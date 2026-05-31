# Plan: <Feature Name>

## Spec Link

`spec.md`

## Architecture Summary

Describe the chosen architecture and why it satisfies the spec.

## Current Truth

Keep this section short and update it whenever the plan changes.

- Implementation status: <Not started / In progress / Complete / Blocked>
- Open architectural decisions:
- Last validation that proves the plan still works:
- Next planned implementation slice:
- Branch safety before implementation: <Not checked / User will create branch / Codex created branch / User approved current branch>
- Sections below that are historical or superseded:

## Premise Check

Before implementing, record whether the problem is definitely a code/design issue or could be expected behavior from scene setup, generated data, stale resources, Godot limitations, or validation interpretation.

- Evidence supporting the premise:
- Evidence against the premise:
- User-facing pushback or clarification needed before patching:
- Smallest check that can falsify the premise:

## Layers

Editor authoring layer:

- <Gizmos, toolbar controls, inspector plugins, debug UI>

Bake/data layer:

- <Bake pipeline, generated textures, resources, metadata, import settings>

Runtime layer:

- <Sampling APIs, shader inputs, gameplay helpers>

Validation layer:

- <Test scene/tool/test/procedure>

Legacy reference layer:

- <Godot 3 behavior being preserved or intentionally changed>

## Godot Components

- Nodes:
- Resources:
- Shaders:
- Editor tools:
- Importers:
- Autoloads:
- Scenes:
- Validation scenes:

## Data Model

Describe resources, serialized fields, generated textures, channel packing, runtime data, ownership, and save/load behavior.

## Editor/Runtime Boundary

- Editor-only code:
- Runtime-safe code:
- Shared data/resources:
- APIs exposed to user projects:
- Assumptions that must not cross the boundary:

## Runtime Flow

1. <Step>
2. <Step>
3. <Step>

## Bake Flow

1. <Input>
2. <Intermediate passes>
3. <Output textures/resources>
4. <Metadata written>
5. <How the result is previewed and consumed>

## Lifecycle, Cleanup, and Re-entry

For async, rendering, editor, or bake work, answer these explicitly before implementation.

- Success path:
  - <What state/resources/progress/UI are finalized?>
- Preflight or early-return path:
  - <What state/resources/progress/UI are cleaned or left untouched?>
- Awaited failure path:
  - <What happens after a renderer, viewport, file, or async operation fails?>
- Temporary node/resource ownership:
  - <Who creates it, who frees it, and when?>
- Progress, dirty-state, and user feedback:
  - <When are signals/UI emitted, hidden, or skipped?>
- Duplicate or overlapping requests:
  - <Ignored, queued, cancelled, disabled in UI, or otherwise guarded?>
- Scene reload or runtime boundary:
  - <What state must not depend on editor-only memory?>

## Files to Change

- `<path>`: <reason>

## Documentation Plan

- Code comments needed:
- Feature docs to update:
- Architecture or data-flow docs to update:
- Validation docs to update:
- Research citations index: `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited list for river behavior, flow-map, shader-water, and production-reference sources. Consult it before research-driven changes and update it when adding new sources.
- Migration notes to update:

## Validation Strategy

- Automated:
- Validation matrix location:
  - `<validation.md section/table>`
- Human-assisted:
- Visual:
- Shader:
- Editor:
- Runtime:
- Performance:
- Manual:

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| <Risk> | <Impact> | <Mitigation> |

## Adversarial Plan Review

Complete this with the user after the plan is drafted and before implementation starts.

- Most likely way this plan could damage working behavior:
- Project state, generated resource, scene, or workflow most at risk:
- Files or data that are riskier than they look:
- Simpler or safer approach considered:
- Validation that will catch the riskiest failure early:
- Branch safety reminder sent before code changes: <Yes / No>

## Migration and Compatibility

Describe any Godot 3-to-4 behavior, data, scene, resource, shader, or API compatibility concerns.
