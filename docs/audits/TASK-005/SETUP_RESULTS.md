# TASK-005 setup results (what actually happened, 2026-10-14)

Plan: `SETUP_PLAN.md`. This file records the outcome against the plan. Owner approval for D3 (planning and guided setup of a separate private SaveTest experience) came in chat; every later write-capable step waited for a separate answer.

| Plan step | Outcome |
|---|---|
| 0 Claude copies the backup to `savetest\` | **Not done by Claude.** The owner made their own copy before the step was approved: `backups\2026-10-14\savetest\LighthouseKeepers_SaveTest_from_v148.rbxl`, byte-identical (SHA-256 `0C880E87D5909DD1B76AFDDD74ECECF8AC5E809FEBF19FD7AF56DDE4537307EF`) to `backups\2026-10-14\LighthouseKeepers_2026-10-14_v149.rbxl` (the owner's save made after v148). So the test place was built from **v149, not v148**. The original `LighthouseKeepers_2026-10-14_v148.rbxl` is untouched (SHA-256 `6AF4E72746EC7D8B7B2509A65A62A989DA6729051E1ECCBE71B969056D03B5C8`, size and time unchanged). |
| 1 Owner opens the copy in a new window | Done by the owner (not witnessed; inferred from the result) |
| 2 Claude re-lists instances | Done after the fact: the list shows production "Lighthouse Keepers - Staging (placeId 132065051336560)", Outlaw City (132163592957463) and a new window "Private lighthouse keepers (placeId 128620546156998)" |
| 3 Owner publishes as a new experience | Done by the owner (the riskiest step). Claude has no evidence of any change to production (its window still reports place 132065051336560), but Claude did not inspect or compare production's published version, so this is "no sign of a problem", not a verification. The owner can confirm in Creator Hub that production's version history shows no new version from today |
| 4 Owner checks Creator Hub: IDs and Private | Owner reported "it says private". The owner could not find the IDs in Creator Hub, so Claude read them from the Studio window instead (see below). Matching them with Creator Hub's page is left to the owner |
| 5 Claude verifies IDs | **PlaceId 128620546156998, GameId (universe) 10770892134, creator user 11752219158, place version 3**, not equal to production (132065051336560 / 10769064643). Counts equal the backup: ReplicatedStorage 51 instances/9 scripts, ServerScriptService 15/14, StarterPlayer 20/17, ServerStorage 632/181, Workspace 90, Lighting 6, 20 backup folders; `Hud` length 74,224 and `PlayerData` length 10,259 match |
| 6 Owner enables Studio API access in SaveTest | Owner reported "studio api access enabled". The first read attempt was rejected ("Studio access to APIs is not allowed"), so the setting had not yet taken effect; after the owner saved it again, the second attempt worked |
| 7 Owner looks at production's API setting | **Not reported; status unknown.** Nothing was changed. D4 (turn it off) remains pending |
| 8-9 Test-only store name and guard, then publish | **Dropped at the owner's request** ("You are opening a door for human errors"). No edit was made to the SaveTest place and nothing further was published. The store name there stays `LighthouseKeepers_PlayerData_v1`, which is the SaveTest universe's own separate store |
| 10 Gate T0 read | **PASS** after the second attempt (details in `REVISED_TEST_MATRIX_V2.md`) |
| 11 Canary write | **Not requested, not done** |

## Calls made to the SaveTest instance (all read-only)
1. `execute_luau` (Edit): read PlaceId, GameId, counts, string lengths, creator, store-name line. No writes.
2. `execute_luau` (Edit), T0, attempt 1: `GetAsync` x2, rejected by Roblox (no data read).
3. `execute_luau` (Edit), T0, attempt 2: `GetAsync` x2, both returned nil.
No instance was changed, no Play session was started, nothing was published by Claude, and no DataStore write was made by Claude. Each T0 script asserted the SaveTest PlaceId and GameId and that they differ from production before touching `DataStoreService`.

## Observations
- The owner's publishing (step 3) also left `PlaceVersion = 3` on the test place, which means more than one publish happened. Not harmful; recorded for completeness.
- No credentials, API keys or real player records were involved.
- ProfileStore is not installed anywhere; the pinned file remains only in `vendor-review\ProfileStore_45c9847\`.
