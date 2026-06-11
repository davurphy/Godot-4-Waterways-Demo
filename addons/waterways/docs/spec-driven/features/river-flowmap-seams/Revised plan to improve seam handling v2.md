# Revised Plan to Improve Seam Handling (v2)

Date: 2026-06-11

## Relationship To The Existing Plans

This document supersedes [Revised plan to improve seam handling.md](Revised%20plan%20to%20improve%20seam%20handling.md) (referred to below as "the v1 revision") and sits alongside [Plan to improve waterways seam handling.md](Plan%20to%20improve%20waterways%20seam%20handling.md) (referred to below as "the original plan"). It was produced by an adversarial review of the v1 revision, with every architectural claim verified against the current code. Where this document cites a file and line, that citation was checked on 2026-06-11.

The v1 revision's instincts carry forward: falsify before building, verify mesh normals/tangents, verify temporal behavior, and treat the visible review as a front-loaded diagnostic rather than a final step. What changes here:

- The strip-packing spike is demoted from an unconditional early step to a conditional branch, because the evidence does not yet show that the joins it fixes are the joins that seam.
- A protection-coverage analysis of the actual shader offsets identifies a smaller unprotected class — lateral cross-column reads — with a correspondingly smaller fix that neither prior plan names.
- A new data-level hypothesis is added — depth-1 bilinear bleed — which neither prior plan covers and which no proposed fix in either plan would address.
- The spike checklist, ablation list, and classification taxonomy are corrected and completed.

## What Carries Over Unchanged

From the original plan and the signature 23 work, unchanged:

- The signature 23 bake-side fixes: floor-partition UV2 tile classification in `_get_uv2_world_sample()`, vertex-aligned grade/bend generation, and exact duplicated-edge-row synchronization for `flow_foam_noise`, `dist_pressure`, `obstacle_features`, and `bank_response_features`.
- Pillow seam fades stay cosmetic and off by default (`pillow_height_tile_seam_fade = 0.0`, `pillow_material_tile_seam_fade = 0.0`, `river.gdshader:92-93`).
- WaterSystem stays a separate longer-term global track, not part of this seam fix.
- The selective-prebake review (original plan section 5) remains the right follow-up once sampling is settled.

From the v1 revision, carried forward with corrections noted below:

- Front-loaded visual classification and ablation before any structural build.
- Mesh normal/tangent verification.
- Temporal verification (demoted to a quick confirmation; see Correction 5).
- Adaptive atlas aspect as a real option (gated differently; see Correction 1).

## Verified Architecture Facts This Plan Relies On

These were verified by code inspection and are stated here so later steps can cite them:

1. The UV2 atlas is square: `calculate_side()` returns the ceiling square side (`water_helper_methods.gd:376-381`). Steps map column-major: `column = step / side`, `row = step % side` (`water_helper_methods.gd:521-522`).
2. The demo bakes are 17 and 18 occupied steps at `uv2_sides = 5`, texture size 358 with a 256 content rect, signature 23 (seam audit, verified probe section). Per-tile resolution is an emergent `resolution / side` ≈ 51 px — it is not an explicit parameter anywhere.
3. Vertices at step joins are duplicated with differing UV2 (`water_helper_methods.gd:784-789`), and normals/tangents are recalculated per-surface by `st.generate_normals()` / `st.generate_tangents()` (`water_helper_methods.gd:791-792`). Because the duplicated join vertices differ in UV2, SurfaceTool will not merge them, so the normal/tangent basis can be discontinuous at every step join.
4. The debug shader is `render_mode unshaded` (`river_debug.gdshader:4`) and the seam-positive debug views render static baked data. A seam visible in a debug view therefore cannot be a lighting/tangent artifact and cannot be temporal.
5. Per-pixel phase noise is applied: `flow_foam_noise.a` offsets the flow time at `river.gdshader:968` and feeds the dual-phase `FlowUVW` blend (`river.gdshader:155-165`, `974-982`). `textures/flow_offset_noise.png` exists in the repo but is referenced by no shader; it is dead weight, not evidence of a missing mechanism.
6. The largest longitudinal shader offset is 0.70 tiles (`EDDY_CONTEXT_UPSTREAM_FAR_TILES`, `river.gdshader:149`). `_add_uv2_column_continuation_margins()` fills one full tile of wrap-neighbor data into the top/bottom margins (`water_helper_methods.gd:1509-1537`). Longitudinal offsets at row-wrap joins are therefore already data-protected with margin to spare.
7. Interior column edges in X have no margin — adjacent columns sit texel-to-texel. Lateral offsets such as `EDDY_CONTEXT_LATERAL_TILES = 0.14` (`river.gdshader:150`) can cross an interior column edge near a bank and read a step roughly `side` steps away. This is the genuinely unprotected offset class.
8. Every offset helper is gated by a runtime uniform that short-circuits sampling at zero: `flow_hard_boundary_slide` (`river.gdshader:47`, applied at `:710`), `wake_edge_sample_tiles` (`:106`, short-circuit at `:564`), `pillow_height_smoothing_tiles` (`:90`, short-circuit at `:420`), among others. Ablation needs no shader edits.
9. Several pillow offset uniforms default to zero (`pillow_forward_reach_tiles = 0.0`, `pillow_contact_pull_strength = 0.0`) and cannot be the live cause unless the demo materials override the defaults.
10. The signature 23 probes report zero delta at edge depth 0, but large depth-1/2 deltas remain in terrain-contact channels. The audit calls these "legitimately different"; that claim is asserted, not proven.
11. The user-observed seam-positive view list in `symptoms and initial suspects.md` predates the signature 23 fixes. No one has re-observed the visible seams since. The visible problem may already be partly or fully gone.

## Corrections To The v1 Revision

### Correction 1: The Strip Fixes 3 Of 16 Joins — Gate It On Evidence, Not Cost

For the 17-step demo river at `uv2_sides = 5`, only the joins at steps 4→5, 9→10, and 14→15 are row-wrap joins. The other 13 are same-column joins, which strip packing leaves byte-identical. If the visible seams appear at most or all joins, row-wrap geometry cannot be the cause and the strip fixes nothing visible.

The v1 revision's decision rule for Build A was "if the spike is small enough" — it gates on implementation cost. The correct gate is conjunctive:

> Build A proceeds only if (a) the diagnosis localizes visible seams to row-wrap joins and/or column X-edge bands, **and** (b) the feasibility spike comes back small.

The strip may still be worth doing later as a simplification (it removes the entire row-wrap and column-edge machinery), but that is a refactor justification to be argued on its own merits, not a seam fix.

The v1 revision's "zero shader cost" claim is also corrected: per-fragment cost is unchanged, but the UV2 remap needs a `vec2` grid uniform in at least four shaders, so it is not zero shader *change*.

### Correction 2: The Unprotected Offset Class Is Lateral, And The Minimal Fix Is A Clamp

Protection coverage of the actual offsets (facts 6 and 7 above):

- **Longitudinal offsets at row-wrap joins: already protected.** The continuation margins carry one full tile of the true logical neighbor's data, and no current offset exceeds 0.70 tiles.
- **Lateral offsets crossing interior column X edges: unprotected.** These read a non-logical step's data in a band along the banks of segments that sit at column edges in the atlas.

The correct handling for lateral offsets is clamping to the current tile's X range — lateral is river width, not the next segment. The original plan states this itself (its helper step 4) but buries it inside the full logical sampler. As a standalone fix, a lateral tile clamp:

- touches only the offset call sites plus one small helper,
- needs no grid metadata, no `i_occupied_steps`, no repack, and no signature bump (it changes shader sampling, not bake data),
- may by itself resolve everything the offset-sampling hypothesis can explain, because the longitudinal class is already margin-protected.

This becomes **Build C**, sequenced before either structural build.

### Correction 3: The Spike Checklist Is Incomplete

Additions to the square-atlas assumption sites listed in the v1 revision's Change 1:

- All nine bake filter shaders take `uniform float size = 512.0` — a scalar, square assumption in every filter pass (`shaders/filters/*.gdshader:3`: blur passes, dilate passes, foam, flow pressure, normal map, normal-to-flow).
- `lava.gdshader` also uses the `safe_uv2_sides` remap (per the seam audit).
- The seam and world-sample probes themselves encode square expectations and would need updating, not just re-running.
- **The per-tile resolution rule.** Today tile size is an emergent `resolution / side`, so per-tile texel density changes with river length. A strip must pick an explicit tile size. That choice changes texel density and memory relative to existing bakes — a visual-quality and budget decision, not a plumbing detail. The spike must answer this question first, because it determines whether strip output is even comparable to current bakes.

### Correction 4: The Classification Step Gets A Free, Decisive Discriminator

Because the debug shader is unshaded and renders static data (fact 4), one comparison resolves three buckets at once:

- Seam visible in any debug view → data or sampling problem. Lighting and temporal causes are excluded for that artifact.
- Seam visible only in the lit water, absent from every debug view → mesh normal/tangent basis or material amplification.

The classification taxonomy must also record **which join indices** seam (same-column, row-wrap, or column X-edge band), because that single observation decides between Build C, Build A, and the depth-1 hypothesis.

### Correction 5: Temporal Verification Is A Five-Minute Confirmation, Not A Workstream

Phase noise is verifiably applied (fact 5), and seams reported in static unshaded debug views cannot be temporal. The v1 revision's citation of `flow_offset_noise.png` as evidence of concern was backwards — the texture is unused. Keep a quick visual confirmation that the dual-phase reset does not pulse, then move on.

### Correction 6: New Hypothesis — Depth-1 Bilinear Bleed

Signature 23 synchronized only the exact duplicated edge row. Depth-1 rows on either side of a join are about two texels apart in world space, and the probes still report large depth-1/2 deltas in terrain-contact channels post-fix (fact 10). `terrain_contact_features.a` is a categorical provenance channel.

Any bilinear sample near the join blends depth-0 with depth-1. A large categorical depth-1 delta therefore paints a one-to-two-texel gradient band exactly along the join — at same-column joins too. This artifact:

- is not fixed by the strip (same-column joins keep it),
- is not fixed by the logical sampler or the lateral clamp (base sampling at `custom_UV` produces it),
- is not fixed by anything in either prior plan.

It needs its own probe (step 2 below) and, if confirmed visible, its own fix decision — likely either constraining depth-1 rows of categorical channels to agree near joins during bake, or accepting the band where it reflects genuine terrain change. Do not pick the fix before the probe.

### Correction 7: The Ablation List Is Incomplete And Partly Redundant

- Add to the ablation set: wake/eddy context (`wake_edge_sample_tiles`), pillow height smoothing (`pillow_height_smoothing_tiles`, default 0.10 — live by default), and the ripple simulation / visible ripple normal sampling paths the audit names but the v1 revision omits.
- Before toggling anything, check whether the demo materials override the zero-default pillow uniforms (fact 9). Offsets that are already off cannot be the live cause, and ablating them is wasted observation.
- All ablation is runtime uniform changes; no shader edits or recompiles are needed (fact 8).

## Revised Implementation Order

1. **Diagnose.** Visual capture in `Demo.tscn` and `Demo_obstacle_flow_test.tscn`, recording for each observed seam:
   - (a) which join index — same-column, row-wrap, or column X-edge band;
   - (b) lit water vs. unshaded debug views — present in debug ⇒ data/sampling; present only lit ⇒ normals/tangents or material amplification;
   - (c) raw baked channel vs. derived view.
   First check whether the demo materials override the zero-default pillow uniforms. State explicitly in the findings whether any visible seam remains at all post-signature-23 (fact 11).
2. **Cheap checks.**
   - Depth-1 bilinear-bleed probe (new): measure post-signature-23 depth-1/2 deltas per channel, prioritizing `terrain_contact_features.a`, and correlate with the observed seam positions from step 1.
   - Mesh normal/tangent continuity across step joins (e.g. a normals/matcap debug view or a CPU dump of join-vertex bases).
   - Temporal confirmation: dual-phase reset does not visibly pulse with `flow_foam_noise.a` phase noise active (`river.gdshader:968`). Five minutes; do not expand.
3. **Ablation.** Toggle each gated uniform group individually — `flow_hard_boundary_slide`, `wake_edge_sample_tiles`, `pillow_height_smoothing_tiles`, eddy/wake context, ripples — so each helper is individually implicated or cleared against the captured seams.
4. **Build C — lateral tile clamp (smallest fix first).** If the diagnosis implicates lateral cross-column reads: clamp lateral offsets to the current tile's X range at the offset call sites. No metadata, no repack, no signature bump. Re-run the step 1 capture to measure the visible effect.
5. **Build A — strip packing (conditional).** Only if the diagnosis localizes remaining seams to row-wrap joins or column X-edge bands **and** the feasibility spike — including the per-tile resolution rule, the nine filter shaders, `lava.gdshader`, and the probes (Correction 3) — comes back small. Gate behind a source signature bump; revalidate with updated probes.
6. **Build B — logical UV2-neighbor sampler (conditional).** Only for offset paths the ablation proved visibly responsible **and** that genuinely need longitudinal wrap beyond the one-tile margin protection. No current offset exceeds 0.70 tiles, so this may never trigger; if it does, follow the original plan's helper design with `i_occupied_steps` plumbing.
7. **Diagnostics.** Offset-routing debug view and probes (same-column, row-wrap, first/last step, column X-edge), per the original plan's section 4, scoped to whichever builds actually happened.
8. **Prebake review.** Decide which expensive context masks to prebake (bank-friction edge, wake, eddy, pillow smoothed height), per the original plan's section 5.
9. **Verification.** Parser checks, `git diff --check`, seam probes, world-sample probes.
10. **Final human-visible editor/runtime review** against whatever signature is current.

## Summary Of Deltas From The Prior Plans

| Topic | Original plan | v1 revision | This plan (v2) |
| :---- | :---- | :---- | :---- |
| Bake-side signature 23 fixes | Keep | Keep | Keep |
| First move | Build logical sampler | Ablation + visual classification | Same, with join-index and lit-vs-unshaded discriminators added |
| Lateral cross-column reads | Inside the full sampler | Not identified | Named as the unprotected class; standalone lateral clamp (Build C) |
| Longitudinal row-wrap offsets | Primary sampler motivation | Primary strip motivation | Shown already margin-protected up to 1 tile (max current offset 0.70) |
| Atlas layout | Square fold fixed | Strip preferred, gated on spike cost | Strip conditional on evidence **and** spike; per-tile resolution rule added to spike |
| Logical-neighbor sampler | Centerpiece | Fallback | Last resort; may never trigger |
| Depth-1 bilinear bleed | Not covered | Not covered | Named hypothesis with its own probe |
| Temporal seams | Assumed handled | Verification workstream | Verified applied (`river.gdshader:968`); demoted to quick confirmation |
| Mesh normals/tangents | Not mentioned | Verify | Verify; basis discontinuity at joins confirmed plausible from `generate_normals`/`generate_tangents` on unmergeable duplicated vertices |
| Ablation set | n/a | 3 helpers | Expanded (wake/eddy, smoothing, ripples); zero-default uniforms checked first |
| Spike assumption sites | n/a | 8 listed | + 9 filter shaders, `lava.gdshader`, probes, per-tile resolution rule |

## Validation Checklist

- Existing signature 23 probes still pass: `RIVER_FLOWMAP_SEAM_PROBE_OK`, `RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK`.
- Step 1 findings recorded: does any visible seam remain post-signature-23, at which join indices, and in lit, debug, or both.
- Demo-material overrides of zero-default pillow uniforms checked and recorded.
- Depth-1 probe results recorded and correlated (or not) with observed seam positions.
- Mesh normals/tangents confirmed continuous across step joins, or the discontinuity confirmed and scoped.
- Temporal reset confirmed non-pulsing (quick check only).
- Ablation result recorded per helper group.
- If Build C lands: lateral offsets no longer cross interior column edges; visible effect measured against the step 1 capture.
- If Build A lands: row-wrap joins eliminated for the demo rivers; per-tile resolution rule documented; probes updated and passing under the new packing.
- If Build B lands: offset-routing diagnostic confirms logical-neighbor behavior at same-column, row-wrap, and first/last step edges.
- Pillow seam fades remain off by default.
- Final visible review shows no straight tile bands in foam, normals, wakes, pillows, or height displacement.

## Source Notes

- [Plan to improve waterways seam handling.md](Plan%20to%20improve%20waterways%20seam%20handling.md)
- [Revised plan to improve seam handling.md](Revised%20plan%20to%20improve%20seam%20handling.md) (superseded by this document)
- [Seam Handling Audit - 2026-06-11](audit/seam-handling-audit-2026-06-11.md)
- [Symptoms And Initial Suspects](symptoms%20and%20initial%20suspects.md)
- [Seamless River Flowmap Techniques](Seamless%20River%20Flowmap%20Techniques.md)
- `addons/waterways/water_helper_methods.gd` — `calculate_side` (376-381), tile mapping (521-522), join-vertex duplication (784-789), `generate_normals`/`generate_tangents` (791-792), `_get_uv2_world_sample` (1190-1239), `add_margins` (1473-1506), `_add_uv2_column_continuation_margins` (1509-1537), `_uv2_tile_rect` (1539-1546)
- `addons/waterways/river_manager.gd` — bake resolution (1693-1700), `i_uv2_sides` assignment (945, 1742)
- `addons/waterways/shaders/river.gdshader` — offset constants (147-151), pillow search (290-298), smoothing short-circuit (420), wake short-circuit (564), flow slide (691-717), phase noise (968), dual-phase blend (155-165, 974-982), seam-fade defaults (92-93)
- `addons/waterways/shaders/river_debug.gdshader` — `render_mode unshaded` (4)
- `addons/waterways/shaders/filters/*.gdshader` — scalar `uniform float size` (line 3 in each)
