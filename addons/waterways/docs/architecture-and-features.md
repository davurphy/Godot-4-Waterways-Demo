# Waterways Architecture And Feature Explainer

Waterways is a Godot 4 add-on for authoring spline-based rivers, baking flow-related data, previewing that data in editor debug views, and exposing a simplified WaterSystem map for runtime systems such as buoyancy.

The current architecture is built around one key idea: the bake stores stable data fields, while the visible water shader turns those fields into animated water. A "flow map" in this project is therefore more than a single direction texture. It is a small data package containing flow, support, terrain contact, bank response, obstacle, foam, grade, and bend information.

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

## Main Components

### RiverManager

`river_manager.gd` owns the per-river authoring and bake pipeline. It generates the river mesh, builds collision/support inputs, runs filter passes, stores the resulting textures, applies them to visible/debug materials, and writes the external `RiverBakeData` resource.

The most important bake entry point is `_generate_flowmap()`. Despite the historical name, this now generates several packed data maps, not only a traditional flow map.

### FilterRenderer

`filter_renderer.gd` runs GPU filter passes in a temporary `SubViewport`. These passes convert source images into data maps:

- collision support dilation and blur
- normal-to-flow conversion
- downstream baseline obstacle avoidance
- flow pressure
- foam source masks
- obstacle feature masks
- bank response feature masks
- channel packing

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

### River Debug Shader And Debug Views

`shaders/river_debug.gdshader` and `gui/debug_view_menu.gd` expose the internal data and derived masks as editor views. These are important because many baked channels are not meant to be read directly as final visuals. Debug views make it possible to inspect raw source masks, shader gates, and final visual masks separately.

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

The flow channels are baked from either a downstream baseline plus obstacle avoidance, or the older collision-gradient path depending on generation behavior. The visible shader unpacks R/G, applies contextual force and slide logic, and then uses the result to animate water normals.

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

### SDF-Style Obstacle Steering

Waterways uses SDF terminology for one bake-time obstacle steering path, but it does not maintain a full signed distance field system.

During a downstream-baseline collision bake, the river can create a temporary steering support field from the collision map. The `dilate_filter_pass1/2/3.gdshader` passes expand obstacle support into a distance-like falloff, the support can be blurred, and `normal_map_pass.gdshader` converts that field into a local gradient/normal map. `obstacle_avoidance_flow_filter.gdshader` then uses the support field, obstacle-normal field, downstream baseline flow, and bank-response context to bend flow around obstacles while preserving a minimum downstream component.

This is best described as an unsigned, SDF-style obstacle influence field:

- It is temporary bake data, not a persistent runtime SDF texture.
- It is not a true signed distance field with negative/positive inside/outside distances.
- Its main output is baked back into `flow_foam_noise.rg` as adjusted source-flow direction.
- `dist_pressure` is distance/pressure feature data, not the signed distance field.

The current bake metadata records this path as `bank_context_gated_local_sdf_steering`, with radius and blur controlled by `RIVER_OBSTACLE_AVOIDANCE_SDF_RADIUS_TILES` and `RIVER_OBSTACLE_AVOIDANCE_SDF_BLUR_TILES`.

## What Is Baked

The bake captures data that depends on river geometry, UV2 atlas layout, terrain/world collision, curve shape, and source-classifier rules:

- river-local flow direction
- SDF-style obstacle influence for local flow steering
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
- hard-boundary slide
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

Changing only these visual/material controls usually does not require a river rebake or WaterSystem regeneration.

## WaterSystem Bake

The WaterSystem bake is a separate, runtime-facing combination step. It renders each contributing river into a shared world-space map, then packs:

| Channel | Meaning |
| --- | --- |
| R | packed world flow X |
| G | packed world flow Z |
| B | normalized water height |
| A | coverage mask |

The WaterSystem flow shader samples the per-river flow, distance/pressure, terrain-contact, and bank-response maps so generated runtime flow matches the final flow-force logic used by visible water. It does not carry the full visual feature set: pillow highlights, wake flecks, eddy-line surface accents, foam color, refraction, and similar material details stay in the visible river shader.

## Feature Summary

### River Authoring

- spline/curve-based river layout
- generated river mesh
- UV2 atlas layout with padded margins
- per-point width support
- editor generation controls

### Flow And Force Data

- packed local flow vectors
- downstream baseline flow option
- obstacle-aware flow steering
- temporary SDF-style obstacle influence during bake
- distance/pressure influence
- grade-aware speed-up
- bend-aware inside/outside bias
- contextual bank drag
- shallow-water drag
- hard-boundary slide

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
- system-map validation paths

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
- SDF-style steering changes: treat these as bake-level source-flow changes because they alter `flow_foam_noise.rg`.
- Resource layout changes: update `RiverBakeData`, shader uniforms, debug views, validation, and saved bakes together.
- Final/physics flow changes: update visible river flow, debug flow, `system_flow.gdshader`, WaterSystem generation, saved WaterSystem bakes, and runtime validation together.
- Visual wake/eddy accents: keep separate from real reverse/circulating flow unless a final-flow milestone explicitly scopes WaterSystem and runtime behavior too.

This separation keeps visuals, baked data, and runtime physics from drifting accidentally.
