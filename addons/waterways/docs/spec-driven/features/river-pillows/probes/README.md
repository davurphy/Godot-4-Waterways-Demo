# River Pillows Probes

These Godot scripts preserve the useful pillow diagnostics from earlier `.codex-research` work in a feature-local, repeatable form. They are intended for future add-on contributors who need to verify pillow placement, debug-view wiring, inspector controls, and visual review exports without digging through old scratch scripts.

Run from the repository root with Godot 4.6.3:

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user-river-pillows-probes'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-pillows/probes/pillow_diagnostic_parity_check.gd'
```

## Probe List

- `pillow_diagnostic_parity_check.gd`
  - Protects duplicated pillow bake constants and Black Zero debug-mode IDs.
  - Success marker: `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`
- `pillow_anchor_source_probe.gd`
  - Loads the main and obstacle-test river bakes, verifies signature `20`, checks direct-contact metadata, and reports direct terrain, bank-response, combined, and bank-only anchor statistics.
  - Success marker: `PILLOW_ANCHOR_SOURCE_PROBE_OK`
- `pillow_placement_diagnostic.gd`
  - Computes raw R, no-reach visual mask, current default visual mask, prior reach comparison, and pull-example metrics for both review bakes.
  - Success marker: `PILLOW_PLACEMENT_DIAGNOSTIC_OK`
- `pillow_inspector_wiring_probe.gd`
  - Verifies Pillow inspector groups, shader uniforms, scene baseline values, material/debug-material sync, and revert defaults.
  - Success marker: `PILLOW_INSPECTOR_WIRING_PROBE_OK`
- `pillow_visual_review_export.gd`
  - Exports current pillow debug views from the main and obstacle-test scenes into `.codex-research/river-pillows-visual-review/`.
  - Set `$env:PILLOW_VISUAL_EXPORT_QUICK = '1'` before running for a one-camera smoke test.
  - Success marker: `PILLOW_VISUAL_REVIEW_EXPORT_OK`

Generated captures and user-data folders should stay under `.codex-research`. Do not commit exported PNGs unless a future review explicitly needs them as fixed reference artifacts.
