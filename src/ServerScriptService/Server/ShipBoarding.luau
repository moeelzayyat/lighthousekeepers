-- ShipBoarding (boarding batch): automatic party membership by standing on a departure ship.
--
-- A player who has pressed Play (InLobby) and walks onto a ship's boarding zone joins that ship's party
-- through ShipRoster (the only place crew membership is decided). The zone is the ship's invisible BoardingZone
-- part (LobbyBuilder: the walkable decks only, so the pier and the shore never count).
-- Boarding never starts a departure; ShipDeparture decides that (4/4 automatic, or SAIL NOW for 1 to 3).
--   * seats fill in arrival order up to ShipRoster.CAPACITY; anyone after that is told the crew is full
--     and stays free to explore or board another ship
--   * stepping off the ship before departure frees the seat (after a short grace, so a stumble at the
--     rail doesn't cost it)
--   * once the ship has sailed nobody can board it until it is back in port (ShipRoster lock)
-- Only seats taken HERE are released by stepping off: a crew that stays on for a rematch is on the island,
-- not on the ship, and keeps its seats (the flag is cleared when the ship departs).
--
-- Replicated player attributes for the client:
--   NearShip      = shipId while the player stands in that ship's zone, else nil
--   BoardRefused  = "full" | "sailed" while in the zone and not in its party, else nil
--   BoardedByDeck = true while the seat was taken by walking aboard (cleared at departure)

local Players = game:GetService("Players")

local ShipBoarding = {}

local POLL = 0.25
local LEAVE_GRACE = 1.0 -- seconds off the ship before a deck seat is released

local zones = {} -- shipId -> { cframe, half }
local offSince = {} -- player -> os.clock() when they left the zone they boarded through
local inZone = {} -- player -> shipId (last poll)

local function zoneOf(position)
	for shipId, zone in zones do
		local p = zone.cframe:PointToObjectSpace(position)
		if math.abs(p.X) <= zone.half.X and math.abs(p.Z) <= zone.half.Z and math.abs(p.Y) <= zone.half.Y then
			return shipId
		end
	end
	return nil
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

-- deps: roster (ShipRoster), zones = { [shipId] = BoardingZone part }, notify(player, text), log(kind, data),
-- canBoard(player) -> bool
function ShipBoarding.init(deps)
	local roster = deps.roster
	for shipId, part in deps.zones do
		zones[shipId] = { cframe = part.CFrame, half = part.Size / 2 }
	end

	local function refuse(player, shipId, reason, entered)
		player:SetAttribute("BoardRefused", reason)
		if entered then
			deps.notify(player, if reason == "full"
				then string.format("Crew full (%d of %d). Find another ship and sail, or wait for the next voyage.", roster.CAPACITY, roster.CAPACITY)
				else "This ship is at sea with its crew. Wait here: the next voyage takes a new crew.")
			deps.log("CrewRefused", { player = player.Name, via = "deck", reason = reason, ship = shipId })
		end
	end

	local function step(player)
		local root = rootOf(player)
		local here = if root and deps.canBoard(player) then zoneOf(root.Position) else nil
		local entered = here ~= nil and inZone[player] ~= here
		inZone[player] = here
		player:SetAttribute("NearShip", here)

		local mine = roster.shipOf(player)
		-- a seat taken by walking aboard is released by walking off (before departure only)
		if mine and player:GetAttribute("BoardedByDeck") and here ~= mine then
			offSince[player] = offSince[player] or os.clock()
			if os.clock() - offSince[player] >= LEAVE_GRACE then
				offSince[player] = nil
				player:SetAttribute("BoardedByDeck", nil)
				if roster.leave(player, "stepped off") then
					deps.notify(player, "You stepped off the ship and left the crew. Walk back aboard to rejoin.")
					deps.log("LeftCrew", { player = player.Name, via = "deck", ship = mine })
				end
				mine = nil
			end
		else
			offSince[player] = nil
		end

		if not here then
			player:SetAttribute("BoardRefused", nil)
			return
		end
		if mine == here then
			player:SetAttribute("BoardRefused", nil)
			return
		end
		if mine ~= nil then
			-- in another party (for example a rematch crew); one party at a time, never switched silently
			player:SetAttribute("BoardRefused", nil)
			return
		end
		local ok, reason = roster.join(player, here)
		if ok then
			player:SetAttribute("BoardRefused", nil)
			if reason == "joined" then
				player:SetAttribute("BoardedByDeck", true)
				local n = #roster.members(here)
				deps.notify(player, if n >= roster.CAPACITY
					then string.format("You're in the crew (%d of %d). The crew is full: the ship is preparing to sail.", n, roster.CAPACITY)
					else string.format("You're in the crew (%d of %d). Waiting for crew: use SAIL NOW at the wheel to leave sooner. Step off to leave the crew.", n, roster.CAPACITY))
				deps.log("PlayerReady", { player = player.Name, via = "deck", ship = here })
				if deps.mark then
					deps.mark(player, "crew")
				end
			end
		else
			refuse(player, here, reason, entered)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		offSince[player] = nil
		inZone[player] = nil
	end)

	if deps.manual then
		ShipBoarding.step = step -- unit tests drive the poll themselves (stand-in players)
		return
	end
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(step, player)
				if not ok then
					warn("[ShipBoarding] " .. tostring(err))
				end
			end
			task.wait(POLL)
		end
	end)
end

-- Departure: the party sails, so walking-on seats become ordinary voyage seats (kept for a rematch)
function ShipBoarding.departed(members)
	for _, p in members do
		p:SetAttribute("BoardedByDeck", nil)
		offSince[p] = nil
	end
end

-- test hook: which ship zone (if any) contains a world position
ShipBoarding.zoneOf = zoneOf

return ShipBoarding
