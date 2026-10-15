# QUESTIONS REQUIRING OWNER / AUDITOR APPROVAL — TASK-010

1. **Approve the disable manifest?** `ServerScriptService.Server.Main.Enabled = false` in SaveTest only (reversible). Without it, a Play session runs the whole game, and the game's `PlayerData` loads and may save the owner's avatar data in the SaveTest copy of `LighthouseKeepers_PlayerData_v1`.
2. **Approve the R3 runner and plan as written?** That covers `R3ServerRunner` SHA-256 `bff3b190…5773`, guard `4d85ffc6…500d`, the draft run command, the new key `player_900000202`, 30 Pearls, and 4 expected writes (1 probe and 3 on the new key).
3. **Studio Play (avatar joins) as the server context?** It is started and stopped through MCP, so no clicks are needed from you. The alternative is "Run" (server only), which needs your click.
4. **The `____PS` probe write.** A fresh Play server always re-runs the library's probe once. Accept it as part of R3?
5. **MessagingService.** If it turns out not to work in a Studio Play server, should MessagingService testing be deferred? Or do you want a design for a published-server test? That design would need an authorization-gated auto-running Script and one SaveTest publish by you.
6. **After the test**, keep `Main` disabled in SaveTest for further tests, or re-enable it straight away?
7. **Shutdown release of an active profile.** Do you want it as a separate later test? It would leave a session open on a third synthetic key, stop Play, then verify the release from Edit.

Items 1, 2 and 5 are the real decisions.
