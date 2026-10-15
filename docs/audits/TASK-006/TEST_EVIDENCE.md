# TEST EVIDENCE — TASK-006

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (place 128620546156998, universe 10770892134), Edit mode. Players: none. Device/emulator: none. No Play session.

**Could any test have changed production DataStore values? No.** No call in this task targeted a production instance's DataStore, and the only DataStore calls were made from the SaveTest window after IDs were asserted in the script.

| # | Test | Expected | Observed | Result |
|---|---|---|---|---|
| 1 | List Studio instances (three times in this task) | production, Outlaw City, SaveTest separate and identifiable by place ID | three windows listed as expected | PASS |
| 2 | Identity read in SaveTest with asserts | exact IDs, not production | PlaceId 128620546156998, GameId 10770892134, creator 11752219158, version 3, `IsEdit` true, `IsRunning` false; store-name line unchanged `LighthouseKeepers_PlayerData_v1` | PASS |
| 3 | Production Studio API-access setting | readable without touching production | no non-invasive method; Creator Hub login wall (browser pane, no login attempted, closed) | **UNKNOWN** |
| 4 | Script hashes v148 vs v149 | equal | 40 of 40 SHA-256 identical (`HASH_COMPARISON_V148_V149.md`) | PASS |
| 5 | Whole export v148 vs v149 | equal | 501 files each; 43 JSON metadata files differ in key order only; 0 content differences; all `.rbxm` model files byte-identical | PASS (exports only) |
| 6 | v148 export vs the TASK-001 hash inventory | no drift | all 40 hashes match `SCRIPT_INVENTORY_SHA256.txt` | PASS |
| 7 | Canary: read-before | nil | ok, nil | PASS |
| 8 | Canary: single write | succeeds | ok; version id `08DF2A11FA68EBDA.0000000001.08DF2A11FA68EBDA.01` | PASS |
| 9 | Canary: read-back | matches | ok; purpose, placeId, gameId, writtenAt all matched | PASS |

**Console output:** only the script return values quoted in `CANARY_RESULT.md`. **Screenshots / performance measurements:** none.

**Tests not performed:** ProfileStore anything; Play or multiplayer; production isolation proof beyond T0 (prohibited to query production); comparison of the live SaveTest place with the backup by hash; any comparison of the world/terrain between v148 and v149.

**Remaining regression risk:** none from this task (no game change).
