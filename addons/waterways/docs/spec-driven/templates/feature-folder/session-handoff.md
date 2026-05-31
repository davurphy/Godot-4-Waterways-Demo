# Session Handoff: <Feature or Workstream>

## Date

<YYYY-MM-DD>

## Current Focus

Briefly state what this session was trying to accomplish.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\<feature-slug>\`
- Active add-on path:
  - `addons\waterways`
- Legacy reference path:
  - `legacy\godot-3\addons\waterways`

## Current Truth

This is the handoff dashboard. Keep it short, concrete, and current.

- Overall status: <Not started / In progress / Complete / Blocked>
- Highest-priority open task:
- Last passing validation:
- Known failing or unproven check:
- Next recommended action:
- Packaging/artifact hygiene status:
- Historical detail starts at:

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\<feature-slug>\tasks.md`
5. `addons\waterways\docs\spec-driven\features\<feature-slug>\review.md`
6. `addons\waterways\docs\spec-driven\features\<feature-slug>\validation.md`
7. `addons\waterways\docs\spec-driven\features\<feature-slug>\plan.md`
8. `addons\waterways\docs\spec-driven\features\<feature-slug>\spec.md`

Then do this next:

- <One concrete next action>
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. Include the evidence, confidence level, and the smallest check that could prove or disprove the premise.

## What Changed This Session

- <File or folder>: <What changed and why>
- <File or folder>: <What changed and why>

## Current Changes Summary

Use this for the latest session only. Move older entries into "Historical Change Log" when this gets long.

- <Latest changed file/folder>: <High-signal summary>

## Historical Change Log

Older change history can live here once the current summary is enough for the next agent.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| <Decision> | <Reason> | <Follow-up or none> |

## Current State

Implementation status:

- <Not started / In progress / Complete / Blocked>

Spec/plan status:

- Research:
- Spec:
- Plan:
- Tasks:
- Validation:
- Review:

Validation status:

- Automated:
  - <Stable result markers and commands that matter>
- Human-assisted:
  - <If needed, include the exact validation request that should be sent to the user next.>
- Shader:
- Editor:
- Visual:
- Runtime:
- Performance:
- Manual:

## Important Context

- <Constraint, assumption, design note, or project-specific context>
- <Known Godot 4.6+ API detail>
- <Legacy Godot 3 behavior to preserve or intentionally change>
- <Any user/agent misunderstanding risk that should be raised directly instead of silently worked around>

## Artifact Hygiene

- Scratch folders or temporary projects created:
- Generated bakes/resources created:
- Active files mirrored into scratch validation:
- Files/folders that must be excluded from packaging:
- Files/folders safe to delete now:

## Known Risks and Open Issues

- <Risk or issue>
- <Risk or issue>
- <Possible false premise or expected-behavior explanation to verify before implementing>

Relevant audit sections:

- `addons\waterways\docs\audit\<audit-file>.md`: <Relevant heading or note>

## Blockers

- <Blocker, owner, and what is needed to unblock>
- <If local Godot/editor/test access is blocked or unreliable, say so plainly. Local parser/headless editor-load signal is not a substitute for visible editor/runtime validation.>
- <If the user appears to be overlooking context, say what evidence should be shared with them and what quick check should happen next.>

## Files To Inspect Before Editing

- `<project-relative-path>`
- `<project-relative-path>`

## Commands or Checks Used

```powershell
<command>
```

Result summary:

- <What mattered from the output>
- <If the user ran the check, record who ran it, what they ran, when, and what they observed>
- <If a command is noisy but passed, record the stable pass/fail marker and the known caveat.>

## Next Tasks

- [ ] <Task>
- [ ] <Task>
- [ ] <Task>

## Do Not Do Yet

- <Thing that is tempting but out of scope or risky>
- <Thing blocked on a spec/plan decision>

## Notes for the Next Agent

Plain-language guidance for the next session. Include anything that would prevent rediscovering context, repeating a mistake, or accidentally editing the legacy snapshot instead of the active Godot 4.6+ add-on.
