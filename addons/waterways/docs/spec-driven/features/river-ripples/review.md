# Review: River Ripples

## Review Date

2026-06-08

## Scope Reviewed

- `addons/waterways/docs/roadmaps/runtime-ripple-simulation-roadmap.md`
- `addons/waterways/docs/spec-driven/templates/feature-folder/`
- `addons/waterways/docs/spec-driven/00-constitution.md`
- `addons/waterways/docs/spec-driven/01-workflow.md`
- Existing feature-folder style from `addons/waterways/docs/spec-driven/features/river-eddies/`
- This newly created `river-ripples` feature folder
- `addons/waterways/river_manager.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_probe.gd`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`
- `addons/waterways/water_ripple_field.gd`
- `addons/waterways/water_ripple_field.tscn`
- `addons/waterways/water_ripple_emitter.gd`
- `addons/waterways/water_ripple_emitter.tscn`
- `addons/waterways/plugin.gd`
- `addons/waterways/icons/ripple_field.svg`
- `addons/waterways/icons/ripple_emitter.svg`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_probe.gd`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_performance_probe.gd`
- `addons/waterways/resources/water_ripple_field_preset.gd`
- `addons/waterways/resources/water_ripple_emitter_preset.gd`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase9_preset_api_probe.gd`
- `addons/waterways/docs/spec-driven/features/river-ripples/phase10-editor-polish-plan.md`
- `addons/waterways/ripple_inspector_plugin.gd`
- `addons/waterways/ripple_inspector_status.gd`
- `addons/waterways/ripple_inspector_preset_apply_model.gd`
- `addons/waterways/ripple_gizmo.gd`
- `addons/waterways/ripple_gizmo_geometry.gd`
- `addons/waterways/ripple_gizmo_handle_model.gd`
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase10_inspector_probe.gd`
- `addons/waterways/docs/research/river-research-citations.md` should be checked before external research-driven implementation changes.

## Current Truth

Use this as the review dashboard. Keep it concise and update it before handing off.

- Overall review status: Partial; standalone feedback spike, standalone mapping probe, standalone mesh-footprint boundary-mask probe, RiverManager-facing material ownership/restore probe, minimal river shader neutral-path probe, river shader sampling-budget probe, visible-normal render probe, demo-backed review-scene smoke probe, demo-backed review-scene diagnostic probe, debug parity probe, shader-cost probe, reusable field/emitter lifecycle probe, field/emitter dispatch-performance probe, post-review-strength-boost terrain-aware demo-backed field/emitter authoring probe/diagnostic, Mobile/Compatibility renderer probes, named-class parser/editor-cache checks, Phase 9 preset/grouping/starter/reload probes, Phase 10 read-only inspector skeleton probe, Phase 10 transient Apply controls, Phase 10 capture/save controls, Phase 10 visual field/emitter gizmo helpers, Phase 10 emitter handle helpers, Phase 10 field `world_bounds` handle helpers, and Phase 10 field boundary preview helper pass automated review; feedback, mapping, boundary, demo-backed minimal visible normal blending, demo-backed debug parity, demo-backed field/emitter visual/debug/control/stop-reload behavior, Add Node visibility, Phase 9 editor authoring surface, Phase 10 read-only inspector lifecycle/dirty-state behavior, Phase 10 Apply active-preset/undo/no-op/boundary/lifecycle behavior, Phase 10 capture/save save-dialog/dirty-state/restart/no-live-link behavior, Phase 10 visual gizmo readability/dirty-state/lifecycle behavior, Phase 10 practical emitter handle behavior, Phase 10 field `world_bounds` handle behavior, and Phase 10 boundary preview behavior also pass human-visible review.
- Blocking issues remaining: None for the standalone feedback spike.
- Important issues remaining: Response/refraction/displacement tuning remains gated. Phase 10 read-only inspector skeleton, transient preset Apply controls, capture/save controls, visual-only gizmos, practical emitter radius/moving-threshold handle behavior, field `world_bounds` face handles, and field boundary preview helper are implemented and accepted for the current automated and human-visible gates. Emitter handle no-op/cancel was not checked because Godot did not expose an obvious gesture, and dirty-prompt reporting was unclear; neither blocks the slice. `debug_visible` re-exposure and live-scene reset/rebuild/emit/texture preview remain implementation work under the strict Phase 10 contracts.
- Last validation relied on: Godot 4.6.3 Forward+ `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`; `--check-only --script` for the gizmo handle model, gizmo geometry/gizmo scripts plus the preset apply model, inspector/status/plugin/probe scripts. The latest Phase 10 probe validates active preset status/selector restoration, capture/save, visual gizmos, boundary preview, emitter handles, and field bounds handles: unsaved scratch field/emitter captures, explicit `.tres` scratch saves, saved preset reload, no target/reserved value persistence, field/emitter helper segment counts including `field_boundary_preview=8`, no preview children, no exported-value mutation while building helpers, moving emitters expose radius plus moving-threshold handles, non-moving emitters expose only radius, tiny moving-threshold guides remain pickable, six field `world_bounds` face handles use stable IDs `2001..2006`, field handles map only to `world_bounds`, preserve opposite faces, clamp to minimum non-flipped size, skip no-op diffs, and no runtime editor/save leakage appears. Post-slice regression probes `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed; static scans found no forbidden editor helper calls or runtime editor/save leakage. The latest human-visible Phase 10 boundary preview review passed; earlier field `world_bounds` handle review confirmed field handle tests pass cleanly in the editor; radius/moving-threshold review confirmed property isolation, undo/redo, plugin disable/re-enable, close/reopen, delete/undo-delete, run/stop cleanup, and no Output errors. The prior visual gizmo, capture/save, and Apply reviews confirmed readable helpers, non-dirty selector/capture/viewing behavior, Apply/undo/redo behavior, save/reload behavior, no live links, and no Output errors.
- Next action: Choose optional `debug_visible` re-exposure design, live-scene bridge planning, or a separate response/refraction/displacement tuning plan.
- Historical detail starts at: `Decision Updates`.

## Findings

### Blocking

- None for the current material ownership/restore gate.

### Important

- Phase 0 decisions are locked for the first spike: standalone fixed/click-style emitter first, axis-aligned X/Z fields first, prototype nodes before registration, field/probe debug first, Forward+ first, and RiverManager-facing `i_ripple_*` material ownership. After runtime, renderer, and human-visible workflow acceptance, `WaterRippleField` and `WaterRippleEmitter` were promoted to public named `Node3D` script classes with `class_name` and `@icon`, matching Godot's documented custom-node Add Node path after plugin-only registration did not appear in human-visible inspection.
- The feedback path is proven enough for the standalone gate in Godot 4.6.3 Forward+: console probes confirm distinct ping-pong targets, no same-target hazard, no normal-runtime readback, fixed impulse response, spread, decay, and 128/256/512 behavior. User-visible scene review confirmed center pulse spread and decay.
- The user observed an inward-moving square outline in the standalone review scene. That is acceptable only as a rectangular field edge/boundary artifact in Phase 1 and reinforces that boundary masking is a hard gate before visible river integration.
- The standalone mapping probe is proven enough for the current gate in Godot 4.6.3 Forward+: `world_to_ripple_uv` generation from fixed axis-aligned X/Z bounds maps four world-space markers to expected UVs, and a probe-only shader renders texture impulses at those same positions.
- Official Godot docs were checked after user challenge. The implementation now relies on documented `SubViewport.UPDATE_ONCE`, viewport texture, and CanvasItem `UV` behavior instead of ad hoc coordinate assumptions.
- The standalone mesh-footprint boundary-mask probe is proven enough for the current gate in Godot 4.6.3 Forward+: a generated Waterways river mesh footprint is transformed through `world_to_ripple_uv`, rendered into a boundary mask, sampled against water/dry points, and fed into the standalone feedback path. Dry impulse rejection and close-parallel dry-gap checks passed. User screenshot confirmed the visible boundary mask shape and dark dry gap.
- RiverManager-facing material ownership is proven enough for the current gate with test-only shader materials: the runtime API accepts only planned `i_ripple_*` keys, duplicates per-target materials, rejects wrong-owner operations, preserves shared source material state, and restores on clear, owner exit, and river tree exit.
- The minimal built-in river shader neutral path is proven enough for the current gate: `river.gdshader` declares the planned `i_ripple_*` uniforms with neutral defaults, the RiverManager API now applies them to a duplicated built-in river material, and `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK` reported zero pixel delta for disabled-with-textures, enabled-missing-simulation-texture, and enabled-missing-boundary-texture cases.
- The river shader sampling and visible-normal slice is proven enough for the current automated gate: `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK` confirms the shader maps world X/Z to ripple U/V, `ripple_height_at_uv()` uses one simulation sample plus one boundary-mask helper call, `ripple_normal_offset_at_uv()` uses three simulation samples plus one boundary-mask helper call, and visible `fragment()` calls the world normal helper once without direct height sampling. The follow-up neutral render probe still reports zero pixel delta.
- Minimal visible normal blending is automated-proven and human-visible accepted for the current gate: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK` reported zero delta for disabled/flat/black-boundary cases and visible delta for an enabled wave texture. `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK` proves the demo-backed review scene applies, toggles, restores runtime ripple state, preserves demo `flow_speed=1.0`, precomputes 48 animation frames, and advances frame references without generating images during playback. `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK` proved the active rendered material receives expected `i_ripple_*` values, the mesh has tangents, all three revised centers land inside the close-overhead frame, and the enabled-vs-zero-strength capture shows visible annular normal changes at default strength `1.25`. User review confirmed the river keeps moving and ripple rings expand outward.
- Debug parity is automated-proven and human-visible accepted for the current gate: `river_debug.gdshader` exposes raw ripple height, impulse/contact, boundary mask, and visible influence modes; the debug menu lists them under Ripples; `RIPPLE_DEBUG_PARITY_PROBE_OK` confirms runtime ripple textures survive visible/debug material switching, review-scene debug toggles preserve animation state, and all four debug renders have nonblank contrast. User confirmed all views work in the currently expected ways; the broad yellow contact view is expected for the current broad precomputed contact fixture.
- Shader cost is automated-proven for the current gate: `RIPPLE_SHADER_COST_PROBE_OK` confirms disabled-ready and visible-fragment direct ripple samples are `0`, the enabled visible normal helper remains at three simulation samples plus one boundary helper call, debug inspection modes are measured separately, and all measured cases use one draw call on the Forward+, Mobile, and Compatibility desktop probes.
- The reusable field/emitter workflow is automated-proven for the current console gate: `WaterRippleField` owns runtime ping-pong, impulse, and boundary `SubViewport` targets, applies owner-scoped `i_ripple_*` material state through RiverManager, generates a mesh-footprint boundary mask from intended targets, clears state on disable/free, and accepts impulses from `WaterRippleEmitter` pulse/continuous/one-shot/moving modes. `RIPPLE_FIELD_EMITTER_PROBE_OK` covers lifecycle, caps, priority, out-of-bounds rejection, no readback, and material cleanup; `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` covers 128/256/512 fields with 0/4/16 emitters on Forward+.
- The demo-backed field/emitter authoring scene is automated-proven for the current post-review-strength-boost terrain-aware console gate and human-visible accepted for the current Forward+ workflow: `ripple_field_emitter_demo_review.tscn` instances `Demo.tscn`, exposes a real `WaterRippleField` and pulse/one-shot/moving `WaterRippleEmitter` children, targets the demo river, generates the river mesh-footprint boundary mask, preserves base `flow_speed=1.0`, samples `World/HTerrain` to avoid buried visible handles, renders localized emitter impulse stamps on a black impulse background, restores the baseline material on disable, reapplies cleanly, and reloads without stale runtime material state through `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. The first human-visible authoring pass caught two emitters embedded in terrain; the next caught no visible ripples. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK` found the impulse viewport had been clearing to a nonzero project color, then proved transparent-zero viewport clearing restores localized blue/green/orange impulse stamps. The next visible pass caught the orange moving path still crossing mostly land; `RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK` now records farther-out exposed water anchors, and the main probe rejects moving emitter/path terrain clearance below `1.0m`. The latest review-only strength boost raises simulation impulse and normal response plus emitter radii/intensities while keeping refraction/displacement off, and the orange moving emitter now emits densely enough to read as a trail through `pulse_rate=12.0` and `moving_emit_distance=0.08`. Latest human-visible rerun reports expected debug behavior, visible normal-view ripples, instant Space off/on cleanup, M moving-emitter control, F manual emission, working controls/debug views, no stale state after stop/run-again, and no Output panel errors.
- Named-node registration is automated- and human-proven for parser/import/cache/Add Node loading: `WaterRippleField` and `WaterRippleEmitter` declare `@icon(...)` and `class_name` on `Node3D` scripts, `--check-only --script` exits cleanly for the plugin and both scripts, a repo-local headless editor scan reaches editor layout ready, `.godot/global_script_class_cache.cfg` lists both ripple classes, and user confirmed both classes and icons are searchable as child nodes in `Demo.tscn` and `ripple_field_emitter_demo_review.tscn`.
- Non-Forward+ renderer coverage is automated-proven for the current gate: Mobile and Compatibility both pass the demo authoring probe, demo diagnostic render probe, debug parity probe, field/emitter dispatch performance probe, and shader-cost probe. Mobile used Vulkan Forward Mobile; Compatibility used OpenGL 3.3. A narrowed log scan found no actual error, warning, `ERR_`, failed, or shader-compilation lines. This is console/render-readback coverage, not human-visible Mobile/Compatibility viewport review.
- The Phase 9 script/resource authoring surface is automated- and human-visible-proven for the current contract: `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` are separate `Resource` types; `WaterRippleField` and `WaterRippleEmitter` expose explicit `apply_preset(preset)`, `capture_preset()`, and `apply_builtin_preset(name)` methods; applying copies approved values into ordinary properties; editing the source preset afterward does not mutate the node; capture returns a fresh in-memory resource with no path; ordinary export groups exist for fields, emitters, and presets; no exported preset slots, live links, runtime `ResourceSaver`, or `.tres` runtime save path exist; field presets do not copy target routing or reserved refraction/displacement values; `debug_visible`, `refraction_strength`, and `displacement_strength` are storage-only; built-in starters avoid unsupported wake, dense rain, foam, refraction, and displacement promises; scratch preset resources load back; and scratch scene reload rebuilds transient runtime textures and restores target material state on disable. User confirmed the visible editor review: field/emitter groups were readable, reserved fields stayed hidden, Add Node search found both ripple nodes, the review scene still behaved correctly, and Output showed no errors. Native editor polish is still deferred to `phase10-editor-polish-plan.md`.
- The Phase 10 editor-polish plan is specific enough to guard implementation. It forbids ordinary inspector UI from calling runtime rebuild/reset/emission/material/boundary/source-signature paths or private resolver/cache methods; it treats selectors as transient UI action inputs rather than saved node slots; it requires Apply actions to use one grouped per-property editor undo action and skip no-op applies; it keeps Capture non-mutating and Save editor-owned with an explicit user-selected path; it requires scratch resource/overlay/gizmo cleanup across plugin, scene, selection, node, and play/stop lifecycles; it keeps `debug_visible` hidden unless real helper behavior is implemented; and it defers live-scene reset/rebuild/emit/runtime texture preview until a bridge plan proves how to reach the running scene instance.
- Phase 10 read-only inspector slice 1 is automated- and human-visible-proven for the current contract: `ripple_inspector_plugin.gd` registers an `EditorInspectorPlugin` from `plugin.gd`, while `ripple_inspector_status.gd` keeps probeable read-only status logic outside the editor-only class because Godot only allows `EditorInspectorPlugin` instances inside the editor. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proves field/emitter status models expose exported values, configuration warnings, and conservative target/routing summaries, mutate no exported values, add no preview/runtime children, and avoid runtime/private resolver calls. Parser checks and static scans passed; user confirmed plugin enable/disable, inspector reselection, scene close/reopen, node deletion, play/stop, Add Node visibility, no Output errors, no stale duplicated UI, and no dirty-scene prompts from simple read-only inspection.
- Phase 10 transient Apply controls are automated- and human-visible-proven for the current contract: `ripple_inspector_plugin.gd` adds transient built-in selectors, a matching-type `EditorResourcePicker`, an `Active preset` row, and per-session custom-resource labels, receives `EditorUndoRedoManager` from `plugin.gd`, and commits one grouped action using per-property `add_do_property()` / `add_undo_property()` entries. `ripple_inspector_preset_apply_model.gd` keeps the value whitelist and exact built-in match detection probeable without owning editor UI. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proves field/emitter apply diffs skip no-ops, copy only approved Phase 9 values, identify active built-in matches after Apply, avoid target routing and hidden/reserved values, preserve source-preset edit isolation, avoid forbidden runtime/private calls, and keep runtime scripts free of editor-only classes or save paths. User confirmed selector/resource focus stayed non-dirty and created no live links, Apply/undo/redo passed, same-actual-preset no-op Apply did not dirty the scene, target routing/material/runtime ownership/bake/reserved values did not appear or change, neutral placeholder selection disabled Apply, and lifecycle checks had no stale UI or Output errors.
- Phase 10 capture/save controls are automated- and human-visible-proven for the current contract: `ripple_inspector_plugin.gd` uses transient captured presets, an editor-owned `EditorFileDialog`, and explicit user-selected `.tres` paths, while runtime field/emitter scripts and preset resources stay free of editor-only save classes and `.tres` write paths. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proves captured field/emitter presets remain scratch resources until saved, save/reload preserves preset scripts and values, target routing and reserved values are excluded, and no live node slot/path is added. User confirmed the visible workflow: capture alone did not dirty the scene, `Save Captured` worked for field and emitter scratch presets, saved presets loaded after restart/reopen with expected types and values, no node gained a preset slot/path/live link/auto-apply behavior, and Output showed no errors.
- Phase 10 visual field/emitter gizmo helpers are automated- and human-visible-proven for the visual-only contract: `ripple_gizmo.gd` registers an `EditorNode3DGizmoPlugin` from `plugin.gd`, while `ripple_gizmo_geometry.gd` keeps line-segment generation probeable without editor-only classes. The gizmo draws field bounds, field X/Z footprint plus center cross, explicit field target routes, emitter radius rings, moving-emitter threshold rings, and emitter-to-field route lines. At that slice, `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proved plugin registration/removal, expected segment counts, no preview children, no exported-value mutation, no forbidden runtime calls, and no runtime editor/save leakage. User confirmed visible readability, no unsaved-scene prompt from viewing only, and no Output errors after the selection/lifecycle/play-stop review. The later emitter handle slice is recorded separately below.
- Phase 10 emitter radius/moving-threshold handles are automated-proven for the first handle contract: `ripple_gizmo_handle_model.gd` keeps stable IDs, property whitelist, clamping, and no-op diff logic probeable without editor-only classes; `ripple_gizmo_geometry.gd` reports handle positions and tiny-threshold pickability guides; `ripple_gizmo.gd` adds axis-constrained handles and commits changed values with `EditorUndoRedoManager`. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proves moving emitters expose two handles, non-moving emitters expose one radius handle, no preview children are added, helper building mutates no exported values, handle changes affect only `radius`/`moving_emit_distance`, no forbidden runtime calls appear, and runtime scripts/preset resources remain free of editor-only references. User confirmed practical behavior: radius and moving-threshold drags edit only their intended properties, undo/redo works, plugin disable/re-enable works, close/reopen without saving works, delete/undo-delete works, run/stop cleanup works, and Output shows no errors. No-op/cancel was not checked because Godot did not expose an obvious gesture; dirty-prompt reporting was unclear.
- Phase 10 field `world_bounds` handles are automated- and human-visible-proven for the current gate: `ripple_gizmo_handle_model.gd` exposes six stable face IDs `2001..2006`, maps them only to `world_bounds`, preserves opposite faces, clamps before flipping below the minimum size, and skips no-op diffs; `ripple_gizmo_geometry.gd` reports face-center handle positions; `ripple_gizmo.gd` projects field drags along world axes and commits changed bounds through `EditorUndoRedoManager`. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proves six face handles, property mapping, handle positions, no preview children, no exported-value mutation during helper building, no forbidden runtime calls, and no runtime editor/save leakage. User confirmed the field handle tests all pass cleanly in the editor.

### Minor

- The shared citations index now includes the Godot SubViewport, CanvasItem shader, spatial shader, shading-language, ShaderMaterial, RenderingServer, and Time references used for feedback, shader uniforms, runtime material ownership, and shader-cost measurement.

## Premise Review

- Was the original premise correct, partially correct, or wrong?
  - Correct for documentation setup: the roadmap is substantial enough to deserve a dedicated spec-driven feature folder.
- Did any evidence suggest the user or agent was overlooking scene/data/context?
  - The roadmap itself warns that visual ripples are easy to confuse with flow or physics changes.
- If yes, was that raised with the user early enough?
  - Captured in `spec.md`, `plan.md`, `research.md`, `tasks.md`, `validation.md`, and `handoff-latest.md`.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation?
  - Code and validation clarification for the RiverManager-facing material ownership gate, minimal river shader neutral path, visible normal slice, and debug parity path; response/refraction/displacement tuning remains deliberately unstarted.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Create a `river-ripples` feature folder | Pass | Folder created under `addons/waterways/docs/spec-driven/features/`. |
| Generate docs from feature-folder templates | Pass | Created `spec.md`, `plan.md`, `tasks.md`, `research.md`, `validation.md`, `review.md`, and workflow-renamed `handoff-latest.md`. |
| Preserve roadmap constraints | Pass | Docs preserve visual-only scope, no-readback requirement, mapping, boundary, material ownership, debug, registration, shader cost gates, concrete `i_ripple_*` uniforms, field properties, emitter properties, and authoring-control notes. |
| Validate runtime ripple behavior | Partial pass | Standalone feedback, mapping, boundary-mask, RiverManager material ownership, river shader neutral-path, shader sampling-budget, visible-normal render, demo diagnostic, debug parity, reusable field/emitter probes, post-review-strength-boost terrain-aware demo-backed field/emitter authoring probe/diagnostic, human-visible field/emitter visual/debug/control/stop-reload review, Mobile/Compatibility renderer coverage, named Add Node registration, human-visible Add Node inspection, Phase 9 preset/grouping/starter/reload probes, human-visible Phase 9 editor authoring review, Phase 10 editor-polish planning, Phase 10 read-only inspector skeleton probes, human-visible Phase 10 read-only inspector lifecycle/dirty-state review, Phase 10 transient Apply automated/human-visible pass, Phase 10 capture/save automated/human-visible pass, Phase 10 visual gizmo automated/human-visible pass, Phase 10 emitter handle automated/human-visible pass, Phase 10 field bounds handle automated/human-visible pass, and Phase 10 boundary preview automated/human-visible pass for the current gates; response/refraction/displacement tuning plus future live-scene workflows are still unproven. |
| Validate Godot editor/runtime visuals | Partial pass | User confirmed standalone center pulse spreads and decays, confirmed mapping scene markers agree with texture impulses, confirmed boundary-mask shape/dry gap, confirmed the revised demo visible-normal fixture keeps the river moving while ripple rings expand outward after the framerate fix, confirmed all demo debug views work in the currently expected ways, confirmed the orange emitter behavior is better after the path fix, asked for stronger visible pulses, reported the field/emitter debug views and normal river view now show expected localized expanding ripples, confirmed Space/M/F controls behave correctly with no visible remnants after Space-off, confirmed stop/run-again cleanup produced no stale state or Output panel errors, confirmed `WaterRippleField`/`WaterRippleEmitter` plus icons are searchable as child nodes in both target scenes, confirmed the Phase 9 grouped inspector authoring surface worked as expected, confirmed the Phase 10 read-only inspector rows/lifecycle/dirty-state behavior worked as expected, confirmed Phase 10 Apply behavior worked as expected, confirmed Phase 10 capture/save loaded saved field/emitter presets after restart/reopen without node preset slots, live links, auto-apply behavior, or Output errors, confirmed Phase 10 visual gizmo helpers were readable without dirty prompts or Output errors, and confirmed practical Phase 10 emitter handle behavior passed. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes.
- Editor/runtime boundary preserved: Partial; current runtime material/debug switching, `WaterRippleField`/emitter runtime lifecycle, human-visible stop/reload cleanup, Mobile/Compatibility console renderer coverage, named-class parser/editor-cache checks, human-visible Add Node visibility, Phase 10 editor-only boundary planning, Phase 10 read-only inspector forbidden-call/export-boundary scans, Phase 10 human-visible read-only inspector lifecycle/dirty-state review, Phase 10 automated/human-visible Apply selector/undo/static boundary checks, Phase 10 automated/human-visible capture/save boundary checks, Phase 10 automated/human-visible visual-gizmo boundary checks, Phase 10 automated plus practical human-visible emitter-handle checks, Phase 10 automated/human-visible field-bounds-handle checks, and Phase 10 automated/human-visible boundary-preview checks are proven for the current gate; live-scene bridge validation remains open.
- Bake data and generated resources explicit: Yes; first pass requires no bake/data changes.
- Legacy Godot 3 behavior used only as reference: Yes.
- Extension points preserved: Yes in docs; planned but not implemented.
- Godot-native features preferred where practical: Yes for current spike; official SubViewport and CanvasItem shader docs were checked.
- Bespoke systems justified: Partial; runtime feedback, the minimal river visible/debug integration, field/emitter workflow, and custom type registration are justified and probe-proven, while deeper presets/API hardening remains gated.
- Comments explain non-obvious intent without restating obvious code: Partial; validation-only readback is labeled in the analysis probe.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Yes for this new folder.

## Validation Results

- Automated:
  - `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` with read-only field/emitter status rows, transient Apply diff validation, plugin registration, forbidden-call scans, no runtime editor-class/save-path leakage, no status-model mutation, no target/reserved Apply copying, no-op Apply diff skipping, and source-preset edit isolation
  - `--check-only --script` for `ripple_inspector_preset_apply_model.gd`, `ripple_inspector_status.gd`, `ripple_inspector_plugin.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd`
  - `RIPPLE_PHASE9_PRESET_API_PROBE_OK` with export grouping, built-in starter preset, and scratch save/reload coverage
  - `--check-only --script` for `water_ripple_field_preset.gd`, `water_ripple_emitter_preset.gd`, `water_ripple_field.gd`, `water_ripple_emitter.gd`, and `ripple_phase9_preset_api_probe.gd`
  - `--check-only --script addons/waterways/plugin.gd` after custom type registration
  - Mobile and Compatibility `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`
  - Mobile and Compatibility `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`
  - Mobile and Compatibility `RIPPLE_DEBUG_PARITY_PROBE_OK`
  - Mobile and Compatibility `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`
  - Mobile and Compatibility `RIPPLE_SHADER_COST_PROBE_OK`
  - Terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`
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
  - `RIPPLE_MAPPING_PROBE_OK`
  - `RIPPLE_BOUNDARY_MASK_PROBE_OK`
  - `RIPPLE_FEEDBACK_PROBE_OK`
  - `RIPPLE_FEEDBACK_ANALYSIS_OK`
- Human-assisted:
  - User confirmed standalone center pulse spreads outward and decays.
  - User confirmed standalone mapping markers agree with matching texture impulses.
  - User confirmed standalone boundary mask shape and dry gap through `ripple_boundary_mask_review.tscn` screenshot.
  - User confirmed all demo debug views work in the currently expected ways; contact currently reads as a broad yellow field by fixture design.
  - User caught the first `ripple_field_emitter_demo_review.tscn` placement as visibly wrong, with two emitters embedded in terrain; later terrain-aware placement, stronger pulses, denser moving trail, controls/debug views, Space disable cleanup, and stop/run-again cleanup passed visible review with no Output panel errors.
  - User confirmed the Phase 9 editor authoring review: field/emitter groups were readable, reserved fields stayed hidden, Add Node search found both ripple nodes, the review scene still behaved correctly, and Output showed no errors.
  - User confirmed the Phase 10 editor capture/save review: capture alone did not dirty the scene, `Save Captured` saved deliberate scratch field/emitter `.tres` preset assets, saved presets loaded after restart/reopen with expected types and values, no node gained a preset slot/path/live link/auto-apply behavior, and Output showed no errors.
  - User confirmed the Phase 10 visual gizmo review: field box/footprint/route helpers and emitter radius/moving/route helpers were readable, viewing only did not prompt for unsaved scene changes, and Output showed no errors.
- Shader:
  - Standalone simulation and impulse shaders compile through probes; built-in river shader declares neutral `i_ripple_*` uniforms and the disabled/missing-texture render comparison passes. `river_debug.gdshader` exposes raw height, impulse/contact, boundary mask, and visible influence debug modes.
- Editor:
  - Named Add Node visibility and ordinary grouped inspector authoring are human-visible accepted for `WaterRippleField` and `WaterRippleEmitter`. Phase 10 read-only inspector rows are automated- and human-visible-proven through a plugin/status helper split, forbidden-call scans, and the editor lifecycle/dirty-state review. Phase 10 transient Apply controls are automated- and human-visible-proven through per-property undo setup, active preset status/selector restoration, whitelist probes, and the visible Apply review. Phase 10 capture/save controls are automated- and human-visible-proven through explicit scratch save/reload, editor/runtime boundary scans, visible save-dialog review, dirty-state review, restart/reload, and no-live-link checks. Phase 10 visual gizmos, practical emitter handles, field bounds handles, and boundary preview helper are automated- and human-visible-proven.
  - Live-scene commands remain unimplemented.
- Visual:
  - Standalone review scene pass for center pulse spread/decay; mapping review pass for colored marker/texture agreement; boundary-mask review screenshot pass for mask shape/dry gap; demo visible-normal review pass; demo debug-view review pass; field/emitter review-scene pass; Phase 9 editor authoring pass; rectangular edge artifact documented.
- Bake output:
  - None; no bake changes were made.
- Runtime:
  - Standalone feedback, mapping, and boundary-mask review/probe paths, plus RiverManager-facing runtime material ownership/restore API, built-in river shader neutral uniform path, prototype `WaterRippleField`/`WaterRippleEmitter` paths, and in-memory Phase 9 preset apply/capture APIs.
- Performance:
  - Review-scene fixture image-generation cost is addressed through precomputed frames. Current shader-cost validation passes on Forward+, Mobile, and Compatibility, with enabled visible-normal deltas of about `+0.004 ms`, `+0.006 ms`, and `+0.006 ms` over disabled live textures respectively on the controlled 640x360 probes. Field/emitter dispatch-performance validation passes at 128/256/512 with 0/4/16 emitters on Forward+, Mobile, and Compatibility.
- Manual:
  - Roadmap was mapped into the feature-folder structure and checked against workflow naming.

## Documentation Consistency Check

- [x] Closed tasks are checked off in `tasks.md`.
- [x] No stale "open follow-up" language remains for completed docs creation.
- [x] Resolved open questions moved to `spec.md` resolved questions or decision log where applicable.
- [x] `plan.md` reflects intended architecture and lifecycle behavior from the roadmap.
- [x] `validation.md` current snapshot and matrix match the current debug-parity status.
- [x] Latest handoff points to the true next action.
- [x] Phase 10 plan constraints are reflected in the dashboard docs: editor-only placement, transient selectors, undo/dirty-state matrix, forbidden runtime calls, scratch cleanup, and live-scene bridge deferral.
- [x] Shared works-cited index checked or updated: `addons/waterways/docs/research/river-research-citations.md`.

## Follow-Up Tasks

- [x] Lock Phase 0 decisions with the user.
- [x] Create or confirm a feature branch before implementation.
- [x] Build the standalone no-readback ripple feedback spike.
- [x] Human-review the standalone feedback scene for visible ring spread/decay.
- [x] Add the first mapping probe before river shader integration.
- [x] Add the first boundary-mask probe before river shader integration.
- [x] Add guarded river shader height/normal sampling helpers before visible blending.
- [x] Update this review after the first validation run.
- [x] Add debug parity views/probe before shader-cost validation.
- [x] Run shader-cost/performance validation before response/refraction/displacement tuning.
- [x] Build and validate the reusable `WaterRippleField` / emitter workflow.
- [x] Integrate the reusable field/emitter prototype into a demo-backed authoring workflow and validate it by console probe.
- [x] Human-review full scene stop/reload cleanup for the demo-backed field/emitter authoring workflow.
- [x] Cover Mobile and Compatibility renderers with focused field/emitter, debug parity, performance, and shader-cost probes.
- [x] Add separate in-memory `WaterRippleFieldPreset` / `WaterRippleEmitterPreset` resources plus type-specific `apply_preset()` / `capture_preset()` methods.
- [x] Human-review the Phase 9 grouped inspector surface, hidden reserved fields, Add Node visibility, and no-Output-error review scene behavior.
- [x] Integrate the Phase 10 editor-polish plan into the living docs after adversarial review tightened the editor/runtime boundary.
- [x] Implement Phase 10 read-only inspector skeleton and lifecycle cleanup before adding mutating editor actions.
- [x] Human-review Phase 10 read-only inspector lifecycle, dirty-state behavior, Add Node visibility, and no-Output-error behavior before adding mutating editor actions.
- [x] Implement Phase 10 transient preset Apply controls with per-property editor undo setup.
- [x] Human-review Phase 10 Apply controls for active-preset display, undo/redo, no-op dirty-state behavior, selector non-persistence, and no Output errors.
- [x] Implement Phase 10 capture/save preset workflow with editor-only explicit `.tres` save paths.
- [x] Human-review Phase 10 capture/save for dirty-state behavior, restart/reload, no live links, and no Output errors.
- [x] Implement Phase 10 visual-only field/emitter gizmo helpers.
- [x] Human-review Phase 10 gizmo readability, dirty-state behavior, lifecycle cleanup, and no Output errors.
- [x] Define the Phase 10 handle contract and validation checklist before code.
- [x] Implement undo-backed emitter radius/moving-threshold handles with automated validation.
- [x] Human-review practical Phase 10 emitter handle behavior: radius/moving-threshold property isolation, undo/redo, plugin disable/re-enable, close/reopen, delete/undo-delete, run/stop cleanup, and no Output errors. No-op/cancel was not exposed/checked; dirty-prompt reporting was unclear.
- [x] Implement editor-only Phase 10 boundary preview helper with automated validation.
- [x] Human-review Phase 10 boundary preview helper for readability, non-dirty viewing, lifecycle cleanup, play/stop behavior, and no Output errors.

## Decision Updates

Record any spec or plan changes discovered during review.

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-07 | Use `handoff-latest.md` instead of `session-handoff.md`. | `01-workflow.md` says copied feature folders should rename the handoff template. |
| 2026-06-07 | Keep this pass documentation-only. | The user asked for the feature folder and generated docs, not implementation. |
| 2026-06-07 | Treat Phase 0 decisions as prerequisites, not hidden assumptions. | The roadmap names them as safety gates before visible river integration. |
| 2026-06-07 | Preserve concrete roadmap details in the feature docs. | Exact field properties, emitter properties, `i_ripple_*` uniforms, and authoring controls were too easy to lose in the first translation. |
| 2026-06-07 | Split broad Phase 0 safety scope into separate task gates. | Source signatures, river bakes, WaterSystem behavior, and buoyancy deserve independent confirmation before implementation. |
| 2026-06-07 | Use official Godot docs to guide the feedback spike. | `SubViewport.UPDATE_ONCE`, viewport texture access, and CanvasItem `UV` semantics are documented; avoid undocumented coordinate detours. |
| 2026-06-07 | Pass spatial shader built-ins into ripple helper functions as arguments. | Godot 4.6.3 rejected reading `INV_VIEW_MATRIX` directly inside global helper scope; argument-based helpers compile and keep future world-position mapping explicit. |
| 2026-06-08 | Start Phase 9 with authoring/API planning before code. | The runtime workflow is proven enough for the current gate; the next risk is public controls and presets that imply unstable visual tuning or hidden runtime plumbing. |
| 2026-06-08 | Split native editor polish into Phase 10. | Dedicated inspector buttons, undo-aware actions, save dialogs, and editor previews need explicit Godot editor-plugin design instead of being casual Phase 9 promises. |
| 2026-06-08 | Keep the first Phase 9 preset implementation script/resource-only. | `RIPPLE_PHASE9_PRESET_API_PROBE_OK` proves copy/capture semantics in memory without exported preset slots, live profile links, runtime resource saving, or Phase 10 editor actions. |
| 2026-06-08 | Treat Phase 10 as an editor-plugin lifecycle and undo/dirty-state problem before it is a button problem. | Ordinary inspector UI targets edited-scene `@tool` nodes, not running-scene instances, so runtime reset/rebuild/emit/texture preview actions stay disabled until a live-scene bridge is separately designed and validated. |
| 2026-06-08 | Keep Phase 10 read-only status logic in a non-editor helper loaded by the inspector plugin. | Godot only allows `EditorInspectorPlugin` instances inside the editor; the helper lets console probes validate status rows without instantiating an editor-only class, while the plugin remains responsible for adding inspector controls. |
| 2026-06-08 | Keep Phase 10 Apply value diffing in a probeable helper and commit changes through the inspector plugin's editor undo manager. | Console probes can verify whitelists, no-op diffs, source-preset isolation, and forbidden boundaries without instantiating editor-only UI; the editor plugin still owns `EditorResourcePicker` controls and `EditorUndoRedoManager` commits. |
| 2026-06-08 | Keep first Phase 10 gizmos visual-only and probe segment generation outside the editor-only class. | Official Godot gizmo docs separate line drawing from editable handles; non-mutating helper lines can be validated now, while handle edits need a later undo/dirty-state contract. |
