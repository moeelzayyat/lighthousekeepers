# Auditor package: boarding revision (departure rules), 2026-10-15

- **Target:** Lighthouse Keepers, PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.**
- **Responds to:** "OWNER'S FINAL DECISION: LIGHTHOUSE KEEPERS SHIP DEPARTURE". It supersedes the departure rules of the boarding batch (commit bc5ad13).
- **Repository:** https://github.com/moeelzayyat/lighthousekeepers, folder `docs/batches/2026-10-15_departure/`.

## The rule now
| Party | What happens |
|---|---|
| 0/4 | Waiting for crew. The sign reads "WAITING FOR CREW · 0/4 · walk aboard to join". |
| 1/4 to 3/4 | Waiting for crew, with Sail Now available. **No countdown starts until a registered member uses SAIL NOW at the ship's wheel.** |
| 4/4 | Automatic departure countdown. |
| 5th and later | Not added to the party: "Crew full (4 of 4). Find another ship and sail, or wait for the next voyage." The lobby stays at 60. |

Walking onto the ship never starts a countdown on its own.

## Scripts changed (SHA-256, equal in Studio and in `after\`; all compile)
| Script | Change | SHA-256 |
|---|---|---|
| `Server.ShipDeparture` (**new**) | Decides when a ship sails: automatic at 4/4, manual SAIL NOW for 1 to 3, rematch | `3468f695ee9bdd49dff0b8ab37eff8bd84d2928b83f95be366411b5d81299c4a` |
| `Server.GameState` | **The first Ready player no longer triggers Intermission.** Waiting holds until a departure is requested. The countdown aborts when the request is withdrawn. An empty snapshot never starts a voyage. Play Again requests a rematch departure. | `db4271215cea37f8b5ecf329c6aa6e10edda58ce02426046c1a3f10fc3a2c36a` |
| `Server.LobbyBuilder` | Builds the invisible **BoardingZone** part. The wheel prompt now reads "Sail now". | `46c4e06840e002f2de8e52b07bb57884d923ecbba14e83dec476c5c464e1eddf` |
| `Server.ShipBoarding` | Uses the BoardingZone part instead of the ship's bounding box. Join messages explain 4/4 versus SAIL NOW. | `54f56dfd605e201a01b6df1e21e0998207bbe499b397f86e431fffb0466c14fe` |
| `Server.ShipRoster` | Adds the synchronous `onChange` hook and `isLocked`. Membership rules are unchanged. | `c9bac6e52d2b5f5a105148e140379e9bfea46550eae3bc2c88173b6a1b08b71b` |
| `Server.Main` | Wires ShipDeparture. The wheel prompt is SAIL NOW, server-validated. The old wheel join/leave code was removed. | `b7a10a5c2e793d91a303b80ceac89eff9a4ffadb1bbd13669a1681a5c803fa16` |
| `Client.Departure` | Sign, harbor card and crew card states. SAIL NOW is shown only to members who can use it. | `d8f905a2d726d74b4904cc66b10ac347d945cd55e55bdedd8e7a30e61af36cd1` |

- The exact diffs are in `CODE_DIFFS.diff`, with full `before\` and `after\` copies.
- **Unchanged since batch 1r:**
  - the batch 1 controller, phone and held-aim code: `Client.Main`, `UiKit`, `Coach`, `LampService` and `Config` (git shows no change);
  - `PlayerData`, the save format and the DataStores;
  - prices and balance.

## BoardingZone implementation
- **Built in `LobbyBuilder` after the ship is placed.**
  - The box is the union of the ship's walkable floor parts (`MainDeckFloor`, `QuarterdeckFloor`, `ForecastleFloor`, or a fallback `Deck`), measured in the ship's facing frame.
  - It runs from 0.5 studs under the lowest floor to 8 studs above the highest.
  - The part is invisible, anchored, and has CanCollide, CanQuery and CanTouch all off. It carries the attribute `ShipId = "Ship1"`.
- **Measured in Play:**
  - The zone is 28 × 12 × 65.5 studs, centred at (0, 15.6, 421.25), so it covers z 388.5–454.
  - The pier ramp starts at z 457.8, which is **3.8 studs outside** the zone.
  - The previous bounding box was 39 × 66 × 71, ran to z 455.7 and included the masts.
- **Membership:** `ShipBoarding` polls every 0.25 s. A point inside the oriented box joins through `ShipRoster.join`. A walked-on seat is released after 1 s outside the zone, which is the established exit tolerance.

## Countdown behaviour
- **One timer:** GameState's existing `Intermission` countdown, `Config.INTERMISSION_SECONDS`, currently 10 s. ShipDeparture never runs a timer of its own, so there are no duplicate countdowns.
- **Automatic (4/4):**
  - When the 4th member joins, a request `auto` is made and the crew is told "The crew is full! The ship is preparing to sail."
  - On any roster change below 4 the request is withdrawn at once, through the synchronous `ShipRoster.onChange` hook, plus a 0.5 s safety poll.
  - GameState's countdown aborts and the phase returns to `Waiting`. Reaching 4 again starts a new, full countdown.
- **Manual (SAIL NOW):**
  - The server accepts it only from a current party member, with a crew of 1 to 3, a ship that has not sailed, and no departure already running.
  - The whole crew is told: "X called SAIL NOW! The ship sails with its crew of N…"
  - It is cancelled if the initiator leaves the party (stepping off, menu or disconnect) or if the party empties.
  - If the party fills to 4 during it, **the same manual countdown continues unchanged**: no automatic request is added, and nothing is shortened or restarted.
  - Other members can step off freely.
- **At completion:** `ShipRoster.depart` freezes a fresh snapshot of members still in the server. An empty snapshot returns to Waiting without starting a run. Only the snapshot is sent to the island.
- **Rematch:** Play Again is treated as a deliberate departure (`rematch`) for the crew that chose it. That crew keeps its seats on the island, and harbor players can fill any free seats during the countdown.
- **After Results:** the ship unlocks at `Waiting`, no request remains, and the count shows only the remaining members.

## Test evidence
API access was checked **OFF** immediately before Play ("Studio access to APIs is not allowed"). The console showed "Progress is kept in memory only".

### Unit test: 24 of 24 PASS
The test ran in Edit mode on fresh copies of `ShipRoster`, `ShipBoarding` and `ShipDeparture` (`manual` mode), with 6 stand-in players and the real poll and evaluate functions.

1/4, 2/4 and 3/4 make no request · a pier spectator 4 studs past the zone is not a member · 4/4 starts `auto` · the 5th is refused "full" and the departure is unchanged · 4→3 cancels · 3→4 starts again · SAIL NOW is refused while a departure is running · a 4→3→4 dip inside one frame still cancels, then restarts · everyone leaving gives 0/4 and no request · SAIL NOW from a non-member is refused · 1/4 SAIL NOW starts one manual departure · a second SAIL NOW is refused · 1/4 sails exactly P1 · SAIL NOW is refused at sea · after results the state is clean · 2/4 sails only P2,P3 · 3/4 sails only P1,P2,P3 · the initiator stepping off cancels · another member leaving keeps the manual departure · filling to 4/4 during SAIL NOW keeps the one manual departure, with no auto added · the party emptying cancels · Play Again keeps the island crew's seats and makes one rematch request.

The first run reported 8 failures. They came from one bug in the test harness: the `wipe()` helper waited before its first poll, so the 1 s exit grace never started. After fixing the helper, all 24 passed with no change to game code.

### Studio Play (one client, real GameState)
| Check | Result |
|---|---|
| The pier ramp (0, 14, 466) is not aboard | PASS: no ShipId, count 0 |
| 1/4 on deck for 15 s (the old countdown was 10 s) | PASS: Phase stays `Waiting`. The log shows a join at 13.3 s and no departure until SAIL NOW at 46.0 s. |
| SAIL NOW visible to the member | PASS: the client prompt is enabled and reads "Sail now (1/4)"; the sign reads "CREW 1/4 · Waiting for crew · SAIL NOW at the wheel" |
| SAIL NOW via a real key press (E held 0.6 s) | PASS: `DepartureStarted mode=manual`, Phase `Intermission`, TimeLeft 10→6 |
| 1/4 solo voyage | PASS: `RunStarted players=1`, `landed`, ship locked, voyage panel "CREW · 1/4", Roblox PlayerList off, prompt hidden at sea |
| Menu leave, then port | PASS: Waiting, unlocked, no request, sign "WAITING FOR CREW 0/4", PlayerList back on |
| Initiator steps off during the manual countdown | PASS: `DepartureCancelled` after about 1.6 s, Phase `Waiting`, no departure 10 s later |
| Console | No game errors, and no ShipBoarding or ShipDeparture warnings |

### Six-client Studio test: PENDING (owner)
MCP Play drives one client, so I cannot run six real clients. The owner's test sheet is below and has not been run yet.

| # | Step (Test > Server & Clients, 6 players) | Expected | Result |
|---|---|---|---|
| 1 | One player boards and waits more than 15 s | No countdown | |
| 2 | 2 aboard, wait | No countdown | |
| 3 | 3 aboard, wait | No countdown | |
| 4 | 4th boards | "Preparing to sail", countdown starts | |
| 5 | One of the 4 steps off | Countdown cancels at once | |
| 6 | They step back on | Countdown restarts from the full time | |
| 7 | 5th and 6th try to board | "Crew full", they stay in the lobby | |
| 8 | A player stands on the pier | Not counted | |
| 9 | 1 aboard, SAIL NOW | Visible countdown, solo voyage | |
| 10 | 2 aboard, SAIL NOW | Only those 2 sail | |
| 11 | 3 aboard, SAIL NOW | Only those 3 sail | |
| 12 | Initiator steps off during a SAIL NOW countdown | Countdown cancels | |
| 13 | Everyone steps off | Ship back to Waiting, 0/4 | |
| 14 | During a voyage | Crew panel shows only the crew; harbor players keep the Roblox list | |
| 15 | During a night | Fuel drain matches the crew size, not the server | |
| 16 | After Results | Ship unlocked, clean count, no countdown unless Play Again | |
| 17 | Controller Y/B lamp and phone joystick | Unchanged from batch 1 | |

## Remaining limitations
- The six-client test above has not been run yet.
- The `TimeLeft` attribute keeps its last value after a cancelled countdown. Clients only display it while a departure is active, so nothing visible is affected.
- A rematch crew keeps its seats while on the island. This needs auditor confirmation.
- The 4th member sees two messages: the join message and "preparing to sail". This is cosmetic.
- On phones the crew card hides its help line, so SAIL NOW is explained by the wheel sign and the prompt itself.
- One ship only. No new islands and no TeleportService, as instructed.

## Rollback
- `ServerStorage.Backups.Departure_before_2026-10-15`: Main, GameState, LobbyBuilder, ShipBoarding, ShipRoster and Departure. Then delete `ShipDeparture`.
- Or the `before\` files.
- Or the place backup `backups\2026-10-15\LighthouseKeepers_2026-10-15_v157_pre-departure.rbxl`: 816,599 bytes, SHA-256 `727544c4e6d5140501ef58942a7cf913d90177ccf8856553a5346248d448da8b`, saved by the owner. It was verified by a Rojo export: its script hashes equal the pre-edit copies.

## Publication readiness
**Not ready yet.** It is ready for manual publish only after:
1. the owner's six-client sheet above passes, and
2. the auditor accepts this package.

## Questions for the auditor
1. Is Play Again counting as a deliberate departure (`rematch`) acceptable, or should every voyage end with the crew back in the harbor?
2. Is the 10 s `INTERMISSION_SECONDS` enough time to step off after SAIL NOW or 4/4? A longer time would be a balance change, which I have not made.
3. Is the BoardingZone height (8 studs above the highest deck) acceptable?
