-- Engine harness: loads the real TOC, logs in a priest in a raid, fires whispers and game events, and
-- checks the queue, replies, ranks, group casts, cast results, combat, secrets and roster changes.
-- Then a druid (CooldownCollaborator's "Innervate on me please") and a paladin (Greater Blessings).
-- Run: node tools/tests/run.js . <toc number> tools/tests/engine.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")

local RANKED = (FLAVOR == "era" or FLAVOR == "tbc" or FLAVOR == "forever")
local CLIENT = ({ era = "era", tbc = "tbc", forever = "forever", mop = "mists", retail = "retail" })[FLAVOR]
local FAILS = 0
local function check(name, ok, detail)
	if ok then
		print("  PASS " .. name)
	else
		FAILS = FAILS + 1
		print("  FAIL " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
	end
end

---------------------------------------------------------------- stubs this harness needs
-- error texts (the game's enUS globals)
SPELL_FAILED_OUT_OF_RANGE = "Out of range."
SPELL_FAILED_LINE_OF_SIGHT = "Target not in line of sight"
SPELL_FAILED_TARGET_NOT_IN_PARTY = "Target is not in your party."
ERR_SPELL_COOLDOWN = "Spell is not ready yet."
SPELL_FAILED_NOT_READY = "Not yet recovered"
SPELL_FAILED_REAGENTS = "Missing reagent: %s"
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", ROGUE = "Rogue", MAGE = "Mage", PRIEST = "Priest" }

-- secret values (Retail / Forever): SECRET from wow.lua is the secret
if RETAILAPI then
	function issecretvalue(v) return rawequal(v, SECRET) end
end

-- outgoing chat
SENT = {}
local function capture(text, chatType, _, target)
	SENT[#SENT + 1] = { text = text, chatType = chatType, target = target }
end
if FLAVOR == "retail" then
	C_ChatInfo = { SendChatMessage = capture, InChatMessagingLockdown = function() return LOCKDOWN and true or false end }
else
	SendChatMessage = capture
end
FILTERS = {}
local function addTestFilter(event, fn)
	FILTERS[event] = FILTERS[event] or {}
	table.insert(FILTERS[event], fn)
end
ChatFrame_AddMessageEventFilter = addTestFilter

-- the raid: index -> { name, realm, class, level, sub }
ROSTER = {}
local function setRoster(list)
	ROSTER = list
end
function IsInRaid() return #ROSTER > 5 end
function IsInGroup() return #ROSTER > 1 end
function GetNumGroupMembers() return #ROSTER end
local function rosterOf(u)
	if u == "player" then return ROSTER[1] or { name = PLAYER.name, class = PLAYER.class, level = PLAYER.level } end
	local i = u:match("^raid(%d+)$")
	if i and IsInRaid() then return ROSTER[tonumber(i)] end
	i = u:match("^party(%d+)$")
	if i and not IsInRaid() then return ROSTER[tonumber(i) + 1] end
end
function UnitName(u)
	local r = rosterOf(u)
	if r then return r.name, r.realm end
end
function UnitClass(u)
	local r = rosterOf(u)
	if r then return r.class, r.class, 1 end
end
function UnitLevel(u)
	local r = rosterOf(u)
	return r and r.level or 0
end
function UnitIsUnit(a, b)
	local ra, rb = rosterOf(a), rosterOf(b)
	return ra ~= nil and ra == rb
end
function UnitIsDeadOrGhost(u)
	local r = rosterOf(u)
	return r and r.dead or false
end
function GetRaidRosterInfo(i)
	local r = ROSTER[i]
	if r then return r.name, 0, r.sub, r.level, r.class, r.class, "", true, false end
end
RANGE = {}  -- unit -> true / false / SECRET
function UnitInRange(u)
	local v = RANGE[u]
	if v == nil then return false, false end
	if rawequal(v, SECRET) then return SECRET, SECRET end
	return v, true
end

---------------------------------------------------------------- load and log in
PLAYER.class = "PRIEST"
PLAYER.level = (FLAVOR == "tbc" and 70) or (FLAVOR == "mop" and 90) or (FLAVOR == "retail" and 80) or 60
local MAXL = PLAYER.level
local files = LoadTOC(HARNESS_TOCFILE)
print(string.format("[%s %s engine] loaded %d toc entries, load errors: %d", HARNESS_TOCFILE, FLAVOR, #files, #ERRORS))
local WCSW = WhisperCastSW

-- every spell of this client gets its English name, every spell of the player's class is known
local function knowClass(class, except)
	for k in pairs(KNOWN) do KNOWN[k] = nil end
	for cls, list in pairs(WCSW.Data.spells[CLIENT]) do
		for _, e in ipairs(list) do
			local ids = { e.id }
			for _, r in ipairs(e.ranks or {}) do ids[#ids + 1] = r[1] end
			for _, a in ipairs(e.alts or {}) do ids[#ids + 1] = a end
			for _, id in ipairs(ids) do
				SPELLINFO[id] = { e.name, e.icon }
				if cls == class and not (except and except[id]) then KNOWN[id] = true end
			end
		end
	end
end
knowClass("PRIEST")

setRoster({
	{ name = "Tester", class = "PRIEST", level = MAXL, sub = 1 },
	{ name = "Alice", class = "WARRIOR", level = MAXL, sub = 1 },
	{ name = "Bob", class = "MAGE", level = 20, sub = 1 },
	{ name = "Cara", class = "ROGUE", level = MAXL, sub = 1 },
	{ name = "Dan", class = "WARRIOR", level = MAXL, sub = 2 },
	{ name = "Eve", class = "PRIEST", level = MAXL, sub = 2 },
	{ name = "Finn", class = "WARLOCK", level = MAXL, sub = 2, realm = "Otherrealm" },
})

local EVENTS = {}
local cb = {}
for _, ev in ipairs({ "QueueChanged", "RequestAdded", "RequestRemoved", "CombatChanged", "ArmedChanged" }) do
	WCSW.RegisterCallback(cb, ev, function(_, ...) EVENTS[#EVENTS + 1] = { ev, ... } end)
end
Login()
Advance(1)
check("logged in, no errors", #ERRORS == 0, #ERRORS)

local function whisper(msg, from) FireEvent("CHAT_MSG_WHISPER", msg, from, "", "", from, "", 0, 0, "", 0, 1, "Player-1") end
local function lastSent() return SENT[#SENT] and SENT[#SENT].text end
local function clearAll()
	WCSW:ClearQueue()
	SENT = {}
	EVENTS = {}
end
local function queueKeys()
	local t = {}
	for _, r in ipairs(WCSW.queue) do t[#t + 1] = r.short .. ":" .. r.spell end
	return table.concat(t, ",")
end
local function removedWhy(name)
	for _, e in ipairs(EVENTS) do
		if e[1] == "RequestRemoved" and e[2].short == name then return e[3] end
	end
end
local p = WCSW.db.profile
local fort = WCSW.spells.fortitude
-- a press in the game is followed by UNIT_SPELLCAST_SENT when the cast starts; NO_SENT = the game took nothing
local realClicked = WCSW.CastClicked
WCSW.CastClicked = function(self, cast)
	realClicked(self, cast)
	if cast and cast.castID and not NO_SENT then FireEvent("UNIT_SPELLCAST_SENT", "player", "Target", "Cast-S", cast.castID) end
end

---------------------------------------------------------------- spells
print("-- spells")
check("fortitude listed and known", fort and fort.known, fort and tostring(fort.known))
check("IsKnown(fortitude)", WCSW:IsKnown("fortitude") == true)
check("no other class's spells", WCSW.spells.innervate == nil)
check("fortitude's own name in its names", fort and fort.names[1] == "power word: fortitude")
if RANKED then
	check("prayer of fortitude is the group version", fort.group == "prayerFortitude" and WCSW.spells.prayerFortitude.isGroup == true)
end

---------------------------------------------------------------- default words
print("-- default words")
local D = WCSW.Data
-- a word two spells of one class share must pick one of them by priority (the character may know both)
for _, loc in ipairs({ "enUS", "deDE", "frFR", "koKR", "zhCN" }) do
	local words = D.Defaults(CLIENT, loc)
	local ties = {}
	for class, list in pairs(D.spells[CLIENT]) do
		local byWord = {}
		for _, e in ipairs(list) do
			for _, w in ipairs(words[class][e.key]) do
				byWord[w] = byWord[w] or {}
				table.insert(byWord[w], e)
			end
		end
		for w, es in pairs(byWord) do
			for i = 1, #es do
				for j = i + 1, #es do
					if D.Priority(class, es[i]) == D.Priority(class, es[j]) then
						ties[#ties + 1] = class .. ":" .. w .. "(" .. es[i].key .. "=" .. es[j].key .. ")"
					end
				end
			end
		end
	end
	table.sort(ties)
	check(loc .. ": no shared word ties on priority", #ties == 0, table.concat(ties, " "))
end
local function has(list, w) for _, x in ipairs(list or {}) do if x == w then return true end end return false end
local de = D.Defaults(CLIENT, "deDE")
check("deDE: Fortitude has 'ss'", has(de.PRIEST.fortitude, "ss"))
if de.WARLOCK.soulstone then check("deDE: Soulstone keeps 'ss' (other class)", has(de.WARLOCK.soulstone, "ss")) end
local en = D.Defaults(CLIENT, "enUS")
check("enUS: every rezzer answers 'rez'", has(en.PRIEST.resurrection, "rez") and has(en.PALADIN.redemption, "rez")
	and has(en.SHAMAN.ancestralSpirit, "rez"))
if en.PRIEST.cureDisease then check("enUS: Cure Disease keeps 'disease'", has(en.PRIEST.cureDisease, "disease")) end
if en.DRUID.removeCorruption then
	check("enUS: Remove Corruption keeps 'curse' and 'poison'", has(en.DRUID.removeCorruption, "curse") and has(en.DRUID.removeCorruption, "poison"))
end
if en.MONK and en.MONK.detox then check("enUS: Detox keeps 'poison'", has(en.MONK.detox, "poison")) end
if en.SHAMAN.cleanseSpirit then check("enUS: Cleanse Spirit keeps 'curse'", has(en.SHAMAN.cleanseSpirit, "curse")) end

---------------------------------------------------------------- matching modes
print("-- matching")
p.match = "start"
check("start: 'fort please' -> fortitude", WCSW:MatchSpell("fort please") == "fortitude")
check("start: 'Fort!' -> fortitude", WCSW:MatchSpell("Fort!") == "fortitude")
check("start: 'can i get fort' -> nothing", WCSW:MatchSpell("can i get fort") == nil)
check("start: 'fortress' -> nothing", WCSW:MatchSpell("fortress") == nil)
check("start: spell name 'Power Word: Fortitude on me please' -> fortitude",
	WCSW:MatchSpell("Power Word: Fortitude on me please") == "fortitude")
p.match = "exact"
check("exact: 'fort' -> fortitude", WCSW:MatchSpell("  FORT ") == "fortitude")
check("exact: 'fort please' -> nothing", WCSW:MatchSpell("fort please") == nil)
p.match = "any"
check("any: 'can i get fort please' -> fortitude", WCSW:MatchSpell("can i get fort please") == "fortitude")
check("any: 'comfort' -> nothing", WCSW:MatchSpell("comfort me") == nil)
p.match = "start"
check("longest word wins: 'power word: fortitude' over 'power' (Power Infusion)",
	WCSW:MatchSpell("power word: fortitude") == "fortitude")
check("'pi' -> Power Infusion", WCSW:MatchSpell("pi") == "powerInfusion")
if RANKED then
	check("'group fort' -> Prayer of Fortitude", WCSW:MatchSpell("group fort") == "prayerFortitude")
	p.match = "any"
	check("any: 'group fort pls' -> Prayer of Fortitude (longest)", WCSW:MatchSpell("group fort pls") == "prayerFortitude")
	p.match = "start"
end
p.spells.powerInfusion.enabled = false
check("turned-off spell doesn't match", WCSW:MatchSpell("pi") == nil)
p.spells.powerInfusion.enabled = true
p.spells.fortitude.words = { "buffme" }
check("custom words replace the defaults", WCSW:MatchSpell("buffme") == "fortitude" and WCSW:MatchSpell("fort") == nil)
p.spells.fortitude.words = {}
check("empty word list: the name still matches", WCSW:MatchSpell("power word: fortitude") == "fortitude" and WCSW:MatchSpell("fort") == nil)
p.spells.fortitude.words = nil
local savedKnown = KNOWN[fort.id]
if RANKED then
	knowClass("PRIEST", { [552] = true }) -- no Abolish Disease: "disease" falls to Cure Disease
	WCSW:RefreshKnown()
	check("low-level priest (no Abolish): 'disease' -> Cure Disease", WCSW:MatchSpell("disease") == "cureDisease")
	knowClass("PRIEST")
	WCSW:RefreshKnown()
	check("priest with Abolish: 'disease' -> Abolish Disease", WCSW:MatchSpell("disease") == "abolishDisease")
end

if WCSW.spells.purifyDisease then
	check("Purify over Purify Disease on 'disease'", WCSW:MatchSpell("disease") == "purify")
	knowClass("PRIEST", { [527] = true })
	WCSW:RefreshKnown()
	check("without Purify: 'disease' -> Purify Disease", WCSW:MatchSpell("disease") == "purifyDisease")
	knowClass("PRIEST")
	WCSW:RefreshKnown()
end

---------------------------------------------------------------- queueing, replies, duplicates, group-only
print("-- queue and replies")
clearAll()
whisper("fort please", "Alice")
check("queued Alice fortitude", queueKeys() == "Alice:fortitude", queueKeys())
check("reply: queued 1st", lastSent() == "[WC] Power Word: Fortitude: you're 1st in line.", lastSent())
check("reply goes to the asker as a whisper", SENT[1] and SENT[1].chatType == "WHISPER" and SENT[1].target == "Alice")
check("RequestAdded fired", EVENTS[1] and EVENTS[1][1] == "RequestAdded" and EVENTS[1][2].short == "Alice")
local a = WCSW.queue[1]
check("request fields: unit raid2, party 1, class WARRIOR", a.unit == "raid2" and a.party == 1 and a.class == "WARRIOR",
	tostring(a.unit) .. " " .. tostring(a.party) .. " " .. tostring(a.class))
whisper("fort", "Dan")
check("reply: queued 2nd", lastSent() == "[WC] Power Word: Fortitude: you're 2nd in line.", lastSent())
whisper("fort", "Alice-Realm")
check("duplicate (Name-Realm of our realm) not queued", #WCSW.queue == 2, #WCSW.queue)
check("reply: already 1st", lastSent() == "[WC] Power Word: Fortitude: you're already 1st in line.", lastSent())
whisper("shield", "Alice")
check("same person, other spell queues", #WCSW.queue == 3 and WCSW.queue[3].spell == "shield")
check("reply: 3rd", lastSent() == "[WC] Power Word: Shield: you're 3rd in line.", lastSent())
local n = #SENT
whisper("fort", "Stranger")
check("group only: stranger not queued, no reply", #WCSW.queue == 3 and #SENT == n)
p.groupOnly = false
whisper("fort", "Stranger")
check("group only off: stranger queued with no unit", #WCSW.queue == 4 and WCSW.queue[4].unit == nil)
p.groupOnly = true
whisper("fort", "Finn-Otherrealm")
check("other-realm member queued", WCSW.queue[5] and WCSW.queue[5].unit == "raid7", WCSW.queue[5] and WCSW.queue[5].unit)
whisper("hello there", "Alice")
check("chatter ignored", #WCSW.queue == 5)
check("Ordinal 1 2 3 4", WCSW:Ordinal(1) == "1st" and WCSW:Ordinal(2) == "2nd" and WCSW:Ordinal(3) == "3rd" and WCSW:Ordinal(4) == "4th")
check("Ordinal 11 12 13", WCSW:Ordinal(11) == "11th" and WCSW:Ordinal(12) == "12th" and WCSW:Ordinal(13) == "13th")
check("Ordinal 21 22 23 101 111", WCSW:Ordinal(21) == "21st" and WCSW:Ordinal(22) == "22nd" and WCSW:Ordinal(23) == "23rd"
	and WCSW:Ordinal(101) == "101st" and WCSW:Ordinal(111) == "111th")
local copy = WCSW:GetQueue()
copy[1].spell = "x"
check("GetQueue returns a copy", WCSW.queue[1].spell == "fortitude" and #copy == 5)

-- /wc clear
SENT = {}
WCSW:OnSlash("clear")
check("/wc clear empties the queue", #WCSW.queue == 0)
local cleared = 0
for _, s in ipairs(SENT) do if s.text:find("^%[WC%] Your .+ request was cleared%.$") then cleared = cleared + 1 end end
check("/wc clear tells each asker", cleared == 5, cleared)
check("cleared reply text", SENT[1] and SENT[1].text == "[WC] Your Power Word: Fortitude request was cleared.", SENT[1] and SENT[1].text)

-- off / on
clearAll()
WCSW:OnSlash("off")
whisper("fort", "Alice")
check("/wc off: not queued", #WCSW.queue == 0)
check("reply: not taking requests", lastSent() == "[WC] Not taking requests right now.", lastSent())
WCSW:OnSlash("on")
whisper("fort", "Alice")
check("/wc on: queued again", #WCSW.queue == 1)

-- replies off
clearAll()
p.replies = false
whisper("fort", "Alice")
check("replies off: queued, nothing sent", #WCSW.queue == 1 and #SENT == 0)
p.replies = true

-- the "wc" whisper
clearAll()
whisper("wc", "Alice")
check("'wc' reply lists first words", lastSent() and lastSent():find("^%[WC%] Whisper me one of: ") ~= nil, lastSent())
check("'wc' reply has fort", lastSent() and lastSent():find("fort", 1, true) ~= nil)
check("'wc' reply fits a chat line", lastSent() and #lastSent() <= 255)
check("'wc' queues nothing", #WCSW.queue == 0)
local long = {}
for i = 1, 40 do long[i] = "longword" .. i end
local before = #SENT
local saveFirst = WCSW.FirstWords
WCSW.FirstWords = function() return long end
whisper("wc", "Alice")
WCSW.FirstWords = saveFirst
check("'wc' reply: two lines at most", #SENT - before == 2 and #SENT[#SENT].text <= 255, #SENT - before)

-- /wc announce
clearAll()
WCSW:OnSlash("announce")
check("/wc announce to the raid", SENT[1] and SENT[1].chatType == "RAID" and SENT[1].text:find("^Whisper me for buffs: fort") ~= nil
	and SENT[1].text:find('Whisper "wc" for the list.', 1, true) ~= nil, SENT[1] and SENT[1].text)
local printed = #CHAT
WCSW:OnSlash("status")
check("/wc status prints", #CHAT > printed)

---------------------------------------------------------------- ranks
if RANKED then
	print("-- ranks")
	clearAll()
	whisper("fort", "Bob") -- level 20
	local b = WCSW.queue[1]
	check("level 20 gets rank 3 (needs 24, 24-10 <= 20)", b.castID == 1245 and b.rank == 3, tostring(b.castID) .. " r" .. tostring(b.rank))
	whisper("fort", "Alice")
	local top = fort.ranks[#fort.ranks]
	check("max level gets the top rank", WCSW.queue[2].castID == top[1], WCSW.queue[2].castID)
	knowClass("PRIEST", { [top[1]] = true })
	WCSW:RefreshKnown()
	WCSW:UpdateRequest(WCSW.queue[2])
	check("unknown top rank: highest known", WCSW.queue[2].castID == fort.ranks[#fort.ranks - 1][1], WCSW.queue[2].castID)
	knowClass("PRIEST")
	WCSW:RefreshKnown()
	ROSTER[3].level = 50
	FireEvent("UNIT_LEVEL", "raid3")
	check("level up re-ranks", WCSW.queue[1].castID == 10938, WCSW.queue[1].castID)
	ROSTER[3].level = 20
	FireEvent("UNIT_LEVEL", "raid3")
end

---------------------------------------------------------------- grouped view and smart group cast
print("-- view and group cast")
clearAll()
whisper("fort", "Alice")   -- party 1
whisper("fort", "Dan")     -- party 2
whisper("fort", "Cara")    -- party 1
whisper("shield", "Eve")   -- party 2
whisper("fort", "Tester")  -- party 1 (myself)
local view = WCSW:GetView()
check("view count 5", view.count == 5, view.count)
check("view next is the first in line", view.next == WCSW.queue[1])
check("grouped: groups by spell in line order", #view.groups == 2 and view.groups[1].spell == "fortitude" and view.groups[1].count == 3
	and view.groups[2].spell == "shield", #view.groups)
local cast = WCSW:NextCast()
if RANKED then
	check("smart group cast: Prayer of Fortitude", cast and cast.spell == "prayerFortitude", cast and cast.spell)
	check("group cast answers all 3 in party 1", cast and #cast.reqs == 3 and cast.unit == "raid2", cast and #cast.reqs)
	check("group cast rank: top Prayer rank", cast and cast.castID == WCSW.spells.prayerFortitude.ranks[#WCSW.spells.prayerFortitude.ranks][1])
	local gc = view.groups[1].groupCast
	check("view hint: group cast for party 1 with 3 askers", gc and gc.party == 1 and #gc.askers == 3 and gc.spell == "prayerFortitude",
		gc and (gc.party .. "/" .. #gc.askers))
	check("nextCast in the view", view.nextCast and view.nextCast.spell == "prayerFortitude")
	check("hint text by party", gc and gc.hint == "All 3 in group 1: Prayer of Fortitude covers them", gc and gc.hint)
	whisper("fort", "Bob") -- level 20: Prayer of Fortitude (48) doesn't suit
	cast = WCSW:NextCast()
	check("a too-low asker in the party: no group cast", cast and cast.spell == "fortitude", cast and cast.spell)
	WCSW:RemoveRequest(WCSW.queue[#WCSW.queue], "cleared")
	p.spells.prayerFortitude.enabled = false
	cast = WCSW:NextCast()
	check("group version turned off: single cast", cast and cast.spell == "fortitude" and #cast.reqs == 1)
	p.spells.prayerFortitude.enabled = true
else
	check("no group versions here: single cast", cast and cast.spell == "fortitude" and #cast.reqs == 1, cast and cast.spell)
	check("no group hint", view.groups[1].groupCast == nil)
end
p.window.grouped = false
view = WCSW:GetView()
check("grouped off: rest lists the other 4 requests", #view.rest == 4 and #view.groups == 0)
p.window.grouped = true

---------------------------------------------------------------- casting and results
print("-- cast results")
SENT = {}
EVENTS = {}
cast = WCSW:NextCast()
WCSW:CastClicked(cast)
check("'coming now' goes out on the press", #SENT == #cast.reqs and SENT[1].text == "[WC] Power Word: Fortitude coming now.", #SENT)
local sentAtPress = #SENT
Advance(0.3)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", cast.castID)
check("nothing more sent on success", #SENT == sentAtPress, #SENT)
if RANKED then
	check("success answers every asker of the group cast", #WCSW.queue == 2 and queueKeys() == "Dan:fortitude,Eve:shield", queueKeys())
	local coming = 0
	for _, s in ipairs(SENT) do if s.text == "[WC] Power Word: Fortitude coming now." then coming = coming + 1 end end
	check("'coming now' to each of the 3, once", coming == 3, coming)
else
	check("success answers the asker", #WCSW.queue == 4 and WCSW.queue[1].short == "Dan", queueKeys())
	check("reply: coming now", SENT[1] and SENT[1].text == "[WC] Power Word: Fortitude coming now.", SENT[1] and SENT[1].text)
end
check("RequestRemoved with 'cast'", removedWhy("Alice") == "cast", removedWhy("Alice"))
-- a success with no click is ignored
local count = #WCSW.queue
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", WCSW:NextCast().castID)
check("success without a click: nothing answered", #WCSW.queue == count)

-- out of range: a try, back in line; four tries and it is dropped
clearAll()
whisper("fort", "Dan")
whisper("shield", "Eve")
local dan = WCSW.queue[1]
for try = 1, WCSW.MAX_TRIES do
	Advance(WCSW.TRY_GRACE + 0.5)
	cast = WCSW:NextCast()
	-- after a try Dan goes to the back; cast Dan's request each time
	if cast.reqs[1] ~= dan then WCSW:CastClicked({ castID = dan.castID, unit = dan.unit, spell = dan.spell, reqs = { dan } }) else WCSW:CastClicked(cast) end
	FireEvent("UI_ERROR_MESSAGE", 51, SPELL_FAILED_OUT_OF_RANGE)
	if try == 1 then
		check("out of range: one try, back in line", dan.fails == 1 and WCSW.queue[#WCSW.queue] == dan, dan.fails)
		-- within the grace a second error doesn't count
		WCSW:CastClicked({ castID = dan.castID, unit = dan.unit, spell = dan.spell, reqs = { dan } })
		FireEvent("UI_ERROR_MESSAGE", 51, SPELL_FAILED_OUT_OF_RANGE)
		check("a second error within the grace isn't a try", dan.fails == 1, dan.fails)
	end
end
check("after " .. WCSW.MAX_TRIES .. " tries the request is dropped", #WCSW.queue == 1 and WCSW.queue[1].short == "Eve", queueKeys())
check("failed reply text", lastSent() == "[WC] Couldn't cast Power Word: Fortitude on you (Out of range). Whisper again to retry.", lastSent())
check("RequestRemoved with 'failed'", removedWhy("Dan") == "failed")

-- line of sight and not in party: tries
clearAll()
whisper("fort", "Dan")
whisper("shield", "Eve")
Advance(5)
WCSW:CastClicked(WCSW:NextCast())
FireEvent("UI_ERROR_MESSAGE", 50, SPELL_FAILED_LINE_OF_SIGHT)
check("line of sight: a try, back in line", WCSW.queue[2].short == "Dan" and WCSW.queue[2].fails == 1)
local cn = 0
for _, s in ipairs(SENT) do if s.target == "Dan" and s.text:find("coming now", 1, true) then cn = cn + 1 end end
check("'coming now' on that press", cn == 1, cn)
Advance(5)
WCSW:CastClicked(WCSW:NextCast())
FireEvent("UI_ERROR_MESSAGE", 50, SPELL_FAILED_TARGET_NOT_IN_PARTY)
check("not in party: a try", WCSW.queue[2].short == "Eve" and WCSW.queue[2].fails == 1)
-- an error long after the click belongs to something else
Advance(5)
WCSW:CastClicked(WCSW:NextCast())
Advance(2)
FireEvent("UI_ERROR_MESSAGE", 50, SPELL_FAILED_OUT_OF_RANGE)
check("a late error is ignored", WCSW.queue[1].short == "Dan" and WCSW.queue[1].fails == 1)
-- re-whisper resets tries
whisper("fort", "Dan")
check("whispering again resets the tries", WCSW.queue[1].fails == 0)
SENT = {}
WCSW:CastClicked(WCSW:NextCast())
check("a retry after a failed try sends 'coming now' again", SENT[1] and SENT[1].target == "Dan" and SENT[1].text:find("coming now", 1, true) ~= nil)

-- cooldown: back in line, no try; the global cooldown: nothing
clearAll()
whisper("pi", "Alice")
whisper("shield", "Eve")
local pi = WCSW.queue[1]
SPELLCD[pi.castID] = { startTime = NOW, duration = 1.5, isEnabled = true, isActive = true, modRate = 1 }
Advance(5)
WCSW:CastClicked(WCSW:NextCast())
FireEvent("UI_ERROR_MESSAGE", 50, ERR_SPELL_COOLDOWN)
check("global cooldown: stays first", WCSW.queue[1] == pi and pi.fails == 0)
SPELLCD[pi.castID] = { startTime = NOW, duration = 120, isEnabled = true, isActive = true, modRate = 1 }
WCSW:CastClicked(WCSW:NextCast())
FireEvent("UI_ERROR_MESSAGE", 50, ERR_SPELL_COOLDOWN)
check("cooldown: back in line without a try", WCSW.queue[2] == pi and pi.fails == 0)
SPELLCD[pi.castID] = nil

---------------------------------------------------------------- combat
print("-- combat")
clearAll()
whisper("fort", "Dan")
whisper("shield", "Eve")
local first = WCSW.queue[1]
EVENTS = {}
FireEvent("PLAYER_REGEN_DISABLED")
local armedEv, combatEv
for _, e in ipairs(EVENTS) do
	if e[1] == "ArmedChanged" then armedEv = e end
	if e[1] == "CombatChanged" then combatEv = e end
end
check("CombatChanged(true)", combatEv and combatEv[2] == true)
check("ArmedChanged(first request)", armedEv and armedEv[2] == first)
check("first request armed", first.armed == true and WCSW:GetView().armed == first)
whisper("fort", "Alice")
check("in combat: queued, flagged", #WCSW.queue == 3 and WCSW.queue[3].inCombat == true)
check("reply: after this fight", lastSent() == "[WC] Power Word: Fortitude: you're 3rd in line, after this fight.", lastSent())
cast = WCSW:NextCast()
check("in combat NextCast is the armed one", cast and cast.reqs[1] == first)
SENT = {}
WCSW:CastClicked(cast)
WCSW:CastClicked(cast)
check("armed press: 'coming now' once per fight", #SENT == 1 and SENT[1].text == "[WC] Power Word: Fortitude coming now.", #SENT)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", cast.castID)
check("cast in combat: marked done, still listed", first.done == true and WCSW.queue[1] == first)
check("reply: coming now", lastSent() == "[WC] Power Word: Fortitude coming now.", lastSent())
check("in combat after the cast: NextCast nil", WCSW:NextCast() == nil)
view = WCSW:GetView()
check("view: spotlight keeps the armed one, count 2", view.next == first and view.count == 2)
EVENTS = {}
FireEvent("PLAYER_REGEN_ENABLED")
check("combat ends: the done one leaves with 'cast'", #WCSW.queue == 2 and removedWhy("Dan") == "cast", queueKeys())
check("no armed request after the fight", WCSW:GetView().armed == nil and not WCSW.queue[1].armed)
cast = WCSW:NextCast()
check("after the fight NextCast is the next one", cast and cast.reqs[1].short == "Eve")
-- a failure on the armed press: un-armed, a try
clearAll()
whisper("fort", "Dan")
whisper("shield", "Eve")
FireEvent("PLAYER_REGEN_DISABLED")
first = WCSW.queue[1]
Advance(5)
WCSW:CastClicked(WCSW:NextCast())
FireEvent("UI_ERROR_MESSAGE", 51, SPELL_FAILED_OUT_OF_RANGE)
check("armed press out of range: a try, un-armed", first.fails == 1 and not first.armed and WCSW:GetView().armed == nil)
FireEvent("PLAYER_REGEN_ENABLED")
-- combat with an empty queue
clearAll()
FireEvent("PLAYER_REGEN_DISABLED")
whisper("fort", "Dan")
check("empty at the pull: nothing armed", WCSW:NextCast() == nil and WCSW:GetView().armed == nil)
FireEvent("PLAYER_REGEN_ENABLED")
check("after the fight it is ready", WCSW:NextCast() ~= nil)

---------------------------------------------------------------- range
print("-- range")
clearAll()
whisper("fort", "Dan")
whisper("fort", "Tester")
local d, me = WCSW.queue[1], WCSW.queue[2]
check("InRange(myself) true", WCSW:InRange(me) == true)
RANGE.raid5 = true
local ir = WCSW:InRange(d)
check("InRange true/false/nil, no error", ir == true or ir == false or ir == nil)
if not (C_Spell and C_Spell.IsSpellInRange) and not IsSpellInRange then
	check("InRange from UnitInRange", ir == true)
	RANGE.raid5 = false
	check("InRange false", WCSW:InRange(d) == false)
	if RETAILAPI then
		RANGE.raid5 = SECRET
		check("InRange secret -> nil", WCSW:InRange(d) == nil)
	end
	RANGE.raid5 = nil
	check("InRange unreadable -> nil", WCSW:InRange(d) == nil)
end
check("InRange(no unit) nil", WCSW:InRange({}) == nil)

---------------------------------------------------------------- secrets and odd input
print("-- secrets")
clearAll()
local errs = #ERRORS
whisper(nil, "Alice")
whisper("fort", nil)
check("missing text or sender ignored", #WCSW.queue == 0 and #ERRORS == errs)
if RETAILAPI then
	whisper(SECRET, "Alice")
	check("secret whisper text ignored, no error", #WCSW.queue == 0 and #ERRORS == errs and #SENT == 0)
	whisper("fort", SECRET)
	check("secret sender ignored, no error", #WCSW.queue == 0 and #ERRORS == errs)
	p.hideRequests = true
	local f = FILTERS.CHAT_MSG_WHISPER and FILTERS.CHAT_MSG_WHISPER[1]
	check("chat filter on a secret whisper: shown, no error", f and f(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", SECRET, "Alice") == false and #ERRORS == errs)
	p.hideRequests = false
	UnitLevelSave = UnitLevel
	UnitLevel = function() return SECRET end
	whisper("fort", "Dan")
	check("secret unit level: still queued (no level)", #WCSW.queue == 1 and WCSW.queue[1].level == nil and #ERRORS == errs)
	UnitLevel = UnitLevelSave
end
if FLAVOR == "retail" then
	clearAll()
	LOCKDOWN = true
	whisper("fort", "Dan")
	check("chat lockdown: queued, no reply sent", #WCSW.queue == 1 and #SENT == 0)
	LOCKDOWN = false
end

---------------------------------------------------------------- chat filters
print("-- chat filters")
local fi = FILTERS.CHAT_MSG_WHISPER_INFORM and FILTERS.CHAT_MSG_WHISPER_INFORM[1]
local fw = FILTERS.CHAT_MSG_WHISPER and FILTERS.CHAT_MSG_WHISPER[1]
check("filters added (never replacing the chat handler)", fi ~= nil and fw ~= nil and #FILTERS.CHAT_MSG_WHISPER == 1)
p.hideOwnReplies = true
check("hides my [WC] whispers", fi(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER_INFORM", "[WC] Fort: you're 1st in line.", "Alice") == true)
check("keeps my other whispers", fi(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER_INFORM", "hello", "Alice") == false)
p.hideOwnReplies = false
check("setting off: shows my [WC] whispers", fi(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER_INFORM", "[WC] x", "Alice") == false)
p.hideRequests = false
check("request whispers shown by default", fw(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "fort", "Alice") == false)
p.hideRequests = true
check("hide requests: 'fort' hidden", fw(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "fort", "Alice") == true)
check("hide requests: 'wc' hidden", fw(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "wc", "Stranger") == true)
check("hide requests: chatter shown", fw(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "hello", "Alice") == false)
check("hide requests: stranger's 'fort' shown (group only)", fw(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "fort", "Stranger") == false)
p.hideRequests = false
p.hideOwnReplies = true

---------------------------------------------------------------- players leaving
print("-- roster")
clearAll()
whisper("fort", "Dan")
whisper("shield", "Eve")
whisper("fort", "Alice")
table.remove(ROSTER, 5) -- Dan leaves; Eve moves to raid5
FireEvent("GROUP_ROSTER_UPDATE")
check("player who left is dropped with 'left'", #WCSW.queue == 2 and removedWhy("Dan") == "left", queueKeys())
check("units follow the roster", WCSW.queue[1].short == "Eve" and WCSW.queue[1].unit == "raid5", WCSW.queue[1].unit)
table.insert(ROSTER, 5, { name = "Dan", class = "WARRIOR", level = MAXL, sub = 2 })
FireEvent("GROUP_ROSTER_UPDATE")

---------------------------------------------------------------- disabling a spell
clearAll()
whisper("shield", "Eve")
WCSW:SetSpellEnabled("shield", false)
check("turning a spell off drops its requests", #WCSW.queue == 0 and removedWhy("Eve") == "disabled")
WCSW:SetSpellEnabled("shield", true)

---------------------------------------------------------------- API
print("-- API")
check("TriggerFor(Innervate) = innervate", WCSW:TriggerFor(29166) == "innervate", WCSW:TriggerFor(29166))
check("TriggerFor(fortitude) = sta (shortest)", WCSW:TriggerFor(fort.id) == "sta", WCSW:TriggerFor(fort.id))
if RANKED then check("TriggerFor(a rank ID)", WCSW:TriggerFor(fort.ranks[2][1]) == "sta") end
check("TriggerFor(unknown ID) = its name", WCSW:TriggerFor(12345) == "Spell 12345", WCSW:TriggerFor(12345))

---------------------------------------------------------------- missing reagents
if RANKED then
	print("-- reagents")
	clearAll()
	whisper("fort", "Alice")
	whisper("fort", "Cara")
	whisper("shield", "Eve")
	cast = WCSW:NextCast()
	check("group cast before the reagent error", cast and cast.spell == "prayerFortitude")
	local printedBefore = #CHAT
	Advance(5)
	WCSW:CastClicked(cast)
	FireEvent("UI_ERROR_MESSAGE", 52, "Missing reagent: Sacred Candle")
	check("missing reagent: group version off for the session", WCSW.noGroup.prayerFortitude == true)
	check("missing reagent: no try, still first", WCSW.queue[1].short == "Alice" and WCSW.queue[1].fails == 0)
	cast = WCSW:NextCast()
	check("missing reagent: single casts after", cast and cast.spell == "fortitude" and #cast.reqs == 1, cast and cast.spell)
	check("missing reagent: one chat line", #CHAT == printedBefore + 1 and tostring(CHAT[#CHAT]):find("missing reagent", 1, true) ~= nil, CHAT[#CHAT])
	check("missing reagent: no hint any more", WCSW:GetView().groups[1] == nil or WCSW:GetView().groups[1].groupCast == nil)
	WCSW:CastClicked(WCSW:NextCast())
	FireEvent("UI_ERROR_MESSAGE", 52, "Missing reagent: Sacred Candle")
	check("a reagent error on a single cast is ignored", WCSW.queue[1].fails == 0 and WCSW.queue[1].short == "Alice")
	WCSW.noGroup.prayerFortitude = nil
end

---------------------------------------------------------------- resurrection
print("-- resurrection")
clearAll()
ROSTER[5].dead = true
whisper("rez please", "Dan")
check("priest: 'rez' queues Resurrection", queueKeys() == "Dan:resurrection", queueKeys())
cast = WCSW:NextCast()
check("a dead asker is cast on (unit kept)", cast and cast.unit == "raid5" and cast.spell == "resurrection", cast and cast.unit)
if RANKED then
	check("rez: highest known rank (no level rule)", cast and cast.castID == WCSW.spells.resurrection.ranks[#WCSW.spells.resurrection.ranks][1])
end
whisper("res", "Bob")
check("'res' works too", WCSW.queue[2] and WCSW.queue[2].spell == "resurrection")
ROSTER[5].dead = nil

---------------------------------------------------------------- druid: CooldownCollaborator's whisper
print("-- druid")
clearAll()
PLAYER.class = "DRUID"
ROSTER[1].class = "DRUID"
knowClass("DRUID")
WCSW:BuildSpells()
check("druid spells built", WCSW.spells.innervate and WCSW.spells.innervate.known and WCSW.spells.fortitude == nil)
whisper("Innervate on me please", "Eve")
check("CDC's 'Innervate on me please' queues Innervate", queueKeys() == "Eve:innervate", queueKeys())
check("reply names Innervate", lastSent() == "[WC] Innervate: you're 1st in line.", lastSent())
whisper("motw", "Alice")
check("'motw' -> Mark of the Wild", WCSW.queue[2] and WCSW.queue[2].spell == "mark")
if WCSW.spells.abolishPoison then
	check("druid with Abolish Poison: 'poison' -> Abolish Poison", WCSW:MatchSpell("poison") == "abolishPoison")
	knowClass("DRUID", { [2893] = true })
	WCSW:RefreshKnown()
	check("low-level druid: 'poison' -> Cure Poison", WCSW:MatchSpell("poison") == "curePoison")
	knowClass("DRUID")
	WCSW:RefreshKnown()
end
if WCSW.spells.naturesCure then
	check("druid with Nature's Cure: 'curse' -> Nature's Cure", WCSW:MatchSpell("curse") == "naturesCure")
	knowClass("DRUID", { [88423] = true })
	WCSW:RefreshKnown()
	check("druid without it: 'curse' -> Remove Corruption", WCSW:MatchSpell("curse") == "removeCorruption")
	knowClass("DRUID")
	WCSW:RefreshKnown()
end
if WCSW.spells.revive then
	check("druid: 'rez' -> Revive", WCSW:MatchSpell("rez") == "revive")
	check("druid: 'rebirth' -> Rebirth", WCSW:MatchSpell("rebirth") == "rebirth")
else
	check("druid: 'rez' -> Rebirth", WCSW:MatchSpell("rez") == "rebirth")
end

---------------------------------------------------------------- paladin: Greater Blessings cover a class
print("-- paladin")
clearAll()
PLAYER.class = "PALADIN"
ROSTER[1].class = "PALADIN"
knowClass("PALADIN")
WCSW:BuildSpells()
if RANKED then
	whisper("kings", "Alice") -- warrior, party 1
	whisper("kings", "Dan")   -- warrior, party 2
	whisper("kings", "Cara")  -- rogue, party 1
	cast = WCSW:NextCast()
	check("two warriors asking kings: Greater Blessing of Kings", cast and cast.spell == "greaterKings" and #cast.reqs == 2, cast and cast.spell)
	local g = WCSW:GetView().groups[1]
	check("view hint by class", g and g.groupCast and g.groupCast.byClass and g.groupCast.class == "WARRIOR")
	check("hint text by class", g and g.groupCast and g.groupCast.hint == "All 2 Warriors: Greater Blessing of Kings covers them",
		g and g.groupCast and g.groupCast.hint)
	clearAll()
	whisper("kings", "Alice")
	whisper("kings", "Cara")
	cast = WCSW:NextCast()
	check("same party, different classes: single Blessing of Kings", cast and cast.spell == "kings" and #cast.reqs == 1, cast and cast.spell)
else
	whisper("freedom", "Alice")
	check("paladin: 'rez' -> Redemption", WCSW:MatchSpell("rez") == "redemption")
	check("'freedom' queues the freedom spell", queueKeys() == "Alice:freedom", queueKeys())
end

---------------------------------------------------------------- WoW: Forever surnames (seen in game 20 Nov 2026)
do
	local word = WCSW.hasRanks and "kings" or "freedom"
	clearAll()
	whisper(word, "Alice Nyx")
	if WCSW.isForever then
		check("Forever: surname sender \"Alice Nyx\" finds Alice in the group", queueKeys():match("^Alice:") ~= nil, queueKeys())
		check("Forever: the reply goes to the full \"Alice Nyx\" (the server needs it)", SENT[#SENT] and SENT[#SENT].target == "Alice Nyx", SENT[#SENT] and SENT[#SENT].target)
		clearAll()
		-- the game itself calls me "Tester Stormrider"; chat says the same
		local saved = PLAYER.name
		PLAYER.name = saved .. " Stormrider"
		if ROSTER[1] then ROSTER[1].name = PLAYER.name end
		whisper(word, PLAYER.name)
		local r = WCSW.queue[1]
		check("Forever: my own whisper with my surname queues on me (unit player)", r and r.unit == "player", r and r.unit)
		clearAll()
		-- chat with a surname, the roster without one (and the other way round)
		PLAYER.name = saved
		if ROSTER[1] then ROSTER[1].name = saved end
		whisper(word, saved .. " Stormrider")
		r = WCSW.queue[1]
		check("Forever: chat surname, roster without: still me", r and r.unit == "player", r and r.unit)
		check("Forever: IsRequestWhisper accepts a surname sender (chat filter)", WCSW:IsRequestWhisper(word, "Alice Nyx") == true)
	else
		check("not Forever: \"Alice Nyx\" is not Alice (no surnames on this client)", queueKeys() == "", queueKeys())
	end
	-- a [WC] reply is never a request (two copies would whisper each other in a loop)
	clearAll()
	p.match = "any"
	whisper("[WC] Mark of the Wild: you're 1st in line. kings freedom fort motw", "Alice")
	check("a [WC] reply whisper is never queued, even with any-word matching", #WCSW.queue == 0 and #SENT == 0, queueKeys())
	p.match = "start"
	local fwh = FILTERS.CHAT_MSG_WHISPER and FILTERS.CHAT_MSG_WHISPER[1]
	check("my own [WC] reply echoed back to me is hidden", fwh and fwh(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "[WC] x: you're 1st in line.", UnitName("player")) == true)
	check("someone else's [WC] whisper is shown", fwh and fwh(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", "[WC] x: you're 1st in line.", "Alice") == false)
	-- "coming now" waits for the game to take the cast
	clearAll()
	whisper(word, "Alice")
	SENT = {}
	NO_SENT = true
	WCSW:CastClicked(WCSW:NextCast())
	check("a press the game doesn't take whispers nobody", #SENT == 0, #SENT)
	NO_SENT = nil
	WCSW:CastClicked(WCSW:NextCast())
	check("a press the game takes sends 'coming now' once", #SENT == 1 and SENT[1].text:find("coming now", 1, true) ~= nil, #SENT)
	-- /wc debug and /wc test
	clearAll()
	WCSW.db.global.debug = true
	local before = #CHAT
	WCSW.slash.test(word)
	local saw = false
	for k = before + 1, #CHAT do if tostring(CHAT[k]):find("WC debug", 1, true) and tostring(CHAT[k]):find("queued", 1, true) then saw = true end end
	check("/wc test queues on me and /wc debug prints the steps", WCSW.queue[1] and WCSW.queue[1].unit == "player" and saw)
	before = #CHAT
	whisper("hello there", "Bob")
	saw = false
	for k = before + 1, #CHAT do if tostring(CHAT[k]):find("no word matched", 1, true) then saw = true end end
	check("/wc debug says why chatter isn't a request", saw)
	WCSW.db.global.debug = false
	clearAll()
end

---------------------------------------------------------------- end
for _, e in ipairs(ERRORS) do print("  FAIL lua error: " .. tostring(e):sub(1, 400)) end
print(string.format("RESULT %s engine: total lua errors %d", HARNESS_TOCFILE, #ERRORS + FAILS))
