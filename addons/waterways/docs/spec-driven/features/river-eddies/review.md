# Review: River Eddies

## Review Date

2026-06-04

## Scope Reviewed

- `addons/waterways/docs/spec-driven/features/river-eddies/spec.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/plan.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/research.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/tasks.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/validation.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/handoff-latest.md`
- Spec-driven templates under `addons/waterways/docs/spec-driven/templates/feature-folder/`
- `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index reference; no new external citations were added in this docs style pass.
- Historical 2026-05-31 migration sources preserved in this folder: `docs/history/CHANGELOG.md`, `docs/handoffs/handoff-latest.md`, `docs/roadmaps/river-feature-detection-roadmap.md`, `docs/roadmaps/river-improvements-roadmap.md`, and current wake/eddy-line workstream state from Phase 7A0 through Phase 7B.

## Current Truth

Use this as the review dashboard. Lead with unresolved risks and next action; keep detailed compliance checks and history lower in the file.

- Overall review status: Pass for 2026-06-04 docs style refresh and accepted Phase 7B visual baseline; partial for future Phase 7C/7D flow.
- Blocking issues remaining: None for preserving Phase 7B or this docs style refresh; Phase 7C requires a new plan before code.
- Important issues remaining: Real reverse/circulating flow has no accepted data model or runtime validation yet.
- Last validation relied on: Historical Phase 7B Godot 4.6.3 probes and user viewport acceptance.
- Next action: Use this feature folder before any future wake/eddy edit; classify requests by raw source, final mask, visible response, or final-flow/physics layer.
- Historical detail starts at: `Historical Review Notes`

## Findings

### Blocking

- No blocking issue for the current docs style refresh or accepted Phase 7B visual baseline.
- Actual reverse/circulating flow is blocked on a Phase 7C plan that includes visible shader, debug shader, system-flow shader, WaterSystem generation, and runtime validation together.

### Important

- Phase 7B is visual-only. It does not change source flow, final flow, reverse flow, WaterSystem generation, or saved WaterSystem bakes.
- The accepted eddy-line fix was channel/phase alignment: raw B was plausible but too far from source rocks, while raw G produced the accepted paired wake-edge margins.
- `wake_edge_sample_tiles = 0.024` is part of the accepted baseline only with the raw-G wake-edge source. The edge-sample-only fix was rejected.
- Old raw-B diagnostic paths should remain available because they explain the rejected path and are useful for regression review.
- User viewport confirmation was the acceptance signal; exports and probes support the evidence but do not replace visible review.
- Any future classifier change touching `obstacle_features` can affect pillows, wakes, eddy lines, and confidence, so Phase 7B probes should be rerun after shared edits.
- Future visible eddy-line foam can easily read as shoreline foam if the mask follows broad banks. Keep material response restrained unless the mask is trusted.

### Minor

- The original eddy/wake history was split across the general changelog, shared handoff, and roadmaps. This feature folder now gives future sessions a cleaner start point.
- A future include/shared helper for duplicated visible/debug wake/eddy math may be useful, but only after the current behavior is stable and covered by parity checks.

## Premise Review

- Was the original premise correct, partially correct, or wrong?
  - Correct for docs migration and style refresh: the eddy work needed a feature-local source of truth, and the folder needed to match the newer template conventions.
- Did any evidence suggest the user or agent was overlooking scene/data/context?
  - Yes. Earlier Phase 7B review showed stronger or wider edge sampling alone was not enough, and the old raw-B source was spatially wrong despite being semantically plausible.
- If yes, was that raised with the user early enough?
  - The current handoff and roadmaps now preserve the channel/phase alignment lesson and the raw/final/visible review loop.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation?
  - This pass produced documentation and validation clarification only.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Phase 7B visual preview accepted | Pass | User accepted visible result after override fix and stronger defaults. |
| `Eddy-Line Visual Mask` uses raw-G candidate at `0.024` | Pass historically | This is the documented baseline. |
| Old raw-B diagnostics preserved | Pass historically | Must re-check after debug menu/shader edits. |
| Raw/final/visible review order followed | Pass in docs | Must be repeated for future issues. |
| Start-of-river hotspot excluded from acceptance | Pass in docs | Must be repeated in viewport review. |
| Ordinary banks do not become long eddy-line strips | Partial/pass historically | Recheck after future changes. |
| Phase 7B remains visual-only | Pass historically | No flow, WaterSystem, source-signature, or bake change. |
| Phase 7C has visible/debug/system-flow/WaterSystem parity | Deferred | No Phase 7C implementation yet. |
| Human-assisted validation steps included | Pass in docs | `validation.md` includes exact request; future chat must paste it. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes
- Editor/runtime boundary preserved: Yes for Phase 7B; future Phase 7C pending
- Bake data and generated resources explicit: Yes historically
- Legacy Godot 3 behavior used only as reference: Not applicable
- Extension points preserved: Yes
- Godot-native features preferred where practical: Yes
- Bespoke systems justified: Yes, because wake/eddy masks are Waterways-specific bake/shader data
- Comments explain non-obvious intent without restating obvious code: Not reviewed in this docs pass
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Yes for this feature folder

## Validation Results

- Automated:
  - Historical: `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`
  - Historical: `PHASE7B_WAKE_EDDY_EXPORT_OK`
  - Historical: `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`
  - Historical supporting checks: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, `PHASE7A2_WAKE_EDDY_EXPORT_OK`
  - Caveat: These are not proof of future visible/editor/runtime behavior after new edits.
- Human-assisted:
  - User rejected edge-sample-only fix.
  - User accepted raw-G wake-edge direction and later visible material pass.
  - Exact future request is recorded in `validation.md`.
- Shader:
  - Existing visible/debug wake/eddy shader paths passed historical probes.
- Editor:
  - Debug material override issue was fixed historically.
- Visual:
  - Current Phase 7B baseline accepted.
- Bake output:
  - Current river bakes are signature `19` after later pillow work; Phase 7B source behavior should be preserved on current bakes.
- Runtime:
  - Not scoped for Phase 7B.
- Performance:
  - Not changed in this docs pass.
- Manual:
  - Current review says do not start Phase 7C without a new plan.

## Documentation Consistency Check

- [x] Closed historical tasks are listed in `tasks.md`.
- [x] Current open tasks are visible in `tasks.md`.
- [x] Resolved questions moved to `spec.md`.
- [x] `plan.md` reflects current architecture and lifecycle behavior.
- [x] `validation.md` current snapshot and matrix match the handoff summary.
- [x] Latest feature handoff points to the true next action.
- [x] Relevant broader roadmap sections have been migrated into this feature folder.
- [x] Shared works-cited index is linked where the newer templates expect it; no new external sources were added in this style pass.

## Follow-Up Tasks

- [ ] Preserve accepted Phase 7B behavior after shared shader/classifier changes.
- [ ] Use the raw/final/visible review loop for future eddy issues.
- [ ] Add raw readings or named-region stats only if live review needs numeric support.
- [ ] Draft Phase 7C plan before any reverse/circulating flow implementation.

## Decision Updates

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-05-31 | Created `features/river-eddies/` as the feature-local source for wake/eddy-line work. | The general changelog, shared handoff, and roadmaps carried too much active Phase 7 state. |
| 2026-05-31 | Preserve Phase 7B as the current accepted visual baseline. | User accepted the visible material pass and no later eddy change superseded it. |
| 2026-05-31 | Record raw-G over raw-B as a channel/phase alignment decision. | Future sessions need to avoid repeating the edge-sample-only or raw-B exact-gate path. |
| 2026-05-31 | Treat Phase 7C/7D as deferred final-flow work. | Real reverse/circulating flow must update visible/debug/system-flow/WaterSystem/runtime validation together. |
| 2026-06-04 | Align the eddy feature folder with the newer feature-folder templates. | The docs already had strong content; the refresh adds current dashboards, shared citation reminders, Godot launch instructions, and handoff usage guidance. |

## Historical Review Notes

- Phase 7A0 completed adversarial review and roadmap revision.
- Phase 7A1 added review-only preflight/export helpers and found gated wake was plausible while old eddy-line/shear needed refinement.
- Phase 7A2 narrowed raw B and kept final-flow/WaterSystem unchanged.
- Phase 7B added visual-only wake/eddy material controls, masks, debug modes, probes, and exports.
- The edge-sample-only hypothesis was rejected.
- Raw-G wake-edge candidate was accepted for `Eddy-Line Visual Mask`.
- Debug-material override behavior was fixed so visible material fields work in Debug View Normal.
- Visible eddy-line defaults were strengthened after the first accepted placement was too subtle.
- User accepted the Phase 7B visual material pass.
