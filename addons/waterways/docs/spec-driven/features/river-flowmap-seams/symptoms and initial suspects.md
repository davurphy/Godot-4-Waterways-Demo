# Symptoms And Initial Suspects

## Observed Symptoms

Visible seams remain along parts of the river surface. The issue appears as discontinuity between river segments or UV2 atlas tiles, where flow, foam, normals, masks, or future displacement-related data do not blend cleanly.

The exact cause is not confirmed yet. Treat this as a visible continuity problem first, not as proof that any single bake pass is broken.

## User-Observed Seam-Positive Debug Views

The user reports visible seams in these debug views:

- Final Flow Strength
- Foam Mix
- Flow Pattern
- Bank Response
- Wake Bank Keep Gate
- Near-Surface Contact (`terrain_contact_features.r`)
- Shallow Depth (`terrain_contact_features.g`)
- Contact Source / Provenance (`terrain_contact_features.a`)
- Bank Friction / Drag, likely `bank_response_features.r` in the current debug menu naming
- Outside-Bend Wet Pressure (`bank_response_features.g`)
- Inside-Bend Deposition (`bank_response_features.b`)

Other debug views may also contain seams, but some palettes are visually uniform enough that seams are hard to confirm by eye.

This evidence pushes the first investigation pass toward baked feature-map continuity, especially `terrain_contact_features` and `bank_response_features`, before treating the problem as only a final material, normal, foam, wake, or pillow amplification issue. Derived views such as Final Flow Strength, Foam Mix, Flow Pattern, and Wake Bank Keep Gate may be revealing discontinuities that already exist in one or more baked inputs.

## Initial Suspects

- UV2 atlas padding may not be wide or consistent enough for all bake and shader samples.
- Cross-tile sampling may be using raw texture offsets instead of a shared river-neighbor lookup.
- Filter passes may bleed, blur, or dilate data differently at segment boundaries.
- Shader sampling near tile edges may read mismatched flow, mask, foam, or bank data.
- Generated source data may disagree across adjacent river segments before filtering.
- Material features such as pillows, foam, wakes, normals, or height displacement may amplify a subtle data seam into a visible artifact.

## Diagnostic Frame

Seams should be investigated as a river-space continuity issue. The key question is whether adjacent river samples represent the same continuous field across segment boundaries, both before and after padding, filtering, packing, and shader interpretation.

## Early Priority

Fixing or at least isolating seam behavior should happen before diagnosing more complex obstacle and rapid behavior, because seams can contaminate every downstream visual feature.

## Investigation Plan

Start by treating the visible seam as evidence, not diagnosis. The first goal is to locate the earliest stage where adjacent river samples stop agreeing.

1. Reproduce and label the visible artifact in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.
   - Compare visible water against debug views for raw flow, effective flow, foam, distance/pressure, terrain contact, bank response, pillow, wake, and eddy-line data.
   - Record whether the seam appears in raw baked channels, derived shader masks, or only in the final material response.
   - Use the user-observed seam-positive views above as the initial inspection set, then check raw neighboring channels whose palettes may hide subtle discontinuities.

2. Audit saved bake textures before shader interpretation.
   - Add a focused probe that loads the saved river bake resources under `waterways_bakes/Demo/`.
   - Sample both sides of every occupied UV2 tile boundary across `flow_foam_noise`, `dist_pressure`, `obstacle_features`, `terrain_contact_features`, and `bank_response_features`.
   - Report per-channel boundary deltas, worst offending tile pairs, and whether the discontinuity is horizontal, vertical, row-wrap, column-wrap, first-tile, last-tile, or unused-tile adjacent.
   - Prioritize `terrain_contact_features.rga` and `bank_response_features.rgb`, since the reported seam-positive debug views directly expose those channels.

3. Separate source-data mismatch from filter or padding mismatch.
   - Compare continuity at raw source image stage, after `WaterHelperMethods.add_margins()`, after each filter pass, and after final packed texture creation.
   - If discontinuity exists before filters, focus on mesh UV2/source generation and collision or terrain sampling.
   - If discontinuity appears after filters, focus on margin fill, filter kernels, and cross-tile sampling.

4. Stress-test atlas padding rules with synthetic data.
   - Build a synthetic UV2 atlas with known continuous per-segment gradients and clear tile IDs.
   - Run it through `add_margins()`, blur, dilate, normal, combine, and any relevant feature filters.
   - Confirm whether local tile edges, row wraps, column wraps, river start/end tiles, or unused atlas cells leak unrelated values.

5. Inspect shader-side neighbor sampling.
   - Review shader paths that sample offsets from the current UV: contextual flow slide, bank-friction edge mask, pillow reach/smoothing/stitching, wake sampling, eddy-line sampling, and foam contributions.
   - Determine whether each offset should sample physical neighboring river space or merely clamped atlas UV space.
   - Mark any path that can cross from one UV2 tile into an unrelated atlas tile without a river-neighbor lookup.

6. Classify the first confirmed failure before fixing.
   - Use these buckets: UV2 mesh mapping, source map generation, margin fill, filter cross-talk, packed texture storage/import, shader remap, shader neighbor lookup, or material amplification.
   - Prefer the smallest probe that falsifies a bucket before making code changes.

7. Choose the fix only after the failure stage is known.
   - If the bake data is discontinuous, fix source generation, margin construction, or filter sampling before touching visual material controls.
   - If the bake data is continuous but the shader output is not, add a shared river-neighbor sampling strategy or constrain specific shader offset samples.
   - If only final material features reveal the seam, tune or gate the amplifying feature after proving the underlying fields are acceptable.

## First Recommended Probe

Create `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd`.

The first version should be read-only and should load existing bake resources, inspect boundary continuity, and print a compact report. It should not rebake, modify scenes, save resources, or change shader behavior. This gives a low-risk answer to the first fork in the diagnosis: whether the seam is already present in saved bake textures or appears later during shader interpretation.

## Probe Result: Saved Bake Boundary Audit

Date: 2026-06-11

Probe:

```text
addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd
```

Run environment:

- Godot 4.6.3 console
- Forward+ renderer
- Profile isolated with repo-local `.codex-research/godot-user`

Result marker:

```text
RIVER_FLOWMAP_SEAM_PROBE_OK
```

The probe loaded the existing saved bakes read-only:

- `res://waterways_bakes/Demo/Water_River.river_bake.res`
- `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`

Key findings:

- Both saved bakes already contain large edge deltas across logical UV2 segment joins.
- The strongest confirmed discontinuities are in `terrain_contact_features`, which is an early generated source map, not only a final material or downstream shader effect.
- Main demo bake:
  - `terrain_contact_features.r` logical same-column edge max delta: `1.0`, average about `0.14001`.
  - `terrain_contact_features.g` logical same-column edge max delta: `1.0`, average about `0.16563`.
  - `terrain_contact_features.a` logical same-column edge max delta: `1.0`, average about `0.91753`.
  - `bank_response_features.r` logical same-column edge max delta: `1.0`, average about `0.18915`.
  - `bank_response_features.g` logical same-column edge max delta: about `0.62353`.
  - `bank_response_features.b` logical same-column edge max delta: about `0.92941`.
- Obstacle-test bake:
  - `terrain_contact_features.r` logical same-column edge max delta: `1.0`, average about `0.13782`.
  - `terrain_contact_features.g` logical same-column edge max delta: `1.0`, average about `0.17956`.
  - `terrain_contact_features.a` logical same-column edge max delta: `1.0`, average about `0.90444`.
  - `bank_response_features.r` logical same-column edge max delta: `1.0`, average about `0.19174`.
  - `bank_response_features.g` logical same-column edge max delta: about `0.66667`.
  - `bank_response_features.b` logical same-column edge max delta: about `0.94510`.

Interpretation:

- This confirms the seam is present in saved bake data before final material interpretation.
- Because `terrain_contact_features` is generated directly from UV2-to-world terrain/contact sampling and then passed through `add_margins()`, the next investigation should focus on terrain-contact source generation and UV2 world sampling before tuning final flow, foam, wake, normal, or material responses.
- `bank_response_features` is likely inheriting and amplifying discontinuities from `terrain_contact_features`, because bank response is derived from terrain contact, grade, bend, and flow context.

Next recommended diagnostic:

- Add a second read-only probe that loads the demo scene, uses the generated river mesh, and compares `_get_uv2_world_sample()` results on both sides of the worst saved-bake segment joins.
- For each checked join, report whether the two UV2 edge pixels map to the same or meaningfully different world positions, and whether the terrain/contact sampler then chooses different terrain sources or heights.
- If world positions disagree, investigate UV2 mesh mapping or pixel-center atlas sampling.
- If world positions agree but contact results disagree, investigate hterrain/physics source selection, raycast sampling, or terrain-contact thresholds at duplicated segment edges.

## Probe Result: UV2 World Sample Boundary Audit

Date: 2026-06-11

Probe:

```text
addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_world_sample_probe.gd
```

Initial result before the fix:

- The probe loaded `Demo.tscn` and `Demo_obstacle_flow_test.tscn`, found the matching river nodes, and inspected the worst saved-bake segment joins.
- For the first hard seam from step `0` to step `1`, the `from` pixel mapped to a world position but the `to` pixel returned an empty UV2 world sample.
- This explained why the saved terrain-contact texels on the first row of the next segment were blank even though the previous segment edge had valid contact data.

Root cause identified:

- `_get_uv2_world_sample()` classified the source pixel's UV2 tile using `floor(pixel / (resolution / side))`.
- The atlas and mesh UV2 generation use floored integer tile partitions instead.
- With a `256` source texture split into `5` UV2 sides, pixel row `51` belongs to tile row `1` in the atlas, but the old classifier treated it as tile row `0`. The barycentric lookup then searched the wrong segment triangles, failed, and left the texel blank.

Fix applied:

- `WaterHelperMethods._get_uv2_world_sample()` now uses the same floor-partition tile classification as the UV2 atlas rect logic.
- `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` was bumped from `20` to `21`.
- The source signature now records `uv2_world_sample_tile_classifier = floor_partition_match_tile_rect`.

Validation after the fix:

- The same probe passed with `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`.
- The formerly empty `to` samples now map to the same world positions as the corresponding `from` samples at the duplicated segment edge.
- Computed terrain-contact values match across the checked joins with zero computed delta.
- The saved bake textures still contain the old discontinuities until the affected river bakes are regenerated.

Next required step:

- Rebuild the affected river bakes with signature `21`, then rerun `river_flowmap_seam_probe.gd`.
- Expected result after rebake: saved `terrain_contact_features` edge deltas at the previously blank segment rows should collapse toward zero or normal terrain-gradient variation, and derived `bank_response_features` seams should reduce accordingly.

## Probe Result: Post-Fix Rebake Validation

Date: 2026-06-11

Rebake helper:

```text
addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_rebake_demo_bakes.gd
```

Result marker:

```text
RIVER_FLOWMAP_SEAM_REBAKE_OK
```

The helper rebuilt and saved only the two affected river bake resources:

- `res://waterways_bakes/Demo/Water_River.river_bake.res`
- `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`

Both bakes now report bake signature `21` and include `uv2_world_sample_tile_classifier = floor_partition_match_tile_rect` in their source signature.

Follow-up boundary audit:

```text
addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd
```

Result marker:

```text
RIVER_FLOWMAP_SEAM_PROBE_OK
```

Confirmed fixed after rebake:

- `terrain_contact_features.r`, near-surface contact: logical segment-edge max delta `0.0`, average delta `0.0`.
- `terrain_contact_features.g`, shallow depth: logical segment-edge max delta `0.0`, average delta `0.0`.
- `terrain_contact_features.b`: logical segment-edge max delta `0.0`, average delta `0.0`.
- `terrain_contact_features.a`, contact source/provenance: logical segment-edge max delta `0.0`, average delta `0.0`.
- The same zero-delta result holds for both same-column step joins and row-wrap step joins in both demo bakes.

Remaining seam-positive channels after rebake:

- `dist_pressure.b`, grade/energy, still has meaningful segment-edge deltas.
  - Main demo same-column max delta about `0.27451`; row-wrap max delta about `0.14902`.
  - Obstacle-test same-column max delta about `0.24706`; row-wrap max delta about `0.11373`.
- `dist_pressure.a`, bend bias, still has meaningful segment-edge deltas.
  - Main demo same-column max delta about `0.32941`; row-wrap max delta about `0.09020`.
  - Obstacle-test same-column max delta about `0.32549`; row-wrap max delta about `0.27451`.
- `bank_response_features.r`, bank friction/drag, is much smaller than before in the main demo but still non-zero.
  - Main demo max deltas are about `0.08627` same-column and `0.09412` row-wrap.
  - Obstacle-test max deltas are about `0.15294` same-column and `0.05490` row-wrap.
- `bank_response_features.g`, outside-bend wet pressure, still has large isolated segment-edge deltas.
  - Main demo max deltas are about `0.53333` same-column and `0.16863` row-wrap.
  - Obstacle-test max deltas are about `0.60392` same-column and `0.45490` row-wrap.
- `bank_response_features.b`, inside-bend deposition, still has large isolated segment-edge deltas.
  - Main demo max deltas are about `0.67451` same-column and `0.25098` row-wrap.
  - Obstacle-test max deltas are about `0.74902` same-column and `0.60392` row-wrap.
- `bank_response_features.a` also remains discontinuous in isolated spots.
  - Main demo max deltas are about `0.33725` same-column and `0.24314` row-wrap.
  - Obstacle-test max deltas are about `0.51765` same-column and `0.13333` row-wrap.

Interpretation:

- The original hard seam in `terrain_contact_features` was caused by UV2 world-sample tile misclassification and is fixed after rebaking.
- At the signature `21` stage, remaining bank-response debug seams were no longer explained by blank terrain-contact rows. They pointed at grade/bend continuity feeding bank response, especially `dist_pressure.b` and `dist_pressure.a`.
- The next investigation slice inspected `_create_curve_grade_energy_source_image()`, `_create_curve_bend_bias_source_image()`, and filtered feature-map outputs to determine whether grade, bend, and filter-derived channels should agree across duplicated segment edges.

## Probe Result: Signature 23 Edge Continuity Validation

Date: 2026-06-11

Additional fixes applied:

- `dist_pressure.b`, grade/energy, now uses vertex-aligned longitudinal interpolation across UV2 tiles.
- `dist_pressure.a`, bend bias, now uses vertex-aligned longitudinal interpolation across UV2 tiles and vertex-aligned lateral ratio across the river width.
- Final derived feature maps now synchronize only the exact duplicated logical edge row after filter readback:
  - `flow_foam_noise`
  - `dist_pressure`
  - `obstacle_features`
  - `bank_response_features`
- `terrain_contact_features` is not post-filter synchronized; it remains source-sampled from UV2-to-world terrain/contact data.
- `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` was bumped to `23`.

Validation commands:

```text
addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_rebake_demo_bakes.gd
addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd
```

Result markers:

```text
RIVER_FLOWMAP_SEAM_REBAKE_OK
RIVER_FLOWMAP_SEAM_PROBE_OK
```

Both saved bakes now report bake signature `23`:

- `res://waterways_bakes/Demo/Water_River.river_bake.res`
- `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`

Confirmed at the actual duplicated segment edge, depth `0`:

- `flow_foam_noise.rgba`: same-column and row-wrap max delta `0.0`.
- `dist_pressure.b`: same-column and row-wrap max delta `0.0`.
- `dist_pressure.a`: same-column and row-wrap max delta `0.0`.
- `obstacle_features.rgba`: same-column and row-wrap max delta `0.0`.
- `terrain_contact_features.rgba`: same-column and row-wrap max delta `0.0`.
- `bank_response_features.rgba`: same-column and row-wrap max delta `0.0`.

Interpretation:

- The originally reported seam-positive channels now agree exactly at logical UV2 segment joins in the saved bake data.
- This covers the reported raw/debug inputs for near-surface contact, shallow depth, contact source/provenance, grade/bend-driven bank response, obstacle/wake features, foam support, and packed flow/foam/noise data.
- The probe still reports large deltas at depths `1` and `2` for some terrain-contact samples. Those rows are not duplicated world positions; they are nearby river samples on opposite sides of the join, so they can legitimately differ where terrain or contact changes quickly.
- The next check should be a human-visible editor/runtime pass against signature `23` bakes. If a visible seam remains, it is now more likely to be shader-side offset sampling, material amplification, or debug palette interpretation rather than a depth-0 saved-bake discontinuity.
