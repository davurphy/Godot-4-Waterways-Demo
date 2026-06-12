# Spec: River Object Artifacts

## Summary

Objects that sit on, intersect, or visually overlap the river (and the banks
themselves) produce blocky, speckled distortions in foam, wake, and flow
near the waterline. Investigation (`research.md`) traced the visible
artifact to bake-texel-scale aliasing of binary water-role classification,
compounded by winner-takes-all contact-source selection, a dead overhang
exemption in the hard-obstacle bake, and the absence of any way to exclude
decorative geometry from the bake. This feature removes those causes in
three phases: sampler quality fixes, a continuous height-field bake format
with late classification, and a geometry participation policy.

## Current Truth

- Status: **Crack artifact RESOLVED — user-confirmed 2026-06-11.** Root
  cause: runtime stagnation-centerline shear in
  `apply_contextual_flow_slide` (boundary-tangent sign flip, gated by
  pillow-capable hard-boundary contexts, maximized for head-on flow);
  fixed by fading the slide with tangent alignment (river + river_debug
  shaders). Remaining open items: squiggly-band status not separately
  confirmed (foam-pass comb is the queued suspect if they resurface);
  Phase 3 (opt-out policy) not started. Also landed this session:
  Phases 0–2 bake quality, cross-tile bleed fix (probe-verified),
  refraction smooth-blend + textureGrad mip fix + avoidance tangent fade
  (all kept as hardening; each exonerated as the crack's cause along the
  way).
- Source of truth for open work: `plan.md` "Next planned implementation
  slice"
- Last meaningful decision: tile-aware filtering via shared
  `atlas_column_clamp.gdshaderinc` with `atlas_columns` uniform (default
  1.0 = no-op for non-atlas consumers); vertical passes left unclamped
  because vertically adjacent tiles are world-adjacent steps
- Known deferred items: wetted-footprint classification for overhangs/wide
  tops (Phase 3 optional follow-up); shader fleck-noise retuning; adaptive
  supersampling (only if budgets tighten)
- Current non-goals that are easy to accidentally reopen: raising default
  bake resolution; eddy-line changes (screenshots show that channel is flat
  near the artifact and ruled out)

## Goals

- Terrain-contact, bank-response, and obstacle feature masks render as
  smooth ramps at the default 256² bake atlas — no single-texel
  classification flips, stair-step blocks, or bilinear cross-fringes at
  waterlines.
- Contact-source provenance (HTerrain vs physics) transitions smoothly
  instead of flipping per texel.
- Geometry hanging above the water (cliff overhangs, wide rock tops,
  bridges) does not bake as a hard flow obstacle in either collision-bake
  path.
- Users can exclude specific geometry from the water bake without changing
  its physics layers (decorative props keep their gameplay collision).
- Close-up foam/wake near obstacles and banks shows no blocky envelope; the
  visible pattern scale is set by shader detail textures, not bake texels.

## Non-Goals

- Raising the default `baking_resolution` (rejected: quadratic cost, only
  shifts the aliasing one octave down).
- Physically simulating wetted footprints, water displacement, or runtime
  fluid response (the ripple system covers runtime response).
- Changing eddy-line behavior (`obstacle_features` B was flat near the
  reproduced artifact).
- Retuning the artistic look of foam/wake beyond what mask smoothness
  requires.
- Migrating or rebaking existing user bakes automatically; a rebake is an
  acceptable requirement after the format change, with a clear version
  check.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`.
- Known scene/data/context facts: demo river bakes a 256² UV2 atlas
  (`baking_resolution = 2`, texture = 2^(6+res)); one unfiltered vertical
  ray per texel; every demo collider (HTerrain, cliffs, rocks) sits on
  collision layer 1, the layer the river bakes against; full code trace in
  `research.md`.
- User-reported observations: artifacts strongest near obstacles, banks
  also affected; visible as dappled/distorted foam near rocks; screenshots
  of "cliff2" in `artifacts/`.
- Agent confidence in the premise: high — debug-view screenshots show the
  same bake-texel stair-step signature across protrusion, provenance, wake
  seed, and final flow strength views, matching the code-level mechanisms.
- Possible expected-behavior explanations ruled out: eddy-line channel
  (flat); shader gate over-amplification (gates multiply/suppress; they
  leak weak masks but do not create the block pattern).
- Clarification or challenge already raised with the user: none pending —
  fix direction was reviewed and accepted.

## Users and Workflows

### User Story: Level designer places props near a river

As a level designer, I want rocks, cliffs, and decorative props near or in
the river to produce believable, smooth water response (or none, if I opt
them out), so that close-up shots near the waterline look correct without
hand-tuning the bake.

Acceptance criteria:

- Placing a collider-bearing prop in the river produces smooth pillow/wake/
  foam response with no blocky halo at default bake settings.
- Adding the documented opt-out (group/metadata) to a prop and rebaking
  removes all of its water response.
- A prop or cliff section overhanging the water (no surface intersection)
  produces no hard-obstacle response beneath it.

### User Story: Add-on maintainer reasons about bake data

As an add-on maintainer, I want the bake to store continuous physical
quantities (signed height delta, confidence) instead of pre-derived masks,
so that downstream filters and shaders can classify at sample resolution
and future features reuse the same field.

Acceptance criteria:

- Terrain-contact bake channels are documented as continuous fields with
  stated remapping, and all mask derivation happens in shaders.
- Bake data carries a format version; loading an old format produces a
  clear "rebake required" path, not silent misrender.

## Functional Requirements

- FR1: `generate_terrain_contact_feature_map` samples each texel with N×N
  (configurable, default ≥ 2×2) jittered vertical rays and averages the
  resulting height field before any classification.
- FR2: Contact-source selection blends HTerrain and physics heights across
  a smooth crossfade band instead of winner-takes-all with a 2 cm epsilon.
- FR3: The direct-shape path of `generate_collisionmap` applies the same
  overhang exemption as the physics fallback (an intersection wholly above
  the water surface whose underside faces down does not mark an obstacle).
- FR4: The terrain-contact map stores signed height delta (remapped to
  0–1) + confidence; contact/shallow/protrusion ramps are computed in the
  consuming filter shaders and river/debug shaders from the interpolated
  delta using the existing band constants.
- FR5: `collect_raycast_collision_shapes`, `collect_hterrain_samplers`, and
  the bake physics ray queries honor a per-object opt-out (node group or
  metadata, e.g. `waterways_ignore`), and the convention is documented.
- FR6: Debug views continue to expose raw contact/shallow/protrusion/
  provenance equivalents after the format change (derived live from the
  height field).
- FR7: Bake resources record a bake format version; version mismatch
  surfaces a user-visible rebake prompt/warning.

## Non-Functional Requirements

- Maintainability: classification thresholds defined once (shared constants
  / uniforms), not duplicated between GDScript and shaders.
- Performance: default-quality bake time for the demo river increases by no
  more than ~3× in the contact pass (supersampling), with a documented
  quality setting to reduce it; runtime shader cost increase limited to the
  arithmetic of deriving masks from one texture sample (no extra texture
  fetches beyond current).
- Visual quality: no visible bake-texel block structure in foam/wake/flow
  debug or normal views at the demo's close-up camera distances.
- Godot 4.6+ compatibility: no use of removed/legacy APIs; physics queries
  via `PhysicsRayQueryParameters3D` as today.
- Editor usability: opt-out workflow usable from the editor without code;
  bake progress reporting unchanged.
- Runtime usability: no editor-only state required at runtime; existing
  public sampling APIs unchanged.
- Extensibility: the baked height field is consumable by future features
  (e.g. wetted-footprint tests, shoreline effects) without re-raycasting.

## Add-on Boundary

Editor authoring responsibilities:

- Debug View menu entries for the derived contact/shallow/protrusion views
  and provenance; bake controls unchanged; opt-out via standard Godot
  groups/metadata editing.

Bake/data responsibilities:

- Terrain-contact texture channel layout (height delta + confidence),
  collision map, feature masks, bake format version metadata.

Runtime responsibilities:

- River shader derives masks from the height field; flow sampling and
  buoyancy APIs unchanged.

Shared code must not depend on:

- Demo scene hierarchy, HTerrain specifically (keep duck-typed sampler),
  one material preset, or editor-only nodes at runtime.

## Data and Extension Model

Users should be able to:

- Exclude any `CollisionObject3D` (or subtree) from water bakes via group/
  metadata without touching physics layers.
- Choose bake layers per river (`baking_raycast_layers`, as today).
- Tune contact band constants per river via existing settings dictionary.

Extension points:

- Opt-out group/metadata name (documented constant).
- Terrain height samplers remain duck-typed (`_looks_like_hterrain`).

Override rules:

- Opt-out beats layer match. Layer mask remains the inclusion filter.

Shared systems must not hard-code:

- Scene node names, demo assets, or a specific terrain plugin class.

## Acceptance Tests

- AT1: Rebake demo river; capture Protrusion, Provenance, Wake Seed, and
  Final Flow Strength debug views at the cliff2 camera; no single-texel
  red/yellow cross fringes or stair-step blocks (compare against
  `artifacts/` baseline).
- AT2: Provenance view shows a gradual blend zone at the cliff base, not a
  two-tone per-texel checkerboard.
- AT3: Construct an overhang test (collider above water, no intersection):
  collision map hit count under the overhang is 0 in both direct-shape and
  physics paths; with the collider lowered to intersect the surface, hits
  appear.
- AT4: Add `waterways_ignore` to one demo rock; rebake; its pillow/wake/
  foam response disappears while neighbors are unchanged.
- AT5: Bake with old-format data present: editor surfaces a rebake-required
  message; no silent misclassification.
- AT6: Demo bake time at default quality within the performance budget
  above; numbers recorded in validation.md.

## Visual Validation Requirements

- Before/after screenshot pairs at the exact cliff2 angles in `artifacts/`
  for: normal view (foam), protrusion, provenance, wake seed, final flow
  strength.
- One additional obstacle mid-stream (smooth_rock) and one plain bank
  section with no object, to confirm bank artifacts are also resolved.
- Probe scripts under `probes/` following the existing feature-probe
  pattern, including a sampler-divergence probe (direct-shape vs physics
  result under an overhang).

## Performance Requirements

- Contact bake pass: ≤ ~3× current wall-clock at default supersampling on
  the demo river; quality setting documented.
- River shader: no additional texture samples per fragment for mask
  derivation versus current (terrain-contact already sampled).
- No change to runtime memory beyond identical texture sizes.

## Open Questions

- Opt-out mechanism: node group vs metadata key (group is editable in the
  Node dock and queryable cheaply; metadata survives instancing more
  predictably). Decide in Phase 3.
- Should supersampling be adaptive (refine only disagreeing texels) at
  default quality, or fixed 2×2 with adaptive as a later optimization?
- Channel packing for FR4: keep four channels (delta, confidence, spare,
  spare) vs preserving legacy-readable contact in R during a transition.

## Resolved Questions

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Is the artifact caused by shader gate over-amplification? | No — gates multiply/suppress; contamination originates in bake inputs | 2026-06-11 | `research.md` finding 7 |
| Is the eddy-line channel involved? | No — flat near reproduced artifact | 2026-06-11 | `artifacts/eddy line shear mask` screenshot |
| Is raising bake resolution the fix? | No — rejected; quadratic cost, aliasing persists one octave down | 2026-06-11 | `research.md` |
| Is an architectural rewrite needed? | No — sampler fixes + bake-format change + participation policy within existing pipeline | 2026-06-11 | `research.md` "Recommended fix direction" |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-11 | Three-phase fix: sampler quality → continuous height-field bake / late classification → participation policy | Matches evidence ranking; cheap reversible wins first; format change is the durable fix |
| 2026-06-11 | Store signed height delta + confidence instead of derived masks | Interpolating height is meaningful; interpolating near-binary masks is the proven artifact source |
| 2026-06-11 | Overhang exemption: physics up/down rays decide first, direct-shape test is fallback-only | Physics rays carry facing info; the analytic intersector does not, and teaching it facing would duplicate fragile geometry code |
| 2026-06-11 | Supersampling default fixed 2×2 (no adaptive) | Measured 2.9× total bake wall — within the ≤3× budget; adaptive deferred |
| 2026-06-11 | Phase 2 = per-tile edge smoothing of classified fields; raw height-delta format rejected | Heights are discontinuous at object silhouettes — interpolating them sweeps through the contact/shallow bands and would create fake fringe rings; smoothing classified masks is silhouette-safe, keeps formats, and removed 97–99% of residual flips |
| 2026-06-11 | Clamp filter-pass offset reads to the fragment's atlas column (horizontal passes only) | Probe-confirmed cross-tile bleed: dilate/blur/feature searches read atlas-adjacent tiles that are world-distant river stretches; vertical neighbors are world-adjacent so vertical passes stay unclamped |
| 2026-06-11 | Replace binary refraction depth-test fallback with a smooth validity blend (+ mip clamp) | The hard branch flickers along screen-space geometry silhouettes (offset wiggles with water normals), drawing dashed shape-tracing contours; runtime artifact independent of bake data. User re-test: did not resolve the dashes — kept as a hardening fix, refraction exonerated as the cause |
| 2026-06-11 | Sample flow-advected pattern textures with textureGrad (continuous base-UV gradients) | The flow phase wraps along iso-lines of the per-pixel phase noise; UVs jump by a full flow vector across those organic curves, exploding screen derivatives and forcing tiny mips — dashed contour-shaped lines, worst in fast flow near obstacles, immune to all bake changes. User re-test: did not resolve the crack — kept as hardening |
| 2026-06-11 | Fade contextual flow slide (and obstacle-avoidance steering) by tangent alignment near stagnation centerlines | Hard tangent sign flips shear the advected pattern in opposite lateral directions across a texel-quantized line through every hard-boundary obstacle — the static jagged "crack" + squiggly compressed-pattern bands. Probe showed the baked flow smooth, so the runtime slide (applied after flow sampling, gated by pillow-capable hard-boundary contexts) is the mechanism |
