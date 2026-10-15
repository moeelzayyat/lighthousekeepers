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
