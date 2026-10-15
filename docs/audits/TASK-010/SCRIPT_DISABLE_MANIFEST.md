# Proposed script-disable manifest for SaveTest (TASK-010) — PROPOSAL ONLY, NOT APPLIED

## What would run automatically when a server starts in SaveTest
Inventory read from the SaveTest window (Edit mode, IDs asserted), all 99 `BaseScript`s:
| Location | Count | Runs at server start? |
|---|---|---|
| `ServerScriptService.Server.Main` (Script, Enabled, RunContext Legacy) | 1 | **Yes.** It is the only server entry point; it requires every server module (`PlayerData`, `GameState`, `IslandBuilder`, `LobbyBuilder`, services). |
| `ServerStorage.Backups.*` Scripts and LocalScripts (Legacy RunContext) | 85 | No: Legacy scripts do not run from `ServerStorage`. |
| `StarterPlayer.StarterPlayerScripts.Client.*` LocalScripts | 13 (12 enabled) | Only on a **client**, when a player joins (Studio Play adds the owner's avatar). Client code cannot use DataStores. |
| `ServerStorage.TestOnly.*` | ModuleScripts only | Never by themselves. |
| Workspace, ReplicatedFirst, StarterGui, StarterPack, StarterCharacterScripts | 0 scripts | — |

Source search of the exported game (`src\`): the only DataStore use in game code is `ServerScriptService.Server.PlayerData` (`GetDataStore`, line 291; `BindToClose`, line 332); no game code uses MessagingService or MemoryStore. `PlayerData` is reached only through `Main`.

## What would happen in a Studio Play session if nothing is disabled
- `PlayerData.init`: one `GetAsync("__access_check")` on the SaveTest copy of `LighthouseKeepers_PlayerData_v1` (read).
- The owner's avatar joins: `PlayerData` loads `player_11752219158` from that SaveTest store (read), and game systems may mark the profile changed; on Stop, a **write** to `LighthouseKeepers_PlayerData_v1/player_11752219158` in the SaveTest universe is possible.
- Gameplay starts (lobby, island build, run loop, remotes).

## Proposed smallest set to disable
| # | Instance | Change | Effect |
|---|---|---|---|
| 1 | `ServerScriptService.Server.Main` | `Enabled = false` (SaveTest only) | No game server code runs: no `PlayerData`, no DataStore call from the game, no gameplay loop, no remotes. Client LocalScripts still start for the avatar but wait forever for the server's remotes; they cannot reach DataStores. |
Nothing else needs disabling.

## Rollback
Set `ServerScriptService.Server.Main.Enabled = true` in the SaveTest window (or restore `backups\2026-10-14\savetest\SaveTest_TASK-010_pre.rbxl`). Production is not involved.

## Not changed by this proposal
Game code contents, `PlayerData`, economy, gameplay, any production asset.
