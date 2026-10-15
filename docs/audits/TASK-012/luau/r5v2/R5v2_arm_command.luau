-- TASK-012 R5 v2 ARM COMMAND (template). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- The ONLY substitutions allowed: __USER_ID_1__ (account 1, joins first, server A) and __USER_ID_2__ (account 2).
-- Creates a fresh RunId, sets a 2-hour authorization window starting now, and enables the bootstrap. Nothing reaches
-- a live server until the owner publishes SaveTest.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SSS = game:GetService("ServerScriptService")
assert(SSS.Server.Main.Enabled == false, "ABORT game Main is enabled")
local T = game:GetService("ServerStorage").TestOnly
local boot = SSS.TestOnly_R5Bootstrap
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57", "ABORT guard hash")
assert(sha(T.R5CrossServer.Source) == "5db78c3848f69f674445acbea88b7f36aae4799b86c9a55adda031d2934e482a", "ABORT R5 module hash")
assert(sha(boot.Source) == "f528fa5cb4817767df47a6e058eec41343b887a86ecba672cdac3ec0a8287aa6", "ABORT bootstrap hash")
local acc1, acc2 = __USER_ID_1__, __USER_ID_2__
assert(type(acc1) == "number" and type(acc2) == "number" and acc1 ~= acc2, "ABORT user ids")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function absent(store, key)
	return DSS:GetDataStore(store):GetAsync(key, opts) == nil
end
assert(absent("TEST_LK_ProfileStore_v2", "player_900000204"), "ABORT handover key exists")
assert(absent("TEST_LK_ProfileStore_v2", "player_900000205"), "ABORT stolen key exists")
local runId = "R5RUN_" .. string.lower(string.gsub(game:GetService("HttpService"):GenerateGUID(false), "-", ""))
assert(absent("TEST_LK_R5_Run", runId), "ABORT run record exists")
local now = os.time()
boot:SetAttribute("AuthTest", "R5_CROSS_SERVER")
boot:SetAttribute("AuthRunId", runId)
boot:SetAttribute("AuthNotBefore", now)
boot:SetAttribute("AuthNotAfter", now + 2 * 3600)
boot:SetAttribute("Account1UserId", acc1)
boot:SetAttribute("Account2UserId", acc2)
T:SetAttribute("LastR5RunId", runId) -- kept after disarm so the results can still be read
boot.Enabled = true
return game:GetService("HttpService"):JSONEncode({ armed = true, runId = runId, notBefore = now, notAfter = now + 2 * 3600, runDeadline = now + 2 * 3600 - 300, attributes = boot:GetAttributes() })
