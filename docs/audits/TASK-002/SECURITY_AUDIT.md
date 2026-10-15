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
