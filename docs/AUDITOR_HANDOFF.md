# Lighthouse Keepers: handoff for the independent auditor (2026-10-16)

This document is the starting point for a new auditor taking over the review of Lighthouse Keepers. It explains:
- what the project is;
- the hard rules;
- what has been accepted;
- what is deployed where;
- what is pending.

All sources and evidence are in this public repository: https://github.com/moeelzayyat/lighthousekeepers

## 1. The project and how review works
- **Lighthouse Keepers** is an existing Roblox co-op survival game for 1–4 players.
  - The crew keeps a lighthouse beam alive through up to 13 storm nights, fighting sea creatures with the beam, cannons and weapons.
  - Players earn **Shells**, which are spent during a run, and **Pearls**, which are saved and spent at the Quartermaster.
- **Roles:**
  - **Owner:** Hamada (Roblox account Lighthouse8282, UserId 11752219158). The owner performs every publish himself.
  - **Developer:** Claude, working through Roblox Studio MCP on the owner's Windows PC.
  - **Auditor:** independent. You have no access to Studio or the PC. The owner relays your verdicts, and Claude's work is reviewed only through this repo.
- **Loop:** each task ends with a package, a git push, and a ready-to-paste prompt for the auditor.
  - Then work stops for your verdict.
  - Real DataStore writes, live tests and publishes happen only after the owner explicitly approves the exact scope.
  - Your verdicts have shaped the scope of every step, and you have repeatedly required that claims be supported by hashes, diffs and logs.

## 2. Places, IDs and branches
| What | IDs | Notes |
|---|---|---|
| **Production: Lighthouse Keepers** | GameId **10769064643**, PlaceId **132065051336560** | Live, public game. Its DataStore holds real player saves, including the owner's `player_11752219158`. **Code = branch `main`.** |
| **Test experience: LK Multiship Test** | GameId **10771229467**. Harbor (start place) **125998212495899**, Lighthouse Isle **111423375237885** | Private, created by the owner on 2026-10-16. **Code = branch `multiship-test`.** Test store `LKMS_TEST_PlayerData_v1`, MemoryStore map `Voyages`. |
| SaveTest (earlier save-integrity tests) | GameId 10770892134, PlaceId 128620546156998 | **Frozen.** Do not touch. Its history is TASK-001…TASK-013 in `docs/audits/`. |
| Outlaw City (another game on the same PC), Deadzone | PlaceIds 132163592957463, 72812275891657 | **Unrelated games. Never touched, never included in packages.** |

**Branches:**
- `main` = production code. Latest commit 659dca8 contains the multi-ship foundation behind **disabled** flags.
- `multiship-test` = the test-experience build. It branches from `main` and adds a gate that is active **only** when `game.GameId == 10771229467`.
- `docs/batches/2026-10-16_multiship_test_env/TEST_BRANCH_VS_PRODUCTION.diff` shows the original test-only delta.

## 3. Standing rules (owner and auditor)
- **Publishing:**
  - Never publish, or create places, without the owner's explicit approval of the exact target. The owner publishes himself.
  - Verify the GameId and PlaceId of the Studio window before every Studio action.
- **Production saves:**
  - Never touch production saves, the save format, or the production DataStore from tests.
  - Never call `RemoveAsync` on real data.
  - No changes to economy, balance or persistence without approval.
- **Studio API access:** it must be **off** before any Studio Play.
  - In the production window, a probe is run before every Play.
  - Studio API access is turned on only for approved, read-only, Edit-mode checks, and off again afterwards.
- **Evidence:** back up the place and scripts before edits, and never claim success without evidence.
- **Out of scope:** SaveTest, Outlaw City and other windows are never touched.
- **Test experience:**
  - Only allow-listed UserIds may be written: `writableUserIds = {11752219158}`. Expanding the list needs owner approval.
  - No live voyages, teleports or publishes without the owner's approval of the exact scope.

## 4. Accepted history (`main`, production line)
| Commit | Batch | Package | Outcome |
|---|---|---|---|
| d8d8793 → 1781805 | Scripts, audits, gameplay batch 1 + per-ship roster | `docs/batches/2026-10-14_batch1/`, `2026-10-15_batch1r/` | Accepted |
| bc5ad13, 5de5724 | Boarding (walk aboard), 4/4 automatic departure, SAIL NOW for 1–3, BoardingZone | `2026-10-15_boarding/`, `2026-10-15_departure/BOARDING_REVISION_AUDITOR_PACKAGE.md` | Accepted after revisions |
| 305e5b2, 86db39f, f00ea66 | Departure fixes 1–2, final publication clearance | `2026-10-15_departure/FINAL_PUBLICATION_CLEARANCE.md` | **Cleared for the owner's manual publish** |
| 3b17aa8 | Multi-ship phase 1: crew-only messages, results and sounds | `2026-10-15_multiship/` | Accepted |
| ad3fe1e, da2b99f | Phase 2 foundation (place roles, Ship 2, IsleAdmission, Voyages, SessionLock), then fixes | `2026-10-15_multiship_phase2/`, `2026-10-16_multiship_phase2_fix/` | Accepted, flags off |
| 659dca8 | Safeguards: launch tickets, bounded save calls, InTransit watchdog | `2026-10-16_multiship_safeguards/MULTISHIP_NEXT_STAGE_PACKAGE.md` | Accepted, flags off |

**Production deployment:**
- The owner manually publishes production. The departure build was cleared at f00ea66.
- The later `main` commits are behind disabled flags and were not published in this workflow.
- **Ask the owner** which build is currently live before relying on it.

## 5. Accepted history (`multiship-test`, test experience)
| Commit | Step | Package | Outcome |
|---|---|---|---|
| 6e4d3c3, 7978ca7, 9f36035 | Test-universe gate, test-only PlayerData SessionLock adapter, attempt-specific voyage recovery, IDs set | `2026-10-16_multiship_test_env/MULTISHIP_TEST_ENV_PACKAGE.md` | Accepted |
| 6a11bce, 0116703, 7db1a73 | **Stage 1:** a real SessionLock test in Studio on `LKMS_TEST_PlayerData_v1 / player_11752219158` (claim, +25 Pearls, heartbeat, release, reload) | `STAGE1_PREFLIGHT.md`, `STAGE1_SESSIONLOCK_AUDITOR_PACKAGE.md` | **Accepted.** The synthetic 25-Pearl profile is preserved. Do not repeat. |
| 93021c7 | PlayerData race fixes A (late claim after leave) and B (mutation generation) | `STAGE1_PLAYERDATA_RACE_FIX_PACKAGE.md`, `PLAYERDATA_RACE_FIX.diff` | Accepted (15/15 fake-store tests) |
| 1b49741, bd4d2fc | Reclaim late-claim leak fix (19/19 tests; the old code was shown to leak); Stage 2 authorization package rev 2 | `PLAYERDATA_RECLAIM_FIX.diff`, `STAGE2_FIRST_VOYAGE_AUTHORIZATION_PACKAGE.md` | Accepted. The `_test` Studio-only guard was accepted by **source inspection only**. |
| eb96479, 0e7d198 | **Stage 2:** the first real voyage, Harbor → reserved Isle → Harbor, published privately | `STAGE2_FIRST_VOYAGE_EVIDENCE.md` | **Accepted**, with qualifications (section 7) |

## 6. Deployment state of the test experience (important)
- **Published to both test places** (Harbor 13:39Z, Isle 13:54Z, 2026-10-16):
  - Config `94ee135c13180be31544db75369b33cedefdb74b5e81303a1f747cb38a9d9651`, with `multiShip`, `sessionLock` and `teleport` = **true**;
  - `ISLE_STUDIO_TEST = false`, `PLACE_ROLE_OVERRIDE = nil`;
  - allowlist `{11752219158}`.
- At 0e7d198, git's Config had the switches **off** (`27661b7a…`). Your verdict: that config is **not safe to publish** over the locked test build, because it would put servers live that write the test store without the session lock.
- **From 763dc4d, git's Config again equals the deployed `94ee135c…`.**
- **Every future test publish** must verify all of these:
  - the exact GameId and PlaceId;
  - every script hash equals git;
  - the Config hash;
  - the role, with both overrides off.

## 7. Open qualifications and known gaps
1. Stage 2's intermediate session **releases were inferred** from the timing (60 s renewals, 120 s stale threshold), not captured individually. The ownership tokens, server JobIds and final release were observed.
2. **No non-zero Pearl change** has yet crossed servers. The run was lost on Night 1, so the award was 0. Run stats (`runs` 0 → 2, `bestNight` 0 → 1) did persist.
3. **Two simultaneous ships** have not been tested live. That needs a second Roblox account and approval to add it to the allowlist.
4. `PlayerData._test` being nil on live servers has been checked by reading the source only.
5. Teleport in a **Private** experience worked for the owner, but Roblox docs don't state it.

## 8. Pending now (awaiting your review and the owner's approval)
- **Commit 763dc4d.** Package: `docs/batches/2026-10-16_isle_arrival/ISLE_ARRIVAL_AND_RETURN_PACKAGE.md`; diff: `ISLE_ARRIVAL_AND_RETURN.diff`.
  - Isle arrival: travellers land by the lighthouse, with a "YOUR CREW IS LANDING n/m" card.
  - Returning voyagers skip the title, detected by `GetJoinData().SourcePlaceId` = the Isle place.
  - Git Config mirrors the deployed build.
  - Tests: 11/11 fake-data tests, plus Studio Play as Isle and as Harbor. **Not published.**
- **Proposed next live test, not approved:** publish this batch, then one voyage on `player_11752219158` that survives Night 1, for +1 Pearl. The expected Harbor balance is 26.
- **After that:** two ships and two reserved servers (plan in the same package, section 5).

## 9. Reading order for a new auditor
1. This file.
2. `docs/PROJECT_RULES_ADDENDUM.md`: owner and auditor rules, including project isolation.
3. `docs/progress.md` and `docs/IMPLEMENTATION_LOG.md`: project history and game systems.
4. `docs/batches/2026-10-15_multiship/HARBOR_ISLAND_SPLIT_PLAN.md`: why the Harbor and Isle are split.
5. `docs/batches/2026-10-16_multiship_safeguards/MULTISHIP_NEXT_STAGE_PACKAGE.md`: the production-side architecture, with flags off.
6. `docs/batches/2026-10-16_multiship_test_env/`, in this order:
   - `MULTISHIP_TEST_ENV_PACKAGE.md`
   - `STAGE1_SESSIONLOCK_AUDITOR_PACKAGE.md`
   - `STAGE1_PLAYERDATA_RACE_FIX_PACKAGE.md`
   - `STAGE2_FIRST_VOYAGE_AUTHORIZATION_PACKAGE.md`
   - `STAGE2_FIRST_VOYAGE_EVIDENCE.md`
7. `docs/batches/2026-10-16_isle_arrival/ISLE_ARRIVAL_AND_RETURN_PACKAGE.md`: **the batch awaiting review.**
8. Key code on `multiship-test`, under `src/ServerScriptService/Server/`:
   - `SessionLock.luau`
   - `PlayerData.luau`
   - `Voyages.luau`
   - `IsleAdmission.luau`
   - `HarborDepartures.luau`
   - `PlaceRole.luau`
   - `Main.server.luau`
   - also `src/ReplicatedStorage/Shared/Config.luau` (the `MULTISHIP_TEST` block).
9. Background only: `docs/audits/TASK-001…TASK-013`, the earlier SaveTest save-integrity work, which is closed.
