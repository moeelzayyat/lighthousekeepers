-- TASK-012 R5 v3 DISARM COMMAND. Edit DataModel of the SaveTest window, after the results are read (or on abort).
-- Removes the auto-running bootstrap from SaveTest. The owner's cleanup publish then removes it from new live servers.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SSS = game:GetService("ServerScriptService")
local boot = SSS:FindFirstChild("TestOnly_R5Bootstrap")
local existed = boot ~= nil
if boot then
	boot.Enabled = false
	boot:Destroy()
end
return "bootstrap existed=" .. tostring(existed) .. " now present=" .. tostring(SSS:FindFirstChild("TestOnly_R5Bootstrap") ~= nil)
	.. " lastRunId=" .. tostring(game:GetService("ServerStorage").TestOnly:GetAttribute("LastR5RunId"))
