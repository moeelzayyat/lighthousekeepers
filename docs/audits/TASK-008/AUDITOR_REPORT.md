# AUDITOR REPORT — TASK-008: First real ProfileStore verification

- **Date:** 2026-10-14
- **Authorized environment only:** SaveTest place 128620546156998, universe 10770892134. Production (132065051336560 / 10769064643) and Outlaw City untouched by Claude.
- **Request (auditor verdict relayed by the owner):** Phase A safety checks; Phase B correct the mock suite (M3) and re-run the cancellation tests; Phase C controlled real-module initialization (R1) only with the owner's separate approval, allowing only the Studio probe write to `____PS`/`____PS`; Phase D this package. Stop afterwards.

## Outcome in one paragraph
All Phase A checks passed (IDs, `PlayerData` unchanged, installed ProfileStore hash equal to the pinned hash, guard flag blocked, backups intact); the owner turned production Studio API access off himself (owner-reported, not verifiable by Claude). Phase B corrected M3 and added M3b and M11b; all 17 mock tests pass as written, now labelled as functional, cancellation regression or destructive demonstration. With the owner's explicit "approve R1", the real pinned ProfileStore was loaded **once** through `SaveTestGuard`; its Studio probe succeeded (`DataStoreState = "Access"`), the guard flag was set back to false straight after, and the probe key `____PS`/`____PS` in the SaveTest universe now holds the timestamp of that write. No session, save, removal or fixture operation was called.

## Phase A
IDs asserted in-script before every run; SaveTest API access on; production API access owner-reported off after D4; `PlayerData` SHA-256 `8413e9ff...bdd2d8` unchanged; `ProfileStore` SHA-256 `AD437372...0C95F` (64,654 bytes) re-verified inside Studio and locally; all local backups preserved with hashes recorded (`TEST_EVIDENCE.md` section 1).

## Phase B
M3 now expects what it observed (Cancel already true: no write, legacy record untouched). M3b and M11b document the in-flight cancel behaviour. The suite distinguishes: 11 functional tests, 2 cancellation regressions, 4 demonstrations on synthetic fake data (M2, M3b, M11b, M13). Result: **17/17 pass as written.** One process error is disclosed: the first re-run used a cached copy of the old test module; it was spotted and re-run with a fresh copy.

## Phase C (R1)
Exact real write performed: **one** `SetAsync` of `os.time()` to store `____PS`, key `____PS`, in the SaveTest universe, made by the library's own probe at module load. Output, console and the resulting key value are in `TEST_EVIDENCE.md` section 3. Console shows no real-module warning except `BindToClose can only be called on the server.` (the real module's shutdown handler was not registered in this Edit-mode context). Nothing else was written.

## Deviations and limitations (read these)
1. **Unguarded require.** The follow-up read-only script called `require(...ProfileStore)` directly once to read `DataStoreState`. It was a cached module, so nothing re-ran, but it bypassed `SaveTestGuard`'s "single sanctioned path" rule.
2. **Production API setting is owner-reported**, before and after.
3. The real module is now loaded in the open SaveTest Studio session with its (empty) autosave loop connected; it clears on Studio restart. SaveTest holds unsaved in-session changes (updated `MockTests`, loaded module) that are not in any saved `.rbxl`.
4. The mock suite uses my own fakes; it does not demonstrate real DataStore behaviour.
5. `BindToClose` was not registered for the real module in Edit mode, so shutdown behaviour of the real module is still untested.

## Next approval requests
1. R2: `ProfileStore.New` plus one `StartSessionAsync`/`Save`/`EndSession` cycle on a **fresh synthetic key** in `TEST_LK_ProfileStore_v2` (writes: session start, save, release).
2. Decision on publishing SaveTest for two-server tests, or dropping those rows.
3. Whether to save the SaveTest window's current state to a new local file and whether to keep the real module loaded or restart Studio first.
4. Decisions D1 and D5-D13.
5. Confirm that production Studio API access should stay OFF.

## Ready for acceptance?
Yes as a controlled real-initialization milestone. No persistence implementation is authorized.
