# Auditor package: multi-ship phase 2 foundation, 2026-10-15

- **Target:** PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.**
- **Not done in this batch:** no place created, no teleport executed, no DataStore operation, PlayerData not switched to the new adapter, SaveTest untouched, Outlaw City untouched.
- **Responds to:** the auditor's phase 1 verdict, "NEXT GAMEPLAY BATCH: MULTI-SHIP FOUNDATION".
- **Backups:**
  - Place: `backups\2026-10-15\LighthouseKeepers_2026-10-15_v160_pre-multiship.rbxl`, SHA-256 `808eb3c9…ec45`. Its Rojo export matches the pre-edit sources.
  - Scripts: `ServerStorage.Backups.Multiship_before_2026-10-15`, plus `before\`.

## The published game is unaffected
| Flag (`Shared.Config`) | Value | Meaning |
|---|---|---|
| `MULTI_SHIP_ENABLED` | **false** | `PlaceRole.get()` returns `"single"`: today's game, with one ship and the voyage in the same server |
| `TELEPORT_ENABLED` | **false** | Departures are simulated in Studio. The real teleport path also refuses to run without the save adapter wired. |
| `PLACE_ROLE_OVERRIDE` | **nil** | Studio testing only |
| `ISLE_PLACE_ID` | **0** | The Isle place does not exist yet |

- **With the flags off, every new code path is skipped:** no second ship, no HarborDepartures, no IsleAdmission. The Ship1 path, GameState and the phase 1 isolation behave exactly as before. This was verified in Studio Play (below).
- The flags were switched on only temporarily, for the harbor and isle Play tests. They were switched back, and Config's hash in Studio again equals git.

## What was implemented
| Item | Where |
|---|---|
| **Place-role switch:** "single", "harbor" or "isle" | New `PlaceRole`; `Main` branches on `ROLE` |
| **Second ship, Ship2:** its own BoardingZone, roster, 1–4 capacity, wheel (SAIL NOW) and gangway | `LobbyBuilder.buildExtraShips` (harbor role only). The ship is a copy of Ship1 moved 48 studs along X; its zone is Ship1's dedicated BoardingZone, moved with it. |
| **Independent per-ship countdowns:** 4/4 automatic, 1–3 SAIL NOW, invalid requests cancel; checked before completion and revalidated before the freeze (FIX 2 kept) | New `HarborDepartures`. It uses the unchanged `ShipDeparture`, `ShipRoster` and `ShipBoarding`, and adds `ShipRoster.unlock(id)` because the harbor has no global game phase. |
| **Client:** one sign per wheel; per-ship countdown and state; SAIL NOW shown per ship | `Client.Departure`: `wheels[]`, `shipView(id)`, and the `MultiShip`, `Ship_<id>_Phase` and `Ship_<id>_TimeLeft` attributes |
| **Isle place code:** the **existing** GameState loop, fed through its two existing hooks (`departure`, `departShip`) | New `IsleAdmission`: a manifest crew, or everyone in a Studio test; wait for the crew or `ISLE_ARRIVAL_WAIT`; Play Again rematch. In `Main`, the isle skips the title, disables boarding, and sends leavers back to the harbor. |
| **Teleport flow:** prepared and disabled | New `Voyages`: `ReserveServer`, a MemoryStore manifest (UserIds and ship only), `TeleportAsync` with an access code, `TeleportInitFailed` recovery, `returnToHarbor`. It **asserts** the save adapter exists before any teleport. |
| **Guarded save hand-off adapter:** synthetic only | New `SessionLock`. It is **not wired** into PlayerData. |
| **Phase 1 isolation kept** | `VoyageCast`, `SoundFx`, `Storm`, `GameState` and `LootService` are unchanged in this batch |

The harbor never runs GameState: in the harbor role `Main` returns after starting HarborDepartures.

### SessionLock against the auditor's checklist
| Requirement | Implementation | Test |
|---|---|---|
| Unique fencing token per session | A GUID per claim in `metadata.session.token`; every write checks it inside `UpdateAsync` | ✓ |
| Heartbeat while unchanged | `heartbeat()` rewrites `at` and keeps the value | ✓ |
| Atomic ownership check on every save | The check runs inside the `UpdateAsync` transform; a mismatch returns nil, which cancels the write | ✓ |
| Preserve existing metadata and UserIds | Metadata fields are copied; `GetUserIds()` is passed through | ✓ |
| Awaited final save and release before teleport | `release(key, value)` (Voyages calls `playerData.handoff` before `TeleportAsync`) | ✓ |
| Recovery when a teleport fails after release | `claim()` again; it succeeds at once with the latest value (Voyages calls `playerData.reclaim`) | ✓ |
| PlayerRemoving and autosave races | Per-key operation queue; after release, later saves get "not owned" | ✓ |
| Old servers that don't understand the lock | An old server's write (value only) clears the session; the new owner's next save is fenced ("lock lost"), not silently mixed. **Deployment rule:** enable only with "Shut down all servers" / "Migrate to latest update". | ✓ (fenced) |
| Isolated tests: concurrent load, takeover, failed save, failed hand-off | A fake in-memory store with atomic per-key `UpdateAsync`, latency and injected failures; no DataStoreService | 19/19 |

## Tests (API access checked OFF before every Play; saves were memory-only)
| Test | Result |
|---|---|
| **SessionLock synthetic suite:** concurrent claims (exactly one wins); profile read; metadata and UserIds kept; GUID token; owner save; non-owner refused; heartbeat; live lock refused; stale lock (>120 s) taken over; old owner fenced; failed save keeps the lock and the retry works; release clears the session and writes the final value; the releaser cannot write; claim after release reads the final value; failed hand-off re-claim; autosave, release and late-save serialization; an old-server write fences the new owner | **19 / 19 PASS** |
| **Two-ship independence** (fresh module copies, 8 stand-in players, real `HarborDepartures` with a 3 s countdown): Ship1 4/4 counts down while Ship2 at 2/4 waits; each player in one party only; a 5th on Ship1 is refused "full" and then boards Ship2; Ship2 SAIL NOW counts down at the same time; Ship1 4→3 cancels only Ship1; Ship2 launches exactly P5–P7 and comes back unlocked and empty; Ship1 back to 4/4 starts a fresh countdown and launches exactly P1–P4; Ship2 at 1/4 without SAIL NOW does not launch; exactly 2 launches, no duplicates | **12 / 12 PASS** |
| **Studio Play, flags OFF** (the published behaviour) | PASS: `MultiShip=false`, no Ship2, 1 wheel prompt; boarding gives 1/4; Sail Now (real E key) → `DepartureStarted mode=manual` → Intermission → Prologue; the player landed on the island; no errors |
| **Studio Play, harbor role** (flag on temporarily) | PASS: Ship1 at (0,0,420) and Ship2 at (48,0,420), each with its own zone (28×12×65.5) and wheel prompt (`ShipId` Ship1/Ship2); the gangway reaches the shore (screenshot). Standing on the gangway does not board; Ship2's deck does (Ship2 1/4, Ship1 0/4). Signs: Ship2 "CREW 1/4 · SAIL NOW", Ship1 "WAITING FOR CREW". Only Ship2's prompt is enabled for this player. SAIL NOW (E) → Ship2 Countdown 10→6, **Ship1 stayed Waiting and the global Phase stayed Waiting** (no voyage loop in the harbor) → simulated launch → the player is back at the harbor spawn and Ship2 is unlocked. |
| **Studio Play, isle role** (`PLACE_ROLE_OVERRIDE="isle"` temporarily) | PASS: no title (`Route=fast`); after the 20 s crew wait, Intermission, then `IsleVoyage crew=1` → `RunStarted players=1` → landed → Prologue with `ShipId=Isle`, using the unchanged GameState; no Ship2 and no boarding on the isle; no errors |

Test notes, recorded for transparency:
- The first SessionLock run timed out: the harness's fake sleep did not advance its fake clock. That left one idle test thread in Studio's edit session, which touches only the fake store and ends when Studio restarts.
- The first two-ship run used a 1 s countdown, shorter than the 1 s step-off grace, so Ship1 sailed before the grace expired. That produced 2 failures, which are a test-timing artifact (the known grace limitation). A rerun with a 3 s countdown passed 12/12.

## Script hashes (Studio = `after\` = git; all compile)
| Script | SHA-256 |
|---|---|
| `Shared.Config` (flags OFF) | `8d89e49db3efcf652412adfc06ed5c9c523c7f3accfb9689f145c1aaae5e374a` |
| `Server.PlaceRole` (new) | `89a0e59b73b659d83ad4a675cf5f6a4c928c464f4213bfc8de10072e2c869593` |
| `Server.HarborDepartures` (new) | `a97276ea108fa6706a1c15ba8d0fc43e5009590831d7b3feb663495f7f056047` |
| `Server.Voyages` (new) | `7d26b69d7ed27417d8670fdbaeb10bfe1d8bf71508c6e790f99775fb88166d75` |
| `Server.IsleAdmission` (new) | `3d3d0f6bb4704395601b0742d352982cdb3863ca988133c42914aa4e7488bc62` |
| `Server.SessionLock` (new) | `451078e55acea9f449eeed59c9ecb4b8ba40ea8ebd3a26feb00ab034284acfea` |
| `Server.ShipRoster` | `c176e9decf418a63d73e2c9875cc15bd061b6726347dc07ebeee8b10396f394e` |
| `Server.LobbyBuilder` | `1db99ff8b9ca0af63bf25fc5077af3c6733465ffe15eaa2f25d44e320e297ba1` |
| `Server.Main` | `42489bb8e9a0eb40c470bc0b781bba7af270f63f5d6da5749eb2df4f5a556a6b` |
| `Client.Departure` | `b81620171b74bb70786875cfb486dd16a1a739fa5f491a8e89e1c446fee3c02f` |

The exact diffs are in `PHASE2_DIFFS.diff`.

## Owner actions required (none done)
1. **Create the Isle place** in the Lighthouse Keepers experience: Creator Dashboard → Lighthouse Keepers → Places → "Create place" (or Studio → Asset Manager → Places → Add). Name it "Lighthouse Isle". Send me its PlaceId. I then set `ISLE_PLACE_ID` and prepare a copy of this build for it. **Do not publish anything to it until asked.**
2. **Choose the test environment** for live teleports and the save hand-off (still open from phase 1): (a) a new test experience with Harbor and Isle copies (recommended), or (b) unfreeze SaveTest.
3. **Later, with separate approval:** wire SessionLock into PlayerData behind its own flag; publish the test places; run multi-client teleport tests; finally publish production using "Shut down all servers".

## Known limitations
- Ship2 is a copy of Ship1 placed beside it. There is no new art or island.
- The isle place's lobby dock is the same harbor geometry. Players wait there up to 20 s before the voyage starts.
- `Voyages.readManifest` uses a MemoryStore sorted map, which is untestable in Studio Play until published.
- The 1 s step-off grace at lock time (accepted earlier) applies per ship.

## Questions for the auditor
1. Is copying Ship1 (model and BoardingZone) for Ship2 acceptable as the foundation, or must every ship's BoardingZone be computed from its own deck parts? They are identical today.
2. Is `IsleAdmission` starting with whoever arrived after `ISLE_ARRIVAL_WAIT` (20 s) acceptable, or should a missing member void the voyage?
3. Is the old-server rule (fence the new owner, plus deploy only with "Shut down all servers") sufficient, or do you require a version marker in metadata that old servers would also preserve?
