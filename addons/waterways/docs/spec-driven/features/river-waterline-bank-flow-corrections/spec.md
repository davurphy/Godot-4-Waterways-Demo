# Spec: River Waterline and Bank Flow Corrections

## Summary

Diagnose and correct two reported river defects:

1. Some protruding obstacles leave gaps where water should still render. The suspected cause is that obstacle/occupancy detection is using a top-down or upper-geometry footprint instead of the actual waterline/wetted contact footprint.
2. Some isolated bank-adjacent flow regions point inward, toward the river center, instead of following the local downstream direction.

The original large missing-water premise is confirmed and partly fixed: top-down/down-ray collision occupancy could still mark open waterline under overhangs as solid. After the patch and user rebake, the large red-circled gaps improved/resolved, but smaller holes remain around objects and river banks and are noticeable only from some viewing angles. Those residual holes may have a different owning layer than the bake occupancy fix. The bank-flow premise remains unverified and should still be treated as a diagnosis task.

User clarification on 2026-06-15: the older obstacle-flow fixes worked for a while, but may have been lost or regressed. Treat those documents as the primary baseline for expected behavior and use this folder to prove where current code, generated bakes, or scene data diverged from them.

## Current Truth

- Status: original large waterline missing-water issue fixed/improved and visually validated after user rebake; residual angle-dependent small holes and bank-flow issue remain open.
- Source of truth for open work: `tasks.md` "Open Work".
- Last meaningful decision: add waterline-contact gating to collision occupancy and bump the bake signature; user rebake confirmed the large reported missing-water gaps improved/resolved, but not all small water holes are gone.
- Known deferred items: residual angle-dependent hole classification, bank-flow classification, possible probes/fixes, and any generated-resource hygiene the user wants after the rebake.
- Current non-goals that are easy to accidentally reopen: general ripple/foam retuning, broad water-material polish, and replacing the pressure-projection system without evidence.

## Goals

- Keep the reported large missing-water gaps fixed by requiring actual waterline contact before upper/top-down collider hits can remove water.
- Prove whether the smaller residual angle-dependent holes are shader/depth/clip artifacts, remaining occupancy false positives, legitimate collider/bank footprints, mesh/normal issues, stale generated data, or another edge case.
- Prove whether the reported inward bank flow exists in the baked flow field, only in a debug view, or only after runtime shader adjustment.
- Compare current code and generated data against the older obstacle-flow documented fixes and recover any lost behavior if regression is confirmed.
- Correct the smallest owning layer once the cause is known.
- Leave durable probes and validation steps so future regressions can be detected from screenshots, saved bakes, or controlled scenes.

## Non-Goals

- Do not redesign the entire river bake pipeline unless the probes show the current architecture cannot represent the needed behavior.
- Do not tune visuals around screenshots before confirming whether the underlying bake data is correct.
- Do not change unrelated obstacle wake, pillow, ripple, foam, buoyancy, or seam behavior unless the same root cause is proven.
- Do not assume all gaps are bugs; some may be legitimate collider occupancy or stale generated data.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Future sessions should use it as the project-level source list for river behavior, hydrology, flow maps, shader-water references, and production examples, and should update it when new external research informs this feature.
- Known scene/data/context facts:
  - Primary regression baseline: `../river-obstacle-flow-constraints/`, especially `implementation-plan.md`, `spec.md`, `validation.md`, and probes around `water_occupancy`, pressure-projected flow, overhang handling, and FLOW_ARROWS debug caveats.
  - Related object-classification work exists in `../river-object-artifacts/`, especially wide tops, overhangs, terrain-contact sampling, and object participation policy.
  - Related bank/flow-map edge behavior may overlap with `../river-flowmap-seams/`.
- User-reported observations:
  - Obstacles with upper geometry wider than the lower water-contact section can leave holes in water rendering.
  - Some isolated bank-adjacent spots appear to change direction inward toward the river center.
  - Three red-circled missing-water screenshots were supplied and later confirmed improved/resolved after the user rebaked the river.
  - Smaller residual holes remain around objects and river banks, but are only noticeable from certain viewing angles.
- Agent confidence in the original large waterline premise: confirmed and fixed/improved. Agent confidence in residual small-hole premise: medium, with view-dependent shader/depth/mesh behavior now a leading possibility. Agent confidence in the bank-flow premise: medium until a specific bank location is probed.
- Possible expected-behavior explanations to rule out before patching:
  - A collider is intentionally wider than visible waterline geometry and the bake is honestly clipping inside that collider.
  - Existing generated bakes may be stale relative to current code/signature.
  - FLOW_ARROWS or another debug view is sampling a low-magnitude or solid-center texel and drawing a misleading direction.
  - A bank-adjacent inward vector may be a local turn, eddy/wake region, or near-zero residual whose direction is visually over-emphasized.
- Clarification or challenge already raised with the user: safe Demo probes did not justify a production patch by themselves; the focused waterline probe classified the screenshot-specific edge case before code changed.

## Users and Workflows

### User Story: River author reviews obstacles at the waterline

As a river author, I want obstacle detection to respect where the object actually meets the water, so that wide tops, overhangs, and protruding geometry do not remove water from open waterline areas.

Acceptance criteria:

- At reported screenshot locations, open water beside or beneath wider upper geometry remains rendered unless the waterline is actually occupied by solid collision.
- Occupancy/debug views identify whether each removed-water region is collision, protrusion, terrain, stale bake, or shader clipping.
- Status: pass for the original large overhang screenshots after the waterline-contact collision occupancy patch and user rebake; residual smaller angle-dependent holes remain open.

### User Story: River author reviews bank flow direction

As a river author, I want bank-adjacent flow to follow the downstream river path unless a deliberate local feature changes it, so that isolated inward-pointing patches do not break the surface motion.

Acceptance criteria:

- At reported screenshot locations, the baked and rendered flow vectors are either downstream-consistent or are flagged with a documented reason.
- If the flow is wrong, the correction removes isolated inward patches without damaging obstacle non-penetration or seam handling.

### User Story: Add-on maintainer diagnoses regressions

As an add-on maintainer, I want probes that compare occupancy, waterline contact, debug arrows, and runtime flow, so that future reports can be classified before code changes.

Acceptance criteria:

- A waterline/occupancy probe can report suspected false-positive solid texels near wide-top obstacles.
- A bank-flow probe can report isolated inward-normal vectors in open-water bank bands.
- Probe output links cleanly to screenshots and scene locations.

## Functional Requirements

- FR1: Preserve a screenshot/evidence inventory for each reported location, including scene, camera, debug view, river resource, bake age, and visible symptom.
- FR2: Compare current code paths and bake metadata against the documented `river-obstacle-flow-constraints` behavior before designing a new fix.
- FR3: Add or identify a probe that compares waterline contact against `water_occupancy` so false-positive solid masks can be separated from legitimate collider footprints. Status: satisfied by `waterline_occupancy_probe.gd`.
- FR4: Add or identify a probe that checks bank-adjacent flow vectors against local downstream tangent and inward/outward bank normals.
- FR5: Distinguish baked-data defects from shader/debug-view defects before implementation.
- FR6: If obstacle gaps are confirmed, first try to restore the documented prior overhang/waterline behavior before inventing a new classification path. Status: satisfied by waterline-contact gating in collision occupancy.
- FR7: If bank flow defects are confirmed, fix the smallest responsible stage: baseline flow, projection/tangency, bank-response field, atlas sampling, runtime slide, or debug rendering.
- FR8: Record any required rebake/version/signature behavior so old generated data does not silently hide or preserve the issue.

## Non-Functional Requirements

- Maintainability: new diagnosis should fit the existing probe and feature-folder patterns.
- Performance: any additional bake sampling must be budgeted before it becomes default behavior.
- Visual quality: fixes must preserve existing no-water-inside-solid behavior while restoring water where the waterline is actually open.
- Godot 4.6+ compatibility: use current Godot 4.6+ APIs; check official docs before implementation if new engine APIs are needed.
- Editor usability: debug views should make the distinction between solid, open water, low-flow, and uncertain classification visible.
- Runtime usability: runtime sampling and buoyancy should continue reading the corrected flow data consistently.
- Extensibility: waterline contact classification should support different collider shapes, terrain, and future object participation rules.

## Add-on Boundary

Editor authoring responsibilities:

- Debug views, screenshot workflows, bake controls, and optional visual probes.

Bake/data responsibilities:

- Occupancy, collision/protrusion classification, terrain-contact data, flow projection, bank-response fields, and metadata/signature updates.

Runtime responsibilities:

- Shader clipping, flow adjustment, debug arrow display, and runtime flow sampling.

Shared code must not depend on:

- A specific demo rock, one screenshot location, one scene hierarchy, one material preset, or one collider style.

## Data and Extension Model

Users should be able to:

- Give objects precise bake-participation behavior without changing unrelated gameplay collision.
- Rebake and inspect why water was removed or why flow was redirected.
- Keep older bakes readable, with clear warnings when regeneration is required.

Extension points:

- Existing bake layers, object opt-out policy, water occupancy channels, debug views, and probe scripts.

Override rules:

- Resolved for collision occupancy: top-down/down-ray collider hits only mark water solid when the collider also contacts the waterline band. Upper-only geometry no longer claims the water column.

Shared systems must not hard-code:

- Demo object names, one bank width, one river resolution, or one raycast layer convention.

## Acceptance Tests

- AT1: For each user screenshot, classify the symptom as occupancy false positive, legitimate collider footprint, stale bake, shader clip, debug-view artifact, or other.
- AT2: Current implementation is compared to the older obstacle-flow documented behavior, and any missing/lost mechanisms are listed before new design work begins.
- AT3: A waterline/occupancy probe flags false-positive solid regions under or beside wide upper geometry without weakening true solid interiors. Status: pass for the reported Demo overhang region; true-solid visual spot checks remain useful for future collider changes.
- AT4: A bank-flow probe flags isolated open-water bank texels whose cross-bank component points inward beyond the chosen threshold while nearby downstream flow remains normal.
- AT5: After any fix and rebake, reported obstacle gap locations show water where the waterline is open and no water inside true solids. Status: partial pass; large reported obstacle gaps show water after user rebake, but smaller angle-dependent holes remain around objects/banks.
- AT6: After any fix and rebake, reported bank-flow locations no longer contain isolated inward patches unless documented as deliberate local behavior.
- AT7: Existing obstacle non-penetration, seam, and system-flow comparison checks still pass.

## Visual Validation Requirements

- User-provided screenshots for each reported location, ideally with normal view plus relevant debug views: occupancy, FLOW_ARROWS/effective flow direction, flow strength, terrain contact/protrusion, and bank response if available.
- Before/after captures at the same camera locations after any fix.
- Human-visible Godot review for the final result, because headless probes cannot prove surface rendering, shader visuals, or editor debug-view readability.

## Performance Requirements

- Diagnosis probes may be slower than production code if they are clearly marked as validation-only.
- Any production bake change must record bake-time impact before becoming default behavior.
- Runtime shader changes should not add new texture reads unless the plan justifies them and validation records the cost/risk.

## Open Questions

- Which scene(s), camera locations, debug views, and bakes correspond to the reported bank-flow screenshots?
- Do the residual small holes line up with occupancy solids, bank/collider footprints, mesh intersections, shader depth/alpha clipping, or only camera/view direction?
- Are residual small holes reproducible in debug/solid views, or only in normal shaded water from certain angles?
- Are bank inward patches high-magnitude actual flow, or low-magnitude residuals/debug arrow artifacts?
- Does the bank-flow issue occur near seams, tile boundaries, tight bends, protrusions, or isolated bank mask speckles?

## Resolved Questions

Move questions here once decided so future sessions do not keep treating them as open.

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Which layer caused the reported missing-water gaps? | Collision occupancy false positive from top-down/down-ray hits over open waterline. | 2026-06-15 | Focused probe at `Cliffs/cliff2` showed `current_upper_open 259 -> 0` after the code patch. |
| Are the obstacle gaps present after a fresh rebake on current code? | Large red-circled gaps improved/resolved, but smaller angle-dependent holes remain. | 2026-06-16 | User rebaked the river after the patch, then reported residual small holes around objects and banks from certain viewing angles. |
| What rule should override misleading upper geometry? | Actual waterline contact is required before top-down/down-ray collider hits can mark collision occupancy solid. | 2026-06-15 | Implemented in `generate_collisionmap()` with signature version 30. |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-15 | Create `river-waterline-bank-flow-corrections` as a fresh diagnosis-first feature folder. | The reported issues overlap prior obstacle/object work but need new screenshot/probe evidence before reusing or changing older fixes. |
| 2026-06-15 | Treat `river-obstacle-flow-constraints` as the primary regression baseline. | User clarified the older fixes worked for a while and may have been lost; current work should recover documented behavior before inventing replacement designs. |
| 2026-06-15 | Require waterline contact for top-down/down-ray collision occupancy. | Focused probe showed upper geometry still clipping open waterline at the reported overhang locations. |
| 2026-06-16 | Mark the large missing-water issue improved/resolved after user rebake, but keep residual angle-dependent holes open. | User rebaked the affected river after the patch, confirmed the large red-circled gaps were gone/improved, then reported smaller holes visible from certain angles. |
