# Research: River Waterline and Bank Flow Corrections

## Purpose

This research frames the two reported defects before code changes: missing water near protruding/wide-top obstacles, and isolated inward bank flow. It should unlock a decision about which layer owns each symptom and what probes are needed.

Use `addons/waterways/docs/research/river-research-citations.md` as the shared works-cited index for river behavior, hydrology, flow maps, shader-water references, and production examples. Update that file when new external sources inform this feature.

For Godot-specific implementation work, search current official Godot documentation and API references online before coding. Prefer official Godot docs first for shaders, rendering, editor APIs, resources, physics, and version-specific behavior; use community examples only as secondary context.

## Current Research Outcome

- Status: Partial; old obstacle-flow baseline comparison and safe Demo bake probes completed.
- Recommendation: keep using `../river-obstacle-flow-constraints/` as the primary regression baseline, then use screenshot/probe correlation to identify whether the reported locations diverge from the otherwise-present baseline behavior.
- Confidence: medium-high that the broad old mechanism is present; low on the reported spots until screenshots are mapped.
- Biggest unknown that remains: whether the specific defects are in saved bake data, shader/debug interpretation, generated-resource staleness, scene/collider setup, or a new edge case at the screenshot locations.
- Decision or plan section this research unlocked: `plan.md` diagnosis-first architecture and validation strategy.

## Questions

- What are we trying to learn?
  - Whether obstacle gaps come from a top-down/upper-geometry footprint instead of actual waterline contact.
  - Whether bank inward spots are real high-magnitude flow defects or misleading visualization of low-magnitude residual flow.
- What assumptions need verification?
  - A fresh rebake on current code still shows the issue.
  - The screenshot locations are open water at the waterline, not inside a collider footprint.
  - The bank spots are not seams, local bends, or debug arrow sampling artifacts.
- What user or agent premise might be wrong, incomplete, or based on missing scene/data context?
  - A visible rock mesh can differ from its collision shape.
  - A solid-center debug cell can cover mostly open water visually.
  - An arrow can point a meaningful-looking direction even when the encoded flow magnitude is near zero.
- What Godot 4.6+ constraints could change the design?
  - Physics query behavior, raycast `hit_from_inside`, mesh/intersection shape behavior, viewport readback reliability, and shader texture sampling rules.
- Which parts are editor-only, runtime-only, or shared?
  - Bake probes and raycasts are editor/validation-side.
  - Shaders and runtime sampling are runtime-side.
  - Generated bake resources and metadata are shared.
- What legacy Waterways behavior should be preserved, changed, or removed?
  - Preserve the active Godot 4.6+ occupancy/projection behavior unless probes show a specific defect.

## Flow-Map and Water Tool Patterns

Useful local pattern from the current project:

- The older obstacle-flow documents describe a previously working solution for pressure-projected obstacle flow, occupancy clipping, overhang/wide-top tuning, and debug-arrow interpretation. Treat that as the first source of truth for expected behavior.
- A binary or near-binary solid/occupancy field can be correct for true solids but too blunt for upper-only geometry near the waterline.
- Debug views that sample one texel per visible cell can overstate a solid rim or low-magnitude residual.
- Pressure-projected fields are meant to prevent obstacle penetration, but post-projection shader slides or debug fallback sampling can make the field appear different than the saved data.

Candidate principles:

- Classify geometry by water role: ignored, decorative, open waterline under overhang, true solid at waterline, bank protrusion, or submerged shallow.
- Preserve provenance where possible so "why was this texel solid?" is inspectable.
- Compare vectors by both direction and magnitude; direction alone is weak evidence near zero speed.

## Godot 4.6+ Findings

No new online Godot documentation was consulted for this documentation-only scaffold.

Before implementation, verify current official Godot behavior for any API touched in code:

- `PhysicsDirectSpaceState3D` ray query parameters and `hit_from_inside`.
- Mesh/shape intersection behavior if direct-shape sampling is changed.
- `Image`/`Texture2D` readback and import/storage behavior for probes.
- Shader texture sampling and derivatives if debug view or runtime flow display changes.
- Windowed versus headless limitations for viewport capture/readback.

## Legacy Waterways Reference

Use this section only if a future fix needs legacy comparison.

- Relevant legacy files: not inspected for this scaffold.
- Behavior to preserve: do not remove water under upper-only geometry unless the waterline is actually blocked.
- Behavior to change: any active Godot 4.6+ path that classifies upper-only geometry as waterline solid.
- Obsolete APIs to avoid: any Godot 3 API found during legacy lookup.
- Risks discovered in `audit/code-audit.md`: not checked yet.
- What belongs in active Godot 4.6+ code: focused waterline/occupancy or bank-flow corrections with validation.
- What should remain legacy-only: old implementation details that conflict with current architecture.

## Local Context

Related folders to read before implementation:

- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/`: primary regression baseline for pressure-projected flow, `water_occupancy`, overhang/wide-top notes, debug arrow caveats, and obstacle probes.
- `addons/waterways/docs/spec-driven/features/river-object-artifacts/`: terrain-contact classification, overhang/wide-top artifact notes, and object participation policy.
- `addons/waterways/docs/spec-driven/features/river-flowmap-seams/`: seam and world-sample behavior that may matter if bank inward spots align to atlas/tile boundaries.
- `addons/waterways/docs/architecture-and-features.md`: current architecture summary if implementation changes behavior.

Specific prior obstacle-flow details to compare against current code:

- `water_occupancy` texture exists in bake data, is bound to river/debug materials, and clips/stills water as documented. Status 2026-06-15: present in current code; main Demo `water_occupancy.r` mean 0.1413 and near-one coverage 14.12%.
- `obstacle_avoidance_algorithm` and `flow_projected` metadata are written and consumed. Status 2026-06-15: current code writes/reads the metadata; both Demo bakes report `flow_projected=true`.
- Runtime contextual slide is skipped for projected fields. Status 2026-06-15: present in `river.gdshader`, `river_debug.gdshader`, and `system_renders/system_flow.gdshader`; `system_map_renderer.gd` plumbs `i_flow_projected`.
- Protrusion occupancy requires sufficient source confidence so upper-only/overhang collider data does not mark open water as solid. Status 2026-06-15: present in `create_solid_occupancy_source_image()`.
- FLOW_ARROWS debug view uses sub-cell fallback and low-speed scaling/threshold behavior so slow residual vectors do not look like confident direction errors. Status 2026-06-15: present; safe probes pass on both Demo bakes.
- Existing probes have save/readback caveats that must be respected before running them.

Safe probe findings from 2026-06-15:

- `river_occupancy_flow_inspect_probe.gd`: main Demo solid coverage 14.12%, obstacle test 14.78%; both `flow_projected=true`.
- `flow_arrow_neutral_cells_probe.gd`: both bakes pass; stilling-ring neutral cells are low (4 main, 3 obstacle), so the old over-wide stilled-zone problem is not broadly present in saved Demo bakes.
- `flow_arrow_direction_outlier_probe.gd`: low-count, low-magnitude outliers (11 main, 7 obstacle) remain consistent with the prior debug-arrow caveat rather than a broad high-speed inward-flow defect.
- `system_flow_compare_probe.gd -- enforce=all -- allow_stale=1`: reaches `SYSTEM_FLOW_COMPARE_OK`, but both WaterSystem maps are stale, so thresholds are report-only.
- `river_flowmap_seam_probe.gd`: reaches `RIVER_FLOWMAP_SEAM_PROBE_OK`; flow channels are continuous at logical depth 0.

## Options

### Option A: Waterline-contact occupancy correction

- Benefits:
  - Directly addresses the suspected wide-top/overhang gap mechanism.
  - Can preserve true solid clipping while restoring water under open upper geometry.
- Costs:
  - May require extra bake provenance, raycasts, or shape tests.
  - Needs careful validation so true obstacle interiors do not leak water.
- Risks:
  - Overfitting to demo rocks or screenshots.
  - Confusing visible mesh with collision footprint.
- Fit for Waterways:
  - Good if probes show occupancy false positives in open waterline areas.

### Option B: Debug/view correction only

- Benefits:
  - Smallest change if the saved flow/occupancy data is correct.
  - Avoids rebake/data migration.
- Costs:
  - Does not fix actual missing rendered water or wrong runtime flow.
- Risks:
  - Could hide a real data defect if used prematurely.
- Fit for Waterways:
  - Good only if probes prove the issue is display-only.

### Option C: Bank-flow projection or tangency correction

- Benefits:
  - Targets real inward vectors if they exist in baked open water.
  - Can improve river direction consistency near banks.
- Costs:
  - Could affect many flows, seams, and obstacle boundaries.
- Risks:
  - Over-correcting legitimate local turns or low-speed wake regions.
  - Damaging existing non-penetration guarantees.
- Fit for Waterways:
  - Good if bank inward patches are high-magnitude and not just debug artifacts.

### Option D: Scene/collider/bake-participation guidance

- Benefits:
  - Correct if the water gap follows an intentionally oversized collider.
  - May avoid risky code changes.
- Costs:
  - Places more burden on scene authors.
  - Does not solve systemic false positives from the bake.
- Risks:
  - Can feel like a workaround if the tool should infer the right footprint.
- Fit for Waterways:
  - Good if probes show the current bake is faithfully using scene collision but the scene collision is too broad for water purposes.

## Recommendation

Do not pick a new production design yet. First, compare the current project to the older working obstacle-flow design, then add evidence and probes that can answer:

- Did this texel become non-water because of collision, terrain-contact protrusion, occupancy proximity, shader clipping, or stale data?
- Is this bank vector wrong in the saved flow map, after runtime shader adjustment, or only in debug display?
- Is the vector magnitude high enough for its direction to matter?

After that, restore the documented prior behavior if it was lost. Only invent a new fix if current code still matches the old docs and the screenshots prove a new edge case.

## Risks and Unknowns

- Screenshots may show symptoms from older generated bakes rather than current code.
- The original fix may exist in docs but no longer exist in code, material binding, metadata, or regenerated resources.
- The visible lower object may not match its collision shape.
- Probe thresholds for "inward" must account for local river curvature and low-flow areas.
- Running rebake probes can save generated resources and dirty the worktree.
- Human-visible validation will still be needed even if probes pass.

## Context Challenge Notes

- Possible misread context:
  - A top-down gap may actually be correct if the collision footprint at water height is broad.
  - A bank arrow may be visually wrong but data-correct if the vector magnitude is nearly zero.
- Evidence:
  - Prior obstacle-flow docs already mention solid-center FLOW_ARROWS cells and low-speed direction outliers.
- Confidence:
  - Medium; plausible but not enough to patch.
- Quick check before patching:
  - Fresh rebake plus occupancy/flow debug capture at one reported obstacle and one bank spot.
- User-facing note or question to raise:
  - Ask for screenshots with scene name, debug mode, whether the bake was freshly regenerated, and whether the object collision shape differs from the visible mesh.

## Sources

- `addons/waterways/docs/research/river-research-citations.md`: shared works-cited index for Waterways river behavior, hydrology, flow-map, shader-water, and production-reference sources.
- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/spec.md`: prior occupancy/projection contract.
- `addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/implementation-plan.md`: prior overhang, occupancy, and debug-arrow diagnosis.
- `addons/waterways/docs/spec-driven/features/river-object-artifacts/spec.md`: prior object-adjacent classification and overhang artifact contract.
- `addons/waterways/docs/spec-driven/features/river-object-artifacts/symptoms and initial suspects.md`: initial object artifact diagnostic frame.
