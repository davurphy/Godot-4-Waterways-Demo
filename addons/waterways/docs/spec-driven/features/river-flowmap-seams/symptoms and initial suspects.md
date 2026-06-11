# Symptoms And Initial Suspects

## Observed Symptoms

Visible seams remain along parts of the river surface. The issue appears as discontinuity between river segments or UV2 atlas tiles, where flow, foam, normals, masks, or future displacement-related data do not blend cleanly.

The exact cause is not confirmed yet. Treat this as a visible continuity problem first, not as proof that any single bake pass is broken.

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
