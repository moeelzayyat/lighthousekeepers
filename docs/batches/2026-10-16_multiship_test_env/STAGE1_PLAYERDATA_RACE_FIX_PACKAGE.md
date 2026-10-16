# PlayerData race fixes A and B (test branch), 2026-10-16

**Scope:** LK Multiship Test only (GameId 10771229467, Harbor 125998212495899; asserted before every Studio action).
- Branch `multiship-test`. The edit was made in the test Harbor window and is **not published**.
- **No real DataStore writes:** every test used an in-memory fake store, and Studio API access stayed **off**.
- No teleports and no publishing. Production Lighthouse Keepers, SaveTest and Outlaw City were untouched.
- The Stage 1 evidence and the synthetic 25-Pearl profile were preserved (never read or written).
- **Studio backup:** `ServerStorage.Backups.RaceFix_before_2026-10-16` (PlayerData before the fix, `f00636f6…`).
- **Exact diff:** `PLAYERDATA_RACE_FIX.diff`, PlayerData only. Config and SessionLock are unchanged.

## Fix A: PlayerRemoving during an in-flight claim
- `load()` marks `loading[player]`, and `PlayerData._onRemoving` sets `leftDuringLoad[player]` if the claim is still running.
- When the claim then **succeeds** for a player who has left, `load()` calls `releaseAbandoned(player, value)`. It releases the new lock with the claimed value unchanged, retrying up to 3 times.
- It stops retrying early if the lock is no longer ours.
- If every retry fails, it warns and leaves the session to the normal stale takeover. The lock is never silently abandoned, and `load()` never crashes.
- A **failed** claim for a leaving player writes nothing and leaves the other server's lock untouched.
- **Leave order changed:** `_onRemoving` now detaches the profile (`profiles[player] = nil`) **before** the final release, so no mutation can slip in after the last write. The release writes the latest state.

## Fix B: changes during an in-flight save
- `markChanged` bumps a per-player **mutation generation**.
- `save()` records the generation and writes a **snapshot** (deep copy) taken at its start.
- On success it clears `dirty` only if the generation has not moved. A change made during the save stays dirty, and the next save writes it. So does the release on leave or hand-off, which writes the live profile.
- The same check applies to the unlocked path.

## Tests: 15 / 15 PASS
These ran deterministically in a fake store with Roblox `UpdateAsync` semantics: a nil return cancels the write, values are serialized on commit, and failures can be injected. A **gate** holds any chosen call in flight until the test opens it. Every scenario used a fresh isolated copy of PlayerData, SessionLock and EventLog with stand-in players.

| # | Scenario | Result |
|---|---|---|
| A1 | Player leaves mid-claim; the claim then succeeds | Key created, **lock released** (no session), not owned, no profile kept: PASS |
| A2 | Player leaves while a claim that will **fail** is in flight (another server holds the key) | Foreign lock and value untouched, nothing owned: PASS |
| A3 | Late success, then the first release attempt fails | Retry releases the lock: PASS |
| A4 | Late success, then **all** release attempts fail | `load` returns cleanly, profile not kept, session left for stale takeover (reported): PASS |
| A5 | Overlapping cleanup (PlayerRemoving twice) during an in-flight claim | One clean release, nothing owned: PASS |
| B1 | +10 → save in flight → +5 during it → save completes | Stored 10 and **dirty stays**: PASS. The next save stores **15** and clears dirty: PASS |
| B2 | The same race, then the player **leaves** | Release wrote **15**, session cleared: PASS |
| B3 | The same race, then a **hand-off** | Released with **15**, frozen: PASS. A mutation while frozen is refused (still 15): PASS. Reclaim reloads 15 under a new lock: PASS |
| R1 | Regression **claim** | New key, default profile, committed token, ProfileState `saved`: PASS |
| R2 | Regression **save** | 25 under the same token, dirty cleared: PASS |
| R3 | Regression **heartbeat** | `at` advances, value unchanged: PASS |
| R4 | Regression **release** on leave | Session cleared, 25 kept, not owned: PASS |

- **Not demonstrated:** the races failing on the **old** code. Running the old module needs the same test seam, which it doesn't have. The defects come from the auditor's code review, and the new tests target exactly those paths.
- SessionLock is unchanged (`07929579…`), so its earlier 22/22 suite still applies.

## Final state (verified in Studio)
| Item | Value |
|---|---|
| `Server.PlayerData` | `8016ca583ae9b7aee2483059bccedd835288e4f6273185a8ae00fa0d2ec74fd8` (Studio = git) |
| `Shared.Config` | `27661b7af8e155a657d00d3c7ea216001406506d633b867a65c99854f1458078` (unchanged) |
| `Server.SessionLock` | `07929579491e0814dbeddaaad594d071a74ffbedb0c9a93eb0d67540a7f291a1` (unchanged) |
| Switches | `multiShip = false`, `sessionLock = false`, `teleport = false` |
| Studio API access (test experience) | off |

The test seam `PlayerData._test` is only reachable from Studio scripts; the game never calls it. It does not exist on `main`.

## Recommended minimum next step toward the first real Harbor → Isle voyage
**Stage 2: one Ship1 crew, one voyage, in the test experience.** It needs the owner's approval of the exact scope.
1. **Owner publishes the current test build to both test places.** For each, I first verify the window's GameId and PlaceId.
   - Harbor 125998212495899: File > Publish to Roblox.
   - Isle 111423375237885: Publish to Roblox As… > LK Multiship Test > Lighthouse Isle.
2. **Switches on:** `multiShip`, `sessionLock` and `teleport` = true, test branch only. Then republish both places.
3. **One live voyage**, by the owner on his account, with the experience still Private:
   - Board Ship1 and press SAIL NOW, which teleports to an Isle server.
   - Play the Prologue, then choose Results → back to harbor.
   - Check with uncached reads of `LKMS_TEST_PlayerData_v1` that the save stayed locked by exactly one server at a time and that Pearls persisted.
4. Two ships with two crews (a second account) and a forced-failure test come **after** that single voyage passes.
