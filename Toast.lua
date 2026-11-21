--[[
	WhisperCast: Second Wind - the note when a request comes in, and its sound (docs/DESIGN_HANDOFF.md
	"When a request comes in"). A note 260 x 40 at scale 1: dark background, a 3 px accent edge on the
	left, the 24 px spell icon and "<Name> asks for <Spell>". It shows for db.toast.duration seconds and
	fades; several stack downward, up to db.toast.max. Its own place: beside the window until it is moved
	(unlocked, or Edit Mode with LibEditMode), with its own scale.

	The sound: WCSW.SOUNDS is the checked list (the 2007 whisper sound first, then the Blizzard sounds
	CooldownTimeline3 checked on every client); LibSharedMedia sounds are offered too (WCSW:SoundValues()).
	db.sound.when "first" plays only when the queue goes from empty to one (2007), "every" on each request.
]]

local WCSW = WhisperCastSW
local L, UI = WCSW.L, WCSW.UI
local C = UI.C

local T = WCSW:AddModule("Toast", {})
WCSW.Toast = T

local NOTE_W, NOTE_H, NOTE_GAP = 260, 40, 4
local FADE = 0.5

local holder, mover
local active = {}   -- the notes on screen, newest last
local pool = {}
local function db() return WCSW.db.profile.toast end
local function spellOf(key) return key and WCSW.spells and WCSW.spells[key] end

---------------------------------------------------------------- sounds
-- key = what db.sound.name holds; kit = a SOUNDKIT name, file = a file data ID (every client has these)
WCSW.SOUNDS = {
	{ key = "TELL_MESSAGE", name = L["Whisper (as in 2007)"], kit = "TELL_MESSAGE" },
	{ key = "Blizzard: Raid Warning", name = "Blizzard: Raid Warning", file = 567397 },
	{ key = "Blizzard: PvP Warning", name = "Blizzard: PvP Warning", file = 567488 },
	{ key = "Blizzard: Quest Complete", name = "Blizzard: Quest Complete", file = 567439 },
	{ key = "Blizzard: Quest Accepted", name = "Blizzard: Quest Accepted", file = 567400 },
	{ key = "Blizzard: Quest Progress", name = "Blizzard: Quest Progress", file = 567516 },
	{ key = "Blizzard: Level Up", name = "Blizzard: Level Up", file = 569593 },
	{ key = "Blizzard: Reputation Rank Up", name = "Blizzard: Reputation Rank Up", file = 568016 },
	{ key = "Blizzard: Queue Joined", name = "Blizzard: Queue Joined", file = 568587 },
	{ key = "Blizzard: Queue Pop", name = "Blizzard: Queue Pop", file = 568011 },
	{ key = "Blizzard: Alarm Clock 1", name = "Blizzard: Alarm Clock 1", file = 567436 },
	{ key = "Blizzard: Alarm Clock 2", name = "Blizzard: Alarm Clock 2", file = 567399 },
	{ key = "Blizzard: Alarm Clock 3", name = "Blizzard: Alarm Clock 3", file = 567458 },
	{ key = "Blizzard: Text Ping", name = "Blizzard: Text Ping", file = 567484 },
	{ key = "Blizzard: Whisper", name = "Blizzard: Whisper", file = 567421 },
	{ key = "Blizzard: Group Invite", name = "Blizzard: Group Invite", file = 567451 },
	{ key = "Blizzard: Map Ping", name = "Blizzard: Map Ping", file = 567416 },
	{ key = "Blizzard: Friend Online", name = "Blizzard: Friend Online", file = 567518 },
	{ key = "Blizzard: Battle.net Toast", name = "Blizzard: Battle.net Toast", file = 567402 },
	{ key = "Blizzard: Store Toast", name = "Blizzard: Store Toast", file = 915759 },
	{ key = "Blizzard: Flight Point Discovered", name = "Blizzard: Flight Point Discovered", file = 567497 },
	{ key = "Blizzard: Coin", name = "Blizzard: Coin", file = 567428 },
	{ key = "Blizzard: Night Elf Bell", name = "Blizzard: Night Elf Bell", file = 566558 },
	{ key = "Blizzard: Shay's Bell", name = "Blizzard: Shay's Bell", file = 568154 },
	{ key = "Blizzard: Holy Cast", name = "Blizzard: Holy Cast", file = 569763 },
	{ key = "Blizzard: Sparkle Chime", name = "Blizzard: Sparkle Chime", file = 5259954 },
	{ key = "Blizzard: Gold Cast", name = "Blizzard: Gold Cast", file = 6226466 },
	{ key = "Blizzard: Trading Post Celebration", name = "Blizzard: Trading Post Celebration", file = 4906957 },
	{ key = "Blizzard: Trading Post Coins", name = "Blizzard: Trading Post Coins", file = 4910746 },
}
for _, s in ipairs(WCSW.SOUNDS) do WCSW.SOUNDS[s.key] = s end

-- key -> name for a dropdown: the checked list, then every LibSharedMedia sound
function WCSW:SoundValues()
	local out = {}
	for _, s in ipairs(self.SOUNDS) do out[s.key] = s.name end
	local LSM = LibStub("LibSharedMedia-3.0", true)
	if LSM then
		for name in pairs(LSM:HashTable("sound")) do
			if name ~= "None" and not out[name] then out[name] = name end
		end
	end
	return out
end

-- Plays a sound by key; with no key, the picked one (the Options lane's Test button: it plays even when
-- the sound is off). True when something played.
function WCSW:PlayRequestSound(key)
	key = key or (self.db and self.db.profile.sound.name) or "TELL_MESSAGE"
	local s = self.SOUNDS[key]
	local ok = pcall(function()
		if s and s.kit then
			PlaySound(SOUNDKIT[s.kit], "SFX")
		elseif s and s.file then
			PlaySoundFile(s.file, "SFX")
		else
			local LSM = LibStub("LibSharedMedia-3.0", true)
			local path = LSM and LSM:IsValid("sound", key) and LSM:Fetch("sound", key)
			if not path then error("no sound") end
			PlaySoundFile(path, "SFX")
		end
	end)
	return ok
end

-- a new request: the sound per the settings (on, first or every)
function T:RequestSound()
	local s = WCSW.db.profile.sound
	if not s.enabled then return false end
	if s.when ~= "every" then
		local v = WCSW.GetView and WCSW:GetView()
		if v and (v.count or 0) > 1 then return false end
	end
	return WCSW:PlayRequestSound(s.name)
end

---------------------------------------------------------------- notes
local function NewNote()
	local n = CreateFrame("Frame", nil, holder)
	n:SetSize(NOTE_W, NOTE_H)
	n.fill = UI.NewBox(n, "BACKGROUND")
	n.fill:SetShape(3, 0)
	n.fill:SetColor(C.toastBg[1], C.toastBg[2], C.toastBg[3], C.toastBg[4])
	n.edge = UI.Tex(n, "BORDER")
	n.edge:SetPoint("TOPLEFT", n, "TOPLEFT", 0, 0)
	n.edge:SetPoint("BOTTOMLEFT", n, "BOTTOMLEFT", 0, 0)
	n.edge:SetWidth(3)
	n.icon = UI.Tex(n, "ARTWORK", nil, WCSW.LOGO)
	n.icon:SetSize(24, 24)
	n.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	n.icon:SetPoint("LEFT", n, "LEFT", 11, 0)
	n.text = n:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	n.text:SetPoint("LEFT", n.icon, "RIGHT", 8, 0)
	n.text:SetWidth(NOTE_W - 11 - 24 - 8 - 10)
	n.text:SetJustifyH("LEFT")
	n.text:SetWordWrap(false)
	return n
end

local function Dress(n)
	local r, g, b = WCSW:LookColor("accent")
	n.edge:SetVertexColor(r, g, b, 1)
	UI.Font(n.text, 12)
	n.text:SetTextColor(C.spell[1], C.spell[2], C.spell[3], 1)
end

local function Restack()
	for i, n in ipairs(active) do
		n:ClearAllPoints()
		n:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * (NOTE_H + NOTE_GAP))
	end
end

local function Release(n)
	n:Hide()
	pool[#pool + 1] = n
end

function T:Add(req)
	if not holder then return end
	local n = table.remove(pool) or NewNote()
	Dress(n)
	local spell = spellOf(req and req.spell)
	n.icon:SetTexture(spell and spell.icon or WCSW.UNKNOWN_ICON)
	local name = req and (req.short or WCSW:ShortName(req.name)) or "?"
	n.text:SetText(string.format(L["%s asks for %s"], UI.ClassHex(req and req.class) .. name .. "|r", spell and spell.name or "?"))
	n.born = GetTime()
	n.req = req
	n:SetAlpha(1)
	n:Show()
	active[#active + 1] = n
	while #active > math.max(1, db().max or 3) do Release(table.remove(active, 1)) end
	Restack()
	self:UpdateHolder()
	return n
end

function T:Clear()
	while #active > 0 do Release(table.remove(active)) end
	self:UpdateHolder()
end

function T:Count() return #active end

-- the notes age and fade (an OnUpdate on the holder, which is shown while it has any)
local function Tick()
	local dur = math.max(1, math.min(10, db().duration or 3))
	local now, changed = GetTime(), false
	for i = #active, 1, -1 do
		local n = active[i]
		local age = now - n.born
		if age >= dur + FADE then
			Release(table.remove(active, i))
			changed = true
		elseif age > dur then
			n:SetAlpha(1 - (age - dur) / FADE)
		end
	end
	if changed then
		Restack()
		T:UpdateHolder()
	end
end

-- the placeholder while unlocked: where the notes will show
function T:UpdateHolder()
	if not holder then return end
	local unlocked = UI.IsUnlocked()
	holder.sample:SetShown(unlocked and #active == 0)
	holder:EnableMouse(unlocked)
	holder:SetShown(unlocked or #active > 0)
end

function T:Layout()
	if not holder then return end
	holder:SetScale(math.max(0.5, math.min(2, db().scale or 1)))
	Dress(holder.sample)
	for _, n in ipairs(active) do Dress(n) end
	self:UpdateHolder()
end

---------------------------------------------------------------- lifecycle
function T:Enable()
	holder = CreateFrame("Frame", "WhisperCastSWToast", UIParent)
	T.holder = holder
	holder:SetSize(NOTE_W, NOTE_H)
	holder:SetFrameStrata("HIGH")
	holder:SetScript("OnUpdate", Tick)
	holder.sample = NewNote()
	holder.sample:SetAllPoints(holder)
	holder.sample.icon:SetTexture(WCSW.LOGO)
	holder.sample.text:SetText(L["Request notes show here"])
	holder.sample:Hide()
	mover = UI.AddMover({
		key = "toast", frame = holder, label = L["Request note"], point = "TOPLEFT",
		db = function() return db() end,
		default = { "TOPLEFT", "CENTER", -182, 200 },
		-- beside the window until it is moved
		anchor = function(f)
			f:ClearAllPoints()
			-- the settings window global exists once that window has been created
			---@diagnostic disable-next-line: undefined-global
			f:SetPoint("TOPLEFT", WhisperCastSWWindow or UIParent, WhisperCastSWWindow and "TOPRIGHT" or "CENTER", 8, 0)
		end,
	})
	UI.MakeDraggable(mover)
	UI.ApplyPosition(mover)

	WCSW.RegisterCallback(T, "RequestAdded", function(_, req)
		if db().enabled then T:Add(req) end
		T:RequestSound()
	end)
	WCSW.RegisterCallback(T, "LookChanged", function() T:Layout() end)
	WCSW.RegisterCallback(T, "LockChanged", function() T:UpdateHolder() end)
	self:Layout()
end

function T:Refresh()
	if not holder then return end
	UI.ApplyPosition(mover)
	self:Layout()
end
