# R3 AUTHORIZATION REQUEST (TASK-010 corrections)

- **Date:** 2026-10-14
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`. Production (`132065051336560` / `10769064643`) and Outlaw City untouched.
- **State:** nothing executed. `Main.Enabled` is still `true`, no Play session has been started, and no real DataStore, MessagingService or BindToClose call has been made. **Execution waits for the owner's explicit approval.**

## 1. Correction 1: three independent results

The corrected runner is `R3ServerRunner` v2, SHA-256 `6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733`, 14,820 bytes. It is installed in SaveTest as a fresh instance, replacing v1 `bff3b190…5773`, which was destroyed.

`status().results` holds three separate verdicts, each computed from its own evidence:

| Result | `passed` only when | What it never implies |
|---|---|---|
| `persistenceAndRelease` | the session started (load count 1), the save of `pearls = 30` was seen in the stored record, and an uncached read shows `MetaData.ActiveSession == nil` | anything about messaging or shutdown |
| `messaging` | subscribe **and** publish **and** receipt on a fresh `TEST_LK_R3_<8 hex>` topic all succeed. The library's own takeover subscription is recorded alongside, as `librarySubscribedToItsTakeoverTopic` | persistence; a successful save is not messaging evidence |
| `bindToClose` | `game:BindToClose(no-op)` registers without error | release at shutdown. The note says so: an *active* profile being released at shutdown is not tested by R3 |

The messaging and BindToClose probes are each wrapped in `pcall` and stored separately, so a failure in either one cannot abort, or count towards, the persistence result.

## 2. Correction 2: Play is stopped only after cleanup is confirmed

- The run command is sent **once** and never re-sent, even if the MCP call times out. Progress is read only with the read-only status command.
- Play is stopped only when one of these holds:
  - `status().safeToStopPlay == true`. That means `terminal == true`, and the approval flag is back to `false`, and either no session was ever started or the final **uncached** read of `player_900000202` shows `ActiveSession == nil`.
  - **or** the run command itself returned `ok=false` while `status()` still shows `idle` with `flagReset == true`. This case means the runner refused before doing anything, so no session exists. Every assert in `startReal()` runs before its first DataStore call.
- If neither holds, I do **not** stop Play and I do **not** rerun. Cases:
  - not terminal after 5 minutes of polling (for example `StartSessionAsync` retrying);
  - terminal with the session still active in the store;
  - the final read failed.

  In each case I report the full `status()` output and the console, and ask the owner for a recovery decision.
- Recovery options would be listed then, not executed. For example: leave Play running and re-read; or stop Play and let the library's own BindToClose release the session (that path is untested).
- On every exit path the runner resets the flag itself. If the session is still active after a failure, it calls `EndSession()` once and waits up to 20 s for the stored release.

## 3. Stale or cached reads, and how release is confirmed

- **What ProfileStore uses:** `UpdateAsync` for session start, save and release. These calls are not served from the local `GetAsync` cache.
- **What the runner's verification reads use:** `GetAsync` with a `DataStoreGetOptions` whose `UseCache = false`. This class exists in this Studio build (`Instance.new` succeeded in Edit). `status().uncachedReads` records whether it was used. If it was ever `false`, the reads fell back to plain `GetAsync`, every read result is marked as possibly cached (up to about 4 s stale), and the release claim is downgraded.
- **Release is confirmed in three independent ways.** The first two come from the test server; the third comes from a different DataModel after Play is stopped.
  1. `OnSessionEnd` fires. This is library-side only, and fires *before* the release write, so it is never used as proof on its own.
  2. A 1 s uncached polling loop in the test server sees `ActiveSession == nil` with `pearls == 30`.
  3. After Play stops, `R3_post_stop_check.luau` runs in the **Edit** DataModel. It makes uncached reads of the synthetic key, the fixture and the probe key, and records the `Version` and `UpdatedTime` from `DataStoreKeyInfo`.
- **What this does not prove:** all three observations come from the same Studio process and the same account. They show what the DataStore service returned on those reads, not what another live server would see.
- **What would prove cross-server visibility.** None of these is in scope; each needs separate approval.
  - A read from a second, independent server, such as a published SaveTest server or a second Studio client.
  - `ListVersionsAsync` or `GetVersionAsync` on the key, to show the committed version history (read-only, but an extra API).
  - A second `StartSessionAsync` from another server that succeeds *without* a takeover. That would be a write.

## 4. Every permitted action

**Persistent writes: exactly these, and nothing else.**

| # | Where | Writer | Count |
|---|---|---|---|
| W0 | SaveTest Studio session: `ServerScriptService.Server.Main.Enabled = false` (in-session property; not a DataStore write) | `R3_disable_main.luau`, Edit | 1 |
| W1 | DataStore `____PS`, key `____PS`: `SetAsync(os.time())` | ProfileStore's Studio probe when it is required in the fresh Play server (vendor line 2080) | 1 |
| W2 | `TEST_LK_ProfileStore_v2/player_900000202`: session start, creating the record | `UpdateAsync` via `StartSessionAsync` | 1 |
| W3 | same key: save with `pearls = 30` | `UpdateAsync` via `profile:Save()` | 1 |
| W4 | same key: release (`ActiveSession = nil`) | `UpdateAsync` via `profile:EndSession()`, or the runner's single recovery `EndSession()` in its place | 1 |

Notes on these counts:
- These are logical, committed writes. If a DataStore call errors, the library retries it; an errored attempt commits nothing.
- The library's autosave runs every 300 s (vendor line 170), and the session lasts only seconds, so no autosave write is expected.
- If the precheck finds `player_900000202` already present, the runner aborts before W2 to W4.

**Non-persistent actions (Play server only):**
- MessagingService subscribe, publish and receive on one fresh `TEST_LK_R3_` topic, then disconnect.
- The library's own subscription to its takeover topic (`PS_<session id>`, vendor line 1340). The library publishes only when it takes over a session another server holds (vendor lines 1585 and 1711). A fresh key has none, so no library publish is expected.
- `BindToClose` registration of a no-op handler. The library also registers its own handlers when required (vendor lines 2199 and 2208).

**Reads:**
- `TEST_LK_ProfileStore_v2/player_900000202` and `____PS/____PS`;
- the regression fixture `TEST_LK_ProfileStore_v2/player_900000201`, **read only**.

The guard allowlist rejects any other raw read.

**Not permitted, and not reachable by the runner:**
- production, Outlaw City, real player data and the game's `PlayerData` store (`Main` is disabled, so it never loads);
- importer code and any other test key;
- `RemoveAsync`;
- `StartSessionAsync` parameters;
- publishing.

## 5. Final hashes

All hashes are SHA-256 over the exact file bytes (LF line endings). They were computed on disk and again inside Studio from the same text, and the two match. Every command file compiles (compile-only check in Studio; none was executed).

| File (`docs\audits\TASK-010\luau\`) | Context | Bytes | SHA-256 |
|---|---|---|---|
| `R3_disable_main.luau` | Edit | 892 | `1936326a42a2c7f0c26e45559b70c305971d18800faaba71d83c1afc9d28294c` |
| `R3_run_command.luau` | Server (Play), sent once | 1,938 | `56a87fef6ab3799f619c3ec5b6da31288d660d8a30c32a53de3ae0258a6f29dc` |
| `R3_status_command.luau` | Server (Play), read-only, repeatable | 595 | `b0a100289d2b7ec2cc82a4e23b4a7848e82eaf088cd712cb448563106ab6b95b` |
| `R3_post_stop_check.luau` | Edit, read-only | 1,585 | `b90cee1129ab3b6c2011b4c5720a2ea487fdc5274ab5d2476edeefdb87c32311` |

The run command asserts these installed modules by hash:

| Module | SHA-256 |
|---|---|
| `TestOnly.R3ServerRunner` v2 | `6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733` |
| `TestOnly.SaveTestGuard` | `4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d` |
| `TestOnly.ProfileStore` (pinned 45c9847) | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |

## 6. Verification of v2 already done (Edit mode, no real calls)

These checks were run in one Edit-mode call with both IDs asserted:
- The installed runner hash equals `6083eca5…b733`, and it compiles. The guard and ProfileStore hashes match.
- `startReal()` without approval was refused: "SaveTestGuard ABORT: operation not approved: R3_SERVER_SESSION".
- `startReal()` with the flag set, in Edit mode, was refused: "R3 ABORT: must run in a running server". The flag was reset to `false`.
- The dry run on in-memory fakes (`runMock`) produced the expected fake writes, and nothing else:
  - `SetAsync ____PS/____PS`;
  - 3 × `UpdateAsync TEST_LK_ProfileStore_v2/player_900000202`.
- The mock results came out separated, as designed:
  - `persistenceAndRelease.passed = true`, `finalPearls = 30`, `sessionReleasedInStore = true`;
  - `messaging.tested = false`, `messaging.passed = false`;
  - `bindToClose.tested = false`, `bindToClose.passed = false`.

  The mock shows that the save did not turn into a messaging or shutdown pass.
- After the dry run, `safeToStopPlay = true` and `flagReset = true`, and `Main.Enabled` was still `true`.

## 7. Execution steps, once approved

1. Re-list Studio instances, and assert in-script that this is SaveTest with both IDs, in Edit mode.
2. Run `R3_disable_main.luau` in Edit. Expected result: `before=true after=false`.
3. Start Play in the SaveTest window through MCP.
4. Run `R3_run_command.luau` **once** in the Server DataModel. Expected result: `ok=true result=started`. `flagNow=true` is normal at this point, because the runner clears the flag when it finishes.
5. Poll `R3_status_command.luau` until `terminal == true`, then apply the stop rule in section 2.
6. Stop Play only if that rule allows it. Then capture the console output.
7. Run `R3_post_stop_check.luau` in Edit. Expected results:
   - `player_900000202`: `pearls = 30`, `activeSession = nil`, `sessionLoadCount = 1`;
   - fixture: unchanged, `pearls = 25`, load count 2, released;
   - `mainEnabled = false`.
8. Leave `Main` disabled. Prepare `TASK-011_AUDITOR_PACKAGE.md` with the full evidence. Then ask the owner to save SaveTest to file, so the post-test state is recorded in a backup.

## 8. Rollback
- `Main.Enabled = true`, or restore `SaveTest_TASK-010_pre.rbxl`.
- The synthetic record `player_900000202` and the probe value are test-only, and they stay where they are. Removing them would be a separate, approved step, and it would never use `RemoveAsync` on anything except that synthetic key.

## Approval requested
Owner approval to execute steps 1 to 8 exactly as written, with the hashes above.
