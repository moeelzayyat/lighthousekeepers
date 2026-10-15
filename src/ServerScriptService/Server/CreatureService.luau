-- CreatureService: spawns and moves creatures, applies the beam to them, and runs their AGGRO.
--
-- Aggro (threat): every creature keeps a threat score for each possible target:
--   "tower"      gains threat when the lighthouse beam damages the creature (and always has a base amount)
--   a player   gains threat when that player hurts the creature, or stands close to it
--   a cannon   gains threat when that cannon hits the creature
-- Threat slowly fades. The creature walks to the target with the most threat and attacks it:
--   tower  -> chews on it (tower breached = run lost)
--   cannon -> chews on it until it's destroyed
--   player -> bites (armor reduces the damage); players can die
-- Eye color shows intent: yellow = tower, orange = a cannon, red = a player.
--
-- Creatures are anchored models moved by code (no physics), which keeps 40 of them cheap on mobile.
-- Beam rules: wide beam pushes them away from the lighthouse; focused beam stops and burns them.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EventLog = require(script.Parent.EventLog)
local Ground = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ground"))
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local Creatures = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Creatures"))

local CreatureService = {}

local CRAB_COLOR = Color3.fromRGB(176, 64, 44)
local CLAW_COLOR = Color3.fromRGB(150, 50, 35)
local BURN_COLOR = Color3.fromRGB(255, 170, 60)
local EYE_COLOR = Color3.fromRGB(255, 240, 120)
local EYE_CANNON = Color3.fromRGB(255, 150, 60)
local EYE_PLAYER = Color3.fromRGB(255, 60, 50)
local HIT_COLOR = Color3.fromRGB(255, 255, 255)
local LIT_TINT = Color3.fromRGB(235, 150, 95)

local refs
local lamp
local tower
local upgrades
local defense

-- Set by Main: called with a position whenever a creature is killed (used for loot)
CreatureService.onKilled = nil
local creatures = {}
local templates = {} -- creature type -> template model
local state -- GameState folder (the boss bar reads BossName / BossHealth / BossMax)
local center = Config.ISLAND_CENTER

-- Same convention as the beam: bearing 0 points along -Z
local function directionFor(bearing)
	local rad = math.rad(bearing)
	return Vector3.new(-math.sin(rad), 0, -math.cos(rad))
end

local function groundAt(radius)
	if radius <= Config.ISLAND_RADIUS then
		return Config.GROUND_Y
	elseif radius <= Config.ISLAND_RADIUS + 8 then
		return 3 -- beach
	end
	return -0.5 -- half-submerged in the sea
end

local function makeModelPart(model, name, size, offset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(offset)
	part.Parent = model
	return part
end

-- Builds (once) the model template for a creature type from its art in ServerStorage.Art
local function buildTemplate(kind)
	local stats = Creatures[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local art = ServerStorage:FindFirstChild("Art") and ServerStorage.Art:FindFirstChild(stats.art)
	local body
	if art then
		body = art:Clone()
		body.Name = "Body"
		body.Size *= stats.scale
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.CFrame = CFrame.new()
		body.Parent = model
		-- Pivot sits 0.7 studs above the ground; turn the model to face -Z
		local lift = body.Size.Y / 2 - 0.7
		body.PivotOffset = (CFrame.new(0, lift, 0) * CFrame.Angles(0, math.rad(art:GetAttribute("YawOffset") or 0), 0)):Inverse()
		-- Textured models can't be recolored, so hit/burn feedback is a colored glow
		local feedback = Instance.new("PointLight")
		feedback.Name = "Feedback"
		feedback.Range = 7 + stats.bodyRadius * 2
		feedback.Brightness = 4
		feedback.Enabled = false
		feedback.Parent = body
	else
		-- Fallback: simple parts (scaled for big monsters)
		local s = stats.bodyRadius
		body = makeModelPart(model, "Body", Vector3.new(3.2, 1.4, 2.6) * s, Vector3.new(0, 0, 0), CRAB_COLOR)
		makeModelPart(model, "ClawL", Vector3.new(0.9, 0.9, 1.2) * s, Vector3.new(-1.3, 0.1, -1.7) * s, CLAW_COLOR)
		makeModelPart(model, "ClawR", Vector3.new(0.9, 0.9, 1.2) * s, Vector3.new(1.3, 0.1, -1.7) * s, CLAW_COLOR)
	end
	model.PrimaryPart = body
	local height = body.Size.Y
	local bigScale = if stats.big then 3 else 1

	-- Glowing eyes drawn as a billboard: fog and darkness don't hide them
	local eyes = Instance.new("BillboardGui")
	eyes.Name = "GlowEyes"
	eyes.Size = UDim2.new(2.4 * bigScale, 0, 0.9 * bigScale, 0) -- in studs, so they shrink with distance
	eyes.StudsOffset = Vector3.new(0, if stats.big then height * 0.25 else 1.3, 0)
	eyes.LightInfluence = 0
	eyes.MaxDistance = 400
	eyes.Parent = body
	for _, x in { 0.12, 0.62 } do
		local eye = Instance.new("Frame")
		eye.Size = UDim2.fromScale(0.26, 0.7)
		eye.Position = UDim2.fromScale(x, 0.15)
		eye.BackgroundColor3 = EYE_COLOR
		eye.BorderSizePixel = 0
		eye.Parent = eyes
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = eye
	end

	-- Health bar, shown once the creature has taken damage
	local bar = Instance.new("BillboardGui")
	bar.Name = "HealthBar"
	bar.Size = UDim2.new(3 * bigScale, 0, 0.35 * bigScale, 0)
	bar.StudsOffset = Vector3.new(0, if stats.big then height * 0.6 + 1 else 2.4, 0)
	bar.LightInfluence = 0
	bar.MaxDistance = 250
	bar.Enabled = false
	bar.Parent = body
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	back.BorderSizePixel = 0
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(240, 80, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back

	return model
end

local function getTemplate(kind)
	if not templates[kind] then
		templates[kind] = buildTemplate(kind)
	end
	return templates[kind]
end

local function updateHealthBar(crab)
	local ratio = math.clamp(crab.health / crab.maxHealth, 0, 1)
	if math.abs(ratio - crab.shownRatio) < 0.02 then
		return
	end
	crab.shownRatio = ratio
	crab.healthBar.Enabled = ratio < 1
	crab.healthFill.Size = UDim2.fromScale(ratio, 1)
end

local function place(crab, now)
	local bob = if crab.moving then math.abs(math.sin(now * 12 + crab.phase)) * 0.25 else 0
	local surface, inWater = Ground.heightAt(crab.pos.X, crab.pos.Z)
	local heightOffset = if inWater then -0.5 else 0.7 -- half-submerged while still in the sea
	local position = Vector3.new(crab.pos.X, surface + heightOffset + bob, crab.pos.Z)
	local face = crab.facing or Vector3.new(center.X, 0, center.Z)
	local lookTarget = Vector3.new(face.X, position.Y, face.Z)
	if (lookTarget - position).Magnitude > 0.05 then
		crab.model:PivotTo(CFrame.lookAt(position, lookTarget))
	else
		crab.model:PivotTo(CFrame.new(position))
	end
end

---------------------------------------------------------------------
-- Aggro helpers
---------------------------------------------------------------------

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Where a target is (flat), or nil if it no longer exists
local function targetPosition(target)
	if target == "tower" then
		return Vector3.new(center.X, 0, center.Z)
	elseif typeof(target) == "Instance" then
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root and flat(root.Position)
	elseif type(target) == "table" and target.position then
		return flat(target.position)
	end
	return nil
end

local function targetValid(target)
	if target == "tower" then
		return true
	elseif typeof(target) == "Instance" then
		if target.Parent ~= Players or not target:GetAttribute("Ready") then
			return false
		end
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0
	elseif type(target) == "table" then
		return (target.level or 0) > 0 -- a built cannon
	end
	return false
end

local function addThreat(crab, target, amount)
	if target ~= nil and amount > 0 then
		crab.threat[target] = (crab.threat[target] or 0) + amount
	end
end

-- Picks the target with the most threat; only switches if the new one clearly beats the current one
local function chooseTarget(crab)
	local best, bestScore = "tower", crab.threat.tower or 0
	for target, score in crab.threat do
		if target ~= "tower" and score > bestScore and targetValid(target) then
			best, bestScore = target, score
		end
	end
	local current = crab.target
	if current and current ~= best and targetValid(current) then
		if bestScore < (crab.threat[current] or 0) * Config.THREAT_SWITCH_RATIO then
			return current
		end
	end
	return best
end

local function setEyes(crab, target)
	local color = if target == "tower" then EYE_COLOR elseif typeof(target) == "Instance" then EYE_PLAYER else EYE_CANNON
	if crab.eyeColor ~= color then
		crab.eyeColor = color
		for _, eye in crab.eyes do
			eye.BackgroundColor3 = color
		end
	end
end

-- A bite or slam on a player: armor reduces it; records deaths
local function bitePlayer(player, crabPosition, damage, cause)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local reduction = player:GetAttribute("DamageReduction") or 0
	humanoid:TakeDamage(damage * (1 - reduction))
	SoundFx.playAt("hit", crabPosition)
	if humanoid.Health <= 0 then
		EventLog.count("deaths", 1, player)
		EventLog.log("PlayerDied", { player = player.Name, cause = cause })
	end
end

-- Small burst of light when a creature is burned away
local function burst(position)
	SoundFx.playAt("crabDeath", position)
	local puff = Instance.new("Part")
	puff.Shape = Enum.PartType.Ball
	puff.Size = Vector3.new(2, 2, 2)
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.CanTouch = false
	puff.Material = Enum.Material.Neon
	puff.Color = BURN_COLOR
	puff.CFrame = CFrame.new(position)
	puff.Parent = refs.creatureFolder
	local tween = TweenService:Create(puff, TweenInfo.new(0.35), { Size = Vector3.new(7, 7, 7), Transparency = 1 })
	tween.Completed:Connect(function()
		puff:Destroy()
	end)
	tween:Play()
end

local function removeAt(index, reason)
	local crab = table.remove(creatures, index)
	if reason == "killed" then
		EventLog.kill(crab.lastSource, if typeof(crab.lastAttacker) == "Instance" then crab.lastAttacker else nil)
		burst(crab.body.Position)
		if crab.stats.big then
			EventLog.log("BigMonsterKilled", { kind = crab.kind, by = crab.lastSource })
			local monster = string.gsub(tostring(crab.kind), "(%l)(%u)", "%1 %2") -- "BarnacleBrute" -> "Barnacle Brute"
			local attacker = if typeof(crab.lastAttacker) == "Instance" then crab.lastAttacker else nil
			if attacker and crab.lastSource == "FocusedBeam" then
				EventLog.moment(2, attacker.DisplayName .. " burned down the " .. monster .. " with the focused beam")
			elseif attacker then
				EventLog.moment(2, attacker.DisplayName .. " landed the final blow on the " .. monster)
			else
				EventLog.moment(2, "The crew brought down the " .. monster)
			end
		end
		if CreatureService.onKilled then
			CreatureService.onKilled(crab.body.Position, crab.kind)
		end
	end
	if crab.bossEntry then
		-- tell the HUD how this monster left, then remove its entry a moment later
		crab.bossEntry:SetAttribute("Outcome", reason)
		crab.bossEntry:SetAttribute("Health", if reason == "killed" then 0 else crab.bossEntry:GetAttribute("Health"))
		task.delay(0.6, game.Destroy, crab.bossEntry)
	end
	if crab.stats.big and state then
		-- keep the legacy single boss bar pointing at another live big monster, if there is one
		local other
		for _, c in creatures do
			if c.stats.big then
				other = c
				break
			end
		end
		if other then
			state:SetAttribute("BossName", other.stats.displayName)
			state:SetAttribute("BossMax", other.maxHealth)
			state:SetAttribute("BossHealth", math.max(0, math.ceil(other.health)))
		else
			state:SetAttribute("BossName", "")
		end
	end
	crab.model:Destroy()
end

-- Spawns a creature of the given type (see Shared/Creatures) climbing out of the sea
function CreatureService.spawn(kind, bearing)
	local stats = Creatures[kind]
	if not stats then
		return false
	end
	if #creatures >= Config.MAX_CREATURES and not stats.big then
		return false
	end
	local model = getTemplate(kind):Clone()
	bearing = bearing or math.random() * 360
	local eyes = {}
	for _, eye in model.PrimaryPart.GlowEyes:GetChildren() do
		if eye:IsA("Frame") then
			table.insert(eyes, eye)
		end
	end
	local crab = {
		kind = kind,
		stats = stats,
		model = model,
		body = model.PrimaryPart,
		bearing = bearing,
		pos = flat(center + directionFor(bearing) * Config.CREATURE_SPAWN_RADIUS),
		radius = Config.CREATURE_SPAWN_RADIUS,
		threat = { tower = Config.THREAT_BASE_TOWER },
		target = "tower",
		eyes = eyes,
		nextBite = 0,
		health = stats.health * (if stats.big then 1 else (state:GetAttribute("ForecastCrabHpMult") or 1)),
		maxHealth = stats.health * (if stats.big then 1 else (state:GetAttribute("ForecastCrabHpMult") or 1)),
		shownRatio = 1,
		healthBar = model.PrimaryPart.HealthBar,
		healthFill = model.PrimaryPart.HealthBar.Frame.Fill,
		phase = math.random() * 10,
		moving = true,
		burning = false,
		flashUntil = 0,
		currentColor = CRAB_COLOR,
		feedback = model.PrimaryPart:FindFirstChild("Feedback"),
	}
	place(crab, os.clock())
	model.Parent = refs.creatureFolder
	table.insert(creatures, crab)
	if stats.big and state then
		state:SetAttribute("BossName", stats.displayName)
		state:SetAttribute("BossMax", stats.health)
		state:SetAttribute("BossHealth", stats.health)
		-- HUD boss list: GameState.Bosses holds one entry per live big monster
		local bosses = state:FindFirstChild("Bosses")
		if not bosses then
			bosses = Instance.new("Folder")
			bosses.Name = "Bosses"
			bosses.Parent = state
		end
		local entry = Instance.new("Configuration")
		entry.Name = kind .. "_" .. string.format("%d", os.clock() * 1000)
		entry:SetAttribute("DisplayName", stats.displayName)
		entry:SetAttribute("Health", stats.health)
		entry:SetAttribute("Max", stats.health)
		entry.Parent = bosses
		crab.bossEntry = entry
	end
	return true
end

-- Rock Crabs (kept for existing callers)
function CreatureService.spawnCrab(bearing)
	return CreatureService.spawn("RockCrab", bearing)
end

-- Damages up to `maxTargets` creatures within `radius` of `position` (measured flat),
-- closest first. Returns a list of the positions that were hit (empty if none).
-- `source` names what dealt the damage (for the event log).
function CreatureService.damageArea(position, radius, amount, maxTargets, source, attacker)
	local candidates = {}
	for index, crab in creatures do
		local offset = crab.body.Position - position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= radius + crab.stats.bodyRadius then
			table.insert(candidates, { index = index, distance = distance })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local hits = {}
	local killed = {}
	for n = 1, math.min(maxTargets, #candidates) do
		local crab = creatures[candidates[n].index]
		table.insert(hits, crab.body.Position)
		crab.health -= amount
		crab.lastSource = source or "Unknown"
		crab.lastAttacker = attacker
		-- Aggro: whoever hurt it becomes more interesting to it
		if typeof(attacker) == "Instance" then
			addThreat(crab, attacker, amount * Config.THREAT_WEAPON_MULT)
		elseif type(attacker) == "table" then
			addThreat(crab, attacker, amount * Config.THREAT_CANNON_MULT)
		end
		crab.flashUntil = os.clock() + 0.12
		updateHealthBar(crab)
		if crab.health <= 0 then
			table.insert(killed, candidates[n].index)
		end
	end

	-- Remove dead creatures from the highest index down so the list stays valid
	table.sort(killed, function(a, b)
		return a > b
	end)
	for _, index in killed do
		removeAt(index, "killed")
	end
	return hits
end

-- Finds the creature within `range` of `position` that is closest to the tower
-- (the biggest threat). Returns its position, or nil.
function CreatureService.findTarget(position, range)
	local best, bestRadius = nil, math.huge
	for _, crab in creatures do
		local offset = crab.body.Position - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= range and crab.radius < bestRadius then
			best, bestRadius = crab, crab.radius
		end
	end
	return best and best.body.Position
end

function CreatureService.count()
	return #creatures
end

function CreatureService.clearAll()
	for index = #creatures, 1, -1 do
		removeAt(index, "cleared")
	end
end

-- The opening-incident reveal: something enormous rises out of the sea, then sinks.
function CreatureService.showSilhouette(bearing)
	local base = center + directionFor(bearing) * 170

	local model = Instance.new("Model")
	model.Name = "Silhouette"
	local head = makeModelPart(model, "Head", Vector3.new(60, 60, 60), Vector3.new(0, 0, 0), Color3.fromRGB(12, 14, 20))
	head.Shape = Enum.PartType.Ball
	local eyeColor = Color3.fromRGB(190, 255, 120)
	makeModelPart(model, "EyeL", Vector3.new(5, 2, 2), Vector3.new(-9, 12, -27), eyeColor, Enum.Material.Neon)
	makeModelPart(model, "EyeR", Vector3.new(5, 2, 2), Vector3.new(9, 12, -27), eyeColor, Enum.Material.Neon)
	model.PrimaryPart = head
	model.Parent = refs.creatureFolder

	-- Tween a number and move the model with it (models can't be tweened directly)
	local height = Instance.new("NumberValue")
	height.Value = -45
	local function apply()
		local position = Vector3.new(base.X, height.Value, base.Z)
		model:PivotTo(CFrame.lookAt(position, Vector3.new(center.X, height.Value, center.Z)))
	end
	height.Changed:Connect(apply)
	apply()

	task.spawn(function()
		local rise = TweenService:Create(height, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = -6 })
		rise:Play()
		rise.Completed:Wait()
		task.wait(3.5)
		local sink = TweenService:Create(height, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Value = -45 })
		sink:Play()
		sink.Completed:Wait()
		model:Destroy()
		height:Destroy()
	end)
end

local function onHeartbeat(dt)
	if #creatures == 0 then
		return
	end

	local beam = lamp.getBeam()
	local halfAngle = if beam.mode == "focused" then Config.FOCUSED_HALF_ANGLE else Config.WIDE_HALF_ANGLE * (state:GetAttribute("ForecastWideMult") or 1)
	local now = os.clock()
	local lens = upgrades.value("LensPower", 1) -- beam damage multiplier
	local sweepDps = upgrades.value("ClockworkSweep", 0) -- automatic sweep damage
	local towerCenter = Vector3.new(center.X, 0, center.Z)
	local decay = 1 - Config.THREAT_DECAY * dt

	-- Players who can be targeted this frame (in the run and alive)
	local players = {}
	for _, player in Players:GetPlayers() do
		if targetValid(player) then
			table.insert(players, { player = player, pos = targetPosition(player) })
		end
	end

	for index = #creatures, 1, -1 do
		local crab = creatures[index]
		local stats = crab.stats
		local fromCenter = crab.pos - towerCenter
		crab.radius = fromCenter.Magnitude
		crab.bearing = math.deg(math.atan2(-fromCenter.X, -fromCenter.Z))
		local inBeam = beam.lit and math.abs(lamp.angleDelta(beam.angle, crab.bearing)) <= halfAngle

		-- Threat fades (the tower never drops below its base), and players standing close add threat
		for target, score in crab.threat do
			if target ~= "tower" then
				local faded = score * decay
				crab.threat[target] = if faded < 0.5 or not targetValid(target) then nil else faded
			end
		end
		crab.threat.tower = math.max(Config.THREAT_BASE_TOWER, crab.threat.tower * decay)
		for _, entry in players do
			if entry.pos and (entry.pos - crab.pos).Magnitude < 10 + stats.bodyRadius then
				addThreat(crab, entry.player, Config.THREAT_PROXIMITY * dt)
			end
		end

		-- Beam effects (beam damage builds threat on the TOWER)
		local speedFactor = 1
		local pushed = false
		local burning = false
		local lit = false
		local beamDamage = 0
		if inBeam then
			if beam.manual and beam.mode == "focused" then
				speedFactor = 0
				burning = true
				beamDamage = Config.FOCUSED_DPS * lens * dt
				crab.lastSource = "FocusedBeam"
				crab.lastAttacker = lamp.getKeeper()
			elseif beam.manual then
				-- heavy monsters can't be shoved; the wide beam just slows them
				pushed = stats.pushable
				if not stats.pushable then
					speedFactor = 0.6
				end
				lit = true
				beamDamage = Config.WIDE_DPS * lens * dt
				crab.lastSource = "WideBeam"
				crab.lastAttacker = lamp.getKeeper()
			else
				speedFactor = Config.AUTO_SWEEP_SLOW
				lit = true
				beamDamage = sweepDps * dt
				if sweepDps > 0 then
					crab.lastSource = "Sweep"
					crab.lastAttacker = nil
				end
			end
		end
		if beamDamage > 0 then
			beamDamage *= stats.beamDamageMult
			crab.health -= beamDamage
			addThreat(crab, "tower", beamDamage * Config.THREAT_BEAM_MULT)
			if beam.manual then
				EventLog.beamHit(crab.lastAttacker) -- onboarding telemetry: first beam hit per Keeper
			end
		end
		updateHealthBar(crab)

		crab.burning = burning
		local color = if crab.flashUntil > now then HIT_COLOR
			elseif burning then BURN_COLOR
			elseif lit then LIT_TINT
			else CRAB_COLOR
		if color ~= crab.currentColor then
			crab.currentColor = color
			crab.body.Color = color
			if crab.feedback then
				crab.feedback.Enabled = color ~= CRAB_COLOR
				crab.feedback.Color = color
			end
		end

		if crab.health <= 0 then
			removeAt(index, "killed")
			continue
		end

		-- Choose a target and move toward it / attack it
		local target = chooseTarget(crab)
		crab.target = target
		setEyes(crab, target)
		local goal = targetPosition(target) or towerCenter
		crab.facing = goal
		crab.moving = false

		if pushed then
			-- wide beam shoves it straight away from the lighthouse
			local away = if crab.radius > 0.01 then fromCenter.Unit else Vector3.new(0, 0, 1)
			crab.pos += away * Config.WIDE_PUSH_SPEED * dt
			crab.moving = true
		elseif speedFactor > 0 then
			local toGoal = goal - crab.pos
			local distance = toGoal.Magnitude
			local reached
			if target == "tower" then
				reached = crab.radius <= Config.TOWER_ATTACK_RADIUS
			else
				reached = distance <= stats.attackRange
			end
			if not reached then
				local stopAt = if target == "tower" then 0 else stats.attackRange * 0.8
				local step = math.min(stats.speed * speedFactor * dt, math.max(0, distance - stopAt))
				if distance > 0.01 then
					crab.pos += toGoal.Unit * step
				end
				crab.moving = step > 0
			else
				-- Attack
				if target == "tower" then
					tower.damage(stats.towerDps * dt)
				elseif typeof(target) == "Instance" then
					if now >= crab.nextBite then
						crab.nextBite = now + stats.attackInterval
						if stats.slamRadius > 0 then
							-- ground slam: everyone near the target gets hit
							local center3 = targetPosition(target) or crab.pos
							for _, entry in players do
								if entry.pos and (entry.pos - center3).Magnitude <= stats.slamRadius then
									bitePlayer(entry.player, crab.body.Position, stats.playerDamage, stats.displayName)
								end
							end
							SoundFx.playAt("cannonImpact", crab.body.Position)
						else
							bitePlayer(target, crab.body.Position, stats.playerDamage, stats.displayName)
						end
					end
				elseif defense then
					defense.damageCannon(target, stats.cannonDps * dt)
				end
			end
		end

		-- Never walk inside the tower
		local offset = crab.pos - towerCenter
		if offset.Magnitude < Config.TOWER_ATTACK_RADIUS then
			crab.pos = towerCenter + (if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(0, 0, 1)) * Config.TOWER_ATTACK_RADIUS
		end
		crab.radius = (crab.pos - towerCenter).Magnitude

		if crab.radius > Config.CREATURE_SPAWN_RADIUS + 1 then
			removeAt(index, "fled") -- pushed back into the sea
		else
			place(crab, now)
			-- keep the boss bar up to date
			if stats.big and state then
				local shown = math.max(0, math.ceil(crab.health))
				if state:GetAttribute("BossName") == stats.displayName and state:GetAttribute("BossHealth") ~= shown then
					state:SetAttribute("BossHealth", shown)
				end
				if crab.bossEntry and crab.bossEntry:GetAttribute("Health") ~= shown then
					crab.bossEntry:SetAttribute("Health", shown)
				end
			end
		end
	end
end

-- defenseService is used to damage cannons that creatures attack
function CreatureService.init(islandRefs, lampService, towerService, upgradeService, defenseService, stateFolder)
	refs = islandRefs
	lamp = lampService
	tower = towerService
	upgrades = upgradeService
	defense = defenseService
	state = stateFolder
	if state then
		state:SetAttribute("BossName", "")
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return CreatureService
