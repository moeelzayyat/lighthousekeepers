-- Vitals (client): the crew's critical numbers, read live from GameState and the local Humanoid,
-- with the SAME thresholds as the production HUD (UiKit Fuel/Health/Tower gauges, Hud blackout alarm).
-- Menus that can cover the HUD on small screens (Upgrade Bench, Trader) use it to surface what
-- matters as compact chips. It keeps no copy of any value: every call reads the live source.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local state = ReplicatedStorage:WaitForChild("GameState")

local LIT_PHASES = { Prologue = true, Day = true, Night = true } -- same as Hud

local Vitals = {}

local function pct(v)
	return math.floor(v * 100 + 0.5)
end

function Vitals.read()
	local maxFuel = state:GetAttribute("MaxFuel") or Config.MAX_FUEL
	local fuel = math.clamp((state:GetAttribute("Fuel") or 0) / math.max(1, maxFuel), 0, 1)
	local fuelStage = if fuel <= 0 then "blackout" elseif fuel < 0.15 then "critical" elseif fuel < 0.3 then "low" else "steady" -- UiKit.FuelGauge
	local dark = (state:GetAttribute("DarkSeconds") or 0) > 0 and LIT_PHASES[state:GetAttribute("Phase")] == true -- Hud alarm
	local maxTower = state:GetAttribute("MaxIntegrity") or Config.MAX_INTEGRITY
	local tower = math.clamp((state:GetAttribute("Integrity") or 0) / math.max(1, maxTower), 0, 1)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = if humanoid then math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1) else 1
	return {
		fuel = fuel,
		fuelStage = fuelStage,
		dark = dark,
		tower = tower,
		towerCritical = tower < 0.3, -- UiKit.TowerGauge "BREACHING"
		health = health,
		healthCritical = health > 0 and health <= 0.25, -- UiKit.HealthGauge "CRITICAL"
	}
end

-- The lamp in one chip: { text, level } where level is "ok" | "warning" | "danger"
function Vitals.fuelChip(v)
	v = v or Vitals.read()
	if v.dark or v.fuelStage == "blackout" then
		return { text = "Lamp dark", level = "danger" }
	elseif v.fuelStage == "critical" then
		return { text = string.format("Fuel %d%% \u{00B7} critical", pct(v.fuel)), level = "danger" }
	elseif v.fuelStage == "low" then
		return { text = string.format("Fuel %d%% \u{00B7} low", pct(v.fuel)), level = "warning" }
	end
	return { text = string.format("Fuel %d%%", pct(v.fuel)), level = "ok" }
end

-- Only what is critical right now (empty when all is well). opts.skipFuel / skipHealth / skipTower
function Vitals.criticalChips(opts)
	opts = opts or {}
	local v = Vitals.read()
	local chips = {}
	if not opts.skipFuel then
		local f = Vitals.fuelChip(v)
		if f.level ~= "ok" then
			table.insert(chips, f)
		end
	end
	if not opts.skipHealth and v.healthCritical then
		table.insert(chips, { text = string.format("Health %d%% \u{00B7} critical", pct(v.health)), level = "danger" })
	end
	if not opts.skipTower and v.towerCritical and LIT_PHASES[state:GetAttribute("Phase")] then
		table.insert(chips, { text = string.format("Tower %d%% \u{00B7} breaching", pct(v.tower)), level = "danger" })
	end
	return chips
end

-- Draws chips into a row of pre-made UiKit tags (a fixed pool, restyled in place: no churn)
function Vitals.paint(UiKit, tags, chips)
	local C = UiKit.Color
	for i, tag in tags do
		local chip = chips[i]
		tag.Visible = chip ~= nil
		if chip then
			local color = if chip.level == "danger" then C.StateDanger elseif chip.level == "warning" then C.StateWarning else C.AccentSea
			local filled = chip.level == "danger"
			tag.Text = string.upper(chip.text)
			tag.BackgroundColor3 = color
			tag.BackgroundTransparency = if filled then 0 else 0.84
			tag.TextColor3 = if filled then C.TextOnAccent else color
			local stroke = tag:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = color
				stroke.Enabled = not filled
			end
		end
	end
end

return Vitals
