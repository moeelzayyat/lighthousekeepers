-- Items: the ONE item catalog. Shop, Inventory, and the server all read from this list.
--
--   kind       "Weapon" (stats in Shared/Weapons), "Armor", "Ammo" (cannon ammo crates), "Material" (loot)
--   category   which Quartermaster shop tab / inventory filter it appears under
--   slot       loadout slot for equippable items: "Primary" or "Armor"
--   model      name of the 3D model in ReplicatedStorage.ItemModels (used for icons and previews)
--   price      Pearls to buy from the Quartermaster (nil = not sold)
--   sell       Pearls the Quartermaster pays for one (materials only)
--   maxStack   most a player can hold (stackable items only)
--   strengths / tradeoffs   short lines shown in the detail panels
--   starter    every player owns it from the start
--
-- Rule (from the design document): everything here is EARNED with Pearls. Nothing that
-- affects combat is sold for Robux; Robux will only buy cosmetics.

local Items = {
	SHOP_ORDER = {
		"DriftwoodHarpoon", "StormHarpoon", "FlareGun", "WhalerHarpoon",
		"OilskinCoat", "KeepersCoat", "IronclawPlate",
		"FireShellCrate",
		"CrabClaw", "SeaGlass", "BlackPearl",
		"BeamAmber", "BeamSeaGlass", "BeamMoonlight", "BeamEmber",
	},
	SHOP_CATEGORIES = { "Weapons", "Armor", "Ammunition", "Cosmetics" }, -- loot is sold to the Trader during a voyage, for shells
	INVENTORY_FILTERS = { "All", "Weapons", "Armor", "Ammunition", "Materials" },
	EXPENSIVE_PRICE = 60, -- owner-approved re-price Oct 12 2026 (was 500 with the old prices) -- purchases at or above this ask for confirmation

	-- WEAPONS (stats live in Shared/Weapons under the same id) -------------
	DriftwoodHarpoon = {
		kind = "Weapon", category = "Weapons", slot = "Primary", model = "DriftwoodHarpoon",
		name = "Driftwood Harpoon",
		description = "Your trusty starter. Quick single throws.",
		strengths = "Fast reload, reliable aim",
		tradeoffs = "Low damage; one target at a time",
		starter = true,
	},
	StormHarpoon = {
		kind = "Weapon", category = "Weapons", slot = "Primary", model = "StormHarpoon",
		name = "Storm Harpoon",
		description = "Pierces through up to 3 creatures. Great against crab swarms.",
		strengths = "Hits up to 3 creatures per throw",
		tradeoffs = "Same damage per target as the starter",
		price = 30, -- was 400 (owner-approved re-price, launch R8)
	},
	FlareGun = {
		kind = "Weapon", category = "Weapons", slot = "Primary", model = "FlareGun",
		name = "Flare Gun",
		description = "Slow, but bursts on a whole group.",
		strengths = "Area blast hits up to 6 creatures",
		tradeoffs = "Slowest reload; weak against a single big target",
		price = 60, -- was 600 (owner-approved re-price, launch R8)
	},
	WhalerHarpoon = {
		kind = "Weapon", category = "Weapons", slot = "Primary", model = "WhalerHarpoon",
		name = "Whaler's Harpoon",
		description = "Huge single hits for big monsters. Slow to reload, weak against swarms.",
		strengths = "Highest damage per hit; built for big monsters",
		tradeoffs = "Slow reload; only ever hits one creature",
		price = 140, -- was 1500
	},

	-- ARMOR (one equipped at a time) ---------------------------------------
	OilskinCoat = {
		kind = "Armor", category = "Armor", slot = "Armor", model = "OilskinCoat",
		name = "Oilskin Coat",
		description = "Standard keeper's raincoat.",
		strengths = "Light and free",
		tradeoffs = "No damage protection",
		starter = true,
		maxHealth = 100,
		damageReduction = 0,
	},
	KeepersCoat = {
		kind = "Armor", category = "Armor", slot = "Armor", model = "KeepersCoat",
		name = "Keeper's Greatcoat",
		description = "Heavy wool and leather. More health, takes less damage.",
		strengths = "+40 health, 15% less damage",
		tradeoffs = "Costs Pearls you could spend on weapons",
		price = 35, -- was 500
		maxHealth = 140,
		damageReduction = 0.15,
	},
	IronclawPlate = {
		kind = "Armor", category = "Armor", slot = "Armor", model = "IronclawPlate",
		name = "Ironclaw Plate",
		description = "Forged from giant crab shell. For facing the big ones.",
		strengths = "+90 health, 30% less damage",
		tradeoffs = "Very expensive",
		price = 140, -- was 1500
		maxHealth = 190,
		damageReduction = 0.3,
	},

	-- CANNON AMMO (used automatically when you reload a cannon) ----------
	FireShellCrate = {
		kind = "Ammo", category = "Ammunition", model = "FireShellCrate",
		name = "Fire Shell Crate",
		description = "Loads a cannon with fire shells: harder hits, bigger blasts. No oil needed.",
		strengths = "x1.6 damage, x1.4 blast, no oil run",
		tradeoffs = "Costs Pearls every time; 10 shots per crate",
		price = 8, -- was 60 (owner-approved re-price, launch R8)
		maxStack = 20,
		ammoType = "FireShell",
	},

	-- LOOT (from creatures). Run-scoped: cleared every voyage, like shells. Sold to the Trader for shells.
	CrabClaw = {
		kind = "Material", category = "Materials", model = "CrabClaw",
		name = "Crab Claw",
		description = "A common trophy from Rock Crabs. The Trader buys it for shells.",
		shellValue = 4, -- was 3 (+30% Shells, Oct 12)
		runScoped = true,
		maxStack = 999,
	},
	SeaGlass = {
		kind = "Material", category = "Materials", model = "SeaGlass",
		name = "Sea Glass",
		description = "Smooth, glowing glass. Rare. The Trader pays well for it.",
		shellValue = 33, -- was 25 (+30% Shells, Oct 12)
		runScoped = true,
		maxStack = 999,
	},
	BlackPearl = {
		kind = "Material", category = "Materials", model = "BlackPearl",
		name = "Black Pearl",
		description = "Extremely rare. The Trader pays a fortune in shells for it.",
		shellValue = 130, -- was 100 (+30% Shells, Oct 12)
		runScoped = true,
		maxStack = 999,
	},

	-- Beam colours (launch R15, owner-approved Oct 12 2026): LOOKS ONLY, bought with Pearls.
	-- The lamp shows the current Keeper's colour to the whole crew. No power, no Robux.
	BeamAmber = {
		kind = "Cosmetic", category = "Cosmetics", slot = "Beam",
		name = "Keeper's Amber",
		description = "The lighthouse's own warm light.",
		strengths = "Shown to the crew while you hold the lamp",
		tradeoffs = "Looks only: no power",
		starter = true,
		beamColor = { 255, 226, 150 },
	},
	BeamSeaGlass = {
		kind = "Cosmetic", category = "Cosmetics", slot = "Beam",
		name = "Sea Glass Beam",
		description = "Pale green light, ground from sea glass lenses.",
		strengths = "Shown to the crew while you hold the lamp",
		tradeoffs = "Looks only: no power",
		price = 25,
		beamColor = { 150, 236, 206 },
	},
	BeamMoonlight = {
		kind = "Cosmetic", category = "Cosmetics", slot = "Beam",
		name = "Moonlight Beam",
		description = "A cold, silver-blue light for the darkest nights.",
		strengths = "Shown to the crew while you hold the lamp",
		tradeoffs = "Looks only: no power",
		price = 40,
		beamColor = { 196, 218, 255 },
	},
	BeamEmber = {
		kind = "Cosmetic", category = "Cosmetics", slot = "Beam",
		name = "Ember Beam",
		description = "Deep orange light, like coals in the keeper's stove.",
		strengths = "Shown to the crew while you hold the lamp",
		tradeoffs = "Looks only: no power",
		price = 60,
		beamColor = { 255, 152, 92 },
	},
}

return Items
