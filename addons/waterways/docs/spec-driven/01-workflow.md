# Spec-Driven Workflow

This process is for substantial Waterways work: the Godot 4.6+ port, new editor tools, flow-map baking changes, shaders, runtime sampling APIs, performance-sensitive code, validation scenes, or architectural refactors.

Small local fixes can use a lighter path, but they should still respect the constitution.

For each substantial feature, create a dedicated feature subfolder under:

```text
addons\waterways\docs\spec-driven\features
```

Copy the template files from `spec-driven/templates/feature-folder/` into that feature subfolder. Rename the copied `session-handoff.md` to `handoff-latest.md`. All feature-specific `research.md`, `spec.md`, `plan.md`, `tasks.md`, `validation.md`, and `review.md` work should live beside it.

Keep each long-running feature folder scan-friendly:

- Maintain a short "Current Truth" section in the active spec, plan, tasks, validation, review, and handoff files.
- Use `tasks.md` as the canonical checklist for unfinished work.
- Move resolved open questions into a resolved-questions table or decision log.
- Keep detailed historical validation, but summarize the current state in a validation matrix.
- When a task closes, sweep the docs for stale "open follow-up" language before handing off.
- Separate current-session changes from historical change logs once files become long.

## Dashboard-First Document Pattern

Every long-running feature file should have a short dashboard near the top and deeper context lower down.

- Dashboard: current truth, next action, validation status, known risk, and "do not do yet" constraints.
- Drilldown: requirements, architecture, implementation plan, task details, and review findings.
- Evidence: validation results, cited research, source paths, decision logs, and copied user observations.
- Archive: historical or closed tasks, superseded assumptions, and older validation runs.

When updating docs, replace stale dashboard facts instead of appending another summary above them. Use links or file paths from the dashboard to point at deeper evidence rather than duplicating long context.

Suggested read order inside an active feature folder:

1. `handoff-latest.md`
2. `tasks.md`
3. `review.md`
4. `validation.md`
5. `plan.md`
6. `spec.md`
7. `research.md`
8. `addons\waterways\docs\research\river-research-citations.md` when the session needs source provenance

## Phase 0: Intake

Capture the idea in plain language.
Identify whether it is a feature, porting task, refactor, bug fix, tool, research task, validation task, or documentation task.

Answer:

- What user or developer need does this serve?
- What should be true when this is done?
- What is explicitly out of scope?
- Does this need research before planning?
- Does this touch the legacy Godot 3 behavior, the active Godot 4.6+ add-on, or both?

Before moving on, do a context challenge check:

- Is the request based on a premise that might be wrong or incomplete?
- Is the user possibly reading expected scene behavior, stale data, validation geometry, or a known Godot/editor limitation as a bug?
- Do local files, previous validation notes, or visible-output descriptions point to a simpler explanation?
- Would a short clarification or falsifying check save time before implementing?

If the answer is probably yes, tell the user directly and early. State the evidence, confidence level, and the smallest check that would distinguish "real issue" from "misread context." Do not turn this into reflexive pushback: if the evidence is weak, present it as a hypothesis; if the user provides stronger contrary evidence, update the plan and continue.

## Phase 1: Research

Use research when the work touches unfamiliar architecture, rendering, editor APIs, engine limitations, performance, shader behavior, physics queries, texture formats, or established flow-map techniques.

Research should cover:

- how comparable flow-map tools or water systems are usually built
- relevant Godot 4.6+ capabilities and constraints
- current Godot documentation for editor plugins, gizmos, shaders, textures, physics, and resources
- the legacy Waterways implementation when preserving behavior matters
- likely failure modes
- likely false premises, expected-behavior cases, or scene/data context the user may be overlooking
- recommended direction for Waterways

Research output goes in `research.md`.
Shared citations and source provenance should link to `addons\waterways\docs\research\river-research-citations.md` when relevant.
Do not turn research directly into code. Turn it into a spec first.

For Godot-specific implementation work, agents can and should search current official Godot documentation and API references online before coding, especially for shaders, rendering, editor APIs, resources, physics, and version-specific behavior. Prefer official Godot docs first, use community examples only as secondary context, and record any sources that affected the implementation in the relevant `research.md` or shared citations index.

The legacy Godot 3 add-on is a reference implementation, not a design mandate.
Preserve useful behavior, but do not preserve obsolete APIs or fragile architecture unless the plan explicitly justifies it.

## Phase 2: Spec

The spec describes what and why, not how.

It should include:

- user stories or developer workflows
- success criteria
- functional requirements
- non-functional requirements
- editor usability requirements
- runtime/API requirements
- generated asset and resource requirements
- acceptance tests
- out-of-scope decisions
- open questions

Output goes in `spec.md`.

## Phase 3: Plan

The plan describes how to satisfy the spec.

It should include:

- architecture
- affected files and modules
- data structures and resources
- Godot nodes, resources, shaders, editor tools, import settings, or scenes involved
- editor-only versus runtime module boundaries
- bake data format, texture channels, and metadata
- validation strategy
- risk register
- migration or compatibility concerns
- documentation updates needed for feature or architectural changes

Output goes in `plan.md`.

Before moving into implementation, adversarially review the plan with the user:

- What is the most likely way this plan could damage working behavior?
- What project state, generated resource, scene, or user workflow could the plan accidentally break?
- What files or data are riskier than they look?
- What simpler or safer approach should be considered before editing code?
- What validation will catch the riskiest failure early?

Record the important findings in `plan.md` or `review.md` before coding.

## Phase 4: Tasks

Tasks should be small enough that an agent can complete and verify them one at a time.
Each task should name the expected change and the validation step.

Good task shape:

```markdown
- [ ] Add `FlowMapBakeResource` with serialized flow texture, foam texture, bounds, and channel metadata.
  - Validate by loading the resource in a minimal Godot 4.6 scene and confirming exported properties appear in the inspector.
```

Output goes in `tasks.md`.

## Phase 4.5: Branch Safety Check

After the plan and adversarial plan review are complete, but before code or generated-resource changes begin, remind the user to create or switch to a dedicated Git branch for the work. The user can do this in GitHub Desktop / GitHub for Windows, or ask Codex to create the branch if local Git access is available.

For substantial or potentially breaking work, do not start implementation until one of these is true:

- the user confirms they created or switched to a feature branch;
- Codex successfully creates or switches to a feature branch;
- the user explicitly says to continue on the current branch despite the risk.

Use a short branch name related to the feature or fix. The goal is to keep experiments, generated resources, and risky code changes away from `main` until they are reviewed.

## Phase 5: Implementation

Implement in task order.

Rules:

- Keep changes scoped to the current task.
- Prefer existing project patterns once the Godot 4.6 architecture is established.
- Keep editor-only code separate from runtime code.
- Avoid broad rewrites unless the plan explicitly calls for them.
- Preserve user-facing behavior from the legacy add-on only when it still makes sense in Godot 4.6+.
- Add comments where they preserve intent, explain Godot quirks, clarify shader/rendering math, or mark architectural boundaries.
- Update feature and architecture documentation as part of the same change when behavior, data flow, or module boundaries change.
- Update tasks as work completes.
- If implementation pressure reveals a bad plan, stop and revise the plan.

## Phase 6: Validation

Validation should prove the feature satisfies the spec.

For Waterways Godot work, human-assisted validation is a normal part of the workflow, not a fallback of last resort. The agent may try narrow local checks such as text searches, script parser checks, or headless editor-load probes when they work, but it must not treat those as replacements for visible Godot editor/runtime validation.

If the check needs the visible Godot editor, viewport interaction, scene running, gizmos, shader visuals, baking, or runtime behavior, the agent should ask the user to run a precise check and relay the result. The request must be written directly in the chat message, not only in `validation.md`, and must include:

- exact scene path, menu action, or workflow to run
- whether the plugin should be enabled
- what Output/console text or parser errors to copy
- what visible behavior to describe or screenshot
- Godot version, renderer, and device details when relevant

Human-assisted validation is valid project evidence when it records what was run, who ran it, the date, the observed result, and any copied console output, screenshot, or visible behavior.

Use the right mix of:

- automated tests
- editor/runtime smoke tests
- visual test scenes
- shader compile checks
- bake output inspection
- runtime sampling checks
- performance measurements
- manual review checklist

For long-running work, maintain a validation matrix that maps each requirement or risk to its proof, environment, stable result marker, date, and owner. Narrative validation notes are still useful, but the matrix should answer "what is currently proven?" quickly.

For visual systems, validation must include a scene or procedure that a human can inspect.
Output goes in `validation.md`.

## Phase 7: Review

Review against the spec and plan.

Ask:

- Does the implementation satisfy every acceptance criterion?
- Did it stay within editor/runtime boundaries?
- Does it avoid obsolete Godot 3 APIs in active code?
- Are generated textures, resources, and metadata explicit and inspectable?
- Is there a visual test scene where needed?
- Is there a performance risk?
- Are code comments and feature/architecture docs sufficient for the next maintainer?
- Are docs, tasks, and open questions updated?
- Does the latest handoff, review, and tasks file agree on what remains open?
- Did completed work leave stale "open issue" language behind?
- Do the dashboard sections still match the deeper evidence and historical notes?

Output goes in `review.md`.

## Repair Loop

If something fails:

1. Decide whether the spec, plan, task, code, validation fixture, or user/agent interpretation is wrong.
2. If the user or agent appears to be misreading expected behavior as a defect, say so plainly with evidence before patching.
3. Update the earliest wrong document, then refresh the dashboard sections that summarized it.
4. Re-run implementation from the corrected source.
5. Record what changed.

Tiny local defects can be patched directly, but repeated defects usually mean the spec or plan is underspecified.
