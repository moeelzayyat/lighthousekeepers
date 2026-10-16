-- Voyages (multi-ship phase 2): takes a departed crew from the harbor to its own Lighthouse Isle server,
-- and brings players back to the harbor.
--
-- TELEPORT_ENABLED = false (default, and the only mode usable in Studio): launch() SIMULATES the voyage. The
-- crew is moved back to the harbor spawn and leaves the party, so boarding and countdowns can be tested.
--
-- TELEPORT_ENABLED = true (owner-only, needs the Isle place and a published test environment):
--   1. every crew member leaves the ship's party and is marked InTransit (cannot board again, cannot be counted
--      twice, the ship can take a new crew at once) - no duplicate launch of the same players is possible
--   2. PlayerData.handoff(player) for each member: awaited final save + session release. While released the
--      profile must not change (handoff freezes it; see the fix package). A member whose hand-off fails stays.
--   3. ReserveServer(ISLE_PLACE_ID) -> access code + private server id
--   4. a MANIFEST in MemoryStore (map "Voyages", key = private server id, short expiry) listing ONLY the members
--      whose hand-off succeeded: their UserIds, the ship, this private server id and the time. No balances,
--      inventory or progress ever travel: the Isle loads saves itself.
--   5. TeleportAsync(ISLE_PLACE_ID, travelling, options) with ReservedServerAccessCode. TeleportData only carries
--      { ship } for the loading screen and is never trusted.
--   Failure at any step (fix 3, 2026-10-16): the member stays in the harbor, is NOT put back into a party (the ship
--   may already have a new crew; they can board again), and must RE-CLAIM their save session before playing on.
--   If the re-claim fails they are disconnected with a message, so they rejoin and load their saved progress fresh.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Voyages = {}

local MANIFEST_MAP = "Voyages"
local MANIFEST_SECONDS = 600

local deps = nil

-- the real Roblox services; tests pass fakes through deps.services
local function realServices()
	local TeleportService = game:GetService("TeleportService")
	local map = function()
		return game:GetService("MemoryStoreService"):GetSortedMap(MANIFEST_MAP)
	end
	return {
		reserve = function(placeId)
			return TeleportService:ReserveServer(placeId)
		end,
		teleport = function(placeId, players, options)
			return TeleportService:TeleportAsync(placeId, players, options)
		end,
		newOptions = function(code, ship)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			options:SetTeleportData({ ship = ship })
			return options
		end,
		manifestSet = function(id, manifest)
			map():SetAsync(id, manifest, MANIFEST_SECONDS)
		end,
		manifestGet = function(id)
			return map():GetAsync(id)
		end,
		initFailed = TeleportService.TeleportInitFailed,
	}
end

-- deps: notify(player, text), log(kind, data), sendToHarbor(player) (move to the harbor spawn),
--       playerData (handoff/reclaim, teleport mode only), roster (ShipRoster), services (tests only), now (os.time)
function Voyages.init(d)
	deps = d
	deps.now = deps.now or os.time
	if Config.TELEPORT_ENABLED or deps.services then
		deps.services = deps.services or realServices()
		if deps.services.initFailed then
			deps.services.initFailed:Connect(function(player, result, message)
				Voyages.teleportFailed(player, tostring(result) .. " " .. tostring(message))
			end)
		end
	end
end

local function simulate(shipId, crew)
	deps.log("VoyageLaunched", { ship = shipId, crew = #crew, mode = "simulated" })
	for _, player in crew do
		deps.notify(player, "(Studio test) Your ship sailed to Lighthouse Isle. Teleporting is off, so you are back in the harbor.")
		deps.roster.leave(player, "sailed (simulated)")
		deps.sendToHarbor(player)
	end
end

-- the real flow (also driven directly by the tests with fake services)
function Voyages._teleport(shipId, crew)
	assert(Config.ISLE_PLACE_ID ~= 0 or deps.services.testPlaceId, "ISLE_PLACE_ID is not set")
	-- never move a player between servers without the guarded save hand-off
	assert(deps.playerData and deps.playerData.handoff and deps.playerData.reclaim, "save hand-off adapter not wired: refusing to teleport")
	local placeId = deps.services.testPlaceId or Config.ISLE_PLACE_ID

	-- 1. out of the party at once: no second launch of these players, the ship is free for a new crew
	for _, player in crew do
		player:SetAttribute("InTransit", true)
		deps.roster.leave(player, "travelling")
	end
	-- 2. awaited hand-off of every save; only successful members travel
	local travelling = {}
	for _, player in crew do
		if player.Parent == Players and deps.playerData.handoff(player) then
			table.insert(travelling, player)
		else
			Voyages.teleportFailed(player, "save hand-off failed")
		end
	end
	if #travelling == 0 then
		deps.log("VoyageCancelled", { ship = shipId, why = "no traveller handed off" })
		return
	end
	-- 3-5. reserve, manifest of exactly the travellers, teleport
	local ok, err = pcall(function()
		local code, privateServerId = deps.services.reserve(placeId)
		local userIds = {}
		for _, player in travelling do
			table.insert(userIds, player.UserId)
		end
		deps.services.manifestSet(privateServerId, { ship = shipId, userIds = userIds, privateServerId = privateServerId, createdAt = deps.now() })
		deps.log("VoyageLaunched", { ship = shipId, crew = #travelling, mode = "teleport", server = privateServerId })
		deps.services.teleport(placeId, travelling, deps.services.newOptions(code, shipId))
	end)
	if not ok then
		for _, player in travelling do
			Voyages.teleportFailed(player, tostring(err))
		end
	end
end

-- A member who could not travel: stays in the harbor, out of any party, and must re-claim the save session.
function Voyages.teleportFailed(player, why)
	if player.Parent ~= Players or not player:GetAttribute("InTransit") then
		return -- gone, or already handled (a pcall error and TeleportInitFailed can both report one failure)
	end
	deps.log("TeleportFailed", { player = player.Name, why = why })
	if deps.roster.shipOf(player) ~= nil then
		deps.roster.leave(player, "teleport failed")
	end
	local reclaimed = true
	if deps.playerData and deps.playerData.reclaim then
		reclaimed = deps.playerData.reclaim(player) == true
	end
	if not reclaimed then
		deps.log("ReclaimFailed", { player = player.Name })
		player:Kick("Lighthouse Keepers: the voyage could not start and your save could not be reopened here. Your progress is saved: please rejoin.")
		return
	end
	player:SetAttribute("InTransit", nil)
	deps.notify(player, "The ship couldn't reach Lighthouse Isle. You're still in the harbor: walk aboard a ship to try again.")
end

-- Called by HarborDepartures at the end of a ship's countdown.
function Voyages.launch(shipId, crew)
	if Config.TELEPORT_ENABLED then
		Voyages._teleport(shipId, crew)
	else
		simulate(shipId, crew)
	end
end

-- Isle side: send one player back to a public harbor server (Results "back to harbor", menu, rematch "no").
-- Returns false when teleporting is off (the caller keeps today's behaviour).
function Voyages.returnToHarbor(player)
	if not Config.TELEPORT_ENABLED then
		return false
	end
	if not (deps.playerData and deps.playerData.handoff) then
		warn("[Voyages] save hand-off adapter not wired: not teleporting " .. player.Name)
		return false
	end
	player:SetAttribute("InTransit", true)
	if not deps.playerData.handoff(player) then
		Voyages.teleportFailed(player, "save hand-off failed")
		return true
	end
	local ok, err = pcall(deps.services.teleport, Config.HARBOR_PLACE_ID, { player }, nil)
	if not ok then
		Voyages.teleportFailed(player, tostring(err))
	end
	return true
end

-- Isle side: read this reserved server's manifest (nil outside a reserved server, when missing or on error).
-- IsleAdmission validates it and fails closed.
function Voyages.readManifest()
	if not Config.TELEPORT_ENABLED or game.PrivateServerId == "" then
		return nil
	end
	local ok, manifest = pcall(deps.services.manifestGet, game.PrivateServerId)
	return if ok then manifest else nil
end

return Voyages
