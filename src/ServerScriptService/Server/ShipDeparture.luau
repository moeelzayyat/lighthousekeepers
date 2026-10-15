-- ShipDeparture (departure revision): decides WHEN a ship's party sails. Boarding (ShipBoarding) and party
-- membership (ShipRoster) never start a departure by themselves.
--   * 4/4, a full party: an automatic departure starts. If the party drops below 4 before the ship sails it
--     is cancelled at once; reaching 4/4 again starts a new one.
--   * 1 to 3 aboard: nothing happens until a registered member uses SAIL NOW at the ship's wheel. That
--     starts a manual departure for the whole party. It is cancelled if the player who called it leaves the
--     party, or if the party empties. If the party fills to 4 during it, the same countdown simply continues
--     (one timer, never shortened or restarted).
--   * Play Again on the results screen is also a deliberate departure, for the crew that chose it.
-- GameState runs the one visible countdown (Phase "Intermission") while a departure is requested, and
-- freezes a fresh roster snapshot (ShipRoster.depart) when it completes.
--
-- Replicated on the GameState folder for the client:
--   Ship_<id>_Departure = "auto" | "manual" | "rematch" | nil
--   Ship_<id>_Initiator = UserId of the SAIL NOW player (manual only)

local ShipDeparture = {}

local requests = {} -- shipId -> { mode = "auto" | "manual" | "rematch", initiator = Player? }
local deps = nil

local function crew(shipId)
	return deps.roster.members(shipId)
end

local function publish(shipId)
	local r = requests[shipId]
	deps.state:SetAttribute("Ship_" .. shipId .. "_Departure", r and r.mode)
	deps.state:SetAttribute("Ship_" .. shipId .. "_Initiator", r and r.initiator and r.initiator.UserId)
end

local function tell(shipId, text)
	for _, p in crew(shipId) do
		deps.notify(p, text)
	end
end

local function start(shipId, mode, initiator)
	requests[shipId] = { mode = mode, initiator = initiator }
	publish(shipId)
	deps.log("DepartureStarted", { ship = shipId, mode = mode, by = initiator and initiator.Name or "", crew = #crew(shipId) })
end

local function cancel(shipId, why, text)
	local r = requests[shipId]
	if not r then
		return
	end
	requests[shipId] = nil
	publish(shipId)
	deps.log("DepartureCancelled", { ship = shipId, mode = r.mode, why = why, crew = #crew(shipId) })
	if text then
		tell(shipId, text)
	end
end

-- Re-checks one ship. Called on every roster change (ShipRoster.onChange) and by a light poll.
function ShipDeparture.evaluate(shipId)
	if deps.roster.isLocked(shipId) then
		return -- sailed: nothing to decide until the ship is back in port
	end
	local n = #crew(shipId)
	local r = requests[shipId]
	if r == nil then
		if n >= deps.roster.CAPACITY then
			start(shipId, "auto")
			tell(shipId, "The crew is full! The ship is preparing to sail. Step off now if you want to stay behind.")
		end
	elseif n == 0 then
		cancel(shipId, "empty")
	elseif r.mode == "auto" and n < deps.roster.CAPACITY then
		cancel(shipId, "below four", "A crew member left, so the departure is off. It starts again when the crew is full, or use SAIL NOW at the wheel.")
	elseif r.mode == "manual" and (r.initiator.Parent == nil or deps.roster.shipOf(r.initiator) ~= shipId) then
		cancel(shipId, "initiator left", "The player who called SAIL NOW left the crew, so the departure is off.")
	end
end

-- SAIL NOW at the wheel. Returns ok, reason ("started" | "not crew" | "sailed" | "already" | "full").
function ShipDeparture.sailNow(player, shipId)
	if deps.roster.shipOf(player) ~= shipId then
		return false, "not crew"
	end
	if deps.roster.isLocked(shipId) then
		return false, "sailed"
	end
	if requests[shipId] then
		return false, "already"
	end
	local n = #crew(shipId)
	if n >= deps.roster.CAPACITY then
		return false, "full" -- a full crew departs automatically
	end
	start(shipId, "manual", player)
	tell(shipId, string.format("%s called SAIL NOW! The ship sails with its crew of %d when the countdown ends. Step off now if you want to stay behind.", player.DisplayName, n))
	return true, "started"
end

-- Play Again after a voyage: the crew that chose it sails again (called while the ship is still locked).
function ShipDeparture.rematch(shipId)
	if not requests[shipId] and #crew(shipId) > 0 then
		start(shipId, "rematch")
	end
end

-- Revalidates before answering: an automatic departure below 4/4, a SAIL NOW whose caller left, or an empty
-- party is cancelled here, so GameState never launches on a request that is no longer valid.
function ShipDeparture.requested(shipId)
	ShipDeparture.evaluate(shipId)
	return requests[shipId] ~= nil
end

-- The countdown completed and the party was frozen: the request is used up.
function ShipDeparture.departed(shipId)
	requests[shipId] = nil
	publish(shipId)
end

-- d: roster (ShipRoster), state (GameState folder), shipIds, notify(player, text), log(kind, data), manual (tests: no poll)
function ShipDeparture.init(d)
	deps = d
	requests = {}
	for _, id in d.shipIds do
		publish(id)
	end
	d.roster.onChange = ShipDeparture.evaluate
	if d.manual then
		return
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, id in d.shipIds do
				local ok, err = pcall(ShipDeparture.evaluate, id)
				if not ok then
					warn("[ShipDeparture] " .. tostring(err))
				end
			end
		end
	end)
end

return ShipDeparture
