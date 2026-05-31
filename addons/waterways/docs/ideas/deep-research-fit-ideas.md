# Possible Future Ideas From Water Research

Date: 2026-05-31

This document collects ideas from the deep water-rendering research report, the current Waterways codebase, and recent pillow/wake/eddy review work.

It is intentionally not a generic water-rendering wish list. Ideas belong here only if they fit the Waterways add-on as a spline-river authoring, bake, shader, debug, and optional physics-sampling tool.

Related local documents:

- `../research/river-research-citations.md`
- `../roadmaps/river-feature-detection-roadmap.md`
- `../roadmaps/river-improvements-roadmap.md`
- `../audit/pillow-system-audit.md`

## Scope Filter

An idea fits Waterways if it:

- Improves spline-authored rivers, river bakes, river feature masks, river materials, WaterSystem maps, buoyancy sampling, or editor review tools.
- Keeps rivers as the main target instead of turning the add-on into a general ocean renderer.
- Works with the existing packed-texture and bake-resource architecture, or clearly extends it.
- Helps users author, inspect, validate, import, or tune river data.
- Can be reviewed in the editor with raw views, final masks, and clear before/after captures.

An idea should stay out of scope if it:

- Requires a full global fluid simulation as the core product.
- Makes Waterways responsible for oceans, weather, boats, naval gameplay, or general-purpose VFX.
- Replaces the current river bake pipeline with a large external DCC pipeline.
- Depends on heavy compute or renderer-specific features without a simple fallback.
- Cannot be explained through the existing source maps, feature maps, or WaterSystem data.

## Highest-Value Near-Term Ideas

### Pillow Formula Diagnostic Split Views

Source: Current pillow audit and the research report's obstacle-interaction framing.

Why it fits:

- The current pillow issue is a Waterways bake/debug problem.
- It directly improves user trust in the feature masks.
- It can be implemented inside the current debug-view architecture.

Possible views:

- Pillow support/facing source.
- Direct `terrain_contact_features.b` anchor.
- `bank_response_features.a` anchor contribution.
- Combined pillow contact gate.
- Bank-response-only anchor contribution.
- Raw-to-final pillow retention.

First useful step:

- Add debug-only views before changing the classifier again. If those views prove the source formula, then make the smallest bake-level change.

Guardrail:

- Do not tune pillow color, foam, height, or brightness until raw placement is accepted.

### Direct-Contact-First Pillow Classifier

Source: Pillow audit, hydrology references, and report discussion of obstacle proximity.

Why it fits:

- It targets the exact current false-positive risk: pillows starting ahead of visible rocks.
- It keeps `bank_response_features.a` useful for wake, eddy, bank, and flow-slide context while preventing it from acting as literal pillow contact by itself.

Possible shape:

```text
direct_anchor = tight local search of terrain_contact_features.b
semantic_context = weak bank_response_features.a support
source = tighter support * facing^2 * bank suppression
raw_pillow = source * direct_anchor_gate * context_gate
```

First useful step:

- Implement only after diagnostic split views and live review confirm that broad semantic anchoring is the actual remaining problem.

Guardrail:

- This is a bake-level classifier change. It needs source-signature bump, rebakes, stats, and regression checks for accepted wake/eddy behavior.

### Raw-To-Final Mask Retention Reports

Source: Current review loop and the need to separate raw placement from shader gating.

Why it fits:

- Waterways already has raw maps, final debug views, and scripted readbacks.
- It gives future sessions a numeric way to answer "is the source wrong or did a gate remove it?"

Useful reports:

- Raw coverage in expected regions.
- Final coverage in expected regions.
- Retention percentage from raw to final.
- False-positive coverage in ordinary-bank regions.
- Top suppressing gates: confidence, hard-boundary, bank suppression, energy, flow, edge thinness.

First useful step:

- Generalize the pillow and eddy diagnostic scripts into a reusable report runner with named regions.

Guardrail:

- Metrics guide review. They do not replace viewport acceptance.

### Shader Helper Includes For Visible And Debug Parity

Source: Pillow audit and current duplication between `river.gdshader` and `river_debug.gdshader`.

Why it fits:

- The visible shader and debug shader duplicate important mask and gate math.
- Shared helpers would reduce drift between what the user sees and what the debug modes claim.

Candidate includes:

- Flow decode and contextual flow-force helpers.
- Pillow masks and gates.
- Wake and eddy-line gates.
- Boundary/contact helpers.
- Debug palette helpers if useful.

First useful step:

- Wait until the next pillow formula is stable, then extract a small helper block rather than refactoring the whole shader at once.

Guardrail:

- Add a simple parity probe or string/checksum test so future shader edits do not silently diverge.

### Bake Data Inspector And Channel Metadata Panel

Source: The report's emphasis on packed data textures, and Waterways' existing `RiverBakeData` metadata.

Why it fits:

- Waterways bakes are now rich data assets, not just flow maps.
- Users need to know whether a bake is current, what each channel means, and whether maps were imported or generated.

Possible UI:

- Texture sizes and source signature version.
- Current/stale status.
- Channel layout summary.
- Source kind and generation behavior.
- Coverage/stats summary for flow, foam, pillow, wake, eddy, terrain contact, and bank response.
- "Open debug view for this channel" shortcuts.

First useful step:

- Add a read-only inspector or menu action that prints a compact bake summary before building a full UI.

Guardrail:

- Keep it informational. Do not make the inspector mutate bakes until the workflows are clearly designed.

## Authoring And Import Ideas

### External Flowmap Import Profile

Source: SideFX flowmap references and the report's Houdini/DCC workflow section.

Why it fits:

- Waterways can remain a procedural river tool while allowing expert users to override or supplement generated flow.
- The bake metadata already includes future source kinds such as imported linear data maps and DCC/simulation flow maps.

Possible workflow:

- User assigns an imported RG flow texture to a river.
- Waterways validates import settings: linear color, no sRGB, no lossy compression, no mipmaps unless explicitly allowed.
- Existing feature maps remain generated unless the user also imports compatible feature maps.
- Metadata records imported source path, expected neutral flow, and channel layout.

First useful step:

- Add a documented import contract and validation function before building editor UI.

Guardrail:

- Imported flow should not bypass validation or silently invalidate WaterSystem physics sampling.

### Author Override Layers

Source: Flowmap painting workflows, Crest water inputs, and current desire to avoid overfitting procedural masks.

Why it fits:

- Waterways users may need small local corrections without changing global bake constants.
- Overrides can be additive and inspectable rather than replacing the whole bake.

Possible override types:

- Flow vector nudge.
- Pillow add/remove.
- Wake add/remove.
- Eddy-line add/remove.
- Ordinary-bank suppression.
- Hard-protrusion boost.

Possible storage:

- Optional per-river override texture.
- Optional per-river marker nodes that bake into an override map.
- Metadata in `RiverBakeData` recording override source and version.

First useful step:

- Start with scripted or marker-based overrides, not a full paint tool.

Guardrail:

- Overrides must be visible in debug views so users can distinguish procedural signal from authored edits.

### Obstacle Semantic Tags

Source: Current terrain/contact ambiguity and the research report's distinction between rocks, banks, and obstructions.

Why it fits:

- The current bake samples collision and terrain contact, but not all collision should mean the same thing.
- A tagged object can say "this is hard obstruction", "this is ordinary bank", or "ignore this for water features".

Possible tags or groups:

- `waterways_hard_obstruction`
- `waterways_soft_bank`
- `waterways_feature_ignore`
- `waterways_contact_only`
- `waterways_wake_source`

First useful step:

- Add a design note and one experimental group filter in the collision/contact sampling path.

Guardrail:

- Do not require tags for normal use. The procedural default should still work.

### Synthetic Review Scenes

Source: Current generalization checks and the report's warning about complex obstacle behavior.

Why it fits:

- Small scenes make classifier regressions obvious.
- They help separate demo-scene tuning from add-on improvement.

Useful scenes:

- Straight channel with one boulder.
- Straight channel with one wall protrusion.
- Smooth ordinary bank with no hard obstruction.
- Narrow channel with banks close to rocks.
- Wide low-energy river.
- Steep chute or rapid section.
- Confluence or overlapping river section.

First useful step:

- Create one isolated-boulder test scene and reuse existing export/probe scripts.

Guardrail:

- Keep scenes minimal and deterministic. They are test fixtures, not showpieces.

## Visual Feature Ideas

### Better Foam Layer Separation

Source: Deep report's foam categories and current Waterways packed masks.

Why it fits:

- Waterways already has baked foam, flow force, grade/energy, pillows, wakes, and eddy-line masks.
- Foam can become more readable if its sources are separated instead of collapsing into one visual result.

Possible foam layers:

- Shore/contact foam from distance or terrain contact.
- High-energy/rapid foam from grade and flow force.
- Pillow flecks on upstream impact faces.
- Wake flecks downstream of obstructions.
- Eddy-line flecks along wake margins.

First useful step:

- Add debug views that show foam source components separately before adding new material controls.

Guardrail:

- Avoid using foam as a crutch for mispositioned masks. Foam should reveal accepted features, not hide detection errors.

### Lightweight Rapids Wave Stamps

Source: Uncharted 4 wave-particle research and the report's "flat sliding normals are not enough" point.

Why it fits:

- Rapids are a natural river feature.
- Waterways already knows flow direction, energy, support, and obstacle/wake masks.
- A lightweight stamp layer can be optional and river-local.

Possible implementation shapes:

- Shader-only normal intensity and banding driven by grade/energy plus wake/pillow masks.
- Baked height/normal stamp texture generated from high-energy obstacle regions.
- Optional particles or MultiMesh quads that advect downstream using WaterSystem flow.

First useful step:

- Prototype a shader-only "rapids detail mask" using existing data before adding particles or new textures.

Guardrail:

- Do not build a general compute fluid solver to solve visual rapids unless simpler layers fail.

### River-To-Waterfall Handoff

Source: Deep report's waterfall seam section.

Why it fits:

- Waterfalls and drops are river continuity problems.
- A separate waterfall material or handoff node can live beside River without making River itself an ocean/waterfall renderer.

Possible features:

- Optional endpoint or segment marker for waterfall handoff.
- Alpha erosion or fade mask near a drop.
- Separate downward-scrolling waterfall material.
- Spray/mist hooks left to the project, not owned by Waterways.

First useful step:

- Document a handoff pattern and add a simple material preset before adding authoring tools.

Guardrail:

- Keep waterfall rendering separate from the flat river flow shader.

### Caustics And Wetness Hooks

Source: Deep report's caustics, screen/depth, and wetness sections.

Why it fits:

- Waterways already has a WaterSystem map and wet-node assignment.
- Caustic and wetness hooks can be optional material parameters assigned to affected surfaces.

Possible features:

- Projected caustic texture controlled by WaterSystem map coordinates.
- Wet material parameter assignment for nodes in `wet_group_name`.
- Simple fade by system-map alpha and height.

First useful step:

- Extend the wet target contract documentation before adding shader expectations.

Guardrail:

- Do not require all terrain materials to use a Waterways shader. Keep assignment optional.

## WaterSystem And Physics-Facing Ideas

### WaterSystem Debug Viewer

Source: Current WaterSystem sampling and the report's gameplay-volume framing.

Why it fits:

- WaterSystem maps already drive buoyancy and wet material assignment.
- Users need to trust world-space sampling, coverage, height, and flow.

Possible tools:

- Show system-map coverage in editor.
- Sample flow/height at cursor or selected node.
- Validate covered samples near each river.
- Show stale river source warnings with source metadata details.

First useful step:

- Add a compact "print sample at selected node" action before building a full map viewer.

Guardrail:

- Keep WaterSystem validation separate from individual River bake validation.

### Flow Magnitude And Energy For Buoyancy

Source: Report discussion of rivers as interactive gameplay volumes.

Why it fits:

- Waterways already samples flow on the CPU for `Buoyant` nodes.
- Current maps can provide more context than direction alone.

Possible data:

- Flow direction.
- Flow force or magnitude.
- Water coverage.
- Height.
- Optional energy or rapid indicator.

First useful step:

- Audit what is already preserved in the system map and whether extra channels would require a new resource layout.

Guardrail:

- Do not promote visual scalar masks like wake or eddy-line directly into reverse/circulating physics flow. They do not encode enough vector information.

### Optional Eddy Vector Descriptors

Source: Current roadmap warning that scalar eddy masks are not physics flow.

Why it fits:

- Eddy visuals are accepted, but physics-facing eddies need different data.
- A compact descriptor layer could stay river-local and optional.

Possible descriptors:

- Eddy center.
- Radius.
- Spin direction.
- Strength.
- Downstream leakage.
- Confidence.

First useful step:

- Create a research note and synthetic test scene before changing maps.

Guardrail:

- This is later-phase work. Do not block visual eddy-line progress on physics eddies.

### Debris Or Foam Fleck Advection Demo

Source: Report examples of leaves/debris following vector flow.

Why it fits:

- It demonstrates CPU or shader sampling of WaterSystem flow.
- It helps users see whether flow direction and magnitude are plausible.

Possible implementation:

- Optional demo script that moves lightweight particles or MultiMesh instances by WaterSystem flow.
- Debug-only or sample-scene feature, not core runtime requirement.

First useful step:

- Build a small demo helper after WaterSystem sampling validation is stable.

Guardrail:

- Keep it as an example consumer of WaterSystem data, not a required part of River.

## Architecture And Maintainability Ideas

### Bake Resource Versioning And Migration Notes

Source: Current source signature bumps and packed channel evolution.

Why it fits:

- Waterways bakes are now versioned data products.
- Future users need clear stale/mismatch behavior and migration expectations.

Possible improvements:

- Explicit bake layout version separate from source signature version.
- Migration notes per signature bump.
- Warnings for old resources with missing channels.
- One-click rebake checklist in editor.

First useful step:

- Document current signature/version meanings and add validation messages where they are ambiguous.

Guardrail:

- Do not auto-mutate old resources without user intent.

### Renderer Profile Presets

Source: Godot rendering limitations and the report's platform constraints.

Why it fits:

- Waterways uses depth texture, screen texture, transparent water, and relatively complex shader logic.
- Different targets may need different defaults.

Possible profiles:

- Desktop Forward+: full material.
- Desktop debug: heavier debug views enabled.
- Mobile/Compatibility: simplified refraction/depth behavior.
- Low-spec: reduced wake/eddy/pillow detail.

First useful step:

- Add documentation and material preset values before adding editor automation.

Guardrail:

- Do not weaken the main desktop path just to satisfy all renderers.

### Bake Profile Presets

Source: Current bake parameters and research report's distinction between slow streams, rapids, and DCC workflows.

Why it fits:

- Users need repeatable settings for common river types.
- Presets can reduce blind tuning of `baking_dilate`, resolution, blur, and feature constants.

Possible presets:

- Smooth creek.
- Rocky stream.
- High-energy rapid.
- Broad slow river.
- Debug/high-resolution bake.

First useful step:

- Define preset metadata and print what values would change before adding a one-click apply action.

Guardrail:

- Presets should not hide source-signature changes. Applying one should clearly invalidate bakes when needed.

### Review Artifact Manifest

Source: Current `.codex-research` workflow and the need to preserve user-reviewed evidence.

Why it fits:

- Waterways tuning depends on repeatable visual review.
- Captures, probes, and parameter sweeps need context to be useful later.

Manifest fields:

- Scene.
- River path.
- Bake signature.
- Debug view.
- Material mode.
- Camera name or transform.
- Script path.
- Important parameters.
- User verdict.

First useful step:

- Add a small JSON or Markdown manifest writer to existing export scripts.

Guardrail:

- Keep this tooling lightweight. It should support review, not become a test framework by itself.

## Later But Still Plausibly In Scope

### River-Local Compute Wake Patch

Source: Deep report's compute wake discussion.

Why it may fit:

- A small optional height/ripple buffer centered on a player or obstacle could layer onto river surfaces.
- It would be a river interaction feature, not a full world fluid simulation.

Why it is risky:

- Forward+ only.
- More complex resource lifetime and renderer assumptions.
- Needs fallback behavior.

First useful step:

- Treat as a separate experimental module after static feature masks and WaterSystem sampling are stable.

### Optional Shallow-Water Solver Prototype

Source: Future research leads and shallow-water references.

Why it may fit:

- Could help if scalar masks are no longer enough for flow around complex obstacles.

Why it is risky:

- It can easily become a different product.
- It may duplicate what DCC import or authored overrides solve more cheaply.

First useful step:

- Keep as research only until there is a specific Waterways problem that cannot be solved with current bakes, override maps, or shader layers.

### Lake Or Wide-River Surface Mode

Source: Gerstner and lake/ocean references.

Why it may fit:

- Some river systems widen into pools or lakes.
- A separate material mode could reduce reliance on downstream flow in still water.

Why it is risky:

- It can drift into ocean rendering.

First useful step:

- Define a wide-river/still-pool material preset using existing flow maps before adding Gerstner or FFT logic.

## Explicit Non-Goals

These ideas may be interesting, but they should not be treated as Waterways roadmap items unless the add-on's scope changes deliberately.

- Full ocean rendering with FFT/CDLOD as a core feature.
- A Godot clone of Unreal Single Layer Water.
- A complete Houdini/FLIP authoring pipeline inside Godot.
- Global weather, tides, wave climate, or hydrology simulation.
- Machine-learning fluid inference.
- Full boat/naval gameplay systems.
- A general VFX particle package for spray, mist, rain, and waterfalls.
- Replacing the existing spline river workflow with a compute simulation-first workflow.

## Suggested Sequencing

1. Finish pillow diagnostic split views and formula review.
2. Stabilize visible/debug shader parity with shared helpers.
3. Generalize raw-to-final mask reports and named-region review tools.
4. Add bake data/channel inspector output.
5. Add small synthetic review scenes.
6. Design import/override contracts before implementing external flowmap import or authored overrides.
7. Explore visual additions such as better foam separation, rapids detail, and waterfall handoff only after raw feature placement is trustworthy.
8. Leave compute wakes, shallow-water solvers, and lake/ocean behavior as isolated experiments with clear opt-in boundaries.
