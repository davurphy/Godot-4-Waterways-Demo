# Session Handoff: River Refactor R6 - river_manager.gd Decomposition

## Date

2026-06-14

## Current Focus

R6.5 cleanup/interface tightening is complete after final automated R6 validation. `river_bake_constants.gd` owns the reviewable constants table, and RiverManager now passes explicit dynamic values into the table builders while still owning source-generation timing, final `RiverBakeData` write/final-read dynamic values, resource saving, material binding, `valid_flowmap`, bake flag clearing, completion progress, and synchronous final result application. The final gates prove generated-output parity, canonical dictionary/API/signal/property parity, R5/R4/filter-renderer/system-flow health, parser/check-only health, and whitespace cleanliness while keeping bake signature version 28. R6.5 removed only unreferenced private helpers and preserved public surface/property shape.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-refactor\r6\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: R6.5 cleanup/interface tightening is complete. R6.2 constants-table extraction and live dictionary switch are in place, the post-R6.1H R6.1A-G rerun remains green, final full-R6 generated-output/canonical/surface/runtime gates passed, and R6.5 private cleanup preserved the public RiverManager surface/property list.
- Highest-priority open task: before any R7 implementation, research current official Godot RenderingDevice docs and record baseline/fixture commands in `r7/validation.md`.
- Last passing validation: 2026-06-14 R6.5 focused validation passed `R6_R61F_PARSER_OK`, `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28`, `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r65 files=10`, `R6_R65_SURFACE_PROPERTY_DIFF_OK files=4 baseline=post-r6-final current=post-r6-r65 surface_line_numbers=normalized`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, and `git diff --check`; the known `Demo.tscn` invalid UID warning repeated.
- Known failing or unproven check: full-Demo human-assisted editor undo-delete was attempted on 2026-06-14, but the bake load made the editor too laggy to delete the river during the awaited phase. Treat this as an infeasible manual check on the full Demo scene, not a product-behavior failure; use a lower-cost fixture or targeted editor harness if this editor-stack variant needs future closure. Visible editor/menu review remains separate.
- Next recommended action: start R7 implementation prep by researching current official Godot RenderingDevice docs, then fill the fixed baseline/fixture commands in `r7/validation.md`.
- Packaging/artifact hygiene status: R6 baseline artifacts live under `.codex-research/r6-baselines/pre-r6/`, `.codex-research/r6-baselines/pre-r6-r61d-fresh/`, `.codex-research/r6-baselines/post-r6-r63/`, `.codex-research/r6-baselines/post-r6-r64/`, `.codex-research/r6-baselines/post-r6-r61b/`, `.codex-research/r6-baselines/post-r6-r61d/`, `.codex-research/r6-baselines/post-r6-r61d-rerun/`, `.codex-research/r6-baselines/post-r6-r61d-final/`, `.codex-research/r6-baselines/post-r6-r61e/`, `.codex-research/r6-baselines/post-r6-r61e-generated/`, `.codex-research/r6-baselines/post-r6-r61f/`, `.codex-research/r6-baselines/post-r6-r61f-generated/`, `.codex-research/r6-baselines/post-r6-r61g/`, `.codex-research/r6-baselines/post-r6-r61g-generated/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-source/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-generated/`, `.codex-research/r6-baselines/post-r6-r62-live/`, `.codex-research/r6-baselines/post-r6-r62-live-generated/`, `.codex-research/r6-baselines/post-r6-final/`, `.codex-research/r6-baselines/post-r6-r65/`, and scratch old-code generated/source hashes under `.codex-research/r6-pre-r61d-origin-fresh/.codex-research/r6-baselines/`; rerun logs live under `.codex-research/r6-r61ag-rerun-logs/`; repo-local Godot profiles live under `.codex-research/godot-user-*`. R6.5-specific `post-r6-r65` and `godot-user-r65-*` outputs are disposable after this record.
- Historical detail starts at: none.

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Before starting any implementation, validation, or documentation slice, read that task in `tasks.md`, then read the matching detailed section in `plan.md`. Treat `tasks.md` as the active checklist and `plan.md` as the implementation contract. If the two appear to disagree, pause and reconcile the docs before editing code.
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

- R6.5 cleanup is complete. Do not redo the baker shell, `_run_pass`, source-helper move, pass-sequencing move, diagnostics/image postprocess move, result-application boundary, abort-matrix coverage, constants-table live switch, final generated/canonical validation, or R6.5 private-method cleanup unless a new probe failure points back to them.
- R7 compute-first decision and docs gate are complete. Do not start R7 implementation until official RenderingDevice research and baseline/fixture setup are recorded.
- Keep `validation.md` open to canonical dictionary rules, dynamic metadata allow-list, no-RiverManager-reach-back, result-application boundary, final resource-writing sections, and the final R6 validation result.
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
- `addons/waterways/probes/r6_baseline_dump_probe.gd`: added shared R6 baseline dump probe.
- `addons/waterways/probes/README.md`: documented the R6 baseline dump probe.
- `.codex-research/r6-baselines/pre-r6/`: captured canonical dictionary dumps, public method/signal dumps, full Demo property-list dumps, and saved-resource RT.1 hash logs.
- `addons/waterways/probes/r6_source_image_hash_probe.gd`: added full raw-plus-margin R6.1D source-image hash probe.
- `addons/waterways/probes/r6_mid_bake_timing_probe.gd`: added windowed `flow_speeds` mid-bake timing/progress trap probe.
- `.codex-research/r6-baselines/pre-r6/`: captured Demo and obstacle Demo source-image hash dumps plus Demo flow-speed timing/progress trap evidence.
- `addons/waterways/river_ripple_material_owner.gd`: added runtime ripple owner helper for owner tokens, material duplication/restoration, parameter validation, and owner tree-exit restoration.
- `addons/waterways/river_manager.gd`: kept public runtime ripple methods as wrappers, moved live runtime ripple ownership state into the helper, and retained inert private compatibility placeholders so the full property-list dump stays unchanged.
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd`: hardened ownership/debug-material coverage.
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd`: updated source checks to follow the extracted owner helper and shared shader include.
- `.codex-research/r6-baselines/post-r6-r63/`: captured post-R6.3 canonical dictionary/API/signal/property dumps for comparison.
- `addons/waterways/river_editor_validation.gd`: added editor validation helper for data-texture checks and filter-renderer menu smoke checks.
- `addons/waterways/river_manager.gd`: kept `validate_data_textures()` and `validate_filter_renderer()` as public wrappers and moved editor validation implementation behind a named context dictionary.
- `addons/waterways/probes/r6_editor_validation_probe.gd`: added R6.4 menu-signal/direct-wrapper marker probe.
- `addons/waterways/probes/README.md`: documented the R6.4 editor validation probe.
- `.codex-research/r6-baselines/post-r6-r64/`: captured post-R6.4 canonical dictionary/API/signal/property dumps for comparison.
- `addons/waterways/river_flowmap_baker.gd`: added R6.1B minimal baker shell with `bake`, `abort`, `is_running`, and `cleanup`.
- `addons/waterways/river_manager.gd`: moved only filter-renderer instantiation and cleanup ownership behind the baker; source-image helpers, pass sequencing, CPU postprocess, and synchronous result application stayed in RiverManager.
- `.codex-research/r6_baker_lifecycle_check.gd`: added scratch-only lifecycle check for setup cleanup, duplicate setup, repeated abort, and RiverManager tree-exit cleanup.
- `.codex-research/r6-baselines/post-r6-r61b/`: captured post-R6.1B canonical dictionary/API/signal/property dumps for comparison.
- `addons/waterways/river_flowmap_baker.gd`: added R6.1C `_run_pass(label, pass_callable)` plus baker-owned pass-result validation/abort records that preserve the old readback warning text and cleanup behavior.
- `addons/waterways/river_manager.gd`: routed `_filter_output_is_valid()` through the baker while keeping pass sequencing and final result application in RiverManager.
- `.codex-research/r6_baker_run_pass_check.gd`: added scratch-only null-texture/readback failure check for abort record fields, warning text, renderer cleanup, and RiverManager validation-hook cleanup.
- `addons/waterways/river_flowmap_baker.gd`: moved R6.1D source-image helper implementation into the baker: margin image/texture creation, blank support/features, curve grade energy, bend bias, flow speed, and tiled flow offset noise.
- `addons/waterways/river_manager.gd`: now calls the baker source helpers through explicit `_get_flowmap_source_image_config()` while preserving RiverManager-owned source timing, filter pass sequencing, CPU postprocess, and synchronous result application.
- `addons/waterways/probes/r6_source_image_hash_probe.gd`: updated the R6.1D hash probe to exercise baker-owned source helpers directly.
- `.codex-research/r6_r61d_parser_check.gd`: added scratch-only preload/parser check for the R6.1D changed scripts.
- `.codex-research/r6-baselines/post-r6-r61d/` and `.codex-research/r6-baselines/post-r6-r61d-rerun/`: captured post-move and same-code rerun source-image hash dumps.
- `.codex-research/r6_source_image_hash_probe_pre_r61d.gd`: added scratch-only old-helper source-image replay probe for R6.1D reconciliation.
- `.codex-research/r6-pre-r61d-origin-fresh/`: created scratch `origin/r6` export with copied `.godot` import cache for fresh pre-R6.1D source-image replay.
- `.codex-research/r6-baselines/pre-r6-r61d-fresh/` and `.codex-research/r6-baselines/post-r6-r61d-final/`: captured fresh pre-R6.1D replay outputs and final current R6.1D source-image outputs.
- R6.1D source-image gate: reconciled the obstacle collision-derived mismatch as collision-probe freshness/variant evidence and recorded `R6_R61D_FULL_SOURCE_IMAGE_DIFF_OK files=2 baseline=pre-r6 current=post-r6-r61d-final`.
- `addons/waterways/river_flowmap_baker.gd`: added `run_filter_pass_sequence()` plus named renderer-pass helpers; moved full filter pass sequencing, pressure projection, support-fallback print timing, and every checked filter output behind baker-owned `_run_pass()`.
- `addons/waterways/river_manager.gd`: now prepares source textures/settings and calls the baker pass-sequencing entry point, then resumes at CPU image postprocess, final bake-data write/save, material binding, bake flag clearing, and completion progress.
- `.codex-research/r6_r61e_parser_check.gd`: added scratch-only preload/parser check for R6.1E.
- `.codex-research/r6_generated_texture_hash_probe.gd`: added scratch-only rendered generated-texture hash probe.
- `.codex-research/r6-baselines/post-r6-r61e/`, `.codex-research/r6-baselines/post-r6-r61e-generated/`, and `.codex-research/r6-pre-r61d-origin-fresh/.codex-research/r6-baselines/pre-r6-r61e-generated/`: captured R6.1E current surface/dictionary and fresh generated old-code/current output hashes.
- R6.1E generated-texture gate: recorded `R6_R61E_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61e-generated`.
- `addons/waterways/river_flowmap_baker.gd`: added R6.1F image-only diagnostics/postprocess ownership via `process_filter_pass_images()`, collision-map diagnostic helpers, warning callback routing, diagnostic print callback routing, flat support reductions, edge-band synchronization, debug-contrast warnings, flow-vector diagnostics, near-neutral flow warnings, and final `ImageTexture.create_from_image()` construction.
- `addons/waterways/river_manager.gd`: now delegates image-only diagnostics/postprocess to the baker while keeping source-generation timing, final bake-data write/save, material binding, bake flag clearing, completion progress, and result application boundaries in RiverManager.
- `addons/waterways/probes/r6_source_image_hash_probe.gd`: updated the source-image probe to call the baker collision-map stats helper directly.
- `.codex-research/r6_r61f_parser_check.gd` and `.codex-research/r6_r61f_warning_postprocess_check.gd`: added scratch-only parser/preload and warning/postprocess callback probes for R6.1F.
- `.codex-research/r6-baselines/post-r6-r61f/` and `.codex-research/r6-baselines/post-r6-r61f-generated/`: captured R6.1F current surface/dictionary and generated-output hashes.
- R6.1F diagnostics/image postprocess gate: recorded warning/postprocess parity and exact generated-output matches against both R6.1E current output and fresh old-code generated output.
- `addons/waterways/river_flowmap_baker.gd`: R6.1G result handoff now includes bake-start `generation_behavior` in the final `BakeResult` dictionary returned from `process_filter_pass_images()`.
- `addons/waterways/river_manager.gd`: added `_apply_flowmap_bake_result()` and changed `_write_bake_data()` to consume the result dictionary directly while preserving RiverManager-owned final texture fields, `RiverBakeData` finalization, save attempt, `_apply_bake_data()`, material bindings, `valid_flowmap`, bake flag clearing, final progress, save/editor-memory notice, and configuration warnings.
- `.codex-research/r6_r61g_result_application_check.gd`: added scratch-only boundary/order check for synchronous RiverManager result application and no baker-owned save/material/valid-flowmap behavior.
- `.codex-research/r6-baselines/post-r6-r61g/` and `.codex-research/r6-baselines/post-r6-r61g-generated/`: captured R6.1G current surface/dictionary and generated-output hashes.
- R6.1G result application gate: recorded exact generated-output matches against both R6.1F current output and fresh old-code generated output, plus exact surface/property/dictionary match against R6.1F.
- `addons/waterways/river_flowmap_baker.gd`: added cancellation callback retention and checks before/after awaited renderer pass callables for R6.1H.
- `addons/waterways/river_manager.gd`: added liveness checks after existing pre-renderer awaits, passed cancellation into baker pass sequencing, and added a controlled terrain-contact source null/empty failure guard for R6.1H.
- `addons/waterways/water_helper_methods.gd`: hardened collision/terrain helper-internal await loops so freed or queued river/mesh references stop safely.
- `addons/waterways/probes/r6_abort_matrix_probe.gd`: added R6.1H abort-matrix probe for pre-renderer abort, scene close, terrain helper node-free, renderer-live/Jacobi-labelled cancellation, invalid filter output, renderer setup failure, duplicate requests, repeated abort, success cleanup, and synchronous postprocess/result-application strategies.
- R6.1H abort-matrix gate: recorded `R6_R61H_ABORT_MATRIX_OK` plus follow-up `R6_BAKER_LIFECYCLE_OK`, `R6_BAKER_RUN_PASS_OK`, and `R6_R61G_RESULT_APPLICATION_OK`.
- R6.1A-G validation rerun after R6.1H: reran the old parser/check-only, baker lifecycle, run-pass, source-image, generated-texture, warning/postprocess, result-application, baseline/surface, R5 preservation, and `git diff --check` gates. Fresh outputs live under `.codex-research/r6-baselines/post-r6-r61ag-rerun/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-source/`, and `.codex-research/r6-baselines/post-r6-r61ag-rerun-generated/`; logs live under `.codex-research/r6-r61ag-rerun-logs/`. The source-image rerun repeated only the known four obstacle collision-derived rows and matched the old-code fresh replay exactly.
- `addons/waterways/river_bake_constants.gd`: added R6.2 shadow constants table with 109 metadata/signature/settings rows, required row-type validation, explicit dynamic-key lists, and non-signature `reason`/`review_decision` fields.
- `addons/waterways/probes/r6_constants_shadow_probe.gd`: added R6.2 shadow-builder comparison for saved Demo/obstacle metadata, signature, and settings dictionaries plus live scene source signatures.
- R6.2 shadow constants gate: recorded `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28` plus final `git diff --check`.
- `addons/waterways/river_manager.gd`: switched only live metadata/signature/settings constant dictionary rows to `RiverBakeConstants`; dynamic final-read values remain explicit in RiverManager.
- R6.2 live constants gate: recorded `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28`, `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r62-live files=10`, `R6_R62_LIVE_CANONICAL_DICTIONARY_DIFF_OK files=6 baseline=post-r6-r61ag-rerun current=post-r6-r62-live metadata_filter=bake_revision`, and final `git diff --check`.
- Final R6 generated-texture gate: recorded `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r62-live-generated files=2`, `R6_FINAL_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61ag-rerun-generated current=post-r6-r62-live-generated`, and `R6_FINAL_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r62-live-generated`.
- Final R6 canonical/surface gate: recorded `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-final files=10` and `R6_FINAL_CANONICAL_SURFACE_DIFF_OK files=10 baseline=pre-r6 current=post-r6-final surface_line_numbers=normalized metadata_filter=bake_revision`.
- Final R6 regression gates: check-only parser passed for `river_manager.gd`, `river_flowmap_baker.gd`, `river_bake_constants.gd`, and `r6_constants_shadow_probe.gd`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, `FILTER_RENDERER_LOAD_OK shader_paths=19`, `SYSTEM_FLOW_PROJECTED_GATE_OK`, and final `git diff --check` passed.
- `addons/waterways/river_manager.gd`: R6.5 removed dead private `_cleanup_flowmap_baker()` and `_filter_output_is_valid()` after active-reference audit; the serialized `_flowmap_bake_renderer` slot remains for property-list compatibility, with a corrected comment naming `RiverFlowmapBaker` as the live renderer owner.
- R6.5 cleanup gate: recorded `R6_R61F_PARSER_OK`, `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28`, `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r65 files=10`, `R6_R65_SURFACE_PROPERTY_DIFF_OK files=4 baseline=post-r6-final current=post-r6-r65 surface_line_numbers=normalized`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, and `git diff --check`.

## Current Changes Summary

- R6 feature-folder companion documents exist beside the pre-existing `plan.md`. Pre-move baseline validation tooling and R6.1A inventory are recorded; R6.3, R6.4, R6.1B, R6.1C, R6.1D source-helper, R6.1E pass-sequencing, R6.1F diagnostics/image postprocess, R6.1G result application, R6.1H abort-matrix implementation/validation, R6.2 constants-table extraction/live switch, and R6.5 dead-private-method/comment cleanup are in place. The post-R6.1H R6.1A-G rerun passed, final automated R6 validation passed, and parent docs/handoffs point to R7 RenderingDevice research plus baseline/fixture setup.

## Historical Change Log

Empty.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Preserve mixed source timing by default. | R6 is behavior-preserving; freeze-at-start would be a behavior change. | `flow_speeds` timing trap is now the minimum proof case for future comparisons. |
| Keep RiverManager as the final result applicator. | RiverManager owns public node state, material binding, resource saving, and signals. | Baker returns `BakeResult`; RiverManager applies it. |
| Treat `bake_revision` as the only allowed dynamic metadata diff. | It is time-derived through `_make_bake_revision()`. | Any additional ignored metadata key must be a review finding. |
| Land R6.3 before bake-pipeline extraction. | It is a smaller review slice with focused probe coverage and no bake algorithm movement. | Done. |
| Keep inert private RiverManager runtime ripple placeholders after extraction. | The full property-list dump includes private script variables. | Live runtime ripple owner state lives in `river_ripple_material_owner.gd`; placeholders are compatibility only. |
| Land R6.4 before bake-pipeline extraction. | It is a smaller review slice with focused caller/marker coverage and no bake algorithm movement. | Done; R6.1B, R6.1C, and R6.1D are now complete. |
| Keep R6.1B as a thin lifecycle slice. | It proves the baker boundary and renderer cleanup before moving pass sequencing. | R6.1C starts with `_run_pass`; source-image helpers remain in RiverManager. |
| Keep R6.1C as a helper/proof slice. | It proves abort-record text and cleanup before larger pass movement. | Source-image helpers and full pass sequencing remain in RiverManager for the next slice. |
| Treat the R6.1D obstacle collision mismatch as collision-probe freshness/variant evidence. | A scratch `origin/r6` replay produced the alternate four collision-derived rows with old helpers, and the final current R6.1D dump matches the original pre-R6 full source-image baseline. | Do not turn this into a broad ignore rule; R6.1E still needs RT.1/generated-output validation. |
| Keep R6.1F as an image-only diagnostics/postprocess slice with warning and diagnostic callbacks. | It proves warning text, CPU image edits, diagnostic output, and generated-output parity while preserving RiverManager's final result application boundary. | Start R6.1G next; do not fold final write/save/material binding into R6.1F. |
| Keep R6.1G result application synchronous and RiverManager-owned. | It proves the `BakeResult` handoff without adding an awaited gap or moving save/material/valid-flowmap behavior into the baker. | Done; R6.1H kept this as the result-application interruption strategy. |
| Keep R6.1H abort coverage focused on cancellation/liveness and named residuals. | The automated probe covers lifecycle buckets without moving algorithms; editor undo-delete and forced collision-helper null injection require editor stack or future narrow injection seams. | Done; R6.2 shadow constants-table work has started and passed. |
| Start R6.2 in shadow mode only. | It exposes signature-coverage decisions and proves old/table dictionary parity before changing live output. | Done; superseded by the live dictionary switch validation. |

## Current State

Implementation status:

- R6.3 runtime ripple material ownership extraction, R6.4 editor validation extraction, R6.1B baker shell/filter-renderer lifecycle extraction, R6.1C run-pass helper extraction, R6.1D source-helper implementation/validation, R6.1E pass-sequencing implementation/validation, R6.1F diagnostics/image postprocess implementation/validation, R6.1G result assembly/application implementation/validation, R6.1H abort-matrix implementation/validation, and R6.2 constants-table extraction/live switch complete. The old R6.1A-G validation/probe set has been rerun after R6.1H.

Spec/plan status:

- Research: Drafted and updated with R6.3, R6.4, R6.1C, R6.1D, R6.1E, R6.1F, R6.1G, R6.1H, and R6.2 Godot API sources.
- Spec: Drafted and updated for R6.1H status plus the post-R6.1H R6.1A-G rerun.
- Plan: Existing detailed R6 plan remains the implementation roadmap; R6.3, R6.4, R6.1B-H, and R6.2 checklists marked complete where applicable.
- Tasks: Updated for R6.2 live switch completion.
- Validation: Pre-move baseline runs, R6.1A inventory, R6.3 validation, R6.4 validation, R6.1B validation, R6.1C focused validation, R6.1D focused/final validation, R6.1E pass-sequencing/generated-texture validation, R6.1F diagnostics/image postprocess validation, R6.1G result application validation, R6.1H abort-matrix validation, post-R6.1H R6.1A-G rerun, and R6.2 live constants validation recorded.
- Review: Pre-move gate, R6.3, R6.4, R6.1B, R6.1C, R6.1D source-image validation, R6.1E pass-sequencing validation, R6.1F diagnostics/image postprocess validation, R6.1G result application validation, R6.1H abort-matrix validation, R6.1A-G rerun, and R6.2 live constants validation reviewed.

Validation status:

- Automated: 2026-06-13 baseline pass (`r6_baseline_dump_probe.gd`; `r6_source_image_hash_probe.gd`; `r6_mid_bake_timing_probe.gd`; `bake_hash_probe.gd` on both saved demo river bakes), plus R6.3 pass, R6.4 pass, R6.1B pass, R6.1C pass, R6.1D focused/final validation, R6.1E pass-sequencing validation (`R6_R61E_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61e-generated`), R6.1F diagnostics/image postprocess validation (`R6_R61F_WARNING_POSTPROCESS_OK`, `R6_R61F_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61f-generated`), R6.1G result application validation (`R6_R61G_RESULT_APPLICATION_OK`, `R6_R61G_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61g-generated`), R6.1H abort-matrix validation (`R6_R61H_ABORT_MATRIX_OK`), and post-R6.1H R6.1A-G rerun (`R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK`, `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK`, `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK`, `R6_R61F_WARNING_POSTPROCESS_OK`, `R6_R61G_RESULT_APPLICATION_OK`, `R6_BAKER_LIFECYCLE_OK`, `R6_BAKER_RUN_PASS_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`).
- Human-assisted: full-Demo editor undo-delete attempted on 2026-06-14, but bake load made the editor too laggy to perform the delete; treat as infeasible on the full scene, not as a behavior failure.
- Shader: no R6 shader change intended.
- Editor: R6.4 rendered console marker/menu-signal probe passed; full-Demo editor undo-delete was attempted but infeasible due bake load; human-visible editor click review remains unrun.
- Visual: unrun.
- Runtime: R6.4 reran R4 runtime robustness and R5 behavior preservation; R6.1H abort checks are automated, with the full-Demo editor undo-delete variant recorded as infeasible and future closure requiring a lower-cost fixture or targeted harness.
- Performance: unrun.
- Manual: docs scaffolded from plan; R6 docs were tracked/clean before validation-tool edits; R6.3 and R6.4 reviewed against their plan sections.

## Important Context

- R6 docs, source-image hashes, timing/progress evidence, R6.1A inventory, R6.3 runtime validation, R6.4 editor validation, R6.1B baker lifecycle validation, R6.1C run-pass validation, R6.1D source-helper validation, R6.1E pass-sequencing validation, R6.1F diagnostics/image postprocess validation, R6.1G result application validation, R6.1H abort-matrix validation, post-R6.1H R6.1A-G rerun evidence, and R6.2 shadow constants validation exist; bake-code movement can continue with the R6.2 live dictionary switch after reading the plan section.
- `plan.md` forbids passing a general RiverManager reference into the baker. Named dependencies/callbacks only.
- The default source-timing contract preserves current mixed timing. Do not freeze everything at bake start unless the spec and validation are deliberately updated.
- Whole-resource `.res` hashes are not the gate; use per-texture RT.1 hashes and canonical dictionary dumps.
- RiverManager remains the synchronous result applicator through R6.1H. Do not add awaited result application unless a future contract explicitly accounts for staging/rollback validation.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`.

## Artifact Hygiene

- Scratch folders or temporary projects created: `.codex-research/r6-baselines/pre-r6/`, `.codex-research/r6-baselines/pre-r6-r61d-fresh/`, `.codex-research/r6-baselines/post-r6-r63/`, `.codex-research/r6-baselines/post-r6-r64/`, `.codex-research/r6-baselines/post-r6-r61b/`, `.codex-research/r6-baselines/post-r6-r61d/`, `.codex-research/r6-baselines/post-r6-r61d-rerun/`, `.codex-research/r6-baselines/post-r6-r61d-final/`, `.codex-research/r6-baselines/post-r6-r61e/`, `.codex-research/r6-baselines/post-r6-r61e-generated/`, `.codex-research/r6-baselines/post-r6-r61f/`, `.codex-research/r6-baselines/post-r6-r61f-generated/`, `.codex-research/r6-baselines/post-r6-r61g/`, `.codex-research/r6-baselines/post-r6-r61g-generated/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-source/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-generated/`, `.codex-research/r6-r61ag-rerun-logs/`, `.codex-research/r6-pre-r61d-origin-fresh/`, `.codex-research/filter_renderer_load_check.gd`, `.codex-research/r6_baker_lifecycle_check.gd`, `.codex-research/r6_baker_run_pass_check.gd`, `.codex-research/r6_r61d_parser_check.gd`, `.codex-research/r6_r61e_parser_check.gd`, `.codex-research/r6_r61f_parser_check.gd`, `.codex-research/r6_r61f_warning_postprocess_check.gd`, `.codex-research/r6_r61g_result_application_check.gd`, `.codex-research/r6_source_image_hash_probe_pre_r61d.gd`, and `.codex-research/godot-user-*` R6 run profiles.
- Generated bakes/resources created: no generated bake resources were saved; only text baseline artifacts were written.
- Active files mirrored into scratch validation: none.
- Files/folders that must be excluded from packaging: `.codex-research` R6 outputs, probe dumps, capture PNGs, scratch bakes, and profile folders.
- Files/folders safe to delete now: none from R6.

## Known Risks and Open Issues

- Source timing can drift if the baker accidentally snapshots live values earlier than the old path; the `flow_speeds` trap is now the minimum comparison case. R6.1D passes curve and a point-in-time `flow_speeds` copy into source helpers at the old source-helper execution point, not at bake start.
- Collision-derived source-image probe rows can vary across fresh obstacle collision runs. R6.1D is closed because the final current run matches the original pre-R6 full source-image baseline and the alternate rows were reproduced by old `origin/r6` helpers; do not treat this as permission to ignore generated-output diffs in later slices.
- Abort cleanup now has R6.1H coverage for helper-internal terrain awaits and renderer/Jacobi-labelled awaits. The full-Demo editor undo-delete manual gate was attempted but infeasible due bake load; do not ask for the same full-scene check again.
- Constants-table rows can make signature coverage look automatic; R6.2 shadow rows now include `reason` and `review_decision` fields for non-signature rows, but new rows still need manual review.
- Future editor validation changes can still drift marker text or menu behavior; R6.4 current extraction is validated.
- Parent docs and latest handoff are updated to point at final R6 automated validation, R6.5 cleanup validation, and R7 decision/docs next work.

Relevant audit sections:

- `addons\waterways\docs\audit\waterways-code-audit-2026-06-12.md`: parent track audit context for decomposition and prior defects.

## Blockers

- No automated R6 validation blocker remains after the final generated-output, canonical/surface, R5, R4, filter-renderer, system-flow, parser/check-only, and whitespace gates.
- Local visible/editor validation may require human assistance. Headless/rendered-console/parser checks are not enough for editor undo-delete or a human-visible menu/viewport review, but the full-Demo undo-delete check is now known to be impractical on the user's machine.

## Files To Inspect Before Editing

- `addons/waterways/docs/spec-driven/features/river-refactor/r6/plan.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/spec.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/validation.md`
- `addons/waterways/river_manager.gd`
- `addons/waterways/river_flowmap_baker.gd`
- `addons/waterways/river_editor_validation.gd`
- `addons/waterways/river_ripple_material_owner.gd`
- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/probes/README.md`

## Commands or Checks Used

R6 baseline commands run with repo-local `APPDATA`/`LOCALAPPDATA` under `.codex-research/godot-user-r6/`:

- `r6_baseline_dump_probe.gd` headless: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/pre-r6 files=10`.
- `r6_source_image_hash_probe.gd` headless: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6 files=2`.
- `r6_mid_bake_timing_probe.gd` windowed console: `R6_MID_BAKE_TIMING_OK out=res://.codex-research/r6-baselines/pre-r6 files=1`.
- `bake_hash_probe.gd` headless on `res://waterways_bakes/Demo/Water_River.river_bake.res`: `BAKE_HASH_PROBE_OK`.
- `bake_hash_probe.gd` headless on `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`: `BAKE_HASH_PROBE_OK`.
- Parser/check-only on changed R6.3 scripts: pass.
- `ripple_material_ownership_probe.gd`: `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`.
- `ripple_field_emitter_probe.gd`: `RIPPLE_FIELD_EMITTER_PROBE_OK`.
- `ripple_debug_parity_probe.gd`: `RIPPLE_DEBUG_PARITY_PROBE_OK`.
- `r4_runtime_robustness_probe.gd`: `R4_RUNTIME_ROBUSTNESS_PROBE_OK`.
- `r6_baseline_dump_probe.gd` post-R6.3: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r63 files=10`.
- Pre/post R6.3 baseline comparison: exact canonical dictionary and property-list match; public method/signal dumps match after normalizing line-number-only drift with `R6_R63_SURFACE_NORMALIZED_DIFF_OK files=2`.
- Parser/check-only on changed R6.4 scripts: pass.
- `r6_editor_validation_probe.gd` windowed console: `R6_EDITOR_VALIDATION_MENU_SIGNALS_OK data=1 filter=1`, unchanged `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` marker prefixes, and `R6_EDITOR_VALIDATION_PROBE_OK`.
- `.codex-research/filter_renderer_load_check.gd` headless: `FILTER_RENDERER_LOAD_OK shader_paths=19`.
- `r6_baseline_dump_probe.gd` post-R6.4: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r64 files=10`.
- Post-R6.3/post-R6.4 baseline comparison: exact canonical dictionary and property-list match; public method/signal dumps match after normalizing line-number-only drift with `R6_R64_SURFACE_PROPERTY_DIFF_OK files=10`.
- `r4_runtime_robustness_probe.gd`: `R4_RUNTIME_ROBUSTNESS_PROBE_OK`.
- `r5_behavior_preservation_probe.gd`: `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- Parser/check-only on R6.1B changed scripts: `river_flowmap_baker.gd` and `river_manager.gd` pass.
- `.codex-research/r6_baker_lifecycle_check.gd` headless: `R6_BAKER_LIFECYCLE_OK`.
- `r6_baseline_dump_probe.gd` post-R6.1B: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61b files=10`.
- Post-R6.4/post-R6.1B baseline comparison: exact canonical dictionary and property-list match; public method/signal dumps match after normalizing line-number-only drift with `R6_R61B_SURFACE_PROPERTY_DIFF_OK files=10`.
- `r5_behavior_preservation_probe.gd`: `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- Parser/check-only on R6.1C changed scripts and scratch probe: `R6_R61C_PARSER_OK`.
- `.codex-research/r6_baker_run_pass_check.gd` headless: `R6_BAKER_RUN_PASS_OK` with expected null-texture/readback warning text and renderer cleanup checks.
- R6.1C reruns: `.codex-research/r6_baker_lifecycle_check.gd` headless `R6_BAKER_LIFECYCLE_OK`; `r5_behavior_preservation_probe.gd` `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- Parser/preload on R6.1D changed scripts and scratch probe: `.codex-research/r6_r61d_parser_check.gd` headless `R6_R61D_PARSER_OK`.
- `r6_source_image_hash_probe.gd` headless after R6.1D source-helper move: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d files=2`.
- `r6_source_image_hash_probe.gd` same-code rerun: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d-rerun files=2`.
- Earlier pre/post source-image diff before reconciliation: Demo exact match `R6_R61D_SOURCE_IMAGE_DIFF_OK demo`; obstacle full diff had collision-derived row mismatch only, superseded by final full source-image diff below.
- Same-code source-image rerun diffs: `R6_R61D_SOURCE_IMAGE_RERUN_DIFF_OK demo`; `R6_R61D_SOURCE_IMAGE_RERUN_DIFF_OK demo_obstacle_flow_test`.
- Moved-helper row comparison excluding only the four untouched collision-derived rows: `R6_R61D_MOVED_SOURCE_HELPERS_DIFF_OK files=2 ignored_collision_derived_rows=4`.
- `.codex-research/r6_baker_lifecycle_check.gd` headless after R6.1D: `R6_BAKER_LIFECYCLE_OK`.
- `r5_behavior_preservation_probe.gd`: `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- Scratch `origin/r6` old-helper source-image replay: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6-r61d-fresh-rerun files=2`.
- Current R6.1D final source-image rerun: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d-final files=2`.
- R6.1D collision baseline reconciliation: `R6_R61D_COLLISION_BASELINE_RECONCILED ignored_collision_probe_variants=4`.
- Final R6.1D full source-image diff: `R6_R61D_FULL_SOURCE_IMAGE_DIFF_OK files=2 baseline=pre-r6 current=post-r6-r61d-final`.
- Parser/preload on R6.1E changed scripts and scratch probe: `.codex-research/r6_r61e_parser_check.gd` headless `R6_R61E_PARSER_OK`.
- `.codex-research/r6_baker_lifecycle_check.gd` headless after R6.1E: `R6_BAKER_LIFECYCLE_OK`.
- `.codex-research/r6_baker_run_pass_check.gd` headless after R6.1E: `R6_BAKER_RUN_PASS_OK` with expected null-texture/readback warning text.
- `r5_behavior_preservation_probe.gd` after R6.1E: `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- Current R6.1E generated-texture run: `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61e-generated files=2`.
- Scratch old-code generated-texture run: `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6-r61e-generated files=2` in `.codex-research/r6-pre-r61d-origin-fresh/`.
- R6.1E generated-texture diff: `R6_R61E_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61e-generated`.
- R6.1E baseline dump: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61e files=10`.
- R6.1E surface/property/dictionary comparison: `R6_R61E_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61b current=post-r6-r61e`.
- Final R6.1E `git diff --check`: pass.
- Parser/preload on R6.1F changed scripts and scratch probe: `.codex-research/r6_r61f_parser_check.gd` headless `R6_R61F_PARSER_OK`.
- Current R6.1F generated-texture run: `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61f-generated files=2`.
- R6.1F generated-texture diff against R6.1E current output: `R6_R61F_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61e-generated current=post-r6-r61f-generated`.
- R6.1F generated-texture diff against fresh old-code output: `R6_R61F_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61f-generated`.
- `.codex-research/r6_r61f_warning_postprocess_check.gd` headless: `R6_R61F_WARNING_POSTPROCESS_OK`.
- `.codex-research/r6_baker_lifecycle_check.gd` headless after R6.1F: `R6_BAKER_LIFECYCLE_OK`.
- `.codex-research/r6_baker_run_pass_check.gd` headless after R6.1F: `R6_BAKER_RUN_PASS_OK` with expected null-texture/readback warning text.
- `r5_behavior_preservation_probe.gd` after R6.1F: `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- R6.1F baseline dump: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61f files=10`.
- R6.1F surface/property/dictionary comparison: `R6_R61F_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61e current=post-r6-r61f`.
- Final R6.1F `git diff --check`: pass.
- R6.1G result application boundary check: `.codex-research/r6_r61g_result_application_check.gd` headless `R6_R61G_RESULT_APPLICATION_OK`.
- Current R6.1G generated-texture run: `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61g-generated files=2`.
- R6.1G generated-texture diff against R6.1F current output: `R6_R61G_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61f-generated current=post-r6-r61g-generated`.
- R6.1G generated-texture diff against fresh old-code output: `R6_R61G_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61g-generated`.
- `.codex-research/r6_r61f_warning_postprocess_check.gd` headless after R6.1G: `R6_R61F_WARNING_POSTPROCESS_OK`.
- `.codex-research/r6_baker_lifecycle_check.gd` headless after R6.1G: `R6_BAKER_LIFECYCLE_OK`.
- `.codex-research/r6_baker_run_pass_check.gd` headless after R6.1G: `R6_BAKER_RUN_PASS_OK` with expected null-texture/readback warning text.
- `r5_behavior_preservation_probe.gd` after R6.1G: `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- R6.1G baseline dump: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61g files=10`.
- R6.1G surface/property/dictionary comparison: `R6_R61G_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61f current=post-r6-r61g`.
- Final R6.1G `git diff --check`: pass.
- `r6_abort_matrix_probe.gd` headless after R6.1H: `R6_R61H_ABORT_MATRIX_OK` with expected duplicate-request, missing-renderer-scene, forced invalid-filter-output, and known Demo invalid-UID warnings; Godot script exit reported non-fatal engine cleanup noise after Demo-scene lifecycle tests while returning success.
- `r6_abort_matrix_probe.gd` windowed console after R6.1H: `R6_R61H_ABORT_MATRIX_OK`.
- `.codex-research/r6_baker_lifecycle_check.gd` headless after R6.1H: `R6_BAKER_LIFECYCLE_OK`.
- `.codex-research/r6_baker_run_pass_check.gd` headless after R6.1H: `R6_BAKER_RUN_PASS_OK` with expected null-texture/readback warning text.
- `.codex-research/r6_r61g_result_application_check.gd` headless after R6.1H: `R6_R61G_RESULT_APPLICATION_OK`.
- `r5_behavior_preservation_probe.gd` headless after R6.1H: `R5_BEHAVIOR_PRESERVATION_PROBE_OK` with expected width-padding warnings.
- Final R6.1H `git diff --check`: pass.
- Post-R6.1H R6.1A-G rerun with repo-local profile `.codex-research/godot-user-r61ag-rerun/` and logs under `.codex-research/r6-r61ag-rerun-logs/`: parser/check-only reruns, `.codex-research/r6_baker_lifecycle_check.gd`, `.codex-research/r6_baker_run_pass_check.gd`, `r5_behavior_preservation_probe.gd`, `r6_source_image_hash_probe.gd`, `.codex-research/r6_generated_texture_hash_probe.gd`, `.codex-research/r6_r61f_warning_postprocess_check.gd`, `.codex-research/r6_r61g_result_application_check.gd`, `r6_baseline_dump_probe.gd`, generated-texture diffs, surface/property diffs, and `git diff --check` passed.
- R6.1A-G rerun source-image reconciliation: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-source files=2`; `R6_R61D_COLLISION_VARIANT_RECONCILED_OK ignored_collision_probe_variants=4 baseline=pre-r6-r61d-fresh-rerun current=post-r6-r61ag-rerun-source`.
- R6.1A-G rerun generated/surface markers: `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-generated files=2`; `R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61g-generated current=post-r6-r61ag-rerun-generated`; `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61ag-rerun-generated`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun files=10`; `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61g current=post-r6-r61ag-rerun`.

Result summary:

- Canonical dictionary/API/signal/property baselines, saved-resource RT.1 hashes, source-image hashes, flow-speed timing/progress trap evidence, and R6.1A inventory captured before bake-code moves. R6.3 runtime ripple extraction, R6.4 editor validation extraction, R6.1B baker lifecycle extraction, R6.1C run-pass helper extraction, R6.1D source-helper implementation, R6.1E pass-sequencing implementation, R6.1F diagnostics/image postprocess implementation, R6.1G result application implementation, R6.1H abort-matrix coverage, and R6.2 shadow/live constants-table extraction passed validation. The post-R6.1H R6.1A-G rerun passed, including generated-output and surface/property parity against post-R6.1G; the only source-image caveat was the known obstacle collision-derived variant matching old code. Final R6 generated-output, canonical dictionary/API/signal/property, R5, R4, filter-renderer, system-flow, parser/check-only, and whitespace gates passed. Non-fatal `Demo.tscn` invalid UID warning recorded in `validation.md`.

## Next Tasks

- [x] Review/check in the R6 docs.
- [x] Implement canonical dictionary dump probe.
- [x] Capture pre-R6 canonical dictionary/API/property/saved-RT.1 baselines.
- [x] Capture source-image hashes and mid-bake timing/progress evidence.
- [x] Complete awaited-operation and live-dependency inventory.
- [x] Decide whether to land R6.3/R6.4 before the bake pipeline extraction.
- [x] Land and validate R6.3 runtime ripple material ownership extraction.
- [x] Land and validate R6.4 editor validation extraction.
- [x] Start R6.1B baker shell.
- [x] Start R6.1C run-pass helper.
- [x] Start R6.1D source-image helper move.
- [x] Reconcile R6.1D obstacle collision-derived source-image baseline caveat before R6.1E.
- [x] Start R6.1E pass sequencing.
- [x] Start R6.1F diagnostics/image postprocess.
- [x] Start R6.1G result assembly/application.
- [x] Start R6.1H abort-matrix coverage.
- [x] Start R6.2 constants-table extraction in shadow mode.
- [x] Switch live metadata/signature/settings generation after reviewing the R6.2 shadow table.
- [x] Run final full-R6 generated-output, canonical dictionary/API/signal/property, R5, R4, filter-renderer, system-flow, parser/check-only, and whitespace gates.
- [x] Complete R6.5 dead-private-method/comment cleanup/interface tightening.
- [x] Record the R7 compute-vs-SubViewport decision and create R7 `spec.md`, `plan.md`, and `validation.md`.
- [ ] Research official Godot RenderingDevice docs and fill R7 baseline/fixture commands before implementation.

## Do Not Do Yet

- Do not redo source-image helper movement; keep the pre-move source-image hash gate and final R6.1D reconciliation as the comparison contract.
- Do not redo or broaden full pass sequencing; R6.1E is closed with RT.1 and R6.1F preserved that output through the image postprocess move.
- Do not redo diagnostics/image postprocess; R6.1F is closed with warning/postprocess and generated-texture validation.
- Do not redo result application; R6.1G is closed with result-boundary, generated-texture, and surface/property validation.
- Do not redo abort-matrix coverage; R6.1H is closed with `R6_R61H_ABORT_MATRIX_OK` plus named editor/source-helper residuals.
- Do not move bake code without keeping the recorded source-image hashes, timing/progress evidence, and R6.1A inventory as the comparison gate.
- Do not pass RiverManager or `self` through the baker as a generic dependency.
- Do not add a new awaited result-application gap without staging/rollback validation.
- Do not update parent validation docs casually; final R6 automated validation, R6.5 cleanup validation, and R7 docs-gate validation have run, so parent updates should point at R7 implementation prep.
- Do not start R7 GPU-resident solve implementation until official RenderingDevice research and baseline/fixture setup are recorded.

## Notes for the Next Agent

R6 is a preservation phase. The important habit is to prove the old behavior before moving it. The canonical dictionary/API/property/saved-hash baseline, source-image baseline, timing/progress trap, R6.1A inventory, R6.3 runtime validation, R6.4 editor validation, R6.1D final source-image reconciliation, R6.1E generated-texture RT.1 comparison, R6.1F warning/postprocess/generated-output comparison, R6.1G result-application/generated-output comparison, R6.1H abort-matrix coverage, post-R6.1H R6.1A-G rerun evidence, R6.2 live constants-table validation, and final R6 automated validation exist now; keep each extraction behind narrow helper boundaries. If a validation result looks surprising, suspect stale resources and baseline setup before changing code.

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
