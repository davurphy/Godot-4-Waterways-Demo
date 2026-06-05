# Spec: River Eddies

## Summary

River eddies in Waterways are currently represented by a visual-only wake and eddy-line material preview. The accepted Phase 7B baseline renders downstream wake breakup and narrow eddy-line turbulence without changing source flow, final flow, reverse/circulating flow, WaterSystem generation, or saved WaterSystem bakes.

Feature terms used by this spec:

- Wake: downstream disturbed or slower region behind an obstruction.
- Eddy line: narrow boundary where the main current shears against wake or slower/recirculating water.
- Eddy core: future flow feature where water may slow, neutralize, or reverse locally.
- Ordinary bank: normal shoreline or bank friction that should not automatically become wake or eddy-line behavior.
- Hard protrusion: rock, cliff, terrain contact, or obstruction that intrudes into flow enough to justify wake or eddy-line detection.
- Raw mask: baked/source feature mask before shader gates.
- Final visual mask: shader-side mask after confidence, context, energy, flow, and suppression gates.
- Visible material response: normal, roughness, specular, albedo, turbulence, and foam response driven by an accepted final mask.

## Current Truth

Use this as the dashboard for the current eddy spec state. Keep older Phase 7A/7B evidence in the sections below instead of reopening it as active uncertainty.

- Status: Phase 7B visual wake/eddy-line material preview accepted.
- Source of truth for open work: `tasks.md` "Open Work".
- Current baseline: `Eddy-Line Visual Mask` uses the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- Known preserved diagnostics: the old raw-B path remains available through B-based debug views, including `Eddy-Line / Shear Mask`, `Gated Eddy-Line Source (B * Wake Gate)`, `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, and `Eddy-Line Wake Context Search`.
- Last meaningful decision: Treat Phase 7B as visual-only and accepted; defer real reverse/circulating flow to Phase 7C/7D.
- Known deferred items: Real reverse/circulating flow, WaterSystem/physics alignment, new eddy vector data, Phase 7C, and Phase 7D.
- Current non-goals that are easy to accidentally reopen: Do not change accepted source flow, final flow, reverse flow, `system_flow.gdshader`, WaterSystem generation, saved WaterSystem bake, river bake source signature, or `RiverBakeData` layout for Phase 7B preservation work.

## Goals

- Preserve the accepted Phase 7B visual wake/eddy-line baseline.
- Keep raw source masks, final visual masks, and visible material response clearly separate.
- Keep the channel/phase alignment lesson explicit: raw B was plausible but spatially wrong, while raw G produced the accepted paired eddy-line margins.
- Make future eddy work start from user-confirmed viewport review instead of fixed screenshots alone.
- Keep B-based diagnostics available for comparison with the accepted raw-G wake-edge path.
- Keep Phase 7B surface-only unless a later spec explicitly scopes final-flow and WaterSystem changes.
- Define the validation expectations for future Phase 7C/7D work before it begins.
- Avoid demo-scene overfitting by checking both main demo and obstacle-test layouts.

## Non-Goals

- Do not add real reverse/circulating flow in the current accepted Phase 7B baseline.
- Do not alter `flow_foam_noise.rg`, source flow, final flow, or WaterSystem flow for visual-only wake/eddy-line work.
- Do not regenerate the saved WaterSystem bake for Phase 7B visual material changes.
- Do not treat `obstacle_features.g` or `.b` as enough information for stable eddy spin, center, radius, or reverse velocity.
- Do not tune visible foam or brightness before verifying raw/final mask placement.
- Do not accept the start-of-river hotspot as proof of successful eddy-line detection.
- Do not remove old B-based diagnostic paths just because the visual mask now uses raw G.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Future sessions should use it as the project-level source list for river behavior, hydrology, flow maps, shader-water references, and production examples, and should update it when new external research informs eddy work.
- Known scene/data/context facts:
  - Phase 5A/5B final flow and WaterSystem behavior are accepted downstream-preserving baselines.
  - Phase 7A2 narrowed `obstacle_features.b` and bumped river bakes to source signature `17`.
  - Phase 6D/6E later bumped current river bakes to signature `19` for pillow classifier work.
  - Phase 7B visual wake/eddy-line material preview is accepted on current data and must be preserved.
  - `waterways_bakes/Demo/WaterSystem.water_system_bake.res` was not regenerated for Phase 7B.
- User-reported observations:
  - The old final eddy-line view was green/empty away from the river start.
  - Edge-sample-only tuning did not produce the desired paired wake margins.
  - `Experimental Wake-Edge Eddy Source` and `Raw Wake-Edge Candidate (from G)` showed the desired two trailing lines behind multiple rocks.
  - After the material-override fix and stronger defaults, the user accepted the visible eddy-line pass.
- Agent confidence in the premise:
  - High that Phase 7B visual placement is accepted.
  - High that Phase 7B is not physics-facing.
  - Medium that existing scalar masks are enough for future surface-only tuning.
- Possible expected-behavior explanations to rule out before patching:
  - Green debug output may mean low or near-zero mask, not a rendered green eddy.
  - Start-of-river hotspots may be boundary/source artifacts.
  - A visual eddy-line cue can look like flow reversal even when buoyancy still follows downstream WaterSystem flow.
  - A material override can make visible-water fields appear to do nothing if debug material state is stale.
- Clarification or challenge already raised with the user:
  - Real reverse/circulating flow is deferred and must update visible shader, debug shader, system-flow shader, WaterSystem generation, and runtime validation together.

## Users and Workflows

### User Story: River Author Reviews Eddy-Line Placement

As a river author, I want to compare wake, eddy-line, and diagnostic debug views around the same rocks, so that I can tell whether eddy-line accents sit on the downstream wake margins instead of filled wake blobs or ordinary banks.

Acceptance criteria:

- `Eddy-Line Visual Mask` shows paired wake-edge margins behind hard protrusions where accepted.
- Wake centers remain quieter than the narrow margins.
- Ordinary smooth banks do not become continuous eddy-line strips.
- The start-of-river hotspot is excluded from acceptance decisions.

### User Story: Add-on Maintainer Preserves Accepted Phase 7B

As an add-on maintainer, I want the accepted raw-G eddy-line path and old raw-B diagnostics documented, so that future shared shader/classifier edits do not accidentally erase the baseline or the reason it was accepted.

Acceptance criteria:

- The accepted raw-G path is named in spec, plan, tasks, validation, review, and handoff.
- B-based diagnostics remain listed and preserved.
- Any future shared classifier or shader change reruns relevant Phase 7B checks.

### User Story: Reviewer Separates Visual Tuning From Flow Changes

As the reviewer, I want any future eddy request to be classified as raw detection, final visual mask, visible material response, or actual flow/physics behavior, so that the implementation changes the correct layer.

Acceptance criteria:

- Visual-only changes do not dirty bakes or WaterSystem output.
- Final-flow or physics-facing work requires Phase 7C/7D planning first.
- Human-assisted viewport/runtime validation is requested in chat, not only stored in docs.

### User Story: Future Flow Designer Scopes Phase 7C

As a future flow designer, I want eddy circulation scoped as a new final-flow milestone, so that visible current, debug current, WaterSystem flow, and runtime buoyancy can agree.

Acceptance criteria:

- Phase 7C defines either explicit eddy vector data or an analytic vector model.
- The same logic is mirrored in `river.gdshader`, `river_debug.gdshader`, and `system_renders/system_flow.gdshader`.
- WaterSystem regeneration and runtime validation are part of the same scoped pass.

## Functional Requirements

- Preserve `Wake Visual Mask`, `Wake Edge Thinness`, and `Eddy-Line Visual Mask` as the primary Phase 7B review views.
- Keep `Eddy-Line Visual Mask` derived from the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- Preserve raw `obstacle_features.g` as the wake / eddy seed source and raw `obstacle_features.b` as a B-based eddy-line/shear diagnostic source.
- Preserve B-based diagnostic views for channel comparison.
- Keep raw source review first, final visual mask review second, and visible water review last.
- Keep visible and debug shader mask logic in parity for any future visual change.
- Keep Phase 7B surface cues visual-only: normal detail, roughness/specular breakup, albedo breakup, turbulence, and small noisy foam flecks.
- Do not redirect flow vectors, change `flow_force`, or add reverse/circulating flow for Phase 7B preservation work.
- Do not bump source signatures or rebake river resources for shader-only material response tuning.
- Do not regenerate saved WaterSystem bake unless final/physics flow changes are explicitly scoped.
- If Phase 7C is scoped, require visible shader, debug shader, system-flow shader, WaterSystem generation, regenerated saved bake, and runtime validation changes together.

## Non-Functional Requirements

- Maintainability: Keep wake, eddy-line, and future eddy-core concepts distinct.
- Performance: Avoid runtime readbacks for normal rendering. Extra sampling should be shader-local, debug-only, or explicitly justified.
- Visual quality: Eddy lines should read as narrow intermittent shear margins, not broad shoreline foam or filled wake blobs.
- Godot 4.6+ compatibility: Use active Godot 4.6+ shader/resource/editor APIs only.
- Editor usability: Debug views should make raw/final/visible differences clear enough for user viewport review.
- Runtime usability: Visual-only masks must not imply unsupported physics behavior.
- Extensibility: Future eddy vector data should be inspectable, documented, and reusable outside `Demo.tscn`.
- Trust/debuggability: Users should be able to explain why an eddy-line accent appears or disappears from debug views and source terms.

## Add-on Boundary

Editor authoring responsibilities:

- Debug View menu entries under Wake / Eddy.
- Human-assisted viewport review and target selection.
- Review cameras, captures, and optional future marker/region tooling.

Bake/data responsibilities:

- `obstacle_features.g`: downstream wake / eddy seed.
- `obstacle_features.b`: eddy-line/shear diagnostic source.
- `obstacle_features.a`: obstacle confidence envelope.
- `terrain_contact_features.b`: direct protrusion/intersection context.
- `bank_response_features.a`: hard-boundary/protrusion context.
- `dist_pressure.b`: grade/energy.
- Any future eddy vector data, metadata, source signature, and saved-resource handling.

Runtime responsibilities:

- Visible material response from accepted final visual masks.
- Runtime-safe shader uniforms for `wake_` controls.
- Future WaterSystem-compatible flow only when Phase 7C/7D is scoped.

Shared code must not depend on:

- Legacy Godot 3 APIs.
- One specific demo camera.
- A single rock layout.
- Debug shader state being saved as visible material state.
- Visual-only masks being treated as WaterSystem flow.

## Data and Extension Model

Users should be able to:

- Review wake and eddy-line raw/final masks through debug views.
- Tune visual wake/eddy response through `wake_` material parameters.
- Use different river scenes and obstacle layouts without one-off constants.

Extension points:

- Wake/eddy material uniforms.
- Debug views and future low-range/threshold diagnostics.
- Validation probes and export helpers.
- Future `RiverBakeData` channel or texture for eddy vectors if Phase 7C chooses that path.

Override rules:

- Saved material overrides must not prevent visible `wake_` fields from affecting normal rendering.
- Debug material overrides must return to visible material behavior when Debug View is Normal.
- Bake changes must invalidate stale resources through source-signature changes.

Shared systems must not hard-code:

- Specific demo rocks.
- A specific HTerrain layout as the only supported terrain source.
- A one-off edge sample setting that only works in one camera.
- WaterSystem regeneration for visual-only material work.

## Acceptance Tests

- `Eddy-Line Visual Mask` uses the accepted raw-G wake-edge source at `wake_edge_sample_tiles = 0.024`.
- `Raw Wake-Edge Candidate (from G)` and `Experimental Wake-Edge Eddy Source` remain available for comparison.
- Old B-based diagnostic views remain available.
- `Wake Visual Mask`, `Wake Edge Thinness`, and `Eddy-Line Visual Mask` can be reviewed around the same targets.
- Main demo and obstacle-test layouts do not show continuous ordinary-bank eddy-line strips.
- Visible wake/eddy material response can be tuned without stale debug-material overrides.
- Phase 7B does not alter source flow, final flow, reverse/circulating flow, WaterSystem shader wiring, `RiverBakeData` layout, source signatures, river bakes, or saved WaterSystem bake.
- Future Phase 7C changes include visible/debug/system-flow parity and runtime validation before acceptance.

## Visual Validation Requirements

- Use visible Godot editor/runtime review for acceptance.
- Compare the same rock/protrusion targets across:
  - `Wake / Eddy Seed Mask`
  - `Raw Wake-Edge Candidate (from G)`
  - `Experimental Wake-Edge Eddy Source`
  - `Wake Visual Mask`
  - `Wake Edge Thinness`
  - `Eddy-Line Visual Mask`
  - `Eddy-Line / Shear Mask`
  - `Gated Eddy-Line Source (B * Wake Gate)`
  - `Eddy-Line Raw Low Range (B x4)`
  - `Obstacle Confidence`
  - `Hard-Boundary / Protrusion Response`
  - `Final Flow Strength`
- Capture or describe upstream/downstream direction for each target.
- Treat fixed screenshots and exported captures as evidence, not final acceptance.
- Include the human-assisted validation steps directly in future chat messages whenever Godot viewport review is needed.

## Performance Requirements

- No runtime readback for normal visible rendering.
- Shader-only visual tuning should not require rebakes.
- Future Phase 7C vector work must define shader sampling cost, WaterSystem generation cost, and runtime validation cost.
- Debug/export probes may be slower, but they should stay out of packaged runtime paths.

## Open Questions

- What data model should Phase 7C use for real eddy circulation: explicit vector texture, analytic vortex field, or another generated flow layer?
- How should eddy spin side be determined from obstacles, flow, banks, and wake context?
- Should future eddy vector data live in a new texture or extend existing resources?
- What runtime object behavior will count as accepted eddy physics: floating object slowdown, lateral pull, reverse drift, or full circulation?
- Which synthetic validation scene is needed for a single isolated obstruction, ordinary bank, and hard wall protrusion?
- Are more low-range raw G/B/A views needed, or are current diagnostics enough?

## Resolved Questions

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Is Phase 7B accepted as a visual baseline? | Yes. User accepted the visible pass after the material-override fix and stronger defaults. | 2026-05-26 | Current docs preserve this as the baseline. |
| Should `Eddy-Line Visual Mask` use raw B as the main visible source? | No. Raw B remains diagnostic; raw G produced the accepted paired wake-edge placement. | 2026-05-26 | Channel/phase alignment fix. |
| Is larger `wake_edge_sample_tiles` alone the fix? | No. `0.024` became accepted only with the raw-G source change. | 2026-05-26 | Edge-sample-only sweep was rejected. |
| Is Phase 7B physics-facing? | No. It is visual-only. | 2026-05-26 | No source-flow, final-flow, reverse-flow, system-flow, or saved WaterSystem bake change. |
| Should Phase 7C update WaterSystem later? | Yes, if real final-flow/reverse-flow is scoped. | 2026-05-26 | Visible/debug/system-flow/WaterSystem/runtime validation must move together. |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-05-26 | Use review-only Phase 7A1 preflight before visible changes. | Avoid promoting broad scalar masks directly into material or physics. |
| 2026-05-26 | Narrow raw eddy-line/shear in Phase 7A2. | Old raw B was too broad for direct visual use. |
| 2026-05-26 | Add visual-only wake/eddy-line material preview in Phase 7B. | Wake and narrowed eddy-line data were ready for cautious surface cues. |
| 2026-05-26 | Reject edge-sample-only fix. | It made thinness busier but did not create paired trailing margins. |
| 2026-05-26 | Promote raw-G wake-edge candidate into `Eddy-Line Visual Mask`. | Raw G matched the desired paired wake-edge margins better than raw B. |
| 2026-05-26 | Keep Phase 7B visual-only. | Existing scalar masks do not encode reverse/circulating flow or physics-ready velocity. |
| 2026-05-31 | Create this feature-local spec folder. | Keep eddy/wake/eddy-line work from being scattered across changelog, handoff, and roadmaps. |
| 2026-06-04 | Align this feature folder with the newer spec-driven templates. | Keep the accepted Phase 7B baseline easier to find without changing feature scope. |
