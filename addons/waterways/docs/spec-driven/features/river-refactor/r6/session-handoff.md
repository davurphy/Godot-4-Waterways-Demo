# Session Handoff: River Refactor R6 - river_manager.gd Decomposition

## Date

2026-06-13

## Current Focus

Create the R6 feature-folder documents from the template and populate them from the existing R6 plan. R6 implementation has not started.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-refactor\r6\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: Not started. R6 planning docs are drafted; no R6 code or validation probes have been implemented in this folder yet.
- Highest-priority open task: review/check in the R6 documentation gate, then implement canonical baseline probes and capture pre-R6 evidence.
- Last passing validation: none for R6. Parent R5 validation closed on 2026-06-13.
- Known failing or unproven check: all R6 validation is unrun.
- Next recommended action: build the canonical metadata/signature/settings dump probe and capture pre-R6 baselines before moving code.
- Packaging/artifact hygiene status: no R6 scratch artifacts created yet.
- Historical detail starts at: none.

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Use `plan.md` as the detailed implementation roadmap.
- Open `spec.md`, `research.md`, and the shared citations index when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-refactor\r6\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-refactor\r6\review.md`
6. `addons\waterways\docs\spec-driven\features\river-refactor\r6\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-refactor\r6\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-refactor\r6\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-refactor\r6\research.md`
10. `addons\waterways\docs\spec-driven\features\river-refactor\roadmap.md`
11. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Review and check in the R6 docs. After that, implement the canonical dictionary dump probe and capture pre-R6 dictionary, texture-hash, source-image, API/signal, and property-list baselines.
- For Godot-specific implementation work, search current official Godot documentation and API references online before patching. Prefer official docs first, and record any source that affects implementation in `research.md` or the shared citations index.
- If human-assisted Godot validation is required, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. Paste the steps into the user-facing message instead of telling the user to read `validation.md`.
- If a mismatch appears before R6 logic changes, treat stale or non-fresh baselines as the first suspect and explain that before patching.

## What Changed This Session

- `spec.md`: drafted R6 goals, non-goals, source timing contract, helper boundaries, and acceptance tests.
- `validation.md`: drafted R6 validation matrix, canonical dictionary dump format, dynamic metadata allow-list, abort inventory, success-order inventory, no-reach-back checklist, and human-assisted validation request.
- `tasks.md`: drafted active R6 checklist from `plan.md`.
- `research.md`: drafted local research questions, options, recommendation, and implementation research needs.
- `review.md`: drafted pre-implementation review with open risks and unproven criteria.
- `session-handoff.md`: drafted this handoff.

## Current Changes Summary

- R6 feature-folder companion documents now exist beside the pre-existing `plan.md`. Implementation and validation remain unstarted.

## Historical Change Log

Empty.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Preserve mixed source timing by default. | R6 is behavior-preserving; freeze-at-start would be a behavior change. | Add mid-bake edit proof before any timing change. |
| Keep RiverManager as the final result applicator. | RiverManager owns public node state, material binding, resource saving, and signals. | Baker returns `BakeResult`; RiverManager applies it. |
| Treat `bake_revision` as the only allowed dynamic metadata diff. | It is time-derived through `_make_bake_revision()`. | Any additional ignored metadata key must be a review finding. |

## Current State

Implementation status:

- Not started.

Spec/plan status:

- Research: Drafted; implementation-specific Godot docs still need lookup before code work.
- Spec: Drafted.
- Plan: Existing detailed R6 plan remains the implementation roadmap.
- Tasks: Drafted.
- Validation: Drafted; no R6 run yet.
- Review: Drafted pre-implementation review.

Validation status:

- Automated: none for R6.
- Human-assisted: none for R6.
- Shader: no R6 shader change intended.
- Editor: unrun.
- Visual: unrun.
- Runtime: unrun.
- Performance: unrun.
- Manual: docs scaffolded from plan.

## Important Context

- R6 is blocked on docs and baselines before code changes.
- `plan.md` forbids passing a general RiverManager reference into the baker. Named dependencies/callbacks only.
- The default source-timing contract preserves current mixed timing. Do not freeze everything at bake start unless the spec and validation are deliberately updated.
- Whole-resource `.res` hashes are not the gate; use per-texture RT.1 hashes and canonical dictionary dumps.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`.

## Artifact Hygiene

- Scratch folders or temporary projects created: none for R6 yet.
- Generated bakes/resources created: none for R6 yet.
- Active files mirrored into scratch validation: none.
- Files/folders that must be excluded from packaging: future `.codex-research` R6 outputs, probe dumps, capture PNGs, scratch bakes, and profile folders.
- Files/folders safe to delete now: none from R6.

## Known Risks and Open Issues

- Source timing can drift if the baker accidentally snapshots live values earlier than the old path.
- Abort cleanup can miss helper-internal awaits if the inventory only reads `_generate_flowmap()`.
- Constants-table rows can make signature coverage look automatic.
- Runtime ripple owner extraction can change owner conflict or material restore semantics.
- Editor validation extraction can change marker text or menu behavior.
- Parent docs are not updated yet and should not claim R6 pass until validation runs.

Relevant audit sections:

- `addons\waterways\docs\audit\waterways-code-audit-2026-06-12.md`: parent track audit context for decomposition and prior defects.

## Blockers

- R6 docs need review/check-in.
- Pre-R6 baselines have not been captured.
- Local visible/editor validation may require human assistance. Headless/parser checks are not enough for visible editor, menu, or shader behavior.

## Files To Inspect Before Editing

- `addons/waterways/docs/spec-driven/features/river-refactor/r6/plan.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/spec.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/validation.md`
- `addons/waterways/river_manager.gd`
- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/probes/README.md`

## Commands or Checks Used

No R6 validation commands have been run yet.

Result summary:

- Documentation scaffold only.

## Next Tasks

- [ ] Review/check in the R6 docs.
- [ ] Implement canonical dictionary dump probe.
- [ ] Capture pre-R6 baselines.
- [ ] Complete awaited-operation and live-dependency inventory.
- [ ] Decide whether to land R6.3/R6.4 before the bake pipeline extraction.

## Do Not Do Yet

- Do not move bake code before baseline probes and dumps exist.
- Do not pass RiverManager or `self` through the baker as a generic dependency.
- Do not add a new awaited result-application gap without staging/rollback validation.
- Do not update parent validation docs as R6 pass until the full R6 gate runs.
- Do not start R7 GPU-resident solve work in this phase.

## Notes for the Next Agent

R6 is a preservation phase. The important habit is to prove the old behavior before moving it. Capture fresh baselines first, especially dictionary dumps and intermediate source-image hashes, then keep each extraction behind narrow helper boundaries. If a validation result looks surprising, suspect stale resources and baseline setup before changing code.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so the user's normal Godot editor profile is not altered.

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
