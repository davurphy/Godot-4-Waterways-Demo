# Review: River Refactor R6 - river_manager.gd Decomposition

## Review Date

2026-06-13

## Scope Reviewed

- R6 documentation scaffold based on `plan.md`.
- Template compliance for feature-folder documents.
- R6.3 runtime ripple material ownership extraction.
- Hardened runtime ripple material/debug parity probe coverage.
- R6.4 editor validation harness extraction and marker/menu probe coverage.
- R6.1B baker shell/filter-renderer lifecycle extraction, R6.1C run-pass helper validation, R6.1D source-image helper move implementation, R6.1E filter pass sequencing extraction, R6.1F diagnostics/image postprocess extraction, R6.1G result assembly/application boundary extraction, and R6.1H abort-matrix coverage.

## Current Truth

- Overall review status: R6.3 runtime ripple owner extraction, R6.4 editor validation extraction, R6.1B baker lifecycle slice, R6.1C run-pass helper slice, R6.1D source-image helper implementation, R6.1E pass sequencing extraction, R6.1F diagnostics/image postprocess extraction, R6.1G result application extraction, and R6.1H abort-matrix coverage reviewed with focused validation. The old R6.1A-G validation/probe set was rerun after R6.1H and did not show a regression; the R6.1D obstacle source-image caveat repeated only as the known collision-derived old-code variant.
- Blocking issues remaining: constants-table extraction and final before/after diffs are not captured.
- Important issues remaining: source timing must remain mixed unless deliberately changed; editor undo-delete still needs human-assisted validation before final R6 closure; inert private RiverManager placeholders are required to preserve the full property-list baseline.
- Last validation relied on: 2026-06-14 R6.1A-G rerun after R6.1H (`R6_BAKER_LIFECYCLE_OK`, `R6_BAKER_RUN_PASS_OK`, `R6_R61F_WARNING_POSTPROCESS_OK`, `R6_R61G_RESULT_APPLICATION_OK`, `R5_BEHAVIOR_PRESERVATION_PROBE_OK`, `R6_R61G_RERUN_GENERATED_TEXTURE_DIFF_OK`, `R6_R61G_RERUN_RT1_GENERATED_TEXTURE_DIFF_OK`, `R6_R61G_RERUN_SURFACE_PROPERTY_DIFF_OK`, and `git diff --check`). The source-image rerun repeated only the known four obstacle collision-derived rows and matched the old-code fresh replay exactly.
- Next action: start R6.2 constants-table work.
- Historical detail starts at: none.

## Findings

### Blocking

- Bake-pipeline decomposition is still partial; the baker lifecycle, run-pass abort helper, source-image helpers, full filter pass sequencing, diagnostics/image postprocess, result application boundary, and abort matrix are in place. R6.2 constants-table work and final full-R6 before/after gates remain open.

### Important

- The source timing contract remains the main behavioral risk. The `flow_speeds` trap proves the old mixed timing; any freeze-at-start change needs deliberate spec and validation updates.
- Helper-internal await abort coverage is now automated for terrain-contact node-free and renderer/Jacobi-labelled cancellation, with editor undo-delete named as a human-assisted editor-stack case.
- `WaterHelperMethods` collision/terrain helper signatures are a reach-back hazard if they continue to accept a broad RiverManager argument.
- The constants table must not hide signature review decisions.
- The full RiverManager property-list dump includes private script variables. R6.3 keeps inert compatibility placeholders for the old runtime ripple state names while the live ownership state moves into `river_ripple_material_owner.gd`; removing those placeholders causes a property-list regression.
- R6.4 keeps public editor validation wrappers in RiverManager while moving the implementation to `river_editor_validation.gd`; the helper context must stay named/read-only except for renderer cleanup.

### Minor

- Decide early whether `BakeConfig`, `BakeResult`, and `BakeAbort` remain dictionaries or become typed `RefCounted` classes.
- Keep exact scratch artifact paths current as validation expands.

## Premise Review

- Was the original premise correct, partially correct, or wrong? Correct. The parent track already identifies `river_manager.gd` decomposition as an R6 goal after R5 structural dedup.
- Did any evidence suggest the user or agent was overlooking scene/data/context? Not yet. The main possible misread is stale baseline data during future validation.
- If yes, was that raised with the user early enough? Not applicable yet.
- Was the final outcome a code/design fix, docs/validation clarification, or expected-behavior explanation? Current outcome is a code/design fix for R6.3 and R6.4 plus docs/validation clarification; bake decomposition remains pending.

## Spec Compliance

| Acceptance Criterion | Status | Notes |
| --- | --- | --- |
| Generated texture hashes unchanged | Pass for R6.1A-G rerun | Fresh current hashes in `post-r6-r61ag-rerun-generated` match the post-R6.1G generated baseline and the fresh old-code generated comparator exactly for both demo scenes. Saved-resource RT.1 logs remain informational because fresh live rebakes differ from older saved resources. |
| Intermediate source-image hashes unchanged | Pass for R6.1A-G rerun with existing caveat | Demo matched the post-R6.1D final source-image dump exactly. The obstacle rerun differed only in the four previously documented collision-derived rows and matched the old-code fresh replay exactly, so this remains collision-probe freshness/variant behavior rather than a moved-helper regression. |
| Source signature and bake settings diffs empty | Partial | Pass for R6.1A-G rerun with exact post-R6.1G/post-rerun canonical dump match; final full-R6 diff still required after later bake moves. |
| Source metadata diff empty except `bake_revision` | Partial | Pass for R6.1A-G rerun with exact post-R6.1G/post-rerun canonical dump match under the existing allow-list; final full-R6 diff still required after later bake moves. |
| Public API/signal surface unchanged | Partial | Pass for R6.1A-G rerun after normalizing public method/signal line numbers; generated-texture logs preserve output parity through result application; final full-R6 diff still required. |
| Full inspector property list unchanged | Partial | Pass for R6.1A-G rerun with exact property-list match against the post-R6.1G baseline after preserving inert private compatibility placeholders. |
| Runtime ripple behavior unchanged | Pass for R6.3 | `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, and `RIPPLE_DEBUG_PARITY_PROBE_OK` passed after extracting `river_ripple_material_owner.gd`. |
| Editor validation markers unchanged | Pass for R6.4 | `r6_editor_validation_probe.gd` reports menu validation signals and direct wrapper markers with unchanged `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` prefixes. |
| Abort cleanup complete | Pass for R6.1H | `R6_R61H_ABORT_MATRIX_OK` covers the automated stage buckets and names editor undo-delete plus forced collision-helper null injection rather than overclaiming automation. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Partial; R6.3 and R6.4 code use current Node/Object/Resource/RefCounted/await APIs, but broader bake code remains pending.
- Editor/runtime boundary preserved: Partial; R6.4 helper avoids editor singleton state, but broader bake/editor closure remains pending until full R6 validation.
- Bake data and generated resources explicit: Partial; validation format records requirements, implementation unreviewed.
- Legacy Godot 3 behavior used only as reference: Yes so far.
- Extension points preserved: Partial; planned modules are named, implementation unreviewed.
- Godot-native features preferred where practical: Unproven.
- Bespoke systems justified: Partial; baker/constants/ripple/editor helpers are justified by local architecture.
- Comments explain non-obvious intent without restating obvious code: Unproven.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Partial; R6 folder drafted, parent docs not updated until validation.

## Validation Results

- Automated: baseline partial pass on 2026-06-13 (`r6_baseline_dump_probe.gd`; `r6_source_image_hash_probe.gd`; `r6_mid_bake_timing_probe.gd`; `bake_hash_probe.gd` for both saved demo river bakes), R6.3 runtime extraction pass, R6.4 editor extraction pass, R6.1B lifecycle pass, R6.1C run-pass helper pass, R6.1D focused/final source-image validation, R6.1E pass sequencing validation, R6.1F diagnostics/image postprocess validation, R6.1G result assembly/application validation, R6.1H abort-matrix validation, and post-R6.1H R6.1A-G rerun (`R6_BAKER_LIFECYCLE_OK`; `R6_BAKER_RUN_PASS_OK`; `R6_R61F_WARNING_POSTPROCESS_OK`; `R6_R61G_RESULT_APPLICATION_OK`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; generated-texture and surface/property rerun diffs passed).
- Human-assisted: none for R6.
- Shader: no R6 shader change intended.
- Editor: R6.4 rendered console marker/menu-signal probe passed; human-visible editor click review remains unrun.
- Visual: unrun.
- Bake output: saved-resource RT.1 hash baselines captured; source-image baselines captured; same-run timing-control texture comparison captured; R6.1E fresh generated old-code/current comparison passed for both demo scenes; R6.1G current output matched both R6.1F current output and fresh old-code output exactly; post-R6.1H R6.1A-G rerun output still matches the post-R6.1G generated baseline and fresh old-code output exactly.
- Runtime: R6.4 reran R4 runtime robustness and R5 behavior preservation; R6.1H abort checks are now covered by the abort-matrix probe, with editor undo-delete still human-assisted.
- Performance: unrun; R6 is not performance-gated except to avoid new avoidable waits/readbacks.
- Manual: documentation scaffold reviewed against `plan.md`; R6 docs were tracked/clean before validation-tool edits; R6.3 and R6.4 extractions reviewed against their plan sections.

## Documentation Consistency Check

- [ ] Closed tasks are checked off in `tasks.md`.
- [ ] No stale "open follow-up" language remains for completed work.
- [ ] Resolved open questions moved to `spec.md` resolved questions or decision log.
- [ ] `plan.md` reflects actual architecture and lifecycle behavior.
- [ ] `validation.md` current snapshot and matrix match detailed recorded results.
- [ ] Latest handoff points to the true next action.
- [ ] Shared works-cited index checked or updated if external sources influence R6.

## Follow-Up Tasks

- [x] Review and check in the R6 documentation gate.
- [x] Implement canonical dictionary dump probe.
- [x] Capture pre-R6 canonical dictionary/API/property/saved-RT.1 baselines before code moves.
- [x] Capture source-image hashes and mid-bake timing/progress evidence before bake-pipeline code moves.
- [x] Complete awaited operation and dependency inventory.
- [x] Decide whether R6.3/R6.4 land before the bake pipeline extraction. Decision: landed R6.3 and R6.4 first.
- [x] Extract runtime ripple material ownership and validate R6.3.
- [x] Run the R6.4 editor validation caller/data-dependency audit and extract the helper behind unchanged RiverManager wrappers.
- [x] Add the R6.1B baker shell/lifecycle ownership and validate focused cleanup.
- [x] Add the R6.1C run-pass helper and validate null/readback abort text plus cleanup.
- [x] Reconcile R6.1D full source-image gate caveat before R6.1E. The final current dump matches the original pre-R6 full source-image baseline for both scenes; the alternate obstacle rows are recorded as collision-probe freshness/variant evidence.
- [x] Start R6.1E pass sequencing and run the required RT.1 gate before continuing.
- [x] Start R6.1F diagnostics/image postprocess extraction.
- [x] Start R6.1G result assembly/application boundary extraction.
- [x] Start R6.1H abort-matrix coverage.
- [x] Rerun the old R6.1A-G validation/probe set after R6.1H before starting R6.2.
- [ ] Start R6.2 constants-table extraction.

## Decision Updates

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-06-13 | R6 docs define preservation of mixed source timing as the default. | This is the safest behavior-preserving stance before implementation. |
| 2026-06-13 | Land R6.3 runtime ripple material ownership before bake-pipeline extraction. | It is a smaller review slice with focused probe coverage and no bake algorithm movement. |
| 2026-06-13 | Keep inert private RiverManager placeholders for old runtime ripple state names after extraction. | The full inspector property-list dump includes private script variables; removing them would fail the R6 surface-preservation gate even though live state moved to the owner helper. |
| 2026-06-14 | Land R6.4 editor validation before bake-pipeline extraction. | It is a small slice with focused caller/marker coverage and keeps public wrappers/menu marker behavior stable before the bake move. |
| 2026-06-14 | Keep R6.1C as a focused helper/probe slice. | Null/readback abort text and cleanup can be proven before source-image movement or full pass sequencing moves. |
| 2026-06-14 | Temporarily block R6.1E after R6.1D until source-image baseline caveat is reconciled. | Moved helper rows matched, but the full obstacle pre/post source-image dump differed in collision-derived rows outside the moved helper set. Resolved by the next decision. |
| 2026-06-14 | Treat the R6.1D obstacle collision mismatch as collision-probe freshness/variant evidence, not source-helper drift. | A scratch `origin/r6` replay produced the alternate four collision-derived rows with old helpers, and the final current R6.1D dump matches the original pre-R6 full source-image baseline. |
| 2026-06-14 | Use fresh old-code generated hashes, not older saved-resource hashes, as the R6.1E RT.1 comparator. | The saved-resource logs remain useful but fresh live rebakes were already known to differ from those resources; the scratch `origin/r6` generated run gives an apples-to-apples pass-sequencing comparison. |
| 2026-06-14 | Keep R6.1F as an image-only diagnostics/postprocess slice with warning/diagnostic callbacks. | This preserves RiverManager's result application boundary before the R6.1G move while proving warning text and generated-output parity. |
| 2026-06-14 | Keep R6.1G result application synchronous and RiverManager-owned. | This preserves the old no-await success tail while making the `BakeResult` handoff explicit and leaving save/material/valid-flowmap semantics on the public node. |
| 2026-06-14 | Keep R6.1H result application and image postprocess as synchronous strategies, and name editor undo-delete/forced collision-helper null injection instead of overclaiming automation. | The abort probe covers the automated lifecycle buckets; editor undo uses the editor stack, and collision helper null injection needs a future narrow seam to avoid broadening this slice. |
| 2026-06-14 | Rerun R6.1A-G after R6.1H before starting R6.2. | The rerun confirmed the old lifecycle, run-pass, generated-output, warning/postprocess, result-boundary, surface/property, and R5 gates still pass after abort-matrix work. The only source-image diff was the known obstacle collision-derived variant and matched old code. |
