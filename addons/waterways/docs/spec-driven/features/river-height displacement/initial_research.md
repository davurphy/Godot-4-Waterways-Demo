# River Height Displacement Initial Research

Date: 2026-06-08

## Project Context

This project already works with a flow map. The current river shader uses flow-map-driven UV animation for normal details, foam, wake, pillow effects, and refraction. That is a strong base for visual flow, but it mostly changes how the surface is shaded. To make the water physically undulate up and down, the shader needs a vertex-stage height signal that modifies `VERTEX.y`.

The most relevant local shader is:

- `addons/waterways/shaders/river.gdshader`
- Existing flow function: `FlowUVW()`
- Existing vertex displacement: obstacle/terrain pillow height adds to `VERTEX.y`
- Existing ripple data: ripple height/normal helpers exist, and `i_ripple_displacement_strength` is declared

## Main Finding

The best fit is not a replacement for the current flow-map system. The best fit is to add a subtle height-displacement layer that uses the same flow data already driving the normal maps.

Recommended approach:

1. Keep flow-map normal advection for fine surface motion.
2. Add a flowed height texture sampled in the vertex shader.
3. Use existing flow force, foam, wake, pillow, and bank masks to control where displacement is visible.
4. Fade displacement by distance and by mesh/LOD suitability.
5. Recompute or approximate normals so lighting follows the displaced surface.

## Technique Options

### 1. Flowed Normal Maps

This is the classic Valve approach used in Left 4 Dead 2 and Portal 2. A flow map stores 2D vectors. The shader uses those vectors to warp normal-map UVs over time. Two phase-shifted samples are blended together to hide the reset point, and noise can offset phase to reduce pulsing.

This technique gives convincing directional water movement, but it does not move the mesh up and down.

Project fit:

- Already mostly implemented through `FlowUVW()`.
- Keep this as the primary fine-detail system.
- Improve it with additional scale layers only if needed.

Sources:

- [Valve SIGGRAPH 2010: Water Flow in Portal 2](https://cdn.fastly.steamstatic.com/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf)
- [Valve Developer Community: Water shader flow maps](https://developer.valvesoftware.com/wiki/Water_%28shader%29)

### 2. Flowed Heightmap Displacement

This is the closest match to the effect in the Godot flow-map shader we inspected. Instead of only flowing a normal map, the shader flows a height or displacement texture, samples it in `vertex()`, recenters the value around zero, scales it, and adds it to `VERTEX.y`.

Core idea:

```glsl
float h = texture(height_texture, flowed_uv).r * 2.0 - 1.0;
VERTEX.y += h * height_strength;
```

For rivers, `flowed_uv` should come from the flow map so crests and ripples travel downstream and around bends.

Project fit:

- Very good.
- Can reuse the existing flow vector and `FlowUVW()`-style two-phase sampling.
- Should be subtle: enough to give body, not enough to break banks or cause transparent depth artifacts.
- Needs a subdivided mesh.
- Needs distance fade to avoid far-field shimmer and vertex cost.

Sources:

- [GPU Gems 2, Chapter 18: Using Vertex Texture Displacement for Realistic Water Rendering](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-18-using-vertex-texture-displacement)
- [Godot 4.6: Your first 3D shader, vertex displacement](https://docs.godotengine.org/en/4.6/tutorials/shaders/your_first_shader/your_first_3d_shader.html)

### 3. Flow-Directed Sine or Gerstner Waves

GPU Gems describes a common split: use large geometric waves for mesh motion and fine normal-map waves for detail. Gerstner waves are more expressive than simple sine waves because they can move vertices laterally toward crests, giving sharper peaks and broader troughs.

For a river, the flow map can provide local wave direction and amplitude. This is useful for broad movement, but pure Gerstner waves can feel like ocean swell if used too strongly.

Project fit:

- Good for broad calm-water movement or stylized rapids.
- Less direct than heightmap displacement for following detailed river flow.
- Could be used as a secondary low-frequency layer.

Sources:

- [GPU Gems, Chapter 1: Effective Water Simulation from Physical Models](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
- [Tessendorf: Simulating Ocean Water](https://people.computing.clemson.edu/~jtessen/reports/papers_files/coursenotes2002.pdf)

### 4. Flowed Foam, Color, and Churn Maps

Portal 2 extended the same flow-map technique beyond normals. It flowed color and foam maps, used two phased samples, and packed additional opacity data into the flow texture. This makes surface detail feel like it belongs to the water rather than sliding over it.

Project fit:

- Already aligned with existing foam and wake systems.
- Useful for rapids: foam should increase where flow force, slope, bank contact, or obstacle wake is high.
- Height displacement should use the same masks so geometry, foam, and normals agree.

Sources:

- [Valve GDC 2011: Making and Using Non-Standard Textures](https://cdn.cloudflare.steamstatic.com/apps/valve/2011/gdc_2011_grimes_nonstandard_textures.pdf)

### 5. Local Ripple Height Fields

GPU Gems 2 discusses local perturbations for impacts, wakes, explosions, and object interaction. These can be analytic ripples or dynamic displacement maps updated over time.

This project already has ripple simulation textures and helper functions for sampling ripple height and normals. That makes local ripple displacement a natural addition.

Project fit:

- Very good for close-range interaction.
- Use `i_ripple_displacement_strength` to add small local vertex displacement.
- Fade by camera distance and boundary mask.
- Keep ripple normal and ripple displacement in sync.

Sources:

- [GPU Gems 2, Chapter 18: local perturbations and dynamic displacement mapping](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-18-using-vertex-texture-displacement)

### 6. Baked River Simulation Maps

Naughty Dog's Uncharted 4 rapids work used offline simulation to inform river surface and flow data, then split motion into geometric and visual components. For this project, a lightweight version would be to bake or generate extra maps: flow, foam/energy, pressure, phase, and maybe height.

Project fit:

- Strong long-term direction.
- Current system already has generated flow, pressure, obstacle, bank, and terrain-contact maps.
- Adding a generated height/energy channel could make rapids more coherent without runtime simulation.

Sources:

- [Advances in Real-Time Rendering 2016: Rendering Rapids in Uncharted 4](https://advances.realtimerendering.com/s2016/index.html)

## Godot 4 Notes

Godot spatial shaders support vertex-stage displacement through `vertex()` and `VERTEX`. Godot's docs show direct `VERTEX.y` changes and texture-sampled height displacement. They also show manual normal reconstruction for generated waves.

Important constraints:

- Mesh subdivision matters. Vertex displacement only moves existing vertices.
- Very fine height detail belongs in `NORMAL_MAP`, not geometry.
- Transparent water that samples screen/depth textures can have ordering and artifact issues.
- Displacement may need a larger custom AABB to prevent culling.
- Normals should be updated or approximated if displacement becomes visible.

Sources:

- [Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
- [Godot 4.6: Your first 3D shader](https://docs.godotengine.org/en/4.6/tutorials/shaders/your_first_shader/your_first_3d_shader.html)
- [Godot 4.6: Your second 3D shader, normal reconstruction](https://docs.godotengine.org/en/4.6/tutorials/shaders/your_first_shader/your_second_3d_shader.html)

## Recommended Prototype

### Phase 1: Subtle Flowed Heightmap

Add new uniforms:

```glsl
uniform sampler2D height_displacement_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform float height_displacement_strength : hint_range(0.0, 1.0) = 0.0;
uniform float height_displacement_speed : hint_range(0.0, 4.0) = 1.0;
uniform float height_displacement_lod_distance : hint_range(0.0, 200.0) = 40.0;
```

Use the existing flow vector and two-phase `FlowUVW()` pattern to sample height. Recenter sampled height around zero:

```glsl
float h = sampled_height * 2.0 - 1.0;
VERTEX.y += h * height_displacement_strength * lod_fade;
```

### Phase 2: Masked Rapids and Obstacles

Modulate height by existing maps and masks:

- `normalized_flow_force`
- `grade_energy_map`
- `pillow_mask`
- `wake_seed_mask`
- `eddy_line_mask`
- bank friction/pressure masks

This keeps the water calm where it should be calm and more physical near rapids, banks, and obstructions.

### Phase 3: Ripple Displacement

Use `ripple_height_at_world()` in the vertex path, controlled by `i_ripple_displacement_strength`.

Expected behavior:

- Close ripples visibly lift/lower the water surface.
- Far ripples remain normal-only for performance and stability.

### Phase 4: Normal Consistency

Approximate normals from the height field or feed the same height pattern into `NORMAL_MAP`. If visible vertex displacement and normal detail disagree, the result looks like a moving mesh with painted-on lighting.

## Risks

- Too much displacement can expose river-bank seams.
- Transparent refraction plus displaced geometry can create depth/sorting artifacts.
- Low mesh subdivision will make waves chunky.
- Heightmap tiling can become obvious unless phase/noise offsets are used.
- Recomputed normals cost extra samples.

## Initial Recommendation

Start small:

1. Add a height displacement texture and strength controls.
2. Use the current flow vector and phase blending.
3. Fade by distance.
4. Gate by flow energy and pillow/wake masks.
5. Keep displacement under roughly `0.05` to `0.25` world units until culling, bank seams, and normals are verified.

This should produce the desired "water has body and rises/falls" effect while preserving the flow-map architecture already built into the project.

## Consolidated Direction From Follow-Up Reviews

The strongest direction is a hybrid river displacement model:

1. **Moving high-frequency height:** a subtle height or displacement texture advected by the existing flow map.
2. **Static low-frequency height:** stationary pressure pillows, hydraulic jumps, bank turbulence, and obstacle standing waves driven by existing support maps.
3. **Runtime local height:** close-range ripple simulation added as a small world-space height contribution.

This direction keeps the current Waterways architecture intact. The goal is not to replace the river shader with an ocean shader, Gerstner system, or full fluid simulation. The goal is to give the existing flow-map river shader a controlled vertex-height layer that agrees with its normal, foam, wake, pillow, and refraction systems.

The current shader is already unusually well-positioned for this because it has:

- `FlowUVW()`, a two-phase flow function for advecting surface detail.
- `i_flowmap`, where RG stores flow direction, B is already used as foam-like data, and A is useful as phase/noise variation.
- generated pressure, distance, obstacle, terrain-contact, and bank-response feature maps.
- pillow and obstruction height controls that already add to `VERTEX.y`.
- runtime ripple height/normal helpers and a declared `i_ripple_displacement_strength`.

## Lessons From The Godot Flow-Map Shader

The JaccomoLorenz/Maujoe flow-map shader uses a direct and useful displacement pattern:

```glsl
float h = sampled_displacement * displace_scale + displace_offset;
VERTEX.y += h;
```

The important idea is not the exact shader, but the shape of the technique:

- sample a height/displacement texture in `vertex()`;
- animate that texture through the flow direction;
- recenter the sampled value so the mesh moves both up and down;
- keep the displacement small;
- use a subdivided mesh;
- rely on normal-map detail unless/until geometric displacement is strong enough to need reconstructed normals.

The demo offsets a 0..1 height texture with a negative `displace_offset`, which effectively turns it into a centered displacement range. That is why the water undulates around the baseline instead of only lifting upward.

## Updated Technical Recommendation

### 1. Start With A Dedicated Height Texture

Do not reorganize the existing flow-map channels at first. Our current channel usage already matters to the river shader, especially `i_flowmap.b` and `i_flowmap.a`. Add a dedicated height/displacement texture for the prototype.

Suggested initial uniforms:

```glsl
uniform sampler2D height_displacement_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform float height_displacement_strength : hint_range(0.0, 1.0) = 0.0;
uniform float height_displacement_speed : hint_range(0.0, 4.0) = 1.0;
uniform float height_displacement_lod_distance : hint_range(0.0, 200.0) = 40.0;
uniform float height_displacement_flow_power : hint_range(0.0, 4.0) = 1.0;
```

Keep the first amplitude deliberately small, roughly `0.05` to `0.25` world units, until seams, culling, and refraction are verified.

### 2. Reuse The Existing Flow Rhythm

Use the current `FlowUVW()` pattern rather than adding an unrelated flow function. Height, normals, foam, and visual flow should share the same broad rhythm so the surface feels coherent.

The first implementation can use the same two-phase idea:

```glsl
vec3 h_uv_a = FlowUVW(UV, flow, jump1, uv_scale, height_time, false);
vec3 h_uv_b = FlowUVW(UV, flow, jump1, uv_scale, height_time, true);
```

Then sample height through those UVs.

### 3. Recenter Per Sample Before Blending

For actual vertex height, recenter each sampled value around zero before applying strength:

```glsl
float h1 = textureLod(height_displacement_texture, h_uv_a.xy, 0.0).r * 2.0 - 1.0;
float h2 = textureLod(height_displacement_texture, h_uv_b.xy, 0.0).r * 2.0 - 1.0;
```

This avoids a water plane that only balloons upward.

### 4. Consider Variance-Preserving Height Blending

Linear two-phase blending can flatten displacement at the phase midpoint because two unrelated height samples average toward the mean. This is much more visible with vertex displacement than with normal maps.

A safer height blend is:

```glsl
float w1 = h_uv_a.z;
float w2 = h_uv_b.z;
float denom = max(sqrt(w1 * w1 + w2 * w2), EPSILON);
float flowed_height = (h1 * w1 + h2 * w2) / denom;
```

This preserves the apparent variance of the height signal better than a plain `mix()`.

Important correction from the deep-research pseudocode: normalizing a single blend weight and then passing it to `mix()` is not the same as variance-preserving blending. Recenter the samples first, then blend the weighted heights with the denominator above.

### 5. Separate Moving Height From Standing Waves

Not every river shape should move downstream. Standing waves, hydraulic jumps, pressure pillows, bank humps, and obstacle piles are often stationary in world space while foam and normals stream over them.

Use two layers:

- **flowed height:** animated chop and moving surface body;
- **static pressure/pillow height:** low-frequency shape around banks, rocks, hard boundaries, and shallow terrain.

The shader already has pillow/obstruction height logic. The new height system should support that instead of competing with it.

### 6. Mask Aggressively

Height displacement should be strongest where the river has energy and weakest where it can cause artifacts.

Good masks/modulators:

- `normalized_flow_force`
- `grade_energy_map`
- pressure and distance features from `i_distmap`
- obstacle feature masks
- terrain-contact and bank-response masks
- `pillow_mask`, `wake_seed_mask`, and `eddy_line_mask`
- distance-to-bank or terrain-contact attenuation
- camera distance fade

Recommended behavior:

- increase height in fast/steep/pressurized sections;
- add static height around pillows and standing waves;
- damp high-frequency height near banks and fragile intersections;
- optionally damp high-frequency geometric height in heavy foam, where normal/foam detail can carry the chaos more cheaply.

### 7. Add Runtime Ripple Height As A Local Superposition

The ripple system is a natural fit because the shader already has ripple height helpers. Once the base height layer is stable, add:

```glsl
float ripple_h = ripple_height_at_world(world_position);
VERTEX.y += ripple_h * i_ripple_displacement_strength * ripple_distance_fade;
```

Keep runtime ripple displacement close-range. Far ripples can remain normal/refraction-only.

The ripple normal contribution and ripple height contribution should use the same boundary and distance fade so the visual normal does not drift away from the geometry.

## Normal Strategy

Finite-difference normals are correct but should not be the first implementation step.

A central-difference normal reconstruction can require four or more additional height evaluations. If each height evaluation uses two-phase texture sampling, the vertex shader cost climbs quickly. This is acceptable for a later quality pass, but it is too expensive to make mandatory before we know the displacement layer is useful.

Recommended progression:

1. Start with subtle displacement and existing flowed `NORMAL_MAP`.
2. Align the visual normal texture with the height texture as much as possible.
3. If the geometric waves become visibly disconnected from lighting, add finite-difference normals.
4. When reconstructing normals, evaluate the **combined** height field: flowed height, static pillow/pressure height, and ripple height.
5. Respect the river mesh tangent/binormal basis. Do not assume local X/Z always maps cleanly to UV axes.

## Engine And Rendering Constraints

The research documents correctly call out the practical Godot issues:

- Vertex displacement only moves existing vertices, so mesh density or LOD matters.
- Godot spatial shaders need explicit `textureLod()` for vertex-stage texture samples.
- GPU vertex displacement can exceed the CPU-side mesh bounds, so culling margins or custom AABBs may need adjustment.
- Transparent water with screen/depth refraction can produce halos or foreground-object bleed, especially around rocks and banks.
- Bank seams are the biggest visual risk if the displacement is not damped at boundaries.

These concerns should be treated as part of the feature, not cleanup afterthoughts.

## What Not To Do First

Avoid these as initial implementation paths:

- Replacing the current flow-map architecture.
- Repacking `i_flowmap` channels before the prototype proves itself.
- Adding Gerstner waves as the main river-height solution.
- Building a wave-particle or Uncharted-style wave-profile system immediately.
- Turning on expensive finite-difference normals before subtle displacement has been evaluated.
- Pushing amplitude high before culling, refraction, bank seams, and mesh density are tested.

Wave particles, phase-field geometry, and wave-profile buffers are valuable research directions for authored rapids, but they are larger systems. They should remain future work unless the simpler hybrid shader layer fails to provide enough body.

## Proposed Implementation Path

### Phase 1: Minimal Flowed Height

- Add a dedicated height displacement texture.
- Sample it in `vertex()` using existing flow data and `FlowUVW()`.
- Recenter height to `-1..1`.
- Apply very small strength.
- Add a camera-distance fade.
- Do not change channel packing.
- Do not reconstruct normals yet.

### Phase 2: Better Two-Phase Height

- Replace simple height `mix()` with variance-preserving height blending.
- Use `i_flowmap.a` or existing phase/noise data to avoid global pulsing.
- Tune height speed independently from normal speed if needed.

### Phase 3: Hybrid River Shape

- Mask flowed height by flow force, grade energy, pressure, wake, pillow, eddy, bank, and terrain-contact maps.
- Add or refine static pressure/pillow height for standing waves.
- Fade displacement near banks and fragile terrain intersections.

### Phase 4: Runtime Ripple Displacement

- Add `ripple_height_at_world()` into the vertex displacement path.
- Gate with `i_ripple_displacement_strength`.
- Fade with boundary mask and camera distance.
- Keep ripple normals and ripple height synchronized.

### Phase 5: Normal Consistency

- Try a matching height-derived normal map or lower-cost approximation first.
- Add finite-difference normal reconstruction only if the geometry/light mismatch is obvious.
- If finite differences are used, sample the total height function and respect the mesh tangent basis.

### Phase 6: Production Hardening

- Expand culling bounds or `extra_cull_margin` based on maximum displacement.
- Verify river-bank seams with displacement at maximum intended strength.
- Verify transparent refraction around rocks, banks, and foreground objects.
- Add LOD or density controls if displaced geometry is too coarse.

## Final Direction

The best next step is a conservative hybrid displacement prototype:

```text
existing flow map
  -> existing FlowUVW rhythm
  -> dedicated flowed height texture
  -> variance-preserved centered height
  -> masks from flow energy, pressure, pillow, wake, bank, terrain contact
  -> small VERTEX.y displacement
  -> optional close-range ripple height
```

This gives the water physical body while preserving the Waterways shader's core identity: a river shaped by flow maps, banks, obstacles, foam, wakes, pillows, and local ripples.
