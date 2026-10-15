-- TASK-012 R4 RUN COMMAND. NOT RUN. Requires the owner's explicit approval.
-- Sent ONCE through MCP execute_luau with datamodel_type = "Server", in the SaveTest window's Play session.
-- Never re-sent, even if the MCP call times out: progress is read with R4_status_command.luau.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsServer() and RS:IsRunning() and not RS:IsEdit() and RS:IsStudio(), "ABORT not a running Studio server")
local SSS = game:GetService("ServerScriptService")
assert(SSS.Server.Main.Enabled == false, "ABORT game Main is enabled")
local boot = SSS:FindFirstChild("TestOnly_R5Bootstrap")
assert(boot == nil or boot.Enabled == false or boot:GetAttribute("AuthTest") == nil, "ABORT R5 bootstrap is armed")
local T = game:GetService("ServerStorage").TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b", "ABORT guard hash")
assert(sha(T.R4ShutdownRunner.Source) == "1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613", "ABORT runner hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R4_SHUTDOWN_RELEASE == false, "ABORT flag already true")
local R4 = require(T.R4ShutdownRunner)
assert(R4.status().status == "idle", "ABORT runner not idle: " .. tostring(R4.status().status))
Guard.APPROVED.R4_SHUTDOWN_RELEASE = true -- the runner resets it to false on every exit path
local ok, res = pcall(R4.startReal)
if not ok then
	Guard.APPROVED.R4_SHUTDOWN_RELEASE = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R4_SHUTDOWN_RELEASE)
