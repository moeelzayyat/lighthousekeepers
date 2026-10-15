# ADDENDUM — TASK-001 follow-up: backup opened in an isolated Studio window (2026-10-14)

**Result: the local `.rbxl` loads, and its content matches the live place at version 148 on every read-only check made.**

## What was done
- The owner opened `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl` themselves with File > Open from File, in its own Studio window. Claude did not open, save, play, publish or close anything.
- Instances were re-listed. The MCP list showed two windows: `LighthouseKeepers_2026-10-14_v148.rbxl` (the local copy, no place ID because it is a file) and Outlaw City (placeId 132163592957463). **The live "Lighthouse Keepers - Staging (placeId 132065051336560)" window did not appear in that list**, so the owner should confirm whether it is still open or was closed or replaced; Claude did not touch it either way.
- Nothing was sent to Outlaw City.
- Only read-only Edit-mode `execute_luau` calls were sent, and only to the instance named after the backup file. The call read properties and string lengths and wrote nothing. No Play, Save, Publish.

## Observed (read-only)
| Check | Local copy | Live place (read in TASK-001) |
|---|---|---|
| `game.PlaceId` / `game.GameId` | 0 / 0 (a file, not tied to the published universe, so no DataStore access is expected) | 132065051336560 / 10769064643 |
| `IsEdit` / `IsRunning` | true / false | true / false |
| ReplicatedStorage | 51 instances, 9 scripts | 51 / 9 |
| ServerScriptService | 15 instances, 14 scripts | 15 / 14 |
| StarterPlayer | 20 instances, 17 scripts | 20 / 17 |
| ServerStorage | 632 instances, 181 scripts; `Backups` folder has 20 children | 632 / 181; 20 |
| Workspace / Lighting | 90 instances / 6 instances | 90 / 6 |
| Script lengths: Hud, UiKit, Config, Server Main, PlayerData | 74224, 107266, 11187, 31478, 10259 | identical |

`ReplicatedStorage.Remotes` does not exist in the file, which matches expectations (the game creates its remotes at runtime; not separately verified in the live Edit tree).

## Limits
Not verified: terrain voxels (the Rojo warning about `Terrain.VoxelGridAssetContentMap` is still unexplained and terrain content was not compared), Play-mode behaviour of the copy (deliberately not run), and a content-hash match of every script. A visual check of the world in the copy was not made.

## Closing the copy
The owner closed the copy window. The instance list was re-read afterwards: it now shows `Lighthouse Keepers - Staging (placeId 132065051336560)` (a new instance id, as expected after a reopen) and Outlaw City (placeId 132163592957463). The backup copy is no longer listed. Nothing else changed.
