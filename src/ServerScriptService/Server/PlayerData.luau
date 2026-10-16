-- PlayerData: each player's saved profile (Pearls, owned gear, ammo crates, materials, equipped armor).
--
-- Saved with Roblox DataStores: loaded when a player joins, saved every 60 seconds, when they
-- leave, and when the server shuts down. If DataStores are unavailable (for example, Studio
-- without API access), profiles live in memory only and a warning is printed.
--
-- All changes go through this module on the server. Clients only ever *request* actions.
--
-- MULTI-SHIP TEST EXPERIENCE ONLY (branch multiship-test): when Config.IS_MULTISHIP_TEST, the store is
-- "LKMS_TEST_PlayerData_v1" (never the production store), and when Config.SESSION_LOCK_ENABLED as well, every
-- read/write goes through SessionLock (claim on join, owned saves + heartbeat, release on leave/close) and the
-- profile can be handed off to another server (freeze + awaited release) and re-claimed. The profile format is
-- unchanged. In production neither condition can be true, so this module behaves exactly as before.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local EventLog = require(script.Parent.EventLog)

local PlayerData = {}

local STORE_NAME = if Config.IS_MULTISHIP_TEST then "LKMS_TEST_PlayerData_v1" else "LighthouseKeepers_PlayerData_v1"
local LOCKED = Config.IS_MULTISHIP_TEST and Config.SESSION_LOCK_ENABLED == true
local lock = nil -- SessionLock instance (test experience with sessionLock only)
local frozen = {} -- player -> profile parked during a hand-off (all mutators see no profile, so they refuse)
local SCHEMA_VERSION = 1
local AUTOSAVE_SECONDS = 60

local store = nil
local storeAvailable = false
local profiles = {} -- player -> profile table
local dirty = {} -- player -> true when unsaved changes exist
local remotes

-- Called whenever a profile changes (Main uses this to refresh tools and armor)
PlayerData.onChanged = nil

local function newProfile()
	local profile = {
		version = SCHEMA_VERSION,
		pearls = Config.DEV_START_PEARLS or 0,
		owned = {}, -- itemId -> true (weapons and armor)
		counts = {}, -- itemId -> number (ammo crates and materials)
		equippedArmor = "OilskinCoat",
		equippedWeapon = "DriftwoodHarpoon",
		equippedBeam = "BeamAmber", -- beam colour (launch R15, owner-approved). Old saves get this default.
		stats = { runs = 0, victories = 0, bestNight = 0 },
	}
	for id, item in Items do
		if type(item) == "table" and item.starter then
			profile.owned[id] = true
		end
	end
	return profile
end

-- Fills in anything missing from older saves
local function reconcile(profile)
	local template = newProfile()
	for key, value in template do
		if profile[key] == nil then
			profile[key] = value
		end
	end
	for id, item in Items do
		if type(item) == "table" and item.starter then
			profile.owned[id] = true
		end
	end
	if not profile.owned[profile.equippedArmor] then
		profile.equippedArmor = "OilskinCoat"
	end
	if not profile.owned[profile.equippedWeapon] then
		profile.equippedWeapon = "DriftwoodHarpoon"
	end
	if not profile.owned[profile.equippedBeam] then
		profile.equippedBeam = "BeamAmber"
	end
	return profile
end

local function keyFor(player)
	return "player_" .. player.UserId
end

-- A plain-table copy the client can display
local function snapshot(profile)
	return HttpService:JSONDecode(HttpService:JSONEncode(profile))
end

local function push(player)
	local profile = profiles[player]
	if profile and remotes then
		remotes.GearData:FireClient(player, snapshot(profile), storeAvailable)
	end
	if PlayerData.onChanged then
		PlayerData.onChanged(player)
	end
end

local function markChanged(player)
	dirty[player] = true
	push(player)
end

local function save(player)
	local profile = profiles[player]
	if not profile or not storeAvailable or not dirty[player] then
		return
	end
	if LOCKED then
		local ok, why = lock:save(keyFor(player), profile)
		if ok then
			dirty[player] = nil
		else
			warn("PlayerData: locked save failed for " .. player.Name .. ": " .. tostring(why))
			if why == "lock lost" then
				profile.doNotSave = true -- another server owns this save now: never write again from here
			end
		end
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return profile
		end)
	end)
	if ok then
		dirty[player] = nil
	else
		warn("PlayerData: save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function load(player)
	local profile
	if storeAvailable and LOCKED then
		local ok, value, why = lock:claim(keyFor(player), newProfile())
		if ok then
			profile = reconcile(value)
		else
			warn("PlayerData: could not claim " .. player.Name .. " (" .. tostring(why) .. "); progress this session will NOT be saved.")
			profile = newProfile()
			profile.doNotSave = true
		end
	elseif storeAvailable then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				profile = if result then reconcile(result) else newProfile()
				break
			end
			warn(string.format("PlayerData: load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
			task.wait(attempt)
		end
		if not profile then
			-- Never overwrite a real save with a blank one: play in memory this session
			warn("PlayerData: could not load " .. player.Name .. "; progress this session will NOT be saved.")
			profile = newProfile()
			profile.doNotSave = true
		end
	else
		profile = newProfile()
	end
	if player.Parent ~= Players then
		return -- left while loading
	end
	profiles[player] = profile
	-- Read-only signals for the first-voyage route and coach (launch R2/R3). Nothing new is saved.
	-- "failed" = the save couldn't be read: never treat that player as new, never save over them.
	player:SetAttribute("RunsCompleted", if profile.doNotSave then -1 else profile.stats.runs)
	player:SetAttribute("ProfileState", if profile.doNotSave then "failed" elseif storeAvailable then "saved" else "memory")
	push(player)
end

---------------------------------------------------------------------
-- Public API (server only)
---------------------------------------------------------------------

function PlayerData.get(player)
	return profiles[player]
end

function PlayerData.owns(player, itemId)
	local profile = profiles[player]
	return profile ~= nil and profile.owned[itemId] == true
end

function PlayerData.count(player, itemId)
	local profile = profiles[player]
	return if profile then (profile.counts[itemId] or 0) else 0
end

function PlayerData.addPearls(player, amount, reason)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	profile.pearls += amount
	EventLog.log("Pearls", { player = player.Name, amount = amount, reason = reason or "?", total = profile.pearls })
	markChanged(player)
end

function PlayerData.addItem(player, itemId, amount)
	local profile = profiles[player]
	local item = Items[itemId]
	if not profile or not item then
		return
	end
	if item.kind == "Weapon" or item.kind == "Armor" or item.kind == "Cosmetic" then
		profile.owned[itemId] = true
	else
		profile.counts[itemId] = (profile.counts[itemId] or 0) + (amount or 1)
	end
	markChanged(player)
end

-- Removes `amount` of a counted item. Returns true if the player had enough.
function PlayerData.removeItem(player, itemId, amount)
	local profile = profiles[player]
	amount = amount or 1
	if not profile or (profile.counts[itemId] or 0) < amount then
		return false
	end
	profile.counts[itemId] -= amount
	if profile.counts[itemId] <= 0 then
		profile.counts[itemId] = nil
	end
	markChanged(player)
	return true
end

function PlayerData.recordRun(player, won, nightReached)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.stats.runs += 1
	if won then
		profile.stats.victories += 1
	end
	profile.stats.bestNight = math.max(profile.stats.bestNight, nightReached)
	if not profile.doNotSave then
		player:SetAttribute("RunsCompleted", profile.stats.runs)
	end
	markChanged(player)
end

---------------------------------------------------------------------
-- Mutations used by ShopService and LoadoutService (they do the validation)
---------------------------------------------------------------------

-- Spends Pearls if the player has enough. Returns true if spent.
function PlayerData.spendPearls(player, amount)
	local profile = profiles[player]
	if not profile or amount < 0 or profile.pearls < amount then
		return false
	end
	profile.pearls -= amount
	markChanged(player)
	return true
end

-- slot is "Primary" or "Armor"
function PlayerData.setEquipped(player, slot, itemId)
	local profile = profiles[player]
	if not profile then
		return
	end
	if slot == "Primary" then
		profile.equippedWeapon = itemId
	elseif slot == "Armor" then
		profile.equippedArmor = itemId
	elseif slot == "Beam" then
		profile.equippedBeam = itemId
	end
	markChanged(player)
end

-- Re-sends the profile to the client (after a rejected request, so its display is correct)
function PlayerData.resync(player)
	push(player)
end

-- Loot (claws, sea glass, black pearls) only lasts one voyage, like shells.
-- Returns a list of { itemId, count } that was removed (empty if none).
function PlayerData.clearRunLoot(player)
	local profile = profiles[player]
	local removed = {}
	if not profile then
		return removed
	end
	for itemId, count in profile.counts do
		local item = Items[itemId]
		if type(item) == "table" and item.runScoped and count > 0 then
			table.insert(removed, { itemId, count })
			profile.counts[itemId] = nil
		end
	end
	if #removed > 0 then
		markChanged(player)
	end
	return removed
end


---------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------

-- Multi-ship hand-off (test experience with sessionLock only). Freeze, then an awaited final save + release.
-- Returns true only when the release is confirmed; on false the profile stays frozen until reclaim().
function PlayerData.handoff(player)
	if not LOCKED or not storeAvailable then
		return false
	end
	local profile = profiles[player] or frozen[player]
	if not profile or profile.doNotSave then
		return false
	end
	frozen[player] = profile
	profiles[player] = nil -- frozen: every mutator now sees no profile and refuses
	local ok = lock:release(keyFor(player), profile)
	if ok then
		dirty[player] = nil
	end
	return ok == true
end

-- Re-claim after a failed voyage: the stored profile becomes the live one again (unfrozen).
function PlayerData.reclaim(player)
	if not LOCKED or not storeAvailable then
		return false
	end
	local ok, value = lock:claim(keyFor(player), newProfile())
	if not ok or player.Parent ~= Players then
		return false
	end
	frozen[player] = nil
	profiles[player] = reconcile(value)
	push(player)
	return true
end

function PlayerData.init(remoteFolder, notify)
	remotes = remoteFolder

	local ok, result = pcall(function()
		local s = DataStoreService:GetDataStore(STORE_NAME)
		s:GetAsync("__access_check")
		return s
	end)
	if ok then
		store = result
		storeAvailable = true
		if LOCKED then
			lock = require(script.Parent.SessionLock).new({ store = store })
		end
	else
		warn("PlayerData: DataStores unavailable (" .. tostring(result) .. "). Progress is kept in memory only. In Studio, enable Game Settings > Security > Enable Studio Access to API Services.")
		-- the HUD shows a "progress isn't saving" warning to players
		local Players = game:GetService("Players")
		for _, p in Players:GetPlayers() do
			p:SetAttribute("SaveUnavailable", true)
		end
		Players.PlayerAdded:Connect(function(p)
			p:SetAttribute("SaveUnavailable", true)
		end)
	end

	remotes.GearAction.OnServerEvent:Connect(function(player, action)
		-- The only client request handled here: "send me my data".
		-- Buying/selling go through ShopService (Quartermaster); equipping through LoadoutService.
		if action == "sync" then
			push(player)
		end
	end)
	local lastAction = {} -- (kept for cleanup on leave)

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if LOCKED and storeAvailable then
			-- frozen (handed off) players already released their save; everyone else releases it now
			if profile and not profile.doNotSave then
				lock:release(keyFor(player), profile)
			elseif frozen[player] and lock:owns(keyFor(player)) then
				lock:release(keyFor(player), frozen[player]) -- a hand-off whose release failed: release it now
			end
			frozen[player] = nil
		elseif profile and not profile.doNotSave then
			save(player)
		end
		profiles[player] = nil
		dirty[player] = nil
		lastAction[player] = nil
	end)
	game:BindToClose(function()
		for player, profile in profiles do
			if not profile.doNotSave then
				if LOCKED and storeAvailable then
					lock:release(keyFor(player), profile)
				else
					save(player)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, profile in profiles do
				if not profile.doNotSave then
					if LOCKED and storeAvailable and not dirty[player] then
						task.spawn(function()
							lock:heartbeat(keyFor(player)) -- keeps the session alive while unchanged
						end)
					else
						task.spawn(save, player)
					end
				end
			end
		end
	end)
end

return PlayerData
