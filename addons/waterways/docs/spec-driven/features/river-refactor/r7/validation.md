# Validation: River Refactor R7 - Compute-First Bake Performance

## Current Validation Snapshot

- Status: docs gate opened 2026-06-14; no R7 implementation validation has run.
- Decision validated by documentation review only: choose compute-first RenderingDevice migration and skip the SubViewport-resident interim.
- R6.5 remains the latest code validation: `R6_R65_SURFACE_PROPERTY_DIFF_OK`, `R6_R61F_PARSER_OK`, `R6_R62_CONSTANTS_SHADOW_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, and `git diff --check`.

## Required Read Order

Before R7 implementation prep or code changes, read:

1. Parent dashboard: `../session-handoff.md`
2. Parent canonical roadmap/checklist: `../roadmap.md`
3. R6 validation evidence: `../r6/validation.md`
4. R6 handoff and residual caveats: `../r6/session-handoff.md`
5. R7 spec/decision: `spec.md`
6. R7 implementation contract: `plan.md`

## Validation Matrix

| Concern | Check | Type | Expected | Status |
| --- | --- | --- | --- | --- |
| Docs gate | R7 `spec.md`, `plan.md`, and `validation.md` exist; parent docs record compute-first decision | Documentation | No R7 code starts before docs exist | Pass - docs exist and parent docs point to compute-first R7 implementation prep |
| Legacy baseline | Fixed fixture wall-clock, generated textures, dictionaries, API/signal/property surface | Godot console/windowed as needed | Baseline recorded before compute patch | Unrun |
| Compute correctness | Compare compute output to legacy output with documented tolerance | Godot rendered/compute run | Within accepted f16/format tolerance; no unexplained artifacts | Unrun |
| Synchronization | Dispatch/readback ordering stress test | Godot rendered/compute run | No stale readback or out-of-order iteration result | Unrun |
| Cleanup/abort | Mid-bake abort/free/scene-close coverage for compute resources | Targeted editor harness or low-cost fixture | No leaked GPU resources, stuck flags, or orphan work | Unrun |
| Performance | Wall-clock before/after on fixed scene/fixture | Timed Godot run | Improvement recorded as future regression budget | Unrun |
| Public surface | R6.5 surface/property guard | Headless/resource dump | RiverManager public API/signals/property list unchanged unless spec approves | Unrun for R7 |

## Recorded Results

Recorded result:

- Date: 2026-06-14
- Ran by: Agent (R7 docs gate)
- Godot version/renderer/device: n/a, documentation-only gate
- Command, scene, or workflow: Created R7 docs and recorded the compute-first decision: fold R7 into feature-roadmap Phase 5 RenderingDevice compute migration and skip the SubViewport-resident interim.
- Output or parser errors: n/a
- Visible result, if applicable: n/a
- Stable result marker: documentation-only; no code marker
- Pass/partial/fail: Pass for docs-gate creation.
- Notes or follow-up: Before implementation, research current official Godot RenderingDevice docs and add the exact baseline/fixture commands here.

## Artifact Hygiene

- Scratch project or temporary folder used: none for docs gate.
- Generated bakes/resources created: none.
- Files or folders that must be excluded from packaging: none beyond the standing `.codex-research/` rule.
- Files or folders safe to delete now: none from R7 docs gate.
