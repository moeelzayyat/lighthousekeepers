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
