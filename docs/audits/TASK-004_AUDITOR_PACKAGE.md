# TASK-004 AUDITOR PACKAGE (combined plain-text version)

Architecture safety revision for Lighthouse Keepers (place 132065051336560). Design and verification only. NOTE: SOURCE_VERIFICATION_ADDENDUM.md carries a correction notice from TASK-007 about cancelled loads. No code, Config, price, save, DataStore or Studio content was changed by this task.

## TABLE OF CONTENTS
1. TASK-004/AUDITOR_REPORT.md
2. TASK-004/CHANGE_MANIFEST.md
3. TASK-004/TEST_EVIDENCE.md
4. TASK-004/AUDITOR_QUESTIONS.md
5. TASK-004/SOURCE_VERIFICATION_ADDENDUM.md
6. TASK-004/CORRIGENDUM_TASK-003.md
7. TASK-004/ARCHITECTURE_RECOMMENDATION.md
8. TASK-004/LIBRARY_SOURCE_FINDINGS.md
9. TASK-004/PERSISTENCE_COMPAT_AND_ROLLBACK.md
10. TASK-004/PEARL_PAYMENT_AND_IDEMPOTENCY.md
11. TASK-004/CREW_FUEL_VALIDATION_REVISION.md
12. TASK-004/TEST_ENVIRONMENT_PROPOSAL.md
13. TASK-004/REVISED_TEST_MATRIX.md
14. TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-004/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-004: Architecture safety revision

- **Date:** 2026-10-14
- **Project / place:** Lighthouse Keepers - Staging, place **132065051336560**, universe 10769064643, place version 148. Source examined: the TASK-001 export in `src\`. **No Studio instance was used or touched in this task.**
- **Original owner request (relayed auditor verdict on TASK-003):** reassess save architecture (library versus hardened custom lock, ten requirements), revise Pearl eligibility and idempotency, confirm crew cap and crew-only fuel with full test coverage, strengthen validation (BuyUpgrade, prompts), propose a safe separate persistence test environment (do not assume a local `.rbxl` is safe), and prepare the handoff. **No live-game edits, configuration changes, DataStore writes or publishing are authorized; stop after the revised design.**
- **Objective:** a design the auditor can approve or reject before any persistence code is written.

## Work completed
Research and documents only. The upstream ProfileStore repository, source and docs, and the Roblox DataStore, versioning, limits, server-update and ProximityPrompt pages were read on 2026-10-14. Findings and limits are in `LIBRARY_SOURCE_FINDINGS.md` and `TEST_EVIDENCE.md`. TASK-003 statements that were wrong or too strong are withdrawn in `CORRIGENDUM_TASK-003.md`.

## Update after D2 follow-up
The full source confirms the core conclusions and adds corrections A-J (for example: ordinary autosave failures are not retried until the next autosave period; the module performs a real write to a store named `____PS` when loaded in Studio with API access; `GetAsync` cannot read our v1 records). See `SOURCE_VERIFICATION_ADDENDUM.md`.

## Key findings
1. **ProfileStore cannot be pointed at the existing v1 store.** As read, it replaces any record that lacks its own wrapped structure with an empty profile. A separate `_v2` store plus our own one-time, read-only, idempotent import from v1 is therefore justified for the library path. An in-place migration is only possible for a custom lock.
2. **Recommendation changed:** use the maintained library on a new store (Apache-2.0, 32 commits, last commit 2025-07-31, so stable but thinly maintained) with the hardened custom lock as a documented fallback. Reason: the auditor's ten requirements describe a protocol that is hard to build and prove, and the library already implements most of it; the rollback advantage that favoured a custom lock in TASK-003 does not exist.
3. **No lossless rollback exists for either option.** Disabling the lock reintroduces SEC-1/SEC-2; with the library, progress after cutover lives only in v2 unless an approved export tool is run. The documented rollback posture is "treat cutover as one-way after a soak period; keep v1 frozen".
4. **Mixed old/new servers are the central deployment risk.** Roblox leaves old servers running after a publish and recommends restarting servers when data formats change. A custom lock offers no protection against old servers; the library path forks data. The mitigation is a maintenance cutover with a restart of outdated servers; residual risk from invite and teleport joins remains.
5. **Pearls:** a three-night minimum for the win bonus leaves a cliff that pays about twice per minute for a late join; a graded bonus `round(5 x credited / 13)` gives parity and still pays 18 for a full win. Durable idempotency is a `grants` map saved atomically with the Pearl balance and is authoritative over the in-memory ledger. No maximum loss on a crash is promised.
6. **Crew and fuel designs confirmed**, with added test rows for full crews, first-voyage joining, mid-run replacement and harbor spectators.
7. **Validation revised:** BuyUpgrade needs a server-recorded bench interaction, present-time proximity, phase and crew eligibility. For prompts, I could not find documentation that hold events fire on the server, so a per-player cooldown of 0.8 x HoldDuration (safe for honest players) is the design and server-side hold timing waits for test V0. No movement anti-cheat.
8. **Test environment:** a separate private test experience is proposed (owner-created, owner-published, with explicit wrong-target safeguards and gate test T0). A local `.rbxl` is never assumed DataStore-safe.

## Architecture / gameplay / security / save-data / performance implications
No change was made. If implemented as designed: a new store and importer, one new saved field (`grants`), per-night Pearl crediting with immediate saves, a cap on crew, and extra validation. Write load rises modestly (lock refresh or library autosave plus about 13 extra writes per player per run); to be measured in C14.

## Known limitations
- The first pass read the library through a summarizing fetch tool. **This was resolved for the source text by the D2 follow-up** (`SOURCE_VERIFICATION_ADDENDUM.md`: the pinned file was downloaded, hash-verified against GitHub's blob SHA, and read in full). The library's behaviour under our usage is still untested.
- DataStore semantic claims (transform re-runs, nil cancels) come from Roblox's pages and community summaries and are to be confirmed in tests C4/C5.
- Per-universe DataStore isolation is platform behaviour I relied on; gate T0 checks it.
- No test of any kind was run.

## Outstanding problems
All TASK-002 findings remain open. Open decisions D1-D13 are in `OWNER_DECISIONS_AND_SEQUENCING.md`.

## Ready for acceptance?
Yes as a design and verification milestone. No implementation is authorized.
=== END FILE ===

=== FILE: TASK-004/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-004

**No game script, Config value, price, save, Studio instance, DataStore or published content was changed.** No DataStore request of any kind was made. Studio was not used. In the first pass nothing was downloaded; in the follow-up under owner decision D2 (approved by the owner in chat on 2026-10-14) one file was downloaded, see below. Owner approval: not needed for documents and web research; D2 covered the download.

Files created in `C:\RobloxProjects\LighthouseKeepers\docs\audits\TASK-004\`:
| File | Purpose |
|---|---|
| `AUDITOR_REPORT.md`, `CHANGE_MANIFEST.md`, `TEST_EVIDENCE.md`, `AUDITOR_QUESTIONS.md` | Standard package |
| `ARCHITECTURE_RECOMMENDATION.md` | Revised recommendation, library versus custom comparison, hardened custom design answering the ten points |
| `LIBRARY_SOURCE_FINDINGS.md` | What was read from the ProfileStore repository and docs, and the limits of that reading |
| `PERSISTENCE_COMPAT_AND_ROLLBACK.md` | Migration feasibility, importer, mixed deployment, rollback, version history, failure states |
| `PEARL_PAYMENT_AND_IDEMPOTENCY.md` | Eligibility, win bonus evaluation, durable idempotency, run counting, scenarios |
| `CREW_FUEL_VALIDATION_REVISION.md` | Crew cap and fuel confirmation with tests, revised BuyUpgrade and prompt validation |
| `TEST_ENVIRONMENT_PROPOSAL.md` | Separate private test universe proposal, steps, isolation gate |
| `REVISED_TEST_MATRIX.md` | Environments and tests including real DataStore tests |
| `OWNER_DECISIONS_AND_SEQUENCING.md` | Decisions D1-D13, sequencing, remaining risks |
| `CORRIGENDUM_TASK-003.md` | TASK-003 statements withdrawn or corrected |

Added for the D2 follow-up: `SOURCE_VERIFICATION_ADDENDUM.md` (this folder) and one downloaded third-party file, `C:\RobloxProjects\LighthouseKeepers\vendor-review\ProfileStore_45c9847\ProfileStore.luau` (64,654 bytes, SHA-256 `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F`), kept outside `src\`, never executed, required or loaded, not installed in Studio, and **not** part of the audit package (the auditor receives only the addendum).

Existing files touched: a short "partly superseded by TASK-004" notice was added at the top of these TASK-003 files (content below the notice is unchanged), and `TASK-003_AUDITOR_PACKAGE.md` was rebuilt from them: `AUDITOR_REPORT.md`, `TEST_EVIDENCE.md`, `SAVE_ARCHITECTURE_AND_MIGRATION.md`, `PEARL_ELIGIBILITY_DESIGN.md`, `ISOLATED_TEST_PLAN.md`.

Source diffs: none (no code changed or written into `src\`).
=== END FILE ===

=== FILE: TASK-004/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-004

**Tests performed: none.** This task is research and design. No game code, Studio session, DataStore or published content was used. **No test could have changed production DataStore values: no DataStore request was made.** (Follow-up under owner decision D2: the pinned `ProfileStore.luau` was downloaded and read as text only; its hash and size checks are in `SOURCE_VERIFICATION_ADDENDUM.md`. It was never executed.)

## Research log (what was read, and how)
All on 2026-10-14, using a fetch tool that returns a model-written answer to a prompt about the page (not the raw bytes), and a web search tool.
| Source | What it was used for | Reliability note |
|---|---|---|
| github.com/MadStudioRoblox/ProfileStore (repo page) | description, license Apache-2.0, 32 commits, file list | page capture; commit/tag details came from the API below |
| api.github.com/repos/MadStudioRoblox/ProfileStore/commits | latest commit `45c9847c...` 2025-07-31, earlier commits | API JSON summarised by the tool |
| api.github.com/repos/MadStudioRoblox/ProfileStore | created 2024-10-09, pushed 2025-07-31, not archived, license `Apache-2.0` | the tool flagged an `updated_at` timestamp (2026-10-13) as odd; it is a metadata field and not a code change |
| raw.githubusercontent.com/.../ProfileStore.luau (two prompts) | record shape, session lock, constants, API names, legacy-record behaviour, Studio probe, shutdown | **second-hand**; quotes are what the tool reported as verbatim; the file was **not downloaded** and not read line by line |
| madstudioroblox.github.io/ProfileStore (docs) | API notes, "backwards compatible with ProfileService", no migration guidance, silent on `Cancel`/`OnSessionEnd`/mock | docs page is thin |
| create.roblox.com ... data-stores (overview) | Studio access off by default, setting path, warning that Studio uses the same data stores, recommendation of a separate test game; silent on local files and BindToClose | direct statements from the page |
| create.roblox.com ... error-codes-and-limits | request budgets (`60 + numPlayers x 40` read and standard write), per-key 4 MB/min write, 4,194,304-char value limit, throttle codes 301-306, 403 StudioAccessToApisNotAllowed | direct statements from the page |
| web search: UpdateAsync semantics | transform may re-run if another server wrote; runs until saved or returns nil; "non-yielding transform" is community advice, not a documented rule | secondary; to be confirmed by tests C4/C5 |
| web search: data store versioning | first write per key per UTC hour is kept as a backup; backups expire 30 days after being overwritten; newest never expires; `RemoveAsync` leaves older versions reachable | secondary summary of the docs page |
| web search: server updates | after publish old servers keep running; "Restart Servers" with "restart only outdated servers" and a 1-60 minute delay exist; Roblox suggests restarting servers when data format changes; invite/teleport joins can still reach old servers | secondary summary of the docs page and a forum thread |
| create.roblox.com ... ProximityPrompt reference | event list; page does not state the side events fire on or any server distance validation | direct reading; **gap, not a negative result** |

## Direct source reading in this repository (no execution)
`PlayerData.luau`, `Main.server.luau`, `GameState.luau`, `LampService.luau`, `IslandBuilder.luau`, `Config.luau` read in TASK-003/TASK-004; lines cited in the design files are from `src\` (place version 148).

## Tests not performed (all of them)
Everything in `REVISED_TEST_MATRIX.md`. Specifically unverified assumptions: transform re-run and nil-cancel behaviour (C4/C5), real shutdown timing (C7), the library's behaviour on our records (C9, C12), mixed-server forks (C10), per-universe store isolation (T0), prompt hold events on the server (V0).

## Remaining regression risk
None from this task (no change).
=== END FILE ===

=== FILE: TASK-004/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-004

1. **Library versus custom.** The recommendation is ProfileStore on a new `_v2` store with our own read-only importer, custom lock as fallback. Do you accept that, given the library was read second-hand and is thinly maintained (last commit 2025-07-31)? Which additional gate would you require before a vendored copy is trusted (full read at a pinned commit, a test suite from the repo's `ProfileStoreTest.server.luau`, our own C-tests)?
2. **Fence strength.** As read, the library fences on PlaceId, JobId and `SessionLoadCount`, not on the per-session GUID. Is that adequate for this game, or do you want a wrapper that adds its own per-load token?
3. **Cutover.** Is a maintenance restart of outdated servers sufficient, or do you want the optional pre-cutover fence (a marker key that evicts old servers) despite the extra release and one production write?
4. **Rollback posture.** Is "one-way after a soak, v1 frozen, forward-fix preferred, export v2 to v1 only with approval" acceptable, or do you require a built and tested export tool before cutover?
5. **Autosave interval.** The library default is 300 s. Is a shorter interval worth the extra writes given immediate saves after each Pearl credit?
6. **Pearl rule.** Graded win bonus `round(5 x credited / 13)` versus a fixed minimum (7 is the lowest value that removes the late-join advantage). Which do you endorse, and should the durable `grants` map be capped at 20 runs / 30 days?
7. **Prompt validation.** If test V0 shows hold events do not fire on the server, is a cooldown at 0.8 x HoldDuration plus phase/crew/distance checks acceptable, given no server-verifiable hold exists?
8. **Test universe.** Are the wrong-target safeguards (production window closed, explicit publish target, ID verification, gate T0) enough for the owner-run publish step?
9. **Early quitters.** Do you agree with counting a run only when the player is present at Results or leaves after at least one credited night?

No concern has been invented; items 1, 3, 4 and 6 are the substantive forks.
=== END FILE ===

=== FILE: TASK-004/SOURCE_VERIFICATION_ADDENDUM.md ===
> **CORRECTION (2026-10-14, TASK-007 mock tests):** two statements below about *cancelled* loads are too strong. A Cancel that is true from the start causes no write; the overwrite and the empty-record creation happen only when Cancel turns true after the load has started. See `docs/audits/TASK-007/CORRIGENDUM_D2_ADDENDUM.md`. The text below is otherwise unchanged.

# Source verification addendum (TASK-004, owner decision D2 only)

Date: 2026-10-14. Scope authorized by the owner: download only `ProfileStore.luau` at the pinned commit, verify it, read all of it without executing it, compare with `LIBRARY_SOURCE_FINDINGS.md`. Nothing was installed in Studio, `PlayerData` was not touched, no test experience was created, no DataStore request was made. Decisions D1 and D3-D13 remain pending.

## 1. Provenance and integrity
| Item | Value |
|---|---|
| URL | `https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/45c9847cbcf1fc260369c50eb335aba7c35aecdd/ProfileStore.luau` (HTTPS, HTTP 200, no redirect: effective URL identical) |
| Commit | `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, 2025-07-31, "Merge pull request #14 from RuizuKun-Dev/patch-1"; GitHub's API for this commit lists only `docs/tutorial/index.md` as changed, so the Lua file is unchanged by it |
| Local path | `C:\RobloxProjects\LighthouseKeepers\vendor-review\ProfileStore_45c9847\ProfileStore.luau` (new empty folder, one file, outside `src\`) |
| Size | 64,654 bytes (GitHub contents API for the same ref: size 64,654) |
| SHA-256 | `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F` |
| Git blob SHA-1 (computed locally) | `5b196af86a1eafa2ad5e94ef9398c483e87704ed`, **equal** to the blob SHA GitHub reports for that path at that commit |
| Length | 2,243 lines, read in full (lines 1-2243) |
| Handling | Never run, required or loaded. Only read as text. |
| License | the file carries no license header; the repository license is Apache-2.0 (earlier API check) |

## 2. Findings that the source confirms
1. **Legacy-record overwrite is real** (lines 531-576, 583-586, 1493-1505). A stored table that lacks `Data`, `MetaData` and `GlobalUpdates` (our flat v1 record has none of them) gets `missing_profile = true` and `overwritten = true`, is replaced by a fresh `{GlobalUpdates = ...}` plus template `Data`, and is written back by `UpdateAsync` (line 1625). The comment at line 583 reads "Invalid data handling (Silently override with empty profile)"; the library does emit a warning and fires `OnOverwrite` (lines 430-433, 637-641). **It happens even when the load is cancelled** because the overwrite flag does not depend on `Cancel`. Pointing it at `LighthouseKeepers_PlayerData_v1` would wipe each existing player on their first load.
2. **Record shape, constants and API** match `LIBRARY_SOURCE_FINDINGS.md` (header comment lines 1-168, saved structure 942-968, constants 170-181).
3. **Fence** is PlaceId + JobId (`IsThisSession`, line 659) plus `SessionLoadCount == profile.load_index` (lines 759 and 830). The GUID `unique_session_id` is stored as `ActiveSession[3]` and used only for the MessagingService topic `"PS_" .. id` (lines 1340, 1585). Stated correctly before.
4. **Saves are fenced**: the write transform edits `Data` only if this session still owns the profile (lines 751-810); a server that lost ownership notices on its next save, disconnects its subscription, removes the profile from autosave and fires `OnSessionEnd` (lines 911-921).
5. **Takeover**: dead-lock rule `os.time() - LastUpdate > ASSUME_DEAD (630)` (line 1472); otherwise a `ForceLoadSession` request plus a MessagingService "EndSession" message to the holder (lines 1583-1586); the holder saves and ends with reason "External" (lines 1343-1348, 843-847); the waiting server repeats every 10 s (first repeat 5 s) and **may steal only after 4 repeats (`ceil(40/10)`) and only if its force-load request is still the pending one** (lines 1573-1580, 1478-1483). A second contender that interrupts the first makes the first return nil (lines 1592-1596).
6. **Shutdown**: `BindToClose` sets `IsClosing`, releases every active profile in parallel with reason "Shutdown", and waits for all load/save jobs (lines 2208-2239). It has no deadline of its own, so Roblox's own shutdown limit is the only cap.
7. **Mock mode**: used when the Studio probe returns NoAccess, NoInternet or an error containing "403" or "must publish" (lines 2072-2111). `ProfileStore.Mock` gives an explicit user mock store.
8. **Keys and names**: key and store names must be at most 50 characters; `player_<UserId>` fits.

## 3. Inaccurate or incomplete assumptions in `LIBRARY_SOURCE_FINDINGS.md`
| # | Earlier statement | Correction from the source |
|---|---|---|
| A | "Save retries use exponential backoff" | Only **release** saves (EndSession, shutdown, external takeover) loop with backoff until they succeed (lines 735, 926-931; cap 20 s, 8 s on shutdown). An ordinary autosave that fails is **not retried until the next autosave** (line 738). Loss window for a failed autosave is therefore one autosave period unless `Profile:Save()` is called again. |
| B | "steal after 40 s" | After the first force-load request, 4 further repeats at 10 s, i.e. roughly 45 s, and only while our request is still current. |
| C | "`GetAsync` read-only view" is usable to read v1 | **No.** For a legacy record `GetAsync` returns a profile whose `Data` is the *template*, not the stored table (lines 1764-1775 and the shared transform). v1 must be read with a plain `DataStoreService` `GetAsync`, as the import design already says. |
| D | Studio probe described only as a probe | It performs a **real write**: `DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())` (line 2080) whenever the module loads in Studio. In a Studio session with API access on the production experience this writes a junk key (store `____PS`) to production. Another reason to keep the library out of the production place until the test universe exists and API access on production is off. |
| E | (not mentioned) | The module opens its store with `DataStoreOptions:SetExperimentalFeatures({v2 = true})` (lines 1305-1306). Roblox's reference page for that method says it currently has no effect and lists no `v2` feature (web search 2026-10-14). Low risk today, but it ties the library to an undocumented switch. |
| F | (not mentioned) | `Cancel` and `Steal` callbacks run **inside** the DataStore transform (lines 1458, 1495, 1509), so a `Cancel` function must be fast, pure and non-yielding (for example `player.Parent ~= Players`). |
| G | (not mentioned) | Calling `StartSessionAsync` for a key already active on this server throws (line 1391). The adapter must always call `EndSession` when a player leaves. A rapid rejoin on the same server is handled specially: the earlier pending load returns nil (lines 1421-1445). |
| H | (not mentioned) | `Profile.OnSessionEnd` fires **before** the final write when `EndSession` is called (lines 716-726), so it means "session over", not "saved". |
| I | (not mentioned) | A cancelled load for a brand-new player can still create an empty record with no active session (lines 1493-1505). Harmless but not a no-op. |
| J | "autosave spread" | Every autosave writes the whole `Data` and refreshes `LastUpdate` (lines 797, 2149), changed or not. This doubles as the liveness heartbeat for `ASSUME_DEAD`, but means constant write traffic of one `UpdateAsync` per player per autosave period. |

## 4. New risks and decisions this raises
1. **Studio and `____PS` write** (D above): the library must not run in the production place's Studio with API access enabled. Reinforces D3 and D4.
2. **Autosave failure window** (A above): choose `AUTO_SAVE_PERIOD` and call `Profile:Save()` after each Pearl credit and purchase so a failed autosave does not hide recent changes; the retry-until-success behavior exists only on release.
3. **`game.JobId` in Studio**: the fence uses `game.JobId`; I believe it is an empty string in Studio test sessions, which would make two Studio sessions look like the same server. This is an inference, not in the source; real concurrency tests must therefore use published servers (already the plan for the test universe).
4. **No version number in the file**: pin by commit and hash, which this addendum records.
5. **No internal shutdown deadline**: release saves loop until success, so a DataStore outage at shutdown is bounded only by Roblox's own limit.
6. The file is 2,243 lines of third-party code; it was read once by me and not independently reviewed. A second reviewer on the security-sensitive parts (lines 521-650, 709-938, 1364-1631, 2208-2239) is advisable before production use.

## 5. Conclusion
The central TASK-004 conclusions are unchanged and now firmly source-based: **the library cannot be used on the v1 store; a separate v2 store with our own import is required; session fencing and graceful takeover are real; rollback has no lossless form.** Corrections A-J should be folded into the design (autosave and `Save()` policy, Studio probe write, Cancel purity, EndSession discipline). No implementation is authorized and I have stopped.
=== END FILE ===

=== FILE: TASK-004/CORRIGENDUM_TASK-003.md ===
# Corrigendum: statements in TASK-003 that are withdrawn or corrected (TASK-004)

| # | TASK-003 statement (file) | Problem | Correction |
|---|---|---|---|
| 1 | "A file opened from disk is not tied to the published universe, so its `game.GameId` should be 0 and DataStores are unavailable (expected)"; E1 listed as "DataStore exposure: none" (`ISOLATED_TEST_PLAN.md`, `TEST_EVIDENCE.md`) | The only evidence is that the backup copy reported `PlaceId 0` and `GameId 0`. Roblox's pages that I read do not say a local file cannot reach data stores, and they warn that Studio uses the live data stores once API access is enabled. | **Withdrawn.** A local `.rbxl` is treated as "unknown" and is never relied on for DataStore safety. Persistence tests move to a separate private test universe. |
| 2 | "Rollback is a code revert with no data conversion", "lossless rollback", "Never restore a backup over saves" as the whole rollback story (`SAVE_ARCHITECTURE_AND_MIGRATION.md`) | Disabling the lock returns to blind overwrites, so SEC-1 and SEC-2 come back; with the library path, later progress lives only in v2. | **Withdrawn.** See `PERSISTENCE_COMPAT_AND_ROLLBACK.md` section 4: no lossless race-free rollback exists. |
| 3 | "at worst one night" of loss after a crash (`PEARL_ELIGIBILITY_DESIGN.md` section 4) | Not guaranteed by any mechanism in the design. | **Withdrawn.** No maximum loss is promised (`PEARL_PAYMENT_AND_IDEMPOTENCY.md` section 4). |
| 4 | Option B (custom in-place lock) recommended; TTL 150 s, token = `jobId`, fence by `jobId` (`SAVE_ARCHITECTURE_AND_MIGRATION.md`) | `jobId` is not a per-load identity, no fencing on every write, no handling of ambiguous commits, single-flight saves or old/new mixed servers. | **Superseded** by `ARCHITECTURE_RECOMMENDATION.md`: library on a new store recommended; the custom design is rewritten against the auditor's ten points as the fallback. |
| 5 | Option A (library) described from memory with a new `_v2` store "as the fallback" | Written without reading the source. The real behaviour is stronger: the library overwrites a non-conforming record with an empty profile, so it can never be pointed at v1. | **Corrected** in `LIBRARY_SOURCE_FINDINGS.md` (still a second-hand reading; see the limits there). |
| 6 | Win bonus "minimum 3 credited nights" | Leaves a cliff that pays about twice per minute for a late join. | **Revised** to a graded bonus, with the fixed minimum kept as an alternative (`PEARL_PAYMENT_AND_IDEMPOTENCY.md` section 3). |
| 7 | "In-memory keys are enough" for duplicate-payout protection | A reload after a failed save can be older than the in-memory ledger. | **Revised:** durable `grants` in the profile are authoritative; the in-memory ledger is only an optimisation. |

TASK-003 is otherwise accepted by the auditor as a design milestone. Its own files carry a "partly superseded" note pointing here.
=== END FILE ===

=== FILE: TASK-004/ARCHITECTURE_RECOMMENDATION.md ===
# Revised save architecture recommendation (TASK-004) — design and verification only

Supersedes the recommendation in `TASK-003/SAVE_ARCHITECTURE_AND_MIGRATION.md`. Nothing has been implemented.

## 1. Recommendation
**Adopt an established, maintained library (ProfileStore) against a NEW DataStore (`..._v2`), with a one-time, read-only, idempotent import from v1 during first load. Keep the hardened custom design below as the fallback only if the library fails a gate.**

Why the answer changed from TASK-003:
1. The auditor's ten requirements for a custom lock (section 3) describe a protocol that is easy to get subtly wrong (fencing across retries, ambiguous write errors, graceful takeover, coalesced saves, shutdown). A widely used library already implements most of them and has had far more real traffic than anything we write and test in one project.
2. The library cannot be pointed at v1 (it overwrites unrecognised records with an empty profile; see `LIBRARY_SOURCE_FINDINGS.md`), so a separate store is *required*, which is exactly the case where the library's shape difference stops mattering: the one-time import is our only custom persistence code.
3. TASK-003 recommended an in-place lock partly because rollback looked "lossless". That claim is withdrawn (see `PERSISTENCE_COMPAT_AND_ROLLBACK.md`): neither option has a lossless rollback, so rollback ease no longer favours the custom lock.

Gates before the library is accepted (any failure triggers the fallback): (a) the exact file at a pinned commit is downloaded into its own folder, read in full and diffed against what is described here (owner approval for the download); (b) tests C1-C14 pass in the separate test universe; (c) the import and mixed-deployment plan passes tests C9 and C10; (d) the owner and auditor accept the residual risks listed in `OWNER_DECISIONS_AND_SEQUENCING.md`.

## 2. Library versus custom lock (summary)
| Criterion | ProfileStore + new v2 store | Hardened custom lock in v1 record |
|---|---|---|
| Session ownership token | session identity plus load count; GUID stored but not used in the fence | per-load GUID plus epoch (designed below) |
| Fencing on every write | yes, inside the write transform | designed, must be built and proven |
| Live-holder takeover | MessagingService request to the holder to save and release, steal after 40 s, 630 s for dead servers | to build (timestamps only, or add MessagingService) |
| Retries / repeated transform | built in with backoff; transform logic is the library's | our transform must be pure and idempotent |
| Coalesced saves, shutdown | built in (parallel release at close) | to build |
| Existing v1 data | **separate store plus our importer**; in-place impossible without wiping | in place, additive fields, but old servers ignore locks |
| Mixed old/new servers | old servers write v1, new servers use v2: **fork risk** unless old servers are shut down first | old servers overwrite blindly and are unprotected; fencing only detects some cases |
| Rollback | v1 frozen at cutover; later progress exists only in v2 unless exported back | record stays valid for old code, but old code re-exposes SEC-1/SEC-2 |
| New code to write and test | thin adapter, importer | the whole protocol |
| Third-party risk | vendored Apache-2.0 file, thinly maintained (last commit 2025-07-31) | none |

## 3. The hardened custom design (fallback), answering the auditor's ten points
Record layout stays flat (v1 fields unchanged) with additive fields: `_owner = { token, jobId, placeId, acquiredAt, heartbeatAt }`, `_epoch` (integer, incremented only when ownership changes hands), `_seq` (integer, incremented on every committed write), `_saveId` (GUID of the last committed write).

1. **Unique per-load token.** At each load, generate `token = GenerateGUID()`; it is the identity of that load of that player on that server, not the server. `jobId` is stored only for diagnostics (it repeats for every load on a server and in Studio can be empty).
2. **Strict ownership and fencing on every write.** A write transform accepts only if the stored `_owner.token` equals mine **and** the stored `_epoch` equals the epoch I acquired. Anything else returns nil (cancel) and flags the session lost. There is no unconditional save path: leave, autosave, shutdown and heartbeat all use the same fenced transform.
3. **Expiry and takeover when the holder is alive.** A contender may take over only when `now - heartbeatAt > TTL`, comparing `os.time()` values from different servers (small clock skew is possible, so TTL must be far larger than skew; proposed 5 minutes with 60 s heartbeats). A holder that is merely slow (throttled DataStore, long pause) can still be alive when taken over. That is safe only because of rule 2: its next write fails the fence, it marks the session lost, stops writing and removes the player; progress it held in memory since its last committed write is lost, and this is the cost of takeover. To reduce that loss, add a MessagingService "please save and release" request first (as the library does) and use timeout takeover only after it goes unanswered.
4. **Retries and repeated callbacks.** The transform is pure: it reads only `old` and a **snapshot taken before the call** (deep copy plus its `_seq`), and returns a new table. It runs any number of times. Ambiguous failures (error after the server committed) are resolved by reading the key back and comparing `_saveId` to the one attempted; if it matches, the save succeeded. Success is judged from the returned record, never from a flag mutated inside the callback.
5. **No in-flight overwrite of newer changes.** One in-flight save per player (single-flight). A change during a save sets `needsSave`; when the flight lands, a new snapshot is taken and saved. Dirty tracking is by sequence number (`changeSeq` versus `savedSeq`), not a boolean.
6. **Consistency of data, revision and lock.** All of data, `_owner`, `_epoch`, `_seq`, `_saveId` are written in one `UpdateAsync` of one key, so they are committed atomically.
7. **PlayerRemoving, autosave and BindToClose together.** Per-player state machine `Loading -> Active -> Releasing -> Released`, one coalescing `requestSave(player, reason)`. PlayerRemoving moves to `Releasing`; autosave skips non-Active; BindToClose waits for all `Releasing` plus saves in parallel and never starts a second release for a player already releasing. A final save is attempted up to three times with backoff, then logged and held in a short retry table.
8. **Compatibility with v1.** Additive fields only; `reconcile` ignores unknown keys; `version` untouched.
9. **Mixed old/new servers.** Old servers ignore tokens and write the whole table blindly. The custom lock gives **no protection against them**. It only lets new servers *detect* some stale overwrites after the fact (token or epoch mismatch) and fail closed. Therefore the rollout requires restarting all outdated servers before enabling locking (see section 5 of the rollback document).
10. **Genuine rollback.** There is none that is lossless and race-free: disabling the lock returns to blind overwrites (the SEC-1 and SEC-2 behaviour) and in-flight stale writes can then destroy newer data. The honest rollback is (a) shut down all servers, (b) republish the previous build, and (c) accept that it carries today's known risks; progress made under the lock stays valid because the record is a superset.

## 4. What stays the same in either option
- All gameplay code keeps using `PlayerData` functions; only `PlayerData`'s load, save and release internals change.
- `doNotSave` for failed loads is retained and honoured inside the save function itself.
- A player whose session cannot be acquired is kicked with a clear message; playing in memory is not allowed because it silently discards progress.
=== END FILE ===

=== FILE: TASK-004/LIBRARY_SOURCE_FINDINGS.md ===
> **UPDATE (2026-10-14): the file was later downloaded and read in full under owner decision D2; see `SOURCE_VERIFICATION_ADDENDUM.md`. It confirms the central findings and corrects items A-J there (notably: only release saves retry; the Studio probe performs a real write; `GetAsync` cannot read v1).**

# ProfileStore: what was actually read (TASK-004)

## How this was read, and the limits
- Source: the public repository `https://github.com/MadStudioRoblox/ProfileStore` (file `ProfileStore.luau`, `README.md`, the docs site `https://madstudioroblox.github.io/ProfileStore/`) and the GitHub REST API for commit and license metadata, read on 2026-10-14.
- The pages were read through a fetch tool that returns a model-written answer to a question, not the raw file. Short quotations below are what that tool reported as verbatim; **I did not download the file or read it line by line**. Two separate questions about the legacy-record behaviour gave consistent answers, but this is still second-hand reading. **Before any adoption, the exact file at a pinned commit must be downloaded into its own empty folder (owner approval required for the download) and read in full.** Nothing was downloaded or executed in this task.

## Identity, version, license, maintenance
| Item | Finding |
|---|---|
| Name | ProfileStore (by loleris / MadStudio), successor to ProfileService |
| Latest commit seen | `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, 2025-07-31 ("Merge pull request #14 from RuizuKun-Dev/patch-1") |
| Previous commits | 2025-06-18 type fix; 2025-03-29 docs/CI; 2025-03-25 "Blocking prevention for MessagingService"; 2025-02-15 link fixes |
| Repo created | 2024-10-09; 32 commits on `main`; not archived |
| Releases/tags | none shown; the source file carries no version number or license header |
| License | Apache-2.0 (repository LICENSE; GitHub API `spdx_id`). Apache-2.0 requires keeping the license and notices if the file is vendored |
| Popularity | about 344 stars, 66 forks (page capture) |
| Maintenance reading | actively built through 2025, **no commit for about 14.5 months as of 2026-10-14**. That is low activity, not abandonment; the code is small and single-purpose. Treat it as "stable, thinly maintained" and pin a commit |
| Delivery | single ModuleScript; Wally manifest present |

## Stored record shape (important)
Each key holds a **wrapped** table: `Data`, `MetaData`, `RobloxMetaData`, `UserIds`, `GlobalUpdates`. `MetaData` holds `ProfileCreateTime`, `SessionLoadCount`, `ActiveSession = {PlaceId, JobId, unique_session_id}`, `ForceLoadSession`, `LastUpdate`, `MetaTags`. Our v1 record is a flat table (`pearls`, `owned`, `counts`, ...), so the two are different shapes.

## What it does with an existing record that is not in its shape (the critical finding)
The load transform checks for `Data`, `MetaData` and `GlobalUpdates`. When they are missing it sets `missing_profile = true` and `overwritten = true`, with the comment reported as `-- Invalid data handling (Silently override with empty profile)`, and replaces the value with a fresh profile built from the template. The original raw fields are discarded in that write. A warning and an `OnOverwrite` signal fire; read-only `GetAsync` does not write.
**Consequence: pointing ProfileStore at the existing v1 store name would, on the first session start for each existing player, replace that player's record with an empty template profile.** That would destroy player progress. This is stronger than what TASK-003 said and rules out an in-place adoption of the library on `LighthouseKeepers_PlayerData_v1`. (Verification in a safe place is test C12 in `REVISED_TEST_MATRIX.md`; it must never be run in production.)

## Session lock, fencing and takeover as read
- Acquire: when there is no active session it writes `ActiveSession = {PlaceId, JobId, unique_session_id}`.
- Dead lock: reported check `if os.time() - last_update > ASSUME_DEAD then`, `ASSUME_DEAD = 630` s, then the session is taken.
- Live holder: the requester writes `ForceLoadSession` and publishes a MessagingService message; the holder saves, ends its session with reason "External" and releases. The requester retries at 5 s then every 10 s; after `SESSION_STEAL` (40 s) of unsuccessful attempts it takes the session by force (`Steal = true` takes it immediately).
- Fencing on write: ownership is checked inside the write transform with `IsThisSession` (reported as `return session_tag[1] == PlaceId and session_tag[2] == JobId`) plus `SessionLoadCount` equality. **It does not compare the per-session unique GUID**, so the fence is PlaceId + JobId + load count. A server that lost its session sees the stored session differ on its next save, stops saving, and fires `OnSessionEnd` (no reason).
- `Cancel`: a function polled during the load loop; returning true makes `StartSessionAsync` return nil without claiming the session. The documented intent is to abandon a load when the player has left.

## Saving behaviour as read
- Auto-save default 300 s, spread across loaded profiles; the docs say it was raised from 30 s. `ProfileStore.SetConstant(name, value)` exists, so the interval can be changed (value to be chosen against the DataStore budget). `Profile:Save()` triggers an extra save.
- Save retries use exponential backoff capped at 20 s (8 s during shutdown). Five errors within 120 s mark a "critical state".
- Shutdown (`BindToClose`) releases every active profile in parallel and waits for pending jobs.
- In Studio the module probes the store with a test write to a store named `____PS` (reported `DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())`); when access is denied it uses an in-memory mock. **When Studio has API access it uses the real DataStore, so a Studio test of ProfileStore on the production place would perform real writes. That is the same exposure the project already has today and is why the persistence tests must live in a separate universe.**

## Public API names read
`ProfileStore.New(store_name, template?)`, `ProfileStore.SetConstant`, `:StartSessionAsync(key, {Steal?, Cancel?})`, `:MessageAsync`, `:GetAsync(key, version?)` (read-only view, no session), `:VersionQuery`, `:RemoveAsync`; profile methods `IsActive`, `Reconcile`, `EndSession`, `AddUserId`, `RemoveUserId`, `MessageHandler`, `Save`; events `OnSave`, `OnLastSave`, `OnAfterSave`, `OnSessionEnd`.
The docs page says its profiles are backwards compatible with ProfileService, and that using `MessageAsync` can make ProfileService have trouble loading them again. The docs recommend trying it in Studio with API access before migrating a live game. It says nothing about migrating arbitrary raw DataStore data.

## What I could not establish
- The exact current text of the file (see limits above).
- Whether `Profile.Data` hooks exist for importing a legacy record at first load (none are documented; an importer would be our own code run immediately after `StartSessionAsync`).
- Runtime behaviour under our usage, which only the test universe can show.
=== END FILE ===

=== FILE: TASK-004/PERSISTENCE_COMPAT_AND_ROLLBACK.md ===
# Persistence compatibility, migration and rollback analysis (TASK-004) — design only

No production data was read or written for this analysis, and no DataStore request of any kind was made.

## 1. Is an in-place migration possible?
- **Custom lock:** yes. The v1 record stays flat and gains additive fields (`_owner`, `_epoch`, `_seq`, `_saveId`). Old code ignores unknown keys and writes them back unchanged, as the `equippedBeam` field showed on Oct 12.
- **ProfileStore:** **no, not safely.** The library treats any record without its `Data`/`MetaData`/`GlobalUpdates` structure as invalid and overwrites it with an empty profile (`LIBRARY_SOURCE_FINDINGS.md`). The only "in-place" route would be to rewrite every existing record into the library's wrapper format ourselves, which is a mass production write that reproduces the library's internal record shape and would break if the library changed it. Not recommended. **A separate DataStore (`LighthouseKeepers_PlayerData_v2`) is justified for the library path.**

## 2. Import design for the separate-store path (library)
1. `StartSessionAsync` on the v2 key (with a `Cancel` that returns true if the player has left). If it returns nil, kick with a retry message.
2. If `profile.Data.importState ~= "done"`: read v1 with a plain `GetAsync` on the v1 key (read-only, up to 3 tries with backoff). Cases:
   - v1 value is nil: a genuinely new player; keep template defaults; set `importState = "done"`.
   - v1 value is a table: run today's `reconcile` on a copy, copy the fields into `profile.Data`, set `importState = "done"` and `importedFrom = { schema = 1, at = os.time() }`.
   - v1 read fails: **do not play and do not mark done.** End the session and kick with a retry message. A blank v2 profile must never be treated as a new player.
3. Save immediately after the import so v2 holds it.
4. v1 is never written by new code. Re-running the importer is harmless because the flag lives inside the same atomic profile record.
5. The import is the only custom persistence code on this path and is covered by tests C9 and C10.

## 3. Mixed old/new deployment (the central risk)
Roblox's documentation says that after a publish the existing servers are left running until they empty, and recommends restarting servers when player data format changes; players can still reach old servers through invites or teleports during a restart delay (sources in `TEST_EVIDENCE.md`).
- **Library path:** an old server keeps writing v1 while a new server imports from v1 and then uses only v2. A player can load a stale v1 on a new server, or play on an old server after import. Progress made on the old server after the import is **lost** (a fork), because v2 never reads v1 again.
- **Custom path:** an old server writes the whole table blindly and ignores locks, so a new server's progress can be silently overwritten by it. Fencing only detects this after the fact.
- **Mitigation, both paths:** a planned maintenance cutover. (1) Announce; (2) publish the new build; (3) in Creator Hub use the server-restart option for outdated servers with a short delay so old servers shut down; (4) watch the server list until none is outdated; (5) only then treat the cutover as complete. Residual risk: invite and teleport joins landing on an old server during the delay window.
- **Optional extra fence (adds a step, owner decision):** release a small "pre-cutover" build first that polls a marker key in the v1 store and evicts players once it appears. At cutover the owner approves one marker write, and old servers eject themselves within the polling interval. This costs an extra release and one production write, and only protects servers that already run the pre-cutover build.

## 4. Rollback: what is and is not true
There is no lossless, race-free rollback for either option. Stated plainly:
- **Disabling session locking reintroduces SEC-1 and SEC-2.** With the lock off, saves are blind overwrites again, so concurrent or stale writes can destroy newer progress. The existing record stays *readable*, but "no data conversion needed" is not "no corruption".
- **Library path rollback:** reverting to the v1 build makes players load their frozen v1 records, so **all progress made on v2 since the cutover is invisible** until restored. Options: (a) accept the loss; (b) forward-fix instead of rolling back; (c) a maintenance-window **export v2 -> v1** tool that reads v2 (read-only `GetAsync` view) and writes flat v1 records for players whose v2 record is newer. Option (c) is a production write that needs explicit approval, would itself be a custom persistence tool needing tests C-series coverage, and must run only with all servers shut down.
- **Custom path rollback:** shut down all servers, republish the previous build, accept today's known risks. Data written under the lock remains valid because the record is a superset.
- **Recommended rollback posture:** treat the cutover as one-way after the soak period, prefer a forward fix, and keep v1 frozen and untouched as the safety copy. Define the soak period and the abort criteria before cutover (see decisions).

## 5. What history exists for recovery
Roblox DataStores keep versioned backups: the first write to a key in each UTC hour is kept, later writes in the same hour overwrite it, and a backup expires 30 days after it is overwritten; the newest version never expires; `RemoveAsync` leaves older versions reachable (source and limits in `TEST_EVIDENCE.md`). Practical meaning: **there is at most hourly granularity**, so autosaves every minute leave no fine-grained history, and recovery after 30 days is not possible. The frozen v1 store is the stronger safety copy for the library path.

## 6. Failure states to design for (both paths)
| State | Required behaviour |
|---|---|
| Lock/session cannot be acquired within the wait | kick with a plain message; never load a copy; never play in memory |
| Load or import read fails | no play, no write, retry message |
| Session lost mid-play (taken over) | stop writing, tell the player, remove them; log |
| Save fails repeatedly | keep retrying with backoff, hold the snapshot, surface a warning, release only on success; at shutdown give up after the deadline and log |
| Store unavailable at boot | re-probe with backoff instead of disabling saves for the server's lifetime |
| Corrupt/unknown record shape | refuse to overwrite; log; fail closed |

## 7. Compatibility checks required before any cutover
- v1 record fixtures: empty, missing `equippedBeam`, extra unknown fields, wrong types, very large `counts`.
- A v2 record is never read by the old build (the old build only knows v1), so no old-build compatibility check against v2 is needed.
- The v1 store remains byte-for-byte unchanged by the new build (verified by version history comparison in the test universe).
=== END FILE ===

=== FILE: TASK-004/PEARL_PAYMENT_AND_IDEMPOTENCY.md ===
# Pearl payment, eligibility and idempotency (revision of TASK-003) — design only

Changes rewards and adds a saved field, so owner approval is required before any implementation. Nothing is built or run. Figures come from Config constants and the code's own formulas: `DAY_SECONDS = 30`, `NIGHT_SECONDS = 90` (so one night plus its day is 120 s), `NIGHTS_TO_WIN = 13`, `PEARLS_PER_NIGHT = 1`, `PEARLS_VICTORY_BONUS = 5`.

## 1. Principle (kept)
One Pearl per completed night for each player who was eligible for that night. Total for a full-participation win stays 13 + 5 = 18; a defeat during night N pays N - 1 (as today's `nightReached - 1`).

## 2. Precise eligibility
- **Night start `T_n`** is the instant the phase becomes `Night` for night `n`. The prologue is not a night and pays nothing.
- **Roster `E_n`** is frozen at `T_n`: players with `Ready == true`, still connected, on the crew (at most 4 by the crew cap).
- **Join time.** Joining the crew during the prologue or during Day `n` (before `T_n`) makes a player eligible for night `n`. Joining at or after `T_n` makes them eligible from night `n + 1`. Joining during Victory, Defeat, Abandoned or Results makes them eligible for nothing in that run; they are queued for the next run.
- **Credit at dawn `n`** goes to each player in `E_n` who is still connected and was **connected continuously** from `T_n` to dawn. A player who leaves and rejoins during the same night does not earn that night. Dying and respawning does not matter.
- **Defeat during night `n`:** night `n` is not credited (it was not survived).
- **Victory bonus:** see section 3.
- **Mid-run replacement:** a friend who takes a vacated slot earns normally from the next night start.
- **Failed-load profile** (`doNotSave`): the player may play; credits are held in memory only and lost on leave, and the player is told (GP-27 fix).

## 3. The win bonus: is a three-night minimum right?
Time per night is 120 s, so late-joining rates compared with a full run (18 Pearls over about 26 minutes plus up to 90 s of prologue, about 0.65 Pearls per minute):
| Rule | Joins for nights 11-13 (about 6 min) | Rate | Joins for nights 7-13 (about 14 min) | Rate |
|---|---|---|---|---|
| Bonus needs 3 credited nights (TASK-003) | 3 + 5 = 8 | about 1.33 per minute, **about 2x a full run** | 7 + 5 = 12 | about 0.86 per minute |
| Bonus needs 7 credited nights | 3 + 0 = 3 | 0.5 per minute | 7 + 5 = 12 | 0.86 per minute |
| **Graded bonus** `round(5 x credited / 13)` | 3 + 1 = 4 | **about 0.67 per minute (parity)** | 7 + 3 = 10 | about 0.71 per minute |
**Assessment:** a fixed three-night minimum leaves a cliff that makes a late join about twice as productive per minute as a full run, which is exactly the farming incentive we are trying to remove. **Recommended: the graded bonus**, which has no cliff, rewards each night equally, still pays 18 for a full run, and needs no tuning of a minimum. A fixed minimum remains available as a simpler alternative (owner decision), with 7 as the lowest value that removes the late-join advantage.

## 4. Idempotency: in-memory versus durable
- **In-memory ledger (per run, per server):** key `runId:userId:night` (and `...:bonus`). It stops the same event firing twice inside one run, and it holds the roster logic. It is lost if the server dies, and it can be *ahead of* the saved profile.
- **Durable record (authoritative):** new saved field `grants = { [runId] = { nights = <count or bitmask of credited nights>, bonus = true/false, at = os.time() } }`, kept only for the last 20 runs or 30 days (pruned at write). `runId` is a GUID created when the run starts. The Pearl balance and the grant marker are changed in the same in-memory profile and are committed by the same atomic save, so they cannot disagree after a crash: either both are saved or neither.
- **The credit function** checks the **profile's** `grants`, not the in-memory ledger, before adding Pearls. Consequence for the awkward case "leave-save failed, the player rejoins the same server later in the same run": the reloaded profile is older than the ledger, so its `grants` lack the unsaved nights, and the function re-grants exactly those nights. Nothing is duplicated and nothing is lost.
- **What durability does not give:** if the server crashes before a save lands, that credit is gone. Nothing in this design bounds that loss to one night. The practical mitigation is an immediate coalesced save after each credit (13 extra writes per player per run; trivial against the budget of `60 + numPlayers x 40` writes per minute per server), which usually leaves a window of seconds, but a DataStore outage or throttling can make it longer. **I make no guarantee of a maximum loss.**
- **Cross-server duplicates** cannot occur because a run lives on one server and the session lock/fence (see `ARCHITECTURE_RECOMMENDATION.md`) allows only one writer of a profile.

## 5. Retries, crashes, disconnects, rejoin, shutdown
| Event | Result |
|---|---|
| Save request fails or is ambiguous | the same snapshot is retried; read-back by `saveId` decides success; no increment is replayed because the Pearl delta is part of the snapshot |
| Server crash | credits since the last successful save are lost (unbounded by design, typically seconds to one night) |
| Player disconnects | credits so far are in the profile; the leave-save retries 3 times with backoff then holds the snapshot for a short period; if every attempt fails the credits are lost and logged |
| Rejoin, same server, same run | profile reload plus `grants` check re-grants only missing nights; earns again from the next night start |
| Rejoin on another server | that run's credits exist only in the saved profile; a new run starts fresh |
| Server shutdown (30 s window) | all players saved in parallel; anything unsaved when time runs out is lost |
| Abandoned (everyone left) | nights already credited stay; no bonus |
| Session taken over while the run continues elsewhere | the old server's writes fail the fence and its credits are refused; the profile belongs to the new server |

## 6. Early quitters and the completed-run count
`stats.runs` is also the onboarding switch: a profile with 0 runs gets the first-voyage fast path (no title) and the coach (`Main.server.luau` `chooseRoute`, `Client.Coach`).
| Rule | Effect |
|---|---|
| **Count a run when the player is present at Results, or leaves after at least one credited night (recommended)** | a prologue quitter stays "new": next time they get the fast path and coach again; someone who survived a night counts as returning |
| Count every started run | a player who bounces in 20 s never sees the coach properly; slightly better "returning player" accuracy; the first-timer's best chance of onboarding is spent |
| Count only completed runs (win or defeat at results) | leavers never leave "new" status until they finish one; stats stay clean, but repeated early quitters see the coach every time |
Implications: telemetry (run counts, rematch rate) shifts depending on the rule, so the choice should be fixed before playtests. `bestNight` for a leaver is the last credited night.

## 7. Revised scenario table (graded bonus; nothing run)
| Scenario | Pearls |
|---|---|
| Full 13-night win | 13 + 5 = 18 |
| Defeat during night 5 | 4 |
| Joins during Day 11, win | 3 + round(5 x 3 / 13 = 1.15) = 4 |
| Joins during Day 7, win | 7 + round(2.69) = 10 |
| Joins during Day 13, win | 1 + round(0.38) = 1 |
| Joins during Night 13 | 0 (eligible from the next run) |
| Leaves after night 9 | 9 (no bonus) |
| Disconnects during night 9 | 8 |
| Leaves during night 9, rejoins during the same night, win | credited 1-8 and 10-13 = 12, bonus round(4.62) = 5, total 17 |
| Joins during Results | 0 |
| Same grant key submitted twice | second is a no-op |
| Leave-save failed, rejoin same server | missing nights re-granted once |
Under the fixed three-night rule instead: joins during Day 11 pays 8; the other rows are unchanged.

## 8. Mode flag and rollback
`Config.PEARL_PAYOUT_MODE = "perNight"` (new) or `"legacy"` (today's end-of-run payout). The saved `grants` field stays harmless if the flag is flipped back, because old code ignores unknown fields; the **legacy mode does not regain per-night durability**.
=== END FILE ===

=== FILE: TASK-004/CREW_FUEL_VALIDATION_REVISION.md ===
# Crew cap, crew fuel and server validation: confirmation and revisions (TASK-004) — design only

The auditor supports a server-enforced maximum of four active crew and fuel scaling by active crew. Both are unchanged from `TASK-003/CREW_CAP_AND_FUEL_DESIGN.md`. This file adds the requested test coverage and revises the validation design. No implementation is authorized.

## 1. Definitions
- **Active crew** = players with `Ready == true` and connected. The cap counts exactly these.
- **Spectator / harbor player** = connected, `Ready == false`, ashore. They never count for crew size, swarm scaling, fuel scaling, loot, Pearls or bench access.

## 2. Test coverage required for the cap and fuel (added to the matrix as C/F rows)
| ID | Scenario | Expected |
|---|---|---|
| CC1 | Full crew of 4, a 5th player uses the wheel | stays ashore, "ship is full", `Ready` unchanged, crew count 4 |
| CC2 | Full crew, two players press the wheel in the same frame | exactly one slot fills if one is free; no overshoot (join check and set run without a yield) |
| CC3 | First-voyage joiner arrives while the ship is full | routed to the harbor or title, no error, no half-joined state, coach not started |
| CC4 | A crew member leaves mid-run (disconnect, wheel, menu) | slot frees; a harbor player can join mid-voyage and is rowed out; crew never exceeds 4 |
| CC5 | Mid-run replacement earns correctly | eligible from the next night start (Pearl rule) |
| CC6 | Spectators in the harbor: 0, 2, 4 extra connected players | crew size, swarm share and fuel multiplier depend only on active crew |
| CC7 | Crew drops from 3 to 2 during a night | fuel multiplier changes at the next drain tick, no negative or nil index |
| CC8 | `Ready` set again for an already-Ready player | idempotent, no double count |
| F1 | Fuel multiplier equals `FUEL_DRAIN_BY_CREW_SIZE[crew]` for crew 1 to 4 | verified by reading the lamp state in an isolated run |
| F2 | Swarm scaling and fuel use the same crew number | same value at the same tick |
The harbor-spectator and first-voyage rows must use real clients in the test universe (Studio "Clients: N" for logic, plus real devices for the first-voyage path, because first-voyage routing depends on the profile load).

## 3. BuyUpgrade (SEC-9, revised)
Require **all** of:
1. **Authorized bench interaction:** the server records `benchSession[player] = { expiresAt = os.clock() + 120 }` only when `refs.upgradePrompt.Triggered` fires for that player (`Main.server.luau:69-71` already sends `OpenUpgrades` there). Cleared on `PlayerRemoving`, on phase end and on leaving the crew.
2. **Present-time proximity:** at `BuyUpgrade` time the player's root part must be within `bench.MaxActivationDistance + 8` studs of the bench part. Position is client-reported, so this is defence in depth against pure remote spam and absurd distances, not proof against a determined position spoofer (a spoofer who stands at the bench can still buy; the harm is limited to spending the crew's shared Shells).
3. **Phase and crew eligibility:** `Ready == true` and phase in Prologue, Day or Night, never in Results or the harbor.
The existing 0.3 s throttle and argument checks stay.

## 4. Repair, oil and refuel prompts (SEC-5, revised)
What is verifiable: `HoldDuration` values in the source are oil 0.5 s, refuel 0.5 s, repair `Config.REPAIR_HOLD_SECONDS = 1.5` s (`IslandBuilder.luau:248, 253, 287`; `Config.luau:111`).
- The Roblox reference pages I could read do not state on which side `PromptButtonHoldBegan` and `PromptButtonHoldEnded` fire, and they say nothing about server validation of distance. **I therefore do not claim a server-verifiable hold timer.** This is test V0 in the matrix: connect a server Script to those events in the test universe and see whether they fire for a real client.
- **If the hold events fire on the server:** record `holdBeganAt[player]` and, on `Triggered`, require `now - holdBeganAt >= 0.8 x HoldDuration`.
- **Regardless of V0, a per-player per-prompt cooldown of `0.8 x HoldDuration` is safe for honest players**, because an honest player can never complete a hold faster than `HoldDuration`. That alone removes burst spam.
- Also require `Ready`, run phase, and server-side distance to the prompt part <= `MaxActivationDistance + 8` (same position caveat as above).
- Honest-play regression: holding a prompt for its normal time is never rejected; a key-repeat or lag spike that completes two holds closer than 0.8 x HoldDuration is rejected, which is acceptable.

## 5. Retained as proposed
- `GearAction "sync"`: at most one push per player per second.
- Crew-only loot: only `Ready` players in the pickup list (`LootService.luau:233-241`).
- Non-finite attack rejection: reject any component that is NaN, infinite or has `math.abs(c) > 1e5`.
- **No movement anti-cheat** (speed or teleport checks) is part of this design, because the false-positive risk for legitimate players (knockback, ship transfers, server-side `PivotTo`) outweighs the benefit.

## 6. Validation tests (additions)
| ID | Scenario | Expected |
|---|---|---|
| V0 | Do hold-began/hold-ended events fire on a server Script? | documented as yes/no with evidence; decides section 4 |
| V1 | 50 `Triggered` calls in one second against each prompt | at most the cooldown-allowed number of effects |
| V2 | normal holds at the intended pace | none rejected |
| V3 | `BuyUpgrade` without a bench session | rejected |
| V4 | `BuyUpgrade` after the session expired (121 s) | rejected |
| V5 | `BuyUpgrade` from outside the proximity radius with a valid session | rejected |
| V6 | `BuyUpgrade` from a spectator or during Results | rejected |
| V7 | non-crew player over a boss Pearl drop | never collects |
| V8 | `sync` x30 in one second | one push |
| V9 | `Attack` with infinite or NaN components | ignored, no error |
=== END FILE ===

=== FILE: TASK-004/TEST_ENVIRONMENT_PROPOSAL.md ===
# Safe persistence test environment: a separate private test experience (TASK-004) — PROPOSAL ONLY

**Nothing has been created or published. The owner must approve explicitly, and the owner (not Claude) performs the Creator Hub and publish steps.** I do not assume that a local `.rbxl` is DataStore-safe: the backup check only recorded `PlaceId 0` and `GameId 0`, and the Roblox pages I read say nothing about local files (they say only that Studio, by default, cannot access data stores until "Enable Studio Access to API Services" is turned on, and warn that Studio then uses the same data stores as the live game). So local-file tests are treated as "unknown", never as protection.

## 1. Goal
A real Roblox universe with its own DataStores, in which real DataStore concurrency, takeover, failure, shutdown and migration behaviour can be exercised without any path to production player data.

## 2. Setup, step by step (owner actions, in this order)
1. **Create a new experience** in Creator Hub, for example "Lighthouse Keepers SaveTest". Keep it **Private**; do not list or monetize it. Note its **Universe ID** and **Place ID** and send them to Claude.
2. **Close the production Lighthouse Keepers Studio window** (and leave Outlaw City alone) so the wrong target cannot be chosen by accident.
3. In Studio, open the backup file `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl` (File > Open from File). The backup contains scripts, world and UI but **no player data** (DataStore data is not stored in a place file).
4. Use **File > Publish to Roblox As...** and pick **the new SaveTest place explicitly**. Do not pick "Lighthouse Keepers - Staging". If the dialog highlights the production experience by default, change it before confirming.
5. **Verify before anything else** (Claude does this read-only through MCP): the instance reports a `GameId` different from 10769064643 and a `PlaceId` different from 132065051336560. If either matches, stop.
6. In the **SaveTest** experience only, enable Game Settings > Security > "Enable Studio Access to API Services". The Roblox page recommends enabling this only on a separate test version, never on a live game.
7. **Recommended: turn that same setting OFF on the production experience**, so that Play sessions in the production Studio window can no longer write to the live DataStores. (Progress notes say Studio currently shares the live DataStore.) This is the owner's call.
8. No Open Cloud API keys are created and no credentials are shared with Claude.
9. Test accounts: the owner's test account(s) join the SaveTest experience. Because it has its own DataStores, those accounts get fresh profiles there.

## 3. Isolation argument and its check
Roblox DataStores belong to an experience (universe); the same store name in a different universe is a different store. I am relying on that general platform behaviour and did not find a page stating it in the sources I read, so it is verified by a gate test **T0**: in the SaveTest universe, a read of the key that exists in production for the owner's real profile (`player_11752219158`) must return nil, and a marker written to the SaveTest store must not be visible from production (verified only by the owner's own observation or a read-only check, never by writing to production). If T0 returns any data, **stop all testing** and escalate.
Additional guards in test code: an `assert(game.GameId ~= 10769064643)` at the top of every harness script, a `Config.ENVIRONMENT = "test"` flag the persistence code refuses to run without when the test hooks are enabled, and store names prefixed `TEST_` for fixtures.

## 4. What can be tested there that cannot be tested anywhere else
- Real `UpdateAsync` semantics, retries, throttling, latency and error codes against real DataStore servers.
- Two real servers: Studio "Test" runs a single local server, so true cross-server behaviour needs published servers. Reserved or private servers of the test place (TeleportService) give a controlled second server for the same account (leave A, join B quickly).
- Real shutdown via Creator Hub's shutdown/restart controls, including `BindToClose` timing.
- Mixed deployment: publish build N, keep its server up, publish build N+1, and join both.
- Library behaviour on a legacy-shaped record (test C12) in a store whose loss does not matter.
- Versioning/recovery behaviour (tests C11).

## 5. Data policy in the test universe
Fixtures are synthetic (fake UserIds such as `900000001`) or created by the test accounts. **No export of production records is made or needed.** If a realistic v1 shape is required beyond what the source code defines, the owner supplies one anonymised example explicitly.

## 6. Cleanup and risks
- When finished, the owner can delete the experience or leave it private; its stores are separate.
- Risks: choosing the wrong publish target (mitigated by steps 2, 4 and 5); the test place drifting from production code (mitigated by deriving it from the dated backup and recording the version); Roblox behaviour in a quiet private universe differing under production load (acknowledged; the soak period after cutover covers that).
=== END FILE ===

=== FILE: TASK-004/REVISED_TEST_MATRIX.md ===
# Revised test matrix (TASK-004) — nothing has been run

## 0. Environments (revised)
| Env | What | DataStore exposure | Use |
|---|---|---|---|
| **E0** | Logic harness with an in-memory fake backend (latency, errors, concurrent writers) | none: no DataStoreService call | protocol logic only |
| **E1** | Scratch Studio copy of the backup opened from disk, `SaveBackend` hard-wired to memory and **Studio API access never enabled** | **unknown, not assumed safe** (a local file showed PlaceId 0/GameId 0 but Roblox's pages do not say it blocks data stores) | handler and gameplay logic (Pearl ledger, crew cap, fuel, validation) only; no real persistence assertions |
| **E3** | **Separate private test universe** (`TEST_ENVIRONMENT_PROPOSAL.md`) with real DataStores | real, isolated by universe, gated by test T0 | every persistence test below |
| — | Production place and production DataStores | production | never used for these tests |
Hard rules from TASK-003 stay: no Play, Save, Publish or script execution on any instance whose GameId/PlaceId has not just been verified; Outlaw City is never touched; no `RemoveAsync` and no writes to production keys; no restore of backups over saves.

## 1. Gate
| ID | Test | Expected |
|---|---|---|
| **T0** | In E3, read `player_11752219158` (the owner's production key) and the other production-shaped keys | all nil. Any data: stop everything |

## 2. Real-DataStore persistence tests (E3, after E0 passes)
| ID | Scenario | Expected |
|---|---|---|
| C1 | Two sessions for one key start simultaneously (one server with injectable identities, then two real servers) | exactly one owns; the other waits then is refused/kicked; no profile loaded without ownership |
| C2 | Live holder takeover: holder stops heartbeating (injected pause), contender takes over | contender loads the latest committed state; holder's next write is rejected; holder removes the player |
| C3 | Fencing: stale holder issues a delayed write after takeover | rejected, stored data unchanged |
| C4 | Repeated callbacks: external conflicting writes force `UpdateAsync` to re-run the transform; count invocations | correct final data, no double effect, transform pure |
| C5 | Ambiguous commit: wrapper performs the real write then throws | read-back by `saveId` resolves to success; no duplicate write |
| C6 | Throttling: exceed the per-server budget with 4 players and bursty changes | no data loss; backoff works; queue-full errors (301-304) handled |
| C7 | Shutdown: Creator Hub shutdown with 4 players and injected 3-5 s latency | all saved in parallel inside the 30 s window; ownership released; time measured |
| C8 | Leave and immediately rejoin a different (reserved) server | no rollback; second server sees final data after release |
| C9 | v1 fixtures into the v2 import (empty, missing `equippedBeam`, unknown fields, wrong types, large `counts`) plus re-import | every shape imports once and idempotently; a failed v1 read blocks play and writes nothing; v1 untouched |
| C10 | Mixed deployment: old build stays up, new build published, same player on both | the fork is demonstrated; the documented restart procedure removes old servers; stale-write detection works as designed |
| C11 | Version history: list versions, confirm one kept per UTC hour, restore a test key from an older version | recovery procedure works and its granularity is measured |
| C12 | Library given a legacy-shaped (v1) record in a TEST store | confirms (or refutes) the overwrite-with-empty behaviour; never repeated elsewhere |
| C13 | Pearl durability: credit then kill the server; failed leave-save then rejoin on the same server | saved state measured; missing nights re-granted exactly once; loss window recorded, not assumed |
| C14 | Autosave period and write budget with 4 players at the chosen interval | stays inside the budget; lock refresh and saves counted |
| C15 | DataStore failure at boot and at load (fault injection) | no play, retry message, no overwrite, re-probe works |
| C16 | Session-lost experience | the player sees the intended message; no crash; logs useful |
| C17 | Isolation audit: confirm no test performed a write outside the test universe | every session logs `GameId`/`PlaceId` at start and the log shows only the test universe |

## 3. Gameplay and handler tests (E1 for logic, E3 for real clients)
Pearl rows P1-P14 from TASK-003 updated by `PEARL_PAYMENT_AND_IDEMPOTENCY.md` (graded bonus table, durable `grants` re-grant), crew rows CC1-CC8 and fuel rows F1-F2 and validation rows V0-V9 from `CREW_FUEL_VALIDATION_REVISION.md`. First-voyage joining and harbor spectators use real clients in E3 because first-voyage routing depends on a real profile load.

## 4. Regression pass
Run to Night 1 with a one-player crew: buy an item, equip, take the lamp, refuel, repair, leave, results, rematch; then a four-client run in E3 through at least night 3 including a mid-run leave and replacement. No console errors; same behaviour as before.

## 5. Still not covered by this matrix
Nights 4-13 and boss nights, real phones, controllers, long soak, and real production load. These remain separate tasks.

## 6. Evidence every row must leave
Test id, environment and verified IDs, number of real servers and clients, injected faults, steps, expected and actual, console lines, pass/fail, and whether the test could have touched production (must be "no").
=== END FILE ===

=== FILE: TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md ===
# Explicit owner decisions, implementation sequencing and remaining risks (TASK-004)

## 1. Decisions needed from the owner (each is a yes/no or a pick)
| # | Decision | Recommendation |
|---|---|---|
| D1 | Persistence path: library (ProfileStore, separate v2 store, one-time import) or hardened custom lock | Library, with the custom lock as fallback if a gate fails |
| D2 | Allow me to download the exact `ProfileStore.luau` at pinned commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd` into its own new empty folder (about one source file, from github.com/MadStudioRoblox/ProfileStore) to read it in full. Needed because this task read it only through a summarizing fetch tool | Yes |
| D3 | Create the separate private test experience and perform the publish-as steps yourself (`TEST_ENVIRONMENT_PROPOSAL.md`) | Yes, before any persistence work |
| D4 | Turn OFF "Enable Studio Access to API Services" on the production experience once the test universe exists | Yes |
| D5 | Maintenance-window cutover with a restart of outdated servers, accepting that invite or teleport joins can still reach an old server during the delay | Yes, short delay |
| D6 | Optional "pre-cutover fence" build and one marker write to the v1 store to evict old servers | Optional; recommend only if the plain restart proves unreliable |
| D7 | Treat the cutover as one-way after a soak period; define the soak length and abort criteria | Agree values before cutover |
| D8 | Win bonus: graded `round(5 x credited / 13)` (recommended), or a fixed minimum number of credited nights (7 is the lowest that removes the late-join advantage; 3 is not enough) | Graded |
| D9 | Count a run for early quitters only when present at Results or after at least one credited night | Yes |
| D10 | New saved field `grants` (last 20 runs or 30 days) for durable Pearl idempotency | Yes |
| D11 | Crew cap of 4 and fuel scaling by active crew (small crews get easier on busy servers) | Yes |
| D12 | Kick (not play-in-memory) when ownership of a save cannot be acquired | Yes |
| D13 | Library autosave interval (the default is 300 s; I suggest about 60-120 s if the write budget allows, to be set from test C14) | Decide after C14 |

## 2. Implementation sequencing (none authorized)
1. **TASK-004 accepted** by the auditor and owner.
2. **Owner actions:** D2 download approval, D3 test universe, D4 setting. Claude then verifies the new instance read-only (`GameId` not 10769064643) and runs gate T0.
3. **Read the library fully** (after D2), and diff it against `LIBRARY_SOURCE_FINDINGS.md`.
4. **Build and test in the test universe only:** persistence adapter, importer, harness; run E0 then C1-C17; produce evidence. No production change.
5. **Auditor gate:** review the evidence; decide library versus custom fallback.
6. **Production Batch 1 (persistence cutover)** with fresh `.rbxl` backup, `ServerStorage.Backups` copy, maintenance window, restart of old servers, soak period.
7. **Batch 2:** Pearl ledger and durable grants, crew cap, active-crew fuel.
8. **Batch 3:** validation hardening. These changes touch no saved data and could ship earlier if the owner and auditor prefer, but only with explicit authorization.
9. Boss redesign and the merchant stay blocked until the above are done and playtested.

## 3. Remaining risks (not eliminated by this design)
1. **Second-hand source reading:** ProfileStore was read through a fetch tool, not line by line.
2. **Thin maintenance:** last library commit 2025-07-31; a vendored copy becomes our code to maintain.
3. **Mixed-version servers** can fork or overwrite data until all old servers are gone; invite and teleport joins can reach old servers during the restart delay.
4. **One-way cutover:** rollback loses v2 progress unless an approved export tool is built and run in a maintenance window.
5. **Unbounded loss on crash:** any unsaved credit or purchase is lost; no maximum is guaranteed.
6. **Takeover of a slow-but-alive server** loses that server's unsaved memory state by design.
7. **Clock skew** between servers affects timestamp-based expiry (library uses 630 s dead-lock detection; the custom design uses minutes, not seconds).
8. **MessagingService dependency** for graceful takeover; if it degrades, takeover waits for the steal timeout (40 s in the library).
9. **Position trust remains** (client-reported positions); the validation changes limit blast radius but do not stop a determined spoofer.
10. **Production data shape unknown beyond the code:** real records may contain surprises; the importer fails closed instead of guessing.
11. **Hourly-granularity version history** (30 days) is the only built-in recovery for a bad write.
12. **Test universe parity:** a quiet private universe does not reproduce production load.
13. **Prompt hold verification** depends on engine behaviour not documented in the pages I read (test V0).
14. **Kicking players** on lock conflicts is user-visible and needs wording and soak monitoring.
=== END FILE ===

