> **NOTICE (2026-10-14): partly superseded by TASK-004.** Some statements below were withdrawn or corrected; see `docs/audits/TASK-004/CORRIGENDUM_TASK-003.md`. The text below is otherwise unchanged.

# AUDITOR REPORT — TASK-003: Integrity design and safe test plan

- **Date:** 2026-10-14
- **Project / place:** Lighthouse Keepers - Staging, place **132065051336560**, universe 10769064643, place version 148 (source examined: the TASK-001 export in `src\`; no Studio access was needed or used for this task).
- **Original owner request (relayed from the independent auditor):** re-examine SEC-1/2/3 against PlayerData; compare a session-safe library with a minimal backward-compatible implementation; document the v1 schema, keys, failure states, migration risks and rollback; design isolated tests; propose a fair per-player Pearl system (GP-23/24); verify GP-25/GP-2 and propose a crew cap and crew-only fuel scaling; review SEC-5/6/8/9 for the smallest safe fixes; separate source-confirmed from needs-reproduction; produce an implementation plan with approval requirements. **No production gameplay, economy, save or Studio changes are authorized. Stop after the plan.**
- **Objective:** a reviewable design and test plan the owner and auditor can approve or change before any code is written.

## Work completed
Design documents only (listed in CHANGE_MANIFEST.md). The following were re-read directly in the exported source: `PlayerData.luau` (whole file), `GameState.luau` (phase loop, boss selection, Pearl payout), `Main.server.luau` (join/leave, crew, prompts, Attack, BuyUpgrade), `LootService.luau`, `TowerService.luau`, `LampService.luau` (fuel). Exact excerpts with line numbers are in `CODE_EXTRACTS.md`.

## Source-confirmed findings (read in code; not reproduced at runtime)
| Item | Result |
|---|---|
| SEC-1 no session lock | CONFIRMED BY SOURCE (`PlayerData.luau:101-116`, `:118-150`). Frequency in the real game needs two-server reproduction. |
| SEC-2 dirty flag cleared after yield | CONFIRMED BY SOURCE (`:96-99`, `:101-116`); deterministic sequence, rate unknown. |
| SEC-3 leave save tried once | CONFIRMED BY SOURCE (`:323-331`). |
| SEC-10 boot probe disables saving for the whole server | CONFIRMED BY SOURCE (`:290-308`). |
| New: shutdown saves are sequential; idle players are never re-saved | CONFIRMED BY SOURCE (`:332-338`, `:103`). |
| GP-23 Pearls go to whoever is Ready at the end | CONFIRMED BY SOURCE (`GameState.luau:503-524`, `Main.server.luau:646-657`). |
| GP-24 leavers/disconnects/Abandoned get nothing | CONFIRMED BY SOURCE (leavers are absent from `Players`; `:508`). |
| New: joining during the Results phase still sets Ready | CONFIRMED BY SOURCE that nothing prevents it; the timing window needs a test. |
| GP-25 no crew cap | CONFIRMED BY SOURCE (`joinCrew`); whether the Roblox place max-players setting caps the server is UNTESTED. |
| GP-2 fuel scales by all connected players, swarm by crew | CONFIRMED BY SOURCE (`LampService.luau:284` versus `GameState.luau:410`). |
| SEC-5, SEC-6, SEC-8, SEC-9, SEC-15 | CONFIRMED BY SOURCE that the checks are missing (`VALIDATION_IMPROVEMENTS.md` section 6); real exploit behaviour needs reproduction. |

## Requires reproduction before relying on it
Cross-server rollback frequency, the save-during-autosave loss rate, shutdown behaviour with real latency, how the engine's `UpdateAsync` handles a cancelled transform, whether a locally opened `.rbxl` really has no DataStore access, spoofed-position reach, and everything about performance. These are covered by `ISOLATED_TEST_PLAN.md`.

## Recommendations (all pending owner approval)
1. **Save integrity:** Option B (in-place lock, additive `_session`/`_rev` fields, same store and key, behind a flag). Reason: lossless rollback and the smallest change; Option A (library with a new store) stays the fallback if B cannot be made reliable in the harness.
2. **Pearls:** per-night credit at dawn to players present for the whole night, win bonus with a minimum nights rule, idempotent credit keys, leavers keep what they earned; full participation still pays 18.
3. **Crew:** `MAX_CREW = 4` enforced in `joinCrew`; fuel scaling by crew (this makes busy servers easier, which is a balance-visible change).
4. **Validation:** cooldown+phase gate for prompts, crew-only loot, `sync` throttle, bench-session gate for upgrades, infinity check on attacks.

## Architecture / gameplay / security / save-data / performance implications
No change was made, so none are in effect. If implemented as designed: the saved record gains two additive fields; rewards are credited per night instead of at the end (same totals for full participation); small CPU/DataStore cost increases (one lock-refresh write per player per minute) are expected but unmeasured.

## Known limitations
Design from reading code only. The library comparison (Option A) is from general knowledge; the library source was not downloaded or read. UpdateAsync cancellation semantics and the scratch-copy DataStore behaviour are assumptions marked for testing. No test of any kind was run.

## Outstanding problems
All TASK-002 findings remain open. The TASK-001 follow-up was done after this report was first drafted: the owner opened the backup in a separate Studio window and a read-only check found it matches the live place (see `TASK-001/ADDENDUM_BACKUP_LOAD_VERIFICATION.md`). One loose end: the live Lighthouse Keepers window was not in the instance list at that moment, which the owner should confirm.

## Ready for acceptance?
Yes as a design and plan. It is not an implementation and nothing is approved to start.
