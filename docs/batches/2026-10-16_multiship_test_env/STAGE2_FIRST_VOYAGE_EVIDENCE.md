# Stage 2 evidence: first real test voyage (2026-10-16)

**Result: the round trip Harbor → reserved Isle → Harbor PASSED.**
- The save had one holder at a time: T1 → release → T2 → release → T3 → final release.
- The Isle accepted the manifest.
- No PlayerData, Voyages or SessionLock warnings were reported.
- The final session is clear.

**Deviation from the plan:** the run was lost on **Night 1**, so the Results award was **0 Pearls**, not the expected 1.
- The balance check holds (25 + 0 = 25).
- However, a *changed Pearl balance* crossing servers was **not** demonstrated.
- The values that did change on the Isle and persist back to the Harbor are the run stats: `runs` went from 0 to 2 and `bestNight` from 0 to 1.

**Scope as approved:**
- LK Multiship Test only (GameId 10771229467, Private throughout).
- Store `LKMS_TEST_PlayerData_v1`, key `player_11752219158` only. MemoryStore map `Voyages`.
- One voyage on the owner's account.
- Production Lighthouse Keepers (10769064643 / 132065051336560), SaveTest and Outlaw City were not accessed. There was no second account, no second voyage and no forced failure.

## Build and publication
| Check | Evidence |
|---|---|
| Pre-Stage 2 backup | `backups\2026-10-16\LKMS_TEST_harbor_2026-10-16_pre-stage2.rbxl`, 839,699 bytes, SHA-256 `fe138e7975d5a3d508955fcf585c803763963c8432e846114d511cf67c804d80`. Its Rojo export equals git for 49/49 scripts. |
| Switches on | Config `94ee135c13180be31544db75369b33cedefdb74b5e81303a1f747cb38a9d9651`, commit eb96479. `multiShip`, `sessionLock` and `teleport` are true. `ISLE_STUDIO_TEST` is false, `PLACE_ROLE_OVERRIDE` is nil, and the allowlist is `{11752219158}`. |
| Before the Harbor publish | Window GameId 10771229467 / PlaceId 125998212495899. 49/49 script hashes equal git, role `harbor`, API off. |
| Publishes (by the owner, no join in between) | Harbor 125998212495899 updated 13:39:35Z; Lighthouse Isle 111423375237885 updated 13:54:19Z (Roblox asset records). |
| After the publishes | The Harbor window still had 49/49. The Isle, opened in Studio, was GameId 10771229467 / PlaceId 111423375237885 with **49/49 equal git**, role `isle` and switches on. The Harbor was reopened from the cloud before the join, again with 49/49. |
| Universe | `develop.roblox.com/v1/universes/10771229467`: `privacyType` **Private**, `rootPlaceId` 125998212495899. The places are exactly Lighthouse Isle and LK Multiship Test. |
| Old servers | The owner used **Restart Servers**; the dashboard offers that rather than "Shut Down All Servers". It closes every server running an older version. Nobody was in the game. |
| Studio | API access was on only for my read-only Edit-mode reads. **Studio Play never ran**: every read asserted `not RunService:IsRunning()`. |

## Save ownership (uncached `GetAsync`, `UseCache = false`, on `player_11752219158`)
The commit counter is the second field of the DataStore version string. `ListVersionsAsync` returned only consolidated snapshots, so the counter between reads is the record of how many commits happened.

| Checkpoint (UTC) | Commit # | Pearls | Session (committed metadata) |
|---|---|---|---|
| R0, before joining (14:54) | 0x06 | 25 | none (Stage 1 end state) |
| Snapshot 14:59:54 | 0x0B | 25 | none. The owner joined and left once before the test. That claim and release ended cleanly, with stats unchanged (`runs` 0). |
| **Harbor, T1** (15:01:47 read) | 0x0D | 25 | token **`9fdfa3d9-2d05-483b-a01a-6e4b24bbe0c9`**, job `e15ed51d-36a5-4dee-9274-497a6904714b`, at 15:01:44 (heartbeat) |
| **Isle, T2** (15:07:19 read) | 0x13 | 25 | token **`727d8825-d862-46db-8aa9-55a6ce1350cf`**, job `7e99c828-ea7e-4528-aaf0-ef3f22f13906` (≠ T1 job), at 15:06:24 |
| **Harbor, T3** (15:12:40 read) | 0x1E | 25, stats `{runs 2, bestNight 1, victories 0}` | token **`b69db358-d1aa-4151-8cae-32256c39ec70`**, job `a390879c-ea09-435d-a680-19fac3bf8ca6` (a new Harbor server, ≠ T1 and T2 jobs), at 15:12:31 |
| **Final release** after the owner left (15:15:10 read) | 0x21 | 25, stats `{runs 2, bestNight 1}` | **metadata `[]`** (released) |

**Releases between holders** are inferred, not separately captured.
- SessionLock only takes over a session that has not been renewed for 120 s, and both servers renewed every 60 s up to the hand-off.
- T2 was committed less than 60 s after T1's last renewal at 15:04:44 (arrival around 15:05:27). The Isle's renewals ran up to the return, and T3 followed within seconds.
- So neither new claim could have been a stale takeover. Each one required the previous holder's release.
- There are three distinct tokens and three distinct JobIds, and there was never a moment with two holders.

## Teleport and manifest
- **Harbor:** the owner boarded Ship 1 alone and used Sail Now (E). The countdown ended and Roblox teleported him. **No refusal, error or kick.** The Harbor's log was not captured before he left that server.
- **Isle server log** (owner's F9 Server screenshot, local time UTC−4):
  - `EnteredLobby player=Lighthouse8282 via=first voyage`
  - `IsleVoyage crew=1 expected=1` at 13.3 s, which means **the manifest was accepted**
  - `RunStarted … players=1`
  - `Phase … phase=Prologue`
  - No `IsleRefused` or `IsleClosed`, and no warnings or errors.
- MemoryStore can't be read from Studio (it is isolated from live servers per Roblox docs), so the Isle's acceptance log above is the manifest evidence.
- **Return:** Results > Back to Harbor teleported him to a Harbor server (T3 above). The owner reported no errors.

## Pearls and Results
- Results screen (owner screenshot): "The light went out", **Lost on night 1 of 13**, **0 Pearls** ("Survive a night to earn Pearls"), 17 Shells earned (run-scoped, not saved), next goal 25 / 30.
- The owner played **two runs** in the Isle server; both were lost, consistent with `runs` +2 and `bestNight` 1. This is from the owner's account, because the Isle log after the first screenshot was not captured.
- Harbor balance after the return: **25 = 25 + 0**. **PASS** for the approved check. A non-zero Pearl change across servers remains to be shown in a later run.

## Stop criteria
None triggered. There was no failed claim, teleport or re-claim, no invalid manifest, no overlapping lock and no kick. The one unexplained value (`runs` 2 instead of 1) was explained by the owner before the final step.

## Observations for later (not fixed in this stage)
1. **Arrival:** the Isle place contains the Harbor world, so a traveller first appears on the harbor island. They stay there for about 10 s, while IsleAdmission waits for the crew, before the run starts. This needs an "arriving" screen or an Isle spawn.
2. **Return:** players returning from a voyage land on the Harbor title screen. A traveller should skip it.

## Cleanup
- Studio API access turned **off** by the owner. My probe at 15:15 UTC was rejected: `Studio access to APIs is not allowed`. Studio was not running.
- The switches are set back to `false` **in git only** (`multiship-test`).
  - The Studio window and both published test places keep the reviewed switches-on build until the next approved stage.
  - Publishing a switches-off build would create an unlocked writer of the test store, so that build is never published.
  - **This differs from the package's section 7**, which also turned the Studio window off. Keeping the window on means an accidental publish from it can't put an unlocked writer live.
- Nothing was published to production, and no other key, store or place was touched.
