# Symptoms And Initial Suspects

## Observed Symptoms

Many objects that sit on, intersect, or visually overlap the river create unintended distortions in the flow-map result. From a distance the river can look acceptable, but up close these areas show artifacts around rocks, props, and obstacles.

The exact cause is not confirmed yet. Treat this as an object-adjacent artifact problem first, not as proof that all affected objects are intended flow obstacles.

## Initial Suspects

- Decorative objects may be included in collision or terrain-contact sampling when they should be ignored.
- Object collision layers may not clearly separate visual props from water-affecting geometry.
- Terrain-contact or obstacle-feature masks may classify too much geometry as water-relevant.
- Objects may pollute the bake through vertical ray hits even when only an upper or decorative part of the object intersects the sample.
- Shader gates may over-amplify weak or noisy object-adjacent feature masks.
- Flow, foam, pillow, wake, or bank-response data may be valid at distance but too noisy or over-detailed for close-up inspection.
- Overhangs, wide rock tops, and oddly shaped props may be interpreted as flow blockers even when their wetted footprint is small or absent.

## Diagnostic Frame

Object artifacts should be investigated as a classification and bake-contamination problem. The key question is whether each object is being classified with the correct water role: ignored, visual-only, shallow/submerged, hard obstacle, or bank protrusion.

## Early Priority

Compare raw debug views around affected objects before tuning the visible shader. Useful views include terrain contact, protrusion/intersection, bank response, obstacle features, pillow masks, wake masks, final flow strength, and effective flow direction.
