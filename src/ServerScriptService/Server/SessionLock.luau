-- SessionLock (multi-ship phase 2): a save-session lock for moving players between servers (harbor <-> isle).
-- NOT WIRED into PlayerData. Production saving is unchanged. Tested only against a fake in-memory store.
--
-- The lock lives in the DataStore key's METADATA (UpdateAsync can return value, userIds, metadata), so the saved
-- profile itself never changes format. metadata.session = { token, job, at }:
--   * token : a unique fencing token per claim (GUID). Every write must present the current token.
--   * job   : the claiming server's JobId (for logs)
--   * at    : last heartbeat (os.time). A session older than staleSeconds may be taken over (crashed server).
--
-- Rules (auditor list, 2026-10-15; fixes 2026-10-16):
--   1. claim(): atomic in UpdateAsync. If another live session holds the key, the write is cancelled (nil) and
--      claim retries until waitSeconds, then fails (the caller keeps the player in memory-only mode).
--      A brand-new key (no stored value) is created with the caller's default profile: returning nil from the
--      transform would CANCEL the write, so the lock would never be stored (fix 1, 2026-10-16).
--   2. save(): atomic ownership check inside UpdateAsync; a stale or foreign token cancels the write.
--   3. heartbeat(): refreshes `at` even when the profile is unchanged (same ownership check).
--   4. Existing metadata fields and the key's UserIds are always carried over.
--   5. release(): an awaited final save that also clears the session. After it, this lock refuses to write.
--   6. reclaim after a failed teleport: claim() again; it succeeds at once because the key is free (or ours).
--   7. Per-key operations are serialized (one at a time, in call order), so PlayerRemoving, autosave and
--      release can never interleave inside one server.
--   8. Old servers (pre-lock code) write without metadata, which clears any session. The new owner's next write is
--      then fenced ("lock lost"). Production cutover must stop every old writer first (see the fix package).
--   9. Success is never inferred from pcall alone: every claim/save/release is confirmed against the metadata
--      UpdateAsync reports as COMMITTED (its second return, DataStoreKeyInfo). The transform may be re-invoked,
--      so it keeps no state between invocations except what it recomputes each time.

local HttpService = game:GetService("HttpService")

local SessionLock = {}
SessionLock.__index = SessionLock

-- opts: store (UpdateAsync-compatible), jobId, staleSeconds (120), waitSeconds (15), now (os.time), sleep (task.wait)
function SessionLock.new(opts)
	return setmetatable({
		store = opts.store,
		jobId = opts.jobId or game.JobId,
		staleSeconds = opts.staleSeconds or 120,
		waitSeconds = opts.waitSeconds or 15,
		now = opts.now or os.time,
		sleep = opts.sleep or task.wait,
		tokens = {}, -- key -> our current token (nil = not owned)
		queues = {}, -- key -> { busy = bool, waiting = { threads } }
	}, SessionLock)
end

local function copyMeta(keyInfo)
	local meta = {}
	if keyInfo then
		for k, v in keyInfo:GetMetadata() or {} do
			meta[k] = v
		end
	end
	return meta
end

local function userIdsOf(keyInfo)
	return if keyInfo then keyInfo:GetUserIds() else {}
end

-- the session token the store reports as committed (nil if none)
local function committedToken(keyInfo)
	local meta = keyInfo and keyInfo:GetMetadata()
	return meta and meta.session and meta.session.token
end

-- serialize every operation on one key
function SessionLock:_run(key, fn)
	local q = self.queues[key]
	if not q then
		q = { busy = false, waiting = {} }
		self.queues[key] = q
	end
	if q.busy then
		table.insert(q.waiting, coroutine.running())
		coroutine.yield()
	end
	q.busy = true
	local results = table.pack(pcall(fn))
	local nextThread = table.remove(q.waiting, 1)
	if nextThread then
		task.defer(nextThread) -- stays busy: ownership passes straight to the next waiter
	else
		q.busy = false
	end
	if not results[1] then
		return false, tostring(results[2])
	end
	return table.unpack(results, 2, results.n)
end

-- Returns ok, value (the stored profile, or the default written for a brand-new key), reason.
-- defaultValue: the profile to create when the key has no value yet (required for new players).
function SessionLock:claim(key, defaultValue)
	return self:_run(key, function()
		local started = self.now()
		local lastReason = "no attempt"
		local tried = {} -- every token this claim has tried: an attempt may have committed although it errored
		while true do
			local token = HttpService:GenerateGUID(false)
			tried[token] = true
			local busy, value = false, nil
			local ok, result, keyInfo = pcall(function()
				return self.store:UpdateAsync(key, function(current, info)
					busy, value = false, nil -- recomputed on every (re-)invocation
					local meta = copyMeta(info)
					local s = meta.session
					local mine = s ~= nil and (s.token == self.tokens[key] or tried[s.token] == true)
					if s ~= nil and not mine and type(s.at) == "number" and self.now() - s.at < self.staleSeconds then
						busy = true
						return nil -- another live session: cancel the write
					end
					local stored = if current ~= nil then current else defaultValue
					if stored == nil then
						return nil -- new key and no default profile: nothing may be written
					end
					meta.session = { token = token, job = self.jobId, at = self.now() }
					value = stored
					return stored, userIdsOf(info), meta
				end)
			end)
			if ok and not busy and committedToken(keyInfo) == token then
				self.tokens[key] = token
				return true, value, "claimed"
			end
			lastReason = if not ok then "store error: " .. tostring(result)
				elseif busy then "locked by another server"
				elseif value == nil then "no profile to create"
				else "lock not confirmed"
			if lastReason == "no profile to create" or self.now() - started >= self.waitSeconds then
				return false, nil, lastReason
			end
			self.sleep(1)
		end
	end)
end

-- shared body of save / heartbeat / release. newValue == nil keeps the stored value.
function SessionLock:_write(key, newValue, releaseAfter)
	local token = self.tokens[key]
	if token == nil then
		return false, "not owned"
	end
	local lost = false
	local ok, result, keyInfo = pcall(function()
		return self.store:UpdateAsync(key, function(current, info)
			lost = false -- recomputed on every (re-)invocation
			local meta = copyMeta(info)
			if current == nil or meta.session == nil or meta.session.token ~= token then
				lost = true
				return nil -- fenced: somebody else owns the key now (or it vanished)
			end
			meta.session = if releaseAfter then nil else { token = token, job = self.jobId, at = self.now() }
			local value = if newValue ~= nil then newValue else current
			return value, userIdsOf(info), meta
		end)
	end)
	if lost then
		self.tokens[key] = nil
		return false, "lock lost"
	end
	if not ok then
		return false, "store error: " .. tostring(result) -- still owned; the caller retries later
	end
	-- confirm what was committed, not just that the call returned
	local committed = committedToken(keyInfo)
	if releaseAfter then
		if keyInfo == nil or committed ~= nil then
			return false, "release not confirmed"
		end
		self.tokens[key] = nil
		return true, "released"
	end
	if committed ~= token then
		return false, "save not confirmed"
	end
	return true, "saved"
end

function SessionLock:save(key, value)
	return self:_run(key, function()
		return self:_write(key, value, false)
	end)
end

function SessionLock:heartbeat(key)
	return self:_run(key, function()
		return self:_write(key, nil, false)
	end)
end

-- awaited final save + release (before a teleport, or when the player leaves)
function SessionLock:release(key, value)
	return self:_run(key, function()
		return self:_write(key, value, true)
	end)
end

function SessionLock:owns(key)
	return self.tokens[key] ~= nil
end

return SessionLock
