# CHANGE MANIFEST — TASK-011 (R3 execution)

**Production Lighthouse Keepers, Outlaw City, real player saves and every other key or store: untouched. Nothing published. No game script contents, Config values, economy or gameplay changed.**

## SaveTest Studio session (Edit DataModel; not yet saved to file)
| Instance | Change | Rollback |
|---|---|---|
| `ServerScriptService.Server.Main` | `Enabled` true → **false** (left disabled, as approved) | set `Enabled = true`, or restore `SaveTest_TASK-010_pre.rbxl` |

No other instance changed. The module hashes were re-verified before the run:
- `R3ServerRunner` v2: `6083eca5…b733`
- `SaveTestGuard`: `4d85ffc6…500d`
- `ProfileStore`: `ad437372…0c95f`

## DataStore writes (SaveTest universe 10770892134 only)
| # | Store / key | Operation | Observed |
|---|---|---|---|
| W1 | `____PS` / `____PS` | library Studio probe `SetAsync(os.time())` at require | value `1792001296` → `1792005392` (19:16:32Z) |
| W2 | `TEST_LK_ProfileStore_v2` / `player_900000202` | `UpdateAsync`: session start (record created) | `ProfileCreateTime 1792005394`; stored `ActiveSession` set |
| W3 | same | `UpdateAsync`: save, `pearls = 30` | stored `pearls 30` |
| W4 | same | `UpdateAsync`: release | `ActiveSession` absent; `LastUpdate 1792005395`; `UpdatedTime` 19:16:37Z |

- The key's version string `…0000000003…` is consistent with three writes. Version numbering is not used as proof.
- No recovery `EndSession` was needed.

## Non-persistent actions (Play server, now stopped)
- MessagingService: subscribe, publish and receive on `TEST_LK_R3_fb999583`, then disconnected.
- The library's own subscription to its `PS_<GUID>` takeover topic, with no library publish.
- One no-op `BindToClose` registration, plus the library's own handlers.

## Reads
`player_900000202`, `player_900000201` (fixture, read only), `____PS`. All the runner's reads used `UseCache = false`.

## Files on disk
`docs\audits\TASK-011\`: this package plus `raw\01..06`.
