# River Flowmap Seams Changelog

## 2026-06-11 - Signature 23 Seam Continuity Pass

Status: implemented and probe-validated for the two demo river bakes.

Affected bakes:

- `res://waterways_bakes/Demo/Water_River.river_bake.res`
- `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`

Primary outcome:

- The saved bake data now has zero delta at the actual duplicated UV2 segment edge, depth `0`, for all currently prioritized seam-positive channels:
  - `flow_foam_noise.rgba`
  - `dist_pressure.b`
  - `dist_pressure.a`
  - `obstacle_features.rgba`
  - `terrain_contact_features.rgba`
  - `bank_response_features.rgba`

## Root Cause Fixes

### UV2 World-Sample Tile Classification

Problem:

- `_get_uv2_world_sample()` classified source pixels with floating tile divisions.
- The UV2 atlas and mesh generation use floored integer tile partitions.
- On a 256-pixel source split into 5 UV2 sides, some pixels at segment boundaries were assigned to the wrong tile.
- The barycentric lookup then searched the wrong segment triangles and returned an empty world sample.
- Empty samples produced blank terrain/contact rows at duplicated segment edges.

Fix:

- `_get_uv2_world_sample()` now uses the same floor-partition logic as UV2 atlas tile rect generation.
- Bake signature was first bumped from `20` to `21`.
- Source signature records:
  - `uv2_world_sample_tile_classifier = floor_partition_match_tile_rect`

### Grade And Bend Continuity

Problem:

- `dist_pressure.b` grade/energy was painted as one value per UV2 tile.
- `dist_pressure.a` bend bias varied across width, but used one signed bend value per tile.
- Adjacent duplicated segment edges could therefore represent the same river position but carry different grade or bend values.
- Bank-response green/blue channels amplified those discontinuities.

Fix:

- Grade/energy now uses vertex-aligned longitudinal interpolation across the UV2 tile length.
- Bend bias now uses vertex-aligned longitudinal interpolation and a vertex-aligned cross-river ratio.
- Bake signature was bumped to `22`.
- Source signature records:
  - `grade_energy_source_sampling = vertex_aligned_longitudinal_lerp`
  - `bend_bias_source_sampling = vertex_aligned_longitudinal_lerp`
  - `bend_bias_lateral_sampling = vertex_aligned_cross_river_ratio`

### Derived Feature Edge Sync

Problem:

- Some filter-derived maps still had exact-edge discontinuities after the source maps were fixed.
- These maps can sample offsets or neighboring pixels during filter passes, so duplicated edge rows can diverge even when their source world position is the same.
- Affected maps included foam/support, obstacle features, and bank response.

Fix:

- Added a narrow post-filter synchronization pass for the exact duplicated logical edge row.
- The pass averages both sides of each logical step join only at depth `0`.
- Applied to:
  - `flow_foam_noise`
  - `dist_pressure`
  - `obstacle_features`
  - `bank_response_features`
- Not applied to `terrain_contact_features`; that source map remains directly generated from UV2-to-world terrain/contact sampling.
- Bake signature was bumped to `23`.
- Source signature records:
  - `filtered_feature_edge_sync_depth_pixels = 1`

## Files Changed

- `addons/waterways/water_helper_methods.gd`
  - Added atlas-matching UV2 axis classification for world sampling.
  - Added `synchronize_uv2_logical_edge_bands()` and helpers for exact logical edge synchronization.

- `addons/waterways/river_manager.gd`
  - Bumped `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` to `23`.
  - Updated grade and bend source generation to use vertex-aligned interpolation.
  - Applied derived-map edge synchronization after filter readback.
  - Added source-signature metadata for the new sampling and edge-sync behavior.

- `waterways_bakes/Demo/Water_River.river_bake.res`
  - Rebuilt with signature `23`.

- `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
  - Rebuilt with signature `23`.

- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/symptoms and initial suspects.md`
  - Updated with the investigation plan, probe results, root causes, fixes, and final signature `23` validation.

## New Diagnostic Probes

- `probes/river_flowmap_seam_probe.gd`
  - Loads saved bakes and audits logical UV2 segment-edge deltas across priority channels.
  - Reports same-column joins, row-wrap joins, and non-logical atlas column edges.

- `probes/river_flowmap_world_sample_probe.gd`
  - Loads demo scenes and checks UV2 edge pixels against `_get_uv2_world_sample()`.
  - Confirms duplicated edge pixels resolve to the same world position and computed contact values.

- `probes/river_flowmap_seam_rebake_demo_bakes.gd`
  - Rebuilds and saves only the two affected demo river bake resources.
  - Does not regenerate WaterSystem bakes.

## Validation

Passed:

- Godot parser check for `res://addons/waterways/water_helper_methods.gd`
- Godot parser check for `res://addons/waterways/river_manager.gd`
- `git diff --check`
- `RIVER_FLOWMAP_SEAM_REBAKE_OK`
- `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`
- `RIVER_FLOWMAP_SEAM_PROBE_OK`

Final saved-bake audit result:

- Both demo bakes report signature `23`.
- All priority logical edge depth `0` max deltas are `0.0`.

## Remaining Follow-Up

- Run a human-visible editor/runtime pass against the signature `23` bakes.
- If a visible seam remains, investigate shader-side offset sampling, material amplification, debug palette interpretation, or non-depth-0 nearby terrain variation.
- The seam probe may still report high deltas at depths `1` and `2`; those pixels are nearby samples, not the exact duplicated edge row, so they can legitimately differ where terrain/contact changes quickly.
