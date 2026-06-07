# Review: River Ripples

## Review Date

2026-06-07

## Scope Reviewed

- `addons/waterways/docs/roadmaps/runtime-ripple-simulation-roadmap.md`
- `addons/waterways/docs/spec-driven/templates/feature-folder/`
- `addons/waterways/docs/spec-driven/00-constitution.md`
- `addons/waterways/docs/spec-driven/01-workflow.md`
- Existing feature-folder style from `addons/waterways/docs/spec-driven/features/river-eddies/`
- This newly created `river-ripples` feature folder
- `addons/waterways/docs/research/river-research-citations.md` should be checked before external research-driven implementation changes.

## Current Truth

Use this as the review dashboard. Keep it concise and update it before handing off.

- Overall review status: Partial.
- Blocking issues remaining: None for the documentation scaffold; implementation is intentionally unstarted.
- Important issues remaining: Phase 0 decisions must be locked before code, shader, scene, material, or generated-resource edits.
- Last validation relied on: Documentation-only file creation, template alignment, and roadmap-detail consistency checks; no Godot runtime validation.
- Next action: Resolve Phase 0 decisions and branch safety, then build the standalone no-readback feedback spike.
- Historical detail starts at: `Decision Updates`.

## Findings

### Blocking

- None for this documentation-only pass.

### Important

- Phase 0 decisions are still open: first demo scenario, field transform support, public/prototype node registration, debug parity path, emitter targeting model, renderer target, and exact material ownership implementation.
- The feedback path is still unproven in Godot 4.6+. Do not integrate with `river.gdshader` until the no-readback ping-pong spike passes.
- Boundary masking is a hard gate for visible river integration. A rectangular debug ripple texture is not enough.
- Material ownership is a hard gate. Shared material mutation could affect unrelated rivers or leave stale runtime textures.

### Minor

- The shared citations index already records the CBerry22 ripple simulation repository, so no citation update was needed for this docs-only pass.

## Premise Review

- Was the original premise correct, partially correct, or wrong?
  - Correct for documentation setup: the roadmap is substantial enough to deserve a dedicated spec-driven feature folder.
- Did any evidence suggest the user or agent was overlooking scene/data/context?
  - The roadmap itself warns that visual ripples are easy to confuse with flow or physics changes.
- If yes, was that raised with the user early enough?
  - Captured in `spec.md`, `plan.md`, `research.md`, `tasks.md`, `validation.md`, and `handoff-latest.md`.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation?
  - Documentation and validation clarification only.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Create a `river-ripples` feature folder | Pass | Folder created under `addons/waterways/docs/spec-driven/features/`. |
| Generate docs from feature-folder templates | Pass | Created `spec.md`, `plan.md`, `tasks.md`, `research.md`, `validation.md`, `review.md`, and workflow-renamed `handoff-latest.md`. |
| Preserve roadmap constraints | Pass | Docs preserve visual-only scope, no-readback requirement, mapping, boundary, material ownership, debug, registration, shader cost gates, concrete `i_ripple_*` uniforms, field properties, emitter properties, and authoring-control notes. |
| Validate runtime ripple behavior | Not applicable | No implementation exists yet. |
| Validate Godot editor/runtime visuals | Not applicable | No scene or shader changes exist yet. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes.
- Editor/runtime boundary preserved: Yes in docs; unproven in implementation.
- Bake data and generated resources explicit: Yes; first pass requires no bake/data changes.
- Legacy Godot 3 behavior used only as reference: Yes.
- Extension points preserved: Yes in docs; planned but not implemented.
- Godot-native features preferred where practical: Partial; viewport feedback needs a spike.
- Bespoke systems justified: Partial; runtime feedback is justified by feature needs but not yet proven.
- Comments explain non-obvious intent without restating obvious code: Not applicable; no code.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Yes for this new folder.

## Validation Results

- Automated:
  - Documentation-only file creation checks. No parser, shader, or Godot runtime checks were run.
- Human-assisted:
  - None.
- Shader:
  - None.
- Editor:
  - None.
- Visual:
  - None.
- Bake output:
  - None; no bake changes were made.
- Runtime:
  - None.
- Performance:
  - None.
- Manual:
  - Roadmap was mapped into the feature-folder structure and checked against workflow naming.

## Documentation Consistency Check

- [x] Closed tasks are checked off in `tasks.md`.
- [x] No stale "open follow-up" language remains for completed docs creation.
- [x] Resolved open questions moved to `spec.md` resolved questions or decision log where applicable.
- [x] `plan.md` reflects intended architecture and lifecycle behavior from the roadmap.
- [x] `validation.md` current snapshot and matrix match the current unrun status.
- [x] Latest handoff points to the true next action.
- [x] Shared works-cited index checked or updated: `addons/waterways/docs/research/river-research-citations.md`.

## Follow-Up Tasks

- [ ] Lock Phase 0 decisions with the user.
- [ ] Create or confirm a feature branch before implementation.
- [ ] Build the standalone no-readback ripple feedback spike.
- [ ] Add the first mapping and boundary-mask probes before river shader integration.
- [ ] Update this review after the first validation run.

## Decision Updates

Record any spec or plan changes discovered during review.

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-07 | Use `handoff-latest.md` instead of `session-handoff.md`. | `01-workflow.md` says copied feature folders should rename the handoff template. |
| 2026-06-07 | Keep this pass documentation-only. | The user asked for the feature folder and generated docs, not implementation. |
| 2026-06-07 | Treat Phase 0 decisions as prerequisites, not hidden assumptions. | The roadmap names them as safety gates before visible river integration. |
| 2026-06-07 | Preserve concrete roadmap details in the feature docs. | Exact field properties, emitter properties, `i_ripple_*` uniforms, and authoring controls were too easy to lose in the first translation. |
| 2026-06-07 | Split broad Phase 0 safety scope into separate task gates. | Source signatures, river bakes, WaterSystem behavior, and buoyancy deserve independent confirmation before implementation. |
