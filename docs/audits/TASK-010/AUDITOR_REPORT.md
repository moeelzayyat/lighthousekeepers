# AUDITOR REPORT — TASK-010: Real-server test preparation

- **Date:** 2026-10-14
- **Target:** SaveTest place 128620546156998, universe 10770892134. Production and Outlaw City untouched. **Preparation only: no server run, no DataStore write, nothing published.**

## Phase A
IDs verified in-script; fresh owner backup `SaveTest_TASK-010_pre.rbxl` verified; pinned ProfileStore and all test-script hashes verified inside Studio; the regression fixture `player_900000201` was not touched. Auto-run inventory: of 99 scripts, only `ServerScriptService.Server.Main` runs at server start, and it is the only path to the game's sole DataStore user (`PlayerData`). **Proposed smallest disable set: `Main.Enabled = false` in SaveTest** (not applied; `SCRIPT_DISABLE_MANIFEST.md`).

## Phase B: server runner
`ServerStorage.TestOnly.R3ServerRunner` (ModuleScript, SHA-256 `bff3b190…5773`) plus a guard entry `R3_SERVER_SESSION` (guard SHA-256 `4d85ffc6…500d`). Properties:
- runs only when both exact SaveTest IDs match, the per-operation flag is true, and it is inside a **running server** (refused in Edit even with the flag, shown by execution);
- reaches only `TEST_LK_ProfileStore_v2/player_900000202` for writes, reads the fixture `player_900000201` and the `____PS` probe key only, exposes only `New`, `StartSessionAsync` (no params), `Save`, `EndSession`;
- records identity (PlaceId, GameId, JobId, IsServer, IsStudio), ProfileStore state, MessagingService subscribe/publish/receive on a `TEST_LK_R3_` topic, BindToClose registration, the library's own takeover subscription, stored lock, saved value, release status;
- **is inert**: a ModuleScript never auto-runs, Play does not start it, nothing requires it, the flag starts false in every new server and is reset by the runner on every exit;
- dry run on fakes passed with the expected writes (fake probe + 3 on the new key).

## Phase C: proposed first real-server test
Identity, ProfileStore init, MessagingService check, fresh session on `player_900000202`, Pearls 30 save and release, BindToClose registration (`SERVER_TEST_PLAN.md`). **Expected real writes: 4** (1 `____PS` probe from the fresh server module + 3 on `player_900000202`). Context: Studio Play started and stopped through MCP; code runs in the Server DataModel; the game's `Main` disabled so the owner's avatar data is never loaded or saved.

## Whether Studio is enough
- **BindToClose:** a Studio Play server is a real server DataModel, so registration should work. The test records it.
- **MessagingService:** unknown in a Studio Play server, and the test measures it. If it does not work, only a published SaveTest server can test it. That would need the owner to publish SaveTest, players joining through the Roblox client, and an in-server trigger. The MCP cannot reach live servers, so the trigger would be an auto-running, authorization-gated Script, which conflicts with the current rule against auto-running test Scripts. It is therefore not proposed.
- **Server-only "Run" mode:** the MCP tool can only start Play (with the avatar). Run mode would need the owner to click Run, and it is not required once `Main` is disabled.

## Implications
None yet. If approved: SaveTest gains `Main` disabled (reversible), one probe write, and one new synthetic record. No change to game code contents, economy, gameplay or production.

## Known limitations
See `SERVER_TEST_PLAN.md` section 6.

## Ready for audit
Yes. Stopped before any server test. Execution needs the owner's explicit approval of the exact runner, manifest and plan.
