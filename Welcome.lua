--[[
	WhisperCast: Second Wind - the welcome window (Welcome · The story · What's new), its moving demo, the
	three-step tour on the real frames and the setup checklist. docs/DESIGN_HANDOFF.md, "The welcome window,
	the demo and the tour", is the drawing; the owner's picks are in docs/SCOPE.md.

	When it shows: a first install opens it on Welcome and closing it starts the tour; after an update it opens
	once on What's new. /wc welcome and /wc tour any time.
]]

local _, ns = ...
local WCSW = ns.WCSW
local L = WCSW.L
local UI = WCSW.UI
local C = UI.C

local WL = WCSW:AddModule("Welcome", {})
WCSW.Welcome = WL

local W_W, W_H = 440, 430
local PAD = 16
local CAST_CMD = "CLICK WhisperCastSWCastButton:LeftButton"
local SAMPLE_ICON = "Interface\\Icons\\Spell_Nature_Regeneration"   -- Mark of the Wild, on every client
local SAMPLE_CLASS = "WARRIOR"

local function G() return WCSW.db.global end
local function Setup()
	local g = G()
	if type(g.setup) ~= "table" then g.setup = {} end
	return g.setup
end
local function setColor(t, c, a) t:SetTextColor(c[1], c[2], c[3], a or c[4] or 1) end

local function Text(parent, px, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	UI.Font(fs, px, nil, true)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

local function GameButton(parent, name, width, text, onClick)
	local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

-- the key the Cast button is bound to, or the sample's "F"
local function KeyText() return WCSW:CastKey() or "F" end

---------------------------------------------------------------- the look (as the queue window)
-- fill, edge and Flat modern's accent line on a frame built by Dress()
local function Dress(f)
	f.fill = UI.NewBox(f, "BACKGROUND")
	f.edgeLine = UI.NewEdge(f, "BORDER")
	f.inner = UI.NewEdge(f, "BORDER", 1)
	f.topLine = UI.Tex(f, "BORDER", 2)
	f.topLine:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.topLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
end

local function ApplyDress(f)
	local look = WCSW:Look()
	local r1, g1, b1, a1, r2, g2, b2, a2 = UI.BgColors()
	-- a dialog reads on top of the game: never fainter than 0.94
	f.fill:SetShape(look.radius, 0)
	f.fill:SetColor(r1, g1, b1, math.max(a1, 0.94), r2, g2, b2, math.max(a2, 0.94))
	local er, eg, eb, ea = WCSW:LookColor("edge")
	f.edgeLine:SetShape(look.radius, look.edgeSize, 0)
	f.edgeLine:SetColor(er, eg, eb, ea)
	f.edgeLine:SetShown(ea > 0)
	if look.inner then
		f.inner:SetShape(math.max(0, look.radius - look.edgeSize), 1, look.edgeSize)
		f.inner:SetColor(look.inner[1], look.inner[2], look.inner[3], 1)
		f.inner:Show()
	else
		f.inner:Hide()
	end
	local ar, ag, ab = WCSW:LookColor("accent")
	if look.topLine then
		f.topLine:SetHeight(look.topLine)
		f.topLine:SetVertexColor(ar, ag, ab, 1)
		f.topLine:Show()
	else
		f.topLine:Hide()
	end
end

---------------------------------------------------------------- the demo's timeline (one 8 s loop)
-- Pure, so the harness can read it: what each piece of the demo shows at t seconds into the loop.
WL.LOOP = 8
local function ramp(t, from, to)
	if t <= from then return 0 elseif t >= to then return 1 end
	return (t - from) / (to - from)
end
function WL.DemoAt(t)
	t = t % WL.LOOP
	local s = {}
	s.whisper = ramp(t, 0.8, 1.1) * (1 - ramp(t, 7.4, 7.8))
	s.reply = ramp(t, 5.0, 5.3) * (1 - ramp(t, 7.4, 7.8))
	s.queued = t >= 2.0 and t < 5.6
	s.note = ramp(t, 2.0, 2.3) * (1 - ramp(t, 4.8, 5.3))
	s.pressed = t >= 4.6 and t < 4.8
	if t >= 0.8 and t < 2.0 then s.step = 1
	elseif t >= 2.0 and t < 4.6 then s.step = 2
	elseif t >= 4.6 and t < 7.4 then s.step = 3
	else s.step = 0 end
	return s
end

---------------------------------------------------------------- the demo panel
local function BuildDemo(parent)
	local d = CreateFrame("Frame", "WhisperCastSWWelcomeDemo", parent)
	d:SetSize(W_W - PAD * 2, 150)
	d.bg = UI.Tex(d, "BACKGROUND")
	d.bg:SetAllPoints(d)
	d.bg:SetVertexColor(0, 0, 0, 0.35)

	-- chat, top left
	d.trade = Text(d, 11)
	d.trade:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -10)
	d.trade:SetText(L["[2. Trade] LFW in UC"])
	d.trade:SetTextColor(1, 0.75, 0.75, 1)
	d.whisper = Text(d, 11)
	d.whisper:SetPoint("TOPLEFT", d.trade, "BOTTOMLEFT", 0, -3)
	d.whisper:SetText(L["[Thornwick] whispers: motw"])
	d.whisper:SetTextColor(1, 0.5, 1, 1)
	d.reply = Text(d, 11)
	d.reply:SetPoint("TOPLEFT", d.whisper, "BOTTOMLEFT", 0, -3)
	d.reply:SetText(L["To [Thornwick]: [WC] Mark of the Wild coming now."])
	d.reply:SetTextColor(1, 0.5, 1, 1)

	-- a small queue window, bottom left
	local q = CreateFrame("Frame", nil, d)
	q:SetSize(176, 76)
	q:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 10)
	Dress(q)
	q.glow = UI.NewGlow(q, 10)
	q.title = Text(q, 10)
	q.title:SetPoint("TOPLEFT", q, "TOPLEFT", 7, -5)
	q.title:SetText("WhisperCast")
	q.badge = UI.NewBadge(q)
	q.badge:SetPoint("TOPRIGHT", q, "TOPRIGHT", -6, -3)
	q.divider = UI.Tex(q, "BORDER")
	q.divider:SetHeight(1)
	q.divider:SetPoint("TOPLEFT", q, "TOPLEFT", 1, -20)
	q.divider:SetPoint("TOPRIGHT", q, "TOPRIGHT", -1, -20)
	q.icon = UI.Tex(q, "ARTWORK", nil, SAMPLE_ICON)
	q.icon:SetSize(30, 30)
	q.icon:SetPoint("TOPLEFT", q, "TOPLEFT", 8, -28)
	q.next = Text(q, 9)
	q.next:SetPoint("TOPLEFT", q.icon, "TOPRIGHT", 7, 1)
	setColor(q.next, C.note)
	q.name = Text(q, 12)
	q.name:SetPoint("TOPLEFT", q.next, "BOTTOMLEFT", 0, -2)
	q.name:SetText("Thornwick")
	q.name:SetTextColor(WCSW:ClassColor(SAMPLE_CLASS))
	q.spell = Text(q, 10)
	q.spell:SetPoint("TOPLEFT", q.name, "BOTTOMLEFT", 0, -2)
	q.spell:SetText(L["Mark of the Wild"])
	setColor(q.spell, C.spell)
	q.empty = Text(q, 11)
	q.empty:SetPoint("LEFT", q.icon, "RIGHT", 8, 0)
	q.empty:SetText(L["No requests"])
	setColor(q.empty, C.note)
	d.q = q

	-- the note, right of the window
	local n = CreateFrame("Frame", nil, d)
	n:SetSize(196, 30)
	n:SetPoint("TOPLEFT", q, "TOPLEFT", 190, 0)
	n.bg = UI.Tex(n, "BACKGROUND")
	n.bg:SetAllPoints(n)
	n.bg:SetVertexColor(C.toastBg[1], C.toastBg[2], C.toastBg[3], C.toastBg[4])
	n.bar = UI.Tex(n, "BORDER")
	n.bar:SetPoint("TOPLEFT", n, "TOPLEFT", 0, 0)
	n.bar:SetPoint("BOTTOMLEFT", n, "BOTTOMLEFT", 0, 0)
	n.bar:SetWidth(3)
	n.icon = UI.Tex(n, "ARTWORK", nil, SAMPLE_ICON)
	n.icon:SetSize(20, 20)
	n.icon:SetPoint("LEFT", n, "LEFT", 8, 0)
	n.text = Text(n, 10)
	n.text:SetPoint("LEFT", n.icon, "RIGHT", 6, 0)
	n.text:SetWidth(160)
	n.text:SetJustifyV("MIDDLE")
	n.text:SetText(string.format(L["%s asks for %s"], UI.ClassHex(SAMPLE_CLASS) .. "Thornwick|r", L["Mark of the Wild"]))
	d.note = n

	-- the Cast button, under the note
	local b = CreateFrame("Frame", nil, d)
	b:SetSize(32, 32)
	b:SetPoint("BOTTOMLEFT", q, "BOTTOMRIGHT", 14, 0)
	b.glow = UI.NewGlow(b, 8)
	b.edge = UI.Tex(b, "BACKGROUND")
	b.edge:SetAllPoints(b)
	b.edge:SetVertexColor(C.abEdge[1], C.abEdge[2], C.abEdge[3], 1)
	b.icon = UI.Tex(b, "ARTWORK", nil, SAMPLE_ICON)
	b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.icon:SetSize(30, 30)
	b.flash = UI.Tex(b, "OVERLAY")
	b.flash:SetAllPoints(b.icon)
	b.flash:SetVertexColor(1, 1, 1, 0.35)
	b.key = Text(b, 10)
	b.key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
	b.key:SetJustifyH("RIGHT")
	b.label = Text(d, 10)
	b.label:SetPoint("LEFT", b, "RIGHT", 8, 0)
	d.btn = b

	d.t = 0
	d:SetScript("OnShow", function(self) self.t = 0; WL.DrawDemo(self, 0) end)
	d:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t + (elapsed or 0)) % WL.LOOP
		WL.DrawDemo(self, self.t)
	end)
	return d
end

-- the step labels under the panel: 1 They whisper · 2 It queues · 3 You press <key>
local function BuildSteps(parent, demo)
	local steps = {}
	local w = (W_W - PAD * 2) / 3
	for i = 1, 3 do
		local s = Text(parent, 12)
		s:SetPoint("TOPLEFT", demo, "BOTTOMLEFT", (i - 1) * w, -6)
		s:SetWidth(w)
		s:SetJustifyH("CENTER")
		steps[i] = s
	end
	return steps
end

function WL.DrawDemo(d, t)
	local s = WL.DemoAt(t)
	local ar, ag, ab = WCSW:LookColor("accent")
	local key = KeyText()
	d.whisper:SetAlpha(s.whisper)
	d.reply:SetAlpha(s.reply)

	local q = d.q
	q.title:SetTextColor(WCSW:LookColor("title"))
	q.next:SetText(string.format(L["NEXT · %s"], key))
	q.next:SetShown(s.queued)
	q.name:SetShown(s.queued)
	q.spell:SetShown(s.queued)
	q.empty:SetShown(not s.queued)
	q.icon:SetTexture(s.queued and SAMPLE_ICON or WCSW.LOGO)
	q.icon:SetDesaturated(not s.queued)
	q.icon:SetAlpha(s.queued and 1 or 0.4)
	q.badge:SetShown(s.queued)
	if s.queued then UI.SetBadge(q.badge, 1) end
	q.glow:SetShown(s.queued)

	d.note:SetAlpha(s.note)
	d.note:SetShown(s.note > 0)
	d.note.bar:SetVertexColor(ar, ag, ab, 1)

	local b = d.btn
	b.icon:SetTexture(s.queued and SAMPLE_ICON or WCSW.LOGO)
	b.icon:SetAlpha(s.queued and 1 or 0.4)
	b.icon:SetSize(s.pressed and 26 or 30, s.pressed and 26 or 30)
	b.flash:SetShown(s.pressed)
	b.glow:SetShown(s.queued)
	b.key:SetText(key)
	b.label:SetText(s.queued and (UI.ClassHex(SAMPLE_CLASS) .. "Thornwick|r") or "")

	local labels = { L["They whisper"], L["It queues"], string.format(L["You press %s"], key) }
	for i, fs in ipairs(d.steps or {}) do
		fs:SetText(i .. "  " .. labels[i])
		if s.step == i then fs:SetTextColor(ar, ag, ab, 1) else setColor(fs, C.note) end
	end
	d.state = s
end

local function ApplyDemoLook(d)
	ApplyDress(d.q)
	local look = WCSW:Look()
	local ar, ag, ab = WCSW:LookColor("accent")
	UI.SetGlowShape(d.q.glow, look.radius, 2, -1)
	UI.SetGlowColor(d.q.glow, ar, ag, ab)
	UI.SetGlowColor(d.btn.glow, ar, ag, ab)
	if look.divider then
		d.q.divider:SetVertexColor(look.divider[1], look.divider[2], look.divider[3], look.divider[4] or 1)
		d.q.divider:Show()
	else
		d.q.divider:Hide()
	end
end

---------------------------------------------------------------- the What's new list
-- Newest version first; a later version adds its own block at the top.
local groupBuffs = WCSW.isEra or WCSW.isTBC or WCSW.isForever   -- the clients with group buffs (Data.lua)
function WL.News()
	return {
		{
			version = "1.0.0", title = L["New since 2007"],
			lines = {
				L["Three looks, Suite dark, Blizzard classic and Flat modern, with your own colours"],
				groupBuffs and L["Next up, big, then the rest grouped by spell; one group buff when two in a party ask"]
					or L["Next up, big, then the rest grouped by spell"],
				L["Its own Cast button (Masque skins it) on one key; in a fight the first request stays ready"],
				L["A note and a glow when someone asks; a round icon when folded away"],
				L["Trigger words as chips; party and raid chat too, if you like"],
				L["Out of range never lands on you, and the queue survives a /reload"],
				L["CooldownCollaborator shows the queue on its Asks tab"],
				L["Classic Era, TBC, Mists, Retail and Forever, from one folder"],
			},
		},
	}
end

---------------------------------------------------------------- binding the Cast key
-- Set the key: the next key press (with Shift, Ctrl, Alt) becomes the Cast key; Esc cancels.
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true }
local catcher

function WL.BindKey(key)
	if InCombatLockdown and InCombatLockdown() then
		WCSW:Print(L["Keys can't change in a fight. Try again after it."])
		return false
	end
	local before = GetBindingAction and GetBindingAction(key)
	local old = { GetBindingKey(CAST_CMD) }
	for _, k in ipairs(old) do SetBinding(k) end
	SetBinding(key, CAST_CMD)
	SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
	local shown = WCSW:CastKey() or key
	if before and before ~= "" and before ~= CAST_CMD then
		WCSW:Print(string.format(L["%s now casts the next request (it was: %s)."], shown, _G["BINDING_NAME_" .. before] or before))
	else
		WCSW:Print(string.format(L["%s now casts the next request."], shown))
	end
	WL:RefreshAll()
	return true
end

function WL.KeyFromPress(key)
	if not key or MODIFIER_KEYS[key] then return nil end
	local mods = ""
	if IsAltKeyDown and IsAltKeyDown() then mods = mods .. "ALT-" end
	if IsControlKeyDown and IsControlKeyDown() then mods = mods .. "CTRL-" end
	if IsShiftKeyDown and IsShiftKeyDown() then mods = mods .. "SHIFT-" end
	return mods .. key
end

function WL.CatchKey(button)
	if InCombatLockdown and InCombatLockdown() then
		WCSW:Print(L["Keys can't change in a fight. Try again after it."])
		return
	end
	if not catcher then
		catcher = CreateFrame("Frame", "WhisperCastSWKeyCatcher", UIParent)
		catcher:SetSize(1, 1)
		catcher:SetPoint("CENTER")
		catcher:SetFrameStrata("FULLSCREEN_DIALOG")
		catcher:EnableKeyboard(true)
		if catcher.SetPropagateKeyboardInput then catcher:SetPropagateKeyboardInput(false) end
		catcher:SetScript("OnKeyDown", function(self, key)
			if key == "ESCAPE" then
				self:Hide()
				WL:RefreshAll()
				return
			end
			local full = WL.KeyFromPress(key)
			if not full then return end
			self:Hide()
			WL.BindKey(full)
		end)
		catcher:SetScript("OnHide", function() WL.catching = nil; WL:RefreshAll() end)
		catcher:Hide()
	end
	WL.catching = button
	catcher:Show()
	if button then button:SetText(L["Press a key..."]) end
end

---------------------------------------------------------------- Try it
function WL.TryIt()
	local words = WCSW.FirstWords and WCSW:FirstWords() or {}
	if not words[1] then
		WCSW:Print(L["No spells to offer on this character."])
		return false
	end
	if WCSW.slash.test then WCSW.slash.test(words[1]) end
	return true
end

function WL.Announce()
	if WCSW:Announce() then Setup().told = true end
	WL:RefreshAll()
end

---------------------------------------------------------------- the checklist's ticks
function WL.Ticks()
	local s, p = Setup(), WCSW.db.profile.window
	local placed = s.placed or (p.point ~= nil) or (p.editMode and next(p.editMode) ~= nil) or false
	return { placed and true or false, WCSW:CastKey() ~= nil, s.told and true or false }
end

---------------------------------------------------------------- the welcome window
local win
local TABS = { "welcome", "story", "news" }

local function TabButton(parent, i, label)
	local b = CreateFrame("Button", "WhisperCastSWWelcomeTab" .. i, parent)
	b.text = Text(b, 12)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
	b.text:SetText(label)
	b:SetSize(math.max(60, (b.text:GetStringWidth() or 60) + 16), 22)
	b.line = UI.Tex(b, "ARTWORK")
	b.line:SetHeight(2)
	b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 0)
	b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 0)
	b:SetScript("OnClick", function() WL:Select(TABS[i]) end)
	return b
end

local function BuildChecklist(parent)
	local c = CreateFrame("Frame", "WhisperCastSWWelcomeChecklist", parent)
	c:SetSize(W_W - PAD * 2, 112)
	c.head = Text(c, 12)
	c.head:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.head:SetText(L["Set up in three steps"])
	c.rows = {}
	local labels = { L["Place your queue window"], L["Bind your Cast key"], L["Tell your group"] }
	for i = 1, 3 do
		local r = CreateFrame("Frame", nil, c)
		r:SetSize(W_W - PAD * 2, 22)
		r:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -18 - (i - 1) * 24)
		r.box = UI.Tex(r, "ARTWORK")
		r.box:SetSize(14, 14)
		r.box:SetPoint("LEFT", r, "LEFT", 2, 0)
		r.tick = UI.Tex(r, "OVERLAY", nil, "Interface\\Buttons\\UI-CheckBox-Check")
		r.tick:SetSize(20, 20)
		r.tick:SetPoint("CENTER", r.box, "CENTER", 1, 1)
		r.text = Text(r, 12)
		r.text:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
		r.text:SetJustifyV("MIDDLE")
		r.label = labels[i]
		c.rows[i] = r
	end
	c.rows[1].button = GameButton(c.rows[1], "WhisperCastSWWelcomeUnlock", 100, L["Unlock"], function()
		local unlocked = WCSW.db.profile.unlocked
		WCSW:SetFramesUnlocked(not unlocked)
		if unlocked then Setup().placed = true end
		WL:RefreshAll()
	end)
	c.rows[2].button = GameButton(c.rows[2], "WhisperCastSWWelcomeSetKey", 100, L["Set the key"], function(b) WL.CatchKey(b) end)
	c.rows[3].button = GameButton(c.rows[3], "WhisperCastSWWelcomeAnnounce", 100, L["Announce"], function() WL.Announce() end)
	for i = 1, 3 do c.rows[i].button:SetPoint("RIGHT", c.rows[i], "RIGHT", 0, 0) end
	c.try = Text(c, 11)
	c.try:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -94)
	c.try:SetText(L["Or Try it to see a request arrive."])
	setColor(c.try, C.note)
	c.tryButton = GameButton(c, "WhisperCastSWWelcomeTry", 100, L["Try it"], function() WL.TryIt() end)
	c.tryButton:SetPoint("RIGHT", c, "TOPRIGHT", 0, -99)
	return c
end

local function DrawChecklist(c)
	local ticks = WL.Ticks()
	local ar, ag, ab = WCSW:LookColor("accent")
	for i, r in ipairs(c.rows) do
		r.tick:SetShown(ticks[i])
		r.tick:SetVertexColor(ar, ag, ab, 1)
		r.box:SetVertexColor(0, 0, 0, 0.5)
		local text = r.label
		if i == 2 and ticks[2] then text = text .. "  " .. UI.Hex(ar, ag, ab) .. (WCSW:CastKey() or "") .. "|r" end
		r.text:SetText(text)
		if ticks[i] then setColor(r.text, C.note) else setColor(r.text, C.white) end
	end
	c.rows[1].button:SetText(WCSW.db.profile.unlocked and L["Lock"] or L["Unlock"])
	if WL.catching ~= c.rows[2].button then c.rows[2].button:SetText(L["Set the key"]) end
	c.head:SetTextColor(ar, ag, ab, 1)
	local all = ticks[1] and ticks[2] and ticks[3]
	c.head:SetText(all and L["All set."] or L["Set up in three steps"])
end

local function BuildScroll(parent, name, height)
	local sf = CreateFrame("ScrollFrame", name, parent)
	sf:SetSize(W_W - PAD * 2, height)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(W_W - PAD * 2 - 8, height)
	sf:SetScrollChild(child)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
		local v = math.min(max, math.max(0, (self:GetVerticalScroll() or 0) - delta * 24))
		self:SetVerticalScroll(v)
	end)
	sf.child = child
	return sf
end

local function Build()
	win = CreateFrame("Frame", "WhisperCastSWWelcome", UIParent)
	WL.frame = win
	win:SetSize(W_W, W_H)
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	win:SetFrameStrata("DIALOG")
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", function(self) self:StartMoving() end)
	win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	Dress(win)
	table.insert(UISpecialFrames, "WhisperCastSWWelcome")

	win.title = Text(win, 13)
	win.title:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -12)
	win.title:SetText(WCSW.TITLE)
	win.version = Text(win, 11)
	win.version:SetPoint("BOTTOMLEFT", win.title, "BOTTOMRIGHT", 8, 0)
	win.version:SetText(WCSW.version)
	setColor(win.version, C.note)
	win.close = CreateFrame("Button", "WhisperCastSWWelcomeClose", win, "UIPanelCloseButton")
	win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)

	-- tabs
	win.tabs = {}
	local tabLabels = { L["Welcome"], L["The story"], L["What's new"] }
	local x = PAD - 4
	for i = 1, 3 do
		local b = TabButton(win, i, tabLabels[i])
		b:SetPoint("TOPLEFT", win, "TOPLEFT", x, -34)
		x = x + b:GetWidth() + 4
		win.tabs[i] = b
	end
	win.divider = UI.Tex(win, "BORDER")
	win.divider:SetHeight(1)
	win.divider:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -57)
	win.divider:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -57)

	-- pages
	win.pages = {}
	local top = -66
	local welcome = CreateFrame("Frame", nil, win)
	welcome:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, top)
	welcome:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 44)
	win.demo = BuildDemo(welcome)
	win.demo:SetPoint("TOPLEFT", welcome, "TOPLEFT", 0, 0)
	win.demo.steps = BuildSteps(welcome, win.demo)
	win.what = Text(welcome, 12)
	win.what:SetPoint("TOPLEFT", win.demo, "BOTTOMLEFT", 0, -30)
	win.what:SetWidth(W_W - PAD * 2)
	win.what:SetText(L["Your group whispers you a word like \"motw\"; the spell queues on them and one key casts it."])
	setColor(win.what, C.spell)
	win.checklist = BuildChecklist(welcome)
	win.checklist:SetPoint("TOPLEFT", win.what, "BOTTOMLEFT", 0, -12)
	win.pages.welcome = welcome

	local story = CreateFrame("Frame", nil, win)
	story:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, top)
	story:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 44)
	story.head = Text(story, 13)
	story.head:SetPoint("TOPLEFT", story, "TOPLEFT", 0, 0)
	story.head:SetText(L["Where it came from"])
	story.scroll = BuildScroll(story, "WhisperCastSWWelcomeStory", W_H - 66 - 44 - 24)
	story.scroll:SetPoint("TOPLEFT", story.head, "BOTTOMLEFT", 0, -8)
	story.text = Text(story.scroll.child, 12)
	story.text:SetPoint("TOPLEFT", story.scroll.child, "TOPLEFT", 0, 0)
	story.text:SetWidth(W_W - PAD * 2 - 8)
	story.text:SetSpacing(3)
	story.text:SetText(L["WELCOME_STORY"])
	setColor(story.text, C.spell)
	win.pages.story = story

	local news = CreateFrame("Frame", nil, win)
	news:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, top)
	news:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 44)
	news.scroll = BuildScroll(news, "WhisperCastSWWelcomeNews", W_H - 66 - 44)
	news.scroll:SetPoint("TOPLEFT", news, "TOPLEFT", 0, 0)
	news.heads, news.dots, news.lines = {}, {}, {}
	local y = 0
	local child = news.scroll.child
	for _, block in ipairs(WL.News()) do
		local h = Text(child, 13)
		h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		h:SetText(block.title .. "  " .. UI.Hex(C.note[1], C.note[2], C.note[3]) .. block.version .. "|r")
		news.heads[#news.heads + 1] = h
		y = y + 24
		for _, line in ipairs(block.lines) do
			local dot = UI.Tex(child, "ARTWORK")
			dot:SetSize(5, 5)
			dot:SetPoint("TOPLEFT", child, "TOPLEFT", 3, -y - 5)
			local fs = Text(child, 12)
			fs:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -y)
			fs:SetWidth(W_W - PAD * 2 - 28)
			fs:SetText(line)
			setColor(fs, C.spell)
			news.dots[#news.dots + 1] = dot
			news.lines[#news.lines + 1] = fs
			y = y + math.max(16, (fs:GetStringHeight() or 14)) + 6
		end
		y = y + 10
	end
	child:SetHeight(math.max(y, 10))
	win.pages.news = news

	-- bottom buttons
	win.tour = GameButton(win, "WhisperCastSWWelcomeTour", 120, L["Take the tour"], function()
		WL.closingForTour = true
		win:Hide()
		WL.closingForTour = nil
		WL:StartTour(true)
	end)
	win.tour:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 14)
	win.closeButton = GameButton(win, "WhisperCastSWWelcomeCloseButton", 80, L["Close"], function() win:Hide() end)
	win.closeButton:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD, 14)

	win:SetScript("OnShow", function() WL:Draw() end)
	win:SetScript("OnHide", function()
		-- a first install: the tour follows the welcome window
		if G().tourPending and not WL.closingForTour and not WL.touring then WL:StartTour() end
	end)
	win:Hide()
	WL:ApplyLook()
end

function WL:ApplyLook()
	if not win then return end
	ApplyDress(win)
	ApplyDemoLook(win.demo)
	win.title:SetTextColor(WCSW:LookColor("title"))
	local look = WCSW:Look()
	if look.divider then
		win.divider:SetVertexColor(look.divider[1], look.divider[2], look.divider[3], look.divider[4] or 1)
	else
		win.divider:SetVertexColor(1, 1, 1, 0.08)
	end
	local ar, ag, ab = WCSW:LookColor("accent")
	win.pages.story.head:SetTextColor(ar, ag, ab, 1)
	for _, h in ipairs(win.pages.news.heads) do h:SetTextColor(ar, ag, ab, 1) end
	for _, d in ipairs(win.pages.news.dots) do d:SetVertexColor(ar, ag, ab, 1) end
	self:Draw()
end

function WL:Select(tab)
	if not win then return end
	self.tab = tab or self.tab or "welcome"
	local ar, ag, ab = WCSW:LookColor("accent")
	for i, key in ipairs(TABS) do
		local on = (key == self.tab)
		win.pages[key]:SetShown(on)
		local b = win.tabs[i]
		b.line:SetShown(on)
		b.line:SetVertexColor(ar, ag, ab, 1)
		if on then b.text:SetTextColor(ar, ag, ab, 1) else setColor(b.text, C.note) end
	end
	self:Draw()
end

function WL:Draw()
	if not (win and win:IsShown()) then return end
	win.checklist:SetShown(G().tourDone and true or false)
	if G().tourDone then DrawChecklist(win.checklist) end
	WL.DrawDemo(win.demo, win.demo.t or 0)
end

-- tab: "welcome", "story" or "news"
function WL:Open(tab)
	if not win then Build() end
	G().lastSeen = WCSW.version
	win:Show()
	self:Select(tab or "welcome")
	return win
end

function WL:Close()
	if win then win:Hide() end
end

---------------------------------------------------------------- the tour (on the real frames)
local note, mark
local wasUnlocked

local function BuildTour()
	note = CreateFrame("Frame", "WhisperCastSWTour", UIParent)
	note:SetSize(300, 120)
	note:SetFrameStrata("DIALOG")
	note:SetClampedToScreen(true)
	note:EnableMouse(true)
	Dress(note)
	note.head = Text(note, 12)
	note.head:SetPoint("TOPLEFT", note, "TOPLEFT", 12, -11)
	note.body = Text(note, 12)
	note.body:SetPoint("TOPLEFT", note, "TOPLEFT", 12, -30)
	note.body:SetWidth(276)
	setColor(note.body, C.spell)
	note.key = Text(note, 11)
	note.key:SetPoint("TOPLEFT", note.body, "BOTTOMLEFT", 0, -6)
	setColor(note.key, C.note)
	note.dots = {}
	for i = 1, 3 do
		local d = UI.Tex(note, "ARTWORK")
		d:SetSize(7, 7)
		d:SetPoint("BOTTOMLEFT", note, "BOTTOMLEFT", 12 + (i - 1) * 12, 15)
		note.dots[i] = d
	end
	note.skip = CreateFrame("Button", "WhisperCastSWTourSkip", note, "UIPanelCloseButton")
	note.skip:SetPoint("TOPRIGHT", note, "TOPRIGHT", 0, 0)
	note.skip:SetScript("OnClick", function() WL:EndTour(false) end)
	note.next = GameButton(note, "WhisperCastSWTourNext", 70, L["Next"], function() WL:TourStep((WL.step or 0) + 1) end)
	note.next:SetPoint("BOTTOMRIGHT", note, "BOTTOMRIGHT", -10, 8)
	note.setKey = GameButton(note, "WhisperCastSWTourSetKey", 100, L["Set the key"], function(b) WL.CatchKey(b) end)
	note.setKey:SetPoint("RIGHT", note.next, "LEFT", -6, 0)
	note.done = GameButton(note, "WhisperCastSWTourDone", 70, L["Done"], function() WL:EndTour(true) end)
	note.done:SetPoint("BOTTOMRIGHT", note, "BOTTOMRIGHT", -10, 8)
	note.try = GameButton(note, "WhisperCastSWTourTry", 70, L["Try it"], function() WL.TryIt() end)
	note.try:SetPoint("RIGHT", note.done, "LEFT", -6, 0)
	note.announce = GameButton(note, "WhisperCastSWTourAnnounce", 84, L["Announce"], function() WL.Announce() end)
	note.announce:SetPoint("RIGHT", note.try, "LEFT", -6, 0)
	note:Hide()

	mark = CreateFrame("Frame", "WhisperCastSWTourMark", UIParent)
	mark:SetFrameStrata("DIALOG")
	mark.edge = UI.NewEdge(mark, "OVERLAY")
	mark.edge:SetShape(4, 2, 0)
	mark.glow = UI.NewGlow(mark, 14)
	mark:Hide()
end

local function ApplyTourLook()
	ApplyDress(note)
	local ar, ag, ab = WCSW:LookColor("accent")
	note.head:SetTextColor(ar, ag, ab, 1)
	mark.edge:SetColor(ar, ag, ab, 1)
	UI.SetGlowColor(mark.glow, ar, ag, ab)
	mark.glow:Show()
end

-- the frame each step is about
local function CastTarget()
	local b = _G["WhisperCastSWCastButton"]
	if b and b:IsShown() then return b end
	return _G["WhisperCastSWWindow"]
end

function WL.TourSteps()
	return {
		{ key = "window", title = L["Your queue window"], frame = function() return _G["WhisperCastSWWindow"] end,
			text = L["Requests line up here, next one first. Drag it by its title where you like."] },
		{ key = "cast", title = L["Your Cast key"], frame = CastTarget,
			text = L["This button casts the next request. Give it a key you can reach in a fight."] },
		{ key = "chat", title = L["Tell your group"], frame = function() return DEFAULT_CHAT_FRAME end,
			text = L["Your group whispers you a word and the spell queues on them. Tell them the words, or try one on yourself first."] },
	}
end

local function Place(frame, key)
	note:ClearAllPoints()
	mark:ClearAllPoints()
	if not frame then
		note:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		mark:Hide()
		return
	end
	mark:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
	mark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
	mark:Show()
	if key == "chat" then
		note:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 40)
	else
		note:SetPoint("LEFT", frame, "RIGHT", 22, 0)
	end
end

function WL:DrawTourNote()
	if not (note and self.step) then return end
	local key = WCSW:CastKey()
	if self.step == 2 then
		note.key:SetText(key and string.format(L["Your key: %s"], key) or L["No key yet."])
		note.key:Show()
	else
		note.key:Hide()
	end
	if WL.catching ~= note.setKey then note.setKey:SetText(L["Set the key"]) end
	local h = 30 + (note.body:GetStringHeight() or 30) + (note.key:IsShown() and 20 or 0) + 44
	note:SetHeight(math.max(110, h))
end

function WL:TourStep(i)
	local steps = self.steps
	if not steps then return end
	if i > #steps then return self:EndTour(true) end
	-- leaving step 1: the window has its place
	if self.step == 1 and i > 1 then
		Setup().placed = true
		if not wasUnlocked then WCSW:SetFramesUnlocked(false) end
	end
	self.step = i
	local s = steps[i]
	if s.key == "window" then
		WCSW:ShowWindow()
		WCSW:SetFramesUnlocked(true)
	end
	note.head:SetText(string.format(L["%d of %d · %s"], i, #steps, s.title))
	note.body:SetText(s.text)
	for n, d in ipairs(note.dots) do
		if n == i then d:SetVertexColor(WCSW:LookColor("accent")) else d:SetVertexColor(0.45, 0.45, 0.45, 1) end
	end
	local last = (i == #steps)
	note.next:SetShown(not last)
	note.setKey:SetShown(s.key == "cast")
	note.done:SetShown(last)
	note.try:SetShown(last)
	note.announce:SetShown(last)
	ApplyTourLook()
	Place(s.frame(), s.key)
	note:Show()
	self:DrawTourNote()
end

-- force: on demand (/wc tour, Take the tour), not only after a first install
function WL:StartTour(force)
	if self.touring then return false end
	if not (force or G().tourPending) then return false end
	if InCombatLockdown and InCombatLockdown() then
		WCSW:Print(L["The tour starts after this fight."])
		self.tourAfterFight = true
		return false
	end
	if not note then BuildTour() end
	if win and win:IsShown() then
		WL.closingForTour = true
		win:Hide()
		WL.closingForTour = nil
	end
	self.touring = true
	wasUnlocked = WCSW.db.profile.unlocked
	self.steps = WL.TourSteps()
	self:TourStep(1)
	return true
end

-- done: the Done button (opens the welcome window on its checklist); the x ends it quietly
function WL:EndTour(done)
	if note then note:Hide() end
	if mark then mark:Hide() end
	if catcher and catcher:IsShown() then catcher:Hide() end
	if self.step == 1 then Setup().placed = true end
	if self.touring and not wasUnlocked and WCSW.db.profile.unlocked then WCSW:SetFramesUnlocked(false) end
	self.touring, self.step, self.steps = nil, nil, nil
	G().tourPending = nil
	G().tourDone = true
	if done then self:Open("welcome") end
end

---------------------------------------------------------------- refresh
function WL:RefreshAll()
	self:Draw()
	self:DrawTourNote()
end

---------------------------------------------------------------- lifecycle
function WL:Init()
	WCSW:AddSlash("welcome", function() WL:Open("welcome") end, L["open the welcome window (what it is, its story, what's new)"])
	WCSW:AddSlash("tour", function() WL:StartTour(true) end, L["the three-step setup tour"])
end

-- what to open at login: "welcome" (a first install), "news" (an update) or nil
function WL.DueAtLogin()
	if WCSW.freshInstall then return "welcome" end
	if G().lastSeen ~= WCSW.version then return "news" end
	return nil
end

function WL:Enable()
	if WCSW.freshInstall then G().tourPending = true end
	local due = WL.DueAtLogin()
	local function refresh() WL:RefreshAll() end
	WCSW.RegisterCallback(WL, "LookChanged", function()
		WL:ApplyLook()
		if note and note:IsShown() then ApplyTourLook() end
	end)
	WCSW.RegisterCallback(WL, "LockChanged", refresh)
	WCSW.RegisterCallback(WL, "Announced", function() Setup().told = true; refresh() end)
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UPDATE_BINDINGS")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "UPDATE_BINDINGS" then
			refresh()
		elseif event == "PLAYER_REGEN_ENABLED" then
			if WL.openAfterFight then
				local tab = WL.openAfterFight
				WL.openAfterFight = nil
				WL:Open(tab)
			end
			if WL.tourAfterFight then
				WL.tourAfterFight = nil
				WL:StartTour(true)
			end
		end
	end)
	if due then
		C_Timer.After(2, function()
			if InCombatLockdown and InCombatLockdown() then
				WL.openAfterFight = due
			else
				WL:Open(due)
			end
		end)
	end
end

function WL:Refresh()
	self:ApplyLook()
end
