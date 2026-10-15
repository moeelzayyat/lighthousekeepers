-- UiStyleSheet (client, STUDIO ONLY): the living style guide for UiKit.
-- Press F7 in a Studio play test to open or close it. Never runs in the live game.
--
-- Test hooks (set on the LocalPlayer):
--   StyleSheetDevice  "smallPhone" | "smallPhonePortrait" | "largePhone" | "tablet" | "desktop" | "widescreen" | ""
--                     draws the guide inside a screen of that exact size
--   StyleSheetTab     opens the guide on a tab (Foundations, Controls, Items, Gauges, Feedback)
--   StyleSheetAction  runs a demo: "scroll:600", "toast:<case>", "pickup:<case>", "purchase:<state>",
--                     "focus:<name>", "damage", "towerHit", "audit", "perf", "clear"
--   StyleSheetResult  (output) results of audit / perf

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local C = UiKit.Color
local player = Players.LocalPlayer

local DEVICES = {
	smallPhone = Vector2.new(667, 375),
	smallPhonePortrait = Vector2.new(375, 667),
	largePhone = Vector2.new(932, 430),
	tablet = Vector2.new(1180, 820),
	desktop = Vector2.new(1366, 768),
	widescreen = Vector2.new(1720, 720),
}

local gui = UiKit.Screen("StyleSheet", 60, true)
gui.Enabled = false

local stage -- the simulated screen everything is drawn in
local pages = {}
local tabs
local demo = {} -- live demo objects (gauges, last purchase dialog)

local function wrapRow(parent, gap, order)
	local row = UiKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
	}, parent)
	UiKit.list(row, "x", gap or 12, { Wraps = true, VerticalAlignment = Enum.VerticalAlignment.Top })
	return row
end

-- a component with a small caption under it
local function captioned(parent, caption, order)
	local col = UiKit.new("Frame", {
		Name = "Example_" .. caption,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = order or 0,
	}, parent)
	UiKit.list(col, "y", 6)
	UiKit.Label(col, caption, "Micro", { LayoutOrder = 99, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false })
	return col
end

local function page(parent)
	local p = UiKit.Scroll(parent)
	UiKit.list(p, "y", 26)
	UiKit.pad(p, 6, 14, 28, 2)
	return p
end

local function build()
	gui:ClearAllChildren()
	gui.Enabled = true -- must be on so sizes can be measured
	pages = {}
	demo = {}
	local deviceName = player:GetAttribute("StyleSheetDevice")
	local deviceSize = DEVICES[deviceName or ""]
	local backdrop = UiKit.new("Frame", { BackgroundColor3 = C.Scrim, BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 1) }, gui)
	stage = backdrop
	local size = workspace.CurrentCamera.ViewportSize
	if deviceSize then
		backdrop.BackgroundTransparency = 0
		backdrop.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
		stage = UiKit.new("Frame", {
			Name = "DeviceScreen",
			BackgroundColor3 = Color3.fromRGB(38, 58, 76), -- stands in for the game world behind menus
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(deviceSize.X, deviceSize.Y),
			ClipsDescendants = true,
		}, backdrop)
		UiKit.border(stage, C.TextMuted, 2)
		UiKit.Label(backdrop, string.format("%s  %d x %d", deviceName, deviceSize.X, deviceSize.Y), "Caption", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, -deviceSize.Y / 2 - 6),
			Size = UDim2.fromOffset(400, 16),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		size = deviceSize
	end
	local bp = UiKit.Breakpoint(size)
	local phone = bp == "phone"
	local narrow = size.X < 600
	local panelSize = if phone then UDim2.fromScale(1, 1) elseif bp == "tablet" then UDim2.new(1, -32, 1, -32) else UDim2.fromScale(0.9, 0.9)
	local panel, content = UiKit.Panel(stage, {
		name = "Sheet",
		beam = true,
		eyebrow = "Lighthouse Keepers  ·  UI kit v2.1",
		title = "Storm-forged maritime",
		compact = phone,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		size = panelSize,
		onClose = function()
			gui.Enabled = false
		end,
	})
	UiKit.new("UISizeConstraint", { MaxSize = Vector2.new(1260, 840) }, panel)
	local pagesFrame = UiKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) }, content)
	tabs = UiKit.Tabs(content, {
		{ id = "Foundations", label = "Foundations" },
		{ id = "Controls", label = "Controls" },
		{ id = "Items", label = "Items" },
		{ id = "Gauges", label = "Gauges" },
		{ id = "Feedback", label = "Feedback" },
	}, {
		shoulders = true,
		textSize = if phone then 16 else 18,
		minWidth = if phone then 56 else 84,
		onChange = function(id)
			for name, frame in pages do
				frame.Visible = name == id
			end
		end,
	})
	-- cards fill each row evenly: as many columns as fit at 140 px or wider (2 on a portrait phone)
	RunService.Heartbeat:Wait() -- let the layout settle, then measure the real page width
	local available = pagesFrame.AbsoluteSize.X - 24
	local columns = math.max(2, math.floor((available + 12) / (140 + 12)))
	local cardWidth = math.min(170, math.floor((available - 12 * (columns - 1)) / columns))
	local cardSize = UDim2.fromOffset(cardWidth, math.floor(cardWidth * 1.36))

	---------------------------------------------------------------- Foundations
	local f = page(pagesFrame)
	pages.Foundations = f
	local colorSection = UiKit.Section(f, "Color", { layoutOrder = 1 })
	local groups = {
		{ "Surfaces", { "SurfaceBase", "SurfacePrimary", "SurfaceSecondary", "SurfaceElevated", "SurfaceInset" } },
		{ "Structure and text", { "BorderStructural", "BorderBrassBright", "BorderSubtle", "BorderFocus", "TextPrimary", "TextSecondary", "TextMuted" } },
		{ "Light, sea and states", { "AccentLighthouse", "AccentLighthouseSoft", "AccentSea", "StateSuccess", "StateWarning", "StateDanger", "StateDisabled" } },
		{ "Resources and categories", { "HealthTrail", "Stone", "Pearl", "Shell", "CatWeapons", "CatArmor", "CatAmmunition", "CatMaterials" } },
	}
	for gi, group in groups do
		UiKit.Label(colorSection, group[1], "Label", { LayoutOrder = gi * 2 - 1 })
		local row = wrapRow(colorSection, 10, gi * 2)
		for _, token in group[2] do
			local col = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(88, 58) }, row)
			local chip = UiKit.new("Frame", { BackgroundColor3 = C[token], Size = UDim2.fromOffset(88, 34) }, col)
			UiKit.round(chip, UiKit.Radius.tag)
			UiKit.border(chip, C.BorderSubtle, 1, 0.4)
			UiKit.Label(col, (token:gsub("^Surface", ""):gsub("^Border", "Border "):gsub("^Text", "Text "):gsub("^Accent", ""):gsub("^State", ""):gsub("^Cat", "")), "Micro", {
				Position = UDim2.fromOffset(0, 38),
				Size = UDim2.new(1, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.None,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
	end

	local typeSection = UiKit.Section(f, "Type  ·  caps only for headings, labels, buttons and warnings", { layoutOrder = 2 })
	local samples = {
		{ "Display", "Keep the light alive" },
		{ "H1", "Quartermaster" },
		{ "H2", "The storm is rising" },
		{ "H3", "Storm Harpoon" },
		{ "Eyebrow", "Night 3 of 5" },
		{ "Label", "Lamp fuel" },
		{ "Body", "Pierces through up to three creatures. Great against crab swarms, weaker against big monsters." },
		{ "BodySmall", "Unsold loot washes away when the voyage ends." },
		{ "Micro", "Smallest readable text: 13 px, used for captions under examples." },
		{ "Number", "1,500" },
	}
	for index, sample in samples do
		local row = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = index }, typeSection)
		local style = UiKit.Type[sample[1]]
		local captionText = string.format("%s · %s %d%s", sample[1], style.font, style.size, if style.upper then " · CAPS" else "")
		if narrow then
			UiKit.list(row, "y", 2)
			UiKit.Label(row, captionText, "Micro", { LayoutOrder = 1 })
			UiKit.Label(row, sample[2], sample[1], { LayoutOrder = 2 })
		else
			UiKit.Label(row, captionText, "Micro", { Size = UDim2.new(0, 190, 0, 0) })
			UiKit.Label(row, sample[2], sample[1], { Position = UDim2.fromOffset(200, 0), Size = UDim2.new(1, -200, 0, 0) })
		end
	end

	local containers = UiKit.Section(f, "Containers  ·  each has its own silhouette", { layoutOrder = 3 })
	local cRow = wrapRow(containers, 18, 1)
	local w = if narrow then 320 else 270
	local ex1 = captioned(cRow, "Housing: menus (brackets, beacon line)", 1)
	local p1, c1 = UiKit.Panel(ex1, { size = UDim2.fromOffset(w, 140), beam = true, eyebrow = "Menu", title = "Quartermaster", titleStyle = "H3", padding = 16 })
	UiKit.Label(c1, "The main panel of a screen.", "BodySmall")
	_ = p1
	local ex2 = captioned(cRow, "Dialog: decisions (lens arc)", 2)
	UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 10) }, ex2).LayoutOrder = 0
	local _, c2 = UiKit.Panel(ex2, { kind = "dialog", size = UDim2.fromOffset(w, 130), title = "Buy this?", titleStyle = "H3", padding = 16, layoutOrder = 1 })
	UiKit.Label(c2, "A question that needs an answer.", "BodySmall")
	local ex3 = captioned(cRow, "Inset: instrument faces, wells, ledgers", 3)
	local inset = UiKit.Inset(ex3, { Size = UDim2.fromOffset(w, 140) })
	UiKit.pad(inset, 14)
	UiKit.Label(inset, "Recessed, no border. Holds previews, tracks and numbers.", "BodySmall")
	local ex4 = captioned(cRow, "List: rows split by hairlines, no box", 4)
	local listFrame = UiKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y }, ex4)
	UiKit.list(listFrame, "y", 0)
	UiKit.SettingRow(listFrame, "Sound effects", nil, { controlWidth = 60, layoutOrder = 1 })
	UiKit.SettingRow(listFrame, "Storm and waves", nil, { controlWidth = 60, layoutOrder = 2 })
	UiKit.SettingRow(listFrame, "Reduced motion", nil, { controlWidth = 60, layoutOrder = 3, last = true })

	local contrast = UiKit.Section(f, "Contrast check (WCAG: 4.5 body text, 3.0 large text and labels)", { layoutOrder = 4 })
	local pairs_ = {
		{ "TextPrimary", "SurfacePrimary", 4.5 },
		{ "TextPrimary", "SurfaceElevated", 4.5 },
		{ "TextSecondary", "SurfacePrimary", 4.5 },
		{ "TextSecondary", "SurfaceSecondary", 4.5 },
		{ "TextMuted", "SurfacePrimary", 4.5 },
		{ "TextMuted", "SurfaceSecondary", 3.0 },
		{ "TextOnAccent", "AccentLighthouse", 4.5 },
		{ "StateDanger", "SurfacePrimary", 3.0 },
		{ "StateWarning", "SurfacePrimary", 3.0 },
		{ "AccentSea", "SurfacePrimary", 3.0 },
		{ "StateDisabledText", "StateDisabled", 3.0 },
	}
	for index, pair in pairs_ do
		local ratio = UiKit.contrast(C[pair[1]], C[pair[2]])
		local pass = ratio >= pair[3]
		UiKit.Label(contrast, string.format("%s on %s:  <b>%.1f : 1</b>  %s (needs %.1f)", pair[1], pair[2], ratio, if pass then "pass" else "FAIL", pair[3]), "BodySmall", {
			LayoutOrder = index,
			TextColor3 = if pass then C.TextSecondary else C.StateDanger,
		})
	end

	---------------------------------------------------------------- Controls
	local c = page(pagesFrame)
	pages.Controls = c
	local bRow = wrapRow(UiKit.Section(c, "Buttons  ·  one primary per screen", { layoutOrder = 1 }), 10, 1)
	UiKit.Button(bRow, "Set sail", { variant = "primary", size = "lg", layoutOrder = 1 })
	UiKit.Button(bRow, "How to play", { variant = "secondary", layoutOrder = 2 })
	UiKit.Button(bRow, "Back", { variant = "ghost", layoutOrder = 3 })
	UiKit.Button(bRow, "Leave crew", { variant = "danger", layoutOrder = 4 })
	for index, glyph in { "close", "back", "next", "plus", "minus" } do
		UiKit.IconButton(bRow, glyph, { layoutOrder = 10 + index, tip = "Icon button: " .. glyph })
	end

	local states = UiKit.Section(c, "Interaction states  ·  focus is an ivory ring, selection is gold", { layoutOrder = 2 })
	for rowIndex, variant in { "primary", "secondary" } do
		local row = wrapRow(states, 14, rowIndex)
		for index, state in { "default", "hover", "pressed", "focus", "disabled", "loading" } do
			local col = captioned(row, state, index)
			local b = UiKit.Button(col, if variant == "primary" then "Buy" else "Equip", { variant = variant, width = 120, layoutOrder = 1, name = variant .. "_" .. state })
			if state ~= "default" then
				UiKit.PreviewState(b, state)
			end
		end
	end

	local hints = wrapRow(UiKit.Section(c, "Input prompts  ·  match the player's device", { layoutOrder = 3 }), 24, 1)
	UiKit.KeyHint(hints, { keyboard = "E" }, "Talk to the Quartermaster", { input = "keyboard", layoutOrder = 1 })
	UiKit.KeyHint(hints, { gamepad = Enum.KeyCode.ButtonX }, "Talk to the Quartermaster", { input = "gamepad", layoutOrder = 2 })
	UiKit.KeyHint(hints, { touch = "Tap" }, "Talk to the Quartermaster", { input = "touch", layoutOrder = 3 })
	UiKit.KeyHint(hints, { keyboard = "B", gamepad = Enum.KeyCode.ButtonY, touch = "Bag" }, "Open your bag (live: follows your input)", { layoutOrder = 4 })

	local tabSection = UiKit.Section(c, "Category tabs  ·  L1 / R1 on a controller", { layoutOrder = 4 })
	UiKit.Tabs(tabSection, {
		{ id = "Weapons", label = "Weapons", color = "CatWeapons" },
		{ id = "Armor", label = "Armor", color = "CatArmor" },
		{ id = "Ammunition", label = "Ammunition", color = "CatAmmunition" },
	}, { layoutOrder = 1 })

	local money = wrapRow(UiKit.Section(c, "Currency, tags and badges", { layoutOrder = 5 }), 10, 1)
	UiKit.Currency(money, "Pearls", 12, { size = "lg", layoutOrder = 1 })
	demo.counter = UiKit.Currency(money, "Shells", 998, { layoutOrder = 2 })
	UiKit.Tag(money, "Weapon", "CatWeapons", { layoutOrder = 3 })
	UiKit.Tag(money, "Armor", "CatArmor", { layoutOrder = 4 })
	UiKit.Tag(money, "This voyage only", "StateWarning", { layoutOrder = 5 })
	UiKit.Badge(money, "equipped", nil, { layoutOrder = 6 })
	UiKit.Badge(money, "owned", nil, { layoutOrder = 7 })
	UiKit.Badge(money, "new", nil, { layoutOrder = 8 })
	UiKit.Badge(money, "locked", nil, { layoutOrder = 9 })

	local settings = UiKit.Section(c, "Settings list", { layoutOrder = 6, gap = 0 })
	local _, s1 = UiKit.SettingRow(settings, "Reduced motion", "Turns off screen shake and menu movement.", { stacked = narrow, controlWidth = 100, layoutOrder = 1 })
	UiKit.Toggle(s1, { value = false })
	local _, s2 = UiKit.SettingRow(settings, "Sound effects", "Harpoons, cannons, creatures and alarms.", { stacked = narrow, layoutOrder = 2 })
	UiKit.Slider(s2, { min = 0, max = 100, step = 5, value = 80, size = UDim2.fromScale(1, 1), format = function(v)
		return v .. "%"
	end })
	local _, s3 = UiKit.SettingRow(settings, "Storm and waves", "Rain, thunder and the sea.", { stacked = narrow, layoutOrder = 3, last = true })
	UiKit.Slider(s3, { min = 0, max = 100, step = 5, value = 60, size = UDim2.fromScale(1, 1), format = function(v)
		return v .. "%"
	end })

	---------------------------------------------------------------- Items
	local it = page(pagesFrame)
	pages.Items = it
	local allRow = wrapRow(UiKit.Section(it, "All 11 item models  ·  one preview standard", { layoutOrder = 1 }), 12, 1)
	for index, id in Items.SHOP_ORDER do
		local item = Items[id]
		UiKit.ItemCard(allRow, { itemId = id, name = item.name, category = item.category, layoutOrder = index, size = cardSize })
	end
	local stateRow = wrapRow(UiKit.Section(it, "Card states", { layoutOrder = 2 }), 14, 1)
	local function stateCard(caption, order, spec)
		local item = Items[spec.id]
		local col = captioned(stateRow, caption, order)
		local card = UiKit.ItemCard(col, {
			itemId = spec.id,
			name = item.name,
			category = item.category,
			price = if spec.price and item.price then { kind = "Pearls", amount = item.price } else nil,
			shortBy = spec.shortBy,
			affordable = spec.affordable,
			owned = spec.owned,
			equipped = spec.equipped,
			selected = spec.selected,
			locked = spec.locked,
			isNew = spec.isNew,
			quantity = spec.quantity,
			rarity = spec.rarity,
			size = cardSize,
			layoutOrder = 1,
		})
		card.frame.Name = "Card_" .. caption
		return card
	end
	stateCard("Default", 1, { id = "StormHarpoon", price = true })
	stateCard("Selected", 2, { id = "StormHarpoon", price = true, selected = true })
	stateCard("Equipped", 3, { id = "DriftwoodHarpoon", equipped = true })
	stateCard("Owned", 4, { id = "KeepersCoat", price = true, owned = true })
	stateCard("Can't afford", 5, { id = "WhalerHarpoon", price = true, affordable = false, shortBy = 1100 })
	stateCard("Locked (example)", 6, { id = "IronclawPlate", price = true, locked = "Unlocks after 10 voyages" })
	stateCard("New, stack of 12", 7, { id = "FireShellCrate", isNew = true, quantity = 12 })
	stateCard("Rarity (if ever added)", 8, { id = "FlareGun", price = true, rarity = { label = "Rare", rank = 2 } })
	local focused = stateCard("Focus + selected", 9, { id = "DriftwoodHarpoon", equipped = true, selected = true })
	UiKit.PreviewState(focused.frame, "focus")

	---------------------------------------------------------------- Gauges
	local g = page(pagesFrame)
	pages.Gauges = g
	local gw = if narrow then UDim2.new(1, -4, 0, 0) else UDim2.fromOffset(360, 0)
	local function gaugeRow(title, order)
		return wrapRow(UiKit.Section(g, title, { layoutOrder = order }), 28, 1)
	end
	local healthRow = gaugeRow("Player health  ·  coral, trailing damage, critical marker at 25%", 1)
	demo.health = UiKit.HealthGauge(healthRow, { value = 100, size = UDim2.new(gw.X.Scale, gw.X.Offset, 0, 38), layoutOrder = 1 })
	UiKit.HealthGauge(healthRow, { value = 18, size = UDim2.new(gw.X.Scale, gw.X.Offset, 0, 38), layoutOrder = 2 })
	UiKit.Button(healthRow, "Take 15 damage", { size = "sm", layoutOrder = 3, onClick = function()
		demo.healthValue = math.max(0, (demo.healthValue or 100) - 15)
		demo.health.set(demo.healthValue)
	end })
	local fuelRow = gaugeRow("Lighthouse fuel  ·  the main objective: steady, low, critical, blackout", 2)
	for index, value in { 0.72, 0.24, 0.1, 0 } do
		UiKit.FuelGauge(fuelRow, { value = value, size = UDim2.new(gw.X.Scale, gw.X.Offset + 20, 0, 58), layoutOrder = index })
	end
	local towerRow = gaugeRow("Tower integrity  ·  segmented masonry, lost blocks crack", 3)
	demo.tower = UiKit.TowerGauge(towerRow, { value = 1, size = UDim2.new(gw.X.Scale, gw.X.Offset, 0, 42), layoutOrder = 1 })
	UiKit.TowerGauge(towerRow, { value = 0.22, size = UDim2.new(gw.X.Scale, gw.X.Offset, 0, 42), layoutOrder = 2 })
	UiKit.Button(towerRow, "Hit the tower", { size = "sm", layoutOrder = 3, onClick = function()
		demo.towerValue = math.max(0, (demo.towerValue or 1) - 0.12)
		demo.tower.set(demo.towerValue)
	end })
	local resourceRow = gaugeRow("Secondary resource  ·  only for real resources (cannon ammo)", 4)
	UiKit.ResourceGauge(resourceRow, { label = "Cannon ammo", value = 5 / 15, text = "5 / 15", color = "CatAmmunition", ticks = 15, size = UDim2.new(gw.X.Scale, gw.X.Offset, 0, 38), layoutOrder = 1 })

	---------------------------------------------------------------- Feedback
	local fb = page(pagesFrame)
	pages.Feedback = fb
	local noticeRow = wrapRow(UiKit.Section(fb, "Notices  ·  top right, max 3, glyph + color + title", { layoutOrder = 1 }), 10, 1)
	local cases = {
		{ "itemAcquired", "Item acquired" },
		{ "itemEquipped", "Item equipped" },
		{ "purchaseOk", "Purchase successful" },
		{ "purchaseRejected", "Purchase rejected" },
		{ "insufficient", "Not enough Pearls" },
		{ "connection", "Connection error" },
		{ "saveUnavailable", "Save unavailable" },
	}
	for index, case in cases do
		UiKit.Button(noticeRow, case[2], { size = "sm", layoutOrder = index, onClick = function()
			player:SetAttribute("StyleSheetAction", "toast:" .. case[1])
		end })
	end
	local pickupRow = wrapRow(UiKit.Section(fb, "Pickups  ·  right edge, merge repeats, Shells vs Pearls", { layoutOrder = 2 }), 10, 1)
	for index, case in { { "shells", "+25 Shells" }, { "pearls", "+2 Pearls" }, { "loot", "Sea Glass" }, { "burst", "Burst of loot" } } do
		UiKit.Button(pickupRow, case[2], { size = "sm", layoutOrder = index, onClick = function()
			player:SetAttribute("StyleSheetAction", "pickup:" .. case[1])
		end })
	end
	local buyRow = wrapRow(UiKit.Section(fb, "Purchase decision", { layoutOrder = 3 }), 10, 1)
	for index, case in { { "default", "Buy (succeeds)" }, { "fail", "Buy (fails)" }, { "insufficient", "Not enough Pearls" }, { "owned", "Already owned" } } do
		UiKit.Button(buyRow, case[2], { size = "sm", layoutOrder = index, onClick = function()
			player:SetAttribute("StyleSheetAction", "purchase:" .. case[1])
		end })
	end
	local viewRow = wrapRow(UiKit.Section(fb, "Designed states  ·  never blank space", { layoutOrder = 4 }), 12, 1)
	local views = {
		{ "loading", "Opening your bag", "Fetching your gear." },
		{ "empty", "Your bag is empty", "Gear you buy from the Quartermaster appears here." },
		{ "empty", "No armor yet", "The Quartermaster sells coats on Harbor Island." },
		{ "error", "Couldn't reach the server", "Nothing was lost. Check your connection and try again.", "Try again" },
		{ "offline", "Progress isn't saving", "You can keep playing. Pearls earned now may not be kept." },
		{ "success", "Storm Harpoon bought", "It's in your bag. Equip it from the BAG." },
	}
	for index, v in views do
		local box = UiKit.Inset(viewRow, { Size = UDim2.fromOffset(if narrow then 320 else 236, 240), LayoutOrder = index })
		UiKit.StateView(box, v[1], { title = v[2], body = v[3], actionText = v[4] })
	end

	tabs.set("Foundations")
end

---------------------------------------------------------------------
-- demo actions
---------------------------------------------------------------------

local TOASTS = {
	itemAcquired = { "Storm Harpoon was added to your bag.", "success", "Item acquired" },
	itemEquipped = { "Storm Harpoon is now your primary weapon.", "success", "Equipped" },
	purchaseOk = { "Whaler's Harpoon is in your bag. Equip it from the BAG.", "success", "Bought" },
	purchaseRejected = { "Nothing was spent. Try again in a moment.", "danger", "Purchase didn't go through" },
	insufficient = { "You need 1,100 more. Earn Pearls by surviving nights.", "warning", "Not enough Pearls" },
	connection = { "We couldn't reach the server. Your last save is safe.", "danger", "Connection problem" },
	saveUnavailable = { "You can keep playing. Pearls earned now may not be kept.", "warning", "Progress isn't saving" },
}

local function openPurchase(case)
	local item = Items.WhalerHarpoon
	local balance = if case == "insufficient" then 400 else 1840
	demo.purchase = UiKit.PurchaseDialog(stage, {
		itemId = "WhalerHarpoon",
		name = item.name,
		description = item.tradeoffs,
		category = item.category,
		effect = "gameplay",
		price = { kind = "Pearls", amount = item.price },
		balance = balance,
		owned = case == "owned",
		onPurchase = function(done)
			task.delay(1.2, function()
				if case == "fail" then
					done(false, "The Quartermaster couldn't confirm that. Nothing was spent.")
				else
					done(true)
				end
			end)
		end,
	})
end

local function audit()
	local small, tinyText, clipped = {}, {}, {}
	for _, d in stage:GetDescendants() do
		if d:IsA("GuiObject") and UiKit.isShown(d) then
			if d:IsA("GuiButton") and d.Selectable and (d.AbsoluteSize.X < 43.5 or d.AbsoluteSize.Y < 43.5) then
				table.insert(small, d.Name .. string.format("(%dx%d)", d.AbsoluteSize.X, d.AbsoluteSize.Y))
			end
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
				local size = if d.TextScaled then d.TextBounds.Y else d.TextSize
				if size < 12 and d.TextBounds.Y > 0 then
					table.insert(tinyText, d.Name .. ":" .. d.Text:sub(1, 20))
				end
				if not d.TextFits and d.TextTruncate == Enum.TextTruncate.None then
					table.insert(clipped, d.Name .. ":" .. d.Text:sub(1, 24))
				end
			end
		end
	end
	return string.format("small buttons %d [%s] | text<12px %d [%s] | clipped %d [%s]",
		#small, table.concat(small, ", "):sub(1, 400), #tinyText, table.concat(tinyText, ", "):sub(1, 300), #clipped, table.concat(clipped, ", "):sub(1, 400))
end

local function perf()
	local total, frames = 0, 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		total += dt
		frames += 1
	end)
	task.wait(2)
	connection:Disconnect()
	local viewports, objects = 0, 0
	for _, d in gui:GetDescendants() do
		objects += 1
		if d:IsA("ViewportFrame") then
			viewports += 1
		end
	end
	return string.format("avg frame %.1f ms (%.0f fps) over %d frames | %d UI objects | %d 3D previews", total / frames * 1000, frames / total, frames, objects, viewports)
end

local function runAction(action)
	local name, arg = action:match("^(%w+):?(.*)$")
	if name == "scroll" then
		for _, p in pages do
			if p.Visible then
				p.CanvasPosition = Vector2.new(0, tonumber(arg) or 0)
			end
		end
	elseif name == "toast" then
		local t = TOASTS[arg]
		if t then
			UiKit.Toast(stage, t[1], t[2], { title = t[3], duration = 8 })
		end
	elseif name == "pickup" then
		if arg == "shells" then
			UiKit.Pickup(stage, { kind = "Shells", amount = 25 })
		elseif arg == "pearls" then
			UiKit.Pickup(stage, { kind = "Pearls", amount = 2 })
		elseif arg == "loot" then
			UiKit.Pickup(stage, { kind = "loot", label = "Sea Glass", category = "Materials" })
		elseif arg == "burst" then
			for _ = 1, 6 do
				UiKit.Pickup(stage, { kind = "loot", label = "Crab Claw", category = "Materials" })
				UiKit.Pickup(stage, { kind = "Shells", amount = 3 })
				task.wait(0.08)
			end
			UiKit.Pickup(stage, { kind = "Pearls", amount = 2 })
			UiKit.Pickup(stage, { kind = "loot", label = "Black Pearl", category = "Materials" })
		end
	elseif name == "purchase" then
		if arg == "pending" or arg == "success" or arg == "error" then
			if not demo.purchase or not demo.purchase.panel.Parent then
				openPurchase("default")
			end
			demo.purchase.setState(arg, if arg == "error" then "The Quartermaster couldn't confirm that. Nothing was spent." else nil)
		else
			openPurchase(arg)
		end
	elseif name == "focus" then
		local target = stage:FindFirstChild(arg, true)
		GuiService.SelectedObject = target
	elseif name == "damage" then
		demo.healthValue = math.max(0, (demo.healthValue or 100) - 35)
		demo.health.set(demo.healthValue)
	elseif name == "towerHit" then
		demo.towerValue = math.max(0, (demo.towerValue or 1) - 0.25)
		demo.tower.set(demo.towerValue)
	elseif name == "audit" then
		player:SetAttribute("StyleSheetResult", audit())
	elseif name == "perf" then
		player:SetAttribute("StyleSheetResult", perf())
	elseif name == "clear" then
		for _, d in stage:GetDescendants() do
			if d.Name == "ToastStack" or d.Name == "PickupFeed" or d.Name == "DialogScrim" then
				d:Destroy()
			end
		end
		GuiService.SelectedObject = nil
		player:SetAttribute("MenuOpen", false)
	end
end

local function toggle()
	if gui.Enabled then
		gui.Enabled = false
	else
		build()
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F7 then
		toggle()
	end
end)

player:GetAttributeChangedSignal("StyleSheetTab"):Connect(function()
	local tab = player:GetAttribute("StyleSheetTab")
	if tab == "" or tab == nil then
		gui.Enabled = false
		return
	end
	if not gui.Enabled then
		build()
	end
	gui.Enabled = true
	tabs.set(tab)
end)

player:GetAttributeChangedSignal("StyleSheetDevice"):Connect(function()
	if gui.Enabled then
		local current = tabs and tabs.selected or "Foundations"
		build()
		tabs.set(current)
	end
end)

player:GetAttributeChangedSignal("StyleSheetAction"):Connect(function()
	local action = player:GetAttribute("StyleSheetAction")
	if action and action ~= "" then
		player:SetAttribute("StyleSheetAction", "")
		task.spawn(runAction, action)
	end
end)
