# Research: River Refactor R6 - river_manager.gd Decomposition

## Purpose

This research file records the source context needed to execute R6 safely. R6 is mostly an internal decomposition, so the primary evidence is local: the R6 plan, parent river-refactor docs, current `river_manager.gd`, existing probes, and R5 validation results.

For implementation work that depends on Godot behavior, search current official Godot documentation and API references before patching. Prefer official Godot docs first for async nodes, `RefCounted`, `SubViewport`, `ImageTexture`, `ShaderMaterial`, scene-tree lifetime, resource saving, and editor/runtime boundaries. Add any source that affects implementation here or in the shared citations index.

Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`.

## Current Research Outcome

- Status: Needed for implementation details; local decomposition direction is accepted by `plan.md`.
- Recommendation: Preserve current behavior by moving code behind explicit config/result/callback boundaries, not by changing algorithms or freezing state at bake start.
- Confidence: High for the local architecture; medium until awaited helper dependencies and source timing are inventoried directly from current code.
- Biggest unknown that remains: the exact narrow context needed to replace `WaterHelperMethods.generate_collisionmap()` and `generate_terrain_contact_feature_map()` RiverManager reach-back.
- Decision or plan section this research unlocked: `spec.md` source timing contract and `validation.md` no-reach-back checklist.

## Questions

- What explicit dependencies does the baker need for frame awaits, cancellation/liveness, collision reset, terrain/collision queries, warnings, prints, progress, and renderer ownership?
- Which current `_generate_flowmap()` awaits are visible directly, and which are hidden inside helper loops?
- Which fields are read at bake start, during source generation, during filter passes, during final dictionary assembly, and during result application?
- Can existing ripple material probes cover R6.3 owner-conflict/tree-exit semantics, or is a focused probe required first?
- Which validation wrapper callers consume `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` marker text?
- Would a typed `RefCounted` data object reduce key drift more than dictionaries for `BakeConfig`, `BakeResult`, and `BakeAbort`?

## Flow-Map and Water Tool Patterns

R6 does not introduce a new flow-map algorithm. The relevant pattern is architectural:

- keep public node state and editor-facing APIs on RiverManager
- move render/bake orchestration into a helper with explicit dependencies
- keep generated texture content and channel packing byte-identical
- centralize constant rows without implying automatic signature coverage
- keep validation fixtures and hash gates close to the moved behavior

No new external water/flow-map research has informed R6 yet.

## Godot 4.6+ Findings

Implementation research still needed before patching:

- `RefCounted` lifetime and async method patterns for long-running coordinators.
- Node and scene-tree lifetime behavior around `tree_exiting`, freed nodes, and awaited coroutines.
- `SubViewport` update/readback behavior and cleanup expectations for temporary render nodes.
- `ImageTexture.create_from_image()` timing and resource ownership expectations.
- `ShaderMaterial` parameter get/set behavior for duplicated visible/debug materials.
- `ResourceSaver` behavior for final bake resource saving and failure reporting.
- Editor/runtime guards for helper scripts that should not depend on editor-only singleton state.

Record official documentation links here when those findings are checked.

## Legacy Waterways Reference

- Relevant legacy files: not yet required for R6.
- Behavior to preserve: current Godot 4 R5 behavior, not Godot 3 behavior.
- Behavior to change: module ownership only.
- Obsolete APIs to avoid: any Godot 3-era APIs already removed by prior phases.
- Risks discovered in audit: `river_manager.gd` remains too large and owns bake orchestration, metadata assembly, runtime material ownership, and editor validation harnesses.
- What belongs in active Godot 4.6+ code: explicit helper boundaries, current shader/material APIs, current bake data contract.
- What should remain legacy-only: any Godot 3 synchronization-by-hand pattern or obsolete helper API.

## Options

### Option A: Preserve Mixed Timing and Extract Behind Explicit Dependencies

- Benefits: most behavior-preserving; minimizes mid-bake edit surprises; aligns with R6 plan.
- Costs: `BakeConfig` must carefully distinguish snapshots, live resources, final-read callbacks, and side-effect callbacks.
- Risks: helper boundaries can become leaky if broad RiverManager references sneak in.
- Fit for Waterways: best fit and current default.

### Option B: Freeze All Bake-Affecting State at Bake Start

- Benefits: simpler mental model for the baker.
- Costs: deliberate behavior change for async bakes; requires mid-bake edit proof and user-visible decision.
- Risks: source metadata/signature/settings can drift from old final-read behavior.
- Fit for Waterways: not the default; only acceptable if documented and validated.

### Option C: Extract Small Runtime/Editor Helpers Before Bake Pipeline

- Benefits: smaller review slices for R6.3 and R6.4; lower immediate bake risk.
- Costs: can delay the main `river_manager.gd` bake decomposition.
- Risks: still needs focused probes before moving ownership/markers.
- Fit for Waterways: acceptable if the user wants incremental review.

## Recommendation

Proceed with Option A as the default. Build baseline probes and inventories first, then move code in the order described by `plan.md`. Use Option C only for incremental review if the runtime ripple owner and editor validation probes are ready before bake baselines.

## Risks and Unknowns

- Helper-internal awaits may be missed if the inventory only greps `_generate_flowmap()`.
- A broad helper context could reintroduce RiverManager reach-back under another name.
- A constants table can make signature coverage look automatic when it is still a review decision.
- Whole `.res` hash changes can create false negatives if per-texture RT.1 hashes are not the gate.
- Editor marker consumers may exist outside the obvious plugin menu path.

## Context Challenge Notes

- Possible misread context: a dictionary or texture mismatch may come from stale or non-fresh baselines, not an R6 code change.
- Evidence: parent validation notes that rebakes can have GPU variance and whole-resource hashes may differ while per-texture hashes match.
- Confidence: medium until fresh pre-R6 baselines are captured.
- Quick check before patching: generate canonical dictionary/property/API/source-image/texture baselines before moving code.
- User-facing note or question to raise: if a mismatch appears before any R6 logic changes, pause and explain that the baseline is suspect before continuing.

## Sources

- `addons/waterways/docs/spec-driven/features/river-refactor/r6/plan.md`: R6 roadmap and decomposition design.
- `addons/waterways/docs/spec-driven/features/river-refactor/spec.md`: parent track requirements and non-goals.
- `addons/waterways/docs/spec-driven/features/river-refactor/validation.md`: prior phase validation evidence and R6 gate row.
- `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`: latest parent handoff and R5 closure evidence.
- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index.
