# TASK-012 AUTHORIZATION REQUEST: shutdown test (R4) and two-server test (R5)

- **Date:** 2026-10-14
- **Target:** SaveTest only, PlaceId `128620546156998`, GameId `10770892134`. Production and Outlaw City are not touched.
- **State:** preparation only.
  - No test has run.
  - No real DataStore, MessagingService or teleport call has been made for R4 or R5.
  - Nothing has been published.
- **Approval:** each test needs the owner's explicit approval, separately. R5 also needs the owner's two publish actions.

## Phase A: current work preserved

**Studio instance**
- Re-listed. SaveTest is asserted in every script by both IDs.
- `Main.Enabled = false` (still disabled).

**Backup `backups\2026-10-14\savetest\SaveTest_TASK-012_pre.rbxl`**

| Property | Value |
|---|---|
| Saved by | the owner |
| Size | 840,982 bytes |
| Header | valid `<roblox!` |
| SHA-256 | `89D64D2E75BF5967AFC7F73C58AEA971BD08C886DC37B1C2A03F1FCF8009D1F6` |

A Rojo export of the backup shows:
- `Main` disabled;
- ProfileStore `ad437372…`, R3 runner `6083eca5…`, guard `194e30d3…` and R4 runner `1a125835…`, all matching.

The R5 module and its bootstrap were installed *after* this save. Their sources are on disk, listed in section 4.

**Synthetic records:** `player_900000201` (25 Pearls) and `player_900000202` (30 Pearls) are preserved fixtures. Every new test uses fresh keys and only reads these two.

## Phase B: R4, release of an active profile at shutdown (Studio Play)

| Item | Definition |
|---|---|
| Code | `TestOnly.R4ShutdownRunner` `1a125835…7613`, guard `194e30d3…400b`, ProfileStore `ad437372…95f`. Commands: `R4_run_command` `d93d62d3…ed31`, `R4_status_command` `287eeadc…866a`, `R4_post_stop_check` `703311f6…8417` |
| Target | SaveTest Studio Play server (one), key `TEST_LK_ProfileStore_v2/player_900000203` (fresh) |
| What it does | Registers a read-only BindToClose observer. Starts a session. Sets `pearls = 40` **in memory only (no Save)**. Confirms the store still holds 0 with the session active, then holds. The approved **Stop Play** is the only thing that can persist the 40, through the library's own BindToClose release. |
| Expected writes | **3:** `____PS/____PS` probe (1), session start (1) and shutdown release (1) on `player_900000203` |
| Expected result | After Stop, an uncached Edit read shows `pearls 40`, `ActiveSession` absent and `SessionLoadCount 1`. The console shows `[R4] OnSessionEnd fired` and `[R4] observer: released=true …`. Fixtures 201 and 202 are unchanged. |
| Stop rule | Stop Play only when `readyForApprovedStop = true`: holding, flag reset, session active, observer registered, and held for less than 240 s (the library autosaves at 300 s). If R4 fails before the hold, the R3 rule applies (`safeToStopAfterFailure`), and otherwise I report and ask. |
| Failure criteria | After Stop: `ActiveSession` still set (lock left); `pearls` ≠ 40 (lost or partial write); the observer printed `released=false` or nothing (Studio cut shutdown short); or any ProfileStore error in the console |
| Cleanup | On success: none (the record stays as a fixture). On a lock left behind: report and ask. A Studio server can reclaim the lock, because Studio's JobId is `""` on both sides, and then release it. The library also treats a lock as dead after 630 s. Either path is a separate, approved step. |
| Evidence | Run result, status JSON, console after Stop, post-stop uncached reads (with version and UpdatedTime) |
| Dry run (fakes, done) | Refused without approval, and refused in Edit. Mock passed: before shutdown 0 Pearls with an active session, after the simulated shutdown 40 Pearls, released, load count 1. Writes: fake probe and 2 × `UpdateAsync player_900000203`. |

## Phase C: R5, cross-server ownership (two published SaveTest servers)

**How two real servers exist.**
- Server **A** is the public SaveTest server that account 1 joins.
- When account 2 joins A, the test teleports account 2 into a **new reserved server B** of the same place (`TeleportOptions.ShouldReserveServer`).
- Roles are fixed by server type (public versus reserved), never by timing.
- A server only runs while a player is in it. One account cannot be in two servers at once. **A second Roblox account is therefore required.**

**Control.** The MCP cannot reach live servers. The only auto-running piece is `ServerScriptService.TestOnly_R5Bootstrap`, which **fails closed** unless every gate below passes:
- not Studio;
- both SaveTest IDs match;
- JobId is non-empty;
- the attribute `AuthTest = "R5_CROSS_SERVER"` is set;
- the current time is inside an `AuthNotBefore`/`AuthNotAfter` window of at most 3 h, which the arm command sets to 2 h;
- `AllowedUserIds` lists exactly 2 accounts. Anyone else is kicked while the test is authorized.

It is also one-shot: a role does nothing if its results record, or (for A) the handover key, already exists. The bootstrap is installed now, **disabled and with no attributes**.

| Item | Definition |
|---|---|
| Code | `TestOnly.R5CrossServer` `ed6765f9…93e6`, bootstrap `85d7bae6…c17f`, guard `194e30d3…400b`, ProfileStore `ad437372…95f`. Commands: `R5_arm_command` (template) `408d9431…0a2c`, `R5_results_check` `9f7e87d1…05ba`, `R5_disarm_command` `c218b130…4d67` |
| Keys | `player_900000204` (handover), `player_900000205` (stolen), results `TEST_LK_R5_Results/A` and `/B` |
| Sequence | **A:** holds 204 (saved 50, then 55 in memory only) and holds 205 (saved 70); then teleports account 2. **B:** waits until it sees A holding both keys. **Handover:** B starts 204 normally; the library writes ForceLoadSession and asks A over MessagingService; A releases with 55; B loads it. **Steal:** B takes 205 with `{Steal = true}` (no message) and saves 80. **Stale write:** A, still believing it owns 205, tries to save 999. **Finish:** B re-saves 80, saves 60 on 204, releases both, and each server writes its results record. |
| Expected writes | **16** (no `____PS` probe in live servers). 204: 7 (A start, A save, B force-load request, A release, B acquire, B save, B release). 205: 7 (A start, A save, B steal, B save, A's fenced attempt, B re-save, B release). Results: 2. A's fenced attempt commits the same content, because ProfileStore's transform always returns the record; the data is unchanged. If A answers slowly, B repeats its load every 10 s, adding at most 4 writes on 204 before stealing at about 40 s. |
| Expected result | All 12 evaluator checks are true (`R5.evaluate`, used for both the mock and the real results). In particular: distinct non-empty JobIds; A public and B reserved; handover via messaging with B loading 55; one owner after handover; the 999 never stored; A's session ended; B unaffected; both released; final values 60 and 80. Takeover time is recorded (about 5 s expected). |
| Failure criteria | Any check false, a results record missing, or a teleport failure. Messaging failure shows as `handoverViaMessaging = false` with a takeover of about 40 s or more. |
| Failure behaviour (dry run with every message dropped) | B stole 204 after 45 s and loaded **50**, so A's unsaved 55 was lost; committed data was intact. A never learned of the takeover, timed out after 240 s, and never reached its 999 attempt. Its recovery release writes were fenced, and the stored values stayed 60 and 80. The evaluator reported 4 checks false (handoverEndedOnA, handoverViaMessaging, handoverLoadedLatestCommitted, staleOverwriteBlocked), and staleHolderSessionEnded was also false, so R5 counts as failed. That run had 20 writes, not counting the fake probes: 7 on 205, 11 on 204 (B's repeated load attempts before the steal) and 2 results records. Two of those are A's fenced recovery releases, one on each key. 20 is the upper bound I expect for R5. |
| Cleanup | B releases both keys. A ends any session it still believes it owns. When the players leave, the library's BindToClose releases anything left. Then `R5_disarm_command` deletes the bootstrap in Studio, and **the owner publishes once more** so the live SaveTest no longer contains it. Its time window is also an expiry: after 2 h it is inert even if the cleanup publish is late. A lock left behind is reported, never forced. |
| Evidence | Both results records, which hold each server's full log, JobId, PrivateServerId and timings. Uncached results-check reads of 204, 205 and fixtures 201 to 203, with the evaluator output. The arm result with its exact window. |
| Dry run (fakes, done) | Two logical servers (`JOB_A`, `JOB_B`) sharing one fake store and messaging: **all 12 checks true**, takeover 5.0 s, 1 message published. Writes match the list above (plus 2 fake Studio probes that do not occur live). |

**Owner actions R5 needs. These are the only manual steps.**
1. **Publish SaveTest:** in the "Private lighthouse keepers" window, File > Publish to Roblox. This is required because live servers run the published version. Before you click, I confirm in-script that this window is SaveTest and that the bootstrap is armed.
2. **Join with account 1** (PC), from the SaveTest page `roblox.com/games/128620546156998`. This creates server A.
3. **Join with account 2** (another device). It is moved to server B automatically. Stay in both until I say the results are in. I watch them from Studio.
4. **Cleanup publish:** File > Publish to Roblox again, after I have removed the bootstrap.

**Prerequisite to settle before arming:**
- SaveTest is private, so account 2 must be allowed to join it.
- I have not verified which Roblox setting does this for a private, user-owned experience. I will confirm the exact setting with you before arming.
- If the only way is making SaveTest public for the 2-hour window, the bootstrap's allowlist kicks everyone else.

## Writes never permitted
Production stores, Outlaw City, real player saves, fixtures 201 and 202 (read only), any key not named above, `RemoveAsync`, and any publish of the production experience.

## Approvals requested
1. **R4** exactly as in Phase B: one Play server, one run, the approved Stop Play, and the read-only post-stop check.
2. **R5** exactly as in Phase C. This requires:
   - the two account UserIds (substituted into the arm template, the only change allowed);
   - the access setting for account 2;
   - the owner's two publishes of SaveTest only.

R4 can run on its own. R5 waits for the second account.
