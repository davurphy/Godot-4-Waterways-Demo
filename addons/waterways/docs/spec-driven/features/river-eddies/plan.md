# Plan: River Eddies

## Spec Link

`spec.md`

## Architecture Summary

River eddies currently use a layered visual architecture:

- Raw source masks: `obstacle_features.g` for downstream wake / eddy seed, `obstacle_features.b` for old eddy-line/shear diagnostics, and `obstacle_features.a` for confidence.
- Final visual masks: shader-side `Wake Visual Mask`, `Wake Edge Thinness`, and `Eddy-Line Visual Mask`.
- Visible material response: surface-only wake breakup, narrow eddy-line turbulence, normal detail, roughness/specular breakup, albedo breakup, and small noisy foam flecks.
- Diagnostics: B-based and G-based debug views that preserve the channel/phase alignment evidence.
- Validation: human-assisted viewport review plus scripted probes and exports.

The accepted Phase 7B architecture does not change source flow, final flow, reverse/circulating flow, WaterSystem shader wiring, WaterSystem generation, saved WaterSystem bakes, or `RiverBakeData` layout.

The review architecture follows the feature-detection loop:

1. Pick one wake/eddy-line question and one target area.
2. Review the raw source mask first.
3. Review the final visual/debug mask second.
4. Review visible water last.
5. Let the user confirm in the visible editor/runtime viewport.
6. Add raw readings if coverage, false positives, or a user-marked area matters.
7. Make the smallest scoped change.

## Current Truth

- Implementation status: Phase 7B visual baseline complete and accepted.
- Open architectural decisions: Phase 7C data model for real reverse/circulating flow.
- Last validation that proves the plan still works: Historical Godot 4.6.3 probes and user viewport acceptance of the Phase 7B visible pass.
- Next planned implementation slice: Preserve and validate the accepted Phase 7B baseline after any shared shader/classifier change. If actual eddy flow is requested, write a Phase 7C plan before editing code.
- Branch safety before implementation: Not checked for future code changes; this documentation consolidation is safe. Before shader, classifier, bake, or WaterSystem edits, use a dedicated feature branch or get explicit approval to continue on the current branch.
- Sections below that are historical or superseded: Phase 7A1 raw-B preflight assumptions are superseded by the accepted raw-G visual path, but remain in `research.md` and diagnostics for comparison.

## Premise Check

Before implementing, decide whether the request is visual material response, final visual mask placement, raw source placement, or actual flow/physics behavior.

- Evidence supporting the current premise:
  - User accepted Phase 7B visual eddy-line placement.
  - `Eddy-Line Visual Mask` now uses raw-G wake-edge candidate plus context at `wake_edge_sample_tiles = 0.024`.
  - Old raw-B path remains available through diagnostics.
  - Phase 7B validation passed with `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK` and `PHASE7B_WAKE_EDDY_EXPORT_OK`.
- Evidence against treating Phase 7B as flow:
  - Phase 7B did not redirect flow vectors or alter `flow_force`.
  - `system_renders/system_flow.gdshader` does not consume obstacle wake/eddy features for Phase 7B.
  - The saved WaterSystem bake was not regenerated.
  - Existing scalar masks do not encode eddy center, spin side, circulation radius, or reverse velocity.
- User-facing pushback or clarification needed before patching:
  - If asked for reverse flow, explain that this is Phase 7C/7D work and must include visible, debug, system-flow, WaterSystem generation, and runtime validation together.
  - If asked for visual polish, confirm whether raw/final mask placement is still accepted first.
- Smallest check that can falsify the premise:
  - Compare `Raw Wake-Edge Candidate (from G)`, `Eddy-Line Visual Mask`, and visible water at the same target. If raw/final placement is accepted but visible response is too subtle, only material response should change.

## Layers

Editor authoring layer:

- Debug View menu entries for Wake / Eddy views.
- Inspector material grouping for `wake_` uniforms.
- Human-assisted editor review in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.

Bake/data layer:

- Current saved sources: `obstacle_features.g`, `.b`, `.a`, `terrain_contact_features.b`, `bank_response_features.a`, `dist_pressure.b`, and final flow context.
- Phase 7A2 source-signature `17` changed raw B; later current bakes are signature `19` due to pillow work.
- Future Phase 7C may add eddy vector data, but that is not part of Phase 7B.

Runtime layer:

- Visible river shader uses accepted final masks for surface response.
- Debug shader mirrors mask logic for review.
- WaterSystem/physics flow remains out of scope unless Phase 7C/7D is explicitly scoped.

Validation layer:

- Godot probes for shader/material/debug wiring.
- Export helpers for stable review captures.
- CPU/readback diagnostic for raw B/G/A and retention.
- Human-assisted viewport review as acceptance.

Legacy reference layer:

- No current legacy dependency.

## Godot Components

- Nodes: River nodes in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`.
- Resources: `waterways_bakes/Demo/Water_River.river_bake.res`, `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`, `waterways_bakes/Demo/WaterSystem.water_system_bake.res`.
- Shaders: `addons/waterways/shaders/river.gdshader`, `addons/waterways/shaders/river_debug.gdshader`, `addons/waterways/shaders/system_renders/system_flow.gdshader`.
- Filter shaders: `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`.
- Editor tools: `addons/waterways/gui/debug_view_menu.gd`, inspector material controls.
- Scripts/resources: `addons/waterways/resources/river_bake_data.gd`, `addons/waterways/system_map_renderer.gd`, `addons/waterways/river_manager.gd`, `addons/waterways/filter_renderer.gd`.
- Scenes: `Demo.tscn`, `Demo_obstacle_flow_test.tscn`.
- Validation helpers: `.codex-research/phase7b_eddy_line_cpu_diagnostic.gd`, `.codex-research/phase7b_wake_eddy_visual_probe.gd`, `.codex-research/export_demo_phase7b_wake_eddy_views.gd`, `.codex-research/export_demo_phase7b_wake_edge_sample_sweep.gd`.

## Data Model

Current Phase 7B data:

- `obstacle_features.g`: raw downstream wake / eddy seed mask.
- `obstacle_features.b`: raw eddy-line/shear diagnostic mask after Phase 7A2.
- `obstacle_features.a`: obstacle confidence envelope.
- `terrain_contact_features.b`: terrain/world protrusion or intersection context.
- `bank_response_features.a`: hard-boundary / protrusion response candidate.
- `dist_pressure.b`: grade/energy.
- `flow_foam_noise.rg`: packed signed baked flow vector.

Accepted current formula direction:

1. `Wake Visual Mask` derives a gated surface wake from raw G, confidence, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, and normalized final-flow strength.
2. `Wake Edge Thinness` samples the wake/edge field in source-tile units.
3. `Eddy-Line Visual Mask` uses a raw-G wake-edge candidate plus nearby wake/hard-protrusion context at `wake_edge_sample_tiles = 0.024`.
4. B-based paths remain diagnostic for comparison because raw B was spatially too far downstream for the accepted close-behind-rock pattern.

Future Phase 7C data possibilities:

- New explicit eddy vector/strength texture with center/spin/radius/strength metadata.
- Analytic vector field derived from accepted masks and obstacle context.
- Regenerated physics-facing flow field that includes eddy circulation.

No future option should be accepted unless visible/debug/system-flow parity and runtime validation are planned together.

## Phase Boundaries

Phase 7B preservation or visual tuning:

- May adjust final visual mask gates or material response only after raw/final placement review.
- Must keep visible/debug shader parity.
- Must not change source signatures, rebake river resources, or regenerate WaterSystem bakes unless the change is not actually visual-only.

Phase 7C reverse/circulating flow:

- Must define the eddy vector/velocity model.
- Must update `river.gdshader`, `river_debug.gdshader`, `system_renders/system_flow.gdshader`, and WaterSystem generation together.
- Must include runtime validation with buoyant objects or equivalent flow sampling.
- Must not save a new WaterSystem bake until visible direction changes are reviewed.

Phase 7D WaterSystem/physics alignment:

- Must regenerate and validate saved WaterSystem data after final-flow changes are accepted.
- Must confirm objects move according to the same river behavior the player sees.

## Editor/Runtime Boundary

- Editor-only code: Debug menus, capture helpers, probe scripts, editor-visible validation.
- Runtime-safe code: Visible/debug shader uniforms and material behavior.
- Shared data/resources: `RiverBakeData` textures, source metadata, saved river bake resources, saved WaterSystem bake when explicitly regenerated.
- APIs exposed to user projects: Material uniforms and future runtime flow sampling behavior.
- Assumptions that must not cross the boundary: Debug material state must not replace visible material state, and visual-only masks must not be treated as physics.

## Runtime Flow

Current Phase 7B:

1. River material samples existing baked textures.
2. Shader computes final flow without wake/eddy reverse-flow changes.
3. Shader derives wake and eddy-line visual masks from existing feature/context maps.
4. Accepted masks drive only surface response.
5. WaterSystem flow remains the accepted Phase 5B baseline.

Future Phase 7C/7D:

1. River material samples or computes eddy vector data.
2. Visible and debug shaders apply the same final-flow adjustment.
3. System-flow shader receives the same inputs and produces matching WaterSystem data.
4. WaterSystem bake is regenerated after user review accepts visible direction changes.
5. Runtime validation confirms buoyant objects and flow sampling agree.

## Bake Flow

Current Phase 7B:

1. Existing river bakes provide obstacle, terrain-contact, bank-response, grade/energy, and flow data.
2. No Phase 7B source-signature bump or river rebake is required.
3. No WaterSystem regeneration is required.

Future bake-level eddy work:

1. Revise classifier or add eddy vector data only after raw source placement is proven wrong or Phase 7C is scoped.
2. Update metadata, channel descriptions, source signatures, probes, and exported captures.
3. Rebake main and obstacle-test river resources.
4. Regenerate WaterSystem only when final/physics flow changes, not for scalar visual masks alone.

## Lifecycle, Cleanup, and Re-entry

Success path:

- Phase 7B baseline remains stable.
- Future requests are classified by layer before code changes.
- Docs, tasks, validation, review, and handoff are updated together after decisions.

Preflight or early-return path:

- If raw/final placement remains accepted, do not change classifier or source signatures.
- If visible response is the only issue, keep work shader/material-only.
- If request is actual reverse flow, stop and draft Phase 7C plan before implementation.

Awaited failure path:

- If local Godot probes fail or visible review is unavailable, ask for human-assisted validation with exact scene paths, debug views, output/errors, expected result, and Godot version/renderer.

Temporary node/resource ownership:

- `.codex-research` helpers and exports remain ignored local tooling unless intentionally promoted.
- Generated captures should be recorded in validation or handoff artifact hygiene.

Progress, dirty-state, and user feedback:

- Visual-only shader changes should not dirty bakes.
- Classifier or data changes should update source metadata and mark stale bakes through signature changes.
- WaterSystem regeneration must be explicit and documented.

Duplicate or overlapping requests:

- Do not mix pillow placement changes, eddy visual tuning, classifier changes, and WaterSystem flow changes in one unreviewed slice.

Scene reload or runtime boundary:

- Debug View Normal must restore visible material behavior.
- Saved scenes must not preserve stale debug shader overrides on generated river meshes.

## Files to Change

Potential future files, only after review confirms the diagnosed layer:

- `addons/waterways/shaders/river.gdshader`: Visual wake/eddy masks, material response, or future final-flow logic.
- `addons/waterways/shaders/river_debug.gdshader`: Debug parity for masks and future final-flow logic.
- `addons/waterways/gui/debug_view_menu.gd`: Debug view labels and menu wiring.
- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`: Raw wake/eddy-line classifier changes.
- `addons/waterways/resources/river_bake_data.gd`: Future eddy vector resource/channel metadata.
- `addons/waterways/filter_renderer.gd`: Future bake pass plumbing.
- `addons/waterways/river_manager.gd`: Future bake/generation integration.
- `addons/waterways/shaders/system_renders/system_flow.gdshader`: Required for Phase 7C/7D final-flow parity.
- `addons/waterways/system_map_renderer.gd`: Required for passing eddy flow inputs into WaterSystem generation.
- `.codex-research/*phase7*`: Probes, exports, readbacks, and review captures.

## Documentation Plan

- Code comments needed:
  - Only for non-obvious shader math, source-tile sampling, future vector semantics, and WaterSystem parity.
- Feature docs to update:
  - This folder after every eddy/wake decision, validation run, or implementation slice.
- Architecture or data-flow docs to update:
  - Roadmaps only when high-level Phase 7/8 plan changes.
- Validation docs to update:
  - `validation.md` current snapshot, matrix, recorded results, and human-assisted request.
- Migration notes to update:
  - `docs/history/CHANGELOG.md` and shared `docs/handoffs/handoff-latest.md`.

## Validation Strategy

- Automated:
  - Use Phase 7B probes for shader/debug/export coverage after visual changes.
  - Use CPU/readback diagnostics for raw B/G/A and retention when source placement is questioned.
- Validation matrix location:
  - `validation.md` "Validation Matrix".
- Human-assisted:
  - Required for visible Godot editor/runtime placement acceptance.
- Visual:
  - Compare same targets across raw G, raw B diagnostics, final masks, and visible water.
- Shader:
  - Confirm visible/debug parity and material controls.
- Editor:
  - Confirm Debug View menu and material override behavior.
- Runtime:
  - Not scoped for Phase 7B; required for Phase 7C/7D.
- Performance:
  - No new runtime readback or WaterSystem generation for visual-only changes.
- Manual:
  - Confirm docs do not imply Phase 7B is physics-facing.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Future work treats visual eddy-line masks as physics | Buoyancy and visible water disagree | Keep Phase 7C/7D gates explicit and require WaterSystem parity for flow changes. |
| Raw B diagnostics are removed | Future sessions lose the channel/phase lesson | Preserve B-based debug views until a later spec removes them deliberately. |
| Start-of-river hotspot drives tuning | False acceptance or overfitted parameters | Exclude the hotspot from acceptance and review rock-garden/downstream-rock targets. |
| Ordinary banks become eddy-line strips | Shoreline artifacts and false positives | Keep ordinary-bank suppression and review smooth-bank controls. |
| Shared classifier changes regress accepted Phase 7B | Visual baseline lost while fixing another feature | Re-run Phase 7B probes and human review after shared `obstacle_features` edits. |
| Phase 7C vector field is not mirrored in system flow | Visible/runtime mismatch | Update visible, debug, system-flow, WaterSystem generation, and runtime validation together. |

## Adversarial Plan Review

- Most likely way this plan could damage working behavior:
  - Letting a visual-only or shared classifier edit alter final flow, WaterSystem output, or accepted Phase 7B mask placement.
- Project state, generated resource, scene, or workflow most at risk:
  - Saved river bakes, saved WaterSystem bake, generated demo river mesh material state, and Wake / Eddy debug views.
- Files or data that are riskier than they look:
  - `obstacle_feature_mask_filter.gdshader`, because it affects pillows, wake, eddy-line, and confidence channels.
  - `system_flow.gdshader`, because flow changes must match visible water and saved WaterSystem behavior.
- Simpler or safer approach considered:
  - Keep Phase 7B visual-only and preserve diagnostics until a concrete Phase 7C request exists.
- Validation that will catch the riskiest failure early:
  - Phase 7B visual probe/export, CPU diagnostic, debug menu wiring probe, and user viewport comparison at known accepted rock/wake targets.
- Branch safety reminder sent before code changes:
  - No code changes in this docs migration; needed before future implementation.

## Migration and Compatibility

- Active implementation targets Godot 4.6+.
- Legacy Godot 3 behavior is not a design mandate for this feature.
- Current docs migration is documentation-only.
- Phase 7B visual work did not change `RiverBakeData` layout, source signatures, final flow, or saved WaterSystem data.
- Future Phase 7C/7D must include resource compatibility, stale bake handling, regenerated resources, and runtime validation.
