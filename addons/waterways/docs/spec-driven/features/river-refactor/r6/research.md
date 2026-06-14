# Research: River Refactor R6 - river_manager.gd Decomposition

## Purpose

This research file records the source context needed to execute R6 safely. R6 is mostly an internal decomposition, so the primary evidence is local: the R6 plan, parent river-refactor docs, current `river_manager.gd`, existing probes, and R5 validation results.

For implementation work that depends on Godot behavior, search current official Godot documentation and API references before patching. Prefer official Godot docs first for async nodes, `RefCounted`, `SubViewport`, `ImageTexture`, `ShaderMaterial`, scene-tree lifetime, resource saving, and editor/runtime boundaries. Add any source that affects implementation here or in the shared citations index.

Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`.

## Current Research Outcome

- Status: Local decomposition direction is accepted by `plan.md`; R6.3, R6.4, R6.1B-H, and R6.2 shadow-table implementation-specific Godot API checks are recorded below.
- Recommendation: Preserve current behavior by moving code behind explicit config/result/callback boundaries, not by changing algorithms or freezing state at bake start. For runtime ripple material ownership, keep RiverManager as a wrapper/material applier and move live owner/material state into a narrow helper. For editor validation, keep public RiverManager wrappers and move implementation behind a named read-only context plus cleanup callback. For the bake path, R6.2 now uses the constants table for live metadata/signature/settings constant rows while leaving dynamic final reads explicit in RiverManager.
- Confidence: High for the local architecture, R6.3/R6.4 extractions, R6.1B-H bake slices, and R6.2 shadow constants table; medium for the remaining live dictionary switch/final validation path until the narrow replacement context for collision/terrain helper reach-back is implemented.
- Biggest unknown that remains: the exact narrow context needed to replace `WaterHelperMethods.generate_collisionmap()` and `generate_terrain_contact_feature_map()` RiverManager reach-back.
- Decision or plan section this research unlocked: `spec.md` source timing contract, `validation.md` no-reach-back checklist, R6.3 `river_ripple_material_owner.gd` extraction, R6.1F warning/diagnostic callback routing, the R6.1G RiverManager-owned synchronous result application boundary, the R6.1H cancellation/liveness strategy, and the R6.2 static constants-table shadow helper.

## Questions

- What explicit dependencies does the baker need for frame awaits, cancellation/liveness, collision reset, terrain/collision queries, warnings, prints, progress, and renderer ownership?
- Which current `_generate_flowmap()` awaits are visible directly, and which are hidden inside helper loops?
- Which fields are read at bake start, during source generation, during filter passes, during final dictionary assembly, and during result application?
- Would a typed `RefCounted` data object reduce key drift more than dictionaries for `BakeConfig`, `BakeResult`, and `BakeAbort`?

## Flow-Map and Water Tool Patterns

R6 does not introduce a new flow-map algorithm. The relevant pattern is architectural:

- keep public node state and editor-facing APIs on RiverManager
- move render/bake orchestration into a helper with explicit dependencies
- keep generated texture content and channel packing byte-identical
- centralize constant rows without implying automatic signature coverage
- keep validation fixtures and hash gates close to the moved behavior

No new external water/flow-map research has informed R6 yet.

## Godot 4.6+ Findings

R6.3 runtime ripple material ownership findings checked against official Godot 4.6 documentation on 2026-06-13:

- `ShaderMaterial` uniform parameter changes affect all instances using the same material resource unless the material is duplicated or per-instance uniforms are used. R6.3 therefore keeps duplicate visible/debug materials for runtime ripple state.
- `Resource.duplicate(true)` and `resource_local_to_scene` are the intended resource-level tools used by the extracted owner to make runtime material state local and restorable.
- `Object.connect()`, `Object.disconnect()`, and `Object.get_instance_id()` support owner-token and signal cleanup behavior.
- `Node.tree_exiting` remains the lifecycle signal used to restore runtime ripple materials when the owner node leaves the tree.

R6.4 editor validation extraction findings checked against official Godot 4.6 documentation on 2026-06-14:

- GDScript `await` on signals/coroutines returns control to the caller and resumes when the signal or coroutine finishes, so keeping `validate_filter_renderer()` as an async public wrapper around a helper preserves the current call pattern.
- `RefCounted` is suitable for the extracted non-node validation helper because it does not need to live in the scene tree or retain editor singleton state.
- Temporary renderer cleanup still belongs to explicit node cleanup: `Node.remove_child()` detaches without deleting, and `Node.queue_free()` deletes the node at the end of the frame, including children.

R6.1C run-pass helper findings checked against official Godot stable documentation on 2026-06-14:

- `Callable.call()` invokes the method represented by a `Callable` and returns its result as a `Variant`.
- GDScript `await` on a coroutine waits for completion, while `await` on a non-coroutine value returns that value immediately. The baker `_run_pass(label, pass_callable)` can therefore use `await pass_callable.call()` for both renderer async passes and focused synchronous validation callables without splitting the helper into separate sync/async paths.

R6.1D source-image helper move findings checked against official Godot 4.6 documentation on 2026-06-14:

- `Image.create()`, `Image.fill()`, `Image.set_pixel()`, `Image.get_data()`, and texture read/write helpers remain the correct procedural image APIs for the baker-owned source-image routines.
- `ImageTexture.create_from_image()` creates a new texture initialized from an `Image`, which preserves the existing margin-source texture handoff shape while moving the helper owner.
- `Curve3D.get_baked_length()`, `Curve3D.get_closest_offset()`, `Curve3D.get_point_position()`, and `Curve3D.sample_baked()` are stable `Curve3D` APIs for the grade, bend-bias, and flow-speed source helpers; R6.1D passes the live `Curve3D` as a named source dependency instead of passing RiverManager.

R6.1E pass-sequencing findings checked against official Godot stable documentation on 2026-06-14:

- `Callable.bindv(arguments)` and `Callable.call()` support the baker's `_run_renderer_pass(label, renderer, method, args)` wrapper without broad RiverManager reach-back; the method arguments are explicit arrays, and `_run_pass()` still owns the checked result/abort record.
- `ImageTexture.create_from_image()` remains the right way to create the pressure seed texture from an `Image` before the Jacobi solve, preserving the old seed texture format and size.
- `SubViewport.UPDATE_ONCE` is still the renderer-side update mode used by `filter_renderer.gd` for a single pass render/readback.
- `RenderingServer.force_draw()` exists for forced viewport drawing from the main thread, but R6.1E did not add a forced-draw path; the existing two-frame `filter_renderer.gd` readback behavior stayed unchanged.
- Sources checked: Godot stable class reference pages for `Callable` (`https://docs.godotengine.org/en/stable/classes/class_callable.html`), `ImageTexture` (`https://docs.godotengine.org/en/stable/classes/class_imagetexture.html`), `SubViewport` (`https://docs.godotengine.org/en/stable/classes/class_subviewport.html`), and `RenderingServer` (`https://docs.godotengine.org/en/stable/classes/class_renderingserver.html`).

R6.1F diagnostics/image postprocess findings checked against official Godot stable documentation on 2026-06-14:

- `Callable.is_valid()` and `Callable.call()` support named warning and diagnostic callbacks without passing RiverManager into the baker.
- `@GlobalScope.push_warning()` remains the Godot warning sink used by RiverManager; R6.1F routes moved user-facing warnings through a RiverManager callback so warning text and timing stay at the public owner boundary.
- `ImageTexture.create_from_image()` creates a new texture initialized from an `Image`, so the baker can return final textures after CPU image edits while RiverManager still applies the result.
- Sources checked: Godot stable class reference pages for `Callable` (`https://docs.godotengine.org/en/stable/classes/class_callable.html`), `@GlobalScope` (`https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html`), and `ImageTexture` (`https://docs.godotengine.org/en/stable/classes/class_imagetexture.html`).

R6.1G result assembly/application findings checked against official Godot 4.6 documentation on 2026-06-14:

- `ResourceSaver.save(resource, path, flags)` returns an `Error` and uses `resource.resource_path` when no path is supplied, which matches keeping external bake resource storage and error handling behind the existing RiverManager/WaterHelperMethods save path rather than moving save behavior into the baker.
- Godot `Resource` instances are reference-counted data containers that can be nested and saved on disk; R6.1G keeps `RiverBakeData` as RiverManager-owned saved resource state and uses the baker result only as the transient handoff.
- Sources checked: Godot 4.6 class reference pages for `ResourceSaver` (`https://docs.godotengine.org/en/4.6/classes/class_resourcesaver.html`) and `Resource` (`https://docs.godotengine.org/en/4.6/classes/class_resource.html`).

R6.1H abort-matrix findings checked against official Godot 4.6 documentation on 2026-06-14:

- `Node.queue_free()` deletes the node at the end of the current frame, deletes children, and leaves existing references invalid after deletion; R6.1H therefore checks queued/free state around source helper waits and renderer-pass awaits instead of assuming stored node references stay safe.
- `Object` references can become invalid without becoming `null`, and official docs recommend `is_instance_valid()` for deleted-object checks; R6.1H uses untyped liveness helper parameters where freed `Object` references must be inspected safely.
- GDScript `await` returns control to the caller and resumes when the signal/coroutine completes; R6.1H keeps result application and image postprocess synchronous/non-awaited and adds cancellation checks before and after awaited renderer-pass callables.
- Sources checked: Godot 4.6 class reference pages for `Node` (`https://docs.godotengine.org/en/4.6/classes/class_node.html`), `Object` (`https://docs.godotengine.org/en/4.6/classes/class_object.html`), and GDScript `await` (`https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#awaiting-signals-or-coroutines`).

R6.2 constants-table shadow findings checked against official Godot latest documentation on 2026-06-14:

- GDScript static functions have no access to instance member variables or `self`, which fits `river_bake_constants.gd` as a static helper with no live RiverManager dependency.
- Dictionaries are passed by reference, and `Dictionary.duplicate(true)` deep-copies nested arrays and dictionaries; the shadow builder therefore duplicates dynamic input dictionaries before adding table-generated constants.
- `RefCounted` remains suitable for helper scripts that do not need scene-tree lifetime ownership.
- Sources checked: Godot latest GDScript static functions (`https://docs.godotengine.org/en/latest/tutorials/scripting/gdscript/gdscript_basics.html#static-functions`), `Dictionary.duplicate()` (`https://docs.godotengine.org/en/latest/classes/class_dictionary.html#class-dictionary-method-duplicate`), and `RefCounted` (`https://docs.godotengine.org/en/latest/classes/class_refcounted.html`).

Implementation research still needed before future bake patching:

- `RefCounted` lifetime and async method patterns for long-running bake coordinators. Checked for R6.2 static helper suitability; recheck if a future helper stores async bake state or node references.
- Node and scene-tree lifetime behavior around `tree_exiting`, freed nodes, and awaited coroutines. Checked for R6.1H cancellation/liveness; recheck if future source-helper context signatures change.
- `SubViewport` update/readback behavior and cleanup expectations for temporary render nodes. Checked for the R6.1E pass-sequencing move; recheck if the renderer wait/readback timing changes.
- `ImageTexture.create_from_image()` timing and resource ownership expectations. Checked for R6.1D/R6.1E source/seed handoffs and R6.1F/R6.1G final result handoffs; recheck if texture reuse/update behavior changes.
- `ShaderMaterial` parameter get/set behavior for duplicated visible/debug materials. Checked for R6.3; recheck only if the material strategy changes.
- `ResourceSaver` behavior for final bake resource saving and failure reporting. Checked for R6.1G; recheck if save ownership or storage-result behavior changes.
- Editor/runtime guards for helper scripts that should not depend on editor-only singleton state. Checked for R6.4; recheck only if future helpers start using editor singleton APIs.

Record official documentation links here when those findings are checked.

## Legacy Waterways Reference

- Relevant legacy files: not yet required for R6.
- Behavior to preserve: current Godot 4 R5 behavior, not Godot 3 behavior.
- Behavior to change: module ownership only.
- Obsolete APIs to avoid: any Godot 3-era APIs already removed by prior phases.
- Risks discovered in audit: `river_manager.gd` remains too large and owns bake orchestration, metadata assembly, and public wrapper/application surfaces. Runtime material ownership and editor validation implementation have moved out, but the bake path is still the main decomposition risk.
- What belongs in active Godot 4.6+ code: explicit helper boundaries, current shader/material APIs, current bake data contract.
- What should remain legacy-only: any Godot 3 synchronization-by-hand pattern or obsolete helper API.

## Options

### Option A: Preserve Mixed Timing and Extract Behind Explicit Dependencies

- Benefits: most behavior-preserving; minimizes mid-bake edit surprises; aligns with R6 plan.
- Costs: `BakeConfig` must carefully distinguish snapshots, live resources, final-read callbacks, and side-effect callbacks.
- Risks: helper boundaries can become leaky if broad RiverManager references sneak in.
- Fit for Waterways: best fit and current default.

### Option B: Freeze All Bake-Affecting State at Bake Start

- Benefits: simpler mental model for the baker.
- Costs: deliberate behavior change for async bakes; requires mid-bake edit proof and user-visible decision.
- Risks: source metadata/signature/settings can drift from old final-read behavior.
- Fit for Waterways: not the default; only acceptable if documented and validated.

### Option C: Extract Small Runtime/Editor Helpers Before Bake Pipeline

- Benefits: smaller review slices for R6.3 and R6.4; lower immediate bake risk.
- Costs: can delay the main `river_manager.gd` bake decomposition.
- Risks: still needs focused probes before moving ownership/markers.
- Fit for Waterways: selected for R6.3 runtime ripple material ownership and R6.4 editor validation; both slices are now validated.

## Recommendation

Proceed with Option A as the default for the remaining bake pipeline. R6.3 and R6.4 used Option C and landed successfully after focused probe coverage; R6.1B-H are now validated bake slices. R6.2 constants-table shadow work and the narrow live dictionary-generation switch are validated with shadow/canonical comparison.

## Risks and Unknowns

- Helper-internal awaits may be missed if the inventory only greps `_generate_flowmap()`.
- A broad helper context could reintroduce RiverManager reach-back under another name.
- A constants table can make signature coverage look automatic when it is still a review decision.
- Whole `.res` hash changes can create false negatives if per-texture RT.1 hashes are not the gate.
- Editor marker consumers outside the obvious plugin menu path were searched during R6.4; no active parser script consumer was found before adding the focused marker probe.

## Context Challenge Notes

- Possible misread context: a dictionary or texture mismatch may come from stale or non-fresh baselines, not an R6 code change.
- Evidence: parent validation notes that rebakes can have GPU variance and whole-resource hashes may differ while per-texture hashes match.
- Confidence: medium until fresh pre-R6 baselines are captured.
- Quick check before patching: generate canonical dictionary/property/API/source-image/texture baselines before moving code.
- User-facing note or question to raise: if a mismatch appears before any R6 logic changes, pause and explain that the baseline is suspect before continuing.

## Sources

- `addons/waterways/docs/spec-driven/features/river-refactor/r6/plan.md`: R6 roadmap and decomposition design.
- `addons/waterways/docs/spec-driven/features/river-refactor/spec.md`: parent track requirements and non-goals.
- `addons/waterways/docs/spec-driven/features/river-refactor/validation.md`: prior phase validation evidence and R6 gate row.
- `addons/waterways/docs/spec-driven/features/river-refactor/session-handoff.md`: latest parent handoff and R5 closure evidence.
- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index.
- Godot 4.6 `ShaderMaterial` class reference: https://docs.godotengine.org/en/4.6/classes/class_shadermaterial.html
- Godot 4.6 `Resource` class reference: https://docs.godotengine.org/en/4.6/classes/class_resource.html
- Godot 4.6 `Object` class reference: https://docs.godotengine.org/en/4.6/classes/class_object.html
- Godot 4.6 `Node` class reference: https://docs.godotengine.org/en/4.6/classes/class_node.html
- Godot 4.6 GDScript reference, `await` coroutines: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#awaiting-signals-or-coroutines
- Godot 4.6 `RefCounted` class reference: https://docs.godotengine.org/en/4.6/classes/class_refcounted.html
- Godot 4.6 `Image` class reference: https://docs.godotengine.org/en/4.6/classes/class_image.html
- Godot 4.6 `ImageTexture` class reference: https://docs.godotengine.org/en/4.6/classes/class_imagetexture.html
- Godot 4.6 `Curve3D` class reference: https://docs.godotengine.org/en/4.6/classes/class_curve3d.html
- Godot stable `Callable` class reference: https://docs.godotengine.org/en/stable/classes/class_callable.html
- Godot stable GDScript reference, `await` coroutines: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#awaiting-signals-or-coroutines
- Godot stable `@GlobalScope` class reference: https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html
- Godot stable `ImageTexture` class reference: https://docs.godotengine.org/en/stable/classes/class_imagetexture.html
- Godot 4.6 `ResourceSaver` class reference: https://docs.godotengine.org/en/4.6/classes/class_resourcesaver.html
- Godot latest GDScript reference, static functions: https://docs.godotengine.org/en/latest/tutorials/scripting/gdscript/gdscript_basics.html#static-functions
- Godot latest `Dictionary` class reference: https://docs.godotengine.org/en/latest/classes/class_dictionary.html
- Godot latest `RefCounted` class reference: https://docs.godotengine.org/en/latest/classes/class_refcounted.html
