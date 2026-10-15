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
