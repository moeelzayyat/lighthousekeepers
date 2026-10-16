-- HarborDepartures (multi-ship phase 2, harbor role only): one independent departure countdown per ship.
--
-- In the single-server game GameState runs the one departure countdown (Phase "Intermission"). The harbor runs
-- no voyage, so each ship gets its own countdown here instead. The rules are unchanged and still come from
-- ShipDeparture: 4/4 starts automatically, 1 to 3 need SAIL NOW, an invalid request cancels at once.
--   * each ship has its own timer, its own state and its own lock; ships never share a countdown
--   * at the end the request is revalidated (no yield before the freeze), ShipRoster.depart(id) freezes a fresh
--     snapshot, and deps.launch(shipId, crew) takes the crew away (teleport, or a Studio simulation)
--   * the ship takes a new party (ShipRoster.unlock) once launch() returns
--
-- Replicated on the GameState folder for the client, per ship:
--   Ship_<id>_Phase    = "Waiting" | "Countdown" | "Sailing"
--   Ship_<id>_TimeLeft = whole seconds left in that ship's countdown

local HarborDepartures = {}

local POLL = 0.2

-- deps: roster, departure (ShipDeparture), boarding (ShipBoarding), state, shipIds, seconds,
--       launch(shipId, crew) -> (yields until the crew has left; errors are caught), log(kind, data)
function HarborDepartures.start(deps)
	local function publish(shipId, phase, left)
		deps.state:SetAttribute("Ship_" .. shipId .. "_Phase", phase)
		deps.state:SetAttribute("Ship_" .. shipId .. "_TimeLeft", left)
	end

	local function runShip(shipId)
		publish(shipId, "Waiting", 0)
		while true do
			while not deps.departure.requested(shipId) do
				task.wait(POLL)
			end
			-- countdown: cancelled the moment the request stops being valid (checked BEFORE completion)
			local endsAt = os.clock() + deps.seconds
			local completed = false
			while true do
				local left = endsAt - os.clock()
				publish(shipId, "Countdown", math.max(0, math.ceil(left)))
				if not deps.departure.requested(shipId) then
					break
				end
				if left <= 0 then
					completed = true
					break
				end
				task.wait(POLL)
			end
			if completed and deps.departure.requested(shipId) then -- revalidated; no yield until the freeze
				local crew = deps.roster.depart(shipId)
				deps.boarding.departed(crew)
				deps.departure.departed(shipId)
				if #crew > 0 then
					publish(shipId, "Sailing", 0)
					local ok, err = pcall(deps.launch, shipId, crew)
					if not ok then
						warn("[HarborDepartures] launch failed for " .. shipId .. ": " .. tostring(err))
						deps.log("LaunchFailed", { ship = shipId, err = tostring(err) })
					end
				end
				deps.roster.unlock(shipId)
			end
			publish(shipId, "Waiting", 0)
		end
	end

	for _, shipId in deps.shipIds do
		task.spawn(runShip, shipId)
	end
end

return HarborDepartures
