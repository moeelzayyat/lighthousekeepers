# AUDITOR REPORT — TASK-011: R3 execution (one real-server ProfileStore session)

- **Date:** 2026-10-14. The run started at about 19:16:31Z. ProfileStore created the record at 19:16:34Z, and the release write landed at 19:16:37Z.
- **Authorization:** the owner's message "OWNER AUTHORIZATION — EXECUTE R3", 2026-10-14 19:15:06Z. It authorizes one execution of `docs\audits\TASK-010\R3_AUTHORIZATION_REQUEST.md`.
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`. Production and Outlaw City were not touched. Nothing was published.
- **Executed:** once. There were no retries and no re-sends.

## Outcome: three independent results

| Area | Result | Evidence | Scope limit |
|---|---|---|---|
| **ProfileStore persistence and lock release** | **PASSED** | Fresh key (precheck: absent); session started with load count 1; `pearls = 30` seen in the stored record 0.37 s after `Save()`; uncached read showed `ActiveSession` cleared 1.33 s after `EndSession()`. Confirmed again from the Edit DataModel after Play stopped: `pearls 30`, no `ActiveSession`, `SessionLoadCount 1` | Single server, single session. No concurrent or second-server claim. |
| **MessagingService** | **PASSED (same server)** | Subscribe, publish and receive all succeeded on `TEST_LK_R3_fb999583` (step `3a_messaging`). The library's own takeover-topic subscription was present (`librarySubscribedToItsTakeoverTopic = true`) | The publisher and subscriber were the same Studio Play server. Cross-server delivery is **not** shown. |
| **BindToClose** | **PASSED (registration only)** | `game:BindToClose(no-op)` registered without error | Release of an *active* profile at shutdown was **not tested**. The session had already been released before Play stopped. |

The save result was computed only from the stored record. It is not used as evidence for messaging or shutdown.

## Safety and cleanup
- Status was `terminal` on the first poll. At that point `flagReset = true` and `safeToStopPlay = true`, and the session was released in the store. Play was stopped only after that.
- `Main` was disabled before Play and is still disabled now. Because of that, the game's `PlayerData` never loaded, and the console shows only client `WaitForChild` warnings.
- The fixture `player_900000201` was read only. Its `UpdatedTime` (18:22:34Z) predates this run, and its data is unchanged: `pearls 25`, load count 2, released.

## New findings
1. **`game.JobId` is the empty string in a Studio Play server.** This was observed in the identity step and in the stored `ActiveSession = [128620546156998, "", <GUID>]`.
   - It confirms the TASK-004 inference, which until now was unverified.
   - The library fences on PlaceId + JobId + load count. Two Studio Play servers would therefore look like the same server to the fence.
   - So session-conflict tests still need published servers, or another design. They cannot use Studio.
2. **`OnSessionEnd` fired about 0.1 ms after `EndSession()`, while the stored release took 1.33 s.** This matches the source reading: the event fires before the release write. Release must therefore be confirmed from the store, never from the event.
3. **Studio Play servers can use MessagingService.** That answers the open TASK-010 question for same-server use only.

## Deviations
None from the approved steps.
- The status command was sent once, because the run was already terminal at 3.5 s.
- The read-only preflight in step 1 also re-checked module hashes and the flag in Edit. It made no DataStore call.

## Open state
- `Main.Enabled = false` exists **only in the open Studio session**. It has not been saved to a file. If Studio is closed without saving, `Main` returns to enabled.
- The owner is asked to save SaveTest to file as `SaveTest_TASK-011_post.rbxl`.

## Ready for audit
Yes. Stopped after R3. No further operations are planned without new approval.
