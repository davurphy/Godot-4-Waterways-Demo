# Plan: River Waterline and Bank Flow Corrections

## Spec Link

`spec.md`

## Architecture Summary

Use a diagnosis-first plan with four tracks:

1. Regression baseline: use `../river-obstacle-flow-constraints/` as the main description of the behavior that used to work, especially the pressure-projection, overhang/waterline, occupancy, and debug-arrow notes.
2. Evidence intake: map each screenshot to a scene, river, bake resource, camera, and debug view.
3. Probe correlation: compare visible symptoms against saved bake data, occupancy, waterline contact, bank masks, rendered/debug flow, and the older documented acceptance checks.
4. Minimal correction: restore lost documented behavior where possible, then rebake and validate against prior obstacle-flow and seam safeguards.

This is deliberately conservative. The older obstacle-flow feature is now the expected-behavior baseline because the user reports it worked for a while. The missing-water symptom was confirmed as a remaining waterline-contact edge case in collision occupancy; the bank-flow symptom still needs the same diagnosis discipline.

## Current Truth

- Implementation status: waterline-contact collision occupancy fix implemented and visually validated after user rebake; bank-flow issue remains diagnosis-only.
- Open architectural decisions: which layer owns the bank-flow symptom; whether existing probes are enough once that location is known or a dedicated bank-flow script is needed.
- Last validation that proves the plan still works: 2026-06-16 user rebake after the waterline patch resolved the red-circled missing-water regions; 2026-06-15 safe probes and focused waterline probe passed.
- Next planned implementation slice: classify the reported bank-flow symptom at its exact location before any bank-flow code changes.
- Branch safety before additional implementation: Not checked. Before code or generated-resource changes for bank flow, ask the user to create/switch to a dedicated branch or have Codex create one.
- Sections below that are historical or superseded: none yet.

## Premise Check

- Evidence supporting the premise:
  - The water-gap description matched a known class of overhang/wide-top occupancy mistakes and was confirmed by the focused waterline probe.
  - The bank-flow description matches possible local vector-field or debug-arrow defects.
  - Prior folders document related risks, so this is not a random visual complaint.
  - User clarified the prior obstacle-flow fixes worked for a while, which made regression or lost generated-data behavior a leading hypothesis.
- Evidence against the premise:
  - Existing `river-obstacle-flow-constraints` work claimed prior overhang/occupancy issues were fixed and validated, but the focused probe found a remaining top-down collision edge case.
  - Some apparent flow-direction problems can be debug-view artifacts when sampled flow magnitude is near zero.
  - Some missing-water regions may be legitimate if the collider footprint is wider than the rendered lower mesh.
- User-facing pushback or clarification needed before future patching:
  - If a future screenshot location is inside the actual collision footprint at water level, the correct fix may be collider/bake-participation setup rather than river code.
  - If a bank arrow is low magnitude, the correct fix may be debug visualization, not flow data.
- Smallest check that can falsify the premise:
  - Fresh rebake plus occupancy/flow debug capture at one reported bank inward patch; missing-water gap already passed after user rebake.

## Layers

Editor authoring layer:

- Debug view selection, screenshot capture, visible editor review, and any future inspector or bake-participation controls.

Bake/data layer:

- Collision map, terrain-contact/protrusion source, `water_occupancy`, pressure-projected flow, bank-response fields, bake signatures, and generated resources.

Runtime layer:

- `river.gdshader`, `river_debug.gdshader`, shared flow shader includes, and runtime flow sampling.

Validation layer:

- Screenshot inventory, existing probes from related features, new waterline footprint probe, new bank inward-flow probe, and human-assisted visible review.

Legacy reference layer:

- Legacy behavior is context only. Active fixes must target Godot 4.6+ code.

## Godot Components

- Nodes: demo scene rivers, WaterSystem, obstacle/collider nodes, terrain/bank geometry.
- Resources: `RiverBakeData`, WaterSystem bake data, generated flow/occupancy/contact textures.
- Shaders: river surface shader, river debug shader, shared flow include, filter shaders if the owning defect is in bake filters.
- Editor tools: debug views and bake controls.
- Importers: none expected.
- Autoloads: none expected.
- Scenes: reported demo scenes once screenshots identify them.
- Validation scenes: likely `Demo.tscn`, `Demo_obstacle_flow_test.tscn`, and any user-provided scene/context from screenshots.

## Data Model

Bank-flow diagnosis should inspect, not change, these data products:

- `water_occupancy`: solid mask and proximity ramp.
- Collision map / terrain-contact / protrusion sources: why a texel became solid or bank-affecting.
- Flow map: encoded direction and magnitude before runtime shader adjustments.
- System flow map: runtime/buoyancy-facing flow if the issue affects ducks or runtime sampling.
- Debug view output: whether a display path misrepresents low-magnitude or solid-center samples.

Initial regression comparison should inspect these documented prior behaviors:

- `water_occupancy` presence, channel use, and material binding. Status 2026-06-15: present in current code and saved Demo bakes.
- `flow_projected` metadata and runtime gate that skips contextual slide for projected fields. Status 2026-06-15: present in river, debug, and system-flow paths; saved Demo bakes report `flow_projected=true`.
- Overhang/protrusion confidence handling that prevents upper-only geometry from becoming solid. Status 2026-06-15: protrusion confidence gating was present, but collision occupancy still needed a waterline-contact gate for top-down/down-ray hits. Status 2026-06-16: patched and visually resolved after user rebake.
- FLOW_ARROWS fallback and low-speed display rules that avoid overconfident wrong-looking arrows. Status 2026-06-15: present; safe probes mirror the behavior and pass.
- Probe caveats for scripts that rebake and save resources.

Possible data-model changes, only if proven for remaining bank-flow work:

- Add stronger provenance for waterline-contact versus upper-geometry/protrusion occupancy.
- Add metadata/signature versioning for any changed occupancy or bank-flow bake behavior.
- Add debug channels or probe-only exports for classification confidence.

## Editor/Runtime Boundary

- Editor-only code: raycast/bake orchestration, visual probes, screenshot capture helpers, and debug UI.
- Runtime-safe code: shader interpretation of existing bake data and runtime sampling.
- Shared data/resources: bake resources and metadata.
- APIs exposed to user projects: unchanged unless object participation or waterline override controls become necessary.
- Assumptions that must not cross the boundary: runtime code must not depend on editor-only scene scans or screenshot-specific diagnostics.

## Runtime Flow

1. Surface shader samples occupancy, flow, contact, and other generated textures.
2. Shader clips or fades water based on occupancy.
3. Shader applies flow adjustments and debug display logic.
4. Runtime systems sample WaterSystem or river flow data for gameplay/buoyancy.

Diagnosis should compare the rendered result to the saved bake data before changing this flow.

## Bake Flow

1. River mesh and scene geometry define sampling positions.
2. Collision, terrain-contact, protrusion, and bank-response inputs are baked.
3. Occupancy and flow are generated/projected.
4. Metadata/signatures record the generation path.
5. Surface/debug shaders consume the generated textures.

If the obstacle gap is confirmed, the likely fix is in steps 2 or 3. If the bank inward patch is confirmed, the likely fix may be in baseline flow, projection/tangency, bank response, or debug interpretation.

## Lifecycle, Cleanup, and Re-entry

- Success path:
  - Evidence is captured, probes classify each screenshot, and any fix is validated with fresh bakes.
- Preflight or early-return path:
  - If screenshots are not yet available, do not implement; keep the work in evidence-intake mode.
- Awaited failure path:
  - If Godot probes cannot run locally, use human-assisted validation and record exact commands/visible results.
- Temporary node/resource ownership:
  - Probe-created nodes and output images stay under the feature folder or `.codex-research` and are excluded from packaging unless intentionally committed.
- Progress, dirty-state, and user feedback:
  - Rebakes that save generated resources must be called out before running because the worktree may already contain user-modified bakes.
- Duplicate or overlapping requests:
  - Do not run a destructive rebake probe twice without recording what generated resources it touches.
- Scene reload or runtime boundary:
  - Fresh editor state and current bake resources must be recorded for every validation run.

## Files to Change

Current documentation scaffold:

- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/spec.md`: behavior contract and open questions.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/plan.md`: diagnosis and implementation plan.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/research.md`: local research frame and options.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/tasks.md`: canonical task list.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/validation.md`: proof matrix and user validation steps.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/review.md`: review dashboard.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/handoff-latest.md`: next-session entry point.

Likely future probe files:

- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/probes/waterline_occupancy_probe.gd`: compare waterline contact, occupancy, and rendered gaps.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/probes/bank_inward_flow_probe.gd`: flag isolated inward bank flow in open water.
- `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/probes/README.md`: command patterns and output interpretation.

Likely future production files, only after diagnosis:

- `addons/waterways/water_helper_methods.gd`: if collision/contact/protrusion classification is wrong.
- `addons/waterways/river_manager.gd`: if bake orchestration, metadata, or uniforms are wrong.
- `addons/waterways/shaders/river.gdshader`: if shader clipping or runtime flow adjustment is wrong.
- `addons/waterways/shaders/river_debug.gdshader`: if debug views misrepresent low-magnitude or solid-center flow.
- `addons/waterways/shaders/filters/*.gdshader`: if projection/tangency/bank filters own the defect.

Primary reference files before any production edit:

- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/implementation-plan.md`: detailed prior design and tuning notes.
- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/spec.md`: expected behavior contract.
- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/validation.md`: prior pass markers, probe caveats, and human validation.
- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/README.md`: probe usage, if present/current.

## Documentation Plan

- Code comments needed: only for any non-obvious waterline-contact or bank-normal math introduced later.
- Feature docs to update: this folder first; related docs only if the fix changes their current truth.
- Architecture or data-flow docs to update: `addons/waterways/docs/architecture-and-features.md` if production behavior changes.
- Validation docs to update: `validation.md` matrix after every probe or human review.
- Research citations index: `addons/waterways/docs/research/river-research-citations.md` should be consulted before research-driven changes and updated only if new external sources affect the design.
- Migration notes to update: bake signature/resource behavior if rebakes become required.

## Validation Strategy

- Automated:
  - Static scan of relevant code paths.
  - Diff current behavior against documented older obstacle-flow mechanisms.
  - Existing related probes first, then new focused probes if needed.
- Validation matrix location:
  - `validation.md` "Validation Matrix".
- Human-assisted:
  - Screenshot correlation and visible Godot review are required for final acceptance.
- Visual:
  - Normal view plus occupancy/flow debug views at the reported camera locations.
- Shader:
  - Confirm whether defects are present in saved data or introduced by shader/debug rendering.
- Editor:
  - Confirm debug views remain understandable and bakes expose stale-data warnings when relevant.
- Runtime:
  - If flow direction affects gameplay/buoyancy, compare WaterSystem/runtime sampled flow.
- Performance:
  - Measure any production bake/runtime cost introduced by the fix.
- Manual:
  - Side-by-side before/after review with the user's screenshots.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Ignoring the prior working fix | Could redesign a solved problem | Treat old obstacle-flow docs as the baseline and compare current code first |
| Fixing a collider/setup issue in river code | Could weaken true obstacle clipping | Classify actual waterline collision before changing code |
| Treating debug arrows as real flow | Could tune away valid data | Compare encoded flow magnitude/direction to debug output |
| Rebake probes modify generated resources | Could overwrite user changes | Call out save behavior and inspect worktree before running |
| Waterline-aware occupancy leaks into true solids | Water renders inside obstacles | Keep non-penetration tests and occupancy interior checks |
| Bank-flow correction harms seams or projected-flow constraints | Regression in existing river behavior | Re-run seam and obstacle projection gates after any fix |

## Adversarial Plan Review

Complete this with the user after the plan is drafted and before implementation starts.

- Most likely way this plan could damage working behavior: over-correcting occupancy so water reappears inside genuine collider interiors.
- Project state, generated resource, scene, or workflow most at risk: generated bakes under `waterways_bakes/` and any user-modified scene/collider setup.
- Files or data that are riskier than they look: `river_debug.gdshader` because it can make data look wrong; rebake probes because they can save resources.
- Simpler or safer approach considered: classify screenshots with existing debug views before adding probes.
- Validation that will catch the riskiest failure early: one controlled waterline false-positive test plus one true-solid non-penetration regression test.
- Branch safety reminder sent before code changes: No.

## Migration and Compatibility

No migration is planned for the documentation scaffold. If implementation changes bake semantics, bump or record the relevant bake signature/version and provide a clear rebake path.
