-- Results (client): the end-of-voyage screen.
--
-- Order of importance (spec): 1 outcome, 2 why it happened, 3 crew accomplishments,
-- 4 rewards, 5 next action. Sail Again (rematch) is the strongest action; Back to Harbor is
-- clear but secondary. Victory is warm and restrained; a loss is darker, explains the cause
-- and invites another try without shame.
-- Data comes from the server's RunResults (EventLog.endRun + Pearls + cause/shells extras).
-- Votes: VoteRematch / SetReady(false), unchanged. Built on UiKit v2.1 (Stage 7).
-- Studio only: player attribute HudSimulate draws it inside a simulated screen size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local SocialService = game:GetService("SocialService")
local Forecasts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Forecasts"))

local C, F = UiKit.Color, UiKit.Font
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local state = ReplicatedStorage:WaitForChild("GameState")
local player = Players.LocalPlayer

local isOpen = false
local results = nil
local voted = false

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local fmt = UiKit.formatNumber

---------------------------------------------------------------------
-- SCREEN
---------------------------------------------------------------------

local gui = UiKit.Screen("Results", 30, true)
gui.Enabled = false
local backdrop = UiKit.new("Frame", { Name = "Backdrop", BackgroundColor3 = C.SurfaceBase, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, gui)
-- the light: a soft glow behind the outcome (warm for a victory, cold sea for a loss)
local glow = UiKit.new("Frame", { Name = "Glow", BackgroundColor3 = C.AccentLighthouse, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromScale(1.1, 0.75) }, backdrop)
UiKit.round(glow, 2000)
UiKit.new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.6, 0.93), NumberSequenceKeypoint.new(1, 1) }),
}, glow)

-- the content stays inside the safe area (notches, Roblox top bar); only the backdrop bleeds
local content = UiKit.Screen("ResultsContent", 31)
content.Enabled = false
local root = UiKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, content)
local rootOutline = UiKit.border(root, C.BorderFocus, 1, 0.4)
rootOutline.Enabled = false

local column = UiKit.Scroll(root, { Name = "Column", ScrollBarThickness = 4, AnchorPoint = Vector2.new(0.5, 0) })
UiKit.list(column, "y", 14, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
UiKit.pad(column, 8, 8, 12, 8)

-- 1. OUTCOME ----------------------------------------------------------
local hero = UiKit.new("Frame", { Name = "Outcome", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, column)
UiKit.list(hero, "y", 4, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
local heroLamp = UiKit.Glyph(hero, "lamp", C.AccentLighthouse, 28)
heroLamp.LayoutOrder = 1
local eyebrow = UiKit.Label(hero, "", "Eyebrow", { Name = "Eyebrow", LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center })
local headline = UiKit.Label(hero, "", "Display", { Name = "Headline", LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Center })

-- 2. WHY -------------------------------------------------------------------
local why = UiKit.new("Frame", { Name = "Why", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, column)
UiKit.list(why, "y", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
local cause = UiKit.Label(why, "", "Body", { Name = "Cause", LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.TextPrimary })
local track = UiKit.new("Frame", { Name = "Nights", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 }, why)
UiKit.list(track, "x", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
local trackLabel = UiKit.Label(why, "", "Micro", { Name = "TrackLabel", LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Center })
local tip = UiKit.Label(why, "", "BodySmall", { Name = "Tip", LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Center })
-- launch R12: the run's best moment (clutch save, big-monster kill, last-stand tower)
local momentLine = UiKit.Label(why, "", "Body", { Name = "Moment", LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.AccentLighthouseSoft, Visible = false })

-- 3. CREW -------------------------------------------------------------------
local crewSection = UiKit.Section(column, "The crew", { layoutOrder = 3, gap = 10 })
local medals = UiKit.new("Frame", { Name = "Medals", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, crewSection)
local medalGrid = UiKit.new("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.fromOffset(180, 78), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, medals)
local yourPart = UiKit.Label(crewSection, "", "BodySmall", { Name = "YourPart", LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.TextPrimary })
-- launch R11: one natural, unrewarded invite point (no nagging; hidden after use or if invites aren't allowed)
local inviteRow = UiKit.new("Frame", { Name = "Invite", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3, Visible = false }, crewSection)
UiKit.list(inviteRow, "x", 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
local inviteButton = UiKit.Button(inviteRow, "Invite a friend to the crew", { name = "InviteButton", variant = "ghost", size = "sm" })
local invitedThisScreen = false
inviteButton.Activated:Connect(function()
	invitedThisScreen = true
	inviteRow.Visible = false
	pcall(SocialService.PromptGameInvite, SocialService, player)
end)

-- 4. REWARDS -------------------------------------------------------------
local rewardSection = UiKit.Section(column, "Rewards", { layoutOrder = 4, gap = 10 })
local rewardRow = UiKit.new("Frame", { Name = "RewardRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, rewardSection)
local rewardGrid = UiKit.new("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.fromOffset(230, 70), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, rewardRow)

local function rewardTile(order, name)
	local tile = UiKit.Inset(rewardRow, { Name = name, LayoutOrder = order })
	UiKit.pad(tile, 10, 12, 10, 12)
	local top = UiKit.new("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, tile)
	UiKit.list(top, "x", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
	local value = UiKit.new("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		FontFace = F.Numeric,
		TextSize = 22,
		TextColor3 = C.TextPrimary,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	}, top)
	local word = UiKit.Label(top, "", "Label", { Name = "Word", LayoutOrder = 3, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextYAlignment = Enum.TextYAlignment.Center })
	local note = UiKit.Label(tile, "", "Micro", { Name = "Note", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	return { frame = tile, top = top, value = value, word = word, note = note, icon = nil }
end
local pearlTile = rewardTile(1, "Pearls")
UiKit.CurrencyIcon(pearlTile.top, "Pearls", 20).LayoutOrder = 1
local shellTile = rewardTile(2, "Shells")
UiKit.CurrencyIcon(shellTile.top, "Shells", 20).LayoutOrder = 1
local lootTile = rewardTile(3, "Loot")
UiKit.CurrencyIcon(lootTile.top, "Shells", 20).LayoutOrder = 1
-- launch R8: the nearest thing to work toward, with progress
local goalTile = rewardTile(4, "NextGoal")
UiKit.CurrencyIcon(goalTile.top, "Pearls", 20).LayoutOrder = 1
local goalTrack = UiKit.new("Frame", { Name = "Track", BackgroundColor3 = C.SurfaceHover, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 49), Size = UDim2.new(1, 0, 0, 3) }, goalTile.frame)
local goalFill = UiKit.new("Frame", { Name = "Fill", BackgroundColor3 = C.AccentLighthouse, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, goalTrack)
local gear -- latest profile from GearData (pearls, owned)
remotes:WaitForChild("GearData").OnClientEvent:Connect(function(profile)
	gear = profile
	if isOpen and results then
		task.defer(function()
			if renderGoal then
				renderGoal()
			end
		end)
	end
end)

-- cheapest Quartermaster item the player doesn't own yet
local function nextGoal()
	if not gear then
		return nil
	end
	-- gear first (it changes how you play); beam colours only once all gear is owned
	local best, bestCosmetic
	for id, item in Items do
		if type(item) == "table" and item.price and not (gear.owned and gear.owned[id]) then
			local entry = { id = id, price = item.price, name = item.name or id }
			if (item.kind == "Weapon" or item.kind == "Armor") and (not best or item.price < best.price) then
				best = entry
			elseif item.kind == "Cosmetic" and (not bestCosmetic or item.price < bestCosmetic.price) then
				bestCosmetic = entry
			end
		end
	end
	return best or bestCosmetic
end

function renderGoal()
	local goal = nextGoal()
	goalTile.frame.Visible = goal ~= nil
	if not goal then
		return
	end
	local have = math.floor(gear.pearls or 0)
	goalTile.value.Text = string.format("%s / %s", fmt(math.min(have, goal.price)), fmt(goal.price))
	goalTile.word.Text = "NEXT GOAL"
	goalTile.note.Text = if have >= goal.price then goal.name .. " \u{00B7} ready at the Quartermaster" else goal.name .. " \u{00B7} " .. fmt(goal.price - have) .. " to go"
	goalFill.Size = UDim2.fromScale(math.clamp(have / goal.price, 0, 1), 1)
end

-- 5. NEXT ACTION (pinned to the bottom) ---------------------------------------
local actions = UiKit.new("Frame", { Name = "Actions", BackgroundColor3 = C.SurfacePrimary, BackgroundTransparency = 0.05, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1) }, root)
UiKit.round(actions, UiKit.Radius.panel)
UiKit.border(actions, C.BorderStructural, 1, 0.45)
local againButton = UiKit.Button(actions, "Sail again", { name = "SailAgain", variant = "primary", size = "lg", width = 280 })
local harborButton = UiKit.Button(actions, "Back to harbor", { name = "BackToHarbor", variant = "secondary", size = "md", width = 220 })
local countdown = UiKit.Label(actions, "", "Micro", { Name = "Countdown", AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Center })

---------------------------------------------------------------------
-- CONTENT
---------------------------------------------------------------------

local CAUSE_TEXT = {
	blackout = "The lamp ran dry and stayed dark too long.",
	breach = "The creatures broke into the lighthouse.",
}
local TIPS = {
	blackout = "Next time: keep oil moving before dark. The focused beam burns fuel fast, so save it for big threats.",
	breach = "Next time: repair the tower between waves, and build a cannon on a pad facing the sea.",
	early = "The first night is the hardest to learn. Every crew gets better at it.",
}

local medalCards = {}
local function clearMedals()
	for _, m in medalCards do
		m:Destroy()
	end
	table.clear(medalCards)
end

local function medal(order, title, name, line)
	local card = UiKit.Inset(medals, { Name = "Medal" .. order, LayoutOrder = order })
	UiKit.pad(card, 8, 12, 8, 12)
	UiKit.border(card, C.BorderStructural, 1, 0.55)
	UiKit.list(card, "y", 2)
	UiKit.Label(card, title, "Eyebrow", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	UiKit.Label(card, name, "H3", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 17 })
	UiKit.Label(card, line, "Micro", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	table.insert(medalCards, card)
end

local nightPips = {}
local function drawTrack(reached, total, won)
	for _, p in nightPips do
		p:Destroy()
	end
	table.clear(nightPips)
	for night = 1, total do
		local done = won or night < reached
		local lost = not won and night == reached
		local pip = UiKit.new("Frame", { Name = "Night" .. night, BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = night }, track)
		local dot = UiKit.new("Frame", {
			BackgroundColor3 = if lost then C.StateDanger elseif done then C.AccentLighthouse else C.SurfaceSecondary,
			BackgroundTransparency = if done or lost then 0 else 0.2,
			Size = UDim2.fromScale(1, 1),
			Rotation = 45,
		}, pip)
		UiKit.border(dot, if lost then C.StateDanger elseif done then C.AccentLighthouseDeep else C.BorderStructural, 1, 0.2)
		if lost then
			local g = UiKit.Glyph(pip, "close", C.TextOnAccent, 10)
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
		elseif done then
			local g = UiKit.Glyph(pip, "check", C.TextOnAccent, 10)
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.Position = UDim2.fromScale(0.5, 0.5)
		end
		table.insert(nightPips, pip)
	end
end

local function yourContribution(r)
	local me
	for _, entry in r.crew or {} do
		if entry.name == player.DisplayName then
			me = entry
		end
	end
	if not me then
		return "You helped the crew this voyage."
	end
	local parts = {}
	if (me.kills or 0) > 0 then
		table.insert(parts, string.format("%d defeated", me.kills))
	end
	if (me.oilDelivered or 0) > 0 then
		table.insert(parts, string.format("%d %s of oil", me.oilDelivered, if me.oilDelivered == 1 then "barrel" else "barrels"))
	end
	if (me.repairs or 0) > 0 then
		table.insert(parts, string.format("%d %s", me.repairs, if me.repairs == 1 then "repair" else "repairs"))
	end
	if (me.keeperSeconds or 0) >= 1 then
		table.insert(parts, clock(me.keeperSeconds) .. " at the lamp")
	end
	if (me.shellsCollected or 0) > 0 then
		table.insert(parts, fmt(me.shellsCollected) .. " Shells picked up")
	end
	if #parts == 0 then
		return "You were part of the crew. Next time, try a job: oil, repairs, the lamp or the harpoon."
	end
	return "<b>Your part:</b> " .. table.concat(parts, " \u{00B7} ")
end

local function render()
	local r = results
	if not r then
		return
	end
	local won = r.result == "Victory"
	local causeKey = r.cause or ""
	-- 1 outcome
	eyebrow.Text = if won then "VOYAGE COMPLETE" else "VOYAGE LOST"
	eyebrow.TextColor3 = if won then C.AccentLighthouse else C.StateDanger
	headline.Text = if won then "The light held" elseif causeKey == "breach" then "The lighthouse fell" else "The light went out"
	headline.TextColor3 = if won then C.AccentLighthouseSoft else C.TextPrimary
	UiKit.SetGlyphColor(heroLamp, if won then C.AccentLighthouse else C.TextMuted)
	glow.BackgroundColor3 = if won then C.AccentLighthouse else C.AccentSeaDeep
	-- phones: near-solid so the HUD underneath doesn't clutter the small screen
	local smallScreen = UiKit.Breakpoint(backdrop.AbsoluteSize) == "phone"
	backdrop.BackgroundTransparency = if smallScreen then 0.03 elseif won then 0.12 else 0.06
	-- 2 why
	if won then
		cause.Text = string.format("Your crew kept the lamp burning through all %d nights.", r.totalNights or 0)
		tip.Visible = false
	else
		cause.Text = CAUSE_TEXT[causeKey] or (if r.reason ~= "" then r.reason else "The storm was too much this time.")
		tip.Visible = true
		tip.Text = if (r.nightReached or 0) <= 1 and causeKey ~= "" then TIPS[causeKey] .. " " .. TIPS.early else (TIPS[causeKey] or TIPS.early)
	end
	drawTrack(math.max(1, r.nightReached or 0), r.totalNights or 1, won)
	trackLabel.Text = string.format("%s %d of %d \u{00B7} %s", if won then "Survived" else "Lost on night", if won then r.totalNights else math.max(1, r.nightReached or 0), r.totalNights or 0, clock(r.duration))
	if r.forecast and Forecasts[r.forecast] then
		trackLabel.Text ..= " \u{00B7} Forecast: " .. Forecasts[r.forecast].displayName
	end
	-- 3 crew
	clearMedals()
	for i, award in r.awards or {} do
		medal(i, award.title, award.player, string.format("%s %s", fmt(award.value), award.unit))
	end
	if #(r.awards or {}) == 0 then
		medal(1, "Crew", "Everyone pitched in", "No single job stood out")
	end
	yourPart.Text = yourContribution(r)
	-- 4 rewards (less prominent; economy-only tiles hide when the economy is off)
	local pearls = r.pearls and r.pearls[player.Name] or 0
	pearlTile.value.Text = if pearls > 0 then "+" .. fmt(pearls) else "0"
	pearlTile.word.Text = "PEARLS"
	pearlTile.note.Text = if pearls > 0 then "Yours to keep \u{00B7} Quartermaster" else "Survive a night to earn Pearls"
	local economy = r.economy ~= false
	shellTile.frame.Visible = economy
	lootTile.frame.Visible = economy
	shellTile.value.Text = fmt(r.shellsEarned or 0)
	shellTile.word.Text = "SHELLS EARNED"
	shellTile.note.Text = string.format("Spent %s \u{00B7} %s left at sea", fmt(r.shellsSpent or 0), fmt(r.shellsLeft or 0))
	lootTile.value.Text = fmt(r.lootSold or 0)
	lootTile.word.Text = "FROM LOOT"
	lootTile.note.Text = if (r.lootSold or 0) > 0 then "Sold to the Trader" else "No loot sold this voyage"
	-- launch additions
	momentLine.Visible = r.moment ~= nil and r.moment ~= ""
	momentLine.Text = if r.moment then "\u{2605}  Moment of the storm: " .. r.moment else ""
	renderGoal()
	remotes.GearAction:FireServer("sync") -- fresh Pearl total after this voyage's reward
	inviteRow.Visible = false
	if not invitedThisScreen then
		task.spawn(function()
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can and isOpen and not invitedThisScreen then
				inviteRow.Visible = true
			end
		end)
	end
end

local function readyCount()
	local ready, total = 0, 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Ready") then
			total += 1
			if p:GetAttribute("WantsRematch") then
				ready += 1
			end
		end
	end
	return ready, total
end

local function renderActions()
	local ready, total = readyCount()
	local left = state:GetAttribute("TimeLeft") or 0
	if voted then
		UiKit.SetBusy(againButton, true, "Ready \u{00B7} waiting for crew")
		countdown.Text = string.format("%d of %d ready \u{00B7} sailing in %s, or as soon as everyone is ready", ready, total, clock(left))
	else
		UiKit.SetBusy(againButton, false)
		countdown.Text = string.format("Next voyage in %s \u{00B7} %d of %d ready", clock(left), ready, total)
	end
end

---------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------

local function layout()
	local size = root.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local phone = UiKit.Breakpoint(size) == "phone"
	local W, H = size.X, size.Y
	local cw = math.min(if phone then W - 16 else 780, W - 16)
	local actionsH = if phone then 64 else 112
	column.Position = UDim2.new(0.5, 0, 0, if phone then 6 else 28)
	column.Size = UDim2.fromOffset(cw, H - actionsH - (if phone then 16 else 52))
	headline.TextSize = if phone then 30 else 54
	cause.TextSize = if phone then 15 else 19
	tip.TextSize = if phone then 13 else 15
	heroLamp.Visible = not phone
	medalGrid.CellSize = UDim2.fromOffset(if phone then 150 else 180, if phone then 70 else 78)
	-- four reward tiles since the launch work (Next goal): one row on desktop, 2 x 2 on phones
	-- (the reward row is ~20 px narrower than the column, so leave room for it plus the gaps)
	rewardGrid.CellSize = UDim2.fromOffset(if phone then math.floor((cw - 34) / 2) else math.min(240, math.floor((cw - 54) / 4)), 70)
	actions.Size = UDim2.fromOffset(math.min(cw, if phone then W - 16 else 620), actionsH)
	actions.Position = UDim2.new(0.5, 0, 1, if phone then -6 else -20)
	if phone then
		againButton.Size = UDim2.fromOffset(220, 48)
		againButton.AnchorPoint = Vector2.new(0, 0.5)
		againButton.Position = UDim2.new(0, 8, 0.5, -6)
		harborButton.Size = UDim2.fromOffset(170, 44)
		harborButton.AnchorPoint = Vector2.new(1, 0.5)
		harborButton.Position = UDim2.new(1, -8, 0.5, -6)
		countdown.Position = UDim2.new(0, 8, 1, -14)
		countdown.Size = UDim2.new(1, -16, 0, 12)
		countdown.TextSize = 11
	else
		againButton.Size = UDim2.fromOffset(300, 56)
		againButton.AnchorPoint = Vector2.new(0, 0)
		againButton.Position = UDim2.fromOffset(20, 16)
		harborButton.Size = UDim2.fromOffset(240, 48)
		harborButton.AnchorPoint = Vector2.new(1, 0)
		harborButton.Position = UDim2.new(1, -20, 0, 20)
		countdown.Position = UDim2.new(0, 20, 1, -32)
		countdown.Size = UDim2.new(1, -40, 0, 20)
		countdown.TextSize = 13
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

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	UiKit.popModal("Results")
	-- the HUD's own weapon slot replaces Roblox's hotbar (OwnWeaponSlot, Oct 13)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, not game:GetService("Players").LocalPlayer:GetAttribute("OwnWeaponSlot"))
	GuiService.SelectedObject = nil
	gui.Enabled = false
	content.Enabled = false
end

local function open(r)
	invitedThisScreen = false
	results = r
	voted = false
	isOpen = true
	gui.Enabled = true
	content.Enabled = true
	UiKit.pushModal("Results")
	-- the Roblox tool hotbar would sit on top of the action bar
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	layout()
	render()
	renderActions()
	column.CanvasPosition = Vector2.zero
	-- restrained entrance: the outcome settles in, nothing loops
	local scale = hero:FindFirstChild("Enter") or UiKit.new("UIScale", { Name = "Enter" }, hero)
	scale.Scale = 0.94
	UiKit.tween(scale, UiKit.Motion.slow, { Scale = 1 })
	backdrop.BackgroundTransparency = 1
	UiKit.tween(backdrop, UiKit.Motion.slow, { BackgroundTransparency = if UiKit.Breakpoint(backdrop.AbsoluteSize) == "phone" then 0.03 elseif r.result == "Victory" then 0.12 else 0.06 })
	task.defer(function()
		if UiKit.usingGamepad() then
			GuiService.SelectedObject = againButton
		end
	end)
end

remotes:WaitForChild("RunResults").OnClientEvent:Connect(function(r)
	if player:GetAttribute("Ready") then
		open(r)
	end
end)

againButton.Activated:Connect(function()
	if voted or againButton:GetAttribute("Disabled") then
		return
	end
	voted = true
	remotes.VoteRematch:FireServer()
	renderActions()
end)
harborButton.Activated:Connect(function()
	remotes.SetReady:FireServer(false) -- back to the lobby ship (the server decides)
	close()
end)

-- live: countdown, who's ready, and closing when the next voyage starts
task.spawn(function()
	while true do
		if isOpen then
			renderActions()
			local phase = state:GetAttribute("Phase")
			if phase == "Intermission" or phase == "Waiting" or phase == "Prologue" or not player:GetAttribute("Ready") then
				close()
			end
		end
		task.wait(0.25)
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
