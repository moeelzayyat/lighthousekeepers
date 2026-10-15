# R5 DEFERRAL NOTE

- **Date:** 2026-10-14
- **Owner decision:** "Defer R5", 21:40:15Z. The owner has only one Roblox account. R5 needs two different accounts in two live SaveTest servers at the same time, and one account can only be in one server.
- **Constraint:** the second account is blocked anyway. SaveTest is unrated, so Roblox shows "not accessible because it is unrated" to non-owners; the owner account sees Play.

## State left in SaveTest (nothing armed, nothing published)
- R5 v3 is installed and inert:
  - guard `2ac3de3d…`
  - `R5CrossServer` `ab17dfee…`
  - bootstrap `646ac454…`, **disabled, no attributes**
- `Main` is disabled.
- No R5 keys exist. 204 and 205 are absent, and there is no run record and no results record.
- Fixtures are preserved and released: 201 = 25, 202 = 30, 203 = 40.
- Nothing was published, no collaborator was added, and no privacy or rating setting was changed.

## What is verified live (Studio server)
- **R2:** save and load.
- **R3:** persistence and release.
- **R4:** an active profile is released at shutdown.

## What is verified only on fakes or by source review
- R5 v3: 12 mock scenarios, covering:
  - the presence gate;
  - the atomic run claim race;
  - reserved-server association;
  - supervised transport failures;
  - the deadline and cleanup;
  - MessagingService handover;
  - stale-writer fencing.
- These are **mock results, not live-server results.**

## Residual risk accepted by deferring (for the auditor to rule on)
1. Session handover between two live servers through MessagingService is untested live. That covers the timing, delivery, and fallback to the library's 40 s steal.
2. Stale-writer fencing with two distinct, non-empty JobIds is untested live. Studio cannot test it, because its JobId is "".
3. Teleport into reserved servers and the shutdown timing of live servers (the 30 s BindToClose limit) are untested.

## Conditions to resume R5
1. A second Roblox account controlled by the owner.
2. Separate owner approval to add it as a collaborator on SaveTest only.
3. A new local `.rbxl` backup.
4. The final arming and publishing checklist approved.

The reviewed v3 code needs no change to resume.

## Recommendation
- Keep the R5 code installed but disabled in SaveTest.
- Before any production save migration, either run R5 when a second account exists, or record the auditor's acceptance of the three residual risks above, with production monitoring of session conflicts as a mitigation.
