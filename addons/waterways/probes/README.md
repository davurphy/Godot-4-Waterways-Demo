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

### `bake_hash_probe.gd` — bake content hash / diff (headless OK)

River-refactor RT.1. Hash mode emits a per-texture content hash for a
`RiverBakeData` (or system bake); diff mode (`a=`/`b=`) compares two bakes and
exits nonzero on mismatch with a per-channel delta summary and the bounding
rect of differing pixels. Consumers: R1 ("metadata-only"), R5/R6 ("byte-identical").
Markers: `BAKE_HASH_PROBE_OK` / `BAKE_HASH_COMPARE_OK` (mismatch: `BAKE_HASH_MISMATCH`).

### `distmap_neutral_binding_probe.gd` — null-distmap neutral binding (headless OK)

River-refactor R0.7. A fresh RiverManager binds the neutral `dist_pressure`
texel ≈ (0.75, 0.25, 0.0, 0.5) to `i_distmap` on both materials when
`dist_pressure` is null. Marker: `DISTMAP_NEUTRAL_BINDING_OK`.

### `flow_solve_seed_assert_probe.gd` — cross-language seed invariant (headless OK)

River-refactor RT.4. Asserts the neutral pressure seed `RIVER_FLOW_PRESSURE_SEED_COLOR`
(`river_manager.gd`) equals enc(0) in all three `flow_solve_common.gdshaderinc`
encodings. Marker: `FLOW_SOLVE_SEED_ASSERT_OK`.

### `system_flow_compare_probe.gd` — system-vs-river flow gate (headless OK)

River-refactor RT.3. Decodes the river's baked flow per texel, transforms to
world XZ via the same per-triangle UV1 basis `system_flow.gdshader` builds, and
compares against the duck-read system-map sample across control/influence/boundary
zones. Default = report mode (control gate); `enforce=all` is R2's gross-divergence
guard (35°). Detects stale system maps. Key args: `scene= stride= min_flow=
max_control_deg=15 max_influence_deg=35 sharp_deg=20 allow_stale=1`.
Markers: `SYSTEM_FLOW_COMPARE_OK` / `SYSTEM_FLOW_COMPARE_EXCEEDED` / `SYSTEM_FLOW_COMPARE_STALE`.

### `system_flow_projected_gate_probe.gd` — slide-gate mechanism gate (window required)

River-refactor R2. A/B system-flow renders (slide gated vs forced) prove the
`i_flow_projected` slide gate is active: gated and forced renders differ where
content exercises the slide, and repeat renders are identical. The mechanism
gate for the Defect-1 fix (the angular RT.3 threshold cannot see a correct
low-magnitude fix on saved maps). Marker: `SYSTEM_FLOW_PROJECTED_GATE_OK`.

### `r4_runtime_robustness_probe.gd` â€” R4 runtime guard probe (headless OK)

River-refactor R4. Exercises the non-visual runtime fixes: ripple stepping is
clamped to one simulation step per `_process`, high-frequency impulses do not
starve propagation, late group-routed targets refresh, `cleanup_runtime()`
preserves API-registered targets, off-tree field group changes remove stale
membership, one-shot emitters stop after the route retry cap, width generation
stays within the legacy 1/100-segment tolerance, buoyancy binds by WaterSystem
coverage, and settled bodies are not forcibly woken. Marker:
`R4_RUNTIME_ROBUSTNESS_PROBE_OK`.

### `r4_ripple_visible_auto_review.gd` - R4 ripple visible review (window required)

River-refactor R4. Opens the ripple field/emitter review scene and cycles the
normal view plus the raw-height, impulse/contact, and visible-influence debug
views without requiring keyboard input in a captured mouse window. Use this for
the human-visible ripple part of the R4 gate. Expected result: localized impulse
marks and influence rings appear around the emitter markers, the field disable
step returns the river to baseline, and the re-enable step restores the effect.
Marker: `R4_VISIBLE_AUTO_REVIEW_DONE`.

### `r4_buoyancy_visible_review.tscn` - R4 buoyancy visible review (window required)

River-refactor R4. Self-contained human-visible scene for the two-WaterSystem
coverage and settled-body sleep checks. It builds one nearby red WaterSystem
whose coverage does not contain the bodies and one farther green WaterSystem
whose coverage does contain them. The overlay reports that the buoyant body binds
to the green coverage system even though the red origin is closer, then watches a
settled sleeping body for wake/twitch regressions. Press `R` to restart the sleep
watch.

### `r5_behavior_preservation_probe.gd` - R5 structural-dedup guard (headless OK)

River-refactor R5. Checks that the filter pass descriptor table covers all 19
pass shaders and default/HDR policies, that Baking inspector rows still appear
in descriptor order, that `widths` and `flow_speeds` round-trip through curve
state restore and pad short arrays, and that `RiverBakeData.finalize()` deep
copies metadata/settings/signatures while restoring default channel/import
metadata. Marker: `R5_BEHAVIOR_PRESERVATION_PROBE_OK`. Expected warning: the
width-padding assertion intentionally triggers the existing "too few entries"
sanitizer warning.
