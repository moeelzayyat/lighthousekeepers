# Every operation that could execute a DataStore write, expected real writes, and next approvals (TASK-007)

Source: the pinned `ProfileStore.luau` (commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, SHA-256 `AD437372...0C95F`), read in full, line numbers from that file. Installed copy is byte-identical (see `TEST_EVIDENCE.md`). **Nothing in this table was executed against a real DataStore in this task.**

## 1. Library operations that write (or can write)
| # | Operation | Where (line) | Real write when | Notes |
|---|---|---|---|---|
| W1 | **Studio initialization probe**: `GetDataStore("____PS"):SetAsync("____PS", os.time())` | 2072-2111 (call at 2080) | at module load (top level) whenever `RunService:IsStudio()` is true | unconditional in Studio, runs even for `ProfileStore.Mock` use; writes into the universe whose Studio API access is on; with API access off the call fails and the module switches to mock mode |
| W2 | `ProfileStore:StartSessionAsync` -> `data_store:UpdateAsync` | 1364-1631 (UpdateAsync via 507-656, call at 625) | every real session start; also on a brand-new key, on a legacy-shaped record (overwrite), and when a cancel arrives mid-load | a Cancel that is already true at the first check writes nothing (M3, M11) |
| W3 | `SaveProfileAsync` -> `UpdateAsync` | 709-938 (call at 741) | autosave, `Profile:Save()`, `Profile:EndSession()`, external takeover, shutdown | release saves repeat until success |
| W4 | Autosave on Heartbeat | 2115-2153 | every `AUTO_SAVE_PERIOD` (default 300 s) per loaded profile, whether or not data changed | |
| W5 | `Profile:Save()` | 1172-1191 | on demand | |
| W6 | `Profile:EndSession()` | 1090-1094 | on demand | |
| W7 | Shutdown release (`BindToClose`) | 2208-2239 | when a real server or a Studio test session stops with active profiles | |
| W8 | `ProfileStore:MessageAsync` -> `UpdateAsync` | 1633-1729 | on demand | not planned for use |
| W9 | `Profile:SetAsync()` (view-mode profiles only) | 1128-1136 | on demand | overwriting write; not planned |
| W10 | `ProfileStore:RemoveAsync` -> `data_store:RemoveAsync` | 1809-1867 (call at 1858) | on demand | destructive; **never used** by this project |

## 2. Reads and non-DataStore network calls
- Reads only: `ProfileStore:GetAsync` (`GetAsync` at 1617, or `GetVersionAsync` at 608; the shared transform runs locally and does not write when `is_get_call` is true, lines 603-621), `VersionQuery` (`ListVersionsAsync` at 1955).
- MessagingService (not a DataStore): `SubscribeAsync` at 1340, `PublishAsync` at 1585 and 1711.

## 3. What the installed test scaffolding can and cannot do
- `SaveTestGuard.requireRealProfileStore` asserts both exact SaveTest IDs, then errors unless `REAL_DATASTORE_APPROVED == true` (currently false). It is the only sanctioned path to the real module. Test M14 proved the three guard behaviours (forbidden store name rejected, non-`TEST_LK_` name rejected, real require blocked while unapproved).
- `MockBackend` / `MockTests` run the vendor **text** with `game` shadowed by an in-memory proxy; they never `require` the real ModuleScript, so W1-W10 only ever hit fakes (verified by running them: zero real DataStore calls were made; M0 shows the `____PS` probe landing on the fake).
- Nothing outside `ServerStorage.TestOnly` references the new scripts (checked in the exported place file).
- A normal Play session in SaveTest would load none of the new scripts. It would still run the game's own `PlayerData`, which writes to the SaveTest universe's `LighthouseKeepers_PlayerData_v1` store as production code does; not changed in this task.

## 4. Test store names and keys (all SaveTest universe only)
| Name | Purpose |
|---|---|
| `TEST_LK_ProfileStore_v2` | ProfileStore profiles (keys `player_9000xxxxx` synthetic) |
| `TEST_LK_V1Fixtures` | legacy-shaped (v1) fixture records for overwrite/importer tests |
| `TEST_LK_IsolationCanary` | already holds the approved canary marker `isolation_canary_v1` |
| `____PS` | created by the library's Studio probe (W1) when the real module loads |

## 5. Expected real writes if the owner approves the next stage (nothing approved yet)
| Step | Writes (SaveTest universe only) |
|---|---|
| R1 load the real module once in the SaveTest Studio window | W1: 1 write to store `____PS`, key `____PS` |
| R2 `New` + `StartSessionAsync` on a fresh synthetic key | 1 `UpdateAsync` on `TEST_LK_ProfileStore_v2` |
| R3 `Save` / `EndSession` | 1-2 `UpdateAsync` per profile |
| R4 legacy overwrite test on a **fixture** key only (never `player_11752219158`) | seed 1 write in `TEST_LK_V1Fixtures`-shaped record, then the overwrite write |
| R5 two-session conflict tests | require **published servers** (Studio sessions share an empty or identical `JobId`, see M13); the owner has declined manual publish steps so far |
| R6 full test matrix rows C1-C29 | counted per test in the matrix v2 |

## 6. Next approval requests (each needs its own explicit yes)
1. Approve **R1**: load the real pinned ProfileStore module in the SaveTest window (one write to store `____PS`). Until then `REAL_DATASTORE_APPROVED` stays false.
2. Approve **R2-R4**: real writes to `TEST_LK_ProfileStore_v2` / fixture keys in SaveTest.
3. Decide whether SaveTest may be **published** for the two-server tests (C1-C3, C7, C8, C10), or whether those rows are dropped or replaced.
4. Decide **D1** (library vs hardened custom), **D4** (turn production Studio API access OFF; the owner reports it is ON, which means any Play or script run in the production window can read or write live data), and D5-D13 from `TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md`.
5. Confirm whether the SaveTest place should stay with these test scripts installed, or be reverted to `SaveTest_pre-TASK-007.rbxl`.

## 7. Remaining risks
- The mock fakes are my own code: they model `UpdateAsync` re-running poorly (the transform runs once per call), have no throttling, and treat MessagingService as instant. Mock results show the library's logic, not real DataStore behaviour.
- The timing tests (M7) are scaled down 50x; real steal timing (about 45 s) is untested.
- The mock harness replaces `game` for the vendor chunk; it does not prove how the library behaves with the real `DataStoreService`.
- The permission system blocked one read-only `execute_luau` call as "Untrusted Code Integration" during installation; after the owner's explicit allowance it worked. Future runs may be blocked again and need the owner's settings.
- The vendor file was transcribed through chunked edits; byte identity was proven from the saved place file, not assumed.
