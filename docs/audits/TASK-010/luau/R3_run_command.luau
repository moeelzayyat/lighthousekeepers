-- TASK-010 R3 RUN COMMAND (final, for runner v2). NOT RUN. Requires the owner's explicit approval.
-- Sent ONCE through MCP execute_luau with datamodel_type = "Server", in the SaveTest window's Play session,
-- only after: owner approval of R3, the disable manifest applied (Main.Enabled = false), and Play started.
-- Never re-sent, even if the MCP call times out: progress is read with R3_status_command.luau.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsServer() and RS:IsRunning() and not RS:IsEdit(), "ABORT not a running server")
assert(game:GetService("ServerScriptService").Server.Main.Enabled == false, "ABORT game Main is enabled")
local T = game:GetService("ServerStorage").TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d", "ABORT guard hash")
assert(sha(T.R3ServerRunner.Source) == "6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733", "ABORT runner hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R3_SERVER_SESSION == false, "ABORT flag already true")
local R3 = require(T.R3ServerRunner)
assert(R3.status().status == "idle", "ABORT runner not idle: " .. tostring(R3.status().status))
Guard.APPROVED.R3_SERVER_SESSION = true -- the runner resets it to false on every exit path
local ok, res = pcall(R3.startReal)
if not ok then
	Guard.APPROVED.R3_SERVER_SESSION = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R3_SERVER_SESSION)
