# AUDITOR REPORT — TASK-002: Read-only code audit (security, save data, gameplay, economy)

- **Date:** 2026-10-14
- **Project / place:** Lighthouse Keepers - Staging, place **132065051336560**, universe 10769064643, place version 148.
- **Original owner request:** "Begin a read-only audit after confirming the correct project", covering onboarding, beam, fuel/repair, creatures, bosses, weapons, economy, Quartermaster/Trader, loadouts, DataStore and network security, performance, mobile HUD, co-op, the 13-night campaign, results/rematch, and runtime errors.
- **Objective:** find and classify problems before any change, using evidence, with severity.

## Method and what "verified" means here
- Two independent code reviews (security: 19 findings, `SECURITY_AUDIT.md`; gameplay/economy/performance: about 53 findings, `GAMEPLAY_AUDIT.md`) were run by sub-agents over the exported scripts in `src\` (the exact copy of place version 148 from TASK-001).
- **Nothing was executed.** No Play session, no multiplayer test, no phone test, no profiling. "VERIFIED" in the two reports means the code path was traced in source, not observed running. Nothing about runtime behaviour, frame rate, bandwidth or retention is claimed.
- Claude (coordinator) independently re-read the code behind five claims and **confirmed all five**: no-session-lock save (`PlayerData.luau:101-116`, `UpdateAsync` returns the local profile and ignores the stored one); dirty flag cleared after the yield (`:111-113`); Pearls paid to `readyPlayers()` at run end (`GameState.luau:503-524`; that a late joiner counts as Ready rests on the sub-agent's trace of `Main.server.luau:646-657`, not re-read); no payout on `Abandoned` (`:356, 391, 453, 508`); the boss-night loop that stops at `MAX_BIG_PER_RUN` (`:359-378`). The remaining findings are the sub-agents' reading and have not been independently re-checked.
- Docs (`progress.md`) were treated as claims. The code-vs-docs comparison is in `GAMEPLAY_AUDIT.md` section 12.

## Highest-priority findings (full detail, evidence and classification in the two reports)
| ID | Severity | Class | Summary |
|---|---|---|---|
| SEC-1 | High | VERIFIED BROKEN | No session locking; saves overwrite the stored value, so a fast rejoin or server hop can roll back Pearls/items. |
| SEC-2 | Medium | VERIFIED BROKEN | Purchase or Pearl payout made during an in-flight autosave can be marked saved and lost. |
| SEC-3 | Medium | VERIFIED BROKEN | Save on leave is attempted once; failure loses everything since the last autosave. |
| GP-23 / SEC-4 | High | VERIFIED BROKEN | A full 18 Pearls (13 nights + 5 win) is paid to anyone Ready at run end, including a player who joined on night 13 or is AFK. |
| GP-24 | High | VERIFIED BROKEN | Quitting, disconnecting or leaving the crew mid-run pays 0 Pearls and no run credit; an "Abandoned" run pays nobody. |
| SEC-6 | Medium | VERIFIED BROKEN | Client-reported character position is trusted for loot pickup, attack range and Trader/shop distance; boss Pearl drops can be teleport-stolen. |
| SEC-5 | Medium | SUSPECTED | No server cooldown on repair/oil/refuel prompts; prompt-spam exploits could make runs unlosable. |
| SEC-8 | Medium | VERIFIED BROKEN | `GearAction "sync"` is unthrottled and does expensive work per call. |
| GP-25 | Medium | VERIFIED BROKEN | The 1-4 crew limit is not enforced. |
| GP-21 | Medium | VERIFIED BROKEN | Shell income (floor 1,303; up to about 6,500-6,700 if all loot is collected and sold) far exceeds the sinks that exist (2,080), as `progress.md` already suspected. |
| GP-11/12/13/14 | High | PLANNED | Map of what the boss changes touch, plus a trap: nights are iterated downward and capped at `MAX_BIG_PER_RUN = 4`, so naively raising boss counts would drop nights 4 and 7. Four Brutes would hit the 100-HP tower for about 20 HP/s. |
| GP-43/44 | Medium | VERIFIED BROKEN | Two scripts fight over `TouchControlsEnabled`; a controller can take the lamp but cannot aim or leave. |
| GP-2, GP-3, GP-15, GP-19 | Medium | VERIFIED BROKEN | Fuel drain scales by all server players not the crew; Keeper is released after 25 s of holding still; a Fire Shell reload wipes cannon ammo; `BuyUpgrade` has no phase/proximity check. |
| GP-35, GP-37, GP-47 | Medium | UNTESTED | Lamp shift (2+ players), 4-player load at the 45-creature cap, phone HUD pixel zones. |
| GP-1 | Info | VERIFIED WORKING | The 10-second blackout rule matches its config. |

Working and well protected (traced): purchase pricing and double-spend protection, negative/fractional quantities, equip of unowned items, Keeper-only beam remotes (NaN-safe), forecast voting, coach whitelist, armor stats set server-side, per-player cleanup, run-to-run state resets.

## Economy numbers from code (no play data exists)
A 13-night win pays 18 Pearls; the full permanent shop costs 530 Pearls (about 29 wins). Per-night creature counts are tabulated in `GAMEPLAY_AUDIT.md` section 13. These are arithmetic, not retention evidence.

## Architecture, gameplay, save-data, performance implications
- No change was made. The save-data and Pearl-payout findings are the only ones that put saved progress at risk; any fix needs owner approval (rewards, persistence).
- Performance: server cost per frame and bandwidth were not measured; code-read risks (per-frame beam raycasts, loot-orb animation, per-call updates) are SUSPECTED.

## Known limitations
No runtime evidence. No multiplayer, mobile, controller or long-session test. Sub-agent findings beyond the five re-checked are single-reader conclusions.

## Outstanding problems
All findings above. Nothing was fixed.

## Ready for acceptance?
Yes as a read-only audit. It is not a clean bill of health for the live game: the Pearl payout and save-integrity issues are present in the published build described by `progress.md`.

## Recommended next step (needs owner decision, see AUDITOR_QUESTIONS.md)
A small, approved "integrity batch" before any feature work: session-safe saving, the dirty-flag/leave-save fixes, Pearl eligibility, and the crew cap. Then a measured 4-player and phone test. Boss and merchant features follow after the economy direction is decided.
