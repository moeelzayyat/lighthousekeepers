# R4 EXECUTION APPROVAL REQUEST

- **Date:** 2026-10-14
- **Status:** not executed. Waiting for the owner's explicit "execute R4".
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`.

## Pre-execution checks (done 2026-10-14 ~20:04Z, read-only, raw output in `raw\R4_00_precheck_edit.json`)

**Studio instances re-listed:**
- production `(132065051336560)`
- Outlaw City `(132163592957463)`
- SaveTest `(128620546156998)`

Only the SaveTest window is used.

**Checks asserted inside the SaveTest window:**
- both IDs;
- Edit mode, not running;
- `Main.Enabled = false`;
- R5 bootstrap present but **disabled with no attributes** (unarmed);
- all approval flags false.

**Uncached read of `TEST_LK_ProfileStore_v2/player_900000203`:** the key does not exist.

**Hashes (in Studio, equal to the reviewed files):**

| Module | SHA-256 |
|---|---|
| ProfileStore | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |
| SaveTestGuard | `194e30d367ff3792ad61fcf0413492f257d81e8caa8e2e85c4e6429fd73f400b` |
| R4ShutdownRunner | `1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613` |

None of these will change before R4 runs. The R5 revision does not touch the Studio guard until after R4.

## Exact steps once approved (each once)
1. Re-list Studio and assert the SaveTest IDs again.
2. Start one Studio Play session in the SaveTest window.
3. Send `R4_run_command.luau` (SHA-256 `d93d62d3586b400d778a2d7ba35e929c7808a140b5351196abf7b367ea26ed31`) **once** to the Server DataModel. It is never re-sent.
4. Poll `R4_status_command.luau` (`287eeadc52abe88c96246f8d6bcee91b6a7125a06a6777bd03f2a52fcf09866a`), read-only, until `readyForApprovedStop = true`.
5. Capture the console. Then **Stop Play**: this is the test's approved action.
   - If `readyForApprovedStop` never becomes true, I do not stop Play. I report and ask for a recovery decision.
   - The only exception is `safeToStopAfterFailure = true` after an early failure.
6. In Edit, run `R4_post_stop_check.luau` (`703311f6b9f26477914e71eaa0ca3bd45373208bef22c2eae6f0a40fd44e8417`) with uncached reads, then capture the console.

## Expected writes (3, and nothing else)
1. `____PS/____PS` Studio probe (1).
2. `player_900000203` session start (1).
3. `player_900000203` shutdown release by the library (1).

Fixtures 201 and 202 are read only.

## Pass and fail criteria

**Pass:**
- `player_900000203` shows `pearls 40`, no `ActiveSession`, and `SessionLoadCount 1`;
- the observer printed `released=true`;
- there are no ProfileStore errors;
- fixtures 201 (25 Pearls) and 202 (30 Pearls) are unchanged.

**Fail:**
- a lock is left behind;
- `pearls ≠ 40`;
- the observer reports `released=false` or prints nothing;
- any ProfileStore error.

On a fail, there is no retry and no recovery without a new approval.

## Approval requested
Reply **"execute R4"** to authorize this single run exactly as written.
