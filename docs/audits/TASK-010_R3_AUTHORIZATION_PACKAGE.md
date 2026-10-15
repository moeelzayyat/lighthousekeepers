# TASK-010 R3 AUTHORIZATION PACKAGE (corrections)

Combined plain-text package for the auditor. It supersedes the R3 parts of TASK-010_AUDITOR_PACKAGE.md (runner v1 and the draft commands). Nothing has been executed.

## Contents
1. docs/audits/TASK-010/R3_AUTHORIZATION_REQUEST.md (11272 bytes, SHA-256 0499fae46c9521470c226670b6097209496e78b92c57d72e8248b44a516afcfe)
2. docs/audits/TASK-010/luau/R3ServerRunner_v2.luau (14820 bytes, SHA-256 6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733)
3. docs/audits/TASK-010/luau/SaveTestGuard.luau (4636 bytes, SHA-256 4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d)
4. docs/audits/TASK-010/luau/R3_disable_main.luau (892 bytes, SHA-256 1936326a42a2c7f0c26e45559b70c305971d18800faaba71d83c1afc9d28294c)
5. docs/audits/TASK-010/luau/R3_run_command.luau (1938 bytes, SHA-256 56a87fef6ab3799f619c3ec5b6da31288d660d8a30c32a53de3ae0258a6f29dc)
6. docs/audits/TASK-010/luau/R3_status_command.luau (595 bytes, SHA-256 b0a100289d2b7ec2cc82a4e23b4a7848e82eaf088cd712cb448563106ab6b95b)
7. docs/audits/TASK-010/luau/R3_post_stop_check.luau (1585 bytes, SHA-256 b90cee1129ab3b6c2011b4c5720a2ea487fdc5274ab5d2476edeefdb87c32311)

=== FILE: docs/audits/TASK-010/R3_AUTHORIZATION_REQUEST.md ===
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
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3ServerRunner_v2.luau ===
```lua
-- ServerStorage.TestOnly.R3ServerRunner  (v2, TASK-010 corrections)
-- SAVETEST ONLY. Test-only server runner for the first real-server test (R3). A ModuleScript in ServerStorage:
-- it NEVER runs by itself, starting Studio Play does not run it, and nothing in the game requires it.
--
-- It may touch ONLY (Guard.OPERATIONS.R3_SERVER_SESSION):
--   ProfileStore: New("TEST_LK_ProfileStore_v2"), StartSessionAsync("player_900000202") without params,
--                 and on that profile Save and EndSession.
--   Raw DataStore reads (GetAsync only, cache bypassed when the engine allows): TEST_LK_ProfileStore_v2/player_900000202,
--                 TEST_LK_ProfileStore_v2/player_900000201 (the R2 regression fixture: READ ONLY), ____PS/____PS.
--   MessagingService: one test topic "TEST_LK_R3_<id>" (subscribe + one publish to itself), then disconnect.
--   game:BindToClose: registers one no-op callback, only to learn whether registration is allowed here.
-- The outcome is reported as THREE INDEPENDENT results: persistenceAndRelease, messaging, bindToClose.
-- A passing save never implies that messaging or shutdown release works.
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
R3.state = { status = "idle", terminal = false, log = {} }

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

		-- 3. MessagingService and BindToClose availability: recorded separately, never abort the persistence test
		local okM, m = pcall(deps.probeMessaging)
		state.messaging = okM and m or { probeError = tostring(m) }
		note("3a_messaging", state.messaging)
		local okB, b = pcall(deps.probeBindToClose)
		state.bindToClose = okB and b or { probeError = tostring(b) }
		note("3b_bindtoclose", state.bindToClose)

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
		state.librarySubscribed = subscribed
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
	local okFinal, finalRecord = pcall(raw)
	state.finalReadOk = okFinal
	state.finalRecord = okFinal and finalRecord or nil
	state.sessionEverStarted = profile ~= nil
	state.error = (not ok) and tostring(err) or nil

	-- THREE INDEPENDENT RESULTS
	local m = state.messaging or {}
	local b = state.bindToClose or {}
	local fr = state.finalRecord
	state.results = {
		persistenceAndRelease = {
			passed = ok,
			finalPearls = fr and fr.Data and fr.Data.pearls,
			sessionReleasedInStore = fr ~= nil and fr.MetaData ~= nil and fr.MetaData.ActiveSession == nil,
			error = state.error,
		},
		messaging = {
			tested = m.skippedInMock ~= true and m.probeError == nil,
			passed = (m.subscribeOk == true and m.publishOk == true and m.messageReceived == true),
			testTopicSubscribe = m.subscribeOk,
			testTopicPublish = m.publishOk,
			testTopicReceived = m.messageReceived,
			librarySubscribedToItsTakeoverTopic = state.librarySubscribed,
		},
		bindToClose = {
			tested = b.skippedInMock ~= true and b.probeError == nil,
			passed = b.registerOk == true,
			registerError = b.registerError,
			note = "registration only; release of an ACTIVE profile at shutdown is not tested by R3",
		},
	}
	return ok
end

-- Edit-mode dry run against in-memory fakes. Makes no real DataStore, MessagingService or BindToClose call.
function R3.runMock(vendorSource)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[R3.OPERATION]
	assert(op ~= nil, "unknown operation")
	local MockBackend = require(script.Parent.MockBackend)
	R3.state = { status = "running-mock", terminal = false, log = {} }
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
	core(deps, op)
	local writes = {}
	for _, w in ipairs(world.writes) do
		table.insert(writes, w.op .. " " .. w.store .. "/" .. w.key)
	end
	R3.state.mockWrites = writes
	R3.state.status = "mock-terminal"
	R3.state.terminal = true
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
	R3.state = { status = "running", terminal = false, log = {}, startedAt = os.time() }

	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = game:GetService("HttpService")
	local allowedRaw = op.rawReads
	-- bypass the local GetAsync cache when the engine supports it, so release is confirmed from the service
	local okOpts, getOptions = pcall(function()
		local o = Instance.new("DataStoreGetOptions")
		o.UseCache = false
		return o
	end)
	R3.state.uncachedReads = okOpts
	local function readRaw(store, key)
		assert(allowedRaw[store .. "/" .. key] == true, "R3 ABORT: raw read not allowed: " .. store .. "/" .. key)
		local ds = DataStoreService:GetDataStore(store)
		if okOpts then
			return ds:GetAsync(key, getOptions)
		end
		return ds:GetAsync(key)
	end

	R3.state.probeBeforeRequire = select(2, pcall(readRaw, "____PS", "____PS"))
	local ok0, PS = pcall(require, psModule) -- fresh server DataModel: this runs the library's Studio probe once
	if not ok0 then
		Guard.APPROVED[R3.OPERATION] = false
		R3.state.status = "crashed"
		R3.state.terminal = true
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
			uncachedReads = okOpts,
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
				publishError = (not okPub) and pubErr and tostring(pubErr) or nil,
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
		local okRun, errRun = pcall(core, deps, op)
		Guard.APPROVED[R3.OPERATION] = false -- ALWAYS reset
		R3.state.status = okRun and "terminal" or "crashed"
		if not okRun then
			R3.state.error = tostring(errRun)
		end
		R3.state.terminal = true
	end)
	return "started"
end

function R3.status()
	local fr = R3.state.finalRecord
	return {
		status = R3.state.status,
		terminal = R3.state.terminal == true,
		approvedFlagNow = Guard.APPROVED[R3.OPERATION],
		flagReset = Guard.APPROVED[R3.OPERATION] == false,
		sessionReleasedInStore = fr ~= nil and fr.MetaData ~= nil and fr.MetaData.ActiveSession == nil,
		-- Play may be stopped only when this is true: terminal, flag reset, and either no session was ever started
		-- or the final (uncached) read shows the session released.
		safeToStopPlay = R3.state.terminal == true
			and Guard.APPROVED[R3.OPERATION] == false
			and (R3.state.sessionEverStarted ~= true
				or (R3.state.finalReadOk == true and fr ~= nil and fr.MetaData ~= nil and fr.MetaData.ActiveSession == nil)),
		results = R3.state.results,
		error = R3.state.error,
		uncachedReads = R3.state.uncachedReads,
		probeBeforeRequire = R3.state.probeBeforeRequire,
		probeAfterRequire = R3.state.probeAfterRequire,
		finalRecord = fr,
		mockWrites = R3.state.mockWrites,
		log = R3.state.log,
	}
end

return R3
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/SaveTestGuard.luau ===
```lua
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
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_disable_main.luau ===
```lua
-- TASK-010 R3 PRE-STEP (final). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- Applies the disable manifest: the only change is ServerScriptService.Server.Main.Enabled = false.
-- Rollback: set Enabled = true, or restore SaveTest_TASK-010_pre.rbxl.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local main = game:GetService("ServerScriptService").Server.Main
assert(main:IsA("Script"), "ABORT Main is not a Script")
local before = main.Enabled
main.Enabled = false
return "Main.Enabled before=" .. tostring(before) .. " after=" .. tostring(main.Enabled)
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_run_command.luau ===
```lua
-- TASK-010 R3 RUN COMMAND (final, for runner v2). NOT RUN. Requires the owner's explicit approval.
-- Sent ONCE through MCP execute_luau with datamodel_type = "Server", in the SaveTest window's Play session,
-- only after: owner approval of R3, the disable manifest applied (Main.Enabled = false), and Play started.
-- Never re-sent, even if the MCP call times out: progress is read with R3_status_command.luau.
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
assert(sha(T.R3ServerRunner.Source) == "6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733", "ABORT runner hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R3_SERVER_SESSION == false, "ABORT flag already true")
local R3 = require(T.R3ServerRunner)
assert(R3.status().status == "idle", "ABORT runner not idle: " .. tostring(R3.status().status))
Guard.APPROVED.R3_SERVER_SESSION = true -- the runner resets it to false on every exit path
local ok, res = pcall(R3.startReal)
if not ok then
	Guard.APPROVED.R3_SERVER_SESSION = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R3_SERVER_SESSION)
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_status_command.luau ===
```lua
-- TASK-010 R3 STATUS COMMAND (final). Read-only in-memory status, Server DataModel of the Play session.
-- Play may be stopped only when the returned safeToStopPlay is true
-- (terminal, approval flag reset, and the synthetic session released in the stored record, or never started).
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game:GetService("ServerStorage").TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R3ServerRunner).status())
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_post_stop_check.luau ===
```lua
-- TASK-010 R3 POST-STOP CHECK (final). NOT RUN. Edit DataModel of the SaveTest window, after Play has stopped.
-- Read-only: uncached GetAsync of the synthetic key, the fixture and the probe key. No writes.
-- This is a second, independent observation of the stored record (secondary evidence for release).
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
	else
		out.value = value
	end
	out.version = info and info.Version
	out.updatedTime = info and info.UpdatedTime
	return out
end
return game:GetService("HttpService"):JSONEncode({
	synthetic = read("TEST_LK_ProfileStore_v2", "player_900000202"),
	fixture = read("TEST_LK_ProfileStore_v2", "player_900000201"),
	probe = read("____PS", "____PS"),
	mainEnabled = game:GetService("ServerScriptService").Server.Main.Enabled,
})
```
=== END FILE ===

