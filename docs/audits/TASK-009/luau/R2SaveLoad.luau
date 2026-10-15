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
