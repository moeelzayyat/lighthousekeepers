# Final departure publication report (Lighthouse Keepers), 2026-10-15

- **Target:** PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.**
- **Builds on:** the departure revision `5de5724`, conditionally accepted by the auditor, plus **one bug fix** found in the owner's six-client test (FIX 1 below).
- **Safety:** Studio API access was checked OFF immediately before every Play, including before the owner's multi-client sessions. PlayerData, saves, SaveTest and Outlaw City were not touched, and nothing was published.

## Six-client acceptance results (observed by the owner, Studio Test > Clients and Servers, 6 players)
| # | Check | Observed | Verdict |
|---|---|---|---|
| R1.1 | 1 aboard, no E, wait 15 s | No countdown | PASS |
| R1.2 | 2 aboard, no E, wait 15 s | No countdown | PASS |
| R1.3 | 3 aboard, E held (SAIL NOW) | Countdown started | PASS (3-player SAIL NOW) |
| R1.7 | 5th and 6th walk aboard | "Crew full", not in the crew | PASS |
| R1.8 | Departure | Only P1–P4 went to the island; P5 and P6 stayed in the harbor | PASS |
| R2.1 | 4 aboard, no E | Automatic countdown started | PASS |
| R2.2 | One of 4 walks to the pier | Countdown stopped, back to 3/4 | PASS |
| R2.3 | Walks back on | Countdown restarted from 0:10 | PASS |
| R2.4 | Who sailed | All four | PASS |
| R2.5 | Voyage UI | The crew saw the crew-only panel; harbor players kept the Roblox list | PASS |
| R2.6 | SAIL NOW for non-members | P5 and P6 saw no "Sail now" prompt | PASS |
| R3.1 | Results: 2 pressed Play Again, 2 went back to the harbor | The harbor pair returned; the Play Again pair got a countdown and sailed together | PASS (rematch opt-in; declining frees the seat) |
| R3.2 | Harbor during a voyage | Sign shows "At sea · next voyage soon"; nobody in the harbor can start a voyage | PASS (one ship, one island, by design) |
| R3.x | A harbor player standing on the ship during a Play Again countdown | **FAIL before FIX 1:** they saw the countdown but could not join and were left behind. **After FIX 1:** they got "You joined a crew", the countdown, and sailed with the Play Again player. | PASS after fix |

R1.4–R1.6 are superseded. In round 1 the owner held E at 3/4, so the countdown seen in steps 4–6 was a SAIL NOW countdown, not the automatic 4/4 one. Round 2 re-ran the 4/4 behaviour cleanly (R2.1–R2.3).

### Not run by the owner (skipped at the owner's request, recorded as UNTESTED with six clients)
| Check | Other evidence |
|---|---|
| SAIL NOW with exactly 1 player in a multi-client session | Studio Play (one client, real key press): solo SAIL NOW, visible countdown, `RunStarted players=1`, landed. Unit test: "1/4 SAIL NOW departs with exactly P1". |
| SAIL NOW with exactly 2, only those 2 sail | Unit test: "2/4 SAIL NOW: only P2,P3 sail". Six-client: R1.3 (3 players) and R3.1 (2 players via Play Again) behaved correctly. |
| Initiator walks off during SAIL NOW | Studio Play (one client): `DepartureCancelled` 1.6 s after stepping off, back to Waiting, no voyage. Unit test passed. |
| Fuel scales only with the active crew | Code unchanged since batch 1: LampService counts `Ready` players, and only the frozen departing party is `Ready` during a voyage (harbor players cannot join a locked ship). Not observed in multiplayer. |
| Controller (Y / right stick / B) and phone joystick | Code not modified since batch 1, when the owner reported "All working" (`Client.Main`, `UiKit`, `Coach`, `LampService` and `Config` show no git changes). Not re-observed. |

## Boarding zone edge check (Studio Play, one client, 11 positions): 11 of 11 PASS
- **Counted:** the main deck centre and the main deck by the rail; the quarterdeck (raised, by the wheel); the forecastle (raised, at the bow).
- **Not counted:** the pier ramp and the pier ramp tip; the water beside the hull; beneath the hull; just outside the side (x=15); just past the bow; high above the deck (y=30).

## FIX 1: ship stayed locked during a Play Again countdown
- **Symptom:** observed by the owner. A harbor player on the ship saw the Play Again countdown but could not join, and was left behind.
- **Cause:** after Play Again, `GameState` sets Phase `Waiting` and then `Intermission` in the same frame. ShipRoster's unlock handler is a deferred attribute signal, so it read `Intermission` and never unlocked. The ship stayed locked through the rematch countdown, so the boarding zone refused everyone with "sailed".
- **Reproduced** before the fix in an Edit-mode harness: "locked after Waiting+Intermission in one frame = true".
- **Fix:** the smallest reversible change, in ShipRoster only. The ship also unlocks when the phase is `Intermission`. A ship is never legitimately locked during Intermission, because it locks when the countdown ends.

```diff
-	-- back in port: every ship takes a new party
+	-- back in port: every ship takes a new party. Intermission counts too: after Play Again, GameState sets
+	-- Waiting and then Intermission in the same frame, and this (deferred) handler only sees Intermission.
+	-- A ship is never locked legitimately during Intermission (it locks when the countdown ends).
 	state:GetAttributeChangedSignal("Phase"):Connect(function()
-		if state:GetAttribute("Phase") == "Waiting" then
+		local phase = state:GetAttribute("Phase")
+		if phase == "Waiting" or phase == "Intermission" then
```

- **Retest:**
  - Harness: **6 of 6 PASS**. The ship stays locked during the voyage and at night; unlocks for the Play Again countdown; a player on deck joins the rematch crew; the rematch takes P1 and P3; the ship locks again once it sails.
  - The owner's six-client retest passed: "the player 2 shown he joined a crew and count down and then he went into the lighthouse isle".
- `ServerScriptService.Server.ShipRoster` is now SHA-256 `85c418b1dfcf56491d6e230aa577d52f803dec5744f507b41834ddd43ca748d9`. It is equal in Studio and in git, and it compiles.
- **Rollback:** `ServerStorage.Backups.UnlockFix_before_2026-10-15`, or revert the diff in `FIX1_UNLOCK_DIFF.diff`.
- The earlier 24-check suite does not use the `Intermission` phase, so this fix does not change its result. It was not re-run after the fix.

## Current script hashes (Studio = git)
| Script | SHA-256 |
|---|---|
| `Server.ShipDeparture` | `3468f695ee9bdd49dff0b8ab37eff8bd84d2928b83f95be366411b5d81299c4a` |
| `Server.ShipRoster` (FIX 1) | `85c418b1dfcf56491d6e230aa577d52f803dec5744f507b41834ddd43ca748d9` |
| `Server.ShipBoarding` | `54f56dfd605e201a01b6df1e21e0998207bbe499b397f86e431fffb0466c14fe` |
| `Server.Main` | `b7a10a5c2e793d91a303b80ceac89eff9a4ffadb1bbd13669a1681a5c803fa16` |
| `Server.GameState` | `db4271215cea37f8b5ecf329c6aa6e10edda58ce02426046c1a3f10fc3a2c36a` |
| `Server.LobbyBuilder` | `46c4e06840e002f2de8e52b07bb57884d923ecbba14e83dec476c5c464e1eddf` |
| `Client.Departure` | `d8f905a2d726d74b4904cc66b10ac347d945cd55e55bdedd8e7a30e61af36cd1` |

## Auditor decisions applied
- **Rematch:** Play Again counts as a deliberate departure. Only opted-in players keep their seats; declining or returning to the harbor frees the seat (R3.1, observed). Disconnecting frees the seat through `PlayerRemoving`, which is unit-tested but was not observed with six clients.
- **Countdown:** kept at 10 s. Nobody in the owner's test reported it as too short, so no change was proposed.
- **Zone:** the geometry is unchanged, and edges were verified as above.

## Owner idea recorded (not implemented)
When a ship sails, it leaves, and a fresh ship appears so another crew can start straight away. This is added to `docs/batches/2026-10-15_boarding/MULTI_SHIP_VOYAGE_SERVER_PLAN.md`. It needs the voyage-server (TeleportService) architecture, which this batch does not implement.

## Publication readiness
**The core departure behaviour is verified with real clients:** automatic 4/4, cancel and restart, SAIL NOW, crew-only UI, harbor spectators, rematch opt-in, and FIX 1.

**Remaining before publishing:**
1. Auditor acceptance of FIX 1.
2. The owner decides whether the skipped multi-client checks are needed before publishing: SAIL NOW with exactly 1 or 2 players, initiator walk-off, multiplayer fuel, and controller and phone re-checks. Each has single-client or unit evidence, listed above.

Publishing stays manual, by the owner.
