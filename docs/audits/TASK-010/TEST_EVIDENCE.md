# TEST EVIDENCE — TASK-010 (preparation only)

**No server was started, no Play session, no real DataStore write, no MessagingService call, nothing published.** Every Studio call ran in the SaveTest window in Edit mode with both IDs asserted.

## 1. Identity checks
| Check | Result |
|---|---|
| Studio instances re-listed | production `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, SaveTest `(128620546156998)` |
| SaveTest asserted in-script | PlaceId 128620546156998, GameId 10770892134, not production, Edit mode, not running |

## 2. Backup
`backups\2026-10-14\savetest\SaveTest_TASK-010_pre.rbxl`, saved by the owner: 835,947 bytes, valid header, SHA-256 `52A1CF55AC91BD40BAD2E58415CD081BFE3BDE68B99872F451725612CF6E372D`.

## 3. Hashes (computed inside Studio; equal to the files in `luau/`)
| Script | SHA-256 |
|---|---|
| `TestOnly.ProfileStore` (pinned) | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |
| `TestOnly.SaveTestGuard` (updated: adds `R3_SERVER_SESSION`, flag false) | `4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d` |
| `TestOnly.R3ServerRunner` (new) | `bff3b190a7559cdb3f8c32ea7211185715a54854de8d869eccb5a4f5778c5773` |
| `TestOnly.R2SaveLoad`, `MockTests`, `MockBackend`, `Sha256` | unchanged from TASK-009 (`8a1cac7a…`, `2feea594…`, `88ad97d4…`, `29d6bd69…`) |
| game `PlayerData` | `8413e9ff…bdd2d8` (unchanged) |
Both new or edited scripts compile (compile-only check). The guard instance was replaced by a fresh clone so `require` would see the edit.

## 4. Auto-run inventory
All 99 `BaseScript`s listed in `SCRIPT_DISABLE_MANIFEST.md`. Only `ServerScriptService.Server.Main` runs at server start; the game's only DataStore code is `PlayerData`, reached through `Main`. The disable manifest is **not applied**: `Main.Enabled` is still `true`.

## 5. Inertness of the runner (proved by execution in Edit mode, no Play)
| Check | Result |
|---|---|
| Default flags | `R2_SAVE_LOAD = false`, `R3_SERVER_SESSION = false` |
| `startReal()` without approval | refused: "SaveTestGuard ABORT: operation not approved: R3_SERVER_SESSION" |
| `startReal()` with the flag set, but in Edit mode | refused before any DataStore call: "R3 ABORT: must run in a running server"; flag reset to false immediately |
| Status after both refusals | still `idle` |
| By construction | the runner is a ModuleScript in `ServerStorage`; Studio Play does not run it; nothing in the game requires it; a new Play server starts with the flag false |

## 6. Dry run on in-memory fakes (`R3.runMock`), no real calls
Steps 1, 2, 3a (skipped in mock), 3b (skipped in mock), 3c fixture read, 3d precheck, 4 session start, 5a save, 5b release: **passed**. Fake writes: `SetAsync ____PS/____PS` (fake probe), then 3 × `UpdateAsync TEST_LK_ProfileStore_v2/player_900000202`. The fixture `player_900000201` was read only.

## 7. Not done
Applying the disable manifest, starting Play, any real DataStore/MessagingService/BindToClose call, publishing.
