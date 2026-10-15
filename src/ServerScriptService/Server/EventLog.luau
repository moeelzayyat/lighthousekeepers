-- EventLog: records what happens in each run, for playtesting and balancing.
--
-- Every event prints one line to the Output window, starting with [EVT].
-- When a run ends, a summary prints between ===== lines (and is kept in
-- ServerStorage.LastRunSummary while the game is running).
--
-- Turn it off with Config.EVENT_LOG_ENABLED = false (the summary still saves).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EventLog = {}

local runStartedAt = os.clock()
local stats = {}
local devices = {} -- userId -> "Touch" / "Keyboard" / "Gamepad"

-- Onboarding telemetry (launch adaptation, Oct 12 2026)
-- joinedAt lives for the whole server session; marks reset each run (mid-run joiners count in that run).
local joinedAt = {} -- userId -> os.clock() when they joined the server
local routes = {} -- userId -> "fast" / "title" / "failed-load"
local marks = {} -- userId -> { name = player name, steps = { step -> seconds since join } }
local ROLE_STEPS = { fuel = true, repair = true, strike = true, reload = true, lamp = true }
local ORDER = { "crew", "landed", "firstAction", "lamp", "firstBeamHit", "fuel", "repair", "strike", "reload" }

local function freshStats()
	return {
		kills = {}, -- by source
		shellsEarned = 0,
		loot = {}, -- by kind
		upgrades = {}, -- list of "Id Lv"
		cannons = 0,
		cannonUpgrades = 0,
		cannonReloads = 0,
		cannonsEmptied = 0,
		cannonsDestroyed = 0,
		deaths = 0,
		refuels = 0,
		repairs = 0,
		oilGrabbed = 0,
		keeperSeconds = 0,
		keeperSessions = 0,
		idleReleases = 0,
		beamToggles = 0,
		darkEvents = 0,
		attacks = 0,
		attackHits = 0,
		nightReached = 0,
		players = {},
		autoSweepSeconds = 0, -- time the lamp swept on its own at night (nobody at the console)
		shellsSpent = 0,
		lootSold = 0, -- shells the Trader paid for loot this run
		quits = 0, -- players who left mid-run
		clutchSaves = 0, -- refuels at night with the tank under 10% (launch R4/R12)
		moments = {}, -- { priority, text } candidates for the Results "Moment of the storm" (lower = better)
		minTower = 1, -- lowest tower integrity ratio this run (outside the protected opening)
		forecast = nil, -- storm forecast id this run (launch R9)
		firsts = {}, -- milestone -> seconds into the run when it first happened
		perPlayer = {}, -- player name -> { kills, refuels, repairs, cannonReloads, keeperSeconds, shellsCollected, ... }
	}
end
stats = freshStats()

local function stamp()
	return os.clock() - runStartedAt
end

local function format(fields)
	if not fields then
		return ""
	end
	local keys = {}
	for key in fields do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		local value = fields[key]
		if typeof(value) == "number" and value % 1 ~= 0 then
			value = string.format("%.1f", value)
		elseif typeof(value) == "Instance" then
			value = value.Name
		end
		table.insert(parts, key .. "=" .. tostring(value))
	end
	return table.concat(parts, " ")
end

-- Record one event. `fields` is an optional table of extra details.
function EventLog.log(name, fields)
	if Config.EVENT_LOG_ENABLED then
		print(string.format("[EVT %6.1fs] %s %s", stamp(), name, format(fields)))
	end
end

local function bump(tableName, key, amount)
	local t = stats[tableName]
	t[key] = (t[key] or 0) + (amount or 1)
end

-- Per-player counter (used for end-of-run awards)
local function bumpPlayer(player, field, amount)
	if not player then
		return
	end
	local entry = stats.perPlayer[player.Name]
	if not entry then
		entry = { displayName = player.DisplayName }
		stats.perPlayer[player.Name] = entry
	end
	entry[field] = (entry[field] or 0) + (amount or 1)
end

-- Counters used by the end-of-run summary. Pass `player` to also credit that player.
function EventLog.count(field, amount, player)
	stats[field] += amount or 1
	bumpPlayer(player, field, amount)
end

function EventLog.kill(source, player)
	bump("kills", source or "Unknown")
	bumpPlayer(player, "kills", 1)
end

function EventLog.loot(kind, value, player)
	bump("loot", kind)
	stats.shellsEarned += value
	bumpPlayer(player, "shellsCollected", value)
end

function EventLog.upgrade(id, level)
	table.insert(stats.upgrades, id .. " Lv" .. level)
end

function EventLog.setNight(night)
	stats.nightReached = math.max(stats.nightReached, night)
end

function EventLog.setDevice(player, device)
	devices[player.UserId] = device
	EventLog.log("Device", { player = player.Name, device = device })
end

-- Called once when a player joins the server
function EventLog.playerJoined(player)
	joinedAt[player.UserId] = os.clock()
end

function EventLog.setRoute(player, route)
	routes[player.UserId] = route
	EventLog.log("Route", { player = player.Name, route = route })
end

-- Records the first time `player` reaches `step` this run (seconds since they joined the server).
-- Steps: crew, landed, firstAction, firstBeamHit, fuel, repair, strike, reload, lamp,
--        promptShown:<id>, promptDone:<id>. Cheap to call often: repeat calls return at once.
function EventLog.mark(player, step)
	if not player then
		return
	end
	local entry = marks[player.UserId]
	if not entry then
		entry = { name = player.Name, steps = {} }
		marks[player.UserId] = entry
	end
	if entry.steps[step] then
		return
	end
	local sinceJoin = os.clock() - (joinedAt[player.UserId] or runStartedAt)
	entry.steps[step] = sinceJoin
	EventLog.log("Onboard", { player = player.Name, step = step, sinceJoin = sinceJoin, sinceRun = stamp() })
	if ROLE_STEPS[step] or step == "firstBeamHit" then
		EventLog.mark(player, "firstAction")
	end
end

-- The beam hurt a creature while `player` held the lamp (called per frame; first call only logs)
function EventLog.beamHit(player)
	local entry = player and marks[player.UserId]
	if entry and entry.steps.firstBeamHit then
		return
	end
	EventLog.mark(player, "firstBeamHit")
end

-- A player left; phase says where (Waiting, Intermission, Prologue, Day, Night, Results, title, lobby)
function EventLog.playerLeft(player, phase)
	EventLog.log("PlayerLeft", {
		player = player.Name,
		where = phase,
		sessionSeconds = os.clock() - (joinedAt[player.UserId] or os.clock()),
	})
	joinedAt[player.UserId] = nil
end

function EventLog.startRun(players)
	runStartedAt = os.clock()
	stats = freshStats()
	-- joining the crew happens just before the run starts, so carry that step over
	local carried = {}
	for userId, entry in marks do
		if entry.steps.crew then
			carried[userId] = { name = entry.name, steps = { crew = entry.steps.crew } }
		end
	end
	marks = carried
	stats.runId = string.sub(string.gsub(game:GetService("HttpService"):GenerateGUID(false), "[^%w]", ""), 1, 8)
	for _, player in players do
		table.insert(stats.players, player.Name .. "(" .. (devices[player.UserId] or "?") .. ")")
	end
	EventLog.log("RunStarted", {
		players = #players,
		runId = stats.runId,
		economy = Config.ECONOMY_ENABLED,
		bigMonsters = Config.BIG_MONSTERS_ENABLED,
		shortRun = Config.PROTOTYPE_SHORT_RUN,
	})
end

-- Records the first time something happens in a run (first oil pickup, first focused beam, ...)
function EventLog.first(milestone)
	if stats.firsts[milestone] == nil then
		stats.firsts[milestone] = stamp()
		EventLog.log("First", { what = milestone })
	end
end

-- A candidate for the run's "Moment of the storm" (launch R12). priority 1 is the best.
function EventLog.moment(priority, text)
	table.insert(stats.moments, { priority = priority, text = text, at = stamp() })
	EventLog.log("Moment", { priority = priority, text = text })
end

function EventLog.towerLow(ratio)
	if ratio < stats.minTower then
		stats.minTower = ratio
	end
end

function EventLog.setForecast(id)
	stats.forecast = id
end

function EventLog.addSeconds(field, seconds)
	stats[field] += seconds
end

local function listCounts(t)
	local parts = {}
	for key, value in t do
		table.insert(parts, key .. " " .. value)
	end
	table.sort(parts)
	return if #parts > 0 then table.concat(parts, ", ") else "none"
end

function EventLog.endRun(result, reason)
	local duration = stamp()
	local totalKills = 0
	for _, n in stats.kills do
		totalKills += n
	end
	local lines = {
		"===== RUN SUMMARY =====",
		string.format("Run ID: %s   Test mode: economy %s, big monsters %s, %s run", stats.runId or "?",
			if Config.ECONOMY_ENABLED then "ON" else "OFF", if Config.BIG_MONSTERS_ENABLED then "ON" else "OFF",
			if Config.PROTOTYPE_SHORT_RUN then "short" else "full"),
		string.format("Result: %s%s", result, if reason and reason ~= "" then " (" .. reason .. ")" else ""),
		string.format("Night reached: %d of %d   Duration: %d:%02d", stats.nightReached, Config.NIGHTS_TO_WIN, math.floor(duration / 60), math.floor(duration % 60)),
		"Players: " .. (if #stats.players > 0 then table.concat(stats.players, ", ") else "none"),
		string.format("Kills: %d  [%s]", totalKills, listCounts(stats.kills)),
		string.format("Weapon attacks: %d (%d hit)", stats.attacks, stats.attackHits),
		string.format("Shells earned: %d  Loot: [%s]", stats.shellsEarned, listCounts(stats.loot)),
		"Upgrades bought: " .. (if #stats.upgrades > 0 then table.concat(stats.upgrades, ", ") else "none"),
		string.format("Cannons built: %d  upgraded: %d  reloaded: %d  ran empty: %d  destroyed: %d", stats.cannons, stats.cannonUpgrades, stats.cannonReloads, stats.cannonsEmptied, stats.cannonsDestroyed),
		string.format("Player deaths: %d", stats.deaths),
		string.format("Oil grabbed: %d  Refuels: %d  Repairs: %d", stats.oilGrabbed, stats.refuels, stats.repairs),
		string.format("Lamp: %d keeper sessions, %ds manned, %ds automatic sweep (lamp lit, nobody at the console), %d idle releases, %d beam toggles, went dark %d times",
			stats.keeperSessions, math.floor(stats.keeperSeconds), math.floor(stats.autoSweepSeconds), stats.idleReleases, stats.beamToggles, stats.darkEvents),
		string.format("Shells spent: %d   Players who quit mid-run: %d", stats.shellsSpent, stats.quits),
		"First times (seconds into run): " .. (function()
			local parts = {}
			for _, key in { "oil pickup", "lamp refuel", "took the lamp", "wide beam", "focused beam", "harpoon attack", "repair", "opening completed" } do
				local t = stats.firsts[key]
				table.insert(parts, key .. " " .. (if t then string.format("%ds", t) else "never"))
			end
			return table.concat(parts, ", ")
		end)(),
		"Onboarding (seconds since each player joined the server; - = never this run):",
	}
	for userId, entry in marks do
		local parts = {}
		for _, step in ORDER do
			local t = entry.steps[step]
			table.insert(parts, step .. " " .. (if t then string.format("%d", t) else "-"))
		end
		local shown, done = 0, 0
		for step in entry.steps do
			if string.sub(step, 1, 12) == "promptShown:" then
				shown += 1
			elseif string.sub(step, 1, 11) == "promptDone:" then
				done += 1
			end
		end
		table.insert(lines, string.format("  %s (%s, route %s): %s, prompts done %d/%d", entry.name,
			devices[userId] or "?", routes[userId] or "?", table.concat(parts, ", "), done, shown))
	end
	table.insert(lines, "=======================")
	local summary = table.concat(lines, "\n")
	print(summary)

	local holder = ServerStorage:FindFirstChild("LastRunSummary")
	if not holder then
		holder = Instance.new("StringValue")
		holder.Name = "LastRunSummary"
		holder.Parent = ServerStorage
	end
	holder.Value = summary

	-- Awards: who did the most of each job (only shown if someone actually did it)
	local AWARDS = {
		{ title = "Lighthouse Keeper", field = "keeperSeconds", unit = "seconds at the lamp" },
		{ title = "Crab Crusher", field = "kills", unit = "creatures defeated" },
		{ title = "Oil Runner", field = "oilDelivered", unit = "barrels delivered" },
		{ title = "Carpenter", field = "repairs", unit = "repairs" },
		{ title = "Treasure Hunter", field = "shellsCollected", unit = "shells collected" },
	}
	for _, entry in stats.perPlayer do
		entry.oilDelivered = (entry.refuels or 0) + (entry.cannonReloads or 0)
	end
	local awards = {}
	for _, award in AWARDS do
		local bestName, bestValue = nil, 0
		for _, entry in stats.perPlayer do
			local value = entry[award.field] or 0
			if value > bestValue then
				bestName, bestValue = entry.displayName, value
			end
		end
		if bestName then
			table.insert(awards, { title = award.title, player = bestName, value = math.floor(bestValue), unit = award.unit })
		end
	end

	-- Each crew member's contributions (the results screen's "your part" line)
	local crew = {}
	for _, entry in stats.perPlayer do
		table.insert(crew, {
			name = entry.displayName,
			kills = entry.kills or 0,
			oilDelivered = entry.oilDelivered or 0,
			repairs = entry.repairs or 0,
			keeperSeconds = math.floor(entry.keeperSeconds or 0),
			shellsCollected = entry.shellsCollected or 0,
		})
	end

	if result == "Victory" and stats.minTower < 0.15 then
		EventLog.moment(3, string.format("The crew held on with the tower at %d%%", math.max(1, math.floor(stats.minTower * 100))))
	end
	local best
	for _, m in stats.moments do
		if not best or m.priority < best.priority or (m.priority == best.priority and m.at > best.at) then
			best = m
		end
	end

	-- Everything the results screen needs
	return {
		moment = best and best.text or nil,
		forecast = stats.forecast,
		clutchSaves = stats.clutchSaves,
		shellsSpent = stats.shellsSpent,
		lootSold = stats.lootSold,
		crew = crew,
		result = result,
		reason = reason or "",
		nightReached = stats.nightReached,
		totalNights = Config.NIGHTS_TO_WIN,
		duration = math.floor(duration),
		totalKills = totalKills,
		shellsEarned = stats.shellsEarned,
		cannons = stats.cannons,
		refuels = stats.refuels,
		repairs = stats.repairs,
		awards = awards,
	}
end

return EventLog
