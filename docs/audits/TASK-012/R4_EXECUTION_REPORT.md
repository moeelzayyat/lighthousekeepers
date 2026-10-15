# R4 EXECUTION REPORT: release of an active profile at Studio shutdown

- **Date:** 2026-10-14. The module loaded and the probe wrote at 21:29:59Z, the session was created in the same second, the approved Stop happened at about 21:30:12Z (`LastUpdate`), and the release write's UpdatedTime is 21:30:15Z.
- **Authorization:** the owner's message "execute R4", 2026-10-14 21:29:32Z, which authorizes one execution under `R4_EXECUTION_APPROVAL_REQUEST.md`.
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`.
- **Executed:** once. There were no retries and no re-sends.
- **Not done:** R5 was not run or armed, nothing was published, and production and Outlaw City were not touched.

## Result: PASSED

| Check | Expected | Observed | Source |
|---|---|---|---|
| Before Stop: stored value | template `pearls 0`, session active | `pearls 0`, `ActiveSession [128620546156998, "", f7a50abf-…]`, load count 1 | `raw\R4_03` (step 5_holding, uncached read) |
| Before Stop: in memory | `pearls 40`, no Save | `memoryPearls 40` | `raw\R4_03` |
| Stop gate | `readyForApprovedStop = true` | true: holding for 4 s, flag reset, profile active, observer registered | `raw\R4_03` |
| Shutdown release | the library's BindToClose writes 40 and releases | console: observer started; OnSessionEnd fired; `released=true after 0.68s storedPearls=40 loadCount=1` | `raw\R4_04` |
| **After Stop: uncached read in Edit** | `pearls 40`, no `ActiveSession`, load count 1 | **`pearls 40`, `activeSession` absent, `sessionLoadCount 1`**, `LastUpdate 1792013412`, UpdatedTime 21:30:15Z | `raw\R4_05` |
| Fixtures preserved | 201 and 202 unchanged | 201: 25 Pearls, load count 2, same version and UpdatedTime as before. 202: 30 Pearls, load count 1, same version and UpdatedTime as before. | `raw\R4_05` |
| Errors | none | only the expected client `WaitForChild` warnings (Main is disabled) | `raw\R4_04` |

## Writes (all expected; nothing else)
1. `____PS/____PS` Studio probe: value `1792005392` → `1792013399` (21:29:59Z).
2. `player_900000203` session start, which created the record.
3. `player_900000203` shutdown release by the library's BindToClose: data `pearls 40`, session cleared.

The key's version string `…0000000002…` is consistent with two writes. Version numbering is not used as proof.

## Pre-execution verification
Done at 21:29:40Z, read-only, in `raw\R4_01`:
- Studio re-listed;
- both IDs asserted, in Edit mode, not running;
- `Main.Enabled = false`;
- R5 bootstrap disabled and with no attributes;
- all flags false;
- hashes: ProfileStore `ad437372…`, guard `194e30d3…`, R4 runner `1a125835…`;
- uncached read: `player_900000203` absent.

The run command re-asserted the same hashes inside the Play server.

## Findings and limits
1. **In a Studio Play server, stopping Play gives ProfileStore's BindToClose time to save and release an active profile.** The release was seen in the store 0.68 s after the observer started. The unsaved in-memory change (40) was persisted by that final write, as the library source says.
2. **`OnSessionEnd` fired before the release write**, which again matches the source. The release is confirmed only by store reads, in-server and then from Edit.
3. **Limits:**
   - This is one Studio server and one profile.
   - Live-server shutdown timing (Roblox's 30 s BindToClose limit, several profiles, slow DataStore responses) is not covered.
   - Both reads come from the same Studio process and account.
4. **Staging folder.** `ServerStorage.TestOnly_R5v2Staging` (R5 v3 code, inert ModuleScripts) was present in the place during the run. It is not required by anything, and the run never touched it.

## State now
- SaveTest is in Edit mode with `Main` disabled.
- The R5 bootstrap is disabled and unarmed. R5 v3 is still staged and not installed.
- Records in `TEST_LK_ProfileStore_v2`: 201 (25 Pearls), 202 (30), 203 (40), all released.

## Next, per the auditor's order, after this evidence is reviewed
1. Install the staged R5 v3 into SaveTest and re-verify the hashes.
2. Account 2 access check.
3. Pre-publish checklist for approval.
