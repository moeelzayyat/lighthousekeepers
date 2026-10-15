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
