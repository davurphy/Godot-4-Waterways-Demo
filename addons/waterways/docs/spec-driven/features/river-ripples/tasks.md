# Tasks: River Ripples

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

## Current Truth

This is the task dashboard. Keep active work here and move completed or superseded task detail to `Historical or Closed Tasks`.

- Current status: Feature folder created; implementation not started.
- Current implementation slice: Phase 0 scope, safety, and architecture contracts.
- Remaining open task count: 38
- Last passing validation: Documentation-only path, file existence, roadmap-detail preservation, and citation-index checks in this session; no Godot ripple validation has run.
- Next recommended action: Lock Phase 0 decisions and branch safety before any code, shader, scene, or generated-resource edits.
- Known deferred work: Flow-aware ripples, physics-facing ripple sampling, WaterSystem changes, saved persistence, and buoyancy behavior.

## Open Work

Use this section as the canonical checklist for unfinished ripple work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and `handoff-latest.md`.

- [ ] Phase 0: Confirm first milestone is visual-only.
  - Validate: Spec, plan, and review state no first-pass flow, final-flow, WaterSystem, or physics-facing behavior.

- [ ] Phase 0: Confirm no source-signature bump is needed.
  - Validate: Implementation plan and final diff leave source-signature logic and metadata unchanged.

- [ ] Phase 0: Confirm no river bake resources or saved `RiverBakeData` resources are changed.
  - Validate: Git/resource diff shows no generated river bake maps, saved river resources, or bake metadata changes.

- [ ] Phase 0: Confirm no WaterSystem bake, regeneration, or runtime map behavior is changed.
  - Validate: `WaterSystem` resources, `system_flow.gdshader`, WaterSystem bake outputs, and runtime WaterSystem sampling paths are unchanged.

- [ ] Phase 0: Confirm no buoyancy, object drift, reverse-flow, or eddy-circulation behavior changes.
  - Validate: Buoyancy scripts and runtime movement behavior remain outside the first visual ripple slice.

- [ ] Phase 0: Choose the first demo scenario.
  - Validate: Decision log names ducks, click/test emitters, rain, static emitters, or another concrete scenario.

- [ ] Phase 0: Lock `world_to_ripple_uv` as the only production mapping input.
  - Validate: Plan has no separate min/size shader path except debug-only mirrors.

- [ ] Phase 0: Decide axis-aligned X/Z bounds versus full transformed fields for the first implementation.
  - Validate: Unsupported transform cases are documented with warning behavior.

- [ ] Phase 0: Choose target river mesh-footprint rendering as the first boundary-mask source or record a revised accepted source.
  - Validate: Plan explicitly rejects direct UV2-atlas bake textures as first-pass world-space masks.

- [ ] Phase 0: Choose the material ownership path.
  - Validate: Plan records RiverManager-facing runtime API, per-target duplication/restore, or instance shader parameters with evidence.

- [ ] Phase 0: Decide built-in custom type registration versus prototype/example nodes.
  - Validate: `plugin.gd` work is either planned or explicitly out of public API scope.

- [ ] Phase 0: Choose debug parity path.
  - Validate: `river_debug.gdshader`, separate `WaterRippleField` views, or targeted probes are named before visible integration.

- [ ] Phase 0: Record shader cost budget.
  - Validate: Disabled path target and enabled sample count target are in `spec.md`, `plan.md`, and `validation.md`.

- [ ] Branch safety: Create or confirm a dedicated feature branch before implementation.
  - Validate: User confirms branch, Codex creates one, or user explicitly approves continuing on current branch.

- [ ] Phase 1: Add `addons/waterways/shaders/runtime/ripple_simulation.gdshader`.
  - Validate: Shader parses and implements a damped feedback step without copied reference code.

- [ ] Phase 1: Build a standalone no-readback feedback spike.
  - Validate: A ripple texture animates, rings spread and decay, and normal runtime does not call viewport image readback.

- [ ] Phase 1: Document feedback ownership.
  - Validate: Read target, write target, swap timing, clear mode, update mode, impulse clear behavior, pause/resume, and scene reload behavior are recorded.

- [ ] Phase 1: Verify texture precision at 128, 256, and 512.
  - Validate: Decay remains stable enough for first-pass visual use or limitations are documented.

- [ ] Phase 2: Implement `world_to_ripple_uv` generation.
  - Validate: Fixed world-space markers land at expected ripple UVs.

- [ ] Phase 2: Implement equivalent shader mapping.
  - Validate: Debug texture markers and scene markers agree.

- [ ] Phase 2: Render target river mesh footprint into boundary mask.
  - Validate: Boundary debug view matches visible water footprint.

- [ ] Phase 2: Feed boundary mask into simulation and impulse rejection.
  - Validate: Waves stop or fade at dry areas and field edges.

- [ ] Phase 3: Add internal `i_ripple_*` uniforms to `river.gdshader`.
  - Validate: Missing or disabled ripple texture produces no visible effect.

- [ ] Phase 3: Add safe ripple height and normal sampling helpers.
  - Validate: Enabled near-camera path stays within the Phase 0 sample budget.

- [ ] Phase 3: Blend ripple normals into existing normal response.
  - Validate: Ripples do not replace flow animation, pillows, wakes, or eddy-line material behavior.

- [ ] Phase 3: Implement selected debug parity path.
  - Validate: Raw ripple, impulse, boundary, and visible influence are inspectable.

- [ ] Phase 4: Create `water_ripple_field.gd` and any needed scene.
  - Validate: A scene can add the field, initialize it, disable it, and clean it up.

- [ ] Phase 4: Add RiverManager-facing runtime uniform API or selected ownership adapter.
  - Validate: Two rivers can have separate fields without material cross-talk.

- [ ] Phase 4: Add warnings and lifecycle cleanup.
  - Validate: Invalid setup leaves river materials unchanged and scene reload leaves no stale texture state.

- [ ] Phase 4: Update `plugin.gd` only if nodes are built-in public API.
  - Validate: Registration status matches docs and inspector expectations.

- [ ] Phase 5: Create `water_ripple_emitter.gd`.
  - Validate: Fixed, moving, continuous, and one-shot modes work or deferred modes are documented.

- [ ] Phase 5: Add emitter filtering, caps, priority, and bounds checks.
  - Validate: Out-of-bounds or dry-area emitters do not create visible impossible waves.

- [ ] Phase 6: Integrate a demo scene.
  - Validate: Demo shows localized ripples and disabling returns the old visual baseline without changing bakes.

- [ ] Phase 7: Add debug and validation probes.
  - Validate: Probes catch mapping drift, material cross-talk, stale debug state, readback violations, and accidental bake changes.

- [ ] Phase 8: Measure performance and tune defaults.
  - Validate: 128/256/512, no emitters, few emitters, many emitters, shader disabled, and shader enabled results are recorded.

- [ ] Phase 9: Add authoring controls and presets only after runtime behavior is accepted.
  - Validate: Users can configure ripples without editing shader code and without unstable internal plumbing exposed accidentally.

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

- [ ] Implement the runtime feedback spike before visible river integration.
  - Validate: No readback, no same-target read/write, rings spread and decay, scene reload is clean.

- [ ] Implement mapping and boundary mask before visible river integration.
  - Validate: World-space markers, texture-space impulses, boundary debug view, and visible river footprint agree.

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
