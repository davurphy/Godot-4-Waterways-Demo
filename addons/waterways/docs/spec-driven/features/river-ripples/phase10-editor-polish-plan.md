# Phase 10 Editor Polish Plan: River Ripples

## Date

2026-06-08

## Purpose

This plan covers native-feeling editor workflow for River Ripples after the Phase 9 script/API and preset-resource contract is stable.

Phase 10 should make ripple authoring convenient in the Godot editor without changing the visual ripple simulation, river bakes, `WaterSystem`, source signatures, buoyancy, foam, refraction tuning, or displacement tuning.

## Why This Is Separate From Phase 9

Major engines make water authoring feel native through editor UI:

- Unity HDRP exposes water deformers, caps, bounded regions, masks, decals, foam settings, and debug modes as authoring concepts.
- Unreal exposes Water Body settings, Water Waves Assets, viewport/debug visualizations, and Details-panel customization for engine-integrated workflows.
- Godot can support similar polish through `EditorInspectorPlugin`, `EditorPlugin`, docks, gizmos, and undo/redo managers. Simple `@export_tool_button` actions exist, but they are not enough for the undo-aware, save-dialog, preview, lifecycle, and export-boundary behavior expected here.

Phase 9 should not depend on that polish. Phase 10 can add it once the ordinary exported fields and type-specific preset resources already work.

## Current Scope

In scope:

- A small ripple inspector extension for `WaterRippleField` and `WaterRippleEmitter`.
- Editor buttons for common authoring actions.
- Undo-aware editor preset application.
- Editor save/capture workflow for `WaterRippleFieldPreset` and `WaterRippleEmitterPreset`.
- Optional editor preset asset slots or selector controls, only if they are action inputs and never live auto-applying profiles.
- Modest editor visualization for field bounds, target coverage, and boundary/influence review.
- Re-exposing or renaming the hidden Phase 9 `debug_visible` reservation once real helper behavior exists.
- Validation that editor-only tooling does not leak into exported runtime scenes.

Out of scope:

- Changing ripple visual response tuning.
- Adding refraction or displacement behavior.
- Adding foam or whitewater.
- Adding new emitter shapes such as capsule, trail, texture stamp, or bow wake.
- Replacing the runtime `SubViewport` feedback path.
- Runtime physics or buoyancy integration.
- River bake or `WaterSystem` changes.

## Non-Negotiable Contracts

The two adversarial reviews are integrated into the implementation rules below. These contracts are the source of truth for Phase 10 unless a later plan explicitly changes one of them and adds matching validation.

### Runtime/editor separation

Ordinary inspector controls operate on the edited-scene `@tool` instance, not automatically on the separate running scene. Current `WaterRippleField` and `WaterRippleEmitter` runtime methods intentionally return inert while `Engine.is_editor_hint()` is true, so runtime commands such as `Reset Feedback`, `Rebuild Runtime`, `Emit Once`, and runtime texture previews are deferred until a later live-scene bridge is designed and validated.

Phase 10 editor UI must not call `initialize_runtime()`, `reset_feedback()`, RiverManager material APIs, boundary-mask bake paths, source-signature logic, target registration, or emitter dispatch from editor status, selector, or preview paths. Editor previews must be overlays, gizmos, or inspector-only data reads unless a separate editor-safe rendering design is accepted.

### Editor-only saving

Preset save/capture workflow belongs in editor/plugin code only. Resource writes must use an explicit user-selected path and must never be called by `WaterRippleField`, `WaterRippleEmitter`, runtime `apply_preset()`, runtime `capture_preset()`, or preset resources.

### Transient preset selection

Preset selectors are action inputs, not live profile slots. Phase 10 must not add `field_preset`, `emitter_preset`, generic preset slots, stored resource paths, auto-apply flags, or serialized inspector selection state to ripple nodes.

### Undo and dirty-state precision

Every action must define mutation, undo/redo, and dirty-state behavior before code. The action matrix below is authoritative. Read-only status, selector focus, capture-only, preview-only, and future runtime-only commands must not mark scenes dirty.

Editor preset apply must use `EditorUndoRedoManager` property operations for each changed whitelisted property. Do not use `apply_preset()` itself as the editor undo do-method, because runtime apply remains a script-facing convenience API and may invoke runtime rebuild/material side effects if the target context changes.

### Read-only means non-mutating

Read-only rows may inspect exported values, configuration warnings, or safe snapshots only. Routing summaries must not call private resolver/cache methods such as `WaterRippleEmitter._resolve_field()`. If a summary cannot be computed from exported paths, parent/ancestor checks, groups, and configuration warnings, show a conservative unresolved state.

### Lifecycle cleanup

Plugin enable/disable, scene close, node deletion, inspector reselection, and play/stop must clean up custom inspector UI, preview state, cached resources, signal connections, gizmos, overlays, and any transient texture/debug handles.

### Hidden and reserved fields

Hidden/reserved Phase 9 fields stay hidden unless Phase 10 gives them supported behavior and validation. `debug_visible` may only be exposed with real helper behavior. `refraction_strength` and `displacement_strength` stay out of Phase 10.

Implementation starts with a read-only inspector skeleton slice that proves lifecycle and non-mutating status behavior before any buttons, save dialogs, gizmos, previews, or runtime commands are added.

## Editor Inspector Contract

Phase 10 may add a dedicated `EditorInspectorPlugin` or equivalent Waterways editor panel for ripple nodes.

The inspector must follow the non-negotiable contracts above. It should start as read-only status UI, then add one mutation category at a time only after that category has an action-matrix row and validation coverage.

Avoid treating `@export_tool_button` as the final implementation for preset apply/capture/save actions unless the action is deliberately non-undo, non-saving, and documented as such. The default expectation for Phase 10 is undo-aware editor tooling.

Recommended field actions:

- `Apply Field Preset`
- `Capture Field Preset`
- `Save Field Preset`
- `Reset Feedback` only after an explicit live-scene bridge exists; disabled in ordinary editor inspection
- `Rebuild Runtime` only after an explicit live-scene bridge exists; otherwise use `Rebuild On Play` guidance
- `Preview Boundary` only if an editor-safe preview path is implemented

Recommended emitter actions:

- `Apply Emitter Preset`
- `Capture Emitter Preset`
- `Save Emitter Preset`
- `Emit Once` only after an explicit live-scene bridge exists; disabled in ordinary editor inspection
- `Show Routing Summary`

Button actions must not be ordinary runtime assumptions hidden in the inspector. They should use editor APIs, mark scenes/resources dirty intentionally, and participate in undo/redo where practical.

If preset resources are shown in the inspector, the UI should present them as transient sources for explicit commands such as `Apply Field Preset`, not as live profile slots. Editing a preset asset must not silently update nodes that previously copied from it. Do not add `field_preset`, `emitter_preset`, generic preset slots, stored resource paths, auto-apply flags, or serialized inspector selection state to `WaterRippleField` or `WaterRippleEmitter` in Phase 10.

Read-only status rows may use diagnostics such as configuration warnings or snapshots, but must not force runtime initialization, rebuilds, target registration, material application, boundary generation, or emitter dispatch in editor mode.

Read-only routing summaries should be computed without mutating ripple nodes. Do not call private cache/resolver methods such as `_resolve_field()`, `_refresh_target_rivers()`, `_get_target_mesh_instances()`, or runtime RID/texture internals from inspector status rows. If a summary cannot be computed from exported paths, parent/ancestor checks, groups, and configuration warnings, show a conservative unresolved state instead.

## Action, Undo, And Dirty-State Matrix

Every editor action needs an explicit mutation contract before implementation. This matrix is the source of truth for what Phase 10 editor UI may mutate.

| Action | Allowed mutation | Undo/redo expectation | Dirty-state expectation |
| --- | --- | --- | --- |
| Read-only status rows | None. Read exported values, configuration warnings, or safe snapshots only. | None. | Never marks scene/resource dirty. |
| Preset selector/input control | Editor UI state only; no node property or serialized scene dependency. | None until Apply. | Never marks scene dirty by selection alone. |
| Apply field/emitter preset | Copy the Phase 9 whitelist of values into the selected node. No targets, material state, bakes, source signatures, refraction, displacement, or hidden reservations. | One grouped editor undo action for all changed exported properties; redo reapplies the copied values. | Marks the scene dirty only when values actually change. |
| Capture field/emitter preset | Create a fresh in-memory scratch preset from current editable values. No node mutation and no asset assignment. | None. | Never marks scene/resource dirty by capture alone. |
| Save captured preset | Save only through editor/plugin save UI to the path explicitly chosen by the user. | No node undo unless a separate assign/update action is explicitly implemented. | Writes the chosen resource asset; does not mark the scene dirty unless a separate intentional node assignment is implemented. |
| Reset feedback | Deferred until an explicit live-scene bridge exists. Disabled or guidance-only in normal editor inspection. | None unless a later bridge defines a runtime-only command history, which is out of this slice. | Never marks scene/resource dirty. |
| Rebuild runtime | Deferred until an explicit live-scene bridge exists, or guidance-only for next play. Disabled in normal editor inspection unless a separate editor-safe runtime design exists. | None unless a later bridge defines a runtime-only command history, which is out of this slice. | Never marks scene/resource dirty. |
| Emit once | Deferred until an explicit live-scene bridge exists. Disabled in normal editor inspection because the edited `@tool` instance is not the running scene instance. | None. | Never marks scene/resource dirty. |
| Preview boundary/debug helper | Editor-only overlay, gizmo, or non-persistent scratch display. No runtime material or texture assignment. | None unless the user edits an exported visual-helper property. | Never marks scene/resource dirty by preview alone. |
| Bounds/radius gizmo edit | Explicit exported property or transform edits only. | One grouped editor undo action per drag/commit. | Marks the scene dirty only for the edited property/transform. |
| Re-expose or rename `debug_visible` | Only if backed by visible/helper behavior and documented semantics. | Undoable if it is an exported saved toggle. | Marks scene dirty only when the saved toggle changes. |

Actions not listed here should be treated as out of scope until their mutation, undo, and dirty-state behavior are added to this matrix.

## Forbidden Editor Calls

These calls and call families are forbidden from read-only status rows, selector controls, capture-only paths, and ordinary editor previews:

- `initialize_runtime()`
- `rebuild_runtime()`
- `rebuild_boundary_mask()`
- `reset_feedback()`
- `queue_impulse*()`
- `emit_once()`
- `register_target()`
- `unregister_target()`
- `apply_runtime_ripple_material_state()`
- `clear_runtime_ripple_material_state()`
- private resolver/cache methods such as `_resolve_field()`, `_refresh_target_rivers()`, and `_get_target_mesh_instances()`
- runtime RID or texture internals such as `get_runtime_viewport_rids()` unless a future live-scene bridge explicitly validates read-only inspection of an already-running scene

If editor UI needs information that only one of these methods can provide, the UI should show an unknown/unresolved state or the plan should add a separate editor-safe query API before implementation.

## Scratch Resource Contract

Scratch resources are editor-private, transient values used by inspector controls or previews.

- Captured presets start with an empty `resource_path` and no back-reference to the source node.
- Scratch preset resources are not assigned to field/emitter nodes unless a later plan explicitly accepts a saved node property.
- Scratch textures, preview meshes, overlay materials, and caches must be held by editor/plugin code, preferably through weak references or disposable owners.
- Scratch resources must not be saved under runtime paths, embedded into scenes, added to river resources, or written into preset resources unless the user chooses an explicit Save action for a preset asset.
- Plugin disable, scene close, inspector reselection, node deletion, and play/stop must drop scratch resources and hide preview overlays.

## Undo And Save Contract

Editor actions that change exported node properties should use the editor undo/redo path.

- Applying a preset through the editor should be undoable.
- Capturing a preset should not mutate the scene unless the user saves or assigns the resource.
- Saving a captured preset should write an explicit `.tres`/resource asset through a deliberate save path.
- Editing a saved preset should not retroactively alter nodes that previously copied from it.
- Runtime `apply_preset()` remains script-callable and does not provide editor undo by itself.
- Runtime `capture_preset()` remains in-memory only; Phase 10 owns any editor workflow that writes a captured preset to disk or assigns it to an editor UI control.
- Editor preset saving should use explicit paths and resource-save APIs, and should avoid automatic writeback to the preset that was just applied unless the user requested that asset update.
- `ResourceSaver` usage for Phase 10 preset assets belongs in editor/plugin code only. Static scans should keep runtime field/emitter scripts free of new `.tres` save paths and runtime resource-saving helpers.
- Save dialogs must not default to silently overwriting the source preset that was most recently applied. Updating an existing preset asset needs an explicit user-visible update/overwrite action.
- Editor apply should use the same value-copy whitelist proven by Phase 9. Do not copy target routing, field/group names, runtime texture handles, generated boundary masks, material state, source signatures, refraction, displacement, or hidden reservations.
- Editor apply should compute the sanitized next values from the selected preset, compare them against the selected node, and skip the undo action entirely if no whitelisted value changes.
- When values do change, create one editor undo action with the selected edited-scene node as context, add per-property `add_do_property()` and `add_undo_property()` entries, and add warning/inspector refresh calls only after the property operations. Do not use `apply_preset()` itself as the editor undo do-method.

## Editor-Only Script Placement

New Phase 10 editor classes should be isolated from exported runtime scripts.

- Put ripple inspector/plugin UI code in editor/plugin scripts, such as a dedicated `@tool` `EditorInspectorPlugin` script preloaded only from `addons/waterways/plugin.gd`.
- Register editor helpers from `EditorPlugin._enter_tree()` and unregister them from `_exit_tree()`, matching the existing Waterways plugin pattern.
- Runtime scripts and preset resources must not reference `EditorPlugin`, `EditorInspectorPlugin`, `EditorUndoRedoManager`, `EditorFileDialog`, `EditorResourcePicker`, `EditorNode3DGizmoPlugin`, or other editor-only classes.
- If an `EditorResourcePicker` is used for preset selection, keep its `edited_resource` as private UI state inside the custom control. Do not bind it to a node property, do not call `emit_changed()` for a node preset slot, and clear the selection when the inspector control is rebuilt or deselected.
- Preset save UI should use an editor-owned `EditorFileDialog`/`FileDialog` save workflow with resource-path access, `.tres`/resource filters, and overwrite warning left enabled. `ResourceSaver.save()` should run only after the user-selected path is received.

## Debug And Preview Contract

Phase 10 should make the hidden Phase 9 `debug_visible` reservation real before it is exposed again. It may keep the `debug_visible` name if the behavior is simple visibility, or rename it to a clearer diagnostics flag if the feature becomes runtime-status oriented.

Minimum useful behavior before any live-scene bridge:

- Field bounds visualization.
- Target river coverage or target list summary.
- Non-mutating emitter-to-field routing summary.

Optional behavior:

- Editor-safe boundary mask preview.
- 3D gizmo handles for field bounds or emitter radius if this can be maintained cleanly.
- Last accepted/rejected emission status while running, only after a validated live-scene status path exists.
- Runtime-only texture preview of raw height, impulse/contact, boundary, and visible influence when the scene is running, only after a validated live-scene bridge exists.

Avoid:

- Running the full ripple simulation in editor mode without a separate editor-safe rendering design.
- Saving runtime viewport textures.
- Dirtying river bakes or material resources while previewing.
- Leaving debug materials or duplicate runtime materials assigned after scene stop/reload.
- Exposing an inert debug checkbox that does not change visible/helper behavior.
- Mutating runtime scene state, river materials, WaterSystem data, bakes, source signatures, boundary-source assets, or buoyancy from `@tool` or inspector preview paths.
- Calling runtime rebuild, target material apply/clear, emitter dispatch, or boundary-mask generation from editor preview code unless a later editor-safe rendering design explicitly accepts that behavior.

Cleanup requirements:

- Preview overlays and debug helpers must clear on inspector deselection, scene close, node deletion, plugin disable, and play/stop transitions.
- Preview state must not persist in `.tscn`, `.tres`, material resources, river resources, or generated bake folders.
- Runtime-only texture previews are allowed only after a live-scene bridge is explicitly designed. They must inspect existing runtime state without saving, replacing, or initializing it.

## Live-Scene Bridge Deferral

Phase 10 does not initially include a bridge from inspector UI to the running scene tree.

Deferred features:

- `Reset Feedback`
- `Rebuild Runtime`
- `Emit Once`
- runtime texture previews
- any command that depends on runtime `SubViewport`, runtime material ownership, queued impulses, active emitters, or live ripple feedback state

A future live-scene bridge plan must prove how it locates the running-scene instance corresponding to the edited node, how it avoids mutating the edited scene by accident, how it behaves when multiple scenes are open or running, and how cleanup works across play/stop, scene reload, and plugin disable. Until then, these controls should be absent, disabled, or guidance-only.

## Runtime/Editor Boundary

Editor-only code belongs in plugin/editor scripts, not in exported runtime logic unless carefully guarded.

- Do not require editor nodes for runtime ripple behavior.
- Do not reference editor-only classes from runtime scripts in a way that breaks export parsing.
- Do not make `WaterRippleField` or `WaterRippleEmitter` depend on editor UI to function.
- Keep editor preview helpers disposable and easy to remove when the plugin is disabled.
- Do not make runtime preset application or capture depend on editor-only save dialogs, inspector widgets, or undo managers.
- Do not add `@tool` behavior to runtime field/emitter scripts that mutates simulation textures, river materials, bakes, target lists, source signatures, or buoyancy in editor mode.
- Do not reference `EditorPlugin`, `EditorInspectorPlugin`, `EditorUndoRedoManager`, `EditorFileDialog`, or other editor-only classes from exported runtime scripts.
- Plugin enable/disable must register and unregister inspector plugins, docks, gizmos, signal connections, preview overlays, and caches cleanly.
- Editor code may call runtime methods only when the action is explicitly runtime-scene-only or when the method is proven read-only and parser/export safe.
- Ordinary inspector UI should target nodes under `EditorInterface.get_edited_scene_root()`. Do not assume a selected edited-scene node is the live running-scene node; live-scene actions require their own bridge and validation.

## Validation Gates

Before implementation:

- Phase 9 exported grouping, type-specific presets, and apply/capture methods are implemented and passing validation.
- Phase 9 does not expose field/emitter preset assets as live exported node slots, and runtime capture remains in-memory only.
- Decide whether editor polish belongs in an inspector plugin, dock, gizmo plugin, or a small combination.
- Decide whether to re-expose `debug_visible` under the existing name or rename it for clearer runtime diagnostics.
- Fill or preserve the action matrix above for any new editor command before code.

After implementation:

- Parser/headless checks for editor and runtime scripts.
- Plugin enable/disable does not leak controls or crash.
- Add Node visibility still works for `WaterRippleField` and `WaterRippleEmitter`.
- Editor preset apply is undoable and redoable.
- Captured preset save/load survives editor restart or headless reload.
- Scene dirty state changes only when expected.
- No-op Apply commands create no undo action and do not mark the scene unsaved.
- Applying a preset through editor UI copies values and does not leave a live link unless a later plan explicitly accepts one.
- Runtime apply/capture still works without editor tooling and never saves preset resources automatically.
- Scene save/reload and play/stop leave no stale runtime ripple material state.
- Exported/runtime scene does not depend on editor-only preview nodes.
- No generated river bake resources, `WaterSystem` resources, source signatures, buoyancy files, or saved material resources change.
- Human-visible editor review confirms the workflow is clear without editing shader code.
- Static scan confirms runtime field/emitter scripts gained no new `ResourceSaver`, `.tres` write path, editor-only class reference, or editor-preview mutation path.
- Static diff review confirms no changes to final flow, `WaterSystem`, bakes, source signatures, buoyancy, response/refraction/displacement tuning, or river material resources.
- Editor-load check opens a scene with the plugin enabled, selects field/emitter nodes, switches selection, disables the plugin, and closes/reopens the scene without Output errors or stale UI.
- Human-visible review confirms selector changes and preview toggles do not dirty the scene, while an intentional Apply or gizmo edit does.
- Save/reload review confirms captured presets save only at the user-selected path, load after editor restart, and do not create live node links.
- Static scan confirms Phase 10 editor scripts do not call anything in the Forbidden Editor Calls section from read-only/status/selector/capture-only paths.
- Any future live-scene action proves how it reaches the running scene instance, proves it does not mutate the edited scene by accident, and remains disabled until that proof exists.

## Implementation Slices

Recommended order:

1. Completed 2026-06-08: Inspector plugin skeleton plus read-only status rows for field/emitter nodes. This retired the editor-load and read-only status-boundary risks first. It shows warnings, routing/target summaries, and safe snapshots, but does not mutate scene/runtime state or expose preset/save/preview buttons yet.
2. Completed 2026-06-08: Plugin lifecycle validation. User confirmed enable/disable, inspector reselection, scene close/reopen, play/stop, Add Node visibility, no Output errors, no stale duplicated UI, and no dirty-scene prompts from simple read-only inspection.
3. Completed 2026-06-08: Undo-aware apply-preset buttons and selector actions for already-defined Phase 9 resources. This retired the copied-value risk by console/static proof and visible editor review. It uses transient selector state, no live profile link, no serialized preset slot, per-property undo operations, no-op apply skipping, active preset status/selector restoration, and no runtime `apply_preset()` undo do-method.
4. Implemented 2026-06-08; human-visible review pending: Capture/save preset buttons with explicit editor-only resource save behavior. This retires the `ResourceSaver` leakage risk by automated proof: capture stores unsaved scratch resources, save uses an editor-owned `EditorFileDialog` and explicit `.tres` path, saved scratch presets reload, and runtime field/emitter scripts plus preset resources still have no editor-only save references. It must still pass visible editor save-dialog, dirty-state, restart/reload, and no-live-link review.
5. Next implementation slice after capture/save review: Optional bounds/radius gizmos only if they use editor undo/redo and do not touch runtime materials, bakes, `WaterSystem` data, source signatures, or buoyancy.
6. Re-expose or rename `debug_visible` only after helper visualization for bounds/radius/routing exists and does not run the simulation in editor mode. `refraction_strength` and `displacement_strength` remain hidden.
7. Optional boundary preview helpers only after a separate editor-safe preview path is proven and added to the action matrix.
8. Optional live-scene texture/runtime buttons only after a separate bridge to the running scene is designed, validated, and added to this plan.
9. Human-visible editor workflow review and renderer/runtime regression sweep.

## Decision Log

- 2026-06-08: Split native editor buttons, undo-aware preset application, save dialogs, and preview helpers out of Phase 9.
- 2026-06-08: Keep Phase 10 editor polish dependent on a stable Phase 9 script/API and type-specific preset-resource contract.
- 2026-06-08: Keep editor-time simulation preview out of scope until a separate editor-safe rendering path is designed.
- 2026-06-08: Acknowledge simple `@export_tool_button` support, but keep Phase 10 focused on undo-aware, save-aware editor tooling.
- 2026-06-08: Keep preset UI action-based rather than live linked; applying copies values and editing saved preset assets does not retroactively update previously applied nodes.
- 2026-06-08: Re-expose or rename `debug_visible` only after concrete helper/debug behavior exists.
- 2026-06-08: Adversarial review tightened Phase 10 around editor-only preview paths, editor-only `ResourceSaver` usage, transient preset selectors, explicit undo/dirty-state behavior, scratch resource isolation, and plugin cleanup before implementation.
- 2026-06-08: Second adversarial review demoted running-scene inspector actions until a live-scene bridge exists, required per-property editor undo for preset apply, banned private resolver/cache calls in read-only status rows, and added exact editor-only script/resource-picker/save-dialog boundaries.
- 2026-06-08: Integrated both adversarial reviews into non-negotiable contracts, forbidden editor calls, live-scene deferral, validation gates, and risk-retiring implementation slices while preserving the original Phase 10 scope.
- 2026-06-08: Implemented and user-validated the read-only inspector skeleton and lifecycle/dirty-state gate; next Phase 10 code should start with transient, undo-aware preset Apply controls.
- 2026-06-08: Implemented transient built-in/resource preset Apply controls through the inspector plugin. Apply uses probeable whitelisted value diffs and per-property `EditorUndoRedoManager` operations, skips no-op diffs, does not serialize selector state, restores matching built-in selector/status display from copied node values after inspector rebuild, and keeps runtime `apply_preset()` out of the editor undo do-method. Human-visible review accepted selector non-dirty behavior, Apply undo/redo, same-actual-preset no-op dirty-state skipping, target/material/bake/reserved-value boundaries, neutral placeholder disabling, lifecycle cleanup, and no Output errors.
- 2026-06-08: Implemented capture/save controls through the inspector plugin. Capture uses the existing in-memory preset capture path, stores only transient scratch resources with empty `resource_path`, and Save opens an editor-owned `EditorFileDialog` before calling `ResourceSaver.save()` on an explicit `.tres` path. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` now covers saved scratch preset reload, target/reserved exclusion, and editor/runtime save-boundary scans; visible editor save-dialog/dirty-state/restart review remains pending.
