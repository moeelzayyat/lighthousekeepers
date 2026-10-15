-- AD-HOC TEST M3b / M11b (run through execute_luau in the SaveTest window; not installed as a script).
-- Question: what does ProfileStore do when Cancel flips to true AFTER the load loop has started
-- (so the DataStore transform runs while cancelled)? Uses the in-memory fakes only; the real module is not required.
-- M3 and M11 (Cancel true from the very first call) were already run by MockTests.

local Guard = require(game.ServerStorage.TestOnly.SaveTestGuard)
Guard.assertSaveTest()
assert(game:GetService("RunService"):IsEdit() and not game:GetService("RunService"):IsRunning(), "ABORT not edit mode")

local T = game.ServerStorage.TestOnly
local MockBackend = require(T.MockBackend)
local STORE = Guard.TEST_STORE_NAME
local PLACE = Guard.SAVETEST_PLACE_ID

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

local world = MockBackend.newWorld()
local h = MockBackend.loadVendor(T.ProfileStore.Source, world, { PlaceId = PLACE, JobId = "JOB_A" })
assert(waitUntil(function()
	return h.PS.DataStoreState == "Access"
end, 3), "mock state never Access")
local store = h.PS.New(STORE, { version = 1, pearls = 0 })
local out = {}

-- M3b: legacy flat record, Cancel returns false on its first call (loop condition) and true afterwards
MockBackend.seed(world, STORE, "player_900000103", { version = 1, pearls = 321, owned = { StormHarpoon = true } })
local calls1 = 0
local p1 = store:StartSessionAsync("player_900000103", {
	Cancel = function()
		calls1 += 1
		return calls1 >= 2
	end,
})
task.wait(0.1)
local r1 = MockBackend.record(world, STORE, "player_900000103")
out.M3b = {
	cancelCalls = calls1,
	returnedNil = p1 == nil,
	storedHasWrapper = r1.Data ~= nil and r1.MetaData ~= nil,
	legacyPearlsStillThere = r1.pearls == 321,
	storedPearlsAfter = r1.Data and r1.Data.pearls,
	activeSession = r1.MetaData and r1.MetaData.ActiveSession,
}

-- M11b: brand-new key, same flipping Cancel
local calls2 = 0
local p2 = store:StartSessionAsync("player_900000104", {
	Cancel = function()
		calls2 += 1
		return calls2 >= 2
	end,
})
task.wait(0.1)
local r2 = MockBackend.record(world, STORE, "player_900000104")
out.M11b = {
	cancelCalls = calls2,
	returnedNil = p2 == nil,
	recordCreated = r2 ~= nil,
	activeSession = r2 and r2.MetaData and r2.MetaData.ActiveSession,
	dataIsTemplate = r2 and r2.Data and r2.Data.pearls == 0,
}

h.destroy()
return game:GetService("HttpService"):JSONEncode(out)
