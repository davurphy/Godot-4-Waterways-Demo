# Spec: River Ripples

## Summary

River ripples add an optional runtime visual disturbance layer to Waterways rivers. The first milestone should create localized surface rings from ducks, boats, players, rain, falling objects, or scripted emitters without changing baked river flow, WaterSystem data, buoyancy, or saved bake resources.

This spec is derived from `addons/waterways/docs/roadmaps/runtime-ripple-simulation-roadmap.md`. The roadmap's main constraint is preserved here: runtime ripples start as transient visual surface detail, not as a new flow solver or physics data source.

## Current Truth

Use this as the dashboard for the current ripple spec state. Move older detail into the sections below instead of letting stale open questions linger.

- Status: Phase 0 decisions locked; standalone Phase 1 feedback ownership, 128/256/512 spread/decay, standalone Phase 2 mapping, standalone Phase 2 mesh-footprint boundary-mask validation, RiverManager-facing material ownership/restore validation, minimal river shader neutral-path validation, guarded river shader sampling-helper validation, minimal visible river normal-blend validation, revised demo review-scene diagnostic validation, debug parity validation, current shader-cost validation, reusable field/emitter lifecycle validation, current field/emitter dispatch-performance validation, demo-backed field/emitter authoring validation, Mobile/Compatibility renderer coverage, and Phase 9 custom type parser/editor-load validation passed automated checks.
- Source of truth for open work: `tasks.md` "Open Work".
- Last meaningful decision: First milestone is visual-only; no-readback standalone feedback, axis-aligned `world_to_ripple_uv` marker mapping, mesh-footprint boundary masking, RiverManager-facing `i_ripple_*` material ownership, built-in river shader disabled/missing-texture neutrality, helper-level sampling budget, minimal visible normal blending, revised demo review-scene diagnostic visibility, review-fixture framerate improvement, human-visible base-flow/outward-ring acceptance, debug parity, current shader-cost, field/emitter lifecycle, Forward+/Mobile/Compatibility field-emitter and shader-cost coverage, automated demo authoring integration, human-visible field/emitter demo authoring stop/reload workflow, and `WaterRippleField`/`WaterRippleEmitter` custom type registration are now proven enough for their current gates. Human-visible Add Node inspection, deeper authoring presets/API hardening, and response/refraction/displacement tuning remain unproven.
- Known deferred items: Buoyancy, object drift, runtime flow changes, WaterSystem regeneration, saved ripple persistence, flow-aware advection, and full physics-facing shallow-water behavior.
- Current non-goals that are easy to accidentally reopen: Do not change `flow`, `flow_force`, `i_flowmap`, final flow, source signatures, river bake resources, WaterSystem bake resources, `system_flow.gdshader`, or buoyancy behavior for the first visual ripple pass.

## Goals

- Add localized water-surface disturbance from runtime emitters.
- Keep Waterways' baked river data stable and authoritative for authored river behavior.
- Enrich visible normals, refraction, and optional close-range displacement without changing current direction or physics.
- Make the first version useful in the demo scene while remaining general enough for user projects.
- Preserve accepted pillow, wake, and eddy-line visual baselines.
- Reimplement the technique in Waterways style instead of copying code from the inspiration repository.
- Keep simulation state transient unless a later milestone explicitly designs persistence.

## Non-Goals

- No full shallow-water simulation for the whole river.
- No replacement for Waterways spline, bake, flow-map, or WaterSystem workflows.
- No source-signature bump for the first visual-only pass.
- No saved river bake changes for visual ripples.
- No WaterSystem regeneration for visual ripples.
- No buoyancy, object drift, reverse-flow, or eddy-circulation changes.
- No runtime texture readback in normal rendering or in the ripple simulation loop.
- No same-texture read/write feedback shortcut unless a Godot-specific spike proves it safe.
- No hidden edits to shared river materials that affect unrelated rivers.
- No claim of debug parity unless raw ripple, impulse, boundary, and visible river influence are inspectable.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Future sessions should use it as the project-level source list for river behavior, hydrology, flow maps, shader-water references, and production examples, and should update it when new external research informs this feature.
- Known scene/data/context facts:
  - `river.gdshader` already layers animated normals, refraction, foam, pillows, wakes, eddy-line turbulence, and optional pillow displacement.
  - Current Waterways architecture separates stable authored bake fields from runtime shader detail.
  - `filter_renderer.gd` proves shader passes through `SubViewport` exist in the project, but it is bake-oriented and uses CPU image readback.
  - Runtime ripples need a separate no-readback feedback path.
- User-reported observations:
  - User confirmed standalone feedback rings spread and decay.
  - User confirmed standalone mapping markers agree with texture impulses.
  - User confirmed standalone boundary mask shape and dry gap.
  - User saw no ripples in the earlier demo normal-review scene; this led to clustered centers and better camera focus.
  - User later saw visible demo ripples, but enabling them froze the base flow and the static texture did not expand outward. After that fixture fix, user saw ripples in the river and reported a harsh enabled-framerate drop. The fixture now preserves material flow speed, precomputes 48 review ripple frames once, and swaps them during playback; user rerun confirmed framerate is greatly improved, the river keeps moving, and ripple rings expand outward.
- Agent confidence in the premise:
  - High that visual-only runtime ripple prototyping fits the current add-on architecture.
  - Medium that Godot viewport feedback can satisfy the no-readback requirement without additional engine constraints; this needs a feasibility spike.
- Possible expected-behavior explanations to rule out before patching:
  - A rectangular debug simulation can look correct while still being unsuitable for river integration because waves pass through banks or disconnected bends.
  - A visible ripple may look like changed current even when buoyancy and WaterSystem flow remain unchanged.
  - Shared material mutation can make one field appear to work while quietly affecting unrelated rivers.
- Clarification or challenge already raised with the user:
  - The roadmap explicitly scopes first-pass ripples as visual-only; physics-facing ripple behavior must be a later milestone.

## Users and Workflows

### User Story: Demo Author Adds Local Ripples

As a demo author, I want ducks, objects, or test emitters to create small decaying rings, so that the river surface feels interactive without rebaking the river.

Acceptance criteria:

- A fixed emitter creates rings at the correct world-space water location.
- A moving emitter creates a local trail that decays.
- Disabling the ripple field returns the old visible river baseline.
- No river bake or WaterSystem resource changes are required.

### User Story: Add-on Maintainer Protects Baked Flow

As an add-on maintainer, I want ripple work to stay separate from baked flow, so that accepted flow, foam, pillow, wake, eddy-line, and WaterSystem behavior cannot be changed by a visual effect.

Acceptance criteria:

- Ripple code does not alter `flow`, `flow_force`, `i_flowmap`, final flow, source signatures, river bakes, saved WaterSystem bakes, or buoyancy.
- Shader and debug docs keep visual ripples separate from physics-facing flow.
- Any future physics-facing request starts a separate plan.

### User Story: Runtime Developer Proves Feedback Rendering

As a runtime developer, I want a no-readback ping-pong ripple texture, so that the simulation can run every frame without CPU image reads or same-texture read/write hazards.

Acceptance criteria:

- The feedback path names the read target, write target, swap timing, clear mode, update mode, impulse lifetime, and pause/resume behavior.
- The normal runtime loop does not call viewport `get_image()` or equivalent readback.
- The shader never samples the render target currently being written.

### User Story: Reviewer Inspects Ripple State

As a reviewer, I want raw ripple, impulse, boundary, and visible influence debug views, so that I can diagnose mapping, masking, material, and shader integration problems.

Acceptance criteria:

- Raw ripple texture, impulse texture, boundary mask, and visible river influence are inspectable through debug shader support, `WaterRippleField` views, or targeted probes.
- Debug material switching does not lose or hide runtime ripple state.
- Missing or disabled ripple systems fail quietly.

## Functional Requirements

- Add a runtime `WaterRippleField` concept that owns ripple simulation textures or viewports.
- Add a runtime emitter path, likely `WaterRippleEmitter`, for fixed, moving, pulse, and continuous impulses.
- Use one production mapping input: `world_to_ripple_uv`.
- Use the same world-to-ripple mapping for emitters, simulation, debug views, and `river.gdshader`.
- Reject or edge-fade ripple UVs outside `[0, 1]`.
- Keep height/Y in mapped position reserved for future height fade or diagnostics, not physics.
- Run simulation on the GPU during normal runtime.
- Use ping-pong render targets or another proven feedback ownership model.
- Do not sample from the texture currently being rendered into.
- Generate or consume a river boundary mask before visible river integration.
- Prefer target river mesh-footprint rendering as the first accepted boundary-mask source.
- Do not use padded UV2 atlas bake textures directly as world-space ripple masks.
- Apply runtime ripple uniforms only to intended river targets.
- Restore or clear runtime material state predictably on disable, unregister, and scene unload.
- Add internal river shader uniforms under the `i_ripple_*` prefix unless user-authored material controls are intentionally designed.
- Keep missing ripple textures neutral.
- Keep displacement default off.
- Keep the current custom type registration documented before expanding the field/emitter public API surface.

## Roadmap Details To Preserve

Keep these concrete details visible during implementation. They come from the roadmap and should not be lost behind the higher-level feature wording above.

Suggested `WaterRippleField` public properties:

- `enabled`
- `resolution`
- `world_transform` or `world_bounds`, with `world_bounds` only acting as a convenience source for `world_to_ripple_uv`
- explicit target river list and optionally `target_group_name`
- `ripple_strength`
- `normal_strength`
- `refraction_strength`
- `displacement_strength`
- `damping`
- `propagation`
- `simulation_update_rate`
- `max_emitters`
- `follow_camera`, hidden or unsupported until reprojection, clear-on-shift, or tile swapping is designed
- `debug_visible`

Suggested `WaterRippleEmitter` public properties:

- `radius`
- `intensity`
- `falloff`
- `pulse_rate`
- `one_shot`
- `enabled`
- `priority`
- optional target field reference or field group name

Internal river shader uniforms should stay under the `i_ripple_*` prefix unless a deliberate user-authored material category is designed:

- `i_ripple_enabled`
- `i_ripple_simulation_texture`
- `i_ripple_impulse_texture`
- `i_ripple_world_to_uv`
- `i_ripple_boundary_mask`
- `i_ripple_texel_size`
- `i_ripple_normal_strength`
- `i_ripple_refraction_strength`
- `i_ripple_displacement_strength`
- `i_ripple_height_fade_distance`
- `i_ripple_boundary_fade`

First-pass shader behavior:

- Compute river fragment world position and map it through `i_ripple_world_to_uv`.
- Reject or fade samples outside the field and outside the boundary mask.
- Sample ripple height and derive local ripple normals from neighboring height samples.
- Blend ripple normals into the existing normal response without replacing flow animation.
- Keep refraction delayed until normal integration is stable.
- Keep displacement default off and close-range only if enabled.
- Keep the disabled path neutral and free of avoidable ripple texture samples.

Authoring controls should eventually expose clear user-facing names such as Ripple Strength, Ripple Normal Strength, Ripple Refraction Strength, Ripple Displacement Strength, Damping, Propagation, Update Rate, Resolution, and Bounds. Presets should remain simple and optional, such as Duck / small object, Player footstep, Boat wake touch, Rain drop, and Heavy splash.

## Non-Functional Requirements

- Maintainability: Keep ripple field, emitters, river shader overlay, material ownership, and debug views as separable responsibilities.
- Performance: No normal-runtime readback; disabled river shader path should have zero avoidable ripple texture samples; first normal integration should target no more than three additional ripple samples near camera unless a performance review accepts more.
- Visual quality: Ripples should read as localized water-surface detail that blends with existing flow animation, not as a generic pond shader pasted over the river.
- Godot 4.6+ compatibility: Use active Godot 4.6+ nodes, shaders, resources, viewport behavior, and material APIs.
- Editor usability: Warnings should explain invalid resolution, missing viewports, incompatible shaders, unsupported transforms, missing targets, and missing boundary masks.
- Runtime usability: The system should be addable to scenes without shader editing once the public API is accepted.
- Extensibility: Later phases may add rain batches, velocity scaling, flow-aware visual advection, or physics sampling without rewriting the visual-only foundation.

## Add-on Boundary

Editor authoring responsibilities:

- Inspector settings for ripple fields and emitters if they become built-in nodes.
- Optional debug visibility controls.
- Human-assisted visual review scenes and procedures.
- Add-on custom type registration and icons if nodes are public.

Bake/data responsibilities:

- None for the first visual-only pass.
- River bakes, WaterSystem bakes, source signatures, and saved `RiverBakeData` resources must remain unchanged.
- Later physics-facing work must explicitly define any new generated data before touching bakes.

Runtime responsibilities:

- Runtime ripple textures, impulse textures, boundary masks, and transient feedback state.
- Runtime mapping from world positions to ripple UVs.
- Runtime-only `i_ripple_*` shader uniforms on intended river targets.
- Emitter gathering, filtering, caps, priorities, and impulse rendering.
- Cleanup and restore behavior on disable, unregister, and scene unload.

Shared code must not depend on:

- Editor-only state.
- One demo scene hierarchy.
- One shared material resource.
- One fixed river mesh.
- Legacy Godot 3 APIs.
- UV2 atlas data being usable as a world-space mask.

## Data and Extension Model

Users should be able to:

- Add a ripple field to a scene.
- Configure resolution, bounds or transform, damping, propagation, strengths, update rate, and debug visibility.
- Register explicit target rivers or use a filtered target set.
- Add emitters to gameplay objects without editing shader code.
- Disable ripples and get predictable neutral material behavior.

Extension points:

- `WaterRippleField` configuration.
- `WaterRippleEmitter` presets and modes.
- Runtime RiverManager-facing uniform application API.
- Debug/probe hooks for raw ripple, impulse, boundary, and visible influence.
- Future flow-aware visual advection and physics sampling milestones.

Override rules:

- Explicit target registration must win over broad group discovery when both exist.
- A ripple field must not affect rivers outside its intended target set.
- Disabling or unregistering must clear or restore the runtime uniforms it applied.
- Registered nodes must not imply response/refraction/displacement, flow, or physics-facing API stability before those slices are planned.

Shared systems must not hard-code:

- Demo duck names, rock positions, or camera views.
- A single target river.
- A single renderer backend unless documented as a first-pass limitation.
- A material-only assumption that bypasses RiverManager ownership.

## Acceptance Tests

- Disabled ripple field produces identical visible river behavior.
- Missing ripple texture produces no visible effect.
- A fixed emitter creates decaying rings.
- A moving emitter creates local disturbance without flooding the whole river.
- Emitters map to the correct world-space water location.
- `world_to_ripple_uv` is the single production mapping input used by emitters, debug views, simulation, and river shader sampling.
- Target river mesh footprint appears correctly in the boundary debug view.
- Boundary mask prevents obvious cross-bank or through-rock propagation.
- Ripples blend with existing normal flow animation.
- Pillow, wake, and eddy-line visuals still read correctly.
- Debug view or targeted probe can inspect raw ripple height, impulse/contact, boundary mask, and visible ripple influence.
- River debug material switching does not lose or hide runtime ripple state.
- Disabled ripple shader path has no avoidable ripple sampling cost.
- Enabled ripple shader path stays within the accepted first-pass sample budget.
- No river bake resources changed.
- No WaterSystem bake changed.
- No source-signature bump occurred.
- No buoyancy or runtime WaterSystem sampling behavior changed.
- No runtime readback is used for simulation or normal rendering.
- No target material cross-talk occurs between rivers.
- Scene reload does not leave stale hidden state.
- Add-on registration status matches the documented API surface.

## Visual Validation Requirements

- Review a standalone ripple texture before visible river integration.
- Review fixed and moving emitters in world space against the ripple debug texture.
- Review boundary mask coverage in the same field space as the simulation.
- Review raw ripple, impulse/contact, boundary mask, and visible influence debug views.
- Review visible river response with ripples disabled, missing texture, fixed emitter, and moving emitter.
- Compare existing pillow, wake, and eddy-line visuals before and after ripple shader changes.
- Use human-assisted Godot viewport review for final visual acceptance unless the agent can genuinely inspect the editor/runtime viewport.

## Performance Requirements

- Default demo target should start at 256x256 unless Phase 0 changes the budget.
- 128 should remain available for cheap localized ripples.
- 512 should be reserved for hero/high-end settings until measured.
- Normal runtime must not use CPU readback.
- Disabled ripple shader path should avoid ripple texture samples.
- First-pass normal integration should target no more than three additional ripple texture samples near camera.
- Current shader-cost validation passes this target: `RIPPLE_SHADER_COST_PROBE_OK` reported zero direct disabled/visible-fragment ripple samples, three enabled-normal simulation samples plus one boundary helper call, one draw call, and a `+0.004 ms` median GPU delta for enabled visible normals over disabled live textures at 640x360 on Godot 4.6.3 Forward+ / AMD Radeon RX 6800 XT.
- Current field/emitter dispatch validation passes the first production sweep: `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` measured 128/256/512 fields with 0/4/16 emitters and dispatch medians of `5.933/5.738/5.755 ms`, `5.981/5.518/5.799 ms`, and `5.511/6.202/5.866 ms` on Godot 4.6.3 Forward+ / AMD Radeon RX 6800 XT.
- Update-rate control should be added if every-frame simulation is too expensive.
- Emitter caps and priorities should prevent unbounded impulse cost.

## Open Questions

- Which renderer and platform targets need first-pass support?
- Should `follow_camera` remain hidden until reprojection, clear-on-shift, or tile swapping is designed?
- Is 256x256 enough for the default demo?
- Should displacement stay completely off in the first release, or be available as a default-off control?
- How should multiple rivers in one scene share or separate ripple fields in the public API?

## Resolved Questions

Move questions here once decided so future sessions do not keep treating them as open.

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Is the first ripple milestone visual-only? | Yes. | 2026-06-07 | Adopted from `runtime-ripple-simulation-roadmap.md`; no first-pass flow, WaterSystem, or buoyancy changes. |
| Should runtime ripples use CPU readback for simulation? | No. | 2026-06-07 | Normal runtime simulation must stay on the GPU. |
| Can visible river integration happen before boundary masking and material ownership are selected? | No. | 2026-06-07 | These are roadmap hard constraints and acceptance gates. |
| Is target river mesh-footprint rendering viable as the first boundary-mask source? | Yes for the standalone gate. | 2026-06-07 | `RIPPLE_BOUNDARY_MASK_PROBE_OK` rendered a generated Waterways river mesh footprint through `world_to_ripple_uv` and validated dry-area rejection in the standalone feedback path. |
| Should visible ripple influence be added to `river_debug.gdshader`, or is a separate debug/probe path enough for the first pass? | Add debug shader parity plus targeted probes. | 2026-06-07 | `river_debug.gdshader` now has raw height, impulse/contact, boundary mask, and visible influence modes; `RIPPLE_DEBUG_PARITY_PROBE_OK` proves view switching preserves runtime ripple state. |
| Should the first field support axis-aligned X/Z bounds or full transformed fields? | Use axis-aligned X/Z `world_bounds` for the prototype; defer full transformed fields. | 2026-06-07 | `WaterRippleField` builds the same `world_to_ripple_uv` contract already proven by mapping, boundary, shader, and field/emitter probes. Unsupported transformed-field/public API behavior remains later polish. |
| Should ripples be built-in Waterways nodes or prototype scenes first? | Prototype scenes first. | 2026-06-07 | `water_ripple_field.tscn` and `water_ripple_emitter.tscn` were added before public registration; this allowed runtime and visible workflow validation before Phase 9 promotion. |
| Should the proven field/emitter nodes be promoted to editor custom types? | Yes, register them without `class_name` for now. | 2026-06-07 | `plugin.gd` now registers `WaterRippleField` and `WaterRippleEmitter` as `Node3D` custom types with ripple icons, matching the existing Waterways custom-type pattern. |
| Should emitter groups be global with field filtering, or should emitters explicitly reference a target field? | Prototype emitters prefer explicit field paths, with ancestor/group fallback. | 2026-06-07 | `WaterRippleEmitter` resolves `target_field_path` first, then a parent field, then `field_group_name`; `RIPPLE_FIELD_EMITTER_PROBE_OK` validates the field API path. |
| Should the first demo use ducks, click/test emitters, rain, or fixed rock-adjacent emitters? | Use prototype test emitters in a demo-backed review scene first. | 2026-06-07 | `ripple_field_emitter_demo_review.tscn` instances `Demo.tscn` and adds inspectable pulse, one-shot, and moving emitters under an inspectable field. Ducks/rain remain later authoring presets. |
| Should the ripple field cover the whole demo river or a smaller fixed review area? | Use the generated demo river mesh AABB for the first review field. | 2026-06-07 | The scene script snaps authored emitter UVs to the live demo mesh, generates the boundary mask from `RiverMeshInstance`, and validates reload cleanup through `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. |
| What should empty runtime field viewports clear to? | Transparent zero/black for canvas ripple buffers. | 2026-06-07 | Human-visible no-ripples review showed impulse/contact blue everywhere and visible influence black. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK` found a nonzero full-field impulse background from the project clear color; `WaterRippleField` now uses transparent zero clear and the demo probe rejects nonblack impulse backgrounds. |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-07 | Create a dedicated `river-ripples` spec-driven feature folder. | Keep the runtime ripple roadmap actionable without scattering decisions across roadmap-only notes. |
| 2026-06-07 | Treat `world_to_ripple_uv` as the required production mapping contract. | Avoid drift between emitters, debug views, simulation pixels, and river shader samples. |
| 2026-06-07 | Keep first-pass runtime state transient. | Avoid corrupting or confusing saved river bakes, WaterSystem resources, or source signatures. |
| 2026-06-07 | Promote proven field/emitter nodes to add-on custom types. | Runtime lifecycle, demo authoring, human-visible workflow, and Mobile/Compatibility renderer gates passed, so the nodes can be added from the editor while deeper presets/API hardening remain separate. |
| 2026-06-07 | Keep the first boundary-mask proof standalone and mesh-footprint based. | Prove river-shaped masking and dry impulse rejection before material ownership or river shader integration. |
