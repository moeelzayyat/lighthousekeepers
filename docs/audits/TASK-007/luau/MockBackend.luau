-- ServerStorage.TestOnly.MockBackend
-- SAVETEST ONLY. In-memory fakes of DataStoreService, MessagingService and RunService, plus a loader that
-- runs the vendor ProfileStore SOURCE TEXT with `game` shadowed by a proxy. The real ModuleScript is never
-- required, so the real DataStoreService and its Studio probe write are never reached.
--
-- Nothing in the game requires this module. It makes no real DataStore or MessagingService call.

local MockBackend = {}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end
MockBackend.deepCopy = deepCopy

function MockBackend.newWorld()
	return {
		stores = {}, -- [storeName] = { data = { [key] = value }, versions = { [key] = n } }
		subscribers = {}, -- messaging subscribers
		published = {}, -- every PublishAsync (topic, data)
		writes = {}, -- every successful write { store, key, op }
		calls = {}, -- every datastore call { op, store, key }
		failures = {}, -- [op] = number of upcoming calls that must fail
		latency = 0, -- seconds added to every datastore call
		dropMessages = false, -- true = messaging delivers nothing (simulates an unresponsive holder)
	}
end

function MockBackend.seed(world, storeName, key, value)
	local s = world.stores[storeName]
	if s == nil then
		s = { data = {}, versions = {} }
		world.stores[storeName] = s
	end
	s.data[key] = deepCopy(value)
	s.versions[key] = (s.versions[key] or 0) + 1
end

function MockBackend.record(world, storeName, key)
	local s = world.stores[storeName]
	return s and s.data[key] or nil
end

local function keyInfoFor(version)
	return {
		Version = "mock." .. tostring(version),
		CreatedTime = 0,
		UpdatedTime = 0,
		GetMetadata = function()
			return {}
		end,
		GetUserIds = function()
			return {}
		end,
	}
end

local function newFakeStore(world, name)
	local backing = world.stores[name]
	if backing == nil then
		backing = { data = {}, versions = {} }
		world.stores[name] = backing
	end

	local function begin(op, key)
		table.insert(world.calls, { op = op, store = name, key = key })
		if world.latency and world.latency > 0 then
			task.wait(world.latency)
		end
		local n = world.failures[op]
		if n ~= nil and n > 0 then
			world.failures[op] = n - 1
			error("MOCK DataStore failure injected for " .. op)
		end
	end

	local store = {}

	function store:GetAsync(key)
		begin("GetAsync", key)
		local v = backing.data[key]
		if v == nil then
			return nil, nil
		end
		return deepCopy(v), keyInfoFor(backing.versions[key] or 0)
	end

	function store:UpdateAsync(key, transform)
		begin("UpdateAsync", key)
		local old = backing.data[key]
		local oldInfo = old ~= nil and keyInfoFor(backing.versions[key] or 0) or nil
		local new, userIds, meta = transform(deepCopy(old), oldInfo)
		if new == nil then
			return nil
		end
		backing.data[key] = deepCopy(new)
		backing.versions[key] = (backing.versions[key] or 0) + 1
		table.insert(world.writes, { store = name, key = key, op = "UpdateAsync" })
		return deepCopy(new), keyInfoFor(backing.versions[key])
	end

	function store:SetAsync(key, value)
		begin("SetAsync", key)
		backing.data[key] = deepCopy(value)
		backing.versions[key] = (backing.versions[key] or 0) + 1
		table.insert(world.writes, { store = name, key = key, op = "SetAsync" })
		return "mock." .. tostring(backing.versions[key])
	end

	function store:RemoveAsync(key)
		begin("RemoveAsync", key)
		local old = backing.data[key]
		backing.data[key] = nil
		table.insert(world.writes, { store = name, key = key, op = "RemoveAsync" })
		return deepCopy(old)
	end

	function store:GetVersionAsync()
		error("MOCK: GetVersionAsync is not supported")
	end

	function store:ListVersionsAsync()
		error("MOCK: ListVersionsAsync is not supported")
	end

	return store
end

function MockBackend.newDataStoreService(world)
	local service = {}
	function service:GetDataStore(name, scope, options)
		table.insert(world.calls, { op = "GetDataStore", store = name })
		return newFakeStore(world, name)
	end
	return service
end

function MockBackend.newMessagingService(world)
	local service = {}
	function service:SubscribeAsync(topic, callback)
		local sub = { topic = topic, callback = callback, connected = true }
		table.insert(world.subscribers, sub)
		return {
			Disconnect = function()
				sub.connected = false
			end,
		}
	end
	function service:PublishAsync(topic, data)
		table.insert(world.published, { topic = topic, data = deepCopy(data) })
		if world.dropMessages then
			return
		end
		for _, sub in ipairs(world.subscribers) do
			if sub.connected and sub.topic == topic then
				task.spawn(sub.callback, { Data = deepCopy(data), Sent = os.time() })
			end
		end
	end
	return service
end

local function newFakeRunService()
	local event = Instance.new("BindableEvent")
	local service = { Heartbeat = event.Event, _event = event }
	function service:IsStudio()
		return true
	end
	return service
end

-- identity = { PlaceId = number, JobId = string }; one identity = one logical "server".
function MockBackend.loadVendor(source, world, identity)
	assert(type(source) == "string" and #source > 1000, "vendor source missing")
	identity.closeCallbacks = identity.closeCallbacks or {}

	local realGame = game
	local realInstance = Instance
	local services = {
		DataStoreService = MockBackend.newDataStoreService(world),
		MessagingService = MockBackend.newMessagingService(world),
		RunService = newFakeRunService(),
	}

	local fakeGame = setmetatable({}, {
		__index = function(_, key)
			if key == "GetService" then
				return function(_, name)
					local fake = services[name]
					if fake ~= nil then
						return fake
					end
					return realGame:GetService(name)
				end
			elseif key == "PlaceId" then
				return identity.PlaceId
			elseif key == "JobId" then
				return identity.JobId
			elseif key == "BindToClose" then
				return function(_, fn)
					table.insert(identity.closeCallbacks, fn)
				end
			end
			local value = realGame[key]
			if type(value) == "function" then
				return function(_, ...)
					return realGame[key](realGame, ...)
				end
			end
			return value
		end,
	})

	local fakeInstance = {
		new = function(className, ...)
			if className == "DataStoreOptions" then
				local options = {}
				function options:SetExperimentalFeatures(features)
					identity.experimentalFeatures = deepCopy(features)
				end
				return options
			end
			return realInstance.new(className, ...)
		end,
	}

	local env = setmetatable({
		game = fakeGame,
		script = { Name = "ProfileStore" },
		Instance = fakeInstance,
	}, { __index = getfenv(1) })

	local chunk, err = loadstring(source, "=ProfileStore(vendor)")
	assert(chunk ~= nil, "vendor source failed to compile: " .. tostring(err))
	setfenv(chunk, env)
	local PS = chunk()

	return {
		PS = PS,
		identity = identity,
		services = services,
		destroy = function()
			services.RunService._event:Destroy()
		end,
	}
end

return MockBackend
