-- ShipRoster (batch 1 revision): the server-authoritative party roster for each departure ship.
--
-- The lobby holds as many players as the Roblox server allows. Only a ship's PARTY sails, and a party has at most
-- CAPACITY members (Config.MAX_CREW, 4). Party membership is the only thing that makes a player crew:
-- join() is the one place that sets the "Ready" attribute to true, and a player is always in at most one party
-- (player attribute "ShipId"). When a ship departs its party is frozen (locked) until the ship is back in port
-- (game Phase "Waiting"); nobody can join a ship that has sailed.
--
-- Today there is one ship ("Ship1", the existing pirate ship) and one voyage at a time. GameState still reads
-- the crew through the Ready attribute, which this module keeps in step with the roster.

local Players = game:GetService("Players")

local ShipRoster = {}
ShipRoster.CAPACITY = 4

local ships = {} -- shipId -> { id, members = { [player] = joinedAt }, locked = false }
local state = nil

local function memberList(ship)
	local list = {}
	for p in ship.members do
		if p.Parent == Players then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return ship.members[a] < ship.members[b]
	end)
	return list
end

local function publish(ship)
	if state then
		state:SetAttribute("Ship_" .. ship.id .. "_Count", #memberList(ship))
		state:SetAttribute("Ship_" .. ship.id .. "_Locked", ship.locked)
	end
end

function ShipRoster.init(stateFolder, capacity, shipIds)
	state = stateFolder
	ShipRoster.CAPACITY = capacity or ShipRoster.CAPACITY
	state:SetAttribute("ShipCapacity", ShipRoster.CAPACITY)
	for _, id in shipIds do
		ships[id] = { id = id, members = {}, locked = false }
		publish(ships[id])
	end
	-- anything that drops a player out of the crew (menu, results screen, rematch "no") also frees the seat
	local function watch(player)
		player:GetAttributeChangedSignal("Ready"):Connect(function()
			if player:GetAttribute("Ready") ~= true and player:GetAttribute("ShipId") ~= nil then
				ShipRoster.leave(player, "not ready")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		ShipRoster.leave(player, "disconnect")
	end)
	-- back in port: every ship takes a new party
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") == "Waiting" then
			for _, ship in ships do
				ship.locked = false
				publish(ship)
			end
		end
	end)
end

function ShipRoster.shipOf(player)
	return player:GetAttribute("ShipId")
end

function ShipRoster.members(shipId)
	local ship = ships[shipId]
	return if ship then memberList(ship) else {}
end

-- Returns ok, reason ("joined" | "already" | "full" | "sailed" | "noship")
function ShipRoster.join(player, shipId)
	local ship = ships[shipId]
	if not ship then
		return false, "noship"
	end
	if ship.members[player] then
		return true, "already"
	end
	if ship.locked then
		return false, "sailed"
	end
	if #memberList(ship) >= ShipRoster.CAPACITY then
		return false, "full"
	end
	if player:GetAttribute("ShipId") ~= nil then
		ShipRoster.leave(player, "switch") -- one party at a time
	end
	ship.members[player] = os.clock()
	player:SetAttribute("ShipId", shipId)
	player:SetAttribute("Ready", true)
	publish(ship)
	return true, "joined"
end

-- Frees the player's seat. Returns true if they were in a party.
function ShipRoster.leave(player, why)
	local shipId = player:GetAttribute("ShipId")
	local ship = shipId and ships[shipId]
	if ship then
		ship.members[player] = nil
	end
	if shipId == nil then
		return false
	end
	player:SetAttribute("ShipId", nil)
	if player.Parent == Players and player:GetAttribute("Ready") then
		player:SetAttribute("Ready", false)
	end
	if ship then
		publish(ship)
	end
	return true
end

-- Departure: freezes the party and returns exactly the players who sail.
function ShipRoster.depart(shipId)
	local ship = ships[shipId]
	if not ship then
		return {}
	end
	ship.locked = true
	local sailing = memberList(ship)
	for p in ship.members do
		if p.Parent ~= Players then
			ship.members[p] = nil
		end
	end
	publish(ship)
	return sailing
end

return ShipRoster
