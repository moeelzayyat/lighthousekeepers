-- ServerStorage.TestOnly.SaveAdapterV2  (TASK-013 proposal; SaveTest only; not wired into the game)
-- The v1-to-v2 save adapter and one-time importer, for the ProfileStore path chosen in TASK-004:
--   * v2 lives in its OWN store; ProfileStore is never pointed at a store that holds flat v1 records.
--   * v1 is READ ONLY. This module has no function that can write v1: its only v1 access is deps.readV1(key).
--   * The import runs once per player, inside that player's v2 session, and is recorded in the same atomic
--     profile record (Data.importState = "done"), so re-running it is harmless.
--   * Fail closed: a v1 read failure, an invalid v1 record or a v2 key with a non-ProfileStore value means
--     NO play and NO "done" mark. The player is told to rejoin; nothing is overwritten.
--   * StartSessionAsync is called WITHOUT params (no Cancel, no Steal). TASK-007 showed a Cancel that turns true
--     mid-load lets the library overwrite a non-conforming record; with no Cancel that path does not exist, and
--     the shape preflight refuses any non-conforming v2 key before the library sees it.
-- Nothing here makes a real DataStore call by itself: all access goes through injected deps. The only entry
-- point used in this task is Adapter.runMockTests (in-memory fakes, Edit mode).

local Adapter = {}

Adapter.KEY_PREFIX = "player_"
Adapter.V1_READ_ATTEMPTS = 3

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
Adapter.deepCopy = deepCopy

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
Adapter.deepEqual = deepEqual

-- A value the library will accept as its own record (anything else it would overwrite).
function Adapter.isProfileStoreShaped(v)
	return type(v) == "table" and type(v.Data) == "table" and type(v.MetaData) == "table"
		and type(v.GlobalUpdates) == "table"
end

local function finiteNonNegative(n)
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

-- Checks a v1 record against the documented v1 schema (TASK-003 section 2). Unknown top-level keys are allowed
-- (v1's reconcile keeps them); wrong types on known keys are not.
function Adapter.validateV1(v)
	if type(v) ~= "table" then
		return false, "v1 value is not a table (" .. type(v) .. ")"
	end
	if v.pearls ~= nil and not finiteNonNegative(v.pearls) then
		return false, "pearls is not a finite non-negative number"
	end
	if v.version ~= nil and type(v.version) ~= "number" then
		return false, "version is not a number"
	end
	if v.owned ~= nil then
		if type(v.owned) ~= "table" then
			return false, "owned is not a table"
		end
		for k, val in pairs(v.owned) do
			if type(k) ~= "string" or val ~= true then
				return false, "owned has an entry that is not string -> true"
			end
		end
	end
	if v.counts ~= nil then
		if type(v.counts) ~= "table" then
			return false, "counts is not a table"
		end
		for k, val in pairs(v.counts) do
			if type(k) ~= "string" or not finiteNonNegative(val) or val % 1 ~= 0 then
				return false, "counts has an entry that is not string -> whole number >= 0"
			end
		end
	end
	for _, f in ipairs({ "equippedArmor", "equippedWeapon", "equippedBeam" }) do
		if v[f] ~= nil and type(v[f]) ~= "string" then
			return false, f .. " is not a string"
		end
	end
	if v.stats ~= nil then
		if type(v.stats) ~= "table" then
			return false, "stats is not a table"
		end
		for k, val in pairs(v.stats) do
			if type(k) ~= "string" or not finiteNonNegative(val) then
				return false, "stats has a non-numeric entry"
			end
		end
	end
	if v._session ~= nil or v._owner ~= nil then
		-- not expected (no lock was ever shipped); refuse rather than guess
		return false, "unexpected lock field in a v1 record"
	end
	return true
end

-- Maps a validated v1 record to v2 Data: exactly today's load semantics (reconcile on a copy), plus the import
-- marker. v1 itself is never modified (the copy is taken first).
function Adapter.mapV1(v1, reconcile, now)
	local data = reconcile(deepCopy(v1))
	data.importState = "done"
	data.importedFrom = { schema = 1, at = now }
	return data
end

-- One player's load. deps:
--   PS                 the ProfileStore module (real or fake)
--   v2StoreName, template, newProfile(), reconcile(profile)
--   readV1(key)        -> value (nil if absent); errors on failure. READ ONLY.
--   readV2Raw(key)     -> raw stored value of the v2 key (uncached GetAsync); errors on failure.
--   now()              -> os.time()
--   wait(seconds)
-- stillInGame() -> boolean
-- Returns { status = "ok" | "refused" | "failed", reason, profile, imported, log }.
function Adapter.load(deps, userId, stillInGame)
	local key = Adapter.KEY_PREFIX .. tostring(userId)
	local log = {}
	local function note(s)
		table.insert(log, s)
	end
	-- 1. shape preflight: never let the library see a non-conforming v2 value (it would overwrite it)
	local okPre, pre = pcall(deps.readV2Raw, key)
	if not okPre then
		return { status = "failed", reason = "v2 preflight read failed: " .. tostring(pre), log = log }
	end
	if pre ~= nil and not Adapter.isProfileStoreShaped(pre) then
		note("v2 key holds a non-ProfileStore value; refused before StartSessionAsync")
		return { status = "refused", reason = "v2 key holds an unexpected value; left untouched", log = log }
	end
	-- 2. session (no params: no Cancel, no Steal)
	local store = deps.PS.New(deps.v2StoreName, deps.template)
	local profile = store:StartSessionAsync(key)
	if profile == nil then
		return { status = "failed", reason = "could not start a v2 session", log = log }
	end
	if not stillInGame() then
		profile:EndSession()
		return { status = "failed", reason = "player left during load", log = log }
	end
	-- 3. one-time import
	local imported = false
	if profile.Data.importState ~= "done" then
		local v1, readOk, lastErr = nil, false, nil
		for attempt = 1, Adapter.V1_READ_ATTEMPTS do
			local ok, value = pcall(deps.readV1, key)
			if ok then
				v1, readOk = value, true
				break
			end
			lastErr = value
			note("v1 read attempt " .. attempt .. " failed: " .. tostring(value))
			deps.wait(attempt)
		end
		if not readOk then
			profile:EndSession() -- importState stays unset; the next join retries
			return { status = "failed", reason = "v1 read failed: " .. tostring(lastErr), log = log }
		end
		if v1 == nil then
			local fresh = deps.newProfile()
			for k, v in pairs(fresh) do
				profile.Data[k] = v
			end
			profile.Data.importState = "done"
			profile.Data.importedFrom = { schema = 0, at = deps.now(), reason = "no v1 record" }
			note("no v1 record: new player")
		else
			local valid, why = Adapter.validateV1(v1)
			if not valid then
				profile:EndSession()
				return { status = "refused", reason = "v1 record failed validation: " .. why, log = log }
			end
			local data = Adapter.mapV1(v1, deps.reconcile, deps.now())
			for k in pairs(profile.Data) do
				profile.Data[k] = nil
			end
			for k, v in pairs(data) do
				profile.Data[k] = v
			end
			note("imported v1 record")
		end
		imported = true
		profile:Save() -- persist the import at once
	else
		note("already imported; v1 not read")
	end
	return { status = "ok", profile = profile, imported = imported, log = log }
end

----------------------------------------------------------------------------------------------------------------------
-- Mock tests (Edit mode, in-memory fakes only; no real DataStore call)
----------------------------------------------------------------------------------------------------------------------
local FAKE_ITEMS = { DriftwoodHarpoon = { starter = true }, OilskinCoat = { starter = true }, BeamAmber = { starter = true } }

local function fakeNewProfile()
	local p = {
		version = 1,
		pearls = 0,
		owned = {},
		counts = {},
		equippedArmor = "OilskinCoat",
		equippedWeapon = "DriftwoodHarpoon",
		equippedBeam = "BeamAmber",
		stats = { runs = 0, victories = 0, bestNight = 0 },
	}
	for id, item in pairs(FAKE_ITEMS) do
		if item.starter then
			p.owned[id] = true
		end
	end
	return p
end

-- a copy of PlayerData.reconcile's rules (production would call the real function)
local function fakeReconcile(profile)
	local template = fakeNewProfile()
	for k, v in pairs(template) do
		if profile[k] == nil then
			profile[k] = v
		end
	end
	for id, item in pairs(FAKE_ITEMS) do
		if item.starter then
			profile.owned[id] = true
		end
	end
	if not profile.owned[profile.equippedArmor] then
		profile.equippedArmor = "OilskinCoat"
	end
	if not profile.owned[profile.equippedWeapon] then
		profile.equippedWeapon = "DriftwoodHarpoon"
	end
	if not profile.owned[profile.equippedBeam] then
		profile.equippedBeam = "BeamAmber"
	end
	return profile
end

function Adapter.runMockTests(vendorSource)
	local Guard = require(script.Parent.SaveTestGuard)
	Guard.assertSaveTest()
	local MockBackend = require(script.Parent.MockBackend)
	local V1 = Guard.TEST_V1_FIXTURE_STORE -- "TEST_LK_V1Fixtures" (fake world only)
	local V2 = "TEST_LK_ImportV2" -- fake world only
	Guard.assertStoreName(V1)
	Guard.assertStoreName(V2)

	local results = {}
	local function record(id, name, pass, detail)
		table.insert(results, { id = id, name = name, pass = pass == true, detail = detail })
	end
	-- a test that throws (including a guard assert inside the fakes) is recorded as a failure
	local function run(id, fn)
		local ok, err = pcall(fn)
		if not ok then
			record(id, "(crashed)", false, tostring(err))
		end
	end

	local function newEnv(opts)
		opts = opts or {}
		local world = opts.world or MockBackend.newWorld()
		local h = MockBackend.loadVendor(vendorSource, world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = "JOB_IMPORT" })
		local t0 = os.clock()
		while h.PS.DataStoreState ~= "Access" and os.clock() - t0 < 3 do
			task.wait()
		end
		local v1Fails = opts.v1Fails or 0
		local v1Reads = 0
		local restricted = {
			New = function(name, template)
				assert(name == V2, "adapter used a store other than v2: " .. tostring(name))
				local real = h.PS.New(name, template)
				return {
					StartSessionAsync = function(_, key, params)
						assert(params == nil, "adapter passed StartSessionAsync params")
						return real:StartSessionAsync(key)
					end,
				}
			end,
		}
		local deps = {
			PS = restricted,
			v2StoreName = V2,
			template = fakeNewProfile(),
			newProfile = fakeNewProfile,
			reconcile = fakeReconcile,
			readV1 = function(key)
				v1Reads += 1
				if v1Fails > 0 then
					v1Fails -= 1
					error("MOCK v1 read failure")
				end
				return MockBackend.deepCopy(MockBackend.record(world, V1, key))
			end,
			readV2Raw = function(key)
				return MockBackend.deepCopy(MockBackend.record(world, V2, key))
			end,
			now = os.time,
			wait = function() end,
		}
		return {
			world = world,
			h = h,
			deps = deps,
			v1Reads = function()
				return v1Reads
			end,
			v1Writes = function()
				local n = 0
				for _, w in ipairs(world.writes) do
					if w.store == V1 then
						n += 1
					end
				end
				return n - (opts.seededV1 or 0)
			end,
			release = function(profile)
				if profile and profile:IsActive() then
					profile:EndSession()
				end
				local t1 = os.clock()
				while os.clock() - t1 < 3 do
					local r = MockBackend.record(world, V2, "player_1")
					if r and r.MetaData and r.MetaData.ActiveSession == nil then
						break
					end
					task.wait(0.05)
				end
			end,
		}
	end
	local function seedV1(env, value)
		MockBackend.seed(env.world, V1, "player_1", value)
		table.insert(env.world.writes, { store = V1, key = "player_1", op = "seed" })
	end
	local function waitSaved(profile)
		local t0 = os.clock()
		while os.clock() - t0 < 3 do
			if profile.LastSavedData and profile.LastSavedData.importState == "done" then
				return true
			end
			task.wait(0.05)
		end
		return false
	end
	local yes = function()
		return true
	end

	local full = {
		version = 1,
		pearls = 1234,
		owned = { DriftwoodHarpoon = true, OilskinCoat = true, BeamAmber = true, StormLance = true },
		counts = { AmmoCrate = 3, Driftwood = 12 },
		equippedArmor = "OilskinCoat",
		equippedWeapon = "StormLance",
		equippedBeam = "BeamAmber",
		stats = { runs = 9, victories = 2, bestNight = 11 },
	}

	-- I1 new player: no v1, no v2
	run("I1", function()
		local env = newEnv()
		local r = Adapter.load(env.deps, 1, yes)
		local ok = r.status == "ok" and r.profile.Data.importState == "done" and r.profile.Data.pearls == 0
			and r.profile.Data.importedFrom.schema == 0 and waitSaved(r.profile) and env.v1Writes() == 0
		record("I1", "new player: template, marked done, saved, v1 untouched", ok, { status = r.status, reason = r.reason })
		env.release(r.profile)
		env.h.destroy()
	end)
	-- I2 full v1 record imported exactly; v1 unchanged
	run("I2", function()
		local env = newEnv({ seededV1 = 1 })
		seedV1(env, full)
		local before = MockBackend.deepCopy(MockBackend.record(env.world, V1, "player_1"))
		local r = Adapter.load(env.deps, 1, yes)
		local d = r.profile and r.profile.Data or {}
		local copy = MockBackend.deepCopy(d)
		copy.importState, copy.importedFrom = nil, nil
		local ok = r.status == "ok" and deepEqual(copy, full) and d.importState == "done" and waitSaved(r.profile)
			and deepEqual(MockBackend.record(env.world, V1, "player_1"), before) and env.v1Writes() == 0
		record("I2", "full v1 record copied exactly; v1 byte-for-byte unchanged; no v1 write", ok, { status = r.status })
		env.release(r.profile)
		env.h.destroy()
	end)
	-- I3 old save without equippedBeam gets the default (today's reconcile)
	run("I3", function()
		local env = newEnv({ seededV1 = 1 })
		local old = MockBackend.deepCopy(full)
		old.equippedBeam = nil
		seedV1(env, old)
		local r = Adapter.load(env.deps, 1, yes)
		record("I3", "missing equippedBeam defaults to BeamAmber", r.status == "ok" and r.profile.Data.equippedBeam == "BeamAmber", { status = r.status })
		env.release(r.profile)
		env.h.destroy()
	end)
	-- I4 unknown extra fields preserved (v1 reconcile never removes keys)
	run("I4", function()
		local env = newEnv({ seededV1 = 1 })
		local extra = MockBackend.deepCopy(full)
		extra.futureField = { a = 1 }
		seedV1(env, extra)
		local r = Adapter.load(env.deps, 1, yes)
		record("I4", "unknown v1 fields preserved", r.status == "ok" and deepEqual(r.profile.Data.futureField, { a = 1 }), { status = r.status })
		env.release(r.profile)
		env.h.destroy()
	end)
	-- I5 invalid v1 types: refused, not marked done, v1 untouched
	run("I5", function()
		local env = newEnv({ seededV1 = 1 })
		local bad = MockBackend.deepCopy(full)
		bad.pearls = "1234"
		seedV1(env, bad)
		local r = Adapter.load(env.deps, 1, yes)
		local stored = MockBackend.record(env.world, V2, "player_1")
		local ok = r.status == "refused" and (stored == nil or stored.Data.importState ~= "done") and env.v1Writes() == 0
		record("I5", "invalid v1 record refused (fail closed); not marked done; v1 untouched", ok, { status = r.status, reason = r.reason })
		env.h.destroy()
	end)
	-- I6 v1 read fails 3 times: no play, not marked done, retry later succeeds
	run("I6", function()
		local env = newEnv({ seededV1 = 1, v1Fails = 3 })
		seedV1(env, full)
		local r1 = Adapter.load(env.deps, 1, yes)
		local t0 = os.clock()
		while os.clock() - t0 < 3 do
			local s = MockBackend.record(env.world, V2, "player_1")
			if s == nil or (s.MetaData and s.MetaData.ActiveSession == nil) then
				break
			end
			task.wait(0.05)
		end
		local stored = MockBackend.record(env.world, V2, "player_1")
		local notDone = stored == nil or stored.Data.importState ~= "done"
		local r2 = Adapter.load(env.deps, 1, yes)
		local ok = r1.status == "failed" and notDone and r2.status == "ok" and r2.profile.Data.pearls == 1234
			and env.v1Writes() == 0
		record("I6", "v1 read failure: no play and no done mark; next join imports", ok, { first = r1.status, firstReason = r1.reason, second = r2.status })
		env.release(r2.profile)
		env.h.destroy()
	end)
	-- I7 second load after import does not read v1 again (v1 is frozen for this player)
	run("I7", function()
		local env = newEnv({ seededV1 = 1 })
		seedV1(env, full)
		local r1 = Adapter.load(env.deps, 1, yes)
		waitSaved(r1.profile)
		env.release(r1.profile)
		local reads = env.v1Reads()
		MockBackend.record(env.world, V1, "player_1").pearls = 99999 -- an old server changing v1 later
		local r2 = Adapter.load(env.deps, 1, yes)
		local ok = r2.status == "ok" and env.v1Reads() == reads and r2.profile.Data.pearls == 1234 and r2.imported == false
		record("I7", "re-load after import skips v1 (no double import, later v1 edits ignored)", ok, { status = r2.status, pearls = r2.profile and r2.profile.Data.pearls })
		env.release(r2.profile)
		env.h.destroy()
	end)
	-- I8 v2 key already holds a flat (non-ProfileStore) value: refused before the library sees it; value kept
	run("I8", function()
		local env = newEnv()
		MockBackend.seed(env.world, V2, "player_1", { pearls = 777 })
		local before = MockBackend.deepCopy(MockBackend.record(env.world, V2, "player_1"))
		local writesBefore = #env.world.writes
		local r = Adapter.load(env.deps, 1, yes)
		local ok = r.status == "refused" and deepEqual(MockBackend.record(env.world, V2, "player_1"), before)
			and #env.world.writes == writesBefore
		record("I8", "flat value in the v2 key is refused and left untouched (no library overwrite)", ok, { status = r.status, reason = r.reason })
		env.h.destroy()
	end)
	-- I9 crash after import before the save lands: next load imports again from unchanged v1, same result
	run("I9", function()
		local env = newEnv({ seededV1 = 1 })
		seedV1(env, full)
		local r1 = Adapter.load(env.deps, 1, yes)
		-- simulate server 1 dying before its import save landed and its lock being cleared: the stored v2 record
		-- is put back to the state of a session start with no import (as a cancelled first load leaves it)
		local stored = MockBackend.record(env.world, V2, "player_1")
		stored.Data = fakeNewProfile()
		stored.MetaData.ActiveSession = nil
		-- a NEW server (second fake ProfileStore on the same world) loads the player
		local env2 = newEnv({ world = env.world, seededV1 = 1 })
		local r2 = Adapter.load(env2.deps, 1, yes)
		local ok = r1.status == "ok" and r2.status == "ok" and r2.profile.Data.pearls == 1234 and r2.imported == true
			and r2.profile.Data.importState == "done" and env2.v1Writes() == 0
		record("I9", "import interrupted before saving: a new server re-imports the same result", ok, { first = r1.status, second = r2.status })
		env2.release(r2.profile)
		env2.h.destroy()
	end)
	-- I10 player leaves during load: session ended, nothing imported
	run("I10", function()
		local env = newEnv({ seededV1 = 1 })
		seedV1(env, full)
		local r = Adapter.load(env.deps, 1, function()
			return false
		end)
		local t0 = os.clock()
		local stored
		while os.clock() - t0 < 3 do
			stored = MockBackend.record(env.world, V2, "player_1")
			if stored and stored.MetaData.ActiveSession == nil then
				break
			end
			task.wait(0.05)
		end
		local ok = r.status == "failed" and stored ~= nil and stored.Data.importState ~= "done" and env.v1Reads() == 0
		record("I10", "player left during load: session released, no import, v1 not read", ok, { status = r.status })
		env.h.destroy()
	end)
	-- I11 non-table v1 value refused
	run("I11", function()
		local env = newEnv({ seededV1 = 1 })
		seedV1(env, "corrupt")
		local r = Adapter.load(env.deps, 1, yes)
		record("I11", "non-table v1 value refused", r.status == "refused" and env.v1Writes() == 0, { status = r.status, reason = r.reason })
		env.h.destroy()
	end)
	-- (invariant, not a separate test: the restricted fake asserts on every call that the adapter passes no
	-- StartSessionAsync params and uses no store but v2; a violation would crash and fail that test)

	local passed = 0
	for _, r in ipairs(results) do
		if r.pass then
			passed += 1
		end
	end
	return { passed = passed, total = #results, results = results }
end

return Adapter
