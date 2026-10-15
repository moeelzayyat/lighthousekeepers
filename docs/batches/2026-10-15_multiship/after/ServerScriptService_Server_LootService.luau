-- LootService: loot that pops out of dead creatures.
--
-- Every crab drops Shells. Some drop rare loot with a colored light pillar:
--   Sea Glass   (blue, rare)    worth SEA_GLASS_VALUE shells
--   Black Pearl (purple, epic)  worth BLACK_PEARL_VALUE shells + server announcement
--
-- Loot flies to any player who comes close and goes into the crew's shared pool.
-- Uncollected loot washes away after LOOT_LIFETIME seconds, and at dawn,
-- so someone has to run out into the dark to grab it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EventLog = require(script.Parent.EventLog)
local VoyageCast = require(script.Parent.VoyageCast)
local Ground = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ground"))
local Creatures = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Creatures"))

local LootService = {}

-- `item` = goes into the collecting player's saved inventory (see Shared/Items) instead of the crew's shells
local KINDS = {
	Shells = { color = Color3.fromRGB(255, 225, 205), size = 0.9, pillar = nil },
	CrabClaw = { color = Color3.fromRGB(230, 120, 80), size = 0.8, pillar = nil, item = "CrabClaw" },
	SeaGlass = { color = Color3.fromRGB(90, 190, 255), size = 1.3, pillar = Color3.fromRGB(90, 190, 255), name = "Sea Glass", item = "SeaGlass" },
	BlackPearl = { color = Color3.fromRGB(170, 90, 255), size = 1.6, pillar = Color3.fromRGB(170, 90, 255), name = "a BLACK PEARL", item = "BlackPearl" },
	-- Pearls (the permanent currency) dropped by big monsters: added straight to the collector's saved Pearls
	Pearls = { color = Color3.fromRGB(245, 240, 255), size = 1.4, pillar = Color3.fromRGB(255, 245, 210), name = "Pearls", pearls = true },
}
local MAGNET_SPEED = 35

local folder
local upgrades
local remotes
local playerData
local drops = {}

local function makePart(name, size, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function groundAt(position)
	local center = Config.ISLAND_CENTER
	local radius = Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude
	if radius <= Config.ISLAND_RADIUS then
		return Config.GROUND_Y
	elseif radius <= Config.ISLAND_RADIUS + 8 then
		return 3
	end
	return 0
end

local function spawnDrop(kind, value, position)
	local info = KINDS[kind]
	local orb = makePart("Loot_" .. kind, Vector3.new(info.size, info.size, info.size), info.color, Enum.PartType.Ball)
	orb.CFrame = CFrame.new(position)
	orb.Parent = folder

	local pillar
	if info.pillar then
		pillar = makePart("Pillar", Vector3.new(0.5, 14, 0.5), info.pillar)
		pillar.Transparency = 0.45
		pillar.Parent = orb
	end

	-- Pop out in a little arc, then rest on the ground
	local angle = math.random() * math.pi * 2
	local landing = position + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
	landing = Vector3.new(landing.X, Ground.heightAt(landing.X, landing.Z) + info.size / 2 + 0.2, landing.Z)
	local drop = {
		kind = kind,
		value = value,
		orb = orb,
		pillar = pillar,
		position = landing,
		bornAt = os.clock(),
		landed = false,
	}
	local pop = TweenService:Create(orb, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(landing),
	})
	pop.Completed:Connect(function()
		drop.landed = true
	end)
	pop:Play()
	if pillar then
		pillar.CFrame = CFrame.new(landing + Vector3.new(0, 7, 0))
	end
	table.insert(drops, drop)
end

-- Called whenever a creature dies. Big monsters drop a big pile of loot.
function LootService.dropFrom(position, kind)
	if not Config.ECONOMY_ENABLED then
		return
	end
	local stats = kind and Creatures[kind]
	if stats and stats.swarm then
		-- swarm crabs: a Shell now and then, no rare loot (keeps the economy where it was)
		if math.random() < (Config.SWARM_SHELL_CHANCE or 0.2) then
			spawnDrop("Shells", 1, position)
		end
		return
	end
	if stats and stats.big then
		spawnDrop("Shells", Config.BIG_LOOT_SHELLS, position)
		spawnDrop("SeaGlass", 1, position)
		spawnDrop("CrabClaw", 1, position)
		spawnDrop("CrabClaw", 1, position)
		if math.random() < Config.BIG_PEARL_CHANCE then
			spawnDrop("BlackPearl", 1, position)
		end
		if math.random() < Config.BOSS_PEARL_CHANCE then
			spawnDrop("Pearls", math.random(Config.BOSS_PEARL_MIN, Config.BOSS_PEARL_MAX), position)
		end
		VoyageCast.fire(remotes.Notify, "The monster is down! Grab its loot!")
		return
	end
	spawnDrop("Shells", math.random(Config.SHELLS_PER_CRAB_MIN, Config.SHELLS_PER_CRAB_MAX), position)
	if math.random() < Config.CRAB_CLAW_CHANCE then
		spawnDrop("CrabClaw", 1, position)
	end

	local roll = math.random()
	if roll < Config.BLACK_PEARL_CHANCE then
		spawnDrop("BlackPearl", 1, position)
	elseif roll < Config.BLACK_PEARL_CHANCE + Config.SEA_GLASS_CHANCE then
		spawnDrop("SeaGlass", 1, position)
	end
end

local function removeAt(index)
	local drop = table.remove(drops, index)
	drop.orb:Destroy()
end

local function collect(index, player)
	local drop = drops[index]
	local info = KINDS[drop.kind]
	if info.pearls then
		-- Permanent currency straight into this player's saved Pearls
		playerData.addPearls(player, drop.value, "boss drop")
		EventLog.log("BossPearls", { player = player.Name, amount = drop.value })
		remotes.LootCollected:FireClient(player, drop.kind, drop.value)
		VoyageCast.fire(remotes.Notify, string.format("%s picked up %d Pearls from the monster!", player.DisplayName, drop.value))
		removeAt(index)
		return
	end
	if info.item then
		-- Personal loot: into this player's saved inventory
		playerData.addItem(player, info.item, drop.value)
		EventLog.loot(drop.kind, 0, player)
	else
		upgrades.addShells(drop.value)
		EventLog.loot(drop.kind, drop.value, player)
	end
	if drop.kind == "SeaGlass" or drop.kind == "BlackPearl" then
		EventLog.log("RareLoot", { player = player.Name, kind = drop.kind })
	end
	remotes.LootCollected:FireClient(player, drop.kind, drop.value)
	if drop.kind == "BlackPearl" then
		VoyageCast.fire(remotes.Notify, string.format("%s found %s!", player.DisplayName, info.name))
	elseif drop.kind == "SeaGlass" then
		VoyageCast.fire(remotes.Notify, string.format("%s found %s!", player.DisplayName, info.name))
	end
	removeAt(index)
end

-- How many loot orbs are lying around right now
function LootService.count()
	return #drops
end

-- Dawn (Oct 12 2026, owner: loot vanished as soon as the night ended): every orb still on the
-- ground gets at least `seconds` more before it washes away, so the crew can go and collect it.
function LootService.keepFor(seconds)
	local now = os.clock()
	for _, drop in drops do
		local remaining = Config.LOOT_LIFETIME - (now - drop.bornAt)
		if remaining < seconds then
			drop.bornAt = now - (Config.LOOT_LIFETIME - seconds)
		end
	end
end

function LootService.clearAll()
	for index = #drops, 1, -1 do
		removeAt(index)
	end
end

-- At dawn the tide carries leftover loot to the crew at a fraction of its value,
-- so a solo Keeper who couldn't leave the lamp still gets something.
-- Returns the number of shells added.
function LootService.tideCollect(fraction)
	local total = 0
	for _, drop in drops do
		if drop.kind == "Shells" then -- personal items aren't carried in by the tide
			total += drop.value
		end
	end
	LootService.clearAll()
	local shells = math.floor(total * fraction)
	if shells > 0 then
		upgrades.addShells(shells)
		EventLog.loot("Tide", shells)
		EventLog.log("TideLoot", { shells = shells, fullValue = total })
		VoyageCast.fire(remotes.Notify, string.format("The tide brought in %d shells from uncollected loot.", shells))
	end
	return shells
end

local function onHeartbeat(dt)
	if #drops == 0 then
		return
	end

	-- Collect living players' positions once per frame
	local players = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(players, { player = player, position = root.Position })
		end
	end

	local now = os.clock()
	for index = #drops, 1, -1 do
		local drop = drops[index]
		if now - drop.bornAt > Config.LOOT_LIFETIME then
			removeAt(index)
		elseif drop.landed then
			-- Find the nearest player within magnet range
			local nearest, nearestDistance = nil, Config.LOOT_MAGNET_RADIUS
			for _, entry in players do
				local distance = (entry.position - drop.position).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = entry, distance
				end
			end

			if nearest and nearestDistance <= Config.LOOT_PICKUP_RADIUS then
				collect(index, nearest.player)
			elseif nearest then
				local step = math.min(MAGNET_SPEED * dt, nearestDistance)
				drop.position += (nearest.position - drop.position).Unit * step
				drop.orb.CFrame = CFrame.new(drop.position)
			else
				-- Idle: bob and spin so it catches the eye
				local bob = math.sin(now * 3 + index) * 0.2
				drop.orb.CFrame = CFrame.new(drop.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * 2, 0)
			end
			if drop.pillar then
				drop.pillar.CFrame = drop.orb.CFrame * CFrame.new(0, 7, 0)
			end
		end
	end
end

function LootService.init(islandFolder, upgradeService, remoteFolder, playerDataService)
	upgrades = upgradeService
	remotes = remoteFolder
	playerData = playerDataService
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = islandFolder
	RunService.Heartbeat:Connect(onHeartbeat)
end

return LootService
