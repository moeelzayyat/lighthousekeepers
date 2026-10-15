# AUDITOR QUESTIONS — TASK-004

1. **Library versus custom.** The recommendation is ProfileStore on a new `_v2` store with our own read-only importer, custom lock as fallback. Do you accept that, given the library was read second-hand and is thinly maintained (last commit 2025-07-31)? Which additional gate would you require before a vendored copy is trusted (full read at a pinned commit, a test suite from the repo's `ProfileStoreTest.server.luau`, our own C-tests)?
2. **Fence strength.** As read, the library fences on PlaceId, JobId and `SessionLoadCount`, not on the per-session GUID. Is that adequate for this game, or do you want a wrapper that adds its own per-load token?
3. **Cutover.** Is a maintenance restart of outdated servers sufficient, or do you want the optional pre-cutover fence (a marker key that evicts old servers) despite the extra release and one production write?
4. **Rollback posture.** Is "one-way after a soak, v1 frozen, forward-fix preferred, export v2 to v1 only with approval" acceptable, or do you require a built and tested export tool before cutover?
5. **Autosave interval.** The library default is 300 s. Is a shorter interval worth the extra writes given immediate saves after each Pearl credit?
6. **Pearl rule.** Graded win bonus `round(5 x credited / 13)` versus a fixed minimum (7 is the lowest value that removes the late-join advantage). Which do you endorse, and should the durable `grants` map be capped at 20 runs / 30 days?
7. **Prompt validation.** If test V0 shows hold events do not fire on the server, is a cooldown at 0.8 x HoldDuration plus phase/crew/distance checks acceptable, given no server-verifiable hold exists?
8. **Test universe.** Are the wrong-target safeguards (production window closed, explicit publish target, ID verification, gate T0) enough for the owner-run publish step?
9. **Early quitters.** Do you agree with counting a run only when the player is present at Results or leaves after at least one credited night?

No concern has been invented; items 1, 3, 4 and 6 are the substantive forks.
