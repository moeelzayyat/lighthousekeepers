-- TASK-010 R3 POST-STOP CHECK (final). NOT RUN. Edit DataModel of the SaveTest window, after Play has stopped.
-- Read-only: uncached GetAsync of the synthetic key, the fixture and the probe key. No writes.
-- This is a second, independent observation of the stored record (secondary evidence for release).
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function read(store, key)
	local ok, value, info = pcall(function()
		return DSS:GetDataStore(store):GetAsync(key, opts)
	end)
	local out = { ok = ok }
	if not ok then
		out.error = tostring(value)
		return out
	end
	out.exists = value ~= nil
	if type(value) == "table" then
		out.pearls = value.Data and value.Data.pearls
		local md = value.MetaData
		out.activeSession = md and md.ActiveSession
		out.sessionLoadCount = md and md.SessionLoadCount
	else
		out.value = value
	end
	out.version = info and info.Version
	out.updatedTime = info and info.UpdatedTime
	return out
end
return game:GetService("HttpService"):JSONEncode({
	synthetic = read("TEST_LK_ProfileStore_v2", "player_900000202"),
	fixture = read("TEST_LK_ProfileStore_v2", "player_900000201"),
	probe = read("____PS", "____PS"),
	mainEnabled = game:GetService("ServerScriptService").Server.Main.Enabled,
})
