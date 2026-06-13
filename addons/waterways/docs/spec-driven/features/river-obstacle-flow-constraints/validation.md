# Validation: Occupancy-Masked, Pressure-Projected River Flow

This is a constitution rule-12 backfill (river-refactor R8.3) for a feature that landed before its template docs existed. Detailed run history for the originating work lives in `implementation-plan.md` §4 and §6; the current mechanism gates are owned and re-recorded by `../river-refactor/validation.md` (the R2/R3 entries). This file maps the feature's acceptance contract to its proofs and points at the canonical records rather than duplicating them.

## What Must Be Proven

- No penetration: baked flow does not point into solids; `|flow| ≈ 0` inside solids.
- No interior/under-overhang water rendering; lee sides slowed.
- WaterSystem (duck-read) flow matches the river's own baked flow inside obstacle influence zones, within the gross-divergence guard.
- Old bakes without occupancy still load and behave as identity.

## Current Validation Snapshot

- Overall status: Pass (landed + tuned; mechanism re-validated by river-refactor R2/R3, 2026-06-12).
- Last automated pass: 2026-06-12 — `system_flow_projected_gate_probe.gd` `SYSTEM_FLOW_PROJECTED_GATE_OK`; `system_flow_compare_probe.gd enforce=all` exit 0 (influence p90 23.3°/26.9° < 35°); penetration gates green on the rebake probe. Recorded in `../river-refactor/validation.md`.
- Last human-assisted pass: 2026-06-12 — user editor round confirmed scenes/debug views and duck behavior near the obstacle rocks on both demo scenes.
- Highest-risk unproven behavior: none open for the landed feature. Possible future scope: system_flow occupancy stilling/wake damping (user decision).
- Known unreliable local check or environment caveat: rebakes are not byte-deterministic on the obstacle scene (GPU variance). **HAZARD:** `river_obstacle_projection_rebake_probe.gd` rebakes and **saves both river bakes in place** — never run it casually (a stray headless run did exactly that during R2+R3; restored from HEAD). `RenderingServer.shader_get_parameter_default` and viewport readback are null/unavailable under the headless dummy renderer — capture/render gates are windowed.

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| No penetration into solids | `probes/river_obstacle_projection_rebake_probe.gd` (rebakes + penetration gates; saves bakes) | Windowed (viewport readback) | Soft-limit / allowance fractions under thresholds; `|flow|≈0` inside solids | Pass (fraction gates 0.13–0.21% / 0.45–0.54%) | 2026-06-12 | Agent |
| Occupancy/flow content sane | `probes/river_occupancy_flow_inspect_probe.gd` (diagnostic) | Headless OK | Solid coverage, protrusion attribution, proximity-binned `|flow|` reported | Pass (proximity-ring `|flow|` ≈ 0.22–0.25) | 2026-06-12 | Agent |
| Duck-read flow respects projection | `system_flow_compare_probe.gd enforce=all` (river-refactor RT.3) | Headless | influence p90 < 35° gross-divergence guard; `SYSTEM_FLOW_COMPARE_OK` | Pass (23.3°/26.9°) | 2026-06-12 | Agent |
| Slide-gate mechanism active | `system_flow_projected_gate_probe.gd` (A/B render) | Windowed | gated vs forced differ where slide exercised; repeat identical; `SYSTEM_FLOW_PROJECTED_GATE_OK` | Pass (obstacle slide_diff=4641, repeat_diff=0) | 2026-06-12 | Agent |
| System map staleness warns | `system_flow_map_version` int vs `SYSTEM_FLOW_MAP_VERSION` (=1) | Editor + headless | pre-v1 maps warn on load; cleared by regen | Pass | 2026-06-12 | Agent + User |
| WaterSystem regen saves explicitly | `probes/water_system_rebake_probe.gd` | Windowed | check printed `save_error`/mtime (editor-only internal save no-ops headless) | Pass | 2026-06-12 | Agent |
| Duck-read flow content | `probes/water_system_flow_inspect_probe.gd` (diagnostic) | Headless OK | decoded flow, dead-zone fraction, magnitude PNG | Pass | 2026-06-12 | Agent |
| Seam regression on projected field | `probes/.../river_flowmap_seam_probe` pattern | Headless | seam expectations hold | Pass | 2026-06-12 | Agent |
| Ducks don't drift near obstacles | `Demo_obstacle_flow_test.tscn` (human) | Editor (windowed) | no boundary-shear drift; FLOW_ARROWS routes around rocks | Pass | 2026-06-12 | User |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug: dark FLOW_ARROWS cells beside rocks are solid-mask centers or legitimately decelerated flow (`|flow|` 0.02–0.13), not stilled open water — the view samples one texel per cell (implementation-plan §6.4). The 23–27° influence-zone angular floor on fresh system maps is quantization noise of the stilled low-magnitude ring, not the unfixed slide — do not chase it below the 35° gate.
- Scene/data/state to rule out: stale pre-v1 system maps (warn + regenerate); stale pre-v28 river bakes (river-refactor R1); a shared system bake making one scene read stale while the other is fresh (un-shared in R0 — each scene owns its bake).
- Research/source context: `addons/waterways/docs/research/river-research-citations.md`; industry validation in implementation-plan §2.
- Evidence the agent is misreading: an RT.3 mismatch on a phase claiming byte-identity may mean the baseline bake was stale — rebake the baseline at the pre-change commit before concluding regression.
- Quick falsifying check before patching: rebake-and-penetration-probe on the unpatched build to confirm a penetration symptom is real before changing solve constants.

## Automated Checks

- Probe pattern (NOT `--headless` for rebakes/captures — viewport readback required; diagnostic inspects are headless-OK), after the APPDATA/LOCALAPPDATA redirect:
  - `& $godotConsole --path $root --script "res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/<probe>.gd"`
- The mechanism gates (`system_flow_projected_gate_probe.gd`, `system_flow_compare_probe.gd`) live in `addons/waterways/probes/` and are documented in `../river-refactor/validation.md`. The RT-tool index lives there.
- Agent limitation note: local headless/editor-load checks prove parse/compile and probe behavior only — not visible editor, shader visuals, bake output, or runtime behavior.

## Godot Launch Instructions

Use the project's standard paths and the `.codex-research` APPDATA/LOCALAPPDATA redirect — see `../river-refactor/validation.md` "Godot Launch Instructions" (Godot 4.6.3 console at `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`; project root `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`). Use the windowed executable for rebake/capture probes and human-visible review.

## Human-Assisted Validation

- Request to user: open both demo scenes with the plugin enabled; inspect the river surface and FLOW_ARROWS / occupancy debug views; run `Demo_obstacle_flow_test.tscn` and watch duck behavior near the rocks.
- Plugin state required: waterways enabled; demo scene open.
- Console output / errors to relay back: any bake warnings; stale-map `push_warning`s.
- Visible behavior to relay back: arrows route around rocks; no interior/under-overhang water; ducks do not drift into boundary-shear paths near obstacles.
- Godot version/renderer: Godot 4.6.3, Forward+ (also Mobile/Compatibility for compile smoke).
- Expected result: pass on all of the above.
- Failure signs: arrows through rocks; water inside solids; ducks veering at obstacle boundaries.

## Recorded Results

Recorded result:

- Date: 2026-06-12
- Ran by: User (post-R2+R3 editor round) + Agent (mechanism gates)
- Godot version/renderer/device: Godot 4.6.3 windowed editor + console, Windows 11
- Command, scene, or workflow: both demo scenes inspected; obstacle scene duck watch; agent ran the slide-gate and RT.3 `enforce=all` gates on the regenerated v1 maps.
- Output or parser errors: none
- Visible result: scenes/debug views passed; no duck-drift near rocks
- Stable result marker: `SYSTEM_FLOW_PROJECTED_GATE_OK`; `SYSTEM_FLOW_COMPARE_OK` (`enforce=all`, influence p90 23.3°/26.9° < 35°)
- Pass/partial/fail: Pass
- Notes or follow-up: canonical record in `../river-refactor/validation.md` (2026-06-12 R2+R3 entry). Open user decision: system_flow occupancy stilling/wake damping.

## Manual Review Checklist

- [x] Acceptance criteria satisfied (penetration gates, mechanism gate, duck behavior).
- [x] Likely false premises raised (the angular-floor attribution correction).
- [x] Human-assisted results recorded (editor round, 2026-06-12).
- [x] Active code uses Godot 4.6+ APIs.
- [x] Editor-only/runtime boundaries preserved (bake vs shader vs buoyancy).
- [x] Generated resources explicit (`water_occupancy`, `flow_projected`, `system_flow_map_version`).
- [x] Visual output matches the spec (user editor round).
- [x] Flow direction, seams, masks, bounds checked.
- [x] Runtime sampling matches generated data (ducks read corrected flow).
- [ ] Performance budget formally recorded (deferred to river-refactor R7 for bake perf).
- [x] Known limitations documented (oversized-collider rims; angular floor; rebake non-determinism).
- [x] Shared research citations checked.
