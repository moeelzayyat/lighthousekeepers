# Multi-ship test experience: setup, test-only adapter and the next controlled test (2026-10-16)

**Production is unchanged.** Lighthouse Keepers (GameId 10769064643 / PlaceId 132065051336560):
- Its code is branch `main` at 659dca8, the post-safeguards build.
- PlayerData, its flags and its save format are untouched.
- Nothing was published or written there.
- SaveTest is frozen and Outlaw City is untouched.

## 1. The test experience (created by the owner, verified in Studio)
| | Value | How it was verified |
|---|---|---|
| Experience | **LK Multiship Test** | Studio window title |
| GameId | **10771229467** | `game.GameId`; not 10769064643 |
| Harbor (start place) | **125998212495899** | `game.PlaceId` |
| Lighthouse Isle | **111423375237885** | `AssetService:GetGamePlacesAsync()` lists exactly these two places |
| Creator | User 11752219158 (the owner) | `game.CreatorId` |
| Studio API access | **off** | DataStore probe rejected |

**How it was created:**
- The owner closed the production window first.
- The source was a **copy** of the post-safeguards backup: `LKMS_TEST_harbor_source.rbxl`, copied from `backups\2026-10-16\LighthouseKeepers_2026-10-16_v163_post-safeguards.rbxl` (SHA-256 `aadd00c3…7f0b`).
- I verified it was **unattached** (PlaceId 0 / GameId 0) before the owner used "Publish to Roblox As → Create new experience".
- **Baseline check:** the v163 Rojo export equals `main` for **49 of 49** scripts.

## 2. Test-only build (branch `multiship-test`; loaded into the test Harbor window, not yet published)
The exact diff against production is `TEST_BRANCH_VS_PRODUCTION.diff`. These four scripts differ, and Studio equals git for each:

| Script | SHA-256 | Change |
|---|---|---|
| `Shared.Config` | `f081953bbf5745575344669a65d0a2942a309503537ed512da9e4b53fa4ea225` | `MULTISHIP_TEST` with the three IDs above. `IS_MULTISHIP_TEST` is true only when `game.GameId == 10771229467`. The switches `multiShip`, `sessionLock` and `teleport` are all **false**. |
| `Server.PlayerData` | `614756da126e5939e771cf6acede6ec9f012ea65024f3a5e7fb7f47b1fd43550` | Test experience only: store `LKMS_TEST_PlayerData_v1`. With `sessionLock` on, it uses SessionLock as listed below this table. The profile format is unchanged. |
| `Server.Voyages` | `a4727ee78d8c1b7e46a3e7decfd3116469e1b67e79f78b1dbf60c06dbf7efd6e` | Attempt-specific recovery (section 3) |
| `Server.Main` | `b3dd58e820055b4615ecd4ed978065ec5ddbeabe8d1385ac9f7fc9a821dcadf0` | Voyages gets `playerData = PlayerData` only when in the test experience **and** `sessionLock` is on |

How PlayerData uses SessionLock when `sessionLock` is on:
- **Claim on join:** `claim(key, newProfile())`.
- **Saves:** confirmed against the stored metadata. A "lock lost" result means this server never writes that player's save again.
- **Heartbeat:** sent every 60 s while the profile is unchanged.
- **Release:** on PlayerRemoving and BindToClose.
- **`handoff`:** freeze, then an awaited release. While frozen the profile is parked, so every mutator sees no profile and refuses.
- **`reclaim`:** claims again and unfreezes.

**Production cannot be affected:**
- Every new code path needs `game.GameId == 10771229467`.
- DataStores are scoped to one experience, so the test universe cannot reach production's `LighthouseKeepers_PlayerData_v1`.
- In addition, the test store has a different name.

## 3. Remaining teleport safety (implemented; 12/12 tests pass)
**What changed:**
- **Per-player attempt token:** every journey (harbor → isle, isle → harbor) gets a token, `VoyageAttempt`.
- **Attempt-specific recovery:** the watchdog and every failure report carry the token of their own attempt. A stale token is ignored and logged as `StaleRecoveryIgnored`. TeleportInitFailed (which has no token) applies to the current journey.
- **One recovery per player:** concurrent reports cause a single re-claim.
- **Bounded save calls:** every hand-off and re-claim is bounded by `ADAPTER_TIMEOUT` (20 s), including the isle → harbor return.
- **Launch-timeout tickets:** kept from the previous batch.

**Tests** ran in Edit mode in the test Harbor window, against real `Voyages` and `ShipRoster` copies with fake teleport and save services:

| Test | Result |
|---|---|
| Attempt A fails and is recovered; the player starts attempt B; **A's watchdog fires during B and is ignored** (still InTransit on B, no extra re-claim, `StaleRecoveryIgnored`); B's own watchdog then recovers B | PASS (4 checks) |
| Three concurrent failure reports (two with the token, one without): exactly one re-claim | PASS |
| TeleportInitFailed recovers the current journey once; a late duplicate does nothing | PASS (3 checks) |
| Isle → harbor hand-off that hangs: bounded (0.5 s with the test timeout), re-claimed, no teleport | PASS |
| Harbor hand-off that hangs: recovered after the adapter timeout, not only the 60 s watchdog | PASS |
| A cancelled launch ticket still recovers instead of teleporting | PASS |

The first run of two scenarios failed 4 checks. Both causes were in the harness:
- The test did not unlock the ship between journeys. The real harbor does unlock it.
- A Roblox BindableEvent copies the stand-in player table, so the copy had no methods.

After fixing the harness, the reruns passed.

## 4. Exact planned DataStore operations: stage 1 (NOT run; needs the owner's yes)
**Goal:** prove the real SessionLock claim, save, heartbeat and release against a real store, inside the test experience only, in Studio.

| Item | Exact value |
|---|---|
| Experience / place | LK Multiship Test (10771229467) / Harbor 125998212495899, **Studio Play only** |
| Owner setting | Turn on Game Settings > Security > "Enable Studio Access to API Services" **in the LK Multiship Test window only** |
| Code switch | `MULTISHIP_TEST.sessionLock = true`. `multiShip` and `teleport` stay **false**. |
| DataStore | `LKMS_TEST_PlayerData_v1` |
| Keys written | `player_11752219158` (the owner's account, playing in Studio). The existing `__access_check` key is read only. |
| Allowed operations | `UpdateAsync` through SessionLock (claim, save, heartbeat, release); `GetAsync` (`__access_check`, plus a read-only verification read of the owner's key and its metadata) |
| Forbidden | `SetAsync`, `RemoveAsync`, `ListKeysAsync`, any other store or key, any MemoryStore write, any teleport |
| Expected results | 1) First Play: the key is created with the default profile, and `metadata.session.token` is set. 2) Earn or spend a little in game, then stop Play: the release is confirmed, the stored profile holds the change, and `metadata.session` is nil. 3) Second Play: the claim succeeds and the change is loaded. 4) During Play, the read-only verification read shows the live session token, and the heartbeat time increases. |
| After the test | `sessionLock` back to false and Studio API access off, unless stage 2 is approved |

## 5. Next controlled test procedure (stage 2; each step needs the owner's approval)
1. **Publish the test build to both test places**, both owner actions after I verify the window:
   - The Harbor window, **LK Multiship Test 125998212495899**: File > Publish to Roblox. The target is the test Harbor; I confirm the window first.
   - The same build to **Lighthouse Isle 111423375237885**: Publish to Roblox As… > LK Multiship Test > Lighthouse Isle.
2. **Set `multiShip`, `sessionLock` and `teleport` to true** in the test branch only, then republish both test places.
3. **Live test**, with the test experience kept Private, using the owner's account and one alt or friend:
   - Two crews depart from Ship1 and Ship2 at the same time and arrive in two separate Isle servers.
   - Results, then back to the harbor.
   - Saves persist in both directions.
   - One forced failure, for example the alt leaving during the hand-off, is recovered.

Production stays untouched throughout; any production rollout is a separate future decision.

## Owner decisions now
1. Is the test experience set to **Private** (Game Settings > Permissions)? Yes or no.
2. **Approve stage 1** (section 4) exactly as written? Yes or no.
