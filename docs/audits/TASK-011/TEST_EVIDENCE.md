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
