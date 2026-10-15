# AUDITOR REPORT — TASK-009: First real profile save/load test (R2)

- **Date:** 2026-10-14
- **Authorized environment:** SaveTest place 128620546156998, universe 10770892134. Store `TEST_LK_ProfileStore_v2`, key `player_900000201`, 25 Pearls, one start/save/release/reload/release sequence.
- **Approvals:** auditor conditional acceptance of `R2_AUTHORIZATION_REQUEST.md`; owner "execute" in chat (18:22 UTC). Production Studio API access owner-reported OFF (18:04 UTC). Production and Outlaw City untouched.

## Result
**R2 passed.** A real ProfileStore session created the synthetic profile with the exact template, saved 25 Pearls (0.30 s), released (release confirmed from the stored record, not from `OnSessionEnd`), a fresh session loaded the same key with 25 Pearls and load count 2, and the second release completed. Final stored record: pearls 25, `SessionLoadCount` 2, no active session, `WasOverwritten` false. No DataStore error was logged, so no retries are evidenced. The `____PS` probe key was unchanged (the module did not re-initialize). The approval flag returned to false by itself.

## Phase A and B summary
Fresh pre-TASK-009 backup verified (`SaveTest_TASK-009_pre.rbxl`, SHA-256 `F4EDB18E…D31B`, scripts as in the live session, `PlayerData` unchanged). Production API OFF cited from the owner's message. A fresh Studio session was **not** used, for the reason given to the owner (the cloud SaveTest place lacks the test scripts; a reopened file has GameId 0); instead the already-loaded module was reused and the probe key proves no re-initialization. The workflow now has one guarded entrypoint (`R2SaveLoad`) restricted to the approved store, key and operations; the guard has per-operation approval flags; cached modules were avoided by recreating edited script instances; a dry run on fakes produced the same 5-write sequence. All six pre-execution conditions were met and documented.

## Findings
1. Save/load and release work with the real DataStore for a single session in this context.
2. `OnSessionEnd` fires about 10 microseconds after `EndSession()`, before the release write; completion must be checked against the stored record, as the test did.
3. In Edit mode, the library cannot use MessagingService (two errors, one per session). Saving is unaffected, but takeover messaging and `BindToClose` (TASK-008) both need a real server context to be tested.
4. `game.JobId` in this Edit context is a GUID, not empty; the earlier inference is withdrawn for this context.

## Implications
- Save data: one synthetic test record now exists in the SaveTest universe (`TEST_LK_ProfileStore_v2/player_900000201`, 25 Pearls, released). Nothing else changed. Gameplay, security, performance: none.

## Deviations
None from the approved scope. One earlier read of the test key was made during the pre-execution checks (read-only, documented).

## Updated approval status
| Item | Status |
|---|---|
| R1 (module initialization) | done (TASK-008) |
| R2 (single save/load) | **done, passed** |
| R3, R4, full matrix, legacy overwrite, v1 import, other keys | not approved, not done |
| Publishing SaveTest / production | not approved, not done |
| D1, D5-D13 | pending |
| D4 | owner-reported done |

## Next recommended test (not started)
**R3 in a real server context:** the same synthetic sequence plus a `BindToClose` release check and MessagingService subscription, on a second fresh key (for example `player_900000202`), run inside a Studio "Run" server session, with the game's own scripts accounted for (the game's `PlayerData` reads `__access_check` at server start, and with no player joining it writes nothing). This needs its own authorization request in the same format.

## Ready for acceptance?
Yes. Stopped after R2 as instructed.
