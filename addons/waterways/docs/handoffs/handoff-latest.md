# Next Session Handoff

## Message To Next Session

Current branch: `river-refactor`, clean tree, all work committed (2026-06-12). This is the *hardening and refactor* track derived from the 2026-06-12 full-addon code audit. The track's working folder is `../spec-driven/features/river-refactor/` — read in this order:

1. `session-handoff.md` (dashboard: current truth, next action)
2. `roadmap.md` (**the canonical work plan** — phases R0–R8 with per-item line references, gates, sequencing, risk register; work its checklists in place)
3. `validation.md` (what is currently proven; the validation matrix has one row per phase gate)
4. `tasks.md`, `spec.md`, `plan.md`, `research.md` as needed

State: **Phase R0 (all 9 defect hotfixes) is complete and user-validated.** RT.1 (`probes/bake_hash_probe.gd` — per-texture hash + diff with per-channel deltas and diff-rect localization) and RT.4 (`probes/flow_solve_seed_assert_probe.gd`) are built and demonstrated. The demo bakes were regenerated post-R0.5 and committed as the new baseline (still signature v27). Demo-scene bake-resource UID references and the probes' `.uid` sidecars are fixed/tracked.

Next work, in order:

1. **RT.3** — system-vs-river flow comparison probe (gates R2). Headless-able: pure resource reads. The hard part is mapping world positions to river UV2-atlas UVs; look at `docs/spec-driven/features/river-flowmap-seams/probes/river_flowmap_world_sample_probe.gd` for existing world-sampling machinery before writing anything new.
2. **RT.2** — pixel-parity capture harness on `debug_view_capture_probe.gd` (gates R3; windowed/human-assisted by design).
3. **R1** — dead-code purge + the single v27→v28 signature bump (unblocked by RT.1). **Warn the user before starting: the bump invalidates every saved river bake.** Operating rule: before deleting any shader uniform or function, grep shaders *and* probes *and* feature specs (R1.4: the ripple-displacement interface is live — annotate, never delete).

Probe markers now passing: `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK` (diagnostic by default; `max_logical_delta=` arg turns it into a gate), `BAKE_HASH_PROBE_OK`/`BAKE_HASH_COMPARE_OK`, `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, `REBAKE_PROBE_OK`.

Run pattern: Godot 4.6.3 console at `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe` with `--path <project root> --script res://... -- key=value`, APPDATA/LOCALAPPDATA redirected to `.codex-research\godot-user` (exact pattern in `river-refactor/validation.md`). Bakes/screenshots need a window — NOT headless; pure resource reads are headless-fine.

## Blockers Needing The User

None right now. Upcoming: the R1 signature bump should land at a quiet point (it invalidates user bakes); the R7 phase has a decision gate (fold into feature-roadmap Phase 5 compute migration, or accept throwaway SubViewport work) that must be recorded before R7 starts.

## Lessons From The Last Session (2026-06-12)

- **Debug-view visual checks are masked whenever the change also invalidates the flowmap**: `river_debug.gdshader:1098` paints magenta/cyan invalid-indicator stripes over every view when `i_valid_flowmap` is false, and all distmap-driven visuals in both shaders are gated on validity. Prefer binding/content probes (`distmap_neutral_binding_probe.gd` is the model) for anything in that shape.
- GDScript `:=` cannot infer from `max()`/Color-subscript — both caused parse errors caught only by actually running a probe. Run a headless probe (not just `--check-only`) after editing shared scripts.
- PowerShell 5.1 mangles embedded double quotes in `git commit -m` here-strings — keep commit messages free of `"`.
- Rebakes are not byte-deterministic (GPU variance), so RT.1 diffs after any rebake show broad small deltas in the filter-derived textures; `terrain_contact_features`/`bank_response_features` were byte-identical across the R0 rebake. Bit-identity claims only hold for *no-rebake* refactors (R5/R6's actual gate).

## Code Audit (2026-06-12)

The audit at `../audit/waterways-code-audit-2026-06-12.md` remains the source for defect details. Of its 11 defects: 2, 3, 4, 5, 8, 9, 10, 11 are fixed (Phase R0); Defect 1 (`system_flow.gdshader` re-bends projected flow) is Phase R2; Defects 6–7 (ripple stepping) are Phase R4.1. The dominant systemic risk — hand-synchronized mirrors — is addressed structurally by R3 (shader includes) and R6.2 (constants table), not yet started.

## Durable Cautions (kept from earlier sessions)

- `generate_system_maps`' internal save is editor-only and silently no-ops under `--script` runs — always save explicitly (`water_system_rebake_probe.gd` does) and check the printed `save_error`.
- Failed tooltip approach to avoid: do not retry the inspector-plugin fallback that wrapped default inspector editors for generated `mat_pillow_*` fields from `_parse_property()` to attach tooltips — it destabilized the editor. Research a documented Godot 4.6 approach first (scoped custom `EditorProperty` tested in isolation).
- The hterrain packed-texture importers under `addons/zylann.hterrain/tools/packed_textures/` are Godot 4.6-compatible *unavailable stubs*, not working importers. If `.packed_tex` assets are ever needed, implement a proper Godot 4 importer as a separate task.
- Pillow/eddy feature work has feature-local docs at `../spec-driven/features/river-pillows/` and `river-eddies/` — treat those as source of truth for that work; their probes have their own `PILLOW_*` markers.
- The feature roadmap (`../spec-driven/features/river-future/Roadmap.md`) and Data Contract remain the planning spine for *feature* work; the refactor track interleaves with it per `river-refactor/roadmap.md`'s "Sequencing and Dependencies".
