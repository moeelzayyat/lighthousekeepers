-- Hud (client): the production gameplay HUD, built on UiKit v2.1.
--
-- Presentation only. Every value shown comes from an authoritative source:
--   GameState attributes  Phase, Night, TimeLeft, Reason (GameState) · Fuel, MaxFuel, DarkSeconds,
--                         BeamMode, KeeperUserId (LampService) · Integrity, MaxIntegrity (TowerService)
--                         Shells (UpgradeService) · BigWarning (GameState) · Bosses folder (CreatureService)
--   Player                Humanoid Health / MaxHealth · equipped Tool (WeaponId) · CarryingOil · SaveUnavailable
--   Cannon pads           CannonLevel, Ammo, MaxAmmo, AmmoName, CannonHealth (DefenseService)
--   Remotes               Notify (server messages) · LootCollected (pickups)
--   ProximityPrompts      drawn here in the shared style (Style = Custom); the engine still decides
--                         which prompts are in range and handles keys, holds and triggering.
--
-- Layout (landscape first, responsive everywhere, inside Roblox safe areas):
--   top-left    health, weapon, shells        top-center  voyage status, lamp fuel, warnings, bosses
--   top-right   (BAG button) tower, beam      center      blackout alarm (above the crosshair)
--   bottom      prompts, cannon card, keeper controls (clear of the joystick and jump button)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local SoundFx = require(Shared:WaitForChild("SoundFx"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))

local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local lampAction = remotes:WaitForChild("LampAction")
local player = Players.LocalPlayer
local C = UiKit.Color
local F = UiKit.Font

local ISLAND_PHASES = { Prologue = true, Day = true, Night = true, Victory = true, Defeat = true }
local LIT_PHASES = { Prologue = true, Day = true, Night = true }

-- Our health gauge replaces Roblox's
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) then
			return
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------
-- Screens: the HUD (only while in the crew) and prompts (always, also in the harbor)
---------------------------------------------------------------------

local gui = UiKit.Screen("GameHUD", 5)
local promptGui = UiKit.Screen("Prompts", 6)
local function makeRoot(screen)
	local root = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen)
	local outline = UiKit.border(root, C.TextMuted, 2)
	outline.Enabled = false
	return root
end
local hudRoot = makeRoot(gui)
local promptRoot = makeRoot(promptGui)
local simulated = nil -- Studio-only layout simulator (see the end of the script)
local applyLayout -- forward declaration (boss bars re-layout on add/remove)
local glassLayout -- forward declaration (glass HUD placement, defined near the end)
local compact = false -- phone layout: tighter clusters, the alarm takes the voyage slot

local function cluster(name, anchor, position, align)
	local f = UiKit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, hudRoot)
	UiKit.list(f, "y", 8, { HorizontalAlignment = align })
	return f
end

local topLeft = cluster("TopLeft", Vector2.new(0, 0), UDim2.fromOffset(12, 10), Enum.HorizontalAlignment.Left)
local topCenter = cluster("TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), Enum.HorizontalAlignment.Center)
local topRight = cluster("TopRight", Vector2.new(1, 0), UDim2.new(1, -12, 0, 64), Enum.HorizontalAlignment.Right)

-- a quiet backing plate so gauges stay legible over rain and lightning
local function plate(parent, order, name)
	local p = UiKit.new("Frame", {
		Name = name or "Plate",
		BackgroundColor3 = C.SurfaceBase,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	UiKit.round(p, UiKit.Radius.panel)
	UiKit.border(p, C.BorderStructural, 1, 0.6)
	UiKit.pad(p, 10, 12, 10, 12)
	UiKit.list(p, "y", 10)
	return p
end

---------------------------------------------------------------------
-- TOP LEFT: health, weapon, shells
---------------------------------------------------------------------

local leftPlate = plate(topLeft, 1, "SurvivorPlate")
local health = UiKit.HealthGauge(leftPlate, { value = 100, max = 100, size = UDim2.new(1, 0, 0, 38), layoutOrder = 1 })

-- weapon in hand (one small static 3D preview, refreshed only when the weapon changes)
local weaponRow = UiKit.new("Frame", { Name = "Weapon", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 2 }, leftPlate)
local weaponWell = UiKit.Inset(weaponRow, { Name = "Well", BackgroundColor3 = Color3.fromRGB(22, 32, 46), Size = UDim2.fromOffset(44, 44), ClipsDescendants = true })
UiKit.border(weaponWell, C.BorderStructural, 1, 0.55)
local weaponPreview = ItemPreview.new(weaponWell, {})
local weaponName = UiKit.Label(weaponRow, "", "H3", {
	Position = UDim2.fromOffset(54, 2),
	Size = UDim2.new(1, -54, 0, 20),
	AutomaticSize = Enum.AutomaticSize.None,
	TextSize = 16,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextWrapped = false,
})
local weaponState = UiKit.Label(weaponRow, "", "Caption", {
	Position = UDim2.fromOffset(54, 23),
	Size = UDim2.new(1, -54, 0, 16),
	AutomaticSize = Enum.AutomaticSize.None,
	TextWrapped = false,
})
local cooldownTrack = UiKit.new("Frame", {
	Name = "Cooldown",
	BackgroundColor3 = C.SurfaceInset,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 54, 1, 0),
	Size = UDim2.new(1, -54, 0, 3),
	Visible = false,
}, weaponRow)
local cooldownFill = UiKit.new("Frame", { BackgroundColor3 = C.AccentLighthouse, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, cooldownTrack)
local weaponScale = UiKit.new("UIScale", {}, weaponRow)

local shells
if Config.ECONOMY_ENABLED then
	shells = UiKit.Currency(leftPlate, "Shells", state:GetAttribute("Shells") or 0, { layoutOrder = 3 })
end

---------------------------------------------------------------------
-- TOP CENTER: voyage status, lamp fuel, big-monster warning, boss bars
---------------------------------------------------------------------

local voyage = UiKit.new("Frame", {
	Name = "Voyage",
	BackgroundColor3 = C.SurfacePrimary,
	BackgroundTransparency = 0.1,
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 1,
}, topCenter)
UiKit.round(voyage, UiKit.Radius.panel)
UiKit.border(voyage, C.BorderStructural, 1, 0.4)
UiKit.pad(voyage, 0, 14, 0, 14)
UiKit.list(voyage, "x", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
local voyageScale = UiKit.new("UIScale", {}, voyage)
local pips = UiKit.new("Frame", { Name = "Nights", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, voyage)
UiKit.list(pips, "x", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
local pipFrames = {}
-- Long runs (more than 7 nights) skip the night diamonds: "NIGHT 4 OF 13" says it, and 13 diamonds crowd phones
pips.Visible = Config.NIGHTS_TO_WIN <= 7
for i = 1, if Config.NIGHTS_TO_WIN <= 7 then Config.NIGHTS_TO_WIN else 0 do
	local holder = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 12), LayoutOrder = i }, pips)
	local d = UiKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		Rotation = 45,
		BorderSizePixel = 0,
	}, holder)
	local stroke = UiKit.border(d, C.BorderStructural, 1.5, 0)
	pipFrames[i] = { d = d, stroke = stroke }
end
local voyageTitle = UiKit.new("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	FontFace = F.LabelBold,
	TextSize = 18,
	TextColor3 = C.TextPrimary,
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
}, voyage)
local voyageSub = UiKit.new("TextLabel", {
	Name = "Subtitle",
	BackgroundTransparency = 1,
	FontFace = F.Body,
	TextSize = 15,
	TextColor3 = C.TextSecondary,
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 3,
}, voyage)
local timerChip = UiKit.Inset(voyage, { Name = "Timer", Size = UDim2.fromOffset(56, 26), LayoutOrder = 4 })
local timerText = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.Numeric,
	TextSize = 16,
	TextColor3 = C.TextPrimary,
	Size = UDim2.fromScale(1, 1),
}, timerChip)

local fuelPlate = plate(topCenter, 2, "FuelPlate")
local fuel = UiKit.FuelGauge(fuelPlate, { value = 1, size = UDim2.new(1, 0, 0, 58), layoutOrder = 1 })

local warning = UiKit.new("Frame", {
	Name = "BigWarning",
	BackgroundColor3 = C.SurfaceBase,
	BackgroundTransparency = 0.15,
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 3,
	Visible = false,
}, topCenter)
UiKit.round(warning, UiKit.Radius.card)
UiKit.border(warning, C.StateDanger, 1.5, 0.2)
UiKit.pad(warning, 0, 14, 0, 12)
UiKit.list(warning, "x", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
UiKit.Glyph(warning, "warning", C.StateDanger, 18).LayoutOrder = 1
UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.LabelBold,
	TextSize = 17,
	TextColor3 = C.StateDanger,
	Text = "SOMETHING BIG IS COMING",
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
}, warning)
local warningSub = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.Body,
	TextSize = 15,
	TextColor3 = C.TextPrimary,
	Text = "Stay close to your crew.",
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 3,
}, warning)

local bossList = UiKit.new("Frame", {
	Name = "Bosses",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 4,
}, topCenter)
UiKit.list(bossList, "y", 6)

---------------------------------------------------------------------
-- TOP RIGHT: tower, beam
---------------------------------------------------------------------

local rightPlate = plate(topRight, 1, "LighthousePlate")
local tower = UiKit.TowerGauge(rightPlate, { value = 1, size = UDim2.new(1, 0, 0, 42), layoutOrder = 1 })

local beamRow = UiKit.new("Frame", { Name = "Beam", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2 }, rightPlate)
UiKit.list(beamRow, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
local beamGlyph = UiKit.new("Frame", { Name = "BeamGlyph", BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 18), LayoutOrder = 1 }, beamRow)
local beamText = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.LabelBold,
	TextSize = 16,
	TextColor3 = C.TextPrimary,
	Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
}, beamRow)
local beamTag = UiKit.Tag(beamRow, "Burns fuel faster", "StateWarning", { layoutOrder = 3 })
local keeperText = UiKit.Label(rightPlate, "", "Micro", { LayoutOrder = 3, Visible = false })

-- beam glyphs: WIDE = three rays fanning out, FOCUSED = one long ray (shape differs, not only color)
local function drawBeamGlyph(mode, color)
	beamGlyph:ClearAllChildren()
	local function ray(length, rotation, thick)
		local r = UiKit.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 3 + math.cos(math.rad(rotation)) * length / 2, 0.5, math.sin(math.rad(rotation)) * length / 2),
			Size = UDim2.fromOffset(length, thick),
			Rotation = rotation,
		}, beamGlyph)
		UiKit.round(r, thick)
	end
	if mode == "focused" then
		ray(19, 0, 4)
	elseif mode == "wide" then
		ray(17, -24, 2)
		ray(18, 0, 2)
		ray(17, 24, 2)
	elseif mode == "dark" then
		ray(16, 0, 2)
	end
	local dot = UiKit.new("Frame", {
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(7, 7),
	}, beamGlyph)
	UiKit.round(dot, 4)
end

---------------------------------------------------------------------
-- CENTER: blackout alarm (sits above the crosshair, never on it)
---------------------------------------------------------------------

local alarm = UiKit.new("Frame", {
	Name = "BlackoutAlarm",
	BackgroundColor3 = C.SurfaceBase,
	BackgroundTransparency = 0.08,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.5, -70),
	Size = UDim2.fromOffset(460, 76),
	Visible = false,
}, hudRoot)
UiKit.round(alarm, UiKit.Radius.panel)
local alarmStroke = UiKit.border(alarm, C.StateDanger, 2, 0)
local alarmLamp = UiKit.Glyph(alarm, "lamp", C.StateDanger, 34)
alarmLamp.AnchorPoint = Vector2.new(0, 0.5)
alarmLamp.Position = UDim2.new(0, 18, 0.5, 0)
local alarmTitle = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.LabelBold,
	TextSize = 24,
	TextColor3 = C.StateDanger,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "THE LAMP IS OUT",
	Position = UDim2.fromOffset(66, 10),
	Size = UDim2.new(1, -150, 0, 28),
}, alarm)
local alarmBody = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.BodyMedium,
	TextSize = 15,
	TextColor3 = C.TextPrimary,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	Position = UDim2.fromOffset(66, 38),
	Size = UDim2.new(1, -150, 0, 32),
}, alarm)
local alarmCount = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.Numeric,
	TextSize = 38,
	TextColor3 = C.TextPrimary,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.fromOffset(72, 44),
	TextXAlignment = Enum.TextXAlignment.Right,
}, alarm)

---------------------------------------------------------------------
-- BOTTOM: cannon card, carried oil, interaction prompts, keeper controls
---------------------------------------------------------------------

local bottom = UiKit.new("Frame", {
	Name = "Bottom",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(320, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, promptRoot)
UiKit.list(bottom, "y", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom })

local function card(name, order)
	local f = UiKit.new("Frame", {
		Name = name,
		BackgroundColor3 = C.SurfacePrimary,
		BackgroundTransparency = 0.08,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Visible = false,
	}, bottom)
	UiKit.round(f, UiKit.Radius.panel)
	UiKit.border(f, C.BorderStructural, 1, 0.4)
	UiKit.pad(f, 10, 12, 10, 12)
	return f
end

-- context cards (cannon, carried oil) live in the right column under the lighthouse plate, so the
-- bottom band only holds the action prompts and never grows up into the crosshair
local sideStack = UiKit.new("Frame", {
	Name = "SideStack",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 170),
	Size = UDim2.fromOffset(174, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
}, promptRoot)
UiKit.list(sideStack, "y", 6)

-- cannon nearby
local cannonCard = card("CannonCard", 1)
UiKit.list(cannonCard, "y", 6)
local cannonHead = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 }, cannonCard)
local cannonTitle = UiKit.Label(cannonHead, "Cannon", "Label", { Size = UDim2.new(0.6, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextColor3 = C.TextPrimary })
local cannonHull = UiKit.new("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = F.BodyMedium,
	TextSize = 14,
	TextColor3 = C.TextSecondary,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.4, 0, 1, 0),
}, cannonHead)
local cannonAmmo = UiKit.ResourceGauge(cannonCard, { label = "Oil Shot", value = 1, color = "CatAmmunition", warnBelow = 0.3, dangerBelow = 0.01, ticks = 10, size = UDim2.new(1, 0, 0, 38), layoutOrder = 2 })

-- carrying oil
local carryCard = card("CarryCard", 2)
UiKit.list(carryCard, "x", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
UiKit.Glyph(carryCard, "lamp", C.AccentLighthouse, 22).LayoutOrder = 1
local carryText = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, carryCard)
UiKit.list(carryText, "y", 0)
UiKit.Label(carryText, "Carrying oil", "H3", { LayoutOrder = 1, TextSize = 16 })
UiKit.Label(carryText, "Pour it into the fuel tank, or reload a cannon.", "BodySmall", { LayoutOrder = 2 })

-- prompt cards (primary + one secondary)
local function promptCard(name, order, compact)
	local b = UiKit.new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.SurfacePrimary,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, if compact then 46 else 56),
		LayoutOrder = order,
		Visible = false,
		Selectable = false,
		ClipsDescendants = true,
	}, bottom)
	UiKit.round(b, UiKit.Radius.panel)
	local stroke = UiKit.border(b, C.BorderStructural, 1, 0.3)
	local key = UiKit.new("Frame", {
		Name = "Key",
		BackgroundColor3 = C.SurfaceElevated,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(if compact then 30 else 36, if compact then 30 else 36),
	}, b)
	UiKit.round(key, UiKit.Radius.control)
	UiKit.border(key, C.BorderBrassBright, 1, 0.2)
	local keyText = UiKit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = F.LabelBold,
		TextSize = if compact then 15 else 17,
		TextColor3 = C.TextPrimary,
		Size = UDim2.fromScale(1, 1),
	}, key)
	local keyImage = UiKit.new("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Visible = false,
	}, key)
	local left = (if compact then 30 else 36) + 20
	local action = UiKit.new("TextLabel", {
		Name = "Action",
		BackgroundTransparency = 1,
		FontFace = F.BodyBold,
		TextSize = if compact then 15 else 17,
		TextColor3 = C.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, left, 0, if compact then 5 else 8),
		Size = UDim2.new(1, -left - 10, 0, 20),
	}, b)
	local object = UiKit.new("TextLabel", {
		Name = "Object",
		BackgroundTransparency = 1,
		FontFace = F.Body,
		TextSize = if compact then 13 else 14,
		TextColor3 = C.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, left, 0, if compact then 24 else 30),
		Size = UDim2.new(1, -left - 10, 0, 18),
	}, b)
	local hold = UiKit.new("Frame", {
		Name = "Hold",
		BackgroundColor3 = C.AccentLighthouse,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0, 0, 0, 3),
		ZIndex = 3,
	}, b)
	return { button = b, stroke = stroke, keyText = keyText, keyImage = keyImage, action = action, object = object, hold = hold, prompt = nil }
end
local primaryCard = promptCard("PrimaryPrompt", 3, false)
local secondaryCard = promptCard("SecondaryPrompt", 4, true)

-- keeper controls (only for the player at the lamp)
local keeperRow = UiKit.new("Frame", {
	Name = "KeeperControls",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 5,
	Visible = false,
}, bottom)
UiKit.list(keeperRow, "y", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
local focusWarn = UiKit.Tag(keeperRow, "Focused beam burns fuel faster", "StateWarning", { layoutOrder = 1 })
local keeperButtons = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 }, keeperRow)
UiKit.list(keeperButtons, "x", 10)
local beamButton = UiKit.Button(keeperButtons, "Focus beam", { name = "ToggleBeam", variant = "secondary", minWidth = 150, layoutOrder = 1, onClick = function()
	lampAction:FireServer("toggleMode")
end })
local leaveButton = UiKit.Button(keeperButtons, "Leave lamp", { name = "LeaveLamp", variant = "ghost", minWidth = 130, layoutOrder = 2, onClick = function()
	lampAction:FireServer("leave")
end })

---------------------------------------------------------------------
-- BINDINGS
---------------------------------------------------------------------

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function inputMode()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif last == Enum.UserInputType.Gamepad1 or last == Enum.UserInputType.Gamepad2 then
		return "gamepad"
	end
	return "keyboard"
end

local function keySuffix(key)
	return if inputMode() == "keyboard" then "  ·  " .. key else ""
end

-- voyage status ------------------------------------------------------
local lastPhase
local function refreshVoyage()
	local phase = state:GetAttribute("Phase") or "Waiting"
	local night = state:GetAttribute("Night") or 0
	local total = Config.NIGHTS_TO_WIN
	local timeLeft = state:GetAttribute("TimeLeft") or 0
	local title, sub, showTimer = "", "", true
	if phase == "Waiting" then
		title, sub, showTimer = "WAITING FOR KEEPERS", "Join the crew at the ship's wheel", false
	elseif phase == "Intermission" then
		title, sub = "SETTING SAIL", "The crew is boarding"
	elseif phase == "Prologue" then
		title, sub, showTimer = "THE STORM HITS", "Restore the light", false
	elseif phase == "Day" then
		title, sub = string.format("DAY %d OF %d", night, total), "Prepare for the night"
	elseif phase == "Night" then
		title, sub = string.format("NIGHT %d OF %d", night, total), "Keep the light alive"
	elseif phase == "Victory" then
		title, sub, showTimer = "VICTORY", "The light survived", false
	elseif phase == "Defeat" then
		local reason = state:GetAttribute("Reason") or ""
		if #reason > 52 then
			reason = reason:sub(1, 50) .. "..."
		end
		title, sub, showTimer = "DEFEAT", reason, false
	end
	voyageTitle.Text = title
	voyageSub.Text = sub
	voyageTitle.TextColor3 = if phase == "Defeat" then C.StateDanger elseif phase == "Victory" then C.AccentLighthouse else C.TextPrimary
	timerChip.Visible = showTimer
	timerText.Text = formatTime(timeLeft)
	timerText.TextColor3 = if phase == "Night" and timeLeft <= 10 then C.AccentLighthouseSoft else C.TextPrimary
	pips.Visible = night > 0 and ISLAND_PHASES[phase] == true
	for i, pip in pipFrames do
		local done = i < night or (i == night and phase == "Victory")
		local current = i == night and (phase == "Night" or phase == "Day" or phase == "Defeat")
		pip.d.BackgroundTransparency = if done or (current and phase ~= "Day") then 0 else 1
		pip.d.BackgroundColor3 = if current then (if phase == "Defeat" then C.StateDanger else C.AccentLighthouse) else C.TextSecondary
		pip.stroke.Color = if current then C.AccentLighthouse elseif done then C.TextSecondary else C.BorderStructural
	end
	if phase ~= lastPhase then
		if lastPhase ~= nil then
			voyageScale.Scale = 1.08 -- a short settle marks the transition
			UiKit.tween(voyageScale, UiKit.Motion.slow, { Scale = 1 })
		end
		lastPhase = phase
	end
end

-- lamp fuel, blackout alarm, beam ------------------------------------
local lastAlarmSecond
local function refreshAlarm()
	local dark = state:GetAttribute("DarkSeconds") or 0
	local phase = state:GetAttribute("Phase")
	if dark > 0 and LIT_PHASES[phase] then
		local left = math.max(0, math.ceil(Config.DARK_GRACE_SECONDS - dark))
		alarm.Visible = true
		if phase == "Prologue" then
			alarmBody.Text = "Carry oil to the fuel tank behind the lighthouse."
			alarmCount.Text = ""
		else
			alarmBody.Text = "Refuel the fuel tank or the voyage is lost."
			alarmCount.Text = left .. "s"
		end
		local beat = left % 2 == 0 -- one pulse per second, nothing continuous
		alarmStroke.Color = if beat then C.StateDanger else C.TextPrimary
		alarmCount.TextColor3 = if beat then C.StateDanger else C.TextPrimary
		if lastAlarmSecond ~= left then
			lastAlarmSecond = left
			SoundFx.play2D("denied", 1.4)
		end
	else
		alarm.Visible = false
		lastAlarmSecond = nil
	end
end

local function refreshBeam()
	local phase = state:GetAttribute("Phase")
	local mode = state:GetAttribute("BeamMode")
	local keeperId = state:GetAttribute("KeeperUserId") or 0
	local dark = (state:GetAttribute("DarkSeconds") or 0) > 0 or (state:GetAttribute("Fuel") or 0) <= 0
	beamRow.Visible = LIT_PHASES[phase] == true
	local text, glyph, color
	if dark then
		text, glyph, color = "LAMP DARK", "dark", C.StateDanger
	elseif keeperId == 0 then
		text, glyph, color = "BEAM · AUTO-SWEEP", "wide", C.AccentSea
	elseif mode == "focused" then
		text, glyph, color = "BEAM · FOCUSED", "focused", C.AccentLighthouse
	else
		text, glyph, color = "BEAM · WIDE", "wide", C.TextPrimary
	end
	beamText.Text = text
	beamText.TextColor3 = color
	drawBeamGlyph(glyph, color)
	beamTag.Visible = not dark and keeperId ~= 0 and mode == "focused"
	beamTag.Text = string.format("%sX FUEL", tostring(Config.FOCUSED_FUEL_MULTIPLIER or 2.5))
	local keeper = keeperId ~= 0 and Players:GetPlayerByUserId(keeperId)
	keeperText.Visible = (keeper and keeper ~= player and beamRow.Visible) == true
	keeperText.Text = if keeper then "Keeper: " .. keeper.DisplayName else ""
	-- keeper controls
	local me = keeperId == player.UserId
	keeperRow.Visible = me
	focusWarn.Visible = me and mode == "focused" and not compact
	beamButton.Text = (if mode == "focused" then "WIDE BEAM" else "FOCUS BEAM") .. keySuffix("F")
	beamButton:SetAttribute("BaseText", beamButton.Text)
	leaveButton.Text = "LEAVE LAMP" .. keySuffix("Q")
	leaveButton:SetAttribute("BaseText", leaveButton.Text)
end

local function refreshFuel()
	local max = state:GetAttribute("MaxFuel") or Config.MAX_FUEL
	fuel.set((state:GetAttribute("Fuel") or 0) / math.max(1, max))
	refreshAlarm()
	refreshBeam()
end

local function refreshTower()
	local max = state:GetAttribute("MaxIntegrity") or Config.MAX_INTEGRITY
	tower.set((state:GetAttribute("Integrity") or 0) / math.max(1, max))
end

-- shells ----------------------------------------------------------------
local lastShells = state:GetAttribute("Shells") or 0
local function refreshShells()
	if shells then
		local n = state:GetAttribute("Shells") or 0
		shells.set(n, n > lastShells)
		lastShells = n
	end
end

-- player health -------------------------------------------------------
local humanoidConnections = {}
local function bindHumanoid(character)
	for _, c in humanoidConnections do
		c:Disconnect()
	end
	table.clear(humanoidConnections)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	health.setNote(nil)
	health.setMax(humanoid.MaxHealth)
	health.reset(humanoid.Health)
	table.insert(humanoidConnections, humanoid.HealthChanged:Connect(function(value)
		health.set(value)
	end))
	table.insert(humanoidConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		health.setMax(humanoid.MaxHealth)
		health.set(humanoid.Health)
	end))
	table.insert(humanoidConnections, humanoid.Died:Connect(function()
		health.setNote("HEALTH · DOWN")
		health.set(0)
	end))
end

-- weapon ---------------------------------------------------------------
local shownWeaponId
local cooldownConnection
local function findWeapon(container)
	if not container then
		return nil
	end
	for _, t in container:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("WeaponId") then
			return t
		end
	end
	return nil
end

local function startCooldown(id)
	local stats = Weapons[id]
	if not stats or not stats.cooldown or stats.cooldown <= 0 then
		return
	end
	local started, length = os.clock(), stats.cooldown
	cooldownTrack.Visible = true
	weaponState.Text = "RELOADING"
	weaponState.TextColor3 = C.AccentLighthouse
	if cooldownConnection then
		cooldownConnection:Disconnect()
	end
	cooldownConnection = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - started) / length
		if alpha >= 1 then
			cooldownConnection:Disconnect()
			cooldownConnection = nil
			cooldownTrack.Visible = false
			weaponState.Text = "READY"
			weaponState.TextColor3 = C.AccentSea
			return
		end
		cooldownFill.Size = UDim2.fromScale(alpha, 1)
	end)
end

local function refreshWeapon()
	local held = findWeapon(player.Character)
	local stowed = if held then nil else findWeapon(player:FindFirstChildOfClass("Backpack"))
	local tool = held or stowed
	local isKeeper = (state:GetAttribute("KeeperUserId") or 0) == player.UserId
	weaponRow.Visible = tool ~= nil and not isKeeper
	if not tool then
		return
	end
	local id = tool:GetAttribute("WeaponId")
	if id ~= shownWeaponId then
		shownWeaponId = id
		weaponPreview:setItem(id)
		weaponName.Text = (Items[id] and Items[id].name) or tool.Name
		weaponScale.Scale = 1.06 -- switch feedback
		UiKit.tween(weaponScale, UiKit.Motion.base, { Scale = 1 })
	end
	if not tool:GetAttribute("HudHooked") then
		tool:SetAttribute("HudHooked", true)
		tool.Activated:Connect(function()
			if player:GetAttribute("MenuOpen") then
				return
			end
			startCooldown(tool:GetAttribute("WeaponId"))
		end)
	end
	weaponName.TextColor3 = if held then C.TextPrimary else C.TextSecondary
	if not cooldownConnection then
		weaponState.Text = if held then "IN HAND · READY"
			elseif inputMode() == "keyboard" then "STOWED · PRESS 1"
			else "STOWED · USE THE HOTBAR"
		weaponState.TextColor3 = if held then C.AccentSea else C.TextMuted
	end
end

-- cannon nearby ---------------------------------------------------------
local pads = {}
local function scanPads()
	table.clear(pads)
	local island = Workspace:FindFirstChild("Island")
	if not island then
		return
	end
	for _, d in island:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("CannonLevel") ~= nil then
			table.insert(pads, d)
		end
	end
end

local shownPad, shownAmmoType
local function refreshCannon()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local isKeeper = (state:GetAttribute("KeeperUserId") or 0) == player.UserId
	local best, bestDistance = nil, 14
	if root and not isKeeper and gui.Enabled then
		for _, pad in pads do
			if pad.Parent and (pad:GetAttribute("CannonLevel") or 0) > 0 then
				local distance = (pad.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = pad, distance
				end
			end
		end
	end
	-- phones: the cannon's own floating label already shows its ammo, so the card stays hidden
	cannonCard.Visible = best ~= nil and not compact
	if not best then
		shownPad = nil
		return
	end
	local ammo, maxAmmo = best:GetAttribute("Ammo") or 0, math.max(1, best:GetAttribute("MaxAmmo") or 1)
	cannonTitle.Text = string.format("CANNON · LEVEL %d", best:GetAttribute("CannonLevel") or 1)
	local hull, hullMax = best:GetAttribute("CannonHealth") or 0, best:GetAttribute("CannonMaxHealth") or 0
	cannonHull.Text = if hullMax > 0 then string.format("Hull %d%%", math.floor(hull / hullMax * 100 + 0.5)) else ""
	cannonHull.TextColor3 = if hullMax > 0 and hull / hullMax < 0.35 then C.StateDanger else C.TextSecondary
	cannonAmmo.frame:FindFirstChild("Label").Text = string.upper(best:GetAttribute("AmmoName") or "Ammo")
	cannonAmmo.set(ammo / maxAmmo, if ammo == 0 then "EMPTY · BRING OIL" else string.format("%d / %d", ammo, maxAmmo))
	local ammoType = best:GetAttribute("AmmoType")
	if best == shownPad and ammoType ~= shownAmmoType then
		-- ammunition changed (for example Fire Shells loaded): flash the card frame once
		local stroke = cannonCard:FindFirstChildOfClass("UIStroke")
		stroke.Color = C.AccentLighthouse
		stroke.Transparency = 0
		task.delay(0.5, function()
			stroke.Color = C.BorderStructural
			stroke.Transparency = 0.4
		end)
	end
	shownPad, shownAmmoType = best, ammoType
end

-- carried oil -------------------------------------------------------------
local function refreshCarry()
	local isKeeper = (state:GetAttribute("KeeperUserId") or 0) == player.UserId
	carryCard.Visible = gui.Enabled and player:GetAttribute("CarryingOil") == true and not isKeeper
		and not (compact and cannonCard.Visible)
	sideStack.Visible = carryCard.Visible or cannonCard.Visible
end

-- interaction prompts -----------------------------------------------------
local shownPrompts = {}
local holdStart = {}

local function claim(object)
	if object:IsA("ProximityPrompt") then
		object.Style = Enum.ProximityPromptStyle.Custom -- drawn by this script; the engine still handles input
	end
end
for _, d in Workspace:GetDescendants() do
	claim(d)
end
Workspace.DescendantAdded:Connect(claim)

local function promptPosition(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

local function keyName(keyCode)
	local names = { One = "1", Two = "2", Three = "3", Four = "4", Return = "ENTER", LeftShift = "SHIFT" }
	return names[keyCode.Name] or keyCode.Name
end

local function fillCard(cardObj, prompt)
	cardObj.prompt = prompt
	cardObj.button.Visible = prompt ~= nil
	cardObj.hold.Size = UDim2.new(0, 0, 0, 3)
	if not prompt then
		return
	end
	local holds = prompt.HoldDuration > 0
	cardObj.action.Text = if prompt.ActionText ~= "" then prompt.ActionText else "Interact"
	local objectText = prompt.ObjectText
	if holds then
		objectText = (if objectText ~= "" then objectText .. "  ·  " else "") .. "Hold"
	end
	cardObj.object.Text = objectText
	local mode = inputMode()
	cardObj.keyImage.Visible = false
	cardObj.keyText.Visible = true
	cardObj.keyText.TextSize = if mode == "keyboard" then 17 else 12
	if mode == "gamepad" then
		local image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		if image and image ~= "" then
			cardObj.keyImage.Image = image
			cardObj.keyImage.Visible = true
			cardObj.keyText.Visible = false
		else
			cardObj.keyText.Text = keyName(prompt.GamepadKeyCode):gsub("Button", "")
		end
	elseif mode == "touch" then
		cardObj.keyText.Text = if holds then "HOLD" else "TAP"
	else
		cardObj.keyText.Text = keyName(prompt.KeyboardKeyCode)
	end
end

local function renderPrompts()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local list = {}
	for prompt in shownPrompts do
		if prompt.Parent and prompt.Enabled then
			table.insert(list, prompt)
		else
			shownPrompts[prompt] = nil
		end
	end
	if root then
		table.sort(list, function(a, b)
			local pa, pb = promptPosition(a), promptPosition(b)
			local da = if pa then (pa - root.Position).Magnitude else math.huge
			local db = if pb then (pb - root.Position).Magnitude else math.huge
			return da < db
		end)
	end
	-- one main action, plus at most one alternative (e.g. Upgrade + Reload at a cannon).
	-- None while you are the Keeper (the lamp view has its own controls) or once the voyage has ended.
	local phase = state:GetAttribute("Phase")
	if (state:GetAttribute("KeeperUserId") or 0) == player.UserId or phase == "Victory" or phase == "Defeat" then
		table.clear(list)
	end
	fillCard(primaryCard, list[1])
	fillCard(secondaryCard, list[2])
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	claim(prompt)
	shownPrompts[prompt] = true
	renderPrompts()
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shownPrompts[prompt] = nil
	holdStart[prompt] = nil
	renderPrompts()
end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
	if who == player then
		holdStart[prompt] = os.clock()
	end
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	holdStart[prompt] = nil
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	holdStart[prompt] = nil
	for _, cardObj in { primaryCard, secondaryCard } do
		if cardObj.prompt == prompt then
			cardObj.stroke.Color = C.AccentLighthouse
			cardObj.stroke.Transparency = 0
			task.delay(0.35, function()
				cardObj.stroke.Color = C.BorderStructural
				cardObj.stroke.Transparency = 0.3
			end)
		end
	end
end)

-- touch / mouse: press and hold the card itself
for _, cardObj in { primaryCard, secondaryCard } do
	cardObj.button.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and cardObj.prompt then
			cardObj.pressed = cardObj.prompt
			cardObj.prompt:InputHoldBegin()
		end
	end)
	cardObj.button.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and cardObj.pressed then
			cardObj.pressed:InputHoldEnd()
			cardObj.pressed = nil
		end
	end)
end

-- hold progress bars
RunService.RenderStepped:Connect(function()
	for _, cardObj in { primaryCard, secondaryCard } do
		local prompt = cardObj.prompt
		local started = prompt and holdStart[prompt]
		if started and prompt.HoldDuration > 0 then
			cardObj.hold.Size = UDim2.new(math.clamp((os.clock() - started) / prompt.HoldDuration, 0, 1), 0, 0, 3)
		elseif cardObj.hold.Size.X.Scale ~= 0 then
			cardObj.hold.Size = UDim2.new(0, 0, 0, 3)
		end
	end
end)

-- boss bars (one per live big monster; never an empty bar) ----------------
local bossBars = {}
local function makeBossBar(entry)
	local frame = UiKit.new("Frame", {
		Name = "Boss_" .. entry.Name,
		BackgroundColor3 = C.SurfaceBase,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, bossList)
	UiKit.round(frame, UiKit.Radius.card)
	UiKit.border(frame, C.StateDanger, 1, 0.5)
	UiKit.pad(frame, 8, 12, 9, 12)
	local name = UiKit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = F.LabelBold,
		TextSize = 17,
		TextColor3 = C.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.7, 0, 0, 20),
	}, frame)
	local readout = UiKit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = F.Numeric,
		TextSize = 15,
		TextColor3 = C.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 20),
	}, frame)
	name.Name = "BossName"
	readout.Name = "BossReadout"
	UiKit.fitHeader(name, readout)
	local track = UiKit.Inset(frame, { Name = "Track", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 12) })
	local trail = UiKit.new("Frame", { BackgroundColor3 = C.HealthTrail, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, track)
	UiKit.round(trail, 3)
	local fill = UiKit.new("Frame", { BackgroundColor3 = C.StateDanger, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, track)
	UiKit.round(fill, 3)
	for i = 1, 9 do
		UiKit.new("Frame", {
			BackgroundColor3 = C.SurfaceBase,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(i / 10, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 4,
		}, track)
	end
	local bar = { frame = frame }
	local shownAlpha, token = nil, 0
	local displayName = entry:GetAttribute("DisplayName") or "Big monster"
	local function update()
		local h = entry:GetAttribute("Health") or 0
		local m = math.max(1, entry:GetAttribute("Max") or 1)
		local alpha = math.clamp(h / m, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		if shownAlpha and alpha < shownAlpha then
			trail.Size = UDim2.fromScale(shownAlpha, 1)
			token += 1
			local mine = token
			task.delay(0.35, function()
				if mine == token then
					UiKit.tween(trail, 0.3, { Size = UDim2.fromScale(alpha, 1) })
				end
			end)
		else
			trail.Size = UDim2.fromScale(alpha, 1)
		end
		shownAlpha = alpha
		readout.Text = string.format("%d / %d", h, m)
		local outcome = entry:GetAttribute("Outcome")
		if outcome == "killed" then
			name.Text = string.upper(displayName) .. " · DEFEATED"
			name.TextColor3 = C.StateSuccess
		elseif outcome == "fled" then
			name.Text = string.upper(displayName) .. " · RETREATED"
			name.TextColor3 = C.TextSecondary
		else
			name.Text = string.upper(displayName)
		end
	end
	entry.AttributeChanged:Connect(function(attribute)
		update()
		if attribute == "Outcome" and entry:GetAttribute("Outcome") == "killed" then
			UiKit.Toast(promptRoot, displayName .. " was driven off for good.", "success", { title = "Big monster defeated" })
		end
	end)
	update()
	bossBars[entry] = bar
end

local function removeBossBar(entry)
	local bar = bossBars[entry]
	if bar then
		bar.frame:Destroy()
		bossBars[entry] = nil
	end
end

local function refreshWarning()
	warning.Visible = (state:GetAttribute("BigWarning") or "") ~= "" and next(bossBars) == nil and ISLAND_PHASES[state:GetAttribute("Phase")] == true
end

local function bindBosses(folder)
	for _, entry in folder:GetChildren() do
		makeBossBar(entry)
	end
	folder.ChildAdded:Connect(function(entry)
		makeBossBar(entry)
		refreshWarning()
		task.defer(applyLayout)
	end)
	folder.ChildRemoved:Connect(function(entry)
		removeBossBar(entry)
		refreshWarning()
		task.defer(applyLayout)
	end)
end
if state:FindFirstChild("Bosses") then
	bindBosses(state.Bosses)
end
state.ChildAdded:Connect(function(child)
	if child.Name == "Bosses" then
		bindBosses(child)
	end
end)

-- server messages and pickups --------------------------------------------
local function noticeKind(text)
	local lower = string.lower(text)
	if lower:find("lost") or lower:find("defeat") or lower:find("destroyed") or lower:find("broke") then
		return "danger"
	elseif lower:find("big") or lower:find("failing") or lower:find("low") or lower:find("hurry") or lower:find("warning") then
		return "warning"
	elseif lower:find("sold") or lower:find("survived") or lower:find("joined") or lower:find("pearl") or lower:find("bought") then
		return "success"
	end
	return "info"
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	UiKit.Toast(promptRoot, text, noticeKind(text))
end)

remotes:WaitForChild("LootCollected").OnClientEvent:Connect(function(kind, value)
	SoundFx.play2D("loot", if kind == "Pearls" then 1.9 elseif kind == "BlackPearl" then 1.6 elseif kind == "SeaGlass" then 1.3 else 1)
	local amount = tonumber(value) or 1
	if kind == "Shells" then
		UiKit.Pickup(hudRoot, { kind = "Shells", amount = amount })
	elseif kind == "Pearls" then
		UiKit.Pickup(hudRoot, { kind = "Pearls", amount = amount })
	else
		local item = Items[kind]
		UiKit.Pickup(hudRoot, { kind = "loot", label = if item then item.name else kind, category = "Materials", amount = amount, key = "loot_" .. kind })
	end
end)

local warnedSave = false
local function refreshSaveWarning()
	if not warnedSave and gui.Enabled and player:GetAttribute("SaveUnavailable") then
		warnedSave = true
		UiKit.Toast(promptRoot, "You can keep playing. Pearls earned now may not be kept.", "warning", { title = "Progress isn't saving", duration = 6 })
	end
end

---------------------------------------------------------------------
-- LAYOUT (landscape first; responsive at every size; inside safe areas)
---------------------------------------------------------------------

local function updateStacking()
	-- notices start under the top-center cluster (and the alarm), pickups under the top-right cluster
	local top = hudRoot.AbsolutePosition.Y
	alarm.AnchorPoint = Vector2.new(0.5, 0)
	local alarmOn = alarm.Visible
	local noticeTop
	-- Glass HUD (Oct 13): the voyage pill lives in the top bar row, so top-center is the lamp's slot.
	-- When the lamp goes out, the alarm banner takes the top and the fuel gauge steps aside (every size).
	local onIsland = ISLAND_PHASES[state:GetAttribute("Phase")] == true
	voyage.Visible = true
	fuelPlate.Visible = onIsland and not alarmOn
	bossList.Visible = onIsland and not (compact and alarmOn)
	alarm.Position = UDim2.new(0.5, 0, 0, 8)
	topCenter.Position = UDim2.new(0.5, 0, 0, if alarmOn then 8 + alarm.AbsoluteSize.Y + 6 else 8)
	if compact then
		-- phones: one notice at a time, at the top (under the alarm when it shows)
		noticeTop = if alarmOn then 8 + alarm.AbsoluteSize.Y + 6 else 8
	else
		local centerBottom = topCenter.AbsolutePosition.Y + topCenter.AbsoluteSize.Y - top
		noticeTop = centerBottom + 8
	end
	promptRoot:SetAttribute("NoticeTop", if gui.Enabled then noticeTop else 140)
	-- keep notices already on screen in the right place after a layout change (e.g. rotation)
	local toastStack = promptRoot:FindFirstChild("ToastStack")
	if toastStack then
		toastStack.Position = UDim2.new(0.5, 0, 0, promptRoot:GetAttribute("NoticeTop"))
		toastStack.Size = UDim2.fromOffset(promptRoot:GetAttribute("NoticeWidth") or math.clamp(promptRoot.AbsoluteSize.X * 0.5, 260, 400), 0)
	end
	local rightBottom = topRight.AbsolutePosition.Y + topRight.AbsoluteSize.Y - top
	sideStack.Position = UDim2.new(1, -12, 0, rightBottom + 8)
	if sideStack.Visible then
		rightBottom = sideStack.AbsolutePosition.Y + sideStack.AbsoluteSize.Y - top
	end
	hudRoot:SetAttribute("PickupTop", rightBottom + 10)
end

local function isTouch()
	if simulated then
		return simulated.touch
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function applyLayout()
	local size = hudRoot.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local bp = UiKit.Breakpoint(size)
	local touch = isTouch()
	compact = bp == "phone"
	local leftW, fuelW, rightW, bossW, alarmW
	if compact then
		leftW, fuelW, rightW, bossW, alarmW = 178, 210, 174, 234, 300
	elseif bp == "tablet" then
		leftW, fuelW, rightW, bossW, alarmW = 250, 320, 250, 360, 420
	else
		leftW, fuelW, rightW, bossW, alarmW = 290, 380, 290, 440, 460
	end
	topLeft.Size = UDim2.fromOffset(leftW, 0)
	topRight.Size = UDim2.fromOffset(rightW, 0)
	topCenter.Size = UDim2.fromOffset(math.max(fuelW, bossW) + 24, 0)
	fuelPlate.Size = UDim2.fromOffset(fuelW + 24, 0)
	bossList.Size = UDim2.fromOffset(bossW, 0)
	promptRoot:SetAttribute("NoticeLimit", if compact then 1 else nil)
	promptRoot:SetAttribute("NoticeWidth", if compact then 260 else nil)
	hudRoot:SetAttribute("PickupLimit", if compact then 2 else nil)
	-- boss bars: slimmer on phones; two or more sit side by side so the column stays short
	local bossCount = 0
	for _ in bossBars do
		bossCount += 1
	end
	local bossLayout = bossList:FindFirstChildOfClass("UIListLayout")
	local sideBySide = compact and bossCount > 1
	bossLayout.FillDirection = if sideBySide then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	for _, bar in bossList:GetChildren() do
		local bossName, bossReadout, track = bar:FindFirstChild("BossName"), bar:FindFirstChild("BossReadout"), bar:FindFirstChild("Track")
		if bossName and bossReadout and track then
			bar.Size = if sideBySide then UDim2.new(0.5, -3, 0, 0) else UDim2.new(1, 0, 0, 0)
			bossName.TextSize = if compact then 14 else 17
			bossReadout.TextSize = if compact then 13 else 15
			bossName.Size = UDim2.new(bossName.Size.X.Scale, bossName.Size.X.Offset, 0, if compact then 16 else 20)
			bossReadout.Size = UDim2.new(0, 0, 0, if compact then 16 else 20)
			track.Position = UDim2.fromOffset(0, if compact then 20 else 26)
			track.Size = UDim2.new(1, 0, 0, if compact then 8 else 12)
			local pad = bar:FindFirstChildOfClass("UIPadding")
			if pad then
				pad.PaddingTop = UDim.new(0, if compact then 6 else 8)
				pad.PaddingBottom = UDim.new(0, if compact then 6 else 9)
				pad.PaddingLeft = UDim.new(0, if compact then 8 else 12)
				pad.PaddingRight = UDim.new(0, if compact then 8 else 12)
			end
		end
	end
	alarm.Size = UDim2.fromOffset(alarmW, if compact then 60 else 76)
	alarmBody.TextSize = if compact then 13 else 15
	alarmTitle.TextSize = if compact then 20 else 24
	voyageSub.Visible = not compact
	warningSub.Visible = not compact
	voyage.Size = UDim2.fromOffset(0, if compact then 34 else 40)
	-- the weapon now lives in its own slot at the bottom (glassLayout sizes it)
	-- prompts: between the joystick zone (left 40%) and the jump button; above the hotbar on desktop
	local bottomLayout = bottom:FindFirstChildOfClass("UIListLayout")
	if compact then
		-- from just right of the joystick zone (40% width) to the right edge; ends above the jump button
		bottom.AnchorPoint = Vector2.new(0, 1)
		bottom.Position = UDim2.new(0.4, 8, 1, -92)
		bottom.Size = UDim2.new(0.6, -20, 0, 0)
		bottomLayout.FillDirection = Enum.FillDirection.Horizontal
		bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		for _, c in { primaryCard, secondaryCard } do
			c.button.Size = UDim2.new(0.5, -4, 0, 52)
		end
	else
		bottom.AnchorPoint = Vector2.new(0.5, 1)
		bottom.Size = UDim2.fromOffset(330, 0)
		bottom.Position = if touch then UDim2.new(0.6, 0, 1, -220) else UDim2.new(0.5, 0, 1, -126) -- above the weapon slot
		bottomLayout.FillDirection = Enum.FillDirection.Vertical
		bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		primaryCard.button.Size = UDim2.new(1, 0, 0, 56)
		secondaryCard.button.Size = UDim2.new(1, 0, 0, 46)
	end
	cannonCard.Parent = sideStack
	carryCard.Parent = sideStack
	sideStack.Size = UDim2.fromOffset(rightW, 0)
	cannonHead.Visible = not compact -- phones: ammo row only (level is on the upgrade prompt)
	-- the top-right cluster starts at the top (Oct 13: the BAG bar became a round icon at the bottom right)
	topRight.Position = UDim2.new(1, -12, 0, 8)
	if glassLayout then
		glassLayout()
	end
	updateStacking()
end

local function refreshVisibility()
	gui.Enabled = player:GetAttribute("Ready") == true
	local onIsland = ISLAND_PHASES[state:GetAttribute("Phase")] == true
	fuelPlate.Visible = onIsland and not alarm.Visible
	rightPlate.Visible = onIsland
	bossList.Visible = onIsland and not (compact and alarm.Visible)
	bottom.Visible = not player:GetAttribute("MenuOpen")
	refreshWarning()
	refreshCarry()
	refreshSaveWarning()
	task.defer(applyLayout)
end

---------------------------------------------------------------------
-- WIRING
---------------------------------------------------------------------

state.AttributeChanged:Connect(function(name)
	if name == "Phase" or name == "Night" or name == "TimeLeft" or name == "Reason" then
		refreshVoyage()
		if name == "Phase" then
			refreshVisibility()
			refreshFuel()
			renderPrompts()
		end
	elseif name == "Fuel" or name == "MaxFuel" or name == "DarkSeconds" then
		refreshFuel()
		task.defer(updateStacking)
	elseif name == "Integrity" or name == "MaxIntegrity" then
		refreshTower()
	elseif name == "BeamMode" then
		refreshBeam()
	elseif name == "KeeperUserId" then
		refreshBeam()
		refreshWeapon()
		refreshCarry()
		renderPrompts()
	elseif name == "Shells" then
		refreshShells()
	elseif name == "BigWarning" then
		refreshWarning()
	end
end)

for _, attribute in { "Ready", "MenuOpen", "SaveUnavailable" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshVisibility)
end
player:GetAttributeChangedSignal("CarryingOil"):Connect(refreshCarry)

local function onCharacter(character)
	task.spawn(bindHumanoid, character)
	character.ChildAdded:Connect(refreshWeapon)
	character.ChildRemoved:Connect(refreshWeapon)
	refreshWeapon()
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
local function onBackpack(backpack)
	if backpack:IsA("Backpack") then
		backpack.ChildAdded:Connect(refreshWeapon)
		backpack.ChildRemoved:Connect(refreshWeapon)
		refreshWeapon()
	end
end
player.ChildAdded:Connect(onBackpack)
if player:FindFirstChildOfClass("Backpack") then
	onBackpack(player:FindFirstChildOfClass("Backpack"))
end

UserInputService.LastInputTypeChanged:Connect(function()
	refreshBeam()
	refreshWeapon()
	renderPrompts()
end)
hudRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
topCenter:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateStacking)
topRight:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateStacking)
sideStack:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateStacking)
sideStack:GetPropertyChangedSignal("Visible"):Connect(updateStacking)

-- light polling for things without change events (distance to cannons and prompts)
task.spawn(function()
	local sinceScan = math.huge
	while true do
		sinceScan += 0.2
		if sinceScan >= 3 then
			sinceScan = 0
			scanPads()
		end
		refreshCannon()
		refreshCarry()
		if next(shownPrompts) then
			renderPrompts()
		end
		task.wait(0.2)
	end
end)

---------------------------------------------------------------------
-- GLASS HUD (owner, Oct 13 2026, from the owner's mock-up)
-- Night-navy glass panels with a soft blue glow. Menus keep the wood skin; the in-game HUD, prompts
-- and notices use glass. Layout: voyage chip in the top-bar row (top right), health top-left,
-- BAG / tower / lamp down the right, lamp fuel (or the blackout banner) top-center, the action
-- prompt above a weapon slot at the bottom, Shells bottom-right (phones: under health).
---------------------------------------------------------------------

local GLASS = {
	bg = Color3.fromRGB(12, 20, 40),
	bgT = 0.18,
	glow = Color3.fromRGB(104, 156, 255),
	glowT = 0.45,
	text = Color3.fromRGB(240, 244, 255),
	heart = Color3.fromRGB(255, 76, 110),
	danger = Color3.fromRGB(255, 70, 104),
	dangerBg = Color3.fromRGB(58, 12, 30),
	chip = Color3.fromRGB(26, 52, 110),
	radius = 14,
}
local function rgbKey(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
-- the wood skin warms the shared colour tokens; the HUD maps them back to night navy
local NAVY = {}
for token, navy in {
	SurfaceBase = Color3.fromRGB(9, 14, 24),
	SurfacePrimary = Color3.fromRGB(15, 23, 37),
	SurfaceSecondary = Color3.fromRGB(27, 37, 50),
	SurfaceElevated = Color3.fromRGB(37, 50, 66),
	SurfaceHover = Color3.fromRGB(46, 61, 80),
	SurfaceInset = Color3.fromRGB(10, 16, 27),
	BorderSubtle = Color3.fromRGB(48, 62, 80),
	StateDisabled = Color3.fromRGB(46, 54, 66),
} do
	NAVY[rgbKey(C[token])] = navy
end
local BRASS = rgbKey(C.BorderStructural)
local GLASS_PANELS = {
	SurvivorPlate = true,
	LighthousePlate = true,
	FuelPlate = true,
	BlackoutAlarm = true,
	BigWarning = true,
	CannonCard = true,
	CarryCard = true,
	PrimaryPrompt = true,
	SecondaryPrompt = true,
	Voyage = true,
	LampPill = true,
	ShellsPill = true,
	WeaponSlot = true,
}

local function glassStroke(s)
	if rgbKey(s.Color) == BRASS then
		s.Color = GLASS.glow
	end
	if not s:GetAttribute("GlassHooked") then
		s:SetAttribute("GlassHooked", true)
		s:GetPropertyChangedSignal("Color"):Connect(function()
			if rgbKey(s.Color) == BRASS then
				s.Color = GLASS.glow -- flashes that return to brass return to glow instead
			end
		end)
	end
end

-- HUD buttons drop the wood art and become glass
local function deskin(host)
	host.BackgroundColor3 = GLASS.bg
	host.BackgroundTransparency = GLASS.bgT
	if host:IsA("TextButton") then
		host.TextColor3 = GLASS.text
		host:SetAttribute("BaseColor", GLASS.bg)
		host:SetAttribute("HoverColor", Color3.fromRGB(30, 48, 88))
		host:SetAttribute("BaseTextColor", GLASS.text)
		host:SetAttribute("GhostButton", nil)
	end
	local corner = host:FindFirstChildOfClass("UICorner") or UiKit.round(host, 12)
	corner.CornerRadius = UDim.new(0, 12)
	local s = host:FindFirstChildOfClass("UIStroke") or UiKit.border(host, GLASS.glow, 1.5, GLASS.glowT)
	s.Enabled = true
	s.Color = GLASS.glow
	s.Transparency = GLASS.glowT
	s.Thickness = 1.5
end

local function restyle(o)
	if o:IsA("ImageLabel") and o.Name == "Skin" then
		local host = o.Parent
		o:Destroy()
		if host and host:IsA("GuiObject") then
			deskin(host)
		end
		return
	end
	if o:IsA("UIStroke") then
		glassStroke(o)
		return
	end
	if not o:IsA("GuiObject") then
		return
	end
	local navy = NAVY[rgbKey(o.BackgroundColor3)]
	if navy then
		o.BackgroundColor3 = navy
	end
	if o:IsA("TextButton") and o:GetAttribute("GhostButton") and o:GetAttribute("Variant") then
		deskin(o) -- ghost buttons in the HUD (Leave lamp) get a glass body too
	end
	if GLASS_PANELS[o.Name] then
		o.BackgroundColor3 = GLASS.bg
		o.BackgroundTransparency = GLASS.bgT
		local corner = o:FindFirstChildOfClass("UICorner") or UiKit.round(o, GLASS.radius)
		corner.CornerRadius = UDim.new(0, GLASS.radius)
		local s = o:FindFirstChildOfClass("UIStroke")
		if s and o.Name ~= "BlackoutAlarm" and o.Name ~= "BigWarning" then
			s.Color = GLASS.glow
			s.Transparency = GLASS.glowT
			s.Thickness = 1.5
		end
		if not o:FindFirstChild("GlassSheen") then
			UiKit.new("UIGradient", {
				Name = "GlassSheen",
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 164, 196)),
			}, o)
		end
	end
end

local function glassTree(root)
	for _, d in root:GetDescendants() do
		restyle(d)
	end
	root.DescendantAdded:Connect(function(d)
		task.defer(function()
			if d.Parent then
				restyle(d)
			end
		end)
	end)
end

-- top bar: the voyage chip sits in the Roblox top-bar row, top right (mock-up: "Night 2:38 AM")
local topBarGui = UiKit.Screen("HudTopBar", 5)
topBarGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local topBar = UiKit.new("Frame", {
	Name = "TopBar",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
}, topBarGui)
voyage.Parent = topBar
voyage.LayoutOrder = 1
-- lamp fuel also moves up into the top-bar row, as a slim bar (owner, Oct 13: "too big")
local topFuelBar = UiKit.new("Frame", {
	Name = "TopFuel",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
}, topBarGui)
fuelPlate.Parent = topFuelBar
local function syncTopBar()
	topBarGui.Enabled = gui.Enabled
end
gui:GetPropertyChangedSignal("Enabled"):Connect(syncTopBar)
syncTopBar()

-- sun by day, crescent moon by night
local sky = UiKit.new("Frame", { Name = "Sky", BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26), LayoutOrder = 0 }, voyage)
local orb = UiKit.new("Frame", {
	Name = "Orb",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(22, 22),
	BorderSizePixel = 0,
}, sky)
UiKit.round(orb, 11)
local bite = UiKit.new("Frame", {
	Name = "Bite",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 7, 0.5, -5),
	Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = Color3.fromRGB(14, 22, 42),
	BorderSizePixel = 0,
}, sky)
UiKit.round(bite, 9)
local function refreshSky()
	local phase = state:GetAttribute("Phase")
	local night = phase == "Night" or phase == "Prologue"
	orb.BackgroundColor3 = if night then Color3.fromRGB(232, 238, 255) else Color3.fromRGB(255, 204, 92)
	bite.Visible = night
	sky.Visible = ISLAND_PHASES[phase] == true
end
state:GetAttributeChangedSignal("Phase"):Connect(refreshSky)

-- lamp state gets its own pill under the tower (red when the lamp is dark)
local lampPill = UiKit.new("Frame", {
	Name = "LampPill",
	BackgroundColor3 = GLASS.bg,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 2,
}, topRight)
UiKit.round(lampPill, GLASS.radius)
local lampStroke = UiKit.border(lampPill, GLASS.glow, 1.5, GLASS.glowT)
UiKit.pad(lampPill, 9, 12, 9, 12)
UiKit.list(lampPill, "y", 4)
beamRow.Parent = lampPill
keeperText.Parent = lampPill
keeperText.LayoutOrder = 3

-- Shells: bottom-right pill on bigger screens; under health on phones
local shellsPill
if shells then
	shellsPill = UiKit.new("Frame", {
		Name = "ShellsPill",
		BackgroundColor3 = GLASS.bg,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -16),
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
	}, hudRoot)
	UiKit.round(shellsPill, GLASS.radius)
	UiKit.border(shellsPill, GLASS.glow, 1.5, GLASS.glowT)
	UiKit.pad(shellsPill, 0, 6, 0, 4)
	shells.frame.BackgroundTransparency = 1
	local s = shells.frame:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
end

-- weapon slot at the bottom (replaces Roblox's hotbar; tap, click or press 1 to draw / stow)
local weaponSlot = UiKit.new("TextButton", {
	Name = "WeaponSlot",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = GLASS.bg,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(96, 104),
	Selectable = false,
}, hudRoot)
UiKit.round(weaponSlot, GLASS.radius)
local slotStroke = UiKit.border(weaponSlot, GLASS.glow, 2, 0.15)
weaponRow.Parent = weaponSlot
weaponRow.Size = UDim2.fromScale(1, 1)
weaponRow.Position = UDim2.new()
weaponWell.AnchorPoint = Vector2.new(0.5, 0)
weaponWell.Position = UDim2.new(0.5, 0, 0, 8)
weaponWell.BackgroundTransparency = 1
do
	local s = weaponWell:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	local lip = weaponWell:FindFirstChild("Lip")
	if lip then
		lip.Visible = false
	end
end
weaponName.TextWrapped = true
weaponName.TextTruncate = Enum.TextTruncate.None
weaponName.TextXAlignment = Enum.TextXAlignment.Center
weaponName.TextYAlignment = Enum.TextYAlignment.Center
weaponName.LineHeight = 0.95
weaponState.Visible = false
cooldownTrack.AnchorPoint = Vector2.new(0, 1)
cooldownTrack.Position = UDim2.new(0, 12, 1, -5)
cooldownTrack.Size = UDim2.new(1, -24, 0, 3)
local slotKey = UiKit.new("TextLabel", {
	Name = "SlotKey",
	BackgroundTransparency = 1,
	FontFace = F.Numeric,
	TextSize = 15,
	TextColor3 = GLASS.text,
	Text = "1",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -7, 0, 4),
	Size = UDim2.fromOffset(14, 16),
}, weaponSlot)

local function toggleWeapon()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or player:GetAttribute("MenuOpen") then
		return
	end
	if (state:GetAttribute("KeeperUserId") or 0) == player.UserId then
		return -- hands on the lamp
	end
	if findWeapon(character) then
		humanoid:UnequipTools()
	else
		local tool = findWeapon(player:FindFirstChildOfClass("Backpack"))
		if tool then
			humanoid:EquipTool(tool)
		end
	end
end
weaponSlot.Activated:Connect(toggleWeapon)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.DPadDown then -- D-pad up opens the BAG
		toggleWeapon()
	end
end)

-- Roblox's own hotbar is replaced by the slot (Menus/Results respect this attribute)
player:SetAttribute("OwnWeaponSlot", true)
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end)

local function refreshSlot()
	weaponSlot.Visible = weaponRow.Visible and not player:GetAttribute("MenuOpen")
	local held = findWeapon(player.Character) ~= nil
	slotStroke.Color = if held then C.AccentLighthouse else GLASS.glow
	slotStroke.Transparency = if held then 0.1 else 0.35
	slotKey.Visible = inputMode() == "keyboard"
end
weaponRow:GetPropertyChangedSignal("Visible"):Connect(refreshSlot)
weaponName:GetPropertyChangedSignal("TextColor3"):Connect(refreshSlot)
player:GetAttributeChangedSignal("MenuOpen"):Connect(refreshSlot)
UserInputService.LastInputTypeChanged:Connect(refreshSlot)

local function refreshLampPill()
	local phase = state:GetAttribute("Phase")
	lampPill.Visible = beamRow.Visible and ISLAND_PHASES[phase] == true
	local dark = beamText.TextColor3 == C.StateDanger
	lampPill.BackgroundColor3 = if dark then GLASS.dangerBg else GLASS.bg
	lampStroke.Color = if dark then GLASS.danger else GLASS.glow
	lampStroke.Transparency = if dark then 0.1 else GLASS.glowT
end
beamRow:GetPropertyChangedSignal("Visible"):Connect(refreshLampPill)
beamText:GetPropertyChangedSignal("TextColor3"):Connect(refreshLampPill)
state:GetAttributeChangedSignal("Phase"):Connect(refreshLampPill)

-- prompt cards: the key chip moves to the right edge (mock-up: "Grab oil for the lamp  [TAP]")
for _, cardObj in { primaryCard, secondaryCard } do
	local key = cardObj.button:FindFirstChild("Key")
	if key then
		key.AnchorPoint = Vector2.new(1, 0.5)
		key.Position = UDim2.new(1, -10, 0.5, 0)
		key.Size = UDim2.fromOffset(54, key.Size.Y.Offset)
		key.BackgroundColor3 = GLASS.chip
		local s = key:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = GLASS.glow
			s.Transparency = 0.2
		end
		local corner = key:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 10)
		end
	end
	for _, label in { cardObj.action, cardObj.object } do
		label.Position = UDim2.new(0, 16, label.Position.Y.Scale, label.Position.Y.Offset)
		label.Size = UDim2.new(1, -16 - 54 - 18, 0, label.Size.Y.Offset)
	end
	cardObj.keyText.TextColor3 = GLASS.text
end

-- glass everywhere in the HUD, prompts, notices, the top bar and the BAG button
for _, root in { hudRoot, promptRoot, topBar, topFuelBar } do
	glassTree(root)
end
task.spawn(function()
	local bagGui = player:WaitForChild("PlayerGui"):WaitForChild("InventoryButton", 30)
	if bagGui then
		glassTree(bagGui)
		task.defer(applyLayout)
	end
end)

-- after the glass pass: special colours
alarm.BackgroundColor3 = GLASS.dangerBg
warning.BackgroundColor3 = GLASS.dangerBg
do
	local cap = leftPlate:FindFirstChild("Cap", true)
	if cap then
		local corner = cap:FindFirstChildOfClass("UICorner") or UiKit.round(cap, 0)
		corner.CornerRadius = UDim.new(0.5, 0)
		local s = cap:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = GLASS.heart
			s.Transparency = 0.05
			s.Thickness = 2
		end
	end
end

-- SLIM (owner, Oct 13: "the lamp fuel bar is too big… make the side bars take less area on mobile")
local function gaugeParts(g)
	local cap = g:FindFirstChild("Cap")
	local body
	for _, c in g:GetChildren() do
		if c:IsA("Frame") and c ~= cap then
			body = c
		end
	end
	return cap, body
end
local function scaleCap(cap, s)
	if cap then
		local sc = cap:FindFirstChild("SlimScale") or UiKit.new("UIScale", { Name = "SlimScale" }, cap)
		sc.Scale = s
	end
end
local function scaleText(root, s)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			if d:GetAttribute("BaseTextSize") == nil then
				d:SetAttribute("BaseTextSize", d.TextSize)
			end
			d.TextSize = math.floor(d:GetAttribute("BaseTextSize") * s + 0.5)
		end
	end
end
local function setPad(frame, v, h)
	local p = frame:FindFirstChildOfClass("UIPadding")
	if p then
		p.PaddingTop, p.PaddingBottom = UDim.new(0, v), UDim.new(0, v)
		p.PaddingLeft, p.PaddingRight = UDim.new(0, h), UDim.new(0, h)
	end
end
local function slimGauge(g, height, capBase, bodyX, barName, barHeight, textScale)
	g.Size = UDim2.new(1, 0, 0, height)
	local cap, body = gaugeParts(g)
	scaleCap(cap, height / capBase)
	if body then
		body.Position = UDim2.fromOffset(bodyX, 0)
		body.Size = UDim2.new(1, -bodyX, 1, 0)
		local bar = body:FindFirstChild(barName)
		if bar then
			bar.Size = UDim2.new(1, 0, 0, barHeight)
			local mark = bar:FindFirstChild("CriticalMark")
			if mark then
				mark.Size = UDim2.fromOffset(2, barHeight + 4) -- stays inside the gauge, clear of the label
			end
		end
		scaleText(body, textScale)
	end
end

local function slimLayout(size)
	-- health (left) and tower (right): smaller on phones
	if compact then
		slimGauge(health.frame, 28, 38, 34, "Track", 9, 0.85)
		slimGauge(tower.frame, 28, 42, 34, "Blocks", 10, 0.85)
	else
		slimGauge(health.frame, 38, 38, 46, "Track", 14, 1)
		slimGauge(tower.frame, 42, 42, 50, "Blocks", 20, 1)
	end
	local sideW = if compact then 146 else topRight.Size.X.Offset
	topLeft.Size = UDim2.fromOffset(if compact then 150 else topLeft.Size.X.Offset, 0)
	topRight.Size = UDim2.fromOffset(sideW, 0)
	sideStack.Size = UDim2.fromOffset(sideW, 0)
	setPad(leftPlate, if compact then 6 else 10, if compact then 9 else 12)
	setPad(rightPlate, if compact then 6 else 10, if compact then 9 else 12)
	setPad(lampPill, if compact then 5 else 9, if compact then 9 else 12)
	scaleText(lampPill, if compact then 0.82 else 1)
	if shells then
		scaleText(shells.frame, if compact then 0.85 else 1)
		if compact then
			shells.frame.Size = UDim2.fromOffset(0, 22)
		end
	end
	-- voyage chip
	voyageTitle.TextSize = if compact then 14 else 18
	timerText.TextSize = if compact then 14 else 16
	-- lamp fuel: one slim line in the top-bar row (all sizes)
	local fuelFrame = fuel.frame
	fuelFrame.Size = UDim2.new(1, 0, 0, 30)
	local cap, body = gaugeParts(fuelFrame)
	scaleCap(cap, 30 / 58)
	if body then
		body.Position = UDim2.fromOffset(38, 0)
		body.Size = UDim2.new(1, -38, 1, 0)
		for _, c in body:GetChildren() do
			if c.Name == "Scale" then
				c.Visible = false
			elseif c.Name == "Reservoir" then
				c.Position = UDim2.fromOffset(0, 19)
				c.Size = UDim2.new(1, 0, 0, 9)
			elseif c:IsA("GuiObject") then
				c.Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, 0, 16)
			end
		end
		scaleText(body, 0.8)
	end
	setPad(fuelPlate, 6, 10)
	local vw = topBarGui.AbsoluteSize.X
	if vw > 0 then
		local leftEdge = 270 -- Roblox's own top-bar buttons end about here
		local rightEdge = vw - (topBar.AbsoluteSize.X + 24)
		local fw = math.clamp(rightEdge - leftEdge - 16, 160, if compact then 230 else 340)
		fuelPlate.Size = UDim2.fromOffset(fw, 0)
		local center = vw / 2
		if center - fw / 2 < leftEdge + 8 or center + fw / 2 > rightEdge - 8 then
			center = (leftEdge + rightEdge) / 2
		end
		topFuelBar.Position = UDim2.new(0, center, 0, 10)
	end
end

glassLayout = function()
	local size = hudRoot.AbsoluteSize
	voyageSub.Visible = false
	voyage.Size = UDim2.fromOffset(0, if compact then 38 else 44)
	-- weapon slot
	local slotW, slotH, well = 96, 106, 56
	if compact then
		slotW, slotH, well = 74, 80, 40
	end
	weaponSlot.Size = UDim2.fromOffset(slotW, slotH)
	weaponSlot.Position = UDim2.new(0.5, 0, 1, if compact then -6 else -12)
	weaponWell.Size = UDim2.fromOffset(well, well)
	weaponWell.Position = UDim2.new(0.5, 0, 0, if compact then 4 else 8)
	weaponName.TextSize = if compact then 12 else 14
	weaponName.Position = UDim2.new(0, 4, 1, if compact then -32 else -40)
	weaponName.Size = UDim2.new(1, -8, 0, if compact then 26 else 32)
	-- Shells: bottom-right above the jump button (bigger screens), under health on phones
	if shellsPill then
		if compact then
			shells.frame.Parent = leftPlate
			shells.frame.LayoutOrder = 3
			shells.frame.Size = UDim2.fromOffset(0, 30)
			shellsPill.Visible = false
		else
			shells.frame.Parent = shellsPill
			shells.frame.Size = UDim2.fromOffset(0, 50)
			shellsPill.Visible = true
			local lift = 16
			if isTouch() then
				lift = if math.min(size.X, size.Y) <= 500 then 100 else 228
			end
			shellsPill.Position = UDim2.new(1, -12, 1, -lift)
		end
	end
	slimLayout(size)
	refreshSlot()
	refreshLampPill()
	refreshSky()
end

refreshVoyage()
refreshFuel()
refreshTower()
refreshShells()
refreshVisibility()
applyLayout()

---------------------------------------------------------------------
-- STUDIO ONLY: layout simulator. Set the player attribute HudSimulate to "smallPhone",
-- "largePhone", "tablet" or "laptop" to draw this real HUD inside a screen of that exact size
-- (touch devices also show the Roblox joystick and jump-button zones). "" turns it off.
-- Never runs in the live game.
---------------------------------------------------------------------

if RunService:IsStudio() then
	local SIZES = {
		smallPhone = { size = Vector2.new(667, 375), touch = true },
		largePhone = { size = Vector2.new(932, 430), touch = true },
		tablet = { size = Vector2.new(1180, 820), touch = true },
		laptop = { size = Vector2.new(1366, 768), touch = false },
	}
	local zones = {}
	local function zone(label, anchor, position, size)
		local z = UiKit.new("Frame", {
			Name = "TouchZone_" .. label,
			BackgroundColor3 = C.StateDanger,
			BackgroundTransparency = 0.85,
			AnchorPoint = anchor,
			Position = position,
			Size = size,
			Visible = false,
		}, promptRoot)
		UiKit.border(z, C.StateDanger, 1, 0.3)
		UiKit.Label(z, label, "Caption", { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 16), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = C.StateDanger })
		table.insert(zones, z)
	end
	zone("Joystick start area", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(0.4, 0.45))
	zone("Jump", Vector2.new(0, 0), UDim2.new(1, -95, 1, -90), UDim2.fromOffset(70, 70))
	local jumpZone = zones[#zones]
	local function applySimulation()
		local spec = SIZES[player:GetAttribute("HudSimulate") or ""]
		simulated = spec
		for _, root in { hudRoot, promptRoot } do
			root:FindFirstChildOfClass("UIStroke").Enabled = spec ~= nil
			if spec then
				root.AnchorPoint = Vector2.new(0.5, 0.5)
				root.Position = UDim2.fromScale(0.5, 0.5)
				root.Size = UDim2.fromOffset(spec.size.X, spec.size.Y)
			else
				root.AnchorPoint = Vector2.zero
				root.Position = UDim2.new()
				root.Size = UDim2.fromScale(1, 1)
			end
		end
		for _, z in zones do
			z.Visible = spec ~= nil and spec.touch
		end
		if spec then
			local small = math.min(spec.size.X, spec.size.Y) <= 500
			jumpZone.Position = if small then UDim2.new(1, -95, 1, -90) else UDim2.new(1, -170, 1, -210)
			jumpZone.Size = if small then UDim2.fromOffset(70, 70) else UDim2.fromOffset(120, 120)
		end
		task.defer(applyLayout)
	end
	player:GetAttributeChangedSignal("HudSimulate"):Connect(applySimulation)
end
