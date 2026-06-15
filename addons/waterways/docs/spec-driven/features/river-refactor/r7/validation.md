# Validation: River Refactor R7 - Compute-First Bake Performance

## Current Validation Snapshot

- Status: non-replacing R7 production-shaped pressure-Jacobi stack proof, expanded projection-pass diagnostic, controlled legacy pass-6 pressure sampler grid/scanline/y-band diagnostics, legacy pressure-feedback correctness audit, probe-only canvas-tie/source-edge pressure diagnostics, pass-limited pressure prefix localization diagnostic, probe-only `FRAGCOORD` diagnostic, `R7_TOLERANCE_V1` gate audit, the automated `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` gate, the low-cost canonical artifact visual review, the low-cost non-replacing cleanup/heartbeat/non-neutral flow-speed proof, explicit backend selection plus guarded active abort/free/scene-close cleanup proof, low-cost representative material/debug visual proof, the guarded `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` promotion gate, report-only generated-output replacement staging, source signature v29 policy, gated canonical compute replacement code path, and refreshed production replacement validation are complete; refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`, refreshed `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`, `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`, refreshed `R7_COMPUTE_SELECTION_ABORT_OK`, `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`, `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`, `R7_COMPUTE_SOLVE_FILTER_STACK_OK`, `R7_COMPUTE_BACKEND_SKELETON_OK`, and refreshed `R7_R6_SURFACE_PROPERTY_DIFF_OK` are recorded.
- Decision validated by documentation review only: choose compute-first RenderingDevice migration and skip the SubViewport-resident interim.
- Official Godot 4.6 RenderingDevice research has been recorded in `research.md`.
- Full feature-folder template docs now exist for R7, including `tasks.md`, `review.md`, and `session-handoff.md`.
- Fixed low-cost fixture/probe and legacy timing/heartbeat/pass-trace baseline are recorded below. Tolerance/self-compare, end-to-end texture-format round-trip, RenderingDevice sync/readback stress probes, the non-replacing compute backend skeleton, the isolated pressure-Jacobi compute step, the production-shaped pressure-Jacobi stack proof, the expanded divergence/gradient/tangency projection diagnostic, the pressure-feedback retry, the controlled pass-6 legacy sampler grid/scanline/y-band diagnostics, the legacy correctness grid diagnostic, the opt-in canvas-tie/source-edge diagnostic candidates, supplemental decoded-flow gate-audit metrics, pass-limited pressure prefix diagnostics, the probe-only `FRAGCOORD` diagnostic, the automated canonical compute acceptance gate, the low-cost canonical artifact visual review, the non-replacing cleanup/heartbeat/non-neutral flow-speed proof, the explicit selection plus guarded active abort/free/scene-close cleanup proof, the low-cost representative material/debug visual proof, the report-only generated-output replacement staging proof, source signature v29, and the refreshed production replacement validation/runtime smoke proof are now recorded. These proofs do not replace checked-in/generated production output. Architecture decision: compute pressure feedback is now the canonical solver target; legacy CanvasItem parity remains compatibility evidence and fallback behavior, not the final correctness oracle once `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` passes.
- R6.5 remains the latest broad code validation; the R7 skeleton, solve/filter step, pressure stack, expanded projection diagnostic, canonical acceptance slice, and production validation slice reran the R6 surface/property guard and recorded `R7_R6_SURFACE_PROPERTY_DIFF_OK`.

## Required Read Order

Before R7 implementation prep or code changes, read:

1. R7 dashboard: `session-handoff.md`
2. R7 active checklist: `tasks.md`
3. R7 review/risk dashboard: `review.md`
4. R7 implementation contract: `plan.md`
5. R7 spec/decision: `spec.md`
6. R7 RenderingDevice research: `research.md`
7. Parent dashboard: `../session-handoff.md`
8. Parent canonical roadmap/checklist: `../roadmap.md`
9. R6 validation evidence: `../r6/validation.md`
10. R6 handoff and residual caveats: `../r6/session-handoff.md`

## Validation Matrix

| Concern | Check | Type | Expected | Status |
| --- | --- | --- | --- | --- |
| Docs gate | R7 full feature-folder docs exist; parent docs record compute-first decision | Documentation | No R7 code starts before docs exist | Pass - `spec.md`, `plan.md`, `research.md`, `validation.md`, `tasks.md`, `review.md`, and `session-handoff.md` exist; parent docs point to compute-first R7 implementation prep |
| R7.1 research | Official Godot 4.6 RenderingDevice docs reviewed and installed 4.6.3 API/runtime spot-checked | Documentation + scratch runtime check | Research notes identify renderer/headless limits, sync/readback risks, RID cleanup, format support, barrier nuance, and local-RD boundary | Pass - recorded in `research.md`; shipped baseline covered separately below |
| Legacy baseline | Fixed fixture wall-clock, generated textures, dictionaries, API/signal/property surface | Windowed Godot console for bake; headless OK for surface dumps | Baseline recorded before compute patch | Pass - `R7_LEGACY_BASELINE_OK`; 1 warmup + 5 measured runs, median 2493.424 ms, max frame gap 93.438 ms, pass trace and metadata proof recorded in `.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt` |
| Tolerance and format proof | Legacy fixture self/rerun compare plus RD texture format round-trip | Windowed Godot console | `R7_TOLERANCE_SELF_COMPARE_OK` and `R7_TEXTURE_FORMAT_ROUNDTRIP_OK`; per-texture/channel, occupied-atlas, decoded flow, class-mask, Image/ImageTexture, and shader imageLoad metrics recorded | Pass - `.codex-research/r7-baselines/format/r7_texture_format_roundtrip.txt` |
| Non-replacing compute backend skeleton | Baker-owned local RenderingDevice backend setup, format/limit preflight, single-submit/wait/sync/readback, cleanup, and no-output-replacement guard | Windowed Godot console plus headless surface dump | `R7_COMPUTE_BACKEND_SKELETON_OK`; `R7_R6_SURFACE_PROPERTY_DIFF_OK`; no RiverManager texture state changes | Pass - `.codex-research/r7-baselines/compute-skeleton/r7_compute_backend_skeleton.txt`; surface dump matched `post-r6-final` with public method/signal line numbers normalized |
| Isolated solve/filter compute step | Baker-owned local RenderingDevice pressure-Jacobi compute step compared to a deterministic legacy-UV CPU reference and one `flow_pressure_jacobi_pass.gdshader` legacy intermediate, with legacy RiverManager texture hashes unchanged | Windowed Godot console plus headless surface dump | `R7_COMPUTE_SOLVE_FILTER_STEP_OK`; `R7_R6_SURFACE_PROPERTY_DIFF_OK`; no generated bake output replacement | Pass - `.codex-research/r7-baselines/compute-solve-filter/r7_compute_solve_filter_step.txt`; compute encoded max delta `0.0000000478363`, compute pressure max delta `0.00000153076173`, legacy shader encoded max delta `0.000486875`, legacy shader pressure max delta `0.01558`, legacy texture hashes unchanged |
| Pressure-Jacobi stack compute proof | Baker-owned local RenderingDevice multi-pass pressure stack using ping-pong RGBA32F pressure textures, the real stride/iteration schedule, intra-list barriers, deterministic CPU diagnostics, and a legacy shader multi-pass intermediate comparison, with legacy RiverManager texture hashes unchanged | Windowed Godot console plus headless surface dump | `R7_COMPUTE_SOLVE_FILTER_STACK_OK`; `R7_R6_SURFACE_PROPERTY_DIFF_OK`; no generated bake output replacement | Pass - `.codex-research/r7-baselines/compute-solve-stack/r7_compute_solve_filter_stack.txt`; 40 dispatches, one compute list, 39 `compute_list_add_barrier()` calls, one submit/sync/readback, stack parity `ok=true`, encoded max delta `0.03020256757736`, encoded p99 delta `0.02548497915268`, pressure max delta `0.96648216247559`, pressure p99 delta `0.81551933288574`, legacy texture hashes unchanged |
| Expanded projection diagnostic | Baker-owned local RenderingDevice divergence -> pressure stack -> gradient subtract -> two boundary tangency passes, final combine, bake-image postprocess, controlled pass-6 legacy sampler capture, opt-in canvas-tie/source-edge diagnostic candidates, decoded-flow gate-audit metrics, pass-limited pressure prefix diagnostics, and probe-only `FRAGCOORD` sampler diagnostic, still non-replacing | Windowed Godot console plus skeleton/surface reruns | Outer passes and final candidate assembly proveable under `R7_TOLERANCE_V1`; legacy parity reports stay diagnostic; no output replacement during the planning slice | Partial/pass split - latest diagnostic `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt`; primary compute-pressure generated candidate still fails legacy parity (`p95_angle=3.48932145236808 deg`, `p99_angle=5.48129340327964 deg`, `max_angle=12.4395520353247 deg`, occupied G p99 `0.00784313678741`, occupied R p99 `0.00392159819603`). The `FRAGCOORD` variant supports the UV-artifact hypothesis: legacy UV y-band rows had 20 X-dependent transitions; `FRAGCOORD` had 0. Both canvas-tie modes remain diagnostic only. The legacy-pressure diagnostic passes intermediate projection and generated `flow_foam_noise` (`p95_angle=0`, `p99_angle=0`, `max_angle=0`, occupied R/G p99 `0`). |
| Canonical compute acceptance | `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`: canonical texel-space pressure feedback, visual evidence, semantic/physics evidence, fallback selection, RiverManager ownership guard, and bake signature/version decision | Windowed Godot console plus rendered screenshots/evidence | Intentional compute-vs-legacy output change accepted only when canonical visual/semantic gates pass; do not relax `R7_TOLERANCE_V1` or create `R7_TOLERANCE_V2` | Partial visual/staging/production-validation acceptance - `.codex-research/r7-baselines/compute-canonical-acceptance/r7_compute_solve_filter_stack.txt` recorded `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK`, RGBA32F pressure feedback, canonical integer texel addressing, semantic/divergence/ownership/integrity gates passing, and 5 review artifacts. The five low-cost artifacts were visually accepted as an intentional output change from legacy. `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK` records the would-replace map without changing production output. Refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` records report-only handoff, timing, source signature v29, supplied-evidence gate readiness, direct baker replacement-path smoke, and unchanged live RiverManager output. Full promotion/default-selection remains incomplete. |
| Compute correctness | Compare future full compute output through both legacy diagnostics and `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` | Windowed Godot console | Legacy p95/p99/max/channel metrics reported; canonical visual/semantic gates decide intentional output differences | Partial - one isolated Jacobi step, the full pressure-Jacobi intermediate stack, and the divergence/gradient/tangency outer passes have non-replacing proof. Legacy primary compute-pressure parity still fails, but replacement target has pivoted to canonical compute acceptance. |
| Synchronization | Dispatch/readback ordering stress test | Windowed Godot console | No stale readback or out-of-order iteration result | Pass - `R7_RENDERING_DEVICE_SYNC_OK`; delayed single-submit/wait/sync/readback path proven; async callback did not arrive and is not selected |
| Cleanup/abort and replacement gate | Mid-bake abort/free/scene-close coverage for compute resources; `canonical_compute_replacing` promotion gate | Targeted editor harness or low-cost fixture | No leaked GPU resources, stuck flags, orphan work, or unguarded compute output replacement | Pass for guarded replacement path - `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK` cancels after compiled resources and sampler setup; refreshed `R7_COMPUTE_SELECTION_ABORT_OK` interrupts in-flight canonical projection after submit through direct baker abort, owner free, and scene close. `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK` stages the generated output map. Refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` proves supplied-evidence `canonical_compute_replacing` selects compute, reports only `flow_foam_noise`, and leaves RiverManager state/hashes unchanged in the direct runtime smoke. Default production remains legacy. |
| Performance | Wall-clock before/after on fixed scene/fixture | Timed windowed Godot run | Improvement recorded as future regression budget | Partial/pass for replacement validation - legacy baseline recorded, non-replacing compute projection comparison recorded, and refreshed production validation recorded `elapsed_ms=228.019` with legacy fixture bake `2571.256 ms`; the direct runtime smoke exercises the replacement branch but does not promote default production output. |
| Editor responsiveness | Process-frame heartbeat during fixture bake; optional low-cost human review | Windowed Godot console/human-assisted | No single low-cost fixture frame gap above 1000 ms; compute no worse than baseline budget unless documented | Pass for low-cost comparison - neutral legacy max frame gap `81.209 ms`, non-neutral legacy max `85.307 ms`, canonical compute projection max `142.179 ms`; refreshed production validation max frame gap `145.067 ms`; all below the 1000 ms hard stop |
| Non-neutral flow-speed | Explicit low-cost run where `flow speed scale map` executes before migrating that path | Windowed Godot console | Neutral flow skips speed-scale; non-neutral flow runs it once and changes generated flow texture | Pass - `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`; neutral `flow_speed_scaled=false` and pass count `0`, non-neutral `flow_speed_scaled=true` and pass count `1`, `flow_foam_noise` hash changes `3bfadac449d094f0bd603f8549f8de9e -> 66af6fbcab99aef2813cbd96c13ca733` |
| Public surface | R6.5 surface/property guard | Headless/resource dump | RiverManager public API/signals/property list unchanged unless spec approves | Pass for latest production validation guard - `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-production-replacement-validation surface_line_numbers=normalized` |

## Fixed Low-Cost Baseline Fixture

The R7 baseline fixture is implemented and validated:

- Scene path: `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`
- Probe path: `res://addons/waterways/probes/r7_bake_baseline_probe.gd`
- River path: `Water River`
- River settings:
  - `baking_resolution = 0` (64x64)
  - `bake_generation_behavior = downstream_baseline_collision_support`
  - `baking_raycast_layers = 1`
  - `shape_step_length_divs = 1`
  - `shape_step_width_divs = 1`
  - neutral `flow_speeds`
  - default projection strides `[32, 16, 8, 4, 2, 1, 1, 1]`, 5 iterations per stride, 2 tangency passes
- Scene content: one short mildly curved river plus at least one deliberately sized `StaticBody3D`/`BoxShape3D` obstacle on layer 1. The collider must be large enough to produce collision pixels at 64x64, but not so large that it covers the entire bake.
- Required proof from the legacy baseline:
  - `bake_generation_behavior == downstream_baseline_collision_support`
  - `collision_probe_skipped=false`
  - `collision_hit_pixel_count > 0`
  - `collision_hit_pixel_count < collision_total_pixel_count`
  - at 64x64, `collision_hit_pixel_count >= 32` and collision coverage below 70%; if this fails, resize/reposition the collider rather than accepting a tiny or full-coverage fixture
  - `support_fallback_applied=false` and empty `support_fallback_reason`
  - `collision_support_filters_ran=true`
  - `water_occupancy_baked=true`
  - `obstacle_avoidance_applied=true`
  - `flow_projected=true`
  - `flow_speed_scaled=false` for the default neutral-flow fixture; the recorded non-neutral run under `.codex-research/r7-baselines/compute-cleanup-responsiveness/` proves `flow_speed_scaled=true` and pass count `1` before migration
  - `water_occupancy` has nonzero/non-full solid coverage and nonzero proximity-ring coverage
  - `obstacle_features` is not all neutral; require side-deflection confidence plus at least one of pillow, wake/eddy, or eddy-line channels to have nonzero occupied coverage
  - all generated textures are present and readable
  - current public projection labels observed: `Projecting flow 0/40`, `5/40`, `10/40`, `15/40`, `20/40`, `25/40`, `30/40`, and `35/40`
  - separate internal proof of `jacobi_pass_count=40`; current public progress labels alone prove only the eight stride groups
  - top-level pass trace counts match the expected neutral-flow fixture workload: `bank response feature mask=1`, `flow pressure=1`, `blurred flow pressure=1`, `dilated collision map=1`, `normal map=1`, `occupancy proximity field=1`, `water occupancy mask=1`, `obstacle feature mask=1`, `flow divergence map=1`, `flow pressure jacobi pass=40`, `projected flow map=1`, `boundary tangency flow map=2`, `foam map=1`, `blurred foam map=1`, `combined flow/foam/noise map=1`, and `combined distance/pressure map=1`
  - `flow_speed_scale` pass count is `0` for the neutral-flow fixture, or `1` only in an explicit non-neutral speed-scale variant
  - diagnostics/postprocess ran: occupied flow diagnostics sampled at least one texel, final padded textures were created through RiverManager result handoff, and `valid_flowmap` plus material bindings reached the same completion path as R6
  - no generated resources saved in place

This fixture is deliberately different from the R6 full-Demo undo-delete workflow. It must stay cheap enough that both automated heartbeat measurement and any human-assisted editor interaction are practical.

## Recorded Baseline Command

Use the existing Godot launch pattern from the parent handoff with repo-local `APPDATA`/`LOCALAPPDATA`.

Recorded reusable command:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user-r7"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_bake_baseline_probe.gd" -- scene=res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn river="Water River" out=res://.codex-research/r7-baselines/legacy warmup=1 runs=5 save=false
```

Expected/recorded marker:

- `R7_LEGACY_BASELINE_OK`

The command is windowed by design. Do not add `--headless` for bake/compute timing because official RenderingDevice docs state local/global RD access is unavailable in headless mode, and existing bake readback probes are windowed.

## Timing And Responsiveness Metrics

The baseline probe must record:

- Godot version, rendering method/driver, adapter name/type/vendor.
- Elapsed bake ms from immediately before `bake_texture()` to `progress_notified` message `finished`.
- Warmup count, measured run count, median/min/max elapsed ms.
- Per-progress-label timestamps, including `Projecting flow`.
- Internal pass counts, including `jacobi_pass_count=40`.
- Process-frame heartbeat while baking: total frames, max frame gap, p95 frame gap.
- Generated texture presence, size, format, and hashes.
- `source_signature_version`, `source_metadata.flow_projected`, `source_metadata.collision_hit_pixel_count`, `source_metadata.collision_support_filters_ran`, `source_metadata.water_occupancy_baked`, `source_metadata.obstacle_avoidance_applied`, `source_metadata.support_fallback_*`, and `bake_settings`.

The future production compute run compares against the recorded median elapsed time and heartbeat budget. Initial hard stop: no single low-cost fixture frame gap above 1000 ms.

Recorded non-replacing heartbeat comparison:

- Neutral legacy low-cost bake: `elapsed_ms=2525.522`, `frame_count=142`, `max_frame_gap_ms=81.209`, `p95_frame_gap_ms=38.599`.
- Non-neutral legacy low-cost bake: `elapsed_ms=2503.01`, `frame_count=144`, `max_frame_gap_ms=85.307`, `p95_frame_gap_ms=33.334`.
- Canonical non-replacing compute projection: `elapsed_ms=180.316`, `frame_count=3`, `max_frame_gap_ms=142.179`, `p95_frame_gap_ms=142.179`.
- Report-only production replacement validation pipeline: `elapsed_ms=228.019`, `frame_count=5`, `max_frame_gap_ms=145.067`, `p95_frame_gap_ms=145.067`, `compute_projection_elapsed_ms=193.19`, `candidate_assembly_elapsed_ms=34.805`, `legacy_fixture_bake_elapsed_ms=2571.256`, `dispatch_count=44`, `compute_barrier_count=43`, `submit_count=1`, `sync_count=1`, and `sync_wait_frames=3`.

Recorded explicit selection and active guarded-abort comparison:

- `R7_COMPUTE_SELECTION_ABORT_OK` wrote `.codex-research/r7-baselines/compute-selection-abort/r7_compute_selection_abort.txt`.
- Backend selection contract: default selection is `legacy_canvas_item`; explicit `canonical_compute_non_replacing` preserves the requested mode but selects legacy output fallback with `fallback_reason=canonical_compute_non_replacing_is_report_only`; missing-evidence `canonical_compute_replacing` falls back with `fallback_reason=canonical_compute_replacing_not_promoted`; unsupported modes fall back to legacy. Source signature version is 29 and `source_signature_requires_backend_or_version_bump_before_compute_replacement=false`.
- Replacement gate contract: selections report `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`, `stage=report_only_non_replacing` without evidence and `ready_for_replacement` with all evidence, minimum replacing signature version `29`, and blocker fields. Without staging/production evidence, the selector reports missing evidence blockers; with staging and production-validation evidence supplied, the blocker list is empty.
- Complete canonical projection stayed non-replacing: `completed=true`, `ok=true`, `selected_readback_path=delayed_single_submit_wait_3_frames_sync_texture_get_data`, `production_output_replaced=false`, empty `output_texture_keys`, zero owned RIDs after cleanup, and released local RenderingDevice.
- Direct baker abort plus immediate cleanup after submit: `completed=true`, `reason=cancelled`, `compiled_shader_count=4`, `projection_sampler_reads=true`, `submit_count=1`, `sync_count=1`, `max_frame_gap_ms=34.433`, zero owned RIDs after cleanup, released local RenderingDevice, no unsynced submit state, empty `output_texture_keys`, and `production_output_replaced=false`.
- Owner free after submit: `completed=true`, `reason=cancelled`, `max_frame_gap_ms=34.337`, and the same zero-RID/released-RD/no-output guard fields as direct abort.
- Scene close after submit: `completed=true`, `reason=cancelled`, `max_frame_gap_ms=33.058`, and the same zero-RID/released-RD/no-output guard fields as direct abort.
- The surface guard reran with `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-selection-abort surface_line_numbers=normalized`.

Recorded representative material/debug visual evidence:

- `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` wrote `.codex-research/r7-baselines/compute-representative-visuals/r7_compute_representative_visuals.txt`.
- The probe ran the canonical non-replacing projection, assembled a review candidate `flow_foam_noise` from canonical RG plus legacy foam/noise channels, temporarily bound it to the live river material for screenshots only, and restored the legacy binding.
- Captured screenshots: 7 PNGs covering legacy material context, canonical material oblique, canonical top-down material, canonical raw flow, canonical flow arrows, canonical obstacle confidence, and canonical contact/protrusion debug views.
- Texture-space artifacts: 6 PNG crops covering known target neighborhoods `(82, 47)`, `(61, 67)`, tile-5 `(42, 63)`, obstacle contact occupancy, obstacle confidence, and a canonical-vs-legacy delta crop around `(82, 47)`.
- Guard fields: `production_output_replaced=false`, empty output texture keys, source signature version 29, RiverManager output state unchanged, generated texture hashes unchanged, and `warnings=[]`.

## Generated Texture Tolerance

Use this first-pass tolerance gate for compute-generated textures:

| Scope | Gate |
| --- | --- |
| Non-migrated textures | Must stay byte-identical to the legacy baseline. |
| Migrated compute textures | Same presence, size, and semantic channels as legacy. |
| Whole-image normalized channel deltas | `max_abs <= 0.02`, `p99_abs <= 0.006`, `mean_abs <= 0.0015`; provisional until baseline self-compare and f16/format round-trip evidence are recorded. |
| Occupied-atlas normalized channel deltas | Same thresholds as whole-image; report separately per texture and per channel. |
| Decoded flow vectors | For occupied texels with magnitude >= 0.05: `p95_angle <= 2 deg`, `max_angle <= 10 deg`, `p95_magnitude_delta <= 0.03`. |
| Binary/class masks | Report solid/proximity/obstacle-feature class-count and coverage deltas; generic max/mean channel thresholds are not sufficient for these masks. |
| Metadata/dictionaries | Signature v28; source signature and bake settings unchanged unless spec updates first. |

Any tolerance failure is a review finding, not an automatic threshold bump. If thresholds change, record the reason, affected texture/channel, diff metrics, and visual/manual evidence in this file.

Recorded R7 format/tolerance evidence:

- `R7_TOLERANCE_SELF_COMPARE_OK` rebaked the low-cost legacy fixture twice and recorded exact self/rerun deltas for all six generated textures: whole-image and occupied-atlas channel deltas stayed `0.0`; decoded flow p95/max angle and p95 magnitude deltas stayed `0.0`; water occupancy solid/proximity/ring deltas stayed `0`; obstacle-feature non-neutral coverage delta stayed `0`.
- `R7_TEXTURE_FORMAT_ROUNDTRIP_OK` created production-style RD storage textures with storage/sampling/copy usage for `R16G16B16A16_SFLOAT` -> `Image.FORMAT_RGBAH` and `R32G32B32A32_SFLOAT` -> `Image.FORMAT_RGBAF`, dispatched representative writes, read the storage image in a second dispatch into a storage buffer, read texture bytes into `Image.create_from_data()`, created `ImageTexture`, and recorded decoded flow/pressure/class-mask metrics.
- RGBA16F result: decoded flow p95 angle `0.19689192887304 deg`, max angle `0.95484827969332 deg`, p95 magnitude delta `0.00089240074158`, pressure p95 delta `0.01437568664551`, pressure max delta `0.015625`, class count `81/81`.
- RGBA32F result: decoded flow p95 angle `0.00001743359219 deg`, max angle `0.00005546911465 deg`, p95 magnitude delta `0.00000035762787`, pressure p95 delta `0.00002098083496`, pressure max delta `0.00002670288086`, class count `81/81`.
- The main legacy baseline file existed during the probe: `.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt`.

A `texture_is_format_supported_for_usage()` result remains only a capability preflight. The accepted evidence for R7 is the shader write, shader imageLoad readback, byte-to-`Image`, `ImageTexture`, and semantic metric path above.

## R7_TOLERANCE_V1 Gate Audit - 2026-06-15

Decision: keep `R7_TOLERANCE_V1` unchanged and add supplemental diagnostics only. Do not introduce `R7_TOLERANCE_V2` without visual artifact evidence, affected texture/channel notes, rationale, and replacement-risk review.

- The decoded-flow mask remains `expected_magnitude >= 0.05`. It is the right replacement-risk mask for now because it avoids neutral-vector angle instability while still covering 3147 of 3612 occupied atlas texels. The probe now reports the mask explicitly plus skipped low-magnitude texels, actual/expected magnitude percentiles, magnitude buckets, tile-edge buckets, p99 angle, weighted mean angle, endpoint delta, and max-angle records.
- The `p95_angle <= 2 deg` gate stays appropriate as the final packed `flow_foam_noise` replacement gate. The current candidate is not failing only by a mathematical low-magnitude corner case: generated p95 angle is `3.48932145236808 deg`, p99 is `5.48129340327964 deg`, 592 samples exceed 2 deg, and the `>= 0.20` magnitude bucket still has p95 angle `2.12881948668782 deg`.
- The `max_angle <= 10 deg` gate remains a strict red-flag guard, but it should be interpreted with the new confidence fields. The current max angle `12.4395520353247 deg` occurs at `(82, 47)`, expected magnitude `0.1071098819375`, endpoint delta `0.02352941036224`, and tile-edge distance `2`; it is not a 1px edge sample, but it is near an atlas tile edge.
- Whole-image and occupied channel gates remain aligned with replacement risk. The whole-image G max is in padding at `(102, 95)`, but occupied content still fails: occupied G p99 is `0.00784313678741` and occupied G max is `0.01568627357483` at `(43, 44)`, while occupied R p99 is `0.00392159819603` and occupied R max is `0.01176470518112` at `(82, 27)`.
- The failures are not concentrated solely in low-magnitude, padding, or 1px atlas-wall samples. Low magnitude `0.05..0.10` has 193 samples and p95 angle `6.19951084639493 deg`; mid magnitude `0.10..0.20` has 1582 samples and p95 angle `3.6169164296965 deg`; strong magnitude `>= 0.20` has 1372 samples and p95 angle `2.12881948668782 deg`. Tile-edge 1px p95 is `3.08730420178394 deg`; tile-inner 1px p95 is `3.54360459424017 deg`.
- Weighted and endpoint metrics are useful supplemental evidence, not replacement gates yet. The current weighted mean angle is `0.76174545540638 deg`, p95 endpoint delta is `0.01109187025577`, and p99 endpoint delta is `0.01753778755665`; these help separate broad small vector drift from isolated angular spikes while preserving the stricter final gate.
- Final replacement remains blocked in this planning slice. The legacy-pressure override still passes with p95/p99/max angle `0` and occupied R/G p99 `0`, so the evidence still points to pressure-feedback drift rather than divergence, gradient subtract, boundary tangency, final combine, or baker postprocess. Future replacement must either pass legacy `R7_TOLERANCE_V1` or pass the separate `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` path below.

## R7_COMPUTE_CANONICAL_ACCEPTANCE_V1 - 2026-06-15

Decision: compute pressure feedback is the canonical solver target. Legacy CanvasItem output is compatibility evidence and fallback behavior, not the final correctness oracle. Keep `R7_TOLERANCE_V1` unchanged, do not introduce `R7_TOLERANCE_V2`, and continue to report legacy parity metrics as diagnostics.

Canonical solver rules:

- Integer texel addressing: compute output texels and pressure neighbors are derived from texel-space coordinates, not CanvasItem interpolated `UV` or renderer-specific half-texel tie artifacts.
- Atlas column walls: X-neighbor reads crossing the current atlas column or the 2% padding-wall band use center pressure as the Neumann wall value.
- Solid-cell pressure preservation: solid cells preserve center pressure; solid pressure neighbors return center pressure.
- Y clamp behavior: Y neighbors clamp to valid texture rows/open continuation margins without becoming atlas walls.
- Occupancy/solid neighbor behavior: `water_occupancy.r > 0.5` defines solid; velocity, divergence, pressure, and tangency passes must preserve their documented solid/proximity semantics.
- Texture choices: pressure feedback uses RGBA32F storage ping-pong unless later evidence safely narrows it; projection/final candidate textures may use RGBA16F only where format and semantic gates pass; RGBA8 sampled source inputs stay RGBA8 when the legacy source image is RGBA8.
- Final packing/postprocess: packed flow, pressure, foam, noise, distance, occupancy, and feature-channel meanings stay unchanged unless a separate spec update says otherwise.

Visual validation required before replacement:

- Low-cost R7 fixture: `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`, with top-down/debug and material-rendered evidence.
- Full Demo or representative scene: `res://Demo.tscn` or a smaller named scene with comparable bends, contacts, and obstacles.
- Obstacle/contact/tile-edge cases: named views and screenshots/rendered evidence covering obstacle contacts, atlas tile edges, and the known `(82, 47)`, `(61, 67)`, and tile-5 `(42, 63)` neighborhoods where practical.
- Non-neutral flow-speed case before migrating that path: recorded for the low-cost legacy path in `.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`; compute migration/replacement for flow-speed effects still needs replacement-specific visual/semantic review if output changes.

Physics/semantic validation required:

- Divergence reduction improves or stays within a documented bound.
- No boundary penetration artifacts at solids, atlas walls, or contact edges.
- No NaNs, invalid pressure values, unreadable images, or unstable self/rerun output.
- Occupied flow vectors remain reasonable by magnitude, endpoint delta, and direction buckets.
- Foam/noise/distance/pressure/occupancy/feature channels do not change accidentally outside the migrated solve/filter scope.

Fallback and bake-data rules:

- The first accepted compute path stays behind a selection/flag until visual validation passes.
- RiverManager ownership stays unchanged: no RiverManager texture/resource writes from compute code; RiverManager still owns generated resources, material binding, validity flags, bake flag clearing, completion signaling, and public API.
- If canonical compute produces different generated textures, make an explicit bake signature/version decision before shipping replacement. Existing bakes may need regeneration; document that intentionally.

Visual review and replacement decision recorded after the automated run:

- The five generated low-cost canonical artifacts in `.codex-research/r7-baselines/compute-canonical-acceptance/` were reviewed: `r7_canonical_final_flow_rg.png`, `r7_canonical_projected_flow_rg.png`, `r7_canonical_pressure_r.png`, `r7_canonical_divergence_before_abs.png`, and `r7_canonical_divergence_after_abs.png`.
- Decision: We are accepting a visible/output change from legacy for the canonical compute path represented by these artifacts.
- Rationale: the final/projected flow RG artifacts remain spatially coherent around the river body, obstacle contact, and atlas tile structure; the pressure artifact is smooth and localized; the divergence-after artifact shows broader low-amplitude structure than divergence-before, but the automated gate reduces the high tail (`p99_abs 0.2470703125 -> 0.12841796875`) and keeps final max divergence inside the documented bound (`0.32080078125 <= max(initial_max * 1.5, initial_p99)`).
- Replacement readiness decision: `replacement_ready=false`. Generated bake output must not be replaced yet.
- Fallback/config decision: legacy CanvasItem remains the production default/fallback. The baker records an explicit `flowmap_backend_mode` selection contract: non-replacing canonical compute is report-only, replacing compute selects canonical compute only when `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` is ready, representative-scene/material visuals are recorded, report-only generated-output replacement staging is accepted, and production replacement validation is accepted.
- Bake signature/version decision: source signature policy is accepted as `RIVER_BAKE_SOURCE_SIGNATURE_VERSION=29`; backend mode is not added to the source signature because it remains an internal baker selection rather than a RiverManager source key.

Recorded confirming diagnostic:

- `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt` recorded `R7_COMPUTE_SOLVE_FILTER_STACK_OK`.
- `legacy_pass6_sampler.fragcoord_uv_artifact_hypothesis_supported=true`.
- Legacy UV y-band rows had 20 total X-dependent transitions; the probe-only `FRAGCOORD` variant had 0.
- The `FRAGCOORD` variant did not select the canonical compute model uniformly (`fragcoord_y_band_compute_model_match_delta=-36`), so this is evidence to stop chasing interpolated-UV artifacts, not evidence to promote a floor/tie/diagonal/source-edge compatibility rule.
- The backend skeleton regression reran and recorded `R7_COMPUTE_BACKEND_SKELETON_OK` in `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/skeleton-rerun/r7_compute_backend_skeleton.txt`.
- The public surface guard reran and recorded `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-fragcoord-diagnostic surface_line_numbers=normalized`.
- `git diff --check` passed; Git reported only the existing CRLF normalization warning for `session-handoff.md`.

## R7_COMPUTE_CLEANUP_RESPONSIVENESS - 2026-06-15

Decision: accept the non-replacing low-cost cleanup, heartbeat, and non-neutral flow-speed coverage as recorded evidence before production replacement. This does not replace generated bake output; the later `R7_COMPUTE_SELECTION_ABORT_OK` proof closes explicit backend selection and guarded active abort/free/scene-close coverage separately.

- Report: `.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`.
- Marker: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK`.
- Probe: `res://addons/waterways/probes/r7_compute_cleanup_responsiveness_probe.gd`.
- Backend reporting change: the non-replacing compute backend now reports cleanup completion, owned RID count after cleanup, local RenderingDevice release, and submitted-without-sync state after cleanup.
- Neutral legacy run: `flow_speed_scaled=false`, `flow speed scale map=0`, `max_frame_gap_ms=81.209`, `p95_frame_gap_ms=38.599`, `source_signature_version=29`, empty `resource_path`.
- Non-neutral legacy run: `flow_speed_scaled=true`, `flow speed scale map=1`, `max_frame_gap_ms=85.307`, `p95_frame_gap_ms=33.334`, `source_signature_version=29`, empty `resource_path`; `flow_foam_noise` hash changed from neutral `3bfadac449d094f0bd603f8549f8de9e` to `66af6fbcab99aef2813cbd96c13ca733`.
- Canonical non-replacing compute projection: `ok=true`, `dispatch_count=44`, `compute_barrier_count=43`, `compute_lists_recorded=1`, delayed `selected_readback_path=delayed_single_submit_wait_3_frames_sync_texture_get_data`, `async_readback_selected=false`, `production_output_replaced=false`, empty `output_texture_keys`, `pressure_feedback_rgba32f=true`, `canonical_integer_texel_addressing=true`, `max_frame_gap_ms=142.179`.
- Cancelled compute run: cancellation happens after compiled compute resources and projection sampler setup; result records `reason=cancelled`, `cleanup_owned_rid_count_after_cleanup=0`, `cleanup_rendering_device_released=true`, `cleanup_submitted_without_sync_after_cleanup=false`, empty `output_texture_keys`, and `production_output_replaced=false`.
- Later replacement slices supersede the old blockers: `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK`, `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`, refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`, source signature v29, and the gated replacement code path are now recorded. Default production remains legacy until final promotion/default-selection policy is accepted.

## R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING - 2026-06-15

Decision: accept generated-output replacement staging as report-only evidence. This does not replace generated bake output, does not make `replacement_ready` true, and does not enable `canonical_compute_replacing`.

- Report: `.codex-research/r7-baselines/compute-generated-output-replacement-staging/r7_compute_generated_output_replacement_staging.txt`.
- Marker: `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`.
- Probe: `res://addons/waterways/probes/r7_compute_generated_output_replacement_staging_probe.gd`.
- Staged output key: `flow_foam_noise`.
- Staged hash decision: legacy `flow_foam_noise` before hash `3bfadac449d094f0bd603f8549f8de9e`; staged canonical candidate hash `a5ee9d4f0e7585ca1dc67d3c72c26a49`; `changed_texture_keys=["flow_foam_noise"]`.
- Legacy-sourced outputs/channels: `dist_pressure`, `obstacle_features`, `terrain_contact_features`, `bank_response_features`, and `water_occupancy` remain legacy-sourced; `flow_foam_noise.b` and `flow_foam_noise.a` remain legacy-sourced foam/noise channels while `flow_foam_noise.r/g` are the staged compute channels.
- Ownership preservation: `actual_river_state_unchanged=true`, `actual_river_texture_hashes_unchanged=true`, `river_manager_ownership_preserved=true`, `river_manager_public_surface_preserved=true`, empty actual `output_texture_keys`, and `production_output_replaced=false`.
- Gate after staging evidence: `generated_output_replacement_staging_ok=true`, `source_signature_policy_ready=true`, `replacement_code_path_implemented=true`, but `ready=false` because `production_replacement_validation_not_accepted` remains the staged-only blocker.
- Selection after staging evidence: explicit `canonical_compute_replacing` still selects `legacy_canvas_item` with `fallback_reason=canonical_compute_replacing_not_promoted`; `production_output_replaced_by_compute=false`.
- Signature policy: `source_signature_version=29`; backend mode remains outside the source signature.

## R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION - 2026-06-15

Decision: accept production replacement validation, source signature v29, and the gated replacement branch smoke. This does not replace checked-in generated bake output and does not change the default production backend, but supplied-evidence `canonical_compute_replacing` is now allowed to select compute behind `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`.

- Report: `.codex-research/r7-baselines/compute-production-replacement-validation/r7_compute_production_replacement_validation.txt`.
- Marker: `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`.
- Probe: `res://addons/waterways/probes/r7_compute_production_replacement_validation_probe.gd`.
- Handoff shape: RiverManager would receive texture fields `flow_foam_noise_texture`, `dist_pressure_texture`, `obstacle_features_texture`, `terrain_contact_features_texture`, `bank_response_features_texture`, and `water_occupancy_texture` through `_apply_flowmap_bake_result`.
- Would-replace output key: `flow_foam_noise` only. Canonical compute supplies `flow_foam_noise.r/g`; `flow_foam_noise.b/a`, `dist_pressure.rgba`, `obstacle_features.rgba`, `terrain_contact_features.rgba`, `bank_response_features.rgba`, and `water_occupancy.rgba` remain legacy-sourced.
- Handoff hashes: `flow_foam_noise` would change from legacy `3bfadac449d094f0bd603f8549f8de9e` to canonical candidate `a5ee9d4f0e7585ca1dc67d3c72c26a49`; `dist_pressure`, `obstacle_features`, `terrain_contact_features`, `bank_response_features`, and `water_occupancy` keep legacy hashes `8f0bfa2fd36dacd3d50cd7cd1da6d988`, `353318792fb5b981bbc3a2b0abe1a807`, `7829e80bb23da90d9740d4accedfdc09`, `4a2a58e055fc208245713efc8565f6e1`, and `ce91ae9edd5559bb1c6d8722a3cfce18`.
- Timing/responsiveness: `elapsed_ms=228.019`, `compute_projection_elapsed_ms=193.19`, `candidate_assembly_elapsed_ms=34.805`, `legacy_fixture_bake_elapsed_ms=2571.256`, `frame_count=5`, `max_frame_gap_ms=145.067`, and `p95_frame_gap_ms=145.067`, below the 1000 ms hard stop.
- Sync/readback: `selected_readback_path=delayed_single_submit_wait_3_frames_sync_texture_get_data`, `async_readback_selected=false`, `submit_count=1`, `sync_count=1`, `sync_wait_frames=3`, `dispatch_count=44`, `compute_barrier_count=43`, and `readback_byte_count=449440`.
- Ownership/output preservation: `actual_river_state_unchanged=true`, `actual_river_texture_hashes_unchanged=true`, `river_manager_ownership_preserved=true`, `river_manager_public_surface_preserved=true`, empty actual `output_texture_keys`, and `production_output_replaced=false`.
- Gated selection behavior: explicit `canonical_compute_replacing` with all gate evidence selects `canonical_compute_replacing`, `fallback_applied=false`, and `production_output_replaced_by_compute=true`.
- Runtime replacement-path smoke: direct baker validation records `runtime_replacement_path.ok=true`, `mode=canonical_compute_replacing`, `output_texture_keys=["flow_foam_noise"]`, `production_output_replaced=true`, delayed `sync_texture_get_data` readback, 44 dispatches, 43 barriers, one submit/sync after three waited frames, and unchanged RiverManager state/hashes because the smoke does not hand textures back to RiverManager.
- Gate after production validation evidence: `production_replacement_validation_ok=true`, `ready=true`, `replacement_ready=true`, `source_signature_policy_ready=true`, `source_signature_version=29`, `replacement_code_path_implemented=true`, and blockers are empty. Default production selection remains `legacy_canvas_item`.
- Surface guard: `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-production-replacement-validation/surface files=10`; normalized comparison recorded `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-production-replacement-validation surface_line_numbers=normalized`.

## R7_COMPUTE_SELECTION_ABORT - 2026-06-15

Decision: accept explicit backend selection/config and guarded active abort/free/scene-close cleanup coverage for the non-replacing canonical compute path. This does not replace generated bake output and does not make `replacement_ready` true.

- Report: `.codex-research/r7-baselines/compute-selection-abort/r7_compute_selection_abort.txt`.
- Marker: `R7_COMPUTE_SELECTION_ABORT_OK`.
- Probe: `res://addons/waterways/probes/r7_compute_selection_abort_probe.gd`.
- Selection contract: default `flowmap_backend_mode` selection is `legacy_canvas_item`; explicit `canonical_compute_non_replacing` preserves the request but selects legacy generated-output fallback with `fallback_reason=canonical_compute_non_replacing_is_report_only`; explicit `canonical_compute_replacing` falls back with `fallback_reason=canonical_compute_replacing_not_promoted`; unsupported modes fall back to legacy.
- Replacement guard: default and missing-evidence selections report `canonical_compute_replacement_ready=false`, `production_output_replaced_by_compute=false`, `source_signature_version=29`, `canonical_compute_replacement_gate_id=R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1`, `canonical_compute_replacement_gate_stage=report_only_non_replacing`, `canonical_compute_replacement_gate_ready=false`, and `canonical_compute_min_replacing_signature_version=29`.
- Gate blockers checked by the refreshed probe before staging/production-validation evidence is supplied: missing canonical/visual/selection/cleanup/surface evidence plus `generated_output_replacement_staging_not_accepted` and `production_replacement_validation_not_accepted`. The probe now asserts that source signature policy and replacement code path blockers are absent.
- Complete canonical projection: `ok=true`, `selected_readback_path=delayed_single_submit_wait_3_frames_sync_texture_get_data`, empty `output_texture_keys`, `production_output_replaced=false`, zero owned RIDs after cleanup, and released local RenderingDevice.
- Direct baker abort plus immediate cleanup, owner free, and scene close after submit: each run completes with `reason=cancelled`, `compiled_shader_count=4`, `projection_sampler_reads=true`, `submit_count=1`, `sync_count=1`, no stuck baker running flag, zero owned RIDs after cleanup, released local RenderingDevice, no unsynced submit state, empty `output_texture_keys`, and `production_output_replaced=false`.
- Surface guard: `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-selection-abort surface_line_numbers=normalized`.

## Legacy Pressure-Feedback Correctness Audit - 2026-06-15

Decision: classify the observed pass-6 mixed sampler behavior as a legacy canvas-renderer artifact with unproven visual consequence. It remains the compatibility target for `R7_TOLERANCE_V1` diagnostics and fallback comparison, but canonical compute is now the solver target. Do not treat `R7_TOLERANCE_V1` as an oracle for physical correctness, and do not accept compute divergence without the visual/semantic evidence required by `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.

- `flow_pressure_jacobi_pass.gdshader` implements the intended Jacobi stencil: pressure is decoded from R using `FLOW_SOLVE_PRESSURE_SCALE`, divergence is decoded from R using `FLOW_SOLVE_DIV_SCALE`, solid center cells preserve their pressure, solid or atlas-wall neighbors use the center pressure as a Neumann ghost, X reads are clamped inside the current atlas column with the existing 2% padding wall, and Y reads clamp to the image edge without wall-flagging. The related legacy solve shaders are coherent with this contract: `flow_divergence_pass.gdshader` uses free-slip velocity ghosts, `flow_gradient_subtract_pass.gdshader` performs `v - gradient(p)`, and `flow_boundary_tangency_pass.gdshader` removes velocity into solid proximity. There is no `flow_project_pass.gdshader` in this checkout; the project step is implemented by `flow_gradient_subtract_pass.gdshader`.
- The mixed half-texel vertical choice is not shader intent. The controlled pass-6 diagnostic still reports zero choice delta, original five-point vertical lower/upper splits of `3/2` for both up and down, horizontal wall-center matches `5/5`, and current compute floor-model matches only `1/5` up and `2/5` down. The new 25-point grid diagnostic records exact vertical choices with zero choice delta and shows a mostly, but not perfectly, ColorRect-triangle-shaped pattern: an `upper when point.x < point.y, otherwise lower` model matches `22/25` up samples and `22/25` down samples, while the compute floor model matches only `10/25` up and `9/25` down.
- The grid mismatches are the important caution. Both up and down cases disagree with the simple diagonal model at `(10, 63)`, `(31, 63)`, and `(53, 63)`, choosing lower where the diagonal model predicts upper. This makes a hard-coded diagonal compatibility rule too speculative for the production backend.
- Visible consequence remains unvalidated. The current compute-pressure generated candidate fails occupied, mid/strong-magnitude, and tile-inner legacy metrics, so the drift cannot be dismissed as padding-only noise. Before replacement, named visual evidence must show that canonical compute is visually acceptable or better and does not introduce new artifacts.
- Failures are not isolated to a single atlas seam or padding band. The largest whole-image G delta is in padding, but occupied G p99 still fails; the decoded-flow max angle is at `(82, 47)` with tile-edge distance `2`, and tile-inner 1px p95 angle remains above the gate. Atlas seams, pressure-feedback transitions, and obstacle-boundary neighborhoods remain plausible contributors rather than proven sole causes.
- A separate canonical-compute acceptance path is now required for any intentional compute-vs-legacy divergence. Minimum evidence: named scenes/views, affected texture/channel rationale, before/after rendered evidence, physics/semantic metrics, fallback selection, bake signature/version decision, and continued legacy parity diagnostics.

## Pressure-Feedback Canvas Tie Diagnostic - 2026-06-15

Decision: keep the diagonal canvas-tie mode as an opt-in diagnostic candidate only. It is not a production compatibility rule and does not justify generated bake output replacement.

- `river_flowmap_compute_backend.gd` now has an opt-in `pressure_jacobi_canvas_tie_mode=1` shader path that biases exact stride-16 vertical half-texel pressure/occupancy samples by the simple `base_texel.x < base_texel.y` diagonal model. The default primary path remains `pressure_jacobi_canvas_tie_mode=0`.
- `r7_compute_solve_filter_stack_probe.gd` runs this candidate as `projection_canvas_tie_*` and `generated_canvas_tie_candidate_parity` beside the unchanged primary candidate and legacy-pressure override. It preserves empty output texture keys, `production_output_replaced=false`, delayed single-submit/wait/sync/readback, and async readback blocked.
- The candidate improves broad generated-output metrics but worsens tail risk: p95 angle improves from `3.48932145236808 deg` to `3.02500924801543 deg`, weighted mean angle improves from `0.76174545540638 deg` to `0.60170081393187 deg`, strong-magnitude p95 improves from `2.12881948668782 deg` to `2.08926201922287 deg`, and tile-inner 1px p95 improves from `3.54360459424017 deg` to `3.36048231339366 deg`; however p99 angle worsens from `5.48129340327964 deg` to `5.96108559105589 deg` and max angle worsens from `12.4395520353247 deg` to `18.2393832633789 deg`.
- Occupied generated channel p99 values remain failing/unchanged at G `0.00784313678741` and R `0.00392159819603`. Projection pressure whole-image R p99 improves from `0.013671875` to `0.007080078125`, but occupied pressure R p99 worsens slightly from `0.0048828125` to `0.00537109375`.
- Conclusion: the simple diagonal model is a useful investigative lead because it reduces mean/p95 drift, but it moves errors into the tail and remains below replacement quality. Future work should use the full grid choice table and/or a renderer-grounded model rather than promoting the diagonal bias.

## Synchronization And Readback Risk Checks

Before production compute replacement, add and run a dedicated sync/readback stress probe:

```powershell
& $godotConsole --path $root --script "res://addons/waterways/probes/r7_rendering_device_sync_probe.gd" -- iterations=97 repeats=20 out=res://.codex-research/r7-baselines/sync
```

Expected/recorded marker:

- `R7_RENDERING_DEVICE_SYNC_OK`

Recorded R7 sync/readback evidence:

- `R7_RENDERING_DEVICE_SYNC_OK` ran with `iterations=97`, `repeats=20`, and `ELEMENT_COUNT=257` under Forward+/Vulkan on AMD Radeon RX 6800 XT.
- Repeated-run/resource-reuse path recorded all 97 ping-pong compute lists, submitted once, waited 3 process frames, called `sync()`, and verified final `buffer_get_data()` checksums across 20 repeats.
- Intra-list dependent dispatch with `compute_list_add_barrier()` matched expected values. The report-only no-barrier variant did not match expected values on this machine, so production batched dependent dispatches must use `compute_list_add_barrier()` or avoid intra-list read-after-write dependencies.
- Async readback was attempted with `buffer_get_data_async()` but the callback did not arrive within 180 frames; async readback is not selected for the first production path. The probe then called delayed `sync()` and verified the same final buffer through `buffer_get_data()`.
- Cleanup subcase created RD texture/buffer/uniform resources and double-called cleanup. Texture validity changed from true to false after cleanup and the second cleanup was a no-op.

The stress probe should:

- Create a local RenderingDevice and report a clear skip/fail marker if unavailable.
- Log relevant RD limits and selected storage texture/buffer formats.
- Dispatch deterministic ping-pong work for more iterations than the frame queue size.
- Include binding-swap and resource-reuse subcases so stale bindings do not accidentally pass.
- Include an intra-list dependent-dispatch subcase with and without `compute_list_add_barrier()` when production intends to batch dependent work in one compute list.
- Exercise both delayed `submit()`/`sync()` plus `texture_get_data()` or `buffer_get_data()` and the selected async readback path if async readback is chosen.
- Read back only through the selected production sync/readback method in the production-path subcase.
- Verify the final checksum/texture values exactly.
- Prove repeated abort and cleanup calls free all owned RIDs.

## Editor Responsiveness Checks

Automated first:

- Use the heartbeat fields from `r7_bake_baseline_probe.gd`.
- Compare compute heartbeat against the legacy fixture budget.
- Fail on stuck bake flag, no `finished` progress message, or max frame gap above the hard stop.

Human-assisted only if needed:

1. Open `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`.
2. Select `Water River`.
3. Run the R7 fixture bake or repeated fixture-bake harness, not the full Demo scene.
4. During `Projecting flow`, confirm the editor still accepts selection changes and does not freeze long enough to prevent interaction.
5. Relay Godot version/renderer, visible behavior, and any Output panel errors.

## Recorded Results

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Added the `RiverFlowmapBaker.build_canonical_compute_generated_output_replacement_staging_report()` report-only staging helper and `res://addons/waterways/probes/r7_compute_generated_output_replacement_staging_probe.gd`. Ran the probe against `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`, river `Water River`, with repo-local `APPDATA`/`LOCALAPPDATA`, writing to `out=res://.codex-research/r7-baselines/compute-generated-output-replacement-staging`.
- Output or parser errors: None in the accepted run.
- Stable result marker: `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK report=res://.codex-research/r7-baselines/compute-generated-output-replacement-staging/r7_compute_generated_output_replacement_staging.txt`.
- Pass/partial/fail: Pass for generated-output replacement staging only. Production output remains unreplaced and `replacement_ready=false`.
- Notes or follow-up: The report records staged output key `flow_foam_noise`, before hash `3bfadac449d094f0bd603f8549f8de9e`, staged candidate hash `a5ee9d4f0e7585ca1dc67d3c72c26a49`, unchanged RiverManager state/hashes, empty actual `output_texture_keys`, `production_output_replaced=false`, and `canonical_compute_replacing` fallback to legacy after staging evidence. The later production-validation proof supplies the production validation evidence; source signature v29 and the gated replacement code path are now accepted, leaving final default-production promotion as the open decision.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Added `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` to `river_flowmap_baker.gd`, extended `res://addons/waterways/probes/r7_compute_selection_abort_probe.gd` to assert the gate fields and blockers, and reran the probe with repo-local `APPDATA`/`LOCALAPPDATA` to `out=res://.codex-research/r7-baselines/compute-selection-abort`.
- Output or parser errors: None in the accepted run.
- Stable result marker: `R7_COMPUTE_SELECTION_ABORT_OK report=res://.codex-research/r7-baselines/compute-selection-abort/r7_compute_selection_abort.txt`.
- Pass/partial/fail: Pass for the guarded replacement-promotion gate and existing selection/abort coverage. Generated bake output remains unreplaced.
- Notes or follow-up: The refreshed report records `source_signature_version=29`, `source_signature_requires_backend_or_version_bump_before_compute_replacement=false`, and pre-staging blockers limited to missing evidence such as generated-output staging and production validation. The later `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK` and refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` proofs supply that evidence; the next implementation slice is final promotion/default-selection policy, not source signature or code-path enablement.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Added `res://addons/waterways/probes/r7_compute_cleanup_responsiveness_probe.gd`, added cleanup-state report fields to the non-replacing compute backend finalizer, and ran the probe with `out=res://.codex-research/r7-baselines/compute-cleanup-responsiveness`. The probe runs neutral and non-neutral low-cost legacy bakes without saving generated resources, runs a canonical non-replacing compute projection with heartbeat timing, and cancels a second compute projection after resource setup.
- Output or parser errors: None in the accepted run.
- Stable result marker: `R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK report=res://.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`.
- Pass/partial/fail: Pass for non-replacing cleanup, heartbeat, and non-neutral flow-speed coverage. Production generated-output replacement remains unstarted.
- Metrics and artifacts: neutral legacy `max_frame_gap_ms=81.209`, non-neutral legacy `max_frame_gap_ms=85.307`, compute projection `max_frame_gap_ms=142.179`; compute projection used 44 dispatches, 43 barriers, one compute list, one submit, delayed wait-3-frames sync texture readback, RGBA32F pressure feedback, and canonical integer texel addressing. The cancelled run reached compiled resources and sampler setup, then reported `reason=cancelled`, `cleanup_owned_rid_count_after_cleanup=0`, `cleanup_rendering_device_released=true`, `cleanup_submitted_without_sync_after_cleanup=false`, empty output texture keys, and `production_output_replaced=false`. The non-neutral run recorded `flow_speed_scaled=true`, `flow speed scale map=1`, and a changed `flow_foam_noise` hash.
- Notes or follow-up: This closes the low-cost non-replacing cleanup/heartbeat/non-neutral evidence. Explicit selection/config and guarded active abort/free/scene-close coverage are closed by the later `R7_COMPUTE_SELECTION_ABORT_OK` proof, representative-scene/material evidence is closed by the later `R7_COMPUTE_REPRESENTATIVE_VISUALS_OK` proof, report-only generated-output staging is closed by the later `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK` proof, and report-only production replacement validation is closed by the later `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK` proof. Production replacement still needs source signature policy and deliberate replacement code enablement.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for windowed probes; headless for the R6 surface/property dump.
- Command, scene, or workflow: Path 2 canonical-compute acceptance slice. Updated the non-replacing projection path to report `acceptance_target=R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`, use RGBA32F pressure feedback/readback for the canonical pressure ping-pong, and explicitly report canonical integer texel-space rules while not emulating CanvasItem UV artifacts or legacy tie rules. Added an automated canonical acceptance section to `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd`; generated visual artifacts under `res://.codex-research/r7-baselines/compute-canonical-acceptance`; reran the stack probe, skeleton regression, R6 surface dump, normalized R6 surface/property comparison, and `git diff --check`.
- Output or parser errors: The accepted run had no parser errors. Two earlier local parser fixes were required while adding the helper code: explicit typing for `column_min` and `save_error`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK report=res://.codex-research/r7-baselines/compute-canonical-acceptance/r7_compute_solve_filter_stack.txt`; `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-canonical-acceptance/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-canonical-acceptance/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-canonical-acceptance/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-canonical-acceptance surface_line_numbers=normalized`.
- Pass/partial/fail: Partial automated pass. `canonical_acceptance.automated_ok=true`, `canonical_rules_ok=true`, `ownership_ok=true`, `integrity_ok=true`, `divergence_ok=true`, and `flow_semantics_ok=true`; the subsequent docs review accepts the five generated artifacts as the low-cost canonical visual/output-change evidence. `canonical_acceptance.acceptance_complete=false`, `replacement_ready=false`, and `production_output_replaced=false` remain true for production replacement.
- Metrics and artifacts: `projection_compute.pressure_feedback_rgba32f=true`, `pressure_texture_format=R32G32B32A32_SFLOAT`, `pressure_image_format=FORMAT_RGBAF`, `pressure_feedback_target=canonical_texel_space_compute`, `canonical_integer_texel_addressing=true`, `canonical_canvasitem_uv_artifact_emulation=false`, and `canonical_legacy_tie_rule_emulation=false`. Divergence p99 improved from `0.2470703125` to `0.12841796875`; final max divergence stayed within the gate (`0.32080078125` vs initial `0.251953125`). Boundary flow into solids improved from projected max/p99 `0.33729922771454`/`0.26862776279449` to final max/p99 `0.076171875`/`0.05185014382005`; solid-flow max was `0.0`, fluid-flow max was `1.00000965595245`. Five visual artifacts were written: `r7_canonical_final_flow_rg.png`, `r7_canonical_projected_flow_rg.png`, `r7_canonical_pressure_r.png`, `r7_canonical_divergence_before_abs.png`, and `r7_canonical_divergence_after_abs.png`.
- Notes or follow-up: This is the automated/semantic half of path 2 plus the low-cost artifact visual acceptance, not full replacement approval. Later non-replacing cleanup/heartbeat/non-neutral evidence, explicit selection/guarded abort evidence, representative material/debug visual evidence, report-only generated-output staging evidence, and report-only production replacement validation are recorded above. Production replacement still needs source signature policy and deliberate replacement code enablement before any generated bake output can be replaced.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Added probe-only `res://addons/waterways/probes/r7_flow_pressure_jacobi_fragcoord_probe.gdshader` and wired it into `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd` as a report-only pass-6 sampler diagnostic. Ran the stack probe with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic`.
- Output or parser errors: No parser errors in the accepted run. An earlier throwaway run proved `FRAGCOORD` must be referenced in `fragment()` scope for this shader; the final run moved that access into `fragment()` and completed cleanly.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt`.
- Pass/partial/fail: Pass for the unchanged non-replacing stack marker and the new probe-only `FRAGCOORD` diagnostic. Generated output replacement did not occur; output texture keys stayed empty and RiverManager texture/resource ownership was unchanged.
- Notes or follow-up: The `FRAGCOORD` variant supports the UV-artifact hypothesis without promoting a legacy tie model. Legacy UV y-band rows had 20 total X-dependent transitions; `FRAGCOORD` rows had 0. However `fragcoord_y_band_compute_model_match_delta=-36`, so this does not prove the compute floor model, diagonal model, or source-edge model is a production compatibility rule. Use this as evidence for the canonical-compute architecture pivot and keep legacy parity reports diagnostic.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the stack prefix diagnostic and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added diagnostic-only pressure pass-prefix comparisons to `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd`, using an opt-in `pressure_jacobi_pass_limit` in the non-replacing backend to compare legacy pressure against primary mode 0, canvas-tie mode 1, and source-edge mode 2 at pass counts `[5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]`. Also added generated candidate target records for `(82, 47)` and `(61, 67)`, occupied R/G failure buckets, and top angle records. Reran the stack probe to `res://.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic`, reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/surface`, compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized, and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-prefix-diagnostic surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for unchanged non-replacing stack/skeleton/surface guards and the pressure prefix diagnostic execution; partial/fail remains for primary and diagnostic compute-pressure generated-output correctness. Full runs still report `pressure_jacobi_pass_limited=false`, empty output texture keys, `production_output_replaced=false`, delayed single-submit/wait/sync/readback, and async readback blocked. The pass limit is diagnostic-only.
- Notes or follow-up: Pass 5 is clean for modes 0/1/2. The primary mode first fails at pass 6, stride 16 iteration 1 (`occupied_r_p99_abs=0.18359375`, `occupied_r_max_abs=0.234375`, 61 over-gate occupied samples) and peaks by pass 10 (`occupied_r_p99_abs=0.30126953125`, 249 over-gate samples). Modes 1/2 suppress broad stride-16 p99 drift but still have local max errors from pass 6, then fail p99 by pass 8 and peak p99 at pass 15. Primary target `(82, 47)` reaches a pressure delta `2.140625` at pass 15 and remains the generated primary max-angle point; modes 1/2 fix `(82, 47)` but introduce the `(61, 67)` max-angle tail, with pressure delta `0.3671875` at pass 20 and final generated angle `18.2393832633789 deg`. Primary occupied G/R failures cluster around tiles 4/3 and 6/7; mode 2 moves most occupied G/R failures into tile 5 `(42, 63)`, proving the source-edge model is over-applied for generated-output tail risk. Continue with pass-index/stride-iteration evidence rather than promoting a global rule.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the stack/canvas-tie diagnostic and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added the full pass-6 grid choice arrays to `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd`. Added an opt-in `pressure_jacobi_canvas_tie_mode=1` diagnostic to the production-shaped compute projection path and ran it from the stack probe as a separate non-replacing candidate. Reran the stack probe to `res://.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic`, reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/surface`, compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized, and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-canvas-tie-diagnostic surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the unchanged non-replacing stack/skeleton/surface guards and the opt-in canvas-tie diagnostic execution; partial/fail remains for primary and canvas-tie compute-pressure generated-output correctness. The candidate remains non-replacing and keeps `R7_TOLERANCE_V1` unchanged.
- Notes or follow-up: The canvas-tie candidate reduced broad error (`p95_angle=3.02500924801543 deg`, weighted mean `0.60170081393187 deg`) but worsened tail risk (`p99_angle=5.96108559105589 deg`, max `18.2393832633789 deg`) and kept occupied R/G p99 failures. Treat it as evidence that stride-16 tie handling matters, not as an accepted compatibility model.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the stack audit and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Re-read the R7 docs, legacy filter shaders, `FilterRenderer`, `RiverFlowmapBaker`, `RiverManager`, `WaterHelperMethods`, the compute backend, and the stack probe. Added a probe-only 25-point pass-6 vertical sampler grid to `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd` while preserving the existing five-point sampler fields. Reran the stack probe with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2`; reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/skeleton-rerun`; reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/surface`; compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized; and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Visible result, if applicable: Rendered console probe only; no human editor or water-material visual review was performed.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-legacy-audit-grid2 surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the unchanged non-replacing stack marker and the new grid diagnostic; partial/fail remains for primary compute-pressure generated-output correctness. The run preserved empty output texture keys, `production_output_replaced=false`, delayed single-submit/wait/sync/readback, and async readback blocked. The generated primary candidate remains unchanged: p95 angle `3.48932145236808 deg`, p99 angle `5.48129340327964 deg`, max angle `12.4395520353247 deg`, weighted mean angle `0.76174545540638 deg`, strong-magnitude p95 angle `2.12881948668782 deg`, tile-inner 1px p95 angle `3.54360459424017 deg`, occupied G p99 `0.00784313678741`, and occupied R p99 `0.00392159819603`.
- Notes or follow-up: Legacy shader intent is coherent, but the pass-6 half-texel vertical sampler behavior is a canvas-renderer artifact rather than a Jacobi rule. The grid diagnostic reports up/down lower/upper counts `16/9`, compute floor-model matches `10/25` up and `9/25` down, and the simple ColorRect diagonal model matches `22/25` in both directions with mismatches at `(10, 63)`, `(31, 63)`, and `(53, 63)`. Do not hard-code a diagonal rule into the backend based on this evidence. Keep `R7_TOLERANCE_V1` unchanged; accepting compute divergence as an improvement requires visual artifact evidence and explicit texture/channel rationale.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the stack gate-audit probe and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added diagnostic-only decoded-flow audit metrics to `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd`: p99 angle, weighted mean angle, endpoint deltas, magnitude buckets, tile-edge buckets, and max-angle records. The `R7_TOLERANCE_V1` pass/fail thresholds were not changed. Reran the stack probe to `res://.codex-research/r7-baselines/compute-solve-stack-final`, reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-final/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-final/surface`, compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized, and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-final/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-final/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-final surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the unchanged non-replacing stack/skeleton/surface guards; partial/fail remains for the primary compute-pressure generated candidate under `R7_TOLERANCE_V1`. The run preserved empty output texture keys, `production_output_replaced=false`, delayed single-submit/wait/sync/readback, and async readback blocked.
- Notes or follow-up: The gate audit keeps `R7_TOLERANCE_V1` unchanged. The added diagnostics show generated `flow_foam_noise` failures are not solely low-magnitude, 1px tile-edge, or padding artifacts, although the largest whole-image G delta is in padding. Add future investigative reports around pressure-feedback drift, but do not relax the final replacement gate without visual artifact evidence and a named tolerance revision.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the stack/sampler diagnostic and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added a controlled legacy `FilterRenderer.apply_flow_pressure_jacobi` sampler diagnostic to `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd`. The diagnostic runs the real canvas shader at pass-6 conditions (`stride=16`, `source_size=64`, `texture_size=106x106`, `atlas_columns=5`) with uniquely encoded up-neighbor, down-neighbor, and horizontal-wall center pressure texels. Reran the stack probe to `res://.codex-research/r7-baselines/compute-solve-stack-final`, reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-final/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-final/surface`, compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized, and ran `git diff --check`.
- Output or parser errors: The first stack run caught one parse-only GDScript inference issue in the new helper (`column_min` needed an explicit float type); after that patch, no parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-final/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-final/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-final surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the existing stack marker and controlled sampler diagnostic; partial/fail remains for primary compute-pressure generated-output correctness. The run preserved 44 dispatches, one compute list, 43 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, `production_output_replaced=false`, empty output texture keys, and async readback blocked.
- Notes or follow-up: The sampler diagnostic recorded exact pass-6 choices with zero choice delta. On the 106-wide padded texture the stride-16 offset is `26.5` texels. Up-neighbor choices were lower/upper `3/2` across five probe points, down-neighbor choices were lower/upper `3/2`, and the current compute floor model matched only `1/5` up choices and `2/5` down choices. Horizontal stride-16 reads matched atlas-wall center pressure at all five probe points (`horizontal_wall_match_count=5`). This proves the legacy canvas behavior is not one global floor/ceil/tie rule; the next pressure-feedback patch should account for spatially mixed canvas UV/tie behavior instead of retrying uniform sample biases.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the pressure-feedback retry and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Retried the non-replacing expanded projection path behind `RiverFlowmapBaker` while preserving RGBA8 sampled inputs where available, using a dynamic pressure-Jacobi stride storage buffer, adding explicit `textureLod(..., 0.0)` pressure/divergence/occupancy reads, and adding probe diagnostics for signed deltas, max-delta coordinates, and per-pass legacy pressure capture. Ran `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-solve-stack-final`. Then reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-final/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-final/surface`, compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized, and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-final/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-final/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-final surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the existing pressure-stack marker and legacy-pressure outer-pass diagnostic; partial/fail for primary compute-pressure generated-output correctness. The run preserved 44 dispatches, one compute list, 43 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, `production_output_replaced=false`, and empty output texture keys.
- Notes or follow-up: Primary compute-pressure projection still fails legacy `R7_TOLERANCE_V1`, but explicit LOD reduced the generated candidate from p95/max angle `3.60344260089818/16.9067074883773 deg` to `3.48932145236808/12.4395520353247 deg`. Occupied G p99 remains `0.00784313678741`; occupied R p99 is now `0.00392159819603`. Reverted or rejected attempts included texelFetch/tie/edge-UV/bias variants, half-like base UV, split lists, fresh pressure texture per pass, RGBA32F projection pressure, linear pressure sampling, divergence scale and iteration-count tweaks, candidate RGBA8 output, and small output/channel biases. Keep these as legacy diagnostics; future replacement must pass either legacy parity or `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the expanded projection and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added non-replacing compute divergence, pressure-stack, gradient subtract, and two boundary tangency passes behind `RiverFlowmapBaker`, then ran `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-solve-stack-next`. The probe bakes the low-cost fixture through the legacy path, captures projection inputs/intermediates, runs the primary compute-pressure projection candidate, runs a legacy-pressure diagnostic candidate, runs the final combine and baker image postprocess for generated `flow_foam_noise` candidates, and verifies RiverManager texture IDs/hashes stay unchanged. Then reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-next/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-next/surface`, compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized, and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-next/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-next/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-next/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-next/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-next surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the existing pressure-stack marker and for the new legacy-pressure outer-pass diagnostic; partial for primary compute-pressure generated-output correctness. Both projection runs recorded 44 dispatches, one compute list, 43 `compute_list_add_barrier()` calls, one submit, delayed wait/sync/readback, `production_output_replaced=false`, and empty output texture keys.
- Notes or follow-up: Primary compute-pressure projection still fails legacy `R7_TOLERANCE_V1`: generated candidate p95 angle `3.60344260089818 deg`, max angle `16.9067074883773 deg`, occupied R/G p99 `0.00784313678741`. The legacy-pressure diagnostic passes the same final generated-output gate after combine/postprocess: generated candidate p95 angle `0`, max angle `0`, occupied R/G p99 `0`; intermediate projection parity also passes with final-flow p95 angle `0` and max angle `0.50106726654548 deg`. This proves divergence, gradient subtract, boundary tangency, final combine, and postprocess are not the current blocker. Future replacement must pass either legacy parity or `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the pressure-Jacobi stack and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added a non-replacing production-shaped pressure-Jacobi stack entry point behind `RiverFlowmapBaker` and `river_flowmap_compute_backend.gd`, then ran `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-solve-stack`. The probe first baked `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn` through the legacy path in memory, captured all six RiverManager-owned generated texture IDs and hashes, ran the compute pressure stack over a deterministic synthetic fixture, ran a legacy `FilterRenderer.apply_flow_pressure_jacobi` multi-pass intermediate over the same fixture, then verified RiverManager texture IDs and hashes were unchanged. Then reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack/skeleton-rerun`, reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack/surface`, and compared against `.codex-research/r6-baselines/post-r6-final`, normalizing only public method/signal line numbers.
- Output or parser errors: No parser errors. The stack probe wrote `.codex-research/r7-baselines/compute-solve-stack/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Rendered console probe only; no human editor interaction.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=r7-compute-solve-stack surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the non-replacing production-shaped pressure-Jacobi stack proof. The backend created two RGBA32F pressure storage textures plus divergence and occupancy storage textures, ran the real low-cost fixture schedule `[32, 16, 8, 4, 2, 1, 1, 1]` with 5 iterations per stride, recorded 40 Jacobi dispatches inside one compute list, inserted 39 `compute_list_add_barrier()` calls for same-list read-after-write dependencies, submitted once, waited 3 process frames, called `sync()`, and read back once through `texture_get_data()`. The stack remained report-only: `production_output_replaced=false`, output texture keys stayed empty, and legacy RiverManager texture IDs and hashes stayed unchanged before/after the compute and legacy-intermediate comparisons.
- Notes or follow-up: The accepted stack gate is `R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1`, a pressure-intermediate tolerance for accumulated f32 compute versus legacy f16 shader feedback. The compute-vs-legacy stack comparison recorded encoded max delta `0.03020256757736`, encoded p99 delta `0.02548497915268`, encoded mean delta `0.00685449554089`, pressure max delta `0.96648216247559`, pressure p99 delta `0.81551933288574`, and pressure mean delta `0.21934385730856`. This does not relax final generated texture `R7_TOLERANCE_V1`; the later expanded projection diagnostic is recorded above and narrows the remaining blocker to primary compute-pressure generated-output parity.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the compute solve/filter step and skeleton rerun; headless for the R6 surface/property dump.
- Command, scene, or workflow: Updated `river_flowmap_compute_backend.gd` so the non-replacing production-shaped pressure-Jacobi proof matches `flow_pressure_jacobi_pass.gdshader` semantics for pressure/divergence encoding, solid cells, source-size stride, atlas-column wall padding, y clamp, and Neumann wall behavior. Updated `res://addons/waterways/probes/r7_compute_solve_filter_step_probe.gd` to run a tiny one-step legacy `FilterRenderer.apply_flow_pressure_jacobi` intermediate against the same synthetic pressure/divergence/occupancy fixture. Ran it with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-solve-filter`. The probe first baked `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn` through the legacy path in memory, hashed all six RiverManager-owned generated textures, ran one RGBA32F storage-image compute dispatch, waited 3 process frames, called `sync()`, read back through `texture_get_data()`, compared against a deterministic legacy-UV CPU pressure-Jacobi reference, ran the legacy shader parity pass, then verified the RiverManager texture IDs and hashes were unchanged. Then reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-filter/parity-surface` and compared against `.codex-research/r6-baselines/post-r6-final`, normalizing only public method/signal line numbers. Reran the previous compute skeleton probe to `res://.codex-research/r7-baselines/compute-solve-filter/skeleton-rerun2`.
- Output or parser errors: No parser errors. The solve/filter probe wrote `.codex-research/r7-baselines/compute-solve-filter/r7_compute_solve_filter_step.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Rendered console probe only; no human editor interaction.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STEP_OK report=res://.codex-research/r7-baselines/compute-solve-filter/r7_compute_solve_filter_step.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-filter/parity-surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=r7-compute-solve-filter-parity surface_line_numbers=normalized`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-filter/skeleton-rerun2/r7_compute_backend_skeleton.txt`; parser scratch marker `R7_COMPILE_CHECK_OK`; `git diff --check` exit 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Pass/partial/fail: Pass for the first isolated non-replacing solve/filter compute step after legacy-shader semantics confirmation. The backend created local RGBA32F storage textures, confirmed RGBA32F storage/sampling/copy usage support, dispatched one pressure-Jacobi compute list, submitted once, waited 3 process frames, called `sync()`, read back through `texture_get_data()`, and matched the legacy-UV CPU reference with encoded max delta `0.0000000478363`, encoded p99 delta `0.00000004108429`, pressure max delta `0.00000153076173`, and pressure p99 delta `0.00000131469727`. The same fixture run through `flow_pressure_jacobi_pass.gdshader` matched with f16-sized deltas: encoded max `0.000486875`, encoded p99 `0.000483125`, pressure max `0.01558`, and pressure p99 `0.01546`. The deterministic fixture covered 232 active pixels, 24 solid pixels, 353 atlas-wall neighbor cases, including 232 cross-column wall cases and 121 padding-wall cases, plus 34 solid-neighbor cases. Legacy RiverManager generated texture IDs and MD5 hashes remained unchanged before/after compute and legacy-intermediate parity.
- Notes or follow-up: This is an isolated pressure-Jacobi step proof, not full generated bake texture replacement. The step deliberately returns no output texture keys and leaves `production_output_replaced=false`. A later pressure-Jacobi stack proof is now recorded above; the remaining solve/filter work is divergence, gradient subtract, and boundary tangency compute, still using non-replacing comparisons until full generated output replacement is explicitly accepted.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT for the compute skeleton probe; headless for the R6 surface/property dump.
- Command, scene, or workflow: Added `river_flowmap_compute_backend.gd`, wired it as a `RiverFlowmapBaker`-owned non-replacing backend proof path, and ran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA`, output `res://.codex-research/r7-baselines/compute-skeleton`. Then reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-skeleton/surface` and compared the output against `.codex-research/r6-baselines/post-r6-final`, normalizing only public method/signal line numbers.
- Output or parser errors: No parser errors. The compute skeleton probe wrote `.codex-research/r7-baselines/compute-skeleton/r7_compute_backend_skeleton.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Rendered console probe only; no human editor interaction.
- Stable result marker: `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-skeleton/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-skeleton/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=r7-compute-skeleton surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the non-replacing production compute backend skeleton. The backend created a local RenderingDevice, confirmed RGBA16F/RGBA32F storage texture format support, recorded 9 ping-pong compute lists, submitted once, waited 3 process frames, called `sync()`, read back through `buffer_get_data()`, matched the expected checksum, and completed idempotent cleanup/abort calls. It did not replace or expose any generated bake textures.
- Notes or follow-up: The skeleton deliberately avoids same-list read-after-write dependencies, so `compute_list_add_barrier()` is not needed in this proof path. Later isolated pressure-Jacobi, multi-pass pressure-stack, canonical acceptance, and low-cost non-replacing cleanup/heartbeat proofs are now recorded above. At the time of the skeleton run, full production compute correctness, production cleanup/abort around active bake replacement, responsiveness comparison, and output replacement were unrun; production replacement remains blocked by the latest gates above.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Confirmed `.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt` exists, then ran `res://addons/waterways/probes/r7_texture_format_roundtrip_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA` and `out=res://.codex-research/r7-baselines/format`.
- Output or parser errors: No parser errors. The probe printed the expected legacy decoded flow diagnostics for two fixture bakes and wrote `.codex-research/r7-baselines/format/r7_texture_format_roundtrip.txt`.
- Visible result, if applicable: Rendered console probe only; no human editor interaction.
- Stable result marker: `R7_TOLERANCE_SELF_COMPARE_OK textures=6 out=res://.codex-research/r7-baselines/format` and `R7_TEXTURE_FORMAT_ROUNDTRIP_OK formats=2 out=res://.codex-research/r7-baselines/format`.
- Pass/partial/fail: Pass for tolerance/self-compare and RD texture-format round-trip evidence. Production compute output comparison remains unrun because no production compute replacement exists yet.
- Notes or follow-up: The report proves both RGBA16F and RGBA32F storage-image write/readback to `Image`/`ImageTexture` stay inside `R7_TOLERANCE_V1` semantic gates. RGBA16F is acceptable for the first compute prototype unless a future production texture comparison finds a slice-specific failure.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Ran `res://addons/waterways/probes/r7_rendering_device_sync_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA`, `iterations=97`, `repeats=20`, and `out=res://.codex-research/r7-baselines/sync`.
- Output or parser errors: No parser errors. Initial development runs exposed two useful installed-RD constraints: repeated `submit()` without `sync()` prints `device already submitted`, and cleanup must free dependent RIDs before parent resources. The final recorded run was clean.
- Visible result, if applicable: Rendered console probe only; no human editor interaction.
- Stable result marker: `R7_RENDERING_DEVICE_SYNC_OK report=res://.codex-research/r7-baselines/sync/r7_rendering_device_sync.txt`.
- Pass/partial/fail: Pass for standalone RD sync/readback stress using delayed single-submit/wait/sync/readback and idempotent cleanup. Async readback is explicitly not selected because the callback did not arrive within 180 frames in this probe.
- Notes or follow-up: The no-barrier intra-list dependent dispatch was report-only and failed to match expected values. Future production code that batches dependent read-after-write dispatches in one compute list must use `compute_list_add_barrier()`; otherwise split dependencies to avoid same-list hazards.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Ran `res://addons/waterways/probes/r7_bake_baseline_probe.gd` against `res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn`, river `Water River`, with repo-local `APPDATA`/`LOCALAPPDATA`, `warmup=1`, `runs=5`, `save=false`, and output `res://.codex-research/r7-baselines/legacy`.
- Output or parser errors: No parser errors. Each run printed the expected occupied/unused decoded flow-vector diagnostics. No generated resources were saved in place; `bake_data.resource_path` stayed empty.
- Visible result, if applicable: Rendered console probe only; no human editor interaction.
- Stable result marker: `R7_LEGACY_BASELINE_OK runs=5 median_ms=2493.424 out=res://.codex-research/r7-baselines/legacy`.
- Pass/partial/fail: Pass for the R7 legacy baseline fixture/probe slice only. At that time compute correctness, format round-trip, sync/readback stress, cleanup/abort, and compute replacement were unrun; later validation-only format and sync gates are recorded above. Production compute correctness, production cleanup/abort, and compute replacement remain unrun.
- Notes or follow-up: Baseline proof file is `.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt`. It records collision coverage `407 / 4096` pixels (`9.9365234375%`), `support_fallback_applied=false`, `collision_support_filters_ran=true`, `water_occupancy_baked=true`, `obstacle_avoidance_applied=true`, `flow_projected=true`, `flow_speed_scaled=false`, the historical v28 source signature row, water occupancy solid/proximity coverage, obstacle feature coverage, occupied flow diagnostics, all generated texture hashes, public projection labels `0/40` through `35/40`, pass trace count `56`, `flow pressure jacobi pass=40`, `boundary tangency flow map=2`, final combine counts, and RiverManager result handoff (`valid_flowmap`, material bindings, and river texture fields all true). Legacy heartbeat budget from the final run set: max frame gap was 93.438 ms, max p95 frame gap was 43.415 ms, and all runs stayed below the 1000 ms hard stop.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent (R7 template-compliance pass)
- Godot version/renderer/device: n/a, documentation-only pass
- Command, scene, or workflow: Read `addons/waterways/docs/spec-driven/templates/feature-folder/`; compared the template docs with the R7 folder; added missing `tasks.md`, `review.md`, and `session-handoff.md`; updated R7 read-order/docs-gate wording to reference the full local doc set.
- Output or parser errors: n/a
- Visible result, if applicable: n/a
- Stable result marker: documentation-only; no code marker
- Pass/partial/fail: Pass for R7 feature-folder template completion.
- Notes or follow-up: Parent river-refactor docs remain canonical for track-wide roadmap/history. R6 docs are referenced as dependency evidence for preserved ownership/result-handoff boundaries, not duplicated into R7.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent (R7 docs gate)
- Godot version/renderer/device: n/a, documentation-only gate
- Command, scene, or workflow: Created R7 docs and recorded the compute-first decision: fold R7 into feature-roadmap Phase 5 RenderingDevice compute migration and skip the SubViewport-resident interim.
- Output or parser errors: n/a
- Visible result, if applicable: n/a
- Stable result marker: documentation-only; no code marker
- Pass/partial/fail: Pass for docs-gate creation.
- Notes or follow-up: Before implementation, research current official Godot RenderingDevice docs and add the exact baseline/fixture commands here.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent (R7 planning/research session)
- Godot version/renderer/device: Official documentation review plus installed Godot 4.6.3 console. Runtime scratch check: Forward+/Vulkan, AMD Radeon RX 6800 XT; headless scratch check confirmed local/global RD unavailable.
- Command, scene, or workflow: Reviewed official Godot 4.6 RenderingDevice, RenderingServer, and compute shader documentation; dumped installed 4.6.3 API metadata into `.codex-research`; ran scratch `.codex-research/r7_rd_runtime_check.gd` windowed and headless; updated R7 docs with fixture-proof gates, exact API names/signatures, texture-format support, barrier nuance, timing method, tolerance gate, sync/readback stress plan, and editor-heartbeat strategy.
- Output or parser errors: No parser errors. The scratch windowed run reported global/local RD available and `R16G16B16A16_SFLOAT` plus `R32G32B32A32_SFLOAT` supported for storage/sampling/copy usage; the scratch headless run reported both RDs unavailable, as expected.
- Visible result, if applicable: n/a
- Stable result marker: `R7_RD_RUNTIME_CHECK_OK` from scratch-only API/runtime check. At the time, no shipped R7 validation marker existed.
- Pass/partial/fail: Pass for R7.1 planning research and local API/format spot-check. At the time, R7 implementation remained unstarted and shipped fixture/probe/baseline were still unrun.
- Notes or follow-up: The planned low-cost fixture/probe follow-up was completed later by the baseline slice recorded above; compute replacement remains unstarted.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable official; Forward+/Vulkan; AMD Radeon RX 6800 XT.
- Command, scene, or workflow: Added dense pass-6 scanline/y-band sampler diagnostics, source-edge model counters, and an opt-in `pressure_jacobi_canvas_tie_mode=2` diagnostic candidate. Ran `res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA` and `out=res://.codex-research/r7-baselines/compute-solve-stack-source-edge-final`; reran `res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-source-edge-final/skeleton-rerun`; reran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` to `res://.codex-research/r7-baselines/compute-solve-stack-source-edge-final/surface`; compared against `.codex-research/r6-baselines/post-r6-final` with public method/signal line numbers normalized; and ran `git diff --check`.
- Output or parser errors: No parser errors. The stack/projection probe wrote `.codex-research/r7-baselines/compute-solve-stack-source-edge-final/r7_compute_solve_filter_stack.txt`. The surface dump repeated the known non-fatal `Demo.tscn` invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. `git diff --check` exited 0 with only the existing CRLF warning for `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`.
- Stable result marker: `R7_COMPUTE_SOLVE_FILTER_STACK_OK report=res://.codex-research/r7-baselines/compute-solve-stack-source-edge-final/r7_compute_solve_filter_stack.txt`; skeleton regression rerun `R7_COMPUTE_BACKEND_SKELETON_OK report=res://.codex-research/r7-baselines/compute-solve-stack-source-edge-final/skeleton-rerun/r7_compute_backend_skeleton.txt`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r7-baselines/compute-solve-stack-source-edge-final/surface files=10`; `R7_R6_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-final current=compute-solve-stack-source-edge-final surface_line_numbers=normalized`.
- Pass/partial/fail: Pass for the unchanged non-replacing stack/skeleton/surface guards and source-edge diagnostic execution; partial/fail remains for primary and diagnostic compute-pressure generated-output correctness.
- Notes or follow-up: The controlled sampler tables are exactly fit by `upper when point.x < point.y except source_size - 1 row, otherwise lower` (`25/25` grid, `95/95` scanline, `209/209` y-band, both up and down). The source-edge candidate is still diagnostic-only: generated p95/weighted mean improved to `2.81378265972502 deg`/`0.51408882340789 deg`, but p99 stayed worse than primary at `5.71058370749061 deg`, max stayed `18.2393832633789 deg`, angle-over-10 count rose to `7`, and occupied G/R p99 remained `0.00784313678741`/`0.00392159819603`.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent (R7 adversarial plan review)
- Godot version/renderer/device: Official Godot 4.6 documentation re-check plus installed Godot 4.6.3 console. Windowed runtime: Forward+/Vulkan, AMD Radeon RX 6800 XT. Headless runtime: no local/global RD.
- Command, scene, or workflow: Re-read parent/R7/R6 docs, rechecked official RenderingDevice/RenderingServer/compute shader documentation, reran scratch `.codex-research/r7_rd_runtime_check.gd` windowed and headless, grepped the legacy bake path and diagnostic/progress consumers, and updated R7 docs only. No addon code, shipped probes, shaders, scenes, or bake resources were edited.
- Output or parser errors: No parser errors. Windowed scratch run reported local/global RD available, limits logged, and both candidate RGBA f16/f32 formats supported for storage/sampling/copy usage. Headless scratch run reported local/global RD unavailable, matching docs.
- Visible result, if applicable: n/a.
- Stable result marker: `R7_RD_RUNTIME_CHECK_OK` from scratch-only runtime checks. At the time, no shipped R7 validation marker existed.
- Pass/partial/fail: Pass for adversarial plan-review documentation hardening. At the time, R7 implementation remained unstarted and fixture/probe/baseline/sync/format probes were unrun.
- Notes or follow-up: The first implementation slice later added only the low-cost fixture/probe and recorded the legacy baseline above. Later validation-only format and sync gates are recorded above; production cleanup/abort and compute replacement remain unrun.

## Artifact Hygiene

- Scratch project or temporary folder used: `.codex-research/r7-api/`, `.codex-research/r7-api-docs/`, `.codex-research/r7_rd_runtime_check.gd`, `.codex-research/r7_api_introspection.gd`, `.codex-research/godot-user-r7-review/`, `.codex-research/godot-user-r7-review-headless/`, `.codex-research/godot-user-r7-api-dump/`, `.codex-research/godot-user-r7-adversarial-review/`, `.codex-research/godot-user-r7-adversarial-review-headless/`, `.codex-research/godot-user-r7/`, `.codex-research/godot-user-r7-trace-check/`, `.codex-research/godot-user-r7-parser/`, `.codex-research/godot-user-r7-format/`, `.codex-research/godot-user-r7-sync/`, `.codex-research/godot-user-r7-compute-skeleton/`, `.codex-research/godot-user-r7-surface/`, `.codex-research/godot-user-r7-compute-solve-parser/`, `.codex-research/godot-user-r7-compute-solve/`, `.codex-research/godot-user-r7-compute-solve-surface/`, `.codex-research/godot-user-r7-compute-solve-skeleton-rerun/`, `.codex-research/godot-user-r7-compute-solve-stack/`, `.codex-research/godot-user-r7-legacy-audit-stack/`, `.codex-research/godot-user-r7-legacy-audit-grid/`, `.codex-research/godot-user-r7-legacy-audit-grid2/`, `.codex-research/godot-user-r7-legacy-audit-grid3/`, `.codex-research/godot-user-r7-canvas-tie-diagnostic/`, `.codex-research/godot-user-r7-canvas-tie-skeleton/`, `.codex-research/godot-user-r7-canvas-tie-surface/`, `.codex-research/r7-baselines/legacy-smoke/`, `.codex-research/r7-baselines/legacy/`, `.codex-research/r7-baselines/format/`, `.codex-research/r7-baselines/sync/`, `.codex-research/r7-baselines/compute-skeleton/`, `.codex-research/r7-baselines/compute-solve-filter/`, `.codex-research/r7-baselines/compute-solve-stack/`, `.codex-research/r7-baselines/compute-solve-stack-next/`, `.codex-research/r7-baselines/compute-solve-stack-final/`, `.codex-research/r7-baselines/compute-solve-stack-legacy-audit/`, `.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid/`, `.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid2/`, `.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid3/`, and `.codex-research/r7-baselines/compute-solve-stack-canvas-tie-diagnostic/`.
- Additional source-edge diagnostic scratch/report folders used: `.codex-research/godot-user-r7-y-band/`, `.codex-research/godot-user-r7-source-edge/`, `.codex-research/godot-user-r7-source-edge-final/`, `.codex-research/godot-user-r7-source-edge-final-verify/`, `.codex-research/godot-user-r7-source-edge-skeleton/`, `.codex-research/godot-user-r7-source-edge-surface/`, `.codex-research/r7-baselines/compute-solve-stack-y-band/`, `.codex-research/r7-baselines/compute-solve-stack-source-edge-tie/`, and `.codex-research/r7-baselines/compute-solve-stack-source-edge-final/`.
- Additional pass-prefix diagnostic scratch/report folders used: `.codex-research/godot-user-r7-prefix-diagnostic/`, `.codex-research/godot-user-r7-prefix-diagnostic-skeleton/`, `.codex-research/godot-user-r7-prefix-diagnostic-surface/`, and `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/`.
- Additional `FRAGCOORD` diagnostic scratch/report folders used: `.codex-research/godot-user-r7-fragcoord-diagnostic/` and `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/`.
- Additional canonical-acceptance scratch/report folders used: `.codex-research/godot-user-r7-canonical-acceptance/`, `.codex-research/godot-user-r7-canonical-acceptance-skeleton/`, `.codex-research/godot-user-r7-canonical-acceptance-surface/`, and `.codex-research/r7-baselines/compute-canonical-acceptance/`.
- Additional cleanup/selection/representative-visual/staging/production-validation scratch/report folders used: `.codex-research/godot-user-r7-compute-cleanup-responsiveness/`, `.codex-research/godot-user-r7-compute-selection-abort/`, `.codex-research/godot-user-r7-selection-abort-surface/`, `.codex-research/godot-user-r7-representative-visuals/`, `.codex-research/godot-user-r7-generated-output-replacement-staging/`, `.codex-research/godot-user-r7-generated-output-replacement-staging-rerun/`, `.codex-research/godot-user-r7-production-replacement-validation/`, `.codex-research/godot-user-r7-production-replacement-validation-surface/`, `.codex-research/godot-user-r7-compute-selection-abort-rerun/`, `.codex-research/r7-baselines/compute-cleanup-responsiveness/`, `.codex-research/r7-baselines/compute-selection-abort/`, `.codex-research/r7-baselines/compute-representative-visuals/`, `.codex-research/r7-baselines/compute-generated-output-replacement-staging/`, and `.codex-research/r7-baselines/compute-production-replacement-validation/`.
- Generated bakes/resources created: none saved in shipped paths. The R7 fixture generated in-memory RiverBakeData during windowed console runs and wrote text baseline reports only under `.codex-research/r7-baselines/`. The compute skeleton probe wrote only text reports and R6 surface dumps under `.codex-research/r7-baselines/compute-skeleton/`. The solve/filter step probe wrote a text report, an R6 surface dump, and a skeleton regression report under `.codex-research/r7-baselines/compute-solve-filter/`. The solve/filter stack/projection/prefix probes wrote text reports, R6 surface dumps, and skeleton regression reports under `.codex-research/r7-baselines/compute-solve-stack*/`. The canonical acceptance run wrote a text report, skeleton rerun, R6 surface dump, and five PNG review artifacts under `.codex-research/r7-baselines/compute-canonical-acceptance/`. The representative visual run wrote one text report, 7 screenshots, and 6 texture-space crops under `.codex-research/r7-baselines/compute-representative-visuals/`. The generated-output staging and production-validation runs wrote text reports plus a surface dump under `.codex-research/r7-baselines/compute-*-replacement-*/`.
- Files or folders that must be excluded from packaging: the standing `.codex-research/` rule covers all scratch API/runtime outputs.
- Files or folders safe to delete now: the R7 scratch API/runtime check outputs, `legacy-smoke` baseline, `godot-user-r7-compute-skeleton`, `godot-user-r7-surface`, and `godot-user-r7-compute-solve-*` profiles above are disposable because the key results are recorded in `research.md` and this file. Keep `.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt`, `.codex-research/r7-baselines/compute-solve-filter/r7_compute_solve_filter_step.txt`, `.codex-research/r7-baselines/compute-solve-stack/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/r7_compute_solve_filter_stack.txt`, `.codex-research/r7-baselines/compute-canonical-acceptance/`, `.codex-research/r7-baselines/compute-cleanup-responsiveness/r7_compute_cleanup_responsiveness.txt`, `.codex-research/r7-baselines/compute-selection-abort/r7_compute_selection_abort.txt`, `.codex-research/r7-baselines/compute-representative-visuals/`, `.codex-research/r7-baselines/compute-generated-output-replacement-staging/r7_compute_generated_output_replacement_staging.txt`, and `.codex-research/r7-baselines/compute-production-replacement-validation/r7_compute_production_replacement_validation.txt` until the replacement-code enablement pass supersedes them.
