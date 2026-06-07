# Initial Foam Research

## Summary

Modern game water foam is usually not one technique. The repeated production pattern is a layered shader system:

- Flow maps advect normals, color/detail textures, foam noise, and debris.
- Depth, signed distance fields, or baked masks create shoreline and contact foam.
- Wave steepness, slope, compression, curvature, or flow speed create crest and whitewater masks.
- Artist-authored masks, vertex colors, decals, splines, and particles provide local control.
- Dynamic foam is often added through render textures, simulation buffers, particles, or shallow-water/FLIP systems when the project can afford it.

For Waterways, the most useful direction is a cheap river-specific foam model:

1. Use the existing river direction/flow data to move foam texture coordinates.
2. Use water depth or terrain intersection for edge/contact foam.
3. Use flow speed, slope, or waterfall/drop masks for fast-water foam.
4. Allow optional painted/baked foam masks for art direction around rocks, bends, banks, and rapids.

## Strongest Sources

### Valve: Flow Maps As The Canonical Baseline

[Water Flow in Portal 2, Alex Vlachos, SIGGRAPH 2010](https://cdn.cloudflare.steamstatic.com/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf)

This is still the clearest flow-map reference for game water. Valve stores a 2D vector field in a texture. The shader uses that field to distort tiled normal maps in the direction of water flow.

Important takeaways:

- Flow maps are artist-authored 2D vector textures.
- The flow map covers the whole water surface, while the normal map is tiled.
- Two phase-offset flow layers are blended to hide the reset/loop.
- Noise offsets help reduce visible pulsing.
- Flow speed can reduce or modulate normal strength.
- The same method can flow color/detail maps such as dirty water debris.

This maps directly to river foam: foam textures should be advected with the same flow data as the normals, not simply panned in one global direction.

### NVIDIA GPU Gems: Waves And Normals

[Effective Water Simulation from Physical Models, GPU Gems Chapter 1](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)

This is a classic real-time water basis. It explains combining geometric waves with finer dynamic normal detail, including sine and Gerstner wave approaches.

Important takeaways:

- Macro movement and micro surface detail can be separate.
- Fine normal-map detail often contributes more to perceived realism than mesh displacement.
- Gerstner waves are useful for sharper crests.
- Crest sharpness and surface orientation are natural foam inputs.

For rivers, this supports a foam mask based on surface slope, normals, or wave height if Waterways later adds more wave displacement.

### Far Cry 5: Production Foam Composition

[Water Rendering in Far Cry 5, GDC 2018](https://media.gdcvault.com/gdc2018/presentations/Grujic_Branislav_WaterRenderingFarCry5.pdf)

This is a strong AAA reference because it combines several practical foam sources instead of relying on one.

Important takeaways:

- Foam color is modulated by noise.
- Flow maps are sampled using two offset phases.
- Signed distance fields control foam around rocks and shorelines.
- Displacement foam can be blended with shoreline/object foam.
- The final result is a max/blend of multiple foam signals.

This strongly suggests Waterways should combine foam masks with `max()` or weighted blend operations: shoreline foam, speed foam, manual mask foam, and any future wave crest foam.

### Diablo IV: Procedural River Foam

[H2O in H3LL: The Various Forms of Water in Diablo IV, GDC 2024](https://gdcvault.com/play/1034779/Technical-Artist-Summit-H2O-in)

This talk is valuable because it describes performance-minded, content-friendly shader water.

Important takeaways:

- Level artists can paint foam where needed.
- Procedural river foam is generated from flow speed masks.
- Foam can be added where flow vectors are longest/fastest.
- Normal masking can add foam where the water surface points away from world up, such as falling water.
- The team avoided relying on depth-based foam for some cases because abrupt depth changes can create poor visual results.

For Waterways, flow-speed foam and slope/drop foam are especially relevant. Depth/contact foam is useful, but it should be tunable and not be the only foam source.

### Epic: Distance Fields And Flow Around Obstacles

[Distance Fields and Simulation Tricks in UE4, Ryan Brucks, GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Brucks_Ryan_Distance_Fields_And.pdf)

This is highly relevant for foam around rocks, banks, and obstacles.

Important takeaways:

- Distance to nearest surface creates stable object/shore masks.
- Distance field gradients can identify upstream and downstream sides of obstacles.
- Flow vectors can be modified around obstacles using distance field information.
- Flow-map advection typically resets every period and fades to a phase-offset texture.
- Scale-flowmap style UV behavior can create foam falling off rocks.

Godot does not provide Unreal-style global distance fields by default, but similar data can be baked into textures, derived from terrain, painted into masks, or approximated with helper meshes/render textures.

### Uncharted Water

[Water Technology of Uncharted, GDC 2012](https://www.gdcvault.com/play/1015309/Water-Technology-of)

Important takeaways:

- Flow shaders scroll normal maps per pixel/vertex using vector fields.
- Refraction can use depth-based jitter and coloring.
- Foam movement can use threshold operations on gradient fields.
- Churn/depth coloring and foam texture modulation are artist-controlled.

This is another vote for a data-driven material: multiple masks, exposed parameters, and art control.

## Engine References

### Unity HDRP Water

[Unity HDRP Water System overview](https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4016.0/manual/WaterSystem-Overview.html)

[Unity blog: The new Water System in Unity 2022 LTS and 2023.1](https://unity.com/blog/engine-platform/new-hdrp-water-system-in-2022-lts-and-2023-1)

[Evaluate Foam Data Shader Graph node](https://docs.unity.cn/Packages/com.unity.shadergraph%4014.0/manual/Evaluate-Foam-Data-Water-Node.html)

Important takeaways:

- Unity separates simulation foam and custom foam.
- Foam can be masked, generated, or injected through Shader Graph.
- Foam generators support local foam around shore waves, rocks, boats, and icebergs.
- Custom foam can be generated from depth buffer sampling, scrolling foam textures, decals, and water masks.
- Unity HDRP foam is monochrome in the built-in system, which reinforces the idea that foam is mainly a scalar mask.

### Unreal Engine Water

[Unreal Water System](https://dev.epicgames.com/documentation/unreal-engine/water-system-in-unreal-engine)

[Water Waves Asset](https://dev.epicgames.com/documentation/en-us/unreal-engine/simulating-waves-using-the-water-waves-asset-in-unreal-engine)

[Single Layer Water Shading Model](https://dev.epicgames.com/documentation/en-us/unreal-engine/single-layer-water-shading-model)

[Fluid Simulation Overview](https://dev.epicgames.com/documentation/unreal-engine/fluid-simulation-in-unreal-engine---overview)

Important takeaways:

- Unreal's Water plugin uses Gerstner waves for macro wave simulation.
- Micro detail is expected to come from water materials and normal maps.
- Single Layer Water is the production-oriented shading model for physically based water surfaces.
- Niagara Fluids can provide FLIP and shallow-water style data, but this is heavier than a simple river shader.

For Waterways, the practical lesson is to keep foam shader-side and data-driven first, then add heavier simulation paths only if needed.

## Open-Source And Tutorial References

### Crest Ocean System

[Crest Water GitHub](https://github.com/FloatingOriginInteractive/crest-water)

[Crest documentation PDF](https://crest.readthedocs.io/_/downloads/en/4.21.4/pdf/)

Important takeaways:

- Crest generates foam from choppy/pinched wave crests and shallow water.
- Foam dissipates over time.
- Users can inject foam into the system using texture or vertex-color inputs.
- Crest has flow input support through top-down rendered data.

This is a strong reference for future advanced Waterways features: foam buffers, dissipation, and user inputs.

### Catlike Coding Flow Tutorials

[Catlike Coding: Flow tutorials](https://catlikecoding.com/unity/tutorials/flow/)

[Catlike Coding: Directional Flow](https://catlikecoding.com/unity/tutorials/flow/directional-flow/)

Important takeaways:

- Texture distortion works well for turbulent/sluggish flow but can look wrong for calm anisotropic ripples.
- Directional flow aligns texture detail with the flow direction.
- Grid/tile approaches can help align local flow direction while hiding seams.

Useful for any future Waterways shader that wants ripples aligned perpendicular to flow rather than just distorted noise.

### Flowmap Generator River Workflow

[Flowmap Generator River Tutorial](https://superpositiongames.com/files/flowmap_generator/docs/RiverExample.pdf)

Important takeaways:

- River flow maps can be baked from shallow-water style simulation.
- Alpha can store water coverage/depth/mask information.
- Flow map textures should bypass sRGB sampling.
- A separate river mesh over terrain is often easier than shading the whole terrain.
- Foam can have its own texture, tiling, speed, and edge fade parameters.

This is directly relevant if Waterways adds a bake step or generated flow/foam texture.

### Godot References

[Godot Flow Map Shader](https://godotassetlibrary.com/asset/6EdJ3t/flow-map-shader)

[Godot Foam Edge Water Shader](https://godotshaders.com/shader/foam-edge-water-shader/)

Important takeaways:

- Godot flow-map examples use the same RG vector texture idea as Valve.
- Two repeating layers and noise offsets are used to avoid long-running distortion artifacts.
- Godot edge foam examples often compare depth texture depth against fragment depth and modulate with foam noise.

Godot-specific warning: screen/depth texture based foam can create artifacts when water meshes have large vertex displacement or self-overlap. Keep displacement modest or provide a non-depth-based fallback mask.

## Research And Simulation References

[A Survey of Ocean Simulation and Rendering Techniques in Computer Graphics](https://diglib.eg.org/items/13496d23-2351-443a-bbc9-f07c1510b574)

[Real-time Simulations of Bubbles and Foam within a Shallow Water Framework](https://diglib.eg.org/items/8108fc3c-3020-4727-946f-5e5809be35fd)

[Very Fast Real-Time Ocean Wave Foam Rendering Using Halftoning](https://ianparberry.com/research/seafoam/)

[Ocean simulation and rendering in War Thunder](https://developer.download.nvidia.com/assets/gameworks/downloads/regular/events/cgdc15/CGDC2015_ocean_simulation_en.pdf)

Important takeaways:

- Physically based foam is possible but expensive.
- Games usually approximate foam with masks and textures unless water is a hero feature.
- Ocean whitecaps can be driven by compression/Jacobian-style criteria, then dissipated over time.
- Halftoning/dither masks are a cheap way to make foam breakup and dissipation feel less like a fading alpha texture.

## Foam Sources To Support

### 1. Flow Speed Foam

Use the length of the flow vector as a whitewater/foam factor.

Example concept:

```glsl
float flow_speed = length(flow_vec);
float speed_foam = smoothstep(speed_foam_start, speed_foam_end, flow_speed);
```

Good for:

- Rapids
- Narrow fast channels
- Waterfalls
- Strong river bends

This is strongly supported by the Diablo IV approach.

### 2. Contact Or Shoreline Foam

Use depth difference, terrain/bank masks, or baked distance-to-shore textures.

Good for:

- River banks
- Rocks
- Bridge supports
- Objects intersecting the surface

Limitations:

- Pure screen-depth foam can shimmer or change with camera/depth discontinuities.
- It may not flow with the river unless its texture coordinates are advected.
- It can create bad results where depth changes abruptly across pixels.

### 3. Painted Or Baked Foam Mask

Use vertex color, a mask texture, or baked river metadata to place foam intentionally.

Good for:

- Hero bends
- Rocks and banks
- Repeating rapids
- Places where procedural masks do not understand art direction

This is common in production because it is predictable and cheap.

### 4. Crest Or Slope Foam

Use wave height, normal direction, surface slope, curvature, compression, or "not facing up" masks.

Good for:

- Waterfalls
- Breaking waves
- Choppy rapids
- High-energy water

This is supported by Gerstner/whitecap literature, War Thunder, Crest, and Diablo IV.

### 5. Dynamic Foam Inputs

Use a render texture, particle system, or simulation buffer to add temporary foam.

Good for:

- Boats
- Characters
- Splashes
- Temporary wakes

This should be a later feature because it introduces extra rendering/update complexity.

## Recommended Shader Model For Waterways

### Inputs

- `flow_map`: RG flow vector, optionally alpha as water/river coverage.
- `foam_texture`: grayscale/noise foam breakup texture.
- `foam_mask`: optional painted or baked mask.
- `depth_texture`: optional, for contact/shore foam where available.
- `slope_or_drop_mask`: optional generated river data for waterfall/rapid sections.
- `flow_speed`: from flow map length or generated river metadata.

### Main Foam Mask

Combine foam sources with a max or weighted blend:

```glsl
float foam = 0.0;
foam = max(foam, shore_foam * shore_foam_strength);
foam = max(foam, speed_foam * speed_foam_strength);
foam = max(foam, painted_foam * painted_foam_strength);
foam = max(foam, slope_foam * slope_foam_strength);
foam *= foam_breakup;
```

### Flowing Foam Texture

Use the Valve two-phase flow pattern:

```glsl
vec2 flow = flow_map_rg * 2.0 - 1.0;
float phase_a = fract(TIME * foam_speed);
float phase_b = fract(TIME * foam_speed + 0.5);

vec2 uv_a = base_uv - flow * phase_a * foam_distortion;
vec2 uv_b = base_uv - flow * phase_b * foam_distortion;

float weight = abs(phase_a * 2.0 - 1.0);
float foam_a = texture(foam_texture, uv_a).r;
float foam_b = texture(foam_texture, uv_b).r;
float foam_breakup = mix(foam_a, foam_b, weight);
```

The exact wave function can differ, but the idea should stay: two animated samples, phase offset, blended to hide reset.

## Suggested Feature Scope

### First Pass

- Add foam texture sampling.
- Flow foam using existing/generated flow direction.
- Add flow-speed foam.
- Add optional painted/baked foam mask.
- Add exposed controls:
  - foam color
  - foam opacity
  - foam speed
  - foam tiling
  - foam breakup contrast
  - speed foam threshold/range
  - shoreline/contact foam strength

### Second Pass

- Add depth/contact foam if the renderer path supports it cleanly.
- Add separate bank foam and rock/contact foam controls.
- Add slope/drop foam for waterfalls.
- Add generated/baked foam mask output from the river tool.

### Later

- Add dynamic foam render texture for splashes/boats/characters.
- Add foam dissipation buffer.
- Add obstacle-aware flow vector modification around rocks.

## Main Risks

- Depth foam can look camera-dependent or noisy if used as the primary mask.
- Foam that is not advected by the flow looks pasted on.
- Flow-map UVs can visibly stretch if distortion grows too far before reset.
- sRGB sampling on flow maps will corrupt vector values.
- A single foam threshold tends to look artificial; use noise breakup and multiple sources.
- Artist control is necessary because procedural foam rarely understands composition.

## Practical Conclusion

For a Godot river addon, the best industry-aligned first implementation is:

- Flow-map-advected foam texture.
- Foam amount from flow speed.
- Optional shoreline/contact foam.
- Optional artist/baked foam mask.
- Simple max/blend composition of those masks.

That gives the addon the same broad architecture used in larger engines and talks, while staying small enough to fit a practical Godot shader and river tool.
