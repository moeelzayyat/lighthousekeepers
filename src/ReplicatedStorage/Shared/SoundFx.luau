-- SoundFx: every gameplay sound effect in one place.
-- Change an ID, volume, or pitch here and it changes everywhere.
--
--   SoundFx.playAt(name, position)  3D sound at a point. Called on the server, it tells every
--                                  client to play it locally (reliable and costs the server nothing).
--   SoundFx.play2D(name, pitch)     sound only this player hears, no position (client only)

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

local SoundFx = {}

-- Volume groups the Settings menu controls: "SFX" (gameplay sounds) and "Ambience" (storm, waves)
function SoundFx.getGroup(name)
	local group = SoundService:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Volume = 1
		group.Parent = SoundService
	end
	return group
end

-- Distance fade: full volume within ROLLOFF_MIN studs, fading out by ROLLOFF_MAX
local ROLLOFF_MIN = 50
local ROLLOFF_MAX = 450

-- volume, playback speed (pitch). Built-in rbxasset sounds ship with Roblox and never get removed.
SoundFx.SOUNDS = {
	throw = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.6, speed = 1.1 },
	hit = { id = "rbxasset://sounds/hit.wav", volume = 0.5, speed = 1.0 },
	crabDeath = { id = "rbxasset://sounds/splat.wav", volume = 0.7, speed = 0.9 },
	cannon = { id = "rbxassetid://9114361763", volume = 0.45, speed = 1.35 },
	cannonImpact = { id = "rbxasset://sounds/bass.wav", volume = 0.6, speed = 1.2 },
	build = { id = "rbxasset://sounds/snap.wav", volume = 0.8, speed = 0.8 },
	refuel = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.6, speed = 1.3 },
	repair = { id = "rbxasset://sounds/snap.wav", volume = 0.7, speed = 1.2 },
	loot = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, speed = 1.0 },
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, speed = 1.0 },
	denied = { id = "rbxasset://sounds/button.wav", volume = 0.5, speed = 0.7 },
	monster = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.9, speed = 0.45 }, -- deep roar when a big monster arrives
}

local function makeSound(name)
	local info = SoundFx.SOUNDS[name]
	if not info then
		warn("SoundFx: unknown sound " .. tostring(name))
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = info.id
	sound.Volume = info.volume
	if not IS_SERVER then
		sound.SoundGroup = SoundFx.getGroup("SFX")
	end
	sound.PlaybackSpeed = info.speed * (0.95 + math.random() * 0.1) -- slight variation so repeats don't sound robotic
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = ROLLOFF_MIN
	sound.RollOffMaxDistance = ROLLOFF_MAX
	return sound
end

local function playLocalAt(name, position)
	local sound = makeSound(name)
	if not sound then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SoundAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace
	sound.Parent = anchor
	if sound.IsLoaded then
		sound:Play()
	else
		-- First use before the download finished: play as soon as it's ready
		task.spawn(function()
			local waited = 0
			while not sound.IsLoaded and waited < 2 do
				waited += task.wait()
			end
			if sound.Parent then
				sound:Play()
			end
		end)
	end
	Debris:AddItem(anchor, 8)
end

local remote -- Remotes.PlaySound, found when first needed
local function getRemote()
	if not remote then
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlaySound")
	end
	return remote
end

function SoundFx.playAt(name, position)
	if IS_SERVER then
		getRemote():FireAllClients(name, position)
	else
		playLocalAt(name, position)
	end
end

-- Kept for older calls: plays at the part's current position
function SoundFx.playOn(name, part)
	SoundFx.playAt(name, part.Position)
end

-- Clients listen for sounds the server asks them to play, and download every sound up front
if not IS_SERVER then
	task.spawn(function()
		local preload = {}
		for _, info in SoundFx.SOUNDS do
			local sound = Instance.new("Sound")
			sound.SoundId = info.id
			table.insert(preload, sound)
		end
		game:GetService("ContentProvider"):PreloadAsync(preload)
	end)
	task.spawn(function()
		getRemote().OnClientEvent:Connect(function(name, position)
			if typeof(name) == "string" and typeof(position) == "Vector3" then
				playLocalAt(name, position)
			end
		end)
	end)
end

function SoundFx.play2D(name, pitch)
	local sound = makeSound(name)
	if not sound then
		return
	end
	sound.PlaybackSpeed *= pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

return SoundFx
