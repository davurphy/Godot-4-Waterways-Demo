# Spec: River Refactor R6 - river_manager.gd Decomposition

## Summary

R6 decomposes `addons/waterways/river_manager.gd` by moving low-coupling responsibilities behind narrow helper objects while preserving the current public RiverManager surface and generated bake behavior. The target extractions are the async flow-map bake coordinator, bake-constant dictionary assembly, runtime ripple material ownership, and editor validation harnesses.

This phase is intentionally behavior-preserving. It must not change bake output, bake metadata except the documented dynamic allow-list, public API behavior, inspector behavior, shader output, runtime ripple behavior, editor validation markers, or the bake signature version.

## Current Truth

- Status: Draft R6 spec. No R6 implementation has started.
- Source of truth for open work: `tasks.md` in this folder, backed by `plan.md`.
- Last meaningful decision: R6 preserves the existing mixed source-timing contract by default. Any deliberate freeze-at-start change must be documented here and validated by a mid-bake edit probe or named human-assisted case.
- Known deferred items: R7 GPU-resident solve is out of scope. Parent docs are updated only after R6 validation runs.
- Current non-goals that are easy to accidentally reopen: no bake algorithm changes, no signature bump, no filter-pass changes, no shader output changes, and no changes to runtime ripple simulation itself.

## Goals

- Extract the async bake pipeline into `river_flowmap_baker.gd` as a `RefCounted` coordinator.
- Centralize bake constants in `river_bake_constants.gd` so source metadata, source signature, and bake settings constant rows are generated from reviewable table data.
- Extract runtime ripple material ownership into `river_ripple_material_owner.gd` while keeping RiverManager's public ripple API unchanged.
- Extract editor validation routines into `river_editor_validation.gd` or a locally consistent editor-helper path while preserving public RiverManager wrappers, menu behavior, and console markers.
- Prove behavior preservation with texture hashes, dictionary diffs, API/signal/property-list diffs, source-image hashes, abort/lifecycle checks, and existing regression probes.

## Non-Goals

- No bake algorithm changes.
- No bake signature bump; R6 keeps signature version 28.
- No new filter passes or pass-order changes except moving existing sequencing behind the baker.
- No shader output changes.
- No changes to `RiverBakeData` channel semantics.
- No R7 GPU-resident solve or compute migration work.
- No runtime ripple simulation changes. R6.3 moves only RiverManager's material ownership glue.

## Context and Assumptions

- Shared works-cited index: `addons/waterways/docs/research/river-research-citations.md`.
- Parent track: `addons/waterways/docs/spec-driven/features/river-refactor/roadmap.md`.
- R5 closed on 2026-06-13 with RT.1 texture hashes, exact property-list diff, and `R5_BEHAVIOR_PRESERVATION_PROBE_OK`.
- `river_manager.gd` after R5 still owns bake request guards, `_generate_flowmap()`, source-image helpers, diagnostics, `_write_bake_data()`, metadata/signature/settings builders, runtime ripple material ownership, and editor validation harnesses.
- Agent confidence in the premise: high. R6 is a planned decomposition phase, not a user-reported behavior defect.
- Possible expected-behavior explanation to rule out before patching: a validation mismatch may be caused by stale baseline bakes or regenerated resources, not by the refactor. Fresh pre-R6 baselines are required before implementation.
- Clarification already raised with the user: none for R6. The phase is blocked only on docs, baselines, and validation setup.

## Users and Workflows

### User Story: Add-on Maintainer

As an add-on maintainer, I want `river_manager.gd` to stop owning the whole bake and validation world, so that future bake and runtime work can be reviewed through smaller modules without losing the existing behavior contract.

Acceptance criteria:

- `RiverManager` remains the public authoring node and API surface.
- New helpers own implementation details only through explicit config, result, callback, and status data.
- No helper receives a general RiverManager reference as a shortcut.
- Behavior-preservation gates pass before R6 is closed.

### User Story: Plugin and Scene Author

As a project author using existing Waterways scenes and plugin actions, I want R6 to be invisible unless I inspect the code, so that existing bakes, menus, inspectors, runtime ripple material state, and public scripts continue to work.

Acceptance criteria:

- Existing public methods and signals remain callable.
- Inspector property list remains unchanged.
- Menu validation actions still emit the same stable console markers.
- Existing generated bake textures and data remain valid.

## Functional Requirements

- `RiverManager` must remain responsible for public API methods, inspector properties, signals, scene-owned state, final material binding, generated mesh ownership, and final `RiverBakeData` ownership.
- `river_flowmap_baker.gd` must own bake run state, filter renderer lifecycle, pass sequencing, abort cleanup, source image synthesis, diagnostics, and bake result assembly.
- The baker must consume `BakeConfig`, local state, or explicitly named callbacks only. Passing `self`, a generic owner object, or a broad RiverManager reference through the baker is not allowed.
- `BakeConfig` entries must be tagged during implementation as one of: bake-start snapshot, live resource intentionally read during bake, final-read callable used only during result application, or narrow side-effect callable.
- `BakeResult` must carry final `ImageTexture` resources, not just `Image` data, to preserve current `ImageTexture.create_from_image()` timing.
- RiverManager result application must preserve the existing non-awaited sequence unless an explicit staging/rollback strategy is implemented and validated.
- `BakeAbort` must turn old early returns into controlled exits with status, label, message, readback error where relevant, stage, and renderer validity.
- `river_bake_constants.gd` must keep dynamic values out of the constants table: curve points, widths, flow speeds, texture stats, diagnostics, content rect, and revision timestamp.
- Constants-table rows that do not feed `source_signature` must include a reason and a review decision so future changes do not look automatically signature-safe.
- Runtime ripple public wrappers must remain on RiverManager:
  - `apply_runtime_ripple_material_state(owner, parameters)`
  - `clear_runtime_ripple_material_state(owner)`
  - `has_runtime_ripple_material_state(owner = null)`
- Editor validation public wrappers must remain on RiverManager:
  - `validate_data_textures()`
  - `validate_filter_renderer()`
- Existing console markers must remain unchanged, especially `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST`.

## Source Timing Contract

R6 defaults to preserving the old mixed timing. Any change to freeze source-affecting values at bake start must be explicitly recorded in this section and validated before code lands.

| Stage | Current timing to preserve by default | R6 rule |
| --- | --- | --- |
| Bake request and preflight | `bake_generation_behavior` is captured at bake start; preflight and mesh-generation state are read through existing RiverManager paths. | Preserve unless a named snapshot field and probe are added. |
| Pre-renderer source generation | Awaited work resumes into live reads of `mesh_instance`, `baking_raycast_layers`, `_steps`, shape divs, helper-owned scene/collision state, `curve`, `widths`, and `flow_speeds` at the point helpers run. | Preserve mixed timing or document each frozen field. |
| Curve-derived source helpers | Grade, bend-bias, flow-speed, point-offset, and baked-distance helpers currently read live curve/channel state when each helper runs. | Inputs must be explicit in `BakeConfig`; live timing is allowed only when deliberately named. |
| Filter-pass execution | Existing pass order, stride order, HDR texture policy, pressure solve texture format, margin/crop geometry, and progress labels define behavior. | Move exactly; no algorithm or output drift. |
| Final dictionary assembly | `_write_bake_data()` is mixed-timing: metadata source kind and generation mode use bake-start behavior, `flow_speed_scaled` re-reads live flow speeds, `get_bake_source_signature()` re-reads live curve/channel/bake settings, `_get_bake_settings()` re-reads live bake settings and `_uv2_sides`, and mesh bounds read final mesh/global transform. | Preserve final-read timing by default. Moving any dictionary generation into the baker requires per-field timing proof. |
| Result application | Old path creates textures, writes/finalizes `RiverBakeData`, saves, reapplies, refreshes shader parameters, clears the bake flag, emits completion, then prints the save/editor-memory notice. | Preserve order; add no awaited gap unless staging/rollback is proven. |

The mid-bake edit probe or human-assisted case must cover the fields most likely to be frozen by accident: curve points/handles, `curve.bake_interval`, widths, flow speeds, `bake_generation_behavior`, ordinary bake settings, and mesh/global transform if `mesh_global_bounds` moves. `flow_speeds` is the minimum trap case.

## Add-on Boundary

Editor authoring responsibilities:

- RiverManager inspector properties, public setters/getters, progress signal, plugin menu entry points, editor-only property-list notification, and validation wrappers.

Bake/data responsibilities:

- Baker-owned filter renderer lifecycle, pass sequencing, source-image generation, diagnostics, abort records, `BakeResult` construction, and constant-table-driven dictionary portions after shadow comparison passes.

Runtime responsibilities:

- Existing runtime APIs, material/debug state, ripple material application/restore semantics, and data-only runtime `set_widths()` / `set_flow_speeds()` behavior.

Shared code must not depend on:

- Editor-only singleton state unless the helper is explicitly editor-only.
- A specific scene tree beyond explicit collision/root/render-parent dependencies.
- RiverManager reach-back for frame awaits, liveness checks, warnings, progress, terrain/collision generation, or resource saving.

## Data and Extension Model

Users should be able to:

- Keep existing scene scripts, bakes, public RiverManager calls, plugin validation actions, and runtime ripple material ownership workflows.

Extension points:

- `river_flowmap_baker.gd` for bake orchestration.
- `river_bake_constants.gd` for reviewable constant rows and dictionary generation helpers.
- `river_ripple_material_owner.gd` for owner-token and material restore behavior.
- `river_editor_validation.gd` or equivalent for editor validation routines.

Override rules:

- RiverManager remains the only object that applies final materials, saves bake data, sets `valid_flowmap`, and emits public signals.
- Helper callbacks must be narrow and named by operation.

Shared systems must not hard-code:

- Dynamic bake state in the constants table.
- A broad owner object where a narrow dependency is enough.
- A different validation marker name for existing menu checks.

## Acceptance Tests

- Pre-R6 and post-R6 generated texture hashes match for both demo river bakes using RT.1.
- Intermediate source-image hashes match for the full raw-plus-margin R6.1D list before and after source-helper moves.
- `source_signature` and `bake_settings` canonical dumps diff exactly with no ignored keys.
- `source_metadata` canonical dumps diff exactly except the explicit dynamic allow-list, currently only `bake_revision`.
- Full public RiverManager method and signal surface diff is empty, including `river_changed` and `progress_notified`.
- Full inspector property-list diff is empty.
- Runtime ripple owner probes pass, including owner conflict, owner clear, owner tree exit, RiverManager tree exit, and debug-view toggles.
- Editor validation wrappers still run and emit the existing markers.
- Abort matrix leaves no stuck bake flag, leaked filter renderer, orphan viewport, stale progress source, or partial overwrite of valid bake data.
- Existing regression probes remain green: R5 behavior preservation, R4 runtime robustness, filter renderer load/check with `shader_paths=19`, and system-flow projected gate.

## Visual Validation Requirements

- Confirm no visible change in normal/debug river views after R6 extraction if a windowed run is available.
- Confirm River menu validation actions still call public RiverManager wrappers and emit the same console markers.
- Human-assisted checks must be requested in chat with exact steps; do not ask the user to hunt in this file.

## Performance Requirements

- R6 is not a performance phase, but decomposition must not add avoidable frame waits, GPU readbacks, or per-bake resource churn.
- Bake wall-clock is not the primary gate; byte-identical output and lifecycle safety are.
- If any helper extraction changes await count or render/update timing, record and justify it in `validation.md`.

## Open Questions

- Whether `BakeConfig`, `BakeResult`, and `BakeAbort` should remain dictionaries or become typed `RefCounted` classes once implementation starts.
- Whether R6.3 and R6.4 should land before the bake pipeline extraction for smaller review slices.
- Whether existing ripple probes already cover every R6.3 owner-conflict/tree-exit semantic or need a focused probe first.
- The exact explicit context shape that replaces `WaterHelperMethods.generate_collisionmap()` and `generate_terrain_contact_feature_map()` RiverManager reach-back.

## Resolved Questions

| Question | Resolution | Date | Notes |
| --- | --- | --- | --- |
| Should R6 freeze all bake-affecting state at bake start? | No, not by default. Preserve mixed timing unless a deliberate change is documented and validated. | 2026-06-13 | This avoids accidental behavior changes during async bakes. |
| Is R6 allowed to bump the bake signature? | No. | 2026-06-13 | R6 is extraction and dictionary centralization only; signature remains 28. |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-13 | Preserve existing mixed source timing by default. | Freezing values at bake start would be a behavior change and needs a targeted mid-bake edit proof. |
| 2026-06-13 | Keep RiverManager as final result applicator. | It owns public node state, resource saving, material binding, signals, and inspector behavior. |
