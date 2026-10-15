> **CORRECTION (2026-10-14, TASK-007 mock tests):** two statements below about *cancelled* loads are too strong. A Cancel that is true from the start causes no write; the overwrite and the empty-record creation happen only when Cancel turns true after the load has started. See `docs/audits/TASK-007/CORRIGENDUM_D2_ADDENDUM.md`. The text below is otherwise unchanged.

# Source verification addendum (TASK-004, owner decision D2 only)

Date: 2026-10-14. Scope authorized by the owner: download only `ProfileStore.luau` at the pinned commit, verify it, read all of it without executing it, compare with `LIBRARY_SOURCE_FINDINGS.md`. Nothing was installed in Studio, `PlayerData` was not touched, no test experience was created, no DataStore request was made. Decisions D1 and D3-D13 remain pending.

## 1. Provenance and integrity
| Item | Value |
|---|---|
| URL | `https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/45c9847cbcf1fc260369c50eb335aba7c35aecdd/ProfileStore.luau` (HTTPS, HTTP 200, no redirect: effective URL identical) |
| Commit | `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, 2025-07-31, "Merge pull request #14 from RuizuKun-Dev/patch-1"; GitHub's API for this commit lists only `docs/tutorial/index.md` as changed, so the Lua file is unchanged by it |
| Local path | `C:\RobloxProjects\LighthouseKeepers\vendor-review\ProfileStore_45c9847\ProfileStore.luau` (new empty folder, one file, outside `src\`) |
| Size | 64,654 bytes (GitHub contents API for the same ref: size 64,654) |
| SHA-256 | `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F` |
| Git blob SHA-1 (computed locally) | `5b196af86a1eafa2ad5e94ef9398c483e87704ed`, **equal** to the blob SHA GitHub reports for that path at that commit |
| Length | 2,243 lines, read in full (lines 1-2243) |
| Handling | Never run, required or loaded. Only read as text. |
| License | the file carries no license header; the repository license is Apache-2.0 (earlier API check) |

## 2. Findings that the source confirms
1. **Legacy-record overwrite is real** (lines 531-576, 583-586, 1493-1505). A stored table that lacks `Data`, `MetaData` and `GlobalUpdates` (our flat v1 record has none of them) gets `missing_profile = true` and `overwritten = true`, is replaced by a fresh `{GlobalUpdates = ...}` plus template `Data`, and is written back by `UpdateAsync` (line 1625). The comment at line 583 reads "Invalid data handling (Silently override with empty profile)"; the library does emit a warning and fires `OnOverwrite` (lines 430-433, 637-641). **It happens even when the load is cancelled** because the overwrite flag does not depend on `Cancel`. Pointing it at `LighthouseKeepers_PlayerData_v1` would wipe each existing player on their first load.
2. **Record shape, constants and API** match `LIBRARY_SOURCE_FINDINGS.md` (header comment lines 1-168, saved structure 942-968, constants 170-181).
3. **Fence** is PlaceId + JobId (`IsThisSession`, line 659) plus `SessionLoadCount == profile.load_index` (lines 759 and 830). The GUID `unique_session_id` is stored as `ActiveSession[3]` and used only for the MessagingService topic `"PS_" .. id` (lines 1340, 1585). Stated correctly before.
4. **Saves are fenced**: the write transform edits `Data` only if this session still owns the profile (lines 751-810); a server that lost ownership notices on its next save, disconnects its subscription, removes the profile from autosave and fires `OnSessionEnd` (lines 911-921).
5. **Takeover**: dead-lock rule `os.time() - LastUpdate > ASSUME_DEAD (630)` (line 1472); otherwise a `ForceLoadSession` request plus a MessagingService "EndSession" message to the holder (lines 1583-1586); the holder saves and ends with reason "External" (lines 1343-1348, 843-847); the waiting server repeats every 10 s (first repeat 5 s) and **may steal only after 4 repeats (`ceil(40/10)`) and only if its force-load request is still the pending one** (lines 1573-1580, 1478-1483). A second contender that interrupts the first makes the first return nil (lines 1592-1596).
6. **Shutdown**: `BindToClose` sets `IsClosing`, releases every active profile in parallel with reason "Shutdown", and waits for all load/save jobs (lines 2208-2239). It has no deadline of its own, so Roblox's own shutdown limit is the only cap.
7. **Mock mode**: used when the Studio probe returns NoAccess, NoInternet or an error containing "403" or "must publish" (lines 2072-2111). `ProfileStore.Mock` gives an explicit user mock store.
8. **Keys and names**: key and store names must be at most 50 characters; `player_<UserId>` fits.

## 3. Inaccurate or incomplete assumptions in `LIBRARY_SOURCE_FINDINGS.md`
| # | Earlier statement | Correction from the source |
|---|---|---|
| A | "Save retries use exponential backoff" | Only **release** saves (EndSession, shutdown, external takeover) loop with backoff until they succeed (lines 735, 926-931; cap 20 s, 8 s on shutdown). An ordinary autosave that fails is **not retried until the next autosave** (line 738). Loss window for a failed autosave is therefore one autosave period unless `Profile:Save()` is called again. |
| B | "steal after 40 s" | After the first force-load request, 4 further repeats at 10 s, i.e. roughly 45 s, and only while our request is still current. |
| C | "`GetAsync` read-only view" is usable to read v1 | **No.** For a legacy record `GetAsync` returns a profile whose `Data` is the *template*, not the stored table (lines 1764-1775 and the shared transform). v1 must be read with a plain `DataStoreService` `GetAsync`, as the import design already says. |
| D | Studio probe described only as a probe | It performs a **real write**: `DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())` (line 2080) whenever the module loads in Studio. In a Studio session with API access on the production experience this writes a junk key (store `____PS`) to production. Another reason to keep the library out of the production place until the test universe exists and API access on production is off. |
| E | (not mentioned) | The module opens its store with `DataStoreOptions:SetExperimentalFeatures({v2 = true})` (lines 1305-1306). Roblox's reference page for that method says it currently has no effect and lists no `v2` feature (web search 2026-10-14). Low risk today, but it ties the library to an undocumented switch. |
| F | (not mentioned) | `Cancel` and `Steal` callbacks run **inside** the DataStore transform (lines 1458, 1495, 1509), so a `Cancel` function must be fast, pure and non-yielding (for example `player.Parent ~= Players`). |
| G | (not mentioned) | Calling `StartSessionAsync` for a key already active on this server throws (line 1391). The adapter must always call `EndSession` when a player leaves. A rapid rejoin on the same server is handled specially: the earlier pending load returns nil (lines 1421-1445). |
| H | (not mentioned) | `Profile.OnSessionEnd` fires **before** the final write when `EndSession` is called (lines 716-726), so it means "session over", not "saved". |
| I | (not mentioned) | A cancelled load for a brand-new player can still create an empty record with no active session (lines 1493-1505). Harmless but not a no-op. |
| J | "autosave spread" | Every autosave writes the whole `Data` and refreshes `LastUpdate` (lines 797, 2149), changed or not. This doubles as the liveness heartbeat for `ASSUME_DEAD`, but means constant write traffic of one `UpdateAsync` per player per autosave period. |

## 4. New risks and decisions this raises
1. **Studio and `____PS` write** (D above): the library must not run in the production place's Studio with API access enabled. Reinforces D3 and D4.
2. **Autosave failure window** (A above): choose `AUTO_SAVE_PERIOD` and call `Profile:Save()` after each Pearl credit and purchase so a failed autosave does not hide recent changes; the retry-until-success behavior exists only on release.
3. **`game.JobId` in Studio**: the fence uses `game.JobId`; I believe it is an empty string in Studio test sessions, which would make two Studio sessions look like the same server. This is an inference, not in the source; real concurrency tests must therefore use published servers (already the plan for the test universe).
4. **No version number in the file**: pin by commit and hash, which this addendum records.
5. **No internal shutdown deadline**: release saves loop until success, so a DataStore outage at shutdown is bounded only by Roblox's own limit.
6. The file is 2,243 lines of third-party code; it was read once by me and not independently reviewed. A second reviewer on the security-sensitive parts (lines 521-650, 709-938, 1364-1631, 2208-2239) is advisable before production use.

## 5. Conclusion
The central TASK-004 conclusions are unchanged and now firmly source-based: **the library cannot be used on the v1 store; a separate v2 store with our own import is required; session fencing and graceful takeover are real; rollback has no lossless form.** Corrections A-J should be folded into the design (autosave and `Save()` policy, Studio probe write, Cancel purity, EndSession discipline). No implementation is authorized and I have stopped.
