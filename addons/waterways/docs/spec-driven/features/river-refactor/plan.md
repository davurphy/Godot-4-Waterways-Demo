# Plan: River Refactor (Hardening + Refactor Track)

## Spec Link

`spec.md` — ordered work plan with per-item details and gates: `roadmap.md`

## Architecture Summary

A dependency-aware phase sequence (R0 hotfixes → RT tooling → R1 dead-code purge + the one v28 signature bump → R2 system-flow correctness → R3 shared shader includes → R4 runtime robustness → R5 structural dedup → R6 `river_manager.gd` decomposition → R7 GPU-resident solve → R8 docs) that converts every hand-synced surface into a single source of truth and every "verified by vigilance" idiom into a structural guarantee, while keeping bake output byte-identical through all behavior-preserving phases (hash-gated by RT.1) and concentrating every bake-content change into one signature bump. R6 and R7 are heavyweight and get their own spec/plan/validation files in this folder before implementation (constitution rule 12); this plan covers the track as a whole and the lighter phases directly.

## Current Truth

- Implementation status: Phases R0, RT, R1, R2, R3, R8 complete and fully closed (2026-06-12); R4/R5 open; R6/R7 gated on their own docs
- Open architectural decisions: R7-vs-feature-Phase-5 compute decision (gate before R7). Resolved: R2/R3 landed merged (2026-06-12), as the roadmap recommended. New optional decision logged in `validation.md`: whether system_flow should also apply occupancy stilling/wake damping so duck-read magnitudes match the river surface's runtime advection
- Last validation that proves the plan still works: 2026-06-12 R8 docs-coherence pass (code grep gates clean, docs spot-checked against source) on top of the post-R2+R3 full suite (see `validation.md` matrix); the plan's R2 gate assumption was corrected during execution (Defect-1 signature misattribution — see `spec.md` Resolved Questions)
- Next planned implementation slice: R4 (runtime/editor robustness) or the GDScript halves of R5 as time allows
- Branch safety before implementation: all work to date on `river-refactor` with the user's acquiescence (deviation from the one-branch-per-phase rule, recorded in the handoff)
- Sections below that are historical or superseded: the R2 acceptance-gate description (RT.3 `enforce=all` < 20°) is superseded by the restructured gate (mechanism probe + 35° gross-divergence guard)

## Premise Check

- Evidence supporting the premise: the audit found eleven defects; the adversarial review re-verified each at the cited source lines (e.g., the stuck bake flag at `river_manager.gd:1656`, the gizmo leak at `river_gizmo.gd:431-433`, the first-tile margin index math at `water_helper_methods.gd:1737-1747`, the four shader drift failures).
- Evidence against the premise: the review *overturned* several audit claims, and the roadmap already incorporates the corrections — the ripple-displacement interface is live (R1.4), `reorder_params` removal is ordering-neutral (R0.6), the width-generation seed concern was withdrawn (R4.2). No further premise corrections are outstanding.
- User-facing pushback or clarification needed before patching: only the R7 decision gate; everything else is verified and self-contained.
- Smallest check that can falsify the premise: each R0 item's validation step doubles as its falsifier (e.g., if Foam Mix already matches the surface after a rebake, R0.2's premise is wrong — re-inspect before patching).

## Layers

Editor authoring layer:

- Gizmo/plugin lifecycle (R0.4: disconnect per-gizmo callables, no-change `_commit_handle` guard, `is_instance_valid` in `_set_progress_source`); inspector revert via `shader_get_parameter_default` (R3.3); editor validation harnesses extracted to an editor-only script (R6.4); ripple inspector lifecycle sweep (R4.4).

Bake/data layer:

- Bake preflight/pipeline (R0.1, R0.3, R0.8) and its extraction to `river_flowmap_baker.gd` (R6.1); signature gaps closed + v28 bump (R1.2, R1.7); `water_occupancy` serialization symmetry (R1.3); first-tile margin fix (R0.5); neutral `i_distmap` binding (R0.7); canonical bake-constants table (R6.2); system-map version field (R2.4); GPU-resident solve (R7).

Runtime layer:

- `system_flow.gdshader` projected-flow gate + stagnation fade (R2.1–R2.2); ripple sim stepping and uniform churn (R4.1, R4.6); buoyancy coverage binding, fallback opt-in, allocation and sleep fixes (R4.3); width generation via `Curve3D.get_closest_offset` (R4.2); runtime ripple material ownership extracted (R6.3).

Validation layer:

- RT.1 bake hash-compare (extends `bake_inspect_probe` or new `bake_hash_probe`); RT.2 pixel-parity capture harness (builds on `debug_view_capture_probe`, windowed); RT.3 system-vs-river flow comparison probe; RT.4 cross-language seed assertion; R0.9 probe hardening (null-checked loads, markers, `out=` support, seam-probe exit-code fix).

Legacy reference layer:

- R0.6 deletes the last Godot 3 leftovers (`reorder_params`, `last_prefix_occurence`, `sum_array` — the `Array.invert()` crash site and the `"Texture"` vs `"Texture2D"` dead match). No legacy behavior is being preserved by this track; the audit-verified-clean areas are explicitly frozen instead.

## Godot Components

- Nodes: `RiverManager` (`river_manager.gd` — shrinks via R6), `WaterSystem` (`water_system_manager.gd`), `BuoyantManager` (`buoyant_manager.gd`), `WaterRippleField` (`water_ripple_field.gd`)
- Resources: `RiverBakeData` (`river_bake_data.gd` — R5.4 `set_from_bake` → field assignment + `finalize()`), `water_system_bake_data.gd` (R2.4 adds a version int)
- Shaders: `river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader`, the filter shaders; new `river_flow_common.gdshaderinc`, `river_surface_common.gdshaderinc`, `flow_pack.gdshaderinc` (R3); orphaned SDF-steering shader deleted (R1.1)
- Editor tools: `plugin.gd`, `river_gizmo.gd`, `ripple_gizmo.gd` (R0.4); progress window (orphan duplicate `gui/progress_window.tscn` removed in R1.5)
- Importers: none touched (`zylann.hterrain` stubs stay inert — non-goal)
- Autoloads: none
- Scenes: demo scenes used as fixed validation fixtures (hash/parity baselines)
- Validation scenes: obstacle demo scene (R2 gate); demo river scene (R0/R1/R3/R5/R6 gates); probe scripts under `probes/`

## Data Model

- Bake signature: v27 today; R1.7 bumps to v28 exactly once. R1.2 closes the verified gaps first (`FLOW_OFFSET_NOISE_TEXTURE_PATH`, `RIVER_EDGE_SMOOTH_RADIUS`/`_ITERATIONS`, `RIVER_FLOW_SPEED_FACTOR_MAX`). After R6.2, every `RIVER_*` constant lives in one table row declaring whether it feeds metadata/signature/settings.
- `water_occupancy`: gains property-list storage, `_enter_tree` material binding, and unsaved-texture coverage (R1.3) so save/reload round-trips correctly.
- `i_distmap` neutral: a code-side neutral `ImageTexture` ≈ (0.75, 0.25, 0.0, 0.5) bound wherever the real texture would be (`_enter_tree`, bake load, bake finalize) when `dist_pressure` is null (R0.7).
- System maps: no staleness mechanism today; R2.4 adds a small version int to system bake settings in `water_system_bake_data.gd`, with a load-time `push_warning` for pre-R2 maps. Documented in the Data Contract via R8.2.
- Per-point channels: `widths`/`flow_speeds` helper pairs collapse into one channel-descriptor implementation (R5.2) — this is the feature roadmap's named-channel-table item and must preserve verified-clean undo integrity.

## Editor/Runtime Boundary

- Editor-only code: gizmos, plugin progress UI, validation harnesses (R6.4), bake triggering. The extracted baker (R6.1) is RefCounted and editor-driven but holds no editor state — config object in, progress signal out.
- Runtime-safe code: shaders + includes, buoyancy sampling, ripple sim, system-map consumption.
- Shared data/resources: `RiverBakeData`, system bake data, the shader includes, the neutral-distmap texture helper.
- APIs exposed to user projects: `bake_texture()`, `get_water_altitude`/`get_water_flow`, ripple registration APIs — signatures unchanged by this track; script-API-only generation behaviors (`legacy_collision_only`, `curve_only`) kept and documented (R1.6).
- Assumptions that must not cross the boundary: editor-frame awaits inside the baker (R6.1 owns abort semantics); `Engine.is_editor_hint`-dependent regeneration behavior in `set_widths`/`set_flow_speeds` gets the constitution-mandated intent comment or a fix (R4.5).

## Runtime Flow

1. River material samples baked textures; with null `dist_pressure`, the code-bound neutral distmap keeps pillows/gates neutral (R0.7).
2. `system_flow.gdshader` receives `i_flow_projected` per river from bake metadata and skips `apply_contextual_flow_slide` for projected fields, with the stagnation-centerline fade ported (R2).
3. `buoyant_manager` binds to a WaterSystem by coverage bounds, samples without per-query allocations, and lets settled bodies sleep (R4.3).
4. `water_ripple_field` steps at most once per `_process`, accumulating delta even when impulses are queued; below `simulation_update_rate` the sim runs proportionally slower by design (R4.1).

## Bake Flow

1. Input: river curve/mesh/steps/baking properties (post-R6: a config object handed to `river_flowmap_baker.gd`).
2. Intermediate passes: table-driven filter passes (R5.1 descriptor: name → shader path, params, required textures, hdr) with one optional-texture policy and one run-pass abort idiom; Jacobi solve GPU-resident post-R7 (fenced per iteration against the Defect-6 ordering hazard).
3. Output textures/resources: unchanged channel semantics (frozen non-goal); first-tile UV2 margin corrected (R0.5).
4. Metadata written: generated from the canonical constants table (R6.2); includes `flow_projected` (already present) and the R1.2 signature additions; signature v28.
5. Preview/consumption: debug material synced from a shared include instead of hand-mirrored code (R3); readback failures surface `last_readback_error` (R0.1).

## Lifecycle, Cleanup, and Re-entry

The bake pipeline's 21 abort points are exactly what this section exists for; R6's own plan.md must redo this in full detail. Track-level answers:

- Success path:
  - Bake finalize binds textures to both materials, writes metadata/signature, emits progress completion; `_flowmap_bake_in_progress` cleared.
- Preflight or early-return path:
  - Preflight failures (1594-1664) return before renderer creation; post-R0.1 they surface `last_readback_error` in the warning text rather than discarding the diagnosis.
- Awaited failure path:
  - Each of the 21 `if not _filter_output_is_valid(...): return` sites aborts the bake; post-R6.1 a run-pass helper owns this idiom in one place so a missed guard is structurally impossible.
- Temporary node/resource ownership:
  - The baker (post-R6.1) owns renderer lifecycle and abort semantics. Pre-R6, R0.3 ensures `tree_exiting` resets `_flowmap_bake_in_progress` and frees the tracked renderer so a mid-bake scene close cannot permanently swallow `bake_texture()` requests.
- Progress, dirty-state, and user feedback:
  - `plugin.gd` `_set_progress_source` guards with `is_instance_valid` (R0.4); progress signal is part of the baker's 2-item interface (R6.1).
- Duplicate or overlapping requests:
  - Guarded by `_flowmap_bake_in_progress` (`river_manager.gd:1656`) — kept, but made un-stickable by R0.3/R6.1.
- Scene reload or runtime boundary:
  - `water_occupancy` survives save/reload like its sibling textures (R1.3); system maps carry a version int so reloads of stale maps warn (R2.4); ripple targets registered via API survive `cleanup_runtime` rebuilds (R4.4).

## Files to Change

High-traffic targets; per-item line references live in `roadmap.md`.

- `river_manager.gd`: R0.1/R0.3 bake guards; R1.3 occupancy serialization; R3.3 revert-table deletion; R5.5 dedup; R6 decomposition (bake pipeline, metadata tables, ripple ownership, validation harnesses out)
- `river.gdshader` / `river_debug.gdshader`: R0.2 foam parity; R0.7 distmap hint comment; R1.4 reserved-interface annotations; R1.5 dead-uniform sweep; R3 include extraction
- `system_flow.gdshader` / `system_map_renderer.gd`: R2.1–R2.2 projected-flow gate + fade; R3.1 flow include; R3.5 default fetching; R5.3 grab consolidation
- `water_helper_methods.gd`: R0.5 margin fix; R0.6 Godot-3 deletions; R4.2 width generation
- `filter_renderer.gd`: R0.1 diagnostics; R5.1 table-driven passes; R7 solve residency
- `river_gizmo.gd` / `plugin.gd`: R0.4 lifecycle fixes
- `water_ripple_field.gd`: R4.1 stepping; R4.4 lifecycle; R4.6 uniform churn
- `buoyant_manager.gd` / `water_system_manager.gd`: R4.3
- `water_system_bake_data.gd`: R2.4 version field
- `river_bake_data.gd`: R5.4
- `probes/*`: R0.9 hardening; RT.1–RT.4 new/extended tooling
- New files: `river_flow_common.gdshaderinc`, `river_surface_common.gdshaderinc`, `flow_pack.gdshaderinc` (R3); `river_flowmap_baker.gd` (R6.1); extracted ripple-ownership and editor-validation scripts (R6.3/R6.4)
- Docs: `architecture-and-features.md`, Data Contract, `river-obstacle-flow-constraints` folder backfill, probe index (R8)

## Documentation Plan

- Code comments needed: dated "reserved for river-height-displacement" annotations (R1.4); `hint_default_black` + code-side-binding comment on `i_distmap` (R0.7); seed-assertion comment pair (RT.4); `_first_enter_tree` intent comment (R4.5); "to be replaced by include" markers if R2 ships before R3 (R2.3).
- Feature docs to update: this folder's files as phases land; `river-future/Roadmap.md` cross-references (R5.2 closes its channel-table item; R8.5 re-scopes its Phase 5 vertex-cost figure to ~622 worst case / ~94 default).
- Architecture or data-flow docs to update: `architecture-and-features.md` rewrite (R8.1 — projection solve, `water_occupancy`, `i_flow_projected`, seven missing FilterRenderer passes).
- Validation docs to update: this folder's `validation.md` as each phase's gate runs; R1.6 one-liner for script-API-only generation behaviors.
- Research citations index: `addons/waterways/docs/research/river-research-citations.md` — consult before research-driven changes; update when new sources are added.
- Migration notes to update: v28 changelog entry (R1); "regenerate all system maps" note (R2.4).

## Validation Strategy

- Automated: RT.1 hash-compare gates R1/R5/R6; RT.3 gates R2; RT.4 seed assertion; hardened probes with stable markers run headless (R0.9). Headless signal is never presented as proof of visible behavior.
- Validation matrix location:
  - `validation.md` — Validation Matrix (one row per phase gate)
- Human-assisted: every pixel/visual gate (constitution rule 8); exact scenes and steps are in each phase's roadmap **Validation** block and must be pasted into the chat message when requested.
- Visual: RT.2 windowed capture + diff for R3; debug-view parity checks for R0.2/R0.7.
- Shader: compile across Forward+/Mobile/Compatibility (R3 gate).
- Editor: undo/no-undo behavior (R0.4), inspector revert spot-checks (R3.3), property-list dump+diff (R5).
- Runtime: ripple low-FPS and hitch-recovery procedure (R4.1), two-system buoyancy binding, sleep behavior (R4.3).
- Performance: frame-time capture for R4.2; bake wall-clock before/after for R7 (recorded as regression budget).
- Manual: mid-bake abort matrix for R6 (scene close, node free, undo-delete at multiple await points).

## Risks

The full risk table is maintained in `roadmap.md` (Risks section). Highest-impact entries:

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Include extraction (R3) subtly changes shader output | Visual regressions across every river | RT.2 pixel-parity before/after; pure-move commits; R0.2 resolves divergences before extraction |
| R6 extraction breaks one of the 21 abort points | Stuck flags / leaked renderers (Defect-3 class) | Run-pass helper owns the abort idiom; abort-matrix validation; own spec/plan first |
| R7 ping-pong hits the Defect-6 ordering hazard | Solve consumes stale iterations — wrong flow fields, hard to notice | Fence every iteration; adversarial ordering test in validation |
| Deleting "dead" shader interface that probes/specs consume (R1.4 class) | Broken debug views and validation suite | Grep shaders + probes + feature specs before any uniform/function deletion |
| Headless validation overstates confidence | "Verified" visuals never actually seen | RT.2 windowed/human-assisted by design; outcomes recorded in validation.md, never assumed-pass |

## Adversarial Plan Review

Complete this with the user after the plan is drafted and before implementation starts.

- Most likely way this plan could damage working behavior: R3's include extraction silently changing shader output (uniform ordering, precision, hint defaults) — mitigated by pure-move commits and RT.2 gating, but the gate is human-assisted and can be skipped under time pressure.
- Project state, generated resource, scene, or workflow most at risk: existing saved bakes (one deliberate v28 invalidation; R0.5 ships a content change *without* a bump — documented exception) and saved system maps (no staleness mechanism at all until R2.4).
- Files or data that are riskier than they look: `river_debug.gdshader` (drift target #1); `_commit_handle` undo path (data-loss class); the 21 bake abort points; probe scripts that assert "dead" interfaces.
- Simpler or safer approach considered: fixing defects ad hoc without the RT tooling — rejected because the phase gates would then rest on unverifiable claims, which is how the audit's four drift failures happened.
- Validation that will catch the riskiest failure early: RT.1 demonstrated on a pre/post-R0.5 pair before R1 starts (proves the hash tool sees real content diffs); RT.2 demonstrated before R3 touches any shader.
- Branch safety reminder sent before code changes: No — must happen at the start of each phase (one branch per phase, cut from `main`, clean tree).

## Migration and Compatibility

- Godot 3 → 4: R0.6 deletes the last Godot 3 leftovers; no legacy APIs may be reintroduced (review checklist item).
- Bake compatibility: pre-v28 river bakes are invalidated once, deliberately, by R1.7 — changelog entry required; R0.5's unbumped content change is retroactively covered by that bump.
- System maps: pre-R2 maps silently carry corrupted projected flow; R2.4's version field + load warning + "regenerate all system maps" migration note is the compatibility mechanism.
- Renderer compatibility: R3's include split must compile and render on Forward+, Mobile, and Compatibility — part of its gate.
- API compatibility: no public API signature changes; `legacy_collision_only`/`curve_only` script-API behaviors kept (R1.6).
