--[[
	WhisperCast: Second Wind - the queue. Whispers in, requests queued, replies out, and what the Cast
	button casts next. Read docs/DESIGN_HANDOFF.md (Replies, In combat, The Cast button) and the
	contract at the top of Core.lua; the public calls are listed in API.lua.

	Flow: CHAT_MSG_WHISPER -> MatchSpell (exact / start / any, as 2007) -> group check -> queue + reply.
	The Cast button reads NextCast() out of combat and calls CastClicked(cast) from PreClick, which
	whispers "coming now" once the game takes the cast (UNIT_SPELLCAST_SENT); the cast is answered on UNIT_SPELLCAST_SUCCEEDED ("player") and a failure
	comes back through UI_ERROR_MESSAGE (out of range, line of sight, not in party: a try; cooldown:
	back in line without a try; a group version missing its reagent: single casts for the session).
	In combat the request NextCast() returned when the fight started is armed and stays on the button.

	Retail and WoW: Forever can hand a whisper's text over as a secret value during chat messaging
	lockdown: every string coming from an event is checked (issecretvalue and a guarded probe) before
	any string operation, and a secret one is ignored.
]]
local WCSW = WhisperCastSW
local L = WCSW.L

local Engine = WCSW:AddModule("Engine", {})
WCSW.Engine = Engine

local queue = {}          -- requests in line order
WCSW.queue = queue
WCSW.noGroup = {}         -- [group spell key] = true: out of reagents, single casts until /reload
local nextID = 0
local inCombat = false
local armedCast = nil     -- the cast on the button for this fight
local pending = nil       -- { cast = cast, time = GetTime() } from CastClicked
local ERROR_WINDOW = 1    -- seconds after a click in which an error message belongs to it
local SUCCESS_WINDOW = 12 -- seconds after a click in which a success belongs to it (cast times, summons)
local LINE_MAX = 255      -- a chat message's length limit

---------------------------------------------------------------- safe values
-- true when v is a secret value (Retail / Forever chat lockdown, hidden unit data)
local function isSecret(v)
	local f = issecretvalue
	if f then
		local ok, r = pcall(f, v)
		if not ok or r then return true end
	end
	return false
end
WCSW.IsSecret = function(_, v) return isSecret(v) end

-- v if it is a plain string we may read, else nil
local function plain(v)
	if type(v) ~= "string" or isSecret(v) then return nil end
	local ok = pcall(function() local s = v:lower(); return s == "" end)
	if not ok then return nil end
	return v
end

local function plainNumber(v)
	if type(v) ~= "number" or isSecret(v) then return nil end
	local ok = pcall(function() return v + 0 > -1 end)
	if not ok then return nil end
	return v
end

local function trim(s) return (s:match("^%s*(.-)%s*$")) end

---------------------------------------------------------------- spells
local function spellInfo(id)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, t = pcall(C_Spell.GetSpellInfo, id)
		if ok and type(t) == "table" and t.name then return t.name, t.iconID end
	end
	-- Classic-only global, read only behind this check
	---@diagnostic disable-next-line: undefined-global
	if GetSpellInfo then
		-- Classic-only global, called only when it exists
		---@diagnostic disable-next-line: undefined-global
		local ok, name, _, icon = pcall(GetSpellInfo, id)
		if ok and name then return name, icon end
	end
end
WCSW.SpellInfo = function(_, id) return spellInfo(id) end

local function isKnown(id)
	if not id then return false end
	-- old global on clients without C_SpellBook
	---@diagnostic disable-next-line: deprecated
	if IsPlayerSpell then
		-- old global on clients without C_SpellBook
		---@diagnostic disable-next-line: deprecated
		local ok, r = pcall(IsPlayerSpell, id)
		if ok and r then return true end
	end
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
		if ok and r then return true end
	end
	-- old global on clients without C_SpellBook
	---@diagnostic disable-next-line: deprecated
	if IsSpellKnown then
		-- old global on clients without C_SpellBook
		---@diagnostic disable-next-line: deprecated
		local ok, r = pcall(IsSpellKnown, id)
		if ok and r then return true end
	end
	return false
end

-- every spell ID a spell entry can be known or cast as
local function allIDs(s)
	local ids = {}
	if s.ranks then
		for _, r in ipairs(s.ranks) do ids[#ids + 1] = r[1] end
	else
		ids[1] = s.id
	end
	for _, a in ipairs(s.alts or {}) do ids[#ids + 1] = a end
	return ids
end

-- WCSW.spells for the player's class on this client (Data.lua), with the localized names
function WCSW:BuildSpells()
	local D = self.Data
	local _, class = UnitClass("player")
	self.playerClass = class
	local list = D.spells[self.client] and D.spells[self.client][class] or {}
	local locale = GetLocale and GetLocale() or "enUS"
	local spells, order, byID = {}, {}, {}
	for i, e in ipairs(list) do
		local s = {
			key = e.key, id = e.id, name = e.name, icon = e.icon, englishName = e.name,
			words = D.DefaultWords(class, e, locale),
			group = e.group, isGroup = e.isGroup or nil, byClass = e.byClass or nil,
			combat = e.combat or nil, cure = e.cure or nil, rez = e.rez or nil,
			ranks = e.ranks, alts = e.alts, order = i, known = false,
			priority = D.Priority(class, e),
		}
		spells[e.key] = s
		order[#order + 1] = e.key
		for _, id in ipairs(allIDs(s)) do byID[id] = e.key end
	end
	-- a group version knows the single spell it stands for
	for _, s in pairs(spells) do
		if s.group and spells[s.group] then spells[s.group].single = s.key end
	end
	self.spells, self.spellOrder, self.spellByID = spells, order, byID
	self:RefreshKnown()
end

-- known flags, localized names (the highest known rank's) and icons
function WCSW:RefreshKnown()
	for _, key in ipairs(self.spellOrder or {}) do
		local s = self.spells[key]
		local ids = allIDs(s)
		local knownID
		s.names = {}
		for _, id in ipairs(ids) do
			local n = spellInfo(id)
			if n then s.names[#s.names + 1] = n:lower() end
			if isKnown(id) then knownID = knownID or id; if s.ranks then knownID = id end end
		end
		-- ranks are lowest first, so the last known one is the highest; alts: the first known
		if s.ranks then
			knownID = nil
			for _, r in ipairs(s.ranks) do if isKnown(r[1]) then knownID = r[1] end end
			if not knownID then for _, a in ipairs(s.alts or {}) do if isKnown(a) then knownID = a; break end end end
		end
		s.known = knownID and true or false
		s.knownID = knownID
		local name, icon = spellInfo(knownID or s.id)
		if name then s.name = name end
		if icon then s.icon = icon end
	end
end

-- the character can cast this spell (any rank)
function WCSW:IsKnown(key)
	local s = self.spells and self.spells[key]
	return s and s.known or false
end

function WCSW:SpellEnabled(key)
	local o = self.db and self.db.profile.spells[key]
	return not (o and o.enabled == false)
end

-- the words that match a spell now: the saved list (or the defaults), not counting its name
function WCSW:GetWords(key)
	local s = self.spells and self.spells[key]
	if not s then return {} end
	local o = self.db and self.db.profile.spells[key]
	return (o and o.words) or s.words
end

-- the spells this character can be asked for, in Data.lua order
function WCSW:KnownSpells()
	local out = {}
	for _, key in ipairs(self.spellOrder or {}) do
		local s = self.spells[key]
		if s.known then out[#out + 1] = s end
	end
	return out
end

-- rank for a target level: the highest known rank whose level is at most 10 above it.
-- returns castID, rank number or nil, fits (false when no known rank suits that level)
function WCSW:PickRank(s, level)
	if not s.ranks then
		if isKnown(s.id) then return s.id, nil, true end
		for _, a in ipairs(s.alts or {}) do if isKnown(a) then return a, nil, true end end
		return s.knownID or s.id, nil, true
	end
	local best, lowest
	for _, r in ipairs(s.ranks) do
		if isKnown(r[1]) then
			lowest = lowest or r
			if s.cure or s.rez or not level or r[2] - 10 <= level then best = r end
		end
	end
	if best then return best[1], best[3], true end
	if lowest then return lowest[1], lowest[3], false end
	return s.id, nil, false
end

---------------------------------------------------------------- matching
-- the whisper as matched: lower case, single spaces, no punctuation at the end
local function normalize(msg)
	local s = msg:lower():gsub("%s+", " ")
	s = trim(s):gsub("[%.!%?,;:]+$", "")
	return trim(s)
end
WCSW.NormalizeWhisper = function(_, msg) return normalize(msg) end

local function edgeAfter(msg, e)
	local c = msg:sub(e + 1, e + 1)
	return c == "" or c:find("^[%s%p]") ~= nil
end
local function edgeBefore(msg, s)
	return s == 1 or msg:sub(s - 1, s - 1):find("^[%s%p]") ~= nil
end

-- does word w match the (normalized) whisper in this mode
local function wordMatches(msg, w, mode)
	if w == "" then return false end
	if msg == w then return true end
	if mode == "exact" then return false end
	if msg:sub(1, #w) == w and edgeAfter(msg, #w) then return true end
	if mode ~= "any" then return false end
	local init = 1
	while true do
		local s, e = msg:find(w, init, true)
		if not s then return false end
		if edgeBefore(msg, s) and edgeAfter(msg, e) then return true end
		init = s + 1
	end
end

-- the spell a whisper asks for, among known and turned-on spells: the longest matching word wins; on
-- the same length the higher priority (Data.lua D.priority: the upgrade first, never a group version
-- over a single-target spell), then list order
function WCSW:MatchSpell(msg, mode)
	local text = normalize(msg)
	mode = mode or (self.db and self.db.profile.match) or "start"
	local bestKey, bestLen, bestWord, bestPri = nil, 0, nil, nil
	for _, key in ipairs(self.spellOrder or {}) do
		local s = self.spells[key]
		if s.known and self:SpellEnabled(key) then
			local pri = s.priority or 0
			local function try(w)
				w = w:lower()
				if (#w > bestLen or (#w == bestLen and bestPri and pri > bestPri)) and wordMatches(text, w, mode) then
					bestKey, bestLen, bestWord, bestPri = key, #w, w, pri
				end
			end
			for _, w in ipairs(self:GetWords(key)) do try(w) end
			for _, n in ipairs(s.names or {}) do try(n) end
		end
	end
	return bestKey, bestWord
end

---------------------------------------------------------------- names and units
local function myRealm()
	local r = GetNormalizedRealmName and GetNormalizedRealmName()
	if not r and GetRealmName then r = (GetRealmName() or ""):gsub("[%s%-]", "") end
	return r
end

-- "Name" or "Name-Realm" -> lower case, the realm dropped when it is our own
local function canon(name)
	if not name then return nil end
	local n, r = name:match("^([^%-]+)%-(.+)$")
	if n then
		local mine = myRealm()
		if mine and r:lower() == mine:lower() then return n:lower() end
		return name:lower()
	end
	return name:lower()
end
WCSW.CanonName = function(_, name) return canon(name) end

-- A whisper's sender as the name the game's unit calls use. WoW: Forever puts a surname in chat senders
-- ("Devilin Nyx", "Devilin Nyx-Realm") while UnitName gives "Devilin" (CooldownCollaborator hit the same
-- on 19 Nov 2026), so the name is the word before the first space; a realm stays.
function WCSW:NormalizeSender(sender)
	if type(sender) ~= "string" or sender == "" then return nil end
	local first = sender:match("^(%S+)") or sender
	local name, realm = first:match("^([^%-]+)%-(.+)$")
	if not name then
		name = first
		realm = sender:match("%-([^%s%-]+)$")
	end
	if realm and realm ~= "" then return name .. "-" .. realm end
	return name
end

-- /wc debug: every step of a whisper in chat (kept across reloads until turned off)
function WCSW:Debug(fmt, ...)
	if not (self.db and self.db.global and self.db.global.debug) then return end
	local ok, line = pcall(string.format, fmt, ...)
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFF80FFWC debug|r " .. tostring(ok and line or fmt))
end

local function unitFullName(unit)
	local ok, n, r = pcall(UnitName, unit)
	if not ok or not plain(n) then return nil end
	if plain(r) and r ~= "" then return n .. "-" .. r end
	return n
end

local function unitClass(unit)
	local ok, _, class = pcall(UnitClass, unit)
	if ok and plain(class) then return class end
end

local function unitLevel(unit)
	local ok, raw = pcall(UnitLevel, unit)
	local lv = ok and plainNumber(raw) or nil
	if lv and lv > 0 then return lv end
end

-- the party or raid unit of a player by name, and their raid subgroup (1 in a party); nil when not grouped
local function bareName(name)
	if type(name) ~= "string" then return nil end
	local first = (name:match("^([^%-]+)") or name)
	first = first:match("^(%S+)") or first
	return first:lower()
end

-- the party or raid unit of a player by name, and their raid subgroup (1 in a party); nil when not grouped.
-- An exact name wins. On WoW: Forever only (no other client has surnames) a name can carry a surname
-- ("Marykatherin Gallagher") in chat, in UnitName, or both (seen in game 20 Nov 2026), so there the first
-- word, realm dropped, on both sides, matches too.
function WCSW:FindUnit(name)
	local c = canon(name)
	if not c then return nil end
	local units = {}
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do units[#units + 1] = { "raid" .. i, i } end
	elseif IsInGroup and IsInGroup() then
		for i = 1, 4 do units[#units + 1] = { "party" .. i } end
	end
	units[#units + 1] = { "player" }
	local function found(u, raidIndex)
		local sub = 1
		if raidIndex and GetRaidRosterInfo then
			local ok, _, _, g = pcall(GetRaidRosterInfo, raidIndex)
			if ok and plainNumber(g) then sub = g end
		end
		local isMe = u == "player"
		if not isMe then pcall(function() isMe = UnitIsUnit(u, "player") and true or false end) end
		return isMe and "player" or u, sub
	end
	for _, e in ipairs(units) do
		local f = unitFullName(e[1])
		if f and canon(f) == c then return found(e[1], e[2]) end
	end
	if not WCSW.isForever then return nil end   -- surnames exist only on WoW: Forever
	local b = bareName(name)
	for _, e in ipairs(units) do
		local f = unitFullName(e[1])
		if f and bareName(f) == b then return found(e[1], e[2]) end
	end
	return nil
end

---------------------------------------------------------------- chat out
local function canSend()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, r = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and r and not isSecret(r) then return false end
	end
	return true
end

local function sendChat(text, chatType, target)
	-- C_ChatInfo.SendChatMessage first; the old global is the fallback
	---@diagnostic disable-next-line: deprecated
	local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not fn or not canSend() then return false end
	local ok = pcall(fn, text, chatType, nil, target)
	return ok
end

-- a reply whisper: "[WC] " + text, only when replies are on
function WCSW:Reply(name, text)
	if not (self.db and self.db.profile.replies) or not name then return end
	local sent = sendChat(self.REPLY_TAG .. " " .. text, "WHISPER", name)
	self:Debug("  reply to %s %s: %s", name, sent and "sent" or "NOT sent (chat locked or no send call)", text)
end

-- 1st, 2nd, 3rd, 4th, 11th, 21st...
function WCSW:Ordinal(n)
	local m100, m10 = n % 100, n % 10
	if m100 >= 11 and m100 <= 13 then return L["%dth"]:format(n) end
	if m10 == 1 then return L["%dst"]:format(n) end
	if m10 == 2 then return L["%dnd"]:format(n) end
	if m10 == 3 then return L["%drd"]:format(n) end
	return L["%dth"]:format(n)
end

-- the first word of each spell taking requests (its name when it has no words), a group version right
-- after its single spell, no word twice
function WCSW:FirstWords()
	local out, seen = {}, {}
	local function add(s)
		if not s or not s.known or not self:SpellEnabled(s.key) then return end
		local w = self:GetWords(s.key)[1] or (s.name and s.name:lower()) or s.key
		if not seen[w] then seen[w] = true; out[#out + 1] = w end
	end
	for _, s in ipairs(self:KnownSpells()) do
		if not (s.isGroup and s.single and self.spells[s.single] and self.spells[s.single].known) then
			add(s)
			if s.group then add(self.spells[s.group]) end
		end
	end
	return out
end

-- fill fmt's %s with as many items as fit in one chat line; returns the line and the items left over
local function fitLine(fmt, items, from)
	local i, text = from, nil
	local function build(n)
		local parts = {}
		for k = from, n do parts[#parts + 1] = items[k] end
		return fmt:format(table.concat(parts, ", "))
	end
	text = build(from)
	if #text > LINE_MAX then return text:sub(1, LINE_MAX), from + 1 end
	while i < #items do
		local t = build(i + 1)
		if #t > LINE_MAX then break end
		i, text = i + 1, t
	end
	return text, i + 1
end

---------------------------------------------------------------- the queue
local function indexOf(req)
	for i, r in ipairs(queue) do if r == req then return i end end
end

local function findRequest(name, key)
	local c = canon(name)
	for i, r in ipairs(queue) do
		if r.spell == key and canon(r.name) == c then return r, i end
	end
end

function WCSW:UpdateRequest(req)
	local s = self.spells[req.spell]
	if not s then return end
	req.level = req.unit and unitLevel(req.unit) or nil
	req.castID, req.rank = self:PickRank(s, req.level)
end

local function changed()
	WCSW:Fire("QueueChanged")
end

local function setArmed(cast)
	local before = armedCast and armedCast.reqs[1] or nil
	if armedCast then for _, r in ipairs(armedCast.reqs) do r.armed = nil end end
	armedCast = cast
	if cast then for _, r in ipairs(cast.reqs) do r.armed = true end end
	local after = cast and cast.reqs[1] or nil
	if before ~= after then WCSW:Fire("ArmedChanged", after) end
end

local function removeAt(i, why)
	local r = table.remove(queue, i)
	if not r then return end
	r.removed = why
	if armedCast then
		for _, a in ipairs(armedCast.reqs) do
			if a == r then setArmed(nil); break end
		end
	end
	if pending then
		for _, p in ipairs(pending.cast.reqs) do if p == r then pending = nil; break end end
	end
	WCSW:Fire("RequestRemoved", r, why)
	return r
end

-- remove one request (a req table or its id); why as in Core.lua ("cleared" whispers the asker)
function WCSW:RemoveRequest(req, why)
	why = why or "cleared"
	if type(req) == "number" then
		for _, r in ipairs(queue) do if r.id == req then req = r; break end end
	end
	local i = type(req) == "table" and indexOf(req)
	if not i then return false end
	local s = self.spells[req.spell]
	if why == "cleared" and not req.done then
		self:Reply(req.name, L["Your %s request was cleared."]:format(s and s.name or req.spell))
	end
	removeAt(i, why)
	changed()
	return true
end

-- empty the queue; each waiting asker is told
function WCSW:ClearQueue()
	local n = #queue
	while #queue > 0 do
		local r = queue[1]
		local s = self.spells[r.spell]
		if not r.done then self:Reply(r.name, L["Your %s request was cleared."]:format(s and s.name or r.spell)) end
		removeAt(1, "cleared")
	end
	setArmed(nil)
	pending = nil
	changed()
	return n
end

-- turn a spell's requests on or off; turning it off drops its requests
function WCSW:SetSpellEnabled(key, on)
	self.db.profile.spells[key].enabled = on and true or false
	if not on then self:PruneDisabled() end
	changed()
end

-- drop requests for spells that are turned off or no longer known
function WCSW:PruneDisabled()
	for i = #queue, 1, -1 do
		local r = queue[i]
		local s = self.spells[r.spell]
		if not s or not s.known or not self:SpellEnabled(r.spell) then removeAt(i, "disabled") end
	end
end

function WCSW:IsInCombat() return inCombat end

-- is the asker in range of the spell: true, false, or nil when the game won't say (no unit, or Retail /
-- Forever hiding unit data in combat)
function WCSW:InRange(req)
	if type(req) ~= "table" or not req.unit then return nil end
	if req.unit == "player" then return true end
	local unit, id = req.unit, req.castID
	local ok, r = pcall(function()
		if id and C_Spell and C_Spell.IsSpellInRange then
			local v = C_Spell.IsSpellInRange(id, unit)
			if isSecret(v) then return nil end
			if v ~= nil then return v and true or false end
		-- Classic-only global, in the branch for clients without C_Spell.IsSpellInRange
		---@diagnostic disable-next-line: undefined-global
		elseif id and IsSpellInRange then
			local name = spellInfo(id)
			-- Classic-only global, in the branch for clients without C_Spell.IsSpellInRange
			---@diagnostic disable-next-line: undefined-global
			local v = name and IsSpellInRange(name, unit)
			if isSecret(v) then return nil end
			if v == 1 or v == true then return true end
			if v == 0 or v == false then return false end
		end
		if UnitInRange then
			local inRange, checked = UnitInRange(unit)
			if isSecret(inRange) or isSecret(checked) then return nil end
			if checked then return inRange and true or false end
		end
		return nil
	end)
	if ok then return r end
	return nil
end

---------------------------------------------------------------- group casts
-- the group version that would answer req (with the others it answers), or nil
-- Two or more askers of one spell in one party (one class for Greater Blessings), or anyone asking for
-- the group version itself; it must be known, turned on, and have a rank that suits every asker.
function WCSW:GroupCastFor(req)
	if not self.hasRanks or not req.unit then return nil end
	local s = self.spells[req.spell]
	if not s then return nil end
	local g = s.isGroup and s or (s.group and self.spells[s.group])
	if not g or not g.known or not self:SpellEnabled(g.key) or self.noGroup[g.key] then return nil end
	local single = g.single
	local askers, minLevel = {}, nil
	for _, r in ipairs(queue) do
		if not r.done and r.unit and (r.spell == g.key or r.spell == single) then
			local same
			if g.byClass then same = r.class ~= nil and r.class == req.class else same = r.party == req.party end
			if same then
				askers[#askers + 1] = r
				if r.level and (not minLevel or r.level < minLevel) then minLevel = r.level end
			end
		end
	end
	if req.spell ~= g.key and #askers < 2 then return nil end
	local castID, rank, fits = self:PickRank(g, minLevel)
	if not fits and req.spell ~= g.key then return nil end
	local hint
	if g.byClass then
		local names = LOCALIZED_CLASS_NAMES_MALE
		local cname = (names and req.class and names[req.class]) or req.class or "?"
		hint = L["All %d %s: %s covers them"]:format(#askers, L["%ss"]:format(cname), g.name)
	else
		hint = L["All %d in group %d: %s covers them"]:format(#askers, req.party or 1, g.name)
	end
	return { spell = g.key, castID = castID, rank = rank, party = req.party, class = g.byClass and req.class or nil,
		byClass = g.byClass, askers = askers, hint = hint }
end

local function castFor(req)
	local s = WCSW.spells[req.spell]
	if not s or not s.known then return nil end
	local unit = req.unit or req.name
	local gc = WCSW:GroupCastFor(req)
	if gc then
		return { castID = gc.castID, unit = unit, spell = gc.spell, rank = gc.rank, reqs = gc.askers, group = gc }
	end
	if not req.castID then WCSW:UpdateRequest(req) end
	return { castID = req.castID, unit = unit, spell = req.spell, rank = req.rank, reqs = { req } }
end

-- what the Cast button casts: { castID, unit, spell, reqs } or nil. In combat: the armed cast until it is done.
function WCSW:NextCast()
	if inCombat then
		local r = armedCast and armedCast.reqs[1]
		if r and r.armed and not r.done and indexOf(r) then return armedCast end
		return nil
	end
	for _, req in ipairs(queue) do
		if not req.done then
			local cast = castFor(req)
			if cast then return cast end
		end
	end
	return nil
end

-- the Cast button calls this from PreClick, so the success or failure that follows is matched to it
-- A press remembers the cast; "coming now" waits for the game to take it (Engine:Sent).
function WCSW:CastClicked(cast)
	self:Debug("Cast pressed: %s on %s", tostring(cast and cast.castID), tostring(cast and cast.unit))
	if type(cast) ~= "table" or not cast.reqs then return end
	if inCombat and armedCast and cast.reqs[1] == armedCast.reqs[1] then
		if armedCast.pressed then return end   -- the wrap blocks this press; keep the first one's state
		armedCast.pressed = true
	end
	pending = { cast = cast, time = GetTime() }
end

-- The game took the cast (UNIT_SPELLCAST_SENT for the player, any rank of the pressed spell): now
-- "coming now" goes out, once per press, so a press that casts nothing (out of range before it starts,
-- no unit, the combat wrap) whispers nobody.
function Engine:Sent(spellID)
	spellID = plainNumber(spellID)
	if not spellID or not pending or pending.told or GetTime() - pending.time > 2 then return end
	local cast = pending.cast
	if WCSW.spellByID[spellID] ~= cast.spell then return end
	pending.told = true
	for _, r in ipairs(cast.reqs) do
		if indexOf(r) and not r.done then
			local s = WCSW.spells[r.spell]
			WCSW:Reply(r.name, L["%s coming now."]:format(s and s.name or r.spell))
		end
	end
end

---------------------------------------------------------------- the view
function WCSW:GetView()
	local view = { count = 0, inCombat = inCombat, next = nil, armed = nil, groups = {}, rest = {} }
	for _, r in ipairs(queue) do if not r.done then view.count = view.count + 1 end end
	local armedReq = inCombat and armedCast and armedCast.reqs[1] or nil
	if armedReq and not indexOf(armedReq) then armedReq = nil end
	view.armed = armedReq
	if armedReq then
		view.next = armedReq
	else
		for _, r in ipairs(queue) do if not r.done then view.next = r; break end end
	end
	view.nextCast = self:NextCast()
	for _, r in ipairs(queue) do
		if r ~= view.next then view.rest[#view.rest + 1] = r end
	end
	local grouped = not self.db or self.db.profile.window.grouped
	if grouped then
		local byKey = {}
		for _, r in ipairs(view.rest) do
			local grp = byKey[r.spell]
			if not grp then
				grp = { spell = r.spell, count = 0, askers = {} }
				byKey[r.spell] = grp
				view.groups[#view.groups + 1] = grp
			end
			grp.count = grp.count + 1
			grp.askers[#grp.askers + 1] = r
		end
		for _, grp in ipairs(view.groups) do
			local seen = {}
			for _, r in ipairs(grp.askers) do
				local key = r.party .. ":" .. tostring(r.class)
				if not seen[key] and not r.done then
					seen[key] = true
					local gc = self:GroupCastFor(r)
					if gc and #gc.askers >= 2 then
						grp.groupCasts = grp.groupCasts or {}
						grp.groupCasts[#grp.groupCasts + 1] = gc
						grp.groupCast = grp.groupCast or gc
					end
				end
			end
		end
		view.rest = {}
	end
	return view
end

-- a copy of the queue (each request copied), for other addons
function WCSW:GetQueue()
	local out = {}
	for i, r in ipairs(queue) do
		local c = {}
		for k, v in pairs(r) do c[k] = v end
		out[i] = c
	end
	return out
end

---------------------------------------------------------------- whispers in
-- the list of words, as a whisper of at most two lines
function WCSW:ReplyList(name)
	local words = self:FirstWords()
	if not self.db.profile.enabled or #words == 0 then
		self:Reply(name, L["Not taking requests right now."])
		return
	end
	local fmt = self.REPLY_TAG .. " " .. L["Whisper me one of: %s"]
	local line1, nextIndex = fitLine(fmt, words, 1)
	if not self.db.profile.replies then return end
	sendChat(line1, "WHISPER", name)
	if nextIndex <= #words then
		local line2 = fitLine(self.REPLY_TAG .. " %s", words, nextIndex)
		sendChat(line2, "WHISPER", name)
	end
end

-- a [WC] reply whisper (ours or another copy's): never a request
local function isReply(m)
	return m and m:sub(1, #WCSW.REPLY_TAG):lower() == WCSW.REPLY_TAG:lower()
end

-- true when this whisper is a request (or "wc") we would act on; used by the chat filter too
function WCSW:IsRequestWhisper(msg, sender)
	if isReply(msg) then return false end
	local text = normalize(msg)
	if text == "wc" then return true end
	if not self:MatchSpell(text) then return false end
	if self.db.profile.groupOnly and not self:FindUnit(sender) then return false end
	return true
end

function WCSW:OnWhisper(rawMsg, rawSender)
	local msg, raw = plain(rawMsg), plain(rawSender)
	if not msg or not raw then
		self:Debug("whisper ignored: the game hid its %s (secret value)", (not msg) and "text" or "sender")
		return
	end
	if not self.spells then self:Debug("whisper ignored: spell list not built yet"); return end
	local sender = raw   -- replies go to the name exactly as chat gave it ("Name Surname" on Forever)
	if isReply(msg) then
		self:Debug("whisper from \"%s\" is a [WC] reply; ignored", raw)
		return
	end
	local text = normalize(msg)
	self:Debug("whisper from \"%s\": \"%s\"", raw, text)
	if not sender then return end
	if text == "wc" then
		self:Debug("  -> the \"wc\" list, replying to %s", sender)
		self:ReplyList(sender)
		return
	end
	local key = self:MatchSpell(text)
	if not key then
		self:Debug("  -> no word matched (match mode %s); not a request", tostring(self.db.profile.match))
		return
	end
	local unit, party = self:FindUnit(sender)
	---@type table
	local p = self.db.profile
	self:Debug("  -> %s; sender's unit: %s%s", tostring(self.spells[key] and self.spells[key].name or key),
		tostring(unit or "none"), (unit and party) and (" (group " .. tostring(party) .. ")") or "")
	if not unit then
		local me = unitFullName("player")
		self:Debug("  -> no group member by that name; the game calls you \"%s\"", tostring(me))
	end
	if p.groupOnly and not unit then
		self:Debug("  -> dropped: not in your party or raid (Settings > General > Group members only)")
		return
	end
	local s = self.spells[key]
	if not p.enabled then
		self:Debug("  -> not queued: requests are off (/wc on)")
		self:Reply(sender, L["Not taking requests right now."])
		return
	end
	local old, at = findRequest(sender, key)
	if old then
		self:Debug("  -> already queued, %s in line", self:Ordinal(at))
		old.fails = 0
		old.lastTry = nil
		self:Reply(sender, L["%s: you're already %s in line."]:format(s.name, self:Ordinal(at)))
		changed()
		return
	end
	nextID = nextID + 1
	local req = {
		id = nextID, name = sender, short = self:ShortName(self:NormalizeSender(sender)), spell = key,
		unit = unit, party = party or 1, class = unit and unitClass(unit) or nil,
		time = GetTime(), fails = 0, inCombat = inCombat or nil,
	}
	self:UpdateRequest(req)
	queue[#queue + 1] = req
	if inCombat then
		self:Reply(sender, L["%s: you're %s in line, after this fight."]:format(s.name, self:Ordinal(#queue)))
	else
		self:Reply(sender, L["%s: you're %s in line."]:format(s.name, self:Ordinal(#queue)))
	end
	self:Debug("  -> queued %s in line; cast ID %s on %s", self:Ordinal(#queue), tostring(req.castID), tostring(unit))
	self:Fire("RequestAdded", req)
	changed()
end

---------------------------------------------------------------- cast results
local tryErrors, cooldownErrors, reagentPatterns = {}, {}, {}
-- "Missing reagent: %s" -> "^Missing reagent: .+$"
local function toPattern(fmt)
	local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	p = p:gsub("%%%%s", ".+"):gsub("%%%%d", "%%d+")
	return "^" .. p .. "$"
end
local function buildErrors()
	wipe(tryErrors); wipe(cooldownErrors); wipe(reagentPatterns)
	for _, g in ipairs({ "SPELL_FAILED_REAGENTS", "SPELL_FAILED_REAGENTS_GENERIC", "ERR_SPELL_FAILED_REAGENTS_GENERIC",
		"ERR_SPELL_FAILED_REAGENTS_GENERIC_S" }) do
		local t = _G[g]
		if type(t) == "string" then reagentPatterns[#reagentPatterns + 1] = toPattern(t) end
	end
	for _, g in ipairs({ "SPELL_FAILED_OUT_OF_RANGE", "ERR_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE",
		"SPELL_FAILED_LINE_OF_SIGHT", "SPELL_FAILED_TARGET_NOT_IN_PARTY", "SPELL_FAILED_TARGET_NOT_IN_RAID" }) do
		local t = _G[g]
		if type(t) == "string" then tryErrors[t] = true end
	end
	for _, g in ipairs({ "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "SPELL_FAILED_NOT_READY" }) do
		local t = _G[g]
		if type(t) == "string" then cooldownErrors[t] = true end
	end
end
Engine.BuildErrors = buildErrors

-- a real cooldown (not the global one) on this spell
local function onCooldown(id)
	local dur
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, t = pcall(C_Spell.GetSpellCooldown, id)
		if ok and type(t) == "table" then dur = plainNumber(t.duration) end
	end
	if not dur and GetSpellCooldown then
		local ok, _, d = pcall(GetSpellCooldown, id)
		if ok then dur = plainNumber(d) end
	end
	if not dur then return true end
	return dur > 1.5
end

local function moveToEnd(req)
	local i = indexOf(req)
	if i then table.remove(queue, i); queue[#queue + 1] = req end
end

function Engine:Succeeded(spellID)
	spellID = plainNumber(spellID)
	if not spellID or not pending or GetTime() - pending.time > SUCCESS_WINDOW then return end
	local cast = pending.cast
	if WCSW.spellByID[spellID] ~= cast.spell then return end
	pending = nil
	for _, r in ipairs(cast.reqs) do
		local i = indexOf(r)
		if i and not r.done then
			if inCombat then
				r.done = true
			else
				removeAt(indexOf(r), "cast")
			end
		end
	end
	changed()
end

function Engine:UIError(a1, a2)
	local msg = plain(a2) or plain(a1)
	if not msg or not pending or GetTime() - pending.time > ERROR_WINDOW then return end
	local kind = (tryErrors[msg] and "try") or (cooldownErrors[msg] and "cooldown") or nil
	local cast = pending.cast
	if not kind and cast.group then
		for _, pat in ipairs(reagentPatterns) do
			if msg:find(pat) then kind = "reagent"; break end
		end
	end
	if not kind then return end
	if kind == "reagent" then
		-- out of reagents for the group version: single casts for the rest of the session, no try
		pending = nil
		WCSW.noGroup[cast.spell] = true
		if armedCast == cast then setArmed(nil) end
		local g = WCSW.spells[cast.spell]
		WCSW:Print(L["%s: missing reagent, so single casts for the rest of this session."]:format(g and g.name or cast.spell))
		changed()
		return
	end
	if kind == "cooldown" and not onCooldown(cast.castID) then return end -- the global cooldown: press again
	pending = nil
	local target = cast.reqs[1]
	if not target or not indexOf(target) then return end
	if armedCast == cast then setArmed(nil) end
	if kind == "try" then
		local now = GetTime()
		if not target.lastTry or now - target.lastTry > WCSW.TRY_GRACE then
			target.fails = (target.fails or 0) + 1
			target.lastTry = now
		end
		if target.fails >= WCSW.MAX_TRIES then
			local s = WCSW.spells[target.spell]
			local why = msg:gsub("[%.!]+$", "")
			WCSW:Reply(target.name, L["Couldn't cast %s on you (%s). Whisper again to retry."]:format(s and s.name or target.spell, why))
			removeAt(indexOf(target), "failed")
			changed()
			return
		end
	end
	moveToEnd(target)
	changed()
end

---------------------------------------------------------------- group and combat
function Engine:Roster()
	for i = #queue, 1, -1 do
		local r = queue[i]
		local unit, party = WCSW:FindUnit(r.name)
		if unit then
			r.unit, r.party = unit, party or 1
			r.class = unitClass(unit) or r.class
			WCSW:UpdateRequest(r)
		elseif r.unit or WCSW.db.profile.groupOnly then
			removeAt(i, "left")
		end
	end
	changed()
end

function Engine:LevelChanged(unit)
	for _, r in ipairs(queue) do
		if r.unit == unit then WCSW:UpdateRequest(r) end
	end
	changed()
end

function Engine:CombatStart()
	if inCombat then return end
	local cast = WCSW:NextCast()
	inCombat = true
	WCSW:Fire("CombatChanged", true)
	setArmed(cast)
	changed()
end

function Engine:CombatEnd()
	if not inCombat then return end
	inCombat = false
	for i = #queue, 1, -1 do
		if queue[i].done then removeAt(i, "cast") end
	end
	for _, r in ipairs(queue) do r.armed = nil end
	setArmed(nil)
	WCSW:Fire("CombatChanged", false)
	changed()
end

---------------------------------------------------------------- chat filters
local function filterInform(_, _, msg)
	local p = WCSW.db and WCSW.db.profile
	local m = plain(msg)
	local hide = (p and p.hideOwnReplies and isReply(m)) and true or false
	if isReply(m) or not m then
		WCSW:Debug("chat filter, my whisper: %s (%s)", hide and "hidden" or "shown", m and "text readable" or "text hidden by the game")
	end
	return hide
end

local function filterWhisper(_, _, msg, sender)
	local p = WCSW.db and WCSW.db.profile
	if not p or not WCSW.spells then return false end
	local m, s = plain(msg), plain(sender)
	if not m or not s then return false end
	-- my own [WC] reply coming back when I whisper myself (testing)
	if p.hideOwnReplies and isReply(m) and WCSW:FindUnit(s) == "player" then return true end
	if not p.hideRequests then return false end
	return WCSW:IsRequestWhisper(m, s) and true or false
end
Engine.filterInform, Engine.filterWhisper = filterInform, filterWhisper

---------------------------------------------------------------- slash words
local function groupChannel()
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then
		if LE_PARTY_CATEGORY_HOME and not IsInGroup(LE_PARTY_CATEGORY_HOME) then return "INSTANCE_CHAT" end
		return "PARTY"
	end
end

function WCSW:Announce()
	local channel = groupChannel()
	if not channel then self:Print(L["You are not in a group."]); return end
	local words = self:FirstWords()
	if #words == 0 then self:Print(L["No spells to offer on this character."]); return end
	local text = fitLine(L["Whisper me for buffs: %s. Whisper \"wc\" for the list."], words, 1)
	sendChat(text, channel)
end

function WCSW:PrintStatus()
	---@type table
	local p = self.db.profile
	local yes, no = L["yes"], L["no"]
	self:Print(L["Taking requests: %s. Matching: %s. Group members only: %s. Waiting: %d."]:format(
		p.enabled and yes or no, p.match, p.groupOnly and yes or no, self:GetView().count))
	local known = self:KnownSpells()
	if #known == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("  " .. L["No spells to offer on this character."])
		return
	end
	for _, s in ipairs(known) do
		local words = table.concat(self:GetWords(s.key), ", ")
		local line = "  " .. s.name .. ": " .. (words ~= "" and words or L["(its name only)"])
		if not self:SpellEnabled(s.key) then line = line .. " " .. L["(off)"] end
		DEFAULT_CHAT_FRAME:AddMessage(line)
	end
end

---------------------------------------------------------------- module
function Engine:Init(wcsw)
	wcsw:BuildSpells()
	wcsw:AddSlash("announce", function() wcsw:Announce() end, L["tell your party or raid what to whisper"])
	wcsw:AddSlash("clear", function() wcsw:ClearQueue(); wcsw:Print(L["Queue cleared."]) end, L["clear the queue"])
	wcsw:AddSlash("on", function()
		wcsw.db.profile.enabled = true
		wcsw:Print(L["Taking requests."])
		changed()
	end, L["take requests"])
	wcsw:AddSlash("off", function()
		wcsw.db.profile.enabled = false
		wcsw:Print(L["Not taking requests."])
		changed()
	end, L["stop taking requests"])
	wcsw:AddSlash("status", function() wcsw:PrintStatus() end, L["your spells, their words and the settings"])
	wcsw:AddSlash("debug", function()
		local g = wcsw.db.global
		g.debug = not g.debug
		wcsw:Print(g.debug and L["Debug on: every whisper's steps print in chat. /wc debug again to stop."] or L["Debug off."])
		if g.debug then wcsw:Debug("chat filters added with %s", tostring(wcsw.filterVia)) end
	end, L["print every step of each whisper (on or off)"])
	wcsw:AddSlash("test", function(rest)
		local me = unitFullName("player") or (UnitName and UnitName("player"))
		if not rest or rest == "" then wcsw:Print(L["Usage: /wc test <words>, e.g. /wc test motw"]); return end
		wcsw:Debug("test whisper (no chat sent): \"%s\" from %s", rest, tostring(me))
		wcsw:OnWhisper(rest, me)
	end, L["act as if you whispered yourself, e.g. /wc test motw"])
end

function Engine:Enable(wcsw)
	buildErrors()
	wcsw:RefreshKnown()
	inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
	local f = self.frame or CreateFrame("Frame")
	self.frame = f
	f:RegisterEvent("CHAT_MSG_WHISPER")
	f:RegisterEvent("GROUP_ROSTER_UPDATE")
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:RegisterEvent("UI_ERROR_MESSAGE")
	f:RegisterEvent("SPELLS_CHANGED")
	f:RegisterEvent("UNIT_LEVEL")
	if f.RegisterUnitEvent then
		f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
	else
		f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		f:RegisterEvent("UNIT_SPELLCAST_SENT")
	end
	f:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_WHISPER" then
			wcsw:OnWhisper(...)
		elseif event == "UNIT_SPELLCAST_SENT" then
			local unit, _, _, spellID = ...
			if unit == "player" then Engine:Sent(spellID) end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local unit, _, spellID = ...
			if unit == "player" then Engine:Succeeded(spellID) end
		elseif event == "UI_ERROR_MESSAGE" then
			Engine:UIError(...)
		elseif event == "PLAYER_REGEN_DISABLED" then
			Engine:CombatStart()
		elseif event == "PLAYER_REGEN_ENABLED" then
			Engine:CombatEnd()
		elseif event == "GROUP_ROSTER_UPDATE" then
			Engine:Roster()
		elseif event == "UNIT_LEVEL" then
			local unit = plain((...))
			if unit then Engine:LevelChanged(unit) end
		elseif event == "SPELLS_CHANGED" then
			wcsw:RefreshKnown()
			wcsw:PruneDisabled()
			changed()
		end
	end)
	-- the long-standing global first (proven in game on Forever, 20 Nov 2026); ChatFrameUtil where it's gone
	local addFilter, via = nil, "none"
	if ChatFrame_AddMessageEventFilter then
		addFilter, via = ChatFrame_AddMessageEventFilter, "ChatFrame_AddMessageEventFilter"
	elseif ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
		addFilter, via = ChatFrameUtil.AddMessageEventFilter, "ChatFrameUtil.AddMessageEventFilter"
	end
	if addFilter and not self.filtersAdded then
		self.filtersAdded = true
		addFilter("CHAT_MSG_WHISPER_INFORM", filterInform)
		addFilter("CHAT_MSG_WHISPER", filterWhisper)
	end
	wcsw.filterVia = via
end

function Engine:Refresh(wcsw)
	wcsw:RefreshKnown()
	wcsw:PruneDisabled()
end
