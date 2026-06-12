# Waterways Data Contract

**Status:** Adopted (Roadmap Phase 1)
**Date:** 2026-06-12
**Machine-readable source of truth:** `resources/river_bake_data.gd` `DEFAULT_CHANNEL_METADATA` / `resources/water_system_bake_data.gd` `DEFAULT_CHANNEL_METADATA` — those dictionaries ship inside every bake. This doc adds the semantics, units, encodings, and consumers that the slugs cannot carry. If the two disagree, the resource constants win and this doc has a bug.

## Conventions

- **Encoding:** all packed signed values use `v × 0.5 + 0.5` (neutral = 0.5). All masks are 0–1 with documented neutral. Linear color space, uncompressed or lossless, no mipmaps (`DEFAULT_IMPORT_PROFILE`).
- **Layout:** every river bake texture is a **padded UV2 atlas** (`padded_uv2_atlas_with_one_tile_margin`): square grid of `uv2_sides²` tiles, one tile per mesh step group, one margin tile band on each side. Tile content continues vertically into top/bottom margins; horizontal neighbor reads must clamp to the fragment's column band (`atlas_column_clamp`). Cross-column logical continuity is restored by `synchronize_uv2_logical_edge_bands`.
- **Units going forward (adopted):** any **new** flow-like data is authored and stored as **true velocity in m/s, world XZ**. Existing channels keep their current dimensionless conventions (documented below) until their consumers migrate; the system map is the first migration candidate (roadmap backlog).

## River bake (`RiverBakeData`)

### `flow_foam_noise`

| Ch | Meaning | Encoding / units | Producers | Consumers |
|---|---|---|---|---|
| R | Flow X, **local mesh-UV space** (+X across width) | Packed signed, neutral 0.5. Dimensionless UV-velocity; downstream baseline magnitude = `RIVER_DOWNSTREAM_BASELINE_STRENGTH` (0.25), then scaled by the authored per-point `flow_speeds` factor (0–`RIVER_FLOW_SPEED_FACTOR_MAX`=2, neutral 1.0) as a final post-projection pass — magnitude only, direction untouched, so the v·n=0 guarantee survives. `source_metadata.flow_speed_scaled` records whether the pass ran. **Not m/s.** Runtime magnitude = decoded value × `contextual_flow_force()` (flow_speed, drags, gates). | Downstream baseline → pressure projection (divergence/Jacobi/gradient-subtract/tangency) or legacy SDF steering → per-point speed scale (`flow_speed_scale_pass.gdshader`) | `river.gdshader` advection (`FlowUVW`), debug arrows, system-map combine |
| G | Flow Y, local UV (+Y = downstream, toward +V) | as R | as R | as R |
| B | Foam mask | 0–1, neutral 0 | foam pass + blur | fragment foam shading |
| A | Phase noise | 0–1, spatial offset for advection cycle decorrelation | tiled noise texture | `FlowUVW` phase offset |

### `dist_pressure`

| Ch | Meaning | Encoding / units |
|---|---|---|
| R | Bank distance / edge influence | 0–1; shader inverts for edge force. Tile-relative distance, not meters. |
| G | Flow pressure / collision support | 0–1; collision proximity. **Caution:** `flow_pressure` uniform boosts force with this — counteracted near solids by occupancy stilling. |
| B | Grade energy (curve-derived slope feature) | 0–1, neutral 0 |
| A | Bend bias (curve-derived) | Packed signed, neutral 0.5, positive = outside of bend |

### `obstacle_features` (masks 0–1, neutral 0)

R = contact-anchored upstream pillow/impact · G = downstream wake/eddy seed (drives `flow_wake_damping`) · B = terrain-energy-gated eddy line/shear · A = side deflection / obstacle confidence. Consumed by pillow shading/height, wake damping, eddy shading. The runtime gates (`pillow_*_gate*`, `flow_wake_damping`, …) are material uniforms — part of this contract's *consumption* side; changing their defaults is a contract change.

### `terrain_contact_features` (masks 0–1, neutral 0 except A)

R = near-surface terrain contact · G = shallow-depth mask · B = protrusion/intersection mask · A = **source provenance**: 0 none, 0.5 physics-collider fallback, 1.0 heightfield. Provenance gates occupancy protrusion (`RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN = 0.75`: collider-sourced protrusion is overhang-blind and excluded).

### `bank_response_features` (masks 0–1, neutral 0)

R = bank friction/drag · G = outside-bend wet pressure / bank pillow candidate · B = inside-bend shallow/deposition candidate · A = hard boundary / protrusion response.

### `water_occupancy` (optional; absent ⇒ all dependent behavior is identity)

| Ch | Meaning |
|---|---|
| R | **Crisp solid mask**: 1 inside obstacle/protruding terrain, 0 water. Sources: collision map ∪ high-confidence protrusion (threshold 0.9). |
| G | Solid proximity: 1 at surface → 0 at `RIVER_OCCUPANCY_RAMP_TILES` (0.12) radius. Drives runtime clip fade and the speed stilling ramp (`OCCUPANCY_SPEED_RAMP_FULL = 0.45`). |
| B/A | Unused (0 / 1). |

### Key metadata fields

`source_signature` (version `RIVER_BAKE_SOURCE_SIGNATURE_VERSION`, currently 27) — staleness detection; bump the version whenever same-inputs bake output changes. Each point entry carries `width` and `flow_speed`. `source_metadata.obstacle_avoidance_algorithm` = `"pressure_projection_free_slip_jacobi"` + solve params; `flow_projected = true` disables the runtime contextual slide (re-bending a projected field would corrupt it).

## System bake (`WaterSystemBakeData.system_map`)

| Ch | Meaning | Encoding / units |
|---|---|---|
| R | Flow X, **world space** | Packed signed, neutral 0.5. Same dimensionless scale as river flow (≈0.25 nominal). **Migration target: m/s** (roadmap backlog) — `buoyant_manager.gd` and future drift/particle consumers should eventually read true velocity. |
| G | Flow Z, world space | as R |
| B | Water height, normalized within `world_bounds` | `world_bounds.position.y + B × world_bounds.size.y` = world height |
| A | Coverage: 0 outside water, 1 valid | Gates sampling; `get_water_flow` returns zero outside |

World↔map via `world_to_map` / `capture_rect`. CPU sampling uses the cached `_sampling_image` (decoded by `buoyant_manager.gd` ducks et al.).

## Runtime (non-baked) fields

- **Ripple field** (`water_ripple_field.gd`, `ripple_simulation.gdshader`): ping-ponged damped wave equation render target, sampled by the river shader for normals (fragment). Channel layout documented in the shader; will join this contract when it gains displacement output (roadmap 3d) and the Crest-derived kernels (roadmap Phase 4).
- **Custom AABB rule:** every vertical vertex-displacement contributor must be listed in `river_manager.gd` `DISPLACEMENT_AABB_SHADER_PARAMETERS`; the mesh's custom AABB grows by the sum of those amplitudes. Adding displacement without registering its amplitude is a contract violation (culling artifacts).

## Change rules

1. New flow-like channels: m/s, world-axis, packed-signed encoding documented here before landing.
2. Any change that alters bake output for identical inputs: bump `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` and note it in the relevant feature doc.
3. New channels get a slug in the resource's `DEFAULT_CHANNEL_METADATA` *and* a row here (semantics, units, neutral, producers, consumers).
4. Neutral values must make absent-texture behavior identity (the occupancy pattern).
