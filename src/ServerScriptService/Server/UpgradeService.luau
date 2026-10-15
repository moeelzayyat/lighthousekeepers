-- UpgradeService: the crew's shared Shell pool and the lighthouse upgrades bought with it.
-- Everything resets at the start of a run.
--
-- Published attributes on ReplicatedStorage.GameState:
--   Shells               the crew's shell count
--   Upgrade_<Id>         current level of each upgrade (0-3)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Upgrades = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Upgrades"))
local EventLog = require(script.Parent.EventLog)

local UpgradeService = {}

local state
local lamp
local tower
local shells = 0
local levels = {}

local evolved = {} -- evolution id -> true this voyage

local function push()
	state:SetAttribute("Shells", shells)
	for _, id in Upgrades.ORDER do
		state:SetAttribute("Upgrade_" .. id, levels[id] or 0)
	end
	for _, evo in Upgrades.EVOLUTIONS or {} do
		state:SetAttribute("Evo_" .. evo.id, evolved[evo.id] == true)
	end
end

-- Unlocks any evolution whose two upgrades are both maxed (launch R13)
local function checkEvolutions()
	if not Config.EVOLUTIONS_ENABLED then
		return nil
	end
	for _, evo in Upgrades.EVOLUTIONS or {} do
		if not evolved[evo.id] then
			local ready = true
			for _, need in evo.needs do
				if (levels[need] or 0) < #Upgrades[need].costs then
					ready = false
				end
			end
			if ready then
				evolved[evo.id] = true
				EventLog.log("Evolution", { id = evo.id })
				EventLog.moment(4, "The crew forged the " .. evo.displayName)
				return evo
			end
		end
	end
	return nil
end

function UpgradeService.isEvolved(id)
	return evolved[id] == true
end

function UpgradeService.getLevel(id)
	return levels[id] or 0
end

-- The upgrade's current effect, or `base` if it hasn't been bought
function UpgradeService.value(id, base)
	local level = levels[id] or 0
	if level == 0 then
		return base
	end
	return Upgrades[id].values[level]
end

-- Spends crew shells if there are enough. Returns true if spent.
function UpgradeService.trySpend(amount)
	if shells < amount then
		return false
	end
	shells -= amount
	EventLog.count("shellsSpent", amount)
	push()
	return true
end

function UpgradeService.getShells()
	return shells
end

function UpgradeService.addShells(amount)
	shells += amount
	push()
end

-- Applies upgrades that change other systems the moment they're bought
local function applyEffects(id)
	if id == "FuelTank" then
		lamp.setMaxFuel(UpgradeService.value("FuelTank", Config.MAX_FUEL))
		lamp.addFuel(30)
	elseif id == "Walls" then
		tower.setMax(UpgradeService.value("Walls", Config.MAX_INTEGRITY))
		tower.repair(50)
	end
	-- LensPower and ClockworkSweep are read live by CreatureService
end

-- Returns true and a message if bought, false and a reason if not
function UpgradeService.buy(id)
	local upgrade = Upgrades[id]
	if not upgrade then
		return false, "Unknown upgrade."
	end
	local level = levels[id] or 0
	if level >= #upgrade.costs then
		return false, upgrade.displayName .. " is already maxed."
	end
	local cost = upgrade.costs[level + 1]
	if shells < cost then
		return false, string.format("Need %d shells (the crew has %d).", cost, shells)
	end
	shells -= cost
	EventLog.count("shellsSpent", cost)
	levels[id] = level + 1
	applyEffects(id)
	local evo = checkEvolutions()
	push()
	if evo then
		return true, string.format("%s maxed! Evolution unlocked: %s. %s.", upgrade.displayName, evo.displayName, evo.description)
	end
	return true, string.format("%s upgraded to level %d!", upgrade.displayName, level + 1)
end

function UpgradeService.reset()
	shells = if Config.ECONOMY_ENABLED then (Config.START_SHELLS or 0) + (Config.DEV_START_SHELLS or 0) else 0
	levels = {}
	evolved = {}
	lamp.setMaxFuel(Config.MAX_FUEL)
	tower.setMax(Config.MAX_INTEGRITY)
	push()
end

function UpgradeService.init(stateFolder, lampService, towerService)
	state = stateFolder
	lamp = lampService
	tower = towerService
	push()
end

return UpgradeService
