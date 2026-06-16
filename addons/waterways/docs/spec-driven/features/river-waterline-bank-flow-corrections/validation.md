# Validation: River Waterline and Bank Flow Corrections

## What Must Be Proven

- Obstacle gaps are correctly classified as real defects, scene/collider setup, stale bakes, shader clipping, debug artifacts, or unknown.
- Current code, material bindings, metadata, and generated bakes either match the older documented obstacle-flow fix or any drift is identified.
- If real, obstacle gaps are fixed without allowing water inside true solids.
- Bank inward patches are correctly classified as baked-flow defects, runtime shader defects, debug artifacts, legitimate behavior, stale bakes, seam/tile issues, or unknown.
- If real, bank inward patches are fixed without damaging existing obstacle non-penetration, seams, or runtime flow sampling.

## Current Validation Snapshot

- Overall status: Waterline overhang gap classified, patched, rebaked by the user, and visually resolved; bank-inward-flow issue remains unclassified.
- Last automated pass: 2026-06-15 focused `waterline_occupancy_probe.gd` pass plus safe existing probe pass.
- Last human-assisted pass: 2026-06-16 user rebaked the affected river after the patch and reported the red-circled missing-water regions are resolved.
- Highest-risk unproven behavior: whether the separate bank-inward-flow report is real baked flow, runtime/debug display, stale data, or expected local behavior.
- Known unreliable local check or environment caveat: headless checks cannot prove visible river rendering, shader visuals, viewport debug views, or user screenshot equivalence. `river_source_image_hash_probe.gd` timed out after 120s on 2026-06-15 and needs follow-up before relying on it.

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| Prior obstacle-flow fix still present | Code/resource comparison against `../river-obstacle-flow-constraints/` | Static + safe probes | Missing/drifted mechanisms listed before new design | Partial pass: current code has `water_occupancy`, `flow_projected`, protrusion confidence gating, projected-flow slide gates, and FLOW_ARROWS low-speed/sub-cell fallback; saved Demo bakes report projected occupancy data | 2026-06-15 | Agent |
| Probe compatibility after refactors | Existing non-mutating probes | Headless + windowed | Markers still reachable; broken/stale probes identified | Partial pass | 2026-06-15 | Agent |
| Screenshot evidence mapped | Evidence inventory from user screenshots | Human-assisted | Each screenshot has scene, view mode, symptom, bake freshness, and location | Pass for waterline issue: three red-circled normal-view screenshots showed missing water under overhangs in Demo near `Cliffs/cliff2`; user later rebaked and confirmed resolution | 2026-06-16 | User/Agent |
| Obstacle gap classified | Existing diagnostics or `waterline_occupancy_probe.gd` | Console/windowed as needed | Gap labeled by owning layer | Classified: collision occupancy false positive from top-down/down-ray hits over open waterline | 2026-06-15 | Agent |
| False-positive occupancy does not include open waterline | `waterline_occupancy_probe.gd` | Console/windowed as needed | Suspect solid texels reported with provenance and local images | Pass: probe after patch showed `current_upper_open 259 -> 0`; user rebake then resolved visible water gaps | 2026-06-16 | Agent/User |
| True solids remain clipped | Existing obstacle projection/occupancy checks | Windowed if rebaking/readback | No water inside true solids; prior pass markers still valid | Unrun | 2026-06-15 | Agent/User |
| Bank inward flow classified | `bank_inward_flow_probe.gd` or equivalent | Console/windowed as needed | Isolated inward vectors listed with magnitude and location | Partial generic probe only: arrow outlier probes show low-speed display outliers on Demo bakes, but reported bank locations are unknown | 2026-06-15 | Agent |
| Debug-view artifact ruled in/out | Compare saved flow data to `river_debug.gdshader` output | Human visible plus probe | Low-magnitude or solid-center display issues identified | Unrun | 2026-06-15 | Agent/User |
| Final visual result | Same camera screenshots before/after | Human-assisted Godot editor/runtime | Gaps/patches corrected or documented as expected behavior | Pass for missing-water issue after user rebake; bank-flow final visual not applicable until classified/fixed | 2026-06-16 | User |
| Regression coverage | Relevant existing obstacle/seam/system-flow probes | Console/windowed as needed | Existing pass markers remain passing | Pass on safe probes: occupancy inspect, arrow outlier, seam, and system-flow compare with `allow_stale=1`; saved resources are stale after signature v30 | 2026-06-15 | Agent |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
  - Water is removed inside an actual collision footprint even if the visible mesh looks narrower at the waterline.
  - A debug arrow points inward where flow magnitude is nearly zero, making direction visually overconfident.
  - Bank-adjacent flow turns inward because the local spline/bank geometry genuinely bends that way.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
  - Old river bakes or WaterSystem maps.
  - Current code missing behavior documented in the older obstacle-flow feature.
  - Different scene/debug view than expected.
  - Object collision shape wider than visible mesh.
  - Generated bakes already modified in the worktree.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index for river behavior, hydrology, flow maps, shader water, and production examples. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation:
  - Occupancy and collision agree that the waterline is solid at the reported gap.
  - Baked flow magnitude is below the low-flow threshold at the reported inward arrow.
  - A fresh rebake no longer shows the symptom.
- What the agent should say to the user if that evidence appears:
  - State that the screenshot is real, but the root cause is scene/collider data, stale bake, or visualization rather than the suspected algorithm; show the smallest supporting evidence.
- Quick falsifying check before patching:
  - Fresh rebake plus occupancy/FLOW_ARROWS/normal-view captures at one representative obstacle gap and one representative bank spot.

## Automated Checks

- Command or procedure:
  - First compare current code/resources to `river-obstacle-flow-constraints` documented mechanisms.
  - Use existing probes from related feature folders first.
  - Add feature-local probes only when existing diagnostics cannot classify the screenshot.
- Expected result:
  - Stable report markers and saved local artifacts that point to the owning layer.
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

Use the console executable for scripted probes and diagnostics because it prints stable output markers. Redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so Codex does not alter the user's normal Godot editor profile.

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

Use this by default for visible Godot editor checks, viewport interaction, scene running, gizmos, shader visuals, bake output, and runtime behavior. The agent may not be able to open or interact with Godot reliably.

When requesting this validation, the agent must put the exact request in the chat message so the user does not have to open this file to discover what to run.

- Request to user:
  - Please post each screenshot with the scene name, normal/debug view mode, whether the river was freshly rebaked, and whether the screenshot is before or after any local changes.
- Exact scene, command, or workflow to run:
  - Open the reported scene, select the river, capture normal view and relevant debug views at the same camera location: occupancy/solid mask if available, FLOW_ARROWS or effective flow direction, flow strength, terrain contact/protrusion, and bank response.
- Plugin state required:
  - Waterways add-on enabled; reported scene open; current bakes loaded or freshly regenerated as stated.
- Console output or errors to relay back:
  - Any bake warnings, stale-resource warnings, parser errors, or shader errors.
- Screenshot or visible behavior to relay back:
  - Whether water is missing in normal view, whether occupancy marks the same region solid, and whether flow arrows are high magnitude or near-neutral.
- Godot version and renderer to relay back:
  - Godot version, renderer, and whether Forward+, Mobile, or Compatibility was used.
- Expected result:
  - Clear evidence of which layer owns each symptom.
- Failure signs:
  - Screenshot without scene/debug/bake context cannot be classified.
- Result recording format:
  - Date:
  - Ran by:
  - Godot version/renderer/device:
  - Scene and river:
  - Bake freshness:
  - View mode:
  - Output or parser errors:
  - Visible result:
  - Pass/partial/fail:

## Recorded Results

Record new runs here. Put the newest and most relevant result first, then move older detail under an archive marker when the section gets long.

Recorded result:

- Date: 2026-06-16
- Ran by: User
- Godot version/renderer/device: not recorded.
- Scene and river: Demo river at the red-circled overhang/wide-top obstacle locations near `Cliffs/cliff2`.
- Bake freshness: user rebaked the river after the waterline-contact collision occupancy patch.
- View mode: normal editor view screenshots/visual review.
- Output or parser errors: none reported.
- Visible result: reported missing-water regions under overhangs are resolved after rebake.
- Pass/partial/fail: Pass for the missing-water/waterline-overhang issue. Does not cover the separate bank-inward-flow issue.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 headless with repo-local `.codex-research/godot-user-waterline-probe`.
- Command, scene, or workflow: `waterline_occupancy_probe.gd` on `res://Demo.tscn`, region `Cliffs/cliff2`, before and after production patch to `generate_collisionmap()`.
- Result summary:
  - Before patch: `sampled=7803`, `saved_solid=1020`, `current_solid=318`, `waterline_hit=276`, `saved_upper_open=947`, `current_upper_open=259`, `current_down_top_upper_open=259`, `current_direct_upper_open=0`.
  - After patch: `sampled=7803`, `saved_solid=1020`, `current_solid=144`, `waterline_hit=276`, `saved_upper_open=947`, `current_upper_open=0`, `current_down_top_upper_open=0`, `current_direct_upper_open=0`.
  - Interpretation: current collision occupancy no longer classifies upper/top-down geometry as solid when the waterline is open. The saved bake still contains old solids and must be regenerated before visual validation.
- Stable result marker:
  - `WATERLINE_OCCUPANCY_PROBE_OK`
- Follow-up:
  - Rebuild the affected river bake only after explicit approval because `waterways_bakes/Demo/Water_River.river_bake.res` was already modified before this pass.
  - Capture the same three screenshot locations after rebake.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3; headless resource probes with repo-local `.codex-research/godot-user-next` APPDATA/LOCALAPPDATA.
- Command, scene, or workflow: static comparison against `river-obstacle-flow-constraints`, then safe probes on `res://waterways_bakes/Demo/Water_River.river_bake.res` and `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`.
- Output or parser errors:
  - Existing scene warnings during `system_flow_compare_probe.gd`: invalid bake-resource UIDs in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`; Godot fell back to text paths.
  - `system_flow_compare_probe.gd -- enforce=all -- allow_stale=1` reported both saved WaterSystem maps stale; thresholds are report-only while stale.
- Static current-code comparison:
  - Present: `water_occupancy` constants, `RiverBakeData.water_occupancy`, material binding to `i_water_occupancy`, bake handoff/storage, and channel metadata.
  - Present: `RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN = 0.75`; `create_solid_occupancy_source_image()` only lets high-confidence terrain-contact protrusion add solids.
  - Present: pressure projection path (`apply_flow_divergence`, Jacobi pressure, gradient subtract, boundary tangency) and fallback `normal_to_flow` path.
  - Present: `flow_projected` metadata and runtime slide gates in river, debug, and system-flow shader paths.
  - Present: FLOW_ARROWS near-neutral threshold, speed-scaled glyphs, and 4-point sub-cell fallback.
- Stable result marker:
  - `RIVER_OCCUPANCY_FLOW_INSPECT_DONE`
  - `ARROW_NEUTRAL_CELLS_PROBE_OK` on both demo bakes.
  - `ARROW_DIRECTION_OUTLIER_PROBE_OK` on both demo bakes.
  - `SYSTEM_FLOW_COMPARE_OK` with `allow_stale=1`.
  - `RIVER_FLOWMAP_SEAM_PROBE_OK`
  - `BAKE_INSPECT_OK` for `water_occupancy.r` on the main demo bake.
- Key results:
  - Main demo: `flow_projected=true`, solid coverage 14.12%, proximity coverage 36.64%, water occupancy R mean 0.1413.
  - Obstacle test: `flow_projected=true`, solid coverage 14.78%, proximity coverage 38.53%.
  - FLOW_ARROWS neutral counts: main `{ solid_collision: 61, solid_protrusion: 94, stilled_ring: 4, dead_flow: 515, flowing: 926 }`; obstacle `{ solid_collision: 56, solid_protrusion: 118, stilled_ring: 3, dead_flow: 451, flowing: 972 }`.
  - FLOW_ARROWS direction outliers: main `11` total, obstacle `7` total; reported magnitudes are low (`|flow|` roughly 0.05-0.14), consistent with the prior low-speed/debug-arrow caveat.
  - Seam probe: projected flow channels have logical edge depth-0 deltas of 0 on both demo bakes.
- Pass/partial/fail: Partial pass.
- Notes or follow-up:
  - This does not classify the user's two reported visual spots because no screenshot scene/view/location was supplied in this thread.
  - The safe evidence makes a complete loss of the older obstacle-flow fix unlikely on the current Demo saved bakes.
  - Do not treat stale WaterSystem comparisons as proof until the user approves regenerating/saving WaterSystem maps.

Recorded result:

- Date: 2026-06-15
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3; headless for resource probes; Forward+ / AMD Radeon RX 6800 XT for windowed readback/capture probes.
- Command, scene, or workflow: probe compatibility pass after refactors, using redirected `.codex-research` Godot user folders.
- Output or parser errors:
  - Existing scene warnings: invalid bake-resource UIDs in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`; Godot fell back to text paths.
  - `system_flow_compare_probe.gd -- enforce=all` exited nonzero because both saved WaterSystem maps are stale. With `allow_stale=1`, the probe reached `SYSTEM_FLOW_COMPARE_OK`; thresholds are report-only while stale.
  - `river_source_image_hash_probe.gd` timed out after 120s after loading `Demo.tscn`; a leftover Godot process was closed. Treat this probe as suspect until investigated.
- Visible result, if applicable:
  - `debug_view_capture_probe.gd` captured Flow Arrows and Final Flow Strength for `Demo_obstacle_flow_test.tscn`.
  - Older `river_debug_view_capture_probe.gd` captured Flow Arrows for `Demo_obstacle_flow_test.tscn`.
- Stable result marker:
  - `RIVER_OCCUPANCY_FLOW_INSPECT_DONE`
  - `ARROW_NEUTRAL_CELLS_PROBE_OK` on both demo bakes.
  - `ARROW_DIRECTION_OUTLIER_PROBE_OK` on both demo bakes.
  - `SYSTEM_FLOW_COMPARE_OK` with `allow_stale=1`.
  - `RIVER_FLOWMAP_SEAM_PROBE_OK`
  - `BAKE_INSPECT_OK` for `water_occupancy.r` on both demo bakes.
  - `SYSTEM_FLOW_PROJECTED_GATE_OK`
  - `DEBUG_VIEW_CAPTURE_OK`
  - `R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK`
  - `RIVER_DEBUG_VIEW_CAPTURE_DONE`
- Pass/partial/fail: Partial pass.
- Notes or follow-up:
  - Do not regenerate WaterSystem maps until the user approves generated-resource changes.
  - Investigate `river_source_image_hash_probe.gd` separately; it may be slow or may have drifted after refactors.
  - Read-only diagnostics confirm saved river bakes have `flow_projected=true` and `water_occupancy` coverage near the prior expected range: main demo solid coverage 14.12%, obstacle test 14.78%.

## Historical Results Archive

Move older validation narratives here once the current snapshot and matrix carry the important status.

## Shader Checks

- Shader/material path:
  - `addons/waterways/shaders/river.gdshader`
  - `addons/waterways/shaders/river_debug.gdshader`
- Renderer backend:
  - Forward+ first; others if shader changes are made.
- Expected result:
  - Rendered water and debug views match saved bake intent.
- Failure signs:
  - Shader clips open water, shows confident directions for near-zero flow, or diverges from saved data without a documented reason.

## Editor Workflow Check

Procedure:

1. Open the reported scene.
2. Capture normal and debug views at the reported locations.
3. If safe and approved, fresh-rebake and capture the same views again.

Expected result:

- The symptom is either reproduced and classified, or the stale/context cause is recorded.

Failure signs:

- Rebake changes generated resources without being recorded.
- Debug views are unavailable or ambiguous for the reported issue.

## Visual Test Scene

Scene path:

- To be identified from screenshots.

Purpose:

- Prove obstacle waterline gaps and bank inward patches in a reproducible context.

Expected visual result:

- Water remains visible at open waterline areas near wide-top obstacles.
- Bank-adjacent flow follows downstream direction unless intentionally modified.

Failure signs:

- Missing water under open upper geometry.
- Isolated high-magnitude arrows pointing inward along banks.
- True obstacle interiors showing water.

Suggested controls or debug views:

- Normal view, occupancy/solid, FLOW_ARROWS/effective flow, flow strength, terrain contact/protrusion, bank response.

## Bake Output Check

Scenario:

- Reported obstacle and bank locations after fresh rebake.

Expected generated outputs:

- Flow: downstream-consistent in open water; no high-magnitude isolated inward bank patches.
- Foam: not central to this feature unless tied to the same classification bug.
- Distance/pressure: obstacle/bank proximity should match actual waterline role.
- Height/alpha: unchanged unless the defect is in terrain-contact classification.
- Metadata: signature/version records any changed generation behavior.

Failure signs:

- Occupancy marks open waterline under upper-only geometry as solid.
- Flow direction points inward at isolated open-water bank texels with meaningful magnitude.
- Old bakes load without warning when new semantics require rebake.

## Runtime API Check

Procedure:

- If bank-flow issue affects runtime objects, sample or inspect WaterSystem/runtime flow at the reported locations.

Expected result:

- Runtime-facing flow agrees with corrected river surface flow.

Failure signs:

- Surface and runtime flow diverge after correction.

## Performance Check

Scenario:

- Any production change that adds waterline sampling, extra raycasts, or shader reads.

Budget or target:

- To be defined before implementation.

How to measure:

- Time representative demo rebakes and compare before/after; record runtime shader cost only if shader sampling changes.

## Artifact Hygiene Check

- Scratch project or temporary folder used:
  - none yet.
- Active scripts/resources mirrored into scratch before validation:
  - none yet.
- Generated bakes/resources created:
  - none yet.
- Files or folders that must be excluded from packaging:
  - probe output folders and local screenshot scratch unless explicitly kept.
- Files or folders safe to delete now:
  - none yet.

## Extension Check

Custom content scenario:

- Wide-top obstacle with a narrow lower waterline footprint; bank section with a tight bend or protrusion.

Expected result:

- The tool classifies waterline contact, not only upper geometry or a misleading top-down footprint.

Failure signs:

- Hard-coded demo-only behavior or inability to distinguish visible mesh from collision participation.

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
