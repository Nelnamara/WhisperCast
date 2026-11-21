--[[
	WhisperCast: Second Wind - the minimap button and a LibDataBroker launcher.
	Left-click shows or hides the window, right-click opens the settings, drag moves it round the minimap
	(db.profile.minimap.angle; hide = true takes it away). The launcher (Titan Panel and the other broker
	bars read it) is made only when some other addon has loaded LibDataBroker-1.1; it isn't bundled.
]]

local WCSW = WhisperCastSW
local L, UI = WCSW.L, WCSW.UI

local M = WCSW:AddModule("Minimap", {})
WCSW.MinimapButton = M

local btn
local function db() return WCSW.db.profile.minimap end

-- the button's centre just past the rim, following the minimap's live size (as CooldownCollaborator's)
local function Place()
	if not btn then return end
	local angle = math.rad(db().angle or 200)
	local radius = ((Minimap:GetWidth() or 140) / 2) + 5
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end

local function Tooltip(tt)
	tt:AddLine(WCSW.TITLE)
	local n = WCSW.GetView and (WCSW:GetView().count or 0) or 0
	if n > 0 then tt:AddLine(string.format(L["%d waiting"], n), 1, 1, 1) end
	tt:AddLine(L["Left-click: show or hide the window"], 0.7, 0.7, 0.7)
	tt:AddLine(L["Right-click: settings"], 0.7, 0.7, 0.7)
end

local function Click(mouse)
	if mouse == "RightButton" then
		UI.OpenSettings()
	else
		WCSW:ToggleWindow()
	end
end
M.Click = Click

local function Build()
	btn = CreateFrame("Button", "WhisperCastSWMinimapButton", Minimap)
	M.button = btn
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	-- the game's own minimap button art round the logo
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(WCSW.LOGO)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	btn.icon = icon
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

	btn:SetScript("OnClick", function(_, mouse) Click(mouse) end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		Tooltip(GameTooltip)
		GameTooltip:AddLine(L["Drag: move the button"], 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			-- the cursor is in screen pixels, the centre in the minimap's scale
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local s = Minimap:GetEffectiveScale() or 1
			local dx, dy = px / s - (mx or 0), py / s - (my or 0)
			db().angle = math.deg(math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx))
			Place()
		end)
	end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	Minimap:HookScript("OnSizeChanged", Place)
end

function M:Draw()
	if not btn then return end
	btn:SetShown(not db().hide)
	Place()
end

function M:Enable()
	Build()
	self:Draw()
	-- the launcher, only when a broker library is already loaded
	local LDB = LibStub("LibDataBroker-1.1", true)
	if LDB and not self.launcher then
		self.launcher = LDB:NewDataObject(WCSW.TITLE, {
			type = "launcher",
			label = WCSW.TITLE,
			icon = WCSW.LOGO,
			OnClick = function(_, mouse) Click(mouse) end,
			OnTooltipShow = function(tt) Tooltip(tt) end,
		})
	end
	WCSW.RegisterCallback(M, "LookChanged", function() M:Draw() end)
end

function M:Refresh()
	self:Draw()
end
