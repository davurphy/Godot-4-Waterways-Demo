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
- `addons/waterways/docs/research/river-research-citations.md` should be checked before external research-driven implementation changes.

## Current Truth

Use this as the review dashboard. Keep it concise and update it before handing off.

- Overall review status: Partial; standalone feedback spike, standalone mapping probe, standalone mesh-footprint boundary-mask probe, RiverManager-facing material ownership/restore probe, minimal river shader neutral-path probe, river shader sampling-budget probe, visible-normal render probe, demo-backed review-scene smoke probe, demo-backed review-scene diagnostic probe, debug parity probe, shader-cost probe, reusable field/emitter lifecycle probe, field/emitter dispatch-performance probe, post-review-strength-boost terrain-aware demo-backed field/emitter authoring probe/diagnostic, Mobile/Compatibility renderer probes, named-class parser/editor-cache checks, and Phase 9 preset/grouping/starter/reload probes pass automated review; feedback, mapping, boundary, demo-backed minimal visible normal blending, demo-backed debug parity, demo-backed field/emitter visual/debug/control/stop-reload behavior, Add Node visibility, and Phase 9 editor authoring surface also pass human-visible review.
- Blocking issues remaining: None for the standalone feedback spike.
- Important issues remaining: Response/refraction/displacement tuning remains gated, and native editor buttons/undo/save dialogs/previews remain Phase 10 work. Phase 9 grouped inspector fields, hidden reserved values, Add Node visibility, and script/resource-first starter behavior have passed human-visible review.
- Last validation relied on: Godot 4.6.3 Forward+ `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, regression `RIPPLE_FIELD_EMITTER_PROBE_OK`, regression `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and regression `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`; `--check-only --script` for the preset resources, changed ripple node scripts, and probe; static `git diff --check`; runtime preset-save/readback scan; forbidden-file diff confirming no river manager, WaterSystem, buoyancy, bake-resource, or shader changes for the Phase 9 authoring slice. Earlier validation also includes named-class parser/editor-cache checks, user-confirmed Add Node visibility, Mobile/Compatibility renderer coverage, and the full Forward+ ripple probe set listed in `validation.md`.
- Next action: Choose the next planned slice. Use `phase10-editor-polish-plan.md` for optional editor preset selectors, dedicated inspector buttons, undo-aware editor actions, save dialogs, and editor preview/debug helpers. Use a separate plan before response/refraction/displacement tuning.
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
| Validate runtime ripple behavior | Partial pass | Standalone feedback, mapping, boundary-mask, RiverManager material ownership, river shader neutral-path, shader sampling-budget, visible-normal render, demo diagnostic, debug parity, reusable field/emitter probes, post-review-strength-boost terrain-aware demo-backed field/emitter authoring probe/diagnostic, human-visible field/emitter visual/debug/control/stop-reload review, Mobile/Compatibility renderer coverage, named Add Node registration, human-visible Add Node inspection, Phase 9 preset/grouping/starter/reload probes, and human-visible Phase 9 editor authoring review pass for the current gate; response/refraction/displacement tuning is still unproven. |
| Validate Godot editor/runtime visuals | Partial pass | User confirmed standalone center pulse spreads and decays, confirmed mapping scene markers agree with texture impulses, confirmed boundary-mask shape/dry gap, confirmed the revised demo visible-normal fixture keeps the river moving while ripple rings expand outward after the framerate fix, confirmed all demo debug views work in the currently expected ways, confirmed the orange emitter behavior is better after the path fix, asked for stronger visible pulses, reported the field/emitter debug views and normal river view now show expected localized expanding ripples, confirmed Space/M/F controls behave correctly with no visible remnants after Space-off, confirmed stop/run-again cleanup produced no stale state or Output panel errors, confirmed `WaterRippleField`/`WaterRippleEmitter` plus icons are searchable as child nodes in both target scenes, and confirmed the Phase 9 grouped inspector authoring surface worked as expected. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Yes.
- Editor/runtime boundary preserved: Partial; current runtime material/debug switching, `WaterRippleField`/emitter runtime lifecycle, human-visible stop/reload cleanup, Mobile/Compatibility console renderer coverage, named-class parser/editor-cache checks, and human-visible Add Node visibility are proven for the current gate; deeper public API polish remains future work.
- Bake data and generated resources explicit: Yes; first pass requires no bake/data changes.
- Legacy Godot 3 behavior used only as reference: Yes.
- Extension points preserved: Yes in docs; planned but not implemented.
- Godot-native features preferred where practical: Yes for current spike; official SubViewport and CanvasItem shader docs were checked.
- Bespoke systems justified: Partial; runtime feedback, the minimal river visible/debug integration, field/emitter workflow, and custom type registration are justified and probe-proven, while deeper presets/API hardening remains gated.
- Comments explain non-obvious intent without restating obvious code: Partial; validation-only readback is labeled in the analysis probe.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Yes for this new folder.

## Validation Results

- Automated:
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
- Shader:
  - Standalone simulation and impulse shaders compile through probes; built-in river shader declares neutral `i_ripple_*` uniforms and the disabled/missing-texture render comparison passes. `river_debug.gdshader` exposes raw height, impulse/contact, boundary mask, and visible influence debug modes.
- Editor:
  - Named Add Node visibility and ordinary grouped inspector authoring are human-visible accepted for `WaterRippleField` and `WaterRippleEmitter`. Dedicated editor buttons, undo-aware actions, save dialogs, and previews remain Phase 10 work.
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
