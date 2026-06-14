# Plan: River Refactor R7 - Compute-First Bake Performance

## Current Truth

- R7 is in docs-gate state only.
- Decision: compute-first. Fold R7 into feature-roadmap Phase 5 RenderingDevice compute migration and skip the SubViewport-resident interim.
- Do not implement R7 code until the research and validation setup below are filled in.

## Required Read Order

Before R7 implementation prep or code changes, read:

1. Parent dashboard: `../session-handoff.md`
2. Parent canonical roadmap/checklist: `../roadmap.md`
3. R6 validation evidence: `../r6/validation.md`
4. R6 handoff and residual caveats: `../r6/session-handoff.md`
5. R7 spec/decision: `spec.md`
6. R7 validation setup: `validation.md`

## Implementation Contract

1. Research current official Godot 4.6+ RenderingDevice documentation before patching code.
2. Record any implementation-relevant documentation findings in this folder's `research.md` if it is created, or in the parent `research.md`/citations index if shared.
3. Establish baseline measurements before replacing any path:
   - fixed scene or fixture path
   - bake size and relevant RiverManager settings
   - wall-clock measurement method
   - generated-texture compare outputs
   - editor responsiveness observation method
4. Preserve the R6 module boundary:
   - RiverManager owns public API, resource saving, material binding, validity flags, and completion signaling.
   - RiverFlowmapBaker owns bake orchestration.
   - A future compute backend may own GPU resources and dispatch details behind the baker.
5. Keep signature version 28 unless an actual bake-data contract change is made and documented.

## Chosen Architecture Direction

R7 should introduce a compute backend for the bake solve/filter stack rather than extending the current Viewport ping-pong approach.

Candidate ownership shape for later implementation:

- `river_flowmap_baker.gd`: selects and coordinates the backend, keeps existing result handoff semantics.
- Future compute backend script: owns RenderingDevice setup, GPU textures/buffers, dispatches, synchronization, readback, and cleanup.
- `river_bake_constants.gd`: remains the source of reviewable metadata/signature/settings rows.
- `filter_renderer.gd`: remains the legacy canvas-item path until compute coverage can replace or bypass it safely.

## Future Implementation Slices

Do not start these until the docs gate is complete and research is recorded.

1. Add low-cost deterministic bake-performance fixture and wall-clock probe.
2. Baseline legacy path output and timing with current R6.5 code.
3. Prototype compute resource setup without changing generated output.
4. Port one isolated solve/filter step and compare against legacy output with tolerance.
5. Expand to the full Jacobi solve/filter stack.
6. Move diagnostics that currently scan pixels on CPU to GPU reductions or opt-in debug-only actions.
7. Add editor responsiveness and cleanup/abort coverage for compute resources.

## Validation Strategy

- Generated texture comparison uses tolerance, not byte identity, because the compute path intentionally avoids legacy per-pass CPU readback quantization.
- Canonical metadata/signature/settings dictionaries should stay unchanged unless the bake-data contract changes.
- RiverManager public API, signal list, and inspector property-list checks remain part of the guard.
- Performance validation records wall-clock before/after and keeps that number as the regression budget.
- Editor validation uses a lower-cost fixture or targeted harness, not the full-Demo undo-delete workflow that was infeasible during R6.

## Risks

- Compute format mismatch can create subtle f16/f32 or normalized-texture differences.
- GPU synchronization mistakes can replace the old Defect-6 viewport-ordering hazard with a compute-dispatch/readback hazard.
- Backend cleanup must handle mid-bake aborts without leaked GPU resources or stuck bake flags.
- Moving diagnostics can break probes if marker text or report fields disappear without coordinated validation updates.
