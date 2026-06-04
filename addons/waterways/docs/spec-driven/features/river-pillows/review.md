# Review: River Pillows

## Review Date

2026-05-31

## Scope Reviewed

- `addons/waterways/docs/history/CHANGELOG.md`
- `addons/waterways/docs/handoffs/handoff-latest.md`
- `addons/waterways/docs/roadmaps/river-feature-detection-roadmap.md`
- `addons/waterways/docs/roadmaps/river-improvements-roadmap.md`
- `addons/waterways/docs/research/river-research-citations.md`
- `addons/waterways/docs/audit/pillow-system-audit.md`
- Spec-driven templates under `addons/waterways/docs/spec-driven/templates/feature-folder/`
- Current pillow workstream state from Phase 6A through Phase 6F

## Current Truth

This is the review dashboard. Lead with unresolved risks and next action; keep detailed findings, compliance checks, and history lower in the file.

- Overall review status: Partial
- Blocking issues remaining: Human-visible placement review and a WaterSystem bake decision remain before finalizing this slice.
- Important issues remaining: The remaining forward pillow offset was attributed to the broad bank-response/combined contact gate on the prior review. Direct-contact-first code exists, `Demo.tscn` has been reset to the placement-review baseline, and both review river bakes are verified signature `20`.
- Last validation relied on: Historical Phase 6 and Phase 7 Godot 4.6.3 probes, the 2026-05-31 user live Godot review, 2026-06-01 static checks for new debug-mode wiring and normalized obstacle-test review state, a 2026-06-04 review-only engineering audit using static scans, post-rebake Godot metadata verification, the requested CPU/readback diagnostic, and the 2026-06-04 feature-local consolidated pillow probes.
- Next action: Review raw/final/source-term views around the same rock targets in Godot on both signature-`20` bakes.
- Historical detail starts at: `Historical Review Notes`

## Findings

### Blocking

- The next implementation should not proceed as another distance tweak. The audit says source-term evidence is needed before changing the classifier.
- `Pillow Visual Mask` currently reads as undifferentiated green in the user's viewport. Debug mode `58`, `Pillow Visual Mask (Black Zero)`, now exists as the true Black Zero version of mode `26`; mode `48`, `Pillow No-Reach Mask (Black Zero)`, remains available for no-reach final-mask placement review. Both still need visible Godot confirmation.
- 2026-06-04 engineering audit found mode `48` is not just a palette variant: it renders the no-reach final mask, while mode `26` renders the current `pillow_visual` mask that can include reach/contact-pull when those controls are non-default.
- 2026-06-04 engineering audit found `Demo.tscn` saved non-baseline pillow material values, including high foam bias and obstruction height. First audit follow-up reset the scene to the placement-review baseline.
- 2026-06-04 post-rebake Godot metadata verification now confirms both review river bakes are signature `20`.
- Pillow support/facing source is bake-only and is not saved in `RiverBakeData`; if signature-`20` raw R still starts too early, target-bound probe output is required before further classifier edits.
- The 2026-06-01 user review resolved the first source question: bank-response/combined contact is too broad, direct terrain contact is closest to desired placement, and the raw classifier should be direct-contact-first. The new code needs a signature-`20` rebake before acceptance.

### Important

- Raw `obstacle_features.r` is now the main suspect for the remaining forward start because visible forward reach and contact-pull defaults are off.
- User-visible review confirms `Pillow / Impact Mask` and final visible water start about `0.3` to `0.5` ahead of the intended obstruction contact point.
- `bank_response_features.a` may be too broad for pillow anchoring because it includes forward protrusion context.
- The generic dilated collision support texture may let pillow support/facing become active before visible contact.
- The audit found about `35%` of raw pillow pixels above `0.05` are strongly bank-response anchored while direct protrusion is weak or absent, making direct-contact-first anchoring the leading formula direction.
- Any bake/classifier change must preserve accepted Phase 7B eddy-line behavior and avoid unintended WaterSystem changes.
- The feature-detection roadmap makes the review method explicit: raw source, final visual mask, visible material response, then smallest scoped change.
- Acceptance needs more than a fixed screenshot. The user should confirm target semantics in the editor/runtime viewport, supported by captures or readings.
- Generalization matters. A fix that only works in one demo camera should stay experimental.

### Minor

- The original pillow history was split across the general changelog, shared handoff, and roadmaps. This feature folder now gives future sessions a cleaner start point.
- Visible/debug shader helper duplication is a medium drift risk; consider `.gdshaderinc` only after the next formula is agreed.
- Debug shader bake constants for pillow contact diagnostics are duplicated from `river_manager.gd` and the filter shader; `addons/waterways/docs/spec-driven/features/river-pillows/probes/pillow_diagnostic_parity_check.gd` now protects this with `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`.

## Premise Review

- Was the original premise correct, partially correct, or wrong?
  - Partially correct. There is likely a real placement issue, but its cause should not be assumed to be the explicit `0.07` contact-search distance.
- Did any evidence suggest the user or agent was overlooking scene/data/context?
  - Yes. Earlier review showed shader forward reach caused one visible offset, then later review showed the remaining offset can come from raw baked formula terms.
- If yes, was that raised with the user early enough?
  - The current handoff now asks for diagnostic split output and formula review before patching again.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation?
  - This review produced documentation and validation clarification only.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Raw and final pillow masks separately inspectable | Partial | Existing views are available, mode `58` is the true Black Zero visual mask, and mode `48` is the no-reach final mask. Visible Godot review still needs to confirm readability. |
| Pillow starts at upstream impact/compression faces | Fail/Partial | User confirms raw and visible starts are about `0.3` to `0.5` too far ahead. |
| `Pillow Visual Mask` is readable for final-mask placement | Partial | Original mode remains ambiguous; new Black Zero mode added for review. |
| Open water far ahead of rocks stays quiet | Partial | Needs target review. |
| Ordinary banks do not become pillow lines | Partial | Needs current review after any future changes. |
| Main and obstacle-test layouts agree | Partial | Roadmap requires more than one layout before acceptance. |
| Raw/final/visible review order followed | Pass in docs | Next live review still needed. |
| Audit diagnostic split exists before classifier edit | Partial | Saved-term editor diagnostics exist; support/facing still needs target-bound probe output or a promoted bake diagnostic. |
| Bank response cannot anchor raw pillows alone | Partial | Signature-`20` metadata records direct-contact-first anchoring and the current anchor-source probe passes, but it still reports bank-response context around some raw pixels; live target review remains the acceptance gate. |
| Material tuning deferred until placement accepted | Pass | Current docs preserve this rule. |
| Accepted Phase 7B eddy-line behavior preserved | Pass historically | Must re-check after shared classifier edits. |
| WaterSystem untouched for pillow-only work | Partial/needs decision | The user's 2026-06-04 main-demo rebake modified `WaterSystem.water_system_bake.res`; decide whether to keep, review, or revert it before finalizing. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes
- Editor/runtime boundary preserved: Partial, pending any next implementation
- Bake data and generated resources explicit: Yes historically; must continue on next bake change
- Legacy Godot 3 behavior used only as reference: Not applicable
- Extension points preserved: Yes
- Godot-native features preferred where practical: Yes
- Bespoke systems justified: Yes, because pillow masks are Waterways-specific bake/shader data
- Comments explain non-obvious intent without restating obvious code: Not reviewed in this docs pass
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Yes for this feature folder

## Validation Results

- Automated:
  - Current: `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`
  - Current: `PILLOW_ANCHOR_SOURCE_PROBE_OK`
  - Current: `PILLOW_PLACEMENT_DIAGNOSTIC_OK`
  - Current: `PILLOW_INSPECTOR_WIRING_PROBE_OK`
  - Current quick smoke: `PILLOW_VISUAL_REVIEW_EXPORT_OK`
  - Audit archive: `PILLOW_FORMULA_ANCHOR_AUDIT_OK`, with high-risk bank-response anchoring found on the previous formula generation.
  - Historical: `PHASE6A_PILLOW_VISUAL_PROBE_OK`
  - Historical: `PHASE6B_PILLOW_TUNING_PROBE_OK`
  - Historical: `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`
  - Historical: `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`
  - Historical: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`
  - Historical: `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`
  - Historical: `DEBUG_VIEW_MENU_WIRING_PROBE_OK`
  - Historical: `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`
  - Historical: `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`
  - Caveat: These are not proof that the current visible pillow placement is accepted.
- Human-assisted:
  - User reports pillows still start too far ahead after Phase 6E.
  - On 2026-05-31, user confirmed raw `Pillow / Impact Mask` and final visible water start about `0.3` to `0.5` ahead of the desired obstruction contact point.
  - User reports the original `Pillow Visual Mask` is undifferentiated green over the river, so use `Pillow Visual Mask (Black Zero)` for the next review.
  - On 2026-06-01, the obstacle-test scene's saved pillow review material state was normalized.
  - Later on 2026-06-01, user reviewed the new modes and identified broad bank-response/combined contact gating as the failing source.
  - Exact next request is recorded in `validation.md`.
- Shader:
  - Existing visible/debug pillow shader paths passed historical probes.
- Editor:
  - Editor wiring issue was fixed historically; broad no-op warning was later reverted after user clarification.
- Visual:
  - Needs new review at the same rock targets.
- Bake output:
  - Godot metadata verification confirms current review river bake output is matched: main and obstacle-test are both signature `20`.
- Runtime:
  - Not scoped for current pillow placement review.
- Performance:
  - Not changed in this docs pass.
- Manual:
  - Current review says diagnostic split plus formula review before classifier implementation.

## Documentation Consistency Check

- [x] Closed historical tasks are listed in `tasks.md`.
- [x] Current open task is visible in `tasks.md`.
- [x] Resolved questions moved to `spec.md`.
- [x] `plan.md` reflects current architecture and lifecycle behavior.
- [x] `validation.md` current snapshot and matrix match the handoff summary.
- [x] Latest feature handoff points to the true next action.
- [x] Relevant broader roadmap sections have been migrated into this feature folder.
- [x] Second-pass coverage added for exact Phase 6E constants, height seam-guard behavior, editor range-hint/material-sync details, and the fuller historical probe list.
- [x] Shared works-cited index path is recorded: `addons/waterways/docs/research/river-research-citations.md`. Future Codex sessions should use it for river-reading and water-rendering source context and update it when new cited research affects the feature.

## Follow-Up Tasks

- [x] Normalize or explicitly label `Demo.tscn` pillow material state before placement review.
- [x] Confirm the main river bake is direct-contact-first/signature-`20` after the 2026-06-04 user rebake.
- [x] Regenerate or verify the obstacle-test river bake to matching direct-contact-first/signature-`20` state.
- [x] Clarify mode `48` naming/semantics, and add a true Black Zero palette variant of mode `26`.
- [ ] Add audit-recommended support/facing probe output if signature-`20` raw R remains too early.
- [ ] Run the human-assisted formula review in `validation.md`.
- [ ] If the direct-contact-first rebake still fails, revise raw R only after support/facing evidence identifies the failing source.
- [ ] Add raw readings or named-region stats only if the live review needs numeric support.

## Decision Updates

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-05-31 | Created `features/river-pillows/` as the feature-local source for pillow work. | The general changelog and handoff were carrying too much active pillow state. |
| 2026-05-31 | Treat current next step as formula review, not code. | Phase 6F evidence shows the cause may be combined source terms rather than one distance constant. |
| 2026-05-31 | Folded relevant roadmap sections into the feature docs. | The feature folder now carries review loop, definitions, generalization checks, raw-tooling expectations, Phase 6 design rules, and change boundaries. |
| 2026-05-31 | Promoted pillow audit findings into plan/tasks/roadmaps. | Audit severity makes diagnostic split the first implementation task and direct-contact-first anchoring the leading formula direction. |
| 2026-05-31 | Backfilled lower-level pillow details from the changelog and roadmap. | Exact constants, editor wiring, height seam guard, and probe names are operationally important for future sessions. |
| 2026-06-04 | Completed engineering audit and promoted findings into handoff/tasks/review/validation. | Next work should fix review-state and diagnostic consistency before placement tuning. |
| 2026-06-04 | Reset `Demo.tscn` pillow review state, split Black Zero/no-reach debug modes, added parity probe, and reran Godot diagnostics. | Next work should reconcile review bakes before live placement review. |
| 2026-06-04 | Verified the user-rebaked main river bake is signature `20`; then rebaked and verified the obstacle-test river bake to signature `20`. | Cross-scene placement review can proceed on matching river bakes; the modified WaterSystem bake still needs an explicit decision. |

## Historical Review Notes

- Phase 6A created the first visual pillow pass.
- Phase 6B added material controls and optional height response.
- Phase 6C diagnosed shader reach, set default reach to zero, and fixed editor range hints/material sync/revert behavior.
- Phase 6D tightened raw classifier anchoring and bumped bakes to signature `18`.
- Phase 6E halved contact-search distance from `0.14` to `0.07`, aligned fallback search from `0.02` to `0.01`, and bumped bakes to signature `19`.
- Phase 6F documented the current formula risk and recommended diagnostic split before more classifier changes.
