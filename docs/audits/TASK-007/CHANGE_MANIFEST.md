# CHANGE MANIFEST — TASK-007

**Changes were made only inside the SaveTest place (PlaceId 128620546156998, GameId 10770892134) and on the local disk. Production, Outlaw City, saved player data and every published version were not touched. Nothing was published by Claude.** No DataStore write was made in this task.

## 1. New instances in SaveTest (the only in-place changes)
| Path | Class | Size / SHA-256 | Purpose |
|---|---|---|---|
| `ServerStorage.TestOnly` | Folder | attribute `Purpose` | container; nothing references it |
| `ServerStorage.TestOnly.SaveTestGuard` | ModuleScript | 2,982 bytes, `4b2ae4732910ffeba9bed3e0034a378fb1f04d0acc747e7b1707c5ecf2f2c8a4` | identity guard (full source below) |
| `ServerStorage.TestOnly.Sha256` | ModuleScript | 2,666 bytes, `29d6bd69e3167d2fd6bbb398322c11736d8b7051fd579e1a1908688bc80ce13f` | pure-Luau SHA-256 used only for verification |
| `ServerStorage.TestOnly.MockBackend` | ModuleScript | 6,959 bytes, `88ad97d4d579d574abdb70e2ebba16911a0b28b00d9844931f921b1c2f309376` | in-memory fakes + loader for the vendor text |
| `ServerStorage.TestOnly.MockTests` | ModuleScript | 16,929 bytes, `cb4d22d7a599598f82bd9b3c7b0f35214932fe4bdcf4eb612a787238757196cf` | tests M0-M14 |
| `ServerStorage.TestOnly.ProfileStore` | ModuleScript | 64,654 bytes, `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F` | the vendor ProfileStore at pinned commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, **byte-identical to the pinned file** (not included in this package; hash proves identity) |

Dependencies affected: none (no existing script references the new ones). New remotes: none. Config values: none. Persistent data or economy values: none. Owner approval: given in chat for Phase B (D2/D3 follow-ups) and, for `execute_luau`, explicitly allowed by the owner after a permission-system block.

## 2. Test-only store names declared in the guard (no store was written)
`TEST_LK_ProfileStore_v2`, `TEST_LK_V1Fixtures`, `TEST_LK_IsolationCanary`. Forbidden by the guard: `LighthouseKeepers_PlayerData_v1`, `LighthouseKeepers_PlayerData_v2`.

## 3. Exact identity-guard code
`SaveTestGuard.luau` is included in full in this package (`luau/SaveTestGuard.luau`). Its key part: it asserts `game.PlaceId == 128620546156998` **and** `game.GameId == 10770892134`, rejects the production IDs, requires store names to start with `TEST_LK_`, and `requireRealProfileStore` errors unless `Guard.REAL_DATASTORE_APPROVED == true` (currently `false`).

## 4. Files on disk created by Claude or by the owner (all inside `C:\RobloxProjects\LighthouseKeepers\`)
| Path | Note |
|---|---|
| `docs\audits\TASK-007\` (this package) and `docs\audits\TASK-007\luau\*.luau` | source of the test-only scripts and the ad-hoc test |
| `backups\2026-10-14\savetest\SaveTest_pre-TASK-007.rbxl` | owner-saved pre-edit backup (verified) |
| `backups\2026-10-14\savetest\SaveTest_TASK-007_integrated.rbxl` | owner-saved post-install file (used for verification) |
| `work\savetest-pre007-export\`, `work\savetest-integrated-export\` | Rojo exports used for comparison (scratch; not part of the package) |
| `vendor-review\ProfileStore_45c9847\ProfileStore.luau` | pinned vendor file, unchanged |
| `docs\audits\TASK-004\SOURCE_VERIFICATION_ADDENDUM.md` | a correction notice was added at its top (content below unchanged); see `CORRIGENDUM_D2_ADDENDUM.md` |

Source diffs: the diff of the SaveTest place versus the pre-edit backup is exactly the 11 new files under `ServerStorage\TestOnly\` (verified by the export comparison in `TEST_EVIDENCE.md`).
