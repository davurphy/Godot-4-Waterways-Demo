# Waterways Development Constitution

These rules guide AI-assisted work on Waterways. Treat them as project-level constraints unless a human maintainer explicitly overrides them.

## 1. Target Godot 4.6+ First

Waterways is being ported into a modern Godot 4.6+ flow-map add-on.

The active add-on lives at:

- `addons/waterways`

## 2. Build a Reusable Flow-Map Add-on

Waterways should be a general-purpose Godot add-on for authoring, baking, previewing, and consuming flow maps.

Prefer reusable systems such as:

- river/curve authoring resources
- flow-map bake resources
- shader materials and presets
- debug visualizers
- editor gizmos and dock/tool controls
- runtime flow sampling APIs
- validation scenes

Avoid hard-coded assumptions about one game, one terrain layout, one material, one art style, or one specific scene hierarchy.

## 3. Prefer Native Godot Features

Before creating custom infrastructure:

1. Try Godot's built-in nodes, resources, editor APIs, shader features, and import settings.
2. Check current Godot 4.6+ documentation and established community patterns.
3. Build custom code only when native and known solutions cannot satisfy the spec.

Custom code should exist because the add-on needs it, not because it is convenient to generate.

## 4. Separate Editor Authoring, Bake Data, and Runtime Use

Waterways should keep these concerns clear:

- Editor tools: gizmos, menus, inspectors, preview controls, validation scenes.
- Bake pipeline: flow, foam, distance, height, masks, metadata, generated textures.
- Runtime APIs: sampling current direction, water altitude, shader parameters, buoyancy helpers.

Generated data should be explicit, inspectable, and reusable. Runtime systems should not depend on hidden editor-only state.

## 5. Keep It Simple and Maintainable

Prefer clear data flow, small modules, and boring names.
Avoid clever abstractions until repeated use proves they are needed.

Every substantial feature should be understandable by reading:

1. the spec,
2. the plan,
3. the primary node/resource/script,
4. the validation scene or test notes.

## 6. Godot Constraints Matter

Plans must account for Godot's actual behavior, not generic engine advice.

Be explicit about:

- Godot version assumptions
- Forward+, Mobile, and Compatibility renderer assumptions
- shader limitations and screen/depth texture behavior
- editor/runtime differences
- resource ownership and scene serialization
- texture import settings for data maps
- physics engine assumptions, especially Godot Physics versus Jolt
- performance constraints around bake passes and GPU readbacks

If a feature depends on a Godot version-specific capability, name it in the plan.

## 7. Challenge Misread Context Early

The agent should not silently accept a premise it has good reason to doubt.

If local evidence, scene state, prior validation, engine behavior, or project context suggests that the user is misunderstanding the situation or overlooking an important fact, the agent should say so early and plainly before spending substantial time implementing or investigating a likely non-issue.

Good pushback is:

- specific about the observed evidence
- proportional to confidence and risk
- framed as a hypothesis when uncertain
- paired with a quick check or falsifiable next step
- respectful of the user's context and prior observations

Bad pushback is:

- reflexively contradicting the user without evidence
- blocking useful work because of vague doubt
- repeating the same objection after the user provides new evidence
- treating local/static checks as stronger than visible editor/runtime evidence

When confidence is mixed, prefer language like: "I may be missing something, but the scene/data suggests X rather than Y. Can we verify this before patching?" If the user explicitly chooses to proceed anyway, record the assumption and continue within the agreed scope.

## 8. Visual Features Need Visual Validation

Flow maps, water shaders, foam, debug views, editor gizmos, and bake outputs need a runnable validation scene or equivalent visual check.

Current project reality: the agent must not assume it can open or interact with the visible Godot editor. In this workspace, local Godot attempts are limited and may stop at sandbox errors or crash, especially non-editor scene/runtime execution. Headless editor-load attempts can sometimes reveal parser or tool-script errors, but they are not proof of visible editor behavior, gizmo behavior, shader output, bake correctness, or runtime gameplay behavior.

When a check needs the visible Godot editor, viewport interaction, scene running, shader visual inspection, baking, or runtime behavior, treat it as human-assisted by default. The agent must put the exact human validation request in its chat message, including scene paths, steps to run, what output/errors to copy, what visible behavior to report, and the Godot version/renderer details to include. Do not require the user to open `validation.md` just to discover the requested test.

Record human-assisted validation in the relevant `validation.md`, `review.md`, or handoff file instead of treating the check as unrun.

The validation scene should make failure obvious:

- exaggerated debug colors or overlays where useful
- fixed camera positions
- representative curves, bends, slopes, banks, and obstacles
- controls or presets for edge cases
- clear expected visual outcomes in `validation.md`

Shader compilation is not proof of visual correctness. Flow direction, seams, foam placement, alpha, height, and runtime sampling must be inspectable.

## 9. Performance Is a Feature

Waterways should stay responsive in the editor and cheap enough at runtime for real projects.

Plans should define performance-sensitive paths, expected scale, and a lightweight way to measure regressions.

When relevant, include budgets or checks for:

- editor bake time
- frame time
- draw calls
- shader complexity
- generated texture memory
- GPU readbacks
- physics raycast count
- add-on startup/reload cost

## 10. Specs Drive Review

Review code against the accepted spec and plan.
Do not review only from taste or intuition.

If code reveals that the spec was incomplete, update the spec before widening the implementation.

## 11. Leave a Trail

Each substantial change should leave enough documentation for the next session to continue:

- what was decided
- why it was decided
- what remains risky
- how to run validation
- what should not be generalized yet

## 12. Documentation Is Part of the Change

Code should be documented at the level needed for a future maintainer to understand intent, boundaries, and safe extension points.

Use comments for:

- non-obvious algorithms or engine workarounds
- Godot-specific quirks that affected the implementation
- shader math, rendering assumptions, and coordinate-space conversions
- performance-sensitive decisions
- places where editor-only code intentionally stops and runtime code begins

Avoid comments that merely repeat what the code says.
Prefer clear names and small functions first, then add comments where context would otherwise be lost.

Feature and architectural changes should update the relevant spec-driven documents:

- `spec.md` for behavior, acceptance criteria, and user-facing intent
- `plan.md` for architecture, data flow, module boundaries, and important tradeoffs
- `validation.md` for test scenes, manual checks, performance checks, and expected visual results
- `review.md` for known risks, follow-up work, and spec compliance


Create the feature subfolder by copying `spec-driven/templates/feature-folder/`, then fill in the copied files for that feature.
