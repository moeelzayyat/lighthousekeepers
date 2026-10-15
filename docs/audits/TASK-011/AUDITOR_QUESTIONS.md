# QUESTIONS FOR AUDITOR / OWNER — TASK-011

1. **Accept R3?** Are the three results acceptable as recorded: persistence and release passed; MessagingService passed for the same server only; BindToClose passed for registration only?
2. **JobId is `""` in Studio Play servers.** This is now verified. It confirms that session-conflict testing cannot be done in Studio. The options are:
   - (a) a guided publish of SaveTest only, then two real servers;
   - (b) drop the conflict rows and rely on the mock evidence (M13);
   - (c) a wrapper with its own per-load token, which would be a design change.

   Which direction?
3. **Shutdown release of an active profile.** Do you want this as R4? It would leave a session open on a third synthetic key, stop Play, then verify release from Edit. That is a new key and new writes, so it needs separate approval.
4. **Cross-server MessagingService.** It needs a published server. Should it be deferred together with item 2?
5. **SaveTest state.** `Main` is disabled only in the open Studio session. Should the owner save SaveTest to file now, as `SaveTest_TASK-011_post.rbxl`? Recommended, so the state is recorded and survives a Studio restart.
6. **Synthetic records.** `player_900000202` (30 Pearls) and the probe value stay as they are. Confirm they should be kept as fixtures. Removing them is not proposed.
