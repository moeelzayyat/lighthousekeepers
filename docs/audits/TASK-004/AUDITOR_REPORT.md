# AUDITOR REPORT — TASK-004: Architecture safety revision

- **Date:** 2026-10-14
- **Project / place:** Lighthouse Keepers - Staging, place **132065051336560**, universe 10769064643, place version 148. Source examined: the TASK-001 export in `src\`. **No Studio instance was used or touched in this task.**
- **Original owner request (relayed auditor verdict on TASK-003):** reassess save architecture (library versus hardened custom lock, ten requirements), revise Pearl eligibility and idempotency, confirm crew cap and crew-only fuel with full test coverage, strengthen validation (BuyUpgrade, prompts), propose a safe separate persistence test environment (do not assume a local `.rbxl` is safe), and prepare the handoff. **No live-game edits, configuration changes, DataStore writes or publishing are authorized; stop after the revised design.**
- **Objective:** a design the auditor can approve or reject before any persistence code is written.

## Work completed
Research and documents only. The upstream ProfileStore repository, source and docs, and the Roblox DataStore, versioning, limits, server-update and ProximityPrompt pages were read on 2026-10-14. Findings and limits are in `LIBRARY_SOURCE_FINDINGS.md` and `TEST_EVIDENCE.md`. TASK-003 statements that were wrong or too strong are withdrawn in `CORRIGENDUM_TASK-003.md`.

## Update after D2 follow-up
The full source confirms the core conclusions and adds corrections A-J (for example: ordinary autosave failures are not retried until the next autosave period; the module performs a real write to a store named `____PS` when loaded in Studio with API access; `GetAsync` cannot read our v1 records). See `SOURCE_VERIFICATION_ADDENDUM.md`.

## Key findings
1. **ProfileStore cannot be pointed at the existing v1 store.** As read, it replaces any record that lacks its own wrapped structure with an empty profile. A separate `_v2` store plus our own one-time, read-only, idempotent import from v1 is therefore justified for the library path. An in-place migration is only possible for a custom lock.
2. **Recommendation changed:** use the maintained library on a new store (Apache-2.0, 32 commits, last commit 2025-07-31, so stable but thinly maintained) with the hardened custom lock as a documented fallback. Reason: the auditor's ten requirements describe a protocol that is hard to build and prove, and the library already implements most of it; the rollback advantage that favoured a custom lock in TASK-003 does not exist.
3. **No lossless rollback exists for either option.** Disabling the lock reintroduces SEC-1/SEC-2; with the library, progress after cutover lives only in v2 unless an approved export tool is run. The documented rollback posture is "treat cutover as one-way after a soak period; keep v1 frozen".
4. **Mixed old/new servers are the central deployment risk.** Roblox leaves old servers running after a publish and recommends restarting servers when data formats change. A custom lock offers no protection against old servers; the library path forks data. The mitigation is a maintenance cutover with a restart of outdated servers; residual risk from invite and teleport joins remains.
5. **Pearls:** a three-night minimum for the win bonus leaves a cliff that pays about twice per minute for a late join; a graded bonus `round(5 x credited / 13)` gives parity and still pays 18 for a full win. Durable idempotency is a `grants` map saved atomically with the Pearl balance and is authoritative over the in-memory ledger. No maximum loss on a crash is promised.
6. **Crew and fuel designs confirmed**, with added test rows for full crews, first-voyage joining, mid-run replacement and harbor spectators.
7. **Validation revised:** BuyUpgrade needs a server-recorded bench interaction, present-time proximity, phase and crew eligibility. For prompts, I could not find documentation that hold events fire on the server, so a per-player cooldown of 0.8 x HoldDuration (safe for honest players) is the design and server-side hold timing waits for test V0. No movement anti-cheat.
8. **Test environment:** a separate private test experience is proposed (owner-created, owner-published, with explicit wrong-target safeguards and gate test T0). A local `.rbxl` is never assumed DataStore-safe.

## Architecture / gameplay / security / save-data / performance implications
No change was made. If implemented as designed: a new store and importer, one new saved field (`grants`), per-night Pearl crediting with immediate saves, a cap on crew, and extra validation. Write load rises modestly (lock refresh or library autosave plus about 13 extra writes per player per run); to be measured in C14.

## Known limitations
- The first pass read the library through a summarizing fetch tool. **This was resolved for the source text by the D2 follow-up** (`SOURCE_VERIFICATION_ADDENDUM.md`: the pinned file was downloaded, hash-verified against GitHub's blob SHA, and read in full). The library's behaviour under our usage is still untested.
- DataStore semantic claims (transform re-runs, nil cancels) come from Roblox's pages and community summaries and are to be confirmed in tests C4/C5.
- Per-universe DataStore isolation is platform behaviour I relied on; gate T0 checks it.
- No test of any kind was run.

## Outstanding problems
All TASK-002 findings remain open. Open decisions D1-D13 are in `OWNER_DECISIONS_AND_SEQUENCING.md`.

## Ready for acceptance?
Yes as a design and verification milestone. No implementation is authorized.
