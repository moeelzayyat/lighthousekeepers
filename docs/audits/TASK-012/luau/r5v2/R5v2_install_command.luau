-- TASK-012 R5 v2 INSTALL COMMAND. NOT RUN. Edit DataModel of the SaveTest window, only AFTER R4 has finished
-- (it changes the guard hash that R4's run command checks). Installs inert code only: no DataStore call, no arming.
-- The bootstrap's v2 source is applied separately with multi_edit and verified by hash in R5v2_arm_command.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SS = game:GetService("ServerStorage")
local T, S = SS.TestOnly, SS.TestOnly_R5v2Staging
local sha = require(T.Sha256)
assert(sha(S.SaveTestGuard.Source) == "2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57", "ABORT staged guard hash")
assert(sha(S.R5CrossServer.Source) == "5db78c3848f69f674445acbea88b7f36aae4799b86c9a55adda031d2934e482a", "ABORT staged R5 hash")
local boot = game:GetService("ServerScriptService").TestOnly_R5Bootstrap
assert(boot.Enabled == false and boot:GetAttribute("AuthTest") == nil, "ABORT bootstrap is armed")
for _, name in ipairs({ "SaveTestGuard", "R5CrossServer" }) do
	local new = S[name]:Clone()
	T[name]:Destroy() -- fresh instances, so require() never returns a cached old module
	new.Parent = T
end
S:Destroy()
return "installed guard " .. sha(T.SaveTestGuard.Source) .. " and R5 " .. sha(T.R5CrossServer.Source)
