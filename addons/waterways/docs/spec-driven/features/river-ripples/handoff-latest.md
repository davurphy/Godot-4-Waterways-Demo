# Session Handoff: River Ripples

## Date

2026-06-08

## Current Focus

Continue the spec-driven runtime river ripple spike toward safe river integration.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-ripples\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

This is the handoff dashboard. Keep it short, concrete, and current.

- Overall status: Phase 0 decisions locked; standalone Phase 1 feedback spike, standalone Phase 2 mapping probe, standalone Phase 2 target river mesh-footprint boundary-mask probe, RiverManager-facing material ownership/restore probe, minimal built-in river shader neutral-path probe, river shader sampling-budget probe, minimal visible normal-blend probe, demo-backed visible review scene, debug parity path, shader-cost probe, reusable `WaterRippleField`/`WaterRippleEmitter` workflow, field/emitter dispatch-performance probe, demo-backed field/emitter authoring scene, Phase 9 named Add Node registration, Phase 9 in-memory preset-resource/API slice, Phase 9 export-grouping/built-in-preset/save-reload slice, Phase 10 read-only inspector skeleton, Phase 10 transient preset Apply controls, Phase 10 capture/save controls, Phase 10 visual field/emitter gizmo helpers, the first undo-backed emitter handle slice, the undo-backed field `world_bounds` face-handle slice, and the editor-only boundary preview helper added. Automated feedback, mapping, boundary, material ownership, river shader neutrality, helper-budget, visible-normal, review-scene smoke, review-scene diagnostic, debug parity, shader-cost/performance, field/emitter lifecycle, field/emitter dispatch-performance, demo-backed field/emitter authoring, Mobile/Compatibility renderer validation, named-class parser/editor-cache validation, `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, and `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` passed; human-visible feedback, mapping, boundary, demo-backed minimal visible normal blending, demo-backed debug parity, demo-backed field/emitter visual/debug/control/stop-reload behavior, Add Node visibility for `WaterRippleField`/`WaterRippleEmitter`, Phase 9 editor authoring review, Phase 10 read-only inspector lifecycle/dirty-state review, Phase 10 Apply active-preset/undo/no-op/boundary/lifecycle review, Phase 10 capture/save save-dialog/dirty-state/restart/no-live-link review, Phase 10 visual gizmo readability/dirty-state/lifecycle review, Phase 10 practical emitter handle review, Phase 10 field `world_bounds` handle review, and Phase 10 boundary preview review passed.
- Highest-priority open task: Choose `debug_visible` re-exposure, live-scene bridge work, or a separate response/refraction/displacement tuning plan.
- Last passing validation: Godot 4.6.3 Forward+ `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, regression `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, regression `RIPPLE_FIELD_EMITTER_PROBE_OK`, regression `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and regression `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed on 2026-06-08. Latest Phase 10 validation includes active preset status/selector restoration, capture/save checks, visual gizmo checks, boundary preview checks, emitter handle checks, and field handle checks: unsaved scratch field/emitter captures, explicit `.tres` scratch save paths, saved preset reload with correct scripts and values, field/emitter helper segment counts including `field_boundary_preview=8`, no target routing or reserved value persistence, moving emitters expose radius plus moving-threshold handles, tiny moving-threshold values expose a short guide to a pickable grip, non-moving emitters expose only radius, six field `world_bounds` face handles use stable IDs `2001..2006`, field handles map only to `world_bounds`, preserve opposite faces, skip no-op diffs, clamp to a minimum non-flipped size, registered `"handles"` gizmo material use after the first visible material lookup error, no preview/runtime children, no exported-value mutation while building helpers, and no runtime editor/save leakage. Parser checks passed for the inspector/apply/gizmo handle/gizmo/plugin/probe scripts; static scans and regression probes passed after the boundary-preview slice. User confirmed the Phase 10 read-only inspector review, Phase 10 Apply review, Phase 10 capture/save review, Phase 10 visual gizmo review, practical emitter handle review, field `world_bounds` handle editor tests, and boundary preview tests.
- Latest gizmo validation addendum: Phase 10 now includes `ripple_gizmo.gd` registered from `plugin.gd`, `ripple_gizmo_geometry.gd` as a probeable non-editor geometry helper, and `ripple_gizmo_handle_model.gd` as a probeable handle contract helper. Parser checks passed for the gizmo/handle scripts and `plugin.gd`; `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` validates field bounds, footprint, projected mesh-footprint boundary preview, route, emitter radius, moving-threshold, route segments, emitter and field handle counts, stable handle IDs, property mapping, clamping, no-op diff skipping, field face-handle drag math, no preview children, no forbidden runtime calls, and no runtime editor/save leakage.
- Known failing or unproven check: Response/refraction/displacement tuning remains unproven. Emitter handle no-op/cancel was not checked because Godot did not expose an obvious gesture and dirty-prompt reporting was unclear, neither blocking the slice; `debug_visible` re-exposure plus live-scene commands remain unimplemented.
- Next recommended action: Choose the next optional Phase 10 slice or use a separate plan before refraction, displacement, response tuning, final flow, WaterSystem, bakes, source signatures, or buoyancy work.
- Packaging/artifact hygiene status: No bakes or generated resources created; repo-local `.codex-research\godot-user*` folders were used for Godot console profile isolation, `.codex-research\ripple-feedback-analysis` holds disposable validation captures, `.codex-research\ripple-review-diagnostic` holds disposable review-scene diagnostic captures, `.codex-research\ripple-renderer-coverage` holds disposable renderer probe logs, `.codex-research\ripple-phase10-inspector` holds disposable captured preset save/reload probe resources, and `.codex-research\ripple-phase9-plugin-*` / `.codex-research\godot-user-phase10-inspector*` / `.codex-research\godot-user-phase10-apply*` / `.codex-research\godot-user-phase10-active-preset*` / `.codex-research\godot-user-phase10-capture-save*` / `.codex-research\godot-user-phase10-handles-*` logs hold disposable plugin parser/editor-load/probe checks.
- Historical detail starts at: `Historical Change Log`.

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and the shared citations index only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-ripples\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-ripples\review.md`
6. `addons\waterways\docs\spec-driven\features\river-ripples\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-ripples\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-ripples\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-ripples\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Phase 0 decisions are already confirmed for this branch. Do not reopen them unless new evidence appears.
- Boundary masking is now proven for the standalone gate; do not redo it unless new evidence appears.
- Official Godot 4.6 docs checked for the field/emitter workflow: node lifecycle, `SubViewport`, `ViewportTexture`, resource ownership, editor `@tool` boundaries, and `ShaderMaterial` material-parameter APIs. The new source notes are recorded in `research.md` and `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`.
- The revised Phase 9 planning phase is documented in `phase9-authoring-api-plan.md`; native editor polish is documented separately in `phase10-editor-polish-plan.md`. Phase 9 script/resource implementation is console-proven and human-visible accepted for in-memory type-specific resources, explicit apply/capture methods, ordinary export grouping, built-in starter presets, warning cleanup, hidden/storage-only `debug_visible`/reserved response values, no exported preset slots, no live profile links, no runtime resource saving, Add Node visibility, and scratch scene/resource reload. Phase 10 now has user-confirmed read-only inspector rows through `ripple_inspector_plugin.gd` and `ripple_inspector_status.gd`, transient preset selectors only, per-property editor undo for Apply, explicit user-selected save paths for capture/save, no runtime forbidden calls from ordinary inspector paths, scratch cleanup, visual gizmo helpers, automated emitter radius/moving-threshold handles, automated field `world_bounds` face handles, and live-scene command deferral.
- Phase 10 practical emitter handle review is human-visible accepted. No-op/cancel was not checked because Godot did not expose an obvious gesture and dirty-prompt reporting was unclear, neither blocking the slice. Field `world_bounds` handles are automated-proven and user-confirmed clean in the editor.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. The main false-premise risk is treating first-pass visual ripples as flow, buoyancy, or WaterSystem behavior.
- Latest human-visible finding: User confirmed all demo debug views work in the currently expected ways, then caught that the first field/emitter authoring scene had misaligned emitters with two embedded in terrain. The terrain-aware authoring fix moved the markers, but the next visible pass showed no emitter ripples: boundary and raw height looked uniform, impulse/contact was blue everywhere, the green one-shot did not visibly flash, and visible influence was black. A focused diagnostic found the impulse viewport was clearing to a nonzero project color (`min=0.30196`) instead of black. `WaterRippleField` offscreen canvas viewports now use transparent zero clear, the demo probe now rejects full-field impulse/contact sheets, and post-fix diagnostics show localized impulse stamps for all three emitters. The next visible pass then showed the moving orange marker still crossing mostly land, so the moving path was moved farther toward exposed river centerline anchors and the probe now requires at least `1.0m` moving-path water/terrain clearance.

## What Changed This Session

- `addons\waterways\docs\spec-driven\features\river-ripples\`: Created new feature folder.
- `spec.md`: Captured user goals, non-goals, requirements, acceptance tests, visual validation, performance, open questions, and decision log from the runtime ripple roadmap.
- `plan.md`: Captured runtime architecture, data model, lifecycle, files to change, validation strategy, risks, and adversarial plan review.
- `tasks.md`: Converted the roadmap phases into ordered implementation and validation tasks.
- `research.md`: Summarized the research direction, options, Godot unknowns, and context challenge notes.
- `validation.md`: Tracks passing feedback ownership and analysis probes, human-assisted review steps, Godot launch instructions, and future checks.
- `review.md`: Records docs setup, Phase 0 decisions, standalone feedback validation, and remaining implementation gates.
- `handoff-latest.md`: Added this dashboard and next-session instructions.
- Follow-up docs tightening: Preserved concrete roadmap details for field properties, emitter properties, `i_ripple_*` uniforms, shader behavior, authoring controls, and split Phase 0 safety gates.
- Standalone feedback implementation: Added runtime ripple simulation and impulse shaders, feedback review scene, ownership probe, and 128/256/512 analysis probe.
- Standalone boundary-mask implementation: Added a target river mesh-footprint mask shader, review scene, and console probe; added boundary texture injection to the standalone feedback review path for validation-only dry impulse and cross-bank checks.
- Material ownership implementation: Added RiverManager owner-scoped runtime ripple material API plus `ripple_material_ownership_probe.gd`, proving planned `i_ripple_*` state applies to intended targets through duplicated runtime materials and restores on clear, owner exit, and river exit.
- Minimal river shader neutral path: Added the planned neutral-default `i_ripple_*` uniforms to `river.gdshader`, updated the material ownership probe so the built-in river shader now accepts runtime ripple state through duplicated materials, and added `ripple_river_shader_neutral_probe.gd` to prove disabled or missing ripple textures remain pixel-identical to baseline.
- Safe shader sampling helpers: Added guarded height, boundary, world-to-ripple-UV, distance-fade, and normal-offset helper functions to `river.gdshader` without visible blending, plus `ripple_river_shader_sampling_probe.gd` to prove the helper-only slice compiles, the visible fragment path remains untouched, and the first normal helper stays at three simulation samples and one boundary-mask helper call.
- Minimal visible normal blending: Corrected river shader `world_to_ripple_uv` sampling to use mapped X/Z, blended the guarded ripple normal offset into `NORMAL_MAP`, kept custom screen refraction on the pre-ripple normal, updated the sampling probe, and added visible-normal render plus demo-backed review-scene probes. Follow-up review-scene ergonomics now instantiate `Demo.tscn` as an editor-visible child, derive clustered review ripple centers from the demo river mesh, start runtime review on a close-overhead camera at strength `1.25`, preserve the demo material `flow_speed`, precompute 48 review ripple frames, swap frame textures during playback, and provide movement/zoom/right-mouse-look controls.
- Demo review diagnosis: Added `ripple_river_shader_visible_normal_review_diagnostic.gd`, switched the review scene to clustered mesh-derived annular centers focused on actual water positions, diagnosed the user-reported frozen-flow/static-texture and harsh-framerate fixture issues, and proved the active rendered material, center projection, mesh tangents, ripple texture slope, preserved `flow_speed=1.0`, precomputed frame reuse, and enabled-vs-zero-strength image delta through `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`.
- Debug parity: Added raw ripple height, impulse/contact, boundary mask, and visible influence modes to `river_debug.gdshader` and the debug view menu; added neutral `i_ripple_impulse_texture` plumbing to the visible/debug material runtime state; expanded the demo review scene controls with 0/4/5/6/7 visible/debug switching; and added `ripple_debug_parity_probe.gd`, which proves debug switching preserves runtime ripple textures and animation state.
- Reusable field/emitter workflow: Added `water_ripple_field.gd`, `water_ripple_field.tscn`, `water_ripple_emitter.gd`, and `water_ripple_emitter.tscn`; Phase 9 now exposes `WaterRippleField` and `WaterRippleEmitter` as named `Node3D` Add Node classes with `ripple_field.svg` and `ripple_emitter.svg` icons. The field owns runtime ping-pong simulation, additive impulse, and boundary-mask `SubViewport` targets, generates mesh-footprint masks from intended river targets, applies owner-scoped `i_ripple_*` state through RiverManager, rejects invalid/out-of-bounds impulses, caps/sorts emitters, and clears material state on disable/free. The emitter supports pulse, continuous, one-shot, and moving modes with explicit field path, ancestor, or group fallback.
- Field/emitter validation: Added `ripple_field_emitter_probe.gd` and `ripple_field_emitter_performance_probe.gd`; split the runtime multi-emitter additive stamp into `ripple_impulse_additive.gdshader` while keeping the original standalone impulse shader compatible with feedback analysis. `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, and the regression sweep passed.
- Phase 9 preset API slice: Added separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resource scripts plus `WaterRippleField.apply_preset()`, `WaterRippleField.capture_preset()`, `WaterRippleEmitter.apply_preset()`, and `WaterRippleEmitter.capture_preset()`. Applying copies approved authoring values only; capture returns fresh in-memory resources; nodes expose no preset asset slots or live profile links; runtime code does not save `.tres` resources; field presets exclude target routing and reserved refraction/displacement values; `debug_visible` is `@export_storage`; and `ripple_phase9_preset_api_probe.gd` validates copy isolation, capture isolation, no runtime save path, and safe runtime field rebuild/reapply behavior.
- Phase 10 docs sync: Updated the living feature docs to match `phase10-editor-polish-plan.md` after adversarial review tightened the contract. The docs now call out read-only inspector skeleton first, transient preset selectors, per-property editor undo, editor-only explicit save paths, scratch cleanup, forbidden editor calls, and live-scene bridge deferral.
- Phase 10 inspector/apply/capture-save slices: Added `ripple_inspector_plugin.gd` as a registered `EditorInspectorPlugin`, `ripple_inspector_status.gd` as a probeable non-editor status helper, `ripple_inspector_preset_apply_model.gd` as a probeable Apply value-diff helper, and `ripple_phase10_inspector_probe.gd`. The status rows show exported values, configuration warnings, and conservative target/routing summaries only, report unresolved state instead of calling runtime/private resolver paths, and the Apply controls use transient built-in/resource selectors plus per-property undo setup. Capture/save controls create transient scratch presets, open an editor-owned save dialog, and save only to explicit `.tres` paths through inspector/plugin code. User completed the visible capture/save review with no Output errors and confirmed saved field/emitter presets reload without adding node preset slots, paths, live links, or auto-apply behavior. Visual gizmos, emitter handles, field handles, and the first boundary preview helper are now added in later slices; live-scene work remains deferred. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` and targeted static scans passed.
- Phase 10 visual gizmo helper slice: Added `ripple_gizmo.gd` as a registered `EditorNode3DGizmoPlugin` plus `ripple_gizmo_geometry.gd` as a probeable non-editor segment helper. The gizmo draws field bounds, X/Z footprint and center cross, explicit target route lines, emitter radius rings, moving-emitter threshold rings, and emitter-to-field route lines. It deliberately added no handles and no saved helper toggles in that slice. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` validated the visual gizmo contract. User confirmed the visible editor review passed: field and emitter helpers were readable, viewing only did not dirty the scene, and Output showed no errors.
- Phase 10 emitter handle slice: Added `ripple_gizmo_handle_model.gd` as a probeable handle contract helper, routed emitter handle points through `ripple_gizmo_geometry.gd`, wired `EditorUndoRedoManager` into `ripple_gizmo.gd` from `plugin.gd`, and implemented undo-backed handles for emitter `radius` plus moving-mode `moving_emit_distance`. Automated validation proves stable handle IDs, property mapping, clamping, no-op diff skipping, cancel restore behavior, undo action setup, no field `world_bounds` mutation, no preview children, no forbidden runtime calls, and no runtime editor/save leakage. User confirmed practical behavior after the material-name and tiny-grip fixes: radius and moving-threshold drags edit only their intended properties, undo/redo works, plugin disable/re-enable works, close/reopen without saving works, delete/undo-delete works, run/stop cleanup works, and Output shows no errors. No-op/cancel was not checked because Godot did not expose an obvious gesture; dirty-prompt reporting was unclear.
- Phase 10 field `world_bounds` handle slice: Added six undo-backed field face handles through `ripple_gizmo_handle_model.gd`, `ripple_gizmo_geometry.gd`, and `ripple_gizmo.gd`. Automated validation proves stable field handle IDs `2001..2006`, face-center positions, `world_bounds`-only property mapping, opposite-face preservation, min-size clamping, no-op diff skipping, no preview children, no forbidden runtime calls, and no runtime editor/save leakage. User confirmed the field handle tests pass cleanly in the editor.

## Current Changes Summary

Use this for the latest session only. Move older entries into "Historical Change Log" when this gets long.

- Standalone ripple feedback shaders, mapping review, boundary-mask review, material ownership probe, river shader neutral probe, river shader sampling-budget probe, visible-normal render probe, demo-backed visible normal review scene, debug parity probe, shader-cost probe, reusable field/emitter workflow, field/emitter performance probe, Phase 9 named Add Node registration, first Phase 9 in-memory preset-resource/API slice, Phase 9 export-grouping/built-in-preset/save-reload slice, Phase 10 read-only inspector slice, Phase 10 transient Apply controls, Phase 10 capture/save controls, Phase 10 visual gizmos, first Phase 10 undo-backed emitter handles, and Phase 10 field `world_bounds` handles were added. Latest Phase 10 validation is `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, proving read-only field/emitter status models, transient built-in/resource preset selectors, active preset status/selector restoration, per-property undo setup, no-op Apply diff skipping, source-preset edit isolation, no target/reserved Apply/capture copying, no preview/runtime child creation, plugin registration/removal wiring, visual gizmo segment generation, emitter handle contract mapping, field handle contract mapping, handle clamping, handle no-op diff skipping, and no editor-only class/save-path leakage into runtime ripple scripts or preset resources. User confirmed the Phase 10 visible editor lifecycle/dirty-state review passed for the read-only rows, Apply controls, capture/save controls, visual gizmos, practical emitter handle behavior, and field handle behavior. Latest Phase 9 validation is `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, proving separate field/emitter preset resources, explicit copy/capture semantics, no exported preset slots, no live profile links, no runtime preset saves, source/captured preset edit isolation, storage-only `debug_visible` plus reserved response fields, ordinary export groups, built-in starter preset factories, scratch preset resource reload, and safe runtime field rebuild/reapply behavior after scratch scene reload. Regression `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` still pass. The demo authoring scene passes human-visible visual/debug/control and full scene stop/reload cleanup review; Mobile and Compatibility renderer coverage also pass. `WaterRippleField` and `WaterRippleEmitter` use documented `class_name`/`@icon` Add Node registration, are present in the refreshed global script class cache, and user confirmed both classes and icons are searchable as child nodes in `Demo.tscn` and `ripple_field_emitter_demo_review.tscn`. User also confirmed the Phase 9 grouped inspector surface, hidden reserved fields, Add Node search, and no-Output-error runtime review. The docs are now current with the Phase 10 state: read-only inspector rows are automated- and human-visible-proven, selectors are transient, Apply uses per-property undo setup and skips no-op diffs, applied built-ins remain visible after inspector redraw, saves must use explicit editor paths, emitter handles use explicit undo-backed commits, field handles use explicit undo-backed `world_bounds` commits, and live-scene runtime commands remain deferred.
- Current gizmo slice: `ripple_gizmo.gd`, `ripple_gizmo_geometry.gd`, and `ripple_gizmo_handle_model.gd` add editor helpers for field bounds/footprint/routes, emitter radius/moving-threshold/routes, undo-backed emitter radius/moving-threshold handles, and undo-backed field `world_bounds` face handles. The helpers are registered and removed by `plugin.gd`, do not create preview children, and remain separate from runtime scripts. Parser checks and `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` passed; the visual-only gizmo review, practical emitter handle review, and field handle review passed.
- Added `ripple_field_emitter_demo_review.tscn`, `ripple_field_emitter_demo_review.gd`, and `ripple_field_emitter_demo_review_probe.gd`. The scene instances `Demo.tscn`, adds a real inspectable `WaterRippleField`, and uses three inspectable emitter children for pulse, one-shot, and moving authoring. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed in Godot 4.6.3 Forward+ and validated demo river targeting, generated mesh-footprint boundary masking, fixed emitter UV placement, moving emitter path bounds, rendered impulse stamps, preserved `flow_speed=1.0`, field disable baseline restore, re-enable, and reload cleanup. Later human-visible review and Mobile/Compatibility renderer coverage passed after placement, clear-color, and trail-density fixes.
- User-visible review caught the first field/emitter authoring placement as visibly wrong: two emitters were embedded in terrain. The review controller now samples `World/HTerrain`, chooses exposed river-mesh anchors near the authored UV targets, lifts emitter handles and markers above terrain for inspection, keeps the moving marker synced to the moving emitter, expands the moving path into terrain-aware samples, and reports terrain clearance in `get_review_status()`. The updated probe now rejects buried water anchors, handles, markers, and moving-path samples; terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed on 2026-06-07. Later human-visible review accepted the revised visual/debug/control behavior.
- User-visible rerun then showed no visible emitter ripples. The new `ripple_field_emitter_demo_review_diagnostic.gd` reproduced the debug symptoms and found the runtime impulse texture had a nonzero full-field background (`min=0.30196`, `changed_count=65536`), making impulse/contact blue everywhere and producing flat/nonlocal height with no visible influence. `water_ripple_field.gd` now clears its canvas `SubViewport` targets with transparent zero background; the diagnostic now reports impulse `min=0.0`, `mean=0.000208`, `changed_count=118`, and localized blue/green/orange emitter samples. `ripple_field_emitter_demo_review_probe.gd` now rejects nonblack impulse backgrounds and still passes. Later human-visible review accepted the revised visible/debug behavior.
- User-visible rerun then showed the moving orange emitter path still running over mostly land. `ripple_field_emitter_demo_review_anchor_diagnostic.gd` was added to inspect terrain-aware candidate anchors near the authored path. The moving emitter UVs now use farther-out exposed water anchors around world `z=27.9`, `z=27.7`, and `z=26.6` instead of the prior land-adjacent `z=28.8` row, and the probe rejects moving emitter reports or moving-path samples with less than `1.0m` water/terrain clearance. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, and `RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK` pass after the path correction. User later confirmed the orange behavior was much better.
- User approved the improved orange path but asked for stronger emitter pulses/effects. The field/emitter review scene now boosts only review-scene authoring values: field `ripple_strength=2.25`, `normal_strength=3.0`, fixed emitter intensity `1.0`, moving emitter intensity `0.9`, and larger emitter radii. Refraction and displacement remain `0.0`, shared materials are still owned/restored through RiverManager, and the probe now asserts the stronger review settings. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, and `RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK` pass after the boost. Later human-visible review confirmed the stronger effect is noticeable.
- User then clarified that the orange emitter still looked like periodic pulses rather than a continuous trail. The review scene now makes only the moving orange emitter denser: `pulse_rate=12.0` and `moving_emit_distance=0.08` instead of `3.0` and `0.45`. The review report/probe now records and asserts the dense moving-emitter settings. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, and `RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK` pass after the trail-density change.
- Latest human-visible rerun accepted the field/emitter visual/debug/control and stop/reload behavior: boundary mask is uniform light yellow over the river, raw height starts blue/grey and emitter pulses turn orange while expanding outward, impulse/contact is black except localized blue/grey emitter flashes that do not expand, visible influence is blue with yellow expanding ripple shapes, and normal river view shows ripples. Space stops/starts the field immediately with no visible remnants when stopped, M stops orange movement, F triggers emitter pulses, controls/debug views worked, the scene could be stopped and run again without stale ripple/debug/material state, and there were no Output panel errors.

## Historical Change Log

Older change history can live here once the current summary is enough for the next agent.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create `river-ripples` as a dedicated feature folder | The roadmap has enough architecture and validation gates to warrant spec-driven tracking | Use this folder before ripple implementation |
| Rename the copied handoff template to `handoff-latest.md` | `01-workflow.md` requires that convention | Keep future handoff updates in this file |
| Keep first-pass ripples visual-only in docs | Roadmap explicitly says not to alter bakes, WaterSystem, flow, or buoyancy | Challenge physics-facing requests before patching |
| Treat Phase 0 decisions as open gates | The roadmap lists them as acceptance prerequisites | Resolve them before implementation |
| Preserve concrete roadmap details in `spec.md` and `plan.md` | Exact field properties, emitter properties, shader uniforms, and authoring controls should not disappear during implementation | Use those sections before adding public API or shader uniforms |
| Mark the citation-index check complete | The shared citations index already includes the CBerry22 ripple simulation repository | Recheck only when new external sources influence implementation |

## Current State

Implementation status:

- Standalone Phase 1 feedback spike, standalone Phase 2 mapping probe, standalone Phase 2 boundary-mask probe, RiverManager material ownership path, minimal built-in river shader neutral uniform path, guarded river shader sampling helpers, minimal visible normal blending, revised demo-backed visible normal review scene, debug parity path, shader-cost path, field/emitter workflow, named Add Node registration, demo-backed field/emitter authoring workflow, and Phase 9 script/resource authoring slice added. Human-visible normal-blend, debug-view, field/emitter visual/debug/control/stop-reload, Add Node visibility, and Phase 9 grouped inspector authoring acceptance are complete for the current gate.

Spec/plan status:

- Research: Updated with official Godot 4.6 Node, SubViewport, ViewportTexture, Resource, editor `@tool`, CanvasItem shader, spatial shader, shading-language, built-in shader function, ShaderMaterial, RenderingServer timing, Time timing, screen-reading constraints, local boundary-mask probe findings, material ownership probe findings, river shader neutral-path probe findings, shader sampling-helper findings, the X/Z mapping correction, visible-normal probe findings, demo review-scene diagnostic findings, debug parity findings, shader-cost findings, field/emitter lifecycle findings, field/emitter performance findings, Phase 9 authoring/API findings, and human-visible Phase 9 editor authoring acceptance.
- Spec: Drafted and updated for standalone feedback, mapping, boundary-mask, material ownership, river shader neutral-path, helper-budget, visible-normal validation, revised demo review-scene diagnostic status, debug parity status, shader-cost validation, field/emitter lifecycle, field/emitter performance validation, named Add Node registration, revised Phase 9 authoring/API planning, Phase 9 preset-resource/API implementation, human-visible Phase 9 editor authoring review, Phase 10 editor-polish contracts, Phase 10 read-only inspector implementation, and human-visible Phase 10 read-only inspector review.
- Plan: Drafted and updated for standalone feedback, mapping, boundary-mask, material ownership, river shader neutral-path, helper-budget, visible-normal validation, revised demo review scene status, debug parity status, shader-cost validation, field/emitter workflow, field/emitter performance validation, named Add Node registration, revised Phase 9 authoring/API planning, Phase 9 preset-resource/API implementation, human-visible Phase 9 editor authoring review, Phase 10 editor-polish contracts, Phase 10 read-only inspector implementation, and human-visible Phase 10 read-only inspector review.
- Tasks: Drafted with Phase 0 through future work.
- Validation: Passing standalone feedback checks, mapping check, boundary-mask check, RiverManager material ownership check, river shader neutral check, river shader sampling-budget check, visible-normal render check, revised demo review-scene smoke/diagnostic checks, debug parity check, shader-cost check, field/emitter lifecycle check, field/emitter performance check, Phase 9 preset API check, user-visible feedback/mapping/boundary/debug reviews, human-visible Phase 9 editor authoring review, human-visible Phase 10 read-only inspector review, and user-reported frozen-flow plus enabled-framerate fixture failures/fixes recorded.
- Review: Partial review complete through demo-backed field/emitter authoring visual/debug/control/stop-reload validation, Mobile/Compatibility renderer coverage, Phase 9 named-class parser/editor-cache validation, user-confirmed Add Node visibility, revised Phase 9 authoring/API plan, Phase 9 preset/grouping/starter/reload implementation, human-visible Phase 9 editor authoring review, Phase 10 editor-polish contract review, and automated plus human-visible Phase 10 read-only inspector review.

Validation status:

- Automated:
  - `RIPPLE_PHASE9_PRESET_API_PROBE_OK`
  - `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`
  - `RIPPLE_FIELD_EMITTER_PROBE_OK`
  - `RIPPLE_SHADER_COST_PROBE_OK`
  - `RIPPLE_DEBUG_PARITY_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`
  - `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`
  - `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`
  - `RIPPLE_BOUNDARY_MASK_PROBE_OK`
  - `RIPPLE_MAPPING_PROBE_OK`
  - `RIPPLE_FEEDBACK_PROBE_OK`
  - `RIPPLE_FEEDBACK_ANALYSIS_OK`
- Human-assisted:
  - User confirmed `ripple_feedback_review.tscn` center pulse spreads outward and decays.
  - User confirmed `ripple_mapping_review.tscn` colored scene markers agree with matching colored texture impulses.
  - User confirmed `ripple_boundary_mask_review.tscn` shows the expected river-shaped white boundary mask with the dry gap dark and dry sample markers outside the footprint.
  - User confirmed all debug views in `ripple_river_shader_visible_normal_review.tscn` work in the currently expected ways.
  - User confirmed field/emitter visual/debug/control/stop-reload behavior, the Phase 9 grouped inspector authoring review, and the Phase 10 read-only inspector lifecycle/dirty-state review, including hidden reserved fields, Add Node visibility, clean inspector reselection/lifecycle behavior, and no Output errors.
- Shader:
  - Standalone runtime feedback and impulse shaders compile through the probes; built-in `river.gdshader` declares neutral-default `i_ripple_*` uniforms including the unsampled impulse/contact texture, maps world X/Z into ripple U/V, has guarded ripple height/normal sampling functions, blends ripple normal offsets into `NORMAL_MAP`, keeps direct height sampling out of `fragment()`, and remains pixel-identical to baseline for disabled/missing texture cases. The custom screen-refraction path still uses the pre-ripple normal for this normal-only slice. `river_debug.gdshader` exposes raw height, impulse/contact, boundary mask, and visible influence modes.
- Editor:
  - Named Add Node visibility and ordinary grouped inspector authoring are human-visible accepted for `WaterRippleField` and `WaterRippleEmitter`. Phase 10 read-only inspector tooling, Apply controls, and capture/save controls are automated- and human-visible-proven.
- Visual:
  - Standalone center pulse spread/decay accepted; standalone mapping marker/texture agreement accepted; standalone boundary-mask shape/dry-gap review accepted. Automated render and diagnostic probes prove visible normal response exists in the revised demo-backed view while preserving flow speed and reusing precomputed animated texture frames; human-visible demo review confirms the river keeps moving and rings expand outward. Field/emitter and Phase 9 authoring reviews are human-visible accepted. Automated debug renders prove raw height, impulse/contact, boundary, and visible-influence views are distinct/nonblank.
- Runtime:
  - Standalone feedback, mapping, and boundary review/probe runtime paths, plus RiverManager-facing owner-scoped runtime material API, built-in river shader visible/debug paths, prototype `WaterRippleField`, prototype `WaterRippleEmitter`, and Phase 9 in-memory preset apply/capture APIs. The demo-backed review scene applies, toggles, switches debug views, and restores runtime ripple state without saving demo changes; the reusable field/emitter prototype applies, steps, disables, frees cleanly, and copies/captures presets in console validation.
- Performance:
  - Review-scene fixture upload cost addressed with precomputed frame textures. Current river shader-cost probe passes on Forward+, Mobile, and Compatibility: disabled-ready and visible-fragment direct ripple samples `0`, enabled normal helper remains at `3` simulation samples plus `1` boundary helper call. Forward+ 640x360 median GPU enabled visible normal is `0.319 ms` versus disabled live textures `0.315 ms`; Mobile is `0.311 ms` versus `0.305 ms`; Compatibility is `0.253 ms` versus `0.247 ms`. Field/emitter dispatch sweeps pass at 128/256/512 with 0/4/16 emitters across all three renderer methods.
- Manual:
  - Roadmap and templates were read and converted into the feature folder.

## Important Context

- First milestone is visual-only.
- Do not touch river bake resources, source signatures, WaterSystem bake resources, final flow, `system_flow.gdshader`, or buoyancy for first-pass ripples.
- `filter_renderer.gd` proves shader passes exist but is bake-oriented and uses readback; do not copy that runtime pattern into ripple simulation.
- `world_to_ripple_uv` is the intended single production mapping contract. The river shader now follows the standalone contract by using mapped world X/Z as ripple U/V.
- Exact first-pass river shader uniform names, field properties, emitter properties, and authoring-control notes are preserved in `spec.md` and `plan.md`.
- Boundary masking is required before visible river overlay. The accepted first source is target river mesh footprint rendering, not direct UV2 atlas bake textures; the standalone gate now has `RIPPLE_BOUNDARY_MASK_PROBE_OK`.
- Material ownership is proven for the current RiverManager-facing gate; preserve owner-scoped apply/clear and per-target material duplication/restore when adding shader integration.
- Shader sampling, visible normal blending, and current shader-cost are proven for the automated gate; preserve the disabled/missing-texture guard, world X/Z mapping, one visible normal helper call, no direct visible height sampling, the three simulation sample budget, and the no-added-draw-call cost profile.
- Debug parity is proven for the current automated gate; preserve the raw height, impulse/contact, boundary mask, and visible influence modes, and preserve runtime texture state when switching visible/debug materials.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.

## Artifact Hygiene

- Scratch folders or temporary projects created:
  - `.codex-research\godot-user`
  - `.codex-research\ripple-feedback-analysis`
  - `.codex-research\ripple-review-diagnostic`
- Generated bakes/resources created:
  - No bakes. Godot generated `.uid` sidecars for earlier probe scripts and runtime shaders after editor review. The new field/emitter scripts, scenes, probes, `ripple_boundary_mask.gdshader`, and `ripple_impulse_additive.gdshader` did not need bake resources; let the editor/import step create any missing `.uid` sidecars later if needed.
- Active files mirrored into scratch validation:
  - None.
- Files/folders that must be excluded from packaging:
  - `.codex-research` probes or local captures unless promoted.
- Files/folders safe to delete now:
  - None.

## Known Risks and Open Issues

- No-readback ping-pong feedback is proven for the standalone Godot 4.6.3 Forward+ console probe.
- Target river mesh-footprint boundary masking is proven for the standalone Godot 4.6.3 Forward+ console probe. The probe rendered a generated Waterways river mesh through `world_to_ripple_uv`, measured non-rectangular coverage at about `10.43%`, rejected a dry-corner impulse with `max_delta=0.0`, kept the dry gap neutral, and kept the across-bank sample below threshold.
- Texture precision at 128/256/512 is proven by automated validation readback, but still needs human visual review.
- Human-visible standalone spread/decay is proven; the observed square outline is a placeholder rectangular-field artifact and must not ship into river integration.
- Material ownership implementation is proven enough for the current gate through `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`; the path is RiverManager-facing `i_ripple_*` runtime ownership with per-target material duplication and restore.
- Shader sampling and minimal visible normal blending are proven enough for the current gate through `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, and human-visible demo review. Human review first found no visible rings, then found visible rings that froze flow and did not expand, then found the enabled path dropped framerate harshly. Those were fixture problems: center/camera readability, temporary `flow_speed=0.0` material overrides, a static review texture, and per-frame GDScript image generation. The revised scene preserves flow speed, starts at strength `1.25`, precomputes 48 texture frames, swaps texture references during playback, keeps the river moving, and expands rings outward. Initial validation found that Godot's spatial built-ins should be passed into helper functions instead of read directly from global helper scope.
- Debug parity is proven enough for the current gate through `RIPPLE_DEBUG_PARITY_PROBE_OK`. The first validation run caught a shader `fragment()` `return` that Godot rejected; the final path uses branch-wrapped fragment logic and exposes raw height, impulse/contact, boundary mask, and visible influence without losing runtime texture state across debug mode switches.
- Reusable field/emitter lifecycle is proven enough for the current Forward+, Mobile, Compatibility, and human-visible gates through `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, renderer coverage probes, and user review. The field owns runtime viewports/textures, generates target mesh-footprint masks, applies owner-scoped material state, rejects invalid/out-of-bounds impulses, caps/sorts emitter impulses, avoids normal-runtime readback, and clears state on disable/free.
- Reusable field/emitter dispatch performance is proven enough for the current Forward+, Mobile, and Compatibility console gates through `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` at 128/256/512 and 0/4/16 emitters. Shader-cost coverage also passes across all three renderer methods.
- Public Add Node registration is now implemented for `WaterRippleField` and `WaterRippleEmitter` through `@icon(...)` and `class_name` on their scripts. The earlier plugin-only `add_custom_type()` approach passed parser/editor-load checks but did not appear in human-visible Add Node inspection.
- The Phase 9 authoring/API implementation is console-proven through `RIPPLE_PHASE9_PRESET_API_PROBE_OK` and human-visible accepted: separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources, explicit in-memory `apply_preset()` / `capture_preset()` methods, copy-only semantics, built-in starter preset factories plus `apply_builtin_preset(name)` helpers, ordinary export groups, warning cleanup, no runtime resource saving, no exported preset slots, no live profile links, no refraction/displacement preset copy, storage-only `debug_visible`/reserved response values, readable inspector groups, hidden reserved fields, Add Node search visibility, and no Output errors in the review scene. Phase 10 read-only inspector lifecycle, Apply, capture/save, and visual-only gizmo helpers are automated-proven through `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` and human-visible accepted.
- Full transformed field support is intentionally deferred; current first path is axis-aligned X/Z fields.
- A rectangular debug simulation can look good while still being invalid for river integration; use the mesh-footprint boundary probe as the current standalone guard.
- Users may expect visual ripples to affect buoyancy; that is intentionally out of scope for the first milestone.

Relevant audit sections:

- `addons\waterways\docs\audit\pillow-system-audit.md` was checked before the mapping probe; no ripple-specific blocker was found there.

## Blockers

- Active implementation blocker: none for the diagnosed review-fixture, debug-parity, shader-cost, field/emitter lifecycle/performance, demo authoring, human-visible workflow, Mobile/Compatibility renderer issues, named Add Node registration issue, revised Phase 9 authoring/API plan, Phase 9 preset/grouping/starter/reload implementation, human-visible Phase 9 editor authoring review, Phase 10 planning split, or Phase 10 read-only inspector automated slice.
- Phase 0 decisions and branch safety are satisfied on branch `ripples`.
- Visible Godot/editor/runtime validation will be human-assisted unless an agent can genuinely inspect the running editor.

## Files To Inspect Before Editing

- `addons\waterways\docs\roadmaps\runtime-ripple-simulation-roadmap.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\spec.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\plan.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\tasks.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\validation.md`
- `addons\waterways\river_manager.gd`
- `addons\waterways\filter_renderer.gd`
- `addons\waterways\system_map_renderer.gd`
- `addons\waterways\shaders\river.gdshader`
- `addons\waterways\shaders\river_debug.gdshader`
- `addons\waterways\plugin.gd`

## Commands or Checks Used

```powershell
Get-Content -Raw -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\roadmaps\runtime-ripple-simulation-roadmap.md'
```

Result summary:

- Read the runtime ripple roadmap and preserved its visual-only scope and hard constraints.

```powershell
Get-ChildItem -Force -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\spec-driven\templates\feature-folder'
```

Result summary:

- Found template files: `plan.md`, `research.md`, `review.md`, `session-handoff.md`, `spec.md`, `tasks.md`, and `validation.md`.

```powershell
Test-Path -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\spec-driven\features\river-ripples'
```

Result summary:

- Confirmed the folder did not exist before creation.

```powershell
$root = 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo'
$godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe'
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
```

Result summary:

- Passed with `RIPPLE_BOUNDARY_MASK_PROBE_OK`. The probe rendered a generated Waterways river mesh footprint into ripple-field space, measured about `10.43%` non-rectangular mask coverage, rejected a dry-corner impulse with `max_delta=0.0`, kept the dry gap neutral, and kept the across-bank sample below threshold after 40 steps.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
```

Result summary:

- Existing gates still passed after the boundary hook: `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
```

Result summary:

- Historical pre-neutral-path result: passed with `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`. At that time, the material ownership probe still rejected the built-in river shader until `river.gdshader` declared `i_ripple_*`; the newer run below supersedes that expectation.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
```

Result summary:

- Passed with `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`. The neutral probe reported `max_delta=0.0` and `mean_delta=0.0` for disabled-with-textures, enabled-missing-simulation-texture, and enabled-missing-boundary-texture render comparisons against the baseline river shader. The material ownership probe now reports `default_shader_apply_accepted=true` for the built-in river shader.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_sampling_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
```

Result summary:

- Passed with `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, profile-isolated `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, and `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`. The sampling probe reported `world_to_uv_uses_xz=true`, `normal_helper_simulation_samples=3`, `normal_helper_boundary_calls=1`, `height_helper_simulation_samples=1`, `height_helper_boundary_calls=1`, one `ripple_normal_offset_at_world()` call from `fragment()`, and zero direct height calls from `fragment()`. The visible-normal probe reported zero delta for disabled/flat/black-boundary cases and visible delta for an enabled wave texture. The review-scene probe proved `ripple_river_shader_visible_normal_review.tscn` loads `Demo.tscn`, applies/toggles/restores runtime ripple state, starts in `close overhead` camera mode, keeps the review camera current, derives three mesh-based ripple centers, starts at strength `1.25`, preserves `runtime_flow_speed=1.0`, precomputes 48 frames, advances `ripple_texture_frame`, and does not increase `ripple_image_generation_count` during playback. The diagnostic proved active material state, center projection, mesh tangents, ripple texture slope, preserved flow speed, precomputed frame reuse, and visible enabled-vs-zero-strength delta in the revised view.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_sampling_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_diagnostic.gd'
```

Result summary:

- Passed with `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, and `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`. The debug parity probe confirmed the shader/menu contract, visible/debug runtime texture preservation, review-scene debug state preservation, and nonblank contrast for raw height (`0.27058823406696`), impulse/contact (`0.81960785388947`), boundary mask (`0.81960785388947`), and visible influence (`0.82091504335403`).

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_performance_probe.gd'
```

Result summary:

- Passed with `RIPPLE_FIELD_EMITTER_PROBE_OK` and `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`. The lifecycle probe validated prototype field/emitter scene/script loading, distinct read/write/impulse/boundary runtime targets, target mesh-footprint boundary-mask generation, owner-scoped material application/clear, out-of-bounds rejection, emitter cap/priority behavior, no same-target feedback hazard, no normal-runtime readback, disable/reenable cleanup, and free cleanup. The performance probe measured field dispatch at 128/256/512 with 0/4/16 emitters; dispatch medians were `5.933/5.738/5.755 ms`, `5.981/5.518/5.799 ms`, and `5.511/6.202/5.866 ms`.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_shader_cost_probe.gd'
```

Result summary:

- Regression sweep passed after the runtime additive impulse shader was split away from the standalone feedback-analysis impulse shader: `RIPPLE_FEEDBACK_ANALYSIS_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK`. Latest shader-cost medians were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`, and debug raw/contact/boundary/influence `0.115/0.118/0.117/0.129 ms`.

## Next Tasks

- [x] Confirm Phase 0 decisions with the user.
- [x] Create or confirm a dedicated branch before code work.
- [x] Build the standalone no-readback feedback spike.
- [x] Validate fixed impulse spread/decay at 128/256/512 with `RIPPLE_FEEDBACK_ANALYSIS_OK`.
- [x] Human-review fixed impulse and debug texture behavior.
- [x] Prove `world_to_ripple_uv` mapping with scene and texture markers.
- [x] Prove target river mesh-footprint boundary mask.
- [x] Prove material ownership and restore behavior.
- [x] Add safe ripple height and normal sampling helpers.
- [x] Add minimal visible ripple normal blending and automated render/review-scene probes.
- [x] Diagnose why visible normal blending was not visible on the demo river review scene despite automated probes passing.
- [x] Human-confirm base flow and outward ring motion in the revised close-overhead demo normal-blend review scene after the precomputed-frame performance fix.
- [x] Implement debug parity for raw ripple height, impulse/contact, boundary mask, and visible influence views.
- [x] Run shader-cost/performance validation before response/refraction/displacement tuning.
- [x] Build the reusable `WaterRippleField` / emitter workflow.
- [x] Validate field/emitter lifecycle, cleanup, material ownership, bounds rejection, caps, and dispatch performance.
- [x] Integrate the reusable field/emitter prototype into a demo/human-visible authoring workflow.
- [x] Human-review `ripple_field_emitter_demo_review.tscn`.
- [x] Cover non-Forward+ renderers now that the first demo workflow is accepted.
- [x] Plan Phase 9 authoring/API hardening before code: research Unity, Unreal Engine, Godot editor tooling, and comparable water/ripple authoring systems; define the public contract, export grouping, type-specific one-click preset behavior, and saved custom design workflow.
- [x] Split native editor polish into Phase 10: read-only inspector lifecycle, transient selectors, undo-aware editor actions, save dialogs, editor preview/helper boundaries, forbidden calls, and live-scene bridge deferral are documented in `phase10-editor-polish-plan.md`.
- [x] Add separate in-memory `WaterRippleFieldPreset` / `WaterRippleEmitterPreset` resources and type-specific `apply_preset()` / `capture_preset()` methods.
- [x] Add ordinary export grouping, warning cleanup, hidden reserved fields, built-in field/emitter starter presets, and scratch scene/resource save-reload checks.
- [x] Human-review the Phase 9 editor authoring surface for grouped inspector fields, hidden reserved fields, Add Node visibility, and no Output errors.
- [x] Implement Phase 10 read-only inspector rows and lifecycle cleanup.
- [x] Human-review Phase 10 read-only inspector lifecycle and dirty-state behavior.
- [x] Implement Phase 10 transient preset Apply controls with per-property editor undo setup.
- [x] Human-review Phase 10 Apply controls for selector non-dirty behavior, active preset display, undo/redo, no-op apply skipping, boundary non-mutation, lifecycle cleanup, and no Output errors.
- [x] Implement Phase 10 capture/save controls with transient scratch presets and explicit editor save paths.
- [x] Human-review Phase 10 capture/save controls for save-dialog, dirty-state, restart/reload, and no-live-link behavior.
- [x] Implement Phase 10 visual-only field/emitter gizmo helpers.
- [x] Human-review Phase 10 visual gizmos for readability, selection switching, plugin/scene lifecycle, play-stop cleanup, and non-dirty viewing.
- [x] Define the Phase 10 gizmo handle contract and validation checklist for field bounds plus emitter radius/moving-threshold editing.
- [x] Implement the first undo-backed Phase 10 handle slice for emitter `radius` and moving-mode `moving_emit_distance`.
- [x] Human-review Phase 10 emitter handles for practical dirty-state/lifecycle behavior, undo/redo, plugin disable, scene close/reopen, delete/undo-delete, play/stop cleanup, and no Output errors. No-op/cancel was not exposed/checked and dirty-prompt reporting was unclear, neither blocking the slice.
- [x] Implement undo-backed Phase 10 field `world_bounds` face handles.
- [x] Human-review Phase 10 field `world_bounds` handles for dirty-state, undo/redo, no-op/cancel if exposed, plugin disable, scene close/reopen, and play/stop behavior.
- [x] Implement the first editor-only Phase 10 boundary preview helper as a projected mesh-footprint gizmo outline.
- [x] Human-review Phase 10 boundary preview readability, non-dirty viewing, lifecycle cleanup, play/stop behavior, and no Output errors.
- [ ] Choose the next optional Phase 10 slice: `debug_visible` re-exposure, live-scene bridge work, or separate response/refraction/displacement tuning plan.

## Do Not Do Yet

- Do not implement Phase 10 editor polish outside the contract in `phase10-editor-polish-plan.md`.
- Do not add Phase 10 preset slots, live profile links, stored preset paths, or auto-apply flags to `WaterRippleField` or `WaterRippleEmitter`.
- Do not call runtime rebuild/reset/emission/material/boundary/source-signature/private resolver paths from read-only inspector rows, selectors, capture-only paths, or ordinary editor previews.
- Do not expand editable gizmo handles beyond emitter radius/moving-threshold and field `world_bounds` until the next handle contract and human-visible review checklist exist.
- Do not enable `Reset Feedback`, `Rebuild Runtime`, `Emit Once`, or runtime texture previews in ordinary editor inspection until a live-scene bridge is separately designed and validated.
- Do not tune visible ripple response, refraction, or displacement in `river.gdshader` without a separate tuning plan.
- Do not mutate shared river materials directly.
- Do not change river bakes, WaterSystem bakes, source signatures, final flow, `system_flow.gdshader`, or buoyancy.
- Ripple nodes are now registered as named Add Node script classes; do not imply the response/refraction/displacement controls or physics-facing behavior are production-ready.
- Do not implement camera-following fields until reprojection, clear-on-shift, or tile swapping is designed.

## Notes for the Next Agent

Phase 9 authoring is accepted, and Phase 10 read-only inspector slice 1, transient Apply controls, capture/save controls, visual field/emitter gizmos, practical emitter radius/moving-threshold handles, field `world_bounds` face handles, and editor-only boundary preview helpers are automated- and human-visible-proven. The reusable nodes and demo-backed authoring scene are console-proven across Forward+, Mobile, and Compatibility for field lifecycle/cleanup, material ownership, boundary-mask generation, emitter caps/priority, bounds rejection, 128/256/512 dispatch sweeps, shader-cost coverage, demo river targeting, emitter world placement, disable baseline restore, and reload cleanup. Human-visible review has accepted the current visual/debug/control/stop-reload workflow, `WaterRippleField` / `WaterRippleEmitter` Add Node visibility, grouped inspector surface, hidden reserved fields, Phase 10 read-only inspector behavior, Phase 10 Apply behavior, Phase 10 capture/save behavior, Phase 10 visual gizmo readability/dirty-state/lifecycle behavior, practical emitter handle behavior, field bounds handle behavior, boundary preview behavior, and no-Output-error review runs. Keep `debug_visible` re-exposure and live-scene runtime commands disabled until their own contracts exist, and do not jump to response/refraction/displacement tuning, final flow, WaterSystem, bakes, source signatures, or buoyancy without a separate plan.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so Codex does not alter the user's normal Godot editor profile.

Console probe pattern:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://path/to/ripple_probe.gd'
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Validation Commands

Future runtime readback scan after implementation:

```powershell
rg "get_image|ImageTexture|readback|get_texture\\(\\)\\.get_image" "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways"
```

Result summary:

- Record whether any ripple runtime path uses CPU readback. Bake paths may still use readback; the violation is normal runtime simulation or visible rendering.
