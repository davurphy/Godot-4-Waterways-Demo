# Pillow System Audit

Date: 2026-05-30

## Scope

This audit reviews the current Waterways pillow system for three goals:

- Better approximation of water pillowing around rocks, boulders, cliff walls, and hard protrusions.
- Maintainable code and debug tooling.
- Performance-appropriate rendering for games.

The audit covers the current signature-19 pillow baseline, the visible/debug shaders, the bake-time feature classifier, existing roadmap notes, validation probes, and the current exported pillow diagnostics.

## Executive Summary

The remaining "pillow starts too far ahead of the rock" issue is primarily a bake/formula issue, not a visible-material reach issue.

Current defaults keep shader-side forward reach and contact pull disabled:

- `pillow_forward_reach_tiles = 0.0`
- `pillow_contact_pull_tiles = 0.0`
- `pillow_contact_pull_strength = 0.0`

With those defaults, `Pillow Visual Mask` mostly reveals baked `obstacle_features.r` through material gates. If the start appears ahead of the source rock in the no-reach view, material brightness, foam, height, and normal tuning are the wrong layer to adjust.

The strongest current placement risk is that the raw pillow contact gate treats broad semantic hard-boundary context as literal pillow contact:

- `hard_boundary_at()` in `obstacle_feature_mask_filter.gdshader` uses `max(bank_response.a, terrain_contact.b)`.
- `bank_response.a` is generated from hard/protrusion response and forward protrusion sampling.
- `pillow_contact_gate_at()` samples this combined hard-boundary value at the current pixel and ahead along flow.

As a result, a candidate pixel can be contact-gated by a downstream semantic protrusion halo even when direct terrain/object protrusion is weak or absent at the candidate location.

## Hydrology Target

A pillow should read as upstream water piling or mounding against the impact face of a solid obstruction. It should appear on or very near the upstream face of a rock, boulder, cliff wall, or hard protrusion.

It should not read as:

- Open water far ahead of an obstruction.
- Downstream wake or eddy-line behavior.
- A broad strip along smooth ordinary banks.
- A filled wake center behind the obstacle.

Practical river-reading references support this interpretation: pillows are upstream pile-up/mound features caused by current pressing into an obstruction, while wakes and eddies belong downstream.

## Current Data Flow

Bake-time path:

1. River collision/support is dilated using `baking_dilate = 0.6`.
2. The dilated support texture is converted into an obstacle normal map.
3. `bank_response_feature_mask_filter.gdshader` creates `bank_response_features`, including:
   - `r`: bank friction/drag response.
   - `g`: outside-bend wet pressure candidate.
   - `b`: inside-bend deposition candidate.
   - `a`: hard-boundary/protrusion response candidate.
4. `obstacle_feature_mask_filter.gdshader` creates `obstacle_features`, including:
   - `r`: pillow/impact mask.
   - `g`: downstream wake seed.
   - `b`: eddy-line/shear mask.
   - `a`: side-deflection/obstacle confidence.

Visible/debug shader path:

1. `river.gdshader` samples `obstacle_features.r`.
2. It gates raw pillow by confidence, hard-boundary context, ordinary-bank suppression, grade/energy, flow force, and `pillow_strength`.
3. Optional shader-side reach and contact pull are available but currently default-off.
4. The resulting pillow mask drives pressure/highlight color, specular/roughness response, normal strength, bands, subtle foam bias, and optional default-off height influence.

## Current Raw Pillow Formula

Current raw pillow logic in `obstacle_feature_mask_filter.gdshader`:

```glsl
raw pillow = max(pillow_source * pillow_contact_gate, pulled_contact_source)
```

Where:

- `pillow_source` = pillow-specific support * flow-facing obstacle normal squared * ordinary-bank/context suppression.
- `pillow_contact_gate` = smooth gate over hard-boundary context sampled at current pixel and downstream offsets.
- `hard_boundary_at` = `max(bank_response.a, terrain_contact.b)`.
- `pulled_contact_source` samples source upstream/back from a current contact anchor.

This was a reasonable attempt to pull pillows closer to contacts, but it still allows `bank_response.a` to behave like direct contact.

## Evidence From Diagnostics

Existing Phase 6C/6E pillow diagnostic:

- Main bake raw R above `0.05`: about `4.70%`.
- Obstacle-test raw R above `0.05`: about `4.61%`.
- Main no-reach visual mask above `0.05`: about `2.32%`.
- Obstacle-test no-reach visual mask above `0.05`: about `2.26%`.

The diagnostic confirms that the visible no-reach mask is smaller than raw R, but it still follows raw placement. It does not create the current forward start by itself.

Additional anchor-split audit from `.codex-research/pillow_formula_anchor_audit.gd`:

- Main river: about `35.17%` of raw pillow pixels above `0.05` are strongly bank-response anchored while direct terrain protrusion is weak or absent.
- Obstacle-test river: about `35.88%` show the same behavior.
- Over half of raw pillow pixels have `bank_response.a` meaningfully higher than direct `terrain_contact.b`.

That is strong evidence that broad semantic hard-boundary response is defining too much of the pillow anchor.

## Primary Findings

### 1. Pillow Contact Is Too Semantic

Severity: high.

`bank_response.a` is useful as hard-boundary/protrusion context, but it is too broad to define literal pillow start by itself. It includes forward-looking protrusion response and is reused by multiple systems. That is good for wake, eddy, bank, and flow-slide context, but risky for the upstream impact face of a pillow.

Recommendation:

- Make the pillow contact anchor direct-contact first.
- Use `terrain_contact.b`, or a very tight local search over `terrain_contact.b`, as the primary pillow anchor.
- Use `bank_response.a` only as a weak context multiplier for pillows, not as a standalone anchor.

### 2. Support Field Can Start Before Visible Contact

Severity: high.

`pillow_source_at()` uses the dilated collision support generated from `baking_dilate = 0.6`. This means support and obstacle normals can be alive before the visible rock/contact boundary the user is judging in the viewport.

Recommendation:

- Consider a tighter pillow-specific support field or higher pillow support thresholds.
- Do not globally reduce `baking_dilate` unless the impact on flow, foam, pressure, wakes, and obstacle avoidance is reviewed.
- Prefer a pillow-only support tightening over changing shared support generation.

### 3. Distance Constants Understate Effective Reach

Severity: medium-high.

`RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES = 0.07` sounds small, but it samples up to `1.5x` of that value. Each sample can accept `bank_response.a`, and `bank_response.a` itself uses `RIVER_BANK_RESPONSE_PROBE_TILES = 0.20` with forward protrusion sampling.

Recommendation:

- Stop treating the `0.07` contact search as the full effective reach.
- If tuning continues, report effective chain reach in documentation and diagnostics.
- Prefer formula separation over another blind scalar reduction.

### 4. Visible And Debug Shaders Duplicate Important Logic

Severity: medium.

`river.gdshader` and `river_debug.gdshader` duplicate much of the pillow, wake, eddy, and flow-gate helper logic. This creates drift risk: the debug view can accidentally stop matching the visible shader.

Recommendation:

- Move shared helper functions into one or more `.gdshaderinc` files once the next pillow formula is agreed.
- Keep debug-only mode selection in `river_debug.gdshader`, but share mask/gate math.
- Add a small parity probe that checks visible/debug include usage or selected helper strings.

### 5. Debug Views Are Good But Missing The Exact Split Needed Now

Severity: medium.

Current debug views show raw R, final pillow mask, obstacle confidence, hard-boundary/protrusion response, terrain protrusion, and final flow strength. That is useful, but it does not directly answer which sub-term made a raw pillow pixel exist.

Recommendation:

Add temporary or permanent pillow diagnostic modes for:

- Pillow support/facing source.
- Direct terrain protrusion anchor.
- Bank-response anchor.
- Combined pillow contact gate.
- Bank-only anchor contribution.

These views would let the user review the formula in the editor viewport before a bake-level change.

### 6. Runtime Cost Is Mostly Acceptable In The Visible Shader

Severity: low-medium.

With reach and contact pull default-off, visible pillow evaluation is fairly cheap: one current-pixel raw sample plus scalar gates. The expensive work is mostly in bake-time filters and debug modes, which is appropriate for game runtime.

Risks to avoid:

- Do not add multi-sample pillow searches to the visible shader unless they are default-off or strictly bounded.
- Do not make optional height displacement a default feature until visual artifacts, mesh density, and buoyancy mismatch are accepted tradeoffs.
- Keep final-flow and WaterSystem changes separate from material-only pillow changes.

## Recommended Next Pass

1. Add diagnostic split views before changing the classifier:
   - direct `terrain_contact.b` anchor;
   - `bank_response.a` anchor;
   - combined pillow contact gate;
   - support/facing source.
2. Review those views live in the editor on the same rock/protrusion targets where the user sees the forward offset.
3. If the split confirms bank-response anchoring is the cause, change pillow R so direct protrusion/contact is the required anchor.
4. Keep `bank_response.a` as context only for pillows.
5. Bump the source signature and rebake only main and obstacle-test river resources if `obstacle_features.r` changes.
6. Re-run:
   - pillow anchor audit;
   - Phase 6C pillow placement diagnostic;
   - pillow editor wiring probe;
   - wake/eddy visual probes to ensure accepted Phase 7B behavior did not regress.
7. Only tune pressure/highlight/normal/bands/foam/height after raw placement is accepted.

## Possible Formula Direction

A safer pillow classifier shape would be:

```text
direct_anchor = tight local search of terrain_contact.b
semantic_context = low-weight bank_response.a overlap/context
source = tight support * facing^2 * bank suppression
raw_pillow = source * direct_anchor_gate * context_gate
```

Where:

- `direct_anchor_gate` should be mandatory or near-mandatory.
- `context_gate` may include `bank_response.a`, energy, flow, and ordinary-bank suppression.
- Broad support should not create a pillow unless the direct anchor is nearby.

This preserves the useful semantic bank/protrusion map without letting it define the visible start of the pillow.

## Follow-Up Questions

1. In the editor, what exact visual boundary should count as the start of a correct pillow: first visible rock-water contact, slightly upstream of contact, or the peak of the mound?
2. Should submerged rocks with no visible hard contact still produce a pillow, or should they produce only subtle pressure/normal changes?
3. Should cliff-wall pillows follow the same strict direct-contact rule as boulder pillows, or should cliff walls allow broader bank-response context?
4. Are ordinary hard banks allowed to show short localized pillows where current hits a convex corner, or should pillows be limited to in-river obstructions?
5. Do we want pillow detection to favor false negatives over false positives? For games, a slightly missing pillow may be less distracting than a detached one.
6. Should the bake produce a separate pillow diagnostic texture/channel in the future, or are debug-only shader modes enough?
7. Should `baking_dilate` remain a shared authoring control, or should obstacle avoidance, foam/pressure, wakes, and pillows each get their own support radius?
8. Should the final visible pillow mask require direct terrain/contact too, even if raw R remains broad for compatibility?
9. How important is pillow behavior in shallow water versus deeper high-energy flow? Should grade/depth suppress shallow bank artifacts more aggressively?
10. Should material-side `pillow_contact_pull_*` remain as review-only controls, or should they be hidden/renamed to avoid implying they fix raw placement?
11. Should optional pillow height ever become a default feature, or should it stay an experimental accent because it can mismatch buoyancy and mesh density?
12. What is the minimum set of debug views the user actually wants in the editor menu, versus temporary scripts under `.codex-research`?

## Files Reviewed

- `addons/waterways/docs/handoffs/handoff-latest.md`
- `addons/waterways/docs/roadmaps/river-feature-detection-roadmap.md`
- `addons/waterways/docs/roadmaps/river-improvements-roadmap.md`
- `addons/waterways/docs/research/river-research-citations.md`
- `addons/waterways/docs/history/CHANGELOG.md`
- `addons/waterways/river_manager.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/resources/river_bake_data.gd`
- `addons/waterways/gui/debug_view_menu.gd`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`
- `addons/waterways/shaders/filters/bank_response_feature_mask_filter.gdshader`
- `addons/waterways/shaders/system_renders/system_flow.gdshader`
- `.codex-research/phase6c_pillow_placement_diagnostic.gd`
- `.codex-research/pillow_formula_anchor_audit.gd`

## Validation Commands Run

- Existing pillow placement diagnostic:
  - Result: `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`
- Pillow anchor split audit:
  - Result: `PILLOW_FORMULA_ANCHOR_AUDIT_OK`

## References

- Boat Ed, "River Hazards: Pillows": https://www.boat-ed.com/waterrescue/studyGuide/River-Hazards-Pillows/191099_55417/
- Boreal River Rescue, "How To Read a River - Hydrology 101": https://rescue.borealriver.com/blogs/swiftwater-and-whitewater/hydrology
- Godot documentation, "ShaderInclude": https://docs.godotengine.org/en/stable/classes/class_shaderinclude.html
- Godot documentation, "Shader preprocessor": https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shader_preprocessor.html
