# Tasks: River Refactor R7 - Compute-First Bake Performance

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

## Current Truth

- Current status: In progress; validation-only R7 gates, the non-replacing production compute backend skeleton, the isolated pressure-Jacobi solve/filter step, the production-shaped pressure-Jacobi stack, the non-replacing divergence/gradient/tangency diagnostic around that stack, the legacy pressure-feedback correctness audit, the probe-only `FRAGCOORD` sampler diagnostic, the automated canonical-compute acceptance gate, the low-cost canonical artifact visual review, non-replacing cleanup/heartbeat/non-neutral flow-speed coverage, explicit backend selection plus guarded abort/free/scene-close cleanup coverage, low-cost representative material/debug visual coverage, the guarded `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` promotion gate, generated-output replacement staging, and production replacement validation are recorded behind the baker as non-replacing evidence.
- Current implementation slice: `river_flowmap_compute_backend.gd`, the baker-owned non-replacing compute proof entry points, explicit `flowmap_backend_mode` selection plus the `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` guard, generated-output staging report, production replacement validation report, source signature v29 policy, and the gated `canonical_compute_replacing` production branch in `river_flowmap_baker.gd`, `river_bake_constants.gd`, `river_manager.gd`, `r7_compute_backend_skeleton_probe.gd`, `r7_compute_solve_filter_step_probe.gd`, `r7_compute_solve_filter_stack_probe.gd`, `r7_compute_cleanup_responsiveness_probe.gd`, `r7_compute_selection_abort_probe.gd`, `r7_compute_representative_visual_probe.gd`, `r7_compute_generated_output_replacement_staging_probe.gd`, and `r7_compute_production_replacement_validation_probe.gd` are implemented and validated. The production-validation probe now also smokes the direct baker replacement path without writing RiverManager output.
- Remaining open task count: final promotion/default-selection policy and broader replacement rollout remain open. Source signature policy and replacement code enablement are accepted. Legacy `R7_TOLERANCE_V1` parity remains a diagnostic/reporting gate and is not relaxed.
- Last passing validation: refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`, refreshed `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`, refreshed `R7_COMPUTE_SELECTION_ABORT_OK`, refreshed `R7_R6_SURFACE_PROPERTY_DIFF_OK`, `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`, `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`, `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`, `R7_COMPUTE_SOLVE_FILTER_STACK_OK`, `R7_COMPUTE_BACKEND_SKELETON_OK`, `R7_COMPUTE_SOLVE_FILTER_STEP_OK`, `R7_RENDERING_DEVICE_SYNC_OK`, `R7_TOLERANCE_SELF_COMPARE_OK`, and `R7_TEXTURE_FORMAT_ROUNDTRIP_OK` are recorded; the latest production validation report is `.codex-research/r7-baselines/compute-production-replacement-validation/r7_compute_production_replacement_validation.txt`. `R7_LEGACY_BASELINE_OK` and scratch-only `R7_RD_RUNTIME_CHECK_OK` remain recorded as dependency evidence.
- Next recommended action: decide the promotion/default-selection policy and any broader fixture coverage before making canonical compute the normal production path. Do not promote the simple diagonal/source-edge tie rules, chase exact CanvasItem sampler artifacts, relax `R7_TOLERANCE_V1`, introduce `R7_TOLERANCE_V2`, or replace checked-in generated bake resources prematurely.
- Known deferred work: full compute backend replacement, diagnostics GPU reductions, non-neutral flow-speed fixture, and any full-Demo comparison.

## Document Relationship

- Parent river-refactor docs remain the canonical track dashboard and roadmap:
  - `../session-handoff.md`
  - `../roadmap.md`
  - `../tasks.md`
  - `../validation.md`
- R7 docs are the active phase-local contract for compute-first bake performance:
  - `session-handoff.md`
  - `tasks.md`
  - `review.md`
  - `validation.md`
  - `plan.md`
  - `spec.md`
  - `research.md`
- R6 docs are dependency evidence, not the active R7 checklist. Use them to preserve the boundary R7 must not break:
  - `../r6/validation.md`
  - `../r6/session-handoff.md`
  - `../r6/review.md`

## Open Work

- [x] Record the compute-first decision and skip the SubViewport-resident interim.
- [x] Create R7 `spec.md`, `plan.md`, `validation.md`, and `research.md`.
- [x] Complete pre-implementation adversarial review of the R7 plan and harden false-green gates.
- [x] Add the missing feature-folder template docs for R7: `tasks.md`, `review.md`, and `session-handoff.md`.
- [x] Add the low-cost deterministic bake fixture and baseline probe only.
  - Validate: fixture/probe exists, does not save generated resources in place, and is documented in `validation.md`.
- [x] Record the legacy baseline before any compute replacement.
  - Validate: `R7_LEGACY_BASELINE_OK`; pass trace proves the expensive path, including collision-support filters, water occupancy, obstacle feature mask, flow divergence, all 40 Jacobi executions, projected flow, boundary tangency, final combines, diagnostics/postprocess, and RiverManager result handoff.
- [x] Add tolerance compare mode and self-compare/format round-trip evidence.
  - Validate: per-texture/channel metrics, occupied-atlas metrics, decoded flow angle/magnitude metrics, binary/class-mask coverage deltas, and end-to-end `Image`/`ImageTexture` conversion proof.
- [x] Add the RenderingDevice sync/readback stress probe.
  - Validate: `R7_RENDERING_DEVICE_SYNC_OK`; includes stale binding/resource-reuse, intra-list barrier, attempted async readback, proven delayed sync/readback, repeated-run/resource-reuse, and standalone cleanup subcases. Async readback is not selected because the callback did not arrive in the recorded run.
- [x] Prototype local RenderingDevice setup and cleanup without changing generated output.
  - Validate: `R7_COMPUTE_BACKEND_SKELETON_OK`; `R7_R6_SURFACE_PROPERTY_DIFF_OK`; no compute output replaces bake textures yet.
- [x] Port one isolated solve/filter step behind the baker.
  - Validate: `R7_COMPUTE_SOLVE_FILTER_STEP_OK`; pressure-Jacobi RGBA32F compute output matches deterministic CPU reference, legacy RiverManager texture IDs and hashes remain unchanged, and no compute output replaces bake textures yet. The follow-up parity gate now pins that reference to the legacy shader semantics before full-stack expansion.
- [x] Confirm the isolated pressure-Jacobi proof against legacy shader semantics before expanding.
  - Validate: `R7_COMPUTE_SOLVE_FILTER_STEP_OK`; CPU reference and compute shader use legacy pressure/divergence encoding, source-size stride, atlas-column padding walls, solid-cell behavior, y clamp, and Neumann wall assumptions; `r7_compute_solve_filter_step_probe.gd` compares the same synthetic intermediate through `flow_pressure_jacobi_pass.gdshader`.
- [x] Expand the isolated proof into a production-shaped multi-pass pressure-Jacobi stack.
  - Validate: `R7_COMPUTE_SOLVE_FILTER_STACK_OK`; RGBA32F ping-pong pressure textures run the real stride/iteration schedule `[32, 16, 8, 4, 2, 1, 1, 1]` with 5 iterations per stride, 40 dispatches, one compute list, 39 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, legacy shader multi-pass intermediate comparison, unchanged RiverManager texture IDs/hashes, and no generated bake output replacement. The stack uses `R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1`; final generated bake textures still need `R7_TOLERANCE_V1`.
- [x] Add divergence, gradient subtract, and boundary tangency compute passes around the pressure stack as non-replacing diagnostics.
  - Validate: `R7_COMPUTE_SOLVE_FILTER_STACK_OK` still passes; the expanded projection path records 44 dispatches, 43 dependent-dispatch barriers, no output texture keys, unchanged RiverManager texture hashes, and a legacy-pressure diagnostic where divergence, pressure, projected flow, final flow, final combine, and postprocess all pass `R7_TOLERANCE_V1`.
- [x] Instrument actual legacy pass-6 pressure-feedback sampler behavior.
  - Validate: `R7_COMPUTE_SOLVE_FILTER_STACK_OK` still passes; `legacy_pass6_sampler.*` in `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt` records a controlled `FilterRenderer.apply_flow_pressure_jacobi` pass at `stride=16`, `source_size=64`, `texture=106x106`, and `atlas_columns=5`. The diagnostic shows vertical half-texel reads split lower/upper by probe position, while horizontal stride-16 reads are atlas-wall center reads.
- [x] Audit legacy pressure-feedback correctness separately from `R7_TOLERANCE_V1`.
  - Validate: `R7_COMPUTE_SOLVE_FILTER_STACK_OK` still passes with the 25-point grid diagnostic in `.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/r7_compute_solve_filter_stack.txt`. The shader intent is coherent, but the mixed pass-6 vertical sampling is a canvas-renderer artifact with unproven visual consequence. A simple `point.x < point.y` diagonal model matches only `22/25` up and `22/25` down samples, so it is not safe to hard-code as the production compatibility rule. Legacy output remains diagnostic and fallback evidence.
- [x] Audit primary compute-pressure generated bake output under legacy `R7_TOLERANCE_V1`.
	- Validate: current primary compute-pressure candidate is intentionally non-replacing and still fails after the latest pressure-feedback retry: generated candidate p95 angle `3.48932145236808 deg`, max angle `12.4395520353247 deg`, occupied G p99 `0.00784313678741`, occupied R p99 `0.00392159819603`. This remains required compatibility evidence, but exact legacy CanvasItem parity is no longer the final replacement oracle once `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` is satisfied.
	- Diagnostic attempt: the opt-in `pressure_jacobi_canvas_tie_mode=1` candidate is non-replacing and keeps the default primary path unchanged. It improves p95 angle to `3.02500924801543 deg` and weighted mean to `0.60170081393187 deg`, but worsens p99/max angle to `5.96108559105589/18.2393832633789 deg`; occupied G/R p99 remain `0.00784313678741`/`0.00392159819603`. Keep it diagnostic-only.
	- Diagnostic attempt: denser scanline and y-band probes show the pass-6 stride-16 sampler is exactly explained by `upper when point.x < point.y except source_size - 1 row, otherwise lower` for the controlled tables (`25/25` grid, `95/95` scanline, `209/209` y-band, both up and down). The opt-in `pressure_jacobi_canvas_tie_mode=2` source-edge candidate is still non-replacing and not accepted: it improves p95/weighted mean to `2.81378265972502 deg`/`0.51408882340789 deg`, but p99 remains worse than primary at `5.71058370749061 deg`, max remains `18.2393832633789 deg`, angle-over-10 count rises to `7`, and occupied G/R p99 remain failing.
	- Diagnostic attempt: pass-limited pressure prefix comparisons across modes 0/1/2 at pass counts `[5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]` explain why the controlled sampler model is not enough. Pass 5 is clean for all modes. Primary mode 0 first fails at pass 6, stride 16 iteration 1 (`occupied_r_p99_abs=0.18359375`) and peaks at pass 10 (`occupied_r_p99_abs=0.30126953125`); the generated primary max remains `(82, 47)` with `12.4395520353247 deg`. Modes 1/2 fix `(82, 47)` but leave local max pressure errors from pass 6 and create the `(61, 67)` generated max tail, with pressure delta `0.3671875` at pass 20 and final generated angle `18.2393832633789 deg`. Mode 2 moves most occupied G/R failures into tile 5 `(42, 63)`, so it appears over-applied near the source-edge row/tile-edge band.
	- Next patch lead: account for the controlled pass-6 finding instead of retrying uniform floor/ceil/tie or global UV-bias rules. On the 106-wide padded texture the `26.5`-texel vertical offset split lower/upper choices `3/2` for both up and down samples; the current compute floor model matched only `1/5` up choices and `2/5` down choices in the five-point diagnostic. The 25-point grid shows compute floor-model matches of `10/25` up and `9/25` down; the source-edge model explains the controlled sampler, but generated-output tail failures show it is not sufficient as a replacement compatibility model.
  - Keep constraints: all work stays behind `RiverFlowmapBaker`, output texture keys stay empty, delayed single-submit/wait/sync/readback stays selected, async readback stays blocked, and no generated bake output replacement is allowed until either the primary candidate passes legacy `R7_TOLERANCE_V1` or the separate `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` path passes with visual/semantic evidence and fallback/signature decisions recorded.
- [x] Add the probe-only `FRAGCOORD` legacy shader diagnostic.
	- Validate: `R7_COMPUTE_SOLVE_FILTER_STACK_OK` still passes; `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt` records `legacy_pass6_sampler.fragcoord_uv_artifact_hypothesis_supported=true`. The y-band legacy UV cases had 20 total X-dependent transitions, while the `FRAGCOORD` variant had 0; the result supports the UV-artifact hypothesis but does not promote the compute floor model, diagonal model, or source-edge model as production behavior.
- [ ] Define and implement `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.
	- Validate: canonical integer texel-space pressure feedback rules are documented and implemented; legacy parity p95/p99/max reports still run as diagnostics; visual/semantic gates pass; fallback selection remains available; RiverManager ownership stays unchanged; and generated bake signature/version impact is deliberately recorded before any replacement output ships.
	- [x] Add and run the automated canonical acceptance proof: canonical RGBA32F pressure feedback, integer texel-space rules, semantic/divergence/integrity/ownership gates, visual artifact generation, skeleton rerun, R6 surface guard, and `git diff --check`.
	- [x] Complete visual review of the five generated artifacts and explicitly accept or reject the visible/output change.
		- Decision: accepted for the low-cost canonical artifact set. We are accepting a visible/output change from legacy for the canonical compute path.
		- Evidence: final/projected flow RG artifacts are spatially coherent around the river and obstacle; pressure is smooth/localized; the divergence-after artifact is more broadly textured than divergence-before, but the automated metric gate reduces the tail (`p99_abs 0.2470703125 -> 0.12841796875`) and keeps final max within the documented bound.
	- [x] Record replacement readiness, fallback selection UX/config, and bake signature/version decision before any generated bake output replacement ships.
		- Replacement readiness decision: `replacement_ready=false`; do not replace generated bake output yet.
		- Fallback/config decision: legacy CanvasItem remains the production default/fallback until a production selection path exists and the remaining coverage passes; a future compute replacement must stay behind an explicit selection/config path until it is promoted.
		- Bake signature/version decision: source signature version is now 29 for the canonical compute replacement boundary; backend mode stays outside the source signature because it is still an internal baker selection surface rather than a RiverManager source key.
- [ ] Move CPU pixel diagnostics only after consumers are migrated.
  - Validate: grep probes/docs for marker text and progress labels immediately before the move; keep or update warning/progress contracts deliberately.
- [x] Add compute cleanup/abort/editor responsiveness coverage using the low-cost fixture.
  - Validate: refreshed `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`; non-replacing full projection max frame gap `142.179 ms`, neutral legacy max `81.209 ms`, non-neutral legacy max `85.307 ms`; cancelled compute reaches compiled resources and sampler setup, then reports zero owned RIDs, released local RenderingDevice, no unsynced submit state, no output texture keys, and `production_output_replaced=false`.
- [x] Add explicit non-neutral flow-speed coverage before migrating that path.
  - Validate: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`; neutral flow-speed pass count `0` with `flow_speed_scaled=false`, non-neutral flow-speed pass count `1` with `flow_speed_scaled=true`, and `flow_foam_noise` hash changes from `3bfadac449d094f0bd603f8549f8de9e` to `66af6fbcab99aef2813cbd96c13ca733`.
- [x] Add representative-scene/material visual evidence for canonical compute.
  - Validate: `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`; `.codex-research/r7-baselines/compute-representative-visuals/r7_compute_representative_visuals.txt` records a temporary material binding of the canonical candidate only, 7 material/top-down/debug screenshots, 6 texture-space neighborhood crops around obstacle/contact/tile-edge/known failure targets `(82, 47)`, `(61, 67)`, and tile-5 `(42, 63)`, unchanged RiverManager texture state/hashes, source signature version 29, empty output texture keys, and `production_output_replaced=false`.
- [x] Add active production replacement selection/config and replacement-path abort coverage.
  - Validate: `R7_COMPUTE_SELECTION_ABORT_OK`; explicit `flowmap_backend_mode` is recognized at the baker boundary, legacy CanvasItem remains the selected generated-output default/fallback, canonical compute remains non-replacing for report-only requests, missing-evidence replacing compute falls back to legacy, source signature version is 29, and direct abort plus immediate cleanup/owner-free/scene-close interrupted compute runs return cancelled after submit with zero owned RIDs, released local RenderingDevice, no unsynced submit state, empty output texture keys, and `production_output_replaced=false`.
- [x] Define the exact `canonical_compute_replacing` promotion gate without enabling replacement.
  - Validate: refreshed `R7_COMPUTE_SELECTION_ABORT_OK`; `river_flowmap_baker.gd` reports `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` with `stage=report_only_non_replacing`, `ready=false`, `replacement_ready=false`, minimum replacing signature version `29`, and pre-evidence blockers for generated-output replacement staging and production replacement validation. Source signature v29 and the gated replacement code path are now accepted; the later staging and production-validation proofs supply the remaining evidence.
- [x] Implement generated-output replacement staging without enabling replacement.
  - Validate: `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`; the staging report names `flow_foam_noise` as the staged output key, records legacy before hash `3bfadac449d094f0bd603f8549f8de9e` and staged candidate hash `a5ee9d4f0e7585ca1dc67d3c72c26a49`, keeps `flow_foam_noise.b/a` and all other generated textures legacy-sourced, preserves RiverManager output IDs/hashes and public-surface ownership, records source signature version 29, and proves `canonical_compute_replacing` still falls back to legacy until production validation evidence is supplied.
- [x] Add production replacement validation without enabling replacement.
  - Validate: `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`; the production report names the RiverManager handoff fields, would hand off canonical `flow_foam_noise.rg` plus legacy `flow_foam_noise.ba` and legacy-sourced remaining textures, records `elapsed_ms=228.019`, `max_frame_gap_ms=145.067`, one submit/sync after three waited frames, unchanged live RiverManager state/hashes, empty actual output texture keys, `production_output_replaced=false`, source signature version 29, an empty supplied-evidence blocker list, and a direct runtime smoke where explicit `canonical_compute_replacing` reports `output_texture_keys=["flow_foam_noise"]`.
- [x] Choose the source signature policy before output-changing replacement.
  - Validate: `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` is bumped to 29; backend mode is not added to the source signature because `flowmap_backend_mode` remains an internal baker selection surface rather than a RiverManager source key.
- [x] Deliberately enable the canonical compute replacement code path behind the gate.
  - Validate: refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`; with all gate evidence supplied, explicit `canonical_compute_replacing` selects compute, the direct baker runtime smoke reports `production_output_replaced=true`, `output_texture_keys=["flow_foam_noise"]`, delayed sync readback, and unchanged RiverManager state/hashes. Default production selection remains `legacy_canvas_item`.

## Setup

- [ ] Confirm current workspace state and branch before implementation.
- [ ] Read this R7 `session-handoff.md`, then `tasks.md`, `review.md`, `validation.md`, `plan.md`, `spec.md`, and `research.md`.
- [ ] Read parent `../session-handoff.md`, `../roadmap.md`, and `../tasks.md` for track-wide truth.
- [ ] Read R6 `../r6/validation.md` and `../r6/session-handoff.md` before touching bake orchestration, result handoff, cleanup, public surface, or property-list behavior.
- [ ] Check `addons/waterways/docs/research/river-research-citations.md` before research-driven changes.
- [ ] For Godot-specific implementation work, search current official Godot documentation before patching and record implementation-relevant findings in `research.md`.
- [ ] Confirm whether the task affects active code, probes, shaders, scenes, generated resources, docs, or validation tooling.
- [ ] If running Godot, use repo-local `APPDATA`/`LOCALAPPDATA` profile redirects from `validation.md` or `session-handoff.md`.
- [ ] Run the context challenge check: can this baseline prove R7 improved the expensive projection workload, or only that a cheap fallback stayed cheap?

## Implementation

- [ ] Keep RiverManager ownership from R6 intact.
  - Validate: RiverManager still owns public API, resource writing, material binding, validity flags, bake flag clearing, completion signaling, and public/property surface.

- [ ] Keep compute ownership behind the baker.
  - Validate: compute backend owns only GPU resources, dispatch, sync/readback, and cleanup behind `RiverFlowmapBaker`.

- [x] Preserve bake compatibility deliberately through the replacement boundary.
  - Validate: the output-changing replacement boundary now uses source signature version 29. Pre-v29 bakes are stale for canonical compute replacement; generated resources are not replaced by docs/probe-only validation.

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge after validation.
- [ ] Do not rely on headless checks for compute correctness; R7 compute probes run windowed Forward+/Vulkan when available.
- [ ] For human-assisted checks, paste exact steps into the user-facing message.
- [ ] Record results in `validation.md` and review conclusions in `review.md`.

## Cleanup

- [ ] Remove temporary debug code not intended as shipped validation tooling.
- [ ] List scratch/generated artifacts created during validation.
- [ ] Confirm `.codex-research/` and disposable probe outputs remain excluded from packaging.
- [ ] Update docs for changed decisions, validation results, or ownership boundaries.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-safe code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced.

## Historical or Closed Tasks

- 2026-06-14: R7 compute-first decision recorded. The SubViewport-resident ping-pong interim was rejected.
- 2026-06-14: Official Godot 4.6 RenderingDevice research and installed 4.6.3 scratch checks recorded in `research.md`.
- 2026-06-14: Adversarial review hardened baseline, pass-trace, texture-format, tolerance, sync/readback, and editor-heartbeat requirements.
- 2026-06-14: Low-cost R7 fixture/probe added and legacy baseline recorded with `R7_LEGACY_BASELINE_OK`.
- 2026-06-14: The isolated pressure-Jacobi compute/reference proof was corrected to legacy UV-space shader semantics and validated against a one-step `flow_pressure_jacobi_pass.gdshader` intermediate while remaining non-replacing.
- 2026-06-14: The isolated pressure-Jacobi proof was expanded into a non-replacing production-shaped 40-pass pressure stack behind `RiverFlowmapBaker`; `R7_COMPUTE_SOLVE_FILTER_STACK_OK` records ping-pong RGBA32F storage textures, intra-list compute barriers, a legacy shader multi-pass intermediate comparison, and unchanged RiverManager texture state.
- 2026-06-15: Legacy pressure-feedback correctness was audited separately from `R7_TOLERANCE_V1`; the mixed pass-6 sampler behavior is artifact-shaped and remains compatibility/fallback evidence, not the canonical solver target.
- 2026-06-15: Opt-in canvas-tie pressure diagnostic recorded. It improved broad p95/mean drift but worsened p99/max angle and stayed below `R7_TOLERANCE_V1`, so it remains a diagnostic lead only.
- 2026-06-15: Dense scanline/y-band source-edge diagnostic recorded. It exactly explains the controlled pass-6 sampler tables but does not solve generated-output p99/max/channel failures, so it remains a diagnostic lead only.
- 2026-06-15: Pass-limited pressure prefix diagnostic recorded. It localizes primary broad drift to stride-16 pass 6-10 and shows the source-edge candidate moves the remaining tail into later stride/tile-edge cases instead of closing generated-output parity.
- 2026-06-15: Probe-only `FRAGCOORD` diagnostic recorded and architecture pivot made. Compute pressure feedback is the canonical solver target; legacy CanvasItem parity remains compatibility evidence and fallback behavior, with intentional output changes accepted only through `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.
- 2026-06-15: Automated canonical compute acceptance recorded with `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`; the five low-cost canonical visual artifacts were later accepted as an intentional visible/output change from legacy. Replacement readiness is still false, generated output is still not replaced, and production coverage remains open.
- 2026-06-15: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK` recorded non-replacing compute cleanup, heartbeat, and non-neutral flow-speed coverage. Later `R7_COMPUTE_SELECTION_ABORT_OK` closed explicit selection/abort coverage, `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` closed the low-cost representative/material visual slice, `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK` closed report-only generated-output staging, and `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` closed production replacement validation plus direct runtime smoke. Source signature policy and gated replacement code enablement are now accepted; final default-production promotion remains open.
- 2026-06-15: `R7_COMPUTE_SELECTION_ABORT_OK` recorded explicit backend selection and guarded active abort/free/scene-close cleanup coverage. Legacy CanvasItem remains the selected generated-output default/fallback, report-only canonical compute remains non-replacing, source signature version is 29, and generated output is still not replaced.
- 2026-06-15: `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` recorded low-cost representative material/debug visual evidence. The canonical candidate was temporarily bound to the live material for screenshots and then restored; generated bake output remains unreplaced.
- 2026-06-15: `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK` recorded report-only generated-output replacement staging. The staged map would replace `flow_foam_noise` only, leaves remaining textures/channels legacy-sourced, and keeps production output unreplaced.
- 2026-06-15: `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` refreshed after source signature v29 and gated replacement-code enablement. The would-handoff payload keeps only `flow_foam_noise.rg` canonical, all other texture fields/channels legacy-sourced, live output unchanged, the supplied-evidence gate has no blockers, and the direct baker runtime smoke reports `output_texture_keys=["flow_foam_noise"]` without changing RiverManager state/hashes.
