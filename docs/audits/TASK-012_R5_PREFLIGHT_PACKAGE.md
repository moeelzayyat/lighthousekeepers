# TASK-012 R5 PREFLIGHT PACKAGE

Combined plain-text package. R5 v3 installed in SaveTest (inert) and checked read-only. Not armed, no live test, nothing published.

## Contents
1. docs/audits/TASK-012/R5_PREFLIGHT_REPORT.md (5234 bytes, SHA-256 b2fea3825f81fbe18b92a655e2e256dc80eab93cec6c7f10501e28916845156b)
2. docs/audits/TASK-012/raw/R5_PF_01_install_result.txt (153 bytes, SHA-256 fbe85c4e072e6c4859dece50efefc8ec366c66cc607180af8c6cd0a835f7f996)
3. docs/audits/TASK-012/raw/R5_PF_02_bootstrap_replace.txt (197 bytes, SHA-256 fc06fda3fd1c4804114f4e31da2d1d6df9c381ede367271689c2a7a565e0b4d9)
4. docs/audits/TASK-012/raw/R5_PF_03_preflight_state.json (1450 bytes, SHA-256 adc26611903d767da6078ddc9981d946a37a0f983e58f279d0ecc20779de6fc8)
5. docs/audits/TASK-012/luau/r5v3/R5v3_install_command.luau (1487 bytes, SHA-256 80ee4baabda9be3e448dfa1eb56a519a3a95a12bc404fe3e9954501ecc7b0186)

=== FILE: docs/audits/TASK-012/R5_PREFLIGHT_REPORT.md ===
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
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R5_PF_01_install_result.txt ===
```text
installed guard 2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57 and R5 ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R5_PF_02_bootstrap_replace.txt ===
```text
removed old bootstrap 85d7bae626e95e988ad4b48ff2b977d7ca7bc13afd3e8df9cdfa28545c00c17f
multi_edit: Created TestOnly_R5Bootstrap (Script) with 1 edits applied (v3 source); disabled by the next call
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/raw/R5_PF_03_preflight_state.json ===
```json
{"isEdit":true,"placeId":128620546156998,"fixtures":{"p202":{"pearls":30,"exists":true,"updatedTime":1792005397531,"version":"08DF2A27AAB2F284.0000000003.08DF2A27AB4375D9.01","sessionLoadCount":1},"p201":{"pearls":25,"exists":true,"updatedTime":1792002154314,"version":"08DF2A201D107A24.0000000005.08DF2A201E27CB15.01","sessionLoadCount":2},"p203":{"pearls":40,"exists":true,"updatedTime":1792013415368,"version":"08DF2A3A4EB43B14.0000000002.08DF2A3A56445552.01","sessionLoadCount":1}},"running":false,"time":1792013624,"bootstrapInstances":1,"compiles":{"R5":true,"guard":true,"boot":true},"r5OpHasRunStore":"TEST_LK_R5_Run","bootAttributes":[],"mainEnabled":false,"installed":{"ServerStorage.TestOnly.ProfileStore":"ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f","ServerStorage.TestOnly.R5CrossServer":"ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4","ServerStorage.TestOnly.R4ShutdownRunner":"1a125835ce528c69c54b795121449a23838022321845ffd81a6771dcd5a47613","ServerScriptService.TestOnly_R5Bootstrap":"646ac454440bb516b3508903420bbc79d74576f4849675cb4a87ae308041f26c","ServerStorage.TestOnly.SaveTestGuard":"2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57"},"gameId":10770892134,"fresh":{"p204":{"exists":false},"p205":{"exists":false}},"stagingFolderGone":true,"bootEnabled":false,"flags":{"R2_SAVE_LOAD":false,"R5_CROSS_SERVER":false,"R4_SHUTDOWN_RELEASE":false,"R3_SERVER_SESSION":false}}
```
=== END FILE ===

=== FILE: docs/audits/TASK-012/luau/r5v3/R5v3_install_command.luau ===
```lua
-- TASK-012 R5 v3 INSTALL COMMAND. NOT RUN. Edit DataModel of the SaveTest window, only AFTER R4 has finished
-- (it changes the guard hash that R4's run command checks). Installs inert code only: no DataStore call, no arming.
-- The bootstrap's v3 source is applied separately with multi_edit and verified by hash in R5v3_arm_command.
assert(game.PlaceId == 128620546156998 and game.GameId == 10770892134, "ABORT ids")
assert(game.PlaceId ~= 132065051336560 and game.GameId ~= 10769064643, "ABORT prod ids")
local RS = game:GetService("RunService")
assert(RS:IsEdit() and not RS:IsRunning(), "ABORT not edit mode")
local SS = game:GetService("ServerStorage")
local T, S = SS.TestOnly, SS.TestOnly_R5v2Staging
local sha = require(T.Sha256)
assert(sha(S.SaveTestGuard.Source) == "2ac3de3d6aeeebf452d7e04633b70f5201c99b7ef0b6590174ac5518ac9a6f57", "ABORT staged guard hash")
assert(sha(S.R5CrossServer.Source) == "ab17dfee61c96bfbd0cd240dcc212918e40dead7b13bbc9a06ad1a157e86aee4", "ABORT staged R5 hash")
local boot = game:GetService("ServerScriptService").TestOnly_R5Bootstrap
assert(boot.Enabled == false and boot:GetAttribute("AuthTest") == nil, "ABORT bootstrap is armed")
for _, name in ipairs({ "SaveTestGuard", "R5CrossServer" }) do
	local new = S[name]:Clone()
	T[name]:Destroy() -- fresh instances, so require() never returns a cached old module
	new.Parent = T
end
S:Destroy()
return "installed guard " .. sha(T.SaveTestGuard.Source) .. " and R5 " .. sha(T.R5CrossServer.Source)
```
=== END FILE ===

