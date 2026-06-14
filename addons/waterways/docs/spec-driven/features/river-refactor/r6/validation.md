# Validation: River Refactor R6 - river_manager.gd Decomposition

## What Must Be Proven

- R6 changes no generated bake texture content.
- `source_signature` and `bake_settings` dumps are exact matches with no ignored keys.
- `source_metadata` dumps match exactly except the explicit dynamic allow-list.
- Full RiverManager public method/signal surface and inspector property list remain unchanged.
- Runtime ripple material ownership semantics remain unchanged.
- Editor validation wrappers and menu markers remain unchanged.
- Every old bake abort/early-return path becomes a controlled exit with cleanup and no partial overwrite.
- The baker has no broad RiverManager reach-back.

## Current Validation Snapshot

- Overall status: Partial. R6 documentation is tracked/clean, pre-move bake/source evidence exists, and the R6.3, R6.4, R6.1B, R6.1C, R6.1D, R6.1E, R6.1F, R6.1G, and R6.1H implementation slices have focused validation. The post-R6.1H R6.1A-G rerun passed the old lifecycle, run-pass, source-image, generated-texture, warning/postprocess, result-application, surface/property, and R5 preservation gates; constants-table extraction and final before/after gates remain open.
- Last automated pass: 2026-06-14 R6.1A-G validation rerun after R6.1H. Passed `R6_BAKER_LIFECYCLE_OK`, `R6_BAKER_RUN_PASS_OK`, `R6_R61F_WARNING_POSTPROCESS_OK`, `R6_R61G_RESULT_APPLICATION_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-generated files=2`, `R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61g-generated current=post-r6-r61ag-rerun-generated`, `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61ag-rerun-generated`, `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun files=10`, `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61g current=post-r6-r61ag-rerun`, and `git diff --check`. The R6.1D source-image rerun hit only the known four obstacle collision-derived rows and matched the old-code fresh replay exactly: `R6_R61D_COLLISION_VARIANT_RECONCILED_OK ignored_collision_probe_variants=4 baseline=pre-r6-r61d-fresh-rerun current=post-r6-r61ag-rerun-source`.
- Last human-assisted pass: none for R6.
- Highest-risk unproven behavior: constants-table signature coverage and final full-R6 before/after parity. Source timing remains a watch item, but the R6.1H helper-internal await abort coverage is now closed.
- Known unreliable local check or environment caveat: headless checks do not prove visible editor, shader, viewport, or menu behavior. Windowed/human-assisted validation is required for those.

## Canonical Dictionary Dump Format

This format must be implemented before any pre-R6 baseline capture.

- Dump files are UTF-8 text with LF line endings.
- Each dump starts with:
  - `R6_CANONICAL_DUMP v1`
  - `section=<source_metadata|source_signature|bake_settings>`
  - `target=<scene or bake resource identifier>`
  - `key_count=<count after allow-list filtering>`
- Keys are sorted lexicographically by their string form.
- Each entry is one line: `<key> = <canonical_value>`.
- Values are serialized with Godot's stable `var_to_str()`-style representation after recursively sorting nested dictionaries. Arrays keep their stored order.
- No ignored keys are allowed for `source_signature`.
- No ignored keys are allowed for `bake_settings`.
- `source_metadata` may ignore only keys explicitly listed in the dynamic allow-list below.
- Any additional ignored key is a review finding and must be recorded in `review.md` before implementation proceeds.

Dynamic metadata allow-list:

| Key | Reason | Status |
| --- | --- | --- |
| `bake_revision` | `_make_bake_revision()` is time-derived and changes on fresh rebakes. | Allowed |

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| R6 documentation gate exists before implementation | `spec.md`, `validation.md`, `tasks.md`, `research.md`, `review.md`, `session-handoff.md` in the R6 folder | Docs review | All required phase docs exist and point to `plan.md` | Pass - R6 docs were tracked and clean on branch `r6` before validation-tool edits | 2026-06-13 | Agent |
| Canonical dictionary dumps are stable | `r6_baseline_dump_probe.gd` | Console/headless | Sorted dumps generated for both demo river bakes | Pass - `R6_BASELINE_DUMP_OK`; six canonical dictionary dumps written under `.codex-research/r6-baselines/pre-r6/`, filtering only `source_metadata.bake_revision` | 2026-06-13 | Agent |
| Source signature unchanged | Canonical dump diff before/after R6 | Console/headless | Empty diff, no ignored keys | Pass for R6.3 slice - pre-R6 and post-R6.3 dumps matched exactly; final R6 diff still required after bake moves | 2026-06-13 | Agent |
| Bake settings unchanged | Canonical dump diff before/after R6 | Console/headless | Empty diff, no ignored keys | Pass for R6.3 slice - pre-R6 and post-R6.3 dumps matched exactly; final R6 diff still required after bake moves | 2026-06-13 | Agent |
| Source metadata unchanged except dynamic allow-list | Canonical dump diff before/after R6 | Console/headless | Empty diff after ignoring only `bake_revision` | Pass for R6.3 slice - pre-R6 and post-R6.3 dumps matched exactly after the existing allow-list; final R6 diff still required after bake moves | 2026-06-13 | Agent |
| Generated texture output unchanged | RT.1 scratch rebake hash compare for Demo and obstacle demo river bakes | Console/windowed as needed | All generated texture hashes identical | Pass for R6.1A-G rerun after R6.1H - `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-generated files=2`; `R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61g-generated current=post-r6-r61ag-rerun-generated`; `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61ag-rerun-generated` | 2026-06-14 | Agent |
| Intermediate source images unchanged | `r6_source_image_hash_probe.gd` for the full raw-plus-margin list | Console/headless or windowed as needed | All intermediate hashes identical before/after source-helper moves | Pass for R6.1A-G rerun after R6.1H with the existing obstacle caveat - Demo matched the post-R6.1D final source-image dump exactly; obstacle differed only in the four previously documented collision-derived rows and matched the old-code fresh replay exactly: `R6_R61D_COLLISION_VARIANT_RECONCILED_OK ignored_collision_probe_variants=4 baseline=pre-r6-r61d-fresh-rerun current=post-r6-r61ag-rerun-source` | 2026-06-14 | Agent |
| Public RiverManager API and signals unchanged | `r6_baseline_dump_probe.gd` public method/signal surface dump and diff; `r6_mid_bake_timing_probe.gd` progress capture | Console/headless plus windowed console for progress | Empty diff; `river_changed` and `progress_notified` still present; progress order remains documented | Pass for R6.1A-G rerun after R6.1H - `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61g current=post-r6-r61ag-rerun`; generated-texture logs still preserve Jacobi labels `Projecting flow 0/40 (stride 32)` through `35/40` | 2026-06-14 | Agent |
| Full inspector property list unchanged | `r6_baseline_dump_probe.gd` serialized property-list dump and diff | Console/windowed as needed | Empty diff | Pass for R6.1A-G rerun after R6.1H - exact property-list and canonical dictionary match against the post-R6.1G baseline; public method/signal line numbers were normalized as surface-only location drift | 2026-06-14 | Agent |
| Source timing contract preserved or deliberately validated | `r6_mid_bake_timing_probe.gd` flow-speed trap plus future before/after checks | Console/windowed/human | Reports targeted stage and old/new value use, with `flow_speeds` minimum trap case | Baseline captured - `R6_MID_BAKE_TIMING_OK`; mutation at first `Projecting flow` progress left all trap textures identical to same-run neutral control while final metadata/signature re-read mutated `flow_speeds` | 2026-06-13 | Agent |
| Baker has no broad RiverManager reach-back | Static review plus implementation checklist | Code review | Only `BakeConfig`, local state, and named callbacks/dependencies are used | Pass for R6.1A-G rerun after R6.1H - `R6_R61G_RESULT_APPLICATION_OK` still covers the boundary and synchronous RiverManager apply order; baker still does not save resources, call `_apply_bake_data()`, bind materials, or mutate `valid_flowmap` | 2026-06-14 | Agent |
| Bake abort cleanup is complete | `r6_abort_matrix_probe.gd` plus named human-assisted cases | Console/headless plus named editor/human | No stuck flag, leaked renderer, orphan viewport, stale progress source, or partial overwrite | Pass for R6.1H - `R6_R61H_ABORT_MATRIX_OK` covers pre-renderer abort before renderer setup, scene close before renderer setup, terrain-contact helper node-free, renderer-live/Jacobi-labelled cancellation, forced invalid filter output, filter-renderer setup failure, duplicate RiverManager and baker requests, repeated `abort()`, success cleanup, post-renderer/image-postprocess synchronous strategy, and synchronous RiverManager result-application strategy. Editor undo-delete is named human-assisted; forced collision-helper null injection is named until a narrow injection seam exists. | 2026-06-14 | Agent |
| Existing R5 behavior remains green | `r5_behavior_preservation_probe.gd` | Console/headless | `R5_BEHAVIOR_PRESERVATION_PROBE_OK` | Pass for R6.1A-G rerun after R6.1H - expected width-padding warnings emitted | 2026-06-14 | Agent |
| Existing runtime robustness remains green | `r4_runtime_robustness_probe.gd` | Console/headless | `R4_RUNTIME_ROBUSTNESS_PROBE_OK` | Pass for R6.4 slice - stable marker reported | 2026-06-14 | Agent |
| Filter renderer load remains green | `filter_renderer_load_check.gd` or equivalent | Console/headless | `FILTER_RENDERER_LOAD_OK shader_paths=19` | Pass for R6.4 slice - scratch `.codex-research/filter_renderer_load_check.gd` reported `shader_paths=19` | 2026-06-14 | Agent |
| System-flow mechanism remains green | `system_flow_projected_gate_probe.gd` | Windowed console | `SYSTEM_FLOW_PROJECTED_GATE_OK` | Unrun for R6 | - | - |
| Runtime ripple material ownership unchanged | Existing ripple probes plus owner-conflict/tree-exit probe | Console/windowed as needed | Owner A/B conflict, clear, tree-exit, debug toggle behavior preserved | Pass for R6.3 - `ripple_material_ownership_probe.gd` was hardened for debug-material ownership and reported `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`; `ripple_debug_parity_probe.gd` was updated to follow the new owner script and shared shader include, then reported `RIPPLE_DEBUG_PARITY_PROBE_OK`; `ripple_field_emitter_probe.gd` reported `RIPPLE_FIELD_EMITTER_PROBE_OK` | 2026-06-13 | Agent |
| Editor validation wrappers unchanged | Menu-wrapper marker check and direct RiverManager wrapper calls | Windowed/human-assisted as needed | Same `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` markers | Pass for R6.4 slice - `r6_editor_validation_probe.gd` reported menu signal marker `R6_EDITOR_VALIDATION_MENU_SIGNALS_OK`, direct wrapper output with unchanged `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` prefixes, and `R6_EDITOR_VALIDATION_PROBE_OK` | 2026-06-14 | Agent |
| Parent docs reflect R6 result only after validation | Parent `validation.md`, `tasks.md`, `roadmap.md`, handoff docs | Docs review | R6 row added only after validation runs | Unrun | - | - |

## R6.4 Editor Validation Caller and Dependency Audit

Caller audit before extraction:

- Plugin/menu path: `addons/waterways/gui/river_menu.gd` emits `validate_data_textures` and `validate_filter_renderer` from the River menu items; `addons/waterways/plugin.gd` connects those signals in `_show_river_control_panel()` and disconnects them in `_hide_river_control_panel()`.
- Plugin wrapper calls: `_on_validate_river_data_textures_pressed()` calls `_edited_node.validate_data_textures()` when the edited node is a `RiverManager`; `_on_validate_filter_renderer_pressed()` calls `_edited_node.validate_filter_renderer()` on the same condition.
- Probe/script callers in active source: no active probe directly invokes either wrapper before R6.4; `addons/waterways/probes/r6_baseline_dump_probe.gd` asserts both wrappers remain in the public RiverManager method surface.
- Marker consumers: `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` are produced by the public wrappers and are consumed by the R6 validation/human-assisted workflow. Repository search found no active parser script that scrapes those marker strings before R6.4.
- Separate filter coverage: `.codex-research/filter_renderer_load_check.gd` prints `FILTER_RENDERER_LOAD_OK shader_paths=19` and remains the all-19-pass load coverage. It is separate from the public River menu smoke marker and must not be folded into `FILTER_RENDERER_TEST`.

Live dependency inventory before extraction:

- `validate_data_textures()` reads `flow_foam_noise`, `dist_pressure`, `obstacle_features`, `terrain_contact_features`, and `bank_response_features`; for each texture it reads image data, resource paths, and import sidecar text when a project path is used.
- `validate_data_textures()` reads `bake_data.source_kind`, texture fields matching the validation label, `bake_data.resource_path`, `bake_data.content_rect`, `bake_data.uv2_sides`, `_uv2_sides`, and `_calculate_step_count()` for generated/resource-owned source notes and UV2 atlas flow statistics. It calls `WaterHelperMethods` statistics/formatting helpers and does not mutate RiverManager state.
- `validate_filter_renderer()` reads `_filter_renderer`, requires the RiverManager node to be inside the scene tree, instantiates the current `filter_renderer.tscn`, adds it as a child of the RiverManager, awaits one process frame, then awaits the same menu smoke subset: combine, dotproduct, flow pressure, foam, blur, vertical blur, normal, normal-to-flow, dilate, and dilate default-fill reset.
- `validate_filter_renderer()` reads the temporary renderer's `filter_mat.color_texture` after the default-fill dilate pass and cleans the temporary renderer through the same `_cleanup_bake_renderer()` path used by bake renderer cleanup. It emits the existing `FILTER_RENDERER_TEST` marker text and does not expand public menu coverage to all 19 shader paths.
- R6.4 extraction context: the helper receives generated textures, `bake_data`, `_uv2_sides`, calculated step count, `_filter_renderer`, a renderer parent node, and the existing cleanup callback. Runtime paths do not depend on editor-only singleton state.

## Source-Image Hash Gate

The source-image hash probe must cover both raw and margin-padded images where padding exists:

- collision source and collision-with-margins
- downstream baseline source and downstream baseline-with-margins
- blank support/features raw and margin-padded variants
- terrain contact source, smoothed terrain contact source, and terrain contact-with-margins
- solid occupancy source and solid occupancy-with-margins
- grade energy, bend bias, and flow speed raw and margin-padded variants
- tiled flow offset noise

This full raw-plus-margin list is the gate. Do not substitute the shorter summary list from older validation rows.

Recorded pre-move source-image baseline:

- `r6_source_image_hash_probe.gd` ran headless with repo-local `APPDATA`/`LOCALAPPDATA` under `.codex-research/godot-user-r6`.
- Output files:
  - `.codex-research/r6-baselines/pre-r6/demo__source_image_hashes.txt`
  - `.codex-research/r6-baselines/pre-r6/demo_obstacle_flow_test__source_image_hashes.txt`
- Each file contains one context row plus 24 source rows. The flow-speed raw and margin-padded images are hashed even though the current demo `flow_speeds` are neutral and `flow_speed_scale_would_run=false`.
- Stable marker: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6 files=2`.
- Non-fatal caveat: `Demo.tscn` still reports the known invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.

Recorded R6.1D post-move source-image validation:

- `r6_source_image_hash_probe.gd` now exercises the baker-owned source-image helpers directly.
- Output files:
  - `.codex-research/r6-baselines/post-r6-r61d/demo__source_image_hashes.txt`
  - `.codex-research/r6-baselines/post-r6-r61d/demo_obstacle_flow_test__source_image_hashes.txt`
  - `.codex-research/r6-baselines/post-r6-r61d-rerun/demo__source_image_hashes.txt`
  - `.codex-research/r6-baselines/post-r6-r61d-rerun/demo_obstacle_flow_test__source_image_hashes.txt`
- Stable markers:
  - `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d files=2`
  - `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d-rerun files=2`
  - `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d-final files=2`
  - `R6_R61D_SOURCE_IMAGE_DIFF_OK demo`
  - `R6_R61D_SOURCE_IMAGE_RERUN_DIFF_OK demo`
  - `R6_R61D_SOURCE_IMAGE_RERUN_DIFF_OK demo_obstacle_flow_test`
  - `R6_R61D_MOVED_SOURCE_HELPERS_DIFF_OK files=2 ignored_collision_derived_rows=4`
- Reconciliation markers:
  - `R6_R61D_COLLISION_BASELINE_RECONCILED ignored_collision_probe_variants=4`
  - `R6_R61D_FULL_SOURCE_IMAGE_DIFF_OK files=2 baseline=pre-r6 current=post-r6-r61d-final`
- Interpretation: all moved source-helper rows match before/after for both scenes. The earlier obstacle mismatch was not an R6.1D source-helper regression: a scratch `origin/r6` replay with old RiverManager helpers reproduced the alternate hash set in the same four untouched collision-derived rows (`collision_source`, `collision_with_margins`, `solid_occupancy_source`, `solid_occupancy_with_margins`), while the final current R6.1D run exactly matched the original pre-R6 full raw-plus-margin source-image dump for both scenes. Treat those four rows as collision-probe freshness/variant evidence for this reconciliation only; future pass-sequencing work still needs RT.1 and source/output gates.
- Non-fatal caveat: `Demo.tscn` still reports the known invalid UID warning for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.

## Mid-Bake Timing and Progress Evidence

Recorded pre-move timing/progress baseline:

- `r6_mid_bake_timing_probe.gd` ran in a rendered console window because filter-renderer readback is unavailable under the headless/dummy renderer.
- Output file: `.codex-research/r6-baselines/pre-r6/demo_flow_speeds_projecting_flow_trap__mid_bake_timing.txt`.
- Trap case: the probe starts the Demo river with all `flow_speeds = 1.0`, waits for the first `Projecting flow 0/40 (stride 32)` progress label, then changes point 0 to `1.5` and the last point to `0.75`.
- Interpretation: by the first `Projecting flow` label, the old path has already made the source-generation decision at `_any_flow_speed_non_neutral()` / `_create_curve_flow_speed_source_image()`. Final dictionary assembly has not happened yet.
- Evidence captured:
  - `initial_point0_flow_speed=1.0`
  - `final_point0_flow_speed=1.5`
  - `final_last_point_flow_speed=0.75`
  - `metadata_flow_speed_scaled=true`
  - same-run neutral control has `control_point0_flow_speed=1.0` and `control_metadata_flow_speed_scaled=false`
  - all six trap texture hashes match the same-run neutral control
- Progress order captured for the Demo path:
  - collision setup and loop progress: `Calculating Collisions`
  - source/filter handoff: `Applying filters`
  - terrain-contact loop progress: `Calculating Terrain Contact`
  - pressure projection stride labels: `Projecting flow 0/40` through `Projecting flow 35/40`
  - completion: `finished`
- Saved-resource baseline hash comparison in this probe is informational only: several fresh rendered-control hashes differ from the saved-resource RT.1 baseline, while the trap-vs-control comparison is the timing proof.
- Stable marker: `R6_MID_BAKE_TIMING_OK out=res://.codex-research/r6-baselines/pre-r6 files=1`.

## Awaited Operation Inventory

Current `_generate_flowmap()` and awaited helper waits before any R6 movement:

- Pre-renderer source-generation waits:
  - curve-only skip path emits `Preparing curve flow` and awaits one `process_frame`
  - collision path calls `WaterHelperMethods.reset_all_colliders(get_tree().root)`, emits `Calculating Collisions`, awaits one `process_frame`, then awaits `WaterHelperMethods.generate_collisionmap(...)`
  - `generate_collisionmap()` emits collision progress through the RiverManager signal and awaits `river.get_tree().process_frame` before the loop and at each 0.1 progress increment
  - `_generate_flowmap()` emits `Applying filters` and awaits one `process_frame`
  - terrain-contact source generation awaits `WaterHelperMethods.generate_terrain_contact_feature_map(...)`
  - `generate_terrain_contact_feature_map()` emits terrain-contact progress and awaits `_await_bake_frame(mesh_instance, river)` before the loop and at each 0.1 progress increment
  - `_await_bake_frame()` awaits `river.get_tree().process_frame` when the river is live in the tree, otherwise awaits `mesh_instance.get_tree().process_frame` when the mesh is live
- Renderer-live filter waits:
  - `_render_bank_response_feature_mask()` awaits `renderer_instance.apply_bank_response_feature_mask(...)`
  - `apply_flow_pressure`, `apply_vertical_blur`, `apply_normal`, `apply_occupancy_pack`, `apply_obstacle_feature_mask`, `apply_flow_divergence`, `apply_flow_gradient_subtract`, `apply_flow_boundary_tangency`, `apply_normal_to_flow`, `apply_foam`, `apply_flow_speed_scale`, and `apply_combine` each await renderer work
  - multi-pass renderer wrappers contain helper-internal waits: `apply_dilate()` awaits three `_run_pass()` calls, `apply_proximity()` awaits two, and `apply_blur()` awaits two
  - pressure projection currently awaits 40 Jacobi passes (`8` stride entries times `5` iterations each) and emits `Projecting flow %d/%d (stride %d)` before each stride group
  - boundary tangency currently awaits two passes
  - every `filter_renderer.gd` `_run_pass()` awaits two `process_frame` ticks before reading back viewport output
- Post-renderer/final-application waits:
  - there are no explicit awaits after `_cleanup_bake_renderer(renderer_instance)` in the success path
  - final texture `get_image()` readback, CPU postprocess, diagnostics, `ImageTexture.create_from_image()`, `_write_bake_data()`, `WaterHelperMethods.save_river_bake_data()`, `_apply_bake_data()`, shader parameter refresh, bake-flag clear, completion progress, and save/editor-memory notice are synchronous in the old path

## Bake Success-Order Inventory

Before adding the baker shell, confirm the current success order and keep R6 result application equivalent:

- final combine outputs are validated
- renderer is cleaned up
- final textures are read back to `Image`
- CPU postprocess and diagnostics run
- generated `ImageTexture`s are created and assigned
- `RiverBakeData` fields are assigned and finalized
- external bake resource save is attempted
- `_apply_bake_data()` and shader parameters are refreshed
- `valid_flowmap` is set true
- `_flowmap_bake_in_progress` is cleared
- completion progress is emitted
- save/editor-memory notice is printed

Current confirmation: the old success path performs that order with no awaited gap after renderer cleanup. If R6 introduces any await after result application starts, it needs explicit staging/rollback validation.

## Known Abort Point Inventory

Count and name each old abort point before moving the pipeline. The known current list is:

- collision map failure
- terrain contact source generation failure
- filter renderer instantiate failure
- early bank-response feature mask invalid
- flow pressure invalid
- vertical blur invalid
- dilate invalid
- normal map invalid
- occupancy proximity invalid
- occupancy pack invalid
- obstacle feature mask invalid
- flow divergence invalid
- each Jacobi pass invalid
- gradient subtract invalid
- each boundary tangency pass invalid
- normal-to-flow invalid
- flow blur invalid
- foam invalid
- foam blur invalid
- primary flow fallback missing
- flow speed scale invalid
- late bank-response feature mask invalid
- combined flow/foam/noise invalid
- combined distance/pressure invalid

Awaited non-filter failures, especially collision map generation and terrain contact source generation, must be counted separately from `_filter_output_is_valid()`-style filter failures.

Current abort count interpretation:

- User-facing abort labels currently visible in `_generate_flowmap()` / `_filter_output_is_valid()`: 24 named labels when looped passes are counted by label.
- Concrete renderer failure opportunities are higher because Jacobi has 40 awaited passes, boundary tangency has two awaited passes, and multi-pass wrappers (`apply_dilate`, `apply_proximity`, `apply_blur`) can fail inside helper-internal `_run_pass()` calls while surfacing through one outer label.
- `collision map failure`, `terrain contact source generation failure`, and filter-renderer instantiation are non-filter abort records and must not be hidden behind `_filter_output_is_valid()`.
- Terrain-contact source generation currently has no clean explicit null/empty guard immediately before smoothing/margin creation; R6 should turn this into a controlled abort record before moving the helper.

## Abort Matrix Requirements

Every abort case must prove:

- `_flowmap_bake_in_progress == false`
- no live filter renderer child remains
- no orphan SubViewport remains
- a later bake request can run
- no stale progress source remains
- existing valid bake data is not partially overwritten unless finalization succeeded
- an abort before RiverManager begins result application does not change generated textures, material bindings, `valid_flowmap`, or `RiverBakeData`

Stage buckets to cover:

- pre-renderer awaited waits/source generation, including helper-internal loop awaits
- renderer-live filter pass and Jacobi awaits
- post-renderer cleanup and CPU image postprocess
- RiverManager result application, save attempt, shader refresh, final progress/notice

Scenarios to cover or explicitly name as human-assisted:

- scene close while a bake is running
- River node freed while a bake is running, including terrain-contact helper loop waits
- undo-delete during an awaited pass
- forced invalid filter output
- forced collision generation failure or no-collision fallback path
- forced terrain-contact source generation failure or liveness interruption
- duplicate bake request while one is running
- baker `abort()` called more than once
- baker cleanup after successful bake
- result-application interruption strategy

If result application remains synchronous and non-awaited, record that as the strategy. If any await is added, prove rollback/staging prevents partial generated textures, partial `RiverBakeData`, or a stuck bake flag.

Current result-application strategy: keep result application synchronous and non-awaited. RiverManager should receive either no result on abort or a complete `BakeResult` and then apply it in the old order without cancellation points.

## R6.1H Abort Matrix Coverage

Automated coverage now lives in `addons/waterways/probes/r6_abort_matrix_probe.gd`.

Covered automatically by `R6_R61H_ABORT_MATRIX_OK`:

- RiverManager duplicate bake request guard rejects a second request while preserving the original in-progress flag, and accepts a later request after cleanup.
- Baker setup cleanup, duplicate setup rejection, repeated `abort()`, and success cleanup leave no live probe renderer.
- Filter-renderer setup failure returns `renderer_scene_missing` and leaves the baker stopped.
- Forced invalid filter output returns a `filter_pass_failed` abort record with label, stage, readback detail, warning text, and renderer cleanup.
- Awaited renderer-pass cancellation uses the Jacobi label `flow pressure jacobi pass`, aborts after the awaited callable returns, clears running state, and frees the renderer.
- Pre-renderer abort before renderer setup clears `_flowmap_bake_in_progress`, leaves no filter renderer, and preserves generated textures, `valid_flowmap`, and `RiverBakeData`.
- Scene close before renderer setup frees the scene and leaves the baker stopped.
- River node free during the terrain-contact helper's internal frame waits leaves the baker stopped and no filter renderer.
- Post-renderer/image postprocess and RiverManager result application remain synchronous/non-awaited strategies; the probe statically checks no `await` was added and that renderer cleanup happens before the image-postprocess handoff.

Named non-automated or strategy cases:

- Editor undo-delete during an awaited bake is the human-assisted editor-stack version of the automated scene-close/node-free cases. The scripted probe covers the runtime lifecycle effect; the editor undo stack still needs visible/manual validation before final R6 closure.
- Forced collision-helper null injection is named rather than automated because the current `WaterHelperMethods.generate_collisionmap()` path has no narrow failure-injection seam. The no-collision-hit path is a fallback (`support_fallback_reason = "no_collision_hits"`), not an abort, and remains covered by generated-output gates.
- Forced terrain-contact natural null is also not expected from ordinary preconditions; R6.1H covers the required terrain-contact failure bucket through liveness interruption during the helper loop plus a controlled null/empty guard after helper return.

Implementation notes:

- `river_flowmap_baker.gd` stores a cancellation callback during `bake()` and checks it immediately before and after awaited renderer pass callables.
- `river_manager.gd` checks `_is_flowmap_bake_cancelled()` after the existing pre-renderer source-generation awaits and passes the same cancellation callable into `run_filter_pass_sequence()`.
- `water_helper_methods.gd` checks helper context liveness around collision and terrain-contact helper-internal awaits, using untyped helper parameters where freed Object references must be inspected safely with `is_instance_valid()`.

## Live Dependency Inventory

Live bake-pipeline dependencies currently read before or during `_generate_flowmap()`:

- bake-start snapshot: sanitized `bake_generation_behavior` is captured into local `generation_behavior`
- live source-generation reads: `mesh_instance`, `baking_raycast_distance`, `baking_raycast_layers`, `_steps`, `shape_step_length_divs`, `shape_step_width_divs`, helper-owned collision/terrain scene state, `curve`, `widths`, `flow_speeds`, `FLOW_OFFSET_NOISE_TEXTURE_PATH`, and `get_tree().root`
- live renderer/pass dependencies: `_filter_renderer`, `_flowmap_bake_renderer`, `get_tree().process_frame`, renderer scene tree parentage, filter shader resources, `RenderingServer`/viewport readback state, `_uv2_sides`, generated source textures/images, and branch booleans derived from `generation_behavior` and support fallback state
- side-effect dependencies: `emit_signal("progress_notified", ...)`, `push_warning`, diagnostic `print`, `WaterHelperMethods.reset_all_colliders()`, `_cleanup_bake_renderer()`, `_finish_flowmap_bake_after_failure()`, `_print_curve_support_fallback_notice()`, `_print_river_flow_vector_diagnostics()`, and warning helpers

Final-write dependencies that must be treated separately from bake-pipeline dependencies:

- `_write_bake_data()` reads generated texture fields after `ImageTexture.create_from_image()` assigns them to RiverManager
- `source_metadata.generation_behavior`, generation mode, source kind, and support/diagnostic stats use the bake-start `generation_behavior` and bake-produced diagnostics
- `source_metadata.flow_speed_scaled` re-reads live `flow_speeds` through `_any_flow_speed_non_neutral()`
- `get_bake_source_signature()` re-reads live `curve.bake_interval`, curve point positions/handles, widths, flow speeds, shape settings, bake settings, live `bake_generation_behavior`, and calculated step count
- `_get_bake_settings()` re-reads shape settings, bake settings, live `bake_generation_behavior`, `_uv2_sides`, source/texture sizes, content rect, and texture layout
- `_get_mesh_global_aabb(mesh_instance)` reads final live mesh/global transform state
- `WaterHelperMethods.save_river_bake_data(self, bake_data)` uses RiverManager and scene ownership only after `RiverBakeData.finalize()`
- `_apply_bake_data()`, `set_materials(...)`, `valid_flowmap`, `_clear_flowmap_bake_request()`, `emit_signal("progress_notified", 100.0, "finished")`, `_print_bake_save_notice(...)`, and `update_configuration_warnings()` remain RiverManager-owned result application

Move/stay candidates before adding the baker shell:

- Move candidates after the source-image hash gate: margin image/texture creation, blank support/feature image creation, terrain-contact and bank-response settings dictionaries as explicit config, downstream baseline/solid occupancy/grade-energy/bend-bias/flow-speed source synthesis, tiled flow-offset noise creation, renderer pass sequencing, filter-output abort record creation, CPU postprocess, channel stats, flat-support reductions, flow diagnostics formatting inputs, and renderer cleanup ownership.
- Conditional move candidates: collision and terrain-contact generation can move only after broad `river` helper arguments are replaced with explicit progress, frame-await, liveness, collision-root, and mesh/context dependencies.
- Stay in RiverManager initially: public API and inspector properties, preflight and duplicate bake request guard, mesh generation/material binding, `_write_bake_data()` result application, `get_bake_source_signature()` and `_get_bake_settings()` until the R6.2 shadow table passes, external save attempt, final shader parameter refresh, progress signal ownership, editor property notification, runtime ripple wrappers, and editor validation wrappers.

## No RiverManager Reach-Back Checklist

Every baker helper must consume only:

- `BakeConfig`
- local baker state
- explicit frame-await callback
- explicit cancellation/liveness callback
- explicit collision reset/root dependency
- explicit terrain/collision generation context
- explicit warning, print, and progress callbacks

Forbidden:

- passing `self` from RiverManager into the baker
- a generic `owner_node`, `collision_owner`, or RiverManager-like wrapper that allows arbitrary method access
- using helper signatures that hide collision-root lookup, progress, frame await, or liveness behind a broad RiverManager argument

## Premise and Interpretation Checks

- Expected behavior that could look like a bug: fresh rebakes may produce dynamic `bake_revision` changes; whole-resource `.res` hashes may differ even when per-texture content is identical.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out: stale pre-R6 baselines, shared or overwritten bake resources, user editor saves that rewrite `.res` files, and `.codex-research` profile state.
- Research/source context to check: `addons/waterways/docs/research/river-research-citations.md`.
- Evidence that would mean the agent is misreading the situation: RT.1 mismatch without a fresh pre-R6 scratch baseline; metadata diff caused only by `bake_revision`.
- What the agent should say if that evidence appears: pause the R6 gate, identify which baseline is suspect, and run the smallest fresh baseline/diff needed before patching.
- Quick falsifying check before patching: capture pre-R6 dictionary/property/API/source-image/texture baselines before moving code.

## Automated Checks

- `git diff --check`
- Godot parser/check-only on changed scripts.
- `r5_behavior_preservation_probe.gd`
- `r4_runtime_robustness_probe.gd`
- `filter_renderer_load_check.gd` or equivalent with `shader_paths=19`
- `system_flow_projected_gate_probe.gd`
- New metadata/signature/settings canonical dump and diff probe
- Full public API/signal-surface diff
- Full inspector property-list diff
- RT.1 generated texture hash compare for both demo river bakes
- Intermediate source-image hash compare
- Abort matrix probe where feasible
- Runtime ripple owner probe
- Editor validation wrapper/marker probe

Agent limitation note:

- Local static, parser, and headless checks do not prove visible editor interaction, shader visuals, bake output appearance, or menu behavior.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so the user's normal Godot editor profile is not altered.

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

## Human-Assisted Validation

Use this by default for visible Godot editor checks, viewport interaction, scene running, menu actions, shader visuals, bake output, and runtime behavior.

Request to user when R6 reaches the relevant gate:

- Open the project in Godot 4.6.3.
- Start a river bake, close the scene mid-bake, reopen it, and confirm a fresh bake can run.
- Start a river bake, undo-delete or remove the river during an awaited phase if the probe cannot cover it, then confirm the editor remains usable and a fresh bake can run.
- Run the River menu validation actions and relay the Output panel lines containing `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST`.
- Compare normal/debug river views against the pre-R6 expectation and report any visible change.
- Relay Godot version, renderer, console/output errors, and visible result.

Expected result:

- No visible behavior change, no stuck bake flag, no leaked renderer, same validation markers, and successful fresh bake after abort.

## Recorded Results

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; Vulkan Forward+ for rendered generated-texture hash probes; headless for parser/check-only, source-image hash, baker lifecycle/run-pass, warning/postprocess, result-application boundary, R5 behavior preservation, baseline dump, and static diff checks.
- Command, scene, or workflow: Reran the old R6.1A-G validation/probe set after R6.1H and before R6.2. The rerun used repo-local `APPDATA`/`LOCALAPPDATA` under `.codex-research/godot-user-r61ag-rerun`, wrote logs under `.codex-research/r6-r61ag-rerun-logs/`, wrote current baseline dumps to `.codex-research/r6-baselines/post-r6-r61ag-rerun/`, wrote source-image hashes to `.codex-research/r6-baselines/post-r6-r61ag-rerun-source/`, and wrote generated-texture hashes to `.codex-research/r6-baselines/post-r6-r61ag-rerun-generated/`. Rerun order followed the recorded R6.1B-G sequence: parser/check-only where originally used, baker lifecycle, run-pass, R5 preservation, R6.1D source-image hash/diff, R6.1E-G generated-texture hashes/diffs, R6.1F warning/postprocess, R6.1G result-application, baseline dump/surface/property comparisons, and `git diff --check`.
- Output or parser errors: No parser or probe failures. The known `Demo.tscn` invalid UID warning repeated. The focused run-pass probe intentionally emitted the old null/readback warning text. R5 behavior preservation emitted expected width-padding warnings. The source-image diff initially stopped on the obstacle scene's four known collision-derived rows (`collision_source`, `collision_with_margins`, `solid_occupancy_source`, `solid_occupancy_with_margins`); diagnosis showed the current rerun matched the old-code fresh replay exactly, so this remained the documented collision-probe freshness variant rather than an implementation regression.
- Visible result, if applicable: Rendered console generated-texture validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_BAKER_LIFECYCLE_OK`; `R6_BAKER_RUN_PASS_OK`; `R6_R61D_PARSER_OK`; `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-source files=2`; `R6_R61D_COLLISION_VARIANT_RECONCILED_OK ignored_collision_probe_variants=4 baseline=pre-r6-r61d-fresh-rerun current=post-r6-r61ag-rerun-source`; `R6_R61E_PARSER_OK`; `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun-generated files=2`; `R6_R61AG_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61g-generated current=post-r6-r61ag-rerun-generated`; `R6_R61AG_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61ag-rerun-generated`; `R6_R61F_PARSER_OK`; `R6_R61F_WARNING_POSTPROCESS_OK`; `R6_R61G_RESULT_APPLICATION_OK`; `R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61g-generated current=post-r6-r61ag-rerun-generated`; `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61ag-rerun-generated`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61ag-rerun files=10`; `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61g current=post-r6-r61ag-rerun`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; `git diff --check`.
- Pass/partial/fail: Pass for the R6.1A-G validation rerun after R6.1H. This confirms the earlier bake-extraction coverage did not regress after the abort-matrix work. It is not a full R6 pass because constants-table extraction, final full-R6 before/after diffs, system-flow projected gate, and visible/manual editor checks remain open.
- Notes or follow-up: Do not redo the R6.1B-H implementation slices. Start R6.2 constants-table extraction in shadow mode next, preserving live metadata/signature/settings output until the shadow-builder probe passes.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; headless for R6.1H abort probe, baker lifecycle/run-pass checks, and result-application static check. A windowed console rerun of the abort probe also reported the same marker.
- Command, scene, or workflow: Added `addons/waterways/probes/r6_abort_matrix_probe.gd`, added awaited-pass cancellation checks in `river_flowmap_baker.gd`, added RiverManager liveness checks after existing pre-renderer awaits and before filter sequencing continues, added a controlled terrain-contact source null/empty failure guard, and hardened collision/terrain helper-internal await liveness checks in `water_helper_methods.gd`. The probe uses a fake renderer for lifecycle/abort semantics, loads Demo for pre-renderer/scene-close/terrain-node-free cases, and statically verifies synchronous post-renderer image postprocess and result application.
- Output or parser errors: No probe assertion failures or script errors after the freed-reference helper signature was corrected. Expected warnings were emitted for duplicate bake request, missing filter renderer scene, and forced invalid filter output. The known `Demo.tscn` invalid UID warning repeated. Godot script exit reported non-fatal engine cleanup noise after Demo-scene lifecycle tests (`RID`/ObjectDB/resource leak messages) while the process returned success after `R6_R61H_ABORT_MATRIX_OK`.
- Visible result, if applicable: Scripted lifecycle validation only; no manual editor undo/delete or visible scene-close UI review.
- Stable result marker: `R6_R61H_ABORT_MATRIX_OK`; follow-up guards `R6_BAKER_LIFECYCLE_OK`, `R6_BAKER_RUN_PASS_OK`, `R6_R61G_RESULT_APPLICATION_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, and final `git diff --check`.
- Pass/partial/fail: Pass for R6.1H abort-matrix coverage. This is not a full R6 pass because constants-table extraction, final full-R6 before/after diffs, system-flow projected gate, and visible/manual editor checks remain open.
- Notes or follow-up: Editor undo-delete remains a named human-assisted case. Forced collision-helper null injection remains named until a narrow source-helper injection seam exists; the no-collision-hit path is a support fallback, not an abort. Start R6.2 constants-table work next.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; Vulkan Forward+, AMD Radeon RX 6800 XT for rendered generated-texture hash probes; headless for result-application boundary check, warning/postprocess probe, baker lifecycle/run-pass, R5 behavior preservation, baseline dump, and static diff checks.
- Command, scene, or workflow: Completed R6.1G by making the bake-result handoff explicit. `river_flowmap_baker.gd` now carries the bake-start `generation_behavior` in the returned result dictionary, and `river_manager.gd` applies that result through `_apply_flowmap_bake_result()` without adding awaits. `_write_bake_data()` now consumes the result dictionary directly while keeping mesh bounds, source metadata, source signature, and bake settings at RiverManager's old final-read point. RiverManager still owns final texture fields, `RiverBakeData` finalization, `WaterHelperMethods.save_river_bake_data(self, bake_data)`, `_apply_bake_data()`, material binding, `valid_flowmap`, bake flag clearing, final progress, save/editor-memory notice, and configuration warnings. Added scratch-only `.codex-research/r6_r61g_result_application_check.gd`.
- Output or parser errors: No parser errors in active scripts. The R6.1G boundary check asserted that the baker does not save resources, call `_apply_bake_data()`, bind materials, or mutate `valid_flowmap`, and that RiverManager result application remains synchronous and ordered. Generated-texture and baseline probes repeated the known non-fatal `Demo.tscn` invalid UID warning. The focused run-pass probe intentionally emitted the old null/readback warning text. R5 behavior preservation emitted expected width-padding warnings.
- Visible result, if applicable: Rendered console validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_R61G_RESULT_APPLICATION_OK`; `R6_R61F_WARNING_POSTPROCESS_OK`; `R6_BAKER_LIFECYCLE_OK`; `R6_BAKER_RUN_PASS_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61g-generated files=2`; `R6_R61G_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61f-generated current=post-r6-r61g-generated`; `R6_R61G_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61g-generated`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61g files=10`; `R6_R61G_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61f current=post-r6-r61g`; final `git diff --check`.
- Pass/partial/fail: Pass for the R6.1G result assembly/application slice and required generated-texture/surface gates. At the time, this was not a full R6 pass because abort-matrix coverage, constants-table extraction, and final full-R6 before/after gates were still pending; abort-matrix coverage was later closed by R6.1H.
- Notes or follow-up: Superseded by the R6.1H abort-matrix result above. Result application remains synchronous/non-awaited; if a future change adds an await after result application starts, it must add staging/rollback validation.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; Vulkan Forward+, AMD Radeon RX 6800 XT for rendered generated-texture hash probes; headless for parser/preload, focused warning/postprocess probe, baker lifecycle/run-pass, R5 behavior preservation, baseline dump, and static diff checks.
- Command, scene, or workflow: Moved image-only diagnostics and CPU image postprocess from `river_manager.gd` into `river_flowmap_baker.gd` behind `process_filter_pass_images()`. RiverManager still owns source-generation timing, final `RiverBakeData` write/save, material binding, bake flag clearing, and completion progress. Moved collision stats/warnings, occupied channel stats, obstacle/terrain/bank feature stats, flat support reductions, logical edge-band synchronization, flow-vector diagnostics assembly, debug-contrast warnings, near-neutral flow warning, and final postprocess `ImageTexture.create_from_image()` calls into the baker. User-facing warnings and diagnostics are routed back through named RiverManager callbacks. Added scratch `.codex-research/r6_r61f_parser_check.gd` and `.codex-research/r6_r61f_warning_postprocess_check.gd`.
- Output or parser errors: No parser errors. The warning/postprocess probe asserted collision warning text, flat support warning text, debug-contrast warning prefixes, near-neutral warning text, diagnostic callback routing, support diagnostic flags, and final texture construction. Generated-texture and baseline probes repeated the known non-fatal `Demo.tscn` invalid UID warning. The focused run-pass probe intentionally emitted the old null/readback warning text. R5 behavior preservation emitted expected width-padding warnings.
- Visible result, if applicable: Rendered console validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_R61F_PARSER_OK`; `R6_R61F_WARNING_POSTPROCESS_OK`; `R6_BAKER_LIFECYCLE_OK`; `R6_BAKER_RUN_PASS_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61f-generated files=2`; `R6_R61F_GENERATED_TEXTURE_DIFF_OK files=2 baseline=post-r6-r61e-generated current=post-r6-r61f-generated`; `R6_R61F_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61f-generated`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61f files=10`; `R6_R61F_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61e current=post-r6-r61f`; final `git diff --check`.
- Pass/partial/fail: Pass for the R6.1F diagnostics/image postprocess slice and required generated-texture/warning parity gates. At the time, this was not a full R6 pass because result assembly/application boundaries, abort-matrix coverage, constants-table extraction, and final full-R6 before/after gates were still pending; result application and abort coverage were later closed by R6.1G and R6.1H.
- Notes or follow-up: Start R6.1G result application next. Do not move final save/material/valid-flowmap semantics outside the R6.1G contract.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; Vulkan Forward+, AMD Radeon RX 6800 XT for rendered generated-texture hash probes; headless for parser/preload, baker lifecycle/run-pass, R5 behavior preservation, baseline dump, and static diff checks.
- Command, scene, or workflow: Moved full filter pass sequencing from `river_manager.gd` into `river_flowmap_baker.gd` behind `run_filter_pass_sequence()`. RiverManager still owns source-generation timing, CPU image postprocess, final `RiverBakeData` write/save, material binding, bake flag clearing, and completion progress. Added scratch `.codex-research/r6_r61e_parser_check.gd` and `.codex-research/r6_generated_texture_hash_probe.gd`. Ran the generated-texture probe in the current workspace and in the scratch `origin/r6` export under `.codex-research/r6-pre-r61d-origin-fresh/`, then compared the fresh old-code and current outputs.
- Output or parser errors: No parser errors. The generated-texture probes repeated the known non-fatal `Demo.tscn` invalid UID warning. The focused run-pass probe intentionally emitted the old null/readback warning text. R5 behavior preservation emitted expected width-padding warnings. Comparing current generated hashes against the older saved-resource RT.1 logs showed the already-known saved-vs-fresh mismatch; the gate result therefore uses fresh old-code generated hashes as the comparator.
- Visible result, if applicable: Rendered console validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_R61E_PARSER_OK`; `R6_BAKER_LIFECYCLE_OK`; `R6_BAKER_RUN_PASS_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61e-generated files=2`; scratch old-code `R6_GENERATED_TEXTURE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6-r61e-generated files=2`; `R6_R61E_RT1_GENERATED_TEXTURE_DIFF_OK files=2 baseline=pre-r6-r61e-generated current=post-r6-r61e-generated`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61e files=10`; `R6_R61E_SURFACE_PROPERTY_DIFF_OK files=10 baseline=post-r6-r61b current=post-r6-r61e`; final `git diff --check`.
- Pass/partial/fail: Pass for the R6.1E pass-sequencing slice and required generated-texture gate. At the time, this was not a full R6 pass because diagnostics/image postprocess, result assembly/application boundaries, abort-matrix coverage, constants-table extraction, and final full-R6 before/after gates were still pending; later R6.1F-H slices closed those bake-pipeline items except constants/final gates.
- Notes or follow-up: Start R6.1F diagnostics and image postprocess next. Do not treat the saved-resource RT.1 mismatch as a pass-sequencing regression; fresh old-code generated output matches current output exactly.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; headless for fresh pre-R6.1D source-image replay from a scratch `origin/r6` export, current R6.1D source-image rerun, and source-image diff reconciliation.
- Command, scene, or workflow: Reconciled the obstacle collision-derived R6.1D source-image mismatch. Added scratch-only `.codex-research/r6_source_image_hash_probe_pre_r61d.gd`, exported `origin/r6` into `.codex-research/r6-pre-r61d-origin-fresh/`, copied the project `.godot` import cache into that scratch export so scenes could load, ran the old RiverManager-helper source-image probe there, copied fresh outputs to `.codex-research/r6-baselines/pre-r6-r61d-fresh/`, reran the current R6.1D source-image probe into `.codex-research/r6-baselines/post-r6-r61d-final/`, and compared full raw-plus-margin source-image dumps.
- Output or parser errors: First scratch replay without `.godot` import cache failed to load imported scene resources; after copying the cache, the fresh pre-R6.1D replay passed. Both old and current source-image runs repeated the known non-fatal `Demo.tscn` invalid UID warning.
- Visible result, if applicable: Headless validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6-r61d-fresh-rerun files=2` in the scratch `origin/r6` export; `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d-final files=2`; `R6_R61D_COLLISION_BASELINE_RECONCILED ignored_collision_probe_variants=4`; `R6_R61D_FULL_SOURCE_IMAGE_DIFF_OK files=2 baseline=pre-r6 current=post-r6-r61d-final`; final `git diff --check`.
- Pass/partial/fail: Pass for the R6.1D full source-image gate. The final current R6.1D dump exactly matches the original pre-R6 source-image baseline for both Demo and obstacle Demo. The earlier obstacle mismatch is reconciled as collision-probe freshness/variant behavior in four untouched collision-derived rows, not a source-helper move regression.
- Notes or follow-up: Superseded by the later R6.1E pass-sequencing result above. Do not carry the four collision-derived row caveat forward as a general ignore rule.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; headless for parser/preload check, source-image hash probe, same-code source-image rerun, source-image diff checks, and R5 behavior preservation.
- Command, scene, or workflow: Moved source-image synthesis helpers from `river_manager.gd` into `river_flowmap_baker.gd`: margin image/texture creation, blank support/features creation, curve grade energy, bend bias, flow speed, and tiled flow offset noise. RiverManager still owns source-generation timing, filter pass sequencing, CPU postprocess, final bake-data write, material binding, bake flag clearing, and completion progress. Updated `r6_source_image_hash_probe.gd` to exercise the baker-owned helpers directly. Added scratch `.codex-research/r6_r61d_parser_check.gd`.
- Output or parser errors: No parser errors after adding explicit local types around the untyped baker accessor. The known non-fatal `Demo.tscn` invalid UID warning repeated. R5 behavior preservation emitted expected width-padding warnings.
- Visible result, if applicable: Headless validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_R61D_PARSER_OK`; `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d files=2`; `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/post-r6-r61d-rerun files=2`; `R6_R61D_SOURCE_IMAGE_DIFF_OK demo`; `R6_R61D_SOURCE_IMAGE_RERUN_DIFF_OK demo`; `R6_R61D_SOURCE_IMAGE_RERUN_DIFF_OK demo_obstacle_flow_test`; `R6_R61D_MOVED_SOURCE_HELPERS_DIFF_OK files=2 ignored_collision_derived_rows=4`; `R6_BAKER_LIFECYCLE_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- Pass/partial/fail: Superseded partial for R6.1D. The implementation and moved-helper hash comparison passed, and same-code source-image reruns were stable in that run; the obstacle collision-derived caveat was resolved by the later full-gate reconciliation recorded above.
- Notes or follow-up: No full filter pass sequencing moved, no RiverManager/self reference was passed into the baker, and RiverManager remains the synchronous result applicator. Scratch artifacts live under `.codex-research/r6-baselines/post-r6-r61d/`, `.codex-research/r6-baselines/post-r6-r61d-rerun/`, `.codex-research/godot-user-r61d*`, and `.codex-research/r6_r61d_parser_check.gd`.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; headless for parser/check-only, focused baker run-pass check, baker lifecycle, and R5 behavior preservation.
- Command, scene, or workflow: Added the smallest `_run_pass(label, pass_callable)` helper inside `river_flowmap_baker.gd`, added baker-owned pass-result validation/abort records, and routed RiverManager's existing `_filter_output_is_valid()` hook through the baker while leaving source-image helpers, full pass sequencing, CPU postprocess, and synchronous RiverManager result application in RiverManager. Added scratch `.codex-research/r6_baker_run_pass_check.gd` to force a null-texture/readback failure and assert the old warning text, abort record fields, renderer cleanup, RiverManager bake-flag cleanup, and no RiverManager/self reach-back through the baker.
- Output or parser errors: No parser errors. The focused probe intentionally emitted the old warning text twice with readback causes: `probe viewport image is empty` and `river hook readback detail`. R5 behavior preservation emitted the expected width-padding sanitizer warnings.
- Visible result, if applicable: Headless validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_R61C_PARSER_OK`; `R6_BAKER_RUN_PASS_OK`; `R6_BAKER_LIFECYCLE_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- Pass/partial/fail: Pass for the R6.1C run-pass helper and focused invalid-output cleanup slice. This is not a full R6 pass because source-image movement, full pass sequencing, full abort matrix, fresh scratch rebake comparison, and final before/after gates remain open.
- Notes or follow-up: No source-image helpers moved, no full pass sequencing moved, no RiverManager/self reference was passed into the baker, and RiverManager remains the synchronous result applicator. The scratch run-pass check lives under `.codex-research` and is not a shipped plugin probe.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; headless for parser/check-only, baker lifecycle, R6 baseline dump, and R5 behavior preservation.
- Command, scene, or workflow: Added `addons/waterways/river_flowmap_baker.gd` with minimal `bake`, `abort`, `is_running`, and `cleanup` API; moved only filter-renderer instantiation/cleanup ownership behind the baker while keeping source-image helpers, pass sequencing, and synchronous RiverManager result application in RiverManager. Ran parser/check-only for `river_flowmap_baker.gd`, `river_manager.gd`, and the scratch lifecycle probe; ran `.codex-research/r6_baker_lifecycle_check.gd`; captured post-R6.1B baseline dumps under `.codex-research/r6-baselines/post-r6-r61b/`; compared against `.codex-research/r6-baselines/post-r6-r64/` with public method/signal line numbers normalized; ran `r5_behavior_preservation_probe.gd`.
- Output or parser errors: No parser errors. The known non-fatal `Demo.tscn` invalid UID warning repeated for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. R5 behavior preservation emitted the expected width-padding sanitizer warnings.
- Visible result, if applicable: Headless validation only; no manual editor UI or visual bake review.
- Stable result marker: `R6_BAKER_LIFECYCLE_OK`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r61b files=10`; normalized comparison marker `R6_R61B_SURFACE_PROPERTY_DIFF_OK files=10`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- Pass/partial/fail: Pass for the R6.1B baker shell and thin renderer lifecycle slice. This is not a full R6 pass because pass sequencing, source-image movement, full abort matrix, fresh scratch rebake comparison, and final before/after gates remain open.
- Notes or follow-up: No source-image helpers moved, no RiverManager/self reference was passed into the baker, and RiverManager remains the synchronous bake result applicator. The scratch lifecycle probe lives under `.codex-research` and is not a shipped plugin probe.

Recorded result:

- Date: 2026-06-14
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; Vulkan Forward+, AMD Radeon RX 6800 XT for rendered editor-validation marker probe; headless for parser/check-only, filter-renderer load check, baseline dump, R4 runtime robustness, and R5 behavior preservation.
- Command, scene, or workflow: Added `addons/waterways/river_editor_validation.gd`, kept RiverManager's `validate_data_textures()` and `validate_filter_renderer()` as public wrappers, added `addons/waterways/probes/r6_editor_validation_probe.gd`, ran parser/check-only on changed scripts, ran the R6.4 marker probe without `--headless`, reran the separate all-19 filter-renderer load check, captured post-R6.4 baseline dumps under `.codex-research/r6-baselines/post-r6-r64/`, compared them against `.codex-research/r6-baselines/post-r6-r63/`, and reran R4/R5 guard probes.
- Output or parser errors: No parser errors. The known non-fatal `Demo.tscn` invalid UID warning repeated for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`. R5 behavior preservation emitted the expected width-padding sanitizer warnings.
- Visible result, if applicable: Rendered console probe only; no manual editor UI click review.
- Stable result marker: `R6_EDITOR_VALIDATION_MENU_SIGNALS_OK data=1 filter=1`; `RIVER_DATA_TEXTURE_TEST: ...`; `FILTER_RENDERER_TEST: ...`; `R6_EDITOR_VALIDATION_PROBE_OK`; `FILTER_RENDERER_LOAD_OK shader_paths=19`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r64 files=10`; normalized comparison marker `R6_R64_SURFACE_PROPERTY_DIFF_OK files=10`; `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- Pass/partial/fail: Pass for the R6.4 editor validation extraction slice. This is not a full R6 pass because bake extraction, abort matrix, fresh scratch rebake comparison, and final before/after gates remain open.
- Notes or follow-up: Public menu smoke behavior still runs the same subset and emits `FILTER_RENDERER_TEST`; all-19 shader path coverage remains separate in `.codex-research/filter_renderer_load_check.gd`. Post-R6.4 artifacts are in `.codex-research/r6-baselines/post-r6-r64/`.

Recorded result:

- Date: 2026-06-13
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console; Vulkan Forward+, AMD Radeon RX 6800 XT for windowed/rendered ripple probes; headless for parser/check-only, R4 runtime robustness, and R6 baseline dump.
- Command, scene, or workflow: Added `addons/waterways/river_ripple_material_owner.gd`, kept RiverManager ripple methods as wrappers, hardened ripple material/debug parity probes, ran parser/check-only on changed scripts, ran the ripple material ownership, ripple field emitter, ripple debug parity, R4 runtime robustness, and R6 baseline dump workflows, then compared pre-R6 and post-R6.3 baseline outputs.
- Output or parser errors: No parser errors in changed scripts. Expected runtime ripple warning cases still emitted during the ownership probe. The known non-fatal `Demo.tscn` invalid UID warning repeated for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Windowed/rendered console probes only; no manual visual review.
- Stable result marker: `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`; `RIPPLE_FIELD_EMITTER_PROBE_OK`; `RIPPLE_DEBUG_PARITY_PROBE_OK`; `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r63 files=10`; normalized comparison marker `R6_R63_SURFACE_NORMALIZED_DIFF_OK files=2`.
- Pass/partial/fail: Pass for the R6.3 runtime ripple extraction slice. This is not a full R6 pass because bake extraction, editor extraction, fresh scratch rebake comparison, abort matrix, and final before/after gates remain open.
- Notes or follow-up: Post-R6.3 artifacts are in `.codex-research/r6-baselines/post-r6-r63/`. Canonical dictionary dumps and full property-list dumps match the pre-R6 baselines exactly. Public method/signal dump differences are line-number-only and pass after normalizing `line=<number>`. Private RiverManager compatibility placeholders for the old runtime ripple fields remain inert so the full property-list dump stays unchanged; live owner state lives in `river_ripple_material_owner.gd`.

Recorded result:

- Date: 2026-06-13
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, headless for resource/property/API baselines
- Command, scene, or workflow: Added and ran `res://addons/waterways/probes/r6_baseline_dump_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA` under `.codex-research/godot-user-r6`; then ran `bake_hash_probe.gd` in hash mode on `res://waterways_bakes/Demo/Water_River.river_bake.res` and `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`.
- Output or parser errors: No parser errors. Non-fatal load warning while opening `Demo.tscn`: invalid UID `uid://bn0wo1sl68vtd`, Godot used the text path for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Not applicable; headless resource/property/API baseline only.
- Stable result marker: `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/pre-r6 files=10`; `BAKE_HASH_PROBE_OK` for both saved demo river bakes.
- Pass/partial/fail: Partial baseline pass. Canonical dictionary, public method/signal, full property-list, and saved-resource texture-hash baselines now exist before R6 implementation moves.
- Notes or follow-up: Baseline artifacts are in `.codex-research/r6-baselines/pre-r6/`. `source_metadata` dumps filter only `bake_revision`; no `bake_revision` remains in the metadata dump files. Fresh scratch rebakes, source-image hashes, mid-bake timing proof, progress label/order documentation, abort matrix, runtime ripple, editor validation, and final before/after diffs remain open.

Recorded result:

- Date: 2026-06-13
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, headless for source-image generation
- Command, scene, or workflow: Added and ran `res://addons/waterways/probes/r6_source_image_hash_probe.gd` with repo-local `APPDATA`/`LOCALAPPDATA` under `.codex-research/godot-user-r6`.
- Output or parser errors: No parser errors. Non-fatal `Demo.tscn` invalid UID warning repeated for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Not applicable; headless source-image hash capture only.
- Stable result marker: `R6_SOURCE_IMAGE_HASH_OK out=res://.codex-research/r6-baselines/pre-r6 files=2`.
- Pass/partial/fail: Partial baseline pass. Full raw-plus-margin source-image hash baselines now exist for Demo and obstacle Demo before source-helper moves.
- Notes or follow-up: Output files are `demo__source_image_hashes.txt` and `demo_obstacle_flow_test__source_image_hashes.txt`; each has context plus 24 source rows. Before/after source-image diff remains unrun until source helpers move.

Recorded result:

- Date: 2026-06-13
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Added and ran `res://addons/waterways/probes/r6_mid_bake_timing_probe.gd` without `--headless`, using repo-local `APPDATA`/`LOCALAPPDATA` under `.codex-research/godot-user-r6`.
- Output or parser errors: No parser errors. Non-fatal `Demo.tscn` invalid UID warning repeated for `res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res`.
- Visible result, if applicable: Rendered console bake only; no manual visual review.
- Stable result marker: `R6_MID_BAKE_TIMING_OK out=res://.codex-research/r6-baselines/pre-r6 files=1`.
- Pass/partial/fail: Partial baseline pass. Flow-speed mid-bake timing trap and progress order are recorded before bake-pipeline moves.
- Notes or follow-up: Output file is `demo_flow_speeds_projecting_flow_trap__mid_bake_timing.txt`. The trap mutates `flow_speeds` at `Projecting flow 0/40 (stride 32)`; all six trap texture hashes match same-run neutral control while final metadata/signature read the mutated speeds. Saved-resource hash comparison in this probe is informational only because fresh rendered-control hashes differ from some saved-resource RT.1 hashes.

## Historical Results Archive

Empty.

## Bake Output Check

Scenario:

- Demo river and obstacle demo river bakes, using fresh scratch rebakes where possible.

Expected generated outputs:

- Flow/foam/noise: identical per-texture hashes before and after R6.
- Distance/pressure: identical per-texture hashes before and after R6.
- Obstacle, terrain contact, bank response, and water occupancy feature textures: identical per-texture hashes before and after R6.
- Metadata: exact canonical match except `bake_revision`.
- Source signature and bake settings: exact canonical match with no ignored keys.

Failure signs:

- Any unexplained RT.1 texture mismatch.
- Any source-image hash mismatch before filter pass sequencing moves.
- Any dictionary diff outside the explicit allow-list.
- Whole-resource hash mismatch treated as a failure without per-texture evidence.

## Runtime API Check

Procedure:

- Dump and diff public RiverManager method/signal surface.
- Run existing runtime and ripple probes.
- Verify runtime ripple material owner semantics with owner-conflict/tree-exit cases.

Expected result:

- Public wrappers stay callable.
- Runtime `set_widths()` and `set_flow_speeds()` remain data-only.
- Ripple owner apply/clear/tree-exit/debug-view behavior is unchanged.

Failure signs:

- Missing public method, changed signal, non-owner clear warning drift, material not restored, or debug material left in the wrong state.

## Editor Workflow Check

Procedure:

1. Run direct `validate_data_textures()` and `validate_filter_renderer()` wrapper calls.
2. Run plugin/menu validation actions.
3. Compare marker text with pre-R6 output.

Expected result:

- RiverManager wrappers remain unconditional and emit the same markers.
- `validate_filter_renderer()` menu behavior still instantiates the current `filter_renderer.tscn` and runs the same smoke-pass subset.
- All-19-pass coverage remains in `filter_renderer_load_check.gd` or an equivalent separate probe.

Failure signs:

- Marker drift, wrapper missing/no-op in probe context, editor-only helper loaded in runtime path, or accidental menu coverage expansion.

## Artifact Hygiene Check

- Scratch project or temporary folder used: record `.codex-research` subfolders per run. Current R6 folders include `.codex-research/r6-baselines/pre-r6/`, `.codex-research/r6-baselines/pre-r6-r61d-fresh/`, `.codex-research/r6-baselines/post-r6-r63/`, `.codex-research/r6-baselines/post-r6-r64/`, `.codex-research/r6-baselines/post-r6-r61b/`, `.codex-research/r6-baselines/post-r6-r61d/`, `.codex-research/r6-baselines/post-r6-r61d-rerun/`, `.codex-research/r6-baselines/post-r6-r61d-final/`, `.codex-research/r6-baselines/post-r6-r61e/`, `.codex-research/r6-baselines/post-r6-r61e-generated/`, `.codex-research/r6-baselines/post-r6-r61f/`, `.codex-research/r6-baselines/post-r6-r61f-generated/`, `.codex-research/r6-baselines/post-r6-r61g/`, `.codex-research/r6-baselines/post-r6-r61g-generated/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-source/`, `.codex-research/r6-baselines/post-r6-r61ag-rerun-generated/`, `.codex-research/r6-r61ag-rerun-logs/`, `.codex-research/r6-pre-r61d-origin-fresh/`, `.codex-research/filter_renderer_load_check.gd`, and `.codex-research/godot-user-*`.
- Active scripts/resources mirrored into scratch before validation: record if applicable.
- Generated bakes/resources created: record both demo river scratch bakes and any `.res` outputs.
- Files or folders that must be excluded from packaging: `.codex-research`, probe dumps, capture PNGs, scratch bakes, profile folders.
- Files or folders safe to delete now: record after R6 validation completes.

## Manual Review Checklist

- [ ] Acceptance criteria in `spec.md` are satisfied.
- [ ] Source timing contract is preserved or deliberate changes are documented and validated.
- [ ] Canonical dictionary dumps are implemented before baseline capture.
- [ ] No broad RiverManager reach-back exists in the baker.
- [ ] Runtime/editor boundary is preserved.
- [ ] Generated resources and metadata remain explicit and inspectable.
- [ ] Human-assisted editor/menu/visible checks are recorded when needed.
- [ ] Parent docs and latest handoff are updated only after validation runs.
