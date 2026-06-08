# Phase 9 Authoring/API Plan: River Ripples

## Date

2026-06-08

## Purpose

This plan turns the validated `WaterRippleField` and `WaterRippleEmitter` spike into a stable public authoring contract before deeper editor tooling is added.

The goal is practical authoring, scriptable reuse, and reusable preset design data. Phase 9 should make the existing visual-only ripple workflow easier to set up, inspect, reuse, and call from scripts without changing river bakes, final flow, `WaterSystem`, source signatures, buoyancy, production response/refraction/displacement tuning, foam, or runtime asset persistence.

Phase 9 is not the native-feeling editor polish milestone. Dedicated inspector buttons, undo-integrated editor actions, editor-time boundary previews, and richer debug overlays are valuable, but they require explicit Godot editor-plugin work. That work is split into Phase 10.

## Current Scope

In scope:

- Public authoring shape for `WaterRippleField` and `WaterRippleEmitter`.
- Godot-native exported-property organization for setup, targets, boundary masking, simulation, visual response, debug, and advanced/reserved controls.
- Script-callable preset application that mutates ordinary editable values.
- Built-in field and emitter preset definitions that use only currently supported behavior.
- Separate saveable resources for reusable field settings and emitter settings.
- Script methods that accept or return preset resources, without exported preset asset slots on field/emitter nodes.
- API naming and boundaries that keep runtime internals from becoming accidental public contract.
- Validation gates for Add Node visibility, parser/headless checks, scene save/reload, preset application, renderer coverage where relevant, and no saved bake/resource/source-signature churn.

Out of scope:

- A dedicated ripple `EditorInspectorPlugin`, plugin panel, editor toolbar, icons beyond existing node icons, or undo-integrated editor buttons. See `phase10-editor-polish-plan.md`.
- Exported preset asset slots on `WaterRippleField` or `WaterRippleEmitter`. Phase 9 preset resources are value inputs/outputs for methods, not live node profiles.
- Runtime saving of preset resources to disk. Runtime scripts may apply presets and capture in-memory preset resources, but asset save/update flows move to Phase 10 editor tooling or a later explicit non-runtime save workflow.
- Editor-time simulation or emitter playback while `Engine.is_editor_hint()` is true.
- Editor preview of generated boundary masks through live runtime `SubViewport` textures.
- Replacing the current `SubViewport` feedback implementation with compute shaders.
- Flow-aware ripple advection.
- Physics-facing ripple sampling.
- Buoyancy, object drift, reverse flow, or eddy circulation.
- River bake, `WaterSystem`, or source-signature changes.
- Refraction or displacement tuning. Current ripple refraction/displacement uniforms are reserved and should not be presented as working production controls.
- Production foam simulation. Foam is planned as a later separate influence layer.

## Research Synthesis

The useful industry pattern is layered water, not one universal solver.

- Base water motion, authored flow, runtime ripples, localized deformers, decals/masks, foam settings/input layers, and debug views are usually separate systems.
- Bounded GPU heightfields remain a common fit for local interaction ripples. This matches the current Waterways field/emitter architecture.
- Unity HDRP exposes water masks, deformers, decals, foam settings, bounded deformation regions, caps, and debug views as authoring concepts. Waterways should borrow the vocabulary of localized influences, not the whole HDRP renderer.
- Unity presets are editor-facing value-copy assets: applying a preset copies property settings and does not create a live link. Waterways should follow that mental model for editor authoring.
- Unreal separates water bodies, Water Waves Assets, debug/scalability controls, and heavier fluid simulations. Waterways should preserve that separation between visual ripple overlays, reusable authoring resources, and future physics-facing systems.
- Crest treats dynamic waves as a layer on top of animated water, uses proxy interaction shapes such as spheres, exposes damping/stability controls, and treats foam as a distinct simulation/input layer.
- AAA river, surf, and rapid examples such as Uncharted 4 and Horizon Forbidden West often bake or procedurally compose complex water from authored data. That supports deferring waterfalls, rapids, breaking waves, and production whitewater from this runtime ripple slice.
- Godot supports exported property groups/subgroups for ordinary inspector organization. It also supports simple `@export_tool_button` buttons, but those are not enough for the undo-aware, save-dialog, preview, and lifecycle behavior expected here; native-feeling ripple actions should use `EditorInspectorPlugin` or other `EditorPlugin` work in Phase 10.
- Godot has an official compute texture demo and `Texture2DRD` path for future GPU-native implementations, but the current `SubViewport` path is already validated across Forward+, Mobile, and Compatibility. Compute should stay a future architecture option.

Primary source details are recorded in `addons/waterways/docs/research/river-research-citations.md`.

## Adopt, Adapt, Reject

| Pattern | Source Family | Waterways Decision |
| --- | --- | --- |
| Bounded heightfield ripple simulation | Tatarchuk rain, Crest dynamic waves, Godot compute texture demo | Adopt. Current `WaterRippleField` remains the first runtime layer. |
| Proxy emitters for larger or non-spherical bodies | Crest sphere interactions, Unreal fluid collision concepts | Adapt later. Phase 9 presets use the current point/ring emitter only; later capsule/trail/stamp shapes need their own implementation plan. |
| Deformer/decal authoring vocabulary | Unity HDRP water deformers, masks, decals | Adapt cautiously. Use "localized disturbance" and point/ring wording now; keep disc, trail, capsule, texture stamp, bow wake, and decal-like language in future vocabulary. |
| Foam as separate simulation/input/shading data | Unity HDRP foam, Crest foam | Adopt later. Do not fake Phase 9 foam by overloading ripple color or normal strength. |
| Runtime compute texture pipeline | Godot `Texture2DRD`, compute texture demo | Defer. Revisit only after the authoring contract is stable. |
| Dedicated editor inspector/buttons/debug panel | Unity/Unreal water authoring tools, Godot `EditorInspectorPlugin` | Move to Phase 10. Useful, but not required for the first stable API/preset slice. |
| Whole-river shallow-water/FLIP physics | Unreal Niagara Fluids, open-world water talks | Reject for this phase. Future milestone only. |
| Offline/baked wavefront and rapid data | Horizon Forbidden West, Uncharted 4 | Defer. Useful for future rapids/waterfalls, not local runtime ripples. |
| Type-specific preset/data assets | Unity presets, Unreal Water Waves Assets, Crest simulation settings assets | Adopt. Use separate field and emitter preset resources instead of one mixed resource with a `kind` switch. |

## Public Mental Model

Phase 9 should present four concepts:

- `WaterRippleField`: the local simulation domain, target ownership, boundary mask, performance, visual response, and minimal debug toggle.
- `WaterRippleEmitter`: an authorable source of current point/ring impulses into a field.
- `WaterRippleFieldPreset`: a saveable field design resource for simulation, visual response, boundary fade, and performance values only.
- `WaterRippleEmitterPreset`: a saveable emitter design resource for current emitter mode, radius, intensity, falloff, pulse/moving cadence, and priority only.

This should be the wording used in docs and UI:

- Ripples are a visual surface-detail layer.
- Emitters create local disturbances.
- Presets are starting points.
- Applying a preset copies values into ordinary editable properties.
- Preset resources are consumed by explicit methods or editor actions. They are not stored as exported live profile slots on ripple nodes in Phase 9.
- Runtime textures are transient and are not saved into river resources or preset resources.
- Editor buttons and native preview helpers are planned for Phase 10.

Avoid wording that implies:

- Ripples alter final river flow.
- Ripples affect buoyancy.
- Presets are simulation modes, default profiles, or asset links that continuously override user edits.
- Refraction or displacement are production-ready.
- Foam, wake trails, bow wakes, capsule bodies, texture stamps, or dense rain systems exist in the current implementation.

## Field Inspector Contract

Recommended grouping for `WaterRippleField` should use ordinary Godot export grouping first. Do not require custom inspector labels in Phase 9.

### Setup

- `enabled`
- `resolution`
- `world_bounds`
- `simulation_update_rate`

No setup action buttons are required in Phase 9. `Rebuild Runtime`, `Reset Feedback`, `Apply Field Preset`, `Capture Field Preset`, and boundary preview buttons move to Phase 10 editor tooling unless implemented as script-callable methods without custom UI.

### Targets

- `target_river_paths`
- `target_group_name`
- `field_group_name`

Phase 9 should improve configuration warnings for no target, invalid target, duplicate ownership, or missing compatible shader where this can be detected without running editor preview simulation. Duplicate ownership detection may still depend on runtime material ownership state, so it should be documented as a warning/probe target, not assumed solved by grouping.

### Boundary Mask

- `auto_generate_boundary_mask`
- `require_boundary_mask`
- `boundary_source_paths`
- `boundary_mask_texture`
- `boundary_fade`

Boundary preview is not a Phase 9 promise. The current runtime boundary generation uses runtime `SubViewport` state, and editor-time preview requires Phase 10 editor-safe preview design.

### Simulation

Use stable property names:

- `damping`
- `propagation`
- `max_emitters`

Documentation and tooltips can explain `damping` as decay and `propagation` as spread speed, but Phase 9 should not require display aliases such as `Decay` or `Spread Speed` unless a custom property list or inspector plugin is accepted.

### Visual Response

- `ripple_strength`
- `normal_strength`
- `height_fade_distance`

Keep these visible because they are part of the accepted normal-only first path.

### Debug

- Hidden stored `debug_visible` reservation, if compatibility requires keeping the property.

`debug_visible` should be hidden in Phase 9 rather than renamed or exposed as an inert inspector promise. If the saved property must remain for compatibility, store it without normal inspector visibility, such as with `@export_storage`. Real bounds, routing, mask, texture, or influence visualization moves to Phase 10.

### Advanced / Reserved

- `refraction_strength`
- `displacement_strength`
- Runtime texture accessors and viewport RID diagnostics.

`refraction_strength` and `displacement_strength` are reserved fields in the current implementation. They should be hidden from normal authoring, preferably as stored/non-inspector values if compatibility requires keeping them, excluded from built-in presets, excluded from default capture, and described as currently having no accepted production effect until a separate visual tuning plan implements and validates them.

## Emitter Inspector Contract

Recommended grouping for `WaterRippleEmitter`:

### Routing

- `enabled`
- `target_field_path`
- `field_group_name`

### Shape

Current Phase 9 shape values:

- `radius`
- `falloff`

Future vocabulary such as disc, trail, capsule, texture stamp, and bow wake should stay in future documentation until matching implementation exists.

### Emission

- `emitter_mode`
- `intensity`
- `emit_on_ready`
- `pulse_rate`
- `moving_emit_distance`

### Priority And Caps

- `priority`

The field still owns final caps and sorting.

### Debug

- `emit_once()`
- `get_emitter_snapshot()`

`emit_once()` is runtime-callable and should continue returning `false` while editor-time emission is disabled. Phase 9 may stabilize the existing snapshot API rather than inventing a parallel `get_last_emission_status()` API unless a replacement is documented.

## Preset Contract

Presets must be value starters, not live profiles.

- Applying a preset writes ordinary exported values onto the selected field or emitter.
- The user can immediately inspect and edit every changed value.
- Applying a preset does not store a live profile reference that keeps overriding edits.
- Phase 9 field/emitter nodes should not expose `field_preset`, `emitter_preset`, or similar exported preset asset slots. Such slots make Godot scenes load the resource as a dependency and imply an ongoing profile relationship. If a future slot is accepted, it must be explicitly documented as an input to an action and must never auto-apply except through a deliberate editor or script call.
- Applying a preset does not change river targets, generated bakes, `WaterSystem`, source signatures, or runtime material ownership.
- Applying a preset does not save runtime textures.
- Applying a preset may rebuild transient runtime textures if the game is running and values such as `resolution`, `world_bounds`, `max_emitters`, `auto_generate_boundary_mask`, `require_boundary_mask`, or boundary-fade policy change. Runtime application should batch property mutations, rebuild boundary/runtime state once, and reapply material state once when practical.
- Applying a preset through Phase 10 editor UI should be undoable. Phase 9 script-callable methods do not themselves guarantee editor undo integration.

### Editor And Runtime Split

- Built-in presets are available as static data or helper methods for script tests and runtime use.
- Editor application copies values and should eventually use undo through Phase 10 editor tooling.
- Runtime application is allowed for gameplay scripts that want to swap ripple behavior, but it must never write back to preset assets automatically.
- Runtime capture is allowed only as an in-memory value object for scripts, tests, or diagnostics.
- Runtime saving of preset resources to disk is out of scope for Phase 9.
- Save/capture from the editor creates or updates explicit resource assets only through Phase 10 editor tooling or a later deliberate save workflow with an explicit path.
- `capture_*_preset()` returns an in-memory resource. It does not save an asset, assign an exported preset slot, or mutate the source preset.

### Field Presets

Initial field presets must only use currently supported field values:

- `Calm Local Field`: modest resolution, higher damping/decay, gentle normal response.
- `Character Interaction Field`: medium resolution, readable normal strength, moderate damping/spread.
- `Rain-Sized Local Field`: medium resolution, lower individual strength expectation, higher emitter cap; this is a field setup only, not a full rain system.
- `Heavy Impact Field`: medium/high resolution, longer decay, stronger normal response.
- `Performance Field`: lower resolution, lower cap, faster decay.
- `Debug Strong Field`: exaggerated but safe values for authoring review scenes.

### Emitter Presets

Initial emitter presets must only use current point/ring emitter behavior:

- `Footstep`: small radius, one-shot or pulse usage.
- `Wading Character`: medium radius, continuous or moving mode, moderate intensity.
- `NPC Ambient`: lower intensity and lower priority than player emitters.
- `Small Impact`: one-shot ring, medium intensity.
- `Heavy Impact`: larger radius, high intensity, high priority.
- `Light Rain Drop`: small radius, low intensity, pulse usage for a single emitter.
- `Static River Disturbance`: low continuous/pulse source for rocks, drains, or environmental churn.

Do not include `Boat/Oar Wake`, dense `Heavy Rain`, capsule/trail/stamp, or bow-wake presets until the corresponding emitter shape/helper behavior exists.

## Saveable Custom Designs

Use separate resources:

- `WaterRippleFieldPreset`
- `WaterRippleEmitterPreset`

A shared base resource or helper is acceptable internally, but the user-facing assets should be type-specific to avoid applying field-only values to emitters or emitter-only values to fields.

The field resource should store authoring values only:

- Simulation values: resolution, update rate, damping, propagation, max emitters.
- Visual values: ripple strength, normal strength, height fade, boundary fade.
- Boundary policy values only when intentionally included: `auto_generate_boundary_mask`, `require_boundary_mask`.
- Reserved values are excluded by default: refraction/displacement.

The emitter resource should store authoring values only:

- Current emitter values: mode, radius, intensity, falloff, pulse rate, moving emit distance, priority, emit-on-ready policy.
- Future shape values only after those shapes exist.

The resources should not store:

- Runtime `SubViewport` textures.
- Runtime RID values.
- River target paths by default.
- Field group or target group names by default unless a future team workflow explicitly accepts that coupling.
- Generated boundary masks unless a future plan explicitly defines authored mask assets.
- River bakes, `WaterSystem` bakes, source signatures, or material state.
- A back-reference to the field/emitter that captured them.
- A live-link flag or auto-apply setting.

Recommended workflow:

1. Add or select a field/emitter.
2. Apply a built-in field or emitter preset.
3. Tune visible exported values.
4. Capture current values into the matching in-memory preset resource.
5. Save the resource only through Phase 10 editor tooling or a later explicit save path, not as part of runtime apply/capture.
6. Reuse that resource on other matching fields/emitters.
7. Scene reload should preserve exported field/emitter values and any explicitly saved preset resource assets, while runtime textures rebuild cleanly. Ripple nodes should not preserve a preset reference by default because applying a preset is a copy operation.

## API Hardening Direction

Keep stable public methods small and intention-revealing:

- `WaterRippleField.register_target(river: Node) -> bool`
- `WaterRippleField.unregister_target(river: Node) -> void`
- `WaterRippleField.queue_impulse_world(world_position: Vector3, radius_world: float, intensity: float, falloff: float = 2.0, priority: int = 0, source: Object = null) -> bool`
- `WaterRippleField.queue_impulse(uv: Vector2, radius_uv: float, intensity: float, falloff: float = 2.0, priority: int = 0, source: Object = null) -> bool`
- `WaterRippleField.step_once() -> bool`
- `WaterRippleField.reset_feedback() -> void`
- `WaterRippleEmitter.emit_once() -> bool`

Potential Phase 9 additions:

- `WaterRippleField.apply_preset(preset: WaterRippleFieldPreset) -> bool`
- `WaterRippleField.capture_preset() -> WaterRippleFieldPreset`
- `WaterRippleEmitter.apply_preset(preset: WaterRippleEmitterPreset) -> bool`
- `WaterRippleEmitter.capture_preset() -> WaterRippleEmitterPreset`
- Stabilize `get_field_snapshot() -> Dictionary` for diagnostics, or explicitly replace it.
- Stabilize `get_emitter_snapshot() -> Dictionary` for diagnostics, or explicitly replace it.

Avoid adding a generic `apply_preset(preset: WaterRipplePreset)` unless a strong reason appears. Type-specific signatures are clearer, safer, and easier to validate.

Treat these as advanced/internal unless stabilized:

- Raw viewport RID access.
- Runtime texture internals.
- Direct material-state dictionaries.
- Validation-only diagnostic snapshots.
- Editor-only save dialogs and undo-aware actions.

Return values should stay boring and script-friendly:

- `bool` for accepted/rejected actions.
- Typed preset resources for capture helpers.
- `Dictionary` snapshots for debug/validation.
- Specific configuration warnings in `_get_configuration_warnings()`.

## Validation Gates

Before implementing Phase 9 presets/API changes:

- Review this revised plan with the user.
- Confirm no new branch is required unless implementation should be isolated.

After implementation:

- Parser/headless checks for changed scripts/resources.
- Editor Add Node visibility still shows `WaterRippleField` and `WaterRippleEmitter`.
- Export grouping appears without requiring a custom inspector.
- Preset application changes exported values and leaves targets/material ownership intact.
- Preset application does not touch generated river bake resources, `WaterSystem` resources, source signatures, buoyancy files, or saved material ownership.
- Runtime preset application, if supported, batches runtime rebuilds where practical and leaves no stale material state.
- Runtime preset capture returns an in-memory resource and does not write `.tres`, assign node preset slots, mutate source preset assets, or mark editor scenes/resources dirty by itself.
- Custom field/emitter preset resource save/load survives editor restart or headless reload.
- `field_group_name` and emitter `field_group_name` edits update group membership/cache state or have explicit warnings/tests documenting when reload is required.
- Scene save/reload rebuilds runtime textures without stale material state.
- Existing Forward+, Mobile, and Compatibility probes still pass where renderer-sensitive code changed.
- Human-visible review confirms the authoring workflow is understandable without editing shader code.

## Implementation Slices

Recommended order:

1. Documentation and warnings only: update docs, warnings, grouping plan, hide the `debug_visible` reservation, and keep reserved refraction/displacement out of normal authoring without changing runtime behavior.
2. Export grouping/tooltips: organize existing exported values with stable property names and no custom inspector.
3. Built-in preset data: field and emitter preset dictionaries/resources that can be tested without editor UI.
4. Type-specific apply/capture methods: mutate exported values on field/emitter, batch runtime rebuild/reapply work, return in-memory captures, and prove no saved bake/resource/source-signature churn.
5. Type-specific saveable resources: `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` with explicit exported authoring fields.
6. Human-visible authoring scene update and renderer regression sweep.
7. Phase 10 handoff: dedicated inspector buttons, undo/save helpers, and editor preview helpers.

## Deferred To Phase 10

- Native inspector buttons for apply/capture/reset/preview.
- Undo-aware editor actions for preset application.
- Editor save dialogs for captured preset resources.
- Editor-time boundary mask preview.
- Editor/runtime debug overlay, including any visible `debug_visible` field-bounds/helper display.
- Re-exposing or renaming `debug_visible` as real helper visualization.
- Toolbar or dock UI for ripple authoring.

## Decision Log

- 2026-06-08: Keep Phase 9 inside the existing `river-ripples` feature folder.
- 2026-06-08: Keep the validated `SubViewport` ripple field as the first implementation architecture; compute/`Texture2DRD` remains a future option.
- 2026-06-08: Split the authoring model into field, emitter, type-specific preset resources, and future foam/influence layers.
- 2026-06-08: Define presets as one-click value starters, not hidden live profile modes.
- 2026-06-08: Allow runtime preset application for scripts, but never automatic runtime writeback to preset assets.
- 2026-06-08: Keep preset resources off field/emitter nodes as exported live slots in Phase 9; use explicit apply/capture methods instead.
- 2026-06-08: Treat runtime preset capture as in-memory only and leave runtime asset saving out of Phase 9.
- 2026-06-08: Use separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources instead of one mixed `WaterRipplePreset` with a kind switch.
- 2026-06-08: Keep refraction and displacement reserved/hidden from normal authoring until a separate visual tuning plan accepts them.
- 2026-06-08: Hide the `debug_visible` reservation in Phase 9; real or renamed debug helper visualization moves to Phase 10.
- 2026-06-08: Defer dedicated editor inspector buttons, undo-aware editor actions, and editor-time preview helpers to Phase 10.
- 2026-06-08: Defer foam, flow-aware ripples, moving fields, physics sampling, and baked rapid/wavefront systems.
