# TASK-002 AUDITOR PACKAGE (combined plain-text version)

Read-only code audit of Lighthouse Keepers (place 132065051336560, place version 148). Static review only: nothing was run, and no code was changed, so there are no source diffs, screenshots or logs.

## TABLE OF CONTENTS
1. TASK-002/AUDITOR_REPORT.md
2. TASK-002/CHANGE_MANIFEST.md
3. TASK-002/TEST_EVIDENCE.md
4. TASK-002/AUDITOR_QUESTIONS.md
5. TASK-002/SECURITY_AUDIT.md
6. TASK-002/GAMEPLAY_AUDIT.md

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-002/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-002: Read-only code audit (security, save data, gameplay, economy)

- **Date:** 2026-10-14
- **Project / place:** Lighthouse Keepers - Staging, place **132065051336560**, universe 10769064643, place version 148.
- **Original owner request:** "Begin a read-only audit after confirming the correct project", covering onboarding, beam, fuel/repair, creatures, bosses, weapons, economy, Quartermaster/Trader, loadouts, DataStore and network security, performance, mobile HUD, co-op, the 13-night campaign, results/rematch, and runtime errors.
- **Objective:** find and classify problems before any change, using evidence, with severity.

## Method and what "verified" means here
- Two independent code reviews (security: 19 findings, `SECURITY_AUDIT.md`; gameplay/economy/performance: about 53 findings, `GAMEPLAY_AUDIT.md`) were run by sub-agents over the exported scripts in `src\` (the exact copy of place version 148 from TASK-001).
- **Nothing was executed.** No Play session, no multiplayer test, no phone test, no profiling. "VERIFIED" in the two reports means the code path was traced in source, not observed running. Nothing about runtime behaviour, frame rate, bandwidth or retention is claimed.
- Claude (coordinator) independently re-read the code behind five claims and **confirmed all five**: no-session-lock save (`PlayerData.luau:101-116`, `UpdateAsync` returns the local profile and ignores the stored one); dirty flag cleared after the yield (`:111-113`); Pearls paid to `readyPlayers()` at run end (`GameState.luau:503-524`; that a late joiner counts as Ready rests on the sub-agent's trace of `Main.server.luau:646-657`, not re-read); no payout on `Abandoned` (`:356, 391, 453, 508`); the boss-night loop that stops at `MAX_BIG_PER_RUN` (`:359-378`). The remaining findings are the sub-agents' reading and have not been independently re-checked.
- Docs (`progress.md`) were treated as claims. The code-vs-docs comparison is in `GAMEPLAY_AUDIT.md` section 12.

## Highest-priority findings (full detail, evidence and classification in the two reports)
| ID | Severity | Class | Summary |
|---|---|---|---|
| SEC-1 | High | VERIFIED BROKEN | No session locking; saves overwrite the stored value, so a fast rejoin or server hop can roll back Pearls/items. |
| SEC-2 | Medium | VERIFIED BROKEN | Purchase or Pearl payout made during an in-flight autosave can be marked saved and lost. |
| SEC-3 | Medium | VERIFIED BROKEN | Save on leave is attempted once; failure loses everything since the last autosave. |
| GP-23 / SEC-4 | High | VERIFIED BROKEN | A full 18 Pearls (13 nights + 5 win) is paid to anyone Ready at run end, including a player who joined on night 13 or is AFK. |
| GP-24 | High | VERIFIED BROKEN | Quitting, disconnecting or leaving the crew mid-run pays 0 Pearls and no run credit; an "Abandoned" run pays nobody. |
| SEC-6 | Medium | VERIFIED BROKEN | Client-reported character position is trusted for loot pickup, attack range and Trader/shop distance; boss Pearl drops can be teleport-stolen. |
| SEC-5 | Medium | SUSPECTED | No server cooldown on repair/oil/refuel prompts; prompt-spam exploits could make runs unlosable. |
| SEC-8 | Medium | VERIFIED BROKEN | `GearAction "sync"` is unthrottled and does expensive work per call. |
| GP-25 | Medium | VERIFIED BROKEN | The 1-4 crew limit is not enforced. |
| GP-21 | Medium | VERIFIED BROKEN | Shell income (floor 1,303; up to about 6,500-6,700 if all loot is collected and sold) far exceeds the sinks that exist (2,080), as `progress.md` already suspected. |
| GP-11/12/13/14 | High | PLANNED | Map of what the boss changes touch, plus a trap: nights are iterated downward and capped at `MAX_BIG_PER_RUN = 4`, so naively raising boss counts would drop nights 4 and 7. Four Brutes would hit the 100-HP tower for about 20 HP/s. |
| GP-43/44 | Medium | VERIFIED BROKEN | Two scripts fight over `TouchControlsEnabled`; a controller can take the lamp but cannot aim or leave. |
| GP-2, GP-3, GP-15, GP-19 | Medium | VERIFIED BROKEN | Fuel drain scales by all server players not the crew; Keeper is released after 25 s of holding still; a Fire Shell reload wipes cannon ammo; `BuyUpgrade` has no phase/proximity check. |
| GP-35, GP-37, GP-47 | Medium | UNTESTED | Lamp shift (2+ players), 4-player load at the 45-creature cap, phone HUD pixel zones. |
| GP-1 | Info | VERIFIED WORKING | The 10-second blackout rule matches its config. |

Working and well protected (traced): purchase pricing and double-spend protection, negative/fractional quantities, equip of unowned items, Keeper-only beam remotes (NaN-safe), forecast voting, coach whitelist, armor stats set server-side, per-player cleanup, run-to-run state resets.

## Economy numbers from code (no play data exists)
A 13-night win pays 18 Pearls; the full permanent shop costs 530 Pearls (about 29 wins). Per-night creature counts are tabulated in `GAMEPLAY_AUDIT.md` section 13. These are arithmetic, not retention evidence.

## Architecture, gameplay, save-data, performance implications
- No change was made. The save-data and Pearl-payout findings are the only ones that put saved progress at risk; any fix needs owner approval (rewards, persistence).
- Performance: server cost per frame and bandwidth were not measured; code-read risks (per-frame beam raycasts, loot-orb animation, per-call updates) are SUSPECTED.

## Known limitations
No runtime evidence. No multiplayer, mobile, controller or long-session test. Sub-agent findings beyond the five re-checked are single-reader conclusions.

## Outstanding problems
All findings above. Nothing was fixed.

## Ready for acceptance?
Yes as a read-only audit. It is not a clean bill of health for the live game: the Pearl payout and save-integrity issues are present in the published build described by `progress.md`.

## Recommended next step (needs owner decision, see AUDITOR_QUESTIONS.md)
A small, approved "integrity batch" before any feature work: session-safe saving, the dirty-flag/leave-save fixes, Pearl eligibility, and the crew cap. Then a measured 4-player and phone test. Boss and merchant features follow after the economy direction is decided.
=== END FILE ===

=== FILE: TASK-002/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-002

**No game script, Studio instance, Config value, price, save or published content was changed.** No new remotes, modules or in-game instances. No persistent data or economy value changed. Owner approval: not required (read-only).

Files created on disk (all under `C:\RobloxProjects\LighthouseKeepers\docs\audits\TASK-002\`):

| File | Purpose |
|---|---|
| `AUDITOR_REPORT.md` | Summary, method, top findings |
| `SECURITY_AUDIT.md` | Full security and DataStore review (SEC-1 to SEC-19), with file:line evidence |
| `GAMEPLAY_AUDIT.md` | Full gameplay, economy, performance, mobile review (GP-1 to GP-52 plus GP-16b), doc-vs-code table, reference arithmetic |
| `TEST_EVIDENCE.md`, `AUDITOR_QUESTIONS.md` | Required package files |

Source diffs: none. Line references in the audits point into `C:\RobloxProjects\LighthouseKeepers\src\` (TASK-001 export, place version 148).
=== END FILE ===

=== FILE: TASK-002/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-002

**Tests performed: none that execute the game.** This task is static code review.

- Environment: exported Luau source on disk (`src\`, place version 148). No Studio Play session, no clients, no players, no device or emulator.
- Studio use: none during this task (all reading was from disk). Could anything here have changed production DataStore values? **No.**
- Evidence type: file:line references and arithmetic from code constants (Config, Items, GameState formulas). Console output: none. Screenshots/performance measurements: none.
- Independent re-checks by the coordinator: five code paths re-read and confirmed (listed in `AUDITOR_REPORT.md`).
- Classification meaning in this package: VERIFIED = traced in source; it is not a runtime observation. UNTESTED = needs a run.

**Tests not performed (needed before trusting any of the runtime areas):**
1. Nights 2-13 and boss nights 4/7/10/13 in a full run.
2. Multiplayer (lamp shift, mid-run join/leave, 4 players at the 45-creature cap), with server frame time and bandwidth measured.
3. A real phone (HUD zones, weapon slot, bag button, frame rate with bloom).
4. A controller (aim and leave bindings).
5. Rejoin and server-hop rollback (SEC-1) and the save-during-autosave race (SEC-2), which must not be tried against the live DataStore.

**Remaining regression risk:** none from this task (no change).
=== END FILE ===

=== FILE: TASK-002/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-002

1. **Save integrity (SEC-1/2/3, GP-26).** Is a hand-written session lock plus retry/dirty-flag fix preferable to adopting an established profile library (ProfileStore)? A library changes how saves are loaded and stored; the existing key `player_<UserId>` and v1 schema must keep loading. What migration safety would you require?
2. **Pearl eligibility (GP-23/24, SEC-4).** Fair rule options: pay only players present for a minimum share of the nights, or pay per night survived while present (so a mid-run leaver keeps what they earned). Which do you recommend, and should AFK detection exist? This changes rewards and needs owner approval.
3. **Crew cap and fuel scaling (GP-25, GP-2).** Hard-cap at 4 in the join path, and scale fuel by crew rather than by everyone on the server. Any hidden coupling you would check first?
4. **Position trust (SEC-6).** Is a server-side movement-speed sanity check plus crew-only loot gating enough, or should pickup range be checked against the server's own character position only?
5. **Boss redesign (GP-11 to GP-14).** Four simultaneous Brutes outdamage the tower. Which levers do you prefer (boss health per extra boss, tower durability, staggered spawns, damage cap)? The balance numbers are owner decisions.
6. **Economy (GP-21/22).** Shell income exceeds sinks several times over, and Pearls take about 29 wins to clear the shop. Should the merchant be sized from the Shell surplus before building it?
7. **Measurement plan.** What minimum 4-player and phone measurements would you accept as evidence for GP-37/GP-47, given Studio cannot show real phone frame rate?

No concern has been invented to fill this list; items 1, 2 and 5 are the real forks.
=== END FILE ===

=== FILE: TASK-002/SECURITY_AUDIT.md ===
# Lighthouse Keepers: Security Audit (read-only code review)

- **Scope:** `src\ServerScriptService\Server\*.luau` (all 14 server modules), `src\ReplicatedStorage\Shared\{Config,Items,Weapons,Upgrades}.luau`, and a skim of `src\StarterPlayer\StarterPlayerScripts\Client\*` for what clients send (every `FireServer` call). `src\ServerStorage` (old backups) was ignored. Nothing in it is `require`d by live server code.
- **Source:** an exported copy of place version 148.
- **Method:** static reading only. Nothing was executed, and no Studio or MCP tools were used.
- **Classifications:**
  - **VERIFIED BROKEN / VERIFIED WORKING:** the code path was traced end to end in the source. This is not a runtime result.
  - **SUSPECTED:** the issue depends on engine behaviour or timing that can't be confirmed from the source.
  - **UNTESTED:** the path is switched off by config.
  - **PLANNED:** a known future risk.
- **Date:** 2026-10-14

## Remote inventory (server-side handlers)

| Remote | Handler | Type checks | Rate limit / dedupe | Phase / ownership gate |
|---|---|---|---|---|
| SetReady (x2) | Main.server.luau:87, :639 | boolean only | none needed | none (false = back to ship) |
| VoteRematch | Main:102 | n/a | n/a | Ready |
| ReportDevice | Main:110 | whitelist | none (log only) | none |
| BuyUpgrade | Main:116 | id string, requestId <=40 | 0.3 s per player | **none** (SEC-9) |
| Attack | Main:498 | Vector3, NaN | per-weapon cooldown | not Keeper, alive, server-chosen weapon |
| CoachEvent | Main:603 | whitelist | 60 per session | none (log only) |
| ForecastVote | Main:619 | must equal offered ids | n/a | Ready + Waiting/Intermission |
| EnterLobby | Main:631 | n/a | idempotent | none |
| TraderRequest | Main:800 | requestId, action whitelist | 0.3 s + last-id memo | Ready + distance (client position) |
| GearAction | PlayerData.luau:310 | "sync" only | **none** (SEC-8) | none |
| ShopRequest | ShopService.luau:181 | requestId, itemId, qty | 0.2 s + 40-id memo | shop open + distance |
| LoadoutRequest | LoadoutService.luau:63 | requestId, itemId | 0.2 s + unbounded memo (SEC-13) | ownership + slot |
| BeamControl | LampService.luau:319 | number, NaN, inf | none (cheap) | Keeper only |
| LampAction | LampService:332 | action whitelist | none (cheap) | Keeper only |
| LampShift | LampService:411 | id match, boolean | n/a | pending offer, Day, named party |

Server-to-client only (no server handler): Notify, LootCollected, PlaySound, OpenUpgrades, UpgradeResult, RunResults, GearData, ShopOpen, ShopResult, LoadoutResult, Travel, TraderOpen, TraderResult, CrewFeed. ProximityPrompt handlers (oil, fuel, repair, console, helm, shop, trader, cannon pads) are covered where relevant.

---

## Findings

### SEC-1: No session locking; saves overwrite blindly (cross-server or rejoin rollback)
- **Classification:** VERIFIED BROKEN (code path). The race itself is timing-dependent.
- **Severity:** High
- **Evidence:**
  - `PlayerData.luau:107-109`: `store:UpdateAsync(keyFor(player), function() return profile end)`. The transform ignores the stored value. It works exactly like `SetAsync`, with no version or lock check.
  - `PlayerData.luau:121-124`: a plain `store:GetAsync(keyFor(player))` on join. No lock is claimed and no "still owned by another server" check is made.
- **Failure scenario:**
  1. A player leaves server A, and A's leave save (`PlayerData.luau:323-327`) is slow or queued.
  2. The player joins server B (or rejoins A as a new Player object) before that save lands.
  3. B loads the stale profile. A's save then lands. B later autosaves or leave-saves its stale-plus-new copy over it.
  4. Pearls earned and items bought in the last session are silently rolled back.
  
  The same happens if two servers hold the same profile at once, for example a stale server still running its autosave loop. There is no trading, so this is a data-loss risk and not a dupe path today. It becomes a dupe path the moment any transferable value (trading, gifting) is added.
- **Fix:**
  - Add a session lock to the stored record: owner `game.JobId` plus a timestamp. Load with `UpdateAsync` that claims the lock, or waits and retries if another live server holds it and the lock is fresh.
  - Save only if this server still owns the lock, and release the lock on leave.
  - Alternatively, adopt ProfileStore/ProfileService, which implements this.
  - At minimum, store a monotonically increasing `saveVersion` and refuse to write a lower version over a higher one.

### SEC-2: The dirty flag is cleared after the save yields, so changes made during a save are lost
- **Classification:** VERIFIED BROKEN
- **Severity:** Medium
- **Evidence:**
  - `PlayerData.luau:103`: `if not profile or not storeAvailable or not dirty[player] then return end`
  - `PlayerData.luau:111-113`: `if ok then dirty[player] = nil`. This runs after `UpdateAsync` has yielded.
  - `PlayerData.luau:96-99`: `markChanged` sets `dirty[player] = true` at any time, including during that yield.
- **Failure scenario:**
  1. The 60-second autosave (`:339-348`) is in flight for a player.
  2. During the yield, the player buys an item (ShopService), or the run ends and `addPearls`/`recordRun` fire (GameState.luau:520-521).
  3. The in-flight save returns OK and clears `dirty`.
  4. If `UpdateAsync` serialized the profile before that mutation, the change is never written. The next autosave and the leave save both return early at line 103 because `dirty` is nil.
  5. If the player leaves before any further change, their Pearls or purchase revert on next join.
- **Fix:** Clear `dirty[player]` before calling `UpdateAsync`, and set it back to true on failure. Alternatively, use a per-player change counter and clear `dirty` only if the counter hasn't changed since the save started.

### SEC-3: The leave save has no retry; a single failure discards the session's changes
- **Classification:** VERIFIED BROKEN
- **Severity:** Medium
- **Evidence:**
  - `PlayerData.luau:323-331`: `save(player)`, then unconditionally `profiles[player] = nil; dirty[player] = nil`.
  - `save` (`:106-115`) only `warn`s on failure.
- **Failure scenario:** A DataStore outage or throttle at the moment a player leaves loses everything since the last successful autosave. That can be up to 60 seconds, or a whole run's Pearl payout if the payout landed in that window.
- **Notes:**
  - On shutdown, `PlayerRemoving` and `BindToClose` (`:332-338`) can both write the same key within seconds. This is harmless but can trigger "request queued" throttle warnings, because each key allows one write per 6 seconds.
  - `BindToClose` saves sequentially. That is fine for 4 players, but it should run in parallel and wait on all saves.
- **Fix:**
  - Retry the leave save 2-3 times with backoff before dropping the profile.
  - In `BindToClose`, spawn the saves in parallel and wait for all of them (with a time cap of about 25 seconds).
  - Skip the `BindToClose` save for players whose `PlayerRemoving` save is already in flight.

### SEC-4: Pearl payout ignores participation, so late joiners and AFK players get full rewards
- **Classification:** VERIFIED BROKEN
- **Severity:** Medium
- **Evidence:**
  - `GameState.luau:503`: `local voters = readyPlayers()` is read at run end.
  - `GameState.luau:509-521`: every voter gets `PEARLS_PER_NIGHT * survived (+ PEARLS_VICTORY_BONUS)`, where `survived` is the run's night count, not the player's.
  - `Main.server.luau:646-656`: `joinCrew` mid-run sets `Ready = true` and rows the player to the island.
  - `Main.server.luau:660-672`: the helm prompt allows joining at any phase once `InLobby` is set. Any client can set `InLobby` with `EnterLobby` (`:631-636`).
- **Failure scenario:**
  - A player idles on the ship and uses the wheel during Night 13. They receive the full 18 Pearls (13 + 5 Victory bonus, Config.luau:17-19) for about 90 seconds of play.
  - A Ready player can also stand AFK for the whole run and get the same payout as the crew carrying them.
  - This gives roughly 10x Pearl farming per hour for alts or late joiners.
- **Fix:**
  - Record per player the night they joined, or the run time they were present, and pay only for nights they were Ready and on the island at nightfall.
  - Optionally require a minimal contribution, from EventLog.perPlayer or recent input, for the Victory bonus.
  - Optionally block or zero-reward joins after a cutoff night.

### SEC-5: Repair and refuel prompts have no server-side cooldown, so prompt-firing exploits make runs unloseable
- **Classification:** SUSPECTED. This depends on the engine not enforcing `HoldDuration` server-side. Exploit executors commonly fire prompts instantly.
- **Severity:** Medium
- **Evidence:**
  - `TowerService.luau:26-32`: `repairPrompt.Triggered:Connect(function(player) ... TowerService.repair(Config.REPAIR_AMOUNT * ...)`. There is no per-player timer, and no Ready or phase check. The intended cost is only the prompt hold: `IslandBuilder.luau:253` with `REPAIR_HOLD_SECONDS = 1.5`.
  - `Main.server.luau:204-214` (grab oil) and `:216-231` (refuel +40): there is no cooldown beyond the 0.5 s prompt hold (`IslandBuilder.luau:248, 287`).
- **Failure scenario:**
  1. An exploiter fires the repair prompt dozens of times per second and keeps the tower at max.
  2. Alternating oil and fuel prompts keeps the lamp full, if the two prompts are both in range or the exploiter teleports between them.
  3. The run cannot be lost, so every run is a Victory paying 18 Pearls (SEC-4), plus boss Pearl drops.
- **Fix:**
  - Enforce a per-player server cooldown of at least `REPAIR_HOLD_SECONDS` on repairs, and at least 0.5 s on oil and fuel.
  - Optionally track `PromptButtonHoldBegan` server-side and require the full hold to have elapsed.
  - Require `Ready` and a run phase for repairs and refuels.

### SEC-6: Client-owned character position is trusted for loot pickup, attack origin, and range checks
- **Classification:** VERIFIED BROKEN. The server reads `HumanoidRootPart.Position`, which the owning client controls, and there is no anti-teleport or speed check anywhere in the server code.
- **Severity:** Medium
- **Evidence:**
  - `LootService.luau:231-259`: any living player's `root.Position` within `LOOT_PICKUP_RADIUS` collects. There is no `Ready`, phase, or movement check.
  - `LootService.luau:153-159`: boss `Pearls` go straight to the collector's saved Pearls.
  - `Main.server.luau:528-531`: attack range is clamped relative to `root.Position`.
  - `Main.server.luau:820`: Trader range check.
  - `ShopService.luau:35-42`: shop range check.
  - `LampService.luau:350-359`: the Keeper is never required to stay at the console.
- **Failure scenario:**
  - An exploiter teleports onto every loot orb, including boss Pearl piles (2-4 Pearls, 50% chance, up to 4 bosses per run, Config.luau:21-23 and :133). This takes rare loot and Pearls from the crew.
  - A non-crew player on the ship can do the same, because pickup isn't gated on `Ready`.
  - Weapon range limits are meaningless because the origin follows the teleported character. Damage per second is still capped by the server cooldown.
- **Fix:**
  - Gate loot pickup on `Ready` and a run phase.
  - Add a lightweight server-side movement sanity check: track last positions per Heartbeat, and flag or rubber-band implausible deltas outside sanctioned `PivotTo` teleports (`Main.server.luau:263, 581`).
  - Optionally split boss Pearls among the crew instead of giving them to the first collector.

### SEC-7: Run-scoped loot survives leaving mid-run and can be sold in a later session
- **Classification:** VERIFIED BROKEN
- **Severity:** Low
- **Evidence:**
  - Loot is stored in the saved `profile.counts` (`LootService.luau:164`, `PlayerData.addItem`).
  - It is cleared only by `clearRunLoot` at `resetRound` (`Main.server.luau:839-841`) and at run end (`GameState.luau:526-528`), and only for players in the server.
  - A player who leaves mid-run is saved with their loot (`PlayerData.luau:323-327`). `load` (`:118-150`) never clears run-scoped items.
- **Failure scenario:** A player collects a Black Pearl (130 shells), leaves, joins another server mid-voyage, joins the crew, and sells it at the Trader (`Main.server.luau:741-763`). This injects shells into a run that didn't earn them. The impact is bounded: shells are run-only, and no Pearls are involved.
- **Fix:** Call the equivalent of `clearRunLoot` inside `load` or `reconcile`. Alternatively, keep run loot out of the saved profile entirely, in a server-memory table.

### SEC-8: GearAction "sync" is unthrottled and does expensive work per call
- **Classification:** VERIFIED BROKEN (no limit exists)
- **Severity:** Medium (server performance and bandwidth abuse)
- **Evidence:**
  - `PlayerData.luau:310-316`: `if action == "sync" then push(player) end`, with no rate limit.
  - `push` (`:86-94`) does a JSON encode and decode of the profile, a `GearData:FireClient`, and `onChanged` → `syncGear` (`Main.server.luau:383-437`). `syncGear` walks the backpack and character and rewrites `MaxHealth`, `Health`, and attributes.
- **Failure scenario:** An exploiter fires `GearAction("sync")` in a tight loop. This burns server CPU and outbound bandwidth for all players, which hurts the 1-4 player server's frame time.
- **Side note (SUSPECTED, Low):** `syncGear` sets `humanoid.Health = math.max(1, ...)` (`Main.server.luau:429`) even when Health is 0. On a dead humanoid this should not revive (the state stays Dead), but it is untidy.
- **Fix:**
  - Rate-limit `sync`, for example 1 per second per player, coalescing extras.
  - Have `push` call `onChanged` only when the profile actually changed, not on a display resync.
  - Skip the Health write when `humanoid.Health <= 0`.

### SEC-9: BuyUpgrade has no crew, phase, or proximity gate
- **Classification:** VERIFIED BROKEN
- **Severity:** Low (griefing)
- **Evidence:**
  - `Main.server.luau:116-146` checks only `typeof(id)`, `requestId`, and a 0.3 s throttle before `UpgradeService.buy(id)`.
  - The bench prompt (`:69-71`) is never required.
  - The handler stays active when `Config.ECONOMY_ENABLED` is false and the bench has been destroyed (`:74-82`).
- **Failure scenario:** A non-crew player on the title screen or ship, or any crew member from anywhere on the map, spends the crew's shared shell pool on upgrades the crew didn't choose. It still buys real upgrades, so this is griefing and not value creation.
- **Related (Info):** `UpgradeService.buy("ORDER")` or `buy("EVOLUTIONS")` resolves to a non-upgrade table. `#upgrade.costs` then errors (`UpgradeService.luau:109-114`), which throws in the handler. This only causes noisy errors and changes no state.
- **Fix:**
  - Require `Ready`, a run phase, and proximity to the bench. Optionally require that the bench was opened recently via the prompt, the same pattern as ShopService's `openFor`.
  - Validate `id` against `Upgrades.ORDER`.
  - Don't connect the handler when the economy is off.

### SEC-10: A transient DataStore failure at boot disables saving for the whole server
- **Classification:** VERIFIED BROKEN
- **Severity:** Low
- **Evidence:**
  - `PlayerData.luau:290-308`: a single `GetAsync("__access_check")`. On error, `storeAvailable` stays false for the server's lifetime, with no retry.
  - `:138-140`: every player then gets `newProfile()`.
  - `Main.server.luau:686-689`: `ProfileState == "memory"` with `RunsCompleted == 0` qualifies for the first-voyage fast path.
- **Failure scenario:**
  - A DataStore hiccup in the first second of a live server means every player there sees 0 Pearls and no owned gear, and earns nothing persistent.
  - Veterans get the new-player fast path.
  - No good save is overwritten, because `save` is gated on `storeAvailable`, so the design does fail safe.
- **Fix:**
  - Retry the access check with backoff, or drop it and rely on per-player load retries.
  - Treat a DataStore failure on a live server (`not RunService:IsStudio()`) as `"failed"` and not `"memory"`, so the "never treat as new" rule applies.

### SEC-11: Corrupt or partial saves aren't handled defensively
- **Classification:** SUSPECTED. The current code never writes a malformed record, so this needs external corruption or a future schema change.
- **Severity:** Low
- **Evidence:**
  - `PlayerData.luau:126`: `profile = if result then reconcile(result) else newProfile()`.
  - `reconcile` (`:53-75`) assumes a table. A non-table value errors at `profile[key] = value`, killing the load thread. The player then never gets a profile, and every request answers "still loading".
  - `reconcile` is shallow. A saved `stats` table missing `bestNight` would make `recordRun` (`:218`) error on `math.max(nil, ...)`.
- **Fix:**
  - Check `type(result) == "table"`. Otherwise mark the profile `doNotSave` and log it.
  - Reconcile nested tables (`stats`, `owned`, `counts`) key by key.
  - Sanitize `pearls` (number, finite, >= 0, integer) and the counts.

### SEC-12: The schema version is written but never read; there is no migration path
- **Classification:** VERIFIED BROKEN (absent feature)
- **Severity:** Info
- **Evidence:** `PlayerData.luau:21` `SCHEMA_VERSION = 1` and `:35` `version = SCHEMA_VERSION`. Nothing compares `profile.version` on load. `reconcile` only adds missing top-level keys.
- **Failure scenario:** A future change to a field's meaning, for example a re-priced currency or a renamed item id, has no hook to migrate old saves. Renamed item ids would linger in `owned` and `counts`.
- **Fix:** Add a `migrate(profile)` step keyed on `profile.version`. Bump `SCHEMA_VERSION` on each breaking change, and drop unknown item ids during reconcile.

### SEC-13: LoadoutService request memo grows without bound
- **Classification:** VERIFIED BROKEN
- **Severity:** Low (memory growth)
- **Evidence:** `LoadoutService.luau:21` declares `handled = {}`, and `:80-84` adds `memory[requestId] = { ok, message }` with no cap. ShopService caps the same structure at 40 (`ShopService.luau:161-172`).
- **Failure scenario:** A client sending a fresh requestId every 0.2 s grows one table per player for the whole session. That is roughly 18k entries per hour, cleared only on leave. Small but unbounded.
- **Fix:** Reuse ShopService's capped `remember` (last 40 ids).

### SEC-14: Anyone can hold the lamp, and a griefer can hold it indefinitely
- **Classification:** VERIFIED BROKEN
- **Severity:** Low
- **Evidence:**
  - `LampService.luau:350-359`: the console prompt has no `Ready` or phase check.
  - `:319-329`: any `BeamControl` from the Keeper resets `lastKeeperInput`, so idle release (`:248`) never fires while a script keeps sending angles.
  - There is no position check, so the Keeper may teleport away (SEC-6).
  - Other players have no way to take the lamp back.
- **Failure scenario:** A public-server griefer, crew or not, takes the lamp at night, points it away from the creatures, and keeps it alive with scripted `BeamControl` calls. The run is lost.
- **Fix:**
  - Require `Ready` and a run phase to take the lamp.
  - Release the Keeper if they move more than N studs from the console.
  - Consider a crew vote or kick, or require meaningful angle changes for idle detection.

### SEC-15: An Attack with an infinite Vector3 produces a NaN target
- **Classification:** VERIFIED BROKEN
- **Severity:** Low / Info
- **Evidence:** `Main.server.luau:500` rejects NaN (`target.X ~= target.X`) but not ±inf. With inf, `offset.Magnitude > weapon.range`, so `target = root.Position + offset.Unit * weapon.range` (`:530`), and `offset.Unit` of an inf vector is NaN.
- **Failure scenario:** `damageArea` with a NaN position hits nothing, because comparisons are false. `showProjectile` then creates a part with a NaN `CFrame.lookAt` (`:471-475`). This is harmless but wastes the cooldown slot and spawns junk parts.
- **Fix:** Also reject `math.abs(component) == math.huge`, as BeamControl already does (`LampService.luau:324`).

### SEC-16: Boss Pearls are lost if collected before the profile loads
- **Classification:** VERIFIED BROKEN
- **Severity:** Info
- **Evidence:**
  - `LootService.luau:155`: `playerData.addPearls(player, drop.value, "boss drop")`.
  - `PlayerData.luau:172-174` returns silently when `profiles[player]` is nil. The orb is still removed (`LootService.luau:159`).
  - The same applies to loot items via `addItem`.
- **Fix:** Skip collection, leaving the orb on the ground, for players without a loaded profile. This combines naturally with the `Ready` gate in SEC-6.

### SEC-17: Awards are a latent Pearl source built on spoofable counters
- **Classification:** PLANNED (latent; inactive at current config)
- **Severity:** Info
- **Evidence:**
  - `GameState.luau:515-519` adds `PEARLS_PER_AWARD` for each award.
  - `Config.luau:20` sets `PEARLS_PER_AWARD = 0`.
  - Awards (`EventLog.luau:324-346`) come from kills, keeper seconds, refuels and cannon reloads, repairs, and shells collected. These are the counters that SEC-5, SEC-6, and SEC-14 let an exploiter inflate.
- **Fix:** Keep the value at 0 until SEC-5, SEC-6, and SEC-14 are fixed, or cap award Pearls per run.

### SEC-18: The auto-sell path is off by config
- **Classification:** UNTESTED
- **Severity:** Info
- **Evidence:** `Main.server.luau:777-786` with `Config.AUTO_SELL_LOOT = false` (`Config.luau:80`).
- **Notes:** It reuses `sellAllLoot`, which is server-valued, clears before paying, and doesn't yield, so it looks safe. It applies to any `Ready` player regardless of location, which is intended. Re-audit when it is enabled.

### SEC-19: Legacy client code sends unused GearAction actions, and ShopService has dead sell code
- **Classification:** VERIFIED WORKING (the server ignores them)
- **Severity:** Info
- **Evidence:**
  - `Gear.client.luau:174` sends `gearActionRemote:FireServer(action.action, itemId, action.amount)`, but the server only handles `"sync"` (`PlayerData.luau:313`).
  - `ShopService.sell` (`:112-130`) is unreachable, because `process` returns early for `"sell"` (`:155-156`).
- **Fix:** Remove the dead paths so a future edit doesn't revive them without review.

---

## What looks well protected (VERIFIED WORKING, traced in source)

- **Shop pricing and validation** (`ShopService.luau:69-159`):
  - Price and cost come from the server's `Items` table.
  - `quantity` is type-checked, NaN-checked, floored, and range-checked (`1..999` or `-1`), so infinities and fractions are rejected.
  - Weapons, armor, and cosmetics are forced to quantity 1 and blocked if already owned.
  - Stack capacity is enforced, and catalog meta keys (`SHOP_ORDER`, `EXPENSIVE_PRICE`) are rejected via the `.kind` check.
  - The shop must have been opened through the server prompt (`openFor`), and the player must be within range.
- **No double-spend:**
  - `spendPearls` checks and deducts with no yield in between (`PlayerData.luau:230-238`). `buy` only adds the item after a successful spend.
  - RequestId memo plus a 0.2 s throttle stop double taps and retries (`ShopService.luau:186-207`).
  - Throttled replies aren't memoized, so a legitimate retry still works.
- **Equip validation** (`LoadoutService.luau:23-57`): the item must exist, have a `slot`, and be owned. The starter can't be unequipped, and the slot comes from the catalog, not the client. `reconcile` also resets unowned equipped ids on load (`PlayerData.luau:65-73`).
- **Weapon authority** (`Main.server.luau:513-533`):
  - The weapon is read from the server-created Tool's `WeaponId` attribute, which clients can't change replicated.
  - Damage, radius, max targets, and cooldown come from `Weapons`. Only a position is accepted from the client, and it is range-clamped.
  - The Keeper can't attack, and dead players can't attack.
- **Trader** (`Main.server.luau:741-830`):
  - Value is computed server-side from `Items.shellValue`.
  - Loot is cleared before shells are added, with no yield.
  - Same-id replays return the memoized result, and there is a 0.3 s throttle and a `Ready` check.
- **Failed-load safety** (`PlayerData.luau:118-148`):
  - An error and a nil value from `GetAsync` are distinguished.
  - Load is retried 3 times. On total failure the profile is flagged `doNotSave` and is never written, so a good save is never overwritten with defaults.
  - `RunsCompleted = -1` and `ProfileState = "failed"` keep the player off the new-player path.
  - There is an autosave every 60 s and a `BindToClose` save.
  - There is no `SetAsync` or `RemoveAsync` anywhere in live code.
- **Run results:** computed entirely server-side (`EventLog.endRun`, `GameState.luau:489-533`). No client input feeds `RunResults`, and Pearls are paid server-side.
- **Smaller remotes:**
  - `BeamControl` and `LampAction` are Keeper-only, and BeamControl rejects NaN and inf.
  - Turn speed is server-limited (`LampService.luau:258-262`).
  - `LampShift` acts only for the named party of a pending offer during Day.
  - `ForecastVote` accepts only the two offered ids, from crew, pre-voyage.
  - `ReportDevice` and `CoachEvent` use whitelists, and CoachEvent has a 60-event budget.
- **Armor stats:** `DamageReduction` and `MaxHealth` are set server-side from the catalog. Client attribute writes don't replicate.
- **Per-player cleanup:** `lastAttack`, `lastBuy`, `coachBudget`, `traderHandled`, `lastTrade`, the ShopService tables, the LoadoutService throttle, and `profiles`/`dirty` are all cleared on `PlayerRemoving`.
  - Remaining minor retention: the `LampService.heldThisRun` Player keys are cleared only at the next run reset (`LampService.luau:237`).
  - `EventLog.devices` and `routes` are keyed by UserId and never cleared. They are bounded by unique visitors per server.
  - The unused `lastAction` table is at `PlayerData.luau:317`.

## Priority order

1. **SEC-1, SEC-2, SEC-3:** data integrity. Adopt session locking (or ProfileStore), fix the dirty-flag race, and add retries.
2. **SEC-4, SEC-5:** Pearl farming via late join or AFK, and via repair/refuel spam.
3. **SEC-6, SEC-8:** gate loot on the crew and add a movement sanity check; throttle `sync`.
4. **SEC-7, SEC-9, SEC-10, SEC-14:** smaller fixes.
5. **Info items** as convenient.
=== END FILE ===

=== FILE: TASK-002/GAMEPLAY_AUDIT.md ===
# Lighthouse Keepers - Gameplay / Game-Systems Audit (read-only code review)

Scope: exported Luau of the live place (version 148): `src\ServerScriptService\Server\*.luau`, `src\ReplicatedStorage\Shared\*.luau`, `src\StarterPlayer\StarterPlayerScripts\Client\*.luau`. `src\ServerStorage` ignored. Docs (`docs\progress.md`, `docs\IMPLEMENTATION_LOG.md`) were treated as claims and checked against code.

**Method and limits.** Nothing was executed. "VERIFIED" = traced end-to-end in source. Every number below is arithmetic on constants in the code (arithmetic shown); no runtime result or performance number is claimed. Line numbers refer to the exported files as read.

Classification key: VERIFIED WORKING / VERIFIED BROKEN / SUSPECTED / UNTESTED / PLANNED. Severity: Critical / High / Medium / Low / Info.

Short file names: `GS` = Server\GameState.luau, `CS` = CreatureService, `LS` = LampService, `TS` = TowerService, `DS` = DefenseService, `LO` = LootService, `US` = UpgradeService, `PD` = PlayerData, `Main` = Server\Main.server.luau, `CMain` = Client\Main.client.luau, `Hud` = Client\Hud.client.luau, `Cfg` = Shared\Config.luau.

---

## 0. Findings index

| ID | Area | Class | Sev | One line |
|---|---|---|---|---|
| GP-1 | Lamp | VERIFIED WORKING | Info | 10 s blackout loss rule traced |
| GP-2 | Lamp/Co-op | VERIFIED BROKEN | Medium | Fuel drain "crew size" counts every player on the server, not the crew |
| GP-3 | Lamp/Co-op | VERIFIED BROKEN | Medium | Keeper is released after 25 s of a still pointer (idle timer ignores held aim) |
| GP-4 | Fuel/Tower | VERIFIED WORKING | Info | Refuel and tower repair flows |
| GP-5 | Tower | UNTESTED | Info | Tower is 100 HP; worst-case incoming DPS arithmetic |
| GP-6 | Creatures | VERIFIED WORKING | Info | MAX_CREATURES=45 cap works for non-boss creatures; bosses bypass it |
| GP-7 | Creatures | VERIFIED BROKEN | Low | Swarm packs count failed spawns at the cap, so fewer skitters than designed |
| GP-8 | Creatures | VERIFIED WORKING | Info | Aggro/threat model works as coded; cannons become aggro magnets |
| GP-9 | Balance | SUSPECTED | Medium | Crab count and boss HP ignore crew size; only skitters scale |
| GP-10 | Bosses | VERIFIED WORKING | Info | Boss nights 4, 7, 10, 13 (one each) |
| GP-11 | Bosses | PLANNED | High | "One boss per crew member": exact touch points and risks |
| GP-12 | Bosses | PLANNED | High | "Boss every night after 7": exact touch points and the MAX_BIG_PER_RUN truncation trap |
| GP-13 | Bosses | SUSPECTED | Medium | Legacy BossName/BossHealth attributes flap when two same-kind bosses live |
| GP-14 | Bosses | PLANNED | High | Tower DPS / reward-inflation arithmetic for the boss redesign |
| GP-15 | Cannons | VERIFIED BROKEN | Medium | Reloading with a Fire Shell crate wipes the cannon's existing ammo; crates always override oil |
| GP-16 | Weapons | VERIFIED WORKING | Info | Server-authoritative strikes (cooldown, range clamp, equipped-tool check) |
| GP-17 | Weapons | SUSPECTED | Low | `Attack` accepts +/-inf coordinates (NaN check only) |
| GP-18 | Weapons | VERIFIED BROKEN | Low | Storm Harpoon trade-off text contradicts stats (9 vs 8 damage) |
| GP-19 | Upgrades | VERIFIED BROKEN | Medium | `BuyUpgrade` has no Ready, phase or proximity check |
| GP-20 | Upgrades | VERIFIED WORKING | Info | Bench levels, Walls/FuelTank effects, evolutions |
| GP-16b | Weapons | UNTESTED | Info | Weapon / beam / cannon DPS arithmetic (balance note) |
| GP-21 | Economy | VERIFIED BROKEN | Medium | Shell income dwarfs Shell sinks (arithmetic) |
| GP-22 | Economy | VERIFIED WORKING | Info | Pearl income vs shop prices (arithmetic); matches docs |
| GP-23 | Pearls | VERIFIED BROKEN | High | Pearls (13 nights + 5) are paid to anyone Ready at the end, including players who joined on the last night |
| GP-24 | Pearls | VERIFIED BROKEN | High | No Pearls and no run credit on quit, disconnect, or leaving the crew mid-run |
| GP-25 | Co-op | VERIFIED BROKEN | Medium | Crew size is not capped at 4 anywhere on the server |
| GP-26 | Saves | SUSPECTED | Medium | DataStore: no session lock, last-write-wins, lost-dirty-flag race |
| GP-27 | Saves | VERIFIED BROKEN | Medium | A failed-load profile (`doNotSave`) gets no "progress isn't saving" warning |
| GP-28 | Shop | VERIFIED WORKING | Info | Quartermaster flow is server-validated and idempotent |
| GP-29 | Trader | VERIFIED WORKING | Info | Trader flow |
| GP-30 | Loadout | VERIFIED WORKING | Low | Loadout flow; unbounded per-player request memory |
| GP-31 | Run flow | VERIFIED WORKING | Info | Victory / defeat / rematch / reset flow; resetRound completeness |
| GP-32 | Run flow | VERIFIED BROKEN | Low | A player who returns to harbor on Results makes everyone wait the full 25 s |
| GP-33 | Run flow | VERIFIED BROKEN | Low | 0.6 s join window: a player can be Ready but stranded on the ship during a run |
| GP-34 | Run flow | VERIFIED BROKEN | Low | Aborted prologue leaves draining/protected/creatures until the next reset |
| GP-35 | Co-op | UNTESTED | Medium | Lamp shift (hand-over) traced; never run with 2+ players |
| GP-36 | Co-op | VERIFIED WORKING | Info | Keeper release on leave/death and mid-run join paths |
| GP-37 | Perf | UNTESTED | Medium | Per-frame server cost inventory; no 45-creature/4-player evidence in the repo |
| GP-38 | Perf | VERIFIED BROKEN | Low | Auto-sweep re-raycasts the beam glows every frame, in every phase |
| GP-39 | Perf | SUSPECTED | Low | Cannon health UI updates per attacker per frame; tower push() per damage call |
| GP-40 | Perf | SUSPECTED | Medium | Loot orbs are CFrame-animated every frame while idle |
| GP-41 | Traffic | SUSPECTED | Low | Remote and attribute traffic inventory (PlaySound, GearData, boss attributes) |
| GP-42 | Leaks | VERIFIED WORKING | Info | No per-run instance/connection leak found; small unbounded tables listed |
| GP-43 | Mobile | VERIFIED BROKEN | Medium | Two scripts fight over `TouchControlsEnabled`; closing any modal while Keeper re-shows the joystick |
| GP-44 | Controller | VERIFIED BROKEN | Medium | Gamepad player can take the lamp but cannot aim, focus or leave |
| GP-45 | Controller | SUSPECTED | Medium | Gamepad strike relies on `mouse.Hit` |
| GP-46 | Mobile | SUSPECTED | Low | Hybrid touch+keyboard devices are treated as keyboard |
| GP-47 | Mobile | UNTESTED | Medium | Phone HUD placement relies on hard-coded pixel zones |
| GP-48 | Mobile | VERIFIED WORKING | Info | Phone control paths: tap-to-strike, touch aim, weapon slot |
| GP-49 | Dead code | VERIFIED BROKEN | Low | Dead Config keys (docs list some as live) and disabled legacy Gear script |
| GP-50 | Safety | SUSPECTED | Low | `GearAction("sync")`, `SetReady(false)`, `ReportDevice` are unthrottled |
| GP-51 | Safety | SUSPECTED | Low | `syncGear` can touch Humanoid.Health of a dead character |
| GP-52 | Ops | VERIFIED WORKING | Info | EVENT_LOG_ENABLED is true in the live build |
| GP-53 | Docs | VERIFIED BROKEN | Medium | Doc/code mismatches (table in section 12) |

---

## 1. Lamp, beam, fuel, blackout rule

### GP-1 - 10 s blackout rule (VERIFIED WORKING, Info)
- Evidence: `LS:275-292` while `draining` fuel falls `rate*dt`; `if fuel <= 0 then LampService.darkSeconds += dt else LampService.darkSeconds = 0`. `GS:439-443` the night countdown stops when `lamp.darkSeconds >= Config.DARK_GRACE_SECONDS` (Cfg:51 = 10). `GS:447,456-458` sets Cause "blackout" and the Defeat reason. `LS:223-229` `setDraining(false)` zeroes the counter.
- Scenario: tank empties at night; if nobody refuels for 10 s the night ends in Defeat; a refuel at any moment before that resets the counter on the next Heartbeat. Dark time is only counted at night (draining is false in Day, and the prologue never checks it, `GS:198-272`).
- Resolution of loss check is the countdown poll of 0.2 s (`GS:139`), so defeat lands 10.0 to about 10.2 s after the lamp dies.
- Minor edge (Info): between the Heartbeat that reaches 10.0 and a refuel handled in the same frame window, the 0.2 s poll could see `darkSeconds >= 10` after `fuel > 0`; window is at most one frame. No fix needed.
- Fix: none.

### GP-2 - Fuel drain scales by all players on the server, not by the crew (VERIFIED BROKEN, Medium)
- Evidence: `LS:284` `local crewSize = math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)`; Cfg:48 `FUEL_DRAIN_BY_CREW_SIZE = { 0.7, 0.85, 1, 1 }` with the comment "solo can't refuel and keep the lamp at once". Compare the swarm: `GS:410` uses `#readyPlayers()`.
- Scenario: the lobby hosts players who are not in the crew (title screen, harbor, ship); the docs describe "20+ players" in the lobby. A solo crew with 3 bystanders (4 players on the server) drains at x1.0 (index 4) instead of x0.7, while the swarm is scaled for 1 player (x0.4). The two difficulty dials disagree and the solo mitigation silently disappears on any non-empty server. Arithmetic: wide beam, 90 s night: x0.7 = 1.2*0.7*90 = 75.6 fuel (1.89 barrels at 40) vs x1.0 = 108 fuel (2.7 barrels).
- Fix (describe only): derive the multiplier from the same Ready count `GameState` uses (publish `CrewCount` or call `readyPlayers`) and clamp to 1..4.

### GP-3 - Keeper idle release ignores a held aim (VERIFIED BROKEN, Medium)
- Evidence: `LS:248` releases after `os.clock() - lastKeeperInput > Config.KEEPER_IDLE_SECONDS` (25). `lastKeeperInput` is refreshed only at `LS:156` (take), `LS:328` (a `BeamControl` angle) and `LS:345` (mode toggle). Client sends `BeamControl` only when `pendingAngle` was set by a pointer move/touch drag: `CMain:175-184` (InputChanged mouse move / touch) and `CMain:202-208`.
- Scenario: Keeper parks the focused beam on a slow boss and keeps the pointer still (or a phone player holds a finger still) for 25 s: the lamp reverts to the weaker auto-sweep (no focus, no wide push), "You stepped away from the lamp" (`LS:252`).
- Fix: also treat any input from the Keeper (periodic heartbeat remote, or resend the current angle at about 1 Hz while the pointer is held) as activity; or only release for true absence (dead/left).

### GP-4 - Refuel and tower repair (VERIFIED WORKING, Info)
- Refuel: `IslandBuilder:257-288` oil pile (prompt hold 0.5 s), `Main:204-214` sets `CarryingOil` + a barrel part, `Main:216-248` refuel adds `FUEL_PER_REFILL` 40 via `LS:218-221`, removes the barrel first, rejects when the tank is full (`Main:221-224`). Oil is unlimited (no stock). Waste when the tank is above 60 (a barrel adds min(40, space)) is not prevented (Low UX).
- Tower repair: `TS:26-38` prompt `Triggered` -> `TowerService.repair(20 * (1.5 if Evo_ClockworkBastion))`, hold 1.5 s (`IslandBuilder:253` with `Config.REPAIR_HOLD_SECONDS`). 20/1.5 = 13.3 HP/s per repairer (20 HP/s with the evolution). Rejects when full.
- Walls: `US:100-103` raises max to 150/200/250 and adds 50.
- Fix: none.

### GP-5 - Tower durability (UNTESTED, Info)
- Facts: tower max 100 (Cfg:109), Walls up to 250; creature `towerDps` RockCrab 0.6, Skitter 0.12, Brute 5, Hermit 4 (`Shared\Creatures`); damage is `stats.towerDps*dt` per creature in range 10 studs of the tower (`CS:664-665`).
- Arithmetic: 45 Rock Crabs at the tower = 27 HP/s, which breaks an undefended 100 tower in 100/27 = 3.7 s; 45 skitters = 5.4 HP/s = 18.5 s. 4 Brutes = 20 HP/s = 5 s (12.5 s with Walls 250). One repairer restores 13.3 HP/s.
- No claim made about how often this happens; it depends on beam, cannon and harpoon cover.

---

## 2. Creatures, spawning, aggro, cap

### GP-6 - MAX_CREATURES cap (VERIFIED WORKING, Info)
- Evidence: `CS:356-358` `if #creatures >= Config.MAX_CREATURES and not stats.big then return false`; both spawners also wait: `GS:149` and `GS:177` (poll 0.5 s). Cfg:120 = 45.
- Behaviour: at most 45 non-boss creatures alive; bosses bypass the cap, so peak alive = 45 + live bosses (up to 49 with the planned 4-boss nights). `count()` includes bosses, so a live boss takes a slot from the swarm.
- Spawn pressure (arithmetic, crew 4, no forecast): night 13 has 105 crabs over 90*0.7 = 63 s (1.67/s) and 154 skitters in 52 packs over 90*0.85 = 76.5 s (1 pack per 1.47 s, 2.0 skitters/s) = about 3.7 spawns/s against 45 slots, so the cap is the effective limiter late in the run. Night 1: 14 crabs/63 s = 0.22/s (cap not relevant).

### GP-7 - Swarm pack loop miscounts at the cap (VERIFIED BROKEN, Low)
- Evidence: `GS:184-187` `for _ = 1, math.min(packSize, total - spawned) do creatures.spawn("SandSkitter", ...) spawned += 1 end`; `CS:356` returns false without spawning at the cap; `spawned` is incremented regardless. The check `GS:177` happens once per pack, not per skitter.
- Scenario: count is 44, pack of 3: first skitter spawns, the other two are dropped but counted. The night's swarm is smaller than the table (1354 for a crew of 4) by an amount that depends on how often the cap is hit. Crab wave (`GS:148-157`) is safe because it re-checks before each spawn. Neither spawner "catches up" after waiting, and both stop at night end (`GS:445-446`), so late spawns are simply lost.
- Fix: increment `spawned` only when `spawn` returns true (and re-check the cap per skitter).

### GP-8 - Aggro/threat (VERIFIED WORKING, Info)
- Evidence: `CS:233-254` target choice with 1.25 switch ratio; `CS:424-452` weapon hits add `amount*2.0` threat to the player, cannon hits add `amount*1.0` to the pad; `CS:558-569` decay 8%/s, tower floor 5, +4/s proximity within 10 studs; beam damage adds `0.6*dmg` to the tower (`CS:607`); eye colour mirrors intent.
- Observations: one cannon hit (10 to 24 dmg => threat 10 to 24) beats the tower base of 5, so any creature a cannon hits walks to that cannon and chews it (`cannonDps` 2/s crab, 14/s Brute vs cannon HP 60/90/120). Decay from a single harpoon hit (8 dmg => threat 16): 16*(0.92^t) < 5 after ln(16/5)/0.0834 = 14 s. Creatures are anchored, no pathing; they walk straight lines and never collide with pads or the tower (`CS:688-693` pushes them out to radius 10).
- Fix: none required.

### GP-9 - Difficulty by crew size (SUSPECTED, Medium)
- Evidence: crab count `GS:405-408` has no crew term; skitters `GS:410-412` scale by `Config.SWARM_BY_CREW` {0.4, 0.65, 0.85, 1.0}; boss HP is fixed (`CS:379-380`, `Creatures` health 700/480); Pearl and Shell night bonuses are per run, not per player.
- Arithmetic (13 nights, no forecast): crabs total 621 for every crew size. Skitters by crew: 542 (solo), 881 (2), 1152 (3), 1354 (4). Creatures per run: 1163 solo, 1502 (2), 1773 (3), 1975 (4). Per player: 1163 / 751 / 591 / 494. Solo faces the same 621 crabs as a full crew with one pair of hands (and the keeper cannot also refuel).
- Per-night tables are in section 11.
- Fix: decide whether crabs and boss count/HP should follow `SWARM_BY_CREW`; playtest 1, 2, 4 player runs before changing.

---

## 3. Boss scheduling and the two planned changes

### GP-10 - Current boss schedule (VERIFIED WORKING, Info)
- Evidence: `GS:361-378`: `candidates` start at `NIGHTS_TO_WIN` and step back by `BIG_EVERY_NIGHTS` (3) while `n >= 2`: 13, 10, 7, 4 (the `n >= 2` guard excludes night 1). `MAX_BIG_PER_RUN` (Cfg:133 = 4) caps picks; each pick `Creatures.BIG_POOL[math.random(1, #BIG_POOL)]` (Brute or Hermit). Spawn: warning `GS:419-424` at +3 s, spawn `GS:425-436` at `NIGHT_SECONDS*BIG_SPAWN_DELAY` = 90*0.15 = 13.5 s, at one random bearing (`GS:430-431`). Matches docs.

### GP-11 - "One boss per crew member": exact touch points (PLANNED, High)
Do NOT treat as a spec; this is a map of what a change would touch.

| File:lines | What is there now | What would have to change / risk |
|---|---|---|
| `GS:358-378` | one boss kind per boss night in `bigNights[n]` | store a count (and per-boss kinds) per night; decide if kinds mix |
| `GS:410` | `crewSize` is read at night start | boss count must use a defined moment: night start (13.5 s before the spawn) or spawn time; players can join/leave in between (`Main:646-657`); crew > 4 is possible (GP-25) so clamp |
| `GS:416-437` | one `task.delay` that calls `creatures.spawn(bigKind, bearing)` once, single announce/EventLog text | loop N times, distinct bearings ("different directions"), stagger or simultaneous; singular strings ("A %s climbs out...") |
| `GS:419-424` | `BigWarning` attribute + notice | unchanged mechanics; text |
| Cfg:132-136 | `MAX_BIG_PER_RUN`, `BIG_*` | semantics change from per-run to per-night; new keys needed |
| `CS:356` | bosses bypass the 45 cap | alive could reach 45 + 4; docs ask whether bosses should count as several slots (progress.md 14c) |
| `CS:394-412` | per boss: legacy `BossName/BossMax/BossHealth` attributes AND a `Bosses` folder entry | legacy attributes overwrite each other (see GP-13) |
| `CS:330-346`, `CS:700-707` | legacy attribute re-pointing and per-frame sync keyed by display name | remove or key by entry (GP-13). Hud does not read them (grep shows only `Hud:1011-1136` Bosses folder) |
| `CS:379-380` | boss HP fixed; not scaled by forecast (`ForecastCrabHpMult` excluded for big) | docs decision "full health, tune later" |
| `CS:665` | `tower.damage(stats.towerDps*dt)` per boss | additive tower DPS (GP-14) |
| `CS:669-677` | slam hits every player within `slamRadius` of the target, per boss, with its own `nextBite` | several bosses slam the same players; damage stacks |
| `LO:118-131` | per-boss drops and a "The monster is down!" `Notify` | per-boss Shells/Sea Glass/claws/Pearls; notify spam (GP-14) |
| `Hud:1010-1136`, `Hud:1246-1253` | boss bars already support many entries, side by side only on phones with 2+ | desktop stacks up to 4 bars vertically; check vertical space |
| `Hud:1111` | the "something BIG is coming" banner hides once any bar exists | ok |
| `EventLog` | `BigMonsterSpawned/Killed` logs, `moment` priority 2 | per-boss logging fine |
| `DS` | `findTarget` (`CS:470-479`) returns the creature closest to the tower, bosses included | cannon fire would favour whichever boss is closest, not a chosen one |

Risks: (a) additive tower DPS and slams (GP-14); (b) simultaneous bosses plus a full swarm at 45 cap; (c) the legacy-attribute flap (GP-13); (d) reward inflation (GP-14); (e) crew-size race at spawn time; (f) no cap on crew size (GP-25).

### GP-12 - "Boss every night after night 7": exact touch points and a trap (PLANNED, High)
- Required nights: 4, 7, 8, 9, 10, 11, 12, 13 = 8 boss nights per run.
- `GS:361-378` builds boss nights only by stepping back from the last night by `BIG_EVERY_NIGHTS`; "every night after 7" needs an explicit list/rule.
- TRAP: the loop at `GS:373-378` iterates candidates in descending order and stops at `picked < Config.MAX_BIG_PER_RUN` (Cfg:133 = 4). If candidates become {13, 12, 11, 10, 9, 8, 7, 4} and the cap stays 4, the picked nights are 13, 12, 11, 10; nights 4 and 7 (and 8, 9) would silently have no boss. Cfg:133 must be raised to at least 8 (or the cap removed).
- Also touched: Cfg:33 and Cfg:132-136 comments and `docs\progress.md` sections 1/4/5; `NIGHTS_TO_WIN > 5` guard at `GS:364`; the Coach "focus (big monster)" prompt text for first-timers (Coach is gated to runs=0 players, unaffected in logic).
- Pearl/Shell consequences: see GP-14.
- Fix (describe only): replace the stepping rule with a data-driven night list (`Config.BOSS_NIGHTS`) and drop `MAX_BIG_PER_RUN` or make it per-night.

### GP-13 - Legacy boss attributes flap with two same-kind bosses (SUSPECTED, Medium; latent)
- Evidence: `CS:702` `if state:GetAttribute("BossName") == stats.displayName and state:GetAttribute("BossHealth") ~= shown then state:SetAttribute("BossHealth", shown)`. With two Barnacle Brutes of different HP, each boss's per-frame call overwrites the value the other just wrote, so `BossHealth` is rewritten every frame, replicating to all clients. `CS:394-397` also overwrites `BossName/BossMax` on every spawn.
- Impact today: zero (only one boss alive at a time; no client reads these attributes: `Hud` uses the `Bosses` folder).
- Fix: delete the legacy attributes (and the comment at `CS:49`) before the boss redesign.

### GP-14 - Boss redesign arithmetic (PLANNED, High)
Crew 1/2/3/4 with one boss per member and bosses on nights 4, 7, 8-13 (8 nights): bosses per run = 8 / 16 / 24 / 32.
- Boss Pearl orb: `BOSS_PEARL_CHANCE` 0.5 x average of 2..4 (3) = 1.5 Pearls per boss (`LO:126-127`, Cfg:21-23). Expected Pearls per run from boss drops (collected by whoever is nearest, `LO:249-258`): 12 / 24 / 36 / 48 on top of 18 per player for a win. Docs estimate "30 to 50" for a 4-player win: consistent with 48.
- Boss Shells: expected 52 + Sea Glass 33 + two Claws 2*4 = 8 + 0.5*130 (Black Pearl) = 65 -> 158 shell-equivalents per boss if all loot is sold: 1264 / 2528 / 3792 / 5056 per run. Shells are already in surplus (GP-21).
- Orbs: each boss death creates Shells + Sea Glass + 2 Claws + 0 to 2 more orbs (`LO:119-128`), 4 to 6 orbs per boss; 32 bosses = 128 to 192 orbs per run, each animated every frame while idle (GP-40).
- Tower: each boss adds 5 (Brute) or 4 (Hermit) HP/s at the tower; 4 Brutes = 20/s (GP-5).
- Total boss HP per night at 4 crew: 4*700 = 2800 (Brute) or 4*480 = 1920 (Hermit); single-target sources: focused beam 35 * 0.5 (Brute) = 17.5 dps per boss in the cone (30.6 dps with Lens L3 x1.75; Hermit 35 * 0.75 = 26.3); Whaler 28.1; L3 Oil cannon 20 (32 Fire Shell); cannon splash hits up to 3 targets.
- Time to arrive: spawn at radius 92, stop at radius 10: Brute 82/3 = 27.3 s, Hermit 82/4.5 = 18.2 s (focused beam freezes them, wide beam x0.6 speed: `CS:578-587`).

---

## 4. Weapons, cannons, upgrades

### GP-15 - Fire Shell crate reload wipes existing ammo and always overrides oil (VERIFIED BROKEN, Medium)
- Evidence: `DS:291-301` crates are checked first (`crateFor(player)`; `Main:167-174` returns the first Ammo item the player holds); `DS:302-305` the "already full" check only fires when `newType == pad.ammoType`; `DS:314-318` "Switching ammo types replaces what was loaded": `pad.ammoType = newType; pad.ammo = 0` then adds `shotsPerLoad`.
- Scenario 1: a cannon holds 25/25 Oil Shot (L3). A player carrying any crate reloads it: oil is wiped, the cannon holds 10 Fire Shells (-15 shots) and the paid crate (8 Pearls, `Items:101`) is consumed.
- Scenario 2: a player who owns crates cannot use oil on any cannon (crate path always wins); to refill with oil they must drop all crates (no UI for that).
- Scenario 3: reloading oil onto a Fire Shell cannon (player with no crate) wipes the remaining Fire Shells (`DS:314`).
- Fix: only convert when the cannon is empty or the player confirms; otherwise top up same-type ammo; let the player choose crate vs oil (prefer oil unless the cannon is empty/Fire Shell).

### GP-16 - Weapon strikes (VERIFIED WORKING, Info)
- `Main:498-543`: validates Vector3 (NaN), refuses the Keeper, reads the real equipped Tool's `WeaponId` (set server-side at `Main:292`), enforces `weapon.cooldown` (`Main:521-525`), clamps to `weapon.range` (`Main:528-531`), damages via `damageArea` (hitRadius, maxTargets). Starter Harpoon 8 dmg / 0.9 s = 8.9 dps; Storm 9/0.9 = 10 dps (x3 targets); Flare 11/1.8 = 6.1 dps (x6 targets, worse single-target than the starter); Whaler 45/1.6 = 28.1 dps (single). Weapon damage ignores `beamDamageMult` (armor of bosses only affects the beam).
- Note: strike has no phase/Ready check, but it needs a server-granted Tool and creatures only exist on the island.

### GP-17 - Attack remote accepts infinite coordinates (SUSPECTED, Low)
- Evidence: `Main:500` rejects NaN only (`target.X ~= target.X`); +/-inf passes. `Main:529-531` then computes `offset.Unit` of an infinite vector (NaN) and `showProjectile` (`Main:542`) builds `CFrame.lookAt` from it.
- Scenario: an exploiter fires `Attack` with `Vector3.new(math.huge, 0, 0)`; resulting NaN CFrame/part may error in the handler or create a broken part. Low (self-inflicted, cooldown-limited).
- Fix: reject non-finite components (compare with `math.huge`) like `BeamControl` does at `LS:324`.

### GP-18 - Storm Harpoon text vs stats (VERIFIED BROKEN, Low)
- `Items:42` tradeoffs "Same damage per target as the starter" vs `Weapons:16` damage 8 (starter) and `Weapons:26` damage 9 (Storm). Already noted in progress.md section 12; still present.

### GP-19 - Upgrade purchase has no Ready/phase/proximity check (VERIFIED BROKEN, Medium)
- Evidence: `Main:116-146`: only checks `id` is a string and a 0.3 s per-player throttle, then `UpgradeService.buy(id)` spends the crew's Shells (`US:108-131`). Compare `Trader` (`Main:818-822`: Ready + 16 stud range) and `Shop` (`ShopService:53,136`). The cannon pads use ProximityPrompts and are engine range-checked.
- Scenario: any client, including a lobby bystander or a title-screen player, can fire `BuyUpgrade("Walls")` etc. and spend the crew's pooled Shells; a griefing exploiter can also buy upgrades in the wrong order (evolutions are free but irreversible choices).
- Fix: require `player:GetAttribute("Ready")`, distance to the bench part, and a run phase.

### GP-20 - Bench and evolutions (VERIFIED WORKING, Info)
- Costs `Shared\Upgrades`: Lens 30/60/100, Fuel Tank 25/50/90, Walls 25/50/90, Clockwork 40/80/120 = 760 total. `US:96-105` applies FuelTank (max + `addFuel(30)`) and Walls (`setMax` + `repair(50)`); Lens and Clockwork are read live in `CS:536-537`; evolutions `US:35-56` unlock when both needed upgrades are maxed (`Evo_*` attribute read in `LS:279` and `TS:32`). `US:133-140` resets everything each run.

### GP-16b - Weapon balance note (UNTESTED, Info)
- Beam: wide 12 dps/creature (x1.75 with Lens L3 = 21) hits every creature in an 18 degree half-angle cone simultaneously; focused 35 dps (61 at Lens L3) in a 9 degree half-angle. On-foot weapons are 6 to 28 dps single-target (harpoon) but multi-target for Storm/Flare. Cannon L1/L2/L3 oil: 6.25 / 11.4 / 20 dps (Fire Shell x1.6). The Keeper's cone is by far the strongest area source; there is no distance limit inside the beam (`CS:555` tests bearing only; creatures exist only within radius 93 and `BEAM_LENGTH` is 105).

---

## 5. Shell and Pearl economy

### GP-21 - Shell income vs sinks (VERIFIED BROKEN, Medium)
Sources in code: start 120 (`US:134`, Cfg:12); night bonus `13*night` (`GS:463`); Rock Crab orb 3 to 5 uniform = 4 average (`LO:132`); Skitter 26% x 1 (`LO:113`); boss 52 (`LO:119`); Trader pays Claw 4 (30% per crab), Sea Glass 33 (4%), Black Pearl 130 (0.5%) (`Items`, `LO:133-142`). Shell sinks are only the cannons and bench (`trySpend` callers: `DS:257`, `Main:131`; `addShells` callers: `GS:464`, `LO:167,218`, `Main:757`): 6 pads x (40+70+110) = 1320 plus bench 760 = **2080 total**; oil/crates are not paid in Shells.

Arithmetic (13 nights, 621 crabs, no forecast, every creature killed, every orb collected):
- Night bonus: 13 x (1+2+...+13) = 13 x 91 = **1183**.
- Start: 120. **Floor with zero loot: 120 + 1183 = 1303** (already 63% of all sinks).
- Crab orbs: 621 x 4 = 2484. Skitter orbs by crew: 142 (solo, 542 x 0.26), 229, 300, 352 (crew 4, 1354 x 0.26). Boss orbs: 4 x 52 = 208.
- Orbs only (no selling items): 120 + 1183 + 2484 + 208 + skitters = **4136 (solo) to 4347 (crew of 4)**.
- Items sold to the Trader (expected): claws 621 x 0.3 x 4 = 745; Sea Glass 621 x 0.04 x 33 = 820; Black Pearl 621 x 0.005 x 130 = 404; bosses 4 x (33 + 8 + 65) = 424. Total potential **about 6529 (solo) to 6740 (crew 4)**.
- If only the dawn tide collects the orbs at 50% (`LO:208-224`): 120 + 1183 + 0.5 x (2484 + 208 + skitters) = **2719 to 2825**, still 640 to 745 above the 2080 sinks.
- Conclusion: Shells exceed sinks by at least about 640 even under pessimistic collection and by roughly 2050 to 4660 under full collection; the bonus alone nearly covers every sink. Matches the doc's "Shells pile up" (progress.md 12), now quantified. The only late-run sinks are cannons being destroyed and rebuilt (each rebuild 40 to 110).
- Fix (describe only): add real Shell sinks (the planned merchant) or reduce per-night bonus / orbs; do not change numbers without owner approval (hard rule in progress.md section 2).

### GP-22 - Pearl income vs prices (VERIFIED WORKING, Info)
- Income: `GS:507-524`: win = 13 x `PEARLS_PER_NIGHT` 1 + `PEARLS_VICTORY_BONUS` 5 = **18**; defeat on night N pays N-1 (`GS:509`, `nightReached - 1`), no bonus; `PEARLS_NIGHT_STEP` 0, `PEARLS_PER_AWARD` 0 (Cfg:18-20). Boss Pearl orb adds 1.5 expected per boss (GP-14). Run time: 13 x (30 + 90) = 1560 s = 26 min plus prologue (up to 90 s), intermission 10 s, results up to 25 s.
- Prices (`Items`): Storm Harpoon 30, Keeper's Coat 35, Flare Gun 60, Whaler 140, Ironclaw 140, Fire Shell crate 8 each (stack 20 = 160), beams 25/40/60. **Permanent unlocks total 530 Pearls** (30+35+60+140+140+25+40+60). At 18 per win that is 29.4 wins (about 12.8 hours of full runs), excluding boss Pearls and crates. First purchase: Storm Harpoon (30) after 2 wins (36 Pearls) or after 3 deep defeats (a defeat on night 13 pays 12; 3 x 12 = 36).
- Matches progress.md prices (section 4). `EXPENSIVE_PRICE` 60 (`Items:26`) means Flare Gun and up ask for confirmation (client-side dialog only).

### GP-23 - Pearls are paid to whoever is Ready at the end, including late joiners (VERIFIED BROKEN, High)
- Evidence: `Main:646-657` `joinCrew` sets `Ready` true and, in a run phase, rows the player to the island; the first-voyage fast path calls it too (`Main:678-710`, "mid-voyage if a run is underway"). `GS:503` `voters = readyPlayers()` and `GS:507-524` pays `PEARLS_PER_NIGHT * survived (13 for a win) + 5` to every voter regardless of join time; `recordRun` also credits a run and a victory.
- Scenario: a brand-new player joins a public server on night 13 of a stranger's run (route "fast" = auto-join), stands anywhere, and receives 13 + 5 = 18 Pearls plus a "Victory" in their stats if the crew wins (also true for players stranded on the ship, GP-33). Players who join on night 1 and play 26 minutes receive the same. It also lets the Pearl price table in GP-22 be bypassed by joining runs at the end.
- Fix: record per-player participation (night joined, seconds on island, any action) and pay nights survived only while Ready; or pay a pro-rata or minimum-participation reward.

### GP-24 - No reward on quit, disconnect or leaving the crew (VERIFIED BROKEN, High)
Exit paths and what happens:
| Path | Code | Pearls? |
|---|---|---|
| Win/defeat with player still Ready (even dead) | `GS:507-524` | paid |
| Disconnect mid-run | `Main:545-555` only logs `PlayerQuit`; `PD:323-331` saves the profile (no reward added) | **no**, `stats.runs` not incremented |
| "Main Menu"/SetReady(false) mid-run | `Main:87-99`, `Main:639-643` clears Ready and teleports to ship | **no** (not in `voters`) |
| All players leave -> "Abandoned" | `GS:355-357,391,452-453,508` | **no one**, no run recorded |
| Server shutdown mid-run | `PD:332-338` saves but no payout | no |
| Player leaves during Results | already paid before `RunResults` (`GS:520` before `GS:533`) and saved on leave | paid |
- Scenario: a solo player loses a connection at night 12 after 24 minutes; the run is Abandoned and they get 0 Pearls (they would have had 11 if defeated there). A 4-player crew with one disconnect at night 12: the leaver gets 0, the others get 18.
- Fix: grant `nights survived so far` Pearls (no victory bonus) on PlayerRemoving / SetReady(false) during a run, once, before saving.

### GP-25 - Crew size 1 to 4 is not enforced (VERIFIED BROKEN, Medium)
- Evidence: no cap in `joinCrew` (`Main:646-657`), `chooseRoute` (`Main:678-710`) or `helmPrompt` (`Main:660-672`); GS clamps only in its scaling formulas (`GS:410`, `LS:284`). Place `MaxPlayers` is a Studio setting not present in the export; progress.md describes a 20+ player lobby. `Departure.client:29,344-353` prints "+N more" for a crew above 4, so >4 is anticipated but not blocked.
- Scenario: 8 players join; swarm and fuel scaling stay at the 4-player value (1.0); bosses planned "per crew member" would need an explicit cap.
- Fix: cap Ready at 4 (queue/"crew full" message) or define scaling for 5+.

---

## 6. Save, shop, trader, loadout

### GP-26 - DataStore semantics (SUSPECTED, Medium)
- `PD:101-116` save uses `store:UpdateAsync(key, function() return profile end)`: the transform ignores the stored value, so this is a last-writer-wins `SetAsync`; no session lock. A player who leaves server A and joins server B before A's save completes loads stale data and the later write on either side overwrites the other (progress.md notes that Studio and live share the store).
- `PD:111-112`: `dirty[player] = nil` after a successful save; changes made during the yield (for example `addPearls` at run end, `PD:170-178`) set `dirty` true, then the completing save clears it; if the player leaves before the next change, `PlayerRemoving` (`PD:324-326`) skips saving (`PD:103`). Window is the duration of one UpdateAsync once per minute per dirty player.
- `PD:332-338` BindToClose saves players sequentially.
- Fix: use a session-locked profile approach or `UpdateAsync` with a version/session check; clear `dirty` only if no change happened since the transform ran (compare a change counter).

### GP-27 - Failed-load profile gets no warning (VERIFIED BROKEN, Medium)
- Evidence: `PD:132-136` sets `profile.doNotSave = true` and `PD:147-148` sets `ProfileState = "failed"`, but the HUD warning reads the player attribute `SaveUnavailable` (`Hud:1169`, `Inventory:726`), which `PD:299-307` sets only when the whole DataStore is unavailable at startup.
- Scenario: a DataStore hiccup on join gives the player an in-memory profile; they earn and spend Pearls all session, then lose everything when they leave (`PD:325` skips save) with no warning.
- Fix: set `SaveUnavailable` for `doNotSave` profiles, and retry the load.

### GP-28 - Quartermaster / Shop (VERIFIED WORKING, Info)
- `ShopService:181-208`: requestId (string, <= 40 chars) memory for 40 requests, 0.2 s per-player throttle; `process` `ShopService:132-159` requires an open shop, range <= 18 studs of the counter (`SHOP_RANGE` 16 + 2), a real catalog id, numeric quantity; `buy` `ShopService:69-110` takes the price from `Items`, rejects owned gear, caps stacks at `maxStack`, `spendPearls` fails on insufficient funds. No yield between ownership check, spend and grant, so double requests cannot double-spend. `sell` is refused (loot sells to the Trader). Beams only if `COSMETICS_ENABLED`. The shop sits on the lobby ship (LobbyBuilder moves the counter); players can shop between runs only.

### GP-29 - Trader (VERIFIED WORKING, Info)
- `Main:792-830`: Ready required, range <= `MaxActivationDistance + 6` = 16 studs, one-request memory per player (`traderHandled`), 0.3 s throttle; `sellAllLoot` (`Main:741-763`) clears the run-scoped loot, credits Shells at `shellValue` and announces. Works in any phase (including mid-night) as long as the player is Ready and near the Trader.

### GP-30 - Loadout (VERIFIED WORKING, Low)
- `LoadoutService:23-89`: slot/ownership checks; equip works mid-run (syncGear swaps the tool and armor); starter slots cannot be emptied. Low: `LoadoutService:80-84` stores every `requestId` forever per player (no cap like `ShopService:26`); bounded by the 0.2 s throttle but unbounded per session.

---

## 7. Run flow: victory, defeat, rematch

### GP-31 - Run lifecycle (VERIFIED WORKING, Info)
- Loop `GS:320-562`: Waiting -> Intermission (10 s) -> `resetRound` (`Main:837-851` clears loot, lamp, tower, upgrades/shells/levels/evolutions, cannons, creatures, orbs, carried oil) -> Prologue -> 13 x (Day 30 s -> Night 90 s) -> Victory/Defeat/Abandoned -> Pearls and `recordRun` -> `RunResults` -> up to 25 s rematch vote (`GS:536-543`) -> non-voters `Ready=false` and `sendToShip` (`GS:549-554`).
- `EventLog.startRun` resets per-run stats; `ForecastVote`, `WantsRematch`, `Cause/Reason` are reset at the loop top or before results.
- Run-scoped loot is cleared on every run end (`GS:526-528`). Health is not reset by the server between runs (no `Humanoid.Health` writes in server code besides `syncGear`); recovery relies on engine-default regeneration (UNTESTED here).

### GP-32 - Harbor-goer stalls the rematch countdown (VERIFIED BROKEN, Low)
- Evidence: `GS:537-541` returns false while any voter still exists with `WantsRematch` false; a voter who clicked "Back to harbor" (`SetReady(false)`) stays in `voters` with `WantsRematch` false.
- Scenario: 4 players: 3 press Play Again, 1 returns to harbor; the other 3 wait the whole 25 s.
- Fix: ignore voters whose `Ready` is false.

### GP-33 - 0.6 s stranded-joiner window (VERIFIED BROKEN, Low)
- Evidence: `GS:336-356`: after the intermission countdown the server calls `sendToIsland` for the Ready snapshot (`GS:349-351`), then `task.wait(0.6)` and only then `setPhase("Prologue")` inside `runPrologue` (`GS:199`). `joinCrew` (`Main:651`) tests `RUN_PHASES[phase]`, which is still "Intermission" during those 0.6 s, so the joiner is Ready but not teleported.
- Scenario: that player stays on the ship for the run, counts as crew (swarm/lamp shift candidate, Pearl payout GP-23).
- Fix: set the phase before the teleport loop, or have `joinCrew` check an `inRun` flag set at `resetRound`.

### GP-34 - Aborted prologue leaves state behind (VERIFIED BROKEN, Low)
- Evidence: `runPrologue` returns false at `GS:215`, `GS:229`, `GS:257` without `lamp.setDraining(false)`, `tower.setProtected(false)` or `creatures.clearAll()` (those happen only at `GS:261-266`). `LampService.reset`/`TowerService.reset` fix it at the next `resetRound`.
- Impact: benign (protected tower and creatures in an empty server until the next run), but the lamp keeps draining and the Heartbeat keeps running creatures with nobody present.
- Fix: do the cleanup in a common exit path.

---

## 8. Co-op logic

### GP-35 - Lamp shift (UNTESTED, Medium)
- Trace: `LS:361-461`. At Day +4 s (`LS:445-456`) `offerShift` picks the first alive Ready player who has not held the lamp this run (`heldThisRun`, `LS:142`), asks the Keeper first (stage "keeper"), then the candidate; hands over only on two yeses, rechecks phase = Day and keeper unchanged on every answer (`LS:415-418`), expires after 20 s (`LS:457-461`), cancelled when the phase changes. If nobody is Keeper the candidate only gets a "nudge". Server code looks consistent; ids/stage validated, types checked.
- Not verified: any 2+ player run (docs agree). Note the new Keeper does not have to be at the console (`setKeeper` can be called from anywhere).
- Fix: test with Studio "Clients: 2".

### GP-36 - Keeper hand-over, release, mid-run join (VERIFIED WORKING, Info)
- Release when the Keeper leaves, dies or loses the character (`LS:244-247`); WalkSpeed restored to the engine default (`LS:148-153`), console prompt toggles (`LS:350-359`), `SetReady(false)`/`sendToShip` release (`Main:96-98,594-596`). A Keeper who is still holding the lamp when the run ends stays frozen until the idle timer fires (`LS:248`, up to 25 s) or `LampService.reset` (`GS:337` -> `resetRound`); it is bounded (no permanent lock).
- Mid-run join: `joinCrew` rows the joiner out (`Main:651-653`); deaths respawn on the island for Ready crew in run phases (`Main:257-266`); swarm/fuel scaling is computed at night start (GP-2, `GS:410`), so a mid-night join or leave does not change that night's swarm.

---

## 9. Server cost, traffic, leaks

### GP-37 - Server loop inventory (UNTESTED, Medium)
No frame-time or bandwidth number is claimed. docs/IMPLEMENTATION_LOG reports 0.11 ms of game work per frame and about 50 KB/s per player "solo, Studio, swarm night 1"; the repo contains no 45-creature or multi-player measurement, and no code asserts it. All loops below are from source:

| Loop | Interval | Work (counts only) |
|---|---|---|
| `CS:528` Heartbeat | every frame, returns at once if no creatures | per creature: 2 raycasts via `Ground.heightAt` (`CS:183`, `Ground:20-24`), `PivotTo`, threat table pass, `Players` scan, `tower.damage` (SetAttribute x2 + an allocated `{0.75,0.5,0.25}` table, `TS:17-20,49`), health bar write, boss attribute writes. 45 creatures at 60 Hz = 45 x 60 x 2 = **5400 raycasts/s** |
| `LS:463` Heartbeat | every frame, all phases | `applyBeam` while sweeping (GP-38); `pushState` every 0.2 s (3 attributes) |
| `LS:457` Heartbeat | every frame | one comparison |
| `LO:226` Heartbeat | every frame when orbs exist | O(orbs x players); idle orb CFrame write per frame (`LO:266`) |
| `DS:327` Heartbeat | every frame | 6 pads, cooldown gated; per shot `findTarget` O(creatures) and 4 to 5 new instances (flash, light, ball, boom) |
| `DS:360-366` `damageCannon` | per attacking creature per frame | full `updateAmmoUi` (about 10 attribute/GUI writes, `string.format` text) |
| `GS` | 0.2 s countdown, 0.25 s waits, 0.5 s cap polls, 1 s waiting loop | trivial |
| `Main:719-733` | 0.5 s | two attributes |
| `ShopService:211-220` | 0.25 s | per open shop |
| `PD:339-348` | 60 s | `UpdateAsync` per dirty profile |
- Fix: measure with 4 clients and 45 creatures (MicroProfiler + `Stats`) before the boss redesign; the cap is an alive-count, so boss nights will raise `damageArea`/threat work.

### GP-38 - Auto-sweep raycasts every frame in every phase (VERIFIED BROKEN, Low)
- Evidence: `LS:264-272` `elseif isLit then ... angle += AUTO_SWEEP_SPEED*dt; applyBeam()`; `applyBeam` (`LS:58-72`) calls `Ground.heightAt` for 3 glows (2 raycasts each = 6 raycasts per frame, 360/s) and moves the emitter. Runs in Waiting, Day, Results and with zero players (no `Ready` gate).
- Fix: skip the glow-height raycasts (cache heights per bearing, or compute them every 0.1 s) and pause when nobody is in the crew.

### GP-39 - Chatty per-call updates (SUSPECTED, Low)
- `TS:41-55` every `damage` call runs `push()` and builds a table; with N attackers that is N calls per frame. `DS:360-366` `damageCannon` calls `updateAmmoUi` (attributes `CannonHealth` etc. and GUI sizes) for every attacker every frame; `CannonHealth` is a float that changes each time, so it replicates continually while attacked.
- Fix: accumulate per-frame damage once and write once per frame.

### GP-40 - Loot orbs animated every frame (SUSPECTED, Medium)
- Evidence: `LO:262-269` every landed orb's `CFrame` (and pillar) is rewritten each frame (bob/spin or magnet), plus `Anchored` parts replicate property changes. With 4 to 6 orbs per boss and 1 to 3 per crab and a 60 s lifetime (`Cfg:94`) plus 25 s dawn keep, the number of simultaneous animated orbs scales with kill rate; no cap on `#drops`.
- Fix: bob with client-side tweening (set once), cap the orb count, merge small Shell orbs.

### GP-41 - Remote/attribute traffic inventory (SUSPECTED, Low)
Server -> client sources (event-driven unless stated): `PlaySound` `FireAllClients` per crab kill (`CS:284`), per player bite/slam (`CS:275`), per cannon shot x2 (`DS:212,234`), per weapon shot/hit (`Main:473,540`), repair/refuel/build. Arithmetic upper bound for cannons: 6 pads x L3 cooldown 1.2 s = 5 shots/s = 10 events/s. `GearData` (full JSON profile) on every profile change including each loot pickup (`PD:96-99`, `LO:164`). `Notify` per cannon destroyed/built, boss kill, rare loot, trader sale. GameState attributes: `TimeLeft` 1 Hz, `Fuel` up to 5 Hz while changing (`LS:300-303`), `Integrity` on each integer change, `DarkSeconds` 5 Hz in the dark, boss entry `Health` per integer change (up to once per frame while burned). Replicated parts: every creature `PivotTo` per frame, loot orbs per frame (GP-40).
- Fix: throttle `PlaySound`, batch `GearData`, rate-limit boss attribute writes.

### GP-42 - Run-to-run leaks (VERIFIED WORKING, Info)
- Checked: creatures (`removeAt` destroys model, schedules `bossEntry` destroy, `CS:303-348`), loot (`LO:145-148`, `clearAll`), cannons (`DS:400-420`), tweens/flash parts (destroyed on `Completed`), spawn tasks (`active=false`, `GS:159-161`), boss delays (phase/night guard `GS:427-429`), `LampService.heldThisRun` cleared on reset (`LS:237`), per-player tables cleared on `PlayerRemoving` (`Main:545-547,614-616,832-835`, `ShopService:222-226`, `LoadoutService:91-94`, `PD:323-331`). Client: boss bars removed on ChildRemoved (`Hud:1123-1127`); Results/Bench/Trader loops are persistent single instances.
- Small unbounded structures (Info): `EventLog.devices/routes/marks` keyed by userId never removed (`EventLog:18-24`); `LampService.heldThisRun` holds leaver Player objects until the next reset (`LS:43`); `LoadoutService.handled` (GP-30); `GS:482` `task.delay(tideCollect)` is not cancelled (a delayed tide after an abandoned day could fire in the next run's early phase; impact tiny since `resetRound` clears orbs first).

---

## 10. Mobile HUD, input, controller

### GP-43 - TouchControlsEnabled is set by two scripts with different rules (VERIFIED BROKEN, Medium)
- Evidence: `CMain:117-119` sets `TouchControlsEnabled = enabled and not MenuOpen` when entering/leaving the Keeper view; `UiKit:307-318` `refreshModal` sets `TouchControlsEnabled = not anyOpen` on every push/pop of any modal (bag, shop, bench, trader, results).
- Scenario: phone Keeper taps the round bag (bag button stays visible while Keeper, `Inventory:945-1019`) or a results screen pops while Keeper; on close, `refreshModal` forces the joystick and jump button back on over the aiming thumb. Also the reverse: leaving the lamp while a modal is open leaves controls off until the modal closes.
- Fix: one owner for the flag (ref-count "reasons to hide": keeper, modal) instead of each script writing it.

### GP-44 - Controller can take the lamp but cannot run it (VERIFIED BROKEN, Medium)
- Evidence: Keeper input handlers `CMain:175-197` only handle `MouseMovement`, `Touch`, keyboard Q/F; no thumbstick, no gamepad buttons for focus/leave (`Hud:521-526` are GUI buttons; `Hud:939-941` clears all prompt cards for the Keeper). The console prompt is operable by gamepad (default ButtonX). Docs list "none yet" for controller aim (progress.md 7).
- Scenario: a gamepad player triggers the console; the camera is scripted overhead (`CMain:122-128`), WalkSpeed 0 (`LS:178`), prompts hidden, no aim; only the idle release (25 s, GP-3) frees them. During that time the lamp is on a non-rotating manual aim (the beam stops sweeping: `LS:256-263` only turns toward `targetAngle`).
- Fix: bind a thumbstick to aim, a button for focus, B for leave; or refuse the console to gamepad users until supported.

### GP-45 - Gamepad strike target (SUSPECTED, Medium)
- Evidence: `CMain:215-228` sends `mouse.Hit.Position` on `Tool.Activated`. With a gamepad the engine mouse has no meaningful pointer; progress.md claims "Strike: R2" but the aim point comes from the Mouse object.
- Fix: for gamepad aim at the closest creature in front, or the camera centre ray.

### GP-46 - Hybrid devices (SUSPECTED, Low)
- `Hud:1215-1219`, `Inventory:997`, `CMain:26-29` use `TouchEnabled and not KeyboardEnabled` for "touch". A touch laptop or an iPad with a keyboard is classed as keyboard: HUD shows PC layout/key chips while Roblox draws touch controls; `ReportDevice` logs "Keyboard".
- Fix: decide per last input type, as `Hud:537-545 inputMode` already does for key hints, and place buttons using both signals.

### GP-47 - Phone HUD pixel zones (UNTESTED, Medium)
- Evidence: `Hud:1921` `leftEdge = 270` ("Roblox's own top-bar buttons end about here"), `UiKit:279-282` reserved corners 260x220 / 220x220, `Hud:1285` prompt strip starts at 40% width and sits 92 px above the bottom, `Inventory:998-1008` bag at fixed offsets from the jump button, `Hud:1962` Shells lift 100/228. All derived from emulator screenshots and one owner phone; docs record "Not verified: weapon-slot tap and the bag position on a real phone".
- Observation (resolved, no bug): the keeper row shares the bottom container with prompt cards, but `Hud:939-941` hides all prompt cards for the Keeper, so the two cannot overflow each other.
- Fix: device test matrix (small Android, iPhone with notch, tablet) with the Studio simulator attribute only as a first pass.

### GP-48 - Phone control paths (VERIFIED WORKING, Info)
- Tap-to-strike via `Tool.Activated` (`CMain:217-228`, blocked while `MenuOpen` or Keeper), touch aim via `InputBegan/Changed` ignoring GUI-processed touches (`CMain:181,190`), 20 Hz aim send (`CMain:92,202-208`), weapon slot toggle (`Hud:1702-1720`), bag button (`Inventory:991-994`), prompt cards drawn custom and pressable (`Hud:982-995`). `Hud:862-865` restyles every ProximityPrompt in Workspace (and each new descendant: a callback per instance created, cheap but frequent: creature clones, orbs, projectiles).

---

## 11. Dead code and config traps

### GP-49 - Dead Config and disabled script (VERIFIED BROKEN, Low)
- Config keys never read by any script (grep over Server/Shared/Client): `SEA_GLASS_VALUE` (Cfg:89), `BLACK_PEARL_VALUE` (Cfg:91), `CRAB_HEALTH`, `CRAB_SPEED`, `CRAB_TOWER_DPS`, `CRAB_ATTACK_RANGE`, `CRAB_PLAYER_DAMAGE`, `CRAB_ATTACK_INTERVAL`, `CRAB_CANNON_DPS`, `LOBBY_SHOP_SIDE`. Real values live in `Items.shellValue` (`Items:119,127`) and `Shared\Creatures`. progress.md section 5 lists `SEA_GLASS_VALUE / BLACK_PEARL_VALUE 33 / 130` as live Config; editing them changes nothing, and the "Gameplay numbers need a yes" rule makes silent no-ops dangerous.
- `Client\Gear.client.luau`: `Disabled: true` in `Gear.meta.json`; legacy GEAR panel whose buy/equip remotes (`GearAction` actions) are no longer handled (`PD:310-316` only accepts "sync"). Delete or keep disabled deliberately.
- Stale comment `CS:49` ("boss bar reads BossName / BossHealth / BossMax") and `CS:394-397` legacy attributes (GP-13).
- Also `PD:317` `lastAction` is allocated but never used; `Main:84` etc fine.

### GP-50 - Unthrottled remotes (SUSPECTED, Low)
- `GearAction("sync")` (`PD:310-316`) runs `snapshot` (JSON encode+decode), a `FireClient`, and `syncGear` per call with no limit; `SetReady(false)` (`Main:87-99,639-643`) logs, teleports and spawns a task per call (self-inflicted); `ReportDevice` logs a line per call (`EventLog:142-145`); `EnterLobby` is guarded.
- Fix: per-player cooldowns (as already done for shop/trader/loadout).

### GP-51 - syncGear and dead humanoids (SUSPECTED, Low)
- `Main:427-429` sets `humanoid.Health = math.max(1, armor.maxHealth * ratio)` on every profile change; when the humanoid is dead (`Health` 0) this assigns 1 (the engine most likely keeps it dead; not verifiable here). Profile changes reach dead players (Pearl payout `GS:520` on a dead voter).
- Fix: skip when `humanoid.Health <= 0`.

### GP-52 - EVENT_LOG_ENABLED (VERIFIED WORKING, Info)
- Cfg:162 true, with the comment "turn off before launch". Every event prints to the server log (kills are counted, not printed). Left on in the live build.

---

## 12. Doc claims vs code

| Claim (docs) | Code | Verdict |
|---|---|---|
| Fuel "scaled by crew size" (progress.md 4) | `LS:284` counts all players (GP-2) | mismatch |
| `SEA_GLASS_VALUE` / `BLACK_PEARL_VALUE` 33 / 130 in Config (progress.md 5) | unused; real source `Items.shellValue` (GP-49) | mismatch |
| "1-4 players" | no cap (GP-25) | mismatch |
| Bosses "nights 4, 7, 10 and 13 (one each)" | `GS:361-378` | matches |
| Pearls "1 per night survived, +5 for a win = 18" | `GS:507-524`, Cfg:17-19 | matches; defeat pays N-1 |
| Boss Pearl drop "50% chance of 2-4" | `LO:126-127` | matches (collected by one player only; lost to the tide) |
| "Quitting / disconnect" not described | no reward (GP-24) | docs silent; behaviour is harsh |
| "Cannons: oil or Fire Shell crates" | crates override and wipe (GP-15) | partly true |
| Prices 30/35/60/140/140/8/25/40/60 | `Items:43,51,59,79,89,101,149,158,167` | matches |
| Cannon costs 40/70/110 | Cfg:100 | matches |
| Swarm 42+16*growth x 40/65/85/100% | `GS:410-412`, Cfg:124-127 | matches; crab count not scaled |
| Night bonus "about 1,180" | 13 x 91 = 1183 | matches |
| Skitters "drop 1 Shell 20%" (IMPLEMENTATION_LOG) | Cfg:129 0.26 | log outdated; progress.md says 26% |
| Storm Harpoon "same damage" | 9 vs 8 (GP-18) | docs already flag |
| "Server perf: 0.11 ms/frame, about 50 KB/s per player" | not derivable from code; measured solo in Studio | UNTESTED at cap/4 players (GP-37) |
| "Lamp shift... untested" | consistent (GP-35) | accurate |
| progress.md 14c #1 "touches GameState, CreatureService and HUD boss bars" | also `LootService`, Config, legacy boss attributes, `findTarget` (GP-11) | incomplete |
| "Nothing is half-built" | `Gear.client` disabled legacy, dead Config keys (GP-49) | minor |
| Controller: "no aim, no focus/leave" | `CMain:175-197` (GP-44) | accurate, and the lamp is takeable (trap) |
| Hotbar replaced; weapon slot "1 / D-pad down", bag "B / D-pad up" | `Hud:1725`, `Inventory:1035` | matches |
| Run length "about 27 minutes" | 13 x 120 s = 26 min plus opening | matches |

---

## 13. Reference tables (arithmetic from code)

Per-night creature counts (no forecast; formula `GS:402-413`; growth = night-1 up to night 3, then 2 + (night-3)*0.5; final-night crabs x1.5 floor):

| Night | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Crabs | 14 | 22 | 30 | 34 | 38 | 42 | 46 | 50 | 54 | 58 | 62 | 66 | 105 | 621 |
| Skitters, crew 1 | 17 | 23 | 30 | 33 | 36 | 39 | 42 | 46 | 49 | 52 | 55 | 58 | 62 | 542 |
| Skitters, crew 2 | 27 | 38 | 48 | 53 | 59 | 64 | 69 | 74 | 79 | 85 | 90 | 95 | 100 | 881 |
| Skitters, crew 3 | 36 | 49 | 63 | 70 | 77 | 83 | 90 | 97 | 104 | 111 | 117 | 124 | 131 | 1152 |
| Skitters, crew 4 | 42 | 58 | 74 | 82 | 90 | 98 | 106 | 114 | 122 | 130 | 138 | 146 | 154 | 1354 |

Spring tide (x1.4 crabs and skitters): crabs total 870, skitters (crew 4) 1896. Night-13 crabs (1.4 x 70 = 98, x1.5 = 147) is included in the 870.

Fuel (wide beam, 90 s night, 1.2/s base): factor 0.7 -> 75.6 (1.89 barrels), 0.85 -> 91.8 (2.3), 1.0 -> 108 (2.7). Focused all night: 189 / 229.5 / 270 (4.7 / 5.7 / 6.75 barrels). Full tank wide 100/1.2 = 83 s; focused 100/3 = 33 s; Overcharged beam focus 2.25/s.

Spring-tide, leaky stores and fog only change one factor each (`Forecasts`).

---

## 14. Suggested order (no code proposed)

1. Pearl payout fairness (GP-23, GP-24) and the crew cap (GP-25) before any publicity: they affect every run and every public server.
2. Decide the economy direction before the merchant (GP-21) so the new sink is sized from the numbers above.
3. Before bosses-by-crew (GP-11/12/13/14): remove the legacy boss attributes, replace the stepping rule with an explicit list, raise or remove `MAX_BIG_PER_RUN`, and re-balance tower DPS.
4. Keeper input: held-aim idle (GP-3), `TouchControlsEnabled` ownership (GP-43), controller bindings (GP-44/45).
5. Fix the cannon ammo overwrite (GP-15) and `BuyUpgrade` validation (GP-19).
6. Profile with 4 clients at the 45 cap (GP-37) and add the traffic throttles (GP-39/40/41) only if the measurements need them.
=== END FILE ===

