# TEST EVIDENCE — TASK-001

**Environment:** Windows 11 PC, Roblox Studio (Edit mode, not playing), Lighthouse Keepers instance. Players: none (no Play session). Device/emulator: none. Could any test have changed production DataStore values? **No.** Nothing ran in Play, so no game server script executed; the only Studio script executions were read-only Edit-mode `execute_luau` calls that read `PlaceId`, `GameId`, `PlaceVersion`, `RunService` state, descendant counts, folder child counts and `#Source` lengths. No instance was written.

| # | Test | Expected | Observed | Result |
|---|---|---|---|---|
| 1 | List Studio instances (twice before work, once more before the length check) | Identify Lighthouse Keepers by place ID | First listing: only "Outlaw City (placeId 132163592957463)". After owner opened the game: "Lighthouse Keepers - Staging (placeId 132065051336560)" plus Outlaw City. Only the Lighthouse instance id was used. | PASS |
| 2 | Studio state | Edit mode | Edit; only Edit DataModel available | PASS |
| 3 | Read place identity | PlaceId 132065051336560, GameId 10769064643 | `PlaceId 132065051336560, GameId 10769064643, PlaceVersion 148, IsEdit true, IsRunning false` | PASS |
| 4 | Script and backup counts | Match handover docs (20 backups; ~37-40 scripts) | ReplicatedStorage 9, ServerScriptService 14, StarterPlayer 17 scripts; ServerStorage 181 scripts; Backups folder: 20 children | PASS |
| 5 | Backup file exists | File present | `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl`, 809,189 bytes | PASS |
| 6 | Backup header | Roblox binary place header | begins `<roblox!` | PASS |
| 7 | Backup parses | Rojo reads without error | `rojo syncback` completed; one warning: `Unknown value type ID 0x23 ... Terrain.VoxelGridAssetContentMap` | PASS (with warning) |
| 8 | Script export completeness | 9 + 14 + 17 = 40 `.luau` | 9 Shared, 14 Server, 17 Client files found | PASS |
| 9 | Export vs live content | Byte length of every exported script equals live `#Source` | All 40 equal (e.g. Hud 74224, UiKit 107266, Config 11187, Server Main 31478) | PASS (length only) |
| 10 | Backup opens in Studio / restores | — | Not performed | NOT TESTED |
| 11 | Content hash of live scripts vs export | — | Not performed | NOT TESTED |

**Console output:** none relevant (no Play). **Screenshots / performance measurements:** none taken.

**Tests not performed:** opening the `.rbxl` in a separate Studio window; content-hash comparison; any gameplay, multiplayer or mobile test.

**Remaining regression risk:** none from this task (no changes). Risk that the backup is incomplete for non-script content is unquantified until it is opened once in a scratch Studio session.
