# Auditor package: boarding batch (2026-10-15)

Repository: https://github.com/moeelzayyat/lighthousekeepers (branch `main`), folder `docs/batches/2026-10-15_boarding/`.

## Read in this order
1. `BOARDING_REPORT.md`: what changed, the hashes, the tests and the owner's 6-player test.
2. `CODE_DIFFS.diff`: exact diffs for Main, GameState, Departure, Hud and Menus, plus the new ShipBoarding.
3. `after/ServerScriptService_Server_ShipBoarding.luau`: the new module (about 150 lines).
4. `MULTI_SHIP_VOYAGE_SERVER_PLAN.md`: the plan the owner asked for, using a harbor place and reserved voyage servers. **Not implemented.**

## Scope check against the owner's decision
| Owner item | Where |
|---|---|
| Automatic boarding for the existing ship | `ShipBoarding.step`, wired in `Main` after `ShipRoster.init` |
| 1/4 … 4/4 and only that ship's members | `Departure.crewList` filters by `ShipId`; the sign, harbor card and crew card use `seats` |
| A 5th player sees "Crew full: find another ship" and stays free | `ShipBoarding.refuse`; the harbor card has a `BoardRefused == "full"` branch |
| Walking away frees the seat | `LEAVE_GRACE` (1 s); only seats taken on deck (`BoardedByDeck`) |
| One party per player | `ShipRoster.join` (unchanged); `ShipBoarding` never switches a player out of another party |
| Voyage HUD shows only the departing crew | `Departure.renderVoyageCrew` |
| Roblox list hidden during voyages only after the panel exists | `setPlayerListHidden(show)` is driven by the panel's own visibility |
| Departure only includes registered members; spectators don't affect fuel | Unchanged: the 1r `ShipRoster.depart` and the Ready-based fuel count |
| Batch 1 controls preserved | `Main.client`, `UiKit`, `Coach`, `LampService` and `Config` are not modified |

## Questions for the auditor
1. **Zone shape:** the zone is the ship model's oriented bounding box, plus 6 studs above it. Is that acceptable, or do you want a dedicated invisible deck volume, which would be a level-design change in LobbyBuilder?
2. **Rematch crew:** a crew that votes rematch keeps its seats while on the island, so harbor players see 4/4 and are refused. Is that the right priority, or should seats reopen at results?
3. **Test hook:** `ShipBoarding.init({ manual = true })` exposes `ShipBoarding.step` for unit tests and starts no loop. Is it acceptable to keep it in production code?
4. **Multi-ship plan:** please review the save hand-over section. The current PlayerData has no session lock, and I consider that the blocker for any teleport work.

## Safety confirmations
- Studio API access was checked OFF immediately before the only Play. PlayerData ran in memory.
- No PlayerData or save-format change, no DataStore writes, and nothing published. SaveTest and Outlaw City were not opened or modified. The Outlaw City Studio window was open but not addressed by any tool call.
