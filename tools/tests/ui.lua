-- UI lane harness: loads the real TOC, logs in, and drives the window, the Cast button, the note, the
-- folded icon, the minimap button and Edit Mode with a fake queue (WCSW.GetView / NextCast overridden),
-- then with the real Engine when it is there. One PASS or FAIL line per check; FAIL lines count as errors.
--   node tools/tests/run.js . <toc number> tools/tests/ui.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "PRIEST"

local FAILS, PASSES = 0, 0
local function check(name, ok, detail)
	if ok then
		PASSES = PASSES + 1
		print("  PASS " .. name)
	else
		FAILS = FAILS + 1
		print("  FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
	end
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.002 end

---------------------------------------------------------------- stubs the UI needs
LOCKDOWN = false
function InCombatLockdown() return LOCKDOWN end
CVARS = {}
function GetCVarBool(k) return CVARS[k] or false end
BINDKEY = "F"
function GetBindingKey(cmd) if cmd == "CLICK WhisperCastSWCastButton:LeftButton" then return BINDKEY end end
function GetBindingText(k) return k end
PLAYED = {}
function PlaySound(id, ch) PLAYED[#PLAYED + 1] = { "kit", id }; return true end
function PlaySoundFile(f, ch) PLAYED[#PLAYED + 1] = { "file", f }; return true end
SOUNDKIT = setmetatable({ TELL_MESSAGE = 3081 }, { __index = function() return 1 end })

-- remember each frame's template, so the secure ones can be told apart
local rawCreate = CreateFrame
CreateFrame = function(otype, name, parent, template, id)
	local f = rawCreate(otype, name, parent, template, id)
	f.__template = template
	return f
end

-- the secure wrap: kept, and run by Press() below as the game would
WRAPS = {}
VIOLATIONS = {}
function SecureHandlerWrapScript(frame, script, header, pre, post)
	if LOCKDOWN then VIOLATIONS[#VIOLATIONS + 1] = "wrap in combat" end
	WRAPS[frame] = { script = script, header = header, pre = pre, post = post }
end

-- LibEditMode stub (wow.lua's) plus a record of the settings each frame gets
local lemStub = STUB_FILES["libs/libeditmode/embed.xml"]
LEM_SETTINGS = {}
STUB_FILES["libs/libeditmode/embed.xml"] = function()
	lemStub()
	function LEM_STUB:AddFrameSettings(frame, settings) LEM_SETTINGS[frame] = settings end
	function LEM_STUB:AddFrame(frame, cb, default, name) self.frames[frame] = { cb = cb, default = default, name = name } end
end

---------------------------------------------------------------- load and log in
local files = LoadTOC(HARNESS_TOCFILE)
print(string.format("[%s %s] loaded %d toc entries (%d lua files), load errors: %d", HARNESS_TOCFILE, FLAVOR, #files, #LOADED_FILES, #ERRORS))
Login()
Advance(1)
local WCSW = WhisperCastSW
local UI = WCSW.UI
local CB, W, T, F = WCSW.CastButton, WCSW.Window, WCSW.Toast, WCSW.Folded
local P = WCSW.db.profile
check("login clean", #ERRORS == 0, #ERRORS .. " errors")

local main = _G.WhisperCastSWCastButton
check("Cast button exists, secure, by its binding name", main and main.__template == "SecureActionButtonTemplate")
check("window, note, folded icon and minimap button exist", _G.WhisperCastSWWindow and _G.WhisperCastSWToast
	and _G.WhisperCastSWFolded and _G.WhisperCastSWMinimapButton and true)
local wrap = main and WRAPS[main]
check("Cast button OnClick wrapped by a secure header", wrap and wrap.script == "OnClick" and wrap.header
	and wrap.header.__template == "SecureHandlerBaseTemplate")
check("three looks listed in order", #WCSW.LOOKS == 3 and WCSW.LOOKS[1].key == "suite" and WCSW.LOOKS[2].key == "blizzard"
	and WCSW.LOOKS[3].key == "flat" and WCSW.LOOKS.flat == WCSW.LOOKS[3])
for _, w in ipairs({ "toggle", "show", "hide", "fold", "lock", "unlock", "reset" }) do
	check("slash word " .. w, type(WCSW.slash[w]) == "function")
end

---------------------------------------------------------------- protected-call guard
local PROTECTED = { "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize",
	"SetWidth", "SetHeight", "SetScale", "SetParent", "EnableMouse", "StartMoving", "RegisterForClicks" }
local guarded = {}
local function Guard(f, label, cond)
	if not f or guarded[f] then return end
	guarded[f] = true
	for _, m in ipairs(PROTECTED) do
		local orig = f[m]
		rawset(f, m, function(self, ...)
			if LOCKDOWN and (not cond or cond()) then VIOLATIONS[#VIOLATIONS + 1] = label .. ":" .. m end
			return orig(self, ...)
		end)
	end
end
Guard(main, "CastButton")
Guard(W.frame, "Window(classic)", function() return W.Protected() end)

-- the restricted snippets, run as the secure environment would: self's attributes and PlayerInCombat()
local function Snippet(body, args)
	local env = { PlayerInCombat = function() return LOCKDOWN end }
	return load("return function(" .. args .. ")\n" .. body .. "\nend", "=snippet", "t", env)()
end
local function SecureSelf(b)
	return { GetAttribute = function(_, k) return b.__attr and b.__attr[k] end,
		SetAttribute = function(_, k, v) b.__attr = b.__attr or {}; b.__attr[k] = v end }
end
CASTS = {}
-- one event of a press (down or up), in the game's order: PreClick, the wrap's pre, the template, post, PostClick
local function Press(b, down)
	local pre = b.__scripts.PreClick
	if pre then pre(b, "LeftButton", down) end
	local w, msg, allow = WRAPS[b], nil, true
	if w then
		local r1, r2 = Snippet(w.pre, "self, button, down")(SecureSelf(b), "LeftButton", down)
		if r1 == false then allow = false end
		msg = r2
	end
	if allow then
		local keyDown = CVARS.ActionButtonUseKeyDown and true or false
		local acts = (down and keyDown) or (not down and not keyDown)
		local a = b.__attr or {}
		if acts and a.type == "spell" then CASTS[#CASTS + 1] = { button = b, spell = a.spell, unit = a.unit } end
	end
	if w and msg ~= nil then Snippet(w.post, "self, message, button, down")(SecureSelf(b), msg, "LeftButton", down) end
	local post = b.__scripts.PostClick
	if post then post(b, "LeftButton", down) end
end
local function Click(b) Press(b, true); Press(b, false) end
local function attr(b, k) return b.__attr and b.__attr[k] end

---------------------------------------------------------------- the fake queue
local REAL = { GetView = WCSW.GetView, NextCast = WCSW.NextCast, CastClicked = WCSW.CastClicked, ClearQueue = WCSW.ClearQueue }
WCSW.spells = WCSW.spells or {}
local SP = {
	t_fort = { key = "t_fort", id = 1243, name = "Power Word: Fortitude", icon = 135987, group = "t_pfort" },
	t_pfort = { key = "t_pfort", id = 21562, name = "Prayer of Fortitude", icon = 135941, isGroup = true },
	t_shadow = { key = "t_shadow", id = 976, name = "Shadow Protection", icon = 136121 },
	t_fear = { key = "t_fear", id = 6346, name = "Fear Ward", icon = 135902 },
}
for k, s in pairs(SP) do WCSW.spells[k] = s end
local FAKE = { queue = {}, combat = false, armed = nil, clicked = {}, cleared = 0 }
local nextID = 0
local function Req(name, class, spell, unit, party, ago)
	nextID = nextID + 1
	return { id = nextID, name = name .. "-Realm", short = name, class = class, unit = unit, spell = spell,
		castID = SP[spell].id + 1, rank = 6, party = party or 1, time = GetTime() - (ago or 5), fails = 0 }
end
local function castOf(req) return { castID = req.castID, unit = req.unit, spell = req.spell, reqs = { req } } end
local function FakeNextCast()
	if FAKE.combat then
		local c = FAKE.armed
		return (c and not c.reqs[1].done) and c or nil
	end
	for _, r in ipairs(FAKE.queue) do if not r.done then return castOf(r) end end
	return nil
end
local function FakeView()
	local v = { count = 0, inCombat = FAKE.combat, groups = {}, rest = {} }
	for _, r in ipairs(FAKE.queue) do if not r.done then v.count = v.count + 1 end end
	v.armed = FAKE.combat and FAKE.armed and FAKE.armed.reqs[1] or nil
	v.next = v.armed
	if not v.next then for _, r in ipairs(FAKE.queue) do if not r.done then v.next = r; break end end end
	for _, r in ipairs(FAKE.queue) do if r ~= v.next then v.rest[#v.rest + 1] = r end end
	if P.window.grouped then
		local by = {}
		for _, r in ipairs(v.rest) do
			local g = by[r.spell]
			if not g then g = { spell = r.spell, count = 0, askers = {} }; by[r.spell] = g; v.groups[#v.groups + 1] = g end
			g.count = g.count + 1
			g.askers[#g.askers + 1] = r
		end
		-- the group version: all fort askers in group 2
		local fortG = {}
		for _, r in ipairs(FAKE.queue) do if r.spell == "t_fort" and r.party == 2 then fortG[#fortG + 1] = r end end
		if by.t_fort and #fortG >= 2 then by.t_fort.groupCast = { spell = "t_pfort", party = 2, askers = fortG } end
		v.rest = {}
	end
	return v
end
local function UseFake()
	WCSW.GetView = function() return FakeView() end
	WCSW.NextCast = function() return FakeNextCast() end
	WCSW.CastClicked = function(_, cast) FAKE.clicked[#FAKE.clicked + 1] = cast end
	WCSW.ClearQueue = function() FAKE.cleared = FAKE.cleared + 1; wipe(FAKE.queue); WCSW:Fire("QueueChanged") end
end
UseFake()
local function Changed() WCSW:Fire("QueueChanged") end
local function SetQueue(list) FAKE.queue = list; Changed() end
local function Five()
	return {
		Req("Ilyra", "MAGE", "t_shadow", "party2", 2, 30),
		Req("Brannoc", "WARRIOR", "t_fort", "party1", 2, 21),
		Req("Pippet", "ROGUE", "t_fort", "party3", 2, 12),
		Req("Thornwick", "DRUID", "t_fort", "party4", 2, 8),
		Req("Odessa", "HUNTER", "t_fear", "raid7", 3, 2),
	}
end

local win = W.frame
local spot = win.spot

---------------------------------------------------------------- looks
local e0 = #ERRORS
for _, look in ipairs(WCSW.LOOKS) do
	P.window.look = look.key
	WCSW:Fire("LookChanged")
	SetQueue(Five())
	check("look " .. look.key .. " draws clean", #ERRORS == e0, #ERRORS - e0 .. " errors")
end
P.window.look = "suite"
local r, g, b, a = WCSW:LookColor("bg")
check("Suite dark bg rgba(13,13,20,0.9)", near(r, 13 / 255) and near(g, 13 / 255) and near(b, 20 / 255) and near(a, 0.9))
r, g, b, a = WCSW:LookColor("edge")
check("Suite dark edge rgba(140,89,140,0.85)", near(r, 140 / 255) and near(g, 89 / 255) and near(b, 140 / 255) and near(a, 0.85))
r, g, b = WCSW:LookColor("title")
check("Suite dark title is the accent pink", near(r, 1) and near(g, 0.5) and near(b, 1))
P.window.look = "blizzard"
r, g, b = WCSW:LookColor("edge")
check("Blizzard classic edge #b8902f", near(r, 0xb8 / 255) and near(g, 0x90 / 255) and near(b, 0x2f / 255))
r, g, b = WCSW:LookColor("title")
check("Blizzard classic title gold #ffd100", near(r, 1) and near(g, 0xd1 / 255) and near(b, 0))
local _, _, _, _, r2, g2, b2 = UI.BgColors()
check("Blizzard classic gradient to #120b06", near(r2, 0x12 / 255) and near(g2, 0x0b / 255) and near(b2, 0x06 / 255))
P.window.look = "flat"
r, g, b, a = WCSW:LookColor("bg")
check("Flat modern bg rgba(6,6,8,0.84)", near(r, 6 / 255) and near(b, 8 / 255) and near(a, 0.84))
r, g, b = WCSW:LookColor("title")
check("Flat modern title white", near(r, 1) and near(g, 1) and near(b, 1))
WCSW:Fire("LookChanged")
check("Flat modern: accent line across the top, no row bars", win.topLine:IsShown() and not win.edgeLine.bars[1]:IsShown())
P.window.look = "suite"
P.window.colors.accent = { 0, 1, 0, 1 }
P.window.colors.bg = { 0.2, 0.3, 0.4, 0.5 }
r, g, b = WCSW:LookColor("accent")
check("colour override (by position) honoured: accent", near(r, 0) and near(g, 1) and near(b, 0))
r, g, b = WCSW:LookColor("title")
check("Suite dark title follows a set accent", near(g, 1) and near(r, 0))
r, g, b, a = WCSW:LookColor("bg")
check("colour override honoured: bg with its opacity", near(r, 0.2) and near(a, 0.5))
WCSW:ResetLookColors()
r, g, b = WCSW:LookColor("accent")
check("Reset to the look's colours", near(r, 1) and near(g, 0.5) and next(P.window.colors) == nil)
P.window.fontSize = 16
check("font size 16 scales a 12 px line to 16", near(WCSW:FontPx(12), 16))
P.window.fontSize = 12
local scaled
rawset(win, "SetScale", function(self, s) scaled = s end)
P.window.scale = 1.5
WCSW:Fire("LookChanged")
check("window scale applied", scaled == 1.5)
P.window.scale = 1
WCSW:Fire("LookChanged")

---------------------------------------------------------------- grouped (the default)
SetQueue(Five())
check("window shown with requests", win:IsShown())
check("count badge 5", win.badge:IsShown() and win.badge.text:GetText() == "5")
check("spotlight: NEXT · F", spot.l1:GetText() == "NEXT \194\183 F", spot.l1:GetText())
check("spotlight: the asker's name", spot.l2:GetText() == "Ilyra", spot.l2:GetText())
check("spotlight: the spell with its rank on ranked clients", (spot.l3:GetText() or ""):find("Shadow Protection", 1, true)
	and ((WCSW.hasRanks and (spot.l3:GetText()):find("R6", 1, true)) or (not WCSW.hasRanks and not (spot.l3:GetText()):find("R6", 1, true))), spot.l3:GetText())
check("THEN heading", win.head:IsShown() and win.head:GetText() == "THEN")
check("grouped: a row per spell (2)", W.shownRows == 2, W.shownRows)
-- read the pooled rows through the module's frame children
local function poolRows()
	local groups, reqs = {}, {}
	for _, f in ipairs(GetAllFrames()) do
		if f.kind == "group" and f:IsShown() then groups[#groups + 1] = f end
		if f.kind == "req" and f:IsShown() then reqs[#reqs + 1] = f end
	end
	return groups, reqs
end
local groups = poolRows()
local fortRow
for _, row in ipairs(groups) do if row.spell:GetText() == "Power Word: Fortitude" then fortRow = row end end
check("grouped: Fortitude row counts 3", fortRow and fortRow.count:GetText() == "3")
check("grouped: the askers in class colours on one line", fortRow and fortRow.who:IsShown()
	and (fortRow.who:GetText() or ""):find("Brannoc", 1, true) and (fortRow.who:GetText()):find("Thornwick", 1, true))
check("grouped: the group spell hint", fortRow and fortRow.hint:IsShown()
	and fortRow.hint:GetText() == "All 3 in group 2: Prayer of Fortitude covers them", fortRow and fortRow.hint:GetText())
-- the Engine's own hint line wins (the Greater Blessing one is by class)
local fakeViewPlain = FakeView
FakeView = function()
	local v = fakeViewPlain()
	for _, grp in ipairs(v.groups) do
		if grp.groupCast then grp.groupCast.hint = "All 2 Warriors: Greater Blessing of Kings covers them" end
	end
	return v
end
Changed()
groups = poolRows()
fortRow = nil
for _, row in ipairs(groups) do if row.spell:GetText() == "Power Word: Fortitude" then fortRow = row end end
check("grouped: the Engine's hint line drawn as given (class version)", fortRow and fortRow.hint:IsShown()
	and fortRow.hint:GetText() == "All 2 Warriors: Greater Blessing of Kings covers them", fortRow and fortRow.hint:GetText())
FakeView = fakeViewPlain
Changed()
check("Cast button set out of combat: type spell", attr(main, "type") == "spell")
check("Cast button set out of combat: the rank's spell ID", attr(main, "spell") == SP.t_shadow.id + 1, attr(main, "spell"))
check("Cast button set out of combat: the asker's unit", attr(main, "unit") == "party2")
check("Cast button: key and count", main.key:GetText() == "F" and main.count:GetText() == "5")
check("Cast button: the asker and spell under it", main.name:IsShown() and main.name:GetText() == "Ilyra"
	and main.spellText:GetText() == "Shadow Protection")
check("Cast button glows while something waits", main.glow:IsShown())
P.castButton.label = false
Changed()
check("Cast button label off", not main.name:IsShown())
P.castButton.label = true
check("glowing edge while something waits", win.glow:IsShown())
P.window.glow = false
Changed()
check("glowing edge setting off", not win.glow:IsShown())
P.window.glow = true

-- a press out of combat: the Engine hears it once, the cast goes out, the type stays
FAKE.clicked = {}
CASTS = {}
Click(main)
check("press out of combat: CastClicked once", #FAKE.clicked == 1 and FAKE.clicked[1].reqs[1].short == "Ilyra")
check("press out of combat: one cast on the asker", #CASTS == 1 and CASTS[1].unit == "party2")
check("press out of combat: the type stays (no wrap out of combat)", attr(main, "type") == "spell")
CVARS.ActionButtonUseKeyDown = true
FAKE.clicked, CASTS = {}, {}
Click(main)
check("key-down setting: still one CastClicked and one cast", #FAKE.clicked == 1 and #CASTS == 1)
CVARS.ActionButtonUseKeyDown = false

---------------------------------------------------------------- ungrouped, +N more, empty
P.window.grouped = false
SetQueue(Five())
local _, reqs = poolRows()
check("ungrouped: a row per request (4)", #reqs == 4 and W.shownRows == 4, #reqs)
check("ungrouped: waited time on each row", reqs[1] and (reqs[1].time:GetText() or ""):match("^%d+s$"), reqs[1] and reqs[1].time:GetText())
local many = {}
for i = 1, 14 do many[i] = Req("Name" .. i, "PRIEST", "t_fort", "raid" .. i, 1, i) end
SetQueue(many)
check("ten rows under the spotlight, then +N more", W.shownRows == 10 and win.more:IsShown()
	and win.more:GetText() == "+3 more", tostring(W.shownRows) .. " " .. tostring(win.more:GetText()))
P.window.grouped = true
SetQueue(many)
check("grouped with many: one row and no +N more", W.shownRows == 1 and not win.more:IsShown())
SetQueue({})
check("empty: No requests", spot.l2:GetText() == "No requests" and not spot.l1:IsShown())
check("empty: no badge, no glow", not win.badge:IsShown() and not win.glow:IsShown())
check("empty: Cast button casts nothing", attr(main, "type") == nil)
check("empty: Cast button dims the logo", main.icon:GetTexture() == WCSW.LOGO and main.icon:GetAlpha() == 0.4)
P.window.showWhenEmpty = false
Changed()
check("show when empty off: window hides", not win:IsShown())
P.window.showWhenEmpty = true
Changed()
check("show when empty on: window back", win:IsShown())
P.castButton.empty = "hide"
Changed()
check("empty look hide: Cast button hidden out of combat", not main:IsShown())
P.castButton.empty = "dim"
Changed()
check("empty look dim: Cast button shown", main:IsShown())

---------------------------------------------------------------- combat: first one stays ready
local function EnterCombat()
	FAKE.armed = FakeNextCast()
	FAKE.combat = true
	FireEvent("PLAYER_REGEN_DISABLED")   -- before the lockdown, as the game does
	LOCKDOWN = true
	Changed()
end
local function LeaveCombat()
	LOCKDOWN = false
	FAKE.combat = false
	for i = #FAKE.queue, 1, -1 do if FAKE.queue[i].done then table.remove(FAKE.queue, i) end end
	FAKE.armed = nil
	FireEvent("PLAYER_REGEN_ENABLED")
	Changed()
end
local v0 = #VIOLATIONS
P.window.grouped = false
SetQueue({ Req("Thornwick", "DRUID", "t_shadow", "party4", 1, 9), Req("Ilyra", "MAGE", "t_fear", "party2", 1, 4) })
EnterCombat()
check("combat: IN COMBAT label", win.fight:IsShown())
check("combat: the lock row", win.lock:IsShown() and win.lock.text:GetText() == "Casts wait until the fight ends")
check("combat: armed in the spotlight with <key> READY", spot.tag:IsShown() and spot.tag.text:GetText() == "F READY"
	and spot.armedLine.bars[1]:IsShown(), spot.tag.text:GetText())
_, reqs = poolRows()
check("combat: the rest greyed with after", reqs[1] and reqs[1]:GetAlpha() == 0.45 and reqs[1].time:GetText() == "after")
local armedSpell = attr(main, "spell")
-- a request arrives in combat: queued, but the button keeps the armed cast
table.insert(FAKE.queue, 1, Req("Zed", "WARLOCK", "t_fort", "party3", 1, 0))
Changed()
WCSW:Fire("RequestAdded", FAKE.queue[1])
check("combat: a new request doesn't change the armed cast", attr(main, "spell") == armedSpell and attr(main, "unit") == "party4")
check("combat: count badge counts it", win.badge.text:GetText() == "3")
FAKE.clicked, CASTS = {}, {}
Click(main)
check("combat press: the armed request casts once", #CASTS == 1 and CASTS[1].unit == "party4")
check("combat press: CastClicked with the armed cast", #FAKE.clicked == 1 and FAKE.clicked[1].reqs[1].short == "Thornwick")
check("combat press: the wrap cleared the type", attr(main, "type") == nil)
FAKE.queue[2].done = true
Changed()
check("combat press: the spotlight says CAST", spot.tag.text:GetText() == "CAST")
FAKE.clicked, CASTS = {}, {}
Click(main)
check("combat: a second press casts nothing", #CASTS == 0 and #FAKE.clicked == 0)
P.window.lockRow = false
Changed()
check("combat: lock row off", not win.lock:IsShown())
P.window.lockRow = true
P.window.combat = "fade"
Changed()
check("combat: fade to the opacity setting", win:IsShown() and near(win:GetAlpha(), 0.4))
P.window.combat = "hide"
Changed()
check("combat: hide", not win:IsShown())
P.window.combat = "show"
Changed()
check("combat: show", win:IsShown() and win:GetAlpha() == 1)
check("combat: no protected call on the Cast button", #VIOLATIONS == v0, table.concat(VIOLATIONS, ", "))
LeaveCombat()
check("after combat: set up again from the next cast", attr(main, "type") == "spell" and attr(main, "unit") == "party3", attr(main, "unit"))
check("after combat: no IN COMBAT, no lock row", not win.fight:IsShown() and not win.lock:IsShown())
check("after combat: not spent", CB.spent == false)

---------------------------------------------------------------- the classic buttons on the window
P.window.classicButtons = true
WCSW:Fire("LookChanged")
local wcast = _G.WhisperCastSWWindowCast
check("classic: the window's Cast is a secure button", wcast and wcast.__template == "SecureActionButtonTemplate")
check("classic: it is kept in step", wcast and attr(wcast, "type") == "spell" and attr(wcast, "unit") == attr(main, "unit")
	and attr(wcast, "spell") == attr(main, "spell"))
check("classic: Cast shows the key", wcast and (wcast.text:GetText() or ""):find("F", 1, true))
Guard(wcast, "WindowCast")
check("classic: the window holds it", W.Protected())
v0 = #VIOLATIONS
SetQueue({ Req("Brannoc", "WARRIOR", "t_fort", "party1", 1, 3) })
P.window.combat = "hide"
EnterCombat()
check("classic: hide in combat at the pull leaves it shown, faded", win:IsShown() and near(win:GetAlpha(), 0.4), win:GetAlpha())
P.window.combat = "show"
Changed()
for i = 1, 4 do table.insert(FAKE.queue, Req("Late" .. i, "MAGE", "t_fear", "raid" .. i, 1, 0)) end
Changed()
P.window.combat = "hide"
Changed()
check("classic in combat: hide fades at the opacity setting, still shown", win:IsShown() and near(win:GetAlpha(), 0.4), win:GetAlpha())
P.window.combatAlpha = 0.1
Changed()
check("classic in combat: hide never fades below 0.25", win:IsShown() and near(win:GetAlpha(), 0.25), win:GetAlpha())
P.window.shown = false
Changed()
check("classic in combat: closed mid-fight stays visible (faded), never clear", win:IsShown() and win:GetAlpha() >= 0.25)
P.window.shown, P.window.combatAlpha = true, 0.4
P.window.combat = "show"
Changed()
check("classic in combat: no protected call on the window or either Cast", #VIOLATIONS == v0, table.concat(VIOLATIONS, ", "))
FAKE.clicked, CASTS = {}, {}
Click(wcast)
check("classic in combat: the window's Cast casts the armed one once", #CASTS == 1 and CASTS[1].unit == "party1")
LeaveCombat()
_G.WhisperCastSWWindowClear.__scripts.OnClick(_G.WhisperCastSWWindowClear)
check("classic: Clear empties the queue", FAKE.cleared == 1 and #FAKE.queue == 0)
P.window.classicButtons = false
WCSW:Fire("LookChanged")
check("classic off: the window lets go of it", not W.Protected() and not wcast:IsShown())

---------------------------------------------------------------- CooldownCollaborator's second button
local parent = CreateFrame("Frame", "CDCAsks", UIParent)
local cdc = WCSW:CreateCastButton(parent)
Guard(cdc, "CDCButton")
SetQueue(Five())
check("CreateCastButton: a secure button on the parent", cdc and cdc.__template == "SecureActionButtonTemplate" and cdc:GetParent() == parent)
check("CreateCastButton: kept in step", attr(cdc, "type") == "spell" and attr(cdc, "spell") == attr(main, "spell") and attr(cdc, "unit") == attr(main, "unit"))
check("CreateCastButton: wrapped too", WRAPS[cdc] ~= nil)

---------------------------------------------------------------- fold, slash words
local fb = F.button
WCSW:SetFolded(true)
check("fold: window hidden, round icon shown", not win:IsShown() and fb:IsShown())
check("fold: remembered in the settings", P.window.folded == true)
fb.__scripts.OnClick(fb, "LeftButton")
check("round icon left-click opens the window", win:IsShown() and not fb:IsShown() and P.window.folded == false)
WCSW:OnSlash("fold")
check("/wc fold folds", P.window.folded and not win:IsShown())
WCSW:OnSlash("fold")
check("/wc fold again opens", not P.window.folded and win:IsShown())
WCSW:OnSlash("")
check("/wc toggles it shut", not win:IsShown() and P.window.shown == false)
WCSW:OnSlash("")
check("/wc toggles it open", win:IsShown())
WCSW:OnSlash("hide")
check("/wc hide", not win:IsShown())
WCSW:OnSlash("show")
check("/wc show", win:IsShown())
T:Clear()
WCSW:OnSlash("unlock")
check("/wc unlock", P.unlocked == true)
check("unlocked: the Cast button casts nothing while it can be dragged", attr(main, "type") == nil)
check("unlocked: the note shows where it goes", T.holder:IsShown() and T.holder.sample:IsShown())
win.bar.__scripts.OnDragStart(win.bar)
win.bar.__scripts.OnDragStop(win.bar)
check("unlocked: dragging the window saves its place (by its top left)", type(P.window.point) == "table" and P.window.point[1] == "TOPLEFT")
main.__scripts.OnDragStart(main)
main.__scripts.OnDragStop(main)
check("unlocked: dragging the Cast button saves its place", type(P.castButton.point) == "table")
WCSW:OnSlash("lock")
check("/wc lock", P.unlocked == false and attr(main, "type") == "spell" and not T.holder:IsShown())
-- the Options lane's toggle: only the setting and the event
P.unlocked = true
WCSW:Fire("LockChanged", true)
check("LockChanged from the settings unlocks", attr(main, "type") == nil and T.holder.sample:IsShown())
P.unlocked = false
WCSW:Fire("LockChanged", false)
WCSW:OnSlash("reset")
check("/wc reset forgets every place", P.window.point == nil and P.castButton.point == nil and P.toast.point == nil and P.folded.point == nil)
check("after reset the note sits beside the window", select(2, T.holder:GetPoint(1)) == win)

---------------------------------------------------------------- folded icon settings
P.folded.show = "always"
P.folded.size = 50
WCSW:Fire("LookChanged")
check("folded: shown always", fb:IsShown())
check("folded: size", fb:GetWidth() == 50)
check("folded: badge and glow while something waits", fb.badge:IsShown() and fb.badge.text:GetText() == "5" and fb.roundGlow:IsShown())
P.folded.badge, P.folded.glow, P.folded.ring = false, false, false
F:Draw()
check("folded: badge, glow and ring off", not fb.badge:IsShown() and not fb.roundGlow:IsShown() and not fb.ring:IsShown())
P.folded.badge, P.folded.glow, P.folded.ring = true, true, true
P.folded.art = "next"
F:Draw()
check("folded: the next request's spell icon", fb.icon:GetTexture() == SP.t_shadow.icon, fb.icon:GetTexture())
P.folded.art = "logo"
F:Draw()
check("folded: the logo", fb.icon:GetTexture() == WCSW.LOGO)
P.folded.alphaOut, P.folded.alphaIn = 0.5, 0.25
F:Draw()
check("folded: opacity out of combat", near(fb:GetAlpha(), 0.5))
EnterCombat()
check("folded: opacity in combat", near(fb:GetAlpha(), 0.25))
LeaveCombat()
P.folded.alphaOut, P.folded.alphaIn = 1, 1
P.folded.show = "waiting"
SetQueue({})
check("folded: only while something waits (empty: hidden)", not fb:IsShown())
SetQueue(Five())
check("folded: only while something waits (waiting: shown)", fb:IsShown())
P.folded.show = "folded"
P.folded.size = 34
WCSW:Fire("LookChanged")
check("folded: only while folded", not fb:IsShown())
fb.__scripts.OnClick(fb, "RightButton")

---------------------------------------------------------------- the note and the sound
T:Clear()
P.toast.max, P.toast.duration = 3, 3
for i = 1, 4 do WCSW:Fire("RequestAdded", FAKE.queue[i]) end
check("note: four in a row stack up to 3", T:Count() == 3 and T.holder:IsShown())
RunOnUpdate(0.5, 5)
check("note: still up within its time", T:Count() == 3)
RunOnUpdate(0.25, 3)
check("note: fading after its time", T:Count() == 3 and T.holder.sample:GetAlpha() == 1 and (function()
	for _, f in ipairs(GetAllFrames()) do if f:GetParent() == T.holder and f ~= T.holder.sample and f:IsShown() and f:GetAlpha() < 1 then return true end end
end)())
RunOnUpdate(0.25, 2)
check("note: gone after its time and fade", T:Count() == 0 and not T.holder:IsShown())
P.toast.duration = 6
WCSW:Fire("RequestAdded", FAKE.queue[1])
RunOnUpdate(0.5, 9)
check("note: the time setting holds it longer", T:Count() == 1)
T:Clear()
P.toast.enabled = false
WCSW:Fire("RequestAdded", FAKE.queue[1])
check("note: off", T:Count() == 0)
P.toast.enabled, P.toast.duration = true, 3
local tscale
rawset(T.holder, "SetScale", function(_, s) tscale = s end)
P.toast.scale = 1.5
WCSW:Fire("LookChanged")
check("note: its scale", tscale == 1.5)
P.toast.scale = 1
-- sound: first (the 2007 rule), every, off, the picked one, LibSharedMedia
PLAYED = {}
SetQueue({ Req("Solo", "MAGE", "t_fear", "party1", 1, 0) })
WCSW:Fire("RequestAdded", FAKE.queue[1])
check("sound first: plays when the queue goes from empty to one", #PLAYED == 1 and PLAYED[1][1] == "kit" and PLAYED[1][2] == 3081)
table.insert(FAKE.queue, Req("Duo", "MAGE", "t_fear", "party2", 1, 0))
WCSW:Fire("RequestAdded", FAKE.queue[2])
check("sound first: not for the second", #PLAYED == 1)
P.sound.when = "every"
WCSW:Fire("RequestAdded", FAKE.queue[2])
check("sound every: plays for each", #PLAYED == 2)
P.sound.enabled = false
WCSW:Fire("RequestAdded", FAKE.queue[2])
check("sound off: silent for requests", #PLAYED == 2)
WCSW:PlayRequestSound()
check("PlayRequestSound() with no key plays the picked sound even when off", #PLAYED == 3)
P.sound.enabled, P.sound.when = true, "first"
P.sound.name = "Blizzard: Raid Warning"
WCSW:PlayRequestSound()
check("a checked Blizzard sound plays by file ID", PLAYED[#PLAYED][1] == "file" and PLAYED[#PLAYED][2] == 567397)
LibStub("LibSharedMedia-3.0"):Register("sound", "Harness Ding", "Interface\\AddOns\\X\\ding.ogg")
P.sound.name = "Harness Ding"
WCSW:PlayRequestSound()
check("a LibSharedMedia sound plays by path", PLAYED[#PLAYED][2] == "Interface\\AddOns\\X\\ding.ogg")
check("SoundValues lists both", WCSW:SoundValues()["TELL_MESSAGE"] and WCSW:SoundValues()["Harness Ding"])
P.sound.name = "TELL_MESSAGE"

---------------------------------------------------------------- Masque absent, then present
check("Masque absent: own frame line, no group", main.wcswMasque == nil and main.line1.bars[1]:IsShown())
local groupsMade = {}
local MSQ = LibStub:NewLibrary("Masque", 1)
function MSQ:Group(addon, sub)
	local grp = { addon = addon, sub = sub, buttons = {} }
	function grp:AddButton(btn, regions) self.buttons[#self.buttons + 1] = { btn, regions } end
	function grp:RemoveButton() end
	function grp:RegisterCallback(fn) self.cb = fn end
	groupsMade[#groupsMade + 1] = grp
	return grp
end
WCSW:RefreshAll()
local castGroup, foldGroup
for _, grp in ipairs(groupsMade) do
	if grp.sub == "Cast button" then castGroup = grp end
	if grp.sub == "Folded icon" then foldGroup = grp end
end
check("Masque present: group WhisperCast: Second Wind / Cast button", castGroup and castGroup.addon == "WhisperCast: Second Wind"
	and castGroup.buttons[1] and castGroup.buttons[1][1] == main and castGroup.buttons[1][2].Icon == main.icon)
check("Masque present: group Folded icon", foldGroup and foldGroup.buttons[1] and foldGroup.buttons[1][1] == fb)
check("Masque present: Masque draws the frame line", not main.line1.bars[1]:IsShown())
main._MSQ_CFG = { Shape = "Circle" }
CB:Draw()
check("Masque round skin: the round glow", main.roundGlow:IsShown() and not main.glow:IsShown())
main._MSQ_CFG = nil
fb._MSQ_CFG = { Shape = "Square" }
P.folded.show = "always"
F:Draw()
check("Masque square skin on the folded icon: square glow, no mask", fb.glow:IsShown() and not fb.roundGlow:IsShown() and fb.masked == false)
P.folded.show = "folded"
fb._MSQ_CFG = nil
if castGroup.cb then castGroup.cb() end
check("Masque skin change redraws clean", #ERRORS == 0)

---------------------------------------------------------------- Edit Mode
local LEM = LibStub("LibEditMode", true)
if FLAVOR == "era" then
	check("Era: no LibEditMode, no Edit Mode module", LEM == nil and WCSW.EditMode == nil)
	check("Era: unlock-and-drag still saves (tested above)", type(P.window.point) == "table" or P.window.point == nil)
else
	local EMframes = {}
	for f, info in pairs(LEM.frames) do EMframes[f] = info end
	check("Edit Mode: the window, Cast button, note and folded icon", EMframes[win] and EMframes[main] and EMframes[T.holder] and EMframes[fb] and true)
	local ts, bs = LEM_SETTINGS[T.holder], LEM_SETTINGS[main]
	check("Edit Mode: the note's scale slider 0.5 to 2", ts and ts[1] and ts[1].minValue == 0.5 and ts[1].maxValue == 2)
	check("Edit Mode: the Cast button's size slider 24 to 64", bs and bs[1] and bs[1].minValue == 24 and bs[1].maxValue == 64)
	if ts and ts[1] then
		ts[1].set("Modern", 1.25)
		check("Edit Mode: the note's slider sets its scale", P.toast.scale == 1.25 and tscale == 1.25)
		P.toast.scale = 1
	end
	if bs and bs[1] then
		bs[1].set("Modern", 48)
		check("Edit Mode: the button's slider sets its size", P.castButton.size == 48 and main:GetWidth() == 48)
		P.castButton.size = 40
		WCSW:Fire("LookChanged")
	end
	EMframes[win].cb(win, "Modern", "CENTER", 10, 20)
	check("Edit Mode: a move is kept for the layout", P.window.editMode.Modern and P.window.editMode.Modern.point == "TOPLEFT")
	P.window.editMode.Raid = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 111, y = 222 }
	LEM.callbacks.layout("Raid")
	check("Edit Mode: switching layout moves it there", P.window.point and P.window.point[3] == 111 and P.window.point[4] == 222)
	LEM.callbacks.rename("Raid", "Raid 2")
	check("Edit Mode: a renamed layout keeps its places", P.window.editMode["Raid 2"] and not P.window.editMode.Raid)
	LEM.callbacks.delete("Raid 2")
	check("Edit Mode: a deleted layout forgets them", not P.window.editMode["Raid 2"])
	T:Clear()
	LEM.callbacks.enter()
	check("Edit Mode open: frames show to be placed", UI.editing and T.holder:IsShown() and fb:IsShown())
	LEM.callbacks.exit()
	check("Edit Mode closed: back as they were", not UI.editing and not T.holder:IsShown() and not fb:IsShown())
end

---------------------------------------------------------------- minimap button
local mm = _G.WhisperCastSWMinimapButton
local opened
WCSW.OpenSettings = function(_, tab) opened = tab or "main" end
P.minimap.hide = true
WCSW:RefreshAll()
check("minimap: hidden by the setting", not mm:IsShown())
P.minimap.hide = false
WCSW:RefreshAll()
check("minimap: shown", mm:IsShown())
local before = win:IsShown()
mm.__scripts.OnClick(mm, "LeftButton")
check("minimap left-click toggles the window", win:IsShown() ~= before)
mm.__scripts.OnClick(mm, "LeftButton")
mm.__scripts.OnClick(mm, "RightButton")
check("minimap right-click opens the settings", opened == "main")
opened = nil
fb.__scripts.OnClick(fb, "RightButton")
check("folded right-click opens the settings on its tab", opened == "folded")

check("no protected call in combat anywhere (fake queue)", #VIOLATIONS == 0, table.concat(VIOLATIONS, ", "))

---------------------------------------------------------------- the real Engine
if REAL.GetView and REAL.NextCast and WCSW.OnWhisper then
	WCSW.GetView, WCSW.NextCast, WCSW.CastClicked, WCSW.ClearQueue = REAL.GetView, REAL.NextCast, REAL.CastClicked, REAL.ClearQueue
	for k in pairs(SP) do WCSW.spells[k] = nil end
	-- a party of two; the player knows every spell this client lists for priests
	local PARTY = { party1 = { "Brannoc", "WARRIOR" }, party2 = { "Ilyra", "MAGE" } }
	local rawUnitName, rawUnitClass, rawUnitExists = UnitName, UnitClass, UnitExists
	UnitName = function(u) if PARTY[u] then return PARTY[u][1], nil end return rawUnitName(u) end
	UnitClass = function(u) if PARTY[u] then return PARTY[u][2], PARTY[u][2], 1 end return rawUnitClass(u) end
	UnitExists = function(u) return PARTY[u] ~= nil or rawUnitExists(u) end
	IsInGroup = function() return true end
	GetNumGroupMembers = function() return 3 end
	IsPlayerSpell = function() return true end
	WCSW:RefreshKnown()
	FireEvent("GROUP_ROSTER_UPDATE")
	local word
	for _, key in ipairs(WCSW.spellOrder or {}) do
		local s = WCSW.spells[key]
		if s.known and not s.isGroup and s.words and s.words[1] then word = s.words[1]; break end
	end
	check("real Engine: a spell word to whisper", word ~= nil)
	if word then
		local e1 = #ERRORS
		FireEvent("CHAT_MSG_WHISPER", word, "Brannoc", "", "", "", "", 0, 0, "", 0, 1, "Player-1-2")
		local v = WCSW:GetView()
		check("real Engine: the whisper queues", v.count == 1, v.count)
		check("real Engine: the spotlight shows the asker", spot.l2:GetText() == "Brannoc", spot.l2:GetText())
		check("real Engine: the Cast button is set on them", attr(main, "type") == "spell" and attr(main, "unit") == "party1")
		FireEvent("CHAT_MSG_WHISPER", word, "Ilyra", "", "", "", "", 0, 0, "", 0, 1, "Player-1-3")
		FireEvent("PLAYER_REGEN_DISABLED")
		LOCKDOWN = true
		FireEvent("CHAT_MSG_WHISPER", word, "Ilyra", "", "", "", "", 0, 0, "", 0, 1, "Player-1-3")
		check("real Engine combat: armed with READY", spot.tag:IsShown() and spot.tag.text:GetText() == "F READY", spot.tag.text:GetText())
		CASTS = {}
		Click(main)
		Click(main)
		check("real Engine combat: one cast for two presses", #CASTS == 1)
		LOCKDOWN = false
		FireEvent("PLAYER_REGEN_ENABLED")
		check("real Engine: set up again after combat", attr(main, "type") == "spell")
		check("real Engine: drew clean", #ERRORS == e1, #ERRORS - e1 .. " errors")
		check("real Engine: no protected call in combat", #VIOLATIONS == 0, table.concat(VIOLATIONS, ", "))
	end
else
	print("  (the real Engine isn't there yet: fake queue only)")
end

for _, e in ipairs(ERRORS) do print("  FAIL lua error: " .. tostring(e):sub(1, 400)) end
print(string.format("  %d checks passed, %d failed", PASSES, FAILS))
print(string.format("RESULT %s ui: total lua errors %d", HARNESS_TOCFILE, #ERRORS + FAILS))
