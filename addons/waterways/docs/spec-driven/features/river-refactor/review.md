# Review: River Refactor (Hardening + Refactor Track)

## Review Date

No formal full-track review held yet. The pre-implementation adversarial review happened 2026-06-12; R4 implementation review closed as Pass on 2026-06-13 after the visible ripple fix; R5 structural-dedup review closed as Pass on 2026-06-13 with RT.1 scratch rebake hashes, property-list diff, and the R5 guard probe.

## Scope Reviewed

- (Per-phase, as phases land) Files, scenes, resources, shaders, editor tools, or behaviors reviewed.
- `addons/waterways/docs/research/river-research-citations.md` when external river, water, shader, or production references shaped the feature decision.

## Current Truth

- Overall review status: In progress — Phases R0, RT, R1, R2, R3, R4, R5, and R8 implemented, validated, and closed against their gates. R4 implementation landed 2026-06-13 and passed automated/headless guards after the visible ripple scheduling fix. R5 implementation landed 2026-06-13 and passed behavior-preservation gates: RT.1 generated texture hashes identical across both demo river bakes, property-list dump matched exactly, and `r5_behavior_preservation_probe.gd` passed. No formal full-track phase-review session held yet (per-item validation + user confirmations stood in, recorded in `validation.md`). The `river-obstacle-flow-constraints` folder got its own `review.md` in R8.3
- Blocking issues remaining: none known in landed code after R4 closure; process gates open: R6/R7 spec-plan-validation files not yet written; R7 compute decision not recorded; the formal Adversarial Plan Review in `plan.md` was never held (work proceeded with per-item user validation by accepted practice)
- Important issues remaining: two execution findings recorded in `spec.md` Resolved Questions (Defect-1 signature misattribution; dead ShaderMaterial revert fallback) — both resolved in code, and both now folded into the architecture docs by R8 (the obstacle mechanism rewrite + the revert behavior)
- Last validation relied on: 2026-06-13 R5 sweep — `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, RT.1 scratch rebake texture hashes identical across both generated demo river bakes, `R5_PROPERTY_LIST_MATCH=True`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, `FILTER_RENDERER_LOAD_OK shader_paths=19`, `SYSTEM_FLOW_PROJECTED_GATE_OK`, and `git diff --check`.
- Next action: write the required R6/R7 spec/plan/validation files before those phases start. R7 also needs the compute decision recorded.
- Historical detail starts at: nothing archived yet

## Findings

### Blocking

- None yet.

### Important

- The first R4 visible ripple review failed: the overlay stayed at `Queued 3 emitter impulses` and no localized ripple/influence appeared. Root cause was unsafe same-frame impulse render, simulation step, and impulse clear ordering; fix landed in `water_ripple_field.gd` and the user-visible rerun passed.

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
| R0 gate (debug parity, neutral distmap, mid-bake close, no-op click, probe markers) | Pass | Closed 2026-06-12; see `validation.md` recorded results |
| RT gate (known-good/known-bad demonstrations) | Pass | RT.1-RT.4 demonstrated 2026-06-12; see `validation.md` |
| R1 gate (stale detection, scoped diffs, zero code refs) | Pass | Closed 2026-06-12 after user rebake + RT.1 diff |
| R2 gate (RT.3 thresholds, duck behavior) | Pass | Closed 2026-06-12 with mechanism gate, regenerated v1 maps, and user editor round |
| R3 gate (3-renderer compile, RT.2 parity, revert checks) | Pass | Closed 2026-06-12 with RT.2 byte-identity and windowed checks |
| R8 gate (docs coherence) | Pass | Closed 2026-06-12; docs spot-checked against source and grep gates clean |
| R4 gate (low-FPS ripple, hitch recovery, width parity, buoyancy binding, sleep) | Pass | Implementation and headless guard pass 2026-06-13 (`R4_RUNTIME_ROBUSTNESS_PROBE_OK`); first visible ripple review failed, fix landed, post-fix agent captures and user rerun show rings; Checks 2-7 later passed by user in the editor/runtime suite |
| R5 gate (byte-identical bakes, property-list diff, undo) | Pass | Closed 2026-06-13 with scratch baseline-vs-R5 generated texture hashes, exact serialized property-list match, and `R5_BEHAVIOR_PRESERVATION_PROBE_OK` |
| R6 gate (byte-identical bakes, abort matrix, metadata dict diffs) | Not run | |
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
  - 2026-06-13 R4 implementation sweep: changed-script parser/check-only, `r4_runtime_robustness_probe.gd`, existing ripple probes, and core flow/bake probes passed. Signal is headless/non-visual only for R4.
  - 2026-06-13 post-visible-failure checks: parser/check-only, `r4_runtime_robustness_probe.gd`, existing ripple review/diagnostic probes, `r4_ripple_visible_auto_review.gd`, and `git diff --check` passed after the impulse scheduling fix.
  - 2026-06-13 R5 sweep: `r5_behavior_preservation_probe.gd`, RT.1 scratch rebake texture hashes, property-list dump compare, filter renderer load check, system-map renderer check-only, `system_flow_projected_gate_probe.gd`, `r4_runtime_robustness_probe.gd`, and `git diff --check` passed.
  - Do not present headless/editor-load checks as proof of visible editor, shader, bake, or runtime behavior.
- Human-assisted:
  - Initial R4 ripple visible review run by user failed: no visible ripple/influence, overlay stayed at `Queued 3 emitter impulses`. Agent fixed the reproduced issue; user rerun passed.
  - R4 involved live-editor suite passed after the fix: hitch recovery, 60 Hz emitter stress, curve editing, ripple inspector state, two-WaterSystem buoyancy coverage, and settled-body sleep.
- Shader: none
- Editor: none
- Visual: initial R4 ripple visible review failed; post-fix agent captures show localized impulse/contact and visible-influence rings; user rerun passed
- Bake output: none
- Runtime: R4 non-visual invariants covered headless; visible runtime stress pass closed by user confirmation
- Performance: R4 width-array parity covered headless; curve editing responsiveness passed by user confirmation
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
