# Stage 1 (SessionLock against a real test DataStore): final preflight and exact test script

**Status: NOT RUN.** It needs the owner's explicit yes to this exact scope.
Branch `multiship-test`, commit 6a11bce.

## Preflight results (done, read-only)
| Check | Result |
|---|---|
| Studio instances | `LK Multiship Test (placeId 125998212495899)`, `Deadzone (72812275891657)`, `Outlaw City (132163592957463)`. Only the first is used; the others are never addressed. |
| Asserted inside the target window | `game.GameId == 10771229467` and `game.PlaceId == 125998212495899` (this check runs first in every script) |
| `Shared.Config` | `27661b7af8e155a657d00d3c7ea216001406506d633b867a65c99854f1458078` (Studio = git) |
| `Server.PlayerData` | `f00636f6384caa0be42a2dd171d55e5e0f7c0c1e9307db22cf2d8aa2c8756df1` (Studio = git) |
| `Server.SessionLock` | `07929579491e0814dbeddaaad594d071a74ffbedb0c9a93eb0d67540a7f291a1` (Studio = git) |
| Switches now | `multiShip = false`, `sessionLock = false`, `teleport = false` |
| Writable keys | `writableUserIds = { 11752219158 }`: only `player_11752219158`. Any other player plays from memory and is never written. |
| Studio API access | **off** |

**Preflight additions** (test branch only; production `main` untouched):
- **Writable-key allowlist** in PlayerData.
- **Stage 1 hook:** `ServerStorage.LKMS_Stage1`, a BindableFunction. It is created only in Studio, in the test experience, with `sessionLock` on.
  - `status` reads the allow-listed player's pearls, dirty flag, lock ownership and ProfileState.
  - `addTestPearls` adds exactly `stage1Pearls = 25` through the normal `PlayerData.addPearls`.

## Owner steps before the test
1. Confirm **LK Multiship Test is Private**.
2. Save a fresh Harbor backup from the test window: **File > Save to File** as `backups\2026-10-16\LKMS_TEST_harbor_2026-10-16_pre-stage1.rbxl`. I hash it and check it with Rojo.
3. Give the explicit **yes** to this scope.

## Exact sequence (after the yes)
| # | Who | Action | Expected / stop condition |
|---|---|---|---|
| 1 | me | Set `sessionLock = true` in the test window's Config (one line), then record the new Config hash | Hash recorded; multiShip and teleport still false |
| 2 | owner | **Game Settings > Security > Enable Studio Access to API Services**, in the **LK Multiship Test window only** | — |
| 3 | me | **Read-only, uncached:** `GetDataStore("LKMS_TEST_PlayerData_v1"):GetAsync("player_11752219158", options with UseCache = false)` | Value **nil** (never written). **If it holds anything, STOP**: no Play, report it. |
| 4 | me | **Play session 1** (solo, the owner's account) | `ProfileState = "saved"`. Hook `status`: owned = true, pearls = 0. |
| 5 | me | Uncached read | Value = the default profile (pearls 0); `metadata.session.token` present (record it) |
| 6 | me | Hook `addTestPearls` (+25) | status: pearls = 25, dirty = true |
| 7 | me | Wait for the autosave (≤ 65 s), then an uncached read | Stored pearls = 25; session token unchanged; `session.at` = t1 |
| 8 | me | Wait one more autosave interval (≤ 65 s), no changes; then an uncached read | Stored pearls still 25; **`session.at` > t1** (heartbeat while unchanged) |
| 9 | me | Stop Play, then an uncached read | Stored pearls = 25; **`metadata.session` = nil** (released) |
| 10 | me | **Play session 2**, then an uncached read | Claim succeeds; status pearls = 25 (**reloaded**); a **new** token, different from step 5 |
| 11 | me | Stop Play, then an uncached read | Pearls 25; `metadata.session` = nil |
| 12 | owner | **Turn Studio API access OFF** in LK Multiship Test | Probe rejected |
| 13 | me | Set `sessionLock = false`, then record the hash (back to `27661b7a…`) | No Play ever runs with the unprotected path while API access is on |
| 14 | me | Console check, then write `STAGE1_SESSIONLOCK_AUDITOR_PACKAGE.md`, then stop | — |

**DataStore operations in the whole test:**
- **Writes:** `UpdateAsync` on `player_11752219158` only, through SessionLock. That is about 2 claims, about 1 save, about 1 heartbeat, about 2 releases, plus any extra autosave heartbeats while Play runs.
- **Reads:** `GetAsync("__access_check")` on server start (existing code), plus my uncached verification reads of `player_11752219158`.
- **Never used:** SetAsync, RemoveAsync, ListKeys, any other key or store, MemoryStore, TeleportService, publishing.

## Tracked for the next corrective batch (NOT fixed in Stage 1, as instructed)
- **A.** `PlayerData.load` can leave a lock behind if PlayerRemoving fires while `claim()` is still in flight and the claim then succeeds.
- **B.** `PlayerData.save` clears `dirty` after an in-flight save, even if another change happened during that save.
