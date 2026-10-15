# Final publication clearance (Lighthouse Keepers), 2026-10-15

- **Target:** PlaceId `132065051336560`, GameId `10769064643`. **Not published**: the owner publishes manually.
- **Scope:** the auditor's final verdict on `305e5b2`. FIX 1 was approved. This clearance adds FIX 2 (the countdown race) and the focused 2-crew, 4-spectator fuel test.
- **Safety:**
  - Studio API access was checked OFF before every Play. All six test players showed `ProfileState=memory`, and the server printed "Progress is kept in memory only".
  - No changes to PlayerData or saves. SaveTest and Outlaw City were untouched, and nothing was published.

## Exact final script hashes (Studio = git = reviewed build)
These were computed in Studio with an in-place SHA-256 and match the files in `src/` and `after/`. All seven compile.

| Script | SHA-256 |
|---|---|
| `ServerScriptService.Server.GameState` (FIX 2) | `e6614062a62dfca6b9ff611929e87456d931e3de5fecc2dd52d95a81b4e4c489` |
| `ServerScriptService.Server.ShipDeparture` (FIX 2) | `c832d490b3ee6ae65f65e25da398dd4378a98d78e379922184583b9a7e6c225a` |
| `ServerScriptService.Server.ShipRoster` (FIX 1) | `85c418b1dfcf56491d6e230aa577d52f803dec5744f507b41834ddd43ca748d9` |
| `ServerScriptService.Server.ShipBoarding` | `54f56dfd605e201a01b6df1e21e0998207bbe499b397f86e431fffb0466c14fe` |
| `ServerScriptService.Server.Main` | `b7a10a5c2e793d91a303b80ceac89eff9a4ffadb1bbd13669a1681a5c803fa16` |
| `ServerScriptService.Server.LobbyBuilder` | `46c4e06840e002f2de8e52b07bb57884d923ecbba14e83dec476c5c464e1eddf` |
| `StarterPlayerScripts.Client.Departure` | `d8f905a2d726d74b4904cc66b10ac347d945cd55e55bdedd8e7a30e61af36cd1` |

The batch 1 control scripts (`Client.Main`, `UiKit`, `Coach`, `LampService`, `Config`) and `PlayerData` are unchanged since the batch 1 builds the owner tested.

## FIX 2: countdown-completion race (`FIX2_COUNTDOWN_DIFF.diff`)
- **Backup:** `ServerStorage.Backups.CountdownFix_before_2026-10-15` (GameState and ShipDeparture).
- **Reproduced before the fix**, using the real GameState countdown code taken from Studio. In a 4/4 automatic departure where one member leaves during the last 0.2 s wait, the result was: "countdown completed=true, request after leave=false, **launched 3 players**".
- **Change** (smallest reversible):
  1. `countdown()` checks `shouldStop()` **before** `left <= 0`.
  2. GameState revalidates the request immediately before `departShip()`: `if countdown(...) and departureRequested() then`. There is no yield in between.
  3. `ShipDeparture.requested()` runs `evaluate()` first. So an automatic departure below 4/4, a SAIL NOW whose initiator left, or an empty party is cancelled at that moment. An automatic departure can never launch fewer than 4 unless a separate, still-valid manual request exists.

```diff
 			state:SetAttribute("TimeLeft", math.max(0, math.ceil(left)))
-			if left <= 0 then
-				return true
-			end
+			-- stop is checked BEFORE completion, so a cancel during the last wait is never reported as done
 			if shouldStop and shouldStop() then
 				return false
 			end
+			if left <= 0 then
+				return true
+			end
...
-		if countdown(Config.INTERMISSION_SECONDS, departureCancelled) then
+		-- the request is revalidated once more right before the party is frozen (no yield in between)
+		if countdown(Config.INTERMISSION_SECONDS, departureCancelled) and departureRequested() then
...
+-- Revalidates before answering: an automatic departure below 4/4, a SAIL NOW whose caller left, or an empty
+-- party is cancelled here, so GameState never launches on a request that is no longer valid.
 function ShipDeparture.requested(shipId)
+	ShipDeparture.evaluate(shipId)
 	return requests[shipId] ~= nil
 end
```

- **Countdown edge-case result:** the harness runs the real fixed countdown from Studio with a 1.0 s countdown, `departShip` gated exactly as in GameState.

| Case | Result |
|---|---|
| 4/4 automatic, one member leaves at 0.81 / 0.90 / 0.95 / 0.99 / 1.00 s | 0 launched in each (PASS) |
| SAIL NOW 2/4, initiator leaves at 0.90 / 0.99 s | 0 launched (PASS) |
| SAIL NOW 2/4, the other member leaves at 0.95 s | The valid manual departure launches the 1 remaining member (PASS) |
| 4/4, nobody leaves | Exactly 4 launch, once, and the request is used up (PASS) |
| SAIL NOW 3/4, nobody leaves | Exactly 3 launch, once (PASS) |
| 30 repeats of the final-instant cancels (4→3 and initiator, at 0.95 / 0.99 / 1.00 s) | 0 launches (PASS) |
| Leave just **after** expiry (1.02 s), 8 runs | Never a partial launch: either nobody, or the whole party frozen before the leave. The leave is then a mid-voyage leave. (PASS) |

  In one first-pass case (initiator leaves at 1.05 s) "2 launched" was reported as a failure. That expectation was wrong: the 1.0 s countdown had already frozen the party before the leave. It was replaced by the after-expiry rule above.
- **No timers or balance values were changed.** `INTERMISSION_SECONDS` is still 10.

## Focused six-client test: two crew, four spectators (owner's Studio session, server read directly)
Server events (from the test server's log):
- `PlayerReady Player1 via=deck` at 44.4 s and `PlayerReady Player2 via=deck` at 53.5 s.
- **No departure until `DepartureStarted by=Player1 crew=2 mode=manual` at 95.7 s**, 42 s at 2/4 with no automatic countdown.
- `RunStarted players=2`.
- `landed` for Player1 and Player2 only.
- A second cycle after results: both players chose the menu (`Rematch playAgain=0`), boarded again, `DepartureStarted by=Player2 crew=2 mode=manual`, and `RunStarted players=2`.
- During that voyage, `CrewRefused Player3 reason=sailed` and `CrewRefused Player6 reason=sailed`: harbor spectators on the ship were not added.

Server state (read-only) during the voyage:
- Player1 and Player2: `Ready=true ShipId=Ship1`, on the island (z≈16–27).
- Player3 to Player6: `Ready=false ShipId=nil`, in the harbor (z≈501–518).
- `Ship_Ship1_Count=2`, `Locked=true`.
- Sampled continuously, **no spectator was ever Ready**.

## Fuel multiplier evidence
Formula (`LampService`): `rate = 1.2 × (focused ? 2.5 : 1) × FUEL_DRAIN_BY_CREW_SIZE[Ready count] × ForecastFuelMult`, with `FUEL_DRAIN_BY_CREW_SIZE = {0.7, 0.85, 1, 1}`. No Overcharged evolution was active (`Evo_OverchargedBeam=false`).

| Window | Beam | Forecast mult | Ready | Measured | Expected, 2 crew | Expected if 6 counted |
|---|---|---|---|---|---|---|
| Run 1 storm opening, 10 one-second samples (integer fuel, ±1 unit) | wide | 1.00 (Spring Tide) | 2 | 10 units / 10.1 s ≈ **0.99 /s** | 1.020 /s | 1.200 /s |
| Run 2 Night 1, exact unit changes over 19.63 s | wide | 1.25 (Leaky Stores) | 2 of 6 | 25 units / 19.63 s = **1.273 /s** | **1.275 /s** | 1.500 /s |

The night measurement matches the 2-crew multiplier (0.85) to within 0.2%, and is 15% below what a 6-player count would give. The spectators never became Ready, so they cannot affect the multiplier.

## Within their actual scope (not new six-client results)
- **Solo SAIL NOW:** tested in one-client Studio Play with a real key press. Solo voyage, `RunStarted players=1`.
- **Initiator walk-off during SAIL NOW:** one-client Play (`DepartureCancelled`, back to Waiting) plus the unit tests and FIX 2 harness above.
- **Controller and phone:** owner-tested in batch 1 ("All working"). The code is unchanged since then and was not re-tested here.

## Known limitations
- One ship and one island: while a voyage is at sea, harbor players cannot start another one ("At sea · next voyage soon"). Multiple ships come with the voyage-server plan; the owner's idea of a fresh ship appearing is recorded there.
- `TimeLeft` keeps its last value after a cancelled countdown. It is only displayed while a departure is active, so nothing visible is affected.
- A player who steps off within the last second is still in the frozen party: the 1 s exit grace counts them as crew at lock time. The party is still valid (all frozen members are registered), so this is not a partial launch.
- On phones the crew card's help line is hidden. SAIL NOW is explained by the wheel sign and the prompt.

## Confirmation
The code in Studio matches the reviewed build: the hashes above were verified in Studio after the final edit and equal the committed files. **Clearance status: ready for the owner's manual publish of Lighthouse Keepers**, subject to the auditor's acceptance of FIX 2 and this evidence. Nothing has been published.

## Auditor verdict (2026-10-15, on commit 86db39f)
**APPROVED FOR MANUAL PUBLISH.**
- FIX 2 was accepted.
- The multiplayer fuel test was accepted: 1.273/s measured against 1.275/s expected for 2 crew.
- FIX 1 was approved earlier.
- The known limitations are documented and are not blockers for a friends-only test build:
  - one voyage per server;
  - the 1 s exit grace at lock time.
- Next priority after publishing: feedback from friends (confusing UI, combat responsiveness, onboarding, bugs, difficulty).

**Pre-publish identity check (read-only, after the verdict):**
- The open Studio window is "Lighthouse Keepers - Staging", PlaceId 132065051336560, GameId 10769064643.
- All 7 scripts MATCH the hashes above.
- The Studio API probe was rejected: access is OFF.
- The owner saves a fresh local backup (`v158_pre-publish`) and then publishes manually.
