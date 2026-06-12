# Next Session Handoff

## Message To Next Session

Current branch: `river-obstacle-flow-constraints` (all work uncommitted in the working tree, including this session's). The branch contains three layers of work, in order: (1) the occupancy + pressure-projection flow bake, implemented and tuned — see `../spec-driven/features/river-obstacle-flow-constraints/implementation-plan.md` (§6 tuning, §7 signature history); (2) Roadmap Phase 1 foundations (custom AABB, tight-bend mesh robustness, smoothstep widths, data contract); (3) Roadmap Phase 2's per-point flow speed (`flow_speeds` array → post-projection bake scale pass). The river bake source signature is now **27**; both demo river bakes and the WaterSystem map are freshly regenerated at v27 with all projection penetration gates passing.

The planning spine for current and future work lives in `../spec-driven/features/river-future/`:

- `Roadmap.md` — phased plan (Phase 0–5 + backlog), with completed items annotated with what/where/verification.
- `Crest Spline System Comparison.md` — Crest 5 spline system vs Waterways, verified against pasted Crest source; the adopt/reject rationale behind Phases 1–2.
- `Data Contract.md` — channel semantics/units/encodings for every baked texture + change rules. Keep it current when channels or signatures change.
- `Crest Reuse and Portability Feasibility.md` — kernel catalogue for Phases 3–4.

**Shared general-purpose probes live at `addons/waterways/probes/` — start there; its README documents args and markers for all of them.** The set: `rebake_probe.gd` (the standard regenerate-bakes tool after a signature bump: river bakes + WaterSystem map, explicit saves), `debug_view_capture_probe.gd` (screenshot any debug view(s) via curve fly-along or the scene's Phase0B review cameras; `-- views=list` prints the menu), `bake_inspect_probe.gd` (headless channel stats + PNG for any bake texture), plus shared copies of the seam regression gate and the two flow-arrow diagnostics. Feature-specific gates stay in feature folders (e.g. `river_obstacle_projection_rebake_probe.gd` for penetration gates).

Run pattern: Godot 4.6.3 console at `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe` with `--path <project root> --script res://... -- key=value` (bakes/screenshots need a window — NOT headless; pure resource reads can be headless). Roadmap validation probes under `river-future/probes/`: `custom_aabb_probe.gd` (headless OK) and `flow_speed_scale_probe.gd` (bakes; loads the saved neutral bake as baseline to stay under the 10-minute timeout — keep that pattern for future bake probes). Markers: `CUSTOM_AABB_PROBE_PASS`, `FLOW_SPEED_SCALE_PROBE_OK`, `RIVER_OBSTACLE_PROJECTION_PROBE_OK`, `REBAKE_PROBE_OK`, `DEBUG_VIEW_CAPTURE_OK`, `BAKE_INSPECT_OK`.

## Blockers Needing The User

1. **Phase 0 merge gate**: the user has not yet done the visual pass over the screenshot locations (implementation plan §4.4) — required before merging the branch to `main`.
2. **Commit strategy**: everything is uncommitted; the user must decide whether roadmap Phases 1–2 ride along in the branch merge or get split out.

## Code Audit (2026-06-12)

A full audit of the shipping code lives at `../audit/waterways-code-audit-2026-06-12.md`: 11 verified defects (worst: `system_flow.gdshader` re-bends pressure-projected flow in the system map the ducks read; foam debug view renders different math than the surface; stuck bake flag on mid-bake scene close), a prioritized 18-item fix list, and a verified-healthy list. The dominant systemic risk is hand-synchronized mirrors (river↔debug shaders, constants echoed into 3 metadata dicts, flow packing in 10 places) — four mirrors have already drifted. Start any cleanup session from that doc's "Prioritized Recommendations".

## Recommended Next Moves

- Phase 2 remainder: generalize `widths`/`flow_speeds` into a named per-point channel table with the override-vs-weight convention (Roadmap Phase 2 bullets 2–3); gizmo handles for `flow_speeds` are also deferred (inspector-only today).
- Or start Phase 3a (minimal flow-advected height displacement) — its custom-AABB prerequisite is done. Follow the phased plan in `River Flow Map Displacement Research.md`.

## Durable Cautions (kept from earlier sessions)

- `generate_system_maps`' internal save is editor-only and silently no-ops under `--script` runs — always save explicitly (`water_system_rebake_probe.gd` does) and check the printed `save_error`.
- Failed tooltip approach to avoid: do not retry the inspector-plugin fallback that wrapped default inspector editors for generated `mat_pillow_*` fields from `_parse_property()` to attach tooltips — it destabilized the editor. Research a documented Godot 4.6 approach first (scoped custom `EditorProperty` tested in isolation).
- The hterrain packed-texture importers under `addons/zylann.hterrain/tools/packed_textures/` are Godot 4.6-compatible *unavailable stubs*, not working importers. If `.packed_tex` assets are ever needed, implement a proper Godot 4 importer as a separate task.
- Pillow/eddy feature work has feature-local docs at `../spec-driven/features/river-pillows/` and `river-eddies/` — treat those as source of truth for that work; their probes have their own `PILLOW_*` markers.
