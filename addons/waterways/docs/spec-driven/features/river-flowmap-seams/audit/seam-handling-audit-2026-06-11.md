# Seam Handling Audit - 2026-06-11

## Scope

This audit covers how seams are handled in the Waterways add-on for River UV2 atlas bakes, shader consumption, pillow seam controls, and related diagnostics. It focuses on the current `river-flowmap-seams` state after the signature `23` seam continuity pass.

## Summary

The current bake-side seam handling is in good shape for the two demo river bakes. Both saved river bakes report signature `23`, and the existing Godot probes confirm zero delta at the exact duplicated logical UV2 segment edge for all prioritized seam-positive channels.

The highest remaining risk is shader-side offset sampling. Several shader helpers sample nearby atlas texels using clamped UVs rather than a dedicated logical river-neighbor lookup. That is acceptable for small offsets and clean edge rows, but it can still reveal nearby-row variation, non-logical atlas neighbors, or material amplification if a visible seam remains.

## Verified Probe Results

Ran with Godot `4.6.3` console executable and repo-local Godot user data:

```text
RIVER_FLOWMAP_SEAM_PROBE_OK
RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK
```

The seam probe verified:

- `res://waterways_bakes/Demo/Water_River.river_bake.res`
  - texture size `(358, 358)`
  - content rect `[P: (51, 51), S: (256, 256)]`
  - `uv2_sides = 5`
  - `occupied_steps = 17`
  - `signature_version = 23`
- `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
  - texture size `(358, 358)`
  - content rect `[P: (51, 51), S: (256, 256)]`
  - `uv2_sides = 5`
  - `occupied_steps = 18`
  - `signature_version = 23`

For both bakes, all priority channels reported `avg_delta = 0.0` and `max_delta = 0.0` at logical edge depth `0` for same-column joins and row-wrap joins:

- `flow_foam_noise.rgba`
- `dist_pressure.b`
- `dist_pressure.a`
- `obstacle_features.rgba`
- `terrain_contact_features.rgba`
- `bank_response_features.rgba`

The world-sample probe confirmed that duplicated segment-edge pixels resolve to the same world position, same terrain/contact result, same saved terrain delta, and same bank-response values in both demo scenes.

## Current Seam Model

River steps are packed into a padded UV2 atlas. Each step occupies a logical tile in a column-major layout:

- step row: `step_index % uv2_sides`
- step column: `step_index / uv2_sides`

The mesh UV2 generation and bake world-sampling now both use floored integer tile partitions. This matters because a previous mismatch around pixel-center classification could assign edge pixels to the wrong tile, causing blank or mismatched terrain-contact samples at duplicated segment edges.

Shader-facing textures keep a one-tile margin around the source content. Runtime shaders remap mesh `UV2` into the padded content rect with:

```glsl
vec2 source_size = max(round(atlas_size * safe_uv2_sides / (safe_uv2_sides + 2.0)), vec2(1.0));
vec2 margin = round((atlas_size - source_size) * 0.5);
vec2 custom_UV = (UV2 * source_size + margin) / atlas_size;
```

This pattern appears in the visible river shader, debug river shader, lava shader, and WaterSystem flow render shader.

## Bake-Side Handling

The bake pipeline currently addresses seams in three main places:

1. UV2 world-sample classification uses atlas-matching floor partitions.
2. Grade and bend maps are generated with vertex-aligned interpolation across each tile length.
3. Derived feature maps are synchronized at the exact duplicated logical edge row after filter readback.

The late synchronization pass is applied to:

- `flow_foam_noise`
- `dist_pressure`
- `obstacle_features`
- `bank_response_features`

It is intentionally not applied to `terrain_contact_features`; that map remains source-sampled from corrected UV2-to-world terrain/contact data. The probes confirm this is currently sufficient at depth `0` for the demo bakes.

Depth `1` and depth `2` probe deltas still appear in the reports. These are nearby rows on opposite sides of a join, not the duplicated logical edge row. They can legitimately differ where terrain or contact changes quickly.

## Shader-Side Handling

The shader-side story is mixed: base sampling is seam-aware through padded UV2 remapping, but offset sampling mostly uses atlas-space UV offsets and clamping.

Important offset-sampling paths:

- `boundary_context_at()` and `boundary_gradient_at()`
- `apply_contextual_flow_slide()`
- `bank_friction_edge_mask()`
- pillow reach, contact pull, smoothing, and seam stitching helpers
- wake edge and eddy-line context helpers
- ripple simulation and visible ripple normal sampling

These paths generally use small offsets expressed as atlas texels or source-tile units. The one-tile margin and depth-0 synchronization protect the exact seam, but they do not provide a generalized logical neighbor lookup for arbitrary offsets across UV2 tile boundaries.

If a visible seam remains after the signature `23` bake pass, shader-side offset sampling, material amplification, debug palette interpretation, or nearby-row terrain variation are now more likely causes than saved-bake discontinuity.

## Pillow Seam Controls

Pillow seam controls are correctly treated as visual artifact controls, not root data fixes:

- `pillow_height_seam_stitch_tiles`
- `pillow_height_tile_seam_fade`
- `pillow_material_tile_seam_fade`

Current defaults keep both seam fades at `0.0`. This matches the documented finding that nonzero material seam fade can draw visible straight bands, and that height seam fade can suppress valid obstruction height through the middle of one logical pillow.

The safer policy is:

- keep material seam fade at `0.0` unless a seam-specific review intentionally enables it
- keep height seam fade at `0.0` by default
- use height seam stitch and height smoothing carefully, especially while mesh divisions are capped
- treat janky or angular height response as a mesh density/topology issue before masking it with seam fades

## Risks

- Shader offset sampling can cross from one UV2 tile into a non-logical atlas neighbor for larger offsets or certain directions.
- The exact edge row is verified, but nearby rows can still differ sharply in terrain-contact channels.
- Material features such as foam, bank edge masks, pillows, wakes, eddy lines, normals, and height displacement can amplify small data variation into visible bands.
- Debug views can make a legitimate nearby-row transition look like a seam, especially with high-contrast palettes.
- WaterSystem consumes river bake metadata, but its own system map should be regenerated after river bake changes when stale.
- Human-visible editor/runtime review remains necessary; probes prove data continuity at specific sample rows, not final perceptual acceptance.

## Recommendations

1. Run a human-visible editor/runtime review against the signature `23` bakes.
2. If a seam is still visible, capture which debug views show it and whether it aligns with exact logical edge rows, nearby rows, or non-logical atlas column edges.
3. Add a shader-side diagnostic if needed that visualizes offset-sampled neighbors for contextual flow slide, bank-friction edge mask, pillow smoothing, wake edge, and eddy-line context.
4. Avoid enabling `pillow_material_tile_seam_fade` or `pillow_height_tile_seam_fade` as a default fix; use them only as targeted review controls.
5. If offset sampling is confirmed as the remaining problem, design a shared logical river-neighbor sampling helper rather than adding one-off clamps in each material feature.

## Files Reviewed

- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/resources/river_bake_data.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/system_renders/system_flow.gdshader`
- `addons/waterways/shaders/lava.gdshader`
- `addons/waterways/shaders/runtime/ripple_simulation.gdshader`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/changelog.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/symptoms and initial suspects.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_world_sample_probe.gd`
