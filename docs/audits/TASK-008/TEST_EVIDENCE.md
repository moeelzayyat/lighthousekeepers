# TEST EVIDENCE — TASK-008

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (PlaceId 128620546156998, GameId 10770892134), Edit mode, no Play session. Players: none. Device/emulator: none.
**Production DataStores:** not read, not written. **Real DataStore write in this task: exactly one** (R1 probe, below). Everything else ran against in-memory fakes or was read-only.

## 1. Phase A: identity, settings, integrity
| # | Check | Result |
|---|---|---|
| 1 | Studio instances re-listed before each run | production `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, SaveTest `(128620546156998)`; Outlaw City untouched |
| 2 | Both SaveTest IDs asserted inside every script before execution | PlaceId 128620546156998, GameId 10770892134, not production, Edit mode and not running |
| 3 | Production Studio API access | **owner reports it was ON earlier and that he turned it OFF himself in this task (D4 yes: "disabled api in production")**. Claude cannot read this setting and did not touch it. Recorded as owner-reported |
| 4 | SaveTest Studio API access | ON (owner-reported; also functionally shown by the successful DataStore read and write in this task) |
| 5 | Original `PlayerData` unchanged | SaveTest Source SHA-256 `8413e9ff936a86f0b9d7fc26d6b5174a430d3b4119a2b5f1c00d3762a4bdd2d8`, length 10,259 = the v148 export hash; store-name line still `LighthouseKeepers_PlayerData_v1`; no new script references it |
| 6 | Installed `ProfileStore` hash (computed inside Studio with the pure-Luau SHA-256, plus earlier from the saved file) | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`, 64,654 bytes = pinned; local pinned file also re-hashed equal |
| 7 | Guard flag before and after | `REAL_DATASTORE_APPROVED` false before R1, false after R1, false in an independent later read |
| 8 | Local backups preserved (hashes recorded) | `SaveTest_pre-TASK-007.rbxl` `D2AC31D6...9BA9B05A`; `SaveTest_TASK-007_integrated.rbxl` `45CF80C3...FAB54D6`; v148 `6AF4E727...03B5C8`; v149 and `LighthouseKeepers_SaveTest_from_v148.rbxl` `0C880E87...7307EF` |

## 2. Phase B: mock-suite correction and results (vendor text vs in-memory fakes; the real module was never required in this phase)
Changes to `MockTests` (installed script and local file `luau/MockTests.luau`, both SHA-256 `2feea5946973ea51dabc9a9fdf551d8b8bf7c8ea82bd86b23b26990f84e6a533`, 19,451 bytes; it compiles): M3's expected outcome now matches observed behaviour (a Cancel that is already true causes **no write**: returned nil, legacy record unchanged); M3b and M11b added (Cancel flips true after the load started); every result now carries a `kind`.
| Test | Kind | Result |
|---|---|---|
| M0 probe/options on fakes | functional | PASS |
| M1 record shape and release | functional | PASS |
| M2 legacy v1 record, normal start | **destructive demo (synthetic data)** | PASS = destructive behaviour observed (record replaced by template, pearls 500 -> 0, `OnOverwrite` fired) |
| M3 legacy + Cancel true from the first call | **cancellation regression** | PASS = no write, legacy pearls kept |
| M3b legacy + Cancel true after load starts | **destructive demo (synthetic data)** | PASS = legacy record overwritten (wrapper present, pearls 0) |
| M4 `GetAsync` view of legacy record | functional | PASS (template shown, stored record unchanged, 0 writes) |
| M5 responsive takeover | functional | PASS |
| M6 fencing after takeover | functional | PASS |
| M7 unresponsive holder (scaled timing) | functional | PASS |
| M8 dead lock | functional | PASS |
| M9 failed save not retried; release retries | functional | PASS |
| M10 double start | functional | PASS |
| M11 new key + Cancel true from the first call | **cancellation regression** | PASS = nothing created |
| M11b new key + Cancel true after load starts | **side-effect demo (synthetic data)** | PASS = empty template record created, no active session |
| M12 shutdown release | functional | PASS |
| M13 equal JobId | **weakness demo (synthetic data)** | PASS = two profiles active at once |
| M14 guard behaviours | functional | PASS |
**All 17 tests pass as written (11 functional, 2 cancellation regressions, 4 demonstrations).** Process note: my first re-run used a **cached copy** of the old test module (Studio caches `require`), which showed only the old tests; I noticed the missing M3b/M11b and `kind` fields and re-ran with a fresh clone of the updated script (the clone was destroyed afterwards; `TestOnly` again holds exactly 5 scripts).

## 3. Phase C: R1, the single real initialization (owner approved in chat: "approve R1")
- **Executed script:** `luau/R1_real_init.luau` (exact code). It asserted both exact SaveTest IDs and Edit mode, asserted the installed source hash equals the pinned hash, asserted the flag was false, set `REAL_DATASTORE_APPROVED = true`, called `SaveTestGuard.requireRealProfileStore(ServerStorage.TestOnly.ProfileStore)` inside a `pcall`, **set the flag back to false immediately afterwards**, then waited (read-only) for `DataStoreState`.
- **Not called:** `ProfileStore.New`, `StartSessionAsync`, `Save`, `EndSession`, `RemoveAsync`, `MessageAsync`, `GetAsync`, or any fixture/import code.
- **Output (verbatim):** `{"secondsToSettle":0.5345892000477761,"flagBefore":false,"isClosing":false,"isCriticalState":false,"flagAfterRequire":false,"moduleType":"table","requireOk":true,"sourceSha":"ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f","startedAt":1792001296,"dataStoreState":"Access"}`
- **Reading:** the module loaded without error; its own probe (`SetAsync("____PS", os.time())`) succeeded in 0.53 s; state `Access`; not in critical state; not closing.
- **Resulting DataStore state (read-only follow-up, `luau/R1_followup_read.luau`):** store `____PS`, key `____PS` holds the number `1792001296` (equal to `startedAt`, 8 s old when read). No `TEST_LK_*` store was written.
- **Console output after R1:** one `[ProfileStore]: Roblox API services available - data will be saved` among the earlier mock-run messages (the vendor prints it for each loaded instance, including the fakes; the real one cannot be separated by the log), and at the end `BindToClose can only be called on the server.` raised from `ProfileStore` line 2208 in a spawned task. This means the real module's shutdown handler was **not** registered in this Edit-mode context (limitation, no persistence consequence since no profile was loaded). No other warnings from the real module. The log also contains earlier expected lines: the first T0 attempt's "StudioAccessToApisNotAllowed" and the mock tests' own fake-failure messages.
- **Deviation to disclose:** the follow-up read script called `require(ServerStorage.TestOnly.ProfileStore)` **directly, not through the guard**, to read `DataStoreState`. The module was already cached from the guarded require, so nothing re-initialized and no further operation ran (flag was false; the guard would have refused a first load). It breaks the "all real-module access goes through the guard" rule and is recorded in the script header.
- **Left behind by R1:** the real module's `RunService.Heartbeat` autosave loop is connected in this Studio session, and its autosave list is empty, so it performs no saves. It disappears when Studio restarts. Its `BindToClose` was not registered (see above).
- **Stopped on unexpected behaviour?** Nothing unexpected happened; no stop was needed.

## 4. Not performed (not approved)
Any real `ProfileStore.New`, `StartSessionAsync`, save, end-session, removal, fixtures, v1 import; published-server tests; Play sessions; production or Outlaw City anything; publishing.

## 5. Remaining risks
Owner-reported (not verified) production API setting; the real module is now loaded in this Studio session with its autosave loop connected (inert); mock results are my own fakes, not real-DataStore behaviour; the SaveTest window holds unsaved in-session changes (updated `MockTests`, real module loaded) that are not in any saved file yet.
