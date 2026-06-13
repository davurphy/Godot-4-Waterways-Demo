# Waterways Architecture And Feature Explainer

Waterways is a Godot 4 add-on for authoring spline-based rivers, baking flow-related data, previewing that data in editor debug views, and exposing a simplified WaterSystem map for runtime systems such as buoyancy.

The current architecture is built around one key idea: the bake stores stable data fields, while the visible water shader turns those fields into animated water. A "flow map" in this project is therefore more than a single direction texture. It is a small data package containing flow, support, terrain contact, bank response, obstacle, foam, grade, and bend information.

Runtime ripples follow the same separation rule. They are transient visual surface detail owned by runtime nodes and editor tooling, not new bake data, WaterSystem data, source signatures, or buoyancy input.

## High-Level Flow

```text
River curve and mesh
        |
        v
Collision, terrain, curve, and obstacle sampling
        |
        v
Per-river RiverBakeData textures
        |
        +--> visible river shader
        +--> debug river shader and editor debug views
        +--> WaterSystem map generation
                    |
                    v
             WaterSystemBakeData for runtime flow, height, and coverage
```

```text
WaterRippleEmitter nodes
        |
        v
WaterRippleField transient simulation, impulse, and boundary textures
        |
        +--> visible river shader ripple-normal overlay
        +--> ripple debug views and editor gizmos
```

## Main Components

### RiverManager

`river_manager.gd` owns the per-river authoring and bake pipeline. It generates the river mesh, builds collision/support inputs, runs filter passes, stores the resulting textures, applies them to visible/debug materials, and writes the external `RiverBakeData` resource.

The most important bake entry point is `_generate_flowmap()`. Despite the historical name, this now generates several packed data maps, not only a traditional flow map.

### FilterRenderer

`filter_renderer.gd` runs GPU filter passes in a temporary `SubViewport`. These passes convert source images into data maps. The pass-shader constant table at the top of `filter_renderer.gd` is the source of truth; the current nineteen pass shaders, grouped by purpose:

- support shaping: `dilate_filter_pass1/2/3` (passes 1+2 alone also serve as the raw proximity field for occupancy), `blur_pass1/2`
- support-derived context: `normal_map_pass` (gradient/normal of the dilated support), `flow_pressure_pass`, `foam_pass`
- fallback flow: `normal_to_flow_filter` (support normals to flow, used when obstacle-avoidance generation is off)
- occupancy: `occupancy_pack_pass` (crisp solid mask + proximity ramp into `water_occupancy`)
- pressure projection solve: `flow_divergence_pass`, `flow_pressure_jacobi_pass`, `flow_gradient_subtract_pass`, `flow_boundary_tangency_pass` (run on HDR float targets via `set_hdr_2d` — 8-bit targets quantize pressure gradients into velocity noise)
- semantic feature masks: `obstacle_feature_mask_filter`, `bank_response_feature_mask_filter`
- authored speed: `flow_speed_scale_pass` (per-point `flow_speeds` magnitude scale, skipped when all points are neutral)
- packing/utility: `combine_pass`, `dotproduct`

The filter passes are shader-based, but their output is read back and stored as bake data.

### RiverBakeData

`resources/river_bake_data.gd` is the per-river data resource. It stores the generated textures, UV2 atlas layout metadata, source signatures, bake settings, and channel metadata.

This resource is what makes the river bake reproducible and stale-data-aware. If the curve, bake settings, or classifier constants change, the source signature changes and the river can report that its bake is no longer current.

### River Shader

`shaders/river.gdshader` is the visible material. It samples the baked maps and computes the final water appearance at draw time:

- animated flow UVs
- normal animation
- foam composition
- pillow highlights
- wake and eddy-line accents
- roughness/specular response
- water depth color
- transparency and refraction
- optional pillow height displacement

This shader is where most visual tuning lives.

### Shared Shader Includes

Since the 2026-06-12 river-refactor track (R2/R3), the shader-side logic that used to be hand-mirrored between `river.gdshader`, `river_debug.gdshader`, and `system_renders/system_flow.gdshader` lives in three shared includes under `shaders/`. This is the structural fix for the drift class that produced four recorded sync failures, including Defect 1:

- `flow_pack.gdshaderinc` — the canonical packed-flow codec (`rg = v * 0.5 + 0.5`, neutral 0.5). Consumed by `river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader`, `lava.gdshader`, and the flow-touching filter passes. Two cross-language mirrors cannot consume an include and are annotated to stay in sync by hand: the `water_helper_methods.gd` encode/decode pair and `flow_solve_common.gdshaderinc`'s internally consistent solve-family encoding (its 0.5 bias is probe-asserted against the CPU pressure seed).
- `river_flow_common.gdshaderinc` — the flow family: the fifteen `flow_*` force uniforms, the boundary feature samplers, `i_flow_projected`, `EPSILON`, `boundary_gradient_at`, `contextual_flow_force`, and `apply_contextual_flow_slide` with its stagnation-centerline fade. Consumed by `river.gdshader`, `river_debug.gdshader`, **and** `system_flow.gdshader` — the WaterSystem flow map is generated by the same force/slide code the visible surface runs.
- `river_surface_common.gdshaderinc` — the surface family (~620 lines): ~80 shared surface uniforms, `FlowUVW`, the pillow stack, wake/eddy gate families, occupancy stilling (`OCCUPANCY_SPEED_RAMP_FULL`), ripple helpers, and the shared displacement `vertex()`. Consumed by `river.gdshader` and `river_debug.gdshader` only — deliberately **not** by `system_flow.gdshader`, which would otherwise inherit ~80 unused surface uniforms and a displacement `vertex()` into the system-map render.

Include order matters: `flow_pack` first, then `river_flow_common`, then (river/debug only) `river_surface_common`. Genuinely divergent debug instrumentation (for example the debug shader's `support_mode` variant of the eddy context search) stays local to `river_debug.gdshader`.

### Runtime Ripple Layer

`water_ripple_field.gd` and `water_ripple_emitter.gd` add optional localized surface disturbance without changing authored river flow. A `WaterRippleField` is a bounded simulation domain. It owns transient ping-pong ripple textures, an impulse texture, a mesh-footprint boundary mask, emitter caps, target ownership, and cleanup. A `WaterRippleEmitter` is an authorable disturbance source. It can emit pulse, continuous, one-shot, or moving impulses into a field through an explicit field path, ancestor lookup, or group routing.

The ripple field uses one production mapping contract: `world_to_ripple_uv`. Emitters, simulation passes, boundary masks, debug views, and river shader sampling all use that same transform, so world-space impulses land at the same texture positions the shader samples. The first implementation supports axis-aligned world bounds; broader transformed or camera-following fields remain future work.

Runtime ripple simulation is GPU-owned through transient viewport textures. Normal gameplay does not read those textures back to the CPU. Boundary masks are generated from intended target river mesh footprints so ripples fade or reject outside the configured water shape instead of flowing through dry gaps, banks, or disconnected channels.

`river_manager.gd` owns the material boundary. Runtime fields apply only planned `i_ripple_*` shader uniforms to intended generated river targets, using owner-scoped material duplication and restore behavior. Clearing, disabling, owner exit, or river tree exit restores the original visible/debug material state and avoids cross-talk between unrelated rivers.

`river.gdshader` treats ripples as a guarded overlay. Disabled or missing textures are neutral, and the accepted first visible path adds ripple-derived normal response without replacing flow animation, pillows, wakes, eddy-line visuals, WaterSystem flow, or buoyancy. Refraction and displacement ripple controls remain reserved until separately tuned and validated.

### River Debug Shader And Debug Views

`shaders/river_debug.gdshader` and `gui/debug_view_menu.gd` expose the internal data and derived masks as editor views. These are important because many baked channels are not meant to be read directly as final visuals. Debug views make it possible to inspect raw source masks, shader gates, and final visual masks separately.

The ripple debug path adds views for raw ripple height, impulse/contact, boundary mask, and visible ripple influence. These views inspect runtime ripple state without making it part of the river bake or WaterSystem map.

### WaterSystem

`water_system_manager.gd` combines contributing rivers into a single `WaterSystemBakeData` map. The system map is runtime-facing and much smaller in scope than the per-river bake:

- R: packed world flow X
- G: packed world flow Z
- B: normalized water height
- A: water coverage

The WaterSystem map is used by runtime consumers such as buoyancy and wet material assignment. It should be regenerated when final/physics-facing flow changes, but visual-only material changes usually should not dirty it.

## Per-River Baked Data

### `flow_foam_noise`

Shader uniform: `i_flowmap`

This is the closest thing to the traditional "flow map", but it also carries foam and phase data.

| Channel | Meaning |
| --- | --- |
| R | packed signed flow X, neutral `0.5` |
| G | packed signed flow Y, neutral `0.5` |
| B | base foam mask |
| A | phase/noise offset for animated flow texture sampling |

The flow channels are baked from a downstream baseline run through the pressure-projection solve (the default obstacle mechanism — see Obstacle Handling below), or from the support-normal fallback (`normal_to_flow` + blur) when obstacle-avoidance generation is off. When any per-point `flow_speeds` factor deviates from neutral, a final bake pass (`flow_speed_scale_pass.gdshader`) scales the finished flow magnitude by the authored factor — direction is untouched, so obstacle non-penetration is preserved, and the WaterSystem map and buoyancy inherit the authored speeds. The visible shader unpacks R/G, applies contextual force shaping, and then uses the result to animate water normals. The runtime hard-boundary slide only runs when `i_flow_projected` is false: a pressure-projected field is divergence-free, and re-bending it would corrupt it.

### `dist_pressure`

Shader uniform: `i_distmap`

This map stores broad flow-energy modifiers.

| Channel | Meaning |
| --- | --- |
| R | bank distance or edge influence |
| G | flow pressure or collision support |
| B | grade/energy from downhill curve analysis |
| A | packed signed bend bias; above `0.5` means outside bend, below `0.5` means inside bend |

The shader combines these channels with material controls such as `flow_distance`, `flow_pressure`, `flow_grade_energy`, and `flow_bend_bias` to compute final flow force.

### `obstacle_features`

Shader uniform: `i_obstacle_features`

This map stores obstacle-relative feature masks.

| Channel | Meaning |
| --- | --- |
| R | contact-anchored pillow or impact source |
| G | downstream wake or eddy seed |
| B | eddy-line or shear source |
| A | obstacle confidence or side-deflection confidence |

Important distinction: these are source features, not final visuals. The visible shader gates them by flow strength, grade energy, bank response, terrain protrusion, confidence, noise, and material settings.

The current visible eddy-line look primarily derives from wake-edge sampling of `obstacle_features.g` plus contextual shader gates. `obstacle_features.b` remains baked, inspectable, and useful in debug/experimental paths, but it is not the main final visible eddy-line driver.

### `terrain_contact_features`

Shader uniform: `i_terrain_contact_features`

This map describes how the water surface relates to terrain or world geometry.

| Channel | Meaning |
| --- | --- |
| R | near-surface terrain/world contact |
| G | shallow depth |
| B | terrain/world protrusion intersection |
| A | source provenance/confidence |

This data is generated from HTerrain sampling when available, with physics fallback sampling. It helps classify hard protrusions, shallow areas, pillow anchors, and bank/terrain contact.

### `bank_response_features`

Shader uniform: `i_bank_response_features`

This map converts terrain contact, grade, bend, and flow direction into semantic bank responses.

| Channel | Meaning |
| --- | --- |
| R | bank friction or drag |
| G | outside-bend wet pressure / bank pillow candidate |
| B | inside-bend shallow/deposition candidate |
| A | hard boundary or protrusion response |

The visible shader and WaterSystem flow shader both use this data for contextual damping, pressure gates, and hard-boundary sliding.

### `water_occupancy`

Shader uniform: `i_water_occupancy`

This map is the crisp solid/water classification the pressure-projection solve and the runtime stilling read. It is optional — bakes made before the occupancy/projection system lack it, and all dependent behavior degrades to identity (`hint_default_black`).

| Channel | Meaning |
| --- | --- |
| R | crisp solid mask: 1 inside obstacle or protruding terrain, 0 water |
| G | solid proximity ramp: 1 at the solid surface, falling to 0 at `RIVER_OCCUPANCY_RAMP_TILES` (0.12) radius |
| B/A | unused (0 / 1) |

The solid source is the collision map union high-confidence terrain protrusion (`RIVER_OCCUPANCY_PROTRUSION_THRESHOLD = 0.9`, gated on provenance ≥ `RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN = 0.75` because collider-sourced protrusion is overhang-blind). At runtime, G drives the clip fade and the advection speed stilling ramp (`OCCUPANCY_SPEED_RAMP_FULL = 0.45` in `river_surface_common.gdshaderinc`: speed is 0 at the solid surface and recovers by mid-ring).

### Obstacle Handling: Pressure Projection

The obstacle mechanism is a bake-time pressure-projection solve (Helmholtz–Hodge decomposition with free-slip solid boundaries) over the downstream baseline flow. Bake metadata records it as `obstacle_avoidance_algorithm = "pressure_projection_free_slip_jacobi_with_normal_to_flow_blur_fallback"`. The legacy SDF-style steering filter was removed in the 2026-06-12 refactor (R1).

During a downstream-baseline bake with obstacle-avoidance generation on:

1. `water_occupancy` is packed from the crisp solid source and its proximity field (`apply_proximity` + `apply_occupancy_pack`).
2. `flow_divergence_pass` computes the baseline field's divergence against occupancy.
3. A Jacobi solve relaxes pressure from a neutral seed (`RIVER_FLOW_PRESSURE_SEED_COLOR`, enc(0) = 0.5): strides `[32, 16, 8, 4, 2, 1, 1, 1]` × 5 iterations per stride = 40 passes, on HDR float targets.
4. `flow_gradient_subtract_pass` subtracts the pressure gradient from the baseline, yielding a divergence-free field.
5. Two `flow_boundary_tangency_pass` rounds enforce tangency at solid boundaries (`RIVER_FLOW_TANGENCY_PASSES = 2`).
6. No post-blur — the projected field is smooth by construction, and blurring would smear velocity back across solid boundaries.

The result guarantees flow does not cross obstacle/bank boundaries (v·n = 0 at solids), splits around solids, stagnates in front of them, and speeds up through constrictions. It is baked into `flow_foam_noise.rg`, and `source_metadata.flow_projected = true` is recorded so every consumer (`river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader` via `i_flow_projected`) skips the runtime hard-boundary slide — re-bending a projected field would corrupt it.

When obstacle-avoidance generation is off (or no collision support exists), the fallback path converts the dilated support's normal map to flow (`normal_to_flow_filter`) and blurs it; such bakes carry `flow_projected = false` and keep the runtime slide.

## What Is Baked

The bake captures data that depends on river geometry, UV2 atlas layout, terrain/world collision, curve shape, and source-classifier rules:

- river-local flow direction (pressure-projected around obstacles by default)
- water occupancy: crisp solid mask plus proximity ramp
- the `flow_projected` metadata flag that gates the runtime slide
- base foam support
- distance and pressure support
- downhill grade energy
- outside/inside bend bias
- terrain contact, shallow depth, and protrusion context
- bank friction, outside-bend pressure, inside-bend deposition, and hard-boundary response
- pillow/impact source masks
- wake/eddy seed masks
- eddy-line/shear source masks
- feature confidence masks
- tile margins for stable UV2 sampling
- source signatures and bake metadata

Changing these usually means the river bake source signature should change and affected river bake resources should be regenerated.

## What Is Runtime Shader Logic

The visible river shader computes the final surface behavior every frame from baked inputs, material uniforms, textures, screen depth, and time:

- animated normal-map flow
- final flow force
- hard-boundary slide (legacy non-projected bakes only — gated off by `i_flow_projected`)
- occupancy clip fade and speed stilling near solids
- steepness proxy from flow direction and view-space up
- final foam amount and softness
- bank foam contribution
- pillow visual masks, reach, smoothing, seam handling, and optional height displacement
- wake visual masks
- eddy-line visual masks
- wake and eddy fleck noise
- specular, roughness, and normal boost
- pillow pressure/highlight coloration
- wake albedo breakup
- depth color
- transparency, refraction, and edge fade
- optional runtime ripple normal overlay from transient field textures

Changing only these visual/material controls usually does not require a river rebake or WaterSystem regeneration.

## Runtime Ripple State

Runtime ripples are intentionally not baked. Their state is rebuilt from scene nodes and runtime textures:

- `WaterRippleField` stores editable scene settings such as `enabled`, `resolution`, `world_bounds`, target river paths or groups, boundary policy, damping, propagation, emitter cap, ripple strength, normal strength, height fade, and boundary fade.
- `WaterRippleEmitter` stores editable scene settings such as target field routing, emitter mode, radius, intensity, falloff, pulse rate, moving emission distance, emit-on-ready behavior, enabled state, and priority.
- `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` are type-specific value resources. Applying a preset copies approved authoring values into ordinary editable properties. Capturing creates a fresh in-memory resource. Presets are not live profile links and do not store runtime textures, target material state, river bakes, WaterSystem data, source signatures, refraction/displacement tuning, or buoyancy behavior.
- Phase 10 editor tooling adds non-runtime helpers: read-only inspector status rows, transient preset selectors, undo-aware Apply actions, capture/save controls with explicit editor-owned `.tres` paths, visual field/emitter gizmos, emitter radius and moving-threshold handles, field `world_bounds` face handles, and an editor-only projected boundary preview.

The editor/runtime boundary is strict. Ordinary inspector status, selector, capture, preview, and gizmo-viewing paths must not call runtime rebuild, reset, emission, RiverManager material, boundary generation, source-signature, bake, WaterSystem, or buoyancy paths. Live-scene runtime buttons remain deferred until a separate bridge proves how edited-scene nodes map to running-scene instances.

## WaterSystem Bake

The WaterSystem bake is a separate, runtime-facing combination step. It renders each contributing river into a shared world-space map, then packs:

| Channel | Meaning |
| --- | --- |
| R | packed world flow X |
| G | packed world flow Z |
| B | normalized water height |
| A | coverage mask |

The WaterSystem flow shader (`system_renders/system_flow.gdshader`) samples the per-river flow, distance/pressure, terrain-contact, and bank-response maps, and consumes `flow_pack.gdshaderinc` and `river_flow_common.gdshaderinc` — so generated runtime flow runs the same `contextual_flow_force` and slide code as visible water, by construction rather than by hand-sync. `system_map_renderer.gd` plumbs each river's `flow_projected` bake metadata into the shader's `i_flow_projected` uniform: projected rivers skip the boundary slide (re-bending a divergence-free field corrupted what buoyant ducks read — Defect 1, fixed 2026-06-12). The shader does not carry the full visual feature set: pillow highlights, wake flecks, eddy-line surface accents, foam color, refraction, occupancy stilling, and similar material details stay in the visible river shader.

System maps have no bake-source signature like river bakes; their staleness signal for shader-output changes is `SYSTEM_FLOW_MAP_VERSION` (`resources/water_system_bake_data.gd`, currently 1), written into `bake_settings` as `system_flow_map_version`. A WaterSystem loading a map with an older version warns and should be regenerated; v1 marks the projected-flow fix above.

## Feature Summary

### River Authoring

- spline/curve-based river layout
- generated river mesh (smoothstep-eased width interpolation; tight-bend edge overlap resolution with targeted relaxation)
- render bounds grown by configured vertical displacement amplitudes (`set_custom_aabb`)
- UV2 atlas layout with padded margins
- per-point width support
- per-point flow speed support (`flow_speeds`, factor 0–2, baked as a post-projection magnitude scale)
- editor generation controls

### Flow And Force Data

- packed local flow vectors
- downstream baseline flow option
- pressure-projected obstacle avoidance (divergence-free, free-slip boundaries)
- water occupancy with proximity ramp; runtime clip fade and speed stilling
- distance/pressure influence
- grade-aware speed-up
- bend-aware inside/outside bias
- contextual bank drag
- shallow-water drag
- hard-boundary slide (legacy non-projected bakes only)

### Terrain And Bank Context

- HTerrain-aware contact sampling
- physics fallback contact sampling
- shallow-depth mask
- protrusion/hard-boundary mask
- bank friction response
- outside-bend pressure response
- inside-bend deposition response

### Visual Water

- animated flow-map water normals
- depth-based color
- transparency and refraction
- edge fade
- base foam from bake
- shader-added foam from grade, bank, pillow, wake, and eddy signals
- pillow/impact highlights
- wake breakup
- eddy-line visual accents
- roughness/specular/normal response for turbulent features
- optional pillow height displacement
- optional runtime ripple normal detail from transient fields

### Debugging And Review

- raw flow direction
- effective flow direction
- final flow strength
- distance/pressure channels
- grade and bend channels
- terrain contact channels
- bank response channels
- pillow source and visual masks
- wake/eddy source and visual masks
- gate-level wake/eddy diagnostics
- ripple raw height, impulse/contact, boundary mask, and visible influence
- editor gizmos for ripple field bounds, target routing, emitter radius/moving thresholds, field bounds handles, and projected boundary previews
- system-map validation paths

### Runtime Ripples And Authoring

- `WaterRippleField` and `WaterRippleEmitter` Add Node script classes with icons
- no-readback GPU feedback simulation through transient runtime textures
- mesh-footprint boundary masks in ripple-field space
- owner-scoped `i_ripple_*` material application and restore through `RiverManager`
- type-specific field and emitter preset resources
- built-in value-starter presets for common local ripple setups
- in-memory preset apply/capture API
- editor-only inspector status, transient Apply controls, capture/save workflow, gizmos, handles, and boundary preview

### Runtime System Integration

- WaterSystem combined map
- world-space flow sampling
- normalized height sampling
- coverage mask
- buoyancy support
- wet-node material assignment support

## Practical Change Boundaries

Use these boundaries when planning changes:

- Material-only visual tuning: edit visible/debug shader uniforms and material response. No river rebake or WaterSystem regeneration should be needed.
- Shader-derived mask tuning: if the source baked masks stay the same, no source signature bump is usually needed.
- Classifier or baked-channel semantic changes: bump the river bake source signature and rebake affected river resources.
- Occupancy or projection-solve changes: treat these as bake-level source-flow changes because they alter `flow_foam_noise.rg` (and `water_occupancy`) — signature bump plus rebake.
- Resource layout changes: update `RiverBakeData`, shader uniforms, debug views, validation, and saved bakes together.
- Final/physics flow changes: update visible river flow, debug flow, `system_flow.gdshader`, WaterSystem generation, saved WaterSystem bakes, and runtime validation together; if `system_flow.gdshader` output changes for identical inputs, bump `SYSTEM_FLOW_MAP_VERSION` and regenerate system maps.
- Shared-include changes: edits to `flow_pack` / `river_flow_common` / `river_surface_common` affect every consuming shader at once — check river, debug, and (for the first two) the system-map render before landing.
- Visual wake/eddy accents: keep separate from real reverse/circulating flow unless a final-flow milestone explicitly scopes WaterSystem and runtime behavior too.
- Runtime ripple changes: keep transient textures, editor helpers, `i_ripple_*` uniforms, and field/emitter presets separate from river bakes, WaterSystem bakes, source signatures, final flow, and buoyancy unless a later physics-facing plan explicitly scopes those systems.

This separation keeps visuals, baked data, and runtime physics from drifting accidentally.
