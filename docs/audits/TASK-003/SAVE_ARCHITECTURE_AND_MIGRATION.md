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
