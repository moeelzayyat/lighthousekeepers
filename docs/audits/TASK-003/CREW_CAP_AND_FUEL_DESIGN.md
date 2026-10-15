# Four-player crew cap and crew-only fuel scaling (GP-25, GP-2) — design only

## 1. Verification against source
| Claim | Evidence | Status |
|---|---|---|
| The 1-4 crew limit is not enforced | `joinCrew` (`Main.server.luau:646-657`) sets `Ready = true` with no count check; callers are the ship's wheel (`:660-672`) and the first-voyage route (`chooseRoute`, which calls `joinCrew`). `readyPlayers()` (`GameState.luau:101-109`) returns every Ready player. | CONFIRMED BY SOURCE. Whether Roblox's place max-players setting already stops a fifth player from joining the server is a Studio/website setting I did not inspect (UNTESTED). Even if it caps the server at 4, the cap is a server rule, not a crew rule, so harbor players beyond the crew would still be counted by GP-2. |
| Swarm scaling silently clamps at 4 | `GameState.luau:410`: `math.clamp(#readyPlayers(), 1, 4)`. A 5th crew member adds players but no extra scaling. | CONFIRMED BY SOURCE |
| Fuel drain counts everyone on the server | `LampService.luau:284`: `math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)`. Every connected player is counted, including harbor and title-screen players, while the swarm uses `readyPlayers()`. | CONFIRMED BY SOURCE |
| Effect size | `FUEL_DRAIN_BY_CREW_SIZE = {0.7, 0.85, 1, 1}`. A solo crew on a server with 3 other players in the harbor drains at 1.0 instead of 0.7 (about 43% faster). Two crew plus 2 harbor players drain at 1.0 instead of 0.85. | ARITHMETIC FROM CONFIG, no run observed |

## 2. Proposed change (smallest safe)
**Crew cap**
- Add `Config.MAX_CREW = 4`.
- In `joinCrew`, before `SetAttribute("Ready", true)`, count Ready players. If the count is already `MAX_CREW` and this player is not already Ready, send "The ship is full" through the existing notify path and return without setting `Ready`. The check and the set run without a yield, so two simultaneous joins cannot both pass (Luau's cooperative scheduling).
- The first-voyage fast path (`chooseRoute`) must fall back to the title/harbor when the ship is full instead of failing silently; the player can use the wheel when a slot opens.
- When a crew member leaves mid-run, the slot opens and a harbor player may join mid-voyage as today.
- Recommendation for the owner: also consider setting the Roblox server size to match what the lobby needs; that is a website setting and is out of scope.

**Fuel scaling**
- Replace `#Players:GetPlayers()` at `LampService.luau:284` with the number of players whose `Ready` attribute is true (the same predicate used in `LampService.luau:383`). No new state is needed.
- Behaviour note: this restores the documented intent ("smaller crews burn less fuel") but it changes difficulty on busy servers. A small crew on a busy server gets easier; nothing gets harder. This is a **balance-visible change and needs owner approval**.

## 3. Acceptance criteria
1. With 4 crew present, a 5th player using the wheel stays ashore, gets the "ship is full" message, and `readyPlayers()` returns 4.
2. A first-voyage player arriving at a full ship lands in the harbor/title flow with no error.
3. Crew leaves mid-run, then a harbor player joins: join succeeds, and a 5th crew member is rejected.
4. Fuel drain rate multiplier equals `FUEL_DRAIN_BY_CREW_SIZE[crew]` for crew 1, 2, 3, 4, independent of how many non-crew players are connected (checked by reading `LampService` state in an isolated run, see test plan).
5. Swarm scaling still uses the same crew number as fuel.

## 4. Risks and compatibility
- A player stuck outside while the crew is full might want a spectator or queue; not in scope.
- No saved data is touched. Rollback is a code revert or `MAX_CREW = 99`.
