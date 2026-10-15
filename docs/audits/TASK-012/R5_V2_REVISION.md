# R5 v2: revision for the three mandatory corrections

- **Date:** 2026-10-14
- **Status:** design and dry runs only.
  - Nothing armed, nothing published, no real DataStore, MessagingService or teleport call.
  - v2 is staged in a separate Studio folder, `ServerStorage.TestOnly_R5v2Staging`, so R4's checked scripts stay unchanged.
  - It is installed into `TestOnly` only after R4, by `R5v2_install_command`.

## Code (SHA-256, equal on disk and in Studio; every file compiles)
| File (`luau\r5v2\`) | Bytes | SHA-256 |
|---|---|---|
| `R5CrossServer.luau` (all logic, `R5.serverMain(env)`) | 38,298 | `5db78c3848f69f674445acbea88b7f36aae4799b86c9a55adda031d2934e482a` |
| `SaveTestGuard.luau` (R5 entry adds `runStore`, the presence requirement) | 6,570 | `2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57` |
| `TestOnly_R5Bootstrap.server.luau` (collects the real environment, calls `serverMain`) | 4,296 | `f528fa5cb4817767df47a6e058eec41343b887a86ecba672cdac3ec0a8287aa6` |
| `R5v2_install_command.luau` (Edit, after R4) | 1,487 | `f02e05721e85ec802df16bbbfb61ec3f4b1ec703a65201b1520d9014925d4863` |
| `R5v2_arm_command.luau` (template: only `__USER_ID_1__` and `__USER_ID_2__` are substituted) | 2,812 | `af70c6b0804d793ce0a228c05da1716800ccf1caf6dc664747bd5afae379ff4f` |
| `R5v2_results_check.luau` (Edit, read-only) | 2,153 | `9bac074b38761828e8b1f117d9ab40204ed66c9bd8812fdc149f2d0dfef00872` |
| `R5v2_disarm_command.luau` (Edit) | 937 | `1a088185a641550fc512a9cf5bbe2d21f19978a1c4a362b49ca0c3d446260e4a` |

## Correction 1: player-presence gate
- `serverMain` waits for the **designated account by UserId** before anything else: account 1 in a public server (role A), account 2 in a reserved server (role B).
- Until the gate passes, the server makes:
  - no DataStore read or write;
  - no MessagingService or teleport call;
  - no ProfileStore `require`.
- A server with no designated participant gives up at its presence timeout (600 s, capped by the deadline) with **zero writes**.
- B must also be in the exact reserved server the run record names (correction 2).
- The window and allowlist are only preconditions. They do not start anything.
- **Dry run `noParticipant`:**
  - a public server with only account 2 in it, and a reserved server with nobody in it;
  - both stopped at `phase = presence`;
  - **writes: none, ProfileStore loaded: 0.**

## Correction 2: atomic run ownership
- **Run identity.** The arm command creates `RunId = R5RUN_<32 hex>`, stored in the bootstrap attributes.
- **Run record.** All coordination is one record: `TEST_LK_R5_Run/<RunId>`.
- **UpdateAsync calls.** Every one is on that record, and every transform is pure: it only reads its argument and returns a new value or `nil`. `nil` cancels, so nothing is written. A transform run several times gives the same answer.

| # | Who | Transform | Commits only if |
|---|---|---|---|
| 1 | A | `claimA` | the record is absent. If it already holds A's own nonce, the transform returns nil (a re-invocation or retry writes nothing). Otherwise nil. |
| 2 | A | `assignB(PrivateServerId)` | A owns the run and the state is `A_CLAIMED`. The PrivateServerId comes from `ReserveServer` on the server, **before** the teleport. Teleport data passes through the client, so it is never trusted. |
| 3 | B | `startB` | the state is `B_ASSIGNED`, the recorded PrivateServerId equals B's `game.PrivateServerId`, the recorded account 2 matches, and no B has started. If the record already holds B's own nonce, nil. |
| 4, 5 | A, B | `finish(outcome)` | the caller's nonce matches and its outcome is not yet recorded |

- **Ownership.** After every update, ownership is confirmed by an uncached read: nonce, JobId and PrivateServerId must all match.
- **Lost responses.** A call that fails after committing is retried up to 3 times, which is safe because the transforms are idempotent.
- **Failure recovery.**
  - If the claim cannot be confirmed, that server stops with zero ProfileStore writes.
  - If A holds the claim but stops before the role, the record stays at `A_CLAIMED` for that RunId only. A new run needs a new arm, which means a new RunId, so an old record can never block or join a later run.
- **Additional writes:** 5 `UpdateAsync` on the run record and 2 `SetAsync` results records (`TEST_LK_R5_Results/<RunId>_A` and `_B`).
- **Dry run `raceA` (three public servers pass every gate at the same moment):**
  - the fake store re-invokes a transform whenever another writer committed in between, as `UpdateAsync` does, and drops the first committed response once;
  - result: **exactly one owner** (JOB_A3). The two losers stopped with "lost the run claim";
  - 6 transform invocations, of which 2 were re-invocations, and 3 cancels (two losers plus the winner's retry after the lost response);
  - **1 write.**
- **Dry run `wrongB`:**
  - account 2 in a reserved server the record does not name was rejected at `phase = claim`, with no write;
  - the first B in the named server started;
  - a second B in the same server was rejected;
  - only 1 write (B's start) after setup.

## Correction 3: expiration and cleanup
- **Deadline during execution.**
  - The run deadline is `AuthNotAfter − 300 s`.
  - It is checked before every step (claim, each session start, save, steal, reserve) and inside every wait.
  - Past the deadline, the role stops at once.
- **Releasing incomplete sessions, in three layers:**
  1. The role's own cleanup runs on every exit path: success, error and deadline. It calls `EndSession` on every profile it still holds, then confirms from the store that none is held by this server. This wait is not cut short by the deadline, up to 30 s.
  2. When the players leave, the server shuts down and the library's own `BindToClose` releases anything still active. R4 tests this path.
  3. If a server crashes, a lock can remain. The library treats it as dead after 630 s without an update. The final read shows it, and any recovery is a separately approved step.
- **Partial results.**
  - Once a role has started, its results record is written on every exit path, including the full step log, `abortedByDeadline`, `cleanupReleased` and the error.
  - The run record's history (`A_CLAIMED` → `B_ASSIGNED` → `B_STARTED` → `A_FINISHED` / `B_FINISHED`, with times and outcomes) survives even if a server dies before writing results.
- **Dry run `deadline` (account 2 never comes; the deadline passes while A holds both keys):**
  - A aborted at `A5_handover` with "R5 DEADLINE reached";
  - both keys were released (204 = 55, 205 = 70, both inactive);
  - partial results were written (6 steps, `abortedByDeadline = true`, `cleanupReleased = true`);
  - the run record shows `aFinished = "aborted: deadline"`.
- **Old servers after the cleanup publish.**
  - Publishing does **not** stop running servers. They keep the old version until they empty, and I do not assume otherwise.
  - The old version is safe anyway:
    - its bootstrap refuses outside the window;
    - a running role aborts and releases at the deadline;
    - the run record is one-shot, so a newly started old-version server cannot claim the same RunId;
    - without a designated account in it, a server writes nothing.
  - **Procedure:**
    1. When the results are in, both accounts leave, so both servers empty and close.
    2. I confirm from Studio that every session is released and both roles are finished.
    3. Then the cleanup publish runs.
  - Only if a read still shows a session held after that would I ask you to use the Creator Hub option to shut down SaveTest's servers. That is never assumed and never done by me.

## Dry run `full` (A and B on fakes, through `serverMain`, with presence, claim, teleport to a reserved server and roles)
**All 15 evaluator checks were true:**
- bothResultsPresent, sameRun, runRecordConsistent, distinctNonEmptyJobIds, serverTypes;
- handoverEndedOnA, handoverViaMessaging, handoverLoadedLatestCommitted (55), singleOwnerAfterHandover;
- staleOverwriteBlocked (80, never 999), staleHolderSessionEnded, newOwnerUnaffected;
- allSessionsReleased, finalValues (60 and 80), noDeadlineAbort.

Takeover took 5.0 s. Run history: `A_CLAIMED` → `B_ASSIGNED` → `B_STARTED` → `A_FINISHED` → `B_FINISHED`.

## Expected live writes (no `____PS` probe in live servers)
**21 in total:**
- `player_900000204`: 7;
- `player_900000205`: 7;
- run record: 5 `UpdateAsync`;
- results: 2 `SetAsync`.

**Upper bound 27.** That allows up to 4 extra load attempts by B if A answers slowly, and up to 2 fenced releases if A must clean up after a failed handover.

Fixtures 201, 202 and 203 are read only. Nothing outside these stores and keys can be reached: `serverMain` rejects any other store or key, and the guard rejects non-`TEST_LK_` names.

## Order and owner actions (unchanged in number)
1. **R4 first.**
2. After R4: `R5v2_install_command` plus the bootstrap v2 source. This is inert code, hash-verified.
3. On R5 approval with the two UserIds, I arm the test.
4. You publish SaveTest once.
5. Account 1 joins first; then account 2 joins.
6. Both accounts leave when I say the results are in.
7. I disarm the test.
8. You publish SaveTest once more for cleanup.

**Still open:**
- a second Roblox account;
- how that account is allowed into the private SaveTest. I'll confirm the exact setting with you before arming.
