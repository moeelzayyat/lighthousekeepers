# TASK-005 AUDITOR PACKAGE (combined plain-text version)

Separate private SaveTest experience for Lighthouse Keepers (test place 128620546156998, universe 10770892134; production 132065051336560 / 10769064643 untouched). Claude changed no game code, no setting, no saved data, published nothing and made no DataStore write; the only DataStore calls were two read-only gate checks (T0) inside the SaveTest universe. No source diffs, screenshots or logs exist.

## TABLE OF CONTENTS
1. TASK-005/AUDITOR_REPORT.md
2. TASK-005/CHANGE_MANIFEST.md
3. TASK-005/TEST_EVIDENCE.md
4. TASK-005/AUDITOR_QUESTIONS.md
5. TASK-005/SETUP_PLAN.md
6. TASK-005/SETUP_RESULTS.md
7. TASK-005/REVISED_TEST_MATRIX_V2.md

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-005/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-005: Separate private SaveTest experience (D3)

- **Date:** 2026-10-14
- **Production (untouched):** Lighthouse Keepers - Staging, place 132065051336560, universe 10769064643.
- **Test environment created by the owner:** "Private lighthouse keepers", **place 128620546156998, universe 10770892134**, private, creator = the owner's account.
- **Original owner request (D3):** plan and guide the setup of a separate, private SaveTest experience; explain steps needing the owner; do not modify or publish production, touch Outlaw City, import real saves, enable production API access, write to DataStores before verification, or install ProfileStore in production; update the test matrix for the source-verification findings; stop after the environment is prepared and verified and produce the handoff before asking for persistence implementation.

## Work completed
1. A step-by-step plan with owner-hands and approval markers (`SETUP_PLAN.md`).
2. The owner created the experience and published it to a new place, enabled Studio API access for it, and confirmed it is private.
3. Claude verified the environment read-only through MCP: IDs differ from production, content equals the owner's v149 save (counts and script lengths), store name unchanged (`LighthouseKeepers_PlayerData_v1`, separate store because it belongs to the test universe).
4. **Gate T0 passed:** a read of the owner's production-profile key `player_11752219158` and of `__access_check` in the SaveTest store returned nil after API access was saved (the first attempt was rejected by Roblox and read nothing).
5. The test matrix was rewritten (`REVISED_TEST_MATRIX_V2.md`) to reflect findings A-J of `SOURCE_VERIFICATION_ADDENDUM.md`, adding C18-C29 and changing C1, C7, C12, C14.

## Deviations from the plan (all recorded in `SETUP_RESULTS.md`)
- The test place was built from **v149**, not v148 (the owner's own copy made before step 0 was approved). v149 is the owner's save after v148; its content matches v148 on every count and length checked.
- Plan steps 8-9 (test-only store name, production-ID guard, extra publish) were **dropped at the owner's request** because manual publishing invites human error. Consequence: no code in the SaveTest place was changed.
- The production Studio API setting was **not reported**, so its state is unknown (D4 pending).
- Step 0 and the opening/publishing steps were done by the owner without my witnessing them; their result was verified afterwards, not observed.

## Gameplay / security / save-data / performance implications
None. No game or Config change, no DataStore write by Claude, nothing published by Claude, no production data read.

## Known limitations
- Isolation is supported by T0 but not proven absolutely: the production key was not read, so "nil in SaveTest" does not demonstrate that the production key exists.
- Whether SaveTest could ever write to a production store is argued from platform behaviour (stores belong to a universe) and one read result, not from a documented guarantee I could cite.
- The SaveTest place carries the production PlayerData code unchanged. A Play session or a joined player in the SaveTest universe would create test-universe saves under the existing store name. That is isolated but unmarked; the guard and rename were not applied.
- ProfileStore is not yet in the test place; no persistence test has run.

## Outstanding problems / pending owner decisions
D1 (library vs custom), D4 (production API setting off), D5-D13 as listed in `TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md`; approval to place the pinned ProfileStore file in the SaveTest place; approval for the first DataStore write in SaveTest; confirmation of production's API setting.

## Ready for acceptance?
Yes as an environment-preparation milestone. No persistence implementation is authorized.
=== END FILE ===

=== FILE: TASK-005/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-005

**Claude changed no game script, Config value, saved data, Studio instance setting or published content, and published nothing. Claude made no DataStore write.** Owner-performed changes (outside Claude's hands): creation and publishing of the SaveTest experience, enabling Studio API access in the SaveTest place, privacy setting, and the local copies `backups\2026-10-14\LighthouseKeepers_2026-10-14_v149.rbxl` and `backups\2026-10-14\savetest\LighthouseKeepers_SaveTest_from_v148.rbxl` (identical to v149).

Files created by Claude in `C:\RobloxProjects\LighthouseKeepers\docs\audits\TASK-005\`:
| File | Purpose |
|---|---|
| `AUDITOR_REPORT.md`, `CHANGE_MANIFEST.md`, `TEST_EVIDENCE.md`, `AUDITOR_QUESTIONS.md` | Standard package |
| `SETUP_PLAN.md` | The plan and the owner/approval markers, written before any action |
| `SETUP_RESULTS.md` | What actually happened against the plan, IDs, deviations |
| `REVISED_TEST_MATRIX_V2.md` | Test matrix updated for the source-verification findings |

No source diffs: no code changed, none written to `src\`. Nothing from Outlaw City is in this package. The pinned ProfileStore file remains in `vendor-review\ProfileStore_45c9847\` and is not part of the package or of any Roblox place.
=== END FILE ===

=== FILE: TASK-005/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-005

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (place 128620546156998, universe 10770892134), Edit mode, not running. Players: none. Device/emulator: none. No Play session.

**Could any test have changed production DataStore values? No.** The only Roblox calls were reads inside the SaveTest universe, each preceded by an in-script assertion that PlaceId/GameId equal the SaveTest IDs and differ from production.

| # | Test | Expected | Observed | Result |
|---|---|---|---|---|
| 1 | List Studio instances (three times) | production, Outlaw City and SaveTest listed separately by place ID | list showed `Lighthouse Keepers - Staging (132065051336560)`, `Outlaw City (132163592957463)`, `Private lighthouse keepers (128620546156998)` | PASS |
| 2 | Read identity of SaveTest | IDs differ from production | PlaceId 128620546156998, GameId 10770892134, creator user 11752219158, version 3, `IsEdit` true, `IsRunning` false | PASS |
| 3 | Content parity with the backup | counts and lengths equal | ReplicatedStorage 51/9, ServerScriptService 15/14, StarterPlayer 20/17, ServerStorage 632/181, Workspace 90, Lighting 6, Backups 20; Hud 74,224; PlayerData 10,259 | PASS (counts and lengths only, not content hashes) |
| 4 | Store name in the test place | unchanged | `local STORE_NAME = "LighthouseKeepers_PlayerData_v1"` | recorded |
| 5 | Original v148 backup unchanged | same hash | SHA-256 `6AF4E727...03B5C8`, same size and time | PASS |
| 6 | v149 and the savetest copy | identical | both `0C880E87...7307EF` | PASS |
| 7 | T0, attempt 1 (reads of `player_11752219158`, `__access_check`) | read nil | rejected: "502 ... Studio access to APIs is not allowed" (setting not yet effective); nothing read | no result |
| 8 | T0, attempt 2 after the owner saved the setting | read nil | both reads `ok = true`, value nil | PASS |

**Console output:** none beyond the above. **Screenshots / performance measurements:** none.

**Tests not performed:** the owner's Creator Hub ID cross-check against Studio, the production window's API setting, content hashes of scripts, any Play or multiplayer test, any DataStore write (including the optional canary), any ProfileStore test.

**Remaining risks:** see the report's limitations (production key not read; no documented isolation guarantee cited; test place still carries unmarked production code).
=== END FILE ===

=== FILE: TASK-005/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-005

1. **Is T0 sufficient as the isolation gate?** It shows the owner's production-profile key is nil in the SaveTest store, but the production key itself was not read. Do you want a stronger gate (for example, a marker written in SaveTest after approval and the owner confirming production cannot see it), or accept T0 plus platform behaviour?
2. **Unmarked production code in the test place.** The owner declined the rename/guard edit and extra publish because of human-error risk. Do you accept that the SaveTest place keeps the production store name (a different store because of the universe), or should the guard be added later inside a Studio session without publishing?
3. **Production API setting.** It is unknown. Should the next step require the owner to read it (without changing it) before any write in SaveTest, and should D4 (turn it off) be a precondition for loading ProfileStore anywhere?
4. **v149 versus v148.** The test place came from v149 (the owner's later save). Counts and lengths match v148. Is that enough, or should content hashes of the 40 scripts be compared before tests begin?
5. **Matrix v2.** Are the new rows C18-C29 and the changes to C1, C7, C12, C14 adequate? In particular, is published-server testing for session conflicts mandatory because `game.JobId` may be empty in Studio (to be established by C22)?
6. **First write.** Which write should be first in SaveTest: the canary marker, then the legacy-record overwrite test (C12), then the importer (C29)?

No concern has been invented; items 1, 2 and 5 are the real forks.
=== END FILE ===

=== FILE: TASK-005/SETUP_PLAN.md ===
# TASK-005 setup plan: separate private "Lighthouse Keepers SaveTest" experience (D3)

Status: PLAN ONLY. Nothing below has been done. Each step that needs the owner's hands or approval is marked **OWNER**. Claude's steps are read-only toward Roblox unless stated.

## Guard rails (from the owner's D3 message)
Do not modify or publish Lighthouse Keepers production. Do not touch Outlaw City or its Studio window. Use a completely separate universe and record its exact PlaceId and GameId. Preserve the original `.rbxl` backup (it is never opened for this). Import no real player saves or credentials. Do not turn on Studio API access for production. No test DataStore writes until the separate universe and store configuration are verified. ProfileStore is not installed in production; the pinned, hash-verified file is used only in the test environment, and not in this task unless the owner approves it later.

## Steps, one at a time
| # | Who | Action | Risk if done wrongly | Abort rule |
|---|---|---|---|---|
| 0 | Claude | Copy the backup to `C:\RobloxProjects\LighthouseKeepers\savetest\LighthouseKeepers_SaveTest_from_v148.rbxl` and prove the copy has the same SHA-256 as the original. The original is not opened. | none (local file copy inside the workspace) | hash differs: stop |
| 1 | **OWNER** | In Studio open a **new window** (File > New, or launch another Studio) and use **File > Open from File** on the **copy** from step 0. Do not use the Lighthouse Keepers - Staging window and do not touch the Outlaw City window. The new window's title should show the copy's file name. Tell me when it is open. | opening the wrong file | title does not show `LighthouseKeepers_SaveTest_from_v148`: close that window without saving and tell me |
| 2 | Claude | Re-list Studio instances. Identify the copy by name, read `PlaceId` and `GameId` (expected 0 and 0 for an unpublished file) and the script counts, read-only. Confirm production and Outlaw City are still listed unchanged. | none | anything unexpected: stop and report |
| 3 | **OWNER** (the riskiest click) | In the copy's window only: **File > Publish to Roblox As...** and choose **Create new experience** (a new experience, never an existing one, and never plain "Publish to Roblox"). Name it `Lighthouse Keepers SaveTest (private)`. Creator: your own account. Leave monetization and everything optional as it is. If the dialog highlights an existing experience such as "Lighthouse Keepers - Staging", change it to the new-experience option before confirming. If the dialog looks different from this description, stop and show me a screenshot before clicking. | publishing over production. This is the one step that could damage the live game | any doubt: do not click Publish |
| 4 | **OWNER** | In Creator Hub (create.roblox.com/dashboard/creations), open the new experience. Tell me: its **Universe ID**, its **Place ID**, and whether it says **Private**. If it is not private, set it to Private (Settings > Basic Info/Privacy). Confirm there is no monetization. Do not touch the Lighthouse Keepers - Staging experience. | public exposure of a test copy | not private: fix before continuing |
| 5 | Claude | Re-list Studio instances (ids change after publishing). Read `PlaceId` and `GameId` of the copy's window and compare: they must equal the numbers from step 4 and must **not** be 132065051336560 or 10769064643. Record everything. | none (read-only) | any match with production: stop, report |
| 6 | **OWNER** | In the SaveTest window only (title/ID checked in step 5): Game Settings > Security > turn on **Enable Studio Access to API Services** and save. Do not change that setting anywhere else. | enabling it on production by mistake | wrong window: turn it off again and tell me |
| 7 | **OWNER (look only)** | In the **production** window, open Game Settings > Security and **tell me whether API access is currently on or off**. Do not change it (turning it off is decision D4, still pending). | accidental change | do not toggle anything |
| 8 | Claude, with approval | In the SaveTest window only, after steps 5 and 6 are confirmed: change the one constant `STORE_NAME` in `PlayerData` to the test-only name `TEST_LK_PlayerData_v1` and add a guard that raises an error if `game.GameId` equals the production universe 10769064643. This is a code edit in the **test copy only**; I show you the exact diff first and parse-check afterwards. | editing the wrong window | instance id and GameId re-verified immediately before the edit |
| 9 | **OWNER** | In the SaveTest window only: **File > Publish to Roblox** (this updates the SaveTest experience, not production) to send the step 8 change to the test place. | publishing from the wrong window | title/GameId checked first |
| 10 | Claude, **explicit approval needed** | Gate T0 (read only): in the SaveTest universe, read the key `player_11752219158` and one `__access_check` key from the test store; both must be nil. This is a DataStore **read**, no write. | if universes were not isolated it would read production (read-only) | non-nil result: stop everything |
| 11 | Claude, **separate explicit approval needed** | Optional canary: write one marker key `__lk_env_canary` in the test store and read it back, to prove API access works in SaveTest. | a write, but into the test store only | skip unless you approve |

After step 10 (or 11 if approved) I stop, update the test matrix, build the TASK-005 package and ask for permission before any persistence implementation.

## What I will not do in this task
Publish or edit production; enable or change Studio API access on production; open Outlaw City; import real player data; install ProfileStore anywhere; write to any DataStore before steps 5, 6 and 8 are verified and you approve step 10/11; create API keys or ask for credentials.

## Expected results to record
The SaveTest Universe ID and Place ID (from Creator Hub and from `game.GameId` / `game.PlaceId`), Private status, the Studio API setting in both experiences (SaveTest on, production unchanged), the copy's SHA-256 equal to the backup's, script and instance counts equal to the backup, and the T0 read results.
=== END FILE ===

=== FILE: TASK-005/SETUP_RESULTS.md ===
# TASK-005 setup results (what actually happened, 2026-10-14)

Plan: `SETUP_PLAN.md`. This file records the outcome against the plan. Owner approval for D3 (planning and guided setup of a separate private SaveTest experience) came in chat; every later write-capable step waited for a separate answer.

| Plan step | Outcome |
|---|---|
| 0 Claude copies the backup to `savetest\` | **Not done by Claude.** The owner made their own copy before the step was approved: `backups\2026-10-14\savetest\LighthouseKeepers_SaveTest_from_v148.rbxl`, byte-identical (SHA-256 `0C880E87D5909DD1B76AFDDD74ECECF8AC5E809FEBF19FD7AF56DDE4537307EF`) to `backups\2026-10-14\LighthouseKeepers_2026-10-14_v149.rbxl` (the owner's save made after v148). So the test place was built from **v149, not v148**. The original `LighthouseKeepers_2026-10-14_v148.rbxl` is untouched (SHA-256 `6AF4E72746EC7D8B7B2509A65A62A989DA6729051E1ECCBE71B969056D03B5C8`, size and time unchanged). |
| 1 Owner opens the copy in a new window | Done by the owner (not witnessed; inferred from the result) |
| 2 Claude re-lists instances | Done after the fact: the list shows production "Lighthouse Keepers - Staging (placeId 132065051336560)", Outlaw City (132163592957463) and a new window "Private lighthouse keepers (placeId 128620546156998)" |
| 3 Owner publishes as a new experience | Done by the owner (the riskiest step). Claude has no evidence of any change to production (its window still reports place 132065051336560), but Claude did not inspect or compare production's published version, so this is "no sign of a problem", not a verification. The owner can confirm in Creator Hub that production's version history shows no new version from today |
| 4 Owner checks Creator Hub: IDs and Private | Owner reported "it says private". The owner could not find the IDs in Creator Hub, so Claude read them from the Studio window instead (see below). Matching them with Creator Hub's page is left to the owner |
| 5 Claude verifies IDs | **PlaceId 128620546156998, GameId (universe) 10770892134, creator user 11752219158, place version 3**, not equal to production (132065051336560 / 10769064643). Counts equal the backup: ReplicatedStorage 51 instances/9 scripts, ServerScriptService 15/14, StarterPlayer 20/17, ServerStorage 632/181, Workspace 90, Lighting 6, 20 backup folders; `Hud` length 74,224 and `PlayerData` length 10,259 match |
| 6 Owner enables Studio API access in SaveTest | Owner reported "studio api access enabled". The first read attempt was rejected ("Studio access to APIs is not allowed"), so the setting had not yet taken effect; after the owner saved it again, the second attempt worked |
| 7 Owner looks at production's API setting | **Not reported; status unknown.** Nothing was changed. D4 (turn it off) remains pending |
| 8-9 Test-only store name and guard, then publish | **Dropped at the owner's request** ("You are opening a door for human errors"). No edit was made to the SaveTest place and nothing further was published. The store name there stays `LighthouseKeepers_PlayerData_v1`, which is the SaveTest universe's own separate store |
| 10 Gate T0 read | **PASS** after the second attempt (details in `REVISED_TEST_MATRIX_V2.md`) |
| 11 Canary write | **Not requested, not done** |

## Calls made to the SaveTest instance (all read-only)
1. `execute_luau` (Edit): read PlaceId, GameId, counts, string lengths, creator, store-name line. No writes.
2. `execute_luau` (Edit), T0, attempt 1: `GetAsync` x2, rejected by Roblox (no data read).
3. `execute_luau` (Edit), T0, attempt 2: `GetAsync` x2, both returned nil.
No instance was changed, no Play session was started, nothing was published by Claude, and no DataStore write was made by Claude. Each T0 script asserted the SaveTest PlaceId and GameId and that they differ from production before touching `DataStoreService`.

## Observations
- The owner's publishing (step 3) also left `PlaceVersion = 3` on the test place, which means more than one publish happened. Not harmful; recorded for completeness.
- No credentials, API keys or real player records were involved.
- ProfileStore is not installed anywhere; the pinned file remains only in `vendor-review\ProfileStore_45c9847\`.
=== END FILE ===

=== FILE: TASK-005/REVISED_TEST_MATRIX_V2.md ===
# Test matrix v2 (TASK-005): updated for `SOURCE_VERIFICATION_ADDENDUM.md` and the real SaveTest universe — nothing has been run except gate T0

Supersedes `TASK-004/REVISED_TEST_MATRIX.md`. Rows marked NEW or CHANGED come from the addendum findings A-J or from the verified environment.

## 0. Environment (verified)
| Item | Value |
|---|---|
| Test experience | "Private lighthouse keepers" (owner-created, private) |
| PlaceId / GameId (universe) | **128620546156998 / 10770892134**, creator = the owner's user account |
| Production, for contrast | 132065051336560 / 10769064643 (never touched) |
| Studio API access | **ON in SaveTest** (confirmed by a successful read in T0 after the owner saved the setting); production: **not known** (owner did not report it; no change made) |
| Test place content | identical to the owner's v149 save (scripts 9/14/17 live and 181 in ServerStorage, 20 backup folders; `PlayerData` length 10,259; store name still `LighthouseKeepers_PlayerData_v1`, which here is the **test universe's own** store) |
| Hard rules | no Play, Save, Publish or script execution on any instance whose PlaceId/GameId was not just verified; Outlaw City is never touched; no writes to production; no `RemoveAsync`; no import of real player saves; ProfileStore only in this test environment, from the pinned hash-verified file |

## 1. Gate results
| ID | Result |
|---|---|
| **T0** | **PASS (2026-10-14).** From the SaveTest window (IDs asserted inside the script), a read of `player_11752219158` and of `__access_check` in store `LighthouseKeepers_PlayerData_v1` both succeeded and returned nil. The first attempt, before the owner saved the API setting, was rejected with "Studio access to APIs is not allowed" (error 502) and read nothing. Limitation: the production key is documented to hold real progress (progress.md) but production was not read, so "nil here" supports isolation without proving the production key exists. |

## 2. Persistence tests (real DataStore, SaveTest universe only)
Carry-over rows C1-C17 from TASK-004 stay, with these changes:
| ID | Change | Test |
|---|---|---|
| C1 | CHANGED (finding: the fence uses `game.JobId`, which I believe is empty in Studio) | Two-session tests must use **published servers** (reserved/private servers of the test place). Studio-only concurrency results are invalid unless a first test (C22) proves `game.JobId` differs per Studio session |
| C7 | CHANGED (finding: release saves loop until success; shutdown has no internal deadline) | Shutdown with 4 players, injected failures and latency; measure how long release saves run before Roblox ends the server; confirm no hang, and that data written before the failure window is intact |
| C12 | CHANGED (findings: overwrite happens even on a cancelled load; `GetAsync` returns a template for a legacy record) | In the **test** store only: seed a v1-shaped record; (a) `StartSessionAsync` with a `Cancel` that returns true, (b) normal start, (c) `GetAsync`; record whether the record is overwritten, the `OnOverwrite` signal, and what each call returns |
| C14 | CHANGED (finding J: every autosave writes the whole `Data`) | Write budget with 4 players at candidate `AUTO_SAVE_PERIOD` values (60, 120, 300 s) plus `Profile:Save()` after each Pearl credit and purchase |
| C18 NEW | finding D: Studio probe writes `____PS` | Load the library in a Studio session on SaveTest with API access; confirm the key `____PS` appears in the **SaveTest** store and nowhere else; this documents why the library is never loaded in the production place's Studio |
| C19 NEW | finding A: ordinary autosave failures are not retried | Inject a failure on one autosave, then change data, then end the session: confirm the loss window equals one autosave period unless `Profile:Save()` is called, and that the release save then succeeds |
| C20 NEW | finding C | `GetAsync` view of a legacy record returns template data, not the stored table; our importer reads v1 with plain `DataStoreService:GetAsync` instead and gets the real fields |
| C21 NEW | finding G | Player leaves and rejoins the same server quickly: `EndSession` always called on leave; no "already loaded in this session" error; second load returns the saved data |
| C22 NEW | JobId in Studio | Log `game.JobId` in two Studio sessions and in two published servers; record the values |
| C23 NEW | finding B | Measure real time from first conflict to steal with an unresponsive holder (expect about 45 s plus request latency) and with a responsive holder (expect a few seconds) |
| C24 NEW | finding F | `Cancel` callback runs inside the transform: verify a pure, non-yielding `Cancel` behaves, and that a yielding one is not used |
| C25 NEW | finding H | `OnSessionEnd` fires before the final write: verify the adapter does not treat it as "saved"; final data present after `EndSession` completes |
| C26 NEW | finding I | Cancelled first load of a brand-new key: confirm what record is left behind |
| C27 NEW | finding E | Record any warning or behaviour change from `DataStoreOptions:SetExperimentalFeatures({v2 = true})` and re-check on later Roblox releases |
| C28 NEW | mock mode | Run the library in a Studio session without API access and confirm it switches to the in-memory mock (state `NoAccess`) and writes nothing to any store |
| C29 NEW | import safety | Seed v1-shaped fixtures in the **test** v1 store, run the importer: v1 read via plain `GetAsync`; every fixture imports once; a failed v1 read blocks play; v1 records unchanged afterwards (compare version history) |

## 3. Gameplay, crew, validation (unchanged from TASK-004)
P1-P14 (Pearl rules and durable `grants`), CC1-CC8, F1-F2, V0-V9 as in `TASK-004/PEARL_PAYMENT_AND_IDEMPOTENCY.md` and `CREW_FUEL_VALIDATION_REVISION.md`. Real clients are required for first-voyage and harbor-spectator tests.

## 4. Preconditions before any persistence test beyond T0
1. Owner approval for the first DataStore **write** in the test universe (not given yet).
2. Owner confirmation of production's Studio API setting (D4 decides whether to turn it off).
3. Owner approval to place the pinned ProfileStore file into the SaveTest place (not given yet; not done).
4. Agreement on the store names for the tests (`TEST_` prefixed) before any adapter code is written; no code has been changed in the SaveTest place.

## 5. Evidence each row must leave
Test id, verified PlaceId/GameId, number of real servers and clients, injected faults, steps, expected and actual, console lines, pass/fail, and whether production could have been touched (must be "no").
=== END FILE ===

