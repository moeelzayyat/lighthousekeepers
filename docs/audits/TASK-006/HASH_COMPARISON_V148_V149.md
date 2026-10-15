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
