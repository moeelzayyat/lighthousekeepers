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
