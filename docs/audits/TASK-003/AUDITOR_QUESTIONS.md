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
