# AUDITOR REPORT — TASK-006: Persistence test readiness

- **Date:** 2026-10-14
- **Production (untouched):** place 132065051336560, universe 10769064643.
- **SaveTest (authorized target):** place 128620546156998, universe 10770892134.
- **Owner/auditor request:** identify SaveTest by both IDs; read production's Studio API-access setting without modifying it; compare SHA-256 of the 40 active scripts in the v148 and v149 backups; prepare a minimal canary against `TEST_LK_IsolationCanary` in SaveTest only with both IDs asserted in the script; run it only with explicit owner approval; no production DataStore reads or writes; no ProfileStore; no production edits or publishing; Outlaw City out of scope.

## Results
| Step | Result |
|---|---|
| 1 Identity | After re-listing the Studio windows, the SaveTest instance was identified by name and confirmed inside the script: **PlaceId 128620546156998, GameId 10770892134**, creator user 11752219158, place version 3, Edit mode, not running. Not the production IDs. |
| 2 Production API-access setting | **UNKNOWN.** No read method exists that avoids touching production: a script in the production window can only learn it by making a production DataStore call (prohibited), and Creator Hub in the built-in browser required a login (not performed; no credentials entered; the page was closed). Nothing was asked of the owner and nothing was changed. |
| 3 Script hashes v148 vs v149 | **40 of 40 identical** (`HASH_COMPARISON_V148_V149.md`). Whole-export comparison: 501 files each, none only on one side, 43 byte-different JSON metadata files that are identical after key sorting (ordering only), no `.luau` difference. |
| 4-5 Canary prepared | `CANARY_SCRIPT.luau`: asserts both exact SaveTest IDs, rejects production IDs, requires Edit mode, then reads, writes once, reads back. |
| 6 Canary run | **Approved by the owner ("yes") and run.** Read-before nil, one write ok, read-back ok and matching (`CANARY_RESULT.md`). |
| 7-10 prohibitions | Not violated: no production DataStore key read/written/deleted/modified; ProfileStore not installed or executed; no production edit or setting change; nothing published; Outlaw City not touched. |

## What changed anywhere
- Claude created local files only (this package; `work\v149-export\` scratch export).
- One DataStore write in total: the canary marker, in the SaveTest universe store `TEST_LK_IsolationCanary`, key `isolation_canary_v1`, owner-approved.
- No game code, Config value, setting or published content was changed by Claude.

## Implications
- **Save-data:** none for production. **Gameplay/security/performance:** none.
- The environment now has a proven write/read round trip, which is the minimum needed before persistence tests start.

## Known limitations
- Production's Studio API setting is still unknown (decision D4 depends on it).
- The canary does not prove production isolation; it proves SaveTest works. The T0 read from TASK-005 remains the only isolation evidence.
- The v148/v149 comparison covers script and exported-tree content, not the world, terrain or Lighthouse properties; the two `.rbxl` files have the same size but different hashes, unexplained.
- The SaveTest place on Roblox was compared with the backup only by counts and lengths (TASK-005), not hashes.

## Outstanding / next-step recommendation
1. Owner reads production's Game Settings > Security himself (look only) and reports on/off, or decides D4 (turn it off) directly; I will not attempt it again.
2. Decide D1 and the remaining D-items in `TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md`.
3. Next test task, if approved: place the pinned `ProfileStore.luau` in the SaveTest place only, add the guard and test-store names, and run the first rows of the test matrix v2 (C20, C22, C12 on test fixtures), each write approved.

## Ready for acceptance?
Yes as a readiness milestone. No persistence implementation is authorized.
