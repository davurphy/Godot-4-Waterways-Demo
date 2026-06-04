# Validation: River Pillows

## What Must Be Proven

- Raw pillow placement starts at upstream impact/compression faces of rocks and hard protrusions.
- No-reach final `Pillow Visual Mask` does not move the pillow start forward ahead of raw R.
- Visible material response does not make accepted masks look detached from the object.
- Ordinary banks, open water far ahead of rocks, downstream wakes, and eddy-line margins are not misclassified as pillows.
- The same conclusion holds in both main demo and obstacle-test layouts.
- Accepted Phase 5 flow and Phase 7B eddy-line behavior remain intact after any shared change.

## Current Validation Snapshot

This is the validation dashboard. The matrix answers what is currently proven; recorded results and archives explain how those conclusions were reached.

- Overall status: Partial
- Last automated pass: Historical Godot 4.6.3 probes passed after Phase 6E, including `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`, `PHASE6B_PILLOW_TUNING_PROBE_OK`, `PHASE6A_PILLOW_VISUAL_PROBE_OK`, `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`, `DEBUG_VIEW_MENU_WIRING_PROBE_OK`, and `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`. On 2026-06-04, consolidated feature-local pillow probes passed in Godot 4.6.3: `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`, `PILLOW_ANCHOR_SOURCE_PROBE_OK`, `PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PILLOW_INSPECTOR_WIRING_PROBE_OK`, and a quick `PILLOW_VISUAL_REVIEW_EXPORT_OK`; metadata verification confirmed both review river bakes are signature `20`.
- Last human-assisted pass: User confirms raw `Pillow / Impact Mask` and final visible water start about `0.3` to `0.5` ahead of the desired obstruction contact point after Phase 6E. User also reports `Pillow Visual Mask` is undifferentiated green over the whole river.
- Highest-risk unproven behavior: Whether signature-`20` direct-contact-first raw R places pillows correctly in live review now that both review river bakes are verified signature `20`.
- Known unreliable local check or environment caveat: Local scripted probes are useful, but not proof of visible editor/runtime placement. The original debug gradient maps zero to green. Mode `58`, `Pillow Visual Mask (Black Zero)`, is the pure palette clone of mode `26`; mode `48`, `Pillow No-Reach Mask (Black Zero)`, is the no-reach final-mask diagnostic.

## Validation Matrix

| Requirement or risk | Check/probe/scene | Environment | Expected marker/result | Last result | Date | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| Pillow forward reach disabled by default | Inspect visible/debug shader defaults and editor controls | Godot editor/human visible | `pillow_forward_reach_tiles = 0.0` unless intentionally changed | Historical pass | 2026-05-26 | Agent/User |
| Raw pillow placement on signature-20 bakes | `probes/pillow_placement_diagnostic.gd` plus human review | Godot scripted readback plus human review | Raw R above `0.05` near rocks, not broad far-ahead blobs | Partial; automated signature-20 stats passed and reported raw R about `2.655%` main and `2.7588%` obstacle-test; no-reach visual about `1.7059%` main and `1.7319%` obstacle-test. Human-visible placement review remains required. | 2026-06-04 | Agent/User |
| Formula source term for remaining offset | Existing views or new diagnostic split | Human visible plus optional probe | Offset source identified as raw support, direct contact, bank response, final gate, or material | User review identified bank-response/combined contact gate as too broad and direct terrain anchor as closest to intended placement | 2026-06-01 | User/Agent |
| Bank-response anchor risk | `probes/pillow_anchor_source_probe.gd` | Godot scripted audit | `PILLOW_ANCHOR_SOURCE_PROBE_OK`; direct-contact metadata present and anchor contributions reported for both bakes | Pass as diagnostic; current report still shows bank-response context is present around some raw pixels, so live target review remains required | 2026-06-04 | Agent |
| Audit diagnostic split | New debug views or probe output | Human visible plus optional probe | Direct contact, bank-response anchor, support/facing, combined contact gate, and bank-only contribution are separable | Partial; saved-term debug views added for direct anchor, bank anchor, combined gate, bank-only contribution, and retention. Support/facing still needs probe/bake diagnostic. | 2026-06-01 | Agent/User |
| `Pillow Visual Mask` readability | Current mode or new threshold/black-zero diagnostic | Human visible plus optional shader/static check | Reviewer can distinguish zero/near-zero, weak, and meaningful final-mask values | Partial; mode `58` is true `Pillow Visual Mask (Black Zero)` and mode `48` is `Pillow No-Reach Mask (Black Zero)`. Godot menu/parity probes passed; human-visible review still needed. | 2026-06-04 | User/Agent |
| Main and obstacle-test generalization | `Demo.tscn` and `Demo_obstacle_flow_test.tscn` review | Human visible | Same placement conclusion without ordinary-bank strips | Partial; both scenes now save baseline pillow placement values and both river bakes are verified signature `20`; human-visible placement review remains unrun | 2026-06-04 | Agent |
| Raw/final metric support when needed | Named-region or probe report | Scripted readback plus user-marked targets | Expected coverage, retention, false positives, and top suppressors reported | Unrun | 2026-05-31 | Agent/User |
| Debug/material wiring | `probes/pillow_inspector_wiring_probe.gd` | Godot 4.6.3 scripted probe | `PILLOW_INSPECTOR_WIRING_PROBE_OK` | Pass; verifies inspector groups, shader uniforms, scene baselines, visible/debug material sync, and revert defaults | 2026-06-04 | Agent |
| Pillow shader visual wiring | `.codex-research/phase6a_pillow_visual_probe.gd` | Godot 4.6.3 scripted probe | `PHASE6A_PILLOW_VISUAL_PROBE_OK` | Pass historically | 2026-05-26 | Agent |
| Pillow tuning controls | `.codex-research/phase6b_pillow_tuning_probe.gd` | Godot 4.6.3 scripted probe | `PHASE6B_PILLOW_TUNING_PROBE_OK` | Pass historically | 2026-05-26 | Agent |
| Accepted eddy-line behavior preserved | Phase 7B visual and CPU probes | Godot 4.6.3 scripted probe plus user review | `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`, accepted visual pattern remains | Pass historically | 2026-05-26 | Agent/User |
| WaterSystem unchanged for pillow-only work | Inspect scope and generated resources | Static/resource review | No saved WaterSystem bake regeneration unless final flow scoped | Partial/needs decision; `WaterSystem.water_system_bake.res` changed during the user's 2026-06-04 main-demo rebake and is not yet reviewed as accepted final-flow/physics work | 2026-06-04 | User/Agent |
| Signature-20 pillow rebake | `Demo.tscn` and `Demo_obstacle_flow_test.tscn` | Godot console plus resource inspection | Main and obstacle-test river bakes regenerated with source signature `20`; WaterSystem change explicitly reviewed or reverted | Pass for river bakes; Godot metadata verifies both `Water_River.river_bake.res` and `Water_River_obstacle_test.river_bake.res` are signature `20`. WaterSystem remains a separate pending decision. | 2026-06-04 | User/Agent |
| Debug diagnostic parity | `probes/pillow_diagnostic_parity_check.gd` plus debug-menu probe | Local static plus optional Godot script | Mode `48` semantics are explicit; bake diagnostic constants match `river_manager.gd`/filter shader or are passed as uniforms | Pass; `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK` and `DEBUG_VIEW_MENU_WIRING_PROBE_OK` | 2026-06-04 | Agent |
| Visual review export smoke test | `probes/pillow_visual_review_export.gd` | Godot 4.6.3 scripted export | Quick export or full export completes with `PILLOW_VISUAL_REVIEW_EXPORT_OK` | Pass in quick mode; exported main demo `visible_water`, raw R, normal visual mask, and Black Zero visual mask captures to `.codex-research/river-pillows-visual-review/` | 2026-06-04 | Agent |

## Premise and Interpretation Checks

- Expected behavior that could look like a bug:
  - Some stylized compression may begin before literal mesh contact.
  - Debug gradients can make low values look more meaningful than they are.
  - Viewing downstream/upstream from a fixed camera can invert interpretation.
- Scene geometry, stale resources, generated data, or editor/runtime state to rule out:
  - Saved debug material override.
  - Old `pillow_forward_reach_tiles = 0.075` material override.
  - Default-off contact-pull or height experiment accidentally enabled.
  - Stale `Demo.tscn` saved non-baseline pillow values. Reset on 2026-06-04; verify if the scene changes again.
  - Resolved on 2026-06-04: main and obstacle-test river bakes are now on matching source-signature `20`.
  - Height curve controls missing explicit range hints or using stale material revert defaults.
  - Stale signature pre-`19` river bakes.
- Research/source context to check:
  - `addons/waterways/docs/research/river-research-citations.md` is the shared works-cited index for river behavior, hydrology, flow maps, shader water, and production examples. Future Codex sessions should consult it when validating whether a visible pillow behavior matches real river-reading references, and update it when new sources are used.
- Evidence that would mean the user or agent is misreading the situation:
  - Raw R and no-reach `Pillow Visual Mask` align well with rocks, but visible highlight/foam reads detached.
  - The reported offset is actually downstream wake/eddy-line behavior.
  - `Pillow Visual Mask` appears broadly green only because zero/near-zero values are mapped to green by the current debug palette.
- What the agent should say to the user if that evidence appears:
  - "The raw and no-reach masks look placed correctly here, so this is probably material response or camera interpretation rather than another bake placement issue."
- Quick falsifying check before patching:
  - Compare `Pillow / Impact Mask` and `Pillow Visual Mask` at the same target with reach/contact-pull off.
  - If raw and final masks are placed correctly but visible response looks wrong, stop treating it as a classifier issue.

## Automated Checks

- Command or procedure:
  - Run the relevant feature-local Godot probe from `addons/waterways/docs/spec-driven/features/river-pillows/probes/`.
  - See `addons/waterways/docs/spec-driven/features/river-pillows/probes/README.md` for launch commands and probe purposes.
- Expected result:
  - Probe-specific `_OK` marker.
- Agent limitation note:
  - Local checks may include static scans, parser checks, or headless editor-load probes when they work.
  - Do not treat local headless/editor-load checks as proof of visible editor interaction, shader visuals, bake output, or runtime behavior.

## Human-Assisted Validation

Use this by default for visible Godot editor checks, viewport interaction, scene running, shader visuals, bake output, and runtime behavior.

- Request to user:
  - Please open the demo in Godot and review one small set of rock/protrusion targets in the listed debug views before we change code again.
- Exact scene, command, or workflow to run:
  - Before visual placement review, confirm `res://Demo.tscn` still uses baseline pillow placement values.
  - Confirm `res://Demo.tscn` uses the verified direct-contact-first/signature-`20` main river bake.
  - Confirm `res://Demo_obstacle_flow_test.tscn` uses the verified direct-contact-first/signature-`20` obstacle-test river bake before cross-scene placement review.
  - Decide whether the modified `waterways_bakes/Demo/WaterSystem.water_system_bake.res` from the user's 2026-06-04 rebake should be kept, reviewed, or reverted before finalizing the work. Do not further regenerate the WaterSystem bake unless final/physics flow is scoped.
  - Open `res://Demo.tscn`.
  - Enable the Waterways plugin if it is not already enabled.
  - Select the main river.
  - Keep `pillow_forward_reach_tiles = 0.0`.
  - Leave `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` at their default-off values.
  - Leave `pillow_terrain_height` and `pillow_obstruction_height` at `0.0` for placement review unless explicitly testing material/height response after raw placement is accepted.
  - For the same rocks/protrusions that still look wrong, switch between:
    - `Pillow / Impact Mask`
    - `Pillow Visual Mask`
    - `Pillow Visual Mask (Black Zero)` / mode `58`
    - `Pillow No-Reach Mask (Black Zero)` / mode `48`
    - `Pillow Direct Terrain Anchor Search`
    - `Pillow Bank-Response Anchor Search`
    - `Pillow Combined Contact Gate`
    - `Pillow Bank-Only Anchor Contribution`
    - `Pillow Raw-to-Final Retention`
    - `Pillow Height Influence`
    - `Terrain Pillow Height Influence`
    - `Obstruction Pillow Height Influence`
    - `Obstacle Confidence`
    - `Hard-Boundary / Protrusion Response`
    - `Grade / Energy Channel`
    - `Protrusion / Intersection`
    - `Final Flow Strength`
  - Repeat at least one target in `res://Demo_obstacle_flow_test.tscn`.
- Plugin state required:
  - Waterways plugin enabled.
- Console output or errors to relay back:
  - Any Output panel errors, shader compile errors, script errors, or stale bake warnings.
- Screenshot or visible behavior to relay back:
  - For each target, say whether the forward offset first appears in raw `Pillow / Impact Mask`, no-reach `Pillow Visual Mask`, or only final visible water.
  - If `Pillow Visual Mask` still appears uniformly green, record it as unreadable and use the clearer diagnostic before judging final-mask placement.
  - Identify each target as should-detect, should-not-detect, false positive, false negative, or accepted.
  - Include screenshots if possible with upstream/downstream direction noted.
- Godot version and renderer to relay back:
  - Godot version, renderer backend, and device/GPU if available.
- Expected result:
  - Raw and no-reach final pillow response should begin at upstream impact/compression faces, not far ahead in open water.
  - `Pillow Visual Mask` or its replacement diagnostic should be readable enough to distinguish no signal from weak/strong mask values.
- Failure signs:
  - Raw R appears as broad halos ahead of rocks.
  - `bank_response.a` or support/facing is active where direct protrusion/contact is not.
  - Ordinary banks form continuous pillow lines.
  - Default-off reach/contact-pull/height controls are influencing the result unexpectedly.
- Result recording format:
  - Date:
  - Ran by:
  - Godot version/renderer/device:
  - Scene:
  - Debug views checked:
  - Target rocks/protrusions:
  - Output or parser errors:
  - Visible result:
  - Pass/partial/fail:

## Recorded Results

Recorded result:

- Date: 2026-06-04
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Ran the consolidated feature-local probe suite under `addons/waterways/docs/spec-driven/features/river-pillows/probes/`: diagnostic parity, anchor source, placement diagnostic, inspector wiring, and quick visual review export.
- Output or parser errors: Initial inspector probe parse issue from GDScript type inference was fixed; rerun passed. Quick visual export printed `Regen multimesh` messages and saved four main-demo PNGs successfully.
- Visible result, if applicable: Quick visual export only; full visual placement review remains unrun. Output went to `.codex-research/river-pillows-visual-review/`.
- Stable result marker: `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`, `PILLOW_ANCHOR_SOURCE_PROBE_OK`, `PILLOW_PLACEMENT_DIAGNOSTIC_OK`, `PILLOW_INSPECTOR_WIRING_PROBE_OK`, `PILLOW_VISUAL_REVIEW_EXPORT_OK`
- Pass/partial/fail: Pass for automated consolidated probes; partial for feature acceptance because human-visible placement review is still required.
- Notes or follow-up: Signature-`20` placement stats from `pillow_placement_diagnostic.gd`: raw R above `0.05` is about `2.655%` main and `2.7588%` obstacle-test; no-reach visual above `0.05` is about `1.7059%` main and `1.7319%` obstacle-test. `pillow_anchor_source_probe.gd` still reports meaningful bank-response context around some raw pixels, so compare specific live targets before deciding whether support/facing needs another probe or classifier change.

Recorded result:

- Date: 2026-06-04
- Ran by: Agent after user main-demo rebake
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Ran `res://.codex-research/print_bake_source_metadata.gd` and reran `res://.codex-research/phase7b_eddy_line_cpu_diagnostic.gd` with isolated Godot console launch patterns.
- Output or parser errors: No parser errors. Main `res://waterways_bakes/Demo/Water_River.river_bake.res` reported `signature_version=20`, `algorithm=bank_context_gated_local_sdf_steering`, `sdf_radius_tiles=0.45`, `upstream_lookahead_tiles=0.08`, and `upstream_strength=0.3`. After the obstacle-test rebake, `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res` also reported `signature_version=20` with the same obstacle-avoidance metadata values. CPU/readback diagnostic rerun passed.
- Visible result, if applicable: Not applicable; this was metadata verification only.
- Stable result marker: `PILLOW_REVIEW_BAKES_SIGNATURE_20_CONFIRMED`, `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`
- Pass/partial/fail: Pass for river bake reconciliation and CPU/readback diagnostic; visible pillow placement review remains unrun.
- Notes or follow-up: The user's rebake also modified `waterways_bakes/Demo/WaterSystem.water_system_bake.res`. Decide how to handle the WaterSystem change before commit; do not treat it as accepted physics/final-flow work yet.

Recorded result:

- Date: 2026-06-04
- Ran by: Agent
- Godot version/renderer/device: Godot 4.6.3 stable, Vulkan Forward+, AMD Radeon RX 6800 XT
- Command, scene, or workflow: Ran the requested CPU/readback diagnostic with the provided isolated user-data launch pattern, then ran debug-menu and pillow diagnostic parity probes with the Godot console executable.
- Output or parser errors: None.
- Visible result, if applicable: Not applicable.
- Stable result marker: `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`, `DEBUG_VIEW_MENU_WIRING_PROBE_OK`, `PILLOW_DIAGNOSTIC_PARITY_CHECK_OK`
- Pass/partial/fail: Pass for automated probes; visible pillow placement review remains unrun.
- Notes or follow-up: `Demo.tscn` is reset to baseline, diagnostic mode semantics/parity are covered, and both review river bakes are signature `20`. Proceed to live pillow placement review before more code changes.

Recorded result:

- Date: 2026-06-04
- Ran by: Agent engineering audit
- Godot version/renderer/device: Not run
- Command, scene, or workflow: Static scans of pillow code/docs/scenes plus binary resource string checks for bake metadata.
- Output or parser errors: No Godot compile, bake, or viewport validation was run.
- Visible result, if applicable: Not applicable.
- Stable result marker: `PILLOW_ENGINEERING_AUDIT_DOCS_UPDATED`
- Pass/partial/fail: Partial
- Notes or follow-up: At audit time, placement review was blocked by `Demo.tscn` non-baseline pillow overrides, mixed/uncertain bake generations, mode-48 semantics, duplicated debug constants, and missing support/facing evidence. Follow-up work resolved the scene-state, bake-generation, debug-mode, and parity items; support/facing evidence is only needed if signature-`20` raw R remains early.

Recorded result:

- Date: 2026-06-01
- Ran by: User live Godot review relayed in chat
- Godot version/renderer/device: Not recorded
- Command, scene, or workflow: Compared `Pillow / Impact Mask`, `Pillow Visual Mask (Black Zero)`, direct terrain anchor search, bank-response anchor search, combined contact gate, bank-only anchor contribution, raw-to-final retention, hard-boundary response, protrusion/intersection, and final flow strength.
- Output or parser errors: Not recorded
- Visible result, if applicable: Raw R lines up with the early pillow. Black Zero final mask is more conservative but still too far ahead. Direct terrain anchor search is much closer to intended placement; fronts read yellow while downstream backsides are weaker blue. Bank-response anchor search, combined contact gate, bank-only contribution, and raw-to-final retention are broad and too far ahead. Final flow strength is green around fronts/sides and appears acceptable as flow behavior.
- Stable result marker: `USER_CONFIRMED_BANK_RESPONSE_CONTACT_GATE_TOO_BROAD`
- Pass/partial/fail: Partial
- Notes or follow-up: Raw classifier contact should become direct-contact-first; bank-response may be weak context but must not anchor pillows alone.

Recorded result:

- Date: 2026-06-01
- Ran by: Agent scoped classifier edit
- Godot version/renderer/device: Not run; Godot executable was not available on the command path.
- Command, scene, or workflow: Changed `obstacle_feature_mask_filter.gdshader` so pillow contact gating uses direct `terrain_contact_features.b` search as the mandatory anchor and treats `bank_response_features.a` only as weak context. Bumped river bake source signature to `20` and recorded anchor metadata in `river_manager.gd`.
- Output or parser errors: Static checks passed with `PILLOW_DIRECT_CONTACT_CLASSIFIER_STATIC_OK` and `PILLOW_DIAGNOSTIC_MENU_STATIC_OK`. No Godot bake or viewport validation was run.
- Visible result, if applicable: Not applicable.
- Stable result marker: `PILLOW_DIRECT_CONTACT_CLASSIFIER_STATIC_OK`
- Pass/partial/fail: Partial
- Notes or follow-up: Resolved on 2026-06-04; main and obstacle-test river bakes now match direct-contact-first/source-signature `20`. Judge raw `Pillow / Impact Mask` using the matching bakes.

Recorded result:

- Date: 2026-06-01
- Ran by: Agent static preflight
- Godot version/renderer/device: Not run; Godot executable was not available on the command path.
- Command, scene, or workflow: Added debug modes `48` through `53`, exposed them in the Debug View menu, scanned for duplicate static menu IDs, checked shader constants/branches, and normalized `Demo_obstacle_flow_test.tscn` pillow review material values.
- Output or parser errors: Static checks passed; `git diff --check` reported only line-ending warnings. No Godot shader compile or viewport validation was run.
- Visible result, if applicable: Not applicable.
- Stable result marker: `PILLOW_DIAGNOSTIC_MENU_STATIC_OK`
- Pass/partial/fail: Partial
- Notes or follow-up: Run human-visible Godot review using the new Black Zero and source-split views. Support/facing source remains unavailable in saved bake textures and needs a target-bound probe before classifier changes.

Recorded result:

- Date: 2026-05-31
- Ran by: User live Godot review relayed in chat
- Godot version/renderer/device: Not recorded
- Command, scene, or workflow: Compared `Pillow / Impact Mask`, `Pillow Visual Mask`, and final visible water in Godot.
- Output or parser errors: Not recorded
- Visible result, if applicable: `Pillow / Impact Mask` and final visible water start about `0.3` to `0.5` ahead of the desired obstruction contact point. `Pillow Visual Mask` reads as undifferentiated green over the river. Final visible water is acceptable-ish stylistically but anatomically early compared with real pillow behavior.
- Stable result marker: `USER_CONFIRMED_RAW_AND_VISIBLE_PILLOW_START_TOO_FAR_AHEAD`
- Pass/partial/fail: Fail/Partial
- Notes or follow-up: Treat raw placement as the primary issue, use the added Black Zero final-mask diagnostic, and finish source-term diagnostics before classifier edits.

Recorded result:

- Date: 2026-05-31
- Ran by: Agent documentation review
- Godot version/renderer/device: Not run
- Command, scene, or workflow: Converted latest changelog and handoff into feature validation plan.
- Output or parser errors: None
- Visible result, if applicable: Not applicable
- Stable result marker: Feature docs created
- Pass/partial/fail: Partial
- Notes or follow-up: Human-assisted pillow formula review is still required.

## Historical Results Archive

- Phase 6A visual probe passed historically with `PHASE6A_PILLOW_VISUAL_PROBE_OK`.
- Phase 6B tuning probe passed historically with `PHASE6B_PILLOW_TUNING_PROBE_OK`.
- Phase 6B height experiment captures used review-only strengths `0.16`, curves `1.20`, and `pillow_height_tile_seam_fade = 0.035`; saved/default behavior stayed off.
- Phase 6C placement diagnostic passed historically with `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`.
- Phase 6C editor wiring probe passed historically with `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`.
- Phase 6D/6E classifier passes rebaked main and obstacle-test river resources to signatures `18` then `19`.
- Historical coverage anchors: Phase 6A main raw R about `8.08%` above `0.05`, Phase 6A gated visual about `3.17%`, Phase 6B gated visual about `3.88%`, Phase 6D raw R about `5.12%` main and `5.06%` obstacle-test, Phase 6E raw R about `4.70%` main and `4.61%` obstacle-test, and Phase 6E no-reach visual about `2.32%` main and `2.26%` obstacle-test.
- Phase 6E also passed historical `PHASE7A2_OBSTACLE_FEATURES_PROBE_OK`, `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`, and `DEBUG_VIEW_MENU_WIRING_PROBE_OK`.
- Phase 7B visual/CPU probes passed historically and should be preserved after shared changes.
- `pillow-system-audit.md` reports `PILLOW_FORMULA_ANCHOR_AUDIT_OK` and found about `35%` of raw pillow pixels above `0.05` were strongly `bank_response.a` anchored while direct terrain protrusion was weak or absent.

## Shader Checks

- Shader/material path:
  - `addons/waterways/shaders/river.gdshader`
  - `addons/waterways/shaders/river_debug.gdshader`
- Renderer backend:
  - Record from Godot editor during human-assisted validation.
- Expected result:
  - Visible and debug shader paths agree on pillow mask placement.
- Failure signs:
  - Debug view differs from visible material in unexplained ways.
  - Material edits do not affect visible water after returning to Debug View Normal.

## Editor Workflow Check

Procedure:

1. Open `res://Demo.tscn`.
2. Select the main river.
3. Confirm the Debug View menu exposes pillow views and related source/context views.
4. Confirm `pillow_` controls are editable and default-off controls stay off unless intentionally changed.
5. Confirm `pillow_terrain_height_curve` and `pillow_obstruction_height_curve` still use explicit range hints and are not treated as generic easing controls.
6. Confirm visible material settings sync into the debug material and revert hooks restore current defaults.
7. Confirm `Pillow Visual Mask`, `Pillow Height Influence`, `Terrain Pillow Height Influence`, and `Obstruction Pillow Height Influence` still map to debug modes `26`, `27`, `28`, and `29`.

Expected result:

- The user can move between raw, final, context, and height influence views without stale material override behavior.
- Height curve controls, seam fade, and default-off height strengths behave as review tools, not hidden placement changes.

Failure signs:

- Debug shader remains applied when Debug View is Normal.
- Controls appear to do nothing because material state is stale.
- Debug modes are missing, mislabeled, or not wired to shader branches.

## Visual Test Scene

Scene path:

- `res://Demo.tscn`
- `res://Demo_obstacle_flow_test.tscn`

Purpose:

- Prove pillow placement on the main demo river and a second obstacle-test layout.

Expected visual result:

- Pillows appear on upstream impact/compression faces of rocks and hard protrusions.
- Open water ahead of rocks stays quiet.
- Downstream wake/eddy lines remain visually distinct from pillow behavior.

Failure signs:

- Broad ahead-of-rock blobs.
- Raw `Pillow / Impact Mask` begins about `0.3` to `0.5` ahead of the intended obstruction contact point.
- Original `Pillow Visual Mask` reads as undifferentiated green; use `Pillow Visual Mask (Black Zero)` for final-mask review.
- Continuous ordinary-bank lines.
- Pillow starts governed by semantic bank-response halo rather than direct obstacle context.
- Debug and visible material disagree on placement.

Suggested controls or debug views:

- `Pillow / Impact Mask`
- `Pillow Visual Mask`
- `Pillow Visual Mask (Black Zero)`
- `Pillow Direct Terrain Anchor Search`
- `Pillow Bank-Response Anchor Search`
- `Pillow Combined Contact Gate`
- `Pillow Bank-Only Anchor Contribution`
- `Pillow Raw-to-Final Retention`
- `Obstacle Confidence`
- `Hard-Boundary / Protrusion Response`
- `Protrusion / Intersection`
- `Final Flow Strength`
- `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` only after raw/no-reach placement is understood.
- Audit-recommended diagnostic split:
  - Pillow support/facing source.
  - Direct terrain protrusion anchor.
  - Bank-response anchor.
  - Combined pillow contact gate.
  - Bank-only anchor contribution.

Required current layout checks:

- Main demo river.
- Obstacle-test river.
- Overview overhead view.
- Rock garden overhead view.
- Main bend low-oblique view.
- Downstream rocks low-oblique view.

Useful future layout checks:

- Single isolated boulder in a straight channel.
- Hard wall protrusion with no detached rock.
- Ordinary smooth bank with no obstruction.
- Shallow low-energy stream segment.
- Steeper chute or high-energy obstacle segment.
- Wide river with a small relative obstacle.
- Narrow channel where banks and rocks are close together.

## Bake Output Check

Scenario:

- Main and obstacle-test rivers after any classifier edit.

Expected generated outputs:

- Flow: unchanged unless explicitly scoped.
- Foam: unchanged unless explicitly scoped.
- Distance/pressure: unchanged unless explicitly scoped.
- Height/alpha: unchanged unless explicitly scoped.
- Obstacle features: raw R updated only for a scoped pillow classifier pass.
- Metadata: source signature and constants updated when saved bake output semantics change.
- Diagnostics: effective anchor-chain reach documented after formula changes, including explicit contact search, `1.5x` sampling, bank-response contribution if any, and support/probe radius.

Failure signs:

- Source signature not bumped after classifier output changes.
- Wake/eddy channels change unintentionally.
- WaterSystem bake regenerated for visual-only pillow work.
- Raw R can still be anchored by `bank_response.a` alone where direct `terrain_contact.b` is weak or absent.

## Runtime API Check

Procedure:

- Not currently scoped.

Expected result:

- Runtime/system flow remains unchanged for pillow-only visual or classifier work unless explicitly planned.

Failure signs:

- WaterSystem flow map or physics behavior changes during a pillow-only placement pass.

## Performance Check

Scenario:

- Any new diagnostic shader sampling or bake classifier pass.

Budget or target:

- No new runtime readback in normal rendering.
- Debug-only diagnostic cost is acceptable for review, but should not become permanent visual cost without justification.

How to measure:

- Use Godot profiler or simple bake/probe timing if performance-sensitive code changes.

## Raw Reading Check

Use this only when visual review needs numeric support.

Suggested output:

- Feature name.
- Scene and target name.
- Raw mask coverage in expected regions.
- Final mask coverage in expected regions.
- Raw-to-final retention.
- False-positive coverage in ordinary-bank or should-not-detect regions.
- Hard-protrusion support percentage.
- Grade/energy support percentage.
- Final-flow support percentage.
- Top gating reason for missing pixels when possible.
- Screenshots or captures as supporting evidence only.

Failure signs:

- Metrics are reported without the user-confirmed target meaning.
- A high numeric score is treated as acceptance despite bad viewport anatomy.
- The report cannot distinguish raw placement failure from gate/material failure.

## Artifact Hygiene Check

- Scratch project or temporary folder used: None for this docs conversion.
- Active scripts/resources mirrored into scratch before validation: Not applicable.
- Generated bakes/resources created: None for this docs conversion.
- Files or folders that must be excluded from packaging:
  - `.codex-research/`
  - Generated review captures unless intentionally committed.
- Files or folders safe to delete now:
  - None identified by this docs conversion.

## Extension Check

Custom content scenario:

- A different river layout with different rocks/protrusions should use the same pillow formula.

Expected result:

- Pillow starts follow upstream impact/compression faces without demo-specific offsets.

Failure signs:

- Constants only fix one rock in `Demo.tscn`.
- Smooth banks or downstream wake margins become pillows in other layouts.

## Manual Review Checklist

- [ ] Acceptance criteria are satisfied.
- [ ] Likely false premises or expected-behavior explanations were raised with the user before extra implementation work.
- [ ] Human-assisted Godot/editor/test results are recorded when the agent could not run them directly.
- [ ] Active code uses Godot 4.6+ APIs and avoids obsolete Godot 3 APIs.
- [ ] Editor-only and runtime-safe boundaries are preserved.
- [ ] Generated resources and metadata are explicit and inspectable.
- [ ] Visual output matches the spec.
- [ ] The raw mask, final mask, and visible material response were reviewed in that order.
- [ ] At least main demo and obstacle-test layouts were checked before accepting detector changes.
- [ ] Flow direction, seams, masks, and bounds are checked visually.
- [ ] Runtime sampling/API behavior remains unchanged unless scoped.
- [ ] Performance-sensitive paths have been checked if changed.
- [ ] Known limitations are documented.
- [ ] Shared research citations were checked or updated when external river/water references affected the decision.
