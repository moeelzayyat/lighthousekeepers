-- Main (client): the Keeper camera, aiming and beam keys, and weapon attacks.
-- The gameplay HUD (gauges, voyage status, prompts, boss bars, notices, pickups) lives in Hud.
-- Works with mouse (desktop) and touch (mobile).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local beamControl = remotes:WaitForChild("BeamControl")
local lampAction = remotes:WaitForChild("LampAction")
local notifyRemote = remotes:WaitForChild("Notify")
local attackRemote = remotes:WaitForChild("Attack")
local lootRemote = remotes:WaitForChild("LootCollected")

-- Tell the server what kind of device this is (for the playtest event log)
do
	local device = "Keyboard"
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		device = "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		device = "Gamepad"
	end
	remotes:WaitForChild("ReportDevice"):FireServer(device)
end

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local lampCore = Workspace:WaitForChild("Island"):WaitForChild("LampCore")

local GREEN = Color3.fromRGB(90, 200, 110)
local YELLOW = Color3.fromRGB(235, 200, 70)
local RED = Color3.fromRGB(220, 70, 60)

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "LighthouseHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- The gameplay HUD only shows once the player has pressed Play on the title screen
local function refreshHudVisible()
	gui.Enabled = player:GetAttribute("Ready") == true
end
player:GetAttributeChangedSignal("Ready"):Connect(refreshHudVisible)
refreshHudVisible()

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(name, size, position, textSize, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent or gui
	return label
end

local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

---------------------------------------------------------------------
-- Keeper mode: overhead camera + aim the beam at the pointer
---------------------------------------------------------------------

local isKeeper = false
local pendingAngle = nil
local lastSent = 0
local SEND_INTERVAL = 0.05
-- batch 1: controller aim (GP-44) and held-aim keep-alive (GP-3)
local lastAim = nil -- the last angle aimed by any input
local stickHeld = false -- a thumbstick is pushed past the dead zone
local heldTouches = {} -- touches currently aiming (not on a button)
local STICK_DEADZONE = 0.35
local HOLD_RESEND = 1 -- seconds: a held finger or stick re-sends its aim so the idle timer sees the Keeper

-- While at the lamp the Keeper can't walk (server sets WalkSpeed 0), so the movement controls
-- are hidden: on phones the joystick and jump button would otherwise sit under the aiming thumb.
local movementControls
task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local module = scripts and scripts:WaitForChild("PlayerModule", 10)
	if module then
		local ok, playerModule = pcall(require, module)
		if ok and playerModule then
			movementControls = playerModule:GetControls()
		end
	end
end)
local function setMovementControls(enabled)
	if movementControls then
		if enabled then
			movementControls:Enable()
		else
			movementControls:Disable()
		end
	end
	-- This place runs the engine's built-in controls (no PlayerModule in PlayerScripts), so the
	-- reliable switch is GuiService: it hides the phone joystick and jump button. Menus keep theirs off.
	pcall(function()
		game:GetService("GuiService").TouchControlsEnabled = enabled and not player:GetAttribute("MenuOpen")
	end)
end

local function enterKeeperView()
	setMovementControls(false)
	local lampPos = lampCore.Position
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt(lampPos + Vector3.new(0, 55, 100), Vector3.new(lampPos.X, 0, lampPos.Z - 15))
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = goal }):Play()
end

local function exitKeeperView()
	setMovementControls(true)
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function refreshKeeper()
	local nowKeeper = state:GetAttribute("KeeperUserId") == player.UserId
	if nowKeeper == isKeeper then
		return
	end
	isKeeper = nowKeeper
	if nowKeeper then
		enterKeeperView()
	else
		pendingAngle = nil
		lastAim = nil
		stickHeld = false
		heldTouches = {}
		exitKeeperView()
	end
end

-- Find where the pointer hits the sea plane (y = 0), and turn that into a beam angle
local function aimAt(screenPosition)
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return
	end
	local t = -ray.Origin.Y / ray.Direction.Y
	if t <= 0 then
		return
	end
	local hit = ray.Origin + ray.Direction * t
	local lampPos = lampCore.Position
	local dx = hit.X - lampPos.X
	local dz = hit.Z - lampPos.Z
	if dx * dx + dz * dz < 1 then
		return
	end
	-- The beam points along -Z at angle 0, so solve for the yaw that faces (dx, dz)
	pendingAngle = math.deg(math.atan2(-dx, -dz))
	lastAim = pendingAngle
end

local function isStick(input)
	return input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2
end

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not isKeeper then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		aimAt(input.Position)
	elseif input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
		aimAt(input.Position)
	elseif isStick(input) then
		-- Controller (batch 1): either stick aims; walking is off at the lamp. The Keeper camera looks
		-- toward -Z, so stick right = world +X and stick up = world -Z (same angle rule as aimAt).
		local x, y = input.Position.X, input.Position.Y
		if math.sqrt(x * x + y * y) >= STICK_DEADZONE then
			pendingAngle = math.deg(math.atan2(-x, y))
			lastAim = pendingAngle
			stickHeld = true
		else
			stickHeld = false
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isKeeper then
		return
	end
	local menuOpen = player:GetAttribute("MenuOpen") == true
	if input.UserInputType == Enum.UserInputType.Touch then
		heldTouches[input] = true
		aimAt(input.Position)
	elseif input.KeyCode == Enum.KeyCode.Q or (input.KeyCode == Enum.KeyCode.ButtonB and not menuOpen) then
		lampAction:FireServer("leave")
	elseif input.KeyCode == Enum.KeyCode.F or (input.KeyCode == Enum.KeyCode.ButtonY and not menuOpen) then
		lampAction:FireServer("toggleMode")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	heldTouches[input] = nil
	if isStick(input) then
		stickHeld = false
	end
end)

-- (the on-screen Focus / Leave buttons are drawn by Hud)

-- Send aim updates to the server at most 20 times per second. While a finger or stick is held still,
-- re-send the same aim once a second so the 25 s idle release (KEEPER_IDLE_SECONDS) does not fire (GP-3).
RunService.RenderStepped:Connect(function()
	if not isKeeper then
		return
	end
	if pendingAngle and os.clock() - lastSent >= SEND_INTERVAL then
		beamControl:FireServer(pendingAngle)
		pendingAngle = nil
		lastSent = os.clock()
	elseif lastAim and (stickHeld or next(heldTouches) ~= nil) and os.clock() - lastSent >= HOLD_RESEND then
		beamControl:FireServer(lastAim)
		lastSent = os.clock()
	end
end)

---------------------------------------------------------------------
-- Weapons: click (or tap) a creature while a weapon is equipped.
-- The server checks range, cooldown, and which weapon is really equipped.
---------------------------------------------------------------------

local mouse = player:GetMouse()

local function hookWeapon(child)
	if not child:IsA("Tool") or not child:GetAttribute("WeaponId") or child:GetAttribute("Hooked") then
		return
	end
	child:SetAttribute("Hooked", true)
	child.Activated:Connect(function()
		if isKeeper or player:GetAttribute("MenuOpen") then
			return -- no attacking while the Keeper, or while a menu is open
		end
		attackRemote:FireServer(mouse.Hit.Position)
	end)
end

local function onCharacter(character)
	character.ChildAdded:Connect(hookWeapon) -- equipped tools move into the character
	for _, child in character:GetChildren() do
		hookWeapon(child)
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

-- (Lightning, rain, clouds, and storm sounds live in the Storm script)

-- (the upgrade bench panel lives in Client.Bench since UI Stage 5)

---------------------------------------------------------------------
-- Wire up attribute listeners
---------------------------------------------------------------------

state.AttributeChanged:Connect(function(name)
	if name == "KeeperUserId" then
		refreshKeeper()
	end
end)

refreshKeeper()
