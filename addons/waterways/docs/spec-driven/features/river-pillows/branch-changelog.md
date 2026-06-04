# Branch Changelog: River Pillows Diagnostics

Branch: `codex/river-pillows-diagnostics`

This changelog summarizes the river-pillow work captured in `handoff-latest.md` and `validation.md`, with branch-diff context added where it clarifies what changed.

## Summary

This branch moved river pillows from broad visual tuning into a diagnostic, source-term-driven workflow. The main outcome is that pillow placement can now be reviewed layer by layer: baked raw impact mask, final shader mask, source/contact diagnostics, visible material response, and optional height response.

The branch also fixed editor stability issues from unused legacy hterrain importers, added a separate material-control reference after inspector helper text was rejected, and reconciled the main and obstacle-test river bakes to source signature `20`.

## Pillow Detection And Bake Changes

- Changed raw pillow anchoring to be direct-contact-first.
  - `terrain_contact_features.b` direct search is now the required pillow contact anchor.
  - `bank_response_features.a` remains as weak context only and should no longer anchor pillows by itself.
- Bumped river bake source signature to `20` for the direct-contact-first classifier.
- Added bake metadata describing the pillow anchor source and bank-response role.
- Regenerated and verified the main and obstacle-test river bakes to signature `20`.
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- Preserved the rule that WaterSystem/physics bakes are not accepted as pillow-placement work unless explicitly reviewed.
  - `waterways_bakes/Demo/WaterSystem.water_system_bake.res` changed during the user's main-demo rebake and still needs a keep/review/revert decision.

## Debug Views

- Added a readable true Black Zero palette variant for the normal final pillow visual mask:
  - Mode `58`: `Pillow Visual Mask (Black Zero)`
- Renamed/clarified the no-reach diagnostic:
  - Mode `48`: `Pillow No-Reach Mask (Black Zero)`
- Added source-term and retention diagnostics for pillow formula review:
  - Mode `49`: `Pillow Direct Terrain Anchor Search`
  - Mode `50`: `Pillow Bank-Response Anchor Search`
  - Mode `51`: `Pillow Combined Contact Gate`
  - Mode `52`: `Pillow Bank-Only Anchor Contribution`
  - Mode `53`: `Pillow Raw-to-Final Retention`
- Added material and seam diagnostics:
  - Mode `54`: `Pillow Material Response Mask`
  - Mode `55`: `Pillow Material Seam Guard`
  - Mode `56`: `Pillow Height Seam Guard`
  - Mode `57`: `Pillow Height Seam Stitch`
- Exposed the new pillow diagnostics in the Debug View menu.
- Clarified that the original `Pillow Visual Mask` still uses a green-zero gradient and should not be the only final-mask acceptance view.

## Inspector And Material Controls

- Organized pillow material parameters under the `Material / Pillow` inspector category.
- Added grouped pillow sub-sections for:
  - Pillow Shape
  - Pillow Mask Gates
  - Pillow Surface
  - Pillow Bands & Foam
  - Pillow Height
  - Pillow Seam Fades
- Added or documented controls for:
  - visible strength, pressure, highlight, forward reach, contact pull
  - confidence, hard-boundary, energy, flow, and bank-suppression gates
  - pressure/highlight colors, specular, roughness, and normal response
  - compression bands and foam bias
  - split terrain and obstruction height
  - height smoothing, height seam stitching, height seam fade, and material seam fade
- Kept placement-review controls default-off where they can hide raw placement errors:
  - `pillow_forward_reach_tiles = 0.0`
  - `pillow_contact_pull_tiles = 0.0`
  - `pillow_contact_pull_strength = 0.0`
  - `pillow_terrain_height = 0.0`
  - `pillow_obstruction_height = 0.0`
- Added `material-controls.md` as the user-facing explanation for pillow material controls after in-inspector helper text proved visually confusing.

## Visible Pillow Rendering

- Expanded visual pillow response in the river shaders with pressure color, highlight color, specular boost, roughness reduction, normal boost, compression bands, and foam bias.
- Added optional visual-only pillow height response.
  - Height is split into terrain and obstruction influence.
  - Height response remains default-off and is not a placement fix.
- Added smoothing and seam handling for pillow height and material response.
- Preserved the review rule that material polish should wait until raw and no-reach placement are accepted.

## Review State And Scene Fixes

- Reset `Demo.tscn` to the pillow placement-review baseline after audit found saved non-baseline values.
- Normalized `Demo_obstacle_flow_test.tscn` pillow review material values.
- Kept baseline placement review values aligned across the main demo and obstacle-test scenes.
- Documented that live cross-scene review must use matching signature-`20` bakes before more classifier changes.

## Architecture And Documentation

- Created and updated the feature-local river-pillows documentation set:
  - `research.md`
  - `spec.md`
  - `plan.md`
  - `tasks.md`
  - `validation.md`
  - `review.md`
  - `handoff-latest.md`
  - `engineering-audit.md`
  - `material-controls.md`
- Folded pillow-specific roadmap and audit guidance into the feature folder.
- Added an engineering audit focused on code quality, consistency, efficiency, architecture, comments, and maintainability.
- Added validation/dashboard sections so future work starts from current facts rather than historical assumptions.
- Updated the shared handoff and history notes to point future sessions at the feature-local pillow documents.

## Bug Fixes And Stability Work

- Fixed the post-tooltip-session editor regression from legacy hterrain packed-texture scripts.
  - Replaced unused Godot 3 packed-texture importer code with Godot 4.6-compatible unavailable stubs.
  - This restores editor parsing for the current project but does not restore `.packed_tex` or `.packed_texarr` import functionality.
- Avoided the failed inspector-tooltip approach that tried to wrap default generated property editors.
- Clarified debug mode `48` so it is no longer mistaken for a pure palette variant of mode `26`.
- Added parity protection for duplicated pillow bake diagnostic constants.

## Validation And Probes

- Added `probes/pillow_diagnostic_parity_check.gd`.
- Verified debug menu and shader diagnostic wiring with Godot 4.6.3.
- Verified both review river bakes report source signature `20`.
- Reran the requested CPU/readback diagnostic.
- Current passing markers include:
  - `PILLOW_FORMULA_ANCHOR_AUDIT_OK`
  - `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`
  - `DEBUG_VIEW_MENU_WIRING_PROBE_OK`
  - `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`
  - `PILLOW_REVIEW_BAKES_SIGNATURE_20_CONFIRMED`

## Known Follow-Ups

- Run live Godot placement review on both signature-`20` review scenes.
- Compare the same targets through raw, final, source-term, and visible material views before changing code again.
- Add support/facing target-bound probe output only if signature-`20` raw R still starts too early.
- Decide whether to keep, review, or revert the modified WaterSystem bake.
- Preserve accepted Phase 7B eddy-line behavior during any future pillow classifier changes.
- Do not tune pillow brightness, foam, height, or material response until placement is accepted or proven to be visual-only.
