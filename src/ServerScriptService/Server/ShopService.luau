-- ShopService: the Quartermaster's shop. The ONLY way to buy gear/ammo or sell loot.
--
-- Security rules:
--   * The shop opens only when the player uses the Quartermaster's prompt (server-side).
--   * Every request checks the player is still near the Quartermaster.
--   * Prices, balances, ownership, stack limits, and quantities come from the server's
--     catalog and saved data; nothing the client sends is trusted except the item id.
--   * Each request has an id; repeats of the same id return the first result and never
--     charge twice (double taps, network retries).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EventLog = require(script.Parent.EventLog)

local ShopService = {}

local SHOP_RANGE = 16 -- studs from the Quartermaster; walking farther closes the shop
local GREETINGS = {
	"Need equipment for the next storm?",
	"Sharp harpoons, dry coats, hot shells. What'll it be?",
	"Back from the rocks in one piece? Let's keep it that way.",
}
local MAX_REMEMBERED_REQUESTS = 40

local remotes
local playerData
local npcPart -- the Quartermaster's interaction part
local openFor = {} -- player -> true while their shop is open
local lastRequest = {} -- player -> os.clock() of their last request
local handled = {} -- player -> { [requestId] = { ok, message }, order = {...} }

local function distanceTo(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not npcPart then
		return math.huge
	end
	return (root.Position - npcPart.Position).Magnitude
end

local function close(player, reason)
	if openFor[player] then
		openFor[player] = nil
		player:SetAttribute("ShopOpen", false)
		remotes.ShopOpen:FireClient(player, false, reason)
	end
end

local function open(player)
	if distanceTo(player) > SHOP_RANGE then
		return
	end
	openFor[player] = true
	player:SetAttribute("ShopOpen", true)
	playerData.resync(player)
	remotes.ShopOpen:FireClient(player, true, GREETINGS[math.random(1, #GREETINGS)])
	EventLog.log("ShopOpened", { player = player.Name })
end

-- How many of a stackable item the player can still hold
local function capacityLeft(player, itemId)
	local item = Items[itemId]
	return math.max(0, (item.maxStack or 1) - playerData.count(player, itemId))
end

local function buy(player, itemId, quantity)
	local item = Items[itemId]
	if not item.price or item.kind == "Material" then
		return false, "The Quartermaster doesn't sell that."
	end
	local profile = playerData.get(player)

	if item.kind == "Cosmetic" and not Config.COSMETICS_ENABLED then
		return false, "The Quartermaster doesn't sell that."
	end
	if item.kind == "Weapon" or item.kind == "Armor" or item.kind == "Cosmetic" then
		if playerData.owns(player, itemId) then
			return false, "You already own " .. item.name .. "."
		end
		quantity = 1
	else
		-- Stackable (ammo). quantity -1 means "as many as I can hold and afford".
		local room = capacityLeft(player, itemId)
		if room <= 0 then
			return false, string.format("Your %s stack is full (%d/%d).", item.name, item.maxStack, item.maxStack)
		end
		if quantity == -1 then
			quantity = math.min(room, math.floor(profile.pearls / item.price))
			if quantity <= 0 then
				return false, string.format("Need %d Pearls for one %s.", item.price, item.name)
			end
		elseif quantity > room then
			return false, string.format("You only have room for %d more.", room)
		end
	end

	local cost = item.price * quantity
	if not playerData.spendPearls(player, cost) then
		return false, string.format("Need %d Pearls (you have %d).", cost, profile.pearls)
	end
	playerData.addItem(player, itemId, quantity)
	EventLog.log("ShopBuy", { player = player.Name, item = itemId, quantity = quantity, cost = cost })
	if quantity > 1 then
		return true, string.format("Bought %d %s for %d Pearls.", quantity, item.name, cost)
	end
	return true, string.format("Bought %s for %d Pearls.", item.name, cost)
end

local function sell(player, itemId, quantity)
	local item = Items[itemId]
	if item.kind ~= "Material" or not item.sell then
		return false, "The Quartermaster won't buy that."
	end
	local have = playerData.count(player, itemId)
	if have <= 0 then
		return false, "You don't have any " .. item.name .. "."
	end
	if quantity == -1 then
		quantity = have
	elseif quantity > have then
		return false, string.format("You only have %d.", have)
	end
	playerData.removeItem(player, itemId, quantity)
	playerData.addPearls(player, item.sell * quantity, "sell")
	EventLog.log("ShopSell", { player = player.Name, item = itemId, quantity = quantity })
	return true, string.format("Sold %d %s for %d Pearls.", quantity, item.name, item.sell * quantity)
end

local function process(player, action, itemId, quantity)
	if not openFor[player] then
		return false, "Talk to the Quartermaster to trade."
	end
	if distanceTo(player) > SHOP_RANGE + 2 then
		close(player, "You walked away from the Quartermaster.")
		return false, "You're too far from the Quartermaster."
	end
	if type(itemId) ~= "string" or type(Items[itemId]) ~= "table" or not Items[itemId].kind then
		return false, "Unknown item."
	end
	if type(quantity) ~= "number" or quantity ~= quantity then
		return false, "Invalid amount."
	end
	quantity = math.floor(quantity)
	if quantity ~= -1 and (quantity < 1 or quantity > 999) then
		return false, "Invalid amount."
	end
	if not playerData.get(player) then
		return false, "Your data is still loading. Try again in a moment."
	end
	if action == "buy" then
		return buy(player, itemId, quantity)
	elseif action == "sell" then
		return false, "I don't buy loot. Sell it to the Trader on the lighthouse island during a voyage."
	end
	return false, "Unknown action."
end

local function remember(player, requestId, ok, message)
	local memory = handled[player]
	if not memory then
		memory = { order = {} }
		handled[player] = memory
	end
	memory[requestId] = { ok, message }
	table.insert(memory.order, requestId)
	if #memory.order > MAX_REMEMBERED_REQUESTS then
		memory[table.remove(memory.order, 1)] = nil
	end
end

function ShopService.init(remoteFolder, playerDataService, quartermasterPart, prompt)
	remotes = remoteFolder
	playerData = playerDataService
	npcPart = quartermasterPart

	prompt.Triggered:Connect(open)

	remotes.ShopRequest.OnServerEvent:Connect(function(player, requestId, action, itemId, quantity)
		if action == "close" then
			close(player, nil)
			return
		end
		if type(requestId) ~= "string" or #requestId == 0 or #requestId > 40 then
			return
		end
		-- Duplicate request: answer with the original result, change nothing
		local memory = handled[player]
		if memory and memory[requestId] then
			remotes.ShopResult:FireClient(player, requestId, memory[requestId][1], memory[requestId][2])
			return
		end
		local now = os.clock()
		if (lastRequest[player] or 0) + 0.2 > now then
			remotes.ShopResult:FireClient(player, requestId, false, "Slow down a little.")
			return
		end
		lastRequest[player] = now

		local ok, message = process(player, action, itemId, quantity)
		remember(player, requestId, ok, message)
		if not ok then
			playerData.resync(player)
		end
		remotes.ShopResult:FireClient(player, requestId, ok, message)
	end)

	-- Close the shop for anyone who walks away
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in openFor do
				if player.Parent ~= Players or distanceTo(player) > SHOP_RANGE then
					close(player, "You walked away from the Quartermaster.")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		openFor[player] = nil
		lastRequest[player] = nil
		handled[player] = nil
	end)
end

return ShopService
