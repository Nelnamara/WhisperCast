--[[
	WhisperCast: Second Wind - Blizzard Edit Mode (LibEditMode), as CooldownTimeline3 does it.
	The window, the Cast button, the request note and the folded icon appear in Edit Mode: drag one to
	move it; the note and the Cast button have a size slider in their Edit Mode settings. Positions are
	kept per Edit Mode layout (each frame's editMode[layoutName]), and as its plain position (what
	clients without Edit Mode use). LibEditMode is bundled by every TOC except Classic Era's; there,
	/wc unlock and drag.
]]

local WCSW = WhisperCastSW
local LEM = LibStub("LibEditMode", true)
if not LEM then return end
local L, UI = WCSW.L, WCSW.UI

local EM = WCSW:AddModule("EditMode", {})
WCSW.EditMode = EM
EM.registered = {}   -- frame -> mover

-- a frame's position for this layout, as UI.SavePosition keeps it
UI.onSaved = function(m, s, pt, layoutName)
	layoutName = layoutName or LEM:GetActiveLayoutName()
	if layoutName then
		s.editMode = s.editMode or {}
		s.editMode[layoutName] = { point = pt[1], relativePoint = pt[2], x = pt[3], y = pt[4] }
	end
end

-- moved in Edit Mode: keep it for this layout (by its own corner, so the window still grows down)
local function OnMoved(frame, layoutName)
	local m = EM.registered[frame]
	if m then UI.SavePosition(m, layoutName) end
end

-- every frame to where it was placed in this layout (a layout it was never placed in keeps it where it is)
function EM:ApplyLayout(layoutName)
	if not layoutName then return end
	for _, m in pairs(self.registered) do
		local s = m.db()
		local pos = s.editMode and s.editMode[layoutName]
		if pos then
			s.point = { pos.point, pos.relativePoint or pos.point, pos.x, pos.y }
			UI.ApplyPosition(m)
		end
	end
end

local function Slider(name, get, set, minValue, maxValue, step, default)
	return {
		kind = LEM.SettingType.Slider,
		name = name,
		default = default,
		minValue = minValue,
		maxValue = maxValue,
		valueStep = step,
		get = function() return get() end,
		set = function(_, value)
			set(value)
			WCSW:Fire("LookChanged")
		end,
	}
end

-- Edit Mode's own sliders: the note's scale and the Cast button's size
EM.SETTINGS = {
	toast = function()
		return { Slider(L["Scale"], function() return WCSW.db.profile.toast.scale end,
			function(v) WCSW.db.profile.toast.scale = v end, 0.5, 2, 0.05, 1) }
	end,
	castButton = function()
		return { Slider(L["Size"], function() return WCSW.db.profile.castButton.size end,
			function(v) WCSW.db.profile.castButton.size = v end, 24, 64, 1, 40) }
	end,
}

function EM:Register(m)
	if self.registered[m.frame] then return end
	self.registered[m.frame] = m
	local d = m.default
	LEM:AddFrame(m.frame, OnMoved, { point = d[1], x = d[3], y = d[4] }, m.label)
	local settings = self.SETTINGS[m.key]
	if settings then LEM:AddFrameSettings(m.frame, settings()) end
	if LEM.AddFrameSettingsButtons then
		LEM:AddFrameSettingsButtons(m.frame, {
			{ text = L["WhisperCast settings"], click = function() UI.OpenSettings() end },
		})
	end
end

function EM:Enable()
	for _, m in ipairs(UI.movers) do self:Register(m) end
	self:ApplyLayout(LEM:GetActiveLayoutName())
end

function EM:Refresh()
	-- a profile change puts back the profile's plain positions: this layout's go back on top
	self:ApplyLayout(LEM:GetActiveLayoutName())
end

local function ForEachPositions(fn)
	for _, m in ipairs(UI.movers) do
		local s = m.db()
		if s.editMode then fn(s.editMode) end
	end
end

LEM:RegisterCallback("layout", function(layoutName) EM:ApplyLayout(layoutName) end)
LEM:RegisterCallback("rename", function(oldName, newName)
	ForEachPositions(function(p) p[newName], p[oldName] = p[oldName], nil end)
end)
LEM:RegisterCallback("delete", function(layoutName)
	ForEachPositions(function(p) p[layoutName] = nil end)
end)
-- while Edit Mode is open the frames show (as unlocked) so they can be placed
LEM:RegisterCallback("enter", function()
	UI.editing = true
	WCSW:Fire("LockChanged", true)
end)
LEM:RegisterCallback("exit", function()
	UI.editing = false
	WCSW:Fire("LockChanged", WCSW.db and WCSW.db.profile.unlocked or false)
end)
