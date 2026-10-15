-- VoyageCast (multi-ship phase 1): voyage messages go to the voyage crew only.
--
-- The island and the harbor share one server, so anything sent with FireAllClients also reaches the
-- players waiting in the harbor. Lighthouse announcements, combat and loot news, cannon and Trader news,
-- and the results screen are for the crew of the current voyage: the players with Ready = true (ShipRoster
-- keeps Ready in step with the departed party; harbor spectators are never Ready during a voyage).
-- Harbor messages keep using FireClient to the players they concern.

local Players = game:GetService("Players")

local VoyageCast = {}

function VoyageCast.crew()
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Ready") == true then
			table.insert(list, player)
		end
	end
	return list
end

-- remote:FireClient(player, ...) for every crew member
function VoyageCast.fire(remote, ...)
	for _, player in VoyageCast.crew() do
		remote:FireClient(player, ...)
	end
end

return VoyageCast
