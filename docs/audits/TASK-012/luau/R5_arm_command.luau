-- TASK-012 R5 ARM COMMAND (template). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- The ONLY substitutions allowed before sending: __USER_ID_1__ and __USER_ID_2__ (the two approved account UserIds).
-- Sets the bootstrap's authorization attributes (a 2-hour window starting now) and enables it. Nothing reaches a live
-- server until the owner publishes SaveTest.
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
assert(sha(T.SaveTestGuard.Source) == "194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b", "ABORT guard hash")
assert(sha(T.R5CrossServer.Source) == "ed6765f9cdec4da25858b8404dfb6bc5125afe942be3f1acad43ccbe569a93e6", "ABORT R5 module hash")
assert(sha(boot.Source) == "85d7bae626e95e988ad4b48ff2b977d7ca7bc13afd3e8df9cdfa28545c00c17f", "ABORT bootstrap hash")
local ids = { __USER_ID_1__, __USER_ID_2__ }
assert(type(ids[1]) == "number" and type(ids[2]) == "number" and ids[1] ~= ids[2], "ABORT user ids")
-- one-shot precheck (uncached reads only)
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function absent(store, key)
	return DSS:GetDataStore(store):GetAsync(key, opts) == nil
end
assert(absent("TEST_LK_ProfileStore_v2", "player_900000204"), "ABORT handover key exists")
assert(absent("TEST_LK_ProfileStore_v2", "player_900000205"), "ABORT stolen key exists")
assert(absent("TEST_LK_R5_Results", "A") and absent("TEST_LK_R5_Results", "B"), "ABORT results exist")
local now = os.time()
boot:SetAttribute("AuthTest", "R5_CROSS_SERVER")
boot:SetAttribute("AuthNotBefore", now)
boot:SetAttribute("AuthNotAfter", now + 2 * 3600)
boot:SetAttribute("AllowedUserIds", tostring(ids[1]) .. "," .. tostring(ids[2]))
boot.Enabled = true
return game:GetService("HttpService"):JSONEncode({ armed = true, notBefore = now, notAfter = now + 2 * 3600, attributes = boot:GetAttributes() })
