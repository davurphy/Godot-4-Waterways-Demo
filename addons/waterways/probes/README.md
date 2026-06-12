# Shared Probes

General-purpose, reusable validation and diagnostic scripts. Feature-specific
probes (with feature-specific gates) stay in their feature folders under
`docs/spec-driven/features/*/probes/`; anything here is cross-feature
infrastructure.

## Run pattern

```powershell
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
& $godotConsole --path $root --script res://addons/waterways/probes/<probe>.gd -- key=value key=value
```

- User args go after a `--` separator, as `key=value` (quote the whole arg if the value has spaces).
- **Bakes and screenshots need a rendered window** — do not pass `--headless` to those probes.
- Pure resource reads are headless-safe — add `--headless`.
- Outputs land in `out/` (gitignored).

## Probes

### `rebake_probe.gd` — regenerate bakes (window required)

The standard tool after a bake source signature bump. Bakes each scene's
river, saves the bake resource, regenerates + saves the WaterSystem map.
Feature probes layer gates on top (e.g. `river_obstacle_projection_rebake_probe`).

| Arg | Default | Meaning |
| --- | --- | --- |
| `scenes=` | `res://Demo.tscn,res://Demo_obstacle_flow_test.tscn` | comma-separated scene list |
| `river=` | `WaterSystem/Water River` | river node path in each scene |
| `save=` | `true` | save river bakes |
| `system=` | `WaterSystem` (first scene only) | WaterSystem node to regenerate; `none` skips |

Marker: `REBAKE_PROBE_OK`. Note: `generate_system_maps`' internal save is
editor-only and silently no-ops under `--script`; this probe saves explicitly
and prints `save_error`.

### `debug_view_capture_probe.gd` — visual review screenshots (window required)

Captures any debug view(s) either from a camera flown along the river curve
or from named review cameras in the scene. View list is read live from
`gui/debug_view_menu.gd`.

| Arg | Default | Meaning |
| --- | --- | --- |
| `views=` | `Flow Arrows` | id(s) or label substring(s), comma-separated; `list` prints all |
| `scene=` / `river=` | Demo.tscn / `WaterSystem/Water River` | |
| `cameras=` | (fly-along) | comma-separated Camera3D node paths in the scene |
| `stations=` / `height=` / `back=` | 8 / 7 / 6 | fly-along stops and camera offset |
| `label=` | | output subfolder (e.g. `before`, `after`) |
| `out=` | `res://addons/waterways/probes/out` | |

Marker: `DEBUG_VIEW_CAPTURE_OK`. Examples:

```powershell
-- views=list
-- views="Flow Arrows,Final Flow Strength" stations=4
-- views=58 scene=res://Demo_obstacle_flow_test.tscn label=after
-- views="foam mix" "cameras=Phase0B Review Cameras/Phase0B_RockGarden_Overhead"
```

### `bake_inspect_probe.gd` — channel stats + PNG (headless OK)

Decodes a channel of a saved bake (river or WaterSystem), prints distribution
stats and the channel's own metadata slug, dumps a grayscale PNG.

| Arg | Default | Meaning |
| --- | --- | --- |
| `bake=` | (required) | `.res` bake resource path |
| `texture=` | `flow_foam_noise` / `system_map` | texture property on the bake |
| `channel=` | `rg` for flow textures, else `r` | `r`,`g`,`b`,`a`, or `rg` (decoded flow vectors) |
| `png=` / `out=` | `true` / `out/` | |

Marker: `BAKE_INSPECT_OK`. Channel semantics reference:
`docs/spec-driven/features/river-future/Data Contract.md`.

### `river_flowmap_seam_probe.gd` — seam regression gate (headless OK)

UV2 atlas logical-edge continuity across all baked channels. Re-run whenever
flow bake content changes. `bakes=` overrides the default two demo bakes.
Marker: `RIVER_FLOWMAP_SEAM_PROBE_OK`. (Copy of the river-flowmap-seams probe.)

### `flow_arrow_neutral_cells_probe.gd` — dark arrow cells diagnosis (headless OK)

Classifies every neutral FLOW_ARROWS cell by root cause (solid collision /
solid protrusion / stilling ring / dead flow) and writes a color-coded
overlay PNG. `bake=` selects the river bake. (Copy of the
river-obstacle-flow-constraints probe; mirrors `river_debug.gdshader` constants —
keep in sync if the arrow logic changes.)

### `flow_arrow_direction_outlier_probe.gd` — wrong-direction arrows diagnosis (headless OK)

Flags FLOW_ARROWS cells whose displayed direction deviates strongly from
flowing neighbors and attributes each to bake data vs sub-cell fallback.
`bake=` selects the river bake. (Copy, same mirroring caveat as above.)
