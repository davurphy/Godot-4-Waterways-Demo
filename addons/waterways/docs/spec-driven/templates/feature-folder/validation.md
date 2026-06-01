# Validation: <Feature Name>

## What Must Be Proven

- <Acceptance criterion or visual/performance requirement>

## Current Validation Snapshot

Keep this short and current. Older detailed runs belong in "Recorded Results" below.
This is the validation dashboard. The matrix answers what is currently proven; recorded results and archives explain how those conclusions were reached.

- Overall status: <Unrun / Partial / Pass / Blocked>
- Last automated pass:
- Last human-assisted pass:
- Highest-risk unproven behavior:
- Known unreliable local check or environment caveat:

## Validation Matrix

Use this as the durable map from requirements to proof. Prefer stable probe names, scene names, or result markers.

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| <Requirement> | <Command, probe, or scene> | <Headless/editor/Forward+/human visible> | <PASS marker or visible behavior> | <Pass/Fail/Partial> | <YYYY-MM-DD> | <Agent/User> |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index for river behavior, hydrology, flow maps, shader water, and production examples. Consult it when validating whether a behavior matches external references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation:
- What the agent should say to the user if that evidence appears:
- Quick falsifying check before patching:

## Automated Checks

- Command or procedure:
- Expected result:
- Agent limitation note:
  - Local checks may include static scans, parser checks, or headless editor-load probes when they work.
  - Do not treat local headless/editor-load checks as proof of visible editor interaction, shader visuals, bake output, or runtime behavior.

## Human-Assisted Validation

Use this by default for visible Godot editor checks, viewport interaction, scene running, gizmos, shader visuals, bake output, and runtime behavior. The agent may not be able to open or interact with Godot reliably.

When requesting this validation, the agent must put the exact request in the chat message so the user does not have to open this file to discover what to run.

- Request to user:
- Exact scene, command, or workflow to run:
- Plugin state required:
- Console output or errors to relay back:
- Screenshot or visible behavior to relay back:
- Godot version and renderer to relay back:
- Expected result:
- Failure signs:
- Result recording format:
  - Date:
  - Ran by:
  - Godot version/renderer/device:
  - Output or parser errors:
  - Visible result:
  - Pass/partial/fail:

## Recorded Results

Record new runs here. Put the newest and most relevant result first, then move older detail under an archive marker when the section gets long.

Recorded result:

- Date:
- Ran by:
- Godot version/renderer/device:
- Command, scene, or workflow:
- Output or parser errors:
- Visible result, if applicable:
- Stable result marker:
- Pass/partial/fail:
- Notes or follow-up:

## Historical Results Archive

Move older validation narratives here once the current snapshot and matrix carry the important status.

## Shader Checks

- Shader/material path:
- Renderer backend:
- Expected result:
- Failure signs:

## Editor Workflow Check

Procedure:

1. <Step>
2. <Step>
3. <Step>

Expected result:

- <What the editor user should see or be able to do>

Failure signs:

- <Errors, missing UI, broken undo/redo, stale previews, invalid resources>

## Visual Test Scene

Scene path:

- `<path/to/test_scene.tscn>`

Purpose:

- <What this scene proves>

Expected visual result:

- <What a human should see>

Failure signs:

- <Obvious signs the feature is broken>

Suggested controls or debug views:

- <Toggle, slider, camera preset, debug overlay>

## Bake Output Check

Scenario:

- <Curve/river/material/obstacle setup>

Expected generated outputs:

- Flow:
- Foam:
- Distance/pressure:
- Height/alpha:
- Metadata:

Failure signs:

- <Wrong direction, seams, stale texture, empty map, bad bounds, wrong channels>

## Runtime API Check

Procedure:

- <How to query or consume the generated data at runtime>

Expected result:

- <Flow vector, altitude, shader behavior, or gameplay response>

Failure signs:

- <Fallback values, stale image data, coordinate mismatch, runtime-only error>

## Performance Check

Scenario:

- <Representative workload>

Budget or target:

- <Bake time, frame time, memory, draw calls, GPU readbacks, raycast count, etc.>

How to measure:

- <Procedure>

## Artifact Hygiene Check

- Scratch project or temporary folder used:
- Active scripts/resources mirrored into scratch before validation:
- Generated bakes/resources created:
- Files or folders that must be excluded from packaging:
- Files or folders safe to delete now:

## Extension Check

Custom content scenario:

- <Alternate resource, shader preset, texture, scene setup, or not applicable>

Expected result:

- <How the custom content should load, override, or coexist>

Failure signs:

- <Hard-coded bundled content, ignored replacement, broken fallback behavior>

## Manual Review Checklist

- [ ] Acceptance criteria are satisfied.
- [ ] Likely false premises or expected-behavior explanations were raised with the user before extra implementation work.
- [ ] Human-assisted Godot/editor/test results are recorded when the agent could not run them directly.
- [ ] Active code uses Godot 4.6+ APIs and avoids obsolete Godot 3 APIs.
- [ ] Editor-only and runtime-safe boundaries are preserved.
- [ ] Generated resources and metadata are explicit and inspectable.
- [ ] Visual output matches the spec.
- [ ] Flow direction, seams, foam, masks, and bounds are checked visually.
- [ ] Runtime sampling/API behavior matches generated data.
- [ ] Performance-sensitive paths have been checked.
- [ ] Known limitations are documented.
- [ ] Shared research citations were checked or updated when external river/water references affected the decision.
