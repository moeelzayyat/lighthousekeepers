# TASK-010 AUDITOR PACKAGE (combined plain-text version)

Real-server test preparation for Lighthouse Keepers, SaveTest only (place 128620546156998, universe 10770892134). PREPARATION ONLY: no server was started, no DataStore write, nothing published; production and Outlaw City untouched. Complete runner source, guard source and draft commands are included in full.

## TABLE OF CONTENTS
1. TASK-010/AUDITOR_REPORT.md
2. TASK-010/CHANGE_MANIFEST.md
3. TASK-010/TEST_EVIDENCE.md
4. TASK-010/AUDITOR_QUESTIONS.md
5. TASK-010/SCRIPT_DISABLE_MANIFEST.md
6. TASK-010/SERVER_TEST_PLAN.md
7. TASK-010/luau/R3ServerRunner.luau
8. TASK-010/luau/SaveTestGuard.luau
9. TASK-010/luau/R3_run_command.luau
10. TASK-010/luau/R3_status_command.luau

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-010/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-010: Real-server test preparation

- **Date:** 2026-10-14
- **Target:** SaveTest place 128620546156998, universe 10770892134. Production and Outlaw City untouched. **Preparation only: no server run, no DataStore write, nothing published.**

## Phase A
IDs verified in-script; fresh owner backup `SaveTest_TASK-010_pre.rbxl` verified; pinned ProfileStore and all test-script hashes verified inside Studio; the regression fixture `player_900000201` was not touched. Auto-run inventory: of 99 scripts, only `ServerScriptService.Server.Main` runs at server start, and it is the only path to the game's sole DataStore user (`PlayerData`). **Proposed smallest disable set: `Main.Enabled = false` in SaveTest** (not applied; `SCRIPT_DISABLE_MANIFEST.md`).

## Phase B: server runner
`ServerStorage.TestOnly.R3ServerRunner` (ModuleScript, SHA-256 `bff3b190…5773`) plus a guard entry `R3_SERVER_SESSION` (guard SHA-256 `4d85ffc6…500d`). Properties:
- runs only when both exact SaveTest IDs match, the per-operation flag is true, and it is inside a **running server** (refused in Edit even with the flag, shown by execution);
- reaches only `TEST_LK_ProfileStore_v2/player_900000202` for writes, reads the fixture `player_900000201` and the `____PS` probe key only, exposes only `New`, `StartSessionAsync` (no params), `Save`, `EndSession`;
- records identity (PlaceId, GameId, JobId, IsServer, IsStudio), ProfileStore state, MessagingService subscribe/publish/receive on a `TEST_LK_R3_` topic, BindToClose registration, the library's own takeover subscription, stored lock, saved value, release status;
- **is inert**: a ModuleScript never auto-runs, Play does not start it, nothing requires it, the flag starts false in every new server and is reset by the runner on every exit;
- dry run on fakes passed with the expected writes (fake probe + 3 on the new key).

## Phase C: proposed first real-server test
Identity, ProfileStore init, MessagingService check, fresh session on `player_900000202`, Pearls 30 save and release, BindToClose registration (`SERVER_TEST_PLAN.md`). **Expected real writes: 4** (1 `____PS` probe from the fresh server module + 3 on `player_900000202`). Context: Studio Play started and stopped through MCP; code runs in the Server DataModel; the game's `Main` disabled so the owner's avatar data is never loaded or saved.

## Whether Studio is enough
- **BindToClose:** a Studio Play server is a real server DataModel, so registration should work. The test records it.
- **MessagingService:** unknown in a Studio Play server, and the test measures it. If it does not work, only a published SaveTest server can test it. That would need the owner to publish SaveTest, players joining through the Roblox client, and an in-server trigger. The MCP cannot reach live servers, so the trigger would be an auto-running, authorization-gated Script, which conflicts with the current rule against auto-running test Scripts. It is therefore not proposed.
- **Server-only "Run" mode:** the MCP tool can only start Play (with the avatar). Run mode would need the owner to click Run, and it is not required once `Main` is disabled.

## Implications
None yet. If approved: SaveTest gains `Main` disabled (reversible), one probe write, and one new synthetic record. No change to game code contents, economy, gameplay or production.

## Known limitations
See `SERVER_TEST_PLAN.md` section 6.

## Ready for audit
Yes. Stopped before any server test. Execution needs the owner's explicit approval of the exact runner, manifest and plan.
=== END FILE ===

=== FILE: TASK-010/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-010

**No game script, Config value, saved data or published version changed; no DataStore write; no Play; nothing published; production and Outlaw City untouched.**

## SaveTest in-session changes (Edit mode; the backup `SaveTest_TASK-010_pre.rbxl` predates them)
| Instance | Change | SHA-256 after |
|---|---|---|
| `ServerStorage.TestOnly.SaveTestGuard` | added operation `R3_SERVER_SESSION` (flag false); replaced by a fresh clone so `require` sees the edit | `4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d` |
| `ServerStorage.TestOnly.R3ServerRunner` | new ModuleScript (inert) | `bff3b190a7559cdb3f8c32ea7211185715a54854de8d869eccb5a4f5778c5773` |
| `ServerScriptService.Server.Main` | **unchanged** (`Enabled = true`); disabling it is only proposed | — |

## Files on disk
`docs\audits\TASK-010\` (this package) with `luau\R3ServerRunner.luau`, `luau\SaveTestGuard.luau`, `luau\R3_run_command.luau` (draft), `luau\R3_status_command.luau` (draft).

## Rollback of this task's changes
Delete `ServerStorage.TestOnly.R3ServerRunner`, or restore `SaveTest_TASK-010_pre.rbxl`. The guard change is inert (one more flag, false).
=== END FILE ===

=== FILE: TASK-010/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-010 (preparation only)

**No server was started, no Play session, no real DataStore write, no MessagingService call, nothing published.** Every Studio call ran in the SaveTest window in Edit mode with both IDs asserted.

## 1. Identity checks
| Check | Result |
|---|---|
| Studio instances re-listed | production `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, SaveTest `(128620546156998)` |
| SaveTest asserted in-script | PlaceId 128620546156998, GameId 10770892134, not production, Edit mode, not running |

## 2. Backup
`backups\2026-10-14\savetest\SaveTest_TASK-010_pre.rbxl`, saved by the owner: 835,947 bytes, valid header, SHA-256 `52A1CF55AC91BD40BAD2E58415CD081BFE3BDE68B99872F451725612CF6E372D`.

## 3. Hashes (computed inside Studio; equal to the files in `luau/`)
| Script | SHA-256 |
|---|---|
| `TestOnly.ProfileStore` (pinned) | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |
| `TestOnly.SaveTestGuard` (updated: adds `R3_SERVER_SESSION`, flag false) | `4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d` |
| `TestOnly.R3ServerRunner` (new) | `bff3b190a7559cdb3f8c32ea7211185715a54854de8d869eccb5a4f5778c5773` |
| `TestOnly.R2SaveLoad`, `MockTests`, `MockBackend`, `Sha256` | unchanged from TASK-009 (`8a1cac7a…`, `2feea594…`, `88ad97d4…`, `29d6bd69…`) |
| game `PlayerData` | `8413e9ff…bdd2d8` (unchanged) |
Both new or edited scripts compile (compile-only check). The guard instance was replaced by a fresh clone so `require` would see the edit.

## 4. Auto-run inventory
All 99 `BaseScript`s listed in `SCRIPT_DISABLE_MANIFEST.md`. Only `ServerScriptService.Server.Main` runs at server start; the game's only DataStore code is `PlayerData`, reached through `Main`. The disable manifest is **not applied**: `Main.Enabled` is still `true`.

## 5. Inertness of the runner (proved by execution in Edit mode, no Play)
| Check | Result |
|---|---|
| Default flags | `R2_SAVE_LOAD = false`, `R3_SERVER_SESSION = false` |
| `startReal()` without approval | refused: "SaveTestGuard ABORT: operation not approved: R3_SERVER_SESSION" |
| `startReal()` with the flag set, but in Edit mode | refused before any DataStore call: "R3 ABORT: must run in a running server"; flag reset to false immediately |
| Status after both refusals | still `idle` |
| By construction | the runner is a ModuleScript in `ServerStorage`; Studio Play does not run it; nothing in the game requires it; a new Play server starts with the flag false |

## 6. Dry run on in-memory fakes (`R3.runMock`), no real calls
Steps 1, 2, 3a (skipped in mock), 3b (skipped in mock), 3c fixture read, 3d precheck, 4 session start, 5a save, 5b release: **passed**. Fake writes: `SetAsync ____PS/____PS` (fake probe), then 3 × `UpdateAsync TEST_LK_ProfileStore_v2/player_900000202`. The fixture `player_900000201` was read only.

## 7. Not done
Applying the disable manifest, starting Play, any real DataStore/MessagingService/BindToClose call, publishing.
=== END FILE ===

=== FILE: TASK-010/AUDITOR_QUESTIONS.md ===
# QUESTIONS REQUIRING OWNER / AUDITOR APPROVAL — TASK-010

1. **Approve the disable manifest?** `ServerScriptService.Server.Main.Enabled = false` in SaveTest only (reversible). Without it, a Play session runs the whole game, and the game's `PlayerData` loads and may save the owner's avatar data in the SaveTest copy of `LighthouseKeepers_PlayerData_v1`.
2. **Approve the R3 runner and plan as written?** That covers `R3ServerRunner` SHA-256 `bff3b190…5773`, guard `4d85ffc6…500d`, the draft run command, the new key `player_900000202`, 30 Pearls, and 4 expected writes (1 probe and 3 on the new key).
3. **Studio Play (avatar joins) as the server context?** It is started and stopped through MCP, so no clicks are needed from you. The alternative is "Run" (server only), which needs your click.
4. **The `____PS` probe write.** A fresh Play server always re-runs the library's probe once. Accept it as part of R3?
5. **MessagingService.** If it turns out not to work in a Studio Play server, should MessagingService testing be deferred? Or do you want a design for a published-server test? That design would need an authorization-gated auto-running Script and one SaveTest publish by you.
6. **After the test**, keep `Main` disabled in SaveTest for further tests, or re-enable it straight away?
7. **Shutdown release of an active profile.** Do you want it as a separate later test? It would leave a session open on a third synthetic key, stop Play, then verify the release from Edit.

Items 1, 2 and 5 are the real decisions.
=== END FILE ===

=== FILE: TASK-010/SCRIPT_DISABLE_MANIFEST.md ===
# Proposed script-disable manifest for SaveTest (TASK-010) — PROPOSAL ONLY, NOT APPLIED

## What would run automatically when a server starts in SaveTest
Inventory read from the SaveTest window (Edit mode, IDs asserted), all 99 `BaseScript`s:
| Location | Count | Runs at server start? |
|---|---|---|
| `ServerScriptService.Server.Main` (Script, Enabled, RunContext Legacy) | 1 | **Yes.** It is the only server entry point; it requires every server module (`PlayerData`, `GameState`, `IslandBuilder`, `LobbyBuilder`, services). |
| `ServerStorage.Backups.*` Scripts and LocalScripts (Legacy RunContext) | 85 | No: Legacy scripts do not run from `ServerStorage`. |
| `StarterPlayer.StarterPlayerScripts.Client.*` LocalScripts | 13 (12 enabled) | Only on a **client**, when a player joins (Studio Play adds the owner's avatar). Client code cannot use DataStores. |
| `ServerStorage.TestOnly.*` | ModuleScripts only | Never by themselves. |
| Workspace, ReplicatedFirst, StarterGui, StarterPack, StarterCharacterScripts | 0 scripts | — |

Source search of the exported game (`src\`): the only DataStore use in game code is `ServerScriptService.Server.PlayerData` (`GetDataStore`, line 291; `BindToClose`, line 332); no game code uses MessagingService or MemoryStore. `PlayerData` is reached only through `Main`.

## What would happen in a Studio Play session if nothing is disabled
- `PlayerData.init`: one `GetAsync("__access_check")` on the SaveTest copy of `LighthouseKeepers_PlayerData_v1` (read).
- The owner's avatar joins: `PlayerData` loads `player_11752219158` from that SaveTest store (read), and game systems may mark the profile changed; on Stop, a **write** to `LighthouseKeepers_PlayerData_v1/player_11752219158` in the SaveTest universe is possible.
- Gameplay starts (lobby, island build, run loop, remotes).

## Proposed smallest set to disable
| # | Instance | Change | Effect |
|---|---|---|---|
| 1 | `ServerScriptService.Server.Main` | `Enabled = false` (SaveTest only) | No game server code runs: no `PlayerData`, no DataStore call from the game, no gameplay loop, no remotes. Client LocalScripts still start for the avatar but wait forever for the server's remotes; they cannot reach DataStores. |
Nothing else needs disabling.

## Rollback
Set `ServerScriptService.Server.Main.Enabled = true` in the SaveTest window (or restore `backups\2026-10-14\savetest\SaveTest_TASK-010_pre.rbxl`). Production is not involved.

## Not changed by this proposal
Game code contents, `PlayerData`, economy, gameplay, any production asset.
=== END FILE ===

=== FILE: TASK-010/SERVER_TEST_PLAN.md ===
# R3 real-server test plan (TASK-010) — PROPOSAL, NOT APPROVED, NOT RUN

## 1. Context and why
- **Context:** a Studio **Play** session of the SaveTest window, started and stopped through MCP `start_stop_play` (the MCP tool can only start Play, which also adds the owner's avatar as a client; it cannot start the server-only "Run" mode, which would need the owner's click). Test code runs through MCP `execute_luau` in the **Server** DataModel of that session.
- **Genuine server?** The Play server is a separate server DataModel (`RunService:IsServer()` true, fresh module cache, `BindToClose` fires on Stop). Whether MessagingService works in a Studio Play server is **not known**; step 3 measures it. If it does not, MessagingService can only be tested on a real published server, which would need: one publish of the SaveTest place by the owner (with `Main` disabled and the runner inside), joining it from the Roblox client, and an in-server trigger. The MCP cannot execute code in a live server, so that trigger would have to be an auto-running, authorization-gated Script. That conflicts with the "no auto-running test Script" rule, which is why it is **not** proposed now.
- **Prerequisite:** the disable manifest (`Main.Enabled = false`) applied first, so the game's `PlayerData` cannot run and the avatar's data is never loaded or saved.

## 2. Test sequence (the auditor's six items)
| # | Step | DataStore effect |
|---|---|---|
| 1 | Server identity: PlaceId, GameId, JobId, IsServer, IsStudio, PrivateServerId | none |
| 2 | ProfileStore initialization in the server (fresh module in the server DataModel) | **1 write** `____PS`/`____PS` by the library's Studio probe (known; a fresh server always re-runs it); probe key read before and after |
| 3 | MessagingService: subscribe to `TEST_LK_R3_<id>`, publish one message to itself, check receipt, disconnect; `BindToClose`: register one no-op callback and record whether it is allowed | none (MessagingService is not a DataStore) |
| — | Regression fixture `player_900000201` | **read only** (expect 25 Pearls, released) |
| 4 | Fresh synthetic session on `TEST_LK_ProfileStore_v2/player_900000202` (must not exist; abort without writing if it does); record the stored lock (should carry the server JobId) and whether the library's own takeover subscription succeeded | **1 write** (session start) |
| 5 | Pearls = 30, `Save`, confirm in the store; `EndSession`, confirm release **from the stored record** | **2 writes** (save, release) |
| 6 | Shutdown registration: evidence from step 3 and from the console (no "BindToClose can only be called on the server" error); then Stop Play through MCP | **0 writes expected** (no profile is active at Stop) |
**Expected writes: 4** (1 probe + 3 on `player_900000202`). Retries, if any, appear as `[ProfileStore]: DataStore API error` lines and are recorded separately. Reads: probe key 2, fixture 1, test key about 6.

## 3. Exact execution steps (after approval)
1. Re-list Studio windows; assert SaveTest IDs.
2. Apply the disable manifest in Edit mode (`Main.Enabled = false`); verify.
3. Confirm runner and guard hashes in Edit mode.
4. `start_stop_play(true)` on the SaveTest window only.
5. In the **Server** DataModel: assert IDs and server state; set `Guard.APPROVED.R3_SERVER_SESSION = true`; call `R3.startReal()` once. Never resend this command.
6. Poll `R3.status()` (in-memory only) until `done` or `failed`.
7. Read the Studio console.
8. `start_stop_play(false)`.
9. Back in Edit mode: read-only check of `player_900000202`, `player_900000201` and `____PS`.
10. Leave `Main` disabled until the auditor accepts, or roll back on request.

## 4. Safeguards
- **No accidental run:** the runner is a ModuleScript in `ServerStorage`; starting Play runs nothing of it. It refuses unless the per-operation flag is true, the IDs match, and it is inside a running server. The flag starts false in every new server DataModel and is reset by the runner on every exit.
- **Single run:** the flag lock, `status ~= "running"`, and the key-absent precheck (a second run after success writes nothing).
- **MCP timeout:** `startReal` returns at once; the start command is sent once and never re-sent; only status reads follow.
- **Unexpected Stop or Studio crash mid-test:** the library's `BindToClose` (if registered) releases the session; otherwise the lock on `player_900000202` expires after 630 s. Only that synthetic key is affected. If ProfileStore cannot release, the record stays locked but unchanged.
- **Unexpected anything:** stop, report, no retry.

## 5. Rollback
`Main.Enabled = true` in SaveTest, or restore `SaveTest_TASK-010_pre.rbxl`. The synthetic records (`player_900000201`, `player_900000202`) and the `____PS` probe key may stay; they are inert test data in the SaveTest universe.

## 6. Known limitations
- MessagingService behaviour in a Studio Play server is unknown until measured; a published-server test would cost a SaveTest publish and an auto-running trigger.
- The avatar's client scripts will run and wait for remotes (harmless noise in the output).
- Shutdown *release* of an active profile is not tested in this first run (no profile is active at Stop). A later test could leave a session open on a third synthetic key and Stop, then read it from Edit.
- Real takeover, legacy overwrite, migration and live player data are out of scope.
=== END FILE ===

=== FILE: TASK-010/luau/R3ServerRunner.luau ===
-- ServerStorage.TestOnly.R3ServerRunner
-- SAVETEST ONLY. Test-only server runner for the first real-server test (R3). A ModuleScript in ServerStorage:
-- it NEVER runs by itself, starting Studio Play does not run it, and nothing in the game requires it.
--
-- It may touch ONLY (Guard.OPERATIONS.R3_SERVER_SESSION):
--   ProfileStore: New("TEST_LK_ProfileStore_v2"), StartSessionAsync("player_900000202") without params,
--                 and on that profile Save and EndSession.
--   Raw DataStore reads (GetAsync only): TEST_LK_ProfileStore_v2/player_900000202,
--                 TEST_LK_ProfileStore_v2/player_900000201 (the R2 regression fixture: READ ONLY), ____PS/____PS.
--   MessagingService: one test topic "TEST_LK_R3_<guid>" (subscribe + one publish to itself), then disconnect.
--   game:BindToClose: registers one no-op callback, only to learn whether registration is allowed here.
-- Entry points (no argument can change store, key or module):
--   R3.runMock(vendorSource)  -- vendor TEXT vs in-memory fakes, Edit mode; no real DataStore/MessagingService call
--   R3.startReal()            -- real module, real DataStore, ONLY in a running Studio server (Play), ONLY with approval
--   R3.status()               -- in-memory status, no DataStore call

local Guard = require(script.Parent.SaveTestGuard)
local R3 = {}

R3.OPERATION = "R3_SERVER_SESSION"
R3.TEST_PEARLS = 30
R3.TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}
R3.state = { status = "idle", log = {} }

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- interval: seconds between checks; checks that read the real DataStore use 1 s
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
		assert(storeName == op.store, "R3 ABORT: store not allowed: " .. tostring(storeName))
		local real = PS.New(storeName, template)
		local storeProxy = {}
		function storeProxy:StartSessionAsync(key, params)
			assert(key == op.key, "R3 ABORT: key not allowed: " .. tostring(key))
			assert(params == nil, "R3 ABORT: no StartSessionAsync params are allowed")
			return real:StartSessionAsync(key)
		end
		return storeProxy
	end
	return proxy
end

-- deps = { PS, readRaw(store,key), probeMessaging() -> table, probeBindToClose() -> table, identity = table }
local function core(deps, op)
	local state = R3.state
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
		-- 1. server identity
		note("1_identity", deps.identity)

		-- 2. ProfileStore initialization (state after the module loaded)
		note("2_profilestore_init", { dataStoreState = deps.PS.getState and deps.PS.getState() or nil })

		-- 3. MessagingService and BindToClose availability (no DataStore involved)
		note("3a_messaging", deps.probeMessaging())
		note("3b_bindtoclose", deps.probeBindToClose())

		-- regression fixture (read only) and precheck of the new key
		local fixture = deps.readRaw(op.store, op.fixtureKey)
		note("3c_fixture_read_only", {
			fixturePearls = fixture and fixture.Data and fixture.Data.pearls,
			fixtureReleased = fixture ~= nil and fixture.MetaData ~= nil and fixture.MetaData.ActiveSession == nil,
			fixtureLoadCount = fixture and fixture.MetaData and fixture.MetaData.SessionLoadCount,
		})
		local pre = raw()
		note("3d_precheck", { keyAbsent = pre == nil })
		assert(pre == nil, "R3 ABORT: the test key already exists; nothing was written")

		-- 4. fresh synthetic session
		local store = deps.PS.New(op.store, R3.TEMPLATE)
		profile = store:StartSessionAsync(op.key)
		assert(profile ~= nil, "R3 ABORT: StartSessionAsync returned nil")
		local endedAt
		profile.OnSessionEnd:Connect(function()
			endedAt = os.clock()
		end)
		-- the library subscribes to its takeover topic in a separate thread; give it a moment, then look
		local subscribed = waitUntil(function()
			return profile.roblox_message_subscription ~= nil
		end, 5)
		local rec1 = raw()
		note("4_session_started", {
			isActive = profile:IsActive(),
			sessionLoadCount = profile.SessionLoadCount,
			templateOk = deepEqual(profile.Data, R3.TEMPLATE),
			libraryMessagingSubscribed = subscribed,
			storedActiveSession = rec1 and rec1.MetaData and rec1.MetaData.ActiveSession,
		})
		assert(profile:IsActive() and profile.SessionLoadCount == 1, "R3 ABORT: session not active or load count not 1")

		-- 5. one controlled save and release
		profile.Data.pearls = R3.TEST_PEARLS
		profile:Save()
		local saved, savedAfter = waitUntil(function()
			return profile.LastSavedData ~= nil and profile.LastSavedData.pearls == R3.TEST_PEARLS
		end, 20)
		local rec2 = raw()
		note("5a_saved", {
			lastSavedSeen = saved,
			secondsToSave = savedAfter,
			storedPearls = rec2 and rec2.Data and rec2.Data.pearls,
		})
		assert(saved and rec2 and rec2.Data.pearls == R3.TEST_PEARLS, "R3 ABORT: save not confirmed in the store")
		local endCalledAt = os.clock()
		profile:EndSession()
		local released, relAfter = waitUntil(function()
			local r = raw()
			return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil and r.Data.pearls == R3.TEST_PEARLS
		end, 20, 1)
		local final = raw()
		note("5b_released", {
			releaseConfirmedInStore = released,
			secondsToStoreRelease = relAfter,
			secondsToOnSessionEnd = endedAt and (endedAt - endCalledAt) or nil,
			finalPearls = final and final.Data and final.Data.pearls,
			finalLoadCount = final and final.MetaData and final.MetaData.SessionLoadCount,
			finalActiveSession = final and final.MetaData and final.MetaData.ActiveSession,
		})
		assert(released, "R3 ABORT: release not confirmed in the store")
	end)

	-- recovery: never leave the session open
	if profile and profile:IsActive() then
		profile:EndSession()
		note("recovery_end_session", { because = tostring(err) })
		waitUntil(function()
			local r = raw()
			return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil
		end, 20, 1)
	end
	state.finalRecord = raw()
	state.error = (not ok) and tostring(err) or nil
	state.passed = ok
	return ok
end

-- Edit-mode dry run against in-memory fakes. Makes no real DataStore, MessagingService or BindToClose call.
function R3.runMock(vendorSource)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[R3.OPERATION]
	assert(op ~= nil, "unknown operation")
	local MockBackend = require(script.Parent.MockBackend)
	R3.state = { status = "running-mock", log = {} }
	local world = MockBackend.newWorld()
	local h = MockBackend.loadVendor(vendorSource, world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = "JOB_A" })
	assert(waitUntil(function()
		return h.PS.DataStoreState == "Access"
	end, 3), "mock state never Access")
	MockBackend.seed(world, op.store, op.fixtureKey, {
		Data = { pearls = 25 },
		MetaData = { SessionLoadCount = 2 },
		GlobalUpdates = { 0, {} },
	})
	local restricted = restrict(h.PS, op)
	restricted.getState = function()
		return h.PS.DataStoreState
	end
	local deps = {
		PS = restricted,
		identity = { mock = true, jobId = "JOB_A" },
		readRaw = function(store, key)
			return MockBackend.record(world, store, key)
		end,
		probeMessaging = function()
			return { skippedInMock = true }
		end,
		probeBindToClose = function()
			return { skippedInMock = true }
		end,
	}
	local ok = core(deps, op)
	local writes = {}
	for _, w in ipairs(world.writes) do
		table.insert(writes, w.op .. " " .. w.store .. "/" .. w.key)
	end
	R3.state.mockWrites = writes
	R3.state.status = ok and "mock-done" or "mock-failed"
	h.destroy()
	return R3.state
end

-- Real path: only inside a RUNNING Studio server, only with Guard.APPROVED.R3_SERVER_SESSION == true.
-- Returns at once; poll R3.status(). The flag is reset to false on every exit path.
function R3.startReal()
	local op = Guard.assertOperationApproved(R3.OPERATION)
	local RunService = game:GetService("RunService")
	assert(RunService:IsServer() and RunService:IsRunning() and not RunService:IsEdit(), "R3 ABORT: must run in a running server")
	assert(R3.state.status ~= "running", "R3 already running")
	local psModule = script.Parent:FindFirstChild("ProfileStore")
	assert(psModule ~= nil and psModule:IsA("ModuleScript"), "ProfileStore module missing")
	R3.state = { status = "running", log = {}, startedAt = os.time() }

	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = game:GetService("HttpService")
	local allowedRaw = op.rawReads
	local function readRaw(store, key)
		assert(allowedRaw[store .. "/" .. key] == true, "R3 ABORT: raw read not allowed: " .. store .. "/" .. key)
		return DataStoreService:GetDataStore(store):GetAsync(key)
	end

	R3.state.probeBeforeRequire = select(2, pcall(readRaw, "____PS", "____PS"))
	local ok0, PS = pcall(require, psModule) -- fresh server DataModel: this runs the library's Studio probe once
	if not ok0 then
		Guard.APPROVED[R3.OPERATION] = false
		R3.state.status = "failed"
		R3.state.error = "require failed: " .. tostring(PS)
		return "failed to load module"
	end
	waitUntil(function()
		return PS.DataStoreState ~= "NotReady"
	end, 20)
	R3.state.probeAfterRequire = select(2, pcall(readRaw, "____PS", "____PS"))

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
			isRunning = RunService:IsRunning(),
			privateServerId = game.PrivateServerId,
		},
		probeMessaging = function()
			local MessagingService = game:GetService("MessagingService")
			local topic = "TEST_LK_R3_" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
			local got = false
			local okSub, conn = pcall(function()
				return MessagingService:SubscribeAsync(topic, function()
					got = true
				end)
			end)
			local okPub, pubErr = false, nil
			if okSub then
				okPub, pubErr = pcall(function()
					MessagingService:PublishAsync(topic, { r3 = true })
				end)
				waitUntil(function()
					return got
				end, 5)
				pcall(function()
					conn:Disconnect()
				end)
			end
			return {
				topic = topic,
				subscribeOk = okSub,
				subscribeError = (not okSub) and tostring(conn) or nil,
				publishOk = okPub,
				publishError = pubErr and tostring(pubErr) or nil,
				messageReceived = got,
			}
		end,
		probeBindToClose = function()
			local okB, errB = pcall(function()
				game:BindToClose(function() end)
			end)
			return { registerOk = okB, registerError = (not okB) and tostring(errB) or nil }
		end,
	}
	task.spawn(function()
		local okRun, passed = pcall(core, deps, op)
		Guard.APPROVED[R3.OPERATION] = false -- ALWAYS reset
		R3.state.status = (okRun and passed) and "done" or "failed"
		if not okRun then
			R3.state.error = tostring(passed)
		end
	end)
	return "started"
end

function R3.status()
	return {
		status = R3.state.status,
		approvedFlagNow = Guard.APPROVED[R3.OPERATION],
		passed = R3.state.passed,
		error = R3.state.error,
		probeBeforeRequire = R3.state.probeBeforeRequire,
		probeAfterRequire = R3.state.probeAfterRequire,
		finalRecord = R3.state.finalRecord,
		mockWrites = R3.state.mockWrites,
		log = R3.state.log,
	}
end

return R3
=== END FILE ===

=== FILE: TASK-010/luau/SaveTestGuard.luau ===
-- ServerStorage.TestOnly.SaveTestGuard
-- SAVETEST ONLY. Never copy this into the production place.
--
-- Purpose: refuse to initialize ProfileStore or touch any DataStore unless BOTH exact SaveTest IDs match,
-- the production IDs do not, the store name is a TEST_LK_ name, and the owner has flipped the approval flag.
-- Nothing in the game requires this module. It is only used by hand-run test code.

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
Guard.APPROVED = { R2_SAVE_LOAD = false, R3_SERVER_SESSION = false }
Guard.OPERATIONS = {
	-- TASK-010 (proposed, not approved): first real-server session test. player_900000201 is the R2 regression
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
=== END FILE ===

=== FILE: TASK-010/luau/R3_run_command.luau ===
-- TASK-010 R3 RUN COMMAND — DRAFT, NOT APPROVED, NOT RUN.
-- To be sent ONCE, through MCP execute_luau with datamodel_type = "Server", in the SaveTest window's Play session,
-- only after: owner approval of R3, the disable manifest applied (Main.Enabled = false), and Play started.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsServer() and RS:IsRunning() and not RS:IsEdit(), "ABORT not a running server")
assert(game:GetService("ServerScriptService").Server.Main.Enabled == false, "ABORT game Main is enabled")
local T = game:GetService("ServerStorage").TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d", "ABORT guard hash")
assert(sha(T.R3ServerRunner.Source) == "bff3b190a7559cdb3f8c32ea7211185715a54854de8d869eccb5a4f5778c5773", "ABORT runner hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R3_SERVER_SESSION == false, "ABORT flag already true")
Guard.APPROVED.R3_SERVER_SESSION = true -- the runner resets it to false on every exit path
local ok, res = pcall(function()
	return require(T.R3ServerRunner).startReal()
end)
if not ok then
	Guard.APPROVED.R3_SERVER_SESSION = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R3_SERVER_SESSION)
=== END FILE ===

=== FILE: TASK-010/luau/R3_status_command.luau ===
-- TASK-010 R3 STATUS COMMAND — DRAFT. Read-only in-memory status, Server DataModel of the Play session.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game:GetService("ServerStorage").TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R3ServerRunner).status())
=== END FILE ===

