# Tasks: River Ripples

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

## Current Truth

This is the task dashboard. Keep active work here and move completed or superseded task detail to `Historical or Closed Tasks`.

- Current status: Phase 0 decisions locked; standalone feedback, mapping, mesh-footprint boundary-mask, RiverManager-facing material ownership/restore, minimal river shader neutral-path, river shader sampling-budget, visible normal render, demo review-scene smoke, demo review-scene diagnostic, debug parity, shader-cost, reusable field/emitter lifecycle, field/emitter dispatch-performance, post-review-strength-boost terrain-aware demo-backed field/emitter authoring, and Mobile/Compatibility renderer probes pass automated validation; feedback, mapping, boundary mask, demo-backed minimal visible normal blend, demo-backed debug parity, and demo-backed field/emitter visual/debug/control/stop-reload behavior also passed human-visible validation.
- Current implementation slice: `water_ripple_field.gd` / `water_ripple_field.tscn` owns runtime ping-pong simulation, impulse, and boundary-mask `SubViewport` textures and applies owner-scoped `i_ripple_*` state through RiverManager; `water_ripple_emitter.gd` / `water_ripple_emitter.tscn` supports pulse, continuous, one-shot, and moving impulse modes. `plugin.gd` now registers `WaterRippleField` and `WaterRippleEmitter` as add-on custom types with ripple icons. The river shader slice remains minimal normal-only; custom refraction and displacement remain untuned/off.
- Remaining open task focus: human-visible add-node inspection, deeper authoring presets/API hardening, and later response/refraction/displacement tuning.
- Last passing validation: Mobile and Compatibility Godot 4.6.3 console `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK`; earlier Forward+ `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, and regression `RIPPLE_SHADER_COST_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`, plus user-visible `ripple_boundary_mask_review.tscn`, `ripple_mapping_review.tscn`, `ripple_feedback_review.tscn`, and demo-backed visible reviews on 2026-06-07.
- Next recommended action: Human-check the editor Add Node flow for `WaterRippleField` / `WaterRippleEmitter`, or continue Phase 9 presets/API hardening before response/refraction/displacement tuning. Final flow, WaterSystem, bakes, source signatures, and buoyancy remain deferred.
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
  - Current result: `plugin.gd` registers `WaterRippleField` and `WaterRippleEmitter` as `Node3D` custom types with `ripple_field.svg` and `ripple_emitter.svg` icons. `--check-only --script addons/waterways/plugin.gd` passes after importing the icons, and a repo-local headless editor-load check reaches editor layout ready. Human-visible Add Node menu inspection remains a Phase 9 follow-up.

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

- [ ] Phase 9: Add authoring controls and presets only after runtime behavior is accepted.
  - Validate: Users can configure ripples without editing shader code and without unstable internal plumbing exposed accidentally.
  - Current result: First Phase 9 slice is complete for add-on custom type registration. Deeper presets, nicer setup controls, and human-visible editor Add Node inspection remain open.

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
  - Current result: Public custom type registration is documented and implemented for `WaterRippleField` / `WaterRippleEmitter`; target registration, material ownership, and debug exposure remain the same proven runtime contracts.

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
