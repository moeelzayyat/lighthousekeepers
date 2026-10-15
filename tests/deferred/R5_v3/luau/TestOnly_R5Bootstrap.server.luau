-- ServerScriptService.TestOnly_R5Bootstrap  (Script, v3, TASK-012)
-- SAVETEST ONLY. The only auto-running test code. It collects the real server environment and hands it to
-- R5CrossServer.serverMain, which owns every decision (gates, presence, run claim, deadline) and fails closed.
-- Authorization lives in this Script's attributes, set by the arm command, so the source never changes:
--   AuthTest = "R5_CROSS_SERVER", AuthRunId = "R5RUN_<hex>", AuthNotBefore / AuthNotAfter (unix, window <= 3 h),
--   Account1UserId, Account2UserId (numbers).
-- Before serverMain's presence gate passes, this Script makes NO DataStore, MessagingService or teleport call and
-- does not require ProfileStore. It never runs in Studio.

local RunService = game:GetService("RunService")
if RunService:IsStudio() then
	return -- inert in Studio, always
end
if game.PlaceId ~= 128620546156998 or game.GameId ~= 10770892134 then
	return
end
if script:GetAttribute("AuthTest") ~= "R5_CROSS_SERVER" then
	return -- not armed
end
local acc1, acc2 = script:GetAttribute("Account1UserId"), script:GetAttribute("Account2UserId")
local notBefore, notAfter = script:GetAttribute("AuthNotBefore"), script:GetAttribute("AuthNotAfter")
if type(acc1) ~= "number" or type(acc2) ~= "number" or type(notBefore) ~= "number" or type(notAfter) ~= "number" then
	return warn("[R5] inert: incomplete authorization")
end
if os.time() < notBefore or os.time() > notAfter then
	return warn("[R5] inert: outside authorization window")
end

local Players = game:GetService("Players")
-- while authorized, only the two designated accounts may stay in a SaveTest server
local function screen(player)
	if player.UserId ~= acc1 and player.UserId ~= acc2 then
		player:Kick("SaveTest is running a private test.")
	end
end
Players.PlayerAdded:Connect(screen)
for _, p in ipairs(Players:GetPlayers()) do
	screen(p)
end

local T = game:GetService("ServerStorage"):FindFirstChild("TestOnly")
if T == nil then
	return warn("[R5] inert: TestOnly folder missing")
end
local Guard = require(T.SaveTestGuard)
local R5 = require(T.R5CrossServer)

local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local getOptions = Instance.new("DataStoreGetOptions")
getOptions.UseCache = false

-- TeleportInitFailed reports for the designated account 2 (read by the supervised transport task)
local teleportFailures = {}
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
	if player.UserId == acc2 then
		teleportFailures[acc2] = tostring(teleportResult) .. ": " .. tostring(errorMessage)
	end
end)

local env = {
	identity = {
		placeId = game.PlaceId,
		gameId = game.GameId,
		jobId = game.JobId,
		privateServerId = game.PrivateServerId,
		privateServerOwnerId = game.PrivateServerOwnerId,
		isStudio = RunService:IsStudio(),
	},
	attrs = {
		AuthTest = script:GetAttribute("AuthTest"),
		AuthRunId = script:GetAttribute("AuthRunId"),
		AuthNotBefore = notBefore,
		AuthNotAfter = notAfter,
		Account1UserId = acc1,
		Account2UserId = acc2,
	},
	now = os.time,
	nonce = HttpService:GenerateGUID(false),
	isPresent = function(userId)
		return Players:GetPlayerByUserId(userId) ~= nil
	end,
	store = {
		get = function(name, key)
			return DataStoreService:GetDataStore(name):GetAsync(key, getOptions)
		end,
		update = function(name, key, fn)
			return DataStoreService:GetDataStore(name):UpdateAsync(key, fn)
		end,
		set = function(name, key, value)
			return DataStoreService:GetDataStore(name):SetAsync(key, value)
		end,
	},
	loadProfileStore = function()
		return require(T.ProfileStore)
	end,
	reserve = function()
		return TeleportService:ReserveServer(game.PlaceId) -- accessCode, privateServerId
	end,
	teleport = function(userId, accessCode)
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return false, "player left"
		end
		return pcall(function()
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
	end,
	teleportFailure = function(userId)
		return teleportFailures[userId]
	end,
	setApproved = function(v)
		Guard.APPROVED.R5_CROSS_SERVER = v
	end,
}

print("[R5] armed server " .. game.JobId .. " (private=" .. tostring(game.PrivateServerId ~= "") .. "); waiting for the gate")
local summary = R5.serverMain(env)
print("[R5] finished: role=" .. tostring(summary.role) .. " phase=" .. tostring(summary.phase) .. " claimed="
	.. tostring(summary.claimed) .. " transport=" .. tostring(summary.transport and summary.transport.outcome)
	.. " resultWritten=" .. tostring(summary.resultWritten) .. " error=" .. tostring(summary.error))
