# Tasks: River Refactor (Hardening + Refactor Track)

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

The canonical per-item checklists live in `roadmap.md` (phases R0, RT, R1–R8) and are worked **in place there** — check items off in the roadmap, note branch names next to phase headings, and record validation results in `validation.md`. This file tracks the cross-phase process work and the current slice; do not duplicate the roadmap's item lists here.

## Current Truth

- Current status: In progress
- Current implementation slice: Phase R0 code complete on branch `river-refactor` (9/9 items, one commit each); human-assisted R0 validation pending; Phase RT is next
- Remaining open task count: R0 human-assisted validation; 4 RT items; phases R1–R8 untouched
- Last passing validation: 2026-06-12 headless — three probe `*_OK` markers + `--check-only` parse pass on all edited scripts (see `validation.md`)
- Next recommended action: run the R0 human-assisted checks (foam parity, null-distmap, mid-bake close, click-without-drag), then start RT.1 (bake hash-compare) — it gates R1
- Known deferred work: R9 (vertex pillow stack) stays on the feature roadmap; R7 blocked on the feature-Phase-5 compute decision gate

## Open Work

Use this section as the canonical checklist for unfinished *process* work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff. Item-level work is tracked in `roadmap.md`.

- [x] Phase R0 — Defect Hotfixes, implementation (9/9 items landed on `river-refactor`, 2026-06-12). R0.2 (the R3 prerequisite) is in.
- [ ] Phase R0 — human-assisted validation block (foam parity, null-distmap visuals, mid-bake close recovery, click-without-drag undo check).
- [ ] Phase RT — Validation Tooling (4 items; RT.1 before R1, RT.2 before R3, RT.3 before R2). Can run parallel with R0.
- [ ] Phase R1 — Dead-Code Purge + signature v28 (needs RT.1).
- [ ] Phase R2 — `system_flow` projected-flow correctness (needs RT.3; after R1; consider merging with R3).
- [ ] Phase R3 — Shared shader includes (needs R0.2 + RT.2).
- [ ] Phase R4 — Runtime/editor robustness (any time after R0).
- [ ] Phase R5 — Structural dedup (R5.1/R5.4/R5.5 any time after R0; gates need RT.1).
- [ ] Write R6's own `spec.md`/`plan.md`/`validation.md` (constitution rule 12) — gate before R6 starts; must include the Lifecycle/Cleanup/Re-entry section (21 abort points).
- [ ] Phase R6 — `river_manager.gd` decomposition (after R1/R3/R5).
- [ ] Record the R7-vs-feature-Phase-5 compute decision in this folder — gate before R7 starts.
- [ ] Write R7's own `spec.md`/`plan.md`/`validation.md` — gate before R7 starts.
- [ ] Phase R7 — GPU-resident solve (after R6).
- [ ] Phase R8 — Documentation coherence (interleave anywhere after R1).
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

- [ ] Run automated checks listed in `validation.md` (RT.1/RT.3/RT.4 once they exist; hardened probes with stable markers).
- [ ] Revisit the context challenge check after validation: if results suggest a roadmap item's premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in the chat message to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene, if applicable, through human-assisted validation (pixel-parity gates are windowed/human-assisted by default — constitution rule 8).
- [ ] Check shader output/debug views through human-assisted validation (Foam Mix parity for R0.2, neutral pillows/gates for R0.7, RT.2 captures for R3).
- [ ] Check editor workflow through human-assisted validation (no-undo on click-without-drag for R0.4, inspector revert for R3.3).
- [ ] Check runtime sampling/API behavior through human-assisted validation or a proven non-crashing runtime check (duck drift for R2, buoyancy binding and sleep for R4.3, ripple low-FPS behavior for R4.1).
- [ ] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation (`.codex-research` probe outputs, capture PNGs, bake hash dumps) and decide whether to keep, exclude, or delete them.
- [ ] If validation used a scratch project, confirm active add-on scripts were mirrored there before running probes.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries (the R1.4 annotations, R0.7's hint comment, RT.4's seed comment pair, R4.5's intent comment).
- [ ] Update docs for any changed decisions (spec.md Decision Log; roadmap inline notes).
- [ ] Update feature or architecture documentation for changed behavior, data flow, module boundaries, or validation procedures (Phase R8 owns the bulk of this).
- [ ] Confirm generated data and resources are explicit and inspectable (v28 signature contents, system-map version field).
- [ ] Confirm editor-only state did not leak into runtime-only code (especially across the R6 extraction seams).
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

None yet — track not started.
