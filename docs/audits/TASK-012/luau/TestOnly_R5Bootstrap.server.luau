-- ServerScriptService.TestOnly_R5Bootstrap  (Script, TASK-012)
-- SAVETEST ONLY. The only auto-running test code. It FAILS CLOSED: it returns without any DataStore, MessagingService
-- or teleport call unless EVERY check below passes. All authorization data lives in this Script's attributes, so the
-- source (and its hash) never changes:
--   AuthTest        = "R5_CROSS_SERVER"
--   AuthNotBefore   = unix seconds   } window set at install, at most 3 hours long
--   AuthNotAfter    = unix seconds   }
--   AllowedUserIds  = "<id1>,<id2>"  the two approved accounts; any other player is kicked while the test is authorized
-- It never runs in Studio. Roles: A = public server, B = reserved server created by A.
-- One-shot: a role does nothing if its results record (or, for A, the handover key) already exists.

local RunService = game:GetService("RunService")
if RunService:IsStudio() then
	return -- inert in Studio, always
end

local function refuse(reason)
	warn("[R5] inert: " .. reason)
end

if game.PlaceId ~= 128620546156998 or game.GameId ~= 10770892134 then
	return refuse("not SaveTest")
end
if game.PlaceId == 132065051336560 or game.GameId == 10769064643 then
	return refuse("production ids")
end
if game.JobId == "" then
	return refuse("empty JobId")
end
if script:GetAttribute("AuthTest") ~= "R5_CROSS_SERVER" then
	return refuse("no authorization")
end
local notBefore, notAfter = script:GetAttribute("AuthNotBefore"), script:GetAttribute("AuthNotAfter")
if type(notBefore) ~= "number" or type(notAfter) ~= "number" or notAfter - notBefore > 3 * 3600 or notAfter <= notBefore then
	return refuse("bad authorization window")
end
local now = os.time()
if now < notBefore or now > notAfter then
	return refuse("outside authorization window")
end
local allowed = {}
local allowedCount = 0
for id in string.gmatch(tostring(script:GetAttribute("AllowedUserIds") or ""), "%d+") do
	allowed[tonumber(id)] = true
	allowedCount += 1
end
if allowedCount ~= 2 then
	return refuse("AllowedUserIds must list exactly two accounts")
end

local ServerStorage = game:GetService("ServerStorage")
local T = ServerStorage:FindFirstChild("TestOnly")
if T == nil then
	return refuse("TestOnly folder missing")
end
local Guard = require(T.SaveTestGuard)
local R5 = require(T.R5CrossServer)
local op = Guard.OPERATIONS.R5_CROSS_SERVER
if op == nil then
	return refuse("guard has no R5 operation")
end

local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local isPublic = game.PrivateServerId == ""
local role = isPublic and "A" or (isReserved and "B" or nil)
if role == nil then
	return refuse("server type is neither public nor reserved")
end

local Players = game:GetService("Players")
local function screen(player)
	if not allowed[player.UserId] then
		player:Kick("SaveTest is running a private test.")
	end
end
Players.PlayerAdded:Connect(screen)
for _, p in ipairs(Players:GetPlayers()) do
	screen(p)
end

local DataStoreService = game:GetService("DataStoreService")
local okOpts, getOptions = pcall(function()
	local o = Instance.new("DataStoreGetOptions")
	o.UseCache = false
	return o
end)
local function readRaw(store, key)
	assert(op.rawReads[store .. "/" .. key] == true, "R5 ABORT: raw read not allowed: " .. store .. "/" .. key)
	local ds = DataStoreService:GetDataStore(store)
	if okOpts then
		return ds:GetAsync(key, getOptions)
	end
	return ds:GetAsync(key)
end
local function writeResult(r, tbl)
	assert(r == role, "R5 ABORT: a server may only write its own results")
	assert(op.rawWrites[op.resultsStore .. "/" .. r] == true, "R5 ABORT: raw write not allowed")
	DataStoreService:GetDataStore(op.resultsStore):SetAsync(r, tbl)
end

-- one-shot checks (reads only)
local okPre, preErr = pcall(function()
	assert(readRaw(op.resultsStore, role) == nil, "results for role " .. role .. " already exist")
	if role == "A" then
		assert(readRaw(op.store, op.keyHandover) == nil, "handover key already exists (another A ran)")
	end
end)
if not okPre then
	return refuse(tostring(preErr))
end

local identity = {
	role = role,
	placeId = game.PlaceId,
	gameId = game.GameId,
	jobId = game.JobId,
	privateServerId = game.PrivateServerId,
	privateServerOwnerId = game.PrivateServerOwnerId,
	isStudio = RunService:IsStudio(),
	uncachedReads = okOpts,
}

local onReady = nil
if role == "A" then
	-- move the second approved account into a new reserved server (server B), once
	onReady = function()
		local TeleportService = game:GetService("TeleportService")
		local first = nil
		local deadline = os.clock() + R5.TIMEOUTS.aWaitHandover
		while os.clock() < deadline do
			local present = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if allowed[p.UserId] then
					table.insert(present, p)
				end
			end
			if first == nil and #present >= 1 then
				first = present[1]
			end
			for _, p in ipairs(present) do
				if p ~= first then
					local okT, errT = pcall(function()
						local options = Instance.new("TeleportOptions")
						options.ShouldReserveServer = true -- a NEW reserved server of the same SaveTest place
						TeleportService:TeleportAsync(game.PlaceId, { p }, options)
					end)
					print("[R5] teleport of the second account to server B: ok=" .. tostring(okT) .. " " .. tostring(errT))
					return
				end
			end
			task.wait(1)
		end
		print("[R5] second account never joined server A")
	end
end

Guard.APPROVED.R5_CROSS_SERVER = true -- reset by R5.runRole on every exit path
print("[R5] authorized; role " .. role .. "; JobId " .. game.JobId)
local res = R5.runRole(role, {
	PS = R5.restrict(require(T.ProfileStore), op, role),
	readRaw = readRaw,
	writeResult = writeResult,
	identity = identity,
	onReady = onReady,
})
Guard.APPROVED.R5_CROSS_SERVER = false
print("[R5] role " .. role .. " finished: completedWithoutError=" .. tostring(res.completedWithoutError) .. " resultWritten=" .. tostring(res.resultWritten)
	.. " error=" .. tostring(res.error))
