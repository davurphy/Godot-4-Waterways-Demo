# Research: <Feature Name>

## Purpose

Describe why this research is needed and what decision it should unlock for Waterways.
Use `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index for river behavior, hydrology, flow maps, shader-water references, and production examples. Update that file when new external sources inform this feature.

## Current Research Outcome

Keep this short once research has produced a direction.

- Status: <Needed / In progress / Complete / Superseded>
- Recommendation:
- Confidence:
- Biggest unknown that remains:
- Decision or plan section this research unlocked:

## Questions

- What are we trying to learn?
- What assumptions need verification?
- What user or agent premise might be wrong, incomplete, or based on missing scene/data context?
- What Godot 4.6+ constraints could change the design?
- Which parts are editor-only, runtime-only, or shared?
- What legacy Waterways behavior should be preserved, changed, or removed?

## Flow-Map and Water Tool Patterns

Summarize how comparable engines, add-ons, tools, papers, or production examples approach this problem.
Prefer principles and tradeoffs over copying implementation details.

Consider:

- flow-map channel packing
- spline/curve authoring
- foam and shore masks
- distance/height/alpha map generation
- debug visualization
- runtime sampling of baked data
- generated texture/resource storage

## Godot 4.6+ Findings

Record relevant Godot 4.6+ assumptions, APIs, limitations, rendering behavior, import behavior, editor/runtime differences, and community practices.

Check as relevant:

- EditorPlugin APIs
- EditorNode3DGizmoPlugin APIs
- SubViewport rendering and GPU readback
- ShaderMaterial and shader uniform APIs
- screen/depth texture shader syntax
- Forward+, Mobile, and Compatibility renderer differences
- Texture2D/Image/ImageTexture APIs
- PhysicsDirectSpaceState3D and ray query APIs
- Jolt versus Godot Physics behavior
- scene serialization and resource ownership

## Legacy Waterways Reference

Use this section when the feature needs to preserve or intentionally change behavior from the Godot 3 add-on.

- Relevant legacy files:
- Behavior to preserve:
- Behavior to change:
- Obsolete APIs to avoid:
- Risks discovered in `audit/code-audit.md`:
- What belongs in active Godot 4.6+ code:
- What should remain legacy-only:

## Options

### Option A: <Name>

- Benefits:
- Costs:
- Risks:
- Fit for Waterways:

### Option B: <Name>

- Benefits:
- Costs:
- Risks:
- Fit for Waterways:

## Recommendation

State the preferred direction and why.

## Risks and Unknowns

- <Risk or unknown>

## Context Challenge Notes

Record any evidence that the reported issue may be expected behavior, stale data, validation-scene setup, user misunderstanding, or an agent assumption error.

- Possible misread context:
- Evidence:
- Confidence:
- Quick check before patching:
- User-facing note or question to raise:

## Sources

- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index for Waterways river behavior, hydrology, flow-map, shader-water, and production-reference sources.
- <Link or local reference>
