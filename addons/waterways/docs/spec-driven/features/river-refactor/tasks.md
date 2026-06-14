# Tasks: River Refactor (Hardening + Refactor Track)

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

The canonical per-item checklists live in `roadmap.md` (phases R0, RT, R1–R8) and are worked **in place there** — check items off in the roadmap, note branch names next to phase headings, and record validation results in `validation.md`. This file tracks the cross-phase process work and the current slice; do not duplicate the roadmap's item lists here.

## Current Truth

- Latest update, 2026-06-14: R6 `river_manager.gd` decomposition and R6.5 cleanup/interface tightening have validation on branch `r6`. Generated-output, canonical dictionary/API/signal/property, R5/R4/filter-renderer/system-flow, parser/check-only, whitespace, and R6.5 surface/property gates passed.
- Current status: In progress
- Current implementation slice: Phases R0, RT, R1, R2, R3, R4, R5, R6, and R8 have implementation/automated validation complete. R6 keeps bake signature version 28 and preserves RiverManager public/surface behavior while moving bake, constants, runtime ripple ownership, and editor validation internals behind helper scripts.
- Remaining open task count: optional lower-cost editor/visible R6 checks, R7 implementation research/baseline setup, and R7 implementation remain open.
- Last passing validation: 2026-06-14 R6.5 focused validation (`R6_R61F_PARSER_OK`, `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28`, `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r65 files=10`, `R6_R65_SURFACE_PROPERTY_DIFF_OK files=4 baseline=post-r6-final current=post-r6-r65 surface_line_numbers=normalized`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R4_RUNTIME_ROBUSTNESS_PROBE_OK`, `git diff --check`)
- Next recommended action: before any R7 code, research current official Godot RenderingDevice docs and fill the R7 baseline/fixture commands in `r7/validation.md`
- Known deferred work: R9 (vertex pillow stack) stays on the feature roadmap; R7 implementation is blocked on official RenderingDevice research and baseline setup; optional user decision logged in validation.md — whether system_flow should also apply occupancy stilling/wake damping to match duck-read magnitudes to the river surface

## Open Work

Use this section as the canonical checklist for unfinished *process* work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff. Item-level work is tracked in `roadmap.md`.

- [x] Phase R0 — Defect Hotfixes, implementation (9/9 items landed on `river-refactor`, 2026-06-12). R0.2 (the R3 prerequisite) is in.
- [x] Phase R0 — validation closed 2026-06-12: user confirmed foam parity, mid-bake close recovery, and no-op click; null-distmap covered by `distmap_neutral_binding_probe.gd` (visual check unreachable — see validation.md).
- [x] Phase RT — Validation Tooling complete (RT.1–RT.4 built and demonstrated, 2026-06-12; commands in `validation.md` Automated Checks).
- [x] Phase R1 — Dead-Code Purge + signature v28 (gate closed 2026-06-12; user rebake round committed as the v28 baseline).
- [x] Phase R2 — `system_flow` projected-flow correctness (landed merged with R3, 2026-06-12; original numeric gate found misattributed — see roadmap R2 banner and validation.md).
- [x] Phase R3 — Shared shader includes (landed merged with R2, 2026-06-12; RT.2 byte-identity across the whole phase).
- [x] Phase R4 — Runtime/editor robustness (implementation landed 2026-06-13; automated/headless guard pass recorded; first visible ripple run failed, the impulse scheduling fix landed, and the full user-visible suite passed later the same session).
- [x] Phase R5 — Structural dedup (R5.1-R5.5 landed 2026-06-13; gate closed by RT.1 scratch rebake texture hashes, property-list diff, and `r5_behavior_preservation_probe.gd`).
- [x] Write R6's own `spec.md`/`plan.md`/`validation.md` (constitution rule 12) — gate before R6 starts; must include the Lifecycle/Cleanup/Re-entry section (21 abort points).
- [x] Phase R6 — `river_manager.gd` decomposition (after R1/R3/R5); final automated validation passed 2026-06-14.
- [x] R6.5 cleanup/interface tightening — dead private helpers removed, boundary comments tightened, focused validation passed 2026-06-14.
- [x] Record the R7-vs-feature-Phase-5 compute decision in this folder — compute-first path chosen 2026-06-14; fold R7 into feature Phase 5 RenderingDevice compute migration and skip SubViewport interim.
- [x] Write R7's own `spec.md`/`plan.md`/`validation.md` — docs gate created 2026-06-14 with compute-first decision.
- [ ] Phase R7 — GPU-resident solve (after R6).
- [x] Phase R8 — Documentation coherence (R8.1–R8.5 + stale-constant cleanup, 2026-06-12). architecture-and-features rewrite, Data Contract neutrals + system_flow_map_version, obstacle-constraints spec/validation/review backfill, probe consolidation + RT index, vertex-cost figure; code grep gates clean.
- [ ] Complete the Adversarial Plan Review section of `plan.md` with the user before implementation starts.

## Setup

- [ ] Confirm the current workspace state (branch `river-refactor` exists; phases get their own branches cut from `main` per the operating rules — no phase starts on a dirty tree).
- [ ] Read `spec.md`, `plan.md`, and `validation.md` — and `roadmap.md`, which is this track's canonical work plan.
- [ ] Check `docs/research/river-research-citations.md` before research-driven changes; update it when new cited sources affect this feature.
- [ ] For Godot-specific implementation work (RenderingServer draws, `Curve3D.get_closest_offset`, `shader_get_parameter_default`, `frame_post_draw`), search current official Godot documentation before patching; record sources that affect the implementation in `research.md` or the shared citations index.
- [ ] Check `docs/audit/waterways-code-audit-2026-06-12.md` for the relevant section before starting any phase — every roadmap item carries its audit refs.
- [ ] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [ ] If running Godot, use the exact console/windowed launch instructions from `validation.md`; console probes use repo-local `.codex-research` user-data folders.
- [ ] Run the context challenge check: the adversarial review already overturned several audit claims (see `spec.md` Resolved Questions) — if new evidence contradicts a roadmap item's premise, raise it with evidence before patching.

## Implementation

- [ ] Honor the standing operating rules for every phase (from `roadmap.md`):
  - Validate: one branch per phase/item from `main`; all bake-content changes ride the single R1 v28 bump (or document why not); extraction phases prove byte-identity via RT.1; before deleting any shader uniform/function, grep shaders *and* probes *and* feature specs.

- [ ] Work the current phase's checklist in `roadmap.md`, checking items off in place and noting the branch name next to the phase heading.
  - Validate: each item's fix verified per the phase's **Validation** block in the roadmap.

- [ ] When a phase completes, record its gate results in `validation.md` (matrix row + recorded result) and update `docs/handoffs/handoff-latest.md`.
  - Validate: the validation matrix row for the phase shows Pass with date and owner; handoff points at the true next action.

## Validation

- [x] Run automated checks listed in `validation.md` (full suite green 2026-06-12 post-R2+R3, including RT.3 `enforce=all` — no intentional reds remain).
- [ ] Revisit the context challenge check after validation: if results suggest a roadmap item's premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in the chat message to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene, if applicable, through human-assisted validation (pixel-parity gates are windowed/human-assisted by default — constitution rule 8).
- [ ] Check shader output/debug views through human-assisted validation (Foam Mix parity for R0.2, neutral pillows/gates for R0.7, RT.2 captures for R3).
- [ ] Check editor workflow through human-assisted validation (no-undo on click-without-drag for R0.4, inspector revert for R3.3).
- [x] Check runtime sampling/API behavior through human-assisted validation or a proven non-crashing runtime check (duck drift for R2, buoyancy binding and sleep for R4.3, ripple low-FPS behavior for R4.1).
- [x] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation (`.codex-research` probe outputs, capture PNGs, bake hash dumps) and decide whether to keep, exclude, or delete them.
- [ ] If validation used a scratch project, confirm active add-on scripts were mirrored there before running probes.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries (the R1.4 annotations, R0.7's hint comment, RT.4's seed comment pair, R4.5's intent comment).
- [ ] Update docs for any changed decisions (spec.md Decision Log; roadmap inline notes).
- [x] Update feature or architecture documentation for changed behavior, data flow, module boundaries, or validation procedures (Phase R8, 2026-06-12: architecture-and-features.md, Data Contract, obstacle-constraints folder backfill; R4 and R5 implementation/validation docs updated 2026-06-13). Per-phase doc updates for R6–R7 still land with those phases.
- [ ] Confirm generated data and resources are explicit and inspectable (v28 signature contents, system-map version field).
- [ ] Confirm editor-only state did not leak into runtime-only code (especially across the R6 extraction seams).
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

None yet — track not started.
