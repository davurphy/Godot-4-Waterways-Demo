# Session Handoff: River Eddies

## Date

2026-06-04

## Current Focus

Refresh the River Eddies feature folder to match the newer spec-driven feature-folder templates while preserving the accepted Phase 7B visual wake/eddy-line baseline.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-eddies\`
- Active add-on path:
  - `addons\waterways`
- Legacy reference path:
  - `legacy\godot-3\addons\waterways`

## Current Truth

- Overall status: Phase 7B visual wake/eddy-line material preview accepted.
- Highest-priority open task: Preserve accepted Phase 7B behavior and classify any future eddy request by layer before editing.
- Current baseline: `Eddy-Line Visual Mask` uses the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- Known preserved diagnostics: old raw-B path remains available through B-based debug views.
- Last passing validation: Historical Godot 4.6.3 probes `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_WAKE_EDDY_EXPORT_OK`, and `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`; user accepted the visible result.
- Known failing or unproven check: Real reverse/circulating flow, WaterSystem/physics alignment, and new eddy vector data are deferred and unimplemented.
- Next recommended action: If future eddy work is requested, review raw source first, final visual mask second, and visible water last. If real flow is requested, write a Phase 7C plan first.
- Packaging/artifact hygiene status: No new generated artifacts from this docs style refresh.
- Historical detail starts at: `Historical Change Log`

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
4. `addons\waterways\docs\spec-driven\features\river-eddies\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-eddies\review.md`
6. `addons\waterways\docs\spec-driven\features\river-eddies\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-eddies\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-eddies\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-eddies\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- For visual tuning, first confirm the raw-G source and final `Eddy-Line Visual Mask` are still placed correctly.
- For source/mask placement issues, compare raw G, old raw-B diagnostics, final mask, and visible water at the same targets.
- For reverse/circulating flow requests, stop and draft Phase 7C before implementation.
- If this requires human-assisted Godot validation, paste the exact request from `validation.md` into the user-facing chat message.
- If the user or agent treats Phase 7B as physics, clarify that it is visual-only before patching.

## What Changed This Session

- `addons\waterways\docs\spec-driven\features\river-eddies\spec.md`: Added the newer dashboard cue and shared citations reminder while preserving the accepted Phase 7B baseline.
- `addons\waterways\docs\spec-driven\features\river-eddies\plan.md`: Updated the plan dashboard, branch-safety note, and documentation plan to match the newer template style.
- `addons\waterways\docs\spec-driven\features\river-eddies\research.md`: Added the shared works-cited guidance and premise/context questions from the newer research template.
- `addons\waterways\docs\spec-driven\features\river-eddies\tasks.md`: Refreshed the task dashboard and setup checklist for the current template expectations.
- `addons\waterways\docs\spec-driven\features\river-eddies\validation.md`: Added the validation dashboard cue, shared citations check, exact Godot launch instructions, and updated manual checklist item.
- `addons\waterways\docs\spec-driven\features\river-eddies\review.md`: Updated the latest review date/scope and recorded the 2026-06-04 docs style alignment decision.
- `addons\waterways\docs\spec-driven\features\river-eddies\handoff-latest.md`: Added the newer "How To Use This Feature Folder" section, shared citations reading step, latest-session summary, and Godot launch instructions.

## Current Changes Summary

- 2026-06-04 docs style refresh: The feature folder now follows the newer template organization without changing the accepted Phase 7B visual-only eddy baseline.

## Historical Change Log

- 2026-05-31 feature-folder migration consolidated wake/eddy-line-specific state from the general changelog, latest handoff, and relevant roadmap sections into spec-driven docs.
- Phase 7A0 completed research and adversarial plan review without behavior changes.
- Phase 7A1 added review-only wake/eddy mask preflight and exports.
- Phase 7A2 narrowed raw `obstacle_features.b`, bumped river bakes to signature `17`, and kept final flow/WaterSystem unchanged.
- Phase 7B added visual-only wake/eddy material controls, masks, debug views, probes, and exports.
- User review rejected the edge-sample-only fix.
- User review accepted the raw-G wake-edge candidate as the source for paired eddy-line margins.
- `wake_edge_sample_tiles` default became `0.024` as part of the accepted raw-G source path.
- Debug-material override behavior was fixed so visible Wake / Eddy fields affect normal rendering.
- Visible eddy-line defaults were increased after the first visible result was too subtle.
- Phase 7B was accepted as visual-only and should be preserved.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create `features/river-eddies/`. | Wake/eddy-line work needed a feature-local source of truth. | Use this folder before future eddy edits. |
| Preserve Phase 7B as accepted baseline. | User accepted the visible material pass. | Re-run Phase 7B checks after shared shader/classifier changes. |
| Record raw-G over raw-B as channel/phase alignment. | Raw B was plausible but spatially wrong; raw G produced accepted paired margins. | Keep old B-based diagnostics available. |
| Keep Phase 7B visual-only. | Existing scalar masks do not encode reverse/circulating velocity. | Plan Phase 7C separately before flow work. |
| Require human-assisted validation steps in chat. | Visible editor/runtime review is acceptance, not just an internal note. | Paste `validation.md` request into future chat messages. |

## Current State

Implementation status:

- Existing Phase 7B visual implementation is accepted; no code changed in this docs style refresh.

Spec/plan status:

- Research: Current recommendation, Phase 7 findings, deferred Phase 7C options, and shared citations guidance captured.
- Spec: Feature definitions, review layers, acceptance criteria, non-goals, and current dashboard are aligned with the newer template style.
- Plan: Preservation-first architecture and Phase 7B/7C/7D boundaries are retained; documentation plan and branch-safety notes are refreshed.
- Tasks: Open checklist remains canonical; setup now includes the shared citations reminder for research-driven changes.
- Validation: Matrix, human-assisted request, generalization checks, historical probes, and exact Godot launch instructions are recorded.
- Review: Current risks, 2026-06-04 style alignment decision, and deferred flow requirements are recorded.

Validation status:

- Automated:
  - Historical pass markers are listed in `validation.md`.
- Human-assisted:
  - Historical user acceptance recorded. Needed again after any future visual or flow change.
- Shader:
  - Existing wake/eddy shaders passed historical probes.
- Editor:
  - Historical material override issue fixed.
- Visual:
  - Phase 7B accepted.
- Runtime:
  - Not scoped for Phase 7B; required for Phase 7C/7D.
- Performance:
  - Not changed.
- Manual:
  - Future issues must use raw/final/visible review order.

## Important Context

- Phase 7B is visual-only.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.
- Current accepted baseline: `Eddy-Line Visual Mask` uses raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- Raw B was plausible but too far from the close-behind-rock shoulders; it remains diagnostic, not the accepted visual source.
- Bigger sampling alone was rejected. `0.024` became accepted only with the source change to raw G.
- The old B-based path remains available through `Eddy-Line / Shear Mask`, `Gated Eddy-Line Source (B * Wake Gate)`, `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, and `Eddy-Line Wake Context Search`.
- Preserve `Wake Visual Mask`, `Wake Edge Thinness`, `Raw Wake-Edge Candidate (from G)`, `Experimental Wake-Edge Eddy Source`, and `Eddy-Line Visual Mask` review views.
- Do not tune around the start-of-river hotspot.
- Review good eddy-line anatomy: downstream rock shoulders, two trailing wake margins, quieter wake center, no upstream pillow-face outline, no long ordinary-bank strips.
- Raw source masks, final visual masks, and visible material response are separate layers.
- Current river bakes are signature `19`.
- The saved WaterSystem bake was last regenerated after Phase 5B/signature `16`; do not regenerate it unless final/physics flow changes are scoped.
- Phase 7C reverse/circulating flow must update visible shader, debug shader, system-flow shader, WaterSystem generation, and runtime validation together.

## Artifact Hygiene

- Scratch folders or temporary projects created: None in this docs style refresh.
- Generated bakes/resources created: None.
- Active files mirrored into scratch validation: Not applicable.
- Files/folders that must be excluded from packaging:
  - `.codex-research/`
  - Generated review captures unless intentionally committed.
- Files/folders safe to delete now: None identified.

## Known Risks and Open Issues

- Future work could accidentally treat visual-only masks as physics.
- Future shared classifier changes could alter accepted Phase 7B eddy-line behavior.
- Start-of-river hotspot could mislead tuning.
- Ordinary-bank suppression must remain checked.
- Real reverse/circulating flow has no accepted vector/data model yet.
- WaterSystem/physics alignment is deferred.

Relevant audit sections:

- No eddy audit document exists for this migration.

## Blockers

- No blocker for current Phase 7B preservation.
- Human-visible Godot/editor review is required for any future visual placement acceptance.
- Local parser/probe signal is not enough to accept visible eddy-line placement.
- Phase 7C is blocked on a real flow/data plan and runtime validation design.

## Files To Inspect Before Editing

- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/gui/debug_view_menu.gd`
- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`
- `addons/waterways/resources/river_bake_data.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/system_map_renderer.gd`
- `addons/waterways/shaders/system_renders/system_flow.gdshader`
- `.codex-research/phase7b_eddy_line_cpu_diagnostic.gd`
- `.codex-research/export_demo_phase7b_wake_edge_sample_sweep.gd`
- `.codex-research/phase7b_wake_eddy_demo_debug/`
- `.codex-research/phase7b_wake_edge_sample_sweep/`

## Commands or Checks Used

```powershell
git status --short --branch
rg --files "addons/waterways/docs/spec-driven/features/river-eddies"
rg --files "addons/waterways/docs/spec-driven/templates"
Get-Content -Raw "addons/waterways/docs/spec-driven/templates/feature-folder/*.md"
Get-Content -Raw "addons/waterways/docs/spec-driven/features/river-eddies/*.md"
```

Result summary:

- Current branch was `eddy` and the worktree was clean before the docs refresh.
- The eddy feature docs already preserved the accepted Phase 7B baseline; this pass aligned them with newer template organization and handoff style.
- No Godot runtime validation was run during this docs-only refresh.

## Next Tasks

- [ ] Use this feature folder before future wake/eddy edits.
- [ ] Lock one detection or flow question before tuning.
- [ ] Preserve accepted raw-G `Eddy-Line Visual Mask` baseline.
- [ ] Preserve old B-based diagnostics.
- [ ] Use raw source, final visual mask, visible water review order.
- [ ] Add raw readings or named-region stats only if target coverage is ambiguous.
- [ ] Draft Phase 7C before reverse/circulating flow implementation.
- [ ] Update this feature folder after every decision, validation run, or implementation slice.

## Do Not Do Yet

- Do not change source flow, final flow, reverse flow, or circulating eddy behavior without a Phase 7C plan.
- Do not regenerate the saved WaterSystem bake for visual-only work.
- Do not remove old raw-B diagnostics.
- Do not treat the start-of-river hotspot as acceptance.
- Do not tune material strength before raw/final placement is accepted.
- Do not change `RiverBakeData` layout or source signatures unless data/bake work is explicitly scoped.

## Notes for the Next Agent

The important thing to preserve is not just a set of parameter values. It is the review lesson: raw B looked plausible, but it was spatially wrong for the accepted close-behind-rock eddy-line. Raw G gave the paired wake-edge margins the user accepted. Keep that distinction alive, and do not let visual eddy-line polish drift into unvalidated reverse-flow or WaterSystem behavior.

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
