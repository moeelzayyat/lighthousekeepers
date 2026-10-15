# AUDITOR QUESTIONS — TASK-006

1. **Production API setting.** It cannot be read without touching production or logging in. Do you accept "owner reports it himself" as the only path, or do you want D4 (turn it OFF) treated as a precondition for any ProfileStore use regardless of its current value?
2. **Isolation evidence.** T0 (production profile key nil in SaveTest) plus a working canary round trip. Is that enough to begin SaveTest persistence tests, given that production cannot be queried to prove the canary is absent there?
3. **v148 versus v149.** Scripts are identical and the exports differ only in JSON key order, but the two `.rbxl` files have different hashes at the same size. Is a world-level comparison (for example, opening both in scratch windows and comparing instance trees) worth doing, or do you accept the script-level result?
4. **Canary marker.** The marker remains in `TEST_LK_IsolationCanary`. Leave it as a permanent environment fingerprint, or have it removed? Removal needs a `RemoveAsync`, which was prohibited so far and would need a separate approval.
5. **Next gate.** Proposed next task: place the pinned, hash-verified `ProfileStore.luau` into the SaveTest place only, add the guard and `TEST_`-prefixed names, and run the first matrix rows with fixtures. Any change to that scope before it is requested?

No further concern has been invented; items 1 and 2 are the real forks.
