# Spec: Occupancy-Masked, Pressure-Projected River Flow

## Summary

Rivers must not let water flow through (or render inside) obstacles and bank protrusions. The feature replaces the old local-rotation SDF steering — which re-opened a penetration hole at every artifact-suppression gate — with a bake-time pressure-projection solve over the spline-tangent baseline, plus a baked `water_occupancy` mask that the runtime shader reads to clip water inside solids and still flow at boundaries. It guarantees `v·n = 0` at solids by construction.

This spec is a **constitution rule-12 backfill** (river-refactor R8.3): the feature was implemented and tuned on branch `river-obstacle-flow-constraints` (2026-06-11/12) before the template docs existed. The authoritative design narrative is `implementation-plan.md` in this folder; this file states the behavior/acceptance contract retrospectively. Architecture-level current truth lives in `docs/architecture-and-features.md` (Obstacle Handling, `water_occupancy`) and `../river-future/Data Contract.md`.

## Current Truth

- Status: Complete (implemented + tuned, landed pre-R8; mechanism re-validated by river-refactor R2).
- Source of truth for open work: none open — this folder is a backfill; live refactor follow-ups are tracked in `../river-refactor/roadmap.md`.
- Last meaningful decision: river-refactor R2 confirmed the projected-flow fix is correct and moved the WaterSystem (duck-read) flow onto the same shared flow include; the prior numeric "Defect-1 signature" was found to be quantization noise, not the slide (see Resolved Questions).
- Known deferred items: advection iterations in the solve (asymmetric wakes); the `dist_pressure.g` force-boost default revisit; system_flow occupancy stilling/wake damping so duck-read magnitudes match the surface (user decision, noted not implemented).
- Current non-goals easy to reopen: chasing the ~23–27° influence-zone angular floor on fresh system maps (it is sampling/quantization noise — do not treat as a defect).

## Goals

- Guarantee non-penetration: baked flow never points into a solid; `|flow| ≈ 0` inside solids.
- Stop water rendering and animating inside boulders/cliffs/crevices.
- Stop full-speed water "rushing out" of obstacle lee sides; the lee side moves slowly.
- Keep ducks (buoyancy) reading the same corrected flow the surface shows, via the WaterSystem map.
- Degrade to identity on bakes that predate the occupancy/projection system (old bakes keep working).

## Non-Goals

- Advection iterations in the bake solve (real asymmetric wakes / eddy recirculation) — wake-mask damping covers the visual need.
- Flow-advected height displacement, finite-difference normals, custom AABB (tracked by `River Flow Map Displacement Research.md`).
- Changing the `dist_pressure.g` force-boost default.
- A general signed-distance-field system — the solve is unsigned occupancy + pressure projection, not an SDF.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Industry validation summarized in `implementation-plan.md` §2 (Portal 2, Far Cry 5, Flowmap Generator, GPU Gems ch. 38, Crest).
- Known scene/data/context facts: demo scenes are `Demo.tscn` and `Demo_obstacle_flow_test.tscn`; each owns its own river and system bakes (un-shared during river-refactor R0). Rebakes are not byte-deterministic on the obstacle scene (GPU variance).
- Agent confidence in the premise: high — the mechanism is industry-standard and probe-verified; the one premise correction is the angular-floor attribution (Resolved Questions).
- Possible expected-behavior explanations ruled out: dark FLOW_ARROWS cells beside rocks are solid-mask centers / decelerated-flow texels, not stilled open water (implementation-plan §6.4); the influence-zone angular floor is quantization noise of the stilled low-magnitude ring.

## Users and Workflows

### User Story: River author placing rivers through rocky terrain

As a river author, I want flow to route around rocks and stay out of solid geometry without per-rock hand-tuning, so that the baked map and the buoyancy it feeds are physically plausible.

Acceptance criteria:

- After baking, flow arrows route around obstacles and bank protrusions instead of passing through them.
- No water renders or animates inside solids; lee sides slow down.
- Ducks near obstacles do not drift into boundary-shear paths.

## Functional Requirements

- Bake a `water_occupancy` texture: R = crisp solid mask (collision ∪ high-confidence terrain protrusion), G = solid proximity ramp to `RIVER_OCCUPANCY_RAMP_TILES` (0.12), B/A unused (0/1).
- Replace the legacy SDF-steering pipeline step with: solid prep → proximity → divergence → Jacobi pressure schedule → gradient subtract → boundary tangency, on HDR float targets, no post-blur.
- Record `obstacle_avoidance_algorithm = "pressure_projection_free_slip_jacobi_with_normal_to_flow_blur_fallback"` and `flow_projected = true` in bake metadata.
- Runtime shader (`river.gdshader`, mirrored in `river_debug.gdshader`, and `system_flow.gdshader` for the flow family): clip on `occupancy.r`, speed-still on `occupancy.g` (`OCCUPANCY_SPEED_RAMP_FULL = 0.45`), wake-damp on the wake seed mask, and **skip the contextual slide when `i_flow_projected`**.
- `RiverBakeData` carries `water_occupancy` as an optional texture; absence is identity.

## Non-Functional Requirements

- Maintainability: the flow force/slide code is single-sourced in `river_flow_common.gdshaderinc` (river-refactor R2/R3); the three consuming shaders cannot drift again.
- Performance: 40 Jacobi passes at bake time (strides `[32,16,8,4,2,1,1,1]` × 5); runtime adds occupancy clip/still/wake reads only.
- Visual quality: no penetration, no interior water, slowed lee sides.
- Godot 4.6+ compatibility: HDR float render targets via `use_hdr_2d`; vertex-stage `textureLod`.
- Runtime usability: buoyancy reads corrected flow through the WaterSystem map.
- Extensibility: occupancy mask is a reusable bake product; the solve passes are descriptor-addable filter passes.

## Add-on Boundary

Editor authoring responsibilities:

- Bake controls (Generate Flow & Foam Map, Generate System Map); FLOW_ARROWS and occupancy debug views.

Bake/data responsibilities:

- `water_occupancy` texture + channel metadata; `flow_projected` and solve params in `source_metadata`/signature; system bake `system_flow_map_version`.

Runtime responsibilities:

- Shader occupancy consumption; `system_flow.gdshader` flow generation; `buoyant_manager.gd` flow sampling.

Shared code must not depend on:

- A specific scene layout, one collider shape style, or the presence of HTerrain (physics-fallback provenance is handled).

## Data and Extension Model

Users should be able to:

- Bake rivers with or without occupancy; old bakes load and behave as identity.
- Give a specific rock a tighter/trimesh collider for baking if its convex-hull rim is too fat (implementation-plan §6.4 caveat).

Extension points:

- `water_occupancy` channels B/A are reserved; the solve is a sequence of filter passes addable through `filter_renderer.gd`.

Override rules:

- `flow_projected` gates the runtime slide per-river; provenance confidence gates protrusion-as-solid.

Shared systems must not hard-code:

- A single obstacle scene or collider style; protrusion thresholds are constants in `river_manager.gd`.

## Acceptance Tests

- Penetration gate: every occupied texel in a solid's proximity ring has `dot(flow_dir, into_solid) ≤ soft limit`; `|flow| ≈ 0` inside solids (`river_obstacle_projection_rebake_probe.gd`).
- WaterSystem flow inside obstacle influence zones matches the river's own baked flow within the gross-divergence guard (`system_flow_compare_probe.gd enforce=all`, ≤ 35°).
- Mechanism gate: forced-slide vs gated-slide system renders differ where the slide is exercised, and repeat renders are identical (`system_flow_projected_gate_probe.gd`).
- Seam regression passes on the projected field (`river_flowmap_seam_probe.gd`).
- Human: ducks do not drift into boundary-shear paths near obstacles; FLOW_ARROWS routes around rocks.

## Visual Validation Requirements

- FLOW_ARROWS debug view + normal surface view at the screenshot locations in `screenshots/`.
- Duck behavior near the obstacle rocks on `Demo_obstacle_flow_test.tscn`.

## Performance Requirements

- Bake: 40 Jacobi passes on the padded atlas (HDR float). No regression budget formally recorded here (R7 owns bake perf).
- Runtime: occupancy adds three texture reads to the surface shader; no per-frame allocation.

## Open Questions

- Should `system_flow.gdshader` also apply occupancy stilling / wake damping so duck-read magnitudes match the surface's runtime advection? (User decision; noted, not implemented.)

## Resolved Questions

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Is the 23–27° influence-zone angular divergence the unfixed slide re-bend (the "Defect-1 signature")? | No — it is sampling/quantization noise of the stilled low-magnitude ring (8-bit flow quantization scales as 1/\|v\|). A/B render measures the slide at 0 differing texels on Demo, 4.6k at mean 3.3° on the obstacle scene. The fix is correct but invisible to an angular threshold on saved maps. | 2026-06-12 | river-refactor R2; gate is `system_flow_projected_gate_probe.gd`, RT.3 `enforce=all` recalibrated to a 35° gross-divergence guard |
| Should terrain rise just above the waterline bake as solid? | No — `RIVER_OCCUPANCY_PROTRUSION_THRESHOLD` 0.5→0.9; shallow shelves where water renders are no longer walls | 2026-06-12 | implementation-plan §6.1 |
| Should physics-collider protrusion add solids under overhangs? | No — require provenance confidence ≥ 0.75; collider protrusion is overhang-blind and already covered by the collision map | 2026-06-12 | implementation-plan §6.2 |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-11 | Pressure projection of the spline-tangent baseline replaces local SDF steering | A locally-rotated field has no mechanism to guarantee non-penetration; projection guarantees `v·n=0` by construction |
| 2026-06-12 | Skip the runtime contextual slide when `flow_projected` | Re-bending a divergence-free field corrupts it (the WaterSystem duck-read path: Defect 1) |
| 2026-06-12 | Single-source the flow force/slide in `river_flow_common.gdshaderinc` (river-refactor R2/R3) | Stop the three shader copies from drifting again |
