# Tasks: River Pillows

Complete tasks in order unless the plan is revised. Each task should be independently reviewable and should record enough evidence that the next session can tell whether the issue is raw placement, final shader gating, or visible material response.

## Current Truth

This is the task dashboard. Keep active work and next action here; move completed or superseded detail to `Historical or Closed Tasks`.

- Current status: In progress
- Current implementation slice: review-state preflight, readable final-mask diagnostic, target-bound diagnostic split, then formula review.
- Remaining open task count: tracked by the checkboxes below; do not maintain a manual count while this document is still changing.
- Last passing validation: Historical Godot 4.6.3 probes listed in `validation.md`, plus audit-reported `PILLOW_FORMULA_ANCHOR_AUDIT_OK`.
- Current review blockers:
  - `Pillow Visual Mask` maps zero/near-zero values through a green-zero debug gradient, so it is not reliable for final-mask placement review until a clearer diagnostic exists.
  - `Demo_obstacle_flow_test.tscn` contains strong saved `pillow_` material overrides, including high strength/foam and nonzero obstruction height, so placement review must normalize or explicitly record scene material state before interpreting visible water.
  - The existing audit is whole-bake evidence; formula changes still need target-bound diagnostics for user-selected should-detect and should-not-detect areas.
- Next recommended action: Normalize/record review state, add readable and source-split diagnostics, then review those diagnostics live with the user before any classifier edit.
- Known deferred work: Material polish, stronger height response, final flow, WaterSystem/physics alignment.

## Open Work

Use this section as the canonical checklist for unfinished pillow work. Items are ordered by dependency and risk. When items close, update stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff.

### 1. Review-State Preflight

- [ ] Lock one detection question and a small target set before tuning.
  - Validate: Review notes list target scene, camera/view, upstream/downstream direction, should-detect areas, and should-not-detect controls.

- [ ] Confirm the active scope is Godot 4 code only.
  - Validate: Record that this workspace has no `legacy/godot-3/addons/waterways` tree, or update the scope if a legacy tree appears later.

- [ ] Run the context challenge check before patching.
  - Validate: If the user or agent may be misreading expected behavior, stale generated data, validation geometry, material overrides, camera direction, or engine limitations as a defect, raise that with evidence before implementation.

- [ ] Normalize or explicitly record pillow review material state in both review scenes.
  - Validate: For `Demo.tscn` and `Demo_obstacle_flow_test.tscn`, record all non-default `pillow_` shader parameters and mirrored `mat_pillow_` values before visual review. Reset to baseline review values unless a non-default value is intentionally part of the test.
  - Required baseline for placement review: `pillow_forward_reach_tiles = 0.0`, `pillow_contact_pull_tiles = 0.0`, `pillow_contact_pull_strength = 0.0`, `pillow_terrain_height = 0.0`, and `pillow_obstruction_height = 0.0`.
  - Validate: Flag any gate pair where start is greater than full, and record whether that scene state is intentionally kept or reset.

- [ ] Keep shader reach, contact pull, and height response out of placement review.
  - Validate: Inspector/default shader/material values show no default forward reach, contact pull, terrain height, or obstruction height during raw/final placement review.

### 2. Diagnostic Tooling Before Formula Changes

- [ ] Add a readable final-mask diagnostic before relying on `Pillow Visual Mask`.
  - Validate: Zero/near-zero reads as quiet or black, or a threshold-band/low-range view clearly separates no signal, weak mask, and meaningful final pillow values.
  - Validate: The diagnostic is available in the editor or in target-bound probe output before the next formula review. This is mandatory because the current green-zero palette is already known to be misleading.

- [ ] Add the audit-recommended pillow source split before changing the classifier.
  - Validate: Editor-visible views or target-bound probe output separate pillow support/facing source, direct `terrain_contact_features.b` anchor, `bank_response_features.a` anchor, combined pillow contact gate, and bank-only anchor contribution.
  - Validate: Whole-bake audit summaries are supporting evidence only; they do not satisfy the target-review requirement by themselves.

- [ ] If adding editor-visible diagnostic modes, reserve debug mode IDs and wire the menu safely.
  - Validate: New mode IDs do not collide with existing `river_debug.gdshader` modes, `debug_view_menu.gd` exposes the labels, Debug View Normal still restores visible material behavior, and menu/static probes cover the new wiring.

- [ ] Add target-bound readings before any classifier formula change.
  - Validate: For each user-confirmed target/control area, report raw R, final mask, raw-to-final retention, direct terrain anchor, bank-response anchor, combined contact gate, bank-only contribution, support/facing source, ordinary-bank false positives, and top gate suppressors where available.

### 3. Formula Review

- [ ] Run a dedicated pillow formula review with the user using the diagnostic split.
  - Validate: User identifies should-detect and should-not-detect rocks/protrusions and compares raw/final/source-term views at the same targets.

- [ ] Compare the same targets in existing and new debug views.
  - Views to include: `Pillow / Impact Mask`, readable final pillow mask, `Pillow Visual Mask` if still present, `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, `Grade / Energy Channel`, `Protrusion / Intersection`, `Final Flow Strength`, and the new source-split diagnostics.
  - Validate: Decide whether the forward offset begins in raw R, no-reach final mask, or visible material response.

- [ ] Check both main demo and obstacle-test layouts before accepting a detector change.
  - Validate: The same decision holds in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`, with no continuous ordinary-bank pillow strips and no stale scene material overrides affecting the conclusion.

- [ ] Record the review result before implementation.
  - Validate: `review.md` states which layer failed, which targets were accepted/rejected, and which implementation path is now authorized.

### 4. Implementation Decision Gates

- [ ] If the diagnostic confirms bank-response anchoring is the cause, make raw pillow R direct-contact first.
  - Validate: `terrain_contact_features.b` or a tight local terrain-contact search is mandatory or near-mandatory for the pillow anchor; `bank_response_features.a` acts only as weak context and cannot anchor a pillow alone.

- [ ] Tighten pillow-specific support if broad support/facing remains a source of false positives.
  - Validate: Use a pillow-only support threshold/field; do not globally reduce `baking_dilate = 0.6` unless flow, foam, pressure, wakes, and obstacle avoidance are explicitly reviewed.

- [ ] If raw R placement is wrong, revise the bake/classifier formula in a scoped pass.
  - Validate: Source signature is bumped, main and obstacle-test river bakes are regenerated, metadata records the new constants, and probes pass.

- [ ] If raw R is correct but no-reach final mask is wrong, revise shader gates instead of the bake classifier.
  - Validate: The readable final pillow mask aligns with raw placement while preserving ordinary-bank suppression.

- [ ] If raw and no-reach final masks are correct but visible water reads detached, tune material response only.
  - Validate: Pressure/highlight/normal/band/foam response improves readability without moving the mask.

- [ ] Rebake only when bake/classifier output changes.
  - Validate: Source signature, metadata, saved river bakes, and probe expectations match. WaterSystem/physics bakes remain untouched unless explicitly scoped.

- [ ] Report effective anchor-chain reach in docs and diagnostics after any formula change.
  - Validate: Documentation names the explicit contact search, `1.5x` sampling, `bank_response.a` contribution if any, and the relevant support/probe radius so future sessions do not treat one constant as the full reach.

- [ ] Preserve accepted Phase 7B eddy-line behavior after any shared classifier or shader change.
  - Validate: Run relevant Phase 7B probes and compare accepted debug behavior if classifier inputs were touched.

- [ ] After the next formula is accepted, consider extracting shared visible/debug pillow mask logic into `.gdshaderinc`.
  - Validate: Visible/debug mask parity is preserved by a probe or static include/string check; keep debug mode selection in `river_debug.gdshader`.

### 5. Validation, Docs, and Cleanup

- [ ] Run automated checks listed in `validation.md` for the changed layer.
  - Validate: Required `_OK` markers pass or failures are recorded with next action.

- [ ] Revisit the context challenge check after validation.
  - Validate: If results suggest the premise was wrong, tell the user and update docs before doing more implementation.

- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in chat to run exact steps.
  - Validate: Request includes scene paths, debug views, expected behavior, screenshot/visible behavior request, Godot version, renderer, device/GPU, and Output panel errors.

- [ ] Do not rely on `validation.md` alone for human-assisted checks.
  - Validate: Paste the requested steps into the user-facing message whenever visible Godot validation is required.

- [ ] Record validation results in `review.md`.
  - Validate: Include pass/partial/fail, target areas, material state, debug views checked, and whether the result came from agent automation or human-visible review.

- [ ] Remove temporary debug code that is not part of the planned validation UI.
  - Validate: Any promoted diagnostics have menu/probe coverage; scratch-only helpers remain under `.codex-research` or are deleted.

- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
  - Validate: Packaging excludes disposable folders, generated captures, editor caches, validation fixtures, and local probe outputs.

- [ ] Add or refine comments only for non-obvious shader math, Godot quirks, source-signature rules, performance-sensitive paths, and architectural boundaries.

- [ ] Update feature docs, changelog, and feature handoff after any decision or code/bake change.
  - Validate: `Current Truth` sections agree across docs, and generated data/resources are explicit and inspectable.

- [ ] Confirm editor-only state did not leak into runtime-only code.

- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Setup Reference

- [x] Confirm the current workspace state.
- [x] Read `spec-driven` workflow and templates.
- [x] Read `docs/history/CHANGELOG.md`.
- [x] Read `docs/handoffs/handoff-latest.md`.
- [x] Read `docs/roadmaps/river-feature-detection-roadmap.md`.
- [x] Read `docs/roadmaps/river-improvements-roadmap.md`.
- [ ] Check `docs/research/river-research-citations.md` before research-driven changes; it is the shared works-cited list for river-reading, flow-map, shader-water, and production-reference sources, and should be updated when new cited sources affect pillow decisions.
- [x] Read `docs/audit/pillow-system-audit.md`.
- [ ] Check any additional `docs/audit/` notes for relevant known risks before code changes.

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
- [x] Adversarially reviewed `tasks.md` and revised it to require review-state normalization, readable final-mask diagnostics, target-bound source-split evidence, and debug-mode wiring validation before classifier changes.
