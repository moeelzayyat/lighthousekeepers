# AUDITOR QUESTIONS — TASK-001

No unresolved technical concern blocks acceptance. Questions where an independent view helps:

1. Is a Rojo parse plus length-match sufficient evidence of a usable backup, or should a one-time restore test (open the `.rbxl` in a throwaway Studio window, never publishing) be required before development starts?
2. The export came from the saved `.rbxl`, not live Studio, to keep the live session untouched. Is a content hash comparison of live scripts worth the extra live-session reads?
3. The Edit-mode data model listed a `Players.Lighthouse8282` entry. Is there any reason to treat that as a risk to saved data? (No test was run to check; flagged only for awareness.)
4. Recommended cadence: new `.rbxl` backup before every approved implementation batch, in addition to the in-Studio `ServerStorage.Backups` folders. Agreed?
