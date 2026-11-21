-- Options lane harness: the real TOC, login, then the settings window (Options.lua) and the word
-- chips (Chips.lua) through their real code paths: the options tree validated, the window opened
-- on every tab, every setting set through its own set handler and read back, every slider's range
-- holding its default, words added / removed / doubled / blank through the chip widget's own
-- scripts, the colour overrides and their reset, the launcher in the game's AddOns list, the slash
-- word, and no label starting with spaces. PASS/FAIL per check; FAIL lines count as Lua errors.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = HARNESS_ARG ~= "" and HARNESS_ARG or "PRIEST"

local files = LoadTOC(HARNESS_TOCFILE)
print(string.format("[options %s %s %s] loaded %d toc entries, load errors: %d", HARNESS_TOCFILE, FLAVOR, PLAYER.class, #files, #ERRORS))
Login()
Advance(5.1)
RunOnUpdate(0.02, 30)

local WCSW = WhisperCastSW
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %s %s%s", ok and "PASS" or "FAIL", label, (not ok and detail) and (" (" .. tostring(detail) .. ")") or ""))
end
local function try(f, ...)
	local e0 = #ERRORS
	local ok, a, b, c, d = xpcall(f, ERRH, ...)
	return ok and #ERRORS == e0, a, b, c, d
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end
local function list(t) return table.concat(t or {}, ",") end

local O = WCSW and WCSW.Options
check("Options module loaded (WCSW.Options)", O ~= nil)
if not O then
	print(string.format("RESULT %s %s: total lua errors %d", HARNESS_TOCFILE, PLAYER.class, #ERRORS + fails))
	return
end
local APP = O.APP
local ACD = LibStub("AceConfigDialog-3.0")
local REG = LibStub("AceConfigRegistry-3.0")
local P = function() return WCSW.db.profile end

---------------------------------------------------------------- stubs: spells when the Engine has none yet
local stubbed = false
if type(WCSW.spells) ~= "table" or next(WCSW.spells) == nil then
	stubbed = true
	WCSW.spells = {
		fort = { key = "fort", id = 1243, name = "Power Word: Fortitude", icon = 135987, words = { "fort", "stam", "stamina" }, group = "pof" },
		pof = { key = "pof", id = 21562, name = "Prayer of Fortitude", icon = 135941, words = { "pof", "prayer" }, isGroup = true },
		shadow = { key = "shadow", id = 976, name = "Shadow Protection", icon = 136121, words = { "shadow", "sp" } },
	}
end
-- every spell counts as known for the window checks (the Engine's own answer is tested in its lane)
local realIsKnown = rawget(WCSW, "IsKnown")
local knownOverride = {}
WCSW.IsKnown = function(_, key) if knownOverride[key] ~= nil then return knownOverride[key] end return true end
O:UpdateSpells()
print(string.format("  spells: %s (%s)", stubbed and "harness stubs" or "the Engine's", (function()
	local n = 0 for _ in pairs(WCSW.spells) do n = n + 1 end return n end)()))

---------------------------------------------------------------- the tree
local okv, err = pcall(function() return REG:GetOptionsTable(APP, "dialog", "AceConfigDialog-3.0") end)
check("options tree validates (AceConfigRegistry)", okv, err)
local tree = O.tree
local TABS = { { "general", "General" }, { "spells", "Spells and words" }, { "window", "Window" }, { "castButton", "Cast button" },
	{ "alerts", "Alerts" }, { "folded", "Folded icon" }, { "profiles", "Profiles" } }
local tabsOk, last = true, -1
for _, t in ipairs(TABS) do
	local g = tree.args[t[1]]
	if not (g and g.type == "group" and (t[1] == "profiles" or g.name == t[2]) and (g.order or 100) > last) then tabsOk = false end
	last = g and (g.order or 100) or last
end
check("seven tabs in the handoff's order: General, Spells and words, Window, Cast button, Alerts, Folded icon, Profiles", tabsOk and tree.childGroups == "tab")
check("Profiles tab is AceDBOptions' (Reset, Copy From, Delete)", tree.args.profiles and tree.args.profiles.args.reset and tree.args.profiles.args.copyfrom ~= nil)

-- every option of a tab: { tab, key, option }
local function allOptions(skipSpells)
	local out = {}
	for _, t in ipairs(TABS) do
		if t[1] ~= "profiles" and not (skipSpells and t[1] == "spells") then
			for k, o in pairs(tree.args[t[1]].args) do out[#out + 1] = { t[1], k, o } end
		end
	end
	return out
end
local function val(o, member, ...)
	local m = o[member]
	if type(m) == "function" then return m({}, ...) end
	return m
end
local count = 0
for _, e in ipairs(allOptions(false)) do
	if e[3].type ~= "header" and e[3].type ~= "description" then count = count + 1 end
end
print(string.format("  controls: %d (headers and text not counted)", count))

---------------------------------------------------------------- labels
do
	local padded, seen = {}, {}
	local function walkOpts(t, path)
		if type(t) ~= "table" or seen[t] then return end
		seen[t] = true
		local name = t.name
		if type(name) == "function" then local ok, n = pcall(name, {}); name = ok and n or nil end
		if type(name) == "string" and t.type ~= "description" and name:match("^%s") then padded[#padded + 1] = path end
		if type(t.args) == "table" then for k, v in pairs(t.args) do walkOpts(v, path .. "." .. tostring(k)) end end
	end
	walkOpts(tree, "root")
	check("no control label starts with spaces", #padded == 0, table.concat(padded, ", "))
	local noDesc = {}
	for _, e in ipairs(allOptions(false)) do
		local o = e[3]
		if o.type ~= "header" and o.type ~= "description" and (type(o.desc) ~= "string" or o.desc == "") then
			noDesc[#noDesc + 1] = e[1] .. "." .. e[2]
		end
	end
	check("every control has a description", #noDesc == 0, table.concat(noDesc, ", "))
end

---------------------------------------------------------------- every saved setting has a control
do
	local missing = {}
	local opts = allOptions(true)
	local function snapshot()
		local s = {}
		for i, e in ipairs(opts) do
			local o = e[3]
			if type(o.get) == "function" then
				local ok, a, b, c, d = pcall(o.get, {})
				s[i] = ok and table.concat({ tostring(a), tostring(b), tostring(c), tostring(d) }, "|") or "err"
			end
		end
		return s
	end
	local skip = { point = true, editMode = true, colors = true, spells = true }
	local function leaves(def, live, path)
		for k, v in pairs(def) do
			if not skip[k] then
				local p = path == "" and k or (path .. "." .. k)
				if type(v) == "table" then
					leaves(v, live[k], p)
				else
					local before = snapshot()
					local old = live[k]
					if type(old) == "boolean" then live[k] = not old
					elseif type(old) == "number" then live[k] = old + 0.25
					else live[k] = "zz_test" end
					local after = snapshot()
					live[k] = old
					local seen = false
					for i in pairs(after) do if after[i] ~= before[i] then seen = true end end
					if not seen then missing[#missing + 1] = p end
				end
			end
		end
	end
	leaves(WCSW.defaults.profile, P(), "")
	for _, key in ipairs(O.COLOR_KEYS) do
		local before = snapshot()
		P().window.colors[key] = { 0.11, 0.22, 0.33, 0.44 }
		local after = snapshot()
		P().window.colors[key] = nil
		local seen = false
		for i in pairs(after) do if after[i] ~= before[i] then seen = true end end
		if not seen then missing[#missing + 1] = "window.colors." .. key end
	end
	check("every setting in WCSW.defaults has a control (positions aside)", #missing == 0, table.concat(missing, ", "))
end

---------------------------------------------------------------- slider ranges
do
	-- a fresh profile: the defaults
	WCSW.db:SetProfile("RangeCheck")
	local bad = {}
	for _, e in ipairs(allOptions(true)) do
		local o = e[3]
		if o.type == "range" then
			local d = o.get({})
			local steps = (d - o.min) / o.step
			if not (d >= o.min - 1e-9 and d <= o.max + 1e-9 and math.abs(steps - math.floor(steps + 0.5)) < 1e-6) then
				bad[#bad + 1] = string.format("%s.%s=%s [%s..%s/%s]", e[1], e[2], tostring(d), o.min, o.max, o.step)
			end
			if not (math.abs((o.max - o.min) / o.step - math.floor((o.max - o.min) / o.step + 0.5)) < 1e-6) then
				bad[#bad + 1] = e[2] .. " max not on a step"
			end
		end
	end
	check("every slider holds its default on a step, and reaches its max", #bad == 0, table.concat(bad, "; "))
	local want = {
		{ "window", "fontSize", 10, 16 }, { "window", "scale", 0.6, 2 }, { "alerts", "duration", 1, 10 }, { "alerts", "toastScale", 0.5, 2 },
		{ "castButton", "size", 24, 64 }, { "folded", "size", 20, 64 }, { "window", "combatAlpha", 0, 1 },
		{ "folded", "alphaOut", 0, 1 }, { "folded", "alphaIn", 0, 1 },
	}
	local wrong = {}
	for _, w in ipairs(want) do
		local o = tree.args[w[1]].args[w[2]]
		if not (o and near(o.min, w[3]) and near(o.max, w[4])) then wrong[#wrong + 1] = w[1] .. "." .. w[2] end
	end
	check("the handoff's ranges: font 10-16, scale 0.6-2, note time 1-10, note scale 0.5-2, button 24-64, icon 20-64, opacities 0-1", #wrong == 0, table.concat(wrong, ", "))
	WCSW.db:SetProfile("Default")
	WCSW.db:DeleteProfile("RangeCheck", true)
end

---------------------------------------------------------------- set every setting and read it back
do
	local looks, events = 0, 0
	local obs = {}
	WCSW.RegisterCallback(obs, "LookChanged", function() looks = looks + 1 end)
	local bad = {}
	local walked = 0
	for _, e in ipairs(allOptions(true)) do
		local tab, key, o = e[1], e[2], e[3]
		local id = tab .. "." .. key
		if o.type == "toggle" then
			walked = walked + 1
			local cur = o.get({})
			local ok = try(o.set, {}, not cur)
			if not ok or o.get({}) ~= (not cur) then bad[#bad + 1] = id end
			try(o.set, {}, cur)
			if o.get({}) ~= cur then bad[#bad + 1] = id .. " back" end
		elseif o.type == "range" then
			walked = walked + 1
			local cur = o.get({})
			for _, v in ipairs({ o.min, o.max, cur }) do
				local ok = try(o.set, {}, v)
				if not ok or not near(o.get({}), v) then bad[#bad + 1] = id .. "=" .. tostring(v) end
			end
		elseif o.type == "select" then
			walked = walked + 1
			local cur = o.get({})
			local values = val(o, "values")
			if type(values) ~= "table" or values[cur] == nil then bad[#bad + 1] = id .. " default not in its list" end
			local sorting = val(o, "sorting")
			if sorting ~= nil and type(sorting) ~= "table" then bad[#bad + 1] = id .. " sorting" end
			for k in pairs(values or {}) do
				local ok = try(o.set, {}, k)
				if not ok or o.get({}) ~= k then bad[#bad + 1] = id .. "=" .. tostring(k) end
			end
			try(o.set, {}, cur)
		elseif o.type == "color" then
			walked = walked + 1
			local r, g, b, a = o.get({})
			local ok = try(o.set, {}, 0.1, 0.2, 0.3, 0.4)
			local r2, g2, b2, a2 = o.get({})
			if not ok or not (near(r2, 0.1) and near(g2, 0.2) and near(b2, 0.3) and near(a2, 0.4)) then bad[#bad + 1] = id end
		end
	end
	check(string.format("set every setting through its set handler and read it back (%d controls), no Lua errors", walked), #bad == 0 and walked >= 40, table.concat(bad, ", "))
	check("look, colour, scale and font changes fire LookChanged", looks > 0, looks)
	WCSW.UnregisterCallback(obs, "LookChanged")
end

---------------------------------------------------------------- colours: override and reset
do
	local wa = tree.args.window.args
	O.ResetColors()
	local lr, lg, lb, la = O.LookColor("bg")
	local r, g, b, a = wa.bg.get({})
	check("no override: a colour shows the look's own", near(r, lr) and near(g, lg) and near(b, lb) and near(a, la))
	check("  Reset to the look's colours is greyed with nothing set", wa.resetColors.disabled({}) == true)
	wa.edge.set({}, 0.5, 0.25, 0.125, 0.75)
	local saved = P().window.colors.edge
	check("set Edge: saved as { r, g, b, a } on db.profile.window.colors.edge", type(saved) == "table" and near(saved[1], 0.5) and near(saved[2], 0.25)
		and near(saved[3], 0.125) and near(saved[4], 0.75))
	check("  the other colours stay the look's own (nil)", P().window.colors.bg == nil and P().window.colors.title == nil and P().window.colors.accent == nil)
	check("  Reset is live now", wa.resetColors.disabled({}) == false)
	local looks = 0
	local obs = {}
	WCSW.RegisterCallback(obs, "LookChanged", function() looks = looks + 1 end)
	try(wa.resetColors.func, {})
	WCSW.UnregisterCallback(obs, "LookChanged")
	local er, eg, eb, ea = wa.edge.get({})
	local xr, xg, xb, xa = O.LookColor("edge")
	check("Reset to the look's colours: overrides gone, the look's own back, LookChanged fired", next(P().window.colors) == nil
		and near(er, xr) and near(eg, xg) and near(eb, xb) and near(ea, xa) and looks > 0)
	-- each look gives its own colours
	local seenLooks = 0
	for _, look in ipairs({ "suite", "blizzard", "flat" }) do
		P().window.look = look
		local cr = O.LookColor("bg")
		if type(cr) == "number" then seenLooks = seenLooks + 1 end
	end
	P().window.look = "suite"
	check("the look list has Suite dark, Blizzard classic, Flat modern; each gives colours", (function()
		local v = O.LookValues() return v.suite and v.blizzard and v.flat end)() and seenLooks == 3)
end

---------------------------------------------------------------- sound, announce, key binding
do
	local aa = tree.args.alerts.args
	local values = O.SoundValues()
	check("sound list holds the default (" .. tostring(WCSW.defaults.profile.sound.name) .. ")", values[WCSW.defaults.profile.sound.name] ~= nil)
	local LSM = LibStub("LibSharedMedia-3.0")
	LSM:Register("sound", "Harness Ding", "Interface\\AddOns\\x.ogg")
	check("  and LibSharedMedia's sounds", O.SoundValues()["Harness Ding"] == "Harness Ding")
	local realPlay = rawget(WCSW, "PlayRequestSound")
	local played = 0
	WCSW.PlayRequestSound = function() played = played + 1 end
	local ok = try(aa.test.func, {})
	check("Test calls WCSW:PlayRequestSound()", ok and played == 1)
	WCSW.PlayRequestSound = nil
	P().sound.name = "Harness Ding"
	local ok2, how = try(O.TestSound)
	check("  without it, Test plays the picked sound itself", ok2 and how == "lsm", how)
	P().sound.name = WCSW.defaults.profile.sound.name
	WCSW.PlayRequestSound = realPlay

	local ga = tree.args.general.args
	local realAnnounce = WCSW.slash.announce
	local said
	WCSW.slash.announce = function(rest) said = rest end
	check("Announce calls WCSW.slash.announce", ga.announce.disabled({}) == false and try(ga.announce.func, {}) and said == "")
	WCSW.slash.announce = nil
	check("  greyed while there is no announce", ga.announce.disabled({}) == true)
	WCSW.slash.announce = realAnnounce

	local ca = tree.args.castButton.args
	local opened
	local realOpen, realID = Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID
	Settings.KEYBINDINGS_CATEGORY_ID = 42
	Settings.OpenToCategory = function(id) opened = id end
	local okb = try(ca.bind.func, {})
	check("Set the key opens the game's Key Bindings (Settings)", okb and opened == 42)
	Settings.KEYBINDINGS_CATEGORY_ID = nil
	KeyBindingFrame = CreateFrame("Frame", "KeyBindingFrame")
	local shown
	local realShow = ShowUIPanel
	ShowUIPanel = function(f) shown = f end
	check("  or the old Key Bindings frame", try(ca.bind.func, {}) and shown == KeyBindingFrame)
	ShowUIPanel, KeyBindingFrame = realShow, nil
	Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID = realOpen, realID
	local keyText = ca.key.name({})
	check("  the key shows (none bound: says so)", type(keyText) == "string" and keyText:find("no key set", 1, true) ~= nil, keyText)
	local realGBK = GetBindingKey
	GetBindingKey = function(cmd) if cmd == "CLICK WhisperCastSWCastButton:LeftButton" then return "F" end end
	keyText = ca.key.name({})
	check("  a bound key shows", keyText:find("F", 1, true) ~= nil and not keyText:find("no key set", 1, true), keyText)
	GetBindingKey = realGBK
end

---------------------------------------------------------------- launcher and slash
do
	check("launcher in the game's AddOns list (Settings API)", O.blizWay == "settings" and ACD.BlizOptions["WhisperCastSWBliz"] ~= nil, O.blizWay)
	check("the slash word settings is there", type(WCSW.slash.settings) == "function")
	ACD:Close(APP)
	RunOnUpdate(0.02, 2)
	local ok = try(WCSW.slash.settings, "")
	check("/wc settings opens the window", ok and ACD.OpenFrames[APP] ~= nil)
	ok = try(WCSW.slash.settings, "alerts")
	local st = ACD:GetStatusTable(APP)
	check("/wc settings alerts opens at the Alerts tab", ok and st.groups and st.groups.selected == "alerts", st.groups and st.groups.selected)
	ACD:Close(APP)
	RunOnUpdate(0.02, 2)
end

---------------------------------------------------------------- the window, every tab
do
	local e0 = #ERRORS
	xpcall(function() ACD:Open(APP) end, ERRH)
	for _, t in ipairs(TABS) do
		xpcall(function() ACD:SelectGroup(APP, t[1]); ACD:Open(APP) end, ERRH)
	end
	RunOnUpdate(0.02, 3)
	check("open the window and visit every tab, no Lua errors", #ERRORS == e0 and ACD.OpenFrames[APP] ~= nil, #ERRORS - e0)
	xpcall(function() ACD:Close(APP) end, ERRH)
	RunOnUpdate(0.02, 2)
end

---------------------------------------------------------------- Spells and words
local Words = WCSW.Words
local sa = tree.args.spells.args
local function rowsFor(key)
	for k, o in pairs(sa) do
		if o.arg == key and k:match("words$") then
			local id = k:match("^(.-)words$")
			return sa[id .. "on"], sa[id .. "reset"], o
		end
	end
end
local key
for _, k in ipairs((function()
	local t = {} for k2, s in pairs(WCSW.spells) do if type(s) == "table" and s.words and #s.words >= 1 then t[#t + 1] = k2 end end
	table.sort(t) return t end)()) do key = key or k end
check("a spell with words to test on", key ~= nil)
if key then
	local on, reset, words = rowsFor(key)
	local defaults = Words.Parse(WCSW.spells[key].words)
	check("every spell has a tick, Reset words and the chips (" .. key .. ")", on and reset and words and words.dialogControl == "WCSW_Chips")
	local rows = 0
	for k in pairs(WCSW.spells) do if rowsFor(k) then rows = rows + 1 end end
	local n = 0 for _ in pairs(WCSW.spells) do n = n + 1 end
	check("  a row for every spell", rows == n, rows .. "/" .. n)
	check("  the tick label has the 22 px icon and the name", on.name({}):find("|T", 1, true) == 1 and on.name({}):find(WCSW.spells[key].name, 1, true) ~= nil, on.name({}))
	on.set({}, false)
	check("tick off: db.profile.spells[key].enabled false", P().spells[key].enabled == false)
	on.set({}, true)
	check("tick on again", P().spells[key].enabled == true and on.get({}) == true)
	knownOverride[key] = false
	check("a spell the character doesn't know is hidden", on.hidden({}) == true and words.hidden({}) == true)
	knownOverride[key] = nil
	check("  a known one shows", on.hidden({}) == false)
	check("no words saved: the spell's own defaults show, Reset words greyed", P().spells[key].words == nil and words.get({}) == Words.Join(defaults)
		and reset.disabled({}) == true)

	-- the set handler's rules
	words.set({}, { "  Heal  ME ", "HEAL me", "", "   ", defaults[1] })
	check("set: lower case, trimmed, single spaces, no duplicates, no empty words", list(P().spells[key].words) == "heal me," .. defaults[1], list(P().spells[key].words))
	words.set({}, defaults)
	check("set to the defaults saves nil", P().spells[key].words == nil)
	words.set({}, "a, b,, a")
	check("a \"a, b\" string works too", list(P().spells[key].words) == "a,b")
	reset.func({})
	check("Reset words: nil again", P().spells[key].words == nil)

	-- the widget, through AceConfigDialog and its own scripts
	local AceGUI = LibStub("AceGUI-3.0")
	local made = {}
	local realCreate = AceGUI.Create
	AceGUI.Create = function(self, kind, ...)
		local w = realCreate(self, kind, ...)
		if kind == "WCSW_Chips" then made[#made + 1] = w end
		return w
	end
	local function openSpells()
		xpcall(function() ACD:Open(APP); ACD:SelectGroup(APP, "spells"); ACD:Open(APP) end, ERRH)
	end
	local function widget()
		for i = #made, 1, -1 do
			local w = made[i]
			local o = w:GetUserData("option")
			if o and o.arg == key and not w.isQueuedForRelease and w.frame:IsShown() ~= false then return w end
		end
	end
	local function shownChips(w)
		local t = {}
		for _, c in ipairs(w.chips) do if c.__shown then t[#t + 1] = c.text:GetText() end end
		return t
	end
	local function addWord(text)
		local w = widget()
		if not w then return false end
		local e0 = #ERRORS
		w.addChip:GetScript("OnClick")(w.addChip, "LeftButton")
		local opened = w.editing and w.editBox.__shown
		w.editBox:SetText(text)
		w.editBox:GetScript("OnEnterPressed")(w.editBox)
		return opened and #ERRORS == e0
	end
	local function removeWord(word)
		local w = widget()
		if not w then return false end
		for _, c in ipairs(w.chips) do
			if c.__shown and c.remove.word == word then
				local e0 = #ERRORS
				c.remove:GetScript("OnClick")(c.remove, "LeftButton")
				return #ERRORS == e0
			end
		end
		return false
	end

	local e0 = #ERRORS
	openSpells()
	local w = widget()
	check("the Spells and words tab draws the chips widget, no Lua errors", w ~= nil and #ERRORS == e0, #ERRORS - e0)
	if w then
		check("  a pill per word, then + word", list(shownChips(w)) == list(defaults) and w.addChip.__shown and not w.editBox.__shown, list(shownChips(w)))
		check("  the label is empty (the tick above names the spell)", w.labelText == nil)

		check("+ word opens the box; Enter adds the word (saved lower case, trimmed)", addWord("  Heal ME ") and list(P().spells[key].words) == list(defaults) .. ",heal me",
			list(P().spells[key].words))
		openSpells()
		check("  the window redraws with the new pill", list(shownChips(widget())) == list(defaults) .. ",heal me")
		addWord("HEAL me")
		check("a word it already has: nothing changes", list(P().spells[key].words) == list(defaults) .. ",heal me")
		check("  the box closed again", not widget().editing and not widget().editBox.__shown and widget().addChip.__shown)
		addWord("    ")
		check("a blank word: nothing changes", list(P().spells[key].words) == list(defaults) .. ",heal me")
		addWord("one, Two")
		check("\"one, Two\" adds both", list(P().spells[key].words) == list(defaults) .. ",heal me,one,two")
		openSpells()
		w = widget()
		w.addChip:GetScript("OnClick")(w.addChip, "LeftButton")
		w.editBox:SetText("zzz")
		w.editBox:GetScript("OnEscapePressed")(w.editBox)
		check("Escape cancels: box closed, nothing saved", not w.editing and not w.editBox.__shown and list(P().spells[key].words) == list(defaults) .. ",heal me,one,two")
		check("× removes a word", removeWord("one") and list(P().spells[key].words) == list(defaults) .. ",heal me,two")
		openSpells()
		check("  its pill is gone", list(shownChips(widget())) == list(defaults) .. ",heal me,two")
		for _, word in ipairs({ "two", "heal me" }) do openSpells(); removeWord(word) end
		check("back to the defaults by hand: saved as nil", P().spells[key].words == nil)
		for _, word in ipairs(defaults) do openSpells(); removeWord(word) end
		check("every word removed: an empty list (its own name still works), not the defaults", type(P().spells[key].words) == "table" and #P().spells[key].words == 0)
		openSpells()
		check("  no pills, only + word", #shownChips(widget()) == 0 and widget().addChip.__shown)
		check("  Reset words is live", reset.disabled({}) == false)
		reset.func({})
		openSpells()
		check("Reset words brings the defaults back to the pills", list(shownChips(widget())) == list(defaults))

		-- the widget on its own: SetValue / OnValueChanged, and AceGUI's recycling
		local x = AceGUI:Create("WCSW_Chips")
		local got, entered
		x:SetCallback("OnValueChanged", function(_, _, v) got = v end)
		x:SetCallback("OnEnterPressed", function(_, _, v) entered = v end)
		x:SetValue({ "A", "b", "a" })
		check("SetValue/GetValue: a clean list", list(x:GetValue()) == "a,b")
		x.addChip:GetScript("OnClick")(x.addChip, "LeftButton")
		x.editBox:SetText("c")
		x.editBox:GetScript("OnEnterPressed")(x.editBox)
		check("a change goes out as the whole list: OnValueChanged and OnEnterPressed", type(got) == "table" and list(got) == "a,b,c" and type(entered) == "table" and list(entered) == "a,b,c")
		x.addChip:GetScript("OnClick")(x.addChip, "LeftButton")
		x:SetDisabled(true)
		check("SetDisabled closes the box and greys it", not x.editing and x.frame.__alpha == 0.5)
		AceGUI:Release(x)
		local y = AceGUI:Create("WCSW_Chips")
		local stale = false
		for _, c in ipairs(y.chips) do if c.__shown or c.remove.word then stale = true end end
		check("recycled by AceGUI: no words, no open box, no callbacks, not greyed", #y:GetValue() == 0 and not y.editing and not y.editBox.__shown
			and not stale and next(y.events) == nil and y.frame.__alpha == 1 and not y.disabled)
		AceGUI:Release(y)
		-- wrapping: a narrow widget puts pills on more lines
		local z = AceGUI:Create("WCSW_Chips")
		z:SetWidth(400)
		z:SetValue({ "aaaaaaaaaa", "bbbbbbbbbb", "cccccccccc", "dddddddddd", "eeeeeeeeee", "ffffffffff" })
		local wide = z.frame.height
		z:SetWidth(120)
		check("pills wrap to more lines when narrow", z.frame.height > wide, tostring(wide) .. " -> " .. tostring(z.frame.height))
		AceGUI:Release(z)
	end
	AceGUI.Create = realCreate
	xpcall(function() ACD:Close(APP) end, ERRH)
	RunOnUpdate(0.02, 2)
end

---------------------------------------------------------------- profiles
do
	P().window.fontSize = 15
	WCSW.db:SetProfile("Second")
	check("a new profile: settings at their defaults in the window", tree.args.window.args.fontSize.get({}) == 12)
	WCSW.db:SetProfile("Default")
	check("  back: the first profile's value", tree.args.window.args.fontSize.get({}) == 15)
	P().window.fontSize = 12
	WCSW.db:DeleteProfile("Second", true)
end

---------------------------------------------------------------- the older AddOns list
do
	local realSettings = Settings
	local added
	local realAdd = InterfaceOptions_AddCategory
	InterfaceOptions_AddCategory = function(panel) added = panel end
	Settings = nil
	local O2 = WCSW.Options
	-- the launcher on a client without the Settings API (the registration code, run again)
	local ok, way = try(function()
		local LAUNCH = O2.AddLauncher
		return LAUNCH and LAUNCH()
	end)
	Settings = realSettings
	InterfaceOptions_AddCategory = realAdd
	check("without the Settings API: a page through InterfaceOptions_AddCategory", ok and way == "interface" and added and added.name == WCSW.TITLE, way)
end

---------------------------------------------------------------- locale
do
	local text = (HARNESS_READ(HARNESS_SRC .. "/Locales/enUS_Options.lua") or "") .. (HARNESS_READ(HARNESS_SRC .. "/Locales/enUS_Core.lua") or "")
	local missing = {}
	for _, f in ipairs({ "Chips.lua", "Options.lua" }) do
		local src = HARNESS_READ(HARNESS_SRC .. "/" .. f) or ""
		for k in src:gmatch('L%["(.-[^\\])"%]') do
			if not text:find('L["' .. k .. '"]', 1, true) then missing[#missing + 1] = k end
		end
	end
	check("every L[\"...\"] in Chips.lua and Options.lua is in Locales/enUS_Options.lua", #missing == 0, table.concat(missing, " | "))
end

WCSW.IsKnown = realIsKnown
for _, e in ipairs(ERRORS) do print("  FAIL lua error: " .. tostring(e):sub(1, 300)) end
print(string.format("RESULT %s %s: total lua errors %d", HARNESS_TOCFILE, PLAYER.class, #ERRORS + fails))
