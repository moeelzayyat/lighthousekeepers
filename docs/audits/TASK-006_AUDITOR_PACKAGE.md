# TASK-006 AUDITOR PACKAGE (combined plain-text version)

Persistence test readiness for Lighthouse Keepers. SaveTest: place 128620546156998, universe 10770892134. Production (132065051336560 / 10769064643) untouched; Outlaw City untouched. One owner-approved canary write was made in the SaveTest universe only; no production DataStore key was read or written; ProfileStore not installed or run; nothing published. No source diffs or screenshots exist; the canary script and hash tables are included in full.

## TABLE OF CONTENTS
1. TASK-006/AUDITOR_REPORT.md
2. TASK-006/CHANGE_MANIFEST.md
3. TASK-006/TEST_EVIDENCE.md
4. TASK-006/AUDITOR_QUESTIONS.md
5. TASK-006/CANARY_RESULT.md
6. TASK-006/CANARY_SCRIPT.luau
7. TASK-006/HASH_COMPARISON_V148_V149.md

Each file is wrapped in === FILE: <path> === and === END FILE === lines and is included in full, unedited.

=== FILE: TASK-006/AUDITOR_REPORT.md ===
# AUDITOR REPORT — TASK-006: Persistence test readiness

- **Date:** 2026-10-14
- **Production (untouched):** place 132065051336560, universe 10769064643.
- **SaveTest (authorized target):** place 128620546156998, universe 10770892134.
- **Owner/auditor request:** identify SaveTest by both IDs; read production's Studio API-access setting without modifying it; compare SHA-256 of the 40 active scripts in the v148 and v149 backups; prepare a minimal canary against `TEST_LK_IsolationCanary` in SaveTest only with both IDs asserted in the script; run it only with explicit owner approval; no production DataStore reads or writes; no ProfileStore; no production edits or publishing; Outlaw City out of scope.

## Results
| Step | Result |
|---|---|
| 1 Identity | After re-listing the Studio windows, the SaveTest instance was identified by name and confirmed inside the script: **PlaceId 128620546156998, GameId 10770892134**, creator user 11752219158, place version 3, Edit mode, not running. Not the production IDs. |
| 2 Production API-access setting | **UNKNOWN.** No read method exists that avoids touching production: a script in the production window can only learn it by making a production DataStore call (prohibited), and Creator Hub in the built-in browser required a login (not performed; no credentials entered; the page was closed). Nothing was asked of the owner and nothing was changed. |
| 3 Script hashes v148 vs v149 | **40 of 40 identical** (`HASH_COMPARISON_V148_V149.md`). Whole-export comparison: 501 files each, none only on one side, 43 byte-different JSON metadata files that are identical after key sorting (ordering only), no `.luau` difference. |
| 4-5 Canary prepared | `CANARY_SCRIPT.luau`: asserts both exact SaveTest IDs, rejects production IDs, requires Edit mode, then reads, writes once, reads back. |
| 6 Canary run | **Approved by the owner ("yes") and run.** Read-before nil, one write ok, read-back ok and matching (`CANARY_RESULT.md`). |
| 7-10 prohibitions | Not violated: no production DataStore key read/written/deleted/modified; ProfileStore not installed or executed; no production edit or setting change; nothing published; Outlaw City not touched. |

## What changed anywhere
- Claude created local files only (this package; `work\v149-export\` scratch export).
- One DataStore write in total: the canary marker, in the SaveTest universe store `TEST_LK_IsolationCanary`, key `isolation_canary_v1`, owner-approved.
- No game code, Config value, setting or published content was changed by Claude.

## Implications
- **Save-data:** none for production. **Gameplay/security/performance:** none.
- The environment now has a proven write/read round trip, which is the minimum needed before persistence tests start.

## Known limitations
- Production's Studio API setting is still unknown (decision D4 depends on it).
- The canary does not prove production isolation; it proves SaveTest works. The T0 read from TASK-005 remains the only isolation evidence.
- The v148/v149 comparison covers script and exported-tree content, not the world, terrain or Lighthouse properties; the two `.rbxl` files have the same size but different hashes, unexplained.
- The SaveTest place on Roblox was compared with the backup only by counts and lengths (TASK-005), not hashes.

## Outstanding / next-step recommendation
1. Owner reads production's Game Settings > Security himself (look only) and reports on/off, or decides D4 (turn it off) directly; I will not attempt it again.
2. Decide D1 and the remaining D-items in `TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md`.
3. Next test task, if approved: place the pinned `ProfileStore.luau` in the SaveTest place only, add the guard and test-store names, and run the first rows of the test matrix v2 (C20, C22, C12 on test fixtures), each write approved.

## Ready for acceptance?
Yes as a readiness milestone. No persistence implementation is authorized.
=== END FILE ===

=== FILE: TASK-006/CHANGE_MANIFEST.md ===
# CHANGE MANIFEST — TASK-006

**Claude changed no game script, Config value, Studio setting, production data or published content, and published nothing.** The only DataStore write was the owner-approved canary marker in the SaveTest universe (see `CANARY_RESULT.md`).

Created on disk (all inside `C:\RobloxProjects\LighthouseKeepers\`):
| Path | Purpose |
|---|---|
| `docs\audits\TASK-006\AUDITOR_REPORT.md`, `CHANGE_MANIFEST.md`, `TEST_EVIDENCE.md`, `AUDITOR_QUESTIONS.md` | Standard package |
| `docs\audits\TASK-006\CANARY_SCRIPT.luau` | The exact script that was approved and run |
| `docs\audits\TASK-006\CANARY_RESULT.md` | Approval, verbatim output, interpretation |
| `docs\audits\TASK-006\HASH_COMPARISON_V148_V149.md` | SHA-256 of the 40 scripts in both backups plus whole-tree result |
| `docs\audits\TASK-006\compare_exports.py` | The small read-only Python used for the whole-tree comparison (never touches the Roblox files; run with `python -I`) |
| `work\v149-export\` | Scratch export of the v149 backup made with Rojo (not part of the package) |

Persistent data changed: one marker key `isolation_canary_v1` in store `TEST_LK_IsolationCanary` of universe 10770892134 (SaveTest). Economic values: none. Owner approval: given in chat for the canary write; the rest needed none.

Source diffs: none. Nothing from Outlaw City is in this package.
=== END FILE ===

=== FILE: TASK-006/TEST_EVIDENCE.md ===
# TEST EVIDENCE — TASK-006

**Environment:** the owner's Studio session; SaveTest window "Private lighthouse keepers" (place 128620546156998, universe 10770892134), Edit mode. Players: none. Device/emulator: none. No Play session.

**Could any test have changed production DataStore values? No.** No call in this task targeted a production instance's DataStore, and the only DataStore calls were made from the SaveTest window after IDs were asserted in the script.

| # | Test | Expected | Observed | Result |
|---|---|---|---|---|
| 1 | List Studio instances (three times in this task) | production, Outlaw City, SaveTest separate and identifiable by place ID | three windows listed as expected | PASS |
| 2 | Identity read in SaveTest with asserts | exact IDs, not production | PlaceId 128620546156998, GameId 10770892134, creator 11752219158, version 3, `IsEdit` true, `IsRunning` false; store-name line unchanged `LighthouseKeepers_PlayerData_v1` | PASS |
| 3 | Production Studio API-access setting | readable without touching production | no non-invasive method; Creator Hub login wall (browser pane, no login attempted, closed) | **UNKNOWN** |
| 4 | Script hashes v148 vs v149 | equal | 40 of 40 SHA-256 identical (`HASH_COMPARISON_V148_V149.md`) | PASS |
| 5 | Whole export v148 vs v149 | equal | 501 files each; 43 JSON metadata files differ in key order only; 0 content differences; all `.rbxm` model files byte-identical | PASS (exports only) |
| 6 | v148 export vs the TASK-001 hash inventory | no drift | all 40 hashes match `SCRIPT_INVENTORY_SHA256.txt` | PASS |
| 7 | Canary: read-before | nil | ok, nil | PASS |
| 8 | Canary: single write | succeeds | ok; version id `08DF2A11FA68EBDA.0000000001.08DF2A11FA68EBDA.01` | PASS |
| 9 | Canary: read-back | matches | ok; purpose, placeId, gameId, writtenAt all matched | PASS |

**Console output:** only the script return values quoted in `CANARY_RESULT.md`. **Screenshots / performance measurements:** none.

**Tests not performed:** ProfileStore anything; Play or multiplayer; production isolation proof beyond T0 (prohibited to query production); comparison of the live SaveTest place with the backup by hash; any comparison of the world/terrain between v148 and v149.

**Remaining regression risk:** none from this task (no game change).
=== END FILE ===

=== FILE: TASK-006/AUDITOR_QUESTIONS.md ===
# AUDITOR QUESTIONS — TASK-006

1. **Production API setting.** It cannot be read without touching production or logging in. Do you accept "owner reports it himself" as the only path, or do you want D4 (turn it OFF) treated as a precondition for any ProfileStore use regardless of its current value?
2. **Isolation evidence.** T0 (production profile key nil in SaveTest) plus a working canary round trip. Is that enough to begin SaveTest persistence tests, given that production cannot be queried to prove the canary is absent there?
3. **v148 versus v149.** Scripts are identical and the exports differ only in JSON key order, but the two `.rbxl` files have different hashes at the same size. Is a world-level comparison (for example, opening both in scratch windows and comparing instance trees) worth doing, or do you accept the script-level result?
4. **Canary marker.** The marker remains in `TEST_LK_IsolationCanary`. Leave it as a permanent environment fingerprint, or have it removed? Removal needs a `RemoveAsync`, which was prohibited so far and would need a separate approval.
5. **Next gate.** Proposed next task: place the pinned, hash-verified `ProfileStore.luau` into the SaveTest place only, add the guard and `TEST_`-prefixed names, and run the first matrix rows with fixtures. Any change to that scope before it is requested?

No further concern has been invented; items 1 and 2 are the real forks.
=== END FILE ===

=== FILE: TASK-006/CANARY_RESULT.md ===
# Canary result (TASK-006), 2026-10-14

**Approval:** the owner answered "yes" in chat to the single canary write, in SaveTest only, after the exact script (`CANARY_SCRIPT.luau`) was shown.

**Pre-run checks:** Studio instances re-listed immediately before the run; the SaveTest window was `Private lighthouse keepers (placeId: 128620546156998)`. The script asserts, before touching `DataStoreService`: PlaceId == 128620546156998, GameId == 10770892134, neither equals the production IDs, Edit mode and not running. It ran from the owner's Studio session via MCP `execute_luau` (Edit datamodel).

**Output (verbatim):**
```
{"readBefore":{"ok":true,"isNil":true},"key":"isolation_canary_v1","gameId":10770892134,"write":{"ok":true,"version":"08DF2A11FA68EBDA.0000000001.08DF2A11FA68EBDA.01"},"placeId":128620546156998,"store":"TEST_LK_IsolationCanary","readBack":{"ok":true,"matches":true}}
```

**Reading it:**
- The key did not exist before (read ok, nil): the marker was new.
- One `SetAsync` succeeded and returned a version id. The version string ends `.0000000001...`, consistent with a first version of a new key.
- The read-back succeeded and every compared field matched (purpose, placeId, gameId, writtenAt).
- Exactly one write was made. Nothing was deleted. No other store or key was touched. No production DataStore key was read, written, deleted or modified in this task.

**What this proves and what it does not**
- Proves: Studio API access works in the SaveTest universe and a write plus read-back round trip works there.
- Does not prove isolation from production. Isolation still rests on platform behaviour (stores belong to a universe) plus the earlier T0 read (the owner's production profile key was nil in SaveTest). No production store was queried to confirm the canary's absence there, because production reads are prohibited.
- The marker remains in `TEST_LK_IsolationCanary` of the SaveTest universe. It is harmless and was deliberately not deleted.
=== END FILE ===

=== FILE: TASK-006/CANARY_SCRIPT.luau ===
-- TEST_LK_IsolationCanary: runs ONLY in the SaveTest Studio instance (Edit mode, no Play).
-- Writes exactly one harmless marker into a brand-new DataStore named TEST_LK_IsolationCanary,
-- reads it back, and reports. It never touches any other store or key and never deletes anything.
-- Any ID mismatch aborts BEFORE DataStoreService is touched.

local SAVETEST_PLACE_ID = 128620546156998
local SAVETEST_GAME_ID = 10770892134 -- universe
local PROD_PLACE_ID = 132065051336560
local PROD_GAME_ID = 10769064643

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

assert(game.PlaceId == SAVETEST_PLACE_ID, "ABORT: PlaceId is not the SaveTest place: " .. tostring(game.PlaceId))
assert(game.GameId == SAVETEST_GAME_ID, "ABORT: GameId is not the SaveTest universe: " .. tostring(game.GameId))
assert(game.PlaceId ~= PROD_PLACE_ID and game.GameId ~= PROD_GAME_ID, "ABORT: production IDs detected")
assert(RunService:IsEdit() and not RunService:IsRunning(), "ABORT: must run in Edit mode, not Play")

local STORE_NAME = "TEST_LK_IsolationCanary"
local KEY = "isolation_canary_v1"

local result = { placeId = game.PlaceId, gameId = game.GameId, store = STORE_NAME, key = KEY }

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore(STORE_NAME)

-- 1) read first: the marker must not exist yet
local okBefore, before = pcall(function() return store:GetAsync(KEY) end)
result.readBefore = { ok = okBefore, isNil = okBefore and before == nil, err = (not okBefore) and tostring(before) or nil }

if okBefore and before == nil then
	-- 2) the single write
	local marker = {
		purpose = "isolation canary",
		placeId = game.PlaceId,
		gameId = game.GameId,
		writtenAt = os.time(),
	}
	local okWrite, writeErr = pcall(function() return store:SetAsync(KEY, marker) end)
	result.write = { ok = okWrite, err = (not okWrite) and tostring(writeErr) or nil, version = okWrite and tostring(writeErr) or nil }

	-- 3) read it back
	local okAfter, after = pcall(function() return store:GetAsync(KEY) end)
	result.readBack = {
		ok = okAfter,
		matches = okAfter and type(after) == "table" and after.purpose == marker.purpose
			and after.gameId == marker.gameId and after.placeId == marker.placeId and after.writtenAt == marker.writtenAt,
		err = (not okAfter) and tostring(after) or nil,
	}
else
	result.write = { skipped = true, reason = "read failed or a marker already exists; nothing written" }
end

return HttpService:JSONEncode(result)
=== END FILE ===

=== FILE: TASK-006/HASH_COMPARISON_V148_V149.md ===
# Script hash comparison: v148 export vs v149 export (TASK-006)

Method: `rojo syncback` of each local backup file into its own folder (v148 -> `src\`, v149 -> `work\v149-export\`, same project file), then SHA-256 of every active Luau script. Sources: `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl` (SHA-256 6AF4E727...03B5C8) and `..._v149.rbxl` (SHA-256 0C880E87...7307EF).

| Script | SHA-256 v148 | SHA-256 v149 | Same |
|---|---|---|---|
| `ReplicatedStorage\Shared\Ammo.luau` | `d0a5b2fa5d17a697f8f4b78a7b6d57db9fd02af868c754270e53f9862d366ce1` | `d0a5b2fa5d17a697f8f4b78a7b6d57db9fd02af868c754270e53f9862d366ce1` | yes |
| `ReplicatedStorage\Shared\Config.luau` | `b4222df56dcfd2c2185159f38890190f02a338b7fa42b77089bea2764b43b9fc` | `b4222df56dcfd2c2185159f38890190f02a338b7fa42b77089bea2764b43b9fc` | yes |
| `ReplicatedStorage\Shared\Creatures.luau` | `61a1ca06ff67c5ee5111d7306f1d545a52dee7aef3e6298670082a6d2b66ee38` | `61a1ca06ff67c5ee5111d7306f1d545a52dee7aef3e6298670082a6d2b66ee38` | yes |
| `ReplicatedStorage\Shared\Forecasts.luau` | `85df7a40568c793a0fd34890dc622fa943551c0e6e4424e696707a5f5efd5b6a` | `85df7a40568c793a0fd34890dc622fa943551c0e6e4424e696707a5f5efd5b6a` | yes |
| `ReplicatedStorage\Shared\Ground.luau` | `9800e172d6a9a903b170695fa87fe717dca52d549011b42c33f8093f2894a319` | `9800e172d6a9a903b170695fa87fe717dca52d549011b42c33f8093f2894a319` | yes |
| `ReplicatedStorage\Shared\Items.luau` | `a7864decf24be19e8fe03211adacd89a29b36810a589dc0c423b950883297b42` | `a7864decf24be19e8fe03211adacd89a29b36810a589dc0c423b950883297b42` | yes |
| `ReplicatedStorage\Shared\SoundFx.luau` | `a4617d2f9f9b4b5b2bcb5a165d2177d6cf18f1f129360af33a011bc96d24ac74` | `a4617d2f9f9b4b5b2bcb5a165d2177d6cf18f1f129360af33a011bc96d24ac74` | yes |
| `ReplicatedStorage\Shared\Upgrades.luau` | `3c235e3e349e41213f605589802a6af7b321866c19ee64c3395126a1cc202213` | `3c235e3e349e41213f605589802a6af7b321866c19ee64c3395126a1cc202213` | yes |
| `ReplicatedStorage\Shared\Weapons.luau` | `f30e0143713ffc22f74fcc0ac1d2ea44aa50a6b2a639d2ec9f2c6f87fbafa566` | `f30e0143713ffc22f74fcc0ac1d2ea44aa50a6b2a639d2ec9f2c6f87fbafa566` | yes |
| `ServerScriptService\Server\CreatureService.luau` | `6509100dee3627eb27bd21fc072bfcaa4ae336f77cecf4dd9a04b1742af59865` | `6509100dee3627eb27bd21fc072bfcaa4ae336f77cecf4dd9a04b1742af59865` | yes |
| `ServerScriptService\Server\DefenseService.luau` | `85dc771f46a816e8c5f9b3749cf8642dd6b5be39df42ee207f5878c7bec86870` | `85dc771f46a816e8c5f9b3749cf8642dd6b5be39df42ee207f5878c7bec86870` | yes |
| `ServerScriptService\Server\EventLog.luau` | `b0ba5f42d5e76dd74b4624595b8ea03b69b5be18253e64d624524df685a17e29` | `b0ba5f42d5e76dd74b4624595b8ea03b69b5be18253e64d624524df685a17e29` | yes |
| `ServerScriptService\Server\GameState.luau` | `4905278ebe874e08806dc0c9b3099033abe25232d87721f17ad121b7969b2d17` | `4905278ebe874e08806dc0c9b3099033abe25232d87721f17ad121b7969b2d17` | yes |
| `ServerScriptService\Server\IslandBuilder.luau` | `568f60659b72af4aaa7e4fa4c973d2b252c265f760212a66c03b9b1aea350495` | `568f60659b72af4aaa7e4fa4c973d2b252c265f760212a66c03b9b1aea350495` | yes |
| `ServerScriptService\Server\LampService.luau` | `4f24d0c099f4bc5b890d44cbc9c0c9ace24e5df022b5137a8eb31a9d1d64c72b` | `4f24d0c099f4bc5b890d44cbc9c0c9ace24e5df022b5137a8eb31a9d1d64c72b` | yes |
| `ServerScriptService\Server\LoadoutService.luau` | `7c22d49a96f5204ac96c06a451cb0e3265d2ea39e5ab83d7db3c7580b2bf846c` | `7c22d49a96f5204ac96c06a451cb0e3265d2ea39e5ab83d7db3c7580b2bf846c` | yes |
| `ServerScriptService\Server\LobbyBuilder.luau` | `5a393609e4d58c03adc1f1031b8abcbbc0c5b7a568c8945643311d509b4b6f39` | `5a393609e4d58c03adc1f1031b8abcbbc0c5b7a568c8945643311d509b4b6f39` | yes |
| `ServerScriptService\Server\LootService.luau` | `7f638abd17905889226bf98be089e8327a4f7546aee0456f5782ac8e2f16e840` | `7f638abd17905889226bf98be089e8327a4f7546aee0456f5782ac8e2f16e840` | yes |
| `ServerScriptService\Server\Main.server.luau` | `dd87123de266d4f6bea927772c1e8e2f05921c89652e837272ac6c63d7852689` | `dd87123de266d4f6bea927772c1e8e2f05921c89652e837272ac6c63d7852689` | yes |
| `ServerScriptService\Server\PlayerData.luau` | `8413e9ff936a86f0b9d7fc26d6b5174a430d3b4119a2b5f1c00d3762a4bdd2d8` | `8413e9ff936a86f0b9d7fc26d6b5174a430d3b4119a2b5f1c00d3762a4bdd2d8` | yes |
| `ServerScriptService\Server\ShopService.luau` | `0f9b436801b78ed3aeff912463775a336a682623cee1dbb30c28bb0e805e61b9` | `0f9b436801b78ed3aeff912463775a336a682623cee1dbb30c28bb0e805e61b9` | yes |
| `ServerScriptService\Server\TowerService.luau` | `399936e547b2a417d3a1c764830cc2fba5620ff42ce32a56b13f2b524b106e3c` | `399936e547b2a417d3a1c764830cc2fba5620ff42ce32a56b13f2b524b106e3c` | yes |
| `ServerScriptService\Server\UpgradeService.luau` | `4f602505e2cc6c050125c09823aec36e7823526f5e3c24a8ceec40b79999cd46` | `4f602505e2cc6c050125c09823aec36e7823526f5e3c24a8ceec40b79999cd46` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Bench.client.luau` | `b16d2095ac834770bd8579e7d3e4fb1857605fc7b76ca2f9acebea4550e881d2` | `b16d2095ac834770bd8579e7d3e4fb1857605fc7b76ca2f9acebea4550e881d2` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Coach.client.luau` | `29658a3c8b75f2dbff160fe7072172a900980c04e12129a48d5562953ee5e727` | `29658a3c8b75f2dbff160fe7072172a900980c04e12129a48d5562953ee5e727` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Departure.client.luau` | `c093df3d228f3d77503f2562e6d911b65081c4d3e093072a6cf60440b88552a5` | `c093df3d228f3d77503f2562e6d911b65081c4d3e093072a6cf60440b88552a5` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Gear.client.luau` | `81bea29c387547fbbb8f62b2d7c9c6f8873be3464756848d2a503e648c360321` | `81bea29c387547fbbb8f62b2d7c9c6f8873be3464756848d2a503e648c360321` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Hud.client.luau` | `6306b37a82b97934ebc36ac547e19544654035ff00adb609851c84ffe6b38845` | `6306b37a82b97934ebc36ac547e19544654035ff00adb609851c84ffe6b38845` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Inventory.client.luau` | `53ffb620f2d70a4e9724c3ac115373f7a32a6e166dd7409f8ee1dce3c121e845` | `53ffb620f2d70a4e9724c3ac115373f7a32a6e166dd7409f8ee1dce3c121e845` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\ItemPreview.luau` | `12dea9ec221d7c455c921f15c33a4d01a222a8987e588e3e5badec99ba60864e` | `12dea9ec221d7c455c921f15c33a4d01a222a8987e588e3e5badec99ba60864e` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Main.client.luau` | `e583e8b1968edf0585285b885d3f5476a408736b366238766c3edf71c77e1a7e` | `e583e8b1968edf0585285b885d3f5476a408736b366238766c3edf71c77e1a7e` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Menus.client.luau` | `77ccf24d03906c6b8e1a3161113abac7796eec402f40ac3f683e3dfed4f1208a` | `77ccf24d03906c6b8e1a3161113abac7796eec402f40ac3f683e3dfed4f1208a` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Results.client.luau` | `1027b5275680e2e7974f7c91d72f1fdac2a6235e4b6eb8de3689e24ca9ed1ab2` | `1027b5275680e2e7974f7c91d72f1fdac2a6235e4b6eb8de3689e24ca9ed1ab2` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Shop.client.luau` | `01ef55e238c03a1a3e99fc937709759a1aa4d1c0c6cf53edaac05d3f30ed56df` | `01ef55e238c03a1a3e99fc937709759a1aa4d1c0c6cf53edaac05d3f30ed56df` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Storm.client.luau` | `6cf05b15fc086655dd031e162066fbdf085b42f9ce7fb17012d30501e5b1ea27` | `6cf05b15fc086655dd031e162066fbdf085b42f9ce7fb17012d30501e5b1ea27` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Trader.client.luau` | `9479fa3f5bfa52aedc1b0f2c8a0423278b18342d5059421c255ff51f41c403d5` | `9479fa3f5bfa52aedc1b0f2c8a0423278b18342d5059421c255ff51f41c403d5` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\UiKit.luau` | `afdf85146514b96fcce3de40b8c8208d3da18cfa10b26792055748fe99b98fae` | `afdf85146514b96fcce3de40b8c8208d3da18cfa10b26792055748fe99b98fae` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\UiSkin.luau` | `5cb8eec90c97e5df27a7edd754d0fb49d48ea009e9a2f2cae25fb40f9a1887a5` | `5cb8eec90c97e5df27a7edd754d0fb49d48ea009e9a2f2cae25fb40f9a1887a5` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\UiStyleSheet.client.luau` | `1c4803bb282bf8c98fcbdcf374b073672cdde63b1405e937020dc20368b0572f` | `1c4803bb282bf8c98fcbdcf374b073672cdde63b1405e937020dc20368b0572f` | yes |
| `StarterPlayer\StarterPlayerScripts\Client\Vitals.luau` | `1813ed69746d4eeeb083fd17ea23f24f48ad9a1023a6aeeb5564bbd59ae9bee1` | `1813ed69746d4eeeb083fd17ea23f24f48ad9a1023a6aeeb5564bbd59ae9bee1` | yes |

**Result: 40 of 40 scripts identical.**

Whole-export comparison (all 501 files in each export, including the in-Studio backup folders under `ServerStorage` and the `.rbxm` models): no file exists in only one export; 43 files differ in bytes, and **all 43 are JSON metadata files whose content is identical once keys are sorted** (property order only, for example `Disabled` and `SerializedOverrides` in a different order). No `.luau` file differs. Script: `compare_exports.py` in this folder.

Not compared: the world itself (Workspace, terrain, Lighting properties, UI instances outside scripts) because the export project maps only script-bearing services; the two `.rbxl` files have the same size (809,189 bytes) but different hashes, which this comparison cannot explain. Also, the SaveTest place on Roblox was compared with the backup only by counts and script lengths (TASK-005), not by hash.
=== END FILE ===

