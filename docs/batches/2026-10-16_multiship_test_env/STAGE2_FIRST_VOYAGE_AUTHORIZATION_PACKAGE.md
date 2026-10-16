# Stage 2 authorization package: first real test voyage (2026-10-16)

**Revision 2:** the auditor's review of 1b49741 is folded in.
- The reclaim fix is accepted.
- The `_test` guard is accepted **by source inspection only**. It was not runtime-tested on a live server.
- Corrections 1 and 2 are applied below: Results through the real game loop, and the published-place preflight.

**Status:** prepared, **not executed**.
- Nothing has been published.
- No real DataStore or MemoryStore writes have been made.
- Teleports are inactive and all three switches are off.
- Production Lighthouse Keepers (GameId 10769064643 / PlaceId 132065051336560), SaveTest and Outlaw City were not accessed.

**Target:** only LK Multiship Test.
- GameId 10771229467.
- Harbor 125998212495899.
- Lighthouse Isle 111423375237885.
- Private (universe record `privacyType: "Private"`).

---

## 1. Reclaim late-claim correction (done in this batch)

**Defect:** `PlayerData.reclaim()` returned false when the player had left during the claim, but it did not give back a lock that claim had just obtained.

**Fix** (`PLAYERDATA_RECLAIM_FIX.diff`, PlayerData only):
- `reclaim()` now marks itself in flight with the same `loading` flag as `load()`, so `_onRemoving` records a leave during it (`leftDuringLoad`).
- When the claim succeeds for a player who has left, it calls the Fix A path `releaseAbandoned(player, value)`. That path makes 3 attempts, stops early once the lock is no longer ours, and warns if every attempt fails, leaving the lock to stale takeover.
- It also clears the frozen profile and returns false.
- A re-claim for a player who is still present behaves as before.

**Test hooks:** `PlayerData._test` is now created only when `RunService:IsStudio()`. On live servers it is `nil`.
- The Stage 1 `LKMS_Stage1` hook was already Studio-only.
- Gameplay behaviour is unchanged, since the game never calls either hook.
- **Not runtime-tested:** that `_test` is nil on a live server. This was checked by reading the code only, because Studio cannot run as a non-Studio server.

**Tests:** 19/19 pass on the deterministic fake store (same harness as 93021c7).

| # | Scenario | Result |
|---|---|---|
| C1 | Hand-off with 10 Pearls. Re-claim held in flight. Player leaves (PlayerRemoving), then the claim succeeds. | reclaim returns false. **Lock released** (no session). Not owned. No profile kept. Stored value still 10. PASS |
| C2 | Same, but the player is already gone (Parent nil) before PlayerRemoving runs | Lock released, not owned. PASS |
| A1–A5, B1–B3, R1–R4 | The accepted 93021c7 suite, unchanged | All PASS. B3c also confirms a normal re-claim still reloads 15 under a new owned lock. |

**Old code fails the same test.** C1 was run against the pre-fix module kept in `ServerStorage.Backups.ReclaimFix_before_2026-10-16`:
- Old: `returned=false session=462a6ca6-… owned=true` (the lock leaked).
- New: `returned=false session=nil owned=false`.

**Studio = git (test Harbor window):**
- PlayerData `52bcbf84bcebd5d17755103f7c519206b0c2b8a325cb57e1753591b97d903186`.
- Config `27661b7a…8078` (switches off) and SessionLock `07929579…91a1` are unchanged.
- **All 49/49 scripts** under `src/` equal git branch `multiship-test`. The only Studio-only scripts are the 5 vendor procedural-model drafts in `ServerStorage.ItemDrafts`, the same as production.
- Studio API access is off.

## 2. What is in the two test places today (and why both need a publish)

| Place | Published content now | Current build present? |
|---|---|---|
| Harbor 125998212495899 | The v163 production copy, published when the experience was created. It is production code, with no test adapter, and uses store `LighthouseKeepers_PlayerData_v1` scoped to the test universe. | **No.** The current build exists only in the open Studio window (verified above). |
| Lighthouse Isle 111423375237885 | A new empty place made with Asset Manager > Add New Place | **No** |

Both places get the **same build**. The role comes from `game.PlaceId` through PlaceRole and Config.

## 3. Test-only configuration for Stage 2

There is a single edit in `Shared.Config`, in the Studio window and in git on `multiship-test` only:

```
multiShip = true, sessionLock = true, teleport = true
```

- **Resulting Config SHA-256:** `94ee135c13180be31544db75369b33cedefdb74b5e81303a1f747cb38a9d9651`. This was computed from git, not applied.
- These switches act only when `game.GameId == 10771229467`. On `main`/production they don't exist.
- **Writable allowlist:** `writableUserIds = { 11752219158 }`, the owner only. Any other account plays from memory and is never saved. It also cannot be handed off, so it cannot travel.
- `ISLE_STUDIO_TEST` stays `false`, so a live Isle without a valid manifest fails closed.
- **Store:** `LKMS_TEST_PlayerData_v1`, key `player_11752219158` only. This is the synthetic Stage 1 profile: 25 Pearls, no session.
- **MemoryStore:** sorted map `Voyages`. There is one entry per voyage, keyed by the Isle private server id, with a 600 s expiry.

**API access:**
- Live servers always have DataStore and MemoryStore access. The Studio setting does not affect them.
- **In Studio**, "Enable Studio Access to API Services" is turned on by the owner **only** for my read-only verification reads, in Edit mode. It is turned off at the end.
- **No Studio Play runs while it is on.**
- DataStores are shared between Studio and live servers, so my reads see the real test key.
- MemoryStore is **isolated** between Studio and live servers, per Roblox docs ("The data in MemoryStoreService is isolated between Studio and production", create.roblox.com/docs/cloud-services/memory-stores). So the manifest is checked from the live servers' logs, not from Studio (see section 6).

## 4. Old unlocked test servers: how none can write while SessionLock is active

1. **No unlocked writer of the test store has ever been published.**
   - The only published Harbor build is the v163 copy. It does not know `LKMS_TEST_PlayerData_v1`.
   - The Isle place has no scripts.
2. **The switches-off test build is never published.**
   - The first and only publish already has `sessionLock = true`.
   - So there is never a published build that writes `LKMS_TEST_PlayerData_v1` without the lock.
3. **After both publishes, the owner shuts down all servers** of LK Multiship Test before joining. Use Creator Dashboard > Creations > LK Multiship Test > ⋯ menu (or Server Management) > **Shut Down All Servers**.
   - The experience is Private, and only the owner has ever joined it, so normally none are running.
   - This step guarantees that no old v163 Harbor server stays alive.
4. **Studio writers:**
   - My Studio window holds the same switches-on Config, so any Play there would also be locked.
   - In any case, no Studio Play runs during Stage 2.
   - SaveTest, Outlaw City and Deadzone stay closed to all actions.
5. **Check on join:**
   - The Harbor shows the two-ship layout, which exists only with `multiShip = true`.
   - Its server log has no `PlayerData: could not claim` warning.
   - Optionally, the owner can run this in the F9 Developer Console server command line: `print(game.PlaceVersion, require(game.ReplicatedStorage.Shared.Config).SESSION_LOCK_ENABLED)`. It should print the new version and `true`.

## 5. Owner-controlled steps (each one waits for the owner's explicit go-ahead)

| # | Who | Action | Check |
|---|---|---|---|
| 0 | Owner | Approve this Stage 2 scope | — |
| 1 | Owner | In the **LK Multiship Test** window: File > Save to File. Name it `LKMS_TEST_harbor_2026-10-16_pre-stage2.rbxl` in `backups\2026-10-16\`. | I hash the file and Rojo-check that it equals git. |
| 2 | Me | `list_roblox_studios`, then assert `GameId 10771229467, PlaceId 125998212495899`. Set the three switches to true. Commit to `multiship-test`. | Config = `94ee135c…`. PlayerData, SessionLock and Voyages = git. API off. |
| 3 | Owner | **File > Publish to Roblox**. **Exact target:** experience **LK Multiship Test** (10771229467), place **LK Multiship Test / Harbor, 125998212495899**, which is the start place. Never Lighthouse Keepers - Staging. | Immediately before: I assert the window's `GameId 10771229467, PlaceId 125998212495899`, check that all 49 hashes equal git with switches on, and confirm `PlaceRole` resolves to `"harbor"` (`PLACE_ROLE_OVERRIDE` = nil; the role comes from the PlaceId). |
| 4 | Owner | **No joining the experience between the two publishes.** Then **File > Publish to Roblox As… > LK Multiship Test > Lighthouse Isle**, overwrite. **Exact target:** place **Lighthouse Isle, 111423375237885**. | Afterwards, I re-list studios and assert the window is **GameId 10771229467, PlaceId 111423375237885**. All 49 hashes equal git with switches on, and `PlaceRole` resolves to `"isle"`. |
| 5 | Owner | **Shut Down All Servers** for LK Multiship Test (section 4), after both publishes | — |
| 5a | Me | **Teleport preflight:** within-universe server teleports need no extra setting. "Allow Third Party Teleports" only covers *other* experiences. The public universe record `develop.roblox.com/v1/universes/10771229467/places` lists exactly **Lighthouse Isle 111423375237885** and **LK Multiship Test 125998212495899**, with `rootPlaceId` 125998212495899, `privacyType` **Private** and creator 11752219158 (checked today). I re-check it after the publishes. | The experience stays **Private** throughout. |
| 6 | Owner | Turn **Studio API access on** (in that window's Experience Settings > Security) | My first uncached read, R0, below |

## 6. Bounded test procedure (one crew, one voyage, owner's account only)

There is no second crew, no second account and no forced failure. At each checkpoint the owner pauses until I confirm the read.

| Step | Owner does | I record (uncached `GetAsync` with `UseCache = false` on `player_11752219158`, plus read-only `ListVersionsAsync` on that key only) |
|---|---|---|
| R0 | — | Before join: pearls 25 and session `nil`. The latest version number is noted as the baseline. |
| 1 | Join LK Multiship Test from roblox.com (Harbor) | **Claim token T1**, job = Harbor JobId, pearls 25. The HUD shows 25. |
| 2 | Board **Ship1** and press **SAIL NOW** (alone, 1/4), then wait out the countdown | Harbor F9 server log: `[EVT] DepartureStarted` (ship 1, mode manual) and `[EVT] VoyageLaunched … mode teleport server <privateServerId>`. No `TeleportFailed`. |
| 3 | Arrive in the reserved Isle server | Store: hand-off **release** (session cleared, pearls 25), then **Isle claim token T2 ≠ T1** with job = Isle JobId. **Manifest check (MemoryStore):** Isle F9 server log `[EVT] IsleVoyage crew 1 expected 1`, and **no** `IsleRefused` / `IsleClosed`. Optional, in the Isle server console: `game.PrivateServerId` equals the Harbor log's server id. |
| 4 | Play the Prologue (it awards no Pearls), then **survive Night 1** (log `[EVT] NightSurvived night 1`). On **Night 2**, end the run through normal play: stop refuelling the lamp until it stays dark for the grace period, a **blackout** Defeat. **No shop, Quartermaster or Trader purchases or sales**, and no boss loot (big monsters only come on nights 4, 7, 10 and 13). | **Expected Results award** (`GameState`): Defeat on night 2 counts 1 night survived × `PEARLS_PER_NIGHT` 1 = **1 Pearl**. I record the exact figure shown on Results and the `run` addPearls. Saves and heartbeats stay under T2: versions advance and the token is unchanged. |
| 5 | On Results choose **Main Menu** (or let the timer run out without Play Again). Both send the player back to the harbor. | Store: Isle **release** (session cleared, pearls = 25 + award), then **Harbor claim T3 ≠ T2**. The Harbor HUD Pearls = stored pearls = **25 + the exact Results award** (expected 26). |
| 6 | Leave the game | **Final release:** session `nil`, pearls unchanged. The version list shows the full claim → save/heartbeat → release chain, with one owner at a time. |
| 7 | Owner | Turn Studio API access **off**. I confirm with the rejected probe. |

**Pass criteria:**
- Every claim follows a release.
- The token sequence T1 → T2 → T3 is distinct, and no two sessions overlap.
- The manifest is accepted on the Isle.
- The Pearls persist across all three servers.
- The final session is cleared.
- There are no PlayerData, Voyages or IsleAdmission warnings.

**Stop immediately (no retry) if any of these happen:**
- `could not claim`
- `TeleportFailed`
- `ReclaimFailed`
- `IsleRefused`
- a kick message
- a stored session held by two jobs
- an invalid manifest
- an unexplained profile value, including any Pearls other than 25 + the recorded award
- an overlapping lock

I then record the state and stop for review. **No retry and no second voyage without new authorization.**

**Known uncertainty:** Roblox docs don't say whether `ReserveServer` / `TeleportAsync` work for the creator in a **Private** experience.
- If Roblox refuses the teleport, **stop**. I record the error, the recovery that ran (re-claim or disconnect) and the resulting save ownership.
- The experience is **never** made public, and nothing is retried, without new authorization.

## 7. After the test

- **Switches:**
  - I set the three switches back to `false` in git and in the Studio window, and do not publish that.
  - The published test places keep the locked build until the next approved stage.
  - Publishing a switches-off build would create an unlocked writer of the test store.
- **Evidence package:** `STAGE2_FIRST_VOYAGE_EVIDENCE.md` with tokens, versions, JobIds, log lines and Pearls.
- **Rollback, if ever needed:** use Version History on each test place. It is never applied to production.
- **Not in scope:** two crews, a second account, forced failures, and production.

## Required owner decision

Approve Stage 2 exactly as above: steps 1–6 of section 5 and the procedure in section 6.
- **Authorized boundary:**
  - universe 10771229467; Harbor 125998212495899; Isle 111423375237885;
  - DataStore `LKMS_TEST_PlayerData_v1`, writable profile `player_11752219158` only;
  - MemoryStore map `Voyages` only;
  - exactly one Harbor → reserved Isle → Harbor round trip.
- Until the owner's explicit yes, nothing is published, no switch is turned on and no write or teleport is made.
