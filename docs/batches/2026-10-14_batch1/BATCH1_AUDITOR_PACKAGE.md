# LIGHTHOUSE KEEPERS - GAMEPLAY BATCH 1 AUDITOR PACKAGE

Combined plain-text package. Target: Lighthouse Keepers (PlaceId 132065051336560, GameId 10769064643), Studio only, NOT published. No save, PlayerData, price or balance changes. Owner testing reported as passing; awaiting audit before the owner's manual publish.

## Contents
1. BATCH1_REPORT.md (6467 bytes, SHA-256 0d69479067ee0eaf6cbfbe7de48b4187cd140b21e89670e3c6efe80b565750e2)
2. CHANGE_MANIFEST.md (3011 bytes, SHA-256 6a4d92265524d841879343343feee76c77b6bd7a2a69bb95bb53e5ce8bbebbfa)
3. CODE_DIFFS.diff (9931 bytes, SHA-256 fb4f6c0814efe361a9d3b5765718eb1b65440112359b9e1f8844eb9f37632208)

=== FILE: docs/batches/2026-10-14_batch1/BATCH1_REPORT.md ===
# Lighthouse Keepers: gameplay batch 1 report

**Status:** implemented in the Studio window of Lighthouse Keepers (PlaceId `132065051336560`, GameId `10769064643`) and tested in Studio. **Not published.** Ready for your own testing and then your manual publish.

## Problems fixed
| # | Problem (audit ID) | Before | After |
|---|---|---|---|
| 1 | No crew limit | Any number of players could join a voyage at the ship's wheel. A first-time player was auto-joined even into a big crew. | At most **4** Keepers sail. A 5th player who uses the wheel sees "The crew is full (4 Keepers). Wait on the ship: you can join the next voyage." and stays aboard. A first-timer is sent to the title screen instead of being auto-joined into a full crew. |
| 2 | Fuel scaled by everyone on the server (GP-2) | Players on the title screen or the ship made the island crew's lamp burn fuel faster. | The drain multiplier counts only the **crew** (Ready players). The numbers `{0.7, 0.85, 1, 1}` are unchanged. |
| 3 | Controller could take the lamp but not run it (GP-44) | No aim, no focus and no leave on a controller; the Keeper was stuck until the 25 s idle release. | **Either stick aims, Y switches the beam, B leaves.** Button labels show "· Y" and "· B", and the coach tips show Y and the left stick. Y and B are ignored while a menu is open, so B still closes menus. |
| 4 | Phone joystick came back over the aiming thumb (GP-43) | Closing any menu while Keeper turned the joystick and jump button back on. | Closing a menu keeps them hidden while you are the Keeper. When you are not the Keeper they come back as before. |
| 5 | A held aim counted as idle (GP-3, phone and controller part) | A finger or stick held still for 25 s released the lamp. | A held finger or stick re-sends its aim once a second, so the Keeper stays. A **mouse** held still for 25 s still releases (unchanged), because that usually means the player walked away. |

## Scripts modified (7)
| Script | SHA-256 after (equal in Studio and in `after\`) |
|---|---|
| `ReplicatedStorage.Shared.Config` (adds `MAX_CREW = 4`) | `41b4f0ab…2df8` |
| `ServerScriptService.Server.Main` (crew cap) | `79fe2532…526a` |
| `ServerScriptService.Server.LampService` (crew-based fuel) | `9222d36f…1842` |
| `StarterPlayerScripts.Client.Main` (controller and held aim) | `846ce8e5…40e3` |
| `StarterPlayerScripts.Client.UiKit` (phone joystick) | `0dc89897…a4d0` |
| `StarterPlayerScripts.Client.Hud` (controller labels) | `d1c0cc19…30a6` |
| `StarterPlayerScripts.Client.Coach` (controller tips) | `7a040636…b900` |

Full hashes, backups and rollback steps are in `CHANGE_MANIFEST.md`.

**Not touched:**
- PlayerData and the save format;
- prices, rewards and balance numbers;
- SaveTest and Outlaw City.

## Test results (Studio, 2026-10-15, one player)
**Before Play:** the API-access probe was refused ("Studio access to APIs is not allowed"). In Play the console shows "Progress is kept in memory only", so no save was read or written.

| Check | Result |
|---|---|
| Every edited script compiles; Studio text equals the reviewed files | PASS (hash check on 10-14; byte sizes equal again after the Studio restart) |
| Play starts with no errors from game scripts | PASS (console: only Roblox's own UIBlox warnings) |
| First voyage: a new player is auto-joined (cap not hit) | PASS (`PlayerReady via=first voyage`) |
| Leave and rejoin the crew at the wheel | PASS (`LeftCrew`, then `PlayerReady via=wheel`) |
| Take the lamp at the console; Keeper view | PASS (Keeper, scripted camera, joystick hidden) |
| **F** switches to focused | PASS (`BeamMode mode=focused`) |
| **Y** (controller) switches back | PASS (`BeamMode mode=wide`) |
| Phone rule: open and close a menu as Keeper | PASS (joystick stays hidden); as non-Keeper it comes back (PASS) |
| **B** (controller) leaves the lamp | PASS (`KeeperLeft reason=leave`) |
| **Q** leaves the lamp | PASS |
| Mouse aim still works (pointer to the right turns the beam to +X) | PASS (beam look `(0.85, 0.14)`) |

**Not testable here, and why:**
- **Crew cap with 5 players.** It needs 5 clients; MCP can only start one. Overriding the cap at runtime was tried and did not reach the game's own copy of Config, so that test proved nothing.
- **Fuel by crew.** It needs players who are not in the crew; with one player the old and new count are equal.
- **Thumbstick aiming.** Simulated stick presses produce no stick movement. The angle formula was checked by hand against the beam code, and buttons Y and B were tested.
- **Real phone touch.**

## Owner test results
- 2026-10-15: crew cap with 5 local clients: **PASS**, reported by the owner. The 5th player at the wheel saw "The crew is full".
- 2026-10-15: remaining owner checks reported as "All working". These were the controller and phone checks (items 2 to 4 below). The owner reported the outcome only; no screenshots or logs.

## What you should test yourself
1. **Crew cap:** Studio Test tab > Clients and Servers > **5 players** > Start. All five use the wheel; the 5th gets "The crew is full" and stays on the ship.
2. **Fuel:** with 2 players, one in the crew and one staying on the title screen, the night drain should match a crew of 1. Without the fix it matched 2.
3. **Controller:** take the lamp, then:
   - push the left or right stick: the beam follows (stick up = away from the camera);
   - Y = focus or wide; B = leave;
   - hold the stick still for 30 s: you stay Keeper.
4. **Phone** (Studio device emulator or a real phone):
   - take the lamp; open and close the bag or shop: the joystick stays hidden;
   - hold a finger still for 30 s: you stay Keeper.

## Remaining issues (not in this batch)
- Roblox's own server size may still allow more than 4 players in a server. The extra players just wait on the ship. To match, set Max Players to 4 in Game Settings > Places if you want that.
- Gamepad weapon strikes still aim with the mouse position (GP-45).
- Hybrid touch-and-keyboard devices are treated as keyboard (GP-46).

## Note on today's first Play
After a Studio restart, API access had come back **on**. My first Play (22 s, title screen) loaded your real profile. Nothing changed and the game only saves on change, so no write is expected, but I can't prove it. You turned access off, and I now check it immediately before every Play.

## Ready for manual publish?
**Yes, after your own tests 1 to 4**, especially the 5-player crew cap and a real controller.
=== END FILE ===

=== FILE: docs/batches/2026-10-14_batch1/CHANGE_MANIFEST.md ===
# Batch 1 change manifest: gameplay reliability (2026-10-14)

**Target:** Lighthouse Keepers, PlaceId `132065051336560`, GameId `10769064643`. Studio window "Lighthouse Keepers - Staging", place version 150.

**Not done:**
- not published;
- no PlayerData change and no save schema change;
- no DataStore write;
- Studio API access left **off**, verified before testing: a probe read was refused with "Studio access to APIs is not allowed";
- SaveTest and Outlaw City not touched.

## Rollback copies
- **Full place:** `backups\2026-10-14\LighthouseKeepers_2026-10-14_v150_pre-batch1.rbxl`, saved by the owner.
  - 809,189 bytes, header `<roblox!`, SHA-256 `7A76DD6BEA03B7C5A73AFD85638B5B07622779318F2CF15694A1B6077C8EEF8E`.
  - Rojo export in `work\v150-export`: the scripts are identical to v149.
- **In Studio:** `ServerStorage.Backups.Batch1_before_2026-10-14` holds disabled clones of all 7 scripts, taken before any edit.
- **On disk:** `before\` (exact pre-batch text) and `after\` (exact post-batch text). The sizes of `before\` equal the Studio sources before the edit.

## Scripts changed (SHA-256 after; verified inside Studio, all compile)
| Script | Change | SHA-256 after |
|---|---|---|
| `ReplicatedStorage.Shared.Config` | adds `MAX_CREW = 4` | `41b4f0ab4fba08b9a0c820145a16187a637d304a3cb97261b2dae672acb30df8` |
| `ServerScriptService.Server.Main` | crew cap: `crewIsFull`; `joinCrew` refuses a 5th Keeper with a message and returns false; a first-time player is not fast-routed into a full crew | `79fe2532247862476c9f239ea695c38b989d67e3236183617096bee35306526a` |
| `ServerScriptService.Server.LampService` | the fuel-drain crew multiplier counts Ready crew, not every player on the server (GP-2) | `9222d36fd7222ea0a29119a7849720d73828457845e4664d944d19017e4c1842` |
| `StarterPlayer...Client.Main` | controller Keeper: either thumbstick aims, Y switches beams, B leaves the lamp (GP-44); a held finger or stick re-sends its aim once a second, so the 25 s idle release no longer fires on a held aim (GP-3) | `846ce8e5eabc4ddbb299f05d21debfe95092433f26e121d44b2d4c89002c40e3` |
| `StarterPlayer...Client.UiKit` | closing a menu no longer turns the phone joystick back on while you are the Keeper (GP-43) | `0dc898972864927f8ff95d721257ccd3b28b6004173509223d0e2f23e2bba4d0` |
| `StarterPlayer...Client.Hud` | Keeper buttons show "· Y" and "· B" on a controller | `d1c0cc19583c6b8677e96f7f1e28bf274b6ea7e87753ab0ce89dde8047cf30a6` |
| `StarterPlayer...Client.Coach` | coach hints for "focus" (Y) and "aim" (left stick) on a controller | `7a040636c2cf8eb55da0da432f6194dc74c4f51a1f659cb3930d1fc1d8f6b900` |

No prices, rewards, drain numbers or other balance values were changed. The existing table `FUEL_DRAIN_BY_CREW_SIZE = { 0.7, 0.85, 1, 1 }` is unchanged. Only who counts as "crew" changed.

## Rollback
For each script, copy the Source of the clone in `ServerStorage.Backups.Batch1_before_2026-10-14` back over it, or use the `before\` files. Alternatively, restore the v150 `.rbxl`.
=== END FILE ===

=== FILE: docs/batches/2026-10-14_batch1/CODE_DIFFS.diff ===
```diff
--- before/ReplicatedStorage_Shared_Config.luau
+++ after/ReplicatedStorage_Shared_Config.luau
@@ -46,6 +46,7 @@
 	FUEL_DRAIN_PER_SECOND = 1.2, -- only drains at night; a full tank lasts ~80 s on the wide beam
 	FUEL_PER_REFILL = 40, -- one barrel of oil
 	FUEL_DRAIN_BY_CREW_SIZE = { 0.7, 0.85, 1, 1 }, -- drain multiplier for 1, 2, 3, 4 players (solo can't refuel and keep the lamp at once)
+	MAX_CREW = 4, -- batch 1: at most 4 Keepers sail together; anyone else waits on the ship for the next voyage
 	DAWN_LOOT_SECONDS = 25, -- leftover loot stays this long into the day at full value (was 10; owner, Oct 12)
 	DAWN_LOOT_FRACTION = 0.5, -- at dawn the tide brings leftover loot to the crew at this fraction of its value
 	DARK_GRACE_SECONDS = 10, -- how long the lamp can be out before the run is lost
--- before/ServerScriptService_Server_LampService.luau
+++ after/ServerScriptService_Server_LampService.luau
@@ -280,8 +280,14 @@
 				rate *= 0.75 -- evolution (Shared.Upgrades.EVOLUTIONS): focused beam burns 25% less
 			end
 		end
-		-- Smaller crews burn less fuel
-		local crewSize = math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)
+		-- Smaller crews burn less fuel. Counts the crew (Ready players), not everyone on the server (batch 1)
+		local crew = 0
+		for _, p in Players:GetPlayers() do
+			if p:GetAttribute("Ready") then
+				crew += 1
+			end
+		end
+		local crewSize = math.clamp(crew, 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)
 		rate *= Config.FUEL_DRAIN_BY_CREW_SIZE[crewSize]
 		rate *= state:GetAttribute("ForecastFuelMult") or 1 -- storm forecast (Leaky stores)
 		fuel = math.max(0, fuel - rate * dt)
--- before/ServerScriptService_Server_Main.server.luau
+++ after/ServerScriptService_Server_Main.server.luau
@@ -642,9 +642,25 @@
 	end
 end)
 
--- Joining the crew (ship's wheel, or automatically on a first voyage)
+-- Crew cap (batch 1): at most Config.MAX_CREW players sail; anyone else waits on the ship
+local function crewIsFull(player)
+	local n = 0
+	for _, p in Players:GetPlayers() do
+		if p ~= player and p:GetAttribute("Ready") then
+			n += 1
+		end
+	end
+	return n >= (Config.MAX_CREW or 4)
+end
+
+-- Joining the crew (ship's wheel, or automatically on a first voyage). Returns false if the crew is full.
 local function joinCrew(player, via)
 	local phase = stateFolder:GetAttribute("Phase")
+	if crewIsFull(player) then
+		LampService.notify(player, string.format("The crew is full (%d Keepers). Wait on the ship: you can join the next voyage.", Config.MAX_CREW or 4))
+		EventLog.log("CrewFull", { player = player.Name, via = via })
+		return false
+	end
 	player:SetAttribute("Ready", true)
 	EventLog.log("PlayerReady", { player = player.Name, via = via })
 	EventLog.mark(player, "crew")
@@ -654,6 +670,7 @@
 	else
 		LampService.notify(player, if via == "first voyage" then "The storm is coming. The light needs a keeper: the ship sets sail soon." else "You joined the crew! The ship sets sail soon.")
 	end
+	return true
 end
 
 -- The ship's wheel: join or leave the crew
@@ -688,6 +705,7 @@
 		and (profileState == "saved" or profileState == "memory")
 		and player:GetAttribute("RunsCompleted") == 0
 		and not player:GetAttribute("InLobby")
+		and not crewIsFull(player) -- batch 1: a full crew sends a first-timer to the title instead
 	EventLog.setRoute(player, if fast then "fast" elseif profileState == "failed" then "failed-load" elseif profileState == nil then "slow-load" else "title")
 	if not fast then
 		player:SetAttribute("Route", "title")
--- before/StarterPlayer_StarterPlayerScripts_Client_Coach.client.luau
+++ after/StarterPlayer_StarterPlayerScripts_Client_Coach.client.luau
@@ -189,7 +189,7 @@
 		id = "focus",
 		icon = "danger",
 		text = "Big one! Focus burns it — uses fuel fast",
-		keys = { keyboard = "F", touch = "Focus" },
+		keys = { keyboard = "F", touch = "Focus", gamepad = Enum.KeyCode.ButtonY }, -- batch 1: controller hint
 		when = function()
 			return isKeeper() and bigMonsterOut() and state:GetAttribute("BeamMode") ~= "focused"
 		end,
@@ -198,7 +198,7 @@
 		id = "aim",
 		icon = "lamp",
 		text = "Aim the light at the crabs",
-		keys = { keyboard = "Mouse", touch = "Drag" },
+		keys = { keyboard = "Mouse", touch = "Drag", gamepad = Enum.KeyCode.Thumbstick1 }, -- batch 1: controller hint
 		when = function()
 			return isKeeper() and creaturesOut()
 		end,
--- before/StarterPlayer_StarterPlayerScripts_Client_Hud.client.luau
+++ after/StarterPlayer_StarterPlayerScripts_Client_Hud.client.luau
@@ -544,8 +544,14 @@
 	return "keyboard"
 end
 
-local function keySuffix(key)
-	return if inputMode() == "keyboard" then "  ·  " .. key else ""
+local function keySuffix(key, padKey)
+	local mode = inputMode()
+	if mode == "keyboard" then
+		return "  ·  " .. key
+	elseif mode == "gamepad" and padKey then
+		return "  ·  " .. padKey -- batch 1: controller hints for the Keeper buttons
+	end
+	return ""
 end
 
 -- voyage status ------------------------------------------------------
@@ -654,9 +660,9 @@
 	local me = keeperId == player.UserId
 	keeperRow.Visible = me
 	focusWarn.Visible = me and mode == "focused" and not compact
-	beamButton.Text = (if mode == "focused" then "WIDE BEAM" else "FOCUS BEAM") .. keySuffix("F")
+	beamButton.Text = (if mode == "focused" then "WIDE BEAM" else "FOCUS BEAM") .. keySuffix("F", "Y")
 	beamButton:SetAttribute("BaseText", beamButton.Text)
-	leaveButton.Text = "LEAVE LAMP" .. keySuffix("Q")
+	leaveButton.Text = "LEAVE LAMP" .. keySuffix("Q", "B")
 	leaveButton:SetAttribute("BaseText", leaveButton.Text)
 end
 
--- before/StarterPlayer_StarterPlayerScripts_Client_Main.client.luau
+++ after/StarterPlayer_StarterPlayerScripts_Client_Main.client.luau
@@ -90,6 +90,12 @@
 local pendingAngle = nil
 local lastSent = 0
 local SEND_INTERVAL = 0.05
+-- batch 1: controller aim (GP-44) and held-aim keep-alive (GP-3)
+local lastAim = nil -- the last angle aimed by any input
+local stickHeld = false -- a thumbstick is pushed past the dead zone
+local heldTouches = {} -- touches currently aiming (not on a button)
+local STICK_DEADZONE = 0.35
+local HOLD_RESEND = 1 -- seconds: a held finger or stick re-sends its aim so the idle timer sees the Keeper
 
 -- While at the lamp the Keeper can't walk (server sets WalkSpeed 0), so the movement controls
 -- are hidden: on phones the joystick and jump button would otherwise sit under the aiming thumb.
@@ -147,6 +153,9 @@
 		enterKeeperView()
 	else
 		pendingAngle = nil
+		lastAim = nil
+		stickHeld = false
+		heldTouches = {}
 		exitKeeperView()
 	end
 end
@@ -170,6 +179,11 @@
 	end
 	-- The beam points along -Z at angle 0, so solve for the yaw that faces (dx, dz)
 	pendingAngle = math.deg(math.atan2(-dx, -dz))
+	lastAim = pendingAngle
+end
+
+local function isStick(input)
+	return input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2
 end
 
 UserInputService.InputChanged:Connect(function(input, gameProcessed)
@@ -180,6 +194,17 @@
 		aimAt(input.Position)
 	elseif input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
 		aimAt(input.Position)
+	elseif isStick(input) then
+		-- Controller (batch 1): either stick aims; walking is off at the lamp. The Keeper camera looks
+		-- toward -Z, so stick right = world +X and stick up = world -Z (same angle rule as aimAt).
+		local x, y = input.Position.X, input.Position.Y
+		if math.sqrt(x * x + y * y) >= STICK_DEADZONE then
+			pendingAngle = math.deg(math.atan2(-x, y))
+			lastAim = pendingAngle
+			stickHeld = true
+		else
+			stickHeld = false
+		end
 	end
 end)
 
@@ -187,23 +212,39 @@
 	if gameProcessed or not isKeeper then
 		return
 	end
+	local menuOpen = player:GetAttribute("MenuOpen") == true
 	if input.UserInputType == Enum.UserInputType.Touch then
+		heldTouches[input] = true
 		aimAt(input.Position)
-	elseif input.KeyCode == Enum.KeyCode.Q then
+	elseif input.KeyCode == Enum.KeyCode.Q or (input.KeyCode == Enum.KeyCode.ButtonB and not menuOpen) then
 		lampAction:FireServer("leave")
-	elseif input.KeyCode == Enum.KeyCode.F then
+	elseif input.KeyCode == Enum.KeyCode.F or (input.KeyCode == Enum.KeyCode.ButtonY and not menuOpen) then
 		lampAction:FireServer("toggleMode")
 	end
 end)
 
+UserInputService.InputEnded:Connect(function(input)
+	heldTouches[input] = nil
+	if isStick(input) then
+		stickHeld = false
+	end
+end)
+
 -- (the on-screen Focus / Leave buttons are drawn by Hud)
 
--- Send aim updates to the server at most 20 times per second
+-- Send aim updates to the server at most 20 times per second. While a finger or stick is held still,
+-- re-send the same aim once a second so the 25 s idle release (KEEPER_IDLE_SECONDS) does not fire (GP-3).
 RunService.RenderStepped:Connect(function()
-	if isKeeper and pendingAngle and os.clock() - lastSent >= SEND_INTERVAL then
+	if not isKeeper then
+		return
+	end
+	if pendingAngle and os.clock() - lastSent >= SEND_INTERVAL then
 		beamControl:FireServer(pendingAngle)
 		pendingAngle = nil
 		lastSent = os.clock()
+	elseif lastAim and (stickHeld or next(heldTouches) ~= nil) and os.clock() - lastSent >= HOLD_RESEND then
+		beamControl:FireServer(lastAim)
+		lastSent = os.clock()
 	end
 end)
 
--- before/StarterPlayer_StarterPlayerScripts_Client_UiKit.luau
+++ after/StarterPlayer_StarterPlayerScripts_Client_UiKit.luau
@@ -312,7 +312,10 @@
 	local anyOpen = next(openModals) ~= nil
 	Players.LocalPlayer:SetAttribute("MenuOpen", anyOpen)
 	pcall(function()
-		GuiService.TouchControlsEnabled = not anyOpen
+		-- batch 1 (GP-43): closing a menu must not bring the joystick back while this player is the Keeper
+		local gameState = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
+		local isKeeper = gameState ~= nil and gameState:GetAttribute("KeeperUserId") == Players.LocalPlayer.UserId
+		GuiService.TouchControlsEnabled = not anyOpen and not isKeeper
 	end)
 end
 function UiKit.pushModal(name)
```
=== END FILE ===

