# Session Handoff: River Refactor R7 - Compute-First Bake Performance

## Date

2026-06-15

## Current Focus

R7 is the compute-first bake-performance phase of the river-refactor track. This folder now has the full feature-folder template set, records the pre-implementation plan review, includes the first low-cost legacy baseline fixture/probe slice, has a non-replacing production compute backend skeleton behind the baker, and now has the isolated pressure-Jacobi solve/filter compute step, the production-shaped multi-pass pressure-Jacobi stack proof, a non-replacing divergence/gradient/tangency projection diagnostic, a controlled legacy pass-6 sampler/grid/scanline/y-band diagnostic, a legacy pressure-feedback correctness audit, opt-in canvas-tie/source-edge pressure diagnostics, a pass-limited pressure prefix localization diagnostic, a probe-only `FRAGCOORD` diagnostic, an automated canonical-compute acceptance gate, the low-cost canonical artifact visual review, non-replacing cleanup/heartbeat/non-neutral flow-speed coverage, explicit selection plus guarded active abort/free/scene-close cleanup coverage, low-cost representative material/debug visual coverage, the guarded `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` promotion gate, report-only generated-output replacement staging, source signature v29, a gated canonical compute replacement branch, refreshed production replacement validation with a direct runtime smoke, broader low-cost/Demo/obstacle promotion fixture coverage, accepted saved-output promotion for the two scoped Demo river bake resources, the requested compute-default human-visible in-game review, the explicit legacy-vs-compute backend performance comparison, and final pre-switch validation for non-neutral compute flow-speed, saved-resource loading, system-map compatibility, and selection/cleanup. The code default backend now returns `canonical_compute_replacing`; the saved resources are intentionally promoted under source signature v29. Both the R7 compute solution and the legacy CanvasItem solution stay available until a separate legacy-removal protocol is accepted.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-refactor\r7\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: In progress; validation-only baseline, tolerance/format, sync/readback gates, non-replacing production compute backend skeleton, first isolated non-replacing solve/filter compute step, pressure-Jacobi legacy shader parity confirmation, production-shaped pressure-Jacobi stack proof, non-replacing projection-pass diagnostic, controlled pass-6 sampler/grid/scanline/y-band diagnostic, legacy pressure-feedback correctness audit, opt-in canvas-tie/source-edge pressure diagnostics, pass-limited pressure prefix diagnostic, probe-only `FRAGCOORD` diagnostic, canonical-compute architecture decision, automated canonical acceptance proof, low-cost canonical visual artifact review, non-replacing cleanup/heartbeat/non-neutral flow-speed proof, explicit selection plus guarded active abort/free/scene-close cleanup proof, low-cost representative material/debug visual proof, guarded replacement-promotion gate, report-only generated-output replacement staging, source signature v29, gated replacement code path, refreshed production replacement validation, broader promotion fixture coverage, saved-output promotion, requested compute-default in-game visual review, explicit backend performance comparison, final pre-switch validation, and accepted compute switched/default solve path complete.
- Highest-priority open task: no behavior switch remains; compute solve is accepted as the switched/default path through `canonical_compute_replacing`, while explicit `legacy_canvas_item` stays available for comparison, rollback, and diagnostics. Define a separate explicit side-by-side comparison/removal protocol only if legacy-path removal is proposed. Do not remove the legacy CanvasItem path or collapse the backend selector. Compute pressure feedback is now the canonical solver target; legacy CanvasItem output is compatibility evidence and fallback behavior, not the final correctness oracle. The automated gate passes, the five low-cost artifacts are visually accepted, low-cost material/debug screenshots/crops are recorded, staging identifies the would-replace output map, source signature is v29, production replacement validation records the report-only handoff plus direct baker runtime smoke, broader coverage passes on low-cost/Demo/obstacle fixtures, saved-output promotion deliberately updated only the two scoped Demo river bake resources, the requested compute-default in-game review passed, explicit performance comparison shows compute faster in all recorded cases with no fallback, and final pre-switch tests cover non-neutral compute flow-speed, load-only saved resources, stale WaterSystem map compatibility, projected-flow system shader gating, and cleanup rerun.
- Last passing validation: post-doc switched/default acceptance rerun recorded `R7_COMPUTE_SELECTION_ABORT_OK`, `R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK`, `R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK`, `SYSTEM_FLOW_COMPARE_OK`, and `SYSTEM_FLOW_PROJECTED_GATE_OK` under `.codex-research/r7-baselines/compute-switched-default-acceptance/`. Previous passing evidence remains `R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK`, `R7_COMPUTE_HUMAN_VISIBLE_INGAME_REVIEW_CAPTURE_OK`, `R7_COMPUTE_SAVED_OUTPUT_PROMOTION_OK`, `R7_COMPUTE_PROMOTION_FIXTURE_COVERAGE_OK`, `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`, refreshed `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`, refreshed `R7_R6_SURFACE_PROPERTY_DIFF_OK`, plus `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`, `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`, `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`, `R7_COMPUTE_SOLVE_FILTER_STACK_OK`, `R7_COMPUTE_BACKEND_SKELETON_OK`, `R7_COMPUTE_SOLVE_FILTER_STEP_OK`, `R7_RENDERING_DEVICE_SYNC_OK`, `R7_TOLERANCE_SELF_COMPARE_OK`, and `R7_TEXTURE_FORMAT_ROUNDTRIP_OK`; `R7_LEGACY_BASELINE_OK`; scratch-only `R7_RD_RUNTIME_CHECK_OK`; latest broad shipped-code validation remains R6.5.
- Known failing or unproven check: the primary compute-pressure generated `flow_foam_noise` candidate still fails legacy `R7_TOLERANCE_V1` diagnostics after the latest pressure-feedback retry (`p95_angle=3.48932145236808 deg`, `p99_angle=5.48129340327964 deg`, `max_angle=12.4395520353247 deg`, occupied G p99 `0.00784313678741`, occupied R p99 `0.00392159819603`). The opt-in canvas-tie candidate also fails: it improves p95/weighted mean but worsens p99/max angle to `5.96108559105589/18.2393832633789 deg`. The opt-in source-edge candidate exactly fits the controlled sampler tables but still fails generated-output parity (`p95=2.81378265972502 deg`, `p99=5.71058370749061 deg`, `max=18.2393832633789 deg`, angle-over-10 count `7`, occupied G/R p99 still failing). The pass-prefix diagnostic explains the split: primary broad drift starts at pass 6-10 in stride 16, while modes 1/2 suppress broad drift but leave local max pressure errors and move the mode-2 tail into `(61, 67)` / tile 5 `(42, 63)`. Path 2 accepts the canonical output through visual/semantic/staging/production/saved-output evidence instead of relaxing `R7_TOLERANCE_V1`; async readback remains unaccepted.
- Next recommended action: treat compute as the accepted switched/default solve path and keep legacy code plus the backend selector intact. If legacy removal is proposed, first define and run an explicit side-by-side comparison/removal protocol. Do not remove legacy code, promote the simple diagonal/source-edge tie models, relax `R7_TOLERANCE_V1`, or introduce `R7_TOLERANCE_V2`. Explicit `legacy_canvas_item` remains the rollback/comparison path. The performance comparison and pre-switch suite justify the compute switched/default decision, not approval to remove legacy.
- Packaging/artifact hygiene status: two generated river bake resources are intentionally changed in shipped paths: `waterways_bakes/Demo/Water_River.river_bake.res` and `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`. Scratch API/runtime outputs and baseline reports live under `.codex-research/` and are disposable except the main reports used for future comparisons.
- Historical detail starts at: `validation.md` recorded results for the docs gate, research session, and adversarial review.

## How To Use This Feature Folder

- Treat this handoff plus `tasks.md`, `review.md`, and `validation.md` as the R7 dashboard.
- Use parent river-refactor docs for cross-phase truth, roadmap status, and historical context:
  - `../session-handoff.md`
  - `../roadmap.md`
  - `../tasks.md`
  - `../validation.md`
- Use R6 docs as dependency evidence only, especially for the RiverManager/Baker ownership boundary:
  - `../r6/validation.md`
  - `../r6/session-handoff.md`
  - `../r6/review.md`
- Do not duplicate parent or R6 history into R7 docs. Link to it and keep R7 docs focused on compute-first bake performance.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-refactor\r7\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-refactor\r7\review.md`
6. `addons\waterways\docs\spec-driven\features\river-refactor\r7\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-refactor\r7\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-refactor\r7\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-refactor\r7\research.md`
10. `addons\waterways\docs\spec-driven\features\river-refactor\session-handoff.md`
11. `addons\waterways\docs\spec-driven\features\river-refactor\roadmap.md`
12. `addons\waterways\docs\spec-driven\features\river-refactor\r6\validation.md`
13. `addons\waterways\docs\spec-driven\features\river-refactor\r6\session-handoff.md`
14. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Confirm the recorded baseline, validation-only proof files, compute skeleton report, isolated solve/filter step report, pressure-Jacobi stack report, expanded projection diagnostic report, canonical acceptance report, cleanup/responsiveness report, selection/abort report, generated-output staging report, refreshed production replacement validation report, saved-output promotion report, human-visible compute review report, backend performance comparison report, and final pre-switch reports under `.codex-research/r7-baselines/compute-non-neutral-flow-speed/`, `.codex-research/r7-baselines/compute-saved-resource-load-smoke/`, `.codex-research/r7-baselines/compute-system-map-compatibility/`, and `.codex-research/r7-baselines/compute-selection-abort-final-pre-switch/`. Use delayed single-submit/wait/sync/readback; do not use async readback or broaden checked-in generated bake texture replacement prematurely.
- The recorded baseline already proves the expensive projection workload, including collision support filters, water occupancy, obstacle feature mask, flow divergence, all 40 Jacobi executions, projected flow, boundary tangency, final combines, diagnostics/postprocess, and RiverManager result handoff.
- For Godot-specific implementation work, search current official Godot documentation and API references before patching, then record source details that affect implementation in `research.md`.
- If human-assisted Godot validation is required, paste exact scene path, plugin state, steps, expected visible result, and Output/console text into the user-facing message.
- If a future fixture or comparison can pass while avoiding the target workload, stop and fix the fixture/proof instead of accepting the result.

## What Changed This Session

- `tasks.md`: added the R7 phase task dashboard and current open-work checklist from the feature-folder template.
- `review.md`: added the R7 pre-implementation review dashboard, findings, compliance checks, and decision updates.
- `session-handoff.md`: added the R7 local handoff and documented how to reference parent river-refactor and R6 milestone docs.
- `spec.md`, `plan.md`, `validation.md`: updated read order and template-compliance wording so the new R7 docs are part of the workflow.
- `r7_low_cost_bake_fixture.tscn`: added the deterministic 64x64 low-cost baseline scene.
- `r7_legacy_canvas_item_bake_trace_probe.gd`: added the windowed baseline probe with pass trace, texture hashes, heartbeat, metadata checks, and RiverManager handoff checks.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded `R7_LEGACY_BASELINE_OK`, `R7_TOLERANCE_SELF_COMPARE_OK`, `R7_TEXTURE_FORMAT_ROUNDTRIP_OK`, and `R7_RENDERING_DEVICE_SYNC_OK`, then updated next-step status.
- `river_flowmap_compute_backend.gd`: added the baker-owned non-replacing local RenderingDevice backend skeleton.
- `r7_compute_backend_skeleton_probe.gd`: added the windowed skeleton probe with delayed single-submit/wait/sync/readback, cleanup/abort, and no-output-replacement checks.
- `river_flowmap_compute_backend.gd`: added the first isolated non-replacing pressure-Jacobi solve/filter compute step using RGBA32F storage textures, one submit, delayed frame wait, `sync()`, and `texture_get_data()` readback.
- `river_flowmap_baker.gd`: added a separate report-only solve/filter compute entry point behind the baker.
- `r7_compute_solve_filter_step_probe.gd`: added the focused windowed proof that compares the compute step against a CPU reference and proves legacy RiverManager texture state/hashes remain unchanged.
- `river_flowmap_compute_backend.gd` and `r7_compute_solve_filter_step_probe.gd`: updated the pressure-Jacobi proof to legacy shader UV/source-size stride semantics, atlas-column padding-wall handling, y clamp, solid-cell behavior, and pressure/divergence encoding; added a one-step `flow_pressure_jacobi_pass.gdshader` intermediate comparison while keeping the path non-replacing.
- `river_flowmap_compute_backend.gd`: expanded the isolated proof into a non-replacing production-shaped pressure-Jacobi stack using ping-pong RGBA32F storage textures, the real stride/iteration schedule, 40 dispatches in one compute list, 39 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, and no output texture replacement.
- `river_flowmap_baker.gd`: added a separate report-only solve/filter stack compute entry point behind the baker.
- `r7_compute_solve_filter_stack_probe.gd`: added the focused windowed proof that compares the pressure stack against a legacy shader multi-pass intermediate and verifies legacy RiverManager texture state/hashes remain unchanged.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded `R7_COMPUTE_SOLVE_FILTER_STACK_OK`, the stack-specific `R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1` pressure-intermediate gate, and the next-step shift to divergence/gradient/tangency compute before generated-output replacement.
- `river_flowmap_compute_backend.gd`: added non-replacing divergence, pressure stack, gradient subtract, and boundary tangency compute projection dispatches using RGBA16F projection textures and sampler-backed reads for legacy-like nearest/linear sampling.
- `r7_compute_solve_filter_stack_probe.gd`: added legacy bake pass capture for projection inputs/intermediates, a primary compute-pressure generated candidate comparison, and a legacy-pressure diagnostic that proves divergence, gradient subtract, boundary tangency, final combine, and postprocess under `R7_TOLERANCE_V1`.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded the expanded projection diagnostic result. Primary compute-pressure generated output remains non-replacing and fails `R7_TOLERANCE_V1`; legacy-pressure outer-pass diagnostic passes.
- `river_flowmap_compute_backend.gd`: retained sampled RGBA8 source inputs where the legacy path provides RGBA8 images, a dynamic pressure-Jacobi stride storage buffer, and explicit `textureLod(..., 0.0)` pressure/divergence/occupancy reads.
- `r7_compute_solve_filter_stack_probe.gd`: added signed channel deltas, max-delta coordinates, and per-pass legacy pressure captures to make accumulated pressure-feedback drift easier to localize.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded the latest pressure-feedback retry. It improved the primary generated candidate from p95/max angle `3.60344260089818/16.9067074883773 deg` to `3.48932145236808/12.4395520353247 deg`, but the candidate still fails and remains non-replacing.
- `r7_compute_solve_filter_stack_probe.gd`: added a controlled legacy `FilterRenderer.apply_flow_pressure_jacobi` pass-6 sampler diagnostic using uniquely encoded neighbor texels at `stride=16`, `source_size=64`, `texture=106x106`, and `atlas_columns=5`.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded the pass-6 sampler finding. Vertical half-texel reads split lower/upper by probe position, while horizontal stride-16 reads are atlas-wall center reads; simple uniform tie or bias rules remain rejected.
- `r7_compute_solve_filter_stack_probe.gd`: added a 25-point pass-6 vertical sampler grid diagnostic. The grid shows the mixed behavior is mostly ColorRect-triangle-shaped but not captured by one safe production rule: the simple `point.x < point.y` model matches `22/25` up and `22/25` down samples, with mismatches at `(10, 63)`, `(31, 63)`, and `(53, 63)`.
- `validation.md`, `tasks.md`, `review.md`, and this handoff: recorded the legacy correctness audit. The shader intent is coherent, the mixed sampler behavior is artifact-shaped with unproven visual consequence, and legacy output remains compatibility/fallback evidence.
- `river_flowmap_compute_backend.gd`: added opt-in `pressure_jacobi_canvas_tie_mode=1` for a diagnostic stride-16 vertical tie-bias candidate; the default primary path remains mode `0`.
- `r7_compute_solve_filter_stack_probe.gd`: records full 25-point grid choice arrays and runs the canvas-tie candidate beside the primary and legacy-pressure override candidates.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded that the canvas-tie candidate reduces p95/mean drift but worsens p99/max angle, so it remains diagnostic only.
- `r7_compute_solve_filter_stack_probe.gd`: added dense scanline and y-band sampler diagnostics plus source-edge model counters; the controlled tables now show `25/25`, `95/95`, and `209/209` model matches for both up and down.
- `river_flowmap_compute_backend.gd`: added opt-in `pressure_jacobi_canvas_tie_mode=2` for a source-edge diagnostic candidate; the default primary path remains mode `0`.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded that the source-edge model explains the controlled pass-6 sampler but remains diagnostic-only because generated p99/max/channel gates still fail.
- `river_flowmap_compute_backend.gd`: added opt-in `pressure_jacobi_pass_limit` for diagnostic prefix runs only; full projection runs keep `pressure_jacobi_pass_limited=false`.
- `r7_compute_solve_filter_stack_probe.gd`: added pass-limited pressure prefix comparisons for modes `0`, `1`, and `2`, known failure target records for `(82, 47)` and `(61, 67)`, top-angle records, and occupied R/G failure bucket diagnostics.
- `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded that primary broad pressure drift starts at stride-16 pass 6-10, while mode 2 moves the remaining generated-output tail into later stride/tile-edge cases rather than closing parity.
- `r7_flow_pressure_jacobi_fragcoord_probe.gdshader`: added a probe-only legacy pressure-Jacobi variant that derives the base texel center from `FRAGCOORD` instead of interpolated CanvasItem `UV`.
- `r7_compute_solve_filter_stack_probe.gd`: runs the `FRAGCOORD` variant inside the controlled pass-6 sampler diagnostic and reports the transition-count comparison while keeping production shaders/output unchanged.
- `plan.md`, `spec.md`, `validation.md`, `tasks.md`, `review.md`, `research.md`, and this handoff: recorded the architecture pivot. Compute pressure feedback is canonical; legacy CanvasItem output is compatibility evidence/fallback behavior; `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` is the separate acceptance path; `R7_TOLERANCE_V1` remains unchanged and no `R7_TOLERANCE_V2` was introduced.
- `river_flowmap_compute_backend.gd`: switched canonical projection pressure feedback/readback to RGBA32F for the non-replacing acceptance path and reports `acceptance_target=R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`, canonical integer texel-space rules, and no CanvasItem UV/tie artifact emulation.
- `r7_compute_solve_filter_stack_probe.gd`: added the automated canonical acceptance proof, semantic/divergence/integrity/ownership gates, five PNG review artifacts, and the `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK` marker while keeping production output replacement false.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `probes/README.md`, and this handoff: recorded the path 2 automated pass. The automated report deliberately left full acceptance open with `replacement_ready=false` and `production_output_replaced=false`.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, and this handoff: recorded the low-cost canonical visual artifact review. The five artifacts are accepted as an intentional visible/output change from legacy. That slice still had `replacement_ready=false` and legacy CanvasItem as the production default/fallback; later staging, production validation, saved-output promotion, and the accepted switched/default compute path supersede that state.
- `river_flowmap_compute_backend.gd`: added final cleanup-state report fields for non-replacing compute runs.
- `r7_compute_cleanup_responsiveness_probe.gd`: added the windowed low-cost probe for non-replacing compute heartbeat timing, cancellation cleanup after resource setup, and neutral/non-neutral flow-speed coverage.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `spec.md`, `probes/README.md`, and this handoff: recorded refreshed `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`. Neutral legacy max frame gap was `81.209 ms`, non-neutral legacy max was `85.307 ms`, compute projection max was `142.179 ms`; cancellation cleanup reported zero owned RIDs and a released local RenderingDevice; non-neutral flow-speed pass count was `1`.
- `river_flowmap_baker.gd`: added explicit `flowmap_backend_mode` selection. Current state: non-explicit bakes use accepted `canonical_compute_replacing`, explicit `legacy_canvas_item` remains available, canonical compute stays non-replacing/report-only for non-replacing requests, and explicit missing-evidence replacing compute falls back to legacy output.
- `river_flowmap_baker.gd`: added `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` so `canonical_compute_replacing` is blocked until canonical acceptance, representative visuals, selection/abort, cleanup/responsiveness, R6 surface evidence, accepted generated-output replacement staging, accepted production replacement validation, source signature version 29 or backend-keyed source signatures, and an enabled replacement code path are all present.
- `river_flowmap_compute_backend.gd`: hardened direct abort during delayed compute wait so an in-flight non-replacing compute run can return a cancelled cleanup report after the local RenderingDevice has already been released.
- `r7_compute_selection_abort_probe.gd`: added the windowed proof for explicit backend selection plus direct abort with immediate cleanup, owner-free, scene-close interrupted compute cleanup after submit, and the replacement-gate field/blocker contract.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `spec.md`, `probes/README.md`, and this handoff: recorded `R7_COMPUTE_SELECTION_ABORT_OK` and a fresh `R7_R6_SURFACE_PROPERTY_DIFF_OK`. Direct abort plus immediate cleanup, owner-free, and scene-close runs returned `reason=cancelled`, zero owned RIDs, released local RenderingDevice, no unsynced submit state, empty output texture keys, and `production_output_replaced=false`; the refreshed report records source signature version 29, no signature/code-path blockers, and missing-evidence blockers before staging/production evidence is supplied.
- `river_flowmap_baker.gd`: added report-only generated-output replacement staging helpers for `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`. The staged replacement candidate is only `flow_foam_noise.rg`; `flow_foam_noise.ba` and all other generated textures remain legacy-sourced.
- `r7_compute_generated_output_replacement_staging_probe.gd`: added the windowed proof that records before/after hashes, staged and legacy-sourced texture keys/channels, RiverManager ownership/public-surface preservation, unchanged live generated textures, and `canonical_compute_replacing` fallback behavior without enabling production replacement.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `spec.md`, `probes/README.md`, and this handoff: recorded `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`. The gate drops the staging blocker when staging evidence is supplied; the later production-validation proof and saved-output promotion pass now supply production/promotion evidence, while any code-default backend flip remains separate.
- `river_flowmap_baker.gd`: added report-only production replacement validation helpers that describe the RiverManager handoff payload without applying it. The would-handoff map sends canonical `flow_foam_noise_texture` RG through the candidate while keeping foam/noise BA and all other generated texture fields legacy-sourced.
- `r7_compute_production_replacement_validation_probe.gd`: added the windowed proof for handoff fields, timing/responsiveness, fallback behavior, ownership/public-surface preservation, unchanged live generated textures, and the post-validation gate state.
- `river_bake_constants.gd` and `river_manager.gd`: bumped `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` to 29 for the canonical compute replacement boundary.
- `river_flowmap_baker.gd`: enabled the gated `canonical_compute_replacing` branch behind `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`. The branch replaces only the projected flow input to the final combine, so `flow_foam_noise.r/g` can come from canonical compute while `flow_foam_noise.b/a` and all remaining generated textures stay legacy-sourced.
- `r7_compute_production_replacement_validation_probe.gd`: refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` and added a direct runtime replacement-path smoke. It reports `output_texture_keys=["flow_foam_noise"]`, delayed sync readback, 44 dispatches, 43 barriers, and unchanged RiverManager state/hashes because it does not hand the smoke output back to RiverManager.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `spec.md`, `research.md`, `probes/README.md`, and this handoff: recorded source signature v29, enabled replacement code path, and the refreshed production validation state.
- `r7_compute_promotion_fixture_coverage_probe.gd`: added broader explicit-gated promotion fixture coverage across the low-cost fixture, `res://Demo.tscn`, and `res://Demo_obstacle_flow_test.tscn`.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `spec.md`, `research.md`, `probes/README.md`, and this handoff: recorded `R7_COMPUTE_PROMOTION_FIXTURE_COVERAGE_OK`, the default-selection policy, and `R7_COMPUTE_SAVED_OUTPUT_PROMOTION_OK`. The explicit gated branch has broader fixture coverage, the two scoped Demo river bake resources are intentionally promoted under source signature v29, and compute is now the accepted switched/default solve path through `canonical_compute_replacing`.
- `r7_compute_non_neutral_flow_speed_probe.gd`: added the final explicit compute-path non-neutral flow-speed proof. The accepted run records `canonical_compute_replacing`, no fallback, one `flow speed scale map` pass only for the non-neutral case, and generated impact scoped to `flow_foam_noise.r/g`.
- `r7_compute_saved_resource_load_smoke_probe.gd`: added the load-only smoke for the promoted saved Demo river bakes. The accepted run loads `res://Demo_obstacle_flow_test.tscn` and `res://Demo.tscn` without rebaking or saving, verifies material/debug binding and texture availability, and keeps river plus WaterSystem file hashes unchanged.
- Existing system-flow probes: reran `system_flow_compare_probe.gd` with `enforce=all allow_stale=1` and `system_flow_projected_gate_probe.gd` after saved-output promotion. Stale WaterSystem map warnings are expected because those resources were intentionally not regenerated; `SYSTEM_FLOW_PROJECTED_GATE_OK` confirms the projected-flow shader gate is still active.
- `validation.md`, `tasks.md`, `review.md`, `plan.md`, `probes/README.md`, and this handoff: recorded `R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK`, `R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK`, `SYSTEM_FLOW_COMPARE_OK`, `SYSTEM_FLOW_PROJECTED_GATE_OK`, and final pre-switch `R7_COMPUTE_SELECTION_ABORT_OK`. With those tests recorded, compute solve is accepted as the switched/default path; legacy-path removal remains separate and unapproved.

## Latest Pressure-Feedback Drift Findings - 2026-06-14

- Retained changes: preserving RGBA8 sampled inputs made projection divergence exact; using a per-dispatch stride storage buffer removed one shader-variant variable; explicit `textureLod(..., 0.0)` on pressure/divergence/occupancy reads produced the best retained generated-output improvement without changing the report-only contract.
- Reverted or rejected hypotheses: texelFetch/tie-down/edge-UV variants, small UV/sample biases, pre-occupancy variants, split compute lists, fresh pressure textures per pass, RGBA32F projection pressure, linear pressure sampling, divergence scale tweaks, 4/6 iterations per stride, candidate RGBA8 output, and tiny output/channel biases all moved errors around or worsened final parity.
- Additional dead end: a throwaway half-UV quantization probe showed legacy HDR ColorRect readback behaves half-ish around pixel centers, but patching a half-like base UV into compute only moved the pass-6 error. A CPU sampler replay of legacy pass 6 from captured pass 5 also did not reproduce the legacy shader closely enough with simple floor/tie/linear/source-size variants.
- Current finding: the remaining mismatch is accumulated pressure-feedback drift, first becoming clear when the real `[32, 16, 8, 4, 2, 1, 1, 1] x 5` schedule enters the first stride-16 pass on the 106-wide padded texture. The controlled legacy sampler diagnostic confirms the 26.5-pixel vertical offset does not use one global tie rule: up-neighbor and down-neighbor choices each split lower/upper `3/2` across five probe points, and the current compute floor model matched only `1/5` up choices and `2/5` down choices. The 25-point grid now records floor-model matches of `10/25` up and `9/25` down, while a simple ColorRect diagonal model matches only `22/25` in each direction.
- Historical next patch target before the pivot: tighten compute pressure-feedback around the spatially mixed canvas UV/tie behavior exposed by `legacy_pass6_sampler.*`, but do not hard-code/promote the simple diagonal rule or the source-edge diagnostic. Keep those metrics as diagnostic evidence; replacement now requires either legacy parity or `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.

## Latest Pass-Prefix Diagnostic Findings - 2026-06-15

- The pass-prefix report is `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/r7_compute_solve_filter_stack.txt`. It adds diagnostic-only pressure prefix comparisons at pass counts `[5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]` for primary mode 0, diagonal mode 1, and source-edge mode 2. The latest overall stack report is the later canonical acceptance run under `.codex-research/r7-baselines/compute-canonical-acceptance/`.
- Full projection runs remain non-replacing: `pressure_jacobi_pass_limited=false`, empty `output_texture_keys`, `production_output_replaced=false`, delayed single-submit/wait/sync/readback, and async readback blocked. The pass limit is only used inside prefix diagnostic runs.
- Pass 5 is clean for all modes. Primary mode 0 first fails at pass 6, stride 16 iteration 1 (`occupied_r_p99_abs=0.18359375`, `occupied_r_max_abs=0.234375`) and peaks at pass 10 (`occupied_r_p99_abs=0.30126953125`, 249 occupied over-gate samples).
- Modes 1/2 suppress broad stride-16 p99 drift but still have local max errors from pass 6, fail occupied p99 by pass 8, and peak occupied p99 at pass 15. This explains why their p95/mean generated metrics improve while p99/max still fail.
- The primary generated max target `(82, 47)` has a mode-0 pressure delta `2.140625` at pass 15 and final generated angle `12.4395520353247 deg`. Modes 1/2 fix `(82, 47)` exactly in generated output, but create the `(61, 67)` tail with pressure delta `0.3671875` at pass 20 and final generated angle `18.2393832633789 deg`.
- Occupied channel clusters support the over-application hypothesis: primary failures cluster mainly in tiles 4/3 for G and 6/7 for R, while mode 2 moves most occupied G/R failures into tile 5 `(42, 63)` near the source-edge row/tile-edge band.
- Diagnostic follow-up if needed: inspect stride-16 and later stride interactions around occupancy/tile-edge cases. Keep any candidate opt-in and diagnostic-only unless it is part of the canonical-compute acceptance path.

## Latest FRAGCOORD Diagnostic And Architecture Pivot - 2026-06-15

- Latest report: `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt`.
- Result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK`.
- The probe-only `FRAGCOORD` shader variant supports the UV-artifact hypothesis: legacy UV y-band rows had 20 total X-dependent transitions, while the `FRAGCOORD` variant had 0.
- Caution: the `FRAGCOORD` variant did not become a uniform canonical compute-floor rule (`fragcoord_y_band_compute_model_match_delta=-36`). This confirms "stop chasing interpolated-UV artifacts," not "promote a new tie rule."
- Architecture decision: compute pressure feedback is the canonical solver target. Legacy CanvasItem output stays as compatibility evidence, fallback behavior, and diagnostic comparison only.
- New acceptance path: `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`. It requires canonical texel-space solver rules, named visual evidence, physics/semantic validation, legacy parity diagnostics, fallback selection, unchanged RiverManager ownership, and an explicit bake signature/version decision if generated textures change.

## Latest Canonical Acceptance Findings - 2026-06-15

- Latest report: `.codex-research/r7-baselines/compute-canonical-acceptance/r7_compute_solve_filter_stack.txt`.
- Result markers: `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`, `R7_COMPUTE_SOLVE_FILTER_STACK_OK`, `R7_COMPUTE_BACKEND_SKELETON_OK`, and `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-canonical-acceptance surface_line_numbers=normalized`.
- The automated gate passes canonical texel-space rules, RGBA32F pressure feedback, divergence, flow semantics, image integrity, no-output-replacement ownership, fallback-selection presence, and visual artifact generation.
- Review artifacts: `r7_canonical_final_flow_rg.png`, `r7_canonical_projected_flow_rg.png`, `r7_canonical_pressure_r.png`, `r7_canonical_divergence_before_abs.png`, and `r7_canonical_divergence_after_abs.png`.
- Visual review decision: the five low-cost canonical artifacts are accepted as an intentional visible/output change from legacy. The flow RG artifacts are coherent around the river and obstacle, the pressure artifact is smooth/localized, and the busier divergence-after artifact is accepted because the automated gate reduces the divergence tail (`p99_abs 0.2470703125 -> 0.12841796875`) and keeps final max inside the documented bound.
- Saved-output production promotion is accepted for the two scoped river bake resources. `canonical_compute_replacing` is now the accepted switched/default solve path, explicit `legacy_canvas_item` remains the fallback/comparison path, source signature policy is accepted as version 29, and the direct replacement branch plus the promoted checked-in river outputs are validated.

## Latest Cleanup/Responsiveness Findings - 2026-06-15

- Latest report: `.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`.
- Result marker: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`.
- Neutral legacy low-cost bake: `flow_speed_scaled=false`, `flow speed scale map=0`, max frame gap `81.209 ms`.
- Non-neutral legacy low-cost bake: `flow_speed_scaled=true`, `flow speed scale map=1`, max frame gap `85.307 ms`, and `flow_foam_noise` hash changed from `3bfadac449d094f0bd603f8549f8de9e` to `66af6fbcab99aef2813cbd96c13ca733`.
- Canonical non-replacing compute projection: max frame gap `142.179 ms`, 44 dispatches, 43 barriers, one compute list, one submit, delayed wait-3-frames sync texture readback, RGBA32F pressure feedback, canonical integer texel addressing, `production_output_replaced=false`, and empty output texture keys.
- Cancelled compute projection: cancellation reaches compiled resources and projection sampler setup, then cleanup reports zero owned RIDs, released local RenderingDevice, and no unsynced submit state.
- Scope limit: this is report-only coverage. It does not replace generated output, and the later selection/abort proof covers explicit backend selection plus guarded active abort/free/scene-close cleanup separately.

## Latest Selection/Abort Findings - 2026-06-15

- Latest report: `.codex-research/r7-baselines/compute-selection-abort/r7_compute_selection_abort.txt`.
- Result markers: `R7_COMPUTE_SELECTION_ABORT_OK` and `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-selection-abort surface_line_numbers=normalized`.
- Backend selection contract: default `flowmap_backend_mode` is now accepted `canonical_compute_replacing` with implicit accepted R7 gate evidence only for non-explicit default bakes. Explicit `legacy_canvas_item` remains available; explicit `canonical_compute_non_replacing` preserves the request but selects legacy output fallback with `fallback_reason=canonical_compute_non_replacing_is_report_only`; explicit missing-evidence `canonical_compute_replacing` falls back with `fallback_reason=canonical_compute_replacing_not_promoted`; unsupported modes fall back to legacy.
- Replacement guard: missing-evidence compute selections report `canonical_compute_replacement_ready=false`, `production_output_replaced_by_compute=false`, `source_signature_version=29`, `signature_version_while_compute_non_replacing=29`, `canonical_compute_replacement_gate_id=R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`, `canonical_compute_replacement_gate_stage=report_only_non_replacing`, `canonical_compute_replacement_gate_ready=false`, `canonical_compute_min_replacing_signature_version=29`, and `source_signature_requires_backend_or_version_bump_before_compute_replacement=false`.
- Complete canonical projection: `ok=true`, delayed wait-3-frames sync readback, empty output texture keys, `production_output_replaced=false`, zero owned RIDs after cleanup, and released local RenderingDevice.
- Direct baker abort plus immediate cleanup, owner free, and scene close after submit: each run completes with `reason=cancelled`, `compiled_shader_count=4`, `projection_sampler_reads=true`, `submit_count=1`, `sync_count=1`, no stuck baker running flag, zero owned RIDs after cleanup, released local RenderingDevice, no unsynced submit state, empty output texture keys, and `production_output_replaced=false`.
- Scope limit: this is guarded non-replacing replacement-path coverage. Generated bake output still has not been replaced and `replacement_ready=false`.

## Current Changes Summary

- R7 now has the complete feature-folder doc set: `spec.md`, `plan.md`, `research.md`, `validation.md`, `tasks.md`, `review.md`, and `session-handoff.md`.
- The R7 low-cost legacy baseline fixture/probe, tolerance/format probe, sync/readback stress probe, non-replacing compute backend skeleton probe, first isolated pressure-Jacobi compute step probe, multi-pass pressure-Jacobi stack probe, expanded projection diagnostic, sampler diagnostics, pass-prefix diagnostic, automated canonical acceptance proof, cleanup/responsiveness proof, selection/abort proof, and representative material/debug visual proof are implemented and validated for report-only use.
- Parent river-refactor docs remain canonical for the overall roadmap/history.
- R6 docs remain dependency evidence for the preserved ownership/result-handoff boundary.

## Historical Change Log

- 2026-06-14: R7 compute-first decision recorded; SubViewport-resident interim rejected.
- 2026-06-14: Official Godot 4.6 RenderingDevice research and installed 4.6.3 scratch checks recorded.
- 2026-06-14: Adversarial review hardened baseline, pass-trace, format, tolerance, sync/readback, and heartbeat gates.
- 2026-06-14: Low-cost fixture/probe added and `R7_LEGACY_BASELINE_OK` recorded before compute replacement.
- 2026-06-14: Validation-only tolerance/format and sync/readback probes added and recorded before compute replacement.
- 2026-06-14: Non-replacing production compute backend skeleton added behind the baker and validated with `R7_COMPUTE_BACKEND_SKELETON_OK`; R6 surface/property guard reran with `R7_R6_SURFACE_PROPERTY_DIFF_OK`.
- 2026-06-14: First isolated non-replacing pressure-Jacobi solve/filter compute step added behind the baker and validated with `R7_COMPUTE_SOLVE_FILTER_STEP_OK`; R6 surface/property guard reran with `R7_R6_SURFACE_PROPERTY_DIFF_OK`.
- 2026-06-14: Pressure-Jacobi compute/reference semantics were confirmed against `flow_pressure_jacobi_pass.gdshader` using a one-step legacy intermediate comparison; no generated bake output replacement was introduced.
- 2026-06-14: The non-replacing production-shaped pressure-Jacobi stack was added behind `RiverFlowmapBaker` and validated with `R7_COMPUTE_SOLVE_FILTER_STACK_OK`; R6 surface/property guard reran with `R7_R6_SURFACE_PROPERTY_DIFF_OK`.
- 2026-06-14: Non-replacing divergence, gradient subtract, and boundary tangency projection compute passes were added around the stack. The legacy-pressure diagnostic passed intermediate and generated-output `R7_TOLERANCE_V1`; the primary compute-pressure generated candidate remains held back by pressure-feedback drift.
- 2026-06-14: Pressure-feedback drift retry retained RGBA8 sampled inputs, dynamic stride state, and explicit LOD reads. Primary generated-output metrics improved, but still fail `R7_TOLERANCE_V1`; follow-up work directly instrumented legacy pass-6 sampler/precision behavior.
- 2026-06-15: Controlled legacy pass-6 sampler diagnostic recorded; vertical half-texel choices are spatially mixed and horizontal stride-16 reads are atlas-wall center reads.
- 2026-06-15: Legacy pressure-feedback correctness audit recorded; the mixed pass-6 sampler behavior is a legacy canvas artifact with unproven visual consequence, not a shader-authored Jacobi rule. A 25-point grid rejects hard-coding a simple diagonal tie rule.
- 2026-06-15: Opt-in canvas-tie diagnostic recorded; it improves p95/mean generated-flow drift but worsens p99/max angle and remains below `R7_TOLERANCE_V1`, so it stays diagnostic-only.
- 2026-06-15: Dense scanline/y-band source-edge diagnostic recorded; it exactly explains the controlled pass-6 sampler tables but still fails generated-output p99/max/channel gates, so it stays diagnostic-only.
- 2026-06-15: Pass-limited pressure prefix diagnostic recorded; it localizes primary broad drift to stride-16 pass 6-10 and shows the source-edge diagnostic candidate shifts remaining tail risk into the `(61, 67)` / tile-5 band.
- 2026-06-15: Probe-only `FRAGCOORD` diagnostic recorded; it collapses legacy y-band X transitions from 20 to 0, supporting the UV-artifact hypothesis. R7 pivoted to `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.
- 2026-06-15: Automated canonical acceptance proof recorded with `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`; the five low-cost canonical artifacts were later visually accepted as an intentional output change. Replacement readiness remains false and production output remains non-replacing.
- 2026-06-15: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK` recorded non-replacing cleanup, heartbeat, and non-neutral flow-speed coverage. Replacement readiness remains false and production output remains non-replacing.
- 2026-06-15: `R7_COMPUTE_SELECTION_ABORT_OK` recorded explicit backend selection plus guarded active direct-abort/immediate-cleanup, owner-free, and scene-close cleanup coverage. Replacement readiness remains false and production output remains non-replacing.
- 2026-06-15: `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` recorded low-cost representative material/debug visual evidence. The canonical candidate was temporarily bound to the live material for screenshots and texture-space neighborhood review, then restored with RiverManager output state and generated texture hashes unchanged. Replacement readiness remains false and production output remains non-replacing.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Reference parent river-refactor docs for roadmap/history | They are the canonical cross-phase dashboard and checklist | Keep R7 docs focused on active R7 work |
| Reference R6 docs only as dependency evidence | R7 must preserve the R6 boundary but should not duplicate R6 validation history | Re-read R6 validation/handoff before touching bake orchestration or result handoff |
| Add full template set to R7 | R7 is heavyweight and should carry the same docs contract as R6 | Keep `tasks.md`, `review.md`, and this handoff current during implementation |
| Make compute pressure feedback canonical | `FRAGCOORD` diagnostic supports the UV-artifact hypothesis, while simple tie rules still fail tail risk | Use `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`; keep legacy parity as diagnostics/fallback evidence |
| Accept low-cost canonical visual artifacts | Flow/pressure artifacts are coherent, divergence tail improves under the automated gate, and exact legacy UV artifacts are no longer the oracle | Keep compute non-replacing; representative/material visuals and report-only generated-output staging are now recorded |
| Record explicit selection and guarded active abort/free/scene-close coverage | The baker now has a deliberate backend selection contract, and in-flight compute interrupts return clean cancelled reports after submit | Keep generated output non-replacing until signature policy and the replacement code path are accepted |
| Record low-cost representative material/debug visual evidence | The canonical candidate renders coherently in material/debug views and the known target neighborhoods have review crops | Keep generated output non-replacing until signature policy and the replacement code path are accepted |
| Define the `canonical_compute_replacing` promotion gate | The replacement path needs an explicit machine-readable blocker set before generated output can be staged | Keep generated output non-replacing until the gate is ready, source signature policy is implemented, and replacement code is deliberately enabled |
| Accept report-only generated-output replacement staging | The staging report identifies the would-replace key, before/after hashes, legacy-sourced channels/textures, and unchanged RiverManager-owned output | Keep `canonical_compute_replacing` falling back to legacy until production replacement validation, signature policy, and replacement code enablement are accepted |
| Accept report-only production replacement validation | The production report names the RiverManager handoff fields, timing, fallback behavior, before/after hashes, and legacy-sourced channels while keeping live output unchanged | Keep `canonical_compute_replacing` falling back to legacy until signature policy and replacement code enablement are accepted |
| Accept broader explicit-gated promotion coverage | Low-cost, Demo, and obstacle Demo coverage prove the gated branch only reports `flow_foam_noise` and keeps all other textures/channels legacy-sourced | Saved-output promotion, the accepted switched/default compute path, and requested compute-default in-game review are now recorded; keep explicit legacy fallback available until a separate removal protocol is accepted |
| Accept requested compute-default in-game review | Normal material and debug views are populated and continuous in the requested Demo and obstacle scenes, with only known invalid UID fallback warnings in console output | Keep explicit legacy fallback available; legacy-path removal still needs a separate accepted comparison/removal protocol |
| Record explicit backend performance comparison | Low-cost, Demo obstacle, and Demo timings show compute faster in all recorded cases with no backend fallback | Treat as regression-budget evidence only; keep explicit legacy fallback and do not remove legacy without a separate accepted removal protocol |

## Current State

Implementation status:

- Validation-only baseline, tolerance/format, sync/readback slices, non-replacing production compute backend skeleton, first isolated non-replacing solve/filter compute step, pressure-Jacobi legacy-intermediate parity, production-shaped pressure-Jacobi stack, non-replacing projection-pass diagnostic, controlled pass-6 sampler/grid/scanline/y-band diagnostics, legacy pressure-feedback correctness audit, opt-in canvas-tie/source-edge pressure diagnostics, pass-limited pressure prefix diagnostic, probe-only `FRAGCOORD` diagnostic, canonical-compute architecture decision, low-cost canonical artifact visual review, non-replacing cleanup/heartbeat/non-neutral flow-speed coverage, explicit selection/guarded active abort coverage, low-cost representative material/debug visual coverage, the guarded `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` promotion gate, report-only generated-output replacement staging, report-only production replacement validation, broader explicit-gated promotion fixture coverage, saved-output promotion, accepted switched/default compute path, requested compute-default in-game review, and explicit backend performance comparison complete.

Spec/plan status:

- Research: Current for planning; standalone format/sync probes, non-replacing skeleton, isolated solve/filter step, pressure-Jacobi stack, staging, production-validation, broader fixture coverage, saved-output promotion, accepted switched/default compute path, and backend performance comparison constraints recorded. Legacy removal remains unapproved.
- Spec: Accepted for docs gate; implementation acceptance now uses `canonical_compute_replacing` as the accepted switched/default solve path while keeping explicit legacy fallback available until a separate legacy-removal protocol is accepted.
- Plan: Current; the pressure-Jacobi stack uses delayed single-submit/wait/sync/readback, inserts intra-list compute barriers for dependent dispatches, does not use async readback, and keeps `canonical_compute_replacing` governed by `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` with explicit `legacy_canvas_item` retained.
- Tasks: Current; validation-only format/tolerance, sync/readback probes, non-replacing compute skeleton, isolated solve/filter step, pressure-Jacobi stack, outer projection-pass diagnostic, sampler diagnostics, pass-prefix diagnostic, probe-only `FRAGCOORD` diagnostic, automated canonical acceptance proof, low-cost visual review, non-replacing cleanup/heartbeat/non-neutral coverage, explicit selection/guarded active abort coverage, low-cost representative material/debug visual coverage, exact replacement promotion gate, report-only generated-output replacement staging, source signature v29, replacement code enablement, refreshed production replacement validation/runtime smoke, broader fixture coverage, saved-output promotion, accepted switched/default compute path, requested compute-default in-game review, and backend performance comparison are closed; next open work is only a separate legacy-removal protocol if removal is proposed.
- Validation: Partial; docs/scratch research, shipped low-cost legacy baseline, tolerance/format, sync/readback probes, compute skeleton, isolated solve/filter step, pressure-Jacobi stack, expanded projection diagnostic, pass-prefix diagnostic, automated canonical acceptance proof, low-cost visual review, non-replacing cleanup/heartbeat/non-neutral proof, explicit selection/guarded abort proof with replacement-gate assertions, low-cost representative visual proof, generated-output replacement staging proof, refreshed production replacement validation/runtime smoke, broader promotion fixture coverage, saved-output promotion, accepted switched/default compute path, requested compute-default in-game review, backend performance comparison, final non-neutral compute flow-speed proof, saved-resource load smoke, system-map compatibility/projected-flow gate checks, final selection/cleanup rerun, and R6 surface/property guard passed. Primary compute-pressure generated bake texture correctness remains failing under legacy parity diagnostics; canonical replacement behind the full gate is validated for low-cost/Demo/obstacle smoke coverage, the two scoped saved river bake resources are promoted, `canonical_compute_replacing` is now the accepted switched/default solve path, and explicit performance timing is recorded.
- Review: Partial pass; baseline, format/sync, non-replacing skeleton, isolated pressure-Jacobi, and pressure-stack blockers closed for the delayed-sync path. Async readback remains blocked.

Validation status:

- Automated: scratch-only `R7_RD_RUNTIME_CHECK_OK` ran in windowed and headless modes during research/adversarial review. Shipped low-cost baseline probe recorded `R7_LEGACY_BASELINE_OK`. Shipped validation-only probes recorded `R7_TOLERANCE_SELF_COMPARE_OK`, `R7_TEXTURE_FORMAT_ROUNDTRIP_OK`, and `R7_RENDERING_DEVICE_SYNC_OK`. The shipped compute skeleton probe recorded `R7_COMPUTE_BACKEND_SKELETON_OK`; the isolated solve/filter step probe recorded `R7_COMPUTE_SOLVE_FILTER_STEP_OK` with legacy shader parity fields; the pressure-Jacobi stack/projection/pass-prefix probe recorded `R7_COMPUTE_SOLVE_FILTER_STACK_OK`; the canonical acceptance slice recorded `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`; the cleanup/responsiveness probe recorded `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`; the selection/abort probe recorded `R7_COMPUTE_SELECTION_ABORT_OK`; the representative material/debug visual probe recorded `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`; the generated-output staging probe recorded `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`; the production replacement validation probe recorded `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`; the promotion fixture coverage probe recorded `R7_COMPUTE_PROMOTION_FIXTURE_COVERAGE_OK`; the backend performance comparison probe recorded `R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK`; the final pre-switch suite recorded `R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK`, `R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK`, `SYSTEM_FLOW_COMPARE_OK`, `SYSTEM_FLOW_PROJECTED_GATE_OK`, and final pre-switch `R7_COMPUTE_SELECTION_ABORT_OK`; and the R6 surface/property guard recorded `R7_R6_SURFACE_PROPERTY_DIFF_OK`.
- Human-assisted: pass for requested compute-default in-game review; no legacy-removal decision is recorded.
- Shader: one embedded compute-shader smoke kernel and one embedded pressure-Jacobi compute kernel added inside the backend and reused for the multi-pass pressure stack; no production bake shader replacement added.
- Editor: no human-driven R7 editor workflow run; automated low-cost heartbeat comparison is recorded.
- Visual: low-cost canonical artifact review accepted for the five generated PNGs. `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` added 7 material/top-down/debug screenshots and 6 texture-space crops around obstacle/contact/tile-edge and known failure neighborhoods while keeping output replacement disabled. `R7_COMPUTE_HUMAN_VISIBLE_INGAME_REVIEW_CAPTURE_OK` records normal material, raw flow direction, flow arrows, and final flow strength contact sheets for `res://Demo_obstacle_flow_test.tscn` and `res://Demo.tscn`.
- Runtime: low-cost probes exercise existing legacy bake runtime; compute skeleton, solve/filter step, pressure-Jacobi stack, cleanup/responsiveness probe, and selection/abort probe exercise local RenderingDevice only. The requested in-game review exercises the default `canonical_compute_replacing` branch and records `output_texture_keys=["flow_foam_noise"]`.
- Performance: legacy baseline, non-replacing compute heartbeat comparison, report-only production replacement validation timing, and explicit `legacy_canvas_item` versus `canonical_compute_replacing` timing are recorded. Compute is faster in all recorded comparison cases: `1044.678 ms` vs `2510.612 ms` low-cost, `70597.861 ms` vs `71726.023 ms` obstacle Demo, and `127139.944 ms` vs `128334.516 ms` Demo; full authored scenes still have >1000 ms frame gaps in both paths.
- Manual: adversarial plan review complete.

## Important Context

- R6/R6.5 are complete and merged. R7 has bumped the active bake source signature to version 29 for the canonical compute replacement boundary.
- R7 compute-first decision is already recorded: use RenderingDevice compute and skip the throwaway SubViewport interim.
- Do not repeat the full `res://Demo.tscn` editor undo-delete check; it was infeasible due CPU/GPU saturation. Use the low-cost fixture or a targeted harness.
- RiverManager must continue owning public API, resource writing, material binding, validity flags, bake flag clearing, completion signaling, and public/property surface unless the spec is explicitly changed.
- A future compute backend should own only GPU resources, dispatch, sync/readback, and cleanup behind the baker.
- Headless runs do not prove R7 compute behavior because local/global RenderingDevice access is unavailable in headless/OpenGL.
- `barrier()` and `full_barrier()` are no-ops; `compute_list_add_barrier()` is separate and must be tested if the production pattern batches dependent dispatches inside one compute list.

## Artifact Hygiene

- Scratch folders or temporary projects created: `.codex-research/r7-api/`, `.codex-research/r7-api-docs/`, `.codex-research/r7_rd_runtime_check.gd`, `.codex-research/r7_api_introspection.gd`, `.codex-research/godot-user-r7-review/`, `.codex-research/godot-user-r7-review-headless/`, `.codex-research/godot-user-r7-api-dump/`, `.codex-research/godot-user-r7-adversarial-review/`, `.codex-research/godot-user-r7-adversarial-review-headless/`, `.codex-research/godot-user-r7/`, `.codex-research/godot-user-r7-trace-check/`, `.codex-research/godot-user-r7-parser/`, `.codex-research/godot-user-r7-format/`, `.codex-research/godot-user-r7-sync/`, `.codex-research/godot-user-r7-compute-skeleton/`, `.codex-research/godot-user-r7-surface/`, `.codex-research/godot-user-r7-compute-solve-parser/`, `.codex-research/godot-user-r7-compute-solve/`, `.codex-research/godot-user-r7-compute-solve-surface/`, `.codex-research/godot-user-r7-compute-solve-skeleton-rerun/`, `.codex-research/godot-user-r7-compute-solve-stack/`, `.codex-research/godot-user-r7-prefix-diagnostic/`, `.codex-research/godot-user-r7-prefix-diagnostic-skeleton/`, `.codex-research/godot-user-r7-prefix-diagnostic-surface/`, `.codex-research/godot-user-r7-canonical-acceptance/`, `.codex-research/godot-user-r7-canonical-acceptance-skeleton/`, `.codex-research/godot-user-r7-canonical-acceptance-surface/`, `.codex-research/godot-user-r7-compute-selection-abort/`, `.codex-research/godot-user-r7-selection-abort-surface/`, `.codex-research/godot-user-r7-representative-visuals/`, `.codex-research/godot-user-r7-generated-output-replacement-staging/`, `.codex-research/godot-user-r7-generated-output-replacement-staging-rerun/`, `.codex-research/godot-user-r7-production-replacement-validation/`, `.codex-research/godot-user-r7-production-replacement-validation-surface/`, `.codex-research/godot-user-r7-compute-selection-abort-rerun/`, `.codex-research/godot-user/`, `.codex-research/godot-user-r7-performance-compare-parser/`, `.codex-research/godot-user-r7-performance-compare/`, `.codex-research/r7_compute_human_visible_ingame_review_probe.gd`, `.codex-research/r7-baselines/legacy-smoke/`, `.codex-research/r7-baselines/legacy/`, `.codex-research/r7-baselines/format/`, `.codex-research/r7-baselines/sync/`, `.codex-research/r7-baselines/compute-skeleton/`, `.codex-research/r7-baselines/compute-solve-filter/`, `.codex-research/r7-baselines/compute-solve-stack/`, `.codex-research/r7-baselines/compute-solve-stack-next/`, `.codex-research/r7-baselines/compute-solve-stack-final/`, `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/`, `.codex-research/r7-baselines/compute-canonical-acceptance/`, `.codex-research/r7-baselines/compute-cleanup-responsiveness/`, `.codex-research/r7-baselines/compute-selection-abort/`, `.codex-research/r7-baselines/compute-representative-visuals/`, `.codex-research/r7-baselines/compute-generated-output-replacement-staging/`, `.codex-research/r7-baselines/compute-production-replacement-validation/`, `.codex-research/r7-baselines/compute-human-visible-ingame-review/`, `.codex-research/r7-baselines/compute-backend-performance-compare/`, plus the temporary repo-local Godot profile redirects `.codex-godot-appdata/` and `.codex-godot-localappdata/` from earlier validation runs.
- Additional final pre-switch scratch/report folders: `.codex-research/godot-user-r7-final-non-neutral-flow-speed/`, `.codex-research/godot-user-r7-final-saved-resource-load-smoke/`, `.codex-research/godot-user-r7-final-system-map-compatibility/`, `.codex-research/godot-user-r7-final-selection-abort/`, `.codex-research/r7-baselines/compute-non-neutral-flow-speed/`, `.codex-research/r7-baselines/compute-saved-resource-load-smoke/`, `.codex-research/r7-baselines/compute-system-map-compatibility/`, and `.codex-research/r7-baselines/compute-selection-abort-final-pre-switch/`.
- Generated bakes/resources created: `waterways_bakes/Demo/Water_River.river_bake.res` and `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res` were intentionally regenerated by the saved-output promotion probe under source signature v29. No WaterSystem bake resource changed during the backend performance comparison or final pre-switch checks. The baseline, tolerance, solve/filter, pressure-stack, prefix, cleanup/responsiveness, selection/abort, representative visual, generated-output staging, production replacement validation, promotion fixture coverage, saved-output promotion, human-visible compute review, backend performance comparison, non-neutral flow-speed, saved-resource load smoke, system-map compatibility, and final selection/abort probes also wrote reports, surface dumps, contact sheets, console logs, or PNG review artifacts under `.codex-research/`.
- Additional `FRAGCOORD` diagnostic scratch/report folders: `.codex-research/godot-user-r7-fragcoord-diagnostic/` and `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/`.
- Active files mirrored into scratch validation: none.
- Files/folders that must be excluded from packaging: `.codex-research/`.
- Files/folders safe to delete now: the R7 scratch API/runtime check outputs, repo-local Godot profiles, and `legacy-smoke` baseline listed above; key results are recorded in `research.md` and `validation.md`. Keep `.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt`, `.codex-research/r7-baselines/format/r7_texture_format_roundtrip.txt`, `.codex-research/r7-baselines/sync/r7_rendering_device_sync.txt`, `.codex-research/r7-baselines/compute-solve-filter/r7_compute_solve_filter_step.txt`, `.codex-research/r7-baselines/compute-solve-stack/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-canonical-acceptance/`, `.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`, `.codex-research/r7-baselines/compute-selection-abort/r7_compute_selection_abort.txt`, `.codex-research/r7-baselines/compute-representative-visuals/`, `.codex-research/r7-baselines/compute-generated-output-replacement-staging/r7_compute_generated_output_replacement_staging.txt`, `.codex-research/r7-baselines/compute-production-replacement-validation/r7_compute_production_replacement_validation.txt`, `.codex-research/r7-baselines/compute-backend-performance-compare/r7_compute_backend_performance_compare.txt`, `.codex-research/r7-baselines/compute-non-neutral-flow-speed/r7_compute_non_neutral_flow_speed.txt`, `.codex-research/r7-baselines/compute-saved-resource-load-smoke/r7_compute_saved_resource_load_smoke.txt`, `.codex-research/r7-baselines/compute-system-map-compatibility/`, and `.codex-research/r7-baselines/compute-selection-abort-final-pre-switch/r7_compute_selection_abort.txt` until replacement-code enablement/performance-regression/pre-switch budgets supersede them.

## Known Risks and Open Issues

- Baseline false-green risk: a tiny/mis-layered collider or fallback path can avoid the target projection workload.
- Synchronization/readback risk: delayed single-submit/wait/sync/readback is proven in the standalone probe, non-replacing skeleton, isolated pressure-Jacobi step, and pressure-Jacobi stack, but production code can still produce stale iterations if it changes resource binding, same-list dependencies, barriers, submit/sync order, or reuse patterns. Async readback is not proven.
- Texture-format risk: standalone RGBA16F/RGBA32F round-trip proof and RGBA32F pressure-stack proof passed, but production compute output still needs per-slice texture comparison against the legacy baseline.
- Editor responsiveness risk: non-replacing low-cost heartbeat is recorded, but a future replacement path can still freeze the main thread if final readback or result handoff changes.
- R6 ownership risk: compute code must not take over RiverManager responsibilities.

Relevant audit sections:

- `addons\waterways\docs\audit\waterways-code-audit-2026-06-12.md`: parent track audit context for bake performance and prior defects.

## Blockers

- Async readback is not accepted: `buffer_get_data_async()` callback did not arrive within 180 frames in the recorded probe.
- Saved-output production promotion is accepted for the two scoped Demo river bake resources. The code default backend is switched to `canonical_compute_replacing` as the accepted default solve path, and explicit `legacy_canvas_item` remains available for comparison and rollback.
- Requested compute-default human-visible in-game review, explicit backend performance comparison, and final pre-switch tests are complete. Compute solve is accepted as the switched/default path, but no legacy-removal decision is recorded. Keep both the legacy CanvasItem path and the R7 compute path available until a separate comparison/removal protocol is accepted.
- `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` is ready only with all evidence supplied. Without supplied evidence it still blocks on missing canonical/visual/selection/cleanup/surface/staging/production evidence; with production validation evidence supplied the blocker list is empty.
- Do not broaden saved-output replacement beyond the two scoped river bake resources, remove legacy, collapse backend selection, or use async readback without a separate accepted protocol.

## Files To Inspect Before Editing

- `addons/waterways/docs/spec-driven/features/river-refactor/r7/tasks.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r7/review.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r7/validation.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r7/plan.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r7/spec.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r7/research.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/roadmap.md`
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/validation.md`
- `addons/waterways/river_flowmap_baker.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/filter_renderer.gd`

## Commands or Checks Used

Latest final pre-switch commands used the windowed Godot console with repo-local `APPDATA`/`LOCALAPPDATA` profiles and wrote the following reports:

- Non-neutral compute flow-speed:
  - Probe: `res://addons/waterways/probes/r7_compute_non_neutral_flow_speed_probe.gd`
  - Output: `.codex-research/r7-baselines/compute-non-neutral-flow-speed/r7_compute_non_neutral_flow_speed.txt`
  - Marker: `R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK`
- Saved-resource load smoke:
  - Probe: `res://addons/waterways/probes/r7_compute_saved_resource_load_smoke_probe.gd`
  - Output: `.codex-research/r7-baselines/compute-saved-resource-load-smoke/r7_compute_saved_resource_load_smoke.txt`
  - Marker: `R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK`
- System-map compatibility:
  - Probes: `res://addons/waterways/probes/system_flow_compare_probe.gd -- enforce=all allow_stale=1` and `res://addons/waterways/probes/system_flow_projected_gate_probe.gd`
  - Output: `.codex-research/r7-baselines/compute-system-map-compatibility/`
  - Markers: `SYSTEM_FLOW_COMPARE_OK`, `SYSTEM_FLOW_PROJECTED_GATE_OK`
- Selection/abort cleanup rerun:
  - Probe: `res://addons/waterways/probes/r7_compute_selection_abort_probe.gd`
  - Output: `.codex-research/r7-baselines/compute-selection-abort-final-pre-switch/r7_compute_selection_abort.txt`
  - Marker: `R7_COMPUTE_SELECTION_ABORT_OK`

Latest backend performance comparison command:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$outDir = Join-Path $root ".codex-research\r7-baselines\compute-backend-performance-compare"
$godotUser = Join-Path $root ".codex-research\godot-user-r7-performance-compare"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local"), $outDir | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
$consoleOut = Join-Path $outDir "godot_console_output.txt"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_compute_backend_performance_compare_probe.gd" -- out=res://.codex-research/r7-baselines/compute-backend-performance-compare low_cost_runs=3 authored_runs=1 2>&1 | Tee-Object -FilePath $consoleOut
```

Result marker:

- `R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK`

Summary:

- Low-cost fixture: compute `1044.678 ms`, legacy `2510.612 ms`; no fallback; compute output keys `["flow_foam_noise"]`, legacy output keys `[]`.
- `res://Demo_obstacle_flow_test.tscn`: compute `70597.861 ms`, legacy `71726.023 ms`; no fallback; both paths exceeded 1000 ms max frame gap.
- `res://Demo.tscn`: compute `127139.944 ms`, legacy `128334.516 ms`; no fallback; both paths exceeded 1000 ms max frame gap.

Latest saved-output promotion command:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user-r7-saved-output-promotion"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_compute_saved_output_promotion_probe.gd" -- out=res://.codex-research/r7-baselines/compute-saved-output-promotion
```

Result marker:

- `R7_COMPUTE_SAVED_OUTPUT_PROMOTION_OK`

Latest production replacement validation command:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user-r7-production-replacement-validation"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_compute_production_replacement_validation_probe.gd" -- out=res://.codex-research/r7-baselines/compute-production-replacement-validation
```

Result marker:

- `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`

Latest pressure-stack validation command recorded in `validation.md`:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user-r7-compute-solve-stack"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd" -- out=res://.codex-research/r7-baselines/compute-solve-stack
```

Result marker:

- `R7_COMPUTE_SOLVE_FILTER_STACK_OK`

Shipped R7 baseline command recorded in `validation.md`:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user-r7"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_legacy_canvas_item_bake_trace_probe.gd" -- scene=res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn river="Water River" out=res://.codex-research/r7-baselines/legacy warmup=1 runs=5 save=false
```

Result marker:

- `R7_LEGACY_BASELINE_OK runs=5 median_ms=2493.424 out=res://.codex-research/r7-baselines/legacy`

Scratch-only checks recorded in `validation.md` include:

```powershell
& $godotConsole --path $root --script "res://.codex-research/r7_rd_runtime_check.gd"
& $godotConsole --headless --path $root --script "res://.codex-research/r7_rd_runtime_check.gd"
```

Result summary:

- Windowed Forward+/Vulkan scratch run reported local/global RenderingDevice available and candidate f16/f32 formats supported for storage/sampling/copy usage on AMD Radeon RX 6800 XT.
- Headless scratch run reported no local/global RenderingDevice, matching official docs.
- Baseline windowed run reported median 2493.424 ms, max frame gap 93.438 ms, p95 frame gap max 43.415 ms, collision coverage 407/4096 pixels, all required pass counts including 40 Jacobi passes, and RiverManager handoff true.

## Next Tasks

- [x] Add `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`.
- [x] Add `res://addons/waterways/probes/r7_legacy_canvas_item_bake_trace_probe.gd`.
- [x] Run and record `R7_LEGACY_BASELINE_OK`.
- [x] Add the end-to-end texture-format probe.
- [x] Add the RenderingDevice sync/readback stress probe.
- [x] Add the non-replacing production compute backend skeleton behind the baker.
- [x] Port one isolated solve/filter step behind the baker for comparison only.
- [x] Confirm the isolated pressure-Jacobi proof against the legacy filter shader semantics.
- [x] Expand the pressure-Jacobi proof into a non-replacing production-shaped multi-pass stack.
- [x] Add low-cost representative material/debug visual evidence for canonical compute.
- [x] Define the exact `canonical_compute_replacing` promotion gate while keeping replacement blocked.
- [x] Record report-only generated-output replacement staging without replacing generated output.
- [x] Record report-only production replacement validation without replacing generated output.
- [x] Choose source signature version 29 or backend-mode signature keying before output-changing replacement.
- [x] Deliberately enable the replacement code path behind `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`.
- [x] Add broader low-cost/Demo/obstacle promotion fixture coverage before default promotion.
- [x] Accept `canonical_compute_replacing` as the switched/default solve path while keeping `legacy_canvas_item` as explicit fallback/comparison path.
- [x] If default production promotion is accepted, deliberately rebake/regenerate saved outputs under source signature v29 and record output hash changes.
- [x] Run the requested compute-default human-visible in-game review in `res://Demo_obstacle_flow_test.tscn` and `res://Demo.tscn`.
- [x] Run explicit legacy-vs-compute backend performance comparison on the low-cost fixture, `res://Demo_obstacle_flow_test.tscn`, and `res://Demo.tscn`.
- [x] Run final pre-switch non-neutral compute flow-speed, saved-resource load smoke, stale/system-map compatibility, projected-flow system shader gate, and selection/abort cleanup checks.
- [ ] Define and run a separate explicit side-by-side legacy comparison/removal protocol before any legacy-path removal.

## Do Not Do Yet

- Do not use async readback in production before separate proof records a callback and semantic correctness.
- Do not remove the legacy CanvasItem solution or collapse the backend selector before a separate legacy-removal protocol is complete and recorded.
- Do not broaden saved production bake texture replacement beyond the accepted two river bake resources without a new protocol.
- Do not repeat the full-Demo editor undo-delete workflow.
- Do not relax `R7_TOLERANCE_V1` without recording artifact evidence and review rationale.
- Do not change RiverManager public/property surface or ownership boundary without an explicit spec update.

## Notes for the Next Agent

The baseline now proves the legacy Jacobi/projection workload R7 is supposed to improve. Keep future comparisons honest: if a compute slice can pass while skipping the occupied projection workload, stop and fix the proof before optimizing.

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

## Validation Commands

Recorded legacy baseline command:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user-r7"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_legacy_canvas_item_bake_trace_probe.gd" -- scene=res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn river="Water River" out=res://.codex-research/r7-baselines/legacy warmup=1 runs=5 save=false
```

Recorded marker:

- `R7_LEGACY_BASELINE_OK`
