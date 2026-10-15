-- Bench (client): the in-run UPGRADE BENCH, a rushed field workshop.
--
-- Shells only (the crew's shared pool, reset every voyage). No Pearls here, ever.
-- The server opens it (OpenUpgrades, from the bench prompt) and validates every purchase
-- (BuyUpgrade -> UpgradeResult). Upgrade values and prices come from Shared/Upgrades unchanged.
--
-- Built on UiKit v2.1 (Stage 5 of the UI redesign). Deliberately faster and plainer than the
-- Quartermaster: docked to the side so the storm stays visible, one tap (or key 1-4) per upgrade,
-- inline confirmation on the row, no dialogs.
-- Studio only: player attribute HudSimulate draws it inside a simulated screen size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local SoundFx = require(Shared:WaitForChild("SoundFx"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Vitals = require(script.Parent:WaitForChild("Vitals"))

local C, F = UiKit.Color, UiKit.Font
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local state = ReplicatedStorage:WaitForChild("GameState")
local player = Players.LocalPlayer

local REQUEST_TIMEOUT = 6
local WALK_AWAY = 16

-- What each upgrade does right now, in the player's words (presentation only)
local BENEFIT = {
	LensPower = { label = "Beam damage", base = 1, fmt = function(v) return math.floor(v * 100 + 0.5) .. "%" end },
	FuelTank = { label = "Max fuel", base = Config.MAX_FUEL, fmt = tostring, extra = "refills 30" },
	Walls = { label = "Tower strength", base = Config.MAX_INTEGRITY, fmt = tostring, extra = "repairs 50" },
	ClockworkSweep = { label = "Auto-sweep damage", base = 0, fmt = function(v) return v .. "/s" end },
}

local isOpen = false
local mode = "desktop"
local pendingId, pendingUpgrade, pendingStarted = nil, nil, 0
local rows = {}
local layout, closeBench -- forward declarations

local function shells()
	return state:GetAttribute("Shells") or 0
end
local function levelOf(id)
	return state:GetAttribute("Upgrade_" .. id) or 0
end
local function hex(color)
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

---------------------------------------------------------------------
-- SCREEN
---------------------------------------------------------------------

local gui = UiKit.Screen("UpgradeBench", 18)
gui.Enabled = false
local root = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local rootOutline = UiKit.border(root, C.BorderFocus, 1, 0.4)
rootOutline.Enabled = false

local panel = UiKit.Panel(root, { name = "Workshop", kind = "plain", variant = "primary", padding = 0, anchor = Vector2.new(1, 0) })
panel.ClipsDescendants = true
UiKit.border(panel, C.StateWarning, 1, 0.55)

-- hazard tape along the top edge: rust and dark diagonal stripes (cells split on the diagonal)
local tape = UiKit.new("Frame", { Name = "HazardTape", BackgroundColor3 = C.SurfaceBase, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8), ClipsDescendants = true, ZIndex = 3 }, panel)
for i = 0, 79 do
	local cell = UiKit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(i * 8, 0), Size = UDim2.fromOffset(8, 8), ZIndex = 3 }, tape)
	UiKit.new("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.StateWarning),
			ColorSequenceKeypoint.new(0.499, C.StateWarning),
			ColorSequenceKeypoint.new(0.5, C.SurfaceBase),
			ColorSequenceKeypoint.new(1, C.SurfaceBase),
		}),
	}, cell)
end

-- header ------------------------------------------------------------
local header = UiKit.new("Frame", { Name = "Header", BackgroundTransparency = 1 }, panel)
local titleBlock = UiKit.new("Frame", { Name = "TitleBlock", BackgroundTransparency = 1, Size = UDim2.new(0.55, 0, 1, 0) }, header)
UiKit.list(titleBlock, "y", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
local eyebrow = UiKit.Label(titleBlock, "Field workshop", "Eyebrow", { LayoutOrder = 1, TextColor3 = C.StateWarning, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
local title = UiKit.Label(titleBlock, "Upgrade Bench", "H2", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })

local purse = UiKit.Currency(header, "Shells", 0, { size = "lg" })
purse.frame.AnchorPoint = Vector2.new(1, 0.5)
purse.frame.Position = UDim2.new(1, -50, 0.5, 0)
UiKit.Tooltip(purse.frame, "The crew's Shells. Everyone shares them, and they reset when the voyage ends.")

local closeButton = UiKit.IconButton(header, "close", { name = "Close", quiet = true, tip = "Step away from the bench", onClick = function()
	closeBench()
end })
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, 6, 0.5, 0)

-- urgency strip: how long until the storm ---------------------------
local strip = UiKit.new("Frame", { Name = "Urgency", BackgroundTransparency = 1 }, panel)
local clockTag = UiKit.Tag(strip, "", "AccentSea", { name = "Clock" })
clockTag.AnchorPoint = Vector2.new(0, 0.5)
clockTag.Position = UDim2.fromScale(0, 0.5)
local voyageNote = UiKit.Label(strip, "Crew Shells · this voyage only", "Micro", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.new(0.55, 0, 0, 18),
	AutomaticSize = Enum.AutomaticSize.None,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Center,
})

-- phones: the bench covers the top-centre fuel gauge and the tower cluster, so the lamp's
-- state (and a breaching tower) shows here, read live from GameState (see Vitals)
local vitalsRow = UiKit.new("Frame", { Name = "Vitals", BackgroundTransparency = 1, Visible = false }, panel)
UiKit.list(vitalsRow, "x", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
local vitalTags = {}
for i = 1, 2 do
	vitalTags[i] = UiKit.Tag(vitalsRow, "", "AccentSea", { name = "Vital" .. i, layoutOrder = i })
end
local function renderVitals()
	if not vitalsRow.Visible then
		return
	end
	local chips = { Vitals.fuelChip() }
	for _, c in Vitals.criticalChips({ skipFuel = true, skipHealth = true }) do
		table.insert(chips, c)
	end
	Vitals.paint(UiKit, vitalTags, chips)
end

-- upgrade rows ------------------------------------------------------
local list = UiKit.Scroll(panel, { Name = "Upgrades", ScrollBarThickness = 4 })
UiKit.list(list, "y", 8)
UiKit.pad(list, 2, 4, 2, 0)

local footer = UiKit.Label(panel, "", "Micro", { Name = "Footer", AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })

local function makeRow(index, id)
	local upgrade = Upgrades[id]
	local row = UiKit.Inset(list, { Name = "Row_" .. id, LayoutOrder = index, Size = UDim2.new(1, 0, 0, 72) })
	local stroke = UiKit.border(row, C.StateSuccess, 1.5, 1)

	local keycap = UiKit.new("TextLabel", {
		Name = "Key",
		BackgroundColor3 = C.SurfaceElevated,
		FontFace = F.LabelBold,
		TextSize = 14,
		TextColor3 = C.TextSecondary,
		Text = tostring(index),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
	}, row)
	UiKit.round(keycap, 3)
	UiKit.border(keycap, C.BorderStructural, 1, 0.3)

	-- level meter: three slots, filled = fitted
	local meter = UiKit.new("Frame", { Name = "Meter", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(30, 46) }, row)
	local pips = {}
	for level = 1, #upgrade.costs do
		local pip = UiKit.new("Frame", {
			Name = "Level" .. level,
			BackgroundColor3 = C.SurfaceSecondary,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset((level - 1) * 10, 0),
			Size = UDim2.fromOffset(7, 30),
		}, meter)
		UiKit.round(pip, 2)
		UiKit.border(pip, C.BorderSubtle, 1, 0.2)
		pips[level] = pip
	end
	local levelText = UiKit.new("TextLabel", {
		Name = "LevelText",
		BackgroundTransparency = 1,
		FontFace = F.LabelBold,
		TextSize = 13,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(40, 14),
	}, meter)

	local textCol = UiKit.new("Frame", { Name = "Text", BackgroundTransparency = 1 }, row)
	local name = UiKit.Label(textCol, upgrade.displayName, "H3", { Name = "UpgradeName", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 8), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 17 })
	local benefit = UiKit.Label(textCol, "", "BodySmall", { Name = "Benefit", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = C.TextPrimary, TextSize = 14 })
	local status = UiKit.Label(textCol, "", "Micro", { Name = "Status", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 49), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })

	local cost = UiKit.Currency(row, "Shells", 0, { plain = true, showWord = false, textSize = 18 })
	cost.frame.Name = "Cost"
	cost.frame.AnchorPoint = Vector2.new(1, 0.5)

	local buy = UiKit.Button(row, "Buy", { name = "Buy", variant = "primary", size = "sm", width = 84 })
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -10, 0.5, 0)

	local r = {
		id = id,
		frame = row,
		stroke = stroke,
		keycap = keycap,
		meter = meter,
		pips = pips,
		levelText = levelText,
		textCol = textCol,
		name = name,
		benefit = benefit,
		status = status,
		cost = cost,
		buy = buy,
		note = nil,
		noteUntil = 0,
		noteColor = C.TextMuted,
	}
	rows[id] = r
	return r
end

for index, id in Upgrades.ORDER do
	makeRow(index, id)
end

-- Evolutions (launch R13): what two maxed upgrades combine into, and how close the crew is
local evoBox = UiKit.Inset(list, { Name = "Evolutions", LayoutOrder = 99, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = Config.EVOLUTIONS_ENABLED == true })
UiKit.pad(evoBox, 8, 12, 8, 12)
UiKit.list(evoBox, "y", 4)
UiKit.Label(evoBox, "Combine", "Eyebrow", { LayoutOrder = 0 })
local evoLines = {}
for i, evo in Upgrades.EVOLUTIONS or {} do
	evoLines[evo.id] = UiKit.Label(evoBox, "", "BodySmall", { Name = evo.id, LayoutOrder = i, RichText = true })
end
local function renderEvolutions()
	for _, evo in Upgrades.EVOLUTIONS or {} do
		local label = evoLines[evo.id]
		if label then
			if state:GetAttribute("Evo_" .. evo.id) then
				label.Text = string.format("<b>%s</b> \u{2713} active: %s", evo.displayName, string.lower(evo.description))
				label.TextColor3 = C.StateSuccess
			else
				local parts = {}
				for _, need in evo.needs do
					local max = #Upgrades[need].costs
					table.insert(parts, string.format("%s %d/%d", Upgrades[need].displayName, levelOf(need), max))
				end
				label.Text = string.format("<b>%s</b>: max %s. %s.", evo.displayName, table.concat(parts, " + "), evo.description)
				label.TextColor3 = C.TextSecondary
			end
		end
	end
end

---------------------------------------------------------------------
-- RENDER
---------------------------------------------------------------------

local function benefitText(id, level)
	local upgrade = Upgrades[id]
	local b = BENEFIT[id]
	local maxLevel = #upgrade.costs
	if not b then
		return upgrade.description
	end
	local now = if level == 0 then b.base else upgrade.values[level]
	if level >= maxLevel then
		return string.format("%s %s · fully upgraded", b.label, b.fmt(now))
	end
	local nextValue = upgrade.values[level + 1]
	local text = string.format("%s %s \u{2192} <font color=\"%s\"><b>%s</b></font>", b.label, b.fmt(now), hex(C.StateSuccess), b.fmt(nextValue))
	return text
end

local function setNote(r, text, color, seconds)
	r.note = text
	r.noteColor = color or C.TextMuted
	r.noteUntil = os.clock() + (seconds or 3)
end

local function renderRow(r)
	local upgrade = Upgrades[r.id]
	local level = levelOf(r.id)
	local maxLevel = #upgrade.costs
	local balance = shells()
	for i, pip in r.pips do
		local filled = i <= level
		pip.BackgroundColor3 = if filled then C.AccentLighthouse else C.SurfaceSecondary
		pip:FindFirstChildOfClass("UIStroke").Color = if filled then C.AccentLighthouseDeep else C.BorderSubtle
	end
	r.levelText.Text = string.format("LV %d/%d", level, maxLevel)
	r.benefit.Text = benefitText(r.id, level)

	local maxed = level >= maxLevel
	local price = if maxed then 0 else upgrade.costs[level + 1]
	r.cost.frame.Visible = not maxed
	r.cost.set(price)
	r.cost.number.TextColor3 = if not maxed and balance < price then C.StateDanger else C.TextPrimary

	local pendingHere = pendingId ~= nil and pendingUpgrade == r.id
	if pendingHere then
		UiKit.SetBusy(r.buy, true, "...")
	else
		UiKit.SetBusy(r.buy, false)
		if maxed then
			r.buy.Text = "MAXED"
			UiKit.SetDisabled(r.buy, true, upgrade.displayName .. " is fully upgraded for this voyage.")
		elseif balance < price then
			r.buy.Text = "BUY"
			UiKit.SetDisabled(r.buy, true, string.format("The crew needs %d more Shells.", price - balance))
		else
			r.buy.Text = "BUY"
			UiKit.SetDisabled(r.buy, pendingId ~= nil, if pendingId then "Finishing the last upgrade..." else nil)
		end
	end

	-- status line: a recent result wins; otherwise what's stopping you
	if r.note and os.clock() < r.noteUntil then
		r.status.Text = r.note
		r.status.TextColor3 = r.noteColor
	elseif pendingHere then
		r.status.Text = "Fitting the upgrade..."
		r.status.TextColor3 = C.TextSecondary
	elseif maxed then
		r.status.Text = "Maxed for this voyage"
		r.status.TextColor3 = C.TextMuted
	elseif balance < price then
		r.status.Text = string.format("Need %d more Shells", price - balance)
		r.status.TextColor3 = C.StateDanger
	else
		local extra = BENEFIT[r.id] and BENEFIT[r.id].extra
		r.status.Text = if extra then string.format("Level %d of %d · also %s", level + 1, maxLevel, extra) else string.format("Level %d of %d", level + 1, maxLevel)
		r.status.TextColor3 = C.TextMuted
	end
	-- a failure gets two full lines in place of the benefit, so the reason is never cut off
	local longNote = r.note ~= nil and os.clock() < r.noteUntil and r.noteColor ~= C.StateSuccess
	r.benefit.Visible = not longNote
	r.status.TextWrapped = longNote
	r.status.TextTruncate = if longNote then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	r.status.Position = UDim2.fromOffset(0, if longNote then 30 else 49)
	r.status.Size = UDim2.new(1, 0, 0, if longNote then 36 else 16)
end

local function renderClock()
	local phase = state:GetAttribute("Phase") or ""
	local night = state:GetAttribute("Night") or 0
	local left = math.max(0, math.floor(state:GetAttribute("TimeLeft") or 0))
	local text, color
	if phase == "Day" then
		text = string.format("Day %d · night in %d:%02d", night, left // 60, left % 60)
		color = if left <= 15 then C.StateWarning else C.AccentSea
	elseif phase == "Night" then
		text = string.format("Night %d · storm on", night)
		color = C.StateDanger
	elseif phase == "Prologue" then
		text = "The storm hits"
		color = C.StateWarning
	else
		text = "Between storms"
		color = C.AccentSea
	end
	clockTag.Text = string.upper(text)
	clockTag.TextColor3 = color
	clockTag.BackgroundColor3 = color
	local stroke = clockTag:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
end

local function render()
	purse.set(shells())
	renderClock()
	for _, r in rows do
		renderRow(r)
	end
	renderEvolutions()
end

local function flashRow(r, color)
	r.stroke.Color = color
	r.stroke.Transparency = 0
	UiKit.tween(r.stroke, 0.9, { Transparency = 1 })
end

---------------------------------------------------------------------
-- BUYING (one request at a time; the server decides)
---------------------------------------------------------------------

local function buy(id)
	local r = rows[id]
	if not isOpen or not r then
		return
	end
	if pendingId then
		return
	end
	if r.buy:GetAttribute("Disabled") then
		SoundFx.play2D("denied")
		local reason = r.buy:GetAttribute("DisabledReason")
		if reason then
			setNote(r, reason, C.StateDanger, 2.5)
			renderRow(r)
		end
		return
	end
	local requestId = HttpService:GenerateGUID(false)
	local levelBefore = levelOf(id)
	pendingId, pendingUpgrade, pendingStarted = requestId, id, os.clock()
	render()
	remotes.BuyUpgrade:FireServer(id, requestId)
	task.delay(REQUEST_TIMEOUT, function()
		if pendingId == requestId then
			-- no reply: trust the replicated level, never guess (a late reply is ignored)
			pendingId, pendingUpgrade = nil, nil
			if levelOf(id) > levelBefore then
				setNote(r, string.format("Fitted! Level %d is working (the bench was slow to confirm).", levelOf(id)), C.StateSuccess, 4)
			else
				setNote(r, "No answer from the bench. Nothing was fitted. Try again.", C.StateWarning, 4)
			end
			render()
		end
	end)
end

for _, r in rows do
	r.buy.Activated:Connect(function()
		buy(r.id)
	end)
end

remotes:WaitForChild("UpgradeResult").OnClientEvent:Connect(function(requestId, ok, message, id)
	if requestId ~= pendingId then
		return
	end
	pendingId, pendingUpgrade = nil, nil
	local r = rows[id]
	if r then
		if ok then
			setNote(r, string.format("Fitted! Level %d is working now.", levelOf(id)), C.StateSuccess, 3)
			flashRow(r, C.StateSuccess)
			purse.set(shells(), true)
		else
			SoundFx.play2D("denied")
			setNote(r, message or "That didn't work. Nothing was spent.", C.StateDanger, 4)
			flashRow(r, C.StateDanger)
		end
	end
	if isOpen then
		render()
	end
end)

---------------------------------------------------------------------
-- LAYOUT (docked to the right so the storm stays in view)
---------------------------------------------------------------------

local ROW_H = 72

function layout()
	local size = root.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local W, H = size.X, size.Y
	mode = UiKit.Breakpoint(size)
	local phone = mode == "phone"
	local keyboard = not phone and UserInputService.KeyboardEnabled and not UiKit.usingGamepad()
	local pw = if phone then math.min(440, W - 12) else math.min(460, W - 32)
	local pad = if phone then 10 else 16
	local headerH = if phone then 44 else 56
	local stripH = 26
	local footerH = if phone then 0 else 36
	local tapeH = 8
	local rowsH = #Upgrades.ORDER * (ROW_H + 8) + 4
	local wanted = tapeH + 8 + headerH + stripH + 8 + rowsH + footerH + pad + (if phone then 26 else 0)
	-- leave the top HUD clusters alone on bigger screens
	local top = if phone then 6 elseif H - 224 - 16 >= wanted then 224 else math.max(12, H - wanted - 16)
	local ph = math.min(wanted, H - top - (if phone then 6 else 16))
	panel.Size = UDim2.fromOffset(pw, ph)
	panel.Position = UDim2.new(1, if phone then -6 else -24, 0, top)
	panel:SetAttribute("RestPosition", panel.Position)

	header.Position = UDim2.fromOffset(pad, tapeH + 6)
	header.Size = UDim2.new(1, -pad * 2, 0, headerH)
	eyebrow.Visible = not phone
	title.TextSize = if phone then 20 else 23
	strip.Position = UDim2.fromOffset(pad, tapeH + 6 + headerH)
	strip.Size = UDim2.new(1, -pad * 2, 0, stripH)
	voyageNote.Visible = true
	local vitalsH = if phone then 26 else 0
	vitalsRow.Visible = phone
	vitalsRow.Position = UDim2.fromOffset(pad, tapeH + 6 + headerH + stripH + 2)
	vitalsRow.Size = UDim2.new(1, -pad * 2, 0, 22)
	renderVitals()
	local listTop = tapeH + 6 + headerH + stripH + 8 + vitalsH
	list.Position = UDim2.fromOffset(pad, listTop)
	list.Size = UDim2.new(1, -pad * 2 + 4, 0, ph - listTop - footerH - (if phone then 6 else 4))
	footer.Visible = not phone
	footer.Position = UDim2.new(0, pad, 1, -footerH)
	footer.Size = UDim2.new(1, -pad * 2, 0, footerH - 6)
	footer.Text = string.format("Cannons are built on the glowing stone pads (%d Shells). %s", Config.CANNON_COSTS[1], if UiKit.usingGamepad() then "B to close." else "Upgrades reset when the voyage ends.")

	local rowW = pw - pad * 2 - (if ph < wanted then 8 else 0)
	for _, r in rows do
		r.keycap.Visible = keyboard
		local left = if keyboard then 42 else 12
		r.meter.Position = UDim2.new(0, left, 0.5, 0)
		local textX = left + 40
		local costW = 62
		local buyW = 84
		r.buy.Size = UDim2.fromOffset(buyW, 44)
		r.cost.frame.Position = UDim2.new(1, -10 - buyW - 8, 0.5, 0)
		r.textCol.Position = UDim2.fromOffset(textX, 0)
		r.textCol.Size = UDim2.new(0, math.max(80, rowW - textX - costW - buyW - 30), 1, 0)
		r.benefit.TextSize = if phone then 13 else 14
	end
	root:SetAttribute("NoticeTop", 12)
	if isOpen then
		render()
	end
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if isOpen then
		layout()
	end
end)

---------------------------------------------------------------------
-- OPEN / CLOSE
---------------------------------------------------------------------

function closeBench()
	if not isOpen then
		return
	end
	isOpen = false
	ContextActionService:UnbindAction("CloseBench")
	ContextActionService:UnbindAction("BenchKeys")
	GuiService.SelectedObject = nil
	UiKit.popModal("Bench")
	UiKit.Close(panel, function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local function openBench()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	UiKit.pushModal("Bench")
	layout()
	render()
	UiKit.Open(panel)
	task.delay(UiKit.Motion.base + 0.05, function()
		if isOpen then
			layout() -- the screen size can settle after the first frame
		end
	end)
	ContextActionService:BindAction("CloseBench", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			closeBench()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	-- 1-4 buy straight away (and don't switch tools while the bench is open)
	ContextActionService:BindActionAtPriority("BenchKeys", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin then
			for index, key in KEYS do
				if input.KeyCode == key and Upgrades.ORDER[index] then
					buy(Upgrades.ORDER[index])
				end
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(KEYS))
	task.defer(function()
		if UiKit.usingGamepad() then
			for _, id in Upgrades.ORDER do
				if not rows[id].buy:GetAttribute("Disabled") then
					GuiService.SelectedObject = rows[id].buy
					return
				end
			end
			GuiService.SelectedObject = rows[Upgrades.ORDER[1]].buy
		end
	end)
end

remotes:WaitForChild("OpenUpgrades").OnClientEvent:Connect(openBench)

state.AttributeChanged:Connect(function(name)
	if not isOpen then
		return
	end
	if name == "TimeLeft" then
		renderClock()
	elseif name == "Shells" or name == "Phase" or name == "Night" or string.sub(name, 1, 8) == "Upgrade_" then
		render()
	end
end)

-- walking away (or dying) closes the bench; notes expire
local lastTick = 0
RunService.Heartbeat:Connect(function()
	if not isOpen then
		return
	end
	local now = os.clock()
	if now - lastTick < 0.25 then
		return
	end
	lastTick = now
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local island = Workspace:FindFirstChild("Island")
	local bench = island and island:FindFirstChild("UpgradeBench")
	if not rootPart or not humanoid or humanoid.Health <= 0 or not bench or (rootPart.Position - bench.Position).Magnitude > WALK_AWAY then
		closeBench()
		return
	end
	renderVitals()
	for _, r in rows do
		if r.note and now >= r.noteUntil then
			r.note = nil
			renderRow(r)
		end
	end
end)

---------------------------------------------------------------------
-- STUDIO ONLY: draw the bench inside a simulated screen (HudSimulate attribute)
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
		rootOutline.Enabled = spec ~= nil
		if spec then
			root.AnchorPoint = Vector2.new(0.5, 0.5)
			root.Position = UDim2.fromScale(0.5, 0.5)
			root.Size = UDim2.fromOffset(spec.X, spec.Y)
		else
			root.AnchorPoint = Vector2.zero
			root.Position = UDim2.new()
			root.Size = UDim2.fromScale(1, 1)
		end
		task.defer(function()
			if isOpen then
				layout()
			end
		end)
	end
	player:GetAttributeChangedSignal("HudSimulate"):Connect(applySimulation)
	applySimulation()
end
