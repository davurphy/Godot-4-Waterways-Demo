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
