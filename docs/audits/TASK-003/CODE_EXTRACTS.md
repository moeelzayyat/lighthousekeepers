# Relevant code extracts (TASK-003)

Verbatim excerpts of the version-148 export in `src\ServerScriptService\Server\`, with original line numbers. Generated mechanically from the files on disk; nothing edited.

## PlayerData.luau lines 20-28
```lua
  20: local STORE_NAME = "LighthouseKeepers_PlayerData_v1"
  21: local SCHEMA_VERSION = 1
  22: local AUTOSAVE_SECONDS = 60
  23: 
  24: local store = nil
  25: local storeAvailable = false
  26: local profiles = {} -- player -> profile table
  27: local dirty = {} -- player -> true when unsaved changes exist
  28: local remotes
```

## PlayerData.luau lines 33-50
```lua
  33: local function newProfile()
  34: 	local profile = {
  35: 		version = SCHEMA_VERSION,
  36: 		pearls = Config.DEV_START_PEARLS or 0,
  37: 		owned = {}, -- itemId -> true (weapons and armor)
  38: 		counts = {}, -- itemId -> number (ammo crates and materials)
  39: 		equippedArmor = "OilskinCoat",
  40: 		equippedWeapon = "DriftwoodHarpoon",
  41: 		equippedBeam = "BeamAmber", -- beam colour (launch R15, owner-approved). Old saves get this default.
  42: 		stats = { runs = 0, victories = 0, bestNight = 0 },
  43: 	}
  44: 	for id, item in Items do
  45: 		if type(item) == "table" and item.starter then
  46: 			profile.owned[id] = true
  47: 		end
  48: 	end
  49: 	return profile
  50: end
```

## PlayerData.luau lines 52-59
```lua
  52: -- Fills in anything missing from older saves
  53: local function reconcile(profile)
  54: 	local template = newProfile()
  55: 	for key, value in template do
  56: 		if profile[key] == nil then
  57: 			profile[key] = value
  58: 		end
  59: 	end
```

## PlayerData.luau lines 96-150
```lua
  96: local function markChanged(player)
  97: 	dirty[player] = true
  98: 	push(player)
  99: end
 100: 
 101: local function save(player)
 102: 	local profile = profiles[player]
 103: 	if not profile or not storeAvailable or not dirty[player] then
 104: 		return
 105: 	end
 106: 	local ok, err = pcall(function()
 107: 		store:UpdateAsync(keyFor(player), function()
 108: 			return profile
 109: 		end)
 110: 	end)
 111: 	if ok then
 112: 		dirty[player] = nil
 113: 	else
 114: 		warn("PlayerData: save failed for " .. player.Name .. ": " .. tostring(err))
 115: 	end
 116: end
 117: 
 118: local function load(player)
 119: 	local profile
 120: 	if storeAvailable then
 121: 		for attempt = 1, 3 do
 122: 			local ok, result = pcall(function()
 123: 				return store:GetAsync(keyFor(player))
 124: 			end)
 125: 			if ok then
 126: 				profile = if result then reconcile(result) else newProfile()
 127: 				break
 128: 			end
 129: 			warn(string.format("PlayerData: load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
 130: 			task.wait(attempt)
 131: 		end
 132: 		if not profile then
 133: 			-- Never overwrite a real save with a blank one: play in memory this session
 134: 			warn("PlayerData: could not load " .. player.Name .. "; progress this session will NOT be saved.")
 135: 			profile = newProfile()
 136: 			profile.doNotSave = true
 137: 		end
 138: 	else
 139: 		profile = newProfile()
 140: 	end
 141: 	if player.Parent ~= Players then
 142: 		return -- left while loading
 143: 	end
 144: 	profiles[player] = profile
 145: 	-- Read-only signals for the first-voyage route and coach (launch R2/R3). Nothing new is saved.
 146: 	-- "failed" = the save couldn't be read: never treat that player as new, never save over them.
 147: 	player:SetAttribute("RunsCompleted", if profile.doNotSave then -1 else profile.stats.runs)
 148: 	player:SetAttribute("ProfileState", if profile.doNotSave then "failed" elseif storeAvailable then "saved" else "memory")
 149: 	push(player)
 150: end
```

## PlayerData.luau lines 287-349
```lua
 287: function PlayerData.init(remoteFolder, notify)
 288: 	remotes = remoteFolder
 289: 
 290: 	local ok, result = pcall(function()
 291: 		local s = DataStoreService:GetDataStore(STORE_NAME)
 292: 		s:GetAsync("__access_check")
 293: 		return s
 294: 	end)
 295: 	if ok then
 296: 		store = result
 297: 		storeAvailable = true
 298: 	else
 299: 		warn("PlayerData: DataStores unavailable (" .. tostring(result) .. "). Progress is kept in memory only. In Studio, enable Game Settings > Security > Enable Studio Access to API Services.")
 300: 		-- the HUD shows a "progress isn't saving" warning to players
 301: 		local Players = game:GetService("Players")
 302: 		for _, p in Players:GetPlayers() do
 303: 			p:SetAttribute("SaveUnavailable", true)
 304: 		end
 305: 		Players.PlayerAdded:Connect(function(p)
 306: 			p:SetAttribute("SaveUnavailable", true)
 307: 		end)
 308: 	end
 309: 
 310: 	remotes.GearAction.OnServerEvent:Connect(function(player, action)
 311: 		-- The only client request handled here: "send me my data".
 312: 		-- Buying/selling go through ShopService (Quartermaster); equipping through LoadoutService.
 313: 		if action == "sync" then
 314: 			push(player)
 315: 		end
 316: 	end)
 317: 	local lastAction = {} -- (kept for cleanup on leave)
 318: 
 319: 	Players.PlayerAdded:Connect(load)
 320: 	for _, player in Players:GetPlayers() do
 321: 		task.spawn(load, player)
 322: 	end
 323: 	Players.PlayerRemoving:Connect(function(player)
 324: 		local profile = profiles[player]
 325: 		if profile and not profile.doNotSave then
 326: 			save(player)
 327: 		end
 328: 		profiles[player] = nil
 329: 		dirty[player] = nil
 330: 		lastAction[player] = nil
 331: 	end)
 332: 	game:BindToClose(function()
 333: 		for player, profile in profiles do
 334: 			if not profile.doNotSave then
 335: 				save(player)
 336: 			end
 337: 		end
 338: 	end)
 339: 	task.spawn(function()
 340: 		while true do
 341: 			task.wait(AUTOSAVE_SECONDS)
 342: 			for player, profile in profiles do
 343: 				if not profile.doNotSave then
 344: 					task.spawn(save, player)
 345: 				end
 346: 			end
 347: 		end
 348: 	end)
 349: end
```

## GameState.luau lines 101-109
```lua
 101: 	local function readyPlayers()
 102: 		local list = {}
 103: 		for _, player in Players:GetPlayers() do
 104: 			if player:GetAttribute("Ready") then
 105: 				table.insert(list, player)
 106: 			end
 107: 		end
 108: 		return list
 109: 	end
```

## GameState.luau lines 408-412
```lua
 408: 					end
 409: 					local stopWave = startWave(crabCount, Config.NIGHT_SECONDS * Config.SPAWN_WINDOW)
 410: 					local crewSize = math.clamp(#readyPlayers(), 1, 4)
 411: 					local crewShare = (Config.SWARM_BY_CREW and Config.SWARM_BY_CREW[crewSize]) or 1
 412: 					local swarmCount = math.floor(((Config.SWARM_BASE or 0) + (Config.SWARM_PER_NIGHT or 0) * growth) * crewShare * (state:GetAttribute("ForecastCrabMult") or 1) + 0.5)
```

## GameState.luau lines 463-465
```lua
 463: 					local bonus = if Config.ECONOMY_ENABLED then Config.WAVE_BONUS_PER_NIGHT * night else 0
 464: 					upgrades.addShells(bonus)
 465: 					EventLog.log("NightSurvived", { night = night, bonus = bonus, fuel = math.floor(lamp.getFuel()), tower = state:GetAttribute("Integrity") })
```

## GameState.luau lines 503-524
```lua
 503: 			local voters = readyPlayers()
 504: 
 505: 			-- Pearl rewards (saved, personal): PEARLS_PER_NIGHT per night survived (+ the old triangular
 506: 			-- step if PEARLS_NIGHT_STEP > 0), plus PEARLS_VICTORY_BONUS for a win. 13-night win = 18.
 507: 			results.pearls = {}
 508: 			if result ~= "Abandoned" then
 509: 				local survived = if result == "Victory" then Config.NIGHTS_TO_WIN else math.max(0, results.nightReached - 1)
 510: 				for _, player in voters do
 511: 					local earned = (Config.PEARLS_PER_NIGHT or 0) * survived + (Config.PEARLS_NIGHT_STEP or 0) * survived * (survived + 1) / 2
 512: 					if result == "Victory" then
 513: 						earned += Config.PEARLS_VICTORY_BONUS
 514: 					end
 515: 					for _, award in results.awards do
 516: 						if award.player == player.DisplayName then
 517: 							earned += Config.PEARLS_PER_AWARD
 518: 						end
 519: 					end
 520: 					deps.playerData.addPearls(player, earned, "run")
 521: 					deps.playerData.recordRun(player, result == "Victory", results.nightReached)
 522: 					results.pearls[player.Name] = earned
 523: 				end
 524: 			end
```

## LampService.luau lines 283-285
```lua
 283: 		-- Smaller crews burn less fuel
 284: 		local crewSize = math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)
 285: 		rate *= Config.FUEL_DRAIN_BY_CREW_SIZE[crewSize]
```

## LampService.luau lines 380-392
```lua
 380: 
 381: 	local function aliveCrew(p)
 382: 		local humanoid = getHumanoid(p)
 383: 		return p.Parent == Players and p:GetAttribute("Ready") == true and humanoid ~= nil and humanoid.Health > 0
 384: 	end
 385: 
 386: 	local function offerShift()
 387: 		if not Config.LAMP_SHIFT_ENABLED or pending then
 388: 			return
 389: 		end
 390: 		local candidate
 391: 		for _, p in Players:GetPlayers() do
 392: 			if p ~= keeper and not heldThisRun[p] and aliveCrew(p) then
```

## Main.server.luau lines 69-71
```lua
  69: refs.upgradePrompt.Triggered:Connect(function(player)
  70: 	remotes.OpenUpgrades:FireClient(player)
  71: end)
```

## Main.server.luau lines 116-145
```lua
 116: remotes.BuyUpgrade.OnServerEvent:Connect(function(player, id, requestId)
 117: 	if typeof(id) ~= "string" then
 118: 		return
 119: 	end
 120: 	if requestId ~= nil and (typeof(requestId) ~= "string" or #requestId > 40) then
 121: 		return
 122: 	end
 123: 	local now = os.clock()
 124: 	if (lastBuy[player] or 0) + 0.3 > now then
 125: 		if requestId then
 126: 			remotes.UpgradeResult:FireClient(player, requestId, false, "One upgrade at a time. Try again.", id)
 127: 		end
 128: 		return -- ignore double-clicks
 129: 	end
 130: 	lastBuy[player] = now
 131: 	local ok, message = UpgradeService.buy(id)
 132: 	if requestId then
 133: 		remotes.UpgradeResult:FireClient(player, requestId, ok, message, id)
 134: 	end
 135: 	if ok then
 136: 		EventLog.upgrade(id, UpgradeService.getLevel(id))
 137: 		EventLog.log("UpgradeBought", { player = player.Name, id = id, level = UpgradeService.getLevel(id) })
 138: 		local benchPart = refs.upgradePrompt.Parent
 139: 		if benchPart then
 140: 			SoundFx.playAt("build", benchPart.Position)
 141: 		end
 142: 		remotes.Notify:FireAllClients(player.DisplayName .. ": " .. message)
 143: 	elseif not requestId then
 144: 		LampService.notify(player, message) -- the bench UI shows the reason itself
 145: 	end
```

## Main.server.luau lines 204-231
```lua
 204: refs.oilPrompt.Triggered:Connect(function(player)
 205: 	if player:GetAttribute("CarryingOil") then
 206: 		LampService.notify(player, "You're already carrying oil. Take it to the fuel tank by the lighthouse.")
 207: 		return
 208: 	end
 209: 	giveOil(player)
 210: 	EventLog.mark(player, "firstAction")
 211: 	EventLog.count("oilGrabbed", 1, player)
 212: 	EventLog.first("oil pickup")
 213: 	EventLog.log("OilGrabbed", { player = player.Name })
 214: end)
 215: 
 216: refs.fuelPrompt.Triggered:Connect(function(player)
 217: 	if not player:GetAttribute("CarryingOil") then
 218: 		LampService.notify(player, "Grab oil from the barrels on the island first.")
 219: 		return
 220: 	end
 221: 	if LampService.getFuel() >= LampService.getMaxFuel() then
 222: 		LampService.notify(player, "The tank is already full.")
 223: 		return
 224: 	end
 225: 	local fuelBefore = LampService.getFuel()
 226: 	removeCarriedOil(player)
 227: 	LampService.addFuel(Config.FUEL_PER_REFILL)
 228: 	EventLog.count("refuels", 1, player)
 229: 	EventLog.first("lamp refuel")
 230: 	EventLog.log("Refueled", { player = player.Name, fuelBefore = math.floor(fuelBefore) })
 231: 	EventLog.mark(player, "fuel")
```

## Main.server.luau lines 498-533
```lua
 498: remotes.Attack.OnServerEvent:Connect(function(player, target)
 499: 	-- Validate everything the client sends
 500: 	if typeof(target) ~= "Vector3" or target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
 501: 		return
 502: 	end
 503: 	if LampService.getKeeper() == player then
 504: 		return
 505: 	end
 506: 	local character = player.Character
 507: 	local root = character and character:FindFirstChild("HumanoidRootPart")
 508: 	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 509: 	if not root or not humanoid or humanoid.Health <= 0 then
 510: 		return
 511: 	end
 512: 
 513: 	-- The server decides which weapon is used: whatever the player actually has equipped
 514: 	local tool = character:FindFirstChildOfClass("Tool")
 515: 	local weaponId = tool and tool:GetAttribute("WeaponId")
 516: 	local weapon = weaponId and Weapons[weaponId]
 517: 	if not weapon then
 518: 		return
 519: 	end
 520: 
 521: 	local now = os.clock()
 522: 	if (lastAttack[player] or 0) + weapon.cooldown > now then
 523: 		return
 524: 	end
 525: 	lastAttack[player] = now
 526: 
 527: 	-- Clamp to the weapon's range
 528: 	local offset = target - root.Position
 529: 	if offset.Magnitude > weapon.range then
 530: 		target = root.Position + offset.Unit * weapon.range
 531: 	end
 532: 
 533: 	local hits = CreatureService.damageArea(target, weapon.hitRadius, weapon.damage, weapon.maxTargets, "Weapon:" .. weaponId, player)
```

## Main.server.luau lines 545-555
```lua
 545: Players.PlayerRemoving:Connect(function(player)
 546: 	lastAttack[player] = nil
 547: 	lastBuy[player] = nil
 548: 	-- Playtest analytics: someone leaving in the middle of a run
 549: 	local phase = stateFolder:GetAttribute("Phase")
 550: 	EventLog.playerLeft(player, if not player:GetAttribute("InLobby") then "title" elseif not player:GetAttribute("Ready") then "harbor" else phase)
 551: 	if player:GetAttribute("Ready") and (phase == "Prologue" or phase == "Day" or phase == "Night") then
 552: 		EventLog.count("quits")
 553: 		EventLog.log("PlayerQuit", { player = player.Name, phase = phase, night = stateFolder:GetAttribute("Night") })
 554: 	end
 555: end)
```

## Main.server.luau lines 646-672
```lua
 646: local function joinCrew(player, via)
 647: 	local phase = stateFolder:GetAttribute("Phase")
 648: 	player:SetAttribute("Ready", true)
 649: 	EventLog.log("PlayerReady", { player = player.Name, via = via })
 650: 	EventLog.mark(player, "crew")
 651: 	if RUN_PHASES[phase] then
 652: 		LampService.notify(player, "You joined the crew mid-voyage! Rowing you to the island...")
 653: 		sendToIsland(player)
 654: 	else
 655: 		LampService.notify(player, if via == "first voyage" then "The storm is coming. The light needs a keeper: the ship sets sail soon." else "You joined the crew! The ship sets sail soon.")
 656: 	end
 657: end
 658: 
 659: -- The ship's wheel: join or leave the crew
 660: lobbyRefs.helmPrompt.Triggered:Connect(function(player)
 661: 	if not player:GetAttribute("InLobby") then
 662: 		return
 663: 	end
 664: 	local phase = stateFolder:GetAttribute("Phase")
 665: 	if player:GetAttribute("Ready") then
 666: 		player:SetAttribute("Ready", false)
 667: 		LampService.notify(player, "You left the crew. Use the wheel again to rejoin.")
 668: 		EventLog.log("LeftCrew", { player = player.Name })
 669: 	else
 670: 		joinCrew(player, "wheel")
 671: 	end
 672: end)
```

## LootService.luau lines 126-127
```lua
 126: 		if math.random() < Config.BOSS_PEARL_CHANCE then
 127: 			spawnDrop("Pearls", math.random(Config.BOSS_PEARL_MIN, Config.BOSS_PEARL_MAX), position)
```

## LootService.luau lines 150-160
```lua
 150: local function collect(index, player)
 151: 	local drop = drops[index]
 152: 	local info = KINDS[drop.kind]
 153: 	if info.pearls then
 154: 		-- Permanent currency straight into this player's saved Pearls
 155: 		playerData.addPearls(player, drop.value, "boss drop")
 156: 		EventLog.log("BossPearls", { player = player.Name, amount = drop.value })
 157: 		remotes.LootCollected:FireClient(player, drop.kind, drop.value)
 158: 		remotes.Notify:FireAllClients(string.format("%s picked up %d Pearls from the monster!", player.DisplayName, drop.value))
 159: 		removeAt(index)
 160: 		return
```

## LootService.luau lines 231-258
```lua
 231: 	-- Collect living players' positions once per frame
 232: 	local players = {}
 233: 	for _, player in Players:GetPlayers() do
 234: 		local character = player.Character
 235: 		local root = character and character:FindFirstChild("HumanoidRootPart")
 236: 		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 237: 		if root and humanoid and humanoid.Health > 0 then
 238: 			table.insert(players, { player = player, position = root.Position })
 239: 		end
 240: 	end
 241: 
 242: 	local now = os.clock()
 243: 	for index = #drops, 1, -1 do
 244: 		local drop = drops[index]
 245: 		if now - drop.bornAt > Config.LOOT_LIFETIME then
 246: 			removeAt(index)
 247: 		elseif drop.landed then
 248: 			-- Find the nearest player within magnet range
 249: 			local nearest, nearestDistance = nil, Config.LOOT_MAGNET_RADIUS
 250: 			for _, entry in players do
 251: 				local distance = (entry.position - drop.position).Magnitude
 252: 				if distance < nearestDistance then
 253: 					nearest, nearestDistance = entry, distance
 254: 				end
 255: 			end
 256: 
 257: 			if nearest and nearestDistance <= Config.LOOT_PICKUP_RADIUS then
 258: 				collect(index, nearest.player)
```

## TowerService.luau lines 26-38
```lua
  26: 	repairPrompt.Triggered:Connect(function(player)
  27: 		if integrity >= maxIntegrity then
  28: 			notify(player, "The tower is already in good shape.")
  29: 			return
  30: 		end
  31: 		-- evolution (Shared.Upgrades.EVOLUTIONS): Clockwork Bastion restores 50% more per repair
  32: 		TowerService.repair(Config.REPAIR_AMOUNT * (if state:GetAttribute("Evo_ClockworkBastion") then 1.5 else 1))
  33: 		EventLog.count("repairs", 1, player)
  34: 	EventLog.mark(player, "repair")
  35: 		EventLog.first("repair")
  36: 		EventLog.log("Repaired", { player = player.Name, integrity = math.ceil(integrity) })
  37: 		SoundFx.playAt("repair", repairPrompt.Parent.Position)
  38: 	end)
```

