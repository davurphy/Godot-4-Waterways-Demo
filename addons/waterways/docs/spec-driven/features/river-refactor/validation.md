# Validation: River Refactor (Hardening + Refactor Track)

## What Must Be Proven

- Each of the eleven audited defects is fixed, verified by its phase's gate (roadmap **Validation** blocks).
- Behavior-preserving phases (R3, R5, R6) change nothing observable: byte-identical bake output (RT.1), pixel parity (RT.2), unchanged inspector property lists, intact undo behavior.
- The single v28 signature bump (R1) invalidates pre-bump bakes and nothing else changes bake content without it (R0.5's documented hotfix exception aside).
- System maps regenerated after R2 carry projected flow matching the rivers' own baked flow inside obstacle influence zones (RT.3), and stale maps warn on load (R2.4).
- Runtime fixes (R4) hold under stress: forced low FPS, post-hitch recovery, 60 Hz emitters, 50-point curve editing, two-system scenes, settled-body sleep.
- R7's solve stays within f16 epsilon of the CPU path and is provably fenced against the Defect-6 ordering hazard; bake wall-clock improvement is measured and recorded.

## Current Validation Snapshot

- Overall status: Partial (track) — **Phases R0, RT, R1, R2, R3, R4, R5, and R8 complete and validated**. R6/R7 remain blocked on their own spec/plan/validation files and the R7 compute decision.
- Last automated/windowed pass: 2026-06-13 R5 structural dedup sweep — Godot 4.6.3 console/windowed: `r5_behavior_preservation_probe.gd` (`R5_BEHAVIOR_PRESERVATION_PROBE_OK`), `r4_runtime_robustness_probe.gd` (`R4_RUNTIME_ROBUSTNESS_PROBE_OK`), `filter_renderer_load_check.gd` (`FILTER_RENDERER_LOAD_OK shader_paths=19`), `system_map_renderer.gd --check-only`, `system_flow_projected_gate_probe.gd` (`SYSTEM_FLOW_PROJECTED_GATE_OK`), scratch baseline-vs-R5 RT.1 rebakes + `bake_hash_probe.gd` texture hashes on both demo river bakes (all six texture properties identical per bake), serialized property-list dump diff (`R5_PROPERTY_LIST_MATCH=True`), and `git diff --check`.
- Last human-assisted pass: 2026-06-13 — user passed R4 Checks 6-7 in `r4_buoyancy_visible_review.tscn`. Checks 2-5 also passed earlier the same session, closing the R4 human-visible suite.
- Most recent R4 human-assisted failure/fix: 2026-06-13 — the first visible ripple review reported no visible ripple or ripple influence in normal/debug views; the window captured the mouse and showed `Queued 3 emitter impulses`. The `Demo.tscn` invalid-UID warning is a known fallback warning and was not the cause. Agent frame captures reproduced the missing localized impulse/contact and influence rings. Fix applied: `water_ripple_field.gd` now separates impulse render, simulation step, and impulse clear across frames so the shader-visible impulse texture survives long enough to be sampled.
- **Attribution correction (2026-06-12, R2 execution):** the recorded pre-R2 "Defect-1 signature" (influence p90 25.5°/28.9°) was NOT the slide — direct A/B rendering (slide gated vs forced) measures the slide's contribution at 0 differing texels on Demo and 4,641 texels at mean 3.3°/max 42° on the obstacle scene; the 23–27° influence floor is sampling/quantization noise of the stilled low-magnitude ring (8-bit flow quantization scales as 1/|v|) and survives the fix. The fix is correct and gated by `system_flow_projected_gate_probe.gd`; RT.3's influence threshold was recalibrated to 35° as a gross-divergence guard (floor-plus-margin, control-gate precedent)
- Highest-risk unproven behavior: the remaining high-risk unproven work belongs to future phases R6/R7, which require their own docs before implementation.
- Known unreliable local check or environment caveat: headless rendering is unreliable per the constitution; additionally `RenderingServer.shader_get_parameter_default` returns null under the headless dummy renderer, so revert checks (`revert_default_check`, `pillow_inspector_wiring_probe`) are windowed. **Hazard:** `river_obstacle_projection_rebake_probe.gd` rebakes and saves both river bakes in place — never run it casually (a stray headless run did exactly that this session; bakes restored from HEAD and verified by hash)

## Validation Matrix

Use this as the durable map from requirements to proof. Prefer stable probe names, scene names, or result markers. One row per phase gate; add rows as RT tools land and get demonstrated.

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| R0 defect fixes hold | Roadmap R0 Validation block (rebake demo river; null-distmap binding probe; mid-bake close; click-without-drag; hardened probes) | Editor (human) + headless probes | Foam Mix matches surface; neutral distmap binding probe `*_OK`; re-bake succeeds after mid-bake close; no undo entry on no-op click; probe `*_OK` markers | Pass — all checks closed (probes + user-run editor checks) | 2026-06-12 | Agent + User |
| RT tools work (known-good/known-bad) | RT.1 on two same-scene bakes, then on pre/post-R0.5 pair | Headless | Identical → exit 0; margin-region diff flagged → nonzero with per-channel delta | Pass — RT.1 (self-diff exit 0; perturbed-rect copy flagged exactly), RT.2 (see RT.2 row), RT.3 (see RT.3 row), RT.4 all demonstrated | 2026-06-12 | Agent |
| RT.2 pixel-parity capture+diff (known-good/known-bad) | `debug_view_capture_probe.gd` `views=parity` twice (windowed), then diff mode (headless) on the two runs and on a perturbed fixture | Windowed capture + headless diff | Two unchanged-code runs → all PNGs byte-identical, `CAPTURE_DIFF_OK`; perturbed/missing files → `CAPTURE_DIFF_MISMATCH`, exit 1 | Pass — 26/26 PNGs byte-identical across two independent runs (after boot-time freeze + fixed grass seed); fixture known-bad flagged | 2026-06-12 | Agent |
| RT.3 system-vs-river flow compare (known-good/known-bad) | `system_flow_compare_probe.gd` default (control gate) vs `enforce=all` (R2 gate) on the demo scenes | Headless | Control zone p90 < 15° with fresh map → `SYSTEM_FLOW_COMPARE_OK`; `enforce=all` pre-R2 → `SYSTEM_FLOW_COMPARE_EXCEEDED zone=influence`, exit 1; stale map → `SYSTEM_FLOW_COMPARE_STALE`, exit 1 | Pass — all three modes demonstrated; re-confirmed on a freshly user-regenerated obstacle map (control p90 12.5° < 15; influence p90 27.6° > 20 flagged; staleness detected on whichever scene the shared bake doesn't match) | 2026-06-12 | Agent |
| R1 stale-bake detection + scoped diffs | Pre-bump scene load; RT.1 on demo scenes; grep for deleted constants | Editor + headless | Stale warning fires; diffs only in R0.5/R1.3 regions; zero code references remain | Pass — stale fired (headless markers + user editor round, warnings cleared after rebake); RT.1: Demo river byte-identical (v28 metadata-only proof), obstacle river shows only the recorded raycast-borderline rebake variance; grep zero code refs | 2026-06-12 | Agent + User |
| R2 system flow respects projection | Mechanism: `system_flow_projected_gate_probe.gd` (windowed A/B render). Gross divergence: RT.3 `enforce=all` (recalibrated 35°). Staleness: R2.4 version int. Duck-drift check (human) | Windowed probes + headless RT.3 + editor (human) | Gated vs forced-slide renders differ where content exercises the slide; repeat renders identical; influence p90 < 35°; pre-v1 maps warn on load | Pass — `SYSTEM_FLOW_PROJECTED_GATE_OK` (obstacle slide_diff=4641, repeat_diff=0); `enforce=all` exit 0 (23.255°/26.913°); stale warning demonstrated on v0 maps then cleared by regeneration; user confirmed scenes/debug views and duck behavior near obstacles in the editor round | 2026-06-12 | Agent + User |
| R3 extraction parity | Shader compile ×3 renderers; RT.2 `views=parity` capture before/after in the same session + headless diff; system-map regen compare; inspector revert spot-checks | Windowed capture + headless diff | Compiles clean; capture PNGs byte-identical; system maps regenerated (changed by design — R2 rode in the same include); reverts restore live shader defaults | Pass — `SCENE_RENDER_SMOKE_OK` on forward_plus/mobile/gl_compatibility; `CAPTURE_DIFF_OK files=26` byte-identical (before vs after the full phase, one windowed session); compiled uniform sets identical on both shaders; `REVERT_DEFAULT_CHECK_OK params=14` + `PILLOW_INSPECTOR_WIRING_PROBE_OK` (windowed); user eyeballed surface + debug views in the editor round (rule-8 confirmation) | 2026-06-12 | Agent + User |
| R8 docs coherence | Grep gates (zero stale mechanism refs in code; doc refs only in historical records); pass-list/uniform/include claims spot-checked vs source; shared flow-arrow probe re-run after R8.4 consolidation | Headless + review | Code grep clean; shared probe `*_OK`; docs match source | Pass — code grep zero hits (`.gd`+shaders); `ARROW_NEUTRAL_CELLS_PROBE_OK` post-consolidation; 19-pass list / 3-include structure / neutrals verified against source | 2026-06-12 | Agent |
| R4 runtime robustness | Forced 20 FPS ripple run; 2 s hitch; 60 Hz emitter; 50-point curve edit frame capture; width array diff; two-system scene; sleep check; `r4_runtime_robustness_probe.gd`; `r4_ripple_visible_auto_review.gd`; `r4_buoyancy_visible_review.tscn` | Editor/runtime (human-assisted) + headless/windowed probe | Artifact-free reduced-rate propagation (rate documented here); no step burst; waves propagate; interactive editing; identical arrays; coverage-bound binding; body sleeps; `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `R4_VISIBLE_AUTO_REVIEW_DONE` | Pass — first user-visible review failed and exposed an impulse scheduling bug, then post-fix agent captures and user rerun showed localized ripple/influence. Checks 2-7 passed by user, including the two-WaterSystem buoyancy coverage and settled sleep scene. | 2026-06-13 | Agent + User |
| R5 behavior preservation | RT.1 hash-compare; property-list dump+diff; undo round-trip probe | Headless + windowed scratch rebakes | Byte-identical texture hashes for generated bakes; empty property-list diff; undo intact | Pass — scratch baseline-vs-R5 rebakes on `Demo.tscn` and `Demo_obstacle_flow_test.tscn` produced identical per-texture RT.1 hashes across all six `RiverBakeData` texture properties; serialized property lists matched exactly (`R5_PROPERTY_LIST_MATCH=True`); `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; R4/system-flow/filter checks still pass | 2026-06-13 | Agent |
| R6 behavior preservation | RT.1 hash-compare; abort matrix + metadata dict diffs | Headless + editor | Byte-identical bakes; no stuck flags/leaked renderers/orphan viewports; metadata dictionaries diff empty | Unrun | — | — |
| R7 solve correctness + perf | f16-epsilon compare vs CPU path; adversarial ordering test; wall-clock before/after | Editor | Within epsilon; fence prevents stale read when both viewports update in one frame; wall-clock recorded as regression budget | Unrun | — | — |
| RT.4 cross-language seed invariant | `flow_solve_seed_assert_probe.gd` | Headless | `Color(0.5,…)` == enc(0) in all three solve encodings; `FLOW_SOLVE_SEED_ASSERT_OK` | Pass | 2026-06-12 | Agent |

## Premise and Interpretation Checks

- (R1.6) The `legacy_collision_only` and `curve_only` bake generation behaviors are intentional, script-API-only (or serialized-scene-only) modes with no inspector exposure — kept on purpose, not dead code (`river_manager.gd` `RIVER_FLOW_GENERATION_BEHAVIOR_*`).
- Expected behavior that could look like a bug: R4.1's reduced ripple rate below `simulation_update_rate` is the *chosen* trade (slower-but-correct), not a regression — document the measured rate here, never log it as a failure. R0.6's inspector ordering is unchanged because `reorder_params` was already a no-op. The seam probe's exit code currently depends only on load errors (deltas land in stats) — a "passing" run proves less than it looks like until R0.9 fixes or relabels it. Post-R2: RT.3's influence-zone p90 of ~23–27° on fresh maps is the measured sampling floor, not a defect (see the 2026-06-12 attribution correction) — do not chase it below the 35° gate; the slide-gate mechanism is what `system_flow_projected_gate_probe.gd` guards.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out: stale pre-v28 bakes after R1 (expected to be flagged, not silently re-validated); stale system maps after R2 (no automatic staleness — must be regenerated by hand until R2.4's warning lands); `.codex-research` probe user-data folders carrying old caches.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation: an RT.1 mismatch on a phase that claims byte-identity may mean the *baseline* bake was stale, not that the refactor changed content — re-bake the baseline on the pre-change commit before concluding regression.
- What the agent should say to the user if that evidence appears: state which side of the compare is suspect, the smallest re-run that disambiguates (fresh baseline bake at the pre-change commit), and hold the phase gate open until it runs.
- Quick falsifying check before patching: each R0 item's validation step doubles as its falsifier — run it on the unpatched build first when cheap (e.g., confirm Foam Mix actually diverges before R0.2).

## Automated Checks

- Command or procedure: headless console probes under `probes/` (hardened with `*_OK` markers and `out=` support by R0.9); RT.1 hash-compare; RT.3 flow comparison; RT.4 seed assertion. Exact commands recorded here as the tools land.
- R4 runtime guard (headless): `& $godotConsole --headless --path $root --script "res://addons/waterways/probes/r4_runtime_robustness_probe.gd"`; marker `R4_RUNTIME_ROBUSTNESS_PROBE_OK`. This covers non-visual invariants only; it does not close the visible low-FPS/editor stress pass.
- R4 visible ripple auto-review (window required): `& $godotConsole --path $root --max-fps 20 --script "res://addons/waterways/probes/r4_ripple_visible_auto_review.gd"`; marker `R4_VISIBLE_AUTO_REVIEW_DONE`. Expected visual result: localized impulse/contact marks and visible-influence rings around the emitter markers; no need to press keys in the captured window.
- R5 behavior-preservation guard (headless): `& $godotConsole --headless --path $root --script "res://addons/waterways/probes/r5_behavior_preservation_probe.gd"`; marker `R5_BEHAVIOR_PRESERVATION_PROBE_OK`. The probe checks filter pass descriptors, Baking property descriptor order, width/flow-speed restore and padding, and `RiverBakeData.finalize()` copy/default restoration. Expected warning: the width-padding assertion intentionally exercises the "too few entries" sanitizer warning.
- RT.3 (after the APPDATA/LOCALAPPDATA redirect from Godot Launch Instructions):
  - report mode (control gate only): `& $godotConsole --headless --path $root --script "res://addons/waterways/probes/system_flow_compare_probe.gd"`
  - influence gate mode (gross-divergence guard; green since R2): append `-- enforce=all`
  - other args: `scene=res://X.tscn stride=4 min_flow=0.05 influence_min=0.05 max_control_deg=15 max_influence_deg=35 sharp_deg=20 height_tol=1.0 allow_stale=1` (stale maps are report-only under `allow_stale=1`, a hard failure otherwise; `sharp_deg` controls the sharp-structure sample exclusion)
- R2 mechanism gate (windowed — A/B system flow renders): `& $godotConsole --path $root --script "res://addons/waterways/probes/system_flow_projected_gate_probe.gd"`; marker `SYSTEM_FLOW_PROJECTED_GATE_OK`. Default scenes carry measured expectations (Demo report-only, obstacle must show slide_diff > 0)
- System-map regeneration (windowed; saves the bake in place): `& $godotConsole --path $root --script "res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/water_system_rebake_probe.gd" -- scene=res://Demo_obstacle_flow_test.tscn`
- R3.3 revert spot-check (windowed — `shader_get_parameter_default` is null headless): `& $godotConsole --path $root --script "res://.codex-research/revert_default_check.gd"`; marker `REVERT_DEFAULT_CHECK_OK`. `pillow_inspector_wiring_probe.gd` is also windowed-only since R3.3 for the same reason
- 3-renderer smoke (windowed): `& $godotConsole --path $root --rendering-method <forward_plus|mobile|gl_compatibility> [--rendering-driver opengl3] --script "res://.codex-research/scene_render_smoke.gd"`; marker `SCENE_RENDER_SMOKE_OK`
- RT.2 (captures are windowed — run without `--headless`; the diff runs headless):
  - capture: `& $godotConsole --path $root --script "res://addons/waterways/probes/debug_view_capture_probe.gd" -- views=parity stations=2 label=<before|after> out=res://.codex-research/probe-out/rt2` (deterministic by default: frozen time + fixed grass seed; `freeze=0` for animated human-review captures)
  - diff: `& $godotConsole --headless --path $root --script "res://addons/waterways/probes/debug_view_capture_probe.gd" -- a=<dir> b=<dir>` (optional `max_delta=0.02 mean_delta=0.002`); marker `CAPTURE_DIFF_OK`
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

- Request to user for next session: no R4 human-visible rerun is needed unless a later code change touches ripple timing/material binding, buoyancy coverage binding, WaterSystem sampling, or settled-body sleep behavior. R5 is closed; next implementation work should first write the R6/R7 phase docs, because both phases remain blocked on their own docs.
- Before starting: use Godot 4.6.3 with the Waterways plugin enabled. Do not save changed demo/review scenes unless the change is deliberate; if Godot prompts after a temporary test edit, choose not to save. Report Godot version, renderer/device, pass/fail per check, Output panel warnings/errors, and anything visually odd. The known `Demo.tscn` invalid-UID fallback warning for `WaterSystem.water_system_bake.res` is acceptable and is not an R4 ripple failure.
- Check 1, ripple low-FPS auto-review: **Pass on 2026-06-13 (user)**. Current stable command: `& $godotConsole --path $root --max-fps 20 --script "res://addons/waterways/probes/r4_ripple_visible_auto_review.gd"`. Expected and observed: normal/debug views show localized ripples/ripple influence; impulse/contact is localized; raw height shows local motion; the script disables and re-enables the field cleanly; marker `R4_VISIBLE_AUTO_REVIEW_DONE`.
- Check 2, hitch recovery: **Pass on 2026-06-13 (user)**. Stable workflow: run `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`, then click `Run soft hitch test` or press `H`. The harness soft-freezes only the ripple field for 2 seconds per view, then resumes with a queued backlog. Expected and observed: every view recovers without rapid catch-up burst, texture corruption/full-field flashing, or static impulse stamps. `8` is intentionally disabled in this review scene after it triggered editor/debugger pause behavior on the user's machine.
- Check 3, 60 Hz emitter stress: **Pass on 2026-06-13 (user)**. User temporarily set `WaterRippleField/PulseEmitter_UpperWater.pulse_rate` to `60.0` without saving; the emitter fired consistently and did not freeze into static impulse stamps. Its ripple field stayed close to the stationary emitter, which is acceptable fixed-source overlap behavior. User repeated the 60 Hz stress on `MovingEmitter_TestTrail`, and that moving emitter extended outward/traced normally. No Output errors were reported.
- Check 4, curve editing responsiveness: **Pass on 2026-06-13 (user)**. User opened `res://Demo.tscn`, selected `WaterSystem/Water River`, and tested curve editing responsiveness. Expected and observed: interactive editing/responsive bank/mesh updates, no blocking stalls reported, and no Output errors reported. Do not save temporary curve edits.
- Check 5, ripple inspector state: **Pass on 2026-06-13 (user)**. User selected `WaterRippleField` and an emitter child in the ripple review scene, exercised the inspector preset/apply/capture UI, changed selection/visibility lifecycle enough to test transient state, and reported pass. Expected and observed: transient inspector state did not vanish merely from selection/visibility changes, no stale duplicated UI reported, no Output errors reported, and no unwanted dirty-state behavior reported.
- Check 6, two-WaterSystem buoyancy coverage: **Pass on 2026-06-13 (user)**. User ran `res://addons/waterways/probes/r4_buoyancy_visible_review.tscn` and reported all tests passed. Expected and observed: overlay showed `Coverage binding: PASS`; the test body is visibly closer to the red WaterSystem origin, but binds to the farther green WaterSystem whose coverage contains it.
- Check 7, settled body sleep: **Pass on 2026-06-13 (user)**. Same scene and run as Check 6. Expected and observed: overlay showed `Settled sleep: PASS` after the observation window; no visible forever-twitch or repeated wake behavior was reported.
- R4 closure: all human-visible Checks 1-7 have now passed after the impulse scheduling fix.
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

- Date: 2026-06-13
- Ran by: Agent (Phase R5 structural dedup, branch `river-refactor`)
- Godot version/renderer/device: Godot 4.6.3 console; headless for parser/probe/hash checks; Forward+ Vulkan on AMD Radeon RX 6800 XT for windowed rebakes and system-flow render probe
- Command, scene, or workflow: Implemented R5.1-R5.5 in `filter_renderer.gd`, `system_map_renderer.gd`, `river_manager.gd`, and `resources/river_bake_data.gd`; added `probes/r5_behavior_preservation_probe.gd`. Ran the R5 guard probe, R4 runtime guard, filter renderer load check, `system_map_renderer.gd --check-only`, `system_flow_projected_gate_probe.gd`, `git diff --check`, serialized property-list dumps in scratch baseline/current projects, and RT.1 scratch rebakes of `Demo.tscn` + `Demo_obstacle_flow_test.tscn` with `rebake_probe.gd save=true system=none`.
- Output or parser errors: none in final runs. The R5 guard prints the expected width-padding sanitizer warning while asserting that too-short width arrays pad correctly. Scratch `git worktree` setup was blocked by `.git` write permissions, so RT.1 used full filesystem scratch copies plus an overlaid HEAD baseline; the large scratch copies remain under `.codex-research/r5-rt1-*` because sandbox policy blocked recursive cleanup.
- Visible result, if applicable: n/a for user-facing visuals. Windowed system-flow mechanism probe preserved the prior signature: Demo report-only `slide_diff_texels=0`, obstacle `slide_diff_texels=4641`, `repeat_diff_texels=0`, marker `SYSTEM_FLOW_PROJECTED_GATE_OK`.
- Stable result marker: `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `FILTER_RENDERER_LOAD_OK shader_paths=19`; `SYSTEM_FLOW_PROJECTED_GATE_OK`; `R5_PROPERTY_LIST_MATCH=True length_baseline=20207 length_current=20207`; RT.1 texture hashes matched for both generated demo river bakes across `flow_foam_noise`, `dist_pressure`, `obstacle_features`, `terrain_contact_features`, `bank_response_features`, and `water_occupancy`.
- Pass/partial/fail: Pass — **Phase R5 gate closed**. Note: whole `.res` file MD5s differed after ResourceSaver, but RT.1's per-texture content hashes were byte-identical; the gate is texture content, not resource-file serialization.
- Notes or follow-up: R6/R7 remain blocked on their own spec/plan/validation docs; R7 also needs the compute decision recorded.

Recorded result:

- Date: 2026-06-13
- Ran by: User (R4 Checks 6-7 buoyancy coverage and settled sleep)
- Godot version/renderer/device: Godot 4.6.3 editor/runtime assumed from this validation session; renderer/device not reported in chat
- Command, scene, or workflow: Ran `res://addons/waterways/probes/r4_buoyancy_visible_review.tscn`, the self-contained visible scene with red near-origin/outside-coverage WaterSystem, green farther covering WaterSystem, coverage-binding body, live settling body, and sleep-watch body.
- Output or parser errors: none reported in chat.
- Visible result, if applicable: Pass — user reported all tests passed. Expected overlay results: `Coverage binding: PASS` and `Settled sleep: PASS`; no forever-twitch or repeated wake behavior was reported.
- Stable result marker: user-visible pass; prior agent verifier marker for this scene was `R4_BUOYANCY_VISIBLE_REVIEW_PROBE_OK`.
- Pass/partial/fail: Pass for R4 Checks 6-7. With Checks 1-5 already passed earlier on 2026-06-13, the R4 human-visible suite is closed.
- Notes or follow-up: Do not rerun unless later code changes touch ripple timing/material binding, buoyancy coverage binding, WaterSystem sampling, or settled-body sleep behavior.

Recorded result:

- Date: 2026-06-13
- Ran by: User (R4 Check 5 ripple inspector state)
- Godot version/renderer/device: Godot 4.6.3 editor/runtime; renderer/device not reported in chat
- Command, scene, or workflow: In `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`, selected `WaterRippleField`, used the ripple inspector preset/apply/capture UI enough to show transient state, clicked away/back and repeated with an emitter child.
- Output or parser errors: none reported in chat.
- Visible result, if applicable: Pass — user reported the inspector lifecycle/state test passed; no stale duplicated UI or transient-state loss was reported.
- Stable result marker: user-visible pass.
- Pass/partial/fail: Pass for R4 Check 5 ripple inspector state. At this point R4 was still open for Checks 6-7; those later passed on 2026-06-13.
- Notes or follow-up: Do not save accidental scene edits from inspection unless deliberate.

Recorded result:

- Date: 2026-06-13
- Ran by: User (R4 Check 4 curve editing responsiveness)
- Godot version/renderer/device: Godot 4.6.3 editor/runtime; renderer/device not reported in chat
- Command, scene, or workflow: Opened `res://Demo.tscn`, selected `WaterSystem/Water River`, and exercised curve point/handle editing responsiveness.
- Output or parser errors: none reported in chat.
- Visible result, if applicable: Pass — user reported the test passed; no long stalls or responsiveness issues were reported.
- Stable result marker: user-visible pass.
- Pass/partial/fail: Pass for R4 Check 4 curve editing responsiveness. At this point R4 was still open for Checks 5-7; those later passed on 2026-06-13.
- Notes or follow-up: Do not save temporary curve edits.

Recorded result:

- Date: 2026-06-13
- Ran by: User (R4 Check 3 60 Hz emitter stress)
- Godot version/renderer/device: Godot 4.6.3 editor/runtime; renderer/device not reported in chat
- Command, scene, or workflow: In `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn`, user temporarily set `WaterRippleField/PulseEmitter_UpperWater.pulse_rate` to `60.0` without saving, ran the scene, then repeated the 60 Hz stress on `MovingEmitter_TestTrail` as a comparison.
- Output or parser errors: none reported in chat. Known `Demo.tscn` invalid-UID fallback warning is acceptable if present.
- Visible result, if applicable: Pass — `PulseEmitter_UpperWater` fired consistently. Its ripple field stayed relatively close to the stationary emitter, which is acceptable fixed-source overlap behavior. `MovingEmitter_TestTrail` at 60 Hz extended outward/traced normally, confirming wave propagation continues under heavy emission.
- Stable result marker: user-visible pass.
- Pass/partial/fail: Pass for R4 Check 3 60 Hz emitter stress. At this point R4 was still open for Checks 4-7; those later passed on 2026-06-13.
- Notes or follow-up: Do not save the temporary `pulse_rate = 60.0` scene edits; reload/close without saving or restore `PulseEmitter_UpperWater.pulse_rate = 0.85` and `MovingEmitter_TestTrail.pulse_rate = 12.0`.

Recorded result:

- Date: 2026-06-13
- Ran by: User + Agent (R4 Check 2 hitch recovery, branch `river-refactor`)
- Godot version/renderer/device: User visible editor/runtime, Godot 4.6.3; agent verification with Godot 4.6.3 console windowed, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: User ran `res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn` and passed the soft-hitch review using the in-scene `Run soft hitch test`/`H` path. Earlier attempts to use a real OS/thread freeze or the `8` key caused editor/game pause behavior, so the review scene now soft-freezes only `WaterRippleField` processing for 2 seconds per view and queues backlog before resuming normal frames.
- Output or parser errors: User reported pass; no Output errors were reported. Known `Demo.tscn` invalid-UID fallback warning is acceptable if present. Agent verification produced only that known UID warning.
- Visible result, if applicable: Pass — normal, visible influence, impulse/contact, raw height, and boundary mask views recover after the soft hitch without rapid catch-up burst, full-field flashing, texture corruption, or static impulse stamps.
- Stable result marker: user-visible pass; agent verification markers `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK` and `R4_SOFT_HITCH_PROBE_OK`.
- Pass/partial/fail: Pass for R4 Check 2 hitch recovery. At this point R4 was still open for Checks 3-7; those later passed on 2026-06-13.
- Notes or follow-up: Use `H` or the button for this harness. `8` is explicitly disabled in the scene because it triggered editor/debugger pause behavior on the user's machine.

Recorded result:

- Date: 2026-06-13
- Ran by: User (R4 ripple visible auto-review rerun after impulse scheduling fix)
- Godot version/renderer/device: Godot 4.6.3, renderer/device not recorded in the chat reply
- Command, scene, or workflow: Ran `res://addons/waterways/probes/r4_ripple_visible_auto_review.gd` at forced 20 FPS after the impulse render/step/clear scheduling fix.
- Output or parser errors: not reported in the chat reply. Known `Demo.tscn` invalid-UID fallback warning is acceptable if present.
- Visible result, if applicable: Pass — user confirmed visible ripples and ripple influence in the normal/debug views.
- Stable result marker: user-visible confirmation of `R4_VISIBLE_AUTO_REVIEW_DONE` workflow; prior agent run printed `R4_VISIBLE_AUTO_REVIEW_DONE`.
- Pass/partial/fail: Pass for the immediate R4 visible ripple rerun. At this point R4 was still open for the more involved human-visible suite; that suite later passed on 2026-06-13.
- Notes or follow-up: The old manual keypress-heavy low-FPS checklist is superseded by the scripted auto-review because the captured mouse/window path was unreliable on the user's machine.

Recorded result:

- Date: 2026-06-13
- Ran by: User + Agent (R4 visible ripple failure follow-up, branch `river-refactor`)
- Godot version/renderer/device: User-visible Godot 4.6.3 windowed run; agent follow-up with Godot 4.6.3 console windowed captures, Windows 11
- Command, scene, or workflow: User ran the ripple visible review path and reported no visible ripple or ripple influence in normal/debug views; the window captured the mouse and the overlay stayed at `Queued 3 emitter impulses`. Agent reproduced with a capture script against `ripple_field_emitter_demo_review.tscn`, fixed the impulse scheduling in `water_ripple_field.gd` by separating impulse render, simulation step, and impulse clear across frames, then promoted `r4_ripple_visible_auto_review.gd` as the stable rerun command.
- Output or parser errors: Known `Demo.tscn` invalid-UID fallback warning appeared in related runs; it was reproduced separately and is not the ripple blocker.
- Visible result, if applicable: Pre-fix captures showed no localized impulse/contact or influence rings. Post-fix captures show localized impulse/contact and visible-influence rings around the emitters; the exact visible auto-review command completed locally at forced 20 FPS and the user rerun later confirmed the visible ripples/ripple influence.
- Stable result marker: `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK`; `RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK`; `R4_VISIBLE_AUTO_REVIEW_DONE`; `git diff --check` clean after the fix.
- Pass/partial/fail: Partial at the time — the initial visible check failed as reported by the user; the code fix, agent visual captures, agent-run visible auto-review, and user rerun pass. The remaining live-editor R4 checks later passed on 2026-06-13.
- Notes or follow-up: The immediate visible-ripple rerun is closed, and the later involved human-visible R4 suite is now closed too.

Recorded result:

- Date: 2026-06-13
- Ran by: Agent (Phase R4 implementation, branch `river-refactor`)
- Godot version/renderer/device: Godot 4.6.3 console headless, Windows 11
- Command, scene, or workflow: Implemented R4.1-R4.6: one ripple simulation step per `_process` with impulse frames still accumulating time; `Curve3D.get_closest_offset`-based width sampling with a legacy-tolerance lookup table; coverage-bound buoyancy system selection plus explicit outside-coverage fallback warning and no forced body wake; ripple target lifecycle refresh and one-shot emitter retry cap; small guard fixes; per-step ripple uniform update reduced to the swapped texture. Added `probes/r4_runtime_robustness_probe.gd`, then ran parser/check-only on changed scripts, the new R4 probe, existing ripple probes, and the core system/flow/bake probes.
- Output or parser errors: none in final runs. `system_flow_compare_probe.gd` printed known UID fallback warnings for existing demo bake resources, then passed; those warnings are not R4 failures.
- Visible result, if applicable: n/a for this entry. The human-visible low-FPS/runtime/editor stress pass remains pending.
- Stable result marker: `R4_CHECK_ONLY_OK`; `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `R4_EXISTING_RIPPLE_PROBES_OK`; `R4_CORE_PROBES_OK`; underlying markers included `RIPPLE_FIELD_EMITTER_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK`, `RIPPLE_PHASE9_PRESET_API_PROBE_OK`, `RIPPLE_PHASE10_INSPECTOR_PROBE_OK`, `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `SYSTEM_FLOW_COMPARE_OK` (default and `enforce=all`), `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, and `BAKE_HASH_PROBE_OK`.
- Pass/partial/fail: Partial — R4 implementation and automated/headless guard coverage pass; the phase gate is still open for visible runtime/editor stress validation.
- Notes or follow-up: The R4.1 slowdown below `simulation_update_rate` is still the accepted design trade and must not be treated as a failure. The R4.2 width probe asserts parity against the legacy 1/100-segment search tolerance used by the old brute-force path; the user later confirmed curve editing responsiveness on 2026-06-13.

Recorded result:

- Date: 2026-06-12
- Ran by: Agent (Phase R8 docs coherence, branch `river-refactor`)
- Godot version/renderer/device: Godot 4.6.3 console headless (probe re-run), Windows 11
- Command, scene, or workflow: R8.1 rewrote `architecture-and-features.md` (obstacle mechanism = pressure projection; `water_occupancy`/`i_water_occupancy`/`i_flow_projected` documented; full 19-pass FilterRenderer list; new Shared Shader Includes section; `SYSTEM_FLOW_MAP_VERSION` note). R8.2 added `neutral_dist_pressure`/`neutral_water_occupancy` to `DEFAULT_IMPORT_PROFILE` and documented the dist_pressure neutrals + `system_flow_map_version` in the Data Contract. R8.3 backfilled `spec.md`/`validation.md`/`review.md` into `river-obstacle-flow-constraints/`. R8.4 deleted the two superseded feature-folder flow-arrow probe copies (+`.uid`), added a pointer README, and indexed the five RT tools in `probes/README.md`. R8.5 fixed the "~200+" vertex-cost figure to ~622/~94 in `river-future/Roadmap.md` + `Crest Reuse and Portability Feasibility.md`. Stale-constant cleanup: `implementation-plan.md` annotated. Then re-ran the shared `flow_arrow_neutral_cells_probe.gd` to confirm the shared set is intact post-deletion.
- Output or parser errors: none
- Visible result, if applicable: n/a (docs + headless probe)
- Stable result marker: code grep gate clean — zero `RIVER_OBSTACLE_AVOIDANCE_*` / `legacy_sdf_steering` / `apply_obstacle_avoidance_flow` / `bank_context_gated_local_sdf_steering` in any `.gd` or shader; remaining doc references all in historical records (CHANGELOG, audit, dated river-improvements-roadmap Phase 5B notes, river-pillows signature-20 result, the annotated obstacle implementation-plan) or this folder. `ARROW_NEUTRAL_CELLS_PROBE_OK` on the shared probe post-consolidation (counts flowing 927 / dead_flow 515 / solid 61+94 / stilled 3 — within rebake variance of the recorded 928/517/… baseline). Source spot-checks: FilterRenderer = 19 pass shaders (`filter_renderer.gd` const table); three `.gdshaderinc` includes with the documented consumer sets (river/debug/system_flow + lava + filters for flow_pack; river/debug-only for surface); `RIVER_NEUTRAL_DISTMAP_COLOR = Color(0.75, 0.25, 0.0, 0.5)`; `SYSTEM_FLOW_MAP_VERSION = 1`.
- Pass/partial/fail: Pass — **Phase R8 gate closed** (review-shaped; no human-assisted step required — docs accuracy verified against source).
- Notes or follow-up: R8.4 removed `flow_arrow_neutral_cells_probe.gd` + `flow_arrow_direction_outlier_probe.gd` (and `.uid`s) from the obstacle-constraints `probes/` folder — the hardened shared `probes/` versions (R0.9 markers/`out=`/sub-cell fallback, R3.5 live ramp read) supersede them; the feature-folder copies had no arg parsing. Grep confirmed no code/scene consumer of the deleted paths before removal.

Recorded result:

- Date: 2026-06-12
- Ran by: User (post-R2+R3 editor round)
- Godot version/renderer/device: Godot 4.6.3 windowed editor, Windows 11
- Command, scene, or workflow: Opened both demo scenes with the plugin enabled, inspected the river surface and debug views, ran the obstacle scene and watched duck behavior near the rocks, saved both scenes.
- Output or parser errors: none reported
- Visible result, if applicable: all scenes and debug views passed inspection; no duck-drift anomalies
- Stable result marker: n/a (visual/editor behavior). Tree effect: only the two expected `.uid` sidecars were generated (`flow_pack.gdshaderinc.uid`, `system_flow_projected_gate_probe.gd.uid`, committed `1d9c91a`); scenes and bakes saved byte-unchanged
- Pass/partial/fail: Pass — closes the human-assisted portion of the R2 and R3 gates (and the follow-ups in the entry below)
- Notes or follow-up: with this, **Phases R0–R3 are fully closed**, automated and human-assisted. Open user decision (no urgency, recorded below): whether system_flow should also apply occupancy stilling/wake damping so duck-read magnitudes match the river surface's runtime advection.

Recorded result:

- Date: 2026-06-12
- Ran by: Agent (Phase R2+R3 merged, branch `river-refactor`, commits `c34b136`..`a2ec75c` + docs)
- Godot version/renderer/device: Godot 4.6.3 console — windowed (captures, regen, A/B renders, revert checks, 3-renderer smoke) + headless (suite), Windows 11
- Command, scene, or workflow: R3.1a flow include → R2.1–R2.3 (system_flow consumes it) → R3.1b surface include → R3.2 flow_pack → R2.4 version int → system-map regeneration (both scenes, windowed rebake probe) → R3.3 revert table deletion → R3.4 filter defaults → R3.5 occupancy-const centralization. Extractions were scripted verbatim moves from river.gdshader (`.codex-research/r3_extract.ps1`); every shader-touching step re-ran the load checks; RT.2 captures bracketed the phase in one windowed session.
- Output or parser errors: none in final runs. Two execution findings (below) and one operational incident: a stray headless run of `river_obstacle_projection_rebake_probe` rewrote both river bakes in place (it is a rebake-and-save probe); restored from HEAD, verified `BAKE_HASH_PROBE_OK` + RT.3 green before committing.
- Visible result, if applicable: RT.2 parity PNGs byte-identical — the visible surface and all 13 debug views provably unchanged by the extraction.
- Stable result marker: `CAPTURE_DIFF_OK files=26` (before vs after-includes, before vs after-flowpack, AND before vs final — all byte-identical); `UNIFORM_SET_COMPARE_OK` (compiled uniform sets unchanged on river + debug); `SYSTEM_FLOW_PROJECTED_GATE_OK` (Demo: slide_diff=0 texels, report-only; obstacle: slide_diff=4641 texels mean 3.3° max 42.3°, repeat_diff=0); RT.3 `enforce=all` exit 0 (influence p90 23.255°/26.913° < 35° on regenerated v1 maps; control p90 8.5°/12.7° unchanged); R2.4 demonstrated (both v0 maps flagged `map v0 < current v1` headless AND via runtime push_warning, cleared by regeneration); `SCENE_RENDER_SMOKE_OK` ×3 rendering methods; `REVERT_DEFAULT_CHECK_OK params=14`; `PILLOW_INSPECTOR_WIRING_PROBE_OK` (first full green since its v20 pin; pin now 28); full headless suite exit 0 (RT.3 both modes, seed assert, distmap, both arrows, seam, bake hash, filter-renderer load)
- Pass/partial/fail: Pass — **R2+R3 gates closed** (agent portions; the human-assisted portion closed the same day — see the user-round entry above)
- Notes or follow-up: **(1) Attribution correction:** the pre-R2 influence p90 (25.5°/28.9°) recorded as "the Defect-1 signature" is sampling/quantization noise of the stilled low-magnitude ring, not the slide — proven by A/B render (slide gated vs forced): 0 differing texels on Demo (regenerated map byte-identical to the pre-fix map), 4.6k texels at mean 3.3° on the obstacle scene. The fix is real but invisible to an angular threshold on saved maps; the mechanism gate is the new `system_flow_projected_gate_probe.gd`, and RT.3's influence limit was recalibrated 20→35 (post-fix floor 23.3/26.9 with the new `sharp_deg` exclusion; same floor-plus-margin philosophy as the recorded control-gate recalibration). **(2) Dead revert fallback:** `ShaderMaterial.property_can_revert("shader_parameter/…")` never worked for the internal river material (remap cache fills only when the material itself is inspected) — the deleted table was the only working revert source; replacement calls `RenderingServer.shader_get_parameter_default` directly (null headless → revert checks are windowed). Never-tabled params (e.g. `mat_flow_max`) gain working reverts for the first time. **Follow-ups:** `.uid` sidecars for the three new `.gdshaderinc` files partially committed (flow/surface; flow_pack's and the new probe's will appear after the next editor session — commit them); the next user editor round should eyeball the surface + debug views once (RT.2 says identical) and watch ducks near the obstacle rocks; possible future scope (user decision, noted not implemented): system_flow could apply occupancy stilling/wake damping so duck-read magnitudes match the river surface's runtime advection — today the system map carries full-force magnitudes in the stilled ring.

Recorded result:

- Date: 2026-06-12
- Ran by: User (post-R1 rebake round) + Agent (RT.1 diff + full suite re-run; commit `8fca46b`)
- Godot version/renderer/device: Godot 4.6.3 windowed editor (user) + console headless (agent), Windows 11
- Command, scene, or workflow: User confirmed staleness in the editor, ran Generate Flow & Foam Map on both demo rivers and Generate System Map on both WaterSystems, saved both scenes — no output errors, warnings cleared. Agent extracted the v27 bakes from git (binary-safe `cmd /c` redirection — PowerShell `>` corrupts binary with UTF-16) into `.codex-research/r1-baseline/` and ran `bake_hash_probe` diff mode, then the full suite.
- Output or parser errors: none
- Visible result, if applicable: stale warnings before rebake, cleared after (user)
- Stable result marker: **Demo river: `BAKE_HASH_COMPARE_OK` — all six textures byte-identical v27→v28** (only `signature_version a=27 b=28` differs; proves R1 changed metadata only, and that the bake pipeline is deterministic for this scene on this machine). Obstacle river: expected mismatch — `terrain_contact_features`/`bank_response_features` differ by **2 pixels** each (1/255 single-channel deltas; borderline physics-raycast samples) and the chain downstream of occupancy (occupancy → divergence/Jacobi/projection → flow, plus obstacle features) amplifies them (differing pixels ≤30.7k/128k, mean deltas ≤0.018, max deltas ~1.0 only in mask channels at flip boundaries) — the same rebake-variance signature recorded at the post-R0.5 baseline, not a regression. Suite on fresh v28 bakes: RT.3 default `SYSTEM_FLOW_COMPARE_OK` exit 0 (no stale; control p90 8.5°/12.7°), `enforce=all` exit 1 (influence p90 25.455°/28.854° > 20° — pre-R2 baseline holds on fresh data), `BAKE_HASH_PROBE_OK signature_version=28`, `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK`
- Pass/partial/fail: Pass — **Phase R1 gate closed**
- Notes or follow-up: scene saves also gave the obstacle bake `ext_resource` its previously missing uid (committed). R2's `enforce=all` baseline now reads 25.5°/28.9° on the v28 bakes. v27 baseline copies live in `.codex-research/r1-baseline/` (safe to delete once R2 starts).

Recorded result:

- Date: 2026-06-12
- Ran by: Agent (Phase R1 implementation, branch `river-refactor`, commits `1ca6109`..`717fdb6`)
- Godot version/renderer/device: Godot 4.6.3 console headless, Windows 11
- Command, scene, or workflow: R1.1–R1.7 implemented one commit each (R1.6+R1.7 share one). After each shared-script edit a real headless probe ran (not `--check-only`). Final gate sweep: bake hash on the committed v27 baseline, seed assert, distmap binding, both arrow probes, seam probe, ripple material ownership, RT.3 default and `allow_stale=1`, scratch `filter_renderer_load_check.gd` (compiles the script and loads all 19 remaining pass-shader paths).
- Output or parser errors: none from the R1 edits. Two pre-existing/environmental failures, neither caused by R1: `ripple_debug_parity_probe` cannot run headless (dummy renderer, `texture_2d_get` null — it is a windowed probe by design) and `pillow_inspector_wiring_probe` fails only its stale era pin (`EXPECTED_SIGNATURE_VERSION := 20` vs 27-now-28); its debug-uniform assertions all pass.
- Visible result, if applicable: n/a (headless)
- Stable result marker: stale gate demonstrated — RT.3 default mode exits 1 with `SYSTEM_FLOW_COMPARE_STALE` on **both** demo scenes (`bake-source signature changed`) and rivers skipped as `invalid_flowmap`; `BAKE_HASH_PROBE_OK` (signature_version=27 baseline still readable for the post-rebake RT.1 diff); `FLOW_SOLVE_SEED_ASSERT_OK`; `DISTMAP_NEUTRAL_BINDING_OK`; `ARROW_NEUTRAL_CELLS_PROBE_OK`; `ARROW_DIRECTION_OUTLIER_PROBE_OK`; `RIVER_FLOWMAP_SEAM_PROBE_OK`; `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`; RT.3 `allow_stale=1` exit 0; grep gate: zero remaining code references to `RIVER_OBSTACLE_AVOIDANCE_*`, `apply_obstacle_avoidance_flow`, or the `..._with_legacy_sdf_steering_fallback` string (doc refs persist until R8 — expected)
- Pass/partial/fail: Partial (phase gate) — headless portion Pass; human-assisted portion pending (editor stale warning, rebake round, RT.1 diff vs the v27 baseline)
- Notes or follow-up: audit corrections found during execution: (1) there were **ten** `RIVER_OBSTACLE_AVOIDANCE_*` constants, not nine; (2) the audit's "delete river_debug's material-only uniforms" was wrong for the nine `pillow_*` surface uniforms — `pillow_inspector_wiring_probe` asserts them **on the debug shader** and river-pillows `spec.md` lists them as the inspector contract (the R1.4 class again, caught by the grep-everything rule); they are annotated instead, while the six unasserted `wake_*` material-only uniforms and `OCCUPANCY_CLIP_*` were deleted. R1.2's noise-texture key stores the const path (stable literal in every load context), not a file hash (a `FileAccess` md5 would diverge in exported builds where the source PNG is absent → false stale positives); in-place PNG edits still need a manual rebake. The new-signature-key staleness comparison itself is what the headless STALE markers prove.

Recorded result:

- Date: 2026-06-12
- Ran by: User (bake un-sharing editor round) + Agent (defect fix + full probe sweep)
- Godot version/renderer/device: Godot 4.6.3 windowed editor (user) + console headless (agent), Windows 11
- Command, scene, or workflow: User cleared `bake_data` per scene and regenerated — Demo.tscn → `waterways_bakes/Demo_28018/` (folder suffixed by design: `Demo/` holds the obstacle river's bake, so `_get_scene_bake_folder` diverts), obstacle scene → `waterways_bakes/Demo_obstacle_flow_test/`. Agent re-ran RT.3 both modes plus the full headless suite.
- Output or parser errors: none (after fix below)
- Visible result, if applicable: n/a
- Stable result marker: `SYSTEM_FLOW_COMPARE_OK` exit 0 (report mode, no stale warnings; control p90 8.5°/12.5° < 15°); `enforce=all` → both rivers flagged (influence p90 25.5°/27.6° > 20°, the expected pre-R2 state); full sweep green: `BAKE_HASH_PROBE_OK`, `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK`
- Pass/partial/fail: Pass — both system maps fresh and scene-owned; one **defect found and fixed** en route: the stale detector compared `flow_foam_noise_path`/`dist_pressure_path` as raw strings, but those textures' container flips between contexts (editor sessions save scene-embedded copies, `res://<scene>::ImageTexture_x`; fresh loads bind the bake resource's subresources) and rebakes regenerate subresource ids — so the comparison reported stale falsely on every fresh load of an editor-generated map. Fixed in `water_system_manager.gd` `_get_source_river_metadata_changed_key`: the two path keys are collected for diagnostics but no longer compared (signatures/sizes/bake-resource-path cover real staleness).
- Notes or follow-up: orphaned `waterways_bakes/Demo/WaterSystem.water_system_bake.res` removed (grep found one code consumer — the obstacle-constraints inspect probe — repointed to the obstacle scene's bake). R2's `enforce=all` gate baseline stands at influence p90 25.5°/27.6° on fresh scene-owned maps.

Recorded result:

- Date: 2026-06-12
- Ran by: User (system-map regeneration, commit `fed4967a`) + Agent (probe re-runs)
- Godot version/renderer/device: Godot 4.6.3 windowed editor (user) + console headless (agent), Windows 11
- Command, scene, or workflow: User regenerated the obstacle scene's system map and committed the probe `.uid`. RT.3 re-run in report and `enforce=all` modes.
- Output or parser errors: none
- Visible result, if applicable: n/a
- Stable result marker: report mode `SYSTEM_FLOW_COMPARE_OK` exit 0; `enforce=all` → `SYSTEM_FLOW_COMPARE_EXCEEDED river=obstacle_test/... zone=influence p90_deg=27.572 limit=20.0` exit 1
- Pass/partial/fail: Pass (probe behavior), with one repo-state consequence: the regeneration saved **in place** into the shared `WaterSystem.water_system_bake.res` (`water_helper_methods.gd:60-69` reuses an existing external path), so the staleness flipped — the obstacle scene is now fresh and **Demo.tscn's map is stale**. Both scenes cannot be fresh while they share one bake resource.
- Notes or follow-up: fix: in the obstacle scene clear the WaterSystem's `bake_data` in the Inspector, regenerate (saves a new scene-owned resource), save; then regenerate Demo.tscn's map (restores the shared path as Demo-owned), save. Probe refinements this round: system map paired bilinearly (removes half-pixel offset; small effect), and thresholds recalibrated to the measured scene-dependent control floor (fresh maps: 8.8–12.5° p90; tail driven by sharp flow structure under the shader's linear filtering, worst on the obstacle scene) — defaults now `max_control_deg=15`, `max_influence_deg=20`. Pre-R2 influence signal 27.1–27.6° stays well separated. The known-bad is now demonstrated on a *freshly generated* map — the re-bend is in the current shader, not stale data.

Recorded result:

- Date: 2026-06-12
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, windowed (captures) + headless (diffs), Windows 11
- Command, scene, or workflow: RT.2 demonstration — `debug_view_capture_probe.gd` `views=parity stations=2` run twice into `.codex-research/probe-out/rt2/parity_run1|2`, then diff mode on the pair; diff mode also demonstrated headless on a generated fixture (identical pair, perturbed-rect + missing-file pair)
- Output or parser errors: none (final runs)
- Visible result, if applicable: capture content verified real (normal view shows the rendered demo river; ~1.8 MB average PNGs, no uniform frames)
- Stable result marker: `CAPTURE_DIFF_OK files=26` exit 0 — all 26 PNGs byte-identical across two independent windowed runs; fixture known-bad → `CAPTURE_DIFF_MISMATCH` lines (perturbed rect per-channel deltas, missing file) exit 1
- Pass/partial/fail: Pass (RT.2 capture + diff demonstrated on known-good and known-bad; byte-identity achieved, so R3's gate can demand it)
- Notes or follow-up: two determinism leaks were found and fixed en route, both diagnosed with a diff heatmap (river/rocks identical, banks differing): (1) `Engine.time_scale = 0` must be set in `_initialize` — frozen later, each run pins shader TIME at a different accumulated value and every animated element carries a phase offset; (2) hterrain detail layers re-scatter grass with a time-randomized RNG per load — the probe now enables their `fixed_seed_enabled` export on the runtime instance. Byte-identity is proven for same-session, same-machine runs; capture R3 before/after pairs in one session (driver/GPU state changes across sessions are unproven). `freeze=0` restores animated captures for human visual review. Captures live under `.codex-research/probe-out/rt2/` (excluded from packaging).

Recorded result:

- Date: 2026-06-12
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, headless display server, Windows 11
- Command, scene, or workflow: RT.3 demonstration — `probes/system_flow_compare_probe.gd` on `Demo.tscn` + `Demo_obstacle_flow_test.tscn` in three modes: (A) `allow_stale=1` report mode, (B) `enforce=all allow_stale=1` R2-gate mode, (C) default (no args)
- Output or parser errors: two type-inference parse errors on first load (Dictionary-member `:=` inference), fixed with explicit `float` types; all subsequent runs clean
- Visible result, if applicable: n/a (headless)
- Stable result marker: (A) `SYSTEM_FLOW_COMPARE_OK` exit 0 — control zone p90 8.8° < 10° on the fresh Demo map proves the sampling/transform machinery; (B) exit 1 with `SYSTEM_FLOW_COMPARE_EXCEEDED zone=influence p90_deg=25.758 limit=15.0` — the Defect-1 known-bad caught by the R2 gate, as expected pre-R2; (C) exit 1 with `SYSTEM_FLOW_COMPARE_STALE` on the obstacle scene — its WaterSystem references Demo's system bake, whose stored river metadata names `Water_River.river_bake.res` while the scene's river uses `Water_River_obstacle_test.river_bake.res`
- Pass/partial/fail: Pass (RT.3 gate demonstrated on known-good and known-bad; stale-map detection demonstrated on a real repo-state issue)
- Notes or follow-up: measured noise floor on fresh maps: control zone ~2.7° median / ~8.8° p90 (8-bit flow quantization at low magnitudes, half-system-pixel offset, bilinear-vs-nearest) — default thresholds `max_control_deg=10`, `max_influence_deg=15` sit above it with the pre-R2 influence signal (25.8°) well separated. Samples whose system-map height channel disagrees with the world sample by >1.0 are excluded (`height_mismatch`; 46 such cross-surface/edge-bleed samples in the obstacle scene). The obstacle scene needs its own system map generated in the editor before its numbers gate anything; R2's validation regenerates it anyway. Probe `.uid` sidecar not yet generated (headless runs don't import) — commit it after the next editor session.

Recorded result:

- Date: 2026-06-12
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 windowed editor, Windows 11
- Command, scene, or workflow: R0.3 check — started a bake on the demo river, closed the scene mid-bake, reopened, baked again. R0.4 check — clicked a river gizmo handle without dragging, inspected undo history and bake validity.
- Output or parser errors: none reported
- Visible result, if applicable: second bake ran to completion (no swallowed request); no "Change River Shape" undo entry and bake stayed valid on click-without-drag
- Stable result marker: n/a (editor behavior)
- Pass/partial/fail: Pass (R0.3 and R0.4) — **Phase R0 gate fully closed**
- Notes or follow-up: with R0.2 (foam parity, user), R0.7 (binding probe), and the headless probe/parse passes, all Phase R0 validation items are complete.

Recorded result:

- Date: 2026-06-12
- Ran by: User
- Godot version/renderer/device: Godot 4.6.3 windowed editor, Windows 11
- Command, scene, or workflow: R0.2 human-assisted check — rebaked the demo river (Generate Flow & Foam Map) and compared the Foam Mix debug view against the normal surface view
- Output or parser errors: editor startup warnings about missing probe .uid files and stale bake-resource UIDs (diagnosed separately; fixed in commit 07545dc — not related to the foam check)
- Visible result, if applicable: Foam Mix matches the normal view after rebake
- Stable result marker: n/a (visual)
- Pass/partial/fail: Pass (R0.2 foam parity)
- Notes or follow-up: the rebake regenerated both demo bake resources; RT.1 hash-diff vs the old baseline showed changes in flow_foam_noise, dist_pressure, obstacle_features, water_occupancy (R0.5 margin fix + GPU run variance) with terrain_contact_features and bank_response_features byte-identical. Committed as the post-R0.5 baseline (29349f0). Remaining R0 human checks: mid-bake scene close (R0.3), click-without-drag (R0.4).

Recorded result:

- Date: 2026-06-12
- Ran by: User (visual attempt) + Agent (probe)
- Godot version/renderer/device: Godot 4.6.3 windowed editor + headless console, Windows 11
- Command, scene, or workflow: R0.7 check. User cleared Dist Pressure on the demo bake resource and inspected the Distance/Pressure debug views — both showed alternating blue/pink lines. Diagnosis: that is the debug shader's deliberate invalid-flowmap indicator (`river_debug.gdshader:1098-1101`, magenta/cyan diagonal checker), painted over every view because a null distmap also fails the validity gate (`_apply_bake_data`). All distmap-driven visuals in both shaders are gated behind `i_valid_flowmap`, so the neutral texel is not visually reachable from the demo scene; the real Defect-11 scenario is a legacy scene with `valid_flowmap` saved true and a missing distmap. Verified the mechanism instead with new `probes/distmap_neutral_binding_probe.gd`: a fresh RiverManager binds the neutral texel to `i_distmap` on both materials.
- Output or parser errors: none (final run)
- Visible result, if applicable: blue/pink invalid-indicator stripes (expected for an invalidated flowmap — not a failure)
- Stable result marker: `DISTMAP_NEUTRAL_BINDING_OK texel=(0.75, 0.25, 0.0, 0.5)`
- Pass/partial/fail: Pass (R0.7 — probe-verified binding; the invalid-indicator stripes additionally confirm the validity gate works)
- Notes or follow-up: roadmap R0 validation wording "confirm pillows/gates render neutral" was based on a wrong assumption about reachability; the probe is the durable gate for this behavior.

Recorded result:

- Date: 2026-06-12
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 console, headless display server, Windows 11
- Command, scene, or workflow: RT.1 demonstration — `bake_hash_probe.gd` in hash mode on the demo bake; diff mode self-vs-self; diff mode original-vs-perturbed copy (scratch fixture `.codex-research/bake_hash_known_bad_fixture.gd` adds +0.25 to flow_foam_noise.r in rect (40,50,10x6))
- Output or parser errors: none
- Visible result, if applicable: n/a (headless)
- Stable result marker: `BAKE_HASH_PROBE_OK` (hash mode, signature_version=27, six texture MD5s); `BAKE_HASH_COMPARE_OK` exit 0 (self-diff); known-bad diff exit 1 with `BAKE_HASH_MISMATCH texture=flow_foam_noise` and `diff_rect=[P: (40, 50), S: (10, 6)]`, channel r max_delta=0.24706, all other channels/textures clean
- Pass/partial/fail: Pass (RT.1 gate demonstrated on known-good and known-bad pairs; the pre/post-R0.5 pair demonstration needs windowed rebakes and rides the next rebake session)
- Notes or follow-up: fixture script and generated `.res` live in `.codex-research/` (excluded from packaging, safe to delete)

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
