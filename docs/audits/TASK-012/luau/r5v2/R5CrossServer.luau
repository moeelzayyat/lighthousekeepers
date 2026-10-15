-- ServerStorage.TestOnly.R5CrossServer  (v2, TASK-012 auditor corrections)
-- SAVETEST ONLY. Two-server ownership test for PUBLISHED SaveTest servers. A ModuleScript: it never runs by itself.
-- In a live server it is started only by ServerScriptService.TestOnly_R5Bootstrap, which passes the real environment
-- to R5.serverMain(env) after its fail-closed gates. All decisions live here so they can be tested on fakes.
--
-- v2 corrections:
--  1. PLAYER-PRESENCE GATE. A makes no write until designated account 1 (by UserId) is in the server; B makes no
--     write until designated account 2 is in the reserved server that the run record names. No participant = zero
--     writes. ProfileStore is not even required before the gate passes.
--  2. ATOMIC RUN OWNERSHIP. One run = one RunId (set at arming). Role A must win an UpdateAsync claim on
--     TEST_LK_R5_Run/<RunId>; the transform is pure, so a re-invocation can never create a second owner, and a
--     re-invocation after our own commit is recognised by our nonce. B must prove it belongs to the same run: the
--     record names the reserved server A created for it (PrivateServerId from ReserveServer, written by A before the
--     teleport) and account 2; B then claims its slot with its own UpdateAsync.
--  3. DEADLINE DURING EXECUTION. Every step checks the run deadline (AuthNotAfter - 300 s). Past it, the role stops,
--     ends every session it holds, waits for the stored release, records partial results and marks the run record.
--
-- Stores and keys (Guard.OPERATIONS.R5_CROSS_SERVER):
--   TEST_LK_ProfileStore_v2/player_900000204, /player_900000205  (through ProfileStore only)
--   TEST_LK_R5_Run/<RunId>                                       (UpdateAsync, pure transforms below)
--   TEST_LK_R5_Results/<RunId>_A, /<RunId>_B                     (SetAsync, one per role)

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
R5.DEADLINE_MARGIN = 300 -- the run deadline is AuthNotAfter - 300 s, leaving time to release sessions
R5.TIMEOUTS = {
	presence = 600, -- how long a server waits for its designated account (capped by the deadline)
	bAssignment = 60, -- how long B waits for the run record to name it
	aWaitHandover = 240,
	aWaitSteal = 120,
	bWaitAReady = 60,
	bWaitAResults = 90,
	release = 30,
	save = 20,
}
R5.RUN_ID_PATTERN = "^R5RUN_%x+$"

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
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

----------------------------------------------------------------------------------------------------------------------
-- Run record protocol. Every transform is PURE: it only reads its argument and returns a new value or nil (nil =
-- cancel, nothing is written). It is safe to invoke any number of times, as Roblox may do.
----------------------------------------------------------------------------------------------------------------------
R5.claim = {}

local function withHistory(rec, state, at, by)
	rec.state = state
	rec.history = rec.history or {}
	table.insert(rec.history, { state = state, at = at, by = by })
	return rec
end

-- spec = { runId, jobId, nonce, account1, account2, now, deadline }
function R5.claim.claimA(spec)
	return function(current)
		if current == nil then
			return withHistory({
				runId = spec.runId,
				aJobId = spec.jobId,
				aNonce = spec.nonce,
				account1 = spec.account1,
				account2 = spec.account2,
				claimedAt = spec.now,
				deadline = spec.deadline,
			}, "A_CLAIMED", spec.now, "A")
		end
		if type(current) == "table" and current.runId == spec.runId and current.aNonce == spec.nonce then
			return nil -- our own claim is already committed (re-invoked or retried call): nothing to write
		end
		return nil -- the run belongs to someone else: cancel, no write
	end
end

function R5.claim.isOwnerA(rec, spec)
	return type(rec) == "table" and rec.runId == spec.runId and rec.aNonce == spec.nonce and rec.aJobId == spec.jobId
end

-- A records the reserved server it created for B, before teleporting account 2 there.
function R5.claim.assignB(spec, bPrivateServerId, now)
	return function(current)
		if not R5.claim.isOwnerA(current, spec) then
			return nil
		end
		if current.state == "B_ASSIGNED" and current.bPrivateServerId == bPrivateServerId then
			return nil -- already recorded: nothing to write
		end
		if current.state ~= "A_CLAIMED" then
			return nil
		end
		current.bPrivateServerId = bPrivateServerId
		return withHistory(current, "B_ASSIGNED", now, "A")
	end
end

-- bSpec = { runId, jobId, nonce, privateServerId, account2, now }
function R5.claim.startB(bSpec)
	return function(current)
		if type(current) ~= "table" or current.runId ~= bSpec.runId then
			return nil
		end
		if current.bNonce ~= nil then
			if current.bNonce == bSpec.nonce then
				return nil -- our own start is already committed: nothing to write
			end
			return nil -- another B already started: cancel
		end
		if current.state ~= "B_ASSIGNED" or current.bPrivateServerId ~= bSpec.privateServerId
			or current.account2 ~= bSpec.account2 then
			return nil
		end
		current.bJobId = bSpec.jobId
		current.bNonce = bSpec.nonce
		return withHistory(current, "B_STARTED", bSpec.now, "B")
	end
end

function R5.claim.isOwnerB(rec, bSpec)
	return type(rec) == "table" and rec.runId == bSpec.runId and rec.bNonce == bSpec.nonce
		and rec.bPrivateServerId == bSpec.privateServerId
end

-- role = "A" | "B"; outcome = short string
function R5.claim.finish(spec, role, outcome, now)
	return function(current)
		if type(current) ~= "table" or current.runId ~= spec.runId then
			return nil
		end
		local nonceField = role == "A" and "aNonce" or "bNonce"
		if current[nonceField] ~= spec.nonce then
			return nil
		end
		local field = role == "A" and "aFinished" or "bFinished"
		if current[field] ~= nil then
			return nil -- already recorded: nothing to write
		end
		current[field] = outcome
		return withHistory(current, role .. "_FINISHED", now, role)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Waiting helpers that respect the run deadline
----------------------------------------------------------------------------------------------------------------------
local function makeClock(env, deadline)
	local clock = {}
	function clock.expired()
		return env.now() >= deadline
	end
	function clock.check(step)
		if clock.expired() then
			error("R5 DEADLINE reached before step " .. step, 0)
		end
	end
	-- waits until cond() is true, the timeout passes, or the deadline passes
	function clock.waitUntil(cond, timeout, interval)
		local t0 = os.clock()
		while true do
			local okC, res = pcall(cond)
			if okC and res then
				return true, os.clock() - t0
			end
			if os.clock() - t0 > timeout or clock.expired() then
				return false, os.clock() - t0
			end
			task.wait(interval or 0.25)
		end
	end
	return clock
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

----------------------------------------------------------------------------------------------------------------------
-- Roles (unchanged sequence from v1; every step now checks the deadline)
----------------------------------------------------------------------------------------------------------------------
local function endAndWaitRelease(profiles, readKey, clockW)
	for _, p in ipairs(profiles) do
		if p ~= nil and p:IsActive() then
			p:EndSession()
		end
	end
	-- release is confirmed from the store; this wait is NOT capped by the deadline (cleanup must finish)
	local t0 = os.clock()
	while os.clock() - t0 < R5.TIMEOUTS.release do
		local allReleased = true
		for _, p in ipairs(profiles) do
			if p ~= nil then
				local okR, r = pcall(readKey, p.Key)
				local s = okR and summarize(r) or nil
				if s == nil or (s.active and s.activeJobId == clockW.jobId) then
					allReleased = false
				end
			end
		end
		if allReleased then
			return true
		end
		task.wait(1)
	end
	return false
end

local function roleA(deps, op, res)
	local clock = deps.clock
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
		note("A1_identity", deepCopy(deps.identity))
		clock.check("A2_precheck")
		assert(raw(op.keyHandover) == nil and raw(op.keyStolen) == nil, "R5 ABORT: test keys already exist")
		note("A2_precheck", { keysAbsent = true })

		clock.check("A3_start_handover_key")
		p1 = store:StartSessionAsync(op.keyHandover)
		assert(p1 ~= nil and p1:IsActive(), "A: handover key session failed")
		p1.Data.pearls = R5.A_SAVED
		p1:Save()
		assert(clock.waitUntil(function()
			return p1.LastSavedData ~= nil and p1.LastSavedData.pearls == R5.A_SAVED
		end, R5.TIMEOUTS.save), "A: save 50 not confirmed")
		p1.Data.pearls = R5.A_UNSAVED -- in memory only; must reach the store through the handover release
		note("A3_handover_key_held", { stored = summarize(raw(op.keyHandover)), memoryPearls = p1.Data.pearls })

		clock.check("A4_start_stolen_key")
		p2 = store:StartSessionAsync(op.keyStolen)
		assert(p2 ~= nil and p2:IsActive(), "A: stolen key session failed")
		p2.Data.pearls = R5.A_STOLEN_SAVED
		p2:Save()
		assert(clock.waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.A_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "A: save 70 not confirmed")
		note("A4_stolen_key_held", { stored = summarize(raw(op.keyStolen)) })

		res.readyAt = os.clock() - t0
		if deps.onReady then
			task.spawn(deps.onReady)
		end

		local handedOver, hSecs = clock.waitUntil(function()
			return not p1:IsActive()
		end, R5.TIMEOUTS.aWaitHandover, 0.25)
		local afterHandover = summarize(raw(op.keyHandover))
		note("A5_handover", { endedByLibrary = handedOver, secondsWaited = hSecs, stored = afterHandover })
		res.handover = { endedByLibrary = handedOver, storedAfter = afterHandover }
		clock.check("A5_handover")
		assert(handedOver, "A: handover never happened")

		local stolen, sSecs = clock.waitUntil(function()
			local s = summarize(raw(op.keyStolen))
			return s.active and s.activeJobId ~= myJob
		end, R5.TIMEOUTS.aWaitSteal, 1)
		local beforeAttempt = summarize(raw(op.keyStolen))
		note("A6_steal_observed", { stolen = stolen, secondsWaited = sSecs, stored = beforeAttempt, localStillActive = p2:IsActive() })
		clock.check("A6_steal")
		assert(stolen, "A: steal never observed")

		local activeBefore = p2:IsActive()
		p2.Data.pearls = R5.A_STALE_ATTEMPT
		p2:Save()
		local endedAfter, eSecs = clock.waitUntil(function()
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
	res.abortedByDeadline = clock.expired()
	res.cleanupReleased = endAndWaitRelease({ p1, p2 }, raw, { jobId = myJob })
	if not ok then
		note("A_cleanup", { because = tostring(err), released = res.cleanupReleased })
	end
	res.completedWithoutError = ok
	res.error = (not ok) and tostring(err) or nil
	return ok
end

local function roleB(deps, op, res)
	local clock = deps.clock
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
		note("B1_identity", deepCopy(deps.identity))
		local aReady = clock.waitUntil(function()
			local h, s = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
			return h.active and h.activeJobId ~= myJob and h.pearls == R5.A_SAVED
				and s.active and s.activeJobId ~= myJob and s.pearls == R5.A_STOLEN_SAVED
		end, R5.TIMEOUTS.bWaitAReady, 1)
		note("B2_a_ready_seen", { aReady = aReady })
		clock.check("B3_handover")
		assert(aReady, "B: server A is not holding both keys")

		local tReq = os.clock()
		p1 = store:StartSessionAsync(op.keyHandover)
		local takeoverSecs = os.clock() - tReq
		assert(p1 ~= nil and p1:IsActive(), "B: handover session failed")
		local h = summarize(raw(op.keyHandover))
		note("B3_handover_acquired", { takeoverSeconds = takeoverSecs, loadedPearls = p1.Data.pearls, sessionLoadCount = p1.SessionLoadCount, stored = h })
		res.handover = {
			takeoverSeconds = takeoverSecs,
			loadedLatestCommitted = p1.Data.pearls == R5.A_UNSAVED,
			loadedPearls = p1.Data.pearls,
			sessionLoadCount = p1.SessionLoadCount,
			storedOwnerIsB = h.active and h.activeJobId == myJob,
			resolvedBy = takeoverSecs < 30 and "messaging (A released)" or "steal after timeout",
		}

		clock.check("B4_steal")
		local tSteal = os.clock()
		p2 = store:StartSessionAsync(op.keyStolen, { Steal = true })
		assert(p2 ~= nil and p2:IsActive(), "B: steal failed")
		local loadedStolen = p2.Data.pearls
		p2.Data.pearls = R5.B_STOLEN_SAVED
		p2:Save()
		assert(clock.waitUntil(function()
			return p2.LastSavedData ~= nil and p2.LastSavedData.pearls == R5.B_STOLEN_SAVED
		end, R5.TIMEOUTS.save), "B: save 80 not confirmed")
		note("B4_stolen_and_saved", { stealSeconds = os.clock() - tSteal, loadedPearls = loadedStolen, stored = summarize(raw(op.keyStolen)) })

		local aDone = clock.waitUntil(function()
			return deps.readResult("A") ~= nil
		end, R5.TIMEOUTS.bWaitAResults, 1)
		clock.check("B5_resave")
		p2:Save()
		assert(clock.waitUntil(function()
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

		clock.check("B6_final_save")
		p1.Data.pearls = R5.B_HANDOVER_FINAL
		p1:Save()
		assert(clock.waitUntil(function()
			return p1.LastSavedData ~= nil and p1.LastSavedData.pearls == R5.B_HANDOVER_FINAL
		end, R5.TIMEOUTS.save), "B: save 60 not confirmed")
	end)
	res.abortedByDeadline = clock.expired()
	local released = endAndWaitRelease({ p1, p2 }, raw, { jobId = myJob })
	local fh, fs = summarize(raw(op.keyHandover)), summarize(raw(op.keyStolen))
	note("B6_released", { bothReleased = released, handover = fh, stolen = fs })
	res.final = { bothReleased = released and not fh.active and not fs.active, handover = fh, stolen = fs }
	res.cleanupReleased = released
	res.completedWithoutError = ok and released
	res.error = (not ok) and tostring(err) or nil
	return res.completedWithoutError
end

----------------------------------------------------------------------------------------------------------------------
-- Server entry: gates, presence, claim, role. env (all injected; real values come from the bootstrap):
--   identity = { placeId, gameId, jobId, privateServerId, privateServerOwnerId, isStudio }
--   attrs    = { AuthTest, AuthRunId, AuthNotBefore, AuthNotAfter, Account1UserId, Account2UserId }
--   now()                       -- os.time()
--   isPresent(userId) -> bool   -- designated account is in THIS server (Players, by UserId)
--   store.get(name, key)        -- uncached GetAsync
--   store.update(name, key, fn) -- UpdateAsync (fn may be invoked several times)
--   store.set(name, key, value) -- SetAsync
--   loadProfileStore() -> PS    -- require of the pinned module, called only after the gates
--   reserve() -> accessCode, privateServerId
--   teleport(userId, accessCode) -> ok, err
--   nonce                        -- unique per server
--   setApproved(bool)            -- flips Guard.APPROVED[R5_CROSS_SERVER] in this server
-- Returns a summary; never throws.
----------------------------------------------------------------------------------------------------------------------
function R5.serverMain(env)
	local summary = { phase = "gates" }
	local op = Guard.OPERATIONS[R5.OPERATION]
	local ok, err = pcall(function()
		Guard.assertSaveTest()
		assert(op ~= nil, "guard has no R5 operation")
		local id, a = env.identity, env.attrs
		assert(id.placeId == Guard.SAVETEST_PLACE_ID and id.gameId == Guard.SAVETEST_GAME_ID, "not SaveTest")
		assert(id.isStudio ~= true, "Studio")
		assert(type(id.jobId) == "string" and id.jobId ~= "", "empty JobId")
		assert(a.AuthTest == R5.OPERATION, "no authorization")
		assert(type(a.AuthRunId) == "string" and string.match(a.AuthRunId, R5.RUN_ID_PATTERN) ~= nil, "bad RunId")
		assert(type(a.AuthNotBefore) == "number" and type(a.AuthNotAfter) == "number", "bad window")
		assert(a.AuthNotAfter > a.AuthNotBefore and a.AuthNotAfter - a.AuthNotBefore <= 3 * 3600, "bad window")
		assert(type(a.Account1UserId) == "number" and type(a.Account2UserId) == "number"
			and a.Account1UserId ~= a.Account2UserId, "bad accounts")
		local deadline = a.AuthNotAfter - R5.DEADLINE_MARGIN
		assert(env.now() >= a.AuthNotBefore and env.now() < deadline, "outside authorization window")
		local clock = makeClock(env, deadline)

		local isPublic = id.privateServerId == ""
		local isReserved = id.privateServerId ~= "" and id.privateServerOwnerId == 0
		local role = isPublic and "A" or (isReserved and "B" or nil)
		assert(role ~= nil, "server type is neither public nor reserved")
		summary.role = role
		local runId = a.AuthRunId
		local resultsKey = runId .. "_" .. role

		-- store access is limited to the operation's stores and THIS run's keys
		local function checkRaw(name, key)
			if name == op.store then
				assert(key == op.keyHandover or key == op.keyStolen, "R5 ABORT: key not allowed: " .. key)
			elseif name == op.runStore then
				assert(key == runId, "R5 ABORT: run key not allowed: " .. key)
			elseif name == op.resultsStore then
				assert(key == runId .. "_A" or key == runId .. "_B", "R5 ABORT: results key not allowed: " .. key)
			else
				error("R5 ABORT: store not allowed: " .. tostring(name))
			end
			Guard.assertStoreName(name)
		end
		local function get(name, key)
			checkRaw(name, key)
			return env.store.get(name, key)
		end
		local function update(name, key, fn)
			checkRaw(name, key)
			assert(name == op.runStore, "R5 ABORT: UpdateAsync only on the run record")
			-- a call may fail after committing; retrying is safe because every transform is idempotent
			local lastErr
			for _ = 1, 3 do
				local okU, e = pcall(env.store.update, name, key, fn)
				if okU then
					return true
				end
				lastErr = e
				task.wait(1)
			end
			error("R5 run-record update failed: " .. tostring(lastErr))
		end

		-- 1. PRESENCE GATE (no write of any kind before it)
		summary.phase = "presence"
		local designated = role == "A" and a.Account1UserId or a.Account2UserId
		local present = clock.waitUntil(function()
			return env.isPresent(designated)
		end, R5.TIMEOUTS.presence, 1)
		summary.designatedPresent = present
		assert(present, "designated account " .. role .. " never joined this server")

		-- 2. RUN OWNERSHIP
		summary.phase = "claim"
		local spec = {
			runId = runId,
			jobId = id.jobId,
			nonce = env.nonce,
			account1 = a.Account1UserId,
			account2 = a.Account2UserId,
			now = env.now(),
			deadline = deadline,
			privateServerId = id.privateServerId,
		}
		if role == "A" then
			assert(get(op.runStore, runId) == nil, "run already claimed (read check)")
			update(op.runStore, runId, R5.claim.claimA(spec))
			local rec = get(op.runStore, runId)
			assert(R5.claim.isOwnerA(rec, spec), "lost the run claim to another server")
		else
			local assigned = clock.waitUntil(function()
				local rec = get(op.runStore, runId)
				return type(rec) == "table" and rec.state == "B_ASSIGNED" and rec.bPrivateServerId == id.privateServerId
					and rec.account2 == a.Account2UserId
			end, R5.TIMEOUTS.bAssignment, 1)
			assert(assigned, "this reserved server is not the one the run record names")
			update(op.runStore, runId, R5.claim.startB(spec))
			local rec = get(op.runStore, runId)
			assert(R5.claim.isOwnerB(rec, spec), "could not start B for this run")
		end
		summary.claimed = true

		-- 3. ROLE (ProfileStore is loaded only now)
		summary.phase = "role"
		local PS = env.loadProfileStore()
		clock.check("role start")
		local deps = {
			PS = R5.restrict(PS, op, role),
			readRaw = get,
			readResult = function(r)
				return get(op.resultsStore, runId .. "_" .. r)
			end,
			identity = {
				role = role,
				runId = runId,
				placeId = id.placeId,
				gameId = id.gameId,
				jobId = id.jobId,
				privateServerId = id.privateServerId,
				privateServerOwnerId = id.privateServerOwnerId,
				mock = id.mock,
			},
			clock = clock,
		}
		if role == "A" then
			deps.onReady = function()
				local okT, errT = pcall(function()
					local seen = clock.waitUntil(function()
						return env.isPresent(a.Account2UserId)
					end, R5.TIMEOUTS.aWaitHandover, 1)
					assert(seen, "account 2 never joined server A")
					clock.check("reserve")
					local code, psid = env.reserve()
					assert(type(code) == "string" and type(psid) == "string" and psid ~= "", "ReserveServer gave no PrivateServerId")
					update(op.runStore, runId, R5.claim.assignB(spec, psid, env.now()))
					local rec = get(op.runStore, runId)
					assert(type(rec) == "table" and rec.bPrivateServerId == psid, "B assignment not recorded")
					local okTp, errTp = env.teleport(a.Account2UserId, code)
					assert(okTp, "teleport failed: " .. tostring(errTp))
				end)
				summary.teleport = { ok = okT, error = (not okT) and tostring(errT) or nil }
			end
		end
		env.setApproved(true)
		local res = { role = role, runId = runId, log = {}, identity = deps.identity, startedAt = env.now() }
		local okRole, errRole = pcall(function()
			Guard.assertOperationApproved(R5.OPERATION)
			if role == "A" then
				roleA(deps, op, res)
			else
				roleB(deps, op, res)
			end
		end)
		env.setApproved(false)
		if not okRole then
			res.completedWithoutError = false
			res.error = "crashed: " .. tostring(errRole)
		end
		res.teleport = summary.teleport
		res.finishedAt = env.now()
		-- partial or complete, the results record is always written once the role has started
		local okW, errW = pcall(function()
			checkRaw(op.resultsStore, resultsKey)
			env.store.set(op.resultsStore, resultsKey, res)
		end)
		summary.resultWritten = okW
		summary.resultWriteError = (not okW) and tostring(errW) or nil
		local outcome = res.completedWithoutError and "completed"
			or (res.abortedByDeadline and "aborted: deadline" or "failed: " .. tostring(res.error))
		pcall(update, op.runStore, runId, R5.claim.finish(spec, role, string.sub(outcome, 1, 200), env.now()))
		summary.result = res
	end)
	env.setApproved(false)
	summary.ok = ok
	summary.error = (not ok) and tostring(err) or nil
	return summary
end

----------------------------------------------------------------------------------------------------------------------
-- The R5 verdict, computed only from the two results records and the run record.
----------------------------------------------------------------------------------------------------------------------
function R5.evaluate(A, B, run)
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
		sameRun = get(A, "runId") ~= nil and get(A, "runId") == get(B, "runId") and get(run, "runId") == get(A, "runId"),
		runRecordConsistent = get(run, "aJobId") == jobA and get(run, "bJobId") == jobB
			and get(run, "aFinished") == "completed" and get(run, "bFinished") == "completed",
		distinctNonEmptyJobIds = type(jobA) == "string" and type(jobB) == "string" and jobA ~= "" and jobB ~= "" and jobA ~= jobB,
		serverTypes = get(A, "identity", "privateServerId") == ""
			and (get(B, "identity", "privateServerId") or "") ~= ""
			and get(B, "identity", "privateServerId") == get(run, "bPrivateServerId"),
		handoverEndedOnA = get(A, "handover", "endedByLibrary") == true,
		handoverViaMessaging = get(B, "handover", "resolvedBy") == "messaging (A released)",
		handoverLoadedLatestCommitted = get(B, "handover", "loadedLatestCommitted") == true,
		singleOwnerAfterHandover = get(B, "handover", "storedOwnerIsB") == true,
		staleOverwriteBlocked = get(A, "staleAttempt", "overwriteBlocked") == true
			and get(A, "staleAttempt", "storedPearlsAfter") == R5.B_STOLEN_SAVED
			and get(B, "stolen", "storedPearlsAfterAAttempt") == R5.B_STOLEN_SAVED,
		staleHolderSessionEnded = get(A, "staleAttempt", "sessionEndedAfterAttempt") == true,
		newOwnerUnaffected = get(B, "stolen", "stillOwnerAfterAAttempt") == true,
		allSessionsReleased = get(B, "final", "bothReleased") == true and get(A, "cleanupReleased") == true,
		finalValues = get(B, "final", "handover", "pearls") == R5.B_HANDOVER_FINAL
			and get(B, "final", "stolen", "pearls") == R5.B_STOLEN_SAVED,
		noDeadlineAbort = get(A, "abortedByDeadline") == false and get(B, "abortedByDeadline") == false,
		takeoverSeconds = get(B, "handover", "takeoverSeconds"),
		mock = mock,
	}
end

----------------------------------------------------------------------------------------------------------------------
-- Edit-mode tests on fakes. No real DataStore, MessagingService, teleport or Players call.
-- The fake raw store re-invokes a transform when another writer committed in between (optimistic concurrency, as
-- UpdateAsync does) and can drop the response of a committed call once, so the caller retries.
----------------------------------------------------------------------------------------------------------------------
local function newRaceStore()
	local st = { data = {}, ver = {}, writes = {}, invocations = 0, reinvocations = 0, cancels = 0, loseResponseOnce = {} }
	local s = { stats = st }
	function s.get(name, key)
		return deepCopy(st.data[name .. "/" .. key])
	end
	function s.update(name, key, fn)
		local k = name .. "/" .. key
		while true do
			local snapVer = st.ver[k] or 0
			local snap = deepCopy(st.data[k])
			task.wait(math.random() * 0.05) -- latency: concurrent callers interleave here
			st.invocations += 1
			local new = fn(snap)
			if (st.ver[k] or 0) ~= snapVer then
				st.reinvocations += 1 -- someone committed meanwhile: invoke again with the latest value
			else
				if new == nil then
					st.cancels += 1
					return nil
				end
				st.data[k] = deepCopy(new)
				st.ver[k] = snapVer + 1
				table.insert(st.writes, "UpdateAsync " .. k)
				if st.loseResponseOnce[k] then
					st.loseResponseOnce[k] = nil
					error("MOCK: response lost after commit")
				end
				return deepCopy(new)
			end
		end
	end
	function s.set(name, key, value)
		st.data[name .. "/" .. key] = deepCopy(value)
		table.insert(st.writes, "SetAsync " .. name .. "/" .. key)
	end
	return s
end

-- Builds one fake server env sharing `world` (ProfileStore fakes) and `raw` (run/results fakes).
local function fakeServer(ctx, opts)
	local MockBackend = require(script.Parent.MockBackend)
	local present = opts.present or {}
	local env = {
		identity = {
			placeId = Guard.SAVETEST_PLACE_ID,
			gameId = Guard.SAVETEST_GAME_ID,
			jobId = opts.jobId,
			privateServerId = opts.privateServerId or "",
			privateServerOwnerId = 0,
			isStudio = false,
			mock = true,
		},
		attrs = ctx.attrs,
		now = os.time,
		nonce = opts.jobId .. "-nonce",
		isPresent = function(userId)
			return present[userId] == true
		end,
		present = present,
		setApproved = function(v)
			Guard.APPROVED[R5.OPERATION] = v -- fakes share one Studio flag; each runRole asserts it at start only
		end,
	}
	-- profile keys go to the MockBackend world (ProfileStore), run/results keys to the race store
	env.store = {
		get = function(name, key)
			if name == ctx.op.store then
				return MockBackend.record(ctx.world, name, key)
			end
			return ctx.raw.get(name, key)
		end,
		update = ctx.raw.update,
		set = ctx.raw.set,
	}
	env.loadProfileStore = function()
		local h = MockBackend.loadVendor(ctx.vendorSource, ctx.world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = opts.jobId })
		local t0 = os.clock()
		while h.PS.DataStoreState ~= "Access" and os.clock() - t0 < 3 do
			task.wait()
		end
		table.insert(ctx.handles, h)
		ctx.psLoads += 1
		return h.PS
	end
	env.reserve = function()
		ctx.reserved += 1
		return "code-" .. ctx.reserved, "PSID-" .. ctx.reserved
	end
	env.teleport = function(userId, code)
		local psid = "PSID-" .. string.sub(code, 6)
		-- the teleported account appears in a NEW reserved server running the same code
		task.spawn(function()
			ctx.summaries["B:" .. psid] = R5.serverMain(fakeServer(ctx, {
				jobId = "JOB_B_" .. psid,
				privateServerId = psid,
				present = { [userId] = true },
			}))
		end)
		return true
	end
	return env
end

local function newCtx(vendorSource, attrsOverride)
	local MockBackend = require(script.Parent.MockBackend)
	local now = os.time()
	local attrs = {
		AuthTest = R5.OPERATION,
		AuthRunId = "R5RUN_" .. string.lower(string.gsub(game:GetService("HttpService"):GenerateGUID(false), "-", "")),
		AuthNotBefore = now - 10,
		AuthNotAfter = now + 7200,
		Account1UserId = 1001,
		Account2UserId = 2002,
	}
	for k, v in pairs(attrsOverride or {}) do
		attrs[k] = v
	end
	return {
		attrs = attrs,
		op = Guard.OPERATIONS[R5.OPERATION],
		world = MockBackend.newWorld(),
		raw = newRaceStore(),
		vendorSource = vendorSource,
		handles = {},
		summaries = {},
		reserved = 0,
		psLoads = 0,
	}
end

local function writesOf(ctx)
	local w = {}
	for _, x in ipairs(ctx.world.writes) do
		table.insert(w, x.op .. " " .. x.store .. "/" .. x.key)
	end
	for _, x in ipairs(ctx.raw.stats.writes) do
		table.insert(w, x)
	end
	return w
end

local function recordOf(ctx, key)
	return require(script.Parent.MockBackend).record(ctx.world, ctx.op.store, key)
end

local function waitFor(cond, timeout)
	local t0 = os.clock()
	while not cond() and os.clock() - t0 < timeout do
		task.wait(0.25)
	end
	return cond()
end

-- scenario: "full" | "noParticipant" | "raceA" | "wrongB" | "deadline"
function R5.runMockScenario(vendorSource, scenario)
	Guard.assertSaveTest()
	local savedTimeouts = deepCopy(R5.TIMEOUTS)
	local out = { scenario = scenario }
	local ok, err = pcall(function()
		if scenario == "full" then
			local ctx = newCtx(vendorSource)
			local envA = fakeServer(ctx, { jobId = "JOB_A", present = { [1001] = true } })
			task.spawn(function()
				ctx.summaries.A = R5.serverMain(envA)
			end)
			task.wait(2)
			envA.present[2002] = true -- account 2 joins server A; A moves it to a reserved server
			waitFor(function()
				local nB = 0
				for k in pairs(ctx.summaries) do
					if string.sub(k, 1, 2) == "B:" then
						nB += 1
					end
				end
				return ctx.summaries.A ~= nil and nB == 1
			end, 120)
			local run = ctx.raw.get(ctx.op.runStore, ctx.attrs.AuthRunId)
			local A = ctx.raw.get(ctx.op.resultsStore, ctx.attrs.AuthRunId .. "_A")
			local B = ctx.raw.get(ctx.op.resultsStore, ctx.attrs.AuthRunId .. "_B")
			out.checks = R5.evaluate(A, B, run)
			out.runHistory = run and run.history
			out.writes = writesOf(ctx)
			out.messagesPublished = #ctx.world.published
		elseif scenario == "noParticipant" then
			R5.TIMEOUTS.presence = 5
			local ctx = newCtx(vendorSource)
			-- a public server and a reserved server start with nobody designated present (account 2 in A's place)
			local sA = R5.serverMain(fakeServer(ctx, { jobId = "JOB_X", present = { [2002] = true } }))
			local sB = R5.serverMain(fakeServer(ctx, { jobId = "JOB_Y", privateServerId = "PSID-9", present = {} }))
			out.publicServer = { ok = sA.ok, phase = sA.phase, error = sA.error }
			out.reservedServer = { ok = sB.ok, phase = sB.phase, error = sB.error }
			out.writes = writesOf(ctx)
			out.profileStoreLoaded = ctx.psLoads
			out.zeroWrites = #out.writes == 0 and ctx.psLoads == 0
		elseif scenario == "raceA" then
			local ctx = newCtx(vendorSource)
			-- two public servers pass the gates at the same moment; the first claim's response is lost once
			ctx.raw.stats.loseResponseOnce[ctx.op.runStore .. "/" .. ctx.attrs.AuthRunId] = true
			local done = 0
			for _, j in ipairs({ "JOB_A1", "JOB_A2", "JOB_A3" }) do
				task.spawn(function()
					-- stop each winner before ProfileStore: this scenario only measures the claim
					local env = fakeServer(ctx, { jobId = j, present = { [1001] = true } })
					env.loadProfileStore = function()
						error("STOP_AFTER_CLAIM")
					end
					ctx.summaries[j] = R5.serverMain(env)
					done += 1
				end)
			end
			waitFor(function()
				return done == 3
			end, 30)
			local winners, losers = {}, {}
			for j, s in pairs(ctx.summaries) do
				if s.claimed then
					table.insert(winners, j)
				else
					table.insert(losers, j .. ": " .. tostring(s.error))
				end
			end
			local run = ctx.raw.get(ctx.op.runStore, ctx.attrs.AuthRunId)
			out.winners = winners
			out.losers = losers
			out.runOwner = run and run.aJobId
			out.invocations = ctx.raw.stats.invocations
			out.reinvocations = ctx.raw.stats.reinvocations
			out.cancels = ctx.raw.stats.cancels
			out.writes = writesOf(ctx)
			out.exactlyOneOwner = #winners == 1 and run ~= nil and run.aJobId == winners[1]
		elseif scenario == "wrongB" then
			R5.TIMEOUTS.bAssignment = 4
			local ctx = newCtx(vendorSource)
			-- the run is claimed and assigned to PSID-1; account 2 shows up in a different reserved server
			local spec = { runId = ctx.attrs.AuthRunId, jobId = "JOB_A", nonce = "JOB_A-nonce", account1 = 1001, account2 = 2002, now = os.time(), deadline = os.time() + 3600 }
			ctx.raw.update(ctx.op.runStore, spec.runId, R5.claim.claimA(spec))
			ctx.raw.update(ctx.op.runStore, spec.runId, R5.claim.assignB(spec, "PSID-1", os.time()))
			local before = #ctx.raw.stats.writes
			local function bServer(jobId, psid)
				local env = fakeServer(ctx, { jobId = jobId, privateServerId = psid, present = { [2002] = true } })
				env.loadProfileStore = function()
					error("STOP_AFTER_CLAIM") -- this scenario only measures B's association and claim
				end
				return env
			end
			local s = R5.serverMain(bServer("JOB_BAD", "PSID-7"))
			out.wrongServer = { ok = s.ok, phase = s.phase, error = s.error, claimed = s.claimed == true }
			-- a second B in the RIGHT server after a first B already started
			local s1 = R5.serverMain(bServer("JOB_B1", "PSID-1"))
			local s2 = R5.serverMain(bServer("JOB_B2", "PSID-1"))
			out.firstB = { claimed = s1.claimed == true, phase = s1.phase, error = s1.error }
			out.secondB = { claimed = s2.claimed == true, phase = s2.phase, error = s2.error }
			out.writesAfterSetup = {}
			for i = before + 1, #ctx.raw.stats.writes do
				table.insert(out.writesAfterSetup, ctx.raw.stats.writes[i])
			end
		elseif scenario == "deadline" then
			-- account 2 never comes; the deadline passes while A holds both keys
			local now = os.time()
			local ctx = newCtx(vendorSource, { AuthNotBefore = now - 10, AuthNotAfter = now + R5.DEADLINE_MARGIN + 12 })
			local s = R5.serverMain(fakeServer(ctx, { jobId = "JOB_A", present = { [1001] = true } }))
			local A = ctx.raw.get(ctx.op.resultsStore, ctx.attrs.AuthRunId .. "_A")
			local run = ctx.raw.get(ctx.op.runStore, ctx.attrs.AuthRunId)
			out.summary = { ok = s.ok, phase = s.phase, error = s.error, resultWritten = s.resultWritten }
			out.partialResults = A and { abortedByDeadline = A.abortedByDeadline, error = A.error, cleanupReleased = A.cleanupReleased, steps = #A.log } or nil
			out.runFinished = run and run.aFinished
			out.keys = {
				handover = summarize(recordOf(ctx, "player_900000204")),
				stolen = summarize(recordOf(ctx, "player_900000205")),
			}
			out.writes = writesOf(ctx)
		else
			error("unknown scenario")
		end
	end)
	R5.TIMEOUTS = savedTimeouts
	Guard.APPROVED[R5.OPERATION] = false
	out.ok = ok
	out.error = (not ok) and tostring(err) or nil
	out.flagReset = Guard.APPROVED[R5.OPERATION] == false
	return out
end

return R5
