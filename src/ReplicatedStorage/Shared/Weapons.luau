-- Weapons: every on-foot weapon is one entry here. Adding a weapon = adding an entry.
--
--   damage      damage per hit, to each creature hit
--   cooldown    seconds between attacks
--   range       max throw/shot distance
--   hitRadius   how close to a creature the shot must land
--   maxTargets  how many creatures one shot can hit (1 = single target)
--   projectile  "spear" or "flare" (the visual)
--
-- Balance rule: on-foot weapons do much less damage per second than the lamp
-- (wide beam 12/s, focused 35/s). They help; the beam carries.

local Weapons = {
	DriftwoodHarpoon = {
		displayName = "Driftwood Harpoon",
		damage = 8,
		cooldown = 0.9, -- about 9 damage per second
		range = 50,
		hitRadius = 5,
		maxTargets = 1,
		projectile = "spear",
		color = Color3.fromRGB(120, 85, 55),
	},
	StormHarpoon = {
		displayName = "Storm Harpoon",
		damage = 9,
		cooldown = 0.9, -- same single-target damage, but pierces up to 3 crabs
		range = 60,
		hitRadius = 6,
		maxTargets = 3,
		projectile = "spear",
		color = Color3.fromRGB(80, 140, 220),
	},
	FlareGun = {
		displayName = "Flare Gun",
		damage = 11,
		cooldown = 1.8, -- slower, but bursts on a group
		range = 70,
		hitRadius = 8,
		maxTargets = 6,
		projectile = "flare",
		color = Color3.fromRGB(230, 90, 50),
	},
	WhalerHarpoon = {
		displayName = "Whaler's Harpoon",
		damage = 45,
		cooldown = 1.6, -- about 28 damage per second, but only ever one target: built for big monsters
		range = 55,
		hitRadius = 5,
		maxTargets = 1,
		projectile = "spear",
		color = Color3.fromRGB(150, 160, 175),
	},
}

return Weapons
