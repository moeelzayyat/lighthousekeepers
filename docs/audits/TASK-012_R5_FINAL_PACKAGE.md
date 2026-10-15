# TASK-012 R5 FINAL AUTHORIZATION PACKAGE (v3: supervised transport)

Combined plain-text package for the auditor. Nothing armed, nothing published, no live server. Hashes are SHA-256 of the exact file bytes (LF) and equal the in-Studio hashes. R4 remains as in R4_EXECUTION_APPROVAL_REQUEST.md, awaiting the owner's "execute R4".

## Contents
1. docs/audits/TASK-012/R5_FINAL_AUTHORIZATION_REQUEST.md (9022 bytes, SHA-256 004e0c545c05ab4794d55fb9ef378d9d2b1c878cfbddacac6890f6a60e15574b)
2. docs/audits/TASK-012/raw/R5v3_mock_all_12.json (9684 bytes, SHA-256 068354586c58987bd867d296e1f6b6ca2beda08db884b86d8304d456c566834f)
3. docs/audits/TASK-012/raw/R5v3_mock_all_12.NOTE.txt (553 bytes, SHA-256 ca83398fe30541a3979c350fe19cd0776ba983c2db171bac907b59975292ddf9)
4. docs/audits/TASK-012/luau/r5v3/R5CrossServer.luau (50595 bytes, SHA-256 ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4)
5. docs/audits/TASK-012/luau/r5v3/TestOnly_R5Bootstrap.server.luau (4796 bytes, SHA-256 646ac454440bb516b3508903420bbc79d74576f4849675cb4a87ae308041f26c)
6. docs/audits/TASK-012/luau/r5v3/SaveTestGuard.luau (6570 bytes, SHA-256 2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57)
7. docs/audits/TASK-012/luau/r5v3/R5v3_install_command.luau (1487 bytes, SHA-256 80ee4baabda9be3e448dfa1eb56a519a3a95a12bc404fe3e9954501ecc7b0186)
8. docs/audits/TASK-012/luau/r5v3/R5v3_arm_command.luau (2812 bytes, SHA-256 04dbf61a734ceb213114279c4361e99f36c11809056a0741535b89eee4c68b29)
9. docs/audits/TASK-012/luau/r5v3/R5v3_results_check.luau (2442 bytes, SHA-256 e6b24afd5b3133a96b0ec42f4c775fb39d6cb00c0a2dcf4df4225061af3a067d)
10. docs/audits/TASK-012/luau/r5v3/R5v3_disarm_command.luau (937 bytes, SHA-256 fe28a7c35c75e49b3738fbc11a46bcb3bdc88598529fe2774192c979a77a1e8c)

=== FILE: docs/audits/TASK-012/R5_FINAL_AUTHORIZATION_REQUEST.md ===
# R5 FINAL AUTHORIZATION REQUEST (v3: supervised transport)

- **Date:** 2026-10-14
- **Status:** nothing armed, nothing published, no live server started, and no real DataStore, MessagingService or teleport call for R5.
- **Where the code is:** v3 is staged in `ServerStorage.TestOnly_R5v2Staging` (the folder name is kept from v2). R4's checked scripts are unchanged: guard `194e30d3…`, R4 runner `1a125835…`, ProfileStore `ad437372…`, all re-verified in Studio after staging.

## 1. The correction
Role A's reservation, B assignment and teleport now run as **one supervised task** (`R5.newTransport`) with the stages `wait_account2 → reserve → assign → teleport → await_b`.

**Durable outcome.** `A.transport` is written into A's results record. It holds:
- `outcome`: `success`, `failed`, `timeout`, `deadline`, `cancelled`, `unresolved` or `late_success`;
- `error`, `seconds`, `privateServerId`, `cancelled`, `marked`;
- the timed stage log.

**What counts as each outcome:**
- **Success** means the run record shows B started (`bNonce` set) in the assigned PrivateServerId.
- **Failure** is any one of:
  - `ReserveServer` raised an error or returned no PrivateServerId;
  - the assignment was not recorded;
  - the `TeleportAsync` call failed;
  - a `TeleportInitFailed` report arrived for account 2. The bootstrap listens for these; this is new in v3.
- **Timeout** means no B start within 90 s of the teleport call, or account 2 never joined A within 240 s.

**No unresolved task:**
- Role A stops waiting for the handover as soon as the transport fails.
- `serverMain` **joins** the task before writing A's results.
- At the 30 s join limit the task is cancelled; every stage checks that flag before it acts.
- If the task is still blocked inside an engine call after that, the outcome is `unresolved` and the run record is closed.

**Late arrivals.** Any non-success outcome is written to the run record with `markTransport`, which moves the state to `TRANSPORT_*`. It commits only while B has not started, so a B that arrives late finds no `B_ASSIGNED` state and is refused with zero writes. If B started just before the mark, the mark cancels and the outcome is `late_success`, which still counts as a failure.

**Failure classes** are recorded separately in each results record (`failureClass`):
- `transport` (moving account 2; never reported as a handover problem);
- `handover` (ProfileStore/MessagingService);
- `fencing`;
- `final`;
- `deadline`;
- `setup`;
- `crash`.

## 2. Code (SHA-256: on disk equals in Studio; all compile)
| File (`luau\r5v3\`) | Bytes | SHA-256 |
|---|---|---|
| `R5CrossServer.luau` (v3, staged) | 50,595 | `ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4` |
| `SaveTestGuard.luau` (unchanged from v2) | 6,570 | `2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57` |
| `TestOnly_R5Bootstrap.server.luau` (v3: TeleportInitFailed listener) | 4,796 | `646ac454440bb516b3508903420bbc79d74576f4849675cb4a87ae308041f26c` |
| `R5v3_install_command.luau` (after R4) | 1,487 | `80ee4baabda9be3e448dfa1eb56a519a3a95a12bc404fe3e9954501ecc7b0186` |
| `R5v3_arm_command.luau` (template; only `__USER_ID_1__` and `__USER_ID_2__` are substituted) | 2,812 | `04dbf61a734ceb213114279c4361e99f36c11809056a0741535b89eee4c68b29` |
| `R5v3_results_check.luau` (read-only; adds bootstrap presence) | 2,442 | `e6b24afd5b3133a96b0ec42f4c775fb39d6cb00c0a2dcf4df4225061af3a067d` |
| `R5v3_disarm_command.luau` | 937 | `fe28a7c35c75e49b3738fbc11a46bcb3bdc88598529fe2774192c979a77a1e8c` |

## 3. Failure-test evidence (all on fakes, `raw\R5v3_mock_all_12.json`)
Every scenario goes through the real `serverMain`, including the presence gate, the claim, the run record and the roles. The fakes inject the failure.

| Scenario | Transport outcome | A's result | Run record | Keys afterwards | Late writes |
|---|---|---|---|---|---|
| full (regression) | success (3.1 s) | completed; **all 5 groups pass** | `A_CLAIMED>B_ASSIGNED>B_STARTED>A_FINISHED>B_FINISHED` | 204 = 60, 205 = 80, released | 0 |
| **teleportDelayed** (B starts 10 s after the call) | success (12.1 s) | completed; **all 5 groups pass** | same as full | 60 / 80, released | 0 |
| **reserveFails** | failed: "ReserveServer failed …" | `failureClass = transport` | `A_CLAIMED>TRANSPORT_FAILED>A_FINISHED` | 55 / 70, released | 0 |
| teleportCallFails | failed: "TeleportAsync failed …" | `transport` | `…B_ASSIGNED>TRANSPORT_FAILED>A_FINISHED` | 55 / 70, released | 0 |
| **teleportInitFails** (call returns, report 3 s later) | failed: "TeleportInitFailed …" | `transport` | `…B_ASSIGNED>TRANSPORT_FAILED>A_FINISHED` | 55 / 70, released | 0 |
| teleportLate (B arrives after the 4 s test limit) | timeout | `transport` | `…B_ASSIGNED>TRANSPORT_TIMEOUT>A_FINISHED` | 55 / 70, released | 0; the late B was **refused at claim** |
| **deadlineInTransportPrep** (deadline while ReserveServer runs) | deadline: "run deadline reached at stage reserve" | `failureClass = deadline`, partial results written | `A_CLAIMED>TRANSPORT_DEADLINE>A_FINISHED` | 55 / 70, released | 0 |
| transportUnresolved (ReserveServer blocks 30 s, join limit 3 s) | **unresolved**, cancelled | `transport` | `A_CLAIMED>TRANSPORT_UNRESOLVED>A_FINISHED` | 55 / 70, released | **0, even after the blocked call returned** |
| raceA (regression) | — | exactly 1 owner of 3; 6 invocations, 2 re-invocations, 3 cancels | 1 write | — | — |
| noParticipant (regression) | — | both servers stop at `presence` | none | — | **0 writes**, ProfileStore never loaded |
| wrongB (regression) | — | wrong server and second B refused at `claim` | 1 write (first B) | — | — |
| deadline (regression; account 2 never comes) | deadline | partial results, `abortedByDeadline` | `aborted: deadline` | 55 / 70, released | — |

In every failure case, ProfileStore handover and fencing were **not attempted**, so they cannot be blamed. The evaluator's `handover` and `fencing` groups fail as "not reached", and the cause is `failureClass = transport` (or `deadline`).

## 4. How a live run is reported (`R5.evaluate`, independent groups)
- **runRecord:** both results present, same RunId, owners equal the results' JobIds, transitions, both finished `completed`.
- **transport:** outcome `success`, reserved-server association (A's PrivateServerId equals the record's equals B's), server types, distinct non-empty JobIds.
- **handover:** ended on A, via messaging, B loaded the latest committed value (55), one owner after the handover.
- **fencing:** the stale write was blocked (80, never 999), the stale holder's session ended, the new owner was unaffected.
- **final:** values 60 and 80, all sessions released, no deadline abort, no failure class.
- **cleanup:** reported outside the evaluator. It covers:
  - the disarm result;
  - `bootstrapPresent = false` in Studio;
  - the cleanup publish;
  - a final read showing every key released and both roles finished.

## 5. Writes
**A successful live run makes 21 writes**, with no probe in live servers:
- `player_900000204`: 7;
- `player_900000205`: 7;
- run record: 5 `UpdateAsync`;
- results: 2 `SetAsync`.

A failed transport makes at most: 6 profile writes (start, save and release on 204 and 205), 4 run-record writes (claim, assign, mark, finish) and 1 results write.

**The overall upper bound stays at 27.** Fixtures 201, 202 and 203 are read only.

## 6. How account 2 joins the private SaveTest
SaveTest stays **private**; making it public is not proposed. What I know and don't know:
- I have **not** verified which Roblox setting lets a second account play a private, user-owned experience.
- The likely route is adding account 2 as a **collaborator** on SaveTest only.
- **Check before arming, with zero writes:**
  - account 2 opens the SaveTest page while logged in and reports whether **Play** is offered;
  - it does **not** press Play;
  - the currently published SaveTest version may still have the game's `Main` enabled, so playing it could make the game save account 2's data in SaveTest.
- If Play is not offered, I stop and report. **No public setting is changed without your separate approval.**
- The first R5 publish replaces the live version with Main disabled and the armed bootstrap.

## 7. Order once approved (owner actions marked ★)
1. R4 runs first, on your "execute R4".
2. I install v3: `R5v3_install_command`, then the bootstrap v3 source by multi_edit. This is inert and hash-checked.
3. ★ Account 2 access check (section 6).
4. I arm with the two UserIds.
5. ★ Publish SaveTest.
6. ★ Account 1 joins first, then account 2.
7. I read results from Studio until both roles have finished.
8. ★ Both accounts leave.
9. I disarm.
10. ★ Cleanup publish.
11. I read the final state and build `TASK-012_AUDITOR_PACKAGE.md`.

## Approval requested
R5 v3 live execution exactly as above. It needs:
- your two account UserIds (for the arm template);
- the account 2 access confirmation;
- your two publishes of SaveTest only.
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R5v3_mock_all_12.json ===
```json
{
"full":{"ok":true,"seconds":8.262048600008712,"allPassed":true,"groupPassed":{"runRecord":true,"transport":true,"handover":true,"fencing":true,"final":true},"transport":{"outcome":"success","seconds":3.078946099849418,"cancelled":false},"runTransitions":"A_CLAIMED>B_ASSIGNED>B_STARTED>A_FINISHED>B_FINISHED","bServers":[{"server":"B:PSID-1","claimed":true,"phase":"role"}],"takeoverSeconds":5.013885900145397,"resultsA":{"completedWithoutError":true,"abortedByDeadline":false,"cleanupReleased":true},"keys":{"handover":{"pearls":60,"active":false,"forceLoad":false,"sessionLoadCount":2},"stolen":{"pearls":80,"active":false,"forceLoad":false,"sessionLoadCount":2}},"writesAfterAFinished":0,"writes":["SetAsync ____PS/____PS","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","SetAsync ____PS/____PS","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_R5_Run/<RunId>","UpdateAsync TEST_LK_R5_Run/<RunId>","UpdateAsync TEST_LK_R5_Run/<RunId>","SetAsync TEST_LK_R5_Results/<RunId>_A","UpdateAsync TEST_LK_R5_Run/<RunId>","SetAsync TEST_LK_R5_Results/<RunId>_B","UpdateAsync TEST_LK_R5_Run/<RunId>"]},
"teleportDelayed":{"ok":true,"seconds":18.466913499869407,"allPassed":true,"groupPassed":{"runRecord":true,"transport":true,"handover":true,"fencing":true,"final":true},"transport":{"outcome":"success","seconds":12.14551530010067,"cancelled":false},"runTransitions":"A_CLAIMED>B_ASSIGNED>B_STARTED>A_FINISHED>B_FINISHED","bServers":[{"server":"B:PSID-1","claimed":true,"phase":"role"}],"takeoverSeconds":5.0128601000178609,"resultsA":{"completedWithoutError":true,"abortedByDeadline":false,"cleanupReleased":true},"keys":{"handover":{"pearls":60,"active":false,"sessionLoadCount":2},"stolen":{"pearls":80,"active":false,"sessionLoadCount":2}},"writesAfterAFinished":0,"writesCount":23},
"reserveFails":{"ok":true,"seconds":2.2662342998664828,"allPassed":false,"transport":{"outcome":"failed","seconds":2.079531399998814,"cancelled":false,"marked":true,"error":"ReserveServer failed: R5CrossServer:1016: MOCK: ReserveServer HTTP 500"},"resultsA":{"completedWithoutError":false,"failureClass":"transport","error":"TRANSPORT failed: ReserveServer failed: R5CrossServer:1016: MOCK: ReserveServer HTTP 500","abortedByDeadline":false,"cleanupReleased":true},"runTransitions":"A_CLAIMED>TRANSPORT_FAILED>A_FINISHED","runTransportOutcome":"failed","bServers":[],"keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesAfterAFinished":0,"writes":["SetAsync ____PS/____PS","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_R5_Run/<RunId> (claimA)","UpdateAsync TEST_LK_R5_Run/<RunId> (markTransport failed)","SetAsync TEST_LK_R5_Results/<RunId>_A","UpdateAsync TEST_LK_R5_Run/<RunId> (finish A)"]},
"teleportCallFails":{"ok":true,"seconds":2.5489142001606526,"allPassed":false,"transport":{"outcome":"failed","seconds":2.0800936000887306,"cancelled":false,"marked":true,"error":"TeleportAsync failed: MOCK: TeleportAsync raised an error"},"resultsA":{"completedWithoutError":false,"failureClass":"transport","error":"TRANSPORT failed: TeleportAsync failed: MOCK: TeleportAsync raised an error","abortedByDeadline":false,"cleanupReleased":true},"runTransitions":"A_CLAIMED>B_ASSIGNED>TRANSPORT_FAILED>A_FINISHED","runTransportOutcome":"failed","bServers":[],"keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesAfterAFinished":0,"writes":["SetAsync ____PS/____PS","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_ProfileStore_v2/player_900000204","UpdateAsync TEST_LK_ProfileStore_v2/player_900000205","UpdateAsync TEST_LK_R5_Run/<RunId> (claimA)","UpdateAsync TEST_LK_R5_Run/<RunId> (assignB)","UpdateAsync TEST_LK_R5_Run/<RunId> (markTransport failed)","SetAsync TEST_LK_R5_Results/<RunId>_A","UpdateAsync TEST_LK_R5_Run/<RunId> (finish A)"]},
"teleportInitFails":{"ok":true,"seconds":5.399836899945512,"allPassed":false,"transport":{"outcome":"failed","seconds":5.097600300097838,"cancelled":false,"marked":true,"error":"TeleportInitFailed: MOCK: Flooded"},"resultsA":{"completedWithoutError":false,"failureClass":"transport","error":"TRANSPORT failed: TeleportInitFailed: MOCK: Flooded","abortedByDeadline":false,"cleanupReleased":true},"runTransitions":"A_CLAIMED>B_ASSIGNED>TRANSPORT_FAILED>A_FINISHED","runTransportOutcome":"failed","bServers":[],"keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesAfterAFinished":0,"writesCount":12},
"teleportLate":{"ok":true,"seconds":15.367002599872649,"allPassed":false,"transport":{"outcome":"timeout","seconds":6.112400999991223,"cancelled":false,"marked":true,"error":"B did not start in the assigned server within 4 s"},"resultsA":{"completedWithoutError":false,"failureClass":"transport","error":"TRANSPORT timeout: B did not start in the assigned server within 4 s","abortedByDeadline":false,"cleanupReleased":true},"runTransitions":"A_CLAIMED>B_ASSIGNED>TRANSPORT_TIMEOUT>A_FINISHED","runTransportOutcome":"timeout","bServers":[{"server":"B:PSID-1","claimed":false,"phase":"claim","error":"R5CrossServer:762: this reserved server is not the one the run record names"}],"keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesAfterAFinished":0,"writesCount":12},
"deadlineInTransportPrep":{"ok":true,"seconds":22.282091100001709,"allPassed":false,"transport":{"outcome":"deadline","seconds":22.0622990000993,"cancelled":false,"marked":true,"error":"run deadline reached at stage reserve"},"resultsA":{"completedWithoutError":false,"failureClass":"deadline","error":"R5 DEADLINE reached before step A5_handover","abortedByDeadline":true,"cleanupReleased":true},"runTransitions":"A_CLAIMED>TRANSPORT_DEADLINE>A_FINISHED","runTransportOutcome":"deadline","bServers":[],"keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesAfterAFinished":0,"writesCount":11},
"transportUnresolved":{"ok":true,"seconds":46.766169799957427,"allPassed":false,"transport":{"outcome":"unresolved","cancelled":true,"marked":true,"error":"still blocked at stage reserve after the join limit; cancelled"},"resultsA":{"completedWithoutError":false,"failureClass":"transport","error":"TRANSPORT running at stage reserve: B never started while A waited","abortedByDeadline":false,"cleanupReleased":true},"runTransitions":"A_CLAIMED>TRANSPORT_UNRESOLVED>A_FINISHED","runTransportOutcome":"unresolved","bServers":[],"keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesAfterAFinished":0,"writesCount":11},
"raceA":{"ok":true,"seconds":1.2989584000315518,"exactlyOneOwner":true,"winners":["JOB_A3"],"losers":["JOB_A1: R5CrossServer:755: lost the run claim to another server","JOB_A2: R5CrossServer:755: lost the run claim to another server"],"runOwner":"JOB_A3","invocations":6,"reinvocations":2,"cancels":3,"writes":["UpdateAsync TEST_LK_R5_Run/<RunId>"],"flagReset":true},
"noParticipant":{"ok":true,"seconds":10.083169900113717,"zeroWrites":true,"writes":[],"profileStoreLoaded":0,"publicServer":{"ok":false,"phase":"presence","error":"R5CrossServer:737: designated account A never joined this server"},"reservedServer":{"ok":false,"phase":"presence","error":"R5CrossServer:737: designated account B never joined this server"},"flagReset":true},
"wrongB":{"ok":true,"seconds":8.232335800072179,"wrongServer":{"ok":false,"claimed":false,"phase":"claim","error":"R5CrossServer:762: this reserved server is not the one the run record names"},"firstB":{"claimed":true,"phase":"role","error":"R5CrossServer:1229: STOP_AFTER_CLAIM"},"secondB":{"claimed":false,"phase":"claim","error":"R5CrossServer:762: this reserved server is not the one the run record names"},"writesAfterSetup":["UpdateAsync TEST_LK_R5_Run/<RunId> (startB, first B only)"],"flagReset":true},
"deadline":{"ok":true,"seconds":12.333256900077686,"summary":{"ok":true,"phase":"role","resultWritten":true},"partialResults":{"steps":6,"abortedByDeadline":true,"error":"R5 DEADLINE reached before step A5_handover","cleanupReleased":true},"runFinished":"aborted: deadline","keys":{"handover":{"pearls":55,"active":false,"sessionLoadCount":1},"stolen":{"pearls":70,"active":false,"sessionLoadCount":1}},"writesCount":11,"flagReset":true}
}
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R5v3_mock_all_12.NOTE.txt ===
```text
R5v3_mock_all_12.json was copied from the Studio output of the R5 v3 mock run (2026-10-14, about 20:45Z), all on in-memory fakes.

To keep the file short:
- RunIds are replaced by <RunId>.
- The "ServerStorage.TestOnly_R5v2Staging." prefix is dropped from error locations.
- Write lists that repeat the full scenario's pattern are given as writesCount. That count includes the fake ____PS probe writes, which do not happen in live servers.
- Short annotations in parentheses name the transform behind a run-record write.

All other values are verbatim.
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/R5CrossServer.luau ===
```lua
-- ServerStorage.TestOnly.R5CrossServer  (v3, TASK-012 auditor corrections)
-- SAVETEST ONLY. Two-server ownership test for PUBLISHED SaveTest servers. A ModuleScript: it never runs by itself.
-- In a live server it is started only by ServerScriptService.TestOnly_R5Bootstrap, which passes the real environment
-- to R5.serverMain(env) after its fail-closed gates. All decisions live here so they can be tested on fakes.
--
-- v2 corrections:
--  1. PLAYER-PRESENCE GATE. A makes no write until designated account 1 (by UserId) is in the server; B makes no
--     write until designated account 2 is in the reserved server that the run record names. No participant = zero
--     writes. ProfileStore is not even required before the gate passes.
--  2. ATOMIC RUN OWNERSHIP. One run = one RunId (set at arming). Role A must win an UpdateAsync claim on
--     TEST_LK_R5_Run/<RunId>; the transform is pure, so a re-invocation can never create a second owner, and a
--     re-invocation after our own commit is recognised by our nonce. B must prove it belongs to the same run: the
--     record names the reserved server A created for it (PrivateServerId from ReserveServer, written by A before the
--     teleport) and account 2; B then claims its slot with its own UpdateAsync.
--  3. DEADLINE DURING EXECUTION. Every step checks the run deadline (AuthNotAfter - 300 s). Past it, the role stops,
--     ends every session it holds, waits for the stored release, records partial results and marks the run record.
-- v3 correction:
--  4. SUPERVISED TRANSPORT. Role A's reservation, B assignment and teleport run as one supervised task with a
--     durable outcome (success | failed | timeout | deadline | cancelled | unresolved) and the stage it reached.
--     Success means the run record shows B started in the assigned reserved server; failure includes a failed
--     reservation, a failed TeleportAsync call and a TeleportInitFailed report. Role A stops waiting for the
--     handover as soon as transport fails, and serverMain joins the task before writing A's results: A can never
--     finish with it unresolved. If it is still running at the join limit it is cancelled (every stage checks the
--     flag before acting). Any non-success outcome is written to the run record so a late B is refused.
--     Failures are classified separately: transport, handover, fencing, deadline, setup.
--
-- Stores and keys (Guard.OPERATIONS.R5_CROSS_SERVER):
--   TEST_LK_ProfileStore_v2/player_900000204, /player_900000205  (through ProfileStore only)
--   TEST_LK_R5_Run/<RunId>                                       (UpdateAsync, pure transforms below)
--   TEST_LK_R5_Results/<RunId>_A, /<RunId>_B                     (SetAsync, one per role)

local Guard = require(script.Parent.SaveTestGuard)
local R5 = {}

R5.OPERATION = "R5_CROSS_SERVER"
R5.TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}
R5.A_SAVED, R5.A_UNSAVED, R5.A_STOLEN_SAVED, R5.A_STALE_ATTEMPT = 50, 55, 70, 999
R5.B_STOLEN_SAVED, R5.B_HANDOVER_FINAL = 80, 60
R5.DEADLINE_MARGIN = 300 -- the run deadline is AuthNotAfter - 300 s, leaving time to release sessions
R5.TIMEOUTS = {
	presence = 600, -- how long a server waits for its designated account (capped by the deadline)
	bAssignment = 60, -- how long B waits for the run record to name it
	aWaitAccount2 = 240, -- how long A's transport task waits for account 2 to join server A
	transport = 90, -- after the teleport call: how long A waits for B to start in the assigned server
	transportJoin = 30, -- how long serverMain waits for the transport task to finish before cancelling it
	aWaitHandover = 240,
	aWaitSteal = 120,
	bWaitAReady = 60,
	bWaitAResults = 90,
	release = 30,
	save = 20,
}
R5.RUN_ID_PATTERN = "^R5RUN_%x+$"

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

local function summarize(r)
	local md = r and r.MetaData
	local as = md and md.ActiveSession
	return {
		exists = r ~= nil,
		pearls = r and r.Data and r.Data.pearls,
		activeJobId = type(as) == "table" and as[2] or nil,
		active = type(as) == "table",
		forceLoad = md and md.ForceLoadSession ~= nil or false,
		sessionLoadCount = md and md.SessionLoadCount,
	}
end

----------------------------------------------------------------------------------------------------------------------
-- Run record protocol. Every transform is PURE: it only reads its argument and returns a new value or nil (nil =
-- cancel, nothing is written). It is safe to invoke any number of times, as Roblox may do.
----------------------------------------------------------------------------------------------------------------------
R5.claim = {}

local function withHistory(rec, state, at, by)
	rec.state = state
	rec.history = rec.history or {}
	table.insert(rec.history, { state = state, at = at, by = by })
	return rec
end

-- spec = { runId, jobId, nonce, account1, account2, now, deadline }
function R5.claim.claimA(spec)
	return function(current)
		if current == nil then
			return withHistory({
				runId = spec.runId,
				aJobId = spec.jobId,
				aNonce = spec.nonce,
				account1 = spec.account1,
				account2 = spec.account2,
				claimedAt = spec.now,
				deadline = spec.deadline,
			}, "A_CLAIMED", spec.now, "A")
		end
		if type(current) == "table" and current.runId == spec.runId and current.aNonce == spec.nonce then
			return nil -- our own claim is already committed (re-invoked or retried call): nothing to write
		end
		return nil -- the run belongs to someone else: cancel, no write
	end
end

function R5.claim.isOwnerA(rec, spec)
	return type(rec) == "table" and rec.runId == spec.runId and rec.aNonce == spec.nonce and rec.aJobId == spec.jobId
end

-- A records the reserved server it created for B, before teleporting account 2 there.
function R5.claim.assignB(spec, bPrivateServerId, now)
	return function(current)
		if not R5.claim.isOwnerA(current, spec) then
			return nil
		end
		if current.state == "B_ASSIGNED" and current.bPrivateServerId == bPrivateServerId then
			return nil -- already recorded: nothing to write
		end
		if current.state ~= "A_CLAIMED" then
			return nil
		end
		current.bPrivateServerId = bPrivateServerId
		return withHistory(current, "B_ASSIGNED", now, "A")
	end
end

-- bSpec = { runId, jobId, nonce, privateServerId, account2, now }
function R5.claim.startB(bSpec)
	return function(current)
		if type(current) ~= "table" or current.runId ~= bSpec.runId then
			return nil
		end
		if current.bNonce ~= nil then
			if current.bNonce == bSpec.nonce then
				return nil -- our own start is already committed: nothing to write
			end
			return nil -- another B already started: cancel
		end
		if current.state ~= "B_ASSIGNED" or current.bPrivateServerId ~= bSpec.privateServerId
			or current.account2 ~= bSpec.account2 then
			return nil
		end
		current.bJobId = bSpec.jobId
		current.bNonce = bSpec.nonce
		return withHistory(current, "B_STARTED", bSpec.now, "B")
	end
end

-- A records a transport that did not succeed. Commits only while B has NOT started (state A_CLAIMED or B_ASSIGNED),
-- so a B that arrives later finds no B_ASSIGNED state and is refused. If B already started, it cancels (nil).
function R5.claim.markTransport(spec, outcome, now)
	return function(current)
		if not R5.claim.isOwnerA(current, spec) or current.bNonce ~= nil then
			return nil
		end
		if current.state ~= "A_CLAIMED" and current.state ~= "B_ASSIGNED" then
			return nil -- already marked or finished: nothing to write
		end
		current.transportOutcome = outcome
		return withHistory(current, "TRANSPORT_" .. string.upper(outcome), now, "A")
	end
end

function R5.claim.isOwnerB(rec, bSpec)
	return type(rec) == "table" and rec.runId == bSpec.runId and rec.bNonce == bSpec.nonce
		and rec.bPrivateServerId == bSpec.privateServerId
end

-- role = "A" | "B"; outcome = short string
function R5.claim.finish(spec, role, outcome, now)
	return function(current)
		if type(current) ~= "table" or current.runId ~= spec.runId then
			return nil
		end
		local nonceField = role == "A" and "aNonce" or "bNonce"
		if current[nonceField] ~= spec.nonce then
			return nil
		end
		local field = role == "A" and "aFinished" or "bFinished"
		if current[field] ~= nil then
			return nil -- already recorded: nothing to write
		end
		current[field] = outcome
		return withHistory(current, role .. "_FINISHED", now, role)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Waiting helpers that respect the run deadline
----------------------------------------------------------------------------------------------------------------------
local function makeClock(env, deadline)
	local clock = {}
	function clock.expired()
		return env.now() >= deadline
	end
	function clock.check(step)
		if clock.expired() then
			error("R5 DEADLINE reached before step " .. step, 0)
		end
	end
	-- waits until cond() is true, the timeout passes, or the deadline passes
	function clock.waitUntil(cond, timeout, interval)
		local t0 = os.clock()
		while true do
			local okC, res = pcall(cond)
			if okC and res then
				return true, os.clock() - t0
			end
			if os.clock() - t0 > timeout or clock.expired() then
				return false, os.clock() - t0
			end
			task.wait(interval or 0.25)
		end
	end
	return clock
end

-- Restricted ProfileStore view for one role.
function R5.restrict(PS, op, role)
	local proxy = {}
	function proxy.New(storeName, template)
		assert(storeName == op.store, "R5 ABORT: store not allowed: " .. tostring(storeName))
		local real = PS.New(storeName, template)
		local storeProxy = {}
		function storeProxy:StartSessionAsync(key, params)
			assert(key == op.keyHandover or key == op.keyStolen, "R5 ABORT: key not allowed: " .. tostring(key))
			if params ~= nil then
				assert(role == "B" and key == op.keyStolen, "R5 ABORT: params allowed only for B on the stolen key")
				local n = 0
				for _ in pairs(params) do
					n += 1
				end
				assert(n == 1 and params.Steal == true, "R5 ABORT: only { Steal = true } is allowed")
				return real:StartSessionAsync(key, { Steal = true })
			end
			return real:StartSessionAsync(key)
		end
		return storeProxy
	end
	return proxy
end

----------------------------------------------------------------------------------------------------------------------
-- Roles (unchanged sequence from v1; every step now checks the deadline)
----------------------------------------------------------------------------------------------------------------------
local function endAndWaitRelease(profiles, readKey, clockW)
	for _, p in ipairs(profiles) do
		if p ~= nil and p:IsActive() then
			p:EndSession()
		end
	end
	-- release is confirmed from the store; this wait is NOT capped by the deadline (cleanup must finish)
	local t0 = os.clock()
	while os.clock() - t0 < R5.TIMEOUTS.release do
		local allReleased = true
		for _, p in ipairs(profiles) do
			if p ~= nil then
				local okR, r = pcall(readKey, p.Key)
				local s = okR and summarize(r) or nil
				if s == nil or (s.active and s.activeJobId == clockW.jobId) then
					allReleased = false
				end
			end
		end
		if allReleased then
			return true
		end
		task.wait(1)
	end
	return false
end

local function roleA(deps, op, res)
	local clock = deps.clock
	local t0 = os.clock()
	local function note(step, data)
		data.step = step
		data.t = math.floor((os.clock() - t0) * 1000) / 1000
		table.insert(res.log, data)
	end
	local function raw(key)
		return deps.readRaw(op.store, key)
	end
	local myJob = deps.identity.jobId
	local store = deps.PS.New(op.store, R5.TEMPLATE)
	local p1, p2
	local failClass = "setup"
	local ok, err = pcall(function()
		note("A1_identity", deepCopy(deps.identity))
		clock.check("A2_precheck")
		assert(raw(op.keyHandover) == nil and raw(op.keyStolen) == nil, "R5 ABORT: test keys already exist")
		note("A2_precheck", { keysAbsent = true })

		clock.check("A3_start_handover_key")
		p1 = store:StartSessionAsync(op.keyHandover)
		assert(p1 ~= nil and p1:IsActive(), "A: handover key session failed")
		p1.Data.pearls = R5.A_SAVED
		p1:Save()
		assert(clock.waitUntil(function()
			return p1.LastSavedData ~= nil and p1.LastSavedData.pearls == R5.A_SAVED
		end, R5.TIMEOUTS.save), "A: save 50 not confirmed")
		p1.Data.pearls = R5.A_UNSAVED -- in memory only; must reach the store through the handover release
		note("A3_handover_key_held", { stored = summarize(raw(op.keyHandover)), memoryPearls = p1.Data.pearls })

		clock.check("A4_start_stolen_key")
		p2 = store:StartSessionAsync(op.keyStolen)
		assert(p2 ~= nil and p2:IsActive(), "A: stolen key session failed")
		p2.Data.pearls = R5.A_STOLEN_SAVED
		p2:Save()
		assert(clock.waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.A_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "A: save 70 not confirmed")
		note("A4_stolen_key_held", { stored = summarize(raw(op.keyStolen)) })

		res.readyAt = os.clock() - t0
		-- supervised transport (reserve, assign B, teleport account 2); A watches it while waiting for the handover
		failClass = "transport"
		local transport = deps.transport
		transport.start()

		local handedOver, hSecs = clock.waitUntil(function()
			return (not p1:IsActive()) or transport.failed()
		end, R5.TIMEOUTS.aWaitHandover, 0.25)
		handedOver = handedOver and not p1:IsActive()
		local afterHandover = summarize(raw(op.keyHandover))
		note("A5_handover", {
			endedByLibrary = handedOver,
			secondsWaited = hSecs,
			stored = afterHandover,
			transportOutcome = transport.snapshot().outcome,
		})
		res.handover = { endedByLibrary = handedOver, storedAfter = afterHandover }
		clock.check("A5_handover")
		if transport.failed() then
			error("TRANSPORT " .. transport.snapshot().outcome .. ": " .. tostring(transport.snapshot().error), 0)
		end
		if not handedOver and transport.snapshot().outcome ~= "success" then
			error("TRANSPORT " .. transport.snapshot().outcome .. " at stage " .. transport.snapshot().stage
				.. ": B never started while A waited", 0)
		end
		failClass = "handover"
		assert(handedOver, "A: handover never happened (transport " .. transport.snapshot().outcome .. ")")
		failClass = "fencing"

		local stolen, sSecs = clock.waitUntil(function()
			local s = summarize(raw(op.keyStolen))
			return s.active and s.activeJobId ~= myJob
		end, R5.TIMEOUTS.aWaitSteal, 1)
		local beforeAttempt = summarize(raw(op.keyStolen))
		note("A6_steal_observed", { stolen = stolen, secondsWaited = sSecs, stored = beforeAttempt, localStillActive = p2:IsActive() })
		clock.check("A6_steal")
		assert(stolen, "A: steal never observed")

		local activeBefore = p2:IsActive()
		p2.Data.pearls = R5.A_STALE_ATTEMPT
		p2:Save()
		local endedAfter, eSecs = clock.waitUntil(function()
			return not p2:IsActive()
		end, R5.TIMEOUTS.save, 0.25)
		local afterAttempt = summarize(raw(op.keyStolen))
		note("A7_stale_save_attempt", {
			localActiveBeforeAttempt = activeBefore,
			sessionEndedAfterAttempt = endedAfter,
			secondsToEnd = eSecs,
			stored = afterAttempt,
		})
		res.staleAttempt = {
			localActiveBeforeAttempt = activeBefore,
			sessionEndedAfterAttempt = endedAfter,
			storedPearlsAfter = afterAttempt.pearls,
			storedOwnerIsB = afterAttempt.active and afterAttempt.activeJobId ~= myJob,
			overwriteBlocked = afterAttempt.pearls ~= R5.A_STALE_ATTEMPT,
		}
	end)
	res.abortedByDeadline = clock.expired()
	res.failureClass = (not ok) and (res.abortedByDeadline and "deadline" or failClass) or nil
	res.cleanupReleased = endAndWaitRelease({ p1, p2 }, raw, { jobId = myJob })
	if not ok then
		note("A_cleanup", { because = tostring(err), failureClass = res.failureClass, released = res.cleanupReleased })
	end
	res.completedWithoutError = ok
	res.error = (not ok) and tostring(err) or nil
	return ok
end

local function roleB(deps, op, res)
	local clock = deps.clock
	local t0 = os.clock()
	local function note(step, data)
		data.step = step
		data.t = math.floor((os.clock() - t0) * 1000) / 1000
		table.insert(res.log, data)
	end
	local function raw(key)
		return deps.readRaw(op.store, key)
	end
	local myJob = deps.identity.jobId
	local store = deps.PS.New(op.store, R5.TEMPLATE)
	local p1, p2
	local failClass = "handover"
	local ok, err = pcall(function()
		note("B1_identity", deepCopy(deps.identity))
		local aReady = clock.waitUntil(function()
			local h, s = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
			return h.active and h.activeJobId ~= myJob and h.pearls == R5.A_SAVED
				and s.active and s.activeJobId ~= myJob and s.pearls == R5.A_STOLEN_SAVED
		end, R5.TIMEOUTS.bWaitAReady, 1)
		note("B2_a_ready_seen", { aReady = aReady })
		clock.check("B3_handover")
		assert(aReady, "B: server A is not holding both keys")

		local tReq = os.clock()
		p1 = store:StartSessionAsync(op.keyHandover)
		local takeoverSecs = os.clock() - tReq
		assert(p1 ~= nil and p1:IsActive(), "B: handover session failed")
		local h = summarize(raw(op.keyHandover))
		note("B3_handover_acquired", { takeoverSeconds = takeoverSecs, loadedPearls = p1.Data.pearls, sessionLoadCount = p1.SessionLoadCount, stored = h })
		res.handover = {
			takeoverSeconds = takeoverSecs,
			loadedLatestCommitted = p1.Data.pearls == R5.A_UNSAVED,
			loadedPearls = p1.Data.pearls,
			sessionLoadCount = p1.SessionLoadCount,
			storedOwnerIsB = h.active and h.activeJobId == myJob,
			resolvedBy = takeoverSecs < 30 and "messaging (A released)" or "steal after timeout",
		}

		failClass = "fencing"
		clock.check("B4_steal")
		local tSteal = os.clock()
		p2 = store:StartSessionAsync(op.keyStolen, { Steal = true })
		assert(p2 ~= nil and p2:IsActive(), "B: steal failed")
		local loadedStolen = p2.Data.pearls
		p2.Data.pearls = R5.B_STOLEN_SAVED
		p2:Save()
		assert(clock.waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.B_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "B: save 80 not confirmed")
		note("B4_stolen_and_saved", { stealSeconds = os.clock() - tSteal, loadedPearls = loadedStolen, stored = summarize(raw(op.keyStolen)) })

		local aDone = clock.waitUntil(function()
			return deps.readResult("A") ~= nil
		end, R5.TIMEOUTS.bWaitAResults, 1)
		clock.check("B5_resave")
		p2:Save()
		assert(clock.waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.B_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "B: re-save 80 not confirmed")
		local s = summarize(raw(op.keyStolen))
		note("B5_after_stale_attempt", { aResultsSeen = aDone, stored = s, stillActive = p2:IsActive() })
		res.stolen = {
			loadedPearls = loadedStolen,
			aResultsSeen = aDone,
			storedPearlsAfterAAttempt = s.pearls,
			stillOwnerAfterAAttempt = p2:IsActive() and s.active and s.activeJobId == myJob,
		}

		failClass = "final"
		clock.check("B6_final_save")
		p1.Data.pearls = R5.B_HANDOVER_FINAL
		p1:Save()
		assert(clock.waitUntil(function()
			return p1.LastSavedData ~= nil and p1.LastSavedData.pearls == R5.B_HANDOVER_FINAL
		end, R5.TIMEOUTS.save), "B: save 60 not confirmed")
	end)
	res.abortedByDeadline = clock.expired()
	res.failureClass = (not ok) and (res.abortedByDeadline and "deadline" or failClass) or nil
	local released = endAndWaitRelease({ p1, p2 }, raw, { jobId = myJob })
	local fh, fs = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
	note("B6_released", { bothReleased = released, handover = fh, stolen = fs })
	res.final = { bothReleased = released and not fh.active and not fs.active, handover = fh, stolen = fs }
	res.cleanupReleased = released
	res.completedWithoutError = ok and released
	res.error = (not ok) and tostring(err) or nil
	return res.completedWithoutError
end

----------------------------------------------------------------------------------------------------------------------
-- Role A's supervised transport task: wait_account2 -> reserve -> assign -> teleport -> await_b.
-- outcome: success | failed | timeout | deadline | cancelled | unresolved | late_success. It is terminal (done) only
-- after a non-success outcome has also been written to the run record (markTransport), so a late B is refused.
----------------------------------------------------------------------------------------------------------------------
function R5.newTransport(env, clock, spec, a, update, get, op, runId)
	local t = { outcome = "not_started", stage = "none", log = {}, cancelled = false, done = false }
	local t0
	local function stage(name, detail)
		t.stage = name
		table.insert(t.log, { stage = name, t = t0 and math.floor((os.clock() - t0) * 1000) / 1000 or 0, detail = detail })
	end
	local function fail(kind, msg)
		error({ kind = kind, msg = msg }, 0)
	end
	local function stopIfCancelledOrLate()
		if t.cancelled then
			fail("cancelled", "cancelled by role A at stage " .. t.stage)
		end
		if clock.expired() then
			fail("deadline", "run deadline reached at stage " .. t.stage)
		end
	end
	local function markRecord(outcome)
		local okM = pcall(update, op.runStore, runId, R5.claim.markTransport(spec, outcome, env.now()))
		local okG, r = pcall(get, op.runStore, runId)
		r = okG and r or nil
		if t.privateServerId ~= nil and type(r) == "table" and r.bNonce ~= nil and r.bPrivateServerId == t.privateServerId then
			return "late_success" -- B started before the mark could commit: the mark was cancelled atomically
		end
		t.marked = okM and type(r) == "table" and r.transportOutcome == outcome
		return outcome
	end

	local transport = {}
	function transport.snapshot()
		return {
			outcome = t.outcome,
			stage = t.stage,
			error = t.error,
			seconds = t.seconds,
			privateServerId = t.privateServerId,
			marked = t.marked,
			done = t.done,
			cancelled = t.cancelled,
			log = deepCopy(t.log),
		}
	end
	function transport.failed()
		return t.done and t.outcome ~= "success"
	end
	function transport.start()
		if t.outcome ~= "not_started" then
			return
		end
		t.outcome = "running"
		t0 = os.clock()
		task.spawn(function()
			local okRun, e = pcall(function()
				stage("wait_account2")
				local seen = clock.waitUntil(function()
					return t.cancelled or env.isPresent(a.Account2UserId)
				end, R5.TIMEOUTS.aWaitAccount2, 1)
				stopIfCancelledOrLate()
				if not seen then
					fail("timeout", "account 2 never joined server A")
				end

				stage("reserve")
				local okR, code, psid = pcall(env.reserve)
				if not okR then
					fail("failed", "ReserveServer failed: " .. tostring(code))
				end
				if type(code) ~= "string" or type(psid) ~= "string" or psid == "" then
					fail("failed", "ReserveServer returned no access code or PrivateServerId")
				end
				t.privateServerId = psid
				stopIfCancelledOrLate()

				stage("assign", { privateServerId = psid })
				update(op.runStore, runId, R5.claim.assignB(spec, psid, env.now()))
				local rec = get(op.runStore, runId)
				if not (type(rec) == "table" and rec.state == "B_ASSIGNED" and rec.bPrivateServerId == psid) then
					fail("failed", "B assignment was not recorded")
				end
				stopIfCancelledOrLate()

				stage("teleport")
				local okT, errT = env.teleport(a.Account2UserId, code)
				if not okT then
					fail("failed", "TeleportAsync failed: " .. tostring(errT))
				end

				stage("await_b")
				local result
				clock.waitUntil(function()
					if t.cancelled then
						return true
					end
					local reported = env.teleportFailure and env.teleportFailure(a.Account2UserId)
					if reported ~= nil then
						result = { kind = "failed", msg = "TeleportInitFailed: " .. tostring(reported) }
						return true
					end
					local r = get(op.runStore, runId)
					if type(r) == "table" and r.bNonce ~= nil and r.bPrivateServerId == psid then
						result = { kind = "success" }
						return true
					end
					return false
				end, R5.TIMEOUTS.transport, 1)
				if result ~= nil and result.kind == "success" then
					return
				end
				if result ~= nil then
					fail(result.kind, result.msg)
				end
				stopIfCancelledOrLate()
				fail("timeout", "B did not start in the assigned server within " .. R5.TIMEOUTS.transport .. " s")
			end)
			if okRun then
				t.outcome = "success"
			else
				local kind = type(e) == "table" and e.kind or "failed"
				t.error = type(e) == "table" and e.msg or tostring(e)
				t.outcome = markRecord(kind)
			end
			t.seconds = os.clock() - t0
			stage("end", { outcome = t.outcome })
			t.done = true
		end)
	end
	-- Waits for the task to finish. At the limit it is cancelled; if it is still blocked inside an engine call after
	-- that, it is recorded as unresolved and the run record is closed so it can no longer lead to a started B.
	function transport.join(timeout)
		if t.outcome == "not_started" then
			return transport.snapshot()
		end
		local t1 = os.clock()
		while not t.done and os.clock() - t1 < timeout do
			task.wait(0.25)
		end
		if not t.done then
			t.cancelled = true
			local t2 = os.clock()
			while not t.done and os.clock() - t2 < 5 do
				task.wait(0.25)
			end
		end
		if not t.done then
			t.error = "still blocked at stage " .. t.stage .. " after the join limit; cancelled"
			t.outcome = markRecord("unresolved")
			t.done = true
		end
		return transport.snapshot()
	end
	return transport
end

----------------------------------------------------------------------------------------------------------------------
-- Server entry: gates, presence, claim, role. env (all injected; real values come from the bootstrap):
--   identity = { placeId, gameId, jobId, privateServerId, privateServerOwnerId, isStudio }
--   attrs    = { AuthTest, AuthRunId, AuthNotBefore, AuthNotAfter, Account1UserId, Account2UserId }
--   now()                       -- os.time()
--   isPresent(userId) -> bool   -- designated account is in THIS server (Players, by UserId)
--   store.get(name, key)        -- uncached GetAsync
--   store.update(name, key, fn) -- UpdateAsync (fn may be invoked several times)
--   store.set(name, key, value) -- SetAsync
--   loadProfileStore() -> PS    -- require of the pinned module, called only after the gates
--   reserve() -> accessCode, privateServerId
--   teleport(userId, accessCode) -> ok, err
--   teleportFailure(userId) -> string | nil  -- a TeleportInitFailed report for that account, if any
--   nonce                        -- unique per server
--   setApproved(bool)            -- flips Guard.APPROVED[R5_CROSS_SERVER] in this server
-- Returns a summary; never throws.
----------------------------------------------------------------------------------------------------------------------
function R5.serverMain(env)
	local summary = { phase = "gates" }
	local op = Guard.OPERATIONS[R5.OPERATION]
	local ok, err = pcall(function()
		Guard.assertSaveTest()
		assert(op ~= nil, "guard has no R5 operation")
		local id, a = env.identity, env.attrs
		assert(id.placeId == Guard.SAVETEST_PLACE_ID and id.gameId == Guard.SAVETEST_GAME_ID, "not SaveTest")
		assert(id.isStudio ~= true, "Studio")
		assert(type(id.jobId) == "string" and id.jobId ~= "", "empty JobId")
		assert(a.AuthTest == R5.OPERATION, "no authorization")
		assert(type(a.AuthRunId) == "string" and string.match(a.AuthRunId, R5.RUN_ID_PATTERN) ~= nil, "bad RunId")
		assert(type(a.AuthNotBefore) == "number" and type(a.AuthNotAfter) == "number", "bad window")
		assert(a.AuthNotAfter > a.AuthNotBefore and a.AuthNotAfter - a.AuthNotBefore <= 3 * 3600, "bad window")
		assert(type(a.Account1UserId) == "number" and type(a.Account2UserId) == "number"
			and a.Account1UserId ~= a.Account2UserId, "bad accounts")
		local deadline = a.AuthNotAfter - R5.DEADLINE_MARGIN
		assert(env.now() >= a.AuthNotBefore and env.now() < deadline, "outside authorization window")
		local clock = makeClock(env, deadline)

		local isPublic = id.privateServerId == ""
		local isReserved = id.privateServerId ~= "" and id.privateServerOwnerId == 0
		local role = isPublic and "A" or (isReserved and "B" or nil)
		assert(role ~= nil, "server type is neither public nor reserved")
		summary.role = role
		local runId = a.AuthRunId
		local resultsKey = runId .. "_" .. role

		-- store access is limited to the operation's stores and THIS run's keys
		local function checkRaw(name, key)
			if name == op.store then
				assert(key == op.keyHandover or key == op.keyStolen, "R5 ABORT: key not allowed: " .. key)
			elseif name == op.runStore then
				assert(key == runId, "R5 ABORT: run key not allowed: " .. key)
			elseif name == op.resultsStore then
				assert(key == runId .. "_A" or key == runId .. "_B", "R5 ABORT: results key not allowed: " .. key)
			else
				error("R5 ABORT: store not allowed: " .. tostring(name))
			end
			Guard.assertStoreName(name)
		end
		local function get(name, key)
			checkRaw(name, key)
			return env.store.get(name, key)
		end
		local function update(name, key, fn)
			checkRaw(name, key)
			assert(name == op.runStore, "R5 ABORT: UpdateAsync only on the run record")
			-- a call may fail after committing; retrying is safe because every transform is idempotent
			local lastErr
			for _ = 1, 3 do
				local okU, e = pcall(env.store.update, name, key, fn)
				if okU then
					return true
				end
				lastErr = e
				task.wait(1)
			end
			error("R5 run-record update failed: " .. tostring(lastErr))
		end

		-- 1. PRESENCE GATE (no write of any kind before it)
		summary.phase = "presence"
		local designated = role == "A" and a.Account1UserId or a.Account2UserId
		local present = clock.waitUntil(function()
			return env.isPresent(designated)
		end, R5.TIMEOUTS.presence, 1)
		summary.designatedPresent = present
		assert(present, "designated account " .. role .. " never joined this server")

		-- 2. RUN OWNERSHIP
		summary.phase = "claim"
		local spec = {
			runId = runId,
			jobId = id.jobId,
			nonce = env.nonce,
			account1 = a.Account1UserId,
			account2 = a.Account2UserId,
			now = env.now(),
			deadline = deadline,
			privateServerId = id.privateServerId,
		}
		if role == "A" then
			assert(get(op.runStore, runId) == nil, "run already claimed (read check)")
			update(op.runStore, runId, R5.claim.claimA(spec))
			local rec = get(op.runStore, runId)
			assert(R5.claim.isOwnerA(rec, spec), "lost the run claim to another server")
		else
			local assigned = clock.waitUntil(function()
				local rec = get(op.runStore, runId)
				return type(rec) == "table" and rec.state == "B_ASSIGNED" and rec.bPrivateServerId == id.privateServerId
					and rec.account2 == a.Account2UserId
			end, R5.TIMEOUTS.bAssignment, 1)
			assert(assigned, "this reserved server is not the one the run record names")
			update(op.runStore, runId, R5.claim.startB(spec))
			local rec = get(op.runStore, runId)
			assert(R5.claim.isOwnerB(rec, spec), "could not start B for this run")
		end
		summary.claimed = true

		-- 3. ROLE (ProfileStore is loaded only now)
		summary.phase = "role"
		local PS = env.loadProfileStore()
		clock.check("role start")
		local deps = {
			PS = R5.restrict(PS, op, role),
			readRaw = get,
			readResult = function(r)
				return get(op.resultsStore, runId .. "_" .. r)
			end,
			identity = {
				role = role,
				runId = runId,
				placeId = id.placeId,
				gameId = id.gameId,
				jobId = id.jobId,
				privateServerId = id.privateServerId,
				privateServerOwnerId = id.privateServerOwnerId,
				mock = id.mock,
			},
			clock = clock,
		}
		if role == "A" then
			deps.transport = R5.newTransport(env, clock, spec, a, update, get, op, runId)
		end
		env.setApproved(true)
		local res = { role = role, runId = runId, log = {}, identity = deps.identity, startedAt = env.now() }
		local okRole, errRole = pcall(function()
			Guard.assertOperationApproved(R5.OPERATION)
			if role == "A" then
				roleA(deps, op, res)
			else
				roleB(deps, op, res)
			end
		end)
		env.setApproved(false)
		if not okRole then
			res.completedWithoutError = false
			res.error = "crashed: " .. tostring(errRole)
			res.failureClass = res.failureClass or "crash"
		end
		if deps.transport then
			-- role A never finishes with the transport task unresolved: join it (cancel at the limit) first
			res.transport = deps.transport.join(R5.TIMEOUTS.transportJoin)
			summary.transport = res.transport
		end
		res.finishedAt = env.now()
		-- partial or complete, the results record is always written once the role has started
		local okW, errW = pcall(function()
			checkRaw(op.resultsStore, resultsKey)
			env.store.set(op.resultsStore, resultsKey, res)
		end)
		summary.resultWritten = okW
		summary.resultWriteError = (not okW) and tostring(errW) or nil
		local outcome = res.completedWithoutError and "completed"
			or (res.abortedByDeadline and "aborted: deadline" or "failed: " .. tostring(res.error))
		pcall(update, op.runStore, runId, R5.claim.finish(spec, role, string.sub(outcome, 1, 200), env.now()))
		summary.result = res
	end)
	env.setApproved(false)
	summary.ok = ok
	summary.error = (not ok) and tostring(err) or nil
	return summary
end

----------------------------------------------------------------------------------------------------------------------
-- The R5 verdict, computed only from the two results records and the run record.
----------------------------------------------------------------------------------------------------------------------
function R5.evaluate(A, B, run)
	local function get(t, ...)
		for _, k in ipairs({ ... }) do
			if type(t) ~= "table" then
				return nil
			end
			t = t[k]
		end
		return t
	end
	local jobA, jobB = get(A, "identity", "jobId"), get(B, "identity", "jobId")
	local states = {}
	for _, h in ipairs(get(run, "history") or {}) do
		table.insert(states, h.state)
	end
	local transitions = table.concat(states, ">")
	local psid = get(run, "bPrivateServerId")
	-- reported independently, one group per concern
	local groups = {
		runRecord = {
			bothResultsPresent = A ~= nil and B ~= nil,
			sameRun = get(A, "runId") ~= nil and get(A, "runId") == get(B, "runId") and get(run, "runId") == get(A, "runId"),
			ownersMatchResults = get(run, "aJobId") == jobA and get(run, "bJobId") == jobB,
			transitions = transitions == "A_CLAIMED>B_ASSIGNED>B_STARTED>A_FINISHED>B_FINISHED"
				or transitions == "A_CLAIMED>B_ASSIGNED>B_STARTED>B_FINISHED>A_FINISHED",
			bothFinishedCompleted = get(run, "aFinished") == "completed" and get(run, "bFinished") == "completed",
		},
		transport = {
			outcomeSuccess = get(A, "transport", "outcome") == "success",
			reservedServerAssociation = psid ~= nil and get(A, "transport", "privateServerId") == psid
				and get(B, "identity", "privateServerId") == psid,
			serverTypes = get(A, "identity", "privateServerId") == "" and (get(B, "identity", "privateServerId") or "") ~= "",
			distinctNonEmptyJobIds = type(jobA) == "string" and type(jobB) == "string" and jobA ~= "" and jobB ~= ""
				and jobA ~= jobB,
		},
		handover = {
			endedOnA = get(A, "handover", "endedByLibrary") == true,
			viaMessaging = get(B, "handover", "resolvedBy") == "messaging (A released)",
			loadedLatestCommitted = get(B, "handover", "loadedLatestCommitted") == true,
			singleOwnerAfterHandover = get(B, "handover", "storedOwnerIsB") == true,
		},
		fencing = {
			staleOverwriteBlocked = get(A, "staleAttempt", "overwriteBlocked") == true
				and get(A, "staleAttempt", "storedPearlsAfter") == R5.B_STOLEN_SAVED
				and get(B, "stolen", "storedPearlsAfterAAttempt") == R5.B_STOLEN_SAVED,
			staleHolderSessionEnded = get(A, "staleAttempt", "sessionEndedAfterAttempt") == true,
			newOwnerUnaffected = get(B, "stolen", "stillOwnerAfterAAttempt") == true,
		},
		final = {
			finalValues = get(B, "final", "handover", "pearls") == R5.B_HANDOVER_FINAL
				and get(B, "final", "stolen", "pearls") == R5.B_STOLEN_SAVED,
			allSessionsReleased = get(B, "final", "bothReleased") == true and get(A, "cleanupReleased") == true,
			noDeadlineAbort = get(A, "abortedByDeadline") == false and get(B, "abortedByDeadline") == false,
			noFailureClass = A ~= nil and B ~= nil and A.failureClass == nil and B.failureClass == nil,
		},
	}
	local groupPassed, all = {}, true
	for name, checks in pairs(groups) do
		local p = true
		for _, v in pairs(checks) do
			if v ~= true then
				p = false
			end
		end
		groupPassed[name] = p
		all = all and p
	end
	return {
		allPassed = all,
		groupPassed = groupPassed,
		groups = groups,
		transportOutcome = get(A, "transport", "outcome"),
		transportStage = get(A, "transport", "stage"),
		transportSeconds = get(A, "transport", "seconds"),
		takeoverSeconds = get(B, "handover", "takeoverSeconds"),
		failureClassA = get(A, "failureClass"),
		failureClassB = get(B, "failureClass"),
		runTransitions = transitions,
		mock = get(A, "identity", "mock") == true,
	}
end

----------------------------------------------------------------------------------------------------------------------
-- Edit-mode tests on fakes. No real DataStore, MessagingService, teleport or Players call.
-- The fake raw store re-invokes a transform when another writer committed in between (optimistic concurrency, as
-- UpdateAsync does) and can drop the response of a committed call once, so the caller retries.
----------------------------------------------------------------------------------------------------------------------
local function newRaceStore()
	local st = { data = {}, ver = {}, writes = {}, invocations = 0, reinvocations = 0, cancels = 0, loseResponseOnce = {} }
	local s = { stats = st }
	function s.get(name, key)
		return deepCopy(st.data[name .. "/" .. key])
	end
	function s.update(name, key, fn)
		local k = name .. "/" .. key
		while true do
			local snapVer = st.ver[k] or 0
			local snap = deepCopy(st.data[k])
			task.wait(math.random() * 0.05) -- latency: concurrent callers interleave here
			st.invocations += 1
			local new = fn(snap)
			if (st.ver[k] or 0) ~= snapVer then
				st.reinvocations += 1 -- someone committed meanwhile: invoke again with the latest value
			else
				if new == nil then
					st.cancels += 1
					return nil
				end
				st.data[k] = deepCopy(new)
				st.ver[k] = snapVer + 1
				table.insert(st.writes, "UpdateAsync " .. k)
				if st.loseResponseOnce[k] then
					st.loseResponseOnce[k] = nil
					error("MOCK: response lost after commit")
				end
				return deepCopy(new)
			end
		end
	end
	function s.set(name, key, value)
		st.data[name .. "/" .. key] = deepCopy(value)
		table.insert(st.writes, "SetAsync " .. name .. "/" .. key)
	end
	return s
end

-- Builds one fake server env sharing `world` (ProfileStore fakes) and `raw` (run/results fakes).
local function fakeServer(ctx, opts)
	local MockBackend = require(script.Parent.MockBackend)
	local present = opts.present or {}
	local env = {
		identity = {
			placeId = Guard.SAVETEST_PLACE_ID,
			gameId = Guard.SAVETEST_GAME_ID,
			jobId = opts.jobId,
			privateServerId = opts.privateServerId or "",
			privateServerOwnerId = 0,
			isStudio = false,
			mock = true,
		},
		attrs = ctx.attrs,
		now = os.time,
		nonce = opts.jobId .. "-nonce",
		isPresent = function(userId)
			return present[userId] == true
		end,
		present = present,
		setApproved = function(v)
			Guard.APPROVED[R5.OPERATION] = v -- fakes share one Studio flag; each runRole asserts it at start only
		end,
	}
	-- profile keys go to the MockBackend world (ProfileStore), run/results keys to the race store
	env.store = {
		get = function(name, key)
			if name == ctx.op.store then
				return MockBackend.record(ctx.world, name, key)
			end
			return ctx.raw.get(name, key)
		end,
		update = ctx.raw.update,
		set = ctx.raw.set,
	}
	env.loadProfileStore = function()
		local h = MockBackend.loadVendor(ctx.vendorSource, ctx.world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = opts.jobId })
		local t0 = os.clock()
		while h.PS.DataStoreState ~= "Access" and os.clock() - t0 < 3 do
			task.wait()
		end
		table.insert(ctx.handles, h)
		ctx.psLoads += 1
		return h.PS
	end
	-- transport fakes; ctx.tm (transport mode) injects the failures the scenarios need
	local tm = ctx.tm or {}
	env.reserve = function()
		if tm.reserveDelay then
			task.wait(tm.reserveDelay)
		end
		if tm.reserveError then
			error("MOCK: ReserveServer HTTP 500")
		end
		ctx.reserved += 1
		return "code-" .. ctx.reserved, "PSID-" .. ctx.reserved
	end
	env.teleport = function(userId, code)
		if tm.teleportCallError then
			return false, "MOCK: TeleportAsync raised an error"
		end
		local psid = "PSID-" .. string.sub(code, 6)
		if tm.initFailAfter then
			-- the call returns, then the engine reports TeleportInitFailed; the account never arrives
			task.delay(tm.initFailAfter, function()
				ctx.teleportFailures[userId] = "MOCK: Flooded"
			end)
			return true
		end
		-- the teleported account appears in a NEW reserved server running the same code, after tm.bDelay seconds
		task.delay(tm.bDelay or 0, function()
			ctx.summaries["B:" .. psid] = R5.serverMain(fakeServer(ctx, {
				jobId = "JOB_B_" .. psid,
				privateServerId = psid,
				present = { [userId] = true },
			}))
		end)
		return true
	end
	env.teleportFailure = function(userId)
		return ctx.teleportFailures[userId]
	end
	return env
end

local function newCtx(vendorSource, attrsOverride)
	local MockBackend = require(script.Parent.MockBackend)
	local now = os.time()
	local attrs = {
		AuthTest = R5.OPERATION,
		AuthRunId = "R5RUN_" .. string.lower(string.gsub(game:GetService("HttpService"):GenerateGUID(false), "-", "")),
		AuthNotBefore = now - 10,
		AuthNotAfter = now + 7200,
		Account1UserId = 1001,
		Account2UserId = 2002,
	}
	for k, v in pairs(attrsOverride or {}) do
		attrs[k] = v
	end
	return {
		attrs = attrs,
		op = Guard.OPERATIONS[R5.OPERATION],
		world = MockBackend.newWorld(),
		raw = newRaceStore(),
		vendorSource = vendorSource,
		handles = {},
		summaries = {},
		reserved = 0,
		psLoads = 0,
		teleportFailures = {},
		tm = nil,
	}
end

local function writesOf(ctx)
	local w = {}
	for _, x in ipairs(ctx.world.writes) do
		table.insert(w, x.op .. " " .. x.store .. "/" .. x.key)
	end
	for _, x in ipairs(ctx.raw.stats.writes) do
		table.insert(w, x)
	end
	return w
end

local function recordOf(ctx, key)
	return require(script.Parent.MockBackend).record(ctx.world, ctx.op.store, key)
end

local function waitFor(cond, timeout)
	local t0 = os.clock()
	while not cond() and os.clock() - t0 < timeout do
		task.wait(0.25)
	end
	return cond()
end

-- Transport scenarios: A runs with account 1; account 2 joins A after 2 s; the fakes inject the failure.
R5.TRANSPORT_SCENARIOS = {
	full = { tm = {}, expectB = true },
	teleportDelayed = { tm = { bDelay = 10 }, expectB = true }, -- completes after 10 s, inside the transport limit
	reserveFails = { tm = { reserveError = true } },
	teleportCallFails = { tm = { teleportCallError = true } },
	teleportInitFails = { tm = { initFailAfter = 3 } }, -- call returns, TeleportInitFailed arrives 3 s later
	teleportLate = { tm = { bDelay = 9 }, timeouts = { transport = 4, bAssignment = 4 }, expectB = true },
	deadlineInTransportPrep = { tm = { reserveDelay = 20 }, deadlineIn = 12 }, -- deadline while ReserveServer runs
	transportUnresolved = { tm = { reserveDelay = 30 }, timeouts = { aWaitHandover = 8, transportJoin = 3 }, settle = 30 },
}

local function runTransportScenario(vendorSource, def)
	local now = os.time()
	local ctx = newCtx(vendorSource, def.deadlineIn and {
		AuthNotBefore = now - 10,
		AuthNotAfter = now + R5.DEADLINE_MARGIN + def.deadlineIn,
	} or nil)
	ctx.tm = def.tm
	for k, v in pairs(def.timeouts or {}) do
		R5.TIMEOUTS[k] = v
	end
	local envA = fakeServer(ctx, { jobId = "JOB_A", present = { [1001] = true } })
	task.spawn(function()
		ctx.summaries.A = R5.serverMain(envA)
	end)
	task.wait(2)
	envA.present[2002] = true -- account 2 joins server A; A moves it to a reserved server
	local function bSummaries()
		local list = {}
		for k, s in pairs(ctx.summaries) do
			if string.sub(k, 1, 2) == "B:" then
				table.insert(list, { server = k, claimed = s.claimed == true, phase = s.phase, error = s.error })
			end
		end
		return list
	end
	waitFor(function()
		return ctx.summaries.A ~= nil and (not def.expectB or #bSummaries() >= 1)
	end, 150)
	local writesAtAFinish = #ctx.raw.stats.writes + #ctx.world.writes
	if def.settle then
		task.wait(def.settle) -- let any blocked or late transport step resume, to show it does nothing
	end
	local run = ctx.raw.get(ctx.op.runStore, ctx.attrs.AuthRunId)
	local A = ctx.raw.get(ctx.op.resultsStore, ctx.attrs.AuthRunId .. "_A")
	local B = ctx.raw.get(ctx.op.resultsStore, ctx.attrs.AuthRunId .. "_B")
	local tr = A and A.transport or {}
	return {
		checks = R5.evaluate(A, B, run),
		transport = { outcome = tr.outcome, stage = tr.stage, error = tr.error, seconds = tr.seconds, marked = tr.marked, cancelled = tr.cancelled },
		resultsA = A and { completedWithoutError = A.completedWithoutError, failureClass = A.failureClass, error = A.error, cleanupReleased = A.cleanupReleased, abortedByDeadline = A.abortedByDeadline } or "MISSING",
		runState = run and run.state,
		runTransportOutcome = run and run.transportOutcome,
		runTransitions = R5.evaluate(A, B, run).runTransitions,
		bServers = bSummaries(),
		keys = { handover = summarize(recordOf(ctx, "player_900000204")), stolen = summarize(recordOf(ctx, "player_900000205")) },
		writesAfterAFinished = #ctx.raw.stats.writes + #ctx.world.writes - writesAtAFinish,
		writes = writesOf(ctx),
	}
end

-- scenario: a key of R5.TRANSPORT_SCENARIOS, or "noParticipant" | "raceA" | "wrongB" | "deadline"
function R5.runMockScenario(vendorSource, scenario)
	Guard.assertSaveTest()
	local savedTimeouts = deepCopy(R5.TIMEOUTS)
	local out = { scenario = scenario }
	local ok, err = pcall(function()
		if R5.TRANSPORT_SCENARIOS[scenario] then
			out.result = runTransportScenario(vendorSource, R5.TRANSPORT_SCENARIOS[scenario])
		elseif scenario == "noParticipant" then
			R5.TIMEOUTS.presence = 5
			local ctx = newCtx(vendorSource)
			-- a public server and a reserved server start with nobody designated present (account 2 in A's place)
			local sA = R5.serverMain(fakeServer(ctx, { jobId = "JOB_X", present = { [2002] = true } }))
			local sB = R5.serverMain(fakeServer(ctx, { jobId = "JOB_Y", privateServerId = "PSID-9", present = {} }))
			out.publicServer = { ok = sA.ok, phase = sA.phase, error = sA.error }
			out.reservedServer = { ok = sB.ok, phase = sB.phase, error = sB.error }
			out.writes = writesOf(ctx)
			out.profileStoreLoaded = ctx.psLoads
			out.zeroWrites = #out.writes == 0 and ctx.psLoads == 0
		elseif scenario == "raceA" then
			local ctx = newCtx(vendorSource)
			-- two public servers pass the gates at the same moment; the first claim's response is lost once
			ctx.raw.stats.loseResponseOnce[ctx.op.runStore .. "/" .. ctx.attrs.AuthRunId] = true
			local done = 0
			for _, j in ipairs({ "JOB_A1", "JOB_A2", "JOB_A3" }) do
				task.spawn(function()
					-- stop each winner before ProfileStore: this scenario only measures the claim
					local env = fakeServer(ctx, { jobId = j, present = { [1001] = true } })
					env.loadProfileStore = function()
						error("STOP_AFTER_CLAIM")
					end
					ctx.summaries[j] = R5.serverMain(env)
					done += 1
				end)
			end
			waitFor(function()
				return done == 3
			end, 30)
			local winners, losers = {}, {}
			for j, s in pairs(ctx.summaries) do
				if s.claimed then
					table.insert(winners, j)
				else
					table.insert(losers, j .. ": " .. tostring(s.error))
				end
			end
			local run = ctx.raw.get(ctx.op.runStore, ctx.attrs.AuthRunId)
			out.winners = winners
			out.losers = losers
			out.runOwner = run and run.aJobId
			out.invocations = ctx.raw.stats.invocations
			out.reinvocations = ctx.raw.stats.reinvocations
			out.cancels = ctx.raw.stats.cancels
			out.writes = writesOf(ctx)
			out.exactlyOneOwner = #winners == 1 and run ~= nil and run.aJobId == winners[1]
		elseif scenario == "wrongB" then
			R5.TIMEOUTS.bAssignment = 4
			local ctx = newCtx(vendorSource)
			-- the run is claimed and assigned to PSID-1; account 2 shows up in a different reserved server
			local spec = { runId = ctx.attrs.AuthRunId, jobId = "JOB_A", nonce = "JOB_A-nonce", account1 = 1001, account2 = 2002, now = os.time(), deadline = os.time() + 3600 }
			ctx.raw.update(ctx.op.runStore, spec.runId, R5.claim.claimA(spec))
			ctx.raw.update(ctx.op.runStore, spec.runId, R5.claim.assignB(spec, "PSID-1", os.time()))
			local before = #ctx.raw.stats.writes
			local function bServer(jobId, psid)
				local env = fakeServer(ctx, { jobId = jobId, privateServerId = psid, present = { [2002] = true } })
				env.loadProfileStore = function()
					error("STOP_AFTER_CLAIM") -- this scenario only measures B's association and claim
				end
				return env
			end
			local s = R5.serverMain(bServer("JOB_BAD", "PSID-7"))
			out.wrongServer = { ok = s.ok, phase = s.phase, error = s.error, claimed = s.claimed == true }
			-- a second B in the RIGHT server after a first B already started
			local s1 = R5.serverMain(bServer("JOB_B1", "PSID-1"))
			local s2 = R5.serverMain(bServer("JOB_B2", "PSID-1"))
			out.firstB = { claimed = s1.claimed == true, phase = s1.phase, error = s1.error }
			out.secondB = { claimed = s2.claimed == true, phase = s2.phase, error = s2.error }
			out.writesAfterSetup = {}
			for i = before + 1, #ctx.raw.stats.writes do
				table.insert(out.writesAfterSetup, ctx.raw.stats.writes[i])
			end
		elseif scenario == "deadline" then
			-- account 2 never comes; the deadline passes while A holds both keys
			local now = os.time()
			local ctx = newCtx(vendorSource, { AuthNotBefore = now - 10, AuthNotAfter = now + R5.DEADLINE_MARGIN + 12 })
			local s = R5.serverMain(fakeServer(ctx, { jobId = "JOB_A", present = { [1001] = true } }))
			local A = ctx.raw.get(ctx.op.resultsStore, ctx.attrs.AuthRunId .. "_A")
			local run = ctx.raw.get(ctx.op.runStore, ctx.attrs.AuthRunId)
			out.summary = { ok = s.ok, phase = s.phase, error = s.error, resultWritten = s.resultWritten }
			out.partialResults = A and { abortedByDeadline = A.abortedByDeadline, error = A.error, cleanupReleased = A.cleanupReleased, steps = #A.log } or nil
			out.runFinished = run and run.aFinished
			out.keys = {
				handover = summarize(recordOf(ctx, "player_900000204")),
				stolen = summarize(recordOf(ctx, "player_900000205")),
			}
			out.writes = writesOf(ctx)
		else
			error("unknown scenario")
		end
	end)
	R5.TIMEOUTS = savedTimeouts
	Guard.APPROVED[R5.OPERATION] = false
	out.ok = ok
	out.error = (not ok) and tostring(err) or nil
	out.flagReset = Guard.APPROVED[R5.OPERATION] == false
	return out
end

return R5
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/TestOnly_R5Bootstrap.server.luau ===
```lua
-- ServerScriptService.TestOnly_R5Bootstrap  (Script, v3, TASK-012)
-- SAVETEST ONLY. The only auto-running test code. It collects the real server environment and hands it to
-- R5CrossServer.serverMain, which owns every decision (gates, presence, run claim, deadline) and fails closed.
-- Authorization lives in this Script's attributes, set by the arm command, so the source never changes:
--   AuthTest = "R5_CROSS_SERVER", AuthRunId = "R5RUN_<hex>", AuthNotBefore / AuthNotAfter (unix, window <= 3 h),
--   Account1UserId, Account2UserId (numbers).
-- Before serverMain's presence gate passes, this Script makes NO DataStore, MessagingService or teleport call and
-- does not require ProfileStore. It never runs in Studio.

local RunService = game:GetService("RunService")
if RunService:IsStudio() then
	return -- inert in Studio, always
end
if game.PlaceId ~= 128620546156998 or game.GameId ~= 10770892134 then
	return
end
if script:GetAttribute("AuthTest") ~= "R5_CROSS_SERVER" then
	return -- not armed
end
local acc1, acc2 = script:GetAttribute("Account1UserId"), script:GetAttribute("Account2UserId")
local notBefore, notAfter = script:GetAttribute("AuthNotBefore"), script:GetAttribute("AuthNotAfter")
if type(acc1) ~= "number" or type(acc2) ~= "number" or type(notBefore) ~= "number" or type(notAfter) ~= "number" then
	return warn("[R5] inert: incomplete authorization")
end
if os.time() < notBefore or os.time() > notAfter then
	return warn("[R5] inert: outside authorization window")
end

local Players = game:GetService("Players")
-- while authorized, only the two designated accounts may stay in a SaveTest server
local function screen(player)
	if player.UserId ~= acc1 and player.UserId ~= acc2 then
		player:Kick("SaveTest is running a private test.")
	end
end
Players.PlayerAdded:Connect(screen)
for _, p in ipairs(Players:GetPlayers()) do
	screen(p)
end

local T = game:GetService("ServerStorage"):FindFirstChild("TestOnly")
if T == nil then
	return warn("[R5] inert: TestOnly folder missing")
end
local Guard = require(T.SaveTestGuard)
local R5 = require(T.R5CrossServer)

local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local getOptions = Instance.new("DataStoreGetOptions")
getOptions.UseCache = false

-- TeleportInitFailed reports for the designated account 2 (read by the supervised transport task)
local teleportFailures = {}
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
	if player.UserId == acc2 then
		teleportFailures[acc2] = tostring(teleportResult) .. ": " .. tostring(errorMessage)
	end
end)

local env = {
	identity = {
		placeId = game.PlaceId,
		gameId = game.GameId,
		jobId = game.JobId,
		privateServerId = game.PrivateServerId,
		privateServerOwnerId = game.PrivateServerOwnerId,
		isStudio = RunService:IsStudio(),
	},
	attrs = {
		AuthTest = script:GetAttribute("AuthTest"),
		AuthRunId = script:GetAttribute("AuthRunId"),
		AuthNotBefore = notBefore,
		AuthNotAfter = notAfter,
		Account1UserId = acc1,
		Account2UserId = acc2,
	},
	now = os.time,
	nonce = HttpService:GenerateGUID(false),
	isPresent = function(userId)
		return Players:GetPlayerByUserId(userId) ~= nil
	end,
	store = {
		get = function(name, key)
			return DataStoreService:GetDataStore(name):GetAsync(key, getOptions)
		end,
		update = function(name, key, fn)
			return DataStoreService:GetDataStore(name):UpdateAsync(key, fn)
		end,
		set = function(name, key, value)
			return DataStoreService:GetDataStore(name):SetAsync(key, value)
		end,
	},
	loadProfileStore = function()
		return require(T.ProfileStore)
	end,
	reserve = function()
		return TeleportService:ReserveServer(game.PlaceId) -- accessCode, privateServerId
	end,
	teleport = function(userId, accessCode)
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return false, "player left"
		end
		return pcall(function()
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
	end,
	teleportFailure = function(userId)
		return teleportFailures[userId]
	end,
	setApproved = function(v)
		Guard.APPROVED.R5_CROSS_SERVER = v
	end,
}

print("[R5] armed server " .. game.JobId .. " (private=" .. tostring(game.PrivateServerId ~= "") .. "); waiting for the gate")
local summary = R5.serverMain(env)
print("[R5] finished: role=" .. tostring(summary.role) .. " phase=" .. tostring(summary.phase) .. " claimed="
	.. tostring(summary.claimed) .. " transport=" .. tostring(summary.transport and summary.transport.outcome)
	.. " resultWritten=" .. tostring(summary.resultWritten) .. " error=" .. tostring(summary.error))
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/SaveTestGuard.luau ===
```lua
-- ServerStorage.TestOnly.SaveTestGuard
-- SAVETEST ONLY. Never copy this into the production place.
--
-- Purpose: refuse to initialize ProfileStore or touch any DataStore unless BOTH exact SaveTest IDs match,
-- the production IDs do not, the store name is a TEST_LK_ name, and the owner has flipped the approval flag.
-- Nothing in the game requires this module. It is only used by hand-run test code and, for R5 only, by the
-- authorization-gated bootstrap Script ServerScriptService.TestOnly_R5Bootstrap.

local Guard = {}

Guard.SAVETEST_PLACE_ID = 128620546156998
Guard.SAVETEST_GAME_ID = 10770892134 -- universe id

Guard.PROD_PLACE_ID = 132065051336560
Guard.PROD_GAME_ID = 10769064643

-- Test-only store names (all start with TEST_LK_)
Guard.TEST_STORE_NAME = "TEST_LK_ProfileStore_v2" -- ProfileStore profiles
Guard.TEST_V1_FIXTURE_STORE = "TEST_LK_V1Fixtures" -- legacy-shaped fixtures for the importer / overwrite tests
Guard.CANARY_STORE_NAME = "TEST_LK_IsolationCanary" -- already holds the approved canary marker

-- Never point anything at these (the production store name):
Guard.FORBIDDEN_STORE_NAMES = {
	["LighthouseKeepers_PlayerData_v1"] = true,
	["LighthouseKeepers_PlayerData_v2"] = true,
}

-- Flip to true ONLY with the owner's explicit written approval of the specific real DataStore writes.
-- While false, requireRealProfileStore() always errors, so the real ProfileStore module (whose Studio
-- initialization probe performs a real write to a store named "____PS") can never be loaded by accident.
Guard.REAL_DATASTORE_APPROVED = false

-- Per-operation approvals (TASK-009). All false by default. An operation may touch a real DataStore only while its
-- flag is true, and only the store/key/operations listed for it here; the entrypoint resets its own flag on every exit.
Guard.APPROVED = { R2_SAVE_LOAD = false, R3_SERVER_SESSION = false, R4_SHUTDOWN_RELEASE = false, R5_CROSS_SERVER = false }
Guard.OPERATIONS = {
	-- TASK-012 (proposed, not approved): release of an ACTIVE profile when the Studio Play server is stopped.
	-- No Save; EndSession only as failure recovery before the hold is reached.
	R4_SHUTDOWN_RELEASE = {
		store = "TEST_LK_ProfileStore_v2",
		key = "player_900000203",
		requiresRunningServer = true,
		requiresStudio = true,
		profileStoreOps = { New = true, StartSessionAsync = true }, -- no params
		profileOps = { EndSession = true }, -- recovery only
		rawReads = {
			["TEST_LK_ProfileStore_v2/player_900000203"] = true,
			["____PS/____PS"] = true,
		},
	},
	-- TASK-012 v2 (proposed, not approved): two PUBLISHED SaveTest servers. Role A = the public server holding the
	-- run claim, role B = the reserved server A created and recorded. Steal is allowed ONLY for role B on keyStolen.
	-- Raw access is limited by R5CrossServer to these stores and to THIS run's keys (RunId = attribute AuthRunId):
	--   runStore/<RunId>                    GetAsync + UpdateAsync (pure claim transforms)
	--   resultsStore/<RunId>_A, <RunId>_B   GetAsync + one SetAsync per role
	--   store/keyHandover, store/keyStolen  GetAsync (writes only through ProfileStore)
	R5_CROSS_SERVER = {
		store = "TEST_LK_ProfileStore_v2",
		keyHandover = "player_900000204",
		keyStolen = "player_900000205",
		runStore = "TEST_LK_R5_Run",
		resultsStore = "TEST_LK_R5_Results",
		requiresRunningServer = true,
		requiresLiveServer = true, -- never in Studio, JobId must be non-empty
		requiresDesignatedPlayer = true, -- account 1 in A, account 2 in the recorded reserved server, before any write
		profileStoreOps = { New = true, StartSessionAsync = true }, -- params: { Steal = true } only for role B on keyStolen
		profileOps = { Save = true, EndSession = true },
	},
	-- TASK-010 (executed once in TASK-011; flag stays false): first real-server session test. player_900000201 is the R2 regression
	-- fixture and is READ ONLY here.
	R3_SERVER_SESSION = {
		store = "TEST_LK_ProfileStore_v2",
		key = "player_900000202",
		fixtureKey = "player_900000201",
		requiresRunningServer = true,
		profileStoreOps = { New = true, StartSessionAsync = true }, -- no params (no Steal, no Cancel)
		profileOps = { Save = true, EndSession = true },
		rawReads = { -- GetAsync only
			["TEST_LK_ProfileStore_v2/player_900000202"] = true,
			["TEST_LK_ProfileStore_v2/player_900000201"] = true,
			["____PS/____PS"] = true,
		},
	},
	R2_SAVE_LOAD = {
		store = "TEST_LK_ProfileStore_v2",
		key = "player_900000201",
		profileStoreOps = { New = true, StartSessionAsync = true }, -- no params (no Steal, no Cancel)
		profileOps = { Save = true, EndSession = true },
		rawReads = { -- GetAsync only
			["TEST_LK_ProfileStore_v2/player_900000201"] = true,
			["____PS/____PS"] = true,
		},
	},
}

function Guard.assertOperationApproved(name)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[name]
	assert(op ~= nil, "SaveTestGuard ABORT: unknown operation " .. tostring(name))
	assert(Guard.APPROVED[name] == true, "SaveTestGuard ABORT: operation not approved: " .. tostring(name))
	Guard.assertStoreName(op.store)
	return op
end

function Guard.assertSaveTest()
	assert(
		game.PlaceId == Guard.SAVETEST_PLACE_ID,
		"SaveTestGuard ABORT: PlaceId is not the SaveTest place: " .. tostring(game.PlaceId)
	)
	assert(
		game.GameId == Guard.SAVETEST_GAME_ID,
		"SaveTestGuard ABORT: GameId is not the SaveTest universe: " .. tostring(game.GameId)
	)
	assert(
		game.PlaceId ~= Guard.PROD_PLACE_ID and game.GameId ~= Guard.PROD_GAME_ID,
		"SaveTestGuard ABORT: production IDs detected"
	)
	return true
end

function Guard.assertStoreName(storeName)
	assert(type(storeName) == "string", "SaveTestGuard ABORT: store name must be a string")
	assert(string.sub(storeName, 1, 8) == "TEST_LK_", "SaveTestGuard ABORT: store name must start with TEST_LK_: " .. storeName)
	assert(Guard.FORBIDDEN_STORE_NAMES[storeName] ~= true, "SaveTestGuard ABORT: forbidden store name: " .. storeName)
	return true
end

-- The ONLY sanctioned way to load the real ProfileStore module.
function Guard.requireRealProfileStore(profileStoreModule)
	Guard.assertSaveTest()
	assert(
		Guard.REAL_DATASTORE_APPROVED == true,
		"SaveTestGuard ABORT: real DataStore writes are not approved (REAL_DATASTORE_APPROVED is false)"
	)
	return require(profileStoreModule)
end

-- Creates a store through the real ProfileStore module, after every check.
function Guard.newRealStore(profileStoreModule, storeName, template)
	Guard.assertStoreName(storeName)
	local ProfileStore = Guard.requireRealProfileStore(profileStoreModule)
	return ProfileStore.New(storeName, template)
end

return Guard
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/R5v3_install_command.luau ===
```lua
-- TASK-012 R5 v3 INSTALL COMMAND. NOT RUN. Edit DataModel of the SaveTest window, only AFTER R4 has finished
-- (it changes the guard hash that R4's run command checks). Installs inert code only: no DataStore call, no arming.
-- The bootstrap's v3 source is applied separately with multi_edit and verified by hash in R5v3_arm_command.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SS = game:GetService("ServerStorage")
local T, S = SS.TestOnly, SS.TestOnly_R5v2Staging
local sha = require(T.Sha256)
assert(sha(S.SaveTestGuard.Source) == "2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57", "ABORT staged guard hash")
assert(sha(S.R5CrossServer.Source) == "ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4", "ABORT staged R5 hash")
local boot = game:GetService("ServerScriptService").TestOnly_R5Bootstrap
assert(boot.Enabled == false and boot:GetAttribute("AuthTest") == nil, "ABORT bootstrap is armed")
for _, name in ipairs({ "SaveTestGuard", "R5CrossServer" }) do
	local new = S[name]:Clone()
	T[name]:Destroy() -- fresh instances, so require() never returns a cached old module
	new.Parent = T
end
S:Destroy()
return "installed guard " .. sha(T.SaveTestGuard.Source) .. " and R5 " .. sha(T.R5CrossServer.Source)
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/R5v3_arm_command.luau ===
```lua
-- TASK-012 R5 v3 ARM COMMAND (template). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- The ONLY substitutions allowed: __USER_ID_1__ (account 1, joins first, server A) and __USER_ID_2__ (account 2).
-- Creates a fresh RunId, sets a 2-hour authorization window starting now, and enables the bootstrap. Nothing reaches
-- a live server until the owner publishes SaveTest.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SSS = game:GetService("ServerScriptService")
assert(SSS.Server.Main.Enabled == false, "ABORT game Main is enabled")
local T = game:GetService("ServerStorage").TestOnly
local boot = SSS.TestOnly_R5Bootstrap
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57", "ABORT guard hash")
assert(sha(T.R5CrossServer.Source) == "ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4", "ABORT R5 module hash")
assert(sha(boot.Source) == "646ac454440bb516b3508903420bbc79d74576f4849675cb4a87ae308041f26c", "ABORT bootstrap hash")
local acc1, acc2 = __USER_ID_1__, __USER_ID_2__
assert(type(acc1) == "number" and type(acc2) == "number" and acc1 ~= acc2, "ABORT user ids")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function absent(store, key)
	return DSS:GetDataStore(store):GetAsync(key, opts) == nil
end
assert(absent("TEST_LK_ProfileStore_v2", "player_900000204"), "ABORT handover key exists")
assert(absent("TEST_LK_ProfileStore_v2", "player_900000205"), "ABORT stolen key exists")
local runId = "R5RUN_" .. string.lower(string.gsub(game:GetService("HttpService"):GenerateGUID(false), "-", ""))
assert(absent("TEST_LK_R5_Run", runId), "ABORT run record exists")
local now = os.time()
boot:SetAttribute("AuthTest", "R5_CROSS_SERVER")
boot:SetAttribute("AuthRunId", runId)
boot:SetAttribute("AuthNotBefore", now)
boot:SetAttribute("AuthNotAfter", now + 2 * 3600)
boot:SetAttribute("Account1UserId", acc1)
boot:SetAttribute("Account2UserId", acc2)
T:SetAttribute("LastR5RunId", runId) -- kept after disarm so the results can still be read
boot.Enabled = true
return game:GetService("HttpService"):JSONEncode({ armed = true, runId = runId, notBefore = now, notAfter = now + 2 * 3600, runDeadline = now + 2 * 3600 - 300, attributes = boot:GetAttributes() })
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/R5v3_results_check.luau ===
```lua
-- TASK-012 R5 v3 RESULTS CHECK. Edit DataModel, read-only (uncached GetAsync). Safe to repeat during and after the run.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local T = game:GetService("ServerStorage").TestOnly
local runId = T:GetAttribute("LastR5RunId")
assert(type(runId) == "string" and string.match(runId, "^R5RUN_%x+$"), "ABORT no RunId recorded")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function get(store, key)
	local ok, value, info = pcall(function()
		return DSS:GetDataStore(store):GetAsync(key, opts)
	end)
	return ok, value, info
end
local function profile(key)
	local ok, v, info = get("TEST_LK_ProfileStore_v2", key)
	if not ok then
		return { error = tostring(v) }
	end
	local md = type(v) == "table" and v.MetaData or nil
	return {
		exists = v ~= nil,
		pearls = type(v) == "table" and v.Data and v.Data.pearls or nil,
		activeSession = md and md.ActiveSession,
		forceLoadSession = md and md.ForceLoadSession,
		sessionLoadCount = md and md.SessionLoadCount,
		version = info and info.Version,
		updatedTime = info and info.UpdatedTime,
	}
end
local okR, run = get("TEST_LK_R5_Run", runId)
local okA, resA = get("TEST_LK_R5_Results", runId .. "_A")
local okB, resB = get("TEST_LK_R5_Results", runId .. "_B")
local R5 = require(T.R5CrossServer) -- pure evaluator; makes no calls
local boot = game:GetService("ServerScriptService"):FindFirstChild("TestOnly_R5Bootstrap")
return game:GetService("HttpService"):JSONEncode({
	runId = runId,
	-- cleanup evidence (in this Studio copy; the live place loses it only with the owner's cleanup publish)
	bootstrapPresent = boot ~= nil,
	bootstrapEnabled = boot ~= nil and boot.Enabled or false,
	checks = R5.evaluate(okA and resA or nil, okB and resB or nil, okR and run or nil),
	run = okR and run or { error = tostring(run) },
	resultsA = okA and resA or { error = tostring(resA) },
	resultsB = okB and resB or { error = tostring(resB) },
	handover204 = profile("player_900000204"),
	stolen205 = profile("player_900000205"),
	fixture201 = profile("player_900000201"),
	fixture202 = profile("player_900000202"),
	r4key203 = profile("player_900000203"),
})
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/R5v3_disarm_command.luau ===
```lua
-- TASK-012 R5 v3 DISARM COMMAND. Edit DataModel of the SaveTest window, after the results are read (or on abort).
-- Removes the auto-running bootstrap from SaveTest. The owner's cleanup publish then removes it from new live servers.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SSS = game:GetService("ServerScriptService")
local boot = SSS:FindFirstChild("TestOnly_R5Bootstrap")
local existed = boot ~= nil
if boot then
	boot.Enabled = false
	boot:Destroy()
end
return "bootstrap existed=" .. tostring(existed) .. " now present=" .. tostring(SSS:FindFirstChild("TestOnly_R5Bootstrap") ~= nil)
	.. " lastRunId=" .. tostring(game:GetService("ServerStorage").TestOnly:GetAttribute("LastR5RunId"))
```
=== END FILE ===

