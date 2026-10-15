# Crew cap, crew fuel and server validation: confirmation and revisions (TASK-004) — design only

The auditor supports a server-enforced maximum of four active crew and fuel scaling by active crew. Both are unchanged from `TASK-003/CREW_CAP_AND_FUEL_DESIGN.md`. This file adds the requested test coverage and revises the validation design. No implementation is authorized.

## 1. Definitions
- **Active crew** = players with `Ready == true` and connected. The cap counts exactly these.
- **Spectator / harbor player** = connected, `Ready == false`, ashore. They never count for crew size, swarm scaling, fuel scaling, loot, Pearls or bench access.

## 2. Test coverage required for the cap and fuel (added to the matrix as C/F rows)
| ID | Scenario | Expected |
|---|---|---|
| CC1 | Full crew of 4, a 5th player uses the wheel | stays ashore, "ship is full", `Ready` unchanged, crew count 4 |
| CC2 | Full crew, two players press the wheel in the same frame | exactly one slot fills if one is free; no overshoot (join check and set run without a yield) |
| CC3 | First-voyage joiner arrives while the ship is full | routed to the harbor or title, no error, no half-joined state, coach not started |
| CC4 | A crew member leaves mid-run (disconnect, wheel, menu) | slot frees; a harbor player can join mid-voyage and is rowed out; crew never exceeds 4 |
| CC5 | Mid-run replacement earns correctly | eligible from the next night start (Pearl rule) |
| CC6 | Spectators in the harbor: 0, 2, 4 extra connected players | crew size, swarm share and fuel multiplier depend only on active crew |
| CC7 | Crew drops from 3 to 2 during a night | fuel multiplier changes at the next drain tick, no negative or nil index |
| CC8 | `Ready` set again for an already-Ready player | idempotent, no double count |
| F1 | Fuel multiplier equals `FUEL_DRAIN_BY_CREW_SIZE[crew]` for crew 1 to 4 | verified by reading the lamp state in an isolated run |
| F2 | Swarm scaling and fuel use the same crew number | same value at the same tick |
The harbor-spectator and first-voyage rows must use real clients in the test universe (Studio "Clients: N" for logic, plus real devices for the first-voyage path, because first-voyage routing depends on the profile load).

## 3. BuyUpgrade (SEC-9, revised)
Require **all** of:
1. **Authorized bench interaction:** the server records `benchSession[player] = { expiresAt = os.clock() + 120 }` only when `refs.upgradePrompt.Triggered` fires for that player (`Main.server.luau:69-71` already sends `OpenUpgrades` there). Cleared on `PlayerRemoving`, on phase end and on leaving the crew.
2. **Present-time proximity:** at `BuyUpgrade` time the player's root part must be within `bench.MaxActivationDistance + 8` studs of the bench part. Position is client-reported, so this is defence in depth against pure remote spam and absurd distances, not proof against a determined position spoofer (a spoofer who stands at the bench can still buy; the harm is limited to spending the crew's shared Shells).
3. **Phase and crew eligibility:** `Ready == true` and phase in Prologue, Day or Night, never in Results or the harbor.
The existing 0.3 s throttle and argument checks stay.

## 4. Repair, oil and refuel prompts (SEC-5, revised)
What is verifiable: `HoldDuration` values in the source are oil 0.5 s, refuel 0.5 s, repair `Config.REPAIR_HOLD_SECONDS = 1.5` s (`IslandBuilder.luau:248, 253, 287`; `Config.luau:111`).
- The Roblox reference pages I could read do not state on which side `PromptButtonHoldBegan` and `PromptButtonHoldEnded` fire, and they say nothing about server validation of distance. **I therefore do not claim a server-verifiable hold timer.** This is test V0 in the matrix: connect a server Script to those events in the test universe and see whether they fire for a real client.
- **If the hold events fire on the server:** record `holdBeganAt[player]` and, on `Triggered`, require `now - holdBeganAt >= 0.8 x HoldDuration`.
- **Regardless of V0, a per-player per-prompt cooldown of `0.8 x HoldDuration` is safe for honest players**, because an honest player can never complete a hold faster than `HoldDuration`. That alone removes burst spam.
- Also require `Ready`, run phase, and server-side distance to the prompt part <= `MaxActivationDistance + 8` (same position caveat as above).
- Honest-play regression: holding a prompt for its normal time is never rejected; a key-repeat or lag spike that completes two holds closer than 0.8 x HoldDuration is rejected, which is acceptable.

## 5. Retained as proposed
- `GearAction "sync"`: at most one push per player per second.
- Crew-only loot: only `Ready` players in the pickup list (`LootService.luau:233-241`).
- Non-finite attack rejection: reject any component that is NaN, infinite or has `math.abs(c) > 1e5`.
- **No movement anti-cheat** (speed or teleport checks) is part of this design, because the false-positive risk for legitimate players (knockback, ship transfers, server-side `PivotTo`) outweighs the benefit.

## 6. Validation tests (additions)
| ID | Scenario | Expected |
|---|---|---|
| V0 | Do hold-began/hold-ended events fire on a server Script? | documented as yes/no with evidence; decides section 4 |
| V1 | 50 `Triggered` calls in one second against each prompt | at most the cooldown-allowed number of effects |
| V2 | normal holds at the intended pace | none rejected |
| V3 | `BuyUpgrade` without a bench session | rejected |
| V4 | `BuyUpgrade` after the session expired (121 s) | rejected |
| V5 | `BuyUpgrade` from outside the proximity radius with a valid session | rejected |
| V6 | `BuyUpgrade` from a spectator or during Results | rejected |
| V7 | non-crew player over a boss Pearl drop | never collects |
| V8 | `sync` x30 in one second | one push |
| V9 | `Attack` with infinite or NaN components | ignored, no error |
