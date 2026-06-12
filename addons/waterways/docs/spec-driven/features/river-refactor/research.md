# Research: River Refactor (Hardening + Refactor Track)

## Purpose

Establish, with verified evidence, what is actually broken, dead, duplicated, or slow in the waterways add-on, so the refactor track fixes real defects and deletes only truly dead code. The research for this track is the 2026-06-12 full-addon code audit plus the adversarial review that re-verified every load-bearing claim against source. This file records the outcome and the corrections; the audit document itself is the primary artifact.

Use `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index. For Godot-specific implementation work (RenderingServer draws in R7, `Curve3D.get_closest_offset` in R4.2, `shader_get_parameter_default` in R3.3), search current official Godot documentation before coding and record sources that affect implementation here or in the shared index.

## Current Research Outcome

- Status: Complete (audit + adversarial review, both 2026-06-12); per-phase deep research deferred to R6/R7's own spec/plan cycles
- Recommendation: execute the phased plan in `roadmap.md` — R0 hotfixes and RT tooling first, one signature bump in R1, includes in R3, decomposition in R6, GPU solve in R7 behind a decision gate
- Confidence: high — every load-bearing claim verified at cited source lines; where audit and code disagreed, the code won and the roadmap notes the correction
- Biggest unknown that remains: whether feature-roadmap Phase 5 (compute migration) is near-term or distant — determines whether R7's SubViewport ping-pong work is worth doing at all (decision gate)
- Decision or plan section this research unlocked: the entire `roadmap.md`; spec.md Resolved Questions table

## Questions

- What are we trying to learn? Which audit findings survive adversarial verification, and in what order the surviving work should land so each phase's gate exists before the phase does.
- What assumptions need verification? "Verified dead" claims (one failed — R1.4); "drop-in replacement" claims (one failed — R4.2's `get_closest_offset` needs an offset→segment mapping layer); feasibility of plumbing per-river uniforms through `system_map_renderer.gd` (confirmed — fresh per-river ShaderMaterial at lines 101-136).
- What user or agent premise might be wrong? Documented per item; all known corrections are already folded into the roadmap (see Context Challenge Notes).
- What Godot 4.6+ constraints could change the design? No built-in texture hint can express the distmap neutral (R0.7); two `UPDATE_ONCE` SubViewports in one frame render in non-dependency order (the Defect-6 mechanism, constraining both R4.1 and R7.1); uniforms-in-includes is supported and proven in-repo.
- Which parts are editor-only, runtime-only, or shared? Mapped in `plan.md` Layers/Boundary sections.
- What legacy Waterways behavior should be preserved, changed, or removed? Removed: the Godot 3 leftovers (R0.6) and the dead SDF steering set (R1.1). Preserved: everything the audit verified clean (§10), the data contract's channel semantics, and the script-API-only generation behaviors (R1.6).

## Flow-Map and Water Tool Patterns

Not applicable as external research — this track changes no channel semantics and adds no water-behavior features. The relevant "patterns" are internal:

- The projection-solve obstacle mechanism (not SDF steering) is the current truth that R8.1 must document.
- The `v*0.5+0.5` flow encode/decode is re-implemented in ≥10 places; canonical copies are `water_helper_methods.gd:388` and `flow_solve_common.gdshaderinc:20-26` (R3.2 extracts `flow_pack.gdshaderinc`).
- All three solve encodings have enc(0)=0.5, matching the neutral pressure seed `Color(0.5,…)` at `river_manager.gd:2084` — RT.4 turns this cross-language invariant into a probe assertion.

## Godot 4.6+ Findings

- SubViewport rendering: two SubViewports flagged `UPDATE_ONCE` in one frame render in non-dependency order → stale ping-pong reads (Defect 6). Any GPU iteration scheme (R7.1) must fence each iteration with ≥1 awaited frame (alternating viewports across frames) or drive draws explicitly via `RenderingServer`.
- `RenderingServer.frame_post_draw` is the candidate await primitive for reducing per-pass waits (R7.2 — test before relying on it).
- Shader includes: `shader_type spatial` includes carrying uniform declarations are proven in-repo (`atlas_column_clamp.gdshaderinc`, included by 5+ filters, declares the `atlas_columns` uniform) — R3.1's design rests on this.
- Texture hints: Godot offers only `hint_default_white/black/transparent`; none can express the distmap neutral ≈ (0.75, 0.25, 0.0, 0.5) derived from the decode at `river.gdshader:950-953` — hence R0.7's code-side neutral ImageTexture.
- `RenderingServer.shader_get_parameter_default` is already used at `river_manager.gd:1413` and replaces the hand-maintained revert table (R3.3) and `system_map_renderer.gd`'s re-hardcoded fallback literals (R3.5).
- `Curve3D.get_closest_offset` returns one baked-length scalar in curve-local space — not the (segment index, interpolate) pair the width code needs; R4.2 maps offset → segment+t via a precomputed per-control-point offset table + binary search.
- Headless rendering is unreliable per the constitution's own caveat — all pixel-parity gates are windowed/human-assisted by default.

## Legacy Waterways Reference

- Relevant legacy files: none active — the Godot 3 leftovers are `reorder_params`, `last_prefix_occurence` (contains the `Array.invert()` crash at `water_helper_methods.gd:1800` and a `"Texture"` vs `"Texture2D"` dead match), and `sum_array` (zero callers).
- Behavior to preserve: inspector ordering is unaffected by removing the `reorder_params` call at `river_manager.gd:601` — it has been a silent no-op since the Godot 4 port.
- Behavior to change: none (deletions only).
- Obsolete APIs to avoid: `Array.invert()` and any other Godot 3 API — review checklist enforces no reintroduction.
- Risks discovered in the audit: the eleven defects and four shader drift failures; see `docs/audit/waterways-code-audit-2026-06-12.md`.
- What belongs in active Godot 4.6+ code: everything else in the add-on.
- What should remain legacy-only: nothing — this track deletes rather than quarantines.

## Options

### Option A: Ad hoc defect fixing (no tooling, no phase gates)

- Benefits: fastest first fix landed; no RT investment.
- Costs: every behavior-preserving claim ("byte-identical bake") rests on assertion, not measurement; signature bumps happen per-fix, repeatedly invalidating user bakes.
- Risks: this is the regime that produced the four shader drift failures and the silent signature gaps; extraction phases (R5/R6) become un-reviewable.
- Fit for Waterways: poor — rejected.

### Option B: Phased plan, tooling-first, single signature bump (chosen)

- Benefits: every gate is measurable before the phase needing it; bake invalidation happens once; hand-synced surfaces are eliminated structurally, not patched; heavyweight phases (R6/R7) get their own spec/plan per constitution rule 12.
- Costs: RT tooling is days of up-front work; R0.5 ships one content change without a bump (documented, retroactively covered by v28).
- Risks: managed per the roadmap risk table — the dominant ones are R3 extraction parity, R6 abort points, and R7's ordering hazard.
- Fit for Waterways: good — adopted as `roadmap.md`.

### Option C: Jump straight to compute migration (skip R7's SubViewport interim, fold into feature Phase 5)

- Benefits: no throwaway SubViewport work.
- Costs: bake performance stays poor until Phase 5 lands; Phase 5 is currently unscheduled.
- Risks: scope coupling between refactor and feature tracks.
- Fit for Waterways: undecided — this is exactly R7's decision gate; record the choice in this folder before R7 starts.

## Recommendation

Execute Option B (`roadmap.md`): R0 + RT in parallel, R1's single v28 bump, R2/R3 (preferably merged — the flow include *is* the structural fix for Defect 1), R4/R5 absorbing idle time, then R6 and R7 behind their own spec/plan cycles, R8 docs interleaved after R1. Hold Option C's question open until the R7 gate.

## Risks and Unknowns

- R7-vs-Phase-5 timing (the one open decision).
- Whether `frame_post_draw` behaves as an await primitive across renderers (R7.2 tests it).
- Whether R5.2's channel generalization can preserve undo integrity (port the existing flow_speeds undo probe before switching widths over).
- The full risk register is in `roadmap.md` (Risks).

## Context Challenge Notes

The adversarial review *was* the context challenge, and it overturned audit claims — these corrections are load-bearing and already folded into the roadmap:

- Possible misread context: "ripple-displacement interface is dead" (audit claim).
- Evidence: `river_debug.gdshader:899,984` samples `i_ripple_impulse_texture`; `ripple_debug_parity_probe.gd:69` and `ripple_material_ownership_probe.gd` assert it; `water_ripple_field.gd:897` sets it every frame; the height-displacement feature folder designs against the rest.
- Confidence: high — interface is live; R1.4 annotates instead of deleting.
- Quick check before patching: the standing operating rule born from this miss — before deleting any shader uniform or function, grep shaders *and* probes *and* feature specs.
- User-facing note or question to raise: none outstanding; further corrections (R0.6 ordering no-op, R4.2 seed concern withdrawn, R0.4 exact-equality sufficiency) are recorded in `spec.md` Resolved Questions.

## Sources

- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index.
- `docs/audit/waterways-code-audit-2026-06-12.md`: full-addon audit (bake signature v27) — primary research artifact for this track.
- Adversarial code review (2026-06-12): verification pass over the audit; corrections noted inline in `roadmap.md`.
- `docs/spec-driven/features/river-future/Roadmap.md`: feature roadmap (Phases 0–5) — interaction points: R5.2 = its channel-table item; R7 decision gate vs its Phase 5; R8.5 re-scopes its vertex-cost figure.
- `docs/spec-driven/features/river-height displacement/initial_research.md:113,188,355`: declared consumer of the ripple-displacement interface (R1.4 evidence).
