# TEST EVIDENCE — TASK-009 (R2 real save/load)

**Environment:** owner's Studio session; SaveTest window "Private lighthouse keepers" (PlaceId 128620546156998, GameId 10770892134); **Edit mode, no Play session**; MCP `execute_luau`. Players: none. No game script ran (Edit mode), so the game's `PlayerData` did not load or save.
**Approval:** the owner wrote "execute" in chat at 18:22 UTC after the auditor's conditional acceptance and the pre-execution checks (`PRE_EXECUTION_CHECKS.md`).
**Production / Outlaw City:** not addressed. Production Studio API access: owner-reported OFF since 18:04 UTC (D4).

## 1. Execution
- Studio instances re-listed immediately before the run (production, Outlaw City and SaveTest listed separately).
- `luau/R2_run_command.luau` was sent **once**. It re-checked the three installed hashes (ProfileStore `ad437372…0c95f`, guard `9e74c577…8fab`, entrypoint `8a1cac7a…0a25`), asserted the flag was false, set it true and called `startReal()`. Result (verbatim): `startReal ok=true result=started flagNow=true` (the flag is true while the asynchronous test runs, by design).
- `luau/R2_status_command.luau` (read-only, in-memory) was then called once, after an 8 s wait.

## 2. Result (verbatim status returned by the entrypoint)
```
{"probeBefore":1792001296,"log":[{"probeBefore":1792001296,"jobId":"8a9b54d1-714b-4cae-9410-26112c77f519","t":0.116,"step":"0_precheck","keyAbsent":true},{"storedTopLevelKeys":["Data","GlobalUpdates","MetaData"],"storedActiveSession":[128620546156998,"8a9b54d1-714b-4cae-9410-26112c77f519","2f04eb2f-0194-4e60-be7b-191354d39472"],"storedPearls":0,"step":"1_session1_started","t":0.636,"isActive":true,"sessionLoadCount":1},{"t":0.636,"step":"2_template","dataEqualsTemplate":true},{"stillOwnedAfterSave":true,"storedPearls":25,"secondsToSave":0.2972033000551164,"t":0.933,"step":"3_saved","lastSavedSeen":true},{"releaseConfirmedInStore":true,"secondsToStoreRelease":1.0166491998825223,"onSessionEndFired":true,"step":"4_session1_released","t":1.95,"secondsToOnSessionEnd":0.000009499955922365189,"isActiveNow":false},{"storedActiveSession":[128620546156998,"8a9b54d1-714b-4cae-9410-26112c77f519","119f6c31-6326-414c-8874-8f0ae4b7cb53"],"pearlsLoaded":25,"step":"5_session2_started","sameObjectAsSession1":false,"t":2.233,"isActive":true,"sessionLoadCount":2},{"t":2.233,"pearlsEqual25":true,"step":"6_persisted","loadCountIs2":true},{"releaseConfirmedInStore":true,"secondsToStoreRelease":1.0168126001954079,"t":3.25,"step":"7_session2_released","finalStoredPearls":25,"finalSessionLoadCount":2}],"approvedFlagNow":false,"probeAfter":1792001296,"passed":true,"probeBeforeRequire":1792001296,"finalRecord":{"UserIds":[],"RobloxMetaData":[],"GlobalUpdates":[0,[]],"WasOverwritten":false,"Data":{"equippedArmor":"OilskinCoat","pearls":25,"version":1,"equippedWeapon":"DriftwoodHarpoon","owned":{"DriftwoodHarpoon":true},"equippedBeam":"BeamAmber","counts":[],"stats":{"runs":0,"bestNight":0,"victories":0}},"MetaData":{"MetaTags":[],"LastUpdate":1792002152,"ProfileCreateTime":1792002150,"SessionLoadCount":2}},"status":"done","probeUnchanged":true}
```

## 3. Step-by-step reading
| Step | Expected | Observed | Result |
|---|---|---|---|
| 0 precheck | key absent; probe value recorded | key absent; probe `1792001296` | PASS |
| 1 session 1 start | active; load count 1; stored record has `Data`/`GlobalUpdates`/`MetaData`; stored lock = this session | active; load count 1; keys `Data, GlobalUpdates, MetaData`; `ActiveSession = [128620546156998, "8a9b54d1-…", "2f04eb2f-…"]`; stored pearls 0 | PASS |
| 2 template | profile data equals the template | equal | PASS |
| 3 Pearls 25 + Save | `LastSavedData.pearls == 25` and stored pearls 25, session still owned | after 0.30 s; stored 25; still owned | PASS |
| 4 end session 1 | completion proven by the STORED record (lock released, pearls 25), not by `OnSessionEnd` | `OnSessionEnd` fired 0.0000095 s after `EndSession()` (before any write, as the source says); stored release confirmed at the first 1 s poll | PASS |
| 5 session 2 start | new profile object; load count 2; pearls 25; new lock | new object; load count 2; pearls 25; new session GUID | PASS |
| 6 persisted | 25 | 25 | PASS |
| 7 end session 2 | stored release with pearls 25 | confirmed at the first 1 s poll; final load count 2 | PASS |
| Final stored record | pearls 25, no `ActiveSession`, load count 2 | as expected; `WasOverwritten = false` | PASS |
| Probe key | unchanged (no module re-initialization) | `1792001296` before require, before test and after test | PASS |
| Approval flag | false after the run | `approvedFlagNow = false` | PASS |

## 4. DataStore operations (write/read evidence)
- **Writes** (store `TEST_LK_ProfileStore_v2`, key `player_900000201`): the library performs them; Claude cannot count real calls directly. Evidence: the stored record went from absent to created (session 1 start), to pearls 25 while locked (save), to unlocked (release), to locked with load count 2 (session 2 start), to unlocked with load count 2 (release). That is the 5-write sequence; the dry run on fakes made exactly 5. **No retries are evidenced**: the console shows no `[ProfileStore]: DataStore API error` line during R2 (the library logs every failed call that way).
- **Reads** (raw `GetAsync`, allow-listed): the test key about 10 times (precheck, after start, after save, two checks per release, after the second start, final record) and `____PS`/`____PS` 3 times. The pre-execution check made 1 earlier read of the test key.
- **No other store or key** was touched; the probe did not run again.

## 5. Session release evidence
Both releases were confirmed from the stored record (`MetaData.ActiveSession == nil` with pearls 25), not from signals. Final record has no `ActiveSession`. No session is left open.

## 6. Console output during R2 (complete new lines after the backup save)
```
[ProfileStore]: Roblox API services available - data will be saved      <- from the two mock dry runs (fakes), before R2
[ProfileStore]: Roblox API services available - data will be saved      <- same
MessagingService can only be executed by game server
Stack Begin
Script 'ServerStorage.TestOnly.ProfileStore', Line 1340 - function RobloxMessageSubscription
Stack End
MessagingService can only be executed by game server
Stack Begin
Script 'ServerStorage.TestOnly.ProfileStore', Line 1340 - function RobloxMessageSubscription
Stack End
```
The two MessagingService errors are one per session: in Edit mode the library cannot subscribe to its takeover topic (anticipated in the authorization request). Saving was unaffected, but **cross-server takeover messaging does not work in this context**, so session-conflict behaviour must be tested on a real server. Earlier console lines (mock runs, R1, T0) are unchanged from TASK-008.

## 7. Deviations and notes
- None from the approved scope. The run command was sent once; no rerun; no other key or store.
- New fact: in this Studio Edit context `game.JobId` was a GUID (`8a9b54d1-…`), not empty. My earlier inference (TASK-004/005) that it is empty in Studio is **refuted for this context**; whether two Studio sessions get distinct JobIds is still untested.
- The real ProfileStore module stays loaded in this Studio session (no active profiles).
