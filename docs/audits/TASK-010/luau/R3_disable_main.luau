-- TASK-010 R3 PRE-STEP (final). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- Applies the disable manifest: the only change is ServerScriptService.Server.Main.Enabled = false.
-- Rollback: set Enabled = true, or restore SaveTest_TASK-010_pre.rbxl.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local main = game:GetService("ServerScriptService").Server.Main
assert(main:IsA("Script"), "ABORT Main is not a Script")
local before = main.Enabled
main.Enabled = false
return "Main.Enabled before=" .. tostring(before) .. " after=" .. tostring(main.Enabled)
