# Plan: River Pillows

## Spec Link

`spec.md`

## Architecture Summary

River pillows use a baked raw feature channel, shader-side gates, material controls, and debug views. The current architecture should remain split into:

- Bake/classifier placement: raw `obstacle_features.r`.
- Shader gating: `Pillow Visual Mask` from raw R plus confidence, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, and flow strength.
- Material response: pressure, highlight, normal, bands, subtle foam, and optional default-off height/contact-pull.
- Validation: visual editor review plus targeted probes and exported review captures.

The next architectural step is diagnostic, not a final formula rewrite.

The review architecture follows the shared feature-detection loop:

1. Pick one pillow detection question and one target area.
2. Review the raw source mask first.
3. Review the final visual/debug mask second.
4. Review visible water last.
5. Let the user confirm in the visible editor/runtime viewport.
6. Add raw readings if coverage, false positives, or a user-marked area matters.
7. Make the smallest scoped change.

## Current Truth

- Implementation status: Existing implementation is in progress; next slice not started.
- Open architectural decisions: Which source terms may anchor the upstream pillow start.
- Last validation that proves the plan still works: Phase 6E/6F documentation and earlier Godot 4.6.3 probes; visible user review now confirms raw and visible pillow starts are about `0.3` to `0.5` ahead of the intended contact point.
- Next planned implementation slice: Add audit-recommended diagnostic split views/probe output plus a readable `Pillow Visual Mask`/threshold diagnostic, then run live formula review before changing classifier constants.
- Branch safety before implementation: Not checked for code changes; this documentation consolidation is safe. Before classifier/shader/bake edits, use a dedicated feature branch or get explicit approval to continue on the current branch.
- Sections below that are historical or superseded: Phase 6A/6B visual tuning history is summarized in `review.md` and `handoff-latest.md`.

## Premise Check

Before implementing, record whether the problem is definitely a code/design issue or could be expected behavior from scene setup, generated data, stale resources, Godot limitations, or validation interpretation.

- Evidence supporting the premise:
  - User still reports pillows starting too far ahead after Phase 6E.
  - User confirmed the offset appears in raw `Pillow / Impact Mask` and final visible water, with the start about `0.3` to `0.5` too far ahead of the desired obstruction contact point.
  - User reports `Pillow Visual Mask` reads as undifferentiated green over the river; static shader review shows zero maps to green in the current debug gradient, so the view is not reliable for final-mask placement decisions without a clearer diagnostic.
  - Phase 6F review found visible shader reach/contact-pull defaults are off.
  - Raw R is governed by dilated support plus hard-boundary context.
  - `bank_response.a` includes forward protrusion sampling and can create a semantic halo.
  - The feature-detection roadmap warns that the explicit `0.07` search does not describe the full effective anchor reach.
  - `pillow-system-audit.md` reports about `35.17%` main and `35.88%` obstacle-test raw pillow pixels above `0.05` are strongly bank-response anchored while direct terrain protrusion is weak or absent.
- Evidence against the premise:
  - Review camera direction or upstream/downstream interpretation can confuse pillow versus wake placement.
  - Some expected compression may start slightly upstream of collision contact in stylized water.
  - Stale material/debug overrides previously caused misleading review signals.
- User-facing pushback or clarification needed before patching:
  - Ask the user to identify the same should-detect and should-not-detect rocks while comparing raw and final pillow views.
  - Remind the user that screenshots are useful evidence, but acceptance should come from live viewport/runtime review.
- Smallest check that can falsify the premise:
  - If raw R is correct but final/visible read is wrong, the next fix is shader/material, not bake/classifier.

## Layers

Editor authoring layer:

- Debug View menu entries for pillow and related source terms.
- Inspector material grouping for `pillow_` uniforms.
- Visible editor review in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.

Bake/data layer:

- `RiverBakeData.obstacle_features.r` for raw pillow/impact.
- `terrain_contact_features.b` for direct protrusion/intersection context.
- `bank_response_features.a` for semantic hard-boundary/protrusion context.
- Source metadata and signatures for classifier changes.

Runtime layer:

- Visible river shader uses accepted pillow masks to render surface response.
- WaterSystem/physics flow remains out of scope unless explicitly scoped.
- Material tuning should only happen after raw/final placement is accepted.

Validation layer:

- Godot probes for metadata/shader wiring.
- Human-assisted viewport review for final placement.
- Capture exports for shared discussion.
- Optional raw readings, named-region stats, low-range/threshold views, or marker samples.

Legacy reference layer:

- No current legacy dependency.

## Godot Components

- Nodes: River nodes in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.
- Resources: `waterways_bakes/Demo/Water_River.river_bake.res`, `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`.
- Shaders: `addons/waterways/shaders/river.gdshader`, `addons/waterways/shaders/river_debug.gdshader`.
- Filter shaders: `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`, `addons/waterways/shaders/filters/bank_response_feature_mask_filter.gdshader`.
- Editor tools: `addons/waterways/gui/debug_view_menu.gd`, inspector material controls.
- Importers: None currently scoped.
- Autoloads: None currently scoped.
- Scenes: `Demo.tscn`, `Demo_obstacle_flow_test.tscn`.
- Validation scenes: Same scenes plus `.codex-research` export/probe helpers.
- Review cameras/targets: overview, rock garden, main bend low-oblique, downstream rocks low-oblique, and any user-identified close-up targets.

## Data Model

- `obstacle_features.r`: raw upstream pillow / impact mask.
- `obstacle_features.a`: obstacle confidence.
- `terrain_contact_features.b`: terrain/world protrusion or intersection.
- `bank_response_features.a`: hard-boundary / protrusion response candidate.
- `dist_pressure.b`: grade/energy.
- `flow_foam_noise.rg`: packed signed baked flow vector.

Current formula summary from the handoff:

1. Visible `Pillow Visual Mask` mostly reveals baked raw `obstacle_features.r` through shader gates.
2. Raw `obstacle_features.r` is `max(pillow_source * pillow_contact_gate, pulled_contact_source)`.
3. `pillow_source` uses dilated collision support, flow-facing obstacle normals, and pillow bank/context suppression.
4. `pillow_contact_gate` samples hard-boundary context at the current pixel and downstream by the pillow contact-search distance.
5. `hard_boundary_at()` uses `max(bank_response.a, terrain_contact.b)`.
6. Phase 6E changed the explicit pillow contact-search constant from `0.14` to `0.07` source tiles and the direct fallback `pillow_contact_search_uv` from `0.02` to `0.01`; the effective reach is still longer because of `1.5x` gate sampling, `bank_response.a`, and broad support.

Current first-pass visual design rules from the roadmap:

- Use accepted Phase 5 flow as the foundation; pillows are surface compression on top of good flow, not a hidden flow correction.
- Use `obstacle_features.r` as the primary upstream impact source.
- Gate visibility with obstacle confidence, hard-boundary/protrusion context, grade/energy, and final/effective flow strength.
- Keep grade/energy and final/effective flow strength as separate multiplicative gates unless review chooses otherwise.
- Suppress ordinary banks using bank friction unless hard protrusion context is present.
- Treat foam as secondary; prefer pressure, highlight, normal detail, roughness/specular, and compression bands for the first read.
- Keep displacement/height default-off and restrained; stronger height needs mesh/topology review.

## Audit-Guided Formula Direction

The audit changes the next pass from "maybe add diagnostics" to "add diagnostics before the classifier edit." The expected safer classifier direction, if live review confirms the audit, is:

```text
direct_anchor = tight local search of terrain_contact.b
semantic_context = low-weight bank_response.a overlap/context
source = tight support * facing^2 * bank suppression
raw_pillow = source * direct_anchor_gate * context_gate
```

Rules for that direction:

- `direct_anchor_gate` should be mandatory or near-mandatory for raw pillow R.
- `bank_response_features.a` may remain useful context, but it should not define literal pillow contact by itself.
- Broad support should not create a pillow unless direct contact/protrusion is nearby.
- Prefer pillow-only support tightening or higher pillow-specific thresholds over changing shared `baking_dilate = 0.6`.
- Do not globally reduce shared support generation without reviewing flow, foam, pressure, wakes, obstacle avoidance, and accepted eddy-line behavior.
- Report effective anchor-chain reach in the docs and diagnostics instead of describing only the explicit `0.07` search constant.

## Severity-Ordered Implementation Path

1. High severity: Add diagnostic split views/probe output for support/facing, direct `terrain_contact_features.b`, `bank_response_features.a`, combined contact gate, and bank-only anchor contribution.
2. High severity: Add a readable final-mask diagnostic or threshold/black-zero view if `Pillow Visual Mask` remains undifferentiated green.
3. High severity: Review those views live at user-selected should-detect and should-not-detect targets.
4. High severity: If confirmed, revise raw pillow R so direct terrain/world protrusion contact is the primary anchor and `bank_response.a` becomes context only.
5. High severity: If support/facing still starts too early, tighten pillow-specific support without touching shared `baking_dilate`.
6. Medium-high severity: Record effective reach through the whole chain.
7. Medium severity: After formula agreement, consider moving duplicated visible/debug pillow helper math into `.gdshaderinc` and add a parity probe.
8. Low-medium severity: Keep multi-sample visible-shader searches, height displacement, final-flow changes, and WaterSystem changes out of the default pillow placement pass.

## Editor/Runtime Boundary

- Editor-only code: Debug menus, capture helpers, probe scripts, editor-visible validation.
- Runtime-safe code: River shader uniforms and runtime-visible material behavior.
- Shared data/resources: `RiverBakeData` textures, source metadata, saved river bake resources.
- APIs exposed to user projects: Material uniforms and debug/inspector controls.
- Assumptions that must not cross the boundary: Debug material state must not replace the visible material in normal rendering.

## Runtime Flow

1. River material samples baked textures.
2. Shader computes final flow and pillow gates from raw feature channels and context.
3. Accepted mask drives visual pressure/highlight/normal/band/foam response.
4. Default-off height/contact-pull controls remain inactive unless explicitly tuned for review.
5. If height is reviewed, use the split terrain/obstruction controls and keep `pillow_height_tile_seam_fade` in mind as a seam guard, not a detector.

## Bake Flow

1. River bake gathers flow, distance/pressure, obstacle, terrain-contact, and bank-response context.
2. Obstacle feature classifier writes `obstacle_features.r` for raw pillows.
3. Source metadata records classifier settings and source signature.
4. River bake resources are saved and reviewed through debug shader views.
5. If classifier output changes, bump the river bake source signature and rebake affected resources.

## Lifecycle, Cleanup, and Re-entry

Success path:

- Diagnostic review identifies whether the problem is raw placement, shader gating, or material response.
- The next code change is scoped to the diagnosed layer.
- Docs, tasks, validation, review, and handoff are updated together.

Preflight or early-return path:

- If existing debug views prove raw/final placement is correct, do not change the bake classifier.
- If the user identifies stale settings or a misread view, record the interpretation and avoid unnecessary code changes.

Awaited failure path:

- If Godot probes cannot run locally, ask for human-assisted validation with exact scene paths, debug views, expected result, and console details.

Temporary node/resource ownership:

- Export/probe helpers under `.codex-research` should remain ignored local tooling unless intentionally promoted.
- Generated review captures should be listed in validation or handoff artifact hygiene.

Progress, dirty-state, and user feedback:

- Classifier/bake changes should update source metadata and mark stale bakes through signature changes.
- Visual-only shader changes should not dirty saved bakes.

Duplicate or overlapping requests:

- Do not mix pillow placement changes with wake/eddy-line tuning or WaterSystem regeneration in the same slice.

Scene reload or runtime boundary:

- Debug state should reset to visible material behavior when Debug View is Normal.

## Files to Change

Potential future files, only after review confirms the diagnosed layer:

- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`: raw pillow classifier/source formula.
- `addons/waterways/filter_renderer.gd`: classifier inputs and metadata wiring.
- `addons/waterways/river_manager.gd`: bake settings, source signatures, support textures, rebake behavior.
- `addons/waterways/resources/river_bake_data.gd`: channel metadata or source metadata normalization.
- `addons/waterways/shaders/river.gdshader`: visible pillow gate/material response.
- `addons/waterways/shaders/river_debug.gdshader`: debug and diagnostic views.
- `addons/waterways/shaders/*.gdshaderinc`: future shared helper include files after the formula is agreed.
- `addons/waterways/gui/debug_view_menu.gd`: debug menu labels and IDs.
- `.codex-research/*pillow*`: probes, diagnostics, and export helpers.
- `waterways_bakes/Demo/*.river_bake.res`: only if classifier output changes.

## Documentation Plan

- Code comments needed: Only for non-obvious shader math, Godot quirks, source-signature rules, or formula boundaries.
- Feature docs to update: This feature folder.
- Architecture or data-flow docs to update: `river-improvements-roadmap.md` only when the broader roadmap changes.
- Validation docs to update: `validation.md`.
- Research citations index: `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited list for river behavior, flow-map, shader-water, and production-reference sources. Future Codex sessions should consult it before research-driven changes and update it when adding new sources.
- Migration notes to update: Not currently needed.

## Validation Strategy

- Automated: Existing Godot probes plus any new pillow diagnostic probe.
- Validation matrix location:
  - `validation.md` "Validation Matrix"
- Human-assisted: Required for visible editor/runtime placement acceptance.
- Visual: Compare raw, final, and context views at the same rock targets.
- Shader: Verify visible/debug shader parity for any gate or material changes.
- Editor: Verify `pillow_` controls and Debug View menu behavior.
- Runtime: Only if visible runtime behavior is explicitly scoped.
- Performance: No new runtime readback; bake/probe times should stay reasonable.
- Manual: Review against spec acceptance criteria.
- Generalization: Check at least the main demo and obstacle-test layout before accepting a detector as an add-on improvement.
- Metrics when needed: Expected-region raw coverage, final-mask coverage, raw-to-final retention, ordinary-bank false-positive coverage, hard-protrusion support, grade/energy support, final-flow support, and top gate suppressors.
- Audit checks after classifier changes: `PILLOW_FORMULA_ANCHOR_AUDIT_OK`, `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, and Phase 7B wake/eddy probes when shared classifier inputs are touched.
- Historical probe names to preserve in summaries when relevant: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, and `DEBUG_VIEW_MENU_WIRING_PROBE_OK`.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| `bank_response.a` anchors pillows without direct contact. | Detached pillows can start ahead of visible rocks. | Make direct `terrain_contact.b` or tight local contact mandatory or near-mandatory; use bank response as weak context only. |
| Broad dilated support starts before visible contact. | Raw R can exist before the object boundary users judge in the viewport. | Tighten pillow-specific support or thresholds; do not globally shrink shared `baking_dilate` without a broader review. |
| Effective reach is understated by a named constant. | Future sessions keep halving the wrong scalar. | Document the full chain: contact search, `1.5x` samples, bank-response probe, and support radius. |
| Another scalar tweak leaves the real formula cause untouched. | Repeated churn and confusing validation. | Diagnose direct contact, bank response, support/facing, and final gate separately first. |
| Bake classifier change regresses accepted eddy-line behavior. | Breaks Phase 7B accepted work. | Keep wake/eddy channels untouched unless explicitly scoped; run Phase 7B probes after classifier edits. |
| Raw and final masks are confused during review. | Wrong layer gets patched. | Compare `Pillow / Impact Mask` and `Pillow Visual Mask` at the same targets. |
| `Pillow Visual Mask` palette reads as undifferentiated green. | Final-mask placement cannot be judged, and low/no signal may be mistaken for broad coverage. | Add a black-zero, threshold-band, or equivalent readable diagnostic before using the view for acceptance. |
| Saved debug/material override misleads review. | Controls appear broken or visuals look stale. | Confirm Debug View Normal restores visible material; use probe coverage if material wiring changes. |
| Pillow height curve hints regress. | Height controls act like generic easing sliders or appear ineffective. | Preserve explicit shader range hints and editor revert defaults for height curves. |
| Height seam guard is mistaken for placement logic. | Material/mesh seam artifacts get confused with raw detector problems. | Keep height default-off during placement review and treat `pillow_height_tile_seam_fade` as visual artifact control only. |
| WaterSystem bake is regenerated unnecessarily. | Physics/runtime flow changes without review. | Leave WaterSystem out of scope unless final flow changes are planned. |
| Demo-scene overfitting. | A fix works for one camera but harms other river layouts. | Check obstacle-test and multiple review angles; document why the change should generalize. |
| Numeric metrics replace visible review. | Technically tidy masks may still look wrong. | Treat metrics as evidence and keep user viewport judgment as acceptance. |
| Visible/debug shader helper drift. | Debug masks stop matching visible water. | Consider `.gdshaderinc` shared helpers after formula agreement, with parity probe coverage. |

## Adversarial Plan Review

Complete this with the user after the diagnostic plan is drafted and before implementation starts.

- Most likely way this plan could damage working behavior: Editing shared classifier inputs or support fields could alter wake/eddy channels or accepted flow behavior.
- Project state, generated resource, scene, or workflow most at risk: Signature-`19` river bakes and accepted Phase 7B eddy-line review behavior.
- Files or data that are riskier than they look: `obstacle_feature_mask_filter.gdshader`, `bank_response_feature_mask_filter.gdshader`, saved `.river_bake.res` files, and debug shader mode IDs.
- Simpler or safer approach considered: Use existing debug views for target selection, but add the audit-recommended diagnostic split before classifier changes because current views do not isolate the failing sub-term; also fix final-mask readability because the current green-zero view is not reliable enough for review.
- Validation that will catch the riskiest failure early: Human review of raw/final pillow views in main and obstacle-test scenes plus `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK` and eddy diagnostic probes after any classifier change.
- Branch safety reminder sent before code changes: No. This docs-only consolidation did not need a branch; code/bake changes do.

## Migration and Compatibility

- Active code targets Godot 4.6+.
- No Godot 3 compatibility work is currently planned.
- River bake source signatures must change when saved bake output semantics change.
- Existing signature-`19` bakes are the current pillow baseline.
- `waterways_bakes/Demo/Water_River_legacy_test.river_bake.res` remains intentionally stale at signature `5`.
