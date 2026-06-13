# Validation: River Refactor R6 - river_manager.gd Decomposition

## What Must Be Proven

- R6 changes no generated bake texture content.
- `source_signature` and `bake_settings` dumps are exact matches with no ignored keys.
- `source_metadata` dumps match exactly except the explicit dynamic allow-list.
- Full RiverManager public method/signal surface and inspector property list remain unchanged.
- Runtime ripple material ownership semantics remain unchanged.
- Editor validation wrappers and menu markers remain unchanged.
- Every old bake abort/early-return path becomes a controlled exit with cleanup and no partial overwrite.
- The baker has no broad RiverManager reach-back.

## Current Validation Snapshot

- Overall status: Unrun. R6 documents are being drafted before implementation.
- Last automated pass: none for R6.
- Last human-assisted pass: none for R6.
- Highest-risk unproven behavior: source timing during async bakes and abort cleanup during helper-internal awaits.
- Known unreliable local check or environment caveat: headless checks do not prove visible editor, shader, viewport, or menu behavior. Windowed/human-assisted validation is required for those.

## Canonical Dictionary Dump Format

This format must be implemented before any pre-R6 baseline capture.

- Dump files are UTF-8 text with LF line endings.
- Each dump starts with:
  - `R6_CANONICAL_DUMP v1`
  - `section=<source_metadata|source_signature|bake_settings>`
  - `target=<scene or bake resource identifier>`
  - `key_count=<count after allow-list filtering>`
- Keys are sorted lexicographically by their string form.
- Each entry is one line: `<key> = <canonical_value>`.
- Values are serialized with Godot's stable `var_to_str()`-style representation after recursively sorting nested dictionaries. Arrays keep their stored order.
- No ignored keys are allowed for `source_signature`.
- No ignored keys are allowed for `bake_settings`.
- `source_metadata` may ignore only keys explicitly listed in the dynamic allow-list below.
- Any additional ignored key is a review finding and must be recorded in `review.md` before implementation proceeds.

Dynamic metadata allow-list:

| Key | Reason | Status |
| --- | --- | --- |
| `bake_revision` | `_make_bake_revision()` is time-derived and changes on fresh rebakes. | Allowed |

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| R6 documentation gate exists before implementation | `spec.md`, `validation.md`, `tasks.md`, `research.md`, `review.md`, `session-handoff.md` in the R6 folder | Docs review | All required phase docs exist and point to `plan.md` | Drafted, not reviewed | 2026-06-13 | Agent |
| Canonical dictionary dumps are stable | New or extended metadata/signature/settings dump probe | Console/headless | Sorted dumps generated for both demo river bakes | Unrun | - | - |
| Source signature unchanged | Canonical dump diff before/after R6 | Console/headless | Empty diff, no ignored keys | Unrun | - | - |
| Bake settings unchanged | Canonical dump diff before/after R6 | Console/headless | Empty diff, no ignored keys | Unrun | - | - |
| Source metadata unchanged except dynamic allow-list | Canonical dump diff before/after R6 | Console/headless | Empty diff after ignoring only `bake_revision` | Unrun | - | - |
| Generated texture output unchanged | RT.1 scratch rebake hash compare for Demo and obstacle demo river bakes | Console/windowed as needed | All generated texture hashes identical | Unrun | - | - |
| Intermediate source images unchanged | New source-image hash probe for the full raw-plus-margin list | Console/headless or windowed as needed | All intermediate hashes identical before/after source-helper moves | Unrun | - | - |
| Public RiverManager API and signals unchanged | Public method/signal surface dump and diff | Console/headless | Empty diff; `river_changed` and `progress_notified` still present | Unrun | - | - |
| Full inspector property list unchanged | Serialized property-list dump and diff | Console/windowed as needed | Empty diff | Unrun | - | - |
| Source timing contract preserved or deliberately validated | Mid-bake edit probe or named human-assisted case | Console/windowed/human | Reports targeted stage and old/new value use, with `flow_speeds` minimum trap case | Unrun | - | - |
| Baker has no broad RiverManager reach-back | Static review plus implementation checklist | Code review | Only `BakeConfig`, local state, and named callbacks/dependencies are used | Unrun | - | - |
| Bake abort cleanup is complete | Abort-matrix probe plus named human-assisted cases | Console/windowed/human | No stuck flag, leaked renderer, orphan viewport, stale progress source, or partial overwrite | Unrun | - | - |
| Existing R5 behavior remains green | `r5_behavior_preservation_probe.gd` | Console/headless | `R5_BEHAVIOR_PRESERVATION_PROBE_OK` | Unrun for R6 | - | - |
| Existing runtime robustness remains green | `r4_runtime_robustness_probe.gd` | Console/headless | `R4_RUNTIME_ROBUSTNESS_PROBE_OK` | Unrun for R6 | - | - |
| Filter renderer load remains green | `filter_renderer_load_check.gd` or equivalent | Console/headless | `FILTER_RENDERER_LOAD_OK shader_paths=19` | Unrun for R6 | - | - |
| System-flow mechanism remains green | `system_flow_projected_gate_probe.gd` | Windowed console | `SYSTEM_FLOW_PROJECTED_GATE_OK` | Unrun for R6 | - | - |
| Runtime ripple material ownership unchanged | Existing ripple probes plus owner-conflict/tree-exit probe | Console/windowed as needed | Owner A/B conflict, clear, tree-exit, debug toggle behavior preserved | Unrun | - | - |
| Editor validation wrappers unchanged | Menu-wrapper marker check and direct RiverManager wrapper calls | Windowed/human-assisted as needed | Same `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` markers | Unrun | - | - |
| Parent docs reflect R6 result only after validation | Parent `validation.md`, `tasks.md`, `roadmap.md`, handoff docs | Docs review | R6 row added only after validation runs | Unrun | - | - |

## Source-Image Hash Gate

The source-image hash probe must cover both raw and margin-padded images where padding exists:

- collision source and collision-with-margins
- downstream baseline source and downstream baseline-with-margins
- blank support/features raw and margin-padded variants
- terrain contact source, smoothed terrain contact source, and terrain contact-with-margins
- solid occupancy source and solid occupancy-with-margins
- grade energy, bend bias, and flow speed raw and margin-padded variants
- tiled flow offset noise

This full raw-plus-margin list is the gate. Do not substitute the shorter summary list from older validation rows.

## Bake Success-Order Inventory

Before adding the baker shell, confirm the current success order and keep R6 result application equivalent:

- final combine outputs are validated
- renderer is cleaned up
- final textures are read back to `Image`
- CPU postprocess and diagnostics run
- generated `ImageTexture`s are created and assigned
- `RiverBakeData` fields are assigned and finalized
- external bake resource save is attempted
- `_apply_bake_data()` and shader parameters are refreshed
- `valid_flowmap` is set true
- `_flowmap_bake_in_progress` is cleared
- completion progress is emitted
- save/editor-memory notice is printed

## Known Abort Point Inventory

Count and name each old abort point before moving the pipeline. The known current list is:

- collision map failure
- terrain contact source generation failure
- filter renderer instantiate failure
- early bank-response feature mask invalid
- flow pressure invalid
- vertical blur invalid
- dilate invalid
- normal map invalid
- occupancy proximity invalid
- occupancy pack invalid
- obstacle feature mask invalid
- flow divergence invalid
- each Jacobi pass invalid
- gradient subtract invalid
- each boundary tangency pass invalid
- normal-to-flow invalid
- flow blur invalid
- foam invalid
- foam blur invalid
- primary flow fallback missing
- flow speed scale invalid
- late bank-response feature mask invalid
- combined flow/foam/noise invalid
- combined distance/pressure invalid

Awaited non-filter failures, especially collision map generation and terrain contact source generation, must be counted separately from `_filter_output_is_valid()`-style filter failures.

## Abort Matrix Requirements

Every abort case must prove:

- `_flowmap_bake_in_progress == false`
- no live filter renderer child remains
- no orphan SubViewport remains
- a later bake request can run
- no stale progress source remains
- existing valid bake data is not partially overwritten unless finalization succeeded
- an abort before RiverManager begins result application does not change generated textures, material bindings, `valid_flowmap`, or `RiverBakeData`

Stage buckets to cover:

- pre-renderer awaited waits/source generation, including helper-internal loop awaits
- renderer-live filter pass and Jacobi awaits
- post-renderer cleanup and CPU image postprocess
- RiverManager result application, save attempt, shader refresh, final progress/notice

Scenarios to cover or explicitly name as human-assisted:

- scene close while a bake is running
- River node freed while a bake is running, including terrain-contact helper loop waits
- undo-delete during an awaited pass
- forced invalid filter output
- forced collision generation failure or no-collision fallback path
- forced terrain-contact source generation failure or liveness interruption
- duplicate bake request while one is running
- baker `abort()` called more than once
- baker cleanup after successful bake
- result-application interruption strategy

If result application remains synchronous and non-awaited, record that as the strategy. If any await is added, prove rollback/staging prevents partial generated textures, partial `RiverBakeData`, or a stuck bake flag.

## No RiverManager Reach-Back Checklist

Every baker helper must consume only:

- `BakeConfig`
- local baker state
- explicit frame-await callback
- explicit cancellation/liveness callback
- explicit collision reset/root dependency
- explicit terrain/collision generation context
- explicit warning, print, and progress callbacks

Forbidden:

- passing `self` from RiverManager into the baker
- a generic `owner_node`, `collision_owner`, or RiverManager-like wrapper that allows arbitrary method access
- using helper signatures that hide collision-root lookup, progress, frame await, or liveness behind a broad RiverManager argument

## Premise and Interpretation Checks

- Expected behavior that could look like a bug: fresh rebakes may produce dynamic `bake_revision` changes; whole-resource `.res` hashes may differ even when per-texture content is identical.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out: stale pre-R6 baselines, shared or overwritten bake resources, user editor saves that rewrite `.res` files, and `.codex-research` profile state.
- Research/source context to check: `addons/waterways/docs/research/river-research-citations.md`.
- Evidence that would mean the agent is misreading the situation: RT.1 mismatch without a fresh pre-R6 scratch baseline; metadata diff caused only by `bake_revision`.
- What the agent should say if that evidence appears: pause the R6 gate, identify which baseline is suspect, and run the smallest fresh baseline/diff needed before patching.
- Quick falsifying check before patching: capture pre-R6 dictionary/property/API/source-image/texture baselines before moving code.

## Automated Checks

- `git diff --check`
- Godot parser/check-only on changed scripts.
- `r5_behavior_preservation_probe.gd`
- `r4_runtime_robustness_probe.gd`
- `filter_renderer_load_check.gd` or equivalent with `shader_paths=19`
- `system_flow_projected_gate_probe.gd`
- New metadata/signature/settings canonical dump and diff probe
- Full public API/signal-surface diff
- Full inspector property-list diff
- RT.1 generated texture hash compare for both demo river bakes
- Intermediate source-image hash compare
- Abort matrix probe where feasible
- Runtime ripple owner probe
- Editor validation wrapper/marker probe

Agent limitation note:

- Local static, parser, and headless checks do not prove visible editor interaction, shader visuals, bake output appearance, or menu behavior.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so the user's normal Godot editor profile is not altered.

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

Use this by default for visible Godot editor checks, viewport interaction, scene running, menu actions, shader visuals, bake output, and runtime behavior.

Request to user when R6 reaches the relevant gate:

- Open the project in Godot 4.6.3.
- Start a river bake, close the scene mid-bake, reopen it, and confirm a fresh bake can run.
- Start a river bake, undo-delete or remove the river during an awaited phase if the probe cannot cover it, then confirm the editor remains usable and a fresh bake can run.
- Run the River menu validation actions and relay the Output panel lines containing `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST`.
- Compare normal/debug river views against the pre-R6 expectation and report any visible change.
- Relay Godot version, renderer, console/output errors, and visible result.

Expected result:

- No visible behavior change, no stuck bake flag, no leaked renderer, same validation markers, and successful fresh bake after abort.

## Recorded Results

No R6 validation runs recorded yet.

Recorded result:

- Date:
- Ran by:
- Godot version/renderer/device:
- Command, scene, or workflow:
- Output or parser errors:
- Visible result, if applicable:
- Stable result marker:
- Pass/partial/fail:
- Notes or follow-up:

## Historical Results Archive

Empty.

## Bake Output Check

Scenario:

- Demo river and obstacle demo river bakes, using fresh scratch rebakes where possible.

Expected generated outputs:

- Flow/foam/noise: identical per-texture hashes before and after R6.
- Distance/pressure: identical per-texture hashes before and after R6.
- Obstacle, terrain contact, bank response, and water occupancy feature textures: identical per-texture hashes before and after R6.
- Metadata: exact canonical match except `bake_revision`.
- Source signature and bake settings: exact canonical match with no ignored keys.

Failure signs:

- Any unexplained RT.1 texture mismatch.
- Any source-image hash mismatch before filter pass sequencing moves.
- Any dictionary diff outside the explicit allow-list.
- Whole-resource hash mismatch treated as a failure without per-texture evidence.

## Runtime API Check

Procedure:

- Dump and diff public RiverManager method/signal surface.
- Run existing runtime and ripple probes.
- Verify runtime ripple material owner semantics with owner-conflict/tree-exit cases.

Expected result:

- Public wrappers stay callable.
- Runtime `set_widths()` and `set_flow_speeds()` remain data-only.
- Ripple owner apply/clear/tree-exit/debug-view behavior is unchanged.

Failure signs:

- Missing public method, changed signal, non-owner clear warning drift, material not restored, or debug material left in the wrong state.

## Editor Workflow Check

Procedure:

1. Run direct `validate_data_textures()` and `validate_filter_renderer()` wrapper calls.
2. Run plugin/menu validation actions.
3. Compare marker text with pre-R6 output.

Expected result:

- RiverManager wrappers remain unconditional and emit the same markers.
- `validate_filter_renderer()` menu behavior still instantiates the current `filter_renderer.tscn` and runs the same smoke-pass subset.
- All-19-pass coverage remains in `filter_renderer_load_check.gd` or an equivalent separate probe.

Failure signs:

- Marker drift, wrapper missing/no-op in probe context, editor-only helper loaded in runtime path, or accidental menu coverage expansion.

## Artifact Hygiene Check

- Scratch project or temporary folder used: record `.codex-research` subfolders per run.
- Active scripts/resources mirrored into scratch before validation: record if applicable.
- Generated bakes/resources created: record both demo river scratch bakes and any `.res` outputs.
- Files or folders that must be excluded from packaging: `.codex-research`, probe dumps, capture PNGs, scratch bakes, profile folders.
- Files or folders safe to delete now: record after R6 validation completes.

## Manual Review Checklist

- [ ] Acceptance criteria in `spec.md` are satisfied.
- [ ] Source timing contract is preserved or deliberate changes are documented and validated.
- [ ] Canonical dictionary dumps are implemented before baseline capture.
- [ ] No broad RiverManager reach-back exists in the baker.
- [ ] Runtime/editor boundary is preserved.
- [ ] Generated resources and metadata remain explicit and inspectable.
- [ ] Human-assisted editor/menu/visible checks are recorded when needed.
- [ ] Parent docs and latest handoff are updated only after validation runs.
