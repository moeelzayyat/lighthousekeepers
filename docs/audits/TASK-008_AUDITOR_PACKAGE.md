# TASK-008 AUDITOR PACKAGE (combined plain-text version)

First real ProfileStore verification for Lighthouse Keepers, SaveTest only (place 128620546156998, universe 10770892134). Production and Outlaw City untouched by Claude. Exactly one real DataStore write was made (the library's own Studio probe, store ____PS, key ____PS, SaveTest universe), after the owner's explicit R1 approval; the guard flag was set back to blocked immediately after. No source diffs of game code exist (none changed). The three Luau files are included in full.

## TABLE OF CONTENTS
1. TASK-008/AUDITOR_REPORT.md
2. TASK-008/CHANGE_MANIFEST.md
3. TASK-008/TEST_EVIDENCE.md
4. TASK-008/AUDITOR_QUESTIONS.md
5. TASK-008/luau/R1_real_init.luau
6. TASK-008/luau/R1_followup_read.luau
7. TASK-008/luau/MockTests.luau

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-008/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-008: First real ProfileStore verification

- **Date:** 2026-10-14
- **Authorized environment only:** SaveTest place 128620546156998, universe 10770892134. Production (132065051336560 / 10769064643) and Outlaw City untouched by Claude.
- **Request (auditor verdict relayed by the owner):** Phase A safety checks; Phase B correct the mock suite (M3) and re-run the cancellation tests; Phase C controlled real-module initialization (R1) only with the owner's separate approval, allowing only the Studio probe write to `____PS`/`____PS`; Phase D this package. Stop afterwards.

## Outcome in one paragraph
All Phase A checks passed (IDs, `PlayerData` unchanged, installed ProfileStore hash equal to the pinned hash, guard flag blocked, backups intact); the owner turned production Studio API access off himself (owner-reported, not verifiable by Claude). Phase B corrected M3 and added M3b and M11b; all 17 mock tests pass as written, now labelled as functional, cancellation regression or destructive demonstration. With the owner's explicit "approve R1", the real pinned ProfileStore was loaded **once** through `SaveTestGuard`; its Studio probe succeeded (`DataStoreState = "Access"`), the guard flag was set back to false straight after, and the probe key `____PS`/`____PS` in the SaveTest universe now holds the timestamp of that write. No session, save, removal or fixture operation was called.

## Phase A
IDs asserted in-script before every run; SaveTest API access on; production API access owner-reported off after D4; `PlayerData` SHA-256 `8413e9ff...bdd2d8` unchanged; `ProfileStore` SHA-256 `AD437372...0C95F` (64,654 bytes) re-verified inside Studio and locally; all local backups preserved with hashes recorded (`TEST_EVIDENCE.md` section 1).

## Phase B
M3 now expects what it observed (Cancel already true: no write, legacy record untouched). M3b and M11b document the in-flight cancel behaviour. The suite distinguishes: 11 functional tests, 2 cancellation regressions, 4 demonstrations on synthetic fake data (M2, M3b, M11b, M13). Result: **17/17 pass as written.** One process error is disclosed: the first re-run used a cached copy of the old test module; it was spotted and re-run with a fresh copy.

## Phase C (R1)
Exact real write performed: **one** `SetAsync` of `os.time()` to store `____PS`, key `____PS`, in the SaveTest universe, made by the library's own probe at module load. Output, console and the resulting key value are in `TEST_EVIDENCE.md` section 3. Console shows no real-module warning except `BindToClose can only be called on the server.` (the real module's shutdown handler was not registered in this Edit-mode context). Nothing else was written.

## Deviations and limitations (read these)
1. **Unguarded require.** The follow-up read-only script called `require(...ProfileStore)` directly once to read `DataStoreState`. It was a cached module, so nothing re-ran, but it bypassed `SaveTestGuard`'s "single sanctioned path" rule.
2. **Production API setting is owner-reported**, before and after.
3. The real module is now loaded in the open SaveTest Studio session with its (empty) autosave loop connected; it clears on Studio restart. SaveTest holds unsaved in-session changes (updated `MockTests`, loaded module) that are not in any saved `.rbxl`.
4. The mock suite uses my own fakes; it does not demonstrate real DataStore behaviour.
5. `BindToClose` was not registered for the real module in Edit mode, so shutdown behaviour of the real module is still untested.

## Next approval requests
1. R2: `ProfileStore.New` plus one `StartSessionAsync`/`Save`/`EndSession` cycle on a **fresh synthetic key** in `TEST_LK_ProfileStore_v2` (writes: session start, save, release).
2. Decision on publishing SaveTest for two-server tests, or dropping those rows.
3. Whether to save the SaveTest window's current state to a new local file and whether to keep the real module loaded or restart Studio first.
4. Decisions D1 and D5-D13.
5. Confirm that production Studio API access should stay OFF.

## Ready for acceptance?
Yes as a controlled real-initialization milestone. No persistence implementation is authorized.
=== END FILE ===

=== FILE: TASK-008/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-008

**No game script, Config value, saved player data or published version was changed; nothing was published; production and Outlaw City were not touched by Claude.**

## In-place changes in SaveTest (PlaceId 128620546156998, GameId 10770892134) — unsaved to any file
| Item | Change | Hash |
|---|---|---|
| `ServerStorage.TestOnly.MockTests` | edited: M3 expectation corrected, M3b and M11b added, `ORDER` and `KIND` tables, `kind` field in results | before `cb4d22d7...7196cf`, after `2feea5946973ea51dabc9a9fdf551d8b8bf7c8ea82bd86b23b26990f84e6a533` (19,451 bytes), equal to `docs\audits\TASK-008\luau\MockTests.luau` |
| `ServerStorage.TestOnly.SaveTestGuard` | **no source change.** Its in-memory flag `REAL_DATASTORE_APPROVED` was set true for one `require` and set back to false in the same script; verified false afterwards | `4b2ae473...c8a4` (unchanged) |
| temporary instance `ServerStorage.TestOnly.MockTests_fresh` | created as a clone for each test run and destroyed immediately; `TestOnly` holds exactly the same 5 scripts as before | none remains |
| runtime state | the real `ProfileStore` module was `require`d once (R1) and remains loaded in this Studio session | source unchanged `AD437372...0C95F` |

## Real DataStore write (one, owner-approved: "approve R1")
Universe 10770892134 (SaveTest), store `____PS`, key `____PS`, value the Unix timestamp `1792001296`, written by the library's own Studio probe. Persistent data of the game, economy values, prices, and production data: unchanged.

## Files created on disk (inside `C:\RobloxProjects\LighthouseKeepers\`)
`docs\audits\TASK-008\` (this package), `docs\audits\TASK-008\luau\MockTests.luau`, `luau\R1_real_init.luau`, `luau\R1_followup_read.luau`. No source diffs against game scripts exist (none changed).
=== END FILE ===

=== FILE: TASK-008/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-008

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (PlaceId 128620546156998, GameId 10770892134), Edit mode, no Play session. Players: none. Device/emulator: none.
**Production DataStores:** not read, not written. **Real DataStore write in this task: exactly one** (R1 probe, below). Everything else ran against in-memory fakes or was read-only.

## 1. Phase A: identity, settings, integrity
| # | Check | Result |
|---|---|---|
| 1 | Studio instances re-listed before each run | production `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, SaveTest `(128620546156998)`; Outlaw City untouched |
| 2 | Both SaveTest IDs asserted inside every script before execution | PlaceId 128620546156998, GameId 10770892134, not production, Edit mode and not running |
| 3 | Production Studio API access | **owner reports it was ON earlier and that he turned it OFF himself in this task (D4 yes: "disabled api in production")**. Claude cannot read this setting and did not touch it. Recorded as owner-reported |
| 4 | SaveTest Studio API access | ON (owner-reported; also functionally shown by the successful DataStore read and write in this task) |
| 5 | Original `PlayerData` unchanged | SaveTest Source SHA-256 `8413e9ff936a86f0b9d7fc26d6b5174a430d3b4119a2b5f1c00d3762a4bdd2d8`, length 10,259 = the v148 export hash; store-name line still `LighthouseKeepers_PlayerData_v1`; no new script references it |
| 6 | Installed `ProfileStore` hash (computed inside Studio with the pure-Luau SHA-256, plus earlier from the saved file) | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`, 64,654 bytes = pinned; local pinned file also re-hashed equal |
| 7 | Guard flag before and after | `REAL_DATASTORE_APPROVED` false before R1, false after R1, false in an independent later read |
| 8 | Local backups preserved (hashes recorded) | `SaveTest_pre-TASK-007.rbxl` `D2AC31D6...9BA9B05A`; `SaveTest_TASK-007_integrated.rbxl` `45CF80C3...FAB54D6`; v148 `6AF4E727...03B5C8`; v149 and `LighthouseKeepers_SaveTest_from_v148.rbxl` `0C880E87...7307EF` |

## 2. Phase B: mock-suite correction and results (vendor text vs in-memory fakes; the real module was never required in this phase)
Changes to `MockTests` (installed script and local file `luau/MockTests.luau`, both SHA-256 `2feea5946973ea51dabc9a9fdf551d8b8bf7c8ea82bd86b23b26990f84e6a533`, 19,451 bytes; it compiles): M3's expected outcome now matches observed behaviour (a Cancel that is already true causes **no write**: returned nil, legacy record unchanged); M3b and M11b added (Cancel flips true after the load started); every result now carries a `kind`.
| Test | Kind | Result |
|---|---|---|
| M0 probe/options on fakes | functional | PASS |
| M1 record shape and release | functional | PASS |
| M2 legacy v1 record, normal start | **destructive demo (synthetic data)** | PASS = destructive behaviour observed (record replaced by template, pearls 500 -> 0, `OnOverwrite` fired) |
| M3 legacy + Cancel true from the first call | **cancellation regression** | PASS = no write, legacy pearls kept |
| M3b legacy + Cancel true after load starts | **destructive demo (synthetic data)** | PASS = legacy record overwritten (wrapper present, pearls 0) |
| M4 `GetAsync` view of legacy record | functional | PASS (template shown, stored record unchanged, 0 writes) |
| M5 responsive takeover | functional | PASS |
| M6 fencing after takeover | functional | PASS |
| M7 unresponsive holder (scaled timing) | functional | PASS |
| M8 dead lock | functional | PASS |
| M9 failed save not retried; release retries | functional | PASS |
| M10 double start | functional | PASS |
| M11 new key + Cancel true from the first call | **cancellation regression** | PASS = nothing created |
| M11b new key + Cancel true after load starts | **side-effect demo (synthetic data)** | PASS = empty template record created, no active session |
| M12 shutdown release | functional | PASS |
| M13 equal JobId | **weakness demo (synthetic data)** | PASS = two profiles active at once |
| M14 guard behaviours | functional | PASS |
**All 17 tests pass as written (11 functional, 2 cancellation regressions, 4 demonstrations).** Process note: my first re-run used a **cached copy** of the old test module (Studio caches `require`), which showed only the old tests; I noticed the missing M3b/M11b and `kind` fields and re-ran with a fresh clone of the updated script (the clone was destroyed afterwards; `TestOnly` again holds exactly 5 scripts).

## 3. Phase C: R1, the single real initialization (owner approved in chat: "approve R1")
- **Executed script:** `luau/R1_real_init.luau` (exact code). It asserted both exact SaveTest IDs and Edit mode, asserted the installed source hash equals the pinned hash, asserted the flag was false, set `REAL_DATASTORE_APPROVED = true`, called `SaveTestGuard.requireRealProfileStore(ServerStorage.TestOnly.ProfileStore)` inside a `pcall`, **set the flag back to false immediately afterwards**, then waited (read-only) for `DataStoreState`.
- **Not called:** `ProfileStore.New`, `StartSessionAsync`, `Save`, `EndSession`, `RemoveAsync`, `MessageAsync`, `GetAsync`, or any fixture/import code.
- **Output (verbatim):** `{"secondsToSettle":0.5345892000477761,"flagBefore":false,"isClosing":false,"isCriticalState":false,"flagAfterRequire":false,"moduleType":"table","requireOk":true,"sourceSha":"ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f","startedAt":1792001296,"dataStoreState":"Access"}`
- **Reading:** the module loaded without error; its own probe (`SetAsync("____PS", os.time())`) succeeded in 0.53 s; state `Access`; not in critical state; not closing.
- **Resulting DataStore state (read-only follow-up, `luau/R1_followup_read.luau`):** store `____PS`, key `____PS` holds the number `1792001296` (equal to `startedAt`, 8 s old when read). No `TEST_LK_*` store was written.
- **Console output after R1:** one `[ProfileStore]: Roblox API services available - data will be saved` among the earlier mock-run messages (the vendor prints it for each loaded instance, including the fakes; the real one cannot be separated by the log), and at the end `BindToClose can only be called on the server.` raised from `ProfileStore` line 2208 in a spawned task. This means the real module's shutdown handler was **not** registered in this Edit-mode context (limitation, no persistence consequence since no profile was loaded). No other warnings from the real module. The log also contains earlier expected lines: the first T0 attempt's "StudioAccessToApisNotAllowed" and the mock tests' own fake-failure messages.
- **Deviation to disclose:** the follow-up read script called `require(ServerStorage.TestOnly.ProfileStore)` **directly, not through the guard**, to read `DataStoreState`. The module was already cached from the guarded require, so nothing re-initialized and no further operation ran (flag was false; the guard would have refused a first load). It breaks the "all real-module access goes through the guard" rule and is recorded in the script header.
- **Left behind by R1:** the real module's `RunService.Heartbeat` autosave loop is connected in this Studio session, and its autosave list is empty, so it performs no saves. It disappears when Studio restarts. Its `BindToClose` was not registered (see above).
- **Stopped on unexpected behaviour?** Nothing unexpected happened; no stop was needed.

## 4. Not performed (not approved)
Any real `ProfileStore.New`, `StartSessionAsync`, save, end-session, removal, fixtures, v1 import; published-server tests; Play sessions; production or Outlaw City anything; publishing.

## 5. Remaining risks
Owner-reported (not verified) production API setting; the real module is now loaded in this Studio session with its autosave loop connected (inert); mock results are my own fakes, not real-DataStore behaviour; the SaveTest window holds unsaved in-session changes (updated `MockTests`, real module loaded) that are not in any saved file yet.
=== END FILE ===

=== FILE: TASK-008/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-008

1. **Is R1 accepted as proof that the real module initializes cleanly?** It loaded, the probe wrote one key and the state became "Access", with the single caveat that `BindToClose` was not registered in Edit mode. Do you want a second R1-style check in a context where `BindToClose` works (a Play session or a published server) before any session test?
2. **The unguarded cached `require`.** Is this deviation acceptable as disclosed, or should the guard be hardened (for example by making the real module unreachable except through a function that also refuses cached returns, or by moving the real module out of `ServerStorage` until each approval)?
3. **Leaving the real module loaded.** It stays loaded in the open Studio session (empty autosave loop). Prefer restarting the SaveTest Studio window before R2?
4. **R2 scope.** Is "one fresh synthetic key, one start/save/end cycle in `TEST_LK_ProfileStore_v2`" the right next step, or do you want the legacy-record overwrite on a fixture key first, to see the real library behave as the mock did?
5. **Production API setting** remains owner-reported (off). Do you need an independent confirmation (for example a screenshot from the owner) before the next stage?
6. **Mock tests vs reality.** The cancellation behaviour (M3, M3b, M11, M11b) is established on fakes. Should those four be repeated on real DataStore keys in SaveTest before the adapter relies on them?

No other concern has been invented; items 2, 4 and 6 are the real forks.
=== END FILE ===

=== FILE: TASK-008/luau/R1_real_init.luau ===
-- TASK-008 R1: load the REAL pinned ProfileStore module ONCE through SaveTestGuard, SaveTest only.
-- Authorized write: the module's own Studio probe, store "____PS", key "____PS", in the SaveTest universe.
-- NOT called: ProfileStore.New, StartSessionAsync, Save, EndSession, RemoveAsync, MessageAsync, GetAsync, or anything else.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")

local T = game.ServerStorage.TestOnly
local sha = require(T.Sha256)
local Guard = require(T.SaveTestGuard)
local out = { startedAt = os.time() }

-- the module we are about to load must be the pinned one
out.sourceSha = sha(T.ProfileStore.Source)
assert(out.sourceSha == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash mismatch")
out.flagBefore = Guard.REAL_DATASTORE_APPROVED
assert(out.flagBefore == false, "ABORT flag was already true")

-- enable the flag ONLY for this one require, and ALWAYS put it back
Guard.REAL_DATASTORE_APPROVED = true
local ok, PS = pcall(function()
	return Guard.requireRealProfileStore(T.ProfileStore)
end)
Guard.REAL_DATASTORE_APPROVED = false
out.requireOk = ok
out.flagAfterRequire = Guard.REAL_DATASTORE_APPROVED
if not ok then
	out.requireError = tostring(PS)
	return game:GetService("HttpService"):JSONEncode(out)
end

-- wait (read-only) for the module's own probe to settle its state
local t0 = os.clock()
while PS.DataStoreState == "NotReady" and os.clock() - t0 < 20 do
	task.wait(0.1)
end
out.dataStoreState = PS.DataStoreState
out.isCriticalState = PS.IsCriticalState
out.isClosing = PS.IsClosing
out.secondsToSettle = os.clock() - t0
out.moduleType = typeof(PS)
return game:GetService("HttpService"):JSONEncode(out)
=== END FILE ===

=== FILE: TASK-008/luau/R1_followup_read.luau ===
-- TASK-008 R1 follow-up: READ-ONLY. Reads the probe key and confirms the guard flag is blocked again.
-- DISCLOSURE: this script called require(T.ProfileStore) DIRECTLY (not through SaveTestGuard) to read the module's
-- state. The module was already cached by the guarded require, so nothing re-initialized, but it was a deviation from
-- "every real-module access goes through the guard". Do not copy that line into future scripts.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local T = game.ServerStorage.TestOnly
local Guard = require(T.SaveTestGuard)
local out = { flagNow = Guard.REAL_DATASTORE_APPROVED }
local store = game:GetService("DataStoreService"):GetDataStore("____PS")
local ok, value, info = pcall(function() return store:GetAsync("____PS") end)
out.readOk = ok
if ok then
	out.valueType = typeof(value)
	out.value = value
	out.now = os.time()
	out.ageSeconds = type(value) == "number" and (os.time() - value) or nil
else
	out.readError = tostring(value)
end
-- no other ProfileStore functions are called here
local okPs, PS = pcall(require, T.ProfileStore)
out.requireCachedOk = okPs
if okPs then out.stateNow = PS.DataStoreState; out.critical = PS.IsCriticalState end
return game:GetService("HttpService"):JSONEncode(out)
=== END FILE ===

=== FILE: TASK-008/luau/MockTests.luau ===
-- ServerStorage.TestOnly.MockTests
-- SAVETEST ONLY. Runs the vendor ProfileStore SOURCE against in-memory fakes (MockBackend).
-- Never requires the real ProfileStore module, so it makes NO real DataStore call and NO real
-- MessagingService call. Run by hand from the command bar:
--   require(game.ServerStorage.TestOnly.MockTests).run(game.ServerStorage.TestOnly.ProfileStore.Source, "M1")
-- (pass nil as the second argument to run everything; each test is short, run a few per call)
--
-- Timings of the session-steal logic are SCALED DOWN with ProfileStore.SetConstant so the tests finish in
-- seconds. The real defaults (5 s / 10 s / 40 s) are NOT exercised here; real timing needs published servers.

local Guard = require(script.Parent.SaveTestGuard)
local MockBackend = require(script.Parent.MockBackend)

local STORE = Guard.TEST_STORE_NAME
local PLACE = Guard.SAVETEST_PLACE_ID

local TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}

local LEGACY_V1 = function(pearls)
	-- the exact v1 shape the game saves today (flat table, no Data/MetaData/GlobalUpdates)
	return {
		version = 1,
		pearls = pearls,
		owned = { DriftwoodHarpoon = true, StormHarpoon = true },
		counts = { FireShellCrate = 3 },
		equippedArmor = "OilskinCoat",
		equippedWeapon = "StormHarpoon",
		equippedBeam = "BeamAmber",
		stats = { runs = 4, victories = 1, bestNight = 9 },
	}
end

local function waitUntil(cond, timeout)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

local function fast(PS)
	PS.SetConstant("FIRST_LOAD_REPEAT", 0.2)
	PS.SetConstant("LOAD_REPEAT_PERIOD", 0.2)
	PS.SetConstant("SESSION_STEAL", 0.8)
	PS.SetConstant("START_SESSION_TIMEOUT", 8)
end

local function newServer(source, world, jobId)
	local h = MockBackend.loadVendor(source, world, { PlaceId = PLACE, JobId = jobId })
	assert(waitUntil(function()
		return h.PS.DataStoreState == "Access"
	end, 3), "mock DataStore state never became Access")
	fast(h.PS)
	h.store = h.PS.New(STORE, TEMPLATE)
	return h
end

local R = {} -- test functions, each returns (pass, detail)

R.M0 = function(source)
	-- the Studio probe and the experimental v2 option, against the FAKE services only
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local probeStore = world.stores["____PS"]
	local probeWrites = 0
	for _, w in ipairs(world.writes) do
		if w.store == "____PS" then
			probeWrites += 1
		end
	end
	local pass = probeStore ~= nil and probeWrites == 1 and h.identity.experimentalFeatures ~= nil
	local detail = {
		probeStoreCreatedOnFake = probeStore ~= nil,
		probeWritesOnFake = probeWrites,
		experimentalFeatures = h.identity.experimentalFeatures,
		dataStoreState = h.PS.DataStoreState,
		closeCallbacksRegistered = #h.identity.closeCallbacks,
	}
	h.destroy()
	return pass, detail
end

R.M1 = function(source)
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000001"
	local p = h.store:StartSessionAsync(key)
	if p == nil then
		return false, "StartSessionAsync returned nil"
	end
	local rec = MockBackend.record(world, STORE, key)
	local shape = type(rec) == "table" and type(rec.Data) == "table" and type(rec.MetaData) == "table" and type(rec.GlobalUpdates) == "table"
	local meta = rec and rec.MetaData or {}
	local active = meta.ActiveSession
	local okActive = type(active) == "table" and active[1] == PLACE and active[2] == "JOB_A" and type(active[3]) == "string"
	p.Data.pearls = 7
	p:EndSession()
	local released = waitUntil(function()
		local r = MockBackend.record(world, STORE, key)
		return r ~= nil and r.MetaData.ActiveSession == nil and r.Data.pearls == 7
	end, 3)
	local final = MockBackend.record(world, STORE, key)
	local detail = {
		topLevelKeys = (function()
			local ks = {}
			for k in pairs(rec) do
				table.insert(ks, k)
			end
			table.sort(ks)
			return ks
		end)(),
		sessionLoadCountAfterLoad = meta.SessionLoadCount,
		activeSessionOk = okActive,
		dataEqualsTemplatePearls = rec.Data.pearls == 0 and rec.Data.equippedBeam == "BeamAmber",
		releasedWithFinalData = released,
		finalPearls = final and final.Data.pearls,
		activeAfterEnd = final and final.MetaData.ActiveSession,
		isActiveAfterEnd = p:IsActive(),
	}
	h.destroy()
	return shape and okActive and meta.SessionLoadCount == 1 and released and not p:IsActive(), detail
end

R.M2 = function(source)
	-- legacy flat v1 record in the FAKE store: what does StartSessionAsync do to it?
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000002"
	MockBackend.seed(world, STORE, key, LEGACY_V1(500))
	local before = MockBackend.deepCopy(MockBackend.record(world, STORE, key))
	local overwrites = 0
	h.PS.OnOverwrite:Connect(function()
		overwrites += 1
	end)
	local p = h.store:StartSessionAsync(key)
	task.wait(0.1)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		seededPearls = before.pearls,
		seededHadWrapper = before.Data ~= nil or before.MetaData ~= nil or before.GlobalUpdates ~= nil,
		loadedProfileNotNil = p ~= nil,
		loadedPearls = p and p.Data.pearls,
		storedAfterHasWrapper = after.Data ~= nil and after.MetaData ~= nil,
		storedPearlsAfter = after.Data and after.Data.pearls,
		legacyFieldStillAtTopLevel = after.pearls ~= nil,
		onOverwriteFired = overwrites,
	}
	local destroyedLegacy = p ~= nil and p.Data.pearls == 0 and after.pearls == nil and overwrites >= 1
	h.destroy()
	-- "pass" = the documented destructive behaviour was reproduced (this is evidence, not a defect of the test)
	return destroyedLegacy, detail
end

R.M3 = function(source)
	-- legacy record + a Cancel that returns true at once: expected outcome = NO write at all (the load loop never starts)
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000003"
	MockBackend.seed(world, STORE, key, LEGACY_V1(321))
	local p = h.store:StartSessionAsync(key, {
		Cancel = function()
			return true
		end,
	})
	task.wait(0.1)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		returnedNil = p == nil,
		storedHasWrapperAfter = after.Data ~= nil and after.MetaData ~= nil,
		legacyPearlsStillThere = after.pearls == 321,
		storedActiveSession = after.MetaData and after.MetaData.ActiveSession,
	}
	h.destroy()
	return p == nil and after.pearls == 321 and after.Data == nil and after.MetaData == nil, detail
end

R.M4 = function(source)
	-- read-only GetAsync view of a legacy record
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000004"
	MockBackend.seed(world, STORE, key, LEGACY_V1(250))
	local writesBefore = #world.writes
	local view = h.store:GetAsync(key)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		viewNotNil = view ~= nil,
		viewPearls = view and view.Data.pearls,
		storedStillLegacy = after.pearls == 250 and after.Data == nil,
		writesDuringGet = #world.writes - writesBefore,
	}
	h.destroy()
	return view ~= nil and view.Data.pearls == 0 and detail.storedStillLegacy and detail.writesDuringGet == 0, detail
end

R.M5 = function(source)
	-- two logical servers, RESPONSIVE holder (messaging delivered)
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000005"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 11 -- unsaved change on the holder
	local ended = false
	pA.OnSessionEnd:Connect(function()
		ended = true
	end)
	local t0 = os.clock()
	local pB
	task.spawn(function()
		pB = B.store:StartSessionAsync(key)
	end)
	local got = waitUntil(function()
		return pB ~= nil
	end, 6)
	local elapsed = os.clock() - t0
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		bGotProfile = got,
		bSawHoldersUnsavedChange = pB and pB.Data.pearls,
		secondsToTakeover = elapsed,
		holderSessionEnded = ended,
		holderStillActive = pA:IsActive(),
		storedSessionLoadCount = rec.MetaData.SessionLoadCount,
		storedActiveJob = rec.MetaData.ActiveSession and rec.MetaData.ActiveSession[2],
		messagesPublished = #world.published,
	}
	local pass = got and pB.Data.pearls == 11 and ended and not pA:IsActive() and rec.MetaData.SessionLoadCount == 2 and detail.storedActiveJob == "JOB_B"
	A.destroy()
	B.destroy()
	return pass, detail
end

R.M6 = function(source)
	-- fencing: a stale holder cannot overwrite after takeover (responsive path)
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000006"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 3
	local pB
	task.spawn(function()
		pB = B.store:StartSessionAsync(key)
	end)
	waitUntil(function()
		return pB ~= nil
	end, 6)
	pB.Data.pearls = 50
	pB:Save()
	task.wait(0.3)
	pA.Data.pearls = 999
	pA:Save() -- inactive: warns and returns
	task.wait(0.3)
	local rec = MockBackend.record(world, STORE, key)
	local detail = { storedPearls = rec.Data.pearls, staleHolderActive = pA:IsActive() }
	A.destroy()
	B.destroy()
	return rec.Data.pearls == 50 and not pA:IsActive(), detail
end

R.M7 = function(source)
	-- UNRESPONSIVE holder: messaging dropped, scaled steal timing
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000007"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 4
	pA:Save()
	task.wait(0.2)
	world.dropMessages = true
	local t0 = os.clock()
	local pB
	task.spawn(function()
		pB = B.store:StartSessionAsync(key)
	end)
	local got = waitUntil(function()
		return pB ~= nil
	end, 8)
	local elapsed = os.clock() - t0
	-- the dead-or-slow holder now writes late
	pA.Data.pearls = 777
	pA:Save()
	task.wait(0.4)
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		bGotProfile = got,
		secondsToSteal_scaled = elapsed,
		scaledConstants = "FIRST_LOAD_REPEAT 0.2, LOAD_REPEAT_PERIOD 0.2, SESSION_STEAL 0.8",
		storedPearlsAfterLateHolderWrite = rec.Data.pearls,
		holderStillActiveAfterLateSave = pA:IsActive(),
		storedActiveJob = rec.MetaData.ActiveSession and rec.MetaData.ActiveSession[2],
	}
	A.destroy()
	B.destroy()
	return got and rec.Data.pearls ~= 777 and not pA:IsActive() and detail.storedActiveJob == "JOB_B", detail
end

R.M8 = function(source)
	-- dead lock: LastUpdate older than ASSUME_DEAD
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000008"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 2
	pA:Save()
	task.wait(0.2)
	local rec = MockBackend.record(world, STORE, key)
	rec.MetaData.LastUpdate = os.time() - 1000 -- older than ASSUME_DEAD (630 s)
	world.dropMessages = true
	local t0 = os.clock()
	local pB = B.store:StartSessionAsync(key)
	local elapsed = os.clock() - t0
	local detail = { tookOver = pB ~= nil, seconds = elapsed, pearls = pB and pB.Data.pearls }
	A.destroy()
	B.destroy()
	return pB ~= nil and elapsed < 1.5, detail
end

R.M9 = function(source)
	-- autosave/Save failure is not retried; the release save retries until it succeeds
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000009"
	local p = h.store:StartSessionAsync(key)
	task.wait(0.1)
	world.failures.UpdateAsync = 1
	p.Data.pearls = 5
	p:Save()
	task.wait(1.5)
	local afterFailedSave = MockBackend.record(world, STORE, key).Data.pearls
	local failuresLeft = world.failures.UpdateAsync
	p.Data.pearls = 6
	world.failures.UpdateAsync = 2
	local t0 = os.clock()
	p:EndSession()
	local ok = waitUntil(function()
		local r = MockBackend.record(world, STORE, key)
		return r.Data.pearls == 6 and r.MetaData.ActiveSession == nil
	end, 12)
	local detail = {
		storedAfterFailedSaveAndWait = afterFailedSave,
		failedSaveWasRetriedByItself = afterFailedSave == 5,
		injectedFailuresRemainingAfterFirstSave = failuresLeft,
		releaseSaveEventuallySucceeded = ok,
		secondsForReleaseWithTwoFailures = os.clock() - t0,
	}
	h.destroy()
	return afterFailedSave ~= 5 and ok, detail
end

R.M10 = function(source)
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000010"
	local p = h.store:StartSessionAsync(key)
	local okCall, err = pcall(function()
		return h.store:StartSessionAsync(key)
	end)
	local detail = { secondStartErrored = not okCall, message = tostring(err) }
	h.destroy()
	return p ~= nil and not okCall and string.find(tostring(err), "already loaded in this session", 1, true) ~= nil, detail
end

R.M11 = function(source)
	-- cancelled first load of a brand-new key
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000011"
	local p = h.store:StartSessionAsync(key, {
		Cancel = function()
			return true
		end,
	})
	task.wait(0.1)
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		returnedNil = p == nil,
		recordCreated = rec ~= nil,
		activeSession = rec and rec.MetaData and rec.MetaData.ActiveSession,
		dataIsTemplate = rec and rec.Data and rec.Data.pearls == 0,
	}
	h.destroy()
	return p == nil, detail
end

R.M3b = function(source)
	-- DELIBERATE destructive demonstration on SYNTHETIC data: Cancel is false on its first call (so the load starts)
	-- and true afterwards. Expected outcome = the legacy record IS overwritten.
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000103"
	MockBackend.seed(world, STORE, key, LEGACY_V1(321))
	local calls = 0
	local p = h.store:StartSessionAsync(key, {
		Cancel = function()
			calls += 1
			return calls >= 2
		end,
	})
	task.wait(0.1)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		cancelCalls = calls,
		returnedNil = p == nil,
		storedHasWrapper = after.Data ~= nil and after.MetaData ~= nil,
		legacyPearlsStillThere = after.pearls == 321,
		storedPearlsAfter = after.Data and after.Data.pearls,
	}
	h.destroy()
	return p == nil and after.Data ~= nil and after.pearls == nil, detail
end

R.M11b = function(source)
	-- side-effect demonstration on a synthetic NEW key: Cancel false on its first call, true afterwards.
	-- Expected outcome = an empty template record with no active session is created.
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000104"
	local calls = 0
	local p = h.store:StartSessionAsync(key, {
		Cancel = function()
			calls += 1
			return calls >= 2
		end,
	})
	task.wait(0.1)
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		cancelCalls = calls,
		returnedNil = p == nil,
		recordCreated = rec ~= nil,
		activeSession = rec and rec.MetaData and rec.MetaData.ActiveSession,
		dataIsTemplate = rec and rec.Data and rec.Data.pearls == 0,
	}
	h.destroy()
	return p == nil and rec ~= nil and rec.MetaData ~= nil and rec.MetaData.ActiveSession == nil, detail
end

R.M12 = function(source)
	-- shutdown: BindToClose releases all profiles in parallel
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local p1 = h.store:StartSessionAsync("player_900000012")
	local p2 = h.store:StartSessionAsync("player_900000013")
	p1.Data.pearls = 1
	p2.Data.pearls = 2
	world.latency = 0.4
	local t0 = os.clock()
	local callbacks = #h.identity.closeCallbacks
	assert(callbacks >= 1, "no BindToClose callback captured")
	for _, fn in ipairs(h.identity.closeCallbacks) do
		fn()
	end
	local elapsed = os.clock() - t0
	world.latency = 0
	local r1 = MockBackend.record(world, STORE, "player_900000012")
	local r2 = MockBackend.record(world, STORE, "player_900000013")
	local afterClose = h.store:StartSessionAsync("player_900000014")
	local detail = {
		closeCallbacks = callbacks,
		secondsWithTwoProfilesAt0_4sPerCall = elapsed,
		bothReleasedWithData = r1.MetaData.ActiveSession == nil and r2.MetaData.ActiveSession == nil and r1.Data.pearls == 1 and r2.Data.pearls == 2,
		isClosing = h.PS.IsClosing,
		startAfterCloseReturnsNil = afterClose == nil,
	}
	h.destroy()
	return detail.bothReleasedWithData and h.PS.IsClosing and afterClose == nil and elapsed < 0.4 * 2 + 0.5, detail
end

R.M13 = function(source)
	-- if two servers share the same JobId (for example both ""), the lock cannot tell them apart
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "")
	local B = newServer(source, world, "")
	local key = "player_900000015"
	local pA = A.store:StartSessionAsync(key)
	local pB = B.store:StartSessionAsync(key)
	local detail = {
		firstProfileActive = pA ~= nil and pA:IsActive(),
		secondProfileActive = pB ~= nil and pB:IsActive(),
		bothActiveAtOnce = pA ~= nil and pB ~= nil and pA:IsActive() and pB:IsActive(),
	}
	A.destroy()
	B.destroy()
	-- "pass" = the weakness is demonstrated (evidence for why real concurrency tests need distinct JobIds)
	return detail.bothActiveAtOnce, detail
end

R.M14 = function(source)
	local g = Guard
	local names = { g.TEST_STORE_NAME, g.TEST_V1_FIXTURE_STORE, g.CANARY_STORE_NAME }
	local detail = { lengths = {} }
	local ok = true
	for _, n in ipairs(names) do
		detail.lengths[n] = #n
		ok = ok and #n <= 50
		g.assertStoreName(n)
	end
	local forbiddenRejected = not pcall(g.assertStoreName, "LighthouseKeepers_PlayerData_v1")
	local noTestPrefixRejected = not pcall(g.assertStoreName, "SomethingElse")
	local requireBlocked = not pcall(g.requireRealProfileStore, script.Parent:FindFirstChild("ProfileStore") or Instance.new("ModuleScript"))
	detail.forbiddenRejected = forbiddenRejected
	detail.noTestPrefixRejected = noTestPrefixRejected
	detail.realRequireBlockedWhileUnapproved = requireBlocked
	detail.approvalFlag = g.REAL_DATASTORE_APPROVED
	return ok and forbiddenRejected and noTestPrefixRejected and requireBlocked and g.REAL_DATASTORE_APPROVED == false, detail
end

local ORDER = { "M0", "M1", "M2", "M3", "M3b", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M11b", "M12", "M13", "M14" }

-- Test kinds. Everything not listed is ordinary functionality. The *-demo kinds reproduce documented destructive or
-- weak behaviour of the vendor code against SYNTHETIC in-memory data; "pass" there means "the behaviour was observed".
local KIND = {
	M2 = "destructive-demo (synthetic data)",
	M3 = "cancellation regression (no write expected)",
	M3b = "destructive-demo (synthetic data)",
	M11 = "cancellation regression (no write expected)",
	M11b = "side-effect-demo (synthetic data)",
	M13 = "weakness-demo (synthetic data)",
}

local Tests = {}

function Tests.run(source, which)
	Guard.assertSaveTest()
	local results = {}
	for _, name in ipairs(ORDER) do
		if which == nil or which == name or (type(which) == "table" and table.find(which, name)) then
			local ok, pass, detail = pcall(R[name], source)
			if ok then
				table.insert(results, { test = name, kind = KIND[name] or "functional", pass = pass, detail = detail })
			else
				table.insert(results, { test = name, kind = KIND[name] or "functional", pass = false, error = tostring(pass) })
			end
		end
	end
	return results
end

return Tests
=== END FILE ===

