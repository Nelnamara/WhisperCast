--[[
	WhisperCast: Second Wind - the queue window (docs/DESIGN_HANDOFF.md "The queue window", "Looks",
	"In combat", "When a request comes in"). The board's picks: Next up, big; grouped by spell (a setting,
	on); the glowing edge; in combat, first one stays ready with the lock row and the count badge.

	Drawn from WCSW:GetView() and, for the spotlight, the cast the key will make (WCSW:NextCast(), or in
	combat the armed cast on the Cast button). With the classic buttons on, the window holds a secure
	Cast button, so in combat it is neither hidden, moved nor resized (it is sized for the fight when the
	fight begins, and what doesn't fit goes into "+N more"); "hide in combat" fades it instead (never below
	0.25), so no invisible Cast is ever left to click.
]]

local WCSW = WhisperCastSW
local L, UI = WCSW.L, WCSW.UI
local C = UI.C

local W = WCSW:AddModule("Window", {})
WCSW.Window = W

local TITLE_H = 20
local SPOT_H = 58       -- padding 8 + the 44 px icon + 6
local PAD_X = 5         -- the body's side padding
local GAP = 2           -- between rows
local GROUP_ROW_H = 22  -- 18 px icon + 2 + 2
local REQ_ROW_H = 18    -- 14 px icon + 2 + 2
local HEAD_H = 17       -- "THEN": 4 + 12 + 1
local MORE_H = 16
local LOCK_H = 21       -- 4 + 13 + 4, with margins 2 and 3
local FOOT_H = 28       -- a 22 px button and 6 below

local frame, mover
local function db() return WCSW.db.profile.window end
local function view()
	if WCSW.GetView then return WCSW:GetView() end
	return { count = 0, groups = {}, rest = {} }
end
local function spellOf(key) return key and WCSW.spells and WCSW.spells[key] end
local function setColor(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or c[4] or 1) end

-- the window holds a secure Cast button (the classic option): protected in combat
function W.Protected()
	return W.castBtn ~= nil and W.castBtn:GetParent() == frame
end

---------------------------------------------------------------- little parts
local function SmallButton(parent, kind)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(12, 12)
	b.bg = UI.NewBox(b, "BACKGROUND")
	b.bg:SetShape(2, 0)
	b.bg:SetColor(C.closeBg[1], C.closeBg[2], C.closeBg[3], C.closeBg[4])
	if kind == "close" then
		b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		UI.Font(b.mark, 11, nil, true)
		b.mark:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.mark:SetText("\195\151")   -- the multiplication sign
		setColor(b.mark, C.closeInk)
	else
		b.mark = UI.Tex(b, "OVERLAY")   -- the fold line, low in the box
		b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
		b.mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
		b.mark:SetHeight(1)
		b.mark:SetVertexColor(C.closeInk[1], C.closeInk[2], C.closeInk[3], 1)
	end
	return b
end

local function Icon(parent, size)
	local t = UI.Tex(parent, "ARTWORK", nil, WCSW.LOGO)
	t:SetSize(size, size)
	t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	return t
end

local function Dot(parent)
	local d = UI.Tex(parent, "OVERLAY", nil, UI.MEDIA .. "disc")
	d:SetSize(6, 6)
	return d
end

-- green in range, red out of range, nil when it can't be read (Retail and Forever in combat)
function W.InRange(castID, spell, unit)
	if not unit or not (castID or spell) then return nil end
	if WCSW.retailAPI and UI.InCombat() then return nil end
	if WCSW.InRange then return WCSW:InRange({ unit = unit, castID = castID or (spell and spell.id) }) end
	local ok, v = pcall(function()
		if not UnitExists(unit) then return nil end
		local r
		if C_Spell and C_Spell.IsSpellInRange then
			r = C_Spell.IsSpellInRange(castID or spell.id, unit)
		-- Classic-only global, in the branch for clients without C_Spell.IsSpellInRange
		---@diagnostic disable-next-line: undefined-global
		elseif IsSpellInRange and spell and spell.name then
			-- Classic-only global, in the branch for clients without C_Spell.IsSpellInRange
			---@diagnostic disable-next-line: undefined-global
			r = IsSpellInRange(spell.name, unit)
			if r ~= nil then r = (r == 1) end
		end
		if r == nil then return nil end
		return r and 1 or 0
	end)
	if not ok or v == nil then return nil end
	return v == 1
end

local function SetDot(d, inRange)
	if inRange == nil then d:Hide() return end
	local c = inRange and C.ready or C.far
	d:SetVertexColor(c[1], c[2], c[3], 1)
	d:Show()
end

local function SpellText(spell, rank)
	local name = spell and spell.name or "?"
	if WCSW.hasRanks and rank then
		return name .. " " .. UI.Hex(C.rank[1], C.rank[2], C.rank[3]) .. string.format(L["R%d"], rank) .. "|r"
	end
	return name
end

local function Waited(req)
	local s = math.max(0, GetTime() - (req.time or GetTime()))
	if s < 1 then return L["now"] end
	if s < 60 then return string.format(L["%ds"], math.floor(s)) end
	return string.format(L["%dm"], math.floor(s / 60))
end

local function ShortName(req) return req.short or WCSW:ShortName(req.name) or "?" end

---------------------------------------------------------------- building
local pools = { group = {}, req = {} }

local function RowBase(kind)
	local r = CreateFrame("Frame", nil, frame)
	r.bg = UI.Tex(r, "BACKGROUND")
	r.bg:SetAllPoints(r)
	r.bar = UI.Tex(r, "ARTWORK")
	r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -2)
	r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 3, 2)
	r.bar:SetWidth(3)
	r.kind = kind
	return r
end

local function GroupRow(i)
	local r = pools.group[i]
	if r then return r end
	r = RowBase("group")
	r.icon = Icon(r, 18)
	r.icon:SetPoint("LEFT", r, "LEFT", 11, 0)
	r.spell = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.spell:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
	r.spell:SetWordWrap(false)
	r.spell:SetJustifyH("LEFT")
	r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.count:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	r.count:SetJustifyH("RIGHT")
	-- the askers' names on one wrapping line, then the hint
	r.who = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.who:SetJustifyH("LEFT")
	r.who:SetWordWrap(true)
	r.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.hint:SetJustifyH("LEFT")
	r.hint:SetWordWrap(true)
	pools.group[i] = r
	return r
end

local function ReqRow(i)
	local r = pools.req[i]
	if r then return r end
	r = RowBase("req")
	r.icon = Icon(r, 14)
	r.icon:SetPoint("LEFT", r, "LEFT", 11, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
	r.name:SetWordWrap(false)
	r.dot = Dot(r)
	r.dot:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	r.time = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.time:SetJustifyH("RIGHT")
	r.spell = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.spell:SetPoint("LEFT", r.name, "RIGHT", 5, 0)
	r.spell:SetWordWrap(false)
	r.spell:SetJustifyH("LEFT")
	pools.req[i] = r
	return r
end

local function FooterButton(b)
	b.fill = UI.NewBox(b, "BACKGROUND")
	b.fill:SetShape(3, 0)
	b.edge = UI.NewEdge(b, "BORDER")
	b.edge:SetShape(3, 1, 0)
	b.hi = UI.Tex(b, "BORDER", 1)
	b.hi:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -1)
	b.hi:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -1)
	b.hi:SetHeight(1)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	return b
end

-- red game button, grey, accent outline or grey outline (the board's .btn styles)
local function SkinButton(b, style)
	local radius = (style == "outline" or style == "outlineGrey") and 0 or 3
	b.fill:SetShape(radius, 0)
	b.edge:SetShape(radius, 1, 0)
	if style == "red" or style == "grey" then
		local c1, c2 = style == "red" and C.btnRed1 or C.btnGrey1, style == "red" and C.btnRed2 or C.btnGrey2
		local e = style == "red" and C.btnEdge or C.btnGreyEdge
		b.fill:Show()
		b.fill:SetColor(c1[1], c1[2], c1[3], 1, c2[1], c2[2], c2[3], 1)
		b.edge:SetColor(e[1], e[2], e[3], 1)
		b.hi:Show()
		b.hi:SetVertexColor(C.btnHi[1], C.btnHi[2], C.btnHi[3], C.btnHi[4])
		setColor(b.text, style == "red" and C.gold or C.spell)
	else
		b.fill:Hide()
		b.hi:Hide()
		if style == "outline" then
			local r, g, bl = WCSW:LookColor("accent")
			b.edge:SetColor(r, g, bl, 1)
			b.text:SetTextColor(r, g, bl, 1)
		else
			b.edge:SetColor(C.flatGreyEdge[1], C.flatGreyEdge[2], C.flatGreyEdge[3], 1)
			setColor(b.text, C.flatGreyText)
		end
	end
	UI.Font(b.text, 11)
end

-- the classic Cast (secure, kept in step by CastButton.lua) and Clear, made the first time they're wanted
function W:BuildFooter()
	if self.castBtn then return end
	local cast = WCSW.CastButton:NewSecure("WhisperCastSWWindowCast", frame)
	FooterButton(cast)
	cast:SetHeight(22)
	self.castBtn = cast
	local clear = CreateFrame("Button", "WhisperCastSWWindowClear", frame)
	FooterButton(clear)
	clear:SetHeight(22)
	clear:SetScript("OnClick", function()
		if WCSW.ClearQueue then
			WCSW:ClearQueue()
		elseif WCSW.slash["clear"] then
			WCSW.slash["clear"]("")
		end
	end)
	self.clearBtn = clear
	WCSW.CastButton:Arm()
end

local function Build()
	frame = CreateFrame("Frame", "WhisperCastSWWindow", UIParent)
	W.frame = frame
	frame:SetFrameStrata("MEDIUM")
	frame:SetSize(260, 100)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)

	frame.fill = UI.NewBox(frame, "BACKGROUND")
	frame.edgeLine = UI.NewEdge(frame, "BORDER")
	frame.inner = UI.NewEdge(frame, "BORDER", 1)       -- Blizzard classic's dark inner line
	frame.topLine = UI.Tex(frame, "BORDER", 2)           -- Flat modern's accent line across the top
	frame.topLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.glow = UI.NewGlow(frame, 18)

	-- title bar: the handle to drag by
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(TITLE_H)
	bar:EnableMouse(true)
	frame.bar = bar
	bar.plate = UI.NewBox(bar, "BACKGROUND", 1)            -- Blizzard classic's title plate
	frame.divider = UI.Tex(frame, "BORDER")
	frame.divider:SetHeight(1)
	frame.title = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.title:SetText(WCSW.TITLE)
	frame.title:SetWordWrap(false)
	frame.fight = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.fight:SetPoint("LEFT", frame.title, "RIGHT", 6, 0)
	frame.fight:SetText(L["IN COMBAT"])
	frame.close = SmallButton(bar, "close")
	frame.close:SetScript("OnClick", function() WCSW:HideWindow() end)
	frame.fold = SmallButton(bar, "fold")
	frame.fold:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
	frame.fold:SetScript("OnClick", function() WCSW:SetFolded(true) end)
	for _, b in ipairs({ frame.close, frame.fold }) do
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	frame.close:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Close"])
		GameTooltip:AddLine(L["/wc or the minimap button opens it again."], 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	frame.fold:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Fold away"])
		GameTooltip:Show()
	end)
	frame.badge = UI.NewBadge(bar)
	frame.badge:SetPoint("RIGHT", frame.fold, "LEFT", -6, 0)

	-- the spotlight: the next cast, big
	local spot = CreateFrame("Frame", nil, frame)
	spot:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(TITLE_H + 1))
	spot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(TITLE_H + 1))
	spot:SetHeight(SPOT_H)
	frame.spot = spot
	spot.armedBg = UI.Tex(spot, "BACKGROUND")
	spot.armedBg:SetPoint("TOPLEFT", spot, "TOPLEFT", 4, -3)
	spot.armedBg:SetPoint("BOTTOMRIGHT", spot, "BOTTOMRIGHT", -4, 1)
	spot.armedHolder = CreateFrame("Frame", nil, spot)
	spot.armedHolder:SetPoint("TOPLEFT", spot, "TOPLEFT", 4, -3)
	spot.armedHolder:SetPoint("BOTTOMRIGHT", spot, "BOTTOMRIGHT", -4, 1)
	spot.armedLine = UI.NewEdge(spot.armedHolder, "BORDER")
	spot.armedLine:SetShape(2, 1, 0)
	spot.icon = Icon(spot, 44)
	spot.icon:SetPoint("TOPLEFT", spot, "TOPLEFT", 8, -8)
	spot.l1 = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	spot.l2 = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	spot.l3 = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	for _, fs in ipairs({ spot.l1, spot.l2, spot.l3 }) do
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
	end
	spot.l2:SetPoint("LEFT", spot.icon, "RIGHT", 9, 0)
	spot.l1:SetPoint("BOTTOMLEFT", spot.l2, "TOPLEFT", 0, 1)
	spot.l3:SetPoint("TOPLEFT", spot.l2, "BOTTOMLEFT", 0, -1)
	spot.dot = Dot(spot)
	spot.dot:SetPoint("LEFT", spot.l3, "RIGHT", 5, 0)
	spot.tag = CreateFrame("Frame", nil, spot)
	spot.tag:SetPoint("RIGHT", spot, "RIGHT", -10, 0)
	spot.tag.bg = UI.NewBox(spot.tag, "BACKGROUND")
	spot.tag.bg:SetShape(2, 0)
	spot.tag.text = spot.tag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	spot.tag.text:SetPoint("CENTER", spot.tag, "CENTER", 0, 0)

	-- the lock row: "Casts wait until the fight ends"
	local lock = CreateFrame("Frame", nil, frame)
	frame.lock = lock
	lock.bg = UI.NewBox(lock, "BACKGROUND")
	lock.bg:SetShape(3, 0)
	lock.bg:SetColor(C.lockBg[1], C.lockBg[2], C.lockBg[3], C.lockBg[4])
	lock.edge = UI.NewEdge(lock, "BORDER")
	lock.edge:SetShape(3, 1, 0)
	lock.edge:SetColor(C.lockEdge[1], C.lockEdge[2], C.lockEdge[3], C.lockEdge[4])
	-- the lock mark: a 9 x 7 body and its shackle
	local lc = C.lockText
	lock.body = UI.Tex(lock, "ARTWORK")
	lock.body:SetSize(9, 7)
	lock.body:SetPoint("BOTTOMLEFT", lock, "BOTTOMLEFT", 6, 5)
	lock.shL = UI.Tex(lock, "ARTWORK")
	lock.shL:SetSize(1.5, 4)
	lock.shL:SetPoint("BOTTOMLEFT", lock.body, "TOPLEFT", 1.5, 0)
	lock.shR = UI.Tex(lock, "ARTWORK")
	lock.shR:SetSize(1.5, 4)
	lock.shR:SetPoint("BOTTOMRIGHT", lock.body, "TOPRIGHT", -1.5, 0)
	lock.shT = UI.Tex(lock, "ARTWORK")
	lock.shT:SetHeight(1.5)
	lock.shT:SetPoint("TOPLEFT", lock.shL, "TOPLEFT", 0, 0)
	lock.shT:SetPoint("TOPRIGHT", lock.shR, "TOPRIGHT", 0, 0)
	for _, t in ipairs({ lock.body, lock.shL, lock.shR, lock.shT }) do t:SetVertexColor(lc[1], lc[2], lc[3], 1) end
	lock.text = lock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lock.text:SetPoint("LEFT", lock, "LEFT", 21, 0)
	lock.text:SetText(L["Casts wait until the fight ends"])

	frame.head = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.head:SetText(string.upper(L["Then"]))
	frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.more:SetJustifyH("LEFT")

	frame:Hide()
end

---------------------------------------------------------------- the look
function W:ApplyLook()
	if not frame then return end
	local look, p = WCSW:Look(), db()
	local r1, g1, b1, a1, r2, g2, b2, a2 = UI.BgColors()
	frame.fill:SetShape(look.radius, 0)
	frame.fill:SetColor(r1, g1, b1, a1, r2, g2, b2, a2)
	local er, eg, eb, ea = WCSW:LookColor("edge")
	frame.edgeLine:SetShape(look.radius, look.edgeSize, 0)
	frame.edgeLine:SetColor(er, eg, eb, ea)
	frame.edgeLine:SetShown(ea > 0)
	if look.inner then
		frame.inner:SetShape(math.max(0, look.radius - look.edgeSize), 1, look.edgeSize)
		frame.inner:SetColor(look.inner[1], look.inner[2], look.inner[3], 1)
		frame.inner:Show()
	else
		frame.inner:Hide()
	end
	local ar, ag, ab = WCSW:LookColor("accent")
	if look.topLine then
		frame.topLine:SetHeight(look.topLine)
		frame.topLine:SetVertexColor(ar, ag, ab, 1)
		frame.topLine:Show()
	else
		frame.topLine:Hide()
	end
	UI.SetGlowShape(frame.glow, look.radius, 2, -1)
	UI.SetGlowColor(frame.glow, ar, ag, ab)

	-- title bar
	local bar = frame.bar
	if look.plate then
		bar.plate:SetShape(math.max(0, look.radius - look.edgeSize), look.edgeSize, true)
		bar.plate:SetColor(look.plate[1], look.plate[2], look.plate[3], 1)
		bar.plate:Show()
	else
		bar.plate:Hide()
	end
	frame.divider:ClearAllPoints()
	local inset = (look.edgeSize or 1)
	frame.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -TITLE_H)
	frame.divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -TITLE_H)
	if look.divider then
		frame.divider:SetVertexColor(look.divider[1], look.divider[2], look.divider[3], look.divider[4] or 1)
		frame.divider:Show()
	else
		frame.divider:Hide()
	end
	UI.Font(frame.title, 12)
	frame.title:SetTextColor(WCSW:LookColor("title"))
	frame.title:ClearAllPoints()
	frame.close:ClearAllPoints()
	if look.titleAlign == "CENTER" then
		frame.title:SetPoint("CENTER", bar, "CENTER", 0, 0)
		frame.close:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
	else
		frame.title:SetPoint("LEFT", bar, "LEFT", look.topLine and 8 or 7, look.topLine and -1 or 0)
		frame.close:SetPoint("RIGHT", bar, "RIGHT", -7, 0)
	end
	UI.Font(frame.fight, 10)
	setColor(frame.fight, C.fight)

	-- spotlight and the rest
	local spot = frame.spot
	UI.Font(spot.l1, 10.5)
	UI.Font(spot.l2, 15)
	UI.Font(spot.l3, 12)
	setColor(spot.l1, C.note)
	setColor(spot.l3, C.spell)
	spot.armedBg:SetVertexColor(ar, ag, ab, 0.08)
	spot.armedLine:SetColor(ar, ag, ab, 1)
	UI.Font(spot.tag.text, 9.5)
	UI.Font(frame.lock.text, 11)
	setColor(frame.lock.text, C.lockText)
	UI.Font(frame.head, 10)
	setColor(frame.head, C.note)
	UI.Font(frame.more, 11)
	setColor(frame.more, C.note)
	for _, r in ipairs(pools.group) do
		UI.Font(r.spell, 12)
		UI.Font(r.count, 10.5)
		UI.Font(r.who, 11)
		UI.Font(r.hint, 10.5)
	end
	for _, r in ipairs(pools.req) do
		UI.Font(r.name, 12)
		UI.Font(r.spell, 12)
		UI.Font(r.time, 10.5)
	end
	if self.castBtn then
		SkinButton(self.castBtn, look.castButton)
		SkinButton(self.clearBtn, look.clearButton)
	end
	self.fontsFor = nil
	UI.AfterCombat("win:scale", function()
		frame:SetScale(math.max(0.6, math.min(2, p.scale or 1)))
		frame:SetWidth(p.width or 260)
	end)
end

---------------------------------------------------------------- drawing
-- the rows' fonts, set once per pooled row after a look change
local function RowFonts(r)
	if r.kind == "group" then
		UI.Font(r.spell, 12)
		UI.Font(r.count, 10.5)
		UI.Font(r.who, 11)
		UI.Font(r.hint, 10.5)
	else
		UI.Font(r.name, 12)
		UI.Font(r.spell, 12)
		UI.Font(r.time, 10.5)
	end
	r.fonted = true
end

local function RowLook(r, first, dim)
	local look = WCSW:Look()
	if look.rowBg then
		r.bg:SetVertexColor(look.rowBg[1], look.rowBg[2], look.rowBg[3], look.rowBg[4])
		r.bg:Show()
	else
		r.bg:Hide()
	end
	r.bar:SetShown(look.rowBars and true or false)
	r:SetAlpha(dim and 0.45 or 1)
	r.icon:SetDesaturated(dim and true or false)
end

-- the requests the spotlight shows, so the list under it leaves them out
local function SpotCast(v, inCombat)
	if inCombat then
		local cast = WCSW.CastButton.cast
		if cast then return cast, true end
	elseif WCSW.NextCast then
		local cast = WCSW:NextCast()
		if cast then return cast, false end
	end
	if v.next then
		return { spell = v.next.spell, castID = v.next.castID, unit = v.next.unit, reqs = { v.next } }, false
	end
	return nil, false
end

function W:DrawSpot(v, inCombat, key)
	local spot = frame.spot
	local cast, armed = SpotCast(v, inCombat)
	local spent = WCSW.CastButton.spent or (v.armed and v.armed.done)
	spot.tag:Hide()
	spot.armedBg:Hide()
	spot.armedLine:Hide()
	spot.dot:Hide()
	if not cast or (v.count or 0) == 0 and not armed then
		spot.icon:SetTexture(WCSW.LOGO)
		spot.icon:SetDesaturated(true)
		spot.icon:SetAlpha(0.6)
		spot.l1:Hide()
		spot.l3:Hide()
		spot.l2:SetText(L["No requests"])
		setColor(spot.l2, C.note)
		spot:SetAlpha(1)
		return {}
	end
	local spell = spellOf(cast.spell)
	local req = cast.reqs and cast.reqs[1] or v.next
	spot.icon:SetTexture(spell and spell.icon or WCSW.UNKNOWN_ICON)
	spot.icon:SetAlpha(1)
	spot.l1:Show()
	spot.l3:Show()
	spot.l1:SetText(string.upper(L["Next"]) .. (key and (" \194\183 " .. string.upper(key)) or ""))
	local more = cast.reqs and #cast.reqs > 1 and (" " .. UI.Hex(C.note[1], C.note[2], C.note[3]) .. "+" .. (#cast.reqs - 1) .. "|r") or ""
	spot.l2:SetText((req and ShortName(req) or "?") .. more)
	spot.l2:SetTextColor(WCSW:ClassColor(req and req.class))
	spot.l3:SetText(SpellText(spell, req and req.rank))
	if not inCombat then SetDot(spot.dot, W.InRange(cast.castID, spell, cast.unit)) end
	local dim = false
	if inCombat then
		if armed then
			-- the armed request: pink outline and "<key> READY"; after its press "CAST", greyed
			spot.armedBg:Show()
			spot.armedLine:Show()
			spot.tag:Show()
			local t = spot.tag.text
			if spent then
				t:SetText(L["CAST"])
				spot.tag.bg:SetColor(C.dis[1], C.dis[2], C.dis[3], 1)
				dim = true
			else
				t:SetText(key and string.format(L["%s READY"], string.upper(key)) or L["READY"])
				local r, g, b = WCSW:LookColor("accent")
				spot.tag.bg:SetColor(r, g, b, 1)
			end
			setColor(t, C.badgeText)
			spot.tag:SetSize((t:GetStringWidth() or 30) + 8, 13)
		else
			dim = true   -- nothing was armed when the fight began: it waits like the rest
		end
	end
	spot.icon:SetDesaturated(dim)
	spot:SetAlpha(dim and 0.45 or 1)
	local skip = {}
	for _, r in ipairs(cast.reqs or {}) do skip[r] = true end
	return skip
end

-- the rows under the spotlight: { kind, height, draw = fn(y) } in order
local function Entries(v, skip, inCombat, width)
	local list, p = {}, db()
	if p.grouped and v.groups then
		for _, g in ipairs(v.groups) do
			local askers = {}
			for _, req in ipairs(g.askers or {}) do
				if not skip[req] then askers[#askers + 1] = req end
			end
			if #askers > 0 then list[#list + 1] = { kind = "group", group = g, askers = askers, n = #askers } end
		end
	else
		for _, req in ipairs(v.rest or {}) do
			if not skip[req] then list[#list + 1] = { kind = "req", req = req, n = 1 } end
		end
	end
	return list
end

local function PlaceGroup(i, e, y, width, inCombat)
	local r = GroupRow(i)
	if not r.fonted or W.fontsFor ~= "set" then RowFonts(r) end
	local g, spell = e.group, spellOf(e.group.spell)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -y)
	r:SetSize(width - 2 * PAD_X, GROUP_ROW_H)
	RowLook(r, i == 1, inCombat)
	local ar, ag, ab = WCSW:LookColor("accent")
	r.bar:SetVertexColor(ar, ag, ab, 1)
	r.icon:SetTexture(spell and spell.icon or WCSW.UNKNOWN_ICON)
	r.spell:SetText(spell and spell.name or "?")
	setColor(r.spell, C.spell)
	r.count:SetText(tostring(e.n))
	setColor(r.count, C.note)
	r.spell:SetWidth(width - 2 * PAD_X - 34 - 24)
	r:Show()
	local h = GROUP_ROW_H
	-- the names in class colours, wrapping
	local names = {}
	for _, req in ipairs(e.askers) do names[#names + 1] = UI.ClassHex(req.class) .. ShortName(req) .. "|r" end
	r.who:ClearAllPoints()
	r.who:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X + 26, -(y + h))
	r.who:SetWidth(width - 2 * PAD_X - 29)
	r.who:SetText(table.concat(names, "  "))
	r.who:SetAlpha(inCombat and 0.45 or 1)
	r.who:Show()
	h = h + (r.who:GetStringHeight() or 13) + 2
	-- the group spell hint (Era, TBC, Forever): the Engine's own line for each group cast (by party, or by
	-- class for Greater Blessings); this text only when it gives none
	local lines = {}
	for _, gc in ipairs(g.groupCasts or (g.groupCast and { g.groupCast }) or {}) do
		if gc.hint then
			lines[#lines + 1] = gc.hint
		elseif gc.askers and #gc.askers >= 2 then
			local gs = spellOf(gc.spell)
			lines[#lines + 1] = string.format(L["All %d in group %d: %s covers them"], #gc.askers, gc.party or 1, gs and gs.name or "?")
		end
	end
	if #lines > 0 then
		r.hint:ClearAllPoints()
		r.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X + 26, -(y + h + 1))
		r.hint:SetWidth(width - 2 * PAD_X - 29)
		r.hint:SetText(table.concat(lines, "\n"))
		setColor(r.hint, C.hint)
		r.hint:SetAlpha(inCombat and 0.45 or 1)
		r.hint:Show()
		h = h + (r.hint:GetStringHeight() or 13) * #lines + 3
	else
		r.hint:Hide()
	end
	return h
end

local function PlaceReq(i, e, y, width, inCombat)
	local r = ReqRow(i)
	if not r.fonted or W.fontsFor ~= "set" then RowFonts(r) end
	local req = e.req
	local spell = spellOf(req.spell)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -y)
	r:SetSize(width - 2 * PAD_X, REQ_ROW_H)
	RowLook(r, false, inCombat)
	local cr, cg, cb = WCSW:ClassColor(req.class)
	r.bar:SetVertexColor(cr, cg, cb, 1)
	r.icon:SetTexture(spell and spell.icon or WCSW.UNKNOWN_ICON)
	r.name:SetText(ShortName(req))
	r.name:SetTextColor(cr, cg, cb, 1)
	r.spell:SetText(SpellText(spell, req.rank))
	setColor(r.spell, C.spell)
	r.time:SetText(inCombat and L["after"] or Waited(req))
	setColor(r.time, C.note)
	local inRange = (not inCombat) and W.InRange(req.castID, spell, req.unit) or nil
	SetDot(r.dot, inRange)
	r.time:ClearAllPoints()
	if inRange ~= nil then
		r.time:SetPoint("RIGHT", r.dot, "LEFT", -5, 0)
	else
		r.time:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	end
	local used = 11 + 14 + 5 + (r.name:GetStringWidth() or 40) + 5 + (r.time:GetStringWidth() or 20) + 9 + (inRange ~= nil and 11 or 0)
	r.spell:SetWidth(math.max(10, width - 2 * PAD_X - used))
	r:Show()
	return REQ_ROW_H
end

function W:Draw()
	if not frame then return end
	local v, p = view(), db()
	local inCombat = UI.InCombat()
	local width = p.width or 260
	local key = WCSW:CastKey()
	local count = v.count or 0
	W.lastCount = count

	-- title: IN COMBAT and the count badge
	frame.fight:SetShown(inCombat)
	if count > 0 then
		UI.SetBadge(frame.badge, count)
		frame.badge:Show()
	else
		frame.badge:Hide()
	end
	frame.glow:SetShown(p.glow and count > 0)

	local skip = self:DrawSpot(v, inCombat, key)
	for _, r in ipairs(pools.group) do r:Hide(); r.who:Hide(); r.hint:Hide() end
	for _, r in ipairs(pools.req) do r:Hide() end
	frame.head:Hide()
	frame.more:Hide()
	frame.lock:Hide()

	local frozen = W.Protected() and UI.Locked()
	local limit = frozen and ((frame:GetHeight() or 0) - 6 - (p.classicButtons and FOOT_H or 0)) or math.huge
	local y = TITLE_H + 1 + SPOT_H + 4
	if inCombat and p.lockRow then
		frame.lock:ClearAllPoints()
		frame.lock:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -(y + 2))
		frame.lock:SetSize(width - 2 * PAD_X, LOCK_H)
		frame.lock:Show()
		y = y + 2 + LOCK_H + 3
	end

	local list = Entries(v, skip, inCombat, width)
	local shown, hidden, gi, ri = 0, 0, 0, 0
	if #list > 0 and y + HEAD_H <= limit then
		frame.head:ClearAllPoints()
		frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X + 3, -(y + 4))
		frame.head:Show()
		y = y + HEAD_H
	end
	local maxRows = p.maxRows or 10
	for i, e in ipairs(list) do
		local fits = shown < maxRows and frame.head:IsShown()
		if fits and frozen then
			local need = (e.kind == "group" and GROUP_ROW_H + 15 or REQ_ROW_H) + ((i < #list) and MORE_H or 0)
			fits = y + need <= limit
		end
		if fits then
			local h
			if e.kind == "group" then
				gi = gi + 1
				h = PlaceGroup(gi, e, y, width, inCombat)
			else
				ri = ri + 1
				h = PlaceReq(ri, e, y, width, inCombat)
			end
			y = y + h + GAP
			shown = shown + 1
		else
			hidden = hidden + e.n
		end
	end
	if hidden > 0 then
		frame.more:ClearAllPoints()
		frame.more:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X + 3, -(y + 2))
		frame.more:SetText(string.format(L["+%d more"], hidden))
		frame.more:Show()
		y = y + MORE_H
	end
	W.fontsFor = "set"
	W.shownRows, W.hiddenCount = shown, hidden
	y = y + 6

	-- the classic Cast and Clear along the bottom
	if p.classicButtons then
		self:DrawFooter(width, key)
		y = y + FOOT_H
	end
	-- holding the secure Cast, the window is sized for the fight as it begins: room for "+N more" too
	if W.Protected() and UI.combat and not frozen and hidden == 0 then y = y + MORE_H end
	if not frozen then
		frame:SetHeight(y)
	end
	self:UpdateShown()
end

function W:DrawFooter(width, key)
	if not self.castBtn then return end
	local clear, cast = self.clearBtn, self.castBtn
	clear.text:SetText(L["Clear"])
	cast.text:SetText(L["Cast"] .. (key and ("  |cccffffff" .. key .. "|r") or ""))
	local cw = (clear.text:GetStringWidth() or 30) + 18
	clear:ClearAllPoints()
	clear:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD_X, 6)
	clear:SetWidth(cw)
	clear:Show()
	UI.AfterCombat("win:footer", function()
		cast:ClearAllPoints()
		cast:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD_X, 6)
		cast:SetWidth(width - 2 * PAD_X - 4 - cw)
		cast:Show()
	end)
end

-- the classic buttons setting: the secure Cast joins the window, or leaves it (out of combat only)
function W:ApplyClassic()
	local p = db()
	if p.classicButtons then self:BuildFooter() end
	if not self.castBtn then return end
	local look = WCSW:Look()
	SkinButton(self.castBtn, look.castButton)
	SkinButton(self.clearBtn, look.clearButton)
	UI.AfterCombat("win:classic", function()
		if db().classicButtons then
			self.castBtn:SetParent(frame)
			self.clearBtn:Show()
		else
			self.castBtn:Hide()
			self.castBtn:SetParent(UIParent)
			self.clearBtn:Hide()
		end
	end)
end

---------------------------------------------------------------- showing
function W:UpdateShown()
	if not frame then return end
	local p, v = db(), view()
	local inCombat = UI.InCombat()
	local holds = W.Protected()   -- holds the secure Cast: never left invisible and clickable
	local floor = math.max(0.25, p.combatAlpha or 0.4)
	local want = p.shown and not p.folded
	if want and (v.count or 0) == 0 and not p.showWhenEmpty and not UI.IsUnlocked() then want = false end
	local alpha = 1
	if inCombat and p.combat == "fade" then
		alpha = holds and floor or (p.combatAlpha or 0.4)
	elseif inCombat and p.combat == "hide" and not UI.IsUnlocked() then
		-- with the classic Cast on it, "hide" fades instead (at the opacity setting, 0.25 at least)
		if holds then alpha = floor else want = false end
	end
	if holds and UI.Locked() then
		-- it can't show or hide in combat: shown stays shown, faded at least; set right after the fight
		if frame:IsShown() then frame:SetAlpha(want and alpha or floor) end
		UI.AfterCombat("win:shown", function() W:UpdateShown() end)
	else
		frame:SetShown(want)
		frame:SetAlpha(alpha)
	end
end

function WCSW:ShowWindow()
	local p = self.db.profile.window
	p.shown, p.folded = true, false
	W:Draw()
	if WCSW.Folded then WCSW.Folded:Draw() end
end

function WCSW:HideWindow()
	self.db.profile.window.shown = false
	W:UpdateShown()
	if WCSW.Folded then WCSW.Folded:Draw() end
end

function WCSW:ToggleWindow()
	local p = self.db.profile.window
	if p.shown and not p.folded and frame and frame:IsShown() then
		self:HideWindow()
	else
		self:ShowWindow()
	end
end

-- fold to the round icon (Folded.lua), or open again
function WCSW:SetFolded(folded)
	local p = self.db.profile.window
	p.folded = folded and true or false
	if not folded then p.shown = true end
	W:Draw()
	if WCSW.Folded then WCSW.Folded:Draw() end
end

---------------------------------------------------------------- lifecycle
function W:Init()
	local U = WCSW.UI
	WCSW:AddSlash("toggle", function() WCSW:ToggleWindow() end, L["show or hide the window"])
	WCSW:AddSlash("show", function() WCSW:ShowWindow() end, L["show the window"])
	WCSW:AddSlash("hide", function() WCSW:HideWindow() end, L["hide the window"])
	WCSW:AddSlash("fold", function() WCSW:SetFolded(not WCSW.db.profile.window.folded) end, L["fold the window to its icon, or open it"])
	WCSW:AddSlash("lock", function() WCSW:SetFramesUnlocked(false); WCSW:Print(L["Frames locked."]) end, L["lock the frames"])
	WCSW:AddSlash("unlock", function() WCSW:SetFramesUnlocked(true); WCSW:Print(L["Frames unlocked: drag them where you like."]) end, L["unlock the frames to move them"])
	WCSW:AddSlash("reset", function() U.ResetPositions(); WCSW:Print(L["Frames back in their places."]) end, L["put every frame back in its place"])
end

function W:Enable()
	Build()
	mover = UI.AddMover({
		key = "window", frame = frame, label = WCSW.TITLE, point = "TOPLEFT",
		db = function() return db() end,
		default = { "TOPLEFT", "CENTER", -450, 200 },
		canDrag = function() return not (W.Protected() and UI.Locked()) end,
	})
	UI.MakeDraggable(mover, frame.bar)
	UI.ApplyPosition(mover)
	self:ApplyClassic()
	self:ApplyLook()

	local function redraw() W:Draw() end
	WCSW.RegisterCallback(W, "QueueChanged", redraw)
	WCSW.RegisterCallback(W, "ArmedChanged", redraw)
	WCSW.RegisterCallback(W, "CombatChanged", redraw)
	WCSW.RegisterCallback(W, "LookChanged", function() W:ApplyClassic(); W:ApplyLook(); W:Draw() end)
	WCSW.RegisterCallback(W, "LockChanged", redraw)
	UI.combatHooks[#UI.combatHooks + 1] = function() W:Draw() end
	UI.redraws[#UI.redraws + 1] = redraw
	-- the waited times and range dots
	self.ticker = C_Timer.NewTicker(1, function()
		if frame:IsShown() and (W.lastCount or 0) > 0 then W:Draw() end
	end)
	self:Draw()
end

function W:Refresh()
	if not frame then return end
	UI.ApplyPosition(mover)
	self:ApplyClassic()
	self:ApplyLook()
	self:Draw()
end
