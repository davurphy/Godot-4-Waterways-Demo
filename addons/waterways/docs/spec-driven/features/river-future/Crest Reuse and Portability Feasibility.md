# Feasibility: Reusing Crest's Simulations and Approximations in Waterways

**Status:** Exploratory / future direction
**Date:** 2026-06-11
**Related:** `../river-obstacle-flow-constraints/River Flow Map Displacement Research.md`

## Question

Can the important simulations and approximations from Crest (wave-harmonic/crest, Unity, MIT) be encapsulated — potentially in an engine-portable form — with Waterways acting as the Godot-specific implementation of that core?

**Short answer: yes, feasible and sensible — provided the "portable" layer is drawn at the level of kernel math and data contracts, not at the level of Crest's rendering architecture.** Crest being MIT-licensed means its kernel math can be lifted verbatim with attribution.

---

## 1. What Crest actually decomposes into

Crest's source splits into two very different kinds of code, and the feasibility verdict differs sharply between them.

### 1.1 The kernels and math — highly portable

Each of these is a page or less of shader code plus a data contract, with no engine dependency in substance:

| Kernel / approximation | Crest source | What it is |
|---|---|---|
| Two-phase flow advection | `Shaders/OceanNormalMapping.hlsl` (`ApplyNormalMapsWithFlow`) — verified against the live repo | Two samples offset by half a period (default half-period = 1 s), offsets centered around zero (`offset -= 0.5 * period`), triangle-wave weights summing to 1, plain linear crossfade. Applied to **detail normals and foam only**, never height. |
| Dynamic waves sim | `Shaders/Resources/UpdateDynWaves.compute`, settings in `SimSettingsWave.cs` | Damped 2D wave equation, ping-ponged, fixed substeps. Wave speed `c = sqrt(g * depth)` from the depth cache (shallow water slows waves), clamped per-texel by a Courant/CFL term for stability. |
| Foam sim | `Shaders/Resources/UpdateFoam.compute`, `LodDataMgrFoam.cs` | Accumulator with exponential decay (`foam *= exp(-fadeRate * dt)`). Sources: (a) **Jacobian-determinant pinching** of total horizontal displacement — where `det(J) < coverage`, add foam; this single term unifies wave foam and wake foam; (b) shoreline foam where depth < threshold. Advected semi-Lagrangian by flow. |
| Per-wavelength depth attenuation | wave generation shaders, `SimSettingsAnimatedWaves` | `wt = lerp(1, saturate(2π·depth / wavelength), attenuationInShallows)` — long waves die approaching shore, short ripples survive. Physically motivated (waves "feel bottom" at depth ≈ λ/2) and nearly free. |
| Volume-neutral interaction forcing | `Scripts/Interaction/SphereWaterInteraction.cs` + input shader | Object forcing into the dyn-waves sim uses a **signed radial profile** — push down inside the footprint, lift in a ring around it — so net injected volume ≈ 0 and the result reads as pressure, not ballooning. Driven by velocity *relative to* the water (surface motion and flow subtracted). |
| Finite-difference normals | `Shaders/OceanHelpersNew.hlsl` (`SampleDisplacementsNormals`) | 3 taps of the displacement texture; tangent vectors built from **full 3D displaced positions** (not height alone, so horizontal chop steepening is captured), crossed and normalized. |
| Adaptive bounds | `Scripts/OceanChunkRenderer.cs` (`UpdateMeshBounds` → `ExpandBoundsForDisplacements`) — verified against the live repo | Every displacement source *reports* its max horizontal/vertical displacement each frame; chunk bounds extents grow by the accumulated maxima. Bounds derive from configured data, never from a hardcoded fudge factor. |
| Flow/height queries | `Scripts/Collision/QueryFlow.cs`, `QueryDisplacements.cs` | Async GPU readback against the same textures the renderer samples — one source of truth for visuals and gameplay (buoyancy, drift). |

### 1.2 The orchestration — inherently engine-bound, and mostly unnecessary for rivers

- The camera-centered clipmap LOD cascade (`LodDataMgr` + `Texture2DArray` per sim, one slice per LOD ring).
- Per-frame splatting of registered inputs (`RegisterLodDataInput` subclasses + `CommandBuffer.DrawRenderer`).
- Vertex grid snapping and `lodAlpha` density morphing in `OceanVertHelpers.hlsl`.
- Unity-specific readback, command buffer, and material plumbing.

None of this transplants — Unity command buffers, Godot `RenderingDevice`/Viewports, and Unreal RDG are different enough that this layer is a per-engine rewrite no matter what.

**The critical nuance:** most of that orchestration complexity exists to serve an *infinite ocean* — unbounded domain, camera-centered detail. A river is a bounded spline with a fixed UV parameterization. Waterways already has the correct substitute (baked atlas maps in UV2 space). "Encapsulating Crest" must mean encapsulating the **simulations and approximations**, not the cascade architecture. Porting the cascade would be solving a problem rivers don't have.

---

## 2. What the portable core would consist of

Three pieces, in increasing order of commitment:

### 2.1 A data contract (cheapest, highest value)

Texture channel semantics with explicit physical units:

- **Flow as true velocity in m/s** (world XZ), not normalized direction + separate magnitude. This is Crest's load-bearing convention: advection speed, buoyancy drift, foam transport, and gameplay queries all read the same field with zero per-consumer scale fudge factors.
- Height/displacement in meters, signed encoding documented.
- Foam as a 0–1 accumulator with a defined decay model.
- Feature masks (pillow, wake, eddy, bank response) with their gates documented as part of the contract rather than embedded only in shader constants.

The data contract is also what makes the gameplay side (buoyancy, audio cues, particle emission) consistent with the visuals — Crest's "dual life of the flow field" pattern.

### 2.2 A kernel library

The sim/math functions written as pure data-in/data-out shader code. Realistic portability mechanisms, in increasing tooling cost:

1. **Spec document + reference implementations** — zero tooling; how these techniques already travel between engines (Valve → Catlike Coding → everyone).
2. **Plain GLSL compute → SPIR-V** — Godot's `RenderingDevice` consumes GLSL compute directly; Unity/Unreal consume a mechanical HLSL translation. No toolchain, one translation per engine.
3. **Slang** — single-source compilation to HLSL/GLSL/SPIR-V/Metal. Genuine one-source-many-engines, at the cost of a build toolchain.

### 2.3 A thin host interface

Roughly ten operations: allocate render target, dispatch kernel, ping-pong swap, set/clear region, read back region. Each engine implements it once. **Do not build this until a second engine backend is real** (see §4).

---

## 3. Mapping onto Waterways as the Godot host

| Layer | Contents | Today's equivalent |
|---|---|---|
| **Core (portable in discipline)** | Data contract; advection math; ripple/dyn-wave step; foam accumulate/decay/pinch; depth/bank attenuation; volume-neutral forcing profile; finite-difference normals; bounds arithmetic; **the feature-mask filter math** (obstacle steering, wakes, eddy lines, bank response) | Scattered through `shaders/filters/*.gdshader`, `shaders/runtime/*.gdshader`, `river.gdshader`, with constants in `river_manager.gd` |
| **Waterways-Godot (host)** | Spline mesh generation, UV2 atlas layout, bake orchestration, inspector/gizmo integration, ripple field host, material plumbing, buoyancy | `river_manager.gd`, `water_helper_methods.gd`, `filter_renderer.gd`, `water_ripple_field.gd`, plugin/GUI scripts |

Notable points of fit:

- **The ripple field is already Crest's dyn-waves sim in miniature** (`shaders/runtime/ripple_simulation.gdshader` — damped wave equation, ping-ponged). It is the natural first resident of the core, and the natural recipient of Crest's depth-derived wave speed + CFL clamp and the volume-neutral forcing profile.
- **The feature-mask bake stack is original to Waterways and is itself pure image-space filtering** with no Godot dependency in its math. It is a *stronger* candidate for the portable core than anything in Crest, since Crest has no flow-obstacle-avoidance equivalent at all.
- **Crest's per-wavelength shore attenuation** maps directly onto the existing distance-to-bank data (`i_distmap` R) — attenuate displacement per frequency band (kill large pillows/waves near banks, keep fine ripple normals) instead of a single scalar edge fade.
- **Adaptive bounds** maps to `Mesh.set_custom_aabb()` grown by the sum of configured amplitudes (pillow heights + ripple displacement strength + any future advected-height amplitude). Since Waterways' amplitudes are static bake/material parameters, this computes once at bake/parameter-change time — simpler than Crest's per-frame version. This is currently **missing entirely** from the mesh pipeline and is needed regardless of any portability work.
- **Flow stored as m/s** would replace the current normalized-flow × `flow_force` convention; `buoyant_manager.gd` and any future drift/particle consumers would read the same field the shader advects with.

---

## 4. Honest caveats and risks

1. **YAGNI risk is real.** An abstraction with one consumer is a tax with no revenue. Until a second engine backend exists, "portable" should mean *discipline*, not infrastructure: kernel math kept in pure functions with explicit units, no engine types (Node, Material, Viewport, Curve3D) inside kernel logic, the data contract written down. That captures ~90% of the portability for ~0% of the cost. Resist building the host-interface plumbing speculatively.
2. **The current bake pipeline fights the portable shape.** Today's filters are `canvas_item` shaders run through Viewports — a Godot-specific idiom. A portable core pushes toward `RenderingDevice` compute, which is also closer to what Unity/Unreal consume. This refactor is **not pure overhead**: it aligns with performance work that is likely wanted anyway (e.g., the very expensive per-vertex pillow mask evaluation in `river.gdshader` `vertex()` — on the order of 200+ `textureLod` fetches per vertex — could move to a baked-texture compute pass).
3. **Runtime sims port cleanly; surface rendering does not.** The ripple sim, foam accumulation, and flow queries are engine-agnostic in nature. The river *surface shader* — refraction, depth fades, Godot's `NORMAL_MAP` pipeline, vertex-stage `textureLod` constraints, transparency ordering — will always be per-engine. Draw the line there and do not attempt to abstract it.
4. **Crest's omissions are also data.** Crest deliberately never advects height by flow (flow advects only normals/foam; heights come from world-space-stationary sources), and has no flow obstacle avoidance at all. Where Waterways diverges from Crest it is sometimes *ahead* (baked steering, wake/eddy features); the core should encode Waterways' approximations alongside Crest's, not treat Crest as the ceiling.
5. **Async readback in Godot.** Crest's query system relies on async GPU readback. Godot 4.4+ exposes async texture/buffer readback on `RenderingDevice`; older 4.x falls back to synchronous `texture_get_data` (stall) or CPU-side sampling of baked images (what `buoyant_manager.gd` effectively does today). Feasible, but version-gated.

---

## 5. Recommendation

Structure Waterways as two layers, with layer one being a **spec plus disciplined code organization, not a framework**:

1. **Now (discipline only, near-zero cost):**
   - Write the data contract (channel semantics + units) as a doc in this folder; adopt flow-as-velocity (m/s) as the convention for any new data.
   - Adopt Crest's "sources report their maxima" pattern: derive `set_custom_aabb()` expansion from configured amplitudes at bake/parameter time.
   - Keep new kernel math (and migrated existing math) in pure functions with no Godot types.
2. **Opportunistically (paid for by performance/quality wins, not by portability alone):**
   - Migrate the ripple sim and any new bake passes to `RenderingDevice` compute; fold in Crest's depth-derived wave speed, CFL clamp, volume-neutral forcing, Jacobian-determinant foam, and per-band bank attenuation as kernels in the core.
   - Move the per-vertex pillow mask stack into a baked/compute pass consuming the same kernels.
3. **Only if a second engine becomes real:** build the thin host interface and pick a cross-compilation mechanism (Slang or GLSL→SPIR-V + mechanical HLSL translation).

If a Unity or Unreal port ever materializes, the expensive thinking will already be done and the mechanical translation is days, not months. If it never does, every step above still leaves Waterways faster, better-specified, and easier to maintain.

---

## Appendix: Verification status of Crest claims

- `ApplyNormalMapsWithFlow` two-phase math: **verified verbatim** against `wave-harmonic/crest` master (`crest/Assets/Crest/Crest/Shaders/OceanNormalMapping.hlsl`).
- `OceanChunkRenderer.UpdateMeshBounds` / `ExpandBoundsForDisplacements` bounds expansion: **verified** against master.
- Dyn-waves/foam/interaction/attenuation specifics: high-confidence from model knowledge of the Crest 4.x codebase; structure and math reliable, exact identifiers unverified. Spot-check against the repo before lifting code verbatim.
