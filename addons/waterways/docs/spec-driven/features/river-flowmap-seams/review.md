# Review: River Flowmap Seam Handling

## Review Date

2026-06-11

## Scope Reviewed

- `Revised plan to improve seam handling v2.md`
- Feature-folder templates under `addons/waterways/docs/spec-driven/templates/feature-folder`
- Existing river-flowmap-seams documents, audit notes, and probe references
- `addons/waterways/docs/research/river-research-citations.md` is referenced as the shared citation index; no new external sources were added in this documentation-only pass.

## Current Truth

- Overall review status: Baseline complete; no current visible seam found.
- Blocking issues remaining: none for the v2 baseline prerequisite.
- Important issues remaining: depth-1 bilinear bleed, normal/tangent continuity, temporal reset confirmation, and offset-helper ablation are unrun and now conditional on reproducing a visible seam or a user request for extra diagnostics.
- Last validation relied on: 2026-06-11 visible baseline export marker `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`, plus prior signature 23 probe markers from `changelog.md` and the 2026-06-11 seam audit.
- Next action: stop implementation for now; do not patch seam handling from the stale pre-signature-23 visible list unless a current seam is reproduced.
- Historical detail starts at: `Revised plan to improve seam handling v2.md` and `audit/seam-handling-audit-2026-06-11.md`.

## Findings

### Blocking

- None after the 2026-06-11 baseline pass. The current post-signature-23 visible seam status is recorded.

### Important

- First-class baseline finding: no visible straight seam remains post-signature-23 in `Demo.tscn` or `Demo_obstacle_flow_test.tscn` in the reviewed lit-water, raw baked channel, and derived/material debug screenshots. There are 0 current seam records to classify by join index, same-column, row-wrap, or column X-edge band.
- Demo material overrides do not enable the zero-default pillow offset uniforms. `pillow_forward_reach_tiles` and `pillow_contact_pull_strength` are `0.0` in both scenes; `pillow_height_smoothing_tiles` is live at `0.1`.
- Depth-1 bilinear bleed remains an unrun conditional hypothesis, but there is no current visible seam to correlate against.
- Lateral cross-column reads remain the smallest named unprotected offset class. If future ablation implicates offset sampling, Build C should be considered before strip packing or the logical sampler.
- Mesh normal/tangent discontinuity remains a conditional lit-only hypothesis only if a future visible seam appears in lit water but not unshaded debug views.
- Strip packing should not be built unless new visible evidence points to row-wrap joins or column X-edge bands and the feasibility spike is small.

### Minor

- `textures/flow_offset_noise.png` being unused should not be interpreted as a missing temporal mechanism; v2 states phase noise is already provided through `flow_foam_noise.a`.
- The v1 revision remains useful historical context but should not drive task order.

## Premise Review

- Was the original premise correct, partially correct, or wrong?
  - Currently unsupported as a live visible problem in the two demo scenes. Exact edge-row bake seams were fixed and probe-validated, and the 2026-06-11 baseline found no remaining visible straight seam.
- Did any evidence suggest the user or agent was overlooking scene/data/context?
  - Yes. The older visible reports were stale after signature 23 for the reviewed scenes.
- If yes, was that raised with the user early enough?
  - Yes. The baseline was recorded before implementation tasks began.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation?
  - Docs/validation clarification for now. No code/design fix is warranted by the current visible baseline.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Existing signature 23 probes still pass | Partial | Prior pass is recorded; should be rerun after changes. |
| Baseline capture records current visible seam status | Pass | 2026-06-11 visible baseline export and screenshot review found no visible seam in either scene. |
| Seams are classified by join index and view type | Not applicable | 0 current visible seams were found; no join-index records exist. |
| Depth-1 probe is recorded and correlated | Deferred | No visible seam baseline exists to correlate against. |
| Ablation identifies or clears helper groups | Deferred | No visible seam currently exists to ablate. |
| Build C is validated if implemented | Not applicable | Conditional. |
| Build A/B diagnostics pass if implemented | Not applicable | Conditional. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Partial
- Editor/runtime boundary preserved: Partial
- Bake data and generated resources explicit: Partial
- Legacy Godot 3 behavior used only as reference: Yes
- Extension points preserved: Partial
- Godot-native features preferred where practical: Partial
- Bespoke systems justified: Partial
- Comments explain non-obvious intent without restating obvious code: Not applicable
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Partial

## Validation Results

- Automated:
  - Prior signature 23 probe markers are recorded in existing docs. The 2026-06-11 baseline exporter also produced `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`.
- Human-assisted:
  - No separate user-run editor review recorded; agent reviewed exported screenshots from both demo scenes.
- Shader:
  - Runtime ablations not run because no visible seam remains.
- Editor:
  - Demo material override state recorded by static scan/exporter report.
- Visual:
  - Pass for current baseline: no visible seam in lit, raw debug, or derived/material debug captures.
- Bake output:
  - Prior signature 23 probe work exists; depth-1 behavior remains unproven.
- Runtime:
  - Temporal quick confirmation not run because no visible seam or pulse was observed in the static baseline captures.
- Performance:
  - Not applicable until a fix lands or a spike is opened.
- Manual:
  - Not run.

## Documentation Consistency Check

- [ ] Closed tasks are checked off in `tasks.md`.
- [ ] No stale "open follow-up" language remains for completed work.
- [ ] Resolved open questions moved to `spec.md` resolved questions or decision log.
- [ ] `plan.md` reflects actual architecture and lifecycle behavior.
- [ ] `validation.md` current snapshot and matrix match the detailed recorded results.
- [ ] Latest handoff points to the true next action.
- [ ] Shared works-cited index checked or updated: `addons/waterways/docs/research/river-research-citations.md`.

## Follow-Up Tasks

- [x] Run baseline visible classification in both demo scenes.
- [x] Check demo material overrides for zero-default pillow uniforms.
- [ ] Add or run the depth-1 bilinear-bleed probe only if a current visible seam is reproduced or extra diagnostics are requested.
- [ ] Run normal/tangent continuity check only if a lit-only seam is reproduced.
- [ ] Run temporal quick confirmation only if a visible pulse or seam is reproduced.
- [ ] Run individual offset-helper ablations only if a visible seam is reproduced.
- [ ] Decide whether Build C, a depth-1 bake decision, a normal/tangent fix, Build A, or Build B is actually warranted if new evidence appears.

## Decision Updates

Record any spec or plan changes discovered during review.

- 2026-06-11: v2 is the controlling plan for this feature folder.
- 2026-06-11: baseline diagnosis is a blocking prerequisite for implementation.
- 2026-06-11: baseline diagnosis found no visible seam in either demo scene; implementation should not continue from stale pre-signature-23 symptoms.
