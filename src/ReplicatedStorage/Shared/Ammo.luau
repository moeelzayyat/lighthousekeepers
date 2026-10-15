-- Ammo: every kind of cannon ammunition. Adding a new ammo type = adding an entry here
-- (plus a way for players to get it, such as a new pickup or a shop item).
--
--   displayName       shown on the cannon's ammo label
--   loadedFrom        what the player must be carrying to load it ("Oil" = an oil barrel)
--   shotsPerLoad      how many shots one load adds
--   damageMultiplier  multiplies the cannon's normal damage
--   splashMultiplier  multiplies the splash radius
--   ballColor         color of the cannonball and its explosion

local Ammo = {
	DEFAULT = "OilShot",

	OilShot = {
		displayName = "Oil Shot",
		loadedFrom = "Oil",
		shotsPerLoad = 15,
		damageMultiplier = 1,
		splashMultiplier = 1,
		ballColor = Color3.fromRGB(25, 25, 25),
		boomColor = Color3.fromRGB(255, 150, 60),
	},

	FireShell = {
		displayName = "Fire Shell",
		loadedFrom = "Crate", -- a Fire Shell Crate from the player's inventory (bought in the shop)
		shotsPerLoad = 10,
		damageMultiplier = 1.6,
		splashMultiplier = 1.4,
		ballColor = Color3.fromRGB(255, 110, 40),
		boomColor = Color3.fromRGB(255, 80, 20),
	},

	-- Ideas for later (not active yet):
	-- Grapeshot:   short range, wide splash, many targets
	-- FlareShell:  lights up an area so the Keeper can see far-off creatures
	-- ChainShot:   pierces through a line of creatures
}

return Ammo
