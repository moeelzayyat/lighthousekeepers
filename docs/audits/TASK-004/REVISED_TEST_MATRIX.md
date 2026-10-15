# Revised test matrix (TASK-004) — nothing has been run

## 0. Environments (revised)
| Env | What | DataStore exposure | Use |
|---|---|---|---|
| **E0** | Logic harness with an in-memory fake backend (latency, errors, concurrent writers) | none: no DataStoreService call | protocol logic only |
| **E1** | Scratch Studio copy of the backup opened from disk, `SaveBackend` hard-wired to memory and **Studio API access never enabled** | **unknown, not assumed safe** (a local file showed PlaceId 0/GameId 0 but Roblox's pages do not say it blocks data stores) | handler and gameplay logic (Pearl ledger, crew cap, fuel, validation) only; no real persistence assertions |
| **E3** | **Separate private test universe** (`TEST_ENVIRONMENT_PROPOSAL.md`) with real DataStores | real, isolated by universe, gated by test T0 | every persistence test below |
| — | Production place and production DataStores | production | never used for these tests |
Hard rules from TASK-003 stay: no Play, Save, Publish or script execution on any instance whose GameId/PlaceId has not just been verified; Outlaw City is never touched; no `RemoveAsync` and no writes to production keys; no restore of backups over saves.

## 1. Gate
| ID | Test | Expected |
|---|---|---|
| **T0** | In E3, read `player_11752219158` (the owner's production key) and the other production-shaped keys | all nil. Any data: stop everything |

## 2. Real-DataStore persistence tests (E3, after E0 passes)
| ID | Scenario | Expected |
|---|---|---|
| C1 | Two sessions for one key start simultaneously (one server with injectable identities, then two real servers) | exactly one owns; the other waits then is refused/kicked; no profile loaded without ownership |
| C2 | Live holder takeover: holder stops heartbeating (injected pause), contender takes over | contender loads the latest committed state; holder's next write is rejected; holder removes the player |
| C3 | Fencing: stale holder issues a delayed write after takeover | rejected, stored data unchanged |
| C4 | Repeated callbacks: external conflicting writes force `UpdateAsync` to re-run the transform; count invocations | correct final data, no double effect, transform pure |
| C5 | Ambiguous commit: wrapper performs the real write then throws | read-back by `saveId` resolves to success; no duplicate write |
| C6 | Throttling: exceed the per-server budget with 4 players and bursty changes | no data loss; backoff works; queue-full errors (301-304) handled |
| C7 | Shutdown: Creator Hub shutdown with 4 players and injected 3-5 s latency | all saved in parallel inside the 30 s window; ownership released; time measured |
| C8 | Leave and immediately rejoin a different (reserved) server | no rollback; second server sees final data after release |
| C9 | v1 fixtures into the v2 import (empty, missing `equippedBeam`, unknown fields, wrong types, large `counts`) plus re-import | every shape imports once and idempotently; a failed v1 read blocks play and writes nothing; v1 untouched |
| C10 | Mixed deployment: old build stays up, new build published, same player on both | the fork is demonstrated; the documented restart procedure removes old servers; stale-write detection works as designed |
| C11 | Version history: list versions, confirm one kept per UTC hour, restore a test key from an older version | recovery procedure works and its granularity is measured |
| C12 | Library given a legacy-shaped (v1) record in a TEST store | confirms (or refutes) the overwrite-with-empty behaviour; never repeated elsewhere |
| C13 | Pearl durability: credit then kill the server; failed leave-save then rejoin on the same server | saved state measured; missing nights re-granted exactly once; loss window recorded, not assumed |
| C14 | Autosave period and write budget with 4 players at the chosen interval | stays inside the budget; lock refresh and saves counted |
| C15 | DataStore failure at boot and at load (fault injection) | no play, retry message, no overwrite, re-probe works |
| C16 | Session-lost experience | the player sees the intended message; no crash; logs useful |
| C17 | Isolation audit: confirm no test performed a write outside the test universe | every session logs `GameId`/`PlaceId` at start and the log shows only the test universe |

## 3. Gameplay and handler tests (E1 for logic, E3 for real clients)
Pearl rows P1-P14 from TASK-003 updated by `PEARL_PAYMENT_AND_IDEMPOTENCY.md` (graded bonus table, durable `grants` re-grant), crew rows CC1-CC8 and fuel rows F1-F2 and validation rows V0-V9 from `CREW_FUEL_VALIDATION_REVISION.md`. First-voyage joining and harbor spectators use real clients in E3 because first-voyage routing depends on a real profile load.

## 4. Regression pass
Run to Night 1 with a one-player crew: buy an item, equip, take the lamp, refuel, repair, leave, results, rematch; then a four-client run in E3 through at least night 3 including a mid-run leave and replacement. No console errors; same behaviour as before.

## 5. Still not covered by this matrix
Nights 4-13 and boss nights, real phones, controllers, long soak, and real production load. These remain separate tasks.

## 6. Evidence every row must leave
Test id, environment and verified IDs, number of real servers and clients, injected faults, steps, expected and actual, console lines, pass/fail, and whether the test could have touched production (must be "no").
