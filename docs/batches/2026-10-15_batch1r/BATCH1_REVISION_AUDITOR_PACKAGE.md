# LIGHTHOUSE KEEPERS - BATCH 1 REVISION AUDITOR PACKAGE (per-ship crew roster)

Target: Lighthouse Keepers (PlaceId 132065051336560, GameId 10769064643), Studio only, NOT published. No save, PlayerData, price or balance changes.

## Contents
1. BATCH1_REVISION_REPORT.md (6589 bytes, SHA-256 74a2dd9b59d9b443f2e693525f440d327355ddb87a7af98b9007ca28476dd1b7)
2. CODE_DIFFS.diff (12614 bytes, SHA-256 9407a38b75efe9ff16c273cb7295a417e125c076ed241be91df74f6507a28945)

=== FILE: docs/batches/2026-10-15_batch1r/BATCH1_REVISION_REPORT.md ===
# Lighthouse Keepers: batch 1 revision (per-ship crew roster)

- **Target:** Lighthouse Keepers, PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.**
- **Responds to:** the auditor's batch 1 verdict, which asked for these changes.
- **Kept from batch 1:** the controller, phone and held-aim changes are unchanged and were re-tested.

## What changed
| Before (batch 1) | After (revision) |
|---|---|
| A global cap: at most 4 Ready players on the whole server | **The lobby holds the whole server** (Roblox Max Players stays 60). Each **departure ship** has its own party of at most 4 (`Config.MAX_CREW`). |
| Being in a crew was just `Ready = true` | **`ShipRoster`** (new server module) is the only thing that puts a player in a crew. Each player is in at most one party, recorded in the `ShipId` attribute; the existing ship is `Ship1`. The roster keeps `Ready` in step, so the existing game loop keeps working. |
| First-time players were auto-joined to the crew | First-timers still skip the title and land on the ship's deck, but they are **not** registered. They get "Use the SHIP'S WHEEL to join the crew", and the existing harbor card says the same. |
| Mid-voyage join rowed you to the island | **Party frozen at departure:** `GameState` calls `ShipRoster.depart("Ship1")` when the countdown ends, and only that frozen list sails. Joins are refused ("The ship has sailed…") until the ship is back in port (Phase `Waiting`). |
| Leaving or disconnecting only cleared `Ready` | Every exit frees the seat through one path: the wheel, the menu, results or rematch "no", or a disconnect. Switching parties is handled too: joining another ship leaves the current one first. |
| Fuel counted Ready players | Unchanged rule. Because only the frozen departing party is Ready during a voyage, **lobby players never count**. |
| Crew card showed "YOUR CREW · n" | It shows "YOUR CREW · n/4". |

**Not touched:** PlayerData or the save format, prices, balance, SaveTest, Outlaw City, and the Roblox server size.

## Scripts (SHA-256, equal in Studio and in `after\`; all compile)
| Script | SHA-256 |
|---|---|
| `ServerScriptService.Server.ShipRoster` (**new**) | `eb09d93464bd47c4cf4ddd44d7ec44ef097ac464b45e7e2a93a96508390945b0` |
| `ServerScriptService.Server.Main` | `993e13fce7554246097cfc7cbc901b3282f01f85716d4b45c44cb57e023a1ce1` |
| `ServerScriptService.Server.GameState` | `c409beb5e286a42ea36f9b4e828405077a13ca975ef398a9d28d24e91cded43d` |
| `ReplicatedStorage.Shared.Config` (comment only) | `a572a4c313196df0214bf503d8fd3eb900e0d859b115fd1f58d3ef8940b93adc` |
| `StarterPlayerScripts.Client.Departure` | `391ad4105ccad8369807d3bcb7f9246cdfb9d497174f3613f53448b4f1e16390` |

**Rollback options:**
- `ServerStorage.Backups.Batch1r_before_2026-10-15`, then delete `ShipRoster`;
- or the `before\` files;
- or the place backup `backups\2026-10-15\LighthouseKeepers_2026-10-15_v155_pre-batch1r.rbxl`: 810,901 bytes, SHA-256 `DBCB1C97BC576162AE1D6DAA57846C951A130087CF2B77F8E9CBB4235061F9CB`, saved by the owner.

## Tests
API access was checked **OFF** immediately before Play ("Studio access to APIs is not allowed"), and PlayerData ran in memory only.

**Roster unit test: 10 of 10 PASS.** It ran in Edit mode on a fresh copy of `ShipRoster` with 6 stand-in players; everything was removed afterwards.

| Check | Result |
|---|---|
| 4 register for Ship1 | PASS |
| 5th refused "full", not crew | PASS |
| Leaving frees a seat | PASS |
| The 5th then takes the freed seat | PASS |
| Departure returns exactly the 4 members | PASS |
| Nobody joins after departure | PASS |
| A mid-voyage leaver cannot rejoin before port | PASS |
| Back in port the ship unlocks | PASS |
| After port, a new player joins the free seat | PASS |
| A disconnected member no longer counts | PASS |

A first run had 3 failures. These were a test bug: the phase was set to "Waiting" twice, so no change fired. With the real Waiting → Prologue → Waiting sequence, all checks passed.

**Studio Play (one player)**

| Check | Result |
|---|---|
| First-timer lands on deck with Ready=false and no ShipId; count 0/4 | PASS |
| Wheel join | PASS: `PlayerReady ship=Ship1 via=wheel`; card "YOUR CREW · 1/4" |
| Departure | PASS: Phase Prologue, `Ship_Ship1_Locked = true` |
| Leave from the menu mid-voyage | PASS: Ready false, ShipId cleared, count 0. With no crew left the run was abandoned, so the ship returned to port and unlocked, as designed. |
| Batch 1 regression | PASS: Keeper Y → focused, B → left the lamp; phone joystick stays hidden after a menu closes |
| Console | no game errors |

**Not possible here:** tests with 5 or more real clients and lobby spectators during a night. MCP Play gives one client. The owner should run the local multiplayer test below.

## Owner multiplayer test (Server & Clients, 6 players)
1. All 6 stay in the lobby.
2. 4 use the wheel and are in. The 5th gets "This ship's crew is full (4 of 4)" and stays on deck.
3. One of the 4 leaves at the wheel, and the 5th can now join. Closing one client also frees a seat.
4. Only the 4 registered players are moved to the island. The 2 on deck stay.
5. During a night, fuel drain matches a crew of 4, not 6.
6. A first-timer is not counted as crew until they use the wheel.

## Future simultaneous voyages: isolation still needed (not implemented)
- `GameState` runs one global loop with one `GameState` folder: Phase, Night, Fuel, KeeperUserId, BeamMode and so on. Each voyage needs its own state folder and loop instance, keyed by ShipId and IslandId.
- These services are singletons with module-level state: `LampService`, `TowerService`, `CreatureService`, `LootService`, `UpgradeService`, `DefenseService`. Each needs per-island instances, or state tables keyed by island.
- `IslandBuilder` builds one `workspace.Island`. A second island needs its own model and position.
- `readyPlayers()` and the fuel crew count read the `Ready` attribute server-wide. They should read `ShipRoster.members(shipId)` for their own voyage.
- Clients read global attributes, so the HUD, Coach and Departure scripts would need the player's voyage state folder.
- `EventLog` assumes one run at a time.

## Remaining limitations
- A member who leaves mid-voyage can rejoin only after the ship returns to port. This follows the freeze rule; previously they could rejoin mid-voyage.
- The owner reported thumbstick aiming as working in batch 1 ("All working"). That code is unchanged here.

## Publication recommendation
Ready for manual publish **after the owner's 6-player check above passes**.
=== END FILE ===

=== FILE: docs/batches/2026-10-15_batch1r/CODE_DIFFS.diff ===
```diff
--- before/ReplicatedStorage_Shared_Config.luau
+++ after/ReplicatedStorage_Shared_Config.luau
@@ -46,7 +46,7 @@
 	FUEL_DRAIN_PER_SECOND = 1.2, -- only drains at night; a full tank lasts ~80 s on the wide beam
 	FUEL_PER_REFILL = 40, -- one barrel of oil
 	FUEL_DRAIN_BY_CREW_SIZE = { 0.7, 0.85, 1, 1 }, -- drain multiplier for 1, 2, 3, 4 players (solo can't refuel and keep the lamp at once)
-	MAX_CREW = 4, -- batch 1: at most 4 Keepers sail together; anyone else waits on the ship for the next voyage
+	MAX_CREW = 4, -- party size of ONE departure ship (batch 1 revision); the lobby itself holds the whole server
 	DAWN_LOOT_SECONDS = 25, -- leftover loot stays this long into the day at full value (was 10; owner, Oct 12)
 	DAWN_LOOT_FRACTION = 0.5, -- at dawn the tide brings leftover loot to the crew at this fraction of its value
 	DARK_GRACE_SECONDS = 10, -- how long the lamp can be out before the run is lost
--- before/ServerScriptService_Server_GameState.luau
+++ after/ServerScriptService_Server_GameState.luau
@@ -334,9 +334,11 @@
 			end
 		end
 		if countdown(Config.INTERMISSION_SECONDS, noPlayers) then
+			-- Departure (batch 1 revision): the ship's party is frozen here and only those players sail
+			local departing = if deps.departShip then deps.departShip() else readyPlayers()
 			deps.resetRound()
-			local forecast, votesA, votesB = chooseForecast(readyPlayers())
-			EventLog.startRun(readyPlayers())
+			local forecast, votesA, votesB = chooseForecast(departing)
+			EventLog.startRun(departing)
 			if forecast then
 				EventLog.setForecast(forecast)
 				EventLog.log("Forecast", { id = forecast, votesA = votesA, votesB = votesB, a = state:GetAttribute("ForecastA"), b = state:GetAttribute("ForecastB") })
@@ -346,7 +348,7 @@
 				task.delay(1.2, notifyAll, "Forecast: " .. Forecasts[forecast].displayName .. ". " .. Forecasts[forecast].summary)
 			end
 			-- The crew sails from the ship to the lighthouse island
-			for _, player in readyPlayers() do
+			for _, player in departing do
 				deps.sendToIsland(player)
 			end
 			task.wait(0.6)
--- before/ServerScriptService_Server_Main.server.luau
+++ after/ServerScriptService_Server_Main.server.luau
@@ -22,6 +22,7 @@
 local PlayerData = require(script.Parent.PlayerData)
 local ShopService = require(script.Parent.ShopService)
 local LoadoutService = require(script.Parent.LoadoutService)
+local ShipRoster = require(script.Parent.ShipRoster)
 
 -- Shared state the HUD reads (attributes replicate to every client automatically)
 local stateFolder = Instance.new("Folder")
@@ -642,54 +643,46 @@
 	end
 end)
 
--- Crew cap (batch 1): at most Config.MAX_CREW players sail; anyone else waits on the ship
-local function crewIsFull(player)
-	local n = 0
-	for _, p in Players:GetPlayers() do
-		if p ~= player and p:GetAttribute("Ready") then
-			n += 1
-		end
-	end
-	return n >= (Config.MAX_CREW or 4)
-end
+-- Ship parties (batch 1 revision): the lobby holds the whole server; each departure ship takes a party of at
+-- most Config.MAX_CREW. ShipRoster is the only thing that puts a player in a crew (Ready = true).
+local SHIP_ID = "Ship1" -- the existing pirate ship
+ShipRoster.init(stateFolder, Config.MAX_CREW or 4, { SHIP_ID })
 
--- Joining the crew (ship's wheel, or automatically on a first voyage). Returns false if the crew is full.
+-- Joining a ship's party at its wheel. Returns false if the party is full or the ship has sailed.
 local function joinCrew(player, via)
-	local phase = stateFolder:GetAttribute("Phase")
-	if crewIsFull(player) then
-		LampService.notify(player, string.format("The crew is full (%d Keepers). Wait on the ship: you can join the next voyage.", Config.MAX_CREW or 4))
-		EventLog.log("CrewFull", { player = player.Name, via = via })
+	local ok, reason = ShipRoster.join(player, SHIP_ID)
+	if not ok then
+		LampService.notify(player, if reason == "full"
+			then string.format("This ship's crew is full (%d of %d). Wait on deck: you can join the next voyage.", ShipRoster.CAPACITY, ShipRoster.CAPACITY)
+			else "The ship has sailed with its crew. Wait on deck for the next voyage.")
+		EventLog.log("CrewRefused", { player = player.Name, via = via, reason = reason, ship = SHIP_ID })
 		return false
 	end
-	player:SetAttribute("Ready", true)
-	EventLog.log("PlayerReady", { player = player.Name, via = via })
-	EventLog.mark(player, "crew")
-	if RUN_PHASES[phase] then
-		LampService.notify(player, "You joined the crew mid-voyage! Rowing you to the island...")
-		sendToIsland(player)
-	else
-		LampService.notify(player, if via == "first voyage" then "The storm is coming. The light needs a keeper: the ship sets sail soon." else "You joined the crew! The ship sets sail soon.")
+	if reason == "joined" then
+		EventLog.log("PlayerReady", { player = player.Name, via = via, ship = SHIP_ID })
+		EventLog.mark(player, "crew")
+		LampService.notify(player, "You joined the crew! The ship sets sail soon.")
 	end
 	return true
 end
 
--- The ship's wheel: join or leave the crew
+-- The ship's wheel: join or leave this ship's party
 lobbyRefs.helmPrompt.Triggered:Connect(function(player)
 	if not player:GetAttribute("InLobby") then
 		return
 	end
-	local phase = stateFolder:GetAttribute("Phase")
-	if player:GetAttribute("Ready") then
-		player:SetAttribute("Ready", false)
+	if ShipRoster.shipOf(player) == SHIP_ID then
+		ShipRoster.leave(player, "wheel")
 		LampService.notify(player, "You left the crew. Use the wheel again to rejoin.")
-		EventLog.log("LeftCrew", { player = player.Name })
+		EventLog.log("LeftCrew", { player = player.Name, ship = SHIP_ID })
 	else
 		joinCrew(player, "wheel")
 	end
 end)
 
 -- First-voyage route (launch R2). A player whose profile loaded cleanly with 0 completed runs skips
--- the title and joins the crew at once (mid-voyage if a run is underway). Everyone else gets the
+-- the title and lands on the ship's deck, where the wheel signs them up (batch 1 revision: they are no
+-- longer put in a crew automatically). Everyone else gets the
 -- title. A failed or slow profile load ALWAYS gets the title: never guess someone is new.
 -- The client waits for the Route attribute before showing anything.
 local function chooseRoute(player)
@@ -705,7 +698,6 @@
 		and (profileState == "saved" or profileState == "memory")
 		and player:GetAttribute("RunsCompleted") == 0
 		and not player:GetAttribute("InLobby")
-		and not crewIsFull(player) -- batch 1: a full crew sends a first-timer to the title instead
 	EventLog.setRoute(player, if fast then "fast" elseif profileState == "failed" then "failed-load" elseif profileState == nil then "slow-load" else "title")
 	if not fast then
 		player:SetAttribute("Route", "title")
@@ -723,7 +715,7 @@
 	EventLog.log("EnteredLobby", { player = player.Name, via = "first voyage" })
 	task.wait(0.4)
 	if player.Parent == Players and not player:GetAttribute("Ready") then
-		joinCrew(player, "first voyage")
+		LampService.notify(player, "The storm is coming and the light needs keepers. Use the SHIP'S WHEEL to join the crew.")
 	end
 end
 Players.PlayerAdded:Connect(function(player)
@@ -880,6 +872,9 @@
 	state = stateFolder,
 	remotes = remotes,
 	resetRound = resetRound,
+	departShip = function()
+		return ShipRoster.depart(SHIP_ID) -- freezes the party; only these players sail
+	end,
 	lampVisuals = LampService.refreshVisuals,
 	autoSell = autoSellAtDawn,
 })
--- /dev/null
+++ after/ServerScriptService_Server_ShipRoster.luau
@@ -0,0 +1,145 @@
+-- ShipRoster (batch 1 revision): the server-authoritative party roster for each departure ship.
+--
+-- The lobby holds as many players as the Roblox server allows. Only a ship's PARTY sails, and a party has at most
+-- CAPACITY members (Config.MAX_CREW, 4). Party membership is the only thing that makes a player crew:
+-- join() is the one place that sets the "Ready" attribute to true, and a player is always in at most one party
+-- (player attribute "ShipId"). When a ship departs its party is frozen (locked) until the ship is back in port
+-- (game Phase "Waiting"); nobody can join a ship that has sailed.
+--
+-- Today there is one ship ("Ship1", the existing pirate ship) and one voyage at a time. GameState still reads
+-- the crew through the Ready attribute, which this module keeps in step with the roster.
+
+local Players = game:GetService("Players")
+
+local ShipRoster = {}
+ShipRoster.CAPACITY = 4
+
+local ships = {} -- shipId -> { id, members = { [player] = joinedAt }, locked = false }
+local state = nil
+
+local function memberList(ship)
+	local list = {}
+	for p in ship.members do
+		if p.Parent == Players then
+			table.insert(list, p)
+		end
+	end
+	table.sort(list, function(a, b)
+		return ship.members[a] < ship.members[b]
+	end)
+	return list
+end
+
+local function publish(ship)
+	if state then
+		state:SetAttribute("Ship_" .. ship.id .. "_Count", #memberList(ship))
+		state:SetAttribute("Ship_" .. ship.id .. "_Locked", ship.locked)
+	end
+end
+
+function ShipRoster.init(stateFolder, capacity, shipIds)
+	state = stateFolder
+	ShipRoster.CAPACITY = capacity or ShipRoster.CAPACITY
+	state:SetAttribute("ShipCapacity", ShipRoster.CAPACITY)
+	for _, id in shipIds do
+		ships[id] = { id = id, members = {}, locked = false }
+		publish(ships[id])
+	end
+	-- anything that drops a player out of the crew (menu, results screen, rematch "no") also frees the seat
+	local function watch(player)
+		player:GetAttributeChangedSignal("Ready"):Connect(function()
+			if player:GetAttribute("Ready") ~= true and player:GetAttribute("ShipId") ~= nil then
+				ShipRoster.leave(player, "not ready")
+			end
+		end)
+	end
+	Players.PlayerAdded:Connect(watch)
+	for _, p in Players:GetPlayers() do
+		watch(p)
+	end
+	Players.PlayerRemoving:Connect(function(player)
+		ShipRoster.leave(player, "disconnect")
+	end)
+	-- back in port: every ship takes a new party
+	state:GetAttributeChangedSignal("Phase"):Connect(function()
+		if state:GetAttribute("Phase") == "Waiting" then
+			for _, ship in ships do
+				ship.locked = false
+				publish(ship)
+			end
+		end
+	end)
+end
+
+function ShipRoster.shipOf(player)
+	return player:GetAttribute("ShipId")
+end
+
+function ShipRoster.members(shipId)
+	local ship = ships[shipId]
+	return if ship then memberList(ship) else {}
+end
+
+-- Returns ok, reason ("joined" | "already" | "full" | "sailed" | "noship")
+function ShipRoster.join(player, shipId)
+	local ship = ships[shipId]
+	if not ship then
+		return false, "noship"
+	end
+	if ship.members[player] then
+		return true, "already"
+	end
+	if ship.locked then
+		return false, "sailed"
+	end
+	if #memberList(ship) >= ShipRoster.CAPACITY then
+		return false, "full"
+	end
+	if player:GetAttribute("ShipId") ~= nil then
+		ShipRoster.leave(player, "switch") -- one party at a time
+	end
+	ship.members[player] = os.clock()
+	player:SetAttribute("ShipId", shipId)
+	player:SetAttribute("Ready", true)
+	publish(ship)
+	return true, "joined"
+end
+
+-- Frees the player's seat. Returns true if they were in a party.
+function ShipRoster.leave(player, why)
+	local shipId = player:GetAttribute("ShipId")
+	local ship = shipId and ships[shipId]
+	if ship then
+		ship.members[player] = nil
+	end
+	if shipId == nil then
+		return false
+	end
+	player:SetAttribute("ShipId", nil)
+	if player.Parent == Players and player:GetAttribute("Ready") then
+		player:SetAttribute("Ready", false)
+	end
+	if ship then
+		publish(ship)
+	end
+	return true
+end
+
+-- Departure: freezes the party and returns exactly the players who sail.
+function ShipRoster.depart(shipId)
+	local ship = ships[shipId]
+	if not ship then
+		return {}
+	end
+	ship.locked = true
+	local sailing = memberList(ship)
+	for p in ship.members do
+		if p.Parent ~= Players then
+			ship.members[p] = nil
+		end
+	end
+	publish(ship)
+	return sailing
+end
+
+return ShipRoster
--- before/StarterPlayer_StarterPlayerScripts_Client_Departure.client.luau
+++ after/StarterPlayer_StarterPlayerScripts_Client_Departure.client.luau
@@ -336,7 +336,7 @@
 	local showCrew = ready and not underway and (sailing or phase == "Waiting") and not hidden
 	crewCard.Visible = showCrew
 	if showCrew then
-		crewEyebrow.Text = string.format("YOUR CREW · %d", crewCount)
+		crewEyebrow.Text = string.format("YOUR CREW · %d/%d", crewCount, state:GetAttribute("ShipCapacity") or 4) -- seats on this ship
 		crewHeadline.Text = if sailing then (if atHarbor then "Sailing in " else "Next storm in ") .. clock(left) else "Waiting to sail"
 		crewHeadline.TextColor3 = if sailing and left <= 5 then C.AccentLighthouseSoft else C.TextPrimary
 		for i, row in rosterRows do
```
=== END FILE ===

