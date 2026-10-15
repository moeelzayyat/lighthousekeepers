-- LampService: owns the lamp's fuel, the beam's rotation and mode, and who the Keeper is.
-- The server is the authority: clients only *request* an angle or mode change,
-- and only the current Keeper's requests are accepted.
--
-- Beam modes:
--   wide    = pushes creatures back (default)
--   focused = narrow, burns creatures, uses more fuel
-- With no Keeper, the lamp sweeps on its own in a weaker wide mode.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EventLog = require(script.Parent.EventLog)
local Ground = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ground"))

local LampService = {}
LampService.darkSeconds = 0 -- how long the lamp has been out during the current night

local LIT_COLOR = Color3.fromRGB(255, 226, 150)
local litColor = LIT_COLOR -- the current Keeper's beam colour (launch R15: looks only)
LampService.colorFor = nil -- set by Main: function(player) -> Color3 or nil
local DARK_COLOR = Color3.fromRGB(70, 60, 50)
local PUSH_INTERVAL = 0.2 -- how often fuel numbers are sent to clients

local refs
local state
local remotes

local maxFuel = Config.MAX_FUEL
local fuel = Config.MAX_FUEL
local angle = 0
local targetAngle = 0
local mode = "wide"
local keeper = nil
local keeperSince = 0
local lastKeeperInput = 0
local draining = false
local isLit = true
local sincePush = 0
local heldThisRun = {} -- player -> true once they've held the lamp this run (lamp shift offers)

-- Shortest signed difference between two angles, in the range [-180, 180)
function LampService.angleDelta(from, to)
	return (to - from + 180) % 360 - 180
end
local angleDelta = LampService.angleDelta

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local GLOW_DISTANCES = { 28, 52, 76 } -- where the pools of light sit along the beam

local function applyBeam()
	refs.emitter.CFrame = CFrame.new(refs.lampPosition)
		* CFrame.Angles(0, math.rad(angle), 0)
		* CFrame.Angles(math.rad(-Config.BEAM_TILT), 0, 0)

	local rad = math.rad(angle)
	local direction = Vector3.new(-math.sin(rad), 0, -math.cos(rad))
	local center = Config.ISLAND_CENTER
	for index, glow in refs.beamGlows do
		local distance = GLOW_DISTANCES[index]
		local flat = center + direction * distance
		local groundY = Ground.heightAt(flat.X, flat.Z)
		glow.CFrame = CFrame.new(flat.X, groundY + 10, flat.Z)
	end
end

local function applyModeVisuals()
	local focused = mode == "focused"
	refs.beam.Width1 = if focused then Config.FOCUSED_VISUAL_WIDTH else Config.WIDE_VISUAL_WIDTH * (state:GetAttribute("ForecastWideMult") or 1)
	refs.beam.Brightness = if focused then 6 else 3
	refs.spotLight.Angle = if focused then 15 else 45
	for _, glow in refs.beamGlows do
		glow.PointLight.Range = if focused then 14 else 24
		glow.PointLight.Brightness = if focused then 5 else 2.5
	end
	state:SetAttribute("BeamMode", mode)
end

local function setMode(newMode)
	if mode == newMode then
		return
	end
	mode = newMode
	applyModeVisuals()
end

local function setLit(lit)
	if draining and not lit then
		EventLog.count("darkEvents")
		EventLog.log("LampDark")
	elseif draining and lit then
		EventLog.log("LampRelit", { darkFor = LampService.darkSeconds })
	end
	isLit = lit
	refs.beam.Enabled = lit
	refs.spotLight.Enabled = lit
	refs.pointLight.Enabled = lit
	for _, glow in refs.beamGlows do
		glow.PointLight.Enabled = lit
	end
	refs.lampCore.Color = if lit then litColor else DARK_COLOR
	refs.lampCore.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function pushState()
	state:SetAttribute("Fuel", math.floor(fuel + 0.5))
	state:SetAttribute("MaxFuel", maxFuel)
	state:SetAttribute("DarkSeconds", math.floor(LampService.darkSeconds * 10) / 10)
end

function LampService.notify(player, text)
	remotes.Notify:FireClient(player, text)
end

function LampService.getKeeper()
	return keeper
end

-- reason (for the event log): "console", "leave", "idle", "gone", "reset"
function LampService.setKeeper(player, reason)
	if keeper == player then
		return
	end

	if keeper then
		local held = os.clock() - keeperSince
		EventLog.count("keeperSeconds", held, keeper)
		EventLog.log("KeeperLeft", { player = keeper.Name, reason = reason or "?", held = held })
	end
	if player then
		keeperSince = os.clock()
		EventLog.count("keeperSessions")
		EventLog.log("KeeperTaken", { player = player.Name, reason = reason or "?" })
		EventLog.mark(player, "lamp")
		heldThisRun[player] = true
		EventLog.first("took the lamp")
		EventLog.first("wide beam") -- the lamp always starts in wide mode
	end

	-- Let the old Keeper walk again
	if keeper then
		local humanoid = getHumanoid(keeper)
		if humanoid then
			humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		end
	end

	keeper = player
	lastKeeperInput = os.clock()
	-- beam colour: the Keeper's equipped cosmetic, or the lighthouse amber (colours only, never range or damage)
	litColor = (player and Config.COSMETICS_ENABLED and LampService.colorFor and LampService.colorFor(player)) or LIT_COLOR
	if refs then
		refs.beam.Color = ColorSequence.new(litColor)
		refs.spotLight.Color = litColor
		refs.pointLight.Color = litColor
		for _, glow in refs.beamGlows do
			glow.PointLight.Color = litColor
		end
		if isLit then
			refs.lampCore.Color = litColor
		end
	end
	targetAngle = angle
	setMode("wide")
	state:SetAttribute("KeeperUserId", if player then player.UserId else 0)

	-- The Keeper stands at the console while running the lamp
	if player then
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid:UnequipTools() -- hands on the lamp, not a weapon
		end
	end
end

-- What the creature code needs to know about the beam this frame
-- Re-applies the beam's look (a forecast can narrow the wide beam)
function LampService.refreshVisuals()
	applyModeVisuals()
end

function LampService.getBeam()
	return {
		lit = isLit,
		angle = angle,
		mode = mode,
		manual = keeper ~= nil,
	}
end

function LampService.getFuel()
	return fuel
end

function LampService.getMaxFuel()
	return maxFuel
end

function LampService.setMaxFuel(amount)
	maxFuel = amount
	fuel = math.min(fuel, maxFuel)
	pushState()
end

function LampService.setFuel(amount)
	fuel = math.clamp(amount, 0, maxFuel)
	pushState()
end

function LampService.addFuel(amount)
	fuel = math.min(maxFuel, fuel + amount)
	pushState()
end

function LampService.setDraining(on)
	draining = on
	if not on then
		LampService.darkSeconds = 0
	end
	pushState()
end

function LampService.reset()
	maxFuel = Config.MAX_FUEL
	fuel = maxFuel
	draining = false
	LampService.darkSeconds = 0
	LampService.setKeeper(nil, "reset")
	table.clear(heldThisRun)
	setMode("wide")
	pushState()
end

local function onHeartbeat(dt)
	-- Release the Keeper if they left, died, lost their character, or went idle
	if keeper then
		local humanoid = getHumanoid(keeper)
		if keeper.Parent ~= Players or not humanoid or humanoid.Health <= 0 then
			LampService.setKeeper(nil, "gone")
		elseif os.clock() - lastKeeperInput > Config.KEEPER_IDLE_SECONDS then
			local idlePlayer = keeper
			EventLog.count("idleReleases")
			LampService.setKeeper(nil, "idle")
			LampService.notify(idlePlayer, "You stepped away from the lamp, so it switched to automatic sweep.")
		end
	end

	if keeper then
		-- Manual control: turn toward the requested angle at a limited speed
		local delta = angleDelta(angle, targetAngle)
		if math.abs(delta) > 0.01 then
			local maxStep = Config.BEAM_TURN_SPEED * dt
			angle = (angle + math.clamp(delta, -maxStep, maxStep)) % 360
			applyBeam()
		end
	elseif isLit then
		-- Automatic sweep
		if draining then
			EventLog.addSeconds("autoSweepSeconds", dt)
		end
		angle = (angle + Config.AUTO_SWEEP_SPEED * dt) % 360
		targetAngle = angle
		applyBeam()
	end

	-- Burn fuel at night (faster when focused) and track how long the lamp has been dark
	if draining then
		local rate = Config.FUEL_DRAIN_PER_SECOND
		if mode == "focused" then
			rate *= Config.FOCUSED_FUEL_MULTIPLIER
			if state:GetAttribute("Evo_OverchargedBeam") then
				rate *= 0.75 -- evolution (Shared.Upgrades.EVOLUTIONS): focused beam burns 25% less
			end
		end
		-- Smaller crews burn less fuel
		local crewSize = math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)
		rate *= Config.FUEL_DRAIN_BY_CREW_SIZE[crewSize]
		rate *= state:GetAttribute("ForecastFuelMult") or 1 -- storm forecast (Leaky stores)
		fuel = math.max(0, fuel - rate * dt)
		if fuel <= 0 then
			LampService.darkSeconds += dt
		else
			LampService.darkSeconds = 0
		end
	end

	local shouldBeLit = fuel > 0
	if shouldBeLit ~= isLit then
		setLit(shouldBeLit)
	end

	sincePush += dt
	if sincePush >= PUSH_INTERVAL then
		sincePush = 0
		pushState()
	end
end

function LampService.init(islandRefs, stateFolder, remoteFolder)
	refs = islandRefs
	state = stateFolder
	remotes = remoteFolder

	applyBeam()
	setLit(true)
	applyModeVisuals()
	state:SetAttribute("KeeperUserId", 0)
	pushState()

	-- Keeper aims the beam
	remotes.BeamControl.OnServerEvent:Connect(function(player, requested)
		if player ~= keeper then
			return
		end
		-- Reject anything that isn't a normal number (exploit protection)
		if typeof(requested) ~= "number" or requested ~= requested or math.abs(requested) == math.huge then
			return
		end
		targetAngle = requested % 360
		lastKeeperInput = os.clock()
	end)

	-- Keeper actions: leave the lamp, or switch beam mode
	remotes.LampAction.OnServerEvent:Connect(function(player, action)
		if player ~= keeper then
			return
		end
		if action == "leave" then
			LampService.setKeeper(nil, "leave")
		elseif action == "toggleMode" then
			setMode(if mode == "wide" then "focused" else "wide")
			EventLog.count("beamToggles")
			EventLog.log("BeamMode", { mode = mode })
			if mode == "focused" then
				EventLog.first("focused beam")
			end
			lastKeeperInput = os.clock()
		end
	end)

	-- Lamp console: take the lamp, or give it back
	refs.consolePrompt.Triggered:Connect(function(player)
		if keeper == player then
			LampService.setKeeper(nil, "console")
		elseif keeper == nil then
			LampService.setKeeper(player, "console")
			LampService.notify(player, "You're the Keeper! Aim with your mouse or finger. F (or Focus) switches beams. Q (or Leave) steps away.")
		else
			LampService.notify(player, keeper.DisplayName .. " is already running the lamp.")
		end
	end)

	-- Lamp shift (launch R5): at dawn, offer the lamp to a crew member who hasn't held it this run.
	-- The Keeper is asked first, then the other player; the lamp changes hands only if both say yes.
	-- Day phase only (never during a night), expires after SHIFT_SECONDS, cancelled at nightfall.
	local SHIFT_SECONDS = 20
	local pending = nil -- { id, keeper, candidate, stage = "keeper" | "candidate", expires }
	local nextId = 0

	local function endShift(why)
		if not pending then
			return
		end
		for _, p in { pending.keeper, pending.candidate } do
			if p and p.Parent == Players then
				remotes.LampShift:FireClient(p, { kind = "cancel", id = pending.id })
			end
		end
		EventLog.log("LampShiftEnded", { result = why })
		pending = nil
	end

	local function aliveCrew(p)
		local humanoid = getHumanoid(p)
		return p.Parent == Players and p:GetAttribute("Ready") == true and humanoid ~= nil and humanoid.Health > 0
	end

	local function offerShift()
		if not Config.LAMP_SHIFT_ENABLED or pending then
			return
		end
		local candidate
		for _, p in Players:GetPlayers() do
			if p ~= keeper and not heldThisRun[p] and aliveCrew(p) then
				candidate = p
				break
			end
		end
		if not candidate then
			return
		end
		nextId += 1
		if keeper then
			pending = { id = nextId, keeper = keeper, candidate = candidate, stage = "keeper", expires = os.clock() + SHIFT_SECONDS }
			remotes.LampShift:FireClient(keeper, { kind = "ask", id = nextId, name = candidate.DisplayName, seconds = SHIFT_SECONDS })
			EventLog.log("LampShiftOffered", { keeper = keeper.Name, to = candidate.Name })
		else
			remotes.LampShift:FireClient(candidate, { kind = "nudge", id = nextId })
			EventLog.log("LampShiftNudge", { to = candidate.Name })
		end
	end

	remotes.LampShift.OnServerEvent:Connect(function(player, id, accepted)
		if not pending or id ~= pending.id or typeof(accepted) ~= "boolean" then
			return
		end
		if state:GetAttribute("Phase") ~= "Day" or keeper ~= pending.keeper then
			endShift("stale")
			return
		end
		if pending.stage == "keeper" and player == pending.keeper then
			if not accepted then
				endShift("keeper kept the lamp")
			elseif not aliveCrew(pending.candidate) then
				endShift("candidate unavailable")
			else
				pending.stage = "candidate"
				pending.expires = os.clock() + SHIFT_SECONDS
				remotes.LampShift:FireClient(pending.candidate, { kind = "offer", id = pending.id, name = player.DisplayName, seconds = SHIFT_SECONDS })
			end
		elseif pending.stage == "candidate" and player == pending.candidate then
			if accepted and aliveCrew(player) then
				local from = pending.keeper
				pending = nil
				LampService.setKeeper(player, "shift")
				LampService.notify(player, "You're the Keeper! Aim with your mouse or finger. F (or Focus) switches beams. Q (or Leave) steps away.")
				if from and from.Parent == Players then
					remotes.LampShift:FireClient(from, { kind = "done", name = player.DisplayName })
				end
				EventLog.log("LampShiftEnded", { result = "handed over", to = player.Name })
			else
				endShift("candidate declined")
			end
		end
	end)

	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase == "Day" then
			task.delay(4, function()
				if state:GetAttribute("Phase") == "Day" then
					offerShift()
				end
			end)
		else
			endShift("phase " .. tostring(phase))
		end
	end)
	RunService.Heartbeat:Connect(function()
		if pending and os.clock() > pending.expires then
			endShift("expired")
		end
	end)

	RunService.Heartbeat:Connect(onHeartbeat)
end

return LampService
