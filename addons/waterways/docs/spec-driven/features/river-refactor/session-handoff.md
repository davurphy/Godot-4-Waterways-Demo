# Session Handoff: River Refactor (Hardening + Refactor Track)

## Date

2026-06-12

## Current Focus

Stand up the spec-driven feature folder for the hardening/refactor track derived from the 2026-06-12 full-addon code audit. This session created the seven feature-folder documents around the already-written `roadmap.md`; no implementation has started.

- Feature folder:
  - `addons\waterways\docs\spec-driven\features\river-refactor\`
- Active add-on path:
  - `addons\waterways`

## Current Truth

- Overall status: Not started (documentation scaffold complete; zero code changes)
- Highest-priority open task: Phase R0 hotfixes (9 independent items) with Phase RT tooling started in parallel; RT.1 must land before R1
- Last passing validation: none — `validation.md` matrix is entirely Unrun
- Known failing or unproven check: everything; the RT tools several phase gates depend on do not exist yet (verified against `probes/`)
- Next recommended action: complete `plan.md`'s Adversarial Plan Review with the user, then cut a branch from `main` for the first R0 item or RT.1
- Packaging/artifact hygiene status: clean — no scratch artifacts created this session
- Historical detail starts at: nothing archived yet

## How To Use This Feature Folder

- Treat this handoff and the `Current Truth` sections as the dashboard.
- **`roadmap.md` is this track's canonical work plan** — phases R0–R8 with per-item details, line references, gates, sequencing, and the risk register. Work its checklists in place; note branch names next to phase headings.
- Use `tasks.md` for the cross-phase process checklist, `review.md` for unresolved risks, and `validation.md` for what is currently proven.
- Open `plan.md`, `spec.md`, `research.md`, and the shared citations index only when the dashboard needs explanation or source provenance.
- Move old session notes, superseded assumptions, and closed work into historical sections instead of growing the dashboard.

## Start Here Next Session

Read these first:

1. `addons\waterways\docs\spec-driven\00-constitution.md`
2. `addons\waterways\docs\spec-driven\01-workflow.md`
3. This handoff file
4. `addons\waterways\docs\spec-driven\features\river-refactor\roadmap.md` (canonical work plan)
5. `addons\waterways\docs\spec-driven\features\river-refactor\tasks.md`
6. `addons\waterways\docs\spec-driven\features\river-refactor\review.md`
7. `addons\waterways\docs\spec-driven\features\river-refactor\validation.md`
8. `addons\waterways\docs\spec-driven\features\river-refactor\plan.md`
9. `addons\waterways\docs\spec-driven\features\river-refactor\spec.md`
10. `addons\waterways\docs\spec-driven\features\river-refactor\research.md`
11. `addons\waterways\docs\research\river-research-citations.md`

Then do this next:

- Complete the Adversarial Plan Review section of `plan.md` with the user, then start Phase R0 (any item) and/or RT.1 on a fresh branch from `main` (one branch per phase/item; clean tree).
- For Godot-specific implementation work, search current official Godot documentation and API references online before patching. Prefer official docs first, and record any source that affects implementation in `research.md` or `addons\waterways\docs\research\river-research-citations.md`.
- If this requires human-assisted Godot validation, include the exact scene path, plugin state, steps, expected visible result, and Output/console text to relay. The next agent should paste those steps into its user-facing message instead of telling the user to read `validation.md`. The per-phase steps live in each roadmap phase's **Validation** block.
- If the next action might be based on a false premise or overlooked context, tell the user before patching. The adversarial review already overturned several audit claims (see `spec.md` Resolved Questions); the standing rule from that miss: before deleting any shader uniform or function, grep shaders *and* probes *and* feature specs.

## What Changed This Session

- `spec.md`: created — goals/non-goals/requirements/acceptance tests distilled from `roadmap.md`, plus the Resolved Questions table capturing the adversarial-review corrections.
- `plan.md`: created — track-level architecture, layers, lifecycle answers, files-to-change map, validation strategy; flags the unfinished Adversarial Plan Review.
- `research.md`: created — records the audit + adversarial review as this track's research, the Godot 4.6 findings that constrain the design, and the option analysis behind the phased plan.
- `tasks.md`: created — cross-phase process checklist; defers item-level tracking to `roadmap.md` to avoid duplicate checklists.
- `validation.md`: created — per-phase-gate validation matrix (all Unrun), premise/interpretation traps (e.g., R4.1's reduced rate is by design), launch instructions, and the regression-budget slot for R7's wall-clock.
- `review.md`: created — empty review scaffold with the pre-implementation premise review filled in; first reviewable unit is the first R0/RT slice.
- `session-handoff.md`: this file.

## Current Changes Summary

- All seven feature-folder documents created around the pre-existing `roadmap.md`. Docs only; no add-on code, shaders, probes, scenes, or resources touched.

## Historical Change Log

- 2026-06-12 (earlier): `roadmap.md` written from the audit and hardened by adversarial review (commit `c34cd9a` "refactor notes" predates this folder scaffold).

## Decisions Made

| Decision | Reason | Follow-up |
| --- | --- | --- |
| Keep `roadmap.md` as the canonical item-level work plan; templates wrap it rather than duplicate it | The roadmap's checklists, line references, and gates are already the verified source of truth; duplicating them invites drift — the exact failure mode this track exists to kill | Check items off in the roadmap; record results in `validation.md` |
| One track-level spec/plan now; R6 and R7 get their own spec/plan/validation later | Constitution rule 12 requires per-phase docs only for the heavyweight phases | Write them before R6/R7 start; R7 also needs the compute decision recorded |

## Current State

Implementation status:

- Not started

Spec/plan status:

- Research: Complete (audit + adversarial review; `research.md` records the outcome)
- Spec: Draft
- Plan: Draft — Adversarial Plan Review not yet completed with the user
- Tasks: Scaffolded; all open
- Validation: Scaffolded; matrix entirely Unrun; RT tooling not yet built
- Review: Scaffolded; nothing to review yet

Validation status:

- Automated: none run. The probes the gates need (RT.1 hash-compare, RT.2 capture diff, RT.3 flow comparison, RT.4 seed assertion) do not exist yet.
- Human-assisted: none requested yet. First requests will come from R0's validation block (Foam Mix parity, null-distmap neutrality, mid-bake close recovery, click-without-drag undo check).
- Shader: none
- Editor: none
- Visual: none
- Runtime: none
- Performance: none
- Manual: none

## Important Context

- The track's operating rules (from `roadmap.md`): one branch per phase/item from `main`; all bake-content changes ride the single R1 v27→v28 signature bump; extraction phases prove byte-identity via RT.1; pixel-parity gates are windowed/human-assisted (constitution rule 8); grep shaders + probes + feature specs before deleting any shader uniform/function.
- Hard sequencing: R0.2 before R3; RT.1 before R1/R5/R6 gates; RT.2 before R3; RT.3 before R2; R5 before R6; R6 before R7; R8 after R1. R2+R3 are best merged.
- R0.5 knowingly changes baked content without a signature bump (hotfix exception, retroactively covered by v28). System maps have **no** staleness mechanism until R2.4.
- Shared works-cited index: `addons\waterways\docs\research\river-research-citations.md`.
- Known Godot 4.6+ detail: two `UPDATE_ONCE` SubViewports in one frame render in non-dependency order (the Defect-6 mechanism) — constrains R4.1 and R7.1; no texture hint can express the distmap neutral ≈ (0.75, 0.25, 0.0, 0.5).
- Misunderstanding risk to raise directly: R4.1 makes the ripple sim slower-but-correct under load *by design* — a reduced propagation rate at low FPS is the accepted trade, not a regression.

## Artifact Hygiene

- Scratch folders or temporary projects created: none this session
- Generated bakes/resources created: none
- Active files mirrored into scratch validation: n/a
- Files/folders that must be excluded from packaging: `.codex-research\` (standing), future RT baselines/captures
- Files/folders safe to delete now: none

## Known Risks and Open Issues

- The full risk register lives in `roadmap.md` (Risks). Dominant: R3 extraction parity, R6's 21 abort points, R7's ordering hazard, the R1.4 class of "dead code that probes/specs consume".
- Open decisions: R7-vs-feature-Phase-5 compute (gate); R2/R3 merge-or-separate (decide at R1).
- Possible false premise to verify before implementing: each R0 item's validation step doubles as its falsifier — when cheap, run it on the unpatched build first (e.g., confirm Foam Mix actually diverges before patching R0.2).

Relevant audit sections:

- `addons\waterways\docs\audit\waterways-code-audit-2026-06-12.md`: Prioritized Recommendations 1–17; Defects 1–11; §§1–10 — every roadmap item carries its audit refs inline.

## Blockers

- Adversarial Plan Review (`plan.md`) not yet completed with the user — required before code changes.
- Local Godot editor/visual access is unreliable for the agent: pixel-parity and editor-interaction gates are human-assisted by design. Local parser/headless editor-load signal is not a substitute for visible editor/runtime validation.
- R7 is blocked on the recorded compute decision; R6/R7 are blocked on their own spec/plan/validation files.

## Files To Inspect Before Editing

- `addons/waterways/docs/spec-driven/features/river-refactor/roadmap.md` (always — it is the work plan)
- Per phase, the files named in `plan.md` "Files to Change" — chiefly `river_manager.gd`, `river.gdshader`, `river_debug.gdshader`, `system_flow.gdshader`, `system_map_renderer.gd`, `water_helper_methods.gd`, `filter_renderer.gd`, `river_gizmo.gd`, `plugin.gd`, `water_ripple_field.gd`, `buoyant_manager.gd`, `water_system_manager.gd`, `probes/*`

## Commands or Checks Used

```powershell
# none — documentation-only session; no probes or Godot launches run
```

Result summary:

- No commands run this session. Folder contents verified by directory listing only (roadmap.md was the sole file before this session).

## Next Tasks

- [ ] Complete `plan.md`'s Adversarial Plan Review with the user.
- [ ] Start RT.1 (bake hash-compare) — it gates R1, R5, and R6 and should land before R1 begins.
- [ ] Start Phase R0 items in parallel (independent; any order; R0.2 unblocks R3 later).

## Do Not Do Yet

- R6 or R7 — blocked on their own spec/plan/validation files; R7 additionally on the recorded compute decision.
- Any deletion of the ripple-displacement interface (`ripple_height_at_*`, `i_ripple_*`) — R1.4 annotates only; deletion requires a per-uniform pass updating the river-ripples spec contract list and all asserting probes.
- Any "improvement" to audit-verified-clean areas (§10): f16 solve bracketing, atlas column clamps, ripple material ownership, undo registration order, export-safety.
- A second signature bump — v27→v28 (R1.7) is the only one; later bake-content changes must ride it or be explicitly justified.

## Notes for the Next Agent

This track is unusual in that the planning is *finished and verified* — the roadmap was adversarially reviewed against source at cited line numbers, and the corrections (R1.4 live interface, R0.6 no-op ordering, R4.2 non-drop-in API) are already baked in. Your job is execution discipline, not re-planning: pick up the next unchecked roadmap item, branch from `main`, fix, run the phase's validation block (pasting human-assisted steps into chat), record results in `validation.md`, check the box in `roadmap.md`, update this handoff. Resist re-deriving the audit; if you find evidence a roadmap item's premise is wrong, that's worth raising — the review missed exactly one thing (R1.4) and the grep-everything rule exists because of it.

## Godot Launch Instructions

Use these exact Windows paths for this project unless the user gives newer ones.

- Project root:
  - `C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo`
- Godot 4.6.3 console executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe`
- Godot 4.6.3 windowed editor executable:
  - `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe`

Use the console executable for scripted probes and diagnostics because it prints stable output markers such as `*_OK`. Always redirect `APPDATA` and `LOCALAPPDATA` to a repo-local `.codex-research` folder for probe runs so the agent does not alter the user's normal Godot editor profile.

Console probe pattern:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotConsole = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe"
$godotUser = Join-Path $root ".codex-research\godot-user"
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser "roaming"), (Join-Path $godotUser "local") | Out-Null
$env:APPDATA = Join-Path $godotUser "roaming"
$env:LOCALAPPDATA = Join-Path $godotUser "local"
& $godotConsole --path $root --script "res://path/to/probe.gd"
```

Use the windowed executable only when a human-visible editor/runtime review is needed:

```powershell
$root = "C:\Users\pc\Documents\GitHub\Godot 4 Waterways Demo"
$godotEditor = "C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64.exe"
& $godotEditor --path $root
```

## Validation Commands

No track-specific validation commands exist yet — RT.1–RT.4 will define them. When they land, record the exact PowerShell invocations and their stable pass/fail markers here and in `validation.md`.
