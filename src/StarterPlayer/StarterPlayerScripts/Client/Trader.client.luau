-- Trader (client): the salvage buyer on the lighthouse island.
--
-- Loot (crab claws, sea glass, black pearls) only lasts one voyage. The Trader turns it into
-- Shells for the whole crew. This is NOT a shop: no Pearls, no permanent items, one action.
-- The server opens it (TraderOpen, from the Trader's prompt) and does the selling
-- (TraderRequest -> TraderResult); shell values come from Shared/Items unchanged.
--
-- Built on UiKit v2.1 (Stage 5 of the UI redesign). Looks like a scavenger's tally sheet,
-- not the Quartermaster's counter: perforated receipt edge, sea-green salvage accents.
-- Studio only: player attribute HudSimulate draws it inside a simulated screen size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local SoundFx = require(Shared:WaitForChild("SoundFx"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))
local Vitals = require(script.Parent:WaitForChild("Vitals"))

local C, F = UiKit.Color, UiKit.Font
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local state = ReplicatedStorage:WaitForChild("GameState")
local player = Players.LocalPlayer

local REQUEST_TIMEOUT = 8
local WALK_AWAY = 16
local ACCENT = C.CatMaterials

local LOOT = {}
for _, itemId in Items.SHOP_ORDER do
	if type(Items[itemId]) == "table" and Items[itemId].runScoped then
		table.insert(LOOT, itemId)
	end
end

local profile = nil
local isOpen = false
local mode = "desktop"
local view = "list" -- "list" | "sold"
local soldFor = 0
local pendingId = nil
local errorText = nil
local awaitingCheck = nil -- after a timeout: the sack's value before, while we re-check the server
local layout, closeTrader, render -- forward declarations

-- while a sale is in flight the sheet keeps showing what was being sold (the server's new,
-- empty sack can arrive before its reply); the live counts decide everything else
local frozen = nil
local function liveCount(itemId)
	return if profile then (profile.counts[itemId] or 0) else 0
end
local function count(itemId)
	if frozen then
		return frozen[itemId] or 0
	end
	return liveCount(itemId)
end
local function totalValue(live)
	local total = 0
	for _, itemId in LOOT do
		total += (if live then liveCount(itemId) else count(itemId)) * (Items[itemId].shellValue or 0)
	end
	return total
end

---------------------------------------------------------------------
-- SCREEN
---------------------------------------------------------------------

local gui = UiKit.Screen("SalvageTrader", 18)
gui.Enabled = false
local root = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local rootOutline = UiKit.border(root, C.BorderFocus, 1, 0.4)
rootOutline.Enabled = false

local panel = UiKit.Panel(root, { name = "TallySheet", kind = "plain", variant = "secondary", padding = 0, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5) })
UiKit.border(panel, ACCENT, 1, 0.5)

-- perforated receipt edge along the top
local perforation = UiKit.new("Frame", { Name = "Perforation", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 2), ClipsDescendants = true }, panel)
for i = 0, 70 do
	UiKit.new("Frame", { BackgroundColor3 = ACCENT, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.fromOffset(i * 9, 0), Size = UDim2.fromOffset(5, 2) }, perforation)
end

-- header ------------------------------------------------------------
local header = UiKit.new("Frame", { Name = "Header", BackgroundTransparency = 1 }, panel)
local titleBlock = UiKit.new("Frame", { Name = "TitleBlock", BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0) }, header)
UiKit.list(titleBlock, "y", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
local eyebrow = UiKit.Label(titleBlock, "Salvage trader", "Eyebrow", { LayoutOrder = 1, TextColor3 = ACCENT, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
local title = UiKit.Label(titleBlock, "The Trader", "H2", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
local greeting = UiKit.Label(titleBlock, "\u{201C}Claws, glass, pearls. I'll take the lot.\u{201D}", "BodySmall", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 20),
	AutomaticSize = Enum.AutomaticSize.None,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
})

local purse = UiKit.Currency(header, "Shells", 0, { size = "lg" })
purse.frame.AnchorPoint = Vector2.new(1, 0.5)
purse.frame.Position = UDim2.new(1, -50, 0.5, 0)
UiKit.Tooltip(purse.frame, "The crew's Shells. Selling adds to them for everyone.")

local closeButton = UiKit.IconButton(header, "close", { name = "Close", quiet = true, tip = "Walk away", onClick = function()
	closeTrader()
end })
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, 6, 0.5, 0)

-- critical HUD states surface here while the sheet is open (the storm doesn't pause):
-- low/critical fuel, lamp dark, critical health, breaching tower. Hidden when all is well.
local vitalsRow = UiKit.new("Frame", { Name = "Vitals", BackgroundTransparency = 1, Visible = false }, panel)
UiKit.list(vitalsRow, "x", 6, { VerticalAlignment = Enum.VerticalAlignment.Center, Wraps = true })
local vitalTags = {}
for i = 1, 3 do
	vitalTags[i] = UiKit.Tag(vitalsRow, "", "StateDanger", { name = "Vital" .. i, layoutOrder = i })
end
local vitalChips = {}

-- body: the tally ---------------------------------------------------
local body = UiKit.Scroll(panel, { Name = "Body", ScrollBarThickness = 4 })
UiKit.list(body, "y", 10)
UiKit.pad(body, 2, 6, 4, 0)

local ledger = UiKit.Section(body, "Your salvage", { layoutOrder = 1, gap = 0 })
ledger.Name = "Ledger"
local ledgerRows = {}
local previews = {}

local totalRow = UiKit.new("Frame", { Name = "Total", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 2 }, body)
UiKit.new("Frame", { Name = "Rule", BackgroundColor3 = ACCENT, BackgroundTransparency = 0.5, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, totalRow)
UiKit.Label(totalRow, "Trader pays", "Label", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(0.5, 0, 0, 36), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextYAlignment = Enum.TextYAlignment.Center })
local totalHolder = UiKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X }, totalRow)
UiKit.list(totalHolder, "x", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center })
local totalDisplay = UiKit.Currency(totalHolder, "Shells", 0, { plain = true, textSize = 22 })

-- the rule every player has to understand
local note = UiKit.Inset(body, { Name = "LootRule", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
UiKit.pad(note, 10, 12, 10, 12)
local noteGlyph = UiKit.Glyph(note, "info", C.AccentSea, 16)
noteGlyph.Position = UDim2.fromOffset(0, 2)
local noteText = UiKit.Label(note, "", "BodySmall", { Name = "Text", Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 0, 0), TextColor3 = C.TextPrimary })
noteText.Text = "<b>Loot only lasts this voyage.</b> Sell it here for Shells the whole crew can spend at the upgrade bench. Anything you don't sell is gone when the run ends."

local emptyView = UiKit.StateView(panel, "empty", { title = "Nothing to sell yet", body = "Creatures drop crab claws, sea glass and black pearls. Bring them here before the voyage ends." })
emptyView.Visible = false
local loadingView = UiKit.StateView(panel, "loading", { title = "Counting your salvage" })
loadingView.Visible = false
local soldView = UiKit.StateView(panel, "success", { title = "Sold", body = "" })
soldView.Visible = false
local function soldTexts()
	local labels = {}
	for _, d in soldView:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(labels, d)
		end
	end
	return labels
end

-- phones: the loot rule as one line right above the button, always in view
local ruleLine = UiKit.Label(panel, "Loot lasts this voyage only. Unsold loot is lost when the run ends.", "Micro", { Name = "RuleLine", TextColor3 = C.AccentSea, AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center, Visible = false })
local errorLabel = UiKit.Label(panel, "", "Micro", { Name = "Error", TextColor3 = C.StateDanger, AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center })
local actionButton = UiKit.Button(panel, "Sell all", { name = "SellAll", variant = "primary", size = "md" })

local function makeLedgerRow(order, itemId)
	local item = Items[itemId]
	local row = UiKit.new("Frame", { Name = "Row_" .. itemId, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = order }, ledger)
	if order > 1 then
		UiKit.new("Frame", { Name = "Hairline", BackgroundColor3 = C.BorderSubtle, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, row)
	end
	local well = UiKit.Inset(row, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(46, 46), ClipsDescendants = true })
	local preview = ItemPreview.new(well, { backdrop = false })
	preview:setItem(itemId)
	table.insert(previews, preview)
	local nameLabel = UiKit.Label(row, item.name, "H3", { Name = "ItemName", Position = UDim2.fromOffset(58, 9), Size = UDim2.new(1, -170, 0, 22), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 16 })
	UiKit.Label(row, string.format("%d Shells each", item.shellValue or 0), "Micro", { Name = "Each", Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -170, 0, 16), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
	local qty = UiKit.new("TextLabel", {
		Name = "Quantity",
		BackgroundTransparency = 1,
		FontFace = F.Numeric,
		TextSize = 17,
		TextColor3 = C.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -86, 0.5, 0),
		Size = UDim2.fromOffset(50, 24),
	}, row)
	local subHolder = UiKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X }, row)
	UiKit.list(subHolder, "x", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center })
	local subtotal = UiKit.Currency(subHolder, "Shells", 0, { plain = true, showWord = false, textSize = 17 })
	ledgerRows[itemId] = { frame = row, qty = qty, subtotal = subtotal, name = nameLabel }
end

---------------------------------------------------------------------
-- RENDER
---------------------------------------------------------------------

function render()
	purse.set(state:GetAttribute("Shells") or 0)
	local total = totalValue()
	local loading = profile == nil
	local empty = not loading and total <= 0 and view ~= "sold"
	local showList = not loading and not empty and view == "list"

	loadingView.Visible = loading
	emptyView.Visible = empty
	soldView.Visible = view == "sold"
	body.Visible = showList or empty
	ledger.Visible = showList
	totalRow.Visible = showList

	local order = 0
	for _, itemId in LOOT do
		local n = count(itemId)
		local r = ledgerRows[itemId]
		if r then
			r.frame.Visible = n > 0
			if n > 0 then
				order += 1
				r.frame.LayoutOrder = order
				r.qty.Text = "\u{00D7}" .. n
				r.subtotal.set(n * (Items[itemId].shellValue or 0))
				local hairline = r.frame:FindFirstChild("Hairline")
				if hairline then
					hairline.Visible = order > 1
				end
			end
		end
	end
	totalDisplay.set(total)

	errorLabel.Text = errorText or ""
	errorLabel.Visible = errorText ~= nil

	if view == "sold" then
		local labels = soldTexts()
		if labels[1] then
			labels[1].Text = string.format("Sold for %s Shells", UiKit.formatNumber(soldFor))
		end
		if labels[2] then
			labels[2].Text = "The crew can spend them at the upgrade bench right now."
		end
		UiKit.SetBusy(actionButton, false)
		actionButton.Text = "DONE"
		UiKit.SetDisabled(actionButton, false)
	elseif pendingId then
		UiKit.SetBusy(actionButton, true, "Selling...")
	else
		UiKit.SetBusy(actionButton, false)
		if loading then
			actionButton.Text = "SELL ALL"
			UiKit.SetDisabled(actionButton, true, "Counting your salvage...")
		elseif empty then
			actionButton.Text = "NOTHING TO SELL"
			UiKit.SetDisabled(actionButton, true, "You aren't carrying any loot.")
		else
			actionButton.Text = string.format("SELL ALL FOR %s SHELLS", UiKit.formatNumber(total))
			UiKit.SetDisabled(actionButton, false)
		end
	end
	if not pendingId then
		actionButton:SetAttribute("BaseText", actionButton.Text)
	end
end

---------------------------------------------------------------------
-- SELLING
---------------------------------------------------------------------

local function sellAll()
	if pendingId or view == "sold" or totalValue() <= 0 then
		return
	end
	local requestId = HttpService:GenerateGUID(false)
	local valueBefore = totalValue()
	frozen = table.clone(profile.counts)
	pendingId = requestId
	errorText = nil
	awaitingCheck = nil
	layout()
	render()
	remotes.TraderRequest:FireServer(requestId, "sellAll")
	task.delay(REQUEST_TIMEOUT, function()
		if pendingId == requestId then
			-- no reply: ask the server what really happened (a late reply is ignored)
			pendingId = nil
			awaitingCheck = valueBefore
			errorText = "The Trader didn't answer. Checking your sack..."
			remotes.GearAction:FireServer("sync")
			if isOpen then
				layout()
				render()
			end
		end
	end)
end

actionButton.Activated:Connect(function()
	if actionButton:GetAttribute("Disabled") then
		SoundFx.play2D("denied")
		return
	end
	if view == "sold" then
		closeTrader()
	else
		sellAll()
	end
end)

remotes:WaitForChild("TraderResult").OnClientEvent:Connect(function(requestId, ok, message, total)
	if requestId ~= pendingId then
		return
	end
	pendingId = nil
	frozen = nil
	if ok then
		view = "sold"
		soldFor = tonumber(total) or 0
		errorText = nil
		purse.set(state:GetAttribute("Shells") or 0, true)
	else
		SoundFx.play2D("denied")
		errorText = message or "That didn't work. Nothing was sold."
	end
	if isOpen then
		layout()
		render()
		if ok and UiKit.usingGamepad() then
			GuiService.SelectedObject = actionButton
		end
	end
end)

remotes:WaitForChild("GearData").OnClientEvent:Connect(function(data)
	profile = data
	if awaitingCheck then
		-- the server's own data decides: the sack is empty -> the sale went through
		frozen = nil
		if totalValue(true) <= 0 then
			view = "sold"
			soldFor = awaitingCheck
			errorText = nil
		else
			errorText = "The Trader didn't answer. Nothing was sold. Try again."
		end
		awaitingCheck = nil
	end
	if isOpen then
		layout()
		render()
	end
end)

state:GetAttributeChangedSignal("Shells"):Connect(function()
	if isOpen then
		purse.set(state:GetAttribute("Shells") or 0)
	end
end)

---------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------

function layout()
	local size = root.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local W, H = size.X, size.Y
	mode = UiKit.Breakpoint(size)
	local phone = mode == "phone"
	local pw = if phone then math.min(500, W - 12) else math.min(500, W - 32)
	local pad = if phone then 12 else 20
	local headerH = if phone then 46 else 74
	local buttonH = 48
	local errorH = if errorText then 30 else 0
	local listH = 0
	for _, itemId in LOOT do
		if count(itemId) > 0 then
			listH += 58
		end
	end
	local bodyWanted = 24 + listH + 54 + 92
	if profile and listH == 0 and view == "list" then
		bodyWanted = 150 + 104 -- empty state + the loot rule
	end
	local wanted = 12 + headerH + 8 + bodyWanted + errorH + buttonH + pad + 8 + (if #vitalChips > 0 then 28 else 0)
	local ph = math.min(math.max(wanted, 330), H - (if phone then 12 else 48))
	panel.Size = UDim2.fromOffset(pw, ph)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel:SetAttribute("RestPosition", panel.Position)

	header.Position = UDim2.fromOffset(pad, 12)
	header.Size = UDim2.new(1, -pad * 2, 0, headerH)
	eyebrow.Visible = not phone
	greeting.Visible = not phone
	title.TextSize = if phone then 20 else 23

	local vitalsH = if #vitalChips > 0 then 28 else 0
	vitalsRow.Visible = vitalsH > 0
	vitalsRow.Position = UDim2.fromOffset(pad, 12 + headerH + 4)
	vitalsRow.Size = UDim2.new(1, -pad * 2, 0, 22)
	Vitals.paint(UiKit, vitalTags, vitalChips)
	local bodyTop = 12 + headerH + 8 + vitalsH
	local ruleH = if phone then 20 else 0
	local bottom = pad + buttonH + 8 + errorH + ruleH
	note.Visible = not phone
	ruleLine.Visible = phone and view == "list"
	ruleLine.Position = UDim2.new(0, pad, 1, -pad - buttonH - 4 - errorH - ruleH)
	ruleLine.Size = UDim2.new(1, -pad * 2, 0, ruleH)
	body.Position = UDim2.fromOffset(pad, bodyTop)
	body.Size = UDim2.new(1, -pad * 2 + 6, 0, ph - bodyTop - bottom)
	for _, v in { emptyView, loadingView, soldView } do
		v.Position = UDim2.fromOffset(pad, bodyTop)
		v.Size = UDim2.new(1, -pad * 2, 0, if v == emptyView then 150 else ph - bodyTop - bottom)
	end
	-- the empty state keeps the loot rule visible underneath
	if profile and totalValue() <= 0 and view == "list" then
		body.Position = UDim2.fromOffset(pad, bodyTop + 150)
		body.Size = UDim2.new(1, -pad * 2 + 6, 0, math.max(60, ph - bodyTop - 150 - bottom))
	end
	errorLabel.Position = UDim2.new(0, pad, 1, -pad - buttonH - 4 - errorH)
	errorLabel.Size = UDim2.new(1, -pad * 2, 0, errorH)
	actionButton.AutomaticSize = Enum.AutomaticSize.None
	actionButton.AnchorPoint = Vector2.new(0, 1)
	actionButton.Position = UDim2.new(0, pad, 1, -pad)
	actionButton.Size = UDim2.new(1, -pad * 2, 0, buttonH)
	root:SetAttribute("NoticeTop", 12)
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if isOpen then
		layout()
		render()
	end
end)

local function refresh()
	layout()
	render()
end

---------------------------------------------------------------------
-- OPEN / CLOSE
---------------------------------------------------------------------

local function clearRows()
	for _, p in previews do
		p:destroy()
	end
	table.clear(previews)
	for _, r in ledgerRows do
		r.frame:Destroy()
	end
	table.clear(ledgerRows)
end

function closeTrader()
	if not isOpen then
		return
	end
	isOpen = false
	ContextActionService:UnbindAction("CloseTrader")
	GuiService.SelectedObject = nil
	UiKit.popModal("Trader")
	UiKit.Close(panel, function()
		if not isOpen then
			gui.Enabled = false
			clearRows() -- 3D icons exist only while the Trader is open
		end
	end)
end

local function openTrader()
	if isOpen then
		return
	end
	isOpen = true
	view = "list"
	errorText = nil
	awaitingCheck = nil
	frozen = nil
	soldFor = 0
	clearRows()
	for order, itemId in LOOT do
		makeLedgerRow(order, itemId)
	end
	vitalChips = Vitals.criticalChips()
	gui.Enabled = true
	UiKit.pushModal("Trader")
	refresh()
	UiKit.Open(panel)
	remotes.GearAction:FireServer("sync")
	ContextActionService:BindAction("CloseTrader", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			closeTrader()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	task.defer(function()
		if UiKit.usingGamepad() then
			GuiService.SelectedObject = if actionButton:GetAttribute("Disabled") then closeButton else actionButton
		end
	end)
end

remotes:WaitForChild("TraderOpen").OnClientEvent:Connect(openTrader)

-- walking away (or dying) closes it
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
	local trader = island and island:FindFirstChild("Trader")
	if not rootPart or not humanoid or humanoid.Health <= 0 or not trader or (rootPart.Position - trader.Position).Magnitude > WALK_AWAY then
		closeTrader()
		return
	end
	-- live critical chips (re-fit the sheet only when they appear or disappear)
	local chips = Vitals.criticalChips()
	local changed = (#chips > 0) ~= (#vitalChips > 0)
	vitalChips = chips
	if changed then
		layout()
	else
		Vitals.paint(UiKit, vitalTags, vitalChips)
	end
end)

---------------------------------------------------------------------
-- STUDIO ONLY: draw the sheet inside a simulated screen (HudSimulate attribute)
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
				refresh()
			end
		end)
	end
	player:GetAttributeChangedSignal("HudSimulate"):Connect(applySimulation)
	applySimulation()
end

remotes.GearAction:FireServer("sync")
