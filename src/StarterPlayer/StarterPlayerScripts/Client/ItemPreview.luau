-- ItemPreview (client): the ONE standard for showing a 3D item (or the player's avatar).
--
--   local preview = ItemPreview.new(parentFrame, { rotatable = true })
--   preview:setItem("StormHarpoon")      -- any id from Shared/Items
--   preview:setModel(modelInstance, "Avatar")
--
-- PRESET per item kind (camera angle, how much of the frame it fills, vertical lift, how far the
-- player may turn it). The camera distance is FITTED to the model's real corners, so long
-- harpoons and small loot read at a consistent optical size. OVERRIDES adjusts single items.
--
-- Lighting is neutral and warm; a soft lamp-glow disc sits behind every item so dark models
-- (wood, iron, black pearl) still separate from dark panels. Nothing spins on its own; when
-- rotatable, the player drags (mouse), swipes (touch) or uses the right stick (controller).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local ItemModels = ReplicatedStorage:WaitForChild("ItemModels")

local ItemPreview = {}
ItemPreview.__index = ItemPreview

-- A ViewportFrame draws its contents when they change. If a preview is built while the item
-- meshes are still downloading, it can stay empty forever after they arrive. So: preload the
-- item models once, then rebuild every preview that was created before loading finished.
local ContentProvider = game:GetService("ContentProvider")
local live = setmetatable({}, { __mode = "k" }) -- previews currently alive
ItemPreview.loaded = false
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ ItemModels })
	end)
	ItemPreview.loaded = true
	for preview in live do
		if preview.itemId and preview.holder.Parent then
			preview:setItem(preview.itemId)
		end
	end
end)

-- pose: "diagonal" (long weapons tip up-right), "side", "front", "threeQuarter"
-- fill: share of the frame the model's silhouette may use (0..1)
-- lift: moves the model up (+) or down (-) as a share of the frame height
-- yaw: extra turn in degrees; yawLimit: how far the player may turn it (nil = all the way)
ItemPreview.PRESETS = {
	Weapon = { pose = "diagonal", fill = 0.92, lift = 0 },
	Armor = { pose = "front", fill = 0.84, lift = 0.02, yaw = -18, yawLimit = 110 },
	Ammo = { pose = "threeQuarter", fill = 0.8, lift = 0.02 },
	Material = { pose = "threeQuarter", fill = 0.62, lift = 0.03 },
	Avatar = { pose = "front", fill = 0.94, lift = 0 },
	Default = { pose = "threeQuarter", fill = 0.8, lift = 0 },
}

-- Single-item corrections found while checking all 11 models (see the Stage 1 report)
ItemPreview.OVERRIDES = {
	FlareGun = { pose = "side", fill = 0.8 }, -- short pistol: side view reads better than a diagonal
	BlackPearl = { fill = 0.56 }, -- a perfect sphere looks oversized at the loot fill
	CrabClaw = { yaw = 30, fill = 0.76 }, -- thin and tall: needs more fill to match the other loot
}

local function baseRotation(pose, size)
	if pose == "diagonal" then
		if size.Z > 3 then
			return CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(0, math.rad(90), 0)
		end
		return CFrame.Angles(0, math.rad(90), 0)
	elseif pose == "side" then
		return CFrame.Angles(0, math.rad(90), 0)
	elseif pose == "front" then
		return CFrame.Angles(0, math.rad(180), 0)
	end
	return CFrame.Angles(math.rad(14), math.rad(205), 0)
end

-- A soft lamp-glow spot: a disc whose edges fade out in one direction. Two crossed discs read
-- as one soft radial pool of light with no hard ring.
local GLOW_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.9),
	NumberSequenceKeypoint.new(1, 1),
})
local function glowDisc(parent, rotation)
	local disc = Instance.new("Frame")
	disc.Name = "Glow"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(1, 1)
	disc.SizeConstraint = Enum.SizeConstraint.RelativeYY
	disc.BackgroundColor3 = Color3.fromRGB(255, 226, 170)
	disc.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = GLOW_FADE
	gradient.Parent = disc
	disc.Parent = parent
	return disc
end

-- options: rotatable, zoom (multiplies fill), backdrop (default true)
function ItemPreview.new(parent, options)
	options = options or {}
	local self = setmetatable({}, ItemPreview)

	local holder = Instance.new("Frame")
	holder.Name = "PreviewHolder"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	if options.backdrop ~= false then
		-- three stacked discs read as one soft radial glow (no images needed)
		glowDisc(holder, 0)
		glowDisc(holder, 90)
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(176, 178, 188)
	viewport.LightColor = Color3.fromRGB(255, 244, 226)
	viewport.LightDirection = Vector3.new(-0.7, -1, -0.9)
	viewport.Active = options.rotatable == true
	viewport.ZIndex = 2
	viewport.Parent = holder

	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	self.holder = holder
	self.viewport = viewport
	self.world = world
	self.camera = camera
	self.yaw = 0
	self.zoom = options.zoom or 1
	self.rotatable = options.rotatable == true
	self.connections = {}
	live[self] = true

	table.insert(self.connections, viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.model then
			self:_fit()
			self:_pose()
		end
	end))

	if self.rotatable then
		local dragging, lastX = false, 0
		table.insert(self.connections, viewport.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, lastX = true, input.Position.X
			end
		end))
		table.insert(self.connections, UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				self:turn(math.rad((input.Position.X - lastX) * 0.6))
				lastX = input.Position.X
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and math.abs(input.Position.X) > 0.3 and viewport.Visible then
				self:turn(input.Position.X * 0.08)
			end
		end))
		table.insert(self.connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
	end
	return self
end

-- Turns the model by an angle (radians), respecting the preset's rotation limit
function ItemPreview:turn(delta)
	local limit = self.preset and self.preset.yawLimit
	self.yaw += delta
	if limit then
		self.yaw = math.clamp(self.yaw, -math.rad(limit), math.rad(limit))
	end
	self:_pose()
end

-- Places the model centered at the origin with the current turn applied
function ItemPreview:_place(yaw)
	local model = self.model
	model:PivotTo(CFrame.Angles(0, yaw, 0) * self.base)
	local cf = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
end

-- Camera distance that fits the model's box corners inside the frame at this turn
function ItemPreview:_distanceAt(yaw)
	self:_place(yaw)
	local cf, size = self.model:GetBoundingBox()
	local t = math.tan(math.rad(self.camera.FieldOfView / 2))
	local absolute = self.viewport.AbsoluteSize
	local aspect = if absolute.X > 0 and absolute.Y > 0 then absolute.X / absolute.Y else 1
	local fill = math.clamp(self.fill * self.zoom, 0.2, 1.2)
	local half = size / 2
	local distance = 0
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
				distance = math.max(distance, p.Z + math.abs(p.Y) / (t * fill), p.Z + math.abs(p.X) / (t * aspect * fill))
			end
		end
	end
	return distance
end

-- Fits once per model and frame size. Rotatable previews fit every turn they allow, so the
-- model never pops closer or farther while the player turns it.
function ItemPreview:_fit()
	local base = math.rad(self.preset.yaw or 0)
	if not self.rotatable then
		self.distance = self:_distanceAt(base)
		return
	end
	local limit = self.preset.yawLimit or 180
	local distance = 0
	for step = -limit, limit, 30 do
		distance = math.max(distance, self:_distanceAt(base + math.rad(step)))
	end
	self.distance = distance
end

function ItemPreview:_pose()
	if not self.model or not self.distance then
		return
	end
	self:_place(self.yaw + math.rad(self.preset.yaw or 0))
	local t = math.tan(math.rad(self.camera.FieldOfView / 2))
	local shift = -(self.preset.lift or 0) * self.distance * t * 2
	self.camera.CFrame = CFrame.new(0, shift, self.distance)
end

-- Shows a model (it is cloned). kind decides the preset; itemId (optional) applies overrides.
function ItemPreview:setModel(model, kind, itemId)
	if itemId == nil then
		self.itemId = nil
	end
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if self.placeholder then
		self.placeholder:Destroy()
		self.placeholder = nil
	end
	self.yaw = 0
	self.distance = nil
	if not model then
		return
	end
	local preset = table.clone(ItemPreview.PRESETS[kind or "Default"] or ItemPreview.PRESETS.Default)
	for key, value in (itemId and ItemPreview.OVERRIDES[itemId]) or {} do
		preset[key] = value
	end
	self.preset = preset
	self.fill = preset.fill

	local copy = model:Clone()
	if not copy:IsA("Model") then
		local wrapper = Instance.new("Model")
		copy.Parent = wrapper
		wrapper.PrimaryPart = if copy:IsA("BasePart") then copy else nil
		copy = wrapper
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local _, size = copy:GetBoundingBox()
	self.base = baseRotation(preset.pose, size)
	copy.Parent = self.world
	self.model = copy
	self:_fit()
	self:_pose()
end

-- Shows an item from the catalog. A missing model shows a clearly temporary placeholder.
function ItemPreview:setItem(itemId)
	self.itemId = itemId
	local item = Items[itemId]
	local model = item and item.model and ItemModels:FindFirstChild(item.model)
	-- Beam colours (launch R15) have no model: draw a lamp throwing a fan of that light
	if item and item.beamColor then
		self:setModel(nil)
		local color = Color3.fromRGB(item.beamColor[1], item.beamColor[2], item.beamColor[3])
		local swatch = Instance.new("Frame")
		swatch.Name = "Placeholder"
		swatch.BackgroundTransparency = 1
		swatch.Size = UDim2.fromScale(1, 1)
		swatch.ZIndex = 3
		swatch.ClipsDescendants = true
		swatch.Parent = self.holder
		for i = -2, 2 do
			local ray = Instance.new("Frame")
			ray.BorderSizePixel = 0
			ray.BackgroundColor3 = color
			ray.BackgroundTransparency = 0.15 + math.abs(i) * 0.12
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			local angle = math.rad(-12 + i * 9)
			ray.Position = UDim2.fromScale(0.22 + 0.33 * math.cos(angle), 0.62 + 0.33 * math.sin(angle))
			ray.Size = UDim2.fromScale(0.66, 0.035)
			ray.Rotation = math.deg(angle)
			ray.ZIndex = 3
			ray.Parent = swatch
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
			fade.Parent = ray
		end
		local lamp = Instance.new("Frame")
		lamp.AnchorPoint = Vector2.new(0.5, 0.5)
		lamp.Position = UDim2.fromScale(0.22, 0.62)
		lamp.Size = UDim2.fromScale(0.14, 0.14)
		lamp.SizeConstraint = Enum.SizeConstraint.RelativeYY
		lamp.BackgroundColor3 = color
		lamp.ZIndex = 4
		lamp.Parent = swatch
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = lamp
		self.placeholder = swatch
		return
	end
	if not model then
		self:setModel(nil)
		local placeholder = Instance.new("Frame")
		placeholder.Name = "Placeholder"
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.fromScale(1, 1)
		placeholder.ZIndex = 3
		placeholder.Parent = self.holder
		local diamond = Instance.new("Frame")
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Position = UDim2.fromScale(0.5, 0.42)
		diamond.Size = UDim2.fromScale(0.3, 0.3)
		diamond.SizeConstraint = Enum.SizeConstraint.RelativeYY
		diamond.Rotation = 45
		diamond.BackgroundTransparency = 1
		diamond.Parent = placeholder
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(150, 152, 156)
		stroke.Thickness = 2
		stroke.Parent = diamond
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, 0.72)
		label.Size = UDim2.new(1, -8, 0, 16)
		label.Text = "Temporary icon"
		label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
		label.TextSize = 13
		label.TextColor3 = Color3.fromRGB(150, 152, 156)
		label.Parent = placeholder
		self.placeholder = placeholder
		return
	end
	self:setModel(model, item.kind, itemId)
end

function ItemPreview:destroy()
	live[self] = nil
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.holder:Destroy()
end

return ItemPreview
