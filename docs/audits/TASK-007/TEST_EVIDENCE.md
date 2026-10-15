# TEST EVIDENCE — TASK-007

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (PlaceId 128620546156998, GameId 10770892134), Edit mode, no Play session. Players: none. Device/emulator: none.
**Could any test have changed production DataStore values? No.** No call targeted a production instance. No real `DataStoreService` call was made in this task: the mock tests ran the vendor text against in-memory fakes, and the real `ProfileStore` ModuleScript was never required.

## 1. Identity and backups
| # | Check | Result |
|---|---|---|
| 1 | Studio instances re-listed (several times) | production `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, SaveTest `(128620546156998)`; production's instance id changed during the task (cause not established); Outlaw City untouched |
| 2 | SaveTest identified by both IDs inside scripts, asserted before every edit-adjacent run | PlaceId 128620546156998, GameId 10770892134, not production |
| 3 | Production Studio API access | **owner-reported ON** (Claude cannot read it); also owner-reported ON for SaveTest. Recorded as a live-data risk for any Play or script in the production window |
| 4 | Pre-edit SaveTest backup `backups\2026-10-14\savetest\SaveTest_pre-TASK-007.rbxl` | 809,189 bytes, SHA-256 `D2AC31D6E1ACCABF86DBB51D71360DEF798770184D95F4291A24E2779BA9B05A`, valid header; Rojo export: 501 files, 40 of 40 scripts identical to v148, 5 JSON files differ only in key order |
| 5 | Pinned vendor file before use | `vendor-review\ProfileStore_45c9847\ProfileStore.luau` size 64,654, SHA-256 `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F` equals the recorded value, unchanged |

## 2. Installation verification (the main result)
| # | Check | Result |
|---|---|---|
| 6 | Owner saved the SaveTest window to `backups\2026-10-14\savetest\SaveTest_TASK-007_integrated.rbxl` (owner typed `.rblx` in chat; the file on disk is `.rbxl`) | 832,148 bytes, valid header, SHA-256 `45CF80C3784E9C8C13DFC68387D8C205C4C9B7B82F9DC4ED0E9FFADA3FAB54D6` |
| 7 | Rojo export of that file: installed `ServerStorage\TestOnly\ProfileStore.luau` | **64,654 bytes, SHA-256 `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F`: identical to the pinned file** |
| 8 | Other installed scripts vs files on disk | `SaveTestGuard`, `MockBackend`, `MockTests`, `Sha256` all byte-identical |
| 9 | What changed versus the pre-edit export | exactly 11 new files, all under `ServerStorage\TestOnly\`; 5 JSON key-order-only differences as before; no other file differs |
| 10 | References to the new scripts outside `TestOnly` | none (grep over the exported tree) |
| 11 | In-Studio block hashes during installation (own SHA-256 helper, vectors "abc" and "" verified) | all 100-line blocks of lines 1-1400 matched the pinned blocks; the helper scripts matched their file hashes; later blocks were verified by item 7 instead (one in-Studio check was denied by the permission system, see 14) |
| 12 | Parse-check (`loadstring`, compile only, never called), run after the owner's explicit allowance | `SaveTestGuard`, `Sha256`, `MockBackend`, `MockTests`, `ProfileStore`: all compile; no leftover `@NEXT@` marker |
| 13 | Installed script line count | `ProfileStore` has 2,243 lines, last line `return ProfileStore` |
| 14 | A read-only hash check was denied by the permission system as "Untrusted Code Integration" mid-install. Claude did not retry or work around it; the owner then explicitly allowed `execute_luau` for the parse-check and fake-backend tests in the SaveTest window | recorded |

## 3. Fake-backend test results (vendor text vs in-memory fakes; real module never required)
| Test | Result | Observation |
|---|---|---|
| M0 Studio probe and options | PASS | the `____PS` write landed on the **fake** store exactly once; `SetExperimentalFeatures({v2=true})` called; state "Access"; 1 `BindToClose` callback registered |
| M1 record shape | PASS | top-level keys `Data`, `GlobalUpdates`, `MetaData`; `SessionLoadCount` 1; `ActiveSession` = {PlaceId, JobId, GUID}; release wrote final data and cleared the session |
| M2 legacy v1-shaped record, normal start | PASS (reproduced) | loaded profile has template data (pearls 0); stored record now wrapped, legacy top-level fields gone, seeded 500 pearls lost; `OnOverwrite` fired once |
| M3 legacy record + Cancel true from the first call | FAIL against my expectation, explained | returned nil and the record was **unchanged** (legacy pearls kept): an already-true Cancel stops the loop before any DataStore call. My earlier addendum statement was too strong (see `CORRIGENDUM_D2_ADDENDUM.md`) |
| M3b (ad hoc) legacy record + Cancel false then true mid-load | observed | returned nil **and the legacy record was overwritten** (wrapper present, legacy pearls gone, stored pearls 0) |
| M4 `GetAsync` view of a legacy record | PASS | returns a profile with template data (pearls 0), the stored legacy record unchanged, 0 writes |
| M5 two servers, responsive holder | PASS | second server took over in 0.24 s (scaled constants); it saw the holder's unsaved change (11); holder's session ended; `SessionLoadCount` 2; active job JOB_B; 1 message published |
| M6 fencing after takeover | PASS | stale holder's later write ignored (stored 50); stale holder inactive |
| M7 unresponsive holder (messages dropped, scaled constants 0.2/0.2/0.8 s) | PASS | takeover after 1.07 s; the holder's late write (777) did not land (stored 4); holder ended; active job JOB_B |
| M8 dead lock (`LastUpdate` 1000 s old) | PASS | immediate takeover (< 1 ms) with the stored data |
| M9 failed save not retried; release retries | PASS | injected failure on a normal `Save`: stored value unchanged after 1.5 s (no self-retry); release with 2 injected failures succeeded in 3.07 s (1 s + 2 s backoff) |
| M10 second start for an active key | PASS | throws "is already loaded in this session" |
| M11 new key + Cancel true from the first call | PASS | returns nil, no record created |
| M11b (ad hoc) new key + Cancel false then true | observed | returns nil but **creates a record** with template data and no active session |
| M12 shutdown | PASS | both profiles released in parallel (0.43 s for two 0.4 s calls); `IsClosing` true; later start returns nil |
| M13 equal JobId on two "servers" | PASS (weakness shown) | both profiles active at once; a lock keyed on PlaceId+JobId cannot distinguish servers with the same JobId (logic demonstration only; I did not establish what `game.JobId` is in Studio) |
| M14 guard behaviours | PASS | forbidden production store name rejected; non-`TEST_LK_` name rejected; real-module require blocked while unapproved; name lengths 23/18/23 (limit 50); approval flag false |

14 of the 15 listed tests (M0 to M14) passed as written; M3 differed from my expectation for an understood reason; M3b and M11b were run ad hoc to settle the question (`luau\adhoc_cancel_midflight.luau`).

## 4. Not performed (all need explicit approval, see `WRITE_OPERATIONS_AND_NEXT_APPROVALS.md`)
Loading the real module; any real DataStore write beyond the earlier canary; published-server tests; real throttling, latency and timing; ProfileStore against real records; Play sessions; production or Outlaw City anything.

## 5. Console output, screenshots, performance
Only the script return values quoted above. No screenshots or performance measurements.
