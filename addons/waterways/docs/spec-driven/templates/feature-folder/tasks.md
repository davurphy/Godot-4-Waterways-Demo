# Tasks: <Feature Name>

Complete tasks in order unless the plan is revised.
Each task should be independently reviewable.

## Current Truth

Keep this as the single fastest way to understand open work.
This is the task dashboard. Keep active work here and move completed or superseded task detail to `Historical or Closed Tasks`.

- Current status: <Not started / In progress / Complete / Blocked>
- Current implementation slice:
- Remaining open task count:
- Last passing validation:
- Next recommended action:
- Known deferred work:

## Open Work

Use this section as the canonical checklist for unfinished work. When items close, update any stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff.

- [ ] <Current highest-priority task>

## Setup

- [ ] Confirm the current workspace state.
- [ ] Read `spec.md`, `plan.md`, and `validation.md`.
- [ ] Check `docs/research/river-research-citations.md` before research-driven changes; it is the shared works-cited list for river-reading, flow-map, shader-water, and production-reference sources, and should be updated when new cited sources affect this feature.
- [ ] Check `audit/code-audit.md` for relevant known risks.
- [ ] Confirm whether the task affects active code in `addons/waterways`, generated resources, demo scenes, docs, or validation tooling.
- [ ] If running Godot, use the exact console/windowed launch instructions from `validation.md` or `session-handoff.md`; console probes should use repo-local `.codex-research` user-data folders.
- [ ] Run the context challenge check: if the user or agent may be misreading expected behavior, stale generated data, validation geometry, or engine limitations as a defect, raise that with evidence before patching.

## Implementation

- [ ] Define or update the add-on extension points described in `spec.md` and `plan.md`.
  - Validate: <How to check resources, presets, shader inputs, scene setup, or configuration>

- [ ] <Task>
  - Validate: <How to check it>

- [ ] <Task>
  - Validate: <How to check it>

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge check after validation: if results suggest the premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, gizmo, shader, bake, or runtime checks, ask the user in the chat message to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene, if applicable, through human-assisted validation unless the agent can genuinely use the visible editor.
- [ ] Check shader output/debug views, if applicable, through human-assisted validation.
- [ ] Check editor workflow, if applicable, through human-assisted validation.
- [ ] Check runtime sampling/API behavior, if applicable, through human-assisted validation or a proven non-crashing runtime check.
- [ ] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] If validation used a scratch project, confirm active add-on scripts were mirrored there before running probes.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious code, Godot quirks, shader math, performance-sensitive paths, and architectural boundaries.
- [ ] Update docs for any changed decisions.
- [ ] Update feature or architecture documentation for changed behavior, data flow, module boundaries, or validation procedures.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

Move long closed checklists here when they stop helping the current session scan quickly. Keep enough detail to preserve the audit trail.
