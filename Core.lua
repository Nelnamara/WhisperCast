--[[
	WhisperCast: Second Wind - core: the addon object, client detection, saved settings, the
	module list, callbacks and the slash command. Read docs/DESIGN_HANDOFF.md first.

	THE CONTRACT every other file builds on (don't change a name here without changing its users):

	Modules: each file adds itself with WCSW:AddModule(name, { Init = fn, Enable = fn, Refresh = fn }).
	  Init    runs in OnInitialize, after the saved settings exist (no frames that need the player yet)
	  Enable  runs at PLAYER_LOGIN (OnEnable), in file order
	  Refresh runs after a profile change or reset (WCSW:RefreshAll())

	Callbacks (CallbackHandler-1.0 on WCSW; WCSW.RegisterCallback(owner, "Event", fn)):
	  "QueueChanged"      ()            the queue or anything shown about it changed (UI redraws)
	  "RequestAdded"      (req)         a new request was queued (alerts: toast, sound, glow)
	  "RequestRemoved"    (req, why)    why = "cast", "failed", "cleared", "left", "disabled"
	  "CombatChanged"     (inCombat)
	  "ArmedChanged"      (req or nil)  the request on the Cast button changed
	  "LookChanged"       ()            look, colours, scale or font changed
	  "LockChanged"       (unlocked)

	A request (owned by Engine.lua; read-only for everyone else):
	  { id, name ("Name" or "Name-Realm" as whispered), short ("Name"), class ("PRIEST"), unit ("raid3"),
	    spell (a key into WCSW.spells), castID (the spell ID to cast, the right rank), rank (number or nil),
	    party (raid subgroup or 1), time (GetTime() when queued), fails (0..), inCombat (queued in combat),
	    armed (on the button in combat), done (cast in combat, waiting to be cleared) }

	A spell (owned by Data.lua and Engine.lua): WCSW.spells[key] =
	  { key, id (base spell ID), name (localized), icon, words (default trigger words, lower case),
	    group (key of its group version, or nil), isGroup (true for group versions), combat (cures etc.) }

	The view (Engine.lua builds it; the window, the button and CDC draw from it): WCSW:GetView() ->
	  { count, inCombat, next = req or nil, armed = req or nil,
	    groups = { { spell, count, askers = { req, ... }, groupCast = { spell, party, askers } or nil }, ... },
	    rest = { req, ... } }  -- groups when db.profile.window.grouped, else rest

	What the Cast button casts (Engine.lua): WCSW:NextCast() -> { castID, unit, spell, reqs = { req, ... } } or nil
	  WCSW:CastClicked(cast)  the button calls this from PreClick, so a success or failure is matched to it
]]

local ADDON_NAME, ns = ...
local WCSW = LibStub("AceAddon-3.0"):NewAddon("WhisperCastSW", "AceEvent-3.0", "AceConsole-3.0")
_G.WhisperCastSW = WCSW
ns.WCSW = WCSW
WCSW.ADDON_NAME = ADDON_NAME or "WhisperCastSecondWind"
WCSW.version = "1.0.0"
WCSW.TITLE = "WhisperCast: Second Wind"
WCSW.PREFIX = "WCSW"        -- addon message prefix
WCSW.REPLY_TAG = "[WC]"     -- start of every reply whisper
WCSW.MAX_TRIES = 4          -- out of range / line of sight / not in party: tries before a request is dropped
WCSW.TRY_GRACE = 1          -- seconds between counted tries
WCSW.ACCENT = { 1, 0.5, 1 } -- whisper pink; the accent colour setting starts here

local L = LibStub("AceLocale-3.0"):GetLocale("WhisperCastSW")
WCSW.L = L

---------------------------------------------------------------- clients
-- Same rules as CDTL3 and CDC: the interface number picks content, the API family picks calls.
local tocversion = select(4, GetBuildInfo())
WCSW.tocversion = tocversion
WCSW.isForever = tocversion >= 16000 and tocversion < 17000
WCSW.isRetail = tocversion >= 110000
WCSW.isMists = tocversion >= 50000 and tocversion < 60000
WCSW.isTBC = tocversion >= 20000 and tocversion < 30000
WCSW.isEra = tocversion < 20000 and not WCSW.isForever
WCSW.retailAPI = WCSW.isRetail or WCSW.isForever
WCSW.hasRanks = WCSW.isEra or WCSW.isTBC or WCSW.isForever  -- spells with ranks picked by target level
WCSW.client = (WCSW.isRetail and "retail") or (WCSW.isForever and "forever") or (WCSW.isMists and "mists")
	or (WCSW.isTBC and "tbc") or "era"

---------------------------------------------------------------- saved settings
-- Everything a setting changes lives here, so the Options lane and the UI lane agree on names.
-- Colours: nil means "the look's own value" (Looks.lua); a set colour is { r, g, b, a }.
-- Positions: { point, relativePoint, x, y } on UIParent; editMode[layoutName] per frame as CDTL3 does.
WCSW.defaults = {
	profile = {
		enabled = true,          -- taking requests
		match = "start",         -- "exact" (the whole whisper), "start" (its first words), "any" (any words)
		groupOnly = true,        -- only from party or raid members
		replies = true,          -- whisper the asker back
		hideOwnReplies = true,   -- hide my [WC] whispers from my chat
		hideRequests = false,    -- hide the request whispers from my chat
		unlocked = false,        -- frames can be dragged
		spells = {               -- [spellKey] = { enabled = bool, words = { ... } or nil (nil = the defaults) }
			["**"] = { enabled = true },
		},
		window = {
			shown = true,
			folded = false,
			look = "suite",      -- "suite", "blizzard", "flat"
			colors = {},         -- bg, edge, title, accent (nil = the look's own)
			scale = 1,
			fontSize = 12,
			width = 260,
			grouped = true,      -- grouped by spell under the spotlight
			classicButtons = false, -- Cast and Clear along the window's bottom
			glow = true,         -- glowing edge while something waits
			maxRows = 10,
			showWhenEmpty = true,
			combat = "show",     -- "show", "fade", "hide"
			combatAlpha = 0.4,
			lockRow = true,
			point = nil,
			editMode = {},
		},
		castButton = {
			shown = true,
			size = 40,
			label = true,        -- the asker's name and spell under it
			empty = "dim",       -- "dim" (logo at 40%) or "hide"
			point = nil,
			editMode = {},
		},
		toast = {
			enabled = true,
			duration = 3,
			scale = 1,
			max = 3,
			point = nil,
			editMode = {},
		},
		sound = {
			enabled = true,
			name = "TELL_MESSAGE",  -- a SOUNDKIT key from the checked Blizzard list, or a LibSharedMedia sound name
			when = "first",        -- "first" (empty -> one, as 2007) or "every"
		},
		folded = {
			size = 34,
			art = "logo",        -- "logo" or "next"
			badge = true,
			glow = true,
			ring = true,
			alphaOut = 1,        -- opacity out of combat
			alphaIn = 1,         -- opacity in combat
			show = "folded",     -- "folded" (only while the window is folded), "always", "waiting"
			point = nil,
			editMode = {},
		},
		minimap = { hide = false, angle = 200 },
	},
}

---------------------------------------------------------------- modules and callbacks
WCSW.modules = {}
function WCSW:AddModule(name, m)
	m.name = name
	self.modules[#self.modules + 1] = m
	return m
end
local function runAll(self, fn)
	for _, m in ipairs(self.modules) do
		if m[fn] then
			local ok, err = pcall(m[fn], m, self)
			if not ok then geterrorhandler()(err) end
		end
	end
end
function WCSW:RefreshAll()
	runAll(self, "Refresh")
	self:Fire("LookChanged")
	self:Fire("QueueChanged")
end

WCSW.callbacks = LibStub("CallbackHandler-1.0"):New(WCSW)
function WCSW:Fire(event, ...)
	self.callbacks:Fire(event, ...)
end

---------------------------------------------------------------- small shared helpers
function WCSW:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFFFF80FFWhisperCast|r " .. tostring(msg))
end

-- "Name-Realm" -> "Name"
function WCSW:ShortName(name)
	if not name then return nil end
	return (name:match("^([^%-]+)") or name)
end

-- r, g, b for a class file name ("PRIEST"); grey when unknown
function WCSW:ClassColor(class)
	-- CUSTOM_CLASS_COLORS exists only when a class-colour addon defines it
	---@diagnostic disable-next-line: undefined-global
	local c = class and (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
	if c then return c.r, c.g, c.b end
	return 0.7, 0.7, 0.7
end

-- the key bound to the Cast button, short ("F", "S-1"), or nil
function WCSW:CastKey()
	local key = GetBindingKey and GetBindingKey("CLICK WhisperCastSWCastButton:LeftButton")
	if key and GetBindingText then
		local ok, short = pcall(GetBindingText, key, "KEY_", true)
		if ok and short and short ~= "" then return short end
	end
	return key
end

---------------------------------------------------------------- slash command
-- Each file adds its own words: WCSW.slash["announce"] = function(rest) ... end
WCSW.slash = {}
WCSW.slashHelp = {}  -- { word, text } in the order they were added, for /wc help
function WCSW:AddSlash(word, fn, help)
	self.slash[word] = fn
	if help then self.slashHelp[#self.slashHelp + 1] = { word, help } end
end
function WCSW:OnSlash(input)
	local word, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	word = (word or ""):lower()
	local fn = self.slash[word]
	if fn then
		fn(rest)
	elseif word == "" and self.slash["toggle"] then
		self.slash["toggle"](rest)
	else
		self:Print(L["Commands:"])
		for _, h in ipairs(self.slashHelp) do
			DEFAULT_CHAT_FRAME:AddMessage("  /wc " .. h[1] .. " - " .. h[2])
		end
	end
end

---------------------------------------------------------------- lifecycle
function WCSW:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("WhisperCastSWDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshAll")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshAll")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshAll")
	self:RegisterChatCommand("wc", "OnSlash")
	self:RegisterChatCommand("whispercast", "OnSlash")
	runAll(self, "Init")
end

function WCSW:OnEnable()
	runAll(self, "Enable")
	self:Fire("LookChanged")
	self:Fire("QueueChanged")
end

-- Key Bindings screen (Bindings.xml)
BINDING_HEADER_WHISPERCASTSW = WCSW.TITLE
_G["BINDING_NAME_CLICK WhisperCastSWCastButton:LeftButton"] = L["Cast the next request"]
