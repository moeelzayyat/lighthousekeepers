# Test matrix v2 (TASK-005): updated for `SOURCE_VERIFICATION_ADDENDUM.md` and the real SaveTest universe — nothing has been run except gate T0

Supersedes `TASK-004/REVISED_TEST_MATRIX.md`. Rows marked NEW or CHANGED come from the addendum findings A-J or from the verified environment.

## 0. Environment (verified)
| Item | Value |
|---|---|
| Test experience | "Private lighthouse keepers" (owner-created, private) |
| PlaceId / GameId (universe) | **128620546156998 / 10770892134**, creator = the owner's user account |
| Production, for contrast | 132065051336560 / 10769064643 (never touched) |
| Studio API access | **ON in SaveTest** (confirmed by a successful read in T0 after the owner saved the setting); production: **not known** (owner did not report it; no change made) |
| Test place content | identical to the owner's v149 save (scripts 9/14/17 live and 181 in ServerStorage, 20 backup folders; `PlayerData` length 10,259; store name still `LighthouseKeepers_PlayerData_v1`, which here is the **test universe's own** store) |
| Hard rules | no Play, Save, Publish or script execution on any instance whose PlaceId/GameId was not just verified; Outlaw City is never touched; no writes to production; no `RemoveAsync`; no import of real player saves; ProfileStore only in this test environment, from the pinned hash-verified file |

## 1. Gate results
| ID | Result |
|---|---|
| **T0** | **PASS (2026-10-14).** From the SaveTest window (IDs asserted inside the script), a read of `player_11752219158` and of `__access_check` in store `LighthouseKeepers_PlayerData_v1` both succeeded and returned nil. The first attempt, before the owner saved the API setting, was rejected with "Studio access to APIs is not allowed" (error 502) and read nothing. Limitation: the production key is documented to hold real progress (progress.md) but production was not read, so "nil here" supports isolation without proving the production key exists. |

## 2. Persistence tests (real DataStore, SaveTest universe only)
Carry-over rows C1-C17 from TASK-004 stay, with these changes:
| ID | Change | Test |
|---|---|---|
| C1 | CHANGED (finding: the fence uses `game.JobId`, which I believe is empty in Studio) | Two-session tests must use **published servers** (reserved/private servers of the test place). Studio-only concurrency results are invalid unless a first test (C22) proves `game.JobId` differs per Studio session |
| C7 | CHANGED (finding: release saves loop until success; shutdown has no internal deadline) | Shutdown with 4 players, injected failures and latency; measure how long release saves run before Roblox ends the server; confirm no hang, and that data written before the failure window is intact |
| C12 | CHANGED (findings: overwrite happens even on a cancelled load; `GetAsync` returns a template for a legacy record) | In the **test** store only: seed a v1-shaped record; (a) `StartSessionAsync` with a `Cancel` that returns true, (b) normal start, (c) `GetAsync`; record whether the record is overwritten, the `OnOverwrite` signal, and what each call returns |
| C14 | CHANGED (finding J: every autosave writes the whole `Data`) | Write budget with 4 players at candidate `AUTO_SAVE_PERIOD` values (60, 120, 300 s) plus `Profile:Save()` after each Pearl credit and purchase |
| C18 NEW | finding D: Studio probe writes `____PS` | Load the library in a Studio session on SaveTest with API access; confirm the key `____PS` appears in the **SaveTest** store and nowhere else; this documents why the library is never loaded in the production place's Studio |
| C19 NEW | finding A: ordinary autosave failures are not retried | Inject a failure on one autosave, then change data, then end the session: confirm the loss window equals one autosave period unless `Profile:Save()` is called, and that the release save then succeeds |
| C20 NEW | finding C | `GetAsync` view of a legacy record returns template data, not the stored table; our importer reads v1 with plain `DataStoreService:GetAsync` instead and gets the real fields |
| C21 NEW | finding G | Player leaves and rejoins the same server quickly: `EndSession` always called on leave; no "already loaded in this session" error; second load returns the saved data |
| C22 NEW | JobId in Studio | Log `game.JobId` in two Studio sessions and in two published servers; record the values |
| C23 NEW | finding B | Measure real time from first conflict to steal with an unresponsive holder (expect about 45 s plus request latency) and with a responsive holder (expect a few seconds) |
| C24 NEW | finding F | `Cancel` callback runs inside the transform: verify a pure, non-yielding `Cancel` behaves, and that a yielding one is not used |
| C25 NEW | finding H | `OnSessionEnd` fires before the final write: verify the adapter does not treat it as "saved"; final data present after `EndSession` completes |
| C26 NEW | finding I | Cancelled first load of a brand-new key: confirm what record is left behind |
| C27 NEW | finding E | Record any warning or behaviour change from `DataStoreOptions:SetExperimentalFeatures({v2 = true})` and re-check on later Roblox releases |
| C28 NEW | mock mode | Run the library in a Studio session without API access and confirm it switches to the in-memory mock (state `NoAccess`) and writes nothing to any store |
| C29 NEW | import safety | Seed v1-shaped fixtures in the **test** v1 store, run the importer: v1 read via plain `GetAsync`; every fixture imports once; a failed v1 read blocks play; v1 records unchanged afterwards (compare version history) |

## 3. Gameplay, crew, validation (unchanged from TASK-004)
P1-P14 (Pearl rules and durable `grants`), CC1-CC8, F1-F2, V0-V9 as in `TASK-004/PEARL_PAYMENT_AND_IDEMPOTENCY.md` and `CREW_FUEL_VALIDATION_REVISION.md`. Real clients are required for first-voyage and harbor-spectator tests.

## 4. Preconditions before any persistence test beyond T0
1. Owner approval for the first DataStore **write** in the test universe (not given yet).
2. Owner confirmation of production's Studio API setting (D4 decides whether to turn it off).
3. Owner approval to place the pinned ProfileStore file into the SaveTest place (not given yet; not done).
4. Agreement on the store names for the tests (`TEST_` prefixed) before any adapter code is written; no code has been changed in the SaveTest place.

## 5. Evidence each row must leave
Test id, verified PlaceId/GameId, number of real servers and clients, injected faults, steps, expected and actual, console lines, pass/fail, and whether production could have been touched (must be "no").
