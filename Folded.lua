--[[
	WhisperCast: Second Wind - the round icon the window folds to (docs/DESIGN_HANDOFF.md "Folded away").
	34 px round (db.folded.size 20 to 64), Masque group "WhisperCast: Second Wind" / "Folded icon". The pink
	count badge top-right; it glows while something waits. Left-click opens the window, right-click the
	settings, drag moves it (unlocked or Edit Mode). Settings: the logo or the next request's spell icon,
	badge, glow, ring border, opacity out of and in combat, and when it shows (always, only while folded,
	only while something waits).
]]

local WCSW = WhisperCastSW
local L, UI = WCSW.L, WCSW.UI

local F = WCSW:AddModule("Folded", {})
WCSW.Folded = F

local btn, mover
local function db() return WCSW.db.profile.folded end
local function view()
	if WCSW.GetView then return WCSW:GetView() end
	return { count = 0, groups = {}, rest = {} }
end

local function Build()
	btn = CreateFrame("Button", "WhisperCastSWFolded", UIParent)
	F.button = btn
	btn:SetFrameStrata("MEDIUM")
	btn:SetSize(34, 34)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn.icon = UI.Tex(btn, "ARTWORK", nil, WCSW.LOGO)
	btn.icon:SetAllPoints(btn)
	-- round: the game's portrait mask (every client here has mask textures)
	if btn.CreateMaskTexture then
		btn.mask = btn:CreateMaskTexture()
		btn.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		btn.mask:SetAllPoints(btn.icon)
		btn.icon:AddMaskTexture(btn.mask)
		btn.masked = true
	end
	btn.ring = UI.Tex(btn, "OVERLAY", nil, UI.MEDIA .. "ring")
	btn.ring:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn.roundGlow = UI.NewRoundGlow(btn)
	btn.glow = UI.NewGlow(btn, 12)   -- for a square Masque skin
	UI.SetGlowShape(btn.glow, 0, 1, -1)
	btn.badge = UI.NewBadge(btn)
	btn.badge:SetFrameLevel((btn:GetFrameLevel() or 1) + 6)
	btn.badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 6, 6)

	btn:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			UI.OpenSettings("folded")
		else
			WCSW:SetFolded(false)
		end
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(WCSW.TITLE)
		local n = view().count or 0
		if n > 0 then GameTooltip:AddLine(string.format(L["%d waiting"], n), 1, 1, 1) end
		GameTooltip:AddLine(L["Left-click: open the window"], 0.7, 0.7, 0.7)
		GameTooltip:AddLine(L["Right-click: settings"], 0.7, 0.7, 0.7)
		if UI.IsUnlocked() then GameTooltip:AddLine(L["Drag to move."], 0.7, 0.7, 0.7) end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- shown per its rule: always, only while the window is folded, or only while something waits
function F:Wanted(v)
	local p, w = db(), WCSW.db.profile.window
	if UI.IsUnlocked() then return true end
	if p.show == "always" then return true end
	if p.show == "waiting" then return (v.count or 0) > 0 end
	return w.folded and true or false
end

function F:Layout()
	if not btn then return end
	local p = db()
	local size = math.max(20, math.min(64, p.size or 34))
	btn:SetSize(size, size)
	btn.ring:SetSize(size + 2, size + 2)
	UI.SetRoundGlowSize(btn.roundGlow, size)
	UI.MasqueSkin(btn, "Folded icon", { Icon = btn.icon })
end

function F:Draw()
	if not btn then return end
	local p, v = db(), view()
	local count = v.count or 0
	local masqued = btn.wcswMasque ~= nil
	local round = not masqued or UI.IsRound(btn)
	-- the art: the logo, or the next request's spell icon
	local icon = WCSW.LOGO
	if p.art == "next" and count > 0 then
		local cast = (WCSW.CastButton and WCSW.CastButton.cast) or (WCSW.NextCast and WCSW:NextCast())
		local key = cast and cast.spell or (v.next and v.next.spell)
		local spell = key and WCSW.spells and WCSW.spells[key]
		icon = spell and spell.icon or icon
	end
	btn.icon:SetTexture(icon)
	-- a square Masque skin draws square; its own mask and ring go
	if btn.mask then
		if round and not btn.masked then
			btn.icon:AddMaskTexture(btn.mask)
			btn.masked = true
		elseif not round and btn.masked then
			btn.icon:RemoveMaskTexture(btn.mask)
			btn.masked = false
		end
	end
	-- the ring border: the look's edge colour (the accent on Flat modern, which has no edge)
	local er, eg, eb, ea = WCSW:LookColor("edge")
	if ea < 0.05 then er, eg, eb, ea = WCSW:LookColor("accent") end
	btn.ring:SetVertexColor(er, eg, eb, ea)
	btn.ring:SetShown(p.ring and not masqued)
	-- badge and glow while something waits
	if p.badge and count > 0 then
		UI.SetBadge(btn.badge, count)
		btn.badge:Show()
	else
		btn.badge:Hide()
	end
	local ar, ag, ab = WCSW:LookColor("accent")
	UI.SetRoundGlowColor(btn.roundGlow, ar, ag, ab)
	UI.SetGlowColor(btn.glow, ar, ag, ab)
	local glow = p.glow and count > 0
	btn.roundGlow:SetShown(glow and round)
	btn.glow:SetShown(glow and not round)
	-- opacity in and out of combat
	btn:SetAlpha(UI.InCombat() and (p.alphaIn or 1) or (p.alphaOut or 1))
	btn:SetShown(self:Wanted(v))
end

function F:Enable()
	Build()
	mover = UI.AddMover({
		key = "folded", frame = btn, label = L["Folded icon"], point = "CENTER",
		db = function() return db() end,
		default = { "CENTER", "CENTER", -430, 190 },
	})
	UI.MakeDraggable(mover)
	UI.ApplyPosition(mover)
	local function redraw() F:Draw() end
	WCSW.RegisterCallback(F, "QueueChanged", redraw)
	WCSW.RegisterCallback(F, "ArmedChanged", redraw)
	WCSW.RegisterCallback(F, "CombatChanged", redraw)
	WCSW.RegisterCallback(F, "LockChanged", redraw)
	WCSW.RegisterCallback(F, "LookChanged", function() F:Layout(); F:Draw() end)
	UI.combatHooks[#UI.combatHooks + 1] = redraw
	UI.redraws[#UI.redraws + 1] = redraw
	self:Layout()
	self:Draw()
end

function F:Refresh()
	if not btn then return end
	UI.ApplyPosition(mover)
	self:Layout()
	self:Draw()
end
