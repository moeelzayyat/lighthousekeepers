# Lighthouse Keepers: boarding batch (automatic ship boarding and a crew-only panel)

- **Target:** Lighthouse Keepers, PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.**
- **Responds to:** the owner's decision of 2026-10-15 ("OWNER DECISION: LIGHTHOUSE KEEPERS SHIPS AND LOBBY"), and the owner's failed 6-player test. In that test only the player who pressed E at the wheel sailed, because the batch 1r build required each player to press E.
- **Builds on:** batch 1r's `ShipRoster`, which is unchanged. It is still the only thing that decides crew membership.

## What changed
| Before (batch 1r) | After (this batch) |
|---|---|
| Each player pressed E at the ship's wheel to join | **Walking onto the ship joins its party** (new `ShipBoarding` module). The zone is the ship model's bounding box. Seats fill in arrival order up to 4. The wheel prompt is switched off, and the wheel keeps its sign. |
| A 5th player at the wheel got "crew is full" | A 5th player who walks aboard gets **"Crew full (4 of 4). Find another ship and sail, or wait for the next voyage."** The message appears once per boarding. The player stays free to walk around and is never moved. |
| Leaving meant pressing E again | **Stepping off the ship** before departure frees the seat after a 1 s grace. Menu, results "no" and disconnect still free it through the roster, as in 1r. |
| The crew list read `Ready` across the whole server | The crew card, wheel sign and harbor card read **only this ship's party** (`ShipId`) and show **n/4**. |
| No crew panel during a voyage; Roblox's list showed every server player | **A voyage crew panel** on the left edge lists only the departing crew and marks the Keeper. Roblox's player list is hidden **only while that panel is on screen**, and comes back in the harbor. |
| Departure: the frozen party | Unchanged: `ShipRoster.depart` freezes the party. The "walked aboard" flag is then cleared, so a rematch crew on the island keeps its seats. |
| Wheel instructions in 6 texts | Rewritten to "walk onto the ship" (Main, GameState, Hud, Menus, Departure). |

**Not touched:** PlayerData, the save format, DataStores, prices, balance, fuel rules, the Roblox server size (60), SaveTest, Outlaw City, and the batch 1 controller and phone code (`Main.client`, `UiKit`, `Coach`, `LampService` and `Config` are unchanged).

## Scripts (SHA-256, equal in Studio and in `after\`; all compile)
| Script | SHA-256 |
|---|---|
| `ServerScriptService.Server.ShipBoarding` (**new**) | `5e1730121b0f49a3e1d18dc156f0598dc87f79cc36362b5dd7289221252ea2f8` |
| `ServerScriptService.Server.Main` | `977db195103d21f46152e71664a1da95710149f6d4e704a353c4a6bf3b17b64f` |
| `ServerScriptService.Server.GameState` (one text) | `ba17f347961db15c6e37b6e1dba6bc8a2f6cd8d7c3738c965908e96f183bdc13` |
| `StarterPlayerScripts.Client.Departure` | `364fe234925b7e64bda8958314aaaa0c6ef1eb75f6e33916428751715b06cafe` |
| `StarterPlayerScripts.Client.Hud` (one text) | `b435e7e27ef6deaeee13482999e807112b11bb1323481a326343d3a5ef7c826a` |
| `StarterPlayerScripts.Client.Menus` (one text) | `3d9d6cfdd7a1a1159ae2ff644aed8aebe4f751e426fb098efc349797bfcdb833` |

Before this batch, Studio matched batch 1r's published hashes: Main `993e13fc…`, GameState `c409beb5…`, Departure `391ad410…`, ShipRoster `eb09d934…`.

**Rollback options:**
- `ServerStorage.Backups.Boarding_before_2026-10-15`, then delete `ShipBoarding`;
- or the `before\` files;
- or the place backup `backups\2026-10-15\LighthouseKeepers_2026-10-15_v156_pre-boarding.rbxl`: 813,107 bytes, SHA-256 `b3797fbfc19441ce1ab17a3860c8f23150f5eea2217313157da951ad5db90d9e`, saved by the owner. It was verified by a Rojo export, whose Main, ShipRoster and Departure hashes equal the pre-batch Studio scripts.

## Tests
API access was checked **OFF** immediately before Play ("Studio access to APIs is not allowed"). The console showed "Progress is kept in memory only", and ProfileState was `memory`.

**Boarding unit test: 15 of 15 PASS.** It ran in Edit mode on fresh copies of `ShipRoster` and `ShipBoarding` (`manual` mode), with 6 stand-in players plus extras. Everything was removed afterwards.

| Check | Result |
|---|---|
| 4 walk aboard: 4/4 crew, flagged as walked aboard | PASS |
| 5th aboard is refused "full" and is not crew | PASS |
| The "Crew full" message appears once per boarding, not every poll | PASS |
| 6th ashore is not crew and not near the ship | PASS |
| Stepping off keeps the seat during the 1 s grace | PASS |
| Stepping off for more than 1 s frees the seat | PASS |
| The 5th, still aboard, takes the freed seat | PASS |
| A player still on the title screen standing on deck is not boarded | PASS |
| Departure is exactly P1, P3, P4, P5 | PASS |
| The walked-aboard flag is cleared at departure | PASS |
| Crew off the ship during the voyage keep their seats | PASS |
| A lobby player on deck mid-voyage is refused "sailed" | PASS |
| In port: unlocked, the rematch crew is still 4/4, and the 6th is refused "full" | PASS |
| A rematch player choosing "menu" frees a seat, and the 6th on deck boards | PASS |
| A dead character is not boarded | PASS |

The first run had 2 failures. These were a test bug: the phase was set twice in one frame, and Studio's deferred attribute signal had not fired yet. With a yield between phase changes, both passed. The game itself never changes phase twice in one frame.

**Studio Play (one player):**

| Check | Result |
|---|---|
| The wheel prompt is disabled; the lobby spawn and Quartermaster counter are outside the ship zone | PASS (`HelmPrompt.Enabled=false`; spawn z=518 and counter z=488 are outside the ship box at z 384–456) |
| Walk aboard | PASS: `PlayerReady ship=Ship1 via=deck`, count 1, phase changes to Intermission |
| Step off for 0.6 s | PASS: still crew |
| Step off for 1.8 s | PASS: `LeftCrew via=deck`, count 0, phase back to Waiting |
| Walk back aboard | PASS: crew again |
| Departure | PASS: Prologue, `Ship_Ship1_Locked=true`, flag cleared, player on the island |
| Voyage panel | PASS: "CREW · 1/4 / Lighthouse8282 (you)" on the left edge, with no overlap with the HUD (screenshot checked). The Roblox PlayerList is disabled. |
| Leave mid-voyage (menu) | PASS: run abandoned, Waiting, unlocked, harbor card "HARBOR ISLAND · SHIP 0/4", sign "CREW 0/4". The voyage panel is hidden and the PlayerList is re-enabled. |
| Console | No game errors and no `[ShipBoarding]` warnings |

**Not possible here:** 5 or more real clients. MCP Play gives one client. The owner's 6-player test below is the remaining gate.

## Owner 6-player test (Studio, Test > Server & Clients, 6 players)
1. All 6 press Play and stand on the shore. The sign reads "CREW 0/4".
2. Players 1 to 4 walk onto the ship one at a time. Each sees "You're in the crew (n of 4)", and the sign goes 1/4, 2/4, 3/4, 4/4. **Nobody presses anything.**
3. Player 5 walks aboard and sees "Crew full… find another ship", and the harbor card says CREW FULL · 4/4.
4. Player 2 walks back to shore and is out after about 1 s. Player 5, still on deck, takes the seat.
5. When the countdown ends, only the 4 crew members are moved to the island. Players 2 and 6 stay in the harbor.
6. During the voyage, each crew member sees a crew panel on the left with only the 4 names, and no Roblox player list. The players in the harbor still have the normal Roblox list.
7. One crew member leaves through the menu. The panel updates for the rest, and fuel drain follows the crew.
8. After the voyage, the ship unlocks and harbor players can walk aboard again.

## Remaining limitations
- The zone is the ship model's bounding box, so the end of the pier can count as aboard if it reaches inside the hull's footprint. The owner should judge this in the test.
- There is no visible floor marking for the zone. The sign and the messages explain it.
- There is one ship. Multiple ships are planned in `MULTI_SHIP_VOYAGE_SERVER_PLAN.md` and are not implemented.

## Publication recommendation
Ready for manual publish **after the owner's 6-player test above passes**.
