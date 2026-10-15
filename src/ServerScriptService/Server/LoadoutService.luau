-- LoadoutService: equip / unequip requests from the Inventory screen. Works anywhere.
--
--   Primary slot: the weapon you carry (only one at a time). Unequipping returns to the starter harpoon.
--   Armor slot:   the armor you wear. Unequipping returns to the starter Oilskin Coat.
--
-- The server checks the player owns the item and that it fits the slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local EventLog = require(script.Parent.EventLog)

local LoadoutService = {}

local STARTERS = { Primary = "DriftwoodHarpoon", Armor = "OilskinCoat", Beam = "BeamAmber" }

local remotes
local playerData
local lastRequest = {}
local handled = {} -- player -> { [requestId] = { ok, message } }

local function process(player, action, itemId)
	local item = type(itemId) == "string" and Items[itemId]
	if type(item) ~= "table" or not item.slot then
		return false, "That can't be equipped."
	end
	local profile = playerData.get(player)
	if not profile then
		return false, "Your data is still loading."
	end
	if not playerData.owns(player, itemId) then
		return false, "You don't own " .. item.name .. "."
	end
	local current = if item.slot == "Primary" then profile.equippedWeapon elseif item.slot == "Beam" then profile.equippedBeam else profile.equippedArmor

	if action == "equip" then
		if current == itemId then
			return true, item.name .. " is already equipped."
		end
		playerData.setEquipped(player, item.slot, itemId)
		EventLog.log("Equip", { player = player.Name, slot = item.slot, item = itemId })
		return true, item.name .. " equipped."
	elseif action == "unequip" then
		local starter = STARTERS[item.slot]
		if current ~= itemId then
			return false, item.name .. " isn't equipped."
		end
		if itemId == starter then
			return false, "You always keep a starter item in this slot."
		end
		playerData.setEquipped(player, item.slot, starter)
		EventLog.log("Unequip", { player = player.Name, slot = item.slot, item = itemId })
		return true, item.name .. " unequipped."
	end
	return false, "Unknown action."
end

function LoadoutService.init(remoteFolder, playerDataService)
	remotes = remoteFolder
	playerData = playerDataService

	remotes.LoadoutRequest.OnServerEvent:Connect(function(player, requestId, action, itemId)
		if type(requestId) ~= "string" or #requestId == 0 or #requestId > 40 then
			return
		end
		local memory = handled[player]
		if memory and memory[requestId] then
			remotes.LoadoutResult:FireClient(player, requestId, memory[requestId][1], memory[requestId][2])
			return
		end
		local now = os.clock()
		if (lastRequest[player] or 0) + 0.2 > now then
			remotes.LoadoutResult:FireClient(player, requestId, false, "Slow down a little.")
			return
		end
		lastRequest[player] = now

		local ok, message = process(player, action, itemId)
		if not memory then
			memory = {}
			handled[player] = memory
		end
		memory[requestId] = { ok, message }
		if not ok then
			playerData.resync(player)
		end
		remotes.LoadoutResult:FireClient(player, requestId, ok, message)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		handled[player] = nil
	end)
end

return LoadoutService
