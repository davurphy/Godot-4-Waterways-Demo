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

- Overall status: Unrun for implementation; docs-only creation complete.
- Last automated pass: None for ripple code; documentation consistency and citation-index checks only.
- Last human-assisted pass: None.
- Highest-risk unproven behavior: Godot 4.6+ no-readback ping-pong feedback timing and material ownership cleanup.
- Known unreliable local check or environment caveat: Headless/parser checks can catch syntax or load issues, but they are not proof of visible editor interaction, shader visuals, runtime simulation, or viewport feedback behavior.

## Validation Matrix

Use this as the durable map from requirements to proof. Prefer stable probe names, scene names, or result markers.

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| Visual-only boundary | Git/resource diff after implementation | Local static review | No river bakes, WaterSystem bakes, source signatures, `system_flow.gdshader`, or buoyancy files changed | Unrun | 2026-06-07 | Agent |
| Source-signature boundary | Static diff and targeted source-signature scan | Local static review | No source-signature constants, hashes, metadata, or invalidation logic changed | Unrun | 2026-06-07 | Agent |
| River bake boundary | Git/resource diff after implementation | Local static review | No generated river bake textures, saved `RiverBakeData`, or bake metadata changed | Unrun | 2026-06-07 | Agent |
| WaterSystem boundary | Git/resource diff and WaterSystem path scan | Local static review | No WaterSystem bake resources, regeneration paths, `system_flow.gdshader`, or runtime WaterSystem sampling behavior changed | Unrun | 2026-06-07 | Agent |
| Buoyancy boundary | Static diff and runtime behavior review if buoyant objects are present | Local static/human-assisted review | No buoyancy, object drift, reverse-flow, or eddy-circulation behavior changed | Unrun | 2026-06-07 | Agent/User |
| No normal-runtime readback | Static scan for `get_image()` or equivalent in ripple runtime path | Local static review | No readback in normal simulation or visible rendering loop | Unrun | 2026-06-07 | Agent |
| Feedback ownership | Standalone ripple feedback probe | Godot 4.6.3 console/editor | Rings spread and decay; read/write targets are distinct | Unrun | 2026-06-07 | Agent/User |
| Texture precision | Ripple feedback probe at 128, 256, 512 | Godot 4.6.3 visible/runtime | Waves decay without unusable banding or instability | Unrun | 2026-06-07 | User |
| Mapping contract | Fixed marker mapping probe | Godot 4.6.3 visible/runtime | Scene marker and debug texture impulse align | Unrun | 2026-06-07 | User |
| Boundary mask | Boundary debug view | Godot 4.6.3 visible/runtime | Target river footprint is visible; waves do not cross dry areas | Unrun | 2026-06-07 | User |
| River shader neutral disabled path | Demo comparison with ripple disabled/missing texture | Godot 4.6.3 visible/runtime | River matches old baseline | Unrun | 2026-06-07 | User |
| River shader enabled path | Demo visible ripple review | Godot 4.6.3 visible/runtime | Local rings appear at emitter positions and blend with flow animation | Unrun | 2026-06-07 | User |
| Debug parity | Debug shader/view/probe | Godot 4.6.3 visible/runtime | Raw ripple, impulse, boundary, and visible influence inspectable | Unrun | 2026-06-07 | Agent/User |
| Material cross-talk | Two-river target probe | Godot 4.6.3 runtime | Disabling one field does not affect unrelated river | Unrun | 2026-06-07 | Agent/User |
| Scene reload cleanup | Reload probe | Godot 4.6.3 runtime/editor | No stale ripple textures remain assigned | Unrun | 2026-06-07 | Agent/User |
| Performance budget | Resolution/emitter/shader sample review | Godot 4.6.3 runtime/editor | Default settings affordable; disabled path avoids samples | Unrun | 2026-06-07 | Agent/User |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
  - Visual ripple rings will not move objects, change current direction, or alter buoyancy in the first milestone.
  - A standalone rectangular field can be acceptable for Phase 1 but still invalid for river overlay until boundary masking passes.
  - Strong normal/refraction ripples can make water appear to flow differently even when actual flow is unchanged.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
  - Stale generated river material state.
  - Debug material override hiding visible material uniforms.
  - Shared material resource receiving runtime uniforms from the wrong field.
  - Ripple field bounds not covering the reviewed water area.
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
  - "Please open the ripple review scene or `Demo.tscn`, run it in Godot 4.6.3, and report the renderer, any Output errors, and what you see in the raw ripple, impulse, boundary, and visible river views."
- Exact scene, command, or workflow to run:
  - To be filled once the ripple review scene or demo integration exists.
- Plugin state required:
  - Waterways add-on enabled if testing registered public nodes.
- Console output or errors to relay back:
  - Parser errors, shader errors, material warnings, missing uniform warnings, and any `RIPPLE_*` probe markers.
- Screenshot or visible behavior to relay back:
  - Fixed emitter rings, moving emitter trail, boundary mask, disabled baseline, and visible river overlay.
- Godot version and renderer to relay back:
  - Godot 4.6.3, renderer backend, OS/GPU if practical.
- Expected result:
  - Localized decaying rings at emitter positions, no obvious cross-bank propagation, neutral disabled path, and existing flow/pillow/wake/eddy-line visuals preserved.
- Failure signs:
  - Rings at wrong positions, waves crossing dry land, no decay, stale textures after reload, unrelated rivers affected, shader errors, or visual baseline changing while disabled.
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
- Godot version/renderer/device: Not run
- Command, scene, or workflow: Documentation creation only
- Output or parser errors: Not applicable
- Visible result, if applicable: Not applicable
- Stable result marker: None
- Pass/partial/fail: Partial
- Notes or follow-up: Feature folder was created from the roadmap and templates. Implementation validation remains unrun.

## Historical Results Archive

Move older validation narratives here once the current snapshot and matrix carry the important status.

## Shader Checks

- Shader/material path:
  - Future `addons/waterways/shaders/runtime/ripple_simulation.gdshader`
  - Future `addons/waterways/shaders/river.gdshader`
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

- No visual test scene exists yet. Phase 1 should create a standalone ripple review scene or probe and record the concrete path here.

Purpose:

- Prove standalone ripple feedback, mapping, boundary mask, and visible river overlay before demo acceptance.

Expected visual result:

- Fixed and moving emitters create localized decaying rings.
- Boundary mask matches target water footprint.
- Visible ripples blend with existing river motion.

Failure signs:

- No rings, rings at wrong positions, rings crossing banks, endless energy, flicker, shimmer, material cross-talk, or changed disabled baseline.

Suggested controls or debug views:

- Raw ripple texture.
- Impulse texture.
- Boundary mask.
- Visible influence.
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

- Measure default ripple field at 128, 256, and 512 with no emitters, a few emitters, and many emitters.

Budget or target:

- Default settings should be affordable in the demo.
- Disabled river shader path should have zero avoidable ripple texture samples.
- First-pass enabled normal path should target no more than three additional ripple texture samples near camera.

How to measure:

- Use Godot profiler or agreed frame-time/GPU timing method once implementation exists.
- Record renderer, resolution, emitter count, update rate, and visible shader state.

## Artifact Hygiene Check

- Scratch project or temporary folder used:
  - None yet.
- Active scripts/resources mirrored into scratch before validation:
  - Not applicable.
- Generated bakes/resources created:
  - None.
- Files or folders that must be excluded from packaging:
  - Future `.codex-research` probes, local captures, and disposable prototype outputs unless promoted.
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
