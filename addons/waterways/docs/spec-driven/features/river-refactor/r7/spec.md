# Spec: River Refactor R7 - Compute-First Bake Performance

## Current Truth

- Date: 2026-06-15
- Status: docs gate complete; full feature-folder template docs exist; official RenderingDevice research recorded; low-cost baseline fixture/probe slice complete; tolerance/self-compare, end-to-end format round-trip, RenderingDevice sync/readback stress probes, non-replacing production compute backend skeleton, first isolated non-replacing pressure-Jacobi solve/filter compute step, non-replacing production-shaped pressure-Jacobi stack, expanded projection diagnostic, pass-prefix diagnostic, probe-only `FRAGCOORD` sampler diagnostic, automated canonical acceptance, low-cost canonical artifact visual review, non-replacing cleanup/heartbeat/non-neutral flow-speed coverage, explicit selection plus guarded active abort/free/scene-close cleanup coverage, low-cost representative material/debug visual coverage, the guarded `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` promotion gate, report-only generated-output replacement staging, source signature v29, gated replacement branch, and refreshed production replacement validation/runtime smoke recorded; default production promotion remains open.
- R6 and R6.5 are closed under automated validation. R7 source signature policy is accepted as version 29 for the canonical compute replacement boundary; backend mode is not included in the source signature.
- Decision recorded: use the feature-roadmap Phase 5 RenderingDevice compute migration as the R7 performance path, skip the throwaway SubViewport-resident Jacobi ping-pong interim, and treat compute pressure feedback as the canonical solver target. Legacy CanvasItem output is compatibility evidence and fallback behavior, not the final correctness oracle.

## Required Read Order

Before R7 implementation prep or code changes, read:

1. R7 dashboard: `session-handoff.md`
2. R7 active checklist: `tasks.md`
3. R7 review/risk dashboard: `review.md`
4. R7 validation setup: `validation.md`
5. R7 implementation contract: `plan.md`
6. R7 RenderingDevice research: `research.md`
7. Parent dashboard: `../session-handoff.md`
8. Parent canonical roadmap/checklist: `../roadmap.md`
9. R6 validation evidence: `../r6/validation.md`
10. R6 handoff and residual caveats: `../r6/session-handoff.md`

## Decision

R7 will not implement the older SubViewport-resident ping-pong optimization. The track will instead fold bake-performance work into a compute-first plan based on Godot `RenderingDevice`.

R7 will stop chasing exact legacy CanvasItem sampler parity as the replacement target unless a later confirming diagnostic disproves the UV-artifact hypothesis. The 2026-06-15 probe-only `FRAGCOORD` diagnostic supports the hypothesis: the controlled y-band legacy UV diagnostic had 20 total X-dependent transitions, while the `FRAGCOORD` variant had 0. That evidence does not promote a simple tie rule; it just moves replacement acceptance to canonical compute plus visual/semantic validation.

Rationale:

- The feature roadmap already names a Phase 5 compute migration for the bake filter stack and ripple simulation.
- A SubViewport interim would optimize a pipeline that Phase 5 intends to replace.
- The known Defect-6 mechanism comes from multiple `UPDATE_ONCE` SubViewports in one frame rendering without dependency order. Avoiding that interim removes a fragile validation burden.
- The attempted full-Demo editor check saturated CPU/GPU enough to make editor interaction impractical, so the next performance phase should target real bake cost rather than temporary structure.

## Goals

- Keep bake intermediates GPU-resident for the solve/filter stack where practical.
- Reduce full-resolution CPU readback/re-upload round trips and awaited editor frames.
- Preserve `RiverManager` public API, signals, and inspector property-list shape unless a later R7 spec update explicitly approves public churn.
- Preserve generated bake behavior within documented precision tolerance while legacy parity remains the target. Once canonical compute is selected, accept intentional generated-output differences only through `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`.
- Keep RiverManager as the owner of final resource writing, material binding, `valid_flowmap`, bake-flag clearing, and completion signaling until a later accepted plan changes that boundary.

## Non-Goals

- No production compute replacement in the first baseline fixture/probe slice.
- No SubViewport-resident ping-pong interim.
- No silent bake signature drift; R7 deliberately bumps the source signature to 29 before any canonical compute replacement can be treated as current generated output.
- No silent visual quality, terrain, obstacle, or flow-generation algorithm change. Canonical compute may produce different output only after the docs, visual evidence, semantic evidence, fallback behavior, and bake signature/version decision call it out explicitly.
- No request to repeat the full `res://Demo.tscn` editor undo-delete workflow; future editor-stack closure needs a lower-cost fixture or targeted harness.
- No `R7_TOLERANCE_V2`; keep `R7_TOLERANCE_V1` unchanged as the legacy compatibility diagnostic gate.

## Acceptance Criteria

- The compute-first decision is recorded in parent and R7 docs.
- Full feature-folder docs exist: `spec.md`, `plan.md`, `research.md`, `validation.md`, `tasks.md`, `review.md`, and `session-handoff.md`.
- R7 must record research notes from current official Godot 4.6+ RenderingDevice documentation and any source detail that affects implementation before the affected implementation work lands.
- R7 must identify baseline scenes, wall-clock measurement method, texture compare tolerance, and editor-responsiveness checks in `validation.md` before compute replacement.
- Before any compute replacement patch, R7 must record a legacy baseline from a fixture that proves it exercised the expensive collision-support/projection path. A baseline that only proves "the bake finished" is not acceptable.
- The legacy baseline must prove the actual pass workload with a pass trace, not only metadata. At minimum it must count the collision-support filters, water occupancy, obstacle feature mask, flow divergence, all 40 Jacobi executions, projected-flow subtract, boundary tangency, final combines, diagnostics/postprocess, and RiverManager result handoff.
- If the first fixture keeps `flow_speeds` neutral, it must record `flow_speed_scaled=false` and treat `flow_speed_scale` as outside the baseline workload. Any R7 slice that migrates `flow_speed_scale` needs a separate non-neutral fixture or run before replacement. The low-cost non-neutral run is now recorded for the legacy path; compute migration of that path still needs replacement-specific gates if output changes.
- Any implementation must leave R6.5 public surface/property checks intact or update the acceptance contract before changing them.
- `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1` must be satisfied before accepting a compute path that intentionally differs from legacy CanvasItem output. It requires canonical integer texel-space pressure feedback rules, visual validation in named scenes/views, physics/semantic validation, continued legacy parity diagnostics, a fallback/selection flag, unchanged RiverManager ownership, and an explicit bake signature/version decision if generated textures change. The current five low-cost canonical artifacts are accepted as an intentional visible/output change, and low-cost non-replacing cleanup/heartbeat/non-neutral, explicit selection/guarded abort, representative material/debug visual coverage, the named replacement gate, report-only generated-output replacement staging, source signature v29, and refreshed production replacement validation/runtime smoke are recorded. Default production promotion remains open.
- `canonical_compute_replacing` must remain a fallback-to-legacy request until `R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1` is ready. That gate requires recorded canonical acceptance, representative visuals, selection/abort, cleanup/responsiveness, and RiverManager surface evidence; accepted generated-output replacement staging; accepted production replacement validation; source signature version 29 or backend mode included in the source signature; and an enabled replacement code path. With all evidence supplied, the gate is now ready and explicit `canonical_compute_replacing` may select compute; default production remains legacy.

## Open Questions For Implementation

- Which Godot texture formats best preserve the legacy solve values while avoiding unnecessary conversion cost? Planning default: probe `R16G16B16A16_SFLOAT` first, fall back to `R32G32B32A32_SFLOAT` only where measured tolerance requires it.
- Should diagnostics move to compute reductions in the first R7 implementation slice, or should R7 first isolate the Jacobi solve path? Planning default: isolate the solve/filter backend first; move diagnostics only after correctness and responsiveness gates exist.
- What is the smallest deterministic fixture that exercises the solve/filter stack without the full-Demo editor saturation seen during R6 manual validation? Planning default: a 64x64 projection fixture with a deliberately sized, layer-checked collider, not `curve_only`, because `curve_only` skips the Jacobi projection branch. The fixture must prove collision hits, no support fallback, water occupancy, obstacle features, projected flow, and the full Jacobi execution count.
- What synchronization primitive is the reliable RenderingDevice equivalent of the old awaited-render contract? Planning default: local RenderingDevice submit with delayed sync or async readback at final boundaries only, plus a dedicated stale-iteration stress probe before production use.
