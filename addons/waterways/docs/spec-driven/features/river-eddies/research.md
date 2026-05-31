# Research: River Eddies

## Purpose

Consolidate the wake, eddy-line, and eddy-related findings from the shared changelog, latest handoff, and river roadmaps into a feature-local research record. There is no eddy audit document to fold in. This document preserves the accepted Phase 7B visual baseline and keeps later reverse/circulating flow work clearly separated from the current material preview.

## Current Research Outcome

- Status: Complete for Phase 7B visual baseline; deferred for Phase 7C/7D flow design
- Recommendation: Treat the accepted Phase 7B visual wake/eddy-line material preview as the current baseline. Do not reopen source flow, final flow, reverse flow, WaterSystem generation, or saved WaterSystem bakes unless Phase 7C/7D is explicitly scoped.
- Confidence: High that the current visual eddy-line placement baseline is user-accepted; medium that the existing scalar masks are enough for future surface-only tuning; low that they are enough for real reverse/circulating flow without new vector data or an analytic flow model.
- Biggest unknown that remains: The data model for true eddy circulation: eddy center, spin side, radius, strength, local velocity offset, and how that should be mirrored between visible, debug, system-flow, WaterSystem bake, and runtime validation.
- Decision or plan section this research unlocked: `plan.md` "Phase Boundaries" and `tasks.md` "Open Work".

## Questions

- What should count as an accepted eddy-line visual: paired wake margins, wake body, hard protrusion shoulder, or actual reverse-flow boundary?
- When a mask looks wrong, is the failure in the raw source channel, the final visual mask, or the visible material response?
- Which existing diagnostics should remain preserved so future sessions can compare raw B against the accepted raw-G wake-edge candidate?
- What exact scope must be included before Phase 7C changes reverse/circulating flow?
- What human-assisted editor/runtime validation is needed before an eddy-flow change is accepted?
- What additional eddy vector data or analytic model would be needed to move beyond a scalar visual mask?

## Flow-Map and Water Tool Patterns

The useful Phase 7 research pattern is staged and inspectable:

- First inspect low-resolution saved vector and feature fields.
- Then build review-only or debug-only derived masks.
- Then add surface-only material cues from accepted masks.
- Only after placement and behavior are trusted, promote final-flow changes into physics-facing WaterSystem maps.

Practical river-reading and water-rendering references point to separate concepts:

- Wake: downstream disturbed or slower region behind an obstruction.
- Eddy line: narrow shear boundary between main current and wake or slower/reverse water.
- Eddy core: later flow feature that may slow, neutralize, or reverse local velocity.

Waterways currently supports the first two visually. It does not yet encode an eddy core, spin side, velocity offset, or stable reverse-flow vector.

## Roadmap Research Findings

- Eddies should not be represented as one undifferentiated blob. The current split between `obstacle_features.g` wake seed and eddy-line/shear candidates is directionally useful.
- Phase 7B can remain visual-only because production water systems often separate scalar surface-detail layers from velocity/physics layers.
- Actual reverse/circulating flow must be shared by visible river, debug river, system-flow shader, generated WaterSystem bake, and runtime validation.
- Eddy-line foam is risky: if it follows broad banks, it reads like shoreline foam. Phase 7B therefore favors normal detail, roughness/specular breakup, albedo breakup, small noisy flecks, and narrow turbulence over broad white foam.
- Wake reach and edge sampling must stay in source-tile units and be reviewed across accepted cameras because oversized influence radii can smear across UV2 tiles, bends, or ordinary banks.
- Scalar wake/eddy masks do not encode spin side or reverse velocity. Do not infer physics from `obstacle_features.g` or `.b` alone.

## Phase 7 Evidence Summary

### Phase 7A0 Research and Review

- Phase 7 began as research/planning only.
- Current surfaces reviewed: `obstacle_features.g` wake / eddy seed, `obstacle_features.b` eddy-line / shear, `obstacle_features.a` confidence, Phase 4B captures, visible/debug shaders, obstacle classifier, WaterSystem flow renderer, bake metadata, and existing export helpers.
- Early stats showed raw wake was plausible for a gated visual preview, while the old eddy-line/shear channel was too broad for direct foam, turbulence, gameplay, reverse-flow, or WaterSystem use.
- No shader, bake, source signature, final flow, WaterSystem flow, or saved WaterSystem bake changed.

### Phase 7A1 Preflight

- Review-only helpers produced `gated_wake`, `gated_eddy_line`, and `wake_edge_thinned_eddy_line` candidates from existing bakes.
- Main demo stats from that pass: raw wake above `0.05` about `18.54%`, gated wake about `7.19%`, raw eddy-line about `20.60%`, gated eddy-line about `8.30%`, and wake-edge-thinned eddy-line about `4.31%`.
- Result: gated wake was localized enough for a cautious visual preview, but eddy-line/shear needed a classifier refinement before visible eddy-line material work.
- This remained review-only: no visible shader behavior, bake resources, source signatures, final flow, WaterSystem flow shader, saved WaterSystem bake, terrain-contact thresholds, bank-response thresholds, or classifier code changed.

### Phase 7A2 Classifier Refinement

- `obstacle_features.b` was narrowed using thresholded wake edges, hard-boundary/protrusion context from `bank_response_features.a` plus `terrain_contact_features.b`, grade/energy gating, source-support rejection, and narrower confidence.
- The river bake source signature was bumped to `17`; main and obstacle-test river resources were rebaked.
- Raw wake `obstacle_features.g` stayed effectively unchanged.
- Main demo image-space stats after the pass: raw wake above `0.05` remained about `18.54%`; raw eddy-line above `0.05` was about `2.42%`; gated eddy-line about `1.06%`; wake-edge-thinned eddy-line about `0.99%`.
- No final-flow, visible river shader, WaterSystem flow shader, saved WaterSystem bake, terrain-contact threshold, or bank-response threshold changes were made.

### Phase 7B Visual Preview

- Phase 7B added the `wake_` material-control category, visible/debug shader helpers, and debug modes for `Wake Visual Mask`, `Eddy-Line Visual Mask`, and `Wake Edge Thinness`.
- Surface-only cues include downstream wake breakup, subtle wake/eddy normal and roughness changes, albedo/specular breakup, small noisy foam flecks, and narrow eddy-line turbulence.
- The initial raw-B exact-gate `Eddy-Line Visual Mask` appeared empty/green away from the river start.
- Larger `wake_edge_sample_tiles` alone was rejected. It made `Wake Edge Thinness` busier but did not create the accepted two trailing wake margins.
- Gate-component and alternate-channel diagnostics showed the important issue was channel/phase alignment: raw B was plausible but too far from the close-behind-rock shoulders, while raw G carried the accepted paired wake-edge pattern.
- The accepted baseline now derives `Eddy-Line Visual Mask` from a raw-G wake-edge candidate plus nearby wake/hard-protrusion context at `wake_edge_sample_tiles = 0.024`.
- Old raw-B paths remain diagnostic through `Eddy-Line / Shear Mask`, `Gated Eddy-Line Source (B * Wake Gate)`, `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, and `Eddy-Line Wake Context Search`.
- User review accepted the visible result after the material-override fix and stronger defaults.

## Channel Phase Alignment Lesson

The accepted Phase 7B fix was not primarily a brightness fix. It was a source-channel placement fix.

- Raw B was semantically plausible but spatially wrong for the accepted visual feature.
- The old exact-pixel wake gate and raw B did not line up with close-behind-rock wake shoulders.
- Larger edge sampling alone did not solve the issue.
- Raw G, interpreted as a wake-edge candidate, produced the accepted paired margins behind rocks with a quieter middle.
- Old plausible-but-misplaced channels should remain available as diagnostics rather than being deleted immediately.

Use this lesson for future eddy, wake, and pillow work: compare physical placement and pattern anatomy before tuning strength.

## Godot 4.6+ Findings

- Active target is Godot 4.6+.
- Human-visible editor/runtime review is required for visual acceptance.
- Local probes can confirm shader wiring, metadata, and exports, but they are not proof of visible editor behavior or runtime feel.
- Current validation uses repo-local Godot user data folders for scripted probes.
- Current river bakes are signature version `19` after later pillow classifier changes; Phase 7B accepted behavior must be preserved on that current data.
- The saved WaterSystem bake was last regenerated after Phase 5B/signature `16`. Phase 7B did not regenerate it and must not require regeneration.

## Legacy Waterways Reference

- Relevant legacy files: None identified for the current Phase 7B baseline.
- Behavior to preserve: Active Godot 4.6+ add-on behavior and accepted user-reviewed visual result.
- Behavior to change: Not applicable until Phase 7C/7D is scoped.
- Obsolete APIs to avoid: Godot 3 editor, shader, resource, and physics APIs.
- What belongs in active Godot 4.6+ code: Visible/debug shader masks, material controls, debug menu entries, validation probes, saved bakes, and future WaterSystem-compatible flow generation.
- What should remain legacy-only: Any behavior that cannot be expressed in the current Godot 4.6+ add-on architecture.

## Options

### Option A: Preserve Phase 7B Visual Baseline

- Benefits: Keeps accepted user-visible behavior stable and avoids accidental physics mismatch.
- Costs: Does not add true reverse/circulating water.
- Risks: Future edits may accidentally reinterpret the visual mask as physics.
- Fit for Waterways: Current recommendation.

### Option B: Shader-Only Visual Tuning

- Benefits: Safe when raw/final masks are accepted but visible response is too subtle or too strong.
- Costs: Can hide placement problems if done too early.
- Risks: Material cues can imply reverse motion while buoyancy remains downstream.
- Fit for Waterways: Allowed only after raw/final mask placement is verified.

### Option C: Bake-Level Wake or Eddy-Line Refinement

- Benefits: Fixes raw source placement when a candidate channel is physically wrong.
- Costs: Requires source-signature bump, rebakes, metadata, probes, and captures.
- Risks: Could disturb accepted pillow or eddy-line behavior if shared classifier inputs change.
- Fit for Waterways: Only when raw source masks are proven wrong.

### Option D: New Eddy Vector Data

- Benefits: Can encode eddy center, spin side, strength, radius, and local velocity.
- Costs: Requires `RiverBakeData` layout changes, material/debug/system-flow wiring, source metadata, source-signature bump, rebakes, and runtime validation.
- Risks: Larger blast radius and harder visual/physics parity.
- Fit for Waterways: Leading direction for Phase 7C if actual reverse/circulating flow is scoped.

### Option E: Analytic Eddy Vector Field

- Benefits: May avoid adding a new texture at first.
- Costs: Must be mirrored exactly between visible, debug, and system-flow shaders.
- Risks: Easy to produce visual/physics mismatch or unstable spin direction.
- Fit for Waterways: Review-only until parity and validation are proven.

## Recommendation

Keep Phase 7B as the accepted visual-only baseline:

- `Eddy-Line Visual Mask` uses the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- The old raw-B path stays available for diagnostics.
- Raw source masks, final visual masks, and visible material response remain separate review layers.
- Future visual tuning should follow raw source first, final mask second, visible water last.
- Phase 7C must be planned as a separate final-flow milestone, not as a small material tweak.

## Risks and Unknowns

- Scalar masks do not encode stable reverse-flow vectors.
- Visible eddy-line turbulence can imply physics that does not exist yet.
- Start-of-river hotspots are known false-positive candidates and should not drive acceptance.
- Ordinary-bank streaks can reappear if hard-boundary/protrusion gates are loosened.
- Future pillow classifier work touches shared obstacle-feature data and must preserve accepted Phase 7B behavior.
- Phase 7C could desynchronize visible water and buoyancy unless visible, debug, system-flow, WaterSystem generation, and runtime validation are updated together.

## Context Challenge Notes

- Possible misread context: A user or agent may treat Phase 7B eddy-line visuals as actual reverse/circulating flow.
- Evidence: Phase 7B explicitly did not redirect `flow`, alter `flow_force`, change final flow, wire obstacle features into `system_flow.gdshader`, or regenerate the saved WaterSystem bake.
- Confidence: High.
- Quick check before patching: Ask whether the requested change is visual material response, final-flow direction, or WaterSystem/physics behavior. If it is flow/physics, require a Phase 7C/7D plan first.
- User-facing note or question to raise: "The accepted eddy-line pass is visual-only. If we want real reverse/circulating current, that needs to update visible flow, debug flow, WaterSystem generation, and runtime validation together."

## Sources

- `addons/waterways/docs/history/CHANGELOG.md`
- `addons/waterways/docs/handoffs/handoff-latest.md`
- `addons/waterways/docs/roadmaps/river-feature-detection-roadmap.md`
- `addons/waterways/docs/roadmaps/river-improvements-roadmap.md`
- `addons/waterways/docs/research/river-research-citations.md`
