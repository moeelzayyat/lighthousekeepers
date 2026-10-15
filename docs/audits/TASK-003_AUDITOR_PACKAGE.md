# TASK-003 AUDITOR PACKAGE (combined plain-text version)

Integrity design and safe test plan (place 132065051336560). Design only. NOTE: partly superseded by TASK-004; see CORRIGENDUM_TASK-003.md in the TASK-004 package. No code, Config, price, save or Studio content was changed and nothing was run.

## TABLE OF CONTENTS
1. TASK-003/AUDITOR_REPORT.md
2. TASK-003/CHANGE_MANIFEST.md
3. TASK-003/TEST_EVIDENCE.md
4. TASK-003/AUDITOR_QUESTIONS.md
5. TASK-003/SAVE_ARCHITECTURE_AND_MIGRATION.md
6. TASK-003/PEARL_ELIGIBILITY_DESIGN.md
7. TASK-003/CREW_CAP_AND_FUEL_DESIGN.md
8. TASK-003/VALIDATION_IMPROVEMENTS.md
9. TASK-003/ISOLATED_TEST_PLAN.md
10. TASK-003/IMPLEMENTATION_PLAN.md
11. TASK-003/CODE_EXTRACTS.md

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-003/AUDITOR_REPORT.md ===
> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# AUDITOR REPORT — TASK-003: Integrity design and safe test plan

- **Date:** 2026-10-14
- **Project / place:** Lighthouse Keepers - Staging, place **132065051336560**, universe 10769064643, place version 148 (source examined: the TASK-001 export in `src\`; no Studio access was needed or used for this task).
- **Original owner request (relayed from the independent auditor):** re-examine SEC-1/2/3 against PlayerData; compare a session-safe library with a minimal backward-compatible implementation; document the v1 schema, keys, failure states, migration risks and rollback; design isolated tests; propose a fair per-player Pearl system (GP-23/24); verify GP-25/GP-2 and propose a crew cap and crew-only fuel scaling; review SEC-5/6/8/9 for the smallest safe fixes; separate source-confirmed from needs-reproduction; produce an implementation plan with approval requirements. **No production gameplay, economy, save or Studio changes are authorized. Stop after the plan.**
- **Objective:** a reviewable design and test plan the owner and auditor can approve or change before any code is written.

## Work completed
Design documents only (listed in CHANGE_MANIFEST.md). The following were re-read directly in the exported source: `PlayerData.luau` (whole file), `GameState.luau` (phase loop, boss selection, Pearl payout), `Main.server.luau` (join/leave, crew, prompts, Attack, BuyUpgrade), `LootService.luau`, `TowerService.luau`, `LampService.luau` (fuel). Exact excerpts with line numbers are in `CODE_EXTRACTS.md`.

## Source-confirmed findings (read in code; not reproduced at runtime)
| Item | Result |
|---|---|
| SEC-1 no session lock | CONFIRMED BY SOURCE (`PlayerData.luau:101-116`, `:118-150`). Frequency in the real game needs two-server reproduction. |
| SEC-2 dirty flag cleared after yield | CONFIRMED BY SOURCE (`:96-99`, `:101-116`); deterministic sequence, rate unknown. |
| SEC-3 leave save tried once | CONFIRMED BY SOURCE (`:323-331`). |
| SEC-10 boot probe disables saving for the whole server | CONFIRMED BY SOURCE (`:290-308`). |
| New: shutdown saves are sequential; idle players are never re-saved | CONFIRMED BY SOURCE (`:332-338`, `:103`). |
| GP-23 Pearls go to whoever is Ready at the end | CONFIRMED BY SOURCE (`GameState.luau:503-524`, `Main.server.luau:646-657`). |
| GP-24 leavers/disconnects/Abandoned get nothing | CONFIRMED BY SOURCE (leavers are absent from `Players`; `:508`). |
| New: joining during the Results phase still sets Ready | CONFIRMED BY SOURCE that nothing prevents it; the timing window needs a test. |
| GP-25 no crew cap | CONFIRMED BY SOURCE (`joinCrew`); whether the Roblox place max-players setting caps the server is UNTESTED. |
| GP-2 fuel scales by all connected players, swarm by crew | CONFIRMED BY SOURCE (`LampService.luau:284` versus `GameState.luau:410`). |
| SEC-5, SEC-6, SEC-8, SEC-9, SEC-15 | CONFIRMED BY SOURCE that the checks are missing (`VALIDATION_IMPROVEMENTS.md` section 6); real exploit behaviour needs reproduction. |

## Requires reproduction before relying on it
Cross-server rollback frequency, the save-during-autosave loss rate, shutdown behaviour with real latency, how the engine's `UpdateAsync` handles a cancelled transform, whether a locally opened `.rbxl` really has no DataStore access, spoofed-position reach, and everything about performance. These are covered by `ISOLATED_TEST_PLAN.md`.

## Recommendations (all pending owner approval)
1. **Save integrity:** Option B (in-place lock, additive `_session`/`_rev` fields, same store and key, behind a flag). Reason: lossless rollback and the smallest change; Option A (library with a new store) stays the fallback if B cannot be made reliable in the harness.
2. **Pearls:** per-night credit at dawn to players present for the whole night, win bonus with a minimum nights rule, idempotent credit keys, leavers keep what they earned; full participation still pays 18.
3. **Crew:** `MAX_CREW = 4` enforced in `joinCrew`; fuel scaling by crew (this makes busy servers easier, which is a balance-visible change).
4. **Validation:** cooldown+phase gate for prompts, crew-only loot, `sync` throttle, bench-session gate for upgrades, infinity check on attacks.

## Architecture / gameplay / security / save-data / performance implications
No change was made, so none are in effect. If implemented as designed: the saved record gains two additive fields; rewards are credited per night instead of at the end (same totals for full participation); small CPU/DataStore cost increases (one lock-refresh write per player per minute) are expected but unmeasured.

## Known limitations
Design from reading code only. The library comparison (Option A) is from general knowledge; the library source was not downloaded or read. UpdateAsync cancellation semantics and the scratch-copy DataStore behaviour are assumptions marked for testing. No test of any kind was run.

## Outstanding problems
All TASK-002 findings remain open. The TASK-001 follow-up was done after this report was first drafted: the owner opened the backup in a separate Studio window and a read-only check found it matches the live place (see `TASK-001/ADDENDUM_BACKUP_LOAD_VERIFICATION.md`). One loose end: the live Lighthouse Keepers window was not in the instance list at that moment, which the owner should confirm.

## Ready for acceptance?
Yes as a design and plan. It is not an implementation and nothing is approved to start.
=== END FILE ===

=== FILE: TASK-003/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-003

**No game script, Config value, price, save, Studio instance or published content was changed.** No new remotes, modules or in-game instances were created. No persistent data or economy value changed. Owner approval: none needed (documents only). Studio was not used.

Files created (all under `C:\RobloxProjects\LighthouseKeepers\docs\audits\TASK-003\`):

| File | Purpose |
|---|---|
| `AUDITOR_REPORT.md`, `CHANGE_MANIFEST.md`, `TEST_EVIDENCE.md`, `AUDITOR_QUESTIONS.md` | Standard package |
| `SAVE_ARCHITECTURE_AND_MIGRATION.md` | SEC-1/2/3 re-check, v1 schema, option comparison, Option B design, migration and rollback |
| `PEARL_ELIGIBILITY_DESIGN.md` | Per-player Pearl rule, ledger, idempotency, disconnect handling, scenario table |
| `CREW_CAP_AND_FUEL_DESIGN.md` | GP-25 and GP-2 verification, proposed cap and fuel change, acceptance criteria |
| `VALIDATION_IMPROVEMENTS.md` | SEC-5, 6, 8, 9, 15 smallest fixes, confirmed-versus-needs-reproduction table |
| `ISOLATED_TEST_PLAN.md` | Environments, safety rules, test matrix |
| `IMPLEMENTATION_PLAN.md` | Three batches, affected scripts, acceptance, rollback, approvals |
| `CODE_EXTRACTS.md` | Verbatim line-numbered excerpts of the code the designs refer to, generated mechanically from `src\` |

Also touched outside the package: `docs\audits\TASK-001\` addendum is pending (see TASK-001), no other file.

Source diffs: none (no code changed). Proposed code is described in prose only; none was written into `src\`.
=== END FILE ===

=== FILE: TASK-003/TEST_EVIDENCE.md ===
> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# TEST EVIDENCE — TASK-003

**Tests performed: none.** This task is design and documentation only.

- Environment: exported Luau source on disk (`src\`, place version 148). No Studio session was used, no Play session, no clients, no device, no emulator.
- Could anything here have changed production DataStore values? **No.** No code ran.
- Evidence type: direct reading of the source files named in the report; verbatim excerpts with line numbers are in `CODE_EXTRACTS.md` (generated mechanically from the files on disk).
- Console output, screenshots, performance measurements: none.
- Arithmetic in the documents (Pearl scenarios, fuel multipliers) comes from Config constants and the code's own formulas; it is calculation, not observation.

**Tests not performed:** everything in `ISOLATED_TEST_PLAN.md` (S1-S14, P1-P14, C1-C4, F1, V1-V6, R1). Nothing was reproduced.

**Assumptions that must be tested before relying on them:** (1) `UpdateAsync` behaviour when the transform returns nil; (2) a file opened from disk has `GameId` 0 and no DataStore access; (3) the 150 s lock TTL against real autosave timing; (4) Roblox's 30 s `BindToClose` window with parallel saves; (5) the description of ProfileStore's record shape.

**Remaining regression risk:** none from this task (no change).
=== END FILE ===

=== FILE: TASK-003/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-003

1. **Option B versus Option A.** Is an in-place additive lock (same store, same key, flag-gated, lossless rollback) an acceptable first step, or would you insist on an established library with a new store and a read-only import from v1, accepting lossy rollback? What would you want the harness to prove before B is trusted?
2. **Lock-conflict behaviour.** If another live server still holds a save after about 20 s of waiting, the design kicks the player with a plain message instead of letting them play in memory. Agree? Any alternative that cannot lose progress?
3. **Lock TTL.** 150 s against a 60 s autosave plus a heartbeat for idle players. Is a shorter TTL safe if heartbeats are reliable, given that a crashed server blocks a rejoin for that long?
4. **Pearl rule.** Per-night credit to players present for the whole night, win bonus only after `PEARLS_BONUS_MIN_NIGHTS` credited nights (proposed 3). Is this the right fairness trade-off, and is 3 sensible for a 13-night run? Should an AFK guard be in the first batch or after playtests?
5. **Run counting for early quitters.** Count a run for any player with at least one credited night (proposed), or for any run started? It changes which players see the first-voyage route and coach again.
6. **Fuel change.** Scaling fuel by crew rather than by everyone on the server makes small crews on busy servers easier. Accept as restoring the documented intent, or hold it for the balance pass?
7. **Position trust.** Crew-only loot is phase 1. Is a server-side movement sanity check worth its false-positive risk in phase 2?
8. **Test environment.** Is E0 (fake backend) plus E1 (scratch copy of the backup, no DataStore access) sufficient evidence before touching the live place, or should the separate test experience (E2) be mandatory before Batch 1?

No further concerns have been invented; items 1, 4 and 6 are the substantive forks.
=== END FILE ===

=== FILE: TASK-003/SAVE_ARCHITECTURE_AND_MIGRATION.md ===
> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# Save architecture and migration proposal (TASK-003, design only)

Source examined: `src\ServerScriptService\Server\PlayerData.luau` (exact export of place version 148). Line numbers below refer to that file. Nothing here has been implemented or run.

## 1. SEC-1, SEC-2, SEC-3 re-examined against the source

| ID | Claim | Source evidence | Status |
|---|---|---|---|
| SEC-1 | No session lock: saves overwrite whatever is stored | `save()` lines 101-116: `store:UpdateAsync(key, function() return profile end)`. The transform ignores its argument (the stored value), so the stored record is replaced unconditionally. `load()` lines 118-150 uses `GetAsync`, no claim of ownership. | CONFIRMED BY SOURCE. The actual rollback needs two servers touching one key (leave on server A while joining server B, or two servers open at once), so the real-world frequency requires reproduction. |
| SEC-2 | A change made while a save is in flight is marked saved and lost | `markChanged` sets `dirty[player] = true` (line 97). `save()` reads `profile` at call time, then yields inside `UpdateAsync`; on success it runs `dirty[player] = nil` (line 112). Any `markChanged` during the yield is erased. If the player then leaves, `save()` returns early at line 103 because `dirty` is nil, so the change is never written. | CONFIRMED BY SOURCE (the sequence is deterministic). Needs an isolated reproduction to measure how often it bites. |
| SEC-3 | Leave save is attempted once | `PlayerRemoving` handler lines 323-331: a single `save(player)` call, a failure only `warn`s (line 114), then `profiles[player] = nil` (line 328) discards the in-memory profile. | CONFIRMED BY SOURCE. |
| SEC-10 | One failed access check at boot disables saving for the server | `init()` lines 290-308: one `GetAsync("__access_check")` inside one `pcall`; failure sets `storeAvailable = false` for the lifetime of the server. | CONFIRMED BY SOURCE. |
| new | `BindToClose` saves are sequential | Lines 332-338 call `save(player)` in a `for` loop; each `UpdateAsync` yields, so N players cost N round trips inside Roblox's 30 s shutdown window. | CONFIRMED BY SOURCE; effect on a real shutdown needs a test. |
| new | Autosave does not refresh anything for idle players | Line 103: `save` returns when `dirty[player]` is nil. This matters for any lock heartbeat (see 4). | CONFIRMED BY SOURCE. |

## 2. The existing v1 schema (documented from `newProfile()` / `reconcile()`)

- DataStore name `LighthouseKeepers_PlayerData_v1`, key `player_<UserId>`, plus a probe read of key `__access_check` at boot.
- Value is the profile table saved as-is:

```
{
  version = 1,                  -- written, never read (SEC-12)
  pearls = number,
  owned = { [itemId] = true },  -- weapons, armor, cosmetics
  counts = { [itemId] = n },    -- ammo crates and run loot
  equippedArmor = string, equippedWeapon = string, equippedBeam = string,
  stats = { runs = n, victories = n, bestNight = n },
}
```
- `reconcile()` fills missing top-level keys from the template and restores starter items; it never removes unknown keys, so additive fields are safe for both old and new code.
- Runtime-only field `doNotSave` is set on failed loads and is never written because every caller checks it (lines 134-137, 325, 334, 343). `save()` itself does not check it (a latent hazard, not a live bug).
- Precedent for additive change: `equippedBeam` was added on Oct 12 with a default (IMPLEMENTATION_LOG), and old saves loaded fine.
- Failure states today: store unavailable at boot (memory only, `SaveUnavailable` attribute); load fails 3 times (memory only, `doNotSave`, `ProfileState = "failed"`); save fails (warning only, retried at next autosave if still dirty, but see SEC-2/3).
- Unknown: whether production records contain any fields besides the above. Reading real records is a production read and is NOT part of this task.

## 3. Options compared

### Option A: adopt an established session-safe library (ProfileStore, successor of ProfileService)
Pros: widely used, handles lock heartbeat, release, steal, retries, BindToClose and a Studio mock; less hand-written locking code. Cons: stores a wrapped record (`Data` plus metadata), so existing v1 values are not the same shape; adoption realistically means a **new DataStore name** (`..._v2`) and a one-time import from v1, which makes rollback lossy (progress made after the cutover lives only in v2). Adds a third-party module to the game (license check, review of its source, and under project rules the file must be downloaded into its own empty folder and read before use). I have not downloaded or read the current library source in this task; the description above is from general knowledge and must be re-verified before anyone relies on it.

### Option B: minimal in-place, backward-compatible lock in `PlayerData` (recommended)
Keep the same store, the same key and the same record shape, and add two additive top-level fields (`_session`, `_rev`). Pros: rollback is a code revert with no data conversion; the change is confined to `PlayerData.luau`; behaviour can be gated by a Config flag. Cons: hand-written concurrency logic, which is exactly where subtle bugs live, so it must pass the isolated tests in `ISOLATED_TEST_PLAN.md` before any real use; an adopted library has had far more real-world exposure.

**Recommendation: Option B, behind `Config.SAVE_LOCKING_ENABLED`, because the existing data stays untouched in shape and rollback is lossless. If the isolated tests show B cannot be made reliable, switch to Option A with the `_v2` store and a read-only v1 import.** This is a trade-off the owner and the auditor should confirm (see AUDITOR_QUESTIONS.md).

## 4. Option B design

Fields added to the saved record (additive, ignored by old code):
- `_session = { jobId = game.JobId, t = os.time() }` (who holds the save and when it last refreshed).
- `_rev = integer`, incremented on every write (diagnostics and conflict detection).

Behaviour:
1. **Load** (per player, with retries): `UpdateAsync(key, transform)`. Inside the transform, set upvalue flags (do not rely on the return value of a cancelled update; the transform may run more than once, so reset the flags on each run). If a record exists with a `_session` held by a different `jobId` whose `t` is newer than `LOCK_TTL` (proposed 150 s, longer than two autosave periods), cancel and flag `conflict`. Otherwise write the record back with `_session` set to this server and `_rev + 1`. If the key is empty, create a new profile with the lock.
2. **Lock conflict**: retry every 3 s for up to about 20 s (covers the leave-then-join hop where the old server is still releasing). If still locked, do NOT load a copy; kick with a plain message ("Your save is still closing on another server, please rejoin in a moment"). Playing in memory would silently discard progress.
3. **Save** (autosave, leave, shutdown): `UpdateAsync` whose transform first checks the stored `_session`; if another live server owns it, cancel and mark the player `doNotSave` (kick). Otherwise it writes a deep copy of the profile taken inside the transform, with `_session.t` refreshed and `_rev + 1`.
4. **Change tracking (fixes SEC-2)**: replace the boolean with a counter. `markChanged` increments `changeCount[player]`. A save records the counter value before the call, and after success clears dirty only if the counter is unchanged.
5. **Heartbeat**: the 60 s loop also performs a lock-refresh write for clean (non-dirty) profiles; otherwise an idle player's lock goes stale and another server could take it. Budget: one write per minute per player.
6. **Leave save (fixes SEC-3)**: up to 3 attempts with backoff, then release the lock (`_session = nil`) in the final successful write. If every attempt fails, keep the profile in a short-lived retry table (about 60 s) instead of dropping it, and log it.
7. **Shutdown**: save all players in parallel (`task.spawn` each, wait for all or about 25 s), release locks.
8. **Boot probe (SEC-10)**: retry the access check a few times with backoff before declaring the store unavailable, and re-probe later instead of disabling permanently.
9. **Failed load** keeps today's safe behaviour (`doNotSave`, never overwrite), and the same flag must be honoured inside `save()` itself.

## 5. Migration, compatibility and rollback
- No schema conversion is needed for Option B. `version` can stay 1. Unknown fields are preserved because `reconcile` only adds keys.
- **Old code reading new records**: loads fine, ignores `_session` and `_rev`, and writes them back unchanged. If the owner rolls the code back and later forward, a stale lock from the old build simply expires after `LOCK_TTL`.
- **Rollback**: set `SAVE_LOCKING_ENABLED = false` (code path equals today's) or republish the previous version. No data restore is needed. Never restore a backup over player saves.
- **Cutover risk**: players already online when the new build goes live have no lock record; their first save writes one. Servers running old and new code at the same time during a rolling update are protected only partially (old servers ignore locks). Mitigation: publish at a quiet time and use Roblox's server-shutdown-on-update setting if the owner chooses.
- **Must be tested in isolation before use** (see the test plan): the cancel-return semantics of `UpdateAsync`, the behaviour of a nil return, the 4 MB value limit (profiles are tiny), and request budgets.
- **Backups before any implementation batch**: a fresh local `.rbxl` saved by the owner, `ServerStorage.Backups.<Batch>_before_<date>` for the touched scripts, and a copy of `src\` on disk. Production player data is never exported or restored by this work.
=== END FILE ===

=== FILE: TASK-003/PEARL_ELIGIBILITY_DESIGN.md ===
> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# Pearl eligibility design (GP-23, GP-24, SEC-4, SEC-16, SEC-17) — design only

Changes rewards and persistence behaviour, so **owner approval is required** before any implementation. Nothing here has been built or run.

## 1. What the source shows today
- Payout happens once, at run end, in `GameState.luau:503-524`: `voters = readyPlayers()` (every connected player whose `Ready` attribute is true at that instant), then for each `earned = PEARLS_PER_NIGHT * survived (+ STEP term) (+ VICTORY_BONUS) (+ award term)`, `addPearls`, `recordRun`.
- `survived` is `NIGHTS_TO_WIN` on Victory and `nightReached - 1` on Defeat (`:509`). Config now: 1 per night, step 0, win bonus 5, award term `PEARLS_PER_AWARD = 0`, so a full win pays 13 + 5 = 18.
- `Ready` is set by `joinCrew` (`Main.server.luau:646-657`) in any phase, with no check of how long the player has been present. `joinCrew` during Victory/Defeat/Results sets `Ready` (the RUN_PHASES check only decides whether to row them out), so a player can join after the last night and still be in `voters` (CONFIRMED BY SOURCE: nothing in `joinCrew` or `readyPlayers` prevents it; the exact timing window needs a test).
- A player who disconnects is no longer in `Players`, so is not in `voters`: 0 Pearls and no `recordRun` (CONFIRMED BY SOURCE). An `Abandoned` result skips the whole block (`:508`, `:356`, `:391`, `:453`).
- Boss Pearl drops (`LootService.luau:126-127`, collected at `:153-160`) go to the nearest living player of ANY kind (`:233-241`), not only crew.

## 2. Proposed rule (recommended)
**Pay per night survived, credited at dawn, only to players who were on the crew for that whole night.** The win bonus goes only to players who were on the crew at the start of the final night and are still present at victory.

- Full participation pays exactly what it pays today (13 + 5 = 18 on a win; `nightReached - 1` on a defeat), so the owner-approved Pearl amounts and shop prices are untouched. What changes is who is eligible and when it is credited.
- Late joiner: joins during night N, earns from night N+1 on. Someone joining at night 13 would get 1 Pearl for that night plus the win bonus only if the bonus rule below allows it.
- Leaver or disconnect: keeps every night already credited (already in their profile and saved by the leave-save). No further credit.
- Rejoin in the same run: the run ledger is keyed by UserId, so earlier nights stay recorded; they resume earning from the next night.
- **Win-bonus guard (owner decision):** require having earned at least `PEARLS_BONUS_MIN_NIGHTS` night credits in this run (proposed default: 3). Without a minimum, a night-13 joiner could still take the 5-Pearl bonus; with 3, joining late is worth about 1 to 3 Pearls instead of 18.

## 3. Mechanics
1. **Run ledger** (server memory, created in `resetRound`, discarded at the next run): `ledger[userId] = { nights = {[n]=true}, bonusPaid = false, left = false, joinedNight = n }`, plus a unique `runId` (incrementing counter plus start time).
2. **Roster snapshot at night start**: when `setPhase("Night", n)` begins, record the set of present crew UserIds. At `NightSurvived`, credit only IDs that are in that start snapshot AND still in `Players` (a player who disconnects during the night does not earn that night).
3. **Credit function**: `PlayerData.grantPearlsOnce(player, key, amount, reason)` where `key = runId .. ":n" .. night` (or `":bonus"`). The ledger refuses a repeated key, giving **duplicate-payout protection** (if the night loop or a retry ever fires twice, the second call is a no-op). Because a run lives and ends on one server, in-memory keys are enough; no new saved field is needed for this.
4. **End of run**: the victory bonus is paid from the ledger; `recordRun` is applied to ledger players who are present at the end, and on leave for players with at least one credited night (so a first-timer who quits in the prologue stays "new" for the coach and first-voyage route, which is an owner call; the alternative is to count every started run).
5. **Results screen**: `results.pearls[player.Name]` is the sum credited to that player this run (night credits plus bonus). The shape the client reads does not change. Leavers simply do not appear.
6. **No payout for joiners during the Results phase**: `joinCrew` during Victory/Defeat/Abandoned either queues them for the next run (set `Ready` when the next intermission starts) or leaves them ashore. Rewards come from the ledger, not from `Ready`, so even if they sneak in they earn nothing.
7. **AFK guard (optional, owner decision)**: a night counts for a player only if they did at least one tracked contribution that night (refuel, repair, oil pickup, strike, cannon build/reload, loot pickup; `EventLog` already counts most of these per player) or moved a minimum distance. This stops idle farming but cannot stop a deliberate cheater, since position is client-reported. Default proposal: off in the first batch, add after playtests, to avoid punishing quiet but legitimate Keepers (a Keeper at the lamp barely moves; lamp holding must count as activity).
8. **Boss Pearl drops**: only living crew-roster players can collect `Pearls` drops (see `VALIDATION_IMPROVEMENTS.md`); `PEARL` drops use the same `grantPearlsOnce` with a key containing the drop id.
9. **Rollback flag**: `Config.PEARL_PAYOUT_MODE = "perNight"` (new) or `"legacy"` (today's end-of-run payout). Flip to `legacy` to restore current behaviour without republishing code changes.

## 4. Disconnect and failure handling
- Leave during the day or night: ledger marked `left`, profile saved with credits already granted. If the leave-save itself fails, the retry logic from `SAVE_ARCHITECTURE_AND_MIGRATION.md` applies.
- Server shutdown mid-run: credits granted so far are in profiles and saved by the parallel shutdown save; nothing is owed for the unfinished night.
- Crash of a server: unsaved credits since the last autosave are lost (at most 60 s of changes; a night credit is granted at dawn, so at worst one night).
- Credit during a profile that is `doNotSave` (failed load): the credit lands in memory only and is lost on leave, as today; the player is told (GP-27).

## 5. Scenario table for the later test (expected results under the recommended rule; nothing run)
| Scenario | Expected Pearls |
|---|---|
| Full 13-night win, present throughout | 18 |
| Defeat on night 5, present throughout | 4 |
| Join at start of night 13, win | 1 (night 13) + 0 bonus if minimum is 3 nights |
| Join at night 7, win | 7 night credits (nights 7-13) + 5 bonus if minimum is 3 |
| Leave after night 9 (credited 1-9) | 9, kept |
| Disconnect during night 9 | 8, kept |
| Rejoin after leaving during night 9, win | 8 + nights 10-13 = 12 + bonus 5 = 17 |
| Join during Results phase | 0 |
| NightSurvived fires twice for the same night | second call ignored |
| Abandoned (everyone left) | each already earned night is kept; no bonus |

## 6. Owner decisions needed
1. Approve per-night eligibility (recommended) versus a simpler "paid only if present at the end" rule.
2. Set `PEARLS_BONUS_MIN_NIGHTS` (proposed 3).
3. First-timer who quits early: count the run or not.
4. AFK guard now or after playtests (proposed: after).
=== END FILE ===

=== FILE: TASK-003/CREW_CAP_AND_FUEL_DESIGN.md ===
# Four-player crew cap and crew-only fuel scaling (GP-25, GP-2) — design only

## 1. Verification against source
| Claim | Evidence | Status |
|---|---|---|
| The 1-4 crew limit is not enforced | `joinCrew` (`Main.server.luau:646-657`) sets `Ready = true` with no count check; callers are the ship's wheel (`:660-672`) and the first-voyage route (`chooseRoute`, which calls `joinCrew`). `readyPlayers()` (`GameState.luau:101-109`) returns every Ready player. | CONFIRMED BY SOURCE. Whether Roblox's place max-players setting already stops a fifth player from joining the server is a Studio/website setting I did not inspect (UNTESTED). Even if it caps the server at 4, the cap is a server rule, not a crew rule, so harbor players beyond the crew would still be counted by GP-2. |
| Swarm scaling silently clamps at 4 | `GameState.luau:410`: `math.clamp(#readyPlayers(), 1, 4)`. A 5th crew member adds players but no extra scaling. | CONFIRMED BY SOURCE |
| Fuel drain counts everyone on the server | `LampService.luau:284`: `math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)`. Every connected player is counted, including harbor and title-screen players, while the swarm uses `readyPlayers()`. | CONFIRMED BY SOURCE |
| Effect size | `FUEL_DRAIN_BY_CREW_SIZE = {0.7, 0.85, 1, 1}`. A solo crew on a server with 3 other players in the harbor drains at 1.0 instead of 0.7 (about 43% faster). Two crew plus 2 harbor players drain at 1.0 instead of 0.85. | ARITHMETIC FROM CONFIG, no run observed |

## 2. Proposed change (smallest safe)
**Crew cap**
- Add `Config.MAX_CREW = 4`.
- In `joinCrew`, before `SetAttribute("Ready", true)`, count Ready players. If the count is already `MAX_CREW` and this player is not already Ready, send "The ship is full" through the existing notify path and return without setting `Ready`. The check and the set run without a yield, so two simultaneous joins cannot both pass (Luau's cooperative scheduling).
- The first-voyage fast path (`chooseRoute`) must fall back to the title/harbor when the ship is full instead of failing silently; the player can use the wheel when a slot opens.
- When a crew member leaves mid-run, the slot opens and a harbor player may join mid-voyage as today.
- Recommendation for the owner: also consider setting the Roblox server size to match what the lobby needs; that is a website setting and is out of scope.

**Fuel scaling**
- Replace `#Players:GetPlayers()` at `LampService.luau:284` with the number of players whose `Ready` attribute is true (the same predicate used in `LampService.luau:383`). No new state is needed.
- Behaviour note: this restores the documented intent ("smaller crews burn less fuel") but it changes difficulty on busy servers. A small crew on a busy server gets easier; nothing gets harder. This is a **balance-visible change and needs owner approval**.

## 3. Acceptance criteria
1. With 4 crew present, a 5th player using the wheel stays ashore, gets the "ship is full" message, and `readyPlayers()` returns 4.
2. A first-voyage player arriving at a full ship lands in the harbor/title flow with no error.
3. Crew leaves mid-run, then a harbor player joins: join succeeds, and a 5th crew member is rejected.
4. Fuel drain rate multiplier equals `FUEL_DRAIN_BY_CREW_SIZE[crew]` for crew 1, 2, 3, 4, independent of how many non-crew players are connected (checked by reading `LampService` state in an isolated run, see test plan).
5. Swarm scaling still uses the same crew number as fuel.

## 4. Risks and compatibility
- A player stuck outside while the crew is full might want a spectator or queue; not in scope.
- No saved data is touched. Rollback is a code revert or `MAX_CREW = 99`.
=== END FILE ===

=== FILE: TASK-003/VALIDATION_IMPROVEMENTS.md ===
# Smallest safe validation improvements: SEC-5, SEC-6, SEC-8, SEC-9 (and SEC-15) — design only

Source-confirmed facts are separated from facts that need an isolated reproduction (section 6). No code was changed.

## SEC-5: repair, oil and refuel prompts have no server cooldown or phase check
Source: `TowerService.luau:26-38` (repair), `Main.server.luau:204-231` (oil, refuel). None checks `Ready`, the phase, or a per-player cooldown. Prompt hold times: oil 0.5 s and refuel 0.5 s (`IslandBuilder.luau:248, 287`), repair `Config.REPAIR_HOLD_SECONDS` (`:253`).
**Smallest fix:** one helper `cooldownOk(player, key, seconds)` (table of last-use times, cleared on `PlayerRemoving`). Use about 0.4 s for oil and refuel (a bit under the 0.5 s hold, so honest play is never blocked) and a fraction of `REPAIR_HOLD_SECONDS` for repair. Also require `Ready` and a run phase (Prologue, Day, Night).
**What it stops:** executor-style repeated prompt firing that ignores the hold time. **What it does not stop:** a player legitimately holding the prompt, and spoofed position (see SEC-6).

## SEC-6: client-reported position is trusted
Source: loot magnet and pickup use `HumanoidRootPart.Position` of every living player (`LootService.luau:233-241`, `:257`); `Attack` clamps range from the client's own root position (`Main.server.luau:528-531`); Trader/shop distance checks use the same position. Roblox lets the owning client move its own character, so any server check based on that position is only as honest as the client.
**Smallest fix (phase 1):** in the LootService heartbeat list, include only players with `Ready == true` (a one-line condition at `:237`). This keeps boss Pearl drops and shared Shell pickups to the crew, which removes the "outsider teleports in and steals the drop" case without any new tracking.
**Optional phase 2 (needs a test before shipping):** a server-side movement sanity check, sampling each crew member's position about once per second and ignoring pickups/attacks for a player whose displacement exceeds roughly `3 x WalkSpeed x dt` plus a margin. This can create false positives (knockback, ship rowing, `PivotTo` teleports by the server itself, which must be excluded), so it ships only after the test plan covers it.

## SEC-8: `GearAction "sync"` is unthrottled
Source: `PlayerData.luau:310-316`. Each call runs `push()` which JSON-round-trips the whole profile (`snapshot`, line 83) and fires a remote.
**Smallest fix:** a per-player `lastSync` time; ignore calls closer than 1 s apart. Clear on leave.

## SEC-9: `BuyUpgrade` can be fired from anywhere by anyone
Source: `Main.server.luau:116-145`. Only a 0.3 s per-player throttle and type checks. `UpgradeService.buy(id)` takes no player argument, so it spends the crew's shared Shells.
**Smallest fix:** require `Ready` and a run phase, and require a recent bench interaction: when `refs.upgradePrompt.Triggered` fires (`Main.server.luau:69-70`, which already sends `OpenUpgrades` to that client), record `benchOpenUntil[player] = os.clock() + 120`. `BuyUpgrade` is accepted only while that time is in the future. This ties purchases to a genuine server-observed prompt activation instead of trusting position.

## SEC-15: infinite coordinates in `Attack`
Source: `Main.server.luau:500` rejects NaN but not infinity; `offset.Unit` of an infinite vector is NaN, so the clamped target becomes NaN (`:529-531`).
**Smallest fix:** also reject any component with `math.abs(c) > 1e5`.

## 5. Acceptance criteria (for the later implementation)
1. A scripted burst of 50 prompt fires in one second yields at most the cooldown-allowed number of effects (checked in the isolated harness by calling the handlers directly).
2. Honest play: holding a prompt for its normal hold time is never rejected.
3. A non-crew player standing on the loot never receives a Pearls drop.
4. `sync` called 30 times in one second causes one push.
5. `BuyUpgrade` from a player who never used the bench prompt is rejected; from one who did within 120 s it succeeds.
6. `Attack` with `Vector3.new(math.huge, 0, 0)` is ignored.
7. All existing handlers still pass the manual checklist in the test plan.

## 6. What is source-confirmed and what needs reproduction
| Item | Source-confirmed | Needs reproduction |
|---|---|---|
| SEC-5 no cooldown / phase check | yes (code read) | whether exploit tooling really fires `Triggered` without the hold on live servers |
| SEC-6 trusts client position | yes | how far a spoofed position works against loot/range (needs a harness that moves a test character) |
| SEC-8 no throttle | yes | server cost per call under spam (needs a profile) |
| SEC-9 no gate | yes | nothing needed to confirm the gap |
| SEC-15 NaN target | yes (arithmetic on `Vector3`) | confirm that `damageArea` with a NaN target does nothing harmful |
=== END FILE ===

=== FILE: TASK-003/ISOLATED_TEST_PLAN.md ===
> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# Isolated test plan (TASK-003) — nothing here has been run

## 0. Hard safety rules for every test
1. **No test touches the production DataStore (`LighthouseKeepers_PlayerData_v1`) or the owner's real profile (`player_11752219158`).** Studio on the live place shares the live DataStore, so no save-related test runs in the live Lighthouse Keepers Studio window.
2. No Play, Stop, Save, Publish or script execution is ever sent to Outlaw City, or to any instance whose place ID has not just been re-verified. The instance list is re-read before each step.
3. Never publish the scratch copy and never use "Save to Roblox" on it.
4. No `RemoveAsync`, no `SetAsync`/`UpdateAsync` against production keys, no restore of backups over saves.

## 1. Environments
| Env | What | DataStore exposure | Used for |
|---|---|---|---|
| E0 | Pure-logic harness: the new save logic written against an interface `Backend` with `getAsync/updateAsync`, run against an in-memory **fake backend** that simulates latency, errors, throttling and concurrent writers | none (no DataStoreService call at all) | save lock, dirty-counter, retry, shutdown, migration shapes |
| E1 | **Scratch copy** of the game: the owner opens `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl` through File > Open from File in its own Studio window; this is also the TASK-001 follow-up. A file opened from disk is not tied to the published universe, so its `game.GameId` should be 0 and DataStores are unavailable (expected; verified at the start of each session by reading `game.GameId` and `game.PlaceId` only) | none | handler tests with Studio "Clients: 4", Pearl ledger, crew cap, fuel, validation, with `SaveBackend = memory` |
| E2 | Optional: a **separate private test experience** created by the owner in their account (new place, new universe), with a test-only store name (for example `LK_TEST_PlayerData`), joined by test accounts only | real DataStores, but a different universe | true two-server tests (rejoin and server hop), shutdown behaviour |
| — | The live Lighthouse Keepers place | production | **never used for these tests** |

Studio's Test tab can start several clients against one local server; it cannot make two separate servers, which is why true cross-server behaviour needs E2 (or is simulated in E0 with two logical servers that have different `JobId`s sharing one fake store).

## 2. Save integrity tests (E0 first, E1 second, E2 last)
| ID | Scenario | Expected |
|---|---|---|
| S1 | Two logical servers load the same key at once | exactly one holds the lock; the other waits, then kicks/refuses; no profile is loaded without a lock |
| S2 | Rejoin: server A releases at leave, server B loads 1-3 s later | B waits for the release then loads the final data from A |
| S3 | Server A "crashes" (stops refreshing); B loads | B is refused until `LOCK_TTL`, then takes over; A's late write is rejected |
| S4 | Autosave in flight (slow fake backend, 3 s), purchase or Pearl grant lands during the wait | dirty is not cleared; the next save writes the change; final store value contains it |
| S5 | Same as S4, then the player leaves before the next autosave | leave save writes the change (this reproduces SEC-2 on today's code in E0, then must pass on new code) |
| S6 | Leave save fails twice then succeeds | retried with backoff; lock released only after success |
| S7 | Leave save fails every time | profile kept in the retry table, error logged, no silent drop |
| S8 | Shutdown with 4 players and 4 s latency per save | all four saves started in parallel; completes inside about 25 s; lock released |
| S9 | Failed load (fake `GetAsync` throws 3 times) | `doNotSave`, no write ever happens for that key, `ProfileState = "failed"`; `save()` itself also refuses |
| S10 | Boot probe fails once then succeeds | store becomes available after retry instead of staying disabled |
| S11 | Migration shapes fed to `reconcile` and the loader: empty key, v1 record without `equippedBeam`, record with unknown extra fields, record with `_session` from a dead server, record with a `nil` stats table | every shape loads, unknown fields preserved, defaults filled, no error |
| S12 | Old code reading a new record (copy of today's `reconcile` run on a record with `_session`/`_rev`) | loads; fields ignored; writes preserve them |
| S13 | Lock heartbeat for an idle (clean) profile over 3 autosave periods | lock timestamp refreshed; not stolen by a second server |
| S14 | Flag `SAVE_LOCKING_ENABLED = false` | behaviour identical to today's code in S1-S13 where applicable (documents the rollback) |

## 3. Pearl, crew and validation tests (E1, `SaveBackend = memory`, Studio "Clients: 4" where players are needed)
| ID | Scenario | Expected |
|---|---|---|
| P1-P10 | the ten rows of the scenario table in `PEARL_ELIGIBILITY_DESIGN.md` | amounts match the table; no duplicate credit; Results shows per-player Pearls |
| P11 | Call the credit function twice with the same key | second call is a no-op |
| P12 | Player leaves, rejoins mid-run (same UserId, memory store) | earlier nights remain recorded; credit resumes next night |
| P13 | Everyone leaves (Abandoned) | already earned nights are kept; no bonus |
| P14 | `PEARL_PAYOUT_MODE = "legacy"` | exactly today's end-of-run behaviour |
| C1-C4 | crew cap acceptance criteria 1-3 in `CREW_CAP_AND_FUEL_DESIGN.md` | pass |
| F1 | Fuel multiplier for crew 1..4 with 0, 2 and 4 extra non-crew players connected | multiplier depends only on crew size |
| V1-V6 | acceptance criteria 1-6 in `VALIDATION_IMPROVEMENTS.md` | pass |
| R1 | Regression pass in E1: run to Night 1 with a 1-player crew, buy an item, equip, take the lamp, refuel, repair, leave, results, rematch | no console errors; same behaviour as before the change |

Not covered by any of the above and still required later: nights 2-13, boss nights, a real phone, a controller, and real two-server timing (E2).

## 4. Evidence that each test must leave
Test id, environment, number of logical servers/clients, the exact fake-backend settings (latency, failures), steps, expected and actual result, relevant console lines, pass/fail, and whether the test could have touched production data (answer must be "no" for every row). Emulated or simulated tests are labelled as such; nothing in E0/E1 is described as a real-player or real-phone test.

## 5. Preconditions the owner controls
- Open the scratch copy in its own Studio window (TASK-001 follow-up), close it afterwards.
- Decide whether to create the E2 test experience.
- Approve the implementation plan before any test code is added anywhere.
=== END FILE ===

=== FILE: TASK-003/IMPLEMENTATION_PLAN.md ===
# Implementation plan (TASK-003) — PLAN ONLY, NOT APPROVED, NOT STARTED

Nothing here is authorized. Each batch needs the owner's explicit approval and a TASK package after it. Line numbers refer to the version-148 export.

## Common procedure for every batch
1. Verify the target Studio instance by place ID 132065051336560 again (list instances first), and confirm Outlaw City is untouched.
2. Before editing: owner saves a fresh local `.rbxl` (File > Save to File, not Publish); copy the touched scripts into `ServerStorage.Backups.<Batch>_before_<date>`; keep `src\` snapshot.
3. Make the smallest change, parse-check every touched script, test in the scratch copy / harness first, then only safe checks in the live Edit window (no Play against the live DataStore unless the owner accepts that it counts as a real run on their account).
4. Revert temporary test settings, update `IMPLEMENTATION_LOG.md` and `progress.md`, build the audit package, tell the owner to republish manually.

## Batch 1: save integrity (needs approval: persistence and a new saved field)
- Files: `ServerScriptService\Server\PlayerData.luau` (all logic); `Shared\Config.luau` (new flags `SAVE_LOCKING_ENABLED`, `SAVE_LOCK_TTL`); optionally a new `Server\SaveBackend.luau` for the fake/real backend interface.
- Content: design in `SAVE_ARCHITECTURE_AND_MIGRATION.md` (lock fields `_session`, `_rev`, dirty counter, leave retry, parallel shutdown save, boot probe retry, honour `doNotSave` inside `save`). Also fixes SEC-10, SEC-13 (LoadoutService memory growth is a separate small item), and the GP-27 failed-load warning to the player can be added here.
- Acceptance: tests S1-S14 pass in E0 and E1; flag off equals current behaviour; no change to the profile shape players see; owner confirms the lock-conflict kick message wording.
- Compatibility checks: old record shapes load (S11), old code reads new records (S12).
- Rollback: flag off, or republish the previous version. Never restore a backup over saves.
- Owner approvals needed: adding saved fields, the lock-conflict kick behaviour, Option B versus Option A.

## Batch 2: reward fairness, crew cap, crew fuel (needs approval: rewards, difficulty, new Config)
- Files: `GameState.luau` (roster snapshot at night start, per-night credit near `:463-465`, end-of-run section `:503-524`, `resetRound` ledger), `Main.server.luau` (`joinCrew` cap and phase guard `:646-657`, `PlayerRemoving` ledger update `:545-555`, first-voyage fallback), `PlayerData.luau` (`grantPearlsOnce`, `recordRun` rule), `LampService.luau:284` (crew count), `Shared\Config.luau` (`MAX_CREW`, `PEARL_PAYOUT_MODE`, `PEARLS_BONUS_MIN_NIGHTS`), `EventLog.luau` only if the results shape needs the per-player Pearl map.
- Acceptance: scenario table in `PEARL_ELIGIBILITY_DESIGN.md`, crew cap and fuel criteria, tests P1-P14, C1-C4, F1.
- Compatibility: Results client reads `results.pearls[player.Name]` unchanged; coach/first-voyage logic reads `RunsCompleted`; `"legacy"` mode keeps today's payout.
- Rollback: `PEARL_PAYOUT_MODE = "legacy"`, `MAX_CREW = 99`.
- Owner approvals: reward eligibility rule and bonus minimum, crew cap behaviour, fuel scaling change (easier on busy servers), whether leavers count as a played run.

## Batch 3: validation hardening (needs approval only where it changes gameplay feel)
- Files: `Main.server.luau` (oil/refuel/BuyUpgrade/Attack handlers), `TowerService.luau` (repair prompt), `LootService.luau:233-241` (crew-only), `PlayerData.luau:310-316` (sync throttle).
- Acceptance: V1-V6 and R1.
- Rollback: revert the batch (each change is local to a handler).
- Owner approvals: crew-only loot (a non-crew player can no longer pick up drops) and, if added later, the movement sanity check.

## Suggested order and why
Batch 1 first (it protects everything else and every later reward), then Batch 2, then Batch 3. Batch 3 items are small and independent, so they could ship earlier if the owner prefers. The boss redesign and merchant stay blocked until these are done and playtested.

## Open points the owner must settle before Batch 1 starts
1. Option B (recommended) versus Option A (library).
2. Whether a lock-conflict kick is acceptable.
3. Whether to create the separate test experience (E2) for true two-server tests.
=== END FILE ===

=== FILE: TASK-003/CODE_EXTRACTS.md ===
# Relevant code extracts (TASK-003)

Verbatim excerpts of the version-148 export in `src\ServerScriptService\Server\`, with original line numbers. Generated mechanically from the files on disk; nothing edited.

## PlayerData.luau lines 20-28
```lua
  20: local STORE_NAME = "LighthouseKeepers_PlayerData_v1"
  21: local SCHEMA_VERSION = 1
  22: local AUTOSAVE_SECONDS = 60
  23: 
  24: local store = nil
  25: local storeAvailable = false
  26: local profiles = {} -- player -> profile table
  27: local dirty = {} -- player -> true when unsaved changes exist
  28: local remotes
```

## PlayerData.luau lines 33-50
```lua
  33: local function newProfile()
  34: 	local profile = {
  35: 		version = SCHEMA_VERSION,
  36: 		pearls = Config.DEV_START_PEARLS or 0,
  37: 		owned = {}, -- itemId -> true (weapons and armor)
  38: 		counts = {}, -- itemId -> number (ammo crates and materials)
  39: 		equippedArmor = "OilskinCoat",
  40: 		equippedWeapon = "DriftwoodHarpoon",
  41: 		equippedBeam = "BeamAmber", -- beam colour (launch R15, owner-approved). Old saves get this default.
  42: 		stats = { runs = 0, victories = 0, bestNight = 0 },
  43: 	}
  44: 	for id, item in Items do
  45: 		if type(item) == "table" and item.starter then
  46: 			profile.owned[id] = true
  47: 		end
  48: 	end
  49: 	return profile
  50: end
```

## PlayerData.luau lines 52-59
```lua
  52: -- Fills in anything missing from older saves
  53: local function reconcile(profile)
  54: 	local template = newProfile()
  55: 	for key, value in template do
  56: 		if profile[key] == nil then
  57: 			profile[key] = value
  58: 		end
  59: 	end
```

## PlayerData.luau lines 96-150
```lua
  96: local function markChanged(player)
  97: 	dirty[player] = true
  98: 	push(player)
  99: end
 100: 
 101: local function save(player)
 102: 	local profile = profiles[player]
 103: 	if not profile or not storeAvailable or not dirty[player] then
 104: 		return
 105: 	end
 106: 	local ok, err = pcall(function()
 107: 		store:UpdateAsync(keyFor(player), function()
 108: 			return profile
 109: 		end)
 110: 	end)
 111: 	if ok then
 112: 		dirty[player] = nil
 113: 	else
 114: 		warn("PlayerData: save failed for " .. player.Name .. ": " .. tostring(err))
 115: 	end
 116: end
 117: 
 118: local function load(player)
 119: 	local profile
 120: 	if storeAvailable then
 121: 		for attempt = 1, 3 do
 122: 			local ok, result = pcall(function()
 123: 				return store:GetAsync(keyFor(player))
 124: 			end)
 125: 			if ok then
 126: 				profile = if result then reconcile(result) else newProfile()
 127: 				break
 128: 			end
 129: 			warn(string.format("PlayerData: load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
 130: 			task.wait(attempt)
 131: 		end
 132: 		if not profile then
 133: 			-- Never overwrite a real save with a blank one: play in memory this session
 134: 			warn("PlayerData: could not load " .. player.Name .. "; progress this session will NOT be saved.")
 135: 			profile = newProfile()
 136: 			profile.doNotSave = true
 137: 		end
 138: 	else
 139: 		profile = newProfile()
 140: 	end
 141: 	if player.Parent ~= Players then
 142: 		return -- left while loading
 143: 	end
 144: 	profiles[player] = profile
 145: 	-- Read-only signals for the first-voyage route and coach (launch R2/R3). Nothing new is saved.
 146: 	-- "failed" = the save couldn't be read: never treat that player as new, never save over them.
 147: 	player:SetAttribute("RunsCompleted", if profile.doNotSave then -1 else profile.stats.runs)
 148: 	player:SetAttribute("ProfileState", if profile.doNotSave then "failed" elseif storeAvailable then "saved" else "memory")
 149: 	push(player)
 150: end
```

## PlayerData.luau lines 287-349
```lua
 287: function PlayerData.init(remoteFolder, notify)
 288: 	remotes = remoteFolder
 289: 
 290: 	local ok, result = pcall(function()
 291: 		local s = DataStoreService:GetDataStore(STORE_NAME)
 292: 		s:GetAsync("__access_check")
 293: 		return s
 294: 	end)
 295: 	if ok then
 296: 		store = result
 297: 		storeAvailable = true
 298: 	else
 299: 		warn("PlayerData: DataStores unavailable (" .. tostring(result) .. "). Progress is kept in memory only. In Studio, enable Game Settings > Security > Enable Studio Access to API Services.")
 300: 		-- the HUD shows a "progress isn't saving" warning to players
 301: 		local Players = game:GetService("Players")
 302: 		for _, p in Players:GetPlayers() do
 303: 			p:SetAttribute("SaveUnavailable", true)
 304: 		end
 305: 		Players.PlayerAdded:Connect(function(p)
 306: 			p:SetAttribute("SaveUnavailable", true)
 307: 		end)
 308: 	end
 309: 
 310: 	remotes.GearAction.OnServerEvent:Connect(function(player, action)
 311: 		-- The only client request handled here: "send me my data".
 312: 		-- Buying/selling go through ShopService (Quartermaster); equipping through LoadoutService.
 313: 		if action == "sync" then
 314: 			push(player)
 315: 		end
 316: 	end)
 317: 	local lastAction = {} -- (kept for cleanup on leave)
 318: 
 319: 	Players.PlayerAdded:Connect(load)
 320: 	for _, player in Players:GetPlayers() do
 321: 		task.spawn(load, player)
 322: 	end
 323: 	Players.PlayerRemoving:Connect(function(player)
 324: 		local profile = profiles[player]
 325: 		if profile and not profile.doNotSave then
 326: 			save(player)
 327: 		end
 328: 		profiles[player] = nil
 329: 		dirty[player] = nil
 330: 		lastAction[player] = nil
 331: 	end)
 332: 	game:BindToClose(function()
 333: 		for player, profile in profiles do
 334: 			if not profile.doNotSave then
 335: 				save(player)
 336: 			end
 337: 		end
 338: 	end)
 339: 	task.spawn(function()
 340: 		while true do
 341: 			task.wait(AUTOSAVE_SECONDS)
 342: 			for player, profile in profiles do
 343: 				if not profile.doNotSave then
 344: 					task.spawn(save, player)
 345: 				end
 346: 			end
 347: 		end
 348: 	end)
 349: end
```

## GameState.luau lines 101-109
```lua
 101: 	local function readyPlayers()
 102: 		local list = {}
 103: 		for _, player in Players:GetPlayers() do
 104: 			if player:GetAttribute("Ready") then
 105: 				table.insert(list, player)
 106: 			end
 107: 		end
 108: 		return list
 109: 	end
```

## GameState.luau lines 408-412
```lua
 408: 					end
 409: 					local stopWave = startWave(crabCount, Config.NIGHT_SECONDS * Config.SPAWN_WINDOW)
 410: 					local crewSize = math.clamp(#readyPlayers(), 1, 4)
 411: 					local crewShare = (Config.SWARM_BY_CREW and Config.SWARM_BY_CREW[crewSize]) or 1
 412: 					local swarmCount = math.floor(((Config.SWARM_BASE or 0) + (Config.SWARM_PER_NIGHT or 0) * growth) * crewShare * (state:GetAttribute("ForecastCrabMult") or 1) + 0.5)
```

## GameState.luau lines 463-465
```lua
 463: 					local bonus = if Config.ECONOMY_ENABLED then Config.WAVE_BONUS_PER_NIGHT * night else 0
 464: 					upgrades.addShells(bonus)
 465: 					EventLog.log("NightSurvived", { night = night, bonus = bonus, fuel = math.floor(lamp.getFuel()), tower = state:GetAttribute("Integrity") })
```

## GameState.luau lines 503-524
```lua
 503: 			local voters = readyPlayers()
 504: 
 505: 			-- Pearl rewards (saved, personal): PEARLS_PER_NIGHT per night survived (+ the old triangular
 506: 			-- step if PEARLS_NIGHT_STEP > 0), plus PEARLS_VICTORY_BONUS for a win. 13-night win = 18.
 507: 			results.pearls = {}
 508: 			if result ~= "Abandoned" then
 509: 				local survived = if result == "Victory" then Config.NIGHTS_TO_WIN else math.max(0, results.nightReached - 1)
 510: 				for _, player in voters do
 511: 					local earned = (Config.PEARLS_PER_NIGHT or 0) * survived + (Config.PEARLS_NIGHT_STEP or 0) * survived * (survived + 1) / 2
 512: 					if result == "Victory" then
 513: 						earned += Config.PEARLS_VICTORY_BONUS
 514: 					end
 515: 					for _, award in results.awards do
 516: 						if award.player == player.DisplayName then
 517: 							earned += Config.PEARLS_PER_AWARD
 518: 						end
 519: 					end
 520: 					deps.playerData.addPearls(player, earned, "run")
 521: 					deps.playerData.recordRun(player, result == "Victory", results.nightReached)
 522: 					results.pearls[player.Name] = earned
 523: 				end
 524: 			end
```

## LampService.luau lines 283-285
```lua
 283: 		-- Smaller crews burn less fuel
 284: 		local crewSize = math.clamp(#Players:GetPlayers(), 1, #Config.FUEL_DRAIN_BY_CREW_SIZE)
 285: 		rate *= Config.FUEL_DRAIN_BY_CREW_SIZE[crewSize]
```

## LampService.luau lines 380-392
```lua
 380: 
 381: 	local function aliveCrew(p)
 382: 		local humanoid = getHumanoid(p)
 383: 		return p.Parent == Players and p:GetAttribute("Ready") == true and humanoid ~= nil and humanoid.Health > 0
 384: 	end
 385: 
 386: 	local function offerShift()
 387: 		if not Config.LAMP_SHIFT_ENABLED or pending then
 388: 			return
 389: 		end
 390: 		local candidate
 391: 		for _, p in Players:GetPlayers() do
 392: 			if p ~= keeper and not heldThisRun[p] and aliveCrew(p) then
```

## Main.server.luau lines 69-71
```lua
  69: refs.upgradePrompt.Triggered:Connect(function(player)
  70: 	remotes.OpenUpgrades:FireClient(player)
  71: end)
```

## Main.server.luau lines 116-145
```lua
 116: remotes.BuyUpgrade.OnServerEvent:Connect(function(player, id, requestId)
 117: 	if typeof(id) ~= "string" then
 118: 		return
 119: 	end
 120: 	if requestId ~= nil and (typeof(requestId) ~= "string" or #requestId > 40) then
 121: 		return
 122: 	end
 123: 	local now = os.clock()
 124: 	if (lastBuy[player] or 0) + 0.3 > now then
 125: 		if requestId then
 126: 			remotes.UpgradeResult:FireClient(player, requestId, false, "One upgrade at a time. Try again.", id)
 127: 		end
 128: 		return -- ignore double-clicks
 129: 	end
 130: 	lastBuy[player] = now
 131: 	local ok, message = UpgradeService.buy(id)
 132: 	if requestId then
 133: 		remotes.UpgradeResult:FireClient(player, requestId, ok, message, id)
 134: 	end
 135: 	if ok then
 136: 		EventLog.upgrade(id, UpgradeService.getLevel(id))
 137: 		EventLog.log("UpgradeBought", { player = player.Name, id = id, level = UpgradeService.getLevel(id) })
 138: 		local benchPart = refs.upgradePrompt.Parent
 139: 		if benchPart then
 140: 			SoundFx.playAt("build", benchPart.Position)
 141: 		end
 142: 		remotes.Notify:FireAllClients(player.DisplayName .. ": " .. message)
 143: 	elseif not requestId then
 144: 		LampService.notify(player, message) -- the bench UI shows the reason itself
 145: 	end
```

## Main.server.luau lines 204-231
```lua
 204: refs.oilPrompt.Triggered:Connect(function(player)
 205: 	if player:GetAttribute("CarryingOil") then
 206: 		LampService.notify(player, "You're already carrying oil. Take it to the fuel tank by the lighthouse.")
 207: 		return
 208: 	end
 209: 	giveOil(player)
 210: 	EventLog.mark(player, "firstAction")
 211: 	EventLog.count("oilGrabbed", 1, player)
 212: 	EventLog.first("oil pickup")
 213: 	EventLog.log("OilGrabbed", { player = player.Name })
 214: end)
 215: 
 216: refs.fuelPrompt.Triggered:Connect(function(player)
 217: 	if not player:GetAttribute("CarryingOil") then
 218: 		LampService.notify(player, "Grab oil from the barrels on the island first.")
 219: 		return
 220: 	end
 221: 	if LampService.getFuel() >= LampService.getMaxFuel() then
 222: 		LampService.notify(player, "The tank is already full.")
 223: 		return
 224: 	end
 225: 	local fuelBefore = LampService.getFuel()
 226: 	removeCarriedOil(player)
 227: 	LampService.addFuel(Config.FUEL_PER_REFILL)
 228: 	EventLog.count("refuels", 1, player)
 229: 	EventLog.first("lamp refuel")
 230: 	EventLog.log("Refueled", { player = player.Name, fuelBefore = math.floor(fuelBefore) })
 231: 	EventLog.mark(player, "fuel")
```

## Main.server.luau lines 498-533
```lua
 498: remotes.Attack.OnServerEvent:Connect(function(player, target)
 499: 	-- Validate everything the client sends
 500: 	if typeof(target) ~= "Vector3" or target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
 501: 		return
 502: 	end
 503: 	if LampService.getKeeper() == player then
 504: 		return
 505: 	end
 506: 	local character = player.Character
 507: 	local root = character and character:FindFirstChild("HumanoidRootPart")
 508: 	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 509: 	if not root or not humanoid or humanoid.Health <= 0 then
 510: 		return
 511: 	end
 512: 
 513: 	-- The server decides which weapon is used: whatever the player actually has equipped
 514: 	local tool = character:FindFirstChildOfClass("Tool")
 515: 	local weaponId = tool and tool:GetAttribute("WeaponId")
 516: 	local weapon = weaponId and Weapons[weaponId]
 517: 	if not weapon then
 518: 		return
 519: 	end
 520: 
 521: 	local now = os.clock()
 522: 	if (lastAttack[player] or 0) + weapon.cooldown > now then
 523: 		return
 524: 	end
 525: 	lastAttack[player] = now
 526: 
 527: 	-- Clamp to the weapon's range
 528: 	local offset = target - root.Position
 529: 	if offset.Magnitude > weapon.range then
 530: 		target = root.Position + offset.Unit * weapon.range
 531: 	end
 532: 
 533: 	local hits = CreatureService.damageArea(target, weapon.hitRadius, weapon.damage, weapon.maxTargets, "Weapon:" .. weaponId, player)
```

## Main.server.luau lines 545-555
```lua
 545: Players.PlayerRemoving:Connect(function(player)
 546: 	lastAttack[player] = nil
 547: 	lastBuy[player] = nil
 548: 	-- Playtest analytics: someone leaving in the middle of a run
 549: 	local phase = stateFolder:GetAttribute("Phase")
 550: 	EventLog.playerLeft(player, if not player:GetAttribute("InLobby") then "title" elseif not player:GetAttribute("Ready") then "harbor" else phase)
 551: 	if player:GetAttribute("Ready") and (phase == "Prologue" or phase == "Day" or phase == "Night") then
 552: 		EventLog.count("quits")
 553: 		EventLog.log("PlayerQuit", { player = player.Name, phase = phase, night = stateFolder:GetAttribute("Night") })
 554: 	end
 555: end)
```

## Main.server.luau lines 646-672
```lua
 646: local function joinCrew(player, via)
 647: 	local phase = stateFolder:GetAttribute("Phase")
 648: 	player:SetAttribute("Ready", true)
 649: 	EventLog.log("PlayerReady", { player = player.Name, via = via })
 650: 	EventLog.mark(player, "crew")
 651: 	if RUN_PHASES[phase] then
 652: 		LampService.notify(player, "You joined the crew mid-voyage! Rowing you to the island...")
 653: 		sendToIsland(player)
 654: 	else
 655: 		LampService.notify(player, if via == "first voyage" then "The storm is coming. The light needs a keeper: the ship sets sail soon." else "You joined the crew! The ship sets sail soon.")
 656: 	end
 657: end
 658: 
 659: -- The ship's wheel: join or leave the crew
 660: lobbyRefs.helmPrompt.Triggered:Connect(function(player)
 661: 	if not player:GetAttribute("InLobby") then
 662: 		return
 663: 	end
 664: 	local phase = stateFolder:GetAttribute("Phase")
 665: 	if player:GetAttribute("Ready") then
 666: 		player:SetAttribute("Ready", false)
 667: 		LampService.notify(player, "You left the crew. Use the wheel again to rejoin.")
 668: 		EventLog.log("LeftCrew", { player = player.Name })
 669: 	else
 670: 		joinCrew(player, "wheel")
 671: 	end
 672: end)
```

## LootService.luau lines 126-127
```lua
 126: 		if math.random() < Config.BOSS_PEARL_CHANCE then
 127: 			spawnDrop("Pearls", math.random(Config.BOSS_PEARL_MIN, Config.BOSS_PEARL_MAX), position)
```

## LootService.luau lines 150-160
```lua
 150: local function collect(index, player)
 151: 	local drop = drops[index]
 152: 	local info = KINDS[drop.kind]
 153: 	if info.pearls then
 154: 		-- Permanent currency straight into this player's saved Pearls
 155: 		playerData.addPearls(player, drop.value, "boss drop")
 156: 		EventLog.log("BossPearls", { player = player.Name, amount = drop.value })
 157: 		remotes.LootCollected:FireClient(player, drop.kind, drop.value)
 158: 		remotes.Notify:FireAllClients(string.format("%s picked up %d Pearls from the monster!", player.DisplayName, drop.value))
 159: 		removeAt(index)
 160: 		return
```

## LootService.luau lines 231-258
```lua
 231: 	-- Collect living players' positions once per frame
 232: 	local players = {}
 233: 	for _, player in Players:GetPlayers() do
 234: 		local character = player.Character
 235: 		local root = character and character:FindFirstChild("HumanoidRootPart")
 236: 		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 237: 		if root and humanoid and humanoid.Health > 0 then
 238: 			table.insert(players, { player = player, position = root.Position })
 239: 		end
 240: 	end
 241: 
 242: 	local now = os.clock()
 243: 	for index = #drops, 1, -1 do
 244: 		local drop = drops[index]
 245: 		if now - drop.bornAt > Config.LOOT_LIFETIME then
 246: 			removeAt(index)
 247: 		elseif drop.landed then
 248: 			-- Find the nearest player within magnet range
 249: 			local nearest, nearestDistance = nil, Config.LOOT_MAGNET_RADIUS
 250: 			for _, entry in players do
 251: 				local distance = (entry.position - drop.position).Magnitude
 252: 				if distance < nearestDistance then
 253: 					nearest, nearestDistance = entry, distance
 254: 				end
 255: 			end
 256: 
 257: 			if nearest and nearestDistance <= Config.LOOT_PICKUP_RADIUS then
 258: 				collect(index, nearest.player)
```

## TowerService.luau lines 26-38
```lua
  26: 	repairPrompt.Triggered:Connect(function(player)
  27: 		if integrity >= maxIntegrity then
  28: 			notify(player, "The tower is already in good shape.")
  29: 			return
  30: 		end
  31: 		-- evolution (Shared.Upgrades.EVOLUTIONS): Clockwork Bastion restores 50% more per repair
  32: 		TowerService.repair(Config.REPAIR_AMOUNT * (if state:GetAttribute("Evo_ClockworkBastion") then 1.5 else 1))
  33: 		EventLog.count("repairs", 1, player)
  34: 	EventLog.mark(player, "repair")
  35: 		EventLog.first("repair")
  36: 		EventLog.log("Repaired", { player = player.Name, integrity = math.ceil(integrity) })
  37: 		SoundFx.playAt("repair", repairPrompt.Parent.Position)
  38: 	end)
```

=== END FILE ===

