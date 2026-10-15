# Multiple ships with voyage servers: technical plan (NOT implemented)

Status: proposal for owner and auditor review. Nothing here is built, published or configured.

## Goal
- The shared harbor (the current place) keeps its full server and its ships.
- Each ship's party sails to its **own reserved voyage server**, so the harbor never runs GameState, creatures, fuel, towers or night timers.
- The lighthouse island is the first destination. Other islands come later.

## Why not several voyages inside one server
`GameState`, `LampService`, `TowerService`, `CreatureService`, `LootService`, `UpgradeService` and `DefenseService` are singletons with module-level state, and the game has one `GameState` folder and one `workspace.Island`. Running parallel voyages in one server would mean rewriting all of them to keep separate state per island. Reserved servers keep the current loop as it is: one voyage per server.

## Shape
| Place | Runs | Does not run |
|---|---|---|
| **Harbor** (the current place, start place of universe 10769064643) | LobbyBuilder, ships, ShipBoarding, ShipRoster, the Quartermaster shop, PlayerData, a per-ship departure countdown | GameState voyage phases, IslandBuilder, creatures, lamp, towers |
| **Voyage** (a NEW place in the same universe) | The current voyage loop, unchanged: Prologue → Day/Night → result, rematch; PlayerData | The lobby ships and boarding |

## Departure flow
1. **Harbor:**
   - Each ship has its own countdown, which starts when its first player boards.
   - When the countdown ends, `ShipRoster.depart(shipId)` freezes the party, exactly as it does today.
2. **Harbor:**
   - `TeleportService:ReserveServer(voyagePlaceId)` returns an access code and a private server id.
   - The harbor writes the voyage manifest to **MemoryStoreService**, keyed by that private server id: party user ids, ship id, destination island, forecast votes, and a short expiry.
3. **Harbor:**
   - `TeleportService:TeleportAsync(voyagePlaceId, members, options)` sends the party, with `ReservedServerAccessCode` set on `options`.
   - TeleportData is used only for loading-screen text, because it passes through the client and can be tampered with.
4. **Voyage server:**
   - It reads the manifest using `game.PrivateServerId`, and admits only the user ids listed in it.
   - It waits a short time for every member to arrive, then starts the existing loop with those players as the crew.
5. **End of the voyage:**
   - Players who choose rematch stay in the same reserved server and the loop runs again with the same crew.
   - Everyone else, and everyone after the final results, is teleported back to the harbor place's public servers.

## Failure handling the plan must cover
- **Teleport fails** (`TeleportInitFailed`): retry once, then put the player back in the harbor with their seat freed, and tell them why.
- **A member never arrives:** the voyage starts with whoever arrives. Crew-size scaling, such as fuel, already uses the real crew count.
- **The voyage server is empty or crashes:** the reserved server shuts down. Pearls already saved for completed runs are kept, and run-scoped shells and loot are lost, which matches today's behaviour.
- **Harbor ship lock:** in the harbor a ship never locks for a whole voyage. It takes a new crew as soon as the previous one has teleported.

## Save-data implications (the main risk; needs auditor review)
- Both places share the universe's DataStores, so PlayerData keys and the schema stay the same and no migration is needed.
- **Hand-over risk:**
  - The harbor saves on `PlayerRemoving`. The voyage server may load the profile before that save finishes, and a later save from either server could overwrite the other.
  - Today `PlayerData.luau` uses `UpdateAsync` / `GetAsync` and has **no session lock**.
  - Before any teleport, this needs one of the following: session locking (the deferred R5 / ProfileStore work), or a strict rule of "save and release in the harbor, then load in the voyage, with a retry if the save is newer". This must be designed and tested in a separate test universe, never on production saves.
- Shells and loot are run-scoped and live only in the voyage server.
- Quartermaster purchases happen only in the harbor.
- Pearls are awarded in the voyage server, as `GameState` does today.

## Testing constraints
- TeleportService and reserved servers do not work in Studio Play. Testing needs **published** places.
- Do this in a separate test universe with two places (a copy of the harbor and a copy of the voyage), never in the production universe, until the owner approves.
- This needs the owner's approval: creating the test universe and places, and publishing to them.

## Minimum changes, in order
1. **Owner:**
   - Create a test universe with a Harbor place and a Voyage place.
   - Later, add a Voyage place to universe 10769064643. Nothing is changed until this is approved.
2. **Split the scripts.** The same codebase gets a place-role switch: `Config.PLACE_ROLE = "harbor" | "voyage"`, set from the PlaceId.
   - Harbor: LobbyBuilder, boarding, the shop and a `Departure` service (countdown, ReserveServer, manifest, teleport).
   - Voyage: the IslandBuilder and GameState loop. Its source of the crew becomes the manifest instead of `ShipRoster`.
3. **Per-ship countdown in the harbor.** `ShipRoster` and `ShipBoarding` already support several ship ids and zones. Add ship models and their zones in LobbyBuilder.
4. **Return path:**
   - "Back to harbor" and the end of the results screen teleport the player to the harbor place.
   - Rematch stays in the same server.
5. **Save hand-over safety** (see above), reviewed by the auditor before step 6.
6. Test the end-to-end flow in the test universe with 6 or more real clients (several ships, a failed teleport, a disconnect mid-teleport, a rematch, a return), then do a production rollout with the owner's approval.

## Owner idea (2026-10-15): the ship sails away and a fresh one takes its place
When a party departs, its ship sails off and disappears, and a new empty ship appears at the same berth, so the harbor is never blocked by a voyage at sea. This matches the voyage-server design: each departing ship becomes its own reserved voyage server, so the replacement ship can fill and leave at once, with no limit on how many voyages run at the same time. It needs the teleport architecture above. Inside one server a second voyage cannot run while the first is on the island, because there is one island and one game loop.

## Not decided (owner)
- How many ships, where they sit in the harbor, and which island each one sails to.
- Whether a party can choose its destination, or each ship goes to a fixed island.
