-- TASK-009 R2 RUN COMMAND (to be executed once, only after the owner's explicit "approve R2").
-- Runs in the SaveTest Studio window, Edit mode, through MCP execute_luau.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local T = game.ServerStorage.TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab", "ABORT guard hash")
assert(sha(T.R2SaveLoad.Source) == "8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25", "ABORT entrypoint hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R2_SAVE_LOAD == false, "ABORT flag already true")
Guard.APPROVED.R2_SAVE_LOAD = true -- the entrypoint resets it to false on every exit path
local ok, res = pcall(function()
	return require(T.R2SaveLoad).startReal()
end)
if not ok then
	Guard.APPROVED.R2_SAVE_LOAD = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R2_SAVE_LOAD)
