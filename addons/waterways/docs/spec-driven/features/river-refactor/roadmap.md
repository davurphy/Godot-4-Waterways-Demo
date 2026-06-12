# River Refactor Roadmap

Status: Draft — not started
Date: 2026-06-12
Source: `docs/audit/waterways-code-audit-2026-06-12.md` (full-addon audit, bake signature v27), hardened by an adversarial code review (2026-06-12) in which every load-bearing claim below was verified against source at the cited lines. Where the audit and the code disagreed, the code won — those corrections are noted inline.
Related: `docs/spec-driven/features/river-future/Roadmap.md` (feature roadmap, Phases 0–5), `docs/spec-driven/00-constitution.md`

This document turns the 2026-06-12 code audit into an ordered, dependency-aware work plan. It is a *hardening and refactor* track, complementary to the feature roadmap in `river-future/Roadmap.md`: the audit's conclusion is that the next feature should not land on top of the current shape of `river_manager.gd`, the hand-synced shaders, or the unfixed defects. Phases R0–R3 should land before (or interleaved with) feature-roadmap Phase 1–2 work.

Per constitution rule 12, the heavyweight phases (R6 bake-pipeline extraction, R7 GPU solve) must get their own `spec.md`/`plan.md`/`validation.md` in this folder before implementation starts. The lighter phases can be tracked directly against the checklists here, with results recorded in a `validation.md` added alongside this roadmap.

---

## Goals

1. Fix all eleven verified defects from the audit, highest-value first.
2. Replace synchronization-by-hand (shader mirrors, constant echoes, revert tables) with single-source-of-truth mechanisms so the four observed drift failures cannot recur.
3. Shrink `river_manager.gd` (3,807 lines) by extracting the bake pipeline and metadata assembly, per the constitution's module-size rule.
4. Remove verified-dead code (the SDF steering set) with a single, deliberate signature bump.
5. Restore doc–code coherence (`architecture-and-features.md`, Data Contract, feature-folder template compliance).
6. Capture the audited bake/runtime performance wins without destabilizing the bake contract.
7. Build the validation tooling the phase gates depend on, before the phases that depend on it (the hash/parity/comparison probes the gates name do not exist today — see Phase RT).

## Non-Goals

- No new user-facing features. Flow-advected displacement, ripple displacement *implementation*, foam kernels, etc. stay on the feature roadmap.
- No change to the data contract's channel semantics (slugs, neutrals, AABB registry) — the audit verified these are correct; they are load-bearing and stay frozen.
- No touching `zylann.hterrain` beyond the already-inert importer stubs.
- Areas the audit verified clean (§10) get no speculative "improvement": f16 solve bracketing, atlas column clamps, ripple material ownership, undo registration order, editor/runtime export-safety.
- No deletion of the declared ripple-displacement interface (`ripple_height_at_*`, `i_ripple_displacement_strength`, `i_ripple_refraction_strength`, `i_ripple_impulse_texture`). The audit called it dead; review found it is not: the debug shader samples the impulse texture (`river_debug.gdshader:899,984`), probes assert the plumbing, and the `river-height displacement` feature folder designs against the rest (see R1.4).

## Operating Rules for Every Phase

- **One branch per phase** (or per item for R0/RT), cut from `main`. No phase starts on a dirty tree.
- **Signature discipline:** every change that alters baked content or bake inputs lands inside a phase that bumps the bake signature exactly once (R1 owns the v27→v28 bump). Content-changing fixes that ship in other phases must either ride that bump or explicitly document why stale-bake detection is acceptable. This discipline covers river bakes only — system maps have no staleness mechanism (see R2.4).
- **Behavior-preserving refactors prove it:** extraction phases (R5, R6) must show byte-identical bake output via the RT.1 hash-compare tooling before and after.
- **Visual validation is human-assisted** (constitution rule 8): each phase's checklist names the exact scene, steps, and expected visuals to request from the user; results recorded in this folder's `validation.md`. Rendered-pixel capture probes require a window in this workspace (headless rendering is unreliable per the constitution's own caveat) — treat all pixel-parity gates as windowed/human-assisted by default.
- **Before deleting any shader uniform or function, grep shaders *and* probes *and* feature specs.** The audit's one "verified dead" miss (R1.4) was caught only because probes assert the interface.

---

## Phase R0 — Defect Hotfixes (hours each, except R0.7; no signature bump)

> Branch: `river-refactor` (2026-06-12). All nine items implemented, one commit each. Headless validation passed (probe markers, parse checks — see `validation.md`); the phase's human-assisted checks (foam parity, null-distmap visuals, mid-bake close, click-without-drag) are pending.

Small, independent, high-confidence fixes. Each can be its own commit; none changes baked content except R0.5 (see its note). Audit refs: Prioritized Recommendations 1–8; Defects 2, 3, 4, 5, 8, 9, 10, 11.

- [x] **R0.1 Surface readback diagnostics.** Include `last_readback_error` in `_filter_output_is_valid`'s warning text. One line; currently 27 precise diagnoses are discarded. (`filter_renderer.gd` / `river_manager.gd` warning site.)
- [x] **R0.2 Foam default parity (Defect 2).** Align `foam_amount` (2.0 vs 1.0) and `foam_smoothness` (0.3 vs 1.0) between `river.gdshader:55,61` and `river_debug.gdshader:103,109`; re-sync the drifted eddy-line foam term — **river's version wins** (`river.gdshader:1074`, bias blend `(0.25 + eddy_fleck_noise * 0.75)`, smoothstep 0.25–0.78) over `river_debug.gdshader:1458` (raw noise, 0.35–0.85). Root cause (null-for-default in `_sync_debug_material_from_visible_material`, `river_manager.gd:1487`) is structurally fixed by R3; this phase only makes the two shaders agree. **Hard prerequisite for R3** — the include extraction must move agreed code, not pick winners mid-move.
- [x] **R0.3 Stuck bake flag (Defect 3).** On `tree_exiting`, reset `_flowmap_bake_in_progress` and free the tracked renderer so a mid-bake scene close doesn't permanently swallow `bake_texture()` requests (`river_manager.gd:1656` guard).
- [x] **R0.4 Gizmo/plugin lifecycle (Defects 8, 9, 10).**
  - Disconnect the per-gizmo `river_changed` callable when the gizmo is freed (`river_gizmo.gd:431-433`).
  - Add the no-change guard to `_commit_handle` so click-without-drag doesn't push "Change River Shape" with `valid_flowmap: false` (`river_gizmo.gd:347-380`; copy the pattern from `ripple_gizmo.gd:100-105`). Exact-equality comparison of the curve-state dictionaries suffices — click-without-drag produces bitwise-identical state; no epsilon needed.
  - Use `is_instance_valid` in `plugin.gd:363-369` `_set_progress_source`.
- [x] **R0.5 First-tile margin fix (Defect 4).** In `_add_uv2_column_continuation_margins` (`water_helper_methods.gd:1737-1747`), copy the tile's *top* strip when `previous_step == step_index` (mirror of the correct last-tile case; fix direction verified by walking the index math). **Note:** this changes baked content for multi-tile rivers without a signature bump — existing bakes stay "valid" but carry the bug. Acceptable for a hotfix; the R1 signature bump retroactively invalidates them. If R1 lands in the same release window, prefer folding this in there.
- [x] **R0.6 Godot-3 leftovers (Defect 5).** Delete `reorder_params` and `last_prefix_occurence` (the `Array.invert()` crash at `water_helper_methods.gd:1800` plus the `"Texture"` vs `"Texture2D"` dead match). **`reorder_params` has a live caller — remove the call at `river_manager.gd:601` too** and accept the resulting inspector ordering (the call has been a silent no-op since the Godot 4 port, so ordering does not actually change). Delete `sum_array` (verified: zero callers).
- [x] **R0.7 `i_distmap` neutral default (Defect 11) — half-day, not a hint swap.** The neutral texel is ≈ (R=0.75, G=0.25, B=0.0, A=0.5), derived from the decode at `river.gdshader:950-953` (`distance = (1-R)*2`, `pressure = G*2`, `grade_energy = B`, `bend_bias = A*2-1`) and the shader's own invalid-fallback constants (lines 963-966). **No built-in hint can express this** — Godot offers only `hint_default_white/black/transparent`, and black would set bend_bias to −1 and distance to max. Fix: create a small neutral `ImageTexture` code-side and bind it to `i_distmap` on both materials whenever `dist_pressure` is null (the same sites that bind the real texture: `_enter_tree`, bake load, bake finalize). Replace `hint_default_white` (`river.gdshader:127`) with `hint_default_black` plus a comment that the code-side binding is the real default. Mirror in `river_debug.gdshader`. If R3 is imminent, land this there with the shared include instead.
- [x] **R0.8 Bake CPU micro-fixes.** Skip `_get_collision_map_stats` on the guaranteed-blank image; use `fill_rect` in `create_downstream_baseline_flow_image` instead of per-pixel `set_pixel`.
- [x] **R0.9 Probe hardening (audit §9).** Null-checked typed loads + success markers + `out=` support in both flow-arrow probes; fix `flow_arrow_neutral_cells_probe`'s missing 4-point sub-cell fallback (mirror `flow_arrow_direction_outlier_probe.gd:150-158`); timeout on `rebake_probe`'s system-map await; make the seam probe's deltas gate the exit code or relabel it (verified: its exit code depends only on load errors, `river_flowmap_seam_probe.gd:49-59` — deltas land in stats only).

**Validation:** rebake the demo river and confirm Foam Mix debug view matches the surface; with a river that has a flowmap but null distmap, confirm pillows/gates render neutral (not maxed); close a scene mid-bake then bake again successfully; click a handle without dragging and confirm no undo entry / no bake invalidation; run all hardened probes headless and confirm markers.

## Phase RT — Validation Tooling (days; build the gates before the phases that need them)

The hash/parity/comparison gates the later phases rely on do not exist yet (verified against `probes/`): `bake_inspect_probe` does single-bake stats and PNG dumps only; `ripple_debug_parity_probe` compares material parameters and luminance contrast, not rendered pixels; no system-vs-river flow comparison probe exists. These items can start in parallel with R0; RT.1 must land before R1, RT.2 before R3, RT.3 before R2.

- [x] **RT.1 Bake hash-compare.** Extend `bake_inspect_probe` (or add `bake_hash_probe`) to emit a per-texture content hash for every texture in a `RiverBakeData` resource and to diff two bake resources, exiting nonzero on mismatch with a per-channel delta summary. Consumers: R1 ("output must not change"), R5/R6 ("byte-identical, hash-gated") gates. *Done 2026-06-12 as `probes/bake_hash_probe.gd` (also reports the bounding rect of differing pixels); demonstrated on self-diff (identical) and a perturbed copy (flags exactly the perturbed rect) — see `validation.md`.*
- [ ] **RT.2 Pixel-parity capture harness.** Build on `debug_view_capture_probe` (window required): capture a fixed set of debug views + the visible surface on the demo scene from fixed cameras to PNG, and add a diff mode (max/mean per-channel delta, exit-code threshold). Per constitution rule 8, runs are windowed/human-assisted; record results in `validation.md`. Consumer: R3's before/after extraction parity.
- [ ] **RT.3 System-vs-river flow comparison probe.** Sample the baked system map's flow vectors against the owning river's own baked flow inside obstacle influence zones; report angular/magnitude deltas; exit-code threshold. Consumer: R2's gate.
- [x] **RT.4 Cross-language seed assertion.** Probe-assert that the neutral pressure seed `Color(0.5,…)` (`river_manager.gd:2084`) equals `enc(0)` in `flow_solve_common.gdshaderinc` (verified: all three solve encodings have enc(0)=0.5), plus a pointed comment pair at both sites. Cheap, and it hardens the contract R7 later depends on. *Done 2026-06-12: seed named `RIVER_FLOW_PRESSURE_SEED_COLOR`, comment pair landed, `probes/flow_solve_seed_assert_probe.gd` passes (`FLOW_SOLVE_SEED_ASSERT_OK`).*

**Validation:** each tool demonstrated on a known-good/known-bad pair (e.g., RT.1 against two bakes of the same scene → identical; against pre/post-R0.5 → flags exactly the margin region).

## Phase R1 — Dead-Code Purge + the One Signature Bump (days; needs RT.1)

Everything that invalidates bakes lands here, together, as signature v28. Audit refs: §4, §8, Recommendation 9.

- [ ] **R1.1 Delete the dead SDF steering set** (verified dead): `apply_obstacle_avoidance_flow`, its orphaned shader, the nine `RIVER_OBSTACLE_AVOIDANCE_*` constants, the `..._with_legacy_sdf_steering_fallback` metadata string (actual fallback is `normal_to_flow` + blur — say so), and the corresponding Data Contract producers line.
- [ ] **R1.2 Close the signature gaps** (silent stale-bake bugs; all three verified): add `FLOW_OFFSET_NOISE_TEXTURE_PATH` (path or content hash), `RIVER_EDGE_SMOOTH_RADIUS`/`_ITERATIONS` (`water_helper_methods.gd:880-881` — they shape the mesh the bake derives from), and `RIVER_FLOW_SPEED_FACTOR_MAX` to the signature.
- [ ] **R1.3 Fix `water_occupancy` serialization asymmetry** (audit §8; all three gaps verified at `river_manager.gd:743-767`, `998-1003`, `2934-2937`): add it to property-list storage, `_enter_tree` material binding, and the unsaved-texture check so a scene saved with in-scene textures doesn't reload with `valid_flowmap == true`, null occupancy, and a default `i_flow_projected`.
- [ ] **R1.4 Annotate the ripple-displacement riders — do not delete.** The audit called this set dead; review found otherwise. `i_ripple_impulse_texture` is sampled by `river_debug.gdshader:899,984` (impulse/contact debug heat view), asserted by `ripple_debug_parity_probe.gd:69` and `ripple_material_ownership_probe.gd` (~10 assertions), and set every frame by `water_ripple_field.gd:897`. The `ripple_height_at_*` chain (`river.gdshader:804-842`) and `i_ripple_refraction_strength`/`i_ripple_displacement_strength` are the declared interface of the planned height-displacement feature (`docs/spec-driven/features/river-height displacement/initial_research.md:113,188,355`). Action: add a dated "reserved for river-height-displacement; see initial_research.md" comment at each declaration, and one at `debug_visible`. Any future deletion requires a per-uniform pass that also updates the river-ripples `spec.md:170-176` contract list and all asserting probes — out of scope here.
- [ ] **R1.5 Sweep the small dead code** (audit §4 "Smaller" list): unused shader functions (`wake_visual_mask`, `wake_edge_thinness_at`), `river_debug`'s unused `OCCUPANCY_CLIP_*` and material-only uniforms, `_is_unsaved_texture_resource`, `_find_covered_sample_near_river`, dead `size`/`resolution` uniforms/params, shadowed `_set`/`_get` arms, the commented-out `albedo_set` signal, the orphaned `gui/progress_window.tscn` duplicate.
- [ ] **R1.6 Document the script-API-only generation behaviors** (`legacy_collision_only`, `curve_only`) with one line in validation docs — keep them.
- [ ] **R1.7 Bump signature v27 → v28** and update the signature-version doc reference. Fold in R0.5's margin fix if it didn't already ship.

**Validation:** stale-bake detection fires on a pre-bump scene; RT.1 hash-compare on the demo scenes shows changes only in the regions explained by R0.5/R1.3; grep proves zero remaining **code** references to the deleted constants/string (docs still reference them until R8 — expected, not a gate failure).

## Phase R2 — `system_flow` Projected-Flow Correctness (Defect 1; days; needs RT.3; after R1)

The highest-value correctness fix: the baked WaterSystem flow map — what `buoyant_manager.gd` ducks read — currently re-bends pressure-projected flow that the entire obstacle-constraints feature exists to keep straight.

Feasibility verified: `system_map_renderer.gd:101-136` renders each river separately with a fresh per-river `ShaderMaterial`, so a per-river uniform is plumbable; the flag already exists in per-river bake metadata (`source_metadata.flow_projected`, written at `river_manager.gd:3312`, read by `_bake_metadata_flow_projected` at `:3277`); `system_flow.gdshader` computes boundary gradients through the same `boundary_gradient_at` machinery as `river.gdshader`, so the fade is portable.

- [ ] **R2.1** Plumb `i_flow_projected` from each river's bake metadata through `system_map_renderer.gd` into `system_flow.gdshader` (it currently has no such uniform), gating `apply_contextual_flow_slide` (`system_flow.gdshader:192`).
- [ ] **R2.2** Port the stagnation-centerline fade (`smoothstep(0.0, 0.35, abs(tangent_alignment))`) that `river.gdshader:747` / `river_debug.gdshader:841` carry with the "re-bending a projected field would corrupt it" rationale.
- [ ] **R2.3** If R3 has landed, implement both by consuming the shared slide/force functions from the flow include instead of a third hand-synced copy. If R2 ships first, mark both blocks with a "to be replaced by include" comment so R3 absorbs them.
- [ ] **R2.4 System-map staleness.** System maps have no signature/stale-detection mechanism; this change alters `system_flow.gdshader` output, so every previously saved system map silently keeps the corrupted flow. At minimum: a changelog/migration note instructing "regenerate all system maps", plus a `push_warning` when a WaterSystem loads a system map whose stored generation metadata predates this fix (add a small version int to the system bake settings in `water_system_bake_data.gd`). Document the field in the Data Contract (R8.2).

**Validation:** regenerate system maps on the obstacle demo scene; RT.3 probe shows system-map flow matching river baked flow inside obstacle influence zones (angular delta under threshold); human-assisted check that ducks no longer drift into boundary-shear paths near obstacles.

## Phase R3 — Shared Shader Includes, End of Hand-Sync (days; needs R0.2 + RT.2)

Kills the dominant systemic risk: ~700 copy-mirrored lines between `river.gdshader` and `river_debug.gdshader`, synced only by comments, already failed four times. Audit refs: §3, Recommendation 11.

- [ ] **R3.1 Extract *two* includes.** All three shaders are `shader_type spatial`, and uniforms-in-includes is proven in-repo (`atlas_column_clamp.gdshaderinc`, included by 5+ filters, declares the `atlas_columns` uniform). But `system_flow.gdshader` carries only 21 uniforms and no pillow stack vs ~107 shared by river/debug — one monolithic include would inject ~90 unused uniforms and a displacement `vertex()` into the system-map render, plausibly changing its output. Split:
  - `river_flow_common.gdshaderinc` — flow decode, `boundary_gradient_at`, `contextual_flow_force`, `apply_contextual_flow_slide` + stagnation fade, eddy context. Consumed by `river.gdshader`, `river_debug.gdshader`, **and** `system_flow.gdshader`.
  - `river_surface_common.gdshaderinc` — shared surface uniforms, `FlowUVW`, the pillow stack, wake/eddy visual families, ripple helpers, the byte-identical `vertex()`. Consumed by `river.gdshader` and `river_debug.gdshader` only.
- [ ] **R3.2 Extract `flow_pack.gdshaderinc`** for the `v*0.5+0.5` encode/decode currently re-implemented in ≥10 places (canonical copies: `water_helper_methods.gd:388`, `flow_solve_common.gdshaderinc:20-26`; clones in five filter shaders and inline in river/debug/system_flow/lava).
- [ ] **R3.3 Delete `MATERIAL_PARAMETER_REVERT_OVERRIDES`** (`river_manager.gd:152-212`) in favor of `RenderingServer.shader_get_parameter_default` (already used at `river_manager.gd:1413`). Verified safe: all sampled entries match shader defaults exactly (the table is misnamed — there are no intentional overrides), and it holds only floats/Colors, no textures. Note the consumers are `_property_can_revert`/`_property_get_revert` (`river_manager.gd:932-948`) — those code paths change, not just data.
- [ ] **R3.4 Align or annotate filter-shader uniform defaults** that disagree with the canonical constants that always override them (`obstacle_feature_mask_filter.gdshader:10-13` vs `river_manager.gd:268-271`, e.g. support_start 0.18 vs 0.22; same for the avoidance filter): set to canonical, or comment as dummies.
- [ ] **R3.5 Centralize `OCCUPANCY_SPEED_RAMP_FULL = 0.45`** (currently 7 copies across two shaders and five probes) — move into an include/shared constant the probes read or assert against; stop `system_map_renderer.gd:118-127` re-hardcoding ten river-shader defaults as fallback literals (fetch via `shader_get_parameter_default`).

Ordering note: R2 and R3 can merge into one branch; the flow include *is* the structural fix for Defect 1. Keep R2 separable only if a fast tactical fix is needed for in-flight buoyancy work.

**Validation:** shader compile across Forward+/Mobile/Compatibility; RT.2 pixel-parity capture before/after extraction (windowed/human-assisted per rule 8); regenerate system maps and compare before/after (system_flow consumes the flow include, so system-map parity is part of this phase's gate); inspector revert restores live shader defaults for a dozen spot-checked params; debug parity probe extended to foam/eddy params.

## Phase R4 — Runtime and Editor Robustness (days; independent — can start any time after R0)

Audit refs: Defects 6–7, §5 runtime items, §6, §7, Recommendation 12.

- [ ] **R4.1 Ripple sim stepping (Defects 6, 7) — trade made explicit.** Clamp the catch-up loop to one step per `_process` (`water_ripple_field.gd:215-220,600-634`) — fixes the stale ping-pong read (two SubViewports flagged `UPDATE_ONCE` in one frame render in non-dependency order) and the unbounded post-hitch queue. **Accepted consequence:** the step is fixed-increment (propagation 0.45 / damping 0.985 per step, no delta scaling), so below `simulation_update_rate` the sim runs proportionally slower (1/3 speed at 20 FPS / 60 Hz). This is the chosen trade: slower-but-correct beats on-time-but-corrupted. If full-rate-under-load is later required, the fix is dependency-ordered stepping (await between steps) or a single-viewport multi-pass scheme — out of scope here. Also accumulate `delta` even when impulses are queued (`water_ripple_field.gd:211-213`) so emitters firing near frame rate can't starve propagation.
- [ ] **R4.2 Width generation (audit §5) — performance fix.** Replace `generate_river_width_values`' O(samples × segments × 101) brute force — which runs on every mesh regeneration during interactive curve editing — using `Curve3D.get_closest_offset`. **Not a drop-in:** the code needs a (segment index, interpolate) pair; `get_closest_offset` returns one baked-length scalar in curve-local space. Implementation: transform sample to curve-local, get offset, then map offset → segment+t via a precomputed per-control-point offset table (N `get_closest_offset` calls on the control points, then binary search). Drop the unused `step_width_divs` param and the `closest_dist := 4096.0` seed (the "fails on large rivers" concern is withdrawn — samples lie on the curve, so the seed is effectively unreachable).
- [ ] **R4.3 Buoyancy correctness and cost (audit §7).** Bind `buoyant_manager` to WaterSystem coverage bounds, not nearest origin (`buoyant_manager.gd:108-122`; multi-system scenes pick the wrong system today); make the outside-coverage fallback explicit (the default `y - minimum_water_level` silently buoys anything below world y=0 — warn or require opt-in); eliminate the per-query Dictionary allocation in `water_system_manager.gd:1126` `_sample_system_map` (two per tick per body via `get_water_altitude`/`get_water_flow`) and cache bounds/transforms per sample; stop forcing `sleeping = false` every tick for settled bodies (`buoyant_manager.gd:194`).
- [ ] **R4.4 Ripple/editor lifecycle sweep (audit §6–7).** Late group-routed ripple targets trigger a boundary-mask rebuild; `cleanup_runtime` preserves API-registered targets across rebuilds; `field_group_name` changes off-tree don't leave the node in both groups; one-shot emitters with no field stop retrying (or retry with a cap); resolve "Continuous" vs "Pulse" (make them distinct or merge the docs); ripple inspector transient state survives visibility toggles, and its capture dictionaries are read back or removed.
- [ ] **R4.5 Small guards.** `remove_point` bounds-guards `widths` like it does `flow_speeds`; `validate_filter_renderer` adds the `is PackedScene` check its sibling has; `_first_enter_tree` runtime behavior (`set_widths`/`set_flow_speeds` never regenerate outside the editor) gets the constitution-mandated intent comment — or a fix if unintentional; `push_warning` in `generate_system_maps` for the runtime no-op save case.
- [ ] **R4.6 Ripple `step_once` uniform churn.** Re-set only the swapped texture per step instead of re-scanning target groups and re-setting all 11 uniforms per target at up to 60 Hz.

**Validation:** ripple sim at forced 20 FPS shows artifact-free propagation at the expected reduced rate (document the measured rate in validation.md — slowdown is the accepted design, not a failure), and recovers from a 2 s hitch without a step burst; emitter firing at 60 Hz still propagates waves; curve editing on a 50-point river stays interactive (frame-time capture before/after R4.2) and produces identical width arrays to the brute-force path on the demo rivers (array diff, not just visual); two-system scene buoyancy binds by coverage; settled floating body sleeps.

## Phase R5 — Structural Deduplication (days; R5.1/R5.4/R5.5 can start any time after R0; needs RT.1 for its gates)

Behavior-preserving consolidation. Audit refs: §1 (filter/system renderers), §2, Recommendations 13–14.

- [ ] **R5.1 Table-driven `filter_renderer` passes.** Replace the 19 copy-pasted `apply_*` methods (~470 of 641 lines scaffolding) with a pass-descriptor table (`name → shader path, params, required textures, hdr`). This also *fixes by construction*: the inconsistent optional-texture policy (combine hard-errors on a null with a shader default; obstacle passes substitute; bank-response errors on all — pick one policy in the descriptor), the leak-prone external `set_hdr_2d` state, and the shared-ShaderMaterial uniform-bleed hazard (`filter_renderer.gd:77`).
- [ ] **R5.2 Generic per-point channel helper.** Subsume the five near-identical `widths`/`flow_speeds` helper pairs (sanitize-array/sanitize-value/ensure-count/get-for-point/set-without-notify) into one channel-descriptor-driven implementation. This is the feature roadmap's *"Named per-point channel table"* item (river-future Phase 2, currently unchecked — per-point flow speed itself already shipped) — landing it here unblocks the third channel without a sixth clone set. Must preserve the verified-clean undo/point-edit integrity (regression-test against the existing flow_speeds undo behavior).
- [ ] **R5.3 `system_map_renderer` consolidation.** Merge `grab_height`/`grab_alpha`/`grab_flow` (~80% identical) into one `_grab(..., material_factory)`; share `filter_renderer.gd:590-607`'s readback preflight so system grabs stop consuming viewport images with zero validation.
- [ ] **R5.4 `river_bake_data.set_from_bake`** (16 positional params, transposition-prone) → field assignment + `finalize()`.
- [ ] **R5.5 Property/dup sweep.** Table-drive the six-place `baking_*` property registration from one descriptor; deduplicate the twin 14-arg `apply_bank_response_feature_mask` calls (`river_manager.gd:1982-2003` / `2140-2160`), the three byte-identical blank-image creators (2285-2303), the twin box-blur smoothers (2576-2609), and the ×8 `add_margins` → `ImageTexture` pattern.

**Validation:** RT.1 hash-compare shows byte-identical bake outputs before/after on the demo scenes; inspector property list unchanged (dump+diff); flow_speeds/widths undo round-trip probe.

## Phase R6 — `river_manager.gd` Decomposition (weeks; needs its own spec/plan)

The god-object split, sequenced after R1/R3/R5 so the extraction moves already-deduplicated code. Audit refs: §1, Recommendation 16. Extraction seams in value order:

- [ ] **R6.1 `river_flowmap_baker.gd` (RefCounted)** owning the ~1,400-line bake pipeline (preflight 1594-1664, `_generate_flowmap` 1865-2255 — 391 lines, ~30 awaits, 21 abort points — source-image synthesis 2281-2618, diagnostics 2621-3012). Node dependencies reduce to a config object (curve/mesh/steps/baking properties) + the progress signal. Wrap passes in a run-pass helper so the `if not _filter_output_is_valid(...): return` idiom (currently correct in all 21 sites, but only by vigilance) is owned in one place. The baker owns renderer lifecycle and abort semantics — the R0.3 `tree_exiting` cleanup moves here.
- [ ] **R6.2 Canonical bake-constants table** generating all three metadata dictionaries (~95/~115/~95 keys currently echoing ~80 `RIVER_*` constants by hand, `river_manager.gd:3245-3801`). One row per constant: name, value, which of metadata/signature/settings it feeds. Ends the 4-edits-per-constant tax and makes R1.2-class signature misses **reviewable in one place** (the "feeds signature?" column is still hand-set, so misses become visible, not impossible — the table's review checklist must include "does this row feed the signature, and why not if not").
- [ ] **R6.3 Runtime ripple material ownership** (~200 self-contained lines, 3-method interface) to its own script.
- [ ] **R6.4 Editor validation harnesses** (~230 lines, menu-only) to an editor-only script.

**Gate before starting:** spec/plan/validation files in this folder, including the Lifecycle/Cleanup/Re-entry section from the plan template — the bake pipeline's 21 abort points are exactly what that template section exists for.

**Validation:** RT.1 byte-identical bake outputs (signature unchanged by extraction); mid-bake abort matrix (scene close, node free, undo-delete at multiple await points) leaves no stuck flags, leaked renderers, or orphan viewports; metadata/signature/settings dictionaries diff empty against pre-extraction dumps.

## Phase R7 — Bake Performance: GPU-Resident Solve (weeks; needs its own spec/plan; decision gate first)

Audit refs: §5, Recommendation 17. Sequenced after R6 so it modifies the extracted baker, not the god object.

**Decision gate:** feature-roadmap Phase 5 already plans "RenderingDevice compute migration — move the bake filter stack (and ripple sim) … to compute" (`river-future/Roadmap.md:61-66`). R7's SubViewport-resident ping-pong is an interim optimization of a pipeline Phase 5 replaces wholesale. Before starting R7, decide explicitly: either (a) Phase 5 compute is near-term — fold R7 into that spec and skip the SubViewport work, or (b) Phase 5 is distant — do R7 as specced below and accept it as throwaway-by-design. Record the decision in this folder.

- [ ] **R7.1 GPU ping-pong for the Jacobi solve.** Today: 8 strides × 5 iterations = 40 passes (`river_manager.gd:2086-2094`, strides at `:265`), each pass = render + full-res CPU readback + re-upload + 2 awaited frames (`filter_renderer.gd`) = 80 awaited editor frames + 40 readback round-trips. Target: keep the intermediate textures GPU-resident across iterations and read back once after the solve. **The naive "two SubViewports sampling each other, both flagged `UPDATE_ONCE` per frame" is exactly the Defect-6 mechanism (non-dependency render order → stale reads) — the spec must fence each iteration with ≥1 awaited frame (alternate viewports across frames), or drive draws explicitly via `RenderingServer`.** Realistic win: eliminate all 40 readback/re-upload round-trips and roughly halve awaited frames (~80 → ~40); not "readback once" as a frame-count claim.
- [ ] **R7.2 Test `RenderingServer.frame_post_draw`** as the await primitive to further reduce per-pass wait across the whole pipeline (potentially ~40 → ~20-frame-equivalents for the solve, and proportional gains elsewhere).
- [ ] **R7.3 Kill the CPU pixel loops:** per-pixel `get_pixel` diagnostics (tens of millions of Color allocations at 1024²) move to GPU reduction passes or become opt-in debug-menu actions; flow-vector stats drop the per-bake Variant array sort; `_get_system_map_diagnostics` stops allocating 2 Arrays per pixel at up to 2048². Check first whether any probe or validation doc parses the removed diagnostic output, and migrate those consumers in the same change.

**Validation:** solve output within f16 epsilon of the CPU round-trip path on the demo scenes (bit-identity is not expected — GPU-resident intermediates skip the per-pass quantize/readback the legacy path performs); an adversarial ordering test — force both viewports to update in one frame and prove the fence prevents the stale read (demonstrate the Defect-6 failure mode is guarded, not assumed away); bake wall-clock measured before/after on a fixed scene (record in validation.md as the regression budget); editor remains responsive during bake.

## Phase R8 — Documentation Coherence (days; can run parallel to any phase after R1)

Audit refs: §8, Recommendation 15. R1 changes what the docs must say, so this follows R1.

- [ ] **R8.1 Rewrite the stale `architecture-and-features.md` sections** from current code: obstacle mechanism is the projection solve (not SDF steering); document `water_occupancy`, `i_water_occupancy`, `i_flow_projected`; FilterRenderer pass list gains the seven missing passes.
- [ ] **R8.2 Data Contract:** fix the `obstacle_avoidance_algorithm` string and the "legacy SDF steering" producer line (falls out of R1.1); add `water_occupancy` and `dist_pressure` R/G neutrals to `DEFAULT_IMPORT_PROFILE` — use the verified per-channel neutrals from R0.7 (≈ R=0.75, G=0.25), not 0.5 across the board; document the system-map version field if R2.4 added one.
- [ ] **R8.3 Constitution compliance backfill:** the `river-obstacle-flow-constraints` folder gets its spec/validation/review per the template (rule 12); this folder gets `validation.md` as phases complete.
- [ ] **R8.4 Probe folder hygiene** (audit §9): make the diverged feature-folder copies of the flow-arrow probes pointers to the shared ones (or delete them); unify the two divergent probe arg-parsing schemes; index the RT tools alongside.
- [ ] **R8.5 Correct the vertex-cost figure** wherever "~200+" appears: audited worst case is ~622 `textureLod`/vertex, defaults ~94 — this re-scopes feature-roadmap Phase 5 (see R9).

## Phase R9 — Vertex Pillow Stack → Baked/Compute (deferred)

This is feature-roadmap Phase 5 ("Solver depth and performance"), not a refactor item — tracked there, noted here because the audit re-scoped it: the real worst case is ~622 fetches/vertex (smoothing ring × reach nesting × 4 feature textures, ×2 under seam stitch), not the documented ~200+. Near-term mitigation that *does* belong in this track:

- [ ] **R9.1 (optional, with R3)** Pass already-fetched features into the smoothing ring instead of re-fetching all four textures per tap; bound or proximity-gate the eddy context search (~85 fetches/pixel regardless of obstacle proximity).

---

## Sequencing and Dependencies

```
R0 (hotfixes; R0.2 is a hard prereq of R3) ──► R1 (dead code + signature v28; needs RT.1)
RT (tooling; parallel with R0) ──┬─► RT.1 → R1, R5, R6 gates
                                 ├─► RT.2 → R3 gate
                                 └─► RT.3 → R2 gate

After R1:
  R2 (system_flow; needs RT.3) ◄──merge──► R3 (includes; needs R0.2 + RT.2)
  R8 (docs)

Any time after R0 (independent of R2/R3):
  R4 (runtime robustness)
  R5.1 / R5.4 / R5.5 (GDScript dedup)        R5.2 / R5.3 too, but R5.3 pairs well with R3.5

R5 ──► R6 (river_manager split)  [own spec/plan]
R6 ──► R7 (GPU solve)            [own spec/plan + Phase-5 decision gate]

R9 stays on the feature roadmap (Phase 5); R9.1 may ride with R3.
```

- R0 items are independent of everything and each other — land first, any order. RT runs in parallel.
- R2 and R3 are best merged (the flow include *is* the structural fix for Defect 1); keep R2 separable only if buoyancy work needs the tactical fix sooner.
- R4 and the GDScript halves of R5 are independent of the shader work and can absorb idle time between the bigger phases.
- R5 before R6: extract already-deduplicated code, not duplicated code. R6 before R7: optimize the extracted baker, not the god object.
- R8 can interleave anywhere after R1.
- Feature-roadmap interaction: R5.2 *is* feature Phase 2's channel-table item (the unchecked one); feature Phase 3 (flow-advected displacement) should not start until R3 lands (it would otherwise add a third+ hand-synced shader surface); R7 must not start without the Phase-5 compute decision recorded.

## Effort Summary

| Phase | Scope | Effort | Bake-content change |
| --- | --- | --- | --- |
| R0 | 9 hotfix items | hours each (R0.7: half-day) | R0.5 only (margin fix) |
| RT | 4 tooling items | days | none |
| R1 | dead code + signature gaps | days | yes — single v28 bump |
| R2 | system_flow projected-flow | days | system maps only (no staleness mechanism — see R2.4) |
| R3 | shader includes ×2 + flow_pack | days | none (RT.2 parity-gated, incl. system maps) |
| R4 | runtime/editor robustness | days | none |
| R5 | structural dedup | days | none (RT.1 hash-gated) |
| R6 | river_manager split | weeks | none (RT.1 hash-gated) |
| R7 | GPU-resident solve | weeks | none (f16-epsilon-gated) |
| R8 | docs coherence | days | none |

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Include extraction (R3) subtly changes shader output (uniform ordering, precision, hint defaults) | Visual regressions across every river | RT.2 pixel-parity capture before/after; land as pure-move commits (no logic edits in the same commit); R0.2 resolves divergences *before* extraction so there are no mid-move judgment calls |
| Monolithic include leaks surface uniforms/vertex() into system_flow | System-map output changes silently | Two-include split (R3.1); system-map regeneration is part of R3's gate |
| R1's signature bump invalidates user bakes mid-feature-work | Lost bake time, confusion | Land R1 at a quiet point; everything bake-affecting rides the one bump; changelog entry |
| R2 fixes the shader but stale system maps persist in saved scenes | Ducks keep reading corrupted flow with no warning | R2.4 version field + load warning + migration note |
| R6 extraction breaks one of the 21 abort points | Stuck flags / leaked renderers, the exact Defect-3 class | Run-pass helper owns the abort idiom; abort-matrix validation at multiple await points; own spec/plan first |
| R7 ping-pong hits the Defect-6 ordering hazard (two UPDATE_ONCE viewports, one frame) | Solve consumes stale iterations — wrong flow fields, hard to notice | Spec must fence every iteration (alternate viewports across awaited frames or RenderingServer-driven draws); adversarial ordering test in validation |
| R7 duplicates feature-Phase-5 compute migration | Weeks of throwaway work | Decision gate recorded before R7 starts |
| R5.2 channel generalization breaks verified-clean undo integrity | Editor data loss on undo | Port the existing flow_speeds undo probe to the generic helper before switching widths over |
| Headless validation overstates confidence (constitution rule 8) | "Verified" visuals that were never seen | RT.2 is windowed/human-assisted by design; every phase checklist names its human-assisted checks; record outcomes in validation.md, not as assumed-pass |
| R2 metadata plumbing adds a key without signature coverage | New silent stale-bake gap (Defect-class §8) | R2 lands after R1; new metadata/signature keys go through R6.2's table once it exists, or get explicit signature entries |
| Deletion of "dead" shader interface that probes/specs actually consume (the R1.4 class) | Broken debug views and validation suite | Operating rule: before deleting any uniform/function, grep shaders **and** probes **and** feature specs |

## Tracking

Work the checklists above in place (edit this file). When a phase starts, note its branch name next to the phase heading; when it completes, record validation results in this folder's `validation.md` and update `docs/handoffs/handoff-latest.md`. R6 and R7 must not start without their own spec/plan/validation files in this folder; R7 additionally requires the Phase-5 compute decision recorded.
