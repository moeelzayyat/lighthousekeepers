# TASK-012 AUTHORIZATION PACKAGE: shutdown (R4) and cross-server (R5) tests

Combined plain-text package for the auditor. Preparation only: no test has run, nothing was published. The final TASK-012_AUDITOR_PACKAGE.md follows after approved execution. All hashes are SHA-256 of the exact file bytes (LF), equal to the in-Studio hashes.

## Contents
1. docs/audits/TASK-012/R4_R5_AUTHORIZATION_REQUEST.md (10385 bytes, SHA-256 9e4daaaa15e3bbc627a8034c7e4466f5beea195c6bda682e92d9908b1e7530af)
2. docs/audits/TASK-012/PREPARATION_EVIDENCE.md (5806 bytes, SHA-256 8eb7adf9c2be04a2a26ef8e41b5f1ec144810a9d59da588d41e642ad727633e2)
3. docs/audits/TASK-012/luau/SaveTestGuard.luau (6374 bytes, SHA-256 194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b)
4. docs/audits/TASK-012/luau/R4ShutdownRunner.luau (12622 bytes, SHA-256 1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613)
5. docs/audits/TASK-012/luau/R4_run_command.luau (2032 bytes, SHA-256 d93d62d3586b400d778a2d7ba35e929c7808a140b5351196abf7b367ea26ed31)
6. docs/audits/TASK-012/luau/R4_status_command.luau (568 bytes, SHA-256 287eeadc52abe88c96246f8d6bcee91b6a7125a06a6777bd03f2a52fcf09866a)
7. docs/audits/TASK-012/luau/R4_post_stop_check.luau (1582 bytes, SHA-256 703311f6b9f26477914e71eaa0ca3bd45373208bef22c2eae6f0a40fd44e8417)
8. docs/audits/TASK-012/luau/R5CrossServer.luau (17013 bytes, SHA-256 ed6765f9cdec4da25858b8404dfb6bc5125afe942be3f1acad43ccbe569a93e6)
9. docs/audits/TASK-012/luau/TestOnly_R5Bootstrap.server.luau (5917 bytes, SHA-256 85d7bae626e95e988ad4b48ff2b977d7ca7bc13afd3e8df9cdfa28545c00c17f)
10. docs/audits/TASK-012/luau/R5_arm_command.luau (2594 bytes, SHA-256 408d94319fddfc4f82bf37c7b5926f14f21d9525cc0f02c306ca96a544a40a2c)
11. docs/audits/TASK-012/luau/R5_results_check.luau (1840 bytes, SHA-256 9f7e87d146be9bd2089ce0ed9181e45aa0c2275641df2d355c65fbaed51305ba)
12. docs/audits/TASK-012/luau/R5_disarm_command.luau (839 bytes, SHA-256 c218b1308752374c95b91d8b474da326f495f111fbc74f3e40bed470f76b4d67)

=== FILE: docs/audits/TASK-012/R4_R5_AUTHORIZATION_REQUEST.md ===
# TASK-012 AUTHORIZATION REQUEST: shutdown test (R4) and two-server test (R5)

- **Date:** 2026-10-14
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`. Production and Outlaw City are not touched.
- **State:** preparation only.
  - No test has run.
  - No real DataStore, MessagingService or teleport call has been made for R4 or R5.
  - Nothing has been published.
- **Approval:** each test needs the owner's explicit approval, separately. R5 also needs the owner's two publish actions.

## Phase A: current work preserved

**Studio instance**
- Re-listed. SaveTest is asserted in every script by both IDs.
- `Main.Enabled = false` (still disabled).

**Backup `backups\2026-10-14\savetest\SaveTest_TASK-012_pre.rbxl`**

| Property | Value |
|---|---|
| Saved by | the owner |
| Size | 840,982 bytes |
| Header | valid `<roblox!` |
| SHA-256 | `89D64D2E75BF5967AFC7F73C58AEA971BD08C886DC37B1C2A03F1FCF8009D1F6` |

A Rojo export of the backup shows:
- `Main` disabled;
- ProfileStore `ad437372…`, R3 runner `6083eca5…`, guard `194e30d3…` and R4 runner `1a125835…`, all matching.

The R5 module and its bootstrap were installed *after* this save. Their sources are on disk, listed in section 4.

**Synthetic records:** `player_900000201` (25 Pearls) and `player_900000202` (30 Pearls) are preserved fixtures. Every new test uses fresh keys and only reads these two.

## Phase B: R4, release of an active profile at shutdown (Studio Play)

| Item | Definition |
|---|---|
| Code | `TestOnly.R4ShutdownRunner` `1a125835…7613`, guard `194e30d3…400b`, ProfileStore `ad437372…95f`. Commands: `R4_run_command` `d93d62d3…ed31`, `R4_status_command` `287eeadc…866a`, `R4_post_stop_check` `703311f6…8417` |
| Target | SaveTest Studio Play server (one), key `TEST_LK_ProfileStore_v2/player_900000203` (fresh) |
| What it does | Registers a read-only BindToClose observer. Starts a session. Sets `pearls = 40` **in memory only (no Save)**. Confirms the store still holds 0 with the session active, then holds. The approved **Stop Play** is the only thing that can persist the 40, through the library's own BindToClose release. |
| Expected writes | **3:** `____PS/____PS` probe (1), session start (1) and shutdown release (1) on `player_900000203` |
| Expected result | After Stop, an uncached Edit read shows `pearls 40`, `ActiveSession` absent and `SessionLoadCount 1`. The console shows `[R4] OnSessionEnd fired` and `[R4] observer: released=true …`. Fixtures 201 and 202 are unchanged. |
| Stop rule | Stop Play only when `readyForApprovedStop = true`: holding, flag reset, session active, observer registered, and held for less than 240 s (the library autosaves at 300 s). If R4 fails before the hold, the R3 rule applies (`safeToStopAfterFailure`), and otherwise I report and ask. |
| Failure criteria | After Stop: `ActiveSession` still set (lock left); `pearls` ≠ 40 (lost or partial write); the observer printed `released=false` or nothing (Studio cut shutdown short); or any ProfileStore error in the console |
| Cleanup | On success: none (the record stays as a fixture). On a lock left behind: report and ask. A Studio server can reclaim the lock, because Studio's JobId is `""` on both sides, and then release it. The library also treats a lock as dead after 630 s. Either path is a separate, approved step. |
| Evidence | Run result, status JSON, console after Stop, post-stop uncached reads (with version and UpdatedTime) |
| Dry run (fakes, done) | Refused without approval, and refused in Edit. Mock passed: before shutdown 0 Pearls with an active session, after the simulated shutdown 40 Pearls, released, load count 1. Writes: fake probe and 2 × `UpdateAsync player_900000203`. |

## Phase C: R5, cross-server ownership (two published SaveTest servers)

**How two real servers exist.**
- Server **A** is the public SaveTest server that account 1 joins.
- When account 2 joins A, the test teleports account 2 into a **new reserved server B** of the same place (`TeleportOptions.ShouldReserveServer`).
- Roles are fixed by server type (public versus reserved), never by timing.
- A server only runs while a player is in it. One account cannot be in two servers at once. **A second Roblox account is therefore required.**

**Control.** The MCP cannot reach live servers. The only auto-running piece is `ServerScriptService.TestOnly_R5Bootstrap`, which **fails closed** unless every gate below passes:
- not Studio;
- both SaveTest IDs match;
- JobId is non-empty;
- the attribute `AuthTest = "R5_CROSS_SERVER"` is set;
- the current time is inside an `AuthNotBefore`/`AuthNotAfter` window of at most 3 h, which the arm command sets to 2 h;
- `AllowedUserIds` lists exactly 2 accounts. Anyone else is kicked while the test is authorized.

It is also one-shot: a role does nothing if its results record, or (for A) the handover key, already exists. The bootstrap is installed now, **disabled and with no attributes**.

| Item | Definition |
|---|---|
| Code | `TestOnly.R5CrossServer` `ed6765f9…93e6`, bootstrap `85d7bae6…c17f`, guard `194e30d3…400b`, ProfileStore `ad437372…95f`. Commands: `R5_arm_command` (template) `408d9431…0a2c`, `R5_results_check` `9f7e87d1…05ba`, `R5_disarm_command` `c218b130…4d67` |
| Keys | `player_900000204` (handover), `player_900000205` (stolen), results `TEST_LK_R5_Results/A` and `/B` |
| Sequence | **A:** holds 204 (saved 50, then 55 in memory only) and holds 205 (saved 70); then teleports account 2. **B:** waits until it sees A holding both keys. **Handover:** B starts 204 normally; the library writes ForceLoadSession and asks A over MessagingService; A releases with 55; B loads it. **Steal:** B takes 205 with `{Steal = true}` (no message) and saves 80. **Stale write:** A, still believing it owns 205, tries to save 999. **Finish:** B re-saves 80, saves 60 on 204, releases both, and each server writes its results record. |
| Expected writes | **16** (no `____PS` probe in live servers). 204: 7 (A start, A save, B force-load request, A release, B acquire, B save, B release). 205: 7 (A start, A save, B steal, B save, A's fenced attempt, B re-save, B release). Results: 2. A's fenced attempt commits the same content, because ProfileStore's transform always returns the record; the data is unchanged. If A answers slowly, B repeats its load every 10 s, adding at most 4 writes on 204 before stealing at about 40 s. |
| Expected result | All 12 evaluator checks are true (`R5.evaluate`, used for both the mock and the real results). In particular: distinct non-empty JobIds; A public and B reserved; handover via messaging with B loading 55; one owner after handover; the 999 never stored; A's session ended; B unaffected; both released; final values 60 and 80. Takeover time is recorded (about 5 s expected). |
| Failure criteria | Any check false, a results record missing, or a teleport failure. Messaging failure shows as `handoverViaMessaging = false` with a takeover of about 40 s or more. |
| Failure behaviour (dry run with every message dropped) | B stole 204 after 45 s and loaded **50**, so A's unsaved 55 was lost; committed data was intact. A never learned of the takeover, timed out after 240 s, and never reached its 999 attempt. Its recovery release writes were fenced, and the stored values stayed 60 and 80. The evaluator reported 4 checks false (handoverEndedOnA, handoverViaMessaging, handoverLoadedLatestCommitted, staleOverwriteBlocked), and staleHolderSessionEnded was also false, so R5 counts as failed. That run had 20 writes, not counting the fake probes: 7 on 205, 11 on 204 (B's repeated load attempts before the steal) and 2 results records. Two of those are A's fenced recovery releases, one on each key. 20 is the upper bound I expect for R5. |
| Cleanup | B releases both keys. A ends any session it still believes it owns. When the players leave, the library's BindToClose releases anything left. Then `R5_disarm_command` deletes the bootstrap in Studio, and **the owner publishes once more** so the live SaveTest no longer contains it. Its time window is also an expiry: after 2 h it is inert even if the cleanup publish is late. A lock left behind is reported, never forced. |
| Evidence | Both results records, which hold each server's full log, JobId, PrivateServerId and timings. Uncached results-check reads of 204, 205 and fixtures 201 to 203, with the evaluator output. The arm result with its exact window. |
| Dry run (fakes, done) | Two logical servers (`JOB_A`, `JOB_B`) sharing one fake store and messaging: **all 12 checks true**, takeover 5.0 s, 1 message published. Writes match the list above (plus 2 fake Studio probes that do not occur live). |

**Owner actions R5 needs. These are the only manual steps.**
1. **Publish SaveTest:** in the "Private lighthouse keepers" window, File > Publish to Roblox. This is required because live servers run the published version. Before you click, I confirm in-script that this window is SaveTest and that the bootstrap is armed.
2. **Join with account 1** (PC), from the SaveTest page `roblox.com/games/128620546156998`. This creates server A.
3. **Join with account 2** (another device). It is moved to server B automatically. Stay in both until I say the results are in. I watch them from Studio.
4. **Cleanup publish:** File > Publish to Roblox again, after I have removed the bootstrap.

**Prerequisite to settle before arming:**
- SaveTest is private, so account 2 must be allowed to join it.
- I have not verified which Roblox setting does this for a private, user-owned experience. I will confirm the exact setting with you before arming.
- If the only way is making SaveTest public for the 2-hour window, the bootstrap's allowlist kicks everyone else.

## Writes never permitted
Production stores, Outlaw City, real player saves, fixtures 201 and 202 (read only), any key not named above, `RemoveAsync`, and any publish of the production experience.

## Approvals requested
1. **R4** exactly as in Phase B: one Play server, one run, the approved Stop Play, and the read-only post-stop check.
2. **R5** exactly as in Phase C. This requires:
   - the two account UserIds (substituted into the arm template, the only change allowed);
   - the access setting for account 2;
   - the owner's two publishes of SaveTest only.

R4 can run on its own. R5 waits for the second account.
=== END FILE ===

=== FILE: docs/audits/TASK-012/PREPARATION_EVIDENCE.md ===
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
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/SaveTestGuard.luau ===
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
	-- TASK-012 (proposed, not approved): two PUBLISHED SaveTest servers. Role A = the public server, role B = a reserved
	-- server created by A. Steal is allowed ONLY for role B on keyStolen.
	R5_CROSS_SERVER = {
		store = "TEST_LK_ProfileStore_v2",
		keyHandover = "player_900000204",
		keyStolen = "player_900000205",
		resultsStore = "TEST_LK_R5_Results",
		requiresRunningServer = true,
		requiresLiveServer = true, -- never in Studio, JobId must be non-empty
		profileStoreOps = { New = true, StartSessionAsync = true }, -- params: { Steal = true } only for role B on keyStolen
		profileOps = { Save = true, EndSession = true },
		rawReads = {
			["TEST_LK_ProfileStore_v2/player_900000204"] = true,
			["TEST_LK_ProfileStore_v2/player_900000205"] = true,
			["TEST_LK_R5_Results/A"] = true,
			["TEST_LK_R5_Results/B"] = true,
		},
		rawWrites = { -- SetAsync of the server's own results record only
			["TEST_LK_R5_Results/A"] = true,
			["TEST_LK_R5_Results/B"] = true,
		},
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

=== FILE: docs/audits/TASK-012/luau/R4ShutdownRunner.luau ===
```lua
-- ServerStorage.TestOnly.R4ShutdownRunner  (TASK-012)
-- SAVETEST ONLY. Test-only runner for R4: release of an ACTIVE profile when the Studio Play server is stopped.
-- A ModuleScript in ServerStorage: it never runs by itself, Play does not run it, nothing in the game requires it.
--
-- It may touch ONLY (Guard.OPERATIONS.R4_SHUTDOWN_RELEASE):
--   ProfileStore: New("TEST_LK_ProfileStore_v2"), StartSessionAsync("player_900000203") without params,
--                 and EndSession on that profile ONLY as failure recovery before the hold is reached.
--   Raw DataStore reads (GetAsync, cache bypassed): TEST_LK_ProfileStore_v2/player_900000203, ____PS/____PS.
--   game:BindToClose: one OBSERVER callback that only reads and prints; the library's own callback does the release.
-- The test: start a session, set pearls = 40 IN MEMORY ONLY (no Save), confirm the store still holds the template
-- with the session active, then hold. The owner-approved Stop Play is the only thing that can persist the 40.
-- Entry points (no argument can change store, key or module):
--   R4.runMock(vendorSource)  -- vendor TEXT vs in-memory fakes, Edit mode, simulated shutdown; no real calls
--   R4.startReal()            -- real module, ONLY in a running Studio Play server, ONLY with approval
--   R4.status()               -- in-memory status, no DataStore call

local Guard = require(script.Parent.SaveTestGuard)
local R4 = {}

R4.OPERATION = "R4_SHUTDOWN_RELEASE"
R4.TEST_PEARLS = 40
R4.MAX_HOLD_SECONDS = 240 -- stop must happen well before the library's 300 s autosave
R4.TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}
R4.state = { status = "idle", terminal = false, log = {} }

local function waitUntil(cond, timeout, interval)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > timeout then
			return false, os.clock() - t0
		end
		task.wait(interval or 0.05)
	end
	return true, os.clock() - t0
end

local function restrict(PS, op)
	local proxy = {}
	function proxy.New(storeName, template)
		assert(storeName == op.store, "R4 ABORT: store not allowed: " .. tostring(storeName))
		local real = PS.New(storeName, template)
		local storeProxy = {}
		function storeProxy:StartSessionAsync(key, params)
			assert(key == op.key, "R4 ABORT: key not allowed: " .. tostring(key))
			assert(params == nil, "R4 ABORT: no StartSessionAsync params are allowed")
			return real:StartSessionAsync(key)
		end
		return storeProxy
	end
	return proxy
end

local function summarize(r)
	return {
		exists = r ~= nil,
		pearls = r and r.Data and r.Data.pearls,
		activeSession = r and r.MetaData and r.MetaData.ActiveSession,
		sessionLoadCount = r and r.MetaData and r.MetaData.SessionLoadCount,
		lastUpdate = r and r.MetaData and r.MetaData.LastUpdate,
	}
end

-- deps = { PS, readRaw(store,key), identity }
local function core(deps, op)
	local state = R4.state
	local t0 = os.clock()
	local function note(step, data)
		data.step = step
		data.t = math.floor((os.clock() - t0) * 1000) / 1000
		table.insert(state.log, data)
	end
	local function raw()
		return deps.readRaw(op.store, op.key)
	end

	local profile
	local ok, err = pcall(function()
		note("1_identity", deps.identity)
		note("2_profilestore_init", { dataStoreState = deps.PS.getState and deps.PS.getState() or nil })
		local pre = raw()
		note("3_precheck", { keyAbsent = pre == nil })
		assert(pre == nil, "R4 ABORT: the test key already exists; nothing was written")

		local store = deps.PS.New(op.store, R4.TEMPLATE)
		profile = store:StartSessionAsync(op.key)
		assert(profile ~= nil, "R4 ABORT: StartSessionAsync returned nil")
		profile.OnSessionEnd:Connect(function()
			state.onSessionEndAt = os.clock()
			print("[R4] OnSessionEnd fired (the release write follows it)")
		end)
		assert(profile:IsActive() and profile.SessionLoadCount == 1, "R4 ABORT: session not active or load count not 1")
		note("4_session_started", { isActive = true, sessionLoadCount = profile.SessionLoadCount })

		-- in-memory change only; NO Save
		profile.Data.pearls = R4.TEST_PEARLS
		local rec = raw()
		local s = summarize(rec)
		note("5_holding", {
			memoryPearls = profile.Data.pearls,
			storedPearls = s.pearls,
			storedActiveSession = s.activeSession,
			storedLoadCount = s.sessionLoadCount,
		})
		assert(rec ~= nil and s.pearls == 0, "R4 ABORT: stored pearls are not the template value before shutdown")
		assert(type(s.activeSession) == "table", "R4 ABORT: stored session is not active")
	end)

	state.sessionEverStarted = profile ~= nil
	state.profile = profile
	if ok then
		state.holdingSince = os.time()
		state.status = "holding"
	else
		state.error = tostring(err)
		state.status = "failed"
		-- recovery: never leave the session open after a failure
		if profile and profile:IsActive() then
			profile:EndSession()
			note("recovery_end_session", { because = state.error })
			waitUntil(function()
				local r = raw()
				return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil
			end, 20, 1)
		end
		local okF, fr = pcall(raw)
		state.finalReadOk = okF
		state.finalRecord = okF and summarize(fr) or nil
	end
	return ok
end

-- Shutdown observer: registered before the session starts. It only reads and prints; it never writes.
local function makeObserver(readRaw, op, clock)
	return function()
		local t0 = clock()
		print("[R4] BindToClose observer started")
		local released = false
		local last
		while clock() - t0 < 25 do
			local okR, r = pcall(readRaw, op.store, op.key)
			if okR then
				last = summarize(r)
				if r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil then
					released = true
					break
				end
			end
			task.wait(0.5)
		end
		print(string.format(
			"[R4] observer: released=%s after %.2fs storedPearls=%s loadCount=%s",
			tostring(released), clock() - t0, tostring(last and last.pearls), tostring(last and last.sessionLoadCount)
		))
		R4.state.observer = { released = released, seconds = clock() - t0, last = last }
	end
end

-- Edit-mode dry run against in-memory fakes, including a simulated shutdown (the vendor's own BindToClose
-- callbacks are invoked from the fake). Makes no real DataStore or BindToClose call.
function R4.runMock(vendorSource)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[R4.OPERATION]
	assert(op ~= nil, "unknown operation")
	local MockBackend = require(script.Parent.MockBackend)
	R4.state = { status = "running-mock", terminal = false, log = {} }
	local world = MockBackend.newWorld()
	local identity = { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = "" }
	local h = MockBackend.loadVendor(vendorSource, world, identity)
	assert(waitUntil(function()
		return h.PS.DataStoreState == "Access"
	end, 3), "mock state never Access")
	local restricted = restrict(h.PS, op)
	restricted.getState = function()
		return h.PS.DataStoreState
	end
	local readRaw = function(store, key)
		return MockBackend.record(world, store, key)
	end
	table.insert(identity.closeCallbacks, makeObserver(readRaw, op, os.clock))
	local ok = core({ PS = restricted, readRaw = readRaw, identity = { mock = true, jobId = "" } }, op)
	local beforeShutdown = summarize(MockBackend.record(world, op.store, op.key))
	-- simulated Stop Play: run every registered close callback concurrently and wait for all of them
	local pending = #identity.closeCallbacks
	for _, fn in ipairs(identity.closeCallbacks) do
		task.spawn(function()
			pcall(fn)
			pending -= 1
		end)
	end
	waitUntil(function()
		return pending == 0
	end, 30)
	local after = summarize(MockBackend.record(world, op.store, op.key))
	local writes = {}
	for _, w in ipairs(world.writes) do
		table.insert(writes, w.op .. " " .. w.store .. "/" .. w.key)
	end
	R4.state.mockWrites = writes
	R4.state.mockBeforeShutdown = beforeShutdown
	R4.state.mockAfterShutdown = after
	R4.state.mockPassed = ok
		and beforeShutdown.pearls == 0
		and type(beforeShutdown.activeSession) == "table"
		and after.pearls == R4.TEST_PEARLS
		and after.activeSession == nil
		and after.sessionLoadCount == 1
	R4.state.profile = nil
	R4.state.status = "mock-terminal"
	R4.state.terminal = true
	h.destroy()
	return R4.status()
end

-- Real path: only inside a RUNNING Studio Play server, only with Guard.APPROVED.R4_SHUTDOWN_RELEASE == true.
-- Returns at once; poll R4.status(). The flag is reset to false on every exit path.
function R4.startReal()
	local op = Guard.assertOperationApproved(R4.OPERATION)
	local RunService = game:GetService("RunService")
	assert(RunService:IsServer() and RunService:IsRunning() and not RunService:IsEdit(), "R4 ABORT: must run in a running server")
	assert(RunService:IsStudio(), "R4 ABORT: R4 is a Studio Play test")
	assert(R4.state.status == "idle", "R4 ABORT: runner not idle")
	local psModule = script.Parent:FindFirstChild("ProfileStore")
	assert(psModule ~= nil and psModule:IsA("ModuleScript"), "ProfileStore module missing")
	R4.state = { status = "running", terminal = false, log = {}, startedAt = os.time() }

	local DataStoreService = game:GetService("DataStoreService")
	local allowedRaw = op.rawReads
	local okOpts, getOptions = pcall(function()
		local o = Instance.new("DataStoreGetOptions")
		o.UseCache = false
		return o
	end)
	R4.state.uncachedReads = okOpts
	local function readRaw(store, key)
		assert(allowedRaw[store .. "/" .. key] == true, "R4 ABORT: raw read not allowed: " .. store .. "/" .. key)
		local ds = DataStoreService:GetDataStore(store)
		if okOpts then
			return ds:GetAsync(key, getOptions)
		end
		return ds:GetAsync(key)
	end

	-- observer first, so it exists before any session does
	local okObs, obsErr = pcall(function()
		game:BindToClose(makeObserver(readRaw, op, os.clock))
	end)
	R4.state.observerRegistered = okObs
	R4.state.observerError = (not okObs) and tostring(obsErr) or nil

	R4.state.probeBeforeRequire = select(2, pcall(readRaw, "____PS", "____PS"))
	local ok0, PS = pcall(require, psModule) -- fresh server DataModel: the library's Studio probe write runs once
	if not ok0 then
		Guard.APPROVED[R4.OPERATION] = false
		R4.state.status = "crashed"
		R4.state.terminal = true
		R4.state.error = "require failed: " .. tostring(PS)
		return "failed to load module"
	end
	waitUntil(function()
		return PS.DataStoreState ~= "NotReady"
	end, 20)
	R4.state.probeAfterRequire = select(2, pcall(readRaw, "____PS", "____PS"))

	local restricted = restrict(PS, op)
	restricted.getState = function()
		return PS.DataStoreState
	end
	local deps = {
		PS = restricted,
		readRaw = readRaw,
		identity = {
			placeId = game.PlaceId,
			gameId = game.GameId,
			jobId = game.JobId,
			isServer = RunService:IsServer(),
			isStudio = RunService:IsStudio(),
			uncachedReads = okOpts,
		},
	}
	task.spawn(function()
		local okRun, errRun = pcall(core, deps, op)
		Guard.APPROVED[R4.OPERATION] = false -- ALWAYS reset
		if not okRun then
			R4.state.status = "crashed"
			R4.state.error = tostring(errRun)
		end
		R4.state.terminal = true
	end)
	return "started"
end

function R4.status()
	local s = R4.state
	local p = s.profile
	local holdingFor = s.holdingSince and (os.time() - s.holdingSince) or nil
	local fr = s.finalRecord
	return {
		status = s.status,
		terminal = s.terminal == true,
		flagReset = Guard.APPROVED[R4.OPERATION] == false,
		profileActive = p ~= nil and p:IsActive() or false,
		memoryPearls = p ~= nil and p.Data and p.Data.pearls or nil,
		holdingForSeconds = holdingFor,
		-- The approved Stop Play for R4 may happen ONLY when this is true.
		readyForApprovedStop = s.status == "holding"
			and s.terminal == true
			and Guard.APPROVED[R4.OPERATION] == false
			and p ~= nil and p:IsActive()
			and holdingFor ~= nil and holdingFor < R4.MAX_HOLD_SECONDS
			and s.observerRegistered == true,
		-- After a FAILURE, Play may be stopped only when this is true (same rule as R3).
		safeToStopAfterFailure = s.status ~= "holding" and s.terminal == true
			and Guard.APPROVED[R4.OPERATION] == false
			and (s.sessionEverStarted ~= true or (s.finalReadOk == true and fr ~= nil and fr.activeSession == nil)),
		observerRegistered = s.observerRegistered,
		observerError = s.observerError,
		uncachedReads = s.uncachedReads,
		probeBeforeRequire = s.probeBeforeRequire,
		probeAfterRequire = s.probeAfterRequire,
		error = s.error,
		finalRecord = fr,
		observer = s.observer,
		mockWrites = s.mockWrites,
		mockBeforeShutdown = s.mockBeforeShutdown,
		mockAfterShutdown = s.mockAfterShutdown,
		mockPassed = s.mockPassed,
		log = s.log,
	}
end

return R4
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/R4_run_command.luau ===
```lua
-- TASK-012 R4 RUN COMMAND. NOT RUN. Requires the owner's explicit approval.
-- Sent ONCE through MCP execute_luau with datamodel_type = "Server", in the SaveTest window's Play session.
-- Never re-sent, even if the MCP call times out: progress is read with R4_status_command.luau.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsServer() and RS:IsRunning() and not RS:IsEdit() and RS:IsStudio(), "ABORT not a running Studio server")
local SSS = game:GetService("ServerScriptService")
assert(SSS.Server.Main.Enabled == false, "ABORT game Main is enabled")
local boot = SSS:FindFirstChild("TestOnly_R5Bootstrap")
assert(boot == nil or boot.Enabled == false or boot:GetAttribute("AuthTest") == nil, "ABORT R5 bootstrap is armed")
local T = game:GetService("ServerStorage").TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b", "ABORT guard hash")
assert(sha(T.R4ShutdownRunner.Source) == "1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613", "ABORT runner hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R4_SHUTDOWN_RELEASE == false, "ABORT flag already true")
local R4 = require(T.R4ShutdownRunner)
assert(R4.status().status == "idle", "ABORT runner not idle: " .. tostring(R4.status().status))
Guard.APPROVED.R4_SHUTDOWN_RELEASE = true -- the runner resets it to false on every exit path
local ok, res = pcall(R4.startReal)
if not ok then
	Guard.APPROVED.R4_SHUTDOWN_RELEASE = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R4_SHUTDOWN_RELEASE)
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/R4_status_command.luau ===
```lua
-- TASK-012 R4 STATUS COMMAND. Read-only in-memory status, Server DataModel of the Play session.
-- The approved Stop Play may happen only when readyForApprovedStop is true.
-- After a failure, Play may be stopped only when safeToStopAfterFailure is true.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game:GetService("ServerStorage").TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R4ShutdownRunner).status())
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/R4_post_stop_check.luau ===
```lua
-- TASK-012 R4 POST-STOP CHECK. NOT RUN. Edit DataModel of the SaveTest window, after Play has stopped.
-- Read-only: uncached GetAsync of the R4 key, the earlier fixtures and the probe key. No writes.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function read(store, key)
	local ok, value, info = pcall(function()
		return DSS:GetDataStore(store):GetAsync(key, opts)
	end)
	local out = { ok = ok }
	if not ok then
		out.error = tostring(value)
		return out
	end
	out.exists = value ~= nil
	if type(value) == "table" then
		out.pearls = value.Data and value.Data.pearls
		local md = value.MetaData
		out.activeSession = md and md.ActiveSession
		out.sessionLoadCount = md and md.SessionLoadCount
		out.lastUpdate = md and md.LastUpdate
	else
		out.value = value
	end
	out.version = info and info.Version
	out.updatedTime = info and info.UpdatedTime
	return out
end
return game:GetService("HttpService"):JSONEncode({
	r4 = read("TEST_LK_ProfileStore_v2", "player_900000203"),
	fixture201 = read("TEST_LK_ProfileStore_v2", "player_900000201"),
	fixture202 = read("TEST_LK_ProfileStore_v2", "player_900000202"),
	probe = read("____PS", "____PS"),
	mainEnabled = game:GetService("ServerScriptService").Server.Main.Enabled,
})
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/R5CrossServer.luau ===
```lua
-- ServerStorage.TestOnly.R5CrossServer  (TASK-012)
-- SAVETEST ONLY. Two-server ownership test for PUBLISHED SaveTest servers. A ModuleScript: it never runs by itself.
-- In a live server it is started only by ServerScriptService.TestOnly_R5Bootstrap, which fails closed unless the
-- exact authorization attributes are present and valid.
--
-- Roles are fixed by server type, never by timing:
--   A = the public SaveTest server the first approved account joins (PrivateServerId == "").
--   B = a reserved server that A creates and teleports the second approved account into (PrivateServerId ~= "").
-- Keys (Guard.OPERATIONS.R5_CROSS_SERVER):
--   keyHandover player_900000204: A holds it (saved 50, then 55 in memory only); B requests it with a normal
--     StartSessionAsync, which makes the library ask A over MessagingService to end its session. B must load 55.
--   keyStolen player_900000205: A holds it (saved 70); B takes it with { Steal = true } (no message to A) and saves 80.
--     A, still believing it holds the session, then tries to save 999. The fence must stop it: the store keeps 80.
-- Each server writes ONE results record (TEST_LK_R5_Results/A or /B) with SetAsync. Nothing else is written
-- except through ProfileStore on the two keys above.
-- Entry points:
--   R5.runRole(role, deps)    -- used by the bootstrap with real deps
--   R5.runMock(vendorSource)  -- both roles against in-memory fakes in Edit mode; no real calls

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
R5.TIMEOUTS = {
	aWaitHandover = 240, -- includes the time for the second account to join (autosave is 300 s)
	aWaitSteal = 120,
	bWaitAReady = 60,
	bWaitAResults = 90,
	release = 30,
	save = 20,
}

local function waitUntil(cond, timeout, interval)
	local t0 = os.clock()
	while true do
		local okC, res = pcall(cond)
		if okC and res then
			return true, os.clock() - t0
		end
		if os.clock() - t0 > timeout then
			return false, os.clock() - t0
		end
		task.wait(interval or 0.25)
	end
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

-- deps = { PS (restricted), readRaw(store,key), writeResult(role, tbl), identity, onReady() (A only) }
local function roleA(deps, op, res)
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
	local ok, err = pcall(function()
		note("A1_identity", deps.identity)
		assert(raw(op.keyHandover) == nil and raw(op.keyStolen) == nil, "R5 ABORT: test keys already exist")
		note("A2_precheck", { keysAbsent = true })

		p1 = store:StartSessionAsync(op.keyHandover)
		assert(p1 ~= nil and p1:IsActive(), "A: handover key session failed")
		p1.OnSessionEnd:Connect(function()
			res.handoverSessionEndAt = os.clock() - t0
		end)
		p1.Data.pearls = R5.A_SAVED
		p1:Save()
		assert(waitUntil(function()
			return p1.LastSavedData ~= nil and p1.LastSavedData.pearls == R5.A_SAVED
		end, R5.TIMEOUTS.save), "A: save 50 not confirmed")
		p1.Data.pearls = R5.A_UNSAVED -- in memory only; must reach the store through the handover release
		note("A3_handover_key_held", { stored = summarize(raw(op.keyHandover)), memoryPearls = p1.Data.pearls })

		p2 = store:StartSessionAsync(op.keyStolen)
		assert(p2 ~= nil and p2:IsActive(), "A: stolen key session failed")
		p2.OnSessionEnd:Connect(function()
			res.stolenSessionEndAt = os.clock() - t0
		end)
		p2.Data.pearls = R5.A_STOLEN_SAVED
		p2:Save()
		assert(waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.A_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "A: save 70 not confirmed")
		note("A4_stolen_key_held", { stored = summarize(raw(op.keyStolen)) })

		res.readyAt = os.clock() - t0
		if deps.onReady then
			task.spawn(deps.onReady)
		end

		-- handover: the library must end A's session when B asks
		local handedOver, hSecs = waitUntil(function()
			return not p1:IsActive()
		end, R5.TIMEOUTS.aWaitHandover, 0.25)
		local afterHandover = summarize(raw(op.keyHandover))
		note("A5_handover", { endedByLibrary = handedOver, secondsWaited = hSecs, stored = afterHandover })
		res.handover = { endedByLibrary = handedOver, storedAfter = afterHandover }
		assert(handedOver, "A: handover never happened")

		-- steal: B takes the key without asking; A only notices by reading the store
		local stolen, sSecs = waitUntil(function()
			local s = summarize(raw(op.keyStolen))
			return s.active and s.activeJobId ~= myJob
		end, R5.TIMEOUTS.aWaitSteal, 1)
		local beforeAttempt = summarize(raw(op.keyStolen))
		note("A6_steal_observed", { stolen = stolen, secondsWaited = sSecs, stored = beforeAttempt, localStillActive = p2:IsActive() })
		assert(stolen, "A: steal never observed")

		-- stale holder tries to overwrite newer progress
		local activeBefore = p2:IsActive()
		p2.Data.pearls = R5.A_STALE_ATTEMPT
		p2:Save()
		local endedAfter, eSecs = waitUntil(function()
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
	-- recovery: never leave a session that A still believes it owns
	for _, p in ipairs({ p1, p2 }) do
		if p ~= nil and p:IsActive() then
			p:EndSession()
			note("A_recovery_end_session", { key = p.Key })
		end
	end
	res.completedWithoutError = ok
	res.error = (not ok) and tostring(err) or nil
	return ok
end

local function roleB(deps, op, res)
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
	local ok, err = pcall(function()
		note("B1_identity", deps.identity)
		local aReady = waitUntil(function()
			local h, s = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
			return h.active and h.activeJobId ~= myJob and h.pearls == R5.A_SAVED
				and s.active and s.activeJobId ~= myJob and s.pearls == R5.A_STOLEN_SAVED
		end, R5.TIMEOUTS.bWaitAReady, 1)
		note("B2_a_ready_seen", { aReady = aReady })
		assert(aReady, "B: server A is not holding both keys")

		-- legitimate handover through the library (ForceLoadSession + MessagingService request to A)
		local tReq = os.clock()
		p1 = store:StartSessionAsync(op.keyHandover)
		local takeoverSecs = os.clock() - tReq
		assert(p1 ~= nil and p1:IsActive(), "B: handover session failed")
		local h = summarize(raw(op.keyHandover))
		note("B3_handover_acquired", {
			takeoverSeconds = takeoverSecs,
			loadedPearls = p1.Data.pearls,
			sessionLoadCount = p1.SessionLoadCount,
			stored = h,
		})
		res.handover = {
			takeoverSeconds = takeoverSecs,
			loadedLatestCommitted = p1.Data.pearls == R5.A_UNSAVED,
			loadedPearls = p1.Data.pearls,
			sessionLoadCount = p1.SessionLoadCount,
			storedOwnerIsB = h.active and h.activeJobId == myJob,
			-- about 5 s means A answered the MessagingService request; about 40 s means the library had to steal
			resolvedBy = takeoverSecs < 30 and "messaging (A released)" or "steal after timeout",
		}

		-- forced steal: no message to A
		local tSteal = os.clock()
		p2 = store:StartSessionAsync(op.keyStolen, { Steal = true })
		assert(p2 ~= nil and p2:IsActive(), "B: steal failed")
		local loadedStolen = p2.Data.pearls
		p2.Data.pearls = R5.B_STOLEN_SAVED
		p2:Save()
		assert(waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.B_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "B: save 80 not confirmed")
		note("B4_stolen_and_saved", { stealSeconds = os.clock() - tSteal, loadedPearls = loadedStolen, stored = summarize(raw(op.keyStolen)) })

		-- hold until A has made its stale attempt and written its results
		local aDone = waitUntil(function()
			return deps.readRaw(op.resultsStore, "A") ~= nil
		end, R5.TIMEOUTS.bWaitAResults, 1)
		p2:Save() -- B's own save still works after A's attempt
		assert(waitUntil(function()
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

		-- finish: one more committed value on the handover key, then release both
		p1.Data.pearls = R5.B_HANDOVER_FINAL
		p1:Save()
		assert(waitUntil(function()
			return p1.LastSavedData ~= nil and p1.LastSavedData.pearls == R5.B_HANDOVER_FINAL
		end, R5.TIMEOUTS.save), "B: save 60 not confirmed")
	end)
	for _, p in ipairs({ p1, p2 }) do
		if p ~= nil and p:IsActive() then
			p:EndSession()
		end
	end
	local released = waitUntil(function()
		local a, b = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
		return (not a.active) and not b.active
	end, R5.TIMEOUTS.release, 1)
	local fh, fs = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
	note("B6_released", { bothReleased = released, handover = fh, stolen = fs })
	res.final = { bothReleased = released, handover = fh, stolen = fs }
	res.completedWithoutError = ok and released
	res.error = (not ok) and tostring(err) or nil
	return res.completedWithoutError
end

-- Runs one role, then writes that role's single results record. Never throws.
function R5.runRole(role, deps)
	local op = Guard.assertOperationApproved(R5.OPERATION)
	assert(role == "A" or role == "B", "R5 ABORT: bad role")
	local res = { role = role, log = {}, identity = deps.identity, startedAt = os.time() }
	local okRun, errRun = pcall(role == "A" and roleA or roleB, deps, op, res)
	Guard.APPROVED[R5.OPERATION] = false -- ALWAYS reset
	if not okRun then
		res.completedWithoutError = false
		res.error = "crashed: " .. tostring(errRun)
	end
	res.finishedAt = os.time()
	local okW, errW = pcall(deps.writeResult, role, res)
	res.resultWritten = okW
	res.resultWriteError = (not okW) and tostring(errW) or nil
	return res
end

-- Edit-mode dry run: both roles against in-memory fakes, two logical servers with DIFFERENT JobIds sharing one fake
-- store and one fake MessagingService. No real DataStore, MessagingService or teleport call.
function R5.runMock(vendorSource, options)
	Guard.assertSaveTest()
	options = options or {}
	local op = Guard.OPERATIONS[R5.OPERATION]
	assert(op ~= nil, "unknown operation")
	local MockBackend = require(script.Parent.MockBackend)
	local world = MockBackend.newWorld()
	world.dropMessages = options.dropMessages == true
	local function makeDeps(role, jobId)
		local h = MockBackend.loadVendor(vendorSource, world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = jobId })
		assert(waitUntil(function()
			return h.PS.DataStoreState == "Access"
		end, 3), "mock state never Access")
		local restricted = R5.restrict(h.PS, op, role)
		return h, {
			PS = restricted,
			identity = { mock = true, role = role, jobId = jobId },
			readRaw = function(store, key)
				assert(op.rawReads[store .. "/" .. key] == true, "R5 ABORT: raw read not allowed")
				return MockBackend.record(world, store, key)
			end,
			writeResult = function(r, tbl)
				assert(op.rawWrites[op.resultsStore .. "/" .. r] == true, "R5 ABORT: raw write not allowed")
				MockBackend.seed(world, op.resultsStore, r, { completedWithoutError = tbl.completedWithoutError })
				table.insert(world.writes, { store = op.resultsStore, key = r, op = "SetAsync" })
			end,
		}
	end
	local hA, depsA = makeDeps("A", "JOB_A")
	local hB, depsB = makeDeps("B", "JOB_B")
	local results = {}
	local done = 0
	Guard.APPROVED[R5.OPERATION] = true -- mock only: both fake servers share this Studio flag
	task.spawn(function()
		results.A = R5.runRole("A", depsA)
		done += 1
	end)
	task.wait(0.5)
	Guard.APPROVED[R5.OPERATION] = true
	task.spawn(function()
		results.B = R5.runRole("B", depsB)
		done += 1
	end)
	waitUntil(function()
		return done == 2
	end, 320, 0.5)
	Guard.APPROVED[R5.OPERATION] = false
	local writes = {}
	for _, w in ipairs(world.writes) do
		table.insert(writes, w.op .. " " .. w.store .. "/" .. w.key)
	end
	hA.destroy()
	hB.destroy()
	return {
		done = done,
		flagReset = Guard.APPROVED[R5.OPERATION] == false,
		checks = R5.evaluate(results.A, results.B),
		A = results.A and { completedWithoutError = results.A.completedWithoutError, error = results.A.error, handover = results.A.handover, staleAttempt = results.A.staleAttempt } or nil,
		B = results.B and { completedWithoutError = results.B.completedWithoutError, error = results.B.error, handover = results.B.handover, stolen = results.B.stolen, final = results.B.final } or nil,
		published = #world.published,
		writes = writes,
	}
end

-- The R5 verdict, computed only from the two results records (the same function is used for the mock and for the
-- real results read back in Studio). Every check must be true for R5 to pass; each one is reported separately.
function R5.evaluate(A, B)
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
	local mock = get(A, "identity", "mock") == true
	return {
		bothResultsPresent = A ~= nil and B ~= nil,
		distinctNonEmptyJobIds = type(jobA) == "string" and type(jobB) == "string" and jobA ~= "" and jobB ~= "" and jobA ~= jobB,
		serverTypes = mock or (get(A, "identity", "privateServerId") == "" and (get(B, "identity", "privateServerId") or "") ~= ""),
		handoverEndedOnA = get(A, "handover", "endedByLibrary") == true,
		handoverViaMessaging = get(B, "handover", "resolvedBy") == "messaging (A released)",
		handoverLoadedLatestCommitted = get(B, "handover", "loadedLatestCommitted") == true,
		singleOwnerAfterHandover = get(B, "handover", "storedOwnerIsB") == true,
		staleOverwriteBlocked = get(A, "staleAttempt", "overwriteBlocked") == true
			and get(A, "staleAttempt", "storedPearlsAfter") == R5.B_STOLEN_SAVED
			and get(B, "stolen", "storedPearlsAfterAAttempt") == R5.B_STOLEN_SAVED,
		staleHolderSessionEnded = get(A, "staleAttempt", "sessionEndedAfterAttempt") == true,
		newOwnerUnaffected = get(B, "stolen", "stillOwnerAfterAAttempt") == true,
		allSessionsReleased = get(B, "final", "bothReleased") == true
			and get(B, "final", "handover", "active") == false
			and get(B, "final", "stolen", "active") == false,
		finalValues = get(B, "final", "handover", "pearls") == R5.B_HANDOVER_FINAL
			and get(B, "final", "stolen", "pearls") == R5.B_STOLEN_SAVED,
		takeoverSeconds = get(B, "handover", "takeoverSeconds"),
	}
end

return R5
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/TestOnly_R5Bootstrap.server.luau ===
```lua
-- ServerScriptService.TestOnly_R5Bootstrap  (Script, TASK-012)
-- SAVETEST ONLY. The only auto-running test code. It FAILS CLOSED: it returns without any DataStore, MessagingService
-- or teleport call unless EVERY check below passes. All authorization data lives in this Script's attributes, so the
-- source (and its hash) never changes:
--   AuthTest        = "R5_CROSS_SERVER"
--   AuthNotBefore   = unix seconds   } window set at install, at most 3 hours long
--   AuthNotAfter    = unix seconds   }
--   AllowedUserIds  = "<id1>,<id2>"  the two approved accounts; any other player is kicked while the test is authorized
-- It never runs in Studio. Roles: A = public server, B = reserved server created by A.
-- One-shot: a role does nothing if its results record (or, for A, the handover key) already exists.

local RunService = game:GetService("RunService")
if RunService:IsStudio() then
	return -- inert in Studio, always
end

local function refuse(reason)
	warn("[R5] inert: " .. reason)
end

if game.PlaceId ~= 128620546156998 or game.GameId ~= 10770892134 then
	return refuse("not SaveTest")
end
if game.PlaceId == 132065051336560 or game.GameId == 10769064643 then
	return refuse("production ids")
end
if game.JobId == "" then
	return refuse("empty JobId")
end
if script:GetAttribute("AuthTest") ~= "R5_CROSS_SERVER" then
	return refuse("no authorization")
end
local notBefore, notAfter = script:GetAttribute("AuthNotBefore"), script:GetAttribute("AuthNotAfter")
if type(notBefore) ~= "number" or type(notAfter) ~= "number" or notAfter - notBefore > 3 * 3600 or notAfter <= notBefore then
	return refuse("bad authorization window")
end
local now = os.time()
if now < notBefore or now > notAfter then
	return refuse("outside authorization window")
end
local allowed = {}
local allowedCount = 0
for id in string.gmatch(tostring(script:GetAttribute("AllowedUserIds") or ""), "%d+") do
	allowed[tonumber(id)] = true
	allowedCount += 1
end
if allowedCount ~= 2 then
	return refuse("AllowedUserIds must list exactly two accounts")
end

local ServerStorage = game:GetService("ServerStorage")
local T = ServerStorage:FindFirstChild("TestOnly")
if T == nil then
	return refuse("TestOnly folder missing")
end
local Guard = require(T.SaveTestGuard)
local R5 = require(T.R5CrossServer)
local op = Guard.OPERATIONS.R5_CROSS_SERVER
if op == nil then
	return refuse("guard has no R5 operation")
end

local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isPublic = game.PrivateServerId == ""
local role = isPublic and "A" or (isReserved and "B" or nil)
if role == nil then
	return refuse("server type is neither public nor reserved")
end

local Players = game:GetService("Players")
local function screen(player)
	if not allowed[player.UserId] then
		player:Kick("SaveTest is running a private test.")
	end
end
Players.PlayerAdded:Connect(screen)
for _, p in ipairs(Players:GetPlayers()) do
	screen(p)
end

local DataStoreService = game:GetService("DataStoreService")
local okOpts, getOptions = pcall(function()
	local o = Instance.new("DataStoreGetOptions")
	o.UseCache = false
	return o
end)
local function readRaw(store, key)
	assert(op.rawReads[store .. "/" .. key] == true, "R5 ABORT: raw read not allowed: " .. store .. "/" .. key)
	local ds = DataStoreService:GetDataStore(store)
	if okOpts then
		return ds:GetAsync(key, getOptions)
	end
	return ds:GetAsync(key)
end
local function writeResult(r, tbl)
	assert(r == role, "R5 ABORT: a server may only write its own results")
	assert(op.rawWrites[op.resultsStore .. "/" .. r] == true, "R5 ABORT: raw write not allowed")
	DataStoreService:GetDataStore(op.resultsStore):SetAsync(r, tbl)
end

-- one-shot checks (reads only)
local okPre, preErr = pcall(function()
	assert(readRaw(op.resultsStore, role) == nil, "results for role " .. role .. " already exist")
	if role == "A" then
		assert(readRaw(op.store, op.keyHandover) == nil, "handover key already exists (another A ran)")
	end
end)
if not okPre then
	return refuse(tostring(preErr))
end

local identity = {
	role = role,
	placeId = game.PlaceId,
	gameId = game.GameId,
	jobId = game.JobId,
	privateServerId = game.PrivateServerId,
	privateServerOwnerId = game.PrivateServerOwnerId,
	isStudio = RunService:IsStudio(),
	uncachedReads = okOpts,
}

local onReady = nil
if role == "A" then
	-- move the second approved account into a new reserved server (server B), once
	onReady = function()
		local TeleportService = game:GetService("TeleportService")
		local first = nil
		local deadline = os.clock() + R5.TIMEOUTS.aWaitHandover
		while os.clock() < deadline do
			local present = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if allowed[p.UserId] then
					table.insert(present, p)
				end
			end
			if first == nil and #present >= 1 then
				first = present[1]
			end
			for _, p in ipairs(present) do
				if p ~= first then
					local okT, errT = pcall(function()
						local options = Instance.new("TeleportOptions")
						options.ShouldReserveServer = true -- a NEW reserved server of the same SaveTest place
						TeleportService:TeleportAsync(game.PlaceId, { p }, options)
					end)
					print("[R5] teleport of the second account to server B: ok=" .. tostring(okT) .. " " .. tostring(errT))
					return
				end
			end
			task.wait(1)
		end
		print("[R5] second account never joined server A")
	end
end

Guard.APPROVED.R5_CROSS_SERVER = true -- reset by R5.runRole on every exit path
print("[R5] authorized; role " .. role .. "; JobId " .. game.JobId)
local res = R5.runRole(role, {
	PS = R5.restrict(require(T.ProfileStore), op, role),
	readRaw = readRaw,
	writeResult = writeResult,
	identity = identity,
	onReady = onReady,
})
Guard.APPROVED.R5_CROSS_SERVER = false
print("[R5] role " .. role .. " finished: completedWithoutError=" .. tostring(res.completedWithoutError) .. " resultWritten=" .. tostring(res.resultWritten)
	.. " error=" .. tostring(res.error))
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/R5_arm_command.luau ===
```lua
-- TASK-012 R5 ARM COMMAND (template). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- The ONLY substitutions allowed before sending: __USER_ID_1__ and __USER_ID_2__ (the two approved account UserIds).
-- Sets the bootstrap's authorization attributes (a 2-hour window starting now) and enables it. Nothing reaches a live
-- server until the owner publishes SaveTest.
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
assert(sha(T.SaveTestGuard.Source) == "194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b", "ABORT guard hash")
assert(sha(T.R5CrossServer.Source) == "ed6765f9cdec4da25858b8404dfb6bc5125afe942be3f1acad43ccbe569a93e6", "ABORT R5 module hash")
assert(sha(boot.Source) == "85d7bae626e95e988ad4b48ff2b977d7ca7bc13afd3e8df9cdfa28545c00c17f", "ABORT bootstrap hash")
local ids = { __USER_ID_1__, __USER_ID_2__ }
assert(type(ids[1]) == "number" and type(ids[2]) == "number" and ids[1] ~= ids[2], "ABORT user ids")
-- one-shot precheck (uncached reads only)
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function absent(store, key)
	return DSS:GetDataStore(store):GetAsync(key, opts) == nil
end
assert(absent("TEST_LK_ProfileStore_v2", "player_900000204"), "ABORT handover key exists")
assert(absent("TEST_LK_ProfileStore_v2", "player_900000205"), "ABORT stolen key exists")
assert(absent("TEST_LK_R5_Results", "A") and absent("TEST_LK_R5_Results", "B"), "ABORT results exist")
local now = os.time()
boot:SetAttribute("AuthTest", "R5_CROSS_SERVER")
boot:SetAttribute("AuthNotBefore", now)
boot:SetAttribute("AuthNotAfter", now + 2 * 3600)
boot:SetAttribute("AllowedUserIds", tostring(ids[1]) .. "," .. tostring(ids[2]))
boot.Enabled = true
return game:GetService("HttpService"):JSONEncode({ armed = true, notBefore = now, notAfter = now + 2 * 3600, attributes = boot:GetAttributes() })
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/R5_results_check.luau ===
```lua
-- TASK-012 R5 RESULTS CHECK. Edit DataModel, read-only (uncached GetAsync). Safe to repeat while the test runs.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
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
local okA, resA = get("TEST_LK_R5_Results", "A")
local okB, resB = get("TEST_LK_R5_Results", "B")
local R5 = require(game:GetService("ServerStorage").TestOnly.R5CrossServer) -- pure evaluator; makes no calls
return game:GetService("HttpService"):JSONEncode({
	checks = R5.evaluate(okA and resA or nil, okB and resB or nil),
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

=== FILE: docs/audits/TASK-012/luau/R5_disarm_command.luau ===
```lua
-- TASK-012 R5 DISARM COMMAND. Edit DataModel of the SaveTest window, after the R5 results are collected (or on abort).
-- Removes the auto-running bootstrap from SaveTest. The owner's cleanup publish then removes it from the live place.
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
```
=== END FILE ===

