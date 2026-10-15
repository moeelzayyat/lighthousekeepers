> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# Isolated test plan (TASK-003) — nothing here has been run

## 0. Hard safety rules for every test
1. **No test touches the production DataStore (`LighthouseKeepers_PlayerData_v1`) or the owner's real profile (`player_11752219158`).** Studio on the live place shares the live DataStore, so no save-related test runs in the live Lighthouse Keepers Studio window.
2. No Play, Stop, Save, Publish or script execution is ever sent to Outlaw City, or to any instance whose place ID has not just been re-verified. The instance list is re-read before each step.
3. Never publish the scratch copy and never use "Save to Roblox" on it.
4. No `RemoveAsync`, no `SetAsync`/`UpdateAsync` against production keys, no restore of backups over saves.

## 1. Environments
| Env | What | DataStore exposure | Used for |
|---|---|---|---|
| E0 | Pure-logic harness: the new save logic written against an interface `Backend` with `getAsync/updateAsync`, run against an in-memory **fake backend** that simulates latency, errors, throttling and concurrent writers | none (no DataStoreService call at all) | save lock, dirty-counter, retry, shutdown, migration shapes |
| E1 | **Scratch copy** of the game: the owner opens `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl` through File > Open from File in its own Studio window; this is also the TASK-001 follow-up. A file opened from disk is not tied to the published universe, so its `game.GameId` should be 0 and DataStores are unavailable (expected; verified at the start of each session by reading `game.GameId` and `game.PlaceId` only) | none | handler tests with Studio "Clients: 4", Pearl ledger, crew cap, fuel, validation, with `SaveBackend = memory` |
| E2 | Optional: a **separate private test experience** created by the owner in their account (new place, new universe), with a test-only store name (for example `LK_TEST_PlayerData`), joined by test accounts only | real DataStores, but a different universe | true two-server tests (rejoin and server hop), shutdown behaviour |
| — | The live Lighthouse Keepers place | production | **never used for these tests** |

Studio's Test tab can start several clients against one local server; it cannot make two separate servers, which is why true cross-server behaviour needs E2 (or is simulated in E0 with two logical servers that have different `JobId`s sharing one fake store).

## 2. Save integrity tests (E0 first, E1 second, E2 last)
| ID | Scenario | Expected |
|---|---|---|
| S1 | Two logical servers load the same key at once | exactly one holds the lock; the other waits, then kicks/refuses; no profile is loaded without a lock |
| S2 | Rejoin: server A releases at leave, server B loads 1-3 s later | B waits for the release then loads the final data from A |
| S3 | Server A "crashes" (stops refreshing); B loads | B is refused until `LOCK_TTL`, then takes over; A's late write is rejected |
| S4 | Autosave in flight (slow fake backend, 3 s), purchase or Pearl grant lands during the wait | dirty is not cleared; the next save writes the change; final store value contains it |
| S5 | Same as S4, then the player leaves before the next autosave | leave save writes the change (this reproduces SEC-2 on today's code in E0, then must pass on new code) |
| S6 | Leave save fails twice then succeeds | retried with backoff; lock released only after success |
| S7 | Leave save fails every time | profile kept in the retry table, error logged, no silent drop |
| S8 | Shutdown with 4 players and 4 s latency per save | all four saves started in parallel; completes inside about 25 s; lock released |
| S9 | Failed load (fake `GetAsync` throws 3 times) | `doNotSave`, no write ever happens for that key, `ProfileState = "failed"`; `save()` itself also refuses |
| S10 | Boot probe fails once then succeeds | store becomes available after retry instead of staying disabled |
| S11 | Migration shapes fed to `reconcile` and the loader: empty key, v1 record without `equippedBeam`, record with unknown extra fields, record with `_session` from a dead server, record with a `nil` stats table | every shape loads, unknown fields preserved, defaults filled, no error |
| S12 | Old code reading a new record (copy of today's `reconcile` run on a record with `_session`/`_rev`) | loads; fields ignored; writes preserve them |
| S13 | Lock heartbeat for an idle (clean) profile over 3 autosave periods | lock timestamp refreshed; not stolen by a second server |
| S14 | Flag `SAVE_LOCKING_ENABLED = false` | behaviour identical to today's code in S1-S13 where applicable (documents the rollback) |

## 3. Pearl, crew and validation tests (E1, `SaveBackend = memory`, Studio "Clients: 4" where players are needed)
| ID | Scenario | Expected |
|---|---|---|
| P1-P10 | the ten rows of the scenario table in `PEARL_ELIGIBILITY_DESIGN.md` | amounts match the table; no duplicate credit; Results shows per-player Pearls |
| P11 | Call the credit function twice with the same key | second call is a no-op |
| P12 | Player leaves, rejoins mid-run (same UserId, memory store) | earlier nights remain recorded; credit resumes next night |
| P13 | Everyone leaves (Abandoned) | already earned nights are kept; no bonus |
| P14 | `PEARL_PAYOUT_MODE = "legacy"` | exactly today's end-of-run behaviour |
| C1-C4 | crew cap acceptance criteria 1-3 in `CREW_CAP_AND_FUEL_DESIGN.md` | pass |
| F1 | Fuel multiplier for crew 1..4 with 0, 2 and 4 extra non-crew players connected | multiplier depends only on crew size |
| V1-V6 | acceptance criteria 1-6 in `VALIDATION_IMPROVEMENTS.md` | pass |
| R1 | Regression pass in E1: run to Night 1 with a 1-player crew, buy an item, equip, take the lamp, refuel, repair, leave, results, rematch | no console errors; same behaviour as before the change |

Not covered by any of the above and still required later: nights 2-13, boss nights, a real phone, a controller, and real two-server timing (E2).

## 4. Evidence that each test must leave
Test id, environment, number of logical servers/clients, the exact fake-backend settings (latency, failures), steps, expected and actual result, relevant console lines, pass/fail, and whether the test could have touched production data (answer must be "no" for every row). Emulated or simulated tests are labelled as such; nothing in E0/E1 is described as a real-player or real-phone test.

## 5. Preconditions the owner controls
- Open the scratch copy in its own Studio window (TASK-001 follow-up), close it afterwards.
- Decide whether to create the E2 test experience.
- Approve the implementation plan before any test code is added anywhere.
