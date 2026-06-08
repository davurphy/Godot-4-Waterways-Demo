# Tasks: River Ripples

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

## Current Truth

This is the task dashboard. Keep active work here and move completed or superseded task detail to `Historical or Closed Tasks`.

- Current status: Phase 0 decisions locked; standalone feedback, mapping, mesh-footprint boundary-mask, RiverManager-facing material ownership/restore, minimal river shader neutral-path, river shader sampling-budget, visible normal render, demo review-scene smoke, demo review-scene diagnostic, debug parity, shader-cost, reusable field/emitter lifecycle, field/emitter dispatch-performance, post-review-strength-boost terrain-aware demo-backed field/emitter authoring, Mobile/Compatibility renderer probes, Phase 10 read-only inspector skeleton, Phase 10 transient preset apply controls, and Phase 10 capture/save controls pass automated validation; feedback, mapping, boundary mask, demo-backed minimal visible normal blend, demo-backed debug parity, demo-backed field/emitter visual/debug/control/stop-reload behavior, Add Node visibility for `WaterRippleField`/`WaterRippleEmitter`, the Phase 9 editor authoring surface, Phase 10 read-only inspector lifecycle/dirty-state review, and Phase 10 Apply active-preset/undo/no-op/boundary/lifecycle review also passed human-visible validation.
- Current implementation slice: `water_ripple_field.gd` / `water_ripple_field.tscn` owns runtime ping-pong simulation, impulse, and boundary-mask `SubViewport` textures and applies owner-scoped `i_ripple_*` state through RiverManager; `water_ripple_emitter.gd` / `water_ripple_emitter.tscn` supports pulse, continuous, one-shot, and moving impulse modes. `WaterRippleField` and `WaterRippleEmitter` are now named `Node3D` script classes with ripple icons so Godot exposes them directly in Add Node after an editor file scan. The river shader slice remains minimal normal-only; custom refraction and displacement remain untuned/off.
- Remaining open task focus: Phase 9 script/resource authoring is accepted; Phase 10 read-only inspector slice 1 and slice 2 transient preset Apply controls are automated-proven and human-visible accepted. Phase 10 slice 3 capture/save controls are implemented and automated-proven; human-visible save-dialog, dirty-state, restart/reload, and no-live-link review is still pending. Later flow-aware or physics-facing work remains deferred.
- Last passing validation: Godot 4.6.3 Forward+ console `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, parser checks for `ripple_inspector_preset_apply_model.gd`, `ripple_inspector_status.gd`, `ripple_inspector_plugin.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd`, plus regression `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed on 2026-06-08. Latest Phase 10 validation includes active preset status/selector restoration plus capture/save checks: capture creates unsaved scratch field/emitter presets, saves them only through explicit `.tres` paths under `.codex-research`, reloads them with the correct preset scripts and values, keeps target routing/reserved values out, and keeps runtime field/emitter scripts and preset resources free of editor-only classes, `ResourceSaver`, and `.tres` save paths. Static `git diff --check`, forbidden-call scan, and runtime editor-class/save-path scan stayed clean. User confirmed the Phase 10 read-only inspector lifecycle/dirty-state review and Phase 10 Apply review; Phase 10 capture/save still needs human-visible editor review.
- Next recommended action: Human-review Phase 10 capture/save in the visible Godot editor, then choose optional Phase 10 helpers/gizmos or use a separate plan for response/refraction/displacement tuning. Final flow, WaterSystem, bakes, source signatures, buoyancy, and physics-facing ripple behavior remain deferred.
- Known deferred work: Flow-aware ripples, physics-facing ripple sampling, WaterSystem changes, saved persistence, and buoyancy behavior.

## Open Work

Use this section as the canonical checklist for unfinished ripple work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and `handoff-latest.md`.

- [x] Phase 0: Confirm first milestone is visual-only.
  - Validate: Spec, plan, and review state no first-pass flow, final-flow, WaterSystem, or physics-facing behavior.

- [x] Phase 0: Confirm no source-signature bump is needed.
  - Validate: Implementation plan and final diff leave source-signature logic and metadata unchanged.

- [x] Phase 0: Confirm no river bake resources or saved `RiverBakeData` resources are changed.
  - Validate: Git/resource diff shows no generated river bake maps, saved river resources, or bake metadata changes.

- [x] Phase 0: Confirm no WaterSystem bake, regeneration, or runtime map behavior is changed.
  - Validate: `WaterSystem` resources, `system_flow.gdshader`, WaterSystem bake outputs, and runtime WaterSystem sampling paths are unchanged.

- [x] Phase 0: Confirm no buoyancy, object drift, reverse-flow, or eddy-circulation behavior changes.
  - Validate: Buoyancy scripts and runtime movement behavior remain outside the first visual ripple slice.

- [x] Phase 0: Choose the first demo scenario.
  - Validate: Decision log names ducks, click/test emitters, rain, static emitters, or another concrete scenario.

- [x] Phase 0: Lock `world_to_ripple_uv` as the only production mapping input.
  - Validate: Plan has no separate min/size shader path except debug-only mirrors.

- [x] Phase 0: Decide axis-aligned X/Z bounds versus full transformed fields for the first implementation.
  - Validate: Unsupported transform cases are documented with warning behavior.

- [x] Phase 0: Choose target river mesh-footprint rendering as the first boundary-mask source or record a revised accepted source.
  - Validate: Plan explicitly rejects direct UV2-atlas bake textures as first-pass world-space masks.

- [x] Phase 0: Choose the material ownership path.
  - Validate: Plan records RiverManager-facing runtime API, per-target duplication/restore, or instance shader parameters with evidence.

- [x] Phase 0: Decide built-in custom type registration versus prototype/example nodes.
  - Validate: `plugin.gd` work is either planned or explicitly out of public API scope.

- [x] Phase 0: Choose debug parity path.
  - Validate: `river_debug.gdshader`, separate `WaterRippleField` views, or targeted probes are named before visible integration.

- [x] Phase 0: Record shader cost budget.
  - Validate: Disabled path target and enabled sample count target are in `spec.md`, `plan.md`, and `validation.md`.

- [x] Branch safety: Create or confirm a dedicated feature branch before implementation.
  - Validate: User confirms branch, Codex creates one, or user explicitly approves continuing on current branch.

- [x] Phase 1: Add `addons/waterways/shaders/runtime/ripple_simulation.gdshader`.
  - Validate: Shader parses and implements a damped feedback step without copied reference code.

- [x] Phase 1: Build a standalone no-readback feedback spike.
  - Validate: A ripple texture animates, rings spread and decay, and normal runtime does not call viewport image readback.
  - Current result: Console ownership/no-readback, validation-readback spread/decay, and human-visible review pass. The visible square outline is a rectangular-field edge artifact; the standalone mesh-footprint boundary gate now addresses that risk before river integration.

- [x] Phase 1: Document feedback ownership.
  - Validate: Read target, write target, swap timing, clear mode, update mode, impulse clear behavior, pause/resume, and scene reload behavior are recorded.

- [x] Phase 1: Verify texture precision at 128, 256, and 512.
  - Validate: Decay remains stable enough for first-pass visual use or limitations are documented.

- [x] Phase 1: Human-review fixed impulse and debug texture behavior.
  - Validate: User confirms a center pulse spreads outward and decays; any rectangular edge artifact is documented as standalone-field-only.

- [x] Phase 2: Implement `world_to_ripple_uv` generation.
  - Validate: Fixed world-space markers land at expected ripple UVs.
  - Current result: Standalone axis-aligned X/Z probe `ripple_mapping_review.gd` builds a `Transform3D` from fixed bounds and maps four world-space markers to expected UVs; `RIPPLE_MAPPING_PROBE_OK` passed and user confirmed the colored relative positions agree visually.

- [x] Phase 2: Implement equivalent shader mapping.
  - Validate: Debug texture markers and scene markers agree.
  - Current result: Probe-only shader `ripple_mapping_markers.gdshader` receives the same `world_to_ripple_uv` transform and renders texture impulses at the GDScript-predicted UVs; validation sampled the rendered texture and confirmed all four marker colors at expected pixels.

- [x] Phase 2: Render target river mesh footprint into boundary mask.
  - Validate: Boundary debug view matches visible water footprint.
  - Current result: Standalone `ripple_boundary_mask_review.gd` generates a close-parallel Waterways river mesh, transforms a mesh copy through the same axis-aligned X/Z `world_to_ripple_uv`, and renders the normalized mesh footprint into a transparent boundary mask. `RIPPLE_BOUNDARY_MASK_PROBE_OK` sampled water/dry points and measured non-rectangular coverage at about `10.43%`.

- [x] Phase 2: Feed boundary mask into simulation and impulse rejection.
  - Validate: Waves stop or fade at dry areas and field edges.
  - Current result: `ripple_boundary_mask_probe.gd` injects the mesh-footprint mask into the standalone feedback review path. Dry-corner impulse rejection produced `max_delta=0.0`, the dry gap between nearby channels stayed neutral, and the across-bank sample stayed below the probe threshold after 40 steps.

- [x] Phase 2.5: Prove RiverManager-facing material ownership and restore behavior before river shader edits.
  - Validate: A two-river probe applies planned `i_ripple_*` state through RiverManager, rejects non-ripple and unknown keys, duplicates per-target materials, preserves a shared source material, rejects wrong-owner apply/clear, keeps unrelated rivers active when one clears, survives debug view toggles, and restores original textures on clear, owner exit, and river tree exit.
  - Current result: `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK` now passes with both the test-only shader material and the built-in `river.gdshader`: planned `i_ripple_*` state is applied to duplicated runtime materials, a shared source material remains unchanged, wrong-owner apply/clear is rejected, debug toggles preserve visible state, and clear/owner-exit/river-exit restores original materials.

- [x] Phase 3: Add internal `i_ripple_*` uniforms to `river.gdshader`.
  - Validate: Missing or disabled ripple texture produces no visible effect.
  - Current result: `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK` passed with `max_delta=0.0` for disabled-with-textures, enabled-missing-simulation-texture, and enabled-missing-boundary-texture comparisons against the baseline river shader render.

- [x] Phase 3: Add safe ripple height and normal sampling helpers.
  - Validate: Enabled near-camera path stays within the Phase 0 sample budget.
  - Current result: `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK` passed. The visible normal slice calls `ripple_normal_offset_at_world()` once from `fragment()`, keeps `ripple_normal_offset_at_uv()` to three simulation samples and one boundary-mask helper call, keeps `ripple_height_at_uv()` to one simulation sample plus one boundary-mask helper call, keeps direct height sampling out of `fragment()`, and checks that river shader mapping uses world X/Z as ripple U/V.

- [x] Phase 3: Blend ripple normals into existing normal response.
  - Validate: Ripples do not replace flow animation, pillows, wakes, or eddy-line material behavior.
  - Current result: Minimal visible normal blending is implemented in `river.gdshader`; `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK` proves disabled/flat/black-boundary cases remain neutral and enabled wave texture changes the rendered normal response. The first no-visible demo failure was diagnosed as a review fixture/readability issue, not a material ownership failure. Later human passes caught and then verified fixes for frozen flow/static texture and harsh enabled-framerate behavior. The review scene now clusters three mesh-derived annular ripple centers, focuses on their real mesh positions, starts in close-overhead mode at strength `1.25`, preserves demo material flow speed, precomputes 48 review texture frames, swaps those frames during playback, and passes `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK` plus `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`. User rerun confirmed the framerate is greatly improved, the river keeps moving, and the ripple rings expand outward.

- [x] Phase 3: Implement selected debug parity path.
  - Validate: Raw ripple, impulse, boundary, and visible influence are inspectable.
  - Current result: `river_debug.gdshader` now exposes raw ripple height, impulse/contact, boundary mask, and visible influence debug modes; the debug view menu groups them under Ripples; the demo-backed review scene can switch between visible and debug modes without losing runtime ripple textures or animation state; `RIPPLE_DEBUG_PARITY_PROBE_OK` passed with measured contrast for all four debug views. User confirmed all views work in the currently expected ways; the contact view's broad yellow field is expected for the current fixture.

- [x] Phase 3.5: Run shader-cost/performance validation before response/refraction/displacement tuning.
  - Validate: Disabled path avoids direct ripple sampling, enabled visible normal path stays within the first-pass sample/timing budget, and debug views are measured as inspection tools rather than tuned visuals.
  - Current result: `RIPPLE_SHADER_COST_PROBE_OK` passed in Godot 4.6.3 Forward+ on an AMD Radeon RX 6800 XT. Static checks found disabled-ready and visible-fragment direct ripple samples at `0`, one visible helper call from `fragment()`, and the accepted enabled-normal budget of three simulation samples plus one boundary helper call. Latest controlled 640x360 median GPU timings were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`, and debug raw/contact/boundary/influence `0.115/0.118/0.117/0.129 ms`, all with one draw call.

- [x] Phase 4: Create `water_ripple_field.gd` and any needed scene.
  - Validate: A scene can add the field, initialize it, disable it, and clean it up.
  - Current result: Prototype `water_ripple_field.gd` and `water_ripple_field.tscn` are added. `RIPPLE_FIELD_EMITTER_PROBE_OK` validates runtime initialization, distinct ping-pong/impulse/boundary targets, mesh-footprint boundary generation, material application, disable/reenable cleanup, and free cleanup without mutating shared river materials.

- [x] Phase 4: Add RiverManager-facing runtime uniform API or selected ownership adapter.
  - Validate: Two rivers can have separate fields without material cross-talk.
  - Current result: `river_manager.gd` now exposes owner-scoped `apply_runtime_ripple_material_state()` and `clear_runtime_ripple_material_state()` for the planned `i_ripple_*` uniforms. It duplicates visible/debug materials for runtime state and restores originals on owner clear or tree exit.

- [x] Phase 4: Add warnings and lifecycle cleanup.
  - Validate: Invalid setup leaves river materials unchanged and scene reload leaves no stale texture state.
  - Current result: The RiverManager material API rejects invalid runtime keys and restores on owner/river exit. The prototype `WaterRippleField` reports setup warnings, refuses required-mask startup without a valid boundary, runs only outside editor hint mode, clears target material state on disable, rebuild, and exit, passed console cleanup checks in `RIPPLE_FIELD_EMITTER_PROBE_OK`, and passed human-visible demo stop/reload cleanup review.

- [x] Phase 4: Update `plugin.gd` only if nodes are built-in public API.
  - Validate: Registration status matches docs and inspector expectations.
  - Current result: `WaterRippleField` and `WaterRippleEmitter` use documented `@icon(...)` plus `class_name` registration as named `Node3D` script classes, because human-visible Add Node inspection showed plugin-only custom-type registration was not appearing. `--check-only --script` passes for `plugin.gd`, `water_ripple_field.gd`, and `water_ripple_emitter.gd`; a repo-local headless editor scan refreshed `.godot/global_script_class_cache.cfg`; a local probe found both global classes; and user confirmed both classes and icons are searchable as child nodes in `Demo.tscn` and `ripple_field_emitter_demo_review.tscn`.

- [x] Phase 5: Create `water_ripple_emitter.gd`.
  - Validate: Fixed, moving, continuous, and one-shot modes work or deferred modes are documented.
  - Current result: Prototype `water_ripple_emitter.gd` and `water_ripple_emitter.tscn` are added with pulse, continuous, one-shot, and moving modes. Emitters resolve a field by explicit path, ancestor, or field group and queue impulses through the field's world-space API.

- [x] Phase 5: Add emitter filtering, caps, priority, and bounds checks.
  - Validate: Out-of-bounds or dry-area emitters do not create visible impossible waves.
  - Current result: `RIPPLE_FIELD_EMITTER_PROBE_OK` validates world-to-ripple mapping, out-of-bounds rejection, priority/intensity sorting, emitter caps, capped-count reporting, and no same-target feedback hazard.

- [x] Phase 6: Integrate a demo scene.
  - Validate: Demo shows localized ripples and disabling returns the old visual baseline without changing bakes.
- Current result: Added `ripple_field_emitter_demo_review.tscn` with the real demo scene, an inspectable `WaterRippleField`, and three inspectable `WaterRippleEmitter` children for pulse, one-shot, and moving authoring. The first human-visible pass caught two emitters embedded in terrain, so the review controller now samples `World/HTerrain`, chooses exposed water anchors near the authored UVs, lifts authoring handles/markers above terrain, and keeps the moving marker synced. The next human-visible pass caught no visible emitter ripples; `ripple_field_emitter_demo_review_diagnostic.gd` found the impulse viewport was clearing to nonzero project color, making impulse/contact blue everywhere and raw height flat/nonlocal. `WaterRippleField` now uses transparent zero clear for its canvas viewports, the demo probe rejects full-field impulse/contact backgrounds, and post-fix diagnostics validate localized blue/green/orange impulse stamps. A later visible pass caught the orange moving path still crossing mostly land; `ripple_field_emitter_demo_review_anchor_diagnostic.gd` found farther-out exposed water anchors, the moving path was moved from the land-adjacent `z=28.8` row to anchors around `z=27.9`, `z=27.7`, and `z=26.6`, and the probe now requires at least `1.0m` water/terrain clearance for moving emitter/path samples. User then asked for stronger pulses; the review scene now uses field `ripple_strength=2.25`, `normal_strength=3.0`, fixed emitter intensity `1.0`, moving emitter intensity `0.9`, and larger emitter radii while keeping refraction/displacement at `0.0`. User then clarified the orange emitter still looked too intermittent, so its review-only moving settings now use `pulse_rate=12.0` and `moving_emit_distance=0.08` for a denser trail. Latest human-visible rerun showed expected debug/normal/control behavior: raw height and visible influence expand outward from emitter pulses, impulse/contact flashes stay localized, normal river view shows ripples, Space stops/starts immediately with no visual remnants when stopped, M stops orange movement, and F triggers emitter pulses. Controls and debug views worked correctly, stop/run-again cleanup did not leave stale ripple/debug/material state, and the Output panel had no errors.

- [x] Phase 7: Add debug and validation probes.
  - Validate: Probes catch mapping drift, material cross-talk, stale debug state, readback violations, and accidental bake changes.
- Current result: Existing feedback, mapping, boundary, material ownership, visible/debug shader, and shader-cost probes remain passing; `ripple_field_emitter_probe.gd`, `ripple_field_emitter_performance_probe.gd`, `ripple_field_emitter_demo_review_probe.gd`, `ripple_field_emitter_demo_review_diagnostic.gd`, and `ripple_field_emitter_demo_review_anchor_diagnostic.gd` cover field/emitter lifecycle, dispatch cost, demo placement/cleanup, zero-clear impulse texture behavior, and moving-path water clearance. Static scans stayed clean for normal-runtime readback and forbidden bake/WaterSystem/source-signature/buoyancy file changes.

- [x] Phase 8: Measure full field/emitter performance and tune defaults.
  - Validate: 128/256/512, no emitters, few emitters, many emitters, shader disabled, and shader enabled results are recorded for the reusable field/emitter path.
  - Current result: `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` passed on Godot 4.6.3 Forward+ / Mobile / Compatibility on an AMD Radeon RX 6800 XT for 128/256/512 fields with 0/4/16 emitters after the transparent-zero viewport clear fix. Forward+ dispatch medians were `5.477/6.059/5.704 ms` at 128, `6.405/5.650/5.521 ms` at 256, and `5.754/5.508/5.377 ms` at 512. Mobile medians were `5.935/5.791/6.007 ms`, `5.308/5.806/5.692 ms`, and `5.704/6.248/5.496 ms`; Compatibility medians were `6.376/6.091/5.647 ms`, `5.234/6.901/5.355 ms`, and `5.243/5.235/5.373 ms`. Shader disabled/enabled timing is covered by `RIPPLE_SHADER_COST_PROBE_OK` across Forward+, Mobile, and Compatibility.

- [x] Phase 8: Cover non-Forward+ renderers after demo workflow acceptance.
  - Validate: Focused demo authoring, debug parity, field/emitter performance, and shader-cost probes pass on Mobile and Compatibility or document renderer-specific limits.
  - Current result: Mobile (`--rendering-method mobile`) and Compatibility (`--rendering-driver opengl3 --rendering-method gl_compatibility`) both passed `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK`. Logs were written under `.codex-research\ripple-renderer-coverage`, and a narrowed scan found no actual error/warning/shader-failure lines.

- [x] Phase 9: Add authoring controls and presets only after runtime behavior is accepted.
  - Validate: Users can configure ripples without editing shader code and without unstable internal plumbing exposed accidentally.
  - Current result: Phase 9 slices are complete for named Add Node registration, in-memory type-specific preset resources/apply/capture APIs, ordinary export grouping, warning cleanup, hidden reserved values, built-in starter preset factories, and scratch scene/resource save-reload validation. The revised authoring/API planning pass is documented in `phase9-authoring-api-plan.md`; dedicated editor polish is split into `phase10-editor-polish-plan.md`. User confirmed the human-visible editor authoring review passed on 2026-06-08.

- [x] Phase 9 planning: Define the authoring polish/API contract before code changes.
  - Validate: A written plan compares relevant Unity, Unreal Engine, Houdini, and comparable industry water/ripple authoring patterns, then states what Waterways will adopt or reject.
  - Current result: `phase9-authoring-api-plan.md` compares Unity HDRP Water, Unity editor presets, Unreal Water Waves Assets/Niagara Fluids, Crest dynamic waves/foam, Godot export grouping/editor-plugin tooling, Waterways lineage, and AAA baked/procedural water references. It keeps Phase 9 scoped to script/resource-first authoring contract hardening, not visual tuning or native editor UI, and keeps `refraction_strength` and `displacement_strength` reserved/hidden from normal authoring until behavior is accepted.

- [x] Phase 9 planning: Define preset and custom-design behavior.
  - Validate: Presets are documented as one-click starting points that mutate normal editable values instead of live profile modes, users can still inspect and edit advanced settings, Phase 9 capture remains in-memory, and Phase 10 owns any editor save workflow.
  - Current result: `phase9-authoring-api-plan.md` defines presets as value starters, allows runtime script application/capture in memory without automatic asset writeback, plans separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources, rejects exported preset asset slots/live profile links in Phase 9, and explicitly rejects saving runtime textures, target material state, river bakes, `WaterSystem` data, or source signatures.

- [x] Phase 9 implementation: Organize the field/emitter authoring surface.
  - Validate: `WaterRippleField` and `WaterRippleEmitter` expose setup, routing/targets, boundary, simulation, visual response, debug, and reserved/advanced controls using ordinary Godot export grouping and stable property names, without changing runtime behavior unexpectedly.
  - Current result: `WaterRippleField` now groups visible authoring properties under Setup, Targets, Boundary Mask, Simulation, and Visual Response; `WaterRippleEmitter` now groups Routing, Shape, Emission, and Priority And Caps. `debug_visible`, `refraction_strength`, and `displacement_strength` are stored without normal inspector visibility. Warning cleanup now catches invalid target paths, invalid boundary source paths, empty field group routing, unsupported transformed fields, and missing group targets when detectable; field group changes update group membership, emitter field group/path changes clear cached routing, and invalid required-boundary state clears owned material state.

- [x] Phase 9 implementation: Decide and wire `debug_visible`.
  - Validate: `debug_visible` is hidden or storage-only in Phase 9 so the inspector does not expose an inert promise; Phase 10 may re-expose or rename it only after real helper/debug behavior exists.
  - Current result: `WaterRippleField.debug_visible` is now `@export_storage`, and `RIPPLE_PHASE9_PRESET_API_PROBE_OK` verifies it remains stored without normal inspector visibility.

- [x] Phase 9 implementation: Add built-in value-mutating presets.
  - Validate: Applying a field or emitter preset changes ordinary exported values, remains inspectable/editable, does not affect targets or material ownership, avoids unsupported shape/foam/refraction/displacement promises, and is covered by automated checks.
  - Current result: `WaterRippleFieldPreset` exposes built-in in-memory starters for Calm Local Field, Character Interaction Field, Rain-Sized Local Field, Heavy Impact Field, Performance Field, and Debug Strong Field. `WaterRippleEmitterPreset` exposes Footstep, Wading Character, NPC Ambient, Small Impact, Heavy Impact, Light Rain Drop, and Static River Disturbance. `WaterRippleField.apply_builtin_preset(name)` and `WaterRippleEmitter.apply_builtin_preset(name)` copy values through the same type-specific `apply_preset()` path without exported preset slots, live links, runtime saves, target routing changes, refraction/displacement promises, foam, dense rain systems, or unsupported wake shapes.

- [x] Phase 9 implementation: Add in-memory preset capture/apply resources.
  - Validate: `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources can capture/apply reusable type-specific values in memory without saving assets, assigning exported preset slots, saving transient runtime textures, or touching river bakes.
  - Current result: Added separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources plus `apply_preset(preset)` and `capture_preset()` on `WaterRippleField` / `WaterRippleEmitter`. The preset resources store only approved authoring values, exclude target paths/groups, runtime textures, refraction/displacement, bakes, source signatures, and live-link state, and the nodes still expose no exported preset asset slots. `RIPPLE_PHASE9_PRESET_API_PROBE_OK` verifies applying copies values, source preset edits after apply do not mutate nodes, capture returns new in-memory resources with empty `resource_path`, no `ResourceSaver` or `.tres` runtime save path exists in the new API, field visual-only apply keeps runtime viewports, and resolution/emitter-cap apply rebuilds/reapplies runtime state safely.

- [x] Phase 9 validation: Prove editor/runtime authoring behavior.
  - Validate: Parser/headless checks pass, Add Node visibility remains intact, export grouping appears without a custom inspector, scene save/reload rebuilds clean runtime textures, forbidden bake/WaterSystem/source-signature/buoyancy files remain unchanged, and human-visible editor workflow is understandable without editing shader code.
  - Current result: Parser checks pass for the two preset resources, `water_ripple_field.gd`, `water_ripple_emitter.gd`, and `ripple_phase9_preset_api_probe.gd`; `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed in Godot 4.6.3 Forward+. The Phase 9 probe validates export grouping metadata, storage-only reserved fields, built-in starter presets, no live preset slots, no runtime save path, saved scratch preset resources, and a scratch scene reload that rebuilds transient runtime textures and restores target material state on disable. User confirmed the visible editor workflow: grouped fields were readable, reserved fields stayed hidden, Add Node search found both ripple nodes, the review scene still ran correctly, and Output showed no errors.

- [x] Phase 10 planning: Native ripple editor polish.
  - Validate: `phase10-editor-polish-plan.md` remains the current plan for inspector buttons, undo-aware editor actions, save dialogs, editor-safe preview/debug helpers, forbidden editor calls, live-scene bridge deferral, transient selectors, scratch resources, lifecycle cleanup, and dirty-state behavior after Phase 9 resources/APIs are stable.
  - Current result: Phase 10 is documented separately so Phase 9 does not over-promise editor buttons or editor-time simulation preview. The current plan starts with a read-only inspector skeleton, keeps selectors transient, requires per-property editor undo for preset apply, saves captured presets only through explicit editor-owned paths, forbids runtime rebuild/reset/emission/material/boundary calls from read-only/selector/capture/preview paths, and keeps live-scene reset/rebuild/emit/texture preview controls disabled until a bridge is planned.

- [x] Phase 10 implementation slice 1: Add read-only ripple inspector tooling.
  - Validate: Editor plugin enable/disable, inspector reselection, scene close/reopen, node deletion, play/stop, and Add Node visibility stay clean; read-only field/emitter status rows inspect only exported values, configuration warnings, or safe snapshots; no read-only status row calls runtime rebuild/reset/emission/material/boundary/source-signature paths, private resolver/cache methods, or runtime RID/texture internals; read-only UI never marks scenes/resources dirty.
- Current result: Added `ripple_inspector_plugin.gd` registered from `plugin.gd` plus `ripple_inspector_status.gd` as a probeable non-editor helper. The status rows show exported values, configuration warnings, and conservative target/routing summaries only; unresolved path/group state stays unresolved instead of calling runtime/private resolvers. Parser checks and `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` pass; static scans confirm no forbidden runtime calls in the read-only inspector/status path and no editor-only class, `ResourceSaver`, or `.tres` save-path references leaked into runtime field/emitter scripts or preset resources. User confirmed the human-visible editor lifecycle and dirty-state review passed.

- [x] Phase 10 implementation slice 2: Add transient preset apply controls.
  - Validate: Preset selectors are editor UI state only, not node properties; Apply Field Preset and Apply Emitter Preset copy only the Phase 9 whitelisted values through one grouped per-property `EditorUndoRedoManager` action; no-op applies create no undo action and do not dirty the scene; editing a source preset after apply does not mutate nodes; runtime `apply_preset()` is not used as the editor undo do-method.
  - Current result: Added transient built-in preset selectors and `EditorResourcePicker` resource selectors to `ripple_inspector_plugin.gd`; Apply uses `EditorUndoRedoManager` `add_do_property()` / `add_undo_property()` entries from `ripple_inspector_preset_apply_model.gd` diffs instead of runtime `apply_preset()`. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` proves field/emitter apply diffs copy only whitelisted values, skip no-op applies, avoid target routing and hidden/reserved values, avoid runtime/private/forbidden calls, and keep runtime scripts free of editor-only classes or save paths. User confirmed human-visible selector non-dirty behavior, Apply undo/redo, same-actual-preset no-op dirty-state skipping, target/material/bake/reserved-value non-mutation, disabled placeholder behavior, and lifecycle/no-Output behavior.

- [ ] Phase 10 implementation slice 3: Add capture/save preset workflow.
  - Validate: Capture creates fresh in-memory scratch presets without node mutation or dirtying; Save uses an editor-owned save dialog and a user-selected `.tres`/resource path; runtime field/emitter scripts, preset resources, and runtime apply/capture paths gain no `ResourceSaver`, `.tres` write path, exported preset slot, source-preset overwrite default, or live link.
  - Current result: Implemented `Capture Field` / `Capture Emitter` and `Save Captured` controls in `ripple_inspector_plugin.gd`. Capture calls the existing in-memory `capture_preset()` path, stores the result as transient inspector/plugin state, starts with an empty `resource_path`, and does not assign a preset slot to the node. Save opens an editor-owned `EditorFileDialog` in `res://` save-file mode with a `.tres` filter and calls `ResourceSaver.save()` only after a user path is selected. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` now validates capture non-mutation, saved scratch `.tres` reload, no target/reserved value persistence, explicit save paths, and no editor/save leakage into runtime scripts or preset resources. Human-visible editor save-dialog, dirty-state, restart/reload, and no-live-link review remains pending.

- [ ] Phase 10 optional helpers: Add bounds/radius gizmos, debug helper visualization, or boundary preview only after their matrix rows are accepted.
  - Validate: Helper previews are editor-only overlays/gizmos or non-persistent scratch state; exported runtime scenes do not depend on them; cleanup runs on plugin disable, scene close, node deletion, inspector reselection, and play/stop; `debug_visible` is re-exposed or renamed only after visible helper behavior exists; `refraction_strength` and `displacement_strength` stay out of Phase 10.

- [ ] Future Phase 10 live-scene bridge: Design before enabling runtime inspector commands.
  - Validate: A separate plan proves how `Reset Feedback`, `Rebuild Runtime`, `Emit Once`, and runtime texture previews find the running-scene instance corresponding to the edited node, avoid mutating the edited scene by accident, handle multiple open/running scenes, and clean up across play/stop, scene reload, and plugin disable.

- [ ] Future: Scope flow-aware visual ripples separately.
  - Validate: Plan keeps the effect visual-only and optional.

- [ ] Future: Scope physics-facing ripple sampling separately.
  - Validate: Visible, runtime, WaterSystem, and validation behavior are planned together.

## Setup

- [x] Read `addons/waterways/docs/roadmaps/runtime-ripple-simulation-roadmap.md`.
- [x] Read `addons/waterways/docs/spec-driven/templates/feature-folder/`.
- [x] Read `addons/waterways/docs/spec-driven/00-constitution.md`.
- [x] Read `addons/waterways/docs/spec-driven/01-workflow.md`.
- [x] Confirm `addons/waterways/docs/spec-driven/features/river-ripples` did not already exist.
- [x] Create this feature folder.
- [x] Confirm `addons/waterways/docs/research/river-research-citations.md` already records `CBerry22/Godot-Water-Ripple-Simulation-Shader` as ripple inspiration.
- [ ] Read `spec.md`, `plan.md`, and `validation.md` before future implementation.
- [ ] Check `addons/waterways/docs/research/river-research-citations.md` before research-driven changes; it is the shared works-cited list for river-reading, flow-map, shader-water, and production-reference sources, and should be updated when new cited sources affect this feature.
- [ ] Check `audit/code-audit.md` or current audit notes for relevant known risks before code changes.
- [ ] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [ ] If running Godot, use the exact console/windowed launch instructions from `validation.md` or `handoff-latest.md`; console probes should use repo-local `.codex-research` user-data folders.
- [ ] Run the context challenge check: if the user or agent may be treating visual-only ripples as flow/physics, raise that with evidence before patching.

## Implementation

- [ ] Define or update the add-on extension points described in `spec.md` and `plan.md`.
  - Validate: Public/prototype node status, target registration, material ownership, and debug exposure are documented before code presents an API.
  - Current result: Public named-node registration is documented and implemented for `WaterRippleField` / `WaterRippleEmitter`; target registration, material ownership, and debug exposure remain the same proven runtime contracts.

- [ ] Implement the runtime feedback spike before visible river integration.
  - Validate: No readback, no same-target read/write, rings spread and decay, scene reload is clean.

- [ ] Implement boundary mask before visible river integration.
  - Validate: Boundary debug view and visible river footprint agree.

- [ ] Implement minimal river shader overlay after feedback, mapping, boundary, and material ownership gates pass.
  - Validate: Disabled path is neutral, enabled normal response is localized, existing river visuals remain recognizable.

- [ ] Implement reusable runtime nodes and emitter system.
  - Validate: Fields and emitters work in ordinary scenes, clean up, and do not affect unintended rivers.

- [ ] Integrate the selected demo scenario.
  - Validate: Demo review shows localized ripples without bake or WaterSystem changes.

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge check after validation: if results suggest the premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in the chat message to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene, if applicable, through human-assisted validation unless the agent can genuinely use the visible editor.
- [ ] Check shader output/debug views through human-assisted validation.
- [ ] Check runtime sampling/API behavior through human-assisted validation or a proven non-crashing runtime check.
- [ ] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] If validation used a scratch project, confirm active add-on scripts were mirrored there before running probes.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries.
- [ ] Update docs for any changed decisions.
- [ ] Update feature or architecture documentation for changed behavior, data flow, module boundaries, or validation procedures.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

- [x] 2026-06-07 created the `river-ripples` feature folder from the runtime ripple roadmap and feature-folder templates.
- [x] 2026-06-07 preserved roadmap-level field properties, emitter properties, internal shader uniform names, and later authoring controls in `spec.md` and `plan.md`.
- [x] 2026-06-07 checked the shared citations index and confirmed the CBerry22 ripple simulation repository is already recorded.
- [x] 2026-06-08 added `phase9-authoring-api-plan.md`, updated the Phase 9 research/plan/task docs, and expanded the shared citations index for authoring/API planning sources.
- [x] 2026-06-08 revised `phase9-authoring-api-plan.md` after adversarial review, split native editor polish into `phase10-editor-polish-plan.md`, and updated plan/task references to prefer script/resource-first Phase 9 work.
