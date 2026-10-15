-- TEST_LK_IsolationCanary: runs ONLY in the SaveTest Studio instance (Edit mode, no Play).
-- Writes exactly one harmless marker into a brand-new DataStore named TEST_LK_IsolationCanary,
-- reads it back, and reports. It never touches any other store or key and never deletes anything.
-- Any ID mismatch aborts BEFORE DataStoreService is touched.

local SAVETEST_PLACE_ID = 128620546156998
local SAVETEST_GAME_ID = 10770892134 -- universe
local PROD_PLACE_ID = 132065051336560
local PROD_GAME_ID = 10769064643

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

assert(game.PlaceId == SAVETEST_PLACE_ID, "ABORT: PlaceId is not the SaveTest place: " .. tostring(game.PlaceId))
assert(game.GameId == SAVETEST_GAME_ID, "ABORT: GameId is not the SaveTest universe: " .. tostring(game.GameId))
assert(game.PlaceId ~= PROD_PLACE_ID and game.GameId ~= PROD_GAME_ID, "ABORT: production IDs detected")
assert(RunService:IsEdit() and not RunService:IsRunning(), "ABORT: must run in Edit mode, not Play")

local STORE_NAME = "TEST_LK_IsolationCanary"
local KEY = "isolation_canary_v1"

local result = { placeId = game.PlaceId, gameId = game.GameId, store = STORE_NAME, key = KEY }

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore(STORE_NAME)

-- 1) read first: the marker must not exist yet
local okBefore, before = pcall(function() return store:GetAsync(KEY) end)
result.readBefore = { ok = okBefore, isNil = okBefore and before == nil, err = (not okBefore) and tostring(before) or nil }

if okBefore and before == nil then
	-- 2) the single write
	local marker = {
		purpose = "isolation canary",
		placeId = game.PlaceId,
		gameId = game.GameId,
		writtenAt = os.time(),
	}
	local okWrite, writeErr = pcall(function() return store:SetAsync(KEY, marker) end)
	result.write = { ok = okWrite, err = (not okWrite) and tostring(writeErr) or nil, version = okWrite and tostring(writeErr) or nil }

	-- 3) read it back
	local okAfter, after = pcall(function() return store:GetAsync(KEY) end)
	result.readBack = {
		ok = okAfter,
		matches = okAfter and type(after) == "table" and after.purpose == marker.purpose
			and after.gameId == marker.gameId and after.placeId == marker.placeId and after.writtenAt == marker.writtenAt,
		err = (not okAfter) and tostring(after) or nil,
	}
else
	result.write = { skipped = true, reason = "read failed or a marker already exists; nothing written" }
end

return HttpService:JSONEncode(result)
