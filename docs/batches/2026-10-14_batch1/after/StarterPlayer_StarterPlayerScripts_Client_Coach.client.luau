-- Coach (client): in-play teaching and crew feedback.  Launch adaptation, Oct 12 2026.
--
--  1. Prompts (R3): short, action-triggered hints with the player's own input and a marker on the
--     thing to use. One at a time, highest priority first; each retires once the player does it.
--     Only for players with 0 completed runs (or unknown). Config.COACH_ENABLED switches it off.
--  2. Crew feed (R4): a capped line when someone refuels, saves the light, or the tower recovers,
--     plus a CLIENT-ONLY flare on the lamp. The flare is a local light: it changes no server beam,
--     range, damage or fuel value.
--  3. Lamp shift (R5): non-blocking cards for the dawn lamp offer. The server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundFx"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local C, F = UiKit.Color, UiKit.Font
local new, tween = UiKit.new, UiKit.tween

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local coachRemote = remotes:WaitForChild("CoachEvent")
local feedRemote = remotes:WaitForChild("CrewFeed")
local shiftRemote = remotes:WaitForChild("LampShift")
local island = Workspace:WaitForChild("Island")

local CHEAPEST_UPGRADE = 25 -- Shared.Upgrades: Fuel Tank / Walls level 1
local BIG_MONSTERS = { BarnacleBrute = true, ShipwreckHermit = true } -- CreatureService names models by kind

local gui = UiKit.Screen("Coach", 7)
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)

local function inputMode()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif UiKit.usingGamepad() then
		return "gamepad"
	end
	return "keyboard"
end

local function phone()
	return UiKit.Breakpoint(root.AbsoluteSize) == "phone"
end

-- Bottom HUD row top edge, so coach elements never sit on top of it
local cachedKeeperRow -- found once, not searched through ~2000 GUI objects every 0.4 s
local function hudFloor()
	if not (cachedKeeperRow and cachedKeeperRow.Parent) then
		local pg = player:FindFirstChild("PlayerGui")
		cachedKeeperRow = pg and pg:FindFirstChild("KeeperControls", true)
	end
	local keeperRow = cachedKeeperRow
	local bottom = keeperRow and keeperRow.Parent
	if bottom and bottom:IsA("GuiObject") and bottom.AbsoluteSize.Y > 0 then
		return bottom.AbsolutePosition.Y - root.AbsolutePosition.Y
	end
	return root.AbsoluteSize.Y * 0.8
end

---------------------------------------------------------------------
-- 1. PROMPTS
---------------------------------------------------------------------

local chip = new("Frame", {
	Name = "Prompt",
	BackgroundColor3 = C.SurfacePrimary,
	BackgroundTransparency = 0.06,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.75),
	Size = UDim2.fromOffset(0, 56),
	AutomaticSize = Enum.AutomaticSize.X,
	Visible = false,
}, root)
UiKit.round(chip, UiKit.Radius.panel)
UiKit.border(chip, C.AccentLighthouse, 1.5, 0.15)
UiKit.pad(chip, 0, 18, 0, 12)
UiKit.list(chip, "x", 12, { VerticalAlignment = Enum.VerticalAlignment.Center })
local chipIcon = new("Frame", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = 1 }, chip)
local chipText = UiKit.Label(chip, "", "H3", {
	Name = "Text",
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 56),
	AutomaticSize = Enum.AutomaticSize.X,
	TextWrapped = false,
	TextYAlignment = Enum.TextYAlignment.Center,
})
local chipKey = new("Frame", { Name = "Key", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 56), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3 }, chip)
UiKit.list(chipKey, "x", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })

-- world marker: a small lamp-gold chevron above the thing to use
local marker = new("BillboardGui", {
	Name = "CoachMarker",
	AlwaysOnTop = true,
	LightInfluence = 0,
	Size = UDim2.fromOffset(44, 44),
	StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
	Enabled = false,
}, gui)
local markerDot = new("Frame", {
	BackgroundColor3 = C.SurfaceBase,
	BackgroundTransparency = 0.2,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(40, 40),
}, marker)
UiKit.round(markerDot, 20)
UiKit.border(markerDot, C.AccentLighthouse, 2, 0)
local markerGlyph = UiKit.Glyph(markerDot, "next", C.AccentLighthouse, 18)
markerGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
markerGlyph.Position = UDim2.fromScale(0.5, 0.55)
markerGlyph.Rotation = 90 -- points down at the target

local function findTarget(name)
	return island:FindFirstChild(name, true)
end
local function partOf(inst)
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function fuelRatio()
	return (state:GetAttribute("Fuel") or 100) / math.max(1, state:GetAttribute("MaxFuel") or 100)
end
local function towerRatio()
	return (state:GetAttribute("Integrity") or 100) / math.max(1, state:GetAttribute("MaxIntegrity") or 100)
end
local function isKeeper()
	return state:GetAttribute("KeeperUserId") == player.UserId
end
local function inRun()
	local phase = state:GetAttribute("Phase")
	return player:GetAttribute("Ready") == true and (phase == "Prologue" or phase == "Day" or phase == "Night")
end
local function creaturesOut()
	local folder = island:FindFirstChild("Creatures")
	return folder ~= nil and #folder:GetChildren() > 0
end
local function bigMonsterOut()
	local folder = island:FindFirstChild("Creatures")
	if not folder then
		return false
	end
	for _, c in folder:GetChildren() do
		if BIG_MONSTERS[c.Name] then
			return true
		end
	end
	return state:GetAttribute("BigWarning") == true
end

local X = Enum.KeyCode.ButtonX
-- priority = order. keys: keyboard / touch / gamepad (nil = no hint on that input)
local PROMPTS = {
	{
		id = "tank",
		icon = "lamp",
		text = "Pour the oil in the fuel tank",
		keys = { keyboard = "E", touch = "Tap", gamepad = X },
		target = "FuelTank",
		when = function()
			return player:GetAttribute("CarryingOil") == true
		end,
	},
	{
		id = "oil",
		icon = "lamp",
		text = "Grab oil for the lamp",
		keys = { keyboard = "E", touch = "Tap", gamepad = X },
		target = "OilPile",
		when = function()
			return not isKeeper() and player:GetAttribute("CarryingOil") ~= true and fuelRatio() < 0.35
		end,
	},
	{
		id = "focus",
		icon = "danger",
		text = "Big one! Focus burns it — uses fuel fast",
		keys = { keyboard = "F", touch = "Focus", gamepad = Enum.KeyCode.ButtonY }, -- batch 1: controller hint
		when = function()
			return isKeeper() and bigMonsterOut() and state:GetAttribute("BeamMode") ~= "focused"
		end,
	},
	{
		id = "aim",
		icon = "lamp",
		text = "Aim the light at the crabs",
		keys = { keyboard = "Mouse", touch = "Drag", gamepad = Enum.KeyCode.Thumbstick1 }, -- batch 1: controller hint
		when = function()
			return isKeeper() and creaturesOut()
		end,
	},
	{
		id = "repair",
		icon = "tower",
		text = "The tower is cracking — repair it",
		keys = { keyboard = "E", touch = "Hold", gamepad = X },
		target = "TowerDoor",
		when = function()
			return not isKeeper() and towerRatio() < 0.6
		end,
	},
	{
		id = "lamp",
		icon = "lamp",
		text = "Nobody's at the lamp — take it",
		keys = { keyboard = "E", touch = "Tap", gamepad = X },
		target = "LampConsole",
		when = function()
			return (state:GetAttribute("KeeperUserId") or 0) == 0 and creaturesOut() and fuelRatio() > 0.1
		end,
	},
	{
		id = "bench",
		icon = "plus",
		text = "Spend Shells at the bench before night",
		keys = { keyboard = "E", touch = "Tap", gamepad = X },
		target = "UpgradeBench",
		when = function()
			return Config.ECONOMY_ENABLED and state:GetAttribute("Phase") == "Day" and (state:GetAttribute("Shells") or 0) >= CHEAPEST_UPGRADE
		end,
	},
}

local retired = {} -- id -> true once done (or shown too often)
local shownCount = {}
local current -- prompt table on screen
local currentSince = 0
local aimInputs = 0

local function report(kind, id)
	coachRemote:FireServer(kind, id)
end

local function eligible()
	if not Config.COACH_ENABLED then
		return false
	end
	local runs = player:GetAttribute("RunsCompleted")
	return runs == nil or runs <= 0 -- unknown (failed load) or a first voyage
end

local function setKeyHint(prompt)
	for _, child in chipKey:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local mode = inputMode()
	if prompt.keys[mode] then
		UiKit.KeyHint(chipKey, prompt.keys, "", { input = mode })
	end
end

local function show(prompt)
	current = prompt
	currentSince = os.clock()
	for _, child in chipIcon:GetChildren() do
		child:Destroy()
	end
	local g = UiKit.Glyph(chipIcon, prompt.icon, C.AccentLighthouse, 24)
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	chipText.Text = prompt.text
	setKeyHint(prompt)
	chip:SetAttribute("RestPosition", chip.Position) -- the chip moves with the HUD; open from where it is now
	chip.Visible = true
	UiKit.Open(chip)
	local part = prompt.target and partOf(findTarget(prompt.target))
	marker.Adornee = part
	marker.Enabled = part ~= nil
	shownCount[prompt.id] = (shownCount[prompt.id] or 0) + 1
	if shownCount[prompt.id] == 1 then
		report("shown", prompt.id)
	end
end

local function hide()
	current = nil
	marker.Enabled = false
	if chip.Visible then
		UiKit.Close(chip)
	end
end

local function retire(id)
	if retired[id] then
		return
	end
	retired[id] = true
	if (shownCount[id] or 0) > 0 then
		report("done", id) -- telemetry counts prompts done out of prompts actually shown
	end
	if current and current.id == id then
		hide()
	end
end

-- What counts as "doing it" (watched outside the prompt so it also retires unseen prompts)
local lastCarrying = player:GetAttribute("CarryingOil") == true
player:GetAttributeChangedSignal("CarryingOil"):Connect(function()
	local carrying = player:GetAttribute("CarryingOil") == true
	if carrying then
		retire("oil")
	elseif lastCarrying and inRun() then
		retire("tank") -- carried oil went into the tank (or was dropped by leaving: still learned)
	end
	lastCarrying = carrying
end)
state:GetAttributeChangedSignal("KeeperUserId"):Connect(function()
	if isKeeper() then
		retire("lamp")
	end
end)
state:GetAttributeChangedSignal("BeamMode"):Connect(function()
	if isKeeper() and state:GetAttribute("BeamMode") == "focused" then
		retire("focus")
	end
end)
local lastIntegrity = state:GetAttribute("Integrity") or 0
state:GetAttributeChangedSignal("Integrity"):Connect(function()
	local now = state:GetAttribute("Integrity") or 0
	if now > lastIntegrity and towerRatio() < 1 and current and current.id == "repair" then
		retire("repair")
	end
	lastIntegrity = now
end)
local lastShells = state:GetAttribute("Shells") or 0
state:GetAttributeChangedSignal("Shells"):Connect(function()
	local now = state:GetAttribute("Shells") or 0
	if now < lastShells and state:GetAttribute("Phase") == "Day" then
		retire("bench")
	end
	lastShells = now
end)
UserInputService.InputChanged:Connect(function(input)
	if isKeeper() and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		aimInputs += 1
		if aimInputs > 40 and current and current.id == "aim" and os.clock() - currentSince > 2.5 then
			retire("aim")
		end
	end
end)
UserInputService.LastInputTypeChanged:Connect(function()
	if current then
		setKeyHint(current)
	end
end)

local function choose()
	if not eligible() or not inRun() or player:GetAttribute("MenuOpen") then
		return nil
	end
	for _, prompt in PROMPTS do
		if not retired[prompt.id] and (shownCount[prompt.id] or 0) < 4 and prompt.when() then
			return prompt
		end
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.4)
		local want = choose()
		if want ~= current then
			-- don't flicker: keep a prompt at least 2.5 s unless its own condition ended
			if current and want and os.clock() - currentSince < 2.5 and current.when() then
				continue
			end
			if current then
				hide()
				task.wait(UiKit.Motion.fast)
			end
			if want then
				show(want)
			end
		end
		-- stay above the bottom HUD row
		local floorY = hudFloor()
		chip.Position = UDim2.new(0.5, 0, 0, math.floor(math.min(floorY - 14, root.AbsoluteSize.Y * 0.8)))
		chipText.TextSize = if phone() then 16 else 18
	end
end)

---------------------------------------------------------------------
-- 2. CREW FEED + client-only lamp flare
---------------------------------------------------------------------

local feed = new("Frame", {
	Name = "CrewFeed",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.42, 0),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, root)
UiKit.list(feed, "y", 6)
local FEED_GAP = 3 -- seconds between lines
local FEED_MAX = 3
local lastLineAt = 0
local queue = {}
local order = 0

local function feedLine(text, color)
	order += 1
	local line = new("Frame", {
		Name = "Line",
		BackgroundColor3 = C.SurfacePrimary,
		BackgroundTransparency = 0.12,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, feed)
	UiKit.round(line, UiKit.Radius.card)
	new("Frame", { Name = "Stripe", BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) }, line)
	local label = UiKit.Label(line, text, "BodySmall", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -18, 0, 0), TextColor3 = C.TextPrimary })
	UiKit.pad(label, 7, 0, 7, 0)
	local lines = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	if #lines > FEED_MAX then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(5, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

local function enqueue(key, text, color)
	for _, item in queue do
		if item.key == key then
			item.count += 1 -- merge repeats
			return
		end
	end
	table.insert(queue, { key = key, text = text, color = color, count = 1 })
end

task.spawn(function()
	while true do
		task.wait(0.25)
		if #queue > 0 and os.clock() - lastLineAt >= FEED_GAP then
			local item = table.remove(queue, 1)
			lastLineAt = os.clock()
			feedLine(if item.count > 1 then item.text .. "  ×" .. item.count else item.text, item.color)
		end
	end
end)

local flaring = false
local function flare(strong)
	local core = island:FindFirstChild("LampCore")
	if not core or flaring then
		return
	end
	flaring = true
	-- local-only light: other players and the server never see or use it
	local light = new("PointLight", {
		Name = "CoachFlare",
		Color = Color3.fromRGB(255, 226, 150),
		Brightness = 0,
		Range = if strong then 40 else 28,
		Shadows = false,
	}, core)
	tween(light, 0.25, { Brightness = if strong then 6 else 3.5 })
	task.delay(0.4, function()
		tween(light, 1.1, { Brightness = 0 })
		task.wait(1.15)
		light:Destroy()
		flaring = false
	end)
end

feedRemote.OnClientEvent:Connect(function(event)
	if not Config.CREW_FEED_ENABLED or typeof(event) ~= "table" then
		return
	end
	local who = if event.self then "You" else tostring(event.name)
	if event.kind == "clutch" then
		enqueue("clutch" .. who, who .. " saved the light!", C.AccentLighthouse)
		flare(true)
		SoundFx.play2D("refuel", 1.15)
	elseif event.kind == "refuel" then
		enqueue("refuel" .. who, string.format("%s refueled the light (+%d%%)", who, tonumber(event.amount) or 0), C.AccentLighthouseSoft)
		flare(false)
	end
end)

-- the tower recovering from critical (watched locally from the shared Integrity value)
local towerCritical = false
state:GetAttributeChangedSignal("Integrity"):Connect(function()
	if not Config.CREW_FEED_ENABLED or not inRun() then
		return
	end
	local r = towerRatio()
	if r < 0.3 then
		towerCritical = true
	elseif towerCritical and r >= 0.5 then
		towerCritical = false
		enqueue("tower", "The tower is holding again", C.StateSuccess)
	end
end)

---------------------------------------------------------------------
-- 3. LAMP SHIFT cards (non-blocking; the server validates every answer)
---------------------------------------------------------------------

local shiftCard
local function closeShift()
	if shiftCard then
		shiftCard:Destroy()
		shiftCard = nil
	end
end

local function shiftPanel(title, body, yesText, noText, onAnswer, seconds)
	closeShift()
	local card = new("Frame", {
		Name = "LampShift",
		BackgroundColor3 = C.SurfacePrimary,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, if phone() then 70 else 120),
		Size = UDim2.fromOffset(if phone() then 280 else 330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, root)
	UiKit.round(card, UiKit.Radius.panel)
	UiKit.border(card, C.AccentLighthouse, 1.5, 0.15)
	UiKit.pad(card, 14, 14, 14, 14)
	UiKit.list(card, "y", 8)
	UiKit.Label(card, "Lamp shift", "Eyebrow", { LayoutOrder = 1 })
	UiKit.Label(card, title, "H3", { LayoutOrder = 2 })
	if body then
		UiKit.Label(card, body, "BodySmall", { LayoutOrder = 3 })
	end
	if onAnswer then
		local row = new("Frame", { Name = "Actions", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 4 }, card)
		UiKit.list(row, "x", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
		local no = UiKit.Button(row, noText, { name = "No", variant = "secondary", size = "sm", minWidth = 90, layoutOrder = 1 })
		local yes = UiKit.Button(row, yesText, { name = "Yes", variant = "primary", size = "sm", minWidth = 110, layoutOrder = 2 })
		yes.Activated:Connect(function()
			onAnswer(true)
			closeShift()
		end)
		no.Activated:Connect(function()
			onAnswer(false)
			closeShift()
		end)
	end
	shiftCard = card
	local mine = card
	task.delay(seconds or 8, function()
		if shiftCard == mine then
			closeShift()
		end
	end)
end

shiftRemote.OnClientEvent:Connect(function(event)
	if typeof(event) ~= "table" then
		return
	end
	if event.kind == "ask" then
		shiftPanel("Offer the lamp to " .. tostring(event.name) .. "?", "They haven't had a turn this voyage.", "Offer", "Keep it", function(yes)
			shiftRemote:FireServer(event.id, yes)
		end, event.seconds)
	elseif event.kind == "offer" then
		shiftPanel(tostring(event.name) .. " offers you the lamp", "Take a turn as Keeper?", "Take it", "Not now", function(yes)
			shiftRemote:FireServer(event.id, yes)
		end, event.seconds)
	elseif event.kind == "nudge" then
		shiftPanel("The lamp is free", "Take a turn at the lamp console.", nil, nil, nil, 7)
	elseif event.kind == "done" then
		shiftPanel(tostring(event.name) .. " has the lamp now", nil, nil, nil, nil, 4)
	elseif event.kind == "cancel" then
		closeShift()
	end
end)

-- leaving the run clears coach UI
player:GetAttributeChangedSignal("Ready"):Connect(function()
	if not player:GetAttribute("Ready") then
		hide()
		closeShift()
		table.clear(queue)
	end
end)

---------------------------------------------------------------------
-- STUDIO ONLY: simulated screen sizes (HudSimulate attribute)
---------------------------------------------------------------------

if RunService:IsStudio() then
	local SIZES = {
		smallPhone = Vector2.new(667, 375),
		largePhone = Vector2.new(932, 430),
		tablet = Vector2.new(1180, 820),
		laptop = Vector2.new(1366, 768),
	}
	local function applySimulation()
		local spec = SIZES[player:GetAttribute("HudSimulate") or ""]
		if spec then
			root.AnchorPoint = Vector2.new(0.5, 0.5)
			root.Position = UDim2.fromScale(0.5, 0.5)
			root.Size = UDim2.fromOffset(spec.X, spec.Y)
		else
			root.AnchorPoint = Vector2.zero
			root.Position = UDim2.new()
			root.Size = UDim2.fromScale(1, 1)
		end
	end
	player:GetAttributeChangedSignal("HudSimulate"):Connect(applySimulation)
	applySimulation()
end
