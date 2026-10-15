# Batch 1 change manifest: gameplay reliability (2026-10-14)

**Target:** Lighthouse Keepers, PlaceId `132065051336560`, GameId `10769064643`. Studio window "Lighthouse Keepers - Staging", place version 150.

**Not done:**
- not published;
- no PlayerData change and no save schema change;
- no DataStore write;
- Studio API access left **off**, verified before testing: a probe read was refused with "Studio access to APIs is not allowed";
- SaveTest and Outlaw City not touched.

## Rollback copies
- **Full place:** `backups\2026-10-14\LighthouseKeepers_2026-10-14_v150_pre-batch1.rbxl`, saved by the owner.
  - 809,189 bytes, header `<roblox!`, SHA-256 `7A76DD6BEA03B7C5A73AFD85638B5B07622779318F2CF15694A1B6077C8EEF8E`.
  - Rojo export in `work\v150-export`: the scripts are identical to v149.
- **In Studio:** `ServerStorage.Backups.Batch1_before_2026-10-14` holds disabled clones of all 7 scripts, taken before any edit.
- **On disk:** `before\` (exact pre-batch text) and `after\` (exact post-batch text). The sizes of `before\` equal the Studio sources before the edit.

## Scripts changed (SHA-256 after; verified inside Studio, all compile)
| Script | Change | SHA-256 after |
|---|---|---|
| `ReplicatedStorage.Shared.Config` | adds `MAX_CREW = 4` | `41b4f0ab4fba08b9a0c820145a16187a637d304a3cb97261b2dae672acb30df8` |
| `ServerScriptService.Server.Main` | crew cap: `crewIsFull`; `joinCrew` refuses a 5th Keeper with a message and returns false; a first-time player is not fast-routed into a full crew | `79fe2532247862476c9f239ea695c38b989d67e3236183617096bee35306526a` |
| `ServerScriptService.Server.LampService` | the fuel-drain crew multiplier counts Ready crew, not every player on the server (GP-2) | `9222d36fd7222ea0a29119a7849720d73828457845e4664d944d19017e4c1842` |
| `StarterPlayer...Client.Main` | controller Keeper: either thumbstick aims, Y switches beams, B leaves the lamp (GP-44); a held finger or stick re-sends its aim once a second, so the 25 s idle release no longer fires on a held aim (GP-3) | `846ce8e5eabc4ddbb299f05d21debfe95092433f26e121d44b2d4c89002c40e3` |
| `StarterPlayer...Client.UiKit` | closing a menu no longer turns the phone joystick back on while you are the Keeper (GP-43) | `0dc898972864927f8ff95d721257ccd3b28b6004173509223d0e2f23e2bba4d0` |
| `StarterPlayer...Client.Hud` | Keeper buttons show "· Y" and "· B" on a controller | `d1c0cc19583c6b8677e96f7f1e28bf274b6ea7e87753ab0ce89dde8047cf30a6` |
| `StarterPlayer...Client.Coach` | coach hints for "focus" (Y) and "aim" (left stick) on a controller | `7a040636c2cf8eb55da0da432f6194dc74c4f51a1f659cb3930d1fc1d8f6b900` |

No prices, rewards, drain numbers or other balance values were changed. The existing table `FUEL_DRAIN_BY_CREW_SIZE = { 0.7, 0.85, 1, 1 }` is unchanged. Only who counts as "crew" changed.

## Rollback
For each script, copy the Source of the clone in `ServerStorage.Backups.Batch1_before_2026-10-14` back over it, or use the `before\` files. Alternatively, restore the v150 `.rbxl`.
