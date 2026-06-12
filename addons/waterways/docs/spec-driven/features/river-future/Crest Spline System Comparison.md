# Comparison: Crest 5 Spline System vs Waterways Spline Flowmap

**Status:** Research / recommendations
**Date:** 2026-06-12
**Related:** `Crest Reuse and Portability Feasibility.md` (same folder), `../river-obstacle-flow-constraints/implementation-plan.md`

## Sources and caveats

Crest side examined from pasted **Crest 5** source (`WaveHarmonic.Crest.Splines` namespace): `Spline.cs`, `SplinePoint.cs`, `SplineInterpolation.cs`, `SplineMeshUtility.cs`, `SplinePointData.cs`, point-data components (`Flow`/`Foam`/`Absorption`/`Scattering`/`WavesSplinePointData`), and the splat shaders (`Hidden/Crest/Inputs/Flow/Spline Geometry`, `…/Foam/Spline Geometry`, `…/Shape Waves/Spline`, plus the `Parameters` unpack include). The full spline → flow path is verified source, not inference.

**License caveat:** the earlier feasibility doc verified against the MIT-licensed 4.x repo (`wave-harmonic/crest`). Crest 5 is a different product under a different license — adopt *patterns and ideas* from this analysis, do not lift Crest 5 code verbatim without checking its license.

---

## 1. How Crest's spline → flow path works

**Authoring model.** A `Spline` component with `SplinePoint` child GameObjects (position + `_RadiusMultiplier` only). Optional per-point *data components* (`FlowSplinePointData`, `AbsorptionSplinePointData`, …) attach beside a point; each packs into one `Vector4` via `SplinePointData.GetData(default)`. A per-input default (`FlowSplineLodInputData.FlowVelocity`) applies where no point component exists. The same spline can feed multiple input types (flow, absorption, height, foam) — one curve, N data layers. Spline-level settings: `_Radius` (base half-width), `_Subdivisions`, `_Closed` (loop), `_Offset` (ribbon Left/Center/Right of the spline). A change-notification bus (`Spline.NotifyReceivers` → `IReceiveSplineChangeMessages`) rebuilds every consumer on edit.

**Curve math** (`SplineInterpolation`). Cubic Bézier hull with **auto-tangents only**: tangent at a point = average of directions to neighbors, scaled by segment length × magic `0.39`; endpoints mirror. No manual handles. Whole-spline `t ∈ [0,1]` parameterization, closed-loop wrap supported.

**Ribbon generation** (`SplineMeshUtility.GenerateMeshFromSpline`). Worth reading in full; the mechanisms:

1. Sample count from estimated length at constant world spacing `16m / 2^(subdiv+1)`.
2. Edge offset = horizontal (flatland, y=0) perpendicular of tangent × radius × per-point `_RadiusMultiplier`, the multiplier **smoothstep-interpolated** between points (Waterways lerps widths linearly).
3. **`ResolveOverlaps`**: on the inside of tight bends, an edge point that "backpedals" (negative dot with the spline tangent, evaluated in flatland) is clamped to the last forward-moving point, keeping its own Y. Prevents flipped/self-intersecting triangles.
4. **5 Laplacian smoothing iterations** (`p[i] = 0.5*(p[i-1]+p[i+1])`) on each edge polyline to soften the corners overlap-resolution creates.
5. Vertex data: `uv0.x` = cross-ribbon ramp 1→0 (feather/falloff input), `uv0.zw` = the **lateral axis direction in world XZ** per vertex pair (the splat shader rotates this 90° to get local flow direction — the rasterizer interpolates *direction* smoothly along and across the ribbon), `uv1` = the interpolated per-point `Vector4` (e.g. `FlowVelocity` — a **signed scalar speed along the spline tangent**, negative reverses).
6. Closed loops weld the seam by averaging first/last edge points.

**Flow splat** (`Hidden/Crest/Inputs/Flow/Spline Geometry`, verified). Purely kinematic, **rasterized at runtime every frame** into the flow LOD cascade:

- Vertex stage rotates the per-vertex lateral axis 90° about Y and into world space (`axis.y * M._m00_m20 − axis.x * M._m02_m22`) — flow direction is exactly the spline tangent, interpolated by the rasterizer.
- Fragment output = `weight × speed × axis`, a raw world-XZ velocity in m/s; `speed` is the rasterizer-interpolated per-point `FlowVelocity` from `uv1`.
- The only spatial shaping is a **symmetric triangle feather on the cross-ribbon coordinate** (`u > 0.5 ? 1−u : u`, divided by `_Crest_FeatherWidth`) — flow fades linearly to zero at both ribbon edges. That feather *is* Crest's entire bank treatment.
- Blend mode is per-input configurable (`Blend [_Crest_BlendSource] [_Crest_BlendTarget]`) — overlapping splines composite additively or alpha-blend by author choice.

No bake, no solve, no obstacle awareness; Crest has *no* mechanism for flow steering around solids — the feasibility doc's finding stands.

**Sibling splat shaders** (same ribbon, different payloads): the foam shader injects `0.25 × weight × Δt` (a dt-scaled source into the foam accumulator, per-point `FoamAmount`); the Gerstner-waves shader is the richest — wave direction follows the per-vertex axis, with an extra away-from-shore feather (`_Crest_FeatherWaveStart`) and **per-wavelength depth attenuation evaluated at splat time** (`saturate(2·depth/avgWavelength)`, the same kernel the feasibility doc catalogued). This is the payoff of the one-spline-N-layers architecture: identical geometry, per-layer physics in the fragment stage.

**Per-point data conventions.** `AbsorptionSplinePointData` shows the **override-vs-weight** pattern: a point either fully overrides the value (xyz) or merely modulates the weight (w) of the input-level default — "how much of this input applies here" without re-authoring the value.

---

## 2. The Waterways equivalent

- **Authoring:** one `Curve3D` (manual in/out handles) + parallel `widths` array, linearly interpolated (`water_helper_methods.gd:786`). No other per-point data; no closed loops; mesh always centered.
- **Mesh:** `_steps = length / average_width` (square-ish UV2 tiles), `shape_step_*_divs` density, UV2 atlas parameterization. No overlap resolution at tight bends.
- **Flow baseline:** uniform `+V` in **local UV space** at constant `RIVER_DOWNSTREAM_BASELINE_STRENGTH = 0.25` everywhere (`create_downstream_baseline_flow_image`). All spatial variation comes from the bake (pressure projection vs solids, occupancy stilling, wake damping) and from runtime force shaping (`contextual_flow_force()` reading distance/pressure/grade-energy/bend-bias maps through ~15 material uniforms: `flow_speed`, `flow_base`, `flow_steepness`, drags, gates…).
- **Curve-derived scalar channels already exist** as bake source images: `grade_energy` and `bend_bias` (`_create_curve_grade_energy_source_image`, `_create_curve_bend_bias_source_image`) — the natural template for any new per-point channel.

## 3. Head to head

| Dimension | Crest 5 splines | Waterways | Better |
|---|---|---|---|
| Flow physics (obstacles, continuity) | None — kinematic tangent × speed | Pressure-projected, free-slip, occupancy-clipped, wake-damped | **Waterways, decisively** |
| Bank treatment | Linear edge feather only | Distance-field drag, shallow drag, bend bias, hard-boundary handling | **Waterways** |
| Per-point authored data | Speed, radius ×, absorption, … composable layers | Width only | **Crest** |
| Authored speed variation along river | Per point, signed (can reverse) | Single global baseline constant | **Crest** |
| Curve control | Auto-tangents only (0.39 magic) | Manual Bézier handles | **Waterways** |
| Tight-bend mesh robustness | Overlap clamp + Laplacian smoothing | Nothing | **Crest** |
| Width interpolation | Smoothstep | Lerp | Crest (minor) |
| Closed loops | Yes | No | Crest |
| Feedback latency | Instant (runtime splat) | Bake required | Crest (but the bake is what buys the physics) |
| Spline reuse across systems | One spline → N input layers | River owns everything | Crest (architecture) |
| Flow units | World XZ m/s | Local-UV normalized ×0.25 | Crest (already flagged in feasibility doc §2.1) |

**Verdict:** on flow *behavior* Waterways is well ahead — Crest's spline flow is exactly the "cheap tier" the implementation plan replaced. Everything worth taking from Crest is on the **authoring** side.

---

## 4. Recommendations

### Adopt

1. **Per-point flow speed** (highest value). Add a `flow_speeds` parallel array beside `widths` (same `_safe_width_value`-style guards), baked as a curve-derived scalar source image **exactly like `grade_energy`/`bend_bias`**, consumed by `contextual_flow_force()` as a speed multiplier. Authors finally get slow pools / fast rapids as intent, not just emergent constriction speed-up. Deliberately *not* fed into the pre-projection baseline magnitude: a magnitude-varying baseline has divergence the solve would partially undo; a post-projection scalar multiplier preserves the projected field's non-penetration guarantee the same way wake damping already does. (Signed/reverse flow à la Crest is out of scope — the whole bake assumes downstream +V.)
2. **`ResolveOverlaps` + Laplacian edge smoothing** in `generate_river_mesh` for tight bends. Self-contained, fixes a real failure mode (self-intersecting ribbon edges), independent of any flow work. The flatland backpedal test against the spline tangent + keep-own-Y detail are both worth copying as-is (as a pattern — see license caveat).
3. **Smoothstep width interpolation** — one-line change at `water_helper_methods.gd:786`; removes width-derivative kinks at points.
4. **Override-vs-weight as the convention for future per-point channels** — each channel = value + weight, point either overrides the value or just scales the river-level default's weight.
5. **Per-point data as named channels** (medium-term). Generalize `widths` into a small per-point channel table (name → array + interpolation + default), each bakeable to a source image via the existing grade-energy template. Candidates: flow speed (above), depth bias, foam amount, ripple strength. This is the structural lesson of `SplinePointData` translated to Curve3D + arrays — Godot resources can't grow per-point components, but parallel channels achieve the same expressiveness.

### Consider later

- **Closed-loop splines** (moats, ring channels): `Curve3D` has no closed flag; Crest shows what's needed — wrap-aware tangents, seam weld, whole-loop parameterization. Real feature, nontrivial touch surface (mesh, UV2 atlas continuity, baseline direction).
- **Change-notification discipline**: if spline data ever feeds consumers outside `river_manager.gd` (ripple field seeding, gameplay), Crest's receiver-bus pattern is the shape to copy.

### Reject (deliberately)

- **Runtime splatting** — the bake is load-bearing for the pressure projection; instant feedback is not worth losing non-penetration guarantees. (Bake latency is a tooling problem, not an architecture problem.)
- **Auto-tangents** — strictly less control than `Curve3D` handles.
- **`SplineOffset` left/right ribbons** — Crest needs it because effects are authored as separate splines; Waterways derives bank effects from the distance field of the one river mesh.
- **World-space flow storage** — UV-space flow is correct for UV-space advection in `river.gdshader`; the *units/contract* point (flow as m/s for gameplay consumers) is already tracked in the feasibility doc §2.1 and is about the system map, not the river-local field.
