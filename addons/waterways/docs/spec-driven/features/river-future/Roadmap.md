# Waterways Roadmap

**Status:** Proposed plan
**Date:** 2026-06-12
**Consolidates:** `Crest Spline System Comparison.md`, `Crest Reuse and Portability Feasibility.md` (this folder), `../river-obstacle-flow-constraints/implementation-plan.md` (§5 out-of-scope), `../river-obstacle-flow-constraints/River Flow Map Displacement Research.md` (its 6-phase plan)

Ordering principle: land what's done, then cheap robustness wins, then authoring expressiveness, then the big visual feature (displacement), then sim depth and performance. Each phase is independently shippable; later phases consume earlier ones but earlier ones never depend on later ones.

---

## Phase 0 — Land the pressure-projection branch

The `river-obstacle-flow-constraints` work is implemented and tuned (plan §6, gates passing, fresh bakes saved). Remaining:

- [ ] Final visual pass over the screenshot locations (plan §4.4).
- [ ] Merge to `main`.

Everything below assumes this is in.

## Phase 1 — Foundations and quick wins

Small, independent, low-risk items. All four sources agree these are wanted regardless of direction.

- [x] **Custom AABB from configured amplitudes** *(done 2026-06-12)* — `_update_mesh_custom_aabb()` in `river_manager.gd`, headroom = sum of `DISPLACEMENT_AABB_SHADER_PARAMETERS` (the pillow heights — the only `VERTEX.y` contributors today), recomputed on mesh generation and on those `mat_` property edits. Verified by `probes/custom_aabb_probe.gd` (zero and nonzero amplitudes). (Feasibility §3; Displacement phase 6 — pulled forward.)
- [x] **Tight-bend mesh robustness** *(done 2026-06-12)* — `_resolve_river_row_overlaps()` in `water_helper_methods.gd`: backpedal clamp vs spline tangent (flatland, keeps own Y), Laplacian relaxation of clamped neighborhoods only, interior row points rebuilt between corrected edges. No-op when there are no overlaps. (Comparison §4.2.)
- [x] **Smoothstep width interpolation** *(done 2026-06-12)* — eased lerp in `generate_river_width_values`; source signature bumped 25 → 26 (covers the mesh changes too). Demo bakes + system map regenerated, projection gates pass. (Comparison §4.3.)
- [x] **Data contract doc** *(done 2026-06-12)* — `Data Contract.md` (this folder); flow-as-m/s adopted for new data, change rules include the AABB registration rule. (Feasibility §2.1, §5.1.)
- [ ] **Kernel discipline** — new shader math lands as pure data-in/data-out functions, no engine types; standing convention from here on, re-checked at review time rather than ever "done". (Feasibility §5.1.)

## Phase 2 — Per-point authoring (the Crest steal)

The single biggest authoring gap vs Crest: intent can only be expressed as one global width array + uniform constants.

- [x] **Per-point flow speed** *(done 2026-06-12)* — `flow_speeds` array parallel to `widths` (inspector "Flow" group; factor 0–2, neutral 1), baked via `_create_curve_flow_speed_source_image` (grade-energy template, smoothstep between points) and applied by `flow_speed_scale_pass.gdshader` as a **post-projection bake pass** — magnitude only, direction untouched, so the solve's non-penetration guarantee survives, and the system map / ducks inherit the authored speeds for free. Skipped entirely when all points are neutral. Signature v27 (per-point `flow_speed`); `flow_speed_scaled` metadata flag. Verified by `probes/flow_speed_scale_probe.gd`: slow band ×0.49 (authored 0.5), fast band ×1.48 (authored 1.5), neutral ×1.0, direction delta 0.01 rad, solids unchanged. Gizmo handles deferred (inspector-only editing for now). (Comparison §4.1.)
- [ ] **Named per-point channel table** — generalize `widths`/`flow_speeds` into a small registry (name → array, interpolation, default, bake target) so the next channel is data, not plumbing. Candidates queued behind it: depth bias, foam amount, ripple strength. (Comparison §4.5.)
- [ ] **Override-vs-weight convention** — each future channel is value + weight; a point either overrides the value or scales the river default's weight. Adopt as convention now, while the table is being designed. (Comparison §4.4.)

## Phase 3 — Flow-advected height displacement

The headline visual feature: waves that actually travel with the flow. Follows the displacement research's phased plan, condensed (its phase 6 AABB item moved to Phase 1 here):

- [ ] **3a. Minimal advected height** — displace `VERTEX.y` from the detail heightmap through the existing `FlowUVW()` advection; accept the pulsing artifact as the baseline.
- [ ] **3b. Variance-preserving two-phase blend** — algebraic blend (÷ √Σw²) instead of `mix()`, height recentering to signed range, spatial phase-offset noise to decorrelate seams.
- [ ] **3c. Coupling to the baked field** — amplitude × decoded flow speed (kinetic energy → wave height; per-point flow speed from Phase 2 feeds straight in); pillow/pressure maps drive the *stationary* layer; foam-weighted damping; bank masking from terrain contact + occupancy (displacement → 0 at solids — Crest deliberately never advects height by flow, so this is beyond-Crest territory; the occupancy clip is what makes it safe).
- [ ] **3d. Ripple superposition** — add the runtime ripple field's height in the vertex stage, with view-distance fade-out on the fetch.
- [ ] **3e. Finite-difference normals** — 4-tap central difference in the vertex stage from full displaced positions (Crest's kernel), composite detail normal map on top in fragment.
- [ ] **3f. Hardening** — screen-depth checks before refraction sampling (glow/MSAA bleed at occluders), vertex-density/LOD strategy for near-camera displacement.

Gate for 3c→3f: per-band bank attenuation (Crest's `wt = lerp(1, saturate(2π·depth/λ), k)` against the distmap) is the principled replacement for a single scalar edge fade — adopt it when 3c's masking proves too blunt. (Feasibility §3.)

## Phase 4 — Ripple sim and foam kernels (Crest lifts)

The ripple field is already Crest's dyn-waves sim in miniature; these are drop-in upgrades from the (MIT, 4.x) kernel catalogue:

- [ ] Depth-derived wave speed `c = √(g·depth)` + per-texel CFL clamp in `ripple_simulation.gdshader`.
- [ ] Volume-neutral interaction forcing (signed radial profile, velocity relative to flow) — fixes "ballooning" from object splashes.
- [ ] Jacobian-determinant foam pinching as a foam source, unifying wake foam and ripple foam, advected by flow with exponential decay.

(All Feasibility §1.1/§5.2. Verify identifiers against the 4.x repo before lifting; do not lift Crest 5 code.)

## Phase 5 — Solver depth and performance

- [ ] **Advection iterations in the bake solve** — extend the one-shot projection toward advect→project cycles for real asymmetric wakes and eddy recirculation; wake-mask damping currently covers the visual need, so this is quality headroom, not a gap. (Implementation plan §5.)
- [ ] **RenderingDevice compute migration** — move the bake filter stack (and ripple sim) from canvas_item/Viewport ping-pong to compute. Paid for by performance, not portability: the per-vertex pillow mask stack in `river.gdshader` (audited worst case ≈ 622 `textureLod`/vertex, defaults ≈ 94 — the older "~200+" figure was reach-only) moves to a baked pass consuming the same kernels. (Feasibility §4.2, §5.2.)
- [ ] Revisit the `dist_pressure.g` force-boost default once wake damping + speed ramp have soaked. (Implementation plan §5.)

## Backlog (unscheduled, tracked)

- **Closed-loop splines** (moats, ring channels) — wrap-aware tangents, seam weld, UV2 atlas continuity, baseline direction. Real feature, wide touch surface. (Comparison §4 "consider later".)
- **System map flow in m/s** — migrate `buoyant_manager.gd`/gameplay consumers to the data-contract units; river-local field unaffected. (Feasibility §2.1.)
- **Spline change-notification bus** — only if spline data grows consumers outside `river_manager.gd`. (Comparison §4 "consider later".)
- **Thin host interface / cross-compilation (Slang or GLSL→SPIR-V)** — only if a second engine backend becomes real; until then portability = the Phase 1 discipline items. (Feasibility §2.3, §5.3.)

## Explicitly rejected (with reasons, so they stay rejected)

- Runtime flow splatting (Crest's model) — instant feedback isn't worth losing the bake's non-penetration guarantee; bake latency is a tooling problem.
- Auto-tangent-only splines — strictly less control than `Curve3D` handles.
- Offset (left/right) ribbons — bank effects derive from the distance field here.
- Porting Crest's LOD cascade — solves an infinite-ocean problem rivers don't have.

## Dependency sketch

```
Phase 0 ──► Phase 1 ──► Phase 2 ──► Phase 3 (3a→3f, needs 1's AABB; 3c consumes 2's flow speed)
                 │
                 ├──► Phase 4 (independent of 2/3; 4's foam feeds 3c's damping if available)
                 └──► Phase 5 (anytime after 0; compute migration easiest before 3 adds shaders)
```

Phases 2, 4, and 5's compute migration are mutually independent and can be reordered or interleaved by appetite; Phase 3 is the long pole and the visible payoff.
