# Session Handoff: River Refactor (Hardening + Refactor Track)

## Date

2026-06-12

## Current Focus

Execute the hardening/refactor track derived from the 2026-06-12 full-addon code audit. Phases R0, RT, R1, **R2, and R3** are complete and validated (R2+R3 landed merged 2026-06-12 on `river-refactor`: three shared shader includes, the system_flow Defect-1 fix, the system-map version int, regenerated v1 system maps; all gates green). Next: a short user editor round (visual eyeball + duck drift + `.uid` sidecars), then **R8 (docs coherence)** can interleave; R4/R5 absorb idle time. R6/R7 stay blocked on their own spec/plan/validation files.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-refactor\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: In progress — **Phases R0, RT, R1, R2, and R3 complete and validated**. R2+R3 (commits `c34b136`..`a2ec75c` + docs, 2026-06-12, all agent-run including the windowed rounds) landed: `river_flow_common.gdshaderinc` (flow family, consumed by river/debug/system_flow), `river_surface_common.gdshaderinc` (~620 shared surface lines, river/debug only), `flow_pack.gdshaderinc` (canonical flow codec, ten clones converted), the Defect-1 fix (system_flow gates the slide on `i_flow_projected` + stagnation fade + shared force), R2.4's `SYSTEM_FLOW_MAP_VERSION` staleness int, R3.3 revert-table deletion (reverts now read live shader defaults), R3.4 filter-default alignment, R3.5 occupancy-const centralization, regenerated v1 system maps
- Highest-priority open task: short user editor round (eyeball surface/debug views — RT.2 says byte-identical; watch ducks near the obstacle rocks; save scenes so the new `.gdshaderinc`/probe `.uid` sidecars generate — commit them). Then R8 (docs coherence); R4/R5 absorb idle time
- Last passing validation: 2026-06-12 post-R2+R3 — full suite green **including** RT.3 `enforce=all` (23.3°/26.9° < recalibrated 35°), `SYSTEM_FLOW_PROJECTED_GATE_OK` (the new R2 mechanism gate), `CAPTURE_DIFF_OK files=26` (whole-phase byte-identity), 3-renderer smoke, `REVERT_DEFAULT_CHECK_OK`, `PILLOW_INSPECTOR_WIRING_PROBE_OK` (era pin 20→28, first full green)
- **Major execution finding (attribution correction):** the "Defect-1 signature" (pre-R2 influence p90 25.5°/28.9°) was NOT the slide — A/B rendering (slide gated vs forced) measures the slide at 0 differing texels on Demo and 4.6k texels at mean 3.3° on the obstacle scene; the 23–27° floor is sampling/quantization noise of the stilled low-magnitude ring and survives the (correct, landed) fix. RT.3's influence gate is now a 35° gross-divergence guard; the mechanism is gated by `probes/system_flow_projected_gate_probe.gd` (windowed A/B). Full detail in validation.md's 2026-06-12 R2+R3 entry
- Second execution finding: `ShaderMaterial.property_can_revert/get_revert` never worked for the internal river material (remap cache only fills when the material itself is inspected) — the deleted revert table was the only working source; replacement calls `RenderingServer.shader_get_parameter_default` directly. That API returns null under the headless dummy renderer, so revert checks are windowed
- Known failing or unproven check: none failing. Pending human-assisted: duck-drift observation near obstacles (expected change small, obstacle scene only) and a post-extraction visual eyeball. Pre-existing quirk remaining: ripple_debug_parity_probe is windowed-only (dummy renderer headless)
- Packaging/artifact hygiene status: probe overlays + RT.2 capture sets under `.codex-research/probe-out/` (excluded from packaging; the `rt2-r3` set is this phase's parity evidence — keep until the user round closes). `.codex-research/r1-baseline/` deleted (R1 evidence recorded). **Hazard noted in validation.md:** `river_obstacle_projection_rebake_probe.gd` saves river bakes in place — never run casually
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

- Run the pending user editor round (exact steps in **Next Tasks**), commit the resulting `.uid`/scene changes deliberately, then pick up R8 (or R4/R5 items) per the roadmap.
- For Godot-specific implementation work, search current official Godot documentation and API references online before patching. Prefer official docs first, and record any source that affects implementation in `research.md` or `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`. The per-phase steps live in each roadmap phase's **Validation** block.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. The adversarial review already overturned several audit claims (see `spec.md` Resolved Questions); the standing rule from that miss: before deleting any shader uniform or function, grep shaders *and* probes *and* feature specs.

## What Changed This Session

Phase R2+R3 merged session (2026-06-12, branch `river-refactor`, commits `c34b136`..`a2ec75c` + docs):

- R3.1a (`c34b136`): `river_flow_common.gdshaderinc` extracted (15 flow uniforms, boundary samplers, `i_flow_projected`, EPSILON, slide/force family) — scripted verbatim move from river.gdshader (`.codex-research/r3_extract.ps1`); compiled uniform sets proven unchanged.
- R2.1–R2.3 (`c933b3d`): system_flow consumes the flow include — slide gated on `i_flow_projected`, stagnation fade rides in, shared `contextual_flow_force`; renderer plumbs the flag + renamed boundary samplers; invalid-flowmap branch made behavior-identical via neutral vec4s.
- R3.1b (`487e678`): `river_surface_common.gdshaderinc` (~620 lines: 80 uniforms, pillow/wake/ripple/FlowUVW families, shared `vertex()`); six debug deltas absorbed as comment-only/semantically-identical (documented in the commit message); genuinely divergent debug instrumentation stayed local (`eddy_line_context_search` support_mode variant etc.).
- R3.2 (`2a3f1c1`): `flow_pack.gdshaderinc` codec; ten clone sites converted (river/debug/system_flow/lava/3 filters + shared vertex); float-form bit-safety argued and proven by capture byte-identity; GDScript + flow_solve_common mirrors annotated, not converted.
- R2.4 (`963327f`): `SYSTEM_FLOW_MAP_VERSION` (=1) in WaterSystemBakeData, written into `bake_settings`, checked by `_get_stale_source_warning` + runtime `push_warning` (stable-int comparator, never paths). Demonstrated: both v0 maps flagged, regen clears.
- Gate restructure (`4429f8c`): the attribution correction (see Current Truth); new `probes/system_flow_projected_gate_probe.gd`; RT.3 `max_influence_deg` 20→35 + `sharp_deg` exclusion; both demo system maps regenerated to v1 via the (now scene-parameterized) windowed rebake probe and committed.
- R3.3 (`7107774`): revert table deleted; reverts read `shader_get_parameter_default` directly (the Material fallback was discovered dead — see Current Truth); never-tabled params gain working reverts.
- R3.4+R3.5 (`a2ec75c`): obstacle filter defaults aligned to canonical (support 0.22/0.82, facing 0.35/0.92; `*_uv` annotated as unit-converted dummies); `OCCUPANCY_SPEED_RAMP_FULL` single-sourced in the surface include with five probes parsing it via `WaterHelperMethods.get_occupancy_speed_ramp_full()`; system_map_renderer's ten fallback literals replaced by pass-throughs (include default applies on null); pillow_inspector_wiring_probe pin 20→28 + retargeted to the new wiring (now windowed-only).
- Incident (resolved): an exploratory headless run of `river_obstacle_projection_rebake_probe` rewrote both river bakes in place; restored from HEAD, verified by hash + RT.3 before any commit.

Previous session (Phase R1, 2026-06-12, commits `1ca6109`..`717fdb6` + docs):

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

- Phases R0 + RT + R1 + R2 + R3 complete and validated (signature v28; system maps v1; three shared shader includes; all suite gates green). Next: user editor round, then R8; R4/R5 absorb idle time.

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

- In progress — Phases R0, RT, R1, R2, R3 complete and validated; R4/R5/R8 ready; R6/R7 blocked on their own docs

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

- Scratch folders or temporary projects created (all under `.codex-research\`, excluded from packaging): `capture_diff_fixture.gd` + `capture-diff-fixture/`, `capture_diff_heatmap.gd`, `stale_metadata_inspect.gd`, `probe-out/rt2/` and `probe-out/rt2-r3/` (parity capture PNGs — rt2-r3 is the R3 byte-identity evidence; keep until the user round closes), `filter_renderer_load_check.gd` (reusable; R5.1), `river_shader_load_check.gd` + `uniform_set_compare.gd` (R3 load/uniform-set checks, reusable), `revert_default_check.gd` (R3.3 windowed revert check, reusable), `scene_render_smoke.gd` (3-renderer smoke, reusable), `shader_func_diff.ps1` + `shader_func_diff_detail.ps1` + `r3_extract.ps1` (the R3 extraction tooling, kept for reference), `system_map_diff_check.gd` (system-bake image diff)
- Generated bakes/resources created: regenerated v1 system bakes committed in place (`waterways_bakes/Demo_28018/`, `waterways_bakes/Demo_obstacle_flow_test/`); river bakes untouched (one accidental overwrite restored from HEAD — see validation.md hazard note)
- Active files mirrored into scratch validation: n/a
- Files/folders that must be excluded from packaging: `.codex-research\` (standing), capture PNGs/baselines
- Files/folders safe to delete now: `probe-out/rt2/` (RT.2-era captures; superseded by rt2-r3); the .ps1 extraction tooling once R3 review interest ends. Deleted this session: `r1-baseline/`, `r3-pre/`, one-off diagnosis scripts

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

- [x] RT.3 — system-vs-river flow comparison probe (gates R2; headless-able). *Done 2026-06-12.*
- [x] RT.2 — pixel-parity capture harness (gates R3). *Done 2026-06-12.*
- [x] R1 — dead-code purge + single v27→v28 signature bump. *Gate closed 2026-06-12.*
- [x] R2+R3 (merged) — shared includes + system_flow projected-flow fix + system-map version int. *Done 2026-06-12; original RT.3 numeric gate found misattributed and restructured (see validation.md); all gates green.*
- [x] (User, editor) Un-share the system bake. *Done 2026-06-12.*
- [ ] (User, editor) Post-R2+R3 round: open both demo scenes, eyeball the river surface + a few debug views (RT.2 proved byte-identity — this is the rule-8 human confirmation), run the obstacle scene and watch ducks near the rocks, save scenes, then commit the newly generated `.uid` sidecars (`flow_pack.gdshaderinc.uid`, `system_flow_projected_gate_probe.gd.uid`, possibly others).
- [ ] R8 — docs coherence (architecture-and-features rewrite; Data Contract gains `system_flow_map_version`, R8.2).
- [ ] R4 / R5 — independent items as time allows (R5.3 pairs with the now-done R3.5).

## Do Not Do Yet

- R6 or R7 — blocked on their own spec/plan/validation files; R7 additionally on the recorded compute decision.
- Any deletion of the ripple-displacement interface (`ripple_height_at_*`, `i_ripple_*`) — R1.4 annotates only; deletion requires a per-uniform pass updating the river-ripples spec contract list and all asserting probes.
- Any "improvement" to audit-verified-clean areas (§10): f16 solve bracketing, atlas column clamps, ripple material ownership, undo registration order, export-safety.
- A second signature bump — v27→v28 (R1.7) is the only one; later bake-content changes must ride it or be explicitly justified.

## Notes for the Next Agent

This track is unusual in that the planning is *finished and verified* — the roadmap was adversarially reviewed against source at cited line numbers, and the corrections (R1.4 live interface, R0.6 no-op ordering, R4.2 non-drop-in API) are already baked in. Your job is execution discipline, not re-planning: pick up the next unchecked roadmap item, fix, run the phase's validation block (pasting human-assisted steps into chat), record results in `validation.md`, check the box in `roadmap.md`, update this handoff. Resist re-deriving the audit; if you find evidence a roadmap item's premise is wrong, that's worth raising — the review missed exactly one thing (R1.4) and the grep-everything rule exists because of it.

Session lessons (2026-06-12), in force going forward:

- Work has been on the `river-refactor` branch (not per-item branches from `main`) with the user's acquiescence; keep that unless told otherwise.
- (2026-06-12, R2+R3) `RenderingServer.shader_get_parameter_default` returns null under the headless dummy renderer — revert-default checks run windowed. `ShaderMaterial.property_can_revert/get_revert` never works for materials that are not themselves inspected (remap cache). Verify a numeric gate's mechanism by A/B before trusting its threshold (the slide misattribution would have shipped a meaningless gate). `river_obstacle_projection_rebake_probe` saves river bakes in place — check what a probe writes before running it. Windowed agent console runs handle captures, system-map regeneration, and revert checks fine.
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
# report mode (control gate only):
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/system_flow_compare_probe.gd"
# influence gate mode (gross-divergence guard, 35 deg; green since R2):
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/system_flow_compare_probe.gd" -- enforce=all

# R2 mechanism gate — A/B system flow renders (windowed; marker: SYSTEM_FLOW_PROJECTED_GATE_OK)
& $godotConsole --path $root --script "res://addons/waterways/probes/system_flow_projected_gate_probe.gd"

# RT.4 — cross-language pressure-seed assertion (marker: FLOW_SOLVE_SEED_ASSERT_OK)
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/flow_solve_seed_assert_probe.gd"

# RT.2 — pixel-parity capture (windowed, no --headless) + diff (headless; marker: CAPTURE_DIFF_OK)
& $godotConsole --path $root --script "res://addons/waterways/probes/debug_view_capture_probe.gd" -- views=parity stations=2 label=before out=res://.codex-research/probe-out/rt2
& $godotConsole --headless --path $root --script "res://addons/waterways/probes/debug_view_capture_probe.gd" -- a=res://.codex-research/probe-out/rt2/before b=res://.codex-research/probe-out/rt2/after
```
