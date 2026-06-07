# Session Handoff: River Ripples

## Date

2026-06-07

## Current Focus

Create a spec-driven feature folder for runtime river ripples based on the roadmap.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-ripples\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

This is the handoff dashboard. Keep it short, concrete, and current.

- Overall status: Feature docs created; implementation not started.
- Highest-priority open task: Lock Phase 0 scope and architecture decisions before code.
- Last passing validation: Documentation-only creation, template alignment, roadmap-detail preservation, and citation-index check; no Godot ripple validation.
- Known failing or unproven check: No-readback ping-pong feedback, mapping, boundary mask, material ownership, shader integration, debug parity, and performance are all unproven.
- Next recommended action: Resolve Phase 0 decisions with the user, then create or confirm a feature branch before implementation.
- Packaging/artifact hygiene status: No scratch folders, generated resources, bakes, or local probes created.
- Historical detail starts at: `Historical Change Log`.

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
4. `addons\waterways\docs\spec-driven\features\river-ripples\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-ripples\review.md`
6. `addons\waterways\docs\spec-driven\features\river-ripples\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-ripples\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-ripples\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-ripples\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Ask the user to confirm Phase 0 decisions: visual-only scope, no source-signature bump, no river bake changes, no WaterSystem changes, no buoyancy or object-drift changes, first demo scenario, axis-aligned vs full transformed fields, boundary source, material ownership path, built-in vs prototype node status, debug parity path, and shader sample budget.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. The main false-premise risk is treating first-pass visual ripples as flow, buoyancy, or WaterSystem behavior.

## What Changed This Session

- `addons\waterways\docs\spec-driven\features\river-ripples\`: Created new feature folder.
- `spec.md`: Captured user goals, non-goals, requirements, acceptance tests, visual validation, performance, open questions, and decision log from the runtime ripple roadmap.
- `plan.md`: Captured runtime architecture, data model, lifecycle, files to change, validation strategy, risks, and adversarial plan review.
- `tasks.md`: Converted the roadmap phases into ordered implementation and validation tasks.
- `research.md`: Summarized the research direction, options, Godot unknowns, and context challenge notes.
- `validation.md`: Added the current unrun validation snapshot, matrix, Godot launch instructions, human-assisted validation format, and future checks.
- `review.md`: Recorded this docs-only review and the remaining implementation gates.
- `handoff-latest.md`: Added this dashboard and next-session instructions.
- Follow-up docs tightening: Preserved concrete roadmap details for field properties, emitter properties, `i_ripple_*` uniforms, shader behavior, authoring controls, and split Phase 0 safety gates.

## Current Changes Summary

Use this for the latest session only. Move older entries into "Historical Change Log" when this gets long.

- New `river-ripples` feature docs translate `runtime-ripple-simulation-roadmap.md` into the spec-driven workflow without touching code, shaders, scenes, bakes, or generated resources. They now preserve the roadmap's exact field/emitter/uniform details and separate the Phase 0 safety confirmations into independent tasks.

## Historical Change Log

Older change history can live here once the current summary is enough for the next agent.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create `river-ripples` as a dedicated feature folder | The roadmap has enough architecture and validation gates to warrant spec-driven tracking | Use this folder before ripple implementation |
| Rename the copied handoff template to `handoff-latest.md` | `01-workflow.md` requires that convention | Keep future handoff updates in this file |
| Keep first-pass ripples visual-only in docs | Roadmap explicitly says not to alter bakes, WaterSystem, flow, or buoyancy | Challenge physics-facing requests before patching |
| Treat Phase 0 decisions as open gates | The roadmap lists them as acceptance prerequisites | Resolve them before implementation |
| Preserve concrete roadmap details in `spec.md` and `plan.md` | Exact field properties, emitter properties, shader uniforms, and authoring controls should not disappear during implementation | Use those sections before adding public API or shader uniforms |
| Mark the citation-index check complete | The shared citations index already includes the CBerry22 ripple simulation repository | Recheck only when new external sources influence implementation |

## Current State

Implementation status:

- Not started.

Spec/plan status:

- Research: Drafted from roadmap; Godot-specific feedback details need implementation research.
- Spec: Drafted.
- Plan: Drafted.
- Tasks: Drafted with Phase 0 through future work.
- Validation: Drafted; implementation checks unrun.
- Review: Partial docs-only review complete.

Validation status:

- Automated:
  - None for ripple implementation.
- Human-assisted:
  - None.
- Shader:
  - None.
- Editor:
  - None.
- Visual:
  - None.
- Runtime:
  - None.
- Performance:
  - None.
- Manual:
  - Roadmap and templates were read and converted into the feature folder.

## Important Context

- First milestone is visual-only.
- Do not touch river bake resources, source signatures, WaterSystem bake resources, final flow, `system_flow.gdshader`, or buoyancy for first-pass ripples.
- `filter_renderer.gd` proves shader passes exist but is bake-oriented and uses readback; do not copy that runtime pattern into ripple simulation.
- `world_to_ripple_uv` is the intended single production mapping contract.
- Exact first-pass river shader uniform names, field properties, emitter properties, and authoring-control notes are preserved in `spec.md` and `plan.md`.
- Boundary masking is required before visible river overlay. The accepted first source should be target river mesh footprint rendering, not direct UV2 atlas bake textures.
- Material ownership is required before touching river materials.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.

## Artifact Hygiene

- Scratch folders or temporary projects created:
  - None.
- Generated bakes/resources created:
  - None.
- Active files mirrored into scratch validation:
  - None.
- Files/folders that must be excluded from packaging:
  - Future `.codex-research` probes or local captures unless promoted.
- Files/folders safe to delete now:
  - None.

## Known Risks and Open Issues

- No-readback ping-pong feedback is not proven in Godot 4.6+ yet.
- Texture precision and update timing are unknown.
- Material ownership path is not chosen.
- Debug parity path is not chosen.
- Public/prototype node registration status is not chosen.
- Field transform support is not chosen.
- A rectangular debug simulation can look good while still being invalid for river integration.
- Users may expect visual ripples to affect buoyancy; that is intentionally out of scope for the first milestone.

Relevant audit sections:

- No ripple-specific audit section has been checked yet. Before implementation, inspect current files under `addons\waterways\docs\audit\` if that directory exists.

## Blockers

- No implementation blocker for the next planning step.
- Code implementation should wait for Phase 0 decisions and branch safety confirmation.
- Visible Godot/editor/runtime validation will be human-assisted unless an agent can genuinely inspect the running editor.

## Files To Inspect Before Editing

- `addons\waterways\docs\roadmaps\runtime-ripple-simulation-roadmap.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\spec.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\plan.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\tasks.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\validation.md`
- `addons\waterways\river_manager.gd`
- `addons\waterways\filter_renderer.gd`
- `addons\waterways\system_map_renderer.gd`
- `addons\waterways\shaders\river.gdshader`
- `addons\waterways\shaders\river_debug.gdshader`
- `addons\waterways\plugin.gd`

## Commands or Checks Used

```powershell
Get-Content -Raw -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\roadmaps\runtime-ripple-simulation-roadmap.md'
```

Result summary:

- Read the runtime ripple roadmap and preserved its visual-only scope and hard constraints.

```powershell
Get-ChildItem -Force -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\spec-driven\templates\feature-folder'
```

Result summary:

- Found template files: `plan.md`, `research.md`, `review.md`, `session-handoff.md`, `spec.md`, `tasks.md`, and `validation.md`.

```powershell
Test-Path -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\spec-driven\features\river-ripples'
```

Result summary:

- Confirmed the folder did not exist before creation.

## Next Tasks

- [ ] Confirm Phase 0 decisions with the user.
- [ ] Create or confirm a dedicated branch before code work.
- [ ] Build the standalone no-readback feedback spike.
- [ ] Add fixed impulse and debug texture review.
- [ ] Prove `world_to_ripple_uv` mapping with scene and texture markers.

## Do Not Do Yet

- Do not edit `river.gdshader` before feedback, mapping, boundary, and material ownership gates pass.
- Do not mutate shared river materials directly.
- Do not change river bakes, WaterSystem bakes, source signatures, final flow, `system_flow.gdshader`, or buoyancy.
- Do not present ripple nodes as public API until registration status is decided.
- Do not implement camera-following fields until reprojection, clear-on-shift, or tile swapping is designed.

## Notes for the Next Agent

Start with the Phase 0 gate list, not the shader. The roadmap is intentionally risk-ordered because the tempting part, visible rings on the river, depends on feedback ownership, coordinate mapping, boundary masking, material cleanup, debug parity, and shader cost. Keep the first implementation slice standalone until those facts are proven.

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
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://path/to/ripple_probe.gd'
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Validation Commands

Future runtime readback scan after implementation:

```powershell
rg "get_image|ImageTexture|readback|get_texture\\(\\)\\.get_image" "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways"
```

Result summary:

- Record whether any ripple runtime path uses CPU readback. Bake paths may still use readback; the violation is normal runtime simulation or visible rendering.
