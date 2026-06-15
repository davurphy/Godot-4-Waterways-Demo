# Shared Probes

General-purpose, reusable validation and diagnostic scripts. Feature-specific
probes (with feature-specific gates) stay in their feature folders under
`docs/spec-driven/features/*/probes/`; anything here is cross-feature
infrastructure.

## Run pattern

```powershell
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
& $godotConsole --path $root --script res://addons/waterways/probes/<probe>.gd -- key=value key=value
```

- User args go after a `--` separator, as `key=value` (quote the whole arg if the value has spaces).
- **Bakes and screenshots need a rendered window** — do not pass `--headless` to those probes.
- Pure resource reads are headless-safe — add `--headless`.
- Outputs land in `out/` (gitignored).

## River-refactor R6/R7 audit

Last updated: 2026-06-15.

Recent cleanup:

- `r6_baseline_dump_probe.gd` was generalized as `river_surface_snapshot_probe.gd`.
- `r6_source_image_hash_probe.gd` was generalized as `river_source_image_hash_probe.gd`.
- `r7_bake_baseline_probe.gd` was generalized as `r7_legacy_canvas_item_bake_trace_probe.gd`.
- `r7_texture_format_roundtrip_probe.gd` was generalized as `r7_texture_format_and_tolerance_probe.gd`.
- The old filenames remain as compatibility wrappers so historical R6/R7 commands still resolve.
- The two R7 legacy fixture probes now explicitly force `legacy_canvas_item`, record backend selection, and assert that compute did not replace production output.
- `R7_TOLERANCE_V1` remains the tolerance gate. Do not introduce `R7_TOLERANCE_V2`.

Deleted from active shared probes on 2026-06-15: legacy R6/R7 wrappers and
archived historical/diagnostic probes whose evidence is preserved in
`.codex-research/` and the river-refactor validation logs. Keep
`r7_compute_generated_output_replacement_staging_probe.gd` for now because the
current production replacement validation probe still extends it as a helper
base.

### Keep as durable validation

| Probe | Keep because |
| --- | --- |
| `river_surface_snapshot_probe.gd` | Current RiverManager public surface, signals, properties, and saved-bake dictionary snapshots. |
| `river_source_image_hash_probe.gd` | Current source-image helper ownership and raw-plus-margin source inventory. |
| `r6_constants_shadow_probe.gd` | Constants-table/source-signature policy guard, now following the current v29 constants. |
| `r6_editor_validation_probe.gd` | Editor validation wrapper and marker coverage. |
| `r6_abort_matrix_probe.gd` | Baker lifecycle, abort, cleanup, and error-path coverage. |
| `r7_legacy_canvas_item_bake_trace_probe.gd` | Explicit rollback/comparison path for `legacy_canvas_item`. |
| `r7_texture_format_and_tolerance_probe.gd` | `R7_TOLERANCE_V1` evidence plus RD texture format/readback proof. |
| `r7_rendering_device_sync_probe.gd` | RenderingDevice sync/readback behavior guard. |
| `r7_compute_selection_abort_probe.gd` | Current backend selection contract, default `canonical_compute_replacing`, explicit legacy availability, and abort cleanup. |
| `r7_compute_production_replacement_validation_probe.gd` | Replacement gate and production handoff report validation. |
| `r7_compute_non_neutral_flow_speed_probe.gd` | Accepted compute path coverage for authored non-neutral `flow_speeds`. |
| `r7_compute_saved_resource_load_smoke_probe.gd` | Promoted saved-resource load smoke without rebake/save. |
| `r7_compute_backend_performance_compare_probe.gd` | Heavy but useful explicit legacy-vs-compute performance comparison. |
| `r7_low_cost_bake_fixture.tscn` | Shared low-cost fixture for R7 validation. |

### Keep as helper dependency

| Probe | Status |
| --- | --- |
| `r7_compute_generated_output_replacement_staging_probe.gd` | Shared helper base for `r7_compute_production_replacement_validation_probe.gd`; not a routine standalone gate. |

### Keep, but dangerous or intentionally mutating

| Probe | Rule |
| --- | --- |
| `rebake_probe.gd` | Saves river bake resources and WaterSystem bake resources. Run only when explicitly regenerating bakes. |
### Removed from active shared probes

These names are intentionally historical after the 2026-06-15 cleanup:

| Removed probe | Replacement or retained evidence |
| --- | --- |
| `r6_baseline_dump_probe.gd` | Use `river_surface_snapshot_probe.gd`; old validation logs remain historical. |
| `r6_source_image_hash_probe.gd` | Use `river_source_image_hash_probe.gd`; old validation logs remain historical. |
| `r7_bake_baseline_probe.gd` | Use `r7_legacy_canvas_item_bake_trace_probe.gd`; old validation logs remain historical. |
| `r7_texture_format_roundtrip_probe.gd` | Use `r7_texture_format_and_tolerance_probe.gd`; old validation logs remain historical. |
| `r6_mid_bake_timing_probe.gd` | R6 timing evidence is archived under `.codex-research/r6-baselines/pre-r6/`. |
| `r7_compute_backend_skeleton_probe.gd` | Backend skeleton evidence is archived and superseded by production/selection probes. |
| `r7_compute_solve_filter_step_probe.gd` | Solve-step evidence is archived. |
| `r7_compute_solve_filter_stack_probe.gd` and `r7_flow_pressure_jacobi_fragcoord_probe.gdshader` | Stack, canonical-acceptance, and FRAGCOORD diagnostic evidence is archived. |
| `r7_compute_cleanup_responsiveness_probe.gd` | Cleanup/heartbeat evidence is superseded by selection/abort and final compute probes. |
| `r7_compute_promotion_fixture_coverage_probe.gd` | Promotion coverage evidence is archived. |
| `r7_compute_saved_output_promotion_probe.gd` | Saved-output promotion evidence is archived; do not rerun the mutating protocol without a new plan. |
| `r7_compute_representative_visual_probe.gd` | Visual review artifacts and notes are archived. |

## Probes

### `rebake_probe.gd` — regenerate bakes (window required)

The standard tool after a bake source signature bump. Bakes each scene's
river, saves the bake resource, regenerates + saves the WaterSystem map.
Feature probes layer gates on top (e.g. `river_obstacle_projection_rebake_probe`).

| Arg | Default | Meaning |
| --- | --- | --- |
| `scenes=` | `res://Demo.tscn,res://Demo_obstacle_flow_test.tscn` | comma-separated scene list |
| `river=` | `WaterSystem/Water River` | river node path in each scene |
| `save=` | `true` | save river bakes |
| `system=` | `WaterSystem` (first scene only) | WaterSystem node to regenerate; `none` skips |

Marker: `REBAKE_PROBE_OK`. Note: `generate_system_maps`' internal save is
editor-only and silently no-ops under `--script`; this probe saves explicitly
and prints `save_error`.

### `debug_view_capture_probe.gd` — visual review screenshots (window required)

Captures any debug view(s) either from a camera flown along the river curve
or from named review cameras in the scene. View list is read live from
`gui/debug_view_menu.gd`.

| Arg | Default | Meaning |
| --- | --- | --- |
| `views=` | `Flow Arrows` | id(s) or label substring(s), comma-separated; `list` prints all |
| `scene=` / `river=` | Demo.tscn / `WaterSystem/Water River` | |
| `cameras=` | (fly-along) | comma-separated Camera3D node paths in the scene |
| `stations=` / `height=` / `back=` | 8 / 7 / 6 | fly-along stops and camera offset |
| `label=` | | output subfolder (e.g. `before`, `after`) |
| `out=` | `res://addons/waterways/probes/out` | |

Marker: `DEBUG_VIEW_CAPTURE_OK`. Examples:

```powershell
-- views=list
-- views="Flow Arrows,Final Flow Strength" stations=4
-- views=58 scene=res://Demo_obstacle_flow_test.tscn label=after
-- views="foam mix" "cameras=Phase0B Review Cameras/Phase0B_RockGarden_Overhead"
```

### `bake_inspect_probe.gd` — channel stats + PNG (headless OK)

Decodes a channel of a saved bake (river or WaterSystem), prints distribution
stats and the channel's own metadata slug, dumps a grayscale PNG.

| Arg | Default | Meaning |
| --- | --- | --- |
| `bake=` | (required) | `.res` bake resource path |
| `texture=` | `flow_foam_noise` / `system_map` | texture property on the bake |
| `channel=` | `rg` for flow textures, else `r` | `r`,`g`,`b`,`a`, or `rg` (decoded flow vectors) |
| `png=` / `out=` | `true` / `out/` | |

Marker: `BAKE_INSPECT_OK`. Channel semantics reference:
`docs/spec-driven/features/river-future/Data Contract.md`.

### `river_flowmap_seam_probe.gd` — seam regression gate (headless OK)

UV2 atlas logical-edge continuity across all baked channels. Re-run whenever
flow bake content changes. `bakes=` overrides the default two demo bakes.
Marker: `RIVER_FLOWMAP_SEAM_PROBE_OK`. (Copy of the river-flowmap-seams probe.)

### `flow_arrow_neutral_cells_probe.gd` — dark arrow cells diagnosis (headless OK)

Classifies every neutral FLOW_ARROWS cell by root cause (solid collision /
solid protrusion / stilling ring / dead flow) and writes a color-coded
overlay PNG. `bake=` selects the river bake. (Copy of the
river-obstacle-flow-constraints probe; mirrors `river_debug.gdshader` constants —
keep in sync if the arrow logic changes.)

### `flow_arrow_direction_outlier_probe.gd` — wrong-direction arrows diagnosis (headless OK)

Flags FLOW_ARROWS cells whose displayed direction deviates strongly from
flowing neighbors and attributes each to bake data vs sub-cell fallback.
`bake=` selects the river bake. (Copy, same mirroring caveat as above.)

### `bake_hash_probe.gd` — bake content hash / diff (headless OK)

River-refactor RT.1. Hash mode emits a per-texture content hash for a
`RiverBakeData` (or system bake); diff mode (`a=`/`b=`) compares two bakes and
exits nonzero on mismatch with a per-channel delta summary and the bounding
rect of differing pixels. Consumers: R1 ("metadata-only"), R5/R6 ("byte-identical").
Markers: `BAKE_HASH_PROBE_OK` / `BAKE_HASH_COMPARE_OK` (mismatch: `BAKE_HASH_MISMATCH`).

### `river_surface_snapshot_probe.gd` - RiverManager surface and bake snapshot (headless OK)

Phase-neutral successor to `r6_baseline_dump_probe.gd`. Writes canonical
`source_metadata`, `source_signature`, and `bake_settings` dumps for the two
demo river bakes, filtering only `source_metadata.bake_revision`; also writes
the RiverManager public method surface, signal surface, and full demo
RiverManager property lists. Default output is
`res://addons/waterways/probes/out/river-surface-snapshot`; pass `out=` for
R6 historical comparison folders. Marker: `R6_BASELINE_DUMP_OK`.
Legacy alias: `r6_baseline_dump_probe.gd`.

### `river_source_image_hash_probe.gd` - source-image hash inventory (headless OK)

Phase-neutral successor to `r6_source_image_hash_probe.gd`. Mirrors
RiverManager's source-generation path, exercises the baker-owned source-image
helpers, and writes SHA-256 hashes for the full raw-plus-margin intermediate
source-image list for the Demo and obstacle Demo rivers, stopping before filter
renderer creation. Default output is
`res://addons/waterways/probes/out/river-source-images`; pass `out=` for R6
historical comparison folders. Marker: `R6_SOURCE_IMAGE_HASH_OK`.
Legacy alias: `r6_source_image_hash_probe.gd`.

### `r6_constants_shadow_probe.gd` - R6 constants-table shadow comparison (headless OK)

River-refactor R6.2. Compares old saved `source_metadata`, `source_signature`,
and `bake_settings` dictionaries plus live scene source signatures against
`river_bake_constants.gd` table-generated dictionaries, using the R6 canonical
dump rules and filtering only `source_metadata.bake_revision`. This does not
switch live dictionary generation. Marker: `R6_R62_CONSTANTS_SHADOW_OK`.

### `r6_editor_validation_probe.gd` - R6 editor validation markers (window required)

River-refactor R6.4. Checks the River menu validation signals, then calls
RiverManager's public `validate_data_textures()` and `validate_filter_renderer()`
wrappers directly on the Demo river. Use without `--headless` because filter
renderer readback needs a real viewport. Markers: `RIVER_DATA_TEXTURE_TEST`,
`FILTER_RENDERER_TEST`, and `R6_EDITOR_VALIDATION_PROBE_OK`.

### `r6_abort_matrix_probe.gd` - R6 abort matrix coverage (headless OK)

River-refactor R6.1H. Covers the automated abort/lifecycle buckets: duplicate
RiverManager and baker requests, repeated `abort()`, success cleanup, missing
renderer scene, forced invalid filter output, awaited renderer/Jacobi-labelled
cancellation, pre-renderer abort without partial generated-state overwrite,
scene close before renderer setup, terrain-contact helper node-free, and static
synchronous postprocess/result-application strategy checks. Marker:
`R6_R61H_ABORT_MATRIX_OK`. Expected warnings include duplicate request, missing
renderer scene, forced invalid output, and the known Demo invalid UID warning.

### `r7_legacy_canvas_item_bake_trace_probe.gd` - R7 explicit legacy bake trace (window required)

River-refactor R7. Bakes `r7_low_cost_bake_fixture.tscn` without saving
generated resources and records the explicit `legacy_canvas_item` pass trace,
timing, heartbeat, backend selection, metadata, texture hashes, and RiverManager
result handoff under `.codex-research/r7-baselines/legacy/`. Marker:
`R7_LEGACY_BASELINE_OK`. Legacy alias: `r7_bake_baseline_probe.gd`.

### `r7_texture_format_and_tolerance_probe.gd` - R7 tolerance and format proof (window required)

River-refactor R7. Confirms the recorded legacy baseline file exists, rebakes
the low-cost fixture twice through explicit `legacy_canvas_item` for self/rerun
tolerance metrics, then creates real RGBA16F/RGBA32F RenderingDevice storage
textures with storage/sampling/copy usage. The probe dispatches representative
writes, reads the storage image in a second dispatch, converts readback bytes to
`Image`/`ImageTexture`, and records decoded flow, pressure, and class-mask
metrics. Markers: `R7_TOLERANCE_SELF_COMPARE_OK` and
`R7_TEXTURE_FORMAT_ROUNDTRIP_OK`. Legacy alias:
`r7_texture_format_roundtrip_probe.gd`.

### `r7_rendering_device_sync_probe.gd` - R7 RD sync/readback stress (window required)

River-refactor R7. Stresses deterministic storage-buffer ping-pong dispatches,
stale binding/resource reuse, intra-list dependent dispatches with and without
`compute_list_add_barrier()`, delayed single-submit/wait/sync readback, attempted
async readback, and idempotent standalone RID cleanup. Marker:
`R7_RENDERING_DEVICE_SYNC_OK`. The recorded R7 run selects delayed sync/readback;
async readback is not selected because its callback did not arrive.

### `r7_compute_selection_abort_probe.gd` - R7 backend selection and active abort cleanup (window required)

River-refactor R7. Verifies the `flowmap_backend_mode` selection contract:
`canonical_compute_replacing` is the review default with accepted gate evidence,
explicit `legacy_canvas_item` remains available, canonical non-replacing compute
is still report-only, and explicit replacing compute without evidence still
falls back. It also verifies `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` keeps
minimum replacing signature version 29 and missing-evidence blockers when
staging/production evidence is not supplied. The probe also runs canonical
compute to completion, then
interrupts in-flight projection after submit through baker abort plus immediate
cleanup, owner free, and scene close. Each interrupted path must return
cancelled with zero owned RIDs, a released local RenderingDevice, no unsynced
submit state, no output texture keys, and `production_output_replaced=false`.
Markers:
`R7_COMPUTE_SELECTION_ABORT_OK` and the separate surface comparison
`R7_R6_SURFACE_PROPERTY_DIFF_OK`.

### `r7_compute_generated_output_replacement_staging_probe.gd` - R7 replacement validation helper (window required)

River-refactor R7. Retained as the shared helper base for
`r7_compute_production_replacement_validation_probe.gd`. Its standalone staging
run is historical and not a routine current gate. Keep this file until the
production validation probe no longer extends it.

### `r7_compute_production_replacement_validation_probe.gd` - R7 production replacement validation (window required)

River-refactor R7. Reuses the generated-output staging capture path, then
builds the report-only production replacement handoff map that RiverManager
would receive if canonical compute replacement were later promoted. The report
keeps actual RiverManager state and generated texture hashes unchanged, records
timing/responsiveness for the non-replacing pipeline, preserves the delayed
single-submit/wait/sync/readback path, proves `canonical_compute_replacing`
selects compute when all replacement gate evidence is supplied, and includes a
direct baker runtime smoke that reports only `flow_foam_noise` while leaving
RiverManager state and hashes unchanged. Marker:
`R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`.

### `r7_compute_non_neutral_flow_speed_probe.gd` - R7 final non-neutral compute flow-speed proof (window required)

River-refactor R7. Runs explicit `canonical_compute_replacing` low-cost bakes
with neutral and non-neutral `flow_speeds`, then verifies the non-neutral path
runs `flow speed scale map` once, stays on compute with no fallback, reports
`output_texture_keys=["flow_foam_noise"]`, and changes only `flow_foam_noise.rg`
while `flow_foam_noise.ba` plus the other generated textures remain unchanged.
Marker: `R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK`.

### `r7_compute_saved_resource_load_smoke_probe.gd` - R7 promoted saved-resource load smoke (window required)

River-refactor R7. Loads `res://Demo_obstacle_flow_test.tscn` and
`res://Demo.tscn` with the promoted saved `.river_bake.res` files without
rebaking or saving. It verifies valid flowmaps, source-signature match,
metadata backend state, material/debug bindings, debug-view availability,
texture readability, empty runtime concerns, and unchanged river/WaterSystem
resource file hashes. Marker: `R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK`.

### `r7_compute_backend_performance_compare_probe.gd` - R7 backend performance comparison (window required)

River-refactor R7. Runs explicit `legacy_canvas_item` and
`canonical_compute_replacing` bakes through the same timing harness on the
low-cost fixture plus `res://Demo_obstacle_flow_test.tscn` and `res://Demo.tscn`.
The probe records requested/selected backend mode, fallback status, elapsed bake
time, frame count, max and p95 frame gaps, output texture keys, compute
readback/dispatch details, texture hashes, report warnings/errors, and runtime
concerns. It does not save generated resources. Marker:
`R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK`.

### `distmap_neutral_binding_probe.gd` — null-distmap neutral binding (headless OK)

River-refactor R0.7. A fresh RiverManager binds the neutral `dist_pressure`
texel ≈ (0.75, 0.25, 0.0, 0.5) to `i_distmap` on both materials when
`dist_pressure` is null. Marker: `DISTMAP_NEUTRAL_BINDING_OK`.

### `flow_solve_seed_assert_probe.gd` — cross-language seed invariant (headless OK)

River-refactor RT.4. Asserts the neutral pressure seed `RIVER_FLOW_PRESSURE_SEED_COLOR`
(`river_manager.gd`) equals enc(0) in all three `flow_solve_common.gdshaderinc`
encodings. Marker: `FLOW_SOLVE_SEED_ASSERT_OK`.

### `system_flow_compare_probe.gd` — system-vs-river flow gate (headless OK)

River-refactor RT.3. Decodes the river's baked flow per texel, transforms to
world XZ via the same per-triangle UV1 basis `system_flow.gdshader` builds, and
compares against the duck-read system-map sample across control/influence/boundary
zones. Default = report mode (control gate); `enforce=all` is R2's gross-divergence
guard (35°). Detects stale system maps. Key args: `scene= stride= min_flow=
max_control_deg=15 max_influence_deg=35 sharp_deg=20 allow_stale=1`.
Markers: `SYSTEM_FLOW_COMPARE_OK` / `SYSTEM_FLOW_COMPARE_EXCEEDED` / `SYSTEM_FLOW_COMPARE_STALE`.

### `system_flow_projected_gate_probe.gd` — slide-gate mechanism gate (window required)

River-refactor R2. A/B system-flow renders (slide gated vs forced) prove the
`i_flow_projected` slide gate is active: gated and forced renders differ where
content exercises the slide, and repeat renders are identical. The mechanism
gate for the Defect-1 fix (the angular RT.3 threshold cannot see a correct
low-magnitude fix on saved maps). Marker: `SYSTEM_FLOW_PROJECTED_GATE_OK`.

### `r4_runtime_robustness_probe.gd` â€” R4 runtime guard probe (headless OK)

River-refactor R4. Exercises the non-visual runtime fixes: ripple stepping is
clamped to one simulation step per `_process`, high-frequency impulses do not
starve propagation, late group-routed targets refresh, `cleanup_runtime()`
preserves API-registered targets, off-tree field group changes remove stale
membership, one-shot emitters stop after the route retry cap, width generation
stays within the legacy 1/100-segment tolerance, buoyancy binds by WaterSystem
coverage, and settled bodies are not forcibly woken. Marker:
`R4_RUNTIME_ROBUSTNESS_PROBE_OK`.

### `r4_ripple_visible_auto_review.gd` - R4 ripple visible review (window required)

River-refactor R4. Opens the ripple field/emitter review scene and cycles the
normal view plus the raw-height, impulse/contact, and visible-influence debug
views without requiring keyboard input in a captured mouse window. Use this for
the human-visible ripple part of the R4 gate. Expected result: localized impulse
marks and influence rings appear around the emitter markers, the field disable
step returns the river to baseline, and the re-enable step restores the effect.
Marker: `R4_VISIBLE_AUTO_REVIEW_DONE`.

### `r4_buoyancy_visible_review.tscn` - R4 buoyancy visible review (window required)

River-refactor R4. Self-contained human-visible scene for the two-WaterSystem
coverage and settled-body sleep checks. It builds one nearby red WaterSystem
whose coverage does not contain the bodies and one farther green WaterSystem
whose coverage does contain them. The overlay reports that the buoyant body binds
to the green coverage system even though the red origin is closer, then watches a
settled sleeping body for wake/twitch regressions. Press `R` to restart the sleep
watch.

### `r5_behavior_preservation_probe.gd` - R5 structural-dedup guard (headless OK)

River-refactor R5. Checks that the filter pass descriptor table covers all 19
pass shaders and default/HDR policies, that Baking inspector rows still appear
in descriptor order, that `widths` and `flow_speeds` round-trip through curve
state restore and pad short arrays, and that `RiverBakeData.finalize()` deep
copies metadata/settings/signatures while restoring default channel/import
metadata. Marker: `R5_BEHAVIOR_PRESERVATION_PROBE_OK`. Expected warning: the
width-padding assertion intentionally triggers the existing "too few entries"
sanitizer warning.
