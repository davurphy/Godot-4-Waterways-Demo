# Tasks: River Eddies

Complete tasks in order unless the plan is revised. Each task should be independently reviewable.

## Current Truth

- Current status: Phase 7B visual baseline accepted; feature-folder migration complete in this docs pass.
- Current implementation slice: Preserve accepted wake/eddy-line visual baseline and document future Phase 7C/7D boundaries.
- Remaining open task count: 10
- Last passing validation: Historical Godot 4.6.3 probes `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_WAKE_EDDY_EXPORT_OK`, and `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`; user accepted the visible result after the material-override fix and stronger defaults.
- Next recommended action: Use this folder as the source of truth before future wake/eddy edits; if a new issue is reported, review raw source, final mask, and visible water in that order.
- Known deferred work: Real reverse/circulating flow, WaterSystem/physics alignment, new eddy vector data, Phase 7C, and Phase 7D.

## Open Work

Use this section as the canonical checklist for unfinished eddy work. Items are ordered by boundary and dependency. When items close, update stale "open" language in `spec.md`, `plan.md`, `validation.md`, `review.md`, and the latest handoff.

- [ ] Before any future eddy/wake code change, lock one detection or flow question and a small target set.
  - Validate: Review notes list target scene, camera/view, upstream/downstream direction, should-detect areas, should-not-detect controls, and whether the request is raw source, final mask, visible response, or actual flow.

- [ ] Preserve the accepted Phase 7B baseline after any shared shader/classifier change.
  - Validate: `Eddy-Line Visual Mask` still uses the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`.

- [ ] Preserve old raw-B diagnostics until a later spec intentionally removes them.
  - Validate: B-based views remain available: `Eddy-Line / Shear Mask`, `Gated Eddy-Line Source (B * Wake Gate)`, `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, and `Eddy-Line Wake Context Search`.

- [ ] If visible eddy-line placement is questioned, follow raw source first, final mask second, visible water last.
  - Validate: Compare `Raw Wake-Edge Candidate (from G)`, B-based diagnostics, `Eddy-Line Visual Mask`, and visible water at the same targets before editing.

- [ ] If raw/final masks remain accepted but visible response is too subtle or too strong, tune material response only.
  - Validate: No river bake source-signature bump, no river rebake, no final-flow change, no WaterSystem shader wiring, and no saved WaterSystem regeneration.

- [ ] If raw source placement is proven wrong, plan a scoped classifier or source-channel change.
  - Validate: Plan records source-signature bump, main and obstacle-test rebakes, metadata/stat updates, probes, and fresh review captures.

- [ ] If Phase 7C reverse/circulating flow is requested, write a new plan before code.
  - Validate: The plan updates visible shader, debug shader, system-flow shader, WaterSystem generation, saved bake regeneration, and runtime validation together.

- [ ] Decide the Phase 7C data model before implementation.
  - Validate: Spec/plan chooses explicit eddy vector data, analytic vector field, or another generated flow layer and records center/spin/radius/strength semantics.

- [ ] Add raw readings or named-region stats only if target coverage is ambiguous.
  - Validate: Report raw G/B/A coverage, final-mask coverage, raw-to-final retention, ordinary-bank false positives, hard-protrusion support, grade/energy support, final-flow support, and top suppressors when possible.

- [ ] Update feature docs, changelog, shared handoff, and roadmaps as needed after any decision or code/bake change.
  - Validate: `Current Truth` sections agree across docs and the shared handoff points to this folder for eddy work.

## Setup

- [x] Confirm the current workspace state.
- [x] Read `spec-driven` constitution and workflow.
- [x] Read feature-folder templates.
- [x] Read `docs/history/CHANGELOG.md`.
- [x] Read `docs/handoffs/handoff-latest.md`.
- [x] Read `docs/roadmaps/river-feature-detection-roadmap.md`.
- [x] Read `docs/roadmaps/river-improvements-roadmap.md`.
- [x] Confirm there is no eddy audit document to fold in.
- [ ] Check any future `docs/audit/` notes for relevant known risks before code changes.
- [ ] Confirm whether the next task affects active code in `addons/waterways`, legacy reference code in `legacy/godot-3/addons/waterways`, or both.
- [ ] Run the context challenge check before patching: if the user or agent may be treating visual-only eddy cues as real flow/physics, raise that with evidence.

## Implementation

- [ ] For visual-only work, keep changes in visible/debug shader masks, material response, debug views, probes, and docs.
  - Validate: No source-flow, final-flow, source-signature, river bake, WaterSystem shader, or saved WaterSystem bake changes occur.

- [ ] Use the review order: raw mask, final mask, visible water.
  - Validate: Notes explain which layer failed before any code change.

- [ ] Add low-range, threshold-band, composite, or named-region diagnostics only when the current views cannot answer the question.
  - Validate: The new diagnostic answers a specific placement/readability question and does not become a distraction.

- [ ] Apply the smallest code change matching the diagnosed layer.
  - Validate: Run the relevant automated checks and request human-visible Godot review if visual placement changed.

- [ ] Rebake only when bake/classifier output changes.
  - Validate: Source signature, metadata, saved bakes, and probe expectations match.

- [ ] Regenerate WaterSystem only when final/physics flow changes.
  - Validate: Visible/debug/system-flow parity and runtime validation are recorded before acceptance.

## Validation

- [ ] Run automated checks listed in `validation.md`.
- [ ] Revisit the context challenge check after validation. If results suggest the premise was wrong, tell the user and update docs before doing more implementation.
- [ ] For Godot editor, viewport, scene-running, shader, bake, or runtime checks, ask the user in chat to run the exact check and relay output, screenshots, version/renderer, and visible behavior.
- [ ] Do not rely on `validation.md` alone for human-assisted checks; paste the requested steps into the user-facing message.
- [ ] Open the visual test scene through human-assisted validation unless the agent can genuinely use the visible editor.
- [ ] Check shader output/debug views through human-assisted validation.
- [ ] Check runtime sampling/API behavior through human-assisted validation or a proven non-crashing runtime check if Phase 7C/7D is scoped.
- [ ] Record results in `review.md`.

## Cleanup

- [ ] Remove temporary debug code that is not part of the planned validation UI.
- [ ] List scratch/generated artifacts created during validation and decide whether to keep, exclude, or delete them.
- [ ] Confirm packaging excludes disposable folders, generated bakes, editor caches, validation fixtures, and local probe outputs.
- [ ] Add or refine comments for non-obvious shader math, source-tile sampling, Godot quirks, performance-sensitive paths, and architectural boundaries.
- [ ] Update docs for any changed decisions.
- [ ] Confirm generated data and resources are explicit and inspectable.
- [ ] Confirm editor-only state did not leak into runtime-only code.
- [ ] Confirm no obsolete Godot 3 APIs were introduced into active Godot 4.6+ code.

## Historical or Closed Tasks

- [x] Phase 7A0 completed adversarial review and roadmap revision.
- [x] Phase 7A1 added review-only wake/eddy preflight/export helpers and no runtime behavior change.
- [x] Phase 7A2 narrowed raw `obstacle_features.b`, bumped river bakes to source signature `17`, and kept final flow/WaterSystem unchanged.
- [x] Phase 7B added visual-only wake/eddy material controls, masks, debug views, probes, and exports.
- [x] Phase 7B edge-sample-only fix was rejected.
- [x] Phase 7B promoted raw-G wake-edge candidate into `Eddy-Line Visual Mask` at `wake_edge_sample_tiles = 0.024`.
- [x] Phase 7B preserved old raw-B diagnostic views.
- [x] Phase 7B fixed stale debug-material override behavior so visible `wake_` fields affect normal rendering.
- [x] Phase 7B increased visible eddy-line response defaults after review found the first visible pass too subtle.
- [x] Phase 7B user review accepted the visible material pass.
- [x] Created this feature-local spec folder from the shared changelog, shared handoff, and roadmaps.
