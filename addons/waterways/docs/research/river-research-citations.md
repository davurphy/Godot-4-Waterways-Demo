# River Research Citations

This file is the shared research index for Waterways river feature detection, visual water behavior, flow maps, and future physics-facing river work.

Update rules:

- Keep citations grouped by category so future sessions can find the right source quickly.
- Add a short "Waterways use" note for each source instead of only pasting a URL.
- Prefer sources with concrete algorithms, data layouts, tuning guidance, debug workflows, or production examples.
- Re-check version-sensitive engine documentation before using it for implementation details.
- Keep speculative or later-phase material in "Future Research Leads" until it is needed.

Last major research pass: 2026-05-31.

## Current Waterways Context

- [river-improvements-roadmap.md](../roadmaps/river-improvements-roadmap.md)
  - Waterways use: Phase history, source-signature boundaries, current channel layout, and the original "Sources Read" appendix this file was split out from.
- [river-feature-detection-roadmap.md](../roadmaps/river-feature-detection-roadmap.md)
  - Waterways use: Current review loop for pillows, wakes, eddy lines, raw masks, final visual masks, user-confirmed regions, and numeric tooling.
- [CHANGELOG.md](../history/CHANGELOG.md)
  - Waterways use: Historical record of which phases changed shaders, bakes, debug views, validation scripts, and source signatures.
- [handoff-latest.md](../handoffs/handoff-latest.md)
  - Waterways use: Tactical quick-start for the next research or implementation pass.

## Hydrology And River Reading

- [Boreal River Rescue, "How To Read a River - Hydrology 101"](https://rescue.borealriver.com/blogs/swiftwater-and-whitewater/hydrology)
  - Waterways use: Practical definitions for pillows, eddies, eddy lines, holes, and visible current-reading cues. Good for explaining feature placement in plain language.
- [Robert B. Kauffman, "River Dynamics" PDF, Frostburg State University](https://www.frostburg.edu/faculty/rkauffman/_files/images_rafting_chapters/Ch03b-RiverDynamics_v3.pdf)
  - Waterways use: Broader river-dynamics framing for obstacles, pillows, holes, eddies, and current behavior around river features.
- [Idaho River Sports, "Understanding River Currents: What Every Kayaker Should Know"](https://www.idahoriversports.com/blogs/news/understanding-river-currents-what-every-kayaker-should-know)
  - Waterways use: Practical river-current vocabulary for ordinary user-facing explanations.
- [Cali Paddler, "Understanding Eddy Currents in Rivers"](https://www.calipaddler.com/blogs/paddle-articles/understanding-eddy-currents-in-rivers)
  - Waterways use: Strong reference for splitting eddies into filling, standing, and flushing zones, and for treating eddy lines as boundaries instead of filled blobs.
- [Boat Ed, "River Hazards: Pillows"](https://www.boat-ed.com/waterrescue/studyGuide/River-Hazards-Pillows/191099_55417/)
  - Waterways use: Simple support for pillow behavior as upstream current piling against an obstruction.
- [Whitewater Guidebook, "What are the Different Types of River Currents?"](https://www.whitewaterguidebook.com/what-are-the-different-types-of-river-currents/)
  - Waterways use: Practical vocabulary for eddies, eddy lines, downstream current, and river-reading review discussions.
- [Mountain House, "How to Read the River for White Water Rafting & Kayaking"](https://mountainhouse.com/blogs/water-sports/white-water-river-reading-rafting-kayaking)
  - Waterways use: Plain-language support for eddy-line shear, holes, and visual river-reading cues.
- [U.S. Geological Survey, "Manning's Roughness Coefficients for South Carolina Streams"](https://www.usgs.gov/centers/sawsc/science/mannings-roughness-coefficients-south-carolina-streams)
  - Waterways use: Background for bank friction and roughness as calming or damping concepts, not automatic wake or pillow sources.
- [U.S. Geological Survey, "Find-A-Feature: Meander"](https://www.usgs.gov/educational-resources/find-feature-meander)
  - Waterways use: Basic geomorphology reference for bend/bank language.
- [National Park Service, "Fluvial Features - Meandering Stream"](https://www.nps.gov/articles/meandering-stream.htm)
  - Waterways use: Support for outside-bend faster flow/erosion and inside-bend deposition concepts used by bend-bias planning.
- [USDA Forest Service, "Geomorphology" PDF](https://www.fs.usda.gov/pnw/pubs/journals/pnw_2017_grant001.pdf)
  - Waterways use: Broader fluvial-process reference for channel forms, erosion/deposition language, and avoiding purely cosmetic interpretations of bends and banks.

## Obstructions, Wakes, Scour, And Open-Channel Flow

- [Wyssmann, Coder, Schwartz, and Papanicolaou, "Turbulent junction flow characteristics upstream of boulders mounted atop a rough, permeable bed and the effects of submergence"](https://pure.psu.edu/en/publications/turbulent-junction-flow-characteristics-upstream-of-boulders-moun/)
  - Waterways use: Research support for using submergence, roughness/contact, and local turbulence as gates for upstream boulder effects.
- [Dias and Vanden-Broeck, "Open channel flows with submerged obstructions"](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/abs/open-channel-flows-with-submerged-obstructions/D1418B1CFA3C476168345279041C2197)
  - Waterways use: Deeper fluid-mechanics reference for flow over submerged obstructions; useful when reasoning about holes or hydraulics later.
- [Schlomer and Herget, "Geometry of Local Scour Holes at Boulder-like Obstacles during Unsteady Flow Conditions and Varying Submergence"](https://www.mdpi.com/2073-4441/15/5/958)
  - Waterways use: Supports the idea that boulder-like obstacle effects depend on submergence and changing discharge, not just obstacle presence.
- [ScienceDirect, "Experimental investigation of the turbulent wake of partially submerged horizontal circular cylinders"](https://www.sciencedirect.com/science/article/pii/S0142727X24002340)
  - Waterways use: Later-phase wake/turbulence reference for partially submerged obstruction behavior.
- [ORCA Cardiff, "Influence of boulder concentration on turbulence and sediment transport in open-channel flow over submerged boulders"](https://orca.cardiff.ac.uk/id/eprint/107890/)
  - Waterways use: Supports avoiding demo-scene overfitting: boulder spacing and concentration alter wakes, turbulence, and local shear.
- [IAHR Library, "Modelling of Turbulent Flow over a Submerged Boulder in Open Channels"](https://www.iahr.org/library/info?pid=29878)
  - Waterways use: Reference for rough-bed and local turbulence effects around submerged boulders.
- [FHWA, "Underwater Bridge Inspection", Publication FHWA-NHI-10-027](https://www.fhwa.dot.gov/bridge/nbis/pubs/nhi10027.pdf)
  - Waterways use: Background for obstruction-induced local scour, horseshoe vortices, and wake vortices. More civil-engineering than rendering, so use cautiously.

## Flow Maps, Shader Animation, And Surface Rendering

- [Alex Vlachos, Valve, "Water Flow in Left 4 Dead 2 and Portal 2", SIGGRAPH 2010 PDF](https://cdn.cloudflare.steamstatic.com/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf)
  - Waterways use: Core production reference for low-resolution flow textures driving shader-time water motion and normal/detail animation.
- [Alex Vlachos, Valve, "Water Flow in Portal 2", SIGGRAPH 2010 course listing](https://advances.realtimerendering.com/s2010/index.html)
  - Waterways use: Stable index page for the Valve water-flow talk and related real-time-rendering material.
- [Valve, "Making and Using Non-Standard Textures", GDC 2011 PDF](https://steamcdn-a.akamaihd.net/apps/valve/2011/gdc_2011_grimes_nonstandard_textures.pdf)
  - Waterways use: Production reference for authoring and consuming special-purpose textures, relevant to packed feature maps and debug inspectability.
- [Valve Developer Community, "Water (shader)"](https://developer.valvesoftware.com/wiki/Water_%28shader%29)
  - Waterways use: Practical Source-engine water and flowmap notes; useful for production vocabulary and constraints.
- [Catlike Coding, "Texture Distortion"](https://catlikecoding.com/unity/tutorials/flow/texture-distortion/)
  - Waterways use: Clear tutorial for flow-map UV distortion, phase blending, and artifact management.
- [Catlike Coding, "Directional Flow"](https://catlikecoding.com/unity/tutorials/flow/directional-flow/)
  - Waterways use: Reference for aligning anisotropic ripple detail to flow direction and handling tile/blend artifacts.
- [NVIDIA GPU Gems, "Effective Water Simulation from Physical Models"](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
  - Waterways use: Foundational water surface simulation reference. Most useful for separating surface waves from river feature masks.
- [Jos Stam, "Real-Time Fluid Dynamics for Games", GDC 2003 PDF](https://www.dgp.toronto.edu/public_user/stam/reality/Research/pdf/GDC03.pdf)
  - Waterways use: Classic real-time fluid-solver reference. Useful for future simulation thinking, but too broad for immediate visual-mask tuning.
- [Roystan, "Toon Water Shader"](https://roystan.net/articles/toon-water/)
  - Waterways use: Practical reference for stylized water, depth/contact cues, and foam edge treatment.
- [Dan Lord, "Water Shader - Flow-Maps"](https://www.danlord3d.co.uk/tooling-visual-effects/unity-water-shader)
  - Waterways use: Practical explanation of painted flow maps around rocks and objects.
- [SideFX Labs, "Labs Guide Flowmap"](https://www.sidefx.com/docs/houdini/nodes/sop/labs--flowmap_guide.html)
  - Waterways use: Practical DCC flowmap-authoring reference if Waterways later imports Houdini/simulation-painted flow or compares bake output against external velocity textures.
- [Godot Asset Library, "Flow Map Shader"](https://godotengine.org/asset-library/asset/246)
  - Waterways use: Godot-specific flow-map shader example and lineage-adjacent technique reference.
- [Godot Shaders, "Simple River"](https://godotshaders.com/shader/simple-river/)
  - Waterways use: Recent Godot 4 river shader example. Good for comparison, but it is simpler than Waterways and not a replacement architecture.

## Production Water Systems, Baked Data, And Engine Examples

- [Epic Developer Community, "Baked River Simulations - Overview and Quick Start"](https://dev.epicgames.com/community/learning/tutorials/Y5J6/unreal-engine-baked-river-simulations-overview-and-quick-start)
  - Waterways use: Production-adjacent reference for baking river simulation data before runtime use.
- [Epic Developer Community, "Water System in Unreal Engine"](https://dev.epicgames.com/documentation/unreal-engine/water-system-in-unreal-engine)
  - Waterways use: Reference for keeping water rendering, meshing, gameplay interaction, and debugging as related but distinct systems.
- [Epic Developer Community, "Single Layer Water Shading Model in Unreal Engine"](https://dev.epicgames.com/documentation/unreal-engine/single-layer-water-shading-model-in-unreal-engine)
  - Waterways use: Architecture contrast for optimized water rendering. Useful as a reminder that Godot water should stay modular because it lacks this specialized render path.
- [Epic Developer Community, "Fluid Simulation in Unreal Engine - Overview"](https://dev.epicgames.com/documentation/unreal-engine/fluid-simulation-in-unreal-engine---overview)
  - Waterways use: Later-phase reference for interaction/ripple simulation, not immediate static feature-mask tuning.
- [Epic Developer Community, "unreal.ShallowWaterRiverComponent"](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/ShallowWaterRiverComponent?application_version=5.6)
  - Waterways use: Reference for physics-facing shallow-water river components and the kind of data that should remain separate from visual-only masks.
- [Ryan Brucks, Epic Games, "Distance Fields and Simulation Tricks in UE4", GDC 2019 PDF](https://media.gdcvault.com/gdc2019/presentations/Brucks_Ryan_Distance_Fields_And.pdf)
  - Waterways use: Distance-field and shader simulation tricks for obstacle influence and masks. Useful conceptually, but Waterways should prefer its existing baked maps before adding engine-specific distance fields.
- [GDC Vault, "Open-World Water Rendering and Real-Time Simulation", LIGHTSPEED STUDIOS, GDC 2023](https://www.gdcvault.com/play/1028829/Advanced-Graphics-Summit-Open-World)
  - Waterways use: Production framing for unifying water rendering, simulation, buoyancy, and large-world constraints.
- [LIGHTSPEED STUDIOS, "Open-World Water Rendering and Real-Time Simulation" slides, GDC 2023 PDF](https://media.gdcvault.com/gdc2023/Slides/Open-World%2BWater%2BRendering%2Band%2BReal-Time%2BSimulation_Mao_Zhenyu%26Wu_Kui.pdf)
  - Waterways use: Slide-level technical detail for large-scale water systems and simulation/rendering separation.
- [Advances in Real-Time Rendering, SIGGRAPH 2016 course index](https://advances.realtimerendering.com/s2016/)
  - Waterways use: Entry point for "Rendering Rapids in Uncharted 4" and related production material on layering flow maps with wave particles for obstacle-driven rapids.
- [80 Level, "River Editor: Water Simulation in Real-Time"](https://80.lv/articles/river-editor-water-simulation-in-real-time)
  - Waterways use: Production-facing reference for decoupling river authoring tools, simulation output, and artist review when considering future rapids or local wave layers.
- [RealtimeVFX, "VFX of Ghost of Tsushima - a recent blog"](https://realtimevfx.com/t/vfx-of-ghost-of-tsushima-a-recent-blog/15815)
  - Waterways use: Art-direction reference for accepting approximate localized water effects when they read correctly in motion instead of overfitting full physical simulation.
- [PlayStation.Blog, "How stunning visual effects bring Ghost of Tsushima to life"](https://blog.playstation.com/2021/01/12/how-stunning-visual-effects-bring-ghost-of-tsushima-to-life/)
  - Waterways use: Production example for stylized but physically informed water VFX, useful when tuning visual readability after raw mask placement is accepted.
- [Digital Foundry, "Red Dead Redemption 2 analysis: a once-in-a-generation technological achievement"](https://www.digitalfoundry.net/articles/digitalfoundry-2018-red-dead-redemption-2-tech-analysis)
  - Waterways use: High-level production comparison for rivers with dense authored flow, temporal stability, and strong lighting integration. Use as visual benchmark material, not implementation guidance.
- [Dear World, "Graphics Study: Red Dead Redemption 2"](https://imgeself.github.io/posts/2020-06-19-graphics-study-rdr2/)
  - Waterways use: Technical visual-analysis reference for water shading, reflections, and production tradeoffs when planning later material polish.
- [Unity, "The new Water System in Unity 2022 LTS and 2023.1"](https://unity.com/blog/engine-platform/new-hdrp-water-system-in-2022-lts-and-2023-1)
  - Waterways use: Reference for current maps, river scenes, VFX, and the split between material visuals and simulation.
- [Unity HDRP documentation, "Capabilities of the Water System"](https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4016.0/manual/WaterSystem-Overview.html)
  - Waterways use: Versioned reference for what a modern engine water system exposes. Re-check current docs before implementation.
- [GitHub, Unity-Technologies/WaterScenes](https://github.com/Unity-Technologies/WaterScenes)
  - Waterways use: Sample scenes showing current maps and river-water workflows in an official Unity context.
- [Galidar Studio Docs, "Riverology"](https://galidar.com/riverology)
  - Waterways use: Commercial river-tool comparison point for spline-driven rivers, flow physics, terrain integration, and exposed controls.
- [Galidar Studio Docs, "Riverology - Foam"](https://galidar.com/riverology/Foam)
  - Waterways use: Practical tuning reference for obstacle foam, flow-map influence, distance-field masking, and troubleshooting. Translate concepts into Waterways' existing maps rather than copying implementation.
- [Crest Ocean System PDF documentation, flow/currents notes](https://crest.readthedocs.io/_/downloads/en/4.22.1/pdf/)
  - Waterways use: Reference for flow inputs, foam, and physics-facing water motion. Re-check current Crest docs for exact APIs.
- [Crest Ocean System, "Oceans, Rivers and Lakes"](https://crest.readthedocs.io/en/stable/user/water-bodies.html)
  - Waterways use: Modular water-body reference for keeping rivers, lakes, and oceans as related but separate systems with different surface and flow needs.
- [Crest Ocean System, "Water Inputs"](https://crest.readthedocs.io/en/stable/user/water-inputs.html)
  - Waterways use: Reference for local water inputs and authored influence layers; useful when considering future user-authored overrides instead of only procedural bakes.
- [Crest Water, "Splines"](https://docs.crest.waveharmonic.com/Packages/Splines/Manual.html)
  - Waterways use: Spline-water architecture comparison for future authoring controls, local flow inputs, and separating geometry generation from water-surface behavior.
- [Crest Water, "Whirlpool" API](https://docs.crest.waveharmonic.com/API/WaveHarmonic.Crest.Whirlpool/Whirlpool.html)
  - Waterways use: Useful future eddy-control model because it separates displacement, flow advection, radius, swirl, max speed, and wave damping.

## Godot Constraints, Tooling, And Readbacks

- [Godot documentation, "Spatial shaders" 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html)
  - Waterways use: Authoritative shader-reference constraints for `river.gdshader` and `river_debug.gdshader`.
- [Godot documentation, "Screen-reading shaders" 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html)
  - Waterways use: Screen/depth texture constraints for any future depth/contact or refraction work.
- [Godot documentation, "3D rendering limitations"](https://docs.godotengine.org/en/latest/tutorials/3d/3d_rendering_limitations.html)
  - Waterways use: Renderer and platform constraint reference for water transparency, screen/depth effects, mobile limitations, and visual tradeoffs. Re-check before mobile or Compatibility-renderer support work.
- [Godot documentation, "Image" class 4.6](https://docs.godotengine.org/en/4.6/classes/class_image.html)
  - Waterways use: CPU-side pixel and region reads for raw numeric probes, mask coverage stats, and user-marked expected/forbidden regions.
- [Godot documentation, "Viewport" class 4.6](https://docs.godotengine.org/en/4.6/classes/class_viewport.html)
  - Waterways use: Capture/export workflow for rendered debug views. Remember to wait for `RenderingServer.frame_post_draw` before readback.
- [Godot documentation, "Command line tutorial" 4.6](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)
  - Waterways use: Source for scripted probe/export runs via `--script`.
- [Godot documentation, "ShaderInclude" 4.6](https://docs.godotengine.org/en/stable/classes/class_shaderinclude.html)
  - Waterways use: Maintainability reference for moving shared visible/debug water-mask helpers into `.gdshaderinc` files with `#include`.
- [Godot documentation, "Shader preprocessor" 4.4](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shader_preprocessor.html)
  - Waterways use: Details `#include` constraints and tradeoffs for reducing shader duplication while avoiding naming collisions.
- [Godot Asset Library, "Waterways - River Generation"](https://godotengine.org/asset-library/asset/805)
  - Waterways use: Public addon listing and feature lineage: spline river mesh generation, flow/foam maps, water/lava shaders, WaterSystem maps, and buoyancy.

## Open-Source And Practical Code References

- [GitHub, Arnklit/WaterGenGodot](https://github.com/Arnklit/WaterGenGodot)
  - Waterways use: Upstream/original project lineage. Use for historical comparison and MIT-friendly reference value.
- [GitHub, Unity-Technologies/WaterScenes](https://github.com/Unity-Technologies/WaterScenes)
  - Waterways use: Official Unity sample scenes with current maps and custom render textures.
- [GitHub, FloatingOriginInteractive/crest-water](https://github.com/FloatingOriginInteractive/crest-water)
  - Waterways use: Open-source water system reference for flow, foam, inputs, and modular water features.
- [GitHub, anunknowperson/uws, Universal Water System for Unity](https://github.com/anunknowperson/uws)
  - Waterways use: Alternative open-source water system for implementation comparison.
- [GitHub, z4gon/water-shader-unity](https://github.com/z4gon/water-shader-unity)
  - Waterways use: Small open-source water shader reference for comparing common normal/refraction/foam layering.
- [GitHub, Chrisknyfe/boujie_water_shader](https://github.com/Chrisknyfe/boujie_water_shader)
  - Waterways use: Godot 4 water shader reference for comparison of Godot-specific shader patterns.
- [GitHub, leonjovanovic/water-shader-unity](https://github.com/leonjovanovic/water-shader-unity)
  - Waterways use: Additional simple Unity shader reference for refraction, surface flow, and normal treatment.
- [GitHub, tessarakkt/godot4-oceanfft](https://github.com/tessarakkt/godot4-oceanfft)
  - Waterways use: Godot 4 RenderingDevice/compute reference for future ocean, lake, or displacement-buffer work. Not relevant to current static river feature-mask tuning.
- [GitHub, LanLou123/waveparticle](https://github.com/LanLou123/waveparticle)
  - Waterways use: Small open-source wave-particle reference for later rapids or obstacle wave stamps layered over baked river flow.

## Future Research Leads

- Better eddy-vector representation:
  - Look for algorithms that produce eddy center, spin side, radius, reverse velocity, and downstream leakage from obstacle and flow fields.
  - Do not promote current scalar masks directly into physics flow; `obstacle_features.g` and `.b` do not encode enough vector information.
- Shallow-water and grid simulations:
  - [FullSWOF, "A free software package for the simulation of shallow water flows"](https://arxiv.org/abs/1401.4125)
  - [A GPU Implementation for Two-Dimensional Shallow Water Modeling](https://arxiv.org/abs/1309.1230)
  - Waterways use: Later-phase references only if visual masks are no longer enough and a real flow-solver path becomes desirable.
- Flow-map generation tooling:
  - [SideFX Labs, "Labs Guide Flowmap"](https://www.sidefx.com/docs/houdini/nodes/sop/labs--flowmap_guide.html)
  - [Superposition Games, "Flowmap Generator River Tutorial" PDF](https://www.superpositiongames.com/files/flowmap_generator/docs/RiverExample.pdf)
  - [Superposition Games, "Flowmap Shaders" PDF](https://www.superpositiongames.com/files/flowmap_generator/docs/FlowmapShaders.pdf)
  - Waterways use: Practical comparison for authoring/exporting flow maps and shader consumption.
- Surface displacement, lakes, oceans, and large-water systems:
  - [Catlike Coding, "Waves"](https://catlikecoding.com/unity/tutorials/flow/waves/)
  - [Jaynakum, "Rendering Water using Gerstner (Trochoidal) Waves"](https://jaynakum.github.io/blog/5/GerstnerWaves.html)
  - [Yang Qi, "Ocean Simulation"](https://argent1024.github.io/projects/fftocean/)
  - Waterways use: Later-phase references if Waterways grows beyond spline rivers into lakes/oceans. Keep separate from river pillow/wake/eddy classifier work.
- Debug and QA workflows:
  - Investigate RenderDoc or image-diff workflows only if Godot scripted readbacks are not enough.
  - Prefer first-class Waterways probes that export raw maps, final masks, overlap stats, and user-marked regions.
