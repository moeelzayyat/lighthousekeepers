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
