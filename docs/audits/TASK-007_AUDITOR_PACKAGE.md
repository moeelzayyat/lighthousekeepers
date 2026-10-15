# TASK-007 AUDITOR PACKAGE (combined plain-text version)

ProfileStore test integration for Lighthouse Keepers, SaveTest only (place 128620546156998, universe 10770892134). Production and Outlaw City untouched; no real DataStore write was made in this task; the real ProfileStore module was never required (mock tests ran the vendor text against in-memory fakes). The vendor file itself (64,654 bytes, SHA-256 AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F) is not included; its identity with the installed copy is proven by hash. All test-only source is included in full.

## TABLE OF CONTENTS
1. TASK-007/AUDITOR_REPORT.md
2. TASK-007/CHANGE_MANIFEST.md
3. TASK-007/TEST_EVIDENCE.md
4. TASK-007/AUDITOR_QUESTIONS.md
5. TASK-007/WRITE_OPERATIONS_AND_NEXT_APPROVALS.md
6. TASK-007/CORRIGENDUM_D2_ADDENDUM.md
7. TASK-007/luau/SaveTestGuard.luau
8. TASK-007/luau/MockBackend.luau
9. TASK-007/luau/MockTests.luau
10. TASK-007/luau/adhoc_cancel_midflight.luau
11. TASK-007/luau/sha256_lib.luau

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-007/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-007: ProfileStore test integration (SaveTest only)

- **Date:** 2026-10-14
- **Authorized target only:** SaveTest place 128620546156998, universe 10770892134. Production (132065051336560 / 10769064643) and Outlaw City untouched.
- **Owner/auditor request:** Phase A safety and backup; Phase B test-only integration (pinned ProfileStore as a ModuleScript in SaveTest, dedicated test store, identity guard, original `PlayerData` untouched, no Rojo/MCP sync to production, parse-check, inspect exact changes); Phase C testing preparation (record shape, cancellation, ownership, legacy handling; mock backend first; list every operation that could write, including the Studio probe; no real writes without separate approval); Phase D this package. Stop after preparation and safe verification.

## Phase A: safety and backup
Re-discovered all Studio windows; SaveTest positively identified by both IDs inside scripts before every edit-adjacent run. Production's Studio API access: **owner reports ON** (also ON for SaveTest); Claude cannot read it and did not access production DataStores. Fresh pre-edit SaveTest backup `SaveTest_pre-TASK-007.rbxl` verified (40 of 40 scripts identical to v148). The pinned vendor file still matched its recorded SHA-256 and was kept unchanged in `vendor-review\`.

## Phase B: what was installed (all under `ServerStorage.TestOnly`, none referenced by the game)
`SaveTestGuard`, `Sha256`, `MockBackend`, `MockTests`, and `ProfileStore` (the vendor text). **The installed `ProfileStore` is byte-identical to the pinned file**, proven from the owner's saved place file (SHA-256 `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F`, 64,654 bytes). Only 11 new files differ from the pre-edit export; nothing else changed. The original `PlayerData` and all game scripts are untouched, and `LighthouseKeepers_PlayerData_v1` is not referenced by any new script (the guard forbids it). All five scripts compile (parse-check, never run). Nothing was synchronized to production, nothing was published.

## Phase C: tests prepared and run safely
A mock backend runs the vendor text against in-memory fakes, so the real module (whose Studio probe writes to a real store named `____PS`) is never loaded. 15 tests were run: 14 passed as written and one (M3) differed from my expectation for an understood reason. Results cover record shape, session ownership and takeover (responsive, unresponsive, dead lock), fencing after takeover, failed-save/release retry behaviour, shutdown, duplicate start, and the guard. The legacy-record overwrite was reproduced on a fake record. Full list of every operation that could write, with source lines, is in `WRITE_OPERATIONS_AND_NEXT_APPROVALS.md`.

## Findings from the tests (important)
1. **Correction to my earlier addendum.** A `Cancel` that is true from the first call prevents any write; the legacy record is overwritten (and an empty record created for a new key) only when Cancel turns true after the load has started (`CORRIGENDUM_D2_ADDENDUM.md`). The recommendation is unchanged.
2. Legacy-record destruction is confirmed on fakes (M2) and `GetAsync` cannot read v1 records (M4: returns template data, no write).
3. Takeover, fencing, dead-lock and shutdown behave as the source reading predicted; a failed ordinary save is not retried until the next save, while release saves retry.
4. Two servers with the same `JobId` cannot be told apart (M13, logic only), so real two-session tests need published servers.

## Architecture / gameplay / security / save-data / performance implications
No game change. No save-data change: the SaveTest place gained inert scripts in `ServerStorage`. The new scripts add about 94 KB of source to the SaveTest place only.

## Known limitations
Fakes are my own code and are simplified (no throttling, instant messaging, single transform run); scaled timings; real module behaviour with real DataStores untested; vendor text is third-party code read once by Claude and not independently reviewed; one in-Studio read-only check was blocked by the permission system and was replaced by verification from the owner-saved file.

## Outstanding problems / next approvals
See `WRITE_OPERATIONS_AND_NEXT_APPROVALS.md` section 6: approve loading the real module (one `____PS` write), approve the first real writes in `TEST_LK_ProfileStore_v2`, decide on publishing SaveTest for two-server tests, and decisions D1 and D4-D13. Production API access being ON strengthens D4.

## Ready for acceptance?
Yes as a preparation and safe-verification milestone. The real persistence test matrix has not started and is not authorized.
=== END FILE ===

=== FILE: TASK-007/CHANGE_MANIFEST.md ===
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
=== END FILE ===

=== FILE: TASK-007/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-007

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (PlaceId 128620546156998, GameId 10770892134), Edit mode, no Play session. Players: none. Device/emulator: none.
**Could any test have changed production DataStore values? No.** No call targeted a production instance. No real `DataStoreService` call was made in this task: the mock tests ran the vendor text against in-memory fakes, and the real `ProfileStore` ModuleScript was never required.

## 1. Identity and backups
| # | Check | Result |
|---|---|---|
| 1 | Studio instances re-listed (several times) | production `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, SaveTest `(128620546156998)`; production's instance id changed during the task (cause not established); Outlaw City untouched |
| 2 | SaveTest identified by both IDs inside scripts, asserted before every edit-adjacent run | PlaceId 128620546156998, GameId 10770892134, not production |
| 3 | Production Studio API access | **owner-reported ON** (Claude cannot read it); also owner-reported ON for SaveTest. Recorded as a live-data risk for any Play or script in the production window |
| 4 | Pre-edit SaveTest backup `backups\2026-10-14\savetest\SaveTest_pre-TASK-007.rbxl` | 809,189 bytes, SHA-256 `D2AC31D6E1ACCABF86DBB51D71360DEF798770184D95F4291A24E2779BA9B05A`, valid header; Rojo export: 501 files, 40 of 40 scripts identical to v148, 5 JSON files differ only in key order |
| 5 | Pinned vendor file before use | `vendor-review\ProfileStore_45c9847\ProfileStore.luau` size 64,654, SHA-256 `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F` equals the recorded value, unchanged |

## 2. Installation verification (the main result)
| # | Check | Result |
|---|---|---|
| 6 | Owner saved the SaveTest window to `backups\2026-10-14\savetest\SaveTest_TASK-007_integrated.rbxl` (owner typed `.rblx` in chat; the file on disk is `.rbxl`) | 832,148 bytes, valid header, SHA-256 `45CF80C3784E9C8C13DFC68387D8C205C4C9B7B82F9DC4ED0E9FFADA3FAB54D6` |
| 7 | Rojo export of that file: installed `ServerStorage\TestOnly\ProfileStore.luau` | **64,654 bytes, SHA-256 `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F`: identical to the pinned file** |
| 8 | Other installed scripts vs files on disk | `SaveTestGuard`, `MockBackend`, `MockTests`, `Sha256` all byte-identical |
| 9 | What changed versus the pre-edit export | exactly 11 new files, all under `ServerStorage\TestOnly\`; 5 JSON key-order-only differences as before; no other file differs |
| 10 | References to the new scripts outside `TestOnly` | none (grep over the exported tree) |
| 11 | In-Studio block hashes during installation (own SHA-256 helper, vectors "abc" and "" verified) | all 100-line blocks of lines 1-1400 matched the pinned blocks; the helper scripts matched their file hashes; later blocks were verified by item 7 instead (one in-Studio check was denied by the permission system, see 14) |
| 12 | Parse-check (`loadstring`, compile only, never called), run after the owner's explicit allowance | `SaveTestGuard`, `Sha256`, `MockBackend`, `MockTests`, `ProfileStore`: all compile; no leftover `@NEXT@` marker |
| 13 | Installed script line count | `ProfileStore` has 2,243 lines, last line `return ProfileStore` |
| 14 | A read-only hash check was denied by the permission system as "Untrusted Code Integration" mid-install. Claude did not retry or work around it; the owner then explicitly allowed `execute_luau` for the parse-check and fake-backend tests in the SaveTest window | recorded |

## 3. Fake-backend test results (vendor text vs in-memory fakes; real module never required)
| Test | Result | Observation |
|---|---|---|
| M0 Studio probe and options | PASS | the `____PS` write landed on the **fake** store exactly once; `SetExperimentalFeatures({v2=true})` called; state "Access"; 1 `BindToClose` callback registered |
| M1 record shape | PASS | top-level keys `Data`, `GlobalUpdates`, `MetaData`; `SessionLoadCount` 1; `ActiveSession` = {PlaceId, JobId, GUID}; release wrote final data and cleared the session |
| M2 legacy v1-shaped record, normal start | PASS (reproduced) | loaded profile has template data (pearls 0); stored record now wrapped, legacy top-level fields gone, seeded 500 pearls lost; `OnOverwrite` fired once |
| M3 legacy record + Cancel true from the first call | FAIL against my expectation, explained | returned nil and the record was **unchanged** (legacy pearls kept): an already-true Cancel stops the loop before any DataStore call. My earlier addendum statement was too strong (see `CORRIGENDUM_D2_ADDENDUM.md`) |
| M3b (ad hoc) legacy record + Cancel false then true mid-load | observed | returned nil **and the legacy record was overwritten** (wrapper present, legacy pearls gone, stored pearls 0) |
| M4 `GetAsync` view of a legacy record | PASS | returns a profile with template data (pearls 0), the stored legacy record unchanged, 0 writes |
| M5 two servers, responsive holder | PASS | second server took over in 0.24 s (scaled constants); it saw the holder's unsaved change (11); holder's session ended; `SessionLoadCount` 2; active job JOB_B; 1 message published |
| M6 fencing after takeover | PASS | stale holder's later write ignored (stored 50); stale holder inactive |
| M7 unresponsive holder (messages dropped, scaled constants 0.2/0.2/0.8 s) | PASS | takeover after 1.07 s; the holder's late write (777) did not land (stored 4); holder ended; active job JOB_B |
| M8 dead lock (`LastUpdate` 1000 s old) | PASS | immediate takeover (< 1 ms) with the stored data |
| M9 failed save not retried; release retries | PASS | injected failure on a normal `Save`: stored value unchanged after 1.5 s (no self-retry); release with 2 injected failures succeeded in 3.07 s (1 s + 2 s backoff) |
| M10 second start for an active key | PASS | throws "is already loaded in this session" |
| M11 new key + Cancel true from the first call | PASS | returns nil, no record created |
| M11b (ad hoc) new key + Cancel false then true | observed | returns nil but **creates a record** with template data and no active session |
| M12 shutdown | PASS | both profiles released in parallel (0.43 s for two 0.4 s calls); `IsClosing` true; later start returns nil |
| M13 equal JobId on two "servers" | PASS (weakness shown) | both profiles active at once; a lock keyed on PlaceId+JobId cannot distinguish servers with the same JobId (logic demonstration only; I did not establish what `game.JobId` is in Studio) |
| M14 guard behaviours | PASS | forbidden production store name rejected; non-`TEST_LK_` name rejected; real-module require blocked while unapproved; name lengths 23/18/23 (limit 50); approval flag false |

14 of the 15 listed tests (M0 to M14) passed as written; M3 differed from my expectation for an understood reason; M3b and M11b were run ad hoc to settle the question (`luau\adhoc_cancel_midflight.luau`).

## 4. Not performed (all need explicit approval, see `WRITE_OPERATIONS_AND_NEXT_APPROVALS.md`)
Loading the real module; any real DataStore write beyond the earlier canary; published-server tests; real throttling, latency and timing; ProfileStore against real records; Play sessions; production or Outlaw City anything.

## 5. Console output, screenshots, performance
Only the script return values quoted above. No screenshots or performance measurements.
=== END FILE ===

=== FILE: TASK-007/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-007

1. **Is the mock-backend approach acceptable evidence?** The vendor text ran against my own in-memory fakes with `game` shadowed. It shows the library's logic (record shape, fencing, takeover, retries) but not real DataStore behaviour. Which real-DataStore rows must still pass before you accept the library?
2. **Probe write (W1).** Loading the real module in a Studio window with API access performs a real write to a store named `____PS`. Is one such write in SaveTest acceptable as the first approved real write (R1), or should the library never be loaded in Studio at all and be tested only on published test servers?
3. **Publishing for two-server tests.** Session-conflict tests need published servers because `game.JobId` cannot be relied on to differ in Studio. The owner has declined manual publish steps so far. Do you want those rows dropped, replaced (for example a scripted Open Cloud flow, which would need credentials that I will not request), or done with a guided, checklist-driven publish to SaveTest only?
4. **Cancel semantics.** Given the corrected finding (a cancel that arrives mid-load still lets the overwrite happen), do you want the adapter to forbid `Cancel` entirely when a store might still hold legacy data, or is "never use a store name that holds v1 data" enough?
5. **Production API access is ON** (owner-reported). Should D4 (turn it off) be a precondition before the real module is loaded anywhere?
6. **The vendor text.** It is 2,243 lines of third-party code. Do you want an independent reviewer on lines 521-650, 709-938, 1364-1631 and 2208-2239 before real use?
7. **Leave or revert the SaveTest scripts?** The new scripts are inert, but SaveTest now differs from production code. Keep them for the next stage, or revert to `SaveTest_pre-TASK-007.rbxl`?

No further concern has been invented; items 2, 3 and 5 are the real forks.
=== END FILE ===

=== FILE: TASK-007/WRITE_OPERATIONS_AND_NEXT_APPROVALS.md ===
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
=== END FILE ===

=== FILE: TASK-007/CORRIGENDUM_D2_ADDENDUM.md ===
# Corrigendum to TASK-004 `SOURCE_VERIFICATION_ADDENDUM.md` (found by TASK-007 mock tests)

| # | Statement in the addendum | What the tests showed | Corrected statement |
|---|---|---|---|
| 1 | Section 2, finding 1: the overwrite of a legacy record "happens even when the load is cancelled because the overwrite flag does not depend on `Cancel`" | M3: a legacy flat record plus a `Cancel` that returns true on its **first** call: `StartSessionAsync` returned nil and the stored record was **unchanged** (legacy pearls still present). The reason is that the load loop's condition calls `cancel_condition()` first, so with an already-true Cancel the loop body, and therefore the DataStore call, never runs (`ProfileStore.luau` line 1417). | A `Cancel` that is true from the start causes **no write**. The legacy record is still overwritten when `Cancel` turns true **after** the load has started, because the transform replaces non-conforming records regardless of Cancel: ad-hoc M3b (Cancel false on its first call, true afterwards) returned nil **and** replaced the legacy record (`legacyPearlsStillThere = false`, stored `Data.pearls = 0`). So cancelling does not protect an old record; refusing to point the library at the v1 store does. |
| 2 | Section 3, item I: "A cancelled load for a brand-new player can still create an empty record with no active session" | M11: new key with `Cancel` true from the first call: nothing created (`recordCreated = false`). Ad-hoc M11b (Cancel false first, true afterwards): record created with template `Data` and no active session. | True only for a cancel that arrives after the load started. |
| 3 | Everything else in the addendum | M0-M2, M4-M14 reproduced or agreed with the described behaviour on the in-memory fakes (see `TEST_EVIDENCE.md`). | unchanged |

Impact: none on the recommendation. The legacy-record risk stands, and a "cancelled load is safe" argument would be wrong; the safe rule remains "never use a store name that holds v1-shaped records".
=== END FILE ===

=== FILE: TASK-007/luau/SaveTestGuard.luau ===
-- ServerStorage.TestOnly.SaveTestGuard
-- SAVETEST ONLY. Never copy this into the production place.
--
-- Purpose: refuse to initialize ProfileStore or touch any DataStore unless BOTH exact SaveTest IDs match,
-- the production IDs do not, the store name is a TEST_LK_ name, and the owner has flipped the approval flag.
-- Nothing in the game requires this module. It is only used by hand-run test code.

local Guard = {}

Guard.SAVETEST_PLACE_ID = 128620546156998
Guard.SAVETEST_GAME_ID = 10770892134 -- universe id

Guard.PROD_PLACE_ID = 132065051336560
Guard.PROD_GAME_ID = 10769064643

-- Test-only store names (all start with TEST_LK_)
Guard.TEST_STORE_NAME = "TEST_LK_ProfileStore_v2" -- ProfileStore profiles
Guard.TEST_V1_FIXTURE_STORE = "TEST_LK_V1Fixtures" -- legacy-shaped fixtures for the importer / overwrite tests
Guard.CANARY_STORE_NAME = "TEST_LK_IsolationCanary" -- already holds the approved canary marker

-- Never point anything at these (the production store name):
Guard.FORBIDDEN_STORE_NAMES = {
	["LighthouseKeepers_PlayerData_v1"] = true,
	["LighthouseKeepers_PlayerData_v2"] = true,
}

-- Flip to true ONLY with the owner's explicit written approval of the specific real DataStore writes.
-- While false, requireRealProfileStore() always errors, so the real ProfileStore module (whose Studio
-- initialization probe performs a real write to a store named "____PS") can never be loaded by accident.
Guard.REAL_DATASTORE_APPROVED = false

function Guard.assertSaveTest()
	assert(
		game.PlaceId == Guard.SAVETEST_PLACE_ID,
		"SaveTestGuard ABORT: PlaceId is not the SaveTest place: " .. tostring(game.PlaceId)
	)
	assert(
		game.GameId == Guard.SAVETEST_GAME_ID,
		"SaveTestGuard ABORT: GameId is not the SaveTest universe: " .. tostring(game.GameId)
	)
	assert(
		game.PlaceId ~= Guard.PROD_PLACE_ID and game.GameId ~= Guard.PROD_GAME_ID,
		"SaveTestGuard ABORT: production IDs detected"
	)
	return true
end

function Guard.assertStoreName(storeName)
	assert(type(storeName) == "string", "SaveTestGuard ABORT: store name must be a string")
	assert(string.sub(storeName, 1, 8) == "TEST_LK_", "SaveTestGuard ABORT: store name must start with TEST_LK_: " .. storeName)
	assert(Guard.FORBIDDEN_STORE_NAMES[storeName] ~= true, "SaveTestGuard ABORT: forbidden store name: " .. storeName)
	return true
end

-- The ONLY sanctioned way to load the real ProfileStore module.
function Guard.requireRealProfileStore(profileStoreModule)
	Guard.assertSaveTest()
	assert(
		Guard.REAL_DATASTORE_APPROVED == true,
		"SaveTestGuard ABORT: real DataStore writes are not approved (REAL_DATASTORE_APPROVED is false)"
	)
	return require(profileStoreModule)
end

-- Creates a store through the real ProfileStore module, after every check.
function Guard.newRealStore(profileStoreModule, storeName, template)
	Guard.assertStoreName(storeName)
	local ProfileStore = Guard.requireRealProfileStore(profileStoreModule)
	return ProfileStore.New(storeName, template)
end

return Guard
=== END FILE ===

=== FILE: TASK-007/luau/MockBackend.luau ===
-- ServerStorage.TestOnly.MockBackend
-- SAVETEST ONLY. In-memory fakes of DataStoreService, MessagingService and RunService, plus a loader that
-- runs the vendor ProfileStore SOURCE TEXT with `game` shadowed by a proxy. The real ModuleScript is never
-- required, so the real DataStoreService and its Studio probe write are never reached.
--
-- Nothing in the game requires this module. It makes no real DataStore or MessagingService call.

local MockBackend = {}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end
MockBackend.deepCopy = deepCopy

function MockBackend.newWorld()
	return {
		stores = {}, -- [storeName] = { data = { [key] = value }, versions = { [key] = n } }
		subscribers = {}, -- messaging subscribers
		published = {}, -- every PublishAsync (topic, data)
		writes = {}, -- every successful write { store, key, op }
		calls = {}, -- every datastore call { op, store, key }
		failures = {}, -- [op] = number of upcoming calls that must fail
		latency = 0, -- seconds added to every datastore call
		dropMessages = false, -- true = messaging delivers nothing (simulates an unresponsive holder)
	}
end

function MockBackend.seed(world, storeName, key, value)
	local s = world.stores[storeName]
	if s == nil then
		s = { data = {}, versions = {} }
		world.stores[storeName] = s
	end
	s.data[key] = deepCopy(value)
	s.versions[key] = (s.versions[key] or 0) + 1
end

function MockBackend.record(world, storeName, key)
	local s = world.stores[storeName]
	return s and s.data[key] or nil
end

local function keyInfoFor(version)
	return {
		Version = "mock." .. tostring(version),
		CreatedTime = 0,
		UpdatedTime = 0,
		GetMetadata = function()
			return {}
		end,
		GetUserIds = function()
			return {}
		end,
	}
end

local function newFakeStore(world, name)
	local backing = world.stores[name]
	if backing == nil then
		backing = { data = {}, versions = {} }
		world.stores[name] = backing
	end

	local function begin(op, key)
		table.insert(world.calls, { op = op, store = name, key = key })
		if world.latency and world.latency > 0 then
			task.wait(world.latency)
		end
		local n = world.failures[op]
		if n ~= nil and n > 0 then
			world.failures[op] = n - 1
			error("MOCK DataStore failure injected for " .. op)
		end
	end

	local store = {}

	function store:GetAsync(key)
		begin("GetAsync", key)
		local v = backing.data[key]
		if v == nil then
			return nil, nil
		end
		return deepCopy(v), keyInfoFor(backing.versions[key] or 0)
	end

	function store:UpdateAsync(key, transform)
		begin("UpdateAsync", key)
		local old = backing.data[key]
		local oldInfo = old ~= nil and keyInfoFor(backing.versions[key] or 0) or nil
		local new, userIds, meta = transform(deepCopy(old), oldInfo)
		if new == nil then
			return nil
		end
		backing.data[key] = deepCopy(new)
		backing.versions[key] = (backing.versions[key] or 0) + 1
		table.insert(world.writes, { store = name, key = key, op = "UpdateAsync" })
		return deepCopy(new), keyInfoFor(backing.versions[key])
	end

	function store:SetAsync(key, value)
		begin("SetAsync", key)
		backing.data[key] = deepCopy(value)
		backing.versions[key] = (backing.versions[key] or 0) + 1
		table.insert(world.writes, { store = name, key = key, op = "SetAsync" })
		return "mock." .. tostring(backing.versions[key])
	end

	function store:RemoveAsync(key)
		begin("RemoveAsync", key)
		local old = backing.data[key]
		backing.data[key] = nil
		table.insert(world.writes, { store = name, key = key, op = "RemoveAsync" })
		return deepCopy(old)
	end

	function store:GetVersionAsync()
		error("MOCK: GetVersionAsync is not supported")
	end

	function store:ListVersionsAsync()
		error("MOCK: ListVersionsAsync is not supported")
	end

	return store
end

function MockBackend.newDataStoreService(world)
	local service = {}
	function service:GetDataStore(name, scope, options)
		table.insert(world.calls, { op = "GetDataStore", store = name })
		return newFakeStore(world, name)
	end
	return service
end

function MockBackend.newMessagingService(world)
	local service = {}
	function service:SubscribeAsync(topic, callback)
		local sub = { topic = topic, callback = callback, connected = true }
		table.insert(world.subscribers, sub)
		return {
			Disconnect = function()
				sub.connected = false
			end,
		}
	end
	function service:PublishAsync(topic, data)
		table.insert(world.published, { topic = topic, data = deepCopy(data) })
		if world.dropMessages then
			return
		end
		for _, sub in ipairs(world.subscribers) do
			if sub.connected and sub.topic == topic then
				task.spawn(sub.callback, { Data = deepCopy(data), Sent = os.time() })
			end
		end
	end
	return service
end

local function newFakeRunService()
	local event = Instance.new("BindableEvent")
	local service = { Heartbeat = event.Event, _event = event }
	function service:IsStudio()
		return true
	end
	return service
end

-- identity = { PlaceId = number, JobId = string }; one identity = one logical "server".
function MockBackend.loadVendor(source, world, identity)
	assert(type(source) == "string" and #source > 1000, "vendor source missing")
	identity.closeCallbacks = identity.closeCallbacks or {}

	local realGame = game
	local realInstance = Instance
	local services = {
		DataStoreService = MockBackend.newDataStoreService(world),
		MessagingService = MockBackend.newMessagingService(world),
		RunService = newFakeRunService(),
	}

	local fakeGame = setmetatable({}, {
		__index = function(_, key)
			if key == "GetService" then
				return function(_, name)
					local fake = services[name]
					if fake ~= nil then
						return fake
					end
					return realGame:GetService(name)
				end
			elseif key == "PlaceId" then
				return identity.PlaceId
			elseif key == "JobId" then
				return identity.JobId
			elseif key == "BindToClose" then
				return function(_, fn)
					table.insert(identity.closeCallbacks, fn)
				end
			end
			local value = realGame[key]
			if type(value) == "function" then
				return function(_, ...)
					return realGame[key](realGame, ...)
				end
			end
			return value
		end,
	})

	local fakeInstance = {
		new = function(className, ...)
			if className == "DataStoreOptions" then
				local options = {}
				function options:SetExperimentalFeatures(features)
					identity.experimentalFeatures = deepCopy(features)
				end
				return options
			end
			return realInstance.new(className, ...)
		end,
	}

	local env = setmetatable({
		game = fakeGame,
		script = { Name = "ProfileStore" },
		Instance = fakeInstance,
	}, { __index = getfenv(1) })

	local chunk, err = loadstring(source, "=ProfileStore(vendor)")
	assert(chunk ~= nil, "vendor source failed to compile: " .. tostring(err))
	setfenv(chunk, env)
	local PS = chunk()

	return {
		PS = PS,
		identity = identity,
		services = services,
		destroy = function()
			services.RunService._event:Destroy()
		end,
	}
end

return MockBackend
=== END FILE ===

=== FILE: TASK-007/luau/MockTests.luau ===
-- ServerStorage.TestOnly.MockTests
-- SAVETEST ONLY. Runs the vendor ProfileStore SOURCE against in-memory fakes (MockBackend).
-- Never requires the real ProfileStore module, so it makes NO real DataStore call and NO real
-- MessagingService call. Run by hand from the command bar:
--   require(game.ServerStorage.TestOnly.MockTests).run(game.ServerStorage.TestOnly.ProfileStore.Source, "M1")
-- (pass nil as the second argument to run everything; each test is short, run a few per call)
--
-- Timings of the session-steal logic are SCALED DOWN with ProfileStore.SetConstant so the tests finish in
-- seconds. The real defaults (5 s / 10 s / 40 s) are NOT exercised here; real timing needs published servers.

local Guard = require(script.Parent.SaveTestGuard)
local MockBackend = require(script.Parent.MockBackend)

local STORE = Guard.TEST_STORE_NAME
local PLACE = Guard.SAVETEST_PLACE_ID

local TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}

local LEGACY_V1 = function(pearls)
	-- the exact v1 shape the game saves today (flat table, no Data/MetaData/GlobalUpdates)
	return {
		version = 1,
		pearls = pearls,
		owned = { DriftwoodHarpoon = true, StormHarpoon = true },
		counts = { FireShellCrate = 3 },
		equippedArmor = "OilskinCoat",
		equippedWeapon = "StormHarpoon",
		equippedBeam = "BeamAmber",
		stats = { runs = 4, victories = 1, bestNight = 9 },
	}
end

local function waitUntil(cond, timeout)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

local function fast(PS)
	PS.SetConstant("FIRST_LOAD_REPEAT", 0.2)
	PS.SetConstant("LOAD_REPEAT_PERIOD", 0.2)
	PS.SetConstant("SESSION_STEAL", 0.8)
	PS.SetConstant("START_SESSION_TIMEOUT", 8)
end

local function newServer(source, world, jobId)
	local h = MockBackend.loadVendor(source, world, { PlaceId = PLACE, JobId = jobId })
	assert(waitUntil(function()
		return h.PS.DataStoreState == "Access"
	end, 3), "mock DataStore state never became Access")
	fast(h.PS)
	h.store = h.PS.New(STORE, TEMPLATE)
	return h
end

local R = {} -- test functions, each returns (pass, detail)

R.M0 = function(source)
	-- the Studio probe and the experimental v2 option, against the FAKE services only
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local probeStore = world.stores["____PS"]
	local probeWrites = 0
	for _, w in ipairs(world.writes) do
		if w.store == "____PS" then
			probeWrites += 1
		end
	end
	local pass = probeStore ~= nil and probeWrites == 1 and h.identity.experimentalFeatures ~= nil
	local detail = {
		probeStoreCreatedOnFake = probeStore ~= nil,
		probeWritesOnFake = probeWrites,
		experimentalFeatures = h.identity.experimentalFeatures,
		dataStoreState = h.PS.DataStoreState,
		closeCallbacksRegistered = #h.identity.closeCallbacks,
	}
	h.destroy()
	return pass, detail
end

R.M1 = function(source)
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000001"
	local p = h.store:StartSessionAsync(key)
	if p == nil then
		return false, "StartSessionAsync returned nil"
	end
	local rec = MockBackend.record(world, STORE, key)
	local shape = type(rec) == "table" and type(rec.Data) == "table" and type(rec.MetaData) == "table" and type(rec.GlobalUpdates) == "table"
	local meta = rec and rec.MetaData or {}
	local active = meta.ActiveSession
	local okActive = type(active) == "table" and active[1] == PLACE and active[2] == "JOB_A" and type(active[3]) == "string"
	p.Data.pearls = 7
	p:EndSession()
	local released = waitUntil(function()
		local r = MockBackend.record(world, STORE, key)
		return r ~= nil and r.MetaData.ActiveSession == nil and r.Data.pearls == 7
	end, 3)
	local final = MockBackend.record(world, STORE, key)
	local detail = {
		topLevelKeys = (function()
			local ks = {}
			for k in pairs(rec) do
				table.insert(ks, k)
			end
			table.sort(ks)
			return ks
		end)(),
		sessionLoadCountAfterLoad = meta.SessionLoadCount,
		activeSessionOk = okActive,
		dataEqualsTemplatePearls = rec.Data.pearls == 0 and rec.Data.equippedBeam == "BeamAmber",
		releasedWithFinalData = released,
		finalPearls = final and final.Data.pearls,
		activeAfterEnd = final and final.MetaData.ActiveSession,
		isActiveAfterEnd = p:IsActive(),
	}
	h.destroy()
	return shape and okActive and meta.SessionLoadCount == 1 and released and not p:IsActive(), detail
end

R.M2 = function(source)
	-- legacy flat v1 record in the FAKE store: what does StartSessionAsync do to it?
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000002"
	MockBackend.seed(world, STORE, key, LEGACY_V1(500))
	local before = MockBackend.deepCopy(MockBackend.record(world, STORE, key))
	local overwrites = 0
	h.PS.OnOverwrite:Connect(function()
		overwrites += 1
	end)
	local p = h.store:StartSessionAsync(key)
	task.wait(0.1)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		seededPearls = before.pearls,
		seededHadWrapper = before.Data ~= nil or before.MetaData ~= nil or before.GlobalUpdates ~= nil,
		loadedProfileNotNil = p ~= nil,
		loadedPearls = p and p.Data.pearls,
		storedAfterHasWrapper = after.Data ~= nil and after.MetaData ~= nil,
		storedPearlsAfter = after.Data and after.Data.pearls,
		legacyFieldStillAtTopLevel = after.pearls ~= nil,
		onOverwriteFired = overwrites,
	}
	local destroyedLegacy = p ~= nil and p.Data.pearls == 0 and after.pearls == nil and overwrites >= 1
	h.destroy()
	-- "pass" = the documented destructive behaviour was reproduced (this is evidence, not a defect of the test)
	return destroyedLegacy, detail
end

R.M3 = function(source)
	-- legacy record + a Cancel that returns true at once
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000003"
	MockBackend.seed(world, STORE, key, LEGACY_V1(321))
	local p = h.store:StartSessionAsync(key, {
		Cancel = function()
			return true
		end,
	})
	task.wait(0.1)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		returnedNil = p == nil,
		storedHasWrapperAfter = after.Data ~= nil and after.MetaData ~= nil,
		legacyPearlsStillThere = after.pearls == 321,
		storedActiveSession = after.MetaData and after.MetaData.ActiveSession,
	}
	h.destroy()
	return p == nil and after.pearls == nil, detail
end

R.M4 = function(source)
	-- read-only GetAsync view of a legacy record
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000004"
	MockBackend.seed(world, STORE, key, LEGACY_V1(250))
	local writesBefore = #world.writes
	local view = h.store:GetAsync(key)
	local after = MockBackend.record(world, STORE, key)
	local detail = {
		viewNotNil = view ~= nil,
		viewPearls = view and view.Data.pearls,
		storedStillLegacy = after.pearls == 250 and after.Data == nil,
		writesDuringGet = #world.writes - writesBefore,
	}
	h.destroy()
	return view ~= nil and view.Data.pearls == 0 and detail.storedStillLegacy and detail.writesDuringGet == 0, detail
end

R.M5 = function(source)
	-- two logical servers, RESPONSIVE holder (messaging delivered)
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000005"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 11 -- unsaved change on the holder
	local ended = false
	pA.OnSessionEnd:Connect(function()
		ended = true
	end)
	local t0 = os.clock()
	local pB
	task.spawn(function()
		pB = B.store:StartSessionAsync(key)
	end)
	local got = waitUntil(function()
		return pB ~= nil
	end, 6)
	local elapsed = os.clock() - t0
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		bGotProfile = got,
		bSawHoldersUnsavedChange = pB and pB.Data.pearls,
		secondsToTakeover = elapsed,
		holderSessionEnded = ended,
		holderStillActive = pA:IsActive(),
		storedSessionLoadCount = rec.MetaData.SessionLoadCount,
		storedActiveJob = rec.MetaData.ActiveSession and rec.MetaData.ActiveSession[2],
		messagesPublished = #world.published,
	}
	local pass = got and pB.Data.pearls == 11 and ended and not pA:IsActive() and rec.MetaData.SessionLoadCount == 2 and detail.storedActiveJob == "JOB_B"
	A.destroy()
	B.destroy()
	return pass, detail
end

R.M6 = function(source)
	-- fencing: a stale holder cannot overwrite after takeover (responsive path)
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000006"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 3
	local pB
	task.spawn(function()
		pB = B.store:StartSessionAsync(key)
	end)
	waitUntil(function()
		return pB ~= nil
	end, 6)
	pB.Data.pearls = 50
	pB:Save()
	task.wait(0.3)
	pA.Data.pearls = 999
	pA:Save() -- inactive: warns and returns
	task.wait(0.3)
	local rec = MockBackend.record(world, STORE, key)
	local detail = { storedPearls = rec.Data.pearls, staleHolderActive = pA:IsActive() }
	A.destroy()
	B.destroy()
	return rec.Data.pearls == 50 and not pA:IsActive(), detail
end

R.M7 = function(source)
	-- UNRESPONSIVE holder: messaging dropped, scaled steal timing
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000007"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 4
	pA:Save()
	task.wait(0.2)
	world.dropMessages = true
	local t0 = os.clock()
	local pB
	task.spawn(function()
		pB = B.store:StartSessionAsync(key)
	end)
	local got = waitUntil(function()
		return pB ~= nil
	end, 8)
	local elapsed = os.clock() - t0
	-- the dead-or-slow holder now writes late
	pA.Data.pearls = 777
	pA:Save()
	task.wait(0.4)
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		bGotProfile = got,
		secondsToSteal_scaled = elapsed,
		scaledConstants = "FIRST_LOAD_REPEAT 0.2, LOAD_REPEAT_PERIOD 0.2, SESSION_STEAL 0.8",
		storedPearlsAfterLateHolderWrite = rec.Data.pearls,
		holderStillActiveAfterLateSave = pA:IsActive(),
		storedActiveJob = rec.MetaData.ActiveSession and rec.MetaData.ActiveSession[2],
	}
	A.destroy()
	B.destroy()
	return got and rec.Data.pearls ~= 777 and not pA:IsActive() and detail.storedActiveJob == "JOB_B", detail
end

R.M8 = function(source)
	-- dead lock: LastUpdate older than ASSUME_DEAD
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "JOB_A")
	local B = newServer(source, world, "JOB_B")
	local key = "player_900000008"
	local pA = A.store:StartSessionAsync(key)
	pA.Data.pearls = 2
	pA:Save()
	task.wait(0.2)
	local rec = MockBackend.record(world, STORE, key)
	rec.MetaData.LastUpdate = os.time() - 1000 -- older than ASSUME_DEAD (630 s)
	world.dropMessages = true
	local t0 = os.clock()
	local pB = B.store:StartSessionAsync(key)
	local elapsed = os.clock() - t0
	local detail = { tookOver = pB ~= nil, seconds = elapsed, pearls = pB and pB.Data.pearls }
	A.destroy()
	B.destroy()
	return pB ~= nil and elapsed < 1.5, detail
end

R.M9 = function(source)
	-- autosave/Save failure is not retried; the release save retries until it succeeds
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000009"
	local p = h.store:StartSessionAsync(key)
	task.wait(0.1)
	world.failures.UpdateAsync = 1
	p.Data.pearls = 5
	p:Save()
	task.wait(1.5)
	local afterFailedSave = MockBackend.record(world, STORE, key).Data.pearls
	local failuresLeft = world.failures.UpdateAsync
	p.Data.pearls = 6
	world.failures.UpdateAsync = 2
	local t0 = os.clock()
	p:EndSession()
	local ok = waitUntil(function()
		local r = MockBackend.record(world, STORE, key)
		return r.Data.pearls == 6 and r.MetaData.ActiveSession == nil
	end, 12)
	local detail = {
		storedAfterFailedSaveAndWait = afterFailedSave,
		failedSaveWasRetriedByItself = afterFailedSave == 5,
		injectedFailuresRemainingAfterFirstSave = failuresLeft,
		releaseSaveEventuallySucceeded = ok,
		secondsForReleaseWithTwoFailures = os.clock() - t0,
	}
	h.destroy()
	return afterFailedSave ~= 5 and ok, detail
end

R.M10 = function(source)
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000010"
	local p = h.store:StartSessionAsync(key)
	local okCall, err = pcall(function()
		return h.store:StartSessionAsync(key)
	end)
	local detail = { secondStartErrored = not okCall, message = tostring(err) }
	h.destroy()
	return p ~= nil and not okCall and string.find(tostring(err), "already loaded in this session", 1, true) ~= nil, detail
end

R.M11 = function(source)
	-- cancelled first load of a brand-new key
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local key = "player_900000011"
	local p = h.store:StartSessionAsync(key, {
		Cancel = function()
			return true
		end,
	})
	task.wait(0.1)
	local rec = MockBackend.record(world, STORE, key)
	local detail = {
		returnedNil = p == nil,
		recordCreated = rec ~= nil,
		activeSession = rec and rec.MetaData and rec.MetaData.ActiveSession,
		dataIsTemplate = rec and rec.Data and rec.Data.pearls == 0,
	}
	h.destroy()
	return p == nil, detail
end

R.M12 = function(source)
	-- shutdown: BindToClose releases all profiles in parallel
	local world = MockBackend.newWorld()
	local h = newServer(source, world, "JOB_A")
	local p1 = h.store:StartSessionAsync("player_900000012")
	local p2 = h.store:StartSessionAsync("player_900000013")
	p1.Data.pearls = 1
	p2.Data.pearls = 2
	world.latency = 0.4
	local t0 = os.clock()
	local callbacks = #h.identity.closeCallbacks
	assert(callbacks >= 1, "no BindToClose callback captured")
	for _, fn in ipairs(h.identity.closeCallbacks) do
		fn()
	end
	local elapsed = os.clock() - t0
	world.latency = 0
	local r1 = MockBackend.record(world, STORE, "player_900000012")
	local r2 = MockBackend.record(world, STORE, "player_900000013")
	local afterClose = h.store:StartSessionAsync("player_900000014")
	local detail = {
		closeCallbacks = callbacks,
		secondsWithTwoProfilesAt0_4sPerCall = elapsed,
		bothReleasedWithData = r1.MetaData.ActiveSession == nil and r2.MetaData.ActiveSession == nil and r1.Data.pearls == 1 and r2.Data.pearls == 2,
		isClosing = h.PS.IsClosing,
		startAfterCloseReturnsNil = afterClose == nil,
	}
	h.destroy()
	return detail.bothReleasedWithData and h.PS.IsClosing and afterClose == nil and elapsed < 0.4 * 2 + 0.5, detail
end

R.M13 = function(source)
	-- if two servers share the same JobId (for example both ""), the lock cannot tell them apart
	local world = MockBackend.newWorld()
	local A = newServer(source, world, "")
	local B = newServer(source, world, "")
	local key = "player_900000015"
	local pA = A.store:StartSessionAsync(key)
	local pB = B.store:StartSessionAsync(key)
	local detail = {
		firstProfileActive = pA ~= nil and pA:IsActive(),
		secondProfileActive = pB ~= nil and pB:IsActive(),
		bothActiveAtOnce = pA ~= nil and pB ~= nil and pA:IsActive() and pB:IsActive(),
	}
	A.destroy()
	B.destroy()
	-- "pass" = the weakness is demonstrated (evidence for why real concurrency tests need distinct JobIds)
	return detail.bothActiveAtOnce, detail
end

R.M14 = function(source)
	local g = Guard
	local names = { g.TEST_STORE_NAME, g.TEST_V1_FIXTURE_STORE, g.CANARY_STORE_NAME }
	local detail = { lengths = {} }
	local ok = true
	for _, n in ipairs(names) do
		detail.lengths[n] = #n
		ok = ok and #n <= 50
		g.assertStoreName(n)
	end
	local forbiddenRejected = not pcall(g.assertStoreName, "LighthouseKeepers_PlayerData_v1")
	local noTestPrefixRejected = not pcall(g.assertStoreName, "SomethingElse")
	local requireBlocked = not pcall(g.requireRealProfileStore, script.Parent:FindFirstChild("ProfileStore") or Instance.new("ModuleScript"))
	detail.forbiddenRejected = forbiddenRejected
	detail.noTestPrefixRejected = noTestPrefixRejected
	detail.realRequireBlockedWhileUnapproved = requireBlocked
	detail.approvalFlag = g.REAL_DATASTORE_APPROVED
	return ok and forbiddenRejected and noTestPrefixRejected and requireBlocked and g.REAL_DATASTORE_APPROVED == false, detail
end

local ORDER = { "M0", "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12", "M13", "M14" }

local Tests = {}

function Tests.run(source, which)
	Guard.assertSaveTest()
	local results = {}
	for _, name in ipairs(ORDER) do
		if which == nil or which == name or (type(which) == "table" and table.find(which, name)) then
			local ok, pass, detail = pcall(R[name], source)
			if ok then
				table.insert(results, { test = name, pass = pass, detail = detail })
			else
				table.insert(results, { test = name, pass = false, error = tostring(pass) })
			end
		end
	end
	return results
end

return Tests
=== END FILE ===

=== FILE: TASK-007/luau/adhoc_cancel_midflight.luau ===
-- AD-HOC TEST M3b / M11b (run through execute_luau in the SaveTest window; not installed as a script).
-- Question: what does ProfileStore do when Cancel flips to true AFTER the load loop has started
-- (so the DataStore transform runs while cancelled)? Uses the in-memory fakes only; the real module is not required.
-- M3 and M11 (Cancel true from the very first call) were already run by MockTests.

local Guard = require(game.ServerStorage.TestOnly.SaveTestGuard)
Guard.assertSaveTest()
assert(game:GetService("RunService"):IsEdit() and not game:GetService("RunService"):IsRunning(), "ABORT not edit mode")

local T = game.ServerStorage.TestOnly
local MockBackend = require(T.MockBackend)
local STORE = Guard.TEST_STORE_NAME
local PLACE = Guard.SAVETEST_PLACE_ID

local function waitUntil(cond, timeout)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

local world = MockBackend.newWorld()
local h = MockBackend.loadVendor(T.ProfileStore.Source, world, { PlaceId = PLACE, JobId = "JOB_A" })
assert(waitUntil(function()
	return h.PS.DataStoreState == "Access"
end, 3), "mock state never Access")
local store = h.PS.New(STORE, { version = 1, pearls = 0 })
local out = {}

-- M3b: legacy flat record, Cancel returns false on its first call (loop condition) and true afterwards
MockBackend.seed(world, STORE, "player_900000103", { version = 1, pearls = 321, owned = { StormHarpoon = true } })
local calls1 = 0
local p1 = store:StartSessionAsync("player_900000103", {
	Cancel = function()
		calls1 += 1
		return calls1 >= 2
	end,
})
task.wait(0.1)
local r1 = MockBackend.record(world, STORE, "player_900000103")
out.M3b = {
	cancelCalls = calls1,
	returnedNil = p1 == nil,
	storedHasWrapper = r1.Data ~= nil and r1.MetaData ~= nil,
	legacyPearlsStillThere = r1.pearls == 321,
	storedPearlsAfter = r1.Data and r1.Data.pearls,
	activeSession = r1.MetaData and r1.MetaData.ActiveSession,
}

-- M11b: brand-new key, same flipping Cancel
local calls2 = 0
local p2 = store:StartSessionAsync("player_900000104", {
	Cancel = function()
		calls2 += 1
		return calls2 >= 2
	end,
})
task.wait(0.1)
local r2 = MockBackend.record(world, STORE, "player_900000104")
out.M11b = {
	cancelCalls = calls2,
	returnedNil = p2 == nil,
	recordCreated = r2 ~= nil,
	activeSession = r2 and r2.MetaData and r2.MetaData.ActiveSession,
	dataIsTemplate = r2 and r2.Data and r2.Data.pearls == 0,
}

h.destroy()
return game:GetService("HttpService"):JSONEncode(out)
=== END FILE ===

=== FILE: TASK-007/luau/sha256_lib.luau ===
-- Pure-Luau SHA-256 (no services, no DataStore). Used only to verify that the installed vendor Source
-- is byte-identical to the pinned file. Self-test vectors: "" and "abc".
local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function sha256(msg)
	local h0, h1, h2, h3, h4, h5, h6, h7 =
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local len = #msg
	msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64) .. string.pack(">I8", len * 8)
	assert(#msg % 64 == 0, "bad padding")
	local w = table.create(64, 0)
	for chunk = 1, #msg, 64 do
		for i = 0, 15 do
			w[i + 1] = string.unpack(">I4", msg, chunk + i * 4)
		end
		for i = 17, 64 do
			local a, b = w[i - 15], w[i - 2]
			local s0 = bit32.bxor(bit32.rrotate(a, 7), bit32.rrotate(a, 18), bit32.rshift(a, 3))
			local s1 = bit32.bxor(bit32.rrotate(b, 17), bit32.rrotate(b, 19), bit32.rshift(b, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
		end
		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for i = 1, 64 do
			local S1 = bit32.bxor(bit32.rrotate(e, 6), bit32.rrotate(e, 11), bit32.rrotate(e, 25))
			local ch = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
			local t1 = (h + S1 + ch + K[i] + w[i]) % 4294967296
			local S0 = bit32.bxor(bit32.rrotate(a, 2), bit32.rrotate(a, 13), bit32.rrotate(a, 22))
			local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
			local t2 = (S0 + maj) % 4294967296
			h, g, f, e, d, c, b, a = g, f, e, (d + t1) % 4294967296, c, b, a, (t1 + t2) % 4294967296
		end
		h0 = (h0 + a) % 4294967296
		h1 = (h1 + b) % 4294967296
		h2 = (h2 + c) % 4294967296
		h3 = (h3 + d) % 4294967296
		h4 = (h4 + e) % 4294967296
		h5 = (h5 + f) % 4294967296
		h6 = (h6 + g) % 4294967296
		h7 = (h7 + h) % 4294967296
	end
	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4, h5, h6, h7)
end

return sha256
=== END FILE ===

