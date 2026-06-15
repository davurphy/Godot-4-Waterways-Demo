# Next Session Handoff

## Message To Next Session

Current branch: `r6` (2026-06-14). This is the *hardening and refactor* track derived from the 2026-06-12 full-addon code audit. The track's working folder is `../spec-driven/features/river-refactor/` - read in this order:

1. `session-handoff.md` (dashboard: current truth, next action)
2. `roadmap.md` (**the canonical work plan** — phases R0–R8 with per-item line references, gates, sequencing, risk register; work its checklists in place)
3. `validation.md` (what is currently proven; the validation matrix has one row per phase gate)
4. `tasks.md`, `spec.md`, `plan.md`, `research.md` as needed

State: **Phases R0, RT, R1, R2, R3, R4, R5, R6, and R8 have implementation/automated validation complete.** Signature is v28, system maps are v1, shared shader includes are in place, R4 runtime/editor robustness is closed, R5 structural GDScript dedup is behavior-preserving, and R6 `river_manager.gd` decomposition plus R6.5 cleanup preserve generated output plus canonical dictionary/API/signal/property surfaces under automated validation.

Next work, in order:

1. **R7 implementation prep** - research current official Godot RenderingDevice docs, then fill the fixed baseline/fixture commands in `river-refactor/r7/validation.md` before any code changes.
2. Keep using the feature handoff (`river-refactor/session-handoff.md`) as the dashboard; it has the latest validation details and scratch-artifact notes.

Recent markers/evidence: `R6_R65_SURFACE_PROPERTY_DIFF_OK`, `R6_FINAL_GENERATED_TEXTURE_DIFF_OK`, `R6_FINAL_RT1_GENERATED_TEXTURE_DIFF_OK`, `R6_FINAL_CANONICAL_SURFACE_DIFF_OK`, `R6_R62_CONSTANTS_SHADOW_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, `FILTER_RENDERER_LOAD_OK shader_paths=19`, `SYSTEM_FLOW_PROJECTED_GATE_OK`, `R5_PROPERTY_LIST_MATCH=True`, RT.1 scratch rebake texture hashes identical for both generated demo river bakes, `R4_VISIBLE_AUTO_REVIEW_DONE`, `BAKE_HASH_PROBE_OK`/`BAKE_HASH_COMPARE_OK`, `FLOW_SOLVE_SEED_ASSERT_OK`, `DISTMAP_NEUTRAL_BINDING_OK`, `SYSTEM_FLOW_COMPARE_OK`, `ARROW_NEUTRAL_CELLS_PROBE_OK`, `ARROW_DIRECTION_OUTLIER_PROBE_OK`, `RIVER_FLOWMAP_SEAM_PROBE_OK`.

Run pattern: Godot 4.6.3 console at `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe` with `--path <project root> --script res://... -- key=value`, APPDATA/LOCALAPPDATA redirected to `.codex-research\godot-user` (exact pattern in `river-refactor/validation.md`). Bakes/screenshots need a window — NOT headless; pure resource reads are headless-fine.

Manual residual note: the user attempted the full `res://Demo.tscn` R6 editor undo-delete workflow on 2026-06-14, but the bake saturated CPU/GPU enough that the editor lag prevented deleting `WaterSystem/Water River`. Treat this as infeasible on the full scene, not as a product-behavior failure; use a lower-cost fixture or targeted editor harness if that editor-stack variant must close later.

## Blockers Needing The User

None in landed code. R7's compute-vs-SubViewport decision is recorded as compute-first and R7 phase docs exist; implementation remains blocked on official RenderingDevice research and baseline/fixture setup.

## Lessons From The Last Session (2026-06-13)

- Full filesystem scratch copies were needed for R5 RT.1 because `git worktree add` was blocked by `.git` write permissions and `git archive` lacked ignored import-cache/assets needed for windowed rebakes. Scratch copies remain under `.codex-research/r5-rt1-*` because sandbox policy blocked recursive cleanup.
- RT.1's R5 gate is per-texture content identity, not raw `.res` file MD5. ResourceSaver produced different `.res` file hashes between baseline/current scratch copies, while all six generated `RiverBakeData` texture hashes matched exactly.
- The R5 guard intentionally triggers the existing width "too few entries" sanitizer warning while proving padding behavior; the warning is expected for that probe.
- Keep the older lessons alive: debug-view visual checks are masked whenever a change invalidates the flowmap; run real probes after shared-script edits; PowerShell 5.1 can mangle embedded quotes in commit messages.

## Code Audit (2026-06-12)

The audit at `../audit/waterways-code-audit-2026-06-12.md` remains the source for defect details. Of its 11 defects: 2, 3, 4, 5, 8, 9, 10, 11 are fixed in R0; Defect 1 is fixed in R2; Defects 6-7 are fixed in R4. The dominant systemic risk from hand-synchronized mirrors is addressed structurally by R3 shader includes, the R5 GDScript descriptor/helper tables, and R6.2's live constants table.

## Durable Cautions (kept from earlier sessions)

- `generate_system_maps`' internal save is editor-only and silently no-ops under `--script` runs — always save explicitly (`water_system_rebake_probe.gd` does) and check the printed `save_error`.
- Failed tooltip approach to avoid: do not retry the inspector-plugin fallback that wrapped default inspector editors for generated `mat_pillow_*` fields from `_parse_property()` to attach tooltips — it destabilized the editor. Research a documented Godot 4.6 approach first (scoped custom `EditorProperty` tested in isolation).
- The hterrain packed-texture importers under `addons/zylann.hterrain/tools/packed_textures/` are Godot 4.6-compatible *unavailable stubs*, not working importers. If `.packed_tex` assets are ever needed, implement a proper Godot 4 importer as a separate task.
- Pillow/eddy feature work has feature-local docs at `../spec-driven/features/river-pillows/` and `river-eddies/` — treat those as source of truth for that work; their probes have their own `PILLOW_*` markers.
- The feature roadmap (`../spec-driven/features/river-future/Roadmap.md`) and Data Contract remain the planning spine for *feature* work; the refactor track interleaves with it per `river-refactor/roadmap.md`'s "Sequencing and Dependencies".
