# Safe persistence test environment: a separate private test experience (TASK-004) — PROPOSAL ONLY

**Nothing has been created or published. The owner must approve explicitly, and the owner (not Claude) performs the Creator Hub and publish steps.** I do not assume that a local `.rbxl` is DataStore-safe: the backup check only recorded `PlaceId 0` and `GameId 0`, and the Roblox pages I read say nothing about local files (they say only that Studio, by default, cannot access data stores until "Enable Studio Access to API Services" is turned on, and warn that Studio then uses the same data stores as the live game). So local-file tests are treated as "unknown", never as protection.

## 1. Goal
A real Roblox universe with its own DataStores, in which real DataStore concurrency, takeover, failure, shutdown and migration behaviour can be exercised without any path to production player data.

## 2. Setup, step by step (owner actions, in this order)
1. **Create a new experience** in Creator Hub, for example "Lighthouse Keepers SaveTest". Keep it **Private**; do not list or monetize it. Note its **Universe ID** and **Place ID** and send them to Claude.
2. **Close the production Lighthouse Keepers Studio window** (and leave Outlaw City alone) so the wrong target cannot be chosen by accident.
3. In Studio, open the backup file `backups\2026-10-14\LighthouseKeepers_2026-10-14_v148.rbxl` (File > Open from File). The backup contains scripts, world and UI but **no player data** (DataStore data is not stored in a place file).
4. Use **File > Publish to Roblox As...** and pick **the new SaveTest place explicitly**. Do not pick "Lighthouse Keepers - Staging". If the dialog highlights the production experience by default, change it before confirming.
5. **Verify before anything else** (Claude does this read-only through MCP): the instance reports a `GameId` different from 10769064643 and a `PlaceId` different from 132065051336560. If either matches, stop.
6. In the **SaveTest** experience only, enable Game Settings > Security > "Enable Studio Access to API Services". The Roblox page recommends enabling this only on a separate test version, never on a live game.
7. **Recommended: turn that same setting OFF on the production experience**, so that Play sessions in the production Studio window can no longer write to the live DataStores. (Progress notes say Studio currently shares the live DataStore.) This is the owner's call.
8. No Open Cloud API keys are created and no credentials are shared with Claude.
9. Test accounts: the owner's test account(s) join the SaveTest experience. Because it has its own DataStores, those accounts get fresh profiles there.

## 3. Isolation argument and its check
Roblox DataStores belong to an experience (universe); the same store name in a different universe is a different store. I am relying on that general platform behaviour and did not find a page stating it in the sources I read, so it is verified by a gate test **T0**: in the SaveTest universe, a read of the key that exists in production for the owner's real profile (`player_11752219158`) must return nil, and a marker written to the SaveTest store must not be visible from production (verified only by the owner's own observation or a read-only check, never by writing to production). If T0 returns any data, **stop all testing** and escalate.
Additional guards in test code: an `assert(game.GameId ~= 10769064643)` at the top of every harness script, a `Config.ENVIRONMENT = "test"` flag the persistence code refuses to run without when the test hooks are enabled, and store names prefixed `TEST_` for fixtures.

## 4. What can be tested there that cannot be tested anywhere else
- Real `UpdateAsync` semantics, retries, throttling, latency and error codes against real DataStore servers.
- Two real servers: Studio "Test" runs a single local server, so true cross-server behaviour needs published servers. Reserved or private servers of the test place (TeleportService) give a controlled second server for the same account (leave A, join B quickly).
- Real shutdown via Creator Hub's shutdown/restart controls, including `BindToClose` timing.
- Mixed deployment: publish build N, keep its server up, publish build N+1, and join both.
- Library behaviour on a legacy-shaped record (test C12) in a store whose loss does not matter.
- Versioning/recovery behaviour (tests C11).

## 5. Data policy in the test universe
Fixtures are synthetic (fake UserIds such as `900000001`) or created by the test accounts. **No export of production records is made or needed.** If a realistic v1 shape is required beyond what the source code defines, the owner supplies one anonymised example explicitly.

## 6. Cleanup and risks
- When finished, the owner can delete the experience or leave it private; its stores are separate.
- Risks: choosing the wrong publish target (mitigated by steps 2, 4 and 5); the test place drifting from production code (mitigated by deriving it from the dated backup and recording the version); Roblox behaviour in a quiet private universe differing under production load (acknowledged; the soak period after cutover covers that).
