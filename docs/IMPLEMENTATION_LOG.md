# Launch adaptation — implementation and verification log

*Oct 12, 2026 · Studio, place 132065051336560 · each batch backed up in `ServerStorage.Backups` first*

## Backups
| Folder | Contents |
|---|---|
| `Launch_A_before_Telemetry_2026-10-12` | all 14 server scripts, Shared.Config, Client.Menus/Main/Hud |
| `Launch_B_before_Controls_2026-10-12` | Client.Main/Hud/Menus |
| `Launch_C_before_Coach_2026-10-12` | Server.LampService/Main, Client.Main/Hud |
| `Launch_D_before_FastPath_2026-10-12` | Server.PlayerData/Main/LampService, Client.Menus |

Plus the owner's local `.rbxl` from Stage 8: `LighthouseKeepers_before_Menus_2026-10-12` in Downloads. **Check its extension** (it was given as `.rblx`).

## Batch A — config and telemetry (R1, R6)

**Changed:**
- **`Shared.Config`:**
  - `DEV_START_SHELLS` 2000 → **0**.
  - New switches `FIRST_VOYAGE_FAST_PATH`, `COACH_ENABLED`, `CREW_FEED_ENABLED`, `LAMP_SHIFT_ENABLED` (all true).
- **`Server.EventLog`:**
  - New per-player functions: `playerJoined`, `setRoute`, `mark(player, step)`, `beamHit`, `playerLeft`.
  - The run summary gets an "Onboarding" block, one line per player.
  - New `clutchSaves` counter.
  - The "crew" step carries over into the run that starts after it.
- **Hooks:**

  | Where | Step recorded |
  |---|---|
  | Server Main | join, crew, landed, first action (oil / attack), fuel, strike, leave-phase |
  | TowerService | repair |
  | DefenseService | reload |
  | LampService | lamp; `KeeperTaken` now logs the reason |
  | CreatureService | first manual beam hit per Keeper (one table lookup per hit) |

**Verified (real run, title + wheel flow, scripted player):**

| Step | Seconds since join |
|---|---|
| crew | 15.6 |
| landed | 26.1 |
| firstAction | 29.9 |
| fuel | 32.1 |
| lamp | 42.1 |
| firstBeamHit | 50.3 |

No errors. A scripted player is an upper bound on speed, not a human baseline.

## Batch B — controls (R7)

**Checked:**
- The Keeper camera is already a fixed, scripted overhead view on every device; the Keeper's WalkSpeed is 0.
- Touch aiming ignores taps on GUI buttons (`gameProcessed`).
- The Focus and Leave buttons are 48 px tall and 130–150 px wide.

**Changed:**
- **`Client.Main`:** movement controls (and so the phone joystick and jump button) are disabled while you hold the lamp and restored when you leave, so the joystick can't swallow aiming touches.

**Not changed:**
- Toggle focus stays (hold-to-focus = owner decision after Test B).
- `Q` stays "leave" (the brief's hold-`Q` would conflict).

**Not verified:** a real phone (owner checklist, PLAYTEST_KIT §6).

## Batch C — coach, crew feed, lamp shift (R3, R4, R5)

**Server:**
- **`Main`:**
  - New remotes `CrewFeed`, `LampShift` and `CoachEvent`.
  - The refuel handler sends a crew-only feed event and flags a "saved the light" refuel (night, tank < 10%).
  - The `CoachEvent` handler is whitelisted and rate-limited (60 events per player per session).
- **`LampService`:** a two-step lamp shift.
  - It runs 4 s into Day, only if a crew member hasn't held the lamp this run.
  - The Keeper must say yes, then the candidate must say yes.
  - The server rechecks the phase, the Keeper and the candidate being alive at every step.
  - It expires after 20 s and is cancelled when the phase changes.
  - If no one holds the lamp, the candidate only gets a "the lamp is free" nudge.

**Client:**
- **New `Client.Coach`** (owner pastes `launch-src/Coach.lua`), with three parts:
  - **7 prompts:** oil → tank, focus (big monster), aim, repair, lamp, bench.
    - One at a time; a prompt stays on screen at least 2.5 s.
    - Shown at most 4 times each, and retired when the player does the action.
    - Each shows the player's own input and a world marker on the thing to use.
    - Only for players with 0 completed runs, or an unknown count.
  - **Crew feed:** at most 3 lines, one every 3 s, with repeats merged.
  - **Client-only lamp flare:** a local PointLight; no server values.
  - **Lamp-shift cards:** non-blocking.

**Status: verified in live runs** (first-voyage player, scripted).
- **Prompt chain:** the oil prompt (marker on the oil pile) appears on landing → picking up oil switches it to "Pour the oil in the fuel tank" → refuelling clears it.
- **Feed and flare:** the feed showed "You refueled the light (+40%)"; the local `CoachFlare` light appeared on LampCore and removed itself.
- **Aim prompt:** appeared when the crabs landed.
- **Telemetry:** `promptShown` / `promptDone` events logged. The "done" count now only includes prompts actually shown.
- **Not verified live:** the lamp shift needs 2+ players (solo has no candidate, as designed).

**Fix found while testing (important):**
- This place runs Roblox's **built-in engine controls**: there is no `PlayerModule` in PlayerScripts.
- So `ControlModule:Disable()` silently did nothing. This affected Batch B (joystick at the lamp) and Stage 8 (no walking on the title).
- **Replaced with:**
  - **Lamp:** `GuiService.TouchControlsEnabled = false` while at the lamp (verified: false at the lamp, true after leaving).
  - **Title:** the character is held still locally (WalkSpeed / JumpPower / JumpHeight set to 0, values remembered and restored). Verified: 0 on the title, 16 / 7.2 after Play.

## Batch D — first-voyage fast path (R2)

**Server:**
- **`PlayerData`:** after loading, it sets the attributes `RunsCompleted` (-1 if the load failed) and `ProfileState` (`saved` / `memory` / `failed`). Nothing new is saved.
- **`Main`:**
  - New `joinCrew` (shared with the ship's wheel) and `chooseRoute`.
  - `chooseRoute` waits up to 6 s for the profile. It picks **fast** only when the profile is `saved` or `memory`, `runs == 0`, and the player hasn't already entered the lobby. Anything else gets **title**.
  - A fast-route player is put on the crew automatically: they sail with the next departure, or are rowed out mid-voyage.

**Client:**
- **`Client.Menus`:** it waits behind the loading cover for `Route` (title if nothing arrives within 10 s).
  - Fast route: no title. It shows "The storm is coming. The light needs a keeper." for about 2 s, then the game.

**Verified:**

| Case | Result |
|---|---|
| New profile (no save) | route `fast`; on the crew **1.1 s** after joining (was 15.6 s); landed **12.0 s** (was 26.1 s); no title; `MenuOpen=false` |
| Returning profile (`runs = 1`) | route `title`; the title shows; not put on the crew; input blocked |
| A run that reaches Results | counts as a run. Proven by accident: an unattended test run went dark, was recorded as a defeat, and the account became "returning". Test save removed afterwards. |

**Not exercised live:**
- **Failed load** (code path reviewed: `doNotSave` → `failed` → title).
- **Busy server mid-voyage join** for a first-timer (uses the existing wheel path, which was verified before).
- **Two friends joining together.**

## Batch G — the rest of the brief (owner instruction Oct 12: "complete the game", with approvals)

Backup: `Launch_G_before_Content_2026-10-12` (all 37 scripts). **Owner approvals, Oct 12:**

| Item | Approved as |
|---|---|
| R8 | apply the new prices |
| R9 | 3 forecasts, no reward change |
| R10 | keep the Trader; switch only |
| R15 | beam colours bought with Pearls, no Robux |

| ID | What was built | Where | Verified |
|---|---|---|---|
| R8 ⚑ | Prices: Storm Harpoon **30**, Keeper's Coat **35**, Flare Gun **60**, Whaler / Ironclaw **140**, Fire Shell crate **8**. The confirmation threshold dropped from 500 to 60. **Next goal** tile on Results (cheapest unowned gear, then beam colours) with a progress bar. | Shared.Items, Client.Results | Prices read back correctly from the catalog. Results showed "0 / 30 · Storm Harpoon · 30 to go". |
| R12 | **Moment of the storm** line on Results: the best of a clutch save, a big-monster kill (focused beam, final blow, or crew) and a last-stand tower (Victory with < 15%), plus "forged an evolution". | EventLog, Main, CreatureService, TowerService, UpgradeService, Client.Results | Logic logged; the line is correctly hidden when nothing qualified (the test run went dark) |
| R11 | Unrewarded **invite** buttons: on the crew card while the crew is under 4, and on Results. Each hides after use. | Client.Departure, Client.Results | Results invite visible (Studio allows invites) |
| R13 | **Evolutions:** Lens Power max + Fuel Tank max → **Overcharged Beam** (focused beam −25% fuel). Walls max + Clockwork Sweep max → **Clockwork Bastion** (repairs +50%). Free, automatic, for the voyage only. The bench has a "Combine" section. | Shared.Upgrades, UpgradeService, LampService, TowerService, Client.Bench | **Live:** buying Lens ×3 + Fuel ×3 unlocked it ("Evolution unlocked: Overcharged Beam…"); the bench showed ✓ active and 0/3 progress for the other |
| R9 ⚑ | **Forecasts:** Fog bank (wide beam −30%), Spring tide (+40% crabs at −20% HP), Leaky stores (+25% oil burn). Two are offered while waiting; the crew votes on the crew card; majority wins (a tie or no votes is random). Announced at sea; shown on Results. Rewards unchanged. | Shared.Forecasts (new), GameState, Main, LampService, CreatureService, Client.Departure, Client.Results | **Live:** the vote button registered, the server picked the voted forecast, its values were applied, and Results showed "Forecast: Leaky stores" |
| R10 ⚑ | `Config.AUTO_SELL_LOOT` (**false**): when true, carried loot sells at dawn at Trader values. The Trader stays. | Main, GameState | Code path only (switch off by owner decision) |
| R15 ⚑ | **Beam colours:** Keeper's Amber (starter), Sea Glass 25, Moonlight 40, Ember 60 Pearls. New Quartermaster tab "Cosmetics" and locker slot "Lamp beam colour". The lamp takes the **current Keeper's** colour for the whole crew. Looks only. New save field `equippedBeam` with a default (old saves load fine). | Items, PlayerData, LoadoutService, ShopService, LampService, Main, ItemPreview (drawn swatch), Shop, Inventory | **Live:** bought Sea Glass at the Quartermaster (100 → 75 Pearls), equipped it, took the lamp: beam and core turned (150, 236, 206). The save kept the purchase and the equipped beam. |

**New Config switches** (all can be turned off without code):

| Switch | Value |
|---|---|
| `EVOLUTIONS_ENABLED` | true |
| `FORECASTS_ENABLED` | true |
| `AUTO_SELL_LOOT` | false |
| `COSMETICS_ENABLED` | true |

**Test-tool note:** clicks by instance path on non-full-screen GUIs land in the wrong place (one went through a button into the world as a harpoon attack). Use computed screen coordinates. This is a test-tool issue, not a game bug.

## Performance and reliability (Studio, solo, Oct 12)

| Measure | Result | Conditions |
|---|---|---|
| Server heartbeat | 60 Hz, avg 16.7 ms, worst 19.9 ms; **game work 0.06 ms per frame** | prologue combat, 3 crabs, solo |
| Server send | 21.4 KB/s | same |
| Client render | 66.7 ms (15 fps) — **not meaningful** | Studio window unfocused, so Studio throttles rendering; client game logic still ran at 60 Hz |
| Client memory | 3.4 GB — **not meaningful** | the whole Studio editor process |
| Workspace instances | 624 | prologue |

**Not measured:**
- **4-player load:** needs a Studio multi-client test (Test → Clients: 4) or real testers.
- **Leak check across 3 consecutive runs:** the Studio link and focus limited long sessions.

**Code review:**
- All new loops are fixed-rate (0.25–0.4 s).
- Feed lines, flare lights and shift cards destroy themselves.
- Per-player tables are cleared on leave or reset.
- The beam-hit hook is one table lookup.

## Saves
- The test save `player_11752219158` was used for testing (100 test Pearls for the cosmetics check) and **removed** afterwards (checked absent).
- `DEV_START_SHELLS` was briefly 400 for the evolution test and **reverted to 0** (checked).
- All scripts parse (full sweep).

## Mobile fixes (Oct 12 evening, after the owner's Studio-emulator report)

Backup: `Mobile_before_fixes_2026-10-12`.

| Report / finding | Fix | Verified |
|---|---|---|
| Quartermaster stood **inside** the booth | `LobbyBuilder` placed him 1.2 studs back; the counter sits 2 back. He's now 4.95 back on a small wooden step (`KeeperStep`), so his head and shoulders show over the 3.7-stud counter. | Overlap test: no stall part overlaps him; 2.1 studs visible above the counter top |
| Crew card too tall on phones (334 of 375 px, overflowing) and covering the jump button | Phones: forecast buttons show name and votes only; the note, invite (still on Results), headline (the top timer shows it) and leave line are hidden | 199 px tall, ends 34 px above the jump zone; buttons 44 px, text fits |
| Results: 4 reward tiles laid out as 3+1 (desktop) and a single column (phone) | Cell width from the real row width: 4 in a row on desktop, 2×2 on phones | Phone: 2×2, all notes fit |
| Results backdrop let the HUD show through on phones | Phones: backdrop near-solid (0.03) | Code path checked |
| Rain = 900 drops/s on every device (heaviest effect for phones) | Touch devices: 35% of the drops, slightly larger so it still reads as a downpour; Low effects still turns it off | Code path checked |
| Coach searched ~2000 GUI objects every 0.4 s | Result cached | Parse check |
| **Grey screen after tapping the first shop item** | **Not reproduced** in Studio. The detail view lays out correctly at phone size. My screenshots show the 3D world as white whenever Studio isn't focused, which under the shop's dark backdrop looks grey. | **Pending:** owner screenshot from the emulator |

## Swarm (Oct 12 night, owner: "waves are too little… something to do every second")

Backup: `Swarm_before_2026-10-12`. **Owner-requested balance change.**

**Changes** (all behind `Config.SWARM_ENABLED`):

| Area | Change |
|---|---|
| New creature | **Sand Skitter**: small (Rock Crab model at 60% size), 6 HP, fast (8.5), pushable, takes 1.3× beam damage, tower damage 0.12 per second, bites players for 3 |
| Packs | Arrive in packs of 3 through 85% of each night |
| Skitters per night | 42 / 58 / 74, then scaled by crew size: **40% solo, 65% for 2, 85% for 3, 100% for 4**, and by the forecast (Spring tide) |
| Prologue | 3 Rock Crabs + **6 skitters** (was 3 crabs) |
| Day | **30 s** (was 40) |
| `MAX_CREATURES` | 45 alive at once (was 60), for phone performance; spawning waits at the cap |
| Loot | Skitters drop **1 Shell 20% of the time**, no rare loot (Shells per run roughly unchanged). Also fixed: `LootService` treated any non-RockCrab creature as a boss. |

Rock Crabs and the big monsters are unchanged.

**Measured (solo, Studio, scripted Keeper aiming at the nearest creature):**

| Test | Peak alive | Night samples with no creatures | Tower after night 1 (first 50 s) |
|---|---|---|---|
| Swarm **off**, continuous aim | 4 | many: "nearly empty", matching the owner's report | 100 |
| Swarm **on**, continuous aim | 6 | **1 of 485** | **100** |
| Swarm on, Keeper idle for the first 17 s of the night | 23 | 0 of 160 | fell after ~30 s |
| First version (10 HP skitters, no crew scaling), idle start | 38 | — | fell after ~25 s |

**Server, swarm on:** 60 Hz; 0.11 ms of work per frame; **~50 KB/s sent per player** (was ~21). That's at Roblox's comfortable limit. If 4-player tests show lag on phones, the fix is moving creature movement to the clients.

**Not yet tested:** nights 2–3 with the swarm, and 2–4 player crews.

## Shell income +30% (Oct 12 night, owner request: "not enough Shells for a cannon against the big boss")

All sources were raised in place, so every number shown (drops, Trader, Results) stays truthful. Read back from Studio:

| Source | Before | After |
|---|---|---|
| Rock Crab drop | 2–4 | **3–5** |
| Night bonus | 10 × night | **13** × night |
| Big-monster drop | 40 | **52** |
| Sea Glass | 25 | **33** |
| Black Pearl | 100 | **130** |
| Crab Claw | 3 | **4** |
| Skitter Shell chance | 0.20 | **0.26** |

Cannon costs (40 / 70 / 110) and upgrade costs are unchanged. Pearl rewards are untouched.

## Dawn loot window (Oct 12 night, owner: "loot disappears once the night is over")

Backup: `DawnLoot_before_2026-10-12`.

**Before:** 10 s into each day the tide cleared all loot on the ground (Shells credited at 50%, items lost). Orbs also expired 60 s after dropping.

**Now:**
- At dawn, every orb on the ground gets a fresh timer (`LootService.keepFor`) and stays collectable at **full value for 25 s** (`Config.DAWN_LOOT_SECONDS`, capped at day length − 3).
- The dawn message tells the crew how long they have, only when loot is actually on the ground.
- After that the tide takes the rest at 50%, as before.
- The final night still uses 10 s, since Results opens then.
- The auto-sell switch (off) now runs after the window.

**Verified:** all three scripts parse. **Live test interrupted:** the Studio link dropped during night 1, so this is to be confirmed in the owner's next playtest.

**Owner update:** "ok it stays which is good" (owner tested the dawn window in Studio).

## Housekeeping (Oct 12 night)
- `NIGHT_SECONDS` had a temporary `30 --TEMPTEST` value for a swarm check. **Restored to 90** and verified (no temp markers left in Config).
- **Starting Shells** (owner: "start with enough to build three cannons"): new `Config.START_SHELLS = 120`. Every run reset gives `START_SHELLS + DEV_START_SHELLS` (`UpgradeService`). Parse-verified; seen live as 120 Shells on the HUD.

## Pirate UI skin (Oct 12 night, owner chose option C: full pirate-kit reskin)
**Theme change:** this overrides the original UI spec line "never ropes, wood, parchment". Owner decision.

Backup: `UISkin_before_2026-10-12` (whole client folder + Config).

**Art:** Kenney "UI Pack: RPG Expansion" (CC0, kenney.nl; credit optional). 19 pieces packed into one 512×196 atlas at 2x (`LK_PirateSkin_atlas.png`), uploaded by the owner as image **127395313470932**. Edge notches were removed from the stretch areas so 9-slicing stays clean.

**How it works:**
- New `Client.UiSkin` module. `Config.UI_SKIN = "pirate"` turns it on; `false` returns to the lighthouse look. `Config.UI_SKIN_ATLAS` holds the image.
- Tokens: the surface colours become warm wood browns; the display font becomes Luckiest Guy (title).
- UiKit constructors are wrapped (no layout code changed):
  - `Panel`: wood frame (housing/dialog); dark wood for "plain" sub-areas. Brass brackets, beacon line and lens arc are hidden.
  - `Button`: gold-tinted wooden plank (primary), wood (secondary), red (danger), grey (disabled). Pressed pieces on press. Ghost buttons stay text-only.
  - The button text is mirrored into a label above the art, so `AutomaticSize`, `SetBusy` and `SetDisabled` all keep working.
  - `IconButton` "close": a round wooden button.
  - `ItemCard`: wood card with a parchment well; the gold selection outline is kept.
- Art is a background ImageLabel (ZIndex −5) sized past any UIPadding. Slice scale shrinks for small controls. If a layout object is ever added to a skinned frame, the art removes itself, so nothing gets pushed around.
- Not skinned yet: HUD gauges, toggles and sliders (they only take the warmer colours).

**Verified in Studio (PC 1920×934):**
- crew card, Quartermaster shop (cards, tabs, detail pane, disabled "Equipped" button) and title screen;
- no errors in Output;
- test save removed afterwards.

**Not yet verified:**
- phone sizes in the device emulator;
- Bench, Trader, Locker, Results and Settings screens;
- item 3D previews (Studio wasn't rendering the 3D view during the check).

## 13-night run (Oct 13, owner: "add 10 more days")
Backup: `Nights13_before_2026-10-13` (Config, GameState, Hud).

Owner choices (asked Oct 13): 18 Pearls per win, 4 bosses, gentler growth after night 3.

**Config:**
- `NIGHTS_TO_WIN = 13` (the short-run block no longer forces 3). Timings stay at 30 s days and 90 s nights, so a full run is about 27 min plus the opening.
- Pearls: `PEARLS_PER_NIGHT = 1`, `PEARLS_NIGHT_STEP = 0` (old triangular formula off), `PEARLS_VICTORY_BONUS = 5`. A win pays **18** (was 6 for 3 nights), which keeps the same Pearls per minute.
- Bosses: `MAX_BIG_PER_RUN = 4`, `BIG_EVERY_NIGHTS = 3`, giving nights **4, 7, 10 and 13**. Runs of 5 nights or fewer keep the old middle + last rule.
- Growth: `GROWTH_FULL_UNTIL = 3`, `GROWTH_LATE_RATE = 0.5`, applied to crabs and the swarm.

| Night | 1 | 4 | 7 | 10 | 13 |
|---|---|---|---|---|---|
| Crabs | 14 | 34 | 46 | 58 | 70 (×1.5 final = 105) |
| Swarm (4-player crew; solo ×0.4) | 42 | 82 | 106 | 130 | 154 |

Linear growth would have reached 110/165 crabs and 234 skitters.

**HUD:** the night diamonds are hidden when a run has more than 7 nights; "NIGHT 4 OF 13" carries it. Results shows 13 diamonds, which fits.

**UI skin follow-up:** the display font changed from Luckiest Guy to **Fredoka One**, because Luckiest Guy mangled mixed-case headlines ("THe LIGHT WenT OUT").

**Verified live (solo, Oct 13):**
- all scripts parse;
- the run starts; HUD and Results say "night 1 of 13"; night 1 spawned 14 crabs and 17 skitters, as expected;
- the run ended in Defeat on night 1 because nobody fuelled the lamp (expected); no errors.

**Not verified live:** nights 4–13, the boss nights and the 18-Pearl payout. These need a full ~27-minute run.

**Watch:**
- The Shell wave bonus is still 13 × night, so about 1,180 Shells across a full win. Bench upgrades may max out mid-run. Not changed; owner call.
- The owner's real save (published game shares the DataStore) was **not** deleted. The Studio test run counted as one more completed run (a defeat, 0 Pearls).

## Glass HUD + night lighting (Oct 13, owner: "How about making it like this")
The owner sent a mock-up: glassy navy HUD panels with a blue glow, the voyage chip at the top right, and the action prompt above a weapon slot.

Owner choices (asked Oct 13):
- glass on the **HUD only** (menus keep the wood skin);
- **no stamina** for now (it would be a new mechanic);
- a **light lighting pass**.

Backup: `HudGlass_before_2026-10-13` (Hud, Coach, Main, UiKit, UiSkin, Gear, Storm, plus a Lighting folder with the old values as attributes).

**HUD (`Client.Hud`, new "GLASS HUD" section near the end):**
- Glass style: navy (12, 20, 40) at 18% transparency, a 1.5 px blue glow stroke, 14 px corners and a soft top sheen. The wood skin's warm colour tokens are mapped back to navy inside the HUD only. Wooden buttons inside the HUD (BAG, Focus beam, Leave lamp) lose their wood art and become glass.
- Layout, as in the mock-up:
  - **voyage chip** (sun or moon + "NIGHT 4 OF 13" + timer) in the top-bar row, top right, in its own `HudTopBar` ScreenGui;
  - health alone at top left (round heart badge);
  - **BAG / tower / lamp pill** down the right; the lamp pill turns red when the lamp is dark;
  - top centre: lamp fuel, or the **blackout banner** in its place when the lamp is out (now on every screen size, not just phones);
  - bottom centre: the action prompt with its key chip (E / TAP / HOLD) on the right, above a **weapon slot**;
  - **Shells pill** at the bottom right, above the jump button on touch screens; on phones Shells sits under health.
- **Roblox's hotbar is hidden.** The weapon slot replaces it: tap, click, `1` or D-pad up draws or stows the weapon, and the outline turns gold while the weapon is in hand. Menus and Results no longer turn the hotbar back on (they check the `OwnWeaponSlot` player attribute).

**Lighting:**
- Night is moonlit blue instead of near-black:
  - `NIGHT_LIGHTING`: ClockTime 23.2, Brightness 1.6, Ambient 40/48/78, OutdoorAmbient 92/108/158;
  - `NIGHT_ATMOSPHERE`: Density 0.32, Haze 0.6, Color 52/72/122.
- Moon size 11 → 18, stars 3,000 → 4,000.
- Bloom: intensity 0.7, size 28, threshold 1.3, so the lanterns glow.
- New `ColorCorrection` "GlassPop": saturation +0.12, contrast +0.06.
- Atmosphere decay is a bluer tint.
- The night is still dark enough that the lamp beam matters.

**Verified in Studio:**
- PC 1920×934: day, prologue night, and "lamp out" with the red banner and the LAMP DARK pill.
- Phone 667×375 simulator: health with Shells, fuel, tower and lamp pills, prompt and weapon slot, all clear of the joystick and jump zones.
- All scripts parse; no errors in a live run.

**Not verified:**
- Tap-to-draw on a real phone.
- Hotbar staying hidden after Results / title round-trips.
- The top-bar chip next to Roblox's own buttons on a real phone.
- Frame rate on a phone with the new bloom and colour correction.

## HUD slimming (Oct 13, owner's real-phone screenshot)
Owner asked for three changes: (1) replace the BAG bar with a small bag icon, (2) make lamp fuel thinner and higher, (3) shrink the side panels on mobile.

Backup: `HudSlim_before_2026-10-13` (Hud, Inventory).

**Bag (`Client.Inventory`):**
- The BAG bar is now a **round glass button with a drawn backpack**. It works in the lobby too.
- **Phones:** just left of the jump button.
- **Tablets:** left of the bigger jump button.
- **PC:** bottom-right above the Shells pill, with a "B" key badge.
- B and D-pad up still open the bag.
- The weapon-slot gamepad key moved to **D-pad down** (D-pad up was already the bag's).

**Lamp fuel (`Client.Hud`):**
- Moved into the **top-bar row**, centred between Roblox's buttons and the voyage chip.
- Now a slim 30 px line: small lamp icon, label and %, and a 9 px bar; the tick scale is gone.
- It still hides while the red "lamp is out" banner shows.

**Phones (compact layout):**
- Left column 178 → 150 px, right column 174 → 146 px.
- Health and tower gauges are 28 px tall (were 38/42), with thinner bars, smaller icons and text, and tighter padding.
- The lamp pill is smaller.
- The voyage chip text is smaller.
- The cannon card is hidden; the cannon's own floating label already shows its ammo.

**Right column:** now starts at the top, since the BAG bar is gone.

**Verified in Studio:**
- PC: the slim fuel bar in the top row, the red banner, the round bag button with its badge.
- Phone simulator 932×430: small left and right columns; prompt and weapon slot clear of the joystick and jump zones.
- All scripts parse; no errors.

**Not verified:** the bag button's exact spot next to the jump button on a real phone (it depends on Roblox's jump-button position and the phone's safe area).

## Source files
**Studio is the source of truth.** `launch-src/Coach.lua` and `stage8-src/Menus.lua` are reference copies from before the last small fixes (prompt telemetry, title hold-still, first-voyage route).
