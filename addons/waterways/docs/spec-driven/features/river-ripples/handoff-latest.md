# Session Handoff: River Ripples

## Date

2026-06-07

## Current Focus

Continue the spec-driven runtime river ripple spike toward safe river integration.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-ripples\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

This is the handoff dashboard. Keep it short, concrete, and current.

- Overall status: Phase 0 decisions locked; standalone Phase 1 feedback spike, standalone Phase 2 mapping probe, standalone Phase 2 target river mesh-footprint boundary-mask probe, RiverManager-facing material ownership/restore probe, minimal built-in river shader neutral-path probe, river shader sampling-budget probe, minimal visible normal-blend probe, demo-backed visible review scene, debug parity path, shader-cost probe, reusable `WaterRippleField`/`WaterRippleEmitter` prototype workflow, field/emitter dispatch-performance probe, and demo-backed field/emitter authoring scene added. Automated feedback, mapping, boundary, material ownership, river shader neutrality, helper-budget, visible-normal, review-scene smoke, review-scene diagnostic, debug parity, shader-cost/performance, field/emitter lifecycle, field/emitter dispatch-performance, and demo-backed field/emitter authoring validation passed; human-visible feedback, mapping, boundary, demo-backed minimal visible normal blending, and demo-backed debug parity passed.
- Highest-priority open task: Human-rerun the terrain-aware demo-backed `WaterRippleField` / emitter authoring workflow.
- Last passing validation: post-clear-fix Godot 4.6.3 console `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, regression `RIPPLE_SHADER_COST_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`, user-visible `ripple_boundary_mask_review.tscn`, `ripple_mapping_review.tscn`, `ripple_feedback_review.tscn`, and demo-backed `ripple_river_shader_visible_normal_review.tscn` visible/debug reviews, static runtime-readback review, and forbidden-file diff on 2026-06-07.
- Known failing or unproven check: Human-visible acceptance of the revised terrain-aware `WaterRippleField`/emitter authoring scene, non-Forward+ renderer coverage, public custom type/API polish, and response/refraction/displacement tuning are unproven.
- Next recommended action: Ask the user to rerun `ripple_field_emitter_demo_review.tscn` and report whether the blue/green/orange markers and emitter handles now sit over exposed river water, whether F pulses land under them, and whether Space/stop/reload still restore the baseline. Keep response, refraction, displacement, final flow, WaterSystem, bakes, source signatures, and buoyancy out of scope.
- Packaging/artifact hygiene status: No bakes or generated resources created; repo-local `.codex-research\godot-user` was used for Godot console profile isolation, `.codex-research\ripple-feedback-analysis` holds disposable validation captures, and `.codex-research\ripple-review-diagnostic` holds disposable review-scene diagnostic captures.
- Historical detail starts at: `Historical Change Log`.

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- Use `tasks.md` for active work, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and the shared citations index only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-ripples\tasks.md`
5. `addons\waterways\docs\spec-driven\features\river-ripples\review.md`
6. `addons\waterways\docs\spec-driven\features\river-ripples\validation.md`
7. `addons\waterways\docs\spec-driven\features\river-ripples\plan.md`
8. `addons\waterways\docs\spec-driven\features\river-ripples\spec.md`
9. `addons\waterways\docs\spec-driven\features\river-ripples\research.md`
10. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Phase 0 decisions are already confirmed for this branch. Do not reopen them unless new evidence appears.
- Boundary masking is now proven for the standalone gate; do not redo it unless new evidence appears.
- Official Godot 4.6 docs checked for the field/emitter workflow: node lifecycle, `SubViewport`, `ViewportTexture`, resource ownership, editor `@tool` boundaries, and `ShaderMaterial` material-parameter APIs. The new source notes are recorded in `research.md` and `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. The main false-premise risk is treating first-pass visual ripples as flow, buoyancy, or WaterSystem behavior.
- Latest human-visible finding: User confirmed all demo debug views work in the currently expected ways, then caught that the first field/emitter authoring scene had misaligned emitters with two embedded in terrain. The terrain-aware authoring fix moved the markers, but the next visible pass showed no emitter ripples: boundary and raw height looked uniform, impulse/contact was blue everywhere, the green one-shot did not visibly flash, and visible influence was black. A focused diagnostic found the impulse viewport was clearing to a nonzero project color (`min=0.30196`) instead of black. `WaterRippleField` offscreen canvas viewports now use transparent zero clear, the demo probe now rejects full-field impulse/contact sheets, and post-fix diagnostics show localized impulse stamps for all three emitters.

## What Changed This Session

- `addons\waterways\docs\spec-driven\features\river-ripples\`: Created new feature folder.
- `spec.md`: Captured user goals, non-goals, requirements, acceptance tests, visual validation, performance, open questions, and decision log from the runtime ripple roadmap.
- `plan.md`: Captured runtime architecture, data model, lifecycle, files to change, validation strategy, risks, and adversarial plan review.
- `tasks.md`: Converted the roadmap phases into ordered implementation and validation tasks.
- `research.md`: Summarized the research direction, options, Godot unknowns, and context challenge notes.
- `validation.md`: Tracks passing feedback ownership and analysis probes, human-assisted review steps, Godot launch instructions, and future checks.
- `review.md`: Records docs setup, Phase 0 decisions, standalone feedback validation, and remaining implementation gates.
- `handoff-latest.md`: Added this dashboard and next-session instructions.
- Follow-up docs tightening: Preserved concrete roadmap details for field properties, emitter properties, `i_ripple_*` uniforms, shader behavior, authoring controls, and split Phase 0 safety gates.
- Standalone feedback implementation: Added runtime ripple simulation and impulse shaders, feedback review scene, ownership probe, and 128/256/512 analysis probe.
- Standalone boundary-mask implementation: Added a target river mesh-footprint mask shader, review scene, and console probe; added boundary texture injection to the standalone feedback review path for validation-only dry impulse and cross-bank checks.
- Material ownership implementation: Added RiverManager owner-scoped runtime ripple material API plus `ripple_material_ownership_probe.gd`, proving planned `i_ripple_*` state applies to intended targets through duplicated runtime materials and restores on clear, owner exit, and river exit.
- Minimal river shader neutral path: Added the planned neutral-default `i_ripple_*` uniforms to `river.gdshader`, updated the material ownership probe so the built-in river shader now accepts runtime ripple state through duplicated materials, and added `ripple_river_shader_neutral_probe.gd` to prove disabled or missing ripple textures remain pixel-identical to baseline.
- Safe shader sampling helpers: Added guarded height, boundary, world-to-ripple-UV, distance-fade, and normal-offset helper functions to `river.gdshader` without visible blending, plus `ripple_river_shader_sampling_probe.gd` to prove the helper-only slice compiles, the visible fragment path remains untouched, and the first normal helper stays at three simulation samples and one boundary-mask helper call.
- Minimal visible normal blending: Corrected river shader `world_to_ripple_uv` sampling to use mapped X/Z, blended the guarded ripple normal offset into `NORMAL_MAP`, kept custom screen refraction on the pre-ripple normal, updated the sampling probe, and added visible-normal render plus demo-backed review-scene probes. Follow-up review-scene ergonomics now instantiate `Demo.tscn` as an editor-visible child, derive clustered review ripple centers from the demo river mesh, start runtime review on a close-overhead camera at strength `1.25`, preserve the demo material `flow_speed`, precompute 48 review ripple frames, swap frame textures during playback, and provide movement/zoom/right-mouse-look controls.
- Demo review diagnosis: Added `ripple_river_shader_visible_normal_review_diagnostic.gd`, switched the review scene to clustered mesh-derived annular centers focused on actual water positions, diagnosed the user-reported frozen-flow/static-texture and harsh-framerate fixture issues, and proved the active rendered material, center projection, mesh tangents, ripple texture slope, preserved `flow_speed=1.0`, precomputed frame reuse, and enabled-vs-zero-strength image delta through `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`.
- Debug parity: Added raw ripple height, impulse/contact, boundary mask, and visible influence modes to `river_debug.gdshader` and the debug view menu; added neutral `i_ripple_impulse_texture` plumbing to the visible/debug material runtime state; expanded the demo review scene controls with 0/4/5/6/7 visible/debug switching; and added `ripple_debug_parity_probe.gd`, which proves debug switching preserves runtime ripple textures and animation state.
- Reusable field/emitter workflow: Added prototype `water_ripple_field.gd`, `water_ripple_field.tscn`, `water_ripple_emitter.gd`, and `water_ripple_emitter.tscn` without public custom type registration. The field owns runtime ping-pong simulation, additive impulse, and boundary-mask `SubViewport` targets, generates mesh-footprint masks from intended river targets, applies owner-scoped `i_ripple_*` state through RiverManager, rejects invalid/out-of-bounds impulses, caps/sorts emitters, and clears material state on disable/free. The emitter supports pulse, continuous, one-shot, and moving modes with explicit field path, ancestor, or group fallback.
- Field/emitter validation: Added `ripple_field_emitter_probe.gd` and `ripple_field_emitter_performance_probe.gd`; split the runtime multi-emitter additive stamp into `ripple_impulse_additive.gdshader` while keeping the original standalone impulse shader compatible with feedback analysis. `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, and the regression sweep passed.

## Current Changes Summary

Use this for the latest session only. Move older entries into "Historical Change Log" when this gets long.

- Standalone ripple feedback shaders, mapping review, boundary-mask review, material ownership probe, river shader neutral probe, river shader sampling-budget probe, visible-normal render probe, demo-backed visible normal review scene, debug parity probe, shader-cost probe, reusable field/emitter prototype, and field/emitter performance probe were added. Automated Godot 4.6.3 Forward+ validation passes for ping-pong ownership, no normal-runtime readback, fixed impulse response, spread/decay, 128/256/512 behavior, fixed world-space marker mapping, target river mesh-footprint boundary masking, RiverManager-facing material ownership/restore, built-in river shader disabled/missing-texture neutrality, helper-level river shader sampling budget, visible normal response, review-scene apply/toggle/restore, preserved demo `flow_speed`, precomputed review-texture frames, no playback-time image generation, revised review-scene diagnostic visibility, debug parity, current shader-cost/performance, field/emitter lifecycle/cleanup, and field/emitter dispatch performance. The review scene now starts on a close-overhead camera, derives three clustered mesh-anchored annular ripple centers, starts at readable strength `1.25`, uses `2.0` and `4.0` for stronger comparisons, preserves base river motion, swaps precomputed ripple frames outward, and includes 0/4/5/6/7 visible/debug switching, WASD/QE movement, right-mouse-look, mouse-wheel zoom, C camera cycling, and R reset. User-visible review confirmed the center pulse spreads outward and decays, confirmed the mapping scene's colored markers agree with the matching texture impulses, confirmed the boundary mask shows the expected split river footprint with the dry gap dark, caught the now-fixed frozen-flow/static-texture demo fixture bug, caught the now-fixed harsh enabled-framerate review fixture issue, confirmed the precomputed-frame fix greatly improved framerate, confirmed the demo river keeps moving while the ripple rings expand outward, and confirmed all debug views work in the currently expected ways. Latest shader-cost probe metrics: disabled-ready and visible-fragment direct ripple samples `0`, enabled normal helper `3` simulation samples plus `1` boundary helper call, 640x360 median GPU baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`, debug raw/contact/boundary/influence `0.115/0.118/0.117/0.129 ms`, all with one draw call. Field/emitter dispatch medians for 0/4/16 emitters were `5.933/5.738/5.755 ms` at 128, `5.981/5.518/5.799 ms` at 256, and `5.511/6.202/5.866 ms` at 512. The demo authoring gate is now covered by the new field/emitter review scene; human-visible acceptance remains open.
- Added `ripple_field_emitter_demo_review.tscn`, `ripple_field_emitter_demo_review.gd`, and `ripple_field_emitter_demo_review_probe.gd`. The scene instances `Demo.tscn`, adds a real inspectable `WaterRippleField`, and uses three inspectable emitter children for pulse, one-shot, and moving authoring. `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed in Godot 4.6.3 Forward+ and validated demo river targeting, generated mesh-footprint boundary masking, fixed emitter UV placement, moving emitter path bounds, rendered impulse stamps, preserved `flow_speed=1.0`, field disable baseline restore, re-enable, and reload cleanup. The next gate is human-visible review of this new scene.
- User-visible review caught the first field/emitter authoring placement as visibly wrong: two emitters were embedded in terrain. The review controller now samples `World/HTerrain`, chooses exposed river-mesh anchors near the authored UV targets, lifts emitter handles and markers above terrain for inspection, keeps the moving marker synced to the moving emitter, expands the moving path into terrain-aware samples, and reports terrain clearance in `get_review_status()`. The updated probe now rejects buried water anchors, handles, markers, and moving-path samples; terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` passed on 2026-06-07. Human-visible rerun remains open.
- User-visible rerun then showed no visible emitter ripples. The new `ripple_field_emitter_demo_review_diagnostic.gd` reproduced the debug symptoms and found the runtime impulse texture had a nonzero full-field background (`min=0.30196`, `changed_count=65536`), making impulse/contact blue everywhere and producing flat/nonlocal height with no visible influence. `water_ripple_field.gd` now clears its canvas `SubViewport` targets with transparent zero background; the diagnostic now reports impulse `min=0.0`, `mean=0.000208`, `changed_count=118`, and localized blue/green/orange emitter samples. `ripple_field_emitter_demo_review_probe.gd` now rejects nonblack impulse backgrounds and still passes. Human-visible rerun remains open.

## Historical Change Log

Older change history can live here once the current summary is enough for the next agent.

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Create `river-ripples` as a dedicated feature folder | The roadmap has enough architecture and validation gates to warrant spec-driven tracking | Use this folder before ripple implementation |
| Rename the copied handoff template to `handoff-latest.md` | `01-workflow.md` requires that convention | Keep future handoff updates in this file |
| Keep first-pass ripples visual-only in docs | Roadmap explicitly says not to alter bakes, WaterSystem, flow, or buoyancy | Challenge physics-facing requests before patching |
| Treat Phase 0 decisions as open gates | The roadmap lists them as acceptance prerequisites | Resolve them before implementation |
| Preserve concrete roadmap details in `spec.md` and `plan.md` | Exact field properties, emitter properties, shader uniforms, and authoring controls should not disappear during implementation | Use those sections before adding public API or shader uniforms |
| Mark the citation-index check complete | The shared citations index already includes the CBerry22 ripple simulation repository | Recheck only when new external sources influence implementation |

## Current State

Implementation status:

- Standalone Phase 1 feedback spike, standalone Phase 2 mapping probe, standalone Phase 2 boundary-mask probe, RiverManager material ownership path, minimal built-in river shader neutral uniform path, guarded river shader sampling helpers, minimal visible normal blending, revised demo-backed visible normal review scene, debug parity path, shader-cost path, prototype field/emitter workflow, and demo-backed field/emitter authoring workflow added. Human-visible normal-blend and debug-view acceptance are complete for the current gate; human-visible field/emitter authoring acceptance remains open.

Spec/plan status:

- Research: Updated with official Godot 4.6 Node, SubViewport, ViewportTexture, Resource, editor `@tool`, CanvasItem shader, spatial shader, shading-language, built-in shader function, ShaderMaterial, RenderingServer timing, Time timing, screen-reading constraints, local boundary-mask probe findings, material ownership probe findings, river shader neutral-path probe findings, shader sampling-helper findings, the X/Z mapping correction, visible-normal probe findings, demo review-scene diagnostic findings, debug parity findings, shader-cost findings, field/emitter lifecycle findings, and field/emitter performance findings.
- Spec: Drafted and updated for standalone feedback, mapping, boundary-mask, material ownership, river shader neutral-path, helper-budget, visible-normal validation, revised demo review-scene diagnostic status, debug parity status, shader-cost validation, prototype field/emitter lifecycle, and field/emitter performance validation.
- Plan: Drafted and updated for standalone feedback, mapping, boundary-mask, material ownership, river shader neutral-path, helper-budget, visible-normal validation, revised demo review scene status, debug parity status, shader-cost validation, prototype field/emitter workflow, and field/emitter performance validation.
- Tasks: Drafted with Phase 0 through future work.
- Validation: Passing standalone feedback checks, mapping check, boundary-mask check, RiverManager material ownership check, river shader neutral check, river shader sampling-budget check, visible-normal render check, revised demo review-scene smoke/diagnostic checks, debug parity check, shader-cost check, field/emitter lifecycle check, field/emitter performance check, user-visible feedback/mapping/boundary/debug reviews, and user-reported frozen-flow plus enabled-framerate fixture failures/fixes recorded.
- Review: Partial review complete through demo-backed field/emitter authoring console validation; human-visible field/emitter authoring acceptance is the next gate.

Validation status:

- Automated:
  - `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`
  - `RIPPLE_FIELD_EMITTER_PROBE_OK`
  - `RIPPLE_SHADER_COST_PROBE_OK`
  - `RIPPLE_DEBUG_PARITY_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`
  - `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`
  - `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`
  - `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`
  - `RIPPLE_BOUNDARY_MASK_PROBE_OK`
  - `RIPPLE_MAPPING_PROBE_OK`
  - `RIPPLE_FEEDBACK_PROBE_OK`
  - `RIPPLE_FEEDBACK_ANALYSIS_OK`
- Human-assisted:
  - User confirmed `ripple_feedback_review.tscn` center pulse spreads outward and decays.
  - User confirmed `ripple_mapping_review.tscn` colored scene markers agree with matching colored texture impulses.
  - User confirmed `ripple_boundary_mask_review.tscn` shows the expected river-shaped white boundary mask with the dry gap dark and dry sample markers outside the footprint.
  - User confirmed all debug views in `ripple_river_shader_visible_normal_review.tscn` work in the currently expected ways.
- Shader:
  - Standalone runtime feedback and impulse shaders compile through the probes; built-in `river.gdshader` declares neutral-default `i_ripple_*` uniforms including the unsampled impulse/contact texture, maps world X/Z into ripple U/V, has guarded ripple height/normal sampling functions, blends ripple normal offsets into `NORMAL_MAP`, keeps direct height sampling out of `fragment()`, and remains pixel-identical to baseline for disabled/missing texture cases. The custom screen-refraction path still uses the pre-ripple normal for this normal-only slice. `river_debug.gdshader` exposes raw height, impulse/contact, boundary mask, and visible influence modes.
- Editor:
  - None.
- Visual:
  - Standalone center pulse spread/decay accepted; standalone mapping marker/texture agreement accepted; standalone boundary-mask shape/dry-gap review accepted. Automated render and diagnostic probes prove visible normal response exists in the revised demo-backed view while preserving flow speed and reusing precomputed animated texture frames; human-visible demo review confirms the river keeps moving and rings expand outward. Automated debug renders prove raw height, impulse/contact, boundary, and visible-influence views are distinct/nonblank.
- Runtime:
  - Standalone feedback, mapping, and boundary review/probe runtime paths, plus RiverManager-facing owner-scoped runtime material API, built-in river shader visible/debug paths, prototype `WaterRippleField`, and prototype `WaterRippleEmitter`. The demo-backed review scene applies, toggles, switches debug views, and restores runtime ripple state without saving demo changes; the reusable field/emitter prototype applies, steps, disables, and frees cleanly in console validation.
- Performance:
  - Review-scene fixture upload cost addressed with precomputed frame textures. Current river shader-cost probe passes: disabled-ready and visible-fragment direct ripple samples `0`, enabled normal helper remains at `3` simulation samples plus `1` boundary helper call, 640x360 median GPU enabled visible normal is `0.319 ms` versus disabled live textures `0.315 ms`. Field/emitter dispatch sweeps pass at 128/256/512 with 0/4/16 emitters; human-visible demo production performance and non-Forward+ coverage remain open.
- Manual:
  - Roadmap and templates were read and converted into the feature folder.

## Important Context

- First milestone is visual-only.
- Do not touch river bake resources, source signatures, WaterSystem bake resources, final flow, `system_flow.gdshader`, or buoyancy for first-pass ripples.
- `filter_renderer.gd` proves shader passes exist but is bake-oriented and uses readback; do not copy that runtime pattern into ripple simulation.
- `world_to_ripple_uv` is the intended single production mapping contract. The river shader now follows the standalone contract by using mapped world X/Z as ripple U/V.
- Exact first-pass river shader uniform names, field properties, emitter properties, and authoring-control notes are preserved in `spec.md` and `plan.md`.
- Boundary masking is required before visible river overlay. The accepted first source is target river mesh footprint rendering, not direct UV2 atlas bake textures; the standalone gate now has `RIPPLE_BOUNDARY_MASK_PROBE_OK`.
- Material ownership is proven for the current RiverManager-facing gate; preserve owner-scoped apply/clear and per-target material duplication/restore when adding shader integration.
- Shader sampling, visible normal blending, and current shader-cost are proven for the automated gate; preserve the disabled/missing-texture guard, world X/Z mapping, one visible normal helper call, no direct visible height sampling, the three simulation sample budget, and the no-added-draw-call cost profile.
- Debug parity is proven for the current automated gate; preserve the raw height, impulse/contact, boundary mask, and visible influence modes, and preserve runtime texture state when switching visible/debug materials.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`. Future sessions should use it as the project-level list of river-reading, hydrology, flow-map, shader-water, and production-example sources, and update it when new external references influence this feature.

## Artifact Hygiene

- Scratch folders or temporary projects created:
  - `.codex-research\godot-user`
  - `.codex-research\ripple-feedback-analysis`
  - `.codex-research\ripple-review-diagnostic`
- Generated bakes/resources created:
  - No bakes. Godot generated `.uid` sidecars for earlier probe scripts and runtime shaders after editor review. The new field/emitter scripts, scenes, probes, `ripple_boundary_mask.gdshader`, and `ripple_impulse_additive.gdshader` did not need bake resources; let the editor/import step create any missing `.uid` sidecars later if needed.
- Active files mirrored into scratch validation:
  - None.
- Files/folders that must be excluded from packaging:
  - `.codex-research` probes or local captures unless promoted.
- Files/folders safe to delete now:
  - None.

## Known Risks and Open Issues

- No-readback ping-pong feedback is proven for the standalone Godot 4.6.3 Forward+ console probe.
- Target river mesh-footprint boundary masking is proven for the standalone Godot 4.6.3 Forward+ console probe. The probe rendered a generated Waterways river mesh through `world_to_ripple_uv`, measured non-rectangular coverage at about `10.43%`, rejected a dry-corner impulse with `max_delta=0.0`, kept the dry gap neutral, and kept the across-bank sample below threshold.
- Texture precision at 128/256/512 is proven by automated validation readback, but still needs human visual review.
- Human-visible standalone spread/decay is proven; the observed square outline is a placeholder rectangular-field artifact and must not ship into river integration.
- Material ownership implementation is proven enough for the current gate through `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`; the path is RiverManager-facing `i_ripple_*` runtime ownership with per-target material duplication and restore.
- Shader sampling and minimal visible normal blending are proven enough for the current gate through `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, and human-visible demo review. Human review first found no visible rings, then found visible rings that froze flow and did not expand, then found the enabled path dropped framerate harshly. Those were fixture problems: center/camera readability, temporary `flow_speed=0.0` material overrides, a static review texture, and per-frame GDScript image generation. The revised scene preserves flow speed, starts at strength `1.25`, precomputes 48 texture frames, swaps texture references during playback, keeps the river moving, and expands rings outward. Initial validation found that Godot's spatial built-ins should be passed into helper functions instead of read directly from global helper scope.
- Debug parity is proven enough for the current gate through `RIPPLE_DEBUG_PARITY_PROBE_OK`. The first validation run caught a shader `fragment()` `return` that Godot rejected; the final path uses branch-wrapped fragment logic and exposes raw height, impulse/contact, boundary mask, and visible influence without losing runtime texture state across debug mode switches.
- Reusable field/emitter lifecycle is proven enough for the current console gate through `RIPPLE_FIELD_EMITTER_PROBE_OK`. The prototype field owns runtime viewports/textures, generates target mesh-footprint masks, applies owner-scoped material state, rejects invalid/out-of-bounds impulses, caps/sorts emitter impulses, avoids normal-runtime readback, and clears state on disable/free. Human-visible demo authoring and editor reload review remain open.
- Reusable field/emitter dispatch performance is proven enough for the current Forward+ console gate through `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` at 128/256/512 and 0/4/16 emitters. Non-Forward+ renderer coverage and demo production review remain open.
- Public custom type registration is intentionally deferred; current status is prototype/example nodes first.
- Full transformed field support is intentionally deferred; current first path is axis-aligned X/Z fields.
- A rectangular debug simulation can look good while still being invalid for river integration; use the mesh-footprint boundary probe as the current standalone guard.
- Users may expect visual ripples to affect buoyancy; that is intentionally out of scope for the first milestone.

Relevant audit sections:

- `addons\waterways\docs\audit\pillow-system-audit.md` was checked before the mapping probe; no ripple-specific blocker was found there.

## Blockers

- Active implementation blocker: none for the diagnosed review-fixture, debug-parity, shader-cost, field/emitter lifecycle/performance, or demo authoring console issues; next gate is human-visible `WaterRippleField` / emitter authoring review.
- Phase 0 decisions and branch safety are satisfied on branch `ripples`.
- Visible Godot/editor/runtime validation will be human-assisted unless an agent can genuinely inspect the running editor.

## Files To Inspect Before Editing

- `addons\waterways\docs\roadmaps\runtime-ripple-simulation-roadmap.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\spec.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\plan.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\tasks.md`
- `addons\waterways\docs\spec-driven\features\river-ripples\validation.md`
- `addons\waterways\river_manager.gd`
- `addons\waterways\filter_renderer.gd`
- `addons\waterways\system_map_renderer.gd`
- `addons\waterways\shaders\river.gdshader`
- `addons\waterways\shaders\river_debug.gdshader`
- `addons\waterways\plugin.gd`

## Commands or Checks Used

```powershell
Get-Content -Raw -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\roadmaps\runtime-ripple-simulation-roadmap.md'
```

Result summary:

- Read the runtime ripple roadmap and preserved its visual-only scope and hard constraints.

```powershell
Get-ChildItem -Force -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\spec-driven\templates\feature-folder'
```

Result summary:

- Found template files: `plan.md`, `research.md`, `review.md`, `session-handoff.md`, `spec.md`, `tasks.md`, and `validation.md`.

```powershell
Test-Path -LiteralPath 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways\docs\spec-driven\features\river-ripples'
```

Result summary:

- Confirmed the folder did not exist before creation.

```powershell
$root = 'C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo'
$godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe'
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
```

Result summary:

- Passed with `RIPPLE_BOUNDARY_MASK_PROBE_OK`. The probe rendered a generated Waterways river mesh footprint into ripple-field space, measured about `10.43%` non-rectangular mask coverage, rejected a dry-corner impulse with `max_delta=0.0`, kept the dry gap neutral, and kept the across-bank sample below threshold after 40 steps.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
```

Result summary:

- Existing gates still passed after the boundary hook: `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
```

Result summary:

- Historical pre-neutral-path result: passed with `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`. At that time, the material ownership probe still rejected the built-in river shader until `river.gdshader` declared `i_ripple_*`; the newer run below supersedes that expectation.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
```

Result summary:

- Passed with `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`. The neutral probe reported `max_delta=0.0` and `mean_delta=0.0` for disabled-with-textures, enabled-missing-simulation-texture, and enabled-missing-boundary-texture render comparisons against the baseline river shader. The material ownership probe now reports `default_shader_apply_accepted=true` for the built-in river shader.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_sampling_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
```

Result summary:

- Passed with `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, profile-isolated `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, and `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`. The sampling probe reported `world_to_uv_uses_xz=true`, `normal_helper_simulation_samples=3`, `normal_helper_boundary_calls=1`, `height_helper_simulation_samples=1`, `height_helper_boundary_calls=1`, one `ripple_normal_offset_at_world()` call from `fragment()`, and zero direct height calls from `fragment()`. The visible-normal probe reported zero delta for disabled/flat/black-boundary cases and visible delta for an enabled wave texture. The review-scene probe proved `ripple_river_shader_visible_normal_review.tscn` loads `Demo.tscn`, applies/toggles/restores runtime ripple state, starts in `close overhead` camera mode, keeps the review camera current, derives three mesh-based ripple centers, starts at strength `1.25`, preserves `runtime_flow_speed=1.0`, precomputes 48 frames, advances `ripple_texture_frame`, and does not increase `ripple_image_generation_count` during playback. The diagnostic proved active material state, center projection, mesh tangents, ripple texture slope, preserved flow speed, precomputed frame reuse, and visible enabled-vs-zero-strength delta in the revised view.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_sampling_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_diagnostic.gd'
```

Result summary:

- Passed with `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, and `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`. The debug parity probe confirmed the shader/menu contract, visible/debug runtime texture preservation, review-scene debug state preservation, and nonblank contrast for raw height (`0.27058823406696`), impulse/contact (`0.81960785388947`), boundary mask (`0.81960785388947`), and visible influence (`0.82091504335403`).

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_performance_probe.gd'
```

Result summary:

- Passed with `RIPPLE_FIELD_EMITTER_PROBE_OK` and `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`. The lifecycle probe validated prototype field/emitter scene/script loading, distinct read/write/impulse/boundary runtime targets, target mesh-footprint boundary-mask generation, owner-scoped material application/clear, out-of-bounds rejection, emitter cap/priority behavior, no same-target feedback hazard, no normal-runtime readback, disable/reenable cleanup, and free cleanup. The performance probe measured field dispatch at 128/256/512 with 0/4/16 emitters; dispatch medians were `5.933/5.738/5.755 ms`, `5.981/5.518/5.799 ms`, and `5.511/6.202/5.866 ms`.

```powershell
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_shader_cost_probe.gd'
```

Result summary:

- Regression sweep passed after the runtime additive impulse shader was split away from the standalone feedback-analysis impulse shader: `RIPPLE_FEEDBACK_ANALYSIS_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK`. Latest shader-cost medians were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`, and debug raw/contact/boundary/influence `0.115/0.118/0.117/0.129 ms`.

## Next Tasks

- [x] Confirm Phase 0 decisions with the user.
- [x] Create or confirm a dedicated branch before code work.
- [x] Build the standalone no-readback feedback spike.
- [x] Validate fixed impulse spread/decay at 128/256/512 with `RIPPLE_FEEDBACK_ANALYSIS_OK`.
- [x] Human-review fixed impulse and debug texture behavior.
- [x] Prove `world_to_ripple_uv` mapping with scene and texture markers.
- [x] Prove target river mesh-footprint boundary mask.
- [x] Prove material ownership and restore behavior.
- [x] Add safe ripple height and normal sampling helpers.
- [x] Add minimal visible ripple normal blending and automated render/review-scene probes.
- [x] Diagnose why visible normal blending was not visible on the demo river review scene despite automated probes passing.
- [x] Human-confirm base flow and outward ring motion in the revised close-overhead demo normal-blend review scene after the precomputed-frame performance fix.
- [x] Implement debug parity for raw ripple height, impulse/contact, boundary mask, and visible influence views.
- [x] Run shader-cost/performance validation before response/refraction/displacement tuning.
- [x] Build the reusable `WaterRippleField` / emitter workflow.
- [x] Validate field/emitter lifecycle, cleanup, material ownership, bounds rejection, caps, and dispatch performance.
- [x] Integrate the reusable field/emitter prototype into a demo/human-visible authoring workflow.
- [ ] Human-review `ripple_field_emitter_demo_review.tscn`.
- [ ] Cover non-Forward+ renderers when the first demo workflow is accepted.

## Do Not Do Yet

- Do not tune visible ripple response, refraction, or displacement in `river.gdshader` as the next step; human-review the reusable field/emitter demo workflow first.
- Do not mutate shared river materials directly.
- Do not change river bakes, WaterSystem bakes, source signatures, final flow, `system_flow.gdshader`, or buoyancy.
- Do not present ripple nodes as public API until registration status is decided.
- Do not implement camera-following fields until reprojection, clear-on-shift, or tile swapping is designed.

## Notes for the Next Agent

Start with human-visible `WaterRippleField` / emitter authoring review, not response tuning, refraction, displacement, final flow, WaterSystem, bakes, source signatures, or buoyancy. The reusable prototype and the new demo-backed authoring scene are console-proven: field lifecycle/cleanup, material ownership, boundary-mask generation, emitter caps/priority, bounds rejection, 128/256/512 dispatch sweeps, demo river targeting, emitter world placement, disable baseline restore, and reload cleanup all pass. The next missing facts are whether `ripple_field_emitter_demo_review.tscn` is visually trustworthy and ergonomic in the visible editor/runtime, and whether non-Forward+ renderers behave acceptably after that.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so Codex does not alter the user's normal Godot editor profile.

Console probe pattern:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://path/to/ripple_probe.gd'
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Validation Commands

Future runtime readback scan after implementation:

```powershell
rg "get_image|ImageTexture|readback|get_texture\\(\\)\\.get_image" "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\addons\waterways"
```

Result summary:

- Record whether any ripple runtime path uses CPU readback. Bake paths may still use readback; the violation is normal runtime simulation or visible rendering.
