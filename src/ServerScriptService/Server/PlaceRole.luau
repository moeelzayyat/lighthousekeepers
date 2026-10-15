-- PlaceRole (multi-ship phase 2): which half of the game this server runs.
--   "single" : MULTI_SHIP_ENABLED is off. Today's game: harbor and voyage in the same server (published build).
--   "harbor" : the shared lobby. Ships, boarding, the Quartermaster; departing crews leave the server.
--              The voyage loop (GameState) never runs here.
--   "isle"   : one Lighthouse Isle voyage for one crew (a reserved server). The existing voyage loop runs here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlaceRole = {}

function PlaceRole.get()
	if Config.MULTI_SHIP_ENABLED ~= true then
		return "single"
	end
	if Config.PLACE_ROLE_OVERRIDE == "harbor" or Config.PLACE_ROLE_OVERRIDE == "isle" then
		return Config.PLACE_ROLE_OVERRIDE
	end
	if Config.ISLE_PLACE_ID ~= 0 and game.PlaceId == Config.ISLE_PLACE_ID then
		return "isle"
	end
	return "harbor"
end

return PlaceRole
