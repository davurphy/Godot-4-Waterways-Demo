# Tasks: River Refactor R6 - river_manager.gd Decomposition

Complete tasks in order unless `plan.md` is revised. Each task should be independently reviewable.

`plan.md` is the detailed roadmap for R6. This file is the active dashboard and checklist; do not let it drift from `spec.md`, `validation.md`, `review.md`, or the handoff.

## Current Truth

- Current status: R6.1H abort-matrix coverage is complete, and the old R6.1A-G validation/probe set has been rerun after the abort-matrix work. The baker now observes cancellation around awaited renderer passes, RiverManager checks liveness after existing source-generation awaits, helper-internal collision/terrain waits stop safely when the river or mesh is freed, and `r6_abort_matrix_probe.gd` covers the automated abort buckets while naming the editor-only residual cases.
- Current implementation slice: R6.1H covered pre-renderer abort, scene close before renderer setup, terrain-contact helper node-free, renderer-live/Jacobi-labelled cancellation, forced invalid filter output, renderer setup failure, duplicate requests, repeated `abort()`, success cleanup, synchronous image-postprocess strategy, and synchronous RiverManager result application strategy. RiverManager still owns source-generation timing, final dictionaries, resource saving, material binding, `valid_flowmap`, bake flag clearing, completion progress, and final result application.
- Remaining open task count: constants table, final before/after diff, and final validation tasks remain open.
- Last passing validation: 2026-06-14 R6.1A-G rerun after R6.1H passed `R6_BAKER_LIFECYCLE_OK`, `R6_BAKER_RUN_PASS_OK`, `R6_R61F_WARNING_POSTPROCESS_OK`, `R6_R61G_RESULT_APPLICATION_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-generated files=2`, `R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61g-generated current=post-r6-r61ag-rerun-generated`, `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61ag-rerun-generated`, `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun files=10`, `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61g current=post-r6-r61ag-rerun`, and `git diff --check`. The source-image rerun hit only the known obstacle collision-derived variant and matched the old-code fresh replay: `R6_R61D_COLLISION_VARIANT_RECONCILED_OK ignored_collision_probe_variants=4 baseline=pre-r6-r61d-fresh-rerun current=post-r6-r61ag-rerun-source`.
- Next recommended action: start R6.2 constants-table work. Do not reopen the closed R6.1B-H bake extraction slices unless a later validation failure points back to them.
- Known deferred work: parent docs are updated only after R6 validation runs; R7 remains out of scope.

## Open Work

- [x] Review and check in the R6 documentation gate: `spec.md`, `plan.md`, `validation.md`, `tasks.md`, `research.md`, `review.md`, and `session-handoff.md`.
- [x] Implement the canonical metadata/signature/settings dump probe before baseline capture.
- [x] Capture pre-R6 canonical dictionary/API/property/saved-RT.1 baselines for both demo river bakes.
- [x] Complete R6.1A bake pipeline inventory before adding the baker shell.
- [x] Decide whether R6.3 and R6.4 should land before the bake pipeline extraction. Decision: landed R6.3 and R6.4 first; R6.1B is the next recommended slice.
- [x] Do not start bake-pipeline implementation until source-image/timing evidence and R6.1A inventory exist.
- [x] Rerun the old R6.1A-G validation/probe set after R6.1H and before R6.2.

## Setup

- [x] Confirm the current workspace state and branch. Current branch is `r6`; R6 docs were already tracked/clean before probe work.
- [x] Read `spec.md`, `plan.md`, and `validation.md`.
- [x] Read the parent river-refactor `roadmap.md`, `tasks.md`, `validation.md`, and latest handoff for track-wide constraints.
- [x] Check `addons/waterways/docs/research/river-research-citations.md` before research-driven changes.
- [x] For Godot-specific implementation work, search current official Godot documentation and API references online before patching; record sources that affect implementation in `research.md` or the shared citations index.
- [x] Check `addons/waterways/docs/audit/waterways-code-audit-2026-06-12.md` for relevant known risks if implementation details touch audited areas.
- [x] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [x] If running Godot, use the exact console/windowed launch instructions from `validation.md`; console probes should use repo-local `.codex-research` user-data folders.
- [x] Run the context challenge check: stale baselines, regenerated resources, or whole `.res` hash churn can look like R6 regressions.

## R6.0 Documentation and Baselines

- [x] Create R6 `spec.md` beside `plan.md`.
  - Validate: file exists and includes acceptance criteria plus the source timing contract.

- [x] Create R6 `validation.md` beside `plan.md`.
  - Validate: file exists and defines the canonical dump format and dynamic metadata allow-list.

- [x] Create R6 `tasks.md`, `research.md`, `review.md`, and `session-handoff.md` from the feature-folder template.
  - Validate: files exist and point future work to the true next action.

- [x] Check in the R6 documentation gate before implementation starts.
  - Validate: R6 docs were tracked and clean on branch `r6` before validation-tool edits.

- [ ] Add R6 row to the parent `river-refactor/validation.md` only after R6 validation runs.
  - Validate: parent row is not prematurely marked pass.

- [x] Capture pre-R6 dictionary dumps for both demo river bakes:
  - `source_metadata`
  - `source_signature`
  - `bake_settings`
  - Validate: `r6_baseline_dump_probe.gd` wrote canonical dumps to `.codex-research/r6-baselines/pre-r6/`; `source_metadata.bake_revision` is the only filtered key.

- [x] Capture the full pre-R6 inspector property list.
  - Validate: full Demo and obstacle Demo RiverManager property-list dumps exist under `.codex-research/r6-baselines/pre-r6/`.

- [x] Capture pre-R6 generated texture hashes with RT.1 using fresh scratch rebakes where possible.
  - Validate: saved-resource RT.1 hash logs exist for both demo river bakes under `.codex-research/r6-baselines/pre-r6/`; fresh scratch rebakes were not run in this baseline pass.

- [x] Record the full current `river_manager.gd` public method surface.
  - Validate: `r6_baseline_dump_probe.gd` wrote `river_manager_public_methods.txt` and asserted the R6-sensitive methods listed in `plan.md`.

- [x] Record the public signal surface and progress semantics.
  - Validate: signal surface baseline exists and asserts `river_changed` plus `progress_notified`; `r6_mid_bake_timing_probe.gd` recorded the Demo bake progress order through completion.

- [x] Add or extend a mid-bake edit probe, or record a named human-assisted case.
  - Validate: `r6_mid_bake_timing_probe.gd` covers `flow_speeds`, mutates at `Projecting flow 0/40 (stride 32)`, and records trap-vs-control texture hashes plus final metadata/signature reads.

## R6.1 Bake Pipeline Extraction

- [x] R6.1A: Mark every awaited operation in `_generate_flowmap()` and awaited helpers.
  - Validate: inventory includes helper-internal waits in collision map generation, terrain contact generation, and `_await_bake_frame()`.

- [x] R6.1A: Record success order, abort points, live dependencies, final-write dependencies, and move/stay function candidates in `validation.md`.
  - Validate: the inventory is checked in before adding the baker shell.

- [x] R6.1A: Add the no-RiverManager-reach-back checklist to validation and implementation review.
  - Validate: helper context exposes only named operations.

- [x] R6.1B: Add `addons/waterways/river_flowmap_baker.gd` with minimal `bake`, `abort`, `is_running`, and `cleanup` API.
  - Validate: parser/check-only passes; renderer ownership is thin and cleanup is explicit.

- [x] R6.1B: Move filter renderer ownership from RiverManager to the baker.
  - Validate: renderer frees on success, abort, scene close, and RiverManager tree exit.

- [x] R6.1C: Add `_run_pass(label, pass_callable)` inside the baker.
  - Validate: null texture/readback errors become abort records with old warning text preserved.

- [x] R6.1D: Add intermediate source-image hash probe and capture pre-move hashes.
  - Validate: full raw-plus-margin source-image list is covered before helpers move.

- [x] R6.1D: Move source image synthesis helpers without algorithm changes.
  - Validate: implementation moved blank source, margin image/texture, curve grade energy, bend bias, flow speed, and tiled flow offset noise helpers into the baker with explicit source config and no RiverManager reach-back. The full source-image gate now passes against the original pre-R6 baseline for both scenes. The prior obstacle mismatch was reconciled as collision-probe freshness/variant behavior in four untouched collision-derived rows (`collision_source`, `collision_with_margins`, `solid_occupancy_source`, `solid_occupancy_with_margins`), not a moved-helper regression.

- [x] R6.1E: Move filter pass sequencing behind the baker.
  - Validate: pass order, progress messages, generation behavior branches, margin/crop geometry, solve path, and support fallback diagnostics are preserved. RiverManager now passes explicit source textures/settings/callbacks into `river_flowmap_baker.gd` and resumes at image postprocess/result application.

- [x] R6.1E: Run RT.1 after pass sequencing before continuing.
  - Validate: fresh generated texture hashes match for both demo river bakes with `R6_R61E_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61e-generated`.

- [x] R6.1F: Move diagnostics and image postprocess.
  - Validate: warning text, debug contrast warnings, near-neutral flow warnings, diagnostics outputs, generated texture hashes, and surface/property dumps match.

- [x] R6.1G: Replace `_write_bake_data()` bake-internal assumptions with RiverManager result application.
  - Validate: result application order from `validation.md` is preserved with no new awaited gap; `R6_R61G_RESULT_APPLICATION_OK`, generated-texture diffs, and surface/property diffs passed.

- [x] R6.1H: Implement or name abort-matrix cases.
  - Validate: `r6_abort_matrix_probe.gd` reports `R6_R61H_ABORT_MATRIX_OK`; editor undo-delete and forced collision-helper null injection are explicitly named in `validation.md` instead of claimed as automated.

## R6.2 Constants Table and Dictionary Builders

- [ ] Add `addons/waterways/river_bake_constants.gd`.
  - Validate: one row per constant or generated literal that participates in metadata, signature, or settings.

- [ ] Include row types for raw values, signature-snapped floats, stable joined arrays, string literals, booleans, and values sourced from `WaterHelperMethods`.
  - Validate: rows are reviewable and dynamic values are excluded.

- [ ] Add `reason` and `review_decision` fields for non-signature rows.
  - Validate: signature coverage decisions are explicit.

- [ ] Add shadow-builder probe comparing old and table-generated dictionaries.
  - Validate: exact source-signature match, exact bake-settings match, metadata match except `bake_revision`.

- [ ] Switch live dictionary paths only after the shadow probe passes.
  - Validate: bake signature version remains 28.

## R6.3 Runtime Ripple Material Ownership Extraction

- [x] Run or inspect existing ripple material ownership probe coverage.
  - Validate: pre-move and post-hardened `ripple_material_ownership_probe.gd` runs passed with `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`.

- [x] Add focused owner-conflict/tree-exit probe if existing probes are incomplete.
  - Validate: existing probe coverage was hardened for owner A/B conflict, owner clear, owner tree exit, RiverManager tree exit, debug-view toggle behavior, and debug-material parameter ownership.

- [x] Add `addons/waterways/river_ripple_material_owner.gd`.
  - Validate: RiverManager public ripple methods remain wrappers.

- [x] Move runtime ripple owner state and helper methods.
  - Validate: non-owner clear warnings, material duplication/restoration, parameter validation, debug material application, and owner tree-exit restoration are preserved. Private RiverManager compatibility placeholders remain inert so the full property-list dump stays unchanged; live ownership state lives in `river_ripple_material_owner.gd`.

## R6.4 Editor Validation Harness Extraction

- [x] Run caller audit before moving validation helpers.
  - Validate: plugin menu signal callers, probes/scripts, and marker consumers are recorded in `validation.md`.

- [x] Inventory live RiverManager data dependencies for `validate_data_textures()` and `validate_filter_renderer()`.
  - Validate: helper context is read-only where it should be and contains only named validation inputs/callbacks.

- [x] Add `addons/waterways/river_editor_validation.gd` or an equivalent editor-only path.
  - Validate: runtime paths do not depend on editor-only singleton state.

- [x] Move editor validation implementation behind public RiverManager wrappers.
  - Validate: direct wrapper calls and menu actions still emit the same markers; `r6_editor_validation_probe.gd` reports `R6_EDITOR_VALIDATION_PROBE_OK`.

- [x] Keep all-19-pass coverage in `filter_renderer_load_check.gd` or equivalent.
  - Validate: public menu marker is not silently expanded; separate load check reports `FILTER_RENDERER_LOAD_OK shader_paths=19`.

## R6.5 Cleanup and Interface Tightening

- [ ] Remove dead private methods left behind in RiverManager after extraction.
  - Validate: public method surface diff remains empty.

- [ ] Rename only where it clarifies the new boundary.
  - Validate: no public churn and no avoidable doc drift.

- [ ] Keep comments that explain Godot-specific async/rendering quirks.
  - Validate: comments are sparse and useful.

- [ ] Update parent docs and handoffs after R6 validation runs:
  - parent `roadmap.md`
  - parent `tasks.md`
  - parent `validation.md`
  - parent `session-handoff.md`
  - `addons/waterways/docs/handoffs/handoff-latest.md`
  - Validate: parent docs point to the true next task.

- [ ] Record scratch artifact paths and cleanup status.
  - Validate: disposable `.codex-research` outputs are listed.

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge check after validation.
- [ ] For visible Godot/editor/menu/runtime checks, ask the user in chat with exact steps and expected output.
- [ ] Do not rely on `validation.md` alone for human-assisted checks.
- [ ] Record results in `validation.md` and `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of planned validation tooling.
- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Update docs for any changed decisions.
- [ ] Confirm generated data and resources remain explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

- 2026-06-13: Draft R6 feature-folder documents created from the template and populated from `plan.md`. Decomposition implementation remains unstarted; baseline validation tooling started later the same day.
