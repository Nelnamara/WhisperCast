--[[
	WhisperCast: Second Wind - the Cast button (docs/DESIGN_HANDOFF.md "The Cast button" and "In combat").

	WhisperCastSWCastButton is a secure action button (Bindings.xml binds "CLICK WhisperCastSWCastButton:
	LeftButton"). Out of combat, on every queue change, every secure Cast button (this one, the window's
	classic Cast and CooldownCollaborator's from WhisperCastSW:CreateCastButton) is set from WCSW:NextCast():
	type "spell", spell = the rank's spell ID, unit = the asker's unit. PreClick tells the Engine which cast
	was pressed (WCSW:CastClicked). In combat nothing is set again: the cast armed when the fight began stays,
	and a secure wrap clears the button's type after the press that cast it, so a second press does nothing.
	Out of combat (PLAYER_REGEN_ENABLED) it is set up again.
]]

local WCSW = WhisperCastSW
local L, UI = WCSW.L, WCSW.UI
local C = UI.C

local CB = WCSW:AddModule("CastButton", {})
WCSW.CastButton = CB
CB.buttons = {}      -- every secure Cast button, kept in step
CB.cast = nil        -- what they cast now (the armed cast in combat)
CB.spent = false     -- the armed cast was pressed in combat (the wrap cleared type)

local function db() return WCSW.db.profile.castButton end
local function view()
	if WCSW.GetView then return WCSW:GetView() end
	return { count = 0, groups = {}, rest = {} }
end
local function spellOf(key) return key and WCSW.spells and WCSW.spells[key] end

---------------------------------------------------------------- the secure part
-- The wrap: in combat, after the press that cast (the key's release, whichever of down and up cast),
-- the button's type goes, so the armed request casts once. Restricted code: it runs in the secure
-- environment, where PlayerInCombat() and the frame's own attributes are readable.
CB.WRAP_PRE = [[
	if PlayerInCombat() and self:GetAttribute("type") then
		return nil, "armed"
	end
]]
CB.WRAP_POST = [[
	if not down then
		self:SetAttribute("type", nil)
	end
]]

local header   -- the secure handler the wraps belong to
local function Header()
	if not header then
		header = CreateFrame("Frame", "WhisperCastSWSecureHeader", UIParent, "SecureHandlerBaseTemplate")
	end
	return header
end

-- does this event of a press act? The template casts on the down event when ActionButtonUseKeyDown is on,
-- else on the up event; PreClick runs for both, so the Engine hears about the one that casts.
local function Acts(down)
	if down == nil then return true end
	local keyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and true or false
	return (down and keyDown) or (not down and not keyDown)
end
CB.Acts = Acts

local function SetCast(b, cast)
	if cast then
		b:SetAttribute("type", "spell")
		b:SetAttribute("spell", cast.castID)
		b:SetAttribute("unit", cast.unit)
	else
		b:SetAttribute("type", nil)
		b:SetAttribute("spell", nil)
		b:SetAttribute("unit", nil)
	end
end

-- a new secure Cast button; set up like the others from then on
function CB:NewSecure(name, parent)
	local b = CreateFrame("Button", name, parent or UIParent, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetScript("PreClick", function(self, _, down)
		if not Acts(down) or self:GetAttribute("type") ~= "spell" then return end
		-- out of combat, an asker out of range: stop this press (the game would cast it on you instead);
		-- PostClick counts the try, which sets the buttons up again
		if CB.cast and not InCombatLockdown() and WCSW.CastAllowed and not WCSW:CastAllowed(CB.cast) then
			self:SetAttribute("type", nil)
			self.blocked = CB.cast
			return
		end
		if CB.cast and WCSW.CastClicked then WCSW:CastClicked(CB.cast) end
	end)
	b:SetScript("PostClick", function(self)
		if self.blocked then
			local cast = self.blocked
			self.blocked = nil
			if WCSW.CastBlocked then WCSW:CastBlocked(cast) end
			CB:Arm()   -- the type comes back even when nothing in the queue moved
			return
		end
		-- the wrap cleared the armed cast: show it spent
		if UI.Locked() and CB.cast and not self:GetAttribute("type") and not CB.spent then
			CB.spent = true
			UI.RedrawAll()
		end
	end)
	UI.AfterCombat("wrap:" .. tostring(name or #self.buttons + 1), function()
		SecureHandlerWrapScript(b, "OnClick", Header(), CB.WRAP_PRE, CB.WRAP_POST)
		SetCast(b, (not UI.IsUnlocked()) and CB.cast or nil)
	end)
	self.buttons[#self.buttons + 1] = b
	return b
end

-- Set every button from the Engine's next cast; out of combat only (in combat: once the fight ends).
-- While the frames are unlocked the buttons cast nothing, so dragging one can't cast.
function CB:Arm()
	return UI.AfterCombat("arm", function()
		local cast = WCSW.NextCast and WCSW:NextCast() or nil
		if cast and not (cast.castID and cast.unit) then cast = nil end
		CB.cast, CB.spent = cast, false
		local live = (not UI.IsUnlocked()) and cast or nil
		for _, b in ipairs(CB.buttons) do SetCast(b, live) end
	end)
end

---------------------------------------------------------------- the look
-- icon, key top-right, count bottom-right, the asker and spell under it, the frame line, the pink glow
local function Dress(b, withLabel)
	b.icon = UI.Tex(b, "ARTWORK", nil, WCSW.LOGO)
	b.icon:SetAllPoints(b)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.line1 = UI.NewEdge(b, "BACKGROUND", 1)   -- 1 px black round it
	b.line1:SetShape(0, 1, -1)
	b.line1:SetColor(0, 0, 0, 1)
	b.line2 = UI.NewEdge(b, "BACKGROUND")      -- then 1 px grey
	b.line2:SetShape(0, 1, -2)
	b.line2:SetColor(C.abEdge[1], C.abEdge[2], C.abEdge[3], 1)
	b.glow = UI.NewGlow(b, 14)
	UI.SetGlowShape(b.glow, 0, 1, -2)
	b.roundGlow = UI.NewRoundGlow(b)
	b.key = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -2)
	b.key:SetJustifyH("RIGHT")
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 2)
	b.count:SetJustifyH("RIGHT")
	if withLabel then
		b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.name:SetPoint("TOP", b, "BOTTOM", 0, -4)
		b.spellText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.spellText:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
	end
	b.dressed = true
end

local function SizeText(b, size)
	local k = size / 40
	UI.Font(b.key, 11 * k, "OUTLINE", true)
	UI.Font(b.count, 13 * k, "OUTLINE", true)
	b.key:SetTextColor(1, 1, 1, 1)
	b.count:SetTextColor(1, 1, 1, 1)
	if b.name then
		UI.Font(b.name, 11, nil, true)
		UI.Font(b.spellText, 11, nil, true)
		local c = C.spell
		b.spellText:SetTextColor(c[1], c[2], c[3], 1)
	end
end

-- draw one button from the cast it holds and the view
function CB:DrawButton(b, v)
	if not b.dressed then return end
	local cast, p = CB.cast, db()
	local waiting = (v.count or 0) > 0
	local masqued = b.wcswMasque ~= nil
	local round = masqued and UI.IsRound(b)
	local spell = cast and spellOf(cast.spell)
	if cast then
		b.icon:SetTexture(spell and spell.icon or WCSW.UNKNOWN_ICON)
		b.icon:SetAlpha(1)
	else
		b.icon:SetTexture(WCSW.LOGO)
		b.icon:SetAlpha(0.4)
	end
	b.icon:SetDesaturated(CB.spent or (not cast and true) or false)
	b.key:SetText(WCSW:CastKey() or "")
	b.count:SetText(waiting and tostring(v.count) or "")
	-- the label: the asker in class colour, the spell under it
	if b.name then
		local req = cast and cast.reqs and cast.reqs[1]
		local show = p.label and req ~= nil
		b.name:SetShown(show)
		b.spellText:SetShown(show)
		if show then
			---@cast cast table
			---@cast req table
			local r, g, bl = WCSW:ClassColor(req.class)
			local more = #cast.reqs > 1 and (" +" .. (#cast.reqs - 1)) or ""
			b.name:SetText((req.short or WCSW:ShortName(req.name) or "?") .. more)
			b.name:SetTextColor(r, g, bl, 1)
			b.spellText:SetText(spell and spell.name or "")
		end
	end
	-- the frame line (Masque draws its own) and the pink glow while something waits
	b.line1:SetShown(not masqued)
	b.line2:SetShown(not masqued and not waiting)
	local ar, ag, ab = WCSW:LookColor("accent")
	local size = b:GetWidth() or 40
	if size <= 0 then size = 40 end
	UI.SetGlowColor(b.glow, ar, ag, ab)
	UI.SetRoundGlowColor(b.roundGlow, ar, ag, ab)
	UI.SetRoundGlowSize(b.roundGlow, size)
	b.glow:SetShown(waiting and not round)
	b.roundGlow:SetShown(waiting and round)
end

---------------------------------------------------------------- the main button
local main
local mover

local function Visible()
	local p = db()
	if not p.shown then return false end
	if UI.IsUnlocked() then return true end
	return CB.cast ~= nil or p.empty ~= "hide"
end

function CB:Layout()
	if not main then return end
	local p = db()
	local size = math.max(24, math.min(64, p.size or 40))
	UI.AfterCombat("cb:layout", function()
		main:SetSize(size, size)
		main:SetShown(Visible())
	end)
	SizeText(main, size)
	UI.SetGlowReach(main.glow, math.max(8, 14 * size / 40))
	-- Masque: "WhisperCast: Second Wind" / "Cast button"
	UI.MasqueSkin(main, "Cast button", { Icon = main.icon, HotKey = main.key, Count = main.count })
end

function CB:Draw()
	if not main then return end
	local v = view()
	for _, b in ipairs(self.buttons) do self:DrawButton(b, v) end
	local p = db()
	if UI.Locked() then
		-- no Show/Hide in combat: an empty button set to hide goes clear instead
		main:SetAlpha((not CB.cast and p.empty == "hide" and not UI.IsUnlocked()) and 0 or 1)
	else
		main:SetAlpha(1)
		UI.AfterCombat("cb:shown", function() main:SetShown(Visible()) end)
	end
end

-- CooldownCollaborator's Asks tab: a second secure button, set up and drawn like the main one
local extra = 1
function WCSW:CreateCastButton(parent)
	extra = extra + 1
	local b = CB:NewSecure("WhisperCastSWCastButton" .. extra, parent)
	Dress(b, false)
	b:SetSize(40, 40)
	SizeText(b, 40)
	CB:DrawButton(b, view())
	return b
end

---------------------------------------------------------------- lifecycle
-- made at load, so the binding's button exists from the start
main = CB:NewSecure("WhisperCastSWCastButton", UIParent)
CB.main = main
main:SetFrameStrata("MEDIUM")
main:SetSize(40, 40)
Dress(main, true)

function CB:Init()
end

function CB:Enable()
	mover = UI.AddMover({
		key = "castButton", frame = main, label = L["Cast button"], point = "CENTER", protected = true,
		db = function() return db() end,
		default = { "CENTER", "CENTER", 0, -200 },
		canDrag = function() return not UI.Locked() end,
	})
	UI.MakeDraggable(mover)
	UI.ApplyPosition(mover)
	main:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(WCSW.TITLE)
		local cast = CB.cast
		local req = cast and cast.reqs and cast.reqs[1]
		local spell = cast and spellOf(cast.spell)
		if req then
			GameTooltip:AddLine(string.format(L["%s on %s"], spell and spell.name or "?",
				req.short or WCSW:ShortName(req.name) or "?"), 1, 1, 1)
		else
			GameTooltip:AddLine(L["No requests"], 0.7, 0.7, 0.7)
		end
		if UI.IsUnlocked() then GameTooltip:AddLine(L["Drag to move."], 0.7, 0.7, 0.7) end
		GameTooltip:Show()
	end)
	main:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local function redraw() CB:Draw() end
	WCSW.RegisterCallback(CB, "QueueChanged", function() CB:Arm(); CB:Draw() end)
	WCSW.RegisterCallback(CB, "ArmedChanged", function() CB:Arm(); CB:Draw() end)
	WCSW.RegisterCallback(CB, "CombatChanged", redraw)
	WCSW.RegisterCallback(CB, "LookChanged", function() CB:Layout(); CB:Draw() end)
	WCSW.RegisterCallback(CB, "LockChanged", function() CB:Arm(); CB:Layout(); CB:Draw() end)
	UI.combatHooks[#UI.combatHooks + 1] = function(inCombat)
		if not inCombat then CB:Arm() end
		CB:Draw()
	end
	self:Layout()
	self:Arm()
	self:Draw()
end

function CB:Refresh()
	if mover then UI.ApplyPosition(mover) end
	self:Layout()
	self:Arm()
	self:Draw()
end

UI.redraws[#UI.redraws + 1] = function() CB:Draw() end
