# Research: River Ripples

## Purpose

This research records the design evidence needed to turn the runtime ripple roadmap into a safe Waterways feature. It should unlock decisions about no-readback feedback rendering, coordinate mapping, river boundary masking, material ownership, debug parity, and whether ripple nodes become public add-on types.

Use `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index for river behavior, hydrology, flow maps, shader-water references, and production examples. Update that file when new external sources inform this feature.

## Current Research Outcome

Keep this short once research has produced a direction.

- Status: In progress.
- Recommendation: Start with a standalone visual-only GPU feedback spike, then prove `world_to_ripple_uv` mapping and mesh-footprint boundary masking before touching visible river materials.
- Confidence: Medium-high for the architecture; medium for Godot-specific viewport feedback details until a local spike proves timing, precision, and pause/reload behavior.
- Biggest unknown that remains: The exact Godot 4.6+ feedback implementation that satisfies no readback, no same-texture read/write, precision, update timing, and renderer compatibility.
- Decision or plan section this research unlocked: `plan.md` "Architecture Summary", "Runtime Flow", and "Risks".

## Questions

- What are we trying to learn?
  - Whether Waterways can run a transient ripple feedback simulation as a runtime visual overlay without disturbing baked flow architecture.
- What assumptions need verification?
  - Godot viewport feedback can run safely with ping-pong targets.
  - Texture precision is sufficient at practical resolutions.
  - River shader world positions can be mapped into ripple field UVs consistently.
  - Mesh-footprint boundary masking can be generated in the same coordinate space.
  - Runtime material uniforms can be applied and restored without cross-talk.
- What user or agent premise might be wrong, incomplete, or based on missing scene/data context?
  - Treating visible ripple rings as flow or buoyancy behavior.
  - Treating a rectangular debug field as proof of river-ready masking.
  - Treating existing bake UV2 atlas textures as direct world-space masks.
- What Godot 4.6+ constraints could change the design?
  - `SubViewport` update mode, clear mode, texture precision, texture feedback hazards, shader uniform support, and renderer-specific behavior.
- Which parts are editor-only, runtime-only, or shared?
  - Runtime-only: simulation, impulse rendering, texture feedback, emitter impulses, target uniforms.
  - Editor-only: custom type icons, editor preview, validation UI.
  - Shared: saved field configuration if nodes become public scene nodes.
- What legacy Waterways behavior should be preserved, changed, or removed?
  - Preserve baked flow and WaterSystem behavior.
  - Do not preserve or rely on legacy Godot 3 APIs.

## Flow-Map and Water Tool Patterns

Comparable water systems often layer small surface detail over stable authored flow:

- Baked flow maps provide direction and broad motion.
- Runtime disturbance textures provide transient local detail.
- Normal and refraction modulation can create convincing interaction without changing physics.
- Boundary masks are required when a simulation domain is rectangular but the water body is not.
- Runtime systems need explicit ownership of transient textures and material parameters.

Waterways fit:

- Existing river shaders already combine baked flow, animated normals, foam, pillows, wakes, and eddy-line turbulence.
- Runtime ripples should join this as another surface detail layer, not as a new source of final flow.
- The project already has shader-pass infrastructure through `SubViewport`, but the current renderers are bake-oriented and use CPU readback, so they are only partial evidence.

## Godot 4.6+ Findings

Record relevant Godot 4.6+ assumptions, APIs, limitations, rendering behavior, import behavior, editor/runtime differences, and community practices here as implementation research proceeds.

Current local findings from the roadmap:

- `filter_renderer.gd` and `system_map_renderer.gd` prove shader passes through `SubViewport` are available.
- Existing bake paths use `SubViewport.UPDATE_ONCE`, wait frames, call `get_image()`, and store textures.
- Runtime ripple simulation needs a different path: no CPU readback during normal runtime and no sampling from the active write target.

Items still needing verification:

- Best ping-pong arrangement with separate render targets.
- Clear mode and update mode behavior.
- Precision/color format options for decaying wave height.
- Pause/resume behavior.
- Scene reload behavior.
- Forward+, Mobile, and Compatibility renderer differences.
- Whether instance shader parameters support the required texture and uniform types if considered for material ownership.

## Legacy Waterways Reference

Use this section when the feature needs to preserve or intentionally change behavior from the Godot 3 add-on.

- Relevant legacy files: None identified for first-pass ripples.
- Behavior to preserve:
  - The active Godot 4.6+ add-on's baked river architecture and existing accepted visual baselines.
- Behavior to change:
  - Add optional runtime visual surface detail.
- Obsolete APIs to avoid:
  - Any Godot 3-only viewport, material, or plugin APIs.
- Risks discovered in `audit/code-audit.md`:
  - Not checked yet for ripple-specific implementation.
- What belongs in active Godot 4.6+ code:
  - Runtime-safe field, emitter, shader, RiverManager adapter, and debug support.
- What should remain legacy-only:
  - Any obsolete Godot 3 editor/runtime patterns.

## Options

### Option A: Runtime Visual Ripple Overlay

- Benefits:
  - Fits Waterways' separation between baked flow and surface detail.
  - Avoids source-signature and WaterSystem churn.
  - Can be prototyped in risk order.
  - Keeps first milestone useful for demos and user projects.
- Costs:
  - Requires new runtime feedback infrastructure.
  - Requires careful material ownership and cleanup.
  - Requires debug parity beyond ordinary shader output.
- Risks:
  - Viewport feedback may expose Godot-specific timing or precision issues.
  - Shader cost may be too high if integration is careless.
- Fit for Waterways:
  - Best first path.

### Option B: Bake Ripple Data Into River Resources

- Benefits:
  - Saved resources would be deterministic and inspectable.
  - Existing bake infrastructure could store outputs.
- Costs:
  - Does not satisfy runtime emitter interaction.
  - Blurs transient visual state with authored river data.
  - Requires source signatures and stale-resource handling.
- Risks:
  - Could corrupt the add-on's clean separation of baked flow and runtime visual detail.
- Fit for Waterways:
  - Not appropriate for the first ripple milestone.

### Option C: Physics-Facing Ripple Simulation

- Benefits:
  - Visible rings and object behavior could eventually agree.
  - Could support advanced gameplay and buoyancy effects.
- Costs:
  - Requires runtime sampling semantics, WaterSystem alignment, determinism decisions, and validation with moving objects.
  - Much larger scope.
- Risks:
  - Visible water and physics can diverge if planned casually.
  - Saved bakes and transient state can become confusing.
- Fit for Waterways:
  - Future work only after visual layer is accepted.

## Recommendation

Use Option A first. Build a standalone no-readback runtime visual ripple field, prove coordinate mapping and mesh-footprint boundary masking, then add a minimal river shader normal overlay through a controlled runtime material API.

Do not implement physics-facing behavior, flow changes, or saved ripple data until the visual layer has been accepted and a separate milestone defines how visible state, runtime sampling, WaterSystem data, and validation should agree.

## Risks and Unknowns

- Godot viewport feedback timing may differ between editor, F6, and exported builds.
- Texture precision may be too low for stable decay if ordinary color formats are used.
- Mapping bugs can be subtle unless world-space markers and debug texture markers are compared directly.
- Boundary masks can look correct in one view while still letting waves leak across dry areas.
- Material ownership bugs can affect unrelated rivers.
- Debug material switching can hide runtime ripple uniforms.
- Shader sample cost can regress an already complex river material.
- Public node registration can imply API stability before the design is proven.

## Context Challenge Notes

Record any evidence that the reported issue may be expected behavior, stale data, validation-scene setup, user misunderstanding, or an agent assumption error.

- Possible misread context:
  - User or agent expects visual ripples to move objects or alter downstream current.
- Evidence:
  - The roadmap explicitly scopes first-pass ripples as visual-only and transient.
- Confidence:
  - High.
- Quick check before patching:
  - Ask whether the requested behavior is surface appearance only or physics-facing object behavior.
- User-facing note or question to raise:
  - "This first ripple feature is visual-only; object drift or buoyancy changes need a separate physics-facing plan so visible and runtime behavior do not diverge."

## Sources

- `addons/waterways/docs/roadmaps/runtime-ripple-simulation-roadmap.md`: primary roadmap for this feature folder.
- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index for Waterways river behavior, hydrology, flow-map, shader-water, and production-reference sources.
- `addons/waterways/docs/spec-driven/00-constitution.md`: project-level development constraints.
- `addons/waterways/docs/spec-driven/01-workflow.md`: feature-folder workflow and handoff naming convention.
- `https://github.com/CBerry22/Godot-Water-Ripple-Simulation-Shader`: algorithmic inspiration named by the roadmap; do not copy code unless licensing is clarified.
