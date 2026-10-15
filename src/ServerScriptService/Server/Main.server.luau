-- Main (server entry point): creates shared state and remotes, builds the island,
-- starts the services, wires up oil carrying, and starts the round loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local IslandBuilder = require(script.Parent.IslandBuilder)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local LampService = require(script.Parent.LampService)
local GameState = require(script.Parent.GameState)
local TowerService = require(script.Parent.TowerService)
local CreatureService = require(script.Parent.CreatureService)
local UpgradeService = require(script.Parent.UpgradeService)
local LootService = require(script.Parent.LootService)
local DefenseService = require(script.Parent.DefenseService)
local EventLog = require(script.Parent.EventLog)
local PlayerData = require(script.Parent.PlayerData)
local ShopService = require(script.Parent.ShopService)
local LoadoutService = require(script.Parent.LoadoutService)
local ShipRoster = require(script.Parent.ShipRoster)

-- Shared state the HUD reads (attributes replicate to every client automatically)
local stateFolder = Instance.new("Folder")
stateFolder.Name = "GameState"
stateFolder:SetAttribute("Phase", "Waiting")
stateFolder:SetAttribute("Night", 0)
stateFolder:SetAttribute("TimeLeft", 0)
stateFolder:SetAttribute("Fuel", Config.MAX_FUEL)
stateFolder:SetAttribute("DarkSeconds", 0)
stateFolder:SetAttribute("KeeperUserId", 0)
stateFolder:SetAttribute("Integrity", Config.MAX_INTEGRITY)
stateFolder:SetAttribute("BeamMode", "wide")
stateFolder:SetAttribute("Reason", "")
stateFolder:SetAttribute("Shells", 0)
stateFolder:SetAttribute("MaxFuel", Config.MAX_FUEL)
stateFolder:SetAttribute("MaxIntegrity", Config.MAX_INTEGRITY)
stateFolder.Parent = ReplicatedStorage

-- Client <-> server messages
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "BeamControl", "LampAction", "Notify", "Attack", "LootCollected", "OpenUpgrades", "BuyUpgrade", "ReportDevice", "PlaySound", "SetReady", "VoteRematch", "RunResults", "GearData", "GearAction", "ShopOpen", "ShopRequest", "ShopResult", "LoadoutRequest", "LoadoutResult", "EnterLobby", "Travel", "UpgradeResult", "TraderOpen", "TraderRequest", "TraderResult", "CrewFeed", "LampShift", "CoachEvent", "ForecastVote" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local refs = IslandBuilder.build()
local lobbyRefs = LobbyBuilder.build(refs) -- the pirate-ship lobby (also moves the Quartermaster aboard)
LampService.init(refs, stateFolder, remotes)
TowerService.init(stateFolder, refs.repairPrompt, LampService.notify)
PlayerData.init(remotes, LampService.notify)
ShopService.init(remotes, PlayerData, refs.shopCounter, refs.shopPrompt)
LoadoutService.init(remotes, PlayerData)
UpgradeService.init(stateFolder, LampService, TowerService)
CreatureService.init(refs, LampService, TowerService, UpgradeService, DefenseService, stateFolder)
LootService.init(refs.folder, UpgradeService, remotes, PlayerData)
CreatureService.onKilled = LootService.dropFrom
DefenseService.init(refs.folder, CreatureService, UpgradeService, function(text)
	remotes.Notify:FireAllClients(text)
end, LampService.notify)

-- Upgrade bench: open the upgrade panel for whoever uses it
refs.upgradePrompt.Triggered:Connect(function(player)
	remotes.OpenUpgrades:FireClient(player)
end)

-- Stripped-core playtest: remove the upgrade bench entirely
if not Config.ECONOMY_ENABLED then
	refs.upgradePrompt.Parent:Destroy()
	local benchTop = refs.folder:FindFirstChild("BenchTop")
	if benchTop then
		benchTop:Destroy()
	end
	-- no loot drops in this mode, so the Trader has nothing to buy: no prompt, no sheet
	refs.traderPrompt.Enabled = false
end

local lastBuy = {}

-- Title screen: Play / back to menu. Only Ready players take part in runs.
remotes.SetReady.OnServerEvent:Connect(function(player, ready)
	if typeof(ready) ~= "boolean" then
		return
	end
	if ready then
		return -- joining the crew now happens at the ship's wheel (see the lobby section below)
	end
	player:SetAttribute("Ready", false)
	EventLog.log("PlayerToMenu", { player = player.Name })
	if LampService.getKeeper() == player then
		LampService.setKeeper(nil, "leave")
	end
end)

-- Results screen: Play Again
remotes.VoteRematch.OnServerEvent:Connect(function(player)
	if player:GetAttribute("Ready") then
		player:SetAttribute("WantsRematch", true)
	end
end)

-- Each client reports its input type once (for the event log)
local VALID_DEVICES = { Touch = true, Keyboard = true, Gamepad = true }
remotes.ReportDevice.OnServerEvent:Connect(function(player, device)
	if VALID_DEVICES[device] then
		EventLog.setDevice(player, device)
	end
end)
-- requestId (optional, sent by the upgrade bench UI) gets a direct UpgradeResult reply
remotes.BuyUpgrade.OnServerEvent:Connect(function(player, id, requestId)
	if typeof(id) ~= "string" then
		return
	end
	if requestId ~= nil and (typeof(requestId) ~= "string" or #requestId > 40) then
		return
	end
	local now = os.clock()
	if (lastBuy[player] or 0) + 0.3 > now then
		if requestId then
			remotes.UpgradeResult:FireClient(player, requestId, false, "One upgrade at a time. Try again.", id)
		end
		return -- ignore double-clicks
	end
	lastBuy[player] = now
	local ok, message = UpgradeService.buy(id)
	if requestId then
		remotes.UpgradeResult:FireClient(player, requestId, ok, message, id)
	end
	if ok then
		EventLog.upgrade(id, UpgradeService.getLevel(id))
		EventLog.log("UpgradeBought", { player = player.Name, id = id, level = UpgradeService.getLevel(id) })
		local benchPart = refs.upgradePrompt.Parent
		if benchPart then
			SoundFx.playAt("build", benchPart.Position)
		end
		remotes.Notify:FireAllClients(player.DisplayName .. ": " .. message)
	elseif not requestId then
		LampService.notify(player, message) -- the bench UI shows the reason itself
	end
end)

---------------------------------------------------------------------
-- Oil carrying: grab a barrel from the pile, bring it to the fuel tank
---------------------------------------------------------------------

local function removeCarriedOil(player)
	player:SetAttribute("CarryingOil", false)
	local character = player.Character
	local barrel = character and character:FindFirstChild("CarriedOil")
	if barrel then
		barrel:Destroy()
	end
end

-- Cannons reload with the same oil barrels
DefenseService.setOilHandlers(function(player)
	return player:GetAttribute("CarryingOil") == true
end, removeCarriedOil)

-- ...or with ammo crates bought in the shop (used first if the player has any)
DefenseService.setCrateHandlers(function(player)
	for _, itemId in Items.SHOP_ORDER do
		local item = Items[itemId]
		if item.kind == "Ammo" and PlayerData.count(player, itemId) > 0 then
			return itemId, item.ammoType
		end
	end
	return nil
end, function(player, itemId)
	return PlayerData.removeItem(player, itemId, 1)
end)

local function giveOil(player)
	player:SetAttribute("CarryingOil", true)

	-- Visual: a small barrel strapped to the player's back
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local barrel = Instance.new("Part")
		barrel.Name = "CarriedOil"
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(2.2, 1.6, 1.6)
		barrel.Color = Color3.fromRGB(45, 40, 35)
		barrel.Material = Enum.Material.Metal
		barrel.CanCollide = false
		barrel.CanQuery = false
		barrel.Massless = true
		barrel.CFrame = root.CFrame * CFrame.new(0, 0, 1.3) * CFrame.Angles(0, 0, math.rad(90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = barrel
		weld.Parent = barrel
		barrel.Parent = character
	end
end

refs.oilPrompt.Triggered:Connect(function(player)
	if player:GetAttribute("CarryingOil") then
		LampService.notify(player, "You're already carrying oil. Take it to the fuel tank by the lighthouse.")
		return
	end
	giveOil(player)
	EventLog.mark(player, "firstAction")
	EventLog.count("oilGrabbed", 1, player)
	EventLog.first("oil pickup")
	EventLog.log("OilGrabbed", { player = player.Name })
end)

refs.fuelPrompt.Triggered:Connect(function(player)
	if not player:GetAttribute("CarryingOil") then
		LampService.notify(player, "Grab oil from the barrels on the island first.")
		return
	end
	if LampService.getFuel() >= LampService.getMaxFuel() then
		LampService.notify(player, "The tank is already full.")
		return
	end
	local fuelBefore = LampService.getFuel()
	removeCarriedOil(player)
	LampService.addFuel(Config.FUEL_PER_REFILL)
	EventLog.count("refuels", 1, player)
	EventLog.first("lamp refuel")
	EventLog.log("Refueled", { player = player.Name, fuelBefore = math.floor(fuelBefore) })
	EventLog.mark(player, "fuel")
	SoundFx.playAt("refuel", refs.fuelPrompt.Parent.Position)
	-- Crew feedback (launch R4): a feed line for the crew and a client-only flare. No gameplay values change.
	local clutch = fuelBefore < LampService.getMaxFuel() * 0.1 and stateFolder:GetAttribute("Phase") == "Night"
	if clutch then
		EventLog.count("clutchSaves", 1, player)
		EventLog.log("SavedTheLight", { player = player.Name, fuelBefore = math.floor(fuelBefore) })
		EventLog.moment(1, string.format("%s saved the light at %d%% fuel", player.DisplayName, math.max(0, math.floor(fuelBefore / LampService.getMaxFuel() * 100))))
	end
	if Config.CREW_FEED_ENABLED then
		local gained = math.floor((LampService.getFuel() - fuelBefore) / LampService.getMaxFuel() * 100 + 0.5)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Ready") then
				remotes.CrewFeed:FireClient(p, { kind = if clutch then "clutch" else "refuel", name = player.DisplayName, self = p == player, amount = gained })
			end
		end
	end
end)

local function onPlayerAdded(player)
	EventLog.playerJoined(player)
	player:SetAttribute("CarryingOil", false)
	player:SetAttribute("Ready", false) -- starts on the title screen
	player:SetAttribute("InLobby", false)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("CarryingOil", false)
		-- Everyone spawns on the ship. Crew members who die mid-run go straight back to the island.
		local phase = stateFolder:GetAttribute("Phase")
		if player:GetAttribute("Ready") and (phase == "Prologue" or phase == "Day" or phase == "Night") then
			task.delay(0.3, function()
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					character:PivotTo(lobbyRefs.islandArrival + Vector3.new(math.random(-4, 4), 3, math.random(-4, 4)))
				end
			end)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
	player:LoadCharacter() -- respawn anyone who loaded in before the island existed
end


---------------------------------------------------------------------
-- Weapons: everyone can fight on foot (much weaker than the beam)
---------------------------------------------------------------------

local ItemModels = ReplicatedStorage:WaitForChild("ItemModels")

-- Builds a weapon Tool from its 3D model in ReplicatedStorage.ItemModels.
-- The model's "Handle" part is what the character holds; every other part is welded to it.
local function buildWeaponTool(weaponId)
	local weapon = Weapons[weaponId]
	local item = Items[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = weapon.displayName
	tool.CanBeDropped = false
	tool.ToolTip = "Click or tap a creature"
	tool:SetAttribute("WeaponId", weaponId)

	local model = item and item.model and ItemModels:FindFirstChild(item.model)
	if model then
		local copy = model:Clone()
		local handle = copy.PrimaryPart
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
				if part ~= handle then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = part
					weld.Parent = part
				end
			end
		end
		for _, child in copy:GetChildren() do
			child.Parent = tool
		end
		copy:Destroy()
		handle.Name = "Handle"
	else
		-- Fallback if the model is missing: a plain stick
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.4, 0.4, 4.5)
		handle.Color = weapon.color
		handle.CanCollide = false
		handle.Massless = true
		handle.Parent = tool
	end
	return tool
end

-- Which weapon tools a player carries: just their equipped primary weapon
-- (or every weapon when the DEV_GIVE_ALL_WEAPONS testing switch is on).
local function weaponsFor(player)
	if Config.DEV_GIVE_ALL_WEAPONS then
		local list = {}
		for _, itemId in Items.SHOP_ORDER do
			if Weapons[itemId] then
				table.insert(list, itemId)
			end
		end
		return list
	end
	local profile = PlayerData.get(player)
	return { if profile then profile.equippedWeapon else Config.STARTER_WEAPON }
end

-- Puts the equipped armor model on the character's torso (purely visual; stats are applied separately)
local function wearArmor(character, itemId)
	local old = character:FindFirstChild("WornArmor")
	if old then
		old:Destroy()
	end
	local item = Items[itemId]
	local model = item and item.model and ItemModels:FindFirstChild(item.model)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not model or not torso then
		return
	end
	local worn = model:Clone()
	worn.Name = "WornArmor"
	local handle = worn.PrimaryPart
	-- Fit the armor's width to the torso, keeping its proportions
	local scale = (torso.Size.X * 1.18) / handle.Size.X
	for _, part in worn:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	handle.Size *= scale
	-- Top of the armor lines up with the top of the torso (the model faces -Z like the character)
	handle.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - handle.Size.Y / 2 + 0.15, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = handle
	weld.Parent = handle
	worn.Parent = character
end

-- Makes the player's tools and armor match their saved loadout.
-- Runs on spawn and whenever their profile changes (buying, equipping).
local function syncGear(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local wanted = {}
	for _, weaponId in weaponsFor(player) do
		wanted[weaponId] = true
	end
	-- Remove tools for weapons no longer equipped, and note which ones we already have
	local have = {}
	local equippedTool = character and character:FindFirstChildOfClass("Tool")
	local wasHolding = equippedTool ~= nil
	for _, container in { backpack, character } do
		if container then
			for _, tool in container:GetChildren() do
				local id = tool:IsA("Tool") and tool:GetAttribute("WeaponId")
				if id then
					if wanted[id] then
						have[id] = true
					else
						tool:Destroy()
					end
				end
			end
		end
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	for weaponId in wanted do
		if not have[weaponId] then
			local tool = buildWeaponTool(weaponId)
			tool.Parent = backpack
			-- if they were holding the old weapon, hand them the new one
			if wasHolding and humanoid and LampService.getKeeper() ~= player then
				humanoid:EquipTool(tool)
			end
		end
	end

	-- Armor: max health + damage reduction, and the visible model on the character
	local profile = PlayerData.get(player)
	local armor = profile and Items[profile.equippedArmor]
	if humanoid and armor then
		local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = armor.maxHealth
		humanoid.Health = math.max(1, armor.maxHealth * ratio)
		player:SetAttribute("DamageReduction", armor.damageReduction)
		player:SetAttribute("ArmorName", armor.name)
		if character:GetAttribute("WornArmorId") ~= profile.equippedArmor then
			character:SetAttribute("WornArmorId", profile.equippedArmor)
			wearArmor(character, profile.equippedArmor)
		end
	end
end
PlayerData.onChanged = syncGear

local function giveWeapons(player, character)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	character:WaitForChild("Humanoid", 5)
	syncGear(player)
	-- Equip the first weapon automatically so new players can fight right away
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local first = backpack:FindFirstChildOfClass("Tool")
	if humanoid and first and LampService.getKeeper() ~= player then
		humanoid:EquipTool(first)
	end
end

-- Projectile visuals (cosmetic only; damage is decided on the server before this plays)
local function showProjectile(weapon, from, to)
	local shot = Instance.new("Part")
	shot.Anchored = true
	shot.CanCollide = false
	shot.CanQuery = false
	shot.CanTouch = false
	shot.Color = weapon.color
	if weapon.projectile == "flare" then
		shot.Shape = Enum.PartType.Ball
		shot.Size = Vector3.new(1, 1, 1)
		shot.Material = Enum.Material.Neon
	else
		shot.Size = Vector3.new(0.3, 0.3, 3)
		shot.Material = Enum.Material.Metal
	end
	shot.CFrame = CFrame.lookAt(from, to)
	shot.Parent = refs.folder
	SoundFx.playOn("throw", shot)

	local travel = TweenService:Create(shot, TweenInfo.new(0.15, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) })
	travel.Completed:Connect(function()
		if weapon.projectile == "flare" then
			-- burst showing the area it hit
			local burst = TweenService:Create(shot, TweenInfo.new(0.3), {
				Size = Vector3.new(weapon.hitRadius * 2, weapon.hitRadius * 2, weapon.hitRadius * 2),
				Transparency = 1,
			})
			burst.Completed:Connect(function()
				shot:Destroy()
			end)
			burst:Play()
		else
			task.delay(0.3, function()
				shot:Destroy()
			end)
		end
	end)
	travel:Play()
end

local lastAttack = {}

remotes.Attack.OnServerEvent:Connect(function(player, target)
	-- Validate everything the client sends
	if typeof(target) ~= "Vector3" or target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
		return
	end
	if LampService.getKeeper() == player then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- The server decides which weapon is used: whatever the player actually has equipped
	local tool = character:FindFirstChildOfClass("Tool")
	local weaponId = tool and tool:GetAttribute("WeaponId")
	local weapon = weaponId and Weapons[weaponId]
	if not weapon then
		return
	end

	local now = os.clock()
	if (lastAttack[player] or 0) + weapon.cooldown > now then
		return
	end
	lastAttack[player] = now

	-- Clamp to the weapon's range
	local offset = target - root.Position
	if offset.Magnitude > weapon.range then
		target = root.Position + offset.Unit * weapon.range
	end

	local hits = CreatureService.damageArea(target, weapon.hitRadius, weapon.damage, weapon.maxTargets, "Weapon:" .. weaponId, player)
	EventLog.count("attacks")
	EventLog.first("harpoon attack")
	EventLog.mark(player, "firstAction")
	if #hits > 0 then
		EventLog.mark(player, "strike")
		EventLog.count("attackHits")
		SoundFx.playAt("hit", hits[1])
	end
	showProjectile(weapon, root.Position + Vector3.new(0, 1.5, 0), hits[1] or target)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
	lastBuy[player] = nil
	-- Playtest analytics: someone leaving in the middle of a run
	local phase = stateFolder:GetAttribute("Phase")
	EventLog.playerLeft(player, if not player:GetAttribute("InLobby") then "title" elseif not player:GetAttribute("Ready") then "harbor" else phase)
	if player:GetAttribute("Ready") and (phase == "Prologue" or phase == "Day" or phase == "Night") then
		EventLog.count("quits")
		EventLog.log("PlayerQuit", { player = player.Name, phase = phase, night = stateFolder:GetAttribute("Night") })
	end
end)

local function hookWeapons(player)
	player.CharacterAdded:Connect(function(character)
		giveWeapons(player, character)
	end)
	if player.Character then
		task.spawn(giveWeapons, player, player.Character)
	end
end
Players.PlayerAdded:Connect(hookWeapons)
for _, player in Players:GetPlayers() do
	hookWeapons(player)
end

---------------------------------------------------------------------
-- Lobby ship: getting from the deck to the island and back
---------------------------------------------------------------------

local RUN_PHASES = { Prologue = true, Day = true, Night = true }

local function moveCharacterTo(player, target)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		remotes.Travel:FireClient(player) -- short fade on their screen
		task.wait(0.35)
		character:PivotTo(target + Vector3.new(math.random(-4, 4), 3, math.random(-4, 4)))
	end
end

local function sendToIsland(player)
	task.spawn(function()
		moveCharacterTo(player, lobbyRefs.islandArrival)
		EventLog.mark(player, "landed")
	end)
end

local function sendToShip(player)
	removeCarriedOil(player)
	if LampService.getKeeper() == player then
		LampService.setKeeper(nil, "leave")
	end
	task.spawn(moveCharacterTo, player, lobbyRefs.spawn.CFrame)
end

-- Coach prompts (launch R3) report shown/done for the playtest log. Known ids only, rate limited.
local COACH_IDS = { oil = true, tank = true, lamp = true, aim = true, focus = true, repair = true, bench = true }
local coachBudget = {} -- player -> events left this session
remotes.CoachEvent.OnServerEvent:Connect(function(player, kind, id)
	if (kind ~= "shown" and kind ~= "done") or not COACH_IDS[id] then
		return
	end
	local left = coachBudget[player] or 60
	if left <= 0 then
		return
	end
	coachBudget[player] = left - 1
	EventLog.mark(player, (if kind == "shown" then "promptShown:" else "promptDone:") .. id)
end)
Players.PlayerRemoving:Connect(function(player)
	coachBudget[player] = nil
end)

-- Storm forecast vote (launch R9): crew members pick one of the two offered forecasts before sailing
remotes.ForecastVote.OnServerEvent:Connect(function(player, choice)
	local phase = stateFolder:GetAttribute("Phase")
	if not player:GetAttribute("Ready") or (phase ~= "Waiting" and phase ~= "Intermission") then
		return
	end
	if choice ~= stateFolder:GetAttribute("ForecastA") and choice ~= stateFolder:GetAttribute("ForecastB") then
		return
	end
	player:SetAttribute("ForecastVote", choice)
end)

-- Title screen "Play": you're now on the ship
remotes.EnterLobby.OnServerEvent:Connect(function(player)
	if not player:GetAttribute("InLobby") then
		player:SetAttribute("InLobby", true)
		EventLog.log("EnteredLobby", { player = player.Name })
	end
end)

-- Results screen "Main Menu" (or leaving the crew): back to the ship
remotes.SetReady.OnServerEvent:Connect(function(player, ready)
	if ready == false then
		sendToShip(player)
	end
end)

-- Ship parties (batch 1 revision): the lobby holds the whole server; each departure ship takes a party of at
-- most Config.MAX_CREW. ShipRoster is the only thing that puts a player in a crew (Ready = true).
local SHIP_ID = "Ship1" -- the existing pirate ship
ShipRoster.init(stateFolder, Config.MAX_CREW or 4, { SHIP_ID })

-- Joining a ship's party at its wheel. Returns false if the party is full or the ship has sailed.
local function joinCrew(player, via)
	local ok, reason = ShipRoster.join(player, SHIP_ID)
	if not ok then
		LampService.notify(player, if reason == "full"
			then string.format("This ship's crew is full (%d of %d). Wait on deck: you can join the next voyage.", ShipRoster.CAPACITY, ShipRoster.CAPACITY)
			else "The ship has sailed with its crew. Wait on deck for the next voyage.")
		EventLog.log("CrewRefused", { player = player.Name, via = via, reason = reason, ship = SHIP_ID })
		return false
	end
	if reason == "joined" then
		EventLog.log("PlayerReady", { player = player.Name, via = via, ship = SHIP_ID })
		EventLog.mark(player, "crew")
		LampService.notify(player, "You joined the crew! The ship sets sail soon.")
	end
	return true
end

-- The ship's wheel: join or leave this ship's party
lobbyRefs.helmPrompt.Triggered:Connect(function(player)
	if not player:GetAttribute("InLobby") then
		return
	end
	if ShipRoster.shipOf(player) == SHIP_ID then
		ShipRoster.leave(player, "wheel")
		LampService.notify(player, "You left the crew. Use the wheel again to rejoin.")
		EventLog.log("LeftCrew", { player = player.Name, ship = SHIP_ID })
	else
		joinCrew(player, "wheel")
	end
end)

-- First-voyage route (launch R2). A player whose profile loaded cleanly with 0 completed runs skips
-- the title and lands on the ship's deck, where the wheel signs them up (batch 1 revision: they are no
-- longer put in a crew automatically). Everyone else gets the
-- title. A failed or slow profile load ALWAYS gets the title: never guess someone is new.
-- The client waits for the Route attribute before showing anything.
local function chooseRoute(player)
	local started = os.clock()
	while player.Parent == Players and player:GetAttribute("ProfileState") == nil and os.clock() - started < 6 do
		task.wait(0.2)
	end
	if player.Parent ~= Players then
		return
	end
	local profileState = player:GetAttribute("ProfileState")
	local fast = Config.FIRST_VOYAGE_FAST_PATH == true
		and (profileState == "saved" or profileState == "memory")
		and player:GetAttribute("RunsCompleted") == 0
		and not player:GetAttribute("InLobby")
	EventLog.setRoute(player, if fast then "fast" elseif profileState == "failed" then "failed-load" elseif profileState == nil then "slow-load" else "title")
	if not fast then
		player:SetAttribute("Route", "title")
		return
	end
	-- wait for a character so the crew can be rowed out
	while player.Parent == Players and not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() - started < 20 do
		task.wait(0.2)
	end
	if player.Parent ~= Players then
		return
	end
	player:SetAttribute("Route", "fast")
	player:SetAttribute("InLobby", true)
	EventLog.log("EnteredLobby", { player = player.Name, via = "first voyage" })
	task.wait(0.4)
	if player.Parent == Players and not player:GetAttribute("Ready") then
		LampService.notify(player, "The storm is coming and the light needs keepers. Use the SHIP'S WHEEL to join the crew.")
	end
end
Players.PlayerAdded:Connect(function(player)
	task.spawn(chooseRoute, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(chooseRoute, player)
end

-- Keep a live count of the crew for the ship's status banner
task.spawn(function()
	while true do
		local crew, aboard = 0, 0
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Ready") then
				crew += 1
			elseif player:GetAttribute("InLobby") then
				aboard += 1
			end
		end
		stateFolder:SetAttribute("CrewCount", crew)
		stateFolder:SetAttribute("AboardCount", aboard)
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------
-- The Trader (lighthouse island): sells all of a player's loot for crew shells
---------------------------------------------------------------------

-- The prompt opens the Trader's panel (client); selling is a request the server checks.
-- Returns ok, message, shells paid.
local function sellAllLoot(player)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Your data is still loading. Try again in a moment.", 0
	end
	-- Work out the value first, then clear (clearRunLoot removes exactly the run-scoped loot)
	local removed = PlayerData.clearRunLoot(player)
	if #removed == 0 then
		return false, "Nothing to sell. Bring claws, sea glass or pearls from the creatures.", 0
	end
	local total, parts = 0, {}
	for _, entry in removed do
		local item = Items[entry[1]]
		total += (item.shellValue or 0) * entry[2]
		table.insert(parts, string.format("%d %s", entry[2], item.name))
	end
	UpgradeService.addShells(total)
	SoundFx.playAt("build", refs.traderPrompt.Parent.Position)
	remotes.Notify:FireAllClients(string.format("%s sold %s to the Trader for %d shells!", player.DisplayName, table.concat(parts, ", "), total))
	EventLog.log("SoldLoot", { player = player.Name, shells = total })
	EventLog.count("lootSold", total) -- for the results screen
	return true, string.format("Sold for %d Shells.", total), total
end

-- Beam colour cosmetics (launch R15): the lamp takes the Keeper's equipped colour
LampService.colorFor = function(player)
	local profile = PlayerData.get(player)
	local item = profile and Items[profile.equippedBeam]
	if item and item.beamColor then
		return Color3.fromRGB(item.beamColor[1], item.beamColor[2], item.beamColor[3])
	end
	return nil
end

-- launch R10 (owner: keep OFF until Test B): with Config.AUTO_SELL_LOOT, each crew member's carried
-- loot sells itself at dawn at the same Trader values. GameState calls this after a night is survived.
local function autoSellAtDawn()
	if not (Config.AUTO_SELL_LOOT and Config.ECONOMY_ENABLED) then
		return
	end
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Ready") then
			sellAllLoot(player)
		end
	end
end

local TRADER_RANGE = refs.traderPrompt.MaxActivationDistance + 6
local traderHandled = {} -- player -> { id, ok, message, total } (a repeated request gets the same answer)
local lastTrade = {}

refs.traderPrompt.Triggered:Connect(function(player)
	if not player:GetAttribute("Ready") then
		return
	end
	PlayerData.resync(player) -- fresh loot counts for the panel
	remotes.TraderOpen:FireClient(player)
end)

remotes.TraderRequest.OnServerEvent:Connect(function(player, requestId, action)
	if typeof(requestId) ~= "string" or #requestId == 0 or #requestId > 40 or action ~= "sellAll" then
		return
	end
	local memory = traderHandled[player]
	if memory and memory.id == requestId then
		remotes.TraderResult:FireClient(player, requestId, memory.ok, memory.message, memory.total)
		return
	end
	local now = os.clock()
	if (lastTrade[player] or 0) + 0.3 > now then
		remotes.TraderResult:FireClient(player, requestId, false, "One trade at a time. Try again.", 0)
		return
	end
	lastTrade[player] = now
	local ok, message, total
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not player:GetAttribute("Ready") then
		ok, message, total = false, "The Trader only buys from the crew during a voyage.", 0
	elseif not root or (root.Position - refs.traderPrompt.Parent.Position).Magnitude > TRADER_RANGE then
		ok, message, total = false, "You're too far from the Trader.", 0
	else
		ok, message, total = sellAllLoot(player)
	end
	traderHandled[player] = { id = requestId, ok = ok, message = message, total = total }
	if not ok then
		PlayerData.resync(player)
	end
	remotes.TraderResult:FireClient(player, requestId, ok, message, total)
end)

Players.PlayerRemoving:Connect(function(player)
	traderHandled[player] = nil
	lastTrade[player] = nil
end)

local function resetRound()
	-- Loot from the last voyage is gone, just like shells
	for _, player in Players:GetPlayers() do
		PlayerData.clearRunLoot(player)
	end
	LampService.reset()
	TowerService.reset()
	UpgradeService.reset()
	DefenseService.reset()
	CreatureService.clearAll()
	LootService.clearAll()
	for _, player in Players:GetPlayers() do
		removeCarriedOil(player)
	end
end

GameState.run({
	lamp = LampService,
	tower = TowerService,
	creatures = CreatureService,
	playerData = PlayerData,
	sendToIsland = sendToIsland,
	sendToShip = sendToShip,
	loot = LootService,
	upgrades = UpgradeService,
	state = stateFolder,
	remotes = remotes,
	resetRound = resetRound,
	departShip = function()
		return ShipRoster.depart(SHIP_ID) -- freezes the party; only these players sail
	end,
	lampVisuals = LampService.refreshVisuals,
	autoSell = autoSellAtDawn,
})
