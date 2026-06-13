# Phase R6 Plan: river_manager.gd Decomposition

## Current Truth

- Status: Draft plan for R6 only. No R6 code has started.
- Parent track: `addons/waterways/docs/spec-driven/features/river-refactor/roadmap.md`
- Gate before implementation: this phase still needs its own `spec.md` and `validation.md` beside this file. This plan is the roadmap/implementation plan, not the whole R6 documentation gate by itself.
- Current branch assumption: continue on `river-refactor` unless the user asks for a fresh phase branch.
- Last completed prerequisite: R5 structural dedup closed on 2026-06-13 with RT.1 texture hashes, exact property-list diff, and `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- Primary objective: move low-coupling responsibilities out of `river_manager.gd` without changing river bake output, metadata, public API behavior, inspector behavior, or runtime ripple behavior.

## Source Scope

Current scan of `addons/waterways/river_manager.gd` after R5:

- Bake entry and guards: `bake_texture()` around line 1103; `_begin_flowmap_bake_request()` / `_clear_flowmap_bake_request()` around 1622.
- Runtime ripple material ownership: public wrappers around 1155-1218; helpers around 1475-1558.
- Bake preflight: `_get_bake_preflight_failures()` around 1561.
- Bake pipeline: `_generate_flowmap()` around 1900-2257.
- Filter validation: `_filter_output_is_valid()` around 2296.
- Source image, diagnostics, and bake helper cluster: roughly 2327-3047.
- Editor validation harnesses: `validate_data_textures()` around 3050 and `validate_filter_renderer()` around 3203.
- Bake writing and generated dictionaries: `_write_bake_data()` around 3327; `get_bake_source_signature()` around 3496; `_get_bake_settings()` around 3695.
- Constant families: `RIVER_*` and bake epsilon constants start near lines 166-276, with neutral distmap and pressure seed constants around 912-917.

Older audit line numbers remain useful for intent, but implementation should use the current line map above.

## Goals

1. Extract the async bake pipeline into `river_flowmap_baker.gd` as a `RefCounted` coordinator.
2. Centralize bake constants into a reviewable table that generates metadata, source signature entries, and bake settings entries.
3. Extract runtime ripple material ownership into a small owner object with the same public RiverManager API.
4. Extract editor validation harnesses into an editor-only helper, preserving menu behavior and console markers.
5. Prove the extraction is behavior-preserving with byte-identical generated bake textures, exact source-signature/settings diffs, source-metadata diffs empty except an explicit dynamic allow-list, and lifecycle abort checks.

## Non-Goals

- No bake algorithm changes.
- No signature bump.
- No new filter passes.
- No shader output changes.
- No changes to `RiverBakeData` channel semantics.
- No R7 GPU-resident solve work.
- No changes to runtime ripple simulation itself; R6.3 only moves RiverManager's material ownership glue.

## Architecture Summary

`RiverManager` stays the public node and authoring surface. R6 moves implementation weight behind narrow collaborators:

| New module | Type | Owns | Does not own |
| --- | --- | --- | --- |
| `river_flowmap_baker.gd` | `RefCounted` | Bake run state, filter renderer lifecycle, pass sequencing, abort cleanup, source image synthesis, diagnostics, and bake result assembly | Inspector properties, RiverManager public API, scene ownership, material binding |
| `river_bake_constants.gd` | `RefCounted` or static script | Canonical rows for bake constants and dictionary generation helpers | Live node state, curve point signatures, texture stats |
| `river_ripple_material_owner.gd` | `RefCounted` | Owner token, material duplication/restoration, owner `tree_exiting` disconnect, `i_ripple_*` validation and parameter application | Ripple simulation, emitter routing, RiverManager mesh/debug-view policy |
| `river_editor_validation.gd` | Editor-only helper script | Validation commands currently embedded in RiverManager, including read-only access to generated bake state needed by those commands | Runtime code paths, mutation of generated bake state |

RiverManager becomes an adapter: collect config and dependencies, call helpers, apply returned textures/resources/materials, emit existing signals, and keep public method names stable.

## Proposed Data Objects

Use dictionaries initially unless the implementation benefits from typed RefCounted classes. Typed classes are allowed when they reduce accidental key drift.

### `BakeConfig`

Assembled by RiverManager before calling the baker, but not a blanket freeze of every live value. Each entry must be tagged in `spec.md` as one of:

- bake-start snapshot,
- live resource intentionally read during the bake,
- final-read callable used only during result application,
- narrow side-effect callable.

The baker must not receive a general RiverManager reference. Passing `self` through a new wrapper is a failed extraction, even if the wrapper is named `BakeConfig`.

- `curve`, only if the spec deliberately preserves live curve reads during source generation; otherwise pass explicit point/handle/offset snapshots
- `mesh_instance`
- `steps`
- `uv2_sides`
- `shape_step_length_divs`
- `shape_step_width_divs`
- `shape_smoothness`
- `widths`
- `flow_speeds`
- `baking_resolution`
- `flowmap_resolution`
- `baking_raycast_distance`
- `baking_raycast_layers`
- `baking_dilate`
- `baking_flowmap_blur`
- `baking_foam_cutoff`
- `baking_foam_offset`
- `baking_foam_blur`
- `bake_generation_behavior`
- `curve_bake_interval`, point arrays, and any other curve-signature fields if R6 snapshots curve state instead of passing the live `Curve3D`
- `filter_renderer_scene`
- `renderer_parent_node` or controlled temporary parent for renderer ownership; this is only a node-parent dependency, not permission to call RiverManager methods
- `collision_reset_root` or a narrow `reset_colliders` callable used by `WaterHelperMethods.reset_all_colliders()`
- `collision_root` or equivalent explicit collision/terrain-query root passed to collision/terrain helper calls; this must be a named dependency, not an implicit RiverManager reach-back
- resource paths or loaded textures needed by the bake, including flow offset noise
- warning and print callbacks for user-facing messages
- progress callback with the exact existing signal text/percentage contract
- callable hooks for terrain/collision helpers only where direct dependencies cannot be removed cleanly; each hook must name the one operation it performs
- `await_frame` or equivalent frame-advance callable; the baker must not call back through a general RiverManager reference just to await `get_tree().process_frame`
- `is_cancelled` / `is_owner_alive` or equivalent liveness callbacks checked before and after awaited operations
- explicit snapshot policy for source-affecting state: R6 must either preserve the old mixed timing or intentionally define a single captured snapshot and validate it

### `BakeResult`

Returned by the baker and applied by RiverManager:

- `flow_foam_noise`
- `dist_pressure`
- `obstacle_features`
- `terrain_contact_features`
- `bank_response_features`
- `water_occupancy`
- `texture_size`
- `source_texture_size`
- `content_rect`
- `texture_layout`
- `source_kind`
- `source_metadata` or the bake-internal metadata inputs, depending on the source-timing contract
- `source_signature`, only if the spec deliberately moves signature generation away from RiverManager's old final-read point
- `bake_settings`, only if the spec deliberately moves settings generation away from RiverManager's old final-read point
- `flow_vector_diagnostics`
- `bake_diagnostics`
- `mesh_global_bounds`, only if captured at the same logical point as the old final write; otherwise RiverManager computes it during result application
- `uv2_sides`
- `revision`

The result should contain everything `_write_bake_data()` needs so RiverManager can assign fields and call `RiverBakeData.finalize()` without recomputing bake internals. It must not accidentally freeze final-live values at bake start. By default, RiverManager keeps ownership of dictionary fields that are currently read at final write; any transfer of `source_signature` or `bake_settings` generation into the baker requires the per-field timing contract below and a mid-bake edit proof.

`BakeResult` must carry final `ImageTexture` resources, not just `Image` data, so R6 can preserve the current `ImageTexture.create_from_image()` timing. The old path creates all generated textures before writing/finalizing `RiverBakeData`, then saves, reapplies bake data, updates shader parameters, clears the bake flag, emits completion, and only then prints the save notice.

Once RiverManager begins applying a successful `BakeResult`, R6 must either complete the whole current non-awaited application sequence or use explicit staging/rollback. Do not add a new awaited cancellation point between texture assignment and `_flowmap_bake_in_progress` cleanup unless validation proves an abort cannot leave half-applied generated textures or stale material validity.

### `BakeAbort`

A small status record returned when a pass fails:

- `ok`
- `label`
- `message`
- `readback_error`
- `stage`
- `renderer_valid`

This exists so every early return in the old pipeline becomes a single controlled exit path.

## Detailed Roadmap

### R6.0 Documentation and Baselines

- [ ] Create R6 `spec.md` beside this plan.
- [ ] Create R6 `validation.md` with the exact validation matrix before code starts. It must define the canonical dump format for dictionary comparisons before any baseline capture happens:
  - `source_signature`: exact sorted dump, no ignored keys.
  - `bake_settings`: exact sorted dump, no ignored keys.
  - `source_metadata`: exact sorted dump with an explicit dynamic allow-list. The known required allow-list is `bake_revision` because `_make_bake_revision()` is time-derived.
  - Any additional ignored key is a review finding, not an implementation convenience.
- [ ] Do not start any R6 implementation until `spec.md` and `validation.md` exist and are checked in. The current `plan.md` alone is not the R6 documentation gate.
- [ ] Add an R6 row to the parent `river-refactor/validation.md` only after R6 validation runs.
- [ ] Add R6 acceptance criteria to the new `spec.md` before implementation:
  - no bake-output hash change,
  - no source-signature/settings change,
  - no metadata change except the validation-doc dynamic allow-list,
  - no public RiverManager API or inspector property-list change,
  - no runtime ripple behavior change,
  - no editor validation marker change,
  - no stuck bake flag or leaked renderer after every abort case.
- [ ] Define the source snapshot contract in `spec.md` before implementation:
  - today `_generate_flowmap()` is stage-timed, not purely bake-start or purely live:
    - it snapshots `generation_behavior` at bake start,
    - its awaited pre-renderer work resumes into live reads of `mesh_instance`, `baking_raycast_layers`, `_steps`, shape divs, and helper-owned scene/collision state at the point collision/terrain helpers run,
    - its curve-derived source helpers read live `curve`, `widths`, and `flow_speeds` at the point each helper runs unless R6 explicitly snapshots those inputs,
    - the flow-speed source decision and image can therefore use values that differ from both bake-request time and final-write time if a user edits during a bake,
  - today `_write_bake_data()` is also mixed-timing, not simply live or simply snapshotted:
    - `source_metadata.generation_behavior`, generation mode, and source kind use the bake-start `generation_behavior`,
    - `source_metadata.flow_speed_scaled` re-reads `flow_speeds` at final write through `_any_flow_speed_non_neutral()`,
    - `get_bake_source_signature()` re-reads `curve.bake_interval`, curve point positions/handles, widths, flow speeds, shape settings, bake settings, live `bake_generation_behavior`, and calculated step count,
    - `_get_bake_settings()` re-reads shape settings, bake settings, live `bake_generation_behavior`, and `_uv2_sides`,
    - `_get_mesh_global_aabb(mesh_instance)` reads final mesh/global transform state,
  - R6 must either preserve that mixed timing or document a deliberate freeze-at-start contract and validate the difference with a mid-bake edit probe.
  - The contract must identify timing by stage: bake request/preflight, source-generation helper execution, filter-pass execution, final dictionary assembly, and result application. A probe edit must record which stage it targeted.
- [ ] Capture pre-R6 dictionary dumps for both demo river bakes:
  - `source_metadata`
  - `source_signature`
  - `bake_settings`
- [ ] Capture the full pre-R6 inspector property list, not only Baking/generated texture rows. The R6 gate may also report a focused Baking/generated subset, but the full dump is the compatibility gate.
- [ ] Capture pre-R6 generated texture hashes with RT.1 using fresh scratch rebakes where possible.
- [ ] Record the full current `river_manager.gd` public method surface. At minimum, explicitly assert these R6-sensitive methods remain callable:
  - `is_bake_in_progress()`
  - `bake_texture()`
  - point editing methods (`add_point()`, `remove_point()`, `set_curve_point_position()`, `set_curve_point_in()`, `set_curve_point_out()`)
  - channel setters (`set_widths()`, `set_flow_speeds()`, `set_bake_generation_behavior()`)
  - material/debug methods (`set_materials()`, `set_debug_view()`)
  - `apply_runtime_ripple_material_state()`
  - `clear_runtime_ripple_material_state()`
  - `has_runtime_ripple_material_state()`
  - `validate_data_textures()`
  - `validate_filter_renderer()`
  - `get_bake_source_signature()`
- [ ] Record the public signal surface and progress semantics. At minimum, `river_changed` and `progress_notified` must still exist, and bake progress labels/order must remain compatible with plugin UI expectations.
- [ ] Add or extend a probe to dump metadata/signature/settings in stable sorted order.
- [ ] Add or extend a probe that can mutate curve/widths/flow_speeds/bake settings during an awaited bake stage, or record this as a named human-assisted case. This closes the source-snapshot timing risk before the baker snapshots state.
- [ ] The mid-bake edit probe or human-assisted case must cover the fields most likely to be frozen by accident: curve points/handles, `curve.bake_interval`, widths, flow speeds, `bake_generation_behavior`, ordinary bake settings, and mesh/global transform if `mesh_global_bounds` moves. It must report which output used the old value and which metadata/signature/settings entry used the new value for at least one edited field, with `flow_speeds` as the minimum trap case.

### R6.1A Bake Pipeline Inventory

- [ ] Mark every awaited operation in `_generate_flowmap()` and in helper bodies it awaits, then classify each await as:
  - source generation
  - filter pass
  - solve loop
  - readback/image postprocess
  - diagnostics
  - final write
- [ ] The await inventory must explicitly include helper-internal frame waits currently hidden behind `WaterHelperMethods.generate_collisionmap()`, `generate_terrain_contact_feature_map()`, and `_await_bake_frame()`. A grep of `_generate_flowmap()` alone is not sufficient.
- [ ] Before adding the baker shell, write the current bake success-order inventory in `validation.md`:
  - final combine outputs are validated,
  - renderer is cleaned up,
  - final textures are read back to `Image`,
  - CPU postprocess/diagnostics run,
  - generated `ImageTexture`s are created and assigned,
  - `RiverBakeData` fields are assigned and finalized,
  - external bake resource save is attempted,
  - `_apply_bake_data()` and shader parameters are refreshed,
  - `valid_flowmap` is set true,
  - `_flowmap_bake_in_progress` is cleared,
  - completion progress is emitted,
  - save/editor-memory notice is printed.
- [ ] Count and name each old abort point. The known current list includes:
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
- [ ] Count awaited non-filter points separately from `_filter_output_is_valid()`-style filter points. At minimum, collision map generation and terrain contact source generation need explicit abort records because they do not naturally fit the run-pass helper, and their internal loop awaits must be cancellable.
- [ ] Record every live non-constant dependency currently read by `_generate_flowmap()` or its candidate helper cluster:
  - `curve`, `curve.bake_interval` if curve state is snapshotted, `widths`, `flow_speeds`
  - `_steps`, `_uv2_sides`, `mesh_instance`
  - `shape_step_length_divs`, `shape_step_width_divs`
  - baking properties and generation behavior
  - `_filter_renderer`
  - `get_tree().root`, `get_tree().process_frame`, and `self` passed to helper methods
  - warning, print, progress, save, and material-application side effects
- [ ] Record live final-write dependencies separately from bake-pipeline dependencies:
  - `_write_bake_data()` computes `source_metadata`, `source_signature`, and `bake_settings` after image postprocess,
  - metadata is mixed-timing: generation behavior/source kind come from the bake-start snapshot, while `flow_speed_scaled` re-reads live `flow_speeds`,
  - `get_bake_source_signature()` re-reads `curve.bake_interval`, curve points/handles, widths, flow speeds, bake properties, live `bake_generation_behavior`, and step count,
  - `_get_bake_settings()` re-reads bake properties, live `bake_generation_behavior`, and `_uv2_sides`,
  - `_any_flow_speed_non_neutral()` re-reads `flow_speeds`,
  - `_get_mesh_global_aabb(mesh_instance)` reads final mesh/global transform state.
- [ ] Decide for each live final-write dependency whether R6 preserves final-read timing or snapshots it earlier. Any earlier snapshot must be named in `spec.md` and covered by the mid-bake edit probe or a human-assisted case.
- [ ] Separate deterministic CPU image helpers from node-dependent operations.
- [ ] Identify functions that can move as private baker helpers without algorithm changes. "Move exactly" means preserving computation and output, not preserving hidden RiverManager field reads:
  - margin image/texture creation
  - blank support/feature image creation
  - curve grade energy source image, only after curve inputs are explicit or live-read timing is deliberately preserved
  - bend bias source image, only after curve inputs are explicit or live-read timing is deliberately preserved
  - flow speed source image, only after flow-speed timing is deliberately preserved or snapshotted and validated
  - bake channel stats
  - flat occupied support reductions
  - flow vector diagnostics formatting inputs
- [ ] Identify functions that should stay in RiverManager initially:
  - public property setters/getters
  - mesh generation and material binding
  - `get_bake_source_signature()` until R6.2 lands
  - editor notifications
- [ ] Add a "no RiverManager reach-back" checklist to the R6 `validation.md`: every baker helper must consume `BakeConfig`, local state, or explicit callbacks only. A general RiverManager reference is forbidden unless a later review item names the exact method and reason.
- [ ] The "no reach-back" checklist must explicitly allow only named callables/dependencies for frame awaits, cancellation/liveness, collision reset, terrain/collision source generation, warnings, prints, and progress. A generic `owner_node`, `collision_owner`, or RiverManager reference is not enough.
- [ ] Treat the current `WaterHelperMethods.generate_collisionmap()` and `generate_terrain_contact_feature_map()` `river` argument as a reach-back hazard: those helpers currently use it for collision-root discovery, progress, and frame awaits. R6 may preserve their algorithm/output, but not by passing a broad RiverManager reference through the baker. If their signatures are changed, the replacement context must expose only named operations: collision-root lookup, progress emit, frame await, and liveness/cancellation.

### R6.1B Baker Shell

- [ ] Do not start this substep until R6.1A has a checked-in dependency inventory and success-order inventory.
- [ ] Add `addons/waterways/river_flowmap_baker.gd`.
- [ ] Give it a minimal API:

```gdscript
func bake(config: Dictionary, progress: Callable, cancellation: Callable = Callable()) -> Dictionary
func abort() -> void
func is_running() -> bool
func cleanup() -> void
```

- [ ] Keep the first version thin: instantiate the filter renderer, run a no-op or single copied helper, and clean up.
- [ ] Move renderer ownership from RiverManager to the baker:
  - instantiate
  - add child to the provided owner node or a controlled temporary parent
  - free on success
  - free on every abort
  - free when RiverManager exits the tree
- [ ] Add liveness checks before and after every awaited operation. Node-free, scene-close, and undo-delete must return an abort record instead of letting the coroutine resume into freed state.
- [ ] Keep pre-renderer awaits owned too: collision-skip frame waits, collision map generation, and terrain-contact generation must be cancellable even before the filter renderer exists.
- [ ] If collision/terrain helper signatures change, preserve the old source images and warning/progress text while replacing their RiverManager reach-back with an explicit bake context or callables.
- [ ] Preserve the current renderer cleanup point unless validation proves an equivalent order: the old path cleans up the renderer after final combine validation and before final `get_image()`/CPU image postprocess.
- [ ] Replace `_flowmap_bake_renderer` direct RiverManager ownership with a baker reference or token.
- [ ] Preserve the R0.3 safety: `tree_exiting` must still unstick `_flowmap_bake_in_progress`.

### R6.1C Run-Pass Helper

- [ ] Add a single helper inside the baker for filter passes:

```gdscript
func _run_pass(label: String, pass_callable: Callable) -> Dictionary
```

- [ ] The helper should:
  - call or await the pass
  - validate non-null texture
  - preserve `last_readback_error`
  - return `{ "ok": true, "texture": texture }` or an abort record
  - optionally emit progress text
- [ ] Port `_filter_output_is_valid()` behavior into the baker without changing warning text.
- [ ] Keep labels identical to old warnings unless a label is clearly wrong.
- [ ] Add a check-only probe that deliberately feeds a bad renderer result and asserts the error text includes the readback diagnosis.

### R6.1D Move Source Image Synthesis

- [ ] Do not start this substep until an intermediate source-image hash probe exists and has captured the pre-move hashes for Demo and obstacle scenes.
- [ ] Move source image creation helpers after tests or probes cover their outputs:
  - blank support source
  - blank obstacle feature source
  - blank terrain contact feature source
  - blank bank response feature source
  - margin image and margin texture helpers
  - grade energy source
  - bend bias source
  - flow speed source
- [ ] The source-image hash probe must cover both raw and margin-padded images where padding exists:
  - collision source and collision-with-margins
  - downstream baseline source and downstream baseline-with-margins
  - blank support/features raw and margin-padded variants
  - terrain contact source, smoothed terrain contact source, and terrain contact-with-margins
  - solid occupancy source and solid occupancy-with-margins
  - grade energy, bend bias, and flow speed raw and margin-padded variants
  - tiled flow offset noise
- [ ] Keep `WaterHelperMethods` source-image algorithms and outputs unchanged. Helper signatures may change only to remove RiverManager reach-back and must be covered by the source-image hashes.
- [ ] Keep `_steps`, `_uv2_sides`, curve data, widths, flow speeds, and point-offset data in `BakeConfig`; do not read RiverManager fields directly from the baker.
- [ ] Treat curve-derived helpers as coupled until their inputs are made explicit:
  - `_calculate_curve_grade_energy_by_step()`
  - `_calculate_curve_flow_speed_by_step()`
  - `_get_curve_point_offsets()`
  - `_sample_flow_speed_at_offset()`
  - `_calculate_curve_bend_bias_by_step()`
  - `_sample_curve_baked_distance()`
- [ ] Validate by comparing intermediate source image hashes on Demo and obstacle scenes before and after the move.
- [ ] Do not rely only on final RT.1 hashes to prove source-helper moves. A margin or occupancy drift must fail at the intermediate hash step before pass sequencing moves.

### R6.1E Move Filter Pass Sequencing

- [ ] Do not start this substep until R6.1D intermediate source-image hashes match after the source-helper move.
- [ ] Move `_generate_flowmap()` pass order into `river_flowmap_baker.gd` with minimal logic edits.
- [ ] Use `_run_pass()` for every filter output that was previously checked by `_filter_output_is_valid()`.
- [ ] Preserve progress messages, especially the Jacobi solve progress:
  - `"Projecting flow %d/%d (stride %d)"`
- [ ] Preserve generation behavior branches:
  - downstream baseline
  - curve only
  - legacy collision only script/API path
- [ ] Preserve support fallback diagnostics:
  - `support_fallback_applied`
  - `support_fallback_reason`
  - `collision_probe_skipped`
  - `collision_support_filters_ran`
- [ ] Keep the pressure solve path byte-identical by not changing pass order, stride order, seed texture format, HDR `set_hdr_2d(true/false)` timing, pressure texture size/format, or tangency pass count.
- [ ] Preserve margin handling and crop geometry exactly:
  - `margin = round(flowmap_resolution / uv2_sides)`
  - `bake_atlas_columns = uv2_sides + 2`
  - crop rect starts at `(margin, margin)` and has the unpadded source resolution
  - noise tiling uses the same slice width and offsets as the old code
- [ ] Validate with RT.1 on generated textures after this substep before continuing.

### R6.1F Move Diagnostics and Image Postprocess

- [ ] Move bake diagnostics that depend only on images:
  - collision stats
  - occupied channel stats
  - obstacle feature stats
  - terrain contact feature stats
  - bank response feature stats
  - flow vector diagnostics input assembly
  - flat occupied support reductions
  - logical edge band synchronization calls
- [ ] Keep warning emission behavior identical. If warnings move into the baker, route them through a callback so RiverManager still owns user-facing Godot warnings.
- [ ] Preserve the "debug contrast" warnings and near-neutral flow warnings.
- [ ] Validate by comparing warning text on a known low-contrast fixture, if cheap.

### R6.1G Result Application in RiverManager

- [ ] Do not start this substep until R6.1E RT.1 passes after pass sequencing and R6.1F diagnostics/postprocess outputs match.
- [ ] Replace `_write_bake_data()`'s direct bake-internal assumptions with a result application method:
  - assign RiverManager texture fields from `BakeResult`
  - compute `mesh_global_bounds` in RiverManager at the old final-write point unless R6 has explicitly chosen and validated an earlier snapshot
  - compute or assign `source_metadata`, `source_signature`, and `bake_settings` according to the per-field timing table; default to RiverManager final-read timing for signature/settings
  - assign `RiverBakeData` fields
  - call `RiverBakeData.finalize()`
  - call `notify_property_list_changed()` only under editor hint, matching the old `_write_bake_data()` point
  - call `WaterHelperMethods.save_river_bake_data(self, bake_data)` after finalization, preserving current storage-result behavior
  - call `_apply_bake_data()` after the save attempt
  - refresh shader parameters in the same order as the old path, including `i_flow_projected`, `i_valid_flowmap`, and `i_uv2_sides`
  - set `valid_flowmap = true` only after the generated textures, bake data, save attempt, `_apply_bake_data()`, and shader refresh have completed
  - clear `_flowmap_bake_in_progress` before emitting the final save/editor-memory notice
  - emit final progress, then print the save/editor-memory notice, then update configuration warnings
- [ ] Do not let the baker mutate RiverManager properties directly.
- [ ] Do not let the baker save resources, call `_apply_bake_data()`, call `set_materials()`, or set `valid_flowmap`.
- [ ] Keep `valid_flowmap` and material validity semantics unchanged.
- [ ] Preserve the editor-memory regenerated warning printed after bake completion.
- [ ] Do not add a new awaited operation inside result application unless the implementation stages all new state and can prove interruption cannot expose partial generated textures, partial `RiverBakeData`, or a stuck bake flag.

### R6.1H Abort Matrix

Implement an explicit abort test strategy before declaring R6.1 complete.

- [ ] Do not start the final R6.1 gate run until every abort point counted in R6.1A has either an automated probe case or a named human-assisted case in R6 `validation.md`.
- [ ] Cover aborts by stage, not only by scenario:
  - pre-renderer awaited waits/source generation, including helper-internal loop awaits,
  - renderer-live filter pass and Jacobi awaits,
  - post-renderer cleanup and CPU image postprocess,
  - RiverManager result application, save attempt, shader refresh, final progress/notice.
- [ ] Scene close while a bake is running.
- [ ] River node freed while a bake is running, including while terrain-contact generation is inside its helper loop.
- [ ] Undo-delete of the river during an awaited pass, including helper-internal frame awaits that are not visible in `_generate_flowmap()`.
- [ ] Forced invalid filter output from a probe.
- [ ] Forced collision generation failure or no collision fallback path.
- [ ] Forced terrain-contact source generation failure or liveness interruption during terrain-contact generation. The current helper normally returns the input image for ordinary precondition failures, so this case needs an injected abort/failing helper, owner-free during await, or another named mechanism rather than assuming a natural null return.
- [ ] Result-application interruption strategy. If result application remains synchronous/non-awaited, record that as the strategy; if any await is added, prove partial application cannot overwrite old valid textures or leave `_flowmap_bake_in_progress` stuck.
- [ ] Duplicate bake request while one is running.
- [ ] Baker `abort()` called more than once.
- [ ] Baker cleanup after successful bake.

Expected result for every abort:

- `_flowmap_bake_in_progress == false`
- no live filter renderer child remains
- no orphan SubViewport remains
- a later bake request can run
- no stale progress source remains
- existing valid bake data is not partially overwritten unless finalization succeeded
- an abort before RiverManager begins result application does not change generated textures, material bindings, `valid_flowmap`, or `RiverBakeData`

### R6.2A Canonical Constants Table Design

- [ ] Do not start this substep until the R6.0 dictionary dump probe exists and can dump old metadata/signature/settings in the canonical validation format.
- [ ] Add `addons/waterways/river_bake_constants.gd`.
- [ ] Define one row per constant or generated literal that participates in metadata, signature, or settings.
- [ ] Recommended row shape:

```gdscript
{
	"name": "obstacle_feature_support_start",
	"value": RIVER_OBSTACLE_FEATURE_SUPPORT_START,
	"metadata_key": "obstacle_features_support_start",
	"signature_key": "obstacle_feature_support_start",
	"settings_key": "obstacle_feature_support_start",
	"signature": "float",
	"metadata": true,
	"settings": true,
	"reason": "Shapes obstacle feature mask bake output."
}
```

- [ ] Include row types for:
  - raw values
  - signature-snapped floats
  - arrays joined as stable strings
  - stable string literals
  - booleans
  - values sourced from `WaterHelperMethods`
- [ ] Add a `reason` for every row that does not feed `source_signature`, regardless of whether it feeds metadata, settings, or both.
- [ ] Add a `review_decision` or equivalent field for non-signature rows so future maintainers cannot mistake the table for automatic signature coverage.
- [ ] Keep dynamic values out of the table:
  - curve points
  - widths and flow speeds per point
  - texture stats
  - diagnostics
  - content rect
  - revision timestamp

### R6.2B Dictionary Builders

- [ ] Do not switch any live dictionary path until the shadow-builder probe compares old and table-generated dictionaries with the R6.0 canonical dump rules.
- [ ] Generate the constant portions of:
  - source metadata
  - source signature
  - bake settings
- [ ] Keep dynamic dictionary assembly explicit and small in RiverManager or a bake-data assembler.
- [ ] Sort generated keys in validation dumps, not necessarily in runtime dictionaries.
- [ ] Add a probe that compares old and table-generated dictionaries before switching the live path.
- [ ] Switch live path only after the probe reports:
  - exact source-signature match,
  - exact bake-settings match,
  - source-metadata match except the validation-doc dynamic allow-list, currently `bake_revision`.
- [ ] The bake signature version remains 28.

### R6.2C Review Checklist for Signature Coverage

Each new or edited constant row must answer:

- Does this value alter generated texture content for identical user inputs?
- Does this value alter mesh geometry that bake output depends on?
- Does this value alter source classification, projection, or map packing?
- If yes, why does it not feed `source_signature`?
- If no, should it still appear in metadata or settings for diagnostics?

This is the structural guard against another R1.2 class miss. The table makes misses visible; it does not make them impossible.

### R6.3 Runtime Ripple Material Ownership Extraction

- [ ] Before adding the owner object, run or inspect `ripple_material_ownership_probe.gd` and record whether it already covers all R6.3 semantics. If it does not, add the focused owner-conflict probe before moving code.
- [ ] Add `addons/waterways/river_ripple_material_owner.gd`.
- [ ] Move state currently stored in RiverManager:
  - `_runtime_ripple_owner_id`
  - `_runtime_ripple_owner_node`
  - `_runtime_ripple_original_material`
  - `_runtime_ripple_original_debug_material`
- [ ] Move helpers:
  - `_validate_runtime_ripple_material_parameters`
  - `_get_runtime_ripple_parameter_names`
  - `_shader_material_has_parameters`, if not used elsewhere
  - `_duplicate_runtime_ripple_material`
  - `_apply_runtime_ripple_parameters`
  - `_restore_runtime_ripple_material_state`
  - `_connect_runtime_ripple_owner`
  - `_disconnect_runtime_ripple_owner`
  - `_on_runtime_ripple_owner_tree_exiting`
- [ ] Keep RiverManager public methods as wrappers:
  - `apply_runtime_ripple_material_state(owner, parameters)`
  - `clear_runtime_ripple_material_state(owner)`
  - `has_runtime_ripple_material_state(owner = null)`
- [ ] Let the owner object return the visible/debug materials to use after apply/clear.
- [ ] Keep RiverManager responsible for `_apply_debug_view_material()` after material changes.
- [ ] Preserve non-owner clear warnings exactly unless validation says the wording is wrong.
- [ ] Validate with existing ripple probes plus a focused owner-conflict/tree-exit probe:
  - owner A applies
  - owner B apply is rejected
  - owner A clears
  - owner B can apply
  - owner tree exit restores materials
  - RiverManager tree exit restores visible and debug materials
  - debug-view toggles keep active runtime ripple state

### R6.4 Editor Validation Harness Extraction

- [ ] Before moving validation helpers, run a caller audit and record it in R6 `validation.md`:
  - plugin menu signal callers,
  - probes or scripts that call `validate_data_textures()`,
  - probes or scripts that call `validate_filter_renderer()`,
  - console marker consumers for `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST`.
- [ ] Before moving validation helpers, inventory their live RiverManager data dependencies:
  - `validate_data_textures()` reads generated textures, `bake_data`, source kind, content rect, UV2 sides, and calculated step count.
  - `validate_filter_renderer()` reads the current filter renderer scene, requires the river inside the tree, awaits renderer passes, and uses the same cleanup semantics as bake renderer cleanup.
- [ ] Add `addons/waterways/river_editor_validation.gd` or an editor-only script under an editor/tools folder if that matches local conventions better.
- [ ] Move editor-oriented validation implementations behind public RiverManager wrappers:
  - `validate_data_textures()`
  - `validate_filter_renderer()`
  - helper methods used only by those routines
- [ ] Keep public RiverManager methods as wrappers unconditionally. Current plugin/menu code calls `RiverManager.validate_data_textures()` and `RiverManager.validate_filter_renderer()` directly, and external scripts may do the same.
- [ ] Make the helper explicit about editor-oriented execution and no runtime dependency, without making the public RiverManager wrappers disappear or silently no-op in probe/script contexts that can call them today.
- [ ] Preserve console markers and warning text.
- [ ] Preserve the current `validate_filter_renderer()` menu behavior exactly: it instantiates the current `filter_renderer.tscn`, runs the same subset of smoke-pass wrappers, and emits the same `FILTER_RENDERER_TEST` marker text.
- [ ] Keep all-19-pass coverage in `filter_renderer_load_check.gd` or an equivalent separate probe. Do not silently expand or change the public menu marker to make it carry that separate gate.
- [ ] Validate by running the existing filter renderer load/check flow, the public menu-wrapper marker check, and direct RiverManager wrapper calls from the same profile-isolated script/probe environment current marker consumers use, comparing expected markers separately.

### R6.5 Cleanup and Interface Tightening

- [ ] Remove dead private methods left behind in RiverManager after extraction.
- [ ] Rename only where it clarifies the new boundary; avoid churn in public names.
- [ ] Keep comments that explain Godot-specific async/rendering quirks.
- [ ] Update parent docs:
  - `river-refactor/roadmap.md` R6 checklist
  - `river-refactor/tasks.md`
  - `river-refactor/validation.md`
  - `river-refactor/session-handoff.md`
  - `addons/waterways/docs/handoffs/handoff-latest.md`
- [ ] Record scratch artifact paths and cleanup status.

## Lifecycle, Cleanup, and Re-entry

This section is the hard gate for R6.1.

### Success Path

- RiverManager accepts a bake request and sets `_flowmap_bake_in_progress = true`.
- RiverManager builds `BakeConfig` after preflight and mesh generation.
- Baker creates the filter renderer and any temporary render nodes.
- Baker runs all source generation and filter passes.
- Baker cleans up the filter renderer at the same logical point as the old path: after final combine validation and before final CPU `get_image()`/image postprocess.
- Baker runs CPU image postprocess and diagnostics.
- Baker returns `BakeResult`.
- RiverManager applies the result in the old order, with no new awaited/cancellable gap unless staging/rollback is implemented:
  - generated `ImageTexture` fields on RiverManager
  - `RiverBakeData` texture and geometry fields
  - `source_metadata`
  - `bake_settings`
  - `source_signature`
  - `RiverBakeData.finalize()`
  - editor-only property-list notification
  - external bake resource save attempt
  - `_apply_bake_data()`
  - explicit material bindings, including `i_flow_projected`, `i_valid_flowmap`, and `i_uv2_sides`
  - `valid_flowmap = true`
- Source metadata/signature/settings are assembled at the documented per-field timing. The default R6 path preserves the old final-read behavior for signature/settings and only uses bake-start values where the old code already did.
- RiverManager clears `_flowmap_bake_in_progress`.
- Progress/UI receives completion.
- RiverManager prints the existing saved/editor-memory warning text after completion state is applied.

### Preflight or Early-Return Path

- Preflight failures before baker creation leave existing bake data untouched.
- RiverManager clears `_flowmap_bake_in_progress`.
- Warning text remains the existing `Cannot generate River flow map: ...` form.
- No renderer should exist yet.

### Awaited Failure Path

- Any awaited source-generation or filter-pass failure returns an abort record, including collision-map generation, terrain-contact source generation, and frame waits inside helper loops.
- Baker owns cleanup of any renderer or temporary viewport it created.
- RiverManager receives no partial `BakeResult`.
- RiverManager clears `_flowmap_bake_in_progress`.
- Existing valid bake data remains unchanged.
- Readback failures include `last_readback_error` as R0.1 required.

### Temporary Node and Resource Ownership

- Baker owns filter renderer lifecycle during bake.
- RiverManager owns public node state, generated mesh, materials, and the final `RiverBakeData` resource.
- Temporary images/textures inside the bake are local to the baker until included in `BakeResult`.
- The result handoff is the only point where RiverManager's generated textures change.
- A baker abort must not overwrite RiverManager's generated textures, `RiverBakeData`, `valid_flowmap`, or material bindings.

### Progress, Dirty-State, and User Feedback

- Progress remains emitted through RiverManager's existing signal so plugin UI does not learn about the baker.
- Baker receives a progress callback and does not directly reference plugin UI.
- Completion warning about editor-memory bake remains user-visible.
- `notify_property_list_changed()` remains editor-only and happens after final application.

### Duplicate or Overlapping Requests

- RiverManager still rejects duplicate bakes while `_flowmap_bake_in_progress` is true.
- Baker should also expose `is_running()` as a second guard.
- Abort followed by a new bake must work without restarting the editor.

### Scene Reload or Runtime Boundary

- Runtime calls must not start editor bake work accidentally.
- Runtime `set_widths()` and `set_flow_speeds()` remain data-only API calls as documented in R4.5.
- Helper scripts must not depend on editor singleton state unless they are explicitly editor-only.

## Validation Plan

### Automated and Scripted

- `git diff --check`
- Godot parser/check-only on changed scripts.
- `r5_behavior_preservation_probe.gd` remains green.
- `r4_runtime_robustness_probe.gd` remains green.
- `filter_renderer_load_check.gd` or equivalent remains green with `shader_paths=19`.
- `system_flow_projected_gate_probe.gd` remains green after bake extraction.
- New dictionary diff probe:
  - source signature diff empty, no ignored keys
  - bake settings diff empty, no ignored keys
  - metadata diff empty except the validation-doc dynamic allow-list, currently `bake_revision`
- Full public RiverManager method/signal-surface diff unchanged, including `river_changed` and `progress_notified`.
- Full inspector property-list diff unchanged.
- New or extended RT.1 scratch rebake comparison:
  - Demo river generated texture hashes identical
  - obstacle demo river generated texture hashes identical
- Intermediate source-image hashes identical before/after source-helper moves:
  - collision source and collision-with-margins
  - downstream baseline source and downstream baseline-with-margins
  - blank support/features raw and margin-padded variants
  - terrain contact source, smoothed terrain contact source, and terrain contact-with-margins
  - solid occupancy source and solid occupancy-with-margins
  - grade energy, bend bias, and flow speed raw and margin-padded variants
  - tiled flow offset noise
  - This full raw-plus-margin list is the gate; do not substitute the shorter summary list from an older validation row.
- New abort-matrix probe where feasible, with any human-only abort case named in R6 `validation.md`.
  - Must include at least one abort/liveness case during a helper-internal await, not only awaits visible in `_generate_flowmap()`.
  - Must state whether result application is synchronous/non-awaited or prove rollback/staging for any awaited application step.

### Human-Assisted

Use human-assisted validation for anything that needs visible Godot editor behavior:

- Start a bake, close the scene mid-bake, reopen, bake again.
- Start a bake, undo-delete or remove the river during an awaited phase, then verify the editor remains usable and a fresh bake can run.
- Confirm the River menu validation actions still call the public RiverManager wrappers and emit the same console markers.
- Confirm no visible change in normal/debug river views after R6 extraction if a windowed run is available.

The exact request must be pasted into chat when needed; do not ask the user to hunt in this file.

### Acceptance Gates

R6 is not closed until all of these are true:

- RT.1 generated texture hashes match before/after for both demo river bakes.
- Intermediate source-image hashes match for the full raw-plus-margin R6.1D list before and after source-helper moves.
- Source-signature and bake-settings diffs are empty; source-metadata diffs are empty except the explicit dynamic allow-list.
- Full public API/signal and full inspector property-list diffs are empty.
- Abort matrix passes across all stage buckets: scene close, node free, undo-delete, invalid filter output, terrain-contact source failure, duplicate request, success cleanup, and result-application interruption where feasible.
- Runtime ripple owner probes pass.
- Editor validation wrappers still run.
- Parent docs and handoffs point at the true next task.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Baker extraction changes pass order or intermediate texture format | Bake output changes without a signature bump | Move pass order first with minimal edits; RT.1 after R6.1E before further cleanup |
| Abort cleanup misses one awaited failure path | Stuck bake flag or leaked renderer returns | Central run-pass helper; explicit abort matrix; baker owns renderer cleanup |
| Config object omits a live dependency | Subtle default drift or null fallback | Complete the R6.1A live-dependency inventory before the baker shell; pass owner/tree/collision/warning/progress dependencies explicitly |
| Constants table makes signature coverage look automatic when it is still a review choice | New R1.2-style stale-bake miss | Require `reason` on every non-signature row and checklist review for new rows |
| Metadata diff gate treats `bake_revision` as static | False failure on every fresh rebake, or worse, broad ignored metadata | R6 validation must define a narrow dynamic allow-list before baseline capture; current known allow-list is only `bake_revision` |
| Runtime ripple material extraction changes owner conflict semantics | Cross-talk between ripple fields or lost material restore | Keep public wrappers; add owner-conflict/tree-exit probe; run existing ripple probes |
| Editor validation extraction accidentally loads editor-only code at runtime | Export/runtime warnings or failures | Put editor helper behind explicit wrapper and avoid singleton access in runtime paths |
| Whole-resource `.res` hashes differ even when texture content is identical | False negative validation | Use RT.1 per-texture content hashes as the gate, as R5 did |

## Implementation Order

1. Write R6 `spec.md` and `validation.md`.
2. Define the canonical dump format and dynamic metadata allow-list in R6 `validation.md`.
3. Build baseline dump/hash/API/signal/property-list/source-image probes and capture pre-R6 evidence.
4. Define and validate the source snapshot contract, including the mid-bake edit case or named human-assisted fallback.
5. Complete the bake success-order, abort-point, live-dependency, and final-write-dependency inventories.
6. Run or extend the runtime ripple owner-conflict/tree-exit probe.
7. Land R6.3 ripple material owner if desired; it is small and now has a focused prerequisite probe.
8. Run the editor-validation caller/data-dependency audit.
9. Land R6.4 editor validation extraction.
10. Add the baker shell and lifecycle ownership.
11. Move source-image helpers only after raw and margin-padded source-image hash baselines exist.
12. Move filter pass sequencing behind `_run_pass()` only after source-image hashes match.
13. Run RT.1 after pass sequencing before continuing.
14. Move diagnostics and image postprocess.
15. Switch RiverManager to apply `BakeResult` only after result-application order and final-write dependency timing are documented.
16. Add the constants table in shadow mode.
17. Switch metadata/signature/settings generation to the table after canonical diffs pass.
18. Run full R6 gates and update parent docs.

The smaller extractions can land before the bake pipeline if the user wants incremental review. The bake pipeline switch should be kept in as few commits as practical so before/after validation remains intelligible.

## Files to Change

- `addons/waterways/river_manager.gd`: shrink to public API, config collection, result application, and helper delegation.
- `addons/waterways/river_flowmap_baker.gd`: new RefCounted bake coordinator.
- `addons/waterways/river_bake_constants.gd`: new canonical constants table and dictionary builders.
- `addons/waterways/river_ripple_material_owner.gd`: new runtime ripple material owner.
- `addons/waterways/river_editor_validation.gd`: new editor validation helper, or equivalent path if a better local editor-tools convention is found.
- `addons/waterways/probes/*`: metadata/signature/settings diff probe; abort-matrix probe; ripple owner probe if existing probes do not cover the extracted owner.
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/spec.md`: required before implementation.
- `addons/waterways/docs/spec-driven/features/river-refactor/r6/validation.md`: required before implementation.
- Parent refactor docs and latest handoff: update when R6 lands.

## Review Checklist

- [ ] Public RiverManager API unchanged.
- [ ] Public RiverManager signals unchanged, especially `river_changed` and `progress_notified`.
- [ ] No signature bump.
- [ ] No shader output change.
- [ ] No generated texture hash change.
- [ ] Raw and margin-padded intermediate source-image hashes match for the full R6.1D list.
- [ ] Source-signature and bake-settings diffs empty; source-metadata diff empty except the explicit dynamic allow-list.
- [ ] Full public RiverManager API surface unchanged.
- [ ] Full inspector property-list unchanged.
- [ ] All 21-plus old abort points represented by controlled baker exits.
- [ ] Abort coverage crosses pre-renderer, renderer-live, post-renderer, and result-application stages.
- [ ] Source snapshot timing is documented and validated, including mid-bake edits or a named human-assisted fallback.
- [ ] Terrain-contact source failure has a controlled abort path.
- [ ] Renderer cleanup happens on success, failure, scene close, node free, and duplicate abort.
- [ ] Runtime ripple owner still restores original materials on owner clear and owner tree exit.
- [ ] Editor validation still reports the same stable markers through menu wrappers and direct RiverManager calls.
- [ ] Docs updated before handoff.
