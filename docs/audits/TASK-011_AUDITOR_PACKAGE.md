# TASK-011 AUDITOR PACKAGE: R3 execution

Combined plain-text package. R3 was executed once in SaveTest (128620546156998 / 10770892134) under the owner's authorization of 2026-10-14 19:15:06Z. Sources are the exact files that were sent to Studio (hashes below, re-verified in Studio before the run).

Result summary: persistence and lock release PASSED; MessagingService PASSED (same server only); BindToClose PASSED (registration only). Play stopped only after safeToStopPlay = true. Main left disabled.

## Contents
1. docs/audits/TASK-011/AUDITOR_REPORT.md (3891 bytes, SHA-256 fe36d8c9bce7aadb3b116432392c25a5efd4a313c90d993c3a333c9938b99498)
2. docs/audits/TASK-011/CHANGE_MANIFEST.md (1997 bytes, SHA-256 1ffabb4dd1a2eed39e9e0851e5f6ef406649d65d69daab7f60ce50b833da4e06)
3. docs/audits/TASK-011/TEST_EVIDENCE.md (4634 bytes, SHA-256 61ab8205fbfcd9fbfd8f5ae021d4358e659b2ad3cbe40b641410979391bb93c5)
4. docs/audits/TASK-011/AUDITOR_QUESTIONS.md (1356 bytes, SHA-256 4f91b9ab5e1a606dea7d2ab118c95050bb6e7c33be09488ae879db4dbf3c1daf)
5. docs/audits/TASK-011/raw/01_preflight_edit.json (336 bytes, SHA-256 3cbefda0a4305b9d834e82c4d935d1cd4449e7fbb5e5abca9220701148ef6d12)
6. docs/audits/TASK-011/raw/02_disable_main_result.txt (37 bytes, SHA-256 9c6f2cef0fb18c026a9e0c6494bb21a5f851108c08effd5a235568222730af85)
7. docs/audits/TASK-011/raw/03_run_command_result.txt (46 bytes, SHA-256 afb416500aeb7b5aa5e861e544405ff2773ef4dba4088582484d39eb0325fd25)
8. docs/audits/TASK-011/raw/04_status_terminal.json (2109 bytes, SHA-256 3066d5347d7d73baef466cc4946da548128e92644a47c786816b202406cc81a2)
9. docs/audits/TASK-011/raw/05_post_stop_check_edit.json (479 bytes, SHA-256 b069cce57e212fb06155f01110aaa873732db0bcac3ea1ef42a2bceb7da63d40)
10. docs/audits/TASK-011/raw/06_console_output.txt (1967 bytes, SHA-256 861998db9f9359fac4d1332eecce8a272168e67cf6a6df9699a1050c102f9f4d)
11. docs/audits/TASK-010/luau/R3_disable_main.luau (892 bytes, SHA-256 1936326a42a2c7f0c26e45559b70c305971d18800faaba71d83c1afc9d28294c)
12. docs/audits/TASK-010/luau/R3_run_command.luau (1938 bytes, SHA-256 56a87fef6ab3799f619c3ec5b6da31288d660d8a30c32a53de3ae0258a6f29dc)
13. docs/audits/TASK-010/luau/R3_status_command.luau (595 bytes, SHA-256 b0a100289d2b7ec2cc82a4e23b4a7848e82eaf088cd712cb448563106ab6b95b)
14. docs/audits/TASK-010/luau/R3_post_stop_check.luau (1585 bytes, SHA-256 b90cee1129ab3b6c2011b4c5720a2ea487fdc5274ab5d2476edeefdb87c32311)
15. docs/audits/TASK-010/luau/R3ServerRunner_v2.luau (14820 bytes, SHA-256 6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733)
16. docs/audits/TASK-010/luau/SaveTestGuard.luau (4636 bytes, SHA-256 4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d)

=== FILE: docs/audits/TASK-011/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-011: R3 execution (one real-server ProfileStore session)

- **Date:** 2026-10-14. The run started at about 19:16:31Z. ProfileStore created the record at 19:16:34Z, and the release write landed at 19:16:37Z.
- **Authorization:** the owner's message "OWNER AUTHORIZATION — EXECUTE R3", 2026-10-14 19:15:06Z. It authorizes one execution of `docs\audits\TASK-010\R3_AUTHORIZATION_REQUEST.md`.
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`. Production and Outlaw City were not touched. Nothing was published.
- **Executed:** once. There were no retries and no re-sends.

## Outcome: three independent results

| Area | Result | Evidence | Scope limit |
|---|---|---|---|
| **ProfileStore persistence and lock release** | **PASSED** | Fresh key (precheck: absent); session started with load count 1; `pearls = 30` seen in the stored record 0.37 s after `Save()`; uncached read showed `ActiveSession` cleared 1.33 s after `EndSession()`. Confirmed again from the Edit DataModel after Play stopped: `pearls 30`, no `ActiveSession`, `SessionLoadCount 1` | Single server, single session. No concurrent or second-server claim. |
| **MessagingService** | **PASSED (same server)** | Subscribe, publish and receive all succeeded on `TEST_LK_R3_fb999583` (step `3a_messaging`). The library's own takeover-topic subscription was present (`librarySubscribedToItsTakeoverTopic = true`) | The publisher and subscriber were the same Studio Play server. Cross-server delivery is **not** shown. |
| **BindToClose** | **PASSED (registration only)** | `game:BindToClose(no-op)` registered without error | Release of an *active* profile at shutdown was **not tested**. The session had already been released before Play stopped. |

The save result was computed only from the stored record. It is not used as evidence for messaging or shutdown.

## Safety and cleanup
- Status was `terminal` on the first poll. At that point `flagReset = true` and `safeToStopPlay = true`, and the session was released in the store. Play was stopped only after that.
- `Main` was disabled before Play and is still disabled now. Because of that, the game's `PlayerData` never loaded, and the console shows only client `WaitForChild` warnings.
- The fixture `player_900000201` was read only. Its `UpdatedTime` (18:22:34Z) predates this run, and its data is unchanged: `pearls 25`, load count 2, released.

## New findings
1. **`game.JobId` is the empty string in a Studio Play server.** This was observed in the identity step and in the stored `ActiveSession = [128620546156998, "", <GUID>]`.
   - It confirms the TASK-004 inference, which until now was unverified.
   - The library fences on PlaceId + JobId + load count. Two Studio Play servers would therefore look like the same server to the fence.
   - So session-conflict tests still need published servers, or another design. They cannot use Studio.
2. **`OnSessionEnd` fired about 0.1 ms after `EndSession()`, while the stored release took 1.33 s.** This matches the source reading: the event fires before the release write. Release must therefore be confirmed from the store, never from the event.
3. **Studio Play servers can use MessagingService.** That answers the open TASK-010 question for same-server use only.

## Deviations
None from the approved steps.
- The status command was sent once, because the run was already terminal at 3.5 s.
- The read-only preflight in step 1 also re-checked module hashes and the flag in Edit. It made no DataStore call.

## Open state
- `Main.Enabled = false` exists **only in the open Studio session**. It has not been saved to a file. If Studio is closed without saving, `Main` returns to enabled.
- The owner is asked to save SaveTest to file as `SaveTest_TASK-011_post.rbxl`.

## Ready for audit
Yes. Stopped after R3. No further operations are planned without new approval.
=== END FILE ===

=== FILE: docs/audits/TASK-011/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-011 (R3 execution)

**Production Lighthouse Keepers, Outlaw City, real player saves and every other key or store: untouched. Nothing published. No game script contents, Config values, economy or gameplay changed.**

## SaveTest Studio session (Edit DataModel; not yet saved to file)
| Instance | Change | Rollback |
|---|---|---|
| `ServerScriptService.Server.Main` | `Enabled` true → **false** (left disabled, as approved) | set `Enabled = true`, or restore `SaveTest_TASK-010_pre.rbxl` |

No other instance changed. The module hashes were re-verified before the run:
- `R3ServerRunner` v2: `6083eca5…b733`
- `SaveTestGuard`: `4d85ffc6…500d`
- `ProfileStore`: `ad437372…0c95f`

## DataStore writes (SaveTest universe 10770892134 only)
| # | Store / key | Operation | Observed |
|---|---|---|---|
| W1 | `____PS` / `____PS` | library Studio probe `SetAsync(os.time())` at require | value `1792001296` → `1792005392` (19:16:32Z) |
| W2 | `TEST_LK_ProfileStore_v2` / `player_900000202` | `UpdateAsync`: session start (record created) | `ProfileCreateTime 1792005394`; stored `ActiveSession` set |
| W3 | same | `UpdateAsync`: save, `pearls = 30` | stored `pearls 30` |
| W4 | same | `UpdateAsync`: release | `ActiveSession` absent; `LastUpdate 1792005395`; `UpdatedTime` 19:16:37Z |

- The key's version string `…0000000003…` is consistent with three writes. Version numbering is not used as proof.
- No recovery `EndSession` was needed.

## Non-persistent actions (Play server, now stopped)
- MessagingService: subscribe, publish and receive on `TEST_LK_R3_fb999583`, then disconnected.
- The library's own subscription to its `PS_<GUID>` takeover topic, with no library publish.
- One no-op `BindToClose` registration, plus the library's own handlers.

## Reads
`player_900000202`, `player_900000201` (fixture, read only), `____PS`. All the runner's reads used `UseCache = false`.

## Files on disk
`docs\audits\TASK-011\`: this package plus `raw\01..06`.
=== END FILE ===

=== FILE: docs/audits/TASK-011/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-011 (R3 execution)

All results below are copied from tool outputs. The raw outputs are in `raw\`.

## Sequence (each step done once)
| Step | Action | Context | Result |
|---|---|---|---|
| 1 | `list_roblox_studios` | — | production `(132065051336560)`, Outlaw City `(132163592957463)`, SaveTest `Private lighthouse keepers (128620546156998)`; SaveTest studio id `e6f3ff12-…` |
| 1 | read-only preflight (no DataStore call) | Edit | IDs 128620546156998 / 10770892134, Edit, not running; runner/guard/ProfileStore hashes match; flag false; Main enabled (`raw\01`) |
| 2 | `R3_disable_main.luau` (SHA `1936326a…294c`) | Edit | `Main.Enabled before=true after=false` (`raw\02`) |
| 3 | `start_stop_play` start | — | "Game Started"; studio list re-checked; state Play, DataModels Client and Server |
| 4 | `R3_run_command.luau` (SHA `56a87fef…29dc`), sent once | Server | `startReal ok=true result=started flagNow=true` (`raw\03`). `flagNow=true` is expected while the runner works |
| 5 | `R3_status_command.luau` (SHA `b0a10028…b95b`), polled once | Server | `status terminal`, `flagReset true`, `sessionReleasedInStore true`, **`safeToStopPlay true`** (`raw\04`) |
| 6 | console captured | Play | client `WaitForChild` infinite-yield warnings only (expected with Main disabled) and `[ProfileStore]: Roblox API services available - data will be saved`. No errors (`raw\06`) |
| 6 | `start_stop_play` stop | — | "Game Stopped"; studio list re-checked; state Edit |
| 7 | `R3_post_stop_check.luau` (SHA `b90cee11…2311`) | Edit | see below (`raw\05`) |
| 7 | console after Stop | Edit | identical to the earlier capture; nothing new from shutdown |

## Runner log (`status().log`, times in seconds from start of `core`)
| Step | t | Data |
|---|---|---|
| 1_identity | 0 | placeId 128620546156998, gameId 10770892134, **jobId ""**, isServer true, isStudio true, isRunning true, privateServerId "", uncachedReads true |
| 2_profilestore_init | 0 | DataStoreState `Access` |
| 3a_messaging | 0.632 | topic `TEST_LK_R3_fb999583`, subscribeOk true, publishOk true, messageReceived true |
| 3b_bindtoclose | 0.632 | registerOk true |
| 3c_fixture_read_only | 0.748 | fixture pearls 25, load count 2, released true |
| 3d_precheck | 0.932 | keyAbsent true |
| 4_session_started | 1.599 | isActive true, sessionLoadCount 1, templateOk true, libraryMessagingSubscribed true, stored ActiveSession `[128620546156998, "", "81018a29-cdf0-484e-a3c0-5f80906c40b3"]` |
| 5a_saved | 2.082 | lastSavedSeen true, secondsToSave 0.366, storedPearls 30 |
| 5b_released | 3.532 | releaseConfirmedInStore true, secondsToStoreRelease 1.333, secondsToOnSessionEnd 0.0000966, finalPearls 30, finalLoadCount 1 |

Probe key: before require `1792001296` (18:08:16Z, from an earlier approved run); after require `1792005392` (19:16:32Z).

## Three results (`status().results`)
```json
{"persistenceAndRelease":{"passed":true,"finalPearls":30,"sessionReleasedInStore":true},
 "messaging":{"tested":true,"passed":true,"testTopicSubscribe":true,"testTopicPublish":true,"testTopicReceived":true,"librarySubscribedToItsTakeoverTopic":true},
 "bindToClose":{"tested":true,"passed":true,"note":"registration only; release of an ACTIVE profile at shutdown is not tested by R3"}}
```

## Final stored record (uncached read in the Play server)
`Data`: pearls 30, the rest equal to the template. `MetaData`: `SessionLoadCount 1`, `ProfileCreateTime 1792005394`, `LastUpdate 1792005395`, **no `ActiveSession`**. `WasOverwritten false`.

## Post-stop check (Edit DataModel, uncached, read-only)
| Key | Result |
|---|---|
| `player_900000202` | exists, pearls 30, activeSession nil, sessionLoadCount 1, UpdatedTime 1792005397531 (19:16:37Z), version `08DF2A27AAB2F284.0000000003.08DF2A27AB4375D9.01` |
| `player_900000201` (fixture) | pearls 25, sessionLoadCount 2, activeSession nil, UpdatedTime 1792002154314 (18:22:34Z, **before** this run), version `08DF2A201D107A24.0000000005.08DF2A201E27CB15.01` |
| `____PS` | value 1792005392, UpdatedTime 19:16:35Z |
| `Main.Enabled` | false |

## What the evidence does and does not show
- **It shows:**
  - the record was released and saved, as returned by the DataStore service to two separate uncached reads (Play server, then the Edit DataModel after Stop);
  - MessagingService works within one Studio Play server;
  - BindToClose registers.
- **It does not show:**
  - what another live server would read;
  - message delivery across servers;
  - release of an active profile during shutdown;
  - any concurrency behaviour.

  All observations come from one Studio process and one account.
=== END FILE ===

=== FILE: docs/audits/TASK-011/AUDITOR_QUESTIONS.md ===
# QUESTIONS FOR AUDITOR / OWNER — TASK-011

1. **Accept R3?** Are the three results acceptable as recorded: persistence and release passed; MessagingService passed for the same server only; BindToClose passed for registration only?
2. **JobId is `""` in Studio Play servers.** This is now verified. It confirms that session-conflict testing cannot be done in Studio. The options are:
   - (a) a guided publish of SaveTest only, then two real servers;
   - (b) drop the conflict rows and rely on the mock evidence (M13);
   - (c) a wrapper with its own per-load token, which would be a design change.

   Which direction?
3. **Shutdown release of an active profile.** Do you want this as R4? It would leave a session open on a third synthetic key, stop Play, then verify release from Edit. That is a new key and new writes, so it needs separate approval.
4. **Cross-server MessagingService.** It needs a published server. Should it be deferred together with item 2?
5. **SaveTest state.** `Main` is disabled only in the open Studio session. Should the owner save SaveTest to file now, as `SaveTest_TASK-011_post.rbxl`? Recommended, so the state is recorded and survives a Studio restart.
6. **Synthetic records.** `player_900000202` (30 Pearls) and the probe value stay as they are. Confirm they should be kept as fixtures. Removing them is not proposed.
=== END FILE ===

=== FILE: docs/audits/TASK-011/raw/01_preflight_edit.json ===
```json
{"isEdit":true,"isRunning":false,"flag":false,"placeId":128620546156998,"mainEnabled":true,"runner":"6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733","gameId":10770892134,"ps":"ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f","guard":"4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d"}
```
=== END FILE ===

=== FILE: docs/audits/TASK-011/raw/02_disable_main_result.txt ===
```text
Main.Enabled before=true after=false
```
=== END FILE ===

=== FILE: docs/audits/TASK-011/raw/03_run_command_result.txt ===
```text
startReal ok=true result=started flagNow=true
```
=== END FILE ===

=== FILE: docs/audits/TASK-011/raw/04_status_terminal.json ===
```json
{"safeToStopPlay":true,"uncachedReads":true,"approvedFlagNow":false,"finalRecord":{"UserIds":[],"RobloxMetaData":[],"GlobalUpdates":[0,[]],"WasOverwritten":false,"Data":{"equippedArmor":"OilskinCoat","stats":{"victories":0,"bestNight":0,"runs":0},"version":1,"equippedWeapon":"DriftwoodHarpoon","owned":{"DriftwoodHarpoon":true},"equippedBeam":"BeamAmber","counts":[],"pearls":30},"MetaData":{"LastUpdate":1792005395,"MetaTags":[],"ProfileCreateTime":1792005394,"SessionLoadCount":1}},"log":[{"privateServerId":"","isRunning":true,"placeId":128620546156998,"step":"1_identity","isStudio":true,"isServer":true,"jobId":"","t":0,"uncachedReads":true,"gameId":10770892134},{"dataStoreState":"Access","step":"2_profilestore_init","t":0},{"messageReceived":true,"topic":"TEST_LK_R3_fb999583","publishOk":true,"t":0.632,"step":"3a_messaging","subscribeOk":true},{"registerOk":true,"step":"3b_bindtoclose","t":0.632},{"fixtureLoadCount":2,"fixturePearls":25,"t":0.748,"step":"3c_fixture_read_only","fixtureReleased":true},{"keyAbsent":true,"t":0.932,"step":"3d_precheck"},{"t":1.599,"storedActiveSession":[128620546156998,"","81018a29-cdf0-484e-a3c0-5f80906c40b3"],"step":"4_session_started","libraryMessagingSubscribed":true,"templateOk":true,"isActive":true,"sessionLoadCount":1},{"storedPearls":30,"secondsToSave":0.36627189978025856,"t":2.082,"step":"5a_saved","lastSavedSeen":true},{"releaseConfirmedInStore":true,"secondsToStoreRelease":1.3327405001036823,"finalLoadCount":1,"step":"5b_released","t":3.532,"secondsToOnSessionEnd":0.00009660003706812859,"finalPearls":30}],"probeAfterRequire":1792005392,"probeBeforeRequire":1792001296,"flagReset":true,"sessionReleasedInStore":true,"status":"terminal","terminal":true,"results":{"bindToClose":{"tested":true,"passed":true,"note":"registration only; release of an ACTIVE profile at shutdown is not tested by R3"},"messaging":{"tested":true,"testTopicSubscribe":true,"testTopicPublish":true,"librarySubscribedToItsTakeoverTopic":true,"passed":true,"testTopicReceived":true},"persistenceAndRelease":{"sessionReleasedInStore":true,"passed":true,"finalPearls":30}}}
```
=== END FILE ===

=== FILE: docs/audits/TASK-011/raw/05_post_stop_check_edit.json ===
```json
{"fixture":{"ok":true,"pearls":25,"exists":true,"updatedTime":1792002154314,"version":"08DF2A201D107A24.0000000005.08DF2A201E27CB15.01","sessionLoadCount":2},"probe":{"ok":true,"updatedTime":1792005395132,"exists":true,"value":1792005392,"version":"08DF2A1E204C399E.0000000002.08DF2A27A9D55078.01"},"mainEnabled":false,"synthetic":{"ok":true,"pearls":30,"exists":true,"updatedTime":1792005397531,"version":"08DF2A27AAB2F284.0000000003.08DF2A27AB4375D9.01","sessionLoadCount":1}}
```
=== END FILE ===

=== FILE: docs/audits/TASK-011/raw/06_console_output.txt ===
```text
Captured twice: once in Play after the terminal status (before Stop), once in Edit after Stop. Both captures were identical:

Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'
Stack Begin
Script 'ReplicatedStorage.Shared.SoundFx', Line 105
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Coach', Line 24
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Inventory', Line 30
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Vitals', Line 10
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Results', Line 23
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Main', Line 15
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Storm', Line 12
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Departure', Line 23
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Menus', Line 28
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("Remotes")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Shop', Line 29
Stack End
Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameState")'
Stack Begin
Script 'Players.Lighthouse8282.PlayerScripts.Client.Hud', Line 34
Stack End
[ProfileStore]: Roblox API services available - data will be saved
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_disable_main.luau ===
```lua
-- TASK-010 R3 PRE-STEP (final). NOT RUN. Edit DataModel of the SaveTest window, after owner approval.
-- Applies the disable manifest: the only change is ServerScriptService.Server.Main.Enabled = false.
-- Rollback: set Enabled = true, or restore SaveTest_TASK-010_pre.rbxl.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local main = game:GetService("ServerScriptService").Server.Main
assert(main:IsA("Script"), "ABORT Main is not a Script")
local before = main.Enabled
main.Enabled = false
return "Main.Enabled before=" .. tostring(before) .. " after=" .. tostring(main.Enabled)
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_run_command.luau ===
```lua
-- TASK-010 R3 RUN COMMAND (final, for runner v2). NOT RUN. Requires the owner's explicit approval.
-- Sent ONCE through MCP execute_luau with datamodel_type = "Server", in the SaveTest window's Play session,
-- only after: owner approval of R3, the disable manifest applied (Main.Enabled = false), and Play started.
-- Never re-sent, even if the MCP call times out: progress is read with R3_status_command.luau.
assert(game.PlaceId == 128620546156998, "ABORT PlaceId " .. tostring(game.PlaceId))
assert(game.GameId == 10770892134, "ABORT GameId " .. tostring(game.GameId))
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsServer() and RS:IsRunning() and not RS:IsEdit(), "ABORT not a running server")
assert(game:GetService("ServerScriptService").Server.Main.Enabled == false, "ABORT game Main is enabled")
local T = game:GetService("ServerStorage").TestOnly
local sha = require(T.Sha256)
assert(sha(T.ProfileStore.Source) == "ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f", "ABORT ProfileStore hash")
assert(sha(T.SaveTestGuard.Source) == "4d85ffc6f263bb6ed23545e1c8e12a421476377e24bf4920182a5f54a9f2500d", "ABORT guard hash")
assert(sha(T.R3ServerRunner.Source) == "6083eca54de48f186fcbf65b647e4844ab2f38efe027f8777e19795e99bcb733", "ABORT runner hash")
local Guard = require(T.SaveTestGuard)
assert(Guard.APPROVED.R3_SERVER_SESSION == false, "ABORT flag already true")
local R3 = require(T.R3ServerRunner)
assert(R3.status().status == "idle", "ABORT runner not idle: " .. tostring(R3.status().status))
Guard.APPROVED.R3_SERVER_SESSION = true -- the runner resets it to false on every exit path
local ok, res = pcall(R3.startReal)
if not ok then
	Guard.APPROVED.R3_SERVER_SESSION = false
end
return "startReal ok=" .. tostring(ok) .. " result=" .. tostring(res) .. " flagNow=" .. tostring(Guard.APPROVED.R3_SERVER_SESSION)
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_status_command.luau ===
```lua
-- TASK-010 R3 STATUS COMMAND (final). Read-only in-memory status, Server DataModel of the Play session.
-- Play may be stopped only when the returned safeToStopPlay is true
-- (terminal, approval flag reset, and the synthetic session released in the stored record, or never started).
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local T = game:GetService("ServerStorage").TestOnly
return game:GetService("HttpService"):JSONEncode(require(T.R3ServerRunner).status())
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3_post_stop_check.luau ===
```lua
-- TASK-010 R3 POST-STOP CHECK (final). NOT RUN. Edit DataModel of the SaveTest window, after Play has stopped.
-- Read-only: uncached GetAsync of the synthetic key, the fixture and the probe key. No writes.
-- This is a second, independent observation of the stored record (secondary evidence for release).
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local DSS = game:GetService("DataStoreService")
local opts = Instance.new("DataStoreGetOptions")
opts.UseCache = false
local function read(store, key)
	local ok, value, info = pcall(function()
		return DSS:GetDataStore(store):GetAsync(key, opts)
	end)
	local out = { ok = ok }
	if not ok then
		out.error = tostring(value)
		return out
	end
	out.exists = value ~= nil
	if type(value) == "table" then
		out.pearls = value.Data and value.Data.pearls
		local md = value.MetaData
		out.activeSession = md and md.ActiveSession
		out.sessionLoadCount = md and md.SessionLoadCount
	else
		out.value = value
	end
	out.version = info and info.Version
	out.updatedTime = info and info.UpdatedTime
	return out
end
return game:GetService("HttpService"):JSONEncode({
	synthetic = read("TEST_LK_ProfileStore_v2", "player_900000202"),
	fixture = read("TEST_LK_ProfileStore_v2", "player_900000201"),
	probe = read("____PS", "____PS"),
	mainEnabled = game:GetService("ServerScriptService").Server.Main.Enabled,
})
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/R3ServerRunner_v2.luau ===
```lua
-- ServerStorage.TestOnly.R3ServerRunner  (v2, TASK-010 corrections)
-- SAVETEST ONLY. Test-only server runner for the first real-server test (R3). A ModuleScript in ServerStorage:
-- it NEVER runs by itself, starting Studio Play does not run it, and nothing in the game requires it.
--
-- It may touch ONLY (Guard.OPERATIONS.R3_SERVER_SESSION):
--   ProfileStore: New("TEST_LK_ProfileStore_v2"), StartSessionAsync("player_900000202") without params,
--                 and on that profile Save and EndSession.
--   Raw DataStore reads (GetAsync only, cache bypassed when the engine allows): TEST_LK_ProfileStore_v2/player_900000202,
--                 TEST_LK_ProfileStore_v2/player_900000201 (the R2 regression fixture: READ ONLY), ____PS/____PS.
--   MessagingService: one test topic "TEST_LK_R3_<id>" (subscribe + one publish to itself), then disconnect.
--   game:BindToClose: registers one no-op callback, only to learn whether registration is allowed here.
-- The outcome is reported as THREE INDEPENDENT results: persistenceAndRelease, messaging, bindToClose.
-- A passing save never implies that messaging or shutdown release works.
-- Entry points (no argument can change store, key or module):
--   R3.runMock(vendorSource)  -- vendor TEXT vs in-memory fakes, Edit mode; no real DataStore/MessagingService call
--   R3.startReal()            -- real module, real DataStore, ONLY in a running Studio server (Play), ONLY with approval
--   R3.status()               -- in-memory status, no DataStore call

local Guard = require(script.Parent.SaveTestGuard)
local R3 = {}

R3.OPERATION = "R3_SERVER_SESSION"
R3.TEST_PEARLS = 30
R3.TEMPLATE = {
	version = 1,
	pearls = 0,
	owned = { DriftwoodHarpoon = true },
	counts = {},
	equippedArmor = "OilskinCoat",
	equippedWeapon = "DriftwoodHarpoon",
	equippedBeam = "BeamAmber",
	stats = { runs = 0, victories = 0, bestNight = 0 },
}
R3.state = { status = "idle", terminal = false, log = {} }

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- interval: seconds between checks; checks that read the real DataStore use 1 s
local function waitUntil(cond, timeout, interval)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > timeout then
			return false, os.clock() - t0
		end
		task.wait(interval or 0.05)
	end
	return true, os.clock() - t0
end

local function restrict(PS, op)
	local proxy = {}
	function proxy.New(storeName, template)
		assert(storeName == op.store, "R3 ABORT: store not allowed: " .. tostring(storeName))
		local real = PS.New(storeName, template)
		local storeProxy = {}
		function storeProxy:StartSessionAsync(key, params)
			assert(key == op.key, "R3 ABORT: key not allowed: " .. tostring(key))
			assert(params == nil, "R3 ABORT: no StartSessionAsync params are allowed")
			return real:StartSessionAsync(key)
		end
		return storeProxy
	end
	return proxy
end

-- deps = { PS, readRaw(store,key), probeMessaging() -> table, probeBindToClose() -> table, identity = table }
local function core(deps, op)
	local state = R3.state
	local t0 = os.clock()
	local function note(step, data)
		data.step = step
		data.t = math.floor((os.clock() - t0) * 1000) / 1000
		table.insert(state.log, data)
	end
	local function raw()
		return deps.readRaw(op.store, op.key)
	end

	local profile
	local ok, err = pcall(function()
		-- 1. server identity
		note("1_identity", deps.identity)

		-- 2. ProfileStore initialization (state after the module loaded)
		note("2_profilestore_init", { dataStoreState = deps.PS.getState and deps.PS.getState() or nil })

		-- 3. MessagingService and BindToClose availability: recorded separately, never abort the persistence test
		local okM, m = pcall(deps.probeMessaging)
		state.messaging = okM and m or { probeError = tostring(m) }
		note("3a_messaging", state.messaging)
		local okB, b = pcall(deps.probeBindToClose)
		state.bindToClose = okB and b or { probeError = tostring(b) }
		note("3b_bindtoclose", state.bindToClose)

		-- regression fixture (read only) and precheck of the new key
		local fixture = deps.readRaw(op.store, op.fixtureKey)
		note("3c_fixture_read_only", {
			fixturePearls = fixture and fixture.Data and fixture.Data.pearls,
			fixtureReleased = fixture ~= nil and fixture.MetaData ~= nil and fixture.MetaData.ActiveSession == nil,
			fixtureLoadCount = fixture and fixture.MetaData and fixture.MetaData.SessionLoadCount,
		})
		local pre = raw()
		note("3d_precheck", { keyAbsent = pre == nil })
		assert(pre == nil, "R3 ABORT: the test key already exists; nothing was written")

		-- 4. fresh synthetic session
		local store = deps.PS.New(op.store, R3.TEMPLATE)
		profile = store:StartSessionAsync(op.key)
		assert(profile ~= nil, "R3 ABORT: StartSessionAsync returned nil")
		local endedAt
		profile.OnSessionEnd:Connect(function()
			endedAt = os.clock()
		end)
		-- the library subscribes to its takeover topic in a separate thread; give it a moment, then look
		local subscribed = waitUntil(function()
			return profile.roblox_message_subscription ~= nil
		end, 5)
		state.librarySubscribed = subscribed
		local rec1 = raw()
		note("4_session_started", {
			isActive = profile:IsActive(),
			sessionLoadCount = profile.SessionLoadCount,
			templateOk = deepEqual(profile.Data, R3.TEMPLATE),
			libraryMessagingSubscribed = subscribed,
			storedActiveSession = rec1 and rec1.MetaData and rec1.MetaData.ActiveSession,
		})
		assert(profile:IsActive() and profile.SessionLoadCount == 1, "R3 ABORT: session not active or load count not 1")

		-- 5. one controlled save and release
		profile.Data.pearls = R3.TEST_PEARLS
		profile:Save()
		local saved, savedAfter = waitUntil(function()
			return profile.LastSavedData ~= nil and profile.LastSavedData.pearls == R3.TEST_PEARLS
		end, 20)
		local rec2 = raw()
		note("5a_saved", {
			lastSavedSeen = saved,
			secondsToSave = savedAfter,
			storedPearls = rec2 and rec2.Data and rec2.Data.pearls,
		})
		assert(saved and rec2 and rec2.Data.pearls == R3.TEST_PEARLS, "R3 ABORT: save not confirmed in the store")
		local endCalledAt = os.clock()
		profile:EndSession()
		local released, relAfter = waitUntil(function()
			local r = raw()
			return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil and r.Data.pearls == R3.TEST_PEARLS
		end, 20, 1)
		local final = raw()
		note("5b_released", {
			releaseConfirmedInStore = released,
			secondsToStoreRelease = relAfter,
			secondsToOnSessionEnd = endedAt and (endedAt - endCalledAt) or nil,
			finalPearls = final and final.Data and final.Data.pearls,
			finalLoadCount = final and final.MetaData and final.MetaData.SessionLoadCount,
			finalActiveSession = final and final.MetaData and final.MetaData.ActiveSession,
		})
		assert(released, "R3 ABORT: release not confirmed in the store")
	end)

	-- recovery: never leave the session open
	if profile and profile:IsActive() then
		profile:EndSession()
		note("recovery_end_session", { because = tostring(err) })
		waitUntil(function()
			local r = raw()
			return r ~= nil and r.MetaData ~= nil and r.MetaData.ActiveSession == nil
		end, 20, 1)
	end
	local okFinal, finalRecord = pcall(raw)
	state.finalReadOk = okFinal
	state.finalRecord = okFinal and finalRecord or nil
	state.sessionEverStarted = profile ~= nil
	state.error = (not ok) and tostring(err) or nil

	-- THREE INDEPENDENT RESULTS
	local m = state.messaging or {}
	local b = state.bindToClose or {}
	local fr = state.finalRecord
	state.results = {
		persistenceAndRelease = {
			passed = ok,
			finalPearls = fr and fr.Data and fr.Data.pearls,
			sessionReleasedInStore = fr ~= nil and fr.MetaData ~= nil and fr.MetaData.ActiveSession == nil,
			error = state.error,
		},
		messaging = {
			tested = m.skippedInMock ~= true and m.probeError == nil,
			passed = (m.subscribeOk == true and m.publishOk == true and m.messageReceived == true),
			testTopicSubscribe = m.subscribeOk,
			testTopicPublish = m.publishOk,
			testTopicReceived = m.messageReceived,
			librarySubscribedToItsTakeoverTopic = state.librarySubscribed,
		},
		bindToClose = {
			tested = b.skippedInMock ~= true and b.probeError == nil,
			passed = b.registerOk == true,
			registerError = b.registerError,
			note = "registration only; release of an ACTIVE profile at shutdown is not tested by R3",
		},
	}
	return ok
end

-- Edit-mode dry run against in-memory fakes. Makes no real DataStore, MessagingService or BindToClose call.
function R3.runMock(vendorSource)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[R3.OPERATION]
	assert(op ~= nil, "unknown operation")
	local MockBackend = require(script.Parent.MockBackend)
	R3.state = { status = "running-mock", terminal = false, log = {} }
	local world = MockBackend.newWorld()
	local h = MockBackend.loadVendor(vendorSource, world, { PlaceId = Guard.SAVETEST_PLACE_ID, JobId = "JOB_A" })
	assert(waitUntil(function()
		return h.PS.DataStoreState == "Access"
	end, 3), "mock state never Access")
	MockBackend.seed(world, op.store, op.fixtureKey, {
		Data = { pearls = 25 },
		MetaData = { SessionLoadCount = 2 },
		GlobalUpdates = { 0, {} },
	})
	local restricted = restrict(h.PS, op)
	restricted.getState = function()
		return h.PS.DataStoreState
	end
	local deps = {
		PS = restricted,
		identity = { mock = true, jobId = "JOB_A" },
		readRaw = function(store, key)
			return MockBackend.record(world, store, key)
		end,
		probeMessaging = function()
			return { skippedInMock = true }
		end,
		probeBindToClose = function()
			return { skippedInMock = true }
		end,
	}
	core(deps, op)
	local writes = {}
	for _, w in ipairs(world.writes) do
		table.insert(writes, w.op .. " " .. w.store .. "/" .. w.key)
	end
	R3.state.mockWrites = writes
	R3.state.status = "mock-terminal"
	R3.state.terminal = true
	h.destroy()
	return R3.state
end

-- Real path: only inside a RUNNING Studio server, only with Guard.APPROVED.R3_SERVER_SESSION == true.
-- Returns at once; poll R3.status(). The flag is reset to false on every exit path.
function R3.startReal()
	local op = Guard.assertOperationApproved(R3.OPERATION)
	local RunService = game:GetService("RunService")
	assert(RunService:IsServer() and RunService:IsRunning() and not RunService:IsEdit(), "R3 ABORT: must run in a running server")
	assert(R3.state.status ~= "running", "R3 already running")
	local psModule = script.Parent:FindFirstChild("ProfileStore")
	assert(psModule ~= nil and psModule:IsA("ModuleScript"), "ProfileStore module missing")
	R3.state = { status = "running", terminal = false, log = {}, startedAt = os.time() }

	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = game:GetService("HttpService")
	local allowedRaw = op.rawReads
	-- bypass the local GetAsync cache when the engine supports it, so release is confirmed from the service
	local okOpts, getOptions = pcall(function()
		local o = Instance.new("DataStoreGetOptions")
		o.UseCache = false
		return o
	end)
	R3.state.uncachedReads = okOpts
	local function readRaw(store, key)
		assert(allowedRaw[store .. "/" .. key] == true, "R3 ABORT: raw read not allowed: " .. store .. "/" .. key)
		local ds = DataStoreService:GetDataStore(store)
		if okOpts then
			return ds:GetAsync(key, getOptions)
		end
		return ds:GetAsync(key)
	end

	R3.state.probeBeforeRequire = select(2, pcall(readRaw, "____PS", "____PS"))
	local ok0, PS = pcall(require, psModule) -- fresh server DataModel: this runs the library's Studio probe once
	if not ok0 then
		Guard.APPROVED[R3.OPERATION] = false
		R3.state.status = "crashed"
		R3.state.terminal = true
		R3.state.error = "require failed: " .. tostring(PS)
		return "failed to load module"
	end
	waitUntil(function()
		return PS.DataStoreState ~= "NotReady"
	end, 20)
	R3.state.probeAfterRequire = select(2, pcall(readRaw, "____PS", "____PS"))

	local restricted = restrict(PS, op)
	restricted.getState = function()
		return PS.DataStoreState
	end
	local deps = {
		PS = restricted,
		readRaw = readRaw,
		identity = {
			placeId = game.PlaceId,
			gameId = game.GameId,
			jobId = game.JobId,
			isServer = RunService:IsServer(),
			isStudio = RunService:IsStudio(),
			isRunning = RunService:IsRunning(),
			privateServerId = game.PrivateServerId,
			uncachedReads = okOpts,
		},
		probeMessaging = function()
			local MessagingService = game:GetService("MessagingService")
			local topic = "TEST_LK_R3_" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
			local got = false
			local okSub, conn = pcall(function()
				return MessagingService:SubscribeAsync(topic, function()
					got = true
				end)
			end)
			local okPub, pubErr = false, nil
			if okSub then
				okPub, pubErr = pcall(function()
					MessagingService:PublishAsync(topic, { r3 = true })
				end)
				waitUntil(function()
					return got
				end, 5)
				pcall(function()
					conn:Disconnect()
				end)
			end
			return {
				topic = topic,
				subscribeOk = okSub,
				subscribeError = (not okSub) and tostring(conn) or nil,
				publishOk = okPub,
				publishError = (not okPub) and pubErr and tostring(pubErr) or nil,
				messageReceived = got,
			}
		end,
		probeBindToClose = function()
			local okB, errB = pcall(function()
				game:BindToClose(function() end)
			end)
			return { registerOk = okB, registerError = (not okB) and tostring(errB) or nil }
		end,
	}
	task.spawn(function()
		local okRun, errRun = pcall(core, deps, op)
		Guard.APPROVED[R3.OPERATION] = false -- ALWAYS reset
		R3.state.status = okRun and "terminal" or "crashed"
		if not okRun then
			R3.state.error = tostring(errRun)
		end
		R3.state.terminal = true
	end)
	return "started"
end

function R3.status()
	local fr = R3.state.finalRecord
	return {
		status = R3.state.status,
		terminal = R3.state.terminal == true,
		approvedFlagNow = Guard.APPROVED[R3.OPERATION],
		flagReset = Guard.APPROVED[R3.OPERATION] == false,
		sessionReleasedInStore = fr ~= nil and fr.MetaData ~= nil and fr.MetaData.ActiveSession == nil,
		-- Play may be stopped only when this is true: terminal, flag reset, and either no session was ever started
		-- or the final (uncached) read shows the session released.
		safeToStopPlay = R3.state.terminal == true
			and Guard.APPROVED[R3.OPERATION] == false
			and (R3.state.sessionEverStarted ~= true
				or (R3.state.finalReadOk == true and fr ~= nil and fr.MetaData ~= nil and fr.MetaData.ActiveSession == nil)),
		results = R3.state.results,
		error = R3.state.error,
		uncachedReads = R3.state.uncachedReads,
		probeBeforeRequire = R3.state.probeBeforeRequire,
		probeAfterRequire = R3.state.probeAfterRequire,
		finalRecord = fr,
		mockWrites = R3.state.mockWrites,
		log = R3.state.log,
	}
end

return R3
```
=== END FILE ===

=== FILE: docs/audits/TASK-010/luau/SaveTestGuard.luau ===
```lua
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

-- Per-operation approvals (TASK-009). All false by default. An operation may touch a real DataStore only while its
-- flag is true, and only the store/key/operations listed for it here; the entrypoint resets its own flag on every exit.
Guard.APPROVED = { R2_SAVE_LOAD = false, R3_SERVER_SESSION = false }
Guard.OPERATIONS = {
	-- TASK-010 (proposed, not approved): first real-server session test. player_900000201 is the R2 regression
	-- fixture and is READ ONLY here.
	R3_SERVER_SESSION = {
		store = "TEST_LK_ProfileStore_v2",
		key = "player_900000202",
		fixtureKey = "player_900000201",
		requiresRunningServer = true,
		profileStoreOps = { New = true, StartSessionAsync = true }, -- no params (no Steal, no Cancel)
		profileOps = { Save = true, EndSession = true },
		rawReads = { -- GetAsync only
			["TEST_LK_ProfileStore_v2/player_900000202"] = true,
			["TEST_LK_ProfileStore_v2/player_900000201"] = true,
			["____PS/____PS"] = true,
		},
	},
	R2_SAVE_LOAD = {
		store = "TEST_LK_ProfileStore_v2",
		key = "player_900000201",
		profileStoreOps = { New = true, StartSessionAsync = true }, -- no params (no Steal, no Cancel)
		profileOps = { Save = true, EndSession = true },
		rawReads = { -- GetAsync only
			["TEST_LK_ProfileStore_v2/player_900000201"] = true,
			["____PS/____PS"] = true,
		},
	},
}

function Guard.assertOperationApproved(name)
	Guard.assertSaveTest()
	local op = Guard.OPERATIONS[name]
	assert(op ~= nil, "SaveTestGuard ABORT: unknown operation " .. tostring(name))
	assert(Guard.APPROVED[name] == true, "SaveTestGuard ABORT: operation not approved: " .. tostring(name))
	Guard.assertStoreName(op.store)
	return op
end

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
```
=== END FILE ===

