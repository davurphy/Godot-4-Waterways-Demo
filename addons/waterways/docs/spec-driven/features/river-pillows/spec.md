# Spec: River Pillows

## Summary

River pillows are the upstream impact/compression features that appear where river current meets rocks, hard protrusions, or other meaningful obstructions. The Waterways add-on should detect, debug, tune, and render these features without overfitting to one demo scene or confusing them with downstream wakes and eddy lines.

Feature terms used by this spec:

- Pillow: upstream compression or pressure on the impact face of a rock, boulder, wall, or hard protrusion.
- Wake: downstream disturbed region behind an obstruction where the main current has been split, slowed, or broken up.
- Eddy line: narrow boundary where main current shears against wake or slower/recirculating water.
- Ordinary bank: normal shoreline or bank friction that should not automatically become a pillow, wake, or eddy.
- Hard protrusion: obstacle, cliff, or terrain contact that intrudes into flow enough to justify stronger feature detection.
- Raw mask: baked/source feature mask before shader gates.
- Final visual mask: shader-side mask after confidence, context, energy, flow, and suppression gates.

## Current Truth

This is the spec dashboard. Keep it limited to active state and link to goals, context, resolved questions, or the decision log for deeper rationale.

- Status: In progress
- Source of truth for open work: `tasks.md` "Open Work"
- Last meaningful decision: 2026-06-01 diagnostic review confirmed bank-response/combined contact gating is too broad, so raw pillow R should be direct-contact-first.
- Last audit update: Direct-contact-first raw R has been implemented in code and source signature bumped to `20`; main and obstacle-test bakes still need regeneration and review.
- Latest user-visible finding: `Pillow / Impact Mask` and Black Zero final mask still start ahead on signature-`19` bakes; direct terrain anchor search is closest to desired placement, while bank-response/combined contact remains too broad.
- Known deferred items: Material polish, stronger height response, final flow changes, reverse/circulating flow, WaterSystem/physics alignment.
- Current non-goals that are easy to accidentally reopen: Do not change accepted Phase 5 flow, accepted Phase 7B eddy-line behavior, WaterSystem flow, terrain-contact thresholds, bank-response thresholds, or saved WaterSystem bakes unless explicitly scoped.

## Goals

- Place pillow starts at the visible upstream impact/compression face of rocks and hard protrusions.
- Keep raw placement and final visual response separately inspectable.
- Keep raw source masks, final masks, and visible material response as separate review layers.
- Build enough raw/numeric tooling that detection decisions do not rely only on screenshots.
- Use user-confirmed viewport review to define should-detect and should-not-detect areas.
- Provide readable debug views for raw mask, final mask, and any diagnostic source terms needed to resolve placement errors.
- Keep pillow visuals controllable through `pillow_` material parameters.
- Preserve accepted flow, wake, and eddy-line work unless a new scoped feature changes them.
- Make the feature general enough for other river layouts, not only `Demo.tscn`.

## Non-Goals

- Do not implement reverse or circulating eddy flow as part of pillow placement.
- Do not regenerate WaterSystem/physics flow unless final flow changes are explicitly scoped.
- Do not tune wake/eddy material response while solving pillow placement.
- Do not treat `bank_response_features.a` or dilated collision support as correct just because they are already available.
- Do not accept screenshots or static exports alone when a visible editor/runtime review is needed.
- Do not overfit to `Demo.tscn`; the main demo is the first review environment, not the whole target.
- Do not use pillow masks to imply reverse/circulating flow or physics behavior.

## Context and Assumptions

- Known scene/data/context facts:
  - Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`. Future Codex sessions should use this as the project-level source list for river reading, hydrology, flow maps, shader-water references, and production examples, and should update it when new external research informs a pillow decision.
  - Phase 5A/5B flow and SDF steering are accepted baseline.
  - Phase 6A/6B added visual-only pillow response and tuning controls.
  - Phase 6C set default `pillow_forward_reach_tiles` to `0.0` after diagnosing shader-side forward reach.
  - Phase 6D/6E moved into raw classifier changes and current saved river bakes are signature `19`; after the direct-contact-first classifier edit, signature `20` bakes are required for review.
  - Phase 6E specifically halved `RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES` from `0.14` to `0.07` and changed the direct fallback `pillow_contact_search_uv` from `0.02` to `0.01`.
  - Phase 7B eddy-line visual pass is accepted and should be preserved.
- User-reported observations:
  - After Phase 6E, pillows still appear to start too far ahead of actual objects.
  - On 2026-05-31, the user confirmed the raw `Pillow / Impact Mask` and final visible water are about `0.3` to `0.5` ahead of the intended pillow start.
  - The user also reported `Pillow Visual Mask` as undifferentiated green over the whole river. Static shader review shows the current debug gradient maps zero to green, so that view may be visually ambiguous even when the numeric mask is low.
- Agent confidence in the premise:
  - Medium-high that a real placement/formula issue remains, but the precise source term needs diagnosis.
- Possible expected-behavior explanations to rule out before patching:
  - Old shader reach or contact-pull controls still being active.
  - Debug material override or stale material settings.
  - Reading downstream wake/eddy behavior as upstream pillow behavior.
  - Review camera direction making upstream/downstream interpretation confusing.
- Clarification or challenge already raised with the user:
  - The next pass should not be another blind distance reduction. It should first decide which signals may define "pillow start."

## Users and Workflows

### User Story: River Author Reviews Pillow Placement

As a river author, I want to switch between raw and final pillow debug views around rocks, so that I can tell whether the detected pillow starts at the actual impact face.

Acceptance criteria:

- The author can compare `Pillow / Impact Mask` and `Pillow Visual Mask` at the same targets.
- The mask is present on upstream impact/compression faces of hard protrusions.
- The mask is not present as broad open-water blobs far ahead of the object.

### User Story: Add-on Maintainer Diagnoses Formula Sources

As an add-on maintainer, I want diagnostic views or probes that split direct contact, bank response, support/facing, and final contact-gate contribution, so that classifier changes are targeted.

Acceptance criteria:

- A diagnostic pass can show whether the offset originates from support/facing, `terrain_contact_features.b`, `bank_response_features.a`, or the combined gate.
- Any bake-level change records source metadata and bumps the source signature when required.

### User Story: Reviewer Defines Detection Semantics

As the reviewer, I want to mark or describe should-detect and should-not-detect areas, so that Codex can compare raw and final masks against the intended river feature instead of guessing from fixed screenshots.

Acceptance criteria:

- Review notes distinguish upstream impact faces, downstream wakes, ordinary banks, and hard protrusions.
- Codex records when a target is a false positive, false negative, or accepted detection.
- Numeric readings are used as supporting evidence when placement or gate retention is unclear.

### User Story: Material Tuner Polishes Accepted Placement

As a material tuner, I want `pillow_` material controls to affect only an accepted placement mask, so that I can adjust visual intensity without hiding placement errors.

Acceptance criteria:

- Material tuning is deferred until raw/no-reach placement is accepted.
- Default-off height and contact-pull controls remain opt-in review tools.

## Functional Requirements

- Use `obstacle_features.r` as the raw pillow/impact source unless the spec and plan are revised.
- Keep `Pillow / Impact Mask` as the raw channel view.
- Keep `Pillow Visual Mask` as the final shader-gated no-default-reach view.
- Keep `pillow_forward_reach_tiles = 0.0` by default during placement review.
- Preserve `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` as default-off review controls.
- Preserve default-off height behavior. `pillow_terrain_height`, `pillow_obstruction_height`, and related curve controls are visual review accents, while `pillow_height_tile_seam_fade` guards source-tile and mesh-step separation.
- Preserve explicit editor range hints and visible/debug material parity for pillow controls, especially the height curve controls.
- Add a readable final-mask diagnostic, threshold band, or palette adjustment if `Pillow Visual Mask` cannot distinguish zero/near-zero, low, and meaningful pillow values during placement review.
- If the raw mask is wrong, solve the bake/classifier source before material tuning.
- If raw placement is correct but final no-reach mask is wrong, solve shader gates before material tuning.
- If raw and final masks are correct but visible water reads wrong, tune pressure/highlight/normal/band/foam response.
- If classifier code changes alter saved river bake output, update source metadata, source signature, bakes, probes, validation, and docs.
- Follow the detection review order: raw source first, final visual mask second, visible material response last.
- If raw source is correct but final mask is too sparse or broad, prefer shader-only gates or material controls.
- If raw and final masks are correct but visible water is too subtle, prefer pressure/highlight/normal/band tuning before foam.
- If a pillow height artifact appears, treat it as visual/material or mesh-topology work before changing detection.
- Any raw-reading tool should report scene, camera or target, debug mode, parameters, and whether the area is expected or rejected.

## Non-Functional Requirements

- Maintainability: Keep pillow-specific logic separate from wake and eddy-line logic where possible.
- Performance: Avoid expensive runtime sampling. Pillow masks should remain baked or shader-local.
- Visual quality: Pillows should read as upstream pressure/compression, not downstream wake blobs or shoreline foam.
- Godot 4.6+ compatibility: Use active Godot 4.6+ shader/resource/editor APIs only.
- Editor usability: Debug views and `pillow_` controls should be discoverable and should reflect current material values.
- Editor correctness: Debug View Normal must restore visible material behavior, and material revert hooks must not leave stale Phase 6B/6C overrides in place.
- Runtime usability: Runtime-visible water should not depend on hidden editor-only state.
- Extensibility: Future river layouts should be able to use the same pillow signals without demo-scene assumptions.
- Trust/debuggability: A user should be able to explain why a pillow appears or disappears from debug views and source terms.

## Add-on Boundary

Editor authoring responsibilities:

- Debug View menu entries.
- Inspector grouping for `pillow_` controls.
- Review scenes and camera workflows.
- Human-assisted viewport review.
- Optional named-region markers or scripted target samples for expected/rejected areas.

Bake/data responsibilities:

- `obstacle_features.r` raw pillow/impact mask.
- `terrain_contact_features.b` direct protrusion/intersection context.
- `bank_response_features.a` semantic hard-boundary/protrusion response.
- Source metadata, channel stats, bake settings, and source signatures.

Runtime responsibilities:

- Visible shader consumption of accepted pillow mask.
- Runtime-safe material uniforms.
- No dependence on editor-only state.

Shared code must not depend on:

- Legacy Godot 3 APIs.
- One specific demo camera.
- A single rock layout.
- Debug shader state being saved as visible material state.
- WaterSystem bake regeneration for visual-only pillow placement.

## Data and Extension Model

Users should be able to:

- Tune pillow visual strength, pressure, highlight, normals, bands, foam bias, and optional height response.
- Review raw and final pillow masks through debug views.
- Use different river scenes and obstacle layouts without changing code.

Extension points:

- Bake classifier constants and metadata.
- Debug views.
- Material uniforms in visible and debug river shaders.
- Validation probes and export helpers.

Override rules:

- Saved material overrides should not mask current shader defaults during placement review.
- Debug material overrides must return to visible material behavior when Debug View is Normal.
- Bake changes should invalidate stale resources via source-signature changes.

Shared systems must not hard-code:

- Specific demo rocks.
- A specific HTerrain layout as the only supported terrain source.
- A one-off pillow offset that only fixes one camera angle.

## Current Controls and Debug Views

Phase 6A core material controls:

- `pillow_strength`
- `pillow_energy_gate`
- `pillow_flow_gate`
- `pillow_bank_suppression`
- `pillow_pressure_strength`
- `pillow_highlight_strength`
- `pillow_normal_strength`
- `pillow_band_strength`
- `pillow_band_scale`
- `pillow_foam_bias`
- `pillow_forward_reach_tiles`

Phase 6B gate and material-language controls:

- `pillow_confidence_gate_start`
- `pillow_confidence_gate_full`
- `pillow_hard_gate_start`
- `pillow_hard_gate_full`
- `pillow_energy_gate_start`
- `pillow_flow_gate_start`
- `pillow_pressure_color`
- `pillow_highlight_color`
- `pillow_specular_boost`
- `pillow_roughness_reduction`

Default-off review controls:

- `pillow_contact_pull_tiles`
- `pillow_contact_pull_strength`
- `pillow_terrain_height`
- `pillow_terrain_height_curve`
- `pillow_obstruction_height`
- `pillow_obstruction_height_curve`
- `pillow_height_tile_seam_fade`

Pillow debug views:

- `Pillow / Impact Mask`: raw `obstacle_features.r`
- `Pillow Visual Mask`: debug mode `26`; current green-zero gradient can make low/no signal read as full-river green, so use the Black Zero companion for placement acceptance.
- `Pillow Visual Mask (Black Zero)`: debug mode `48`; no-reach final mask with zero/near-zero rendered black.
- `Pillow Direct Terrain Anchor Search`: debug mode `49`
- `Pillow Bank-Response Anchor Search`: debug mode `50`
- `Pillow Combined Contact Gate`: debug mode `51`
- `Pillow Bank-Only Anchor Contribution`: debug mode `52`
- `Pillow Raw-to-Final Retention`: debug mode `53`
- `Pillow Height Influence`: debug mode `27`
- `Terrain Pillow Height Influence`: debug mode `28`
- `Obstruction Pillow Height Influence`: debug mode `29`

## Acceptance Tests

- `Pillow / Impact Mask` starts near upstream rock/protrusion impact faces in `Demo.tscn`.
- `Pillow / Impact Mask` behaves similarly in `Demo_obstacle_flow_test.tscn`.
- Main demo, obstacle-test, overview, rock-garden, main-bend low-oblique, and downstream-rock low-oblique review angles do not contradict each other.
- `Pillow Visual Mask` with default reach/contact-pull settings does not invent a forward start ahead of raw R.
- `Pillow Visual Mask` or its replacement diagnostic is readable enough to distinguish no signal from weak/strong pillow mask values.
- Open water far ahead of rocks remains quiet.
- Downstream wakes and eddy-line margins remain governed by wake/eddy logic, not pillow logic.
- Ordinary smooth banks do not become continuous pillow lines.
- Raw and final masks explain each other. If they diverge, the source of divergence is documented.
- If numeric readings are used, expected-region raw coverage, final-mask retention, ordinary-bank false positives, hard-protrusion support, grade/energy support, and final-flow support are recorded.
- Accepted Phase 7B eddy-line visual behavior remains unchanged unless explicitly scoped.
- Any bake/classifier change passes relevant probes and records new source metadata.

## Visual Validation Requirements

- Use visible Godot editor/runtime review for placement acceptance.
- Compare the same rock/protrusion targets across:
  - `Pillow / Impact Mask`
  - `Pillow Visual Mask`
  - `Pillow Height Influence`
  - `Terrain Pillow Height Influence`
  - `Obstruction Pillow Height Influence`
  - `Obstacle Confidence`
  - `Hard-Boundary / Protrusion Response`
  - `Grade / Energy Channel`
  - `Protrusion / Intersection`
  - `Final Flow Strength`
- Capture or describe upstream/downstream direction for each review target.
- Treat fixed screenshots and exported captures as evidence, not final acceptance.
- If the current palette hides useful low values, add low-range or threshold-band diagnostic views before changing thresholds.

## Performance Requirements

- No new runtime texture readback for normal visible rendering.
- Bake/classifier passes should remain offline/editor bake work.
- Shader sampling added for diagnostics should be debug-only or clearly justified.
- WaterSystem regeneration is not part of visual-only pillow placement review.

## Open Questions

- Should pillow contact use only direct `terrain_contact_features.b` protrusion/contact?
- Should `bank_response_features.a` be allowed to anchor pillows at all?
- Should broad dilated support be replaced or tightened for pillow-specific placement?
- What minimum diagnostic split should be added: support/facing, direct terrain anchor, bank-response anchor, combined contact gate, bank-only contribution, or all of them?
- Should `Pillow Visual Mask` keep the current debug gradient, gain a black-zero/threshold companion, or be replaced by a clearer review mode?
- Which exact rocks/protrusions are the user treating as must-detect and must-not-detect review targets?
- Are raw readings or named-region stats needed for the user-identified target areas?
- What second-layout or synthetic check is enough before accepting a formula change as reusable add-on behavior?

## Resolved Questions

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Should the old default shader forward reach remain enabled? | No. `pillow_forward_reach_tiles` defaults to `0.0`. | 2026-05-26 | Phase 6C found it caused a visible forward offset. |
| Is Phase 5 flow the baseline for pillow review? | Yes. Phase 5A/5B is accepted by the user. | 2026-05-26 | Do not reopen unless a new visible regression appears. |
| Should Phase 7B eddy-line behavior be preserved? | Yes. The raw-G wake-edge direction was accepted. | 2026-05-26 | Preserve unless explicitly scoped. |
| Is another scalar distance reduction the next step? | No. Do formula review and diagnostics first. | 2026-05-31 | Phase 6F found effective reach comes from more than the explicit `0.07` search. |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-05-26 | Add visual-only pillow highlights using raw `obstacle_features.r`. | Start from accepted Phase 5 flow and avoid bake/physics changes. |
| 2026-05-26 | Add `pillow_` material controls and `Pillow Visual Mask`. | Make review and tuning inspectable. |
| 2026-05-26 | Default `pillow_forward_reach_tiles` to `0.0`. | Earlier forward reach moved pillows too far ahead. |
| 2026-05-26 | Keep pillow height/contact-pull controls as default-off review tools. | Height, contact pull, and seam fade help review material shape but must not hide placement errors. |
| 2026-05-26 | Move from shader-only tuning to raw classifier review. | User found raw `Pillow / Impact Mask` was still too far ahead. |
| 2026-05-26 | Bump to source signature `19` after halving contact-search distance. | River bakes changed for pillow classifier tuning. |
| 2026-05-31 | Create this feature-local spec folder. | Keep pillow work from being scattered across general changelog and handoff files. |
| 2026-05-31 | Promote audit-guided diagnostic split before classifier edits. | `pillow-system-audit.md` found about `35%` bank-response-only anchoring and recommends direct-contact-first anchoring if confirmed. |
| 2026-06-01 | Make raw pillow R direct-contact-first. | User diagnostic review found direct terrain anchor search closest to desired placement and bank-response/combined contact gates too broad. |
