-- Menus (client): title screen, How to Play, Settings.  UI Stage 8 "storm-forged" redesign.
--
-- Flow: join -> title (lighthouse streamed in, slow low camera drift, storm grade) -> Play -> harbor.
-- While the title or its panels are open the UiKit modal "Title" is pushed (MenuOpen = true),
-- character controls, touch controls and the Roblox hotbar are off, so no gameplay input fires
-- behind the menu. Play fires Remotes.EnterLobby exactly as before.
--
-- Settings: only controls that work (SFX volume, storm/waves volume, low effects). They last for
-- this session; saving them needs a new save field, which is frozen during the UI work.
-- Studio only: player attribute HudSimulate draws it inside a simulated screen size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local C, F = UiKit.Color, UiKit.Font
local new, tween = UiKit.new, UiKit.tween

local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local LIGHTHOUSE = Vector3.new(0, 35, 0)
local LOOK_AT = Vector3.new(0, 40, 0)
local ECONOMY = Config.ECONOMY_ENABLED == true

local function inputMode()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif UiKit.usingGamepad() then
		return "gamepad"
	end
	return "keyboard"
end

local function focus(obj)
	if obj and UiKit.usingGamepad() then
		GuiService.SelectedObject = obj
	end
end

local function spacer(parent, height, order)
	return new("Frame", { Name = "Gap", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order }, parent)
end

local function setDisabled(button, disabled)
	pcall(UiKit.SetDisabled, button, disabled)
end

local function setButtonText(button, text)
	button.Text = string.upper(text)
	button:SetAttribute("BaseText", button.Text)
end

---------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------

local gui = UiKit.Screen("Menus", 10, true)
gui.IgnoreGuiInset = true
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)

---------------------------------------------------------------------
-- TITLE: the lighthouse is the image; the brand column sits in the dark on the left
---------------------------------------------------------------------

local title = new("Frame", { Name = "Title", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)

local shade = new("Frame", { Name = "Shade", BackgroundColor3 = C.SurfaceBase, BorderSizePixel = 0, Size = UDim2.fromScale(0.72, 1) }, title)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.42),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, shade)
local floor = new("Frame", {
	Name = "Floor",
	BackgroundColor3 = C.SurfaceBase,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0.3),
}, title)
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) }),
}, floor)

local brand = new("Frame", {
	Name = "Brand",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.07, 0.52),
	Size = UDim2.fromOffset(600, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, title)
UiKit.list(brand, "y", 0)

local eyebrowRow = new("Frame", { Name = "EyebrowRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 }, brand)
UiKit.list(eyebrowRow, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
UiKit.Glyph(eyebrowRow, "lamp", C.AccentLighthouse, 18).LayoutOrder = 1
UiKit.Label(eyebrowRow, "Co-op storm survival  ·  1–4 keepers", "Eyebrow", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X,
	TextWrapped = false,
	TextYAlignment = Enum.TextYAlignment.Center,
})
local eyebrowGap = spacer(brand, 6, 2)

local function wordLine(text, color, order)
	local label = new("TextLabel", {
		Name = "Word" .. order,
		BackgroundTransparency = 1,
		FontFace = F.Display,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 88),
		LayoutOrder = order,
	}, brand)
	new("UITextSizeConstraint", { MaxTextSize = 84, MinTextSize = 24 }, label)
	new("UIStroke", { Color = C.SurfaceBase, Thickness = 1.5, Transparency = 0.35 }, label)
	return label
end
local word1 = wordLine("LIGHTHOUSE", C.TextPrimary, 3)
local word2 = wordLine("KEEPERS", C.AccentLighthouse, 4)

-- the beam: a warm rule that fades out to the right, starting at a small lamp diamond
local beamRow = new("Frame", { Name = "BeamRule", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 5 }, brand)
local beam = new("Frame", {
	Name = "Beam",
	BackgroundColor3 = C.AccentLighthouse,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.new(0.8, 0, 0, 2),
}, beamRow)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, beam)
new("Frame", {
	Name = "Lamp",
	BackgroundColor3 = C.AccentLighthouseSoft,
	BorderSizePixel = 0,
	Rotation = 45,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 5, 0.5, 0),
	Size = UDim2.fromOffset(9, 9),
}, beamRow)

local tagline = UiKit.Label(brand, "Keep the light alive through the storm. Together.", "Body", {
	Name = "Tagline",
	LayoutOrder = 6,
	FontFace = F.BodyMedium,
	TextSize = 19,
	TextColor3 = C.TextSecondary,
})
local actionsGap = spacer(brand, 28, 7)

local actions = new("Frame", {
	Name = "Actions",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 340, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 8,
}, brand)
UiKit.list(actions, "y", 10)
local playButton = UiKit.Button(actions, "Play", { name = "PlayButton", variant = "primary", size = "lg", fill = true, layoutOrder = 1 })
local secondaryRow = new("Frame", { Name = "Secondary", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 2 }, actions)
UiKit.list(secondaryRow, "x", 10)
local howButton = UiKit.Button(secondaryRow, "How to Play", { name = "HowButton", variant = "secondary", width = 165, layoutOrder = 1 })
local settingsButton = UiKit.Button(secondaryRow, "Settings", { name = "SettingsButton", variant = "secondary", width = 165, layoutOrder = 2 })

local noteGap = spacer(brand, 14, 9)
local note = new("Frame", {
	Name = "VoyageNote",
	BackgroundColor3 = C.SurfacePrimary,
	BackgroundTransparency = 0.15,
	Size = UDim2.new(0, 340, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 10,
	Visible = false,
}, brand)
UiKit.round(note, UiKit.Radius.card)
UiKit.border(note, C.AccentSeaDeep, 1, 0.1)
new("Frame", { Name = "Stripe", BackgroundColor3 = C.AccentSea, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) }, note)
local noteText = UiKit.Label(note, "", "BodySmall", { Name = "Text", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -24, 0, 0) })
UiKit.pad(noteText, 9, 0, 9, 0)

local buildText = if game.PlaceVersion > 0
	then string.format("Private prototype  ·  build %d", game.PlaceVersion)
	else "Private prototype  ·  Studio build"
local buildLabel = UiKit.Label(title, buildText, "Caption", {
	Name = "Build",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -18),
	Size = UDim2.fromOffset(0, 18),
	AutomaticSize = Enum.AutomaticSize.X,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- loading cover: hides the unstreamed (white) world until the lighthouse exists on this client
local cover = new("Frame", { Name = "Cover", BackgroundColor3 = C.SurfaceBase, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 50 }, root)
local coverRow = new("Frame", {
	Name = "Loading",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 51,
}, cover)
UiKit.list(coverRow, "x", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
local coverGlyph = UiKit.Glyph(coverRow, "lamp", C.AccentLighthouse, 18)
coverGlyph.LayoutOrder = 1
local coverText = UiKit.Label(coverRow, "Lighting the lamp…", "Caption", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	TextWrapped = false,
	TextYAlignment = Enum.TextYAlignment.Center,
})
for _, d in coverRow:GetDescendants() do
	if d:IsA("GuiObject") then
		d.ZIndex = 51
	end
end

---------------------------------------------------------------------
-- Title camera: stream the lighthouse in, drift low around it, cool storm grade
---------------------------------------------------------------------

local cameraConnection
local orbitAngle = math.rad(205)
local framingDegrees = 16
local grade
local savedFov

local function startCamera()
	if cameraConnection then
		return
	end
	savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 55
	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		orbitAngle += dt * 0.028
		local position = Vector3.new(math.cos(orbitAngle) * 82, 22, math.sin(orbitAngle) * 82)
		camera.CFrame = CFrame.lookAt(position, LOOK_AT) * CFrame.Angles(0, math.rad(framingDegrees), 0)
	end)
	if not grade then
		grade = new("ColorCorrectionEffect", {
			Name = "TitleGrade",
			Brightness = -0.07,
			Contrast = 0.14,
			Saturation = -0.32,
			TintColor = Color3.fromRGB(196, 208, 230),
		}, Lighting)
	end
end

local function stopCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	if grade then
		grade:Destroy()
		grade = nil
	end
	-- hand over from behind the character, not from the title camera's angle
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local look = rootPart.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(rootPart.Position - look * 12 + Vector3.new(0, 4, 0), rootPart.Position + Vector3.new(0, 1.5, 0))
	end
	camera.CameraType = Enum.CameraType.Custom
	if savedFov then
		camera.FieldOfView = savedFov
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

---------------------------------------------------------------------
-- Input blocking while the title is up
---------------------------------------------------------------------

local blocking = false
local controls
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local module = scripts and scripts:WaitForChild("PlayerModule", 10)
	if module then
		local ok, playerModule = pcall(require, module)
		if ok and playerModule then
			controls = playerModule:GetControls()
			if blocking then
				controls:Disable()
			end
		end
	end
end)

-- The engine's built-in controls have no PlayerModule here, so the character is held still locally
-- while the title is up (the client simulates its own character). Restored on Play.
local function holdStill(on)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if on and humanoid:GetAttribute("TitleWalkSpeed") == nil then
		humanoid:SetAttribute("TitleWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("TitleJumpPower", humanoid.JumpPower)
		humanoid:SetAttribute("TitleJumpHeight", humanoid.JumpHeight)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	elseif not on and humanoid:GetAttribute("TitleWalkSpeed") ~= nil then
		humanoid.WalkSpeed = humanoid:GetAttribute("TitleWalkSpeed")
		humanoid.JumpPower = humanoid:GetAttribute("TitleJumpPower")
		humanoid.JumpHeight = humanoid:GetAttribute("TitleJumpHeight")
		humanoid:SetAttribute("TitleWalkSpeed", nil)
		humanoid:SetAttribute("TitleJumpPower", nil)
		humanoid:SetAttribute("TitleJumpHeight", nil)
	end
end
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid", 5)
	holdStill(blocking)
end)

local function setBlocking(on)
	if blocking == on then
		return
	end
	blocking = on
	if on then
		UiKit.pushModal("Title")
	else
		UiKit.popModal("Title")
	end
	-- the HUD's own weapon slot replaces Roblox's hotbar (OwnWeaponSlot, Oct 13)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, (not on) and not game:GetService("Players").LocalPlayer:GetAttribute("OwnWeaponSlot"))
	holdStill(on)
	if controls then
		if on then
			controls:Disable()
		else
			controls:Enable()
		end
	end
end

---------------------------------------------------------------------
-- PANELS (How to Play, Settings) share one scrim
---------------------------------------------------------------------

local panels = new("Frame", { Name = "Panels", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10 }, root)
local scrim = new("TextButton", {
	Name = "Scrim",
	Text = "",
	AutoButtonColor = false,
	Selectable = false,
	BackgroundColor3 = C.Scrim,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
}, panels)

local current = "title" -- "title" | "how" | "settings" | "gone"
local closePanel -- forward declared

local function panelHeader(content, eyebrowText, titleText, name)
	local header = new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, -56, 0, 48) }, content)
	UiKit.list(header, "y", 2)
	local eyebrow = UiKit.Label(header, eyebrowText, "Eyebrow", { LayoutOrder = 1 })
	local heading = UiKit.Label(header, titleText, "H2", { LayoutOrder = 2 })
	local close = UiKit.IconButton(content, "close", { name = name, quiet = true })
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 6, 0, -6)
	close.ZIndex = 5
	close.Activated:Connect(function()
		closePanel()
	end)
	return header, eyebrow, heading, close
end

---------------------------------------------------------------------
-- HOW TO PLAY: illustrated steps, one or two lines each, live input hints
---------------------------------------------------------------------

local KEY_X = Enum.KeyCode.ButtonX

-- drawing helpers (positions and sizes in fractions of the square art well)
local function bar(p, x, y, w, h, color, rotation, transparency, anchor)
	return new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = rotation or 0,
	}, p)
end
local function dot(p, x, y, d, color, transparency)
	local f = bar(p, x, y, d, d, color, 0, transparency)
	UiKit.round(f, 999)
	return f
end
local function ray(p, ox, oy, length, thickness, degrees, color, transparency)
	local r = math.rad(degrees)
	local f = bar(p, ox + length / 2 * math.cos(r), oy + length / 2 * math.sin(r), length, thickness, color, degrees, transparency)
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
	}, f)
	return f
end
local function glyph(p, kind, x, y, px, color)
	local g = UiKit.Glyph(p, kind, color, px)
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(x, y)
	return g
end
local function tag(p, text, x, y, color)
	local l = UiKit.Label(p, text, "Caption", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	if color then
		l.TextColor3 = color
	end
	return l
end
local function scene(p)
	bar(p, 0.5, 1, 1, 0.3, C.AccentSeaDeep, 0, 0.5, Vector2.new(0.5, 1))
	for i, y in { 0.82, 0.9, 0.96 } do
		bar(p, 0.2 + i * 0.18, y, 0.14, 0.008, C.AccentSea, 0, 0.55)
	end
	local isle = bar(p, 0.5, 0.79, 0.66, 0.07, C.SurfaceHover, 0, 0)
	UiKit.round(isle, 999)
end
local function tower(p, x, base, s)
	bar(p, x, base, 0.11 * s, 0.4 * s, C.Stone, 0, 0, Vector2.new(0.5, 1))
	bar(p, x, base - 0.13 * s, 0.11 * s, 0.03 * s, C.StateDanger, 0, 0.25, Vector2.new(0.5, 1))
	bar(p, x, base - 0.27 * s, 0.11 * s, 0.03 * s, C.StateDanger, 0, 0.25, Vector2.new(0.5, 1))
	bar(p, x, base - 0.4 * s, 0.17 * s, 0.022 * s, C.BorderBrassBright, 0, 0, Vector2.new(0.5, 1))
	bar(p, x, base - 0.42 * s, 0.08 * s, 0.07 * s, C.SurfaceElevated, 0, 0, Vector2.new(0.5, 1))
	bar(p, x, base - 0.49 * s, 0.11 * s, 0.022 * s, C.BorderStructural, 0, 0, Vector2.new(0.5, 1))
	dot(p, x, base - 0.455 * s, 0.05 * s, C.AccentLighthouse)
	return x, base - 0.455 * s -- lamp point
end
local function crab(p, x, y, d, transparency)
	dot(p, x, y, d, C.StateDanger, transparency)
	bar(p, x - d * 0.55, y + d * 0.2, d * 0.5, d * 0.14, C.StateDanger, 30, transparency)
	bar(p, x + d * 0.55, y + d * 0.2, d * 0.5, d * 0.14, C.StateDanger, -30, transparency)
end
local function keeper(p, x, y, s, color)
	dot(p, x, y - 0.1 * s, 0.055 * s, C.TextPrimary)
	local body = bar(p, x, y, 0.06 * s, 0.1 * s, color, 0, 0, Vector2.new(0.5, 0.5))
	UiKit.round(body, 6)
end
local function gauge(p, y, fill, color, glyphKind, label, px)
	glyph(p, glyphKind, 0.17, y, math.max(12, math.floor(px * 0.05)), color)
	local track = bar(p, 0.55, y, 0.62, 0.035, C.SurfaceHover, 0, 0)
	UiKit.round(track, 3)
	local f = bar(track, 0, 0.5, fill, 1, color, 0, 0, Vector2.new(0, 0.5))
	UiKit.round(f, 3)
	if label then
		tag(p, label, 0.55, y - 0.06, C.TextMuted)
	end
end

local DRAW = {}
DRAW.fuel = function(p, px)
	scene(p)
	tower(p, 0.4, 0.78, 1)
	local barrel = bar(p, 0.74, 0.76, 0.09, 0.12, Color3.fromRGB(122, 82, 44), 0, 0, Vector2.new(0.5, 1))
	UiKit.round(barrel, 4)
	bar(p, 0.74, 0.68, 0.09, 0.012, C.BorderStructural, 0, 0)
	bar(p, 0.74, 0.72, 0.09, 0.012, C.BorderStructural, 0, 0)
	for i = 1, 4 do
		dot(p, 0.68 - i * 0.045, 0.72, 0.016, C.AccentLighthouseSoft, 0.15 + i * 0.12)
	end
	gauge(p, 0.14, 0.62, C.AccentLighthouse, "lamp", "Fuel", px)
end
DRAW.wide = function(p, px)
	scene(p)
	local lx, ly = tower(p, 0.28, 0.78, 1)
	for i = 0, 4 do
		ray(p, lx, ly, 0.66, 0.03, 10 + i * 7, C.AccentLighthouseSoft, 0.25)
	end
	crab(p, 0.78, 0.66, 0.05)
	crab(p, 0.86, 0.72, 0.045)
	crab(p, 0.72, 0.73, 0.045)
	glyph(p, "next", 0.93, 0.6, math.max(12, math.floor(px * 0.05)), C.AccentLighthouseSoft)
	tag(p, "Wide", 0.5, 0.14, C.AccentLighthouse)
end
DRAW.focus = function(p, px)
	scene(p)
	local lx, ly = tower(p, 0.28, 0.78, 1)
	ray(p, lx, ly, 0.62, 0.035, 21, C.AccentLighthouseSoft, 0)
	dot(p, 0.8, 0.62, 0.19, C.StateDanger, 0)
	dot(p, 0.8, 0.62, 0.11, Color3.fromRGB(150, 62, 52), 0)
	for _, o in { { -0.08, -0.08 }, { -0.1, 0.03 }, { -0.04, 0.1 } } do
		dot(p, 0.8 + o[1], 0.62 + o[2], 0.025, C.AccentLighthouseSoft, 0)
	end
	tag(p, "Focused  ·  more fuel", 0.5, 0.14, C.AccentLighthouse)
end
DRAW.repair = function(p, px)
	scene(p)
	tower(p, 0.5, 0.78, 1.05)
	crab(p, 0.27, 0.76, 0.045, 0.45)
	glyph(p, "plus", 0.66, 0.5, math.max(14, math.floor(px * 0.07)), C.StateSuccess)
	gauge(p, 0.14, 0.7, C.StateSuccess, "tower", "Tower", px)
end
DRAW.fight = function(p, px)
	scene(p)
	keeper(p, 0.26, 0.7, 1.2, C.AccentSea)
	local shaft = bar(p, 0.5, 0.64, 0.4, 0.012, C.TextPrimary, -4, 0)
	_ = shaft
	glyph(p, "diamond", 0.71, 0.625, math.max(10, math.floor(px * 0.04)), C.TextPrimary)
	crab(p, 0.8, 0.68, 0.07)
	tag(p, "Strike", 0.5, 0.14, C.AccentLighthouse)
end
DRAW.cannons = function(p, px)
	scene(p)
	dot(p, 0.4, 0.76, 0.22, C.AccentLighthouse, 0.7)
	local base = bar(p, 0.4, 0.72, 0.14, 0.07, C.SurfaceHover, 0, 0)
	UiKit.round(base, 4)
	local barrel = bar(p, 0.48, 0.66, 0.2, 0.05, C.BorderBrassBright, -18, 0)
	UiKit.round(barrel, 6)
	for i = 1, 3 do
		dot(p, 0.6 + i * 0.09, 0.6 - i * 0.025, 0.03, C.TextPrimary, (i - 1) * 0.3)
	end
	for i = 1, 4 do
		local pip = bar(p, 0.3 + i * 0.08, 0.14, 0.055, 0.05, if i <= 3 then C.AccentLighthouse else C.SurfaceHover, 0, 0)
		UiKit.round(pip, 2)
	end
	tag(p, "Ammo", 0.17, 0.14, C.TextMuted)
end
DRAW.team = function(p, px)
	scene(p)
	tower(p, 0.5, 0.78, 0.9)
	local roles = {
		{ 0.17, 0.72, C.AccentLighthouse, "Aim" },
		{ 0.83, 0.72, Color3.fromRGB(196, 140, 72), "Oil" },
		{ 0.25, 0.4, C.StateSuccess, "Repair" },
		{ 0.75, 0.4, C.AccentSea, "Fight" },
	}
	for _, r in roles do
		keeper(p, r[1], r[2], 1, r[3])
		tag(p, r[4], r[1], r[2] + 0.1, r[3])
	end
end

local STEPS = {}
local function addStep(step)
	table.insert(STEPS, step)
end
addStep({
	id = "fuel",
	title = "Keep the lighthouse fueled",
	body = string.format(
		"The lamp burns oil all night. Carry barrels from the oil pile to the fuel tank. Dark for %d seconds and the voyage is lost.",
		Config.DARK_GRACE_SECONDS or 10
	),
	hints = { { keyboard = "E", gamepad = KEY_X, touch = "Tap", label = "Grab oil, then refuel" } },
})
addStep({
	id = "wide",
	title = "Wide beam pushes groups back",
	body = "Take the lamp console to become the Keeper. The wide beam shoves crowds of crabs away from the tower.",
	hints = {
		{ keyboard = "E", gamepad = KEY_X, touch = "Tap", label = "Use the lamp" },
		{ keyboard = "Mouse", touch = "Drag", label = "Aim the beam" },
	},
})
addStep({
	id = "focus",
	title = "Focused beam burns tough threats",
	body = "Switch to the focused beam to burn big monsters fast. It drinks much more fuel, so switch back when they fall.",
	hints = {
		{ keyboard = "F", touch = "Focus", label = "Switch beam" },
		{ keyboard = "Q", touch = "Leave", label = "Leave the lamp" },
	},
})
addStep({
	id = "repair",
	title = "Repair the tower",
	body = "Crabs chew on the tower. Hold the prompt at the tower door to patch it, and watch the tower bar.",
	hints = { { keyboard = "E", gamepad = KEY_X, touch = "Hold", label = "Repair (hold)" } },
})
addStep({
	id = "fight",
	title = "Fight with your harpoon",
	body = "Away from the lamp, strike creatures with your harpoon. Creatures you hit tend to turn on you instead of the tower.",
	hints = { { keyboard = "Click", gamepad = Enum.KeyCode.ButtonR2, touch = "Tap", label = "Strike a creature" } },
})
if ECONOMY then
	addStep({
		id = "cannons",
		title = "Build and reload cannons",
		body = "Spend Shells to build a cannon on a glowing stone pad. Cannons fire on their own; carry oil over to reload them.",
		hints = {
			{ keyboard = "E", gamepad = KEY_X, touch = "Hold", label = "Build (hold)" },
			{ keyboard = "R", gamepad = Enum.KeyCode.ButtonY, touch = "Hold", label = "Reload with oil (hold)" },
		},
	})
end
addStep({
	id = "team",
	title = "Work together",
	body = "One Keeper aims the light. Everyone else hauls oil, repairs and fights. Nobody holds the light alone.",
	hints = {},
})

local howPanel, howContent = UiKit.Panel(panels, {
	name = "HowToPlay",
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
	size = UDim2.fromOffset(900, 560),
})
howPanel.Visible = false
howPanel.ZIndex = 2
local howHeader, _, howHeading = panelHeader(howContent, "Keeper's primer", "How to keep the light", "CloseHow")

local howBody = new("Frame", { Name = "Body", BackgroundTransparency = 1 }, howContent)
local art = UiKit.Inset(howBody, { Name = "Art", ClipsDescendants = true })
local artStage = new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, art)
local textCol = new("ScrollingFrame", {
	Name = "Text",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.BorderStructural,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Selectable = false,
}, howBody)
UiKit.list(textCol, "y", 12)
local stepLabel = UiKit.Label(textCol, "", "Eyebrow", { Name = "StepCount", LayoutOrder = 1 })
local stepTitle = UiKit.Label(textCol, "", "H1", { Name = "StepTitle", LayoutOrder = 2 })
local stepBody = UiKit.Label(textCol, "", "Body", { Name = "StepBody", LayoutOrder = 3, TextColor3 = C.TextSecondary })
local hintBox = new("Frame", {
	Name = "Hints",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 4,
}, textCol)
UiKit.list(hintBox, "y", 8)

local howFooter = new("Frame", {
	Name = "Footer",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 48),
}, howContent)
local pips = new("Frame", {
	Name = "Pips",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(0, 12),
	AutomaticSize = Enum.AutomaticSize.X,
}, howFooter)
UiKit.list(pips, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
local pipFrames = {}
for i = 1, #STEPS do
	local pip = new("Frame", { Name = "Pip" .. i, BackgroundColor3 = C.SurfaceHover, BorderSizePixel = 0, Size = UDim2.fromOffset(10, 10), LayoutOrder = i }, pips)
	UiKit.round(pip, 5)
	pipFrames[i] = pip
end
local navRow = new("Frame", {
	Name = "Nav",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(0, 48),
	AutomaticSize = Enum.AutomaticSize.X,
}, howFooter)
UiKit.list(navRow, "x", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
local backStep = UiKit.Button(navRow, "Back", { name = "BackStep", variant = "secondary", width = 120, layoutOrder = 1 })
local nextStep = UiKit.Button(navRow, "Next", { name = "NextStep", variant = "primary", width = 150, layoutOrder = 2 })

local stepIndex = 1
local artPx = 340
local textBase = UDim2.fromOffset(372, 0)

local function renderHints(step)
	for _, child in hintBox:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local mode = inputMode()
	for i, hint in step.hints do
		if hint[mode] then
			UiKit.KeyHint(hintBox, { keyboard = hint.keyboard, touch = hint.touch, gamepad = hint.gamepad }, hint.label, {
				input = mode,
				layoutOrder = i,
			})
		end
	end
end

local function drawArt()
	artStage:ClearAllChildren()
	local step = STEPS[stepIndex]
	local draw = DRAW[step.id]
	if draw then
		draw(artStage, artPx)
	end
end

local function showStep(index, animate)
	stepIndex = math.clamp(index, 1, #STEPS)
	local step = STEPS[stepIndex]
	stepLabel.Text = string.upper(string.format("Step %d of %d", stepIndex, #STEPS))
	stepTitle.Text = step.title
	stepBody.Text = step.body
	renderHints(step)
	drawArt()
	for i, pip in pipFrames do
		local on = i == stepIndex
		pip.BackgroundColor3 = if on then C.AccentLighthouse elseif i < stepIndex then C.BorderStructural else C.SurfaceHover
		pip.Size = if on then UDim2.fromOffset(24, 10) else UDim2.fromOffset(10, 10)
	end
	setDisabled(backStep, stepIndex == 1)
	setButtonText(nextStep, if stepIndex == #STEPS then "Got it" else "Next")
	textCol.CanvasPosition = Vector2.zero
	if animate then
		artStage.Position = UDim2.fromOffset(animate * 14, 0)
		tween(artStage, UiKit.Motion.base, { Position = UDim2.new() })
		textCol.Position = textBase + UDim2.fromOffset(animate * 10, 0)
		tween(textCol, UiKit.Motion.base, { Position = textBase })
	end
end

local function stepBy(delta)
	if current ~= "how" then
		return
	end
	local target = stepIndex + delta
	if target > #STEPS then
		closePanel()
	elseif target >= 1 then
		showStep(target, delta)
	end
end
backStep.Activated:Connect(function()
	if stepIndex > 1 then
		stepBy(-1)
	end
end)
nextStep.Activated:Connect(function()
	stepBy(1)
end)
UserInputService.TouchSwipe:Connect(function(direction)
	if current ~= "how" then
		return
	end
	if direction == Enum.SwipeDirection.Left then
		stepBy(1)
	elseif direction == Enum.SwipeDirection.Right then
		stepBy(-1)
	end
end)
UserInputService.LastInputTypeChanged:Connect(function()
	if current == "how" then
		renderHints(STEPS[stepIndex])
	end
end)

---------------------------------------------------------------------
-- SETTINGS: only controls that work; they last for this session
---------------------------------------------------------------------

local settingsPanel, settingsContent = UiKit.Panel(panels, {
	name = "Settings",
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
	size = UDim2.fromOffset(680, 500),
})
settingsPanel.Visible = false
settingsPanel.ZIndex = 2
local settingsHeader = panelHeader(settingsContent, "Keeper's log", "Settings", "CloseSettings")

local settingsScroll = new("ScrollingFrame", {
	Name = "Rows",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.BorderStructural,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Selectable = false,
}, settingsContent)
UiKit.list(settingsScroll, "y", 18)
UiKit.pad(settingsScroll, 0, 10, 8, 0)

local settingsFooter = new("Frame", {
	Name = "Footer",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 48),
}, settingsContent)
local sessionNote = UiKit.Label(settingsFooter, "Settings last until you leave the game.", "Micro", {
	Name = "SessionNote",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(1, -330, 0, 0),
})
local settingsActions = new("Frame", {
	Name = "Actions",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(0, 48),
	AutomaticSize = Enum.AutomaticSize.X,
}, settingsFooter)
UiKit.list(settingsActions, "x", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
local resetButton = UiKit.Button(settingsActions, "Reset", { name = "ResetButton", variant = "ghost", width = 120, layoutOrder = 1 })
local doneButton = UiKit.Button(settingsActions, "Done", { name = "DoneButton", variant = "primary", width = 130, layoutOrder = 2 })

local DEFAULTS = { SFX = 1, Ambience = 1, LowEffects = false }
local dialogOpen = false
local firstControl

local function buildSettings()
	for _, child in settingsScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	firstControl = nil
	local phone = UiKit.Breakpoint(root.AbsoluteSize) == "phone"
	local controlWidth = if phone then 250 else 320
	local audio = UiKit.Section(settingsScroll, "Audio", { name = "Audio", layoutOrder = 1 })
	local function volume(text, description, groupName, order, last, preview)
		local group = SoundFx.getGroup(groupName)
		local _, slot = UiKit.SettingRow(audio, text, description, {
			name = groupName .. "Row",
			layoutOrder = order,
			controlWidth = controlWidth,
			last = last,
		})
		local slider = UiKit.Slider(slot, {
			name = groupName .. "Slider",
			min = 0,
			max = 100,
			step = 10,
			value = math.floor(group.Volume * 100 + 0.5),
			size = UDim2.fromScale(1, 1),
			format = function(v)
				return string.format("%d%%", v)
			end,
			onChange = function(v)
				group.Volume = v / 100
				if preview then
					SoundFx.play2D("click")
				end
			end,
		})
		return slider
	end
	local sfx = volume("Sound effects", "Harpoons, cannons, pickups and menus.", "SFX", 1, false, true)
	volume("Storm and waves", "Rain, wind, thunder and the sea.", "Ambience", 2, true, false)
	firstControl = sfx.frame:FindFirstChild("Less") or sfx.frame

	local visual = UiKit.Section(settingsScroll, "Visual", { name = "Visual", layoutOrder = 2 })
	local _, slot = UiKit.SettingRow(visual, "Low effects", "Turns off the rain. Helps slower phones and tablets.", {
		name = "LowEffectsRow",
		layoutOrder = 1,
		controlWidth = controlWidth,
		last = true,
	})
	local toggle = UiKit.Toggle(slot, {
		name = "LowEffectsToggle",
		value = player:GetAttribute("LowEffects") == true,
		onChange = function(v)
			player:SetAttribute("LowEffects", v)
		end,
	})
	toggle.button.AnchorPoint = Vector2.new(1, 0)
	toggle.button.Position = UDim2.fromScale(1, 0)
end

local function isDefault()
	return math.abs(SoundFx.getGroup("SFX").Volume - DEFAULTS.SFX) < 0.01
		and math.abs(SoundFx.getGroup("Ambience").Volume - DEFAULTS.Ambience) < 0.01
		and (player:GetAttribute("LowEffects") == true) == DEFAULTS.LowEffects
end

resetButton.Activated:Connect(function()
	if dialogOpen or current ~= "settings" then
		return
	end
	if isDefault() then
		UiKit.Toast(root, "Everything is already at its default.", "info")
		return
	end
	dialogOpen = true
	local dialog = UiKit.Dialog(panels, {
		eyebrow = "Settings",
		title = "Reset to defaults?",
		body = "Both volumes go back to 100% and low effects turns off. Nothing else changes.",
		confirmText = "Reset",
		cancelText = "Keep",
		onConfirm = function()
			dialogOpen = false
			SoundFx.getGroup("SFX").Volume = DEFAULTS.SFX
			SoundFx.getGroup("Ambience").Volume = DEFAULTS.Ambience
			player:SetAttribute("LowEffects", DEFAULTS.LowEffects)
			buildSettings()
			UiKit.Toast(root, "Settings reset to defaults.", "success")
			focus(doneButton)
		end,
		onCancel = function()
			dialogOpen = false
			focus(resetButton)
		end,
	})
	if dialog and dialog.cancel then
		focus(dialog.cancel)
	end
end)
doneButton.Activated:Connect(function()
	closePanel()
end)

---------------------------------------------------------------------
-- Layout (desktop / tablet / phone are designed separately, not shrunk)
---------------------------------------------------------------------

local lastBreakpoint

local function layoutTitle()
	local size = root.AbsoluteSize
	local bp = UiKit.Breakpoint(size)
	local phone = bp == "phone"
	local wordSize = if phone then 44 elseif bp == "tablet" then 64 else 84
	for _, w in { word1, word2 } do
		w.Size = UDim2.new(1, 0, 0, wordSize + 4)
		w.UITextSizeConstraint.MaxTextSize = wordSize
	end
	brand.Size = UDim2.fromOffset(math.floor(math.min(if phone then 400 else 620, size.X * (if phone then 0.62 else 0.55))), 0)
	eyebrowRow.Visible = not phone
	eyebrowGap.Visible = not phone
	tagline.TextSize = if phone then 15 else 19
	actionsGap.Size = UDim2.new(1, 0, 0, if phone then 14 else 28)
	noteGap.Size = UDim2.new(1, 0, 0, if phone then 8 else 14)
	local actionWidth = if phone then 290 else 340
	actions.Size = UDim2.new(0, actionWidth, 0, 0)
	note.Size = UDim2.new(0, actionWidth, 0, 0)
	playButton.Size = UDim2.new(1, 0, 0, if phone then 50 else 56)
	secondaryRow.Size = UDim2.new(1, 0, 0, if phone then 44 else 48)
	for _, b in { howButton, settingsButton } do
		b.Size = UDim2.fromOffset((actionWidth - 10) / 2, if phone then 44 else 48)
	end
	shade.Size = UDim2.fromScale(if phone then 0.95 else 0.72, 1)
	framingDegrees = if phone then 11 else 16
	buildLabel.Position = if phone then UDim2.new(1, -16, 1, -10) else UDim2.new(1, -24, 1, -18)
	local left = math.max(if phone then 48 else 32, math.floor(size.X * (if phone then 0.05 else 0.07)))
	brand.Position = UDim2.new(0, left, 0.5, 0)
	-- keep the column clear of the Roblox top bar and the bottom edge
	task.defer(function()
		local h = brand.AbsoluteSize.Y
		local top = math.max(60, (size.Y - h) / 2 + (if phone then 6 else size.Y * 0.02))
		top = math.min(top, size.Y - h - 8)
		brand.Position = UDim2.new(0, left, 0, math.floor(top + h / 2))
	end)
end

local function layoutHow()
	local size = root.AbsoluteSize
	local bp = UiKit.Breakpoint(size)
	local phone = bp == "phone"
	local pw, ph
	if phone then
		pw, ph = size.X - 16, size.Y - 16
	elseif bp == "tablet" then
		pw, ph = math.min(size.X - 48, 900), math.min(size.Y - 48, 560)
	else
		pw, ph = 900, 560
	end
	howPanel.Size = UDim2.fromOffset(pw, ph)
	local pad = if phone then 14 else 26
	howContent.Position = UDim2.fromOffset(pad, pad)
	howContent.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	local contentW, contentH = pw - pad * 2, ph - pad * 2
	local headerH = if phone then 30 else 50
	howHeader.Size = UDim2.new(1, -56, 0, headerH)
	howHeader:FindFirstChild("Eyebrow").Visible = not phone
	howHeading.TextSize = if phone then 20 else 23
	local bodyTop = headerH + (if phone then 8 else 16)
	local bodyH = contentH - bodyTop - 48 - (if phone then 8 else 16)
	howBody.Position = UDim2.fromOffset(0, bodyTop)
	howBody.Size = UDim2.new(1, 0, 0, bodyH)
	artPx = math.floor(math.min(bodyH, contentW * 0.42))
	art.Size = UDim2.fromOffset(artPx, artPx)
	local gap = if phone then 16 else 32
	textBase = UDim2.fromOffset(artPx + gap, 0)
	textCol.Position = textBase
	textCol.Size = UDim2.new(1, -(artPx + gap), 1, 0)
	stepTitle.TextSize = if phone then 21 else 30
	stepBody.TextSize = if phone then 15 else 18
	for _, pip in pipFrames do
		pip.Visible = true
	end
	if current == "how" then
		drawArt()
	end
end

local function layoutSettings()
	local size = root.AbsoluteSize
	local bp = UiKit.Breakpoint(size)
	local phone = bp == "phone"
	local pw, ph
	if phone then
		pw, ph = size.X - 16, size.Y - 16
	else
		pw, ph = math.min(size.X - 48, 680), math.min(size.Y - 48, 500)
	end
	settingsPanel.Size = UDim2.fromOffset(pw, ph)
	local pad = if phone then 14 else 26
	settingsContent.Position = UDim2.fromOffset(pad, pad)
	settingsContent.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	local headerH = if phone then 30 else 50
	settingsHeader.Size = UDim2.new(1, -56, 0, headerH)
	settingsHeader:FindFirstChild("Eyebrow").Visible = not phone
	local top = headerH + (if phone then 6 else 14)
	settingsScroll.Position = UDim2.fromOffset(0, top)
	settingsScroll.Size = UDim2.new(1, 0, 1, -top - 48 - 8)
	sessionNote.Size = UDim2.new(1, -280, 0, 0)
end

local function relayout()
	layoutTitle()
	layoutHow()
	layoutSettings()
	local bp = UiKit.Breakpoint(root.AbsoluteSize)
	if bp ~= lastBreakpoint then
		lastBreakpoint = bp
		if current == "settings" then
			buildSettings()
		end
	end
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

---------------------------------------------------------------------
-- Screen switching
---------------------------------------------------------------------

local function openPanel(which)
	if current ~= "title" then
		return
	end
	current = which
	brand.Visible = false
	scrim.Visible = true
	tween(scrim, UiKit.Motion.base, { BackgroundTransparency = 0.35 })
	if which == "how" then
		layoutHow()
		showStep(1)
		UiKit.Open(howPanel)
		focus(nextStep)
	else
		layoutSettings()
		buildSettings()
		UiKit.Open(settingsPanel)
		focus(firstControl or doneButton)
	end
end

closePanel = function()
	if current ~= "how" and current ~= "settings" then
		return
	end
	if dialogOpen then
		return
	end
	local panel = if current == "how" then howPanel else settingsPanel
	local opener = if current == "how" then howButton else settingsButton
	current = "title"
	tween(scrim, UiKit.Motion.fast, { BackgroundTransparency = 1 })
	UiKit.Close(panel, function()
		if current == "title" then
			scrim.Visible = false
		end
	end)
	brand.Visible = true
	focus(opener)
end

howButton.Activated:Connect(function()
	openPanel("how")
end)
settingsButton.Activated:Connect(function()
	openPanel("settings")
end)

local function refreshNote()
	local phase = state:GetAttribute("Phase")
	local underway = phase == "Prologue" or phase == "Day" or phase == "Night"
	note.Visible = underway
	noteGap.Visible = underway
	noteText.Text = "A voyage is already at sea. Press Play, then walk onto the ship to join the next crew."
	if current == "title" then
		layoutTitle()
	end
end
state:GetAttributeChangedSignal("Phase"):Connect(refreshNote)

-- Back: controller B or Backspace closes a panel (Escape belongs to the Roblox menu)
local function onBack(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if (current == "how" or current == "settings") and not dialogOpen then
		closePanel()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end
local function onStepKeys(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin or current ~= "how" then
		return Enum.ContextActionResult.Pass
	end
	if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.ButtonR1 then
		stepBy(1)
	else
		stepBy(-1)
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority("MenusBack", onBack, false, 3000, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
ContextActionService:BindActionAtPriority(
	"MenusSteps",
	onStepKeys,
	false,
	3000,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.ButtonL1,
	Enum.KeyCode.ButtonR1
)

UserInputService.LastInputTypeChanged:Connect(function()
	if current == "title" and UiKit.usingGamepad() and not GuiService.SelectedObject then
		focus(playButton)
	end
end)

---------------------------------------------------------------------
-- Play: same EnterLobby request as before, with a short dark transition
---------------------------------------------------------------------

local leaving = false
playButton.Activated:Connect(function()
	if leaving or current ~= "title" then
		return
	end
	leaving = true
	current = "gone"
	remotes:WaitForChild("EnterLobby"):FireServer()
	coverRow.Visible = false
	cover.Visible = true
	cover.BackgroundTransparency = 1
	tween(cover, 0.25, { BackgroundTransparency = 0 })
	task.wait(0.27)
	title.Visible = false
	panels.Visible = false
	GuiService.SelectedObject = nil
	stopCamera()
	setBlocking(false)
	ContextActionService:UnbindAction("MenusBack")
	ContextActionService:UnbindAction("MenusSteps")
	task.wait(0.15)
	tween(cover, 0.45, { BackgroundTransparency = 1 })
	task.wait(0.47)
	cover.Visible = false
end)

---------------------------------------------------------------------
-- STUDIO ONLY: simulated screen sizes (HudSimulate attribute)
---------------------------------------------------------------------

if RunService:IsStudio() then
	local SIZES = {
		smallPhone = Vector2.new(667, 375),
		largePhone = Vector2.new(932, 430),
		tablet = Vector2.new(1180, 820),
		laptop = Vector2.new(1366, 768),
	}
	local function applySimulation()
		local spec = SIZES[player:GetAttribute("HudSimulate") or ""]
		root.ClipsDescendants = spec ~= nil
		if spec then
			root.AnchorPoint = Vector2.new(0.5, 0.5)
			root.Position = UDim2.fromScale(0.5, 0.5)
			root.Size = UDim2.fromOffset(spec.X, spec.Y)
		else
			root.AnchorPoint = Vector2.zero
			root.Position = UDim2.new()
			root.Size = UDim2.fromScale(1, 1)
		end
	end
	player:GetAttributeChangedSignal("HudSimulate"):Connect(applySimulation)
	applySimulation()
end

---------------------------------------------------------------------
-- Start on the title screen
---------------------------------------------------------------------

-- The server picks the route (launch R2): "fast" = first voyage, already on the crew, no title.
-- Anything else, or no answer within 10 s, shows the title as before.
local route
setBlocking(true)
relayout()
refreshNote()
task.spawn(function()
	local started = os.clock()
	while player:GetAttribute("Route") == nil and os.clock() - started < 10 do
		task.wait(0.1)
	end
	route = player:GetAttribute("Route") or "title"
	if route == "fast" then
		current = "gone"
		title.Visible = false
		panels.Visible = false
		setBlocking(false)
		ContextActionService:UnbindAction("MenusBack")
		ContextActionService:UnbindAction("MenusSteps")
		coverText.Text = "The storm is coming. The light needs a keeper."
		task.wait(2.2)
		tween(cover, 0.6, { BackgroundTransparency = 1 })
		tween(coverText, 0.4, { TextTransparency = 1 })
		for _, d in coverGlyph:GetDescendants() do
			if d:IsA("Frame") then
				tween(d, 0.4, { BackgroundTransparency = 1 })
			end
		end
		task.wait(0.62)
		cover.Visible = false
	else
		startCamera()
		focus(playButton)
	end
end)

task.spawn(function()
	pcall(function()
		player:RequestStreamAroundAsync(LIGHTHOUSE, 8)
	end)
end)
task.spawn(function()
	while route == nil do
		task.wait(0.1)
	end
	if route == "fast" then
		return -- handled above
	end
	local started = os.clock()
	while os.clock() - started < 8 do
		local island = Workspace:FindFirstChild("Island")
		if island and island:FindFirstChild("LighthouseTower") then
			break
		end
		task.wait(0.2)
	end
	task.wait(0.4) -- let the first frames render
	if current == "gone" then
		return
	end
	tween(cover, 0.6, { BackgroundTransparency = 1 })
	tween(coverText, 0.3, { TextTransparency = 1 })
	for _, d in coverGlyph:GetDescendants() do
		if d:IsA("Frame") then
			tween(d, 0.3, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.62)
	if current ~= "gone" then
		cover.Visible = false
	end
end)
