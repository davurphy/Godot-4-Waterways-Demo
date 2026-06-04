# Session Handoff: <Feature or Workstream>

## Date

<YYYY-MM-DD>

## Current Focus

Briefly state what this session was trying to accomplish.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\<feature-slug>\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

This is the handoff dashboard. Keep it short, concrete, and current.

- Overall status: <Not started / In progress / Complete / Blocked>
- Highest-priority open task:
- Last passing validation:
- Known failing or unproven check:
- Next recommended action:
- Packaging/artifact hygiene status:
- Historical detail starts at:

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and the shared citations index only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

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
9. `addons\waterways\docs\spec-driven\features\<feature-slug>\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

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
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future Codex sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.
- <Known Godot 4.6+ API detail>
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

Plain-language guidance for the next session. Include anything that would prevent rediscovering context, repeating a mistake, or editing the wrong project area.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so Codex does not alter the user's normal Godot editor profile.

Console probe pattern:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://path/to/probe.gd"
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Validation Commands

Run the CPU/readback diagnostic:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user-phase7b-eddy-cpu-diagnostic'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://.codex-research/phase7b_eddy_line_cpu_diagnostic.gd'
```

Use this Godot launch pattern for visual probes:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://.codex-research/phase7b_wake_eddy_visual_probe.gd'
