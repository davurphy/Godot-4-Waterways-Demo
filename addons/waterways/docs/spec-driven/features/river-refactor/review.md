# Review: River Refactor (Hardening + Refactor Track)

## Review Date

Not yet held — no implementation to review. The pre-implementation review that *has* happened is the adversarial review of the audit/roadmap (2026-06-12); its outcomes are recorded under Premise Review and in `spec.md` Resolved Questions.

## Scope Reviewed

- (Per-phase, as phases land) Files, scenes, resources, shaders, editor tools, or behaviors reviewed.
- `addons/waterways/docs/research/river-research-citations.md` when external river, water, shader, or production references shaped the feature decision.

## Current Truth

- Overall review status: Blocked — nothing implemented yet; first reviewable unit will be a Phase R0 item or RT.1
- Blocking issues remaining: none in code (none exists); process gates open: Adversarial Plan Review in `plan.md` not yet completed with the user; R6/R7 spec-plan-validation files not yet written; R7 compute decision not recorded
- Important issues remaining: none recorded
- Last validation relied on: none — `validation.md` matrix is entirely Unrun
- Next action: implement and review the first R0/RT slice; complete `plan.md`'s Adversarial Plan Review with the user before code changes
- Historical detail starts at: nothing archived yet

## Findings

### Blocking

- None yet.

### Important

- None yet.

### Minor

- None yet.

## Premise Review

This section already has pre-implementation content because the track's premise *was* formally reviewed (the 2026-06-12 adversarial pass over the audit):

- Was the original premise correct, partially correct, or wrong? Partially correct — the audit's defect findings held, but several specific claims were overturned: the ripple-displacement interface is live, not dead (R1.4); `reorder_params` removal is ordering-neutral (R0.6); the width-generation seed concern was withdrawn (R4.2); `Curve3D.get_closest_offset` is not a drop-in (R4.2).
- Did any evidence suggest the user or agent was overlooking scene/data/context? Yes — probes and feature specs consume interfaces the audit's grep missed, which produced the standing operating rule: grep shaders *and* probes *and* feature specs before deleting any uniform/function.
- If yes, was that raised with the user early enough? Yes — corrections are inline in `roadmap.md` before any implementation started.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation? A corrected plan: roadmap items were rewritten (delete → annotate for R1.4; drop-in → mapping-layer design for R4.2) before any code changed.

Per-phase implementations must redo this check against their own findings.

## Spec Compliance

Fill per phase as work lands; criteria come from `spec.md` Acceptance Tests.

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| R0 gate (debug parity, neutral distmap, mid-bake close, no-op click, probe markers) | Not run | |
| RT gate (known-good/known-bad demonstrations) | Not run | |
| R1 gate (stale detection, scoped diffs, zero code refs) | Not run | |
| R2 gate (RT.3 thresholds, duck behavior) | Not run | |
| R3 gate (3-renderer compile, RT.2 parity, revert checks) | Not run | |
| R4 gate (low-FPS ripple, hitch recovery, width parity, buoyancy binding, sleep) | Not run | |
| R5/R6 gate (byte-identical bakes, property-list diff, undo, abort matrix) | Not run | |
| R7 gate (f16 epsilon, ordering test, wall-clock budget) | Not run | |

## Architecture Compliance

To be answered per reviewed phase:

- Godot 4.6+ API target preserved: Not yet reviewed
- Editor/runtime boundary preserved: Not yet reviewed
- Bake data and generated resources explicit: Not yet reviewed
- Legacy Godot 3 behavior used only as reference: Not yet reviewed (R0.6 should make this trivially Yes — leftovers deleted)
- Extension points preserved: Not yet reviewed
- Godot-native features preferred where practical: Not yet reviewed (R3.3/R3.5 lean on `shader_get_parameter_default`; R4.2 on `Curve3D.get_closest_offset`)
- Bespoke systems justified: Not yet reviewed (RT tooling is bespoke by necessity — the gates it serves have no native equivalent)
- Comments explain non-obvious intent without restating obvious code: Not yet reviewed
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Not yet reviewed (Phase R8 owns the backlog)

## Validation Results

- Automated:
  - None run. Note for future entries: state whether the signal was only a parser/static/headless editor-load check.
  - Do not present headless/editor-load checks as proof of visible editor, shader, bake, or runtime behavior.
- Human-assisted:
  - None run. Record the exact request sent to the user, who ran it, date, Godot version/renderer/device, Output/console errors, and visible result.
- Shader: none
- Editor: none
- Visual: none
- Bake output: none
- Runtime: none
- Performance: none
- Manual: none

## Documentation Consistency Check

- [ ] Closed tasks are checked off in `tasks.md` (and the roadmap checklists).
- [ ] No stale "open follow-up" language remains for completed work.
- [ ] Resolved open questions moved to `spec.md` resolved questions or decision log.
- [ ] `plan.md` reflects actual architecture and lifecycle behavior.
- [ ] `validation.md` current snapshot and matrix match the detailed recorded results.
- [ ] Latest handoff points to the true next action.
- [ ] Shared works-cited index checked or updated: `addons/waterways/docs/research/river-research-citations.md`.

## Follow-Up Tasks

- [ ] Complete `plan.md`'s Adversarial Plan Review with the user before implementation starts.
- [ ] Write R6's own spec/plan/validation before R6 starts (constitution rule 12).
- [ ] Record the R7-vs-feature-Phase-5 compute decision, then write R7's own spec/plan/validation before R7 starts.

## Decision Updates

Record any spec or plan changes discovered during review. None yet — pre-implementation corrections are already folded into `roadmap.md` and `spec.md` Resolved Questions.
