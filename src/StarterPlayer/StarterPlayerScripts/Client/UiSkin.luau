-- UiSkin (client): optional art skin drawn on top of UiKit, switched by Config.UI_SKIN.
-- "pirate" = Kenney UI Pack RPG Expansion (CC0, kenney.nl): wood panels, parchment wells, wooden buttons.
-- One atlas image (Config.UI_SKIN_ATLAS) holds every piece at 2x; pieces are 9-sliced.
-- Layouts are untouched: the art is a background ImageLabel (ZIndex -5) and button text is mirrored
-- into a label above it. Set UI_SKIN = false to return to the original lighthouse look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiSkin = {}

local Config = {}
do
	local ok, mod = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	end)
	if ok and type(mod) == "table" then
		Config = mod
	end
end

local ATLAS = Config.UI_SKIN_ATLAS
UiSkin.enabled = Config.UI_SKIN == "pirate"
UiSkin.images = UiSkin.enabled and type(ATLAS) == "string" and ATLAS:match("%d%d%d%d+") ~= nil

-- x, y, w, h, slice corner (atlas pixels; 0 = not sliced)
local R = {
	panel = { 0, 0, 76, 76, 36 },
	parchment = { 80, 0, 68, 68, 32 },
	parchmentLight = { 152, 0, 68, 68, 32 },
	slot = { 224, 0, 68, 68, 32 },
	panelLight = { 296, 0, 76, 76, 36 },
	btnBeige = { 376, 0, 64, 64, 30 },
	btnBeigeDown = { 444, 0, 56, 56, 26 },
	btnBrown = { 0, 80, 64, 64, 30 },
	btnBrownDown = { 68, 80, 56, 56, 26 },
	btnGrey = { 128, 80, 64, 64, 30 },
	btnGreyDown = { 196, 80, 56, 56, 26 },
	round = { 256, 80, 70, 76, 0 },
	cross = { 330, 80, 32, 30, 0 },
	check = { 366, 80, 32, 30, 0 },
	barBack = { 402, 80, 72, 36, 17 },
	barYellow = { 0, 160, 72, 36, 17 },
	barRed = { 76, 160, 72, 36, 17 },
	barGreen = { 152, 160, 72, 36, 17 },
	barBlue = { 228, 160, 72, 36, 17 },
}
UiSkin.Rects = R

-- Bigger = chunkier frame edges (atlas is 2x, so 0.5 = the pack's native size)
local MAX_SCALE = {
	panel = 0.85,
	panelLight = 0.85,
	slot = 0.6,
	parchment = 0.6,
	parchmentLight = 0.6,
	btnBeige = 0.55,
	btnBeigeDown = 0.55,
	btnBrown = 0.55,
	btnBrownDown = 0.55,
	btnGrey = 0.55,
	btnGreyDown = 0.55,
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Warm the shared colour tokens (runs before any UI is built). Fonts: cartoon display face.
function UiSkin.remap(Color, Fonts)
	if not UiSkin.enabled then
		return
	end
	Color.SurfaceBase = rgb(24, 16, 11)
	Color.SurfacePrimary = rgb(48, 33, 23)
	Color.SurfaceSecondary = rgb(66, 46, 32)
	Color.SurfaceElevated = rgb(88, 62, 42)
	Color.SurfaceHover = rgb(108, 77, 52)
	Color.SurfaceInset = rgb(34, 24, 17)
	Color.BorderSubtle = rgb(100, 76, 52)
	Color.StateDisabled = rgb(78, 68, 60)
	Color.StateDisabledText = rgb(184, 176, 164)
	pcall(function()
		-- Fredoka One: chunky and playful, with real lowercase (Luckiest Guy mangled mixed-case headlines)
		Fonts.Display = Font.fromEnum(Enum.Font.FredokaOne)
	end)
end

local function setPiece(img, name)
	local r = R[name]
	img.ImageRectOffset = Vector2.new(r[1], r[2])
	img.ImageRectSize = Vector2.new(r[3], r[4])
	local c = r[5]
	if c > 0 then
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = Rect.new(c, c, r[3] - c, r[4] - c)
	else
		img.ScaleType = Enum.ScaleType.Fit
	end
	img:SetAttribute("SkinC", c)
	img:SetAttribute("SkinPiece", name)
end

local function fitScale(img)
	local c = img:GetAttribute("SkinC") or 0
	if c <= 0 then
		return
	end
	local s = img.AbsoluteSize
	local m = math.min(s.X, s.Y)
	if m <= 0 then
		return
	end
	local maxScale = MAX_SCALE[img:GetAttribute("SkinPiece")] or 0.5
	img.SliceScale = math.clamp(m / (2 * c + 2), 0.1, maxScale)
end

-- Draw a piece behind host's content. Returns the ImageLabel (or nil when images are off).
function UiSkin.attach(host, name, tint)
	if not UiSkin.images or not host or host:FindFirstChild("Skin") then
		return nil
	end
	if host:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return nil -- a layout would move the art; keep the plain background
	end
	local pad = host:FindFirstChildOfClass("UIPadding")
	local l = if pad then pad.PaddingLeft.Offset else 0
	local r = if pad then pad.PaddingRight.Offset else 0
	local t = if pad then pad.PaddingTop.Offset else 0
	local b = if pad then pad.PaddingBottom.Offset else 0
	local img = Instance.new("ImageLabel")
	img.Name = "Skin"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = ATLAS
	img.Size = UDim2.new(1, l + r, 1, t + b)
	img.Position = UDim2.fromOffset(-l, -t)
	img.ZIndex = -5
	img.ImageColor3 = tint or Color3.new(1, 1, 1)
	setPiece(img, name)
	img:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitScale(img)
	end)
	img.Parent = host
	fitScale(img)
	host.BackgroundTransparency = 1
	local stroke = host:FindFirstChildOfClass("UIStroke")
	if stroke and not host:GetAttribute("SkinKeepStroke") then
		stroke.Enabled = false
	end
	local grad = host:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Enabled = false
	end
	-- If a layout is added later, the art would be laid out with the content: remove it
	host.ChildAdded:Connect(function(child)
		if child:IsA("UIGridStyleLayout") and img.Parent then
			img:Destroy()
		end
	end)
	return img
end

function UiSkin.setPiece(img, name)
	if img then
		setPiece(img, name)
		fitScale(img)
	end
end

-- Button text drawn above the art; the host keeps its (invisible) text so AutomaticSize still works
local function mirrorText(host, colorFn)
	local t = Instance.new("TextLabel")
	t.Name = "SkinText"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Position = UDim2.fromOffset(0, -2)
	t.ZIndex = 2
	local function sync()
		t.Text = host.Text
		t.FontFace = host.FontFace
		t.TextSize = host.TextSize
		t.TextColor3 = colorFn(host.TextColor3)
		t.TextXAlignment = host.TextXAlignment
		t.TextYAlignment = host.TextYAlignment
		t.TextScaled = host.TextScaled
		t.TextWrapped = host.TextWrapped
		t.RichText = host.RichText
		t.TextTruncate = host.TextTruncate
	end
	for _, p in { "Text", "FontFace", "TextSize", "TextColor3", "TextXAlignment", "TextScaled", "TextWrapped", "RichText" } do
		host:GetPropertyChangedSignal(p):Connect(sync)
	end
	sync()
	t.Parent = host
	host.TextTransparency = 1
	return t, sync
end

local BUTTON = {
	primary = { piece = "btnBeige", down = "btnBeigeDown", base = rgb(255, 206, 112), hover = rgb(255, 228, 156) },
	secondary = { piece = "btnBrown", down = "btnBrownDown", base = rgb(222, 222, 222), hover = rgb(255, 255, 255) },
	danger = { piece = "btnGrey", down = "btnGreyDown", base = rgb(190, 84, 70), hover = rgb(214, 102, 86), text = "TextPrimary" },
}
local DISABLED = { piece = "btnGrey", down = "btnGreyDown", base = rgb(104, 94, 86) }

function UiSkin.skinButton(b, Color)
	local spec = BUTTON[b:GetAttribute("Variant") or "secondary"]
	if not spec then
		return -- ghost buttons stay text-only
	end
	local img = UiSkin.attach(b, spec.piece, spec.base)
	if not img then
		return
	end
	local function current()
		return if b:GetAttribute("Disabled") then DISABLED else spec
	end
	local _, sync = mirrorText(b, function(c)
		if b:GetAttribute("Disabled") then
			return Color.StateDisabledText
		end
		if spec.text then
			return Color[spec.text]
		end
		return c
	end)
	local hovered = false
	local function refresh(down)
		local s = current()
		setPiece(img, if down then s.down else s.piece)
		fitScale(img)
		img.ImageColor3 = if hovered and s.hover then s.hover else s.base
		sync()
	end
	b:GetAttributeChangedSignal("Disabled"):Connect(function()
		refresh(false)
	end)
	b.MouseEnter:Connect(function()
		hovered = true
		refresh(false)
	end)
	b.MouseLeave:Connect(function()
		hovered = false
		refresh(false)
	end)
	b.MouseButton1Down:Connect(function()
		refresh(true)
	end)
	b.MouseButton1Up:Connect(function()
		refresh(false)
	end)
	refresh(false)
end

local HIDE = { Brackets = true, Beacon = true, Tick = true, LensArc = true, Lamp = true }

-- Wrap UiKit constructors (called once, at the end of UiKit)
function UiSkin.install(UiKit)
	if not UiSkin.images then
		return
	end
	local Color = UiKit.Color

	local Panel = UiKit.Panel
	UiKit.Panel = function(parent, opts)
		local panel, content, header = Panel(parent, opts)
		local kind = panel:GetAttribute("PanelKind")
		if kind == "plain" then
			UiSkin.attach(panel, "slot", rgb(176, 176, 176))
		else
			UiSkin.attach(panel, "panel", rgb(168, 168, 168))
			for _, child in panel:GetChildren() do
				if HIDE[child.Name] then
					child.Visible = false
				end
			end
		end
		return panel, content, header
	end

	local Button = UiKit.Button
	UiKit.Button = function(parent, text, opts)
		local b = Button(parent, text, opts)
		UiSkin.skinButton(b, Color)
		return b
	end

	local IconButton = UiKit.IconButton
	UiKit.IconButton = function(parent, glyph, opts)
		local b = IconButton(parent, glyph, opts)
		if glyph == "close" then
			local img = UiSkin.attach(b, "round", rgb(220, 220, 220))
			if img then
				img.Size = UDim2.fromOffset(36, 36)
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.5, 0.5)
			end
		elseif not (opts and opts.quiet) then
			UiSkin.attach(b, "btnBrown", rgb(200, 200, 200))
		end
		return b
	end

	local ItemCard = UiKit.ItemCard
	UiKit.ItemCard = function(parent, opts)
		local self = ItemCard(parent, opts)
		local card = type(self) == "table" and self.frame
		if typeof(card) == "Instance" then
			card:SetAttribute("SkinKeepStroke", true) -- selection outline
			UiSkin.attach(card, "slot", rgb(214, 214, 214))
			local well = card:FindFirstChild("Well")
			if well then
				UiSkin.attach(well, "parchment", rgb(236, 230, 220))
				local lip = well:FindFirstChild("Lip")
				if lip then
					lip.Visible = false
				end
			end
		end
		return self
	end
end

return UiSkin
