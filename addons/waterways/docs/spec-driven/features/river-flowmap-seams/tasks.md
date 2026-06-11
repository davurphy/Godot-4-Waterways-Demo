# Tasks: River Flowmap Seam Handling

Complete tasks in order unless the plan is revised. Each task should be independently reviewable.

## Current Truth

- Current status: Baseline diagnosis complete; no visible seam found.
- Current implementation slice: stopped after baseline diagnosis before patching.
- Remaining open task count: 10 active or conditional tasks
- Last passing validation: prior signature 23 probes reported `RIVER_FLOWMAP_SEAM_PROBE_OK` and `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`; not rerun in this new feature-folder pass.
- Next recommended action: do not implement a seam fix from the stale pre-signature-23 visible list. Reopen cheap checks only if a current visible seam is reproduced or the user explicitly asks for the conditional diagnostics.
- Known deferred work: Build A strip packing, Build B logical-neighbor sampler, and WaterSystem/global flow work.

## Open Work

Use this section as the canonical checklist for unfinished work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff.

- [x] Confirm current workspace state and branch safety before code changes.
- [x] Read `spec.md`, `plan.md`, `validation.md`, and `Revised plan to improve seam handling v2.md`.
- [x] Check whether demo materials override zero-default pillow uniforms, especially `pillow_forward_reach_tiles` and `pillow_contact_pull_strength`.
- [x] First-class step 1 finding: record whether any visible seam remains at all post-signature-23, because the user-observed seam list predates signature 23 and the visible problem may already be partly resolved.
- [x] Capture current visible seam state in `Demo.tscn`.
- [x] Capture current visible seam state in `Demo_obstacle_flow_test.tscn`.
- [x] For every visible seam, record join index and atlas class: same-column, row-wrap, or column X-edge band. Result: no visible seams, so there are 0 join-index records.
- [x] Compare lit water against unshaded debug views; record whether each seam appears in lit only, debug, raw baked channel, or derived/material view.
- [x] State explicitly whether any visible seam remains post-signature-23.
- [ ] Add or run a depth-1 bilinear-bleed probe, prioritizing `terrain_contact_features.a`, only if a current visible seam is reproduced or extra diagnostics are requested.
- [ ] Correlate depth-1/2 deltas with observed seam positions only if observed seam positions exist.
- [ ] Verify mesh normal/tangent continuity across step joins, or scope the discontinuity, only if a lit-only seam is reproduced.
- [ ] Confirm the dual-phase temporal reset is not visibly pulsing with `flow_foam_noise.a` phase noise active if a temporal artifact is reproduced.
- [ ] Ablate `flow_hard_boundary_slide` and record visible effect only against a reproduced visible seam.
- [ ] Ablate `wake_edge_sample_tiles` plus wake/eddy context and record visible effect only against a reproduced visible seam.
- [ ] Ablate `pillow_height_smoothing_tiles` and any live pillow offset uniforms; record visible effect only against a reproduced visible seam. Note: forward/contact pillow offsets are not live in the demo scenes.
- [ ] Ablate visible ripple/normal sampling paths named by the audit; record visible effect only against a reproduced visible seam.
- [ ] If lateral cross-column reads are implicated, implement Build C lateral tile clamp and validate it against the baseline capture.
- [ ] If any seams remain after Build C or non-shader checks, decide whether a depth-1 bake fix, normal/tangent fix, Build A spike, or Build B sampler is justified by evidence.

## Setup

- [x] Confirm the current workspace state.
- [x] Read `spec.md`, `plan.md`, and `validation.md`.
- [ ] Check `docs/research/river-research-citations.md` before research-driven changes; it is the shared works-cited list for river-reading, flow-map, shader-water, and production-reference sources, and should be updated when new cited sources affect this feature.
- [ ] For Godot-specific implementation work, search current official Godot documentation and API references online before patching; record sources that affect the implementation in `research.md` or the shared citations index.
- [ ] Check `audit/code-audit.md` for relevant known risks.
- [ ] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [x] If running Godot, use the exact console/windowed launch instructions from `validation.md` or `session-handoff.md`; console probes should use repo-local `.codex-research` user-data folders.
- [x] Run the context challenge check: if the user or agent may be misreading expected behavior, stale generated data, validation geometry, or engine limitations as a defect, raise that with evidence before patching.

## Implementation

- [x] Baseline diagnosis: material overrides, visible review, first-class "does any seam remain" finding, join-index classification, and lit-vs-debug discriminator.
  - Validate: `review.md` and `validation.md` record that no visible seam remains at all post-signature-23, so no remaining seams are classified.

- [ ] Conditional cheap check: depth-1 bilinear-bleed probe.
  - Validate: recorded per-channel depth-1/2 deltas, with `terrain_contact_features.a` called out and correlated against observed seam positions.

- [ ] Conditional cheap check: normal/tangent continuity.
  - Validate: normals/matcap debug view or CPU dump shows continuous bases, or discontinuity is confirmed and scoped to lit-only seams.

- [ ] Conditional cheap check: temporal reset.
  - Validate: visible confirmation records no uniform pulse, or temporal behavior becomes a tracked finding.

- [ ] Conditional ablation pass: toggle each runtime-gated helper group individually.
  - Validate: each helper group is marked implicated, cleared, or inconclusive with scene/view notes.

- [ ] Build C: lateral tile clamp, if implicated.
  - Validate: offset samples no longer cross interior column X edges; final capture is compared against baseline.

- [ ] Depth-1 bake fix decision, if implicated.
  - Validate: chosen fix or expected-behavior acceptance is recorded before changing bake data.

- [ ] Normal/tangent fix decision, if implicated.
  - Validate: lit-only seam disappears or the remaining lighting behavior is documented.

- [ ] Build A feasibility spike, only if evidence points to row-wrap joins or column X-edge bands after smaller checks.
  - Validate: per-tile resolution rule, nine filter shaders, `lava.gdshader`, probes, grid metadata, and source-signature impact are documented.

- [ ] Build B logical-neighbor sampler, only if a longitudinal offset path proves it needs wrap beyond continuation margins.
  - Validate: offset-routing diagnostic covers same-column, row-wrap, first/last step, and column X-edge cases.

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [x] Revisit the context challenge check after validation: if results suggest the premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in the chat message to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene, if applicable, through human-assisted validation unless the agent can genuinely use the visible editor.
- [ ] Check shader output/debug views, if applicable, through human-assisted validation.
- [ ] Check editor workflow, if applicable, through human-assisted validation.
- [ ] Check runtime sampling/API behavior, if applicable, through human-assisted validation or a proven non-crashing runtime check.
- [x] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [x] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] If validation used a scratch project, confirm active add-on scripts were mirrored there before running probes.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries.
- [ ] Update docs for any changed decisions.
- [ ] Update feature or architecture documentation for changed behavior, data flow, module boundaries, or validation procedures.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

The signature 23 bake-side work is already implemented and probe-validated according to `changelog.md` and `audit/seam-handling-audit-2026-06-11.md`. This feature-folder task list tracks the v2 follow-up work, not the completed signature 23 implementation.

The 2026-06-11 baseline visible pass created `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_visible_baseline_export.gd` and screenshot/report artifacts under `.codex-research/river-flowmap-seams-visible-baseline`. The exporter is validation tooling; the `.codex-research` output folder is disposable local evidence and should stay out of packaging.
