# Lighthouse Keepers — Project Handover (progress.md)

*Last updated: October 14, 2026. This file is the single source of truth for a new session. Read it top to bottom before touching Studio.*

| | |
|---|---|
| **Game** | Lighthouse Keepers: co-op storm survival for Roblox, 1–4 players, PC + phone (+ controller later) |
| **Roblox place ID** | 132065051336560 (universe 10769064643) |
| **Experience name on Roblox** | "Lighthouse Keepers - Staging" |
| **Status** | **Published by the owner on Oct 13, 2026.** The owner meant it to be public. Check privacy and the Maturity questionnaire in the Creator Dashboard if it can't be found. |
| **Owner** | Mohamed. Roblox test account **"Lighthouse8282"** (UserId **11752219158**) |
| **Developer** | Claude, working in Roblox Studio through the Studio MCP tools on the owner's Windows PC |
| **Source of truth** | **Studio** (not Rojo/Git yet). Files in this folder are notes and reference copies. |

---

## 0. START HERE

### Where things stand (Oct 14)
- The game is **published and playable**. It has:
  - a full 13-night run;
  - swarm enemies and 4 boss nights;
  - an economy (Shells inside a run, Pearls saved forever);
  - the Quartermaster shop, locker, upgrade bench and Trader;
  - forecasts, evolutions and beam colours;
  - a coach for new players;
  - a wooden "pirate" menu skin and a **glassy navy in-game HUD** modelled on the owner's mock-up.
- The last work, on Oct 13, was mobile HUD polish from the owner's real-phone screenshots:
  - a round bag icon;
  - a slim lamp-fuel bar in the top row;
  - smaller side panels on phones.
- **Nothing is half-built.** All scripts parse. The last live runs showed no errors.
- **The next job:** the owner's six feature requests in **section 14c**, in the suggested order. Start with bosses scaled by crew size and a boss every night after night 7. Several ⚑ decisions there need the owner's answer first. Recommended defaults are listed with each one.
- **After every change,** remind the owner to **re-publish** from Studio, or players won't get it.

### What the owner should attach in a new session
- This `progress.md` (required).
- `IMPLEMENTATION_LOG.md`: detailed change log of every batch since Oct 12.
- Optional:
  - `LAUNCH_ADAPTATION_PLAN.md`;
  - `PLAYTEST_KIT.md`;
  - `ICON_BRIEF.md`;
  - `LK_PirateSkin_atlas.png`;
  - `ROBLOX_GAME_DEVELOPER_REVISION_BRIEF.md` (the psychology coach's brief);
  - the original UI spec ("TASK: Completely polish and visually redesign the existing Lighthouse Keepers menus…").

---

## 1. The game

**One paragraph:** 1–4 players defend a lighthouse on a storm island through **13 nights**.
- One player can take the **lamp console** and aim the beam:
  - **wide** pushes groups back;
  - **focused** burns tough enemies but uses about 2.5× fuel.
- The others:
  - carry **oil** to the fuel tank;
  - **repair** the tower;
  - fight with **harpoons**;
  - build and reload **cannons**;
  - grab **loot** that the creatures drop.
- If the lamp stays dark for 10 seconds, or the tower breaks, the voyage is lost.
- Between runs, players stand on **Harbor Island**:
  - spend **Pearls** at the **Quartermaster** on permanent gear and beam colours;
  - equip in the **locker** (BAG);
  - join the crew at the **ship's wheel** to sail to the lighthouse island.

**The promise being tested:**
- **Click:** "What is that enormous thing outside the lighthouse?"
- **Stay:** "We nearly lost the light, but we saved it together."
- **Return:** "Let's try a different approach in the next storm."

**Run flow:**
1. **Title screen** (returning players) or **first-voyage fast path** (new players skip the title and go straight to the crew).
2. Harbor lobby.
3. Ship's wheel ("Join the crew"); the crew votes on the forecast.
4. Sail.
5. **Prologue** (storm hits, restore the light, first fight).
6. **13 × (Day 30 s → Night 90 s).**
7. **Results** (cause, awards, Moment of the storm, rewards, next goal), then **Sail again** or **Back to harbor**.

**Roblox store description** (written Oct 13, about 900 characters). The owner has it. It mentions only built features. Update it when bosses-by-crew or the island merchant ship.

---

## 2. Hard rules (owner's words — never break)

- **Never publish without approval.** "Do not publish, deploy, enable monetization, purchase assets, or modify the public Roblox experience without explicit owner approval." The owner publishes; Claude never does.
- **No pay-to-win, and no publishing from backups.** Never sell gear power for Robux. Never "Save to Roblox" or publish from a backup file.
- **Gameplay numbers need a yes.** Don't change prices, rewards, stats, server validation, duplicate-request protection or the DataStore schema unless the owner says so. Many have been approved; see section 6. Ask with options, recommend one, then do it.
- **Back up before every batch:**
  - copy the scripts you'll touch into `ServerStorage.Backups.<Name>_before_<date>`;
  - for big changes, the owner also saves a local `.rbxl` (File → Save to File; the extension must be `.rbxl`, not `.rblx`).
- **Revert temporary test values** (e.g. `DEV_START_SHELLS`, `--TEMPTEST` markers) before reporting.
- **SAVES ARE LIVE NOW.** Since publishing, Studio uses the **same DataStore as the live game**. **Never `RemoveAsync` the owner's save** (`player_11752219158`); it holds real progress. Studio test runs count as real runs on the owner's account. Say so when it happens.
- **The owner's email is for identification only.** Never send it anywhere.
- **Downloads are untrusted.** Downloaded files and archives go in their own new empty folder, and Python that reads them runs with `-I`.
- **Monetization policy (owner, Oct 11):**
  - Cosmetics may be Robux-only.
  - Convenience items may be sold only if the same item is also **earnable in normal play**.
  - **Never sold:** combat stats, weapon or armor power, upgrade ranks, paid revives, random paid crates.
  - No grind inflation.
  - **Nothing is enabled for Robux yet.**

**Working agreement:**
- The owner sometimes brings external AI reviews or briefs. Weigh them honestly, propose a trimmed version where they overreach, and let the owner decide.
- The owner prefers short plain-English replies, a working result, and one question at a time only when a real decision is needed.

---

## 3. How to work in Studio (hard-won facts)

**Tools:** Roblox Studio MCP via the owner's PC. Tool names look like `mcp__remote-devices__Roblox_Studio__*`.
- Call **`list_roblox_studios` first every time**; the studio id changes on each reconnect. The place shows as "Lighthouse Keepers - Staging (placeId 132065051336560)".

**Main tools:**
- `execute_luau` (datamodels: Edit / Client / Server);
- `multi_edit` (edit or create scripts; Edit only);
- `script_read`, `script_grep` (Lua patterns, **no `|` alternation**; at most 50 results);
- `start_stop_play`, `screen_capture`, `get_console_output`.

**The MCP link is unstable.**
- Calls time out after about 60 s. A timed-out call **may still have run**, so don't blindly repeat non-idempotent calls.
- Keep calls short.
- Don't `task.wait` more than about 50 s in one call; loop across calls instead.
- For big new code, insert a placeholder line (`--@PART2`), then replace it piece by piece with `multi_edit`.
- **Never** use `ScriptEditorService:UpdateSourceAsync` for big sources; it crashed Studio twice.
- **Parse-check after every edit:** `loadstring(script.Source)` in the Edit context.

**Play mode:**
- Edit is unavailable while playing. **Stop Play before editing.**
- If Edit says "not available in Play mode" and you didn't start Play, **the owner may be testing**. Wait and retry; don't stop their session.

**Studio must be visible.** When Studio is minimized or unfocused it renders 0 frames: screenshots show a white world, prompts don't fire and 3D previews are blank. That's not a game bug.

**Engine controls:** this place has **no PlayerModule** (Roblox's built-in controls).
- Use `GuiService.TouchControlsEnabled` to hide the phone joystick and jump button.
- To freeze a character, set the Humanoid's WalkSpeed / JumpPower / JumpHeight locally.
- `ControlModule:Disable()` does nothing here.

**Getting into a run quickly (for tests):**
1. Start Play.
2. From the Client: `ReplicatedStorage.Remotes.EnterLobby:FireServer()`.
3. From the Server: `Players:GetPlayers()[1]:SetAttribute("Ready", true)`. The run starts after the intermission, about 10 s.
4. To clear the title overlay in the Client: `PlayerGui.Menus.Enabled = false`, then `player:SetAttribute("MenuOpen", false)`.
5. Optionally hide the player list: `StarterGui:SetCoreGuiEnabled(PlayerList, false)`.

**Run timing:** the prologue lasts up to 90 s, then Day 1 (30 s), then Night 1 (90 s). With no oil delivered, the lamp dies in night 1 and the run ends in Defeat about 2–2.5 min in. That's a quick way to reach Results.

**Phone layout simulator:** set the player attribute `HudSimulate` to `smallPhone` (667×375), `largePhone` (932×430), `tablet` (1180×820), `laptop` (1366×768) or `""` for off.
- Hud, Inventory, Shop, Bench, Trader, Departure, Results and Menus support it.
- The new `HudTopBar` (voyage chip + fuel) and the round bag button follow the **real** screen, not the simulator.

**Opening the shop from a test:** in the Server context, `ReplicatedStorage.Remotes.ShopOpen:FireClient(player, true, "Welcome aboard.")`.

**Clicking in tests:**
- Prefer computed screen coordinates. Screenshots are downscaled (2004 → 1920 px).
- Instance-path clicks on non-full-screen GUIs can miss and land in the world.

**Test loot:** server `execute_luau` runs a separate module instance, so it can't reach player profiles. Add a temporary Studio-only Script with a BindableEvent, and **delete it afterwards**.

**Assets:**
- An image can't be uploaded from this cloud workspace directly. The owner imports it: Asset Manager → Images → Import → right-click → Copy Asset ID.
- Pack several images into one atlas so it's a single upload.

**Account note:** a Roblox daily screen-time limit on the owner's account once caused asset 403s and a white world (fixed in parental settings).

---

## 4. What is built (current build)

### World
- **Harbor Island lobby** (20+ players):
  - spawn, Quartermaster stall (he stands on a `KeeperStep` behind the counter);
  - campfire, pier, lanterns, palms;
  - the pirate ship at the shore, with the wheel used to join the crew.
- **Lighthouse island:**
  - the tower (lamp console at the door);
  - fuel tank, oil barrels, cannon pads, the upgrade bench, the Trader, rocks and beaches.

### Core gameplay
- **Lamp beam:**
  - Wide or focused (focused costs 2.5× fuel, with a laser hum).
  - Auto-sweep when nobody is at the console.
  - Idle Keepers are released.
  - The Keeper's camera is a fixed overhead view.
  - On phones, the joystick and jump button hide at the lamp; drag to aim.
- **Fuel:**
  - Drains over time, scaled by crew size.
  - Carry oil from the barrels to the tank.
  - An emergency reserve kicks in once in the prologue.
  - Blackout after **10 s dark** (`DARK_GRACE_SECONDS`) ends the run.
- **Tower:** creatures damage it; players repair by holding at the door.
- **Weapons** (Tools, drawn and stowed with the new HUD weapon slot): Driftwood Harpoon (starter), Storm Harpoon, Flare Gun, Whaler Harpoon.
- **Armor:** Oilskin (starter), Keeper's Coat, Ironclaw.
- **Cannons:**
  - Built on pads for Shells (40 / 70 / 110 for levels 1 / 2 / 3).
  - Need ammo: oil shot from carried oil, or Fire Shell crates.
  - Have their own health.
  - A floating label above each shows its ammo.
- **Aggro:** creatures target the tower, players, or whoever is hitting them.
- **Creatures:**
  - **Rock Crab:** the common one.
  - **Sand Skitter:** swarm, 6 HP, fast, packs of 3 all night.
  - **Big monsters:** **Barnacle Brute** (700 HP) and **Shipwreck Hermit** (480 HP). They come with a warning ("something BIG is coming") and a boss bar.
- **Difficulty per night:**
  - Crabs: `14 + 8 × growth`.
  - Skitters: `42 + 16 × growth`, scaled by crew size (40% solo / 65% / 85% / 100%) and by the forecast.
  - `growth` is night − 1 up to night 3, then +0.5 per night.
  - The last night has ×1.5 crabs.
  - At most **45 creatures alive** at once.
  - **Bosses on nights 4, 7, 10 and 13** (one each).
- **Loot:**
  - Crab Claw, Sea Glass and Black Pearl drop as orbs, plus Shell orbs.
  - At dawn the orbs stay **25 s** at full value; then the tide brings the rest in at 50%.
  - Loot is run-only: sold to the **Trader** for Shells, cleared at run end.
  - An auto-sell switch exists and is off.

### Economy
- **Shells** are the in-run currency and reset every run.
  - Every run starts with **120** (enough for 3 cannons).
  - **Earned from:** crab drops 3–5; skitters 26% chance of 1; boss 52; the night bonus (13 × night number, about 1,180 over a full win); Trader sales (Crab Claw 4, Sea Glass 33, Black Pearl 130).
  - **Spent on:** bench upgrades, cannons and ammo.
- **Pearls** are saved forever.
  - **A run pays:** 1 per night survived, plus **5 for a win** (a full 13-night win = **18**).
  - Bosses also have a 50% chance to drop 2–4 Pearls.
- **Prices (Pearls):**

  | Item | Price |
  |---|---|
  | Storm Harpoon | 30 |
  | Keeper's Coat | 35 |
  | Flare Gun | 60 |
  | Whaler Harpoon / Ironclaw | 140 |
  | Fire Shell crate (stack 20, 10 shots each) | 8 |
  | Beam colours: Sea Glass / Moonlight / Ember | 25 / 40 / 60 |

  Purchases of 60 or more ask for confirmation.
- **Upgrade bench** (Shells, one run only):
  - Lens Power, Fuel Tank, Reinforced Walls, Clockwork Sweep.
  - **Evolutions:** Lens + Fuel maxed → **Overcharged Beam** (focus uses 25% less fuel); Walls + Clockwork maxed → **Clockwork Bastion** (repairs +50%).
- **Forecasts:** two are offered before sailing and the crew votes.
  - **Fog bank:** wide beam −30%.
  - **Spring tide:** +40% crabs at −20% HP.
  - **Leaky stores:** +25% oil burn.
  - Rewards are unchanged by the forecast.
- **Beam colours:** cosmetic and bought with Pearls. The lamp shows the **current Keeper's** colour.

### Player experience features (launch adaptation, Oct 12)
- **Telemetry:** a per-player "Onboarding" block in the run summary, role contributions, the phase a player quit in, and the route they took.
- **First-voyage fast path:** a new player is on the crew 1.1 s after joining, with no title. Returning players see the title.
- **Coach (`Client.Coach`):** short prompts for players with 0 completed runs. They point at the oil, the tank, focus, aiming, repair, the lamp and the bench, each with a world marker and the player's own input.
- **Crew feed:** "X refueled the light", plus a local lamp flare.
- **Lamp shift:** a two-yes hand-over at dawn, so others can try the lamp. Needs 2+ players; untested.
- **Results:**
  - cause of the result, night track, tip, awards, "your part";
  - **Moment of the storm**;
  - rewards tiles;
  - **Next goal** (cheapest unowned item with a progress bar);
  - invite button.
- **Invites:** unrewarded, on the crew card and on Results.

### UI (all built on `Client.UiKit` v2.1)
- **Menus** (title, How to Play, Settings): rebuilt in UI Stage 8. Settings are **session-only** (owner decision).
- **Quartermaster shop:**
  - tabs: Weapons, Armor, Ammunition, Cosmetics;
  - 3D previews;
  - server-validated purchases that are safe against double requests.
- **Locker / Inventory:** tabs All, Weapons, Armor, Ammo, Loot, plus a beam-colour slot.
- **Bench, Trader, Departure (crew card + forecast vote), Results** each have their own client script.
- **Pirate skin on all menus** (Oct 12): wood panels, parchment wells, wooden buttons.
  - Art: Kenney UI Pack RPG Expansion (CC0), one atlas image, ID **127395313470932**.
  - Code: `Client.UiSkin`, switched by `Config.UI_SKIN = "pirate"` (`false` = the original navy/brass lighthouse look).
  - The display font is **Fredoka One**. Luckiest Guy was tried and dropped because it mangled mixed-case headlines.
- **Glass HUD in-game** (Oct 13, from the owner's mock-up): navy glass panels at 18% transparency with a blue glow.
  - **Top-bar row:** slim **lamp-fuel** bar (centre) and a **voyage chip** (sun or moon + "NIGHT 4 OF 13" + timer, top right). Both live in their own `HudTopBar` ScreenGui with device safe insets.
  - **Top left:** health with a round heart badge (on phones, Shells sit under it).
  - **Right column:** tower gauge, then the **lamp pill**, which turns red with "LAMP DARK" when the lamp is out.
  - **Lamp out:** the red "THE LAMP IS OUT" banner replaces the fuel bar.
  - **Bottom centre:** the action prompt, with its key chip (E / TAP / HOLD) on the right, above a **weapon slot**.
    - The slot replaces Roblox's hotbar (the Backpack CoreGui is hidden).
    - Tap, click or `1` draws or stows the weapon; on a controller, **D-pad down**.
    - The slot's outline is gold while the weapon is in hand.
  - **Bag:** a **round glass bag button** (`Client.Inventory`) left of the jump button on phones, bottom right on PC with a "B" badge. **B** or **D-pad up** also opens the bag.
  - **Shells pill:** bottom right on PC.
  - **Phones:** smaller columns (150 / 146 px), 28 px gauges, and the cannon card hidden.
- **Lighting:** moonlit blue nights (ClockTime 23.2, Brightness 1.6, blue ambients, lighter atmosphere), a bigger moon, glowing lanterns (bloom), and a `GlassPop` colour correction (+12% saturation, +6% contrast).

---

## 5. Config (`ReplicatedStorage.Shared.Config`) — current values

| Setting | Value | Notes |
|---|---|---|
| `UI_SKIN` / `UI_SKIN_ATLAS` | `"pirate"` / `rbxassetid://127395313470932` | `false` = original look |
| `PROTOTYPE_SHORT_RUN` | true | 30 s days / 90 s nights (false = 45 / 75) |
| `NIGHTS_TO_WIN` | **13** | owner, Oct 13 (was 3) |
| `DAY_SECONDS` / `NIGHT_SECONDS` | 30 / 90 | set in the short-run block at the bottom |
| `PROLOGUE_MAX_SECONDS` | 90 | |
| `GROWTH_FULL_UNTIL` / `GROWTH_LATE_RATE` | 3 / 0.5 | gentler difficulty after night 3 |
| `CRABS_BASE` / `CRABS_PER_NIGHT` / `FINAL_NIGHT_CRAB_MULTIPLIER` | 14 / 8 / 1.5 | |
| `SWARM_ENABLED` | true | |
| `SWARM_BASE` / `SWARM_PER_NIGHT` / `SWARM_PACK_SIZE` | 42 / 16 / 3 | |
| `SWARM_BY_CREW` | {0.4, 0.65, 0.85, 1.0} | |
| `SWARM_WINDOW` / `SWARM_SHELL_CHANCE` / `PROLOGUE_SWARM` | 0.85 / 0.26 / 6 | |
| `MAX_CREATURES` | 45 | phone performance |
| `BIG_MONSTERS_ENABLED` | true | |
| `MAX_BIG_PER_RUN` / `BIG_EVERY_NIGHTS` | 4 / 3 | nights 13, 10, 7, 4 |
| `BIG_SPAWN_DELAY` | 0.15 | |
| `BIG_LOOT_SHELLS` / `BIG_PEARL_CHANCE` | 52 / 0.5 | |
| `PEARLS_PER_NIGHT` / `PEARLS_NIGHT_STEP` / `PEARLS_VICTORY_BONUS` | 1 / 0 / 5 | win = 18 |
| `BOSS_PEARL_CHANCE` / `MIN` / `MAX` | 0.5 / 2 / 4 | |
| `START_SHELLS` / `DEV_START_SHELLS` | 120 / 0 | |
| `WAVE_BONUS_PER_NIGHT` | 13 | |
| `SHELLS_PER_CRAB` | 3–5 | |
| `SEA_GLASS_VALUE` / `BLACK_PEARL_VALUE` | 33 / 130 | |
| `BLACK_PEARL_CHANCE` | 0.005 | |
| `DAWN_LOOT_SECONDS` / `DAWN_LOOT_FRACTION` | 25 / 0.5 | |
| `MAX_FUEL` / `DARK_GRACE_SECONDS` / `FOCUSED_FUEL_MULTIPLIER` | 100 / 10 / 2.5 | |
| `ECONOMY_ENABLED` | true | false = "stripped core" playtest |
| `FIRST_VOYAGE_FAST_PATH` / `COACH_ENABLED` / `CREW_FEED_ENABLED` / `LAMP_SHIFT_ENABLED` | true | |
| `EVOLUTIONS_ENABLED` / `FORECASTS_ENABLED` / `COSMETICS_ENABLED` | true | |
| `AUTO_SELL_LOOT` | false | owner: keep the Trader |
| `DEV_START_PEARLS` / `DEV_GIVE_ALL_WEAPONS` / `DEV_TEST_BIG_MONSTER` | 0 / false / "" | test-only; keep off |
| `EVENT_LOG_ENABLED` | true | prints a run summary to Output |

Night and day lighting tables (`NIGHT_LIGHTING`, `NIGHT_ATMOSPHERE`, `DAY_*`) live in **`Server.GameState`**, not Config.

---

## 6. Owner-approved changes to numbers (so nobody "fixes" them back)

| Date | Change | Owner's words / choice |
|---|---|---|
| Oct 12 | R8 prices (see section 4) | "Apply proposal" |
| Oct 12 | R9 forecasts, 3 of them, no reward change | approved |
| Oct 12 | R10: keep the Trader; auto-sell switch off | approved |
| Oct 12 | R15: beam colours for Pearls only; new save field `equippedBeam` | approved |
| Oct 12 | Swarm (Sand Skitters) | "we need swarming… something to do every second" |
| Oct 12 | All Shell income +30% | "increase the amount of shells… by 30%" |
| Oct 12 | Dawn loot window, 25 s | "let it out for a while" |
| Oct 12 | `START_SHELLS = 120` | "enough to build three cannons" |
| Oct 12 | Pirate menu skin (overrides the spec's "no wood, parchment or cartoon pirate") | option C |
| Oct 13 | 13 nights; Pearls 1 per night + 5 for a win; 4 bosses (4, 7, 10, 13); gentler growth after night 3 | "add 10 more days" + chose the recommended options |
| Oct 13 | Glass HUD for the in-game HUD only (menus keep wood); no stamina; light lighting pass | chose the recommended options |
| Oct 13 | Round bag icon, slim fuel bar, smaller phone side panels | from the owner's phone screenshot |

---

## 7. Scripts map

- **`ReplicatedStorage.Shared`** (ModuleScripts):
  - Config, Items (the single catalog: prices, `shellValue`, cosmetics with `beamColor`), Weapons, Ammo;
  - Upgrades (with `EVOLUTIONS`), Creatures (incl. `SandSkitter`, `BIG_POOL`), Forecasts;
  - Ground, SoundFx.
- **`ServerScriptService.Server`:**
  - **Main:** remotes, joinCrew / chooseRoute, refuel feed, coach events, auto-equip of weapons.
  - **GameState:** phase loop, nights, boss scheduling, growth, swarm, Pearls payout, lighting tables, dawn loot.
  - **Services:** IslandBuilder, LobbyBuilder, LampService (beam, keeper, lamp shift, beam colour), TowerService, CreatureService, DefenseService (cannons), LootService (`keepFor`, `count`, tide), UpgradeService (bench, evolutions, `START_SHELLS`).
  - **Player-facing:** PlayerData (DataStore `LighthouseKeepers_PlayerData_v1`, key `player_<UserId>`; sets `RunsCompleted` and `ProfileState`), ShopService, LoadoutService, EventLog.
- **`StarterPlayer.StarterPlayerScripts.Client`:**
  - **UI system:** **UiKit** (design system, about 107k chars), **UiSkin** (pirate skin), ItemPreview, UiStyleSheet (Studio-only style guide, F7).
  - **Gameplay:** Main (camera, beam aim, F/Q, attack), **Hud** (glass HUD, about 1,900 lines), Gear, Storm (rain, thunder, hum; 35% rain on touch).
  - **Screens:** Coach, Menus, Shop, Inventory (+ round bag button), Bench, Trader, Vitals, Departure, Results.
- **Menus and Results** turn Roblox's hotbar back on only when the player attribute `OwnWeaponSlot` isn't set (the Hud sets it).

**Remotes (`ReplicatedStorage.Remotes`):**

| Area | Remotes |
|---|---|
| Lamp and combat | BeamControl, LampAction (`toggleMode` / `leave`), Attack |
| Feedback and loot | Notify, LootCollected, PlaySound |
| Bench | OpenUpgrades, BuyUpgrade(id, requestId), UpgradeResult |
| Crew and runs | SetReady, VoteRematch, RunResults, EnterLobby, Travel |
| Gear | GearData, GearAction(`sync`) |
| Quartermaster shop | ShopOpen(open, text), ShopRequest(requestId, `buy`, itemId, qty), ShopResult |
| Loadout | LoadoutRequest / LoadoutResult |
| Trader | TraderOpen, TraderRequest(requestId, `sellAll`), TraderResult |
| Launch features | CrewFeed, LampShift, CoachEvent, ForecastVote, ReportDevice |

**GameState attributes** (`ReplicatedStorage.GameState`):
- Phase, Night, TimeLeft, Reason, Cause;
- Fuel, MaxFuel, DarkSeconds, BeamMode, KeeperUserId;
- Integrity, MaxIntegrity, Shells, BigWarning;
- the Forecast* fields, Upgrade_* and Evo_*.

**Control bindings:**

| Action | Keyboard | Controller | Touch |
|---|---|---|---|
| Prompts | E | X | tap |
| Repair / build / grab oil / refuel | hold | hold | hold |
| Reload cannon | R | Y | hold |
| Focus / leave the lamp | F / Q | **none yet** | on-screen buttons |
| Aim the beam | mouse | **none yet** | drag |
| Strike | click | R2 | tap |
| Draw / stow weapon | 1 | D-pad down | weapon slot |
| Bag | B | D-pad up | bag button |

---

## 8. UI system facts

**UiKit v2.1 API:**
- **Building blocks:** Screen, Panel (kind housing / dialog / plain), Inset, Section, Scroll, Label, Button (primary / secondary / ghost / danger; sm / md / lg), IconButton, Tabs.
- **Items and currency:** ItemCard (returns `self` with `.frame`), Currency (`.frame`, `.set`), Tag, Badge, StateView, Tooltip.
- **Controls:** Slider, Toggle, SettingRow, KeyHint.
- **Dialogs and gauges:** Dialog, PurchaseDialog, Health / Fuel / Tower / Resource gauges.
- **Feedback:** Toast (the container's NoticeTop / NoticeWidth / NoticeLimit attributes), Pickup.
- **Modals and states:** Open / Close, pushModal / popModal (sets `MenuOpen` and hides touch controls), SetDisabled / SetBusy, Breakpoint (phone = W < 760 or H < 500).
- **Tokens:** `UiKit.Color` (C.*) and `UiKit.Font` (F.*).

**UiSkin:**
- `remap(Color, Fonts)` warms the tokens at load time.
- `install(UiKit)` wraps Panel, Button, IconButton and ItemCard, adding a 9-sliced ImageLabel "Skin" (ZIndex −5). Button text is mirrored into "SkinText".
- The atlas rects are in `UiSkin.Rects`. The source PNG is `LK_PirateSkin_atlas.png`.

**Glass HUD (`Client.Hud`, "GLASS HUD" section near the end):**
- `restyle` / `glassTree` map the wood-warmed tokens back to navy inside the HUD and strip wood art from HUD buttons.
- `glassLayout` and `slimLayout` run at the end of `applyLayout`, which re-runs on every screen-size change.

---

## 9. History (what happened, in order)

1. **Design phase:**
   - Game plan.
   - Design docs v2 → v4.2: beam modes, gear, aggro, cannons, big monsters, lobby, Pearls.
   - Playtest Guide v1/v2.
   - An old Rojo project, retired; Studio became the source of truth.
2. **Core build (to Oct 10):** everything in section 4's core gameplay, the lobby, the ship, the shop, the inventory, the Trader, big monsters, the event log.
3. **UI redesign, Stages 1–8 (Oct 10–12):**
   - **1:** UiKit v2.1.
   - **2:** production HUD.
   - **3:** Inventory.
   - **4:** Shop.
   - **5 / 5.1:** Bench + Trader + Vitals.
   - **6:** Departure.
   - **7:** Results.
   - **8:** Title, How to Play, Settings.
   - Stage 9 was replaced by the launch adaptation.
4. **Launch adaptation (Oct 12):** from the psychology coach's brief (R1–R16; plan in `LAUNCH_ADAPTATION_PLAN.md`).
   - **A:** telemetry.
   - **B:** phone lamp controls.
   - **C:** coach, crew feed, lamp shift.
   - **D:** first-voyage fast path.
   - **G:** R8 prices, R9 forecasts, R10 switch, R11 invites, R12 moment, R13 evolutions, R15 beam colours.
   - **Deferred:** R14 (specialties, Kraken, maps) and R16 (icon A/B; see `ICON_BRIEF.md`).
   - **Also:** the engine-controls fix, `PLAYTEST_KIT.md`, and a tester questionnaire Doc ("Lighthouse Keepers — Tester Checklist", a Claude Doc artifact).
5. **Owner playtest feedback (Oct 12):** mobile fixes, swarm, Shells +30%, dawn loot window, `START_SHELLS` 120.
6. **Pirate menu skin (Oct 12 night):** Kenney atlas, `UiSkin`.
7. **Published (Oct 13)** by the owner.
8. **13-night run (Oct 13):** with the Pearl and boss rules above.
9. **Owner's six feature requests added to the plan (Oct 13):** section 14c.
10. **Glass HUD + lighting (Oct 13),** then **HUD slimming** from the owner's real-phone screenshot.
11. **Store description written (Oct 13).**

---

## 10. Backups (`ServerStorage.Backups`, newest last)

1. `UI_before_redesign_2026-10-10`
2. `Stage2_before_HUD_2026-10-10`
3. `Stage3_before_Inventory_2026-10-11`
4. `Stage4_before_Shop_2026-10-11`
5. `Stage5_before_Bench_Trader_2026-10-11`
6. `Stage6_before_Departure_2026-10-11`
7. `Stage7_before_Results_2026-10-12`
8. `Stage8_before_Menus_2026-10-12`
9. `Launch_A_before_Telemetry_2026-10-12`
10. `Launch_B_before_Controls_2026-10-12`
11. `Launch_C_before_Coach_2026-10-12`
12. `Launch_D_before_FastPath_2026-10-12`
13. `Launch_G_before_Content_2026-10-12` (all 37 scripts)
14. `Mobile_before_fixes_2026-10-12`
15. `Swarm_before_2026-10-12`
16. `DawnLoot_before_2026-10-12`
17. `UISkin_before_2026-10-12` (whole client folder + Config)
18. `Nights13_before_2026-10-13` (Config, GameState, Hud)
19. `HudGlass_before_2026-10-13` (Hud, Coach, Main, UiKit, UiSkin, Gear, Storm, plus a Lighting folder with the old values as attributes)
20. `HudSlim_before_2026-10-13` (Hud, Inventory)

**Local `.rbxl` files (owner's PC):**
- `Documents\LighthouseKeepers_before_HUD_2026-10-10.rbxl`
- `Documents\LighthouseKeepers_before_Inventory_2026-10-11.rbxl`
- `Downloads\LighthouseKeepers_before_Menus_2026-10-12` (fix the extension to `.rbxl`)
- **Suggest a fresh local save** before the next big batch.

---

## 11. Testing status

**Verified in Studio (solo, scripted):**
- **Core loop:** beam, fuel, repair, harpoons, cannons + ammo, aggro, big monsters with warning and boss bar.
- **Harbor and runs:** lobby, travel, Results, rematch.
- **Shop and locker:** buying, equipping, saving.
- **Launch features:**
  - first-voyage route (new player → crew in 1.1 s);
  - the coach prompt chain;
  - the crew feed;
  - forecast vote;
  - evolutions;
  - beam colours.
- **Swarm night 1:** never empty; the tower held with an attentive Keeper.
- **13-night run:** night-1 spawn counts and "night 1 of 13" on the HUD and Results.
- **Glass HUD at PC and phone sizes** (simulator): day, night and "lamp out".
- **Server performance:** 60 Hz, 0.11 ms of work per frame, about 50 KB/s sent per player with the swarm. That's near the comfortable limit; the fix if needed is client-side creature movement.

**Owner-tested:** the dawn loot window ("it stays"); the HUD on a real phone, which led to the Oct 13 slimming.

**Not verified yet:**
- nights 2–13 (late difficulty), the boss nights 4/7/10/13, the 18-Pearl win payout;
- multiplayer: the lamp shift (needs 2+ players) and a **4-player load test**;
- weapon-slot tap and the bag position on a real phone, plus frame rate with the new bloom;
- the pirate skin on Bench, Trader, Locker, Results and Settings at phone size;
- a controller (there's no beam aim on controllers at all yet);
- the shop "grey screen" report (not reproduced; the owner's screenshot is pending);
- a real playtest with outside players (Prototype A).

---

## 12. Known issues and open questions

- **Shells pile up late in the run** (night bonus about 1,180 per full win). Bench upgrades may max out mid-run. Request #4 (island merchant) gives them a use.
- **Pearl payout vs prices** need watching after real runs, especially if the boss count rises (14c decision).
- **No controller beam aim** and no Focus/Leave binding (gameplay work; needs approval).
- **Settings are session-only;** saving them needs a save field.
- The Storm Harpoon trade-off text says "same damage per target as the starter", but its stats are 9 vs 8.
- `PLAYTEST_KIT.md` still says a run is about 10 min; it's about 27 min now.
- The icon brief says "avoid a cartoon pirate look". Revisit it, since the menus are now a pirate skin.
- Studio test runs now change the owner's **real** save, because the DataStore is live.
- Optional credit line "UI art: Kenney.nl" (CC0, not required).

---

## 13. Original goals and playtest plan (still valid)

**Goals:**
1. Prove the core is fun before adding more.
2. Every role matters; the Keeper isn't the only hero.
3. Players choose to sail again (rematch rate).
4. Works on PC, phone and controller.

**Prototype A playtests** (`PLAYTEST_KIT.md` + Playtest Guide v2):
- 3–5 sessions, 2–4 players each, at least 1 real phone, one session with no verbal help.
- Test A with the economy off, Test B with it on.
- Neutral questions only.
- Paste each run summary back here; report raw counts next to percentages, and keep the age groups (14+ and 8–13) separate.

**Pass thresholds:**
- ≥80% understand that the light must be fueled and protected;
- ≥70% use both beam modes on purpose;
- ≥60% accept or ask for a rematch;
- most can explain why they lost;
- phone players finish the essential actions without help.

**Tester access:**
- The game is now published.
- Children need Trusted Connections or Parental Controls.
- A Tester Checklist Doc exists.

---

## 14. Roadmap

### 14a. Phases (owner-approved Oct 11, updated)

| Phase | What | Status |
|---|---|---|
| A. UI redesign + launch adaptation | Stages 1–8, batches A–G, mobile fixes | ✅ done |
| B. Prototype A playtests | sessions with outside testers | ⏳ the game is published; real sessions are not yet run |
| C. Fix + Prototype B | fix the biggest problem; one hand-built shipwreck rescue event; move scripts to Git/Rojo | later |
| D. Content | the owner chose to build content now (14c), alongside playtests | **in progress** |
| E. Monetization | cosmetics for Robux first (beam colours, lamp housings, skins); convenience items only if also earnable | needs owner approval; nothing enabled |
| F. Closed alpha → public beta → full launch | each stage needs owner approval | later |

### 14b. Earlier planned ideas (from the "Survive The Swarm" comparison, Oct 12)
1. Upgrade evolutions — ✅ **built** (2 evolutions).
2. **Reward codes:** Pearls once per player, via a new save field `redeemedCodes`.
3. **Specialties (about 4):** Keeper, Engineer, Harpooner, Oiler. Earnable only.
4. **Shared crew unlocks:** needs new maps first.
5. **Final boss:** the Kraken.

**Not taken:** hundreds of simultaneous enemies (bad for phones, and off-identity).

### 14c. Owner's six requests (Oct 13) — NEXT WORK

Quoted as written; **planned, not built.**

| # | Owner request | Plan | Effort |
|---|---|---|---|
| 1 | "number of bosses is based on the number of players in the round… 3 bosses spawn at the same time if there is party of 3" | On a boss night, spawn one big monster per crew member (1–4), together, from different directions. Touches `GameState`, `CreatureService` and the HUD boss bars (already stack side by side on phones). | ~1 session |
| 2 | "after day 7 all rounds has bosses" | Boss nights become 4, 7, then **every night 8–13**. | with #1 |
| 3 | "add more weapons (like swords whirling around the character)" | **Orbiting Blades**: 2–4 blades circle the player and hit on touch, with no aiming (good on phones). Later: chain hook, net launcher, lantern bomb. | medium per weapon |
| 4 | "npc at the lighthouse isle that sells weapons, speed boosts and many more items with shells, these items get deleted once the rounds finishes" | A merchant on the lighthouse island (day only) selling run-only items for Shells: temporary weapons, speed boost, damage boost, heal, tower shield, oil bundle. Everything is wiped at run end. | medium |
| 5 | "add more sea monsters each monster has different attacking style, some of them magical and does different sounds with different loot" | About 5 new monsters: **Spitter Eel** (ranged), **Tide Witch** (teleports, summons skitters), **Puffer Mine** (explodes at the tower), **Ghost Lantern** (dims the beam), **Coral Shaman** (heals monsters). Each has its own sounds and loot table. | large (models) |
| 6 | "quartermaster has more perma items and weapons also gear and boosts like additional number of shells, speed boosts, damage boosts" | More permanent Pearl items: weapons, gear, and capped permanent boosts (e.g. +10% Shells, +5% speed, +5% damage), each with a few levels. Needs new save fields with defaults. | medium |

**Suggested order:**
1. #1 + #2;
2. #4;
3. #3 (Orbiting Blades sold at the merchant first);
4. #6;
5. #5 (one monster at a time).

Run a playtest after #1 + #2 and after #4.

**⚑ Owner decisions needed** (recommended answer first):
- **Boss health with several bosses:** full health, tune after a test (rec.), or scale down per extra boss.
- **Boss Pearl drops:** with bosses × crew on most nights, a 4-player win could add about 30–50 Pearls on top of 18. Rec.: keep boss Pearl drops on nights 4, 7 and 13 only, or one Pearl drop per boss night.
- **Permanent boosts:** small steps with a cap of about +15% (rec.), so veterans don't overpower new players in co-op.
- **Merchant:** make it the **Trader's new job** (one NPC buys loot and sells run items) (rec.), rather than a third stall.
- **Monster models:** free Creator Store models (licence checked; nothing purchased without approval), Studio AI mesh generation, or a modeler.
- **Performance:** 4 bosses plus the swarm on phones; `MAX_CREATURES` may need to count bosses as several creatures.

### 14d. Deferred (only if playtests ask for it)
- **Gameplay and content:** stamina / sprint (from the HUD mock-up), loot-collecting pet (earnable; modest range), player levels, rotating cosmetic stock.
- **Maps and places:** new maps (make `IslandBuilder` data-driven first), a separate lobby place, lobby forge.
- **Exploration events:** shipwreck diving, a traveling merchant.
- **Systems:** crafting, seasons, leaderboards.
- **Saved settings.**
- **Controller beam aim.**
- **Icon/thumbnail A/B** (`ICON_BRIEF.md`).
- **Island scenery upgrade** (the mock-up's richer world: trees, cliffs, village lights).

---

## 15. Next steps (in order)

1. **Ask the owner the ⚑ questions in 14c**, or proceed with the recommended defaults if they say so.
2. Back up (`ServerStorage.Backups.Bosses_before_<date>`), then build **#1 + #2** (bosses by crew size; a boss every night from 8). Test a boss night by temporarily setting `DEV_TEST_BIG_MONSTER`, then revert it.
3. Owner re-publishes and playtests. Paste the run summary from Output.
4. Build **#4**, the island merchant (likely the Trader's new job), then **#3** Orbiting Blades as its first item.
5. Build **#6** (permanent Quartermaster boosts; new save fields with defaults), then **#5** (new monsters, one at a time).
6. Keep updating this file and `IMPLEMENTATION_LOG.md` after every batch, and remind the owner to re-publish.
7. **Before going bigger:**
   - run a 4-player test (Studio Test → Clients: 4, or real players);
   - fix `PLAYTEST_KIT.md`'s run length;
   - consider moving scripts to Git/Rojo.

---

## 16. Files and assets

| File | What it is |
|---|---|
| `progress.md` | this handover |
| `IMPLEMENTATION_LOG.md` | detailed log of every batch since Oct 12 (what changed, what was verified) |
| `LAUNCH_ADAPTATION_PLAN.md` | R1–R16 mapping, batches, acceptance criteria, owner decisions, pricing |
| `PLAYTEST_KIT.md` | session checklist, observer sheet, Onboarding-line meaning, results template H1–H7, real-phone checklist |
| `ICON_BRIEF.md` | icon and thumbnail brief (R16) |
| `ROBLOX_GAME_DEVELOPER_REVISION_BRIEF.md` | the psychology coach's brief (owner's file) |
| `LK_PirateSkin_atlas.png` | the pirate skin atlas (uploaded as 127395313470932) |
| `stage8-src/Menus.lua`, `launch-src/Coach.lua` | old reference copies; Studio is newer |
| Claude Doc "Lighthouse Keepers — Tester Checklist" | tester questionnaire: https://claude.ai/code/artifact/cce5eba7-52b2-4460-8815-9341a0989f63 |
| Design docs (owner's) | Game Plan, Game Design v2–v4.2, Playtest Guide v1/v2 |
