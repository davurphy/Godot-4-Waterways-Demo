# Future Ideas

This document is a parking lot for later river-system ideas. These notes are not current implementation commitments.

## Open-World River Ripple Methods

The current ripple-field design is a local authoring model: one bounded simulation area around the river section being reviewed. That is useful for a demo scene, a crossing, a dock, a combat space, or any other contained gameplay area.

For a massive open-world river, a single enormous `world_bounds` box would not be a good fit. The ripple texture would have to cover too much world space, so detail would become blurry unless the texture resolution increased dramatically. Higher resolution would cost more GPU memory and compute time, while much of the texture might still cover land or river areas where no local interaction is happening. Distant emitters would also compete for the same simulation budget, and world streaming or floating-origin systems would need special handling so ripple coordinates stay stable.

Better open-world approaches should be considered later.

### Tiled Ripple Fields

Split large rivers into multiple `WaterRippleField` zones. Each field can cover a river segment, bend, crossing, dock, waterfall base, settlement edge, combat area, or other local point of interaction.

Emitters would target the nearest or most relevant active field instead of one global field. This keeps texture detail local, limits wasted simulation area, and makes it easier to stream ripple zones in and out with world chunks.

Important future questions:

- How emitters choose a field when several overlap.
- How ripples behave at tile boundaries.
- How fields stream, sleep, wake, and clean up.
- Whether adjacent fields need blending or handoff behavior.

### Player-Following Ripple Field

A ripple field could follow the player, camera, or active gameplay focus. This keeps simulation resolution concentrated near the area the player can inspect.

This approach is attractive for local interactions, but it needs careful design. Moving the field can cause visible popping unless old ripple data is reprojected, faded, or cleared in a controlled way.

Important future questions:

- How far the field can move before reprojection or clearing.
- Whether ripple history should survive field movement.
- How to avoid visible pops when the field shifts.
- How this interacts with fast travel, streaming, and floating origin.

### Hybrid Local And Distant Effects

Use high-detail ripple fields only near gameplay, and use cheaper shader-only effects for distant river surfaces. Distant water can rely on flow maps, scrolling normals, broad wakes, foam, eddies, or other non-simulated details.

This keeps interaction quality high where the player notices it, without paying full ripple-simulation cost across an entire open-world river network.

Important future questions:

- Which distances or gameplay states activate local ripple fields.
- How local simulated ripples blend into cheaper distant water effects.
- Whether distant effects need to react to boats, weather, or scripted events.
- How boundary previews and emitter routing should communicate active zones to designers.

### Recommended Direction

Avoid solving open-world support by making one `world_bounds` box huge. Prefer tiled or streamed ripple fields, possibly combined with a player-following field for local interactions and cheaper shader effects for distant rivers.

Before building this, future work should first design boundary previews and emitter routing so designers can see which parts of the river are ripple-enabled and which field an emitter will target.

## Ripple Visual Tuning Phase

The current accepted ripple pass is intentionally conservative: localized runtime ripples affect visible normals, while refraction, displacement, stronger response shaping, foam coupling, flow-aware behavior, WaterSystem data, bakes, source signatures, and buoyancy remain untouched.

A later tuning phase should focus on how ripples read in the final water material after the runtime field, emitter workflow, boundary masking, debug views, and editor authoring tools are stable. This should be treated as visual tuning, not as a physics or flow milestone.

Potential tuning areas:

- Normal response:
  - Tune `normal_strength`, ripple slope scale, sample spacing, and blend behavior against existing flow-map normals.
  - Keep the base river motion, pillows, wakes, and eddy-line details recognizable.
  - Check whether strong ripple normals make water appear to change direction even though flow and buoyancy are unchanged.
- Refraction response:
  - Decide whether ripple height or ripple-derived normals should influence screen refraction.
  - Keep refraction subtle enough that shallow banks, rocks, and transparency do not shimmer or crawl.
  - Validate Forward+, Mobile, and Compatibility renderer behavior before exposing user-facing controls.
- Displacement response:
  - Keep displacement default-off until mesh density, silhouette quality, seam behavior, shallow-water artifacts, and buoyancy mismatch are accepted tradeoffs.
  - Restrict any first displacement pass to close-range or hero-use cases.
  - Avoid implying that visual displacement changes object floating height or WaterSystem height.
- Height and distance fading:
  - Tune `height_fade_distance`, boundary fade, camera-distance fade, and shallow-water fade so ripples blend out naturally at banks and far views.
  - Check that ripples do not pop at field edges, boundary-mask edges, or tiled field boundaries.
- Impulse and decay feel:
  - Tune damping, propagation, pulse cadence, emitter radius, falloff, and intensity families for readable rings without flooding the whole field.
  - Keep performance budgets for 128, 256, and 512 fields visible during tuning.
- Material interaction:
  - Consider optional ripple-driven roughness, specular, foam flecks, or micro-normal response only after normal/refraction behavior is accepted.
  - Keep these as visual accents; do not let them become hidden flow, whitewater, or physics signals.

Important future questions:

- Which review scenes prove ripple tuning across calm, fast, shallow, obstructed, and bank-adjacent water?
- Should tuning controls live on `WaterRippleField`, the river material, or a separate visual profile resource?
- Which settings are safe for built-in presets, and which should remain advanced?
- How should debug views show ripple height, slope, refraction influence, displacement influence, and final visible contribution?
- What renderer-specific fallback is needed if refraction or displacement is too expensive or inconsistent?

Recommended direction:

Start with a normal/refraction tuning plan that leaves displacement off. Prove visual quality, shader cost, and renderer compatibility before exposing any new normal/refraction controls broadly. Treat displacement as its own later review gate.

## Ripple Preset Families

Current ripple presets are value starters: applying one copies ordinary field or emitter values, and there is no live profile link. Future preset work can build on that model with practical interaction families for gameplay authors.

The goal is for a designer to choose a recognizable interaction type, apply it, then still inspect and adjust the ordinary field or emitter properties. Presets should not save runtime textures, target material state, river bakes, WaterSystem data, source signatures, buoyancy behavior, or live links.

### Character And NPC Water Interaction

Character and NPC presets should help common movement in shallow or mid-depth water:

- `Character Footstep - Shallow`:
  - Small one-shot or short pulse rings.
  - Low radius, low-medium intensity, quick decay.
  - Intended for ankle-deep water, puddle-like edges, and exposed shallows.
- `Character Wading Trail`:
  - Moving emitter with short dense pulses.
  - Medium radius, moderate intensity, moderate decay.
  - Intended for walking through knee-to-waist-depth river water.
- `NPC Ambient Wading`:
  - Lower intensity and lower priority than player interaction.
  - Useful for background agents that should not overpower the player.
- `Player Sprint Splash Trail`:
  - Faster pulse cadence and stronger impulses than ordinary wading.
  - Needs velocity-aware scaling or script-side intensity changes before it feels right.

Important future questions:

- Should footstep emitters be triggered by animation events, physics contacts, or script calls?
- Should intensity scale with character speed, mass, water depth, or slope?
- How should multiple NPCs be capped so they do not saturate the field?

### Creature And Object Size Ripples

Object and creature presets should scale by size, mass, speed, and whether the source is entering, moving through, or leaving the water.

Suggested size tiers:

- `Tiny Ripple`:
  - Small insects, drips, pebbles, tiny debris.
  - Very small radius, low intensity, fast decay.
- `Small Object Ripple`:
  - Small rocks, thrown items, hands, small animals, light debris.
  - Small-medium radius, medium intensity, short-medium decay.
- `Medium Object Ripple`:
  - Human-sized object entry, crates, medium creatures, heavy footsteps.
  - Medium radius, stronger intensity, more visible propagation.
- `Large Object Ripple`:
  - Large creatures, heavy dropped objects, big debris, strong impacts.
  - Large radius, high intensity, longer decay, stricter cap/priority handling.
- `Huge Impact / Boss Step`:
  - Hero-use preset only.
  - Requires careful performance and readability review so it does not flood the whole field.

Important future questions:

- Should these be one-shot emitter presets, field presets, or paired field/emitter preset bundles?
- Should impact intensity be script-driven from mass and velocity rather than a fixed preset value?
- Should large impacts add optional foam or splash decals later, or stay ripple-only?

### Wakes And Moving Bodies

Wakes are more than ordinary circular ripples. The current moving emitter can create a dense trail, but convincing character, creature, and boat wakes likely need later emitter shapes or scripted emission patterns.

Potential wake presets:

- `Character Wake`:
  - Narrow moving trail behind a walking or swimming character.
  - Could start with dense moving point impulses, then later use capsule or trail emitters.
- `NPC Wake`:
  - Similar to character wake but lower intensity and lower priority.
  - Designed for groups of background actors.
- `Creature Wake - Small / Medium / Large`:
  - Width, pulse cadence, and intensity scale with creature size.
  - Larger variants may need multiple emitters along the body or a capsule/stamp emitter shape.
- `Boat Wake - Small`:
  - Future trail or V-shaped pattern, not just a circular pulse.
  - Should remain visual-only until boat physics/water response is separately planned.
- `Oar / Paddle Stroke`:
  - Directional local disturbance from each stroke.
  - Likely needs a short capsule or stamp shape plus timing from animation events.

Important future questions:

- Do wake presets require new emitter shapes such as trail, capsule, disc, stamp, or V-wake?
- Should wake direction come from node velocity, animation events, or explicit script parameters?
- How should wakes blend with river flow normals so they look carried by water without changing final flow?
- When many actors are present, how should wake emitters sleep, cap, or merge?

### Field Preset Pairings

Some use cases may need a field preset and an emitter preset together. For example, a shallow-footstep setup may want a low-cost local field plus several small footstep emitters, while a large-creature setup may want a larger field, higher emitter cap, slower decay, and stronger normal response.

Potential paired designs:

- `Shallow Crossing Interaction Set`:
  - Performance-minded field, shallow footstep emitters, quick decay.
- `Dock / Town Interaction Set`:
  - Medium local field, NPC ambient wading, small object drops.
- `Combat Water Interaction Set`:
  - Higher cap field, player sprint trail, medium impacts, large impact priority.
- `Creature Encounter Interaction Set`:
  - Large local field, creature wake, large step/impact emitters.
- `Rain And Drips Interaction Set`:
  - Higher emitter cap but low individual intensity.
  - Needs batching or specialized rain emission before it is production-ready.

Important future questions:

- Should paired designs become a new resource type, or should they stay documented combinations of existing field/emitter presets?
- If bundles are added, how do they avoid becoming live links or hidden scene dependencies?
- How should bundles apply to multiple selected nodes without confusing undo/dirty-state behavior?

### Recommended Direction

Start with preset families that current point/ring and moving emitters can support: shallow footsteps, wading trails, NPC ambient movement, small/medium/large object impacts, and debug-strength review presets.

Defer boat wakes, creature body wakes, oar strokes, dense rain, foam coupling, and directional trail/stamp/capsule presets until matching emitter shapes, batching behavior, validation scenes, and editor controls are planned.
