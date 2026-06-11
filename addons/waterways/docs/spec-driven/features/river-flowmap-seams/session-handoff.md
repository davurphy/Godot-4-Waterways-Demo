# Session Handoff: River Flowmap Seam Handling

## Date

2026-06-11

## Current Focus

Record the current post-signature-23 visible baseline for the river-flowmap seam feature using `Revised plan to improve seam handling v2.md` as the source direction.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-flowmap-seams\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: Baseline visible diagnosis complete; no visible seam found in either demo scene; implementation not started.
- Highest-priority open task: do not implement a seam fix from stale pre-signature-23 observations. Reopen cheap checks only if a current visible seam is reproduced or the user explicitly asks for extra diagnostics.
- Last passing validation: prior signature 23 probe results recorded in `changelog.md` and the seam audit.
- Latest visible validation: 2026-06-11 baseline screenshot export produced `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`; agent review found no visible straight seam in lit water, raw debug, or derived/material debug views.
- Known failing or unproven check: depth-1 bilinear bleed, normal/tangent continuity, temporal reset, and offset-helper ablations remain unrun because no visible seam exists to correlate against.
- Next recommended action: stop implementation unless new evidence reproduces a seam; if that happens, start with the v2 cheap checks and prefer Build C only if offset sampling is implicated.
- Packaging/artifact hygiene status: `.codex-research/river-flowmap-seams-visible-baseline` contains disposable local screenshots/report; no generated bakes changed.
- Historical detail starts at: `Revised plan to improve seam handling v2.md`.

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
4. `addons\waterways\docs\spec-driven\features\river-flowmap-seams\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-flowmap-seams\review.md`
6. `addons\waterways\docs\spec-driven\features\river-flowmap-seams\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-flowmap-seams\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-flowmap-seams\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-flowmap-seams\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Start from the 2026-06-11 finding: no visible seam remains post-signature-23 in `Demo.tscn` or `Demo_obstacle_flow_test.tscn` in the exported baseline screenshots.
- If the user provides a new screenshot or asks for another pass, reproduce the seam first, then record join index, same-column/row-wrap/column X-edge class, lit vs. unshaded debug, and raw baked vs. derived/material view.
- For Godot-specific implementation work, search current official Godot documentation and API references online before patching. Prefer official docs first, and record any source that affects implementation in `research.md` or `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. Include the evidence, confidence level, and the smallest check that could prove or disprove the premise.

## What Changed This Session

- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\spec.md`: created a feature-specific spec from the template and v2 plan.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\plan.md`: created the diagnosis-first implementation plan with Build C/A/B gates.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\tasks.md`: created the active checklist in v2 order.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\research.md`: summarized v2 evidence, options, and recommendations.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\validation.md`: created the validation matrix and Godot launch/human-assisted procedures.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\review.md`: created the initial review dashboard with unresolved risks.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\session-handoff.md`: created this handoff.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\probes\river_flowmap_visible_baseline_export.gd`: added local validation tooling to export lit, raw, derived, and join-marker screenshots for both demo scenes.
- `.codex-research\river-flowmap-seams-visible-baseline\`: generated disposable local screenshots and `visible_baseline_report.json` for the 2026-06-11 baseline pass.

## Current Changes Summary

- Feature-folder docs now translate v2 into the standard spec-driven workflow and record the first baseline finding: no visible seam remains in the checked post-signature-23 demo scenes. No shader fix or generated bake data has been changed.

## Historical Change Log

Older investigation and signature 23 history lives in:

- `symptoms and initial suspects.md`
- `changelog.md`
- `audit\seam-handling-audit-2026-06-11.md`
- `Plan to improve waterways seam handling.md`
- `Revised plan to improve seam handling.md`
- `Revised plan to improve seam handling v2.md`

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Use v2 as controlling plan | It supersedes v1 and verifies architectural claims against current code. | Keep v1 as historical context only. |
| Make baseline diagnosis the next action | Older visible symptoms predate signature 23. | Capture both demo scenes before code changes. |
| Treat Build C as the first conditional sampling fix | Lateral cross-column reads are the unprotected offset class. | Only implement if ablation/diagnosis implicates it. |
| Keep Build A and Build B conditional | Strip packing and logical-neighbor sampling are broader than the current evidence justifies. | Revisit only after smaller checks. |

## Current State

Implementation status:

- Not started; baseline stopped before code changes because no current visible seam was found.

Spec/plan status:

- Research: drafted from v2
- Spec: drafted
- Plan: drafted
- Tasks: drafted
- Validation: drafted, partial proof only from prior probes
- Review: updated with baseline visible classification and no-current-seam finding

Validation status:

- Automated:
  - Prior docs report `RIVER_FLOWMAP_SEAM_PROBE_OK`, `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`, and `RIVER_FLOWMAP_SEAM_REBAKE_OK`.
- Human-assisted:
  - No separate user-run editor review recorded. Agent reviewed exported screenshots for both scenes.
- Shader:
  - Ablations not run.
- Editor:
  - Material override check recorded: zero-default pillow forward/contact offsets are `0.0`; height smoothing is `0.1`.
- Visual:
  - Current post-signature-23 screenshot review passed with no visible seam.
- Runtime:
  - Temporal quick confirmation not run because no visible seam/pulse was reproduced.
- Performance:
  - Not applicable yet.
- Manual:
  - Not run.

## Important Context

- The v2 plan says the visible problem may already be partly or fully gone after signature 23.
- The first step 1 finding is now recorded: no visible seam remains in the checked post-signature-23 `Demo.tscn` and `Demo_obstacle_flow_test.tscn` baseline.
- The current square atlas uses `i_uv2_sides`; demo bakes are 17 and 18 occupied steps at `uv2_sides = 5`.
- Longitudinal row-wrap offsets are already protected up to the current 0.70-tile maximum by one-tile continuation margins.
- Lateral offsets crossing interior column X edges are the smaller unprotected sampling class.
- Depth-1 bilinear bleed in terrain-contact channels is a separate hypothesis and is not fixed by Build C, Build A, or Build B.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future Codex sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.
- For Godot 4.6+ implementation, use official docs before patching API-sensitive code.
- If no visible seam remains, say so and do not silently continue into code changes. This condition is currently true for the recorded baseline.

## Artifact Hygiene

- Scratch folders or temporary projects created: `.codex-research\river-flowmap-seams-visible-baseline` for local screenshots/report.
- Generated bakes/resources created: none.
- Active files mirrored into scratch validation: none.
- Files/folders that must be excluded from packaging: `.codex-research`, temporary screenshots, probe output folders, editor caches.
- Files/folders safe to delete now: `.codex-research\river-flowmap-seams-visible-baseline` if the local screenshot evidence is no longer needed.

## Known Risks and Open Issues

- No current visible seam is reproduced in the checked baseline.
- Depth-1/2 terrain-contact deltas may or may not be visible bilinear bleed, but there is no current visible seam to correlate against.
- Lit-only seams could be normal/tangent basis discontinuities if a future lit-only seam is reproduced.
- Material overrides do not make zero-default pillow forward/contact offsets live in the checked demo scenes.
- Strip packing has a hidden per-tile resolution and metadata cost.
- The full logical sampler may be unnecessary because current longitudinal offsets fit within continuation margins.

Relevant audit sections:

- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\audit\seam-handling-audit-2026-06-11.md`: validated signature 23 exact edge-row and world-sample probes, and notes human-visible review is still necessary.

## Blockers

- No current seam-backed implementation target exists.
- No depth-1 bilinear-bleed probe exists or has been run in this workflow.
- Local Godot/editor visual access may be unreliable; the current baseline used exported screenshots rather than interactive editor manipulation.

## Files To Inspect Before Editing

- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/Revised plan to improve seam handling v2.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/spec.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/plan.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/tasks.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/validation.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/review.md`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_world_sample_probe.gd`

## Commands or Checks Used

```powershell
Get-ChildItem -Force -LiteralPath "addons\waterways\docs\spec-driven\templates\feature-folder"
Get-Content -Raw -LiteralPath "addons\waterways\docs\spec-driven\features\river-flowmap-seams\Revised plan to improve seam handling v2.md"
rg --files "addons\waterways\docs\spec-driven\features\river-flowmap-seams\probes"
& "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo" --script "res://addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_visible_baseline_export.gd"
```

Result summary:

- The template folder contains `spec.md`, `plan.md`, `tasks.md`, `research.md`, `validation.md`, `review.md`, and `session-handoff.md`.
- v2 is the superseding plan and is now reflected in feature-specific docs.
- Existing probe files are present for seam, world-sample, and rebake validation.
- Visible baseline exporter produced `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`.
- Agent screenshot review found no visible seam in either demo scene, including lit water, raw baked debug views, derived/material debug views, and lit join-marker overlays.
- Demo material overrides keep `pillow_forward_reach_tiles` and `pillow_contact_pull_strength` at `0.0` in both scenes; `pillow_height_smoothing_tiles` is `0.1`.

## Next Tasks

- [x] Inspect demo material overrides for zero-default pillow uniforms.
- [x] Record whether any visible seam remains at all post-signature-23 in both demo scenes.
- [x] If seams remain, classify their join positions and lit/debug/raw/derived context. Result: no seams remain, so no classification records exist.
- [ ] Add or run the depth-1 bilinear-bleed probe only if a current visible seam is reproduced or extra diagnostics are requested.
- [ ] Run normal/tangent continuity and temporal quick checks only if a current visible artifact makes them relevant.
- [ ] Run individual offset-helper ablations only against a reproduced visible seam.
- [ ] Choose the smallest evidence-backed fix, starting with Build C if lateral cross-column reads are implicated.

## Do Not Do Yet

- Do not implement strip packing before visible evidence points to row-wrap or column X-edge seams and the spike is complete.
- Do not implement the full logical sampler before ablation proves a longitudinal offset path needs it.
- Do not enable pillow seam fades as the acceptance fix.
- Do not change bake data to force depth-1 rows to match until the depth-1 probe proves the band is a visible problem rather than expected data variation.

## Notes for the Next Agent

Start from the recorded baseline: the current symptom was not reproduced in the exported screenshot pass. If a seam appears later in an unshaded debug view, focus on data/sampling. If it appears only in lit water, check normals/tangents and material amplification. If offset sampling is implicated, the v2 plan wants Build C before bigger structural work.

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
& $godotConsole --path $root --script "res://addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd"
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Validation Commands

Run the current seam probe:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe" }
$godotUser = Join-Path $root ".codex-research\godot-user-river-flowmap-seams"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd"
```

Run the current world-sample probe:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe" }
$godotUser = Join-Path $root ".codex-research\godot-user-river-flowmap-seams"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_world_sample_probe.gd"
```
