# Tasks: River Pillows

Complete tasks in order unless the plan is revised. Each task should be independently reviewable.

## Current Truth

- Current status: In progress
- Current implementation slice: Audit-guided diagnostic split, readable final-mask diagnostic, then formula review.
- Remaining open task count: 17
- Last passing validation: Historical Godot 4.6.3 probes listed in `validation.md`, plus audit-reported `PILLOW_FORMULA_ANCHOR_AUDIT_OK`.
- Next recommended action: Add pillow diagnostic split views or probe output and a readable final-mask diagnostic before the next classifier edit, then review those views live with the user.
- Known deferred work: Material polish, stronger height response, final flow, WaterSystem/physics alignment.

## Open Work

Use this section as the canonical checklist for unfinished pillow work. Items are ordered by audit severity and dependency. When items close, update stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff.

- [ ] Lock one detection question and a small target set before tuning.
  - Validate: Review notes list target scene, camera/view, upstream/downstream direction, should-detect areas, and should-not-detect controls.

- [ ] Keep `pillow_forward_reach_tiles = 0.0` during placement review.
  - Validate: Inspector/default shader values show no default forward reach during the review.

- [ ] Add the audit-recommended pillow diagnostic split before changing the classifier.
  - Validate: Editor-visible views or a probe separate pillow support/facing source, direct `terrain_contact_features.b` anchor, `bank_response_features.a` anchor, combined pillow contact gate, and bank-only anchor contribution.

- [ ] Add a readable `Pillow Visual Mask` diagnostic if the current view remains undifferentiated green.
  - Validate: Zero/near-zero reads as quiet or black, or a threshold-band view clearly separates no signal, weak mask, and meaningful final pillow values.

- [ ] Run a dedicated pillow formula review with the user using the diagnostic split.
  - Validate: User identifies should-detect and should-not-detect rocks/protrusions and compares raw/final/source-term views at the same targets.

- [ ] Compare existing debug views at the same targets:
  - `Pillow / Impact Mask`
  - `Pillow Visual Mask`
  - `Pillow Height Influence`
  - `Terrain Pillow Height Influence`
  - `Obstruction Pillow Height Influence`
  - `Obstacle Confidence`
  - `Hard-Boundary / Protrusion Response`
  - `Grade / Energy Channel`
  - `Protrusion / Intersection`
  - `Final Flow Strength`
  - Validate: Decide whether the forward offset begins in raw R, no-reach final mask, or visible material response.

- [ ] Check both main demo and obstacle-test layouts before accepting a detector change.
  - Validate: The same decision holds in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`, with no continuous ordinary-bank pillow strips.

- [ ] If placement depends on ambiguous coverage, add raw readings or named-region stats.
  - Validate: Report expected-region raw coverage, final-mask coverage, raw-to-final retention, ordinary-bank false positives, and top gate suppressors.

- [ ] If the diagnostic confirms bank-response anchoring is the cause, make raw pillow R direct-contact first.
  - Validate: `terrain_contact_features.b` or a tight local terrain-contact search is mandatory or near-mandatory for the pillow anchor; `bank_response_features.a` acts only as weak context and cannot anchor a pillow alone.

- [ ] Tighten pillow-specific support if broad support/facing remains a source of false positives.
  - Validate: Use a pillow-only support threshold/field; do not globally reduce `baking_dilate = 0.6` unless flow, foam, pressure, wakes, and obstacle avoidance are explicitly reviewed.

- [ ] If raw R placement is wrong, revise the bake/classifier formula in a scoped pass.
  - Validate: Source signature is bumped, main and obstacle-test river bakes are regenerated, metadata records the new constants, and probes pass.

- [ ] Report effective anchor-chain reach in docs and diagnostics after any formula change.
  - Validate: Documentation names the explicit contact search, `1.5x` sampling, `bank_response.a` contribution if any, and the relevant support/probe radius so future sessions do not treat one constant as the full reach.

- [ ] If raw R is correct but no-reach final mask is wrong, revise shader gates instead of the bake classifier.
  - Validate: `Pillow Visual Mask` aligns with raw placement while preserving ordinary-bank suppression.

- [ ] If raw and no-reach final masks are correct but visible water reads detached, tune material response only.
  - Validate: Pressure/highlight/normal/band/foam response improves readability without moving the mask.

- [ ] Preserve accepted Phase 7B eddy-line behavior after any shared classifier or shader change.
  - Validate: Run relevant Phase 7B probes and compare accepted debug behavior if classifier inputs were touched.

- [ ] After the next formula is accepted, consider extracting shared visible/debug pillow mask logic into `.gdshaderinc`.
  - Validate: Visible/debug mask parity is preserved by a probe or static include/string check; keep debug mode selection in `river_debug.gdshader`.

- [ ] Update feature docs, changelog, and feature handoff after any decision or code/bake change.
  - Validate: `Current Truth` sections agree across docs.

## Setup

- [x] Confirm the current workspace state.
- [x] Read `spec-driven` workflow and templates.
- [x] Read `docs/history/CHANGELOG.md`.
- [x] Read `docs/handoffs/handoff-latest.md`.
- [x] Read `docs/roadmaps/river-feature-detection-roadmap.md`.
- [x] Read `docs/roadmaps/river-improvements-roadmap.md`.
- [ ] Check `docs/research/river-research-citations.md` before research-driven changes; it is the shared works-cited list for river-reading, flow-map, shader-water, and production-reference sources, and should be updated when new cited sources affect pillow decisions.
- [x] Read `docs/audit/pillow-system-audit.md`.
- [ ] Check any additional `docs/audit/` notes for relevant known risks before code changes.
- [ ] Confirm whether the next task affects active code in `addons/waterways`, legacy reference code in `legacy/godot-3/addons/waterways`, or both.
- [ ] Run the context challenge check before patching: if the user or agent may be misreading expected behavior, stale generated data, validation geometry, or engine limitations as a defect, raise that with evidence.

## Implementation

- [ ] Define the formula-review target set.
  - Validate: User confirms target rocks/protrusions and upstream/downstream orientation.

- [ ] Use the review order: raw mask, final mask, visible water.
  - Validate: Notes explain which layer failed before any code change. Current user report says raw `Pillow / Impact Mask` and final visible water both start about `0.3` to `0.5` ahead, while current `Pillow Visual Mask` is not readable enough because it appears all green.

- [ ] Add diagnostic split views or probe before a classifier edit.
  - Validate: Diagnostic output separates support/facing, direct contact, bank response, final gate contribution, and bank-only contribution.

- [ ] Add low-range or threshold-band views only if the current palette hides meaningful low values.
  - Validate: The new view answers a specific placement/readability question and does not become a permanent distraction. The current `Pillow Visual Mask` all-green report is a valid trigger for this task.

- [ ] Apply the smallest code change matching the diagnosed layer.
  - Validate: Run the relevant automated checks and request human-visible Godot review if visual placement changed.

- [ ] Rebake only when bake/classifier output changes.
  - Validate: Source signature, metadata, saved bakes, and probe expectations match.

- [ ] Re-run the audit-required checks after any raw pillow formula change.
  - Validate: `PILLOW_FORMULA_ANCHOR_AUDIT_OK`, `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, and relevant Phase 7B wake/eddy probes pass or have recorded failures.

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge check after validation. If results suggest the premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in chat to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene through human-assisted validation unless the agent can genuinely use the visible editor.
- [ ] Check shader output/debug views through human-assisted validation.
- [ ] Check editor workflow if `pillow_` controls or Debug View menu behavior changes.
- [ ] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries.
- [ ] Update docs for any changed decisions.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

- [x] Phase 6A added first visual-only pillow highlights and `Pillow Visual Mask`.
- [x] Phase 6B added pillow tuning controls and experimental default-off height controls, including split terrain/obstruction height and `pillow_height_tile_seam_fade`.
- [x] Phase 6C diagnosed shader forward reach and changed default `pillow_forward_reach_tiles` to `0.0`.
- [x] Phase 6C fixed pillow editor wiring issues: explicit height-curve range hints, visible/debug material sync, material revert hooks, and stale obstacle-demo override reset.
- [x] Phase 6D tightened the raw pillow classifier with support/contact anchoring and bumped bakes to signature `18`.
- [x] Phase 6E halved raw pillow contact-search distance from `0.14` to `0.07`, aligned `pillow_contact_search_uv` from `0.02` to `0.01`, and bumped bakes to signature `19`.
- [x] Phase 6F documented that the remaining offset is likely formula/source related, not default visible shader reach.
- [x] Created this feature-local spec folder from the shared changelog and latest handoff.
- [x] Read `pillow-system-audit.md` and reordered open work by audit severity.
