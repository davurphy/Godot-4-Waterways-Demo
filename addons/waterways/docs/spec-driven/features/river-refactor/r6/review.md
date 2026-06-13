# Review: River Refactor R6 - river_manager.gd Decomposition

## Review Date

2026-06-13

## Scope Reviewed

- R6 documentation scaffold based on `plan.md`.
- Template compliance for feature-folder documents.
- No R6 implementation code reviewed yet.

## Current Truth

- Overall review status: Partial.
- Blocking issues remaining: no R6 implementation or validation has run; pre-R6 baselines are not captured; docs are not yet checked in.
- Important issues remaining: source timing must be validated before the baker snapshots state; abort matrix must include helper-internal awaits; runtime ripple and editor validation extractions need focused probe coverage.
- Last validation relied on: parent R5 validation from 2026-06-13, not R6-specific validation.
- Next action: review/check in the R6 documentation gate, then build and capture pre-R6 baselines.
- Historical detail starts at: none.

## Findings

### Blocking

- R6 implementation must not start until `spec.md` and `validation.md` are reviewed and checked in, and the canonical baseline format is available.
- No pre-R6 baseline dumps, property/API/signal dumps, source-image hashes, or fresh RT.1 scratch hashes exist yet.

### Important

- The source timing contract is the main behavioral risk. The default is to preserve mixed timing; any freeze-at-start change needs explicit proof.
- The abort matrix must include helper-internal awaits, not only awaits visible in `_generate_flowmap()`.
- `WaterHelperMethods` collision/terrain helper signatures are a reach-back hazard if they continue to accept a broad RiverManager argument.
- The constants table must not hide signature review decisions.

### Minor

- Decide early whether `BakeConfig`, `BakeResult`, and `BakeAbort` remain dictionaries or become typed `RefCounted` classes.
- Record exact scratch artifact paths as soon as validation begins.

## Premise Review

- Was the original premise correct, partially correct, or wrong? Correct. The parent track already identifies `river_manager.gd` decomposition as an R6 goal after R5 structural dedup.
- Did any evidence suggest the user or agent was overlooking scene/data/context? Not yet. The main possible misread is stale baseline data during future validation.
- If yes, was that raised with the user early enough? Not applicable yet.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation? Current outcome is docs/validation clarification only.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Generated texture hashes unchanged | Unproven | Requires RT.1 before/after comparison. |
| Intermediate source-image hashes unchanged | Unproven | Requires new/extended source-image hash probe. |
| Source signature and bake settings diffs empty | Unproven | Requires canonical dump probe. |
| Source metadata diff empty except `bake_revision` | Unproven | Requires canonical dump probe and allow-list enforcement. |
| Public API/signal surface unchanged | Unproven | Requires dump/diff. |
| Full inspector property list unchanged | Unproven | Requires dump/diff. |
| Runtime ripple behavior unchanged | Unproven | Requires existing and focused owner probes. |
| Editor validation markers unchanged | Unproven | Requires wrapper/menu marker checks. |
| Abort cleanup complete | Unproven | Requires abort matrix. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Partial; no code changed yet.
- Editor/runtime boundary preserved: Partial; spec records the boundary, implementation unreviewed.
- Bake data and generated resources explicit: Partial; validation format records requirements, implementation unreviewed.
- Legacy Godot 3 behavior used only as reference: Yes so far.
- Extension points preserved: Partial; planned modules are named, implementation unreviewed.
- Godot-native features preferred where practical: Unproven.
- Bespoke systems justified: Partial; baker/constants/ripple/editor helpers are justified by local architecture.
- Comments explain non-obvious intent without restating obvious code: Unproven.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Partial; R6 folder drafted, parent docs not updated until validation.

## Validation Results

- Automated: none for R6.
- Human-assisted: none for R6.
- Shader: no R6 shader change intended.
- Editor: unrun.
- Visual: unrun.
- Bake output: unrun.
- Runtime: unrun.
- Performance: unrun; R6 is not performance-gated except to avoid new avoidable waits/readbacks.
- Manual: documentation scaffold reviewed against `plan.md`.

## Documentation Consistency Check

- [ ] Closed tasks are checked off in `tasks.md`.
- [ ] No stale "open follow-up" language remains for completed work.
- [ ] Resolved open questions moved to `spec.md` resolved questions or decision log.
- [ ] `plan.md` reflects actual architecture and lifecycle behavior.
- [ ] `validation.md` current snapshot and matrix match detailed recorded results.
- [ ] Latest handoff points to the true next action.
- [ ] Shared works-cited index checked or updated if external sources influence R6.

## Follow-Up Tasks

- [ ] Review and check in the R6 documentation gate.
- [ ] Implement canonical dictionary dump probe.
- [ ] Capture pre-R6 baselines before code moves.
- [ ] Complete awaited operation and dependency inventory.
- [ ] Decide whether R6.3/R6.4 land before the bake pipeline extraction.

## Decision Updates

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-13 | R6 docs define preservation of mixed source timing as the default. | This is the safest behavior-preserving stance before implementation. |
