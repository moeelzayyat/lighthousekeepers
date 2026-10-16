# Isle arrival and harbor return: gameplay batch (2026-10-16)

**Scope:** LK Multiship Test only (GameId 10771229467, Harbor 125998212495899, Isle 111423375237885), branch `multiship-test`.
- The change was made in the test Harbor Studio window and is **not published**.
- No DataStore writes, MemoryStore writes or teleports were made.
- Studio API access stayed **off**, checked before every Studio Play.
- Production Lighthouse Keepers, SaveTest and Outlaw City were untouched.
- **Studio backup:** `ServerStorage.Backups.Arrival_before_2026-10-16` holds PlaceRole, IsleAdmission, Main, Departure and Menus as they were before.
- **Exact diff:** `ISLE_ARRIVAL_AND_RETURN.diff`.

## 1. Deployment state: published test build vs git
| | Config SHA-256 | Switches |
|---|---|---|
| **Published** to both test places (Stage 2, 13:39Z / 13:54Z) | `94ee135c13180be31544db75369b33cedefdb74b5e81303a1f747cb38a9d9651` | `multiShip`, `sessionLock` and `teleport` = **true** |
| Git `multiship-test` at 0e7d198 (Stage 2 cleanup) | `27661b7a…8078` | all false. **Not safe to publish** over the locked test build: it would put servers live that write `LKMS_TEST_PlayerData_v1` without the lock. |
| **Git `multiship-test` from this batch** | `94ee135c…9651` (switches on again) | Git now **mirrors the deployed test build**, so anything published from this branch keeps the lock. |

- **Rule for any future test publish:**
  - Assert `GameId 10771229467` and the exact PlaceId of the window.
  - Check that every script hash equals git, with Config `94ee135c…`.
  - Check that `PlaceRole` resolves to the right role, with `PLACE_ROLE_OVERRIDE = nil` and `ISLE_STUDIO_TEST = false`.
  - Never publish a test build with `sessionLock = false`.
- Production (`main`) has no test switches; the test gate only matches GameId 10771229467.

## 2. Changes (6 scripts; gameplay rules, rewards and saves unchanged)
1. **Isle arrival** (`Main`, isle role only): the place's single spawn moves to the lighthouse island's arrival point. Travellers now land **beside the lighthouse**, never on the copied harbor ship.
   - `stateFolder.PlaceRole` tells the client which place it is in.
   - `IsleAdmission` reports how many of the crew have landed through a new optional `report(arrived, expected)` hook. `Main` publishes the count as `IsleArrived` / `IsleExpected`.
2. **Isle arrival card** (`Client.Departure`): on the isle, the harbor's boarding card becomes:
   - while landing: **"LIGHTHOUSE ISLE · YOUR CREW IS LANDING n/m"**, "Wait by the lighthouse. The storm starts when your crew has landed."
   - during the existing 10 s countdown: **"LIGHTHOUSE ISLE · THE STORM STARTS IN 0:0x"**.
   - Its loading cover (`Client.Menus`) reads "Landing on Lighthouse Isle. The storm is coming."
3. **Returning players skip the title** (`Main` + `PlaceRole.arrivedFromIsle`):
   - On the harbor, a player whose `Player:GetJoinData().SourcePlaceId` is the Isle place goes straight to the harbor deck (the existing fast route).
   - They see "Back at the harbor. Walk onto a ship to sail again.", and the log reads `EnteredLobby via=voyage return`.
   - **New joins keep the title screen** exactly as before. The existing first-voyage fast path for 0-run players is unchanged.
   - The result is used only for routing, so a wrong value can never grant anything.
4. `Config`: switches back on, to mirror the deployed build (section 1). No other value changed.

## 3. Tests (all in Studio, API off, no writes)
| Test | Result |
|---|---|
| `arrivedFromIsle`: Isle source → true; no source, Harbor source, production place source, nil or non-table → false | 6/6 PASS |
| IsleAdmission report: 0/2 → 1/2 (waits) → 2/2 (voyage requested); depart freezes exactly the listed crew; no report hook → unchanged | 5/5 PASS |
| **Studio Play as Isle**, with a temporary `PLACE_ROLE_OVERRIDE = "isle"` and `ISLE_STUDIO_TEST = true`, both reverted afterwards | The player spawned **at the lighthouse arrival point** (0, 14, 24), 3.5 studs from the moved spawn. Card: "LIGHTHOUSE ISLE · YOUR CREW IS LANDING 1/1", then "THE STORM STARTS IN 0:06". Cover: "Landing on Lighthouse Isle…". The Prologue started with the player Ready and the card hidden. No script errors; the console shows only Roblox UIBlox warnings and the expected "DataStores unavailable". PASS |
| **Studio Play as Harbor** (regression) | Role harbor; `RouteNote` nil; the original cover text and "HARBOR ISLAND · WAITING FOR CREW 0/4" card are unchanged. PASS |
| Final state | All 49 scripts equal git (Config `94ee135c…`), all compile, Studio not running, API off |

**Not testable in Studio:** a real `SourcePlaceId` (Studio joins aren't teleports). The return route is covered by the `arrivedFromIsle` cases above. It is confirmed live only when the next approved voyage returns.

## 4. Next owner-authorized live test: one positive Pearl reward (prepared, not run)
**Goal:** earn a non-zero Pearl reward on the Isle, and see it saved and loaded back in the Harbor. This also checks changes 1–3 live.
- **Needs the owner's approval** to publish this batch to both test places, with the same procedure as Stage 2:
  - pre-publish backup;
  - window, hash and role checks before and after each publish;
  - no join between the publishes;
  - Restart Servers;
  - API on only for my read-only checks, no Studio Play.
- **Profile:** `player_11752219158` only (now 25 Pearls, runs 2, bestNight 1). One voyage, Ship 1, Sail Now.
- **How to earn it with the existing rules (no balance change):**
  - Survive Night 1, which pays `PEARLS_PER_NIGHT` = 1 per night survived. Then end the run on Night 2 by letting the lamp go dark.
  - Expected award: **+1, so 26 Pearls after return**. Surviving more nights gives +1 each, so record the exact Results figure.
  - Night 1 solo tips: keep the lamp fuelled before dark and carry oil continuously, keep the beam on wide, and repair the tower between waves.
- **If he loses Night 1 again:** 0 Pearls. Record it and **do not** start another voyage without new approval.
- **Pass:**
  - The Results award is above 0.
  - The Harbor balance is 25 + that award, and the stored value matches (uncached read).
  - T1 → T2 → T3 → final release.
  - He lands beside the lighthouse with the landing card shown.
  - The return skips the title (`EnteredLobby via=voyage return`).

## 5. Then: two ships, two reserved servers (plan only)
- **Needs:**
  - a **second Roblox account**;
  - the owner's approval to add its UserId to `writableUserIds`. Otherwise it plays memory-only, can't hand off, and can't travel.
- **Sequence:** both players join the Harbor. One boards **Ship 1** and the other **Ship 2**. Both use Sail Now within a few seconds of each other.
- **Expect:**
  - two `VoyageLaunched` events with different private server ids;
  - each Isle logs `IsleVoyage crew=1 expected=1`;
  - each save holds its own lock;
  - both return and both final releases clear.
- **No forced failures** until that passes.

## Required owner decision
Approve publishing this batch to both test places and the one positive-Pearl voyage in section 4. Until then nothing is published and no live test runs.
