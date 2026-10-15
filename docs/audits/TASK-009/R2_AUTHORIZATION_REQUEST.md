# R2 authorization request (TASK-009 Phase C) — NOT YET RUN

## 1. Exact script to execute
- Run command: `luau/R2_run_command.luau` (executed once through MCP `execute_luau` in the SaveTest window).
- It calls `ServerStorage.TestOnly.R2SaveLoad.startReal()`; the entrypoint's full source is `luau/R2SaveLoad.luau` (SHA-256 `8a1cac7a40ff371653278d08957fd48e35b17a4fa9937976925a0aed0ac30a25`); the guard is `luau/SaveTestGuard.luau` (SHA-256 `9e74c577f6d9b79bf784ee0c21917f488a392b1c50ad7d24c010576cf0278fab`). The run command refuses to start unless the installed ProfileStore, guard and entrypoint hashes all match these values.
- Progress is read with `luau/R2_status_command.luau` (in-memory status only, no DataStore call).

## 2. Verified target IDs
SaveTest PlaceId 128620546156998, GameId 10770892134, asserted inside the run command, inside the guard, and inside the entrypoint. Production 132065051336560 / 10769064643 rejected. Outlaw City never addressed.

## 3. Execution context
SaveTest Studio window, **Edit mode, no Play session**, MCP `execute_luau` (plugin/command context). Consequences: none of the game's own scripts run, so the game's `PlayerData` cannot load or save anything (no `LighthouseKeepers_PlayerData_v1` access); `BindToClose` cannot be registered in this context (seen in TASK-008), which does not matter here because both sessions are ended explicitly. The test runs asynchronously (`startReal` returns at once) to avoid MCP time-outs.

## 4. Expected stores, keys and operations
| Store / key | Operation | Count (expected) |
|---|---|---|
| `TEST_LK_ProfileStore_v2` / `player_900000201` | `UpdateAsync` writes by ProfileStore: session 1 start, Save of Pearls 25, session 1 release, session 2 start, session 2 release | **5** (the dry run on fakes produced exactly these 5) |
| `TEST_LK_ProfileStore_v2` / `player_900000201` | raw `GetAsync` reads by the test (precheck, after each step, release polling once per second) | about 8-14 |
| `____PS` / `____PS` | raw `GetAsync` reads (before require, before and after the test) | 3 |
The test aborts **before any write** if `player_900000201` already exists.

## 5. Possible unintended writes and how each is handled
| Possible write | Handling |
|---|---|
| Repeat Studio probe (`____PS`/`____PS`) | The real module is already loaded in this Studio session since R1, so `require` returns the cached module and the probe does not run again. If Studio had been restarted, the probe would run once more (same store/key as R1). The status reports `probeBeforeRequire`, `probeBefore`, `probeAfter` so a repeat is visible. **Accepted only as this one known write.** |
| Library retries | A failed `UpdateAsync` during session start is retried, and release saves repeat until success; any retry writes the same key only. |
| Library autosave | Default 300 s and skips profiles loaded less than 150 s ago; each session lives seconds, so no autosave is expected. |
| MessagingService | each session subscribes to a topic `PS_<guid>`; not a DataStore write; may log an error in Edit mode, which does not affect saving. |
| The game's own `PlayerData` (`LighthouseKeepers_PlayerData_v1`) | cannot run: Edit mode, no Play, no player. |
| Any other store or key | impossible through the entrypoint: `New` only accepts `TEST_LK_ProfileStore_v2`, `StartSessionAsync` only `player_900000201` with no parameters, and raw reads are allow-listed. `RemoveAsync`, `MessageAsync`, `GetAsync`-view, `VersionQuery`, `Steal`, `Cancel` are not exposed. |
| Production or Outlaw City | not addressed; IDs asserted. |

## 6. Stop and recovery behaviour
- Any failed check stops the remaining steps. A recovery block then ends any session still active and waits (polling once per second, up to 20 s) until the stored record shows the lock released.
- The approval flag is reset to false by the entrypoint on every exit path; the status shows it.
- I will report and stop on any unexpected result, and will not re-run without a new approval.
- If Studio closes mid-run, the record could stay locked; ProfileStore treats such a lock as dead after 630 s. Only the synthetic key is affected.

## 7. Evidence that will be returned
The status log (every step with stored values), the final stored record of `player_900000201`, the probe-key values, the flag value afterwards, and the Studio console output.

## 8. Not requested and not allowed
Legacy-record overwrite tests, v1 import, other keys, production DataStores, publishing, R3/R4, the full matrix.
