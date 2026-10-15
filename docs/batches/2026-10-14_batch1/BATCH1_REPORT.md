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
