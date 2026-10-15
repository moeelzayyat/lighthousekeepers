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
