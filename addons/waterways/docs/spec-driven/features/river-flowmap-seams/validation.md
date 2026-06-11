# Validation: River Flowmap Seam Handling

## What Must Be Proven

- Current visible seam status is known for both demo scenes after signature 23.
- Existing signature 23 probes still pass unless a deliberate source-signature change updates expectations.
- Any visible seam is classified by join index, atlas class, and lit/debug/raw/derived context.
- Depth-1 bilinear bleed, normal/tangent discontinuity, temporal reset, and runtime offset helpers are each implicated or cleared before structural work.
- Any implemented fix visibly improves the baseline artifact and does not regress existing probe markers.

## Current Validation Snapshot

- Overall status: Baseline visible pass recorded; implementation not started.
- Last automated pass: prior signature 23 reports in `changelog.md` and `audit/seam-handling-audit-2026-06-11.md` list `RIVER_FLOWMAP_SEAM_PROBE_OK`, `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`, and `RIVER_FLOWMAP_SEAM_REBAKE_OK`.
- Last visible pass: 2026-06-11 agent screenshot review from `probes/river_flowmap_visible_baseline_export.gd`, marker `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`.
- Highest-risk unproven behavior: no current visible seam was found to correlate against depth-1 bleed, normal/tangent lighting, material amplification, temporal reset, or offset helpers.
- Known unreliable local check or environment caveat: console probes are not proof of interactive editor behavior, but the 2026-06-11 visible pass captured lit water plus raw and derived unshaded debug views from both demo scenes.

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| Signature 23 exact edge-row continuity | `probes/river_flowmap_seam_probe.gd` | Godot console | `RIVER_FLOWMAP_SEAM_PROBE_OK` | Prior pass reported | 2026-06-11 | Agent |
| Signature 23 UV2 world-sample continuity | `probes/river_flowmap_world_sample_probe.gd` | Godot console | `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK` | Prior pass reported | 2026-06-11 | Agent |
| Demo rebake signature status | `probes/river_flowmap_seam_rebake_demo_bakes.gd` | Godot console | `RIVER_FLOWMAP_SEAM_REBAKE_OK` | Prior pass reported | 2026-06-11 | Agent |
| Current visible seam status | `Demo.tscn` and `Demo_obstacle_flow_test.tscn` | Godot console screenshot export, agent visible review | No straight tile bands, or classified seam records | Pass: no visible seam observed post-signature-23 in either scene; 0 seams to classify | 2026-06-11 | Agent |
| Lit vs. unshaded discriminator | Lit water and `river_debug.gdshader` debug views | Godot console screenshot export, agent visible review | Debug seam means data/sampling; lit-only seam means normals/tangents/material | Pass: lit water, raw baked channel views, and derived/material debug views showed no straight join-aligned bands | 2026-06-11 | Agent |
| Demo material override check | Inspector/material resource scan plus baseline exporter report | Editor or static resource scan | Zero-default pillow offsets recorded as live or inactive | Pass: `pillow_forward_reach_tiles` and `pillow_contact_pull_strength` are `0.0` in both scenes; `pillow_height_smoothing_tiles` is `0.1` | 2026-06-11 | Agent |
| Depth-1 bilinear bleed | New or updated probe | Godot console/static image data | Depth-1/2 deltas recorded and correlated with observed seam positions | Unrun | 2026-06-11 | Agent |
| Normal/tangent continuity | CPU dump or normals/matcap debug view | Godot console/editor | Bases continuous, or discontinuity scoped to lit-only seams | Unrun | 2026-06-11 | Agent/User |
| Temporal reset | Runtime visual check | Godot runtime, human visible | No uniform pulse with `flow_foam_noise.a` phase noise active | Unrun | 2026-06-11 | User/Agent |
| Runtime offset helpers | Individual uniform ablations | Godot runtime, human visible | Each helper group implicated, cleared, or inconclusive | Unrun | 2026-06-11 | User/Agent |
| Build C lateral clamp | Shader diagnostic or offset-routing probe | Godot console/runtime | Lateral offsets do not cross interior column X edges | Conditional | 2026-06-11 | Agent |
| Build A strip packing | Updated packing probes and visual review | Godot console/editor | Row-wrap joins removed, per-tile resolution documented | Conditional | 2026-06-11 | Agent/User |
| Build B logical sampler | Offset-routing diagnostic | Godot console/runtime | Same-column, row-wrap, first/last, and column X-edge behavior verified | Conditional | 2026-06-11 | Agent |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
  - Real terrain/contact changes can differ across nearby depth-1/2 rows.
  - Material/debug contrast can amplify small gradients into visible bands.
  - Lit-only bands can come from duplicated-vertex normal/tangent basis, not bake data.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
  - Current demo bakes must be signature 23.
  - Older visual reports must not be reused as current proof.
  - Material overrides must be checked before pillow-related conclusions.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index for river behavior, hydrology, flow maps, shader water, and production examples. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation:
  - No visible seam remains in both demo scenes.
  - Seam appears only in lit water and not debug views.
  - Depth-1 deltas do not correlate with visible seam positions.
- What the agent should say to the user if that evidence appears:
  - "The current evidence does not support the planned code fix yet; the visible premise changed or points to a different layer."
- Quick falsifying check before patching:
  - Current lit/debug capture in both demo scenes.

## Automated Checks

- Command or procedure:
  - Run existing console probes with repo-local Godot user data.
  - Add/run a depth-1 bilinear-bleed probe before choosing any depth-1 bake fix.
  - Run parser/static checks and `git diff --check` after edits.
- Expected result:
  - Existing probes produce their `*_OK` markers.
  - New depth-1 probe reports channel deltas and correlation information without mutating bakes unless explicitly intended.
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
& $godotConsole --path $root --script "res://addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_seam_probe.gd"
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
  - Open `Demo.tscn` and `Demo_obstacle_flow_test.tscn` in Godot 4.6.3. First report whether any visible seam remains at all post-signature-23, because the earlier user-observed seam list predates that fix. If seams remain, inspect lit water and available river debug views, then report where they appear, whether they are visible in lit water, unshaded debug, raw baked channels, or derived/material views, and whether the bands align with step joins or column-edge bands.
- Exact scene, command, or workflow to run:
  - Launch the editor with the windowed command above.
  - Open `res://Demo.tscn`, inspect the river in lit water and debug views, then repeat for `res://Demo_obstacle_flow_test.tscn`.
- Plugin state required:
  - Waterways add-on enabled, current signature 23 bakes loaded.
- Console output or errors to relay back:
  - Any shader compile errors, missing resource warnings, bake warnings, or editor output related to Waterways.
- Screenshot or visible behavior to relay back:
  - Screenshots of any visible seam, plus which view/mode was active.
- Godot version and renderer to relay back:
  - Godot version, renderer backend, GPU/device if shown.
- Expected result:
  - A first-class yes/no answer for whether any visible seam remains post-signature-23, followed by enough information to classify each remaining seam if the answer is yes.
- Failure signs:
  - Straight tile bands in foam, normals, wakes, pillows, height displacement, raw data, or derived views; shader errors; stale/missing bakes.
- Result recording format:
  - Date:
  - Ran by:
  - Godot version/renderer/device:
  - Output or parser errors:
  - Visible result:
  - Pass/partial/fail:

## Recorded Results

Recorded result:

- Date: 2026-06-11
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable console, Forward+ Vulkan; AMD Radeon RX 6800 XT shown in console output.
- Command, scene, or workflow: `res://addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_visible_baseline_export.gd` captured screenshots for `res://Demo.tscn` and `res://Demo_obstacle_flow_test.tscn` using a repo-local `.codex-research` Godot user-data folder.
- Output or parser errors: marker `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`; no blocking parser or shader errors recorded.
- Evidence path: `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\.codex-research\river-flowmap-seams-visible-baseline\visible_baseline_report.json`
- Screenshot path: `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo\.codex-research\river-flowmap-seams-visible-baseline`
- Bake status: `Demo.tscn` uses signature 23, 17 occupied steps, `uv2_sides = 5`; `Demo_obstacle_flow_test.tscn` uses signature 23, 18 occupied steps, `uv2_sides = 5`.
- Visible result: no visible straight seam remains post-signature-23 in either scene in the reviewed lit-water captures, raw baked channel debug views, or derived/material debug views.
- Classification result: no seam records. Same-column joins, row-wrap joins, and column X-edge bands were available in the report/marker overlays, but no visible artifact aligned with them.
- Material override result: both scenes leave `pillow_forward_reach_tiles` and `pillow_contact_pull_strength` at `0.0`; `pillow_height_smoothing_tiles` is `0.1`; seam fades are `0.0` or unset/default.
- Stable result marker: `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK`
- Pass/partial/fail: Pass for the current visible baseline. Cheap checks remain deferred because there is no visible seam to correlate.
- Notes or follow-up: do not implement a seam fix from the stale pre-signature-23 visible list. Reopen cheap checks only if a seam is reproduced or the user explicitly wants the conditional diagnostics.

Recorded result:

- Date: 2026-06-11
- Ran by: Prior agent work, summarized from `changelog.md` and audit
- Godot version/renderer/device: not recorded here
- Command, scene, or workflow: signature 23 seam, world-sample, and rebake probes
- Output or parser errors: none recorded here
- Visible result, if applicable: not covered by probes
- Stable result marker: `RIVER_FLOWMAP_SEAM_PROBE_OK`, `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`, `RIVER_FLOWMAP_SEAM_REBAKE_OK`
- Pass/partial/fail: Partial
- Notes or follow-up: proves exact edge-row and world-sample continuity, not perceptual acceptance.

## Historical Results Archive

Older validation narratives live in `symptoms and initial suspects.md`, `changelog.md`, and `audit/seam-handling-audit-2026-06-11.md`.

## Shader Checks

- Shader/material path: `addons/waterways/shaders/river.gdshader`, `river_debug.gdshader`, demo river materials.
- Renderer backend: record during human-assisted validation.
- Expected result: runtime helper ablations either move/remove the implicated seam or are cleared.
- Failure signs: a helper changes an unrelated artifact, shader compile errors, or results cannot be interpreted because material overrides are unknown.

## Editor Workflow Check

Procedure:

1. Open the project in Godot 4.6.3.
2. Inspect demo river material overrides for zero-default pillow uniforms.
3. Capture lit/debug views in both demo scenes and record seam positions.

Expected result:

- Current visible state and material override state are known before code changes.

Failure signs:

- Stale bakes, missing debug views, unrecorded material overrides, or screenshots without scene/view context.

## Visual Test Scene

Scene path:

- `res://Demo.tscn`
- `res://Demo_obstacle_flow_test.tscn`

Purpose:

- Prove whether seams remain in the two known demo rivers and classify the artifact source.

Expected visual result:

- No straight tile bands, or classified bands with scene, view, channel, and join-index notes.

Failure signs:

- Straight tile bands in lit or debug views without classification.

Suggested controls or debug views:

- Lit water, unshaded river debug views, raw baked channel views, derived/material views, and uniform ablation groups.

## Bake Output Check

Scenario:

- Current signature 23 demo bakes.

Expected generated outputs:

- Flow: exact duplicated edge rows synchronized where signature 23 applies.
- Foam: no seam-positive exact edge discontinuity in fixed channels.
- Distance/pressure: exact duplicated edge rows synchronized where signature 23 applies.
- Height/alpha: verify through visual/debug review if implicated.
- Metadata: source signature remains current unless a structural packing/bake fix lands.

Failure signs:

- Existing probes lose `*_OK` markers, bakes are stale, or depth-1 bands correlate with visible seam positions and remain unexplained.

## Runtime API Check

Procedure:

- If Build C lands, add or run an offset-routing check that samples representative lateral offsets near interior column X edges.

Expected result:

- Lateral offset reads clamp within the current tile's X range; longitudinal offsets continue using valid margin behavior.

Failure signs:

- Lateral reads cross into non-logical neighbor columns, or longitudinal row-wrap behavior regresses.

## Performance Check

Scenario:

- Build C shader-local clamp, or conditional Build A/B.

Budget or target:

- Build C should add minimal arithmetic and no extra texture samples.
- Build A must document texture dimensions, memory, and per-tile texel density before adoption.
- Build B must justify per-fragment helper cost with visible evidence.

How to measure:

- Static shader review for Build C; memory/texture estimate for Build A; before/after runtime observation when available.

## Artifact Hygiene Check

- Scratch project or temporary folder used: `.codex-research/river-flowmap-seams-visible-baseline` for the 2026-06-11 screenshot/report export.
- Active scripts/resources mirrored into scratch before validation: not applicable yet.
- Generated bakes/resources created: none in this feature-folder pass.
- Files or folders that must be excluded from packaging: `.codex-research`, temporary screenshots/probe outputs, editor caches.
- Files or folders safe to delete now: `.codex-research/river-flowmap-seams-visible-baseline` if the local screenshot/report evidence is no longer needed.

## Extension Check

Custom content scenario:

- Existing user river materials and bakes should continue working if only Build C lands.

Expected result:

- No new required metadata or material setup for Build C.

Failure signs:

- Shader requires a new uniform or bake metadata for existing materials without a compatibility path.

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
