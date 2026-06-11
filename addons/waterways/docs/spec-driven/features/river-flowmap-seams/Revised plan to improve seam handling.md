# Revised Plan to Improve Waterways Seam Handling

Date: 2026-06-11

## Relationship To The Existing Plan

This document sits alongside [Plan to improve waterways seam handling.md](Plan%20to%20improve%20waterways%20seam%20handling.md) and does not replace it. It keeps that plan's bake-side conclusions and most of its shader-side direction, but it changes the order of work and challenges one assumption the existing plan treats as fixed.

Read the existing plan first. This revision only records the deltas and the reasoning behind them.

## What Carries Over Unchanged

The following from the existing plan and the signature 23 work is correct and is not reopened here:

- The signature 23 bake-side fixes: floor-partition UV2 tile classification in `_get_uv2_world_sample()`, vertex-aligned grade/bend generation, and exact duplicated-edge-row synchronization for `flow_foam_noise`, `dist_pressure`, `obstacle_features`, and `bank_response_features`.
- Pillow seam fades stay cosmetic and off by default (`pillow_height_tile_seam_fade = 0.0`, `pillow_material_tile_seam_fade = 0.0`).
- WaterSystem stays a separate longer-term global track, not part of this seam fix.
- The logical UV2-neighbor sampler plus `i_occupied_steps` plumbing remains the correct general solution **for any river that must keep folding into a square atlas**.

## Core Disagreement: Compensating For The Fold vs. Removing It

The existing plan accepts the square UV2 atlas as fixed and builds compensation around it. The river is a 1D sequence of steps folded into a `calculate_side(steps)`-by-`calculate_side(steps)` grid (`side = ceil(sqrt(steps))`). That fold is the source of the seam class that still needs work.

Two join types result:

- **Same-column longitudinal joins.** Step `N` and step `N+1` are directly stacked in the same atlas column with no margin between them. They are naturally adjacent and in the correct order, so once the edge rows agree (signature 23 sync) they are continuous.
- **Row-wrap joins.** The last step of a column wraps to the top of the next column. These two steps are physically far apart in the atlas and only stay continuous because of `_add_uv2_column_continuation_margins()` and edge-band synchronization. This is the structurally fragile class.

The external techniques reference is explicit that the strongest spatial-seam defense is a *rectilinear* (straight) UV layout. Waterways folds for a real reason: a single-column strip for a long river becomes an impractically tall texture and can exceed the GPU max texture dimension and memory budget. But that reason does not apply to short and medium rivers.

### Change 1: Adaptive Atlas Aspect (Prefer Strip) — Treat As A Feasibility Spike

Add a task the existing plan omits: choose the **fewest columns** that fit the source resolution within the max texture dimension and memory budget, preferring a 1-column strip.

- For the two demo rivers (17 and 18 steps) a strip is feasible and removes every row-wrap join outright, at zero shader cost.
- Square packing becomes the fallback, used only when step count times tile size would exceed the dimension/memory budget.
- Knock-on benefit: with a strip, a longitudinal offset sample that runs off the end of a tile lands in the actual logical neighbor. The logical-neighbor helper then degenerates to a near no-op (clamp only at the very first and last step) for the common case. The shader complexity is then needed only for rivers long enough to force a fold.

**This is a medium architecture change, not a quick optimization. Scope it as a packing feasibility spike before committing.** The current code assumes a single square `uv2_sides` atlas in several places, all of which a non-square layout would have to touch:

- mesh UV2 generation (`generate_river_mesh`, `calculate_side`)
- margin padding (`add_margins`, `_add_uv2_column_continuation_margins`)
- tile rect lookup (`_uv2_tile_rect`)
- UV2 world sampling (`_get_uv2_world_sample`)
- shader UV remap (`river.gdshader`, `river_debug.gdshader`) using `i_uv2_sides` and the `safe_uv2_sides` derived `source_size`/`margin`
- WaterSystem flow rendering (`system_flow.gdshader`, `system_map_renderer.gd`)
- the seam and world-sample probes
- saved bake metadata and the source signature

It almost certainly needs explicit grid metadata — `uv2_columns`/`uv2_rows` or a `uv2_grid_size` vector — rather than the single scalar `i_uv2_sides`. The spike should decide whether that metadata change is small enough to adopt now or deferred behind the logical sampler.

This must be gated behind a source signature bump and validated with the existing seam and world-sample probes, since it changes packing.

Decision rule to record in the changelog: if adaptive aspect cannot be adopted (for example, because the grid-metadata change is too large, or a single packing must serve arbitrarily long rivers with a uniform layout), document that explicitly so the logical-neighbor helper is understood as the deliberate compensation rather than the default.

## Reordering: Falsify Before Building

The existing plan makes the logical UV2-neighbor sampler the first build step and puts human-visible review at step 9 of 10. The diagnosis so far is entirely probe-driven (delta `0` at edge depth `0`), and the audit itself notes that depth `1` and depth `2` rows legitimately differ and that material amplification and debug palettes can manufacture an apparent seam. The risk is building the whole sampler and then finding the visible seam was never offset sampling.

### Change 2: Front-Load Visual Classification And Ablation

Before building the logical sampler:

1. Capture the visible seam in `Demo.tscn` and `Demo_obstacle_flow_test.tscn` and classify it as one of: saved-data discontinuity, shader offset-sampling artifact, material amplification, mesh normal/tangent lighting flip, or debug-palette artifact.
2. Run a cheap ablation: temporarily disable `apply_contextual_flow_slide`, `bank_friction_edge_mask`, and pillow reach/smoothing, and observe whether the seam moves or disappears. This falsifies or confirms the offset-sampling hypothesis for almost no cost.
3. Only invest in the shared logical sampler if ablation confirms offset sampling is a visible contributor.

This restores the falsification discipline from `symptoms and initial suspects.md` ("smallest probe that falsifies a bucket before making code changes").

## Gaps The Existing Plan Does Not Cover

### Change 3: Verify Temporal Seams

The existing plan is entirely spatial and assumes Valve-style dual-phase blending with phase noise is already handled. The techniques reference spends roughly half its length on temporal seams (the flowmap reset "pulse"), and `textures/flow_offset_noise.png` exists in the repo. A uniform breathing band can read as a seam.

Add one verification task: confirm per-pixel phase noise is actually applied and that the dual-phase reset is not visibly pulsing across the surface. Do not assume.

### Change 4: Verify Mesh Normal/Tangent Continuity

The techniques reference flags recalculated tangents as a classic seam source, because lighting flips at joins, and normals amplify hard into visible lighting bands. The existing plan never checks this.

Add a check that `generate_river_mesh()` produces continuous normals and tangents across step joins (shared vs. duplicated vertices). This is cheap to verify and a common culprit when data is continuous but the surface still seams under lighting.

## Revised Implementation Order

The order is grouped so the cheap diagnostics and falsification run first, the architecture spike is a deliberate decision point, and only one of the two structural fixes (adaptive packing vs. logical sampler) gets built based on what the spike and ablation prove.

1. **Diagnose.** Visual capture and seam classification on both demo scenes, then cheap ablation of the offset-sampling helpers (`apply_contextual_flow_slide`, `bank_friction_edge_mask`, pillow reach/smoothing) to confirm or falsify the offset-sampling hypothesis.
2. **Cheap checks.** Mesh normal/tangent continuity across step joins, and temporal seam verification (dual-phase reset plus `flow_foam_noise.a` phase noise). Both are low cost and can each independently explain a visible seam even when saved-bake data is exact.
3. **Spike.** Adaptive atlas packing feasibility spike: assess the grid-metadata change (`uv2_columns`/`uv2_rows` or `uv2_grid_size`) and the square-atlas assumption sites listed in Change 1. Decision point.
4. **Build A — if the spike is small enough.** Implement strip-preferring packing with grid metadata, behind a source signature bump, and revalidate with the seam and world-sample probes. This removes row-wrap seams structurally for short/medium rivers.
5. **Build B — if packing is deferred, or for rivers that must fold.** Add `i_occupied_steps` plumbing and the logical UV2-neighbor helper, scoped to the offset paths the ablation proved visibly responsible.
6. Add offset-routing diagnostics and probes (same-column, row-wrap, first/last step, non-logical column edge).
7. Decide which expensive context masks to prebake (bank-friction edge, wake, eddy, pillow smoothed height), per the existing plan's section 5.
8. Run parser checks, `git diff --check`, seam probes, world-sample probes.
9. Final human-visible editor/runtime review against the new signature.

## Summary Of Deltas From The Existing Plan

| Topic | Existing plan | This revision |
| :---- | :---- | :---- |
| Bake-side signature 23 fixes | Keep | Keep |
| First move | Build logical sampler | Ablation plus visual classification first |
| Atlas layout | Square fold treated as fixed | Adaptive aspect, prefer strip; removes row-wrap seams structurally |
| Logical-neighbor sampler | Centerpiece | Fallback for rivers that must fold |
| Temporal seams | Assumed handled | Explicitly verified |
| Mesh normals/tangents | Not mentioned | Explicitly verified |
| Visible review | Step 9 of 10 | Front-loaded diagnostic, plus final review |

## Validation Checklist

- Existing signature 23 probes still pass: `RIVER_FLOWMAP_SEAM_PROBE_OK`, `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`.
- Ablation result recorded: does the visible seam depend on offset-sampling helpers.
- Mesh normals/tangents confirmed continuous across step joins.
- Temporal reset confirmed non-pulsing with phase noise active.
- If adaptive aspect adopted: row-wrap joins eliminated for the demo rivers and probes still pass under the new packing.
- If logical sampler still needed: offset-routing diagnostic confirms logical-neighbor behavior at same-column, row-wrap, and first/last step edges.
- Pillow seam fades remain off by default.
- Final visible review shows no straight tile bands in foam, normals, wakes, pillows, or height displacement.

## Source Notes

- [Plan to improve waterways seam handling.md](Plan%20to%20improve%20waterways%20seam%20handling.md)
- [Seam Handling Audit - 2026-06-11](audit/seam-handling-audit-2026-06-11.md)
- [Symptoms And Initial Suspects](symptoms%20and%20initial%20suspects.md)
- [Seamless River Flowmap Techniques](Seamless%20River%20Flowmap%20Techniques.md)
- `addons/waterways/water_helper_methods.gd` (`calculate_side`, `_get_uv2_world_sample`, `add_margins`, `_add_uv2_column_continuation_margins`, `_uv2_tile_rect`, `generate_river_mesh`)
- `addons/waterways/shaders/river.gdshader` (`boundary_context_at`, `apply_contextual_flow_slide`, `bank_friction_edge_mask`, pillow reach/seam helpers, UV2 remap)
