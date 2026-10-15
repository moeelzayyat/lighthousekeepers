-- DefenseService: cannons the crew builds on stone pads around the lighthouse.
--
--   Empty pad   -> "Build Cannon" prompt (CANNON_COSTS[1] shells). New cannons start fully loaded.
--   Cannon      -> "Upgrade Cannon" prompt (levels 2 and 3) and "Reload Cannon" prompt (R key).
--   Each shot uses ammo. Reloading takes an oil barrel, the same oil the lamp needs,
--   so the crew has to choose where each barrel goes. Ammo types live in Shared/Ammo.
--   Each cannon fires at the creature in range that is closest to the tower,
--   with a small splash. Cannons are removed at the start of every run.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EventLog = require(script.Parent.EventLog)
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local Ammo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ammo"))
local ArtFolder = game:GetService("ServerStorage"):FindFirstChild("Art")
local artCannon = ArtFolder and ArtFolder:FindFirstChild("Cannon")

local LEVEL_SCALES = { 1, 1.12, 1.25 } -- the 3D cannon grows with each level
local EMPTY_RING_COLOR = Color3.fromRGB(140, 255, 160)

local DefenseService = {}

local LEVEL_COLORS = {
	Color3.fromRGB(40, 40, 45), -- iron
	Color3.fromRGB(170, 110, 50), -- bronze
	Color3.fromRGB(235, 190, 60), -- gold
}
local SHOT_TRAVEL_TIME = 0.25

local folder
local creatures
local upgrades
local notifyAll
local notify
local pads = {}

-- Set by Main once oil carrying exists: hasOil(player) -> bool, takeOil(player)
local hasOil = function()
	return false
end
local takeOil = function() end

-- Set by Main: crateFor(player) -> itemId, ammoType (or nil); takeCrate(player, itemId) -> bool
local crateFor = function()
	return nil
end
local takeCrate = function()
	return false
end

local GLOW_READY = Color3.fromRGB(255, 190, 110)
local GLOW_EMPTY = Color3.fromRGB(255, 60, 50)

-- Refreshes the ammo label, glow color, and reload prompt for one pad
local function updateAmmoUi(pad)
	local built = pad.level > 0
	-- the HUD reads these when the player stands near this cannon
	local padPart = pad.reloadPrompt and pad.reloadPrompt.Parent
	if padPart then
		padPart:SetAttribute("CannonLevel", pad.level)
		if built and pad.ammoType and Ammo[pad.ammoType] then
			padPart:SetAttribute("Ammo", pad.ammo)
			padPart:SetAttribute("MaxAmmo", pad.maxAmmo)
			padPart:SetAttribute("AmmoType", pad.ammoType)
			padPart:SetAttribute("AmmoName", Ammo[pad.ammoType].displayName)
			padPart:SetAttribute("CannonHealth", pad.health or 0)
			padPart:SetAttribute("CannonMaxHealth", pad.maxHealth or 0)
		end
	end
	pad.ammoLabel.Enabled = built
	pad.reloadPrompt.Enabled = built
	if not built then
		return
	end
	local ratio = if pad.maxAmmo > 0 then pad.ammo / pad.maxAmmo else 0
	pad.ammoFill.Size = UDim2.fromScale(ratio, 1)
	pad.ammoFill.BackgroundColor3 = if pad.ammo == 0 then GLOW_EMPTY
		elseif ratio < 0.3 then Color3.fromRGB(240, 200, 60)
		else Color3.fromRGB(90, 200, 110)
	pad.ammoText.Text = if pad.ammo == 0 then "EMPTY - bring oil" else string.format("%s  %d/%d", Ammo[pad.ammoType].displayName, pad.ammo, pad.maxAmmo)
	if pad.healthFill and pad.maxHealth > 0 then
		local health = math.clamp(pad.health / pad.maxHealth, 0, 1)
		pad.healthFill.Size = UDim2.fromScale(health, 1)
		pad.healthFill.BackgroundColor3 = if health > 0.35 then Color3.fromRGB(120, 180, 240) else GLOW_EMPTY
	end
	pad.reloadPrompt.ObjectText = if pad.ammo >= pad.maxAmmo then "Full" else string.format("+%d shots, uses oil", Ammo[pad.ammoType].shotsPerLoad)
	if pad.glow then
		pad.glow.Color = if pad.ammo == 0 then GLOW_EMPTY else GLOW_READY
	end
end

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function updatePrompt(pad)
	local prompt = pad.prompt
	if pad.level == 0 then
		prompt.ActionText = "Build Cannon"
		prompt.ObjectText = string.format("%d shells", Config.CANNON_COSTS[1])
		prompt.Enabled = true
	elseif pad.level < #Config.CANNON_COSTS then
		prompt.ActionText = "Upgrade Cannon"
		prompt.ObjectText = string.format("Level %d: %d shells", pad.level + 1, Config.CANNON_COSTS[pad.level + 1])
		prompt.Enabled = true
	else
		prompt.ActionText = "Cannon"
		prompt.ObjectText = "Max level"
		prompt.Enabled = false
	end
end

-- Builds (or rebuilds) the cannon model on a pad for its current level
local function buildCannonModel(pad)
	if pad.model then
		pad.model:Destroy()
	end
	local model = Instance.new("Folder")
	model.Name = "Cannon"
	model.Parent = folder

	local base = pad.position
	local color = LEVEL_COLORS[pad.level]
	if pad.ring then
		pad.ring.Color = color -- iron, bronze, gold ring shows the level at a glance
	end

	if artCannon then
		-- 3D cannon model: the whole cannon turns to aim
		local cannon = artCannon:Clone()
		cannon.Name = "CannonModel"
		cannon.Size *= LEVEL_SCALES[pad.level]
		cannon.Anchored = true
		cannon.CanCollide = false
		cannon.CanQuery = false
		cannon.Parent = model
		-- Warm lantern glow so built cannons are easy to spot at night (brighter at higher levels)
		local glow = Instance.new("PointLight")
		glow.Name = "CannonGlow"
		glow.Color = Color3.fromRGB(255, 190, 110)
		glow.Range = 10 + pad.level * 2
		glow.Brightness = 1.2 + pad.level * 0.3
		glow.Shadows = false
		glow.Parent = cannon
		pad.glow = glow
		pad.model = model
		pad.barrel = cannon
		pad.isArt = true
		pad.barrelLength = cannon.Size.Z / 2 + 0.3 -- center to muzzle
		pad.pivot = base + Vector3.new(0, 0.4 + cannon.Size.Y / 2, 0)
		pad.aim = pad.aim or (base + Vector3.new(0, 3, -10))
		pad.lastShot = 0
		return
	end
	makePart("Base", Vector3.new(1.2, 4, 4), CFrame.new(base + Vector3.new(0, 0.6, 0)) * VERTICAL, Color3.fromRGB(70, 60, 50), Enum.Material.Wood, model).Shape = Enum.PartType.Cylinder
	makePart("Mount", Vector3.new(2.2, 1.6, 2.2), CFrame.new(base + Vector3.new(0, 1.9, 0)), Color3.fromRGB(85, 70, 55), Enum.Material.Wood, model)

	local barrelLength = 3.6 + pad.level * 0.4
	local barrel = makePart("Barrel", Vector3.new(barrelLength, 1.1 + pad.level * 0.1, 1.1 + pad.level * 0.1), CFrame.new(), color, Enum.Material.Metal, model)
	barrel.Shape = Enum.PartType.Cylinder

	pad.model = model
	pad.barrel = barrel
	pad.barrelLength = barrelLength
	pad.pivot = base + Vector3.new(0, 3, 0)
	pad.aim = pad.aim or (base + Vector3.new(0, 3, -10))
	pad.lastShot = 0
end

-- Points the barrel at a target (cylinders lie along X, so turn them 90 degrees)
local function aimBarrel(pad, target)
	local flatTarget = Vector3.new(target.X, pad.pivot.Y, target.Z)
	if (flatTarget - pad.pivot).Magnitude < 0.1 then
		return
	end
	pad.aim = flatTarget
	if pad.isArt then
		pad.barrel.CFrame = CFrame.lookAt(pad.pivot, flatTarget)
		return
	end
	pad.barrel.CFrame = CFrame.lookAt(pad.pivot, flatTarget)
		* CFrame.new(0, 0, -pad.barrelLength / 2 + 0.6)
		* CFrame.Angles(0, math.rad(90), 0)
end

local function fire(pad, target)
	local ammo = Ammo[pad.ammoType]
	local splash = Config.CANNON_SPLASH_RADIUS * ammo.splashMultiplier
	local damage = Config.CANNON_DAMAGE[pad.level] * ammo.damageMultiplier
	local muzzle = pad.pivot + (Vector3.new(target.X, pad.pivot.Y, target.Z) - pad.pivot).Unit * (pad.barrelLength - 0.2)
	if pad.isArt then
		muzzle += Vector3.new(0, 0.6, 0) -- the barrel sits above the carriage's center
	end
	SoundFx.playAt("cannon", muzzle)

	-- Muzzle flash
	local flash = makePart("Flash", Vector3.new(1.5, 1.5, 1.5), CFrame.new(muzzle), Color3.fromRGB(255, 200, 90), Enum.Material.Neon, folder)
	flash.Shape = Enum.PartType.Ball
	local flashLight = Instance.new("PointLight")
	flashLight.Color = Color3.fromRGB(255, 180, 80)
	flashLight.Range = 18
	flashLight.Brightness = 6
	flashLight.Parent = flash
	local fade = TweenService:Create(flash, TweenInfo.new(0.15), { Size = Vector3.new(3, 3, 3), Transparency = 1 })
	fade.Completed:Connect(function()
		flash:Destroy()
	end)
	fade:Play()

	-- Cannonball
	local ball = makePart("Cannonball", Vector3.new(0.9, 0.9, 0.9), CFrame.new(muzzle), ammo.ballColor, Enum.Material.Metal, folder)
	ball.Shape = Enum.PartType.Ball
	local travel = TweenService:Create(ball, TweenInfo.new(SHOT_TRAVEL_TIME, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target) })
	travel.Completed:Connect(function()
		ball:Destroy()
		SoundFx.playAt("cannonImpact", target)
		-- Damage lands on impact, around wherever the target is now
		creatures.damageArea(target, splash, damage, Config.CANNON_SPLASH_TARGETS, "Cannon", pad)
		local boom = makePart("Boom", Vector3.new(1, 1, 1), CFrame.new(target), ammo.boomColor, Enum.Material.Neon, folder)
		boom.Shape = Enum.PartType.Ball
		local blast = TweenService:Create(boom, TweenInfo.new(0.25), {
			Size = Vector3.new(splash * 2, splash * 2, splash * 2),
			Transparency = 1,
		})
		blast.Completed:Connect(function()
			boom:Destroy()
		end)
		blast:Play()
	end)
	travel:Play()
end

local function onPadTriggered(pad, player)
	local nextLevel = pad.level + 1
	local cost = Config.CANNON_COSTS[nextLevel]
	if not cost then
		return
	end
	if not upgrades.trySpend(cost) then
		notify(player, string.format("Need %d shells (the crew has %d).", cost, upgrades.getShells()))
		return
	end
	pad.level = nextLevel
	-- Ammo: a new cannon arrives fully loaded; an upgrade adds the extra capacity
	local oldMax = pad.maxAmmo
	pad.maxAmmo = Config.CANNON_CAPACITY[nextLevel]
	pad.ammo = if nextLevel == 1 then pad.maxAmmo else math.min(pad.maxAmmo, pad.ammo + (pad.maxAmmo - oldMax))
	-- Health: building or upgrading restores the cannon to full at its new level
	pad.maxHealth = Config.CANNON_HEALTH[nextLevel]
	pad.health = pad.maxHealth
	buildCannonModel(pad)
	aimBarrel(pad, pad.aim)
	updatePrompt(pad)
	updateAmmoUi(pad)
	SoundFx.playAt("build", pad.position)
	if nextLevel == 1 then
		EventLog.count("cannons")
		EventLog.log("CannonBuilt", { player = player.Name, pad = table.find(pads, pad) })
		notifyAll(player.DisplayName .. " built a cannon!")
	else
		EventLog.count("cannonUpgrades")
		EventLog.log("CannonUpgraded", { player = player.Name, pad = table.find(pads, pad), level = nextLevel })
		notifyAll(string.format("%s upgraded a cannon to level %d!", player.DisplayName, nextLevel))
	end
end

local function onReloadTriggered(pad, player)
	if pad.level == 0 then
		return
	end

	-- Shop ammo crates are used first; otherwise the player needs to be carrying oil
	local crateId, crateAmmoType = crateFor(player)
	local newType
	if crateId then
		newType = crateAmmoType
	elseif hasOil(player) then
		newType = Ammo.DEFAULT
	else
		notify(player, "Grab an oil barrel (or buy ammo crates in the GEAR shop), then reload.")
		SoundFx.playAt("denied", pad.position)
		return
	end
	if newType == pad.ammoType and pad.ammo >= pad.maxAmmo then
		notify(player, "This cannon is already full.")
		return
	end

	if crateId then
		if not takeCrate(player, crateId) then
			return
		end
	else
		takeOil(player)
	end
	-- Switching ammo types replaces what was loaded
	if newType ~= pad.ammoType then
		pad.ammoType = newType
		pad.ammo = 0
	end
	pad.ammo = math.min(pad.maxAmmo, pad.ammo + Ammo[newType].shotsPerLoad)
	updateAmmoUi(pad)
	SoundFx.playAt("build", pad.position)
	EventLog.count("cannonReloads", 1, player)
	EventLog.mark(player, "reload")
	EventLog.log("CannonReloaded", { player = player.Name, pad = table.find(pads, pad), ammo = pad.ammo, type = newType })
end

local function onHeartbeat()
	local now = os.clock()
	for _, pad in pads do
		if pad.level > 0 and pad.ammo > 0 and now - pad.lastShot >= Config.CANNON_COOLDOWN[pad.level] then
			local target = creatures.findTarget(pad.position, Config.CANNON_RANGE[pad.level])
			if target then
				pad.lastShot = now
				aimBarrel(pad, target)
				fire(pad, target)
				pad.ammo -= 1
				updateAmmoUi(pad)
				if pad.ammo == 0 then
					EventLog.count("cannonsEmptied")
					EventLog.log("CannonEmpty", { pad = table.find(pads, pad) })
					notifyAll("A cannon is out of ammo! Bring it an oil barrel to reload (R).")
				end
			end
		end
	end
end

-- Called by Main once oil carrying is set up
function DefenseService.setOilHandlers(hasOilFn, takeOilFn)
	hasOil = hasOilFn
	takeOil = takeOilFn
end

function DefenseService.setCrateHandlers(crateForFn, takeCrateFn)
	crateFor = crateForFn
	takeCrate = takeCrateFn
end

-- A creature chewing on a cannon (called every frame while it attacks)
function DefenseService.damageCannon(pad, amount)
	if pad.level == 0 then
		return
	end
	pad.health -= amount
	updateAmmoUi(pad)
	if pad.health <= 0 then
		-- Destroyed: the pad is empty again and must be rebuilt
		local position = pad.position
		if pad.model then
			pad.model:Destroy()
			pad.model = nil
		end
		pad.level = 0
		pad.ammo = 0
		pad.maxAmmo = 0
		pad.ammoType = Ammo.DEFAULT
		pad.health = 0
		pad.maxHealth = 0
		pad.glow = nil
		pad.aim = nil
		if pad.ring then
			pad.ring.Color = EMPTY_RING_COLOR
		end
		updatePrompt(pad)
		updateAmmoUi(pad)
		SoundFx.playAt("cannon", position)
		local wreck = makePart("Wreck", Vector3.new(2, 2, 2), CFrame.new(position + Vector3.new(0, 2, 0)), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, folder)
		wreck.Shape = Enum.PartType.Ball
		local blast = TweenService:Create(wreck, TweenInfo.new(0.5), { Size = Vector3.new(10, 10, 10), Transparency = 1 })
		blast.Completed:Connect(function()
			wreck:Destroy()
		end)
		blast:Play()
		notifyAll("A cannon was destroyed! Rebuild it on its pad.")
		EventLog.count("cannonsDestroyed")
		EventLog.log("CannonDestroyed", { pad = table.find(pads, pad) })
	end
end

function DefenseService.reset()
	for _, pad in pads do
		if pad.model then
			pad.model:Destroy()
			pad.model = nil
		end
		pad.level = 0
		pad.aim = nil
		pad.ammo = 0
		pad.maxAmmo = 0
		pad.ammoType = Ammo.DEFAULT
		pad.health = 0
		pad.maxHealth = 0
		pad.glow = nil
		if pad.ring then
			pad.ring.Color = EMPTY_RING_COLOR
		end
		updatePrompt(pad)
		updateAmmoUi(pad)
	end
end

function DefenseService.init(islandFolder, creatureService, upgradeService, notifyAllFn, notifyFn)
	creatures = creatureService
	upgrades = upgradeService
	notifyAll = notifyAllFn
	notify = notifyFn

	folder = Instance.new("Folder")
	folder.Name = "Defenses"
	folder.Parent = islandFolder

	if not Config.ECONOMY_ENABLED then
		return -- stripped-core playtest: no cannon pads
	end

	-- Stone pads where cannons can be built
	local center = Config.ISLAND_CENTER
	for index, bearing in Config.CANNON_PAD_BEARINGS do
		local rad = math.rad(bearing)
		local flat = center + Vector3.new(-math.sin(rad), 0, -math.cos(rad)) * Config.CANNON_PAD_RADIUS
		local position = Vector3.new(flat.X, Config.GROUND_Y, flat.Z)

		local padPart = makePart("CannonPad" .. index, Vector3.new(0.4, 6, 6), CFrame.new(position + Vector3.new(0, 0.2, 0)) * VERTICAL, Color3.fromRGB(120, 120, 125), Enum.Material.Cobblestone, folder)
		padPart.Shape = Enum.PartType.Cylinder
		padPart.CanCollide = true
		local ring = makePart("Ring", Vector3.new(0.1, 6.6, 6.6), CFrame.new(position + Vector3.new(0, 0.1, 0)) * VERTICAL, Color3.fromRGB(140, 255, 160), Enum.Material.Neon, folder)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.5

		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = padPart

		local pad = { position = position, level = 0, prompt = prompt, ring = ring, ammo = 0, maxAmmo = 0, ammoType = Ammo.DEFAULT }
		prompt.Triggered:Connect(function(player)
			onPadTriggered(pad, player)
		end)

		-- Second prompt for reloading (R on keyboard; shows as its own button on phones)
		local reloadPrompt = Instance.new("ProximityPrompt")
		reloadPrompt.ActionText = "Reload Cannon"
		reloadPrompt.KeyboardKeyCode = Enum.KeyCode.R
		reloadPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		reloadPrompt.HoldDuration = 0.5
		reloadPrompt.MaxActivationDistance = 10
		reloadPrompt.RequiresLineOfSight = false
		reloadPrompt.UIOffset = Vector2.new(0, 70) -- sits below the upgrade prompt
		reloadPrompt.Enabled = false
		reloadPrompt.Parent = padPart
		reloadPrompt.Triggered:Connect(function(player)
			onReloadTriggered(pad, player)
		end)
		pad.reloadPrompt = reloadPrompt

		-- Ammo label floating above the cannon
		local label = Instance.new("BillboardGui")
		label.Name = "AmmoLabel"
		label.Size = UDim2.fromOffset(150, 44)
		label.StudsOffset = Vector3.new(0, 6, 0)
		label.AlwaysOnTop = true
		label.MaxDistance = 160
		label.Enabled = false
		label.Parent = padPart
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 0, 18)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 13
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Parent = label
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0.8, 0, 0, 8)
		bar.Position = UDim2.new(0.1, 0, 0, 22)
		bar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		bar.BorderSizePixel = 0
		bar.Parent = label
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		pad.ammoLabel = label
		pad.ammoText = text
		pad.ammoFill = fill
		-- cannon health bar under the ammo bar
		local healthBack = Instance.new("Frame")
		healthBack.Size = UDim2.new(0.8, 0, 0, 6)
		healthBack.Position = UDim2.new(0.1, 0, 0, 34)
		healthBack.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		healthBack.BorderSizePixel = 0
		healthBack.Parent = label
		local healthFill = Instance.new("Frame")
		healthFill.Size = UDim2.fromScale(1, 1)
		healthFill.BorderSizePixel = 0
		healthFill.Parent = healthBack
		pad.healthFill = healthFill
		pad.health = 0
		pad.maxHealth = 0

		updatePrompt(pad)
		updateAmmoUi(pad)
		table.insert(pads, pad)
	end

	RunService.Heartbeat:Connect(onHeartbeat)
end

return DefenseService
