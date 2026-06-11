# Plan to Improve Waterways Seam Handling

Date: 2026-06-11

## Purpose

This plan summarizes findings from the current river-flowmap seam audit, the signature 23 changelog, the local Waterways implementation, and the external flowmap/water-rendering references collected in `Seamless River Flowmap Techniques.md`.

The goal is to improve seam accuracy, runtime performance, and visual quality without replacing Waterways' current per-river bake workflow.

## Current Architecture Summary

Waterways currently renders each River from a generated mesh and a local padded UV2 atlas. The bake textures use a one-tile margin around the source atlas, and the visible river shaders remap mesh `UV2` into that padded content area.

The signature 23 pass fixed the most important bake-side discontinuity:

- UV2 world sampling now uses the same floor-partitioned tile classification as mesh UV2 generation.
- Grade and bend features are generated with vertex-aligned interpolation.
- Filter-derived feature maps are synchronized at the exact duplicated logical segment edge.
- The two demo river bakes now report zero delta at depth `0` for the prioritized seam-positive channels.

The remaining risk is runtime offset sampling. Base texture sampling is seam-aware through padded UV2 remapping, but shader helpers often offset the padded atlas UV directly and clamp the result. That can sample a non-logical atlas neighbor or nearby row data when a logical river-neighbor sample was intended.

## Main Finding

The current bake-side model is a good foundation. The highest-value next improvement is not a full global-water rewrite. It is a shared logical UV2-neighbor sampling model for runtime shader offsets, followed by selective prebaking of expensive context masks.

This aligns with the cited sources:

- Valve's flowmap work supports Waterways' existing dual-phase flow animation with phase noise.
- Commercial river tools emphasize strict UV layout, mesh tangent/normal consistency, and positive downstream river flow.
- Unreal and Crest show why global water buffers are powerful for multi-body blending, but Waterways already has a separate WaterSystem path for world-space flow/height/alpha data.
- Horizon's water work is most relevant as a reminder that baked compensation maps are valuable when runtime deformation or sampling becomes too expensive or unstable.

## Goals

1. Preserve the existing River authoring and bake workflow.
2. Keep signature 23's exact-edge bake continuity guarantees.
3. Make runtime shader offset samples cross UV2 segment boundaries logically.
4. Reduce material-side amplification of small discontinuities.
5. Keep expensive multi-sample contextual features out of the fragment shader when they can be baked.
6. Leave WaterSystem/global-map changes as a separate longer-term track.

## Non-Goals

- Do not replace per-river rendering with a global Unreal-style WaterMesh architecture for this seam fix.
- Do not use pillow seam fades as a default data fix.
- Do not move high-frequency contact, obstacle, or bank data into vertex colors only.
- Do not change runtime ripples into authoritative flow or WaterSystem data as part of this work.

## Recommended Architecture Changes

### 1. Add River Occupancy Metadata To Shaders

Runtime shader logic currently receives `i_uv2_sides`, but a logical-neighbor helper also needs the number of occupied river steps.

Add:

```glsl
uniform int i_occupied_steps = 0;
```

Set it from `RiverManager` using `_steps` whenever `i_uv2_sides` is assigned. For legacy or custom materials, default behavior should treat `i_occupied_steps <= 0` as `i_uv2_sides * i_uv2_sides`.

Apply the same concept to:

- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/system_renders/system_flow.gdshader`

### 2. Add A Logical UV2 Atlas Helper

Create a shader helper that treats the UV2 atlas as a linear river-step sequence packed into columns:

- `row = step % uv2_sides`
- `column = step / uv2_sides`

The helper should:

1. Convert padded atlas UV into source-atlas tile coordinates.
2. Identify the current logical step.
3. Apply offsets in tile-local units.
4. Clamp lateral offsets within the same tile, because lateral X is river width, not next river segment.
5. Wrap longitudinal offsets across logical step boundaries:
   - `local_y < 0.0` samples `step - 1`
   - `local_y >= 1.0` samples `step + 1`
6. Recompute the target tile from the target step.
7. Clamp start/end samples to the first or last occupied step.
8. Convert back to padded atlas UV.

Suggested helper shape:

```glsl
vec2 river_logical_offset_uv(
	vec2 atlas_uv,
	vec2 offset_tiles,
	vec2 atlas_size,
	vec2 source_size,
	vec2 margin,
	float safe_uv2_sides,
	int occupied_steps
) {
	// Convert, offset, step-wrap, clamp, and return padded atlas UV.
}
```

Then add sampler wrappers:

```glsl
vec4 sample_river_logical(sampler2D tex, vec2 atlas_uv, vec2 offset_tiles);
float sample_river_logical_channel(sampler2D tex, vec2 atlas_uv, vec2 offset_tiles, int channel);
```

The implementation can be duplicated across the visible river, debug river, and WaterSystem flow render shader until a safe shader-include strategy exists.

### 3. Migrate High-Risk Runtime Offset Paths

Use the logical helper first in the shader paths most likely to expose seams:

- `boundary_context_at()` and `boundary_gradient_at()`
- `apply_contextual_flow_slide()`
- `bank_friction_edge_mask()`
- pillow contact search, forward reach, smoothing, and height stitch helpers
- wake edge and eddy-line context helpers
- `system_flow.gdshader` flow-slide sampling

Base sampling at `custom_UV` can remain unchanged. The helper is mainly for samples that move away from the current texel.

### 4. Add Offset-Sampling Diagnostics

Add a debug view that visualizes offset sampling state:

- same logical tile
- previous or next logical river step
- clamped first or last step
- non-logical atlas neighbor fallback
- out-of-occupied-range sample

Add a probe that uses the shader source or a small CPU mirror to validate representative offsets at:

- same-column joins
- row-wrap joins
- first and last occupied step edges
- non-logical atlas column edges

The existing seam probes prove saved data continuity at exact edge depth `0`; this new diagnostic should prove that runtime offset samples intend the correct logical neighbor.

### 5. Prebake More Context Where It Pays Off

The visible shader currently performs many repeated feature-map samples for pillows, wakes, eddy lines, bank friction edges, and contextual flow slide.

After the logical sampler exists, review which derived masks should move into bake outputs. Candidates:

- bank friction edge support
- wake edge support
- eddy context support
- pillow smoothed height support
- seam-aware hard-boundary gradient support

These should be stored as context/support fields, not final material decisions, so existing artist-facing material strengths can remain adjustable.

Benefits:

- fewer fragment shader texture reads
- fewer runtime seam opportunities
- more stable visual output across debug and final materials
- easier probes because baked masks can be audited like the existing channels

Any new bake output or channel semantic change should bump the river source signature.

### 6. Keep Vertex Data For Low-Frequency Facts

Vertex colors or extra vertex attributes are useful for low-frequency river facts:

- longitudinal direction
- grade/energy
- bend direction
- end fade
- broad tributary/lake transition weight

They should not replace high-frequency contact, obstruction, bank-response, foam, wake, or pillow fields unless mesh density is explicitly high enough. Horizon's notes call out that vertex-carried foam and similar details can undersample when triangle density is insufficient.

### 7. Treat WaterSystem As A Longer-Term Global Track

Waterways already has a global WaterSystem map path for world-space flow, height, and alpha. That is the right direction for:

- multiple rivers merging
- rivers entering lakes
- buoyancy and gameplay sampling
- world-space wet/shoreline consumers
- future transition masks

For the current seam problem, WaterSystem should not replace per-river rendering. Instead:

1. Regenerate WaterSystem maps after river bake changes.
2. Add diagnostics for stale WaterSystem data.
3. Later, consider using WaterSystem-derived transition masks for multi-river or river-to-lake seams.

## Performance Guidance

Logical sampling adds math. Use it where it removes real risk:

- high-risk offset samples near UV2 tile boundaries
- contextual feature sampling that affects flow direction, foam, height, or normals
- WaterSystem flow rendering where river flow is projected into global maps

Avoid using it for every base texture fetch. Base `custom_UV` samples are already protected by the padded atlas and signature 23 bake continuity.

Prebaking repeated context masks should recover more performance than the logical helper costs, especially in the visible river shader where pillow, wake, eddy, and bank effects currently perform many dependent texture samples.

## Visual Quality Guidance

Keep these defaults:

- `pillow_height_tile_seam_fade = 0.0`
- `pillow_material_tile_seam_fade = 0.0`

Those controls are useful review tools, but they can introduce straight visual bands or suppress valid obstruction height. Prefer data correctness and logical sampling first.

Also keep the human-visible review step. Probes can prove exact data continuity and sample routing, but they cannot fully prove final perceptual quality under lighting, normals, foam, refraction, and debug palettes.

## Suggested Implementation Order

1. Add `i_occupied_steps` plumbing and default fallback behavior.
2. Add the logical UV2 helper to `river.gdshader`.
3. Port the helper to `river_debug.gdshader` and `system_flow.gdshader`.
4. Migrate `boundary_context_at()` and `apply_contextual_flow_slide()`.
5. Add the debug view for logical sample routing.
6. Migrate bank, pillow, wake, and eddy offset helpers.
7. Add or update probes for seam-offset routing.
8. Run parser checks, `git diff --check`, seam probes, and world-sample probes.
9. Run a visible editor/runtime review of the demo rivers.
10. Decide which expensive context masks should move into bake outputs.

## Validation Checklist

- Existing signature 23 probes still pass:
  - `RIVER_FLOWMAP_SEAM_PROBE_OK`
  - `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`
- New offset-routing diagnostic confirms logical-neighbor behavior at same-column and row-wrap joins.
- Debug river and visible river agree on sample routing.
- WaterSystem flow render still matches river flow direction after regeneration.
- First and last occupied river steps do not bleed into unused atlas cells.
- Pillow seam fades remain off by default.
- Visible review shows no straight tile bands in foam, normals, wakes, pillows, or height displacement.

## Source Notes

Local project sources:

- [Seam Handling Audit - 2026-06-11](audit/seam-handling-audit-2026-06-11.md)
- [River Flowmap Seams Changelog](changelog.md)
- [Seamless River Flowmap Techniques](Seamless%20River%20Flowmap%20Techniques.md)
- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/system_renders/system_flow.gdshader`
- `addons/waterways/water_system_manager.gd`
- `addons/waterways/system_map_renderer.gd`

External sources:

- Valve, Alex Vlachos, [Water Flow in Portal 2 / SIGGRAPH 2010](https://cdn.akamai.steamstatic.com/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf). Used for dual-phase flowmap animation, phase offsets, noise-reduced pulsing, and flowmap performance context.
- Graphics Runner, [Animating Water Using Flow Maps](http://graphicsrunner.blogspot.com/2010/08/water-using-flow-maps.html). Used as a practical explanation of Valve-style flowmap normal animation.
- Epic Games, [Water Meshing System and Surface Rendering in Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/water-meshing-system-and-surface-rendering-in-unreal-engine?lang=en-US). Used for the global water mesh and Water Zone comparison.
- Epic Games, [Water System in Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/water-system-in-unreal-engine?lang=en-US). Used for broad comparison with spline-authored water bodies and shared water-system data.
- Wave Harmonic, [Crest Water - Flow](https://docs.crest.waveharmonic.com/Manual/Simulation/Flow.html). Used for global flow-input and simulation-buffer comparison.
- Staggart Creations, [Stylized Water 2 - River Mode](https://staggart.xyz/unity/stylized-water-2/sws-2-docs/?section=river-mode). Used for river-specific UV, mesh, and material constraints.
- Guerrilla, Hugh Malan, [Rendering Water in Horizon Forbidden West](https://advances.realtimerendering.com/s2022/SIGGRAPH2022-Advances-Water-Malan.pdf). Used for baked deformation, partial derivatives, UV compensation, vertex-color limits, and tessellation tradeoffs.
- Arnklit, [Waterways Add-on for Godot Engine](https://github.com/Arnklit/Waterways). Used for upstream Waterways workflow, bake, WaterSystem, and documented limitations.
