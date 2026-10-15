-- TASK-012 R5 RESULTS CHECK. Edit DataModel, read-only (uncached GetAsync). Safe to repeat while the test runs.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function get(store, key)
	local ok, value, info = pcall(function()
		return DSS:GetDataStore(store):GetAsync(key, opts)
	end)
	return ok, value, info
end
local function profile(key)
	local ok, v, info = get("TEST_LK_ProfileStore_v2", key)
	if not ok then
		return { error = tostring(v) }
	end
	local md = type(v) == "table" and v.MetaData or nil
	return {
		exists = v ~= nil,
		pearls = type(v) == "table" and v.Data and v.Data.pearls or nil,
		activeSession = md and md.ActiveSession,
		forceLoadSession = md and md.ForceLoadSession,
		sessionLoadCount = md and md.SessionLoadCount,
		version = info and info.Version,
		updatedTime = info and info.UpdatedTime,
	}
end
local okA, resA = get("TEST_LK_R5_Results", "A")
local okB, resB = get("TEST_LK_R5_Results", "B")
local R5 = require(game:GetService("ServerStorage").TestOnly.R5CrossServer) -- pure evaluator; makes no calls
return game:GetService("HttpService"):JSONEncode({
	checks = R5.evaluate(okA and resA or nil, okB and resB or nil),
	resultsA = okA and resA or { error = tostring(resA) },
	resultsB = okB and resB or { error = tostring(resB) },
	handover204 = profile("player_900000204"),
	stolen205 = profile("player_900000205"),
	fixture201 = profile("player_900000201"),
	fixture202 = profile("player_900000202"),
	r4key203 = profile("player_900000203"),
})
