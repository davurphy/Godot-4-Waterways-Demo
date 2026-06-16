# Tasks: River Waterline and Bank Flow Corrections

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

## Current Truth

- Current status: Waterline overhang gap classified, patched, rebaked by the user, and visually resolved at the reported locations.
- Current implementation slice: waterline-contact gating for collision occupancy; bank-flow issue remains classification-only.
- Remaining open task count: 3.
- Last passing validation: 2026-06-16 user rebaked the affected river after the code fix and reported that the red-circled missing-water regions are resolved; 2026-06-15 `waterline_occupancy_probe.gd` after patch reported `current_upper_open=0` at `Cliffs/cliff2`.
- Next recommended action: classify the reported bank-inward-flow issue with focused magnitude/location evidence.
- Known deferred work: focused bank-inward-flow classification and any generated-resource hygiene the user wants after their rebake.

## Open Work

Use this section as the canonical checklist for unfinished work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff.

- [x] Create an evidence inventory from the user's screenshots.
  - Validate: each screenshot has scene, camera/location, debug view or normal view, visible symptom, suspected issue type, and whether a fresh rebake was used.

- [x] Compare current code and bake behavior against `river-obstacle-flow-constraints`.
  - Validate: list any missing or drifted mechanisms from the prior working fix, including `water_occupancy`, `flow_projected`, overhang/protrusion confidence, runtime slide gating, and FLOW_ARROWS low-speed handling.

- [x] Read the related prior feature folders before writing probes.
  - Validate: record the relevant prior assumptions from `river-obstacle-flow-constraints`, `river-object-artifacts`, and `river-flowmap-seams` in `research.md` or `review.md`.

- [x] Inspect the current code paths for occupancy, terrain-contact/protrusion, pressure projection, bank response, runtime flow adjustment, and debug arrows.
  - Validate: list exact files/functions and likely owning layers in `plan.md`.

- [x] Run or adapt existing non-destructive diagnostics first.
  - Validate: record which probes are safe, which rebake/save resources, and which results classify the reported locations.

- [x] Design `waterline_occupancy_probe.gd`.
  - Validate: probe plan can classify solid texels by collision/protrusion/source and compare them to waterline openness near reported obstacle gaps.

- [ ] Design `bank_inward_flow_probe.gd`.
  - Validate: probe plan defines local downstream tangent, inward/outward bank direction, open-water filtering, magnitude threshold, and isolation test.

- [x] Add probes only after deciding existing diagnostics are insufficient.
  - Validate: probes print stable markers and write optional local images under an ignored output folder.

- [x] Classify each reported obstacle gap.
  - Validate: label as occupancy false positive, legitimate collider footprint, stale bake, shader clip, debug artifact, or unknown.

- [ ] Classify each reported bank inward patch.
  - Validate: label as baked-flow defect, runtime shader defect, debug-view artifact, legitimate local behavior, stale bake, seam/tile issue, or unknown.

- [x] Pick the smallest implementation fix for each confirmed defect.
  - Validate: update `plan.md` risks, files to change, and branch safety state before code edits.

- [x] Implement the selected fix or document why scene/collider guidance is the correct outcome.
  - Validate: run the focused probe and relevant existing regression probes.

- [ ] Perform final human-assisted visual validation.
  - Validate: before/after screenshots at the same locations show the expected correction and no new obvious regression.
  - Status: waterline overhang gap passed after user rebake on 2026-06-16; bank-flow issue still needs its own final validation if fixed.

## Setup

- [ ] Confirm the current workspace state.
- [ ] Read `spec.md`, `plan.md`, and `validation.md`.
- [ ] Check `docs/research/river-research-citations.md` before research-driven changes; it is the shared works-cited list for river-reading, flow-map, shader-water, and production-reference sources, and should be updated when new cited sources affect this feature.
- [ ] For Godot-specific implementation work, search current official Godot documentation and API references online before patching; record sources that affect the implementation in `research.md` or the shared citations index.
- [ ] Check `audit/code-audit.md` for relevant known risks.
- [ ] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [ ] If running Godot, use the exact console/windowed launch instructions from `validation.md` or `handoff-latest.md`; console probes should use repo-local `.codex-research` user-data folders.
- [ ] Run the context challenge check: if the user or agent may be misreading expected behavior, stale generated data, validation geometry, or engine limitations as a defect, raise that with evidence before patching.
- [ ] Before implementation, remind the user to create/switch to a dedicated branch or ask Codex to do it.
- [ ] Treat `../river-obstacle-flow-constraints/` as the primary regression baseline before designing new behavior.

## Implementation

- [ ] Define the screenshot/evidence inventory format.
  - Validate: one example entry is recorded in `validation.md` or a later evidence document.

- [x] Build the prior-fix comparison checklist.
  - Validate: every documented older mechanism has a current-code/current-bake status: present, missing, drifted, stale-data only, or unknown.

- [x] Identify safe existing probes.
  - Validate: every probe that can save bakes is marked with a warning before it is run.

- [x] Add focused probes if needed.
  - Validate: probes parse/run in the intended Godot environment and print stable pass/fail or report markers.

- [x] Implement confirmed waterline/occupancy fix.
  - Validate: true solids remain clipped; false-positive open-water gaps are restored.

- [ ] Implement confirmed bank-flow fix.
  - Validate: isolated inward patches are gone; seam and obstacle-flow regressions pass.

## Validation

- [x] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge check after validation: if results suggest the premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in the chat message to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene, if applicable, through human-assisted validation unless the agent can genuinely use the visible editor.
- [ ] Check shader output/debug views, if applicable, through human-assisted validation.
- [ ] Check editor workflow, if applicable, through human-assisted validation.
- [ ] Check runtime sampling/API behavior, if applicable, through human-assisted validation or a proven non-crashing runtime check.
- [ ] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] If validation used a scratch project, confirm active add-on scripts were mirrored there before running probes.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries.
- [ ] Update docs for any changed decisions.
- [ ] Update feature or architecture documentation for changed behavior, data flow, module boundaries, or validation procedures.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

- [x] Create `addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/`.
- [x] Scaffold feature documents from the template set.
