# Tasks: River Refactor R6 - river_manager.gd Decomposition

Complete tasks in order unless `plan.md` is revised. Each task should be independently reviewable.

`plan.md` is the detailed roadmap for R6. This file is the active dashboard and checklist; do not let it drift from `spec.md`, `validation.md`, `review.md`, or the handoff.

## Current Truth

- Current status: Not started; documentation scaffold drafted on 2026-06-13.
- Current implementation slice: R6.0 documentation and baseline preparation.
- Remaining open task count: all implementation and validation tasks remain open.
- Last passing validation: none for R6. Parent track last known pass is R5 on 2026-06-13.
- Next recommended action: review and check in the R6 docs, then build/capture pre-R6 baseline probes before any implementation.
- Known deferred work: parent docs are updated only after R6 validation runs; R7 remains out of scope.

## Open Work

- [ ] Review and check in the R6 documentation gate: `spec.md`, `plan.md`, `validation.md`, `tasks.md`, `research.md`, `review.md`, and `session-handoff.md`.
- [ ] Implement the canonical metadata/signature/settings dump probe before baseline capture.
- [ ] Capture pre-R6 baselines for both demo river bakes.
- [ ] Complete R6.1A bake pipeline inventory before adding the baker shell.
- [ ] Decide whether R6.3 and R6.4 should land before the bake pipeline extraction.
- [ ] Do not start R6 implementation until the documentation gate is reviewed and baseline evidence exists.

## Setup

- [ ] Confirm the current workspace state and branch. Current assumption from `plan.md`: continue on `river-refactor` unless the user asks for a fresh phase branch.
- [ ] Read `spec.md`, `plan.md`, and `validation.md`.
- [ ] Read the parent river-refactor `roadmap.md`, `tasks.md`, `validation.md`, and latest handoff for track-wide constraints.
- [ ] Check `addons/waterways/docs/research/river-research-citations.md` before research-driven changes.
- [ ] For Godot-specific implementation work, search current official Godot documentation and API references online before patching; record sources that affect implementation in `research.md` or the shared citations index.
- [ ] Check `addons/waterways/docs/audit/waterways-code-audit-2026-06-12.md` for relevant known risks if implementation details touch audited areas.
- [ ] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [ ] If running Godot, use the exact console/windowed launch instructions from `validation.md`; console probes should use repo-local `.codex-research` user-data folders.
- [ ] Run the context challenge check: stale baselines, regenerated resources, or whole `.res` hash churn can look like R6 regressions.

## R6.0 Documentation and Baselines

- [x] Create R6 `spec.md` beside `plan.md`.
  - Validate: file exists and includes acceptance criteria plus the source timing contract.

- [x] Create R6 `validation.md` beside `plan.md`.
  - Validate: file exists and defines the canonical dump format and dynamic metadata allow-list.

- [x] Create R6 `tasks.md`, `research.md`, `review.md`, and `session-handoff.md` from the feature-folder template.
  - Validate: files exist and point future work to the true next action.

- [ ] Check in the R6 documentation gate before implementation starts.
  - Validate: git status shows the R6 docs staged/committed as intended.

- [ ] Add R6 row to the parent `river-refactor/validation.md` only after R6 validation runs.
  - Validate: parent row is not prematurely marked pass.

- [ ] Capture pre-R6 dictionary dumps for both demo river bakes:
  - `source_metadata`
  - `source_signature`
  - `bake_settings`
  - Validate: dumps use the R6 canonical format.

- [ ] Capture the full pre-R6 inspector property list.
  - Validate: full dump exists; focused Baking/generated rows may be extra only.

- [ ] Capture pre-R6 generated texture hashes with RT.1 using fresh scratch rebakes where possible.
  - Validate: both demo river bakes have recorded hashes.

- [ ] Record the full current `river_manager.gd` public method surface.
  - Validate: explicitly assert R6-sensitive methods listed in `plan.md` remain callable.

- [ ] Record the public signal surface and progress semantics.
  - Validate: `river_changed` and `progress_notified` exist and bake progress labels/order are documented.

- [ ] Add or extend a mid-bake edit probe, or record a named human-assisted case.
  - Validate: the case covers `flow_speeds` at minimum and reports the targeted stage.

## R6.1 Bake Pipeline Extraction

- [ ] R6.1A: Mark every awaited operation in `_generate_flowmap()` and awaited helpers.
  - Validate: inventory includes helper-internal waits in collision map generation, terrain contact generation, and `_await_bake_frame()`.

- [ ] R6.1A: Record success order, abort points, live dependencies, final-write dependencies, and move/stay function candidates in `validation.md`.
  - Validate: the inventory is checked in before adding the baker shell.

- [ ] R6.1A: Add the no-RiverManager-reach-back checklist to validation and implementation review.
  - Validate: helper context exposes only named operations.

- [ ] R6.1B: Add `addons/waterways/river_flowmap_baker.gd` with minimal `bake`, `abort`, `is_running`, and `cleanup` API.
  - Validate: parser/check-only passes; renderer ownership is thin and cleanup is explicit.

- [ ] R6.1B: Move filter renderer ownership from RiverManager to the baker.
  - Validate: renderer frees on success, abort, scene close, and RiverManager tree exit.

- [ ] R6.1C: Add `_run_pass(label, pass_callable)` inside the baker.
  - Validate: null texture/readback errors become abort records with old warning text preserved.

- [ ] R6.1D: Add intermediate source-image hash probe and capture pre-move hashes.
  - Validate: full raw-plus-margin source-image list is covered before helpers move.

- [ ] R6.1D: Move source image synthesis helpers without algorithm changes.
  - Validate: intermediate source-image hashes match before/after.

- [ ] R6.1E: Move filter pass sequencing behind the baker.
  - Validate: pass order, progress messages, generation behavior branches, margin/crop geometry, solve path, and support fallback diagnostics are preserved.

- [ ] R6.1E: Run RT.1 after pass sequencing before continuing.
  - Validate: generated texture hashes match for both demo river bakes.

- [ ] R6.1F: Move diagnostics and image postprocess.
  - Validate: warning text, debug contrast warnings, near-neutral flow warnings, and diagnostics outputs match.

- [ ] R6.1G: Replace `_write_bake_data()` bake-internal assumptions with RiverManager result application.
  - Validate: result application order from `validation.md` is preserved, with no new awaited gap unless rollback/staging is proven.

- [ ] R6.1H: Implement or name abort-matrix cases.
  - Validate: every counted abort point has automated coverage or a named human-assisted case.

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

- [ ] Run or inspect existing ripple material ownership probe coverage.
  - Validate: record whether it covers all R6.3 semantics.

- [ ] Add focused owner-conflict/tree-exit probe if existing probes are incomplete.
  - Validate: owner A/B conflict, owner clear, owner tree exit, RiverManager tree exit, and debug-view toggle behavior are covered.

- [ ] Add `addons/waterways/river_ripple_material_owner.gd`.
  - Validate: RiverManager public ripple methods remain wrappers.

- [ ] Move runtime ripple owner state and helper methods.
  - Validate: non-owner clear warnings, material duplication/restoration, parameter validation, and debug material application are preserved.

## R6.4 Editor Validation Harness Extraction

- [ ] Run caller audit before moving validation helpers.
  - Validate: plugin menu signal callers, probes/scripts, and marker consumers are recorded.

- [ ] Inventory live RiverManager data dependencies for `validate_data_textures()` and `validate_filter_renderer()`.
  - Validate: helper context is read-only where it should be.

- [ ] Add `addons/waterways/river_editor_validation.gd` or an equivalent editor-only path.
  - Validate: runtime paths do not depend on editor-only singleton state.

- [ ] Move editor validation implementation behind public RiverManager wrappers.
  - Validate: direct wrapper calls and menu actions still emit the same markers.

- [ ] Keep all-19-pass coverage in `filter_renderer_load_check.gd` or equivalent.
  - Validate: public menu marker is not silently expanded.

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

- 2026-06-13: Draft R6 feature-folder documents created from the template and populated from `plan.md`. Implementation and validation remain unstarted.
