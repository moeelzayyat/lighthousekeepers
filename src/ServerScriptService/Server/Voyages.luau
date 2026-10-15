-- Voyages (multi-ship phase 2): takes a departed crew from the harbor to its own Lighthouse Isle server,
-- and brings players back to the harbor.
--
-- TELEPORT_ENABLED = false (default, and the only mode usable in Studio): launch() SIMULATES the voyage. The
-- crew is moved back to the harbor spawn and leaves the party, so boarding and countdowns can be tested.
--
-- TELEPORT_ENABLED = true (owner-only, needs the Isle place and a published test environment):
--   1. ReserveServer(ISLE_PLACE_ID) -> access code + private server id
--   2. a MANIFEST in MemoryStore (map "Voyages", key = private server id, short expiry): the crew's UserIds,
--      ship and forecast votes. No balances, inventory or progress ever travel: the Isle loads saves itself.
--   3. PlayerData.handoff(player) for each member (awaited final save + session release; see SessionLock)
--   4. TeleportAsync(ISLE_PLACE_ID, crew, options) with ReservedServerAccessCode. TeleportData only carries
--      { ship } for the loading screen and is never trusted.
--   A member whose teleport fails stays in the harbor, keeps the party seat (normal boarding rules apply again)
--   and their save session is re-claimed by the harbor (PlayerData.reclaim). Nothing is deleted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Voyages = {}

local MANIFEST_MAP = "Voyages"
local MANIFEST_SECONDS = 600

local deps = nil

-- deps: notify(player, text), log(kind, data), sendToHarbor(player) (move to the harbor spawn),
--       playerData (handoff/reclaim, teleport mode only), roster (ShipRoster)
function Voyages.init(d)
	deps = d
	if Config.TELEPORT_ENABLED then
		TeleportService.TeleportInitFailed:Connect(function(player, result, message)
			Voyages.teleportFailed(player, tostring(result) .. " " .. tostring(message))
		end)
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

local function teleport(shipId, crew)
	assert(Config.ISLE_PLACE_ID ~= 0, "ISLE_PLACE_ID is not set")
	-- never move a player between servers without the guarded save hand-off
	assert(deps.playerData and deps.playerData.handoff and deps.playerData.reclaim, "save hand-off adapter not wired: refusing to teleport")
	local code, privateServerId = TeleportService:ReserveServer(Config.ISLE_PLACE_ID)
	local userIds = {}
	for _, player in crew do
		table.insert(userIds, player.UserId)
	end
	local manifest = { ship = shipId, userIds = userIds, createdAt = os.time() }
	game:GetService("MemoryStoreService"):GetSortedMap(MANIFEST_MAP):SetAsync(privateServerId, manifest, MANIFEST_SECONDS)
	-- hand every save over before anyone leaves (awaited final save + release); a member whose hand-off
	-- fails does not travel
	local travelling = {}
	for _, player in crew do
		if deps.playerData.handoff(player) then
			table.insert(travelling, player)
		else
			Voyages.teleportFailed(player, "save hand-off failed")
		end
	end
	if #travelling == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ ship = shipId })
	deps.log("VoyageLaunched", { ship = shipId, crew = #travelling, mode = "teleport", server = privateServerId })
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.ISLE_PLACE_ID, travelling, options)
	if not ok then
		for _, player in travelling do
			Voyages.teleportFailed(player, tostring(err))
		end
	end
end

-- A member who could not travel: still in the harbor, keeps the seat, keeps (re-claims) the save session.
function Voyages.teleportFailed(player, why)
	if player.Parent ~= Players then
		return
	end
	deps.log("TeleportFailed", { player = player.Name, why = why })
	if deps.playerData and deps.playerData.reclaim then
		deps.playerData.reclaim(player)
	end
	if deps.roster.shipOf(player) ~= nil then
		player:SetAttribute("BoardedByDeck", true) -- normal boarding rules apply again (stepping off frees the seat)
	end
	deps.notify(player, "The ship couldn't reach Lighthouse Isle. You're still in the harbor with your crew seat. Try SAIL NOW again.")
end

-- Called by HarborDepartures at the end of a ship's countdown.
function Voyages.launch(shipId, crew)
	if Config.TELEPORT_ENABLED then
		teleport(shipId, crew)
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
	if not deps.playerData.handoff(player) then
		deps.notify(player, "Saving your progress before the trip back failed. Try again in a moment.")
		return true
	end
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.HARBOR_PLACE_ID, { player })
	if not ok then
		Voyages.teleportFailed(player, tostring(err))
	end
	return true
end

-- Isle side: read this reserved server's manifest. Returns nil outside a reserved server or when missing.
function Voyages.readManifest()
	if not Config.TELEPORT_ENABLED or game.PrivateServerId == "" then
		return nil
	end
	local ok, manifest = pcall(function()
		return game:GetService("MemoryStoreService"):GetSortedMap(MANIFEST_MAP):GetAsync(game.PrivateServerId)
	end)
	return if ok then manifest else nil
end

return Voyages
