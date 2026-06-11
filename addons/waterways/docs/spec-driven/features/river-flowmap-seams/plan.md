# Plan: River Flowmap Seam Handling

## Spec Link

`spec.md`

## Architecture Summary

Use the v2 seam plan as the controlling architecture: classify the current visible artifact first, then build only the smallest fix proven by that classification. The plan treats lateral cross-column reads as the first likely shader-side fix if offset sampling is implicated, while strip packing and the full logical UV2-neighbor sampler remain conditional branches.

## Current Truth

- Implementation status: Not started; stopped at baseline because no current visible seam was reproduced.
- Open architectural decisions: none selected for implementation. Build C, a depth-1 bake decision, a normal/tangent fix, Build A, and Build B are all conditional on new visible evidence.
- Last validation that proves the plan still works: 2026-06-11 baseline screenshot export produced `RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK` and found no visible seam in either demo scene; prior signature 23 probes reported `RIVER_FLOWMAP_SEAM_PROBE_OK` and `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`.
- Next planned implementation slice: none until a visible seam is reproduced or the user explicitly requests extra diagnostics.
- Branch safety before implementation: checked before editing docs/validation tooling; no destructive git action taken.
- Sections below that are historical or superseded: `Revised plan to improve seam handling.md` is superseded by `Revised plan to improve seam handling v2.md`.

## Premise Check

Before implementing, record whether the problem is definitely a code/design issue or could be expected behavior from scene setup, generated data, stale resources, Godot limitations, or validation interpretation.

- Evidence supporting the premise:
  - Earlier observations reported visible seam-positive debug views.
  - Depth-1/2 deltas still appear in terrain-contact channels after signature 23.
  - Lateral shader offsets can cross interior column X edges without margin protection.
  - Duplicated join vertices with differing UV2 can leave a discontinuous normal/tangent basis.
- Evidence against the premise:
  - Exact duplicated edge rows already probe as continuous at depth 0.
  - The earlier visible symptom list predates signature 23.
  - The 2026-06-11 exported baseline found no visible straight seam in the checked lit-water, raw debug, or derived/material debug screenshots for either demo scene.
  - Current longitudinal row-wrap offsets are covered by one full tile of continuation margin.
  - Static unshaded debug seams cannot be temporal or lighting artifacts.
- User-facing pushback or clarification needed before patching:
  - Baseline review showed no visible seam remains, so tell the user before adding any fix.
  - If a depth-1 band reflects genuine nearby terrain/contact changes, document that before forcing data to match.
- Smallest check that can falsify the premise:
  - Done on 2026-06-11 with exported screenshots. Re-run only if new evidence or a new scene state appears.

## Layers

Editor authoring layer:

- Human-visible review of `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.
- Debug view selection, material uniform inspection, and possible normal/matcap review.

Bake/data layer:

- Existing signature 23 bake data, duplicated-edge synchronization, terrain-contact depth-1/2 observations, continuation margins, and source signatures.

Runtime layer:

- Shader offset paths, runtime uniform gates, temporal flow blend, visible ripples, material amplification, and possible lateral clamp.

Validation layer:

- Existing seam and world-sample probes, new depth-1 bilinear-bleed probe, offset-routing diagnostics if any sampling fix lands, human-visible baseline/final review.

Legacy reference layer:

- Legacy Waterways behavior is reference only. Active work targets Godot 4.6+.

## Godot Components

- Nodes: river nodes in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`
- Resources: saved demo river bakes under `waterways_bakes`
- Shaders: `addons/waterways/shaders/river.gdshader`, `river_debug.gdshader`, `lava.gdshader`, and `shaders/filters/*.gdshader` if Build A is considered
- Editor tools: bake workflow and debug/material inspection UI
- Importers: not expected for Build C; may matter if packing changes affect generated textures
- Autoloads: none currently identified
- Scenes: `Demo.tscn`, `Demo_obstacle_flow_test.tscn`
- Validation scenes: same demo scenes, plus any probe scene or script added for depth-1/offset routing

## Data Model

Current bakes use a square UV2 atlas represented by `i_uv2_sides`, with column-major step layout. Per-tile texel density is emergent from the bake resolution divided by the side count. Signature 23 preserves exact duplicated-edge continuity for the fixed channels, but does not force depth-1/2 rows to match.

Build C changes shader sampling only: lateral offsets are clamped to the current tile's X range at implicated call sites. It requires no new bake metadata, no source-signature bump, and no change to saved resources.

Build A would introduce explicit grid metadata such as `uv2_columns`/`uv2_rows` or `uv2_grid_size`, update all square-atlas assumptions, choose an explicit per-tile resolution rule, and require a source-signature bump.

Build B would add `i_occupied_steps` and logical-neighbor sampling only for offset paths proven to need longitudinal wrap beyond existing continuation margins.

## Editor/Runtime Boundary

- Editor-only code: visual scene review, bake triggering, inspector/debug UI, human-assisted validation.
- Runtime-safe code: shader sampling helpers, material uniforms, runtime river rendering.
- Shared data/resources: generated bake textures, metadata/source signature, river material settings.
- APIs exposed to user projects: existing Waterways river bake/render APIs and material uniforms.
- Assumptions that must not cross the boundary:
  - Do not let editor-only debug state become required for runtime seam handling.
  - Do not make demo-only scene structure part of a shared sampling fix.
  - Do not rely on stale bakes as evidence after changing bake code.

## Runtime Flow

1. River material receives UV2, bake textures, `i_uv2_sides`, and runtime uniforms.
2. Base and offset shader samples read bake channels for flow, foam, wake, pillow, ripple, and context masks.
3. Runtime-gated helpers may apply contextual flow slide, wake/eddy context, pillow smoothing, or visible ripple/normal sampling.
4. If Build C is implemented, lateral offsets clamp to the current tile X range before texture sampling.
5. The dual-phase flow blend uses `flow_foam_noise.a` phase noise to avoid uniform reset pulsing.

## Bake Flow

1. River curve/mesh and terrain context produce source samples for each logical step.
2. Steps are packed into the current square UV2 atlas.
3. Signature 23 bake logic synchronizes exact duplicated edge rows for the fixed channels.
4. Continuation margins add row-wrap neighbor data for longitudinal offsets.
5. Generated textures/resources and source signature are saved and consumed by runtime materials.

## Lifecycle, Cleanup, and Re-entry

For async, rendering, editor, or bake work, answer these explicitly before implementation.

- Success path:
  - Baseline and final findings are recorded in `review.md` and `validation.md`.
  - Any landed fix updates `tasks.md`, `plan.md`, and `session-handoff.md`.
- Preflight or early-return path:
  - If no visible seam remains, stop implementation and record the result as validation/context clarification. This path was taken on 2026-06-11.
- Awaited failure path:
  - If Godot launch, probe, renderer, or file access fails, record the failure and do not treat missing visual proof as a pass.
- Temporary node/resource ownership:
  - Probe scripts should use repo-local `.codex-research` user-data folders and remove or document scratch artifacts.
- Progress, dirty-state, and user feedback:
  - Tell the user when the premise is falsified, when human-visible validation is needed, and when a structural branch is being considered.
- Duplicate or overlapping requests:
  - Avoid running multiple bakes or editor sessions that mutate the same demo resources without a clear reason.
- Scene reload or runtime boundary:
  - Reopen scenes or reload bakes after source-signature changes before interpreting visual results.

## Files to Change

- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/spec.md`: feature spec and decisions.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/tasks.md`: active checklist.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/validation.md`: proof matrix and run records.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/review.md`: findings and review state.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/research.md`: v2 evidence and options.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/session-handoff.md`: next-session dashboard.
- `addons/waterways/shaders/river.gdshader`: possible Build C lateral clamp and related diagnostics.
- `addons/waterways/water_helper_methods.gd`: possible depth-1 bake decision, normal/tangent investigation, or Build A metadata work.
- `addons/waterways/river_manager.gd`: possible Build A metadata/uniform plumbing.
- `addons/waterways/shaders/river_debug.gdshader`: possible debug classification or offset-routing view.
- `addons/waterways/shaders/lava.gdshader`: only if Build A changes grid metadata.
- `addons/waterways/shaders/filters/*.gdshader`: only if Build A changes square texture assumptions.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/probes/*.gd`: existing probes plus the visible baseline exporter and any future depth-1/offset-routing probes.

## Documentation Plan

- Code comments needed: only for non-obvious shader clamp math, bake synchronization rules, or source-signature migration.
- Feature docs to update: `spec.md`, `plan.md`, `tasks.md`, `validation.md`, `review.md`, and `session-handoff.md`.
- Architecture or data-flow docs to update: only if Build A or Build B changes metadata or sampling contracts.
- Validation docs to update: record every baseline, ablation, probe, and final visible review result.
- Research citations index: `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited list for river behavior, flow-map, shader-water, and production-reference sources. Consult it before research-driven changes and update it when adding new sources.
- Migration notes to update: required only for source-signature bumps, atlas metadata changes, or saved-resource compatibility changes.

## Validation Strategy

- Automated:
  - Existing seam and world-sample probes.
  - New depth-1 bilinear-bleed probe.
  - Shader/parser checks and `git diff --check` after edits.
- Validation matrix location:
  - `validation.md` Validation Matrix
- Human-assisted:
  - Baseline and final visual review of the two demo scenes when interactive editor confirmation is needed. The 2026-06-11 baseline used exported screenshots reviewed by the agent.
- Visual:
  - Lit water vs. unshaded debug views; raw baked channels vs. derived/material views.
- Shader:
  - Ablate each runtime-gated helper group individually.
  - Confirm Build C clamp behavior if implemented.
- Editor:
  - Material override inspection for zero-default pillow uniforms.
- Runtime:
  - Confirm dual-phase reset is not visibly pulsing.
- Performance:
  - For Build C, check no unnecessary extra texture samples or metadata.
  - For Build A, estimate texture dimensions, memory, and per-tile texel density before adoption.
- Manual:
  - Record screenshots or user-observed behavior when local visible editor access is not reliable.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Building the wrong structural fix before current diagnosis | Wasted complexity and possible regressions | Require baseline capture, join classification, and ablation first. |
| Treating depth-1 terrain-contact differences as always wrong | Could erase legitimate local terrain/contact detail | Probe and correlate with visible seams before choosing a bake fix. |
| Strip packing changes texture density and metadata contracts | Broad shader, bake, and probe churn | Gate Build A on evidence plus a feasibility spike. |
| Full logical sampler adds shader complexity without current need | Performance and maintenance cost | Build only if ablation proves an offset path that continuation margins do not cover. |
| Lit-only normal/tangent issue is mistaken for data seam | Shader/data fixes miss the artifact | Compare lit water with unshaded debug views and inspect bases. |
| Human-visible review is skipped | Probes pass while perceptual seam remains | Make baseline and final visual review required validation. |

## Adversarial Plan Review

Complete this with the user after the plan is drafted and before implementation starts.

- Most likely way this plan could damage working behavior: treating a legitimate terrain-contact gradient as a seam and forcing data to match across nearby but non-identical rows.
- Project state, generated resource, scene, or workflow most at risk: demo bakes under `waterways_bakes`, river material overrides, and shader sampling paths shared by user projects.
- Files or data that are riskier than they look: `terrain_contact_features.a`, filter shaders with scalar `size`, and any source-signature metadata.
- Simpler or safer approach considered: no code change if current visible seams are gone; Build C before Build A/B when lateral sampling is implicated.
- Validation that will catch the riskiest failure early: baseline lit/debug capture plus depth-1 correlation before patching.
- Branch safety reminder sent before code changes: Yes, workspace state was checked before docs/validation-tool edits.

## Migration and Compatibility

No migration is expected for documentation, diagnosis, ablation, or Build C. Build A would require a source-signature bump and compatibility notes because it changes atlas packing and likely shader metadata from a scalar side count to grid dimensions. Build B may require new uniform plumbing but should not alter saved bake data unless paired with other changes.
