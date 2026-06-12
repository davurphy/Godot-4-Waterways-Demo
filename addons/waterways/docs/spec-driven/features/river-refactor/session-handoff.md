# Session Handoff: River Refactor (Hardening + Refactor Track)

## Date

2026-06-12

## Current Focus

Execute the hardening/refactor track derived from the 2026-06-12 full-addon code audit. Phases R0, RT, and now R1 (dead-code purge + the v27→v28 signature bump, landed with explicit user go 2026-06-12) are implemented; R1's human-assisted gate is the immediate next step — the user must verify the editor stale warning, rebake both demo rivers and regenerate both system maps, then the agent runs the RT.1 diff and re-greens the suite on fresh v28 bakes. After that: R2+R3 (best merged).

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-refactor\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: In progress — **Phases R0, RT, and R1 implemented**; R1 (commits `1ca6109`..`717fdb6`, 2026-06-12) landed the dead-SDF-steering deletion, the three signature-gap keys, the occupancy serialization fix, the ripple-rider annotations, the small sweep, and the v27→v28 bump — **all saved river bakes are now intentionally stale**
- Highest-priority open task: R1's human-assisted gate — user verifies the editor stale warning fires, rebakes both demo rivers (Generate Flow & Foam Map) and regenerates both system maps, saves; then agent runs RT.1 diff vs the committed v27 baseline, re-runs the suite (should re-green on fresh bakes), commits the editor-modified files deliberately
- Last passing validation: 2026-06-12 post-R1 headless gate — stale detection demonstrated (`SYSTEM_FLOW_COMPARE_STALE` on both demo scenes, the v28 gate firing); rest of suite green (see validation.md newest Recorded Result); grep gate zero code refs to the deleted set
- Known failing or unproven check: RT.3 default mode exits 1 with `SYSTEM_FLOW_COMPARE_STALE` on both demo scenes — **expected and correct post-bump** until the rebake round; two pre-existing probe quirks recorded in validation.md (ripple_debug_parity_probe is windowed-only; pillow_inspector_wiring_probe has a stale version pin of 20). Older note — none open from RT — the bake un-sharing round closed the shared-resource issue (each scene now owns its system bake; Demo's lives in `waterways_bakes/Demo_28018/` because `_get_scene_bake_folder` diverts when `Demo/` holds another scene's bakes). En route, a stale-detector false positive was found and fixed (`water_system_manager.gd`: texture-path keys flip container between editor-embedded scene saves and bake-resource binding on fresh load — no longer compared). Pre-R2 RT.3 baseline on fresh scene-owned maps: influence-zone angular p90 25.5°/27.6° vs the 20° gate and an 8.5°/12.5° control floor (the Defect-1 signature, proven against freshly generated data).
- Next recommended action: run the R1 rebake round with the user (steps are in the latest chat message and the R1 matrix row): editor stale warning check → rebake both rivers → regenerate both system maps → save → agent runs RT.1 diff vs the v27 baseline and the full suite → commit editor-modified files → check off the R1 matrix row. Then start R2+R3 merged (the flow include is the structural fix for Defect 1; RT.3 `enforce=all` flipping green is R2's acceptance gate). The grep-everything rule caught another audit miss during R1.5: river_debug's nine `pillow_*` material-only uniforms are probe-asserted (kept, annotated).
- Packaging/artifact hygiene status: probe overlays written to `.codex-research/probe-out/` (excluded from packaging; safe to delete)
- Historical detail starts at: nothing archived yet

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- **`roadmap.md` is this track's canonical work plan** — phases R0–R8 with per-item details, line references, gates, sequencing, and the risk register. Work its checklists in place; note branch names next to phase headings.
- Use `tasks.md` for the cross-phase process checklist, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and the shared citations index only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-refactor\roadmap.md` (canonical work plan)
5. `addons\waterways\docs\spec-driven\features\river-refactor\tasks.md`
6. `addons\waterways\docs\spec-driven\features\river-refactor\review.md`
7. `addons\waterways\docs\spec-driven\features\river-refactor\validation.md`
8. `addons\waterways\docs\spec-driven\features\river-refactor\plan.md`
9. `addons\waterways\docs\spec-driven\features\river-refactor\spec.md`
10. `addons\waterways\docs\spec-driven\features\river-refactor\research.md`
11. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Complete the Adversarial Plan Review section of `plan.md` with the user, then start Phase R0 (any item) and/or RT.1 on a fresh branch from `main` (one branch per phase/item; clean tree).
- For Godot-specific implementation work, search current official Godot documentation and API references online before patching. Prefer official docs first, and record any source that affects implementation in `research.md` or `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`. The per-phase steps live in each roadmap phase's **Validation** block.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. The adversarial review already overturned several audit claims (see `spec.md` Resolved Questions); the standing rule from that miss: before deleting any shader uniform or function, grep shaders *and* probes *and* feature specs.

## What Changed This Session

Phase R1 session (2026-06-12, branch `river-refactor`, commits `1ca6109`..`717fdb6` + this docs commit):

- R1.1: deleted `apply_obstacle_avoidance_flow` + its shader load plumbing, the orphaned `obstacle_avoidance_flow_filter.gdshader` (+ `.uid`), the **ten** `RIVER_OBSTACLE_AVOIDANCE_*` constants (audit said nine) and their metadata/signature/settings rows; `obstacle_avoidance_algorithm` now reads `pressure_projection_free_slip_jacobi_with_normal_to_flow_blur_fallback`; Data Contract producers line fixed.
- R1.2: signature gains `river_edge_smooth_radius`/`_iterations`, `flow_speed_factor_max`, `flow_offset_noise_texture_path` (const path, not file hash — exported builds lack the source PNG, so a hash would false-positive stale at runtime).
- R1.3: `water_occupancy` added to property-list storage, `_enter_tree` binding, and `_has_unsaved_generated_textures`.
- R1.4: dated reserved-for-river-height-displacement comments at the ripple riders in both river shaders and `water_ripple_field.gd` (incl. `debug_visible`); nothing deleted.
- R1.5: dead-code sweep (see commit `eccdf73` for the full list). Key correction: river_debug's nine `pillow_*` material-only uniforms kept (asserted on the debug shader by `pillow_inspector_wiring_probe` + river-pillows spec contract); the six `wake_*` ones and `OCCUPANCY_CLIP_*` deleted; `apply_dotproduct`/`apply_foam`/`apply_normal_to_flow` lost dead resolution params (call sites updated).
- R1.6: one-line note in validation.md for `legacy_collision_only`/`curve_only`.
- R1.7: `RIVER_BAKE_SOURCE_SIGNATURE_VERSION` 27→28 with a dated comment; Data Contract reference updated. Stale detection demonstrated headless on both demo scenes.
- New scratch check: `.codex-research/filter_renderer_load_check.gd` (compiles filter_renderer.gd + loads all 19 pass-shader paths headless).

Previous implementation session (2026-06-12, branch `river-refactor`, all committed):

- Phase R0, all nine items, one commit each: readback diagnostics in bake warnings (R0.1); foam parity re-sync in `river_debug.gdshader` (R0.2); tracked bake renderer + `_exit_tree` abort so mid-bake scene close can't stick the bake flag (R0.3); gizmo connection sweep, `_commit_handle` no-change guard, `is_instance_valid` in `_set_progress_source` (R0.4); first-tile UV2 margin clamp (R0.5); Godot-3 leftover deletions (R0.6); code-side neutral `i_distmap` texture + `hint_default_black` comments (R0.7); blank-image stats skip + `fill_rect` (R0.8); probe hardening across four probes (R0.9).
- RT.1: new `probes/bake_hash_probe.gd` (hash + diff modes, per-channel deltas, diff-rect localization); demonstrated on known-good and known-bad pairs.
- RT.4: seed named `RIVER_FLOW_PRESSURE_SEED_COLOR`, comment pair, new `probes/flow_solve_seed_assert_probe.gd`.
- R0.7 follow-up: new `probes/distmap_neutral_binding_probe.gd` after the visual check proved unreachable (invalid-indicator stripes mask all debug views when validity fails).
- Repo hygiene: probes' `.uid` sidecars tracked; stale bake-resource UID references in `Demo.tscn`/`Demo_obstacle_flow_test.tscn` fixed; user's post-R0.5 rebakes committed as the new bake baseline (still signature v27).
- User-validated: foam parity (R0.2), mid-bake close recovery (R0.3), no-op click (R0.4) — Phase R0 gate closed.
- RT.3 (second implementation session, 2026-06-12): new `probes/system_flow_compare_probe.gd` — decodes river baked flow per texel, transforms to world XZ via the same per-triangle UV1 basis `system_flow.gdshader` builds, compares against `_sample_system_map` (the duck-read path); three zones (control/influence/boundary), control gate always on, influence gate (`enforce=all`) is R2's gate for `flow_projected` rivers; stale-map detection via `_get_stale_source_warning`; height-channel filter excludes cross-surface top-down samples. Demonstrated known-good (control p90 8.8° < 10°), known-bad (influence p90 25.8° > 15° flagged), and stale detection (obstacle scene). Deliberately does NOT replicate the slide/force pipeline — no third hand-synced flow copy.
- Bake un-sharing round (same day, after RT.2/RT.3): the user gave each demo scene its own system bake (commits `fed4967a`, `0bbada9`) — this surfaced that regeneration saves in place into a shared resource path, and a stale-detector false positive: the texture-path metadata keys flip container between editor-embedded scene saves and fresh-load bake-resource binding, so editor-generated maps always read stale at runtime. Fixed in `water_system_manager.gd` `_get_source_river_metadata_changed_key` (commit `2050789`): the two path keys are diagnostics-only now. Orphaned shared bake removed; the obstacle-constraints inspect probe repointed.
- RT.2 (same session): `probes/debug_view_capture_probe.gd` extended — `views=parity` fixed 13-view set, headless diff mode (`a=`/`b=`, byte-identity fast path, per-channel max/mean deltas, `CAPTURE_DIFF_OK`), and two determinism fixes: `Engine.time_scale=0` at `_initialize` (boot-time; freezing later pins each run at a different shader TIME) and fixed-seed mode on hterrain detail layers (grass RNG is time-randomized per load — diagnosed with a diff heatmap showing only the banks differing). Result: 26/26 parity PNGs byte-identical across two independent windowed runs, both run by the agent on this machine (windowed agent runs worked this session). R3's gate can demand byte-identity for same-session before/after pairs.

## Current Changes Summary

- Phases R0 + RT validated; Phase R1 implemented (signature v28, all R1 boxes checked) with the headless gate passed; saved bakes intentionally stale. Next: user rebake round, then R2+R3.

## Historical Change Log

- 2026-06-12 (scaffold session): seven feature-folder documents created around the pre-existing `roadmap.md` (docs only).
- 2026-06-12 (earlier): `roadmap.md` written from the audit and hardened by adversarial review (commit `c34cd9a` "refactor notes" predates this folder scaffold).

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Keep `roadmap.md` as the canonical item-level work plan; templates wrap it rather than duplicate it | The roadmap's checklists, line references, and gates are already the verified source of truth; duplicating them invites drift — the exact failure mode this track exists to kill | Check items off in the roadmap; record results in `validation.md` |
| One track-level spec/plan now; R6 and R7 get their own spec/plan/validation later | Constitution rule 12 requires per-phase docs only for the heavyweight phases | Write them before R6/R7 start; R7 also needs the compute decision recorded |

## Current State

Implementation status:

- In progress — Phases R0 and RT complete and validated; R1–R8 not started

Spec/plan status:

- Research: Complete (audit + adversarial review; `research.md` records the outcome)
- Spec: Accepted in practice (R0 executed against it); Resolved Questions table grew the R0.7 reachability finding
- Plan: Current — Adversarial Plan Review section still not formally completed with the user (work proceeded with per-item user validation instead)
- Tasks: R0 and RT closed; see `tasks.md` Current Truth
- Validation: Matrix live — R0 row Pass, RT rows Pass (RT.1–RT.4 all demonstrated), R2 row carries the recorded pre-R2 baseline; recorded results current
- Review: No formal phase review held yet; `review.md` still scaffold + premise review

Validation status:

- Automated: eight markers green — `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK`, `BAKE_HASH_PROBE_OK`/`BAKE_HASH_COMPARE_OK`, `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, `SYSTEM_FLOW_COMPARE_OK`, `CAPTURE_DIFF_OK`; the only intentional red is RT.3 `enforce=all` (pre-R2 Defect-1 baseline: influence p90 25.5°/27.6° > 20°)
- Human-assisted: R0.2/R0.3/R0.4 confirmed by user 2026-06-12 (Godot 4.6.3 windowed)
- Shader: foam parity confirmed visually post-rebake; 3-renderer compile sweep deferred to R3's gate
- Editor: mid-bake close + no-op click confirmed
- Visual: Foam Mix vs surface confirmed; R0.7 visual route unreachable (probe instead)
- Runtime: untouched (R4 territory)
- Performance: untouched (R4/R7 territory)
- Manual: n/a

## Important Context

- The track's operating rules (from `roadmap.md`): one branch per phase/item from `main`; all bake-content changes ride the single R1 v27→v28 signature bump; extraction phases prove byte-identity via RT.1; pixel-parity gates are windowed/human-assisted (constitution rule 8); grep shaders + probes + feature specs before deleting any shader uniform/function.
- Hard sequencing: R0.2 before R3; RT.1 before R1/R5/R6 gates; RT.2 before R3; RT.3 before R2; R5 before R6; R6 before R7; R8 after R1. R2+R3 are best merged.
- R0.5 knowingly changes baked content without a signature bump (hotfix exception, retroactively covered by v28). System maps have **no** staleness mechanism until R2.4.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`.
- Known Godot 4.6+ detail: two `UPDATE_ONCE` SubViewports in one frame render in non-dependency order (the Defect-6 mechanism) — constrains R4.1 and R7.1; no texture hint can express the distmap neutral ≈ (0.75, 0.25, 0.0, 0.5).
- Misunderstanding risk to raise directly: R4.1 makes the ripple sim slower-but-correct under load *by design* — a reduced propagation rate at low FPS is the accepted trade, not a regression.

## Artifact Hygiene

- Scratch folders or temporary projects created (all under `.codex-research\`, excluded from packaging, safe to delete): `capture_diff_fixture.gd` + `capture-diff-fixture/` (RT.2 known-bad demo), `capture_diff_heatmap.gd` (diff visualizer), `stale_metadata_inspect.gd` (stale-warning diagnosis), `probe-out/rt2/` (RT.2 parity capture PNGs), `filter_renderer_load_check.gd` (R1 filter-renderer compile/shader-path check — useful again at R5.1)
- Generated bakes/resources created: scene-owned system bakes committed at `waterways_bakes/Demo_28018/` and `waterways_bakes/Demo_obstacle_flow_test/` (user editor rounds); the formerly shared `waterways_bakes/Demo/WaterSystem.water_system_bake.res` was removed as orphaned
- Active files mirrored into scratch validation: n/a
- Files/folders that must be excluded from packaging: `.codex-research\` (standing), RT.2 capture PNGs/baselines
- Files/folders safe to delete now: the `.codex-research` scratch items above once RT results are no longer being re-demonstrated

## Known Risks and Open Issues

- The full risk register lives in `roadmap.md` (Risks). Dominant: R3 extraction parity, R6's 21 abort points, R7's ordering hazard, the R1.4 class of "dead code that probes/specs consume".
- Open decisions: R7-vs-feature-Phase-5 compute (gate); R2/R3 merge-or-separate (decide at R1).
- Possible false premise to verify before implementing: each R0 item's validation step doubles as its falsifier — when cheap, run it on the unpatched build first (e.g., confirm Foam Mix actually diverges before patching R0.2).

Relevant audit sections:

- `addons\waterways\docs\audit\waterways-code-audit-2026-06-12.md`: Prioritized Recommendations 1–17; Defects 1–11; §§1–10 — every roadmap item carries its audit refs inline.

## Blockers

- Adversarial Plan Review (`plan.md`) not yet completed with the user — required before code changes.
- Local Godot editor/visual access is unreliable for the agent: pixel-parity and editor-interaction gates are human-assisted by design. Local parser/headless editor-load signal is not a substitute for visible editor/runtime validation.
- R7 is blocked on the recorded compute decision; R6/R7 are blocked on their own spec/plan/validation files.

## Files To Inspect Before Editing

- `addons/waterways/docs/spec-driven/features/river-refactor/roadmap.md` (always — it is the work plan)
- Per phase, the files named in `plan.md` "Files to Change" — chiefly `river_manager.gd`, `river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader`, `system_map_renderer.gd`, `water_helper_methods.gd`, `filter_renderer.gd`, `river_gizmo.gd`, `plugin.gd`, `water_ripple_field.gd`, `buoyant_manager.gd`, `water_system_manager.gd`, `probes/*`

## Commands or Checks Used

See **Validation Commands** below for the full RT.1–RT.4 invocations (all use the `.codex-research` profile redirect). Latest sweep (2026-06-12, after the bake un-sharing round): RT.3 report mode exit 0; RT.3 `enforce=all` exit 1 (expected pre-R2); `BAKE_HASH_PROBE_OK`, `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK` all exit 0.

Result summary:

- Full headless suite green on the current scenes/bakes; RT.2 byte-identity demonstrated windowed (26/26 PNGs); the only intentionally red check is RT.3 `enforce=all` (the pre-R2 Defect-1 baseline).

## Next Tasks

- [x] RT.3 — system-vs-river flow comparison probe (gates R2; headless-able). *Done 2026-06-12: `probes/system_flow_compare_probe.gd`; commands in `validation.md` Automated Checks.*
- [x] RT.2 — pixel-parity capture harness on `debug_view_capture_probe.gd` (gates R3). *Done 2026-06-12: parity preset + diff mode + determinism fixes; 26/26 byte-identical across runs; commands in `validation.md` Automated Checks.*
- [x] R1 — dead-code purge + single v27→v28 signature bump. *Implemented 2026-06-12 with user go; headless gate passed (stale detection demonstrated).*
- [ ] R1 human-assisted gate: user editor stale check + rebake both rivers + regenerate both system maps; agent RT.1 diff vs v27 baseline, suite re-green, commit editor files, close the R1 matrix row.
- [ ] R2+R3 (merged) — system_flow projected-flow correctness via the shared flow include; RT.3 `enforce=all` flipping green is the acceptance gate.
- [x] (User, editor) Un-share the system bake. *Done 2026-06-12: each scene owns its bake; old shared resource removed; RT.3 report mode exits 0 with no stale warnings; full headless suite green. Also fixed the stale detector's texture-path false positive (see validation.md).*

## Do Not Do Yet

- R6 or R7 — blocked on their own spec/plan/validation files; R7 additionally on the recorded compute decision.
- Any deletion of the ripple-displacement interface (`ripple_height_at_*`, `i_ripple_*`) — R1.4 annotates only; deletion requires a per-uniform pass updating the river-ripples spec contract list and all asserting probes.
- Any "improvement" to audit-verified-clean areas (§10): f16 solve bracketing, atlas column clamps, ripple material ownership, undo registration order, export-safety.
- A second signature bump — v27→v28 (R1.7) is the only one; later bake-content changes must ride it or be explicitly justified.

## Notes for the Next Agent

This track is unusual in that the planning is *finished and verified* — the roadmap was adversarially reviewed against source at cited line numbers, and the corrections (R1.4 live interface, R0.6 no-op ordering, R4.2 non-drop-in API) are already baked in. Your job is execution discipline, not re-planning: pick up the next unchecked roadmap item, fix, run the phase's validation block (pasting human-assisted steps into chat), record results in `validation.md`, check the box in `roadmap.md`, update this handoff. Resist re-deriving the audit; if you find evidence a roadmap item's premise is wrong, that's worth raising — the review missed exactly one thing (R1.4) and the grep-everything rule exists because of it.

Session lessons (2026-06-12), in force going forward:

- Work has been on the `river-refactor` branch (not per-item branches from `main`) with the user's acquiescence; keep that unless told otherwise.
- Debug-view visual checks are masked by the magenta/cyan invalid-flowmap stripe indicator (`river_debug.gdshader:1098`) whenever the change also fails the validity gate — use binding/content probes for those (model: `distmap_neutral_binding_probe.gd`).
- Run an actual headless probe after editing shared scripts, not just `--check-only` — two type-inference parse errors (`max()`, Color subscript) were only caught by real runs.
- Rebakes are not byte-deterministic (GPU variance): RT.1 byte-identity gates apply to no-rebake refactors only (R5/R6); rebake comparisons show broad small deltas in filter-derived textures.
- PowerShell 5.1: no embedded double quotes in `git commit -m` here-strings.
- The user's editor sessions modify the working tree (bake .res rewrites, scene saves with embedded image data, generated `.uid` sidecars) — diff and commit these deliberately after human-assisted validation rounds; verify scene `ext_resource` uid lines survive editor saves.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so the agent does not alter the user's normal Godot editor profile.

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

## Validation Commands

After the APPDATA/LOCALAPPDATA redirect from Godot Launch Instructions above:

```powershell
# RT.1 — bake content hash/diff (markers: BAKE_HASH_PROBE_OK / BAKE_HASH_COMPARE_OK)
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/bake_hash_probe.gd" -- bake=res://waterways_bakes/Demo/Water_River.river_bake.res
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/bake_hash_probe.gd" -- a=res://path_a.res b=res://path_b.res

# RT.3 — system-vs-river flow compare (marker: SYSTEM_FLOW_COMPARE_OK)
# report mode (control gate only; green pre-R2 when saved maps are fresh):
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/system_flow_compare_probe.gd"
# R2 gate mode (influence zone enforced for projected rivers; red pre-R2 by design):
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/system_flow_compare_probe.gd" -- enforce=all

# RT.4 — cross-language pressure-seed assertion (marker: FLOW_SOLVE_SEED_ASSERT_OK)
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/flow_solve_seed_assert_probe.gd"

# RT.2 — pixel-parity capture (windowed, no --headless) + diff (headless; marker: CAPTURE_DIFF_OK)
& $godotConsole --path $root --script "res://addons/waterways/probes/debug_view_capture_probe.gd" -- views=parity stations=2 label=before out=res://.codex-research/probe-out/rt2
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/debug_view_capture_probe.gd" -- a=res://.codex-research/probe-out/rt2/before b=res://.codex-research/probe-out/rt2/after
```
