-- Ground: finds the real height of the terrain (or water surface) at a point.
-- Used so creatures, loot, and beam lights follow the actual island surface.

local Workspace = game:GetService("Workspace")

local Ground = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }
params.IgnoreWater = false

local solidParams = RaycastParams.new()
solidParams.FilterType = Enum.RaycastFilterType.Include
solidParams.FilterDescendantsInstances = { Workspace.Terrain }
solidParams.IgnoreWater = true

-- Returns the surface height at (x, z), and whether that surface is water.
-- Solid ground and the water surface are measured separately, so leftover water inside
-- filled-in terrain (it happens where land was added over old sea) can't fool it.
function Ground.heightAt(x, z)
	local origin, down = Vector3.new(x, 300, z), Vector3.new(0, -400, 0)
	local solid = Workspace:Raycast(origin, down, solidParams)
	local any = Workspace:Raycast(origin, down, params)
	if solid and (not any or any.Material ~= Enum.Material.Water or solid.Position.Y >= any.Position.Y - 0.05) then
		return solid.Position.Y, false
	end
	if any then
		return any.Position.Y, any.Material == Enum.Material.Water
	end
	return 0, true
end

return Ground
