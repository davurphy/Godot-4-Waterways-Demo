# Session Handoff: River Waterline and Bank Flow Corrections

## Date

2026-06-15

## Current Focus

Diagnose and fix two reported river issues: missing water near protruding/wide-top obstacles, and isolated inward bank flow patches.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: Waterline overhang gap is classified, patched in code, rebaked by the user, and visually resolved at the reported red-circled locations.
- Highest-priority open task: classify the separate bank-inward-flow issue with focused magnitude/location evidence.
- Last passing validation: 2026-06-16 user rebaked the affected river after the patch and reported the missing-water regions are resolved; 2026-06-15 `waterline_occupancy_probe.gd` after patch reported `current_upper_open=0` for `Cliffs/cliff2`.
- Known failing or unproven check: bank-inward-flow screenshot/location is not yet classified.
- Next recommended action: build or run a focused bank-flow diagnostic only after the specific reported bank location is known.
- Packaging/artifact hygiene status: production code and probe/docs changed; user rebaked the affected river resource after the patch; probe PNG output is ignored.
- Historical detail starts at: none yet.

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and the shared citations index only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Message To Next Session

Start from the current code patch, not from scratch. The old obstacle-flow fix was present, but the collision map still allowed top-down/down-ray hits to mark open waterline under overhangs as solid. The current patch gates those hits on actual waterline contact.

Read, in this order:

1. This file, especially `Current Truth`, `Important Context`, and `Do Not Do Yet`.
2. `addons\waterways\docs\spec-driven\features\river-obstacle-flow-constraints\implementation-plan.md`
3. `addons\waterways\docs\spec-driven\features\river-obstacle-flow-constraints\spec.md`
4. `addons\waterways\docs\spec-driven\features\river-obstacle-flow-constraints\validation.md`
5. `addons\waterways\docs\spec-driven\features\river-obstacle-flow-constraints\probes\README.md`
6. `addons\waterways\probes\README.md`
7. This feature's `tasks.md`, `validation.md`, `plan.md`, and `research.md`.

Then do this:

1. Check branch/worktree state first. There was already an unrelated modified generated bake: `waterways_bakes/Demo/Water_River.river_bake.res`. Do not overwrite, revert, or casually rebake it.
2. Build a prior-fix comparison checklist. Current code must be checked for `water_occupancy`, `flow_projected`, `RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN`, runtime slide gating when projected, and FLOW_ARROWS low-speed/sub-cell fallback behavior. Status 2026-06-15: these mechanisms are present in current code and the safe Demo bake probes pass; this still does not classify screenshot-specific locations.
3. User supplied three red-circled screenshots of missing water under overhangs near `Cliffs/cliff2` in normal view, then rebaked after the patch and confirmed the missing water is resolved.
4. Run read-only/safe probes before anything that saves bakes.
5. The waterline gap is classified, code-patched, rebaked, and visually confirmed fixed; do not reopen it unless a new screenshot shows a fresh failure.

Suggested probe order:

- Headless/read-only first:
  - `res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_occupancy_flow_inspect_probe.gd`
  - `res://addons/waterways/probes/flow_arrow_neutral_cells_probe.gd -- bake=<reported river bake>`
  - `res://addons/waterways/probes/flow_arrow_direction_outlier_probe.gd -- bake=<reported river bake>`
  - `res://addons/waterways/probes/system_flow_compare_probe.gd -- enforce=all` if the issue might affect WaterSystem/duck-read flow or stale system maps.
  - `res://addons/waterways/probes/river_flowmap_seam_probe.gd` if inward bank patches line up with atlas/tile boundaries or after any flow bake change.
  - `res://addons/waterways/probes/bake_inspect_probe.gd -- bake=<reported bake> texture=water_occupancy channel=r` and related channels if a screenshot needs texture-level proof.
- Windowed but non-rebake review:
  - `res://addons/waterways/probes/debug_view_capture_probe.gd -- views="Flow Arrows,Final Flow Strength" scene=<scene> label=<case>`
  - `res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_debug_view_capture_probe.gd` if the older feature-specific capture path is more convenient.
  - `res://addons/waterways/probes/system_flow_projected_gate_probe.gd` to prove the projected-flow slide gate is actually exercised.
  - `res://addons/waterways/probes/r7_compute_saved_resource_load_smoke_probe.gd` if you need a saved-resource/material-binding smoke check without rebaking.
- Dangerous/mutating only after explicit decision:
  - `res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_obstacle_projection_rebake_probe.gd` rebakes and saves both demo river bakes on success.
  - `res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/water_system_rebake_probe.gd` saves a WaterSystem map.
  - `res://addons/waterways/probes/rebake_probe.gd` saves river and WaterSystem bakes by default.

Probe compatibility result from 2026-06-15:

- Still working:
  - `river_occupancy_flow_inspect_probe.gd`
  - `flow_arrow_neutral_cells_probe.gd`
  - `flow_arrow_direction_outlier_probe.gd`
  - `system_flow_compare_probe.gd` with `allow_stale=1`
  - `river_flowmap_seam_probe.gd`
  - `bake_inspect_probe.gd`
  - `system_flow_projected_gate_probe.gd`
  - `debug_view_capture_probe.gd`
  - `r7_compute_saved_resource_load_smoke_probe.gd`
  - old feature-specific `river_debug_view_capture_probe.gd`
- Works but reports important data caveat:
  - `system_flow_compare_probe.gd -- enforce=all` exits nonzero without `allow_stale=1` because both saved WaterSystem maps are stale relative to the river bakes/signatures.
- Suspect:
  - `river_source_image_hash_probe.gd` timed out after 120s after loading `Demo.tscn`; a leftover Godot process was closed. Investigate before relying on it.

Expected classification outcomes:

- Missing-water gap: classified as a collision-occupancy false positive from top-down/down-ray hits over open waterline; fixed and visually resolved after user rebake.
- Inward bank flow: classify as baked-flow defect, runtime shader defect, debug-arrow artifact, low-magnitude residual, stale system/river map, seam/tile issue, or deliberate local geometry behavior.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\review.md`
6. `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Compare current code, material bindings, metadata, and generated bakes to `addons\waterways\docs\spec-driven\features\river-obstacle-flow-constraints\implementation-plan.md`, `spec.md`, and `validation.md`.
- Treat the missing-water screenshots as resolved after the user rebake recorded in `validation.md`.
- For any remaining bank-flow screenshot, capture: scene, view mode, river/bake resource if known, whether bakes were fresh, symptom type, and suspected location.
- For Godot-specific implementation work, search current official Godot documentation and API references online before patching. Prefer official docs first, and record any source that affects implementation in `research.md` or `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. Include the evidence, confidence level, and the smallest check that could prove or disprove the premise.

## What Changed This Session

- `addons/waterways/water_helper_methods.gd`: added waterline-contact gating for collision occupancy so top-down/down-ray hits do not remove open water under overhangs.
- `addons/waterways/river_manager.gd`: bumped `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` from 29 to 30.
- `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\probes\waterline_occupancy_probe.gd`: added a non-mutating focused probe for `Cliffs/cliff2`.
- `addons\waterways\docs\spec-driven\features\river-waterline-bank-flow-corrections\`: created feature folder.
- `spec.md`: captured the waterline issue as fixed/validated and the bank-flow issue as the remaining unverified requirement.
- `plan.md`: defined a diagnosis-first plan and likely future probe/code touch points.
- `research.md`: summarized local related-feature context and candidate root-cause options.
- `tasks.md`: created the active checklist.
- `validation.md`: created the validation matrix and human-assisted screenshot request format.
- `review.md`: recorded initial risks and next action.
- `handoff-latest.md`: recorded the next-session entry point.
- `screenshots\.gitignore`: created an ignored holding area for local screenshot evidence.

## Current Changes Summary

- Production code changed in `water_helper_methods.gd` and `river_manager.gd`.
- Focused probe/docs changed under the feature folder.
- No generated bakes/resources were intentionally saved by the agent during the patch pass. The user later rebaked the affected river, so `waterways_bakes/Demo/Water_River.river_bake.res` should be treated as user-authored validation output and not reverted without direction.

## Historical Change Log

Older change history can live here once the current summary is enough for the next agent.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create a new feature folder named `river-waterline-bank-flow-corrections`. | The issues overlap previous work but need fresh screenshot/probe evidence. | Classify screenshots before implementation. |
| Treat `river-obstacle-flow-constraints` as primary baseline. | User clarified the old fixes worked for a while and may have been lost. | Audit current project against the old docs before new design. |
| Patch waterline collision occupancy. | Focused probe showed current collision logic marked 259 open-waterline texels as solid via top-down/down-ray hits near `Cliffs/cliff2`. | Completed; user rebake visually resolved the missing water. |
| Bump bake signature to 30. | Collision occupancy semantics changed, so old saved bakes must not be treated as current. | River rebake completed by user for the reported gap; WaterSystem maps may still need separate refresh if runtime/system flow is validated. |

## Current State

Implementation status:

- Waterline overhang code patch implemented and visually validated after user rebake; bank-flow implementation not started.

Spec/plan status:

- Research: partial local frame plus safe-probe findings.
- Spec: draft.
- Plan: draft with baseline status.
- Tasks: active checklist updated.
- Validation: matrix plus first safe-probe result.
- Review: partial evidence-pass review.

Validation status:

- Automated:
  - Probe compatibility partial pass and safe baseline probe pass on 2026-06-15. See `validation.md`.
- Human-assisted:
  - User rebaked after the patch and confirmed the red-circled missing-water areas are resolved.
- Shader:
  - None.
- Editor:
  - None.
- Visual:
  - Missing-water issue passed after user rebake; bank-flow visual evidence still needed if pursued.
- Runtime:
  - None.
- Performance:
  - None.
- Manual:
  - Documentation scaffold plus baseline comparison notes.

## Important Context

- Existing related work may already cover part of the suspected obstacle issue. Read `../river-obstacle-flow-constraints/` before editing occupancy/projection behavior.
- More strongly: assume regression/lost-change is plausible until disproven. The older obstacle-flow docs are the expected behavior baseline, not just background reading.
- Existing object artifact work discusses wide tops, overhangs, and object participation. Read `../river-object-artifacts/` before changing terrain-contact or collision classification.
- Direction-only evidence is weak near zero flow magnitude. Bank-flow probes must record magnitude and local downstream/inward basis.
- The worktree had an unrelated modified generated bake resource when this folder was created: `waterways_bakes/Demo/Water_River.river_bake.res`. Do not overwrite or revert it without user direction.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.

## Artifact Hygiene

- Scratch folders or temporary projects created:
  - `.codex-research\godot-user-probe-compat`
  - `.codex-research\godot-user-probe-compat-windowed`
- Generated bakes/resources created:
  - none.
- Active files mirrored into scratch validation:
  - none.
- Files/folders that must be excluded from packaging:
  - future probe output folders and local screenshot scratch.
- Files/folders safe to delete now:
  - none.

## Known Risks and Open Issues

- Missing-water screenshots showed saved-bake/current-code collision false positives under overhangs; current code is patched and the user rebake resolved the visible symptom.
- Saved WaterSystem maps are stale relative to the current river bakes/signatures, as reported by `system_flow_compare_probe.gd`.
- Visible mesh and collision footprint may differ at the waterline.
- Existing debug views can misrepresent low-magnitude vectors or solid-center sampled cells.
- A future rebake probe could modify generated resources.
- The bank-flow issue may overlap seam/tile/bank response behavior rather than obstacle detection.
- `river_source_image_hash_probe.gd` may be slow or drifted; it timed out during compatibility testing.
- The 2026-06-15 safe pass makes a broad loss of the old obstacle-flow fix unlikely on the current Demo saved bakes, but screenshots may still show stale bakes, different scenes, true collider footprints, shader/debug artifacts, or a new waterline/bank edge case.

Relevant audit sections:

- `addons\waterways\docs\spec-driven\features\river-obstacle-flow-constraints\validation.md`: prior obstacle projection and occupancy validation.
- `addons\waterways\docs\spec-driven\features\river-object-artifacts\spec.md`: prior object classification and overhang artifact context.
- `addons\waterways\docs\spec-driven\features\river-flowmap-seams\validation.md`: possible seam-related flow checks.

## Blockers

- Bank-inward-flow issue still needs screenshot/location classification before implementation.
- No branch-safety decision has been recorded for additional generated-resource changes.
- Local headless Godot probes have run; user provided after-rebake visible validation for the missing-water issue.

## Files To Inspect Before Editing

- `addons/waterways/river_manager.gd`
- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/river_flow_common.gdshaderinc`
- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/`
- `addons/waterways/docs/spec-driven/features/river-object-artifacts/`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/`

## Commands or Checks Used

```powershell
Get-ChildItem -LiteralPath 'addons\waterways\docs\spec-driven\templates\feature-folder' -Force
Get-ChildItem -LiteralPath 'addons\waterways\docs\spec-driven' -Force
rg --files 'addons\waterways\docs\spec-driven'
git status --short
```

Result summary:

- Template files found: `plan.md`, `research.md`, `review.md`, `session-handoff.md`, `spec.md`, `tasks.md`, `validation.md`.
- New feature folder did not already exist.
- Worktree already had one unrelated modified generated bake resource.

Probe compatibility commands used on 2026-06-15:

```powershell
& $godotConsole --headless --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_occupancy_flow_inspect_probe.gd'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/flow_arrow_neutral_cells_probe.gd' -- 'bake=res://waterways_bakes/Demo/Water_River.river_bake.res'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/flow_arrow_neutral_cells_probe.gd' -- 'bake=res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/flow_arrow_direction_outlier_probe.gd' -- 'bake=res://waterways_bakes/Demo/Water_River.river_bake.res'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/flow_arrow_direction_outlier_probe.gd' -- 'bake=res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/system_flow_compare_probe.gd' -- 'enforce=all'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/system_flow_compare_probe.gd' -- 'enforce=all' 'allow_stale=1'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/river_flowmap_seam_probe.gd'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/bake_inspect_probe.gd' -- 'bake=res://waterways_bakes/Demo/Water_River.river_bake.res' 'texture=water_occupancy' 'channel=r'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/bake_inspect_probe.gd' -- 'bake=res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res' 'texture=water_occupancy' 'channel=r'
& $godotConsole --path $root --script 'res://addons/waterways/probes/system_flow_projected_gate_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/probes/debug_view_capture_probe.gd' -- 'views=Flow Arrows,Final Flow Strength' 'stations=2' 'scene=res://Demo_obstacle_flow_test.tscn'
& $godotConsole --path $root --script 'res://addons/waterways/probes/r7_compute_saved_resource_load_smoke_probe.gd'
& $godotConsole --headless --path $root --script 'res://addons/waterways/probes/river_source_image_hash_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_debug_view_capture_probe.gd' -- 'scene=res://Demo_obstacle_flow_test.tscn' 'mode=7' 'stations=2'
```

Result summary:

- All listed probes reached success markers except `system_flow_compare_probe.gd -- enforce=all` without `allow_stale=1` (stale WaterSystem maps) and `river_source_image_hash_probe.gd` (timeout after 120s).
- Diagnostic PNG/screenshots were written only under ignored probe output folders.
- Follow-up safe baseline run in this session confirmed current code and saved Demo bakes still have the prior mechanisms: `water_occupancy`, `flow_projected`, protrusion-confidence gating, projected-flow slide gates, and FLOW_ARROWS low-speed/sub-cell fallback. Main Demo solid coverage was 14.12%; obstacle test solid coverage was 14.78%; seam probe passed; arrow outliers were low-count and low-magnitude.

## Next Tasks

- [ ] Record the screenshots and context.
- [ ] Compare screenshot locations against the passing probes.
- [ ] Investigate or replace `river_source_image_hash_probe.gd`.
- [ ] Read the related prior feature folders in detail.
- [ ] Decide whether new probes are needed.
- [ ] Revisit branch safety before code or generated-resource changes.

## Do Not Do Yet

- Do not patch occupancy, collision, projection, or shader behavior before classifying the screenshots.
- Do not run rebake probes that save resources without warning the user and checking worktree state.
- Do not assume bank inward arrows are real flow until magnitude and source data are checked.
- Do not revert the existing modified bake resource.

## Notes for the Next Agent

The user's language is intentionally loose because the issue is not fully diagnosed. Preserve that posture. Treat the screenshots as evidence to classify, not as proof of a specific root cause.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so Codex does not alter the user's normal Godot editor profile.

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
