# Review: Occupancy-Masked, Pressure-Projected River Flow

## Review Date

2026-06-12 (constitution rule-12 backfill, river-refactor R8.3)

## Scope Reviewed

- Bake pipeline: `water_occupancy` generation and the pressure-projection solve in `river_manager.gd` `_generate_flowmap` and `filter_renderer.gd` (`apply_proximity`, `apply_occupancy_pack`, `apply_flow_divergence`, `apply_flow_pressure_jacobi`, `apply_flow_gradient_subtract`, `apply_flow_boundary_tangency`).
- Runtime shaders: `river.gdshader`, `river_debug.gdshader`, `system_renders/system_flow.gdshader` (occupancy clip/still/wake + `i_flow_projected` slide gate), now via `river_flow_common.gdshaderinc`.
- Persistence: `RiverBakeData.water_occupancy`, `WaterSystemBakeData.system_flow_map_version`, `source_metadata.flow_projected` / `obstacle_avoidance_algorithm`.
- Probes in this folder and the mechanism gates in `addons/waterways/probes/`.
- `addons/waterways/docs/research/river-research-citations.md` — industry references (Portal 2, Far Cry 5, GPU Gems ch. 38, Crest) shaped the projection design.

## Current Truth

- Overall review status: Pass.
- Blocking issues remaining: none.
- Important issues remaining: none for the landed feature. One refactor follow-up: the two flow-arrow probes in this folder (`flow_arrow_direction_outlier_probe.gd`, `flow_arrow_neutral_cells_probe.gd`) are divergent copies of the shared `probes/` versions — river-refactor R8.4 consolidates them.
- Last validation relied on: 2026-06-12 — mechanism gates green on regenerated v1 maps + user editor round (`validation.md`).
- Next action: none here; track refactor follow-ups in `../river-refactor/`.
- Historical detail starts at: `implementation-plan.md` §6 (tuning).

## Findings

### Blocking

- None.

### Important

- The feature-folder flow-arrow probes diverged from the shared `probes/` versions (two arg-parsing schemes). Tracked by river-refactor R8.4 — not a feature defect, a hygiene item.

### Minor

- The system map carries full-force magnitudes in the stilled ring (no occupancy stilling / wake damping in `system_flow.gdshader`), so duck-read magnitudes can exceed the surface's runtime-advected speed near solids. Direction is correct; this is a deliberate open user decision, not a bug.

## Premise Review

- Was the original premise correct? Partially. The non-penetration goal and the projection mechanism were correct and landed cleanly. The one premise correction came during river-refactor R2: the recorded numeric "Defect-1 signature" (influence p90 ~25–29°) was **misattributed** to the unfixed slide. A/B rendering (slide gated vs forced) shows the slide contributes 0 differing texels on Demo and 4.6k at mean 3.3° on the obstacle scene; the angular floor is sampling/quantization noise of the stilled low-magnitude ring.
- Did evidence suggest an overlooked data/context fact? Yes — that a saved-map angular threshold cannot see a correct-but-low-magnitude fix. Raised and resolved by replacing the numeric gate with the A/B mechanism gate (`system_flow_projected_gate_probe.gd`) and recalibrating RT.3 `enforce=all` to a 35° gross-divergence guard.
- Final outcome: a validation/gate-design fix plus a docs clarification; the code fix itself was correct.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| No penetration into solids | Pass | `river_obstacle_projection_rebake_probe.gd` fraction gates green |
| No interior / under-overhang water | Pass | occupancy clip + provenance-gated protrusion (implementation-plan §6.2); user editor round |
| Lee sides slowed | Pass | wake damping + speed ramp; user editor round |
| Ducks read corrected flow | Pass | `system_flow_compare_probe.gd enforce=all` + `system_flow_projected_gate_probe.gd`; user duck watch |
| Old bakes degrade to identity | Pass | `water_occupancy` optional; `hint_default_black`; `has_required_textures()` unchanged |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes (HDR float targets, vertex `textureLod`).
- Editor/runtime boundary preserved: Yes (bake → data → shader/buoyancy).
- Bake data and generated resources explicit: Yes (`water_occupancy`, `flow_projected`, `system_flow_map_version`, solve params in signature).
- Legacy Godot 3 behavior used only as reference: Not applicable.
- Extension points preserved: Yes (occupancy B/A reserved; solve is a pass sequence).
- Godot-native features preferred where practical: Yes (SubViewport ping-pong filters, existing atlas-clamp include).
- Bespoke systems justified: Yes (pressure projection is the minimum defensible non-penetration baker; implementation-plan §2).
- Comments explain non-obvious intent: Yes (the Defect-1 fix and projection rationale are commented at the shader and pipeline sites).
- Feature/architecture docs updated: Yes — `docs/architecture-and-features.md` (Obstacle Handling, `water_occupancy`), `../river-future/Data Contract.md`, and this backfill (river-refactor R8).

## Validation Results

- Automated: mechanism + penetration gates green on regenerated v1 maps (`validation.md` matrix). Headless inspects are diagnostic-only; rebake/render gates are windowed.
- Human-assisted: 2026-06-12 user editor round — both demo scenes, debug views, and duck behavior near obstacles confirmed (Godot 4.6.3 windowed, Windows 11).
- Shader: 3-renderer compile smoke clean (Forward+/Mobile/Compatibility) via river-refactor R3.
- Editor: bake controls and debug views behaved.
- Visual: arrows route around rocks; no interior water; lee sides slow.
- Bake output: `water_occupancy` present; `flow_projected=true`; projected `flow_foam_noise.rg`.
- Runtime: ducks read corrected flow through the WaterSystem map.
- Performance: not formally budgeted here (bake perf is river-refactor R7).
- Manual: see `validation.md` checklist.

## Documentation Consistency Check

- [x] Closed tasks checked off — this folder is a backfill; live tasks are in `../river-refactor/`.
- [x] No stale "open follow-up" language for completed work.
- [x] Resolved open questions live in `spec.md` Resolved Questions.
- [x] `implementation-plan.md` annotated where as-designed specifics drifted from what landed.
- [x] `validation.md` snapshot/matrix match the recorded results and the river-refactor R2/R3 records.
- [x] Latest handoff (`../river-refactor/session-handoff.md`) points to the true next action.
- [x] Shared works-cited index checked.

## Follow-Up Tasks

- [ ] (river-refactor R8.4) Consolidate the two feature-folder flow-arrow probes onto the shared `probes/` versions; unify arg parsing.
- [ ] (open user decision) Decide whether `system_flow.gdshader` should apply occupancy stilling / wake damping for duck-read magnitude parity.

## Decision Updates

- The numeric influence-zone gate was replaced by the A/B mechanism gate during river-refactor R2 (see Premise Review). No spec behavior changed; only the proof method.
