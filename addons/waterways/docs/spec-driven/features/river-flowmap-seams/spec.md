# Spec: River Flowmap Seam Handling

## Summary

Diagnose and resolve visible straight bands or tile seams in Waterways river flowmap output without guessing at the cause. This feature preserves the signature 23 bake-side fixes, uses the v2 plan as the controlling direction, and gates any larger architecture work on current visual evidence.

## Current Truth

- Status: Baseline recorded; no current visible seam found in the checked demo scenes.
- Source of truth for open work: `tasks.md` Open Work
- Last meaningful decision: the 2026-06-11 baseline diagnosis found no visible seam post-signature-23 in `Demo.tscn` or `Demo_obstacle_flow_test.tscn`, so no code fix should be built from stale pre-signature-23 observations.
- Known deferred items: WaterSystem/global flow handling, adaptive atlas packing unless evidence points to row-wrap or column-edge seams, and the full logical UV2-neighbor sampler unless a current offset path proves it is needed.
- Current non-goals that are easy to accidentally reopen: enabling pillow seam fades as the primary fix, replacing the square atlas preemptively, or building the full logical sampler before visual classification and ablation.

## Goals

- Confirm whether any visible river-flowmap seam remains after the signature 23 bake fixes.
- Classify any visible seam by join index, atlas class, and rendering context: same-column join, row-wrap join, column X-edge band, lit water only, unshaded debug view, raw baked channel, or derived/material view.
- Prefer the smallest confirmed fix, especially a lateral tile clamp for cross-column lateral reads, before considering atlas repacking or a full logical-neighbor sampler.
- Verify depth-1 bilinear bleed, mesh normal/tangent continuity, and temporal flow reset behavior as independent seam sources.
- Keep existing seam and world-sample probes passing unless a deliberate source-signature change updates their expectations.
- Record all diagnosis, validation, and follow-up decisions in this feature folder.

## Non-Goals

- Do not fold WaterSystem into this feature. It remains a separate longer-term track.
- Do not adopt strip packing unless current evidence localizes visible seams to row-wrap joins or column X-edge bands and the packing spike is small enough.
- Do not add `i_occupied_steps` or the full logical-neighbor sampler unless ablation proves a longitudinal offset path needs it beyond the existing one-tile continuation margin.
- Do not treat temporal seams as a workstream unless the quick confirmation shows visible pulsing.
- Do not use cosmetic pillow seam fades as proof that the underlying seam source is fixed.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Future Codex sessions should use it as the project-level source list for river behavior, hydrology, flow maps, shader-water references, and production examples, and should update it when new external research informs this feature.
- Known scene/data/context facts:
  - The UV2 atlas is currently square. `calculate_side()` computes a ceiling-square side, and steps map column-major.
  - The two demo river bakes are 17 and 18 occupied steps at `uv2_sides = 5`, texture size 358, content rect 256, signature 23.
  - Signature 23 synchronizes exact duplicated edge rows for the already-fixed bake channels.
  - Existing probes report zero delta at edge depth 0, while large depth-1/2 deltas remain in terrain-contact channels.
  - Longitudinal row-wrap offsets are protected by one full tile of continuation margin, while lateral offsets can cross interior column X edges without margin protection.
  - The debug shader is unshaded and renders static baked data, so seams visible there are data or sampling issues, not lighting or temporal issues.
  - The 2026-06-11 exported visible baseline found no straight seam in either demo scene in lit water, raw baked channel debug views, or derived/material debug views.
  - The checked demo materials keep `pillow_forward_reach_tiles` and `pillow_contact_pull_strength` at `0.0`; `pillow_height_smoothing_tiles` is `0.1`.
- User-reported observations: earlier seam-positive observations came from `symptoms and initial suspects.md` and predate the signature 23 fixes. A current visible pass is required before assuming the same symptom remains.
- Agent confidence in the premise: high that the v2 architecture facts are useful; medium that a visible seam remains; low confidence in any specific fix until baseline capture and ablation run.
- Possible expected-behavior explanations to rule out before patching:
  - Depth-1/2 terrain-contact changes may be legitimate nearby terrain changes rather than duplicated-edge errors.
  - Material amplification or debug palette contrast may make a small data gradient look like a hard seam.
  - Lit-only seams may come from duplicated-vertex normal/tangent basis discontinuity.
  - Previous visible reports may be stale after signature 23.
- Clarification or challenge already raised with the user: the v2 plan explicitly requires stating whether any visible seam remains before building fixes.

## Users and Workflows

### User Story: Add-on Maintainer Diagnoses Flowmap Seams

As an add-on maintainer, I want a repeatable seam-classification workflow, so that I can avoid expensive shader or atlas changes when a smaller cause explains the artifact.

Acceptance criteria:

- A baseline capture records whether seams remain in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.
- Each observed seam is mapped to a join index and atlas class.
- Each observed seam is classified as data/sampling, lit-only shading/material, temporal, or unresolved.

### User Story: Waterways User Bakes Seam-Resistant Rivers

As a Waterways user, I want demo rivers and similar river bakes to avoid straight tile bands in visible water, foam, wakes, pillows, normals, and height displacement, so that generated rivers read as continuous surfaces.

Acceptance criteria:

- Final human-visible review finds no straight tile bands in the checked views, or any remaining band is documented as expected behavior with supporting evidence.
- Existing data probes still pass after any fix.

## Functional Requirements

- Preserve the signature 23 bake-side behavior: corrected UV2 world sampling, vertex-aligned grade/bend generation, and exact duplicated-edge-row synchronization for the fixed channels.
- Run baseline visible classification before implementation work.
- Record whether demo materials override zero-default pillow uniforms before using pillow ablation results.
- Add or run a depth-1 bilinear-bleed probe that prioritizes `terrain_contact_features.a` and correlates results with observed seam positions.
- Verify mesh normal/tangent continuity or scope any confirmed discontinuity.
- Confirm temporal dual-phase reset is not visibly pulsing; keep this as a quick confirmation unless it fails.
- Ablate runtime-gated offset groups individually: `flow_hard_boundary_slide`, `wake_edge_sample_tiles`, `pillow_height_smoothing_tiles`, eddy/wake context, and ripples.
- If lateral cross-column reads are implicated, implement Build C: clamp lateral offsets to the current tile X range at the relevant offset call sites.
- If strip packing is considered, first complete the feasibility spike covering per-tile resolution, grid metadata, filter shaders, `lava.gdshader`, probes, and source-signature impact.
- If the logical sampler is considered, prove that a longitudinal offset path needs it beyond the existing one-tile continuation margins.

## Non-Functional Requirements

- Maintainability: keep fixes scoped to the implicated layer and update feature docs when decisions change.
- Performance: avoid adding per-fragment complexity unless a visible seam requires it; Build C should be shader-local and minimal.
- Visual quality: no visible straight tile bands in the demo scenes after the chosen fix, with debug and lit views agreeing with the diagnosis.
- Godot 4.6+ compatibility: implementation must use current Godot 4.6+ APIs and shader syntax.
- Editor usability: diagnosis and validation should use repeatable scene/debug-view steps that a human can run in the editor.
- Runtime usability: runtime shader behavior must remain compatible with existing materials and bakes unless a signature bump is explicitly chosen.
- Extensibility: any future atlas metadata should be explicit and inspectable instead of hidden behind square-only assumptions.

## Add-on Boundary

Editor authoring responsibilities:

- Human-visible scene review in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.
- Debug view selection, material override inspection, and any editor-visible normal/matcap review.

Bake/data responsibilities:

- Existing generated textures, duplicated-edge rows, continuation margins, source signature, and any future depth-1 or atlas-packing changes.
- Probe scripts that inspect saved bakes and UV2 world sampling.

Runtime responsibilities:

- Shader sampling, runtime uniform gates, lateral offset clamping if implemented, temporal flow blend, visible ripple/normal paths, and material amplification behavior.

Shared code must not depend on:

- One demo scene layout, one material preset, editor-only state, stale generated resources, or an assumption that all seams have the same root cause.

## Data and Extension Model

Users should be able to:

- Keep existing signature 23 bakes working.
- Disable or tune runtime offset helpers via material uniforms for diagnosis.
- Inspect generated bake channels and metadata when seam behavior changes.

Extension points:

- Shader uniforms for runtime offset helpers.
- Bake metadata/source signature for any future packing or channel synchronization changes.
- Debug views and probes for data, offset routing, normals/tangents, and visual review.

Override rules:

- Runtime material overrides should be recorded before ablation.
- If Build A changes packing, new grid metadata must supersede the single scalar `i_uv2_sides` assumption where needed.
- If no structural build lands, existing bake metadata remains authoritative.

Shared systems must not hard-code:

- Bundled demo-only texture dimensions, a material-only interpretation of seams, or square-atlas assumptions in new code without documenting why.

## Acceptance Tests

- Existing signature 23 probes still pass: `RIVER_FLOWMAP_SEAM_PROBE_OK` and `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`.
- Baseline capture records current visible seam status for both demo scenes.
- Any visible seam is classified by join index, atlas class, and lit/debug/raw/derived context.
- Depth-1 probe results are recorded and correlated or explicitly not correlated with observed seam positions.
- Ablation results identify or clear each gated helper group.
- If Build C lands, lateral offsets no longer cross interior column edges and the visible effect is measured against the baseline capture.
- If Build A or Build B lands, updated diagnostics and probes prove the relevant routing or packing behavior.

## Visual Validation Requirements

- Review `Demo.tscn` and `Demo_obstacle_flow_test.tscn` after signature 23 bakes are active.
- Compare lit water against unshaded debug views.
- Inspect raw baked channels separately from derived/material-amplified views.
- Confirm final output has no straight tile bands in foam, normals, wakes, pillows, or height displacement, or document why a remaining band is expected.

## Performance Requirements

- Build C should avoid new bake data, source-signature bumps, and atlas metadata.
- Build A must document the per-tile resolution rule and texture memory impact before adoption.
- Build B must be justified by a visible longitudinal sampling problem and should not duplicate work already covered by one-tile continuation margins.

## Open Questions

- Which join indices or atlas classes show visible artifacts?
- Do depth-1/2 deltas in `terrain_contact_features.a` visibly produce a bilinear band?
- Are normals/tangents discontinuous enough to cause lit-only bands?
- Does any runtime offset helper materially change the visible seam under ablation?
- Is Build C sufficient if lateral cross-column reads are implicated?
- Is strip packing justified by current seam evidence, or only as a later simplification?
- Is the full logical-neighbor sampler needed at all?

## Resolved Questions

Move questions here once decided so future sessions do not keep treating them as open.

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Which revised seam plan controls future work? | `Revised plan to improve seam handling v2.md` supersedes v1. | 2026-06-11 | v2 was produced by adversarial review and verified architecture claims against current code. |
| Is temporal phase noise absent? | No. Per-pixel phase noise is applied via `flow_foam_noise.a`; temporal reset only needs quick visible confirmation. | 2026-06-11 | `textures/flow_offset_noise.png` being unused is not evidence of a missing mechanism. |
| Are row-wrap longitudinal offsets currently unprotected? | No for current offset distances. One-tile continuation margins cover the current maximum longitudinal offset of 0.70 tiles. | 2026-06-11 | Lateral cross-column reads are the smaller unprotected offset class. |
| Does any visible seam remain after signature 23 in the current demo scenes? | No visible straight seam was found in the 2026-06-11 exported baseline for `Demo.tscn` or `Demo_obstacle_flow_test.tscn`. | 2026-06-11 | 0 seam records; no join-index, same-column, row-wrap, or column X-edge classification entries. |
| Do demo materials override zero-default pillow uniforms? | Not for the forward/contact pillow offsets. | 2026-06-11 | Both scenes keep `pillow_forward_reach_tiles` and `pillow_contact_pull_strength` at `0.0`; smoothing remains `0.1`. |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-11 | Use v2 as the feature-folder source plan. | It corrects the v1 spike gate, identifies lateral cross-column reads, adds depth-1 bilinear bleed, and expands ablation/classification. |
| 2026-06-11 | Diagnose before building. | The previous visible reports may be stale after signature 23, and debug/lit comparison can rule out multiple causes cheaply. |
| 2026-06-11 | Sequence Build C before Build A or Build B when offset sampling is implicated. | Lateral clamping is the smallest named fix and does not require repacking, new metadata, or a source-signature bump. |
| 2026-06-11 | Stop before implementation when the baseline found no visible seam. | There is no current visible artifact in the checked demo scenes to correlate with cheap checks or fix with Build C/A/B. |
