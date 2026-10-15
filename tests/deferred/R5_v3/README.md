# R5 v3 (DEFERRED): two-server ProfileStore ownership test

**Status: UNTESTED.** It was not passed and has never run live. The owner deferred it on 2026-10-14 because a second Roblox account is not available. The auditor accepts R1 to R4 within their tested scope only.

## Contents
- `luau/`: the reviewed v3 source and commands. SHA-256 values are in `SHA256SUMS.txt`.
  - `R5CrossServer.luau`, `SaveTestGuard.luau` (the v3 guard, which also holds R2 to R4 entries), `TestOnly_R5Bootstrap.server.luau`.
  - `R5v3_install_command`, `R5v3_arm_command` (template), `R5v3_results_check`, `R5v3_disarm_command`.
- `evidence/`: the final authorization request, the preflight report, the deferral note, and the 12 mock scenario results with their note.

## To resume later (all of this needs fresh approvals)
1. A second Roblox account controlled by the owner, added as a collaborator on SaveTest only. SaveTest is unrated, so non-owners see "not accessible".
2. A fresh SaveTest `.rbxl` backup.
3. The bootstrap reinstalled from `luau/TestOnly_R5Bootstrap.server.luau`. It was removed from the SaveTest working copy in TASK-013. Check its hash against `SHA256SUMS.txt` and keep it disabled.
4. An approved arming and publishing checklist, then the steps in `evidence/R5_FINAL_AUTHORIZATION_REQUEST.md`.

## Wording rules for any future report
- Report the five groups independently.
- Never present a mock pass as a live pass.
- Never classify a teleport failure as a ProfileStore failure.
- Never describe an unresolved engine call as forcibly cancelled.
