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

## Current Validation Snapshot

Keep this short and current. Older detailed runs belong in "Recorded Results" below.

- Overall status: Standalone feedback spike passed console/static validation and human-visible review; standalone mapping probe passed console and human-visible validation; standalone mesh-footprint boundary-mask probe passed console and human-visible validation; RiverManager-facing material ownership/restore, minimal river shader neutral path, river shader visible-normal path, river shader sampling-budget, shader-cost/performance, demo review-scene smoke, demo review-scene diagnostic, debug parity, reusable field/emitter lifecycle, field/emitter dispatch-performance, and post-clear-fix terrain-aware demo-backed field/emitter authoring checks passed console validation; demo-backed visible normal review passed the current human-visible base-flow/outward-ring gate; demo-backed debug parity passed human-visible review for the currently expected debug outputs.
- Last automated pass: post-clear-fix `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, and `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK` in Godot 4.6.3 Forward+ on 2026-06-07. The demo probe now requires terrain samples, exposed water anchors, visible emitter-handle clearance, moving-path clearance, localized impulse stamps on a black background, disable baseline restore, and reload cleanup. Earlier regression passes include `RIPPLE_SHADER_COST_PROBE_OK`, `RIPPLE_DEBUG_PARITY_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK`, `RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK`, `RIPPLE_FEEDBACK_PROBE_OK`, `RIPPLE_BOUNDARY_MASK_PROBE_OK`, and `RIPPLE_FEEDBACK_ANALYSIS_OK`.
- Last human-assisted result: User reported the first field/emitter demo authoring scene did not visually line up with the river and that two emitters were embedded in the terrain. After terrain-aware placement, user reported no visible ripples: impulse/contact was blue everywhere, green one-shot was not visibly flashing, visible influence was black, and normal view showed no rings. The field now clears offscreen canvas viewports to transparent zero so empty impulse/contact is black instead of a nonzero full-field sheet; human-visible rerun remains open.
- Highest-risk unproven behavior: Human-visible acceptance of the revised terrain-aware WaterRippleField/emitter authoring workflow in the demo scene, non-Forward+ renderer coverage, and later public API/custom type polish.
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
| Runtime field/emitter lifecycle | `ripple_field_emitter_probe.gd`, prototype field/emitter scenes, and RiverManager material state | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT | Field initializes, owns runtime targets, maps world impulses, applies only intended material state, caps emitters, rejects invalid impulses, disables cleanly, and frees cleanly | Pass: `RIPPLE_FIELD_EMITTER_PROBE_OK`; runtime initialized with 128x128 read/write/impulse/boundary targets, boundary source `target_river_mesh_footprint`, target/apply counts `1`, distinct viewports/textures, no same-target hazard, no runtime readback, capped emitters reported, out-of-bounds impulse rejected, and disable/free cleanup restored material state | 2026-06-07 | Agent |
| Demo-backed field/emitter authoring | `ripple_field_emitter_demo_review.tscn`, `ripple_field_emitter_demo_review_probe.gd`, and `ripple_field_emitter_demo_review_diagnostic.gd` | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT | Demo scene exposes real field/emitter nodes, target river state applies through RiverManager, fixed/moving emitters map to visible exposed water positions, impulse/contact clears to black except localized emitter flashes, disabling restores baseline, and reload creates fresh runtime state | Pass after two user-reported visible failures: terrain-aware `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` covers demo scene load, close overhead camera, 256x256 field bounds, mesh-footprint boundary, preserved `flow_speed=1.0`, exposed-water anchors, lifted handles/markers, three emitter impulse stamps, disable/reapply/reload cleanup. A later no-visible-ripples report led to `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`, which found the old impulse texture had full-field nonzero background (`min=0.30196`, `changed_count=65536`); after transparent-zero viewport clearing, impulse texture reports `min=0.0`, `mean=0.000208`, `changed_count=118`, and localized samples for blue/green/orange emitters. The main probe now rejects nonblack impulse backgrounds. Human-visible rerun remains open. | 2026-06-07 | Agent/User |
| Scene reload cleanup | `ripple_material_ownership_probe.gd` owner/river exit checks, `ripple_field_emitter_probe.gd` field disable/free checks, and `ripple_field_emitter_demo_review_probe.gd` reload check | Godot 4.6.3 Forward+ console with built-in and test-only shader material | No stale ripple textures remain assigned | Pass for current console gate: RiverManager clear, owner tree exit, and river tree exit restored original material/texture; prototype `WaterRippleField` disable/reenable/free cleared owner-scoped runtime material state; demo-backed review scene reload/disable restored the baseline material and created fresh runtime state. Human-visible editor scene reload remains a workflow check. | 2026-06-07 | Agent |
| Shader cost/performance budget | `ripple_shader_cost_probe.gd` plus sampling/neutral probes | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT | Disabled path avoids direct ripple samples; enabled visible normal path stays within the first-pass sample/timing budget; debug modes are measured as inspection tools | Pass: `RIPPLE_SHADER_COST_PROBE_OK`; static disabled-ready and visible-fragment direct ripple samples were `0`; enabled normal helper stayed at `3` simulation samples and `1` boundary helper call; 640x360 median GPU was baseline `0.312 ms`, disabled live textures `0.315 ms` (`+0.003 ms`), enabled visible normal `0.319 ms` (`+0.004 ms` over disabled), and debug raw/contact/boundary/influence medians `0.115/0.118/0.117/0.129 ms`; all cases stayed at one draw call | 2026-06-07 | Agent |
| Runtime field/emitter production performance | `ripple_field_emitter_performance_probe.gd` resolution and emitter-count sweep | Godot 4.6.3 Forward+ console, Vulkan, AMD Radeon RX 6800 XT | 128/256/512, no emitters, few emitters, many emitters, shader disabled, and shader enabled results are recorded for the current reusable-node path | Pass for current field/emitter dispatch gate after transparent-zero viewport clearing: `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`; 128 resolution dispatch medians were `5.477/6.059/5.704 ms` for 0/4/16 emitters, 256 medians `6.405/5.650/5.521 ms`, and 512 medians `5.754/5.508/5.377 ms`. Shader disabled/enabled timing remains covered by `RIPPLE_SHADER_COST_PROBE_OK`; human-visible demo production and non-Forward+ coverage remain open. | 2026-06-07 | Agent |

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
  - Mesh-derived emitter anchors landing on valid river mesh vertices that are hidden by nearby terrain. User caught this in the first field/emitter authoring review; the demo review controller now samples `World/HTerrain`, chooses exposed water anchors near the authored UVs, lifts authoring handles above terrain, and the probe rejects buried anchors/handles.
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

## Recorded Results

Record new runs here. Put the newest and most relevant result first, then move older detail under an archive marker when the section gets long.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review_probe.gd`
- Output or parser errors: Stable marker `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`. First run caught a GDScript inference error in the review controller and a marker global-transform timing issue; both were fixed before the passing run.
- Visible result, if applicable: Not human-visible; this is a console validation of the demo-backed authoring scene. Human-visible review is still requested through `ripple_field_emitter_demo_review.tscn`.
- Stable result marker: `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`
- Pass/partial/fail: Pass for automated demo authoring integration.
- Notes or follow-up: The probe validated that the scene exposes real `WaterRippleField`/`WaterRippleEmitter` nodes, targets only the demo river, generates the mesh-footprint boundary mask, maps fixed emitters to expected water UVs, keeps the moving emitter in-bounds on the authored path, renders three impulse stamps, preserves base `flow_speed=1.0`, disables back to the baseline material, reapplies runtime state, and reloads without stale runtime material state. Human-visible editor/runtime acceptance remains open.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_performance_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`.
- Visible result, if applicable: Not human-visible; this is a dispatch-time field/emitter sweep for the reusable prototype path.
- Stable result marker: `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`
- Pass/partial/fail: Pass for the current Forward+ field/emitter production-dispatch gate. Dispatch medians for 0/4/16 emitters were `5.933/5.738/5.755 ms` at 128, `5.981/5.518/5.799 ms` at 256, and `5.511/6.202/5.866 ms` at 512. Each case applied to one generated river target and reported the expected texture size.
- Notes or follow-up: The probe measures runtime field/emitter dispatch work, not human-visible demo polish. Non-Forward+ renderer coverage and a demo authoring workflow review remain open.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_FIELD_EMITTER_PROBE_OK`.
- Visible result, if applicable: Not human-visible; this validates the reusable runtime field/emitter lifecycle and material ownership path.
- Stable result marker: `RIPPLE_FIELD_EMITTER_PROBE_OK`
- Pass/partial/fail: Pass. The field initialized 128x128 read/write/impulse/boundary targets, generated the boundary mask from the target river mesh footprint, kept read/write/impulse/boundary viewports and textures distinct, applied runtime material state to one intended target, rejected an out-of-bounds impulse, rendered the emitter cap/priority path, reported no same-target hazard and no normal-runtime readback, and restored target material state on disable and free.
- Notes or follow-up: This proves the console lifecycle path for prototype nodes. Demo-backed authoring integration is now covered by `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`; human-visible editor scene workflow and public custom type registration remain separate gates.

Recorded result:

- Date: 2026-06-07
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Profile-isolated console probe `--script res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_shader_cost_probe.gd`.
- Output or parser errors: Stable marker `RIPPLE_SHADER_COST_PROBE_OK`. The probe used `RenderingServer.viewport_set_measure_render_time()` on a 640x360 offscreen viewport, 24 warmup frames, and 72 measured frames per case.
- Visible result, if applicable: Not human-visible; this is a controlled renderer-cost and static sample-budget probe.
- Stable result marker: `RIPPLE_SHADER_COST_PROBE_OK`
- Pass/partial/fail: Pass for the current shader-cost gate. Static checks reported disabled-ready ripple samples `0`, visible-fragment direct ripple samples `0`, one visible helper call from `fragment()`, and the accepted enabled-normal budget of three simulation samples plus one boundary helper call. Measured median GPU timings were baseline `0.312 ms`, disabled live textures `0.315 ms`, enabled visible normal `0.319 ms`; disabled delta was `+0.003 ms`, enabled-over-disabled delta was `+0.004 ms`, and all visible cases stayed at one draw call. Debug medians were raw height `0.115 ms`, impulse/contact `0.118 ms`, boundary mask `0.117 ms`, and visible influence `0.129 ms`; these are recorded as inspection-tool costs, not visual tuning targets.
- Notes or follow-up: This proves the current disabled/visible/debug river shader paths are affordable enough for the first-pass gate on this Forward+ desktop setup. Field/emitter dispatch sweeps now have their own pass above; human-visible demo production review and non-Forward+ coverage remain open.

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
- Notes or follow-up: Render contrast measurements were `0.27058823406696` for raw height, `0.81960785388947` for impulse/contact, `0.81960785388947` for boundary mask, and `0.82091504335403` for visible influence. Shader-cost, reusable field/emitter console validation, and demo-backed authoring console validation have since passed; the current next gate is human-visible field/emitter authoring review before response/refraction/displacement tuning.

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
  - Forward+ first unless Phase 0 chooses a different target; Mobile and Compatibility need explicit verification.
- Expected result:
  - Simulation shader produces decaying rings.
  - Visible river shader is neutral when disabled or missing texture.
  - Enabled normal overlay blends with existing flow animation.
- Failure signs:
  - Shader compile errors, same-texture feedback artifacts, stuck height field, non-decaying waves, wrong UV mapping, excessive shimmer, or disabled-path visual changes.

## Editor Workflow Check

Procedure:

1. Add or select `WaterRippleField` after public/prototype status is decided.
2. Configure resolution, bounds/transform, target river, debug visibility, and at least one emitter.
3. Toggle enabled/disabled and reload the scene.

Expected result:

- Inspector fields are clear, warnings are actionable, debug view is available, disabling is neutral, and reload does not leave stale texture state.

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
- The field/emitter demo review scene proves the reusable prototype nodes are inspectable in a demo-backed scene tree before public custom type registration.

Expected visual result:

- In `ripple_mapping_review.tscn`, each colored fixed scene marker lines up with the matching colored texture impulse.
- In `ripple_river_shader_visible_normal_review.tscn`, Space toggles runtime ripple normals off/on on the demo river, 0 returns to the normal visible river, 1/2/3 adjust review strength, 4/5/6/7 switch raw ripple height, impulse/contact, boundary mask, and visible influence debug views, C cycles close overhead/original demo overhead/close oblique cameras, R resets the review camera, WASD/QE moves the close review camera, right-mouse drag changes look direction, and the mouse wheel zooms.
- In `ripple_field_emitter_demo_review.tscn`, select `WaterRippleField` and its `PulseEmitter_UpperWater`, `OneShotEmitter_MidBend`, and `MovingEmitter_TestTrail` children in the scene tree to inspect the prototype authoring setup. Space toggles the field on/off, F queues a manual pulse from all emitters, M toggles the moving emitter, 0 returns to the normal visible river, 4/5/6/7 switch raw ripple height, impulse/contact, boundary mask, and visible influence debug views, C cycles close overhead/close oblique/demo cameras, R resets feedback/camera, WASD/QE moves the close review camera, right-mouse drag changes look direction, and the mouse wheel zooms.
- Fixed and moving emitters create localized decaying rings.
- Boundary mask matches target water footprint.
- Visible ripples blend with existing river motion.
- Debug view switching preserves the same runtime ripple texture state and does not hide the visible river state when returning to 0.
- Disabling the field with Space removes runtime ripple state and should make the river match its old visible baseline; re-enabling should not leave stale material state after stop/reload.

Failure signs:

- No rings, rings at wrong positions, rings crossing banks, endless energy, flicker, shimmer, material cross-talk, or changed disabled baseline.

## Field/Emitter Human Review Request

Use this exact request when asking for the next visible review:

1. Open Godot 4.6.3 with the project at `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`.
2. Open and run `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`.
3. Confirm the plugin is enabled as it is in the project default. Do not run a river bake.
4. In the running scene, select `WaterRippleField` and its three emitter children in the scene tree if the editor is visible. Confirm the field targets `World/WaterSystem/Water River`, uses 256 resolution, and has pulse, one-shot, and moving emitters under it.
5. Visually check that the blue/green/orange emitter markers and emitter handles line up over exposed river water and are not embedded in terrain. The handles may hover slightly above the surface for readability; pressing F should create localized ripple rings directly under those marker positions. The moving emitter should leave a small local trail along the river rather than crossing dry terrain or flooding the whole river.
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
- Current field/emitter dispatch pass accepts the prototype path at 128/256/512 with 0/4/16 emitters on the recorded Forward+ desktop run.

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
