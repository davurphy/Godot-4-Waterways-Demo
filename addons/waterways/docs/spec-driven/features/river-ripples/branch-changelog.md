# Branch Changelog: River Ripples

Branch: `ripples`

This changelog summarizes the river-ripple work captured in `handoff-latest.md`, `tasks.md`, `validation.md`, `review.md`, `phase9-authoring-api-plan.md`, and `phase10-editor-polish-plan.md`.

## Summary

River Ripples adds a visual-only runtime surface disturbance layer to Waterways. The feature creates localized decaying rings from authorable fields and emitters while preserving the existing river architecture: baked flow, `WaterSystem` maps, source signatures, final flow, and buoyancy stay unchanged.

The work landed in three broad layers:

- Runtime ripple simulation and river-shader integration.
- Script/resource authoring through field, emitter, and preset APIs.
- Editor-only polish through inspector controls, transient preset actions, gizmos, handles, and boundary previews.

## Runtime Ripple Architecture

- Added `WaterRippleField` as the bounded runtime simulation domain.
  - Owns ping-pong ripple simulation targets.
  - Owns impulse and boundary-mask targets.
  - Applies owner-scoped `i_ripple_*` material state to intended river targets.
  - Clears or restores material state on disable, rebuild, free, owner exit, and river exit.
- Added `WaterRippleEmitter` as the authorable disturbance source.
  - Supports pulse, continuous, one-shot, and moving modes.
  - Resolves fields by explicit path first, then ancestor or group fallback.
  - Queues impulses through the field's world-space API.
  - Respects field caps, priority sorting, bounds checks, and boundary rejection.
- Locked the first mapping model to a single `world_to_ripple_uv` transform.
  - The same mapping is used by emitters, simulation, boundary masks, debug views, and river shader sampling.
  - The first accepted field shape is axis-aligned X/Z `world_bounds`; transformed and camera-following fields remain future work.
- Added target river mesh-footprint boundary masking.
  - Boundary masks are generated in ripple-field space from configured target/boundary mesh sources.
  - Dry-corner impulses, dry gaps, and obvious cross-bank propagation are rejected by the accepted probes.
- Kept runtime ripple textures transient.
  - No normal-runtime CPU readback is used.
  - No river bake resources, WaterSystem resources, source signatures, saved material resources, or buoyancy scripts are changed.

## River Shader And Debug Integration

- Added neutral `i_ripple_*` uniforms to `river.gdshader`.
- Added guarded ripple height and normal sampling helpers.
- Added minimal visible normal blending.
  - Disabled, flat, black-boundary, missing-simulation-texture, and missing-boundary-texture cases remain neutral.
  - The accepted first path changes normal response only.
  - Custom refraction and displacement remain untuned/reserved.
- Added ripple debug parity.
  - Raw ripple height.
  - Impulse/contact.
  - Boundary mask.
  - Visible ripple influence.
- Added Debug View menu entries under the ripple group.
- Added demo-backed visible review behavior that preserves base river flow while ripple rings animate outward.

## Material Ownership And Cleanup

- Added RiverManager-facing runtime ripple material APIs.
  - Runtime fields apply only planned `i_ripple_*` keys.
  - Target materials are duplicated for runtime state.
  - Shared source materials remain unchanged.
  - Wrong-owner apply/clear operations are rejected.
  - Clearing one field does not remove another field's active ripple state.
- Added cleanup coverage for disable/re-enable, owner exit, river tree exit, scene reload, plugin lifecycle, stop/run-again behavior, and target material restore.

## Authoring And Public API

- Promoted `WaterRippleField` and `WaterRippleEmitter` to named Add Node script classes with ripple icons.
- Added ordinary Godot export grouping for fields and emitters.
  - Field groups cover setup, targets, boundary mask, simulation, and visual response.
  - Emitter groups cover routing, shape, emission, and priority/caps.
- Added configuration warning cleanup for common invalid setup states.
- Added storage-only reserved values.
  - `debug_visible` stays hidden until real helper behavior is planned.
  - `refraction_strength` and `displacement_strength` stay hidden until visual tuning is accepted.
- Added separate preset resource types:
  - `WaterRippleFieldPreset`
  - `WaterRippleEmitterPreset`
- Added preset APIs:
  - `WaterRippleField.apply_preset()`
  - `WaterRippleField.capture_preset()`
  - `WaterRippleField.apply_builtin_preset()`
  - `WaterRippleEmitter.apply_preset()`
  - `WaterRippleEmitter.capture_preset()`
  - `WaterRippleEmitter.apply_builtin_preset()`
- Added built-in value-starter presets.
  - Field presets include calm local, character interaction, rain-sized local, heavy impact, performance, and debug-strong field setups.
  - Emitter presets include footstep, wading character, NPC ambient, small impact, heavy impact, light rain drop, and static river disturbance.
- Presets copy approved authoring values only.
  - They do not store runtime textures.
  - They do not store river target routing.
  - They do not save `.tres` resources at runtime.
  - They do not create exported preset slots or live profile links on nodes.
  - They do not touch bakes, `WaterSystem`, source signatures, material ownership, refraction, displacement, or buoyancy.

## Editor Polish

- Added `ripple_inspector_plugin.gd` for editor-only inspector controls.
- Added `ripple_inspector_status.gd` for probeable read-only status rows.
- Added read-only field/emitter status UI.
  - Reports exported values, configuration warnings, and conservative routing/target summaries.
  - Does not call runtime rebuild, reset, emission, material, boundary, source-signature, private resolver, or runtime texture paths.
- Added transient preset Apply controls.
  - Selectors and resource pickers are UI state only.
  - Applying copies Phase 9 whitelisted values through one grouped per-property editor undo action.
  - No-op applies skip dirtying and undo actions.
  - Active built-in status is derived from copied node values, not saved links.
- Added capture/save controls.
  - Capture creates scratch in-memory presets without mutating the node.
  - Save opens an editor-owned save dialog and writes only to an explicit user-selected `.tres` path.
  - Runtime scripts and preset resources remain free of `ResourceSaver` and save-path behavior.
- Added visual gizmo helpers.
  - Field bounds.
  - Field footprint and center cross.
  - Target route lines.
  - Emitter radius rings.
  - Moving-emitter threshold rings.
  - Emitter-to-field route lines.
- Added undo-backed editable handles.
  - Emitter `radius`.
  - Emitter `moving_emit_distance`, including a pickable guide for tiny values.
  - Field `world_bounds` six-face handles with stable IDs `2001..2006`.
- Added editor-only field boundary preview.
  - Draws a projected mesh-footprint outline from configured boundary or target mesh sources.
  - Does not generate a runtime boundary texture.
  - Does not create preview children or mutate exported values.

## Validation

- Automated validation passed for:
  - standalone feedback spread/decay
  - 128/256/512 precision checks
  - mapping marker parity
  - mesh-footprint boundary masks
  - material ownership and restore
  - river shader neutral path
  - ripple sampling budget
  - visible normal render behavior
  - demo visible-normal review setup and diagnostics
  - debug parity
  - shader-cost and renderer coverage
  - field/emitter lifecycle
  - field/emitter dispatch performance
  - demo-backed field/emitter authoring
  - Phase 9 preset API, grouping, starter presets, scratch reload, and no-save boundaries
  - Phase 10 inspector/apply/capture-save/gizmo/handle/boundary-preview contract
- Human-visible validation passed for:
  - standalone feedback rings spreading and decaying
  - mapping markers matching texture impulses
  - boundary mask shape and dry gap
  - demo visible-normal flow and outward rings after review-fixture fixes
  - debug view behavior
  - field/emitter visual/debug/control/stop-reload workflow
  - Add Node visibility for both ripple classes and icons
  - Phase 9 grouped inspector authoring
  - Phase 10 read-only inspector lifecycle and dirty-state behavior
  - Phase 10 Apply undo/redo, no-op, active-preset, and boundary behavior
  - Phase 10 capture/save with explicit save paths and no live links
  - Phase 10 visual gizmos
  - practical emitter handle behavior
  - field `world_bounds` handle behavior
  - boundary preview behavior

## Deferred Work

- Do not re-expose `debug_visible` until helper behavior and saved-toggle semantics are planned and validated.
- Do not enable live-scene reset, rebuild, emit-once, or runtime texture preview buttons until a live-scene bridge is designed and validated.
- Do not tune response, refraction, or displacement without a separate visual tuning plan.
- Do not add foam, boat wakes, capsule/trail/stamp emitters, dense rain systems, flow-aware advection, physics sampling, WaterSystem integration, buoyancy behavior, river bake changes, source-signature changes, or saved ripple persistence without their own plans and validation gates.
