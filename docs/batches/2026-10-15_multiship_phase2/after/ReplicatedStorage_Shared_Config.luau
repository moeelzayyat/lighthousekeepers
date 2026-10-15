-- Config: every tunable number for the game lives here.
-- Times are SHORT for testing. The design targets ~90 s days and ~3 min nights.

local Config = {
	-- PLAYTEST SWITCHES -------------------------------------------------
	UI_SKIN = "pirate", -- "pirate" = wood/parchment art skin (Kenney RPG pack, CC0); false = original lighthouse look
	UI_SKIN_ATLAS = "rbxassetid://127395313470932", -- one image holding every skin piece (LK_PirateSkin_atlas.png)
	PROTOTYPE_SHORT_RUN = true, -- true = 30 s days / 90 s nights; false = the longer 45 s / 75 s timings
	ECONOMY_ENABLED = true, -- false = "stripped core" test: no loot, shells, upgrades, or cannons
	BIG_MONSTERS_ENABLED = true, -- false = no Barnacle Brute / Shipwreck Hermit (use for the stripped-core test)
	DEV_START_SHELLS = 0, -- TESTING ONLY: crew starts every run with this many shells. Set to 0 before real playtests.
	START_SHELLS = 120, -- GAMEPLAY: every voyage starts with this many Shells = 3 cannons at 40 each (owner, Oct 12 2026)
	DEV_START_PEARLS = 0, -- TESTING ONLY: new player profiles start with this many Pearls. Set to 0 before real playtests.
	DEV_TEST_BIG_MONSTER = "", -- TESTING ONLY: "BarnacleBrute" or "ShipwreckHermit" spawns one 8 s into the opening. "" = off.

	-- Pearls (personal, saved) earned at the end of each run
	PEARLS_PER_NIGHT = 1, -- 1 Pearl per night survived (owner, Oct 13: 13-night win = 13 + 5 = 18)
	PEARLS_NIGHT_STEP = 0, -- old triangular formula (night N gives N); 0 = off. Was 1 for the 3-night run.
	PEARLS_VICTORY_BONUS = 5, -- extra Pearls for surviving every night (was 0)
	PEARLS_PER_AWARD = 0,
	BOSS_PEARL_CHANCE = 0.5, -- chance a big monster drops Pearls (picked up like loot)
	BOSS_PEARL_MIN = 2,
	BOSS_PEARL_MAX = 4,
	CRAB_CLAW_CHANCE = 0.3, -- chance a crab drops a Crab Claw (personal loot)
	----------------------------------------------------------------------

	FINAL_NIGHT_CRAB_MULTIPLIER = 1.5, -- the last night is a crisis: more crabs than the formula
	-- Run structure
	NIGHTS_TO_WIN = 13, -- owner, Oct 13 2026: 10 more nights (was 3 in the short run, 5 in the long one)
	-- Difficulty growth: full growth up to GROWTH_FULL_UNTIL, then GROWTH_LATE_RATE of it per night
	GROWTH_FULL_UNTIL = 3,
	GROWTH_LATE_RATE = 0.5,
	BIG_EVERY_NIGHTS = 3, -- long runs: a big monster every 3rd night counting back from the last (13, 10, 7, 4)
	INTERMISSION_SECONDS = 10, -- "Setting sail" countdown on the ship before a run
	DAY_SECONDS = 45,
	NIGHT_SECONDS = 75,
	RESULT_SECONDS = 25, -- how long the results screen and Play Again vote stay up

	-- Opening incident (the "prologue" storm every run starts with)
	PROLOGUE_START_FUEL = 15,
	PROLOGUE_CRABS = 3,
	PROLOGUE_MAX_SECONDS = 90,

	-- Lamp fuel
	MAX_FUEL = 100,
	FUEL_DRAIN_PER_SECOND = 1.2, -- only drains at night; a full tank lasts ~80 s on the wide beam
	FUEL_PER_REFILL = 40, -- one barrel of oil
	FUEL_DRAIN_BY_CREW_SIZE = { 0.7, 0.85, 1, 1 }, -- drain multiplier for 1, 2, 3, 4 players (solo can't refuel and keep the lamp at once)
	MAX_CREW = 4, -- party size of ONE departure ship (batch 1 revision); the lobby itself holds the whole server

	-- Multi-ship (phase 2 foundation). ALL OFF in the published game: with MULTI_SHIP_ENABLED = false the
	-- place runs exactly as before (one ship, the voyage in this same server).
	MULTI_SHIP_ENABLED = false, -- harbor/isle place roles and a second departure ship
	TELEPORT_ENABLED = false, -- send crews to reserved Lighthouse Isle servers (needs the Isle place; owner-only)
	PLACE_ROLE_OVERRIDE = nil, -- Studio testing only: "harbor" or "isle" (nil = decided by PlaceId)
	HARBOR_PLACE_ID = 132065051336560, -- the Lighthouse Keepers start place
	ISLE_PLACE_ID = 0, -- the Lighthouse Isle place, once the owner creates it (0 = not created)
	ISLE_ARRIVAL_WAIT = 20, -- isle: seconds to wait for the whole crew before the voyage starts anyway
	DAWN_LOOT_SECONDS = 25, -- leftover loot stays this long into the day at full value (was 10; owner, Oct 12)
	DAWN_LOOT_FRACTION = 0.5, -- at dawn the tide brings leftover loot to the crew at this fraction of its value
	DARK_GRACE_SECONDS = 10, -- how long the lamp can be out before the run is lost

	-- Beam
	BEAM_TURN_SPEED = 120, -- degrees per second (manual control)
	BEAM_LENGTH = 105,
	BEAM_TILT = 31, -- degrees pointing down; the beam lands on the rocks at the island's edge
	WIDE_HALF_ANGLE = 18, -- how wide the beam's effect is, either side of center
	FOCUSED_HALF_ANGLE = 9,
	WIDE_VISUAL_WIDTH = 78, -- matches WIDE_HALF_ANGLE at the end of the beam
	FOCUSED_VISUAL_WIDTH = 38, -- matches FOCUSED_HALF_ANGLE
	FOCUSED_FUEL_MULTIPLIER = 2.5, -- focused beam burns fuel much faster
	FOCUSED_DPS = 35, -- damage per second in the focused beam (also stops creatures)
	WIDE_DPS = 12, -- damage per second in the wide beam (also pushes creatures back)
	WIDE_PUSH_SPEED = 7, -- studs per second creatures are pushed back by a manual wide beam

	-- Automatic sweep (nobody at the lamp)
	AUTO_SWEEP_SPEED = 25, -- degrees per second
	AUTO_SWEEP_SLOW = 0.5, -- creatures in the auto-sweep move at this fraction of normal speed
	KEEPER_IDLE_SECONDS = 25, -- Keeper is released after this long without aiming

	-- Weapons (stats for each weapon are in Shared/Weapons)
	STARTER_WEAPON = "DriftwoodHarpoon",
	DEV_GIVE_ALL_WEAPONS = false, -- TESTING ONLY: true = everyone spawns with every weapon, ignoring the shop.
	-- Launch adaptation (Oct 12 2026). Each can be switched off without code changes.
	FIRST_VOYAGE_FAST_PATH = true, -- players with 0 completed runs skip the title and join the crew right away
	COACH_ENABLED = true, -- short action-triggered prompts for players with 0 completed runs
	CREW_FEED_ENABLED = true, -- crew-wide lines and a client-only lamp flare for refuels, repairs, saves
	EVOLUTIONS_ENABLED = true, -- maxing two related bench upgrades unlocks an evolved effect for the voyage (owner-approved Oct 12)
	FORECASTS_ENABLED = true, -- crew votes between 2 storm forecasts before sailing; changes the voyage, not rewards (owner-approved Oct 12)
	AUTO_SELL_LOOT = false, -- true = carried loot sells itself at dawn at Trader values (the Trader stays). Owner: keep false until Test B
	COSMETICS_ENABLED = true, -- beam colours bought with Pearls; looks only, no power (owner-approved Oct 12)
	LAMP_SHIFT_ENABLED = true, -- at dawn, offer the lamp to a crew member who hasn't held it (both must agree)

	-- Loot (shells go into the crew's shared pool and buy lighthouse upgrades)
	-- Shell income +30% (owner, Oct 12 2026: "not enough for a cannon by the big monster"). Was 2-4.
	SHELLS_PER_CRAB_MIN = 3,
	SHELLS_PER_CRAB_MAX = 5,
	SEA_GLASS_CHANCE = 0.04, -- rare drop, about 1 in 25 crabs
	SEA_GLASS_VALUE = 33, -- was 25 (+30% Shells, Oct 12)
	BLACK_PEARL_CHANCE = 0.005, -- epic drop, about 1 in 200 crabs
	BLACK_PEARL_VALUE = 130, -- was 100 (+30% Shells, Oct 12)
	LOOT_MAGNET_RADIUS = 10, -- loot flies to players within this distance
	LOOT_PICKUP_RADIUS = 2.5,
	LOOT_LIFETIME = 60, -- uncollected loot washes away after this long (and at dawn)
	WAVE_BONUS_PER_NIGHT = 13, -- surviving night N gives N x this many shells (was 10; +30% Shells, Oct 12)

	-- Cannons (built on fixed pads with crew shells; reset every run)
	CANNON_PAD_RADIUS = 34, -- distance of the pads from the tower
	CANNON_PAD_BEARINGS = { 0, 60, 120, 180, 240, 300 }, -- six pads around the island
	CANNON_COSTS = { 40, 70, 110 }, -- build, then upgrade to level 2, level 3
	CANNON_DAMAGE = { 10, 16, 24 }, -- per shot, per level
	CANNON_RANGE = { 35, 40, 45 },
	CANNON_COOLDOWN = { 1.6, 1.4, 1.2 },
	CANNON_CAPACITY = { 15, 20, 25 }, -- max shots a cannon holds, per level (one oil barrel adds Ammo.shotsPerLoad)
	CANNON_SPLASH_RADIUS = 4, -- shots damage crabs near the impact too
	CANNON_SPLASH_TARGETS = 3,

	-- Tower
	MAX_INTEGRITY = 100,
	REPAIR_AMOUNT = 20,
	REPAIR_HOLD_SECONDS = 1.5,

	-- Rock Crabs
	CRAB_HEALTH = 30,
	CRAB_SPEED = 6,
	CRAB_TOWER_DPS = 0.6, -- damage per second each crab deals to the tower (6 crabs take ~30 s to break an undefended tower)
	CRABS_BASE = 14, -- crabs on night 1 (a swarm splits the cannons' fire)
	CRABS_PER_NIGHT = 8, -- extra crabs each night after
	SPAWN_WINDOW = 0.7, -- crabs arrive during the first 70% of the night
	MAX_CREATURES = 45, -- was 60; 45 alive at once keeps phones smooth (new ones arrive as others die)
	-- Swarm (Oct 12 2026): packs of small Sand Skitters arrive all night on top of the Rock Crabs,
	-- so there is always something to do. Switch off with SWARM_ENABLED = false.
	SWARM_ENABLED = true,
	SWARM_BASE = 42, -- skitters on night 1
	SWARM_PER_NIGHT = 16, -- extra skitters each night after
	SWARM_PACK_SIZE = 3, -- they come in small packs from one direction
	SWARM_BY_CREW = { 0.4, 0.65, 0.85, 1.0 }, -- share of the swarm for a crew of 1 / 2 / 3 / 4 (a solo Keeper can't also repair)
	SWARM_WINDOW = 0.85, -- packs keep coming through 85% of the night
	SWARM_SHELL_CHANCE = 0.26, -- a skitter drops 1 Shell 26% of the time (was 0.2; +30% Shells, Oct 12)
	PROLOGUE_SWARM = 6, -- skitters in the opening fight, after the first crabs

	-- Big sea monsters (stats in Shared/Creatures). At most MAX_BIG_PER_RUN per run.
	MAX_BIG_PER_RUN = 4, -- was 2 (owner, Oct 13: 4 bosses in the 13-night run)
	BIG_SPAWN_DELAY = 0.15, -- a big monster arrives this far into its night (0.15 = 15%, about 13 s)
	BIG_LOOT_SHELLS = 52, -- shells a big monster drops (was 40; +30% Shells, Oct 12)
	BIG_PEARL_CHANCE = 0.5, -- chance it also drops a Black Pearl (Sea Glass is guaranteed)

	-- Aggro (threat): each creature attacks whatever has the most threat on it
	THREAT_BASE_TOWER = 5, -- the tower always has at least this much, so untouched creatures go for it
	THREAT_BEAM_MULT = 0.6, -- beam damage adds this x damage as threat on the TOWER
	THREAT_WEAPON_MULT = 2.0, -- a player's weapon damage adds this x damage as threat on THAT PLAYER (one hit pulls a crab)
	THREAT_CANNON_MULT = 1.0, -- cannon damage adds this x damage as threat on THAT CANNON
	THREAT_PROXIMITY = 4, -- threat per second on a player standing within 10 studs (body-blocking)
	THREAT_DECAY = 0.08, -- fraction of threat lost per second, so creatures change their minds
	THREAT_SWITCH_RATIO = 1.25, -- a new target must beat the current one by 25% to switch

	-- What creatures do when they reach their target
	CRAB_ATTACK_RANGE = 3.5, -- studs from a player or cannon to start attacking
	CRAB_PLAYER_DAMAGE = 6, -- per bite on a player (reduced by armor)
	CRAB_ATTACK_INTERVAL = 1.0, -- seconds between bites on a player
	CRAB_CANNON_DPS = 2.0, -- damage per second each crab deals to a cannon
	CANNON_HEALTH = { 60, 90, 120 }, -- cannon health per level; at 0 the cannon is destroyed

	-- Island layout
	LOBBY_POSITION = Vector3.new(0, 0, 420), -- the ship, parked at the lobby island's shore
	LOBBY_SPAWN = Vector3.new(0, 0, 518), -- spawn plaza on the lobby island (height is found from the terrain)
	LOBBY_SHOP = Vector3.new(14, 0, 488), -- Quartermaster's stall on the lobby island, beside the path to the pier
	LOBBY_WHEEL_OFFSET = 24, -- studs from the ship's middle toward the stern (back) for the wheel
	LOBBY_SHOP_OFFSET = 16, -- studs toward the bow (front) for the Quartermaster
	LOBBY_SHOP_SIDE = 6, -- studs to the side for the Quartermaster
	USE_TERRAIN = true, -- the island, beach, and sea are Roblox terrain built in Studio (not code-built parts)
	EVENT_LOG_ENABLED = true, -- prints [EVT] lines and a run summary to Output (turn off before launch)

	-- Island layout
	ISLAND_CENTER = Vector3.new(0, 0, 0),
	ISLAND_RADIUS = 70,
	GROUND_Y = 10, -- height of the island surface where the lighthouse stands (sea surface is y = 0)
	TOWER_HEIGHT = 60,
	TOWER_ATTACK_RADIUS = 10, -- creatures stop here to attack the tower
	CREATURE_SPAWN_RADIUS = 92, -- creatures climb out of the sea here
}

-- Short timings: 13 nights x (30 s + 90 s) = about 27 minutes plus the opening
if Config.PROTOTYPE_SHORT_RUN then
	Config.DAY_SECONDS = 30 -- was 40: a breather, not a wait (Oct 12 2026)
	Config.NIGHT_SECONDS = 90
end

return Config
