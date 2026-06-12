# Validation: River Object Artifacts

## How to run the probe

From the repository root with Godot 4.6.3:

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user-river-object-artifacts'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://addons/waterways/docs/spec-driven/features/river-object-artifacts/probes/object_artifact_baseline_probe.gd'
```

Success marker: `OBJECT_ARTIFACT_BASELINE_PROBE_OK`.
Optional: `$env:OBJECT_ARTIFACT_RES_AB = '1'` adds an in-memory rebake at
`baking_resolution = 3` (512 atlas) and re-measures. Committed bakes were
verified unchanged after an A/B run (`git status waterways_bakes` clean),
but check again if the save path behavior changes.

## Phase 0 baseline (2026-06-11, saved bake `Water_River.river_bake.res`, 256 atlas)

Region = UV2 steps within 10 m of `Cliffs/cliff2` (steps 0–2).

### Terrain-contact provenance (A channel)

| Scope | Texels | Zero | Physics (≈0.5) | Blend | HTerrain (≈1.0) | Neighbor flips (≥0.3) | Flip density |
| --- | --- | --- | --- | --- | --- | --- | --- |
| global | 44370 | 6 | 7879 | **0** | 36485 | 4364 | 0.0984 |
| region (cliff2) | 7803 | 1 | 564 | **0** | 7238 | 595 | 0.0763 |

Provenance is strictly two-tone — zero blended texels — confirming
winner-takes-all source selection flipping at texel granularity.

### Protrusion (B channel)

| Scope | Hard (≥0.5) | Partial | Isolated hard | Hard-edge flips | Flips per hard texel |
| --- | --- | --- | --- | --- | --- |
| global | 11679 | 766 | 8 | 3051 | 0.2612 |
| region (cliff2) | 1308 | 89 | 2 | 462 | 0.3532 |

Only 766 of 12445 nonzero protrusion texels are partial: the 3 cm→20 cm
ramp almost never resolves — protrusion is effectively binary per texel.

### Contact (R channel)

| Scope | Partial-contact texels | Mean neighbor delta |
| --- | --- | --- |
| global | 8100 | 0.2366 |
| region (cliff2) | 981 | 0.2761 |

### Collision-path divergence (live scan, stride 2, 11131 samples)

| Both mark | Direct-only | Direct-only overhang (`up_hit_frontface`) | Physics-only |
| --- | --- | --- | --- |
| 925 | 1035 | **1035 (100% of direct-only)** | 0 |

**53% of all obstacle-marking texels** (1035 of 1960) are marked solely by
the direct-shape path in cases the physics path's overhang exemption would
skip. 199 of them are in the cliff2 region. This confirms `research.md`
finding 4 (dead exemption) with large real-scene impact.

### Resolution A/B (premise falsification, 256 → 512)

| Metric | 256 | 512 | Scale | Expected if texel aliasing |
| --- | --- | --- | --- | --- |
| Occupied texels | 44370 | 177992 | ×4.01 | ×4 (area) |
| Hard protrusion texels | 11679 | 45434 | ×3.89 | ×4 (area) |
| Provenance physics texels | 7879 | 31582 | ×4.01 | ×4 (area) |
| Provenance blend texels | 0 | 0 | — | 0 at any resolution |
| Provenance flips | 4364 | 8969 | ×2.06 | ×2 (perimeter) |
| Hard-edge flips | 3051 | 5475 | ×1.79 | ×2 (perimeter) |
| Contact mean neighbor delta | 0.2366 | 0.1400 | ×0.59 | ×0.5 (fixed world gradient) |

Area metrics scale ×4, discontinuity metrics scale ×2 (perimeter-bound),
per-texel gradient halves: the classification edges are resolution-limited
aliasing, present at every resolution. **Premise confirmed; raising
resolution shrinks but never removes the blocks.**

## Acceptance test matrix (from spec.md)

| Test | Status | Evidence |
| --- | --- | --- |
| AT1 blocky debug views eliminated at cliff2 | Partially met (Phase 1); needs human screenshot review + Phase 2 for protrusion edges | Metrics below; capture new `artifacts/` screenshots |
| AT2 provenance blends instead of two-tone | **Met (Phase 1)** | prov_blend 0 → 20641; flips −87% |
| AT3 overhang not marked as obstacle | **Met (Phase 1)** | collision hits 7767 → 3751 (−52%), matching the 53% dead-exemption prediction |
| AT4 opt-out removes object response | Pending Phase 3 | — |
| AT5 old-format bake surfaces rebake message | Covered by signature bump 23 → 24 (existing staleness path); Phase 2 will bump again | — |
| AT6 bake-time budget ≤ ~3× | **Met** | Full rebake wall (both scenes): 69.8 s (ss=1) → 203.5 s (ss=2) = 2.9× |

## Phase 1 results (2026-06-11, signature 24, supersamples=2, blend band 0.15 m)

Implementation: `water_helper_methods.gd` — physics-first collision decision
with direct-shape fallback (overhang exemption now effective); 2×2 jittered
supersampling averaging classified masks; `_blend_contact_samples`
height-crossfade replacing the 2 cm winner-takes-all epsilon. Constants and
signature keys in `river_manager.gd` (`RIVER_TERRAIN_CONTACT_SUPERSAMPLES`,
`RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND`; `RIVER_TERRAIN_SOURCE_SELECTION_EPSILON`
removed).

### Provenance (A) — vs Phase 0 baseline

| Scope | Physics | Blend | HTerrain | Flips | Flip density |
| --- | --- | --- | --- | --- | --- |
| global | 5463 (was 7879) | **20641 (was 0)** | 18262 | **580 (was 4364, −87%)** | 0.0131 (was 0.0984) |
| region | 257 (was 564) | **3180 (was 0)** | 4366 | **50 (was 595, −92%)** | 0.0064 (was 0.0763) |

### Protrusion (B)

| Scope | Hard | Partial | Isolated | Hard-edge flips | Flips/hard |
| --- | --- | --- | --- | --- | --- |
| global | 11483 (was 11679) | **1582 (was 766)** | 6 (was 8) | 2669 (was 3051, −13%) | 0.2324 (was 0.2612) |
| region | 1281 (was 1308) | **214 (was 89)** | 3 | 402 (was 462) | 0.3138 (was 0.3532) |

Partial-ramp texels doubled, but hard-edge flips only dropped ~13%: on
near-vertical banks the whole 3→20 cm protrusion ramp fits inside a
sub-texel, so 2×2 coverage averaging cannot resolve it. This residual is
the Phase 2 (continuous height field, classify-late) target.

### Contact (R)

| Scope | Partial texels | Mean neighbor delta |
| --- | --- | --- |
| global | 10122 (was 8100) | 0.2037 (was 0.2366) |
| region | 1273 (was 981) | 0.2321 (was 0.2761) |

### Collision map (overhang exemption)

`collision_hit_pixel_count` (main demo): **7767 → 3751 (−51.7%)**.
The Phase 0 scan predicted 53% of marks were direct-only overhang
exemptions; the live result matches. `object_artifact_collision_stats_probe.gd`
prints these counts from any saved bake.

### Timing (AT6)

Full two-scene rebake wall clock: 69.8 s at supersamples=1 vs 203.5 s at
supersamples=2 → 2.9× total (the contact pass dominates; per-pass ratio is
~4× rays). Within budget; adaptive refinement remains the optimization
lever if budgets tighten.

### Outstanding for Phase 1 sign-off

- Human visual review (2026-06-11): user confirmed no negative effects;
  artifacts near objects reduced but still noticeable → proceeded to
  Phase 2.
- Note: `river-flowmap-seams/probes/river_flowmap_world_sample_probe.gd`
  still replicates the legacy winner-takes-all selection internally; its
  source-attribution output is informational only and may disagree with
  signature-24 bakes.

## Phase 2 results (2026-06-11, per-tile edge smoothing, 1 binomial pass)

Implementation: `WaterHelperMethods.smooth_uv2_tile_channels` — separable
5-tap binomial blur per occupied UV2 tile (edge-clamped so atlas-adjacent
but world-unrelated tiles never bleed), applied to the terrain-contact
source before margins (`river_manager.gd`, `RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES = 1`).
The GPU filter passes (bank response, obstacle features) consume the
smoothed data, so wake/pillow gates inherit the smoothness.

Phase 2 replaces the originally planned raw-height-delta bake format:
bilinearly interpolating a height field across object silhouettes sweeps
through intermediate heights and would synthesize fake shallow-contact
rings around protruding rocks. Smoothing the classified fields keeps
formats, fixes the measured residual, and has no runtime cost.

### Metrics vs earlier phases (global scope)

| Metric | Phase 0 | Phase 1 | Phase 2 |
| --- | --- | --- | --- |
| Provenance flips | 4364 | 580 | **47 (−99%)** |
| Provenance flips (region) | 595 | 50 | **0** |
| Protrusion hard-edge flips | 3051 | 2669 | **79 (−97%)** |
| Isolated hard texels | 8 | 6 | 1 |
| Partial protrusion texels | 766 | 1582 | 4898 |
| Contact mean neighbor delta | 0.2366 | 0.2037 | **0.0916** |

### Visual evidence

`object_artifact_visual_export.gd` exported before/after debug views to
`.codex-research/river-object-artifacts-visual-review/{baseline,phase2}/`
(baseline captured by stashing the code+bake changes; phase2 from the
current tree). The Protrusion view at the upper-obstructions camera shows
the baseline's jagged blocky bank fringes replaced by smooth ramps.

### User review (2026-06-11) — FEATURE REMAINS OPEN (superseded by bleed fix below; pending re-review)

Artifacts near objects are less severe but still noticeable. Since the
texel-flip metrics this feature has been steering by are now near zero,
the remaining artifacts come from a different mechanism. Working
hypothesis (user): bake bleed. Concrete suspects and a verification plan
are recorded in `research.md` "Open lead after Phases 0–2" — the GPU
filter passes (dilate, blur, foam, obstacle-feature directional searches)
operate atlas-wide over tiles that are not world-adjacent. Next
measurements must target the *filtered* outputs (flow_foam_noise,
obstacle_features), not the raw terrain contact.

## Cross-tile bleed fix (2026-06-11)

`object_artifact_tile_bleed_probe.gd`: bakes the Demo river with and
without a synthetic box obstacle intersecting the water near the RIGHT
edge of step 1's tile, then reports per-tile |delta| stats on the filtered
outputs. The tile to the right of step 1 belongs to step 6 (side = 5) — a
river stretch five steps away in the world; any delta there is bleed.

### Probe results (step-6 tile = atlas neighbor, world-distant)

| Metric | Before fix | After fix |
| --- | --- | --- |
| dist delta (tile mean / max) | 0.130 / 0.796 | **0.0 / 0.0** |
| dist delta (left-edge 8px band mean) | 0.584 | **0.0** |
| pillow delta max | 0.961 | **0.0** |
| wake delta max | 0.871 | **0.0** |
| foam delta max | 0.047 | **0.0** |
| control tile (two columns away) | 0.0 | 0.0 |

Legitimate responses preserved after the fix: obstacle tile deltas
unchanged (dist_max 0.99, pillow_max 1.0); downstream world-neighbor keeps
its wake (wake_max 0.99).

### Implementation

- `shaders/filters/atlas_column_clamp.gdshaderinc` (new): `atlas_columns`
  uniform + `atlas_column_clamp(sample_uv, base_uv)` clamps a sample's x
  into the column band of the fragment being shaded (2% column-width
  padding keeps bilinear taps off the shared boundary). `atlas_columns <=
  1.0` disables clamping (single-image consumers unaffected).
- Clamped passes: `dilate_filter_pass1` (horizontal obstacle search — the
  dominant bleed, ~`size * dilation` texels of reach), `blur_pass1`
  (horizontal Gaussian), `normal_map_pass` (3×3 taps),
  `obstacle_feature_mask_filter` (wake/pillow/eddy directional and lateral
  searches), `obstacle_avoidance_flow_filter` (upstream lookahead),
  `bank_response_feature_mask_filter` (gradient probes, forward
  protrusion). Vertical-only passes were left untouched — vertically
  adjacent tiles are world-adjacent steps.
- `filter_renderer.gd` apply_* functions take `atlas_columns` (default
  1.0); `river_manager.gd` passes `_uv2_sides + 2` (content columns plus
  margin bands) and stamps `filter_passes_column_clamped` into the bake
  signature/metadata (old bakes flag stale).

Demo bakes regenerated; visual captures in
`.codex-research/river-object-artifacts-visual-review/bleedfix/`.
Pending: user close-up re-review at cliff2.

## Refraction silhouette-dash fix (2026-06-11)

After the bleed fix, the user re-baked and re-confirmed remaining
artifacts: thin DASHED contour lines tracing organic shapes on the water
("looks like tearing, but it is a shape") — screenshots in
`artifacts/visual artifact.png` and `artifacts/visual artifact 2.png`.

Diagnosis (river.gdshader runtime, not bake data — which is why every bake
fix left it unchanged):

- Ruled out vertex tearing: pillow height displacement is the only vertex
  path and the demo sets `mat_pillow_terrain_height` /
  `mat_pillow_obstruction_height` to 0.0.
- Root cause: the refraction depth test. The refracted screen sample
  (`ref_ofs = SCREEN_UV - normal * transparency_refraction`) can land on
  geometry in front of the water; the old code handled that with a binary
  per-pixel branch (`if (scene_z2 > VERTEX.z)`) that swapped `ref_ofs`,
  `water_depth2`, `clar_t`, and `alb_t` all at once. Because the offset
  wiggles with the water normal FBM, pixels along the screen-space
  silhouette of any rock/bank flicker between the two branches — drawing a
  dashed contour that follows the geometry's shape. Visible even on heavy
  foam via the `alb_t` color flip and residual `ref_amount`.

Fix (`shaders/river.gdshader`):

- `refraction_valid = smoothstep(0.0, REFRACTION_VALID_BAND, VERTEX.z -
  scene_z2)` fades the refraction offset back to `SCREEN_UV` across a
  0.15 view-unit band instead of switching; depth is re-sampled at the
  blended UV and `water_depth2`/`clar_t`/`alb_t` follow continuously
  (when fully invalid the math reduces exactly to the old fallback values).
- Refraction mip clamped (`REFRACTION_MAX_LOD = 4.0`) so
  `ROUGHNESS * water_depth2` cannot jump to extreme LODs across the band.

Runtime-only change: no rebake required. Shader compiles and renders
correctly (captures in
`.codex-research/river-object-artifacts-visual-review/refractionfix/`).
User re-review: **did not resolve the dashes** — refraction branch
exonerated as the cause (fix kept; it removes a real flicker mechanism).

## Flowmap phase-wrap mip-seam fix (2026-06-11)

Next candidate after the refraction fix failed: the flow-pattern phase
seam. `river.gdshader` line ~972 builds `time = TIME * flow_speed +
flow_foam_noise.a` — the per-pixel baked phase noise. Inside `FlowUVW`,
`progress = fract(time + phaseOffset)` and the `(time - progress) * jump`
term are **discontinuous across the iso-line where the fract wraps**. That
iso-line is an organic curve (a contour of the phase-noise blobs). Across
it, the pattern-sampling UV jumps by a whole flow vector between adjacent
pixels; `texture()` mip selection uses screen derivatives, so the 2×2
quads straddling the curve get exploded derivatives and sample a tiny mip
— a line of wrong-colored pixels, dashed, tracing the noise contour.
Signature match: organic shape-following dashed lines, worst where flow is
fast (near obstacles), present on foam, immune to every bake-side change,
and unaffected by the refraction fix (the two-phase *color* blend hides
the wrap — `uvw.z` weight is zero there — but the *derivative* corruption
is weight-independent).

Fix: sample the flow-advected pattern textures with `textureGrad` using
the continuous base-UV gradients (`dFdx/dFdy(UV) * uv_scale`, ×2 for the
second detail level) instead of derivative-based mips:

- `shaders/river.gdshader` (level 1 + level 2 water samples)
- `shaders/river_debug.gdshader` (Foam Mix view + Flow Pattern view)
- `shaders/lava.gdshader` (normal/emission samples)

Runtime-only: no rebake required.

Verification status: headless A/B capture diffing
(`object_artifact_dash_hunt_probe.gd`, `flow_speed = 0` makes the wrap
curves frame-deterministic) confirms the fix changes mip selection on the
water as intended, but run-to-run TIME-animated content (vegetation sway,
ripples) contaminates the diff, so the dashes themselves could not be
isolated headless. User re-review: **dashes persisted** — see next section.

## Stagnation-centerline shear fix (2026-06-11)

User provided decisive close-ups (`artifacts/crack.png`,
`artifacts/crack close-up with jagged staircase look.png`,
`artifacts/squiggly patterns.png`): the "dash" is a static crack-like seam
running along the flow through obstacles, jagged at texel scale up close,
with static squiggly compressed-pattern bands beside it that foam
movement reveals. User correctly localized it to pillow-capable obstacles.

Diagnosis chain:

1. Hypothesis A — obstacle-avoidance tangent flip
   (`obstacle_avoidance_flow_filter.gdshader`,
   `if (dot(tangent, baseline) < 0) tangent = -tangent`) bakes a lateral
   flow shear along obstacle stagnation centerlines. **Refuted by
   measurement**: `object_artifact_flow_shear_probe.gd` found the baked
   flow field laterally smooth (max neighbor delta 0.102, zero pairs
   ≥ 0.5) — the flowmap blur erases the flip. A centerline fade
   (`influence *= smoothstep(0, 0.35, abs(tangent_alignment))`) was kept
   as polish; bake metrics pre/post essentially unchanged.
2. Hypothesis B — the SAME flip pattern at RUNTIME:
   `apply_contextual_flow_slide` (river.gdshader, also duplicated in
   river_debug.gdshader) flips `boundary_tangent` per fragment, gated by
   `hard_boundary = max(bank_response.a, terrain_protrusion)` — exactly
   the pillow-capable obstacle contexts — and `flow_into_boundary ≈ 1`
   (head-on flow) MAXIMIZES the slide gate precisely where the tangent
   choice is ambiguous. Adjacent fragments across the stagnation
   centerline slide the advected pattern in opposite lateral directions
   at full strength: a static shear seam, texel-staircased because the
   boundary gradient comes from 256² masks. Invisible to baked-flow
   metrics because it is applied after sampling.

Fix: `slide_amount *= smoothstep(0.0, 0.35, abs(tangent_alignment))` in
both `river.gdshader` and `river_debug.gdshader` — the slide fades out at
the centerline (water splits smoothly at a stagnation line). Runtime-only;
no rebake needed (demo bakes were regenerated anyway with the harmless
avoidance-filter polish).

If the crack disappears but the static squiggly bands remain, the queued
suspect for the squiggles alone is the foam pass comb
(`foam_pass.gdshader` takes the max over 10 offset taps, creating up to
10 ghost copies of every obstacle edge at regular spacing).

**User review (2026-06-11): CONFIRMED — the cracks are gone and the water
looks much better.** Root cause of the long-chased "dashed shape" artifact
was the runtime stagnation-centerline shear. Squiggly-band status not
separately confirmed; if they resurface, start with the foam-pass comb
suspect above.
