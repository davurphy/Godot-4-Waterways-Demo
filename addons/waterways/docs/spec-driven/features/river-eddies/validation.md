# Validation: River Eddies

## What Must Be Proven

- The accepted Phase 7B `Eddy-Line Visual Mask` remains derived from raw-G wake-edge placement plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- Old B-based eddy-line paths remain available as diagnostics.
- Raw source masks, final visual masks, and visible material response are reviewed separately.
- Phase 7B remains visual-only: no source-flow change, no final-flow/reverse-flow change, no WaterSystem regeneration, and no saved WaterSystem bake change.
- Main demo and obstacle-test layouts do not show ordinary-bank strips as accepted eddy lines.
- Any future Phase 7C/7D flow work updates visible shader, debug shader, system-flow shader, WaterSystem generation, and runtime validation together.

## Current Validation Snapshot

This is the validation dashboard. The matrix answers what is currently proven; recorded results and archives explain how those conclusions were reached.

- Overall status: Pass for accepted Phase 7B visual baseline; unrun for Phase 7C/7D flow.
- Last automated pass: Historical Godot 4.6.3 probes `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_WAKE_EDDY_EXPORT_OK`, and `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`.
- Last human-assisted pass: User accepted the visible eddy-line pass after the material-override fix and stronger defaults.
- Highest-risk unproven behavior: Real reverse/circulating flow and WaterSystem/physics alignment.
- Known unreliable local check or environment caveat: Local scripted probes are useful, but not proof of visible editor/runtime placement or gameplay physics.

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 7B visual shader/debug wiring | `.codex-research/phase7b_wake_eddy_visual_probe.gd` | Godot 4.6.3 scripted probe | `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK` | Pass historically | 2026-05-26 | Agent |
| Phase 7B review captures | `.codex-research/export_demo_phase7b_wake_eddy_views.gd` | Godot 4.6.3 scripted export | `PHASE7B_WAKE_EDDY_EXPORT_OK` | Pass historically | 2026-05-26 | Agent |
| Raw B/G/A and retention diagnostic | `.codex-research/phase7b_eddy_line_cpu_diagnostic.gd` | Godot 4.6.3 scripted readback | `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK` | Pass historically | 2026-05-26 | Agent |
| Accepted visual placement | User viewport review in `Demo.tscn` | Human visible editor/runtime | User accepts paired trailing wake-edge margins and visible response | Pass; "It looks good" | 2026-05-26 | User |
| Current baseline source | Static/shader review plus viewport review | Docs/static/human visible | `Eddy-Line Visual Mask` uses raw-G wake-edge candidate at `wake_edge_sample_tiles = 0.024` | Pass historically | 2026-05-26 | Agent/User |
| Old raw-B diagnostics preserved | Debug View menu and shader review | Static/editor visible | B-based diagnostic views remain available | Pass historically | 2026-05-26 | Agent |
| Raw/final/visible review loop | Human-assisted validation request | Human visible | Raw source first, final mask second, visible water last | Required for future issues | 2026-05-31 | User/Agent |
| Phase 7B visual-only boundary | Scope/resource review | Static/resource review | No source-flow, final-flow, WaterSystem shader, or saved WaterSystem bake change | Pass historically | 2026-05-26 | Agent |
| Main and obstacle-test generalization | `Demo.tscn` and `Demo_obstacle_flow_test.tscn` review | Human visible | Same accepted pattern without ordinary-bank strips | Partial historical evidence; recheck after changes | 2026-05-31 | User/Agent |
| Phase 7C/7D parity | Future flow probe/runtime review | Visible/debug/system-flow/runtime | Visible flow, debug flow, WaterSystem map, and runtime object behavior agree | Deferred/unrun | 2026-05-31 | Agent/User |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
  - Green debug gradient can mean low/near-zero mask value.
  - Wake centers can remain quieter than wake-edge margins.
  - Phase 7B surface turbulence can imply motion that is not yet physics-facing.
  - Start-of-river hotspots can be boundary/source artifacts.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
  - Saved debug material override on generated river mesh.
  - Material overrides that differ from current shader defaults.
  - Stale pre-Phase-7B resources or wrong river bake signature.
  - Viewing direction confusion when interpreting upstream/downstream.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index for river behavior, hydrology, flow maps, shader water, and production examples. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation:
  - Raw G and `Eddy-Line Visual Mask` are placed correctly, but visible water looks too subtle or too strong.
  - The requested "eddy" behavior is actually reverse-flow physics, not visual eddy-line turbulence.
  - The only visible improvement is at the start-of-river hotspot while rock shoulder targets remain quiet.
- What the agent should say to the user if that evidence appears:
  - "The accepted eddy-line pass is visual-only. If we want actual reverse or circulating current, we need to scope Phase 7C so visible flow, debug flow, WaterSystem generation, and runtime validation move together."
- Quick falsifying check before patching:
  - Compare `Raw Wake-Edge Candidate (from G)`, B-based diagnostics, `Eddy-Line Visual Mask`, and visible water at the same target rocks.

## Automated Checks

- Command or procedure:
  - Run the relevant `.codex-research` Godot probe for the changed layer.
- Expected result:
  - Probe-specific `_OK` marker.
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
& $godotConsole --path $root --script "res://path/to/probe.gd"
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Human-Assisted Validation

Use this by default for visible Godot editor checks, viewport interaction, scene running, shader visuals, bake output, and runtime behavior. The agent must paste these steps into future chat messages when requesting validation; do not ask the user to open this file just to discover the check.

- Request to user:
  - Please open the demo in Godot and review the accepted wake/eddy-line targets in the listed debug views before we change code or accept a future eddy change.
- Exact scene, command, or workflow to run:
  - Open `res://Demo.tscn`.
  - Enable the Waterways plugin if it is not already enabled.
  - Select the main river.
  - Set Debug View to the listed modes one at a time around the same rocks/protrusions:
    - `Wake / Eddy Seed Mask`
    - `Raw Wake-Edge Candidate (from G)`
    - `Experimental Wake-Edge Eddy Source`
    - `Wake Visual Mask`
    - `Wake Edge Thinness`
    - `Eddy-Line Visual Mask`
    - `Eddy-Line / Shear Mask`
    - `Gated Eddy-Line Source (B * Wake Gate)`
    - `Eddy-Line Raw Low Range (B x4)`
    - `Obstacle Confidence`
    - `Hard-Boundary / Protrusion Response`
    - `Final Flow Strength`
  - Return Debug View to `Normal` and review visible water with the current `wake_` material defaults.
  - Repeat at least one target in `res://Demo_obstacle_flow_test.tscn` if the change affects raw source, final mask, or ordinary-bank suppression.
- Plugin state required:
  - Waterways plugin enabled.
- Console output or errors to relay back:
  - Any Output panel errors, shader compile errors, script errors, stale bake warnings, or material override warnings.
- Screenshot or visible behavior to relay back:
  - For each target, say whether the issue appears in raw G, old raw-B diagnostics, final `Eddy-Line Visual Mask`, or only visible water.
  - Say whether the mask forms paired trailing wake margins, a filled wake blob, an upstream pillow-face outline, a continuous ordinary-bank strip, or only the start-of-river hotspot.
  - Include screenshots if possible with upstream/downstream direction noted.
- Godot version and renderer to relay back:
  - Godot version, renderer backend, and device/GPU if available.
- Expected result:
  - Accepted eddy-line signal appears mostly on downstream rock shoulders and paired trailing wake margins.
  - Wake centers are quieter than the margins.
  - Ordinary smooth banks remain mostly quiet.
  - Visible water shows a restrained surface cue without implying physics-facing reverse flow.
- Failure signs:
  - Final mask becomes green/empty in accepted rock-garden targets.
  - Only the start-of-river hotspot strengthens.
  - Smooth ordinary banks become continuous eddy-line strips.
  - The visible material implies reverse/circulating current while WaterSystem flow is unchanged.
  - Debug and visible material disagree on placement.
- Result recording format:
  - Date:
  - Ran by:
  - Godot version/renderer/device:
  - Scene:
  - Debug views checked:
  - Target rocks/protrusions:
  - Output or parser errors:
  - Visible result:
  - Pass/partial/fail:

## Recorded Results

Recorded result:

- Date: 2026-06-04
- Ran by: Agent documentation review
- Godot version/renderer/device: Not run
- Command, scene, or workflow: Read current eddy feature docs and newer feature-folder templates, then aligned the eddy docs with the updated template organization.
- Output or parser errors: None
- Visible result, if applicable: Not applicable
- Stable result marker: Docs style refresh complete
- Pass/partial/fail: Pass for docs style refresh; no new runtime validation
- Notes or follow-up: Human-assisted Godot review is still needed for future visual or flow changes.

Recorded result:

- Date: 2026-05-31
- Ran by: Agent documentation review
- Godot version/renderer/device: Not run
- Command, scene, or workflow: Converted latest changelog, handoff, and roadmaps into feature validation plan.
- Output or parser errors: None
- Visible result, if applicable: Not applicable
- Stable result marker: Feature docs created
- Pass/partial/fail: Pass for docs migration; no new runtime validation
- Notes or follow-up: Human-assisted review is needed for future visual or flow changes.

## Historical Results Archive

- Phase 7A1 preflight exported review-only masks and captures; no visible/runtime behavior changed.
- Phase 7A2 classifier refinement passed `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, `PHASE7A2_WAKE_EDDY_EXPORT_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, and `DEMO_SYSTEM_MAP_VALID=true`.
- Phase 7B visual probe passed with `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`.
- Phase 7B export passed with `PHASE7B_WAKE_EDDY_EXPORT_OK`.
- Phase 7B CPU/readback diagnostic passed with `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`.
- User viewport review rejected the edge-sample-only fix.
- User viewport review accepted the raw-G wake-edge source and visible material pass after override fix and stronger defaults.

## Shader Checks

- Shader/material path:
  - `addons/waterways/shaders/river.gdshader`
  - `addons/waterways/shaders/river_debug.gdshader`
- Renderer backend:
  - Record from Godot editor during human-assisted validation.
- Expected result:
  - Visible and debug shader paths agree on wake/eddy-line mask placement.
  - `wake_edge_sample_tiles` default remains `0.024` unless intentionally reviewed.
  - Debug View Normal restores visible material behavior.
- Failure signs:
  - Debug view differs from visible material in unexplained ways.
  - Material edits do not affect visible water after returning to Debug View Normal.
  - `Eddy-Line Visual Mask` falls back to old raw-B exact-gate behavior unexpectedly.

## Editor Workflow Check

Procedure:

1. Open `res://Demo.tscn`.
2. Select the main river.
3. Confirm the Debug View menu exposes Wake / Eddy views and related diagnostic modes.
4. Confirm `wake_` controls are editable and visible water updates in Debug View Normal.
5. Switch between raw source, final mask, and visible water without stale material override behavior.

Expected result:

- The user can compare raw G, old raw B diagnostics, final masks, and visible response around the same targets.

Failure signs:

- Debug shader remains applied when Debug View is Normal.
- Controls appear to do nothing because material state is stale.
- Debug modes are missing, mislabeled, or not wired to shader branches.

## Visual Test Scene

Scene path:

- `res://Demo.tscn`
- `res://Demo_obstacle_flow_test.tscn`

Purpose:

- Prove the accepted eddy-line baseline on the main demo river and a second obstacle-test layout.

Expected visual result:

- Paired trailing margins appear downstream of hard rocks/protrusions.
- Wake centers remain quieter than the thin margins.
- Smooth ordinary banks do not become continuous highlighted outlines.
- Visible response is restrained and surface-only.

Failure signs:

- Filled wake blobs are mistaken for eddy lines.
- Upstream pillow-face outlines are mistaken for wake-edge thinness.
- Start-of-river hotspot drives tuning.
- Ordinary banks become long eddy-line strips.
- Visible water suggests reverse flow while WaterSystem remains downstream.

Suggested controls or debug views:

- `Wake / Eddy Seed Mask`
- `Raw Wake-Edge Candidate (from G)`
- `Experimental Wake-Edge Eddy Source`
- `Wake Visual Mask`
- `Wake Edge Thinness`
- `Eddy-Line Visual Mask`
- `Eddy-Line / Shear Mask`
- `Gated Eddy-Line Source (B * Wake Gate)`
- `Eddy-Line Raw Low Range (B x4)`
- `Obstacle Confidence`
- `Hard-Boundary / Protrusion Response`
- `Final Flow Strength`

## Bake Output Check

Scenario:

- Phase 7B visual-only preservation or tuning.

Expected generated outputs:

- Flow: unchanged.
- Foam: no new bake data.
- Distance/pressure: unchanged.
- Obstacle features: unchanged unless classifier work is explicitly scoped.
- Metadata: unchanged for shader-only visual work.
- WaterSystem: unchanged.

Failure signs:

- River bake source signature changes for visual-only work.
- Saved river bakes are regenerated without a raw classifier/data change.
- Saved WaterSystem bake is regenerated without final/physics flow scope.

## Runtime API Check

Procedure:

- Phase 7B: not required because work is visual-only.
- Phase 7C/7D: run a runtime scene or validated flow sampling check after visible/debug/system-flow changes and WaterSystem regeneration.

Expected result:

- Phase 7B: buoyancy/runtime flow remains accepted Phase 5B behavior.
- Phase 7C/7D: buoyant objects and runtime flow samples match visible eddy circulation.

Failure signs:

- Objects drift only downstream while visible shader implies reverse circulation after a supposed Phase 7C change.
- Runtime flow samples differ from debug final-flow views.

## Performance Check

Scenario:

- Visual-only Phase 7B preservation.

Budget or target:

- No runtime readback.
- No WaterSystem regeneration.
- No broad increase in shader sampling unless explicitly reviewed.

How to measure:

- Static scope review for visual-only work.
- Future Phase 7C must add a concrete frame-time/bake-time/resource check.

## Artifact Hygiene Check

- Scratch project or temporary folder used:
  - None for this docs migration.
- Active scripts/resources mirrored into scratch before validation:
  - Not applicable.
- Generated bakes/resources created:
  - None.
- Files or folders that must be excluded from packaging:
  - `.codex-research/`
  - Generated review captures unless intentionally committed.
- Files or folders safe to delete now:
  - None identified.

## Extension Check

Custom content scenario:

- A different river layout with isolated rocks, hard wall protrusions, and smooth ordinary banks.

Expected result:

- Raw/final/visible review still distinguishes wake body, eddy-line margins, ordinary banks, and upstream pillow faces.

Failure signs:

- The accepted behavior only works in one `Demo.tscn` camera or one rock arrangement.

## Manual Review Checklist

- [ ] Phase 7B accepted baseline is preserved.
- [ ] Raw source, final mask, and visible material response were reviewed in that order for any new visual issue.
- [ ] Human-assisted Godot/editor/test results are recorded when the agent could not run them directly.
- [ ] Human-assisted validation steps were pasted into chat for visible/editor/runtime checks.
- [ ] Active code uses Godot 4.6+ APIs and avoids obsolete Godot 3 APIs.
- [ ] Editor-only and runtime-safe boundaries are preserved.
- [ ] Generated resources and metadata are explicit and inspectable.
- [ ] Visual output matches the spec.
- [ ] Flow direction, masks, ordinary-bank suppression, and start-of-river hotspot behavior are checked visually.
- [ ] Runtime sampling/API behavior is checked if Phase 7C/7D changes final flow.
- [ ] Performance-sensitive paths have been checked for future flow work.
- [ ] Known limitations are documented.
- [ ] Shared research citations were checked or updated when external river/water references affected the decision.
