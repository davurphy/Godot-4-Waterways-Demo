# River Improvements Roadmap

Created: 2026-05-26

This roadmap captures the river-generation direction discussed for the Waterways addon. The guiding idea is to keep the system practical for Godot: use the existing baked flow, foam, pressure, distance, and system maps as the foundation, then add richer behavior layers for grade, bends, banks, hard boundaries, obstacles, pillows, and eddies.

## Current Foundation

The addon already has the main pieces needed for a believable river system:

- River meshes are generated from curves.
- Flow and foam maps are baked per river.
- A system map can combine river height and flow for buoyancy and object drift.
- The water shader uses flow-map-driven normal animation.
- Obstacle avoidance already steers the current around collision-derived shapes.

Important existing files:

- `river_manager.gd`: river mesh generation, flow and foam baking, bake metadata.
- `water_helper_methods.gd`: mesh, UV2 atlas, collision, and flow helper methods.
- `filter_renderer.gd`: GPU-style bake filter pipeline.
- `shaders/river.gdshader`: visible river material.
- `shaders/system_renders/system_flow.gdshader`: system-map flow bake for physics.
- `shaders/filters/obstacle_avoidance_flow_filter.gdshader`: current obstacle steering pass.

## Design Principle

Treat river behavior as a layered flow field:

1. Terrain/world geometry contact and shallow-bed masks from explicit height/intersection sampling.
2. Base downstream flow from the curve.
3. Grade/energy from elevation change.
4. Bend bias from curve curvature.
5. Obstacle deflection from collision/SDF data.
6. Feature masks for pillows, eddies, foam, turbulence, and pressure.
7. Final flow written to the same data used by rendering and buoyant objects.

This avoids full fluid simulation while keeping the result inspectable, tunable, and fast enough for authoring.

## Phase 0: Terrain And World Geometry Contact

Goal: detect where the river intersects, touches, or closely rides over terrain and other world geometry before changing flow behavior.

Status: Phase 0A initial bake implemented, Phase 0B review is complete for the current milestone, and Phase 0C has an initial semantic bank/boundary implementation. The addon bakes `terrain_contact_features` as saved raw contact data and derives `bank_response_features` as saved semantic bank/boundary response data. Phase 5A now consumes these two layers for final-flow damping and hard-boundary guidance, while foam, pillow visuals, obstacle wakes, and eddies remain deferred.

The current river bake already samples the generated river mesh in UV2 space, converts each sample back to world space, and raycasts against collision layers. In the demo, HTerrain has collision enabled on layer `1`, and the river bake also raycasts layer `1`, so terrain can already contribute to the generic collision/support texture. The missing piece is semantic contact data: the bake does not yet distinguish terrain just below the river, terrain intersecting the river surface, shallow riverbed areas, or rocks/cliffs protruding into the water.

Phase 0A implementation direction:

- Add a separate debug-first `terrain_contact_features` texture instead of overloading `flow_foam_noise`, `dist_pressure`, or `obstacle_features`.
- Make `terrain_contact_features` a first-class `RiverBakeData` texture with channel metadata, a neutral black import profile entry, bake validation, material wiring, and external-resource saving.
- Keep older or missing terrain-contact bakes safe by providing a neutral black fallback until the river is intentionally rebaked.
- Bump the river bake source signature after the new texture and thresholds are written, expected first target version: `13`.
- Reuse or factor the existing UV2-to-world sampling path from `generate_collisionmap()` so the new mask aligns exactly with the river bake atlas. Avoid copying the per-pixel barycentric walk into a second divergent implementation if it can be shared.
- For HTerrain, prefer direct height sampling:
  - Convert the river sample world position into terrain map space with `HTerrain.world_to_map()`.
  - Sample the heightmap through `HTerrainData.get_interpolated_height_at()`.
  - Treat the sampled height as raw terrain height, then convert it back through `HTerrain.get_internal_transform()` before comparing world Y values.
  - Guard against missing terrain data and record whether the sample came from HTerrain.
- For generic world geometry, keep a physics fallback:
  - Raycast from slightly above the river surface down past the shallow-water depth threshold, not only to the water surface.
  - Record nearest-hit height and normal data for later feature classification.
  - Treat generic physics hits as lower confidence than direct HTerrain height samples.
- Derive masks from signed height delta, where `delta = water_y - terrain_or_hit_y`:
  - near zero means near-surface contact. Treat "shoreline" as a later derived interpretation, because true shoreline also needs bank/edge context.
  - small positive values mean shallow water over terrain or geometry.
  - negative values mean terrain or geometry protrudes through or above the river surface.
- Add explicit tuning constants and record them in bake metadata and the source signature:
  - near-contact band and fade distance.
  - shallow-water full depth and fade depth.
  - protrusion full height and fade height.
  - HTerrain-vs-physics source confidence values.
- Add diagnostics for each channel, including occupancy above thresholds such as `0.05`, `0.25`, and `0.50`, because faint interpolation noise can make raw nonzero counts misleading.
- Start with debug views only. Do not let this affect visible water, foam, pressure, obstacle masks, or WaterSystem flow until the masks are readable.

Suggested initial texture layout:

- `terrain_contact_features.r`: near-surface contact mask, neutral `0.0`.
- `terrain_contact_features.g`: shallow-depth mask, neutral `0.0`.
- `terrain_contact_features.b`: terrain/world protrusion or intersection mask, neutral `0.0`.
- `terrain_contact_features.a`: source/provenance mask, neutral `0.0`; categorical values are `0.5` for generic physics fallback and `1.0` for direct HTerrain sampling. This is not a true confidence heatmap.

Phase 0A validation targets:

- The main demo and obstacle-test river bakes reload as source signature version `13` with `terrain_contact_features_baked=true`. Implemented.
- Debug views show contact, shallow-depth, protrusion, and source/provenance masks without changing visible river water or WaterSystem flow. Implemented.
- Contact appears only where the river surface closely meets terrain or world geometry. Initial demo captures look localized along banks and near obstacles.
- Shallow-depth appears in low-clearance areas without filling the whole channel. Initial demo captures are readable and still debug-only.
- Protrusion appears where terrain, rocks, or cliffs rise through or above the river surface. Initial captures show localized protrusion/intersection regions, but this should be reviewed before visible use.
- Source/provenance distinguishes HTerrain samples from generic physics fallback samples. Implemented with `1.0` direct HTerrain and `0.5` physics fallback.
- Export Phase 0A debug captures before any visible-water consumption. Implemented under `.codex-research/phase0a_demo_debug/`.

Phase 0A notes:

- `terrain_contact_features` is now a fourth first-class `RiverBakeData` texture with neutral black fallback metadata.
- `water_helper_methods.gd` now shares the UV2-to-world sample reconstruction between the old collision map path and the new terrain-contact map path.
- Saved Phase 0A resources:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- Exported Phase 0A debug captures:
  - `.codex-research/phase0a_demo_debug/demo_near_surface_contact.png`
  - `.codex-research/phase0a_demo_debug/demo_shallow_depth.png`
  - `.codex-research/phase0a_demo_debug/demo_protrusion_intersection.png`
  - `.codex-research/phase0a_demo_debug/demo_contact_source_provenance.png`
- The current masks remain debug-only. Do not feed them into foam, pressure, obstacle masks, visible water, or WaterSystem flow until the captures have been reviewed.

Phase 0B review and tuning:

Goal: make the Phase 0A terrain/world-contact masks reliable enough to become context for shoreline, wet-bank, shallow-bed, obstacle, and later foam work, without consuming them in visible water or WaterSystem flow yet.

Current review read:

- The raw data path is in place through `RiverBakeData`, `WaterHelperMethods.generate_terrain_contact_feature_map()`, and `river_manager.gd` bake/source-signature wiring.
- `river.gdshader` receives `i_terrain_contact_features` but does not use it for visible water, foam, pressure, normals, obstacle masks, or WaterSystem flow. This boundary remains in place after Phase 0B.
- The Phase 0B review-camera captures show contact and shallow-depth bands mostly near banks and obstacles, with protrusion/intersection remaining localized around geometry in the rendered views.
- The current terrain-contact thresholds are accepted for now. Do not change contact band/fade, shallow full/fade depth, protrusion fade/full height, or source selection epsilon until a later feature pass shows a concrete need.
- Source/provenance is categorical and now uses the `source_provenance` stats key in current saved demo bakes. `RiverBakeData.normalize_source_metadata()` also migrates older nested `source_confidence` stats keys when older resources are applied.
- External references support keeping this as stable bake data first: river speed and behavior vary with banks, bed, friction, bends, and obstacles; Valve-style flow-map work favors inspectable low-resolution maps that can later be shared with gameplay/physics. Godot depth-texture shoreline foam remains a later visual-only option, not the authoritative saved mask.

User-overhead review finding:

- In the editor screenshot of `terrain_contact_features.a`, the white/red/yellow spline handles and segment lines are the editor river gizmo overlay, not baked terrain-contact data.
- The `terrain_contact_features.a` texture itself is categorical source provenance, not a confidence heatmap:
  - `1.0` means direct HTerrain sample.
  - `0.5` means generic physics fallback sample.
  - `0.0` means no source.
- The previous `Contact Source / Confidence` debug view used the same red-green gradient as scalar masks, so source switching, interpolation, and editor spline/tile structure could look like terrain-contact features. This was misleading for Phase 0B review and is now fixed by the provenance view.

Phase 0B completed plan:

1. Keep Phase 0B debug-only. Complete.
2. Use the review camera rig in `Demo.tscn` (`Phase0B Review Cameras`) to inspect the river from whole-river, overhead bend/obstacle, and low oblique viewpoints. Complete.
3. Export better review material: current camera and Phase 0B overhead/oblique cameras. Complete for the current milestone; atlas-style captures remain optional if a later ambiguity appears.
4. Rename the `Contact Source / Confidence` debug view to `Contact Source / Provenance`. Implemented.
5. Render source/provenance with discrete colors and nearest/texel-style sampling instead of a continuous red-green gradient, so categorical values do not blur across UV tile or segment edges. Implemented.
6. Optionally add a separate real contact-confidence/problem debug view later, based on source reliability or source disagreement, instead of overloading `terrain_contact_features.a`.
7. Tune only terrain-contact thresholds if needed: contact band/fade, shallow full/fade depth, protrusion fade/full height, and source selection epsilon. No tuning needed for the current milestone.
8. Add a derived shoreline-candidate debug view only after the raw masks are accepted. Derive it from contact plus bank/edge context, not by renaming `terrain_contact_features.r`.
9. If terrain-contact generation thresholds or source semantics change, bump the river bake source signature to `14`, rebake main and obstacle-test resources, and update the changelog/roadmap/handoff.
10. After Phase 0B reads cleanly, use the reviewed terrain-contact data as context for Phase 0C bank/boundary response first, then Phase 4B obstacle feature mask tuning.

Research notes:

- This should be a bake-time map, not primarily a water-shader depth trick. Godot depth-texture shoreline foam can be useful as a later visual-only option, but the addon needs a stable bake that can also feed debug views, saved resources, and eventually WaterSystem flow.
- Valve-style production flow-map work supports this low-resolution, inspectable-map direction: bake or author flow/mask fields, use procedural shader detail on top, and share the same final flow data with gameplay/physics when possible.
- SDF or volume-based obstacle-flow methods, such as Houdini-style potential-flow workflows, are useful references for later world-geometry-aware vector fields. Phase 0A should stay simpler: terrain contact and shallow-depth masks first.

Known critique resolutions:

- Resource schema risk: add the fourth texture deliberately across `RiverBakeData`, river material wiring, debug shader uniforms, editor validation, external bake storage, and source signatures.
- Height-space risk: convert HTerrain's raw interpolated height back to world space before calculating `delta`.
- Shoreline ambiguity: keep channel R named as near-surface contact for now; derive shoreline later from contact plus bank/edge context.
- Fallback ray depth risk: cast far enough below the water surface to classify shallow bed clearance, not only current-surface intersections.
- Source/provenance ambiguity: channel A is categorical source data, not scalar confidence. It should be displayed with discrete colors and nearest/texel-style sampling during Phase 0B.
- Performance risk: share the existing UV2-to-world sample walk instead of adding another independent atlas traversal.
- Stale milestone risk: Phase 0B is complete for the current milestone; the next milestone is Phase 0C depth-aware bank and boundary response before Phase 4B obstacle feature mask tuning.

Phase 0C depth-aware bank and boundary response:

Goal: derive a debug-only bank/boundary behavior layer from accepted Phase 0 terrain-contact data before changing visible water, foam, normals, obstacle masks, or WaterSystem flow.

User-observed shortcomings:

- Water can appear to emerge from, spill out of, or push outward from solid terrain and river banks. Banks should contain, slow, and guide the river rather than read as active sources of obstructed water.
- Flow direction can over-anticipate large terrain obstructions. The upstream river sometimes turns away too early or too strongly instead of staying drawn downstream until it reaches the boundary.
- Some water appears to travel through terrain unimpeded when the visible surface and normal motion continue across shallow or intersecting terrain.

Desired behavior:

- Water speed and surface activity should depend on depth and boundary context.
- Deep, open, straight channel water can move quickly with active normals.
- Shallow or bank-adjacent water should become calmer and more friction-damped while still following the terrain or bank tangent.
- Around hard protrusions, the main current should stay downstream-biased, slide along the obstruction, and leave a calmer buffer or wake behind it.
- Ordinary banks should mostly guide and slow water. In-channel protrusions should split, slow, and disturb the flow locally.
- Outside river bends can support stronger pressure, wet-bank detail, and mild pillowing when bend bias, grade, and contact agree.

Design rule:

- Depth controls energy.
- Contact controls damping.
- Protrusions control local sliding and wakes.
- Curvature controls outside-bank pressure.

Phase 0C review findings:

- The debug-only derived-layer approach is the right next step. `terrain_contact_features` should remain the raw measured contact/depth/protrusion/provenance data, while `bank_response_features` should describe how that contact should behave.
- Do not treat raw bank contact as an obstacle wake source. The user screenshots and Phase 4A mask review both point to the same risk: broad bank/contact regions can flood wake, shear, and obstacle-confidence masks if ordinary banks and hard protrusions are not separated first.
- Keep Phase 0C visual-consumption-free. The reported visible issues with arrows, normals, and surface detail moving through terrain should first be explained by debug masks, then addressed in a later conservative shader/WaterSystem pass.
- `bank_response_features.a` should be narrowed to hard boundary / protrusion response. Eddy candidacy should be derived later from hard-boundary response plus downstream shadow/wake context, not baked into a broad Phase 0C alpha channel.
- Phase 0C should not depend on the current broad `obstacle_features` masks until Phase 4B tightens them. Use terrain contact, shallow depth, protrusion/intersection, grade/energy, bend bias, and local downstream flow first.
- If Phase 0C adds `bank_response_features` as a first-class texture, the next bake source signature target should be `14`, because resource validity changes even if visible water remains unchanged.

Implementation direction:

1. Keep Phase 0C debug-only at first.
2. Do not consume `terrain_contact_features` raw in the visible river shader or WaterSystem flow.
3. Derive a new semantic bank/boundary layer, likely `bank_response_features`, instead of overloading the full packed `flow_foam_noise`, `dist_pressure`, `obstacle_features`, or `terrain_contact_features` channels.
4. Suggested `bank_response_features` layout:
   - `r`: bank friction / drag.
   - `g`: outside-bend wet pressure / bank-pillow candidate.
   - `b`: inside-bend shallow / deposition candidate.
   - `a`: hard-boundary / protrusion response candidate.
5. Build the derived layer from:
   - Phase 0 near-surface contact.
   - Phase 0 shallow depth.
   - Phase 0 protrusion/intersection.
   - curve-derived grade/energy.
   - curve-derived bend bias.
   - local downstream flow direction.
   - later, tightened obstacle masks if needed after Phase 4B.
6. Treat ordinary bank contact as damping and boundary-following, not obstacle wake generation.
7. Treat hard protrusions and terrain intersections as local slide-around and wake/buffer candidates.
8. Use the accepted Phase 0B review cameras to inspect the derived masks before any visible-water consumption.
9. If Phase 0C adds a new texture, material uniform, source metadata, or bake-signature inputs, bump the river bake source signature to `14`, rebake the main and obstacle-test resources, and update the changelog/handoff.

Implementation plumbing checklist if `bank_response_features` is added:

- Add it as a first-class `RiverBakeData` texture with neutral black fallback metadata and channel descriptions.
- Wire it into river and debug materials as an internal uniform without visible-water use.
- Add debug menu entries for bank friction, outside-bend wet pressure, inside-bend shallow/deposition, and hard-boundary/protrusion response.
- Add source metadata, bake settings, source-signature entries, and thresholded channel diagnostics.
- Rebake and save the main and obstacle-test river bake resources, then export review-camera captures under a Phase 0C output folder.

Phase 0C validation targets:

- Deep open channel areas remain high energy.
- Shallow bank/contact areas show stronger drag and calmer response candidates without filling the whole channel.
- Hard protrusion/intersection regions are separable from ordinary banks.
- Outside-bend pressure candidates appear only where bend bias, grade, and contact support them.
- Bank/boundary masks explain the user-reported screenshots better than the old generic collision support path.
- Visible river water, foam, normals, pressure, obstacle masks, and WaterSystem flow remain unchanged until the debug layer is reviewed.

Phase 0C implementation notes:

- Added `bank_response_features` as a fifth first-class `RiverBakeData` texture with neutral black fallback metadata.
- Channel layout:
  - `bank_response_features.r`: bank friction / drag.
  - `bank_response_features.g`: outside-bend wet pressure / bank-pillow candidate.
  - `bank_response_features.b`: inside-bend shallow / deposition candidate.
  - `bank_response_features.a`: hard-boundary / protrusion response candidate.
- The bake derives the layer from `terrain_contact_features`, curve grade/energy, bend bias, and local downstream flow. It explicitly does not consume the current broad `obstacle_features` masks.
- The visible river shader receives `i_bank_response_features` only as an internal uniform. It does not consume this data for water, foam, normals, pressure, obstacle masks, or WaterSystem flow.
- The debug shader and menu expose four Phase 0C views, and review-camera captures were exported under `.codex-research/phase0c_demo_debug/`.
- The main and obstacle-test river bakes were rebaked to source signature version `14` with `bank_response_features_baked=true`. The main WaterSystem bake was regenerated after the main river rebake.

Phase 0C research notes:

- USGS Manning roughness references support the simplified game rule that roughness, hydraulic radius/depth, and slope determine channel velocity. For Waterways, shallow/contact-heavy areas can reasonably become more friction-damped while deeper graded areas keep more energy.
- USGS and NPS meander references support the existing bend model: outside bends carry stronger/faster flow and erosion pressure, while inside bends are slower and depositional. This supports separate outside-bend pressure and inside-bend shallow/deposition candidates.
- Valve's production flow-map approach still supports the roadmap direction: keep low-resolution, inspectable maps as the source of truth, then layer shader detail and physics flow on top after debug review.
- Godot 4.6 screen/depth-texture shader features remain useful for later visual-only shoreline/edge polish, but they should not replace saved bake data for Phase 0C because the addon needs stable resources and WaterSystem-compatible fields.

## Phase 1: Debug And Channel Clarity

Goal: make the existing data easy to inspect before adding more behavior.

Status: implemented as the initial debug/channel pass.

- Confirm and document current packed channel meanings:
  - `flow_foam_noise.rg`: packed signed flow vector.
  - `flow_foam_noise.b`: foam mask.
  - `flow_foam_noise.a`: phase/noise offset.
  - `dist_pressure.r`: distance/bank influence.
  - `dist_pressure.g`: pressure/support.
  - `dist_pressure.b`: curve-derived grade/energy feature channel, neutral 0.
  - `dist_pressure.a`: curve-derived signed bend-bias feature channel, neutral 0.5; values above 0.5 mark the outside-bend side and values below 0.5 mark the inside-bend side.
- Add debug views for:
  - raw flow direction.
  - final flow force.
  - foam.
  - distance.
  - pressure.
  - grade/energy.
  - bend bias.
  - pillow mask.
  - eddy mask.
- Keep all new feature outputs visible in `river_debug.gdshader`.

Phase 1 notes:

- The debug menu now distinguishes raw packed flow from effective flow after force modifiers.
- The steepness/grade-proxy debug view uses the same surface-steepness scale as the water and system-flow shaders.
- Phase 1 reserved `dist_pressure.b` for grade/energy and `dist_pressure.a` for bend bias, so later phases could write those channels without redesigning the debug UI. Phase 2 writes grade/energy into B, and Phase 3 writes curve-derived bend bias into A.
- Pillow and eddy debug modes are currently reserved placeholders until their feature masks are generated.

## Phase 2: Grade / River Energy Layer

Goal: make steep stretches naturally faster and more active.

Status: initial bake and consumption layers implemented. The river bake now derives grade/energy from curve height drop over a short downstream lookahead, smooths it between neighboring UV2 tiles, normalizes it to `0..1`, and writes it to `dist_pressure.b` for the existing Grade / Energy debug view. The water and WaterSystem flow shaders can now use this channel as a bounded flow-force boost, and the water/debug shaders can use it as a modest foam bias.

Use river-curve elevation as the first implementation, not full terrain-bed sampling.

- Compute grade per curve sample using upstream/downstream height difference over a short lookahead distance.
- Smooth grade along the river so the flow does not flicker between segments.
- Normalize it into a "river energy" value.
- Use energy to influence:
  - base flow force. Implemented for water visuals and WaterSystem flow through `flow_grade_energy`.
  - foam generation. Implemented for water/debug foam mix through `foam_energy_bias`.
  - obstacle impact strength.
  - pillow intensity.
  - eddy-line turbulence.
  - standing-wave likelihood later.

Current behavior still considers the slope of the generated water surface in the water shader and system-flow shader. The explicit baked grade/energy layer now adds an inspectable, tunable force term that can be shared by later features.

Phase 2 notes:

- Grade/energy is currently baked per occupied UV2 tile, matching the river-step atlas layout used by flow/support maps.
- Visual flow force, foam bias, and system-map force now consume the grade/energy channel; obstacle impact, pillows, and eddies should consume it in later passes.
- `dist_pressure.b` is no longer just reserved neutral data for new bakes. Phase 2 introduced it at source signature version `10`; after Phase 3, the main demo and obstacle-test river bakes have been refreshed to source signature version `11`. Older legacy bakes remain stale until intentionally rebaked.

## Phase 3: Bend Intelligence

Goal: make curves read like natural rivers.

Status: initial bake and consumption layers implemented. The river bake now derives bend bias from XZ-plane curve curvature, smooths it along neighboring UV2 tiles, writes a cross-river inside/outside gradient into `dist_pressure.a`, and documents the positive-outside sign convention in bake metadata. The water and WaterSystem flow shaders can use this channel through `flow_bend_bias` to subtly speed the outside bend and slow the inside bend while preserving the base downstream flow.

- Compute curve curvature and bend direction along the river.
- Push faster/deeper current toward the outside bend. Implemented for water visuals and WaterSystem flow through `flow_bend_bias`.
- Slow the inside bend. Implemented as the negative side of the signed bend-bias channel.
- Increase pressure and wet-bank visual strength on the outside bend.
- Reserve inside bends for future gravel bars, sandbars, shallower color, and lower foam.

Implementation idea:

- For each river sample, derive tangent and curvature from neighboring curve samples in plan view so elevation grade does not read as bend curvature.
- Convert curvature into a cross-river bias value, with neutral center flow, positive outside-bank bias, and negative inside-bank bias.
- Bake that bias into `dist_pressure.a` and consume it as a conservative force modifier for visible and WaterSystem flow.
- Keep the effect subtle enough that the base downstream flow remains legible.

Phase 3 notes:

- `dist_pressure.a` is no longer just reserved neutral data for new bakes. Bakes with source signature version `11` contain curve-derived bend bias.
- The initial implementation intentionally changes flow force rather than adding lateral bend pull. A later pass can add a small cross-current vector once debug captures show the speed gradient is readable and not confusing.
- Pressure/wet-bank and inside-bank sediment visuals remain future work because the current river shader only uses pressure/support as a flow-force input.

## Phase 4: Obstacle Feature Upgrade

Goal: turn rocks and cliffs into feature generators, not only avoidance shapes.

Status: Phase 4A debug-mask layer implemented. The current obstacle pass is still treated as a downstream-preserving steering baseline, not as the place to add pillows or eddy reversal. It uses collision-derived support, a broader SDF-style steering field, obstacle normals, and local downstream flow to deflect current around rocks while keeping a minimum downstream component. That is useful and should stay stable.

The current packed river bake textures are already spoken for:

- `flow_foam_noise.rg`: packed signed flow vector.
- `flow_foam_noise.b`: foam mask.
- `flow_foam_noise.a`: phase/noise offset.
- `dist_pressure.r`: distance/bank influence.
- `dist_pressure.g`: pressure/support.
- `dist_pressure.b`: curve-derived grade/energy.
- `dist_pressure.a`: curve-derived bend bias.

Because the existing packed channels are occupied, Phase 4A adds a separate `obstacle_features` texture instead of overloading `flow_foam_noise` or `dist_pressure`. The Pillow Mask, Wake / Eddy Seed, Eddy-Line / Shear, and Obstacle Confidence debug views now read from that texture.

The existing obstacle avoidance pass should stay as the baseline current-deflection layer. Add separate masks for:

- Upstream impact zone.
- Side deflection zones.
- Downstream wake zone.
- Pillow zone.
- Eddy seed zone.
- Eddy-line/shear zone.

Implementation idea:

- Continue using collision-derived support/distance maps.
- Use obstacle normals, signed distance support, and local flow direction to classify obstacle regions.
- Keep downstream-preserving avoidance for the main current.
- Add a later eddy pass that is allowed to reverse flow locally.

Phase 4A milestone:

1. Add an obstacle feature mask texture to `RiverBakeData`. Implemented as `obstacle_features`.
2. Bake it from the same collision/SDF support and normal fields used by obstacle steering. Implemented through `obstacle_feature_mask_filter.gdshader`.
3. Start debug-only: wire the feature texture into `river_debug.gdshader` and update the existing Pillow Mask and Eddy Mask views before changing visible water. Implemented with four debug views.
4. Initial channel layout:
   - `obstacle_features.r`: upstream pillow / impact mask.
   - `obstacle_features.g`: downstream wake / eddy seed mask.
   - `obstacle_features.b`: eddy-line / shear mask.
   - `obstacle_features.a`: side deflection / obstacle confidence mask.
5. Bump the river bake source signature after the new feature texture is written and document neutral channel values in bake metadata. Implemented at source signature version `12`.
6. Export debug captures for the main demo and obstacle-flow test before applying the masks to foam, normals, pressure, or physics flow. Main demo debug captures were exported under `.codex-research/phase4a_demo_debug/`.

After the Phase 5 actual flow-map pass, the first pillow pass should be conservative: use the pillow mask for pressure/normal/foam accents, and keep eddies visual/debug-only until the seed and eddy-line masks read clearly. True reverse or circulating eddy flow should remain a later pass so the WaterSystem flow field does not become confusing.

Phase 4A notes:

- `waterways_bakes/Demo/Water_River.river_bake.res` and `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res` were rebaked to source signature version `12` and now contain `obstacle_features`.
- The initial masks are useful for inspection, but wake/eddy seed, eddy-line/shear, and obstacle confidence remain broad. Tune these masks with the user before using them for visible foam, normals, pressure, or WaterSystem flow.
- The main demo WaterSystem map was regenerated after the main river rebake. Phase 4A does not yet consume obstacle features in WaterSystem flow.

Phase 4B planned tuning:

Goal: tune and validate the obstacle feature masks before they affect visible river rendering or WaterSystem physics. This should remain a debug-only classifier pass.

Current baseline from the Phase 4A demo debug captures and bake inspection:

- Pillow / impact is readable and already forms useful hot spots, but should be kept mainly on upstream obstacle faces.
- Wake / eddy seed is too broad; the current main demo bake reports an occupied-sample average around `0.243`.
- Eddy-line / shear is much too filled in; the current main demo bake reports an occupied-sample average around `0.356` and visibly forms broad sheets instead of boundary lines.
- Obstacle confidence floods the channel; the current main demo bake reports an occupied-sample average around `0.533`.

Likely cause:

- `obstacle_feature_mask_filter.gdshader` currently classifies all feature channels from the broad SDF-style steering support. That support is correct for early flow deflection, but it is too wide for semantic feature masks such as pillow faces, downstream wakes, and eddy-line boundaries.
- The current wake function takes a max over several upstream samples but does not strongly taper by distance or gate the result to a narrow downstream obstacle shadow.
- The current eddy-line term includes a `wake * side_deflection` fill contribution, which makes shear read as a filled wake/channel condition instead of a thin boundary.
- Obstacle confidence currently takes the max of broad wake, broad shear, and side-deflection terms, so it inherits the over-wide channels.

Implementation plan:

1. Split the classifier inputs conceptually:
   - use tighter collision/dilated support for obstacle body, pillow, and near-face detection.
   - keep the broader SDF steering support for flow-avoidance and only limited side-influence context.
2. Tighten pillow / impact:
   - keep the core test as support times upstream-facing-normal.
   - raise support and facing thresholds if needed so pillows stay mostly on upstream rock/wall faces.
3. Rebuild wake / eddy seed:
   - classify the current pixel as downstream of an obstacle by sampling upstream along the local flow direction.
   - apply a clear downstream distance taper.
   - reduce side-facing contribution so side banks do not paint wake across the channel.
   - shorten initial wake length from `0.90` tiles toward roughly `0.60` to `0.75` tiles unless visual comparison suggests otherwise.
4. Rebuild eddy-line / shear:
   - derive it from lateral differences or gradients of the wake mask.
   - remove or greatly reduce the filled `wake * side_deflection` contribution.
   - use narrower lateral samples so the result becomes thin boundary bands along the wake edges.
5. Rebuild obstacle confidence:
   - make it an envelope around meaningful pillow, wake, shear, and near-obstacle side-deflection areas.
   - threshold tiny values to zero so confidence does not mark the whole river channel.
6. Bump the river bake source signature after changing mask generation and document the tuned constants in source metadata and source signatures.
7. Rebake and save the main demo and obstacle-test river bake resources.
8. Re-export the four debug views under a Phase 4B output folder and compare them against the Phase 4A captures.

Validation targets:

- Pillow / impact appears mainly on upstream faces of rocks and walls.
- Wake / eddy seed sits behind obstacles as tapered downstream zones instead of covering too much river.
- Eddy-line / shear appears as thinner boundary zones around wake edges.
- Obstacle confidence marks obstacle-influenced areas without flooding the whole channel.
- Inspection helpers should report thresholded occupancy, such as pixels above `0.05`, `0.25`, and `0.50`, because raw nonzero counts are too sensitive to faint interpolation noise.
- Visible river water, foam, normals, pressure, and WaterSystem flow should remain unchanged during Phase 4B.

Phase 4B implementation notes:

- Implemented the debug-only classifier tuning pass.
- The broad SDF steering support remains the flow-avoidance input, while `obstacle_features` now classifies from the tighter collision/dilated support and normal field.
- `obstacle_feature_mask_filter.gdshader` now receives `bank_response_features` context. Bank friction suppresses wake/confidence from ordinary banks unless hard-boundary/protrusion response supports obstacle behavior.
- Wake / eddy seed now uses a shorter `0.70` tile wake length, a narrower `0.11` tile lateral sample, reduced side-facing contribution, downstream tapering, hard-boundary gating, and a low-value wake gate.
- Eddy-line / shear now derives from lateral wake-edge differences and no longer uses the old filled `wake * side_deflection` term.
- Obstacle confidence is thresholded from pillow, wake, shear, and side-deflection evidence so faint classifier noise no longer marks most of the river.
- Bumped the river bake source signature to version `15` and recorded the tuned obstacle constants in source metadata, bake settings, and the source signature.
- Rebaked and saved:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
  - `waterways_bakes/Demo/WaterSystem.water_system_bake.res`
- Exported Phase 4B review captures under `.codex-research/phase4b_demo_debug/`.
- Current main-demo image stats from the inspection helper:
  - pillow / impact: above `0.05` about `8.08%`, average about `0.037`.
  - wake / eddy seed: above `0.05` about `18.54%`, average about `0.079`.
  - eddy-line / shear: above `0.05` about `20.60%`, average about `0.150`.
  - obstacle confidence: above `0.05` about `40.16%`, average about `0.170`.
- Kept visible river water, foam, normals, pressure, and WaterSystem flow consumption unchanged. Phase 4B only changes the saved debug classifier texture.

## Phase 5: Actual Flow Map Improvement

Goal: improve the actual river vector and force field before adding pillow visuals or reverse/circulating eddies.

Status: Phase 5A contextual final-flow pass implemented, followed by a Phase 5B cleanup of the older SDF obstacle steering bake. The visible river shader, debug shader, and WaterSystem flow shader consume terrain-contact and bank-response context for conservative damping, pressure gating, and local hard-boundary sliding. The baked `flow_foam_noise.rg` source field has also been rebaked with bank-context-gated, less anticipatory SDF steering at source signature version `16`. The user reviewed the result in game and accepted it as the new baseline. Obstacle features still do not drive visible wake/pillow/eddy behavior.

Current reason:

- `flow_foam_noise.rg` is still mostly downstream baseline flow, now with bank-context-gated local SDF obstacle steering instead of the older broad upstream-anticipation pass.
- `dist_pressure.b` grade/energy and `dist_pressure.a` bend bias currently scale final flow force, but they do not create new local flow directions.
- Before Phase 5A, `terrain_contact_features`, `bank_response_features`, and `obstacle_features` were debug/semantic layers only. Phase 5A now consumes terrain contact and bank response for final flow, while obstacle features remain deferred for visible wake, pillow, foam, normal, pressure, and eddy behavior.
- The visible issues around water emerging from terrain, moving through banks, or turning away from obstructions too early should be handled by conservative bank/contact-aware flow behavior before feature effects are layered on top.

Phase 5 design rule:

- First make the shared final flow calmer and more boundary-aware.
- Do not make ordinary banks into wake, pillow, or eddy sources.
- Do not introduce reverse flow yet. Every correction should preserve a readable downstream component.
- Keep visible-water flow and WaterSystem flow numerically aligned. Any formula used by `river.gdshader` should also be represented in `river_debug.gdshader` and `system_renders/system_flow.gdshader`.
- Prefer a shader/system-flow consumption pass first. Only rebake `flow_foam_noise.rg` or change bake generation if the reviewed result proves the source vector field itself must change.

Phase 5A implementation direction: shared contextual final-flow pass.

1. Review the Phase 4B obstacle-feature captures together with the Phase 0C bank-response captures before changing behavior.
2. Add the missing context inputs to WaterSystem flow generation:
   - pass `terrain_contact_features` and `bank_response_features` from `system_map_renderer.gd` into `system_renders/system_flow.gdshader`.
   - pass `obstacle_features` only if the Phase 4B masks are accepted and the implementation needs obstacle confidence as an additional hard-boundary gate.
3. In `river.gdshader`, `river_debug.gdshader`, and `system_flow.gdshader`, derive the same local context terms:
   - `bank_drag` from `bank_response_features.r`.
   - `shallow_drag` from `terrain_contact_features.g`.
   - `protrusion_contact` from `terrain_contact_features.b`.
   - `hard_boundary` from `bank_response_features.a`, optionally reinforced by accepted `obstacle_features.a`.
   - `outside_wet_pressure` from `bank_response_features.g`.
   - `inside_deposition` from `bank_response_features.b`.
4. Apply damping before adding new visual effects:
   - reduce final flow force in bank-drag, shallow-depth, and inside-deposition areas.
   - clamp damping to a nonzero floor so water never freezes along ordinary banks unless a later pass explicitly supports still pools.
   - keep grade/energy able to push deep open-channel water after damping, but make shallow or contact-heavy regions resist that energy.
5. Gate the old pressure/support contribution:
   - ordinary bank contact should suppress `dist_pressure.g` force so banks read as containment and friction.
   - hard-boundary/protrusion regions may preserve a smaller local pressure term, because water pushing into a rock or wall should still look compressed.
   - this should affect force first, not foam or pillow visuals.
6. Add local hard-boundary sliding:
   - estimate a boundary normal from a texel-scale gradient of hard-boundary/protrusion/contact context.
   - derive the boundary tangent from that normal.
   - choose the tangent orientation that best agrees with the current downstream flow.
   - blend toward the tangent only where hard-boundary response is strong and local, then enforce a minimum downstream alignment.
   - keep or reduce the older upstream lookahead in obstacle avoidance if it is causing early over-steering; Phase 5 should feel like local contact guidance, not distant anticipation.
7. Keep bend behavior subtle:
   - use outside-bend wet pressure as a mild force/pressure preservation term after damping.
   - use inside-bend deposition as an additional calming term.
   - do not invent a strong lateral bend direction from the scalar packed bend-bias channel alone. If a later pass needs true bend-side vector steering, add an explicit baked vector/context signal and bump the source signature.
8. Mirror the same calculation into debug:
   - update `Final Flow Strength`, `Effective Flow`, and WaterSystem flow preview to reflect Phase 5.
   - add debug views only if needed for review, such as `Contextual Flow Damping`, `Pressure Gate`, and `Hard-Boundary Slide`.
9. Regenerate the main `WaterSystem.water_system_bake.res` after shader/system-flow changes so buoyancy previews match the visible river.
10. Keep pillow highlights, visible obstacle accents, foam accents, normal accents, and true reverse/circulating eddies deferred until this flow-map pass is reviewed.

Phase 5A implementation notes:

- Added conservative flow controls to `river.gdshader`, `river_debug.gdshader`, and `system_renders/system_flow.gdshader`: `flow_bank_drag`, `flow_shallow_drag`, `flow_inside_bend_drag`, `flow_pressure_bank_gate`, `flow_hard_boundary_pressure`, `flow_hard_boundary_slide`, `flow_hard_boundary_min_downstream`, and `flow_boundary_probe`.
- Visible, debug, and WaterSystem flow now derive the same context terms from `terrain_contact_features` and `bank_response_features`.
- Final force now gates old pressure/support in ordinary bank and shallow-contact areas, keeps a smaller pressure term at hard protrusions, resists grade/energy in shallow or bank-heavy context, and applies conservative contextual drag.
- Local hard-boundary sliding estimates a texel-scale boundary gradient, blends toward the downstream-facing tangent only near hard-boundary/protrusion context, and enforces a minimum downstream alignment.
- Debug `Effective Flow`, `Final Flow Strength`, `Flow Pattern`, and `Flow Arrows` now reflect the Phase 5A contextual flow calculation. Raw flow remains available through `Raw Flow Direction (flow_foam_noise RG)`.
- `system_map_renderer.gd` now passes terrain-contact and bank-response textures plus the Phase 5A tuning values into the WaterSystem flow renderer, with neutral/default fallbacks for older or custom materials.
- Added `.codex-research/phase5a_contextual_flow_probe.gd` to verify the new uniforms and wiring.
- Added `.codex-research/regenerate_demo_phase5a_system_map.gd` and regenerated `waterways_bakes/Demo/WaterSystem.water_system_bake.res` after Phase 5A.
- Phase 5A alone did not require a source-signature bump, but the later Phase 5B SDF steering cleanup changed baked `flow_foam_noise.rg`, so current river bakes are now source signature version `16`.

Suggested Phase 5 tuning controls:

- `flow_bank_drag`: strength of `bank_response_features.r` damping.
- `flow_shallow_drag`: strength of shallow-depth damping.
- `flow_inside_bend_drag`: extra calming for inside-bend/deposition candidates.
- `flow_pressure_bank_gate`: how strongly ordinary banks suppress the pressure/support term.
- `flow_hard_boundary_pressure`: how much pressure remains near hard protrusions.
- `flow_hard_boundary_slide`: blend amount for local tangent sliding.
- `flow_hard_boundary_min_downstream`: minimum downstream alignment after sliding.
- `flow_boundary_probe`: texel or UV distance used to estimate the local boundary gradient.

Defaults should be conservative and should keep existing no-context bakes visually close to the current result. Neutral black context textures must behave like Phase 4B behavior, not like a missing-data error.

Phase 5B implementation notes:

- The older broad SDF steering system was still producing bad source-flow directions in spots after Phase 5A, so Phase 5B tightened the bake-level obstacle steering path directly.
- `obstacle_avoidance_flow_filter.gdshader` now receives `bank_response_features` context. Ordinary bank friction suppresses SDF steering; hard-boundary/protrusion response preserves local steering.
- Reduced broad anticipation: lower steering strength, higher influence start, smaller SDF radius, shorter SDF blur, much shorter upstream lookahead, lower upstream strength, and higher minimum downstream alignment.
- Source metadata now records the algorithm as `bank_context_gated_local_sdf_steering`.
- Bumped the river bake source signature to `16` and recorded the new bank-context steering constants in source metadata, bake settings, and the source signature.
- Rebaked and saved:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
  - `waterways_bakes/Demo/WaterSystem.water_system_bake.res`
- Added `.codex-research/phase5b_sdf_steering_probe.gd` to verify ordinary-bank steering suppression and hard-boundary steering preservation.
- The main demo rebake now reports occupied source-flow average magnitude about `0.244`, max about `0.251`, and no near-neutral occupied flow. This keeps the source vector field much calmer while leaving Phase 5A to handle final local damping and sliding.

Implementation plumbing checklist:

- `river.gdshader`: consume context maps in final flow force and local slide direction, without changing foam or pillow appearance yet.
- `river_debug.gdshader`: use the exact same final-flow math for effective-flow and final-strength views.
- `system_renders/system_flow.gdshader`: consume the same context maps and tuning values so the generated WaterSystem flow matches visible water.
- `system_map_renderer.gd`: pass context textures and Phase 5 tuning values into the WaterSystem flow material, with neutral fallbacks for older resources.
- `river_manager.gd`: only change source-signature, source metadata, or river rebake behavior if Phase 5B changes the baked `flow_foam_noise.rg`; Phase 5A shader/system-flow consumption alone should not invalidate river bakes.
- `../history/CHANGELOG.md` and this roadmap: keep the boundary clear between context-aware flow consumption and later pillow/eddy visuals.

Validation targets:

- Deep, open, straight channel water remains fast and legible.
- Shallow or bank-adjacent water becomes slower and calmer while still moving downstream.
- Hard protrusions make the current slide locally instead of steering the whole upstream channel too early.
- Debug arrows and normals no longer read as water emerging from terrain or moving through solid banks.
- Ordinary banks reduce force without painting wake, pillow, or eddy behavior across the river.
- Outside bends can keep a little pressure/energy; inside bends become calmer without becoming static.
- Final Flow Strength and WaterSystem flow preview agree after rebakes.
- Neutral or legacy bakes that lack terrain-contact, bank-response, or obstacle-feature textures still render safely with black/default context.
- Main demo and obstacle-test captures are exported under `.codex-research/phase5_demo_debug/` before moving on to Phase 6.

Phase 5 acceptance note:

- The user reviewed Phase 5A/5B in game after the SDF steering cleanup and said the water looks good. Treat the Phase 5A/5B flow behavior and existing WaterSystem flow as the accepted baseline; current river bakes are signature version `19` after the Phase 6E raw pillow contact-search distance pass.
- Do not keep tuning hidden flow, SDF steering, terrain-contact thresholds, or bank-response thresholds unless a new visible regression is found.

## Phase 6: Pillows

Goal: show water piling up on the upstream face of rocks and walls.

Status: Phase 6A visual-only pillow highlights are implemented and accepted as part of the closed Phase 6B baseline. The visible pass consumes accepted river masks in the visible/debug river shaders only. It does not change final flow, WaterSystem flow, reverse-flow behavior, eddy behavior, or `RiverBakeData` layout. A focused follow-up diagnosis found the obvious forward placement came from shader-side forward reach, so the default `pillow_forward_reach_tiles` is now `0.0` while the material control remains available for explicit review. Later raw-classifier passes tightened `obstacle_features.r` with pillow-specific support thresholds, a nearby hard-contact anchor, and then a halved contact-search distance after live/in-game review showed raw/visible pillows still too far ahead of rocks.

Phase 6 research update:

- River-reading sources describe a pillow as an upstream mound where current presses into a rock, boulder, or cliff wall before deflecting around it. The visual priority is therefore compression and surface lift on the impact face, not downstream wake foam.
- River-dynamics and boulder-flow research reinforces that the upstream side of an obstruction is a deceleration, pressure, and turbulence zone, with submergence and local energy affecting how pronounced the feature is. This supports gating pillows by hard-boundary context, grade/energy, and effective flow strength rather than treating every obstacle mask pixel equally.
- Valve's production flow-map work, Catlike Coding's flow-map tutorial, and the current Waterways shader all point to the same practical rendering strategy: use the accepted vector field to drive moving normal/detail layers, then use procedural masks and phase/noise offsets to localize accents without changing the underlying flow.
- Unreal/Riverology-style obstacle foam systems commonly expose upstream-obstacle foam and distance-field masking controls, but Phase 6A should translate that idea into Waterways' existing saved maps: `obstacle_features`, `terrain_contact_features`, and `bank_response_features`.
- GPU Gems' water guidance supports using depth/contact data to attenuate wave behavior in shallow or bank-contact areas. In Waterways terms, ordinary bank friction and shallow contact should calm or suppress pillow visuals unless hard protrusion context is present.

Design rules:

- Use the accepted Phase 5 flow as the foundation. Pillows should read as surface compression on top of good flow, not as another hidden flow correction.
- Use `obstacle_features.r` as the primary upstream pillow / impact mask.
- Gate pillow visibility with `obstacle_features.a`, hard-boundary/protrusion context from `max(bank_response_features.a, terrain_contact_features.b)`, `dist_pressure.b` grade/energy, and final/effective flow strength so faint classifier noise does not create broad highlights.
- Treat grade/energy and final/effective flow strength as separate multiplicative gates in the first pass. Do not let high final flow alone satisfy both the energy and flow tests unless review explicitly chooses a more permissive `energy OR flow` look.
- Suppress ordinary banks with `bank_response_features.r * (1.0 - hard_boundary_context)`. Ordinary bank friction should not become a long pillow strip.
- Let outside-bend wet pressure from `bank_response_features.g` contribute only as a subtle optional bank-pressure accent, separate from hard-obstacle pillows.
- Treat foam as a secondary accent. The first read should come from pressure/highlight, local roughness or brightness, stronger normal detail, and narrow compression bands. Foam should appear only where impact, energy, and existing foam/noise support all agree.
- Avoid vertex displacement until the shader-gated mask and visual language are accepted. If added later, displacement should be small, local, and fade out before banks and shallow terrain-contact strips.
- Keep eddies and reverse/circulating flow deferred to Phase 7.

Phase 6A implementation plan:

1. Inspect `obstacle_features.r` / `.a`, `bank_response_features.a`, `terrain_contact_features.b`, grade/energy, Final Flow Strength, Foam Mix, and Flow Pattern at the rocks and hard bank protrusions that look best in game. Use the existing Phase 0B/0C review cameras plus any tight rock-facing captures needed for comparison.
2. Before changing visible water, calculate or export an exact preview of the proposed gated `pillow_visual_mask` and report overlap stats. Current signature-version-`16` main-demo stats from the inspection helper are a useful warning: raw pillow impact is fairly localized (`obstacle_features.r > 0.05` is about `8.08%` of the atlas), while obstacle confidence, terrain protrusion, and hard-boundary response are much broader. Use the final overlap, not any single channel, to choose first thresholds.
3. Add `pillow_ = "Pillow"` to `MATERIAL_CATEGORIES` in `river_manager.gd` and update the shader prefix comment. The Waterways inspector is prefix-driven, so Godot `group_uniforms` alone is not enough for these controls to appear in a clean category. Then add conservative controls to the visible and debug shaders:
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
   Start with threshold constants inside the shader for detailed tuning ranges; expose extra start/full threshold sliders only if review shows the simple gates are too blunt.
4. Derive a shared `pillow_visual_mask` helper in `river.gdshader` and `river_debug.gdshader` from the accepted masks and gates. Neutral black `obstacle_features`, `terrain_contact_features`, or `bank_response_features` must produce no pillow effect. Truly missing feature textures are still treated as stale/invalid bakes by the current `RiverManager` resource validation, so do not claim missing-texture fallback is implemented unless Phase 6 deliberately adds real neutral fallback textures.
   Suggested first formula:
   - `raw_pillow = obstacle_features.r`
   - `confidence_gate = smoothstep(0.10, 0.55, obstacle_features.a)`
   - `hard_boundary_context = clamp(max(bank_response_features.a, terrain_contact_features.b), 0.0, 1.0)`
   - `hard_gate = smoothstep(0.12, 0.55, hard_boundary_context)`
   - `ordinary_bank = clamp(bank_response_features.r * (1.0 - hard_boundary_context), 0.0, 1.0)`
   - `bank_gate = 1.0 - clamp(ordinary_bank * pillow_bank_suppression, 0.0, 0.95)`
   - `normalized_flow_force = clamp(flow_force / max(flow_max, EPSILON), 0.0, 1.0)`
   - `energy_gate = smoothstep(0.08, max(0.09, pillow_energy_gate), grade_energy_map)`
   - `flow_gate = smoothstep(0.04, max(0.05, pillow_flow_gate), normalized_flow_force)`
   - `pillow_visual_mask = clamp(raw_pillow * confidence_gate * hard_gate * bank_gate * energy_gate * flow_gate * pillow_strength, 0.0, 1.0)`
   Keep this helper side-effect free so the debug shader can display exactly the same value the visible shader consumes.
5. Use the mask to:
   - Define the exact visible insertion point before implementation. A safe first target is to lightly brighten or tighten `alb_mix` after the depth color is computed and before `ALBEDO = mix(alb_mix, foam_color.rgb, combined_foam)`, because the current shader has no separate pressure-color path.
   - Add a narrow, view-stable highlight on upstream impact faces, preferably by blending toward a lightened water color instead of turning the area white. Verify that the later refraction/emission math does not wash the highlight away.
   - Strengthen existing normal/detail animation locally by scaling `water_norFBM` or `NORMAL_MAP_DEPTH` in a clamped way; do not redirect flow vectors for Phase 6A.
   - Add subtle compression-wave bands using a current-aligned coordinate such as `dot(UV * uv_scale.xy * pillow_band_scale, safe_direction(flow, vec2(0.0, 1.0)))`, with phase/noise offsets so every rock does not pulse in sync. Suppress or fade bands when normalized flow force is very low. Bands should be multiplied by the final mask and fade with distance/LOD.
   - Add small foam/noise accents only where grade/energy, final-flow strength, and the existing foam texture agree. This should be a bias into the current foam pipeline, not a separate always-white decal.
   - Use `pillow_forward_reach_tiles` for shader-only upstream extension by sampling the same visual mask downstream along the safe flow direction. The value is in UV2 source-tile units, not raw atlas texels, so it stays stable across bake resolution changes. Setting it to `0.0` restores the no-reach Phase 6A mask.
6. Add a `Pillow Visual Mask` debug mode as part of Phase 6A, not as an optional extra. Keep the existing Pillow / Impact view as raw `obstacle_features.r` so it remains clear whether a problem is in the bake or in shader gating.
7. Keep WaterSystem flow unchanged. If Phase 6 only affects visuals, do not bump the river bake source signature and do not regenerate the WaterSystem map.
8. Add a small validation probe that checks the new shader uniforms, `pillow_` inspector category, debug mode ID, visible/debug material parameter parity, neutral-black feature texture behavior, and that Phase 6A does not change `RiverBakeData` texture layout, the river source signature, or WaterSystem flow shader wiring.
9. Export Phase 6 review captures under `.codex-research/phase6_pillows_demo_debug/` before considering stronger displacement or foam.

Phase 6A implementation notes:

- Added `pillow_ = "Pillow"` to `MATERIAL_CATEGORIES` so the custom Waterways inspector groups pillow controls cleanly.
- Added conservative pillow controls to `river.gdshader` and `river_debug.gdshader`.
- Added a shared shader-side `pillow_visual_mask` helper that multiplies raw pillow impact, obstacle confidence, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, and normalized final-flow strength.
- Kept grade/energy and final-flow strength separate in the mask.
- Used the mask for localized pressure/highlight, normal-detail boost, subtle current-aligned compression bands, and small high-energy foam bias. The flow vector itself is not redirected.
- Added `pillow_forward_reach_tiles`, a shader-only control that lets the visual pillow begin slightly upstream of the raw obstruction mask by sampling downstream along the accepted flow direction with falloff. The reach is measured in UV2 source-tile units rather than atlas texels.
- Added `Pillow Visual Mask` as debug mode `26` and kept `Pillow / Impact Mask` as the raw `obstacle_features.r` view.
- Preflight estimate on the main demo bake: raw pillow impact above `0.05` is about `8.08%`; the combined visual mask above `0.05` is about `3.17%` with default `pillow_forward_reach_tiles = 0.05`. The obstacle-test bake is similar at about `3.15%` above `0.05` after gating and reach.
- Added local validation/export helpers:
  - `.codex-research/phase6a_pillow_mask_preflight.gd`
  - `.codex-research/phase6a_pillow_visual_probe.gd`
  - `.codex-research/export_demo_phase6_pillow_views.gd`
- Exported review captures under `.codex-research/phase6_pillows_demo_debug/`.
- Validation results: `PHASE6A_PILLOW_VISUAL_PROBE_OK`; main demo `validate_generated_map_sampling()` still returns `true`.
- No river rebake or WaterSystem regeneration is needed for Phase 6A.

Acceptance targets:

- Upstream faces of rocks and hard wall/protrusion areas get readable compression highlights.
- Ordinary banks do not turn into continuous bright pillow strips.
- Foam stays subtle and appears only at higher-energy impacts.
- The result still reads as the same accepted Phase 5 flow underneath.
- Flow Pattern and Flow Arrows still show the accepted downstream-preserving behavior; Phase 6 should not make apparent flow direction contradict the visible accents.
- Debug views make it clear whether a problem is in the baked pillow mask or the shader's final visual gate.
- Current signature-version-`19` bakes and future custom bakes with neutral black feature textures remain visually safe because black masks produce no pillow effect. Older bakes that truly lack required feature textures remain stale/invalid under the current resource validation unless a separate neutral fallback-texture pass is implemented.

Phase 6B and later, only after Phase 6A is accepted:

Phase 6B research / investigation update:

- Current recommendation: make Phase 6B a visual-only pillow review and tuning milestone by default, not a bake or physics milestone. The Phase 6A captures show the combined `pillow_visual_mask` is much narrower than the raw `obstacle_features.r` mask and is concentrated near rocks/hard protrusions, so the first likely need is stronger art-direction controls rather than new source data.
- Treat Phase 6B as a review/tuning gate until Phase 6A is accepted in game. If the current result is acceptable but subtle, tune material response. If it is too sparse, inspect `Pillow / Impact Mask` versus `Pillow Visual Mask` before increasing strength, because material sliders cannot recover pixels that the shader gates already suppress.
- Hydrology references still support the current separation: pillows belong on the upstream impact/compression side of solid obstructions, while wakes, eddy lines, holes, and reverse/circulating flow are downstream/void-filling phenomena. Do not use `obstacle_features.g` or `.b` for Phase 6B pillow visuals except as comparison debug.
- Production water references point toward the same practical path: keep the low-resolution accepted flow/feature maps inspectable, then use shader-time normal, roughness/specular, band/noise phase, and foam accents to sell local motion. Avoid large deformation unless the surface mesh density and depth/refraction behavior have been reviewed.
- The current add-on already has five first-class bake textures, and their channels are occupied. `obstacle_features.r` is already an upstream-facing impact classifier; `terrain_contact_features` and `bank_response_features` already supply hard-boundary, protrusion, shallow, and ordinary-bank context; `dist_pressure.b` and `.a` already supply grade/energy and bend bias. Adding a new pillow data channel or changing classifier semantics is a real bake-format/source-signature change.
- The fixed `confidence_gate`, `hard_gate`, energy start, and flow start in `pillow_visual_mask` are the main remaining bottleneck if the user reports "not enough pixels" rather than "not enough contrast." A Phase 6B gate pass should expose shader-only threshold uniforms with visible/debug parity instead of changing `obstacle_feature_mask_filter.gdshader`.
- `pillow_forward_reach_tiles` now uses UV2 source-tile units and is stable across bake resolution changes. The remaining reach risk is semantic: forward reach currently samples downstream masks but reuses the current pixel's normalized flow force. If reach feels inconsistent near abrupt flow/energy changes, either sample downstream flow/energy for the reached mask or treat reach as a raw-mask extension that is gated again at the current pixel.
- The current pressure/highlight path blends toward `foam_color`, which can make pillow compression read as foam if pushed too hard. Before increasing `pillow_foam_bias`, consider a separate `pillow_highlight_color` / `pillow_pressure_color`, or subtle roughness/specular controls, so upstream pressure can read as lifted water instead of whitewater.
- The visible river shader currently has no `vertex()` displacement path. Adding local height would be possible, but it would be a new rendering behavior that must be tested against depth color, screen refraction, bank clipping, mesh tessellation, and buoyancy/physics mismatch. Godot's screen/depth texture behavior makes this a higher-risk visual step than stronger material tuning.
- WaterSystem flow currently consumes final flow, terrain contact, and bank response, but not `obstacle_features` or the visual `pillow_visual_mask`. A visual-only Phase 6B must leave `system_renders/system_flow.gdshader`, the saved WaterSystem bake, and the river source signature unchanged.

Phase 6B implementation notes:

- Implemented the first Phase 6B tuning pass as visual-only shader work. No river bake source-signature bump, no `RiverBakeData` layout change, no source flow change, no WaterSystem flow shader wiring, and no WaterSystem bake regeneration.
- Added shader-only gate controls with visible/debug parity:
  - `pillow_confidence_gate_start`
  - `pillow_confidence_gate_full`
  - `pillow_hard_gate_start`
  - `pillow_hard_gate_full`
  - `pillow_energy_gate_start`
  - `pillow_flow_gate_start`
- Kept `pillow_energy_gate` and `pillow_flow_gate` as the full-threshold controls for energy and final-flow gates, but lowered their defaults slightly so the accepted raw pillow mask is less over-suppressed.
- Added separate non-foam pillow visual language controls:
  - `pillow_pressure_color`
  - `pillow_highlight_color`
  - `pillow_specular_boost`
  - `pillow_roughness_reduction`
- Tuned conservative defaults for a stronger review read: `pillow_strength = 1.15`, `pillow_energy_gate = 0.35`, `pillow_flow_gate = 0.28`, `pillow_pressure_strength = 0.50`, `pillow_highlight_strength = 0.60`, `pillow_normal_strength = 0.70`, `pillow_band_strength = 0.55`, `pillow_foam_bias = 0.14`, and `pillow_forward_reach_tiles = 0.075`.
- The main-demo preflight estimate now reports raw pillow impact above `0.05` at about `8.08%` and combined `Pillow Visual Mask` above `0.05` at about `3.88%`. The obstacle-test bake reports about `7.82%` raw and `3.75%` combined.
- Added `.codex-research/phase6b_pillow_tuning_probe.gd` and `.codex-research/export_demo_phase6b_pillow_views.gd`; refreshed the Phase 6 preflight helper for the new gate defaults.
- Exported Phase 6B review captures under `.codex-research/phase6b_pillows_demo_debug/`.

Phase 6B experimental pillow height notes:

- Implemented the optional local height/displacement review path as shader-only, default-off behavior after the Phase 6B tuned visual mask.
- Added split default-off height controls to `river.gdshader` and `river_debug.gdshader`: `pillow_terrain_height`, `pillow_terrain_height_curve`, `pillow_obstruction_height`, `pillow_obstruction_height_curve`, and `pillow_height_tile_seam_fade`.
- The vertex path lifts local water height only when `i_valid_flowmap` is true and either split height is above zero. Terrain height uses the reached hard-boundary `pillow_visual_mask`; obstruction height uses a separate raw-impact obstruction mask so in-river rocks do not require terrain/protrusion context to lift.
- Added source-tile seam fading to the experimental height path so obstruction lift can be reviewed around rocks without separating neighboring river tiles at UV2 atlas borders or mesh step borders. If the mesh has too few interior vertices, this necessarily suppresses height rather than inventing smooth displacement.
- Follow-up editor review confirmed that the seam guard fixes the visible separation at lower obstruction-height values. Treat obstruction pillow height as a restrained accent; if the desired look needs stronger vertical lift, prefer material response first or plan explicit mesh-density/stitch/skirt work.
- Added `Pillow Height Influence` debug mode `27`, `Terrain Pillow Height Influence` debug mode `28`, and `Obstruction Pillow Height Influence` debug mode `29`, then exported review captures with `.codex-research/export_demo_phase6_pillow_height_experiment.gd`.
- The experiment capture uses `pillow_terrain_height = 0.16`, `pillow_terrain_height_curve = 1.20`, `pillow_obstruction_height = 0.16`, `pillow_obstruction_height_curve = 1.20`, and `pillow_height_tile_seam_fade = 0.035`, and writes 60 captures to `.codex-research/phase6_pillow_height_experiment_debug/`.
- No bake layout, source signature, source flow, WaterSystem shader, or WaterSystem bake changed.
- User direction: Phase 6B is complete/closed. Keep the current pillow controls as the accepted Phase 6 baseline unless a new regression appears, and start the next session by improving the Phase 7 plan.

Phase 6B decision table:

- Stronger material tuning: visual-only. Tune existing `pillow_pressure_strength`, `pillow_highlight_strength`, `pillow_normal_strength`, `pillow_band_strength`, `pillow_band_scale`, `pillow_foam_bias`, and `pillow_forward_reach_tiles`. No source-signature bump, rebake, or WaterSystem regeneration.
- Shader-only gate refinement: visual-only if it only adds/tunes material uniforms for the existing `pillow_visual_mask`, such as confidence start/full, hard-boundary start/full, energy start/full, flow start/full, band contrast, roughness/specular response, or pressure/highlight color. This is the right answer if review says the mask is too sparse after comparing raw `Pillow / Impact Mask` to `Pillow Visual Mask`. Requires visible/debug shader parity and probe updates, but no river rebake.
- Shader-only reach refinement: visual-only if it keeps `pillow_forward_reach_tiles` in source-tile units and only changes how reached samples are gated. Sample downstream flow/energy only if review shows obvious reach artifacts; otherwise keep the cheaper current-pixel gate.
- Separate pressure/highlight language: visual-only. Add `pillow_highlight_color`, `pillow_pressure_color`, or roughness/specular controls if the highlight reads as foam. Prefer this before raising `pillow_foam_bias`.
- Shader-only local height/displacement: implemented as an experimental review capture, not a default. It is tiny, gated by `pillow_visual_mask`, suppressed by the existing mask near ordinary banks/shallow strips, faded by LOD/distance, and should be reviewed against refraction/depth artifacts. No source-signature bump unless baked height/source data is added; no WaterSystem regeneration unless physics height/flow is deliberately changed to match.
- Bake-level pillow classifier refinement: data change. Changing `obstacle_feature_mask_filter.gdshader` thresholds/semantics again, changing `obstacle_features.r` meaning, or adding new classifier inputs requires the next source-signature version after current `18`, rebaking main and obstacle-test river resources, updated stats, validation probes, and fresh review captures before visible-water tuning.
- New pillow feature/debug channel: resource layout change. Adding `pillow_features`, pressure bands, local height, or another first-class texture requires `RiverBakeData`, material wiring, debug views, validation/export scripts, source metadata, source-signature bump, and rebakes.
- Stronger foam accent: visual-only only if it remains a local bias into the current foam path using `pillow_visual_mask`, grade/energy, normalized flow, and existing noise. Broad obstacle foam, eddy-line foam, and wake foam belong to Phase 7.
- Flow or physics response: not Phase 6B by default. Any change to source flow, final WaterSystem flow, reverse/circulating flow, or buoyancy-facing maps requires explicit scope expansion, WaterSystem shader wiring, regeneration, and review.

Recommended Phase 6B plan:

1. Review Phase 6A in game and in `.codex-research/phase6_pillows_demo_debug/`, focusing on `rock_garden_overhead`, `main_bend_low_oblique`, and `downstream_rocks_low_oblique`.
2. Classify the review feedback before choosing a fix:
   - Too subtle but correctly placed: tune `pillow_pressure_strength`, `pillow_highlight_strength`, `pillow_normal_strength`, `pillow_band_strength`, `pillow_band_scale`, and only then `pillow_foam_bias`.
   - Too sparse or starts too late: compare raw `Pillow / Impact Mask` against `Pillow Visual Mask`; add shader-only gate uniforms if the final mask is over-suppressing good raw pixels.
   - Too foam-like: add separate pillow pressure/highlight color or roughness/specular controls before increasing foam.
   - Reach artifacts near abrupt flow changes: refine reached-sample gating while keeping `pillow_forward_reach_tiles` source-tile based.
   - Wrong raw pillow placement: stop visual tuning and plan a new source-signature classifier/rebake pass.
3. If existing controls are only too subtle, do a material-only tuning pass first. Bias toward stronger pressure/highlight/normal/band read before increasing foam.
4. If existing controls are too blunt, add shader-only Phase 6B tuning uniforms for the mask gates and visual response, mirrored in `river_debug.gdshader`, with a validation probe that confirms no bake layout, source signature, source flow, or WaterSystem wiring changed.
5. Review the new experimental local height capture in `.codex-research/phase6_pillow_height_experiment_debug/`. Keep `pillow_terrain_height` and `pillow_obstruction_height` at `0.0` by default unless in-game review accepts the extra vertical read. Start obstruction height low and treat it as a subtle accent. If seams reappear or the desired look requires stronger lift, treat that as a mesh-density/topology limit first: reduce height, increase source-step tessellation, add stitch/skirt geometry, or drop back to material-only pillow cues.
6. Consider bake-level classifier work only if review proves the raw `Pillow / Impact Mask` is wrong, not merely too subtle after shader gating.
7. Keep downstream wakes, eddy-line foam, reverse/circulating flow, holes, and hydraulic recirculation in Phase 7 or later.

Phase 6B closure status:

- Complete as of the user review after the obstruction-height seam guard. Do not reopen Phase 6B by default next session.
- Default-off pillow height remains available for subtle review use. Obstruction height should stay low; stronger reads should come from material response unless a future mesh/topology pass is explicitly planned.
- Later review found raw pillow placement problems, handled separately as Phase 6D/6E data/classifier work rather than reopening Phase 6B material tuning.

Phase 6D raw classifier update:

- User review of `Pillow / Impact Mask` showed raw `obstacle_features.r` still too far ahead of rocks after shader-side forward reach was disabled.
- Updated `obstacle_feature_mask_filter.gdshader` so the pillow channel uses pillow-specific tighter support thresholds and a nearby hard-contact/protrusion anchor along the downstream flow direction.
- Kept wake/eddy source behavior on the existing support path and preserved the accepted Phase 7B visible wake/eddy-line shader behavior.
- Bumped the river bake source signature to `18` and rebaked only the main and obstacle-test river resources. `RiverBakeData` layout, source flow, final flow, WaterSystem shader wiring, and the saved WaterSystem bake did not change.
- Refreshed `.codex-research/phase6c_pillow_placement_diagnostic/`. The diagnostic now reports raw pillow coverage above `0.05` at about `5.12%` on the main bake and `5.06%` on obstacle-test, down from the earlier roughly `8%` raw coverage, with review captures showing the broad ahead-of-rock blobs reduced.

Phase 6E contact-search distance review:

- User in-game review found obstruction pillows still a little too far ahead of the obstruction and requested halving the distance for review.
- Halved `RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES` from `0.14` to `0.07`, and aligned the direct filter fallback `pillow_contact_search_uv` default from `0.02` to `0.01`.
- Bumped the river bake source signature to `19` and rebaked only the main and obstacle-test river resources. `RiverBakeData` layout, source flow, final flow, WaterSystem shader wiring, and the saved WaterSystem bake did not change.
- Refreshed `.codex-research/phase6c_pillow_placement_diagnostic/`. The diagnostic now reports raw pillow coverage above `0.05` at about `4.70%` on the main bake and `4.61%` on obstacle-test; the no-reach visual mask above `0.05` is about `2.32%` main and `2.26%` obstacle-test.

Phase 6F formula review finding:

- Follow-up code and capture review confirmed that visible shader reach is still default-off and is not the main source of the remaining forward pillow start.
- The explicit `0.07` pillow contact search is not the full effective contact reach. `pillow_contact_gate_at()` samples `hard_boundary_at()` up to `1.5 * pillow_contact_search_uv`; `hard_boundary_at()` includes `bank_response.a`; and `bank_response.a` is created by `forward_protrusion()` using `RIVER_BANK_RESPONSE_PROBE_TILES = 0.20`, sampled at `0.75x` and `1.5x`.
- The source side also remains broad because `pillow_source_at()` uses the generic dilated collision support generated from `baking_dilate = 0.6`.
- Treat the next pillow step as a formula/diagnostic decision, not another scalar distance reduction. The likely first diagnostic split is support/facing, direct `terrain_contact.b` anchoring, `bank_response.a` anchoring, and final contact-gate contribution.
- Documentation-only: no shader code, bake resources, source signatures, final flow, WaterSystem data, or validation probes changed.

Phase 6G audit-guided diagnostic and formula direction:

- `docs/audit/pillow-system-audit.md` reviewed the signature-`19` pillow baseline and confirmed the remaining forward-start issue is primarily a bake/formula issue, not a visible-material reach issue.
- The audit-reported anchor split found about `35.17%` of main-river and `35.88%` of obstacle-test raw pillow pixels above `0.05` are strongly `bank_response.a` anchored while direct `terrain_contact.b` is weak or absent. Over half of raw pillow pixels have `bank_response.a` meaningfully higher than direct `terrain_contact.b`.
- Treat this as high-severity evidence that `bank_response.a` is too semantic and forward-looking to define literal pillow contact by itself.
- The next implementation pass should add diagnostic split views or probe output before another classifier edit:
  - pillow support/facing source;
  - direct terrain protrusion anchor;
  - bank-response anchor;
  - combined pillow contact gate;
  - bank-only anchor contribution.
- If live review confirms the audit, revise raw pillow R toward a direct-contact-first formula:
  - `direct_anchor = tight local search of terrain_contact.b`;
  - `semantic_context = low-weight bank_response.a overlap/context`;
  - `source = tight support * facing^2 * bank suppression`;
  - `raw_pillow = source * direct_anchor_gate * context_gate`.
- Keep `bank_response.a` as context for pillows, not as a standalone contact anchor.
- If support/facing still starts too early, tighten pillow-specific support or thresholds. Do not globally reduce `baking_dilate = 0.6` unless the impact on flow, foam, pressure, wakes, and obstacle avoidance is reviewed.
- After the next formula is accepted, consider moving duplicated visible/debug pillow helper math into `.gdshaderinc` files and add parity probe coverage. Do this after formula agreement, not before the placement diagnosis.
- Re-run `PILLOW_FORMULA_ANCHOR_AUDIT_OK`, `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, and relevant Phase 7B wake/eddy probes after any raw pillow formula change.

Future pillow detection review workflow:

- See `river-feature-detection-roadmap.md` for the shared review workflow for pillows, wakes, and eddy lines.
- Keep the current Phase 6B pillow visuals and Phase 6E halved-distance contact-anchored raw pillow classifier as the active baseline, but allow later pillow detection improvements when live review proves the raw/source placement is still wrong.
- Detection acceptance should come from the user's live editor/runtime inspection of debug views, supported by Codex-side captures and numeric readings.
- Compare raw and final masks before changing code. If raw `Pillow / Impact Mask` is wrong, plan a bake-level classifier pass with source-signature bump, rebakes, stats, probes, and new review captures.

## Phase 7: Eddies

Status: Phase 7B visual-only wake/eddy-line material preview is implemented on top of the accepted Phase 7A2 masks. Source flow, SDF steering, terrain-contact thresholds, bank-response thresholds, final flow, WaterSystem flow shader wiring, and the saved WaterSystem bake remain unchanged. Actual reverse/circulating flow remains Phase 7C or later.

Goal: support believable downstream wake, eddy-line, and eventually reverse/circulating flow behind obstacles and sharp banks.

This should be a new pass rather than a tweak to obstacle avoidance, because the current avoidance pass preserves downstream alignment.

- Generate wake regions downstream of obstacles.
- Blend in a rotational vector field inside the wake.
- Let eddy cores become slow, neutral, or reverse-flow regions.
- Generate an eddy-line mask where main current and eddy flow meet.
- Use the eddy-line mask for turbulence, foam, noisy normals, and possible gameplay feedback.

Research takeaways:

- Practical river-reading sources and hydraulic research agree on the broad anatomy: the upstream face of an obstruction is a pillow/compression zone, while the downstream void can become a slow or reverse-flow eddy, separated from the main current by a narrow turbulent eddy line.
- Boulder and cylinder wake studies show that wake size and reverse-flow area depend strongly on submergence, blockage, obstacle shape, and bed/bank context. Waterways should therefore keep energy, hard-boundary/protrusion response, and ordinary-bank suppression in the gate instead of treating every bank or contact edge as an eddy source.
- Valve-style flow maps, Unreal distance-field flow tricks, Unity HDRP current maps, Crest whirlpool flow inputs, Riverology obstacle foam, and Epic's baked river simulations all support the same staged pattern: inspect low-resolution vector/feature fields first, add shader-time surface cues next, and only then promote trusted flow data into physics-facing maps.
- Godot screen/depth texture techniques can help the final water material, but they are not a replacement for the saved bake channels because Phase 7 needs editor review, reproducible bakes, and eventual WaterSystem/physics agreement.
- Actual reverse/circulating flow is more data-hungry than a wake accent. The current `obstacle_features.g` and `.b` channels describe scalar wake and shear confidence, not an eddy center, spin side, or local velocity offset.
- River-reading references describe eddy lines as narrow upstream and wider or less defined downstream. A good Waterways eddy-line preview should therefore be edge-weighted and should fade or soften downstream; a uniformly thick band around the whole wake is a classifier smell.
- Flow-map references repeatedly warn that overlarge influence radii or sharp direction/magnitude changes create stretching, pulsing, or smeared normal detail. Any future Phase 7C vector field needs bounded speed, smooth phase/noise handling, and visible/debug/WaterSystem parity before it is saved.

Current Waterways findings:

- `obstacle_features.g` is the current downstream wake / eddy seed mask. In the current signature-version-`19` main demo bake, the image-space estimate reports average `0.079`, above `0.05` about `18.54%`, above `0.25` about `12.90%`, and above `0.50` about `7.72%`.
- `obstacle_features.b` is the current eddy-line / shear mask. In the current signature-version-`19` main demo bake, it reports average `0.014`, above `0.05` about `2.42%`, above `0.25` about `1.92%`, and above `0.50` about `1.41%`.
- Visual review of `.codex-research/phase4b_demo_debug/` shows `obstacle_features.g` is useful as a downstream wake candidate behind rocks and protrusions, but still has atlas/flow-aligned streaks and some broad downstream regions.
- Phase 7A1 visual review showed `obstacle_features.b` was too broad and saturated for direct visible foam or reverse-flow use. Phase 7A2 narrows it substantially; review `.codex-research/phase7a2_wake_eddy_demo_debug/` before deciding how much of it should become visible.
- Phase 7B now consumes `obstacle_features.g` and `.b` in `river.gdshader` and `river_debug.gdshader` for surface detail and debug views only. It does not create reverse-flow, final-flow, or WaterSystem consumption.
- `system_renders/system_flow.gdshader` currently consumes flow, `dist_pressure`, `terrain_contact_features`, and `bank_response_features`, but not `obstacle_features`. That separation is still useful: Phase 7B remains visual/debug-only, while Phase 7C/7D must deliberately wire every final-flow change into the system-flow path.
- Historical Phase 7B diagnosis showed the raw eddy-line channels were present in marked expected regions, but the old final `Eddy-Line Visual Mask` stayed green because its source and gate were out of spatial phase. The old default `wake_edge_sample_tiles = 0.006` was also sub-pixel in the signature-`17` bakes, so sample distance had to be reviewed separately from source placement.
- A downstream-looking-upstream viewport review of `Wake Edge Thinness` circled missing signal around rock and terrain features. Expected wake-edge thinness should appear on downstream rock shoulders and the thin trailing wake margins, not as a filled wake blob, not across upstream pillow faces, and not as continuous ordinary-bank outlines. Missing signal around the large lower rock cluster and central downstream shoulder is a plausible false negative to test in the sample-distance sweep.
- A follow-up `Eddy-Line Visual Mask` viewport review found no useful eddy-line response in the expected areas; the only strong response was at the start of the river, an area the user reports is frequently over-dramatic in many debug views. Treat that start-of-river response as a likely boundary/source false positive and exclude it from acceptance when judging Phase 7B tuning.
- User review of the `wake_edge_sample_tiles = 0.024` sweep rejected the edge-sample-only fix. `Raw Eddy-Line / Shear Mask` and `Wake / Eddy Seed Mask` show some plausible rock shoulder/trailing data, but `Wake Edge Thinness` becomes crowded behind or beside rocks without producing two trailing wake-edge lines. `Wake Shared Gate` appears upstream/on protrusion contact, `Gated Eddy-Line Source (B * Wake Gate)` stays green almost everywhere except tiny bank strips, and final `Eddy-Line Visual Mask` stays green.
- Accepted Phase 7B resolution: the final eddy-line visual now derives placement from a raw-G wake-edge candidate at `wake_edge_sample_tiles = 0.024`, then applies nearby wake/hard-protrusion context and ordinary-bank/energy/flow gates. Raw B remains diagnostic because it was too far downstream for the accepted close-behind-rock visual pattern.

Phase 7A1 preflight/export update:

- Added ignored review helpers under `.codex-research`: `phase7a1_wake_eddy_mask_lib.gd`, `phase7a1_wake_eddy_mask_preflight.gd`, and `export_demo_phase7a1_wake_eddy_views.gd`.
- Exported atlas-space candidate masks under `.codex-research/phase7a1_mask_preflight/` and 60 accepted Phase 0B camera captures under `.codex-research/phase7a1_wake_eddy_demo_debug/`.
- The preflight derives review-only `gated_wake`, `gated_eddy_line`, and `wake_edge_thinned_eddy_line` candidates from `obstacle_features.g`, `obstacle_features.b`, `obstacle_features.a`, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, estimated normalized final-flow strength, and local wake-edge gradients.
- Main demo stats: raw wake above `0.05` is about `18.54%`; gated wake above `0.05` is about `7.19%`; raw eddy-line above `0.05` is about `20.60%`; gated eddy-line above `0.05` is about `8.30%`; wake-edge-thinned eddy-line above `0.05` is about `4.31%`.
- Obstacle-test stats are similar: raw wake above `0.05` is about `18.69%`; gated wake above `0.05` is about `7.17%`; raw eddy-line above `0.05` is about `20.45%`; gated eddy-line above `0.05` is about `8.02%`; wake-edge-thinned eddy-line above `0.05` is about `4.16%`.
- Ordinary-bank false positives are not the dominant remaining problem after gates. On the main demo, final-mask pixels above `0.05` overlap ordinary-bank areas by about `3.10%` for gated wake, `6.73%` for gated eddy-line, and `5.81%` for wake-edge-thinned eddy-line; at `0.50`, those overlap rates fall to about `0.05%`, `0.46%`, and `1.42%`.
- Visual review of the Phase 7A1 captures shows the gated wake mask is localized enough for a restrained visual wake-only material pass if the user accepts the placement. The eddy-line candidate still reads as either broad raw bank/downstream-edge activity or, after edge thinning, small broken fragments near rocks and atlas/flow edges. Plan Phase 7A2 classifier work before visible eddy-line foam/turbulence or any reverse/circulating flow.
- No visible-water shader behavior, source bake, river bake source signature, final flow, WaterSystem flow shader, saved WaterSystem bake, terrain-contact thresholds, bank-response thresholds, or obstacle classifier code changed during Phase 7A1.

Phase 7A2 classifier update:

- Refined `obstacle_feature_mask_filter.gdshader` so the eddy-line channel uses thresholded wake edges, hard-boundary/protrusion context from `bank_response_features.a` plus `terrain_contact_features.b`, grade/energy gating, source-support rejection, and reduced broad side-deflection confidence.
- Bumped the river bake source signature to version `17` and rebaked the main and obstacle-test river resources.
- Kept `obstacle_features.r` pillow impact and `obstacle_features.g` wake seed effectively unchanged; the main change is a narrower `obstacle_features.b` eddy-line/shear mask and less broad `obstacle_features.a` confidence.
- Main demo metadata stats after the rebake: eddy-line/shear above `0.05` is about `3.38%`, above `0.25` about `2.68%`, and above `0.50` about `1.97%`; obstacle confidence above `0.05` is about `23.14%`.
- Main demo image-space preflight stats after the rebake: raw wake above `0.05` remains about `18.54%`; raw eddy-line above `0.05` is about `2.42%`; gated wake above `0.05` is about `6.95%`; gated eddy-line above `0.05` is about `1.06%`; wake-edge-thinned eddy-line above `0.05` is about `0.99%`.
- Obstacle-test image-space preflight stats after the rebake: raw wake above `0.05` remains about `18.69%`; raw eddy-line above `0.05` is about `2.15%`; gated wake above `0.05` is about `6.95%`; gated eddy-line above `0.05` is about `0.95%`; wake-edge-thinned eddy-line above `0.05` is about `0.86%`.
- Exported atlas-space Phase 7A2 masks under `.codex-research/phase7a2_mask_preflight/` and 60 accepted Phase 0B camera captures under `.codex-research/phase7a2_wake_eddy_demo_debug/`.
- Validation passed with Godot 4.6.3: `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, `PHASE7A2_WAKE_EDDY_EXPORT_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, and `DEMO_SYSTEM_MAP_VALID=true`.
- No final-flow, visible river shader, WaterSystem flow shader, saved WaterSystem bake, terrain-contact threshold, or bank-response threshold changes were made. Actual reverse/circulating flow remains Phase 7C or later.

Phase 7B visual material preview update:

- Reviewed `.codex-research/phase7a2_wake_eddy_demo_debug/` and `.codex-research/phase7a2_mask_preflight/`; the wake and narrowed eddy-line placement looked good enough for a restrained material pass.
- Added `wake_ = "Wake / Eddy"` to the Waterways material inspector categories.
- Added shader-side `wake_visual_mask`, `wake_edge_thinness_at`, and `eddy_line_visual_mask` helpers in the visible and debug river shaders. The masks use existing `obstacle_features.g`, `obstacle_features.b`, `obstacle_features.a`, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, normalized final-flow strength, and source-tile wake-edge sampling.
- Added conservative material controls for wake/eddy gate thresholds, ordinary-bank suppression, edge sampling, eddy-line thinness, normal detail, roughness/specular breakup, albedo breakup color/strength, and small foam flecks.
- Added visual-only surface cues: downstream wake breakup, subtle normal/roughness changes, small high-noise foam flecks, and narrow eddy-line turbulence. The implementation does not redirect `flow`, alter `flow_force`, add reverse/circulating physics, touch WaterSystem flow shader wiring, or regenerate the saved WaterSystem bake.
- Added `Wake Visual Mask`, `Eddy-Line Visual Mask`, and `Wake Edge Thinness` debug modes and menu entries.
- Added ignored helpers `.codex-research/phase7b_wake_eddy_visual_probe.gd` and `.codex-research/export_demo_phase7b_wake_eddy_views.gd`.
- Added ignored CPU/readback helper `.codex-research/phase7b_eddy_line_cpu_diagnostic.gd` to reproduce the shader-side eddy-line formula from existing bake textures and report raw B/G/A, shared wake gating, edge gradient, nearby wake, edge thinness, and final retention across sample distances.
- Exported 60 Phase 7B review captures under `.codex-research/phase7b_wake_eddy_demo_debug/`.
- Initial editor review found `Eddy-Line Visual Mask` appears as a uniform green river. Treat this as a follow-up item: the final eddy-line visual mask is probably too suppressed, or the debug palette is too easy to misread, and it should be compared against raw `Eddy-Line / Shear Mask`, `Wake Visual Mask`, and `Wake Edge Thinness` before any Phase 7C flow work.
- CPU diagnosis of marked regions found that one-pixel-ish wake-edge sampling restores much more final eddy-line signal in expected rock/wake regions, while separate raw-B regions are still suppressed by low `wake_shared_gate`. Treat edge sample distance and shared-gate review as different problems.
- Additional user review of `Eddy-Line Visual Mask` found the current final view is void of eddies away from the river start. Do not count the start-of-river hotspot as a successful eddy-line result; the next sweep must produce plausible signal around rocks/protrusions and downstream wake margins.
- Added follow-up debug/export support for `Wake Shared Gate`, `Gated Eddy-Line Source (B * Wake Gate)`, and `.codex-research/phase7b_wake_edge_sample_sweep/`. The sweep confirmed that bigger edge sampling alone was not enough, which led to the gate-component and alternate-channel diagnosis below.
- Added gate-component and alternate-channel diagnostics after the sweep. The important finding was channel/phase alignment: raw `obstacle_features.b` was plausible but too far downstream from the close-behind-rock shoulders, while raw `obstacle_features.g` contained a better-distance wake-edge pattern.
- Promoted the accepted raw-G wake-edge candidate into `Eddy-Line Visual Mask` at the reviewed `wake_edge_sample_tiles = 0.024`. The final visual mask now uses paired wake-edge margins plus nearby wake/hard-protrusion context, while old raw-B views remain available as diagnostics.
- User review accepted the visible eddy-line placement after the material-override fix and stronger defaults. The result remains surface-only: no reverse/circulating flow, no source-signature bump, no river rebake, and no saved WaterSystem bake regeneration.
- Validation passed with Godot 4.6.3: `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_WAKE_EDDY_EXPORT_OK`, and `PHASE6B_PILLOW_TUNING_PROBE_OK`.

Adversarial review findings:

- Blind spot: a single eddy scalar does not encode eddy center, spin side, circulation radius, or reverse velocity. Do not infer stable reverse/circulating physics from `obstacle_features.g` or `.b` alone.
- Blind spot: `obstacle_features.a` confidence is broad, so it should be an envelope gate, not proof that wake or shear is localized. Require overlap stats for each gate and for the final composed masks.
- Blind spot: hard-boundary/protrusion gates help with rocks and cliffs but can also keep ordinary bank streaks alive near bends. Phase 7A should report separate coverage for ordinary-bank, hard-boundary, grade/energy, and flow-force gates so a broad bank artifact is visible in numbers.
- Failure mode: using eddy-line mask directly for foam will read like shoreline foam if it follows broad bank edges. The first visible Phase 7B should keep eddy-line foam as a narrow, noisy accent and should favor normal/roughness/turbulence before white foam.
- Failure mode: adding wake reach by looking downstream can cross UV2 atlas tile borders or smear across curved bends. Any reach/edge sampling should be expressed in source-tile units, clamp to the content rect, and be compared in accepted Phase 0B cameras before it becomes visible.
- Failure mode: shader-only visual flow accents can imply reverse motion while ducks and other buoyant objects still move downstream. Keep Phase 7B surface-detail-only, or explicitly label it as not physics-aligned until Phase 7D.
- Missing constraint: neutral black feature textures must produce no wake or eddy effect. Missing textures remain stale/invalid bake data under the current resource validation unless a later neutral fallback-texture pass is added.
- Simpler alternative: do not add a new eddy texture for Phase 7A. First build a CPU/Godot preflight that estimates the same candidate masks a future shader would use, exports debug images, and reports coverage and gate overlap. Only add bake data after those images show a real need.

Revised implementation idea:

- Build or refine an eddy seed from obstacle support, obstacle normal, flow direction, hard-boundary/protrusion response, ordinary-bank suppression, and river energy.
- Shape the wake as a tapered downstream region, but keep the eddy-line as a thin boundary band rather than a filled wake area.
- For visual-only cues, derive shader-side `wake_visual_mask` and `eddy_line_visual_mask` from `obstacle_features.g`, `obstacle_features.b`, `obstacle_features.a`, `bank_response_features.a`, ordinary-bank suppression, grade/energy, and normalized final-flow strength.
- For Phase 7A, implement that derivation first in a review helper rather than in the visible shader. Save raw wake, raw eddy-line, gated wake, gated eddy-line, wake-edge-thinned eddy-line, ordinary-bank suppression, hard-boundary/protrusion, grade/energy, final-flow strength, and overlap/composite views.
- For Phase 7B, keep visible changes to surface language: slower-looking downstream wake normal detail, subtle roughness/specular breakup, localized foam flecks, and narrow eddy-line turbulence. Do not redirect `flow`, do not alter `flow_force`, and do not touch WaterSystem output.
- For actual eddy flow, prefer a new explicit eddy-flow feature texture or a regenerated physics-facing flow field instead of pretending the current scalar masks contain enough information for stable spin direction and reverse velocity.
- If using an analytic vortex before adding new data, keep it review-only until it can be mirrored exactly between visible river debug and WaterSystem flow generation. Save no physics bake until the user has reviewed the visible direction change in game.

Recommended Phase 7 planning split:

1. Phase 7A0: adversarial review and roadmap revision. Completed in this pass. No runtime behavior, shader behavior, bake resources, source signatures, or WaterSystem data change.
2. Phase 7A1: review-only mask preflight/export. Complete. It added ignored helper scripts, exported accepted Phase 0B camera captures, printed raw/gated/overlap stats, and made no visible-water, bake, final-flow, or WaterSystem changes.
3. Phase 7A2: refine `obstacle_feature_mask_filter.gdshader` for eddy-line semantics before visible eddy-line foam/turbulence. Complete. It bumped the river bake source signature to `17`, rebaked main and obstacle-test river resources, refreshed stats, reran probes, and exported fresh review captures.
4. Phase 7B: visual-only downstream wake and eddy-line cues from accepted masks. Complete as a material preview. It added material controls for localized wake foam, eddy-line turbulence, normal/noise roughening, and subtle albedo/specular breakup without redirecting final flow, touching WaterSystem shader wiring, or regenerating WaterSystem data.
5. Phase 7C: actual reverse/circulating flow. Treat this as a separate final-flow milestone. Either add a new explicit eddy-flow feature texture/channel set, or derive an analytic vector field from accepted masks and mirror it in `river.gdshader`, `river_debug.gdshader`, and `system_renders/system_flow.gdshader`.
6. Phase 7D: WaterSystem/physics alignment. Regenerate and validate the saved WaterSystem bake only after final flow changes are accepted, so buoyancy and visible flow agree.

Phase 7 decision table:

- Debug-only mask review / capture refresh: no bake layout change, no source-signature bump, no WaterSystem regeneration.
- Ignored preflight/export helper scripts and new debug PNGs under `.codex-research`: no source-signature bump and no WaterSystem regeneration.
- Shader-only gated visual wake/eddy-line preview from existing `obstacle_features.g` / `.b`: no source-signature bump and no WaterSystem regeneration, as long as final flow and saved resources are unchanged. The accepted Phase 7B eddy-line preview uses a raw-G wake-edge candidate because it aligned better with the source rocks than the older raw-B exact-gate path.
- Changing `obstacle_feature_mask_filter.gdshader` thresholds, semantics, wake length/width, or eddy-line derivation: source-signature bump, main and obstacle-test rebakes, updated metadata/stats, probe updates, and fresh captures.
- Adding a new eddy vector/strength texture: `RiverBakeData` layout update, material wiring, debug modes, validation/export script updates, source metadata, source-signature bump, rebakes, and capture review.
- Changing final flow, reverse/circulating flow, or physics-facing maps: visible shader, debug shader, system-flow shader, WaterSystem regeneration, validation, and in-game buoyancy review.

Recommended next action:

Use the Phase 7B eddy-line fix as the model for any remaining pillow placement review. The first pillow follow-up found the visible forward offset in shader-side reach and changed the default reach to `0.0`; later reviews found raw R still too far ahead, so Phase 6D moved the raw pillow classifier closer to hard contact/protrusion support and Phase 6E halved the contact-search distance. The current river resources are signature `19`. A formula review and the 2026-05-30 pillow audit then found that the remaining offset can still come from the effective anchor stack: `pillow_contact_gate_at()` samples a hard-boundary term that includes forward-looking `bank_response.a`, and `pillow_source_at()` still uses the broad dilated collision support. Add the audit-recommended diagnostic split, review the refreshed raw/final/source-term pillow masks in live viewport, and only then change classifier constants. Do not do material-strength, foam, or height tuning until placement is accepted. Only start Phase 7C after the user explicitly wants real reverse/circulating flow; that milestone must update visible/debug final-flow logic and WaterSystem generation together.

Next-session triage order:

1. Review the signature-`19` halved-distance contact-anchored `Pillow / Impact Mask` in live viewport at upstream impact faces of rocks/protrusions and "should not detect" controls ahead of those rocks, downstream wakes, and smooth banks.
2. Compare `Pillow / Impact Mask`, `Pillow Visual Mask`, `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, terrain contact, and final-flow strength at the same targets.
3. Keep `pillow_forward_reach_tiles = 0.0` while judging placement so the old shader reach does not confuse the raw classifier review.
4. Add or use the audit-recommended split before reducing the same contact distance again. Compare support/facing, direct `terrain_contact.b`, `bank_response.a`, combined pillow contact gate, and bank-only contribution.
5. If the split proves bank-response anchoring is the cause, make direct `terrain_contact.b` or a tight local direct-contact search mandatory or near-mandatory for raw R, and keep `bank_response.a` as context only.
6. If the split proves support/facing starts too early, tighten pillow-specific support or thresholds without globally reducing `baking_dilate`.
7. If placement is accepted but the pillow now reads too sparse or subtle, tune shader-only gates/material response before considering any bake changes.
8. Preserve the accepted Phase 7B eddy-line behavior while working on pillows; do not touch final flow, WaterSystem output, or Phase 7C unless explicitly scoped.

## Phase 8: Visual Flow And Physics Together

Goal: objects move according to the same river the player sees.

The WaterSystem map already bakes flow for buoyant objects. Once grade, bends, actual flow-map corrections, pillows, and eddies affect the final flow, regenerate the system map so physics receives:

- faster chute flow.
- slower pools.
- outside-bend pull.
- obstacle deflection.
- eddy circulation.

This is especially important for ducks, kayaks, debris, and any future player-controlled craft.

## Phase 9: Authoring Controls

Goal: make the system usable without hand-editing shader constants.

Suggested controls:

- `grade_influence`
- `bend_influence`
- `obstacle_deflection`
- `pillow_strength`
- `pillow_wave_strength`
- `eddy_strength`
- `eddy_size`
- `eddy_spin_bias`
- `foam_energy_bias`
- `debug_feature_view`

Defaults should produce a good river without requiring manual tuning.

## Phase 10: Later Features

These should wait until grade, bends, obstacles, actual flow-map corrections, pillows, and eddies are working:

- Standing waves downstream of rocks.
- Holes/hydraulics below ledges.
- Boils and whirlpools in high-energy convergence zones.
- Strainers and undercut hazards as gameplay features.
- Sediment bars on inside bends.
- Terrain carving, bed shaping, and wet-bank generation beyond the Phase 0 contact masks.
- Compute-shader shallow-water simulation for selected hero areas.

## Recommended Next Milestone

Review the signature-`19` halved-distance contact-anchored pillow classifier in the editor viewport using the audit-recommended diagnostic split. The first diagnosis identified shader-side `pillow_forward_reach_tiles = 0.075` as the source of the obvious ahead-of-rock visual offset and changed the default to `0.0`; later raw-classifier passes tightened `obstacle_features.r` and halved the contact-search distance after review showed raw/visible pillows still too far ahead. The current review finding is that the explicit contact-search distance is only one part of the start rule: the contact gate can still accept forward-looking `bank_response.a`, and the pillow source still uses broad dilated collision support. The pillow audit adds quantitative evidence that bank-response anchoring is defining too much of raw R, so diagnostics should come before another classifier edit.

Start with `Pillow / Impact Mask`, `Pillow Visual Mask`, `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, terrain contact, and `Final Flow Strength`, but add direct diagnostic views/probe output for support/facing, direct protrusion contact, bank-response anchoring, contact-gate contribution, and bank-only contribution before changing classifier constants. If placement is accepted, any next pillow work should be shader-only material/gate tuning; if raw/no-reach placement is still wrong, plan a focused classifier pass using direct-contact-first anchoring. Do not touch final flow, WaterSystem flow, reverse/circulating physics, or saved WaterSystem bake unless explicitly scoped.

## Godot Verification Setup

Set these per machine before running scripted probes:

- Console/script runner: `$godotConsole`, or environment variable `GODOT_CONSOLE`.
- GUI editor: `$godotEditor`, or environment variable `GODOT_EDITOR`.

When launching Godot from Codex for headless or scripted probes, route `APPDATA` and `LOCALAPPDATA` into the repo's ignored `.codex-research` folder. Godot may write editor data, config, cache, logs, or shader cache files under AppData, and keeping those writes inside the repo-local research folder avoids touching the normal user profile.

PowerShell pattern:

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Path\To\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://<path-to-probe>.gd'
```

## Sources Read

The categorized source index now lives in `../research/river-research-citations.md`. Future research sessions should add citations there with short Waterways-specific notes instead of extending a phase roadmap appendix.

## Phase 6 Research Notes

- Pillows are upstream impact features, so the first visual pass should emphasize local compression, brighter specular/refraction response, and tightened normal detail on the obstacle-facing side.
- Boulder-flow research supports keeping submergence/contact and energy in the gate: partially submerged or hard protruding obstacles can produce stronger near-surface disturbance than ordinary shallow banks.
- Flow-map production examples support the existing Waterways approach: keep low-resolution vector/feature fields inspectable, then use shader-time normal, noise, and phase offsets to hide repetition and localize the look.
- Obstacle foam in other engines is often distance-field driven. Waterways already has saved obstacle, terrain-contact, and bank-response textures, so Phase 6A should consume those instead of adding a screen-only or engine-specific distance-field dependency.
- Foam should be tuned as a high-energy accent. Broad foam is more likely to read as shoreline/wake noise than as a pillow, and would blur the boundary between Phase 6 pillows and Phase 7 eddies.
- Distance-field flow-map examples generally separate the upstream/high-pressure facing side from downstream low-pressure wake/curl zones by comparing obstacle gradients with flow direction. Waterways already approximates that split in `obstacle_features.r` versus `.g`/`.b`; Phase 6B should preserve that distinction.
- The accepted Phase 7B eddy-line fix is a useful warning for Phase 6 pillows: if the pillow appears far ahead of the source rock/protrusion, first verify the raw/channel placement and shader reach phase before tuning visual strength. A plausible feature channel can still be spatially wrong for the visible feature.
- The Phase 6F pillow review adds a second warning: a named distance constant may not describe the effective visual reach when it samples a compound context channel. For pillows, the explicit contact search samples `hard_boundary_at()`, and that hard-boundary term can already include forward protrusion context from `bank_response.a`.
- Open-source and tutorial water shaders repeatedly use depth fade, screen refraction, normal distortion, and optional vertex waves/displacement as separate layers. In Waterways, pressure/highlight/normal/band tuning is the low-risk layer; vertex displacement is a later experiment because it can disturb depth/refraction and mismatch buoyancy.
- Systems that feed flow into physics, such as Crest-style flow inputs, reinforce the Waterways rule: only regenerate or alter WaterSystem data when the final flow field changes. Pillow material accents alone should stay out of physics.

## Phase 7 Research Notes

- Eddies should be represented as at least two concepts: a downstream wake/core where water slows or reverses, and an eddy-line boundary where the main current shears against that slower/reverse flow. The current `obstacle_features.g` / `.b` split is directionally correct, but `.b` is not thin enough yet for direct use.
- Production water systems commonly keep a scalar surface-detail layer separate from the velocity/physics layer. For Waterways, Phase 7B can stay visual-only, while Phase 7C/7D must share final-flow logic with the WaterSystem bake.
- Distance-field and current-map examples support deriving local visual flow changes from obstacle gradients, but they also warn that oversized influence radii or unbounded vector magnitudes cause stretched flow-map texture artifacts. This matches the current caution around broad eddy-line bands.
- Unity HDRP and Epic baked river examples both expose debug views or baked textures for current, deformation, foam, and physics interaction. Phase 7 should add review/probe steps before material accents, then regenerate physics only after final flow changes.
- Crest's whirlpool API is a useful design reference because it separates displacement, flow advection, radius, swirl, maximum speed, and dynamic-wave damping. A future Waterways eddy control set should make the same separation: visual wake, eddy-line turbulence, reverse-flow strength, radius, spin bias, and physics export.
- Hydrology literature suggests submergence/blockage and channel confinement change wake and recirculation size. Waterways has proxies for those conditions in `terrain_contact_features`, `bank_response_features`, grade/energy, and final-flow strength, so Phase 7 should use those existing gates before adding new data.

## Phase 4 Research Notes

- Boreal River Rescue describes pillows as upstream mounds where current presses into rocks or cliff walls, and describes eddies as downstream void/backfill zones with turbulent eddy lines. This maps cleanly to separate upstream impact, downstream wake, and eddy-line masks.
- Kauffman's river dynamics chapter treats pillows, holes, and eddies as related outcomes of obstacle depth, exposure, and width. This supports keeping a simple feature classifier first, with holes/hydraulics deferred until the addon has a reliable wake/eddy seed mask.
- Cali Paddler breaks eddies into filling, standing, and flushing zones, with a distinct eddy line between downstream current and upstream circulation. That suggests eddy masks should not be a single blob forever; the first bake can store wake/seed and shear separately.
- Valve's flow-map work reinforces the Waterways direction: use low-resolution flow fields and procedural masks, keep normal animation shader-driven, and eventually share final flow data with physics. For Phase 4, that means debug and feature masks should be inspectable before they influence the WaterSystem flow map.

## Further Research

Codex is allowed to search online during the research and planning phase before implementation. Useful sources include research papers, white papers, GDC/SIGGRAPH talks, GitHub codebases, Godot tutorials, other game-engine tutorials, shader writeups, and practical river/water rendering or simulation articles. Prefer sources with concrete algorithms, data layouts, tuning guidance, or production examples that can be adapted to Waterways without overcomplicating the addon.

Hydrology and river feature behavior:

- Bend hydraulics: outside-bend erosion, inside-bend deposition, helicoidal flow, and secondary circulation.
- Eddy anatomy: eddy core, eddy fence/eddy line, upstream-flow regions, downstream leakage, and wake shape behind obstacles.
- Pillows and compression waves: relation to obstacle size, current speed, submergence, and water depth.
- Holes/hydraulics: when water recirculates vertically after a ledge or submerged obstacle.

Real-time rendering and flow maps:

- Valve-style flow-map normal advection, especially two-phase blending and noise offsets.
- Tiled directional flow methods for reducing obvious texture repetition on long rivers.
- Authoring or procedural generation of vector fields around obstacles.
- Multi-channel feature textures for foam, turbulence, pressure, and local wave detail.

Godot-specific implementation:

- RenderingDevice or compute-shader options for optional high-end flow-field generation.
- Efficient editor-time bake previews and debug overlays.
- System-map sampling accuracy for buoyant objects.
- How to keep generated bake resources stable for export and F6 runs.

Possible later simulation research:

- 2D shallow-water equations for small hero sections.
- Lattice Boltzmann or grid-based flow solvers for obstacle wakes.
- Hybrid approach: baked procedural flow for the whole river, lightweight simulation only around interactive obstacles.
