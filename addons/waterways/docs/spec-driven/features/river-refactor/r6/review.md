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

- Overall review status: R6.5 cleanup/interface tightening is complete after final automated R6 validation. R6.3 runtime ripple owner extraction, R6.4 editor validation extraction, R6.1B baker lifecycle, R6.1C run-pass helper, R6.1D source-image helper implementation, R6.1E pass sequencing, R6.1F diagnostics/image postprocess, R6.1G result application, R6.1H abort-matrix coverage, R6.2 constants-table live dictionary switch, and R6.5 private cleanup are reviewed with focused validation.
- Blocking issues remaining: none from automated R6 validation or R6.5 cleanup. Full-Demo human-assisted editor undo-delete was attempted but infeasible due bake load; visible review should not be overclaimed.
- Important issues remaining: source timing must remain mixed unless deliberately changed; the editor undo-delete variant needs a lower-cost fixture or targeted editor harness if it must be closed later; inert private RiverManager placeholders are required to preserve the full property-list baseline.
- Last validation relied on: 2026-06-14 R6.5 focused validation (`R6_R61F_PARSER_OK`; `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28`; `R6_BASELINE_DUMP_OK out=res://.codex-research/r6-baselines/post-r6-r65 files=10`; `R6_R65_SURFACE_PROPERTY_DIFF_OK files=4 baseline=post-r6-final current=post-r6-r65 surface_line_numbers=normalized`; `R5_BEHAVIOR_PRESERVATION_PROBE_OK`; `R4_RUNTIME_ROBUSTNESS_PROBE_OK`; `git diff --check`). The known `Demo.tscn` invalid UID warning repeated.
- Next action: move to the R7 compute-vs-SubViewport decision/docs gate; do not start R7 implementation until the decision is recorded and R7 `spec.md`, `plan.md`, and `validation.md` exist.
- Historical detail starts at: none.

## Findings

### Blocking

- None from automated R6 validation. The final generated-output, canonical dictionary, public API/signal, full property-list, R5, R4, filter-renderer, system-flow, parser/check-only, and whitespace gates passed.

### Important

- The source timing contract remains the main behavioral risk. The `flow_speeds` trap proves the old mixed timing; any freeze-at-start change needs deliberate spec and validation updates.
- Helper-internal await abort coverage is now automated for terrain-contact node-free and renderer/Jacobi-labelled cancellation. The full-Demo editor undo-delete attempt was infeasible due bake load, so any future editor-stack closure should use a lower-cost fixture.
- `WaterHelperMethods` collision/terrain helper signatures are a reach-back hazard if they continue to accept a broad RiverManager argument.
- The constants table must not hide signature review decisions.
- The full RiverManager property-list dump includes private script variables. R6.3 keeps inert compatibility placeholders for the old runtime ripple state names while the live ownership state moves into `river_ripple_material_owner.gd`; R6.5 also keeps the old `_flowmap_bake_renderer` slot as serialized compatibility while `RiverFlowmapBaker` owns the live renderer.
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
| Generated texture hashes unchanged | Pass final | Fresh current hashes in `post-r6-r62-live-generated` match both the post-R6.1H rerun generated baseline and the fresh old-code generated comparator exactly for both demo scenes. Saved-resource RT.1 logs remain informational because fresh live rebakes differ from older saved resources. |
| Intermediate source-image hashes unchanged | Pass for R6.1A-G rerun with existing caveat | Demo matched the post-R6.1D final source-image dump exactly. The obstacle rerun differed only in the four previously documented collision-derived rows and matched the old-code fresh replay exactly, so this remains collision-probe freshness/variant behavior rather than a moved-helper regression. |
| Source signature and bake settings diffs empty | Pass final | `post-r6-final` source-signature and bake-settings dumps match the original `pre-r6` dumps exactly with no ignored keys. |
| Source metadata diff empty except `bake_revision` | Pass final | `post-r6-final` source-metadata dumps match the original `pre-r6` dumps with only the documented `bake_revision` filter. |
| Constants-table live dictionary switch | Pass for R6.2 live | `r6_constants_shadow_probe.gd` reported `R6_R62_CONSTANTS_SHADOW_OK comparisons=8 rows=109 signature_version=28`; the post-switch canonical dump wrote `post-r6-r62-live` and matched the post-R6.1A-G rerun dictionaries exactly with only the documented metadata `bake_revision` filter. |
| Public API/signal surface unchanged | Pass final | `post-r6-final` public method and signal dumps match the original `pre-r6` surface after normalizing line-number-only location drift. |
| Full inspector property list unchanged | Pass final | Full Demo and obstacle property-list dumps match the original `pre-r6` baseline exactly after preserving inert private compatibility placeholders. |
| R6.5 private cleanup preserved interface | Pass for R6.5 | Removed `_cleanup_flowmap_baker()` and `_filter_output_is_valid()` only after active-reference audit. Public method/signal dumps matched after line-number normalization and full property-list dumps matched byte-for-byte. |
| Runtime ripple behavior unchanged | Pass for R6.3 | `RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK`, `RIPPLE_FIELD_EMITTER_PROBE_OK`, and `RIPPLE_DEBUG_PARITY_PROBE_OK` passed after extracting `river_ripple_material_owner.gd`. |
| Editor validation markers unchanged | Pass for R6.4 | `r6_editor_validation_probe.gd` reports menu validation signals and direct wrapper markers with unchanged `RIVER_DATA_TEXTURE_TEST` and `FILTER_RENDERER_TEST` prefixes. |
| Abort cleanup complete | Pass for R6.1H automated coverage | `R6_R61H_ABORT_MATRIX_OK` covers the automated stage buckets and names editor undo-delete plus forced collision-helper null injection rather than overclaiming automation. The user attempted full-Demo editor undo-delete on 2026-06-14, but the bake load made the editor too laggy to perform the delete; future closure needs a lower-cost fixture or targeted editor harness. |

## Architecture Compliance

- Godot 4.6+ API target preserved: Pass for automated R6 validation; changed scripts pass check-only and final probes run under Godot 4.6.3.
- Editor/runtime boundary preserved: Pass for automated R6 validation; R6.4 helper avoids editor singleton state, public wrappers remain, and runtime guard probes pass. Human-visible editor review remains separate.
- Bake data and generated resources explicit: Pass for automated R6 validation; final generated-output and canonical dictionary/resource-surface gates pass.
- Legacy Godot 3 behavior used only as reference: Yes so far.
- Extension points preserved: Pass for automated R6 validation; baker, constants, runtime ripple owner, and editor validation helpers are present behind existing public RiverManager wrappers.
- Godot-native features preferred where practical: Unproven.
- Bespoke systems justified: Partial; baker/constants/ripple/editor helpers are justified by local architecture.
- Comments explain non-obvious intent without restating obvious code: Pass for R6.5 cleanup; stale renderer-ownership comment now explains property-list compatibility and live baker ownership.
- Feature and architecture docs updated for behavior, data flow, and boundary changes: Pass for R6 docs/parent handoff; deeper dead-method/comment cleanup remains R6.5.

## Validation Results

- Automated: baseline partial pass on 2026-06-13 (`r6_baseline_dump_probe.gd`; `r6_source_image_hash_probe.gd`; `r6_mid_bake_timing_probe.gd`; `bake_hash_probe.gd` for both saved demo river bakes), R6.3 runtime extraction pass, R6.4 editor extraction pass, R6.1B lifecycle pass, R6.1C run-pass helper pass, R6.1D focused/final source-image validation, R6.1E pass sequencing validation, R6.1F diagnostics/image postprocess validation, R6.1G result assembly/application validation, R6.1H abort-matrix validation, post-R6.1H R6.1A-G rerun, R6.2 constants-table live switch (`R6_R62_CONSTANTS_SHADOW_OK`; `R6_R62_LIVE_CANONICAL_DICTIONARY_DIFF_OK`), final full-R6 gates (`R6_FINAL_GENERATED_TEXTURE_DIFF_OK`; `R6_FINAL_RT1_GENERATED_TEXTURE_DIFF_OK`; `R6_FINAL_CANONICAL_SURFACE_DIFF_OK`; `SYSTEM_FLOW_PROJECTED_GATE_OK`), and R6.5 focused cleanup validation (`R6_R65_SURFACE_PROPERTY_DIFF_OK`; R5/R4 guards; `git diff --check`).
- Human-assisted: none for R6.
- Shader: no R6 shader change intended.
- Editor: R6.4 rendered console marker/menu-signal probe passed; full-Demo editor undo-delete was attempted but infeasible due bake load; human-visible menu/viewport review remains separate.
- Visual: unrun.
- Bake output: saved-resource RT.1 hash baselines captured; source-image baselines captured; same-run timing-control texture comparison captured; R6.1E fresh generated old-code/current comparison passed for both demo scenes; R6.1G current output matched both R6.1F current output and fresh old-code output exactly; post-R6.1H R6.1A-G rerun output matched the post-R6.1G generated baseline and fresh old-code output exactly; final `post-r6-r62-live-generated` output still matches both the post-R6.1H rerun and fresh old-code generated comparator exactly.
- Runtime: Final R6 reran R4 runtime robustness, R5 behavior preservation, filter-renderer load, and the rendered system-flow projected gate; R6.1H abort checks are covered by the abort-matrix probe, with the full-Demo editor undo-delete manual variant recorded as infeasible.
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
- [x] Start R6.2 constants-table extraction in shadow mode.
- [x] Switch live metadata/signature/settings generation after reviewing the R6.2 shadow table and rerunning the canonical comparison.
- [x] Run final full-R6 generated-output, canonical dictionary/API/signal/property, R5, R4, filter-renderer, system-flow, parser/check-only, and whitespace gates.
- [x] Continue R6.5 dead-private-method/comment cleanup/interface tightening.

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
| 2026-06-14 | Start R6.2 in shadow mode only. | The constants table now exposes signature-coverage decisions and matches old dictionaries, while leaving live RiverManager dictionary generation untouched until a narrow follow-up switch. |
| 2026-06-14 | Switch only live constant dictionary rows to `RiverBakeConstants`. | The shadow probe and canonical dump comparison preserve exact signature/settings and metadata except `bake_revision`, while dynamic final reads remain explicit in RiverManager and signature version remains 28. |
| 2026-06-14 | Remove only unreferenced private RiverManager helpers in R6.5. | `_cleanup_flowmap_baker()` and `_filter_output_is_valid()` no longer had active call sites after the baker extraction; keeping serialized private variables avoids property-list churn. |
