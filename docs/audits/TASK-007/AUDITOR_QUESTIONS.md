# AUDITOR QUESTIONS — TASK-007

1. **Is the mock-backend approach acceptable evidence?** The vendor text ran against my own in-memory fakes with `game` shadowed. It shows the library's logic (record shape, fencing, takeover, retries) but not real DataStore behaviour. Which real-DataStore rows must still pass before you accept the library?
2. **Probe write (W1).** Loading the real module in a Studio window with API access performs a real write to a store named `____PS`. Is one such write in SaveTest acceptable as the first approved real write (R1), or should the library never be loaded in Studio at all and be tested only on published test servers?
3. **Publishing for two-server tests.** Session-conflict tests need published servers because `game.JobId` cannot be relied on to differ in Studio. The owner has declined manual publish steps so far. Do you want those rows dropped, replaced (for example a scripted Open Cloud flow, which would need credentials that I will not request), or done with a guided, checklist-driven publish to SaveTest only?
4. **Cancel semantics.** Given the corrected finding (a cancel that arrives mid-load still lets the overwrite happen), do you want the adapter to forbid `Cancel` entirely when a store might still hold legacy data, or is "never use a store name that holds v1 data" enough?
5. **Production API access is ON** (owner-reported). Should D4 (turn it off) be a precondition before the real module is loaded anywhere?
6. **The vendor text.** It is 2,243 lines of third-party code. Do you want an independent reviewer on lines 521-650, 709-938, 1364-1631 and 2208-2239 before real use?
7. **Leave or revert the SaveTest scripts?** The new scripts are inert, but SaveTest now differs from production code. Keep them for the next stage, or revert to `SaveTest_pre-TASK-007.rbxl`?

No further concern has been invented; items 2, 3 and 5 are the real forks.
