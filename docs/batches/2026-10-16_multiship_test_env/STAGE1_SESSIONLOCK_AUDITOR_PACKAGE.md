# Stage 1 audit package: SessionLock against a real test DataStore (2026-10-16)

**Result: all Stage 1 checks PASSED.**
- The test was bounded exactly as approved.
- Production (Lighthouse Keepers, GameId 10769064643) was never accessed.
- There were no MemoryStore writes, no teleports, no publishes, and no SetAsync, RemoveAsync or ListKeys calls.
- SaveTest, Outlaw City and Deadzone were untouched. These Studio windows were open but never addressed.

## Preflight (before any write)
| Item | Evidence |
|---|---|
| Studio instances | `Deadzone (72812275891657)`, `LK Multiship Test (125998212495899)`, `Outlaw City (132163592957463)`. Every script asserted `game.GameId == 10771229467 and game.PlaceId == 125998212495899` first. |
| Private | Roblox universe record `develop.roblox.com/v1/universes/10771229467`: `privacyType: "Private"`, `isActive: false`, creator Lighthouse8282 (11752219158). The public game page reports it as not accessible. |
| Harbor backup | `backups\2026-10-16\LKMS_TEST_harbor_2026-10-16_pre-stage1.rbxl`, 838,268 bytes, SHA-256 `0d8ebfcf6fd8d235be12c435bad739ea37f64c678c1c22e098df230a6e7eb962`. Its Rojo export equals git for Config, PlayerData, SessionLock, Voyages and Main. |
| Script hashes (Studio = git, branch `multiship-test` 6a11bce) | Config `27661b7a…8078` (switches off); PlayerData `f00636f6…6df1`; SessionLock `07929579…91a1` |
| Test configuration | `sessionLock = true` (Config `3e5586d0c61243a82d758d0cbf0433ee69834fd6375de8846d2094d6364ff0d6`); `multiShip = false`; `teleport = false`; store `LKMS_TEST_PlayerData_v1`; `writableUserIds = { 11752219158 }` |
| Order | The save lock was turned on **before** the owner enabled API access, and turned off only **after** API access was confirmed off. No Play ever ran with the unprotected path while API access was on. |
| Read-only key check | Uncached `GetAsync("player_11752219158")` (`DataStoreGetOptions.UseCache = false`) returned **value nil, no keyInfo**. The key was empty, so it was safe to proceed. |

## The deterministic change
- `ServerStorage.LKMS_Stage1` is a BindableFunction. It exists only in Studio, in the test experience, with the save lock on.
- `Invoke("addTestPearls", 11752219158)` calls the normal `PlayerData.addPearls(player, 25, "stage1-test")`.
- `Invoke("status", 11752219158)` reports pearls, dirty, lock ownership and ProfileState.

## Observed values (uncached reads of `LKMS_TEST_PlayerData_v1 / player_11752219158`)
| Step | Observed | Expected | Verdict |
|---|---|---|---|
| Play 1: join | ProfileState `saved`; status `{owned: true, pearls: 0, dirty: false}` | Claim ok, default profile | PASS |
| Play 1: stored | pearls 0, version `…0000000001…`, metadata `{session: {token: "b4e66a4e-4bdd-4604-a8a0-cfea2c1d50bd", at: 1792151806, job: ""}}` | Key created with the committed token | PASS |
| `addTestPearls` | status `{pearls: 25, dirty: true, owned: true}` | +25, dirty | PASS |
| Autosave (46 s) | stored pearls **25**, version `…0000000002…`, same token, `at` 1792151865; status dirty false | Owned save committed | PASS |
| Next autosave, profile unchanged (51 s) | stored pearls **25**, version `…0000000003…`, same token, **`at` 1792151925** (> 1792151865) | Heartbeat advances `at`; value unchanged | PASS |
| Stop Play 1 | stored pearls **25**, version `…0000000004…`, **metadata `[]`** (session cleared) | Released | PASS |
| Play 2: join | ProfileState `saved`; status `{owned: true, pearls: 25}`; stored version `…0000000005…`, token **`1211a507-889f-4dd2-b59b-48e340f322e4`**, different from Play 1 | Reload under a new token | PASS |
| Stop Play 2 | stored pearls **25**, version `…0000000006…`, **metadata `[]`** | Released | PASS |
| Console (Play 2 output) | `Device`, `Route fast`, `EnteredLobby`, `PlayerLeft`. **No PlayerData warnings or errors.** The other lines are Roblox CorePackages UIBlox warnings, which are unrelated. | — | PASS |

`job` is empty because `game.JobId` is empty in Studio Play. In live servers it holds the server's JobId.

## Operations performed
- **Writes:** six `UpdateAsync` commits on `player_11752219158` only, versions 1 to 6:
  - claim;
  - owned save;
  - heartbeat;
  - release;
  - claim;
  - release.
- **Reads:** the existing `GetAsync("__access_check")` on each server start, and my uncached verification reads of `player_11752219158`.
- **Not used:** SetAsync, RemoveAsync, ListKeysAsync, any other key or store, MemoryStore, TeleportService, publishing.

## Final configuration (verified)
- Studio API access in LK Multiship Test: **off**. The probe was rejected after the owner turned it off.
- `sessionLock = false`. Config is back to `27661b7af8e155a657d00d3c7ea216001406506d633b867a65c99854f1458078`, equal to git 6a11bce.
- `multiShip = false`, `teleport = false`.
- PlayerData `f00636f6…6df1` and SessionLock `07929579…91a1` are unchanged.
- The test key holds `{pearls: 25, …default profile}` with no session. It was left in place as test evidence.

## Tracked, not fixed in Stage 1 (next corrective batch, before teleport activation)
- **A.** `PlayerData.load` can leave a lock behind if PlayerRemoving fires while `claim()` is in flight and the claim then succeeds.
- **B.** `PlayerData.save` clears `dirty` after an in-flight save, even if another mutation happened during that save.
