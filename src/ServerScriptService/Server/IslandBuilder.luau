-- IslandBuilder: builds the Week 1 placeholder island entirely from code.
-- Everything here gets replaced with real models in the Week 6 art pass,
-- so names matter more than looks (other scripts find parts by name).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ground = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ground"))

-- 3D models made in Studio live in ServerStorage.Art; anything missing falls back to simple parts
local ArtFolder = game:GetService("ServerStorage"):FindFirstChild("Art")
local function getArt(name)
	return ArtFolder and ArtFolder:FindFirstChild(name)
end

-- Places a copy of an art model standing on the ground at `position` (x/z), facing `yaw` degrees
local function placeArt(art, position, yaw, parent)
	local copy = art:Clone()
	copy.Anchored = true
	copy.CanCollide = true
	local groundY = Ground.heightAt(position.X, position.Z)
	copy.CFrame = CFrame.new(position.X, groundY + copy.Size.Y / 2, position.Z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	copy.Parent = parent
	return copy
end

local IslandBuilder = {}

-- Roblox cylinders lie along the X axis; rotating 90 degrees stands them up.
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeCylinder(name, position, height, diameter, color, material, parent)
	local part = makePart(
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * VERTICAL,
		color,
		material,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function addPrompt(parent, actionText, objectText, holdDuration)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Floating label so new players can find things in the dark
local function addLabel(parent, text, color, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(140, 30)
	billboard.StudsOffset = Vector3.new(0, height or 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard
	return billboard
end

function IslandBuilder.build()
	-- Remove the Baseplate template's floor and spawn so they don't overlap the sea.
	for _, name in { "Baseplate", "SpawnLocation", "Island" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local island = Instance.new("Folder")
	island.Name = "Island"
	island.Parent = Workspace

	local c = Config.ISLAND_CENTER
	local groundY = Config.GROUND_Y
	local radius = Config.ISLAND_RADIUS

	-- Old placeholder sea, beach, island, and rocks. Skipped when the place has real terrain.
	if not Config.USE_TERRAIN then
	-- Sea (top surface at y = 0)
	local sea = makePart(
		"Sea",
		Vector3.new(2048, 2, 2048),
		CFrame.new(c.X, -1, c.Z),
		Color3.fromRGB(28, 62, 92),
		Enum.Material.SmoothPlastic,
		island
	)
	sea.Reflectance = 0.1

	-- Sandy beach ring (top at y = 3) and the island plateau (top at GROUND_Y)
	makeCylinder("Beach", Vector3.new(c.X, -1, c.Z), 8, radius * 2 + 16, Color3.fromRGB(196, 178, 140), Enum.Material.Sand, island)
	makeCylinder("IslandTop", Vector3.new(c.X, groundY - 6, c.Z), 12, radius * 2, Color3.fromRGB(92, 110, 84), Enum.Material.Grass, island)

	-- Rocks around the shore (fixed seed so the layout is the same every time)
	local rng = Random.new(7)
	for i = 1, 16 do
		local theta = (i / 16) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dist = radius + rng:NextNumber(4, 10)
		local size = Vector3.new(rng:NextNumber(6, 12), rng:NextNumber(5, 10), rng:NextNumber(6, 12))
		local position = Vector3.new(c.X + math.cos(theta) * dist, 1.5, c.Z + math.sin(theta) * dist)
		local rotation = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
		makePart("Rock", size, CFrame.new(position) * rotation, Color3.fromRGB(88, 90, 96), Enum.Material.Slate, island)
	end

	end -- if not Config.USE_TERRAIN

	-- Lighthouse tower: red and white stripes, slightly tapered
	local segments = 6
	local segmentHeight = Config.TOWER_HEIGHT / segments
	local artTower = getArt("LighthouseTower")
	local lampPosition
	if artTower then
		-- Complete 3D lighthouse (tower, gallery, and lantern room). The lamp goes inside its lantern room.
		local tower = artTower:Clone()
		tower.Name = "LighthouseTower"
		tower.Anchored = true
		tower.CFrame = CFrame.new(c.X, groundY + tower.Size.Y / 2, c.Z) * CFrame.Angles(0, math.rad(artTower:GetAttribute("YawOffset") or 0), 0)
		tower.Parent = island
		lampPosition = Vector3.new(c.X, groundY + tower.Size.Y * (artTower:GetAttribute("LanternHeightFraction") or 0.89), c.Z)
	else
	for i = 0, segments - 1 do
		local color = if i % 2 == 0 then Color3.fromRGB(235, 235, 230) else Color3.fromRGB(190, 45, 45)
		local diameter = 16 - i * 0.6
		local position = Vector3.new(c.X, groundY + segmentHeight * (i + 0.5), c.Z)
		makeCylinder("TowerSegment", position, segmentHeight, diameter, color, Enum.Material.SmoothPlastic, island)
	end

	-- Code-built gallery, glass lamp room, and roof (only for the placeholder tower)
	local topY = groundY + Config.TOWER_HEIGHT
	makeCylinder("Gallery", Vector3.new(c.X, topY + 0.5, c.Z), 1, 20, Color3.fromRGB(40, 40, 45), Enum.Material.Metal, island)
	local lampRoom = makeCylinder("LampRoom", Vector3.new(c.X, topY + 5, c.Z), 8, 12, Color3.fromRGB(200, 230, 255), Enum.Material.Glass, island)
	lampRoom.Transparency = 0.7
	lampRoom.CanCollide = false
	makeCylinder("Roof", Vector3.new(c.X, topY + 9.5, c.Z), 1, 14, Color3.fromRGB(150, 35, 35), Enum.Material.Metal, island)
	lampPosition = Vector3.new(c.X, topY + 5, c.Z)
	end

	-- The lamp itself
	local lampCore = makePart("LampCore", Vector3.new(3, 3, 3), CFrame.new(lampPosition), Color3.fromRGB(255, 226, 150), Enum.Material.Neon, island)
	lampCore.Shape = Enum.PartType.Ball
	lampCore.CanCollide = false

	local pointLight = Instance.new("PointLight")
	pointLight.Range = 40
	pointLight.Brightness = 3
	pointLight.Color = Color3.fromRGB(255, 226, 150)
	pointLight.Parent = lampCore

	-- Beam emitter: an invisible part the server rotates. Its front face (-Z) is the beam direction.
	local emitter = makePart("BeamEmitter", Vector3.new(1, 1, 1), CFrame.new(lampPosition), Color3.new(1, 1, 1), nil, island)
	emitter.Transparency = 1
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false

	local beamStart = Instance.new("Attachment")
	beamStart.Name = "BeamStart"
	beamStart.Parent = emitter

	local beamEnd = Instance.new("Attachment")
	beamEnd.Name = "BeamEnd"
	beamEnd.Position = Vector3.new(0, 0, -Config.BEAM_LENGTH)
	beamEnd.Parent = emitter

	local beam = Instance.new("Beam")
	beam.Name = "LightBeam"
	beam.Attachment0 = beamStart
	beam.Attachment1 = beamEnd
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 236, 170))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 3
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = 3
	beam.Width1 = 40
	beam.FaceCamera = true
	beam.Parent = emitter

	local spotLight = Instance.new("SpotLight")
	spotLight.Face = Enum.NormalId.Front
	spotLight.Angle = 35
	spotLight.Range = 60
	spotLight.Brightness = 10
	spotLight.Shadows = true
	spotLight.Color = Color3.fromRGB(255, 236, 170)
	spotLight.Parent = emitter

	-- Pools of light along the beam so it visibly lights the rocks and creatures
	local beamGlows = {}
	for index = 1, 3 do
		local glow = makePart("BeamGlow" .. index, Vector3.new(1, 1, 1), CFrame.new(lampPosition), Color3.new(1, 1, 1), nil, island)
		glow.Transparency = 1
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CanTouch = false
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 2.5
		light.Color = Color3.fromRGB(255, 236, 170)
		light.Parent = glow
		table.insert(beamGlows, glow)
	end

	-- Lamp console at the tower door: whoever uses it becomes the Keeper
	local propRadius = if artTower then 14 else 11 -- the 3D lighthouse has a wider base
	local console = makePart("LampConsole", Vector3.new(4, 4, 2), CFrame.new(c.X, groundY + 2, c.Z + propRadius), Color3.fromRGB(60, 60, 70), Enum.Material.Metal, island)
	local consolePrompt = addPrompt(console, "Use the Lamp", "Lamp Console", 0)
	addLabel(console, "LAMP", Color3.fromRGB(255, 226, 150), 4)

	-- Fuel tank on the other side of the tower
	local fuelTank = makeCylinder("FuelTank", Vector3.new(c.X, groundY + 3, c.Z - propRadius), 6, 5, Color3.fromRGB(184, 115, 51), Enum.Material.Metal, island)
	local fuelPrompt = addPrompt(fuelTank, "Refuel Lamp", "Fuel Tank", 0.5)
	addLabel(fuelTank, "FUEL TANK", Color3.fromRGB(255, 170, 90), 5)

	-- Tower door: creatures chew on the tower, players repair it here
	local towerDoor = makePart("TowerDoor", Vector3.new(1.5, 7, 5), CFrame.new(c.X - propRadius + 2.5, groundY + 3.5, c.Z), Color3.fromRGB(105, 70, 45), Enum.Material.WoodPlanks, island)
	local repairPrompt = addPrompt(towerDoor, "Repair Tower", "Tower Door", Config.REPAIR_HOLD_SECONDS)
	addLabel(towerDoor, "REPAIR", Color3.fromRGB(150, 210, 255), 5)

	-- Oil barrels out on the island
	local oilPosition = Vector3.new(c.X + 48, groundY, c.Z + 20)
	local barrelOffsets = {
		Vector3.new(0, 1.75, 0),
		Vector3.new(3, 1.75, 0),
		Vector3.new(1.5, 1.75, 2.8),
		Vector3.new(1.5, 5.25, 1.2),
	}
	local artBarrel = getArt("OilBarrel")
	if artBarrel then
		-- A loose pile of barrels on the ground (plus one on top)
		local pile = {
			{ Vector3.new(0, 0, 0), 0 },
			{ Vector3.new(3, 0, 0.4), 40 },
			{ Vector3.new(1.4, 0, 2.8), 75 },
			{ Vector3.new(-1.6, 0, 2.2), 20 },
		}
		for _, entry in pile do
			placeArt(artBarrel, oilPosition + entry[1], entry[2], island).Name = "OilBarrel"
		end
		local top = placeArt(artBarrel, oilPosition + Vector3.new(1.4, 0, 1), 10, island)
		top.Name = "OilBarrel"
		top.Position += Vector3.new(0, artBarrel.Size.Y, 0)
	else
		for _, offset in barrelOffsets do
			makeCylinder("OilBarrel", oilPosition + offset, 3.5, 2.6, Color3.fromRGB(45, 40, 35), Enum.Material.Metal, island)
		end
	end
	local oilPile = makePart("OilPile", Vector3.new(6, 4, 6), CFrame.new(oilPosition + Vector3.new(1.5, 2, 1.2)), Color3.new(1, 1, 1), nil, island)
	oilPile.Transparency = 1
	oilPile.CanCollide = false
	local oilPrompt = addPrompt(oilPile, "Grab Oil", "Whale Oil", 0.5)
	addLabel(oilPile, "OIL", Color3.fromRGB(255, 200, 80), 6)

	-- Upgrade bench near the spawn: the crew spends Shells here
	local bench = makePart("UpgradeBench", Vector3.new(6, 3, 3), CFrame.new(c.X - 14, groundY + 1.5, c.Z + 26), Color3.fromRGB(95, 75, 55), Enum.Material.WoodPlanks, island)
	local artBench = getArt("UpgradeBench")
	if artBench then
		-- Invisible interaction box, with the 3D bench inside it (removing the box removes both)
		bench.Transparency = 1
		bench.CanCollide = false
		placeArt(artBench, bench.Position, 180, bench).Name = "BenchModel"
	else
		makePart("BenchTop", Vector3.new(6.4, 0.4, 3.4), CFrame.new(c.X - 14, groundY + 3.2, c.Z + 26), Color3.fromRGB(150, 120, 80), Enum.Material.Wood, island)
	end
	local upgradePrompt = addPrompt(bench, "Upgrade Lighthouse", "Upgrade Bench", 0)
	addLabel(bench, "UPGRADES", Color3.fromRGB(140, 255, 160), 4)

	-- Quartermaster's shop: a market stall near the spawn, facing players as they arrive
	local shopPosition = Vector3.new(c.X + 18, 0, c.Z + 36)
	local toSpawn = (Vector3.new(c.X, 0, c.Z + 24) - shopPosition).Unit -- direction customers come from
	local shopGround = Ground.heightAt(shopPosition.X, shopPosition.Z)
	local facing = CFrame.lookAt(Vector3.new(shopPosition.X, shopGround, shopPosition.Z), Vector3.new(shopPosition.X, shopGround, shopPosition.Z) + toSpawn)
	local artStall = getArt("ShopStall")
	if artStall then
		local stall = artStall:Clone()
		local _, stallSize = stall:GetBoundingBox()
		-- the stall model's counter faces +Z; turn it to face the customers
		stall:PivotTo(facing * CFrame.new(0, stallSize.Y / 2, 0) * CFrame.Angles(0, math.rad(180), 0))
		stall.Parent = island
	end
	local artKeeper = getArt("Quartermaster")
	local quartermaster
	if artKeeper then
		quartermaster = artKeeper:Clone()
		quartermaster.Anchored = true
		-- behind the counter, looking at customers (the model faces -Z, which lookAt also uses)
		quartermaster.CFrame = facing * CFrame.new(0, quartermaster.Size.Y / 2, 1.2)
	else
		quartermaster = makePart("Quartermaster", Vector3.new(2, 5, 1.5), facing * CFrame.new(0, 2.5, 1.2), Color3.fromRGB(40, 50, 80), Enum.Material.Fabric, nil)
	end
	quartermaster.Name = "Quartermaster"
	quartermaster.Parent = island

	-- Nameplate with a small shop icon
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(200, 50)
	plate.StudsOffset = Vector3.new(0, quartermaster.Size.Y / 2 + 1.6, 0)
	plate.MaxDistance = 90
	plate.Parent = quartermaster
	local plateName = Instance.new("TextLabel")
	plateName.Size = UDim2.new(1, 0, 0, 26)
	plateName.BackgroundTransparency = 1
	plateName.Font = Enum.Font.GothamBlack
	plateName.TextSize = 20
	plateName.TextColor3 = Color3.fromRGB(245, 196, 92)
	plateName.TextStrokeTransparency = 0.3
	plateName.Text = "\u{2693} QUARTERMASTER"
	plateName.Parent = plate
	local plateSub = Instance.new("TextLabel")
	plateSub.Size = UDim2.new(1, 0, 0, 18)
	plateSub.Position = UDim2.fromOffset(0, 26)
	plateSub.BackgroundTransparency = 1
	plateSub.Font = Enum.Font.GothamMedium
	plateSub.TextSize = 14
	plateSub.TextColor3 = Color3.fromRGB(220, 226, 236)
	plateSub.TextStrokeTransparency = 0.4
	plateSub.Text = "Weapons \u{2022} Armor \u{2022} Ammo"
	plateSub.Parent = plate

	-- Invisible area in front of the counter: the trade prompt lives here
	local counter = makePart("ShopCounter", Vector3.new(6, 5, 4), facing * CFrame.new(0, 2.5, -2.5), Color3.new(1, 1, 1), nil, island)
	counter.Transparency = 1
	counter.CanCollide = false
	counter.CanQuery = false
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "TradePrompt"
	shopPrompt.ActionText = "Trade"
	shopPrompt.ObjectText = "Quartermaster"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
	shopPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 10
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = counter

	-- The Trader: buys the crew's loot for shells during a voyage (only on this island)
	local traderXZ = Vector3.new(c.X + 18, 0, c.Z + 42)
	local traderGround = Ground.heightAt(traderXZ.X, traderXZ.Z)
	local traderLook = CFrame.lookAt(Vector3.new(traderXZ.X, traderGround, traderXZ.Z), Vector3.new(c.X, traderGround, c.Z + 24))
	local trader
	local artTrader = getArt("Trader")
	if artTrader then
		trader = artTrader:Clone()
		trader.Anchored = true
		trader.CFrame = traderLook * CFrame.new(0, trader.Size.Y / 2, 0) -- the model faces -Z, same as lookAt
	else
		trader = makePart("Trader", Vector3.new(2, 4, 1.5), traderLook * CFrame.new(0, 2, 0), Color3.fromRGB(190, 150, 90), Enum.Material.Fabric, nil)
	end
	trader.Name = "Trader"
	trader.Parent = island
	local traderPrompt = addPrompt(trader, "Sell loot", "Salvage Trader", 0)
	traderPrompt.MaxActivationDistance = 10
	local traderLabel = addLabel(trader, "TRADER", Color3.fromRGB(140, 255, 160), trader.Size.Y / 2 + 1.5)
	traderLabel.Size = UDim2.fromOffset(200, 30)

	-- Folder that holds live creatures
	local creatureFolder = Instance.new("Folder")
	creatureFolder.Name = "Creatures"
	creatureFolder.Parent = island

	-- Spawn point in front of the lighthouse
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(c.X, groundY + 0.5, c.Z + 24)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 90, 60)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Parent = island

	return {
		folder = island,
		lampPosition = lampPosition,
		lampCore = lampCore,
		pointLight = pointLight,
		emitter = emitter,
		beam = beam,
		spotLight = spotLight,
		beamGlows = beamGlows,
		consolePrompt = consolePrompt,
		fuelPrompt = fuelPrompt,
		oilPrompt = oilPrompt,
		repairPrompt = repairPrompt,
		traderPrompt = traderPrompt,
		shopCounter = counter,
		shopPrompt = shopPrompt,
		upgradePrompt = upgradePrompt,
		creatureFolder = creatureFolder,
	}
end

return IslandBuilder
