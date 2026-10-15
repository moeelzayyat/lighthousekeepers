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
