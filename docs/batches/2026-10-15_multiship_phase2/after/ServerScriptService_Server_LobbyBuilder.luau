-- LobbyBuilder: the lobby is a small island with a pirate ship parked at its shore.
-- Players spawn on the island; the ship (reached by the pier) is how the crew sails to the lighthouse.
--
-- Players arrive on the deck after pressing Play. On deck:
--   * the Quartermaster (shop) - moved here from the island
--   * the ship's wheel - "Join the crew" readies you for the next run (or joins a run in progress)
-- The run island's spawn is turned into an arrival point; the ship is the only spawn.
--
-- The ship comes from ServerStorage.Art.PirateShip. If it's missing, a simple deck is built instead.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ground = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ground"))

local LobbyBuilder = {}

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.WoodPlanks
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Finds the walkable deck height at a point by casting a ray down onto the ship's floors
-- (only parts named like "...Floor" or "Deck", so masts, sails, and rigging are ignored)
local function deckHeightAt(ship, position)
	local floors = {}
	for _, part in ship:GetDescendants() do
		if part:IsA("BasePart") and (part.Name:find("Floor") or part.Name == "Deck") then
			table.insert(floors, part)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if #floors > 0 then floors else { ship }
	local hit = Workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -160, 0), params)
	return hit and hit.Position.Y
end

function LobbyBuilder.build(islandRefs)
	local old = Workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace

	local center = Config.LOBBY_POSITION
	-- The ship's bow points at the island
	local facing = CFrame.lookAt(Vector3.new(center.X, 0, center.Z), Vector3.new(Config.ISLAND_CENTER.X, 0, Config.ISLAND_CENTER.Z))

	local ship
	local art = ServerStorage:FindFirstChild("Art") and ServerStorage.Art:FindFirstChild("PirateShip")
	if art then
		ship = art:Clone()
		ship.Name = "PirateShip"
		ship:PivotTo(facing * CFrame.new(0, art:GetAttribute("WaterlineOffset") or 0, 0) * CFrame.Angles(0, math.rad(art:GetAttribute("YawOffset") or 0), 0))
		for _, part in ship:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		ship.Parent = lobby
	else
		-- Fallback: a plain wooden deck with railings
		ship = Instance.new("Model")
		ship.Name = "PirateShip"
		local deck = makePart("Deck", Vector3.new(24, 2, 70), facing * CFrame.new(0, 4, 0), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks, ship)
		makePart("Hull", Vector3.new(22, 8, 66), facing * CFrame.new(0, -1, 0), Color3.fromRGB(70, 45, 30), Enum.Material.Wood, ship)
		for _, x in { -11.5, 11.5 } do
			makePart("Rail", Vector3.new(1, 3, 70), facing * CFrame.new(x, 6.5, 0), Color3.fromRGB(95, 65, 40), Enum.Material.Wood, ship)
		end
		ship.PrimaryPart = deck
		ship.Parent = lobby
	end

	-- Deck height at the middle of the ship, and toward the back (wheel) and front (shop)
	local function deckPoint(localX, localZ)
		local flat = (facing * CFrame.new(localX, 0, localZ)).Position
		local y = deckHeightAt(ship, flat) or 6
		return Vector3.new(flat.X, y, flat.Z)
	end
	local middle = deckPoint(0, 0)
	local back = deckPoint(0, Config.LOBBY_WHEEL_OFFSET)
	local front = deckPoint(0, -Config.LOBBY_SHOP_OFFSET)

	-- Spawn on the deck (the only spawn in the game)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DeckSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	local spawnXZ = Config.LOBBY_SPAWN
	local spawnPos = Vector3.new(spawnXZ.X, Ground.heightAt(spawnXZ.X, spawnXZ.Z) + 0.2, spawnXZ.Z)
	spawn.CFrame = CFrame.lookAt(spawnPos, Vector3.new(center.X, spawnPos.Y, center.Z)) -- face the ship
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lobby
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- The island's old spawn becomes the crew's arrival point
	local islandSpawn = islandRefs.folder:FindFirstChild("SpawnLocation")
	local arrival = if islandSpawn then islandSpawn.CFrame else CFrame.new(0, Config.GROUND_Y + 3, 24)
	if islandSpawn then
		islandSpawn.Enabled = false
	end

	-- The ship's wheel: "Join the crew" (uses the ship model's own wheel if it has one)
	local wheel = ship:FindFirstChild("WheelStand", true) or ship:FindFirstChild("WheelHub", true)
	if not wheel then
		wheel = makePart("WheelPost", Vector3.new(1.2, 3.4, 1.2), CFrame.new(back + Vector3.new(0, 1.7, 0)) * facing.Rotation, Color3.fromRGB(90, 60, 38), Enum.Material.Wood, lobby)
		local ring = makePart("Wheel", Vector3.new(0.4, 4, 4), CFrame.new(back + Vector3.new(0, 3.6, 0)) * facing.Rotation * CFrame.new(0, 0, -0.7) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 105, 60), Enum.Material.Wood, lobby)
		ring.Shape = Enum.PartType.Cylinder
	end
	-- Departure revision: the wheel is the crew's SAIL NOW (1 to 3 aboard); boarding is by the BoardingZone
	local helmPrompt = Instance.new("ProximityPrompt")
	helmPrompt.Name = "HelmPrompt"
	helmPrompt.ActionText = "Sail now"
	helmPrompt.ObjectText = "Ship's Wheel"
	helmPrompt.KeyboardKeyCode = Enum.KeyCode.E
	helmPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	helmPrompt.HoldDuration = 0.3
	helmPrompt.MaxActivationDistance = 12
	helmPrompt.RequiresLineOfSight = false
	helmPrompt.Parent = wheel
	-- (the wheel's departure sign is drawn per player by Client.Departure since UI Stage 6)

	-- BoardingZone (departure revision): an invisible box over the ship's walkable decks only (the parts
	-- named "...Floor" or "Deck"), from just under the lowest deck to 8 studs above the highest. Standing
	-- in it is what puts a player in this ship's party; the pier, the water and the shore are outside it.
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ship:GetDescendants() do
		if part:IsA("BasePart") and (part.Name:find("Floor") or part.Name == "Deck") then
			local h = part.Size / 2
			for _, c in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local v = facing:PointToObjectSpace(part.CFrame:PointToWorldSpace(h * c))
				lo = lo:Min(v)
				hi = hi:Max(v)
			end
		end
	end
	if lo.X == math.huge then -- no named floors: fall back to the deck around the ship's middle
		lo, hi = facing:PointToObjectSpace(middle) - Vector3.new(10, 1, 30), facing:PointToObjectSpace(middle) + Vector3.new(10, 0, 30)
	end
	hi += Vector3.new(0, 8, 0)
	local boardingZone = Instance.new("Part")
	boardingZone.Name = "BoardingZone"
	boardingZone.Anchored = true
	boardingZone.CanCollide = false
	boardingZone.CanQuery = false
	boardingZone.CanTouch = false
	boardingZone.CastShadow = false
	boardingZone.Transparency = 1
	boardingZone.Size = hi - lo
	boardingZone.CFrame = facing * CFrame.new((lo + hi) / 2)
	boardingZone:SetAttribute("ShipId", "Ship1")
	boardingZone.Parent = lobby

	-- The Quartermaster's market stall stands on the lobby island beside the path to the pier,
	-- its counter facing the path, the Quartermaster behind it.
	local keeper = islandRefs.folder:FindFirstChild("Quartermaster")
	local counter = islandRefs.shopCounter
	local stall = islandRefs.folder:FindFirstChild("ShopStall")
	local shopXZ = Config.LOBBY_SHOP
	local shopSpot = Vector3.new(shopXZ.X, Ground.heightAt(shopXZ.X, shopXZ.Z), shopXZ.Z)
	-- -Z points at the path to the pier, where players walk past
	local shopFacing = CFrame.lookAt(shopSpot, Vector3.new(0, shopSpot.Y, shopXZ.Z))
	if stall then
		local _, stallSize = stall:GetBoundingBox()
		-- the stall model's counter faces +Z; turn it so the counter faces the players
		stall:PivotTo(shopFacing * CFrame.new(0, stallSize.Y / 2, 0) * CFrame.Angles(0, math.rad(180), 0))
		stall.Parent = lobby
	end
	if keeper then
		-- Behind the counter, looking at the players (the model faces -Z). The stall's counter sits about
		-- 2 studs back from shopSpot, so 1.2 put him INSIDE it (fixed Oct 12). He now stands 4.95 back
		-- (clear of the counter top and the shelves, checked by overlap test), on a small step so his
		-- upper body shows over the 3.7-stud counter.
		local STEP = 1.5
		local BACK = 4.95
		local step = Instance.new("Part")
		step.Name = "KeeperStep"
		step.Anchored = true
		step.Size = Vector3.new(2.6, STEP, 2.6)
		step.Material = Enum.Material.WoodPlanks
		step.Color = Color3.fromRGB(110, 78, 50)
		step.CFrame = shopFacing * CFrame.new(0, STEP / 2, BACK)
		step.Parent = lobby
		keeper.CFrame = shopFacing * CFrame.new(0, STEP + keeper.Size.Y / 2, BACK)
		keeper.Parent = lobby
	end
	counter.CFrame = shopFacing * CFrame.new(0, 2.5, -3)
	counter.Parent = lobby

	return {
		folder = lobby,
		spawn = spawn,
		helmPrompt = helmPrompt,
		boardingZone = boardingZone,
		islandArrival = arrival,
		deckCenter = middle,
	}
end

-- Multi-ship phase 2 (harbor role only, behind Config.MULTI_SHIP_ENABLED): more departure ships moored beside
-- the first. Each is a copy of the first ship with its OWN BoardingZone (the first ship's zone, moved with it),
-- its own wheel prompt (SAIL NOW) and a gangway to the shore. Returns { [shipId] = { helmPrompt, boardingZone } }.
local EXTRA_SHIPS = { { id = "Ship2", side = 48 } } -- side: studs along world X from the first ship

function LobbyBuilder.buildExtraShips(lobbyRefs)
	local lobby = lobbyRefs.folder
	local first = lobby:FindFirstChild("PirateShip")
	lobbyRefs.helmPrompt:SetAttribute("ShipId", "Ship1")
	lobbyRefs.boardingZone:SetAttribute("ShipId", "Ship1")
	local built = {}
	for _, spec in EXTRA_SHIPS do
		local shift = CFrame.new(spec.side, 0, 0)
		local ship = first:Clone()
		ship.Name = "PirateShip_" .. spec.id
		for _, d in ship:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		ship:PivotTo(shift * first:GetPivot())
		ship.Parent = lobby

		local zone = lobbyRefs.boardingZone:Clone()
		zone.Name = "BoardingZone_" .. spec.id
		zone.CFrame = shift * lobbyRefs.boardingZone.CFrame
		zone:SetAttribute("ShipId", spec.id)
		zone.Parent = lobby

		-- the wheel: the copy's own wheel, or a simple post at the stern if the ship has none
		local wheel = ship:FindFirstChild("WheelStand", true) or ship:FindFirstChild("WheelHub", true)
		if not wheel then
			local post = lobbyRefs.helmPrompt.Parent
			wheel = makePart("WheelPost_" .. spec.id, post.Size, shift * post.CFrame, post.Color, post.Material, lobby)
		end
		local prompt = lobbyRefs.helmPrompt:Clone()
		prompt.Enabled = true
		prompt:SetAttribute("ShipId", spec.id)
		prompt.Parent = wheel

		-- gangway from the stern down to the shore
		local deckTop = -math.huge
		for _, part in ship:GetDescendants() do
			if part:IsA("BasePart") and (part.Name:find("Floor") or part.Name == "Deck") then
				deckTop = math.max(deckTop, part.Position.Y + part.Size.Y / 2)
			end
		end
		if deckTop == -math.huge then
			deckTop = zone.Position.Y - zone.Size.Y / 2 + 1
		end
		local sternZ = zone.Position.Z + zone.Size.Z / 2
		local x = zone.Position.X
		local fromPos = Vector3.new(x, deckTop, sternZ - 2)
		local shoreZ = sternZ + 24
		local toPos = Vector3.new(x, Ground.heightAt(x, shoreZ) + 0.5, shoreZ)
		local length = (toPos - fromPos).Magnitude
		makePart("Gangway_" .. spec.id, Vector3.new(7, 1, length), CFrame.lookAt((fromPos + toPos) / 2, toPos), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks, lobby)

		built[spec.id] = { helmPrompt = prompt, boardingZone = zone, ship = ship }
	end
	return built
end

return LobbyBuilder
