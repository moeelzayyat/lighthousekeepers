# Explicit owner decisions, implementation sequencing and remaining risks (TASK-004)

## 1. Decisions needed from the owner (each is a yes/no or a pick)
| # | Decision | Recommendation |
|---|---|---|
| D1 | Persistence path: library (ProfileStore, separate v2 store, one-time import) or hardened custom lock | Library, with the custom lock as fallback if a gate fails |
| D2 | Allow me to download the exact `ProfileStore.luau` at pinned commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd` into its own new empty folder (about one source file, from github.com/MadStudioRoblox/ProfileStore) to read it in full. Needed because this task read it only through a summarizing fetch tool | Yes |
| D3 | Create the separate private test experience and perform the publish-as steps yourself (`TEST_ENVIRONMENT_PROPOSAL.md`) | Yes, before any persistence work |
| D4 | Turn OFF "Enable Studio Access to API Services" on the production experience once the test universe exists | Yes |
| D5 | Maintenance-window cutover with a restart of outdated servers, accepting that invite or teleport joins can still reach an old server during the delay | Yes, short delay |
| D6 | Optional "pre-cutover fence" build and one marker write to the v1 store to evict old servers | Optional; recommend only if the plain restart proves unreliable |
| D7 | Treat the cutover as one-way after a soak period; define the soak length and abort criteria | Agree values before cutover |
| D8 | Win bonus: graded `round(5 x credited / 13)` (recommended), or a fixed minimum number of credited nights (7 is the lowest that removes the late-join advantage; 3 is not enough) | Graded |
| D9 | Count a run for early quitters only when present at Results or after at least one credited night | Yes |
| D10 | New saved field `grants` (last 20 runs or 30 days) for durable Pearl idempotency | Yes |
| D11 | Crew cap of 4 and fuel scaling by active crew (small crews get easier on busy servers) | Yes |
| D12 | Kick (not play-in-memory) when ownership of a save cannot be acquired | Yes |
| D13 | Library autosave interval (the default is 300 s; I suggest about 60-120 s if the write budget allows, to be set from test C14) | Decide after C14 |

## 2. Implementation sequencing (none authorized)
1. **TASK-004 accepted** by the auditor and owner.
2. **Owner actions:** D2 download approval, D3 test universe, D4 setting. Claude then verifies the new instance read-only (`GameId` not 10769064643) and runs gate T0.
3. **Read the library fully** (after D2), and diff it against `LIBRARY_SOURCE_FINDINGS.md`.
4. **Build and test in the test universe only:** persistence adapter, importer, harness; run E0 then C1-C17; produce evidence. No production change.
5. **Auditor gate:** review the evidence; decide library versus custom fallback.
6. **Production Batch 1 (persistence cutover)** with fresh `.rbxl` backup, `ServerStorage.Backups` copy, maintenance window, restart of old servers, soak period.
7. **Batch 2:** Pearl ledger and durable grants, crew cap, active-crew fuel.
8. **Batch 3:** validation hardening. These changes touch no saved data and could ship earlier if the owner and auditor prefer, but only with explicit authorization.
9. Boss redesign and the merchant stay blocked until the above are done and playtested.

## 3. Remaining risks (not eliminated by this design)
1. **Second-hand source reading:** ProfileStore was read through a fetch tool, not line by line.
2. **Thin maintenance:** last library commit 2025-07-31; a vendored copy becomes our code to maintain.
3. **Mixed-version servers** can fork or overwrite data until all old servers are gone; invite and teleport joins can reach old servers during the restart delay.
4. **One-way cutover:** rollback loses v2 progress unless an approved export tool is built and run in a maintenance window.
5. **Unbounded loss on crash:** any unsaved credit or purchase is lost; no maximum is guaranteed.
6. **Takeover of a slow-but-alive server** loses that server's unsaved memory state by design.
7. **Clock skew** between servers affects timestamp-based expiry (library uses 630 s dead-lock detection; the custom design uses minutes, not seconds).
8. **MessagingService dependency** for graceful takeover; if it degrades, takeover waits for the steal timeout (40 s in the library).
9. **Position trust remains** (client-reported positions); the validation changes limit blast radius but do not stop a determined spoofer.
10. **Production data shape unknown beyond the code:** real records may contain surprises; the importer fails closed instead of guessing.
11. **Hourly-granularity version history** (30 days) is the only built-in recovery for a bad write.
12. **Test universe parity:** a quiet private universe does not reproduce production load.
13. **Prompt hold verification** depends on engine behaviour not documented in the pages I read (test V0).
14. **Kicking players** on lock conflicts is user-visible and needs wording and soak monitoring.
