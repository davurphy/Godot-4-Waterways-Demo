# Spec: River Refactor R7 - Compute-First Bake Performance

## Current Truth

- Date: 2026-06-14
- Status: docs gate opened; no R7 implementation has started.
- R6 and R6.5 are closed under automated validation. Bake signature remains version 28.
- Decision recorded: use the feature-roadmap Phase 5 RenderingDevice compute migration as the R7 performance path, and skip the throwaway SubViewport-resident Jacobi ping-pong interim.

## Required Read Order

Before R7 implementation prep or code changes, read:

1. Parent dashboard: `../session-handoff.md`
2. Parent canonical roadmap/checklist: `../roadmap.md`
3. R6 validation evidence: `../r6/validation.md`
4. R6 handoff and residual caveats: `../r6/session-handoff.md`
5. R7 implementation contract: `plan.md`
6. R7 validation setup: `validation.md`

## Decision

R7 will not implement the older SubViewport-resident ping-pong optimization. The track will instead fold bake-performance work into a compute-first plan based on Godot `RenderingDevice`.

Rationale:

- The feature roadmap already names a Phase 5 compute migration for the bake filter stack and ripple simulation.
- A SubViewport interim would optimize a pipeline that Phase 5 intends to replace.
- The known Defect-6 mechanism comes from multiple `UPDATE_ONCE` SubViewports in one frame rendering without dependency order. Avoiding that interim removes a fragile validation burden.
- The attempted full-Demo editor check saturated CPU/GPU enough to make editor interaction impractical, so the next performance phase should target real bake cost rather than temporary structure.

## Goals

- Keep bake intermediates GPU-resident for the solve/filter stack where practical.
- Reduce full-resolution CPU readback/re-upload round trips and awaited editor frames.
- Preserve `RiverManager` public API, signals, and inspector property-list shape unless a later R7 spec update explicitly approves public churn.
- Preserve generated bake behavior within documented precision tolerance. Bit identity is not expected once legacy per-pass readback quantization is removed.
- Keep RiverManager as the owner of final resource writing, material binding, `valid_flowmap`, bake-flag clearing, and completion signaling until a later accepted plan changes that boundary.

## Non-Goals

- No R7 implementation in this docs-gate step.
- No SubViewport-resident ping-pong interim.
- No bake signature bump in this docs gate.
- No visual quality, terrain, obstacle, or flow-generation algorithm change unless a later R7 implementation spec calls it out.
- No request to repeat the full `res://Demo.tscn` editor undo-delete workflow; future editor-stack closure needs a lower-cost fixture or targeted harness.

## Acceptance Criteria

- The compute-first decision is recorded in parent and R7 docs.
- `spec.md`, `plan.md`, and `validation.md` exist before implementation starts.
- Before any code patch, R7 must add research notes from current official Godot 4.6+ RenderingDevice documentation and any source detail that affects implementation.
- Before any code patch, R7 must identify baseline scenes, wall-clock measurement method, texture compare tolerance, and editor-responsiveness checks in `validation.md`.
- Any implementation must leave R6.5 public surface/property checks intact or update the acceptance contract before changing them.

## Open Questions For Implementation

- Which Godot texture formats best preserve the legacy solve values while avoiding unnecessary conversion cost?
- Should diagnostics move to compute reductions in the first R7 implementation slice, or should R7 first isolate the Jacobi solve path?
- What is the smallest deterministic fixture that exercises the solve/filter stack without the full-Demo editor saturation seen during R6 manual validation?
- What synchronization primitive is the reliable RenderingDevice equivalent of the old awaited-render contract?
