# Validation: River Ripples

## What Must Be Proven

- Runtime ripples are visual-only and do not alter flow, WaterSystem, bakes, source signatures, or buoyancy.
- The simulation runs without normal-runtime CPU readback.
- Feedback ownership avoids same-texture read/write hazards.
- Emitters, simulation, debug views, boundary masks, and river shader samples share one `world_to_ripple_uv` mapping.
- Mesh-footprint boundary masking prevents obvious wave leakage through dry areas.
- Runtime material ownership prevents cross-talk between rivers and restores cleanly.
- Debug/probe coverage exposes raw ripple, impulse, boundary, and visible river influence.
- Disabled and missing-texture paths are neutral.
- Enabled river shader path stays within the accepted sample budget.
- Existing pillow, wake, and eddy-line visuals remain recognizable.
- Phase 9 preset resources copy authoring values in memory only, grouped authoring properties stay inspectable, reserved controls stay hidden/storage-only, starter presets avoid unsupported promises, scene/resource reload is clean, and runtime code avoids exported live slots, runtime saves, target/material/bake/source-signature churn, or Phase 10 editor tooling.
- Phase 10 editor tooling stays editor-only, starts with non-mutating read-only status UI, keeps preset selectors transient, applies presets through per-property editor undo, saves captured presets only through explicit user-selected editor paths, cleans up scratch UI/preview state across lifecycle events, never dirties scenes from read-only/selector/capture/preview-only paths, and keeps live-scene runtime commands disabled until a separate bridge is validated.

## Current Validation Snapshot

Keep this short and current. Older detailed runs belong in "Recorded Results" below.

- Overall status: Standalone feedback spike passed console/static validation and human-visible review; standalone mapping probe passed console and human-visible validation; standalone mesh-footprint boundary-mask probe passed console and human-visible validation; RiverManager-facing material ownership/restore, minimal river shader neutral path, river shader visible-normal path, river shader sampling-budget, shader-cost/performance, demo review-scene smoke, demo review-scene diagnostic, debug parity, reusable field/emitter lifecycle, field/emitter dispatch-performance, post-review-strength-boost terrain-aware demo-backed field/emitter authoring, Mobile/Compatibility renderer checks, Phase 9 named-class parser/editor-cache checks, Phase 9 in-memory preset-resource/API, export grouping, built-in starter presets, warning cleanup, scratch scene/resource reload, Phase 10 read-only inspector skeleton, Phase 10 transient preset Apply controls, and Phase 10 capture/save controls passed console/static validation; demo-backed visible normal review passed the current human-visible base-flow/outward-ring gate; demo-backed debug parity, field/emitter visual/debug/control/stop-reload behavior, Add Node visibility, Phase 9 editor authoring surface, Phase 10 read-only inspector lifecycle/dirty-state behavior, and Phase 10 Apply active-preset/undo/no-op/boundary/lifecycle behavior passed human-visible review. Phase 10 capture/save still needs visible editor review.
- Last automated pass: Phase 10 inspector/apply/capture-save contract passed on 2026-06-08 with Godot 4.6.3 Forward+ `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`; the latest pass includes active preset status/selector restoration checks plus capture/save checks for unsaved scratch presets, explicit `.tres` save paths under `.codex-research`, saved preset reload with correct scripts and values, no target routing/reserved value persistence, and no runtime editor/save leakage. Parser checks passed for `ripple_inspector_preset_apply_model.gd`, `ripple_inspector_status.gd`, `ripple_inspector_plugin.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd`; static `git diff --check`, forbidden-call scan, and runtime editor-class/save-path scan stayed clean. Regression `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` also passed. Earlier Phase 9 named Add Node registration passed on 2026-06-07 after adding `class_name` and `@icon` to `WaterRippleField` and `WaterRippleEmitter`; user confirmed both are searchable with icons as child nodes in `Demo.tscn` and `ripple_field_emitter_demo_review.tscn`.
- Last human-assisted result: User confirmed the Phase 10 Apply review on 2026-06-08: changing built-in selectors or matching preset resources did not dirty the scene or create live preset links; `Apply Built-In`, undo, and redo passed for field/emitter use; applying the same actual preset again did not dirty the scene; the neutral `Choose...` row disables Apply; target routing, material/runtime ownership, bake fields, and reserved values did not appear or change; and plugin/scene/node/play-stop lifecycle checks passed without stale UI or Output errors. Earlier, user confirmed the Phase 10 read-only inspector review: status rows appeared for the field and emitters, inspector reselection/lifecycle checks behaved cleanly, no stale duplicated UI or Output errors appeared, and simple read-only inspection did not dirty the scene.
- Highest-risk unproven behavior: Response/refraction/displacement tuning remains separate and unproven. Capture/save is implemented and automated-proven but still needs visible editor save-dialog/dirty-state/restart review. Gizmos, previews, and live-scene commands remain unimplemented and must follow `phase10-editor-polish-plan.md` one mutation category at a time.
- Known unreliable local check or environment caveat: Headless/parser checks can catch syntax or load issues, but they are not proof of visible editor interaction, shader visuals, runtime simulation, or viewport feedback behavior.

## Validation Matrix

Use this as the durable map from requirements to proof. Prefer stable probe names, scene names, or result markers.

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| Visual-only boundary | Git/resource diff after implementation | Local static review | No river bakes, WaterSystem bakes, source signatures, `system_flow.gdshader`, or buoyancy files changed | Pass: forbidden-file diff clean for current spike | 2026-06-07 | Agent |
| Source-signature boundary | Static diff and targeted source-signature scan | Local static review | No source-signature constants, hashes, metadata, or invalidation logic changed | Pass: no source-signature files changed | 2026-06-07 | Agent |
| River bake boundary | Git/resource diff after implementation | Local static review | No generated river bake textures, saved `RiverBakeData`, or bake metadata changed | Pass: no bake files changed | 2026-06-07 | Agent |
| WaterSystem boundary | Git/resource diff and WaterSystem path scan | Local static review | No WaterSystem bake resources, regeneration paths, `system_flow.gdshader`, or runtime WaterSystem sampling behavior changed | Pass: no WaterSystem files changed | 2026-06-07 | Agent |
| Buoyancy boundary | Static diff and runtime behavior review if buoyant objects are present | Local static/human-assisted review | No buoyancy, object drift, reverse-flow, or eddy-circulation behavior changed | Pass: no buoyancy files changed | 2026-06-07 | Agent/User |
| No normal-runtime readback | Static scan for `get_image()` or equivalent in ripple runtime path | Local static review | No readback in normal simulation or visible rendering loop | Pass: no runtime ripple readback; validation-only analysis, mapping, boundary, neutral, visible-normal, debug-parity, and field/emitter probes use `get_image()` only for measurements where needed. Static scan of `water_ripple_field.gd`, `water_ripple_emitter.gd`, and runtime shaders found no normal-runtime `get_image()` path. | 2026-06-07 | Agent |
| Feedback ownership | Standalone ripple feedback probe and review scene | Godot 4.6.3 console/editor | Rings spread and decay; read/write targets are distinct | Pass: distinct targets, no same-target hazard, automated spread/decay analysis, and user-visible ring decay passed; square edge artifact remains standalone-only | 2026-06-07 | Agent/User |
| Texture precision | Ripple feedback analysis probe at 128, 256, 512 | Godot 4.6.3 Forward+ console with validation readback | Waves decay without unusable saturation; ring energy spreads from fixed impulse | Pass: `RIPPLE_FEEDBACK_ANALYSIS_OK` at 128/256/512 | 2026-06-07 | Agent |
| Mapping contract | `ripple_mapping_probe.gd` and `ripple_mapping_review.tscn` | Godot 4.6.3 Forward+ console; human-visible review | Scene markers and debug texture impulses align through one `world_to_ripple_uv` transform | Pass: `RIPPLE_MAPPING_PROBE_OK` for four fixed axis-aligned X/Z markers; user confirmed colored relative positions agree in both views | 2026-06-07 | Agent/User |
| Boundary mask | `ripple_boundary_mask_probe.gd` and `ripple_boundary_mask_review.tscn` | Godot 4.6.3 Forward+ console; visible review scene | Target river footprint is visible; waves do not cross dry areas | Pass: `RIPPLE_BOUNDARY_MASK_PROBE_OK`; mesh-footprint mask coverage about `10.43%`, dry impulse rejected with `max_delta=0.0`, dry gap stayed neutral, across-bank sample remained below threshold, and user screenshot confirmed the visible mask shape/dry gap | 2026-06-07 | Agent/User |
| River shader neutral disabled path | `ripple_river_shader_neutral_probe.gd` | Godot 4.6.3 Forward+ console with validation readback | Declared `i_ripple_*` uniforms; disabled or missing texture paths match baseline | Pass: `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`; disabled-with-textures, enabled-missing-simulation, and enabled-missing-boundary cases all reported `max_delta=0.0` versus baseline | 2026-06-07 | Agent |
| River shader sampling budget | `ripple_river_shader_sampling_probe.gd` plus neutral render probe | Godot 4.6.3 Forward+ console; local static review | Visible normal slice uses the guarded helper once and first normal helper stays within three simulation samples | Pass: `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`; shader mapping uses world X/Z, normal helper uses three simulation texture samples and one boundary-mask helper call, height helper uses one simulation texture sample and one boundary-mask helper call, `fragment()` calls the world normal helper once and does not directly sample ripple height, and follow-up neutral render probe remained `max_delta=0.0` | 2026-06-07 | Agent |
| River shader visible normal render | `ripple_river_shader_visible_normal_probe.gd` | Godot 4.6.3 Forward+ console with validation readback | Disabled, flat, and masked cases stay neutral; enabled wave texture visibly changes normal response | Pass: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`; disabled, flat, and black-boundary cases all reported `max_delta=0.0`; enabled wave texture reported `max_delta=0.75686274468899`, `mean_delta=0.10863875223822`, and `7252` changed pixels | 2026-06-07 | Agent |
| Demo visible ripple review setup | `ripple_river_shader_visible_normal_review_probe.gd`, `ripple_river_shader_visible_normal_review_diagnostic.gd`, and `ripple_river_shader_visible_normal_review.tscn` | Godot 4.6.3 Forward+ console; human-visible review | Demo scene loads, runtime ripple material state applies/toggles/restores without saving demo state, starts on a close overhead inspection camera, derives clustered mesh-anchored review ripple centers, preserves demo material motion, animates the review ripple texture, and keeps the source demo material restorable | Pass for current gate: automated setup pass `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`; diagnostic pass `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK` confirmed active `i_ripple_*` material values, all three centers inside the inspection frame, mesh tangents present, default `i_ripple_normal_strength=1.25`, `flow_speed=1.0`, advancing texture frames, and enabled-vs-zero-strength delta. User rerun confirmed greatly improved enabled framerate, moving base river flow, and outward-expanding ripple rings. | 2026-06-07 | Agent/User |
| River shader enabled path | Demo visible ripple review | Godot 4.6.3 visible/runtime | Local rings appear, move outward, and flow animation, pillows, wakes, and eddy-line visuals remain recognizable | Pass for current minimal normal-blend gate: user review showed the previous fixture froze the flow and used a massive static texture; a later review showed a harsh enabled-framerate drop. Patched fixture now preserves `flow_speed=1.0`, advances precomputed review ripple frames, and diagnostic capture reports `max_delta=0.60392156243324`, `mean_delta=0.01630346588826`, and `39976` changed pixels at default strength `1.25`. User rerun confirmed greatly improved framerate, moving river flow, and outward-expanding rings. Human-visible debug-view review and production visual/performance validation remain separate gates. | 2026-06-07 | Agent/User |
| Demo review fixture animation cost | `ripple_river_shader_visible_normal_review_probe.gd` plus human-visible review | Godot 4.6.3 Forward+ console; human-visible review | Review animation does not generate new images during playback; enabled ripples do not cause a harsh framerate drop | Pass for review fixture cost: probe passes with `ripple_precomputed_frame_count=48` and asserts `ripple_image_generation_count` stays unchanged while `ripple_texture_frame` advances; user rerun confirmed enabled-ripple framerate is greatly improved. Production performance remains a later gate. | 2026-06-07 | Agent/User |
| Debug parity | `river_debug.gdshader`, debug menu, `ripple_debug_parity_probe.gd`, and `ripple_river_shader_visible_normal_review.tscn` controls | Godot 4.6.3 Forward+ console with validation readback; human-visible review scene | Raw ripple, impulse/contact, boundary, and visible influence are inspectable; switching debug views preserves runtime ripple state | Pass: `RIPPLE_DEBUG_PARITY_PROBE_OK`; debug modes `62`-`65` are exposed, runtime visible/debug materials keep ripple textures across mode switches, review texture animation continues, render contrast passed for raw height/contact/boundary/visible-influence views, and user confirmed all views work in the currently expected ways. Contact currently reads as a broad yellow field by design of the fixture texture, not a blocker. | 2026-06-07 | Agent/User |
| Material cross-talk | `ripple_material_ownership_probe.gd` | Godot 4.6.3 Forward+ console with built-in and test-only shader materials | Disabling one field does not affect unrelated river | Pass: `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`; built-in river shader now accepts declared `i_ripple_*` uniforms through a duplicated runtime material, shared source material stayed unchanged, River A/B got distinct runtime duplicates, wrong-owner apply/clear was rejected, and clearing River A left River B runtime texture active | 2026-06-07 | Agent |
| Runtime field/emitter lifecycle | `ripple_field_emitter_probe.gd`, field/emitter scenes, and RiverManager material state | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT | Field initializes, owns runtime targets, maps world impulses, applies only intended material state, caps emitters, rejects invalid impulses, disables cleanly, and frees cleanly | Pass: `RIPPLE_FIELD_EMITTER_PROBE_OK`; runtime initialized with 128x128 read/write/impulse/boundary targets, boundary source `target_river_mesh_footprint`, target/apply counts `1`, distinct viewports/textures, no same-target hazard, no runtime readback, capped emitters reported, out-of-bounds impulse rejected, and disable/free cleanup restored material state | 2026-06-07 | Agent |
| Named Add Node registration | `water_ripple_field.gd`, `water_ripple_emitter.gd`, ripple icons, and `.godot/global_script_class_cache.cfg` | Godot 4.6.3 check-only parser, repo-local headless editor scan, global-class probe, and human-visible editor review | `WaterRippleField` and `WaterRippleEmitter` register as named `Node3D` script classes with icons for Add Node | Pass: `--check-only --script` exits cleanly for the plugin and both ripple scripts; headless editor scan reaches editor layout ready and refreshes the global script class cache; local probe reports `GLOBAL_CLASS_WATER_RIPPLE_FIELD_OK` and `GLOBAL_CLASS_WATER_RIPPLE_EMITTER_OK`; user confirmed both classes and icons are searchable as child nodes in `Demo.tscn` and `ripple_field_emitter_demo_review.tscn`. | 2026-06-07 | Agent/User |
| Phase 9 authoring/API planning | Revised planning doc plus updated spec/plan/tasks/research/review/handoff notes | Local docs review before code | Plan compares Unity, Unreal Engine, Godot editor tooling, Crest, and comparable water/ripple authoring systems; defines script/resource-first export grouping, type-specific one-click presets that mutate editable values, separate field/emitter preset resources, in-memory apply/capture only, no exported preset slots/live links/runtime preset saves, and keeps refraction/displacement/debug helper behavior reserved or hidden from normal authoring; native editor polish is split into Phase 10 | Pass for plan; implementation and human-visible editor authoring review are covered by the next rows. | 2026-06-08 | Agent/User |
| Phase 9 authoring API, grouping, presets, and reload | `WaterRippleFieldPreset`, `WaterRippleEmitterPreset`, field/emitter grouping, `apply_preset()`, `capture_preset()`, `apply_builtin_preset()`, and `ripple_phase9_preset_api_probe.gd` | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT; local static review | Applying presets copies values, source preset edits do not mutate nodes, capture returns fresh in-memory resources, export groups exist without custom inspector tooling, reserved fields are storage-only, built-in starters avoid unsupported promises, runtime saves/live slots are absent, scratch preset resources reload, and scratch scene reload rebuilds transient runtime textures and restores target material state | Pass: `RIPPLE_PHASE9_PRESET_API_PROBE_OK`; parser checks passed for resources, changed nodes, and probe; regression `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` stayed green; static `git diff --check`, runtime preset-save/readback scan, and forbidden-file diff stayed clean. | 2026-06-08 | Agent |
| Phase 9 visible editor authoring workflow | Phase 9 Authoring Human Review Request and `ripple_field_emitter_demo_review.tscn` | Godot 4.6.3 editor, human-visible review | Field/emitter groups are readable, reserved controls stay hidden, Add Node search still finds both ripple nodes by name/icon, and the review scene still runs with localized ripples, debug views, cleanup, and no Output errors | Pass: user confirmed all numbered review items worked as expected; scratch empty-field warnings were expected configuration warnings, not Output errors. | 2026-06-08 | User |
| Phase 10 editor-polish planning | `phase10-editor-polish-plan.md` plus updated dashboard docs | Local docs review before code | Plan defines editor/runtime separation, transient preset selectors, editor-only saving, undo/dirty-state matrix, forbidden editor calls, scratch-resource cleanup, plugin script placement, debug/preview boundaries, live-scene bridge deferral, validation gates, and implementation slices | Pass for planning docs; Phase 10 slice 1 implementation is now covered by the next row. | 2026-06-08 | Agent |
| Phase 10 read-only inspector skeleton | `ripple_inspector_plugin.gd`, `ripple_inspector_status.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd` | Godot 4.6.3 Forward+ console parser/probe plus local static scan; Godot 4.6.3 editor human-visible review | Selecting `WaterRippleField`/`WaterRippleEmitter` shows read-only status rows that use exported values, configuration warnings, or conservative path/group/ancestor summaries only; no read-only path calls runtime rebuild/reset/emission/material/boundary/source-signature/private-resolver APIs; no editor-only class/save-path references leak into runtime field/emitter scripts or preset resources; plugin/selection/scene/play-stop lifecycle stays clean and read-only inspection does not dirty the scene | Pass for automated contract and human-visible lifecycle gate: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` reports six read-only rows for field and emitter models; parser checks passed for inspector/status/probe/plugin scripts; forbidden-call scan and runtime editor-class/save-path scan were clean; regression `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` stayed green. User confirmed the read-only lifecycle/dirty-state review passed with no stale duplicated UI and no Output errors. | 2026-06-08 | Agent/User |
| Phase 10 preset apply | `ripple_inspector_plugin.gd`, `ripple_inspector_preset_apply_model.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd` | Godot 4.6.3 Forward+ console parser/probe plus local static scan; Godot 4.6.3 editor human-visible review | Selector focus does not dirty the scene; no preset slot/path/auto-apply state is serialized; editor Apply copies only the Phase 9 whitelist through one grouped per-property undo action and skips no-ops; editing a source preset after apply does not mutate nodes; the inspector shows an active preset status and restores a matching built-in selector instead of defaulting visually to the first preset; runtime `apply_preset()` is not used as the editor undo do-method | Pass: user confirmed selector/resource focus does not dirty or create a live link, Apply/undo/redo works for field/emitter use, same-actual-preset no-op Apply does not dirty the scene, neutral placeholder selection disables Apply, target routing/material/runtime ownership/bake/reserved values do not appear or change, and plugin/scene/node/play-stop lifecycle has no stale UI or Output errors. `RIPPLE_PHASE10_INSPECTOR_PROBE_OK` validates transient selector plumbing, active built-in match detection, per-property undo setup, whitelist diffs, no-op diff skipping, source-preset edit isolation, no target routing or hidden/reserved value copying, forbidden-call boundaries, and no editor-only leakage. | 2026-06-08 | Agent/User |
| Phase 10 capture/save | `ripple_inspector_plugin.gd` and `ripple_phase10_inspector_probe.gd` | Godot 4.6.3 Forward+ console parser/probe plus local static scan; visible editor review pending | Capture creates scratch resources only; Save writes only a user-selected preset asset path; runtime scripts/preset resources gain no `ResourceSaver`, `.tres` write path, editor-only class reference, or live link | Partial pass: automated contract passed in `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`; probe validates unsaved scratch field/emitter captures, no node mutation, saved scratch `.tres` reload with correct scripts/values, no target routing or reserved value persistence, `EditorFileDialog`/`ResourceSaver.save()` isolated to the inspector plugin, and runtime scripts/preset resources free of editor/save leakage. Human-visible editor review is still required for the actual dialog, scene dirty state, restart/reload, and no-live-link behavior. | 2026-06-08 | Agent |
| Demo-backed field/emitter authoring | `ripple_field_emitter_demo_review.tscn`, `ripple_field_emitter_demo_review_probe.gd`, `ripple_field_emitter_demo_review_diagnostic.gd`, and `ripple_field_emitter_demo_review_anchor_diagnostic.gd` | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT; human-visible review | Demo scene exposes real field/emitter nodes, target river state applies through RiverManager, fixed/moving emitters map to visible exposed water positions, impulse/contact clears to black except localized emitter flashes, disabling restores baseline, and reload creates fresh runtime state | Pass for visual/debug/control/stop-reload behavior after visible review corrections and review-only strength/trail boosts: terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` covers demo scene load, close overhead camera, 256x256 field bounds, mesh-footprint boundary, preserved `flow_speed=1.0`, exposed-water anchors, lifted handles/markers, stronger review settings, dense moving-trail settings, emitter impulse stamps, disable/reapply/reload cleanup. A no-visible-ripples report led to transparent-zero viewport clearing. A later orange-over-land report led to farther-out moving-path anchors and `RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK`. Latest human-visible review reports boundary mask uniform over river water, raw height and visible influence expanding outward from emitter pulses, impulse/contact localized and non-expanding, visible normal-view ripples, instant Space off/on with no visible remnants when stopped, M stopping orange movement, F manual emission, correct controls/debug views, no stale state after stop/run-again, and no Output panel errors. | 2026-06-07 | Agent/User |
| Scene reload cleanup | `ripple_material_ownership_probe.gd` owner/river exit checks, `ripple_field_emitter_probe.gd` field disable/free checks, `ripple_field_emitter_demo_review_probe.gd` reload check, and human-visible `ripple_field_emitter_demo_review.tscn` stop/run-again review | Godot 4.6.3 Forward+ console with built-in and test-only shader material; human-visible review | No stale ripple textures remain assigned | Pass: RiverManager clear, owner tree exit, and river tree exit restored original material/texture; prototype `WaterRippleField` disable/reenable/free cleared owner-scoped runtime material state; demo-backed review scene reload/disable restored the baseline material and created fresh runtime state; user confirmed stop/run-again left no stale ripple/debug/material state and no Output panel errors. | 2026-06-07 | Agent/User |
| Non-Forward+ renderer coverage | `ripple_field_emitter_demo_review_probe.gd`, `ripple_field_emitter_demo_review_diagnostic.gd`, `ripple_debug_parity_probe.gd`, `ripple_field_emitter_performance_probe.gd`, and `ripple_shader_cost_probe.gd` | Godot 4.6.3 Forward Mobile/Vulkan and Compatibility/OpenGL 3.3 on AMD Radeon RX 6800 XT | Field/emitter demo setup, debug parity, visible/debug render paths, reload cleanup, dispatch performance, and shader-cost checks pass outside Forward+ | Pass: Mobile and Compatibility both reported `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK`. Log scan found no actual `ERROR`, `SCRIPT ERROR`, `WARNING`, `ERR_`, or shader-compilation failure lines. | 2026-06-07 | Agent |
| Shader cost/performance budget | `ripple_shader_cost_probe.gd` plus sampling/neutral probes | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT | Disabled path avoids direct ripple samples; enabled visible normal path stays within the first-pass sample/timing budget; debug modes are measured as inspection tools | Pass: `RIPPLE_SHADER_COST_PROBE_OK`; static disabled-ready and visible-fragment direct ripple samples were `0`; enabled normal helper stayed at `3` simulation samples and `1` boundary helper call; 640x360 median GPU was baseline `0.312 ms`, disabled live textures `0.315 ms` (`+0.003 ms`), enabled visible normal `0.319 ms` (`+0.004 ms` over disabled), and debug raw/contact/boundary/influence medians `0.115/0.118/0.117/0.129 ms`; all cases stayed at one draw call | 2026-06-07 | Agent |
| Runtime field/emitter production performance | `ripple_field_emitter_performance_probe.gd` resolution and emitter-count sweep | Godot 4.6.3 Forward+/Mobile/Compatibility console on AMD Radeon RX 6800 XT | 128/256/512, no emitters, few emitters, many emitters, shader disabled, and shader enabled results are recorded for the current reusable-node path | Pass: Forward+ dispatch medians were `5.477/6.059/5.704 ms` at 128, `6.405/5.650/5.521 ms` at 256, and `5.754/5.508/5.377 ms` at 512. Mobile medians were `5.935/5.791/6.007 ms`, `5.308/5.806/5.692 ms`, and `5.704/6.248/5.496 ms`. Compatibility medians were `6.376/6.091/5.647 ms`, `5.234/6.901/5.355 ms`, and `5.243/5.235/5.373 ms`. Shader disabled/enabled timing remains covered by `RIPPLE_SHADER_COST_PROBE_OK` across the three renderer methods. | 2026-06-07 | Agent |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
  - Visual ripple rings will not move objects, change current direction, or alter buoyancy in the first milestone.
  - A standalone rectangular field can be acceptable for Phase 1 but still invalid for river overlay until boundary masking passes. User observed an inward-moving square outline in `ripple_feedback_review.tscn`; treat this as the placeholder rectangular edge/boundary artifact, not an accepted river behavior.
  - Strong normal/refraction ripples can make water appear to flow differently even when actual flow is unchanged.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
  - Stale generated river material state.
  - Debug material override hiding visible material uniforms.
  - Shared material resource receiving runtime uniforms from the wrong field.
  - Ripple field bounds not covering the reviewed water area.
  - Runtime material state applying to a duplicate that is not the active rendered material.
  - Mesh-derived review ripple centers landing on valid mesh vertices but not on visually inspectable/shaded water pixels. This caused the first demo review failure: centers were too spread out and the camera focused above the sloped water.
  - Mesh-derived emitter anchors landing on valid river mesh vertices that are hidden by nearby terrain. User caught this in the first field/emitter authoring review; the demo review controller now samples `World/HTerrain`, chooses exposed water anchors near the authored UVs, lifts authoring handles above terrain, and the probe rejects buried anchors/handles. User later caught the orange moving marker still crossing mostly land; the path now uses farther-out exposed anchors and the probe rejects low-clearance moving path samples.
  - Empty offscreen ripple buffers inheriting the project clear color instead of black. User caught this through a no-visible-ripples report: impulse/contact appeared blue everywhere, raw height looked uniform, and visible influence stayed black. `WaterRippleField` canvas viewports now use transparent zero clear, and the demo probe rejects full-field impulse/contact sheets.
  - Normal-only perturbation being too small or visually hidden by demo normal scale, refraction, transparency, lighting, or existing flow/wake normal content. A temporary inspection-material approach made ripples legible but froze the base flow and overpowered the scene; the review scene now leaves demo material motion intact and animates the review ripple texture instead.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index for river behavior, hydrology, flow maps, shader water, and production examples. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation:
  - Asking why buoyant objects ignore visual ripples during the first milestone.
  - Treating a rectangular debug texture as proof that river banks are masked correctly.
  - Treating UV2 bake texture alignment as proof of world-space ripple alignment.
- What the agent should say to the user if that evidence appears:
  - "The current ripple milestone is visual-only. The visible rings can be accepted while buoyancy still follows WaterSystem flow; changing object behavior needs a separate physics-facing plan."
- Quick falsifying check before patching:
  - Disable ripple normals/refraction and compare runtime object movement. If movement does not change, the issue is visual/physics scope rather than a broken ripple field.

## Automated Checks

- Command or procedure:
  - Run static scans after implementation for forbidden runtime readback calls in ripple files.
  - Allow `get_image()` only in validation/export probes that are not part of normal runtime simulation or visible rendering.
  - For Phase 10 editor work, run static scans that read-only/status/selector/capture-only paths do not call `initialize_runtime()`, `rebuild_runtime()`, `rebuild_boundary_mask()`, `reset_feedback()`, `queue_impulse*()`, `emit_once()`, target registration, RiverManager runtime material APIs, private resolver/cache methods, or runtime RID/texture internals.
  - For Phase 10 editor work, scan runtime field/emitter scripts and preset resources for new `EditorPlugin`, `EditorInspectorPlugin`, `EditorUndoRedoManager`, `EditorFileDialog`, `EditorResourcePicker`, `ResourceSaver`, or `.tres` write-path references.
  - Run Godot console parser/probe checks for new scripts and shaders when available.
  - Run any future `RIPPLE_*_OK` probes recorded in this file.
- Expected result:
  - No normal-runtime readback, no parser errors, and stable pass markers for each probe.
- Agent limitation note:
  - Local checks may include static scans, parser checks, or headless editor-load probes when they work.
  - Do not treat local headless/editor-load checks as proof of visible editor interaction, shader visuals, bake output, or runtime behavior.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so Codex does not alter the user's normal Godot editor profile.

Console probe pattern:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://path/to/ripple_probe.gd"
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Human-Assisted Validation

Use this by default for visible Godot editor checks, viewport interaction, scene running, gizmos, shader visuals, bake output, and runtime behavior. The agent may not be able to open or interact with Godot reliably.

When requesting this validation, the agent must put the exact request in the chat message so the user does not have to open this file to discover what to run.

- Request to user:
  - "Please open `addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`, run it in Godot 4.6.3, and report the renderer, any Output errors, and whether the close-overhead view preserves normal river flow while three localized annular ripple patches move outward on the demo river. The scene starts at readable strength `1.25` with clustered mesh-anchored ripple centers and does not change the demo material's `flow_speed`. Press 4 for raw ripple height, 5 for impulse/contact texture, 6 for boundary mask, 7 for visible influence, and 0 to return to the normal visible river. While switching those views, confirm the ripple rings or debug texture state keeps animating instead of disappearing or resetting. Press Space to toggle ripples off/on, press 1/2/3 to compare low/medium/inspection normal strength (`1.25`, `2.0`, `4.0`), press C to switch between close overhead, the original demo overhead camera, and close oblique, press R to reset the review camera, use WASD/QE to move, hold right mouse and move the mouse to look around, and use the mouse wheel to zoom."
- Exact scene, command, or workflow to run:
  - Open and run `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`.
- Plugin state required:
  - Waterways add-on should be enabled as in the demo project; the scene uses existing `Demo.tscn` and runtime-only RiverManager material state.
- Console output or errors to relay back:
  - Parser errors, shader errors, material warnings, missing uniform warnings, and whether the overlay reports the expected visible/debug view.
- Screenshot or visible behavior to relay back:
  - Whether the scene is no longer blank or too distant; whether Space returns to the old visible baseline; whether the base flow keeps moving when ripples are enabled; whether ripples appear as localized surface-normal rings that move outward rather than as a frozen flow-map pattern; whether strengths 1, 2, and 3 remain usable; whether debug views 4, 5, 6, and 7 show distinct raw/contact/boundary/influence information; whether returning to 0 restores the visible river without losing the runtime ripple state.
- Godot version and renderer to relay back:
  - Godot 4.6.3, renderer backend, OS/GPU if practical.
- Expected result:
  - Ripples are visible when enabled, disappear when toggled off, move outward from their centers, and read as local surface detail rather than frozen flow or physics behavior. Debug views show distinct raw ripple, impulse/contact, boundary, and visible influence data; switching views does not reset or hide the running runtime ripple state.
- Failure signs:
  - Scene renders blank, starts too far away for inspection, shader errors appear, ripples do not toggle off, the old river material does not restore, base flow freezes when ripples are enabled, ripples do not expand outward, debug views are blank or identical, switching debug views resets the ripple animation/state, returning to visible mode hides the runtime ripples, or the ripple normals overpower flow/pillow/wake/eddy-line cues at the default strength.
- Result recording format:
  - Date:
  - Ran by:
  - Godot version/renderer/device:
  - Output or parser errors:
  - Visible result:
  - Pass/partial/fail:

## Phase 10 Editor Polish Human Review Request

Use this only after Phase 10 editor tooling exists. Keep live-scene commands disabled unless a later live-scene bridge plan supersedes this checklist.

1. Open Godot 4.6.3 with the project at `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`.
2. Enable the Waterways plugin, open `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`, and select `WaterRippleField`, then each `WaterRippleEmitter`.
3. Confirm the Phase 10 read-only status rows appear and switching selection does not create Output errors, stale duplicated UI, preview leftovers, or dirty-scene prompts.
4. In the `Preset Apply` panel, change the built-in preset selector and optionally pick a matching preset resource through the resource picker. Confirm selector/resource-picker focus alone does not mark the scene dirty and no `field_preset`, `emitter_preset`, resource path, live link, or auto-apply property appears on the node. The neutral `Choose...` selector row should disable Apply; that is placeholder behavior, not the same as a no-op Apply.
5. Click `Apply Built-In` for a field preset, undo, redo, then click `Apply Built-In` again while the same actual preset is still selected and the node already matches it. Repeat with one emitter. Confirm one grouped undo action is created only when values change, the changed ordinary properties are visible, the `Active preset` row and selector show the applied matching built-in instead of reverting visually to the first preset, no target routing/material/bake values changed, no reserved `debug_visible`/`refraction_strength`/`displacement_strength` value appears or changes, and same-actual-preset no-op Apply does not dirty the scene.
6. In `Preset Capture`, click `Capture Field` on the field and `Capture Emitter` on an emitter. Confirm capture alone does not dirty the scene. Click `Save Captured`, choose a deliberate scratch `.tres` path such as `res://.codex-research/ripple-phase10-visible-review/my_field_preset.tres`, and confirm the save dialog opens only after capture. Restart or reopen the editor, load the saved preset resource, and confirm it has the right field/emitter preset type and values. Confirm no field/emitter node gained a preset slot, resource path, live link, or auto-apply behavior.
7. Disable and re-enable the plugin, close/reopen the scene, delete a selected ripple node, and play/stop the scene. Confirm no stale inspector UI, overlays, gizmos, signals, scratch resources, or debug handles remain.

Expected result:

- Phase 10 editor UI feels native but remains editor-only, undo-aware, explicit about saving, precise about dirty state, and separate from runtime scene commands.

## Recorded Results

Record new runs here. Put the newest and most relevant result first, then move older detail under an archive marker when the section gets long.

Recorded result:

- Date: 2026-06-08
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated parser checks for `plugin.gd`, `ripple_inspector_plugin.gd`, `ripple_inspector_status.gd`, `ripple_inspector_preset_apply_model.gd`, and `ripple_phase10_inspector_probe.gd`; profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase10_inspector_probe.gd`; regression probes `ripple_phase9_preset_api_probe.gd`, `ripple_field_emitter_probe.gd`, `ripple_material_ownership_probe.gd`, and `ripple_field_emitter_demo_review_probe.gd`; static `git diff --check`, forbidden-call scan, and runtime editor-class/save-path scan.
- Output or parser errors: Stable markers `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. The Phase 10 probe reported `phase10_capture_save_paths=["res://.codex-research/ripple-phase10-inspector/phase10_captured_field_preset.tres", "res://.codex-research/ripple-phase10-inspector/phase10_captured_emitter_preset.tres"]`.
- Visible result, if applicable: Not human-visible; this validates the capture/save contract by saving and reloading scratch preset resources through explicit paths.
- Stable result marker: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`
- Pass/partial/fail: Partial pass for Phase 10 capture/save. Automated contract passes; visible editor save-dialog, dirty-state, restart/reload, and no-live-link review remains pending.
- Notes or follow-up: `ripple_inspector_plugin.gd` now exposes `Capture Field` / `Capture Emitter` and `Save Captured`. Capture stores a transient scratch preset with empty `resource_path`; Save opens an editor-owned `EditorFileDialog` and calls `ResourceSaver.save()` only after an explicit `.tres` path is selected. Runtime field/emitter scripts and preset resources still contain no editor-only classes, `ResourceSaver`, or `.tres` save paths.

Recorded result:

- Date: 2026-06-08
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 editor, local project; renderer/device not relayed.
- Command, scene, or workflow: Human-visible Phase 10 Apply review in the Godot editor for `Preset Apply` controls.
- Output or parser errors: User reported no stale UI or Output errors during plugin disable/enable, scene close/reopen, selected-node delete, and play/stop lifecycle checks.
- Visible result, if applicable: Selector/resource-picker focus alone passed without dirtying the scene or creating a live preset link. `Apply Built-In`, undo, and redo passed, including an emitter. Same-actual-preset no-op Apply did not dirty the scene. The neutral `Choose...` row disabled Apply. Target routing, material/runtime ownership, bake fields, and reserved values did not appear or change. Plugin/scene/node/play-stop lifecycle checks passed.
- Stable result marker: Human-visible Phase 10 Apply review.
- Pass/partial/fail: Pass for human-visible Phase 10 Apply controls.
- Notes or follow-up: The checklist now clarifies that "no-op apply" means applying the same actual preset again after the node already matches it, not selecting the neutral `Choose...` placeholder. Capture/save is now implemented and automated-proven, with visible editor review pending.

Recorded result:

- Date: 2026-06-08
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe using redirected `APPDATA`/`LOCALAPPDATA`: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase10_inspector_probe.gd`; parser checks for `ripple_inspector_plugin.gd`, `ripple_inspector_preset_apply_model.gd`, and `ripple_phase10_inspector_probe.gd`; static `git diff --check`, selector/apply forbidden-call scan, and runtime editor-class/save-path scan.
- Output or parser errors: Stable marker `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`. Parser checks exited cleanly. The probe reported `field_apply_changes=9` and `emitter_apply_changes=7`.
- Visible result, if applicable: Not human-visible; this validates the active preset status/selector restoration contract after the user reported that an emitter Apply visually reverted to `Footstep` after inspector rebuild.
- Stable result marker: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`
- Pass/partial/fail: Pass for automated Phase 10 active-preset display regression coverage; human-visible Phase 10 Apply review later passed.
- Notes or follow-up: `ripple_inspector_plugin.gd` now adds an `Active preset` row and a neutral built-in selector placeholder. `ripple_inspector_preset_apply_model.gd` can identify exact built-in matches from copied node values, so an applied built-in preset remains visibly selected after redraw without adding serialized preset slots, paths, or live links. Custom resource labels remain transient to the inspector session.

Recorded result:

- Date: 2026-06-08
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated parser checks for `ripple_inspector_preset_apply_model.gd`, `ripple_inspector_status.gd`, `ripple_inspector_plugin.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd`; profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase10_inspector_probe.gd`; regression probes `ripple_phase9_preset_api_probe.gd`, `ripple_field_emitter_probe.gd`, `ripple_material_ownership_probe.gd`, and `ripple_field_emitter_demo_review_probe.gd`; static `git diff --check`, selector/apply forbidden-call scan, runtime editor-class/save-path scan, and runtime preset-save/readback scan.
- Output or parser errors: Stable markers `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. The Phase 10 probe reported `field_apply_changes=9` and `emitter_apply_changes=7`. The material ownership probe printed its expected invalid-key/wrong-owner warning cases while still passing. Parser checks exited cleanly.
- Visible result, if applicable: Not human-visible; this validates the inspector/status/apply contract and runtime boundary statically/through console probes.
- Stable result marker: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`
- Pass/partial/fail: Pass for Phase 10 transient Apply controls automated validation; human-visible review later passed.
- Notes or follow-up: `ripple_inspector_plugin.gd` now shows transient built-in preset selectors and matching-type `EditorResourcePicker` controls. Apply uses `EditorUndoRedoManager` property operations from `ripple_inspector_preset_apply_model.gd` diffs, skips no-op diffs, avoids runtime `apply_preset()` as the undo do-method, and keeps selectors out of serialized node state. Later capture/save controls are now implemented and automated-proven, with visible editor review pending.

Recorded result:

- Date: 2026-06-08
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 editor, local project
- Command, scene, or workflow: Ran the Phase 10 Editor Polish Human Review Request for the read-only inspector rows against `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`, selecting the `WaterRippleField` and `WaterRippleEmitter` nodes and checking plugin/selection/scene/play-stop lifecycle plus dirty-state behavior.
- Output or parser errors: User confirmed no Output errors.
- Visible result, if applicable: Read-only status rows appeared for the field and emitters; switching selection and lifecycle checks did not create stale duplicated UI, preview leftovers, or dirty-scene prompts from simple read-only inspection.
- Stable result marker: Human-visible Phase 10 read-only inspector review.
- Pass/partial/fail: Pass for Phase 10 read-only inspector lifecycle and dirty-state review.
- Notes or follow-up: This retires the visible lifecycle gate for the non-mutating inspector skeleton. Transient preset selectors and undo-aware Apply were later human-visible accepted; capture/save is now implemented and automated-proven. Capture/save visible review, gizmos, previews, and live-scene commands remain future validation work.

Recorded result:

- Date: 2026-06-08
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated parser checks for `ripple_inspector_status.gd`, `ripple_inspector_plugin.gd`, `plugin.gd`, and `ripple_phase10_inspector_probe.gd`; profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase10_inspector_probe.gd`; regression probes `ripple_phase9_preset_api_probe.gd`, `ripple_field_emitter_probe.gd`, `ripple_material_ownership_probe.gd`, and `ripple_field_emitter_demo_review_probe.gd`; static `git diff --check`, read-only inspector forbidden-call scan, runtime editor-class/save-path scan, and runtime preset-save/readback scan.
- Output or parser errors: Stable markers `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. The material ownership probe printed its expected invalid-key/wrong-owner warning cases while still passing. Parser checks exited cleanly.
- Visible result, if applicable: Not human-visible; this validates the read-only inspector/status contract and runtime boundary statically/through console probes.
- Stable result marker: `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`
- Pass/partial/fail: Pass for Phase 10 read-only inspector slice 1 automated validation; human-visible editor lifecycle and dirty-state review later passed.
- Notes or follow-up: `ripple_inspector_plugin.gd` is registered and removed by `plugin.gd`, while `ripple_inspector_status.gd` holds probeable read-only status logic. The status model reports exported values, configuration warnings, and conservative target/routing summaries only, avoids runtime/private resolver calls, adds no children, mutates no field/emitter values, and left preset selectors, Apply, Capture/Save, gizmos, previews, and live-scene commands for later Phase 10 slices. Preset selectors, Apply, and capture/save are now implemented in later slices.

## Phase 9 Authoring Human Review Request

Use this exact request if the editor authoring review needs to be rerun:

1. Open Godot 4.6.3 with the project at `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`.
2. Open `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`.
3. In the Scene dock, collapse the large `World` instance or use the Scene dock filter/search. Select the root-level `WaterRippleField` node, which is a sibling of `World`, not inside it. Confirm the inspector uses ordinary groups for Setup, Targets, Boundary Mask, Simulation, and Visual Response.
4. Confirm `debug_visible`, `refraction_strength`, and `displacement_strength` do not appear as normal editable inspector fields.
5. Select `PulseEmitter_UpperWater`, `OneShotEmitter_MidBend`, and `MovingEmitter_TestTrail`. Confirm each emitter uses ordinary groups for Routing, Shape, Emission, and Priority And Caps.
6. Add a new `WaterRippleField` and `WaterRippleEmitter` as child nodes in any unsaved scratch scene or temporary branch scene. Confirm both still appear by name and icon in Add Node search.
7. Do not run a river bake. Run the review scene once and confirm it still behaves like the previous accepted field/emitter review: localized ripples, working debug views, Space disable/reenable cleanup, and no Output errors.
8. Relay Godot version, renderer, any Output errors, whether the grouped inspector fields were readable, whether reserved fields stayed hidden, and whether Add Node search still found both ripple nodes.

Expected result:

- The authoring surface is understandable without editing shader code.
- Presets are script-callable starters, not visible live profile slots.
- No dedicated editor buttons, save dialogs, or preview helpers are expected in Phase 9.

Recorded result:

- Date: 2026-06-08
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 requested; exact renderer/device not relayed.
- Command, scene, or workflow: Ran the Phase 9 Authoring Human Review Request against `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`, including field/emitter inspector review, hidden reserved-field check, Add Node search for scratch nodes, and one runtime pass of the review scene.
- Output or parser errors: User reported no Output errors. Adding an empty scratch `WaterRippleField` showed expected setup warnings about missing target river/group and boundary sources, plus the intentional note that editor-time runtime texture preview is disabled for this prototype.
- Visible result, if applicable: User confirmed `WaterRippleField` used ordinary Setup, Targets, Boundary Mask, Simulation, and Visual Response groups; `debug_visible`, `refraction_strength`, and `displacement_strength` did not appear as normal editable fields; `PulseEmitter_UpperWater`, `OneShotEmitter_MidBend`, and `MovingEmitter_TestTrail` used ordinary Routing, Shape, Emission, and Priority And Caps groups; Add Node search still found `WaterRippleField` and `WaterRippleEmitter` by name/icon; and the review scene behaved like the previous accepted field/emitter review with localized ripples, working debug views, and Space disable/reenable cleanup.
- Stable result marker: Human-visible Phase 9 authoring review.
- Pass/partial/fail: Pass for the Phase 9 visible editor authoring workflow.
- Notes or follow-up: This closes the Phase 9 authoring review gate. Phase 10 owns editor-only inspector polish, starting with read-only lifecycle/non-mutating status validation before transient selectors, undo-aware Apply, capture/save dialogs, helper previews, or any live-scene bridge. Response/refraction/displacement tuning remains a separate future slice.

Recorded result:

- Date: 2026-06-08
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated parser checks for `water_ripple_field_preset.gd`, `water_ripple_emitter_preset.gd`, `water_ripple_field.gd`, `water_ripple_emitter.gd`, and `ripple_phase9_preset_api_probe.gd`; profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_phase9_preset_api_probe.gd`; regression probes `ripple_field_emitter_probe.gd`, `ripple_material_ownership_probe.gd`, and `ripple_field_emitter_demo_review_probe.gd`; static `git diff --check`, runtime preset-save/readback scan, and forbidden-file diff.
- Output or parser errors: Stable markers `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. The material ownership probe printed its expected invalid-key/wrong-owner warning cases while still passing. Parser checks exited cleanly.
- Visible result, if applicable: Not human-visible; this validates the Phase 9 script/resource contract.
- Stable result marker: `RIPPLE_PHASE9_PRESET_API_PROBE_OK`
- Pass/partial/fail: Pass for the Phase 9 script/resource authoring slice through export grouping, warning cleanup, built-in starter presets, and scratch save/reload.
- Notes or follow-up: The probe validated separate `WaterRippleFieldPreset` and `WaterRippleEmitterPreset` resources, type-specific `apply_preset(preset)` rejection/acceptance, value-copy semantics, source-preset edit isolation after apply, fresh in-memory `capture_preset()` resources with empty `resource_path`, absence of `field_preset`/`emitter_preset`/generic preset slots, no runtime `ResourceSaver` or `.tres` path in the public API, storage-only `debug_visible`, `refraction_strength`, and `displacement_strength`, no refraction/displacement/target routing copy from field presets, export group metadata for field/emitter nodes and preset resources, built-in starter preset lists, rejection of unsupported wake/heavy-rain names, visual-only field preset application without viewport rebuild, safe runtime rebuild/reapply for resolution/emitter-cap changes, saved scratch preset resource reload, and scratch scene reload with fresh runtime texture rebuild and material-state restore on disable. Human-visible editor authoring review later passed.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Forward Mobile/Vulkan and Compatibility/OpenGL 3.3, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated renderer coverage using `--rendering-method mobile` and `--rendering-driver opengl3 --rendering-method gl_compatibility` for `ripple_field_emitter_demo_review_probe.gd`, `ripple_field_emitter_demo_review_diagnostic.gd`, `ripple_debug_parity_probe.gd`, `ripple_field_emitter_performance_probe.gd`, and `ripple_shader_cost_probe.gd`.
- Output or parser errors: Stable markers `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, and `RIPPLE_SHADER_COST_PROBE_OK` passed on both renderer methods. Log scan found no actual `ERROR`, `SCRIPT ERROR`, `WARNING`, `ERR_`, failed, or shader-compilation lines.
- Visible result, if applicable: Automated render/debug readback only; no human-visible Mobile/Compatibility viewport review was run.
- Stable result marker: Listed markers passed for both Mobile and Compatibility.
- Pass/partial/fail: Pass for non-Forward+ console renderer coverage on this desktop GPU.
- Notes or follow-up: Mobile field/emitter dispatch medians for 0/4/16 emitters were `5.935/5.791/6.007 ms` at 128, `5.308/5.806/5.692 ms` at 256, and `5.704/6.248/5.496 ms` at 512; shader-cost GPU medians were baseline `0.303 ms`, disabled live textures `0.305 ms`, enabled visible normal `0.311 ms`, and debug raw/contact/boundary/influence `0.087/0.086/0.087/0.099 ms`. Compatibility dispatch medians were `6.376/6.091/5.647 ms`, `5.234/6.901/5.355 ms`, and `5.243/5.235/5.373 ms`; shader-cost GPU medians were baseline `0.248 ms`, disabled live textures `0.247 ms`, enabled visible normal `0.253 ms`, and debug raw/contact/boundary/influence `0.099/0.099/0.101/0.114 ms`. All shader-cost cases stayed at one draw call.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 requested; exact renderer/device not relayed.
- Command, scene, or workflow: Ran the requested `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn` visible checklist, including controls, debug views, Space disable/re-enable, F manual pulses, M moving-emitter toggle, and scene stop/run-again cleanup.
- Output or parser errors: User reported no Output window errors.
- Visible result, if applicable: Controls worked correctly, debug views worked, and the stop/run-again cleanup did not leave stale ripple/debug/material state.
- Stable result marker: Human-visible report only.
- Pass/partial/fail: Pass for human-visible field/emitter visual/debug/control and stop/reload cleanup workflow.
- Notes or follow-up: This closes the demo-backed visible workflow gate for the current Forward+ review slice. Mobile and Compatibility renderer coverage later passed through focused console/render probes.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. First run caught a GDScript inference error in the review controller and a marker global-transform timing issue; both were fixed before the passing run.
- Visible result, if applicable: Not human-visible; this was the first console validation of the demo-backed authoring scene. Later human-visible review accepted the revised visual/debug/control behavior.
- Stable result marker: `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`
- Pass/partial/fail: Pass for automated demo authoring integration.
- Notes or follow-up: The probe validated that the scene exposes real `WaterRippleField`/`WaterRippleEmitter` nodes, targets only the demo river, generates the mesh-footprint boundary mask, maps fixed emitters to expected water UVs, keeps the moving emitter in-bounds on the authored path, renders three impulse stamps, preserves base `flow_speed=1.0`, disables back to the baseline material, reapplies runtime state, and reloads without stale runtime material state. Later human-visible review accepted visual/debug/control and stop/reload cleanup behavior.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_performance_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`.
- Visible result, if applicable: Not human-visible; this is a dispatch-time field/emitter sweep for the reusable node path.
- Stable result marker: `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`
- Pass/partial/fail: Pass for the current Forward+ field/emitter production-dispatch gate. Dispatch medians for 0/4/16 emitters were `5.933/5.738/5.755 ms` at 128, `5.981/5.518/5.799 ms` at 256, and `5.511/6.202/5.866 ms` at 512. Each case applied to one generated river target and reported the expected texture size.
- Notes or follow-up: The probe measures runtime field/emitter dispatch work, not human-visible demo polish. Mobile and Compatibility renderer coverage later passed through focused console/render probes.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_FIELD_EMITTER_PROBE_OK`.
- Visible result, if applicable: Not human-visible; this validates the reusable runtime field/emitter lifecycle and material ownership path.
- Stable result marker: `RIPPLE_FIELD_EMITTER_PROBE_OK`
- Pass/partial/fail: Pass. The field initialized 128x128 read/write/impulse/boundary targets, generated the boundary mask from the target river mesh footprint, kept read/write/impulse/boundary viewports and textures distinct, applied runtime material state to one intended target, rejected an out-of-bounds impulse, rendered the emitter cap/priority path, reported no same-target hazard and no normal-runtime readback, and restored target material state on disable and free.
- Notes or follow-up: This proves the console lifecycle path for the reusable nodes. Demo-backed authoring integration, human-visible scene workflow, Mobile/Compatibility renderer coverage, named-class parser/editor-cache validation, and human-visible Add Node visibility are now covered.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_shader_cost_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_SHADER_COST_PROBE_OK`. The probe used `RenderingServer.viewport_set_measure_render_time()` on a 640x360 offscreen viewport, 24 warmup frames, and 72 measured frames per case.
- Visible result, if applicable: Not human-visible; this is a controlled renderer-cost and static sample-budget probe.
- Stable result marker: `RIPPLE_SHADER_COST_PROBE_OK`
- Pass/partial/fail: Pass for the current shader-cost gate. Static checks reported disabled-ready ripple samples `0`, visible-fragment direct ripple samples `0`, one visible helper call from `fragment()`, and the accepted enabled-normal budget of three simulation samples plus one boundary helper call. Measured median GPU timings were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`; disabled delta was `+0.003 ms`, enabled-over-disabled delta was `+0.004 ms`, and all visible cases stayed at one draw call. Debug medians were raw height `0.115 ms`, impulse/contact `0.118 ms`, boundary mask `0.117 ms`, and visible influence `0.129 ms`; these are recorded as inspection-tool costs, not visual tuning targets.
- Notes or follow-up: This proves the current disabled/visible/debug river shader paths are affordable enough for the first-pass gate on this Forward+ desktop setup. Field/emitter dispatch sweeps and Mobile/Compatibility renderer coverage now have their own passes above.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 requested; exact renderer/device not relayed.
- Command, scene, or workflow: Reviewed `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn` debug controls after automated debug parity passed.
- Output or parser errors: None relayed.
- Visible result, if applicable: User confirmed raw ripple, contact, boundary, and visible-influence debug views work in the currently expected ways. User noted the contact debug view currently makes the river an undifferentiated yellow; this matches the current broad precomputed contact fixture and is not a debug-parity failure.
- Stable result marker: Human-visible demo debug parity review.
- Pass/partial/fail: Pass for human-visible debug parity at the current fixture fidelity.
- Notes or follow-up: Contact debug usability can be improved later with tighter/localized emitter spots and darker zero regions, but that is polish after the shader-cost/performance gate.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_debug_parity_probe.gd`, followed by regression reruns of the material ownership, neutral shader, sampling-budget, visible-normal, review-smoke, and review-diagnostic probes.
- Output or parser errors: First debug-parity run caught an invalid `return` in `river_debug.gdshader` fragment code; final run passed with stable marker `RIPPLE_DEBUG_PARITY_PROBE_OK`. Regression reruns passed with `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, and `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`.
- Visible result, if applicable: Automated render readback only; human-visible review steps are listed above for the same review scene controls.
- Stable result marker: `RIPPLE_DEBUG_PARITY_PROBE_OK`
- Pass/partial/fail: Pass for debug parity. The probe confirmed shader/menu contract, runtime debug-state preservation, review-scene debug-state preservation, and nonblank/high-contrast renders for raw height, impulse/contact, boundary mask, and visible influence.
- Notes or follow-up: Render contrast measurements were `0.27058823406696` for raw height, `0.81960785388947` for impulse/contact, `0.81960785388947` for boundary mask, and `0.82091504335403` for visible influence. Shader-cost, reusable field/emitter console validation, demo-backed authoring console validation, human-visible workflow review, Mobile/Compatibility renderer coverage, named-class parser/editor-cache validation, human-visible Add Node visibility, revised Phase 9/Phase 10 planning, Phase 9 preset/grouping/starter/reload implementation, and human-visible Phase 9 editor authoring review have since passed; response/refraction/displacement tuning remains separate.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3; exact renderer/device not relayed.
- Command, scene, or workflow: Reran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn` after the precomputed-frame performance fix.
- Output or parser errors: None relayed.
- Visible result, if applicable: The river keeps moving and the ripple rings expand outward.
- Stable result marker: Human-visible demo normal-blend review.
- Pass/partial/fail: Pass for the current demo-backed minimal visible normal-blend gate.
- Notes or follow-up: This supersedes the earlier frozen-flow/static-texture and harsh-framerate fixture failures. Debug parity and shader-cost validation have since passed; proceed to reusable field/emitter workflow before response/refraction/displacement tuning.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3; exact renderer/device not relayed.
- Command, scene, or workflow: Reran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn` after the precomputed-frame performance fix.
- Output or parser errors: None relayed.
- Visible result, if applicable: Enabled-ripple framerate is greatly improved.
- Stable result marker: Human-visible demo normal-blend review performance check.
- Pass/partial/fail: Pass for the review-fixture performance regression; visual acceptance of base river motion and outward ring motion still needs explicit confirmation.
- Notes or follow-up: The likely review-fixture culprit was playback-time GDScript generation/upload of a 256x256 procedural ripple texture. The current scene precomputes 48 frames once and swaps texture references during playback.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe with `APPDATA` and `LOCALAPPDATA` redirected to `.codex-research\godot-user`, then `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`. The demo printed two existing `Regen multimesh` messages while loading.
- Visible result, if applicable: Not applicable; automated smoke/status probe only.
- Stable result marker: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`
- Pass/partial/fail: Pass.
- Notes or follow-up: Status reported `normal_strength=1.25`, `camera_mode="close overhead"`, `runtime_flow_speed=1.0`, `ripple_precomputed_frame_count=48`, advancing `ripple_texture_frame`, and unchanged `ripple_image_generation_count=48` during playback.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_diagnostic.gd`
- Output or parser errors: Stable marker `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`. The demo printed two existing `Regen multimesh` messages while loading.
- Visible result, if applicable: Validation-only capture exported `enabled_ripples.png`, `zero_strength.png`, and `diff.png` under `.codex-research/ripple-review-diagnostic`. The capture showed visible annular ripple patches in the close-overhead view after the review scene clustered centers, focused on actual mesh positions, preserved demo flow motion, animated the review texture, and switched to precomputed animation frames.
- Stable result marker: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`
- Pass/partial/fail: Pass for diagnosis and automated visual-delta support; later human-visible rerun passed the base-flow/outward-ring gate.
- Notes or follow-up: Diagnostic confirmed active rendered material state (`i_ripple_enabled=true`, `i_ripple_normal_strength=1.25`, `flow_speed=1.0`, `normal_scale=0.8090007984275`, `i_ripple_texel_size=(0.003906, 0.003906)`, 256x256 ripple/boundary textures), all three clustered mesh-derived centers inside the 384x216 inspection frame, mesh tangent data present, `precomputed_frame_count=48`, `image_generation_count=48`, local max one-texel slope `0.28289705514908`, and enabled-vs-zero-strength image delta `max_delta=0.60392156243324`, `mean_delta=0.01630346588826`, `changed_pixels=39976`.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3; exact renderer/device not relayed.
- Command, scene, or workflow: Reran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn` after the frozen-flow/static-texture fixture fix.
- Output or parser errors: None relayed.
- Visible result, if applicable: Ripples are now visible in the river. Enabling them drops framerate harshly.
- Stable result marker: Human-visible demo normal-blend review.
- Pass/partial/fail: Partial: pass for visibility, fail for enabled review-scene performance.
- Notes or follow-up: Superseded by the precomputed-frame review fixture fix above. The likely review-fixture culprit was per-frame GDScript generation and upload of a 256x256 procedural ripple texture; the scene now precomputes 48 frames once and swaps texture references during playback.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3; screenshots showed Radeon ReLive capture on Windows, exact renderer/device not relayed.
- Command, scene, or workflow: Opened and ran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`; supplied four screenshots for strengths `1.25`, `2.0`, `4.0`, and ripples off.
- Output or parser errors: None relayed.
- Visible result, if applicable: With ripples enabled, the review fixture froze the base flow-map motion; the ripple contribution looked massive and frozen, and it did not expand outward. With ripples off, the normal river view moved again.
- Stable result marker: Human-visible demo normal-blend review.
- Pass/partial/fail: Fail for enabled review behavior; pass for catching an important fixture bug before response tuning.
- Notes or follow-up: Superseded by the animated review-texture fix above. The cause was review-fixture-only material tweaking (`flow_speed=0.0`, boosted `normal_scale`, and transparency changes) plus a static procedural ripple texture. The fix preserves demo material motion, starts at strength `1.25`, uses `2.0` for medium strength, and updates the review ripple texture at runtime so rings move outward.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 requested; exact renderer/device not relayed.
- Command, scene, or workflow: Opened and ran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn` after the close-camera/right-mouse-look review-scene fix.
- Output or parser errors: None relayed.
- Visible result, if applicable: Camera became more usable, but no ripples were visible on the demo river.
- Stable result marker: Human-visible demo normal-blend review.
- Pass/partial/fail: Fail for visible ripple appearance; partial pass for review-scene camera usability.
- Notes or follow-up: Superseded as the active blocker by the diagnostic above. The failure came from review-scene framing/readability: centers were too spread across the river, the camera focus used the mesh AABB height instead of selected water positions, and the original transparent demo material made normal-only perturbation hard to see.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`. The demo printed two existing `Regen multimesh` messages while loading.
- Visible result, if applicable: Not human-visible; smoke probe only. It instantiated `ripple_river_shader_visible_normal_review.tscn`, which now includes `Demo.tscn` as an editor-visible child, finds `WaterSystem/Water River`, starts on a close-overhead camera, derives three clustered annular ripple centers from the demo river mesh, starts at readable strength `1.25`, preserves active material `flow_speed=1.0`, advances the animated review texture, applies runtime ripple material state, toggles it off/on, and restores on free.
- Stable result marker: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`
- Pass/partial/fail: Pass for demo-backed review-scene setup, close review camera activation, runtime apply/toggle/restore, and parser/load smoke.
- Notes or follow-up: Human-visible review of the scene is still required to judge whether flow animation, pillows, wakes, and eddy-line visuals remain recognizable with ripples enabled.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`. Disabled-with-wave, enabled-flat, and enabled-black-boundary cases all reported `max_delta=0.0`; enabled wave texture reported `max_delta=0.75686274468899`, `mean_delta=0.10863875223822`, and `changed_pixels=7252`.
- Visible result, if applicable: Not human-visible; validation-only render readback proves visible normal response changes when the wave texture is enabled.
- Stable result marker: `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`
- Pass/partial/fail: Pass for minimal visible river shader normal blending gate.
- Notes or follow-up: The probe sets `i_ripple_refraction_strength=0.0` and `i_ripple_displacement_strength=0.0`; the shader keeps custom screen refraction on the pre-ripple normal for this slice.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_sampling_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`. Results reported `world_to_uv_uses_xz=true`, `normal_helper_simulation_samples=3`, `normal_helper_boundary_calls=1`, `height_helper_simulation_samples=1`, `height_helper_boundary_calls=1`, `fragment_ripple_normal_world_calls=1`, `fragment_ripple_normal_uv_calls=0`, and `fragment_ripple_height_calls=0`.
- Visible result, if applicable: Not human-visible; static/compile probe only. The follow-up neutral render probe still reported zero pixel delta for disabled/missing-texture cases.
- Stable result marker: `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`
- Pass/partial/fail: Pass for guarded river shader height/normal sampling helpers, first normal-helper sample budget, visible normal helper call budget, and X/Z mapping contract.
- Notes or follow-up: `river.gdshader` now has helper functions for world-to-ripple UV mapping, guarded height sampling, boundary masking, distance fade, and normal-offset sampling. Visible normal blending calls the world helper once from `fragment()` and leaves direct height sampling out of the visible path. Initial validation found that Godot's spatial built-ins could not be read directly inside global helper functions; the helpers receive view/camera values as arguments when needed.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Reran `ripple_feedback_probe.gd`, `ripple_mapping_probe.gd`, `ripple_boundary_mask_probe.gd`, and `ripple_feedback_analysis_probe.gd` after visible normal integration.
- Output or parser errors: Stable markers `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`.
- Visible result, if applicable: Not human-visible; regression sweep only.
- Stable result marker: `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_MAPPING_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, `RIPPLE_FEEDBACK_ANALYSIS_OK`
- Pass/partial/fail: Pass.
- Notes or follow-up: These standalone gates were unaffected by the river shader normal-blend edit.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_neutral_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`. Results reported `max_delta=0.0` and `mean_delta=0.0` for disabled-with-textures, enabled-missing-simulation-texture, and enabled-missing-boundary-texture render comparisons against the baseline river shader.
- Visible result, if applicable: Not human-visible; probe uses validation-only render readback for exact pixel comparison.
- Stable result marker: `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`
- Pass/partial/fail: Pass for minimal built-in river shader disabled/missing-texture neutral path.
- Notes or follow-up: `river.gdshader` declares the planned neutral-default `i_ripple_*` uniforms and guarded helper functions. Later visible-normal validation now proves disabled/missing texture cases stay neutral and enabled wave textures change the normal response.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_material_ownership_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`. Expected warnings were printed for rejected invalid calls: non-ripple `i_flowmap`, unknown `i_ripple_unplanned`, wrong-owner apply, and wrong-owner clear.
- Visible result, if applicable: Not a visible scene; probe used generated RiverManager instances and test-only shader materials.
- Stable result marker: `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`
- Pass/partial/fail: Pass for RiverManager-facing material ownership/restore gate.
- Notes or follow-up: Probe proved the runtime API now accepts the built-in river shader's declared `i_ripple_*` uniforms through duplicated runtime materials, applies only planned `i_ripple_*` state, keeps shared source material unchanged, prevents wrong-owner apply/clear, preserves unrelated river state when one target clears, survives debug view toggles, and restores original ripple textures on explicit clear, owner tree exit, and river tree exit. `river_debug.gdshader`, bakes, WaterSystem, source signatures, and buoyancy files remained untouched.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 requested; exact renderer/device not relayed.
- Command, scene, or workflow: Opened and reviewed `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_review.tscn`; provided screenshot `C:\Users\pc\Desktop\ripple_boundary_mask_review.png`.
- Output or parser errors: None relayed.
- Visible result, if applicable: Screenshot shows the boundary mask as the expected two-branch river footprint with the center dry gap dark. Green/blue water sample positions correspond to white mask areas; red/yellow/pink dry sample positions are outside the white footprint. The left target mesh pane is low contrast, but the mask pane is readable.
- Stable result marker: Human-visible boundary-mask review.
- Pass/partial/fail: Pass for human-visible standalone mesh-footprint boundary-mask review.
- Notes or follow-up: Boundary mask is now covered by automated and human-visible validation. Material ownership/restore, disabled/missing-texture neutral river shader validation, and helper-budget validation have since passed; proceed to minimal visible normal blending before response tuning.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_probe.gd`
- Output or parser errors: None on final run.
- Visible result, if applicable: Console probe smoke-instantiated `ripple_boundary_mask_review.tscn`. User later reviewed the visible scene via screenshot and confirmed the mask shape/dry gap.
- Stable result marker: `RIPPLE_BOUNDARY_MASK_PROBE_OK`
- Pass/partial/fail: Pass for standalone target river mesh-footprint boundary-mask rendering and standalone feedback boundary sampling.
- Notes or follow-up: Probe rendered a generated Waterways river mesh footprint into ripple-field space with the same `world_to_ripple_uv` contract, rejected a dry-corner impulse with `max_delta=0.0`, kept the dry gap neutral, and held the across-bank sample below threshold after 40 steps. Material ownership/restore, disabled/missing-texture neutral river shader validation, and helper-budget validation have since passed; proceed to minimal visible normal blending before response tuning.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 requested; exact renderer/device not relayed.
- Command, scene, or workflow: Opened and reviewed `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_review.tscn`.
- Output or parser errors: None relayed.
- Visible result, if applicable: User noted the left scene view reads wider/rectangular while the right texture view reads square, then confirmed the colored dots/markers match relative positions in each view and that there is agreement.
- Stable result marker: Human-visible mapping review.
- Pass/partial/fail: Pass for human-visible standalone mapping agreement; the aspect-ratio difference is expected because the world field is rectangular while the UV texture display is square.
- Notes or follow-up: Automated and human-visible mesh-footprint boundary-mask validation, RiverManager material ownership/restore validation, disabled/missing-texture neutral river shader validation, and helper-budget validation have since passed; proceed to minimal visible normal blending before response tuning.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_MAPPING_PROBE_OK`. After the pass marker, Godot printed Vulkan `swap_chain_resize ERR_CANT_CREATE` shutdown warnings; process exit code was 0 and no parser/shader errors appeared before the pass marker.
- Visible result, if applicable: Later human review confirmed the colored scene markers agree with the matching colored texture impulses. The console probe also smoke-instantiates the scene-marker pane and texture-marker view.
- Stable result marker: `RIPPLE_MAPPING_PROBE_OK`
- Pass/partial/fail: Pass for standalone axis-aligned X/Z `world_to_ripple_uv` generation and equivalent probe shader mapping.
- Notes or follow-up: Automated and human-visible mesh-footprint boundary-mask validation, RiverManager material ownership/restore validation, disabled/missing-texture neutral river shader validation, and helper-budget validation have since passed; proceed to minimal visible normal blending before response tuning.

Recorded result:

- Date: 2026-06-07
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 assumed from requested review path; exact renderer/device not relayed.
- Command, scene, or workflow: Opened and ran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_review.tscn`.
- Output or parser errors: None relayed.
- Visible result, if applicable: User saw a pulse emanate from the center outward and confirmed it decays the farther it moves from the initial impulse spot. User also saw a square outline start near the outside of the colored square and move inward.
- Stable result marker: Human-visible review.
- Pass/partial/fail: Pass for standalone center impulse spread/decay; partial for river readiness because the square outline is a standalone rectangular-field artifact that must be replaced by real boundary masking before visible river integration.
- Notes or follow-up: Mapping, mesh-footprint boundary masking, RiverManager material ownership/restore, disabled/missing-texture river shader neutrality, and helper-budget validation are now covered by automated probes; proceed to minimal visible normal blending before response tuning.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_analysis_probe.gd`
- Output or parser errors: None on final run.
- Visible result, if applicable: Agent inspected repo-local validation captures under `.codex-research/ripple-feedback-analysis`; fixed impulse, ring spread, and decay are visible in captured frames.
- Stable result marker: `RIPPLE_FEEDBACK_ANALYSIS_OK`
- Pass/partial/fail: Pass for automated analysis; later human-visible scene review passed for standalone feedback.
- Notes or follow-up: Probe intentionally uses validation-only `get_image()` readback to measure the texture. Normal runtime feedback and visible rendering still avoid CPU readback. Metrics passed at 128, 256, and 512 with no saturation.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_probe.gd`
- Output or parser errors: None on final run.
- Visible result, if applicable: Not inspected by agent during this probe; later user review of `ripple_feedback_review.tscn` confirmed center pulse spread and decay.
- Stable result marker: `RIPPLE_FEEDBACK_PROBE_OK`
- Pass/partial/fail: Partial
- Notes or follow-up: Probe reported 128x128 read/write textures, distinct viewports/textures, no same-target hazard on the last step, and `normal_runtime_readback=false`. Static scan found no normal-runtime ripple `get_image()` calls; the separate analysis probe uses validation-only readback. The forbidden-file diff at that stage found no changes to river bakes, WaterSystem, source signatures, `system_flow.gdshader`, buoyancy, `river.gdshader`, or `river_debug.gdshader`; the later neutral-path slice intentionally changed only `river.gdshader` among those named files.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Not run
- Command, scene, or workflow: Documentation creation only
- Output or parser errors: Not applicable
- Visible result, if applicable: Not applicable
- Stable result marker: None
- Pass/partial/fail: Partial
- Notes or follow-up: Historical docs-only starting point. Implementation validation has since passed through the current field/emitter console gates; see the current snapshot and newer recorded results above.

## Historical Results Archive

Move older validation narratives here once the current snapshot and matrix carry the important status.

## Shader Checks

- Shader/material path:
  - `addons/waterways/shaders/runtime/ripple_simulation.gdshader`
  - `addons/waterways/shaders/runtime/ripple_impulse.gdshader`
  - `addons/waterways/shaders/river.gdshader`
  - Optional future `addons/waterways/shaders/river_debug.gdshader`
- Renderer backend:
  - Forward+ first unless Phase 0 chooses a different target; Mobile and Compatibility now have focused console/render coverage and should be rerun after renderer-sensitive changes.
- Expected result:
  - Simulation shader produces decaying rings.
  - Visible river shader is neutral when disabled or missing texture.
  - Enabled normal overlay blends with existing flow animation.
- Failure signs:
  - Shader compile errors, same-texture feedback artifacts, stuck height field, non-decaying waves, wrong UV mapping, excessive shimmer, or disabled-path visual changes.

## Editor Workflow Check

Procedure:

1. Add or select the registered `WaterRippleField` custom type.
2. Configure resolution, bounds/transform, target river, and at least one emitter; confirm any node-level debug flag is hidden unless it has real helper behavior.
3. Toggle enabled/disabled and reload the scene.

Expected result:

- Inspector fields are clear, warnings are actionable, existing debug views remain available through the accepted debug path, node-level debug helper flags are not exposed as inert promises, disabling is neutral, and reload does not leave stale texture state.

Failure signs:

- Missing custom type registration when docs say nodes are public, confusing warnings, stale runtime texture assignments, or changed river bakes.

## Visual Test Scene

Scene path:

- `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_review.tscn`
- `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_review.tscn`
- `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_review.tscn`
- `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn`
- `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`

Purpose:

- Prove standalone ripple feedback, mapping, boundary mask, and visible river overlay before demo acceptance.
- The mapping scene specifically compares fixed world-space scene markers against texture-space impulses generated with the same `world_to_ripple_uv`.
- The field/emitter demo review scene proves the reusable nodes are inspectable in a demo-backed scene tree; named Add Node registration now also lets new fields/emitters be added through the editor Add Node flow, confirmed by user review in both `Demo.tscn` and `ripple_field_emitter_demo_review.tscn`.

Expected visual result:

- In `ripple_mapping_review.tscn`, each colored fixed scene marker lines up with the matching colored texture impulse.
- In `ripple_river_shader_visible_normal_review.tscn`, Space toggles runtime ripple normals off/on on the demo river, 0 returns to the normal visible river, 1/2/3 adjust review strength, 4/5/6/7 switch raw ripple height, impulse/contact, boundary mask, and visible influence debug views, C cycles close overhead/original demo overhead/close oblique cameras, R resets the review camera, WASD/QE moves the close review camera, right-mouse drag changes look direction, and the mouse wheel zooms.
- In `ripple_field_emitter_demo_review.tscn`, select `WaterRippleField` and its `PulseEmitter_UpperWater`, `OneShotEmitter_MidBend`, and `MovingEmitter_TestTrail` children in the scene tree to inspect the authoring setup. Space toggles the field on/off, F queues a manual pulse from all emitters, M toggles the moving emitter, 0 returns to the normal visible river, 4/5/6/7 switch raw ripple height, impulse/contact, boundary mask, and visible influence debug views, C cycles close overhead/close oblique/demo cameras, R resets feedback/camera, WASD/QE moves the close review camera, right-mouse drag changes look direction, and the mouse wheel zooms.
- Fixed and moving emitters create localized decaying rings.
- Boundary mask matches target water footprint.
- Visible ripples blend with existing river motion.
- Debug view switching preserves the same runtime ripple texture state and does not hide the visible river state when returning to 0.
- Disabling the field with Space removes runtime ripple state and should make the river match its old visible baseline; re-enabling should not leave stale material state after stop/reload.

Failure signs:

- No rings, rings at wrong positions, rings crossing banks, endless energy, flicker, shimmer, material cross-talk, or changed disabled baseline.

## Field/Emitter Human Review Request

Use this exact request if this visible review needs to be rerun:

1. Open Godot 4.6.3 with the project at `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`.
2. Open and run `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`.
3. Confirm the plugin is enabled as it is in the project default. Do not run a river bake.
4. In the running scene, select `WaterRippleField` and its three emitter children in the scene tree if the editor is visible. Confirm the field targets `World/WaterSystem/Water River`, uses 256 resolution, and has pulse, one-shot, and moving emitters under it.
5. Visually check that the blue/green/orange emitter markers and emitter handles line up over exposed river water and are not embedded in terrain. The handles may hover slightly above the surface for readability; pressing F should now create stronger localized ripple rings directly under those marker positions. The orange moving emitter should stay farther out over the exposed river, leaving a denser local trail along the water rather than visibly separated pulse beats, crossing dry terrain, or flooding the whole river.
6. Press 6 to inspect the boundary mask. The mask should follow the river footprint and not look like a full square field. Press 4 for raw ripple height, 5 for impulse/contact, 7 for visible influence, and 0 to return to the normal visible river.
7. Press Space to disable the field. The river should return to the old baseline look, with no stuck ripple texture or debug material. Press Space again and F to confirm ripples reapply cleanly.
8. Stop and run the scene again. Confirm the river does not start with stale ripples or stuck debug/material state.
9. Relay any Output panel errors, whether the renderer is Forward+/Mobile/Compatibility, the GPU/device name if visible, and what you saw for marker placement, F pulse location, Space disable baseline, debug views, and stop/reload cleanup.

Suggested controls or debug views:

- Raw ripple texture.
- Impulse texture.
- Boundary mask.
- Visible influence.
- Normal visible river return mode.
- Ripple enabled/disabled.
- Fixed emitter and moving emitter toggles.

## Bake Output Check

Scenario:

- First-pass visual ripples should not run a bake.

Expected generated outputs:

- Flow: Unchanged.
- Foam: Unchanged.
- Distance/pressure: Unchanged.
- Height/alpha: Unchanged.
- Metadata: Unchanged.

Failure signs:

- River bake resource changes, WaterSystem bake changes, source-signature bump, or regenerated maps during visual-only work.

## Runtime API Check

Procedure:

- After runtime nodes exist, initialize a field, register a target river, assign one emitter, disable the field, unregister the target, and reload the scene.

Expected result:

- Target materials receive only intended `i_ripple_*` uniforms while enabled.
- Disabling or unregistering clears or restores runtime state.
- Unrelated rivers are unaffected.

Failure signs:

- Uniforms remain after cleanup, shared material cross-talk, missing texture errors, hidden debug material state, or runtime-only crashes.

## Performance Check

Scenario:

- Current shader-cost gate: measure the current river shader paths with ripples disabled, enabled visible normals, and debug inspection modes.
- Current field/emitter gate: measure default ripple field at 128, 256, and 512 with no emitters, a few emitters, and many emitters.

Budget or target:

- Default settings should be affordable in the demo.
- Disabled river shader path should have zero avoidable ripple texture samples.
- First-pass enabled normal path should target no more than three additional ripple texture samples near camera.
- Current controlled shader-cost pass accepts the existing visible path: three simulation samples, one boundary helper call, no direct visible-fragment ripple sampling, and `+0.004 ms` median GPU over disabled live textures on the recorded Forward+ desktop run.
- Current field/emitter dispatch pass accepts the reusable node path at 128/256/512 with 0/4/16 emitters on the recorded Forward+ desktop run.

How to measure:

- For shader-cost checks, run `ripple_shader_cost_probe.gd`, which uses `RenderingServer` per-viewport CPU/GPU render-time measurement and static shader sample counts.
- For field/emitter checks, record renderer, resolution, emitter count, update rate, visible shader state, and whether runtime uses CPU readback.

## Artifact Hygiene Check

- Scratch project or temporary folder used:
  - Repo-local `.codex-research/godot-user` for isolated Godot console profile.
  - Repo-local `.codex-research/ripple-feedback-analysis` for validation-only PNG captures.
  - Repo-local `.codex-research/ripple-review-diagnostic` for validation-only demo review diagnostic captures.
- Active scripts/resources mirrored into scratch before validation:
  - Not applicable.
- Generated bakes/resources created:
  - None.
- Files or folders that must be excluded from packaging:
  - `.codex-research` probes, local captures, and disposable prototype outputs unless promoted.
- Files or folders safe to delete now:
  - None.

## Extension Check

Custom content scenario:

- Multiple rivers with separate ripple fields and explicit target registration.

Expected result:

- Each field affects only intended targets and cleanup is independent.

Failure signs:

- Global group discovery consumes unrelated emitters, shared material resources receive wrong texture, or disabling one field affects another river.

## Manual Review Checklist

- [ ] Acceptance criteria are satisfied.
- [ ] Likely false premises or expected-behavior explanations were raised with the user before extra implementation work.
- [ ] Human-assisted Godot/editor/test results are recorded when the agent could not run them directly.
- [ ] Active code uses Godot 4.6+ APIs and avoids obsolete Godot 3 APIs.
- [ ] Editor-only and runtime-safe boundaries are preserved.
- [ ] Generated resources and metadata are explicit and inspectable.
- [ ] Visual output matches the spec.
- [ ] Flow direction, seams, foam, masks, and bounds are checked visually.
- [ ] Runtime sampling/API behavior matches generated data.
- [ ] Performance-sensitive paths have been checked.
- [ ] Known limitations are documented.
- [ ] Shared research citations were checked or updated when external river/water references affected the decision.
