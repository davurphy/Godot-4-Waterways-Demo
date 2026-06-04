# River Pillow Engineering Audit

## Purpose

The next session should audit the pillow system as an expert software engineer before returning to rebakes or feature tuning. This is a review task, not an implementation task.

The audit should look for code-quality, consistency, efficiency, architecture, comment, and maintainability issues in the pillow implementation and its immediate integration points.

## Scope

Primary files:

- `addons/waterways/river_manager.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`
- `addons/waterways/shaders/filters/bank_response_feature_mask_filter.gdshader`
- `addons/waterways/gui/debug_view_menu.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/resources/river_bake_data.gd`
- `addons/waterways/docs/spec-driven/features/river-pillows/`

Secondary context:

- `addons/waterways/docs/audit/pillow-system-audit.md`
- `addons/waterways/docs/roadmaps/river-feature-detection-roadmap.md`
- `addons/waterways/docs/roadmaps/river-improvements-roadmap.md`
- `.codex-research/phase6c_pillow_placement_diagnostic.gd`
- `.codex-research/pillow_formula_anchor_audit.gd`

## Review Questions

### Code Quality

- Are pillow-specific paths clear, localized, and easy to reason about?
- Are names precise enough to distinguish raw classifier terms, final shader gates, visible material response, and height response?
- Are constants, defaults, and source-signature metadata easy to trace from bake code to shader/debug behavior?

### Consistency

- Do visible and debug shaders compute equivalent pillow masks where they are intended to match?
- Do material defaults, revert defaults, shader defaults, docs, and saved scene assumptions agree?
- Are debug mode names, IDs, shader branches, and menu entries consistently wired?

### Efficiency

- Are shader sampling patterns justified by the visual/debug need?
- Are repeated pillow computations duplicated unnecessarily between visible/debug shaders?
- Are bake-time and runtime costs bounded and understandable?

### Architecture

- Is too much pillow-specific policy concentrated in `river_manager.gd` or shader files?
- Would a small shared shader include, helper, or metadata structure reduce risk, or would it add unnecessary abstraction?
- Are bake classifier data, visual material response, debug views, and editor controls separated cleanly enough?

### Comments And Docs

- Are comments present where the code has non-obvious Godot, shader, bake-signature, or atlas-space behavior?
- Are comments stale, misleading, or explaining obvious code?
- Do the feature docs describe the current architecture and known risks without contradicting the implementation?

### Maintainability

- What would be hard for a future engineer to change safely?
- What tests/probes are missing for the most fragile paths?
- Are there naming, grouping, or data-flow decisions that will become painful when wake/eddy or final-flow work resumes?

## Output Format

Use a code-review style report:

1. Findings first, ordered by severity.
2. Each finding should include file and line references where possible.
3. Include why it matters and what kind of fix would reduce the risk.
4. Separate confirmed issues from questions or possible refactors.
5. End with a short summary of strengths, residual risks, and recommended next steps.

Do not make code changes during the audit unless the user explicitly asks for a follow-up implementation pass.

## Audit Result - 2026-06-04

Status: Completed as a review-only pass. No code, scene, bake, or shader files were changed during the audit.

### Findings

1. P1: `Demo.tscn` contradicts the documented pillow review baseline.
   - Evidence: `Demo.tscn` saves non-baseline pillow material values, including `pillow_strength = 1.18`, `pillow_foam_bias = 2.0`, `pillow_obstruction_height = 0.276`, `pillow_obstruction_height_curve = 4.0`, `pillow_height_smoothing_tiles = 0.11`, and `pillow_height_tile_seam_fade = 0.004`, with mirrored `mat_pillow_*` values.
   - Why it matters: main-demo visible-water and height review can be biased even if raw masks are correct.
   - Recommended fix: reset `Demo.tscn` to the placement-review baseline or explicitly label it as a non-baseline material/height review preset before using it as placement evidence.

2. P1: Main and obstacle-test bakes appeared to be on mixed generations at audit time.
   - Evidence at audit time: binary metadata scan found signature-`20` direct-contact metadata strings in `waterways_bakes/Demo/Water_River.river_bake.res`, while `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res` still appeared signature `19`. Follow-up Godot metadata verification confirmed main signature `20` after the user rebake and obstacle-test signature `19`.
   - Why it matters: cross-scene formula review is invalid if the two review resources use different raw classifiers.
   - Recommended fix: regenerate or verify the obstacle-test river bake to a known matching direct-contact-first/signature-`20` state. Do not further regenerate or accept WaterSystem bake changes unless final/physics flow is explicitly scoped; later follow-up found the user's main-demo rebake did modify that resource.
   - Follow-up status: Resolved after the audit on 2026-06-04; the obstacle-test river bake was regenerated and both review river bakes now report source signature `20`.

3. P2: `Pillow Visual Mask (Black Zero)` is not only a palette variant.
   - Evidence: mode `26` renders `pillow_visual`, while mode `48` renders `pillow_visual_no_reach`.
   - Why it matters: with non-default reach/contact-pull controls, the two modes can disagree for reasons unrelated to color readability.
   - Recommended fix: rename mode `48` to make the no-reach semantics explicit, or add a true Black Zero palette variant of mode `26`.

4. P2: Bake diagnostic constants are duplicated across code paths.
   - Evidence: the debug shader hard-codes pillow bake contact-search/gate constants that are also represented in `river_manager.gd` and the obstacle-feature filter.
   - Why it matters: the diagnostic split can silently drift from the real bake formula.
   - Recommended fix: pass these values as debug uniforms, share them through a shader include/config path, or add a static parity probe before further classifier-distance edits.

5. P2: Support/facing source is still not directly inspectable.
   - Evidence: raw pillow source depends on pillow support and flow-facing obstacle normal, but only final raw `pillow` is stored in `obstacle_features.r`.
   - Why it matters: if direct-contact-first raw R still starts early, the next likely suspect cannot be isolated from saved textures alone.
   - Recommended fix: add target-bound probe output first; promote a stored bake diagnostic only if repeated reviews need it.

### Strengths

- The direct-contact-first classifier shape is consistent with the prior user review: direct `terrain_contact_features.b` search is mandatory, and `bank_response_features.a` acts only as weak context.
- Expensive pillow contact sampling stays in bake/debug paths rather than normal visible material runtime.
- Visible/debug material defaults and river-manager revert defaults are broadly aligned for the core default-off placement controls.

### Next Steps

1. Normalize or explicitly label `Demo.tscn` pillow material state.
2. Decide whether the user-modified `WaterSystem.water_system_bake.res` should be kept, reviewed, or reverted before finalizing.
3. Run the human-visible raw/final/source-term review in Godot.
4. Add support/facing target-bound probe output only if signature-`20` raw R still starts too early.

## First Follow-Up Status - 2026-06-04

Completed after the audit:

1. `Demo.tscn` was reset to the pillow placement-review baseline.
   - Reset high foam bias, obstruction height, obstruction height curve, height smoothing, height seam fade, and mirrored `mat_pillow_*` values.
2. Debug mode semantics were clarified.
   - Mode `58`, `Pillow Visual Mask (Black Zero)`, renders the normal `pillow_visual` mask with a black-zero heat palette.
   - Mode `48`, `Pillow No-Reach Mask (Black Zero)`, keeps the no-reach final-mask diagnostic.
3. Diagnostic parity coverage was added.
   - Added `addons/waterways/docs/spec-driven/features/river-pillows/probes/pillow_diagnostic_parity_check.gd`.
   - Godot 4.6.3 console validation passed `DEBUG_VIEW_MENU_WIRING_PROBE_OK` and `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`.
4. Review river bake metadata was verified after the rebakes.
   - Godot metadata verification found `waterways_bakes/Demo/Water_River.river_bake.res` at source signature `20`.
   - The obstacle-test river bake was regenerated and `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res` now also reports source signature `20`.
   - `waterways_bakes/Demo/WaterSystem.water_system_bake.res` was modified by the user rebake and needs an explicit keep/review/revert decision.
5. The requested Phase 7B CPU/readback diagnostic was rerun.
   - Godot 4.6.3 console validation passed `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`.

Still open:

1. Decide how to handle the modified WaterSystem bake before finalizing or committing.
2. Run live pillow placement review with the raw/final/source-term views.
3. Add support/facing target-bound probe output only if signature-`20` raw R still starts early.
