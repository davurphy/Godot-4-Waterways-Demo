# Spec: River Refactor (Hardening + Refactor Track)

## Summary

Turn the 2026-06-12 full-addon code audit (`docs/audit/waterways-code-audit-2026-06-12.md`, bake signature v27) into completed hardening work: fix the eleven verified defects, replace synchronization-by-hand (shader mirrors, constant echoes, revert tables) with single-source-of-truth mechanisms, shrink `river_manager.gd` by extracting the bake pipeline, remove verified-dead code with one deliberate signature bump, restore doc–code coherence, and capture audited performance wins — all gated by validation tooling built first (Phase RT). The ordered, dependency-aware work plan lives in `roadmap.md` in this folder; this spec records what the track must achieve and what is out of scope.

## Current Truth

- Status: Accepted and in execution — Phases R0, RT, R1, R2, R3, R4, and R8 complete and fully closed. R4 implementation landed with automated/headless guard coverage passing (2026-06-13), then the first visible ripple review failed and the impulse scheduling fix landed. The user-visible auto-review rerun and the remaining R4 human-visible suite passed; R5 open; R6/R7 gated on their own docs
- Source of truth for open work: `roadmap.md` phase checklists (R0, RT, R1–R8); `tasks.md` mirrors only the cross-phase process items
- Last meaningful decision: R4 separates impulse render, simulation step, and impulse clear across frames after the first visible review proved the same-frame ordering could hide all ripples (2026-06-13). R4 still accepts slower-but-correct ripple propagation below `simulation_update_rate` rather than multiple same-frame ping-pong steps, and keeps the `Curve3D.get_closest_offset` offset-to-segment lookup layer because the API is not a segment-index replacement. Prior: R8 restored doc–code coherence (2026-06-12), and R2's gate was restructured on measured evidence.
- Known deferred items: R9 (vertex pillow stack → baked/compute) stays on the feature roadmap (`river-future/Roadmap.md` Phase 5); R7 has a decision gate against that same Phase 5 before any work starts
- Current non-goals that are easy to accidentally reopen: deleting the ripple-displacement interface (R1.4 — it is *not* dead); changing data-contract channel semantics; "improving" areas the audit verified clean (audit §10)

## Goals

- Fix all eleven verified defects from the audit, highest-value first (Phase R0 hotfixes; R2 for Defect 1).
- Replace synchronization-by-hand (shader mirrors, constant echoes, revert tables) with single-source-of-truth mechanisms so the four observed drift failures cannot recur (Phases R3, R6.2).
- Shrink `river_manager.gd` (3,807 lines) by extracting the bake pipeline and metadata assembly, per the constitution's module-size rule (Phase R6).
- Remove verified-dead code (the SDF steering set) with a single, deliberate signature bump v27 → v28 (Phase R1).
- Restore doc–code coherence: `architecture-and-features.md`, Data Contract, feature-folder template compliance (Phase R8).
- Capture the audited bake/runtime performance wins without destabilizing the bake contract (Phases R4, R7).
- Build the validation tooling the phase gates depend on, before the phases that depend on it (Phase RT — the hash/parity/comparison probes the gates name do not exist today).

## Non-Goals

- No new user-facing features. Flow-advected displacement, ripple displacement *implementation*, foam kernels, etc. stay on the feature roadmap (`river-future/Roadmap.md`).
- No change to the data contract's channel semantics (slugs, neutrals, AABB registry) — the audit verified these are correct; they are load-bearing and stay frozen.
- No touching `zylann.hterrain` beyond the already-inert importer stubs.
- Areas the audit verified clean (§10) get no speculative "improvement": f16 solve bracketing, atlas column clamps, ripple material ownership, undo registration order, editor/runtime export-safety.
- No deletion of the declared ripple-displacement interface (`ripple_height_at_*`, `i_ripple_displacement_strength`, `i_ripple_refraction_strength`, `i_ripple_impulse_texture`). The audit called it dead; review found it is not (see roadmap R1.4).

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Future sessions should use it as the project-level source list and update it when new external research informs this feature.
- Known scene/data/context facts: current bake signature is v27; `river_manager.gd` is 3,807 lines; ~700 copy-mirrored lines exist between `river.gdshader` and `river_debug.gdshader`, synced only by comments, with four observed drift failures; system maps have no staleness/signature mechanism.
- User-reported observations: R4 visible ripple review initially showed no visible ripple or ripple influence, with the overlay stuck at `Queued 3 emitter impulses`; this became the R4 visible-failure follow-up recorded in `validation.md`. Earlier phases were audit-driven, not bug-report-driven.
- Agent confidence in the premise: high. Every load-bearing audit claim was re-verified against source at the cited lines in an adversarial review (2026-06-12); where audit and code disagreed, the code won and the roadmap notes the correction inline.
- Possible expected-behavior explanations to rule out before patching: per-item premise checks are recorded in `roadmap.md` where they applied (e.g., R0.6 `reorder_params` is a silent no-op so ordering does not actually change; R4.2's "fails on large rivers" concern was withdrawn; R1.4's "dead" interface is live).
- Clarification or challenge already raised with the user: none outstanding; the R7-vs-feature-Phase-5 decision gate is the one open call that needs a deliberate user-visible decision before R7 starts.

## Users and Workflows

### User Story: Add-on Maintainer Hardening

As an add-on maintainer, I want the verified defects fixed and the hand-synced surfaces collapsed into single sources of truth, so that the next feature (feature-roadmap Phase 1–2 work) does not land on top of a god object, drifting shader mirrors, and known defects.

Acceptance criteria:

- All eleven audited defects have a landed fix with its phase's validation recorded in `validation.md`.
- `river.gdshader` / `river_debug.gdshader` shared code lives in includes; no comment-synced mirror blocks remain (R3).
- Bake signature is v28; stale-bake detection fires on pre-bump scenes (R1).
- `river_manager.gd` no longer contains the bake pipeline (R6), with byte-identical bake output proven by RT.1.

### User Story: Game Developer Consuming Baked Data

As a game developer using WaterSystem buoyancy, I want the baked system flow map to respect pressure-projected river flow, so that floating bodies (ducks) stop drifting into boundary-shear paths near obstacles (Defect 1, Phase R2).

Acceptance criteria:

- System-map flow matches river baked flow inside obstacle influence zones (RT.3 probe, angular delta under threshold).
- Loading a stale system map produces a `push_warning` naming the regeneration requirement (R2.4).

## Functional Requirements

- Every change that alters baked content or bake inputs rides the single R1 signature bump (v27 → v28), or explicitly documents why stale-bake detection is acceptable (R0.5's hotfix window is the one sanctioned exception).
- Extraction phases (R5, R6) are behavior-preserving and prove it: byte-identical bake output via RT.1 hash-compare before and after.
- R3 produces two includes (`river_flow_common.gdshaderinc`, `river_surface_common.gdshaderinc`) plus `flow_pack.gdshaderinc` — not one monolithic include (it would inject ~90 unused uniforms and a displacement `vertex()` into the system-map render).
- RT tooling (RT.1 hash-compare, RT.2 pixel-parity capture, RT.3 system-vs-river flow probe, RT.4 seed assertion) exists and is demonstrated on known-good/known-bad pairs before the phases that gate on it.
- Before deleting any shader uniform or function: grep shaders *and* probes *and* feature specs (operating rule from the R1.4 near-miss).
- R6 and R7 do not start without their own `spec.md`/`plan.md`/`validation.md` in this folder (constitution rule 12); R7 additionally requires the feature-Phase-5 compute decision recorded.

## Non-Functional Requirements

- Maintainability: end the 4-edits-per-constant tax (R6.2 canonical bake-constants table); one channel-descriptor implementation instead of five clone helper sets (R5.2); table-driven filter passes (R5.1).
- Performance: width generation interactive on a 50-point river (R4.2); bake solve loses its 40 readback round-trips (R7.1); buoyancy sampling stops allocating per query (R4.3); wall-clock measured before/after and recorded as the regression budget.
- Visual quality: no visual regressions — RT.2 pixel-parity capture gates R3; debug views match the surface after R0.2.
- Godot 4.6+ compatibility: shader compiles across Forward+/Mobile/Compatibility are part of R3's gate; no obsolete Godot 3 APIs reintroduced (R0.6 deletes the leftovers).
- Editor usability: editor remains responsive during bake (R7 gate); click-without-drag no longer pushes undo entries or invalidates bakes (R0.4).
- Runtime usability: ripple sim degrades to slower-but-correct under load, explicitly documented (R4.1); impulse/contact frames remain visible to the ripple shader after queued emitter impulses; settled floating bodies are allowed to sleep (R4.3).
- Extensibility: R5.2's channel-descriptor helper is the feature roadmap's "named per-point channel table" item — landing it here unblocks a third per-point channel without a sixth clone set.

## Add-on Boundary

Editor authoring responsibilities:

- Gizmo/plugin lifecycle fixes (R0.4), editor validation harness extraction (R6.4), inspector revert via `shader_get_parameter_default` (R3.3), bake progress and abort handling (R0.3, R6.1).

Bake/data responsibilities:

- Bake signature v28 and its closed gaps (R1.2), `water_occupancy` serialization symmetry (R1.3), neutral `i_distmap` ImageTexture binding (R0.7), first-tile margin fix (R0.5), system-map version field (R2.4), bake pipeline extraction to `river_flowmap_baker.gd` (R6.1), GPU-resident solve (R7).

Runtime responsibilities:

- `system_flow.gdshader` projected-flow gating + stagnation fade (R2.1–R2.2), buoyancy coverage binding and allocation fixes (R4.3), ripple sim stepping (R4.1), shared shader includes consumed by river/debug/system shaders (R3).

Shared code must not depend on:

- Editor-only state (the extracted baker is RefCounted, fed a config object + progress signal); legacy Godot 3 APIs (R0.6 removes the last `Array.invert()`-era leftovers); one scene layout or one material preset (fallback literals in `system_map_renderer.gd` replaced by `shader_get_parameter_default`, R3.5).

## Data and Extension Model

Users should be able to:

- Keep existing river bakes valid through every phase except the single R1 v28 bump (and R0.5's documented hotfix exception); regenerate system maps once after R2 with a load-time warning guiding them.

Extension points:

- `river_flow_common.gdshaderinc` / `river_surface_common.gdshaderinc` / `flow_pack.gdshaderinc` become the canonical shader building blocks (R3); the pass-descriptor table (R5.1) and channel-descriptor helper (R5.2) become the canonical extension seams for new filter passes and per-point channels.

Override rules:

- Material parameter reverts come from `RenderingServer.shader_get_parameter_default` — the shader is the single source of defaults; the `MATERIAL_PARAMETER_REVERT_OVERRIDES` table is deleted (R3.3, verified safe: all sampled entries match shader defaults exactly).

Shared systems must not hard-code:

- River-shader defaults re-echoed as fallback literals (`system_map_renderer.gd:118-127`, fixed by R3.5); `OCCUPANCY_SPEED_RAMP_FULL` in 7 copies (centralized by R3.5); the ~80 `RIVER_*` constants echoed by hand into three metadata dictionaries (table-driven by R6.2).

## Acceptance Tests

- R0: rebake demo river → Foam Mix debug view matches the surface; null-distmap river renders neutral pillows/gates; mid-bake scene close then successful re-bake; click-without-drag produces no undo entry; hardened probes pass headless with markers.
- RT: each tool demonstrated on a known-good/known-bad pair (RT.1: two bakes of the same scene → identical; pre/post-R0.5 → flags exactly the margin region).
- R1: stale-bake detection fires on a pre-bump scene; RT.1 shows changes only in regions explained by R0.5/R1.3; grep proves zero remaining code references to deleted constants.
- R2: RT.3 shows system-map flow matching river baked flow inside obstacle influence zones; human-assisted duck-drift check.
- R3: shader compile on all three renderers; RT.2 pixel parity before/after; system-map regeneration parity; inspector revert spot-checks.
- R4: visible ripple auto-review shows localized impulse/contact marks and influence rings at forced 20 FPS; ripple sim remains artifact-free at the documented reduced rate; 2 s hitch recovery without step burst; width arrays identical to brute-force on demo rivers (array diff); two-system buoyancy binds by coverage; settled body sleeps.
- R5/R6: RT.1 byte-identical bake output; inspector property list unchanged (dump+diff); undo round-trip; R6 abort matrix leaves no stuck flags/leaked renderers/orphan viewports; metadata/signature/settings dictionaries diff empty.
- R7: solve within f16 epsilon of CPU path; adversarial ordering test proves the Defect-6 fence; bake wall-clock recorded.

## Visual Validation Requirements

- Per constitution rule 8, visual validation is human-assisted: each phase's roadmap checklist names the exact scene, steps, and expected visuals; results recorded in this folder's `validation.md`.
- Rendered-pixel capture probes (RT.2 and its consumers) require a window — headless rendering is unreliable per the constitution's own caveat; treat all pixel-parity gates as windowed/human-assisted by default.
- Key human-visible checks: Foam Mix debug parity (R0.2), neutral pillows/gates with null distmap (R0.7), duck drift near obstacles (R2), before/after surface parity on the demo scene (R3), localized ripple impulse/contact and visible-influence rings under forced low FPS (R4.1).

## Performance Requirements

- R4.2: curve editing on a 50-point river stays interactive (frame-time capture before/after).
- R4.3: zero per-query Dictionary allocations in `_sample_system_map`; settled bodies sleep.
- R7.1: eliminate all 40 readback/re-upload round-trips; roughly halve awaited frames (~80 → ~40). Not "readback once" as a frame-count claim.
- R7: bake wall-clock measured before/after on a fixed scene and recorded in `validation.md` as the regression budget; editor responsive during bake.

## Open Questions

- R7 decision gate: is feature-roadmap Phase 5 (RenderingDevice compute migration) near-term — fold R7 into that spec — or distant — do R7 as specced and accept it as throwaway-by-design? Must be decided and recorded before R7 starts.
- R2/R3 merge: best merged into one branch (the flow include *is* the structural fix for Defect 1); keep R2 separable only if in-flight buoyancy work needs the tactical fix sooner. Decide when R1 lands.
- R0.5 / R0.7 landing site: fold into R1 / R3 respectively if those phases are imminent at hotfix time.

## Resolved Questions

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Is the ripple-displacement uniform set dead code? | No — annotate, do not delete | 2026-06-12 | `river_debug.gdshader:899,984` samples it; probes assert it; `river-height displacement/initial_research.md` designs against it (roadmap R1.4) |
| Can `i_distmap`'s neutral be expressed with a built-in hint? | No — code-side neutral ImageTexture required | 2026-06-12 | Neutral ≈ (0.75, 0.25, 0.0, 0.5); no `hint_default_*` matches (roadmap R0.7) |
| Is `MATERIAL_PARAMETER_REVERT_OVERRIDES` deletion safe? | Yes — but the planned fallback was dead | 2026-06-12 | All entries match shader defaults; execution found `ShaderMaterial.property_can_revert/get_revert` never worked for the internal material (remap cache fills only when the material itself is inspected) — the table was the only working revert source; replacement calls `RenderingServer.shader_get_parameter_default` directly (null headless → revert checks are windowed) |
| Was the pre-R2 influence p90 (25.5°/28.9°) the Defect-1 slide re-bend? | No — misattributed | 2026-06-12 | A/B rendering (slide gated vs forced): 0 differing texels on Demo, 4.6k at mean 3.3° on the obstacle scene; the 23–27° floor is 8-bit quantization/resampling noise of the stilled low-magnitude ring and survives the (correct, landed) fix. Mechanism gated by `system_flow_projected_gate_probe.gd`; RT.3 influence limit recalibrated 20→35 |
| One shader include or two? | Two (flow + surface) plus `flow_pack` | 2026-06-12 | Monolithic include would inject ~90 unused uniforms + displacement `vertex()` into system-map render (roadmap R3.1) |
| Does R0.4's no-change guard need epsilon comparison? | No — exact equality suffices | 2026-06-12 | Click-without-drag produces bitwise-identical curve-state dictionaries |
| Does removing the `reorder_params` call change inspector ordering? | No | 2026-06-12 | The call has been a silent no-op since the Godot 4 port (roadmap R0.6) |
| Is `generate_river_width_values`' `closest_dist := 4096.0` seed a large-river bug? | No — concern withdrawn | 2026-06-12 | Samples lie on the curve; the seed is effectively unreachable (roadmap R4.2) |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-12 | Run a hardening/refactor track (R0–R8) before/interleaved with feature-roadmap Phase 1–2 | Audit conclusion: the next feature should not land on the current shape of `river_manager.gd`, the hand-synced shaders, or the unfixed defects |
| 2026-06-12 | Single signature bump v27 → v28, owned by R1; all bake-content changes ride it | Avoid repeated bake invalidation; make staleness deliberate and reviewable |
| 2026-06-12 | Build validation tooling (RT) before the phases that gate on it | The hash/parity/comparison probes the gates name do not exist today (verified against `probes/`) |
| 2026-06-12 | R4.1 accepts slower-but-correct ripple stepping under load | One step per `_process` fixes the stale ping-pong read and unbounded catch-up queue; full-rate-under-load deferred |
| 2026-06-13 | R4.1 separates impulse render, sim step, and impulse clear across frames | User visible review showed no ripple/influence because same-frame ordering could clear or miss the impulse texture before sampling; frame separation preserves shader-visible impulses |
| 2026-06-12 | R5 before R6; R6 before R7 | Extract already-deduplicated code, not duplicated code; optimize the extracted baker, not the god object |
