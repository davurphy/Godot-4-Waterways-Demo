# Review: River Waterline and Bank Flow Corrections

## Review Date

2026-06-15

## Scope Reviewed

- Documentation scaffold for the new feature folder.
- Related local feature context:
  - `../river-obstacle-flow-constraints/`
  - `../river-object-artifacts/`
  - `../river-flowmap-seams/`
- `addons/waterways/docs/research/river-research-citations.md` should be checked when external river, water, shader, or production references shape the feature decision.

## Current Truth

- Overall review status: Waterline overhang issue fixed and visually validated after user rebake; bank-flow issue remains open.
- Blocking issues remaining: specific bank-inward-flow screenshot/location context is needed before code changes for that issue.
- Important issues remaining: identify whether the reported bank-flow symptom is generated data, shader/debug display, stale data, seam/tile behavior, scene geometry, or expected low-magnitude residual flow.
- Last validation relied on: 2026-06-16 user rebake after the waterline patch resolved the red-circled missing-water regions; 2026-06-15 focused probe showed `current_upper_open=0` after patch.
- Next action: classify one representative bank inward patch with magnitude and location evidence.
- Historical detail starts at: none yet.

## Findings

### Blocking

- Bank-inward-flow screenshot/location evidence is still not recorded, so that owning layer is unknown.
- No branch-safety decision has been recorded for future bank-flow code or generated-resource changes.

### Important

- Prior obstacle-flow docs claimed similar overhang/occupancy issues were already addressed, but focused probing found a remaining current-code edge case: top-down/down-ray collision hits could mark open waterline under overhangs as solid.
- User clarified that the older fixes worked for a while, so regression/lost-change is a leading hypothesis and the old docs should be treated as the primary baseline.
- Debug flow arrows can be misleading around solid-center samples and low-magnitude vectors; direction-only evidence is insufficient.
- Rebake probes may save generated resources, and the worktree already has an unrelated modified bake resource. Future validation must avoid overwriting user changes casually.

### Minor

- `waterline_occupancy_probe.gd` now covers the confirmed missing-water case; a bank-flow probe is still not designed.

## Premise Review

- Was the original premise correct, partially correct, or wrong?
  - Correct for the missing-water issue: a screenshot-specific waterline-contact edge case remained in collision occupancy and was fixed. Still unproven for the bank-flow issue.
- Did any evidence suggest the user or agent was overlooking scene/data/context?
  - Partly. Existing docs included similar fixed issues and debug-view caveats, but the user screenshots revealed a real remaining waterline occupancy defect.
- If yes, was that raised with the user early enough?
  - Yes for the waterline issue; the focused probe classified it before production code was patched.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation?
  - Code fix plus rebake for the missing-water issue; bank-flow outcome not decided.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Compare current project to old obstacle-flow baseline | Partial pass | Current code has the documented mechanisms; saved Demo bakes report projected occupancy data |
| Classify each screenshot symptom | Partial pass | Missing-water screenshots classified as collision occupancy false positives; bank-flow screenshots still needed |
| Add or identify probes | Partial pass | `waterline_occupancy_probe.gd` added for the confirmed gap; bank probe remains open |
| Fix confirmed obstacle gaps | Pass | User rebake after patch resolved the red-circled missing-water regions |
| Fix confirmed bank inward flow | Not started | Requires diagnosis |
| Preserve regressions | Not run | Existing obstacle/seam checks must be selected later |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes for docs; not applicable to implementation yet.
- Editor/runtime boundary preserved: Yes in plan; untested.
- Bake data and generated resources explicit: Partial; risks and candidate data are named.
- Legacy Godot 3 behavior used only as reference: Yes.
- Extension points preserved: Partial; to be decided after diagnosis.
- Godot-native features preferred where practical: Not applicable yet.
- Bespoke systems justified: Not applicable yet.
- Comments explain non-obvious intent without restating obvious code: Not applicable yet.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Feature docs only; no behavior changed.

## Validation Results

- Automated:
  - Static comparison against the prior obstacle-flow baseline found the required mechanisms present: `water_occupancy`, `flow_projected`, protrusion-confidence gating, projected-flow slide gates, and FLOW_ARROWS fallback/low-speed behavior.
  - Safe probe markers reached: `RIVER_OCCUPANCY_FLOW_INSPECT_DONE`, `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `SYSTEM_FLOW_COMPARE_OK` with `allow_stale=1`, `RIVER_FLOWMAP_SEAM_PROBE_OK`, `BAKE_INSPECT_OK`, and `WATERLINE_OCCUPANCY_PROBE_OK`.
  - Focused waterline probe after patch reported `current_upper_open=0` at `Cliffs/cliff2`.
  - Key caveat: `system_flow_compare_probe.gd` reported stale WaterSystem maps, so its thresholds remain report-only.
- Human-assisted:
  - User rebaked the affected river after the patch and reported the red-circled missing-water regions are resolved.
- Shader:
  - None.
- Editor:
  - None.
- Visual:
  - Missing-water issue passed after user rebake; bank-flow visual evidence remains open.
- Bake output:
  - Current saved Demo river bakes report `flow_projected=true`; main solid coverage 14.12%, obstacle-test solid coverage 14.78%.
- Runtime:
  - None.
- Performance:
  - None.
- Manual:
  - Documentation scaffold review only.

## Documentation Consistency Check

- [x] Closed tasks are checked off in `tasks.md`.
- [x] No stale "open follow-up" language remains for completed work.
- [x] Resolved open questions moved to `spec.md` resolved questions or decision log.
- [x] `plan.md` reflects current architecture intent and lifecycle behavior.
- [x] `validation.md` current snapshot and matrix match recorded safe-probe results.
- [x] Latest handoff points to the true next action.
- [ ] Shared works-cited index checked or updated: `addons/waterways/docs/research/river-research-citations.md`.

## Follow-Up Tasks

- [x] Add the user's missing-water screenshots and classify them.
- [x] Compare current code, material binding, metadata, and generated resources to the prior obstacle-flow documented mechanisms.
- [x] Confirm current branch/worktree state before running any rebake probe.
- [x] Choose safe existing probes to run before creating new probes.
- [x] Update this review after the first evidence pass.

## Decision Updates

Record any spec or plan changes discovered during review.

- 2026-06-16: Waterline overhang issue is fixed and visually confirmed after user rebake; keep bank-flow issue as the remaining open diagnosis target.
