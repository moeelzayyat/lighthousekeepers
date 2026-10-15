# CHANGE MANIFEST — TASK-010

**No game script, Config value, saved data or published version changed; no DataStore write; no Play; nothing published; production and Outlaw City untouched.**

## SaveTest in-session changes (Edit mode; the backup `SaveTest_TASK-010_pre.rbxl` predates them)
| Instance | Change | SHA-256 after |
|---|---|---|
| `ServerStorage.TestOnly.SaveTestGuard` | added operation `R3_SERVER_SESSION` (flag false); replaced by a fresh clone so `require` sees the edit | `4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d` |
| `ServerStorage.TestOnly.R3ServerRunner` | new ModuleScript (inert) | `bff3b190a7559cdb3f8c32ea7211185715a54854de8d869eccb5a4f5778c5773` |
| `ServerScriptService.Server.Main` | **unchanged** (`Enabled = true`); disabling it is only proposed | — |

## Files on disk
`docs\audits\TASK-010\` (this package) with `luau\R3ServerRunner.luau`, `luau\SaveTestGuard.luau`, `luau\R3_run_command.luau` (draft), `luau\R3_status_command.luau` (draft).

## Rollback of this task's changes
Delete `ServerStorage.TestOnly.R3ServerRunner`, or restore `SaveTest_TASK-010_pre.rbxl`. The guard change is inert (one more flag, false).
