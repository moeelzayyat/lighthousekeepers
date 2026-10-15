# TEST EVIDENCE — TASK-005

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (place 128620546156998, universe 10770892134), Edit mode, not running. Players: none. Device/emulator: none. No Play session.

**Could any test have changed production DataStore values? No.** The only Roblox calls were reads inside the SaveTest universe, each preceded by an in-script assertion that PlaceId/GameId equal the SaveTest IDs and differ from production.

| # | Test | Expected | Observed | Result |
|---|---|---|---|---|
| 1 | List Studio instances (three times) | production, Outlaw City and SaveTest listed separately by place ID | list showed `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, `Private lighthouse keepers (128620546156998)` | PASS |
| 2 | Read identity of SaveTest | IDs differ from production | PlaceId 128620546156998, GameId 10770892134, creator user 11752219158, version 3, `IsEdit` true, `IsRunning` false | PASS |
| 3 | Content parity with the backup | counts and lengths equal | ReplicatedStorage 51/9, ServerScriptService 15/14, StarterPlayer 20/17, ServerStorage 632/181, Workspace 90, Lighting 6, Backups 20; Hud 74,224; PlayerData 10,259 | PASS (counts and lengths only, not content hashes) |
| 4 | Store name in the test place | unchanged | `local STORE_NAME = "LighthouseKeepers_PlayerData_v1"` | recorded |
| 5 | Original v148 backup unchanged | same hash | SHA-256 `6AF4E727...03B5C8`, same size and time | PASS |
| 6 | v149 and the savetest copy | identical | both `0C880E87...7307EF` | PASS |
| 7 | T0, attempt 1 (reads of `player_11752219158`, `__access_check`) | read nil | rejected: "502 ... Studio access to APIs is not allowed" (setting not yet effective); nothing read | no result |
| 8 | T0, attempt 2 after the owner saved the setting | read nil | both reads `ok = true`, value nil | PASS |

**Console output:** none beyond the above. **Screenshots / performance measurements:** none.

**Tests not performed:** the owner's Creator Hub ID cross-check against Studio, the production window's API setting, content hashes of scripts, any Play or multiplayer test, any DataStore write (including the optional canary), any ProfileStore test.

**Remaining risks:** see the report's limitations (production key not read; no documented isolation guarantee cited; test place still carries unmarked production code).
