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
