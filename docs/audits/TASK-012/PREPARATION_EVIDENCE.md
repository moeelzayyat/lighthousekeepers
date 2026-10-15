# TASK-012 PREPARATION EVIDENCE (no real test run)

Every Studio call below:
- ran in the SaveTest window (`Private lighthouse keepers (placeId: 128620546156998)`) in **Edit** mode;
- asserted both IDs;
- was preceded by a fresh `list_roblox_studios` in the session, which showed production `(132065051336560)`, Outlaw City `(132163592957463)` and SaveTest.

The dry runs use `MockBackend`: in-memory fake DataStore, MessagingService and RunService, loading the vendor source text. They make **no real** DataStore, MessagingService, BindToClose or teleport call.

## 1. Phase A
| Check | Result |
|---|---|
| Read-only state check | Edit, not running. `Main.Enabled = false`. TestOnly hashes as before (ProfileStore `ad437372`, R3 runner `6083eca5`, guard `4d85ffc6` before this task). All approval flags false. |
| Owner backup | `SaveTest_TASK-012_pre.rbxl`, 840,982 B, header `<roblox!`, SHA-256 `89D64D2E75BF5967AFC7F73C58AEA971BD08C886DC37B1C2A03F1FCF8009D1F6` |
| Backup content (Rojo 7.7.1 syncback to `work\savetest-pre012-export`) | `ServerScriptService.Server.Main` has `Disabled: true`. Guard `194e30d3…400b`, R4 runner `1a125835…7613`, R3 runner `6083eca5…b733` and ProfileStore `ad437372…95f` all match. R5 module and bootstrap are not present: they were installed after the save. |

## 2. Installed in SaveTest (Edit; inert)
| Instance | SHA-256 (in Studio = on disk) | State |
|---|---|---|
| `ServerStorage.TestOnly.SaveTestGuard` | `194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b` | adds `R4_SHUTDOWN_RELEASE` and `R5_CROSS_SERVER` (flags false). Replaced by a fresh clone so that `require` sees the edit. |
| `ServerStorage.TestOnly.R4ShutdownRunner` | `1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613` | ModuleScript, never auto-runs |
| `ServerStorage.TestOnly.R5CrossServer` | `ed6765f9cdec4da25858b8404dfb6bc5125afe942be3f1acad43ccbe569a93e6` | ModuleScript, never auto-runs (refreshed clone after its last edit) |
| `ServerScriptService.TestOnly_R5Bootstrap` | `85d7bae626e95e988ad4b48ff2b977d7ca7bc13afd3e8df9cdfa28545c00c17f` | **Enabled = false, no attributes**. It also returns at its first line in Studio. |

All of these compile (compile-only check). The six command files compile too, and their in-Studio hashes equal the on-disk hashes. These are listed in the authorization request, section 4 of the package.

## 3. R4 refusals and dry run
- `startReal()` without approval was refused: "SaveTestGuard ABORT: operation not approved: R4_SHUTDOWN_RELEASE".
- `startReal()` with the flag set, in Edit, was refused: "R4 ABORT: must run in a running server". The flag was reset, and the status stayed `idle`.
- `runMock` (with the vendor's own BindToClose invoked from the fake as a simulated Stop): `mockPassed = true`.
  - Holding: stored `pearls 0`, `ActiveSession [128620546156998, "", <GUID>]`, load count 1; memory `pearls 40`.
  - After the simulated shutdown: stored `pearls 40`, no `ActiveSession`, load count 1. The observer reported `released = true`.
  - Writes: `SetAsync ____PS/____PS` (fake probe), then 2 × `UpdateAsync TEST_LK_ProfileStore_v2/player_900000203`.

## 4. R5 dry run, normal path (two fake servers `JOB_A` and `JOB_B`, one shared fake store and messaging)
- Completed in 6.6 s, both roles completed without error, and the flag was reset.
- The evaluator returned all 12 checks **true**:
  - bothResultsPresent;
  - distinctNonEmptyJobIds;
  - serverTypes (skipped in the mock, because fake servers have no PrivateServerId);
  - handoverEndedOnA;
  - handoverViaMessaging;
  - handoverLoadedLatestCommitted (55);
  - singleOwnerAfterHandover;
  - staleOverwriteBlocked (stored 80, never 999);
  - staleHolderSessionEnded;
  - newOwnerUnaffected;
  - allSessionsReleased;
  - finalValues (60 and 80).
- `takeoverSeconds = 5.0`. One message was published: B's request to A.
- Fake writes, in order:
  1. 2 × `SetAsync ____PS/____PS`. These are fake Studio probes, one per fake server; live servers do not probe.
  2. 204: A start, A save.
  3. 205: A start, A save.
  4. 204: B force-load request, A release, B acquire.
  5. 205: B steal, B save 80, A fenced attempt.
  6. Results A.
  7. 205: B re-save.
  8. 204: B save 60, B release.
  9. 205: B release.
  10. Results B.

  That is 7 writes on 204, 7 on 205 and 2 results records.

## 5. R5 dry run, failure branch (fake MessagingService drops every message: an unresponsive holder)
- Completed in 240.4 s and both roles finished. The flag was reset. 5 messages were published, and none was delivered.
- **B:**
  - took 204 by the library's steal after **45.1 s** (`resolvedBy = "steal after timeout"`);
  - loaded **50**, the last committed value. A's unsaved 55 was lost;
  - stole 205 and saved 80;
  - released both keys;
  - final values 60 and 80.
- **A:**
  - never learned of the 204 takeover;
  - error "A: handover never happened" after the 240 s wait;
  - never reached its 999 attempt;
  - its recovery `EndSession` calls were fenced: the stored values remained 60 and 80, and both keys stayed released.
- Evaluator:

  | Check | Result |
  |---|---|
  | handoverEndedOnA | **false** |
  | handoverViaMessaging | **false** |
  | handoverLoadedLatestCommitted | **false** |
  | staleOverwriteBlocked | **false** (not exercised) |
  | staleHolderSessionEnded | **false** |
  | distinctNonEmptyJobIds, singleOwnerAfterHandover, newOwnerUnaffected, allSessionsReleased, finalValues | true |

  So a live run in this condition is reported as **failed**, with the takeover time recorded.
- Writes: 22 fake writes, including 2 fake probes, so 20 real-equivalent.
- An earlier run of the same branch, made before the evaluator and the 320 s mock wait were added, ended its harness after 200 s while A was still waiting. It is superseded by this run.
