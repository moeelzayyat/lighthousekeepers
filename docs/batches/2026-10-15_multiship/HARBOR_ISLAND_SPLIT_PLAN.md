# Harbor / Lighthouse Isle split: implementation breakdown (phases 2 and 3)

Status: **plan only**. No place has been created, nothing has been published, and there has been no live DataStore operation. Every owner-controlled step below waits for approval.

## Target structure (one experience, GameId 10769064643)
| Place | Role | Runs |
|---|---|---|
| **A: Harbor** = the existing place 132065051336560 (start place) | Shared lobby, server size 60 | Title, harbor island, Quartermaster shop and loadouts, **two ships** (ShipBoarding, ShipRoster, ShipDeparture), teleport out, return arrivals |
| **B: Lighthouse Isle** = a NEW place in the same experience | One reserved server per departing crew | The current voyage: GameState loop, Lamp, Tower, Creatures, Loot, Upgrades, Defense, Trader, results, rematch |

The full game loop exists only in place B. Place A never runs GameState.

## Reuse (no rewrite)
| Existing code | Harbor (A) | Isle (B) | Change needed |
|---|---|---|---|
| `ShipRoster`, `ShipBoarding`, `ShipDeparture` | ✓ | – | Already keyed by ship id. Register `Ship1` and `Ship2`; each ship gets its own countdown (below). |
| `LobbyBuilder` | ✓ | – | Build a second ship model, BoardingZone and wheel at a second berth. |
| `GameState`, `LampService`, `TowerService`, `CreatureService`, `LootService`, `UpgradeService`, `DefenseService`, `IslandBuilder` | – | ✓ | **Unchanged in logic.** In B every player in the server is crew, so `Ready` and `VoyageCast` (phase 1) still hold. |
| `PlayerData` | ✓ | ✓ | Same DataStore and the same profile format. **Add the session hand-off guard** (below) before live travel. |
| `ShopService`, `LoadoutService` | ✓ | read-only use | No change. |
| Client UI (`Departure`, `Hud`, `Results`, `Storm`, …) | ✓ | ✓ | Small changes: the departure card says "Setting sail…" during the teleport; Results gains a "Back to harbor" button that asks the server to teleport the player. |

A single source tree with `Config.PLACE_ROLE` chosen from `game.PlaceId` ("harbor" / "isle"): Main runs only the half it needs. This keeps one codebase and one Rojo project, publishing the same scripts to both places.

## Minimum changes, in order
1. **Place role switch** (Main): harbor runs the lobby, boarding, shop and departure; isle runs IslandBuilder and GameState. Done locally and testable in Studio by forcing the role.
2. **Per-ship departure in the harbor:** ShipDeparture keeps its rules (1–3 SAIL NOW, 4/4 automatic, below 4 cancels, max 4) but runs **one countdown per ship** (a small timer per ship id) instead of GameState's single Intermission. GameState stays in the isle.
3. **Second ship** (LobbyBuilder): a second berth with its own BoardingZone and wheel, `ShipRoster.init(..., { "Ship1", "Ship2" })`.
4. **Teleport out** (new `Voyages` module, harbor):
   1. At countdown end, `ShipRoster.depart(shipId)` returns the frozen, validated crew.
   2. `TeleportService:ReserveServer(ISLE_PLACE_ID)` returns the access code and private server id.
   3. Write a **manifest** to MemoryStoreService (`Voyages` map, key = private server id, about 10 min expiry): `{ ship, userIds, forecastVotes, createdAt }`. No balances, inventory or progress.
   4. `TeleportService:TeleportAsync(ISLE_PLACE_ID, crew, options)` with `ReservedServerAccessCode`. TeleportData carries only `{ ship }` for the loading screen; the isle never trusts it.
   5. The ship unlocks right away for the next crew. The roster is cleared for the teleported players only once the teleport has succeeded, which is when they leave the harbor server.
5. **Isle admission:**
   - The isle reads the manifest by `game.PrivateServerId`.
   - Anyone whose UserId is not in the manifest is kicked back to the harbor.
   - It waits up to about 20 s for all expected members, then starts with whoever arrived (crew size scaling already uses the real count).
   - With no manifest (a public isle server, or one opened from Studio), it sends players to the harbor.
6. **Return:**
   - "Back to harbor" on Results, the end of the results countdown, and the menu's leave all call `TeleportAsync(HARBOR_PLACE_ID, { player })` to a public harbor server.
   - Play Again keeps the crew in the same reserved isle server, using the existing rematch loop.
7. **Failure handling:**
   - On `TeleportInitFailed`, retry once. If it still fails, the player stays in the harbor and is told why, and the voyage starts without them.
   - Party membership and progress are never deleted because of a failed teleport: the player is simply still in the harbor and can board again.
   - An isle server whose crew never arrives shuts down after its wait.

## Save hand-off safeguard (required before live travel)
**Risk today:** `PlayerData.save` does `UpdateAsync(key, function() return profile end)`, so the last writer wins. `load` does `GetAsync`.

On a teleport, the harbor saves on `PlayerRemoving` while the isle may already be loading. The isle can read the **old** profile, for example from before a Quartermaster purchase made just before boarding. Its later saves would then overwrite the harbor's newer save, so the purchase is lost.

**Safeguard (no change to the profile format):** a session lock kept in the DataStore key's **metadata**. `UpdateAsync` can return `(value, userIds, metadata)`, and the metadata is stored beside the profile, not inside it.
1. **Load = claim.**
   - The loading server runs `UpdateAsync`, which reads `keyInfo:GetMetadata().session`.
   - If another live session holds the key and its heartbeat is less than about 2 min old, it does not claim. It waits and retries, up to about 15 s.
   - Otherwise it writes the same value back with `metadata.session = { jobId, at = os.time() }`, and uses that value as the profile.
2. **Save only while owning.**
   - Every save is an `UpdateAsync` that first checks the metadata session is still this server's.
   - If it isn't, the save is refused, and the server stops saving and warns.
   - Each save refreshes `at`, which acts as the heartbeat.
3. **Hand-off on teleport.** Before `TeleportAsync`, the harbor runs a **final save that releases** the lock (`metadata.session = nil`) and waits for it to finish. Only then does it teleport. The isle's claim then succeeds immediately and reads the newest profile.
4. **Crash safety:** a lock whose heartbeat is older than about 2 min counts as stale and may be taken over. This is the same idea as ProfileStore's session lock, without changing the stored profile.
5. `doNotSave` (a failed load) keeps its meaning: such a session never claims and never writes.

**Testing it needs a non-production DataStore.** SaveTest is frozen, so this needs the owner's choice of where to test:
- (a) a new test experience with Harbor and Isle copies (recommended), or
- (b) explicit permission to unfreeze SaveTest.

Teleports and reserved servers do not work in Studio Play, so the end-to-end test needs **published test places**. That is owner-controlled.

## Owner-controlled steps (each needs approval; I will not do them)
1. Create place B, "Lighthouse Isle", inside the Lighthouse Keepers experience, using Creator Dashboard, Places, Add, or Studio's Asset Manager. Then tell me its PlaceId.
2. Choose and create the test environment for the hand-off (a new test experience is recommended).
3. Publish the test places when I have the scripts ready, and run the multi-client tests there.
4. Only after those pass and the auditor accepts: publish the production harbor and isle.

## What I can do now without approval (local and reversible)
- Implement steps 1–3 (role switch, per-ship countdowns, a second ship) behind a `Config.MULTI_SHIP_ENABLED = false` flag, testable in Studio with two ships departing to the current single-server island one at a time. Nothing changes in the live behaviour until the flag is on.
- Write the `Voyages` (teleport) and PlayerData session-lock code behind `Config.TELEPORT_ENABLED = false`. It can be reviewed by the auditor but cannot run in Studio.
