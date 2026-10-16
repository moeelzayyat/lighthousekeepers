# Multi-ship: live-activation safeguards and the next-stage authorization package, 2026-10-16

- **Production game:** Lighthouse Keepers, PlaceId `132065051336560`, GameId `10769064643`.
- **Unchanged:** `MULTI_SHIP_ENABLED`, `TELEPORT_ENABLED` and `ISLE_STUDIO_TEST` are **false**. PlayerData is unchanged. There have been no DataStore or MemoryStore operations, no teleport, no new place and no publish.
- **Backups:**
  - Place: `backups\2026-10-16\LighthouseKeepers_2026-10-16_v162_pre-safeguards.rbxl`, SHA-256 `406c979d…806e`. Its Rojo export equals the pre-edit sources.
  - Scripts: `ServerStorage.Backups.Safeguards_before_2026-10-16`, plus `before\`.
- **Exact diffs:** `SAFEGUARDS_DIFFS.diff`.

## Part A: the two safeguards (implemented and tested)

### A1. A timed-out launch can never teleport an old crew
- **Per-voyage ticket:** every launch gets its own ticket `{ cancelled = false }`. When `HarborDepartures` reaches `LAUNCH_TIMEOUT` it sets `ticket.cancelled = true` and frees the ship.
- **Ticket checks:** `Voyages._teleport` checks the ticket at each of these points, and if it is cancelled it **recovers the crew** instead of teleporting them:
  - before each hand-off;
  - after all hand-offs;
  - after `ReserveServer`;
  - immediately before `TeleportAsync`.
- **Recovery** means a re-claim, removal from every party, and `InTransit` cleared. A failed re-claim disconnects the player so they rejoin.

### A2. Save hand-off exceptions
- Every `handoff` and `reclaim` call goes through `safeCall` (`pcall`). An exception counts as a failure: it is logged as `SaveAdapterError` and the player is recovered.
- An exception during `reclaim` counts as a failed re-claim, so the player is disconnected with "progress is saved, please rejoin" and never plays without an owned save session.
- **Watchdog:** a timer starts the moment a player becomes `InTransit`. Any player still in the server and still `InTransit` after `TRANSIT_TIMEOUT` (60 s) is recovered. This also covers a hand-off that **hangs** and a teleport that was requested but never happened.

### Tests: 18 / 18 PASS
These ran against real `Voyages`, `HarborDepartures`, `ShipRoster`, `ShipDeparture` and `ShipBoarding` copies, with fake teleport, MemoryStore and save-adapter services. The fake adapter tracks ownership the way SessionLock does.

| Scenario | Result |
|---|---|
| **Launch delayed past the timeout** (old crew's hand-offs take 3 s; launch timeout 1 s): the ship is released 1.0 s after sailing while the old launch is still running | PASS |
| A **new crew boards the same ship** and launches: exactly `P3,P4` teleported | PASS |
| The old launch, resuming after its hand-offs, **did not teleport the old crew**; exactly 1 teleport in total; `VoyageCancelled` logged | PASS |
| Old crew recovered: re-claimed, out of the party, not InTransit | PASS |
| Hand-off throws **before commit**: that player recovered, the others travel, and the manifest lists only the travellers | PASS (2 checks) |
| Hand-off throws **after release**: ownership re-claimed, no teleport, not InTransit | PASS |
| Re-claim throws: the player is disconnected to rejoin | PASS |
| **Teleport setup** throws (manifest write; teleport options): no teleport, everyone re-claimed, nobody InTransit | PASS (2 checks) |
| Teleport requested but the player never leaves: the watchdog recovers them | PASS (2 checks) |
| Hand-off **hangs forever**: the watchdog recovers the player, no teleport | PASS |

- The first run of the delayed-launch scenario failed 2 checks. That was test timing: the new crew boarded at a fixed time before the 0.2 s poll had released the ship. The rerun waits for the ship to be back in port, and all 7 checks passed.
- Script hashes (Studio equals `after\` and git; both compile):
  - `Voyages`: `84f77d46187d032f35133c1ab52aa9e0dc1cf9564e4de0fbbea5e33f2c5758cf`
  - `HarborDepartures`: `9f285b95daa712197ef7ed9adc33aa7aec38f06d0ad94354d42ab22113a5c8ff`

## Part B: the next stage, a working two-ship test (needs the owner's approval)

### B1. Where: a separate test experience (recommended)
- **What:** a NEW private experience, for example "LK Multiship Test". It holds two places: **Harbor** (the start place) and **Lighthouse Isle**.
- **Why this keeps production saves out of reach:** Roblox DataStores and MemoryStores belong to the experience (universe). Code running in the test experience **cannot address** universe 10769064643's DataStores at all, so production saves are physically inaccessible from it.
- **Second guard, in code:**
  - The new save path refuses to run unless `game.GameId == Config.MULTISHIP_TEST_GAME_ID`, the test experience's id (0 until you create it).
  - In production that check is always false, so even a mistaken publish keeps the new path off.

### B2. Exact store names and keys (test experience only)
| Store | Name | Key | Contents |
|---|---|---|---|
| Player saves (DataStore) | `LKMS_TEST_PlayerData_v1` | `player_<UserId>` (same format as today) | The same profile format as production. The session lock lives in the key's **metadata** `session = { token, job, at }`. |
| Voyage manifests (MemoryStore sorted map) | `Voyages` | `<reserved server PrivateServerId>` | `{ ship, userIds, privateServerId, createdAt }`; expires after 600 s |

Production keeps `LighthouseKeepers_PlayerData_v1` in its own experience; nothing new touches it. The test store has a different name as well, so it could never be mistaken for the production store.

### B3. Separating old and new writers
- **In the test experience:** only the new code ever runs, so there are no old writers.
- **Production:** the old code stays unchanged with the flags off. Production and test never share a store, so they cannot interfere.
- **Later production cutover**, which needs a separate approval:
  1. Publish the Harbor and Isle places together.
  2. Use **"Shut down all servers"** (not "Migrate"), so no old PlayerData writer survives.
  3. Only then turn on the flags, with a second publish.
- A metadata version marker is not relied on. Old code ignores metadata, so stopping old servers is the only real separation.

### B4. Minimal integration I will build next (once you approve; Studio only, flags off)
1. **PlayerData lock adapter**, active only when `game.GameId == MULTISHIP_TEST_GAME_ID`:
   - Load uses `SessionLock:claim(key, newProfile())`.
   - Autosave uses `save`, and also sends a `heartbeat` every 60 s.
   - `PlayerRemoving` uses `release`.
   - New `PlayerData.handoff(player)` freezes the profile, so every mutating function refuses while frozen, then calls `release`.
   - New `PlayerData.reclaim(player)` re-claims, reloads the profile and unfreezes it.
   - In production, PlayerData behaves exactly as today. This is the first PlayerData code change, so it needs your approval.
2. **Config:**
   - `MULTISHIP_TEST_GAME_ID` and `ISLE_PLACE_ID`, both set from your new IDs.
   - The multi-ship and teleport switches only take effect when the GameId equals the test id.
3. **Voyages:** wired to that adapter (`playerData = PlayerData`).

### B5. Creating and publishing the test places (owner steps; none done yet)
1. In Studio, open **a copy** of `LighthouseKeepers_2026-10-16_v162_pre-safeguards.rbxl` (File > Open from File). **Never** the live Lighthouse Keepers window.
2. **File > Publish to Roblox As… > "Create new experience"**, named "LK Multiship Test" and kept **Private**. This becomes the **Harbor** place.
3. **Asset Manager > Places > Add new place**, named "Lighthouse Isle". Publish the same build to it: right-click it, then Publish.
4. In the test experience's **Game Settings > Security**, turn on "Enable Studio Access to API Services". This is safe there, because that experience has no real player saves.
5. Send me the test **GameId**, the Harbor **PlaceId** and the Isle **PlaceId**.
6. I set the IDs, build B4 in that test Studio, and you publish both test places. We then run the two-ship test with real clients:
   - Ship1 and Ship2 depart at the same time to two separate Isle servers;
   - the save hand-off works in both directions;
   - a failed teleport is recovered;
   - a return to the harbor after Results works.

## Decisions for the owner
1. **Approve the separate test experience** (B1), or name another environment.
2. **Approve the PlayerData lock adapter** (B4), active only in the test experience.

Until both are approved, nothing in Part B will be created, written or published.
