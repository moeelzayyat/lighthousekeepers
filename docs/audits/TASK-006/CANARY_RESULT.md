# Canary result (TASK-006), 2026-10-14

**Approval:** the owner answered "yes" in chat to the single canary write, in SaveTest only, after the exact script (`CANARY_SCRIPT.luau`) was shown.

**Pre-run checks:** Studio instances re-listed immediately before the run; the SaveTest window was `Private lighthouse keepers (placeId: 128620546156998)`. The script asserts, before touching `DataStoreService`: PlaceId == 128620546156998, GameId == 10770892134, neither equals the production IDs, Edit mode and not running. It ran from the owner's Studio session via MCP `execute_luau` (Edit datamodel).

**Output (verbatim):**
```
{"readBefore":{"ok":true,"isNil":true},"key":"isolation_canary_v1","gameId":10770892134,"write":{"ok":true,"version":"08DF2A11FA68EBDA.0000000001.08DF2A11FA68EBDA.01"},"placeId":128620546156998,"store":"TEST_LK_IsolationCanary","readBack":{"ok":true,"matches":true}}
```

**Reading it:**
- The key did not exist before (read ok, nil): the marker was new.
- One `SetAsync` succeeded and returned a version id. The version string ends `.0000000001...`, consistent with a first version of a new key.
- The read-back succeeded and every compared field matched (purpose, placeId, gameId, writtenAt).
- Exactly one write was made. Nothing was deleted. No other store or key was touched. No production DataStore key was read, written, deleted or modified in this task.

**What this proves and what it does not**
- Proves: Studio API access works in the SaveTest universe and a write plus read-back round trip works there.
- Does not prove isolation from production. Isolation still rests on platform behaviour (stores belong to a universe) plus the earlier T0 read (the owner's production profile key was nil in SaveTest). No production store was queried to confirm the canary's absence there, because production reads are prohibited.
- The marker remains in `TEST_LK_IsolationCanary` of the SaveTest universe. It is harmless and was deliberately not deleted.
