# Smallest safe validation improvements: SEC-5, SEC-6, SEC-8, SEC-9 (and SEC-15) — design only

Source-confirmed facts are separated from facts that need an isolated reproduction (section 6). No code was changed.

## SEC-5: repair, oil and refuel prompts have no server cooldown or phase check
Source: `TowerService.luau:26-38` (repair), `Main.server.luau:204-231` (oil, refuel). None checks `Ready`, the phase, or a per-player cooldown. Prompt hold times: oil 0.5 s and refuel 0.5 s (`IslandBuilder.luau:248, 287`), repair `Config.REPAIR_HOLD_SECONDS` (`:253`).
**Smallest fix:** one helper `cooldownOk(player, key, seconds)` (table of last-use times, cleared on `PlayerRemoving`). Use about 0.4 s for oil and refuel (a bit under the 0.5 s hold, so honest play is never blocked) and a fraction of `REPAIR_HOLD_SECONDS` for repair. Also require `Ready` and a run phase (Prologue, Day, Night).
**What it stops:** executor-style repeated prompt firing that ignores the hold time. **What it does not stop:** a player legitimately holding the prompt, and spoofed position (see SEC-6).

## SEC-6: client-reported position is trusted
Source: loot magnet and pickup use `HumanoidRootPart.Position` of every living player (`LootService.luau:233-241`, `:257`); `Attack` clamps range from the client's own root position (`Main.server.luau:528-531`); Trader/shop distance checks use the same position. Roblox lets the owning client move its own character, so any server check based on that position is only as honest as the client.
**Smallest fix (phase 1):** in the LootService heartbeat list, include only players with `Ready == true` (a one-line condition at `:237`). This keeps boss Pearl drops and shared Shell pickups to the crew, which removes the "outsider teleports in and steals the drop" case without any new tracking.
**Optional phase 2 (needs a test before shipping):** a server-side movement sanity check, sampling each crew member's position about once per second and ignoring pickups/attacks for a player whose displacement exceeds roughly `3 x WalkSpeed x dt` plus a margin. This can create false positives (knockback, ship rowing, `PivotTo` teleports by the server itself, which must be excluded), so it ships only after the test plan covers it.

## SEC-8: `GearAction "sync"` is unthrottled
Source: `PlayerData.luau:310-316`. Each call runs `push()` which JSON-round-trips the whole profile (`snapshot`, line 83) and fires a remote.
**Smallest fix:** a per-player `lastSync` time; ignore calls closer than 1 s apart. Clear on leave.

## SEC-9: `BuyUpgrade` can be fired from anywhere by anyone
Source: `Main.server.luau:116-145`. Only a 0.3 s per-player throttle and type checks. `UpgradeService.buy(id)` takes no player argument, so it spends the crew's shared Shells.
**Smallest fix:** require `Ready` and a run phase, and require a recent bench interaction: when `refs.upgradePrompt.Triggered` fires (`Main.server.luau:69-70`, which already sends `OpenUpgrades` to that client), record `benchOpenUntil[player] = os.clock() + 120`. `BuyUpgrade` is accepted only while that time is in the future. This ties purchases to a genuine server-observed prompt activation instead of trusting position.

## SEC-15: infinite coordinates in `Attack`
Source: `Main.server.luau:500` rejects NaN but not infinity; `offset.Unit` of an infinite vector is NaN, so the clamped target becomes NaN (`:529-531`).
**Smallest fix:** also reject any component with `math.abs(c) > 1e5`.

## 5. Acceptance criteria (for the later implementation)
1. A scripted burst of 50 prompt fires in one second yields at most the cooldown-allowed number of effects (checked in the isolated harness by calling the handlers directly).
2. Honest play: holding a prompt for its normal hold time is never rejected.
3. A non-crew player standing on the loot never receives a Pearls drop.
4. `sync` called 30 times in one second causes one push.
5. `BuyUpgrade` from a player who never used the bench prompt is rejected; from one who did within 120 s it succeeds.
6. `Attack` with `Vector3.new(math.huge, 0, 0)` is ignored.
7. All existing handlers still pass the manual checklist in the test plan.

## 6. What is source-confirmed and what needs reproduction
| Item | Source-confirmed | Needs reproduction |
|---|---|---|
| SEC-5 no cooldown / phase check | yes (code read) | whether exploit tooling really fires `Triggered` without the hold on live servers |
| SEC-6 trusts client position | yes | how far a spoofed position works against loot/range (needs a harness that moves a test character) |
| SEC-8 no throttle | yes | server cost per call under spam (needs a profile) |
| SEC-9 no gate | yes | nothing needed to confirm the gap |
| SEC-15 NaN target | yes (arithmetic on `Vector3`) | confirm that `damageArea` with a NaN target does nothing harmful |
