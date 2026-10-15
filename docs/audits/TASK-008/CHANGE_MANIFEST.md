# CHANGE MANIFEST — TASK-008

**No game script, Config value, saved player data or published version was changed; nothing was published; production and Outlaw City were not touched by Claude.**

## In-place changes in SaveTest (PlaceId 128620546156998, GameId 10770892134) — unsaved to any file
| Item | Change | Hash |
|---|---|---|
| `ServerStorage.TestOnly.MockTests` | edited: M3 expectation corrected, M3b and M11b added, `ORDER` and `KIND` tables, `kind` field in results | before `cb4d22d7...7196cf`, after `2feea5946973ea51dabc9a9fdf551d8b8bf7c8ea82bd86b23b26990f84e6a533` (19,451 bytes), equal to `docs\audits\TASK-008\luau\MockTests.luau` |
| `ServerStorage.TestOnly.SaveTestGuard` | **no source change.** Its in-memory flag `REAL_DATASTORE_APPROVED` was set true for one `require` and set back to false in the same script; verified false afterwards | `4b2ae473...c8a4` (unchanged) |
| temporary instance `ServerStorage.TestOnly.MockTests_fresh` | created as a clone for each test run and destroyed immediately; `TestOnly` holds exactly the same 5 scripts as before | none remains |
| runtime state | the real `ProfileStore` module was `require`d once (R1) and remains loaded in this Studio session | source unchanged `AD437372...0C95F` |

## Real DataStore write (one, owner-approved: "approve R1")
Universe 10770892134 (SaveTest), store `____PS`, key `____PS`, value the Unix timestamp `1792001296`, written by the library's own Studio probe. Persistent data of the game, economy values, prices, and production data: unchanged.

## Files created on disk (inside `C:\RobloxProjects\LighthouseKeepers\`)
`docs\audits\TASK-008\` (this package), `docs\audits\TASK-008\luau\MockTests.luau`, `luau\R1_real_init.luau`, `luau\R1_followup_read.luau`. No source diffs against game scripts exist (none changed).
