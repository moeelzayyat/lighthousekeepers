# AUDITOR REPORT — TASK-005: Separate private SaveTest experience (D3)

- **Date:** 2026-10-14
- **Production (untouched):** Lighthouse Keepers - Staging, place 132065051336560, universe 10769064643.
- **Test environment created by the owner:** "Private lighthouse keepers", **place 128620546156998, universe 10770892134**, private, creator = the owner's account.
- **Original owner request (D3):** plan and guide the setup of a separate, private SaveTest experience; explain steps needing the owner; do not modify or publish production, touch Outlaw City, import real saves, enable production API access, write to DataStores before verification, or install ProfileStore in production; update the test matrix for the source-verification findings; stop after the environment is prepared and verified and produce the handoff before asking for persistence implementation.

## Work completed
1. A step-by-step plan with owner-hands and approval markers (`SETUP_PLAN.md`).
2. The owner created the experience and published it to a new place, enabled Studio API access for it, and confirmed it is private.
3. Claude verified the environment read-only through MCP: IDs differ from production, content equals the owner's v149 save (counts and script lengths), store name unchanged (`LighthouseKeepers_PlayerData_v1`, separate store because it belongs to the test universe).
4. **Gate T0 passed:** a read of the owner's production-profile key `player_11752219158` and of `__access_check` in the SaveTest store returned nil after API access was saved (the first attempt was rejected by Roblox and read nothing).
5. The test matrix was rewritten (`REVISED_TEST_MATRIX_V2.md`) to reflect findings A-J of `SOURCE_VERIFICATION_ADDENDUM.md`, adding C18-C29 and changing C1, C7, C12, C14.

## Deviations from the plan (all recorded in `SETUP_RESULTS.md`)
- The test place was built from **v149**, not v148 (the owner's own copy made before step 0 was approved). v149 is the owner's save after v148; its content matches v148 on every count and length checked.
- Plan steps 8-9 (test-only store name, production-ID guard, extra publish) were **dropped at the owner's request** because manual publishing invites human error. Consequence: no code in the SaveTest place was changed.
- The production Studio API setting was **not reported**, so its state is unknown (D4 pending).
- Step 0 and the opening/publishing steps were done by the owner without my witnessing them; their result was verified afterwards, not observed.

## Gameplay / security / save-data / performance implications
None. No game or Config change, no DataStore write by Claude, nothing published by Claude, no production data read.

## Known limitations
- Isolation is supported by T0 but not proven absolutely: the production key was not read, so "nil in SaveTest" does not demonstrate that the production key exists.
- Whether SaveTest could ever write to a production store is argued from platform behaviour (stores belong to a universe) and one read result, not from a documented guarantee I could cite.
- The SaveTest place carries the production PlayerData code unchanged. A Play session or a joined player in the SaveTest universe would create test-universe saves under the existing store name. That is isolated but unmarked; the guard and rename were not applied.
- ProfileStore is not yet in the test place; no persistence test has run.

## Outstanding problems / pending owner decisions
D1 (library vs custom), D4 (production API setting off), D5-D13 as listed in `TASK-004/OWNER_DECISIONS_AND_SEQUENCING.md`; approval to place the pinned ProfileStore file in the SaveTest place; approval for the first DataStore write in SaveTest; confirmation of production's API setting.

## Ready for acceptance?
Yes as an environment-preparation milestone. No persistence implementation is authorized.
