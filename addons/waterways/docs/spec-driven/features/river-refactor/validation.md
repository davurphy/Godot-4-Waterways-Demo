# Validation: River Refactor (Hardening + Refactor Track)

## What Must Be Proven

- Each of the eleven audited defects is fixed, verified by its phase's gate (roadmap **Validation** blocks).
- Behavior-preserving phases (R3, R5, R6) change nothing observable: byte-identical bake output (RT.1), pixel parity (RT.2), unchanged inspector property lists, intact undo behavior.
- The single v28 signature bump (R1) invalidates pre-bump bakes and nothing else changes bake content without it (R0.5's documented hotfix exception aside).
- System maps regenerated after R2 carry projected flow matching the rivers' own baked flow inside obstacle influence zones (RT.3), and stale maps warn on load (R2.4).
- Runtime fixes (R4) hold under stress: forced low FPS, post-hitch recovery, 60 Hz emitters, 50-point curve editing, two-system scenes, settled-body sleep.
- R7's solve stays within f16 epsilon of the CPU path and is provably fenced against the Defect-6 ordering hazard; bake wall-clock improvement is measured and recorded.

## Current Validation Snapshot

- Overall status: Partial — R0 implemented (branch `river-refactor`); headless checks pass, human-assisted R0 checks pending; RT tooling not built yet
- Last automated pass: 2026-06-12 — `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK` (all exit 0), plus `--check-only` parse pass on river_manager.gd / river_gizmo.gd / plugin.gd / rebake_probe.gd
- Last human-assisted pass: none
- Highest-risk unproven behavior: R0 visual/editor checks (foam parity, null-distmap neutrality, mid-bake close recovery, click-without-drag) — headless signal cannot prove these; then R3 include-extraction pixel parity (RT.2 must be built first)
- Known unreliable local check or environment caveat: headless rendering is unreliable per the constitution — all pixel-parity gates are windowed/human-assisted by default; headless editor-load signal is never proof of visible behavior

## Validation Matrix

Use this as the durable map from requirements to proof. Prefer stable probe names, scene names, or result markers. One row per phase gate; add rows as RT tools land and get demonstrated.

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| R0 defect fixes hold | Roadmap R0 Validation block (rebake demo river; null-distmap river; mid-bake close; click-without-drag; hardened probes) | Editor (human) + headless probes | Foam Mix matches surface; neutral pillows/gates; re-bake succeeds; no undo entry; probe `*_OK` markers | Partial — probes Pass headless; editor/visual checks pending | 2026-06-12 | Agent |
| RT tools work (known-good/known-bad) | RT.1 on two same-scene bakes, then on pre/post-R0.5 pair | Headless | Identical → exit 0; margin-region diff flagged → nonzero with per-channel delta | Unrun | — | — |
| R1 stale-bake detection + scoped diffs | Pre-bump scene load; RT.1 on demo scenes; grep for deleted constants | Editor + headless | Stale warning fires; diffs only in R0.5/R1.3 regions; zero code references remain | Unrun | — | — |
| R2 system flow respects projection | RT.3 probe on obstacle demo scene; duck-drift check | Headless probe + editor (human) | Angular/magnitude delta under threshold; ducks no longer drift into boundary-shear paths | Unrun | — | — |
| R3 extraction parity | Shader compile ×3 renderers; RT.2 capture diff; system-map regen compare; inspector revert spot-checks | Windowed (human-assisted) | Compiles clean; pixel deltas under threshold; system maps match; reverts restore live shader defaults | Unrun | — | — |
| R4 runtime robustness | Forced 20 FPS ripple run; 2 s hitch; 60 Hz emitter; 50-point curve edit frame capture; width array diff; two-system scene; sleep check | Editor/runtime (human-assisted) | Artifact-free reduced-rate propagation (rate documented here); no step burst; waves propagate; interactive editing; identical arrays; coverage-bound binding; body sleeps | Unrun | — | — |
| R5/R6 behavior preservation | RT.1 hash-compare; property-list dump+diff; undo round-trip probe; (R6) abort matrix + metadata dict diffs | Headless + editor | Byte-identical bakes; empty diffs; undo intact; no stuck flags/leaked renderers/orphan viewports | Unrun | — | — |
| R7 solve correctness + perf | f16-epsilon compare vs CPU path; adversarial ordering test; wall-clock before/after | Editor | Within epsilon; fence prevents stale read when both viewports update in one frame; wall-clock recorded as regression budget | Unrun | — | — |
| RT.4 cross-language seed invariant | Seed assertion probe | Headless | `Color(0.5,…)` == enc(0) in all three solve encodings; `*_OK` marker | Unrun | — | — |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug: R4.1's reduced ripple rate below `simulation_update_rate` is the *chosen* trade (slower-but-correct), not a regression — document the measured rate here, never log it as a failure. R0.6's inspector ordering is unchanged because `reorder_params` was already a no-op. The seam probe's exit code currently depends only on load errors (deltas land in stats) — a "passing" run proves less than it looks like until R0.9 fixes or relabels it.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out: stale pre-v28 bakes after R1 (expected to be flagged, not silently re-validated); stale system maps after R2 (no automatic staleness — must be regenerated by hand until R2.4's warning lands); `.codex-research` probe user-data folders carrying old caches.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation: an RT.1 mismatch on a phase that claims byte-identity may mean the *baseline* bake was stale, not that the refactor changed content — re-bake the baseline on the pre-change commit before concluding regression.
- What the agent should say to the user if that evidence appears: state which side of the compare is suspect, the smallest re-run that disambiguates (fresh baseline bake at the pre-change commit), and hold the phase gate open until it runs.
- Quick falsifying check before patching: each R0 item's validation step doubles as its falsifier — run it on the unpatched build first when cheap (e.g., confirm Foam Mix actually diverges before R0.2).

## Automated Checks

- Command or procedure: headless console probes under `probes/` (hardened with `*_OK` markers and `out=` support by R0.9); RT.1 hash-compare; RT.3 flow comparison; RT.4 seed assertion. Exact commands recorded here as the tools land.
- Expected result: stable `*_OK` markers; nonzero exit with per-channel delta summary on real mismatches.
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

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so the agent does not alter the user's normal Godot editor profile.

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

Use this by default for visible Godot editor checks, viewport interaction, scene running, gizmos, shader visuals, bake output, and runtime behavior. The agent may not be able to open or interact with Godot reliably. RT.2 pixel-parity runs are windowed/human-assisted **by design** (constitution rule 8).

When requesting this validation, the agent must put the exact request in the chat message so the user does not have to open this file to discover what to run.

- Request to user: (per phase — pull the exact scene/steps/expected visuals from the phase's roadmap **Validation** block)
- Exact scene, command, or workflow to run:
- Plugin state required: waterways plugin enabled; relevant demo scene open
- Console output or errors to relay back:
- Screenshot or visible behavior to relay back:
- Godot version and renderer to relay back:
- Expected result:
- Failure signs:
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

- Date: 2026-06-12
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, headless display server, Windows 11
- Command, scene, or workflow: Phase R0 headless validation on branch `river-refactor` — `flow_arrow_neutral_cells_probe.gd` and `flow_arrow_direction_outlier_probe.gd` (with `out=res://.codex-research/probe-out`), `river_flowmap_seam_probe.gd` (diagnostic mode), and `--check-only` on river_manager.gd, river_gizmo.gd, plugin.gd, rebake_probe.gd
- Output or parser errors: first run caught a compile error in the R0.5 edit (`previous_strip_y` type inference from `max()`); fixed with an explicit `int` type, all subsequent runs clean
- Visible result, if applicable: n/a (headless)
- Stable result marker: `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK`, all exit 0; neutral-cells counts on the demo bake: flowing 928, dead_flow 517, solid_protrusion 94, solid_collision 58, stilled_ring 3
- Pass/partial/fail: Partial (phase gate) — headless portion Pass; human-assisted portion (foam parity, null-distmap visuals, mid-bake close, click-without-drag undo) not yet run
- Notes or follow-up: headless-OK probe runs prove parse/compile and probe behavior only, not editor or shader visuals. The probe overlays were written to `.codex-research/probe-out/` (excluded from packaging). Neutral-cells counts shifted vs pre-R0.9 runs are expected: the probe now mirrors the FLOW_ARROWS sub-cell fallback.

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

Empty — no runs recorded yet.

## Shader Checks

- Shader/material path: `river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader`, and (post-R3) the three new `.gdshaderinc` files
- Renderer backend: Forward+, Mobile, **and** Compatibility — all three are part of R3's compile gate
- Expected result: clean compile on all three; RT.2 pixel parity before/after extraction; debug views match the surface after R0.2
- Failure signs: compile errors on any backend; pixel deltas above threshold in RT.2 diffs; foam/eddy divergence between surface and debug views

## Editor Workflow Check

Procedure (R0.4 gizmo/undo gate — representative; other phases substitute their roadmap Validation block):

1. Open the demo river scene with the plugin enabled.
2. Click a river gizmo handle without dragging.
3. Check the undo history and the river's `valid_flowmap` state.
4. Start a bake, close the scene mid-bake, reopen, and bake again.

Expected result:

- No "Change River Shape" undo entry from a click-without-drag; `valid_flowmap` untouched; the second bake runs to completion (no permanently swallowed `bake_texture()` requests).

Failure signs:

- Spurious undo entries; `valid_flowmap: false` after a no-op click; `bake_texture()` silently ignored after a mid-bake scene close; errors from freed-gizmo `river_changed` callables.

## Visual Test Scene

Scene path:

- Demo river scene and obstacle demo scene (project demo scenes — also the fixed fixtures for RT.1 hash baselines and RT.2 camera captures)

Purpose:

- Prove debug/surface parity (R0.2), neutral null-distmap rendering (R0.7), extraction pixel parity (R3), and duck behavior near obstacles (R2).

Expected visual result:

- Foam Mix debug view matches the visible surface; pillows/gates render neutral (not maxed) with a null distmap; before/after RT.2 captures are indistinguishable; ducks follow projected flow instead of drifting into boundary-shear paths.

Failure signs:

- Foam/eddy mismatch between surface and debug; maxed-out pillow/gate response on null distmap; visible surface change after a "pure-move" include commit; ducks veering near obstacles.

Suggested controls or debug views:

- Foam Mix debug view; impulse/contact heat view (consumes `i_ripple_impulse_texture` — must survive R1); fixed RT.2 camera presets.

## Bake Output Check

Scenario:

- Demo river (single- and multi-tile) baked before and after each content-affecting or behavior-preserving phase.

Expected generated outputs:

- Flow: unchanged except where R0.5/R1.3 explain the diff (RT.1 localizes it); projected rivers' system-map flow matches their baked flow after R2.
- Foam: unchanged through R3/R5/R6 (hash-gated).
- Distance/pressure: real texture when baked; code-side neutral ≈ (0.75, 0.25, 0.0, 0.5) bound when null (R0.7).
- Height/alpha: unchanged through extraction phases.
- Metadata: v28 signature with the R1.2 keys; `flow_projected` present; no `..._with_legacy_sdf_steering_fallback` string after R1.1; system bake settings carry the R2.4 version int.

Failure signs:

- RT.1 diffs outside the explained regions; first-tile UV2 margin artifacts persisting after R0.5; a scene saved with in-scene textures reloading with `valid_flowmap == true` but null occupancy (R1.3's target); stale bakes accepted after the v28 bump.

## Runtime API Check

Procedure:

- Query `get_water_altitude`/`get_water_flow` via a buoyant body in a two-WaterSystem scene; let a floating body settle; run the ripple field at forced 20 FPS and through a simulated 2 s hitch.

Expected result:

- Body binds to the system whose coverage contains it (not nearest origin); outside coverage, the fallback is explicit (warning or opt-in) rather than silently buoying below world y=0; no per-query Dictionary allocations; settled body sleeps; ripple sim steps once per `_process`, recovers from hitches without a step burst, and emitters firing near frame rate cannot starve propagation.

Failure signs:

- Wrong-system binding; silent y<0 buoyancy; allocation churn per tick; `sleeping = false` forced every tick on settled bodies; corrupted ping-pong reads or step bursts after hitches.

## Performance Check

Scenario:

- R4.2: interactive curve editing on a 50-point river. R4.3: per-tick buoyancy sampling. R7: full bake on a fixed demo scene.

Budget or target:

- Curve editing stays interactive (frame-time capture before/after R4.2; width arrays byte-identical to brute force).
- Zero per-query allocations in `_sample_system_map`.
- R7: all 40 readback/re-upload round-trips eliminated; awaited frames roughly halved (~80 → ~40); measured wall-clock recorded **here** as the ongoing regression budget.

How to measure:

- Godot profiler frame-time capture during curve drag; before/after wall-clock on the same scene, same machine, recorded with date and commit.

## Artifact Hygiene Check

- Scratch project or temporary folder used: `.codex-research\godot-user*` (probe user-data redirects)
- Active scripts/resources mirrored into scratch before validation: confirm per probe run
- Generated bakes/resources created: baseline + comparison bakes for RT.1; RT.2 capture PNGs and diffs
- Files or folders that must be excluded from packaging: `.codex-research\`, probe output dumps, capture PNGs, hash baselines
- Files or folders safe to delete now: stale per-phase probe user-data folders once their phase's results are recorded here

## Extension Check

Custom content scenario:

- After R3.3: a user-modified shader default must be what inspector revert restores (`shader_get_parameter_default`), with no hand-table shadowing it. After R5.1/R5.2: adding a filter pass or a third per-point channel goes through the descriptor tables, not a new clone set.

Expected result:

- Inspector revert restores the *live* shader default for a dozen spot-checked params; a new channel registers via one descriptor entry with undo behavior matching `flow_speeds`.

Failure signs:

- Revert restoring a stale table value; a new pass or channel requiring copy-paste of an existing clone set; `system_map_renderer.gd` fallback literals diverging from shader defaults again.

## Manual Review Checklist

- [ ] Acceptance criteria are satisfied (spec.md Acceptance Tests).
- [ ] Likely false premises or expected-behavior explanations were raised with the user before extra implementation work.
- [ ] Human-assisted Godot/editor/test results are recorded when the agent could not run them directly.
- [ ] Active code uses Godot 4.6+ APIs and avoids obsolete Godot 3 APIs.
- [ ] Editor-only and runtime-safe boundaries are preserved (especially across R6 extraction seams).
- [ ] Generated resources and metadata are explicit and inspectable (v28 contents; system-map version field).
- [ ] Visual output matches the spec (RT.2 parity; debug/surface agreement).
- [ ] Flow direction, seams, foam, masks, and bounds are checked visually.
- [ ] Runtime sampling/API behavior matches generated data (RT.3; buoyancy checks).
- [ ] Performance-sensitive paths have been checked (R4.2/R4.3/R7 budgets above).
- [ ] Known limitations are documented (R4.1's reduced-rate trade; R0.5's unbumped hotfix window; system-map staleness before R2.4).
- [ ] Shared research citations were checked or updated when external river/water references affected the decision.
