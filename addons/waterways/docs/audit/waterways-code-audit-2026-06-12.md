# Waterways Code Audit

Date: 2026-06-12
Branch: `river-obstacle-flow-constraints` (uncommitted working tree, bake signature v27)

## Scope

Full audit of the files that ship the addon: the core scripts at `addons/waterways/*.gd`, `shaders/` (surface, debug, filters, runtime, system renders), `gui/`, `resources/`, the editor/plugin layer, and the shared `probes/`. Excluded: third-party `zylann.hterrain` (except confirming the importer stubs stay inert), generated bakes, demo content, art, and historical/WIP docs. Graded against the repo's own conventions (`docs/spec-driven/00-constitution.md`, `docs/architecture-and-features.md` "Practical Change Boundaries", `river-future/Data Contract.md`) rather than generic style preferences.

Method: six parallel audit passes (core node, bake pipeline + resources, shaders, runtime nodes, editor layer, doc-coherence + probes), followed by manual verification of every High-severity claim. The five most load-bearing findings below were each re-verified directly against source before this report: the dead SDF path, the foam default divergence, the `system_flow` slide gate, the Godot-3 `invert()` leftover, and the first-tile margin copy.

## Executive Summary

The codebase is in better shape than its size suggests: the data contracts hold (every channel slug, neutral value, and the AABB registry verified against code), the f16 pressure-solve plumbing is correct, the editor/runtime boundary discipline is genuinely respected, the ripple material-ownership protocol has no leak paths, and the recently added `flow_speeds` plumbing survives undo and point edits correctly.

The dominant systemic risk is **synchronization by hand**. The river surface shader and its debug twin share ~700 copy-mirrored lines synced only by comments — and that mechanism has already failed four times (foam defaults ×2, the eddy foam formula, and `system_flow.gdshader` missing the projected-field protections). The same pattern repeats at smaller scale: ~80 bake constants echoed by hand into three metadata dictionaries, ~60 shader defaults mirrored into the inspector revert table, flow encode/decode re-implemented in ten places, and shader thresholds mirrored into seven probe copies.

The second theme is **verified correctness defects** — eleven concrete bugs listed below, the worst being that the WaterSystem flow map (what buoyancy reads) re-bends pressure-projected flow that the entire obstacle-constraints feature exists to keep straight.

The third theme is **`river_manager.gd` as a 3,807-line god object** whose bake pipeline (~1,400 lines) and metadata assembly (~550 lines) are both low-coupling extractions waiting to happen — the constitution's own module-size rule says so, and the next feature should not land on top of the current shape.

## Verified Defects (fix list)

1. **[H] `system_flow.gdshader` corrupts projected flow in the system map.** It applies `apply_contextual_flow_slide` unconditionally (`system_flow.gdshader:192`) — it has no `i_flow_projected` uniform — and its slide lacks the stagnation-centerline fade (`smoothstep(0.0, 0.35, abs(tangent_alignment))`) that `river.gdshader:747` / `river_debug.gdshader:841` both carry with an explicit "re-bending a projected field would corrupt it" rationale. Result: the baked system map (consumed by `buoyant_manager.gd` ducks) re-introduces boundary shear the projection solve removed. Port both protections; the system map renderer must plumb `i_flow_projected` from each river's bake metadata.
2. **[H] The Foam Mix debug view renders different math than the surface shader.** `foam_amount` defaults 2.0 vs 1.0 and `foam_smoothness` 0.3 vs 1.0 between `river.gdshader:55,61` and `river_debug.gdshader:103,109`; `_sync_debug_material_from_visible_material` (`river_manager.gd:1487`) copies `get_shader_parameter()`, which returns null for at-default params, so the mismatched defaults win whenever the user hasn't touched the sliders. The eddy-line foam term has also textually drifted (`river.gdshader:1074` vs `river_debug.gdshader:1458`).
3. **[H] Stuck bake flag on mid-bake exit.** If the river leaves the tree during `_generate_flowmap`'s ~30 awaits (scene closed, undo deletes the node), the coroutine dies with `_flowmap_bake_in_progress == true`; every later `bake_texture()` is silently swallowed as a "duplicate request" (`river_manager.gd:1656`). Reset the flag (and free the tracked renderer) on `tree_exiting`.
4. **[M] First-tile margin copies the wrong end.** `_add_uv2_column_continuation_margins` (`water_helper_methods.gd:1737-1747`): for `step_index == 0` the self-referencing clamp copies the tile's *bottom* strip into the *top* margin — content from one tile-length downstream sits just above the river's first row, feeding dilate/blur/solve neighbor reads. The symmetric last-tile case (1748-1756) clamps correctly. Copy the top strip when `previous_step == step_index`.
5. **[M] Godot 3 leftover crash + dead inspector reordering.** `last_prefix_occurence` calls `Array.invert()` (`water_helper_methods.gd:1800`) — removed in Godot 4, guaranteed error if reached; concealed because its caller matches `hint_string == "Texture"` which Godot 4 reports as `"Texture2D"`, making `reorder_params` a silent no-op. Fix (`reverse()` + `"Texture2D"`) or delete both.
6. **[M] Ripple sim multi-step-per-frame reads stale textures.** The catch-up loop (`water_ripple_field.gd:215-220,600-634`) can flag both ping-pong SubViewports `UPDATE_ONCE` in one frame; render order is not dependency-ordered, so step 2 samples step 1's not-yet-rendered output. Routine whenever FPS < `simulation_update_rate` (default 60); the loop is also unbounded after a hitch (~120 queued steps for a 2 s stall). Clamp to one step per `_process`.
7. **[M] Queued impulses starve the wave equation.** `_process` returns before accumulating `delta` when impulses are queued (`water_ripple_field.gd:211-213`); emitters firing near frame rate stamp impulses forever while propagation never advances.
8. **[M] Gizmo connection leak → freed-instance errors.** `river_gizmo.gd:431-433` connects `river_changed` to a per-gizmo bound callable and never disconnects; old gizmos accumulate and fire after being freed — triggered exactly by the undo paths the gizmo creates.
9. **[M] Click-without-drag on a handle invalidates a valid bake.** `river_gizmo.gd:347-380` `_commit_handle` has no no-change guard: it always pushes "Change River Shape" with `valid_flowmap: false`. The ripple gizmo (`ripple_gizmo.gd:100-105`) already implements the correct no-op pattern.
10. **[M] Freed-instance access on scene close.** `plugin.gd:363-369` `_set_progress_source` checks null but not `is_instance_valid`; closing a scene while a river is the progress source touches a freed node.
11. **[M] `i_distmap : hint_default_white` violates neutral-at-absent.** With a valid flowmap but missing distmap, white decodes to maximum pressure and fully-open grade-energy gates (`river.gdshader:127,362,436,585`) instead of the documented neutral fallback. (`i_water_occupancy`'s black default is the correct pattern.)

## 1. Architecture and Decomposition

`river_manager.gd` (3,807 lines) holds five separable concerns. Extraction seams, in value order:

- **Bake pipeline** (~1,400 lines: preflight 1594-1664, `_generate_flowmap` 1865-2255 — 391 lines, ~30 awaits, 21 abort points — source-image synthesis 2281-2618, diagnostics 2621-3012). Node dependencies reduce to curve/mesh/steps/baking properties + the progress signal — all passable as a config object. Extract `river_flowmap_baker.gd` (RefCounted) owning renderer lifecycle and abort semantics; wrap passes in a run-pass helper so the easy-to-forget `if not _filter_output_is_valid(...): return` idiom (currently correct in all 21 sites, verified) is owned in one place.
- **Metadata/signature/settings assembly** (~550 lines, 3245-3801): three dictionaries (~145, ~115, ~95 keys) echo the same ~80 `RIVER_*` constants key-by-key. Adding one bake constant requires 4 edits; missing the signature copy silently breaks stale-bake detection (and §8 shows two such misses exist today). Build all three from a single canonical constants table.
- **Runtime ripple material ownership** (~200 lines, self-contained, 3-method interface).
- **Editor validation harnesses** (~230 lines, menu-only) to an editor-only script.

`filter_renderer.gd` is the same story in miniature: 19 `apply_*` methods share an identical 9-line skeleton; ~470 of 641 lines are scaffolding (path consts + vars + loads triplicate every pass registration). A table-driven pass descriptor (`name → shader path, params, required textures, hdr`) collapses it, fixes the optional-texture policy inconsistency (combine hard-errors on a null the shader declares a default for; obstacle passes substitute defaults; bank-response errors on all), fixes `set_hdr_2d` as leak-prone external state, and structurally solves the shared-ShaderMaterial uniform-bleed hazard (`filter_renderer.gd:77` — passes inherit stale uniform values whenever names collide and a pass relies on a default).

`system_map_renderer.gd`: `grab_height`/`grab_alpha`/`grab_flow` are ~80% identical (one `_grab(..., material_factory)` suffices), and it consumes viewport images with zero validation in exactly the environments `filter_renderer.gd:590-607` carefully preflights — share the readback helper.

## 2. Duplication

- `widths` / `flow_speeds`: five near-identical helper pairs (`river_manager.gd` sanitize-array/sanitize-value/ensure-count/get-for-point/set-without-notify). A third per-point channel adds a sixth clone set — this is the roadmap's per-point channel table, now with audit weight behind it.
- `apply_bank_response_feature_mask` invoked twice with identical 14-argument bodies (`river_manager.gd:1982-2003` vs `2140-2160`); three byte-identical blank-image creators (2285-2303); twin box-blur smoothers (2576-2609); the `add_margins` → `ImageTexture` pattern ×8.
- Every `baking_*` property exists in six places (setter, property list, sanitize, `_set`, `_get`, defaults dict) — table-drive from one descriptor.
- Flow packing `v*0.5+0.5` encode/decode exists in **≥10 places** (canonical: `water_helper_methods.gd:388`, `flow_solve_common.gdshaderinc:20-26`; re-implemented in five filter shaders and inline in river/debug/system_flow/lava). The repo already proves the fix pattern — `atlas_column_clamp.gdshaderinc` is included by 10+ filters. Extract `flow_pack.gdshaderinc`.
- `resources/river_bake_data.gd` `set_from_bake`: 16 positional parameters with trailing optionals in landing order (`water_occupancy` separated from its five sibling textures by a Dictionary param) — adjacent same-typed params make transposition bugs likely; switch to field assignment + `finalize()`.

## 3. Mirrored Constants and Shader Drift

The shader audit produced a full mirror table (20 constant families). Summary: most copies agree today, but four have already diverged (defects 1, 2 above plus the filter-shader uniform defaults below), and nothing enforces any of them.

- **river ↔ river_debug**: ~700 lines copy-mirrored (`FlowUVW`, the whole pillow stack, wake/eddy families, `contextual_flow_force`, slide, ripple helpers, byte-identical `vertex()`), synced only by "Mirrors river.gdshader" comments. Godot's `#include` supports uniforms and functions in includes (proven in-repo); extract `river_common.gdshaderinc` and let `system_flow.gdshader` consume the slide/force functions from the same include — which fixes defect 1 structurally rather than by a third hand-synced copy.
- **Filter shader uniform defaults disagree with the canonical constants that always override them** (`obstacle_feature_mask_filter.gdshader:10-13` vs `river_manager.gd:268-271`, e.g. support_start 0.18 vs 0.22; same for the avoidance filter). Wrong documentation for anyone hand-testing; set to canonical or comment as dummies.
- **`MATERIAL_PARAMETER_REVERT_OVERRIDES`** (`river_manager.gd:152-212`) mirrors ~60 shader defaults by value; drift makes inspector revert restore the wrong value silently. `RenderingServer.shader_get_parameter_default` is already used at line 1413 — use it and delete the table.
- **`OCCUPANCY_SPEED_RAMP_FULL = 0.45` exists in 7 places** (two shaders, five probes) with zero enforcement; `system_map_renderer.gd:118-127` re-hardcodes ten river shader defaults as fallback literals.
- The neutral pressure seed `Color(0.5,…)` (`river_manager.gd:2084`) must equal `enc(0)` in `flow_solve_common.gdshaderinc` — an implicit cross-language contract held only by comments.

## 4. Dead and Legacy Code

- **The legacy SDF steering path is dead, and the metadata lies about it** (verified): `apply_obstacle_avoidance_flow` has zero call sites; its shader is orphaned; the nine `RIVER_OBSTACLE_AVOIDANCE_*` constants survive only to be echoed into metadata/signature/settings; and `source_metadata.obstacle_avoidance_algorithm` advertises `..._with_legacy_sdf_steering_fallback` when the actual fallback is `normal_to_flow` + blur. The implementation plan's "legacy steering path remains for fallback" claim is no longer true. Delete the set together (function, shader, constants, metadata string, Data Contract producers line) with a signature bump.
- Unimplemented ripple displacement rides along everywhere: `i_ripple_impulse_texture` never sampled; `i_ripple_refraction_strength`/`i_ripple_displacement_strength` never read but set every frame and synced to debug; the `ripple_height_at_*` call-chain has no callers (`river.gdshader:804-842`). `debug_visible` is reserved-but-unconsumed.
- Smaller: `wake_visual_mask()`/`wake_edge_thinness_at()` defined-unused in river.gdshader; `river_debug`'s unused `OCCUPANCY_CLIP_*` and 15+ material-only uniforms; `_is_unsaved_texture_resource`, `sum_array`, `_find_covered_sample_near_river` (no callers); dead `size` uniforms in three filter shaders; the dead `apply_dotproduct` `resolution` param; defensive `_set`/`_get` arms shadowed by declared properties; commented-out `albedo_set` signal; the orphaned `gui/progress_window.tscn` duplicate whose script extends `Window` while the scene root is a `PopupPanel`.
- `legacy_collision_only` / `curve_only` generation behaviors are reachable only via script API or serialized scenes — keep, but they deserve one line in validation docs.

## 5. Performance

- **Vertex cost is ~3× the documented figure**: worst path ≈ 622 `textureLod`/vertex (smoothing ring × reach nesting, each tap re-fetching all four feature textures; seam stitch doubles it), defaults ≈ 94; the Roadmap's "~200+" corresponds to reach-only. Reinforces the Phase 5 baked/compute migration; near-term, the smoothing ring can pass already-fetched features. Fragment side: the eddy context search costs ~85 fetches/pixel regardless of obstacle proximity.
- **Bake wall-clock is dominated by the CPU round-trip ping-pong**: every pass renders, reads back full-resolution to CPU, re-uploads; ×2 awaited frames each. The Jacobi solve alone = 40 passes = 80 awaited editor frames + 40 float readbacks. Keep the ping-pong on GPU (two SubViewports sampling each other) and read back once after the solve; test `RenderingServer.frame_post_draw` to halve the wait.
- CPU pixel loops on every bake: per-pixel `get_pixel` diagnostics (tens of millions of Color allocations at 1024²; `_get_collision_map_stats` even runs once on a guaranteed-blank image), flow-vector stats with a Variant array sort per bake, `create_downstream_baseline_flow_image` doing per-pixel `set_pixel` where `fill_rect` is a one-liner, and `_get_system_map_diagnostics` allocating 2 Arrays per pixel at up to 2048².
- `generate_river_width_values` brute-forces closest-point at O(samples × segments × 101) `curve.sample()` calls **on every mesh regeneration** (interactive curve editing), with a `closest_dist := 4096.0` seed that silently fails on rivers larger than 4096 units and an unused `step_width_divs` parameter. Replace with `Curve3D.get_closest_offset`.
- Runtime: ripple `step_once` re-scans target groups and re-sets all 11 uniforms per target up to 60 Hz when only the swapped texture changes; `buoyant_manager` allocates a result Dictionary per sample (2/tick/body) and re-resolves bounds/transforms per call; submerged bodies never sleep (`sleeping = false` every tick).

## 6. Editor Stability and Lifecycle

Defects 8-10 above, plus: `_first_enter_tree` never flips outside the editor, so runtime `set_widths()`/`set_flow_speeds()` never regenerate or invalidate — if intentional, it needs the constitution-mandated comment; `remove_point` bounds-guards `flow_speeds` but not `widths`; `validate_filter_renderer` skips the `is PackedScene` check its sibling performs; ripple inspector transient state is wiped on every visibility change and its capture dictionaries accumulate without being read back; `field_group_name` changes off-tree leave the node in both groups; one-shot emitters with no field retry forever; "Continuous" emitter mode is behaviorally identical to "Pulse" while docs list them as distinct.

Verified clean: plugin enter/exit symmetry (custom types, gizmo plugins, inspector plugins, signals, controls); progress window always hides on failure; debug menu tables internally consistent across all 66 ids; no per-frame polling; the gradient inspector editor is additive, not the wrapping pattern that caused the past tooltip incident; `flow_speeds` undo/point-edit integrity.

## 7. Runtime Nodes

Defects 6-7 above, plus: `buoyant_manager` binds to the nearest WaterSystem *origin*, ignoring coverage bounds — wrong system wins in multi-system scenes; outside-coverage fallback (`y - minimum_water_level`, default 0) silently buoys anything below world y=0; late group-routed ripple targets never trigger a boundary-mask rebuild (permanently outside the mask they define); `cleanup_runtime` drops API-registered targets on every rebuild; `generate_system_maps`' editor-only internal save is documented in probes but not at the function itself (`push_warning` the runtime no-op case).

Verified clean: material ownership restore paths (two independent backstops), texture lifecycle (viewports freed on cleanup/rebuild), emitter cap/priority, world→map transform math (matches `build_world_to_map` exactly), flow decode, editor-singleton access pattern export-safe.

## 8. Doc-Code Coherence and Signature Discipline

- `architecture-and-features.md` is **stale at High severity**: it documents the removed SDF steering as the obstacle mechanism (metadata string it cites no longer exists in code) and has zero mentions of `water_occupancy`, `i_water_occupancy`, `i_flow_projected`, or the projection solve. The FilterRenderer pass list omits all seven passes added since. Rewrite those sections from current code.
- Data Contract: accurate except the `obstacle_avoidance_algorithm` string and the "legacy SDF steering" producer (both fall out of the defect-4 cleanup). The machine-readable `DEFAULT_IMPORT_PROFILE` lacks neutrals for `water_occupancy` and `dist_pressure` R/G.
- **Signature gaps (silent stale-bake bugs)**: `FLOW_OFFSET_NOISE_TEXTURE_PATH` content is baked into `flow_foam_noise.A` but neither path nor hash is in the signature; `RIVER_EDGE_SMOOTH_RADIUS`/`_ITERATIONS` shape the mesh the bake derives from but aren't in the signature (while the analogous terrain-contact pass count is); `RIVER_FLOW_SPEED_FACTOR_MAX` is in metadata but not the signature.
- Constitution: the active feature folder skips the mandated spec/validation/review template (rule 12); `water_occupancy` is serialization-asymmetric with its five sibling textures (absent from property-list storage, `_enter_tree` material binding, and the unsaved-texture check — a scene saved with in-scene textures reloads with `valid_flowmap == true` but null occupancy and a default `i_flow_projected`).

Verified clean: signature version matches docs; AABB registry exactly matches the shader's `VERTEX.y` contributors; occupancy bake thresholds, flow packing, dist_pressure B/A provenance, and all quoted constants match.

## 9. Probes and Validation Tooling

- `flow_arrow_neutral_cells_probe` claims to reproduce the FLOW_ARROWS neutral decision but skips the shader's 4-point sub-cell fallback (its sibling probe mirrors it correctly) — it over-counts neutral cells.
- Both flow-arrow probes crash (and hang headless with no marker) on a wrong-typed bake resource; harden like `bake_inspect_probe`. Neither prints a success marker nor takes `out=`.
- The seam probe is labeled a "regression gate" but its deltas never affect the exit code — add a threshold gate or relabel.
- `rebake_probe`'s system-map await has no timeout (the river bake wait does).
- The shared and feature copies of the flow-arrow probes have already diverged (the duplication this folder was built to manage — make the feature copies pointers or delete them), and probe arg parsing exists in two divergent schemes.

## 10. What Is Healthy

Worth stating plainly, because it shapes where effort should not go: data contracts and channel metadata verified end-to-end; f16 HDR bracketing of the pressure solve correct with sane precision headroom; atlas column clamping consistent across all bake x-offset passes; neutral-at-absent correct for occupancy and ripple boundary (distmap is the one violation); editor/runtime boundary export-safe throughout; undo registration order correct; ripple material ownership leak-free; warnings consistently actionable; no game-specific hardcoding in the addon.

## Prioritized Recommendations

**Hours each (do first):**
1. Surface `last_readback_error` in `_filter_output_is_valid`'s warning (one line; currently 27 precise diagnoses are discarded).
2. Align `foam_amount`/`foam_smoothness` defaults between river/debug shaders (defect 2's immediate symptom).
3. Reset `_flowmap_bake_in_progress` + free the renderer on `tree_exiting` (defect 3).
4. `_commit_handle` no-change guard (defect 9, template exists in ripple_gizmo) and the `_redraw` disconnect fix (defect 8); `is_instance_valid` in `_set_progress_source` (defect 10).
5. Fix the first-tile margin strip (defect 4) and the metadata algorithm string; delete `reorder_params`/`invert()` (defect 5) and `sum_array`.
6. `i_distmap` → neutral-safe default (defect 11).
7. Skip the blank-image collision stats scan; `fill_rect` for the baseline image.
8. Probe hardening (null-checked loads + markers in flow-arrow probes; timeout on system await; seam gate or relabel).

**Days each:**
9. Delete the dead SDF steering set (function + shader + 9 constants + metadata string + Data Contract line) with a signature bump; add the missing signature keys (noise texture, edge-smooth constants, speed-factor max) in the same bump.
10. `system_flow.gdshader`: port the stagnation fade and `i_flow_projected` gate, plumbing the flag through the system map renderer (defect 1 — the highest-value correctness fix).
11. Extract `river_common.gdshaderinc` (shared uniforms + helper functions for river/debug/system_flow) and `flow_pack.gdshaderinc`; delete the revert-override table in favor of `shader_get_parameter_default`.
12. Replace `generate_river_width_values` search with `Curve3D.get_closest_offset`; fix ripple step clamping + impulse delta accumulation (defects 6-7).
13. Table-driven `filter_renderer` pass descriptors (kills ~470 scaffolding lines, the HDR state leak, and the uniform-bleed hazard).
14. Generic per-point channel helper (subsumes the widths/flow_speeds twins — roadmap Phase 2 item, now audit-backed).
15. Rewrite the stale `architecture-and-features.md` sections (SDF → projection, occupancy, pass list) and backfill the feature folder's spec/validation/review per the constitution.

**Weeks (schedule deliberately):**
16. Extract the bake pipeline (`river_flowmap_baker.gd`) and the metadata/signature/settings builder from `river_manager.gd` (~2,000 lines out of the node; single canonical constants table ends the triple echo).
17. GPU-resident ping-pong for the solve (80 awaited frames → ~2 readbacks per bake).
18. Vertex-stage pillow stack to a baked/compute pass (the documented Roadmap Phase 5 item; the real worst-case is ~622 fetches, not ~200).
