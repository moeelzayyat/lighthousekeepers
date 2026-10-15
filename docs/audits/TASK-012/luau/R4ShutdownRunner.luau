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
