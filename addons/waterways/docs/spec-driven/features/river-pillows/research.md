# Research: River Pillows

## Purpose

Consolidate the pillow-related findings from the shared changelog and latest handoff into a feature-local research record. This document should help decide the next safe change for Waterways pillow placement without rediscovering Phase 6A through 6F history.

## Current Research Outcome

This is the research dashboard. Keep the recommended direction here and use the lower sections for evidence, options, cited sources, and rejected paths.

- Status: Complete enough for formula review; roadmap details folded in
- Recommendation: Rebake main and obstacle-test rivers to signature `20` and review the direct-contact-first classifier before making further support/facing changes. For the separate height issue, treat the two named missing-height targets as confirmed height seam fade suppression and review the default-off height seam guard plus `pillow_height_smoothing_tiles = 0.10` and `pillow_height_seam_stitch_tiles = 0.015` at the supported `8/8` cap before changing classifier logic.
- Confidence: Medium-high that the remaining forward offset is a baked raw-mask/formula issue, not default visible shader reach.
- Biggest unknown that remains: For placement, which signal should be allowed to anchor the upstream start of a pillow: direct terrain/world protrusion, semantic bank response, dilated collision support, or some overlap of those. For height, whether the current `0.0` seam guard plus smoothed/stitched height mask is enough at `8/8`, or whether additional topology/mask work is needed.
- Decision or plan section this research unlocked: `plan.md` "Next Implementation Slice" and `tasks.md` "Open Work".

## Questions

- What visual feature should count as the start of a pillow?
- Is the reported forward offset present in raw `Pillow / Impact Mask`, no-reach `Pillow Visual Mask`, or only final visible material response?
  - Current user answer: raw `Pillow / Impact Mask` and final visible water both start about `0.3` to `0.5` too far ahead. The original `Pillow Visual Mask` is unreadable because it appears undifferentiated green; `Pillow Visual Mask (Black Zero)` is now available for review.
- Is `bank_response_features.a` too broad or too forward-looking to anchor pillow starts?
  - Current answer: Yes for pillow anchoring. User review found bank-response anchor, combined contact gate, and bank-only contribution too broad, while direct terrain anchor search was much closer to intended placement.
- Is the generic dilated collision support field too broad for pillow-specific placement?
- Should pillow anchoring use direct `terrain_contact_features.b` protrusion/contact first, with semantic bank response only as context?
  - Current answer: Yes for the next implementation slice.
- Which diagnostic split views/probe outputs are the smallest useful set for the next review?
- Does `pillow_height_tile_seam_fade` suppress valid obstruction pillow height at the two named problem spots?
  - Current answer: Yes. User set `pillow_height_tile_seam_fade = 0.0`, and those spots began lifting again. The remaining issue is angular/janky displacement quality.

## Flow-Map and Water Tool Patterns

The current Waterways direction treats pillows as upstream compression/highlight behavior near rocks and hard protrusions, not as downstream wakes or eddy-line turbulence.

Useful principles preserved from the earlier research and review:

- Pillows should sit at upstream impact/compression faces of rocks and hard protrusions.
- Pillow placement should be judged before material polish.
- Foam is secondary; compression, pressure, highlights, normals, and subtle bands carry the first readable pillow cue.
- A raw mask and a final visual mask should be compared before deciding whether the problem is bake data, shader gating, or material response.
- Demo-scene overfitting is a risk. Any formula should generalize beyond `Demo.tscn`.
- Detection review is a collaborative workflow: Codex can propose probes and small changes, but the user confirms feature meaning in the visible Godot editor/runtime viewport.
- Exported screenshots and fixed-camera captures are supporting evidence, not final acceptance.

## Roadmap Research Findings

- River-reading sources describe pillows as upstream mounds where current presses into a rock, boulder, wall, or cliff face before deflecting around it.
- River-dynamics and boulder-flow research support gating pillows with submergence/contact, hard protrusion context, grade/energy, and effective flow strength. Ordinary shallow banks should not automatically become pillows.
- Flow-map production references support the existing Waterways strategy: keep low-resolution vector and feature fields inspectable, then use shader-time normal detail, noise, phase offsets, and material response to sell local motion.
- Unreal/Riverology-style obstacle foam systems commonly use distance-field-like obstacle context, but Waterways should use its existing saved `obstacle_features`, `terrain_contact_features`, and `bank_response_features` maps before adding screen-only or engine-specific dependencies.
- Foam should remain a high-energy accent. Broad foam blurs the boundary between upstream pillows, shoreline foam, downstream wakes, and eddy lines.
- Existing Waterways channels already separate upstream impact from downstream features: `obstacle_features.r` is pillow/impact, while `.g` and `.b` support wake and eddy-line review. The current pillow pass should preserve that anatomy.
- Vertex displacement remains higher risk than pressure/highlight/normal/band tuning because it can expose mesh density, depth/refraction, seam, and buoyancy mismatch issues.
- The Phase 6B height experiment is default-off review behavior, not a placement fix. Its terrain and obstruction lifts are split, guarded by `pillow_height_tile_seam_fade`, and should stay subtle unless mesh density/topology work is deliberately scoped. The historical review capture used terrain/obstruction strengths `0.16`, curves `1.20`, and seam fade `0.035` while leaving saved/default river behavior off.
- The 2026-06-03 height follow-up confirmed that `pillow_height_tile_seam_fade` can suppress valid obstruction height when the debug influence appears as one logical pillow blob split by black bands. Setting it to `0.0` restored lift at the two named targets, but exposed janky/angular vertex displacement.
- Phase 6C editor wiring matters for future reviews: explicit shader range hints keep `pillow_terrain_height_curve` and `pillow_obstruction_height_curve` from being treated as generic easing controls, visible/debug material parameters must stay synced, and material revert hooks must restore current defaults.

## Audit Findings

`docs/audit/pillow-system-audit.md` raises the severity of the placement issue:

- Current shader-side reach and contact pull defaults are off, so material reach is not the likely current cause.
- The anchor audit reports about `35.17%` of main-river and `35.88%` of obstacle-test raw pillow pixels above `0.05` are strongly `bank_response.a` anchored while direct `terrain_contact.b` is weak or absent.
- Over half of raw pillow pixels have `bank_response.a` meaningfully higher than direct `terrain_contact.b`.
- The next pass should add diagnostic split views/probe output before the classifier is changed.
- The current `Pillow Visual Mask` view is not reliable for review because the user sees undifferentiated green over the river, and static shader review shows the current grayscale gradient maps zero to green.
- If confirmed in live review, raw R should move toward direct-contact-first anchoring, with `bank_response.a` used as context only.
- 2026-06-01 live review confirmed this direction; the classifier now requires direct `terrain_contact_features.b` search for pillow contact and uses `bank_response.a` only as weak context.

## Channel Phase Alignment Lesson

The accepted Phase 7B eddy-line fix is the model for remaining pillow placement review:

- A plausible source channel can be semantically correct but spatially wrong for the visible feature.
- Bigger sampling or stronger material response is not enough when the source channel is in the wrong phase.
- Candidate channels should be compared by physical placement first: distance from the source rock, upstream/downstream side, paired margins versus filled blobs, and ordinary-bank behavior.
- Old plausible-but-misplaced channels should remain diagnostic until the replacement is proven.
- For pillows, compare raw R, final `Pillow Visual Mask` or a clearer threshold/black-zero diagnostic, support/facing, direct contact, bank response, confidence, reach/contact-pull, grade/energy, and final-flow context against the actual upstream impact face before tuning visual strength.

## Godot 4.6+ Findings

- Active target is Godot 4.6+.
- Visual/editor/shader behavior needs human-visible editor or runtime validation.
- Local probes are useful for parser, metadata, saved-resource, and image/readback checks, but they are not proof of visible editor behavior.
- Current validation uses repo-local Godot user data folders for scripted probes.
- Current bakes relevant to pillows are signature version `19`.
- Phase 6E's literal classifier-distance change was `RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES` from `0.14` to `0.07`, with the direct filter fallback `pillow_contact_search_uv` changed from `0.02` to `0.01`; this still does not describe the full effective anchor reach.
- Historical coverage anchors from the roadmap/changelog are useful for comparison, not acceptance: Phase 6A main raw R above `0.05` was about `8.08%`, gated visual was about `3.17%`; Phase 6B gated visual rose to about `3.88%`; Phase 6D raw R dropped to about `5.12%` main and `5.06%` obstacle-test; Phase 6E raw R dropped to about `4.70%` main and `4.61%` obstacle-test, with no-reach visual mask about `2.32%` main and `2.26%` obstacle-test.
- The saved WaterSystem bake was not regenerated after Phase 6D/6E pillow-only bake changes and should remain untouched unless physics/system flow changes are explicitly scoped.

## Legacy Waterways Reference

- Relevant legacy files: None identified for the active pillow placement question.
- Behavior to preserve: Not applicable unless a later review explicitly compares Godot 3 behavior.
- Behavior to change: Active Waterways should use Godot 4.6+ shader/resource/editor APIs only.
- Obsolete APIs to avoid: Any Godot 3 editor, shader, resource, or physics APIs.
- What belongs in active Godot 4.6+ code: Inspector controls, bake metadata, debug views, classifier shaders, validation probes, and saved bakes for the current add-on.
- What should remain legacy-only: Historical behavior that does not match the Godot 4.6+ architecture.

## Options

### Option A: Direct Contact Anchor

- Benefits: Keeps pillow starts close to actual terrain/world protrusion or intersection contact.
- Costs: May miss useful semantic context where the visible obstacle is represented indirectly.
- Risks: Could make pillows too sparse if `terrain_contact_features.b` misses an obstruction.
- Fit for Waterways: Audit-preferred formula direction if live review confirms bank-response anchoring is causing the offset.

### Option B: Weighted or Overlap-Gated Bank Response

- Benefits: Preserves useful `bank_response_features.a` context while reducing forward halo influence.
- Costs: More tuning and more edge cases.
- Risks: Still allows semantic context to start pillows ahead of visible objects if overlap rules are too loose.
- Fit for Waterways: Plausible if direct contact alone is too strict.

### Option C: Pillow-Specific Support Field

- Benefits: Reduces dependence on the generic `baking_dilate = 0.6` collision support field.
- Costs: Requires bake/classifier work and likely source-signature bump.
- Risks: Could regress accepted wake/eddy behavior if shared inputs are changed carelessly.
- Fit for Waterways: Useful only if the diagnostic split proves broad support is a primary cause.

### Option D: Diagnostic Split First

- Benefits: Answers which signal creates the offset before another formula edit.
- Costs: Adds temporary or debug-only views/probes.
- Risks: Slight debug-view complexity if too many channels are added at once.
- Fit for Waterways: Best immediate next move.

### Option E: Raw Readings and Named Regions

- Benefits: Lets Codex compare expected and rejected areas numerically instead of relying on screenshots alone.
- Costs: Requires region definitions, probe/export updates, or temporary markers.
- Risks: Metrics can distract from visible review if treated as acceptance by themselves.
- Fit for Waterways: Useful once the user identifies specific should-detect and should-not-detect targets.

## Recommendation

Add or use diagnostics to compare these contributions at the same rocks/protrusions before changing the classifier again:

- pillow support/facing
- direct `terrain_contact_features.b`
- semantic `bank_response_features.a`
- final pillow contact-gate contribution
- raw `obstacle_features.r`
- no-reach `Pillow Visual Mask`

The diagnostic split and live review moved the formula to direct-contact anchoring. The direct-contact-first output is closer/better in some diagnostics, and the later material-seam review found that nonzero material seam fade was itself drawing visible straight bars. Keep `pillow_material_tile_seam_fade` default/current `0.0` unless a seam-specific review intentionally enables it.

The live review should treat final-mask readability as a tooling problem before it treats green coverage as real coverage. Use the Black Zero mode and compare it against raw R, direct terrain anchor search, bank-response anchor search, combined contact gate, bank-only anchor contribution, raw-to-final retention, `Pillow Material Response Mask`, `Pillow Height Influence`, terrain/obstruction height influence views, and final visible water. Use `Pillow Material Seam Guard` only if visible seam bands return.

The 2026-06-03 height follow-up answered the missing-height part of that question: setting `pillow_height_tile_seam_fade = 0.0` makes the leading `"rock low"` target for `cliff8` and the `"smooth rock"` cluster target raise. Treat the remaining problem as height seam guard policy plus vertex-displacement quality. Because shape divisions are capped at `8/8`, review the new `pillow_height_smoothing_tiles = 0.10`, `pillow_height_seam_stitch_tiles = 0.015`, and gentler height curves at that cap before changing classifier logic. A cap lift above `8/8` is diagnostic-only unless the supported range is deliberately changed.

For a numeric follow-up, prefer readings that report expected-region raw coverage, final-mask coverage, raw-to-final retention, ordinary-bank false-positive coverage, hard-protrusion support, grade/energy support, final-flow support, and the top gates suppressing expected pixels.

## Risks and Unknowns

- `pillow_contact_search_tiles = 0.07` is not the full effective anchor reach because `pillow_contact_gate_at()` samples up to `1.5 * pillow_contact_search_uv`.
- `hard_boundary_at()` uses `max(bank_response.a, terrain_contact.b)`.
- `bank_response.a` already includes forward-looking protrusion sampling using `RIVER_BANK_RESPONSE_PROBE_TILES = 0.20`.
- `pillow_source_at()` uses generic dilated collision support built from `baking_dilate = 0.6`.
- Reducing a single distance constant again may not address the true cause.
- Any bake/classifier pass must preserve accepted Phase 7B eddy-line behavior.
- Height, contact-pull, and material-response controls can change the visible read without fixing raw placement. Keep them default-off or review-only until raw/no-reach placement is accepted, and keep `pillow_material_tile_seam_fade` at `0.0` unless actively testing a returned seam.
- `pillow_height_tile_seam_fade` is separate from material seam fade and can remove valid vertex displacement through the middle of one detected pillow. Disabling it can reveal whether height data exists, but may also expose low mesh density or narrow-mask faceting.

## Context Challenge Notes

- Possible misread context: The visible shader might be blamed for the offset even though default reach and contact-pull controls are off.
- Evidence: Phase 6C found shader forward reach caused one earlier offset and set `pillow_forward_reach_tiles = 0.0`; later Phase 6F review found the remaining start mostly reveals baked raw `obstacle_features.r`.
- Confidence: Medium-high.
- Quick check before patching: Compare `Pillow / Impact Mask`, `Pillow Visual Mask`, `Hard-Boundary / Protrusion Response`, `Protrusion / Intersection`, and `Final Flow Strength` at the same target rocks in the visible editor.
- User-facing note or question to raise: "The remaining offset appears in raw `Pillow / Impact Mask`, so the classifier is the likely failing layer. Before changing constants, let's add source-term diagnostics and a clearer final-mask view so we can see whether support/facing, direct contact, or bank response is responsible."

## Sources

- `addons/waterways/docs/history/CHANGELOG.md`
- `addons/waterways/docs/handoffs/handoff-latest.md`
- `addons/waterways/docs/roadmaps/river-feature-detection-roadmap.md`
- `addons/waterways/docs/roadmaps/river-improvements-roadmap.md`
- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index for Waterways river behavior, hydrology, flow-map, shader-water, and production-reference sources. Future Codex sessions should consult it before research-driven feature decisions and update it when new external sources are used.
