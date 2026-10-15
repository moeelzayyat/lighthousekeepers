# TEST EVIDENCE — TASK-004

**Tests performed: none.** This task is research and design. No game code, Studio session, DataStore or published content was used. **No test could have changed production DataStore values: no DataStore request was made.** (Follow-up under owner decision D2: the pinned `ProfileStore.luau` was downloaded and read as text only; its hash and size checks are in `SOURCE_VERIFICATION_ADDENDUM.md`. It was never executed.)

## Research log (what was read, and how)
All on 2026-10-14, using a fetch tool that returns a model-written answer to a prompt about the page (not the raw bytes), and a web search tool.
| Source | What it was used for | Reliability note |
|---|---|---|
| github.com/MadStudioRoblox/ProfileStore (repo page) | description, license Apache-2.0, 32 commits, file list | page capture; commit/tag details came from the API below |
| api.github.com/repos/MadStudioRoblox/ProfileStore/commits | latest commit `45c9847c...` 2025-07-31, earlier commits | API JSON summarised by the tool |
| api.github.com/repos/MadStudioRoblox/ProfileStore | created 2024-10-09, pushed 2025-07-31, not archived, license `Apache-2.0` | the tool flagged an `updated_at` timestamp (2026-10-13) as odd; it is a metadata field and not a code change |
| raw.githubusercontent.com/.../ProfileStore.luau (two prompts) | record shape, session lock, constants, API names, legacy-record behaviour, Studio probe, shutdown | **second-hand**; quotes are what the tool reported as verbatim; the file was **not downloaded** and not read line by line |
| madstudioroblox.github.io/ProfileStore (docs) | API notes, "backwards compatible with ProfileService", no migration guidance, silent on `Cancel`/`OnSessionEnd`/mock | docs page is thin |
| create.roblox.com ... data-stores (overview) | Studio access off by default, setting path, warning that Studio uses the same data stores, recommendation of a separate test game; silent on local files and BindToClose | direct statements from the page |
| create.roblox.com ... error-codes-and-limits | request budgets (`60 + numPlayers x 40` read and standard write), per-key 4 MB/min write, 4,194,304-char value limit, throttle codes 301-306, 403 StudioAccessToApisNotAllowed | direct statements from the page |
| web search: UpdateAsync semantics | transform may re-run if another server wrote; runs until saved or returns nil; "non-yielding transform" is community advice, not a documented rule | secondary; to be confirmed by tests C4/C5 |
| web search: data store versioning | first write per key per UTC hour is kept as a backup; backups expire 30 days after being overwritten; newest never expires; `RemoveAsync` leaves older versions reachable | secondary summary of the docs page |
| web search: server updates | after publish old servers keep running; "Restart Servers" with "restart only outdated servers" and a 1-60 minute delay exist; Roblox suggests restarting servers when data format changes; invite/teleport joins can still reach old servers | secondary summary of the docs page and a forum thread |
| create.roblox.com ... ProximityPrompt reference | event list; page does not state the side events fire on or any server distance validation | direct reading; **gap, not a negative result** |

## Direct source reading in this repository (no execution)
`PlayerData.luau`, `Main.server.luau`, `GameState.luau`, `LampService.luau`, `IslandBuilder.luau`, `Config.luau` read in TASK-003/TASK-004; lines cited in the design files are from `src\` (place version 148).

## Tests not performed (all of them)
Everything in `REVISED_TEST_MATRIX.md`. Specifically unverified assumptions: transform re-run and nil-cancel behaviour (C4/C5), real shutdown timing (C7), the library's behaviour on our records (C9, C12), mixed-server forks (C10), per-universe store isolation (T0), prompt hold events on the server (V0).

## Remaining regression risk
None from this task (no change).
