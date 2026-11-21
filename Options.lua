--[[
	WhisperCast: Second Wind - settings (docs/DESIGN_HANDOFF.md "Settings layout"): one AceConfig
	window, "WhisperCastSW", with tabs General · Spells and words · Window · Cast button · Alerts ·
	Folded icon · Profiles. The game's AddOns list gets a launcher page with one button (as CDTL3:
	Blizzard's settings frame can't be moved, so the settings live in their own window).

	Opens with /wc settings [tab] or WhisperCastSW:OpenSettings([tab]).

	Every control reads and writes WCSW.db.profile (Core.lua's defaults) and then tells the rest:
	look, colours, scale and font fire "LookChanged"; everything else runs WCSW:RefreshAll().
	Calls into the other files (WCSW.LOOKS, WCSW.SOUNDS, WCSW:IsKnown, WCSW:PlayRequestSound,
	WCSW.slash.announce) are guarded: each may not exist yet.
]]

local WCSW = WhisperCastSW
local L = WCSW.L
local Words = WCSW.Words

local APP = "WhisperCastSW"
local BLIZ = "WhisperCastSWBliz"

local Options = WCSW:AddModule("Options", {})
WCSW.Options = Options
Options.APP = APP

local function ACD() return LibStub("AceConfigDialog-3.0") end
local function REG() return LibStub("AceConfigRegistry-3.0") end
local function P() return WCSW.db.profile end

---------------------------------------------------------------- telling the rest
local function changed(kind)
	if kind == "look" then
		WCSW:Fire("LookChanged")
	else
		WCSW:RefreshAll()
	end
end

-- "window.scale" -> P().window, "scale"
local function walk(path)
	local t, last = P(), nil
	for part in path:gmatch("[^%.]+") do
		if last then t = t[last] end
		last = part
	end
	return t, last
end

local function getter(path)
	return function()
		local t, k = walk(path)
		return t[k]
	end
end

local function setter(path, kind)
	return function(_, value)
		local t, k = walk(path)
		t[k] = value
		changed(kind)
	end
end

---------------------------------------------------------------- control makers
local function toggle(order, name, desc, path, kind, extra)
	local o = { type = "toggle", order = order, name = name, desc = desc, get = getter(path), set = setter(path, kind) }
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

local function range(order, name, desc, path, min, max, step, kind, extra)
	local o = { type = "range", order = order, name = name, desc = desc, min = min, max = max, step = step,
		get = getter(path), set = setter(path, kind) }
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

local function choose(order, name, desc, path, values, sorting, kind, extra)
	local o = { type = "select", order = order, name = name, desc = desc, values = values, sorting = sorting,
		get = getter(path), set = setter(path, kind) }
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

local function header(order, name)
	return { type = "header", order = order, name = name }
end

local function text(order, name)
	return { type = "description", order = order, name = name, fontSize = "medium" }
end

---------------------------------------------------------------- looks and colours
-- the handoff's values for each look, used when Looks.lua has none to give
local FALLBACK_COLORS = {
	suite = { bg = { 13 / 255, 13 / 255, 20 / 255, 0.9 }, edge = { 140 / 255, 89 / 255, 140 / 255, 0.85 },
		title = { 1, 0.5, 1, 1 }, accent = { 1, 0.5, 1, 1 } },
	blizzard = { bg = { 0x2a / 255, 0x1d / 255, 0x12 / 255, 1 }, edge = { 0xb8 / 255, 0x90 / 255, 0x2f / 255, 1 },
		title = { 1, 0.82, 0, 1 }, accent = { 1, 0.5, 1, 1 } },
	flat = { bg = { 6 / 255, 6 / 255, 8 / 255, 0.84 }, edge = { 1, 0.5, 1, 1 },
		title = { 1, 0.5, 1, 1 }, accent = { 1, 0.5, 1, 1 } },
}
Options.COLOR_KEYS = { "bg", "edge", "title", "accent" }

-- { r, g, b, a } or { r =, g =, b =, a = } -> r, g, b, a
local function rgba(c)
	if type(c) ~= "table" then return nil end
	local r, g, b, a = c[1] or c.r, c[2] or c.g, c[3] or c.b, c[4] or c.a
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
	return r, g, b, (type(a) == "number") and a or 1
end

-- look key -> its name, from Looks.lua's WCSW.LOOKS ({ key = { name = } }, { key = "Name" } or { { key =, name = } })
function Options.LookValues()
	local t = {}
	if type(WCSW.LOOKS) == "table" then
		for k, v in pairs(WCSW.LOOKS) do
			if type(k) == "string" then
				t[k] = (type(v) == "table" and (v.name or v.title or v.label)) or (type(v) == "string" and v) or k
			elseif type(v) == "table" and type(v.key) == "string" then
				t[v.key] = v.name or v.title or v.key
			end
		end
	end
	if not next(t) then
		t = { suite = L["Suite dark"], blizzard = L["Blizzard classic"], flat = L["Flat modern"] }
	end
	return t
end

local function lookEntry(look)
	local looks = WCSW.LOOKS
	if type(looks) ~= "table" then return nil end
	if type(looks[look]) == "table" then return looks[look] end
	for _, v in ipairs(looks) do
		if type(v) == "table" and v.key == look then return v end
	end
end

-- the chosen look's own colour for bg / edge / title / accent
function Options.LookColor(key)
	local look = P().window.look
	local e = lookEntry(look)
	if e then
		local r, g, b, a = rgba(type(e.colors) == "table" and e.colors[key] or e[key])
		if r then return r, g, b, a end
	end
	return rgba((FALLBACK_COLORS[look] or FALLBACK_COLORS.suite)[key])
end

-- the colour in use: the setting when there is one, else the look's own
function Options.Color(key)
	local r, g, b, a = rgba(P().window.colors[key])
	if r then return r, g, b, a end
	return Options.LookColor(key)
end

local function colorOption(order, key, name, desc)
	return {
		type = "color", order = order, name = name, desc = desc, hasAlpha = true,
		get = function() return Options.Color(key) end,
		set = function(_, r, g, b, a)
			P().window.colors[key] = { r, g, b, a or 1 }
			changed("look")
		end,
	}
end

function Options.ResetColors()
	wipe(P().window.colors)
	changed("look")
end

---------------------------------------------------------------- sounds
-- WCSW.SOUNDS (UI lane: the checked Blizzard list) plus every LibSharedMedia sound
function Options.SoundValues()
	local t, own = {}, {}
	local S = WCSW.SOUNDS
	if type(S) == "table" then
		for k, v in pairs(S) do
			local key, name
			if type(k) == "string" then
				key = k
				name = (type(v) == "string" and v) or (type(v) == "table" and (v.name or v[2])) or k
			elseif type(v) == "table" then
				key, name = v.key or v[1], v.name or v[2]
			elseif type(v) == "string" then
				key, name = v, v
			end
			if type(key) == "string" then
				t[key] = type(name) == "string" and name or key
				own[key] = true
			end
		end
	end
	if not next(t) then
		t.TELL_MESSAGE = L["Whisper"]
		own.TELL_MESSAGE = true
	end
	local LSM = LibStub("LibSharedMedia-3.0", true)
	if LSM then
		for _, name in ipairs(LSM:List("sound") or {}) do
			if name ~= "None" and t[name] == nil then t[name] = name end
		end
	end
	local cur = P().sound.name
	if type(cur) == "string" and t[cur] == nil then t[cur] = cur end
	return t, own
end

local function soundSorting()
	local t, own = Options.SoundValues()
	local first, rest = {}, {}
	for k in pairs(t) do
		if own[k] then first[#first + 1] = k else rest[#rest + 1] = k end
	end
	local function byName(a, b) return tostring(t[a]) < tostring(t[b]) end
	table.sort(first, byName)
	table.sort(rest, byName)
	for _, k in ipairs(rest) do first[#first + 1] = k end
	return first
end

function Options.TestSound()
	if type(WCSW.PlayRequestSound) == "function" then
		WCSW:PlayRequestSound()
		return "addon"
	end
	local name = P().sound.name
	if type(name) ~= "string" then return nil end
	local kit = SOUNDKIT and rawget(SOUNDKIT, name)
	if kit then
		PlaySound(kit, "Master")
		return "soundkit"
	end
	local LSM = LibStub("LibSharedMedia-3.0", true)
	local file = LSM and LSM:Fetch("sound", name, true)
	if file then
		pcall(PlaySoundFile, file, "Master")
		return "lsm"
	end
end

---------------------------------------------------------------- key binding
-- the game's Key Bindings page (Settings on clients that have it, the old frame on the rest)
function Options.OpenKeyBindings()
	pcall(ACD().Close, ACD(), APP)
	if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
		local ok = pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
		if ok then return "settings" end
	end
	if not KeyBindingFrame and KeyBindingFrame_LoadUI then pcall(KeyBindingFrame_LoadUI) end
	if KeyBindingFrame then
		ShowUIPanel(KeyBindingFrame)
		return "frame"
	end
	WCSW:Print(L["Open the game's Key Bindings and look for WhisperCast: Second Wind."])
	return nil
end

---------------------------------------------------------------- spells and words
local function spellsOf()
	return type(WCSW.spells) == "table" and WCSW.spells or {}
end

-- known to this character (every spell when the Engine has no answer)
local function known(key)
	if type(WCSW.IsKnown) ~= "function" then return true end
	local ok, yes = pcall(WCSW.IsKnown, WCSW, key)
	return not ok or yes and true or false
end

-- the words in use for a spell: the profile's own, else the spell's defaults
function Options.WordsOf(key)
	local own = P().spells[key].words
	if type(own) == "table" then return own end
	local s = spellsOf()[key]
	return Words.Parse(s and s.words or {})
end

-- saves a new word list (a table or "a, b"); the same as the defaults saves nil
function Options.SetWords(key, value)
	local list = Words.Parse(value)
	local s = spellsOf()[key]
	local defaults = Words.Parse(s and s.words or {})
	P().spells[key].words = (not Words.Same(list, defaults)) and list or nil
	changed("all")
end

function Options.ResetWords(key)
	P().spells[key].words = nil
	changed("all")
end

-- spells in order: by name, each one's group version right after it, unmatched ones last
local function orderedSpells()
	local all = spellsOf()
	local singles, placed, out = {}, {}, {}
	for key, s in pairs(all) do
		if type(s) == "table" and not s.isGroup then singles[#singles + 1] = key end
	end
	local function name(k) return tostring(all[k].name or k) end
	table.sort(singles, function(a, b) return name(a) < name(b) end)
	for _, key in ipairs(singles) do
		out[#out + 1] = key
		placed[key] = true
		local g = all[key].group
		if g and all[g] and not placed[g] then
			out[#out + 1] = g
			placed[g] = true
		end
	end
	local rest = {}
	for key, s in pairs(all) do
		if type(s) == "table" and not placed[key] then rest[#rest + 1] = key end
	end
	table.sort(rest, function(a, b) return name(a) < name(b) end)
	for _, key in ipairs(rest) do out[#out + 1] = key end
	return out
end

local function spellLabel(key)
	local s = spellsOf()[key] or {}
	local name = s.name or key
	if s.icon then return "|T" .. tostring(s.icon) .. ":22:22:0:0|t " .. name end
	return name
end

local function anyShown()
	for key in pairs(spellsOf()) do
		if known(key) then return true end
	end
	return false
end

-- fills the Spells and words tab's spell rows (args keyed s1, s2...; arg = the spell key)
local function fillSpellArgs(args)
	for k in pairs(args) do
		if k:match("^spell%d+") then args[k] = nil end
	end
	for i, key in ipairs(orderedSpells()) do
		local base = 100 + i * 10
		local hidden = function() return not known(key) end
		local id = "spell" .. i
		args[id .. "on"] = {
			type = "toggle", order = base, arg = key, width = 1.7, hidden = hidden,
			name = function() return spellLabel(key) end,
			desc = L["Take requests for this spell. Its own name always works as a word too."],
			get = function() return P().spells[key].enabled end,
			set = function(_, v)
				P().spells[key].enabled = v and true or false
				changed("all")
			end,
		}
		args[id .. "reset"] = {
			type = "execute", order = base + 1, arg = key, width = 0.8, hidden = hidden,
			name = L["Reset words"],
			desc = L["Back to this spell's usual words."],
			disabled = function() return P().spells[key].words == nil end,
			func = function() Options.ResetWords(key) end,
		}
		args[id .. "words"] = {
			type = "input", order = base + 2, arg = key, width = "full", hidden = hidden,
			dialogControl = "WCSW_Chips",
			name = "",
			desc = L["Words that ask for this spell. × removes one, + word adds one."],
			get = function() return Words.Join(Options.WordsOf(key)) end,
			set = function(_, value) Options.SetWords(key, value) end,
		}
	end
end

-- rebuilds the spell rows when the Engine's spell list changed; true when it did
function Options:UpdateSpells()
	local keys = orderedSpells()
	local sig = table.concat(keys, "\001")
	if sig == self.spellSig then return false end
	self.spellSig = sig
	fillSpellArgs(self.tree.args.spells.args)
	if self.registered then REG():NotifyChange(APP) end
	return true
end

---------------------------------------------------------------- the tree
local MATCH_VALUES = function()
	return { exact = L["The whole whisper"], start = L["Its first words"], any = L["Any word in it"] }
end
local MATCH_SORT = { "exact", "start", "any" }

local function matchOption(order)
	return choose(order, L["Matching"], L["How a whisper has to hold a word: the whole whisper is the word, it starts with the word, or the word is anywhere in it."],
		"match", MATCH_VALUES, MATCH_SORT, "all")
end

function Options:Build()
	local tree = {
		type = "group",
		name = WCSW.TITLE,
		childGroups = "tab",
		args = {},
	}
	local a = tree.args

	-- General
	a.general = {
		type = "group", order = 10, name = L["General"],
		args = {
			about = text(1, L["Group members whisper you a word; the spell joins a queue, and one key casts it on them."]),
			requests = header(10, L["Requests"]),
			enabled = toggle(11, L["Take requests"], L["Queue the spells group members whisper for. Off: nothing new joins the queue."], "enabled", "all"),
			match = matchOption(12),
			groupOnly = toggle(13, L["Group members only"], L["Only take requests from your party or raid."], "groupOnly", "all"),
			replies = header(20, L["Replies"]),
			replyOn = toggle(21, L["Whisper replies"], L["Tell the asker their place in line, when it's cast and when it's cleared."], "replies", "all"),
			hideOwnReplies = toggle(22, L["Hide my [WC] whispers"], L["Keep your own [WC] replies out of your chat."], "hideOwnReplies", "all", { width = 1.5 }),
			hideRequests = toggle(23, L["Hide the request whispers"], L["Keep the whispers that asked for a spell out of your chat."], "hideRequests", "all", { width = 1.5 }),
			announce = {
				type = "execute", order = 24, name = L["Announce"],
				desc = L["Tell your party or raid which words to whisper you."],
				disabled = function() return type(WCSW.slash.announce) ~= "function" end,
				func = function() WCSW.slash.announce("") end,
			},
			frames = header(30, L["Frames"]),
			unlocked = {
				type = "toggle", order = 31, name = L["Unlock frames"],
				desc = L["Drag the window, the Cast button, the note and the folded icon where you want them."],
				get = function() return P().unlocked end,
				set = function(_, v)
					P().unlocked = v and true or false
					WCSW:Fire("LockChanged", P().unlocked)
				end,
			},
			minimap = {
				type = "toggle", order = 32, name = L["Minimap button"],
				desc = L["Show the button on the minimap."],
				get = function() return not P().minimap.hide end,
				set = function(_, v)
					P().minimap.hide = not v
					changed("all")
				end,
			},
			minimapAngle = range(33, L["Minimap button place"], L["Where the button sits around the minimap, in degrees."],
				"minimap.angle", 0, 360, 1, "all", { disabled = function() return P().minimap.hide end }),
		},
	}

	-- Spells and words (the spell rows come from UpdateSpells)
	a.spells = {
		type = "group", order = 20, name = L["Spells and words"],
		args = {
			about = text(1, L["Whisper any of a spell's words to ask for it. Each spell's own name always works as a word too."]),
			match = matchOption(2),
			none = {
				type = "description", order = 3, fontSize = "medium",
				name = L["No spells this character can cast on others yet."],
				hidden = function() return anyShown() end,
			},
		},
	}

	-- Window
	a.window = {
		type = "group", order = 30, name = L["Window"],
		args = {
			lookHead = header(10, L["Look"]),
			look = choose(11, L["Look"], L["Suite dark, Blizzard classic or Flat modern. The colours below start from the look's own."],
				"window.look", Options.LookValues, nil, "look"),
			bg = colorOption(12, "bg", L["Background"], L["The window's background colour and opacity."]),
			edge = colorOption(13, "edge", L["Edge"], L["The window's edge colour and opacity."]),
			title = colorOption(14, "title", L["Title"], L["The title's colour."]),
			accent = colorOption(15, "accent", L["Accent"], L["The count badge, glow, note edge, ready outline and row highlight."]),
			resetColors = {
				type = "execute", order = 16, name = L["Reset to the look's colours"], width = 1.5,
				desc = L["Forget the colours set here and use the look's own."],
				disabled = function() return next(P().window.colors) == nil end,
				func = function() Options.ResetColors() end,
			},
			scale = range(17, L["Scale"], L["The window's size."], "window.scale", 0.6, 2, 0.05, "look", { isPercent = true }),
			fontSize = range(18, L["Font size"], L["Text size in the window."], "window.fontSize", 10, 16, 1, "look"),
			width = range(19, L["Width"], L["The window's width in pixels."], "window.width", 200, 400, 10, "look"),
			showHead = header(20, L["What it shows"]),
			shown = toggle(21, L["Show the window"], L["Show the queue window."], "window.shown", "all"),
			folded = toggle(22, L["Folded away"], L["Fold the window to the round icon."], "window.folded", "all"),
			showWhenEmpty = toggle(23, L["Show when empty"], L["Keep the window up when nobody is waiting."], "window.showWhenEmpty", "all"),
			grouped = toggle(24, L["Group by spell"], L["One row per spell under Next up, with the askers' names under it. Off: one row per request."], "window.grouped", "all"),
			classicButtons = toggle(25, L["Cast and Clear on the window"], L["The classic buttons along the window's bottom. They use the same key as the Cast button."], "window.classicButtons", "all", { width = 1.5 }),
			maxRows = range(26, L["Rows"], L["How many rows show under Next up before \"+N more\"."], "window.maxRows", 1, 20, 1, "all"),
			combatHead = header(30, L["In combat"]),
			combat = choose(31, L["In combat"], L["What the window does while you're in combat."], "window.combat",
				function() return { show = L["Show"], fade = L["Fade"], hide = L["Hide"] } end, { "show", "fade", "hide" }, "all"),
			combatAlpha = range(32, L["Faded opacity"], L["How see-through the window is in combat when it fades."], "window.combatAlpha", 0, 1, 0.05, "all",
				{ isPercent = true, disabled = function() return P().window.combat ~= "fade" end }),
			lockRow = toggle(33, L["Lock row"], L["The \"Casts wait until the fight ends\" row in combat."], "window.lockRow", "all"),
		},
	}

	-- Cast button
	a.castButton = {
		type = "group", order = 40, name = L["Cast button"],
		args = {
			shown = toggle(1, L["Show the Cast button"], L["Its own action button that casts the next request."], "castButton.shown", "all", { width = 1.5 }),
			size = range(2, L["Size"], L["The button's size in pixels."], "castButton.size", 24, 64, 1, "all"),
			label = toggle(3, L["Name and spell under it"], L["The asker's name in class colour and the spell, under the button."], "castButton.label", "all", { width = 1.5 }),
			empty = choose(4, L["When nobody is waiting"], L["Show the logo dimmed, or hide the button."], "castButton.empty",
				function() return { dim = L["Dimmed logo"], hide = L["Hidden"] } end, { "dim", "hide" }, "all"),
			keyHead = header(10, L["Key"]),
			key = {
				type = "description", order = 11, fontSize = "medium", width = 1.5,
				name = function()
					local key = WCSW:CastKey()
					return format(L["Cast the next request: %s"], key or L["no key set"])
				end,
			},
			bind = {
				type = "execute", order = 12, name = L["Set the key"],
				desc = L["Opens the game's Key Bindings, where it's under WhisperCast: Second Wind."],
				func = function() Options.OpenKeyBindings() end,
			},
		},
	}

	-- Alerts
	a.alerts = {
		type = "group", order = 50, name = L["Alerts"],
		args = {
			noteHead = header(10, L["Note"]),
			toast = toggle(11, L["Show a note"], L["A note by the window when a request comes in."], "toast.enabled", "all"),
			duration = range(12, L["Note time"], L["Seconds the note stays before it fades."], "toast.duration", 1, 10, 0.5, "all"),
			toastScale = range(13, L["Note size"], L["The note's size."], "toast.scale", 0.5, 2, 0.05, "all", { isPercent = true }),
			toastMax = range(14, L["Notes at once"], L["How many notes stack up at most."], "toast.max", 1, 5, 1, "all"),
			soundHead = header(20, L["Sound"]),
			sound = toggle(21, L["Play a sound"], L["A sound when a request comes in."], "sound.enabled", "all"),
			soundName = choose(22, L["Sound"], L["The game's sounds, then LibSharedMedia's."], "sound.name",
				function() return (Options.SoundValues()) end, soundSorting, "all",
				{ disabled = function() return not P().sound.enabled end }),
			test = {
				type = "execute", order = 23, name = L["Test"], width = "half",
				desc = L["Play the sound now."],
				func = function() Options.TestSound() end,
			},
			soundWhen = choose(24, L["When"], L["Only when the queue was empty (as in 2007), or for every request."], "sound.when",
				function() return { first = L["First request only"], every = L["Every request"] } end, { "first", "every" }, "all",
				{ disabled = function() return not P().sound.enabled end }),
			glowHead = header(30, L["Glow"]),
			glow = toggle(31, L["Glowing edge"], L["The window's edge glows while anyone is waiting."], "window.glow", "look"),
		},
	}

	-- Folded icon
	a.folded = {
		type = "group", order = 60, name = L["Folded icon"],
		args = {
			show = choose(1, L["Shows"], L["When the round icon is on screen."], "folded.show",
				function() return { folded = L["While the window is folded"], always = L["Always"], waiting = L["While someone waits"] } end,
				{ "folded", "always", "waiting" }, "all"),
			art = choose(2, L["Picture"], L["The logo, or the next request's spell."], "folded.art",
				function() return { logo = L["Logo"], next = L["Next spell"] } end, { "logo", "next" }, "all"),
			size = range(3, L["Size"], L["The icon's size in pixels."], "folded.size", 20, 64, 1, "all"),
			badge = toggle(4, L["Count badge"], L["The pink count at the top right."], "folded.badge", "all"),
			glow = toggle(5, L["Glow"], L["Glows while anyone is waiting."], "folded.glow", "all"),
			ring = toggle(6, L["Ring"], L["A ring around the icon."], "folded.ring", "all"),
			alphaOut = range(7, L["Opacity out of combat"], L["How solid the icon is out of combat."], "folded.alphaOut", 0, 1, 0.05, "all", { isPercent = true }),
			alphaIn = range(8, L["Opacity in combat"], L["How solid the icon is in combat."], "folded.alphaIn", 0, 1, 0.05, "all", { isPercent = true }),
		},
	}

	-- Profiles
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(WCSW.db)
	profiles.order = 100
	a.profiles = profiles

	self.tree = tree
	self.spellSig = nil
	self:UpdateSpells()
	return tree
end

---------------------------------------------------------------- opening
local TABS = { general = true, spells = true, window = true, castButton = true, alerts = true, folded = true, profiles = true }
Options.TABS = TABS

-- opens the settings window, at a tab when one is named
function WCSW:OpenSettings(tab)
	Options:UpdateSpells()
	if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
	if InterfaceOptionsFrame and InterfaceOptionsFrame.IsShown and InterfaceOptionsFrame:IsShown() then pcall(HideUIPanel, InterfaceOptionsFrame) end
	ACD():Open(APP)
	if tab and TABS[tab] then
		ACD():SelectGroup(APP, tab)
	end
end

function WCSW:CloseSettings()
	ACD():Close(APP)
end

-- the AddOns list's page: words and one button
local function addLauncher()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(BLIZ, {
		type = "group",
		name = WCSW.TITLE,
		args = {
			about = text(1, L["WhisperCast: Second Wind has its settings in its own window."] .. "\n"),
			open = {
				type = "execute", order = 2, width = 1.5, name = L["Open settings"],
				desc = L["Opens the settings window (the same as /wc settings)."],
				func = function() WCSW:OpenSettings() end,
			},
		},
	})
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local ok, frame = pcall(ACD().AddToBlizOptions, ACD(), BLIZ, WCSW.TITLE)
		if ok then
			Options.blizFrame = frame
			return "settings"
		end
	end
	if InterfaceOptions_AddCategory then
		-- older clients: a plain page with the button
		local panel = CreateFrame("Frame", "WhisperCastSWOptionsPanel", UIParent)
		panel.name = WCSW.TITLE
		local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 16, -16)
		title:SetText(WCSW.TITLE)
		local about = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
		about:SetText(L["WhisperCast: Second Wind has its settings in its own window."])
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetSize(160, 24)
		button:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -12)
		button:SetText(L["Open settings"])
		button:SetScript("OnClick", function() WCSW:OpenSettings() end)
		InterfaceOptions_AddCategory(panel)
		Options.blizFrame = panel
		return "interface"
	end
end

Options.AddLauncher = addLauncher

---------------------------------------------------------------- module
function Options:Init()
	self:Build()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(APP, self.tree)
	self.registered = true
	ACD():SetDefaultSize(APP, 720, 600)
	self.blizWay = addLauncher()
	WCSW:AddSlash("settings", function(rest)
		WCSW:OpenSettings(rest and rest ~= "" and rest or nil)
	end, L["open the settings"])
	-- a change made elsewhere (/wc lock, Edit Mode) shows in an open window
	WCSW.RegisterCallback(self, "LockChanged", function() REG():NotifyChange(APP) end)
end

function Options:Enable()
	self:UpdateSpells()
end

-- after a profile change or reset: the open window shows the new profile
function Options:Refresh()
	self:UpdateSpells()
	REG():NotifyChange(APP)
end
