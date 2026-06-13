# Implementation Plan: Occupancy-Masked, Pressure-Projected River Flow

**Status:** Implemented + tuned (branch `river-obstacle-flow-constraints`); post-landing tuning in §6
**Date:** 2026-06-11 (plan), 2026-06-12 (tuning)
**Related:** `River Flow Map Displacement Research.md` (same folder), `screenshots/` (problem evidence), `../river-future/Crest Reuse and Portability Feasibility.md`

> **Historical annotation (2026-06-12, river-refactor R8).** This is the as-designed plan; it is preserved as a record, not current truth. Where it describes the prior `RIVER_OBSTACLE_AVOIDANCE_*` / SDF-steering mechanism (§1 symptom table, §2, §3.2–3.3) it is documenting the state being *replaced* — accurate as history. Specifics that drifted before/after landing, with current truth in `docs/architecture-and-features.md` and `../river-future/Data Contract.md`:
> - Jacobi schedule landed as `RIVER_FLOW_PROJECTION_STRIDES = [32, 16, 8, 4, 2, 1, 1, 1]` × 5 = **40 passes** (this plan estimated `[48, 24, 12, 6, 3, 1, 1]` ≈ 35).
> - `obstacle_avoidance_algorithm` landed as `"pressure_projection_free_slip_jacobi_with_normal_to_flow_blur_fallback"` (this plan wrote the un-suffixed form).
> - The legacy SDF steering filter (`apply_obstacle_avoidance_flow`, `obstacle_avoidance_flow_filter.gdshader`, the ten `RIVER_OBSTACLE_AVOIDANCE_*` constants) did **not** remain in the codebase as §3.2 expected — it was deleted entirely in river-refactor R1.1. The fallback is now `normal_to_flow` + blur.

## 1. Problem statement (from screenshot review, 2026-06-11)

Four confirmed failure modes, each traced to a structural cause:

| Symptom | Root cause |
|---|---|
| Flow arrows pass straight through obstacles and bank protrusions | Baked steering only fires in a narrow oblique band: facing weight zeroes the sides, the stagnation-line fade zeroes head-on approaches, and `RIVER_OBSTACLE_AVOIDANCE_MIN_DOWNSTREAM_ALIGNMENT = 0.65` caps deflection at ~49° |
| Full-speed water "rushes out" of obstacle lee sides | Wake/eddy masks are cosmetic only — `contextual_flow_force()` never reads them; worse, `dist_pressure.g` (collision proximity) × `flow_pressure` *boosts* speed near rocks |
| Water renders and animates inside boulders/cliffs/crevices | No occupancy concept survives the bake; the crisp collision interior is only ever consumed dilated+blurred; fragment `ALPHA` is depth-fade only |
| Flow crosses banks at bends | Baseline field is the spline tangent, uniform across width; banks only apply drag/gates, never redirection; hard-boundary redirection requires protrusion detection that tall sheer banks can miss |

The current method is **local rotation with artifact-suppression gates**; each gate re-opens a penetration hole exactly where obstacle response matters most. A locally-rotated field has no mechanism to guarantee non-penetration.

## 2. Industry validation (research summary)

- **Portal 2** (Vlachos, SIGGRAPH 2010): flow maps baked from a 2D fluid sim in Houdini with obstacles as colliders.
- **Far Cry 5** (Grujic & Cutocheras, GDC 2018): spline rivers, flow baked from an offline incompressible solve with banks/rocks as boundary conditions.
- **Flowmap Generator** (Unity tool): 2D Eulerian solve (advect + pressure projection, solid cells stamped) baked to texture.
- **Houdini Labs Flowmap Obstacle**: SDF-tangent steering — the documented *cheap tier*, equivalent to what waterways does today.
- **GPU Gems ch. 38** (Harris): canonical Jacobi pressure projection with boundary conditions.
- **Crest** (verified earlier in this feature): clip-surface texture + `clip()` is the standard for "no water inside objects"; flow stored unnormalized so magnitude carries wake information.
- Refinements adopted from research: **free-slip** solid boundaries (kill only the normal velocity component; no-slip drags too wide a band at bake resolutions) and **unnormalized velocity storage**.

Conclusion: a one-shot pressure projection of the spline-tangent baseline is the *minimum defensible* baker; it guarantees `v·n = 0` at solids (no penetration), produces stagnation in front, splitting around, and constriction speed-up by construction. Lee-side wake slowdown does not come from a one-shot projection (it is symmetric); we cover it with wake-mask speed damping.

## 3. Design

### 3.1 New bake product: `water_occupancy` texture (padded UV2 atlas, like all others)

- **R — solid mask** (1 = inside obstacle / protruding terrain, 0 = water). Crisp. Source: binary collision map ∪ terrain-contact protrusion ≥ `RIVER_OCCUPANCY_PROTRUSION_THRESHOLD` (0.9, see §6) **with source confidence `terrain_contact.a ≥ RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN` (0.75)** — only heightfield-sourced protrusion may add solids; physics-collider protrusion is overhang-blind and is covered by the collision map instead (see §6). Carried through `add_margins` for column continuation.
- **G — solid proximity** (1 at solid surface → 0 at ≥ ramp radius). From the existing dilate pass 1+2 distance field (new `apply_proximity` renderer method) at `RIVER_OCCUPANCY_RAMP_TILES` radius.
- B unused (0), A = 1.
- Neutral/absent texture (`hint_default_black`) ⇒ no solids ⇒ all new shader behavior is identity. Old bakes keep working.

Collision interior detection hardening (`generate_collisionmap`): enable `hit_from_inside` on the up-ray; a zero-normal hit (ray started inside a collider) marks the texel solid. Keeps the existing overhang exemption (underside hit with real normal ⇒ not an obstacle).

### 3.2 Bake-time pressure projection (replaces SDF steering for the obstacle-avoidance behavior)

Runs on the margin-padded atlas via the existing `filter_renderer` SubViewport ping-pong, with `use_hdr_2d = true` during solve passes (float16 targets; 8-bit would quantize pressure gradients). Atlas topology is respected the same way existing filters do it: x-neighbor reads use `atlas_column_clamp` (column band = wall), y-neighbor reads are naturally continuous within columns and read continuation content in the top/bottom margins; cross-column residue is handled by the existing `synchronize_uv2_logical_edge_bands`.

New filter shaders (`shaders/filters/`):
1. `flow_divergence_pass.gdshader` — central-difference divergence of the baseline velocity; free-slip: a solid neighbor contributes the center's velocity with the boundary-normal component removed (approximated as zero normal flux). Output offset-encoded around 0.5.
2. `flow_pressure_jacobi_pass.gdshader` — one Jacobi iteration `p' = (Σ p_neighbors − div) / 4`; solid or out-of-band neighbor ⇒ Neumann (use center p). Uniform `stride` (texels) enables a coarse-to-fine schedule: strides `[48, 24, 12, 6, 3, 1, 1]` × `RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE = 5` ≈ 35 passes (~70 frames at bake time) — long wavelengths converge at large stride, boundaries clean up at stride 1.
3. `flow_gradient_subtract_pass.gdshader` — `v' = v − ∇p` (central difference, Neumann across solids), re-zero `v` inside solids, repack RG.
4. `flow_boundary_tangency_pass.gdshader` — safety net independent of solve convergence: within the proximity ring, remove any remaining velocity component pointing *into* the solid (free-slip projection onto the boundary tangent using the proximity-field gradient). Hard local guarantee of non-penetration.

Pipeline placement in `_generate_flowmap()` (the `_uses_obstacle_avoidance_generation()` branch): keep `apply_obstacle_feature_mask` (pillow/wake/eddy shading data, unchanged), **replace** `apply_obstacle_avoidance_flow` + post-blur with: solid prep → proximity → divergence → Jacobi schedule → gradient subtract → tangency. No post-blur (the projected field is smooth; blurring would re-introduce penetration). The legacy steering path remains in the codebase for non-default behaviors / fallback. Bake metadata: `obstacle_avoidance_algorithm = "pressure_projection_free_slip_jacobi"` plus solve parameters; `flow_projected = true` flag consumed at runtime.

### 3.3 Runtime shader consumption (`river.gdshader`, mirrored in `river_debug.gdshader`)

New uniforms: `i_water_occupancy` (hint_default_black), `i_flow_projected` (bool), `flow_wake_damping` (0–1, default ≈ 0.6, auto-categorized under Flow in the inspector).

1. **Clip**: `ALPHA *= 1 − smoothstep(start, full, occupancy.r)` — water fades out inside solids (fixes crevice/interior rendering). Pillow vertex displacement also suppressed by solid mask.
2. **Stilling + speed ramp**: `flow *= smoothstep(0, OCCUPANCY_SPEED_RAMP_FULL, 1 − occupancy.g)` openness ramp — advection speed is 0 at the solid surface and recovers over the proximity radius (fixes "rushing" at boundaries and stills any residual interior water). `OCCUPANCY_SPEED_RAMP_FULL = 0.45` after tuning (see §6): full speed returns by mid-ring so the stilled band hugs the solid.
3. **Wake damping**: `flow_force *= 1 − flow_wake_damping * wake_seed_mask` — the lee side finally *moves slowly*, matching the wake/eddy shading that already exists.
4. **Disable the runtime slide for projected fields**: `apply_contextual_flow_slide` is skipped when `i_flow_projected` — re-bending a divergence-free field would corrupt it. Legacy bakes (flag false) keep the slide.

### 3.4 Persistence

`RiverBakeData`: new `@export var water_occupancy: Texture2D` (optional — `has_required_textures()` unchanged), channel metadata entry, trailing optional parameter on `set_from_bake`. `river_manager.gd`: property + `set_materials("i_water_occupancy", …)` + `i_flow_projected` in both `_generate_flowmap` and `_apply_bake_data` (flag read from `source_metadata`).

## 4. Validation

Probe pattern: `<godot_console> --path <project root> --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/<probe>.gd` (NOT headless — bakes need viewport readback). Godot 4.6.3 console at `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`.

1. **Rebake** `Demo.tscn` and `Demo_obstacle_flow_test.tscn` (reuse `river_flowmap_seam_rebake_demo_bakes.gd` pattern).
2. **New penetration probe**: for every occupied texel within the proximity ring of a solid, decode flow and assert `dot(flow_dir, normalize(∇solid_toward_solid)) ≤ threshold` (no inflow into solids); assert `|flow| ≈ 0` inside solids; report worst offenders with tile coordinates.
3. **Seam regression**: re-run the existing flowmap seam probe expectations on the projected field.
4. Visual: user verifies the screenshot locations (arrows view + normal view).

Probes in `probes/` (status 2026-06-12):

- `river_obstacle_projection_rebake_probe.gd` — rebakes both demo scenes, runs the penetration gates, saves the river bakes on success. Gate constants mirror the runtime shader's stilling ramp; recalibrations are documented inline (see §6).
- `river_occupancy_flow_inspect_probe.gd` — diagnostic only (headless OK): loads the saved river bakes, reports solid coverage, protrusion attribution, speckle counts, proximity-binned `|flow|`, and dumps occupancy/flow PNGs to `probes/out/`.
- `water_system_rebake_probe.gd` — regenerates the `Demo.tscn` WaterSystem combined map and saves it explicitly via `ResourceSaver`. **Caveat**: `generate_system_maps`' internal save (`save_water_system_bake_data`) is editor-only and silently no-ops under `--script` runs — always check the printed `save_error`/file mtime, never trust the in-memory result alone.
- `water_system_flow_inspect_probe.gd` — diagnostic only (headless OK): decodes the system map's flow channels (what `buoyant_manager.gd` ducks sample via `get_water_flow`), reports dead-zone fraction, dumps a magnitude PNG.
- Visual capture / arrow-cell diagnosis probes added later during tuning: see §6.5.

## 5. Out of scope (deliberate)

- Advection iterations in the solve (real asymmetric wakes/eddy recirculation) — future enhancement; wake damping covers the visual need.
- Flow-advected height displacement, finite-difference normals, custom AABB (tracked by the displacement research doc).
- Changing the `dist_pressure.g` force boost default — wake damping + speed ramp counteract it where it was harmful.

## 6. Post-implementation tuning (2026-06-12)

User testing after the initial landing surfaced two over-aggression problems; both were diagnosed by probing the baked textures rather than the shaders (the projected flow field itself was healthy — proximity-ring `|flow|` ≈ 0.22–0.25, above the 0.25 baseline in constrictions, as the physics predicts).

### 6.1 Over-wide dead zones / splotchy flow arrows

**Symptom**: ducks stalled beside rocks; arrows debug view splotchy. **Root cause**: with `RIVER_OCCUPANCY_PROTRUSION_THRESHOLD = 0.5`, terrain only ~0.115 m above the water surface (rise mask: fade 0.03 m → full 0.20 m) baked as solid — 83–87 % of all solid texels came from this, not from collision. Shallow shelves and bank margins where water renders (and ducks float) became walls with zero baked flow, and the 0.12-tile proximity ring around them stilled ~45 % of the river.

**Changes**:
- `RIVER_OCCUPANCY_PROTRUSION_THRESHOLD` 0.5 → **0.9** (`river_manager.gd`).
- `OCCUPANCY_SPEED_RAMP_FULL` 0.85 → **0.45** (`river.gdshader`, `river_debug.gdshader`, probe mirror) — advection recovers full speed by mid-ring.
- Occupancy/projection constants added to `get_bake_source_signature()`; signature version 24 → **25**.

### 6.2 Missing water under overhangs

**Symptom**: rocks wider above the waterline than at it ("overhangs") left holes where no water rendered at their base (four+ locations, see `screenshots/overhang water missing*.png`). **Root cause**: the terrain-contact protrusion sampler raycasts down from 0.75 m above the water surface, so under an overhang it hits the boulder's top and reads "terrain above water" — even though the water surface is open air. The occupancy union consumed that protrusion with no facing awareness, unlike `generate_collisionmap` (whose up-ray exempts underside hits).

**Change**: `create_solid_occupancy_source_image` now requires `terrain_contact.a` (source confidence) ≥ `RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN = 0.75` for protrusion to mark a solid. Heightfield-sourced protrusion (confidence 1.0) still counts — heightfields cannot overhang. Physics-collider protrusion (confidence 0.5) is dropped: it is overhang-blind, and those same colliders are already baked through the collision map's facing-aware exemption (both passes raycast the same `baking_raycast_layers`).

### 6.3 Probe gate recalibration

- `EFFECTIVE_INTO_SOLID_SOFT_LIMIT` 0.03 → 0.07: the limit models rendered penetration (`raw × stilling factor`); the softer 0.45 ramp renders ~2.3× more residual motion from the same raw field.
- `MAX_ALLOWANCE_EXCESS` 0.10 → 0.25: single-texel backstop. Shrinking the solids exposed thin/small blobs whose 2-texel proximity gradients are degenerate at concave junctions; an extra tangency pass left the worst texel byte-identical (probe-vs-bake gradient disagreement, not removable penetration). Field-wide health stays enforced by the fraction gates (`ALLOWANCE_EXCESS_MAX_FRACTION` 0.5 %, `SOFT_LIMIT_MAX_FRACTION` 1 %), which pass at 0.13–0.21 % / 0.45–0.54 %.

### 6.4 Dark "neutral" arrow squares beside rocks (debug-view artifact)

**Symptom**: in the FLOW_ARROWS debug view, dark squares beside obstacles where water visibly flows. **Diagnosis** (`flow_arrow_neutral_cells_probe.gd` classifies every neutral arrow cell from the saved bake): in the live river area essentially all neutral cells had their *center texel inside the baked solid mask* (collision-map rock footprints or bank protrusion) — not stilled open water, not dead baked flow. An arrow cell spans ~1/8 of the river width but samples a single texel at its center, so a thin solid rim (a convex-hull collider bulges slightly wider than the visible rock at the waterline) paints a whole cell dark while most of the cell flows. Note ducks can never occupy those texels — they collide with the same shapes the rim was baked from.

**Change** (`river_debug.gdshader` FLOW_ARROWS branch): when the center sample is neutral, probe four sub-cell offsets (±0.3 cell) and represent the cell with the strongest open-water flow found. Cells fully inside solids stay dark. Debug-only cost (4 extra fetches in one branch).

**Caveat**: per-rock dead rims wider than the visible rock come from oversized collision shapes (e.g., convex hulls around overhanging boulders claim the under-overhang water column; physics rays cannot distinguish that volume from rock interior). If a specific rock's rim is too fat, give it a tighter/trimesh collider for baking.

**Follow-up — stray direction arrows beside walls**: a handful of wall-adjacent arrows pointed ~60–90° off their neighbors. `flow_arrow_direction_outlier_probe.gd` showed all of them are texels where the solve legitimately decelerated flow to near-zero (|flow| 0.02–0.13 vs ~0.23 channel norm) — the residual *direction* is numerically meaningless, but the view drew a full-confidence glyph for anything above 0.02. Fix (`river_debug.gdshader`): `FLOW_ARROW_NEAR_NEUTRAL_THRESHOLD` 0.02 → 0.05, and glyph size now scales with flow speed (`FLOW_ARROW_FULL_SPEED_REFERENCE = 0.25`, min 45 % size) so slow water reads as a visibly small arrow instead of a confident wrong-looking one. Probe mirrors updated.

### 6.5 Capture / diagnosis probes added during tuning

- `river_debug_view_capture_probe.gd` — loads `Demo.tscn`, switches the river to a debug view (`DEBUG_VIEW_MODE`, default FLOW_ARROWS), flies a camera along the spline and saves screenshots to `probes/out/` for visual review without the editor.
- `flow_arrow_neutral_cells_probe.gd` — classifies every neutral arrow cell by root cause (solid-collision / solid-protrusion / stilled-ring / dead-flow) and writes a color-coded overlay PNG.
- `flow_arrow_direction_outlier_probe.gd` — mirrors the displayed-arrow logic (center sample + sub-cell fallback) and flags cells whose direction deviates > 60° from flowing neighbor cells, reporting magnitude and whether the fallback picked the sample.

### 6.6 Measured results (original → final, fresh bakes saved)

| Metric | Before | After |
|---|---|---|
| Solid mask, main demo (% of content) | 21.0 % | 13.5 % |
| Solid mask, obstacle test | 22.3 % | 14.9 % |
| Proximity ring coverage, main demo | 44.8 % | 36.3 % |
| WaterSystem map dead fraction (duck-facing, `\|flow\|<0.05`) | 29.3 % | 19.6 % |
| WaterSystem map mean `\|flow\|` | 0.229 | 0.246 |
| Mean `\|flow\|` inside solids | 0.0055 | 0.0055 (unchanged, gates pass) |

## 7. Subsequent signature bumps (roadmap work, 2026-06-12)

Later same-branch work bumped the bake source signature past this plan's v25; flow content of neutral bakes is unchanged and all §4 gates re-pass at the same values. See `../river-future/Roadmap.md` for details.

- **v26** — smoothstep-eased width interpolation + tight-bend edge overlap resolution (mesh outputs change slightly for the same curve).
- **v27** — per-point `flow_speeds` (each signature point entry gains `flow_speed`; new optional post-projection magnitude scale pass, identity when all factors are neutral).
