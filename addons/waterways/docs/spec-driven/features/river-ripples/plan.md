# Plan: River Ripples

## Spec Link

`spec.md`

## Architecture Summary

River ripples should be implemented as an optional runtime visual overlay:

- `WaterRippleField` owns transient simulation, impulse, and boundary textures.
- `WaterRippleEmitter` nodes or equivalent registered emitters create impulses.
- A Waterways-owned ripple simulation shader advances a damped height field.
- A no-readback ping-pong feedback path keeps normal runtime work on the GPU.
- One `world_to_ripple_uv` transform maps world positions into field UVs for emitters, debug views, simulation, and river shader sampling.
- A target-river mesh-footprint mask prevents waves from crossing banks, dry areas, rocks, or disconnected bends.
- A RiverManager-facing runtime API applies and clears only `i_ripple_*` uniforms on intended generated river targets.
- Debug views or probes expose raw ripple, impulse, boundary, and visible influence before acceptance.

The first accepted implementation must not touch river bakes, WaterSystem bakes, source signatures, final flow, `system_flow.gdshader`, or buoyancy.

## Current Truth

Keep this section short and update it whenever the plan changes.

- Implementation status: Standalone Phase 1 feedback spike, standalone Phase 2 mapping probe, standalone Phase 2 mesh-footprint boundary-mask probe, RiverManager-facing material ownership/restore API/probe, minimal river shader disabled/missing-texture neutral path, guarded river shader height/normal sampling helpers, minimal visible normal blending, revised demo-backed visible review scene, debug parity path, shader-cost probe, `WaterRippleField`/`WaterRippleEmitter` workflow, field/emitter dispatch-performance probe, post-clear-fix demo-backed field/emitter authoring scene/probe/diagnostic, named Add Node registration, and Phase 9 script/resource authoring are added; human-visible field/emitter visual/debug/control/stop-reload review and Phase 9 editor authoring review passed for the current Forward+ gate; Mobile and Compatibility renderer coverage passed by console/render probes.
- Open architectural decisions: Revised Phase 9 authoring/API planning is documented in `phase9-authoring-api-plan.md`; native editor polish is split into `phase10-editor-polish-plan.md`. Phase 9 script/resource implementation is console-proven and human-visible accepted through grouping, warnings, built-in starters, hidden reserved fields, in-memory apply/capture, Add Node visibility, and scratch save/reload; later production visual tuning is still unproven. First-spike decisions are locked. Emitter targeting uses explicit field path first, then ancestor/group fallback.
- Last validation that proves the plan still works: `--check-only --script` for `plugin.gd`, `water_ripple_field.gd`, and `water_ripple_emitter.gd`; repo-local headless editor scan plus global-class probe for `WaterRippleField` and `WaterRippleEmitter`; `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_SHADER_COST_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_FEEDBACK_ANALYSIS_OK`, static runtime-readback review, and forbidden-file diff on 2026-06-07.
- Next planned slice: Choose between Phase 10 native editor polish and a separate response/refraction/displacement tuning plan. Leave exported preset asset slots, live profile links, runtime preset saving, dedicated editor inspector buttons, undo-aware UI actions, editor-time previews, response tuning, refraction tuning, displacement tuning, final flow, WaterSystem, bakes, source signatures, and buoyancy out unless the next slice explicitly plans them.
- Branch safety before implementation: Satisfied on user-created branch `ripples`.
- Sections below that are historical or superseded: None yet.

## Premise Check

Before implementing, record whether the problem is definitely a code/design issue or could be expected behavior from scene setup, generated data, stale resources, Godot limitations, or validation interpretation.

- Evidence supporting the premise:
  - The roadmap identifies a real missing capability: localized runtime water-surface disturbance.
  - Waterways already has visual shader layers that can accept an additional runtime normal/detail contribution.
  - Current bakes intentionally represent authored river behavior, so runtime transient detail belongs outside saved bake resources.
- Evidence against treating this as flow or physics:
  - Existing roadmap explicitly rejects first-pass flow, WaterSystem, and buoyancy changes.
  - A ripple height texture alone does not define physically consistent object drift or eddy circulation.
  - Existing baked UV2 atlas fields are not world-space ripple masks.
- User-facing pushback or clarification needed before patching:
  - If asked for floating objects to respond to ripples, explain that this is not part of the first visual milestone and requires separate physics-facing planning.
  - If asked to blend ripples into visible rivers before the feedback, mapping, boundary, and material ownership spikes pass, explain which gate is missing.
- Smallest check that can falsify the premise:
  - Create a standalone no-readback ripple texture with one fixed impulse. If ping-pong feedback cannot run reliably in this Godot setup, river shader integration should not start.

## Layers

Editor authoring layer:

- Named Add Node registration for `WaterRippleField` and `WaterRippleEmitter`.
- Inspector controls for resolution, bounds/transform, strengths, damping, propagation, update rate, target rivers, and a hidden/reserved debug diagnostic flag.
- Phase 9 authoring contract in `phase9-authoring-api-plan.md` for inspector grouping, one-click presets, advanced settings, and in-memory preset capture/apply.
- Human-assisted scene review in demo scenes.

Bake/data layer:

- No first-pass bake data changes.
- No source-signature bump.
- No WaterSystem regeneration.
- Future physics-facing work must define generated resources, metadata, and stale-resource handling before touching this layer.

Runtime layer:

- `WaterRippleField` lifecycle, ping-pong render targets, impulse target, boundary mask, simulation scheduling, target registration, and material cleanup.
- `WaterRippleEmitter` configuration, field filtering, UV mapping, priority, and one-shot/continuous modes.
- River shader sampling of runtime ripple texture only when enabled and valid.

Validation layer:

- Static scans for forbidden readbacks and unintended bake/WaterSystem changes.
- Godot parser/headless checks when practical.
- Standalone ripple debug scene or probe.
- Human-assisted visible review for shader output and editor/runtime behavior.
- Performance checks for resolution, emitter count, idle cost, and shader samples.

Legacy reference layer:

- No legacy Godot 3 behavior is required.
- External ripple-shader reference is algorithmic inspiration only; do not copy code unless licensing is clarified.

## Godot Components

- Nodes:
  - Prototype `addons/waterways/water_ripple_field.gd`.
  - Prototype `addons/waterways/water_ripple_field.tscn`.
  - Prototype `addons/waterways/water_ripple_emitter.gd`.
  - Prototype `addons/waterways/water_ripple_emitter.tscn`.
- Resources:
- Runtime-created viewport textures or equivalent transient textures.
- Planned `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources for type-specific authoring values only; Phase 9 uses them through explicit in-memory apply/capture methods, not exported live slots or runtime asset saves.
- No saved bake resources in first pass.
- Shaders:
  - `addons/waterways/shaders/runtime/ripple_simulation.gdshader`.
  - `addons/waterways/shaders/runtime/ripple_impulse.gdshader`.
  - `addons/waterways/shaders/runtime/ripple_impulse_additive.gdshader`.
  - `addons/waterways/shaders/runtime/ripple_boundary_mask.gdshader`.
  - Internal `i_ripple_*` declarations, including neutral `i_ripple_impulse_texture` plumbing, guarded height/normal helpers, and minimal visible normal blending are now present in `addons/waterways/shaders/river.gdshader`; future work should keep response tuning behind human-visible review and performance checks.
  - Debug parity modes for raw height, impulse/contact, boundary mask, and visible influence are now present in `addons/waterways/shaders/river_debug.gdshader`.
- Editor tools:
  - Named script-class registration if nodes are public.
  - Optional icons if registered.
- Importers:
  - None expected for first pass.
- Autoloads:
  - None expected unless a later plan justifies global emitter discovery.
- Scenes:
  - Temporary standalone ripple prototype scene.
  - Revised demo-backed visible normal review scene at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`.
  - Demo-backed field/emitter authoring review scene at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`.
- Validation scenes:
  - Standalone ripple texture review at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_review.tscn`.
  - Automated feedback probes at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd` and `ripple_feedback_analysis_probe.gd`.
  - Standalone mapping review at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_review.tscn`.
  - Automated mapping probe at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd`.
  - Boundary-mask review at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_review.tscn`.
  - Automated boundary-mask probe at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd`.
  - Demo visible river overlay/debug parity review.
  - Automated debug parity probe at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd`.
  - Automated field/emitter lifecycle probe at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_probe.gd`.
  - Automated field/emitter dispatch-performance probe at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_performance_probe.gd`.
  - Automated demo-backed field/emitter authoring probe at `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review_probe.gd`.

## Data Model

Runtime field state:

- `resolution`: expected first defaults are 128, 256, or 512.
- `world_to_ripple_uv`: single production transform from world position to ripple field UV space.
- Simulation texture channels:
  - `r`: current height.
  - `g`: previous height or velocity-like memory.
  - `b`: impulse/contact memory or boundary diagnostic.
  - `a`: optional age, confidence, or unused.
- Impulse texture: cleared or accumulated according to the documented update model.
- Boundary mask: target river mesh footprint in ripple-field space.
- Target registry: explicit river targets and material state applied by this field.
- Restore state: enough information to clear or restore only the uniforms this field owns.

Save/load behavior:

- Field node configuration may be serialized if nodes are public.
- Future custom preset resources may serialize authoring values for fields and emitters through separate field/emitter resource types.
- Simulation, impulse, and runtime textures are transient.
- River bake data, WaterSystem data, and source signatures are not changed.

Roadmap detail carried into implementation:

- Field configuration should cover `enabled`, `resolution`, `world_transform` or `world_bounds`, target rivers, strengths, damping, propagation, update rate, emitter cap, and hidden/storage-only diagnostic reservations; visible debug helpers belong to Phase 10 once real behavior exists.
- `world_bounds` can be a convenience input only if it generates the same `world_to_ripple_uv` transform used by GDScript and shaders.
- `follow_camera` should stay hidden or unsupported until reprojection, clear-on-shift, or tile swapping is designed.
- Emitter configuration should cover radius, intensity, falloff, pulse rate, one-shot behavior, enabled state, priority, and optional target-field routing.
- River shader integration should use `i_ripple_enabled`, `i_ripple_simulation_texture`, `i_ripple_impulse_texture`, `i_ripple_world_to_uv`, `i_ripple_boundary_mask`, `i_ripple_texel_size`, `i_ripple_normal_strength`, `i_ripple_refraction_strength`, `i_ripple_displacement_strength`, `i_ripple_height_fade_distance`, and `i_ripple_boundary_fade` unless the plan is revised. The visible shader currently declares but does not sample the impulse/contact texture; it exists for runtime/debug plumbing.
- First visible integration adds ripple normals only; custom refraction still uses the pre-ripple normal, refraction tuning follows after normal stability, and displacement stays default off.
- Later authoring should use clear controls and restrained presets rather than exposing unstable runtime plumbing. Phase 9 should follow `phase9-authoring-api-plan.md`, treat presets/API hardening as authoring contract work rather than visual tuning, split field and emitter presets into separate resource types, keep preset apply/capture in memory, and keep `refraction_strength`, `displacement_strength`, and `debug_visible` reserved/hidden from normal authoring until a separate tuning or editor-polish plan accepts real behavior. Phase 10 should handle optional editor preset selectors, dedicated editor buttons, undo-aware editor actions, save dialogs, and editor-time preview helpers.

## Phase 9 Authoring Planning Direction

`phase9-authoring-api-plan.md` is the current contract for deeper public authoring/API changes. `phase10-editor-polish-plan.md` is the deferred native editor UI plan.

- Keep the scope to exported-property organization, public API hardening, and type-specific preset resources. Do not tune visible response, refraction, or displacement as part of this slice.
- Organize the public inspector surface around setup, targets, boundary masking, simulation, visual response, debug, and reserved/advanced controls using ordinary Godot export grouping first.
- Present `WaterRippleField` as the local simulation domain and target/boundary/debug owner.
- Present `WaterRippleEmitter` as an authorable disturbance source, with point/ring impulses now and deformer-like shapes planned later.
- Treat presets as one-click starting points that mutate ordinary editable values, not live profile modes that keep overriding user edits.
- Preserve access to advanced settings after a preset is applied, but keep reserved refraction/displacement out of normal preset capture until behavior is accepted.
- Plan separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources for reusable authoring values only, consumed by explicit apply/capture calls rather than exported live preset slots.
- Do not save transient runtime textures, target material state, generated river bakes, `WaterSystem` data, or source signatures as part of a preset.
- Keep dedicated editor inspector buttons, undo-aware actions, editor save dialogs, and editor-time preview helpers in Phase 10.

## Editor/Runtime Boundary

- Editor-only code:
  - Custom type registration, icons, debug menu integration, editor-only preview tooling, validation helpers, and future Phase 10 ripple inspector controls.
- Runtime-safe code:
  - Ripple field lifecycle, emitter gathering, viewport stepping, shader uniforms, material cleanup.
- Shared data/resources:
  - Runtime field configuration when saved in scenes.
  - River target references or paths when intentionally serialized.
- APIs exposed to user projects:
  - Add-on registration now exposes `WaterRippleField` and `WaterRippleEmitter` as editor custom types.
  - Current callable surface includes `WaterRippleField.register_target()`, `unregister_target()`, emitter configuration, and debug texture accessors; deeper stability promises remain Phase 9 API hardening.
- Assumptions that must not cross the boundary:
  - Editor debug material state must not be required for runtime behavior.
  - Hidden editor-only nodes must not be required for exported runtime scenes.
  - Runtime visual state must not dirty generated bake resources.

## Runtime Flow

1. `WaterRippleField` initializes ping-pong simulation targets, impulse target, and boundary mask.
2. Field validates resolution, transform, target rivers, compatible materials, and boundary mask availability.
3. Emitters register explicitly or are gathered from a filtered group.
4. Each update maps emitter world positions through `world_to_ripple_uv`.
5. Field rejects or fades impulses outside bounds or boundary mask.
6. Impulse pass renders circles or sprites into the impulse texture.
7. Simulation pass reads previous ripple texture, impulse texture, boundary mask, damping, propagation, and texel size.
8. Ping-pong targets swap after the write completes.
9. Field applies current ripple texture and transform uniforms to intended river targets.
10. River shader samples ripple height only when enabled and valid.
11. On disable, unregister, exit, or scene reload, field stops updates and clears or restores the runtime uniforms it owns.

## Bake Flow

1. No first-pass bake input changes.
2. No intermediate bake passes.
3. No output textures/resources.
4. No metadata written.
5. Preview and consumption are runtime-only.

If a later phase promotes ripples to physics or saved data, write a new bake/data plan before implementation.

## Lifecycle, Cleanup, and Re-entry

Success path:

- Field creates runtime targets, applies uniforms to intended river targets, runs simulation, exposes debug state, and restores material state on cleanup.

Preflight or early-return path:

- Invalid resolution, missing target, incompatible material, unsupported transform, or missing boundary mask should warn and leave river materials unchanged.

Awaited failure path:

- Viewport/rendering failure should stop the simulation and clear runtime uniforms rather than leaving stale textures assigned.

Temporary node/resource ownership:

- `WaterRippleField` owns viewports, textures, debug nodes, and temporary render helpers it creates.
- Target river materials remain owned by RiverManager or the target river unless the selected ownership path explicitly duplicates and restores them.

Progress, dirty-state, and user feedback:

- Runtime enable/disable should not dirty bakes.
- Editor warnings should be specific enough to fix the setup.
- Debug toggles should not change saved visible material state.

Duplicate or overlapping requests:

- Multiple fields can exist, but each must have explicit target ownership or filtering.
- If two fields target one river, the first implementation should reject or warn unless blending is deliberately designed.

Scene reload or runtime boundary:

- Scene reload must not leave stale ripple textures assigned.
- Exported/runtime scenes must not depend on editor-only preview nodes.

## Files to Change

- `addons/waterways/shaders/runtime/ripple_simulation.gdshader`: Waterways-owned runtime simulation shader is added.
- `addons/waterways/shaders/runtime/ripple_impulse.gdshader`: Standalone/probe runtime impulse shader is added and remains compatible with feedback analysis.
- `addons/waterways/shaders/runtime/ripple_impulse_additive.gdshader`: Runtime field additive multi-emitter impulse shader is added.
- `addons/waterways/shaders/runtime/ripple_boundary_mask.gdshader`: Runtime field boundary-mask footprint shader is added.
- `addons/waterways/water_ripple_field.gd`: Prototype runtime field node is added.
- `addons/waterways/water_ripple_field.tscn`: Prototype reusable field scene is added.
- `addons/waterways/water_ripple_emitter.gd`: Prototype emitter node is added.
- `addons/waterways/water_ripple_emitter.tscn`: Prototype reusable emitter scene is added.
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`: Demo-backed review scene with inspectable field and emitter nodes is added.
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.gd`: Review-scene controller for camera, markers, toggles, emitter movement, and validation hooks is added.
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review_probe.gd`: Console validation for demo authoring setup, emitter positions, disable baseline, and reload cleanup is added.
- `addons/waterways/docs/spec-driven/features/river-ripples/phase9-authoring-api-plan.md`: Phase 9 authoring/API plan is added and should guide deeper presets/API hardening.
- `addons/waterways/docs/spec-driven/features/river-ripples/phase10-editor-polish-plan.md`: Phase 10 native editor polish plan is added for inspector buttons, undo-aware editor actions, save dialogs, and editor preview helpers.
- `addons/waterways/river_manager.gd`: Runtime uniform application/clear API is added, including the internal impulse/contact texture key.
- `addons/waterways/shaders/river.gdshader`: Neutral `i_ripple_*` declarations, guarded height/normal helpers, X/Z `world_to_ripple_uv` sampling, and minimal visible ripple normal overlay are added.
- `addons/waterways/shaders/river_debug.gdshader`: Debug parity modes for raw height, impulse/contact, boundary mask, and visible influence are added.
- `addons/waterways/plugin.gd`: Register custom types and icons if nodes are public.
- `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`: Demo-backed visible normal review scene for the current river shader slice.
- `addons/waterways/docs/spec-driven/features/river-ripples/*`: Keep this folder current after each decision and validation run.

## Documentation Plan

- Code comments needed:
  - Godot viewport feedback ownership.
  - World-to-ripple transform math.
  - Boundary mask generation.
  - Material ownership and restore behavior.
  - Shader sample budget and disabled-path guards.
- Feature docs to update:
  - This folder after every decision, spike result, implementation slice, and validation run.
  - `phase9-authoring-api-plan.md` when authoring/API decisions change before implementation.
- Architecture or data-flow docs to update:
  - Roadmaps and architecture docs only after an implementation direction is accepted.
- Validation docs to update:
  - `validation.md` current snapshot, matrix, recorded results, visual review steps, and performance measurements.
- Research citations index:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited list for river behavior, flow-map, shader-water, and production-reference sources. Consult it before research-driven changes and update it when adding new sources.
- Migration notes to update:
  - Changelog and shared handoff only after implementation or public API changes.

## Validation Strategy

- Automated:
  - Static scan for forbidden runtime `get_image()` use in ripple simulation.
  - Standalone ownership probe `RIPPLE_FEEDBACK_PROBE_OK`.
  - Standalone analysis probe `RIPPLE_FEEDBACK_ANALYSIS_OK` at 128, 256, and 512; this may use validation-only readback and saved scratch captures.
  - Standalone mapping probe `RIPPLE_MAPPING_PROBE_OK`; this uses validation-only readback to confirm shader-rendered texture markers land at GDScript-predicted UVs.
  - Standalone boundary-mask probe `RIPPLE_BOUNDARY_MASK_PROBE_OK`; this uses validation-only readback to confirm mesh-footprint coverage and boundary-fed feedback behavior.
  - River shader neutral-path probe `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`; this uses validation-only readback to compare disabled and missing-texture river renders against baseline.
  - River shader sampling-budget probe `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`; this statically confirms the visible normal slice calls the helper once from `fragment()`, keeps the normal helper at three simulation texture samples, and keeps direct height sampling out of `fragment()`.
  - River shader visible-normal probe `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`; this uses validation-only readback to prove disabled, flat, and black-boundary cases stay neutral while an enabled wave texture visibly changes the rendered river material normal response.
  - Demo-backed visible review scene smoke probe `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`; this proves `ripple_river_shader_visible_normal_review.tscn` loads `Demo.tscn`, starts on the close-overhead camera, applies runtime ripple material state, preserves demo `flow_speed`, precomputes review texture frames, advances the animated review texture without playback-time image generation, toggles it off/on, and restores on free.
  - Demo-backed visible review diagnostic probe `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`; this uses validation-only captures to prove active material state, clustered center projection, mesh tangent availability, ripple texture slope, preserved demo flow speed, precomputed frame reuse, and enabled-vs-zero-strength visible delta in the revised view.
  - Debug parity probe `RIPPLE_DEBUG_PARITY_PROBE_OK`; this proves `river_debug.gdshader`, the debug view menu, RiverManager runtime texture application, visible/debug material switching, and review-scene debug controls expose raw height, impulse/contact, boundary mask, and visible influence without losing runtime ripple state.
  - Shader-cost probe `RIPPLE_SHADER_COST_PROBE_OK`; this uses static shader sample counts plus `RenderingServer` per-viewport CPU/GPU timing to prove disabled live textures stay near baseline, enabled visible normals stay within the first-pass budget, and debug modes are recorded as inspection-tool costs.
  - Field/emitter lifecycle probe `RIPPLE_FIELD_EMITTER_PROBE_OK`; this proves prototype scene/script loading, field initialization, boundary generation, material ownership, world impulse mapping, emitter caps/priority, out-of-bounds rejection, no readback, disable cleanup, and free cleanup.
  - Field/emitter dispatch-performance probe `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`; this measures 128/256/512 field dispatch with 0/4/16 emitters through the reusable nodes.
  - Demo-backed field/emitter review probe `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`; this proves the authoring scene loads `Demo.tscn`, exposes real field/emitter nodes, targets the demo river, generates a mesh-footprint boundary mask, maps emitters to expected water positions, renders localized emitter impulses on a black background, preserves base flow speed, restores baseline material on disable, and reloads without stale runtime state.
  - Demo-backed field/emitter diagnostic `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`; this reproduced the no-visible-ripples debug symptoms, caught nonzero offscreen clear color in the impulse texture, and now proves transparent-zero canvas viewport clearing restores localized blue/green/orange impulse stamps.
  - Parser/headless checks for new scripts and shaders when Godot tooling is available.
  - Probe for target material uniform application and clear behavior.
- Validation matrix location:
  - `validation.md` "Validation Matrix".
- Human-assisted:
  - Required for visible ripple behavior, editor workflow, shader output, and demo acceptance.
- Visual:
  - Standalone ripple texture, impulse texture, boundary mask, visible river overlay, and existing pillow/wake/eddy-line comparison.
- Shader:
  - Confirm disabled path has no avoidable ripple sampling and enabled normal path stays within budget.
- Editor:
  - Confirm custom type registration and inspector behavior if public.
- Runtime:
  - Confirm scene reload, pause/resume, multiple fields, and missing targets.
- Performance:
  - Current shader-cost gate is measured: disabled-ready and visible-fragment direct ripple samples `0`, enabled normal helper `3` simulation samples plus `1` boundary helper call, one draw call, and 640x360 median GPU `0.319 ms` enabled versus `0.315 ms` disabled on Godot 4.6.3 Forward+ / AMD Radeon RX 6800 XT.
  - Current field/emitter dispatch gate is measured: 128/256/512 resolutions with 0/4/16 emitters passed on Godot 4.6.3 Forward+ / AMD Radeon RX 6800 XT. Dispatch medians were `5.933/5.738/5.755 ms`, `5.981/5.518/5.799 ms`, and `5.511/6.202/5.866 ms` respectively.
  - Future performance review should rerun Forward+/Mobile/Compatibility checks after renderer-sensitive changes or exported/runtime workflow changes.
- Manual:
  - Confirm docs do not imply physics-facing behavior.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Feedback path samples from the texture being written | Undefined or platform-specific rendering behavior | Prove ping-pong ownership before river integration. |
| CPU readback slips into normal runtime loop | Frame-time stalls and architecture violation | Static scan and code review for viewport/image readback calls. |
| Mapping differs between emitters and shader | Ripples appear in wrong world locations | Use one `world_to_ripple_uv` contract and probe fixed markers. |
| Boundary mask is rectangular or atlas-based | Waves cross banks, rocks, or disconnected bends | Require target river mesh-footprint mask before visible integration. |
| Runtime uniforms mutate shared materials | Cross-talk between rivers and stale scene state | Use RiverManager-facing API or explicit duplication/restore path. |
| Debug material switching hides ripple state | Review cannot trust visible/debug comparison | Covered for the current gate by `RIPPLE_DEBUG_PARITY_PROBE_OK` and human-visible debug-view review; keep this in the performance/regression sweep if debug plumbing changes. |
| Shader sampling cost is too high | Regresses already heavy river material | Current shader-cost gate is covered by `RIPPLE_SHADER_COST_PROBE_OK`; preserve the disabled-path guard, three-sample normal helper budget, and one-draw-call profile in future shader edits. |
| Users infer physics from visuals | Buoyancy and visible rings appear inconsistent | Keep docs, UI, and validation explicit that first pass is visual-only. |
| Presets hide or override editable values | Users cannot understand or safely customize the result | Phase 9 presets must mutate visible exported values, must not act as live profile modes, and must not be stored as exported preset asset slots on field/emitter nodes. |
| Editor polish becomes accidental runtime dependency | Exported projects break or runtime behavior requires editor-only nodes/classes | Keep Phase 9 script/resource-first; isolate buttons, save dialogs, undo, and preview helpers in Phase 10 editor tooling. |

## Adversarial Plan Review

Complete this with the user after the plan is drafted and before implementation starts.

- Most likely way this plan could damage working behavior:
  - Accidentally touching baked flow, saved WaterSystem data, shared river materials, or accepted pillow/wake/eddy-line shader paths while adding a visual overlay.
- Project state, generated resource, scene, or workflow most at risk:
  - Generated river mesh material state, saved river bakes, saved WaterSystem bake, demo scene material/debug state, and runtime target registration.
- Files or data that are riskier than they look:
  - `river.gdshader`, because it is already visually dense and performance-sensitive.
  - `river_debug.gdshader`, because debug parity can silently diverge.
  - `river_manager.gd`, because material ownership and restore behavior affect many river workflows.
  - `filter_renderer.gd`, because its bake-oriented readback pattern must not be copied into runtime.
- Simpler or safer approach considered:
  - Start with a standalone debug texture and one fixed impulse before touching visible river materials.
- Validation that will catch the riskiest failure early:
  - No-readback ping-pong probe, fixed world marker mapping probe, boundary mask debug view, two-river material cross-talk probe, and disabled-path visual comparison.
- Branch safety reminder sent before code changes:
  - Satisfied before implementation on user-created branch `ripples`.

## Migration and Compatibility

- Active target is Godot 4.6+.
- No legacy Godot 3 APIs should be introduced.
- First-pass visual ripples are optional and should fail neutral when disabled or missing textures.
- No resource migration is expected for visual-only implementation.
- Public API compatibility now matters for the registered field/emitter custom types; keep follow-up API hardening conservative and documented.
- Future physics-facing work must include save/load, bake invalidation, WaterSystem, and runtime sampling compatibility planning.
