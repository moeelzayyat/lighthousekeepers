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
