-- TASK-008 R1: load the REAL pinned ProfileStore module ONCE through SaveTestGuard, SaveTest only.
-- Authorized write: the module's own Studio probe, store "____PS", key "____PS", in the SaveTest universe.
-- NOT called: ProfileStore.New, StartSessionAsync, Save, EndSession, RemoveAsync, MessageAsync, GetAsync, or anything else.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")

local T = game.ServerStorage.TestOnly
local sha = require(T.Sha256)
local Guard = require(T.SaveTestGuard)
local out = { startedAt = os.time() }

-- the module we are about to load must be the pinned one
out.sourceSha = sha(T.ProfileStore.Source)
assert(out.sourceSha == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash mismatch")
out.flagBefore = Guard.REAL_DATASTORE_APPROVED
assert(out.flagBefore == false, "ABORT flag was already true")

-- enable the flag ONLY for this one require, and ALWAYS put it back
Guard.REAL_DATASTORE_APPROVED = true
local ok, PS = pcall(function()
	return Guard.requireRealProfileStore(T.ProfileStore)
end)
Guard.REAL_DATASTORE_APPROVED = false
out.requireOk = ok
out.flagAfterRequire = Guard.REAL_DATASTORE_APPROVED
if not ok then
	out.requireError = tostring(PS)
	return game:GetService("HttpService"):JSONEncode(out)
end

-- wait (read-only) for the module's own probe to settle its state
local t0 = os.clock()
while PS.DataStoreState == "NotReady" and os.clock() - t0 < 20 do
	task.wait(0.1)
end
out.dataStoreState = PS.DataStoreState
out.isCriticalState = PS.IsCriticalState
out.isClosing = PS.IsClosing
out.secondsToSettle = os.clock() - t0
out.moduleType = typeof(PS)
return game:GetService("HttpService"):JSONEncode(out)
