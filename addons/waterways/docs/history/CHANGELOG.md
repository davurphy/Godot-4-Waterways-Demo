# Waterways Changelog

## Unreleased - 2026-05-26

### Editor Stability

- Fixed a post-tooltip-session editor regression in the bundled hterrain packed-texture scripts. Godot first reported `addons/zylann.hterrain/tools/packed_textures/packed_texture_importer.gd:93` from malformed converted method chains, then exposed broader Godot 3 importer API errors in the same legacy script set.
- Replaced the unused legacy `.packed_tex` and `.packed_texarr` custom importer implementation with Godot 4.6-compatible unavailable stubs. This keeps the editor stable for the current project, which has no `.packed_tex` / `.packed_texarr` assets and no active importer registration, but does not restore those legacy importer formats.
- The user confirmed the reported hterrain packed-texture errors are gone. No Waterways pillow classifier, shader, river bake, WaterSystem bake, or tooltip functionality changed in this stability slice.

### River Pillow Inspector Usability

- Organized `Material / Pillow` controls into Inspector subgroups: Pillow Shape, Pillow Mask Gates, Pillow Surface, Pillow Bands & Foam, Pillow Height, and Pillow Seam Fades.
- Researched Godot 4.6 inspector tooltip/description support for generated `mat_pillow_*` fields. Non-replacing helper-row and full-width helper-block prototypes were rejected as visually confusing, so in-inspector descriptions were removed.
- Added `docs/spec-driven/features/river-pillows/material-controls.md` as the Pillow material-control reference instead.
- Added `docs/spec-driven/features/river-pillows/engineering-audit.md` and updated handoffs so the next session starts with a software-engineering audit of the pillow system before rebakes or feature tuning.

### River Pillows Direct-Contact Diagnostic Pass

- Added editor Debug View modes for pillow placement review:
  - `Pillow Visual Mask (Black Zero)`
  - `Pillow Direct Terrain Anchor Search`
  - `Pillow Bank-Response Anchor Search`
  - `Pillow Combined Contact Gate`
  - `Pillow Bank-Only Anchor Contribution`
  - `Pillow Raw-to-Final Retention`
- Reset `Demo_obstacle_flow_test.tscn` saved pillow review material values to baseline placement-review defaults, including zero forward reach, zero contact pull, zero terrain/obstruction height, and non-inverted gate pairs.
- Recorded the user's diagnostic review: raw R and final Black Zero still began early, direct terrain anchor search was closest to the intended pillow face, and bank-response/combined contact gating was too broad.
- Changed the raw pillow classifier so direct `terrain_contact_features.b` search is mandatory for the pillow contact gate; `bank_response_features.a` now acts only as weak context and cannot anchor a pillow alone.
- Bumped the river bake source signature to version `20` and recorded direct-contact-first pillow anchor metadata. Existing signature-`19` river bakes are stale until the main and obstacle-test rivers are regenerated.
- Did not change WaterSystem/physics bakes, final flow, or visible material tuning.

### River Pillows Spec-Driven Feature Folder

- Added `docs/spec-driven/features/river-pillows/` as the feature-local source of truth for pillow placement work.
- Converted the pillow-relevant Phase 6 history and `handoffs/handoff-latest.md` guidance into focused `research.md`, `spec.md`, `plan.md`, `tasks.md`, `validation.md`, `review.md`, and `handoff-latest.md` documents.
- Folded the pillow-relevant sections of `roadmaps/river-feature-detection-roadmap.md` and `roadmaps/river-improvements-roadmap.md` into the feature docs, including the raw/final/visible review loop, feature definitions, generalization checks, raw-reading expectations, Phase 6 design rules, and change boundaries.
- Folded `audit/pillow-system-audit.md` into the feature plan, tasks, validation, review, and roadmaps. The audit makes diagnostic split views/probe output the first implementation step and records direct-contact-first raw pillow anchoring as the leading formula direction if live review confirms the audit.
- Recorded the current next step as audit-guided diagnostic split views/probe output, followed by a dedicated pillow formula review before any further classifier, shader, bake, or material changes.
- Kept this consolidation documentation-only: no shader code, bake resources, source signatures, final flow, WaterSystem data, probes, or generated captures changed.

### River Eddies Spec-Driven Feature Folder

- Added `docs/spec-driven/features/river-eddies/` as the feature-local source of truth for wake, eddy-line, and future eddy-flow work.
- Converted the eddy/wake/eddy-line relevant Phase 7 history and `handoffs/handoff-latest.md` guidance into focused `research.md`, `spec.md`, `plan.md`, `tasks.md`, `validation.md`, `review.md`, and `handoff-latest.md` documents.
- Folded the eddy-relevant sections of `roadmaps/river-feature-detection-roadmap.md` and `roadmaps/river-improvements-roadmap.md` into the feature docs, including the raw/final/visible review loop, channel/phase alignment lesson, accepted Phase 7B baseline, visual validation expectations, and Phase 7C/7D change boundaries.
- Recorded the current accepted baseline: Phase 7B remains a visual-only wake/eddy-line material preview, and `Eddy-Line Visual Mask` uses the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.
- Preserved the old raw-B path as diagnostics through B-based debug views, and recorded that real reverse/circulating flow, WaterSystem/physics alignment, new eddy vector data, and Phase 7C/7D remain deferred.
- Kept this consolidation documentation-only: no shader code, bake resources, source signatures, source flow, final flow, WaterSystem data, probes, or generated captures changed.

### Debug View Menu Label Cleanup

- Removed the leading `Display` prefix from every editor Debug View menu item, including quick views and grouped feature submenus. Debug mode IDs are unchanged, so this is an editor-label-only update.
- Updated the toolbar button caption to show the active debug mode, such as `Debug View: Normal`, `Debug View: Foam Mix`, or the currently selected submenu mode. The selected river's saved debug view now resyncs both the checked menu item and the visible button text.
- Added `.codex-research/debug_view_menu_wiring_probe.gd` to verify the renamed menu entries still map to debug shader constants and handled branches, and that selected IDs still flow through menu, plugin, river, and debug shader wiring.
- Validation passed with Godot 4.6.3 using repo-local user data folders: `DEBUG_VIEW_MENU_WIRING_PROBE_OK`, `PHASE1_DEBUG_PROBE_OK`, `PHASE6A_PILLOW_VISUAL_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, and `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`.

### Roadmap, Debug Views, And Editor UX

- Added `river-improvements-roadmap.md` to document the planned river-generation work for grade/energy, bends, obstacle feature masks, pillows, eddies, physics integration, authoring controls, and further research.
- Added a Godot verification setup section to the roadmap with the known Godot 4.6.3 console/editor executable paths and the repo-local `APPDATA` / `LOCALAPPDATA` redirection pattern for scripted probes.
- Expanded `RiverBakeData` channel metadata so current and reserved bake channels are explicit:
  - `flow_foam_noise.rg`: packed signed flow vector.
  - `flow_foam_noise.b`: foam mask.
  - `flow_foam_noise.a`: phase/noise offset.
  - `dist_pressure.r`: distance/bank influence.
  - `dist_pressure.g`: pressure/support.
  - `dist_pressure.b`: reserved grade/energy feature channel.
  - `dist_pressure.a`: reserved bend-bias feature channel.
- Updated river bakes to reserve `dist_pressure.b` as neutral grade/energy `0.0` and `dist_pressure.a` as neutral bend bias `0.5`.
- Bumped the river bake source signature to version `9` so older bakes are treated as stale after the reserved channel layout change.
- Expanded the river debug shader with views for raw flow, effective flow, final flow strength, surface steepness/grade proxy, reserved grade/energy, reserved bend bias, pillow mask, and eddy mask.
- Corrected the debug shader's surface-steepness scale so it matches the actual water and system-flow shader calculations.
- Split `Debug View` out of the nested `River` menu into its own top-level toolbar menu next to `River`, making debug views one click easier to reach while editing rivers.
- Added a local `.codex-research` Godot probe for Phase 1 validation and verified it with Godot 4.6.3.
- Added `NEXT_SESSION_HANDOFF.md` with a read list, previous-session summary, validation pattern, and instructions for the next session to inspect, research, plan, and discuss before committing code changes.
- Refined the Phase 0 terrain/world contact plan with explicit `terrain_contact_features` storage, neutral fallback, source-signature, HTerrain world-height conversion, generic physics fallback depth, thresholded diagnostics, and debug-only Phase 0A validation requirements.
- Inserted a new Phase 5 actual flow-map improvement pass into `river-improvements-roadmap.md`, then renumbered pillows to Phase 6, eddies to Phase 7, visual/physics alignment to Phase 8, authoring controls to Phase 9, and later features to Phase 10.
- Initially updated `NEXT_SESSION_HANDOFF.md` so the next-session checklist pointed to the Phase 5 flow-map improvement pass before pillow visuals; later Phase 5 acceptance now moves the handoff to Phase 6A.

### Changelog Maintenance

- Future sessions should update [docs/history/CHANGELOG.md](CHANGELOG.md) when changing Waterways addon behavior, editor UX, bake data, debug tools, roadmap docs, or validation workflows.
- Added `river-research-citations.md` as the shared, categorized research index for hydrology, obstruction-flow papers, shader/flow-map references, production water systems, Godot tooling, open-source examples, and future research leads. Pointed the roadmaps at it so future source additions do not get split across appendix lists.
- Updated `NEXT_SESSION_HANDOFF.md` so the next session focuses on a Phase 7B eddy-line diagnostic ladder and raw numeric/readback tooling plan before shader tuning, bake classifier edits, or Phase 7C flow work.
- Clarified that future research/planning passes may search online for research papers, white papers, GDC/SIGGRAPH talks, GitHub examples, Godot or other game-engine tutorials, shader writeups, and related river/water rendering references before committing to an implementation plan.
- Added `river-feature-detection-roadmap.md` to break out the collaborative detection-review workflow for pillows, wakes, and eddy lines. The workflow keeps the current visual baselines, improves detection slowly with user confirmation in editor/runtime debug views, compares raw and final masks before changing code, and calls for raw numeric tools/readings for user-identified expected detection areas so Codex is not relying on screenshots alone.
- Expanded the feature-detection roadmap with reusable add-on development principles: avoid demo-scene overfitting, preserve inspectable MIT-friendly reference value, define feature terms, check multiple river layouts, track raw numeric metrics, and maintain a debug-view/tooling backlog.
- Added a truth-seeking collaboration note to the feature-detection roadmap: both the user and Codex can be wrong, Codex should push back rather than agree reflexively, and explanations or references should be used to help the user learn hydrology, shader, rendering, physics, and game-design context during review.
- Trimmed `NEXT_SESSION_HANDOFF.md` from a long phase-history log into a tactical next-session quick-start now that stable history lives in the changelog and roadmaps.
- Added an explicit next-session note that the next step is research and roadmap planning for river feature detection, not shader, bake, or material coding yet.

### Phase 7B Visual Wake And Eddy-Line Material Preview

- Reviewed the completed Phase 7A2 outputs under `.codex-research/phase7a2_wake_eddy_demo_debug/` and `.codex-research/phase7a2_mask_preflight/`; the gated wake remained localized, and the narrowed eddy-line placement was restrained enough for a visual-only preview.
- Added a `wake_` material-control category to the Waterways inspector.
- Added conservative wake/eddy uniforms to the visible and debug river shaders for gated wake strength, confidence/hard-boundary/energy/flow gates, ordinary-bank suppression, source-tile edge sampling, eddy-line edge/near-wake gates, normal detail, roughness/specular breakup, albedo breakup, and small foam flecks.
- Added shader-side `wake_visual_mask` and `eddy_line_visual_mask` helpers. They consume existing `obstacle_features.g` wake seeds, narrowed `obstacle_features.b` eddy-line/shear, obstacle confidence, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, normalized final-flow strength, and wake-edge thinness.
- Added surface-only downstream wake breakup, subtle wake/eddy normal and roughness changes, small high-noise foam flecks, and narrow eddy-line turbulence without redirecting flow vectors or changing final-flow force.
- Added debug modes and menu entries for `Wake Visual Mask`, `Eddy-Line Visual Mask`, and `Wake Edge Thinness`.
- Added ignored Phase 7B helpers:
  - `phase7b_wake_eddy_visual_probe.gd`
  - `export_demo_phase7b_wake_eddy_views.gd`
- Added an ignored CPU/readback eddy-line diagnostic helper, `phase7b_eddy_line_cpu_diagnostic.gd`, which samples the existing signature-`17` river bakes and reports raw `obstacle_features` B/G/A, shared wake gating, wake-edge gradient, nearby wake, edge thinness, and final eddy-line retention across current, one-pixel, `0.012`, and `0.024` source-tile edge sample distances.
- Recorded the Phase 7B diagnostic finding that raw eddy-line channels are present in marked expected regions, current `wake_edge_sample_tiles = 0.006` is sub-pixel at about `0.31` texture pixels, one-pixel-ish sampling substantially restores expected-region final mask averages, and separate raw-B suppressed regions are mainly limited by low `wake_shared_gate`.
- Updated the handoff, feature-detection roadmap, and Phase 7 roadmap with the user's downstream-looking `Wake Edge Thinness` viewport review: expected thinness should show on downstream rock shoulders and trailing wake margins, while filled wake blobs, upstream pillow-face outlines, and continuous ordinary-bank outlines remain bad signs.
- Recorded the user's `Eddy-Line Visual Mask` review that the current final view is void of eddies away from the river start, and that the bright start-of-river response should be treated as a likely boundary/source false positive rather than evidence of successful eddy-line detection.
- Added a clear next-session Phase 7B eddy-line triage ladder: lock review targets, verify debug honesty, run the edge-sample sweep, split edge-thinness failures from shared-gate failures, inspect specific shared-gate components, escalate to bake/classifier work only if raw B placement is wrong, and tune visible material response last.
- Exported 60 Phase 7B review captures under `.codex-research/phase7b_wake_eddy_demo_debug/`.
- Initial editor review found `Eddy-Line Visual Mask` reads as a uniform green river in the current debug gradient. Since this gradient uses green for low/near-zero mask values, mark the eddy-line visual derivation as needing follow-up: the final mask appears over-suppressed or not visually diagnosable enough, rather than clearly identifying narrow eddy-line seams.
- Added a follow-up Phase 7B `wake_edge_sample_tiles` sweep helper and two debug-only retention views, `Wake Shared Gate` and `Gated Eddy-Line Source (B * Wake Gate)`, so edge-thinness failures can be separated from shared-gate suppression without changing bakes, source signatures, final flow, or WaterSystem data.
- Updated the handoff and roadmaps after user viewport review rejected the `0.024` edge-sample-only fix. The next Phase 7B step is now gate diagnosis: expose gate components, prototype a debug-only eddy-line-specific context gate, and have the user review `Experimental Gated Eddy Source` before returning to edge thinness, final eddy-line masks, material response, bakes, or Phase 7C flow.
- Added debug-only Phase 7B gate diagnosis views for `Wake Confidence Gate`, `Wake Hard/Protrusion Gate`, `Wake Bank Keep Gate`, `Wake Energy Gate`, and `Wake Flow Gate`.
- Added debug-only `Eddy-Line Context Gate` and `Experimental Gated Eddy Source` views. The experimental gate keeps raw `obstacle_features.b` as the eddy-line candidate, but searches nearby/upstream for hard-protrusion or wake-source context instead of requiring exact-pixel hard-boundary support.
- Refreshed the Phase 7B wake-edge sample sweep with the new debug views. This remains a visual/debug-only pass: no bake resources, source signatures, visible material response, final flow, WaterSystem shader wiring, or saved WaterSystem bake were changed.
- Reorganized the editor debug-view menu into quick top-level views plus feature submenus for General, Flow, Pillows, Wake / Eddy, Terrain / Banks, Bends / Grade, and Obstacles.
- Added follow-up Wake / Eddy diagnostics after viewport review of the first experimental gate: `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, and `Eddy-Line Wake Context Search`.
- Added debug-only wake-edge candidate diagnostics sourced from raw `obstacle_features.g`: `Raw Wake-Edge Candidate (from G)` and `Experimental Wake-Edge Eddy Source`, so close-behind-rock placement can be compared against the too-far-downstream raw B eddy-line source without changing visible water.
- Promoted the accepted wake-edge-from-G prototype into the actual visual eddy-line mask. Visible water and the `Eddy-Line Visual Mask` debug view now use paired raw wake-edge margins plus nearby wake/obstruction context instead of the old raw-B-at-exact-pixel gate, while keeping the old B-based source as a diagnostic view.
- Updated the default `wake_edge_sample_tiles` value from `0.006` to the reviewed `0.024` value so fresh shader loads use the same paired-line edge scale that the user accepted.
- Fixed a stale debug-material override issue that could make visible-water material fields appear to do nothing. The River now restores the visible material when Debug View is Normal, reapplies the active material mode after material-field edits, and the demo scene is no longer saved with a debug shader override on the generated river mesh.
- Increased the default visible eddy-line response after review found the effect too subtle: higher `wake_eddy_line_strength`, `wake_eddy_line_normal_strength`, `wake_eddy_line_foam_bias`, roughness/specular breakup, albedo breakup, and less sparse eddy-line foam/color noise.
- Documented the accepted Phase 7B fix as a channel/phase alignment fix: raw B was plausible but too far from the source rocks, while a raw-G wake-edge candidate produced the accepted distance and paired-line pattern. Added a Phase 6 pillow follow-up note to apply the same method because the current pillow appears far ahead of its source rock/protrusion.
- Kept Phase 7B visual-only: no `RiverBakeData` layout change, no river bake source-signature bump, no source-flow change, no reverse/circulating flow, no WaterSystem shader wiring, and no saved WaterSystem bake regeneration.
- Validation passed with Godot 4.6.3: `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_WAKE_EDDY_EXPORT_OK`, and `PHASE6B_PILLOW_TUNING_PROBE_OK`.

### Phase 6C Pillow Placement Diagnosis

- Added ignored review helper `.codex-research/phase6c_pillow_placement_diagnostic.gd` to compare raw `Pillow / Impact Mask`, no-reach `Pillow Visual Mask`, and the prior `pillow_forward_reach_tiles = 0.075` result on the main and obstacle-test bakes.
- The diagnostic found the forward placement issue is shader-side reach, not a required bake/source-signature change: the prior reach nearly doubled final pillow coverage above `0.05` compared with no reach.
- Changed the default `pillow_forward_reach_tiles` from `0.075` to `0.0` in the visible and debug river shaders, while keeping the material slider available for explicit review use.
- Fixed pillow editor wiring after live review still looked unchanged: preserved explicit shader range hints so `pillow_terrain_height_curve` and `pillow_obstruction_height_curve` no longer get treated as generic easing controls, synced saved visible-material parameters into the debug material, fixed material revert hooks, reset stale obstacle-demo Pillow and Wake / Eddy feature overrides to current shader defaults, and added `.codex-research/phase6c_pillow_editor_wiring_probe.gd`.
- Reverted the next-session warning about broad editor-field failure after the user clarified the apparent no-op controls came from another setting being too high.
- Added a default-off shader experiment for placing pillows closer to the obstruction: `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` in the visible/debug shaders, with editor revert defaults and probe coverage.
- Kept the fix visual-only: no `RiverBakeData` layout change, no river bake source-signature bump, no source-flow change, no WaterSystem shader wiring, and no saved WaterSystem bake regeneration.

### Phase 6D Pillow Raw Classifier Contact Anchor

- Follow-up viewport review found the raw `Pillow / Impact Mask` / `obstacle_features.r` still sat too far ahead of rocks, so the pillow work moved from shader-only tuning into a scoped bake/classifier pass.
- Refined `obstacle_feature_mask_filter.gdshader` so the pillow channel uses its own tighter support thresholds plus a nearby hard-contact/protrusion anchor in the downstream flow direction. The wake seed and eddy-line derivation continue to use their existing support path.
- Added pillow classifier constants, source metadata, bake settings, and source-signature entries for the new support/contact-anchor tuning.
- Bumped the river bake source signature to version `18` and rebaked the main and obstacle-test river resources:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- Kept the pass data-only for river resources: no `RiverBakeData` layout change, no source-flow change, no visible shader material change, no WaterSystem shader wiring, and no saved WaterSystem bake regeneration.
- Refreshed `.codex-research/phase6c_pillow_placement_diagnostic/`; raw pillow coverage above `0.05` is now about `5.12%` on the main bake and `5.06%` on obstacle-test in the diagnostic atlas-space pass, with the broad ahead-of-rock blobs visibly reduced in the review cameras.
- Validation passed with Godot 4.6.3: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PHASE6A_PILLOW_VISUAL_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`, `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, and `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`.

### Phase 6E Pillow Contact Search Distance Review

- User in-game review found obstruction pillows still slightly too far ahead of rocks and requested halving the placement distance for review.
- Halved the raw pillow classifier contact-search distance from `0.14` to `0.07` source tiles, and aligned the obstacle feature filter's direct fallback `pillow_contact_search_uv` default from `0.02` to `0.01`.
- Bumped the river bake source signature to version `19` and rebaked only the main and obstacle-test river resources:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- Kept the pass data-only for river resources: no `RiverBakeData` layout change, no source-flow change, no visible shader material change, no WaterSystem shader wiring, and no saved WaterSystem bake regeneration.
- Refreshed `.codex-research/phase6c_pillow_placement_diagnostic/`; diagnostic atlas-space raw pillow coverage above `0.05` is now about `4.70%` on the main bake and `4.61%` on obstacle-test. The no-reach visual mask above `0.05` is about `2.32%` main and `2.26%` obstacle-test.
- Validation passed with Godot 4.6.3: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE6A_PILLOW_VISUAL_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`, `DEBUG_VIEW_MENU_WIRING_PROBE_OK`, and `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`.

### Phase 6F Pillow Formula Review Prep

- Documented the post-6E finding that the remaining ahead-of-rock pillow start is not coming from visible shader reach when the reach/contact-pull controls are default-off.
- Recorded the current pillow start formula: visible `Pillow Visual Mask` mostly reveals baked raw `obstacle_features.r`, while raw R combines dilated collision support, flow-facing obstacle normals, and a hard-boundary gate.
- Identified the likely formula risk: pillow hard-boundary gating uses `max(bank_response.a, terrain_contact.b)`, but `bank_response.a` is a semantic hard-boundary/protrusion response with forward protrusion sampling, so it can anchor pillows to a context halo ahead of the visible object.
- Updated the handoff and feature-detection roadmap to ask for a dedicated formula review session before the next classifier edit. Candidate directions include direct-contact anchoring via `terrain_contact.b`, lower/overlap-gated use of `bank_response.a`, tighter pillow support, or a diagnostic split of support/contact/bank-response contributions.
- Documentation-only: no shader code, bake resources, source signatures, final flow, WaterSystem data, or validation probes changed.

### Phase 6F Pillow Formula Review Findings

- Refined the documentation after code and capture review of the current pillow formula.
- Clarified that the explicit `0.07` pillow contact-search distance is not the full effective anchor reach: `pillow_contact_gate_at()` samples `hard_boundary_at()` up to `1.5 * pillow_contact_search_uv`, `hard_boundary_at()` includes `bank_response.a`, and `bank_response.a` already uses `forward_protrusion()` from `RIVER_BANK_RESPONSE_PROBE_TILES = 0.20`.
- Clarified that raw pillow source can also begin from broad dilated support because `pillow_source_at()` uses the generic `baking_dilate = 0.6` collision support texture.
- Updated the handoff, feature-detection roadmap, and improvements roadmap to recommend a diagnostic split of support/facing, direct `terrain_contact.b`, `bank_response.a`, and final contact-gate contribution before changing classifier constants again.
- Documentation-only: no shader code, bake resources, source signatures, final flow, WaterSystem data, or validation probes changed.

### Phase 7A1 Wake And Eddy-Line Mask Preflight

- Added ignored review-only helpers under `.codex-research` for candidate wake and eddy-line masks:
  - `phase7a1_wake_eddy_mask_lib.gd`
  - `phase7a1_wake_eddy_mask_preflight.gd`
  - `export_demo_phase7a1_wake_eddy_views.gd`
- Computed candidate `gated_wake`, `gated_eddy_line`, and `wake_edge_thinned_eddy_line` masks from the existing signature-version-`16` bakes using obstacle confidence, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, estimated normalized final-flow strength, and local wake-edge gradients.
- Exported atlas-space Phase 7A1 mask images under `.codex-research/phase7a1_mask_preflight/` and 60 accepted Phase 0B camera captures under `.codex-research/phase7a1_wake_eddy_demo_debug/`.
- Main demo stats: raw wake above `0.05` is about `18.54%`, gated wake about `7.19%`, raw eddy-line about `20.60%`, gated eddy-line about `8.30%`, and wake-edge-thinned eddy-line about `4.31%`.
- Obstacle-test stats are similar: raw wake above `0.05` is about `18.69%`, gated wake about `7.17%`, raw eddy-line about `20.45%`, gated eddy-line about `8.02%`, and wake-edge-thinned eddy-line about `4.16%`.
- Recorded the Phase 7A1 finding: the gated wake mask is localized enough for a cautious visual wake-only preview if accepted, but the current eddy-line/shear source should get a Phase 7A2 classifier pass before visible eddy-line foam/turbulence, gameplay feedback, reverse-flow, or WaterSystem use.
- Kept Phase 7A1 review-only. No visible shader behavior, bake resource, river bake source signature, final flow, WaterSystem flow shader, saved WaterSystem bake, terrain-contact threshold, bank-response threshold, or obstacle classifier code was changed.

### Phase 7A2 Eddy-Line Classifier Refinement

- Refined `obstacle_feature_mask_filter.gdshader` so `obstacle_features.b` uses thresholded wake edges, hard-boundary/protrusion context from `bank_response_features.a` and `terrain_contact_features.b`, grade/energy gating, source-support rejection, and a narrower confidence contribution.
- Passed terrain-contact and grade/energy textures through `FilterRenderer.apply_obstacle_feature_mask()` and recorded the new eddy-line tuning constants in bake metadata, bake settings, and source signatures.
- Bumped the river bake source signature to version `17`.
- Rebaked and saved the main and obstacle-test river bake resources to signature version `17`.
- Main demo metadata stats after the rebake: raw eddy-line/shear above `0.05` is about `3.38%`, above `0.25` about `2.68%`, and above `0.50` about `1.97%`; wake coverage stayed effectively unchanged.
- Image-space Phase 7A2 preflight stats: main demo raw eddy-line above `0.05` is about `2.42%`, gated eddy-line about `1.06%`; obstacle-test raw eddy-line above `0.05` is about `2.15%`, gated eddy-line about `0.95%`.
- Added ignored Phase 7A2 helpers:
  - `phase7a2_obstacle_features_probe.gd`
  - `rebake_demo_phase7a2_data.gd`
  - `phase7a2_wake_eddy_mask_preflight.gd`
  - `export_demo_phase7a2_wake_eddy_views.gd`
- Exported atlas-space Phase 7A2 masks under `.codex-research/phase7a2_mask_preflight/` and 60 accepted Phase 0B camera captures under `.codex-research/phase7a2_wake_eddy_demo_debug/`.
- Updated `RiverBakeData` obstacle-feature channel metadata so channel B describes the terrain/energy-gated eddy-line mask.
- Kept Phase 7A2 data-only: no final-flow change, no visible river shader behavior change, no WaterSystem flow shader wiring, no terrain-contact threshold change, no bank-response threshold change, and no saved WaterSystem bake regeneration.
- Validation passed with Godot 4.6.3: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, `PHASE7A2_WAKE_EDDY_EXPORT_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, and `DEMO_SYSTEM_MAP_VALID=true`.

### Phase 5A Contextual Flow Consumption

- Began Phase 5A by consuming the existing terrain-contact and bank-response feature maps in final flow calculations instead of changing baked `flow_foam_noise.rg`.
- Added conservative flow tuning uniforms to the river, debug, and WaterSystem flow shaders: `flow_bank_drag`, `flow_shallow_drag`, `flow_inside_bend_drag`, `flow_pressure_bank_gate`, `flow_hard_boundary_pressure`, `flow_hard_boundary_slide`, `flow_hard_boundary_min_downstream`, and `flow_boundary_probe`.
- Updated `river.gdshader` so bank friction, shallow depth, inside-bend deposition, and hard-boundary/protrusion context damp final flow force; ordinary bank contact gates old pressure/support force, while hard protrusions keep a smaller local pressure term.
- Added local hard-boundary sliding in the visible river shader by estimating a boundary-context gradient, blending toward the downstream-facing tangent, and preserving a minimum downstream component.
- Updated `river_debug.gdshader` so Effective Flow, Final Flow Strength, Flow Pattern, and Flow Arrows use the same Phase 5A contextual flow math as visible water. Raw Flow remains available as the baked `flow_foam_noise.rg` view.
- Updated `system_renders/system_flow.gdshader` and `system_map_renderer.gd` so generated WaterSystem flow receives the same terrain-contact and bank-response damping, pressure gating, and hard-boundary slide behavior as visible water.
- Kept Phase 5A out of foam, visible pillow accents, obstacle wake visuals, and true reverse/circulating eddy flow.
- Did not bump the river bake source signature because Phase 5A is shader/system-flow consumption only; version `15` river bakes remain valid.
- Added `.codex-research/phase5a_contextual_flow_probe.gd` and `.codex-research/regenerate_demo_phase5a_system_map.gd`, and updated older grade/bend probes for the new WaterSystem parameter fallback helper.
- Regenerated and saved the main `waterways_bakes/Demo/WaterSystem.water_system_bake.res` after Phase 5A so saved physics flow matches the updated shader-time flow.

### Phase 5B SDF Steering Cleanup

- Tightened the older SDF obstacle steering bake after Phase 5A exposed remaining buggy spots from the broad source vector field.
- Bumped the river bake source signature to version `16`.
- Changed obstacle avoidance from broad `sdf_upstream_lookahead` behavior to `bank_context_gated_local_sdf_steering`.
- Reduced broad SDF anticipation:
  - steering strength from `1.0` to `0.85`.
  - influence start from `0.02` to `0.08`.
  - SDF steering radius from `0.95` tiles to `0.45` tiles.
  - SDF steering blur from `0.08` tiles to `0.02` tiles.
  - upstream lookahead from `0.30` tiles to `0.08` tiles.
  - upstream strength from `0.75` to `0.30`.
  - minimum downstream alignment from `0.45` to `0.65`.
- Updated `obstacle_avoidance_flow_filter.gdshader` and `FilterRenderer.apply_obstacle_avoidance_flow()` so ordinary bank friction suppresses old SDF steering while hard-boundary/protrusion response preserves local steering.
- Added source metadata, bake settings, and source-signature entries for the new obstacle-avoidance bank-context gates.
- Added `.codex-research/phase5b_sdf_steering_probe.gd`.
- Rebaked and saved the main and obstacle-test river bake resources to signature version `16`.
- Regenerated and saved the main `waterways_bakes/Demo/WaterSystem.water_system_bake.res` after the signature-`16` main river rebake.

### Phase 5 Acceptance And Phase 6 Prep

- Recorded the user in-game review result: Phase 5A/5B now looks good and should be treated as the accepted flow baseline.
- Expanded `river-improvements-roadmap.md` with a Phase 6A visual-only pillow plan that consumes the existing accepted masks before changing bakes or physics flow.
- Defined the Phase 6A pillow starting point: use `obstacle_features.r` as the upstream impact source, gate it with obstacle confidence, hard-boundary response, grade/energy, and final/effective flow strength, and suppress ordinary bank friction.
- Refined the Phase 6 roadmap after online hydrology, boulder-flow, flow-map, Unity, Unreal/Riverology, GPU Gems, and GitHub water-system research. The plan now emphasizes upstream compression/highlight/normal detail before foam, defines a concrete `pillow_visual_mask` gate, adds a `pillow_` material-control category recommendation, and spells out validation/debug expectations without changing bakes or WaterSystem flow.
- Revised the Phase 6A pillow plan with review findings: make `pillow_` inspector grouping explicit, preflight final-mask overlap stats before visible tuning, keep grade/energy and flow as separate gates, use safe flow-direction handling for compression bands, require a `Pillow Visual Mask` debug view, validate visible/debug parameter parity, and clarify that truly missing feature textures are still stale/invalid bakes unless a neutral fallback-texture pass is added.
- Updated `NEXT_SESSION_HANDOFF.md` so the next session starts on Phase 6A and avoids further hidden flow, SDF steering, WaterSystem, terrain-contact, or bank-response tuning unless a new visible regression appears.

### Phase 6A Visual Pillow Highlights

- Implemented the first visual-only pillow pass on top of the accepted Phase 5A/5B flow baseline.
- Added a `pillow_` material-control category to the Waterways inspector.
- Added conservative pillow uniforms to the visible and debug river shaders: `pillow_strength`, `pillow_energy_gate`, `pillow_flow_gate`, `pillow_bank_suppression`, `pillow_pressure_strength`, `pillow_highlight_strength`, `pillow_normal_strength`, `pillow_band_strength`, `pillow_band_scale`, `pillow_foam_bias`, and `pillow_forward_reach_tiles`.
- Added a shared shader-side `pillow_visual_mask` gate using `obstacle_features.r`, `obstacle_features.a`, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, and normalized final flow strength.
- Added shader-only forward reach sampling so the pillow visual can begin slightly upstream of the raw obstruction mask by looking downstream along the accepted flow direction.
- Kept grade/energy and final-flow strength as separate multiplicative gates.
- Added localized pressure/highlight, normal-detail, compression-band, and subtle high-energy foam accents without redirecting flow vectors.
- Added `Pillow Visual Mask` debug mode and menu entry while keeping `Pillow / Impact Mask` as the raw `obstacle_features.r` view.
- Added `.codex-research/phase6a_pillow_mask_preflight.gd`, `.codex-research/phase6a_pillow_visual_probe.gd`, and `.codex-research/export_demo_phase6_pillow_views.gd`.
- Preflight estimate for the main demo reduces raw pillow coverage above `0.05` from about `8.08%` to about `3.17%` after the combined visual gate and default source-tile forward reach.
- Exported Phase 6A review captures under `.codex-research/phase6_pillows_demo_debug/`.
- Kept the work visual-only: no `RiverBakeData` layout change, no river bake source-signature bump, no WaterSystem flow shader wiring, and no WaterSystem bake regeneration.
- Changed pillow forward reach from raw atlas texels to UV2 source-tile units via `pillow_forward_reach_tiles`, so material tuning is stable across bake resolution changes while remaining shader-only.

### Phase 6B Research And Planning

- Began the Phase 6B research/investigation pass without changing shaders, bakes, source flow, source signatures, or WaterSystem data.
- Reviewed the current Phase 6A captures, pillow shader path, feature-texture layout, obstacle feature classifier, debug views, filter renderer wiring, WaterSystem flow renderer, material grouping, and validation/export helper structure.
- Expanded `river-improvements-roadmap.md` with Phase 6B findings, a decision table, and a recommended next plan.
- Recommended keeping Phase 6B visual-only by default and treating it as a Phase 6A review/tuning gate until the pillow read is accepted in game.
- Folded in adversarial review notes: distinguish subtle-but-correct pillows from sparse shader-gated masks, use shader-only gate uniforms when `Pillow Visual Mask` over-suppresses good raw pillow pixels, separate pressure/highlight language from foam if needed, and refine reached-sample gating only if source-tile reach shows artifacts.
- Documented the boundary between visual-only changes, source-signature version `17` bake changes, resource-layout changes, and WaterSystem regeneration requirements.
- Added additional Phase 6B research sources covering Unreal/GDC distance-field flow tricks, baked river simulation, Crest flow inputs, Godot screen/depth shader constraints, Unity/Godot/open-source water shaders, and practical whitewater pillow/eddy references.

### Phase 6B Pillow Tuning Controls

- Implemented the first Phase 6B pillow tuning pass as visual-only shader work.
- Added shader-only gate controls to the visible and debug river shaders: `pillow_confidence_gate_start`, `pillow_confidence_gate_full`, `pillow_hard_gate_start`, `pillow_hard_gate_full`, `pillow_energy_gate_start`, and `pillow_flow_gate_start`.
- Added separate pillow pressure/highlight visual controls so upstream compression does not have to borrow directly from `foam_color`: `pillow_pressure_color`, `pillow_highlight_color`, `pillow_specular_boost`, and `pillow_roughness_reduction`.
- Tuned conservative defaults for a clearer review read while keeping foam subtle: `pillow_strength = 1.15`, `pillow_energy_gate = 0.35`, `pillow_flow_gate = 0.28`, `pillow_pressure_strength = 0.50`, `pillow_highlight_strength = 0.60`, `pillow_normal_strength = 0.70`, `pillow_band_strength = 0.55`, `pillow_foam_bias = 0.14`, and `pillow_forward_reach_tiles = 0.075`.
- Kept Phase 6B visual-only: no `RiverBakeData` layout change, no river bake source-signature bump, no source-flow change, no WaterSystem shader wiring, and no WaterSystem bake regeneration.
- Updated `.codex-research/phase6a_pillow_visual_probe.gd` and `.codex-research/phase6a_pillow_mask_preflight.gd` for the new gate controls.
- Added `.codex-research/phase6b_pillow_tuning_probe.gd` and `.codex-research/export_demo_phase6b_pillow_views.gd`.
- Exported Phase 6B review captures under `.codex-research/phase6b_pillows_demo_debug/`.
- Validation passed with Godot 4.6.3: `PHASE6B_PILLOW_TUNING_PROBE_OK`, `PHASE6A_PILLOW_VISUAL_PROBE_OK`, and the refreshed Phase 6 preflight estimates.

### Phase 6B Experimental Pillow Height Capture

- Implemented the roadmap's optional tiny local pillow height experiment as opt-in shader behavior, not a default visual change.
- Added split default-off height controls to the visible and debug river shaders: `pillow_terrain_height`, `pillow_terrain_height_curve`, `pillow_obstruction_height`, `pillow_obstruction_height_curve`, and `pillow_height_tile_seam_fade`.
- Added a vertex-stage local Y lift with distance/LOD fade. Terrain height uses the accepted hard-boundary `pillow_visual_mask`; obstruction height uses a separate obstruction impact mask so in-river rocks can lift even when the terrain/protrusion gate is weak.
- Added source-tile seam fading to the experimental height path so obstruction lift eases to zero at UV2 atlas borders and mesh step borders instead of pulling neighboring river tiles apart.
- Follow-up editor review confirmed the seam guard fixes visible tile separation at lower obstruction-height values. Documented obstruction height as a subtle vertical accent only; stronger pillow reads should prefer pressure/highlight, normal, band, and foam-bias cues unless the mesh topology is changed.
- Added `Pillow Height Influence` debug mode `27`, plus `Terrain Pillow Height Influence` mode `28` and `Obstruction Pillow Height Influence` mode `29`.
- Added `.codex-research/export_demo_phase6_pillow_height_experiment.gd`, which enables only the review capture terrain/obstruction strengths (`0.16`), curves (`1.20`), and seam fade (`0.035`) while leaving saved/default river behavior off.
- Exported 60 experimental review captures under `.codex-research/phase6_pillow_height_experiment_debug/`.
- Kept the experiment visual-only in data terms: no `RiverBakeData` layout change, no river bake source-signature bump, no source-flow change, no WaterSystem shader wiring, and no WaterSystem bake regeneration.
- Validation passed with Godot 4.6.3: `PHASE6B_PILLOW_TUNING_PROBE_OK` and `PHASE6A_PILLOW_VISUAL_PROBE_OK`.

### Phase 6B Closure And Phase 7 Handoff

- User confirmed Phase 6B can be considered done/closed for the next session.
- Updated `NEXT_SESSION_HANDOFF.md` so the next session starts with Phase 7 planning and wake/eddy mask review instead of more pillow tuning.
- Updated `river-improvements-roadmap.md` with a Phase 6B closure note and a staged Phase 7 planning split: mask review, visual wake/eddy-line cues, reverse/circulating flow, then WaterSystem/physics alignment if final flow changes.

### Phase 7 Research And Mask Review

- Began Phase 7 as a research/planning pass, not a runtime behavior change.
- Reviewed current Waterways Phase 7 surfaces: `obstacle_features.g` wake / eddy seed, `obstacle_features.b` eddy-line / shear, `obstacle_features.a` confidence, Phase 4B captures, river/debug shaders, obstacle feature classifier, WaterSystem flow renderer, bake metadata, and existing inspection/export helpers.
- Ran the current bake inspection helper against the signature-version-`16` main and obstacle-test bakes.
- Main demo image-space Phase 7 candidate stats: `obstacle_features.g` wake seed average about `0.079`, above `0.05` about `18.54%`; `obstacle_features.b` eddy-line/shear average about `0.150`, above `0.05` about `20.60%`; obstacle confidence above `0.05` about `40.16%`.
- Obstacle-test stats remain similar: wake seed above `0.05` about `18.69%`, eddy-line/shear above `0.05` about `20.45%`, obstacle confidence above `0.05` about `39.89%`.
- Visual review finding: the wake seed is useful enough for a gated visual wake preview, but the eddy-line/shear mask is still broad and saturated enough that it should not directly drive foam, turbulence, gameplay feedback, reverse flow, or WaterSystem data.
- Expanded `river-improvements-roadmap.md` with Phase 7 research findings, current-code findings, a decision table, a recommended Phase 7A review/gated-preview pass, and explicit boundaries for source-signature bumps, rebakes, new feature textures, final-flow changes, and WaterSystem regeneration.
- Added new Phase 7 references covering Valve/GDC flow-map production, LIGHTSPEED open-world water simulation, Epic baked river/shallow-water simulation, Unity HDRP current maps and sample scenes, Crest whirlpool flow controls, Riverology obstacle foam, Catlike Coding directional flow, Jos Stam fluid simulation, Godot screen/depth shader constraints, and hydrology wake/submergence research.
- Initially updated `NEXT_SESSION_HANDOFF.md` so the next session's role was to adversarially review the Phase 7 plan, research blind spots and alternatives online, propose solutions, and revise the Phase 7 roadmap before implementing.
- No river shader, debug shader, classifier shader, bake resource, source signature, source flow, WaterSystem flow shader, or saved WaterSystem bake was changed.

### Phase 7 Adversarial Plan Review

- Revised the Phase 7 roadmap after adversarial review of the existing plan, current captures, classifier code, visible/debug shader boundaries, WaterSystem flow export path, and additional external references.
- Split the next work into Phase 7A0 adversarial review, Phase 7A1 review-only preflight/export, Phase 7A2 classifier changes only if needed, Phase 7B visual-only surface accents, Phase 7C final-flow/reverse-flow work, and Phase 7D WaterSystem/physics alignment.
- Added explicit Phase 7 blind spots and failure modes: scalar wake/eddy masks do not encode spin side or reverse velocity, `obstacle_features.a` is too broad to be trusted alone, eddy-line foam can read like shoreline foam, downstream reach can smear across UV2 tiles or bends, and visual reverse-flow cues can mislead if buoyancy still moves downstream.
- Updated the recommended next action to build a review-only `wake_visual_mask` / `eddy_line_visual_mask` preflight with per-gate overlap stats and accepted Phase 0B camera captures before changing visible water, classifiers, bakes, final flow, or WaterSystem data.
- Updated `NEXT_SESSION_HANDOFF.md` to explicitly tell the next session that Phase 7A0 is complete and they can begin Phase 7A1 review-only preflight/export work.
- No runtime behavior, shader behavior, bake resource, source signature, source flow, WaterSystem flow shader, or saved WaterSystem bake was changed.

### Phase 0A Terrain And World Contact Masks

- Added a fourth river bake texture, `terrain_contact_features`, to `RiverBakeData`.
- Documented `terrain_contact_features` channel metadata:
  - `r`: near-surface terrain/world contact mask.
  - `g`: shallow-depth mask.
  - `b`: terrain/world protrusion or intersection mask.
  - `a`: contact source/provenance mask, with `1.0` for direct HTerrain samples and `0.5` for generic physics fallback samples. This channel is categorical source data, not a true confidence heatmap.
- Factored the river bake's UV2-to-world sampling path in `water_helper_methods.gd` so collision and terrain-contact bakes share the same atlas/world-position reconstruction.
- Added HTerrain-first height sampling with `world_to_map()`, `HTerrainData.get_interpolated_height_at()`, and `get_internal_transform()` world-height conversion, plus generic physics fallback raycasts for other world geometry.
- Added terrain-contact bake constants, source metadata, thresholded channel diagnostics, and source-signature entries.
- Bumped the river bake source signature to version `13`.
- Updated `river.gdshader`, `river_debug.gdshader`, and `debug_view_menu.gd` so terrain contact data is wired debug-first and not consumed by visible water, foam, pressure, obstacle masks, or WaterSystem flow.
- Added `.codex-research/phase0a_terrain_contact_probe.gd`, `.codex-research/rebake_demo_phase0a_data.gd`, and `.codex-research/export_demo_phase0a_debug_views.gd`.
- Updated local probes and inspection helpers for source signature version `13` and thresholded channel diagnostics.
- Rebaked the main and obstacle-test river bake resources to signature version `13` with `terrain_contact_features`.
- Regenerated the main demo WaterSystem map after the main Phase 0A river rebake.
- Exported Phase 0A demo inspection images under `.codex-research/phase0a_demo_debug/`.

### Phase 0B Planning And Review Cameras

- Documented the Phase 0B goal: keep terrain/world-contact data debug-only while reviewing and tuning the Phase 0A contact, shallow-depth, protrusion, and source/provenance masks.
- Added a `Phase0B Review Cameras` rig to `Demo.tscn` with whole-river overhead, focused overhead, and low oblique cameras for inspecting obstructions, bends, banks, and terrain-contact artifacts.
- Recorded the user-overhead review finding that the previous `Contact Source / Confidence` view was misleading: editor spline handles and segment lines overlay the debug render, and `terrain_contact_features.a` represents categorical source provenance rather than scalar confidence.
- Updated the Phase 0B plan to rename that debug view to `Contact Source / Provenance`, render it with discrete colors and nearest/texel-style sampling, and reserve a separate real confidence/problem view for later if needed.
- Kept the Phase 0B plan non-consuming: terrain-contact data should not affect visible water, foam, pressure, obstacle masks, normals, or WaterSystem flow until the debug masks read cleanly.

### Phase 0B Provenance Debug View

- Renamed the terrain-contact A-channel debug menu item from `Contact Source / Confidence` to `Contact Source / Provenance`.
- Updated `river_debug.gdshader` so the provenance view samples `terrain_contact_features.a` at texel centers and renders categorical source colors instead of the scalar red-green gradient.
- Updated `RiverBakeData` channel metadata, terrain-contact diagnostics naming, and local inspection/export helpers to use `contact_source_provenance` naming.
- Corrected the Phase 0B review-camera transforms in `Demo.tscn` so the overhead and oblique review cameras frame the river instead of looking sideways.
- Shifted the `Phase0B_UpperObstructions_Low_Oblique` review camera laterally so terrain no longer blocks most of the river view.
- Shifted `Phase0B_Downstream_Rocks_Low_Oblique` farther right and re-aimed it toward the downstream river channel so foreground rocks block less of the debug view.
- Refreshed the full Phase 0B review-camera capture set after the user accepted the adjusted low-oblique framing.
- Added `.codex-research/export_demo_phase0b_review_views.gd` and exported 32 Phase 0B review captures under `.codex-research/phase0b_demo_debug/`.
- Kept the change presentation-only and debug-only; no bake source-signature bump or rebake is required because the underlying `terrain_contact_features.a` values did not change.
- Re-ran the Phase 0A terrain-contact probe and main demo system-map validation after the Phase 0B presentation and camera updates.

### Phase 0B Terrain Contact Review And Metadata Cleanup

- Reviewed the refreshed Phase 0B review-camera captures and accepted the current terrain-contact masks for this milestone without changing contact, shallow-depth, protrusion/intersection, or source-selection thresholds.
- Added `RiverBakeData.normalize_source_metadata()` and call it when applying river bake data so older terrain-contact diagnostics using the nested `source_confidence` key migrate to `source_provenance`.
- Resaved `waterways_bakes/Demo/Water_River.river_bake.res` so its terrain-contact feature stats now use `source_provenance`; `Water_River_obstacle_test.river_bake.res` was already using the corrected key.
- Kept the cleanup data-only and debug-only: no bake source-signature bump, terrain-contact threshold change, visible-water consumption, or WaterSystem flow change.
- Re-ran the Phase 0A terrain-contact probe, bake inspection helper, and main demo system-map validation after the metadata cleanup.

### Phase 0C Planning Review

- Updated `river-improvements-roadmap.md` with Phase 0C review findings from the user screenshots, Phase 0B terrain-contact captures, current bake/shader plumbing, and supporting hydrology/game-rendering references.
- Clarified that `terrain_contact_features` should remain raw contact/depth/protrusion/provenance data and Phase 0C should derive a separate debug-only `bank_response_features` layer.
- Narrowed the proposed `bank_response_features.a` channel from a broad bank-eddy candidate to hard-boundary / protrusion response, leaving eddy candidacy for a later pass after downstream wake context is clearer.
- Documented that Phase 0C should avoid using the currently broad `obstacle_features` masks until Phase 4B tuning, and should first use terrain contact, shallow depth, protrusion/intersection, grade/energy, bend bias, and local downstream flow.
- Made the expected source-signature target explicit: adding `bank_response_features` as a first-class bake texture should bump the river bake source signature to `14`, rebake main and obstacle-test resources, and export Phase 0C review-camera captures before visible-water or WaterSystem consumption.
- Updated `NEXT_SESSION_HANDOFF.md` with a concise next-session start message, added the Phase 0C review references, and aligned the handoff start checklist with the narrowed hard-boundary/protrusion alpha channel.

### Phase 0C Bank And Boundary Response

- Added a fifth river bake texture, `bank_response_features`, to `RiverBakeData`.
- Documented `bank_response_features` channel metadata:
  - `r`: bank friction / drag response.
  - `g`: outside-bend wet pressure / bank-pillow candidate.
  - `b`: inside-bend shallow / deposition candidate.
  - `a`: hard-boundary / protrusion response candidate.
- Added `bank_response_feature_mask_filter.gdshader` and `FilterRenderer.apply_bank_response_feature_mask()` to derive the semantic bank/boundary layer from terrain contact, shallow depth, protrusion/intersection, curve grade/energy, bend bias, and local downstream flow.
- Kept Phase 0C debug-only. `river.gdshader` receives `i_bank_response_features` as an internal uniform but does not consume it for visible water, foam, normals, pressure, obstacle masks, or WaterSystem flow.
- Updated `river_debug.gdshader` and `debug_view_menu.gd` with Bank Friction / Drag, Outside-Bend Wet Pressure, Inside-Bend Deposition, and Hard-Boundary / Protrusion Response debug views.
- Added bank-response settings, source metadata, source-signature entries, and thresholded channel diagnostics.
- Bumped the river bake source signature to version `14`.
- Added `.codex-research/phase0c_bank_response_probe.gd`, `.codex-research/rebake_demo_phase0c_data.gd`, and `.codex-research/export_demo_phase0c_review_views.gd`.
- Updated local probes and inspection helpers for source signature version `14` and `bank_response_features`.
- Rebaked the main and obstacle-test river bake resources to signature version `14` with `bank_response_features`.
- Regenerated the main demo WaterSystem map after the main Phase 0C river rebake.
- Exported Phase 0C review-camera captures under `.codex-research/phase0c_demo_debug/`.

### Phase 4 Obstacle Feature Research

- Reviewed the current SDF-guided obstacle steering path, exported Phase 3 inspection images, and external river/flow-map references before planning the next behavior layer.
- Documented the recommendation to keep obstacle avoidance as the downstream-preserving baseline and add a separate obstacle feature mask texture for pillows, wake/eddy seeds, eddy-line shear, and side-deflection confidence.
- Updated `river-improvements-roadmap.md` with the proposed debug-only Phase 4A milestone, initial channel layout, validation expectations, and Phase 4 research notes.
- Updated `NEXT_SESSION_HANDOFF.md` so the next implementation pass starts from the mask-first Phase 4A plan rather than jumping directly into visible-water or reverse-flow changes.

### Phase 4A Obstacle Feature Masks

- Added a third river bake texture, `obstacle_features`, to `RiverBakeData`.
- Documented `obstacle_features` channel metadata:
  - `r`: upstream pillow / impact mask.
  - `g`: downstream wake / eddy seed mask.
  - `b`: eddy-line / shear mask.
  - `a`: side deflection / obstacle confidence mask.
- Added `obstacle_feature_mask_filter.gdshader` and `FilterRenderer.apply_obstacle_feature_mask()` to classify obstacle features from the existing SDF steering support, obstacle normal field, and downstream baseline flow.
- Updated `river_manager.gd` to bake, store, validate, save, and apply `obstacle_features` alongside `flow_foam_noise` and `dist_pressure`.
- Added obstacle feature bake settings, source metadata, channel stats, and source-signature entries.
- Bumped the river bake source signature to version `12`.
- Updated `river_debug.gdshader` and `debug_view_menu.gd` with real debug views for Pillow / Impact, Wake / Eddy Seed, Eddy-Line / Shear, and Obstacle Confidence.
- Kept Phase 4A debug-only: visible water, foam, and WaterSystem flow do not yet consume the obstacle feature masks.
- Added `.codex-research/phase4a_obstacle_features_probe.gd`, `.codex-research/rebake_demo_phase4a_data.gd`, and `.codex-research/export_demo_phase4a_debug_views.gd`.
- Updated local inspection helpers so saved bakes report obstacle feature metadata and channel stats.
- Rebaked the main and obstacle-test river bake resources to signature version `12` with `obstacle_features`.
- Regenerated the main demo WaterSystem map after the main Phase 4A river rebake.
- Exported Phase 4A demo inspection images under `.codex-research/phase4a_demo_debug/`.

### Phase 4B Obstacle Feature Mask Tuning Plan

- Updated `river-improvements-roadmap.md` with the Phase 4B debug-only tuning plan for narrowing pillow, wake/eddy seed, eddy-line/shear, and obstacle-confidence masks before visible-water or WaterSystem consumption.
- Documented the Phase 4A baseline capture findings, likely classifier causes, implementation plan, and validation targets for the next obstacle-feature pass.

### Phase 4B Obstacle Feature Mask Tuning

- Tuned the debug-only `obstacle_features` classifier while keeping visible water, foam, normals, pressure, and WaterSystem flow consumption unchanged.
- Kept broad SDF support for obstacle flow steering, but changed obstacle feature classification to use the tighter collision/dilated support and normal field.
- Passed `bank_response_features` into the obstacle feature mask filter so ordinary bank friction suppresses wake/confidence unless hard-boundary or protrusion response supports obstacle behavior.
- Shortened and gated wake / eddy seed generation, narrowed the lateral wake sample, reduced side-facing contribution, and added a low-value wake gate to remove faint classifier haze.
- Rebuilt eddy-line / shear from lateral wake-edge differences and removed the previous filled `wake * side_deflection` term.
- Thresholded obstacle confidence so it acts as an envelope around meaningful pillow, wake, shear, and side-deflection evidence instead of flooding the river.
- Added `.codex-research/phase4b_obstacle_features_probe.gd`, `.codex-research/rebake_demo_phase4b_data.gd`, and `.codex-research/export_demo_phase4b_debug_views.gd`.
- Updated local probes for the new source signature version.
- Bumped the river bake source signature to version `15`.
- Rebaked and saved the main and obstacle-test river bake resources to signature version `15`.
- Regenerated and saved the main demo WaterSystem bake after the main river rebake.
- Exported Phase 4B review captures under `.codex-research/phase4b_demo_debug/`.
- Final inspected main-demo image stats: wake / eddy seed above `0.05` dropped to about `18.54%`, eddy-line / shear to about `20.60%`, and obstacle confidence to about `40.16%`.

### Grade / River Energy Bake

- Implemented the initial Phase 2 grade/energy bake layer.
- Added a curve-derived grade/energy source image that samples river height drop over a short downstream lookahead, smooths neighboring UV2 tiles, normalizes the result to `0..1`, and writes it into `dist_pressure.b`.
- Updated `RiverBakeData` channel metadata so `dist_pressure.b` is now documented as curve-derived grade/energy data instead of a reserved neutral channel.
- Added grade/energy bake metadata, bake settings, and source-signature entries for lookahead, smoothing radius, reference grade, neutral value, and occupied-tile diagnostics.
- Bumped the river bake source signature to version `10` so bakes without the grade/energy channel are treated as stale.
- Added `.codex-research/phase2_grade_energy_probe.gd` to verify that descending curves bake visible grade/energy while flat curves remain neutral.

### Grade / River Energy Consumption

- Added `flow_grade_energy` to the river, debug, and WaterSystem flow shaders so `dist_pressure.b` can increase final flow force while staying bounded by `flow_max`.
- Added `foam_energy_bias` to the river and debug shaders so grade/energy can modestly increase foam activity on steeper stretches.
- Passed `flow_grade_energy` through the WaterSystem flow render path so generated physics flow maps match the visible river flow.
- Mirrored material parameter edits into the debug material so final-flow and foam debug views reflect current river tuning.
- Added `.codex-research/phase2_grade_energy_consumption_probe.gd` to verify shader uniforms and wiring.
- Rebaked the main `Demo.tscn` river bake resource to signature version `10` so `Water_River.river_bake.res` now includes curve-derived grade/energy in `dist_pressure.b`.
- Regenerated `WaterSystem.water_system_bake.res` after the main demo river rebake so buoyancy/runtime flow uses the same grade-aware field as the visible river.
- Added local ignored Phase 2 inspection helpers for explicit console-run bake saving, WaterSystem sampling validation, and exported debug-view screenshots.

### Bend Bias Bake And Consumption

- Implemented the initial Phase 3 bend-intelligence layer.
- Added a curve-derived bend-bias source image that samples XZ-plane curvature over a short upstream/downstream lookahead, smooths neighboring UV2 tiles, writes a cross-river inside/outside gradient, and packs it into `dist_pressure.a`.
- Defined the `dist_pressure.a` sign convention: neutral is `0.5`, values above `0.5` mean outside-bend/faster side, and values below `0.5` mean inside-bend/slower side.
- Updated `RiverBakeData` channel metadata so `dist_pressure.a` describes curve-derived bend bias instead of a reserved neutral channel.
- Added bend-bias bake metadata, bake settings, and source-signature entries for lookahead, smoothing radius, reference angle, sign convention, and occupied-tile diagnostics.
- Bumped the river bake source signature to version `11` so bakes without bend-bias data are treated as stale.
- Added `flow_bend_bias` to the river, debug, and WaterSystem flow shaders so the bend channel can conservatively speed outside bends and slow inside bends while staying bounded by `flow_max`.
- Passed `flow_bend_bias` through the WaterSystem flow render path so generated physics/system flow uses the same bend-aware force field as visible water.
- Updated WaterSystem flow-render fallbacks so unset `flow_grade_energy` and `flow_bend_bias` material parameters use the same defaults as the visible river shader.
- Added `.codex-research/phase3_bend_bias_probe.gd` to verify straight, mirrored-bend, S-bend, metadata, shader, and WaterSystem wiring behavior.
- Rebaked the main and obstacle-test river bake resources to signature version `11` so they include curve-derived bend-bias data in `dist_pressure.a`.
- Regenerated `WaterSystem.water_system_bake.res` after the main demo river rebake so buoyancy/runtime flow uses the same bend-aware field as the visible river.
- Added local ignored Phase 3 inspection helpers for explicit console-run bake saving and exported bend-bias debug screenshots.

### Obstacle Flow Steering

- Added SDF-guided obstacle steering to the downstream-baseline collision flow path.
- The bake now builds a broader steering-only collision influence field for flow direction, while keeping the existing collision support map for foam, pressure, and distance data.
- Tuned the steering field to start before direct obstacle contact:
  - SDF steering radius: `0.95` UV2 tiles.
  - SDF steering blur: `0.08` UV2 tiles.
  - Upstream lookahead: `0.30` UV2 tiles.
  - Upstream lookahead strength: `0.75`.
- Added a minimum downstream alignment of `0.45` so obstacle avoidance cannot rotate river flow into pure bank-outward horizontal motion.
- Changed obstacle weighting so side-facing bank normals do not get default steering influence. Steering now responds mainly to obstacles that face into the downstream flow path.
- Added a final blur after obstacle avoidance to reduce thin alternating-vector artifacts in the baked flow map.
- Bumped the river bake source signature to version `8` so older obstacle-flow bakes are treated as stale.

### Debug Flow Arrows

- Reworked the debug flow-arrow view to make the arrows smaller and easier to read.
- Each arrow now samples one flow vector at the center of its display cell, preventing a single arrow glyph from deforming across multiple flow directions.
- Increased debug arrow density to `8` arrows per UV2 tile.
- Added a debug glyph scale of `0.55` so arrows occupy only part of each cell.

### Bake Resources Updated

- Rebaked and saved the demo river bake resources:
  - `res://waterways_bakes/Demo/Water_River.river_bake.res`
  - `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- Kept the active generation behavior as `downstream_baseline_collision_support`.
- Updated `Demo.tscn` and `Demo_obstacle_flow_test.tscn` to reference the refreshed bake resources cleanly.

### Validation Notes

- Validation scene: `Demo_obstacle_flow_test.tscn`.
- Collision hits remain stable at `7,477 / 65,536` pixels.
- Occupied river flow remains active with `0.0%` near-neutral flow.
- Final obstacle-test average occupied flow vector: approximately `(0.0010, 0.2272)`.
- Strong lateral flow with low downstream movement is now `0.0%`.
- Minimum downstream flow stayed positive at approximately `0.0824`.
- Phase 1 and Phase 2 probe scripts passed after the main demo rebake.
- Phase 3 bend-bias probe passed after the implementation and demo rebake.
- The refreshed main demo WaterSystem map passed `validate_generated_map_sampling()` with active alpha-covered flow and the expected saved source-river path.
- The main and obstacle-test river bake resources reloaded as signature version `11` with `bend_bias_baked=true`; the legacy-test bake remains intentionally stale at signature version `5`.

### Files Changed

- `river_manager.gd`
- `filter_renderer.gd`
- `shaders/filters/obstacle_avoidance_flow_filter.gdshader`
- `shaders/river.gdshader`
- `shaders/river_debug.gdshader`
- `shaders/system_renders/system_flow.gdshader`
- `system_map_renderer.gd`
- `CHANGELOG.md`
- `river-improvements-roadmap.md`
- `NEXT_SESSION_HANDOFF.md`
- Phase 3 local validation and export helpers under `.codex-research`
- Demo scene bake references and saved river/WaterSystem bake resources
