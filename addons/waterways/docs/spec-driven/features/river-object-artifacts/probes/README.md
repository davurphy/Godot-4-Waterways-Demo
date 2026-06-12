# River Object Artifacts Probes

Run from the repository root with Godot 4.6.3 (same harness as the other
feature probes):

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user-river-object-artifacts'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-object-artifacts/probes/object_artifact_baseline_probe.gd'
```

## Probe List

- `object_artifact_baseline_probe.gd`
  - Measures terrain-contact blockiness from the saved Demo bake
    (provenance histogram + neighbor flips, protrusion hard/partial/edge
    flips, contact edge sharpness), globally and near `Cliffs/cliff2`, and
    runs a live scan comparing the direct-shape collision path against the
    physics up/down-ray path (overhang-exemption divergence).
  - `$env:OBJECT_ARTIFACT_RES_AB = '1'` adds an in-memory rebake at
    `baking_resolution = 3` for the aliasing falsification A/B.
  - Success marker: `OBJECT_ARTIFACT_BASELINE_PROBE_OK`
- `object_artifact_collision_stats_probe.gd`
  - Prints `collision_hit_pixel_count` / total / percent from the saved
    Demo bake for before/after comparison of collision-map changes.
  - Success marker: `OBJECT_ARTIFACT_COLLISION_STATS_OK`
- `object_artifact_tile_bleed_probe.gd`
  - Bakes the Demo river with and without a synthetic obstacle at a tile
    edge and reports per-tile |delta| stats on the filtered outputs
    (foam, flow, distance, pressure, pillow, wake). Any delta in the
    atlas-horizontal neighbor tile (a world-distant river stretch) is
    cross-tile bleed. In-probe bakes do not persist to disk.
  - Success marker: `OBJECT_ARTIFACT_TILE_BLEED_PROBE_OK`
- `object_artifact_dash_hunt_probe.gd`
  - Captures close-up renders of the river surface along the curve
    (`OBJECT_ARTIFACT_DASH_MODE=bisect` additionally captures one image
    per shader-uniform suspect override at two fractions; `flow_speed=0`
    capture is frame-deterministic for diffing). Used to chase the dashed
    shape-tracing runtime artifact.
  - Success marker: `OBJECT_ARTIFACT_DASH_HUNT_OK`
- `object_artifact_flow_shear_probe.gd`
  - Measures lateral discontinuities in the baked flow field (decoded RG
    deltas between laterally adjacent texels inside occupied tiles). Used
    to refute the baked-shear hypothesis for the crack artifact (baked
    flow is smooth: max delta 0.102, zero pairs >= 0.5).
  - Success marker: `OBJECT_ARTIFACT_FLOW_SHEAR_PROBE_OK`
- `object_artifact_visual_export.gd`
  - Exports the artifact-relevant debug views (visible water, foam mix,
    final flow strength, wake seed, protrusion, provenance) from the Demo
    review cameras to
    `.codex-research/river-object-artifacts-visual-review/<label>/`.
  - `$env:OBJECT_ARTIFACT_EXPORT_LABEL` names the output subfolder; stash
    code+bake changes to capture a baseline set first.
  - Success marker: `OBJECT_ARTIFACT_VISUAL_EXPORT_OK`

Baseline, Phase 1, and Phase 2 numbers are recorded in `../validation.md`.
