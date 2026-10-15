# TASK-009 AUDITOR PACKAGE (combined plain-text version)

First real profile save/load test (R2) for Lighthouse Keepers, SaveTest only (place 128620546156998, universe 10770892134; store TEST_LK_ProfileStore_v2, key player_900000201). Production and Outlaw City untouched; nothing published. The entrypoint, guard, run command and status command are included in full. No game-code diffs exist (none changed).

## TABLE OF CONTENTS
1. TASK-009/AUDITOR_REPORT.md
2. TASK-009/CHANGE_MANIFEST.md
3. TASK-009/TEST_EVIDENCE.md
4. TASK-009/AUDITOR_QUESTIONS.md
5. TASK-009/R2_AUTHORIZATION_REQUEST.md
6. TASK-009/PRE_EXECUTION_CHECKS.md
7. TASK-009/luau/R2SaveLoad.luau
8. TASK-009/luau/SaveTestGuard.luau
9. TASK-009/luau/R2_run_command.luau
10. TASK-009/luau/R2_status_command.luau

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-009/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-009: First real profile save/load test (R2)

- **Date:** 2026-10-14
- **Authorized environment:** SaveTest place 128620546156998, universe 10770892134. Store `TEST_LK_ProfileStore_v2`, key `player_900000201`, 25 Pearls, one start/save/release/reload/release sequence.
- **Approvals:** auditor conditional acceptance of `R2_AUTHORIZATION_REQUEST.md`; owner "execute" in chat (18:22 UTC). Production Studio API access owner-reported OFF (18:04 UTC). Production and Outlaw City untouched.

## Result
**R2 passed.** A real ProfileStore session created the synthetic profile with the exact template, saved 25 Pearls (0.30 s), released (release confirmed from the stored record, not from `OnSessionEnd`), a fresh session loaded the same key with 25 Pearls and load count 2, and the second release completed. Final stored record: pearls 25, `SessionLoadCount` 2, no active session, `WasOverwritten` false. No DataStore error was logged, so no retries are evidenced. The `____PS` probe key was unchanged (the module did not re-initialize). The approval flag returned to false by itself.

## Phase A and B summary
Fresh pre-TASK-009 backup verified (`SaveTest_TASK-009_pre.rbxl`, SHA-256 `F4EDB18E…D31B`, scripts as in the live session, `PlayerData` unchanged). Production API OFF cited from the owner's message. A fresh Studio session was **not** used, for the reason given to the owner (the cloud SaveTest place lacks the test scripts; a reopened file has GameId 0); instead the already-loaded module was reused and the probe key proves no re-initialization. The workflow now has one guarded entrypoint (`R2SaveLoad`) restricted to the approved store, key and operations; the guard has per-operation approval flags; cached modules were avoided by recreating edited script instances; a dry run on fakes produced the same 5-write sequence. All six pre-execution conditions were met and documented.

## Findings
1. Save/load and release work with the real DataStore for a single session in this context.
2. `OnSessionEnd` fires about 10 microseconds after `EndSession()`, before the release write; completion must be checked against the stored record, as the test did.
3. In Edit mode, the library cannot use MessagingService (two errors, one per session). Saving is unaffected, but takeover messaging and `BindToClose` (TASK-008) both need a real server context to be tested.
4. `game.JobId` in this Edit context is a GUID, not empty; the earlier inference is withdrawn for this context.

## Implications
- Save data: one synthetic test record now exists in the SaveTest universe (`TEST_LK_ProfileStore_v2/player_900000201`, 25 Pearls, released). Nothing else changed. Gameplay, security, performance: none.

## Deviations
None from the approved scope. One earlier read of the test key was made during the pre-execution checks (read-only, documented).

## Updated approval status
| Item | Status |
|---|---|
| R1 (module initialization) | done (TASK-008) |
| R2 (single save/load) | **done, passed** |
| R3, R4, full matrix, legacy overwrite, v1 import, other keys | not approved, not done |
| Publishing SaveTest / production | not approved, not done |
| D1, D5-D13 | pending |
| D4 | owner-reported done |

## Next recommended test (not started)
**R3 in a real server context:** the same synthetic sequence plus a `BindToClose` release check and MessagingService subscription, on a second fresh key (for example `player_900000202`), run inside a Studio "Run" server session, with the game's own scripts accounted for (the game's `PlayerData` reads `__access_check` at server start, and with no player joining it writes nothing). This needs its own authorization request in the same format.

## Ready for acceptance?
Yes. Stopped after R2 as instructed.
=== END FILE ===

=== FILE: TASK-009/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-009

**No game script, Config value, production data or published version changed. Nothing was published. Production and Outlaw City were not touched.**

## SaveTest in-session changes (Studio, unsaved after the pre-TASK-009 backup)
| Instance | Change | Final SHA-256 |
|---|---|---|
| `ServerStorage.TestOnly.SaveTestGuard` | added per-operation approvals (`Guard.APPROVED`, `Guard.OPERATIONS`, `Guard.assertOperationApproved`); the instance was replaced by a fresh one so `require` would not return the cached old version | `9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab` (3,980 B) |
| `ServerStorage.TestOnly.R2SaveLoad` | new guarded entrypoint (store/key/operation restricted; mock and real paths); recreated once after changing the poll interval for real reads to 1 s | `8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25` (11,374 B) |
| Other TestOnly scripts | unchanged (`ProfileStore` `ad437372…0c95f`, `MockTests` `2feea594…a533`, `MockBackend` `88ad97d4…9376`, `Sha256` `29d6bd69…e13f`) | |

## Real DataStore writes (SaveTest universe only)
Store `TEST_LK_ProfileStore_v2`, key `player_900000201`: created and updated by ProfileStore during R2 (start, save, release, start, release). Final value: profile with `Data.pearls = 25`, `SessionLoadCount = 2`, no active session. No other key or store written. The probe key `____PS` was not written again.

## Local files
`docs\audits\TASK-009\` (this package), sources in `luau\` (entrypoint, guard, run command, status command), `backups\2026-10-14\savetest\SaveTest_TASK-009_pre.rbxl` (owner-saved), `work\savetest-pre009-export\` (scratch export).
=== END FILE ===

=== FILE: TASK-009/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-009 (R2 real save/load)

**Environment:** owner's Studio session; SaveTest window "Private lighthouse keepers" (PlaceId 128620546156998, GameId 10770892134); **Edit mode, no Play session**; MCP `execute_luau`. Players: none. No game script ran (Edit mode), so the game's `PlayerData` did not load or save.
**Approval:** the owner wrote "execute" in chat at 18:22 UTC after the auditor's conditional acceptance and the pre-execution checks (`PRE_EXECUTION_CHECKS.md`).
**Production / Outlaw City:** not addressed. Production Studio API access: owner-reported OFF since 18:04 UTC (D4).

## 1. Execution
- Studio instances re-listed immediately before the run (production, Outlaw City and SaveTest listed separately).
- `luau/R2_run_command.luau` was sent **once**. It re-checked the three installed hashes (ProfileStore `ad437372…0c95f`, guard `9e74c577…8fab`, entrypoint `8a1cac7a…0a25`), asserted the flag was false, set it true and called `startReal()`. Result (verbatim): `startReal ok=true result=started flagNow=true` (the flag is true while the asynchronous test runs, by design).
- `luau/R2_status_command.luau` (read-only, in-memory) was then called once, after an 8 s wait.

## 2. Result (verbatim status returned by the entrypoint)
```
{"probeBefore":1792001296,"log":[{"probeBefore":1792001296,"jobId":"8a9b54d1-714b-4cae-9410-26112c77f519","t":0.116,"step":"0_precheck","keyAbsent":true},{"storedTopLevelKeys":["Data","GlobalUpdates","MetaData"],"storedActiveSession":[128620546156998,"8a9b54d1-714b-4cae-9410-26112c77f519","2f04eb2f-0194-4e60-be7b-191354d39472"],"storedPearls":0,"step":"1_session1_started","t":0.636,"isActive":true,"sessionLoadCount":1},{"t":0.636,"step":"2_template","dataEqualsTemplate":true},{"stillOwnedAfterSave":true,"storedPearls":25,"secondsToSave":0.2972033000551164,"t":0.933,"step":"3_saved","lastSavedSeen":true},{"releaseConfirmedInStore":true,"secondsToStoreRelease":1.0166491998825223,"onSessionEndFired":true,"step":"4_session1_released","t":1.95,"secondsToOnSessionEnd":0.000009499955922365189,"isActiveNow":false},{"storedActiveSession":[128620546156998,"8a9b54d1-714b-4cae-9410-26112c77f519","119f6c31-6326-414c-8874-8f0ae4b7cb53"],"pearlsLoaded":25,"step":"5_session2_started","sameObjectAsSession1":false,"t":2.233,"isActive":true,"sessionLoadCount":2},{"t":2.233,"pearlsEqual25":true,"step":"6_persisted","loadCountIs2":true},{"releaseConfirmedInStore":true,"secondsToStoreRelease":1.0168126001954079,"t":3.25,"step":"7_session2_released","finalStoredPearls":25,"finalSessionLoadCount":2}],"approvedFlagNow":false,"probeAfter":1792001296,"passed":true,"probeBeforeRequire":1792001296,"finalRecord":{"UserIds":[],"RobloxMetaData":[],"GlobalUpdates":[0,[]],"WasOverwritten":false,"Data":{"equippedArmor":"OilskinCoat","pearls":25,"version":1,"equippedWeapon":"DriftwoodHarpoon","owned":{"DriftwoodHarpoon":true},"equippedBeam":"BeamAmber","counts":[],"stats":{"runs":0,"bestNight":0,"victories":0}},"MetaData":{"MetaTags":[],"LastUpdate":1792002152,"ProfileCreateTime":1792002150,"SessionLoadCount":2}},"status":"done","probeUnchanged":true}
```

## 3. Step-by-step reading
| Step | Expected | Observed | Result |
|---|---|---|---|
| 0 precheck | key absent; probe value recorded | key absent; probe `1792001296` | PASS |
| 1 session 1 start | active; load count 1; stored record has `Data`/`GlobalUpdates`/`MetaData`; stored lock = this session | active; load count 1; keys `Data, GlobalUpdates, MetaData`; `ActiveSession = [128620546156998, "8a9b54d1-…", "2f04eb2f-…"]`; stored pearls 0 | PASS |
| 2 template | profile data equals the template | equal | PASS |
| 3 Pearls 25 + Save | `LastSavedData.pearls == 25` and stored pearls 25, session still owned | after 0.30 s; stored 25; still owned | PASS |
| 4 end session 1 | completion proven by the STORED record (lock released, pearls 25), not by `OnSessionEnd` | `OnSessionEnd` fired 0.0000095 s after `EndSession()` (before any write, as the source says); stored release confirmed at the first 1 s poll | PASS |
| 5 session 2 start | new profile object; load count 2; pearls 25; new lock | new object; load count 2; pearls 25; new session GUID | PASS |
| 6 persisted | 25 | 25 | PASS |
| 7 end session 2 | stored release with pearls 25 | confirmed at the first 1 s poll; final load count 2 | PASS |
| Final stored record | pearls 25, no `ActiveSession`, load count 2 | as expected; `WasOverwritten = false` | PASS |
| Probe key | unchanged (no module re-initialization) | `1792001296` before require, before test and after test | PASS |
| Approval flag | false after the run | `approvedFlagNow = false` | PASS |

## 4. DataStore operations (write/read evidence)
- **Writes** (store `TEST_LK_ProfileStore_v2`, key `player_900000201`): the library performs them; Claude cannot count real calls directly. Evidence: the stored record went from absent to created (session 1 start), to pearls 25 while locked (save), to unlocked (release), to locked with load count 2 (session 2 start), to unlocked with load count 2 (release). That is the 5-write sequence; the dry run on fakes made exactly 5. **No retries are evidenced**: the console shows no `[ProfileStore]: DataStore API error` line during R2 (the library logs every failed call that way).
- **Reads** (raw `GetAsync`, allow-listed): the test key about 10 times (precheck, after start, after save, two checks per release, after the second start, final record) and `____PS`/`____PS` 3 times. The pre-execution check made 1 earlier read of the test key.
- **No other store or key** was touched; the probe did not run again.

## 5. Session release evidence
Both releases were confirmed from the stored record (`MetaData.ActiveSession == nil` with pearls 25), not from signals. Final record has no `ActiveSession`. No session is left open.

## 6. Console output during R2 (complete new lines after the backup save)
```
[ProfileStore]: Roblox API services available - data will be saved      <- from the two mock dry runs (fakes), before R2
[ProfileStore]: Roblox API services available - data will be saved      <- same
MessagingService can only be executed by game server
Stack Begin
Script 'ServerStorage.TestOnly.ProfileStore', Line 1340 - function RobloxMessageSubscription
Stack End
MessagingService can only be executed by game server
Stack Begin
Script 'ServerStorage.TestOnly.ProfileStore', Line 1340 - function RobloxMessageSubscription
Stack End
```
The two MessagingService errors are one per session: in Edit mode the library cannot subscribe to its takeover topic (anticipated in the authorization request). Saving was unaffected, but **cross-server takeover messaging does not work in this context**, so session-conflict behaviour must be tested on a real server. Earlier console lines (mock runs, R1, T0) are unchanged from TASK-008.

## 7. Deviations and notes
- None from the approved scope. The run command was sent once; no rerun; no other key or store.
- New fact: in this Studio Edit context `game.JobId` was a GUID (`8a9b54d1-…`), not empty. My earlier inference (TASK-004/005) that it is empty in Studio is **refuted for this context**; whether two Studio sessions get distinct JobIds is still untested.
- The real ProfileStore module stays loaded in this Studio session (no active profiles).
=== END FILE ===

=== FILE: TASK-009/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-009

1. **Edit-mode limits.** Saving works in Edit mode, but MessagingService and `BindToClose` do not. Do you agree the next step must be a real server context (Studio "Run" server, no player) before any session-conflict or shutdown test?
2. **Game scripts in a Run server.** In a "Run" session the game's own server scripts start. With no player, the game's `PlayerData` only reads `__access_check` from the SaveTest copy of `LighthouseKeepers_PlayerData_v1` (no write expected). Is that acceptable, or should those scripts be disabled in the SaveTest copy first (a code change to the test place only)?
3. **The synthetic record left behind.** `player_900000201` now holds 25 Pearls in SaveTest. Leave it (it also stops any accidental rerun of R2 from writing), or remove it later with an approved `RemoveAsync` on that one key?
4. **Fresh Studio session.** We reused the already-loaded module instead of a fresh session, with probe-key evidence of no re-initialization. Acceptable going forward, or do you want a procedure that restores the TestOnly scripts into a fresh session (which would require publishing SaveTest)?
5. **Write counting.** Real writes were inferred from stored-record transitions and the absence of error logs. Do you want an instrumented count next time (for example by reading `GetRequestBudgetForRequestType` before and after)?

No further concern has been invented; items 1 and 2 are the real forks.
=== END FILE ===

=== FILE: TASK-009/R2_AUTHORIZATION_REQUEST.md ===
# R2 authorization request (TASK-009 Phase C) — NOT YET RUN

## 1. Exact script to execute
- Run command: `luau/R2_run_command.luau` (executed once through MCP `execute_luau` in the SaveTest window).
- It calls `ServerStorage.TestOnly.R2SaveLoad.startReal()`; the entrypoint's full source is `luau/R2SaveLoad.luau` (SHA-256 `8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25`); the guard is `luau/SaveTestGuard.luau` (SHA-256 `9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab`). The run command refuses to start unless the installed ProfileStore, guard and entrypoint hashes all match these values.
- Progress is read with `luau/R2_status_command.luau` (in-memory status only, no DataStore call).

## 2. Verified target IDs
SaveTest PlaceId 128620546156998, GameId 10770892134, asserted inside the run command, inside the guard, and inside the entrypoint. Production 132065051336560 / 10769064643 rejected. Outlaw City never addressed.

## 3. Execution context
SaveTest Studio window, **Edit mode, no Play session**, MCP `execute_luau` (plugin/command context). Consequences: none of the game's own scripts run, so the game's `PlayerData` cannot load or save anything (no `LighthouseKeepers_PlayerData_v1` access); `BindToClose` cannot be registered in this context (seen in TASK-008), which does not matter here because both sessions are ended explicitly. The test runs asynchronously (`startReal` returns at once) to avoid MCP time-outs.

## 4. Expected stores, keys and operations
| Store / key | Operation | Count (expected) |
|---|---|---|
| `TEST_LK_ProfileStore_v2` / `player_900000201` | `UpdateAsync` writes by ProfileStore: session 1 start, Save of Pearls 25, session 1 release, session 2 start, session 2 release | **5** (the dry run on fakes produced exactly these 5) |
| `TEST_LK_ProfileStore_v2` / `player_900000201` | raw `GetAsync` reads by the test (precheck, after each step, release polling once per second) | about 8-14 |
| `____PS` / `____PS` | raw `GetAsync` reads (before require, before and after the test) | 3 |
The test aborts **before any write** if `player_900000201` already exists.

## 5. Possible unintended writes and how each is handled
| Possible write | Handling |
|---|---|
| Repeat Studio probe (`____PS`/`____PS`) | The real module is already loaded in this Studio session since R1, so `require` returns the cached module and the probe does not run again. If Studio had been restarted, the probe would run once more (same store/key as R1). The status reports `probeBeforeRequire`, `probeBefore`, `probeAfter` so a repeat is visible. **Accepted only as this one known write.** |
| Library retries | A failed `UpdateAsync` during session start is retried, and release saves repeat until success; any retry writes the same key only. |
| Library autosave | Default 300 s and skips profiles loaded less than 150 s ago; each session lives seconds, so no autosave is expected. |
| MessagingService | each session subscribes to a topic `PS_<guid>`; not a DataStore write; may log an error in Edit mode, which does not affect saving. |
| The game's own `PlayerData` (`LighthouseKeepers_PlayerData_v1`) | cannot run: Edit mode, no Play, no player. |
| Any other store or key | impossible through the entrypoint: `New` only accepts `TEST_LK_ProfileStore_v2`, `StartSessionAsync` only `player_900000201` with no parameters, and raw reads are allow-listed. `RemoveAsync`, `MessageAsync`, `GetAsync`-view, `VersionQuery`, `Steal`, `Cancel` are not exposed. |
| Production or Outlaw City | not addressed; IDs asserted. |

## 6. Stop and recovery behaviour
- Any failed check stops the remaining steps. A recovery block then ends any session still active and waits (polling once per second, up to 20 s) until the stored record shows the lock released.
- The approval flag is reset to false by the entrypoint on every exit path; the status shows it.
- I will report and stop on any unexpected result, and will not re-run without a new approval.
- If Studio closes mid-run, the record could stay locked; ProfileStore treats such a lock as dead after 630 s. Only the synthetic key is affected.

## 7. Evidence that will be returned
The status log (every step with stored values), the final stored record of `player_900000201`, the probe-key values, the flag value afterwards, and the Studio console output.

## 8. Not requested and not allowed
Legacy-record overwrite tests, v1 import, other keys, production DataStores, publishing, R3/R4, the full matrix.
=== END FILE ===

=== FILE: TASK-009/PRE_EXECUTION_CHECKS.md ===
# R2 pre-execution checks (auditor's six conditions), 2026-10-14 — before any R2 write

| # | Condition | Evidence |
|---|---|---|
| 1 | SHA-256 of `R2SaveLoad.luau`, `SaveTestGuard.luau`, `R2_run_command.luau`, pinned ProfileStore | Local files: `R2SaveLoad.luau` `8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25` (11,374 B); `SaveTestGuard.luau` `9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab` (3,980 B); `R2_run_command.luau` `42d054965240c38067547ed2ca6fee4c7b2ae51944a9201742ee33ec07f22ae7` (1,447 B); `R2_status_command.luau` `99cf5a608962010d7746b4f4a06883a50c5bc9afede63fbd46b8b6e4ef6942e6`; pinned vendor `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`. **Installed in SaveTest (computed inside Studio):** ProfileStore, guard and entrypoint hashes identical to the above. The run command itself re-checks all three installed hashes and aborts on any mismatch. |
| 2 | Only one R2 execution at a time | Three independent locks: (a) the run command aborts unless the approval flag is false, and the flag stays true for the whole asynchronous run, so a second command during a run aborts; (b) `startReal` refuses while its status is "running"; (c) the test's first step aborts without writing if `player_900000201` already exists, so any second run after a completed one writes nothing. |
| 3 | No automatic rerun after an MCP timeout | `startReal` returns immediately and the test continues inside Studio, so the run command itself is short. Claude sends the run command **once** and never re-sends it; if that call times out, Claude only reads status with the read-only status command and reports. Locks (a)-(c) also prevent a duplicate even if a command were repeated. |
| 4 | Synthetic key absent | Read-only `GetAsync` on `TEST_LK_ProfileStore_v2` / `player_900000201` in SaveTest returned nil (`keyAbsent: true`). |
| 5 | Both exact SaveTest IDs before any DataStore operation | The check above asserted PlaceId 128620546156998 and GameId 10770892134 (and rejected production IDs) before its single read; the run command, the guard and the entrypoint each assert them again. |
| 6 | Complete source copies preserved | `docs/audits/TASK-009/luau/` holds the entrypoint, guard, run command and status command in full; they will be included verbatim in the package. |

Current state: R2 approval flag `false`; real-module flag `false`; entrypoint status `mock-done` (from the dry run); the real ProfileStore is cached in this Studio session since R1.
=== END FILE ===

=== FILE: TASK-009/luau/R2SaveLoad.luau ===
-- ServerStorage.TestOnly.R2SaveLoad
-- SAVETEST ONLY. The single guarded entrypoint for the R2 synthetic save/load test.
--
-- It may touch ONLY:  store "TEST_LK_ProfileStore_v2",  key "player_900000201"
--   ProfileStore operations: New, StartSessionAsync (no params), and on the returned profiles Save and EndSession.
--   Raw reads (GetAsync, no writes): that same store/key, and the probe key "____PS"/"____PS" (to prove no repeat probe).
-- It never calls RemoveAsync, MessageAsync, GetAsync-view, VersionQuery, Steal or Cancel, and exposes none of them.
-- The real ProfileStore module is reached only inside this module, only after Guard.assertOperationApproved, and the
-- approval flag is reset to false by this module itself on every exit path.
--
-- Two entrypoints, neither takes any argument that could change store, key or module:
--   R2.runMock(vendorSource)  -- vendor TEXT against in-memory fakes; no real DataStore call; runs synchronously
--   R2.startReal()            -- real module and real DataStore; returns at once; poll R2.status()

local Guard = require(script.Parent.SaveTestGuard)
local R2 = {}

R2.OPERATION = "R2_SAVE_LOAD"
R2.TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}
R2.state = { status = "idle", log = {} }

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

-- interval: seconds between checks. Checks that read the real DataStore use 1 s to stay far inside the read budget.
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

-- Restricts a ProfileStore-like module to the approved store and key.
local function restrict(PS, op)
	local proxy = {}
	function proxy.New(storeName, template)
		assert(storeName == op.store, "R2 ABORT: store not allowed: " .. tostring(storeName))
		local real = PS.New(storeName, template)
		local storeProxy = {}
		function storeProxy:StartSessionAsync(key, params)
			assert(key == op.key, "R2 ABORT: key not allowed: " .. tostring(key))
			assert(params == nil, "R2 ABORT: no StartSessionAsync params are allowed (no Steal, no Cancel)")
			return real:StartSessionAsync(key)
		end
		return storeProxy
	end
	function proxy.getState()
		return PS.DataStoreState
	end
	return proxy
end

-- The test itself. deps = { PS = restricted module, readRaw = function(store, key) -> value, jobId = string }
local function core(deps, op)
	local state = R2.state
	local t0 = os.clock()
	local function note(step, data)
		data.step = step
		data.t = math.floor((os.clock() - t0) * 1000) / 1000
		table.insert(state.log, data)
	end
	local function raw()
		return deps.readRaw(op.store, op.key)
	end
	local function released(expectPearls)
		local r = raw()
		return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil and r.Data ~= nil and r.Data.pearls == expectPearls
	end

	local profile1, profile2
	local ok, err = pcall(function()
		-- 0. probe key before (read only) and the test key must not exist yet
		state.probeBefore = deps.readRaw("____PS", "____PS")
		local pre = raw()
		note("0_precheck", { keyAbsent = pre == nil, probeBefore = state.probeBefore, jobId = deps.jobId })
		assert(pre == nil, "R2 ABORT: the test key already exists; nothing was written")

		-- 1. new ProfileStore session (first session for this key)
		local store = deps.PS.New(op.store, R2.TEMPLATE)
		profile1 = store:StartSessionAsync(op.key)
		assert(profile1 ~= nil, "R2 ABORT: StartSessionAsync returned nil")
		local sessionEnded1At
		profile1.OnSessionEnd:Connect(function()
			sessionEnded1At = os.clock()
		end)
		local rec1 = raw()
		note("1_session1_started", {
			isActive = profile1:IsActive(),
			sessionLoadCount = profile1.SessionLoadCount,
			storedTopLevelKeys = (function()
				local ks = {}
				for k in pairs(rec1 or {}) do
					table.insert(ks, k)
				end
				table.sort(ks)
				return ks
			end)(),
			storedActiveSession = rec1 and rec1.MetaData and rec1.MetaData.ActiveSession,
			storedPearls = rec1 and rec1.Data and rec1.Data.pearls,
		})
		assert(profile1:IsActive() and profile1.SessionLoadCount == 1, "R2 ABORT: session 1 not active or load count not 1")

		-- 2. default template
		local templateOk = deepEqual(profile1.Data, R2.TEMPLATE)
		note("2_template", { dataEqualsTemplate = templateOk })
		assert(templateOk, "R2 ABORT: the new profile does not equal the template")

		-- 3. change Pearls to 25 and save; wait for the save to complete (LastSavedData), never for a signal
		profile1.Data.pearls = 25
		profile1:Save()
		local saved, savedAfter = waitUntil(function()
			return profile1.LastSavedData ~= nil and profile1.LastSavedData.pearls == 25
		end, 20)
		local rec2 = raw()
		note("3_saved", {
			lastSavedSeen = saved,
			secondsToSave = savedAfter,
			storedPearls = rec2 and rec2.Data and rec2.Data.pearls,
			stillOwnedAfterSave = rec2 and rec2.MetaData and rec2.MetaData.ActiveSession ~= nil,
		})
		assert(saved and rec2 and rec2.Data.pearls == 25, "R2 ABORT: save of 25 pearls not confirmed in the store")

		-- 4. end session 1; completion = the STORED record shows the lock released with the data, not OnSessionEnd
		local endCalledAt = os.clock()
		profile1:EndSession()
		local rel1, rel1After = waitUntil(function()
			return released(25)
		end, 20, 1)
		note("4_session1_released", {
			releaseConfirmedInStore = rel1,
			secondsToStoreRelease = rel1After,
			onSessionEndFired = sessionEnded1At ~= nil,
			secondsToOnSessionEnd = sessionEnded1At and (sessionEnded1At - endCalledAt) or nil,
			isActiveNow = profile1:IsActive(),
		})
		assert(rel1, "R2 ABORT: release of session 1 not confirmed in the store")

		-- 5. fresh session for the same key
		profile2 = store:StartSessionAsync(op.key)
		assert(profile2 ~= nil, "R2 ABORT: second StartSessionAsync returned nil")
		local rec3 = raw()
		note("5_session2_started", {
			isActive = profile2:IsActive(),
			sessionLoadCount = profile2.SessionLoadCount,
			pearlsLoaded = profile2.Data.pearls,
			storedActiveSession = rec3 and rec3.MetaData and rec3.MetaData.ActiveSession,
			sameObjectAsSession1 = profile2 == profile1,
		})

		-- 6. persistence confirmed
		note("6_persisted", { pearlsEqual25 = profile2.Data.pearls == 25, loadCountIs2 = profile2.SessionLoadCount == 2 })
		assert(profile2.Data.pearls == 25, "R2 FAIL: pearls did not persist")

		-- 7. end session 2 cleanly
		profile2:EndSession()
		local rel2, rel2After = waitUntil(function()
			return released(25)
		end, 20, 1)
		local final = raw()
		note("7_session2_released", {
			releaseConfirmedInStore = rel2,
			secondsToStoreRelease = rel2After,
			finalStoredPearls = final and final.Data and final.Data.pearls,
			finalSessionLoadCount = final and final.MetaData and final.MetaData.SessionLoadCount,
			finalActiveSession = final and final.MetaData and final.MetaData.ActiveSession,
		})
		assert(rel2, "R2 ABORT: release of session 2 not confirmed in the store")
	end)

	-- recovery: never leave a session open
	for i, p in ipairs({ profile1 or false, profile2 or false }) do
		if p and p:IsActive() then
			p:EndSession()
			note("recovery_end_session_" .. i, { endedBecauseOf = tostring(err) })
		end
	end
	if profile1 or profile2 then
		waitUntil(function()
			local r = raw()
			return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil
		end, 20, 1)
	end

	state.probeAfter = deps.readRaw("____PS", "____PS")
	state.probeUnchanged = state.probeBefore == state.probeAfter
	state.finalRecord = raw()
	state.error = (not ok) and tostring(err) or nil
	state.passed = ok
	return ok
end

-- Mock path: vendor text vs in-memory fakes. Makes no real DataStore call.
function R2.runMock(vendorSource)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[R2.OPERATION]
	assert(op ~= nil, "unknown operation")
	local MockBackend = require(script.Parent.MockBackend)
	R2.state = { status = "running-mock", log = {} }
	local world = MockBackend.newWorld()
	local h = MockBackend.loadVendor(vendorSource, world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = "JOB_A" })
	assert(waitUntil(function()
		return h.PS.DataStoreState == "Access"
	end, 3), "mock state never Access")
	local deps = {
		PS = restrict(h.PS, op),
		jobId = "JOB_A",
		readRaw = function(store, key)
			return MockBackend.record(world, store, key)
		end,
	}
	local ok = core(deps, op)
	local writes = {}
	for _, w in ipairs(world.writes) do
		table.insert(writes, w.op .. " " .. w.store .. "/" .. w.key)
	end
	R2.state.mockWrites = writes
	R2.state.status = ok and "mock-done" or "mock-failed"
	h.destroy()
	return R2.state
end

-- Real path. Needs Guard.APPROVED.R2_SAVE_LOAD == true (owner approval). Returns at once; poll R2.status().
function R2.startReal()
	local op = Guard.assertOperationApproved(R2.OPERATION)
	assert(R2.state.status ~= "running", "R2 already running")
	local ps = script.Parent:FindFirstChild("ProfileStore")
	assert(ps ~= nil and ps:IsA("ModuleScript"), "ProfileStore module missing")
	assert(game:GetService("RunService"):IsEdit() and not game:GetService("RunService"):IsRunning(), "R2 ABORT: Edit mode only")
	R2.state = { status = "running", log = {}, startedAt = os.time() }
	local DataStoreService = game:GetService("DataStoreService")
	-- read (no write) the probe key BEFORE the module is reached: if the module is not already loaded, requiring it
	-- would run its Studio probe again, and this value lets the status show whether the probe key changed
	local okPre, probePre = pcall(function()
		return DataStoreService:GetDataStore("____PS"):GetAsync("____PS")
	end)
	R2.state.probeBeforeRequire = okPre and probePre or nil
	local ok0, PS = pcall(require, ps)
	if not ok0 then
		Guard.APPROVED[R2.OPERATION] = false
		R2.state.status = "failed"
		R2.state.error = "require failed: " .. tostring(PS)
		return "failed to load module"
	end
	local allowedRaw = op.rawReads
	local deps = {
		PS = restrict(PS, op),
		jobId = game.JobId,
		readRaw = function(store, key)
			assert(allowedRaw[store .. "/" .. key] == true, "R2 ABORT: raw read not allowed: " .. store .. "/" .. key)
			return DataStoreService:GetDataStore(store):GetAsync(key)
		end,
	}
	task.spawn(function()
		local okRun, passed = pcall(core, deps, op)
		Guard.APPROVED[R2.OPERATION] = false -- ALWAYS reset, on every path
		R2.state.status = (okRun and passed) and "done" or "failed"
		if not okRun then
			R2.state.error = tostring(passed)
		end
	end)
	return "started"
end

function R2.status()
	return {
		status = R2.state.status,
		approvedFlagNow = Guard.APPROVED[R2.OPERATION],
		passed = R2.state.passed,
		error = R2.state.error,
		probeBeforeRequire = R2.state.probeBeforeRequire,
		probeBefore = R2.state.probeBefore,
		probeAfter = R2.state.probeAfter,
		probeUnchanged = R2.state.probeUnchanged,
		finalRecord = R2.state.finalRecord,
		mockWrites = R2.state.mockWrites,
		log = R2.state.log,
	}
end

return R2
=== END FILE ===

=== FILE: TASK-009/luau/SaveTestGuard.luau ===
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
Guard.APPROVED = { R2_SAVE_LOAD = false }
Guard.OPERATIONS = {
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

=== FILE: TASK-009/luau/R2_run_command.luau ===
-- TASK-009 R2 RUN COMMAND (to be executed once, only after the owner's explicit "approve R2").
-- Runs in the SaveTest Studio window, Edit mode, through MCP execute_luau.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local T = game.ServerStorage.TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab", "ABORT guard hash")
assert(sha(T.R2SaveLoad.Source) == "8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25", "ABORT entrypoint hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R2_SAVE_LOAD == false, "ABORT flag already true")
Guard.APPROVED.R2_SAVE_LOAD = true -- the entrypoint resets it to false on every exit path
local ok, res = pcall(function()
	return require(T.R2SaveLoad).startReal()
end)
if not ok then
	Guard.APPROVED.R2_SAVE_LOAD = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R2_SAVE_LOAD)
=== END FILE ===

=== FILE: TASK-009/luau/R2_status_command.luau ===
-- TASK-009 R2 STATUS COMMAND (read-only; polls the in-memory status of the running test; makes no DataStore call)
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game.ServerStorage.TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R2SaveLoad).status())
=== END FILE ===

