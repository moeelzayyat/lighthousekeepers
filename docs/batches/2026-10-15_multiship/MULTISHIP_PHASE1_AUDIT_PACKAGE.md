# Audit package: multi-ship batch, phase 1 (message isolation) + split plan, 2026-10-15

- **Target:** PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.** No place created, no DataStore operation.
- **Responds to:** "OWNER DIRECTIVE: LIGHTHOUSE KEEPERS MULTI-SHIP AND SEPARATE ISLANDS".
- **Backups:**
  - Place: `backups\2026-10-15\LighthouseKeepers_2026-10-15_v159_pre-isolation.rbxl`, SHA-256 `390c9e13…0148`. It is byte-identical to the cleared v158 build, and its Rojo export matches the source.
  - Scripts: `ServerStorage.Backups.Isolation_before_2026-10-15`, plus the `before\` folder.

## Phase 1: what leaked, and the fix
| Leak (harbor players received it) | Where | Fix |
|---|---|---|
| About 30 voyage announcements: lamp failing, crabs, night start and survived, big monster, low fuel, forecast, victory and defeat | `GameState.notifyAll` → `Notify:FireAllClients` | `VoyageCast.fire(Notify, …)`, crew only |
| Results payload (the client already ignored it unless Ready) | `GameState` → `RunResults:FireAllClients` | `FireClient` to each voter (the voyage crew) |
| Monster down, pearls picked up, rare loot, tide loot | `LootService` (5 calls) | `VoyageCast.fire` |
| Cannon built, upgraded, out of ammo, destroyed | `DefenseService` notifier from `Main` | `VoyageCast.fire` |
| Upgrade bench purchases, Trader sales | `Main` | `VoyageCast.fire` |
| **All island sounds:** hits, deaths, cannons, monster, refuel, build, repair, throw. The 450-stud fade-out reached the harbor 420–520 studs away. | `SoundFx.playAt` (server) → `PlaySound:FireAllClients` | Server `playAt` sends only to Ready players. Every server `playAt` call (16 sites) is an island sound. |
| Storm rain, ambient, lightning, thunder; the focused-beam hum (500-stud range) | `Storm.client` gated only on Phase | Also requires `Ready == true`, and refreshes when Ready changes |

- **New module `VoyageCast`:** `crew()` returns the Ready players, and `fire(remote, …)` sends `FireClient` to each of them. During a voyage, Ready is exactly the frozen, departed party; harbor spectators are never Ready.
- **Harbor messages are unchanged:** boarding, SAIL NOW, "crew full", "at sea", the harbor countdown note and the shop all already use `FireClient` to the concerned player.
- **After this batch, there are 0 `FireAllClients` calls in any server module or in SoundFx** (checked in Studio).

### Scripts (SHA-256, Studio = `after\` = git; all compile)
| Script | SHA-256 |
|---|---|
| `Server.VoyageCast` (**new**) | `f44382fe74dcdc6ecc561c50c387e539aea4404824d5e0482347c05443e44ba3` |
| `Server.GameState` | `3833e284c22fd05df5c5c7f25339091d9d01d4a722e7fae7a68915a5d42c9f1f` |
| `Server.LootService` | `3f329dcdb8b8f8ea27c703aa2035cc84c6badfeb75e2fd9068ae2ab07918b48d` |
| `Server.Main` | `390a989b2fe94135928a273a79f08cd5b755f181453ba4b03845782fb087f821` |
| `Shared.SoundFx` | `356d78626fc8a217eb518f529cc720dc9e09bf594c649b2d724755e6f0b3f85b` |
| `Client.Storm` | `bce6b6998d0acc53842ff8481b4ad061e8459c58dc16d094865fb27fc50945c8` |

The exact diffs are in `ISOLATION_DIFFS.diff`. The departure scripts (ShipRoster, ShipBoarding, ShipDeparture, LobbyBuilder, Departure), PlayerData and Config are untouched.

### Six-client test (owner session; counters attached to each client's Notify, RunResults and PlaySound remotes)
The voyage ran with 2 crew (P1, P2) via SAIL NOW and 4 in the harbor (P3–P6). It went through the prologue, 3 cannons built, rare Sea Glass, a Trader sale, day, night with the focused beam, defeat and results.

| Client | Role | Notify | RunResults | Sounds |
|---|---|---|---|---|
| Player1 | crew | 13 (cannons ×3, monster, crabs, Sea Glass, Trader sale, squall, day, low fuel, Keeper, night, defeat) | 1 | 54 |
| Player2 | crew | 12 (the same, minus the personal Keeper tip) | 1 | 54 |
| Player3 | harbor | **0** | **0** | **0** |
| Player4 | harbor | **0** | **0** | **0** |
| Player5 | harbor | **0** | **0** | **0** |
| Player6 | harbor | **0** | **0** | **0** |

- The server console had no errors, and saves were in memory only (API access OFF, checked before Play).
- The counters were temporary listeners in the test session only, not in the place.

### Not isolated (known limitation)
- **Night lighting:** the server tweens `Lighting` for the whole server, so the harbor darkens at night.
- A client-side override would be overwritten by replication. This disappears with the Harbor/Isle place split (phase 2), so no workaround was added.

## Phases 2 and 3: Harbor / Lighthouse Isle split
See `HARBOR_ISLAND_SPLIT_PLAN.md`. In summary:
- **Structure:** Place A Harbor (the existing place) and a new Place B Isle in the same experience.
- **Reuse:** the whole voyage loop is reused unchanged in B. The harbor keeps ShipRoster, ShipBoarding and ShipDeparture, with one countdown per ship and **two ships**.
- **Departure:** `ReserveServer` per departing crew. A MemoryStore manifest keyed by `PrivateServerId` lists the admitted UserIds; TeleportData carries no balances or inventory and is not trusted.
- **Return:** to a public harbor server after Results. Play Again stays in the same reserved isle server.
- **Teleport failures:** these leave the player in the harbor with membership and progress intact.
- **Save hand-off guard:** a session lock stored in the DataStore key **metadata**, with the profile format unchanged:
  - claim on load;
  - save only while owning, with a heartbeat;
  - release with an awaited final save before teleport;
  - stale-lock takeover after about 2 min.
  This must be tested in a non-production DataStore before any live travel.

## Owner decisions needed (nothing done without approval)
1. Create Place B "Lighthouse Isle" in the Lighthouse Keepers experience, and give me its PlaceId.
2. Test environment for the teleport and save hand-off: (a) a new test experience with Harbor and Isle copies (recommended), or (b) unfreeze SaveTest.
3. Publishing the test places, and later the production harbor and isle.

## Questions for the auditor
1. Is routing every server `SoundFx.playAt` to Ready players acceptable? All 16 current call sites are island sounds; a future harbor sound would need a separate helper.
2. Is the metadata-based session lock (no profile schema change) an acceptable resolution of the cross-server hand-off risk, or do you require ProfileStore?
3. Is night lighting reaching the harbor acceptable until the place split?
