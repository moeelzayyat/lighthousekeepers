-- Gear (client): the GEAR screen with SHOP and INVENTORY tabs.
-- Open with the GEAR button (top right) or the G key. Everything is bought with Pearls,
-- which are earned by playing and saved between sessions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Ammo = require(Shared:WaitForChild("Ammo"))
local SoundFx = require(Shared:WaitForChild("SoundFx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gearDataRemote = remotes:WaitForChild("GearData")
local gearActionRemote = remotes:WaitForChild("GearAction")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local THEME = {
	panel = Color3.fromRGB(16, 22, 34),
	card = Color3.fromRGB(30, 40, 58),
	cardOwned = Color3.fromRGB(28, 52, 44),
	gold = Color3.fromRGB(245, 196, 92),
	goldDark = Color3.fromRGB(196, 140, 48),
	text = Color3.fromRGB(240, 242, 248),
	muted = Color3.fromRGB(160, 172, 192),
	green = Color3.fromRGB(96, 200, 120),
	red = Color3.fromRGB(226, 84, 70),
	pearl = Color3.fromRGB(225, 215, 255),
}
local KIND_COLORS = {
	Weapon = Color3.fromRGB(230, 120, 80),
	Armor = Color3.fromRGB(110, 170, 240),
	Ammo = Color3.fromRGB(240, 170, 60),
	Material = Color3.fromRGB(150, 210, 170),
}

local profile = nil -- latest copy of our saved data from the server
local saving = true

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end
local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end
local function text(parent, value, size, position, textSize, font, color, align)
	return make("TextLabel", {
		BackgroundTransparency = 1, Size = size, Position = position, Text = value,
		TextSize = textSize, Font = font or Enum.Font.Gotham, TextColor3 = color or THEME.text,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, parent)
end
local function smallButton(parent, value, size, position, color)
	local b = make("TextButton", {
		Size = size, Position = position, BackgroundColor3 = color or THEME.gold,
		Text = value, TextColor3 = Color3.fromRGB(25, 20, 10), Font = Enum.Font.GothamBlack, TextSize = 15,
	}, parent)
	corner(b, 8)
	return b
end

-- One-line stats for an item card
local function statLine(itemId, item)
	if item.kind == "Weapon" then
		local w = Weapons[itemId]
		local dps = w.damage / w.cooldown
		return string.format("%d dmg  |  %.1fs reload  |  %s  |  ~%d dmg/s", w.damage, w.cooldown,
			if w.maxTargets > 1 then ("hits " .. w.maxTargets) else "single target", math.floor(dps + 0.5))
	elseif item.kind == "Armor" then
		return string.format("%d health  |  takes %d%% less damage", item.maxHealth, math.floor(item.damageReduction * 100 + 0.5))
	elseif item.kind == "Ammo" then
		local a = Ammo[item.ammoType]
		return string.format("%d shots  |  x%.1f damage  |  x%.1f blast", a.shotsPerLoad, a.damageMultiplier, a.splashMultiplier)
	elseif item.kind == "Material" then
		return string.format("Sells for %d Pearls", item.sell)
	end
	return ""
end

---------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "Gear", ResetOnSpawn = false, DisplayOrder = 5, Enabled = false }, player:WaitForChild("PlayerGui"))
local scaleRoot = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
local uiScale = make("UIScale", {}, scaleRoot)
local function rescale()
	local viewport = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 640), 0.5, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- GEAR button on the HUD
local openButton = make("TextButton", {
	Size = UDim2.fromOffset(130, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = THEME.gold, Text = "GEAR  (G)", TextColor3 = Color3.fromRGB(25, 20, 10),
	Font = Enum.Font.GothamBlack, TextSize = 17,
}, scaleRoot)
corner(openButton, 10)
make("UIStroke", { Color = THEME.goldDark, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, openButton)

local panel = make("Frame", {
	Size = UDim2.fromOffset(820, 560), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = THEME.panel, Visible = false,
}, scaleRoot)
corner(panel, 16)
make("UIStroke", { Color = THEME.goldDark, Thickness = 2 }, panel)

text(panel, "GEAR", UDim2.fromOffset(200, 40), UDim2.fromOffset(24, 16), 32, Enum.Font.GothamBlack, THEME.gold)
local pearlsLabel = text(panel, "", UDim2.fromOffset(260, 30), UDim2.fromOffset(150, 22), 22, Enum.Font.GothamBlack, THEME.pearl)
local saveLabel = text(panel, "", UDim2.fromOffset(300, 20), UDim2.fromOffset(420, 28), 13, Enum.Font.GothamMedium, THEME.muted, Enum.TextXAlignment.Right)
local closeButton = smallButton(panel, "X", UDim2.fromOffset(40, 40), UDim2.new(1, -56, 0, 16), THEME.red)
closeButton.TextColor3 = THEME.text

local shopTab = smallButton(panel, "SHOP", UDim2.fromOffset(150, 38), UDim2.fromOffset(24, 70))
local invTab = smallButton(panel, "INVENTORY", UDim2.fromOffset(150, 38), UDim2.fromOffset(184, 70))

local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -48, 1, -132), Position = UDim2.fromOffset(24, 120),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
make("UIGridLayout", { CellSize = UDim2.fromOffset(372, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local currentTab = "shop"

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- A card: kind tag, name, description, stats, and up to two action buttons
local function card(order, itemId, item, owned, extraLine, actions)
	local c = make("Frame", { BackgroundColor3 = if owned then THEME.cardOwned else THEME.card, LayoutOrder = order }, list)
	corner(c, 12)
	local tag = make("TextLabel", {
		Size = UDim2.fromOffset(82, 20), Position = UDim2.fromOffset(12, 10), BackgroundColor3 = KIND_COLORS[item.kind],
		Text = string.upper(item.kind), TextSize = 12, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(20, 20, 25),
	}, c)
	corner(tag, 6)
	text(c, item.name, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 34), 20, Enum.Font.GothamBold, THEME.text)
	text(c, item.description, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 60), 13, Enum.Font.Gotham, THEME.muted)
	text(c, statLine(itemId, item), UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 96), 13, Enum.Font.GothamMedium, THEME.gold)
	if extraLine then
		text(c, extraLine, UDim2.new(0.5, 0, 0, 20), UDim2.new(0, 12, 1, -32), 15, Enum.Font.GothamBold, THEME.pearl)
	end
	for index, action in actions do
		local b = smallButton(c, action.label, UDim2.fromOffset(118, 32), UDim2.new(1, -12 - index * 124 + 6, 1, -40), action.color)
		if action.disabled then
			b.AutoButtonColor = false
			b.BackgroundColor3 = Color3.fromRGB(70, 74, 86)
			b.TextColor3 = THEME.muted
		else
			b.Activated:Connect(function()
				SoundFx.play2D("click")
				gearActionRemote:FireServer(action.action, itemId, action.amount)
			end)
		end
	end
end

local function buildShop()
	for order, itemId in Items.SHOP_ORDER do
		local item = Items[itemId]
		if not item.price then
			continue -- not sold (materials)
		end
		local owned = profile.owned[itemId] == true
		local actions = {}
		local extra = nil
		if item.kind == "Weapon" or item.kind == "Armor" then
			if owned then
				if item.kind == "Armor" then
					local equipped = profile.equippedArmor == itemId
					table.insert(actions, { label = if equipped then "EQUIPPED" else "EQUIP", action = "equip", disabled = equipped, color = THEME.green })
				else
					table.insert(actions, { label = "OWNED", disabled = true })
				end
			else
				extra = string.format("%d Pearls", item.price)
				table.insert(actions, { label = "BUY", action = "buy", disabled = profile.pearls < item.price })
			end
		else
			extra = string.format("%d Pearls  (have %d)", item.price, profile.counts[itemId] or 0)
			table.insert(actions, { label = "BUY 1", action = "buy", disabled = profile.pearls < item.price })
		end
		card(order, itemId, item, owned, extra, actions)
	end
end

local function buildInventory()
	local order = 0
	-- Gear first, then ammo, then materials
	for _, kind in { "Weapon", "Armor", "Ammo", "Material" } do
		for itemId, item in Items do
			if type(item) == "table" and item.kind == kind then
				local count = profile.counts[itemId] or 0
				local owned = profile.owned[itemId] == true
				if owned or count > 0 then
					order += 1
					local actions = {}
					local extra = nil
					if kind == "Armor" then
						local equipped = profile.equippedArmor == itemId
						table.insert(actions, { label = if equipped then "EQUIPPED" else "EQUIP", action = "equip", disabled = equipped, color = THEME.green })
					elseif kind == "Ammo" then
						extra = string.format("x%d  (used when you reload a cannon)", count)
					elseif kind == "Material" then
						extra = string.format("x%d", count)
						table.insert(actions, { label = "SELL ALL", action = "sell", amount = count })
						table.insert(actions, { label = "SELL 1", action = "sell", amount = 1, color = THEME.card })
					end
					card(order, itemId, item, owned, extra, actions)
				end
			end
		end
	end
	-- Lifetime stats card
	local s = profile.stats
	local c = make("Frame", { BackgroundColor3 = THEME.card, LayoutOrder = order + 1 }, list)
	corner(c, 12)
	text(c, "KEEPER RECORD", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 14), 18, Enum.Font.GothamBlack, THEME.gold)
	text(c, string.format("Runs played: %d\nVictories: %d\nBest night reached: %d", s.runs, s.victories, s.bestNight),
		UDim2.new(1, -24, 0, 80), UDim2.fromOffset(12, 46), 16, Enum.Font.GothamMedium, THEME.text)
end

local function refresh()
	if not profile then
		return
	end
	pearlsLabel.Text = string.format("%d Pearls", profile.pearls)
	saveLabel.Text = if saving then "Progress saves automatically" else "Not saving (Studio API access is off)"
	saveLabel.TextColor3 = if saving then THEME.muted else THEME.red
	shopTab.BackgroundColor3 = if currentTab == "shop" then THEME.gold else THEME.card
	shopTab.TextColor3 = if currentTab == "shop" then Color3.fromRGB(25, 20, 10) else THEME.text
	invTab.BackgroundColor3 = if currentTab == "inventory" then THEME.gold else THEME.card
	invTab.TextColor3 = if currentTab == "inventory" then Color3.fromRGB(25, 20, 10) else THEME.text
	clearList()
	if currentTab == "shop" then
		buildShop()
	else
		buildInventory()
	end
end

---------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------

local function setOpen(open)
	panel.Visible = open
	if open then
		refresh()
	end
end

openButton.Activated:Connect(function()
	SoundFx.play2D("click")
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
shopTab.Activated:Connect(function()
	currentTab = "shop"
	refresh()
end)
invTab.Activated:Connect(function()
	currentTab = "inventory"
	refresh()
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.G and gui.Enabled then
		setOpen(not panel.Visible)
	end
end)

gearDataRemote.OnClientEvent:Connect(function(data, isSaving)
	profile = data
	saving = isSaving
	if panel.Visible then
		refresh()
	end
end)

-- Only available once in the game (not on the title screen)
local function refreshEnabled()
	gui.Enabled = player:GetAttribute("Ready") == true
	if not gui.Enabled then
		panel.Visible = false
	end
end
player:GetAttributeChangedSignal("Ready"):Connect(refreshEnabled)
refreshEnabled()

-- Ask the server for our data (in case it was sent before this script started)
gearActionRemote:FireServer("sync")
