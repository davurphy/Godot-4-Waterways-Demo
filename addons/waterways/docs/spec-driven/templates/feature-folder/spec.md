# Spec: <Feature Name>

## Summary

Describe the feature in plain language.

## Current Truth

Use this short section as the dashboard for the current spec state. Keep it current; move older detail into the sections below instead of letting stale open questions linger.

- Status: <Draft / Accepted / In progress / Complete / Blocked>
- Source of truth for open work: `<tasks.md section or issue>`
- Last meaningful decision:
- Known deferred items:
- Current non-goals that are easy to accidentally reopen:

## Goals

- <Goal>

## Non-Goals

- <Explicitly out of scope>

## Context and Assumptions

- Known scene/data/context facts:
- User-reported observations:
- Agent confidence in the premise:
- Possible expected-behavior explanations to rule out before patching:
- Clarification or challenge already raised with the user:

## Users and Workflows

### User Story: <Name>

As a <user/developer/add-on maintainer>, I want <capability>, so that <outcome>.

Acceptance criteria:

- <Observable result>

## Functional Requirements

- <Requirement>

## Non-Functional Requirements

- Maintainability:
- Performance:
- Visual quality:
- Godot 4.6+ compatibility:
- Editor usability:
- Runtime usability:
- Extensibility:

## Add-on Boundary

Editor authoring responsibilities:

- <Gizmos, inspector, toolbar, bake controls, debug views>

Bake/data responsibilities:

- <Generated textures, resources, metadata, channel layout, storage>

Runtime responsibilities:

- <Shader inputs, flow sampling, altitude sampling, buoyancy helpers, public APIs>

Shared code must not depend on:

- <Editor-only state, legacy Godot 3 APIs, one scene layout, one material preset, or one project-specific asset>

## Data and Extension Model

Users should be able to:

- <Add, replace, configure, or disable resources/assets/behavior>

Extension points:

- <Resource, config, shader preset, scene, script hook, importer, editor tool, or data layer>

Override rules:

- <Priority, conflict behavior, fallback behavior, or not applicable>

Shared systems must not hard-code:

- <Bundled texture, specific scene hierarchy, material-only assumption, or one-off behavior>

## Acceptance Tests

- <Testable acceptance criterion>

## Visual Validation Requirements

- <Scene/debug view/procedure needed to prove the visual behavior>

## Performance Requirements

- <Bake-time, frame-time, memory, draw-call, shader, or raycast target>

## Open Questions

- <Question>

## Resolved Questions

Move questions here once decided so future sessions do not keep treating them as open.

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| <Question> | <Decision> | <YYYY-MM-DD> | <Why or where validated> |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| <YYYY-MM-DD> | <Decision> | <Reason> |
