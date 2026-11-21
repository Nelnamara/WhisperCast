--[[
	WhisperCast: Second Wind - the word chips (Settings › Spells and words; docs/DESIGN_HANDOFF.md
	"Trigger words (word chips)", look board section "triggers", the Word chips choice).

	A custom AceGUI widget, "WCSW_Chips", for an AceConfig option of type "input" with
	dialogControl = "WCSW_Chips". Each word is a pink-tinted pill with ×; a "+ word" pill opens a
	one-line box (Enter adds, Escape cancels); the pills wrap to more lines.

	Values: the option's get returns the words as one string, "mark, motw" (AceConfigDialog hands an
	input control only strings). The widget also takes a list through SetValue. Every change goes out
	as the whole new list (a table): first "OnValueChanged", then "OnEnterPressed", which is the
	callback AceConfigDialog listens to on an input, so the option's set receives the list. AceConfig
	then redraws the window, which releases this widget, so nothing here touches the widget after
	that last Fire.

	WCSW.Words holds the word rules both this file and Options.lua use: lower case, trimmed, inner
	spaces single, no commas (a comma splits words), no empty words, no duplicates.
]]

local WCSW = WhisperCastSW
local L = WCSW and WCSW.L or setmetatable({}, { __index = function(_, k) return k end })

---------------------------------------------------------------- the word rules
local Words = {}
if WCSW then WCSW.Words = Words end

-- one word as it's saved, or nil when nothing is left of it
function Words.Clean(word)
	if type(word) ~= "string" then return nil end
	-- a no-break space is a space; any run of spaces is one
	word = strtrim((strlower(word):gsub("\194\160", " "):gsub("%s+", " ")))
	if word == "" then return nil end
	return word
end

-- a list (table) or a "a, b" string -> a clean list: no empty words, no duplicates, first one kept
function Words.Parse(value)
	local raw = {}
	if type(value) == "table" then
		for _, w in ipairs(value) do
			if type(w) == "string" then
				for part in w:gmatch("[^,\r\n]+") do raw[#raw + 1] = part end
			end
		end
	elseif type(value) == "string" then
		for part in value:gmatch("[^,\r\n]+") do raw[#raw + 1] = part end
	end
	local out, seen = {}, {}
	for _, w in ipairs(raw) do
		local c = Words.Clean(w)
		if c and not seen[c] then
			seen[c] = true
			out[#out + 1] = c
		end
	end
	return out
end

function Words.Join(list)
	return table.concat(list or {}, ", ")
end

-- same words in the same order
function Words.Same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

---------------------------------------------------------------- the widget
local Type, Version = "WCSW_Chips", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local CHIP_H = 17          -- pill height (look board: 17 px)
local GAP = 3              -- between pills and between lines
local PAD = 6              -- text inset inside a pill
local X_W = 12             -- the × part
local BOX_W = 110          -- the one-line box that "+ word" opens
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- a white disc: halves make the pill ends
local NOTE = { 0.6, 0.6, 0.66 }  -- the note grey of the board (× and the "+ word" pill)
local TEXT = { 1, 0.84, 1 }      -- #ffd6ff

-- the accent colour setting (Looks: nil = the look's own); pills are tinted with it
local function accent()
	local O = WCSW and WCSW.Options
	if O and O.Color and WCSW.db then
		local ok, r, g, b = pcall(O.Color, "accent")
		if ok and type(r) == "number" then return r, g, b end
	end
	local a = WCSW and WCSW.ACCENT or { 1, 0.5, 1 }
	return a[1], a[2], a[3]
end

local function copy(list)
	local t = {}
	for i, w in ipairs(list) do t[i] = w end
	return t
end

local function tip(owner, text)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	GameTooltip:SetText(text, 1, 1, 1, 1, true)
	GameTooltip:Show()
end
local function untip(owner)
	if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

-- sends the whole new list out (see the top of the file); the last thing a change does
local function Commit(self, list)
	self.words = copy(list)
	self:Layout()
	self:Fire("OnValueChanged", copy(list))
	self:Fire("OnEnterPressed", copy(list))  -- AceConfigDialog: set, then a redraw that releases this widget
end

local function StopEditing(self)
	self.editing = false
	local box = self.editBox
	box:SetText("")
	box:ClearFocus()
	box:Hide()
end

---------------------------------------------------------------- scripts
local function Remove_OnClick(button)
	local self = button.obj
	if self.disabled then return end
	local word = button.word
	local list = {}
	for _, w in ipairs(self.words) do
		if w ~= word then list[#list + 1] = w end
	end
	untip(button)
	if #list ~= #self.words then Commit(self, list) end
end

local function Remove_OnEnter(button)
	button.x:SetTextColor(1, 1, 1)
	tip(button, format(L["Remove \"%s\""], button.word or ""))
end

local function Remove_OnLeave(button)
	button.x:SetTextColor(NOTE[1], NOTE[2], NOTE[3])
	untip(button)
end

local function Add_OnClick(button)
	local self = button.obj
	if self.disabled then return end
	self.editing = true
	untip(button)
	self.editBox:SetText("")
	self.editBox:Show()
	self:Layout()
	self.editBox:SetFocus()
	if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

local function Add_OnEnter(button)
	tip(button, L["Add a word. Several at once: separate them with commas."])
end

local function Box_OnEnterPressed(box)
	local self = box.obj
	local typed = box:GetText()
	StopEditing(self)
	local list = copy(self.words)
	local seen, added = {}, false
	for _, w in ipairs(list) do seen[w] = true end
	for _, w in ipairs(Words.Parse(typed)) do
		if not seen[w] then
			seen[w] = true
			list[#list + 1] = w
			added = true
		end
	end
	if added then
		Commit(self, list)
	else
		-- blank, or only words it already has: nothing changes
		self:Layout()
		if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
	end
end

local function Box_OnEscapePressed(box)
	local self = box.obj
	StopEditing(self)
	self:Layout()
	if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

-- clicking elsewhere cancels, as Escape does
local function Box_OnEditFocusLost(box)
	local self = box.obj
	if self.editing then Box_OnEscapePressed(box) end
end

---------------------------------------------------------------- pills
local function PillBackground(owner)
	local l = owner:CreateTexture(nil, "BACKGROUND")
	l:SetTexture(ROUND)
	l:SetTexCoord(0, 0.5, 0, 1)
	l:SetSize(CHIP_H / 2, CHIP_H)
	l:SetPoint("LEFT")
	local r = owner:CreateTexture(nil, "BACKGROUND")
	r:SetTexture(ROUND)
	r:SetTexCoord(0.5, 1, 0, 1)
	r:SetSize(CHIP_H / 2, CHIP_H)
	r:SetPoint("RIGHT")
	local m = owner:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(WHITE)
	m:SetPoint("TOPLEFT", l, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
	owner.bg = { l, m, r }
end

local function NewChip(self)
	local chip = CreateFrame("Frame", nil, self.frame)
	chip:SetHeight(CHIP_H)
	PillBackground(chip)
	local text = chip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("LEFT", PAD, 0)
	text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	chip.text = text
	local remove = CreateFrame("Button", nil, chip)
	remove:SetSize(X_W, CHIP_H)
	remove:SetPoint("RIGHT", -3, 0)
	local x = remove:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	x:SetPoint("CENTER", 0, 1)
	x:SetText("\195\151")  -- ×
	x:SetTextColor(NOTE[1], NOTE[2], NOTE[3])
	remove.x = x
	remove.obj = self
	remove:SetScript("OnClick", Remove_OnClick)
	remove:SetScript("OnEnter", Remove_OnEnter)
	remove:SetScript("OnLeave", Remove_OnLeave)
	chip.remove = remove
	return chip
end

local function NewAddChip(self, frame)
	local add = CreateFrame("Button", nil, frame)
	add:SetHeight(CHIP_H)
	-- a 1 px outline in the board's line grey
	local lines = {}
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = add:CreateTexture(nil, "BORDER")
		t:SetTexture(WHITE)
		t:SetVertexColor(NOTE[1], NOTE[2], NOTE[3], 0.5)
		t:SetPoint(p[1])
		t:SetPoint(p[2])
		if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
		lines[i] = t
	end
	local text = add:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("CENTER")
	text:SetTextColor(NOTE[1], NOTE[2], NOTE[3])
	text:SetText(L["+ word"])
	add.text = text
	add.obj = self
	add:SetScript("OnClick", Add_OnClick)
	add:SetScript("OnEnter", Add_OnEnter)
	add:SetScript("OnLeave", untip)
	return add
end

---------------------------------------------------------------- methods
local methods = {
	["OnAcquire"] = function(self)
		self.words = {}
		self.disabled = false
		self.editing = false
		self.labelText = nil
		self.editBox:SetText("")
		self.editBox:Hide()
		self.label:SetText("")
		self.label:Hide()
		self.frame:SetAlpha(1)
		self:SetWidth(300)
		self:Layout()
	end,

	["OnRelease"] = function(self)
		-- AceGUI hands this widget to the next spell: nothing of this one may stay
		self.editing = false
		self.editBox:SetText("")
		self.editBox:ClearFocus()
		self.editBox:Hide()
		for _, chip in ipairs(self.chips) do
			chip.remove.word = nil
			untip(chip.remove)
			chip:Hide()
		end
		untip(self.addChip)
		self.words = {}
		self.labelText = nil
		self.disabled = false
	end,

	-- AceConfigDialog: the option's name (shown above the pills when it isn't empty)
	["SetLabel"] = function(self, text)
		self.labelText = (text and text ~= "") and text or nil
		self.label:SetText(self.labelText or "")
		self.label:SetShown(self.labelText ~= nil)
		self:Layout()
	end,

	-- AceConfigDialog (input): the get value, "a, b"
	["SetText"] = function(self, text)
		self:SetValue(text)
	end,

	["GetText"] = function(self)
		return Words.Join(self.words)
	end,

	-- a list or a "a, b" string
	["SetValue"] = function(self, value)
		if self.editing then StopEditing(self) end
		self.words = Words.Parse(value)
		self:Layout()
	end,

	["GetValue"] = function(self)
		return copy(self.words)
	end,

	["SetDisabled"] = function(self, disabled)
		self.disabled = disabled and true or false
		if self.disabled and self.editing then StopEditing(self) end
		self.frame:SetAlpha(self.disabled and 0.5 or 1)
		self.addChip:SetEnabled(not self.disabled)
		for _, chip in ipairs(self.chips) do chip.remove:SetEnabled(not self.disabled) end
		self:Layout()
	end,

	-- AceConfigDialog may call these on an input control; one line, words are short
	["SetMaxLetters"] = function(self, n) self.editBox:SetMaxLetters(n or 0) end,
	["DisableButton"] = function() end,

	["OnWidthSet"] = function(self)
		self:Layout()
	end,

	-- places the pills left to right, wrapping, and sets the height to fit
	["Layout"] = function(self)
		if self.laying then return end
		self.laying = true
		local frame = self.frame
		local width = frame.width or frame:GetWidth() or 0
		if width < 60 then width = 300 end
		local top = 0
		if self.labelText then
			self.label:ClearAllPoints()
			self.label:SetPoint("TOPLEFT")
			self.label:SetPoint("TOPRIGHT")
			top = 14
		end
		local x, y = 0, top
		local function place(f, w)
			if x > 0 and x + w > width then
				x = 0
				y = y + CHIP_H + GAP
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
			f:SetWidth(w)
			x = x + w + GAP
		end
		local r, g, b = accent()
		for i, word in ipairs(self.words) do
			local chip = self.chips[i]
			if not chip then
				chip = NewChip(self)
				self.chips[i] = chip
			end
			chip.text:SetText(word)
			chip.remove.word = word
			chip.remove:SetEnabled(not self.disabled)
			for _, t in ipairs(chip.bg) do t:SetVertexColor(r, g, b, 0.22) end
			place(chip, math.ceil(chip.text:GetStringWidth()) + PAD + X_W + 5)
			chip:Show()
		end
		for i = #self.words + 1, #self.chips do
			self.chips[i].remove.word = nil
			self.chips[i]:Hide()
		end
		if self.editing then
			self.addChip:Hide()
			place(self.editBox, BOX_W)
			self.editBox:Show()
		else
			self.editBox:Hide()
			place(self.addChip, math.ceil(self.addChip.text:GetStringWidth()) + PAD * 2)
			self.addChip:Show()
		end
		local height = y + CHIP_H + 2
		frame:SetHeight(height)
		frame.height = height
		self.laying = nil
	end,
}

---------------------------------------------------------------- constructor
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetJustifyH("LEFT")
	label:SetHeight(12)
	label:Hide()

	local widget = {
		frame = frame,
		label = label,
		chips = {},
		words = {},
		type = Type,
	}
	for name, fn in pairs(methods) do widget[name] = fn end

	widget.addChip = NewAddChip(widget, frame)

	local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	box:SetHeight(CHIP_H + 1)
	box:SetAutoFocus(false)
	box:SetMaxLetters(40)
	box:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	box:SetTextInsets(4, 4, 0, 0)
	box.obj = widget
	box:SetScript("OnEnterPressed", Box_OnEnterPressed)
	box:SetScript("OnEscapePressed", Box_OnEscapePressed)
	box:SetScript("OnEditFocusLost", Box_OnEditFocusLost)
	box:Hide()
	widget.editBox = box

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
