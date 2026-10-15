-- Shop (client): the Quartermaster's supply counter at the harbor.
--
-- ONLY the server opens it (the Quartermaster's Trade prompt) and it closes when the player
-- walks away. Every purchase is a request (ShopRequest -> ShopResult); the server validates
-- price, Pearls, ownership, stack limits, range and duplicate requests. Nothing here changes data.
--
-- Built on UiKit v2.1 (Stage 4 of the UI redesign).
--   Wide / medium: category tabs + supply grid | selected-item counter panel (preview, stats,
--                  comparison, price tag, buy). Buying opens the UiKit purchase dialog (ledger).
--   Phone (landscape): grid first -> tap -> detail view with Back.
-- Studio only: player attribute HudSimulate draws it inside a simulated screen size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Ammo = require(Shared:WaitForChild("Ammo"))
local SoundFx = require(Shared:WaitForChild("SoundFx"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))

local C, F = UiKit.Color, UiKit.Font
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local REQUEST_TIMEOUT = 8

local profile = nil
local isOpen = false
local category = Items.SHOP_CATEGORIES[1]
local selectedId = nil
local pendingId = nil
local pendingDone = nil
local quantity = 1
local mode = "wide"
local phoneView = "items"
local dialog = nil
local layout, closeShop -- forward declarations

---------------------------------------------------------------------
-- FACTS
---------------------------------------------------------------------

local function count(itemId)
	return if profile then (profile.counts[itemId] or 0) else 0
end
local function owns(itemId)
	return profile ~= nil and profile.owned[itemId] == true
end
local function isEquipped(itemId)
	return profile ~= nil and (profile.equippedWeapon == itemId or profile.equippedArmor == itemId)
end
local function pearls()
	return if profile then profile.pearls or 0 else 0
end
local function dps(weaponId)
	local w = Weapons[weaponId]
	return w.damage / w.cooldown
end
local function typeLabel(item)
	return if item.kind == "Weapon" then "Primary weapon" elseif item.kind == "Armor" then "Armor" elseif item.kind == "Ammo" then "Cannon ammo" elseif item.kind == "Cosmetic" then "Beam colour \u{00B7} looks only" else item.category
end
local function itemsIn(cat)
	local list = {}
	for _, itemId in Items.SHOP_ORDER do
		local item = Items[itemId]
		if item.category == cat and (item.price or owns(itemId)) then
			table.insert(list, itemId)
		end
	end
	return list
end

-- ammo: how many crates the player could buy right now
local function ammoRoom(itemId)
	local item = Items[itemId]
	local room = item.maxStack - count(itemId)
	local afford = if item.price and item.price > 0 then math.floor(pearls() / item.price) else 0
	return room, afford, math.max(0, math.min(room, afford))
end

-- stat rows with a comparison against what is equipped in the same slot
local function statRows(itemId)
	local item = Items[itemId]
	local rows = {}
	local function add(label, value, a, b, higherIsBetter, fmt)
		local delta, better
		if b ~= nil and a ~= b then
			delta = a - b
			better = if higherIsBetter then delta > 0 else delta < 0
		end
		table.insert(rows, { label = label, value = value, delta = delta, better = better, fmt = fmt })
	end
	if item.kind == "Weapon" then
		local w = Weapons[itemId]
		local current = profile and profile.equippedWeapon
		local cw = current and current ~= itemId and Weapons[current] or nil
		add("Damage per hit", tostring(w.damage), w.damage, cw and cw.damage, true, "%+d")
		add("Reload", string.format("%.1f s", w.cooldown), w.cooldown, cw and cw.cooldown, false, "%+.1f s")
		add("Targets per throw", if w.maxTargets > 1 then ("up to " .. w.maxTargets) else "1", w.maxTargets, cw and cw.maxTargets, true, "%+d")
		add("Damage per second", tostring(math.floor(dps(itemId) + 0.5)), math.floor(dps(itemId) + 0.5), cw and math.floor(dps(current) + 0.5), true, "%+d")
	elseif item.kind == "Armor" then
		local current = profile and profile.equippedArmor
		local ca = current and current ~= itemId and Items[current] or nil
		add("Health", tostring(item.maxHealth), item.maxHealth, ca and ca.maxHealth, true, "%+d")
		local red = math.floor(item.damageReduction * 100 + 0.5)
		add("Damage blocked", red .. "%", red, ca and math.floor(ca.damageReduction * 100 + 0.5), true, "%+d%%")
	elseif item.kind == "Ammo" then
		local a = Ammo[item.ammoType]
		add("Shots per crate", tostring(a.shotsPerLoad))
		add("Cannon damage", string.format("x%.1f", a.damageMultiplier))
		add("Blast size", string.format("x%.1f", a.splashMultiplier))
		add("You carry", string.format("%d / %d crates", count(itemId), item.maxStack))
	end
	return rows
end

---------------------------------------------------------------------
-- SCREENS
---------------------------------------------------------------------

local scrimGui = UiKit.Screen("QuartermasterScrim", 19, true)
scrimGui.Enabled = false
local scrim = UiKit.new("TextButton", {
	Name = "Scrim",
	Text = "",
	AutoButtonColor = false,
	Selectable = false,
	BackgroundColor3 = C.Scrim,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, scrimGui)

local gui = UiKit.Screen("QuartermasterShop", 20)
gui.Enabled = false
local root = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local rootOutline = UiKit.border(root, C.BorderFocus, 1, 0.4)
rootOutline.Enabled = false

-- notices shown on the HUD after the counter closes (e.g. "You walked away")
local noticeGui = UiKit.Screen("ShopNotice", 21)
local noticeRoot = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, noticeGui)
noticeRoot:SetAttribute("NoticeTop", 140)

local panel = UiKit.Panel(root, { name = "CounterPanel", kind = "housing", beam = true, padding = 0, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5) })

-- header: who you're talking to, what they said, your Pearls, close ---------
local header = UiKit.new("Frame", { Name = "Header", BackgroundTransparency = 1 }, panel)
local titleBlock = UiKit.new("Frame", { Name = "TitleBlock", BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0) }, header)
UiKit.list(titleBlock, "y", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
local eyebrow = UiKit.Label(titleBlock, "Harbor supply counter", "Eyebrow", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
local title = UiKit.Label(titleBlock, "The Quartermaster", "H2", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
local greeting = UiKit.Label(titleBlock, "", "BodySmall", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic) })

local purse = UiKit.Currency(header, "Pearls", 0, { size = "lg" })
purse.frame.AnchorPoint = Vector2.new(1, 0.5)
purse.frame.Position = UDim2.new(1, -56, 0.5, 0)

local backButton = UiKit.Button(header, "Back", { name = "Back", variant = "secondary", size = "sm", minWidth = 96, onClick = function()
	phoneView = "items"
	layout()
end })
backButton.AnchorPoint = Vector2.new(0, 0.5)
backButton.Position = UDim2.fromScale(0, 0.5)

local closeButton = UiKit.IconButton(header, "close", { name = "Close", quiet = true, tip = "Leave the counter", onClick = function()
	closeShop(nil, false)
end })
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, 6, 0.5, 0)

local body = UiKit.new("Frame", { Name = "Body", BackgroundTransparency = 1 }, panel)
local gridCol = UiKit.new("Frame", { Name = "GridColumn", BackgroundTransparency = 1 }, body)
local detailCol = UiKit.new("Frame", { Name = "DetailColumn", BackgroundTransparency = 1 }, body)
---------------------------------------------------------------------
-- GRID
---------------------------------------------------------------------

local renderGrid, renderDetail
local tabItems = {}
for _, cat in Items.SHOP_CATEGORIES do
	table.insert(tabItems, { id = cat, label = cat, color = UiKit.CATEGORY[cat] })
end
local tabs = UiKit.Tabs(gridCol, tabItems, {
	size = UDim2.new(1, 0, 0, 46),
	textSize = 17,
	minWidth = 90,
	shoulders = true,
	onChange = function(id)
		category = id
		selectedId = nil
		quantity = 1
		renderGrid()
	end,
})
local gridScroll = UiKit.Scroll(gridCol, { Name = "Grid", Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56) })
local gridLayout = UiKit.new("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, gridScroll)
UiKit.pad(gridScroll, 6, 6, 6, 6)
local gridState = nil

---------------------------------------------------------------------
-- COUNTER PANEL (selected item)
---------------------------------------------------------------------

local detail = UiKit.new("Frame", { Name = "Detail", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, detailCol)
local well = UiKit.Inset(detail, { Name = "PreviewWell", ClipsDescendants = true })
UiKit.border(well, C.BorderStructural, 1, 0.6)
local bigPreview = ItemPreview.new(well, { rotatable = true })
UiKit.Label(well, "Drag to turn", "Micro", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -8, 1, -6),
	Size = UDim2.fromOffset(120, 16),
	AutomaticSize = Enum.AutomaticSize.None,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 4,
})

local info = UiKit.Scroll(detail, { Name = "Info", ScrollBarThickness = 4 })
UiKit.list(info, "y", 8)
UiKit.pad(info, 0, 6, 8, 0)
local dName = UiKit.Label(info, "", "H2", { Name = "ItemName", LayoutOrder = 1 })
local dTags = UiKit.new("Frame", { Name = "Tags", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2 }, info)
UiKit.list(dTags, "x", 6)
local dDesc = UiKit.Label(info, "", "BodySmall", { Name = "Description", LayoutOrder = 3, TextColor3 = C.TextPrimary })
local statsSection = UiKit.Section(info, "Stats", { layoutOrder = 4, gap = 4 })
local compareCaption = UiKit.Label(info, "", "Micro", { Name = "CompareCaption", LayoutOrder = 5 })
local tradeFrame = UiKit.new("Frame", { Name = "Tradeoffs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6 }, info)
UiKit.list(tradeFrame, "y", 4)
local function tradeLine(order, glyph, color)
	local row = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, tradeFrame)
	UiKit.Glyph(row, glyph, color, 14).Position = UDim2.fromOffset(0, 2)
	local text = UiKit.Label(row, "", "BodySmall", { Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 0, 0), TextColor3 = C.TextPrimary })
	return row, text
end
local strengthRow, strengthText = tradeLine(1, "plus", C.StateSuccess)
local tradeoffRow, tradeoffText = tradeLine(2, "minus", C.StateWarning)

-- price tag + affordability + buy (pinned to the bottom of the counter panel)
local buyArea = UiKit.Inset(detail, { Name = "PriceTag" })
UiKit.pad(buyArea, 10, 12, 10, 12)
local priceRow = UiKit.new("Frame", { Name = "PriceRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, buyArea)
local priceLabel = UiKit.Label(priceRow, "Price", "Label", { Size = UDim2.new(0.4, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextYAlignment = Enum.TextYAlignment.Center })
local priceHolder = UiKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X }, priceRow)
UiKit.list(priceHolder, "x", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center })
local priceDisplay = UiKit.Currency(priceHolder, "Pearls", 0, { plain = true, textSize = 20 })

-- ammo quantity stepper
local stepper = UiKit.new("Frame", { Name = "Quantity", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 44), Visible = false }, buyArea)
UiKit.list(stepper, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
local minusButton = UiKit.IconButton(stepper, "minus", { name = "Less", layoutOrder = 1, tip = "One crate fewer" })
local qtyLabel = UiKit.new("TextLabel", {
	Name = "Count",
	BackgroundTransparency = 1,
	FontFace = F.Numeric,
	TextSize = 22,
	TextColor3 = C.TextPrimary,
	Size = UDim2.fromOffset(56, 44),
	LayoutOrder = 2,
}, stepper)
local plusButton = UiKit.IconButton(stepper, "plus", { name = "More", layoutOrder = 3, tip = "One crate more" })
local maxButton = UiKit.Button(stepper, "Max", { name = "Max", variant = "ghost", size = "sm", minWidth = 64, layoutOrder = 4 })

local affordText = UiKit.Label(buyArea, "", "Micro", { Name = "Affordability", Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
local buyButton = UiKit.Button(buyArea, "Buy", { name = "BuyButton", variant = "primary", size = "md", fill = true })
buyButton.AnchorPoint = Vector2.new(0, 1)
buyButton.Position = UDim2.fromScale(0, 1)

local detailEmpty = UiKit.StateView(detail, "empty", { title = "Pick something from the counter", body = "Select an item to see it up close, compare it and buy it." })
detailEmpty.Visible = false

local statWidgets = {}
local function renderStats(rows)
	for _, w in statWidgets do
		w:Destroy()
	end
	table.clear(statWidgets)
	for index, r in rows do
		local row = UiKit.new("Frame", { Name = "Stat_" .. index, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = index }, statsSection)
		UiKit.Label(row, r.label, "BodySmall", { Size = UDim2.new(1, -170, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center })
		local right = UiKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X }, row)
		UiKit.list(right, "x", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center })
		if r.delta then
			-- sign + word, never color alone
			UiKit.Tag(right, string.format(r.fmt, r.delta) .. (if r.better then "  better" else "  worse"), if r.better then "StateSuccess" else "StateWarning", { layoutOrder = 1 }).Name = "Delta"
		end
		UiKit.new("TextLabel", {
			Name = "Value",
			BackgroundTransparency = 1,
			FontFace = F.Numeric,
			TextSize = 17,
			TextColor3 = C.TextPrimary,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = r.value,
			LayoutOrder = 2,
		}, right)
		table.insert(statWidgets, row)
	end
end
---------------------------------------------------------------------
-- REQUESTS
---------------------------------------------------------------------

-- one request at a time; done(ok, message) is called with the server's answer (or a timeout)
local function send(action, itemId, qty, done)
	if pendingId then
		return false
	end
	local id = string.sub(HttpService:GenerateGUID(false), 1, 36)
	pendingId, pendingDone = id, done
	remotes.ShopRequest:FireServer(id, action, itemId, qty)
	task.delay(REQUEST_TIMEOUT, function()
		if pendingId == id then
			pendingId, pendingDone = nil, nil
			if done then
				done(false, "The Quartermaster didn't answer. Nothing was spent. Try again in a moment.")
			end
		end
	end)
	return true
end

---------------------------------------------------------------------
-- RENDERING
---------------------------------------------------------------------

local cards = {}

local function select(itemId)
	if selectedId and cards[selectedId] then
		cards[selectedId].setSelected(false)
	end
	selectedId = itemId
	quantity = 1
	if itemId and cards[itemId] then
		cards[itemId].setSelected(true)
	end
	if mode == "phone" and itemId then
		phoneView = "detail"
		layout()
	end
	renderDetail()
end

local function setBuy(text, enabled, reason)
	buyButton.Text = string.upper(text)
	buyButton:SetAttribute("BaseText", buyButton.Text)
	UiKit.SetDisabled(buyButton, not enabled, reason)
end

renderDetail = function()
	for _, child in dTags:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local item = selectedId and Items[selectedId]
	local show = item ~= nil and profile ~= nil
	detailEmpty.Visible = not show
	well.Visible = show
	info.Visible = show
	buyArea.Visible = show
	if not show then
		bigPreview:setModel(nil)
		return
	end
	bigPreview:setItem(selectedId)
	dName.Text = item.name
	UiKit.Tag(dTags, typeLabel(item), C[UiKit.CATEGORY[item.category] or "CatMaterials"], { layoutOrder = 1 })
	if isEquipped(selectedId) then
		UiKit.Badge(dTags, "equipped", nil, { layoutOrder = 2 })
	elseif owns(selectedId) then
		UiKit.Badge(dTags, "owned", nil, { layoutOrder = 2 })
	end
	dDesc.Text = item.description or ""
	renderStats(statRows(selectedId))
	local current = if item.kind == "Weapon" then profile.equippedWeapon elseif item.kind == "Armor" then profile.equippedArmor elseif item.kind == "Cosmetic" then (profile.equippedBeam or "BeamAmber") else nil
	compareCaption.Visible = current ~= nil and current ~= selectedId
	compareCaption.Text = if current then ("Compared with your equipped " .. Items[current].name .. ".") else ""
	strengthRow.Visible = item.strengths ~= nil
	tradeoffRow.Visible = item.tradeoffs ~= nil
	strengthText.Text = item.strengths or ""
	tradeoffText.Text = item.tradeoffs or ""

	-- price tag, affordability and the buy button
	local isAmmo = item.kind == "Ammo"
	stepper.Visible = isAmmo
	priceHolder.Visible = true
	local tagHeight = if isAmmo then 172 else 124
	buyArea.Size = UDim2.new(buyArea.Size.X.Scale, buyArea.Size.X.Offset, 0, tagHeight)
	-- the info scroll fills whatever the price tag leaves
	local detailH = detail.AbsoluteSize.Y
	if detailH > 0 then
		info.Size = UDim2.new(0, info.Size.X.Offset, 0, math.max(60, detailH - info.Position.Y.Offset - tagHeight - 10))
	end
	affordText.Position = UDim2.fromOffset(0, if isAmmo then 80 else 32)
	local balance = pearls()
	affordText.TextColor3 = C.TextMuted
	if isAmmo then
		local room, afford, max = ammoRoom(selectedId)
		quantity = math.clamp(quantity, if max > 0 then 1 else 0, math.max(max, 0))
		qtyLabel.Text = tostring(quantity)
		UiKit.SetDisabled(minusButton, quantity <= 1)
		UiKit.SetDisabled(plusButton, quantity >= max)
		UiKit.SetDisabled(maxButton, max <= 1 or quantity == max)
		local total = item.price * math.max(quantity, 1)
		priceLabel.Text = if quantity > 1 then string.format("PRICE · %d CRATES", quantity) else "PRICE · 1 CRATE"
		priceDisplay.set(total)
		if room <= 0 then
			affordText.Text = string.format("Your stack is full (%d / %d). Use some in a cannon first.", count(selectedId), item.maxStack)
			affordText.TextColor3 = C.StateWarning
			setBuy("Stack full", false, "You can carry at most " .. item.maxStack .. " crates.")
		elseif afford <= 0 then
			affordText.Text = string.format("You need %d more Pearls for one crate.", item.price - balance)
			affordText.TextColor3 = C.StateDanger
			setBuy(string.format("Need %d more", item.price - balance), false, "Earn Pearls by surviving nights.")
		else
			affordText.Text = string.format("You carry %d / %d. Room for %d more; you can afford %d.", count(selectedId), item.maxStack, room, afford)
			setBuy(string.format("Buy %d for %d Pearls", quantity, total), pendingId == nil)
		end
	else
		local starter = (item.price or 0) <= 0
		priceLabel.Text = if starter then "STARTER GEAR" else "PRICE"
		priceHolder.Visible = not starter
		priceDisplay.set(item.price or 0)
		if owns(selectedId) then
			affordText.Text = if isEquipped(selectedId) then "You own this and have it equipped." else "You own this. Equip it from your BAG."
			affordText.TextColor3 = C.StateSuccess
			setBuy(if isEquipped(selectedId) then "Equipped" else "Owned", false, "You already own this. Find it in your BAG.")
		elseif balance < (item.price or 0) then
			affordText.Text = string.format("You have %d Pearls. You need %d more.", balance, item.price - balance)
			affordText.TextColor3 = C.StateDanger
			setBuy(string.format("Need %d more", item.price - balance), false, "Earn Pearls by surviving nights.")
		else
			affordText.Text = string.format("You have %d Pearls. %d left after buying.", balance, balance - item.price)
			setBuy(string.format("Buy for %d Pearls", item.price), pendingId == nil)
		end
	end
end

local function cellSize(gridWidth)
	local minCard = if mode == "phone" then 132 else 156
	local gap = 10
	local usable = gridWidth - 12 - 8
	local columns = math.max(1, math.floor((usable + gap) / (minCard + gap)))
	local w = math.floor((usable - gap * (columns - 1)) / columns)
	return w, math.floor(w * (if mode == "phone" then 1.22 else 1.32))
end

renderGrid = function()
	for _, card in cards do
		card.frame:Destroy()
	end
	table.clear(cards)
	if gridState then
		gridState:Destroy()
		gridState = nil
	end
	purse.set(pearls())
	if not profile then
		gridState = UiKit.StateView(gridCol, "loading", { title = "Opening the counter", body = "The Quartermaster is checking your account." })
		gridState.Position = UDim2.fromOffset(0, 56)
		gridState.Size = UDim2.new(1, 0, 1, -56)
		renderDetail()
		return
	end
	local list = itemsIn(category)
	if #list == 0 then
		gridState = UiKit.StateView(gridCol, "empty", { title = "Nothing on this shelf", body = "The Quartermaster has nothing in this category right now." })
		gridState.Position = UDim2.fromOffset(0, 56)
		gridState.Size = UDim2.new(1, 0, 1, -56)
	end
	local balance = pearls()
	for order, itemId in list do
		local item = Items[itemId]
		local qty = count(itemId)
		local owned = owns(itemId)
		local price = item.price or 0
		local full = item.kind == "Ammo" and qty >= item.maxStack
		local card = UiKit.ItemCard(gridScroll, {
			itemId = itemId,
			name = item.name,
			category = item.category,
			subtitle = if item.kind == "Ammo" then (Ammo[item.ammoType].shotsPerLoad .. " shots / crate") elseif item.kind == "Weapon" then "Weapon" else typeLabel(item),
			quantity = if item.kind == "Ammo" and qty > 0 then qty else nil,
			price = if price > 0 then { kind = "Pearls", amount = price } else nil,
			shortBy = if balance < price then price - balance else nil,
			affordable = balance >= price,
			owned = owned,
			equipped = isEquipped(itemId),
			locked = if full then "Stack full" else nil,
			selected = itemId == selectedId,
			layoutOrder = order,
			onClick = function(id)
				select(id)
			end,
		})
		cards[itemId] = card
	end
	if selectedId and not cards[selectedId] then
		selectedId = nil
	end
	if not selectedId and mode ~= "phone" and list[1] then
		selectedId = list[1]
		cards[list[1]].setSelected(true)
	end
	renderDetail()
end

---------------------------------------------------------------------
-- BUYING (through the purchase dialog's ledger)
---------------------------------------------------------------------

local function startPurchase()
	local item = selectedId and Items[selectedId]
	if not item or pendingId or dialog then
		return
	end
	local itemId = selectedId
	local qty = if item.kind == "Ammo" then quantity else 1
	if qty < 1 then
		return
	end
	local name = if qty > 1 then string.format("%s  x%d", item.name, qty) else item.name
	dialog = UiKit.PurchaseDialog(root, {
		itemId = itemId,
		name = name,
		description = item.description,
		category = item.category,
		effect = "gameplay",
		eyebrow = "The Quartermaster",
		price = { kind = "Pearls", amount = item.price * qty },
		balance = pearls(),
		owned = item.kind ~= "Ammo" and owns(itemId),
		successText = if item.kind == "Ammo" then "loaded into your supplies. Cannons use them automatically." else nil,
		onPurchase = function(done)
			local sent = send("buy", itemId, qty, function(ok, message)
				SoundFx.play2D(if ok then "build" else "denied")
				done(ok, if ok then nil else message)
				renderDetail()
			end)
			if not sent then
				done(false, "Another purchase is still being processed. Nothing was spent.")
			end
			renderDetail()
		end,
		onClose = function()
			dialog = nil
			renderDetail()
		end,
	})
end

buyButton.Activated:Connect(function()
	if buyButton:GetAttribute("Disabled") then
		SoundFx.play2D("denied")
		return
	end
	startPurchase()
end)
minusButton.Activated:Connect(function()
	quantity = math.max(1, quantity - 1)
	renderDetail()
end)
plusButton.Activated:Connect(function()
	local _, _, max = ammoRoom(selectedId)
	quantity = math.min(max, quantity + 1)
	renderDetail()
end)
maxButton.Activated:Connect(function()
	local _, _, max = ammoRoom(selectedId)
	quantity = math.max(1, max)
	renderDetail()
end)
---------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------

local function place(frame, x, y, w, h)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.Visible = true
end

function layout()
	local size = root.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local W, H = size.X, size.Y
	mode = if W < 760 or H < 500 then "phone" elseif W >= 1180 and H >= 680 then "wide" else "medium"
	local pw, ph
	if mode == "phone" then
		pw, ph = W, H
	elseif mode == "wide" then
		pw, ph = math.min(W - 64, 1120), math.min(H - 64, 700)
	else
		pw, ph = math.min(W - 32, 1100), math.min(H - 32, 700)
	end
	panel.Size = UDim2.fromOffset(pw, ph)
	panel:SetAttribute("RestPosition", UDim2.fromScale(0.5, 0.5))
	local phone = mode == "phone"
	local pad = if phone then 10 else 20
	local headerTop = if phone then 6 else 14
	local headerH = if phone then 46 else 64
	header.Position = UDim2.fromOffset(pad, headerTop)
	header.Size = UDim2.new(1, -pad * 2, 0, headerH)
	local bodyTop = headerTop + headerH + (if phone then 6 else 10)
	body.Position = UDim2.fromOffset(pad, bodyTop)
	body.Size = UDim2.new(1, -pad * 2, 1, -bodyTop - pad)
	local bw, bh = pw - pad * 2, ph - bodyTop - pad

	local inDetail = phone and phoneView == "detail"
	eyebrow.Visible = not phone
	greeting.Visible = not phone
	title.Text = if phone then "Quartermaster" else "The Quartermaster"
	title.TextSize = if phone then 20 else 23
	titleBlock.Visible = not inDetail
	backButton.Visible = inDetail
	purse.frame.Position = UDim2.new(1, -56, 0.5, 0)

	local function layoutDetail(w, h, side)
		local tagH = buyArea.Size.Y.Offset > 0 and buyArea.Size.Y.Offset or 110
		if side then
			local pwid = math.floor(w * 0.38)
			well.Position, well.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(pwid, h)
			info.Position = UDim2.fromOffset(pwid + 14, 0)
			info.Size = UDim2.fromOffset(w - pwid - 14, h - tagH - 8)
			buyArea.AnchorPoint = Vector2.new(0, 1)
			buyArea.Position = UDim2.new(0, pwid + 14, 1, 0)
			buyArea.Size = UDim2.new(0, w - pwid - 14, 0, tagH)
		else
			local wellH = math.clamp(math.floor(h * 0.3), 120, 200)
			well.Position, well.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(w, wellH)
			info.Position = UDim2.fromOffset(0, wellH + 12)
			info.Size = UDim2.fromOffset(w, h - wellH - 12 - tagH - 10)
			buyArea.AnchorPoint = Vector2.new(0, 1)
			buyArea.Position = UDim2.new(0, 0, 1, 0)
			buyArea.Size = UDim2.new(1, 0, 0, tagH)
		end
	end

	if phone then
		gridCol.Visible, detailCol.Visible = false, false
		if inDetail then
			place(detailCol, 0, 0, bw, bh)
			layoutDetail(bw, bh, true)
		else
			place(gridCol, 0, 0, bw, bh)
		end
	else
		local detailW = if mode == "wide" then 360 else 320
		place(gridCol, 0, 0, bw - detailW - 18, bh)
		place(detailCol, bw - detailW, 0, detailW, bh)
		layoutDetail(detailW, bh, false)
	end
	local cw, ch = cellSize(gridCol.Size.X.Offset)
	gridLayout.CellSize = UDim2.fromOffset(cw, ch)
	root:SetAttribute("NoticeTop", if phone then 6 else math.max(8, (H - ph) / 2 - 56))
	root:SetAttribute("NoticeWidth", if phone then 280 else nil)
	root:SetAttribute("NoticeLimit", if phone then 1 else 2)
	if isOpen then
		renderDetail()
	end
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if isOpen then
		layout()
	end
end)

---------------------------------------------------------------------
-- OPEN / CLOSE (the server decides; walking away closes it)
---------------------------------------------------------------------

function closeShop(reason, fromServer)
	if not isOpen then
		return
	end
	isOpen = false
	if dialog then
		-- a dialog left open (even mid-request) must not survive the counter closing
		local d = dialog
		dialog = nil
		pcall(function()
			d.close(false)
		end)
		if d.panel and d.panel.Parent then
			d.panel.Parent:Destroy()
		end
	end
	ContextActionService:UnbindAction("CloseShop")
	GuiService.SelectedObject = nil
	UiKit.popModal("Shop")
	if not fromServer then
		remotes.ShopRequest:FireServer("close", "close")
	end
	UiKit.Close(panel, function()
		if not isOpen then
			gui.Enabled = false
			scrimGui.Enabled = false
		end
	end)
	if reason then
		UiKit.Toast(noticeRoot, reason, "info")
	end
end

local function openShop(text)
	if isOpen then
		greeting.Text = "\u{201C}" .. (text or "Need equipment for the next storm?") .. "\u{201D}"
		return
	end
	isOpen = true
	gui.Enabled = true
	scrimGui.Enabled = true
	UiKit.pushModal("Shop")
	greeting.Text = "\u{201C}" .. (text or "Need equipment for the next storm?") .. "\u{201D}"
	phoneView = "items"
	quantity = 1
	layout()
	if mode == "phone" then
		selectedId = nil
	end
	renderGrid()
	layout()
	UiKit.Open(panel)
	ContextActionService:BindAction("CloseShop", function(_, state)
		if state == Enum.UserInputState.Begin and not dialog then
			if mode == "phone" and phoneView == "detail" then
				phoneView = "items"
				layout()
			else
				closeShop(nil, false)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	task.defer(function()
		if UiKit.usingGamepad() then
			GuiService.SelectedObject = (selectedId and cards[selectedId] and cards[selectedId].frame) or tabs.buttons[category].button
		end
	end)
end

scrim.Activated:Connect(function()
	if not dialog then
		closeShop(nil, false)
	end
end)

remotes.ShopOpen.OnClientEvent:Connect(function(open, text)
	if open then
		openShop(text)
	else
		closeShop(text, true)
	end
end)

remotes.ShopResult.OnClientEvent:Connect(function(requestId, ok, message)
	if requestId ~= pendingId then
		return
	end
	local done = pendingDone
	pendingId, pendingDone = nil, nil
	if done then
		done(ok, message)
	elseif isOpen then
		UiKit.Toast(root, message, if ok then "success" else "danger")
	end
end)

remotes.GearData.OnClientEvent:Connect(function(data)
	profile = data
	if isOpen then
		renderGrid()
	end
end)

---------------------------------------------------------------------
-- STUDIO ONLY: draw the counter inside a simulated screen (HudSimulate attribute)
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
				renderGrid()
				layout()
			end
		end)
	end
	player:GetAttributeChangedSignal("HudSimulate"):Connect(applySimulation)
	applySimulation()
end

remotes.GearAction:FireServer("sync")
