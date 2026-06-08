# Research: River Ripples

## Purpose

This research records the design evidence needed to turn the runtime ripple roadmap into a safe Waterways feature. It should unlock decisions about no-readback feedback rendering, coordinate mapping, river boundary masking, material ownership, debug parity, and whether ripple nodes become public add-on types.

Use `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index for river behavior, hydrology, flow maps, shader-water references, and production examples. Update that file when new external sources inform this feature.

## Current Research Outcome

Keep this short once research has produced a direction.

- Status: In progress; standalone feedback ownership, spread/decay, 128/256/512 analysis, axis-aligned `world_to_ripple_uv` marker mapping, mesh-footprint boundary masking, RiverManager-facing material ownership/restore, built-in river shader neutral-path behavior, helper-level shader sampling budget, minimal visible normal blending, revised demo review-scene diagnostic/performance-fixture behavior, debug parity, current shader-cost behavior, reusable field/emitter lifecycle, current field/emitter dispatch performance, Mobile/Compatibility renderer coverage, named Add Node parser/editor-cache behavior, human-visible Add Node visibility, Phase 9 authoring/API research plan, Phase 9 script/resource authoring implementation, human-visible Phase 9 editor authoring workflow, Phase 10 inspector/apply/capture-save implementation, Phase 10 visual gizmo helper implementation plus human-visible review, and the first Phase 10 emitter handle implementation are validated or documented.
- Recommendation: Keep the visual-only GPU feedback path and registered `WaterRippleField`/`WaterRippleEmitter` workflow. Treat Phase 9 as accepted script/resource-first authoring: ordinary export grouping, warning cleanup, type-specific value-mutating presets, built-in starter factories, separate field/emitter preset resources, hidden reserved controls, Add Node visibility, and scratch reload checks are now console-proven and human-visible accepted. Use `phase10-editor-polish-plan.md` for editor-only tooling. The current implemented Phase 10 surface now includes accepted non-mutating field/emitter gizmos for bounds, field footprint, target routes, emitter radius, moving threshold, and emitter-to-field route; practical human-visible emitter radius/moving-threshold handle behavior; and automated field `world_bounds` face handles. Field `world_bounds` handles still need human-visible review. Boundary texture previews, `debug_visible` re-exposure, and live-scene bridge work still need separate validation. Do not treat either plan as visual tuning; keep `refraction_strength` and `displacement_strength` reserved/hidden from normal authoring until a separate tuning pass is accepted.
- Confidence: Medium-high for the architecture; medium-high for Godot 4.6.3 Forward+/Mobile/Compatibility standalone feedback, mesh-footprint boundary masking, RiverManager-facing material ownership, built-in shader neutral path, helper-level shader sample budget, minimal visible normal render behavior, revised review-scene diagnostic/performance-fixture behavior, human-visible base-flow/ring-motion acceptance, debug parity, current shader-cost behavior, field/emitter lifecycle, current field/emitter dispatch performance, human-visible field/emitter demo workflow/stop-reload cleanup, named Add Node parser/editor-cache behavior, human-visible Add Node visibility, Phase 9 script/resource authoring implementation, Phase 9 visible editor authoring workflow, Phase 10 inspector/apply/capture-save implementation, Phase 10 visual gizmo helper implementation plus visible review, and automated Phase 10 emitter handle validation; medium for human-visible handle interaction, future field bounds handles, boundary previews, and live-scene bridge details.
- Biggest unknown that remains: Response/refraction/displacement tuning plus future Phase 10 editor work beyond first emitter handles. Human-visible handle review, field bounds handles, boundary previews, `debug_visible` re-exposure, and live-scene commands remain unimplemented.
- Decision or plan section this research unlocked: `plan.md` "Phase 9 Authoring Planning Direction", `phase9-authoring-api-plan.md`, and `phase10-editor-polish-plan.md`.

## Questions

- What are we trying to learn?
  - Whether Waterways can run a transient ripple feedback simulation as a runtime visual overlay without disturbing baked flow architecture.
- What assumptions need verification?
  - Godot viewport feedback can run safely with ping-pong targets.
  - Texture precision is sufficient at practical resolutions.
  - River shader world positions can be mapped into ripple field UVs consistently.
  - Mesh-footprint boundary masking can be generated in the same coordinate space.
  - Runtime material uniforms can be applied and restored without cross-talk.
- What user or agent premise might be wrong, incomplete, or based on missing scene/data context?
  - Treating visible ripple rings as flow or buoyancy behavior.
  - Treating a rectangular debug field as proof of river-ready masking.
  - Treating existing bake UV2 atlas textures as direct world-space masks.
- What Godot 4.6+ constraints could change the design?
  - `SubViewport` update mode, clear mode, texture precision, texture feedback hazards, shader uniform support, and renderer-specific behavior.
- Which parts are editor-only, runtime-only, or shared?
  - Runtime-only: simulation, impulse rendering, texture feedback, emitter impulses, target uniforms.
  - Editor-only: custom type icons, editor inspector/plugin UI, transient preset selectors, editor undo/redo integration, editor save dialogs, editor helper previews, validation UI.
  - Shared: saved field configuration if nodes become public scene nodes.
- What legacy Waterways behavior should be preserved, changed, or removed?
  - Preserve baked flow and WaterSystem behavior.
  - Do not preserve or rely on legacy Godot 3 APIs.

## Phase 9 Authoring Research Outcome

The Phase 9 research pass compared Unity HDRP Water, Unreal Water/Niagara Fluids, Crest dynamic waves/foam, Godot compute texture examples, Waterways lineage, and AAA baked/procedural water references.

Key outcome:

- Keep the current `SubViewport` field/emitter architecture for Phase 9 because it is already proven across Forward+, Mobile, and Compatibility.
- Treat `WaterRippleField` as the simulation domain, target ownership, boundary-mask, performance, and debug surface.
- Treat `WaterRippleEmitter` as an authorable source of point/ring impulses now and deformer-like stamps later.
- Use `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources for reusable type-specific values, not runtime textures; Phase 9 uses explicit in-memory apply/capture methods and script-callable starter factories, while editor asset saving belongs to Phase 10 or later editor tooling.
- Keep foam as a later separate influence layer rather than overloading ripple strength or color.
- Borrow the authoring vocabulary of deformers, decals, masks, generators, and settings assets, but adapt it to Godot scene nodes and Waterways' visual-only scope.
- Define presets as one-click starting points that mutate ordinary editable values and remain inspectable/editable after application.
- Keep `refraction_strength` and `displacement_strength` reserved/hidden from normal authoring until a separate visual tuning plan.

The detailed contract is in `phase9-authoring-api-plan.md`.

## Phase 10 Editor Polish Research Outcome

The Phase 10 planning pass keeps the industry authoring goal from Unity/Unreal-style water tools but adapts it to Godot's edited-scene/runtime split.

Key outcome:

- Use editor/plugin code for native inspector polish, not runtime field/emitter scripts or preset resources.
- Start with read-only status UI that inspects exported values, configuration warnings, or safe snapshots only.
- Treat preset resource pickers as transient action inputs. They must not become exported node slots, serialized resource paths, live profile links, or auto-apply flags.
- Apply presets in editor UI through one grouped per-property undo action using the Phase 9 whitelist; skip no-op applies and do not call runtime `apply_preset()` as the editor undo do-method.
- Keep capture non-mutating and scratch-only until the user chooses an explicit editor save path.
- Keep `ResourceSaver` use in editor/plugin code only; runtime scripts and preset resources must not gain save helpers or `.tres` write paths.
- Defer `Reset Feedback`, `Rebuild Runtime`, `Emit Once`, runtime texture previews, and any command that depends on runtime `SubViewport` state until a live-scene bridge is separately designed.
- Re-expose or rename `debug_visible` only when there is real visible helper behavior plus cleanup, undo/dirty-state, and export-boundary validation.
- Register non-mutating 3D gizmos through `EditorPlugin.add_node_3d_gizmo_plugin()`, keep line-generation logic probeable outside the editor-only class, and add editable handles only after handle edits have documented undo/dirty-state coverage.

The detailed contract is in `phase10-editor-polish-plan.md`.

## Flow-Map and Water Tool Patterns

Comparable water systems often layer small surface detail over stable authored flow:

- Baked flow maps provide direction and broad motion.
- Runtime disturbance textures provide transient local detail.
- Normal and refraction modulation can create convincing interaction without changing physics.
- Boundary masks are required when a simulation domain is rectangular but the water body is not.
- Runtime systems need explicit ownership of transient textures and material parameters.

Waterways fit:

- Existing river shaders already combine baked flow, animated normals, foam, pillows, wakes, and eddy-line turbulence.
- Runtime ripples should join this as another surface detail layer, not as a new source of final flow.
- The project already has shader-pass infrastructure through `SubViewport`, but the current renderers are bake-oriented and use CPU readback, so they are only partial evidence.

## Godot 4.6+ Findings

Record relevant Godot 4.6+ assumptions, APIs, limitations, rendering behavior, import behavior, editor/runtime differences, and community practices here as implementation research proceeds.

Current local findings from the roadmap:

- `filter_renderer.gd` and `system_map_renderer.gd` prove shader passes through `SubViewport` are available.
- Existing bake paths use `SubViewport.UPDATE_ONCE`, wait frames, call `get_image()`, and store textures.
- Runtime ripple simulation needs a different path: no CPU readback during normal runtime and no sampling from the active write target.
- Official Godot 4.6 `SubViewport` docs say `UPDATE_ONCE` updates the render target once, then switches to disabled; manual validation and feedback passes should request the update and wait frames deliberately.
- Official Godot 4.6 `EditorPlugin.add_custom_type()` docs say plugin custom types appear in node/resource lists as base objects with scripts, but the official custom-node tutorial shows `@icon(...)` plus `class_name` as the direct Add Node registration path. Human-visible inspection did not show the plugin-only ripple registrations, so the ripple nodes now use `class_name` and were confirmed in `.godot/global_script_class_cache.cfg` after a headless editor scan.
- Official Godot 4.6 viewport docs confirm `SubViewport` content is accessed through the viewport texture returned by `get_texture()`.
- Official Godot 4.6 `Node` docs define `_enter_tree()`, `_ready()`, and `_exit_tree()` lifecycle order; the field/emitter path uses runtime setup/cleanup around `_ready()`/`_exit_tree()` and avoids relying on editor-time preview side effects.
- Official Godot 4.6 `ViewportTexture` docs describe viewport textures as scene-local dynamic textures; the field owns `SubViewport` nodes and passes their runtime textures to materials instead of saving or mutating bake resources.
- Official Godot 4.6 `Resource` docs describe duplication and scene-local resource behavior; this reinforces keeping transient viewport/material state owned by the field/RiverManager runtime path rather than editing shared source resources directly.
- Official Godot 4.6 editor-tool docs caution that `@tool` scripts run in the editor; the field and emitter keep simulation/emission disabled under `Engine.is_editor_hint()` and use warnings for authoring feedback.
- Official Godot 4.6 `EditorNode3DGizmoPlugin` docs identify `_has_gizmo()` and `_redraw()` as the simple custom gizmo path, with registration through `EditorPlugin.add_node_3d_gizmo_plugin()`. They also document handle callbacks: `_get_handle_value()` supplies restore data, `_set_handle()` handles live dragging, and `_commit_handle()` receives cancel/commit state. The first handle slice follows that model and routes committed mutations through editor undo.
- Official Godot 4.6 `EditorNode3DGizmo` docs define `add_lines()`, `add_collision_segments()`, and editable `add_handles()` behavior. The ripple helper uses lines/collision for visualization and now uses handles only for the automated-proven emitter radius/moving-threshold properties.
- Official Godot 4.6 `Node3D` docs list `update_gizmos()` and local/global conversion helpers; the first gizmo slice uses local line coordinates and keeps future refresh hooks available if helper-visible exported properties are later added.
- Official Godot 4.6 CanvasItem shader docs define `UV` as normalized texture coordinates and `FRAGCOORD.xy` as pixel-center viewport coordinates; the standalone shaders should stay on these documented built-ins instead of ad hoc vertex-derived UVs.
- Official Godot screen-reading docs warn that `hint_screen_texture` relies on back-buffer copying behavior; ripple feedback should continue using explicit `ViewportTexture` ping-pong targets instead.
- Official Godot shader-language docs confirm regular shader uniforms can declare defaults and sampler hints, and that `Transform3D` maps to `mat4` when set from GDScript; they also note per-instance uniforms cannot be textures, so the current runtime texture path remains material-parameter based rather than instance-uniform based.
- Official Godot `ShaderMaterial` docs confirm shader parameter names are case-sensitive, `set_shader_parameter()`/`get_shader_parameter()` are the runtime material API, and shared materials require per-instance uniforms or material duplication to avoid cross-instance changes; this supports the RiverManager duplicate-before-runtime-write path.
- Official Godot 4.6 spatial shader docs confirm fragment `VERTEX` is view-space, `INV_VIEW_MATRIX` maps view to world, `CAMERA_POSITION_WORLD` is available in fragment scope, and `NORMAL_MAP` is tangent-space output. Local shader validation showed these built-ins should be passed into helper functions instead of read directly from global helper scope.
- Official Godot 4.6 shader built-in function docs confirm `textureSize()` and `textureLod()` are available for the guarded helper/sample-budget path.
- Official Godot 4.6 `RenderingServer` docs confirm per-viewport CPU/GPU render-time measurement is available through `viewport_set_measure_render_time()`, `viewport_get_measured_render_time_cpu()`, and `viewport_get_measured_render_time_gpu()`, and that per-viewport draw-call info is available after frames have rendered.
- Official Godot 4.6 `Time` docs confirm `get_ticks_usec()` is monotonic and appropriate for precise elapsed-time measurement; the shader-cost probe records wall-clock frame waits only as secondary context and uses `RenderingServer` timing for the pass criteria.
- Local probe finding: manual-mode validation must not let `_process()` clear the impulse texture while `auto_step` is disabled. The first failing analysis run exposed this by showing a blank impulse despite valid render-target ownership.
- Local probe result: `RIPPLE_FEEDBACK_ANALYSIS_OK` proves fixed impulse response, outward ring-band energy, decay, and no saturation at 128, 256, and 512 in Godot 4.6.3 Forward+.
- Local probe result: `RIPPLE_MAPPING_PROBE_OK` proves the standalone axis-aligned X/Z `world_to_ripple_uv` transform maps four fixed world-space markers to expected UVs, and the probe-only shader renders texture impulses at those same positions in Godot 4.6.3 Forward+.
- Local probe result: `RIPPLE_BOUNDARY_MASK_PROBE_OK` proves a generated Waterways river mesh footprint can be transformed through the same `world_to_ripple_uv`, rendered into a boundary mask, sampled against water/dry points, and fed into the standalone feedback path so dry impulses and close cross-bank leakage are rejected.
- Local probe result: `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK` proves the built-in river shader declares planned neutral `i_ripple_*` uniforms and remains pixel-identical to baseline when ripples are disabled, when the simulation texture is missing, and when the boundary texture is missing.
- Local probe finding: The standalone mapping and boundary probes treat `world_to_ripple_uv` as world X/Z to ripple U/V. The first river helper used mapped X/Y; this would pin flat river fragments to one texture row, so `river.gdshader` now samples mapped X/Z and the sampling probe checks for that contract.
- Local probe result: `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK` proves the visible normal river shader slice compiles, calls `ripple_normal_offset_at_world()` once from `fragment()`, keeps direct height sampling out of `fragment()`, keeps `ripple_height_at_uv()` to one simulation sample plus one boundary-mask helper call, and keeps `ripple_normal_offset_at_uv()` to three simulation samples plus one boundary-mask helper call.
- Local probe result: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK` proves disabled, flat, and black-boundary cases stay pixel-identical while an enabled wave texture visibly changes rendered normal response in Godot 4.6.3 Forward+.
- Local probe result: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK` proves the demo-backed visible review scene can load `Demo.tscn`, start on the close-overhead inspection camera, apply runtime ripple state to the existing river through RiverManager, toggle it off/on, and restore runtime material state on free.
- Local diagnostic result: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK` diagnosed the previous no-visible-ripples review failure as fixture readability rather than material ownership. Later human reviews caught that the readability fix froze base flow, used a static texture, then caused a harsh enabled-framerate drop from playback-time 256x256 GDScript image generation/upload. The revised scene now clusters annular centers, focuses the camera on actual selected water positions, preserves demo material motion, precomputes 48 annular review frames once, swaps texture references during playback, confirms mesh tangents, and shows a visible enabled-vs-zero-strength delta in validation-only captures. Human rerun confirmed the precomputed-frame fix greatly improved enabled-ripple framerate, the river keeps moving, and rings expand outward.
- Local probe result: `RIPPLE_DEBUG_PARITY_PROBE_OK` proves the selected debug parity path: `river_debug.gdshader` exposes raw ripple height, impulse/contact, boundary mask, and visible influence modes; the debug menu lists those modes; RiverManager applies the additional impulse/contact texture to duplicated runtime materials; switching visible/debug modes preserves texture state; and the demo-backed review scene can switch 0/4/5/6/7 without resetting the animated runtime ripple texture.
- Local probe result: `RIPPLE_SHADER_COST_PROBE_OK` proves the current shader-cost gate in Godot 4.6.3 Forward+ on an AMD Radeon RX 6800 XT. Static checks found disabled-ready and visible-fragment direct ripple samples at `0`, one visible helper call from `fragment()`, and the accepted enabled-normal budget of three simulation samples plus one boundary helper call. The latest controlled 640x360 median GPU timings were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`, and debug raw/contact/boundary/influence `0.115/0.118/0.117/0.129 ms`, all with one draw call. Debug timings are inspection-tool evidence, not visual tuning targets.
- Local probe result: `RIPPLE_FIELD_EMITTER_PROBE_OK` proves the current field/emitter lifecycle gate in Godot 4.6.3 Forward+. The field initializes distinct read/write/impulse/boundary viewports and textures, generates a target river mesh-footprint boundary mask, applies material state to the intended river through RiverManager, accepts world-space emitter impulses, caps/sorts emitters, rejects out-of-bounds impulses, avoids normal-runtime readback, and clears material state on disable/free.
- Local probe result: `RIPPLE_FIELD_EMITTER_PROBE_OK` and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` still pass after switching `WaterRippleField` canvas `SubViewport` targets to transparent zero clear. This matters because the human-visible field/emitter review showed impulse/contact blue everywhere, raw height flat/nonlocal, visible influence black, and no visible rings. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK` found the impulse texture had a nonzero full-field background (`min=0.30196`) before the fix and a localized background after it (`min=0.0`, `mean=0.000208`, `changed_count=118`) with blue/green/orange emitter samples present.
- Local probe result: `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` proves the current Forward+ field/emitter dispatch sweep after transparent-zero viewport clearing. Dispatch medians for 0/4/16 emitters were `5.477/6.059/5.704 ms` at 128, `6.405/5.650/5.521 ms` at 256, and `5.754/5.508/5.377 ms` at 512 on Godot 4.6.3 Forward+ / AMD Radeon RX 6800 XT.
- Local regression result: After splitting the additive runtime impulse shader from the standalone feedback-analysis impulse shader, `RIPPLE_FEEDBACK_ANALYSIS_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK` all still passed. The latest shader-cost medians were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`, and debug raw/contact/boundary/influence `0.115/0.118/0.117/0.129 ms`.
- Local probe result: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` first proved the Phase 10 visual gizmo helper slice. `ripple_gizmo.gd` is registered and removed by `plugin.gd`; `ripple_gizmo_geometry.gd` builds probeable line segments without editor-only classes or runtime calls. At that visual-only point the probe validated field bounds (`24` segment points), field footprint (`12`), explicit target route (`2`), emitter radius (`128`), moving threshold (`64` dashed points), emitter route (`2`), no preview children, no exported-value mutation, and no runtime editor-class/save-path leakage. The later emitter handle slice is recorded below.
- User-visible review result: Phase 10 visual gizmo helpers are accepted for that visual-only contract. User confirmed field box/footprint/route helpers and emitter radius/moving/route helpers were readable, viewing only did not prompt for unsaved scene changes, and Output showed no errors.
- Local probe result: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` also proves the first Phase 10 emitter handle slice. `ripple_gizmo_handle_model.gd` maps stable handle IDs to `radius` and `moving_emit_distance`, clamps values to `0.001..64.0`, and reports no-op diffs. `ripple_gizmo_geometry.gd` exposes probeable handle positions. `ripple_gizmo.gd` uses `EditorUndoRedoManager` for committed handle edits. The probe validates moving emitters expose two handles, non-moving emitters expose one radius handle, no preview children are added, no exported values mutate while building helpers, no forbidden runtime calls appear, and runtime scripts/preset resources remain free of editor-only references.
- Local probe result: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` now proves the Phase 10 field `world_bounds` handle slice. `ripple_gizmo_handle_model.gd` exposes stable field face IDs `2001..2006`, maps them only to `world_bounds`, preserves opposite faces, clamps before flipping below the minimum size, and reports no-op diffs. `ripple_gizmo_geometry.gd` exposes six face-center handle positions. `ripple_gizmo.gd` projects field drags along world X/Y/Z axes and commits one editor undo action for the `world_bounds` AABB.

Items still needing verification:

- Pause/resume behavior beyond the current fixed update-rate prototype.
- Human-visible editor review for the new field `world_bounds` handles.
- Future Phase 10 boundary previews, `debug_visible` re-exposure, and live-scene bridge work after the accepted Phase 9 contract and Phase 10 plan.
- Human-visible editor scene reload/authoring behavior after any future authoring API changes.
- Future response/refraction/displacement tuning behavior.

## Legacy Waterways Reference

Use this section when the feature needs to preserve or intentionally change behavior from the Godot 3 add-on.

- Relevant legacy files: None identified for first-pass ripples.
- Behavior to preserve:
  - The active Godot 4.6+ add-on's baked river architecture and existing accepted visual baselines.
- Behavior to change:
  - Add optional runtime visual surface detail.
- Obsolete APIs to avoid:
  - Any Godot 3-only viewport, material, or plugin APIs.
- Risks discovered in `audit/code-audit.md`:
  - Not checked yet for ripple-specific implementation.
- What belongs in active Godot 4.6+ code:
  - Runtime-safe field, emitter, shader, RiverManager adapter, and debug support.
- What should remain legacy-only:
  - Any obsolete Godot 3 editor/runtime patterns.

## Options

### Option A: Runtime Visual Ripple Overlay

- Benefits:
  - Fits Waterways' separation between baked flow and surface detail.
  - Avoids source-signature and WaterSystem churn.
  - Can be prototyped in risk order.
  - Keeps first milestone useful for demos and user projects.
- Costs:
  - Requires new runtime feedback infrastructure.
  - Requires careful material ownership and cleanup.
  - Requires debug parity beyond ordinary shader output.
- Risks:
  - Viewport feedback may expose Godot-specific timing or precision issues.
  - Shader cost may be too high if integration is careless.
- Fit for Waterways:
  - Best first path.

### Option B: Bake Ripple Data Into River Resources

- Benefits:
  - Saved resources would be deterministic and inspectable.
  - Existing bake infrastructure could store outputs.
- Costs:
  - Does not satisfy runtime emitter interaction.
  - Blurs transient visual state with authored river data.
  - Requires source signatures and stale-resource handling.
- Risks:
  - Could corrupt the add-on's clean separation of baked flow and runtime visual detail.
- Fit for Waterways:
  - Not appropriate for the first ripple milestone.

### Option C: Physics-Facing Ripple Simulation

- Benefits:
  - Visible rings and object behavior could eventually agree.
  - Could support advanced gameplay and buoyancy effects.
- Costs:
  - Requires runtime sampling semantics, WaterSystem alignment, determinism decisions, and validation with moving objects.
  - Much larger scope.
- Risks:
  - Visible water and physics can diverge if planned casually.
  - Saved bakes and transient state can become confusing.
- Fit for Waterways:
  - Future work only after visual layer is accepted.

## Recommendation

Use Option A first. Build a standalone no-readback runtime visual ripple field, prove coordinate mapping and mesh-footprint boundary masking, prove material ownership/restore behavior, then add a minimal river shader normal overlay through a controlled runtime material API.

Do not implement physics-facing behavior, flow changes, or saved ripple data until the visual layer has been accepted and a separate milestone defines how visible state, runtime sampling, WaterSystem data, and validation should agree.

## Risks and Unknowns

- Godot viewport feedback timing may differ between editor, F6, and exported builds.
- Texture precision may be too low for stable decay if ordinary color formats are used.
- Mapping bugs can be subtle unless world-space markers and debug texture markers are compared directly.
- Boundary masks can look correct in one view while still letting waves leak across dry areas.
- Material ownership bugs can affect unrelated rivers.
- Debug material switching can hide runtime ripple uniforms.
- Shader sample cost can regress an already complex river material.
- Public node registration can imply API stability before the design is proven.
- Editor inspector polish can accidentally mutate runtime state, dirty edited scenes, or serialize hidden preset dependencies if it is implemented as ordinary runtime methods instead of editor-owned actions.

## Context Challenge Notes

Record any evidence that the reported issue may be expected behavior, stale data, validation-scene setup, user misunderstanding, or an agent assumption error.

- Possible misread context:
  - User or agent expects visual ripples to move objects or alter downstream current.
- Evidence:
  - The roadmap explicitly scopes first-pass ripples as visual-only and transient.
- Confidence:
  - High.
- Quick check before patching:
  - Ask whether the requested behavior is surface appearance only or physics-facing object behavior.
- User-facing note or question to raise:
  - "This first ripple feature is visual-only; object drift or buoyancy changes need a separate physics-facing plan so visible and runtime behavior do not diverge."

## Sources

- `addons/waterways/docs/roadmaps/runtime-ripple-simulation-roadmap.md`: primary roadmap for this feature folder.
- `addons/waterways/docs/spec-driven/features/river-ripples/phase9-authoring-api-plan.md`: Phase 9 script/resource-first authoring/API contract produced from the industry research pass and adversarial review.
- `addons/waterways/docs/spec-driven/features/river-ripples/phase10-editor-polish-plan.md`: Deferred native editor polish plan for inspector buttons, undo-aware actions, save dialogs, and editor-safe preview helpers.
- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index for Waterways river behavior, hydrology, flow-map, shader-water, and production-reference sources.
- `addons/waterways/docs/spec-driven/00-constitution.md`: project-level development constraints.
- `addons/waterways/docs/spec-driven/01-workflow.md`: feature-folder workflow and handoff naming convention.
- `https://github.com/CBerry22/Godot-Water-Ripple-Simulation-Shader`: algorithmic inspiration named by the roadmap; do not copy code unless licensing is clarified.
- `https://docs.godotengine.org/en/4.6/classes/class_subviewport.html`: official `SubViewport` update and clear-mode semantics.
- `https://docs.godotengine.org/en/4.6/tutorials/rendering/viewports.html`: official `SubViewport` render-target and `get_texture()` usage.
- `https://docs.godotengine.org/en/4.6/classes/class_node.html`: official node lifecycle reference for `_ready()`, `_exit_tree()`, setup, and cleanup.
- `https://docs.godotengine.org/en/4.6/classes/class_viewporttexture.html`: official dynamic viewport texture reference for runtime `SubViewport` texture ownership.
- `https://docs.godotengine.org/en/4.6/classes/class_resource.html`: official resource duplication/local-to-scene reference for avoiding shared-resource mutation.
- `https://docs.godotengine.org/en/4.6/tutorials/plugins/running_code_in_the_editor.html`: official editor `@tool` boundary reference for avoiding editor-time runtime simulation side effects.
- `https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html`: official CanvasItem shader coordinate semantics.
- `https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html`: official screen/back-buffer behavior to avoid for explicit feedback targets.
- `https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html`: official spatial shader built-ins and output semantics for fragment world-position and future normal-map blending.
- `https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shading_language.html`: official shader uniform, sampler, and per-instance uniform constraints used for runtime ripple uniform decisions.
- `https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shader_functions.html`: official texture sampling and size functions used by the helper guard and sample-budget probe.
- `https://docs.godotengine.org/en/4.6/classes/class_shadermaterial.html`: official `ShaderMaterial` parameter and material-sharing guidance used for debug parity/material ownership work.
- `https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html`: official per-viewport CPU/GPU render-time and draw-call measurement API used by `ripple_shader_cost_probe.gd`.
- `https://docs.godotengine.org/en/4.6/classes/class_time.html`: official monotonic timing reference used for secondary wall-clock measurement in the shader-cost probe.
