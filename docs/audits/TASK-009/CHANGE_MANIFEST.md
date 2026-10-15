# CHANGE MANIFEST — TASK-009

**No game script, Config value, production data or published version changed. Nothing was published. Production and Outlaw City were not touched.**

## SaveTest in-session changes (Studio, unsaved after the pre-TASK-009 backup)
| Instance | Change | Final SHA-256 |
|---|---|---|
| `ServerStorage.TestOnly.SaveTestGuard` | added per-operation approvals (`Guard.APPROVED`, `Guard.OPERATIONS`, `Guard.assertOperationApproved`); the instance was replaced by a fresh one so `require` would not return the cached old version | `9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab` (3,980 B) |
| `ServerStorage.TestOnly.R2SaveLoad` | new guarded entrypoint (store/key/operation restricted; mock and real paths); recreated once after changing the poll interval for real reads to 1 s | `8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25` (11,374 B) |
| Other TestOnly scripts | unchanged (`ProfileStore` `ad437372…0c95f`, `MockTests` `2feea594…a533`, `MockBackend` `88ad97d4…9376`, `Sha256` `29d6bd69…e13f`) | |

## Real DataStore writes (SaveTest universe only)
Store `TEST_LK_ProfileStore_v2`, key `player_900000201`: created and updated by ProfileStore during R2 (start, save, release, start, release). Final value: profile with `Data.pearls = 25`, `SessionLoadCount = 2`, no active session. No other key or store written. The probe key `____PS` was not written again.

## Local files
`docs\audits\TASK-009\` (this package), sources in `luau\` (entrypoint, guard, run command, status command), `backups\2026-10-14\savetest\SaveTest_TASK-009_pre.rbxl` (owner-saved), `work\savetest-pre009-export\` (scratch export).
