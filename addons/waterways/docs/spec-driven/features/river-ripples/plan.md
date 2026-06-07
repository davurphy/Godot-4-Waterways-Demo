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

- Implementation status: Not started; docs created from roadmap.
- Open architectural decisions: First demo scenario, axis-aligned vs full transformed fields, built-in vs prototype registration, debug parity path, emitter targeting model, renderer targets, and final shader sample budget confirmation.
- Last validation that proves the plan still works: None yet for ripple code; this is a planning folder only.
- Next planned implementation slice: Phase 0 decision lock and branch safety check before any code, shader, scene, or generated-resource edits.
- Branch safety before implementation: Not checked. Before implementation, use a dedicated branch or get explicit approval to continue on the current branch.
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

- Optional custom type registration for `WaterRippleField` and `WaterRippleEmitter`.
- Inspector controls for resolution, bounds/transform, strengths, damping, propagation, update rate, target rivers, and debug visibility.
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
  - Future `addons/waterways/water_ripple_field.gd`.
  - Future `addons/waterways/water_ripple_field.tscn`.
  - Future `addons/waterways/water_ripple_emitter.gd`.
- Resources:
  - Runtime-created viewport textures or equivalent transient textures.
  - No saved bake resources in first pass.
- Shaders:
  - Future `addons/waterways/shaders/runtime/ripple_simulation.gdshader`.
  - Future internal `i_ripple_*` additions to `addons/waterways/shaders/river.gdshader`.
  - Optional parity additions to `addons/waterways/shaders/river_debug.gdshader`.
- Editor tools:
  - Future `addons/waterways/plugin.gd` custom type registration if nodes are public.
  - Optional icons if registered.
- Importers:
  - None expected for first pass.
- Autoloads:
  - None expected unless a later plan justifies global emitter discovery.
- Scenes:
  - Temporary standalone ripple prototype scene.
  - Future demo integration in `Demo.tscn` or a small ripple review scene.
- Validation scenes:
  - Standalone ripple texture review.
  - Mapping and boundary-mask review.
  - Demo visible river overlay review.

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
- Simulation, impulse, and runtime textures are transient.
- River bake data, WaterSystem data, and source signatures are not changed.

Roadmap detail carried into implementation:

- Field configuration should cover `enabled`, `resolution`, `world_transform` or `world_bounds`, target rivers, strengths, damping, propagation, update rate, emitter cap, and debug visibility.
- `world_bounds` can be a convenience input only if it generates the same `world_to_ripple_uv` transform used by GDScript and shaders.
- `follow_camera` should stay hidden or unsupported until reprojection, clear-on-shift, or tile swapping is designed.
- Emitter configuration should cover radius, intensity, falloff, pulse rate, one-shot behavior, enabled state, priority, and optional target-field routing.
- River shader integration should use `i_ripple_enabled`, `i_ripple_simulation_texture`, `i_ripple_world_to_uv`, `i_ripple_boundary_mask`, `i_ripple_texel_size`, `i_ripple_normal_strength`, `i_ripple_refraction_strength`, `i_ripple_displacement_strength`, `i_ripple_height_fade_distance`, and `i_ripple_boundary_fade` unless the plan is revised.
- First visible integration should add ripple normals only; refraction follows after normal stability, and displacement stays default off.
- Later authoring should use clear controls and restrained presets rather than exposing unstable runtime plumbing.

## Editor/Runtime Boundary

- Editor-only code:
  - Custom type registration, icons, debug menu integration, editor-only preview tooling, validation helpers.
- Runtime-safe code:
  - Ripple field lifecycle, emitter gathering, viewport stepping, shader uniforms, material cleanup.
- Shared data/resources:
  - Runtime field configuration when saved in scenes.
  - River target references or paths when intentionally serialized.
- APIs exposed to user projects:
  - Only after add-on registration status is decided.
  - Likely `WaterRippleField.register_target()`, `unregister_target()`, emitter configuration, and debug texture accessors.
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

- `addons/waterways/shaders/runtime/ripple_simulation.gdshader`: Add Waterways-owned runtime simulation shader.
- `addons/waterways/water_ripple_field.gd`: Add runtime field node.
- `addons/waterways/water_ripple_field.tscn`: Add reusable field scene if needed.
- `addons/waterways/water_ripple_emitter.gd`: Add emitter node when emitter phase starts.
- `addons/waterways/river_manager.gd`: Add runtime uniform application/clear API if selected.
- `addons/waterways/shaders/river.gdshader`: Add minimal internal visible ripple normal overlay after spikes pass.
- `addons/waterways/shaders/river_debug.gdshader`: Add debug parity only if selected.
- `addons/waterways/plugin.gd`: Register custom types and icons if nodes are public.
- `Demo.tscn` or a dedicated review scene: Optional demo integration after runtime path is stable.
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
  - Measure 128, 256, and 512 resolutions; no-emitter idle; few emitters; many emitters; shader enabled/disabled.
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
| Debug material switching hides ripple state | Review cannot trust visible/debug comparison | Implement selected debug parity path or targeted probe. |
| Shader sampling cost is too high | Regresses already heavy river material | Keep disabled path cheap and first normal pass within sample budget. |
| Users infer physics from visuals | Buoyancy and visible rings appear inconsistent | Keep docs, UI, and validation explicit that first pass is visual-only. |

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
  - No. This docs pass is not implementation. Send the reminder before shader, script, scene, or generated-resource edits.

## Migration and Compatibility

- Active target is Godot 4.6+.
- No legacy Godot 3 APIs should be introduced.
- First-pass visual ripples are optional and should fail neutral when disabled or missing textures.
- No resource migration is expected for visual-only implementation.
- Public API compatibility only matters after built-in/prototype registration status is decided.
- Future physics-facing work must include save/load, bake invalidation, WaterSystem, and runtime sampling compatibility planning.
