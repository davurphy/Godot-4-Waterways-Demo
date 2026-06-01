# Session Handoff: River Pillows

## Date

2026-05-31

## Current Focus

Create a feature-local spec-driven home for pillow placement work by converting the general changelog and latest handoff into focused feature documents.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-pillows\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: In progress
- Highest-priority open task: Add audit-recommended diagnostic split views/probe output plus a readable final-mask diagnostic before the next classifier edit.
- Last passing validation: Historical Phase 6/7 Godot 4.6.3 probes listed in `validation.md`, plus audit-reported `PILLOW_FORMULA_ANCHOR_AUDIT_OK`.
- Known failing or unproven check: User confirms raw `Pillow / Impact Mask` and final visible water start about `0.3` to `0.5` ahead of the desired obstruction contact point after Phase 6E; source term not isolated.
- Current debug-view issue: `Pillow Visual Mask` reads as undifferentiated green over the river. Static shader review shows zero maps to green, so add a clearer threshold/black-zero diagnostic before relying on that view for acceptance.
- Next recommended action: Add diagnostics for support/facing, direct terrain anchor, bank-response anchor, combined contact gate, and bank-only contribution, plus a readable final-mask view; then compare those views around the same rock targets in the editor.
- Packaging/artifact hygiene status: No new generated artifacts from this docs conversion.
- Historical detail starts at: `Historical Change Log`

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and `addons\waterways\docs\research\river-research-citations.md` only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-pillows\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-pillows\review.md`
6. `addons\waterways\docs\spec-driven\features\river-pillows\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-pillows\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-pillows\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-pillows\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Add or ask to add the audit-recommended diagnostic split before changing classifier constants.
- Add or ask to add a readable final-mask diagnostic if `Pillow Visual Mask` still appears all-green.
- Ask the user to run or join a dedicated pillow formula review after the split is available.
- Use the exact human-assisted validation request in `validation.md`.
- If the user wants Codex to implement immediately, push back gently: the current evidence says the next code change should depend on whether the offset starts in raw R, no-reach final mask, or visible material response.

## What Changed This Session

- `addons\waterways\docs\spec-driven\features\river-pillows\research.md`: Captured the current research conclusion and formula options.
- `addons\waterways\docs\spec-driven\features\river-pillows\spec.md`: Defined goals, non-goals, acceptance criteria, and current open questions.
- `addons\waterways\docs\spec-driven\features\river-pillows\plan.md`: Converted handoff guidance into a scoped diagnostic-first plan.
- `addons\waterways\docs\spec-driven\features\river-pillows\tasks.md`: Created the canonical open checklist for pillow work.
- `addons\waterways\docs\spec-driven\features\river-pillows\validation.md`: Created a validation matrix and exact human-assisted review request.
- `addons\waterways\docs\spec-driven\features\river-pillows\review.md`: Recorded the current review stance and risks.
- `addons\waterways\docs\spec-driven\features\river-pillows\handoff-latest.md`: Created this feature-local handoff.
- `addons\waterways\docs\roadmaps\river-feature-detection-roadmap.md` and `addons\waterways\docs\roadmaps\river-improvements-roadmap.md`: Read and folded relevant pillow sections into this feature folder.
- `addons\waterways\docs\audit\pillow-system-audit.md`: Read and promoted its severity-ranked findings into the feature plan, tasks, validation, review, and roadmaps.

## Current Changes Summary

- New feature folder: Consolidates pillow-specific state from the general changelog, latest handoff, and relevant roadmap sections into spec-driven docs.

## Historical Change Log

- Phase 5A/5B flow and SDF steering were accepted by the user as the baseline.
- Phase 6A added visual-only pillow highlights and the `Pillow Visual Mask`.
- Phase 6B added pillow tuning controls and optional default-off height response.
- Phase 6B's height response is split into terrain/obstruction height with `pillow_height_tile_seam_fade`; it remains a subtle default-off review accent, not a placement fix.
- Phase 6C diagnosed shader-side forward reach and changed default `pillow_forward_reach_tiles` to `0.0`.
- Phase 6C also fixed editor wiring by preserving height-curve range hints, syncing visible/debug material parameters, fixing material revert hooks, and resetting stale obstacle-demo overrides.
- Phase 6D moved into bake/classifier changes, tightened raw pillow anchoring, and bumped river bakes to signature `18`.
- Phase 6E halved pillow contact-search distance from `0.14` to `0.07`, aligned `pillow_contact_search_uv` from `0.02` to `0.01`, and bumped river bakes to signature `19`.
- Phase 6F documented that the explicit `0.07` contact search is not the full effective reach because `hard_boundary_at()` includes `bank_response.a`, which has its own forward-looking context.
- Phase 7B eddy-line visual work was accepted and should be preserved.
- The shared feature-detection roadmap now lives here as local rules: review raw source first, final mask second, visible material last; use screenshots as evidence but user viewport review as acceptance; check more than one layout before accepting a detector change.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create `features/river-pillows/`. | Pillow work needed a feature-local source of truth. | Use this folder before future pillow edits. |
| Treat diagnostic split plus formula review as the next action. | Evidence points to combined source terms, not only one distance value, and the audit says current views do not isolate the needed sub-terms. | Add split views/probe output, then run the validation request in `validation.md`. |
| Treat `Pillow Visual Mask` readability as a separate tooling issue. | User reports the view is undifferentiated green; shader review shows zero maps to green, so the palette can hide whether the final mask is actually broad or low. | Add a black-zero, threshold-band, or equivalent readable diagnostic before final-mask acceptance. |
| Keep code/bake changes out of this docs conversion. | The user asked to create the feature docs, and the next implementation depends on review. | Branch safety check before future code changes. |
| Fold roadmap rules into this feature folder. | The roadmaps contained pillow-specific review loop, generalization, and Phase 6 design rules. | Keep future pillow edits anchored here, then update broader roadmaps only when the high-level plan changes. |
| Promote audit diagnostics ahead of classifier edits. | The audit found about `35%` bank-response-only anchoring and says current views do not show the needed source split. | Add split views/probe output before changing raw R. |

## Current State

Implementation status:

- Existing pillow implementation is in progress; no code changed in this docs conversion.

Spec/plan status:

- Research: Current recommendation, roadmap research findings, and audit evidence captured.
- Spec: Drafted with feature definitions, review layers, and acceptance criteria.
- Plan: Drafted with diagnostic-first path and roadmap change boundaries.
- Tasks: Open checklist reordered by audit severity.
- Validation: Matrix, human-assisted request, generalization checks, raw-reading expectations, and audit probe expectations created.
- Review: Current risks, roadmap migration, and audit severity recorded.

Validation status:

- Automated:
  - Historical pass markers are listed in `validation.md`.
- Human-assisted:
  - User now confirmed raw and visible pillow starts are about `0.3` to `0.5` too far ahead, and `Pillow Visual Mask` is not readable because it appears all green.
  - Needed next: ask the user to compare raw/final/context views around the same target rocks after split diagnostics and a clearer final-mask view are available.
- Shader:
  - Existing pillow shaders passed historical probes, but placement remains under review.
- Editor:
  - Historical wiring issue fixed.
- Visual:
- User still reports forward offset after Phase 6E.
- Latest user detail: the raw `Pillow / Impact Mask` and final visible water both start about `0.3` to `0.5` too far ahead; final visible water is acceptable-ish but anatomically early compared with real pillow behavior.
- `Pillow Visual Mask` currently appears undifferentiated green over the river and should not be used alone for final-mask acceptance until readability is fixed.
- Runtime:
  - Not scoped.
- Performance:
  - Not changed.
- Manual:
  - Formula review required.

## Important Context

- Keep `pillow_forward_reach_tiles = 0.0` during placement review.
- Keep `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` default-off until raw/no-reach placement is understood.
- Current river bakes are signature `19`.
- The Phase 6E literal distance constants are not the full effective anchor reach because the contact gate samples up to `1.5x`, `hard_boundary_at()` can include `bank_response.a`, and raw source support is still broad.
- Historical coverage anchors: Phase 6A main raw R was about `8.08%` above `0.05`; Phase 6D raw R dropped to about `5.12%` main and `5.06%` obstacle-test; Phase 6E raw R dropped to about `4.70%` main and `4.61%` obstacle-test, with no-reach visual about `2.32%` main and `2.26%` obstacle-test.
- The saved WaterSystem bake was last regenerated after Phase 5B/signature `16`; do not regenerate it unless final/physics flow changes are scoped.
- Current likely formula risk: `hard_boundary_at()` uses `max(bank_response.a, terrain_contact.b)`, and `bank_response.a` includes forward-looking protrusion context.
- Current support risk: `pillow_source_at()` uses generic dilated collision support generated from `baking_dilate = 0.6`.
- Audit evidence: about `35.17%` of main-river and `35.88%` of obstacle-test raw pillow pixels above `0.05` are strongly `bank_response.a` anchored while direct `terrain_contact.b` is weak or absent.
- Leading formula direction if confirmed: direct `terrain_contact.b` or tight local direct-contact search should become mandatory or near-mandatory; `bank_response.a` should become weak context only.
- Do not change accepted Phase 7B eddy-line behavior while fixing pillows.
- Use the review order from the roadmap: raw source, final visual/debug mask, visible water. Patch only the layer that fails.
- Check both `Demo.tscn` and `Demo_obstacle_flow_test.tscn` before accepting a detector change.
- Add raw readings or named-region stats only when the visible review needs numeric support.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future Codex sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence pillow decisions.

## Artifact Hygiene

- Scratch folders or temporary projects created: None in this docs conversion.
- Generated bakes/resources created: None.
- Active files mirrored into scratch validation: Not applicable.
- Files/folders that must be excluded from packaging:
  - `.codex-research/`
  - Generated review captures unless intentionally committed.
- Files/folders safe to delete now: None identified.

## Known Risks and Open Issues

- The raw pillow formula may still start ahead of visible objects.
- The final visible pillow response may look stylistically acceptable while still beginning too far ahead anatomically.
- The current `Pillow Visual Mask` debug gradient may hide low/no values because zero maps to green.
- `bank_response.a` may be too semantic and forward-looking for pillow anchoring.
- Generic dilated collision support may be too broad for pillow starts.
- Another scalar distance tweak may leave the real cause untouched.
- Future shared classifier edits could accidentally alter accepted wake/eddy-line behavior.

Relevant audit sections:

- `addons\waterways\docs\audit\pillow-system-audit.md` was reviewed and promoted into this feature folder. Check `addons\waterways\docs\audit\` again before code changes in case newer audit notes were added.

## Blockers

- Human-visible Godot/editor review is needed to decide the next implementation layer.
- Local parser/probe signal is not enough to accept visible pillow placement.
- The next code change should wait until raw R, final no-reach mask, or material response is identified as the failing layer.

## Files To Inspect Before Editing

- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`
- `addons/waterways/shaders/filters/bank_response_feature_mask_filter.gdshader`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/gui/debug_view_menu.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/resources/river_bake_data.gd`
- `.codex-research/phase6c_pillow_placement_diagnostic.gd`
- `.codex-research/phase6b_pillows_demo_debug/`

## Commands or Checks Used

```powershell
Get-Content -LiteralPath 'addons\waterways\docs\history\CHANGELOG.md' -Raw
Get-Content -LiteralPath 'addons\waterways\docs\handoffs\handoff-latest.md' -Raw
```

Result summary:

- The changelog and shared handoff identify Phase 6F formula review as the next pillow step.
- No Godot runtime validation was run during this docs conversion.

## Next Tasks

- [ ] Lock one detection question and target set before tuning.
- [ ] Add audit-recommended diagnostic split views or probe output.
- [ ] Add a readable `Pillow Visual Mask` threshold/black-zero diagnostic if the existing view remains all-green.
- [ ] Run the human-assisted formula review in `validation.md`.
- [ ] Add raw readings or named-region stats only if target coverage is ambiguous.
- [ ] Choose the smallest code path matching the diagnosed layer.
- [ ] Preserve accepted Phase 7B eddy-line behavior.
- [ ] Update this feature folder after every decision, validation run, or implementation slice.

## Do Not Do Yet

- Do not halve another distance constant without isolating the failing source term.
- Do not tune pillow brightness, foam, height, or material response until placement is accepted or the failure is proven to be visual-only.
- Do not regenerate the WaterSystem bake.
- Do not change final flow, reverse flow, or circulating eddy behavior.
- Do not change terrain-contact or bank-response thresholds unless the formula review explicitly scopes that work.

## Notes for the Next Agent

The current work is about truth-finding more than implementation speed. The user may be right that pillows are still too far ahead, but the code history says the cause is probably a combined formula/source issue rather than a simple remaining reach value. Start by comparing raw and final masks at the same rocks, then patch the layer that actually fails.
