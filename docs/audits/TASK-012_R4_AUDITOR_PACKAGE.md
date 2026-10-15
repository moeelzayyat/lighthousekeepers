# TASK-012 R4 AUDITOR PACKAGE: active-profile shutdown test (executed once)

Combined plain-text package. R4 ran once in SaveTest under the owner's "execute R4" (2026-10-14 21:29:32Z). Result: PASSED (40 Pearls persisted by the shutdown release; session released; load count 1; fixtures unchanged). Sources are the exact files sent to Studio; hashes re-verified in Studio before the run. R5 was not executed, armed or published.

## Contents
1. docs/audits/TASK-012/R4_EXECUTION_REPORT.md (4113 bytes, SHA-256 7c2313f3e00894443bdec2d1421d30e07803c230dda8d262db27446bed44f232)
2. docs/audits/TASK-012/R4_EXECUTION_APPROVAL_REQUEST.md (2922 bytes, SHA-256 b8bfd1946deb3966232a6a19b51e079d082423cce3b969c90ea9fca0b0deb9af)
3. docs/audits/TASK-012/raw/R4_01_precheck_execution.json (609 bytes, SHA-256 e45ded006020992330f1f79f40a55a7dfff4ddbffaebd8c80627f15fc9666c5d)
4. docs/audits/TASK-012/raw/R4_02_run_command_result.txt (46 bytes, SHA-256 afb416500aeb7b5aa5e861e544405ff2773ef4dba4088582484d39eb0325fd25)
5. docs/audits/TASK-012/raw/R4_03_status_ready.json (786 bytes, SHA-256 9d06305b7d1e40db5d293525ca5f5cff1107e04fc53efe0801640cfd932a3e54)
6. docs/audits/TASK-012/raw/R4_04_console_after_stop.txt (1646 bytes, SHA-256 83f416113504ab926af237fce4f4d1549e5d872f3ab9bc0a1fbcad4940330c7d)
7. docs/audits/TASK-012/raw/R4_05_post_stop_check_edit.json (707 bytes, SHA-256 378cdb7975d8a744bc13beb641876fce09f24770c6746c31f02aab7a504472e1)
8. docs/audits/TASK-012/luau/R4ShutdownRunner.luau (12622 bytes, SHA-256 1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613)
9. docs/audits/TASK-012/luau/R4_run_command.luau (2032 bytes, SHA-256 d93d62d3586b400d778a2d7ba35e929c7808a140b5351196abf7b367ea26ed31)
10. docs/audits/TASK-012/luau/R4_status_command.luau (568 bytes, SHA-256 287eeadc52abe88c96246f8d6bcee91b6a7125a06a6777bd03f2a52fcf09866a)
11. docs/audits/TASK-012/luau/R4_post_stop_check.luau (1582 bytes, SHA-256 703311f6b9f26477914e71eaa0ca3bd45373208bef22c2eae6f0a40fd44e8417)
12. docs/audits/TASK-012/luau/SaveTestGuard.luau (6374 bytes, SHA-256 194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b)

=== FILE: docs/audits/TASK-012/R4_EXECUTION_REPORT.md ===
# R4 EXECUTION REPORT: release of an active profile at Studio shutdown

- **Date:** 2026-10-14. The module loaded and the probe wrote at 21:29:59Z, the session was created in the same second, the approved Stop happened at about 21:30:12Z (`LastUpdate`), and the release write's UpdatedTime is 21:30:15Z.
- **Authorization:** the owner's message "execute R4", 2026-10-14 21:29:32Z, which authorizes one execution under `R4_EXECUTION_APPROVAL_REQUEST.md`.
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`.
- **Executed:** once. There were no retries and no re-sends.
- **Not done:** R5 was not run or armed, nothing was published, and production and Outlaw City were not touched.

## Result: PASSED

| Check | Expected | Observed | Source |
|---|---|---|---|
| Before Stop: stored value | template `pearls 0`, session active | `pearls 0`, `ActiveSession [128620546156998, "", f7a50abf-…]`, load count 1 | `raw\R4_03` (step 5_holding, uncached read) |
| Before Stop: in memory | `pearls 40`, no Save | `memoryPearls 40` | `raw\R4_03` |
| Stop gate | `readyForApprovedStop = true` | true: holding for 4 s, flag reset, profile active, observer registered | `raw\R4_03` |
| Shutdown release | the library's BindToClose writes 40 and releases | console: observer started; OnSessionEnd fired; `released=true after 0.68s storedPearls=40 loadCount=1` | `raw\R4_04` |
| **After Stop: uncached read in Edit** | `pearls 40`, no `ActiveSession`, load count 1 | **`pearls 40`, `activeSession` absent, `sessionLoadCount 1`**, `LastUpdate 1792013412`, UpdatedTime 21:30:15Z | `raw\R4_05` |
| Fixtures preserved | 201 and 202 unchanged | 201: 25 Pearls, load count 2, same version and UpdatedTime as before. 202: 30 Pearls, load count 1, same version and UpdatedTime as before. | `raw\R4_05` |
| Errors | none | only the expected client `WaitForChild` warnings (Main is disabled) | `raw\R4_04` |

## Writes (all expected; nothing else)
1. `____PS/____PS` Studio probe: value `1792005392` → `1792013399` (21:29:59Z).
2. `player_900000203` session start, which created the record.
3. `player_900000203` shutdown release by the library's BindToClose: data `pearls 40`, session cleared.

The key's version string `…0000000002…` is consistent with two writes. Version numbering is not used as proof.

## Pre-execution verification
Done at 21:29:40Z, read-only, in `raw\R4_01`:
- Studio re-listed;
- both IDs asserted, in Edit mode, not running;
- `Main.Enabled = false`;
- R5 bootstrap disabled and with no attributes;
- all flags false;
- hashes: ProfileStore `ad437372…`, guard `194e30d3…`, R4 runner `1a125835…`;
- uncached read: `player_900000203` absent.

The run command re-asserted the same hashes inside the Play server.

## Findings and limits
1. **In a Studio Play server, stopping Play gives ProfileStore's BindToClose time to save and release an active profile.** The release was seen in the store 0.68 s after the observer started. The unsaved in-memory change (40) was persisted by that final write, as the library source says.
2. **`OnSessionEnd` fired before the release write**, which again matches the source. The release is confirmed only by store reads, in-server and then from Edit.
3. **Limits:**
   - This is one Studio server and one profile.
   - Live-server shutdown timing (Roblox's 30 s BindToClose limit, several profiles, slow DataStore responses) is not covered.
   - Both reads come from the same Studio process and account.
4. **Staging folder.** `ServerStorage.TestOnly_R5v2Staging` (R5 v3 code, inert ModuleScripts) was present in the place during the run. It is not required by anything, and the run never touched it.

## State now
- SaveTest is in Edit mode with `Main` disabled.
- The R5 bootstrap is disabled and unarmed. R5 v3 is still staged and not installed.
- Records in `TEST_LK_ProfileStore_v2`: 201 (25 Pearls), 202 (30), 203 (40), all released.

## Next, per the auditor's order, after this evidence is reviewed
1. Install the staged R5 v3 into SaveTest and re-verify the hashes.
2. Account 2 access check.
3. Pre-publish checklist for approval.
=== END FILE ===

=== FILE: docs/audits/TASK-012/R4_EXECUTION_APPROVAL_REQUEST.md ===
# R4 EXECUTION APPROVAL REQUEST

- **Date:** 2026-10-14
- **Status:** not executed. Waiting for the owner's explicit "execute R4".
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`.

## Pre-execution checks (done 2026-10-14 ~20:04Z, read-only, raw output in `raw\R4_00_precheck_edit.json`)

**Studio instances re-listed:**
- production `(132065051336560)`
- Outlaw City `(132163592957463)`
- SaveTest `(128620546156998)`

Only the SaveTest window is used.

**Checks asserted inside the SaveTest window:**
- both IDs;
- Edit mode, not running;
- `Main.Enabled = false`;
- R5 bootstrap present but **disabled with no attributes** (unarmed);
- all approval flags false.

**Uncached read of `TEST_LK_ProfileStore_v2/player_900000203`:** the key does not exist.

**Hashes (in Studio, equal to the reviewed files):**

| Module | SHA-256 |
|---|---|
| ProfileStore | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |
| SaveTestGuard | `194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b` |
| R4ShutdownRunner | `1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613` |

None of these will change before R4 runs. The R5 revision does not touch the Studio guard until after R4.

## Exact steps once approved (each once)
1. Re-list Studio and assert the SaveTest IDs again.
2. Start one Studio Play session in the SaveTest window.
3. Send `R4_run_command.luau` (SHA-256 `d93d62d3586b400d778a2d7ba35e929c7808a140b5351196abf7b367ea26ed31`) **once** to the Server DataModel. It is never re-sent.
4. Poll `R4_status_command.luau` (`287eeadc52abe88c96246f8d6bcee91b6a7125a06a6777bd03f2a52fcf09866a`), read-only, until `readyForApprovedStop = true`.
5. Capture the console. Then **Stop Play**: this is the test's approved action.
   - If `readyForApprovedStop` never becomes true, I do not stop Play. I report and ask for a recovery decision.
   - The only exception is `safeToStopAfterFailure = true` after an early failure.
6. In Edit, run `R4_post_stop_check.luau` (`703311f6b9f26477914e71eaa0ca3bd45373208bef22c2eae6f0a40fd44e8417`) with uncached reads, then capture the console.

## Expected writes (3, and nothing else)
1. `____PS/____PS` Studio probe (1).
2. `player_900000203` session start (1).
3. `player_900000203` shutdown release by the library (1).

Fixtures 201 and 202 are read only.

## Pass and fail criteria

**Pass:**
- `player_900000203` shows `pearls 40`, no `ActiveSession`, and `SessionLoadCount 1`;
- the observer printed `released=true`;
- there are no ProfileStore errors;
- fixtures 201 (25 Pearls) and 202 (30 Pearls) are unchanged.

**Fail:**
- a lock is left behind;
- `pearls ≠ 40`;
- the observer reports `released=false` or prints nothing;
- any ProfileStore error.

On a fail, there is no retry and no recovery without a new approval.

## Approval requested
Reply **"execute R4"** to authorize this single run exactly as written.
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R4_01_precheck_execution.json ===
```json
{"bootPresent":true,"isEdit":true,"bootAttributes":[],"placeId":128620546156998,"mainEnabled":false,"bootEnabled":false,"running":false,"stagingPresent":true,"gameId":10770892134,"time":1792013380,"key203":{"exists":false,"readOk":true},"flags":{"R2_SAVE_LOAD":false,"R5_CROSS_SERVER":false,"R4_SHUTDOWN_RELEASE":false,"R3_SERVER_SESSION":false},"hashes":{"R4ShutdownRunner":"1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613","SaveTestGuard":"194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b","ProfileStore":"ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f"}}
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R4_02_run_command_result.txt ===
```text
startReal ok=true result=started flagNow=true
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R4_03_status_ready.json ===
```json
{"memoryPearls":40,"uncachedReads":true,"profileActive":true,"flagReset":true,"status":"holding","log":[{"t":0,"uncachedReads":true,"isStudio":true,"gameId":10770892134,"jobId":"","placeId":128620546156998,"step":"1_identity","isServer":true},{"dataStoreState":"Access","step":"2_profilestore_init","t":0},{"keyAbsent":true,"t":0.15,"step":"3_precheck"},{"step":"4_session_started","t":0.501,"isActive":true,"sessionLoadCount":1},{"memoryPearls":40,"storedActiveSession":[128620546156998,"","f7a50abf-2bcf-418e-8b5b-97ccb23039a0"],"storedPearls":0,"t":0.599,"step":"5_holding","storedLoadCount":1}],"probeBeforeRequire":1792005392,"readyForApprovedStop":true,"safeToStopAfterFailure":false,"observerRegistered":true,"holdingForSeconds":4,"probeAfterRequire":1792013399,"terminal":true}
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R4_04_console_after_stop.txt ===
```text
Captured in Play before Stop (identical except for the last three lines), and again in Edit after Stop:

Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'  (ReplicatedStorage.Shared.SoundFx, Line 105)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")' (Client.Vitals, Line 10)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'  (Client.Inventory, Line 30)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'  (Client.Shop, Line 29)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'  (Client.Results, Line 23)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")' (Client.Coach, Line 24)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")' (Client.Hud, Line 34)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")' (Client.Storm, Line 12)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'  (Client.Departure, Line 23)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")' (Client.Main, Line 15)
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")' (Client.Menus, Line 28)
[ProfileStore]: Roblox API services available - data will be saved
--- the next three lines appeared only after Stop Play ---
[R4] BindToClose observer started
[R4] OnSessionEnd fired (the release write follows it)
[R4] observer: released=true after 0.68s storedPearls=40 loadCount=1

(The client lines are written as "Players.Lighthouse8282.PlayerScripts.Client.X" with Stack Begin/End markers in the raw output; they are shortened here. No errors.)
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R4_05_post_stop_check_edit.json ===
```json
{"r4":{"ok":true,"pearls":40,"exists":true,"lastUpdate":1792013412,"updatedTime":1792013415368,"version":"08DF2A3A4EB43B14.0000000002.08DF2A3A56445552.01","sessionLoadCount":1},"fixture202":{"ok":true,"pearls":30,"exists":true,"lastUpdate":1792005395,"updatedTime":1792005397531,"version":"08DF2A27AAB2F284.0000000003.08DF2A27AB4375D9.01","sessionLoadCount":1},"fixture201":{"ok":true,"pearls":25,"exists":true,"lastUpdate":1792002152,"updatedTime":1792002154314,"version":"08DF2A201D107A24.0000000005.08DF2A201E27CB15.01","sessionLoadCount":2},"probe":{"ok":true,"updatedTime":1792013402024,"exists":true,"value":1792013399,"version":"08DF2A1E204C399E.0000000003.08DF2A3A4E50225F.01"},"mainEnabled":false}
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

