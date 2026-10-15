-- UiKit (client): the ONE shared visual system for every Lighthouse Keepers menu.
--
-- Direction: lighthouse machinery. Storm-navy surfaces, wet-slate panels, weathered brass
-- structure, warm lamp light for primary actions, ivory text, sea-blue information, coral
-- danger, rust warnings. Identity comes from instrument details (corner brackets, a beacon
-- line with gauge ticks, a lens arc on dialogs, compass ticks on gauges), never from ropes,
-- wood, parchment, skulls or glow.
--
-- CONTAINER TREATMENTS (each has its own silhouette; do not box everything):
--   Panel kind "housing"  menus: quiet brass frame, corner brackets, beacon line on top
--   Panel kind "dialog"   decisions: lens arc rising from the top edge, no brackets
--   UiKit.Inset           instrument faces: recessed, borderless (wells, tracks, ledgers)
--   UiKit.Section         groups: a label and a rule, NO box
--   UiKit.SettingRow      lists: rows split by hairline dividers, NO box
--   UiKit.ItemCard        items: slate card, borderless until selected/equipped
--   Gauges                HUD instruments: icon cap + track, one silhouette per resource
--
-- ORIENTATION (owner decision, Oct 10 2026): phone gameplay is locked to LandscapeSensor
-- (StarterGui.ScreenOrientation). Design and verify production screens for landscape phones
-- (667x375 to 932x430), tablet, desktop and widescreen. Keep every layout responsive and
-- safe-area aware anyway: the lock is not a fixed resolution, and narrow reflow must still work.
--
-- TEXT CASE: CAPS only for short headings, categories, buttons, warnings and instrument labels.
-- Descriptions, explanations, errors, confirmations and help are sentence case.
--
-- v1 API (lowercase: THEME, make, button, toast, ...) at the bottom is kept ONLY so the current
-- Shop and Inventory keep working until their stages. Do not use it in new code.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiKit = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

---------------------------------------------------------------------
-- TOKENS
---------------------------------------------------------------------

local Color = {
	SurfaceBase = rgb(9, 14, 24),
	SurfacePrimary = rgb(15, 23, 37), -- storm navy
	SurfaceSecondary = rgb(27, 37, 50), -- wet slate
	SurfaceElevated = rgb(37, 50, 66),
	SurfaceHover = rgb(46, 61, 80),
	SurfaceInset = rgb(10, 16, 27),
	Scrim = rgb(4, 7, 12),
	BorderStructural = rgb(128, 104, 64), -- weathered brass
	BorderBrassBright = rgb(201, 165, 104),
	BorderSubtle = rgb(48, 62, 80),
	BorderSelected = rgb(242, 193, 78),
	BorderFocus = rgb(241, 234, 219), -- controller focus is IVORY, selection is GOLD
	TextPrimary = rgb(241, 234, 219), -- warm ivory
	TextSecondary = rgb(192, 186, 172),
	TextMuted = rgb(156, 158, 160),
	TextOnAccent = rgb(30, 21, 6),
	AccentLighthouse = rgb(242, 193, 78),
	AccentLighthouseDeep = rgb(196, 140, 44),
	AccentLighthouseSoft = rgb(255, 226, 158),
	AccentSea = rgb(127, 167, 196),
	AccentSeaDeep = rgb(58, 92, 120),
	StateDanger = rgb(234, 114, 96), -- coral
	StateWarning = rgb(214, 128, 46), -- rust orange
	StateSuccess = rgb(112, 192, 144),
	StateDisabled = rgb(46, 54, 66),
	StateDisabledText = rgb(132, 138, 148),
	HealthTrail = rgb(255, 204, 186),
	Stone = rgb(206, 198, 180), -- tower masonry
	Pearl = rgb(230, 224, 242),
	Shell = rgb(236, 178, 128),
	CatWeapons = rgb(226, 140, 72),
	CatArmor = rgb(110, 156, 206),
	CatAmmunition = rgb(196, 164, 98),
	CatMaterials = rgb(126, 192, 160),
}
UiKit.Color = Color

UiKit.CATEGORY = {
	Weapons = "CatWeapons",
	Armor = "CatArmor",
	Ammunition = "CatAmmunition",
	Materials = "CatMaterials",
	Loot = "CatMaterials",
}

local function family(name)
	return "rbxasset://fonts/families/" .. name .. ".json"
end

local Fonts = {
	Display = Font.new(family("Merriweather"), Enum.FontWeight.Heavy),
	Heading = Font.new(family("Merriweather"), Enum.FontWeight.Bold),
	Label = Font.new(family("Oswald"), Enum.FontWeight.Medium),
	LabelBold = Font.new(family("Oswald"), Enum.FontWeight.Bold),
	Body = Font.new(family("BuilderSans"), Enum.FontWeight.Regular),
	BodyMedium = Font.new(family("BuilderSans"), Enum.FontWeight.Medium),
	BodyBold = Font.new(family("BuilderSans"), Enum.FontWeight.Bold),
	Numeric = Font.new(family("BuilderSans"), Enum.FontWeight.ExtraBold),
}
UiKit.Font = Fonts

-- Optional art skin (Config.UI_SKIN): warms the colour tokens before anything is built
local UiSkin = require(script.Parent:WaitForChild("UiSkin"))
UiSkin.remap(Color, Fonts)
UiKit.Skin = UiSkin

-- upper = true only for headings/labels. lineHeight for multi-line reading text.
local Type = {
	Display = { font = "Display", size = 56 },
	H1 = { font = "Heading", size = 30 },
	H2 = { font = "Heading", size = 23 },
	H3 = { font = "BodyBold", size = 18 },
	Eyebrow = { font = "Label", size = 16, color = "AccentLighthouse", upper = true },
	Label = { font = "Label", size = 15, color = "TextSecondary", upper = true }, -- instrument labels
	Body = { font = "Body", size = 17, lineHeight = 1.12 },
	BodySmall = { font = "Body", size = 15, color = "TextSecondary", lineHeight = 1.1 },
	Micro = { font = "BodyMedium", size = 13, color = "TextMuted" }, -- smallest readable size
	Caption = { font = "Label", size = 14, color = "TextMuted", upper = true },
	Number = { font = "Numeric", size = 22 },
}
UiKit.Type = Type

UiKit.Space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48 }
UiKit.Radius = { panel = 6, card = 4, control = 4, tag = 2 }
UiKit.Motion = { fast = 0.12, base = 0.18, slow = 0.32 }
UiKit.TOUCH = 44

---------------------------------------------------------------------
-- BASIC HELPERS
---------------------------------------------------------------------

local function new(className, props, parent)
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			inst[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
UiKit.new = new

local function apply(inst, props)
	if props then
		for key, value in props do
			inst[key] = value
		end
	end
	return inst
end

local function tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
UiKit.tween = tween

function UiKit.round(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or UiKit.Radius.card) }, parent)
end

function UiKit.border(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Color.BorderSubtle,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UiKit.pad(parent, top, right, bottom, left)
	right = right or top
	bottom = bottom or top
	left = left or right
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	}, parent)
end

function UiKit.list(parent, direction, gap, props)
	return apply(new("UIListLayout", {
		FillDirection = if direction == "x" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent), props)
end

local function formatNumber(n)
	local s = tostring(math.floor(n or 0))
	local negative = s:sub(1, 1) == "-"
	if negative then
		s = s:sub(2)
	end
	local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if result:sub(1, 1) == "," then
		result = result:sub(2)
	end
	return (if negative then "-" else "") .. result
end
UiKit.formatNumber = formatNumber

-- Width reserved for a number so counters don't jitter as digits change
local function numberWidth(text, size)
	local _, commas = text:gsub(",", "")
	return math.ceil((#text - commas) * size * 0.6 + commas * size * 0.3) + 2
end
UiKit.numberWidth = numberWidth

local function isShown(gui)
	local node = gui
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end
UiKit.isShown = isShown

local SoundFx
local function click()
	if SoundFx == nil then
		local ok, mod = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
		end)
		SoundFx = if ok then mod else false
	end
	if SoundFx then
		pcall(SoundFx.play2D, "click")
	end
end
UiKit.click = click

local function usingGamepad()
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1 or last == Enum.UserInputType.Gamepad2
end
UiKit.usingGamepad = usingGamepad

-- "phone" | "tablet" | "desktop" for a screen or container size (defaults to the camera)
function UiKit.Breakpoint(size)
	size = size or workspace.CurrentCamera.ViewportSize
	if size.X < 760 or size.Y < 500 then -- landscape phones are at most ~430 px tall
		return "phone"
	elseif size.X < 1180 or size.Y < 700 then
		return "tablet"
	end
	return "desktop"
end

-- fullBleed = true covers the whole screen (backdrops, cinematic screens)
function UiKit.Screen(name, displayOrder, fullBleed)
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 10,
		ScreenInsets = if fullBleed then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

-- Reserved corners on touch screens while gameplay controls are visible (thumbstick, jump).
-- HUD elements must stay out of these; menus hide the touch controls instead (see pushModal).
UiKit.TOUCH_RESERVED = {
	bottomLeft = Vector2.new(260, 220),
	bottomRight = Vector2.new(220, 220),
}

---------------------------------------------------------------------
-- FOCUS (controller / keyboard). Ivory double-spaced ring, distinct from gold selection.
---------------------------------------------------------------------

local focusRing = new("Frame", {
	Name = "FocusRing",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 12, 1, 12),
	Position = UDim2.fromOffset(-6, -6),
})
UiKit.round(focusRing, UiKit.Radius.panel + 2)
UiKit.border(focusRing, Color.BorderFocus, 2.5)
UiKit.FocusRing = focusRing

function UiKit.focusable(obj)
	obj.Selectable = true
	obj.SelectionImageObject = focusRing
	return obj
end

---------------------------------------------------------------------
-- MODALS: MenuOpen attribute for gameplay scripts; touch controls hide while a menu is open
---------------------------------------------------------------------

local openModals = {}
local function refreshModal()
	local anyOpen = next(openModals) ~= nil
	Players.LocalPlayer:SetAttribute("MenuOpen", anyOpen)
	pcall(function()
		GuiService.TouchControlsEnabled = not anyOpen
	end)
end
function UiKit.pushModal(name)
	openModals[name] = true
	refreshModal()
end
function UiKit.popModal(name)
	openModals[name] = nil
	refreshModal()
end

---------------------------------------------------------------------
-- TEXT
---------------------------------------------------------------------

function UiKit.Label(parent, text, styleName, props)
	local style = Type[styleName or "Body"] or Type.Body
	local label = new("TextLabel", {
		Name = styleName or "Body",
		BackgroundTransparency = 1,
		FontFace = Fonts[style.font],
		TextSize = style.size,
		TextColor3 = Color[style.color or "TextPrimary"],
		Text = if style.upper then string.upper(text) else text,
		TextWrapped = true,
		RichText = true,
		LineHeight = style.lineHeight or 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	return apply(label, props)
end

---------------------------------------------------------------------
-- GLYPHS (drawn, no image uploads)
-- close, back, next, plus, minus, check, alert, warning, info, diamond, lock, heart, lamp, tower
---------------------------------------------------------------------

function UiKit.Glyph(parent, kind, color, size)
	size = size or 18
	color = color or Color.TextPrimary
	local box = new("Frame", { Name = "Glyph", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) }, parent)
	box:SetAttribute("Kind", kind)
	local thick = math.max(2, math.floor(size / 8 + 0.5))
	local function bar(length, rotation, x, y)
		local b = new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(length, thick),
			Position = UDim2.fromScale(x or 0.5, y or 0.5),
			Rotation = rotation,
		}, box)
		UiKit.round(b, thick)
		return b
	end
	local function block(w, h, x, y, radius, rotation)
		local b = new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(w, h),
			Position = UDim2.fromScale(x, y),
			Rotation = rotation or 0,
		}, box)
		if radius then
			UiKit.round(b, radius)
		end
		return b
	end
	local function dot(x, y, d)
		local b = new("Frame", {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(d, d),
		}, box)
		UiKit.round(b, d)
		return b
	end
	if kind == "close" then
		bar(size * 1.15, 45)
		bar(size * 1.15, -45)
	elseif kind == "plus" then
		bar(size, 0)
		bar(size, 90)
	elseif kind == "minus" then
		bar(size, 0)
	elseif kind == "back" then
		bar(size * 0.62, -45, 0.42, 0.31)
		bar(size * 0.62, 45, 0.42, 0.69)
	elseif kind == "next" then
		bar(size * 0.62, 45, 0.58, 0.31)
		bar(size * 0.62, -45, 0.58, 0.69)
	elseif kind == "check" then
		bar(size * 0.45, 45, 0.3, 0.6)
		bar(size * 0.85, -50, 0.6, 0.46)
	elseif kind == "alert" then
		bar(size * 0.55, 90, 0.5, 0.36)
		dot(0.5, 0.86, thick + 1)
	elseif kind == "info" then
		dot(0.5, 0.16, thick + 1)
		bar(size * 0.55, 90, 0.5, 0.64)
	elseif kind == "warning" then
		local d = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			Rotation = 45,
		}, box)
		UiKit.round(d, 2)
		UiKit.border(d, color, math.max(1.5, thick * 0.75))
		bar(size * 0.3, 90, 0.5, 0.43)
		dot(0.5, 0.68, thick)
	elseif kind == "diamond" then
		block(0.6, 0.6, 0.5, 0.5, nil, 45)
	elseif kind == "lock" then
		local body = block(0.8, 0.55, 0.5, 0.72, 2)
		body.AnchorPoint = Vector2.new(0.5, 0.5)
		local hoop = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.56, 0.7),
		}, box)
		UiKit.round(hoop, size)
		UiKit.border(hoop, color, thick)
	elseif kind == "heart" then
		dot(0.31, 0.37, math.floor(size * 0.52))
		dot(0.69, 0.37, math.floor(size * 0.52))
		block(0.52, 0.52, 0.5, 0.56, 2, 45)
	elseif kind == "lamp" then
		-- a beacon: lens ring with a lit core, beams reaching out to both sides
		local ring = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.46, 0.46),
		}, box)
		UiKit.round(ring, size)
		UiKit.border(ring, color, math.max(1.5, thick * 0.8))
		dot(0.5, 0.5, math.floor(size * 0.2))
		for _, side in { -1, 1 } do
			bar(size * 0.2, 0, 0.5 + side * 0.4, 0.5)
			bar(size * 0.16, side * 30, 0.5 + side * 0.36, 0.24)
			bar(size * 0.16, side * -30, 0.5 + side * 0.36, 0.76)
		end
	elseif kind == "tower" then
		block(0.5, 0.56, 0.5, 0.7)
		block(0.68, 0.08, 0.5, 0.4)
		block(0.32, 0.2, 0.5, 0.26)
		block(0.46, 0.08, 0.5, 0.12)
	end
	return box
end

function UiKit.SetGlyphColor(glyph, color)
	for _, d in glyph:GetDescendants() do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = color
		elseif d:IsA("UIStroke") then
			d.Color = color
		end
	end
end

local function pearlIcon(parent, size)
	local p = new("Frame", { Name = "PearlIcon", BackgroundColor3 = Color.Pearl, Size = UDim2.fromOffset(size, size) }, parent)
	UiKit.round(p, size)
	new("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(160, 150, 196)) }, p)
	UiKit.border(p, rgb(110, 100, 140), 1, 0.4)
	local glint = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(math.max(3, size * 0.26), math.max(3, size * 0.26)),
		Position = UDim2.fromScale(0.22, 0.18),
	}, p)
	UiKit.round(glint, size)
	return p
end

local function shellIcon(parent, size)
	local holder = new("Frame", { Name = "ShellIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) }, parent)
	local clipHeight = math.floor(size * 0.66)
	local clip = new("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(size, clipHeight),
		Position = UDim2.fromOffset(0, math.floor(size * 0.08)),
	}, holder)
	local fan = new("Frame", { BackgroundColor3 = Color.Shell, Size = UDim2.fromOffset(size, size) }, clip)
	UiKit.round(fan, size)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(200, 170, 150)) }, fan)
	local ribLength = clipHeight * 0.85
	for _, angle in { -40, -14, 14, 40 } do
		local r = math.rad(angle)
		new("Frame", {
			BackgroundColor3 = rgb(150, 96, 60),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(math.max(1, size / 14), ribLength),
			Position = UDim2.fromOffset(size / 2 + math.sin(r) * ribLength / 2, clipHeight - math.cos(r) * ribLength / 2),
			Rotation = angle,
		}, clip)
	end
	local hinge = new("Frame", {
		BackgroundColor3 = rgb(196, 130, 86),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(math.floor(size * 0.4), math.max(3, math.floor(size * 0.2))),
		Position = UDim2.new(0.5, 0, 0, math.floor(size * 0.08) + clipHeight - 1),
	}, holder)
	UiKit.round(hinge, 2)
	return holder
end

function UiKit.CurrencyIcon(parent, kind, size)
	if kind == "Pearls" then
		return pearlIcon(parent, size or 18)
	end
	return shellIcon(parent, size or 18)
end

---------------------------------------------------------------------
-- STRUCTURE
---------------------------------------------------------------------

-- Instrument corner brackets (L-shapes). inset < 0 draws them outside the parent.
function UiKit.Brackets(parent, color, arm, thick, inset)
	arm = arm or 12
	thick = thick or 2
	inset = inset or 0
	local holder = new("Frame", {
		Name = "Brackets",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		Position = UDim2.fromOffset(inset, inset),
		ZIndex = 4,
	}, parent)
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local anchor = Vector2.new(c[1], c[2])
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = UDim2.fromScale(c[1], c[2]),
			Size = UDim2.fromOffset(arm, thick),
			ZIndex = 4,
		}, holder)
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = UDim2.fromScale(c[1], c[2]),
			Size = UDim2.fromOffset(thick, arm),
			ZIndex = 4,
		}, holder)
	end
	return holder
end

-- The beacon line: lamp light fading along the top edge, with brass gauge ticks beneath
local function beacon(panel)
	local beam = new("Frame", {
		Name = "Beacon",
		BackgroundColor3 = Color.AccentLighthouse,
		BorderSizePixel = 0,
		Size = UDim2.new(0.5, 0, 0, 2),
		Position = UDim2.fromOffset(22, 0),
		ZIndex = 3,
	}, panel)
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	}, beam)
	for i = 0, 12 do
		new("Frame", {
			Name = "Tick",
			BackgroundColor3 = Color.BorderBrassBright,
			BackgroundTransparency = math.min(0.92, 0.3 + i * 0.05),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(22 + i * 10, 2),
			Size = UDim2.fromOffset(1, if i % 4 == 0 then 6 else 3),
			ZIndex = 3,
		}, panel)
	end
end

-- The lens arc: a shallow brass dome rising from a dialog's top edge, with the lamp at its heart
local function lensArc(panel, color)
	local clip = new("Frame", {
		Name = "LensArc",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 1),
		Size = UDim2.fromOffset(84, 16),
		ZIndex = 3,
	}, panel)
	local disc = new("Frame", { BackgroundColor3 = Color.SurfacePrimary, Size = UDim2.fromOffset(84, 84), ZIndex = 3 }, clip)
	UiKit.round(disc, 42)
	UiKit.border(disc, color or Color.BorderStructural, 1.5)
	local lamp = new("Frame", {
		Name = "Lamp",
		BackgroundColor3 = color or Color.AccentLighthouse,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(7, 7),
		ZIndex = 4,
	}, panel)
	UiKit.round(lamp, 4)
	return clip
end

-- A panel.
--   kind: "housing" (menus, default) | "dialog" (decisions) | "plain" (a quiet sub-area)
--   variant: surface color "primary" | "secondary" | "elevated"
--   beam: beacon line on top (housing only, main menu panel only)
--   eyebrow / title / titleStyle, onClose, compact (phones: one header line)
-- Returns panel, content, header.
function UiKit.Panel(parent, opts)
	opts = table.clone(opts or {})
	if opts.compact then
		opts.eyebrow = nil
		opts.titleStyle = "H3"
		opts.padding = opts.padding or UiKit.Space.md
	end
	local kind = opts.kind or (if opts.brass == false then "plain" else "housing")
	local background = ({
		primary = Color.SurfacePrimary,
		secondary = Color.SurfaceSecondary,
		elevated = Color.SurfaceElevated,
	})[opts.variant or (if kind == "plain" then "secondary" else "primary")]
	local panel = new("Frame", {
		Name = opts.name or "Panel",
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		Size = opts.size or UDim2.fromOffset(480, 320),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	panel:SetAttribute("PanelKind", kind)
	UiKit.round(panel, opts.radius or UiKit.Radius.panel)
	if kind ~= "plain" then
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(196, 202, 212)) }, panel)
	end
	if kind == "housing" then
		UiKit.border(panel, Color.BorderStructural, 1, 0.45)
		UiKit.Brackets(panel, Color.BorderBrassBright, 14, 2, 0)
		if opts.beam then
			beacon(panel)
		end
	elseif kind == "dialog" then
		UiKit.border(panel, opts.frameColor or Color.BorderStructural, 1.5, 0.2)
		lensArc(panel, opts.frameColor)
	end

	local pad = opts.padding or UiKit.Space.xl
	local header
	local headerHeight = opts.headerHeight or 0
	if opts.title or opts.eyebrow then
		header = new("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -pad * 2 - (if opts.onClose then 52 else 0), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(pad, pad - 2),
		}, panel)
		UiKit.list(header, "y", 2)
		if opts.eyebrow then
			UiKit.Label(header, opts.eyebrow, "Eyebrow", { LayoutOrder = 1 })
		end
		if opts.title then
			UiKit.Label(header, opts.title, opts.titleStyle or "H1", { LayoutOrder = 2 })
		end
		if not opts.headerHeight then
			local titleSize = if opts.title then Type[opts.titleStyle or "H1"].size + 8 else 0
			headerHeight = (if opts.eyebrow then 19 else 0) + titleSize + (if opts.compact then UiKit.Space.sm else UiKit.Space.lg)
		end
	end
	if opts.onClose then
		local close = UiKit.IconButton(panel, "close", { name = "Close", quiet = true, onClick = opts.onClose })
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = if opts.compact then UDim2.new(1, -4, 0, 4) else UDim2.new(1, -pad + 10, 0, pad - 12)
		close.ZIndex = 5
	end
	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad, pad + headerHeight),
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2 - headerHeight),
	}, panel)
	return panel, content, header
end

-- A recessed instrument face: no border, a hairline shadow under its top edge
function UiKit.Inset(parent, props)
	local f = new("Frame", { Name = "Inset", BackgroundColor3 = Color.SurfaceInset, BorderSizePixel = 0 }, parent)
	UiKit.round(f, UiKit.Radius.card)
	new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.new(1, -6, 0, 1),
		ZIndex = 2,
	}, f)
	return apply(f, props)
end

-- A group without a box: label, then a brass rule running to a small diamond.
-- Children go straight into the returned frame (LayoutOrder 1+).
function UiKit.Section(parent, title, opts)
	opts = opts or {}
	local s = new("Frame", {
		Name = opts.name or title,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.list(s, "y", opts.gap or 12)
	local head = new("Frame", { Name = "SectionHead", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0 }, s)
	local label = UiKit.Label(head, title, "Eyebrow", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local rule = new("Frame", {
		Name = "Rule",
		BackgroundColor3 = Color.BorderStructural,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
	}, head)
	local tip = new("Frame", {
		BackgroundColor3 = Color.BorderStructural,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(5, 5),
		Rotation = 45,
	}, head)
	local function layout()
		local w = label.AbsoluteSize.X + 12
		rule.Position = UDim2.new(0, w, 0.5, 0)
		rule.Size = UDim2.new(1, -w - 8, 0, 1)
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	_ = tip
	return s
end

function UiKit.Divider(parent, props)
	local d = new("Frame", { Name = "Divider", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12) }, parent)
	for _, side in { 0, 1 } do
		new("Frame", {
			BackgroundColor3 = Color.BorderStructural,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(side, 0.5),
			Position = UDim2.fromScale(side, 0.5),
			Size = UDim2.new(0.5, -9, 0, 1),
		}, d)
	end
	new("Frame", {
		BackgroundColor3 = Color.BorderBrassBright,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		Rotation = 45,
	}, d)
	return apply(d, props)
end

function UiKit.Scroll(parent, props)
	local s = new("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color.BorderStructural,
		ScrollBarImageTransparency = 0.15,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Selectable = false,
	}, parent)
	return apply(s, props)
end

---------------------------------------------------------------------
-- BUTTONS
---------------------------------------------------------------------

local BUTTON_SIZES = { lg = { 56, 22 }, md = { 48, 19 }, sm = { 44, 17 } }
local BUTTON_VARIANTS = {
	primary = { bg = Color.AccentLighthouse, hover = Color.AccentLighthouseSoft, text = Color.TextOnAccent, stroke = Color.AccentLighthouseDeep, glass = true },
	secondary = { bg = Color.SurfaceElevated, hover = Color.SurfaceHover, text = Color.TextPrimary, stroke = Color.BorderStructural },
	ghost = { bg = Color.SurfaceSecondary, hover = Color.SurfaceSecondary, text = Color.TextSecondary, transparent = true },
	danger = { bg = rgb(56, 30, 32), hover = rgb(76, 38, 38), text = Color.StateDanger, stroke = Color.StateDanger },
}

local function attachFeedback(b)
	local scale = new("UIScale", { Name = "PressScale" }, b)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Disabled") and b:GetAttribute("HoverColor") then
			tween(b, UiKit.Motion.fast, { BackgroundColor3 = b:GetAttribute("HoverColor") })
			if b:GetAttribute("GhostButton") then
				b.BackgroundTransparency = 0.4
			end
		end
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("Disabled") and b:GetAttribute("BaseColor") then
			tween(b, UiKit.Motion.fast, { BackgroundColor3 = b:GetAttribute("BaseColor") })
			if b:GetAttribute("GhostButton") then
				b.BackgroundTransparency = 1
			end
		end
		tween(scale, UiKit.Motion.fast, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		if not b:GetAttribute("Disabled") then
			tween(scale, 0.06, { Scale = 0.97 })
		end
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, UiKit.Motion.fast, { Scale = 1 })
	end)
end

local function wireClick(b, opts)
	b.Activated:Connect(function()
		if b:GetAttribute("Disabled") then
			if opts.onDisabledClick then
				opts.onDisabledClick(b:GetAttribute("DisabledReason"))
			end
			return
		end
		if opts.silent ~= true then
			click()
		end
		if opts.onClick then
			opts.onClick()
		end
	end)
end

-- UiKit.Button(parent, "Buy", { variant = "primary" | "secondary" | "ghost" | "danger",
--     size = "lg" | "md" | "sm", width = 220 (fixed), minWidth = 150 (grows with text), fill = true,
--     onClick, onDisabledClick(reason) })
function UiKit.Button(parent, text, opts)
	opts = opts or {}
	local v = BUTTON_VARIANTS[opts.variant or "secondary"]
	local s = BUTTON_SIZES[opts.size or "md"]
	local b = new("TextButton", {
		Name = opts.name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = v.bg,
		BackgroundTransparency = if v.transparent then 1 else 0,
		Text = string.upper(text),
		FontFace = Fonts.LabelBold,
		TextSize = s[2],
		TextColor3 = v.text,
		Size = if opts.fill then UDim2.new(1, 0, 0, s[1]) else UDim2.fromOffset(opts.width or opts.minWidth or 120, s[1]),
		AutomaticSize = if opts.fill or opts.width then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.round(b, UiKit.Radius.control)
	UiKit.pad(b, 0, 20, 0, 20)
	if v.stroke then
		UiKit.border(b, v.stroke, 1, if opts.variant == "primary" then 0 else 0.2)
	end
	if v.glass then
		new("UIGradient", { Name = "Glass", Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(226, 206, 170)) }, b)
	end
	b:SetAttribute("Variant", opts.variant or "secondary")
	b:SetAttribute("BaseColor", v.bg)
	b:SetAttribute("HoverColor", v.hover)
	b:SetAttribute("BaseTextColor", v.text)
	b:SetAttribute("BaseText", b.Text)
	if v.stroke then
		b:SetAttribute("BaseStrokeColor", v.stroke)
	end
	if v.transparent then
		b:SetAttribute("GhostButton", true)
	end
	UiKit.focusable(b)
	attachFeedback(b)
	wireClick(b, opts)
	return b
end

function UiKit.IconButton(parent, glyph, opts)
	opts = opts or {}
	local b = new("TextButton", {
		Name = opts.name or "IconButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color.SurfaceElevated,
		BackgroundTransparency = if opts.quiet then 1 else 0,
		Size = UDim2.fromOffset(UiKit.TOUCH, UiKit.TOUCH),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.round(b, UiKit.Radius.control)
	if not opts.quiet then
		UiKit.border(b, Color.BorderStructural, 1, 0.3)
	end
	local g = UiKit.Glyph(b, glyph, opts.color or Color.TextPrimary, opts.glyphSize or 16)
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	b:SetAttribute("BaseColor", Color.SurfaceElevated)
	b:SetAttribute("HoverColor", Color.SurfaceHover)
	if opts.quiet then
		b:SetAttribute("GhostButton", true)
	end
	if opts.tip then
		UiKit.Tooltip(b, opts.tip)
	end
	UiKit.focusable(b)
	attachFeedback(b)
	wireClick(b, opts)
	return b
end

-- Disabled buttons stay focusable so controller players can read WHY (tooltip on focus)
function UiKit.SetDisabled(b, disabled, reason)
	b:SetAttribute("Disabled", disabled)
	b:SetAttribute("DisabledReason", if disabled then reason else nil)
	local glass = b:FindFirstChild("Glass")
	if glass then
		glass.Enabled = not disabled
	end
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if disabled then
		b.BackgroundColor3 = Color.StateDisabled
		b.TextColor3 = Color.StateDisabledText
		if b:GetAttribute("GhostButton") then
			b.BackgroundTransparency = 1
		end
		if stroke then
			stroke.Color = Color.BorderSubtle
		end
	else
		b.BackgroundColor3 = b:GetAttribute("BaseColor") or b.BackgroundColor3
		b.TextColor3 = b:GetAttribute("BaseTextColor") or b.TextColor3
		if stroke and b:GetAttribute("BaseStrokeColor") then
			stroke.Color = b:GetAttribute("BaseStrokeColor")
		end
	end
	if reason then
		UiKit.Tooltip(b)
	end
end

-- Busy state for an action in flight: disabled, label replaced, a small lamp turning beside it
function UiKit.SetBusy(b, busy, text)
	UiKit.SetDisabled(b, busy)
	local spinner = b:FindFirstChild("BusyLamp")
	if busy then
		b.Text = string.upper(text or "Working...")
		if not spinner then
			spinner = new("Frame", {
				Name = "BusyLamp",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -14, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
			}, b)
			local beam = new("Frame", {
				BackgroundColor3 = Color.StateDisabledText,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0.5, 0, 0, 2),
			}, spinner)
			local core = new("Frame", {
				BackgroundColor3 = Color.StateDisabledText,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(5, 5),
			}, spinner)
			UiKit.round(core, 3)
			_ = beam
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				if not spinner.Parent then
					connection:Disconnect()
					return
				end
				spinner.Rotation = (spinner.Rotation + dt * 300) % 360
			end)
		end
	else
		b.Text = b:GetAttribute("BaseText") or b.Text
		if spinner then
			spinner:Destroy()
		end
	end
end

-- For the style guide and tests: show a component in a fixed interaction state
-- state: "hover" | "pressed" | "focus" | "selected" | "disabled" | "loading"
function UiKit.PreviewState(b, state)
	if state == "hover" then
		b.BackgroundColor3 = b:GetAttribute("HoverColor") or b.BackgroundColor3
		if b:GetAttribute("GhostButton") then
			b.BackgroundTransparency = 0.4
		end
	elseif state == "pressed" then
		b.BackgroundColor3 = b:GetAttribute("HoverColor") or b.BackgroundColor3
		local scale = b:FindFirstChild("PressScale")
		if scale then
			scale.Scale = 0.95
		end
	elseif state == "focus" then
		local ring = focusRing:Clone()
		ring.Name = "FocusPreview"
		ring.ZIndex = 6
		local padding = b:FindFirstChildOfClass("UIPadding")
		local left = if padding then padding.PaddingLeft.Offset else 0
		local right = if padding then padding.PaddingRight.Offset else 0
		local top = if padding then padding.PaddingTop.Offset else 0
		local bottom = if padding then padding.PaddingBottom.Offset else 0
		ring.Position = UDim2.fromOffset(-6 - left, -6 - top)
		ring.Size = UDim2.new(1, 12 + left + right, 1, 12 + top + bottom)
		ring.Parent = b
	elseif state == "disabled" then
		UiKit.SetDisabled(b, true, "Example of a disabled action with its reason.")
	elseif state == "loading" then
		UiKit.SetBusy(b, true, "Saving...")
	end
end

---------------------------------------------------------------------
-- TOOLTIP (mouse hover after a short pause, or controller focus). DisabledReason wins.
---------------------------------------------------------------------

function UiKit.Tooltip(obj, text)
	if text then
		obj:SetAttribute("Tip", text)
	end
	if obj:GetAttribute("TipWired") then
		return
	end
	obj:SetAttribute("TipWired", true)
	local tip
	local token = 0
	local function hide()
		token += 1
		if tip then
			tip:Destroy()
			tip = nil
		end
	end
	local function show()
		local message = obj:GetAttribute("DisabledReason") or obj:GetAttribute("Tip")
		local gui = obj:FindFirstAncestorOfClass("ScreenGui")
		if not message or message == "" or not gui then
			return
		end
		tip = new("TextLabel", {
			Name = "Tooltip",
			BackgroundColor3 = Color.SurfaceBase,
			TextColor3 = Color.TextPrimary,
			FontFace = Fonts.BodyMedium,
			TextSize = 15,
			LineHeight = 1.1,
			Text = message,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(250, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 400,
		}, gui)
		UiKit.round(tip, UiKit.Radius.control)
		UiKit.border(tip, Color.BorderStructural, 1)
		UiKit.pad(tip, 8, 10)
		local origin = obj.AbsolutePosition - gui.AbsolutePosition
		local x = math.clamp(origin.X, 8, math.max(8, gui.AbsoluteSize.X - 258))
		local y = origin.Y + obj.AbsoluteSize.Y + 8
		if y + 64 > gui.AbsoluteSize.Y then
			y = origin.Y - 60
		end
		tip.Position = UDim2.fromOffset(x, y)
	end
	obj.MouseEnter:Connect(function()
		hide()
		local mine = token
		task.delay(0.35, function()
			if mine == token then
				show()
			end
		end)
	end)
	obj.MouseLeave:Connect(hide)
	obj.SelectionGained:Connect(function()
		hide()
		show()
	end)
	obj.SelectionLost:Connect(hide)
	obj.Destroying:Connect(hide)
end

---------------------------------------------------------------------
-- INPUT HINT: a keycap that matches the player's current input (keyboard, controller, touch)
---------------------------------------------------------------------

-- keys = { keyboard = "E", gamepad = Enum.KeyCode.ButtonX, touch = "Tap" }; opts.input forces one
function UiKit.KeyHint(parent, keys, label, opts)
	opts = opts or {}
	local frame = new("Frame", {
		Name = "KeyHint",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.list(frame, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	local cap = new("Frame", {
		Name = "Keycap",
		BackgroundColor3 = Color.SurfaceElevated,
		Size = UDim2.fromOffset(32, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
	}, frame)
	UiKit.round(cap, UiKit.Radius.control)
	UiKit.border(cap, Color.BorderBrassBright, 1, 0.25)
	new("Frame", {
		Name = "KeyLip",
		BackgroundColor3 = Color.SurfaceBase,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, 0),
		Size = UDim2.new(1, -4, 0, 3),
	}, cap)
	local capText = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.LabelBold,
		TextSize = 16,
		TextColor3 = Color.TextPrimary,
		Size = UDim2.new(0, 32, 1, -2),
		AutomaticSize = Enum.AutomaticSize.X,
	}, cap)
	UiKit.pad(capText, 0, 8, 0, 8)
	local capImage = new("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		Visible = false,
	}, cap)
	UiKit.Label(frame, label, "Body", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 2,
	})
	local function mode()
		if opts.input then
			return opts.input
		end
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			return "touch"
		elseif usingGamepad() then
			return "gamepad"
		end
		return "keyboard"
	end
	local function refresh()
		local m = mode()
		capImage.Visible = false
		capText.Visible = true
		if m == "gamepad" then
			local keyCode = keys.gamepad or Enum.KeyCode.ButtonX
			local image = UserInputService:GetImageForKeyCode(keyCode)
			if image and image ~= "" then
				capImage.Image = image
				capImage.Visible = true
				capText.Text = ""
				capText.Size = UDim2.new(0, 32, 1, -2)
			else
				capText.Text = keyCode.Name:gsub("Button", "")
			end
		elseif m == "touch" then
			capText.Text = string.upper(keys.touch or "Tap")
		else
			capText.Text = string.upper(keys.keyboard or "E")
		end
	end
	refresh()
	if not opts.input then
		local connection = UserInputService.LastInputTypeChanged:Connect(refresh)
		frame.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end
	return frame
end

---------------------------------------------------------------------
-- TABS (L1/R1 on a controller). Underline + ivory text marks the selected tab.
---------------------------------------------------------------------

function UiKit.Tabs(parent, items, opts)
	opts = opts or {}
	local bar = new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = opts.size or UDim2.new(1, 0, 0, 46), LayoutOrder = opts.layoutOrder or 0 }, parent)
	new("Frame", {
		Name = "Rule",
		BackgroundColor3 = Color.BorderSubtle,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
	}, bar)
	local row = new("ScrollingFrame", {
		Name = "Row",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Selectable = false,
	}, bar)
	UiKit.list(row, "x", opts.gap or 2)
	local tabs = {}
	local self = { frame = bar, buttons = tabs, selected = nil }

	function self.set(id, silent)
		self.selected = id
		for tabId, t in tabs do
			local on = tabId == id
			t.button.TextColor3 = if on then Color.TextPrimary else Color.TextSecondary
			t.button.BackgroundTransparency = if on then 0.55 else 1
			t.underline.Visible = on
		end
		if not silent and opts.onChange then
			opts.onChange(id)
		end
	end

	for index, item in items do
		local accent = if item.color then (Color[item.color] or item.color) else Color.AccentLighthouse
		local b = new("TextButton", {
			Name = "Tab_" .. item.id,
			AutoButtonColor = false,
			BackgroundColor3 = Color.SurfaceSecondary,
			BackgroundTransparency = 1,
			Text = string.upper(item.label),
			FontFace = Fonts.LabelBold,
			TextSize = opts.textSize or 18,
			TextColor3 = Color.TextSecondary,
			Size = UDim2.fromOffset(opts.minWidth or 84, 45),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
		}, row)
		UiKit.round(b, UiKit.Radius.tag)
		UiKit.pad(b, 0, 16, 0, 16)
		local underline = new("Frame", {
			Name = "Underline",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			Visible = false,
		}, b)
		UiKit.focusable(b)
		b.MouseEnter:Connect(function()
			if self.selected ~= item.id then
				b.TextColor3 = Color.TextPrimary
			end
		end)
		b.MouseLeave:Connect(function()
			if self.selected ~= item.id then
				b.TextColor3 = Color.TextSecondary
			end
		end)
		b.Activated:Connect(function()
			if self.selected ~= item.id then
				click()
				self.set(item.id)
			end
		end)
		tabs[item.id] = { button = b, underline = underline, index = index }
	end

	if opts.shoulders then
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode ~= Enum.KeyCode.ButtonL1 and input.KeyCode ~= Enum.KeyCode.ButtonR1 then
				return
			end
			if not isShown(bar) then
				return
			end
			local current = tabs[self.selected] and tabs[self.selected].index or 1
			local step = if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1
			local nextIndex = (current - 1 + step) % #items + 1
			click()
			self.set(items[nextIndex].id)
		end)
		bar.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end

	self.set(opts.selected or items[1].id, true)
	return self
end

---------------------------------------------------------------------
-- SETTINGS CONTROLS
---------------------------------------------------------------------

function UiKit.Toggle(parent, opts)
	opts = opts or {}
	local value = opts.value == true
	local b = new("TextButton", {
		Name = opts.name or "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color.SurfaceInset,
		Size = UDim2.fromOffset(88, UiKit.TOUCH),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.round(b, 22)
	local stroke = UiKit.border(b, Color.BorderStructural, 1.5, 0.3)
	local knob = new("Frame", {
		Name = "Knob",
		BackgroundColor3 = Color.TextSecondary,
		Size = UDim2.fromOffset(32, 32),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
	}, b)
	UiKit.round(knob, 16)
	local word = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.LabelBold,
		TextSize = 15,
		Size = UDim2.new(0, 40, 1, 0),
	}, b)
	UiKit.focusable(b)
	local self = { button = b }
	local function render(animate)
		local t = if animate then UiKit.Motion.fast else 0
		if value then
			tween(knob, t, { Position = UDim2.new(1, -38, 0.5, 0), BackgroundColor3 = Color.TextOnAccent })
			tween(b, t, { BackgroundColor3 = Color.AccentLighthouse })
			stroke.Color = Color.AccentLighthouseDeep
			word.Text = "ON"
			word.TextColor3 = Color.TextOnAccent
			word.Position = UDim2.fromOffset(8, 0)
		else
			tween(knob, t, { Position = UDim2.new(0, 6, 0.5, 0), BackgroundColor3 = Color.TextSecondary })
			tween(b, t, { BackgroundColor3 = Color.SurfaceInset })
			stroke.Color = Color.BorderStructural
			word.Text = "OFF"
			word.TextColor3 = Color.TextMuted
			word.Position = UDim2.new(1, -46, 0, 0)
		end
	end
	function self.set(v, silent)
		value = v == true
		render(true)
		if not silent and opts.onChange then
			opts.onChange(value)
		end
	end
	function self.get()
		return value
	end
	b.Activated:Connect(function()
		click()
		self.set(not value)
	end)
	render(false)
	return self
end

function UiKit.Slider(parent, opts)
	opts = opts or {}
	local min, max, step = opts.min or 0, opts.max or 100, opts.step or 1
	local value = opts.value or min
	local format = opts.format or function(v)
		return tostring(v)
	end
	local frame = new("Frame", {
		Name = opts.name or "Slider",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromOffset(320, UiKit.TOUCH),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	local readout = new("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = 19,
		TextColor3 = Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 58, 1, 0),
	}, frame)
	local self = { frame = frame }
	local minus = UiKit.IconButton(frame, "minus", { name = "Less", glyphSize = 14, silent = true })
	local plus = UiKit.IconButton(frame, "plus", { name = "More", glyphSize = 14, silent = true })
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, -66, 0, 0)
	local track = new("TextButton", {
		Name = "Track",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -54 - 66 - 54, 1, 0),
		Selectable = false,
	}, frame)
	local rail = new("Frame", {
		BackgroundColor3 = Color.SurfaceInset,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
	}, track)
	UiKit.round(rail, 3)
	UiKit.border(rail, Color.BorderStructural, 1, 0.45)
	local fill = new("Frame", { BackgroundColor3 = Color.AccentLighthouse, Size = UDim2.fromScale(0, 1) }, rail)
	UiKit.round(fill, 3)
	local knob = new("Frame", {
		BackgroundColor3 = Color.TextPrimary,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
	}, track)
	UiKit.round(knob, 10)
	UiKit.border(knob, Color.AccentLighthouseDeep, 2)

	function self.set(v, silent)
		v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
		local changed = v ~= value
		value = v
		local alpha = if max > min then (value - min) / (max - min) else 0
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		readout.Text = format(value)
		if changed and not silent and opts.onChange then
			opts.onChange(value)
		end
	end
	function self.get()
		return value
	end
	minus.Activated:Connect(function()
		click()
		self.set(value - step)
	end)
	plus.Activated:Connect(function()
		click()
		self.set(value + step)
	end)
	local dragging = false
	local function setFromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		self.set(min + alpha * (max - min))
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	frame.Destroying:Connect(function()
		moved:Disconnect()
		ended:Disconnect()
	end)
	value = nil
	self.set(opts.value or min, true)
	return self
end

-- A list row (no box): title + sentence-case description, control on the right, hairline below.
-- stacked = true puts the control under the text (narrow screens). last = true drops the hairline.
function UiKit.SettingRow(parent, title, description, opts)
	opts = opts or {}
	local controlWidth = opts.controlWidth or 320
	local row = new("Frame", {
		Name = opts.name or "SettingRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	local inner = new("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, row)
	UiKit.pad(inner, 12, 0, 13, 0)
	local textColumn = new("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = if opts.stacked then UDim2.new(1, 0, 0, 0) else UDim2.new(1, -controlWidth - 20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	}, inner)
	UiKit.list(textColumn, "y", 2)
	UiKit.Label(textColumn, title, "H3", { LayoutOrder = 1 })
	if description then
		UiKit.Label(textColumn, description, "BodySmall", { LayoutOrder = 2 })
	end
	local slot = new("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		Size = if opts.stacked then UDim2.new(1, 0, 0, UiKit.TOUCH) else UDim2.fromOffset(controlWidth, UiKit.TOUCH),
		LayoutOrder = 2,
	}, inner)
	if opts.stacked then
		UiKit.list(inner, "y", 10)
	else
		UiKit.list(inner, "x", 20, { VerticalAlignment = Enum.VerticalAlignment.Center })
	end
	if not opts.last then
		new("Frame", {
			Name = "Hairline",
			BackgroundColor3 = Color.BorderSubtle,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
		}, row)
	end
	return row, slot
end

---------------------------------------------------------------------
-- DISPLAY: currency, tags, badges
---------------------------------------------------------------------

-- Pearl or Shell amount. Shows the word too (never icon alone). Width is reserved per digit
-- count so counters don't jitter. opts: size "md" | "lg", plain (no housing), showWord, color
function UiKit.Currency(parent, kind, amount, opts)
	opts = opts or {}
	local big = opts.size == "lg"
	local frame = new("Frame", {
		Name = kind .. "Display",
		BackgroundColor3 = Color.SurfaceInset,
		BackgroundTransparency = if opts.plain then 1 else 0,
		Size = UDim2.fromOffset(0, if big then 44 else 34),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	if not opts.plain then
		UiKit.round(frame, UiKit.Radius.control)
		UiKit.border(frame, Color.BorderStructural, 1, 0.3)
		UiKit.pad(frame, 0, 12, 0, 10)
	end
	UiKit.list(frame, "x", 7, { VerticalAlignment = Enum.VerticalAlignment.Center })
	UiKit.CurrencyIcon(frame, kind, if big then 22 else 17).LayoutOrder = 1
	local textSize = if big then 23 else (opts.textSize or 18)
	local number = new("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = textSize,
		TextColor3 = opts.color or Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = 2,
	}, frame)
	new("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		FontFace = Fonts.Label,
		TextSize = if big then 14 else 13,
		TextColor3 = Color.TextMuted,
		Text = string.upper(kind),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Visible = opts.showWord ~= false,
	}, frame)
	local self = { frame = frame, number = number }
	function self.set(n, flash)
		number.Text = formatNumber(n)
		number.Size = UDim2.fromOffset(numberWidth(number.Text, textSize), 24)
		if flash then
			number.TextColor3 = Color.AccentLighthouseSoft
			tween(number, UiKit.Motion.slow, { TextColor3 = opts.color or Color.TextPrimary })
		end
	end
	self.set(amount or 0)
	return self
end

-- Category / info chip. filled = solid with dark text; otherwise a tinted outline.
function UiKit.Tag(parent, text, colorName, opts)
	opts = opts or {}
	local color = Color[colorName] or colorName or Color.AccentSea
	local t = new("TextLabel", {
		Name = opts.name or "Tag",
		BackgroundColor3 = color,
		BackgroundTransparency = if opts.filled then 0 else 0.84,
		Text = string.upper(text),
		FontFace = Fonts.LabelBold,
		TextSize = 13,
		TextColor3 = if opts.filled then Color.TextOnAccent else color,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.round(t, UiKit.Radius.tag)
	UiKit.pad(t, 0, 7, 0, 7)
	if not opts.filled then
		UiKit.border(t, color, 1, 0.5)
	end
	return t
end

local function restyleTag(tag, text, color, filled)
	tag.Text = string.upper(text)
	tag.BackgroundColor3 = color
	tag.BackgroundTransparency = if filled then 0 else 0.84
	tag.TextColor3 = if filled then Color.TextOnAccent else color
	local stroke = tag:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Enabled = not filled
	elseif not filled then
		UiKit.border(tag, color, 1, 0.5)
	end
end

-- Item status badges. kind: "equipped" (strong) | "owned" (quiet) | "new" | "locked"
local BADGES = {
	equipped = { bg = Color.AccentLighthouse, bgT = 0, fg = Color.TextOnAccent, glyph = "check", label = "Equipped" },
	owned = { bg = Color.SurfaceBase, bgT = 0.25, fg = Color.TextSecondary, glyph = "check", glyphColor = Color.AccentSea, label = "Owned" },
	new = { bg = Color.SurfaceBase, bgT = 0.25, fg = Color.AccentLighthouseSoft, dot = true, label = "New" },
	locked = { bg = Color.SurfaceBase, bgT = 0.15, fg = Color.TextPrimary, glyph = "lock", label = "Locked" },
}
function UiKit.Badge(parent, kind, text, opts)
	opts = opts or {}
	local style = BADGES[kind]
	local b = new("Frame", {
		Name = "Badge_" .. kind,
		BackgroundColor3 = style.bg,
		BackgroundTransparency = style.bgT,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = opts.layoutOrder or 0,
		ZIndex = 5,
	}, parent)
	UiKit.round(b, UiKit.Radius.tag)
	UiKit.pad(b, 0, 6, 0, 5)
	UiKit.list(b, "x", 4, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if style.glyph then
		UiKit.Glyph(b, style.glyph, style.glyphColor or style.fg, 10).LayoutOrder = 1
	elseif style.dot then
		local d = new("Frame", { BackgroundColor3 = Color.AccentLighthouse, Size = UDim2.fromOffset(6, 6), LayoutOrder = 1 }, b)
		UiKit.round(d, 3)
	end
	new("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		FontFace = Fonts.LabelBold,
		TextSize = 13,
		TextColor3 = style.fg,
		Text = string.upper(text or style.label),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	}, b)
	return b
end

---------------------------------------------------------------------
-- ITEM CARD (Shop and Inventory). Priority: visual > name > type > price > status.
---------------------------------------------------------------------

-- opts: itemId, name, category, subtitle, quantity, price = { kind, amount }, shortBy,
--       equipped, owned, selected, affordable, locked (reason string), isNew,
--       rarity = { label = "Rare", rank = 2 } (only if the game ever adds rarity),
--       onClick(itemId, card), size, layoutOrder
function UiKit.ItemCard(parent, opts)
	local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))
	local category = opts.category or "Materials"
	local catColor = Color[UiKit.CATEGORY[category] or "CatMaterials"]
	local card = new("TextButton", {
		Name = "Card_" .. tostring(opts.itemId),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color.SurfaceSecondary,
		Size = opts.size or UDim2.fromOffset(156, 212),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.round(card, UiKit.Radius.card)
	local stroke = UiKit.border(card, Color.BorderSubtle, 1, 1)
	UiKit.focusable(card)

	local well = UiKit.Inset(card, {
		Name = "Well",
		BackgroundColor3 = rgb(22, 32, 46),
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -76),
		ClipsDescendants = true,
	})
	new("Frame", {
		Name = "CategoryRule",
		BackgroundColor3 = catColor,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 4,
	}, well)
	local preview = ItemPreview.new(well, {})
	preview:setItem(opts.itemId)

	local badges = new("Frame", {
		Name = "Badges",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 0, 20),
		ZIndex = 5,
	}, well)
	UiKit.list(badges, "x", 4)
	local equippedBadge = UiKit.Badge(badges, "equipped", nil, { layoutOrder = 1 })
	local ownedBadge = UiKit.Badge(badges, "owned", nil, { layoutOrder = 2 })
	local topRight = new("Frame", {
		Name = "TopRight",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 5,
	}, well)
	UiKit.list(topRight, "x", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	local quantity = new("TextLabel", {
		Name = "Quantity",
		BackgroundColor3 = Color.SurfaceBase,
		BackgroundTransparency = 0.2,
		FontFace = Fonts.Numeric,
		TextSize = 15,
		TextColor3 = Color.TextPrimary,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = 5,
	}, topRight)
	UiKit.round(quantity, UiKit.Radius.tag)
	UiKit.pad(quantity, 0, 6, 0, 6)
	local newBadge = UiKit.Badge(topRight, "new", nil, { layoutOrder = 1 })

	local rarityMarks
	if opts.rarity then
		rarityMarks = new("Frame", {
			Name = "RarityMarks",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 6, 1, -7),
			Size = UDim2.fromOffset(0, 8),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 5,
		}, well)
		UiKit.list(rarityMarks, "x", 3)
		for i = 1, opts.rarity.rank or 1 do
			new("Frame", {
				BackgroundColor3 = Color.BorderBrassBright,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(6, 6),
				Rotation = 45,
				LayoutOrder = i,
				ZIndex = 5,
			}, rarityMarks)
		end
	end

	local lockOverlay = new("Frame", {
		Name = "Locked",
		BackgroundColor3 = Color.Scrim,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Visible = false,
	}, well)
	local lockGlyph = UiKit.Glyph(lockOverlay, "lock", Color.TextPrimary, 18)
	lockGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	lockGlyph.Position = UDim2.fromScale(0.5, 0.36)
	local lockReason = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.BodyMedium,
		TextSize = 13,
		TextColor3 = Color.TextPrimary,
		TextWrapped = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.new(1, -12, 0.4, 0),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 6,
	}, lockOverlay)

	local name = new("TextLabel", {
		Name = "ItemName",
		BackgroundTransparency = 1,
		FontFace = Fonts.BodyBold,
		TextSize = 16,
		TextColor3 = Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		Text = opts.name or tostring(opts.itemId),
		Position = UDim2.new(0, 10, 1, -62),
		Size = UDim2.new(1, -20, 0, 20),
	}, card)
	new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 12 }, name)
	local typeLine = new("TextLabel", {
		Name = "Type",
		BackgroundTransparency = 1,
		FontFace = Fonts.Label,
		TextSize = 14,
		TextColor3 = catColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper((if opts.rarity then opts.rarity.label .. " · " else "") .. (opts.subtitle or category)),
		Position = UDim2.new(0, 10, 1, -30),
		Size = UDim2.new(1, -20, 0, 18),
	}, card)
	local priceRow, shortGlyph
	if opts.price then
		priceRow = UiKit.Currency(card, opts.price.kind, opts.price.amount, { plain = true, showWord = false, textSize = 17 })
		priceRow.frame.AnchorPoint = Vector2.new(1, 1)
		priceRow.frame.Position = UDim2.new(1, -10, 1, -8)
		priceRow.frame.Size = UDim2.fromOffset(0, 22)
		shortGlyph = UiKit.Glyph(priceRow.frame, "warning", Color.StateDanger, 13)
		shortGlyph.LayoutOrder = 0
	end
	local brackets = UiKit.Brackets(card, Color.AccentLighthouse, 12, 2, -4)

	local self = { frame = card, preview = preview, name = name, typeLine = typeLine }
	local state = {}
	local function render()
		local emphasized = state.selected or state.equipped
		stroke.Transparency = if emphasized then 0 else 1
		stroke.Color = if state.selected then Color.BorderSelected else Color.AccentLighthouseDeep
		stroke.Thickness = if state.selected then 2 else 1
		brackets.Visible = state.selected == true
		card.BackgroundColor3 = if state.selected then Color.SurfaceElevated else Color.SurfaceSecondary
		equippedBadge.Visible = state.equipped == true
		ownedBadge.Visible = state.owned == true and not state.equipped
		quantity.Visible = state.quantity ~= nil and state.quantity > 0
		newBadge.Visible = state.isNew == true
		lockOverlay.Visible = state.locked ~= nil
		lockReason.Text = state.locked or ""
		if priceRow then
			priceRow.frame.Visible = not state.owned and not state.locked
			priceRow.number.TextColor3 = if state.affordable then Color.TextPrimary else Color.TextSecondary
			shortGlyph.Visible = not state.affordable
		end
		if state.affordable == false and opts.shortBy then
			UiKit.Tooltip(card, string.format("You need %s more %s.", formatNumber(opts.shortBy), opts.price and opts.price.kind or "Pearls"))
		end
	end
	function self.setSelected(on)
		state.selected = on
		render()
	end
	function self.setEquipped(on)
		state.equipped = on
		render()
	end
	function self.setOwned(on)
		state.owned = on
		render()
	end
	function self.setAffordable(on)
		state.affordable = on
		render()
	end
	function self.setLocked(reason)
		state.locked = reason
		render()
	end
	function self.setNew(on)
		state.isNew = on
		render()
	end
	function self.setQuantity(n)
		state.quantity = n
		quantity.Text = if n then "x" .. formatNumber(n) else ""
		render()
	end
	card.MouseEnter:Connect(function()
		if not state.selected then
			card.BackgroundColor3 = Color.SurfaceHover
		end
	end)
	card.MouseLeave:Connect(render)
	card.Activated:Connect(function()
		click()
		if opts.onClick then
			opts.onClick(opts.itemId, self)
		end
	end)
	state.selected = opts.selected == true
	state.equipped = opts.equipped == true
	state.owned = opts.owned == true
	state.affordable = opts.affordable ~= false
	state.locked = opts.locked
	state.isNew = opts.isNew == true
	self.setQuantity(opts.quantity)
	return self
end

---------------------------------------------------------------------
-- GAUGES: one family, four silhouettes. Shared: icon cap (Inset), Label text, numeric readout.
---------------------------------------------------------------------

local function gaugeCap(frame, size, glyphKind, glyphColor, glyphSize)
	local cap = UiKit.Inset(frame, { Name = "Cap", Size = UDim2.fromOffset(size, size) })
	UiKit.border(cap, Color.BorderStructural, 1, 0.55)
	local glyph = UiKit.Glyph(cap, glyphKind, glyphColor, glyphSize)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	return cap, glyph
end

local function readoutLabel(parent, size)
	return new("TextLabel", {
		Name = "Readout",
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = size,
		TextColor3 = Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(0, size + 2),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 9,
	}, parent)
end

-- GENERIC RESOURCE (secondary resources only, e.g. cannon ammo)
-- opts: label, value 0..1, text, color (token), warnBelow, dangerBelow, ticks
function UiKit.ResourceGauge(parent, opts)
	opts = opts or {}
	local frame = new("Frame", {
		Name = opts.name or "ResourceGauge",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.new(1, 0, 0, 38),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	UiKit.Label(frame, opts.label or "", "Label", {
		Size = UDim2.new(0.6, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.None,
		TextWrapped = false,
	})
	local readout = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = 15,
		TextColor3 = Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 0, 16),
	}, frame)
	local track = UiKit.Inset(frame, {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 10),
	})
	local fill = new("Frame", { BackgroundColor3 = Color.AccentLighthouse, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	UiKit.round(fill, 3)
	local ticks = opts.ticks or 10
	for i = 1, ticks - 1 do
		new("Frame", {
			BackgroundColor3 = Color.SurfaceBase,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(i / ticks, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 3,
		}, track)
	end
	local self = { frame = frame }
	function self.set(v, text)
		v = math.clamp(v or 0, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		local color = Color[opts.color or "AccentSea"]
		if opts.dangerBelow and v < opts.dangerBelow then
			color = Color.StateDanger
		elseif opts.warnBelow and v < opts.warnBelow then
			color = Color.StateWarning
		end
		fill.BackgroundColor3 = color
		readout.Text = text or string.format("%d%%", math.floor(v * 100 + 0.5))
	end
	self.set(opts.value or 0, opts.text)
	return self
end
UiKit.Gauge = UiKit.ResourceGauge

-- PLAYER HEALTH: compact survival instrument. Coral fill, a pale trailing segment shows recent
-- damage, a brass marker at 25% shows where "critical" begins.
function UiKit.HealthGauge(parent, opts)
	opts = opts or {}
	local max = opts.max or 100
	local frame = new("Frame", {
		Name = "HealthGauge",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromOffset(300, 38),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	local cap, heart = gaugeCap(frame, 38, "heart", Color.StateDanger, 18)
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 1, 0) }, frame)
	local label = UiKit.Label(body, "Health", "Label", { Size = UDim2.new(0.7, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
	local readout = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = 15,
		TextColor3 = Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 16),
	}, body)
	UiKit.fitHeader(label, readout)
	local track = UiKit.Inset(body, {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 14),
	})
	local trail = new("Frame", { Name = "Trail", BackgroundColor3 = Color.HealthTrail, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, track)
	UiKit.round(trail, 3)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Color.StateDanger, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, track)
	UiKit.round(fill, 3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(200, 190, 190)) }, fill)
	new("Frame", {
		Name = "CriticalMark",
		BackgroundColor3 = Color.BorderBrassBright,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.25, 0, 1, 2),
		Size = UDim2.fromOffset(2, 20),
		ZIndex = 4,
	}, track)
	local self = { frame = frame }
	local shown
	local token = 0
	function self.set(v)
		v = math.clamp(v, 0, max)
		local alpha = v / max
		local before = shown
		shown = alpha
		fill.Size = UDim2.fromScale(alpha, 1) -- damage reads instantly; the trail catches up
		if before and alpha < before then
			trail.Size = UDim2.fromScale(before, 1)
			token += 1
			local mine = token
			task.delay(0.35, function()
				if mine == token then
					tween(trail, 0.3, { Size = UDim2.fromScale(alpha, 1) })
				end
			end)
		else
			trail.Size = UDim2.fromScale(alpha, 1)
		end
		readout.Text = string.format("%d / %d", math.ceil(v), max)
		local critical = alpha <= 0.25
		cap.BackgroundColor3 = if critical then Color.StateDanger else Color.SurfaceInset
		UiKit.SetGlyphColor(heart, if critical then Color.TextOnAccent else Color.StateDanger)
		label.Text = self.note or (if critical then "HEALTH · CRITICAL" else "HEALTH")
		label.TextColor3 = if critical or self.note then Color.StateDanger else Color.TextSecondary
	end
	-- the maximum can change (armor); the current value is kept
	function self.setMax(newMax)
		max = math.max(1, newMax)
	end
	-- a short override for the label, e.g. "HEALTH · DOWN"; nil restores the normal label
	function self.setNote(text)
		self.note = text
	end
	-- jump straight to a value with no trailing segment (respawn, new run)
	function self.reset(v)
		shown = nil
		token += 1
		self.set(v)
	end
	self.set(opts.value or max)
	return self
end

-- LIGHTHOUSE FUEL: the main objective instrument. Taller, lamp cap, compass-style scale above
-- the reservoir, quarter marks, and four stages: steady, LOW, CRITICAL, BLACKOUT.
function UiKit.FuelGauge(parent, opts)
	opts = opts or {}
	local frame = new("Frame", {
		Name = "FuelGauge",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromOffset(380, 58),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	local cap, lamp = gaugeCap(frame, 58, "lamp", Color.AccentLighthouse, 30)
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -68, 1, 0) }, frame)
	local label = UiKit.Label(body, "Lamp fuel", "Label", {
		Size = UDim2.new(0.5, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		TextWrapped = false,
		TextSize = 16,
		TextColor3 = Color.TextPrimary,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local right = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
	}, body)
	UiKit.list(right, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Right })
	local stateTag = UiKit.Tag(right, "Low", "StateWarning", { layoutOrder = 1 })
	local percent = readoutLabel(right, 20)
	local scale = new("Frame", { Name = "Scale", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 6) }, body)
	for i = 0, 20 do
		local major = i % 5 == 0
		new("Frame", {
			BackgroundColor3 = Color.BorderBrassBright,
			BackgroundTransparency = if major then 0.3 else 0.62,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(i / 20, 1),
			Size = UDim2.fromOffset(if major then 2 else 1, if major then 6 else 3),
		}, scale)
	end
	local track = UiKit.Inset(body, { Name = "Reservoir", Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 18) })
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Color.AccentLighthouse, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, track)
	UiKit.round(fill, 3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(205, 185, 150)) }, fill)
	for _, q in { 0.25, 0.5, 0.75 } do
		new("Frame", {
			BackgroundColor3 = Color.SurfaceBase,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(q, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 3,
		}, track)
	end
	local self = { frame = frame }
	function self.set(v)
		v = math.clamp(v or 0, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		percent.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
		fill.Visible = v > 0
		track.BackgroundColor3 = if v <= 0 then Color.Scrim else Color.SurfaceInset
		local stage
		if v <= 0 then
			stage = "blackout"
			restyleTag(stateTag, "Blackout", Color.StateDanger, true)
		elseif v < 0.15 then
			stage = "critical"
			fill.BackgroundColor3 = Color.StateDanger
			restyleTag(stateTag, "Critical", Color.StateDanger, true)
		elseif v < 0.3 then
			stage = "low"
			fill.BackgroundColor3 = Color.StateWarning
			restyleTag(stateTag, "Low", Color.StateWarning, false)
		else
			stage = "steady"
			fill.BackgroundColor3 = Color.AccentLighthouse
		end
		stateTag.Visible = stage ~= "steady"
		UiKit.SetGlyphColor(lamp, if stage == "blackout" then Color.TextMuted else Color.AccentLighthouse)
		cap.BackgroundColor3 = if stage == "blackout" then Color.SurfaceBase else Color.SurfaceInset
		label.TextColor3 = if stage == "blackout" or stage == "critical" then Color.StateDanger else Color.TextPrimary
		self.stage = stage
	end
	self.set(opts.value or 1)
	return self
end

-- TOWER INTEGRITY: segmented masonry. Lost blocks go dark and show a crack; a block that just
-- broke flashes coral once.
function UiKit.TowerGauge(parent, opts)
	opts = opts or {}
	local segments = opts.segments or 10
	local frame = new("Frame", {
		Name = "TowerGauge",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromOffset(320, 42),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	gaugeCap(frame, 42, "tower", Color.Stone, 24)
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 1, 0) }, frame)
	local label = UiKit.Label(body, "Tower", "Label", { Size = UDim2.new(0.7, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
	local readout = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = 15,
		TextColor3 = Color.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 16),
	}, body)
	UiKit.fitHeader(label, readout)
	local blocksFrame = new("Frame", { Name = "Blocks", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 20) }, body)
	local blocks = {}
	for i = 1, segments do
		local block = UiKit.Inset(blocksFrame, {
			Name = "Block" .. i,
			Position = UDim2.new((i - 1) / segments, 0, 0, 0),
			Size = UDim2.new(1 / segments, -3, 1, 0),
		})
		block:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 2)
		local fill = new("Frame", { Name = "Stone", BackgroundColor3 = Color.Stone, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, block)
		UiKit.round(fill, 2)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(170, 165, 155)) }, fill)
		local crack = new("Frame", { Name = "Crack", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Visible = false }, block)
		new("Frame", {
			BackgroundColor3 = Color.BorderStructural,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.42, 0.34),
			Size = UDim2.new(0, 2, 0.6, 0),
			Rotation = 28,
			ZIndex = 3,
		}, crack)
		new("Frame", {
			BackgroundColor3 = Color.BorderStructural,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.56, 0.72),
			Size = UDim2.new(0, 2, 0.5, 0),
			Rotation = -24,
			ZIndex = 3,
		}, crack)
		blocks[i] = { frame = block, fill = fill, crack = crack, amount = 1 }
	end
	local self = { frame = frame }
	local initialized = false
	function self.set(v)
		v = math.clamp(v or 0, 0, 1)
		for i, b in blocks do
			local amount = math.clamp(v * segments - (i - 1), 0, 1)
			local justBroke = initialized and b.amount > 0 and amount == 0
			b.amount = amount
			b.fill.Size = UDim2.fromScale(amount, 1)
			b.fill.Visible = amount > 0
			b.crack.Visible = amount == 0
			if justBroke then
				b.frame.BackgroundColor3 = Color.StateDanger
				tween(b.frame, 0.45, { BackgroundColor3 = Color.SurfaceInset })
			end
		end
		initialized = true
		readout.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
		local breaching = v < 0.3
		label.Text = if breaching then "TOWER · BREACHING" else "TOWER"
		label.TextColor3 = if breaching then Color.StateDanger else Color.TextSecondary
	end
	self.set(opts.value or 1)
	return self
end

---------------------------------------------------------------------
-- FEEDBACK: notices (top center) and pickups (right edge). Both stay clear of the screen center
-- (aiming), the lower middle (interaction prompts) and menu close buttons (top right).
-- Kinds differ by glyph AND color AND title.
---------------------------------------------------------------------

local NOTICE_KINDS = {
	success = { color = Color.StateSuccess, glyph = "check" },
	good = { color = Color.StateSuccess, glyph = "check" },
	warning = { color = Color.StateWarning, glyph = "warning" },
	danger = { color = Color.StateDanger, glyph = "close" },
	bad = { color = Color.StateDanger, glyph = "close" },
	error = { color = Color.StateDanger, glyph = "close" },
	info = { color = Color.AccentSea, glyph = "info" },
}
UiKit.NOTICE_LIMIT = 3
UiKit.PICKUP_LIMIT = 4

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function trim(stack, limit)
	local items = {}
	for _, child in stack:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(items, child)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #items >= limit do
		table.remove(items, 1):Destroy()
	end
end

local function fadeOut(frame)
	local scale = frame:FindFirstChild("EnterScale")
	if scale then
		tween(scale, UiKit.Motion.fast, { Scale = 0.94 })
	end
	task.delay(UiKit.Motion.fast, function()
		frame:Destroy()
	end)
end

-- UiKit.Toast(container, "message", "success" | "warning" | "danger" | "info", { title, duration })
-- Gauge/bar headers: the number keeps its full width, the label gets what is left and truncates.
function UiKit.fitHeader(label, readout)
	readout.AutomaticSize = Enum.AutomaticSize.X
	readout.Size = UDim2.new(0, 0, readout.Size.Y.Scale, readout.Size.Y.Offset)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local function fit()
		label.Size = UDim2.new(1, -(readout.AbsoluteSize.X + 6), label.Size.Y.Scale, label.Size.Y.Offset)
	end
	readout:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

function UiKit.Toast(container, message, kind, opts)
	opts = opts or {}
	local style = NOTICE_KINDS[kind or "info"] or NOTICE_KINDS.info
	local stack = container:FindFirstChild("ToastStack")
	if not stack then
		stack = new("Frame", {
			Name = "ToastStack",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 200,
		}, container)
		UiKit.list(stack, "y", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	end
	stack.Size = UDim2.fromOffset(container:GetAttribute("NoticeWidth") or math.clamp(container.AbsoluteSize.X * 0.5, 260, 400), 0)
	stack.Position = UDim2.new(0.5, 0, 0, container:GetAttribute("NoticeTop") or 12)
	trim(stack, container:GetAttribute("NoticeLimit") or UiKit.NOTICE_LIMIT)
	local t = new("Frame", {
		Name = "Toast",
		BackgroundColor3 = Color.SurfaceElevated,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		ZIndex = 200,
	}, stack)
	t:SetAttribute("Kind", kind)
	UiKit.round(t, UiKit.Radius.card)
	UiKit.border(t, style.color, 1, 0.5)
	new("Frame", { Name = "Rule", BackgroundColor3 = style.color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), ZIndex = 201 }, t)
	local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, t)
	UiKit.pad(inner, 10, 14, 10, 16)
	local glyph = UiKit.Glyph(inner, style.glyph, style.color, 16)
	glyph.Position = UDim2.fromOffset(0, 2)
	local column = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, inner)
	UiKit.list(column, "y", 1)
	if opts.title then
		UiKit.Label(column, opts.title, "H3", { LayoutOrder = 1, TextSize = 16 })
	end
	UiKit.Label(column, message, "BodySmall", { LayoutOrder = 2, TextColor3 = Color.TextPrimary })
	local scale = new("UIScale", { Name = "EnterScale", Scale = 0.96 }, t)
	tween(scale, UiKit.Motion.fast, { Scale = 1 })
	task.delay(opts.duration or 3.2, function()
		if t.Parent then
			fadeOut(t)
		end
	end)
	return t
end

-- Loot and currency pickups: small rows on the right edge. The same key merges while visible,
-- so ten crab claws read as one "x10" row. Shells and loot say THIS VOYAGE; Pearls say KEPT.
-- opts: kind "Shells" | "Pearls" | "loot", amount, label (loot name), category, key
function UiKit.Pickup(container, opts)
	local feed = container:FindFirstChild("PickupFeed")
	if not feed then
		feed = new("Frame", {
			Name = "PickupFeed",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0.36, 0),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 190,
		}, container)
		UiKit.list(feed, "y", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	end
	if container:GetAttribute("PickupTop") then
		feed.Position = UDim2.new(1, -16, 0, container:GetAttribute("PickupTop"))
	end
	local kind = opts.kind or "loot"
	local key = opts.key or (kind .. "_" .. tostring(opts.label))
	local amount = opts.amount or 1
	local function amountText(n)
		return if kind == "loot" then "x" .. formatNumber(n) else "+" .. formatNumber(n)
	end
	local existing = feed:FindFirstChild("Pickup_" .. key)
	if existing then
		local total = existing:GetAttribute("Amount") + amount
		existing:SetAttribute("Amount", total)
		existing:SetAttribute("Expire", os.clock() + 2.6)
		existing:FindFirstChild("Amount", true).Text = amountText(total)
		local scale = existing:FindFirstChild("EnterScale")
		scale.Scale = 1.06
		tween(scale, UiKit.Motion.fast, { Scale = 1 })
		return existing
	end
	trim(feed, container:GetAttribute("PickupLimit") or UiKit.PICKUP_LIMIT)
	local accent = if kind == "Shells" then Color.Shell
		elseif kind == "Pearls" then Color.Pearl
		else Color[UiKit.CATEGORY[opts.category or "Materials"] or "CatMaterials"]
	local row = new("Frame", {
		Name = "Pickup_" .. key,
		BackgroundColor3 = Color.SurfaceBase,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromOffset(200, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = nextOrder(),
	}, feed)
	row:SetAttribute("Amount", amount)
	row:SetAttribute("Expire", os.clock() + 2.6)
	UiKit.round(row, UiKit.Radius.card)
	new("Frame", { Name = "Rule", BackgroundColor3 = accent, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) }, row)
	local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, row)
	UiKit.pad(inner, 0, 12, 0, 12)
	UiKit.list(inner, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if kind == "Shells" or kind == "Pearls" then
		UiKit.CurrencyIcon(inner, kind, 18).LayoutOrder = 1
	else
		UiKit.Glyph(inner, "diamond", accent, 14).LayoutOrder = 1
	end
	new("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		FontFace = Fonts.Numeric,
		TextSize = 17,
		TextColor3 = if kind == "Pearls" then Color.Pearl else Color.TextPrimary,
		Text = amountText(amount),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	}, inner)
	new("TextLabel", {
		Name = "What",
		BackgroundTransparency = 1,
		FontFace = Fonts.BodyMedium,
		TextSize = 15,
		TextColor3 = Color.TextPrimary,
		Text = if kind == "loot" then opts.label or "Loot" else kind,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
	}, inner)
	new("TextLabel", {
		Name = "Note",
		BackgroundTransparency = 1,
		FontFace = Fonts.Label,
		TextSize = 13,
		TextColor3 = if kind == "Pearls" then Color.AccentSea else Color.TextMuted,
		Text = if kind == "Pearls" then "KEPT" else "THIS VOYAGE",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 4,
	}, inner)
	local scale = new("UIScale", { Name = "EnterScale", Scale = 0.94 }, row)
	tween(scale, UiKit.Motion.fast, { Scale = 1 })
	task.spawn(function()
		while row.Parent do
			if os.clock() > row:GetAttribute("Expire") then
				fadeOut(row)
				return
			end
			task.wait(0.2)
		end
	end)
	return row
end

---------------------------------------------------------------------
-- DIALOGS
---------------------------------------------------------------------

local function makeScrim(container)
	local scrim = new("TextButton", {
		Name = "DialogScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color.Scrim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 300,
		Selectable = false,
	}, container)
	tween(scrim, UiKit.Motion.base, { BackgroundTransparency = 0.3 })
	return scrim
end

-- A plain confirmation. opts: eyebrow, title, body, confirmText, cancelText, kind "default" | "danger",
-- onConfirm, onCancel. Escape / B cancels.
function UiKit.Dialog(container, opts)
	opts = opts or {}
	local scrim = makeScrim(container)
	local danger = opts.kind == "danger"
	local height = opts.height or 216
	local panel, content = UiKit.Panel(scrim, {
		name = "Dialog",
		kind = "dialog",
		frameColor = if danger then Color.StateDanger else nil,
		eyebrow = opts.eyebrow,
		title = opts.title,
		titleStyle = "H2",
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		size = UDim2.new(0.92, 0, 0, height),
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(470, height) }, panel)
	UiKit.Label(content, opts.body or "", "Body", { TextColor3 = Color.TextSecondary })
	local row = new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
	}, content)
	UiKit.list(row, "x", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	local name = "Dialog" .. tostring(os.clock())
	UiKit.pushModal(name)
	scrim.Destroying:Connect(function()
		UiKit.popModal(name) -- never leave input locked if something else removes the dialog
	end)
	local closed = false
	local connection
	local function close(confirmed)
		if closed then
			return
		end
		closed = true
		if connection then
			connection:Disconnect()
		end
		UiKit.popModal(name)
		GuiService.SelectedObject = nil
		tween(scrim, UiKit.Motion.fast, { BackgroundTransparency = 1 })
		panel.Visible = false
		task.delay(UiKit.Motion.fast, function()
			scrim:Destroy()
		end)
		if confirmed and opts.onConfirm then
			opts.onConfirm()
		elseif not confirmed and opts.onCancel then
			opts.onCancel()
		end
	end
	local cancel = UiKit.Button(row, opts.cancelText or "Cancel", { name = "CancelButton", variant = "secondary", layoutOrder = 1, onClick = function()
		close(false)
	end })
	local confirm = UiKit.Button(row, opts.confirmText or "Confirm", { name = "ConfirmButton", variant = if danger then "danger" else "primary", layoutOrder = 2, onClick = function()
		close(true)
	end })
	connection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			close(false)
		end
	end)
	if usingGamepad() then
		GuiService.SelectedObject = if danger then cancel else confirm
	end
	UiKit.Open(panel)
	return { close = close, confirm = confirm, cancel = cancel, panel = panel }
end

-- An item-specific purchase decision.
-- opts: itemId, name, description, category, effect "gameplay" | "cosmetic", eyebrow,
--       price = { kind = "Pearls", amount }, balance, owned,
--       onPurchase(done)  -> call done(true) or done(false, "what went wrong, in plain words")
-- States: default, insufficient, owned, pending, success, error. Returns { setState, close, ... }.
function UiKit.PurchaseDialog(container, opts)
	local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))
	local phone = UiKit.Breakpoint(container.AbsoluteSize) == "phone"
	local price = opts.price
	local currency = price.kind
	local balance = opts.balance or 0
	local height = math.min(if phone then 300 else 340, container.AbsoluteSize.Y - 24)
	local scrim = makeScrim(container)
	local panel, content = UiKit.Panel(scrim, {
		name = "PurchaseDialog",
		kind = "dialog",
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		size = UDim2.new(0.94, 0, 0, height),
		padding = if phone then 16 else 22,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(if phone then 500 else 548, height) }, panel)

	local wellSize = if phone then 96 else 128
	local well = UiKit.Inset(content, { Name = "Well", BackgroundColor3 = rgb(22, 32, 46), Size = UDim2.fromOffset(wellSize, wellSize), ClipsDescendants = true })
	local preview = ItemPreview.new(well, {})
	preview:setItem(opts.itemId)
	local info = new("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(wellSize + 16, 0),
		Size = UDim2.new(1, -(wellSize + 16), 0, wellSize),
	}, content)
	UiKit.list(info, "y", 5)
	UiKit.Label(info, opts.eyebrow or "Quartermaster", "Eyebrow", { LayoutOrder = 1 })
	UiKit.Label(info, opts.name or "", "H2", { LayoutOrder = 2, TextSize = if phone then 20 else 23 })
	local tags = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 3 }, info)
	UiKit.list(tags, "x", 6)
	if opts.effect == "cosmetic" then
		UiKit.Tag(tags, "Cosmetic only", "CatAmmunition", { layoutOrder = 1 })
	else
		UiKit.Tag(tags, "Affects gameplay", "AccentSea", { layoutOrder = 1 })
	end
	if opts.category then
		UiKit.Tag(tags, opts.category, UiKit.CATEGORY[opts.category] or "AccentSea", { layoutOrder = 2 })
	end
	if opts.description then
		UiKit.Label(info, opts.description, "BodySmall", { LayoutOrder = 4, TextTruncate = Enum.TextTruncate.AtEnd, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, if phone then 18 else 38) })
	end

	-- the ledger: price, balance, balance after
	local areaTop = wellSize + 12
	local ledger = UiKit.Inset(content, { Name = "Ledger", Position = UDim2.fromOffset(0, areaTop), Size = UDim2.new(1, 0, 0, 84) })
	UiKit.pad(ledger, 8, 14, 8, 14)
	UiKit.list(ledger, "y", 2)
	local function ledgerRow(labelText, layoutOrder)
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = layoutOrder }, ledger)
		UiKit.Label(r, labelText, "BodySmall", { Size = UDim2.new(0.5, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })
		local value = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X }, r)
		UiKit.list(value, "x", 6, { VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Right })
		return value
	end
	UiKit.Currency(ledgerRow("Price", 1), currency, price.amount, { plain = true, textSize = 17 })
	local balanceDisplay = UiKit.Currency(ledgerRow("Your " .. currency, 2), currency, balance, { plain = true, textSize = 17 })
	local afterSlot = ledgerRow("After purchase", 3)
	local afterDisplay = UiKit.Currency(afterSlot, currency, math.max(0, balance - price.amount), { plain = true, textSize = 17 })
	local shortLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Fonts.BodyBold,
		TextSize = 15,
		TextColor3 = Color.StateDanger,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		LayoutOrder = 0,
	}, afterSlot)

	-- the status strip replaces the ledger after a result
	local status = UiKit.Inset(content, { Name = "Status", Position = UDim2.fromOffset(0, areaTop), Size = UDim2.new(1, 0, 0, 84), Visible = false })
	UiKit.pad(status, 10, 14, 10, 14)
	local statusGlyphHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22) }, status)
	local statusText = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 1, 0) }, status)
	UiKit.list(statusText, "y", 2)
	local statusTitle = UiKit.Label(statusText, "", "H3", { LayoutOrder = 1 })
	local statusBody = UiKit.Label(statusText, "", "BodySmall", { LayoutOrder = 2 })

	local actions = new("Frame", { Name = "Actions", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 48) }, content)
	UiKit.list(actions, "x", 10, { HorizontalAlignment = Enum.HorizontalAlignment.Right })

	local api = { panel = panel, state = nil }
	local modalName = "Purchase" .. tostring(os.clock())
	UiKit.pushModal(modalName)
	scrim.Destroying:Connect(function()
		UiKit.popModal(modalName)
	end)
	local closed = false
	local connection
	local cancel, primary

	local function close(bought)
		if closed or api.state == "pending" then
			return
		end
		closed = true
		connection:Disconnect()
		UiKit.popModal(modalName)
		GuiService.SelectedObject = nil
		tween(scrim, UiKit.Motion.fast, { BackgroundTransparency = 1 })
		panel.Visible = false
		task.delay(UiKit.Motion.fast, function()
			scrim:Destroy()
		end)
		if opts.onClose then
			opts.onClose(bought == true)
		end
	end
	api.close = close

	local function showStatus(kind, title, body)
		ledger.Visible = false
		status.Visible = true
		statusGlyphHolder:ClearAllChildren()
		local style = NOTICE_KINDS[kind]
		UiKit.Glyph(statusGlyphHolder, style.glyph, style.color, 20)
		statusTitle.Text = title
		statusTitle.TextColor3 = style.color
		statusBody.Text = body
	end

	function api.setState(state, message)
		api.state = state
		-- keep the main button's width steady while its label changes (no jumping layout)
		if primary.AbsoluteSize.X > 0 then
			primary.Size = UDim2.fromOffset(math.max(primary.AbsoluteSize.X, 150), primary.Size.Y.Offset)
		end
		UiKit.SetBusy(primary, false)
		UiKit.SetDisabled(primary, false)
		UiKit.SetDisabled(cancel, false)
		cancel.Visible = true
		cancel.Text = "CANCEL"
		ledger.Visible = true
		status.Visible = false
		shortLabel.Visible = false
		afterDisplay.frame.Visible = true
		local buyText = string.format("Buy for %s %s", formatNumber(price.amount), currency)
		primary.Text = string.upper(buyText)
		primary:SetAttribute("BaseText", primary.Text)
		if state == "insufficient" then
			local short = price.amount - balance
			UiKit.SetDisabled(primary, true, string.format("You need %s more %s. Earn them by surviving nights.", formatNumber(short), currency))
			primary.Text = string.upper(string.format("Need %s more", formatNumber(short)))
			afterDisplay.frame.Visible = false
			shortLabel.Visible = true
			shortLabel.Text = string.format("Short by %s", formatNumber(short))
		elseif state == "owned" then
			UiKit.SetDisabled(primary, true, "You already own this. Find it in your BAG.")
			primary.Text = "ALREADY OWNED"
		elseif state == "pending" then
			UiKit.SetBusy(primary, true, "Buying...")
			UiKit.SetDisabled(cancel, true)
		elseif state == "success" then
			balanceDisplay.set(balance - price.amount)
			showStatus("success", "Bought", string.format("%s %s You have %s %s left.", opts.name or "The item", opts.successText or "is in your bag. Equip it from the BAG.", formatNumber(balance - price.amount), currency))
			cancel.Visible = false
			primary.Text = "DONE"
		elseif state == "error" then
			showStatus("error", "Purchase didn't go through", message or "Nothing was spent. Try again in a moment.")
			cancel.Text = "CLOSE"
			primary.Text = "TRY AGAIN"
		end
		if usingGamepad() then
			GuiService.SelectedObject = if primary:GetAttribute("Disabled") or state == "pending" then cancel else primary
		end
	end

	cancel = UiKit.Button(actions, "Cancel", { name = "CancelButton", variant = "secondary", layoutOrder = 1, onClick = function()
		close(false)
	end })
	primary = UiKit.Button(actions, "Buy", { name = "PrimaryButton", variant = "primary", minWidth = 150, layoutOrder = 2, onClick = function()
		if api.state == "success" then
			close(true)
		elseif api.state == "default" or api.state == "error" then
			api.setState("pending")
			if opts.onPurchase then
				opts.onPurchase(function(ok, why)
					if closed then
						return
					end
					if ok then
						api.setState("success")
					else
						api.setState("error", why)
					end
				end)
			end
		end
	end })
	api.cancel = cancel
	api.primary = primary

	connection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			close(api.state == "success")
		end
	end)

	if opts.owned then
		api.setState("owned")
	elseif balance < price.amount then
		api.setState("insufficient")
	else
		api.setState("default")
	end
	UiKit.Open(panel)
	return api
end

-- Designed states instead of blank space. kind: loading | empty | error | success | offline
function UiKit.StateView(parent, kind, opts)
	opts = opts or {}
	local frame = new("Frame", {
		Name = "State_" .. kind,
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromScale(1, 1),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	local column = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, frame)
	UiKit.list(column, "y", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local color = ({
		loading = Color.AccentLighthouse,
		empty = Color.AccentSea,
		error = Color.StateDanger,
		success = Color.StateSuccess,
		offline = Color.StateWarning,
	})[kind] or Color.AccentSea
	local ring = new("Frame", { Name = "Emblem", BackgroundTransparency = 1, Size = UDim2.fromOffset(48, 48), LayoutOrder = 1 }, column)
	UiKit.round(ring, 24)
	UiKit.border(ring, color, 2, if kind == "empty" then 0.45 else 0)
	if kind == "loading" then
		local lamp = new("Frame", {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			ZIndex = 2,
		}, ring)
		UiKit.round(lamp, 5)
		local spinner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, ring)
		local beam = new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0.5, -2),
			Size = UDim2.new(0.5, -4, 0, 4),
		}, spinner)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, beam)
		local connection = RunService.RenderStepped:Connect(function(dt)
			if frame.Parent and frame.Visible then
				spinner.Rotation = (spinner.Rotation + dt * 160) % 360
			end
		end)
		frame.Destroying:Connect(function()
			connection:Disconnect()
		end)
	else
		local glyphKind = ({ empty = "diamond", error = "close", success = "check", offline = "warning" })[kind] or "diamond"
		local g = UiKit.Glyph(ring, glyphKind, color, if glyphKind == "diamond" then 14 else 18)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
	end
	if opts.title then
		UiKit.Label(column, opts.title, "H3", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center })
	end
	if opts.body then
		UiKit.Label(column, opts.body, "BodySmall", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Center })
	end
	if opts.actionText then
		UiKit.Button(column, opts.actionText, { variant = "secondary", size = "sm", layoutOrder = 4, onClick = opts.onAction })
	end
	return frame
end

---------------------------------------------------------------------
-- MOTION: small rise + settle on open, quick dip on close. Nothing loops or floats.
---------------------------------------------------------------------

function UiKit.Open(frame)
	local rest = frame:GetAttribute("RestPosition")
	if not rest then
		rest = frame.Position
		frame:SetAttribute("RestPosition", rest)
	end
	frame.Visible = true
	local scale = frame:FindFirstChild("OpenScale") or new("UIScale", { Name = "OpenScale" }, frame)
	scale.Scale = 0.97
	frame.Position = rest + UDim2.fromOffset(0, 10)
	tween(scale, UiKit.Motion.base, { Scale = 1 })
	tween(frame, UiKit.Motion.base, { Position = rest })
end

function UiKit.Close(frame, onDone)
	local rest = frame:GetAttribute("RestPosition") or frame.Position
	local scale = frame:FindFirstChild("OpenScale") or new("UIScale", { Name = "OpenScale" }, frame)
	tween(scale, UiKit.Motion.fast, { Scale = 0.98 })
	task.delay(UiKit.Motion.fast, function()
		frame.Visible = false
		frame.Position = rest
		scale.Scale = 1
		if onDone then
			onDone()
		end
	end)
end

-- WCAG contrast ratio between two colors (used by the style guide's contrast check)
function UiKit.contrast(a, b)
	local function lum(c)
		local function ch(v)
			return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
	end
	local l1, l2 = lum(a), lum(b)
	if l1 < l2 then
		l1, l2 = l2, l1
	end
	return (l1 + 0.05) / (l2 + 0.05)
end

---------------------------------------------------------------------
-- v1 API (legacy). Kept unchanged for the current Shop and Inventory. Do not use in new code.
---------------------------------------------------------------------

UiKit.THEME = {
	bg = Color3.fromRGB(12, 17, 27),
	panel = Color3.fromRGB(18, 25, 38),
	surface = Color3.fromRGB(28, 38, 56),
	surfaceHi = Color3.fromRGB(38, 51, 74),
	stroke = Color3.fromRGB(62, 78, 104),
	gold = Color3.fromRGB(245, 196, 92),
	goldDark = Color3.fromRGB(196, 140, 48),
	text = Color3.fromRGB(240, 242, 248),
	muted = Color3.fromRGB(160, 172, 192),
	good = Color3.fromRGB(96, 200, 120),
	bad = Color3.fromRGB(226, 84, 70),
	pearl = Color3.fromRGB(225, 215, 255),
	dark = Color3.fromRGB(25, 20, 10),
}

UiKit.CATEGORY_COLORS = {
	Weapons = Color3.fromRGB(232, 128, 72),
	Armor = Color3.fromRGB(96, 156, 236),
	Ammunition = Color3.fromRGB(206, 170, 96),
	Materials = Color3.fromRGB(130, 196, 160),
}

UiKit.MIN_TOUCH = 44

function UiKit.make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

function UiKit.corner(parent, radius)
	return UiKit.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function UiKit.stroke(parent, color, thickness)
	return UiKit.make("UIStroke", {
		Color = color or UiKit.THEME.stroke,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UiKit.text(parent, value, props)
	local label = UiKit.make("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = UiKit.THEME.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
	}, parent)
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

function UiKit.button(parent, value, style, props)
	local T = UiKit.THEME
	local colors = {
		primary = { T.gold, T.dark },
		secondary = { T.surfaceHi, T.text },
		danger = { T.bad, T.text },
		good = { T.good, T.dark },
	}
	local c = colors[style or "secondary"]
	local b = UiKit.make("TextButton", {
		BackgroundColor3 = c[1],
		TextColor3 = c[2],
		Text = value,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(140, UiKit.MIN_TOUCH),
		Selectable = true,
	}, parent)
	UiKit.corner(b, 10)
	for key, value in props or {} do
		b[key] = value
	end
	b:SetAttribute("BaseColor", c[1])
	b:SetAttribute("BaseTextColor", c[2])
	return b
end

function UiKit.setEnabled(b, enabled)
	b.AutoButtonColor = enabled
	b.Active = enabled
	b.BackgroundColor3 = if enabled then b:GetAttribute("BaseColor") else Color3.fromRGB(64, 70, 84)
	b.TextColor3 = if enabled then b:GetAttribute("BaseTextColor") else UiKit.THEME.muted
	b:SetAttribute("Disabled", not enabled)
end

function UiKit.tag(parent, value, color, props)
	local t = UiKit.make("TextLabel", {
		BackgroundColor3 = color,
		Text = string.upper(value),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(18, 18, 24),
		Size = UDim2.fromOffset(84, 18),
		AutomaticSize = Enum.AutomaticSize.X,
	}, parent)
	UiKit.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, t)
	UiKit.corner(t, 6)
	for key, value in props or {} do
		t[key] = value
	end
	return t
end

function UiKit.toast(parent, message, kind)
	local T = UiKit.THEME
	local old = parent:FindFirstChild("Toast")
	if old then
		old:Destroy()
	end
	local color = if kind == "good" then T.good elseif kind == "bad" then T.bad else T.surfaceHi
	local toast = UiKit.make("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.9, 0, 0, 40),
		BackgroundColor3 = color,
		Text = message,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = if kind == "info" then T.text else T.dark,
		TextWrapped = true,
		ZIndex = 50,
	}, parent)
	UiKit.corner(toast, 10)
	task.delay(3, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
	return toast
end

function UiKit.layoutFor(viewportSize, designWidth, designHeight)
	local phone = viewportSize.X < 760 or viewportSize.Y < 420
	if phone then
		return 1, true
	end
	return math.clamp(math.min(viewportSize.X / designWidth, viewportSize.Y / designHeight), 0.6, 1), false
end

UiSkin.install(UiKit) -- wraps Panel / Button / IconButton / ItemCard when the skin is on

return UiKit
