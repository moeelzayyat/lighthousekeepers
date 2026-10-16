-- IsleAdmission (multi-ship phase 2, isle role only): who the crew of this Lighthouse Isle server is, and when
-- its voyage starts. It plugs into the EXISTING voyage loop (GameState) through the same two hooks the
-- single-server game uses (deps.departure and deps.departShip), so no game logic is duplicated.
--
-- Fail closed (fix 2, 2026-10-16):
--   * A LIVE isle server needs a valid server-side manifest (Voyages): a table for THIS reserved server
--     (privateServerId), not expired, with 1..capacity distinct positive UserIds. Missing, expired, malformed or
--     foreign manifest -> no voyage at all, and everyone is sent back to the harbor.
--   * The manifest-free simulation (everyone who joins is crew) exists ONLY in explicit Studio test mode
--     (Config.ISLE_STUDIO_TEST = true AND running in Studio).
--   * Only listed UserIds may become crew. The voyage starts when every listed player has arrived, or
--     ISLE_ARRIVAL_WAIT seconds after the first arrival with whoever is here (fewer than four is fine).
--   * Once the voyage is frozen, nobody else joins it: a late arrival (listed or not) is sent back to the harbor
--     and is never Ready, so it never earns run rewards. If nobody arrives, no voyage starts.
--   * Play Again: the players who chose it sail again in this same server (GameState's rematch flow).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local IsleAdmission = {}

local SHIP_ID = "Isle"
local MANIFEST_MAX_AGE = 600 -- seconds; matches the manifest's MemoryStore expiry in Voyages

-- Pure check of a manifest for this server. Returns ok, reason, { [userId] = true }, count.
function IsleAdmission.validate(manifest, privateServerId, capacity, now)
	if type(manifest) ~= "table" then
		return false, "missing"
	end
	if manifest.privateServerId ~= privateServerId or type(privateServerId) ~= "string" or privateServerId == "" then
		return false, "wrong server"
	end
	if type(manifest.createdAt) ~= "number" or now - manifest.createdAt > MANIFEST_MAX_AGE or manifest.createdAt > now + 60 then
		return false, "expired"
	end
	if type(manifest.userIds) ~= "table" or #manifest.userIds < 1 or #manifest.userIds > capacity then
		return false, "bad crew size"
	end
	local set, count = {}, 0
	for _, id in manifest.userIds do
		if type(id) ~= "number" or id <= 0 or id % 1 ~= 0 or set[id] then
			return false, "bad user id"
		end
		set[id] = true
		count += 1
	end
	return true, "ok", set, count
end

-- per-server state (reset by init)
local deps, expected, expectedCount, firstArrival, started, rematchWanted, closed

local function getPlayers()
	return if deps and deps.players then deps.players() else Players:GetPlayers()
end

local function eligible(player)
	return player:GetAttribute("InLobby") == true and (expected == nil or expected[player.UserId] == true)
end

local function admitted()
	local list = {}
	for _, player in getPlayers() do
		if eligible(player) and not player:GetAttribute("IsleLate") then
			table.insert(list, player)
		end
	end
	return list
end

local function turnAway(player, why)
	player:SetAttribute("IsleLate", true)
	deps.log("IsleRefused", { player = player.Name, why = why })
	deps.sendToHarbor(player)
end

-- deps: manifest (table or nil), studioTest (bool), privateServerId, capacity, now(), sendToHarbor(player),
--       log(kind, data), players (optional list source for tests)
function IsleAdmission.init(d)
	deps = d
	expected, expectedCount, firstArrival, started, rematchWanted, closed = nil, 0, nil, false, false, false
	if d.manifest == nil and d.studioTest then
		deps.log("IsleStudioTest", {}) -- manifest-free simulation: explicit Studio test mode only
	else
		local ok, reason, set, count = IsleAdmission.validate(d.manifest, d.privateServerId, d.capacity or 4, d.now())
		if ok then
			expected, expectedCount = set, count
		else
			closed = true -- fail closed: no voyage in this server
			deps.log("IsleClosed", { why = reason })
		end
	end
	local function onJoin(player)
		if closed then
			turnAway(player, "no valid voyage manifest")
		elseif expected and not expected[player.UserId] then
			turnAway(player, "not in this crew")
		elseif started then
			turnAway(player, "voyage already sailed") -- a Play Again rematch is for the crew already here
		end
	end
	if not d.players then
		Players.PlayerAdded:Connect(onJoin)
	end
	for _, player in getPlayers() do
		onJoin(player)
	end
	IsleAdmission._onJoin = onJoin -- test hook
end

-- GameState: is there a voyage to start?
function IsleAdmission.requested()
	if closed then
		return false
	end
	if started then
		if not rematchWanted then
			return false
		end
		for _, player in getPlayers() do
			if player:GetAttribute("Ready") == true then
				return true
			end
		end
		rematchWanted = false -- everyone who wanted it left
		return false
	end
	local list = admitted()
	if #list == 0 then
		return false -- nobody here (yet): no voyage
	end
	firstArrival = firstArrival or deps.now()
	local everyone = expected ~= nil and #list >= expectedCount
	return everyone or deps.now() - firstArrival >= (Config.ISLE_ARRIVAL_WAIT or 20)
end

-- GameState: the countdown finished; these players sail (the existing loop takes them to the lighthouse).
function IsleAdmission.depart()
	if started and rematchWanted then
		rematchWanted = false
		local crew = {}
		for _, player in getPlayers() do
			if player:GetAttribute("Ready") == true then
				table.insert(crew, player)
			end
		end
		return crew
	end
	started = true -- frozen: from now on every new arrival is turned away
	local crew = admitted()
	for _, player in crew do
		player:SetAttribute("ShipId", SHIP_ID)
		player:SetAttribute("Ready", true)
	end
	-- listed players who are here but not admitted (e.g. still on the title flow) do not sail either
	for _, player in getPlayers() do
		if player:GetAttribute("Ready") ~= true and not player:GetAttribute("IsleLate") then
			turnAway(player, "missed the departure")
		end
	end
	deps.log("IsleVoyage", { crew = #crew, expected = expectedCount })
	return crew
end

-- GameState: Play Again was chosen by at least one crew member
function IsleAdmission.rematch()
	rematchWanted = true
end

function IsleAdmission.isClosed()
	return closed
end

return IsleAdmission
