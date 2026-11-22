--[[
	WhisperCast: Second Wind - the three looks (docs/DESIGN_HANDOFF.md "Looks") and the UI lane's shared
	drawing helpers (WCSW.UI): rounded boxes and edges drawn with the addon's own textures (Media/, made by
	tools/make-media.py), the soft glow, the count badge, fonts, Masque groups, saved positions, the
	frame lock and the out-of-combat queue for protected changes.

	For the Options lane:
	  WCSW.LOOKS            { { key = "suite", name = ... }, ... } in order; also WCSW.LOOKS.suite etc.
	  WCSW:Look()           the chosen look's table
	  WCSW:LookColor(key)   r, g, b, a for "bg", "edge", "title", "accent" (db.profile.window.colors first),
	                        and the look's fixed parts ("bg2", "divider", "plate", "inner", "rowHi", "rowBg")
	  WCSW:ResetLookColors() "Reset to the look's colours"
	  WCSW:FontPx(px)       a drawing's px at the font size setting (10 to 16; 12 is the board's size)
]]

local WCSW = WhisperCastSW
local L = WCSW.L
local UI = {}
WCSW.UI = UI

WCSW.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
UI.MEDIA = "Interface\\AddOns\\" .. (WCSW.ADDON_NAME or "WhisperCast") .. "\\Media\\"
-- The owner's Second Wind picture, cut three ways (his picks, 21 Nov; tools/icon-board):
WCSW.LOGO = WCSW.LOGO or (UI.MEDIA .. "logo")         -- the sigil: empty Cast button, folded icon, note, empty window
WCSW.ICON = WCSW.ICON or (UI.MEDIA .. "icon")         -- the whisper: the AddOns list (TOC) and the launcher
WCSW.MINIMAP_ICON = UI.MEDIA .. "minimap"             -- the whisperer, round with the gold ring baked in
UI.WHITE = "Interface\\Buttons\\WHITE8X8"

local function hex(h, a)
	return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
local function rgba(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end

-- Fixed colours of the drawings (the board's --g-* values), the same in every look
UI.C = {
	note = hex("8fa2b4"),        -- small grey text: NEXT, THEN, waited time
	spell = hex("d9d9d9"),       -- spell names
	rank = hex("888888"),        -- R6
	ready = hex("4dff4d"),       -- range dot, in range
	far = hex("ff4d4d"),         -- range dot, out of range
	hint = hex("ffcc00"),        -- the group spell hint
	fight = hex("ff6666"),       -- IN COMBAT
	lockText = hex("ffb3b3"),    -- the lock row
	lockBg = rgba(255, 77, 77, 0.12),
	lockEdge = rgba(255, 77, 77, 0.45),
	badgeText = hex("2a0a2a"),   -- dark text on the pink badge and tag
	closeBg = rgba(255, 255, 255, 0.08),
	closeInk = hex("bbbbbb"),
	gold = hex("ffd100"),
	btnRed1 = hex("9c1a12"), btnRed2 = hex("4f0805"), btnEdge = hex("b8902f"), btnHi = rgba(255, 255, 255, 0.18),
	btnGrey1 = hex("3a3a44"), btnGrey2 = hex("1e1e24"), btnGreyEdge = hex("666666"),
	flatGreyEdge = hex("555555"), flatGreyText = hex("aaaaaa"),
	white = { 1, 1, 1, 1 },
	black = { 0, 0, 0, 1 },
	abEdge = hex("5d5d5d"),      -- the Cast button's grey frame line
	toastBg = rgba(10, 10, 18, 0.94),
	dis = hex("808080"),
}

---------------------------------------------------------------- the looks
-- Exactly the board's Overall look item. Colours the settings can change are bg, edge, title and accent;
-- nil title means the accent colour (Suite dark's pink title).
local LOOKS = {
	{
		key = "suite", name = L["Suite dark"],
		bg = rgba(13, 13, 20, 0.9), edge = rgba(140, 89, 140, 0.85), edgeSize = 1, radius = 4,
		divider = rgba(110, 77, 128, 0.6), title = nil, titleAlign = "LEFT",
		rowBars = true, rowHi = rgba(255, 255, 255, 0.07),
		castButton = "red", clearButton = "grey",
	},
	{
		key = "blizzard", name = L["Blizzard classic"],
		bg = hex("2a1d12"), bg2 = hex("120b06"), edge = hex("b8902f"), edgeSize = 2, inner = hex("4f3a14"), radius = 6,
		plate = hex("3b2412"), divider = hex("b8902f"), title = hex("ffd100"), titleAlign = "CENTER",
		rowBars = true, rowHi = rgba(255, 209, 0, 0.08),
		castButton = "red", clearButton = "red",
	},
	{
		key = "flat", name = L["Flat modern"],
		bg = rgba(6, 6, 8, 0.84), edge = rgba(255, 255, 255, 0), edgeSize = 1, radius = 0, topLine = 2,
		divider = nil, title = hex("ffffff"), titleAlign = "LEFT",
		rowBars = false, rowBg = rgba(255, 255, 255, 0.04), rowHi = rgba(255, 128, 255, 0.12),
		castButton = "outline", clearButton = "outlineGrey",
	},
}
for _, look in ipairs(LOOKS) do LOOKS[look.key] = look end
WCSW.LOOKS = LOOKS

function WCSW:Look()
	local p = self.db and self.db.profile.window
	return LOOKS[p and p.look or "suite"] or LOOKS.suite
end

local ADJUSTABLE = { bg = true, edge = true, title = true, accent = true }

-- r, g, b, a; a set colour may be { r, g, b, a } or { r = , g = , b = , a = }
function WCSW:LookColor(key)
	local p = self.db and self.db.profile.window
	local c = ADJUSTABLE[key] and p and p.colors and p.colors[key]
	if type(c) == "table" then
		local r, g, b, a = c[1] or c.r, c[2] or c.g, c[3] or c.b, c[4] or c.a
		if r and g and b then return r, g, b, a or 1 end
	end
	if key == "accent" then
		local a = self.ACCENT or { 1, 0.5, 1 }
		return a[1], a[2], a[3], 1
	end
	local look = self:Look()
	if key == "title" and not look.title then return self:LookColor("accent") end
	if key == "bg2" and not look.bg2 then return self:LookColor("bg") end
	local v = look[key]
	if v then return v[1], v[2], v[3], v[4] or 1 end
	return 1, 1, 1, 1
end

-- Blizzard classic's gradient bottom: the bottom colour of the look, or a set background darkened the same way
function UI.BgColors()
	local r, g, b, a = WCSW:LookColor("bg")
	local look = WCSW:Look()
	if not look.bg2 then return r, g, b, a, r, g, b, a end
	local p = WCSW.db and WCSW.db.profile.window
	if p and p.colors and p.colors.bg then
		local k = look.bg2[1] / look.bg[1]
		return r, g, b, a, r * k, g * k, b * k, a
	end
	local r2, g2, b2, a2 = WCSW:LookColor("bg2")
	return r, g, b, a, r2, g2, b2, a2
end

function WCSW:ResetLookColors()
	local p = self.db and self.db.profile.window
	if p then wipe(p.colors) end
	self:Fire("LookChanged")
end

function WCSW:FontPx(px)
	local p = self.db and self.db.profile.window
	local size = p and p.fontSize or 12
	if size < 10 then size = 10 elseif size > 16 then size = 16 end
	return px * size / 12
end

-- the game's own font at a drawing's size; fixed = true ignores the font size setting
function UI.Font(fs, px, flags, fixed)
	fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fixed and px or WCSW:FontPx(px), flags or "")
end

function UI.Hex(r, g, b)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function UI.ClassHex(class)
	return UI.Hex(WCSW:ClassColor(class))
end

---------------------------------------------------------------- textures
local function Tex(parent, layer, sub, file)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	t:SetTexture(file or UI.WHITE)
	return t
end
UI.Tex = Tex

-- top colour to bottom colour on a white texture (every client here has the ColorMixin form; the old
-- SetGradientAlpha stays as a fallback)
function UI.Gradient(t, r1, g1, b1, a1, r2, g2, b2, a2)
	t:SetVertexColor(1, 1, 1, 1)
	if r1 == r2 and g1 == g2 and b1 == b2 and a1 == a2 then
		t:SetVertexColor(r1, g1, b1, a1)
		return
	end
	local ok = CreateColor and pcall(t.SetGradient, t, "VERTICAL", CreateColor(r2, g2, b2, a2), CreateColor(r1, g1, b1, a1))
	if not ok and t.SetGradientAlpha then
		t:SetGradientAlpha("VERTICAL", r2, g2, b2, a2, r1, g1, b1, a1)
	end
end

-- texcoords that turn the top-left quadrant into each corner
local CORNER_TC = {
	TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 }, BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local SIGN = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }

---------------------------------------------------------------- rounded box (a fill)
-- Seven pieces anchored to the parent's edges, so it follows every size change by itself.
local Box = {}
Box.__index = Box

function UI.NewBox(parent, layer, sub)
	local b = setmetatable({ parent = parent, c = {} }, Box)
	for _, k in ipairs(CORNERS) do
		b.c[k] = Tex(parent, layer or "BACKGROUND", sub, UI.MEDIA .. "corner-fill")
		b.c[k]:SetTexCoord(unpack(CORNER_TC[k]))
	end
	b.top = Tex(parent, layer or "BACKGROUND", sub)
	b.bottom = Tex(parent, layer or "BACKGROUND", sub)
	b.center = Tex(parent, layer or "BACKGROUND", sub)
	b:SetShape(0, 0)
	return b
end

-- radius in px, inset in px from the parent's edges (negative: outside); squareBottom keeps the bottom
-- corners square (Blizzard classic's title plate)
function Box:SetShape(radius, inset, squareBottom)
	local p, r, i = self.parent, radius or 0, inset or 0
	self.radius, self.inset, self.squareBottom = r, i, squareBottom
	for _, k in ipairs(CORNERS) do
		local t, s = self.c[k], SIGN[k]
		t:ClearAllPoints()
		t:SetPoint(k, p, k, s[1] * i, s[2] * i)
		t:SetSize(r, r)
	end
	local rb = squareBottom and 0 or r
	self.top:ClearAllPoints()
	self.top:SetPoint("TOPLEFT", p, "TOPLEFT", i + r, -i)
	self.top:SetPoint("TOPRIGHT", p, "TOPRIGHT", -i - r, -i)
	self.top:SetHeight(r)
	self.bottom:ClearAllPoints()
	self.bottom:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", i + rb, i)
	self.bottom:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i - rb, i)
	self.bottom:SetHeight(r)
	self.center:ClearAllPoints()
	self.center:SetPoint("TOPLEFT", p, "TOPLEFT", i, -i - r)
	self.center:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i, i + r)
	self:SetShown(self.shown ~= false)
end

-- one colour, or top and bottom colours (a vertical gradient)
function Box:SetColor(r, g, b, a, r2, g2, b2, a2)
	r2, g2, b2, a2 = r2 or r, g2 or g, b2 or b, a2 or a
	self.c.TOPLEFT:SetVertexColor(r, g, b, a)
	self.c.TOPRIGHT:SetVertexColor(r, g, b, a)
	self.top:SetVertexColor(r, g, b, a)
	self.c.BOTTOMLEFT:SetVertexColor(r2, g2, b2, a2)
	self.c.BOTTOMRIGHT:SetVertexColor(r2, g2, b2, a2)
	self.bottom:SetVertexColor(r2, g2, b2, a2)
	UI.Gradient(self.center, r, g, b, a, r2, g2, b2, a2)
end

function Box:SetShown(v)
	self.shown = v and true or false
	local r = self.radius or 0
	for _, k in ipairs(CORNERS) do
		self.c[k]:SetShown(v and r > 0 and not (self.squareBottom and k:find("BOTTOM")))
	end
	self.top:SetShown(v and r > 0)
	self.bottom:SetShown(v and r > 0)
	self.center:SetShown(v)
end
function Box:Show() self:SetShown(true) end
function Box:Hide() self:SetShown(false) end

---------------------------------------------------------------- rounded edge (a line round a box)
local Edge = {}
Edge.__index = Edge
local EDGE_PCTS = { 25, 29, 33, 40 }

function UI.NewEdge(parent, layer, sub)
	local e = setmetatable({ parent = parent, c = {}, bars = {} }, Edge)
	for _, k in ipairs(CORNERS) do
		e.c[k] = Tex(parent, layer or "BORDER", sub, UI.MEDIA .. "corner-edge-25")
		e.c[k]:SetTexCoord(unpack(CORNER_TC[k]))
	end
	for i = 1, 4 do e.bars[i] = Tex(parent, layer or "BORDER", sub) end
	e:SetShape(0, 1, 0)
	return e
end

-- radius, thickness and inset in px (inset negative: outside the parent)
function Edge:SetShape(radius, thick, inset)
	local p, r, t, i = self.parent, radius or 0, thick or 1, inset or 0
	self.radius = r
	if r > 0 then
		local want, best = t / r * 100, 25
		for _, pct in ipairs(EDGE_PCTS) do
			if math.abs(pct - want) < math.abs(best - want) then best = pct end
		end
		for _, k in ipairs(CORNERS) do
			local c, s = self.c[k], SIGN[k]
			c:SetTexture(UI.MEDIA .. "corner-edge-" .. best)
			c:ClearAllPoints()
			c:SetPoint(k, p, k, s[1] * i, s[2] * i)
			c:SetSize(r, r)
		end
	end
	local top, bottom, left, right = self.bars[1], self.bars[2], self.bars[3], self.bars[4]
	local side = math.max(r, t)   -- square corners: the side bars stop short of the top and bottom ones
	for _, bar in ipairs(self.bars) do bar:ClearAllPoints() end
	top:SetPoint("TOPLEFT", p, "TOPLEFT", i + r, -i)
	top:SetPoint("TOPRIGHT", p, "TOPRIGHT", -i - r, -i)
	top:SetHeight(t)
	bottom:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", i + r, i)
	bottom:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i - r, i)
	bottom:SetHeight(t)
	left:SetPoint("TOPLEFT", p, "TOPLEFT", i, -i - side)
	left:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", i, i + side)
	left:SetWidth(t)
	right:SetPoint("TOPRIGHT", p, "TOPRIGHT", -i, -i - side)
	right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i, i + side)
	right:SetWidth(t)
	self:SetShown(self.shown ~= false)
end

function Edge:SetColor(r, g, b, a)
	for _, k in ipairs(CORNERS) do self.c[k]:SetVertexColor(r, g, b, a) end
	for _, bar in ipairs(self.bars) do bar:SetVertexColor(r, g, b, a) end
end

function Edge:SetShown(v)
	self.shown = v and true or false
	for _, k in ipairs(CORNERS) do self.c[k]:SetShown(v and (self.radius or 0) > 0) end
	for _, bar in ipairs(self.bars) do bar:SetShown(v) end
end
function Edge:Show() self:SetShown(true) end
function Edge:Hide() self:SetShown(false) end

---------------------------------------------------------------- the soft glow (square)
-- A 2 px accent edge just outside the parent and a soft falloff beyond it (the board's
-- box-shadow 0 0 0 1px pink, 0 0 14px 3px pink at 0.28). Its own frame, so it shows and hides as one.
UI.GLOW_ALPHA = 0.19   -- the falloff's strength at the edge: 0.28 x the blur's half-way
function UI.NewGlow(parent, reach)
	local g = CreateFrame("Frame", nil, parent)
	g:SetAllPoints(parent)
	g:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
	reach = reach or 18
	g.reach = reach
	g.parts = {}
	local function part(file, tc)
		local t = Tex(g, "BACKGROUND", nil, UI.MEDIA .. file)
		if tc then t:SetTexCoord(unpack(tc)) end
		g.parts[#g.parts + 1] = t
		return t
	end
	-- corners: glow-corner.tga is the top-left one (strong at its bottom-right)
	local tl = part("glow-corner", { 0, 1, 0, 1 })
	tl:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", 0, 0)
	local tr = part("glow-corner", { 1, 0, 0, 1 })
	tr:SetPoint("BOTTOMLEFT", parent, "TOPRIGHT", 0, 0)
	local bl = part("glow-corner", { 0, 1, 1, 0 })
	bl:SetPoint("TOPRIGHT", parent, "BOTTOMLEFT", 0, 0)
	local br = part("glow-corner", { 1, 0, 1, 0 })
	br:SetPoint("TOPLEFT", parent, "BOTTOMRIGHT", 0, 0)
	g.corners = { tl, tr, bl, br }
	-- sides: glow-h is strong at its left (x 0), glow-v at its top (y 0)
	local right = part("glow-h")
	right:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, 0)
	local left = part("glow-h", { 1, 0, 0, 1 })
	left:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", 0, 0)
	local bottom = part("glow-v")
	bottom:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	local top = part("glow-v", { 0, 1, 1, 0 })
	top:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 0)
	top:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 0)
	g.sides = { right = right, left = left, bottom = bottom, top = top }
	g.edge = UI.NewEdge(g, "BORDER")
	UI.SetGlowReach(g, reach)
	g:Hide()
	return g
end

function UI.SetGlowReach(g, reach)
	g.reach = reach
	for _, c in ipairs(g.corners) do c:SetSize(reach, reach) end
	g.sides.right:SetWidth(reach)
	g.sides.left:SetWidth(reach)
	g.sides.bottom:SetHeight(reach)
	g.sides.top:SetHeight(reach)
end

-- radius of the box it glows round; the accent edge edge px thick from inset px (default 2 px from -1: over
-- the box's outer pixel and one beyond it)
function UI.SetGlowShape(g, radius, edge, inset)
	inset = inset or -1
	g.edge:SetShape((radius or 0) > 0 and radius - inset or 0, edge or 2, inset)
end

function UI.SetGlowColor(g, r, g2, b)
	for _, t in ipairs(g.parts) do t:SetVertexColor(r, g2, b, UI.GLOW_ALPHA) end
	g.edge:SetColor(r, g2, b, 1)
end

---------------------------------------------------------------- the round glow
-- A thin accent ring and a soft round falloff (glow-round.tga: clear inside 58 percent of its radius)
function UI.NewRoundGlow(parent)
	local g = CreateFrame("Frame", nil, parent)
	g:SetAllPoints(parent)
	g:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
	g.soft = Tex(g, "BACKGROUND", nil, UI.MEDIA .. "glow-round")
	g.soft:SetPoint("CENTER", parent, "CENTER", 0, 0)
	g.ring = Tex(g, "BORDER", nil, UI.MEDIA .. "ring")
	g.ring:SetPoint("CENTER", parent, "CENTER", 0, 0)
	g:Hide()
	return g
end

function UI.SetRoundGlowSize(g, size)
	g.soft:SetSize(size / 0.58, size / 0.58)
	g.ring:SetSize(size + 4, size + 4)
end

function UI.SetRoundGlowColor(g, r, g2, b)
	g.soft:SetVertexColor(r, g2, b, UI.GLOW_ALPHA * 1.5)
	g.ring:SetVertexColor(r, g2, b, 1)
end

---------------------------------------------------------------- the count badge
-- A pink pill, 16 px high, at least 16 wide, dark bold text (10.5 px)
function UI.NewBadge(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(16, 16)
	b.left = Tex(b, "ARTWORK", nil, UI.MEDIA .. "disc")
	b.left:SetTexCoord(0, 0.5, 0, 1)
	b.left:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.left:SetSize(8, 16)
	b.right = Tex(b, "ARTWORK", nil, UI.MEDIA .. "disc")
	b.right:SetTexCoord(0.5, 1, 0, 1)
	b.right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	b.right:SetSize(8, 16)
	b.mid = Tex(b, "ARTWORK")
	b.mid:SetPoint("TOPLEFT", b, "TOPLEFT", 8, 0)
	b.mid:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	UI.Font(b.text, 10.5, nil, true)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	return b
end

function UI.SetBadge(b, n)
	local r, g, bl = WCSW:LookColor("accent")
	for _, t in ipairs({ b.left, b.right, b.mid }) do t:SetVertexColor(r, g, bl, 1) end
	local c = UI.C.badgeText
	b.text:SetTextColor(c[1], c[2], c[3], 1)
	b.text:SetText(tostring(n))
	local w = math.max(16, (b.text:GetStringWidth() or 8) + 8)
	b:SetWidth(w)
	b.mid:SetShown(w > 16)
end

---------------------------------------------------------------- Masque
-- Groups under "WhisperCast: Second Wind": "Cast button" and "Folded icon". Looked up when a button is
-- skinned, so a Masque that loads late still gets the buttons on the next refresh.
UI.masqueGroups = {}
function UI.Masque()
	return LibStub("Masque", true)
end

function UI.MasqueGroup(sub)
	local MSQ = UI.Masque()
	if not MSQ then return nil end
	local g = UI.masqueGroups[sub]
	if not g then
		g = MSQ:Group(WCSW.TITLE, sub)
		UI.masqueGroups[sub] = g
		if g and g.RegisterCallback then
			g:RegisterCallback(function() WCSW:Fire("LookChanged") end)
		end
	end
	return g
end

-- true when the button is in a Masque group now
function UI.MasqueSkin(button, sub, regions)
	local g = UI.MasqueGroup(sub)
	if not g then return false end
	if button.wcswMasque ~= g then
		g:AddButton(button, regions)
		button.wcswMasque = g
	end
	return true
end

-- the skin Masque put on a button is round (Cirque and the like): Masque keeps it in _MSQ_CFG.Shape
function UI.IsRound(button)
	local cfg = rawget(button, "_MSQ_CFG")
	return type(cfg) == "table" and cfg.Shape == "Circle"
end

---------------------------------------------------------------- combat
-- Protected changes (the secure buttons and anything holding one) wait for the fight to end.
UI.combat = false   -- PLAYER_REGEN_DISABLED .. ENABLED (set before the lockdown starts)
local pending, pendingOrder = {}, {}
function UI.Locked()
	return InCombatLockdown and InCombatLockdown() and true or false
end
function UI.InCombat()
	return UI.combat or UI.Locked()
end

-- run fn now, or once after combat (keyed, so the latest call per key wins)
function UI.AfterCombat(key, fn)
	if not UI.Locked() then
		fn()
		return true
	end
	if not pending[key] then pendingOrder[#pendingOrder + 1] = key end
	pending[key] = fn
	return false
end

local events = CreateFrame("Frame")
UI.events = events
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_BINDINGS")
UI.combatHooks = {}   -- fn(inCombat) per file, run in the event, before the lockdown starts
UI.redraws = {}       -- fn() per file: draw again (a binding changed, the armed cast was spent)
function UI.RedrawAll()
	for _, fn in ipairs(UI.redraws) do fn() end
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		UI.combat = true
		for _, fn in ipairs(UI.combatHooks) do fn(true) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		UI.combat = false
		local order = pendingOrder
		pendingOrder = {}
		for _, key in ipairs(order) do
			local fn = pending[key]
			pending[key] = nil
			if fn then fn() end
		end
		for _, fn in ipairs(UI.combatHooks) do fn(false) end
	elseif event == "UPDATE_BINDINGS" then
		UI.RedrawAll()
	end
end)

-- the settings window (Options.lua), on a tab when given one
function UI.OpenSettings(tab)
	if WCSW.OpenSettings then
		WCSW:OpenSettings(tab)
	elseif WCSW.slash["settings"] then
		WCSW.slash["settings"]("")
	end
end

---------------------------------------------------------------- positions and the lock
-- Each movable frame registers itself: { key, frame, db = fn -> its settings table, point = "TOPLEFT" (the
-- corner it is kept by, so the window grows down), default = { point, relativePoint, x, y }, label,
-- protected = true (the secure button), apply = fn (put it where its settings say) }
UI.movers = {}
UI.editing = false   -- Blizzard's Edit Mode is open (EditMode.lua)

function UI.AddMover(m)
	UI.movers[#UI.movers + 1] = m
	UI.movers[m.key] = m
	return m
end

function UI.IsUnlocked()
	return (WCSW.db and WCSW.db.profile.unlocked) or UI.editing
end

-- put a frame where its settings say: the saved point, or its default
function UI.ApplyPosition(m)
	if not (m and m.frame) then return end   -- a frame whose setup never finished
	local f, s = m.frame, m.db()
	local pt = s.point
	if m.anchor and not pt then
		return UI.AfterCombat("pos:" .. m.key, function() m.anchor(f) end)
	end
	local d = m.default
	return UI.AfterCombat("pos:" .. m.key, function()
		f:ClearAllPoints()
		if type(pt) == "table" and pt[1] then
			f:SetPoint(pt[1], UIParent, pt[2] or pt[1], pt[3] or 0, pt[4] or 0)
		else
			f:SetPoint(d[1], UIParent, d[2], d[3], d[4])
		end
	end)
end

-- where the frame is now, kept by its corner (m.point), as { point, "BOTTOMLEFT", x, y } in its own scale
function UI.CurrentPoint(m)
	local f, corner = m.frame, m.point or "CENTER"
	local l, t, r, b = f:GetLeft(), f:GetTop(), f:GetRight(), f:GetBottom()
	if not (l and t and r and b) then return nil end
	local x = corner:find("LEFT") and l or corner:find("RIGHT") and r or (l + r) / 2
	local y = corner:find("TOP") and t or corner:find("BOTTOM") and b or (t + b) / 2
	return { corner, "BOTTOMLEFT", x, y }
end

UI.onSaved = nil   -- EditMode.lua: also keep it for the current Edit Mode layout
function UI.SavePosition(m, layoutName)
	local pt = UI.CurrentPoint(m)
	if not pt then return end
	local s = m.db()
	s.point = pt
	if UI.onSaved then UI.onSaved(m, s, pt, layoutName) end
	UI.ApplyPosition(m)   -- re-anchored by its corner
end

-- dragging with the lock off (every client; Era has no Edit Mode)
function UI.MakeDraggable(m, handle)
	handle = handle or m.frame
	local f = m.frame
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if not UI.IsUnlocked() or (m.protected and UI.Locked()) then return end
		if m.canDrag and not m.canDrag() then return end
		m.dragging = true
		f:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		if not m.dragging then return end
		m.dragging = false
		f:StopMovingOrSizing()
		UI.SavePosition(m)
	end)
end

function WCSW:SetFramesUnlocked(unlocked)
	self.db.profile.unlocked = unlocked and true or false
	self:Fire("LockChanged", self.db.profile.unlocked)
end

-- /wc reset: every frame back to its default place
function UI.ResetPositions()
	for _, m in ipairs(UI.movers) do
		local s = m.db()
		s.point = nil
		if s.editMode then wipe(s.editMode) end
		UI.ApplyPosition(m)
	end
end
