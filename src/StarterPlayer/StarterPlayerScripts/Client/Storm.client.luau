-- Storm (client): rain, storm clouds, ambient sound, lightning and thunder.
-- Purely visual/audio and runs on each player's device, so it costs the server nothing.
-- The storm is on during the opening incident and at night; calm during the day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local state = ReplicatedStorage:WaitForChild("GameState")
local camera = Workspace.CurrentCamera
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local localPlayer = game:GetService("Players").LocalPlayer

-- Sounds (free Creator Store audio; swap the IDs here to change them)
local SOUND_IDS = {
	waves = "rbxassetid://3159087887",
	wind = "rbxassetid://9120610116",
	rain = "rbxassetid://365362615",
	thunder = { "rbxassetid://9120016241", "rbxassetid://9120016037", "rbxassetid://9120016256" },
}

local function makeSound(name, id, looped)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = 0
	sound.SoundGroup = SoundFx.getGroup("Ambience")
	sound.Parent = SoundService
	return sound
end

local waves = makeSound("StormWaves", SOUND_IDS.waves, true)
local wind = makeSound("StormWind", SOUND_IDS.wind, true)
local rain = makeSound("StormRain", SOUND_IDS.rain, true)
waves:Play()
wind:Play()
rain:Play()

local thunderSounds = {}
for index, id in SOUND_IDS.thunder do
	thunderSounds[index] = makeSound("Thunder" .. index, id, false)
	thunderSounds[index].Volume = 0.7
end

---------------------------------------------------------------------
-- Rain: an invisible box above the camera that emits stretched raindrops
---------------------------------------------------------------------

local rainBox = Instance.new("Part")
rainBox.Name = "RainEmitter"
rainBox.Size = Vector3.new(140, 1, 140)
rainBox.Transparency = 1
rainBox.Anchored = true
rainBox.CanCollide = false
rainBox.CanQuery = false
rainBox.CanTouch = false
rainBox.Parent = Workspace

local drops = Instance.new("ParticleEmitter")
drops.Name = "Rain"
drops.Shape = Enum.ParticleEmitterShape.Box
drops.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
drops.EmissionDirection = Enum.NormalId.Bottom
drops.Orientation = Enum.ParticleOrientation.VelocityParallel
drops.Speed = NumberRange.new(90, 110)
drops.Lifetime = NumberRange.new(0.6, 0.8)
drops.Size = NumberSequence.new(0.12)
drops.Squash = NumberSequence.new(4) -- stretches each drop into a streak
drops.Transparency = NumberSequence.new(0.45)
drops.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
drops.LightEmission = 0.2
drops.Acceleration = Vector3.new(6, 0, 3) -- a little wind slant
drops.Rate = 0
drops.Parent = rainBox

RunService.RenderStepped:Connect(function()
	local position = camera.CFrame.Position
	rainBox.CFrame = CFrame.new(position.X, position.Y + 45, position.Z)
end)

---------------------------------------------------------------------
-- Clouds
---------------------------------------------------------------------

local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Parent = Workspace.Terrain

local CALM = {
	clouds = { Cover = 0.55, Density = 0.35, Color = Color3.fromRGB(235, 238, 245) },
	volumes = { waves = 0.45, wind = 0, rain = 0 },
	rainRate = 0,
}
local STORM = {
	clouds = { Cover = 0.88, Density = 0.75, Color = Color3.fromRGB(60, 66, 80) },
	volumes = { waves = 0.25, wind = 0.35, rain = 0.5 },
	rainRate = 900,
}

local stormy = nil
local function setStorm(on)
	if stormy == on then
		return
	end
	stormy = on
	local preset = if on then STORM else CALM
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine)
	TweenService:Create(clouds, info, preset.clouds):Play()
	TweenService:Create(waves, info, { Volume = preset.volumes.waves }):Play()
	TweenService:Create(wind, info, { Volume = preset.volumes.wind }):Play()
	TweenService:Create(rain, info, { Volume = preset.volumes.rain }):Play()
	-- "Low effects" (Settings menu) turns off the rain particles for weaker phones.
	-- Phones and tablets get a lighter storm by default (about a third of the drops, slightly bigger so it
	-- still reads as heavy rain): 900 drops/s was the heaviest thing on screen for mobile GPUs (Oct 12).
	local touch = game:GetService("UserInputService").TouchEnabled
	drops.Size = NumberSequence.new(if touch then 0.16 else 0.12)
	drops.Rate = if localPlayer:GetAttribute("LowEffects") then 0 elseif touch then math.floor(preset.rainRate * 0.35) else preset.rainRate
end

localPlayer:GetAttributeChangedSignal("LowEffects"):Connect(function()
	local current = stormy
	stormy = nil
	setStorm(current)
end)

-- the storm (rain, thunder) is on the lighthouse island: only the voyage crew is in it, not the harbor
local function refresh()
	local phase = state:GetAttribute("Phase")
	setStorm((phase == "Night" or phase == "Prologue") and localPlayer:GetAttribute("Ready") == true)
end
state:GetAttributeChangedSignal("Phase"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("Ready"):Connect(refresh)
refresh()

---------------------------------------------------------------------
-- Focused-beam laser hum: plays from the lamp while the focused beam is on
---------------------------------------------------------------------

task.spawn(function()
	local lampCore = Workspace:WaitForChild("Island"):WaitForChild("LampCore")
	local laser = Instance.new("Sound")
	laser.Name = "FocusedBeamHum"
	laser.SoundId = "rbxassetid://9126086336" -- Pro Sound Effects: pulsing energy tone
	laser.Looped = true
	laser.Volume = 0
	laser.PlaybackSpeed = 1.25
	laser.RollOffMode = Enum.RollOffMode.InverseTapered
	laser.RollOffMinDistance = 60
	laser.RollOffMaxDistance = 500
	laser.SoundGroup = SoundFx.getGroup("SFX")
	laser.Parent = lampCore

	local on = false
	local function refresh()
		local focused = state:GetAttribute("BeamMode") == "focused"
			and (state:GetAttribute("Fuel") or 0) > 0
			and (state:GetAttribute("KeeperUserId") or 0) ~= 0
			and localPlayer:GetAttribute("Ready") == true -- the island lamp is heard by the voyage crew only
		if focused == on then
			return
		end
		on = focused
		if on then
			if not laser.IsPlaying then
				laser:Play()
			end
			TweenService:Create(laser, TweenInfo.new(0.25), { Volume = 0.6 }):Play()
		else
			local fade = TweenService:Create(laser, TweenInfo.new(0.35), { Volume = 0 })
			fade.Completed:Connect(function()
				if not on then
					laser:Stop()
				end
			end)
			fade:Play()
		end
	end
	for _, attribute in { "BeamMode", "Fuel", "KeeperUserId" } do
		state:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	localPlayer:GetAttributeChangedSignal("Ready"):Connect(refresh)
	refresh()
end)

---------------------------------------------------------------------
-- Lightning: a double flash, then thunder a moment later (sound travels slower than light)
---------------------------------------------------------------------

local function flash()
	Lighting.ExposureCompensation = 1.6
	TweenService:Create(Lighting, TweenInfo.new(0.12), { ExposureCompensation = 0 }):Play()
	task.wait(0.18)
	Lighting.ExposureCompensation = 1.1
	TweenService:Create(Lighting, TweenInfo.new(0.4), { ExposureCompensation = 0 }):Play()
end

task.spawn(function()
	while true do
		task.wait(math.random(7, 16))
		if stormy then
			task.spawn(flash)
			local thunder = thunderSounds[math.random(1, #thunderSounds)]
			task.delay(math.random(3, 15) / 10, function()
				thunder.PlaybackSpeed = math.random(90, 110) / 100
				thunder:Play()
			end)
		end
	end
end)
