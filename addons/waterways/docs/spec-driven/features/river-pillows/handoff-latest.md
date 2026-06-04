# Session Handoff: River Pillows

## Date

2026-06-04

## Current Focus

Inspector tooltip/field-description support has been researched and parked. The user rejected in-inspector helper text as visually confusing, so pillow material-control explanations now live in `material-controls.md`. The requested expert software-engineering audit has now been completed as a review-only pass; the next session should address the audit findings before returning to placement tuning.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-pillows\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: In progress
- Highest-priority open task: Review the matching signature-`20` river bakes in live Godot before any further classifier or material tuning. The first audit follow-up slice reset `Demo.tscn` material state, clarified the Black Zero/no-reach debug modes, and added diagnostic parity checks. After the 2026-06-04 rebakes, Godot metadata verifies both `Water_River.river_bake.res` and `Water_River_obstacle_test.river_bake.res` are source-signature `20`.
- Editor-regression status: Fixed on 2026-06-04. The hterrain packed-texture scripts under `addons/zylann.hterrain/tools/packed_textures/` now parse in Godot 4.6 as unavailable stubs, and the user confirmed the reported errors are gone. The project has no `.packed_tex` / `.packed_texarr` assets and no active registration for those legacy custom importers; do not treat `.packed_tex` import functionality as restored.
- Tooltip/field-description status: Researched and parked. Do not treat tooltips as implemented or validated; current decision is to keep the Inspector clean and use `addons\waterways\docs\spec-driven\features\river-pillows\material-controls.md` for Pillow material-control explanations until Godot exposes a better description path for generated properties.
- Failed tooltip approach to avoid: do not repeat the shortcut inspector-plugin fallback that tried to create or wrap default inspector editors for generated `mat_pillow_*` fields from `_parse_property()` and then assign tooltip text to those controls. That path destabilized the editor. For any future attempt, first look up current Godot 4.6 documentation and examples for adding descriptions/tooltips to generated inspector properties, then use a documented approach such as a carefully scoped custom `EditorProperty` or non-replacing help control tested in isolation.
- Last passing validation: Historical Phase 6/7 Godot 4.6.3 probes listed in `validation.md`, 2026-06-04 `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`, `DEBUG_VIEW_MENU_WIRING_PROBE_OK`, and the consolidated feature-local pillow probe suite: `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`, `PILLOW_ANCHOR_SOURCE_PROBE_OK`, `PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PILLOW_INSPECTOR_WIRING_PROBE_OK`, and quick `PILLOW_VISUAL_REVIEW_EXPORT_OK`.
- Known failing or unproven check: User confirmed bank-response/combined contact gating was too broad on signature-`19` bakes. Godot metadata now confirms both review river bakes are signature `20`; live cross-scene placement review on those matching bakes is still unrun.
- Current debug-view status: The original `Pillow Visual Mask` still uses the green-zero gradient. Mode `58`, `Pillow Visual Mask (Black Zero)`, is now the true Black Zero version of mode `26`; mode `48`, `Pillow No-Reach Mask (Black Zero)`, is the no-reach final-mask diagnostic.
- Next recommended action: Compare raw/final/source-term views around the same rocks in both signature-`20` review scenes. Treat the modified `WaterSystem.water_system_bake.res` from the user rebake as pending review/decision, not as accepted pillow physics work.
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
10. `addons\waterways\docs\spec-driven\features\river-pillows\material-controls.md`
11. `addons\waterways\docs\spec-driven\features\river-pillows\engineering-audit.md`
12. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Treat the engineering audit as complete and start from its findings below.
- Verify `Demo.tscn` remains at the reset pillow placement-review baseline before using the main demo for placement review.
- Confirm both review scenes load their matching signature-`20` river bakes before judging the direct-contact-first classifier across scenes.
- Use mode `58` for the true `Pillow Visual Mask (Black Zero)` and mode `48` for the no-reach Black Zero diagnostic.
- Use `addons\waterways\docs\spec-driven\features\river-pillows\probes\README.md` for the current reusable pillow probe suite before reaching for old `.codex-research` scratch scripts.
- Ask the user to run or join a dedicated pillow formula review after the split is available.
- Use the exact human-assisted validation request in `validation.md`.
- If the user wants Codex to implement immediately, start with the review-state/bake consistency fixes. Further classifier changes should still wait until raw R, no-reach final mask, or visible material response is identified as the failing layer.

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
- `addons\waterways\shaders\river_debug.gdshader`: Added readable Black Zero final-mask mode and saved-term pillow anchor/contact diagnostics.
- `addons\waterways\gui\debug_view_menu.gd`: Exposed the new pillow diagnostics as Debug View menu items.
- `Demo_obstacle_flow_test.tscn`: Reset saved pillow review material values to baseline placement-review defaults.
- `addons\waterways\shaders\filters\obstacle_feature_mask_filter.gdshader`: Changed raw pillow contact gating to require direct `terrain_contact_features.b` search; `bank_response_features.a` is weak context only.
- `addons\waterways\river_manager.gd`: Bumped river bake source signature to `20` and recorded direct-contact-first pillow anchor metadata.
- `addons\zylann.hterrain\tools\packed_textures\`: Replaced legacy Godot 3 packed-texture importer code with Godot 4.6-compatible unavailable stubs after the user reported editor parse/API errors. The user confirmed the errors are gone; this does not restore `.packed_tex` or `.packed_texarr` import functionality.
- `addons\waterways\docs\spec-driven\features\river-pillows\material-controls.md`: Added a separate Pillow material-control reference after in-inspector helper text proved visually confusing.
- `addons\waterways\docs\spec-driven\features\river-pillows\engineering-audit.md`: Added the next-session audit brief covering code quality, consistency, efficiency, architecture, comments, and maintainability.
- 2026-06-04 engineering audit: Completed a review-only audit. Confirmed the direct-contact-first classifier shape is sensible, but found review-state and diagnostic blockers: `Demo.tscn` had saved non-baseline pillow overrides, main/obstacle-test bakes appeared mixed generation, mode `48` was no-reach rather than a pure palette variant, bake diagnostic constants were duplicated, and support/facing source remains unavailable without a probe. The scene-state, bake-generation, debug-mode, and parity items have since been resolved.
- 2026-06-04 audit follow-up slice: Reset `Demo.tscn` to placement-review pillow defaults, added true `Pillow Visual Mask (Black Zero)` as mode `58`, renamed mode `48` to `Pillow No-Reach Mask (Black Zero)`, added `probes/pillow_diagnostic_parity_check.gd`, and reran relevant Godot probes.
- 2026-06-04 user main-demo rebake: Godot metadata verifies `waterways_bakes/Demo/Water_River.river_bake.res` now has source signature `20`. `waterways_bakes/Demo/WaterSystem.water_system_bake.res` was also modified during the user rebake and needs an explicit keep/revert/review decision before commit.
- 2026-06-04 agent obstacle-test rebake: Rebaked `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res` with Godot 4.6.3 and verified both review river bakes report source signature `20`. Reran the requested CPU/readback diagnostic with `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`.
- 2026-06-04 probe consolidation slice: Promoted reusable pillow diagnostics into `probes/` with a README, anchor-source probe, placement diagnostic, inspector wiring probe, and visual review exporter. Godot 4.6.3 validation passed `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`, `PILLOW_ANCHOR_SOURCE_PROBE_OK`, `PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PILLOW_INSPECTOR_WIRING_PROBE_OK`, and quick `PILLOW_VISUAL_REVIEW_EXPORT_OK`.
- Latest handoff update: Next session should run cross-scene signature-`20` placement review before any further classifier or material changes.

## Current Changes Summary

- New feature folder: Consolidates pillow-specific state from the general changelog, latest handoff, and relevant roadmap sections into spec-driven docs.
- 2026-06-01 diagnostic slice: Added modes `48` through `53` for Black Zero final mask, direct terrain anchor search, bank-response anchor search, combined contact gate, bank-only anchor contribution, and raw-to-final retention. Support/facing source remains probe-only because it is not stored in `RiverBakeData`.
- 2026-06-01 classifier slice: User review confirmed bank-response/combined contact was too broad, so raw pillow R now requires direct terrain-contact search. Signature-`19` bakes are stale for the current classifier; the main demo and obstacle-test review river bakes are now signature `20`.
- 2026-06-04 editor-stability slice: Fixed the hterrain packed-texture editor regression using Godot 4.6-compatible unavailable stubs for unused legacy importers. No Waterways pillow classifier, shader, river bake, WaterSystem bake, or tooltip work changed in this slice.
- 2026-06-04 tooltip-planning slice: Official Godot inspector tooltip/description support was researched. A non-replacing helper-row prototype and a full-width subgroup helper block were rejected as visually confusing, so Inspector helper text was removed and a separate material-control reference document was added.
- 2026-06-04 audit-planning slice: User requested an expert software-engineering audit of the pillow system before returning to rebake/review work.
- 2026-06-04 engineering-audit slice: Audit completed without code changes. Highest-impact findings were review-state/bake consistency issues rather than a new classifier-code defect.
- 2026-06-04 first audit-follow-up slice: `Demo.tscn` review state is reset, Black Zero/no-reach debug modes are explicit, and diagnostic parity checks exist and pass in Godot.
- 2026-06-04 probe-consolidation slice: current reusable pillow probes live under `addons/waterways/docs/spec-driven/features/river-pillows/probes/`; old `.codex-research` probes remain historical scratch helpers.

## Historical Change Log

- Phase 5A/5B flow and SDF steering were accepted by the user as the baseline.
- Phase 6A added visual-only pillow highlights and the `Pillow Visual Mask`.
- Phase 6B added pillow tuning controls and optional default-off height response.
- Phase 6B's height response is split into terrain/obstruction height with `pillow_height_tile_seam_fade`; it remains a subtle default-off review accent, not a placement fix.
- Phase 6C diagnosed shader-side forward reach and changed default `pillow_forward_reach_tiles` to `0.0`.
- Phase 6C also fixed editor wiring by preserving height-curve range hints, syncing visible/debug material parameters, fixing material revert hooks, and resetting stale obstacle-demo overrides.
- Phase 6D moved into bake/classifier changes, tightened raw pillow anchoring, and bumped river bakes to signature `18`.
- Phase 6E halved pillow contact-search distance from `0.14` to `0.07`, aligned `pillow_contact_search_uv` from `0.02` to `0.01`, and bumped river bakes to signature `19`.
- Phase 6F documented that the signature-`19` explicit `0.07` contact search was not the full effective reach because `hard_boundary_at()` included `bank_response.a`, which had its own forward-looking context.
- Phase 7B eddy-line visual work was accepted and should be preserved.
- The shared feature-detection roadmap now lives here as local rules: review raw source first, final mask second, visible material last; use screenshots as evidence but user viewport review as acceptance; check more than one layout before accepting a detector change.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create `features/river-pillows/`. | Pillow work needed a feature-local source of truth. | Use this folder before future pillow edits. |
| Treat diagnostic split plus formula review as the next action. | Evidence points to combined source terms, not only one distance value, and the audit says current views do not isolate the needed sub-terms. | Saved-term diagnostics are added; run the validation request in `validation.md`, then add support/facing probe output if needed. |
| Treat `Pillow Visual Mask` readability as a separate tooling issue. | User reports the view is undifferentiated green; shader review shows zero maps to green, so the palette can hide whether the final mask is actually broad or low. | Use `Pillow Visual Mask (Black Zero)` before final-mask acceptance. |
| Keep code/bake changes out of this docs conversion. | The user asked to create the feature docs, and the next implementation depends on review. | Branch safety check before future code changes. |
| Fold roadmap rules into this feature folder. | The roadmaps contained pillow-specific review loop, generalization, and Phase 6 design rules. | Keep future pillow edits anchored here, then update broader roadmaps only when the high-level plan changes. |
| Promote audit diagnostics ahead of classifier edits. | The audit found about `35%` bank-response-only anchoring and says current views do not show the needed source split. | Saved-term diagnostics are added; support/facing still needs probe output before changing raw R. |

## Current State

Implementation status:

- Existing pillow implementation is in progress; no code changed in this docs conversion.

Spec/plan status:

- Research: Current recommendation, roadmap research findings, and audit evidence captured.
- Spec: Drafted with feature definitions, review layers, and acceptance criteria.
- Plan: Drafted with diagnostic-first path and roadmap change boundaries.
- Tasks: Open checklist reordered by audit severity.
- Validation: Matrix, human-assisted request, generalization checks, raw-reading expectations, and audit probe expectations created.
- Review: Current risks, roadmap migration, audit severity, and 2026-06-04 engineering-audit findings recorded.

Validation status:

- Automated:
  - Historical pass markers are listed in `validation.md`. The 2026-06-04 engineering audit used static reads and binary resource string scans only; no Godot runtime validation was run.
- Human-assisted:
  - User now confirmed raw and visible pillow starts are about `0.3` to `0.5` too far ahead, and `Pillow Visual Mask` is not readable because it appears all green.
  - Needed next: ask the user to compare raw/final/context views around the same target rocks after split diagnostics and a clearer final-mask view are available.
- Shader:
  - Existing pillow shaders passed historical probes, but placement remains under review.
- Editor:
  - Historical wiring issue fixed.
- Visual:
- User still reports forward offset after Phase 6E/signature-`19` review. Judge direct-contact-first placement only on the matching signature-`20` bakes, with material states remaining baseline.
- Latest user detail: the raw `Pillow / Impact Mask` and final visible water both start about `0.3` to `0.5` too far ahead; final visible water is acceptable-ish but anatomically early compared with real pillow behavior.
- `Pillow Visual Mask` currently appears undifferentiated green over the river and should not be used alone for final-mask acceptance. Use mode `48` for no-reach final-mask placement review, but remember it is not a pure palette clone of mode `26`.
- Runtime:
  - Not scoped.
- Performance:
  - Not changed.
- Manual:
  - Formula review required.

## Important Context

- Keep `pillow_forward_reach_tiles = 0.0` during placement review.
- Keep `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` default-off until raw/no-reach placement is understood.
- Audit follow-up: `Demo.tscn` was reset to the documented pillow placement-review baseline on 2026-06-04. It now matches the obstacle-test defaults for strength, foam, reach, contact pull, terrain height, obstruction height, smoothing, and seam fade.
- Audit follow-up: saved river bakes are now matching generation. Godot metadata verification after the 2026-06-04 rebakes found signature `20` in both `waterways_bakes/Demo/Water_River.river_bake.res` and `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`.
- Current direct-contact-first code signature is `20`; live cross-scene raw placement review is the next gate before further code changes.
- Historical Phase 6E distance note: in the signature-`19` formula, the literal distance constants were not the full effective anchor reach because the contact gate sampled up to `1.5x`, `hard_boundary_at()` could include `bank_response.a`, and raw source support was still broad.
- Historical coverage anchors: Phase 6A main raw R was about `8.08%` above `0.05`; Phase 6D raw R dropped to about `5.12%` main and `5.06%` obstacle-test; Phase 6E raw R dropped to about `4.70%` main and `4.61%` obstacle-test, with no-reach visual about `2.32%` main and `2.26%` obstacle-test.
- The saved WaterSystem bake was modified by the user's 2026-06-04 main demo rebake. Do not treat that as accepted pillow physics/final-flow work until it is explicitly reviewed or intentionally reverted.
- Historical signature-`19` formula risk: `hard_boundary_at()` used `max(bank_response.a, terrain_contact.b)`, and `bank_response.a` included forward-looking protrusion context. The current signature-`20` code moves that role to direct terrain contact first; validate it with matching bakes and baseline material state.
- Current support risk: `pillow_source_at()` uses generic dilated collision support generated from `baking_dilate = 0.6`.
- Diagnostic limitation: support/facing source is not saved in `RiverBakeData`, so editor-visible diagnostics can split direct terrain, bank response, combined contact gate, bank-only contribution, raw R, and final retention, but not original support/facing without a probe or promoted bake diagnostic.
- Diagnostic naming result: mode `58`, `Pillow Visual Mask (Black Zero)`, renders `pillow_visual`; mode `48`, `Pillow No-Reach Mask (Black Zero)`, renders `pillow_visual_no_reach`.
- Maintainability result: `addons/waterways/docs/spec-driven/features/river-pillows/probes/` now contains the reusable pillow probe suite. `pillow_diagnostic_parity_check.gd` checks debug shader bake constants against `river_manager.gd` and the filter shader; `pillow_anchor_source_probe.gd`, `pillow_placement_diagnostic.gd`, `pillow_inspector_wiring_probe.gd`, and `pillow_visual_review_export.gd` cover current anchor stats, placement stats, inspector/material wiring, and review captures.
- User formula review result: direct terrain anchor search was closest to desired pillow placement; bank-response anchor search, combined contact gate, bank-only anchor contribution, raw R, and raw-to-final retention were too broad or too early.
- Audit evidence: about `35.17%` of main-river and `35.88%` of obstacle-test raw pillow pixels above `0.05` are strongly `bank_response.a` anchored while direct `terrain_contact.b` is weak or absent.
- Implemented formula direction to validate: direct `terrain_contact.b` or tight local direct-contact search is now mandatory or near-mandatory in code; `bank_response.a` is weak context only.
- Do not change accepted Phase 7B eddy-line behavior while fixing pillows.
- Use the review order from the roadmap: raw source, final visual/debug mask, visible water. Patch only the layer that fails.
- Check both `Demo.tscn` and `Demo_obstacle_flow_test.tscn` before accepting a detector change.
- Add raw readings or named-region stats only when the visible review needs numeric support.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future Codex sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence pillow decisions.

## Artifact Hygiene

- Scratch folders or temporary projects created: Repo-local Godot user-data folders under `.codex-research/` for the obstacle rebake, metadata verification, CPU/readback diagnostic, consolidated probe runs, and quick visual export.
- Generated bakes/resources changed: The user's 2026-06-04 main demo rebake modified `waterways_bakes/Demo/Water_River.river_bake.res` and `waterways_bakes/Demo/WaterSystem.water_system_bake.res`. The 2026-06-04 agent rebake modified `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`.
- Active files mirrored into scratch validation: Not applicable.
- Probe outputs created: quick visual captures under `.codex-research/river-pillows-visual-review/`; keep them as local review output unless a future review explicitly asks to commit reference captures.
- Files/folders that must be excluded from packaging:
  - `.codex-research/`
  - Generated review captures unless intentionally committed.
- Files/folders safe to delete now: None identified.

## Known Risks and Open Issues

- The raw pillow formula may still start ahead of visible objects.
- The final visible pillow response may look stylistically acceptable while still beginning too far ahead anatomically.
- The current `Pillow Visual Mask` debug gradient may hide low/no values because zero maps to green.
- Visible placement on the matching signature-`20` river bakes is not yet accepted.
- The modified `WaterSystem.water_system_bake.res` needs an explicit keep/review/revert decision before this work is finalized.
- Mode `58` and mode `48` still need human-visible review for readability, though their semantics are now explicit.
- Duplicated bake constants in the debug shader now have parity coverage, but future changes must keep the check passing.
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
- `addons/waterways/docs/spec-driven/features/river-pillows/probes/README.md`
- `addons/waterways/docs/spec-driven/features/river-pillows/probes/`
- `.codex-research/phase6b_pillows_demo_debug/` only when historical captures are useful.

## Commands or Checks Used

```powershell
Get-Content -LiteralPath 'addons\waterways\docs\history\CHANGELOG.md' -Raw
Get-Content -LiteralPath 'addons\waterways\docs\handoffs\handoff-latest.md' -Raw
```

Result summary:

- The changelog and shared handoff identify Phase 6F formula review as the next pillow step.
- No Godot runtime validation was run during this docs conversion.
- 2026-06-04 engineering audit found no obvious defect in the direct-contact-first classifier shape, but found review-state and diagnostic blockers that must be resolved before placement acceptance.

## Next Tasks

- [ ] Lock one detection question and target set before tuning.
- [x] Reset or explicitly label `Demo.tscn` pillow material state before using it for placement review.
- [x] Confirm `Demo.tscn` main river bake is direct-contact-first/source-signature `20` after the 2026-06-04 user rebake.
- [x] Reconcile `Demo_obstacle_flow_test.tscn` river bake so it is confirmed direct-contact-first/signature `20`.
- [x] Clarify mode `48` naming/semantics and add a true Black Zero palette variant for mode `26`.
- [ ] Review the signature-`20` Black Zero and saved-term diagnostic views in Godot.
- [ ] Add support/facing target-bound probe output if signature-`20` raw R still starts too early.
- [x] Add a static parity check for duplicated bake diagnostic constants before future classifier-distance edits.
- [ ] Add raw readings or named-region stats only if target coverage is ambiguous.
- [ ] Choose the smallest code path matching the diagnosed layer.
- [ ] Preserve accepted Phase 7B eddy-line behavior.
- [ ] Update this feature folder after every decision, validation run, or implementation slice.

## Do Not Do Yet

- Do not halve another distance constant without isolating the failing source term.
- Do not tune pillow brightness, foam, height, or material response until placement is accepted or the failure is proven to be visual-only.
- Do not further regenerate or accept the WaterSystem bake change unless final/physics flow review is explicitly scoped.
- Do not change final flow, reverse flow, or circulating eddy behavior.
- Do not change terrain-contact or bank-response thresholds unless the formula review explicitly scopes that work.

## Notes for the Next Agent

The current work is about truth-finding more than implementation speed. The user may be right that pillows are still too far ahead, but the code history says the cause is probably a combined formula/source issue rather than a simple remaining reach value. Start by comparing raw and final masks at the same rocks, then patch the layer that actually fails.
