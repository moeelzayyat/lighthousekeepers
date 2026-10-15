# AUDITOR QUESTIONS — TASK-005

1. **Is T0 sufficient as the isolation gate?** It shows the owner's production-profile key is nil in the SaveTest store, but the production key itself was not read. Do you want a stronger gate (for example, a marker written in SaveTest after approval and the owner confirming production cannot see it), or accept T0 plus platform behaviour?
2. **Unmarked production code in the test place.** The owner declined the rename/guard edit and extra publish because of human-error risk. Do you accept that the SaveTest place keeps the production store name (a different store because of the universe), or should the guard be added later inside a Studio session without publishing?
3. **Production API setting.** It is unknown. Should the next step require the owner to read it (without changing it) before any write in SaveTest, and should D4 (turn it off) be a precondition for loading ProfileStore anywhere?
4. **v149 versus v148.** The test place came from v149 (the owner's later save). Counts and lengths match v148. Is that enough, or should content hashes of the 40 scripts be compared before tests begin?
5. **Matrix v2.** Are the new rows C18-C29 and the changes to C1, C7, C12, C14 adequate? In particular, is published-server testing for session conflicts mandatory because `game.JobId` may be empty in Studio (to be established by C22)?
6. **First write.** Which write should be first in SaveTest: the canary marker, then the legacy-record overwrite test (C12), then the importer (C29)?

No concern has been invented; items 1, 2 and 5 are the real forks.
