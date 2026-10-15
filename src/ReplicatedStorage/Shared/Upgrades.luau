-- Upgrades: lighthouse upgrades the crew buys with Shells during a run.
-- They reset at the start of every run, so each run asks "what do we build this time?"
--
--   costs   shell cost of level 1, 2, 3
--   values  the effect at level 1, 2, 3 (level 0 uses the game's normal value)

local Upgrades = {
	ORDER = { "LensPower", "FuelTank", "Walls", "ClockworkSweep" },

	LensPower = {
		displayName = "Lens Power",
		description = "Beam damage +25% per level",
		costs = { 30, 60, 100 },
		values = { 1.25, 1.5, 1.75 }, -- beam damage multiplier
	},
	FuelTank = {
		displayName = "Bigger Fuel Tank",
		description = "+30 max fuel per level (and fills it)",
		costs = { 25, 50, 90 },
		values = { 130, 160, 190 }, -- max fuel
	},
	Walls = {
		displayName = "Reinforced Walls",
		description = "+50 tower strength per level (and repairs it)",
		costs = { 25, 50, 90 },
		values = { 150, 200, 250 }, -- max tower integrity
	},
	ClockworkSweep = {
		displayName = "Clockwork Sweep",
		description = "The automatic sweep damages creatures",
		costs = { 40, 80, 120 },
		values = { 4, 8, 12 }, -- damage per second while sweeping on its own
	},
}

-- Evolutions (launch R13 / roadmap 9b #1): maxing BOTH listed upgrades in a voyage unlocks one
-- evolved effect for the rest of that voyage. Free, automatic, run-only (nothing saved).
-- Read by servers through the GameState attribute "Evo_<Id>". Switch off: Config.EVOLUTIONS_ENABLED.
Upgrades.EVOLUTIONS = {
	{
		id = "OverchargedBeam",
		displayName = "Overcharged Beam",
		needs = { "LensPower", "FuelTank" },
		description = "The focused beam burns 25% less fuel",
		focusedFuelMult = 0.75,
	},
	{
		id = "ClockworkBastion",
		displayName = "Clockwork Bastion",
		needs = { "Walls", "ClockworkSweep" },
		description = "Repairs restore 50% more",
		repairMult = 1.5,
	},
}

return Upgrades
