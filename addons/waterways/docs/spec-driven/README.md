# Waterways Spec-Driven Development

This folder is the working agreement for evolving Waterways as a Godot 4.6+ flow-map add-on.

It turns ideas into durable specs, plans, tasks, validation scenes, and review notes so future sessions can continue without rediscovering the same context.

## Dashboard-First Pattern

These docs should save future sessions from rehashing the past while still preserving the receipts.

Use each feature folder in this order:

1. Read the dashboard sections first: `handoff-latest.md`, `tasks.md`, `review.md`, and `validation.md`.
2. Drill into `plan.md`, `spec.md`, and `research.md` only when the current state needs explanation.
3. Use linked source trails, decision logs, and historical archives when a session needs to answer "why is it structured like this?"

Keep the top of every long-running feature file short and current. Put old validation runs, superseded assumptions, and detailed rationale lower in the same file under history, evidence, sources, or decision-log sections.

## Agent Start Protocol

For any non-trivial Waterways change, read these files before editing code:

1. `00-constitution.md`
2. `01-workflow.md`
3. The active feature folder under `features/<feature-slug>/`, if one exists

Inside an active feature folder, start with:

1. `handoff-latest.md`
2. `tasks.md`
3. `review.md`
4. `validation.md`
5. `plan.md`
6. `spec.md`
7. `research.md`
8. `addons\waterways\docs\research\river-research-citations.md` when research provenance matters

If no feature folder exists for the work, create one under `features/<feature-slug>/`.
Do not skip directly from a vague idea to implementation unless the requested change is clearly small and local.

After the plan is drafted and adversarially reviewed, but before implementation begins, remind the user to create or switch to a dedicated Git branch for that feature. The user can do this in GitHub Desktop / GitHub for Windows, or ask Codex to create the branch if local Git access is available. This keeps experiments isolated and protects `main` from catastrophic or hard-to-unwind changes.

## Current Orientation

Waterways is past the original Godot 4 / 0.2.2 port-and-audit phase. Do not treat `godot-4-port` or `godot-4-audit-remediation` as the default active workstream unless the user explicitly asks to revisit that history.

For a new feature, first look for an existing feature folder that matches the request. If one exists, read its latest handoff and active spec documents. If none exists, create a new feature folder from the templates and start with research/spec/plan/tasks before implementation.

Treat visible Godot/editor/runtime validation as human-assisted by default. Local parser or editor-load signal is useful, but it is not proof of visible Inspector, shader, bake, or F6 behavior.

New feature folders must be created under:

```text
addons\waterways\docs\spec-driven\features
```

Copy the files from `spec-driven/templates/feature-folder/` into the new feature subfolder, then fill them in for that feature.

## Active Add-on Layout

The working Godot 4.6+ add-on lives here:

```text
addons/
  waterways/
```

If a legacy Godot 3 reference snapshot exists in the current workspace, use it only as behavioral reference:

```text
legacy/
  godot-3/
    addons/
      waterways/
```

Use any legacy copy for behavior comparison only. Active code should be written for Godot 4.6+.

## Feature Folder Shape

Each substantial feature should live in its own folder:

```text
spec-driven/
  features/
    <feature-slug>/
      handoff-latest.md
      research.md
      spec.md
      plan.md
      tasks.md
      validation.md
      review.md
```

For example, a feature named `editor-authoring-tools` should create and use:

```text
addons\waterways\docs\spec-driven\features\editor-authoring-tools\
```

The copied `session-handoff.md` template should become `handoff-latest.md` in that subfolder. The copied `research.md`, `spec.md`, `plan.md`, `tasks.md`, `validation.md`, and `review.md` files live beside it.

Use this order:

1. Keep `handoff-latest.md` and each `Current Truth` section as the dashboard.
2. Research the problem and Godot-specific constraints.
3. Write the behavior/spec: what, why, success criteria.
4. Plan the technical design: architecture, data flow, risks.
5. Break the plan into small tasks.
6. Adversarially review the plan before implementation.
7. Before code changes, remind the user to create or switch to a dedicated Git branch for the feature.
8. Implement one task at a time.
9. Validate with automated checks and visual test scenes where relevant.
10. Review against the spec before broadening or polishing.
11. When handing off, replace stale dashboard facts instead of appending more top-level history.

## Core Rule

When implementation diverges from intent, update the spec or plan first unless the issue is a tiny local defect.
The spec is the source of truth; code is the current attempt to satisfy it.

## Collaboration Rule

Agents should challenge likely false premises early. If the code, scene, validation data, or Godot behavior suggests the user is overlooking context or reading expected behavior as a bug, the agent should say that plainly, explain the evidence, and suggest the smallest check before spending time on a non-issue. The challenge should be proportional and falsifiable, not reflexive contradiction.

## Included Files

- `00-constitution.md`: standing principles for all Waterways AI-assisted development.
- `01-workflow.md`: the repeatable spec-driven process.
- `templates/feature-folder/`: copyable feature-document templates.
- `templates/feature-folder/session-handoff.md`: copyable template for handing work from one session to the next.

## Session Handoffs

For long-running work, copy `spec-driven/templates/feature-folder/session-handoff.md` into the active feature folder under `spec-driven/features/<feature-slug>/`.

Use a name such as:

```text
handoff-YYYY-MM-DD.md
```

or:

```text
handoff-latest.md
```

The handoff should tell the next session what changed, what was decided, what validation ran, what remains risky, and the single best next action.

## Useful Feature Folder Examples

- `features/flow-map-bake-pipeline/`: flow/foam/distance/height bake resources and outputs.
- `features/editor-authoring-tools/`: gizmos, toolbar controls, inspectors, and debug previews.
- `features/runtime-flow-sampling/`: runtime APIs for current direction, water altitude, and buoyancy helpers.
- `features/godot-4-audit-remediation/`: historical release-blocking audit fixes for 0.2.2.
- `features/godot-4-port/`: historical Godot 4.6+ add-on migration notes.
