# Obstacle-Flow-Constraints Probes

Feature-specific probes for the occupancy / pressure-projection work. They bake
or read the demo river/system bakes and apply this feature's gates.

Run pattern (NOT `--headless` for the rebake/capture probes — viewport readback
is required; the `*_inspect_probe` diagnostics are headless-safe). User args go
after `--` as `key=value`:

```powershell
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
& $godotConsole --path $root --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/<probe>.gd -- key=value
```

## Probes

- `river_obstacle_projection_rebake_probe.gd` — rebakes both demo scenes, runs the penetration gates, and **saves both river bakes in place on success**. ⚠️ Never run casually: a stray run overwrites the committed bakes (restore from HEAD if it happens). Window required.
- `river_occupancy_flow_inspect_probe.gd` — diagnostic (headless OK): solid coverage, protrusion attribution, proximity-binned `|flow|`, occupancy/flow PNG dumps to `out/`.
- `water_system_rebake_probe.gd` — regenerates a scene's WaterSystem map and saves explicitly (the internal save is editor-only and no-ops under `--script`; check the printed `save_error`/mtime). Window required.
- `water_system_flow_inspect_probe.gd` — diagnostic (headless OK): decodes the duck-read system-map flow, dead-zone fraction, magnitude PNG.
- `river_debug_view_capture_probe.gd` — debug-view screenshots for human review. Window required.

## Moved to shared probes/

The flow-arrow diagnostics were consolidated into the cross-feature shared set
(river-refactor R8.4) — the hardened versions there carry success markers,
`bake=`/`out=` args, null-checked loads, and the 4-point sub-cell fallback, and
read `OCCUPANCY_SPEED_RAMP_FULL` live from `river_surface_common.gdshaderinc`:

- `flow_arrow_neutral_cells_probe.gd` → `addons/waterways/probes/flow_arrow_neutral_cells_probe.gd`
- `flow_arrow_direction_outlier_probe.gd` → `addons/waterways/probes/flow_arrow_direction_outlier_probe.gd`

See `addons/waterways/probes/README.md` for the full shared-probe index.
