# Next Session Handoff

## Message To Next Session

We are working on river feature detection for the Waterways add-on: pillows, wakes, eddy-line placement, and the raw/debug tools needed to judge those features accurately. A targeted pillow placement diagnosis first found the obvious forward pillow offset was shader-side reach, so the default `pillow_forward_reach_tiles` is now `0.0`. The user then tested raw `Pillow / Impact Mask` / `obstacle_features.r` and found it still too far ahead of rocks. Phase 6D responded with a scoped bake/classifier pass: raw pillow R now uses tighter pillow-specific support and a nearby hard-contact/protrusion anchor. Phase 6E then halved the raw pillow contact-search distance from `0.14` to `0.07` source tiles for in-game review. The user still reports the pillow starts too far ahead on the actual object. A follow-up inspection found the start is now governed by the baked pillow formula, especially the dilated collision support and hard-boundary context, not by visible shader reach. The latest review clarified that the explicit `0.07` contact search is not the full effective anchor reach because it samples `hard_boundary_at()`, which includes forward-looking `bank_response.a`. The main and obstacle-test river bakes are signature `19`, and the WaterSystem/physics bake was not regenerated.

Feature-local spec-driven docs now exist at `addons/waterways/docs/spec-driven/features/river-pillows/`. For pillow work, treat that folder as the current source of truth before returning to this shared handoff; the pillow-relevant roadmap and audit guidance has been folded into that feature folder. The audit now makes diagnostic split views/probe output the next implementation step before another classifier edit.

Feature-local spec-driven docs now also exist at `addons/waterways/docs/spec-driven/features/river-eddies/`. For wake, eddy-line, or future Phase 7C/7D flow work, treat that folder as the current source of truth before returning to this shared handoff. The current eddy baseline is Phase 7B visual-only: `Eddy-Line Visual Mask` uses the raw-G wake-edge candidate plus nearby wake/obstruction context at `wake_edge_sample_tiles = 0.024`; old raw-B paths remain diagnostic; real reverse/circulating flow and WaterSystem/physics alignment remain deferred.

Start from the feature-local folders first, then `../roadmaps/river-feature-detection-roadmap.md`, `../roadmaps/river-improvements-roadmap.md`, `.codex-research/phase7b_eddy_line_cpu_diagnostic.gd`, `.codex-research/phase7b_wake_edge_sample_sweep/`, and the pillow review outputs under `.codex-research/phase6b_pillows_demo_debug/`. The old eddy hypothesis that the main fix might be a larger `wake_edge_sample_tiles` value alone was rejected. The accepted eddy direction was a raw wake-edge-from-G prototype at the reviewed `0.024` edge scale, now promoted into `Eddy-Line Visual Mask`.

Recommended next move: schedule a dedicated discussion/review session for the pillow placement formula before changing code again. The question is no longer just "how much distance should be halved?" but "which signals should be allowed to define the upstream impact start?" Keep `pillow_forward_reach_tiles = 0.0` while reviewing. If the agreed formula needs a code change, make it a scoped bake/classifier pass after the discussion, with source-signature bump, rebakes, probes, and fresh review captures.

Preferred next review path:

1. Start by reviewing the current formula and deciding the visual definition of "correct pillow start" together.
2. Keep `pillow_forward_reach_tiles = 0.0` so the old ahead-of-rock reach does not confuse the review.
3. Compare `Pillow / Impact Mask`, `Pillow Visual Mask`, `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, `Protrusion / Intersection`, and `Final Flow Strength` at the same rock/protrusion targets.
4. Treat accepted raw placement as the gate for any next material work. Only then tune pillow pressure/highlight/normal/bands/foam or shader gates.
5. If the existing views cannot explain the offset, add a temporary diagnostic split for support/facing, direct `terrain_contact.b`, `bank_response.a`, and final pillow contact-gate contribution.
6. Use `pillow_contact_pull_tiles` / `pillow_contact_pull_strength` only if raw R is placed correctly but the final shader-gated read still looks visually detached.
7. If raw/no-reach placement is still wrong, plan another bake/classifier pass instead of tuning brightness, foam, height, or wake/eddy settings.

## Read First

- `addons/waterways/docs/spec-driven/features/river-pillows/handoff-latest.md`
- `addons/waterways/docs/spec-driven/features/river-pillows/tasks.md`
- `addons/waterways/docs/spec-driven/features/river-pillows/validation.md`
- `addons/waterways/docs/spec-driven/features/river-pillows/plan.md`
- `addons/waterways/docs/spec-driven/features/river-pillows/spec.md`
- `addons/waterways/docs/audit/pillow-system-audit.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/handoff-latest.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/tasks.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/validation.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/plan.md`
- `addons/waterways/docs/spec-driven/features/river-eddies/spec.md`
- `addons/waterways/docs/roadmaps/river-improvements-roadmap.md`
- `addons/waterways/docs/roadmaps/river-feature-detection-roadmap.md`
- `addons/waterways/docs/research/river-research-citations.md`
- `addons/waterways/docs/history/CHANGELOG.md`
- `addons/waterways/shaders/river.gdshader`
- `addons/waterways/shaders/river_debug.gdshader`
- `addons/waterways/gui/debug_view_menu.gd`
- `.codex-research/export_demo_phase7b_wake_edge_sample_sweep.gd`
- `addons/waterways/river_manager.gd`
- `addons/waterways/filter_renderer.gd`
- `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader`
- `addons/waterways/resources/river_bake_data.gd`
- `addons/waterways/system_map_renderer.gd`
- `addons/waterways/shaders/system_renders/system_flow.gdshader`

## Current Baseline

- Phase 5A/5B flow and SDF steering cleanup are accepted by the user after in-game review.
- Phase 6B pillow visuals are closed as the accepted current visual baseline. Pillow height remains default-off, restrained, and visual-only. Follow-up diagnosis found the far-ahead visible pillow read came from shader-side forward reach; the default `pillow_forward_reach_tiles` is now `0.0`. Later raw/in-game reviews showed pillows still too far ahead, so Phase 6D tightened the raw classifier with contact anchoring and Phase 6E halved the raw pillow contact-search distance. After Phase 6E, the user still reports the start is too far ahead on the actual object; the next step is a formula review, not another blind distance reduction.
- Current river bakes are source-signature version `19`:
  - `waterways_bakes/Demo/Water_River.river_bake.res`
  - `waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`
- `waterways_bakes/Demo/Water_River_legacy_test.river_bake.res` remains source-signature version `5`.
- `waterways_bakes/Demo/WaterSystem.water_system_bake.res` was last regenerated after the Phase 5B signature-`16` main river rebake. Do not regenerate it unless final/physics flow changes are explicitly scoped.
- Phase 7A2 classifier refinement is complete as data-only. It updated `obstacle_features.b` and rebaked the main and obstacle-test river resources to signature `17`; Phase 6D/6E later updated `obstacle_features.r` and bumped the current river bakes to signature `19`.
- Phase 7B visual-only wake/eddy-line material preview is implemented and accepted. It added `wake_` controls and debug modes `Wake Visual Mask`, `Eddy-Line Visual Mask`, and `Wake Edge Thinness`. For wake/eddy work, use `addons/waterways/docs/spec-driven/features/river-eddies/` as the feature-local source of truth.
- Phase 7B follow-up debug modes now include `Wake Shared Gate`, `Gated Eddy-Line Source (B * Wake Gate)`, `Wake Confidence Gate`, `Wake Hard/Protrusion Gate`, `Wake Bank Keep Gate`, `Wake Energy Gate`, `Wake Flow Gate`, `Eddy-Line Context Gate`, `Experimental Gated Eddy Source`, `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, `Eddy-Line Wake Context Search`, `Raw Wake-Edge Candidate (from G)`, and `Experimental Wake-Edge Eddy Source`.
- Editor Debug View menu entries no longer use a leading `Display` prefix, and the toolbar button now shows the selected mode, for example `Debug View: Normal` or `Debug View: Foam Mix`. This was a label/caption-only cleanup; debug mode IDs and shader wiring stayed unchanged and are covered by `.codex-research/debug_view_menu_wiring_probe.gd`.
- `.codex-research/phase7b_eddy_line_cpu_diagnostic.gd` is implemented and validated. It samples the existing main and obstacle-test signature-`19` bakes and reports raw B/G/A, `wake_shared_gate`, edge gradient, nearby wake, `wake_edge_thinness`, and final `B * wake_shared_gate * wake_edge_thinness * 1.35` for marked regions.
- `.codex-research/export_demo_phase7b_wake_edge_sample_sweep.gd` is implemented and validated. It exports the same review cameras at `wake_edge_sample_tiles = 0.006`, `0.012`, `0.0195`, and `0.024`, using only live material overrides on the instantiated scene.
- The Phase 7B wake-edge sample sweep was refreshed after adding the new debug-only gate views. Current output under `.codex-research/phase7b_wake_edge_sample_sweep/` includes 268 PNG files: the refreshed sample-folder captures plus the older contact sheets.
- A dedicated categorized citation index now exists at `addons/waterways/docs/research/river-research-citations.md`. Future research should add sources there with short Waterways-specific notes.

## Current Status

- Earlier `Eddy-Line Visual Mask` reviews were effectively uniform green because the old path multiplied raw eddy-line B by the exact-pixel `wake_shared_gate`; that gate was upstream/contact-side while raw B was often farther downstream.
- The edge-sample-only fix was rejected: larger `wake_edge_sample_tiles` made `Wake Edge Thinness` busier, but did not create the desired two trailing wake margins.
- Follow-up review at `wake_edge_sample_tiles = 0.024` showed `Eddy-Line Raw Low Range (B x4)` and `Eddy-Line Candidate Gate` were still green close behind rocks, with red/yellow patches only farther downstream. This moved the diagnosis from final-gate suppression to raw-B placement.
- The user then confirmed `Experimental Wake-Edge Eddy Source` shows the desired two trailing wake lines behind multiple rocks, with green/quieter patches between the converging margins. `Raw Wake-Edge Candidate (from G)` showed the same pattern more strongly, confirming raw wake G has the close-shoulder signal that raw B lacks.
- The user also reported ordinary banks remain green except where rock protrusions are nearby, so the current bank behavior is acceptable for this prototype.
- The actual visible/debug `Eddy-Line Visual Mask` now uses the accepted raw-G wake-edge candidate plus context gate. The default `wake_edge_sample_tiles` value is now `0.024`, matching the accepted review setting. The old raw-B path remains available through `Gated Eddy-Line Source (B * Wake Gate)`, `Eddy-Line Raw Low Range (B x4)`, and related diagnostics.
- The user reported Wake / Eddy material fields did not affect visible water. The cause was a stale debug shader override saved on the generated demo river mesh. `river_manager.gd` now restores the visible material whenever Debug View is Normal and reapplies the active material mode after material-field edits; `Demo.tscn` no longer saves the generated mesh with the debug override.
- After the override fix, the user reported the visible effect is still very subtle. Defaults were increased for a more legible visual pass: `wake_eddy_line_strength = 1.85`, `wake_eddy_line_normal_strength = 0.85`, `wake_eddy_line_foam_bias = 0.18`, with stronger roughness/specular/albedo response and less sparse eddy-line foam/color breakup.
- The user then accepted the eddy-line visual pass: "It looks good." The current documentation records that the important fix was channel/phase alignment: raw B was plausible but too far from the source rocks, while raw G produced the accepted paired wake-edge distance and pattern.
- The user clarified the apparent broad editor-field issue came from another setting being too high. Treat the editor-field handoff warning as reverted.
- Phase 6E changed only the raw pillow classifier contact-search distance, direct filter fallback default, and river bakes. Fresh `.codex-research/phase6c_pillow_placement_diagnostic/` captures show diagnostic atlas-space raw R above `0.05` is about `4.70%` on main and `4.61%` on obstacle-test; no-reach visual mask above `0.05` is about `2.32%` main and `2.26%` obstacle-test.
- Post-Phase-6E inspection found the visible shader is not inventing the current forward start when `pillow_forward_reach_tiles`, `pillow_contact_pull_tiles`, and `pillow_contact_pull_strength` are all default-off. The visible start mostly reveals the baked raw `obstacle_features.r` channel through gates.
- Current raw pillow formula summary:
  - visible `Pillow Visual Mask` = raw `obstacle_features.r` multiplied by confidence, hard-boundary, ordinary-bank suppression, energy, flow, and strength gates;
  - raw `obstacle_features.r` = `max(pillow_source * pillow_contact_gate, pulled_contact_source)`;
  - `pillow_source` = dilated collision support * flow-facing obstacle normal squared * pillow bank/context suppression;
  - `pillow_contact_gate` samples hard-boundary context at the current pixel and downstream by the pillow contact-search distance;
  - `hard_boundary_at` = `max(bank_response.a, terrain_contact.b)`;
  - `bank_response.a` is a semantic hard-boundary/protrusion response that uses forward protrusion sampling, not literal object contact only.
- Review finding: halving `pillow_contact_search_tiles` only reduced the explicit pillow search. It did not remove the forward-looking `bank_response.a` halo or the broad dilated support field, so the mask can still start ahead of the visible rock.
- Review finding: the `0.07` source-tile contact search is not the full effective anchor reach. `pillow_contact_gate_at()` samples `hard_boundary_at()` as far as `1.5 * pillow_contact_search_uv`; `hard_boundary_at()` includes `bank_response.a`; and `bank_response.a` already uses `forward_protrusion()` at `0.75x` and `1.5x` of `RIVER_BANK_RESPONSE_PROBE_TILES = 0.20`. This means a candidate pixel can be contact-gated by a downstream semantic protrusion halo even when direct `terrain_contact.b` is much tighter.
- Review finding: `pillow_source_at()` uses the generic dilated collision support generated from `baking_dilate = 0.6`, so support and normals can be alive before literal visible object contact.

## Pillow Formula Review Notes

Do not treat the next pillow pass as another scalar-distance tweak until the formula is agreed. The review question is: what should be allowed to say "this pixel is the start of a pillow"?

Current code references:

- Visible pillow gate: `addons/waterways/shaders/river.gdshader` `pillow_visual_mask()` and `pillow_visual_mask_with_reach()`.
- Raw pillow bake: `addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader` `pillow_source_at()`, `pillow_contact_gate_at()`, and `hard_boundary_at()`.
- Hard-boundary/protrusion context: `addons/waterways/shaders/filters/bank_response_feature_mask_filter.gdshader` `forward_protrusion()` and `hard_response`.
- Support field: `addons/waterways/river_manager.gd` creates a dilated collision texture from `baking_dilate = 0.6`, then feeds it to the obstacle-feature mask as `support_texture`.
- Current reach/support constants to keep in mind: `RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES = 0.07`, `RIVER_BANK_RESPONSE_PROBE_TILES = 0.20`, and `baking_dilate = 0.6`.

Likely review options:

1. Make pillow contact use only direct protrusion/contact (`terrain_contact.b`, possibly with near-surface contact) while leaving broader `bank_response.a` for wakes, eddies, flow drag, and flow pressure.
2. Keep `bank_response.a` in the formula but weight it much lower or require it to overlap direct contact/support before it can anchor a pillow.
3. Tighten the pillow-specific support field or thresholds so the dilated collision halo cannot begin the pillow too far from the visible object.
4. Add a diagnostic source view that isolates "pillow support/facing", "direct terrain protrusion contact", "bank-response anchor contribution", and "final pillow contact gate" before changing the classifier.

Ask the user for another session to review these formula options in the editor before implementing. The session should start with live viewport comparison of `Pillow / Impact Mask`, `Pillow Visual Mask`, `Hard-Boundary / Protrusion Response`, and `Protrusion / Intersection` around the same rocks that still look wrong.

## Feature Detection Workflow

- Follow `../roadmaps/river-feature-detection-roadmap.md`.
- Codex and the user can both be wrong; do not be sycophantic.
- User confirmation happens in the editor 3D viewport and runtime debug views. Screenshots/captures support review, but do not decide acceptance alone.
- Compare raw masks against final visual masks before changing code.
- If raw mask placement is good but final read is bad, tune shader gates/material response first.
- If raw mask placement is wrong, plan a bake-level classifier pass with source-signature bump, rebakes, stats, probes, and fresh captures.
- Keep changes generalizable beyond `Demo.tscn`.

## Eddy Review Lessons To Preserve

The eddy-line pass was accepted only after adversarial review checked whether the result matched wake anatomy rather than merely becoming brighter. The user provided downstream-looking-upstream screenshots with blue-drawn wake lines that helped identify the accepted paired-margin pattern.

Visual interpretation to preserve:

- The camera is downstream of the rocks looking upriver, so water likely flows from the far/top side of the screenshot toward the near/bottom side.
- `Wake Edge Thinness` should appear mostly on downstream shoulders of rocks/protrusions and along the two thin trailing margins of the wake.
- It should not become a filled wake blob directly behind the rock center.
- It should not outline the whole upstream impact face; that area belongs more to pillow/compression behavior.
- It should not draw long continuous lines along every ordinary bank.
- Missing signal around the big bottom-left rock cluster and the central rock's downstream/right shoulder was suspicious and led to the sample-distance/channel comparison.
- Missing signal on small side-bank circled areas may be acceptable unless those terrain pieces are hard convex protrusions intruding into the current.
- Do not tune around the hot streak at the river start. If a parameter mainly strengthens that start-of-river hotspot while the rock-garden/downstream-rock shoulder areas remain green, reject it.

What the eddy fix proved:

- Include the user in visual analysis before accepting changes. The user can freely move the editor camera and inspect close-up areas better than fixed exports can.
- The fix was channel/phase alignment. Raw B was alive but too far from the close-behind-rock shoulders; raw G produced the accepted paired wake-edge margins.
- Bigger sampling alone was not enough. `wake_edge_sample_tiles = 0.024` became the accepted default only after the source changed to the raw-G wake-edge candidate.
- Debug-only gate-component views now exist for confidence, hard/protrusion context, ordinary-bank keep/suppression, energy, flow, and current combined `wake_shared_gate`.
- `Raw Wake-Edge Candidate (from G)` and `Experimental Wake-Edge Eddy Source` remain exposed so future work can compare the accepted source against old raw-B diagnostics.
- For pillows, repeat this method: compare raw/final placement to the source rock first, then tune visuals after placement is correct.

What may be excess for the first implementation:

- A full editor marker authoring system.
- A polished UI for arbitrary region drawing.
- Many new debug modes at once.
- Composite overlays for every possible channel if a small set of diagnostic views answers the first question.
- Reworking the bake classifier, source signatures, or saved bakes before proving raw placement is actually wrong.

What seems feasible:

- Add a temporary pillow placement probe or export helper only if the editor debug views cannot answer where the forward offset begins.
- Add low-range/threshold pillow views only if the current palette hides useful raw `obstacle_features.r` values.
- Prefer the smallest implementation that answers "does the raw or final pillow mask move ahead of the source rock?"
- Keep the work visual/debug-only unless review proves the raw pillow channel itself is wrong or the user explicitly asks to move into bake changes.

## Do Not Touch Unless Explicitly Scoped

- accepted source flow
- SDF steering
- terrain-contact thresholds
- bank-response thresholds
- final flow/reverse/circulating physics
- WaterSystem flow shader wiring
- saved WaterSystem bake
- river bake resources/source signature

## Next Checklist

1. Read the channel/phase alignment note in `../roadmaps/river-feature-detection-roadmap.md`, the Phase 6/7 sections of `../roadmaps/river-improvements-roadmap.md`, and this handoff's pillow formula review notes.
2. Ask for a dedicated pillow formula review session before changing code.
3. Lock pillow review targets before tuning:
   - "should detect": upstream impact/compression faces of rocks and hard protrusions;
   - "should not detect": open water far ahead of rocks, downstream wakes, smooth ordinary banks, and filled wake centers;
   - second layout: `Water_River_obstacle_test.river_bake.res` / obstacle-test scene.
4. Compare these debug views in the editor viewport:
   - `Pillow / Impact Mask`
   - `Pillow Visual Mask`
   - `Pillow Height Influence`
   - `Terrain Pillow Height Influence`
   - `Obstruction Pillow Height Influence`
   - `Obstacle Confidence`
   - `Hard-Boundary / Protrusion Response`
   - `Protrusion / Intersection`
   - `Final Flow Strength`
5. Decide whether any remaining forward offset begins in raw/no-reach placement:
   - refreshed raw R still ahead of the source: another bake/classifier/source-support issue;
   - raw R correct but no-reach final mask ahead: shader gate/reach issue;
   - raw and no-reach final both correct but visible read odd: material response issue.
6. If the existing editor views cannot explain the offset, add a temporary diagnostic split before changing classifier constants. The first split should separate direct `terrain_contact.b` anchoring from `bank_response.a` anchoring and pillow support/facing.
7. If placement is close but still visually detached, test `pillow_contact_pull_tiles` and `pillow_contact_pull_strength` with `pillow_forward_reach_tiles` left at `0.0`.
8. If code changes are made, keep them scoped to the diagnosed layer and validate the affected probes. Preserve the accepted Phase 7B eddy-line behavior.
9. Leave further bake classifier edits, source-signature bumps, final flow, WaterSystem flow, and Phase 7C reverse/circulating flow for a later implementation session unless the user explicitly expands scope.

## Useful Outputs

- `.codex-research/phase7a2_mask_preflight/`
- `.codex-research/phase7a2_wake_eddy_demo_debug/`
- `.codex-research/phase7b_wake_eddy_demo_debug/`
- `.codex-research/phase7b_wake_edge_sample_sweep/`
- `.codex-research/phase6c_pillow_placement_diagnostic/`
- `.codex-research/phase6b_pillows_demo_debug/`
- `.codex-research/phase6_pillow_height_experiment_debug/`

## Validation Commands

Run the CPU/readback diagnostic:

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Path\To\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user-phase7b-eddy-cpu-diagnostic'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://.codex-research/phase7b_eddy_line_cpu_diagnostic.gd'
```

Use this Godot launch pattern for visual probes:

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Path\To\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://.codex-research/phase7b_wake_eddy_visual_probe.gd'
```

Recent expected checks:

- `PHASE7B_EDDY_LINE_CPU_DIAGNOSTIC_OK`
- `PHASE7B_WAKE_EDDY_VISUAL_PROBE_OK`
- `PHASE7B_WAKE_EDDY_EXPORT_OK`
- `PHASE6C_PILLOW_PLACEMENT_DIAGNOSTIC_OK`
- `PHASE6C_PILLOW_EDITOR_WIRING_PROBE_OK`
- `PHASE6B_PILLOW_TUNING_PROBE_OK`
- `PHASE7A2_WAKE_EDDY_PREFLIGHT_OK`
- `PHASE7A2_WAKE_EDDY_EXPORT_OK`

Export Phase 7B captures:

```powershell
$root = Get-Location
$godotConsole = $env:GODOT_CONSOLE
if (-not $godotConsole) { $godotConsole = 'C:\Path\To\Godot_v4.6.3-stable_win64_console.exe' }
$godotUser = Join-Path $root '.codex-research\godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $godotUser 'roaming'), (Join-Path $godotUser 'local') | Out-Null
$env:APPDATA = Join-Path $godotUser 'roaming'
$env:LOCALAPPDATA = Join-Path $godotUser 'local'
& $godotConsole --path $root --script 'res://.codex-research/export_demo_phase7b_wake_eddy_views.gd'
```

## Reference Notes

- External research/source links live in `../research/river-research-citations.md`.
- Feature definitions, review principles, and raw-tooling ideas live in `../roadmaps/river-feature-detection-roadmap.md`.
- Phase roadmap/history context lives in `../roadmaps/river-improvements-roadmap.md`.
- Detailed historical phase log lives in `../history/CHANGELOG.md`.
- Online research is appropriate when a concrete uncertainty appears; prefer sources with actionable algorithms, data layouts, tuning guidance, or debug workflows, and add useful sources to `../research/river-research-citations.md`.
