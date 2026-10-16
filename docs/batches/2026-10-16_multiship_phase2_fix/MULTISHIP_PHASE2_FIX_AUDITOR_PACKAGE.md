# Auditor package: multi-ship phase 2 corrective batch, 2026-10-16

- **Target:** PlaceId `132065051336560`, GameId `10769064643`. Studio only. **Not published.**
- **Boundaries kept:**
  - `MULTI_SHIP_ENABLED`, `TELEPORT_ENABLED` and the new `ISLE_STUDIO_TEST` are all **false**.
  - SessionLock is **not** wired into PlayerData.
  - No DataStore or MemoryStore operation, no teleport, no place created, nothing published.
  - SaveTest and Outlaw City untouched.
- **Responds to:** the auditor's phase 2 verdict, required fixes 1–3.
- **Backups:**
  - Place: `backups\2026-10-16\LighthouseKeepers_2026-10-16_v161_pre-phase2fix.rbxl`, SHA-256 `b8af8930f27d19e642d3213d125b2f719550a21b635570016253b226e658dfb5`. Its Rojo export equals the pre-fix sources.
  - Scripts: `ServerStorage.Backups.Phase2Fix_before_2026-10-16`, plus `before\`.

## Exact diffs
See `PHASE2_FIX_DIFFS.diff`, plus full `before\` and `after\` copies of `SessionLock`, `IsleAdmission`, `Voyages`, `HarborDepartures`, `Main` and `Config`.

## Fix 1: SessionLock new-key defect
- **Defect, reproduced:** the old `claim()` returned `current` from the transform. For a brand-new key that is nil, so Roblox **cancels** the write. The old code still reported `true`, because `pcall` succeeded.
  - The test running the old module from the Studio backup confirms it: "success reported, nothing stored".
- **Change:**
  - `claim(key, defaultValue)` creates a brand-new key with the caller's default profile. Without a default it refuses with "no profile to create".
  - **Success is confirmed against the committed metadata** that `UpdateAsync` returns (its second value, DataStoreKeyInfo): the stored `session.token` must equal ours. `pcall` success alone is never enough.
  - The transform recomputes all its state (`busy`, `value`, `lost`) on every invocation, so re-invocation is safe.
  - A retried claim recognises **every token it already tried**. An attempt that committed and then errored is therefore re-owned, instead of being mistaken for a foreign lock and waited out until it goes stale.
  - `save`, `heartbeat` and `release` are also confirmed against the committed metadata: "save not confirmed" or "release not confirmed" otherwise.
- **Tests: 22 of 22 PASS.** These ran against a fake store with Roblox semantics: a nil return cancels the write, the transform can be re-invoked with the record changing between invocations, there are failures before commit and after commit, and the committed keyInfo is returned.

| Check | Result |
|---|---|
| OLD module: brand-new key reports success but nothing is stored (defect reproduced) | PASS |
| New key without a default profile is refused and nothing is stored | PASS |
| New key with a default: claimed, profile stored | PASS |
| **Proof:** the stored metadata `session.token` equals this server's token | PASS |
| Owner can save on the new key | PASS |
| Two servers claim the same **missing** key at once: exactly one wins | PASS |
| The stored token is the winner's, and only the winner owns it | PASS |
| The loser reports "locked by another server" | PASS |
| Re-invocation (foreign lock on the first call, free on the re-run): confirmed on the committed run | PASS |
| Existing value, metadata field and UserIds preserved | PASS |
| Re-invocation (free on the first call, foreign lock on the re-run): **not** reported as a claim | PASS |
| Two failed responses (not committed), then the retry stores the lock | PASS |
| Committed-but-errored attempt: the retry re-claims its own lock | PASS (this check caught a bug in my first version of the fix, which overwrote the earlier token; fixed) |
| Save committed-but-errored: reported as a store error, ownership kept | PASS |
| Release clears the session and is confirmed | PASS |
| Regression of the phase 2 behaviours: owner/non-owner, heartbeat, live lock, stale takeover and fencing, release then re-claim, autosave/release/late-save serialization, old-server write fences the new owner | 7 / 7 PASS |

## Fix 2: Isle manifest safety
- **`IsleAdmission.validate(manifest, privateServerId, capacity, now)`** requires:
  - a table whose `privateServerId` equals this reserved server's (a server with an empty `PrivateServerId` can never match);
  - `createdAt` no older than 600 s and not more than 60 s in the future;
  - 1 to capacity (4) **distinct positive integer** UserIds.
- **Fail closed:** in any live isle server, a missing, expired, malformed or foreign manifest gives `closed`. No voyage starts, and everyone who joins is sent back to the harbor.
- **Studio only:** the manifest-free simulation runs **only** when `Config.ISLE_STUDIO_TEST == true` **and** `RunService:IsStudio()`.
- **Who sails:**
  - Only listed UserIds can be crew.
  - The voyage starts when every listed player has arrived, or 20 s after the first arrival with whoever is there (fewer than four is allowed, per the auditor's decision).
  - With zero arrivals, no voyage starts.
- **After the freeze:**
  - Every later arrival, listed or not, is turned away (`IsleLate`) and never set Ready, so it gets no run rewards.
  - A listed player who is present but not admitted at departure is turned away too.
  - Play Again is only for the crew already in the server.
- **The manifest lists only travellers whose save hand-off succeeded:** Voyages writes it **after** the hand-offs, with `privateServerId` included.
- **Tests: 23 of 23 PASS.** They cover:
  - validation of a good manifest and of each failure: missing, other server, expired, no createdAt, empty crew, 5 > 4, duplicate UserId, non-number, negative or fractional UserId, empty server id;
  - a live server with no manifest (closed, player sent back, no voyage);
  - a live server with another server's manifest (closed);
  - Studio test mode allowed;
  - an unlisted player turned away;
  - **one missing player:** 2 of 3 arrive, no start before 20 s, then a start with exactly P1 and P2;
  - **a late listed arrival** after the freeze, turned away and never Ready;
  - no second voyage without Play Again; Play Again for the present crew only;
  - all listed players arriving gives an immediate start;
  - **zero arrivals** gives no voyage even after the wait;
  - a listed player not ready at departure does not sail and is sent back.

## Fix 3: Failed-departure recovery
- **A ship never stays locked:** HarborDepartures runs `launch` in its own thread and unlocks the ship when it returns, errors or exceeds `LAUNCH_TIMEOUT` (30 s).
- **No duplicate launch:** at launch every crew member leaves the ship's party and is marked `InTransit`. ShipBoarding's `canBoard` refuses `InTransit` players, so the same players can never be counted or launched twice, and the ship can take a new crew at once.
- **Membership on failure:** a failed traveller is **removed** from the party, not restored, because the ship may already have a new crew. They stay in the harbor and can board again.
- **No profile changes while ownership is released:**
  - Voyages calls `playerData.handoff` (an awaited final save plus release) before anything leaves the server, and does nothing to the profile until `reclaim`.
  - SessionLock refuses every write after release ("not owned"; tested in fix 1).
  - The contract for the future PlayerData wiring is that `handoff` freezes in-memory mutations until `reclaim` succeeds. That wiring is not part of this batch.
- **A failed traveller needs a successful re-claim before playing on:**
  - When `reclaim` succeeds, `InTransit` is cleared and the player is told to board again.
  - When `reclaim` fails, the player is **disconnected** with "Your progress is saved: please rejoin", so they never play without an owned save session.
- **Failure handled once:** a pcall error and a later `TeleportInitFailed` for the same player cause a single recovery, because the `InTransit` guard stops the second.
- **Tests: 13 of 13 PASS.** These ran the real `Voyages._teleport` with fake reserve, manifest, teleport and save-adapter services and a real ShipRoster copy, plus real `HarborDepartures` copies.
  - Full success: the manifest is exactly the travellers and the server id, one teleport, everyone out of the party and InTransit.
  - One hand-off fails: the manifest has only the 2 who handed off, the teleport carries only them, and the failed player re-claimed, is out of the party, has InTransit cleared and was notified.
  - Teleport error: both travellers re-claim once, are out of the party and have InTransit cleared.
  - ReserveServer error: no teleport, no manifest, both recover.
  - Re-claim fails: the player is disconnected with the rejoin message.
  - A duplicate failure report is handled once.
  - A launch error leaves the ship unlocked and in port.
  - A hanging launch shows "Sailing" within the timeout and the ship is released after it.
  - Each crew is launched once.

## Regression with flags off (Studio Play, API access checked OFF, memory-only saves)
`MultiShip=false` and no Ship2. Boarding gives Ship1; Sail Now (real E key) leads to Intermission and then Prologue, and the player landed on the island.

## Script hashes (Studio = `after\` = git; all compile)
| Script | SHA-256 |
|---|---|
| `Shared.Config` (all flags false) | `7dd563808bbd5dd18c7a25972c26ae77e3e5fcaef783dfaa083fc81145f4d7b6` |
| `Server.SessionLock` | `07929579491e0814dbeddaaad594d071a74ffbedb0c9a93eb0d67540a7f291a1` |
| `Server.IsleAdmission` | `1a6a97460d020880f456f61450cec410307d472445b76684c6cd65b234c5e434` |
| `Server.Voyages` | `2de823ded3c429029eea8cc9a65f1eda74aa7184a9185fd2e21bade878605b5d` |
| `Server.HarborDepartures` | `56bc3f29af0852ab0de0ed5ee0942592316c3b4bdbd0cceeaf8665fe71c394c5` |
| `Server.Main` | `9218af7bf237e04b9f51919ad0d4861b4c74dff2ac783e33974425492bd1358a` |

## Remaining activation blockers (nothing below is done)
1. **The owner creates the Isle place** in the Lighthouse Keepers experience and provides its PlaceId.
2. **The owner chooses an isolated test environment** (a new test experience is recommended; SaveTest stays frozen unless authorized).
3. **Wire SessionLock into PlayerData** behind its own flag, with a `handoff` that freezes mutations and a `reclaim` that resumes them. This needs a separate owner and auditor approval.
4. **Real session-ownership testing** in that test environment, against real DataStores: concurrent load, takeover, a failed save, and a failed hand-off between two published test servers.
5. **Controlled production cutover.** Old PlayerData code ignores metadata, so the cutover must stop every old writer first: publish with "Shut down all servers" or "Migrate to latest update", and only then enable teleports. A metadata version marker alone is not relied on.
6. Live teleport and manifest testing with several real clients in the test environment, then owner approval to publish.
