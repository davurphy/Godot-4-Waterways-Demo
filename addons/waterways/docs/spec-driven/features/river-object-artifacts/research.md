# River Object Artifacts — Code Investigation Findings

Status: code-level investigation + first visual evidence (screenshots of
"cliff2" in `artifacts/`). Line references are to the current
`river-object-artifacts` branch.

## Summary

The diagnostic frame in `symptoms and initial suspects.md` asked whether each
object is classified with the correct water role (ignored / visual-only /
shallow / hard obstacle / bank protrusion). The answer from the code is that
**no explicit classification mechanism exists**. An object's water role is
emergent from three vertical-ray heuristics applied per bake pixel, all of
which sample every `CollisionShape3D` whose parent body matches
`baking_raycast_layers` (default layer 1 — the same default layer every
`StaticBody3D` in the demo uses). Several of those heuristics classify
geometry as water-relevant when its wetted footprint is small or absent.

Findings ranked by suspected contribution to the observed artifacts:

| # | Finding | Confidence | Code |
|---|---------|------------|------|
| 1 | Bake-texel aliasing: contact/protrusion classification flips per texel at ~256² atlas resolution, producing blocky stair-step masks at every waterline | **Confirmed by screenshots** | `Demo.tscn` (`baking_resolution = 2`), `river_manager.gd:1693-1700`, `water_helper_methods.gd:1336-1367` |
| 2 | Protrusion mask marks full "hard boundary" for any collider top 0.2–0.75 m above the surface, regardless of wetted footprint | Confirmed mechanism; screenshots show it firing along the cliff waterline | `water_helper_methods.gd:1415-1449`, `river_manager.gd:275-282` |
| 3 | Visible foam speckle = coarse blocky wake/bank masks × high-frequency fleck noise in the river shader | **Confirmed by screenshots** | `shaders/river.gdshader` (`wake_foam_fleck_bias`, `wake_fleck_noise_scale = 42`) |
| 4 | Hard-obstacle bake tests the full 10 m air column above the water with no overhang exemption in the preferred (direct-shape) path | Confirmed asymmetry in code; scene impact not yet isolated | `water_helper_methods.gd:1286-1305` |
| 5 | No layer/role separation: every default-layer collider is simultaneously obstacle + terrain-contact + protrusion source | Confirmed | `water_helper_methods.gd:311-333`, `Demo.tscn`, `assets/Cliff.tscn`, `assets/SmoothRock.tscn` |
| 6 | Dilation/blur inflate misclassified footprints well beyond the object | Confirmed mechanism, severity depends on 1–5 | `river_manager.gd:1841-1861` |
| 7 | Shader gates leak weak masks but mostly suppress rather than amplify | Secondary | `shaders/river.gdshader:304-330`, `obstacle_feature_mask_filter.gdshader` |

## Visual evidence (artifacts/, cliff2, 2026-06-11)

User observation: artifacts are strongest near obstacles but banks show them
too; the visible symptom is distorted, dappled foam near the rock.

- **`normal view.png`** — a wide band of speckled "leopard print" foam hugs
  the cliff base. The speckle frequency is the shader's fleck noise; the
  band's blotchy envelope is much coarser — bake-texel scale.
- **`protrusion intersection (terrain_contact_features B).png`** — isolated
  red texels with yellow bilinear cross/diamond fringes, stair-stepping
  along the waterline. This is per-texel binary flipping of the protrusion
  classification, not a smooth field. On steep bank geometry the entire
  protrusion ramp (0.03→0.20 m) spans less than one texel laterally, so the
  mask cannot resolve and aliases to scattered full-on texels.
- **`contact source provenance (terrain_contact_features A).png`** — two
  flat tones with blocky stair-step boundaries: provenance (physics 0.5 vs
  HTerrain 1.0) flips texel-by-texel exactly where the blocks appear,
  confirming the physics-override path (`source_selection_epsilon` race)
  is what's flipping near the cliff.
- **`wake eddy seed mask (obstacle_features G).png`** — the wake region
  downstream of the cliff is built of visible rectangular texel blocks with
  a feathered fade. The protrusion texels above act as "hard boundary" and
  boost the wake seeds (`hard_gate = mix(0.45, 1.0, hard_boundary)`).
- **`eddy  line shear mask (obstacle features b).png`** — empty (flat zero)
  around the cliff: the eddy-line channel is **ruled out** as a contributor
  here.
- **`final flow strength.png`** — blocky stair-stepped flow suppression
  hugging the cliff; same texel structure propagated into flow.

Why banks show the same artifact: the cliff *is* the bank at this spot. The
bank-response filter weights contact (0.85), shallow (0.65), and protrusion
(0.90) from the same coarse terrain-contact texture, so every waterline gets
the same per-texel classification flips regardless of whether an "object" is
present. Obstacles are worse because protrusion → hard boundary additionally
*boosts* wake there.

Resolution math: `baking_resolution = 2` → atlas is 2^(6+2) = **256×256**
for the entire river (`river_manager.gd:1700`). The atlas is divided into
`_uv2_sides ≈ ceil(sqrt(steps))` columns of per-step tiles, so one step of
river (several meters long and the full river width) gets roughly a
40–60 px tile — on the order of 10–20 cm of water per texel longitudinally
and a similar scale across width, sampled by a single unfiltered vertical
ray per texel. Up close, single-texel features are tens of centimeters wide
on screen.

## Detail

### 1. Full-column hard-obstacle test (overhangs become flow blockers)

`generate_collisionmap` (`water_helper_methods.gd:1255`) marks a pixel as a
hard obstacle when **any** collision shape intersects the vertical segment
from the water surface up to `baking_raycast_distance` above it (default and
demo value: **10.0 m**):

- Line 1286–1289: the direct-shape test
  (`_intersects_collision_shapes_segment(direct_collision_shapes,
  real_pos_up, real_pos)`) marks the pixel white on **any** intersection of
  the full column and `continue`s — it short-circuits the rest of the loop.
- Line 1291–1305: the physics-raycast fallback contains an explicit overhang
  exemption: if the **up**-ray from the water surface first hits a
  downward-facing surface (`result_up.normal.y < 0`, i.e. the underside of
  something hanging above the water), the pixel is *not* marked.

Because cliffs and rocks in the demo are ordinary `CollisionShape3D`s under
`StaticBody3D` (so `direct_collision_shapes` is non-empty), the direct path
runs first for every pixel and the overhang exemption is effectively dead
code. Consequences:

- A cliff face leaning over the river, a wide rock top overhanging the
  water, a bridge, or any prop within 10 m above the surface bakes as a hard
  flow obstacle across its entire projected footprint.
- This contaminates the dilated collision map, the steering normal map, flow
  pressure, foam, and (via the support texture) the pillow/wake/eddy feature
  masks — i.e. essentially every object-adjacent visual.

This directly matches suspects "vertical ray hits even when only an upper
part intersects the sample" and "overhangs / wide rock tops interpreted as
flow blockers".

### 2. Protrusion band classifies near-surface tops as hard boundary

`generate_terrain_contact_feature_map` (`water_helper_methods.gd:1309`)
writes per-pixel contact (R), shallow (G), protrusion (B), confidence (A).
Heights come from `_sample_physics_contact` (line 1415), which casts from
`water_y + 0.75` down to `water_y − 1.50` and keeps the **highest** hit
(both via direct shape segment tests and a physics ray). Defaults
(`river_manager.gd:275-282`):

- `RIVER_TERRAIN_CONTACT_PROTRUSION_FULL_HEIGHT = 0.20` → a hit 20 cm above
  the water writes **full** protrusion.
- Physics hits (confidence 0.5) override HTerrain heights whenever higher
  than terrain + 0.02 (`source_selection_epsilon`), so any object lying on
  or near the surface replaces the terrain classification.

The protrusion channel is consumed as **hard boundary**:
`obstacle_feature_mask_filter.gdshader:103-105`
(`hard_boundary = max(bank_response.a, terrain_contact.b)`), where it
*boosts* wake (`hard_gate = mix(0.45, 1.0, hard_boundary)`) and feeds the
pillow contact gates; `bank_response_feature_mask_filter` also weights it at
0.90 (`RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT`). So a decorative object
whose top skims the 0.2–0.75 m band above the water — even with zero wetted
footprint — generates pillow/wake/eddy responses across its whole top
footprint.

Note the asymmetric resolution of the two samplers: the wide-top problem in
finding 1 affects the *obstacle* map at 10 m sensitivity, while the
terrain-contact sampler uses a 0.75 m band. An object 1–10 m above water is
an obstacle but produces no contact/protrusion; an object 0.2–0.75 m above
water produces both. Neither checks whether the object actually touches the
water.

### 3. No role classification, single shared layer

`collect_raycast_collision_shapes` (`water_helper_methods.gd:311`) filters
only by `collision_layer & raycast_layers` (plus enabled/PhysicsBody3D
checks). `_get_bake_collision_root` (line 873) scans the whole scene from
the river's owner. In the demo:

- `Demo.tscn` river: `baking_raycast_layers = 1`.
- `HTerrain`: `collision_layer = 1`.
- `assets/Cliff.tscn`, `assets/SmoothRock.tscn`: `StaticBody3D` with no
  `collision_layer` override → default layer 1, `ConcavePolygonShape3D`.

So terrain, cliffs, and rocks are indistinguishable to the bake, and any
future decorative prop with default collision settings silently joins the
bake. There is no per-object opt-out (group, metadata, or layer convention)
and no documentation steering users to separate layers.

### 4. Footprint inflation by dilation/blur

`river_manager.gd:1841-1861`: the binary collision map is dilated by
`baking_dilate / uv2_sides`, and the obstacle-avoidance steering support is
dilated to at least `0.45` tiles and blurred before the normal map is
derived. Foam derives from the dilated texture too. Inflation is by design
(seam margins, smooth steering), but it multiplies the area affected by any
misclassification from findings 1–3, which is why artifacts read as "halos"
around objects up close while looking acceptable at distance (suspect 6).

### 5. Shader gates are secondary

The visible-mask gates in `shaders/river.gdshader` (e.g.
`pillow_visual_mask`, line 304) chain multiplicative smoothstep gates —
they suppress rather than amplify. Amplification factors exist
(`pillow_strength = 1.15`, `wake_eddy_line_strength = 1.85`) and confidence
gating starts low (`RIVER_OBSTACLE_FEATURE_CONFIDENCE_START = 0.14`), so
weak contaminated masks do leak through, but the contamination originates in
the bake inputs, not the gates. Tuning gates without fixing findings 1–3
would trade object artifacts for suppressed legitimate features.

## What this rules in/out (per the suspects list)

- "Decorative objects included in collision sampling" — **in**: anything on
  layer 1 with a collider participates (finding 3).
- "Collision layers may not separate props from water-affecting geometry" —
  **in**: demo uses one layer for everything; no convention exists.
- "Masks classify too much geometry as water-relevant" — **in**: findings 1
  and 2 are the concrete mechanisms.
- "Vertical ray hits from upper/decorative parts" — **in**: finding 1
  (10 m column, dead overhang exemption) and finding 2 (0.75 m band).
- "Shader gates over-amplify weak masks" — **partially in**: leak, not
  amplify (finding 5).
- "Valid at distance, too noisy close up" — explained by findings 1–4
  compounding; not an independent cause.

## Verification plan (next steps)

Reproduction and raw-view snapshots are done (see Visual evidence). The
evidence reorders the priorities: the dominant close-up artifact is
**resolution-limited, unfiltered classification** (findings 1–3), with the
classification-breadth problems (findings 4–5) determining *where* it fires.

1. **A/B bake resolution:** rebake cliff2 area with `baking_resolution`
   raised (2 → 4, i.e. 256 → 1024). If blocks shrink proportionally and the
   foam speckle envelope tightens, finding 1 is confirmed as dominant.
   (Not a fix by itself — cost grows quadratically and the CPU sampler loop
   is per-pixel — but the cleanest causal test.)
2. **Supersample / soften the contact sampler:** prototype N×N (e.g. 2×2 or
   3×3) jittered vertical rays per texel in
   `generate_terrain_contact_feature_map`, averaging contact/shallow/
   protrusion. Expectation: stair-step blocks become smooth ramps even at
   256², and provenance flips (the 0.5/1.0 confidence race at
   `source_selection_epsilon`) average out instead of flipping whole texels.
3. **Blend, don't switch, sources:** the provenance screenshot shows the
   physics-vs-hterrain selection flipping per texel. Replace the
   winner-takes-all selection (`water_helper_methods.gd:1351-1355`) with a
   height-weighted blend, or widen the epsilon into a smooth crossfade band.
4. **Decouple fleck noise from blocky masks:** in `river.gdshader`, the
   visible speckle is fleck noise gated by the coarse wake/bank masks.
   Verify by zeroing `wake_foam_fleck_bias` / pillow foam biases around
   cliff2 — the leopard pattern should vanish while the blocky envelope
   remains. Any mask-resolution fix should be validated against this view.
5. **Probe finding 4 (overhang exemption):** bake-time probe comparing the
   direct-shape segment result vs. physics up/down-ray result under the
   cliff overhang; then A/B applying the `up_hit_frontface`-style exemption
   to the direct path.
6. **A/B the protrusion band:** rebake with `raycast_up_offset` reduced
   (0.75 → ~0.1) to quantify finding 2's share.
7. Then design the durable fixes: sampler supersampling + source blending
   (bake quality), and role/classification (layer convention, per-object
   opt-out, wetted-footprint test) for which geometry participates at all.

## Recommended fix direction

The pipeline shape (CPU ray sampling → feature maps → GPU filter passes →
shader gates) is sound. The problem is *what* gets baked, not *how* the
pipeline flows. Three tiers, ordered by sequencing — only the second is
arguably architectural, and it is a contained data-format change, not a
pipeline rewrite.

### Tier 1 — sampler quality (cheap, surgical, do first)

- **Supersample the terrain-contact sampler.** 2×2 or 3×3 jittered vertical
  rays per texel, averaged, in `generate_terrain_contact_feature_map`.
  Turns per-texel binary flips into ramps even at the current 256² atlas.
  CPU cost is ×4–9 on a slow loop, so consider adaptive refinement (only
  refine texels whose neighbors disagree).
- **Blend contact sources instead of winner-takes-all.** The provenance
  screenshot shows the physics-vs-HTerrain selection flipping per texel
  over a 2 cm epsilon (`water_helper_methods.gd:1351-1355`). Replace with a
  height-weighted crossfade band.
- **Port the overhang exemption into the direct-shape path** of
  `generate_collisionmap` (`water_helper_methods.gd:1286-1289`). The
  correct logic already exists in the physics fallback right below it
  (`up_hit_frontface`); the direct path short-circuits past it.

### Tier 2 — bake continuous fields, classify late (the durable fix)

Store the underlying continuous quantity instead of derived masks: the
terrain-contact map currently bakes contact/shallow/protrusion, all three
derived from one scalar (signed height delta between water surface and
highest hit) plus confidence. Bilinearly interpolating a near-binary mask is
exactly what produces the cross-fringes and stair-steps. Instead bake the
**signed height delta** (remapped to 0–1) + confidence, and compute the
contact/shallow/protrusion ramps in the filter shaders and river shader at
sample time from the interpolated height. Height is meaningful to
interpolate; classifications are not (same principle as SDF text). This
resolves the 3 cm→0.20 m protrusion ramp smoothly at current resolution and
removes most pressure to raise `baking_resolution`. Touches: bake channel
semantics, `obstacle_feature_mask_filter` / `bank_response_feature_mask_filter`
inputs, river/debug shader gate inputs, bake-data versioning.

### Tier 3 — participation policy (which geometry bakes at all)

- Documented collision-layer convention plus a per-object opt-out (node
  group or metadata such as `waterways_ignore`) honored by
  `collect_raycast_collision_shapes` and the physics queries' exclusion
  list. Constitution rule 2 (reusable add-on, no scene assumptions) argues
  for groups/metadata over hardcoded names.
- Optional later: wetted-footprint test so overhangs/wide tops with no
  water contact are classified visual-only.
- Shader fleck-noise gating is cosmetic tuning once masks are smooth.

**Explicitly rejected as a fix:** raising `baking_resolution` alone —
quadratic bake cost and it only pushes the same aliasing one octave down.

## Open lead after Phases 0–2: cross-tile bake bleed (2026-06-11) — CONFIRMED AND FIXED

Outcome: the synthetic obstacle-at-tile-edge probe
(`probes/object_artifact_tile_bleed_probe.gd`) confirmed the bleed —
phantom distance/pillow/wake response (dist edge-band mean 0.58, pillow
max 0.96, wake max 0.87) appeared in the atlas-neighbor tile five world
steps away. Fixed by clamping all horizontal/directional offset reads in
the filter passes to the fragment's atlas column
(`shaders/filters/atlas_column_clamp.gdshaderinc`); the re-run probe
measures exactly zero in the neighbor tile while legitimate same-tile and
downstream responses are unchanged. Details and numbers: `validation.md`
"Cross-tile bleed fix". The analysis below is preserved as written before
the fix.

Phases 0–2 (supersampling, source crossfade, overhang exemption, per-tile
edge smoothing) drove the texel-flip metrics to near zero (provenance flips
4364 → 47, protrusion hard-edge flips 3051 → 79) and the user confirmed the
artifacts are less severe — but still present. The remaining artifacts are
therefore NOT explained by classification aliasing. User hypothesis: bake
bleed somewhere in the architecture.

That hypothesis has concrete candidates — the GPU filter passes are
**tile-unaware** while the UV2 atlas packs world-disjoint river segments
into adjacent tiles (steps stack down each column; the bottom of column N
is NOT world-adjacent to the top of column N+1):

- `apply_dilate` (dilate_filter_pass1-3) expands the collision map across
  the whole atlas: an obstacle near a tile edge dilates into the
  atlas-neighbor tile — a different stretch of river. The obstacle-
  avoidance steering map dilates even wider (0.45 tiles + blur).
- `apply_blur` / `apply_vertical_blur` (blur_pass1/2) are atlas-global
  Gaussians: flow, foam, and pressure blur across tile boundaries.
- `obstacle_feature_mask_filter.gdshader` performs directional UV searches
  in raw atlas space: wake sampling reaches up to `wake_length_uv * 1.15`
  (0.7 tiles base length) upstream, pillow contact searches offset by flow
  direction, eddy-line lateral taps — near tile edges these read the
  wrong tile's data.
- `obstacle_avoidance_flow_filter` upstream lookahead (0.08 tiles) ditto.
- `add_margins` + `synchronize_uv2_logical_edge_bands` protect the outer
  image edges and logical step continuations, but none of the in-filter
  offset reads above are clamped or redirected to the world-correct
  neighbor tile.
- The terrain-contact smoothing added in Phase 2 IS per-tile clamped and
  is not a bleed source.

Suggested verification for the next session: a probe that bakes a
synthetic river with one obstacle placed hard against a tile edge and
checks whether wake/foam/flow response appears in the atlas-adjacent
(world-distant) tile; plus per-tile-boundary difference metrics on the
filtered outputs (flow_foam_noise, obstacle_features) rather than on the
raw terrain contact this feature has measured so far. If confirmed, the
fix direction is making the filter passes tile-aware (clamp or remap
offset reads to logical neighbors), mirroring what the
river-flowmap-seams feature did for edge continuity.
