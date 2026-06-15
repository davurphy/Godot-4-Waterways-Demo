# Waterways Architecture And Feature Explainer

Waterways is a Godot 4 add-on for authoring spline-based rivers, baking flow-related data, previewing that data in editor debug views, and exposing a simplified WaterSystem map for runtime systems such as buoyancy.

The current architecture is built around one rule: stable data is baked into explicit resources, while visual water behavior is computed by shaders at draw time. A "flow map" in this project is therefore a data package, not only a direction texture. It contains flow, foam, phase, support, terrain contact, bank response, obstacle, occupancy, grade, bend, metadata, and source-signature information.

As of the river-refactor R7 compute-default acceptance, the accepted default solve path is `canonical_compute_replacing`. It computes the canonical pressure-projection flow and replaces only `flow_foam_noise.r/g`. The explicit `legacy_canvas_item` backend remains available for rollback, comparison, and diagnostics. Legacy removal, backend selector collapse, broader saved-output promotion, `R7_TOLERANCE_V1` relaxation, and `R7_TOLERANCE_V2` are not approved.

Runtime ripples follow the same separation rule. They are transient visual surface detail owned by runtime nodes and editor tooling, not river bake data, WaterSystem data, source signatures, or buoyancy input.

## High-Level Flow

```text
RiverManager
  - curve, mesh, inspector/API surface
  - collision/terrain/curve source preparation
  - material binding, validity, resource writing
        |
        v
RiverFlowmapBaker
  - filter pass sequencing
  - renderer/backend lifecycle and abort cleanup
  - backend selection
  - bake diagnostics/postprocess
        |
        +--> FilterRenderer legacy CanvasItem/SubViewport passes
        |
        +--> RiverFlowmapComputeBackend canonical compute projection
             (default for the accepted R7 solve scope)
        |
        v
RiverManager handoff
        |
        +--> RiverBakeData external resource
        +--> visible river shader
        +--> debug river shader and editor debug views
        +--> WaterSystem map generation
```

```text
WaterRippleEmitter nodes
        |
        v
WaterRippleField transient simulation, impulse, and boundary textures
        |
        +--> RiverManager owner-scoped material state
        +--> visible river shader ripple-normal overlay
        +--> ripple debug views and editor gizmos
```

```text
RiverBakeData from one or more rivers
        |
        v
SystemMapRenderer renders height, alpha, and flow
        |
        v
WaterSystemBakeData
        |
        +--> runtime flow/height/coverage sampling
        +--> buoyancy and wet-node integration
```

## Ownership Boundaries

### RiverManager

`river_manager.gd` is the public per-river authoring owner. It owns the curve, generated mesh, inspector properties, public API/signal surface, visible/debug material setup, bake validity, resource saving, and final `RiverBakeData` application.

The method still named `_generate_flowmap()` prepares source inputs: collision maps, terrain contact images, curve grade and bend sources, optional per-point flow-speed source images, UV2 atlas margins, noise textures, and bake constants. It then delegates the pass sequence and backend work to `RiverFlowmapBaker`. After the baker returns, RiverManager writes the resource, applies shader uniforms, updates `valid_flowmap`, clears bake flags, and emits completion/progress signals.

RiverManager must remain the owner of final resource writing and material binding. The compute backend does not write `.river_bake.res` files and does not bind local RenderingDevice textures directly to river materials.

### RiverFlowmapBaker

`river_flowmap_baker.gd` is a `RefCounted` helper extracted in R6. It owns the bake pass sequence, temporary FilterRenderer instance lifecycle, run-pass validation, abort cleanup, backend selection, backend fallback, and image postprocess/diagnostics before result handoff.

Important backend constants:

- `FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM = "legacy_canvas_item"`
- `FLOWMAP_BACKEND_CANONICAL_COMPUTE_NON_REPLACING = "canonical_compute_non_replacing"`
- `FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING = "canonical_compute_replacing"`
- `FLOWMAP_BACKEND_ACTIVE_SOURCE_SIGNATURE_VERSION = 29`
- `FLOWMAP_BACKEND_REPLACEMENT_GATE_ID = "R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1"`

`get_default_flowmap_backend_mode()` returns `canonical_compute_replacing`. Explicit `legacy_canvas_item` remains supported. Explicit non-replacing compute remains a report/diagnostic path. Explicit compute requests without the accepted evidence can still fall back to legacy by design.

### RiverFlowmapComputeBackend

`river_flowmap_compute_backend.gd` owns local RenderingDevice setup, RIDs, compute shaders, dispatch lists, barriers, synchronization, readback, and cleanup. It is behind the baker and uses the accepted delayed single-submit, wait-3-frames, `sync()`, `texture_get_data()` readback path. Async readback is not accepted for production.

The accepted R7 production scope is deliberately narrow:

- Canonical compute replaces the pressure-projected flow result that becomes `flow_foam_noise.r/g`.
- `flow_foam_noise.b/a` remain legacy-sourced foam/noise channels.
- `dist_pressure`, `obstacle_features`, `terrain_contact_features`, `bank_response_features`, and `water_occupancy` remain legacy-sourced.
- Saved-output promotion is limited to:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- WaterSystem bake resources were not promoted as part of R7.

The compute implementation uses canonical integer texel-space pressure feedback instead of reproducing legacy CanvasItem interpolated-UV sampler artifacts. Legacy parity metrics remain diagnostics under unchanged `R7_TOLERANCE_V1`; they are not the replacement oracle after `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.

### FilterRenderer

`filter_renderer.gd` is the descriptor-driven CanvasItem/SubViewport filter runner. It remains the legacy backend and still owns the non-migrated generation passes used by the default compute path. Its `PASS_DESCRIPTORS` table is the source of truth for shader path, required/default texture policy, and HDR target selection.

The current nineteen pass descriptors, grouped by purpose:

- support shaping: `dilate_h`, `dilate_v`, `dilate_fill`, `blur_h`, `blur_v`
- support-derived context: `normal`, `flow_pressure`, `foam`
- fallback flow: `normal_to_flow`
- occupancy: `occupancy_pack`
- pressure projection legacy path: `flow_divergence`, `flow_pressure_jacobi`, `flow_gradient_subtract`, `flow_boundary_tangency`
- semantic features: `obstacle_feature`, `bank_response`
- authored speed: `flow_speed_scale`
- packing/utility: `combine`, `dotproduct`

The projection descriptors use HDR targets. `last_readback_error` is propagated into bake warnings so readback, null texture, invalid size, and descriptor failures are visible instead of collapsing into a generic bake failure.

### RiverBakeConstants

`river_bake_constants.gd` is the canonical table for reviewable bake constants. Each row declares the constant value, which generated dictionaries it feeds (`source_metadata`, `source_signature`, `bake_settings`), and the review rationale. R6 moved the old hand-maintained metadata/signature/settings echoes into this table so signature coverage decisions are visible in one place.

The active river source signature is version `29`. Version 29 records the accepted R7 canonical compute replacement boundary: pre-R7 replacement bakes are stale because `flow_foam_noise.r/g` can intentionally change under the canonical compute solve. Backend mode is not part of the source signature because it is an internal baker selection surface, not a RiverManager source setting.

### RiverBakeData

`resources/river_bake_data.gd` is the per-river bake resource. It stores:

- generated textures
- UV2 atlas and content-rect metadata
- mesh bounds
- source metadata
- channel metadata
- import profile neutrals
- bake settings
- source signature and `source_signature_version`

`finalize()` deep-copies dictionaries, refreshes default channel/import metadata, and derives `source_signature_version` from the signature. `has_required_textures()` treats `water_occupancy` as optional for compatibility with older bakes, but modern projected bakes produce it and bind it to `i_water_occupancy`.

Important import-profile neutrals:

- packed flow neutral: `(0.5, 0.5)`
- grade energy: `0.0`
- bend bias: `0.5`
- dist/pressure: `Color(0.75, 0.25, 0.0, 0.5)`
- water occupancy: `Color(0.0, 0.0, 0.0, 1.0)`

### Materials, Debug Views, And Reverts

RiverManager owns the visible `ShaderMaterial` and internal debug material. It mirrors visible shader parameters into the debug material when both shaders declare the parameter. Inspector revert behavior uses `RenderingServer.shader_get_parameter_default()` directly, because `ShaderMaterial.property_can_revert()` does not work reliably for the internal material that is not itself inspected.

`river_debug.gdshader` and `gui/debug_view_menu.gd` expose raw bake channels, derived masks, final flow/foam views, and runtime ripple views. Debug views are part of the validation surface: many channels are not meant to be judged directly as final visuals.

`river_editor_validation.gd` owns the menu/public wrappers for data-texture and filter-renderer validation markers (`RIVER_DATA_TEXTURE_TEST`, `FILTER_RENDERER_TEST`) so RiverManager does not carry that editor-only probe implementation.

### Runtime Ripple Material Ownership

`river_ripple_material_owner.gd` owns runtime ripple material duplication and restore. It allows only planned `i_ripple_*` uniforms, duplicates visible/debug materials per owner, prevents two ripple owners from controlling the same river at once, and restores original materials when the owner exits or clears state.

Runtime ripple fields and emitters do not touch river bakes, WaterSystem bakes, source signatures, final flow, or buoyancy.

### WaterSystem And SystemMapRenderer

`water_system_manager.gd` combines contributing rivers into one `WaterSystemBakeData` map for runtime consumers. `system_map_renderer.gd` renders three SubViewport passes:

- height
- alpha/coverage
- flow

The flow render copies the river material flow settings into `system_renders/system_flow.gdshader`, including `i_flow_projected`. Projected rivers skip the runtime hard-boundary slide in the system map for the same reason the visible river shader skips it: re-bending a divergence-free field corrupts the physics-facing flow.

`WaterSystemBakeData.SYSTEM_FLOW_MAP_VERSION` is currently `1`. System maps do not have a river-style source signature; `system_flow_map_version` in `bake_settings` is their staleness signal for shader-output changes. Version 1 marks the projected-flow fix. A WaterSystem loading an older map warns and should be regenerated.

Runtime sampling uses the baked system map for world-space flow X/Z, normalized height, and coverage. `covers_world_position()` lets runtime systems choose a WaterSystem by coverage instead of by nearest origin.

## Bake Pipeline

The default downstream-baseline collision-support bake is:

1. RiverManager generates or refreshes the river mesh.
2. RiverManager builds source images: collision support, terrain contact, curve grade, bend bias, optional per-point flow speed, blank fallback maps, and padded UV2 atlas margins.
3. RiverFlowmapBaker runs the filter/backend sequence:
   - bank response from baseline flow, terrain contact, grade, and bend
   - collision pressure, blur, dilation, and normal map
   - water occupancy from collision plus high-confidence terrain protrusion
   - obstacle feature masks from baseline flow, normal/support, bank response, terrain contact, and grade
   - selected projection backend:
     - default `canonical_compute_replacing`
     - explicit `legacy_canvas_item`
   - foam and blurred foam
   - optional per-point flow-speed magnitude scale
   - final `flow_foam_noise` and `dist_pressure` combine passes
4. RiverFlowmapBaker postprocesses images, computes diagnostics, softens saturated support channels when needed, and returns result dictionaries.
5. RiverManager writes `RiverBakeData`, saves through `WaterHelperMethods.save_river_bake_data()`, applies materials, and updates validity.

Generation behavior variants remain:

- `downstream_baseline_collision_support`: default; uses downstream baseline plus collision/occupancy/projection.
- `curve_only`: script/API-only or special fallback behavior that skips collision probing.
- `legacy_collision_only`: compatibility/script behavior, retained intentionally.

## Per-River Baked Data

### `flow_foam_noise`

Shader uniform: `i_flowmap`

| Channel | Meaning |
| --- | --- |
| R | packed signed flow X, neutral `0.5` |
| G | packed signed flow Y, neutral `0.5` |
| B | base foam mask |
| A | phase/noise offset for animated flow texture sampling |

For default projected bakes, R/G are the pressure-projected flow. Under the accepted R7 default, those two channels come from `canonical_compute_replacing` when the projected path runs. B/A remain produced by the legacy filter/packing path.

When any per-point `flow_speeds` factor deviates from neutral, `flow_speed_scale` scales the finished flow magnitude after projection. Direction is untouched, so obstacle non-penetration is preserved and the WaterSystem map inherits authored speed intent when regenerated.

### `dist_pressure`

Shader uniform: `i_distmap`

| Channel | Meaning |
| --- | --- |
| R | bank distance or edge influence |
| G | flow pressure or collision support |
| B | curve-derived grade/energy |
| A | packed signed bend bias; above `0.5` means outside bend, below `0.5` means inside bend |

If this texture is missing, RiverManager binds the code-side neutral texture `Color(0.75, 0.25, 0.0, 0.5)` to both visible and debug materials.

### `obstacle_features`

Shader uniform: `i_obstacle_features`

| Channel | Meaning |
| --- | --- |
| R | contact-anchored pillow or impact source |
| G | downstream wake or eddy seed |
| B | terrain/energy-gated eddy-line or shear source |
| A | side-deflection or obstacle confidence |

These are source features, not final visuals. The visible shader gates them by flow strength, grade, bank response, terrain contact, confidence, noise, and material settings.

The current visible eddy-line look primarily derives from wake-edge sampling of `obstacle_features.g` plus contextual shader gates. `obstacle_features.b` remains baked, inspectable, and useful in debug/experimental paths.

### `terrain_contact_features`

Shader uniform: `i_terrain_contact_features`

| Channel | Meaning |
| --- | --- |
| R | near-surface terrain/world contact |
| G | shallow depth |
| B | terrain/world protrusion intersection |
| A | source provenance: none, physics fallback, or HTerrain |

This data is generated from HTerrain sampling when available, with physics fallback sampling. It helps classify shallow water, protrusions, pillow anchors, and bank/terrain contact.

### `bank_response_features`

Shader uniform: `i_bank_response_features`

| Channel | Meaning |
| --- | --- |
| R | bank friction or drag |
| G | outside-bend wet pressure / bank pillow candidate |
| B | inside-bend shallow/deposition candidate |
| A | hard boundary or protrusion response |

The visible shader and WaterSystem flow shader both use this data for contextual damping, pressure gates, and hard-boundary slide behavior on legacy non-projected bakes.

### `water_occupancy`

Shader uniform: `i_water_occupancy`

| Channel | Meaning |
| --- | --- |
| R | crisp solid mask: 1 inside obstacle or protruding terrain, 0 water |
| G | solid proximity ramp: 1 at solid surface, falling to 0 at `RIVER_OCCUPANCY_RAMP_TILES` |
| B/A | unused (0 / 1) |

The solid source is collision union high-confidence terrain protrusion (`RIVER_OCCUPANCY_PROTRUSION_THRESHOLD = 0.9`, provenance >= `RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN = 0.75`). At runtime, G drives clip fade and speed stilling. `OCCUPANCY_SPEED_RAMP_FULL = 0.45` lives in `river_surface_common.gdshaderinc`.

## Obstacle Handling: Pressure Projection

The obstacle mechanism is a bake-time pressure-projection solve with free-slip solid boundaries over the downstream baseline flow. Bake metadata records:

`obstacle_avoidance_algorithm = "pressure_projection_free_slip_jacobi_with_normal_to_flow_blur_fallback"`

The old SDF steering filter and `RIVER_OBSTACLE_AVOIDANCE_*` constant family were removed in R1. Historical docs may mention them as history only; active code and shaders do not use them.

Projected-flow steps:

1. Pack `water_occupancy` from crisp solid source and proximity.
2. Compute baseline divergence.
3. Relax pressure from `RIVER_FLOW_PRESSURE_SEED_COLOR`, where enc(0) is `0.5`.
4. Use strides `[32, 16, 8, 4, 2, 1, 1, 1]` with 5 iterations per stride: 40 Jacobi passes.
5. Subtract pressure gradient from baseline flow.
6. Run two boundary tangency passes.
7. Do not post-blur the projected flow, because blur would smear velocity back across solid boundaries.

The accepted R7 compute path performs the canonical pressure feedback in compute. The legacy CanvasItem implementation of the same solve remains selectable as `legacy_canvas_item` for comparison, fallback, and diagnostics.

When obstacle-avoidance generation is off or no collision support exists, the fallback converts the dilated support normal map to flow (`normal_to_flow`) and blurs it. Such bakes carry `flow_projected = false` and keep the runtime hard-boundary slide enabled.

## Shared Shader Includes

The river-refactor R2/R3 work moved hand-mirrored shader logic into shared includes under `shaders/`:

- `flow_pack.gdshaderinc`: canonical packed-flow codec. Consumed by `river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader`, `lava.gdshader`, and flow-touching filters. GDScript and solve-shader mirrors are annotated where includes cannot be consumed.
- `river_flow_common.gdshaderinc`: shared flow force uniforms, feature samplers, `i_flow_projected`, `contextual_flow_force`, and boundary slide logic. Consumed by river, debug, and system-flow shaders.
- `river_surface_common.gdshaderinc`: shared visible/debug surface families, including pillow, wake, eddy, occupancy stilling, runtime ripple helpers, and shared displacement `vertex()`. Consumed only by `river.gdshader` and `river_debug.gdshader`.

Include order matters: `flow_pack`, then `river_flow_common`, then `river_surface_common` for river/debug shaders. `system_flow.gdshader` intentionally consumes only the first two so the WaterSystem render does not inherit surface-only uniforms and vertex displacement.

## Runtime Shader Logic

The visible river shader computes final surface behavior every frame from baked inputs, material uniforms, textures, screen depth, and time. This layer includes:

- animated normal-map flow
- final flow force from baked flow plus grade, bend, bank, and shallow-water controls
- hard-boundary slide for legacy non-projected bakes only
- occupancy clip fade and speed stilling near solids
- final foam mix and softness
- bank foam, pillow foam, wake, and eddy-line visual accents
- pillow masks, material response, smoothing, seam handling, and optional height response
- wake breakup and eddy fleck noise
- specular, roughness, normal boost, pressure/highlight coloration, depth color, transparency, refraction, and edge fade
- optional runtime ripple normal detail from transient field textures

Changing only these material/visual controls usually does not require a river rebake or WaterSystem regeneration. Changing source classifiers, packed channel semantics, occupancy/projection math, or final physics-facing flow does.

## WaterSystem Bake

The WaterSystem bake packs one runtime-facing map:

| Channel | Meaning |
| --- | --- |
| R | packed world flow X |
| G | packed world flow Z |
| B | normalized water height |
| A | coverage mask |

`system_flow.gdshader` samples the river bake and consumes `flow_pack` plus `river_flow_common`, so the system map uses the same flow-force and projected-flow gate code as the visible/debug shaders. It does not include visual-only features such as pillow highlights, foam color, wake flecks, ripple detail, refraction, or occupancy stilling.

Regenerate a WaterSystem map when final/physics-facing flow changes. R7 intentionally did not promote WaterSystem resources when the two Demo river bakes were promoted to source signature v29, so stale-map warnings in validation are expected until those maps are deliberately regenerated.

## Runtime Ripple Layer

`water_ripple_field.gd` and `water_ripple_emitter.gd` add optional localized surface disturbance without changing authored river flow.

- `WaterRippleField` owns bounded simulation settings, transient ping-pong textures, impulse textures, boundary masks, target routing, cleanup, and editor gizmos.
- `WaterRippleEmitter` owns pulse, continuous, one-shot, and moving impulse settings.
- `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` copy approved authoring values into ordinary properties; they are not live profile links and do not store runtime textures, bakes, WaterSystem data, source signatures, or buoyancy behavior.

R4 hardened runtime behavior: ripple simulation steps are clamped to one fixed step per `_process`, impulses survive long enough to be sampled, hitch recovery drops backlog instead of bursting, late group-routed targets refresh, and API-registered targets survive runtime cleanup.

## Feature Summary

### River Authoring

- spline/curve-based river layout
- generated river mesh with smooth width interpolation and tight-bend edge-overlap relaxation
- custom render bounds expanded by configured vertical displacement amplitudes
- padded UV2 atlas layout
- per-point width support
- per-point `flow_speeds` support, with neutral 1.0 and authored magnitude scale 0-2
- editor bake/generation controls

### Flow And Force Data

- packed local flow vectors
- downstream-baseline collision-support bake mode
- canonical pressure-projected obstacle avoidance by default
- explicit legacy CanvasItem projection backend for comparison and rollback
- water occupancy with solid mask and proximity ramp
- distance/pressure influence
- curve-derived grade energy
- curve-derived bend bias
- contextual bank, shallow-water, inside-bend, and hard-boundary responses
- hard-boundary slide for legacy non-projected bakes

### Terrain, Bank, And Obstacle Context

- HTerrain-aware contact sampling
- physics fallback contact sampling
- shallow-depth, protrusion, and contact-provenance masks
- bank friction, outside-bend pressure, inside-bend deposition, and hard-boundary response masks
- pillow/impact, wake/eddy seed, eddy-line/shear, and obstacle-confidence masks

### Visual Water

- animated flow-map water normals
- depth-based color, transparency, refraction, and edge fade
- base foam from bake plus shader-side foam contributions
- pillow/impact highlights and optional height response
- wake breakup and eddy-line accents
- roughness/specular/normal response for turbulent features
- optional runtime ripple normal detail from transient fields

### Debugging And Review

- raw and effective flow direction
- final flow strength
- distance, pressure, grade, bend, terrain-contact, bank-response, obstacle, and occupancy channels
- pillow, wake, eddy, foam, and gate-level diagnostics
- ripple raw height, impulse/contact, boundary mask, and visible influence views
- shared probes for bake hashes, debug captures, system-flow comparison, projected-flow gates, R6 surface/constant guards, and R7 compute selection/cleanup/performance checks

### Runtime Integration

- WaterSystem combined map
- world-space flow sampling
- normalized height sampling
- coverage mask and `covers_world_position()`
- buoyancy support
- wet-node material assignment support

## Refactor-Visible Feature Changes

The river-refactor track made these documentation-visible changes:

- R0 fixed bake/error robustness, neutral `i_distmap` binding, no-op gizmo undo behavior, and first-tile UV2 margin handling.
- RT added shared validation probes, including bake hashing, pixel captures, system-flow comparison, and flow-solve seed assertions.
- R1 removed legacy SDF steering code, added signature coverage for missed source inputs, serialized `water_occupancy`, and bumped river source signatures to v28.
- R2 fixed system-flow projected-flow handling and added `SYSTEM_FLOW_MAP_VERSION = 1`.
- R3 extracted `flow_pack`, `river_flow_common`, and `river_surface_common`, and moved inspector reverts to live shader defaults.
- R4 hardened runtime ripple, curve-width generation, WaterSystem coverage-aware buoyancy binding, and runtime/editor guards.
- R5 made FilterRenderer pass descriptors, per-point channel helpers, SystemMapRenderer readbacks, RiverBakeData finalization, and Baking inspector rows table-driven.
- R6/R6.5 split RiverManager internals into `RiverFlowmapBaker`, `RiverBakeConstants`, `RiverRippleMaterialOwner`, and `RiverEditorValidation`, while preserving public API, signal, and property-list behavior.
- R7 accepted `canonical_compute_replacing` as the switched/default solve path for the approved scope, with source signature v29 and explicit legacy fallback retained.
- R8 corrected the architecture/data-contract docs after the early refactor slices; this document supersedes that earlier snapshot with R6/R7 state.

## Practical Change Boundaries

Use these boundaries when planning changes:

- Material-only visual tuning: edit visible/debug shader uniforms and material response. No river rebake or WaterSystem regeneration should be needed.
- Shader-derived visual mask tuning: if baked source masks stay the same, no source signature bump is usually needed.
- Classifier or baked-channel semantic changes: update `RiverBakeData`, source metadata, validation, and the river source signature; rebake affected resources.
- Occupancy or projection-solve changes: treat as bake-level source-flow changes because they alter `flow_foam_noise.r/g` and/or `water_occupancy`; update signature policy and regenerate affected river bakes.
- Backend changes inside the approved R7 scope: preserve `flow_foam_noise.r/g` as the only compute-migrated generated channels unless a new protocol expands scope.
- Legacy CanvasItem removal or backend selector collapse: not approved. Define and run a separate explicit side-by-side comparison/removal protocol first.
- R7 tolerance policy: keep `R7_TOLERANCE_V1` unchanged and do not introduce `R7_TOLERANCE_V2` without a separate accepted protocol.
- Saved-output promotion: do not broaden beyond the two accepted Demo `.river_bake.res` files without a new protocol.
- Final/physics flow changes: update visible river flow, debug flow, `system_flow.gdshader`, WaterSystem generation, saved WaterSystem bakes, and runtime validation together; if `system_flow.gdshader` output changes for identical inputs, bump `SYSTEM_FLOW_MAP_VERSION`.
- Shared include changes: edits to `flow_pack` or `river_flow_common` affect river, debug, and system-map renders; edits to `river_surface_common` affect visible and debug river shaders.
- Runtime ripple changes: keep transient textures, editor helpers, `i_ripple_*` uniforms, and field/emitter presets separate from bakes, WaterSystem maps, source signatures, final flow, and buoyancy unless a later physics-facing plan explicitly scopes those systems.

This separation keeps visuals, baked data, compute backends, and runtime physics from drifting accidentally.
