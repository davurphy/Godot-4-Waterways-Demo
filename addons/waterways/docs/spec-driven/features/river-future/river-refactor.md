I’d treat these as three symptoms of the same deeper problem: the system needs a more reliable **river-space field representation** before adding waterfalls/rapids/displacement.

The fix order I’d use:

1. **Fix seams first**
   The current UV2 tiled atlas is fragile. Even with padded margins, every segment boundary can disagree in flow, masks, normals, foam, and height. I’d move toward a continuous river-space coordinate system: `u = across river`, `v = distance along river`, with either a long strip texture or procedural river coordinates. If the atlas stays, every bake pass must sample cross-tile neighbors through a shared “river neighbor lookup,” not raw texture offsets.

2. **Separate decorative objects from flow obstacles**
   Right now, objects sitting on or near the river can pollute the bake. I’d add explicit object roles:
   `Ignore Water Bake`, `Visual Only`, `Submerged Shallow`, `Hard Flow Obstacle`, `Bank Protrusion`.
   Flow should not infer all of this from whatever collider happens to be hit. A rock prop with a collider should only distort flow if it is marked as a water obstacle or included in a water-obstacle layer.

3. **Replace object handling with a real waterline obstacle mask**
   For rocks protruding from banks or out of the river, the system needs a 2D top-down obstacle field at the water surface, not just vertical ray hits. For each river sample, classify:
   `open water`, `shallow submerged`, `hard protrusion`, `bank edge`, `ignored`.
   Then flow steering should solve around the hard protrusion mask before visual pillows/wakes are generated.

For the flow issue specifically: I would stop relying on local normal steering alone. Around a series of rocks, local steering can create small bends but still leave channels that point through obstacles. I’d add a stronger pass:

- build hard obstacle mask
- dilate it into an avoidance field
- compute a distance/gradient field
- advect/relax flow downstream while enforcing “do not enter hard mask”
- preserve a minimum downstream component
- generate pillows/wakes after this corrected flow exists

So the order becomes:

`river shape -> waterline obstacle classification -> corrected flow field -> bank/shallow drag -> pillows/wakes/foam -> visual shader`

The big design principle: **objects should affect flow only through explicit, height-aware water-interaction data.** Then seams become a coordinate problem, artifacts become a classification problem, and bad flow becomes a solver/steering problem instead of endless shader tuning.


I’d treat these as three symptoms of the same deeper problem: the system needs a more reliable river-space field representation before adding waterfalls/rapids/displacement.

The fix order I’d use:

Fix seams first
The current UV2 tiled atlas is fragile. Even with padded margins, every segment boundary can disagree in flow, masks, normals, foam, and height. I’d move toward a continuous river-space coordinate system: u = across river, v = distance along river, with either a long strip texture or procedural river coordinates. If the atlas stays, every bake pass must sample cross-tile neighbors through a shared “river neighbor lookup,” not raw texture offsets.

Separate decorative objects from flow obstacles
Right now, objects sitting on or near the river can pollute the bake. I’d add explicit object roles:
Ignore Water Bake, Visual Only, Submerged Shallow, Hard Flow Obstacle, Bank Protrusion.
Flow should not infer all of this from whatever collider happens to be hit. A rock prop with a collider should only distort flow if it is marked as a water obstacle or included in a water-obstacle layer.

Replace object handling with a real waterline obstacle mask
For rocks protruding from banks or out of the river, the system needs a 2D top-down obstacle field at the water surface, not just vertical ray hits. For each river sample, classify:
open water, shallow submerged, hard protrusion, bank edge, ignored.
Then flow steering should solve around the hard protrusion mask before visual pillows/wakes are generated.

For the flow issue specifically: I would stop relying on local normal steering alone. Around a series of rocks, local steering can create small bends but still leave channels that point through obstacles. I’d add a stronger pass:

build hard obstacle mask
dilate it into an avoidance field
compute a distance/gradient field
advect/relax flow downstream while enforcing “do not enter hard mask”
preserve a minimum downstream component
generate pillows/wakes after this corrected flow exists
So the order becomes:

river shape -> waterline obstacle classification -> corrected flow field -> bank/shallow drag -> pillows/wakes/foam -> visual shader

The big design principle: objects should affect flow only through explicit, height-aware water-interaction data. Then seams become a coordinate problem, artifacts become a classification problem, and bad flow becomes a solver/steering problem instead of endless shader tuning.