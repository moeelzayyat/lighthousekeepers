-- GameState: runs the round loop.
-- Waiting -> Intermission -> Prologue (opening incident) -> (Day -> Night) x NIGHTS_TO_WIN -> Victory / Defeat
-- The current phase is published as attributes on ReplicatedStorage.GameState
-- so every client's HUD can read it.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Creatures = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Creatures"))
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local EventLog = require(script.Parent.EventLog)
local Forecasts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Forecasts"))

local GameState = {}

local FORECAST_KEYS = { wideMult = "ForecastWideMult", crabMult = "ForecastCrabMult", crabHpMult = "ForecastCrabHpMult", fuelMult = "ForecastFuelMult" }

-- Note: when an Atmosphere exists, Roblox ignores the Fog settings, so fog is done with Atmosphere.
local DAY_LIGHTING = {
	ClockTime = 14,
	Brightness = 2,
	Ambient = Color3.fromRGB(110, 110, 115),
	OutdoorAmbient = Color3.fromRGB(128, 128, 135),
}
-- Night (lighting pass, Oct 13): moonlit blue instead of near-black, so the island reads at night.
-- Was ClockTime 22.5, Brightness 0.2, Ambient 18/20/30, OutdoorAmbient 30/34/48.
local NIGHT_LIGHTING = {
	ClockTime = 23.2,
	Brightness = 1.6,
	Ambient = Color3.fromRGB(40, 48, 78),
	OutdoorAmbient = Color3.fromRGB(92, 108, 158),
}
local DAY_ATMOSPHERE = {
	Density = 0.3,
	Haze = 0.5,
	Color = Color3.fromRGB(199, 215, 230),
}
-- was Density 0.45, Haze 1.5, Color 40/45/60 (a grey murk)
local NIGHT_ATMOSPHERE = {
	Density = 0.32,
	Haze = 0.6,
	Color = Color3.fromRGB(52, 72, 122),
}

local function tweenProps(instance, goal, seconds)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(instance, info, goal):Play()
end

local function getAtmosphere()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	return atmosphere
end

local function setLighting(isNight, seconds)
	if isNight then
		tweenProps(Lighting, NIGHT_LIGHTING, seconds)
		tweenProps(getAtmosphere(), NIGHT_ATMOSPHERE, seconds)
	else
		-- Jump to dawn so the sun rises forward instead of rewinding through the evening
		if Lighting.ClockTime > 14 then
			Lighting.ClockTime = 5.5
		end
		tweenProps(Lighting, DAY_LIGHTING, seconds)
		tweenProps(getAtmosphere(), DAY_ATMOSPHERE, seconds)
	end
end

-- deps = { lamp, tower, creatures, state, remotes, resetRound }
function GameState.run(deps)
	local lamp = deps.lamp
	local tower = deps.tower
	local creatures = deps.creatures
	local loot = deps.loot
	local upgrades = deps.upgrades
	local state = deps.state

	local function notifyAll(text)
		deps.remotes.Notify:FireAllClients(text)
	end

	local function setPhase(phase, night)
		state:SetAttribute("Phase", phase)
		state:SetAttribute("Night", night or 0)
		if phase ~= "Waiting" and phase ~= "Intermission" then
			EventLog.log("Phase", { phase = phase, night = night or 0, fuel = math.floor(lamp.getFuel()), tower = state:GetAttribute("Integrity") })
		end
		if phase == "Night" then
			EventLog.setNight(night)
		end
	end

	-- Only players who pressed Play on the title screen take part in runs
	local function readyPlayers()
		local list = {}
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Ready") then
				table.insert(list, player)
			end
		end
		return list
	end

	local function noPlayers()
		return #readyPlayers() == 0
	end

	-- Waits until condition() is true. Returns false if everyone left first.
	local function waitUntil(condition)
		while not condition() do
			if noPlayers() then
				return false
			end
			task.wait(0.25)
		end
		return true
	end

	-- Counts down, publishing TimeLeft. Returns true if it finished,
	-- false if shouldStop() returned true first.
	local function countdown(seconds, shouldStop)
		local endsAt = os.clock() + seconds
		while true do
			local left = endsAt - os.clock()
			state:SetAttribute("TimeLeft", math.max(0, math.ceil(left)))
			if left <= 0 then
				return true
			end
			if shouldStop and shouldStop() then
				return false
			end
			task.wait(0.2)
		end
	end

	-- Spawns a wave of crabs spread over `window` seconds. Returns a function that stops it.
	local function startWave(total, window)
		local active = true
		task.spawn(function()
			local interval = window / math.max(total, 1)
			for _ = 1, total do
				while active and creatures.count() >= Config.MAX_CREATURES do
					task.wait(0.5)
				end
				if not active then
					return
				end
				creatures.spawnCrab()
				task.wait(interval)
			end
		end)
		return function()
			active = false
		end
	end

	-- Swarm (Oct 12 2026): packs of Sand Skitters through the night, on top of the Rock Crab wave.
	-- Waits when MAX_CREATURES are alive, so phones never get more than that at once.
	local function startSwarm(total, window)
		local active = true
		if not Config.SWARM_ENABLED or total <= 0 then
			return function() end
		end
		task.spawn(function()
			local packSize = Config.SWARM_PACK_SIZE or 3
			local interval = window / math.max(math.ceil(total / packSize), 1)
			local spawned = 0
			task.wait(2)
			while active and spawned < total do
				while active and creatures.count() >= Config.MAX_CREATURES do
					task.wait(0.5)
				end
				if not active then
					return
				end
				local bearing = math.random() * 360
				for _ = 1, math.min(packSize, total - spawned) do
					creatures.spawn("SandSkitter", bearing + math.random(-12, 12))
					spawned += 1
				end
				task.wait(interval)
			end
		end)
		return function()
			active = false
		end
	end

	-- The opening incident: the lamp is failing, a storm hits, something huge is out there.
	-- It can't be lost; it teaches fuel, the lamp, and the beam by doing.
	local function runPrologue()
		setPhase("Prologue", 0)
		setLighting(true, 1.5)
		lamp.setFuel(Config.PROLOGUE_START_FUEL)
		lamp.setDraining(true)
		tower.setProtected(true)
		local started = os.clock()
		local function elapsed()
			return os.clock() - started
		end
		if Config.DEV_TEST_BIG_MONSTER ~= "" and Creatures[Config.DEV_TEST_BIG_MONSTER] then
			task.delay(8, creatures.spawn, Config.DEV_TEST_BIG_MONSTER, math.random() * 360)
		end

		notifyAll("The lamp is failing! Grab OIL from the barrels and pour it in the FUEL TANK behind the lighthouse.")
		if not waitUntil(function()
			return lamp.getFuel() > Config.PROLOGUE_START_FUEL + 5 or elapsed() > 30
		end) then
			return false
		end
		if lamp.getFuel() <= Config.PROLOGUE_START_FUEL + 5 then
			EventLog.log("Tutorial", { step = "refuel", result = "timed out, reserve used" })
			lamp.addFuel(40)
			notifyAll("The emergency reserve kicked in. Remember: no oil, no light.")
		else
			EventLog.log("Tutorial", { step = "refuel", result = "done", seconds = elapsed() })
		end

		notifyAll("The light is back! Use the LAMP console at the tower door and sweep the rocks.")
		if not waitUntil(function()
			return lamp.getKeeper() ~= nil or elapsed() > 45
		end) then
			return false
		end

		task.wait(2)
		EventLog.log("Tutorial", { step = "lamp", result = if lamp.getKeeper() then "done" else "timed out", seconds = elapsed() })
		creatures.showSilhouette(lamp.getBeam().angle + 30)
		notifyAll("...something enormous is out there.")
		task.wait(5)

		for _ = 1, Config.PROLOGUE_CRABS do
			creatures.spawnCrab()
			task.wait(1.5)
		end
		if Config.SWARM_ENABLED then
			-- a first taste of the swarm: small skitters the wide beam sweeps away
			local bearing = lamp.getBeam().angle
			for i = 1, (Config.PROLOGUE_SWARM or 0) do
				creatures.spawn("SandSkitter", bearing + math.random(-20, 20))
				if i % 3 == 0 then
					task.wait(2)
				end
			end
		end
		notifyAll("Crabs! Keeper: the wide beam pushes them back, F burns them. Everyone else: click or tap a crab with your harpoon.")

		if not waitUntil(function()
			return creatures.count() == 0 or elapsed() > Config.PROLOGUE_MAX_SECONDS
		end) then
			return false
		end

		lamp.setDraining(false)
		tower.setProtected(false)
		tower.repair(math.huge) -- start the real run with a full-strength tower
		EventLog.log("Tutorial", { step = "crabs", result = if creatures.count() == 0 then "cleared" else "timed out", seconds = elapsed() })
		EventLog.first("opening completed")
		creatures.clearAll()
		notifyAll(if Config.ECONOMY_ENABLED
			then "You survived the first squall. Grab any loot, then spend Shells at the UPGRADE bench."
			else "You survived the first squall. The real storm comes tonight.")
		task.wait(3)
		return true
	end

	setLighting(false, 0)

	-- Storm forecasts (launch R9): two are offered while the crew gathers; the crew votes at the ship.
	local function applyForecast(id)
		local f = id and Forecasts[id]
		state:SetAttribute("Forecast", if f then id else "")
		for field, attribute in FORECAST_KEYS do
			state:SetAttribute(attribute, if f and f[field] then f[field] else 1)
		end
	end
	local function offerForecasts()
		applyForecast(nil)
		for _, p in Players:GetPlayers() do
			p:SetAttribute("ForecastVote", nil)
		end
		if not Config.FORECASTS_ENABLED then
			state:SetAttribute("ForecastA", "")
			state:SetAttribute("ForecastB", "")
			return
		end
		local pool = table.clone(Forecasts.ORDER)
		local a = table.remove(pool, math.random(#pool))
		local b = table.remove(pool, math.random(#pool))
		state:SetAttribute("ForecastA", a)
		state:SetAttribute("ForecastB", b)
	end
	local function chooseForecast(crew)
		local a, b = state:GetAttribute("ForecastA"), state:GetAttribute("ForecastB")
		if not Config.FORECASTS_ENABLED or not Forecasts[a] or not Forecasts[b] then
			applyForecast(nil)
			return nil, 0, 0
		end
		local votesA, votesB = 0, 0
		for _, p in crew do
			local v = p:GetAttribute("ForecastVote")
			if v == a then
				votesA += 1
			elseif v == b then
				votesB += 1
			end
		end
		local pick = if votesA > votesB then a elseif votesB > votesA then b elseif math.random() < 0.5 then a else b
		applyForecast(pick)
		return pick, votesA, votesB
	end

	while true do
		setPhase("Waiting", 0)
		state:SetAttribute("Reason", "")
		state:SetAttribute("Cause", "")
		offerForecasts()
		while noPlayers() do
			task.wait(1)
		end

		setPhase("Intermission", 0)
		-- only for players ashore who haven't joined (the crew sees its own countdown card)
		for _, p in Players:GetPlayers() do
			if not p:GetAttribute("Ready") and p:GetAttribute("InLobby") then
				deps.remotes.Notify:FireClient(p, string.format("The ship sails in %d seconds! Use the SHIP'S WHEEL to join the crew.", Config.INTERMISSION_SECONDS))
			end
		end
		if countdown(Config.INTERMISSION_SECONDS, noPlayers) then
			deps.resetRound()
			local forecast, votesA, votesB = chooseForecast(readyPlayers())
			EventLog.startRun(readyPlayers())
			if forecast then
				EventLog.setForecast(forecast)
				EventLog.log("Forecast", { id = forecast, votesA = votesA, votesB = votesB, a = state:GetAttribute("ForecastA"), b = state:GetAttribute("ForecastB") })
				if deps.lampVisuals then
					deps.lampVisuals()
				end
				task.delay(1.2, notifyAll, "Forecast: " .. Forecasts[forecast].displayName .. ". " .. Forecasts[forecast].summary)
			end
			-- The crew sails from the ship to the lighthouse island
			for _, player in readyPlayers() do
				deps.sendToIsland(player)
			end
			task.wait(0.6)
			local result = "Victory"

			if not runPrologue() then
				result = "Abandoned"
			else
				-- Big monsters this run. Short runs: the middle night and the final night.
				-- Long runs (more than 5 nights): every BIG_EVERY_NIGHTS counting back from the final night
				-- (13 nights -> 13, 10, 7, 4). At most MAX_BIG_PER_RUN.
				local bigNights = {}
				local picked = 0
				local candidates = {}
				if Config.NIGHTS_TO_WIN > 5 and (Config.BIG_EVERY_NIGHTS or 0) > 0 then
					local n = Config.NIGHTS_TO_WIN
					while n >= 2 do
						table.insert(candidates, n)
						n -= Config.BIG_EVERY_NIGHTS
					end
				else
					candidates = { math.max(1, math.ceil(Config.NIGHTS_TO_WIN / 2)), Config.NIGHTS_TO_WIN }
				end
				for _, n in candidates do
					if Config.BIG_MONSTERS_ENABLED and picked < Config.MAX_BIG_PER_RUN and not bigNights[n] then
						bigNights[n] = Creatures.BIG_POOL[math.random(1, #Creatures.BIG_POOL)]
						picked += 1
					end
				end
				for night = 1, Config.NIGHTS_TO_WIN do
					-- DAY: prepare
					setPhase("Day", night)
					setLighting(false, 4)
					notifyAll(if Config.ECONOMY_ENABLED
						then string.format("Day %d: stock up on oil, repair the tower, and spend Shells at the UPGRADE bench.", night)
						else string.format("Day %d: stock up on oil and repair the tower before dark.", night))
					-- Warn early if the lamp won't last the night
					if lamp.getFuel() < lamp.getMaxFuel() * 0.5 then
						task.delay(4, notifyAll, string.format("FUEL IS LOW (%d)! Carry oil to the FUEL TANK before night falls, or the light will go out.", math.floor(lamp.getFuel())))
					end
					if not countdown(Config.DAY_SECONDS, noPlayers) then
						result = "Abandoned"
						break
					end

					-- NIGHT: survive
					setPhase("Night", night)
					setLighting(true, 4)
					notifyAll(string.format("Night %d: the storm is here. Keep the light alive!", night))
					lamp.setDraining(true)
					-- Growth steps: full growth for the first nights, then gentler (owner, Oct 13)
					local fullUntil = Config.GROWTH_FULL_UNTIL or math.huge
					local growth = if night <= fullUntil
						then night - 1
						else (fullUntil - 1) + (night - fullUntil) * (Config.GROWTH_LATE_RATE or 1)
					local crabCount = math.floor((Config.CRABS_BASE + Config.CRABS_PER_NIGHT * growth) * (state:GetAttribute("ForecastCrabMult") or 1) + 0.5)
					if night == Config.NIGHTS_TO_WIN then
						crabCount = math.floor(crabCount * Config.FINAL_NIGHT_CRAB_MULTIPLIER)
					end
					local stopWave = startWave(crabCount, Config.NIGHT_SECONDS * Config.SPAWN_WINDOW)
					local crewSize = math.clamp(#readyPlayers(), 1, 4)
					local crewShare = (Config.SWARM_BY_CREW and Config.SWARM_BY_CREW[crewSize]) or 1
					local swarmCount = math.floor(((Config.SWARM_BASE or 0) + (Config.SWARM_PER_NIGHT or 0) * growth) * crewShare * (state:GetAttribute("ForecastCrabMult") or 1) + 0.5)
					local stopSwarm = startSwarm(swarmCount, Config.NIGHT_SECONDS * (Config.SWARM_WINDOW or 0.85))
					EventLog.log("NightSpawns", { night = night, crabs = crabCount, skitters = if Config.SWARM_ENABLED then swarmCount else 0 })

					-- A big sea monster arrives partway through this night
					local bigKind = bigNights[night]
					if bigKind then
						task.delay(3, function()
							notifyAll("The sea is restless... something BIG is coming tonight. Stay close to your crew.")
							if state:GetAttribute("Phase") == "Night" and state:GetAttribute("Night") == night then
								state:SetAttribute("BigWarning", "approaching") -- HUD warning until it arrives
							end
						end)
						task.delay(Config.NIGHT_SECONDS * Config.BIG_SPAWN_DELAY, function()
							state:SetAttribute("BigWarning", "")
							if state:GetAttribute("Phase") ~= "Night" or state:GetAttribute("Night") ~= night then
								return -- the night already ended
							end
							local bearing = math.random() * 360
							creatures.spawn(bigKind, bearing)
							local rad = math.rad(bearing)
							SoundFx.playAt("monster", Vector3.new(-math.sin(rad) * 80, 5, -math.cos(rad) * 80))
							notifyAll(string.format("A %s climbs out of the sea! Big monsters hit hard: bring your best gear.", string.upper(Creatures[bigKind].displayName)))
							EventLog.log("BigMonsterSpawned", { kind = bigKind, night = night })
						end)
					end

					local survived = countdown(Config.NIGHT_SECONDS, function()
						return noPlayers()
							or lamp.darkSeconds >= Config.DARK_GRACE_SECONDS
							or tower.isBroken()
					end)

					stopWave()
					stopSwarm()
					local wentDark = lamp.darkSeconds >= Config.DARK_GRACE_SECONDS
					lamp.setDraining(false)
					creatures.clearAll() -- at dawn, the survivors retreat into the sea

					if not survived then
						if noPlayers() then
							result = "Abandoned"
						else
							result = "Defeat"
							state:SetAttribute("Cause", if wentDark then "blackout" else "breach") -- for the results screen
							state:SetAttribute("Reason", if wentDark
								then string.format("The light went out: the lamp ran out of fuel and stayed dark for %d seconds.", Config.DARK_GRACE_SECONDS)
								else "The creatures broke into the lighthouse.")
						end
						break
					end
					local bonus = if Config.ECONOMY_ENABLED then Config.WAVE_BONUS_PER_NIGHT * night else 0
					upgrades.addShells(bonus)
					EventLog.log("NightSurvived", { night = night, bonus = bonus, fuel = math.floor(lamp.getFuel()), tower = state:GetAttribute("Integrity") })
					-- Dawn loot window (Oct 12 2026): leftover loot stays on the beach most of the day at full
					-- value, then the tide brings what's left in at DAWN_LOOT_FRACTION. The last night ends the run,
					-- so there the tide comes quickly as before.
					local lootSeconds = if night < Config.NIGHTS_TO_WIN
						then math.min(Config.DAWN_LOOT_SECONDS or 25, Config.DAY_SECONDS - 3)
						else 10
					loot.keepFor(lootSeconds + 1)
					if night < Config.NIGHTS_TO_WIN and Config.ECONOMY_ENABLED then
						if loot.count() > 0 then
							notifyAll(string.format("Night %d survived! +%d shells wave bonus. Loot is still on the beach: grab it in the next %d seconds for full value. The tide brings the rest in at half.", night, bonus, lootSeconds))
						else
							notifyAll(string.format("Night %d survived! +%d shells wave bonus.", night, bonus))
						end
					elseif night < Config.NIGHTS_TO_WIN then
						notifyAll(string.format("Night %d survived! Dawn is coming.", night))
					end
					task.delay(lootSeconds, loot.tideCollect, Config.DAWN_LOOT_FRACTION) -- the tide brings leftover loot in at reduced value
					if deps.autoSell then
						task.delay(lootSeconds + 2, deps.autoSell) -- launch R10 switch (Config.AUTO_SELL_LOOT, off by default)
					end
				end
			end

			setPhase(result, state:GetAttribute("Night"))
			local results = EventLog.endRun(result, state:GetAttribute("Reason"))
			results.cause = state:GetAttribute("Cause") or ""
			results.shellsLeft = upgrades.getShells()
			results.economy = Config.ECONOMY_ENABLED
			setLighting(false, 4)
			if result == "Victory" then
				notifyAll(string.format("You kept the light alive for all %d nights!", Config.NIGHTS_TO_WIN))
			elseif result == "Defeat" then
				notifyAll(state:GetAttribute("Reason") .. " The sea claims the island.")
			end

			-- Results screen and rematch vote. Players who don't choose Play Again go back to the title
			-- screen, which tells us whether people choose to replay (a key playtest question).
			local voters = readyPlayers()

			-- Pearl rewards (saved, personal): PEARLS_PER_NIGHT per night survived (+ the old triangular
			-- step if PEARLS_NIGHT_STEP > 0), plus PEARLS_VICTORY_BONUS for a win. 13-night win = 18.
			results.pearls = {}
			if result ~= "Abandoned" then
				local survived = if result == "Victory" then Config.NIGHTS_TO_WIN else math.max(0, results.nightReached - 1)
				for _, player in voters do
					local earned = (Config.PEARLS_PER_NIGHT or 0) * survived + (Config.PEARLS_NIGHT_STEP or 0) * survived * (survived + 1) / 2
					if result == "Victory" then
						earned += Config.PEARLS_VICTORY_BONUS
					end
					for _, award in results.awards do
						if award.player == player.DisplayName then
							earned += Config.PEARLS_PER_AWARD
						end
					end
					deps.playerData.addPearls(player, earned, "run")
					deps.playerData.recordRun(player, result == "Victory", results.nightReached)
					results.pearls[player.Name] = earned
				end
			end
			-- Loot is run-scoped like shells: unsold loot is lost when the voyage ends
			for _, player in Players:GetPlayers() do
				deps.playerData.clearRunLoot(player)
			end
			if result ~= "Abandoned" and #voters > 0 then
				for _, player in voters do
					player:SetAttribute("WantsRematch", false)
				end
				deps.remotes.RunResults:FireAllClients(results)
				EventLog.log("ResultsShown", { players = #voters })
				EventLog.log("RematchOffered", { players = #voters })
				countdown(Config.RESULT_SECONDS, function()
					for _, player in voters do
						if player.Parent and not player:GetAttribute("WantsRematch") then
							return false
						end
					end
					return true -- everyone voted: start right away
				end)
				local again = 0
				for _, player in voters do
					if player.Parent then
						local wants = player:GetAttribute("WantsRematch") == true
						EventLog.log("RematchChoice", { player = player.Name, choice = if wants then "play again" else "menu" })
						if wants then
							again += 1
						else
							player:SetAttribute("Ready", false)
							deps.sendToShip(player) -- back to the lobby ship
						end
					end
				end
				EventLog.log("Rematch", { playAgain = again, of = #voters })
			else
				task.wait(3)
			end
		end
	end
end

return GameState
