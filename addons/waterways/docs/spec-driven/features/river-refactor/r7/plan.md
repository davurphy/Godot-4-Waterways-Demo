# Plan: River Refactor R7 - Compute-First Bake Performance

## Current Truth

- R7 docs gate is complete, the low-cost legacy baseline fixture/probe slice is complete, the validation-only tolerance/format plus sync/readback probes are complete, the first non-replacing production compute backend skeleton is complete, the isolated non-replacing pressure-Jacobi solve/filter compute step is complete, the non-replacing production-shaped multi-pass pressure-Jacobi stack proof is complete, the remaining solve/filter projection passes are implemented as non-replacing diagnostics, and the controlled legacy pass-6 pressure sampler/grid/scanline/y-band diagnostic, legacy correctness audit, opt-in canvas-tie/source-edge diagnostics, pass-limited pressure prefix diagnostic, automated canonical-compute acceptance gate, non-replacing cleanup/heartbeat/non-neutral flow-speed proof, explicit selection plus guarded active abort/free/scene-close cleanup proof, low-cost representative material/debug visual proof, guarded replacement-promotion gate, report-only generated-output replacement staging proof, source signature v29 policy, gated replacement branch, and refreshed production replacement validation/runtime smoke are recorded.
- Decision: compute-first. Fold R7 into feature-roadmap Phase 5 RenderingDevice compute migration and skip the SubViewport-resident interim.
- Official Godot 4.6 RenderingDevice research is recorded in `research.md`.
- Full feature-folder docs exist for R7: `spec.md`, `plan.md`, `research.md`, `validation.md`, `tasks.md`, `review.md`, and `session-handoff.md`.
- Default production compute replacement has not been promoted. The expanded projection path now proves divergence, gradient subtract, boundary tangency, final combine, and postprocess under `R7_TOLERANCE_V1` when fed the captured legacy pressure; the primary compute-pressure generated candidate remains a legacy-parity diagnostic and still fails that final generated-output gate. Path 2 is now the active direction: canonical compute pressure feedback is accepted by the automated semantic gate, the five low-cost canonical visual artifacts are accepted as an intentional visible/output change from legacy, report-only generated-output staging identifies the would-replace output, source signature v29 is active, and refreshed production replacement validation records the RiverManager handoff/timing plus a direct replacement-branch smoke with unchanged RiverManager state/hashes.
- Architecture pivot: compute pressure feedback is now the canonical solver target. Legacy CanvasItem output remains compatibility evidence, regression context, and fallback behavior, but exact CanvasItem sampler parity is no longer the final correctness oracle unless a confirming diagnostic disproves the UV-artifact hypothesis. The 2026-06-15 probe-only `FRAGCOORD` shader diagnostic supports that hypothesis: y-band legacy UV rows had 20 total X-dependent transitions, while the `FRAGCOORD` variant had 0, although it still did not select the canonical compute floor model uniformly.
- Next implementation work should decide final promotion/default-selection policy and any broader replacement fixture coverage before canonical compute becomes the normal production path. The low-cost cleanup, heartbeat, non-neutral flow-speed proof, explicit backend selection contract, guarded active abort/free/scene-close proof, representative material/debug visual proof, named replacement gate, report-only staging proof, source signature v29, and refreshed production validation proof are recorded. Do not relax `R7_TOLERANCE_V1` and do not introduce `R7_TOLERANCE_V2`. Keep the recorded delayed single-submit/wait/sync/readback path unless async readback is separately proven.

## Required Read Order

Before R7 implementation prep or code changes, read:

1. R7 dashboard: `session-handoff.md`
2. R7 active checklist: `tasks.md`
3. R7 review/risk dashboard: `review.md`
4. R7 validation setup: `validation.md`
5. R7 spec/decision: `spec.md`
6. R7 RenderingDevice research: `research.md`
7. Parent dashboard: `../session-handoff.md`
8. Parent canonical roadmap/checklist: `../roadmap.md`
9. R6 validation evidence: `../r6/validation.md`
10. R6 handoff and residual caveats: `../r6/session-handoff.md`

## Implementation Contract

1. Research current official Godot 4.6+ RenderingDevice documentation before patching code.
2. Record any implementation-relevant documentation findings in this folder's `research.md` if it is created, or in the parent `research.md`/citations index if shared.
3. Establish baseline measurements before replacing any path:
   - fixed scene or fixture path
   - bake size and relevant RiverManager settings
   - wall-clock measurement method
   - generated-texture compare outputs
   - editor responsiveness observation method
4. Preserve the R6 module boundary:
   - RiverManager owns public API, resource saving, material binding, validity flags, and completion signaling.
   - RiverFlowmapBaker owns bake orchestration.
   - A future compute backend may own GPU resources and dispatch details behind the baker.
5. Keep source signature policy explicit; R7 now uses version 29 for the canonical compute replacement boundary.

## RenderingDevice Research Constraints

- R7 compute work must be validated in a windowed Forward+ console run. Official docs say local and global RenderingDevice access return `null` in headless/OpenGL.
- Prefer a local RenderingDevice backend behind the baker. Local RD resources cannot be shared with the global RenderingDevice, so the final RiverManager boundary remains CPU readback into ordinary Godot images/textures.
- Do not call `sync()` inside every solve/filter pass. Submit compute work, wait frames where practical, and read back only at final texture/result boundaries.
- Every RD RID must have one cleanup owner and idempotent abort cleanup.
- Query and log compute limits and texture-format support before creating the production backend. Keep workgroup sizes conservative and shader bounds checks mandatory.
- Do not treat `texture_is_format_supported_for_usage()` as an end-to-end format proof. The format probe must create the production-style storage texture, dispatch a shader that writes and reads representative values, read back bytes, convert into the intended Godot `Image` format (`FORMAT_RGBAH` or `FORMAT_RGBAF`), create an `ImageTexture`, and compare decoded flow/pressure values against the tolerance metrics.
- `barrier()` and `full_barrier()` are not a correctness mechanism; the installed 4.6.3 API docs say both do nothing. Do not extend that statement to `compute_list_add_barrier(compute_list)`: it exists and raises a Vulkan compute barrier. If production batches dependent dispatches in one compute list, the design must either use `compute_list_add_barrier()` where needed or prove via the sync stress probe that separate lists/submits/resource ping-pong make it unnecessary.

## Chosen Architecture Direction

R7 should introduce a compute backend for the bake solve/filter stack rather than extending the current Viewport ping-pong approach.

Compute pressure feedback is the canonical solver target for R7. The legacy CanvasItem path stays available as a fallback and as compatibility evidence, but replacement acceptance should move to a separate canonical-compute gate once visual and semantic evidence exists.

Candidate ownership shape for later implementation:

- `river_flowmap_baker.gd`: selects and coordinates the backend, keeps existing result handoff semantics.
- Future compute backend script: owns RenderingDevice setup, GPU textures/buffers, dispatches, synchronization, readback, and cleanup.
- `river_bake_constants.gd`: remains the source of reviewable metadata/signature/settings rows.
- `filter_renderer.gd`: remains the legacy canvas-item path until compute coverage can replace or bypass it safely.

## Canonical Compute Acceptance Path

Do not rename or loosen `R7_TOLERANCE_V1`, and do not add `R7_TOLERANCE_V2`. The new acceptance path is `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.

Canonical solver rules:

- Integer texel addressing: compute shaders address output texels from `gl_GlobalInvocationID`/`ivec2` coordinates and derive neighbor coordinates in texel space. The solver must not encode CanvasItem interpolated-`UV` triangle artifacts, simple diagonal tie rules, source-edge tie rules, or nearest half-texel quirks as production behavior.
- Atlas column walls: X-neighbor reads that leave the current atlas column, including the established 2% padding-wall band, use the center pressure as the Neumann wall value. Cross-column bleed is invalid.
- Solid-cell pressure preservation: solid output cells preserve center pressure. Solid pressure neighbors also return center pressure.
- Y clamp behavior: Y neighbors clamp to valid texel rows/open continuation margins and do not become atlas walls merely because they clamp at the texture edge.
- Occupancy/solid neighbor behavior: `water_occupancy.r > 0.5` is solid. Velocity/divergence consumers must keep occupied/solid reads semantically consistent with the legacy solve, and boundary tangency must keep using the proximity/ring channel intentionally.
- Texture formats: pressure feedback uses RGBA32F storage textures for canonical pressure ping-pong unless a later semantic proof justifies narrower precision. Projection/final candidate textures may use RGBA16F where the existing format probe and canonical gates pass. Preserve RGBA8 sampled source inputs when the legacy source image is RGBA8.
- Final packing/postprocess: final flow vectors, pressure, foam, noise, distance, and class channels keep the existing packed channel meanings and run through the existing baker postprocess/final combine path unless a separate spec update changes them. Non-migrated textures must remain byte-identical.

Replacement staging:

- The first accepted compute path remains behind explicit `flowmap_backend_mode` selection until full production validation passes. The current selection contract keeps legacy CanvasItem as the generated-output default/fallback, treats canonical compute as non-replacing report-only, and leaves unpromoted replacing compute falling back to legacy output. The low-cost artifact review accepts the canonical output direction, not production output replacement.
- Report-only staging is recorded by `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`: the would-replace generated output key is `flow_foam_noise`, with canonical compute providing `flow_foam_noise.rg`; `flow_foam_noise.ba` plus `dist_pressure`, `obstacle_features`, `terrain_contact_features`, `bank_response_features`, and `water_occupancy` remain legacy-sourced. The low-cost staged `flow_foam_noise` hash changes from `3bfadac449d094f0bd603f8549f8de9e` to `a5ee9d4f0e7585ca1dc67d3c72c26a49`, but the live RiverManager texture hashes and state remain unchanged.
- Production replacement validation is recorded by refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`: RiverManager would receive `flow_foam_noise_texture` from the canonical candidate and the five remaining generated texture fields from legacy output. The report records `elapsed_ms=228.019`, `max_frame_gap_ms=145.067`, one submit/sync after three waited frames, `production_output_replaced=false`, empty actual `output_texture_keys`, unchanged live RiverManager state/hashes, preserved public surface, and a direct baker runtime smoke with `output_texture_keys=["flow_foam_noise"]`.
- RiverManager ownership stays unchanged: no RiverManager texture/resource writes from compute code, and RiverManager continues to own generated resources, material binding, validity flags, completion signaling, and the public API.
- Signature/version decision: source signature policy is accepted as `RIVER_BAKE_SOURCE_SIGNATURE_VERSION=29`; backend mode remains outside the source signature.
- Promotion gate: `canonical_compute_replacing` may select generated compute output only when `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` is ready. The exact gate requires `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`, `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`, `R7_COMPUTE_SELECTION_ABORT_OK`, `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`, `R7_R6_SURFACE_PROPERTY_DIFF_OK`, accepted generated-output replacement staging, accepted production replacement validation, either source signature version 29 or backend mode in the source signature, and an enabled replacement code path.
- Current gate state with staging and production validation evidence supplied: `stage=ready_for_replacement`, `ready=true`, `replacement_ready=true`, blockers empty. Without supplied evidence, the selector still reports missing evidence blockers and defaults/falls back to legacy.

Visual validation required for `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`:

- Low-cost R7 fixture: `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`, including a top-down/debug view and a material-rendered view. Current status: the five raw canonical PNG artifacts from this fixture are accepted, and `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` records 7 material/top-down/debug screenshots plus 6 obstacle/contact/tile-edge/known-failure texture-space crops with output replacement disabled.
- Full Demo or representative scene: `res://Demo.tscn` or a smaller named scene with comparable river bends, contacts, and obstacles.
- Obstacle/contact/tile-edge evidence: named camera/view plus screenshots or rendered output covering obstacle contact, atlas tile edges, and the known `(82, 47)`, `(61, 67)`, and tile-5 `(42, 63)` failure neighborhoods where practical. Current low-cost status: covered by `r7_compute_representative_visual_probe.gd`; broader scene coverage can still be added before or during replacement staging if desired.
- Non-neutral flow-speed evidence before the flow-speed path is migrated: a named fixture/run where `flow_speed_scale` executes and its generated texture impact is reviewed. Current status: the low-cost non-neutral legacy run is recorded in `.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`; compute migration/replacement for flow-speed effects still needs the usual replacement gates if output changes.

Physics/semantic validation required:

- Divergence reduction improves or stays within a documented bound versus the pre-projection flow.
- No boundary penetration artifacts at solids, atlas walls, or contact edges.
- No NaNs, invalid pressure values, unreadable images, or unstable rerun/self-compare output.
- Occupied flow vectors remain reasonable by magnitude, endpoint delta, and direction buckets.
- Foam, noise, distance, pressure, occupancy, and feature channels do not change accidentally outside the migrated solve/filter scope.

Legacy parity reports remain diagnostics:

- Continue reporting p95/p99/max differences, occupied-channel deltas, top angle records, and known failure targets against legacy.
- A legacy parity failure no longer blocks replacement if `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` visual and semantic gates pass, the output change is documented, fallback selection exists, and the review explicitly accepts the change.
- Current review explicitly accepts the low-cost artifact output change from legacy, the report-only generated-output staging plan, source signature v29, and the refreshed production replacement validation/runtime smoke. Default production promotion remains open.

## Fixed Low-Cost Baseline Fixture

This fixture/probe was created as the first R7 implementation slice, before changing the bake backend:

- Scene path: `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`
- Main probe path: `res://addons/waterways/probes/r7_bake_baseline_probe.gd`
- Fixture root: `Node3D` named `R7LowCostBakeFixture`
- River node: `RiverManager` named `Water River`
- Obstacle node: at least one `StaticBody3D` with a `BoxShape3D` on collision layer 1, placed through the river midsection and sized so the collision map has nonzero but not full coverage. Avoid a "tiny" collider that may fall between 64x64 UV2 samples.
- River curve: 3 or 4 short points with a mild bend, widths around `1.0`, neutral `flow_speeds`.
- Bake settings: `baking_resolution = 0` (64x64), `baking_raycast_layers = 1`, `shape_step_length_divs = 1`, `shape_step_width_divs = 1`, default `downstream_baseline_collision_support`, default projection strides `[32, 16, 8, 4, 2, 1, 1, 1]`, 5 iterations per stride, 2 tangency passes.
- Flow-speed scaling caveat: neutral `flow_speeds` intentionally skip `flow_speed_scale`. The baseline probe must assert `flow_speed_scaled=false` and `flow_speed_scale` pass count `0`. If any R7 slice migrates `flow_speed_scale`, add a separate non-neutral run first and require `flow_speed_scale` pass count `1`.
- Required exercised path proof: collision support filters, water occupancy, obstacle feature mask, flow divergence, 40 Jacobi pass executions, projected flow, boundary tangency, foam, final combines, diagnostics/postprocess, and RiverManager result handoff. The baseline probe must fail if this proof is missing; a fast bake that falls back to curve support is not a valid R7 baseline.
- Required metadata/texture assertions: `collision_hit_pixel_count > 0`, `collision_hit_pixel_count < collision_total_pixel_count`, `support_fallback_applied=false`, empty `support_fallback_reason`, `collision_support_filters_ran=true`, `water_occupancy_baked=true`, `obstacle_avoidance_applied=true`, `flow_projected=true`, all generated textures present, `water_occupancy` has solid/proximity coverage, `obstacle_features` is not all neutral, and occupied flow diagnostics sample at least one texel.
- Required progress/pass assertions: observe the current public stride labels `Projecting flow 0/40`, `5/40`, `10/40`, `15/40`, `20/40`, `25/40`, `30/40`, and `35/40`. Current code emits those eight public labels, not forty labels; the probe must separately prove `jacobi_pass_count=40` from an internal pass trace or equivalent instrumentation before accepting the baseline.
- Required pass trace shape: collect the trace through a low-distortion hook such as an additive pass callback or wrapper around `RiverFlowmapBaker._run_renderer_pass()` and, where useful, `FilterRenderer._run_pass()`. Do not change public progress semantics to make the trace easier.

Expected top-level baker labels for the default neutral-flow fixture:

| Baker pass label | Expected count |
| --- | ---: |
| `bank response feature mask` | 1 |
| `flow pressure` | 1 |
| `blurred flow pressure` | 1 |
| `dilated collision map` | 1 |
| `normal map` | 1 |
| `occupancy proximity field` | 1 |
| `water occupancy mask` | 1 |
| `obstacle feature mask` | 1 |
| `flow divergence map` | 1 |
| `flow pressure jacobi pass` | 40 |
| `projected flow map` | 1 |
| `boundary tangency flow map` | 2 |
| `foam map` | 1 |
| `blurred foam map` | 1 |
| `combined flow/foam/noise map` | 1 |
| `combined distance/pressure map` | 1 |

The fixture should also fail if `collision_probe_skipped=true`, if `support_fallback_reason` is `curve_only`, `baking_raycast_layers_zero`, or `no_collision_hits`, or if collision coverage is too small to prove the 64x64 workload. Initial gate: at least 32 hit pixels and less than 70% of the collision map covered; adjust the collider before relaxing those numbers.
- Non-goal for this fixture: terrain, hterrain, full Demo visuals, or saved shipped bake resources.

Use the full `res://Demo.tscn` only as an optional later comparison after the low-cost fixture is green. Do not use it for editor undo-delete closure.

## Baseline Timing Method

The baseline probe should run under the repo-local Godot profile and should not save generated resources in place.

- Recorded command shape:
  - `$godotConsole --path $root --script res://addons/waterways/probes/r7_bake_baseline_probe.gd -- scene=res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn river="Water River" out=res://.codex-research/r7-baselines/legacy warmup=1 runs=5 save=false`
- Measurement window: `Time.get_ticks_usec()` immediately before `river.bake_texture()` through the `progress_notified` message `finished`.
- Record for each run: total elapsed ms, public progress-label timings, internal pass counts, collision/occupancy/obstacle-feature proof fields, frame count while baking, max and p95 process-frame gap, generated texture size/format/hash, `flow_projected`, Godot version, rendering method/driver, adapter name/type/vendor, and relevant RD limits if available.
- Baseline statistic: median elapsed ms from the 5 measured runs after one discarded warmup. Preserve all raw run lines because later changes compare both median and worst-frame behavior.
- Recorded legacy result: `R7_LEGACY_BASELINE_OK runs=5 median_ms=2493.424 out=res://.codex-research/r7-baselines/legacy`; max frame gap 93.438 ms and max p95 frame gap 43.415 ms.

## Generated Texture Comparison Tolerance

Use `R7_TOLERANCE_V1` for the first compute comparisons, but treat it as provisional until the legacy baseline records self-compare noise, per-texture/channel distributions, and an f16 round-trip or format-conversion probe:

| Texture scope | Required comparison |
| --- | --- |
| Textures not produced by the migrated compute slice | Byte-identical to the legacy baseline. |
| Textures produced by compute | Same presence, size, and channel semantics; compare whole image and occupied atlas content separately. |
| Generic per-channel tolerance | `max_abs <= 0.02`, `p99_abs <= 0.006`, and `mean_abs <= 0.0015` for normalized channels. |
| Decoded flow vectors in `flow_foam_noise` | For occupied texels with magnitude >= 0.05: `p95_angle <= 2 deg`, `max_angle <= 10 deg`, and `p95_magnitude_delta <= 0.03`. |
| Binary/class masks | Do not rely only on generic channel thresholds; report class-count/coverage deltas for solid occupancy, proximity rings, and obstacle-feature non-neutral texels. |
| Metadata/signature/settings | Signature version remains 28; source signature and bake settings unchanged unless the spec is updated first. |

Any threshold relaxation is a review event: record the artifact, diff metrics, affected texture/channel, and visual/manual rationale before accepting it.

## Synchronization And Readback Validation

Before the compute backend replaces the legacy path, the small RenderingDevice stress probe was added and recorded:

- Path: `res://addons/waterways/probes/r7_rendering_device_sync_probe.gd`
- Run windowed, not headless.
- Create a local RenderingDevice and skip with a clear marker if it is unavailable.
- Dispatch a deterministic ping-pong shader over storage textures or storage buffers for more iterations than the frame queue size.
- Include subcases for stale binding mistakes, intra-list dependent dispatches with and without `compute_list_add_barrier()` where applicable, delayed async readback, repeated-run/resource-reuse, and final readback after delayed `submit()`/`sync()`.
- Read back only after the selected production sync/readback path for the production-path subcase.
- Repeat enough times with distinct seeds to catch stale binding/order bugs; recorded marker: `R7_RENDERING_DEVICE_SYNC_OK`.
- Include a cleanup/abort subcase proving repeated abort and resource-free calls leave no owned RIDs.

Recorded result: the probe ran with `iterations=97` and `repeats=20`, using a delayed single-submit/wait-3-frames/sync/readback pattern. The `compute_list_add_barrier()` intra-list dependent-dispatch subcase matched expected values; the no-barrier report-only variant did not. `buffer_get_data_async()` was attempted but did not call back within 180 frames, so async readback is not selected for production.

The production backend should not rely on `barrier()` or `full_barrier()` calls as its correctness story. Correctness comes from ping-pong resource ownership, list/submit/readback order, needed `compute_list_add_barrier()` calls inside dependent compute lists, and the stress probe.

## Editor Responsiveness Check

R7 editor responsiveness is measured with the low-cost fixture:

- The baseline/performance probe should record a heartbeat during bake: process-frame gaps and total frames while the bake is active.
- Future compute acceptance should be no worse than the recorded legacy heartbeat budget unless a deliberate trade-off is documented. As an initial hard stop, no single fixture frame gap should exceed 1000 ms.
- If human-visible review is needed, use the low-cost fixture with repeated fixture bakes or a targeted harness. Do not repeat the full `res://Demo.tscn` undo-delete check.

Recorded non-replacing comparison: refreshed `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK` captured neutral legacy max frame gap `81.209 ms`, non-neutral legacy max `85.307 ms`, and canonical non-replacing compute projection max `142.179 ms`, all below the 1000 ms hard stop. This proves the current report-only compute harness heartbeat, not final production replacement timing.

## Future Implementation Slices

Docs gate, research, and slice 1 are complete. Continue in this order:

1. Complete: add the low-cost deterministic bake fixture and baseline probe, then record the legacy baseline. No compute backend replacement was started before this baseline existed.
2. Complete: add tolerance compare mode plus RD format/limit/sync stress probes. This used compute only as standalone probes, not as bake replacement, and recorded `R7_TOLERANCE_SELF_COMPARE_OK`, `R7_TEXTURE_FORMAT_ROUNDTRIP_OK`, and `R7_RENDERING_DEVICE_SYNC_OK`.
3. Complete for the low-cost fixture: baseline legacy path output, timing, heartbeat, dictionaries, RiverManager result handoff, legacy self/rerun tolerance evidence, and standalone RD format/sync evidence with current R6.5/R7 baseline code. Add public-surface reruns when production code changes.
4. Complete: prototype local RenderingDevice setup, format/limit probing, delayed single-submit/wait/sync/readback, and cleanup without changing generated output. Recorded marker: `R7_COMPUTE_BACKEND_SKELETON_OK`.
5. Complete: port one isolated pressure-Jacobi solve/filter step behind the baker for comparison only. Recorded marker: `R7_COMPUTE_SOLVE_FILTER_STEP_OK`; the compute result matches a deterministic legacy-UV CPU reference, a one-step `flow_pressure_jacobi_pass.gdshader` intermediate matches that same reference within f16-sized tolerance, and all legacy RiverManager texture IDs/hashes stay unchanged.
6. Complete: expand the isolated pressure-Jacobi proof into a production-shaped non-replacing multi-pass stack. Recorded marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK`; the stack uses RGBA32F ping-pong pressure textures, the real stride/iteration schedule `[32, 16, 8, 4, 2, 1, 1, 1]` with 5 iterations per stride, 40 dispatches in one compute list, 39 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, a legacy shader multi-pass intermediate comparison, and unchanged RiverManager texture IDs/hashes. This uses `R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1` only for the pressure intermediate and does not relax final generated texture `R7_TOLERANCE_V1`.
7. Complete as diagnostic: add divergence, gradient subtract, and boundary tangency compute passes around the proven pressure stack. The expanded path records 44 dispatches, 43 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, and no generated output replacement. The legacy-pressure diagnostic passes `R7_TOLERANCE_V1` through final combine/postprocess, proving the outer passes and candidate assembly.
8. Complete as diagnostic: instrument actual legacy pass-6 pressure sampler behavior. The controlled `FilterRenderer.apply_flow_pressure_jacobi` pass records `stride=16`, `source_size=64`, `texture=106x106`, `atlas_columns=5`, vertical offset `26.5` texels, lower/upper split `3/2` for both up and down samples, current compute floor-model matches of `1/5` up and `2/5` down, exact horizontal atlas-wall center reads, and a 25-point grid where compute floor-model matches only `10/25` up and `9/25` down.
9. Complete as audit: separate legacy correctness from replacement compatibility. The legacy shader intent is coherent, the mixed half-texel sampler behavior is artifact-shaped with unproven visual consequence, and the simple ColorRect diagonal model is not safe enough to hard-code because it matches only `22/25` in each direction. Legacy output remains compatibility/fallback evidence and a diagnostic report target.
10. Complete as diagnostic: run an opt-in diagonal canvas-tie candidate. It improves generated p95 angle to `3.02500924801543 deg` and weighted mean to `0.60170081393187 deg`, but worsens p99/max angle to `5.96108559105589/18.2393832633789 deg`, so it remains report-only.
11. Complete as diagnostic: run dense pass-6 scanline/y-band sampler probes and an opt-in source-edge candidate. The source-edge model exactly fits the controlled sampler tables, but generated p99/max/channel gates still fail (`p99=5.71058370749061 deg`, max `18.2393832633789 deg`), so it remains report-only.
12. Complete as diagnostic: add pass-limited pressure prefix comparisons for modes 0/1/2. The diagnostic records pass counts `[5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]`, proves pass 5 is clean, localizes primary broad drift to pass 6-10 at stride 16, and shows mode 2 shifts the remaining generated-output tail to `(61, 67)` and tile 5 `(42, 63)`.
13. Partial visual acceptance: implement the canonical-compute acceptance slice. The current primary candidate remains report-only and fails legacy `R7_TOLERANCE_V1` because accumulated pressure feedback still drifts enough to produce generated flow p95 angle `3.48932145236808 deg` and max angle `12.4395520353247 deg`, but exact legacy CanvasItem sampler parity is no longer the final oracle. `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK` is recorded with canonical texel-space RGBA32F pressure feedback, semantic/divergence/ownership/integrity gates, continued legacy parity diagnostics, and five visual artifacts. The five artifacts are accepted as an intentional visible/output change from legacy for the low-cost canonical path. `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` records low-cost material/top-down/debug screenshots and known-neighborhood crops with only a temporary material binding. Refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` records source signature v29, report-only production handoff, and direct runtime replacement smoke; final default promotion remains open.
14. Move diagnostics that currently scan pixels on CPU to GPU reductions or opt-in debug-only actions after probe consumers are migrated.
15. Complete for non-replacing low-cost coverage: add editor responsiveness, cancellation cleanup, and non-neutral flow-speed evidence. Recorded marker: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`; the cancelled compute run reaches compiled resources and sampler setup, then reports zero owned RIDs, released local RenderingDevice, no unsynced submit state, no output texture keys, and `production_output_replaced=false`; the non-neutral flow-speed run records pass count `1` and a changed `flow_foam_noise` hash.
16. Complete for guarded non-replacing replacement-path coverage: add explicit backend selection/config and active abort/free/scene-close cleanup proof. Recorded marker: `R7_COMPUTE_SELECTION_ABORT_OK`; legacy CanvasItem remains the generated-output default/fallback, report-only canonical compute remains non-replacing, missing-evidence replacing compute falls back to legacy, source signature version is 29, and interrupted direct abort/owner-free/scene-close runs return clean cancelled reports with zero owned RIDs, released local RenderingDevice, no unsynced submit state, empty output texture keys, and `production_output_replaced=false`.
17. Complete for low-cost representative coverage: add material/debug visual evidence before generated-output replacement staging. Recorded marker: `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`; generated output remains unreplaced.
18. Complete for report-only replacement staging: record which generated outputs `canonical_compute_replacing` would replace without changing production output. Recorded marker: `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`; only `flow_foam_noise.rg` is staged from canonical compute, `flow_foam_noise.ba` and the other generated textures remain legacy-sourced, RiverManager state/hashes stay unchanged, source signature is 29, and staging alone still falls back to legacy until production validation evidence is supplied.
19. Complete for production validation and replacement branch smoke. Recorded marker: refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`; it proves replacement handoff behavior, timing/responsiveness, RiverManager ownership/public surface, output texture keys, before/after hashes, legacy-sourced texture/channel split, empty supplied-evidence gate blockers, and direct runtime branch execution while leaving live RiverManager output unchanged.
20. Next: decide final promotion/default-selection policy and broader fixture coverage before making canonical compute the normal production path.

## Validation Strategy

- Generated texture comparison uses tolerance, not byte identity, because the compute path intentionally avoids legacy per-pass CPU readback quantization.
- Canonical metadata/signature/settings dictionaries should stay unchanged unless the bake-data contract changes.
- RiverManager public API, signal list, and inspector property-list checks remain part of the guard.
- Performance validation records wall-clock before/after and keeps that number as the regression budget.
- Editor validation uses a lower-cost fixture or targeted harness, not the full-Demo undo-delete workflow that was infeasible during R6.

## Risks

- Compute format mismatch can create subtle f16/f32 or normalized-texture differences.
- GPU synchronization mistakes can replace the old Defect-6 viewport-ordering hazard with a compute-dispatch/readback hazard.
- Backend cleanup must handle mid-bake aborts without leaked GPU resources or stuck bake flags.
- Moving diagnostics can break probes if marker text or report fields disappear without coordinated validation updates. Known consumers include `r6_mid_bake_timing_probe.gd` for `Projecting flow`, R6 warning/postprocess validation records for warning text, and public wrapper markers `RIVER_DATA_TEXTURE_TEST` / `FILTER_RENDERER_TEST`; grep active probes/docs again immediately before any R7.4 diagnostic move.
- Headless validation will falsely skip compute. R7 compute probes must run windowed and report renderer/device context.
