# AUDITOR QUESTIONS — TASK-009

1. **Edit-mode limits.** Saving works in Edit mode, but MessagingService and `BindToClose` do not. Do you agree the next step must be a real server context (Studio "Run" server, no player) before any session-conflict or shutdown test?
2. **Game scripts in a Run server.** In a "Run" session the game's own server scripts start. With no player, the game's `PlayerData` only reads `__access_check` from the SaveTest copy of `LighthouseKeepers_PlayerData_v1` (no write expected). Is that acceptable, or should those scripts be disabled in the SaveTest copy first (a code change to the test place only)?
3. **The synthetic record left behind.** `player_900000201` now holds 25 Pearls in SaveTest. Leave it (it also stops any accidental rerun of R2 from writing), or remove it later with an approved `RemoveAsync` on that one key?
4. **Fresh Studio session.** We reused the already-loaded module instead of a fresh session, with probe-key evidence of no re-initialization. Acceptable going forward, or do you want a procedure that restores the TestOnly scripts into a fresh session (which would require publishing SaveTest)?
5. **Write counting.** Real writes were inferred from stored-record transitions and the absence of error logs. Do you want an instrumented count next time (for example by reading `GetRequestBudgetForRequestType` before and after)?

No further concern has been invented; items 1 and 2 are the real forks.
