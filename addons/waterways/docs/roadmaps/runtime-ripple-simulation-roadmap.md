# Runtime Ripple Simulation Roadmap

This roadmap describes how to adapt the ideas from `CBerry22/Godot-Water-Ripple-Simulation-Shader` into Waterways without disturbing the add-on's baked river-flow architecture.

The guiding decision remains: start with an optional runtime visual ripple layer. Do not treat ripples as final flow, buoyancy flow, eddy circulation, or saved WaterSystem data until a later milestone explicitly scopes that work.

This revision folds in an adversarial engineering review against the current Waterways add-on architecture. The main change is that the first implementation milestone must prove the hard parts before it hardens the user-facing node API: no-readback feedback rendering, one explicit world-space mapping contract, target-river boundary masking, material ownership and restore behavior, debug parity, add-on registration, and shader cost.

## Goals

- Add localized water-surface disturbance from ducks, boats, players, rain, falling objects, or scripted emitters.
- Keep Waterways' baked river data stable: flow, foam, pressure, obstacle, terrain-contact, bank-response, and WaterSystem maps remain authoritative for authored river behavior.
- Let ripples enrich visible water normals, refraction, and optional close-range displacement without changing current direction or physics.
- Make the first version useful in the demo scene, but general enough for user projects.
- Preserve the accepted pillow, wake, and eddy-line visual baselines.
- Avoid copying code from the inspiration repo unless licensing is clarified; reimplement the technique in Waterways style.
- Keep the runtime simulation transient unless a future milestone explicitly defines persistence.

## Non-Goals

- No full shallow-water simulation for the whole river.
- No replacement for Waterways' spline, bake, flow-map, or WaterSystem workflows.
- No new source-signature bump for the first visual-only pass.
- No saved river bake changes for visual ripples.
- No WaterSystem regeneration for visual ripples.
- No buoyancy, object drift, reverse-flow, or eddy-circulation changes until a separate physics-facing milestone.
- No runtime texture readback in normal rendering or in the ripple simulation loop.
- No same-texture read/write feedback shortcut unless a Godot-specific spike proves it is stable and portable.
- No hidden edits to shared river materials that affect unrelated rivers.
- No river shader integration before material ownership, coordinate mapping, and boundary-mask generation are chosen.
- No claim of debug parity unless the raw ripple texture, impulse texture, boundary mask, and visible river influence are inspectable.

## Current Fit

The reference project uses a compact feedback simulation:

1. A `canvas_item` shader samples the previous simulation texture.
2. It computes a damped wave step from neighboring pixels.
3. It reads a collision/impulse texture to add or remove disturbance.
4. A water material samples the simulation texture for vertex displacement, normals, refraction, depth color, and alpha.

Waterways already has compatible concepts:

- `river.gdshader` already layers animated normals, refraction, foam, pillows, wakes, eddy-line turbulence, and optional pillow displacement.
- The bake data model already separates stable authored fields from runtime shader detail.
- The docs already distinguish surface-only visual effects from final-flow and WaterSystem/physics changes.
- `filter_renderer.gd` proves shader passes through `SubViewport` are available in the project.

The important mismatch:

- `filter_renderer.gd` is bake-oriented. It uses `SubViewport.UPDATE_ONCE`, waits frames, reads the viewport image back to the CPU, and stores generated textures. That is not enough proof for a runtime feedback simulation.
- The reference project is a live feedback simulation, while Waterways' core river behavior is baked and saved.
- Therefore, the ripple system should begin as a runtime node and shader overlay, but only after the render-feedback path and coordinate mapping are proven.

## Hard Constraints

These constraints are acceptance gates, not polish:

- Visual-only first: ripple texture data must not alter `flow`, `flow_force`, `i_flowmap`, WaterSystem data, buoyancy, or saved bakes.
- No readback loop: the simulation must stay on the GPU during normal runtime.
- Explicit feedback ownership: use ping-pong viewports/textures or another proven feedback path. Do not sample from the texture currently being rendered into.
- Explicit coordinate contract: the same world-to-ripple mapping must be used by emitters, the simulation, debug views, and `river.gdshader`.
- Boundary handling before river overlay: the simulation can be rectangular for a standalone debug quad, but it must have a water/bank boundary strategy before it is blended into visible rivers.
- Material ownership before river touch: runtime parameters must target the intended river instance only, and unregistering or disabling must restore predictable material state.
- Shader cost budget before river touch: adding ripple samples to `river.gdshader` must be measured against the existing heavy normal/foam/wake/refraction path.
- Debug parity before acceptance: any final visible shader integration must be inspectable through `river_debug.gdshader`, a `WaterRippleField` debug view, or a targeted probe.
- Add-on registration is part of the feature if the ripple nodes are built-in Waterways nodes. If they are not registered through `plugin.gd`, they are example/prototype nodes only.

## Architecture Proposal

### New Runtime Node

Add a `WaterRippleField` node under `addons/waterways/`, probably as `water_ripple_field.gd` plus a scene file.

Responsibilities:

- Own the ripple simulation textures or viewports.
- Own the impulse texture or impulse-rendering path.
- Run the feedback simulation without CPU readback.
- Convert emitter world positions into ripple-field UVs.
- Generate or consume a boundary mask before river integration.
- Expose the current ripple texture to target river instances.
- Keep runtime state transient unless normal scene configuration is explicitly saved.
- Cleanly restore target material state on disable, unregister, and scene unload.

Suggested public properties:

- `enabled`
- `resolution`
- `world_transform` or `world_bounds`
- `target_group_name` or explicit target river list
- `ripple_strength`
- `normal_strength`
- `refraction_strength`
- `displacement_strength`
- `damping`
- `propagation`
- `simulation_update_rate`
- `max_emitters`
- `follow_camera`
- `debug_visible`

Design decisions that must be made before implementation:

- Use one shader/GDScript coordinate contract: a `Transform3D world_to_ripple_uv` that maps world position to `(u, height, v)`.
- `world_bounds` can be a convenience input only if it generates the same `world_to_ripple_uv` transform. Do not maintain a separate bounds-based shader path.
- Axis-aligned X/Z bounds match the current WaterSystem sampling style. Rotated or non-uniformly scaled fields require the full transform path and explicit tests.
- `follow_camera` waits until reprojection, clear-on-shift, or tile swapping is designed. Otherwise it will create sliding or popping ripple history.
- `target_group_name` is convenient, but explicit registration must exist so multiple rivers do not accidentally share one runtime texture.
- First built-in implementation should use a RiverManager-facing runtime API that applies and clears only `i_ripple_*` uniforms on intended generated river targets.

### Coordinate Contract

The ripple feature must not mix independent mapping schemes. Waterways' current river shader samples baked data through padded UV2 atlas coordinates, while WaterSystem samples runtime flow through an axis-aligned world-to-map transform. Runtime ripples should use the WaterSystem-style idea, but with a single explicit `Transform3D`.

First contract:

- GDScript stores and validates `world_to_ripple_uv`.
- Emitters map world positions by `world_to_ripple_uv * global_position`.
- The simulation and debug overlay use `uv = mapped_position.xz`.
- `river.gdshader` computes world position and applies the same `i_ripple_world_to_uv` uniform.
- UV outside `[0, 1]` is rejected or edge-faded.
- Height/Y in the mapped position is reserved for later height fade or diagnostics, not for physics.

Do not pass both `i_ripple_world_to_uv` and separate min/size uniforms unless the extra uniforms are debug-only mirrors. Duplicated mapping inputs invite drift.

### Runtime Feedback Path

The existing `filter_renderer.gd` and `system_map_renderer.gd` prove that shader passes can run through `SubViewport`, but they are bake paths: they use `UPDATE_ONCE`, wait frames, call `get_image()`, and store textures. Runtime ripples need a different path.

First feedback path must specify:

- two separate render targets for ping-pong feedback
- which viewport is read this frame and which viewport is written this frame
- clear mode and update mode
- texture precision/color format or a documented fallback if Godot exposes no configurable format for the chosen path
- impulse texture lifetime and clear behavior
- pause/resume and scene-reload behavior
- no CPU readback in normal runtime

### Ripple Simulation Shader

Add a Waterways-owned shader inspired by the reference algorithm, not copied verbatim.

Suggested file:

- `addons/waterways/shaders/runtime/ripple_simulation.gdshader`

Inputs:

- previous ripple texture
- impulse texture
- damping
- propagation strength
- texel size
- boundary mask
- optional clear/fade mask
- optional flow advection bias in a later phase

Suggested channel layout:

- `r`: current height
- `g`: previous height or velocity-like memory
- `b`: impulse/contact memory or boundary diagnostic
- `a`: optional age, confidence, or unused value

First version should keep it simple:

- no flow advection
- no physics export
- no readback
- no saved bake/resource mutation
- no displacement by default

### Impulse Input

Add a small emitter path.

Possible first version:

- `WaterRippleEmitter` node with radius, intensity, falloff, mode, and optional pulse rate.
- The ripple field gathers active emitters each frame or on a fixed update.
- A `SubViewport` or draw-list path renders circles or simple sprites into an impulse texture.
- Emitters can be attached to ducks, player objects, boats, or placed as test points.
- The impulse render path must use the same world-to-ripple mapping as the river shader overlay.

Later version:

- automatic impulse from buoyant objects crossing the surface
- rain impulse batches
- scripted splashes
- editor preview emitters
- velocity-scaled impulse trails

### River Shader Integration

Add internal uniforms to `river.gdshader` rather than exposing all runtime plumbing as user-facing material controls:

- `i_ripple_enabled`
- `i_ripple_simulation_texture`
- `i_ripple_world_to_uv`
- `i_ripple_boundary_mask`
- `i_ripple_texel_size`
- `i_ripple_normal_strength`
- `i_ripple_refraction_strength`
- `i_ripple_displacement_strength`
- `i_ripple_height_fade_distance`
- `i_ripple_boundary_fade`

If shader controls are meant to be user-authored on the river material instead of the `WaterRippleField`, add a `ripple_` material category in `river_manager.gd`. Otherwise keep runtime plumbing under the `i_` prefix so the existing inspector does not expose unstable internals.

Shader behavior:

1. Compute current river fragment world position.
2. Convert world position to ripple-field UV with `i_ripple_world_to_uv`.
3. Reject or fade samples outside the field and outside the water/boundary mask.
4. Sample ripple height.
5. Derive local ripple normal from neighboring height samples.
6. Blend ripple normal into the existing `NORMAL_MAP` response without replacing flow animation.
7. Add a subtle refraction contribution only after normal integration is stable.
8. Optionally add vertex displacement at close range only, default off.

The visible shader already samples multiple baked maps, animated normal layers, foam noise, depth, and screen texture. First-pass ripple normal integration should target no more than three additional ripple texture samples in the enabled near-camera path and zero additional ripple texture samples when `i_ripple_enabled` is false.

Debug behavior:

- If `river_debug.gdshader` participates, it must declare matching `i_ripple_*` uniforms so `RiverManager` can mirror parameters from the visible material.
- If debug parity is provided by a separate `WaterRippleField` view instead, the roadmap must say that visible river debug modes will not show ripple influence yet.
- A targeted probe must verify that debug material switching does not lose or hide runtime ripple state.

First-pass integration should affect only visible surface response:

- Add to normal detail near the current `NORMAL_MAP` assignment.
- Add to refraction offset only after normal integration is stable.
- Leave `flow`, `flow_force`, `i_flowmap`, and WaterSystem data untouched.
- Keep a neutral fallback path when no ripple texture is assigned.

### Boundary Masking

Boundary masking is not optional for river integration. Without it, a rectangular simulation can propagate waves through banks, rocks, and nearby disconnected bends, then re-enter visible water from impossible directions.

Acceptable first strategies:

- First accepted strategy: render the target river mesh footprint into a ripple-field mask using the same `world_to_ripple_uv` contract.
- Fallback prototype strategy: build a coarse mask from target river bounds and width, but only for standalone debug work before visible river integration.
- Later strategy: sample existing baked water support/coverage only after a UV2-atlas-to-world mapping path is proven clean.

The baked river fields are padded UV2 atlas textures. They are not world-space ripple masks. Treating them as direct ripple masks would let a rectangular world-space simulation disagree with the river mesh footprint.

Standalone debug work can use a coarse mask, but visible river integration must use the target river mesh-footprint mask. Any accepted mask must:

- prevent wave propagation through fully dry areas
- fade at field edges
- be visible in debug view
- be regenerated or updated when the target river changes

### Material Ownership

The runtime field must not blindly mutate shared material resources. Before any river material is touched, choose one ownership path:

- Preferred first path: a RiverManager-facing API that applies and clears runtime ripple uniforms on the generated river mesh/material.
- Alternative path: per-target material duplication with explicit restore on unregister.
- Spike-only path: instance shader parameters if Godot supports the required texture and uniform types for this use case.

Acceptance depends on behavior, not only implementation style:

- two rivers can have separate ripple fields
- disabling one field does not affect unrelated rivers
- debug material behavior remains sane
- scene reload does not leave stale ripple textures assigned
- changing a river's debug view does not silently drop visible ripple state
- applying a ripple field does not dirty river bake data, source signatures, or WaterSystem metadata

### Add-On Registration

If `WaterRippleField` and `WaterRippleEmitter` are built-in Waterways nodes, update `plugin.gd` to register them as custom types and add icons. If they are not registered, keep them as prototype/example nodes and document that they are not part of the public add-on API yet.

## Phase 0: Scope, Safety, And Architecture Contracts

Goal: make the feature safe to prototype without blurring visual and physics responsibilities, and remove the high-risk architectural ambiguity before any river shader or material is touched.

Steps:

1. Confirm the first milestone is visual-only.
2. Confirm no source-signature bump is needed.
3. Confirm no river bake resources are changed.
4. Confirm no WaterSystem bake is regenerated.
5. Confirm no buoyancy or runtime flow sampling behavior changes.
6. Confirm the shared citation index already records the inspiration repo as algorithmic inspiration.
7. Choose the first demo scenario: duck ripples, click/test ripples, rain ripples, or static emitters.
8. Specify `world_to_ripple_uv` as the single GDScript/shader mapping contract.
9. Decide whether the first field supports only axis-aligned X/Z bounds or full transformed fields.
10. Choose the first boundary-mask source: target river mesh footprint rendered into ripple field space.
11. Choose the first material ownership path: RiverManager-facing runtime uniform API with explicit clear/restore.
12. Decide whether ripple nodes are built-in add-on custom types or prototype/example nodes.
13. Define debug parity for the first visible pass: `river_debug.gdshader`, separate `WaterRippleField` views, or a targeted probe.
14. Define the first river shader cost budget, including disabled-path and enabled-path sample limits.

Acceptance:

- Roadmap exists and documents visual-only boundaries.
- First demo scenario is chosen.
- `world_to_ripple_uv` is documented as the only production mapping input.
- Boundary mask source is target river mesh footprint rendering, not direct use of UV2-atlas bake textures.
- Material ownership path is selected before any river material is modified.
- Debug parity path is selected before visible shader integration.
- Add-on registration status is chosen before nodes are presented as public API.
- Initial shader sample budget is recorded.
- Known risks are tracked before implementation starts.

## Phase 1: Runtime Feedback Feasibility Spike

Goal: prove a feedback ripple texture can run in Godot inside this project without CPU readback and without touching any river material, bake data, or WaterSystem data.

Steps:

1. Create `addons/waterways/shaders/runtime/ripple_simulation.gdshader`.
2. Create a temporary standalone prototype scene or script for the simulation.
3. Implement a two-texture ping-pong loop using separate render targets, or document a proven Godot-safe alternative.
4. Record the feedback ownership model: read target, write target, swap timing, clear mode, update mode, and pause/resume behavior.
5. Add one fixed impulse source at a fixed UV.
6. Display the resulting texture in a simple debug quad or `TextureRect`.
7. Tune propagation and damping until rings visibly spread and decay.
8. Verify the simulation loop does not call viewport image readback.
9. Verify the shader never samples from the render target currently being written.
10. Verify texture precision is sufficient for decaying waves at 128, 256, and 512 resolution.
11. Verify impulse texture clear/accumulation behavior.
12. Verify scene reload and pause/resume do not leave stale feedback textures.
13. Verify the update loop does not run in the editor unless explicitly previewing.

Acceptance:

- A ripple texture animates in a controlled local test.
- Ripples decay over time.
- Fixed impulses create visible rings.
- Stopping impulses lets the field calm down.
- No readback is used for normal runtime simulation.
- Viewport feedback timing is stable across scene reload and pause/resume.
- Feedback ownership is explicit enough to avoid same-texture read/write hazards.
- No river shader, bake data, source signature, or WaterSystem changes are required yet.

Risks:

- Viewport feedback timing may require explicit ping-pong viewports or texture copies.
- Texture precision may be too low if using ordinary color formats.
- Running the simulation in editor mode could create confusing hidden state.
- Update order may differ between editor, F6, and exported builds.

## Phase 2: Coordinate Mapping And Mesh-Footprint Boundary Prototype

Goal: prove that emitters, debug views, simulation pixels, boundary masks, and eventual river shader samples all agree about position.

Steps:

1. Implement `world_to_ripple_uv` generation from the chosen field definition.
2. Implement world position to ripple UV conversion in GDScript.
3. Implement the equivalent mapping in shader code for debug/prototype rendering.
4. Add debug markers that show emitter positions in the ripple debug texture.
5. Add visible scene markers on the water surface and compare them to texture-space impulses.
6. Render the target river mesh footprint into a ripple-field boundary mask.
7. Feed the boundary mask into the simulation step.
8. Reject or fade impulses outside the mask.
9. Verify waves fade or stop at fully dry areas and field edges.
10. Test translated target rivers.
11. Test rotated and scaled target rivers only if Phase 0 chose full transformed-field support.
12. Document unsupported transform cases.
13. Document why UV2-atlas bake textures are not being used directly as first-pass masks.

Acceptance:

- A fixed world-space emitter lands at the same visual location in the debug texture and on the river.
- Moving an emitter creates a trail at the correct world position.
- The target river mesh footprint appears correctly in the boundary debug view.
- Boundary mask prevents obvious cross-bank propagation.
- Field edge handling does not create visible ringing or reflection artifacts.
- Unsupported transforms are rejected or warned about instead of silently mis-mapping ripples.
- The mapping contract is documented before river shader overlay work begins.

## Phase 3: Minimal River Shader Overlay

Goal: blend the proven ripple texture into visible Waterways rivers with the smallest safe shader change, while preserving debug and disabled-path behavior.

Steps:

1. Add internal ripple uniforms to `river.gdshader`.
2. Add world-position plumbing needed to convert fragment positions into ripple UVs.
3. Add a helper to sample ripple height safely.
4. Add a helper to derive a ripple normal from neighboring height samples.
5. Blend ripple normal into the existing normal-map response.
6. Keep the enabled near-camera normal path within the Phase 0 sample budget.
7. Keep the disabled path at zero ripple texture samples.
8. Keep refraction contribution off until normal blending is accepted.
9. Keep displacement default-off.
10. Add LOD fade so distant ripples do not shimmer.
11. Add a neutral fallback path when no ripple texture is assigned.
12. Make sure missing textures produce no visible effect.
13. Implement the selected debug parity path.
14. Add a targeted probe or debug check that toggling River debug views does not lose or hide runtime ripple state.

Acceptance:

- Waterways rivers look unchanged when ripple support is disabled.
- Missing ripple texture produces no visible effect.
- Enabling ripple support adds visible local rings at the correct world locations.
- Ripple normals blend with existing flow animation instead of replacing it.
- Foam, pillow, wake, and eddy-line material behavior remains recognizable.
- Debug parity exists through `river_debug.gdshader`, a separate `WaterRippleField` view, or an explicit targeted probe.
- The shader sample budget is met or the roadmap is revised before proceeding.
- No final flow, debug final-flow, bake data, source signature, or WaterSystem logic changes.

Risks:

- The existing fragment path is already expensive; ripple normal sampling adds more texture reads.
- World-position built-ins must be verified for Godot spatial shaders before implementation.
- Refraction can exaggerate small normal errors and should be delayed until normals are stable.
- River debug material switching can hide ripple state unless debug uniforms or probes are planned.

## Phase 4: Runtime Nodes, Material Ownership, And Add-On Wiring

Goal: turn the prototype into reusable Waterways runtime components without material side effects or ambiguous public API status.

Steps:

1. Create `water_ripple_field.gd`.
2. Create `water_ripple_field.tscn`.
3. Create `water_ripple_emitter.gd` only if emitter work is included in this phase; otherwise keep emitters in Phase 5.
4. Add exported properties for resolution, world transform/bounds, strength, damping, update rate, boundary mask, and debug visibility.
5. Add lifecycle handling:
   - inactive when disabled
   - initialized on ready
   - cleaned up on exit
   - paused safely when not inside tree
6. Add simulation step scheduling.
7. Add a RiverManager-facing runtime API or adapter that applies only `i_ripple_*` uniforms.
8. Add a method to register target river instances.
9. Add a method to unregister target river instances.
10. Apply shader parameters through the chosen material ownership path.
11. Clear or restore shader parameters predictably on disable and unregister.
12. Add warnings for invalid resolution, missing viewports, incompatible shaders, missing target materials, unsupported transforms, or missing boundary masks.
13. Keep the node runtime-safe and avoid editor-only dependencies.
14. If built-in, update `plugin.gd` to register `WaterRippleField` and any built-in emitter type.
15. If prototype-only, document that the nodes are not public custom types yet.

Acceptance:

- A scene can add `WaterRippleField`.
- The field creates and updates its texture.
- The field can expose that texture to one or more intended river targets.
- Disabling the node stops updates and clears or freezes output predictably.
- Two rivers can have separate ripple fields without cross-talk.
- The debug material path does not accidentally hide or corrupt visible material state.
- Scene reload does not leave stale ripple textures assigned.
- Add-on registration status matches the intended API surface.

## Phase 5: Emitter System

Goal: let gameplay objects create ripples without custom shader knowledge.

Steps:

1. Create `water_ripple_emitter.gd`.
2. Add exported properties:
   - `radius`
   - `intensity`
   - `falloff`
   - `pulse_rate`
   - `one_shot`
   - `enabled`
   - `priority`
   - optional target field reference or field group name
3. Let emitters join a configurable group such as `waterways_ripple_emitters`, but require `WaterRippleField` filtering so fields do not consume unrelated emitters accidentally.
4. Make `WaterRippleField` gather only emitters within its bounds and intended target set.
5. Convert emitter world position into ripple texture UV using the Phase 2 `world_to_ripple_uv` mapping.
6. Render impulse circles into the impulse viewport or equivalent input path.
7. Add optional velocity scaling for moving emitters.
8. Add one-shot impulse support for splashes.
9. Add continuous low-strength impulse support for floating objects.
10. Clamp maximum active emitters for performance.
11. Sort or prioritize emitters when the cap is exceeded.

Acceptance:

- Moving an emitter creates a trail of decaying rings.
- A one-shot emitter creates a single visible pulse.
- Emitters outside bounds do not affect the texture.
- Emitters in dry/boundary-masked areas do not create visible impossible waves.
- The system remains stable when no emitters exist.

## Phase 6: Demo Integration

Goal: show the feature in this project without making it mandatory.

Suggested demo choices:

- Duck ripples in `Demo.tscn`.
- Static test emitters around rocks in `Demo_obstacle_flow_test.tscn`.
- A small rain-ripple test area.

Steps:

1. Add a `WaterRippleField` to the demo scene.
2. Set bounds to cover the visible review area.
3. Add target river mesh-footprint boundary mask generation or assignment.
4. Add emitters to ducks or a few placed test nodes.
5. Assign the ripple field to the river target through the chosen runtime API.
6. Add a simple debug toggle if needed.
7. Keep the demo scene's existing river bakes unchanged.
8. Keep WaterSystem bake unchanged.
9. Run the scene and review from near and far cameras.
10. Tune first-pass defaults for readable but restrained ripples.
11. Record review notes in docs or changelog.

Acceptance:

- Demo visibly shows localized ripple interaction.
- The river still reads as Waterways flow-map water, not a generic pond shader.
- Ducks or emitters create ripples without disrupting pillows/wakes/eddies.
- Disabling the ripple field returns the old visual baseline.
- Debug views or probes show raw ripple, impulse, boundary, and visible influence.
- No saved bake resources or WaterSystem resources change.

## Phase 7: Debug And Validation

Goal: make ripple behavior inspectable before polishing and catch the architecture regressions most likely to slip through visual review.

Steps:

1. Add a debug view for the raw ripple texture.
2. Add debug display for impulse texture.
3. Add debug display for boundary mask.
4. Add a debug view or probe for visible river ripple influence.
5. Add warnings when target rivers have no compatible shader uniforms.
6. Add validation for the selected material ownership path:
   - two rivers with separate ripple fields
   - one river disabled while another stays enabled
   - debug view toggled while ripple field is active
   - scene reload with no stale runtime texture
7. Add validation for the mapping contract:
   - fixed world-space marker maps to expected texture UV
   - moving emitter trail lands on the correct river location
   - unsupported transforms warn or fail clearly
8. Add validation for runtime boundaries:
   - no river bake resources are modified
   - no WaterSystem bake resources are modified
   - no source-signature bump occurs
   - no buoyancy behavior changes
9. Add a lightweight runtime probe scene or script that verifies:
   - ripple field initializes
   - texture dimensions are valid
   - target materials receive `i_ripple_*` texture and transform uniforms
   - disabling clears or stops updates
   - no saved bake resources are modified
10. Add manual viewport review instructions.
11. Test at multiple resolutions.
12. Test no-emitter idle cost.
13. Test many emitters.
14. Test scene reload.
15. Test export/F6 behavior if Godot tooling is available.

Acceptance:

- Debug texture clearly shows impulses and wave decay.
- Boundary mask debug view explains where waves can and cannot travel.
- Visible river influence is inspectable or explicitly covered by a targeted probe.
- Missing or disabled ripple systems fail quietly.
- No editor-only state is required for runtime use.
- No runtime readback is used.
- Validation catches accidental material cross-talk.
- Validation catches debug material state loss.
- Validation catches accidental bake, WaterSystem, source-signature, or buoyancy changes.

## Phase 8: Performance And Quality

Goal: make the runtime cost predictable.

Steps:

1. Establish target resolutions:
   - 128 for cheap localized ripples
   - 256 for normal demo use
   - 512 only for hero shots or high-end settings
2. Measure simulation cost with no emitters, a few emitters, and many emitters.
3. Measure river shader cost with ripple sampling disabled and enabled.
4. Track additional ripple texture samples in the visible shader path.
5. Keep the disabled path at zero ripple texture samples.
6. Keep first-pass normal integration to no more than three additional ripple samples near camera unless a performance review explicitly accepts more.
7. Add update-rate control if every-frame simulation is too expensive.
8. Add camera-following bounds only if reprojection or clear-on-shift behavior is designed.
9. Add simulation pause when offscreen or no target material is visible, if practical.
10. Add emitter cap and priority sorting.
11. Keep default settings conservative.
12. Avoid adding compute shaders until the viewport path proves insufficient.

Acceptance:

- Default settings are affordable in the demo.
- Users can lower resolution or disable ripples.
- Visual output remains stable on camera movement.
- Distant ripples do not shimmer.
- Disabled ripple shader path has no avoidable ripple sampling cost.
- Enabled ripple shader path meets the documented first-pass sample budget or the budget is revised with evidence.
- The runtime cost is documented.

## Phase 9: Authoring Controls

Goal: expose enough control for users without turning the feature into a complicated simulator.

Steps:

1. Add inspector grouping for ripple field settings.
2. Add clear names:
   - Ripple Strength
   - Ripple Normal Strength
   - Ripple Refraction Strength
   - Ripple Displacement Strength
   - Damping
   - Propagation
   - Update Rate
   - Resolution
   - Bounds
3. Add safe ranges.
4. Add default-off displacement.
5. Add simple emitter presets:
   - Duck / small object
   - Player footstep
   - Boat wake touch
   - Rain drop
   - Heavy splash
6. Document how to attach emitters to runtime objects.
7. Document how multiple rivers and multiple fields should be configured.
8. Document whether the nodes are built-in custom types or prototype/example scene nodes.

Acceptance:

- A user can add ripples without editing shader code.
- Defaults are restrained and stable.
- Strong settings are available but not the default.
- The inspector does not expose unstable internal shader plumbing unless intentionally categorized.
- Public add-on registration and documentation agree.

## Phase 10: Optional Flow-Aware Ripples

Goal: make ripples feel like they belong to a moving river without changing physics.

Only start this phase after the basic visual layer is accepted.

Possible steps:

1. Sample Waterways' baked local flow at the river material level.
2. Slightly stretch ripple normals along flow direction.
3. Slightly fade ripple rings in high-flow/high-foam regions.
4. Optionally advect the ripple simulation by a low-strength flow vector.
5. Compare against the simpler non-advected version.
6. Keep this visual-only unless explicitly promoted.

Acceptance:

- Ripples feel less pond-like in moving water.
- Flow-aware settings do not imply unsupported physics behavior.
- The effect can be disabled.

Risks:

- Flow advection may smear rings or fight Waterways' normal animation.
- Shader and simulation need the same world-to-ripple mapping.
- Strong advection can look like a hidden flow change while buoyancy remains unchanged.
- Baked flow is UV2/atlas based while the ripple field is world-space, so mapping must be handled carefully.

## Phase 11: Physics-Facing Future Work

Goal: define what would be required if ripples ever influence objects or WaterSystem behavior.

Do not begin this phase as part of the first ripple feature.

Required planning:

1. Define whether ripple height affects buoyancy height, object drift, or only visuals.
2. Decide how buoyant objects would sample the ripple field.
3. Decide whether the WaterSystem map should remain static while runtime ripples are sampled separately.
4. Avoid writing transient ripple data into saved WaterSystem bakes.
5. Add runtime validation with buoyant objects.
6. Add debug views that compare visible ripple height with sampled runtime height.
7. Make sure multiplayer or deterministic gameplay expectations are addressed if relevant.

Acceptance:

- Visible water and runtime behavior agree.
- The feature does not corrupt or obscure the saved WaterSystem bake.
- Runtime sampling is documented.

## Recommended First Milestone

Build a small visual-only prototype, but in risk order:

1. Finalize the visual-only scope, `world_to_ripple_uv` contract, mesh-footprint boundary source, RiverManager-facing material ownership path, debug parity path, add-on registration status, and shader sample budget.
2. Add the ripple simulation shader.
3. Prove no-readback ping-pong feedback in a standalone debug view.
4. Prove world-to-ripple mapping with one fixed world-space impulse.
5. Render the target river mesh footprint into a ripple-field boundary mask.
6. Verify waves do not propagate through dry areas or field edges.
7. Apply runtime uniforms through the selected ownership API.
8. Blend only ripple normals into `river.gdshader` within the sample budget.
9. Add debug/probe coverage for raw ripple, impulse, boundary, visible influence, and material ownership.
10. Add one fixed emitter and one moving emitter.
11. Review in `Demo.tscn`.

Do not touch:

- river bake resources
- source signatures
- `system_flow.gdshader`
- `WaterSystem.water_system_bake.res`
- buoyancy code
- accepted pillow/wake/eddy classifiers
- shared material resources without explicit ownership and restore behavior

## Validation Checklist

Before accepting the first implementation:

- [ ] Disabled ripple field produces identical visible river behavior.
- [ ] Missing ripple texture produces no visible effect.
- [ ] A fixed emitter creates decaying rings.
- [ ] Moving emitter creates local disturbance without flooding the whole river.
- [ ] Emitters map to the correct world-space water location.
- [ ] `world_to_ripple_uv` is the single production mapping input used by emitters, debug views, simulation, and river shader sampling.
- [ ] Target river mesh footprint appears correctly in the boundary debug view.
- [ ] Boundary mask prevents obvious cross-bank or through-rock propagation.
- [ ] Ripples blend with normal flow animation.
- [ ] Pillow, wake, and eddy-line visuals still read correctly.
- [ ] Debug view or targeted probe can inspect visible ripple influence.
- [ ] River debug material switching does not lose or hide runtime ripple state.
- [ ] Disabled ripple shader path has no avoidable ripple sampling cost.
- [ ] Enabled ripple shader path stays within the accepted first-pass sample budget.
- [ ] No river bake resources changed.
- [ ] No WaterSystem bake changed.
- [ ] No source-signature bump occurred.
- [ ] No buoyancy or runtime WaterSystem sampling behavior changed.
- [ ] No runtime readback is used for simulation or normal rendering.
- [ ] No target material cross-talk occurs between rivers.
- [ ] Scene reload does not leave stale hidden state.
- [ ] Add-on registration status matches the documented API surface.
- [ ] F6/export behavior is checked if Godot tooling is available.
- [ ] User reviews the visible effect in the editor or running scene.

## Open Questions

- Should the first demo use ducks, click/test emitters, rain, or fixed rock-adjacent emitters?
- Should the ripple field cover the whole demo river or a smaller fixed review area?
- Which renderer/platform targets need to be supported in the first pass?
- Should the first public field support only axis-aligned X/Z bounds, or full transformed fields?
- If full transformed fields are deferred, what warning should unsupported rotated/scaled setups show?
- Should `follow_camera` remain hidden until after a reprojection strategy exists?
- Is 256x256 enough for the default demo?
- Should displacement stay completely off in the first release, or be available as a default-off control?
- Should ripples be a built-in Waterways node or a separate example scene first?
- Should emitter groups be global with field filtering, or should emitters explicitly reference a target `WaterRippleField`?
- How should multiple rivers in one scene share or separate ripple fields in the public API?
- Should visible ripple influence be added to `river_debug.gdshader`, or is a separate `WaterRippleField` debug/probe path enough for the first pass?

## Sources

- `../research/river-research-citations.md`
- `../roadmaps/river-improvements-roadmap.md`
- `../roadmaps/river-feature-detection-roadmap.md`
- `../architecture-and-features.md`
- `https://github.com/CBerry22/Godot-Water-Ripple-Simulation-Shader`
