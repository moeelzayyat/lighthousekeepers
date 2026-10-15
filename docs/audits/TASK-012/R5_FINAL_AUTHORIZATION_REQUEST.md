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
