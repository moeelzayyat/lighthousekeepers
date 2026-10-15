# R3 real-server test plan (TASK-010) — PROPOSAL, NOT APPROVED, NOT RUN

## 1. Context and why
- **Context:** a Studio **Play** session of the SaveTest window, started and stopped through MCP `start_stop_play` (the MCP tool can only start Play, which also adds the owner's avatar as a client; it cannot start the server-only "Run" mode, which would need the owner's click). Test code runs through MCP `execute_luau` in the **Server** DataModel of that session.
- **Genuine server?** The Play server is a separate server DataModel (`RunService:IsServer()` true, fresh module cache, `BindToClose` fires on Stop). Whether MessagingService works in a Studio Play server is **not known**; step 3 measures it. If it does not, MessagingService can only be tested on a real published server, which would need: one publish of the SaveTest place by the owner (with `Main` disabled and the runner inside), joining it from the Roblox client, and an in-server trigger. The MCP cannot execute code in a live server, so that trigger would have to be an auto-running, authorization-gated Script. That conflicts with the "no auto-running test Script" rule, which is why it is **not** proposed now.
- **Prerequisite:** the disable manifest (`Main.Enabled = false`) applied first, so the game's `PlayerData` cannot run and the avatar's data is never loaded or saved.

## 2. Test sequence (the auditor's six items)
| # | Step | DataStore effect |
|---|---|---|
| 1 | Server identity: PlaceId, GameId, JobId, IsServer, IsStudio, PrivateServerId | none |
| 2 | ProfileStore initialization in the server (fresh module in the server DataModel) | **1 write** `____PS`/`____PS` by the library's Studio probe (known; a fresh server always re-runs it); probe key read before and after |
| 3 | MessagingService: subscribe to `TEST_LK_R3_<id>`, publish one message to itself, check receipt, disconnect; `BindToClose`: register one no-op callback and record whether it is allowed | none (MessagingService is not a DataStore) |
| — | Regression fixture `player_900000201` | **read only** (expect 25 Pearls, released) |
| 4 | Fresh synthetic session on `TEST_LK_ProfileStore_v2/player_900000202` (must not exist; abort without writing if it does); record the stored lock (should carry the server JobId) and whether the library's own takeover subscription succeeded | **1 write** (session start) |
| 5 | Pearls = 30, `Save`, confirm in the store; `EndSession`, confirm release **from the stored record** | **2 writes** (save, release) |
| 6 | Shutdown registration: evidence from step 3 and from the console (no "BindToClose can only be called on the server" error); then Stop Play through MCP | **0 writes expected** (no profile is active at Stop) |
**Expected writes: 4** (1 probe + 3 on `player_900000202`). Retries, if any, appear as `[ProfileStore]: DataStore API error` lines and are recorded separately. Reads: probe key 2, fixture 1, test key about 6.

## 3. Exact execution steps (after approval)
1. Re-list Studio windows; assert SaveTest IDs.
2. Apply the disable manifest in Edit mode (`Main.Enabled = false`); verify.
3. Confirm runner and guard hashes in Edit mode.
4. `start_stop_play(true)` on the SaveTest window only.
5. In the **Server** DataModel: assert IDs and server state; set `Guard.APPROVED.R3_SERVER_SESSION = true`; call `R3.startReal()` once. Never resend this command.
6. Poll `R3.status()` (in-memory only) until `done` or `failed`.
7. Read the Studio console.
8. `start_stop_play(false)`.
9. Back in Edit mode: read-only check of `player_900000202`, `player_900000201` and `____PS`.
10. Leave `Main` disabled until the auditor accepts, or roll back on request.

## 4. Safeguards
- **No accidental run:** the runner is a ModuleScript in `ServerStorage`; starting Play runs nothing of it. It refuses unless the per-operation flag is true, the IDs match, and it is inside a running server. The flag starts false in every new server DataModel and is reset by the runner on every exit.
- **Single run:** the flag lock, `status ~= "running"`, and the key-absent precheck (a second run after success writes nothing).
- **MCP timeout:** `startReal` returns at once; the start command is sent once and never re-sent; only status reads follow.
- **Unexpected Stop or Studio crash mid-test:** the library's `BindToClose` (if registered) releases the session; otherwise the lock on `player_900000202` expires after 630 s. Only that synthetic key is affected. If ProfileStore cannot release, the record stays locked but unchanged.
- **Unexpected anything:** stop, report, no retry.

## 5. Rollback
`Main.Enabled = true` in SaveTest, or restore `SaveTest_TASK-010_pre.rbxl`. The synthetic records (`player_900000201`, `player_900000202`) and the `____PS` probe key may stay; they are inert test data in the SaveTest universe.

## 6. Known limitations
- MessagingService behaviour in a Studio Play server is unknown until measured; a published-server test would cost a SaveTest publish and an auto-running trigger.
- The avatar's client scripts will run and wait for remotes (harmless noise in the output).
- Shutdown *release* of an active profile is not tested in this first run (no profile is active at Stop). A later test could leave a session open on a third synthetic key and Stop, then read it from Edit.
- Real takeover, legacy overwrite, migration and live player data are out of scope.
