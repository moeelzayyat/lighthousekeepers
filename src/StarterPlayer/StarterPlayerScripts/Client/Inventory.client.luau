-- Inventory (client): the player's own Locker / Loadout. Opens anywhere once you're in the game:
-- the BAG button (top right), the B key, or D-pad Up on a controller.
--
-- Shows ONLY owned items. No shop, no prices, no buying. Equip / Unequip go to LoadoutService
-- (LoadoutRequest -> LoadoutResult), the profile arrives on GearData. Nothing here changes data.
--
-- Built on UiKit v2.1 (Stage 3 of the UI redesign).
--   Wide (desktop):  EQUIPPED slots | avatar | owned-item grid | selected-item details
--   Medium (tablet / laptop): avatar over slots | grid | details
--   Phone (landscape): ITEMS view (grid first) -> tap -> DETAIL view (Back); separate LOADOUT view
-- Studio only: player attribute HudSimulate = smallPhone / largePhone / tablet / laptop draws this
-- menu inside a screen of that exact size (shared with the HUD simulator).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Ammo = require(Shared:WaitForChild("Ammo"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))

local C, F = UiKit.Color, UiKit.Font
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ItemModels = ReplicatedStorage:WaitForChild("ItemModels")
local player = Players.LocalPlayer

local STARTERS = { Primary = "DriftwoodHarpoon", Armor = "OilskinCoat", Beam = "BeamAmber" }
local REQUEST_TIMEOUT = 8

local profile = nil
local isOpen = false
local filter = "All"
local selectedId = nil
local pendingId = nil
local mode = "wide" -- "wide" | "medium" | "phone"
local phoneView = "items" -- "items" | "detail" | "loadout"
local simulated = nil
local layout, setOpen, cardsFocusTarget -- forward declarations

---------------------------------------------------------------------
-- FACTS
---------------------------------------------------------------------

local function count(itemId)
	return if profile then (profile.counts[itemId] or 0) else 0
end
local function owns(itemId)
	return profile ~= nil and (profile.owned[itemId] == true or count(itemId) > 0)
end
local function isEquipped(itemId)
	return profile ~= nil and (profile.equippedWeapon == itemId or profile.equippedArmor == itemId)
end
local function dps(weaponId)
	local w = Weapons[weaponId]
	return w.damage / w.cooldown
end
local function equippedFor(slot)
	if not profile then
		return nil
	end
	return if slot == "Primary" then profile.equippedWeapon elseif slot == "Armor" then profile.equippedArmor elseif slot == "Beam" then (profile.equippedBeam or "BeamAmber") else nil
end
local function typeLabel(item)
	if item.kind == "Weapon" then
		return "Primary weapon"
	elseif item.kind == "Armor" then
		return "Armor"
	elseif item.kind == "Ammo" then
		return "Cannon ammo"
	elseif item.kind == "Material" then
		return "Voyage loot"
	elseif item.kind == "Cosmetic" then
		return "Beam colour \u{00B7} looks only"
	end
	return item.category
end

-- Stat rows for an item: { label, value, delta = number or nil, better = true/false/nil }
-- delta compares with what is equipped in the same slot (nil when this IS the equipped item)
local function statRows(itemId)
	local item = Items[itemId]
	local rows = {}
	if item.kind == "Weapon" then
		local w = Weapons[itemId]
		local current = profile and profile.equippedWeapon
		local cw = current and current ~= itemId and Weapons[current]
		local function add(label, value, a, b, higherIsBetter, fmt)
			local delta, better
			if cw and a ~= b then
				delta = a - b
				better = if higherIsBetter then delta > 0 else delta < 0
			end
			table.insert(rows, { label = label, value = value, delta = delta, better = better, fmt = fmt })
		end
		add("Damage per hit", tostring(w.damage), w.damage, cw and cw.damage, true, "%+d")
		add("Reload", string.format("%.1f s", w.cooldown), w.cooldown, cw and cw.cooldown, false, "%+.1f s")
		add("Targets per throw", if w.maxTargets > 1 then ("up to " .. w.maxTargets) else "1", w.maxTargets, cw and cw.maxTargets, true, "%+d")
		add("Damage per second", tostring(math.floor(dps(itemId) + 0.5)), math.floor(dps(itemId) + 0.5), cw and math.floor(dps(current) + 0.5), true, "%+d")
	elseif item.kind == "Armor" then
		local current = profile and profile.equippedArmor
		local ca = current and current ~= itemId and Items[current]
		local function add(label, value, a, b, fmt)
			local delta, better
			if ca and a ~= b then
				delta = a - b
				better = delta > 0
			end
			table.insert(rows, { label = label, value = value, delta = delta, better = better, fmt = fmt })
		end
		add("Health", tostring(item.maxHealth), item.maxHealth, ca and ca.maxHealth, "%+d")
		local red = math.floor(item.damageReduction * 100 + 0.5)
		add("Damage blocked", red .. "%", red, ca and math.floor(ca.damageReduction * 100 + 0.5), "%+d%%")
	elseif item.kind == "Ammo" then
		local a = Ammo[item.ammoType]
		table.insert(rows, { label = "Crates", value = string.format("%d / %d", count(itemId), item.maxStack) })
		table.insert(rows, { label = "Shots per crate", value = tostring(a.shotsPerLoad) })
		table.insert(rows, { label = "Cannon damage", value = string.format("x%.1f", a.damageMultiplier) })
	elseif item.kind == "Material" then
		local n = count(itemId)
		table.insert(rows, { label = "Carried", value = tostring(n) })
		table.insert(rows, { label = "Trader pays each", value = (item.shellValue or 0) .. " Shells" })
		table.insert(rows, { label = "Worth now", value = (n * (item.shellValue or 0)) .. " Shells" })
	end
	return rows
end

local function ownedList()
	local list = {}
	for _, itemId in Items.SHOP_ORDER do
		local item = Items[itemId]
		if owns(itemId) and (filter == "All" or item.category == filter) then
			table.insert(list, itemId)
		end
	end
	return list
end

---------------------------------------------------------------------
-- SCREENS
---------------------------------------------------------------------

local scrimGui = UiKit.Screen("InventoryScrim", 17, true)
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

local gui = UiKit.Screen("Inventory", 18)
gui.Enabled = false
local root = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local rootOutline = UiKit.border(root, C.BorderFocus, 1, 0.4)
rootOutline.Enabled = false

local panel = UiKit.Panel(root, { name = "LockerPanel", kind = "housing", beam = true, padding = 0, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5) })
panel.ClipsDescendants = false

-- header ------------------------------------------------------------------
local header = UiKit.new("Frame", { Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 52) }, panel)
local titleBlock = UiKit.new("Frame", { Name = "TitleBlock", BackgroundTransparency = 1, Size = UDim2.new(0, 260, 1, 0) }, header)
UiKit.list(titleBlock, "y", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
local eyebrow = UiKit.Label(titleBlock, "Keeper's locker", "Eyebrow", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
local title = UiKit.Label(titleBlock, "Loadout", "H2", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })

local saveNote = UiKit.new("Frame", { Name = "SaveNote", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -56, 0.5, 0), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Visible = false }, header)
UiKit.list(saveNote, "x", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
UiKit.Glyph(saveNote, "warning", C.StateWarning, 14).LayoutOrder = 1
UiKit.Label(saveNote, "Saving is offline. Changes last until you leave.", "Micro", { LayoutOrder = 2, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextColor3 = C.StateWarning })

local phoneNav = UiKit.Tabs(header, { { id = "items", label = "Items" }, { id = "loadout", label = "Loadout" } }, {
	size = UDim2.fromOffset(240, 46),
	textSize = 16,
	minWidth = 100,
	onChange = function(id)
		phoneView = id
		layout()
	end,
})
phoneNav.frame.AnchorPoint = Vector2.new(0.5, 0.5)
phoneNav.frame.Position = UDim2.fromScale(0.5, 0.5)

local backButton = UiKit.Button(header, "Back", { name = "Back", variant = "secondary", size = "sm", minWidth = 96, onClick = function()
	phoneView = "items"
	layout()
	if cardsFocusTarget then
		cardsFocusTarget()
	end
end })
backButton.AnchorPoint = Vector2.new(0, 0.5)
backButton.Position = UDim2.new(0, 0, 0.5, 0)

local closeButton = UiKit.IconButton(header, "close", { name = "Close", quiet = true, tip = "Close", onClick = function()
	setOpen(false)
end })
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, 6, 0.5, 0)

local body = UiKit.new("Frame", { Name = "Body", BackgroundTransparency = 1 }, panel)

-- column containers (positioned by layout) ---------------------------------
local slotsCol = UiKit.new("Frame", { Name = "SlotsColumn", BackgroundTransparency = 1 }, body)
local avatarCol = UiKit.new("Frame", { Name = "AvatarColumn", BackgroundTransparency = 1 }, body)
local gridCol = UiKit.new("Frame", { Name = "GridColumn", BackgroundTransparency = 1 }, body)
local detailCol = UiKit.new("Frame", { Name = "DetailColumn", BackgroundTransparency = 1 }, body)

---------------------------------------------------------------------
-- EQUIPPED SLOTS
---------------------------------------------------------------------

local slotsList = UiKit.Scroll(slotsCol, { Name = "Slots", ScrollBarThickness = 4 }) -- scrolls only when a short screen needs it
UiKit.list(slotsList, "y", 8)
UiKit.pad(slotsList, 2, 6, 2, 0)
local slotsSection = UiKit.Section(slotsList, "Equipped", { layoutOrder = 1, gap = 8 })

local slotWidgets = {}
local function makeSlot(parent, order, key, label)
	local b = UiKit.new("TextButton", {
		Name = "Slot_" .. key,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.SurfaceSecondary,
		Size = UDim2.new(1, 0, 0, 66),
		LayoutOrder = order,
	}, parent)
	UiKit.round(b, UiKit.Radius.card)
	local stroke = UiKit.border(b, C.BorderSubtle, 1, 0.2)
	UiKit.focusable(b)
	local well = UiKit.Inset(b, { Name = "Well", Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(52, 52), ClipsDescendants = true })
	local icon = ItemPreview.new(well, {})
	local slotLabel = UiKit.Label(b, label, "Caption", { Position = UDim2.fromOffset(70, 10), Size = UDim2.new(1, -80, 0, 16), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false })
	local name = UiKit.Label(b, "", "H3", {
		Name = "ItemName",
		Position = UDim2.fromOffset(70, 28),
		Size = UDim2.new(1, -80, 0, 22),
		AutomaticSize = Enum.AutomaticSize.None,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 17,
	})
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = C.SurfaceHover
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = C.SurfaceSecondary
	end)
	slotWidgets[key] = { button = b, icon = icon, name = name, label = slotLabel, stroke = stroke }
	return b
end
makeSlot(slotsSection, 1, "Primary", "Primary weapon")
makeSlot(slotsSection, 2, "Armor", "Armor")
makeSlot(slotsSection, 3, "Beam", "Lamp beam colour") -- launch R15: looks only

-- supplies: Fire Shell crates are used automatically by cannons (not an equip slot)
local suppliesSection = UiKit.Section(slotsList, "Supplies", { layoutOrder = 2, gap = 8 })
makeSlot(suppliesSection, 1, "Ammo", "Cannon ammo")

-- loadout summary: what your gear adds up to
local summarySection = UiKit.Section(slotsList, "Your keeper", { layoutOrder = 3, gap = 6 })
local summaryRows = {}
local function summaryRow(order, label)
	local row = UiKit.new("Frame", { Name = "Summary_" .. order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order }, summarySection)
	UiKit.Label(row, label, "BodySmall", { Size = UDim2.new(0.62, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextYAlignment = Enum.TextYAlignment.Center })
	local value = UiKit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = F.Numeric,
		TextSize = 17,
		TextColor3 = C.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.38, 0, 1, 0),
	}, row)
	summaryRows[order] = value
	return value
end
summaryRow(1, "Health")
summaryRow(2, "Damage blocked")
summaryRow(3, "Weapon damage / s")
---------------------------------------------------------------------
-- AVATAR
---------------------------------------------------------------------

local avatarWell = UiKit.Inset(avatarCol, { Name = "AvatarWell", Size = UDim2.fromScale(1, 1), ClipsDescendants = true })
UiKit.border(avatarWell, C.BorderStructural, 1, 0.6)
local avatarPreview = ItemPreview.new(avatarWell, { rotatable = true })
UiKit.Label(avatarWell, "Drag to turn", "Micro", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(1, -16, 0, 16),
	AutomaticSize = Enum.AutomaticSize.None,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 4,
})

local function placeHeld(copy, hand, model)
	local held = model:Clone()
	local bboxCf, size = held:GetBoundingBox()
	local long = math.max(size.X, size.Y, size.Z)
	-- stand long weapons upright in the hand like a staff; small ones keep their own pose
	local rot = CFrame.new()
	if long >= 2 then
		if size.X == long then
			rot = CFrame.Angles(0, 0, math.rad(90))
		elseif size.Z == long then
			rot = CFrame.Angles(math.rad(-90), 0, 0)
		end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart")
	local yaw = if hrp then hrp.CFrame.Rotation else CFrame.new()
	local target = CFrame.new(hand.Position + Vector3.new(0, if long >= 2 then long * 0.22 else 0, 0)) * yaw * rot
	held:PivotTo(target * bboxCf:ToObjectSpace(held:GetPivot()))
	held.Parent = copy
end

local function refreshAvatar()
	local character = player.Character
	if not character or not profile then
		return
	end
	character.Archivable = true
	local copy = character:Clone()
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("Tool") or d:IsA("BillboardGui") or d.Name == "CarriedOil" then
			d:Destroy()
		end
	end
	local hand = copy:FindFirstChild("RightHand") or copy:FindFirstChild("Right Arm")
	local weaponItem = Items[profile.equippedWeapon]
	local weaponModel = weaponItem and ItemModels:FindFirstChild(weaponItem.model)
	if hand and weaponModel then
		pcall(placeHeld, copy, hand, weaponModel)
	end
	avatarPreview:setModel(copy, "Avatar")
	copy:Destroy()
end

---------------------------------------------------------------------
-- GRID
---------------------------------------------------------------------

local filterItems = {}
for _, name in Items.INVENTORY_FILTERS do
	-- short labels so all five fit on one row at every size
	local short = ({ Ammunition = "Ammo", Materials = "Loot" })[name] or name
	table.insert(filterItems, { id = name, label = short, color = if name == "All" then nil else UiKit.CATEGORY[name] })
end
local renderGrid
local filterTabs = UiKit.Tabs(gridCol, filterItems, {
	size = UDim2.new(1, 0, 0, 46),
	textSize = 16,
	minWidth = 0,
	shoulders = true,
	onChange = function(id)
		filter = id
		selectedId = nil
		renderGrid()
	end,
})
local gridScroll = UiKit.Scroll(gridCol, { Name = "Grid", Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56) })
local gridLayout = UiKit.new("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, gridScroll)
UiKit.pad(gridScroll, 6, 6, 6, 6)
local gridState = nil -- StateView shown instead of cards

---------------------------------------------------------------------
-- DETAIL
---------------------------------------------------------------------

local detail = UiKit.new("Frame", { Name = "Detail", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, detailCol)
local detailWell = UiKit.Inset(detail, { Name = "PreviewWell", ClipsDescendants = true })
local bigPreview = ItemPreview.new(detailWell, { rotatable = true })
local detailInfo = UiKit.Scroll(detail, { Name = "Info", ScrollBarThickness = 4 })
UiKit.list(detailInfo, "y", 8)
UiKit.pad(detailInfo, 0, 6, 8, 0)

local dName = UiKit.Label(detailInfo, "", "H2", { Name = "ItemName", LayoutOrder = 1 })
local dTags = UiKit.new("Frame", { Name = "Tags", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2 }, detailInfo)
UiKit.list(dTags, "x", 6)
local dDesc = UiKit.Label(detailInfo, "", "BodySmall", { Name = "Description", LayoutOrder = 3, TextColor3 = C.TextPrimary })
local statsSection = UiKit.Section(detailInfo, "Stats", { layoutOrder = 4, gap = 4 })
local compareCaption = UiKit.Label(detailInfo, "", "Micro", { Name = "CompareCaption", LayoutOrder = 5 })
local tradeFrame = UiKit.new("Frame", { Name = "Tradeoffs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6 }, detailInfo)
UiKit.list(tradeFrame, "y", 4)
local function tradeLine(order, glyph, color)
	local row = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, tradeFrame)
	local g = UiKit.Glyph(row, glyph, color, 14)
	g.Position = UDim2.fromOffset(0, 2)
	local text = UiKit.Label(row, "", "BodySmall", { Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 0, 0), TextColor3 = C.TextPrimary })
	return row, text
end
local strengthRow, strengthText = tradeLine(1, "plus", C.StateSuccess)
local tradeoffRow, tradeoffText = tradeLine(2, "minus", C.StateWarning)
local statusText = UiKit.Label(detailInfo, "", "Micro", { Name = "Status", LayoutOrder = 7 })

local actionButton = UiKit.Button(detail, "Equip", { name = "EquipButton", variant = "primary", size = "md", fill = true })
actionButton.AnchorPoint = Vector2.new(0, 1)
actionButton.Position = UDim2.fromScale(0, 1)

local detailEmpty = UiKit.StateView(detail, "empty", { title = "Nothing selected", body = "Pick an item or an equipped slot to see its details." })
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
			local text = string.format(r.fmt, r.delta)
			local tag = UiKit.Tag(right, text .. (if r.better then "  better" else "  worse"), if r.better then "StateSuccess" else "StateWarning", { layoutOrder = 1 })
			tag.Name = "Delta"
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
-- RENDERING
---------------------------------------------------------------------

local cards = {}

local function renderSlots()
	if not profile then
		return
	end
	for key, w in slotWidgets do
		local itemId = if key == "Primary" then profile.equippedWeapon elseif key == "Armor" then profile.equippedArmor elseif key == "Beam" then (profile.equippedBeam or "BeamAmber") else nil
		if key == "Ammo" then
			local crates = count("FireShellCrate")
			if crates > 0 then
				w.icon:setItem("FireShellCrate")
				w.name.Text = string.format("Fire Shells  x%d", crates)
				w.name.TextColor3 = C.TextPrimary
			else
				w.icon:setModel(nil)
				w.name.Text = "None: cannons use oil"
				w.name.TextColor3 = C.TextMuted
			end
			itemId = if crates > 0 then "FireShellCrate" else nil
		else
			w.icon:setItem(itemId)
			w.name.Text = if itemId and Items[itemId] then Items[itemId].name else "Empty"
			w.name.TextColor3 = C.TextPrimary
		end
		local selected = itemId ~= nil and itemId == selectedId
		w.stroke.Color = if selected then C.BorderSelected else C.BorderSubtle
		w.stroke.Transparency = if selected then 0 else 0.2
	end
	local armor = Items[profile.equippedArmor]
	summaryRows[1].Text = tostring(armor and armor.maxHealth or 100)
	summaryRows[2].Text = (if armor then math.floor(armor.damageReduction * 100 + 0.5) else 0) .. "%"
	summaryRows[3].Text = if Weapons[profile.equippedWeapon] then tostring(math.floor(dps(profile.equippedWeapon) + 0.5)) else "-"
end

local renderDetail

local function select(itemId)
	if selectedId and cards[selectedId] then
		cards[selectedId].setSelected(false)
	end
	selectedId = itemId
	if itemId and cards[itemId] then
		cards[itemId].setSelected(true)
	end
	if mode == "phone" and itemId then
		phoneView = "detail"
		layout()
	end
	renderSlots()
	renderDetail()
end

local function setPending(id)
	pendingId = id
	if id then
		task.delay(REQUEST_TIMEOUT, function()
			if pendingId == id then
				pendingId = nil
				UiKit.Toast(root, "No reply from the server. Your loadout didn't change. Try again.", "danger")
				renderDetail()
			end
		end)
	end
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
	detailWell.Visible = show
	detailInfo.Visible = show
	actionButton.Visible = false
	if not show then
		bigPreview:setModel(nil)
		return
	end
	bigPreview:setItem(selectedId)
	dName.Text = item.name
	UiKit.Tag(dTags, typeLabel(item), C[UiKit.CATEGORY[item.category] or "CatMaterials"], { layoutOrder = 1 })
	local equipped = isEquipped(selectedId)
	if equipped then
		UiKit.Badge(dTags, "equipped", nil, { layoutOrder = 2 })
	elseif item.slot then
		UiKit.Badge(dTags, "owned", nil, { layoutOrder = 2 })
	end
	if item.runScoped then
		UiKit.Tag(dTags, "This voyage", "AccentSea", { layoutOrder = 3 })
	end
	dDesc.Text = item.description or ""
	renderStats(statRows(selectedId))
	local current = item.slot and equippedFor(item.slot)
	if item.slot and current and current ~= selectedId then
		compareCaption.Text = "Compared with your equipped " .. Items[current].name .. "."
		compareCaption.Visible = true
	else
		compareCaption.Visible = false
	end
	strengthRow.Visible = item.strengths ~= nil
	tradeoffRow.Visible = item.tradeoffs ~= nil
	strengthText.Text = item.strengths or ""
	tradeoffText.Text = item.tradeoffs or ""

	if not item.slot then
		statusText.Text = if item.kind == "Ammo"
			then "Used automatically when you reload a cannon. Nothing to equip."
			else "Loot lasts one voyage. Sell it to the Trader on the lighthouse island for Shells."
		statusText.TextColor3 = C.TextMuted
		return
	end
	actionButton.Visible = true
	local isStarter = STARTERS[item.slot] == selectedId
	if pendingId then
		UiKit.SetBusy(actionButton, true, if equipped then "Unequipping..." else "Equipping...")
		statusText.Text = "Updating your loadout..."
		statusText.TextColor3 = C.TextMuted
		return
	end
	UiKit.SetBusy(actionButton, false)
	local function label(text)
		actionButton.Text = text
		actionButton:SetAttribute("BaseText", text)
	end
	if equipped and isStarter then
		label("EQUIPPED")
		UiKit.SetDisabled(actionButton, true, "Starter gear stays on until you equip something else.")
		statusText.Text = "Starter gear stays on until you equip something else."
	elseif equipped then
		label("UNEQUIP")
		UiKit.SetDisabled(actionButton, false)
		statusText.Text = "Unequipping switches back to your " .. Items[STARTERS[item.slot]].name .. "."
	else
		label("EQUIP")
		UiKit.SetDisabled(actionButton, false)
		statusText.Text = if current then ("Replaces your " .. Items[current].name .. ". You keep both.") else ""
	end
	statusText.TextColor3 = C.TextMuted
end

local function cellSize(gridWidth)
	local minCard = if mode == "phone" then 132 else 150
	local gap = 10
	local usable = gridWidth - 12 - 8 -- padding + scrollbar
	local columns = math.max(1, math.floor((usable + gap) / (minCard + gap)))
	local w = math.floor((usable - gap * (columns - 1)) / columns)
	local h = math.floor(w * (if mode == "phone" then 1.22 else 1.3))
	return w, h
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
	if not profile then
		gridState = UiKit.StateView(gridCol, "loading", { title = "Opening your locker", body = "Fetching your gear from the harbor." })
		gridState.Position = UDim2.fromOffset(0, 56)
		gridState.Size = UDim2.new(1, 0, 1, -56)
		renderDetail()
		return
	end
	local list = ownedList()
	if #list == 0 then
		local titleText, bodyText = "Nothing here yet", "Gear you own shows up here."
		if filter == "Materials" then
			titleText, bodyText = "No loot right now", "Creatures drop claws, sea glass and pearls during a voyage. Loot lasts one voyage."
		elseif filter == "Ammunition" then
			titleText, bodyText = "No ammo crates", "Cannons use oil from the island. The Quartermaster at the harbor sells Fire Shell crates."
		end
		gridState = UiKit.StateView(gridCol, "empty", { title = titleText, body = bodyText })
		gridState.Position = UDim2.fromOffset(0, 56)
		gridState.Size = UDim2.new(1, 0, 1, -56)
	end
	for order, itemId in list do
		local item = Items[itemId]
		local qty = count(itemId)
		local card = UiKit.ItemCard(gridScroll, {
			itemId = itemId,
			name = item.name,
			category = item.category,
			subtitle = typeLabel(item),
			quantity = if qty > 0 then qty else nil,
			equipped = isEquipped(itemId),
			selected = itemId == selectedId,
			layoutOrder = order,
			onClick = function(id)
				select(id)
			end,
		})
		cards[itemId] = card
	end
	if selectedId and not cards[selectedId] and not isEquipped(selectedId) then
		selectedId = nil
	end
	if not selectedId and mode ~= "phone" and list[1] then
		selectedId = list[1]
		cards[list[1]].setSelected(true)
	end
	renderSlots()
	renderDetail()
end

local function renderAll()
	renderGrid()
	refreshAvatar()
end

cardsFocusTarget = function()
	if not UiKit.usingGamepad() then
		return
	end
	local target = (selectedId and cards[selectedId] and cards[selectedId].frame) or filterTabs.buttons[filter].button
	GuiService.SelectedObject = target
end
---------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------

local function place(frame, x, y, w, h)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.Visible = true
end
local function setBox(frame, x, y, w, h)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
end

function layout()
	local size = root.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local W, H = size.X, size.Y
	mode = if W < 760 or H < 500 then "phone" elseif W >= 1300 and H >= 700 then "wide" else "medium"
	local pw, ph
	if mode == "phone" then
		pw, ph = W, H
	elseif mode == "wide" then
		pw, ph = math.min(W - 64, 1240), math.min(H - 64, 720)
	else
		pw, ph = math.min(W - 32, 1180), math.min(H - 32, 720)
	end
	panel.Size = UDim2.fromOffset(pw, ph)
	panel:SetAttribute("RestPosition", UDim2.fromScale(0.5, 0.5))
	local phone = mode == "phone"
	local pad = if phone then 10 else 20
	local headerH = if phone then 46 else 52
	local headerTop = if phone then 6 else 14
	header.Position = UDim2.fromOffset(pad, headerTop)
	header.Size = UDim2.new(1, -pad * 2, 0, headerH)
	local bodyTop = headerTop + headerH + (if phone then 6 else 12)
	body.Position = UDim2.fromOffset(pad, bodyTop)
	body.Size = UDim2.new(1, -pad * 2, 1, -bodyTop - pad)
	local bw, bh = pw - pad * 2, ph - bodyTop - pad

	-- header contents
	eyebrow.Visible = not phone
	title.Text = if phone then "Locker" else "Loadout"
	title.TextSize = if phone then 20 else 23
	titleBlock.Size = UDim2.new(0, if phone then 120 else 260, 1, 0)
	phoneNav.frame.Visible = phone and phoneView ~= "detail"
	backButton.Visible = phone and phoneView == "detail"
	titleBlock.Visible = not (phone and phoneView == "detail")
	saveNote.Visible = player:GetAttribute("SaveUnavailable") == true and not phone
	if phone and phoneView ~= "detail" then
		phoneNav.set(phoneView, true)
	end

	-- detail internals (shared by every mode)
	local function layoutDetail(w, h, side)
		local buttonH = 48
		if side then
			-- phone detail: preview on the left, info on the right
			local pwid = math.floor(w * 0.4)
			setBox(detailWell, 0, 0, pwid, h)
			detailInfo.Position = UDim2.fromOffset(pwid + 14, 0)
			detailInfo.Size = UDim2.fromOffset(w - pwid - 14, h - buttonH - 10)
			actionButton.Position = UDim2.new(0, pwid + 14, 1, 0)
			actionButton.Size = UDim2.fromOffset(w - pwid - 14, buttonH)
		else
			local wellH = math.clamp(math.floor(h * 0.3), 120, 190)
			setBox(detailWell, 0, 0, w, wellH)
			detailInfo.Position = UDim2.fromOffset(0, wellH + 12)
			detailInfo.Size = UDim2.fromOffset(w, h - wellH - 12 - buttonH - 12)
			actionButton.Position = UDim2.new(0, 0, 1, 0)
			actionButton.Size = UDim2.new(1, 0, 0, buttonH)
		end
	end

	local gap = 16
	if mode == "wide" then
		local slotsW, avatarW, detailW = 250, 250, 300
		local gridW = bw - slotsW - avatarW - detailW - gap * 3
		place(slotsCol, 0, 0, slotsW, bh)
		place(slotsList, 0, 0, slotsW, bh)
		place(avatarCol, slotsW + gap, 0, avatarW, bh)
		place(gridCol, slotsW + avatarW + gap * 2, 0, gridW, bh)
		place(detailCol, bw - detailW, 0, detailW, bh)
		layoutDetail(detailW, bh, false)
		summarySection.Visible = true
	elseif mode == "medium" then
		local leftW, detailW = 250, 290
		local gridW = bw - leftW - detailW - gap * 2
		local avatarH = math.floor(bh * 0.4)
		place(avatarCol, 0, 0, leftW, avatarH)
		place(slotsCol, 0, avatarH + 12, leftW, bh - avatarH - 12)
		place(slotsList, 0, 0, leftW, bh - avatarH - 12)
		place(gridCol, leftW + gap, 0, gridW, bh)
		place(detailCol, bw - detailW, 0, detailW, bh)
		layoutDetail(detailW, bh, false)
		summarySection.Visible = false
	else
		slotsCol.Visible, avatarCol.Visible, gridCol.Visible, detailCol.Visible = false, false, false, false
		if phoneView == "items" then
			place(gridCol, 0, 0, bw, bh)
		elseif phoneView == "detail" then
			place(detailCol, 0, 0, bw, bh)
			layoutDetail(bw, bh, true)
		else
			local avatarW = math.floor(bw * 0.42)
			place(avatarCol, 0, 0, avatarW, bh)
			place(slotsCol, avatarW + 14, 0, bw - avatarW - 14, bh)
			place(slotsList, 0, 0, bw - avatarW - 14, bh)
			summarySection.Visible = true
		end
	end
	if isOpen then
		renderDetail()
	end
	local cw, ch = cellSize(gridCol.Size.X.Offset)
	gridLayout.CellSize = UDim2.fromOffset(cw, ch)
	-- notices: above the panel on big screens, at the very top on phones
	root:SetAttribute("NoticeTop", if phone then 6 else math.max(8, (H - ph) / 2 - 56))
	root:SetAttribute("NoticeWidth", if phone then 280 else nil)
	root:SetAttribute("NoticeLimit", if phone then 1 else 2)
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if isOpen then
		layout()
	end
end)

---------------------------------------------------------------------
-- OPEN / CLOSE
---------------------------------------------------------------------

function setOpen(open)
	if open == isOpen then
		return
	end
	isOpen = open
	if open then
		gui.Enabled = true
		scrimGui.Enabled = true
		UiKit.pushModal("Inventory")
		phoneView = "items"
		layout()
		if mode == "phone" then
			selectedId = nil
		end
		renderAll()
		layout()
		UiKit.Open(panel)
		ContextActionService:BindAction("CloseInventory", function(_, state)
			if state == Enum.UserInputState.Begin then
				if mode == "phone" and phoneView == "detail" then
					phoneView = "items"
					layout()
				else
					setOpen(false)
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
		task.defer(cardsFocusTarget)
	else
		ContextActionService:UnbindAction("CloseInventory")
		GuiService.SelectedObject = nil
		UiKit.popModal("Inventory")
		-- the Quartermaster's shop may be opening right now: keep gameplay input locked for it
		local shop = player.PlayerGui:FindFirstChild("QuartermasterShop")
		if shop and shop.Enabled then
			player:SetAttribute("MenuOpen", true)
		end
		UiKit.Close(panel, function()
			if not isOpen then
				gui.Enabled = false
				scrimGui.Enabled = false
			end
		end)
	end
end

scrim.Activated:Connect(function()
	setOpen(false)
end)

-- slot clicks select the equipped item
for key, w in slotWidgets do
	w.button.Activated:Connect(function()
		UiKit.click()
		if not profile then
			return
		end
		local id = if key == "Primary" then profile.equippedWeapon
			elseif key == "Armor" then profile.equippedArmor
			elseif key == "Beam" then (profile.equippedBeam or "BeamAmber")
			elseif count("FireShellCrate") > 0 then "FireShellCrate" else nil
		if id then
			select(id)
		end
	end)
end

actionButton.Activated:Connect(function()
	if actionButton:GetAttribute("Disabled") or not selectedId or pendingId then
		return
	end
	local action = if isEquipped(selectedId) then "unequip" else "equip"
	setPending(string.sub(HttpService:GenerateGUID(false), 1, 36))
	remotes.LoadoutRequest:FireServer(pendingId, action, selectedId)
	renderDetail()
end)

local function flashSlot(itemId)
	local item = Items[itemId]
	local w = item and item.slot and slotWidgets[item.slot]
	if not w then
		return
	end
	w.stroke.Color = C.StateSuccess
	w.stroke.Transparency = 0
	task.delay(0.6, renderSlots)
end

remotes.LoadoutResult.OnClientEvent:Connect(function(requestId, ok, message)
	if requestId ~= pendingId then
		return
	end
	local itemId = selectedId
	pendingId = nil
	if isOpen then
		UiKit.Toast(root, message or (if ok then "Loadout updated." else "That didn't work. Your loadout didn't change."), if ok then "success" else "danger")
		if ok then
			flashSlot(itemId)
		end
		renderDetail()
	end
end)

remotes.GearData.OnClientEvent:Connect(function(data)
	profile = data
	if isOpen then
		renderGrid()
		-- the server puts new armor on the character a moment after the data changes
		task.delay(0.35, function()
			if isOpen then
				refreshAvatar()
			end
		end)
	end
end)

player:GetAttributeChangedSignal("SaveUnavailable"):Connect(function()
	if isOpen then
		layout()
	end
end)

-- Opening the Quartermaster's shop closes the locker
remotes.ShopOpen.OnClientEvent:Connect(function(open)
	if open then
		setOpen(false)
	end
end)

---------------------------------------------------------------------
-- BAG BUTTON (HUD, top right)
---------------------------------------------------------------------

-- Owner, Oct 13: a small round glass bag icon (mock-up) instead of the BAG bar. Touch screens: left of
-- the jump button. Mouse/keyboard: bottom-right, above the Shells pill, with a "B" hint.
local hud = UiKit.Screen("InventoryButton", 4)
local bagButton = UiKit.new("TextButton", {
	Name = "BagButton",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.fromRGB(12, 20, 40),
	BackgroundTransparency = 0.18,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -76),
	Size = UDim2.fromOffset(54, 54),
}, hud)
UiKit.round(bagButton, 27)
UiKit.border(bagButton, Color3.fromRGB(104, 156, 255), 1.5, 0.35)
UiKit.focusable(bagButton)
do
	-- drawn backpack: body, handle, pocket (white outlines)
	local icon = UiKit.new("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(24, 26) }, bagButton)
	local function outline(position, size, radius)
		local f = UiKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = position, Size = size }, icon)
		UiKit.round(f, radius)
		UiKit.border(f, Color3.fromRGB(240, 244, 255), 2, 0)
		return f
	end
	outline(UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(10, 7), 3) -- handle
	outline(UDim2.new(0.5, 0, 0, 5), UDim2.fromOffset(22, 21), 6) -- body
	outline(UDim2.new(0.5, 0, 0, 15), UDim2.fromOffset(12, 8), 2) -- pocket
end
local bagKey = UiKit.new("TextLabel", {
	Name = "Key",
	BackgroundColor3 = Color3.fromRGB(26, 52, 110),
	FontFace = UiKit.Font.LabelBold,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(240, 244, 255),
	Text = "B",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -6, 0, 6),
	Size = UDim2.fromOffset(18, 18),
	ZIndex = 3,
}, bagButton)
UiKit.round(bagKey, 9)
bagButton.MouseEnter:Connect(function()
	bagButton.BackgroundColor3 = Color3.fromRGB(30, 48, 88)
end)
bagButton.MouseLeave:Connect(function()
	bagButton.BackgroundColor3 = Color3.fromRGB(12, 20, 40)
end)
bagButton.Activated:Connect(function()
	UiKit.click()
	setOpen(not isOpen)
end)
local function placeBag()
	local view = workspace.CurrentCamera.ViewportSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touch and math.min(view.X, view.Y) <= 500 then
		-- phones: just left of the jump button (jump sits about 95..25 px from the right, 90..20 from the bottom)
		bagButton.Size = UDim2.fromOffset(52, 52)
		bagButton.Position = UDim2.new(1, -106, 1, -26)
	elseif touch then
		bagButton.Size = UDim2.fromOffset(62, 62)
		bagButton.Position = UDim2.new(1, -182, 1, -96)
	else
		bagButton.Size = UDim2.fromOffset(54, 54)
		bagButton.Position = UDim2.new(1, -12, 1, -76)
	end
	bagButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeBag)
placeBag()
local function refreshBagLabel()
	local keyboard = UserInputService.KeyboardEnabled and not UiKit.usingGamepad()
	bagKey.Visible = keyboard
	placeBag()
end
UserInputService.LastInputTypeChanged:Connect(refreshBagLabel)
refreshBagLabel()

local function refreshHud()
	hud.Enabled = player:GetAttribute("Ready") == true or player:GetAttribute("InLobby") == true
	if not hud.Enabled then
		setOpen(false)
	end
end
player:GetAttributeChangedSignal("Ready"):Connect(refreshHud)
player:GetAttributeChangedSignal("InLobby"):Connect(refreshHud)
refreshHud()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not hud.Enabled then
		return
	end
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.DPadUp then
		setOpen(not isOpen)
	end
end)

---------------------------------------------------------------------
-- STUDIO ONLY: draw the locker inside a simulated screen (HudSimulate attribute)
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
		simulated = spec
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
