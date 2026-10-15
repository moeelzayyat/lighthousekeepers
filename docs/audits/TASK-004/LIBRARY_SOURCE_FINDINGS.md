> **UPDATE (2026-10-14): the file was later downloaded and read in full under owner decision D2; see `SOURCE_VERIFICATION_ADDENDUM.md`. It confirms the central findings and corrects items A-J there (notably: only release saves retry; the Studio probe performs a real write; `GetAsync` cannot read v1).**

# ProfileStore: what was actually read (TASK-004)

## How this was read, and the limits
- Source: the public repository `https://github.com/MadStudioRoblox/ProfileStore` (file `ProfileStore.luau`, `README.md`, the docs site `https://madstudioroblox.github.io/ProfileStore/`) and the GitHub REST API for commit and license metadata, read on 2026-10-14.
- The pages were read through a fetch tool that returns a model-written answer to a question, not the raw file. Short quotations below are what that tool reported as verbatim; **I did not download the file or read it line by line**. Two separate questions about the legacy-record behaviour gave consistent answers, but this is still second-hand reading. **Before any adoption, the exact file at a pinned commit must be downloaded into its own empty folder (owner approval required for the download) and read in full.** Nothing was downloaded or executed in this task.

## Identity, version, license, maintenance
| Item | Finding |
|---|---|
| Name | ProfileStore (by loleris / MadStudio), successor to ProfileService |
| Latest commit seen | `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, 2025-07-31 ("Merge pull request #14 from RuizuKun-Dev/patch-1") |
| Previous commits | 2025-06-18 type fix; 2025-03-29 docs/CI; 2025-03-25 "Blocking prevention for MessagingService"; 2025-02-15 link fixes |
| Repo created | 2024-10-09; 32 commits on `main`; not archived |
| Releases/tags | none shown; the source file carries no version number or license header |
| License | Apache-2.0 (repository LICENSE; GitHub API `spdx_id`). Apache-2.0 requires keeping the license and notices if the file is vendored |
| Popularity | about 344 stars, 66 forks (page capture) |
| Maintenance reading | actively built through 2025, **no commit for about 14.5 months as of 2026-10-14**. That is low activity, not abandonment; the code is small and single-purpose. Treat it as "stable, thinly maintained" and pin a commit |
| Delivery | single ModuleScript; Wally manifest present |

## Stored record shape (important)
Each key holds a **wrapped** table: `Data`, `MetaData`, `RobloxMetaData`, `UserIds`, `GlobalUpdates`. `MetaData` holds `ProfileCreateTime`, `SessionLoadCount`, `ActiveSession = {PlaceId, JobId, unique_session_id}`, `ForceLoadSession`, `LastUpdate`, `MetaTags`. Our v1 record is a flat table (`pearls`, `owned`, `counts`, ...), so the two are different shapes.

## What it does with an existing record that is not in its shape (the critical finding)
The load transform checks for `Data`, `MetaData` and `GlobalUpdates`. When they are missing it sets `missing_profile = true` and `overwritten = true`, with the comment reported as `-- Invalid data handling (Silently override with empty profile)`, and replaces the value with a fresh profile built from the template. The original raw fields are discarded in that write. A warning and an `OnOverwrite` signal fire; read-only `GetAsync` does not write.
**Consequence: pointing ProfileStore at the existing v1 store name would, on the first session start for each existing player, replace that player's record with an empty template profile.** That would destroy player progress. This is stronger than what TASK-003 said and rules out an in-place adoption of the library on `LighthouseKeepers_PlayerData_v1`. (Verification in a safe place is test C12 in `REVISED_TEST_MATRIX.md`; it must never be run in production.)

## Session lock, fencing and takeover as read
- Acquire: when there is no active session it writes `ActiveSession = {PlaceId, JobId, unique_session_id}`.
- Dead lock: reported check `if os.time() - last_update > ASSUME_DEAD then`, `ASSUME_DEAD = 630` s, then the session is taken.
- Live holder: the requester writes `ForceLoadSession` and publishes a MessagingService message; the holder saves, ends its session with reason "External" and releases. The requester retries at 5 s then every 10 s; after `SESSION_STEAL` (40 s) of unsuccessful attempts it takes the session by force (`Steal = true` takes it immediately).
- Fencing on write: ownership is checked inside the write transform with `IsThisSession` (reported as `return session_tag[1] == PlaceId and session_tag[2] == JobId`) plus `SessionLoadCount` equality. **It does not compare the per-session unique GUID**, so the fence is PlaceId + JobId + load count. A server that lost its session sees the stored session differ on its next save, stops saving, and fires `OnSessionEnd` (no reason).
- `Cancel`: a function polled during the load loop; returning true makes `StartSessionAsync` return nil without claiming the session. The documented intent is to abandon a load when the player has left.

## Saving behaviour as read
- Auto-save default 300 s, spread across loaded profiles; the docs say it was raised from 30 s. `ProfileStore.SetConstant(name, value)` exists, so the interval can be changed (value to be chosen against the DataStore budget). `Profile:Save()` triggers an extra save.
- Save retries use exponential backoff capped at 20 s (8 s during shutdown). Five errors within 120 s mark a "critical state".
- Shutdown (`BindToClose`) releases every active profile in parallel and waits for pending jobs.
- In Studio the module probes the store with a test write to a store named `____PS` (reported `DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())`); when access is denied it uses an in-memory mock. **When Studio has API access it uses the real DataStore, so a Studio test of ProfileStore on the production place would perform real writes. That is the same exposure the project already has today and is why the persistence tests must live in a separate universe.**

## Public API names read
`ProfileStore.New(store_name, template?)`, `ProfileStore.SetConstant`, `:StartSessionAsync(key, {Steal?, Cancel?})`, `:MessageAsync`, `:GetAsync(key, version?)` (read-only view, no session), `:VersionQuery`, `:RemoveAsync`; profile methods `IsActive`, `Reconcile`, `EndSession`, `AddUserId`, `RemoveUserId`, `MessageHandler`, `Save`; events `OnSave`, `OnLastSave`, `OnAfterSave`, `OnSessionEnd`.
The docs page says its profiles are backwards compatible with ProfileService, and that using `MessageAsync` can make ProfileService have trouble loading them again. The docs recommend trying it in Studio with API access before migrating a live game. It says nothing about migrating arbitrary raw DataStore data.

## What I could not establish
- The exact current text of the file (see limits above).
- Whether `Profile.Data` hooks exist for importing a legacy record at first load (none are documented; an importer would be our own code run immediately after `StartSessionAsync`).
- Runtime behaviour under our usage, which only the test universe can show.
