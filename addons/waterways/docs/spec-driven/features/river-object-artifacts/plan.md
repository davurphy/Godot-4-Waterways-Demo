# Plan: River Object Artifacts

## Spec Link

`spec.md`

## Architecture Summary

Keep the existing pipeline (CPU vertical-ray samplers → feature textures →
GPU filter passes → river shader gates) and fix it in three phases:

- **Phase 1 — Sampler quality:** supersample the terrain-contact sampler,
  crossfade contact sources instead of winner-takes-all, and port the
  overhang exemption into the direct-shape collision path. Pure bake-side
  changes; output textures keep their current meaning, so all downstream
  consumers are untouched. Reversible and independently shippable.
- **Phase 2 — Bake continuous fields, classify late:** change the
  terrain-contact texture to store signed height delta (remapped 0–1) +
  confidence; derive contact/shallow/protrusion in the consuming shaders
  from the interpolated delta. This is the durable fix for texel-scale
  classification aliasing and the only format change.
- **Phase 3 — Participation policy:** per-object opt-out
  (group/metadata) honored by shape collection and physics queries, plus a
  documented layer convention.

Why this satisfies the spec: Phase 1 removes per-texel flips cheaply and
proves the mechanism; Phase 2 makes mask edges resolution-independent
(interpolating height is meaningful, interpolating classifications is not);
Phase 3 controls which geometry participates at all. No pipeline rewrite.

## Current Truth

- Implementation status: Phases 0–2 complete (2026-06-11); demo bakes
  regenerated at signature 24 with supersampling + source blend + edge
  smoothing. Pending: user close-up review at cliff2, then Phase 3
  (opt-out policy).
- Open architectural decisions: opt-out group vs metadata (Phase 3).
  Resolved: fixed 2×2 supersampling default (2.9× total bake wall);
  Phase 2 = per-tile edge smoothing — the originally planned raw
  height-delta format was REJECTED because bilinear interpolation across
  object silhouettes sweeps through intermediate heights and would
  synthesize fake shallow-contact rings around protruding rocks. The
  "classify late" idea remains viable only as region-SDF storage, kept as
  a future option if smoothing proves insufficient.
- Last validation that proves the plan still works: `validation.md` Phase 2
  results — provenance flips 4364 → 47 (−99%), protrusion hard-edge flips
  3051 → 79 (−97%), contact gradient −61%; before/after debug-view PNGs in
  `.codex-research/river-object-artifacts-visual-review/`. User review
  (2026-06-11): improved but artifacts remain — **feature stays open**.
- Next planned implementation slice: user close-up re-review of the crack
  locations after the stagnation-centerline slide fade (runtime-only, no
  rebake; see validation.md "Stagnation-centerline shear fix"). If the
  crack is gone but the static squiggly bands remain, next suspect is the
  foam-pass 10-tap comb (ghost edges of obstacle outlines at regular
  spacing). If the crack persists, audit the remaining hard branches in
  the slide/steering chain (`keep_minimum_alignment`,
  `keep_downstream_component`) and `boundary_gradient_at` sampling, then
  the float-precision suspect (`(time - progress) * jump` growing
  unbounded — artifact would worsen with editor uptime). Then Phase 3
  (opt-out). Completed this session: Phases 0–2, bleed fix
  (probe-verified), refraction smooth-blend (kept; not the cause),
  textureGrad mip fix (kept; not the cause), avoidance tangent fade
  (kept; baked flow was already smooth — probe-measured).
- Branch safety before implementation: feature branch
  `river-object-artifacts` already checked out (user-created)
- Sections below that are historical or superseded: Phase 0/1 items in
  "Files to Change" are done as described, with one deviation — the overhang
  exemption was implemented by making the physics up/down rays the primary
  decision and demoting the direct-shape test to a fallback (physics rays
  carry facing info; the analytic intersector does not), instead of porting
  facing logic into the direct path.

## Premise Check

- Evidence supporting the premise: debug-view screenshots show bake-texel
  stair-steps in protrusion, provenance, wake seed, and final flow strength
  at cliff2; code trace identifies the exact mechanisms
  (`research.md` findings 1–7, file:line references).
- Evidence against the premise: none found; eddy-line and shader-gate
  amplification explicitly ruled out by the screenshots.
- User-facing pushback or clarification needed before patching: none —
  user reviewed the diagnosis and fix direction.
- Smallest check that can falsify the premise: A/B `baking_resolution`
  2 → 4 on cliff2 — if the block size does *not* shrink proportionally, the
  texel-aliasing theory is wrong and Phase 1/2 need rethinking. Run this
  first as Phase 0.

## Layers

Editor authoring layer:

- Debug View menu: keep existing terrain/bank view IDs; in Phase 2 their
  shader implementations derive values from the height field. Possible new
  view: raw height delta.

Bake/data layer:

- `water_helper_methods.gd` samplers and shape collection;
  `river_manager.gd` bake settings/constants and stats;
  `resources/river_bake_data.gd` format version bump (Phase 2).

Runtime layer:

- `shaders/river.gdshader` + `shaders/river_debug.gdshader` mask
  derivation (Phase 2); no API changes.

Validation layer:

- Probe scripts under `docs/spec-driven/features/river-object-artifacts/probes/`
  following the existing feature-probe pattern; before/after screenshot
  matrix in `validation.md`.

Legacy reference layer:

- Original Waterways physics up/down-ray overhang exemption is the intended
  behavior being restored to the direct-shape path.

## Godot Components

- Nodes: none new.
- Resources: `RiverBakeData` (version bump, channel-meta docs, Phase 2).
- Shaders: `obstacle_feature_mask_filter.gdshader`,
  `bank_response_feature_mask_filter.gdshader`, `river.gdshader`,
  `river_debug.gdshader`; new shared `.gdshaderinc` for mask-derivation
  functions (Phase 2) to avoid duplicating thresholds.
- Editor tools: Debug View menu (labels only if needed).
- Importers / Autoloads: none.
- Scenes: demo overhang test arrangement for AT3 (validation-only).
- Validation scenes: reuse `Demo.tscn` cliff2/smooth_rock cameras.

## Data Model

Current `terrain_contact_features` (RGBA8): R contact, G shallow,
B protrusion, A confidence — all derived at bake time from one scalar
`delta = water_y − hit_y` plus source confidence.

Phase 2 target: R = signed height delta remapped
`clamp(delta / DELTA_RANGE * 0.5 + 0.5, 0, 1)` with `DELTA_RANGE`
covering at least −protrusion_full…+shallow_fade (≈ −0.20…+1.25 m, stored
in bake metadata so shaders un-remap with uniforms, not magic numbers);
G = blended confidence; B/A reserved (write 0). "No hit" must encode
distinctly (confidence 0) so dilation/blur of empty water stays neutral.
Contact/shallow/protrusion are then
`_falloff_mask`/`_rise_mask`-equivalent smoothsteps evaluated in shader
from the interpolated delta, using the same band constants delivered as
uniforms from `river_manager.gd` settings. `source_signature_version` in
`RiverBakeData` increments; mismatch triggers the existing
rebake-required messaging path.

Phase 1 makes no format change: supersampled, source-blended delta is
still converted to R/G/B/A masks at bake time.

## Editor/Runtime Boundary

- Editor-only code: bake orchestration, probes, debug menu.
- Runtime-safe code: shaders, bake-data resource, mask derivation.
- Shared data/resources: `RiverBakeData`, band constants in settings.
- APIs exposed to user projects: unchanged; plus documented opt-out
  group/metadata name (Phase 3).
- Assumptions that must not cross the boundary: no editor scene-tree
  scanning at runtime; shaders must not assume demo band values (uniforms).

## Runtime Flow

1. River shader samples `i_terrain_contact_features` (bilinear) → height
   delta + confidence (Phase 2).
2. Derives contact/shallow/protrusion via shared smoothstep functions at
   fragment resolution.
3. Existing gates (pillow/wake/bank/hard-boundary) consume the derived
   values exactly where they consumed channels before.

## Bake Flow

1. Inputs: river mesh UV2 sample context, collision shapes filtered by
   layer mask **and not opted out** (Phase 3), HTerrain samplers.
2. Per texel: N×N jittered vertical rays (Phase 1); per ray, blend HTerrain
   and physics heights across a crossfade band (Phase 1); average deltas.
3. Collision map: direct-shape segment test with overhang exemption
   (Phase 1) before physics fallback.
4. Outputs: Phase 1 — same textures/channels; Phase 2 — height-delta +
   confidence texture, masks derived downstream.
5. Metadata: terrain-contact stats updated to report delta stats;
   `source_signature_version` bumped in Phase 2.
6. Preview/consumption: existing debug views; filters consume the new
   channels via shared derivation include.

## Lifecycle, Cleanup, and Re-entry

The bake remains the existing awaited, progress-reporting flow in
`_generate_flowmap`; phases change per-texel math, not control flow.

- Success path: unchanged — textures assigned, stats printed, progress
  window closed.
- Preflight or early-return path: unchanged guards (empty image, no
  context); supersampling must not change early-return semantics.
- Awaited failure path: unchanged `_filter_output_is_valid` /
  `_finish_flowmap_bake_after_failure` handling.
- Temporary node/resource ownership: renderer instance lifecycle unchanged
  (`_cleanup_bake_renderer`).
- Progress, dirty-state, and user feedback: contact pass is ~N× slower at
  default supersampling — keep per-column progress emission so the window
  still advances; consider emitting every 5% instead of 10% if it feels
  stalled.
- Duplicate or overlapping requests: existing bake-in-progress guards
  unchanged.
- Scene reload or runtime boundary: version check lives in bake data, not
  editor memory (Phase 2).

## Files to Change

Phase 0 (baseline, no behavior change):

- `docs/spec-driven/features/river-object-artifacts/probes/object_artifact_baseline_probe.gd`:
  capture collision/terrain-contact pixel stats around cliff2; log
  direct-shape vs physics divergence under the overhang.
- `validation.md`: baseline matrix from existing `artifacts/` screenshots;
  record the `baking_resolution` 2→4 falsification A/B result.

Phase 1:

- `water_helper_methods.gd`: supersampling loop + jitter offsets in
  `generate_terrain_contact_feature_map` (sample N² deltas, average);
  crossfade source blend replacing the epsilon override at lines
  ~1351-1355; overhang exemption in `generate_collisionmap` direct path
  (~1286-1289), reusing one shared exemption helper for both paths.
- `river_manager.gd`: new settings keys (`contact_supersamples`,
  `source_blend_band`) in `_get_terrain_contact_feature_settings` +
  constants; optional inspector property for supersample quality.
- `docs/architecture-and-features.md`: bake sampling notes.

Phase 2:

- `water_helper_methods.gd`: write delta+confidence instead of masks;
  update `_get_terrain_contact_feature_stats` inputs.
- `river_manager.gd`: pass band constants as shader uniforms; stats; bump
  source signature version handling.
- `resources/river_bake_data.gd`: channel docs, neutral color for the new
  encoding, version bump.
- `shaders/filters/obstacle_feature_mask_filter.gdshader`,
  `shaders/filters/bank_response_feature_mask_filter.gdshader`: derive
  contact/shallow/protrusion from delta via shared include.
- `shaders/filters/contact_field.gdshaderinc` (new): remap + band
  derivation functions shared by filters and river shaders.
- `shaders/river.gdshader`, `shaders/river_debug.gdshader`: replace direct
  channel reads (`terrain_contact.r/.g/.b`) with derived values; keep debug
  view IDs stable.
- `gui/debug_view_menu.gd`: label tweaks only if channel names change.

Phase 3:

- `water_helper_methods.gd`: opt-out check in
  `collect_raycast_collision_shapes` / `collect_hterrain_samplers`; exclude
  opted-out bodies' RIDs from `PhysicsRayQueryParameters3D` via `exclude`.
- `river_manager.gd`: constant for the group/metadata name.
- `docs/architecture-and-features.md` + README section: layer convention
  and opt-out workflow.
- `Demo.tscn`: tag one decorative prop as the worked example (AT4).

## Documentation Plan

- Code comments needed: encoding constraint at the delta remap (range,
  no-hit sentinel) — the one thing the code can't show.
- Feature docs to update: `docs/architecture-and-features.md` (bake data
  semantics, opt-out convention).
- Architecture or data-flow docs to update: same.
- Validation docs to update: `validation.md` matrix (created Phase 0).
- Research citations index: add SDF/late-classification reference if one is
  consulted; no new external research required so far.
- Migration notes to update: "rebake required after Phase 2" note in
  changelog + bake-data version behavior.

## Validation Strategy

- Automated: probe scripts (baseline probe; overhang divergence probe;
  post-fix re-run asserting zero direct/physics divergence and smooth
  provenance histogram — no two-value spike).
- Validation matrix location: `validation.md` (Phase 0 creates it; one row
  per acceptance test AT1–AT6 from `spec.md`).
- Human-assisted: before/after screenshot review at the cliff2 angles.
- Visual: debug views — Protrusion, Provenance, Wake Seed, Final Flow
  Strength, plus normal-view foam; bank-only section and mid-stream rock.
- Shader: river_debug parity — derived masks in Phase 2 must match Phase 1
  baked masks within tolerance on an unchanged scene (capture-diff probe).
- Editor: bake progress still advances; rebake-required message on version
  mismatch.
- Runtime: demo runs with rebaked data; buoyancy/flow sampling unchanged.
- Performance: time the contact pass before/after Phase 1 on the demo
  river; record in validation.md against the ≤3× budget.
- Manual: AT4 opt-out workflow walk-through.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Supersampling makes bakes feel hung | Editor UX regression | Keep per-column progress; quality setting; adaptive refinement if >3× budget |
| Source crossfade changes bank look globally (not just at artifacts) | Visual regression on tuned scenes | A/B full-river screenshots, not just cliff2; band width as a setting defaulting near current epsilon behavior |
| Phase 2 derived masks drift from baked masks (different smoothstep inputs post-interpolation) | Subtle look change everywhere | Parity capture-diff probe with tolerance; tune DELTA_RANGE so bands sit well inside 8-bit precision |
| 8-bit delta quantization (256 steps over ~1.5 m ≈ 6 mm) visible in 3 cm protrusion band | Banding in derived masks | Verify in probe; if visible, narrow DELTA_RANGE or use RGBA16/two-channel packing |
| Overhang exemption removes intended obstacles (e.g. arched rock touching water at edges) | Lost legitimate flow response | Exemption only skips hits wholly above the surface with down-facing underside; AT3 covers both placements |
| Old bakes silently misread after format change | Broken user scenes | `source_signature_version` gate + rebake message (AT5) |
| Physics `exclude` list approach misses bodies added during bake | Opt-out leaks | Collect opt-outs at bake start (same pass as shape collection); document that mid-bake scene edits are unsupported |

## Adversarial Plan Review

To complete with the user before implementation starts.

- Most likely way this plan could damage working behavior: Phase 2 mask
  derivation subtly differing from baked masks, shifting pillow/wake/foam
  tuning across every scene — mitigated by the parity probe gate.
- Project state, generated resource, scene, or workflow most at risk:
  existing `waterways_bakes/` resources (invalidated by Phase 2 version
  bump — intended, but must message clearly).
- Files or data that are riskier than they look: `river_debug.gdshader`
  (66 view IDs consumed by review probes; channel reads are scattered);
  `add_margins`/dilation interaction with the new "no-hit" encoding.
- Simpler or safer approach considered: Phase 1 only (no format change) —
  kept as a shippable fallback; Phase 2 proceeds only if Phase 1 validation
  still shows objectionable blockiness up close.
- Validation that will catch the riskiest failure early: parity
  capture-diff probe on an unchanged scene before any visual retuning.
- Branch safety reminder sent before code changes: Yes — work is on
  `river-object-artifacts`.

## Migration and Compatibility

- Phase 1: none — same formats, same channels; rebake recommended but old
  bakes remain valid.
- Phase 2: bake format change; old `RiverBakeData` detected via
  `source_signature_version` and reported as rebake-required. No automatic
  migration (per spec non-goal). Demo bakes under `waterways_bakes/`
  regenerated and committed with the change.
- No Godot 3 compatibility concerns; all APIs in use are Godot 4.6+.
