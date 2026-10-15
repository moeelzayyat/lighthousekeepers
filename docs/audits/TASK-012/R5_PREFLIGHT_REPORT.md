# R5 v3 PREFLIGHT REPORT

- **Date:** 2026-10-14, about 21:33Z
- **Target:** SaveTest only.
- **Scope:** installed inert code and made read-only checks.
- **Not done:** R5 is not armed, no live server was started, and nothing was published. Production and Outlaw City were not touched.

## 1. Identity and privacy
| Check | Result |
|---|---|
| Studio instances re-listed | production `(132065051336560)`, Outlaw City `(132163592957463)`, SaveTest "Private lighthouse keepers" `(128620546156998)`. Only the SaveTest window was used. |
| Asserted inside SaveTest | PlaceId `128620546156998`, GameId `10770892134`, Edit mode, not running |
| `ServerScriptService.Server.Main.Enabled` | **false** |
| SaveTest privacy | not changed by me. It is private as far as the owner has reported, and no access setting was touched. |

## 2. Installed code (in Studio, `raw\R5_PF_03`; every hash equals the reviewed one)
| Installed path | SHA-256 | How |
|---|---|---|
| `ServerStorage.TestOnly.ProfileStore` | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` | unchanged |
| `ServerStorage.TestOnly.SaveTestGuard` (v3) | `2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57` | reviewed `R5v3_install_command` (staged hashes asserted; fresh instance) |
| `ServerStorage.TestOnly.R5CrossServer` (v3) | `ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4` | same command; the staging folder was then removed |
| `ServerScriptService.TestOnly_R5Bootstrap` (v3) | `646ac454440bb516b3508903420bbc79d74576f4849675cb4a87ae308041f26c` | old v1 bootstrap (`85d7bae6…`, disabled, no attributes) removed; v3 source created with `multi_edit`, then disabled in the next call |

Every module compiles. There is exactly one bootstrap instance in the place.

**Disclosure.** `multi_edit` creates a Script enabled. Between its creation and the disabling call it was enabled in **Edit mode**, where scripts do not run, and it had no attributes. Its first line also returns in Studio.

Side effect: the R4 run command can no longer pass its guard-hash check, so R4 cannot be repeated by accident.

## 3. Bootstrap and flags
- Bootstrap `Enabled = false`, **no attributes** (no AuthTest, RunId, window or UserIds).
- `TestOnly.LastR5RunId`: not set.
- All approval flags are false: R2, R3, R4, R5.

## 4. Records (uncached `GetAsync`, read-only)
| Key in `TEST_LK_ProfileStore_v2` | Pearls | Session | Load count | UpdatedTime (unchanged since its own test) |
|---|---|---|---|---|
| `player_900000201` | 25 | released | 2 | 18:22:34Z |
| `player_900000202` | 30 | released | 1 | 19:16:37Z |
| `player_900000203` | 40 | released | 1 | 21:30:15Z |
| `player_900000204` | **absent** | — | — | — |
| `player_900000205` | **absent** | — | — | — |

## 5. Account 2 access: NOT YET VERIFIED
- I cannot check this from Studio; it needs the second account.
- No collaborator permission or privacy setting was changed.
- Proposed check, which needs no join and no setting change: the second account, logged in on its own device, opens `https://www.roblox.com/games/128620546156998` and reports whether a **Play** button is offered. **It must not press Play.** The currently published SaveTest version may still have `Main` enabled, so playing it could make the game save data for that account in SaveTest.
- If Play is not offered, giving access is a separate owner decision, for example adding that account as a collaborator on SaveTest only. **It needs your approval before I or you change anything. SaveTest is not made public.**

## 6. Publish targets and owner actions (unchanged plan; none authorized yet)
| # | Action | Target |
|---|---|---|
| 1 | (recommended) File > Save to File, as `backups\2026-10-14\savetest\SaveTest_TASK-012_R5_preflight.rbxl` | the SaveTest window "Private lighthouse keepers" |
| 2 | account 2 access check (section 5) | SaveTest page only |
| 3 | **Publish 1:** File > Publish to Roblox, after I arm the test and confirm it in-script | SaveTest place `128620546156998` only |
| 4 | account 1 joins first, then account 2; both stay until I report the results are in | SaveTest |
| 5 | both accounts leave | — |
| 6 | **Publish 2 (cleanup):** File > Publish to Roblox, after I disarm (remove the bootstrap) | SaveTest place `128620546156998` only |

Cleanup of live servers:
- Publishing does not stop running servers.
- The run's protections are in place: the deadline, the one-shot run record and the presence gate.
- When the results are in, both accounts leave so both servers empty.
- I confirm from Studio that every session is released before Publish 2.
- Only if a session still shows as held would I ask you to shut SaveTest's servers down from the Creator Hub.

## 7. Remaining approvals before arming
1. **Your two Roblox UserIds:** account 1 (server A) and account 2. These are the only substitutions in the reviewed arm template.
2. **Account 2 access result** (section 5), and your separate approval of any permission change if one is needed.
3. **Approval of the final pre-publish checklist.** I'll prepare it once items 1 and 2 are known. It will repeat the items above with the arm command's final hash.
4. **Your two SaveTest publishes**, each as its own action.
