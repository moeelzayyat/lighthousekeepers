-- IsleAdmission (multi-ship phase 2, isle role only): who the crew of this Lighthouse Isle server is, and when
-- its voyage starts. It plugs into the EXISTING voyage loop (GameState) through the same two hooks the
-- single-server game uses (deps.departure and deps.departShip), so no game logic is duplicated.
--
--   * reserved server with a manifest (Voyages): only the listed UserIds are crew; anyone else is sent back to
--     the harbor. The voyage starts when everyone listed has arrived, or ISLE_ARRIVAL_WAIT seconds after the
--     first one did (crew-size scaling already uses the real count).
--   * no manifest (Studio test with PLACE_ROLE_OVERRIDE = "isle"): everyone who joins is crew, same timing.
--   * Play Again: the players who chose it sail again in this same server (GameState's rematch flow).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local IsleAdmission = {}

local SHIP_ID = "Isle"

local deps = nil
local expected = nil -- { [userId] = true } from the manifest, or nil = anyone
local expectedCount = 0
local firstArrival = nil
local started = false
local rematchWanted = false

local function admitted()
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InLobby") == true and (expected == nil or expected[player.UserId]) then
			table.insert(list, player)
		end
	end
	return list
end

-- deps: manifest (table or nil), sendToHarbor(player), log(kind, data)
function IsleAdmission.init(d)
	deps = d
	if d.manifest and d.manifest.userIds then
		expected = {}
		for _, id in d.manifest.userIds do
			expected[id] = true
			expectedCount += 1
		end
	end
	local function onJoin(player)
		if expected and not expected[player.UserId] then
			deps.log("IsleRefused", { player = player.Name })
			deps.sendToHarbor(player)
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
end

-- GameState: is there a voyage to start?
function IsleAdmission.requested()
	if started then
		if not rematchWanted then
			return false
		end
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Ready") == true then
				return true
			end
		end
		rematchWanted = false -- everyone who wanted it left
		return false
	end
	local list = admitted()
	if #list == 0 then
		return false
	end
	firstArrival = firstArrival or os.clock()
	local everyone = expected ~= nil and #list >= expectedCount
	return everyone or os.clock() - firstArrival >= (Config.ISLE_ARRIVAL_WAIT or 20)
end

-- GameState: the countdown finished; these players sail (the existing loop takes them to the lighthouse).
function IsleAdmission.depart()
	if started and rematchWanted then
		rematchWanted = false
		local crew = {}
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Ready") == true then
				table.insert(crew, player)
			end
		end
		return crew
	end
	started = true
	local crew = admitted()
	for _, player in crew do
		player:SetAttribute("ShipId", SHIP_ID)
		player:SetAttribute("Ready", true)
	end
	deps.log("IsleVoyage", { crew = #crew, expected = expectedCount })
	return crew
end

-- GameState: Play Again was chosen by at least one crew member
function IsleAdmission.rematch()
	rematchWanted = true
end

return IsleAdmission
