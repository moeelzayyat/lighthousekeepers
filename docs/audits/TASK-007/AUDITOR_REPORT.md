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
