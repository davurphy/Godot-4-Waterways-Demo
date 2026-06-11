# Research: River Flowmap Seam Handling

## Purpose

Capture the evidence and options from `Revised plan to improve seam handling v2.md` in the standard feature-folder format. This research should unlock a diagnosis-first implementation plan for any remaining river flowmap seam after the signature 23 fixes.

Use `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index for river behavior, hydrology, flow maps, shader-water references, and production examples. Update that file when new external sources inform this feature.

For Godot-specific implementation work, search current official Godot documentation and API references online before coding. Prefer official Godot docs first for shaders, rendering, editor APIs, resources, physics, and version-specific behavior; use community examples only as secondary context.

## Current Research Outcome

- Status: Complete enough to plan and baseline; reopen if implementation touches Godot APIs or external references.
- Recommendation: do not implement a seam fix from stale pre-signature-23 observations. If a current seam is reproduced and offset sampling is implicated, attempt the lateral tile clamp before strip packing or a full logical-neighbor sampler.
- Confidence: high in the v2 code-inspection facts; high that no visible seam was present in the 2026-06-11 exported baseline screenshots for the two checked demo scenes.
- Biggest unknown that remains: whether a seam can be reproduced in a different editor state, camera, material change, or future bake; no current seam exists to correlate with cheap checks.
- Decision or plan section this research unlocked: `plan.md` Architecture Summary and Revised Implementation Order.

## Questions

- What are we trying to learn?
  - Whether a current seam exists after signature 23. The 2026-06-11 exported baseline answer for the two demo scenes is no.
  - Whether it is data/sampling, material amplification, normal/tangent lighting, temporal reset, lateral cross-column reads, row-wrap packing, or depth-1 bilinear bleed.
- What assumptions need verification?
  - That older seam-positive observations still reproduce if new evidence appears. The 2026-06-11 exported baseline did not reproduce them.
  - That depth-1/2 deltas are visible artifacts rather than legitimate nearby terrain/contact changes.
  - That offset sampling is still a visible contributor.
- What user or agent premise might be wrong, incomplete, or based on missing scene/data context?
  - The visible seam may already be gone.
  - A seam visible only in lit water may not be a flowmap data problem.
  - Row-wrap packing may not explain seams at most joins.
- What Godot 4.6+ constraints could change the design?
  - Shader uniform plumbing, texture sampling behavior, SurfaceTool normal/tangent generation, and render/debug workflow constraints.
- Which parts are editor-only, runtime-only, or shared?
  - Editor-only: visual review, inspector/material checks, bake workflow.
  - Runtime-only: shader sampling, material uniforms, dual-phase flow animation.
  - Shared: generated bakes, source signatures, atlas metadata.
- What legacy Waterways behavior should be preserved, changed, or removed?
  - Preserve existing signature 23 bake improvements and runtime material compatibility unless evidence forces a metadata/signature change.

## Flow-Map and Water Tool Patterns

Comparable flow-map guidance favors rectilinear layouts where practical because they reduce spatial discontinuities. Waterways currently folds a 1D river step sequence into a square atlas to control texture dimensions and memory for long rivers. That tradeoff remains valid for long rivers, but it should not automatically force strip packing for short demo rivers unless the observed seams are actually row-wrap or column-edge artifacts.

The v2 evidence reframes protection coverage:

- Longitudinal row-wrap offsets are already protected by a one-tile continuation margin, and the current largest longitudinal shader offset is 0.70 tiles.
- Lateral offsets can cross interior column X edges without a margin. Since lateral direction means river width, the correct local behavior is to clamp those reads to the current tile's X range rather than sample the atlas neighbor column.
- Dual-phase flow blending with per-pixel phase noise is already present, so temporal reset should be confirmed visually but not treated as the main workstream unless it fails.

## Godot 4.6+ Findings

No new online Godot research was performed for this documentation-only pass. Before code changes, use current official Godot documentation for any implementation-sensitive API or shader behavior.

Facts imported from the v2 code inspection:

- `river_debug.gdshader` is unshaded and static for seam-positive debug views, making it a strong discriminator between data/sampling and lighting/temporal causes.
- `flow_foam_noise.a` contributes per-pixel phase noise to the dual-phase flow blend.
- `SurfaceTool` normal/tangent generation follows duplicated vertices with differing UV2, making a join basis discontinuity plausible.
- Runtime offset helpers are controlled by uniforms that can short-circuit sampling at zero, enabling ablation without shader edits.
- Several pillow offset uniforms default to zero and should not be treated as live causes unless material overrides prove otherwise.

## Legacy Waterways Reference

- Relevant legacy files: none required for the v2 diagnosis-first plan.
- Behavior to preserve: existing Godot 4 signature 23 behavior and current material/bake compatibility.
- Behavior to change: only behavior proven by current diagnosis.
- Obsolete APIs to avoid: any Godot 3-only editor, rendering, or resource APIs.
- Risks discovered in `audit/code-audit.md`: not checked in this documentation pass; future implementation should check it during setup.
- What belongs in active Godot 4.6+ code: shader-local lateral clamp, probes, and bake metadata changes only if evidence justifies them.
- What should remain legacy-only: any older Waterways behavior that assumes different Godot rendering or resource APIs.

## Options

### Option A: Build C, Lateral Tile Clamp

- Benefits: smallest named shader fix; addresses the genuinely unprotected offset class; no new metadata, repack, source-signature bump, or bake change.
- Costs: touches shader offset call sites and one helper; must be carefully scoped so longitudinal offsets still use existing margin protection.
- Risks: does nothing for depth-1 bilinear bleed or lit-only normal/tangent seams.
- Fit for Waterways: best first implementation if diagnosis implicates lateral cross-column reads.

### Option B: Depth-1 Bilinear-Bleed Decision

- Benefits: addresses a data-level hypothesis not covered by prior plans and can explain same-column bands near joins.
- Costs: requires a new probe and possibly a bake-side policy for categorical channels.
- Risks: constraining depth-1 rows may erase legitimate terrain/contact differences.
- Fit for Waterways: necessary if visible seams correlate with depth-1/2 terrain-contact deltas.

### Option C: Mesh Normal/Tangent Fix

- Benefits: targets lit-only seam artifacts without changing bake data.
- Costs: requires basis inspection and likely mesh generation changes.
- Risks: may affect lighting across all river steps.
- Fit for Waterways: appropriate only if seams are absent from unshaded debug views but present in lit water.

### Option D: Build A, Strip-Preferring Atlas Packing

- Benefits: structurally removes row-wrap joins for short/medium rivers and may simplify future reasoning.
- Costs: broad metadata, shader, bake filter, probe, source-signature, and per-tile resolution decisions.
- Risks: fixes only 3 of 16 joins in the 17-step demo case unless seams localize to row-wrap or column-edge bands; changes texture density/memory behavior.
- Fit for Waterways: conditional branch, not the default seam fix.

### Option E: Build B, Logical UV2-Neighbor Sampler

- Benefits: general compensation for rivers that must remain folded into a square atlas.
- Costs: more shader complexity and `i_occupied_steps` plumbing.
- Risks: current longitudinal offsets do not exceed the one-tile continuation margin, so it may solve no visible problem.
- Fit for Waterways: last resort for proven longitudinal offset paths that current margins cannot cover.

## Recommendation

Follow the v2 order, with the baseline gate now closed as "no visible seam found." Do not continue into cheap checks or ablation unless a seam is reproduced or extra diagnostics are requested. If a sampling fix is later proven, implement Build C first. Treat depth-1 and normal/tangent findings as separate branches. Consider Build A only when visible evidence points to row-wrap or column-edge atlas geometry and the feasibility spike is small. Consider Build B only if a longitudinal offset path demonstrably needs it.

## Risks and Unknowns

- The visible symptom appears stale after signature 23 in the checked baseline.
- Depth-1/2 deltas may be real terrain changes or may create a visible bilinear band in another state; this should be probed only if a current visible seam is reproduced or extra diagnostics are requested.
- Material overrides do not make zero-default forward/contact pillow offsets live in the checked demo scenes; `pillow_height_smoothing_tiles` remains live at `0.1`.
- A single screenshot without join-index classification could point the plan toward the wrong build.
- Strip packing has a hidden per-tile resolution decision because current tile size is emergent from `resolution / side`.

## Context Challenge Notes

- Possible misread context: assuming the older seam-positive list is still true.
- Evidence: the 2026-06-11 baseline lit/debug export did not reproduce visible seams in `Demo.tscn` or `Demo_obstacle_flow_test.tscn`.
- Confidence: high for the exported baseline; medium for other editor states or future bakes not reviewed.
- Quick check before patching: re-run baseline lit/debug capture in both demo scenes if new evidence appears.
- User-facing note or question to raise: no visible seam remains in the checked baseline, so no implementation fix is currently justified by the stale symptom list.

## Sources

- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index for Waterways river behavior, hydrology, flow-map, shader-water, and production-reference sources.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/Revised plan to improve seam handling v2.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/Plan to improve waterways seam handling.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/Revised plan to improve seam handling.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/audit/seam-handling-audit-2026-06-11.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/symptoms and initial suspects.md`
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/Seamless River Flowmap Techniques.md`
- `addons/waterways/water_helper_methods.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/filters/*.gdshader`
