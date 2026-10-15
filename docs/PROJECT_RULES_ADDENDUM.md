# Project rules addendum (relayed verbatim by the coordinator session, 2026-10-14)

## CRITICAL — MULTIPLE ROBLOX GAMES ON THE SAME COMPUTER
There is another Roblox game actively being developed on this Windows PC. Its Roblox Studio session may already be open and connected through MCP. That other game is completely separate from Lighthouse Keepers.
You MUST follow these rules:
1. NEVER modify, save, close, stop Play, publish, or otherwise interfere with another game's Roblox Studio session.
2. NEVER assume the first Roblox Studio instance returned by MCP is Lighthouse Keepers.
3. Before any operation, discover all available Roblox Studio instances and identify them by their actual place IDs.
4. Lighthouse Keepers has place ID 132065051336560 and universe ID 10769064643.
5. Open Lighthouse Keepers in its OWN separate Roblox Studio window/session. Do not reuse or replace the other game's window.
6. If Lighthouse Keepers is already open in a separate verified window, reuse that correct instance rather than opening unnecessary duplicates.
7. If Lighthouse Keepers is not open, locate it through Roblox Studio or an appropriate authorized workflow and open it separately.
8. Do not close, overwrite, or switch away from the other game's editing session.
9. After opening Lighthouse Keepers, rediscover MCP Studio instances because their identifiers may have changed.
10. Before every Studio modification or test, verify the selected MCP instance still belongs to Lighthouse Keepers.
11. If the MCP connection cannot reliably target the correct Studio instance, STOP and ask for assistance.
12. Do not send Play, Stop, Edit, Save, or script execution commands to an unverified instance.
13. Never publish either game without explicit owner approval.
14. Keep Lighthouse Keepers backups, script exports, documentation, and development files in its own dedicated local workspace.
15. Do not modify the other game's source files, folders, repositories, assets, or configuration.
The other Roblox game must remain completely untouched throughout this project.
Your first Studio-related action must be to list available Studio instances, identify their place IDs, and confirm which instance belongs to Lighthouse Keepers.
If only the other game is running, open Lighthouse Keepers in a NEW Studio window without disturbing the existing one.
Treat these instructions as mandatory for all agents, subagents, and development threads.

Project Isolation (auditor section, summarized by the coordinator): never include the other game's scripts, screenshots, settings, backups or confidential files in Lighthouse Keepers audit packages.

# MANDATORY — INDEPENDENT AUDITOR COORDINATION
## Independent Auditor
This Roblox project has a separate independent technical auditor: ChatGPT, acting as The Architect. The auditor is responsible for reviewing development quality, architecture, security, gameplay design, balance, performance, testing evidence, and long-term project direction. The auditor does NOT have automatic access to this Claude Code project, your Windows computer, Roblox Studio, MCP sessions, or local files. The project owner transfers audit reports and supporting files to the auditor manually. Your responsibility is to make this handoff easy, complete, honest, and consistent.
## Mandatory Audit After Every Task
After EVERY completed development task, including major bug fixes, feature implementations, refactors, migrations, and important configuration changes, prepare a structured audit package. Do not wait for the owner to request the report. Do not begin the next significant implementation batch until the owner has had an opportunity to review the results with the auditor and approve the next batch. Routine exploration and minor documentation operations can be grouped into one report when appropriate.
## Audit Package Location
Maintain: docs/audits/. For each completed task, create a separate folder: docs/audits/TASK-001/, docs/audits/TASK-002/, docs/audits/TASK-003/. Each task folder should contain: 1. AUDITOR_REPORT.md 2. CHANGE_MANIFEST.md 3. TEST_EVIDENCE.md 4. AUDITOR_QUESTIONS.md 5. Supporting files when relevant. Use sequential task identifiers and descriptive task names.
## AUDITOR_REPORT.md
Include: Task ID and title; Original owner request; Objective; Date; Current project and verified Roblox place ID; Work completed; Architecture decisions; Gameplay changes; Security implications; Save-data implications; Performance implications; Known limitations; Outstanding problems; Whether the task is ready for acceptance. Distinguish confirmed results from assumptions. Be precise and transparent.
## CHANGE_MANIFEST.md
List every changed script and file with its exact path. For each change, explain: What was changed; Why it was changed; Dependencies affected; Any new remotes, modules, instances or configuration; Whether persistent data or economic values changed; Whether owner approval was obtained. Include source diffs or copies of the relevant changed code whenever practical. For substantial code changes, provide a separate diff or source snapshot so the auditor can examine the actual implementation. Do not substitute summaries for code evidence when code correctness is the subject of review.
## TEST_EVIDENCE.md
Include: Tests performed; Test environment; Player count; Device or emulator; Test steps; Expected results; Actual observed results; Pass/fail outcome; Relevant console output; Screenshots or performance measurements when available; Tests not performed; Remaining regression risks. Never claim tests passed without evidence. Never describe an emulated device test as a real-phone test. Record whether a test could have changed production DataStore values.
## AUDITOR_QUESTIONS.md
Identify any decisions requiring independent review. Include: Unresolved technical concerns; Important tradeoffs; Potential security or persistence risks; Gameplay balance concerns; Possible improvements; Specific questions for ChatGPT. Do not invent problems merely to create questions. If no specific concerns remain, state that explicitly.
## Supporting Evidence
When relevant, provide: Luau script files; Source diffs; Error logs; Performance metrics; UI screenshots; Gameplay screenshots; Test recordings or summaries; Architecture diagrams; Relevant configuration; DataStore migration proposals. Exclude credentials, secret tokens, personally identifiable player data, and unrelated game files.
## Mandatory Owner Handoff Message
After each task, explicitly tell the owner: "Task TASK-XXX is complete and ready for independent audit. Please send the following files to ChatGPT (The Architect):" Then list the exact local file paths required. Clearly distinguish: REQUIRED files; OPTIONAL supporting evidence. Also include a brief summary of the task, test status, any unresolved risks, and your recommended next step. If the owner wants a single attachment, create a ZIP containing only that task's audit package. The ZIP should be named: TASK-XXX_AUDITOR_PACKAGE.zip. Verify that the archive contains the intended files before reporting it as ready.
## Audit Feedback Loop
When the owner returns feedback from ChatGPT: 1. Read the auditor's findings carefully. 2. Classify findings as confirmed, plausible, disputed, or requiring more evidence. 3. Verify technical claims against actual project code and Studio behavior. 4. Propose corrective actions. 5. Obtain owner approval where required. 6. Implement approved corrections. 7. Update the audit package with the resolution. 8. Record accepted and rejected recommendations with reasons. Do not automatically implement every auditor recommendation. The owner has final authority.
## Project Isolation
(see the Outlaw City section above; never include the other game's scripts, screenshots, settings, backups or confidential files in audit packages.)
## Definition of Done
A task is not fully closed until: 1. The approved work is completed. 2. Relevant tests and safety checks are performed. 3. Temporary changes are reverted. 4. The development logs are updated. 5. The auditor package is generated and verified. 6. The owner is told exactly which files to send. 7. Important auditor feedback has been addressed or explicitly accepted by the owner. Never publish without explicit owner approval.

## Repository rule (owner, 2026-10-15)
After each task, push to https://github.com/moeelzayyat/lighthousekeepers so the auditor can read it.
- The repository is PUBLIC.
- Push: exported scripts (`src\`), `docs\` and `tests\`.
- Never push:
  - `.rbxl` or `.rbxm` place and model files, or `backups\`, `work\` or `vendor-review\`;
  - anything from Outlaw City or `G:\`;
  - credentials, cookies, API keys or player data.
- Never force-push.
