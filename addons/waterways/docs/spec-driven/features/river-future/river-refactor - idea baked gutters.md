atlas_column_clamp.gdshaderinc exists, six filter shaders include
  it, filter_renderer.gd threads the atlas_columns parameter through, and the tile-bleed probe verified exactly zero
  cross-tile contamination. So the question is really "was that good design, and is it worth extending" — and there I'd
  say: yes with caveats worth knowing.

  What makes it good design:
  - It encodes a real invariant of the data model in exactly one place. The UV2 atlas packs world-disjoint river
  stretches into adjacent tiles; therefore any neighborhood read must respect tile boundaries. That rule now lives in
  one shared include rather than being re-derived (or forgotten) per shader — the shader equivalent of a shared utility
  function.
  - It's opt-in and backwards compatible: atlas_columns = 1.0 is a no-op, so any non-atlas consumer of those filters is
  untouched.
  - It's cheap (a floor and a clamp per offset sample) and it followed an idiom the codebase had already
  half-established — flow_pressure_pass was already column-aware.
  - It has a regression probe with a stable success marker, so future changes can't silently reintroduce the bleed.

  The honest caveats:
  - It's a clamp, not a correct neighbor lookup. Near a tile edge, offset reads get edge-extended rather than redirected
  to the world-correct neighbor (which does exist — it's just in a different atlas location). The margins + edge-sync
  machinery covers logical continuity, so visually this holds up, but it's a principled approximation, not exactness.
  - The column bands use uniform fractions while real tile rects use a floor partition — up to ~1–2 px misalignment,
  absorbed by padding. Fixable with exact tile-rect uniforms if it ever matters.
  - The deeper critique: the clamp treats a symptom of the atlas layout itself. The textbook-correct designs are baked
  gutters (each tile carries its own border padding, making plain sampling safe) or a Texture2DArray (one layer per step
  — no spatial adjacency at all). Either would delete the need for consumer-side clamping entirely, but both are big
  migrations: mesh UV2 encoding, every shader, the bake pipeline, and the existing seam-stitch machinery. I wouldn't pay
  that cost while the clamp is measurably sufficient.

  If you want to extend the pattern, the highest-value move is applying the same discipline to the runtime shaders:
  river.gdshader and river_debug.gdshader do their own atlas-space offset searches (pillow contact reach, wake edge
  taps, eddy context probes, bank-friction edge) with only a global clamp(uv, 0, 1) — the same class of cross-tile read
  the filters had. The existing pillow "seam guard/stitch" uniforms are point-wise patches for exactly this; a shared
  tile-aware clamp there would unify them under one rule. That's a contained, well-scoped follow-up in the same spirit,
  and a natural companion to Phase 3 when you return to this feature.