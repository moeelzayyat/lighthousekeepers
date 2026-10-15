-- Creatures: stats for every creature type. Adding a monster = adding an entry here
-- (plus its 3D model in ServerStorage.Art under the same `art` name).
--
--   health          hit points
--   speed           studs per second
--   pushable        can the wide beam shove it back?
--   beamDamageMult  how much beam damage it takes (0.5 = half)
--   bodyRadius      how big it is, for hits (weapon/cannon hits count within hitRadius + this)
--   attackRange     how close it gets to a player or cannon before attacking
--   playerDamage    damage per attack on players (armor reduces it)
--   attackInterval  seconds between attacks on players
--   slamRadius      0 = bites one player; > 0 = slams every player within this many studs
--   towerDps / cannonDps   damage per second to the tower / a cannon while attacking it
--   scale           size of the 3D model (sets the art's size relative to its file)
--   big             big monsters get a boss bar, an announcement, and big loot

local Creatures = {
	RockCrab = {
		displayName = "Rock Crab",
		art = "RockCrab",
		health = 30,
		speed = 6,
		pushable = true,
		beamDamageMult = 1,
		bodyRadius = 1,
		attackRange = 3.5,
		playerDamage = 6,
		attackInterval = 1.0,
		slamRadius = 0,
		towerDps = 0.6,
		cannonDps = 2,
		scale = 1,
		big = false,
	},

	-- Swarm crab (Oct 12 2026, owner asked for constant action): small, fast, fragile. Comes in packs
	-- all night so the wide beam and harpoons always have targets. Worth little loot (economy unchanged).
	SandSkitter = {
		displayName = "Sand Skitter",
		art = "RockCrab", -- same model, smaller
		health = 6, -- was 10 in the first test: the beam must sweep them, not grind them
		speed = 8.5,
		pushable = true,
		beamDamageMult = 1.3, -- the wide beam sweeps them away
		bodyRadius = 0.6,
		attackRange = 3,
		playerDamage = 3,
		attackInterval = 0.9,
		slamRadius = 0,
		towerDps = 0.12, -- was 0.25: a solo test lost the tower 25 s into night 1
		cannonDps = 1,
		scale = 0.6,
		big = false,
		swarm = true,
	},

	BarnacleBrute = {
		displayName = "Barnacle Brute",
		art = "BarnacleBrute",
		health = 700,
		speed = 3,
		pushable = false, -- too heavy for the beam to shove
		beamDamageMult = 0.5, -- armored shell
		bodyRadius = 5,
		attackRange = 7,
		playerDamage = 28,
		attackInterval = 2.6,
		slamRadius = 8, -- ground slam hits everyone nearby
		towerDps = 5,
		cannonDps = 14,
		scale = 1,
		big = true,
	},

	ShipwreckHermit = {
		displayName = "Shipwreck Hermit",
		art = "ShipwreckHermit",
		health = 480,
		speed = 4.5,
		pushable = false,
		beamDamageMult = 0.75,
		bodyRadius = 4.5,
		attackRange = 6,
		playerDamage = 20,
		attackInterval = 1.8,
		slamRadius = 5,
		towerDps = 4,
		cannonDps = 10,
		scale = 1,
		big = true,
	},
}

-- Big monsters that can be picked for a run
Creatures.BIG_POOL = { "BarnacleBrute", "ShipwreckHermit" }

return Creatures
