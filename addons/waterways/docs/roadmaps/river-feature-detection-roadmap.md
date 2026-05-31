# River Feature Detection Roadmap

This roadmap describes how Codex and the user should improve river feature detection together. It is separate from `river-improvements-roadmap.md` because detection review is an ongoing workflow, not a single phase.

The core rule: Codex can propose small detection changes and build raw readings, but the user confirms the meaning of those detections in the editor 3D viewport and at runtime. Exported screenshots are useful evidence, not the final judge.

Supporting external and local references live in `../research/river-research-citations.md`. Future research sessions should add new sources there with a short Waterways-specific note before those sources are used to justify feature-detection changes.

## Goals

- Improve detection of pillows, downstream wakes, and eddy lines without rushing into physics-facing flow changes.
- Keep raw source masks, final visual masks, and visible material response clearly separate.
- Build enough numeric tooling that Codex can reason about detection coverage instead of relying only on screenshots.
- Use user-confirmed viewport review to define "should detect" and "should not detect" areas.
- Keep every detection change scoped: shader-only tuning, bake-level classifier changes, resource-layout changes, and WaterSystem/physics changes should remain distinct decisions.
- Improve the add-on as a reusable river tool, not just as a tuned demo scene. Detection changes should be explainable, portable, and useful to other projects or to developers building bespoke river systems.

## Project Principles

- Respect the add-on lineage. Waterways builds on prior MIT-licensed work that already solved hard authoring, baking, and rendering problems. New detection work should preserve that spirit: documented, inspectable, and useful beyond this demo.
- Do not overfit to `Demo.tscn`. The demo is the first review environment, not the whole target. A change that fixes one rock arrangement but makes ordinary banks, shallow streams, or alternate obstacle layouts worse is not a detection improvement.
- Prefer general concepts over scene-specific constants: upstream impact face, hard protrusion, ordinary bank, downstream wake, wake edge, grade/energy context, and final-flow strength.
- Keep author trust high. Debug views and numeric readings should explain why a feature appears or disappears, so users can reason about their own rivers.
- Preserve MIT-friendly reference value. When possible, document algorithms, tradeoffs, validation captures, and failure modes clearly enough that other developers can learn from or adapt the work.
- Treat collaboration as truth-seeking, not agreement-seeking. The user and Codex can both be wrong, and the user does not want sycophantic responses. If Codex thinks the user is misunderstanding the hydrology, shader behavior, game-design tradeoff, data layout, or add-on architecture, Codex should push back clearly and explain why.
- Use disagreement constructively. Codex should distinguish "the viewport review shows this is wrong" from "the underlying principle suggests a different fix" from "we need better evidence before changing code."
- Teach as the system improves. When useful, Codex should explain the relevant hydrology, shader, rendering, physics, or game-design concept in plain language and point to the roadmap, source comments, captures, or external references that can help the user build understanding while reviewing.

## Current Baseline

- Phase 5A/5B flow behavior is accepted as the downstream-preserving baseline.
- Phase 6B pillow visuals are the accepted current visual baseline. `Pillow / Impact Mask` is the raw `obstacle_features.r` source, and `Pillow Visual Mask` is the shader-gated material mask. Follow-up diagnosis found the obvious forward offset came from shader-side forward reach, so the default `pillow_forward_reach_tiles` is now `0.0`; the material slider remains available for explicit review. Later raw-classifier passes tightened `obstacle_features.r` with pillow-specific support thresholds, a nearby hard-contact anchor, and then a halved contact-search distance after live/in-game review showed raw/visible pillows still too far ahead of rocks. The current pillow issue needs a formula review: the remaining forward start appears to come from baked support/contact signals, especially dilated collision support and hard-boundary context, not from visible reach. The latest review found that the explicit `0.07` pillow search is not the full effective anchor reach because it samples `hard_boundary_at()`, which includes forward-looking `bank_response.a`. The 2026-05-30 pillow audit adds stronger evidence: about `35.17%` of main-river and `35.88%` of obstacle-test raw pillow pixels above `0.05` are strongly bank-response anchored while direct terrain protrusion is weak or absent, so the next pass should add diagnostic split views before another classifier edit.
- Phase 7B wake/eddy-line visuals are implemented as surface-only and accepted as a visible preview. `Wake Visual Mask` is the shader-gated downstream wake mask. `Eddy-Line Visual Mask` now uses paired wake-edge margins derived from raw `obstacle_features.g` plus nearby wake/obstruction context, instead of the older raw-B exact-gate path.
- The Phase 7B eddy-line fix was a channel/phase alignment fix, not primarily a brightness fix. Raw `obstacle_features.b` was semantically plausible but landed too far downstream or away from the close-behind-rock shoulders. Raw wake seed `obstacle_features.g`, when sampled as a wake-edge candidate at the reviewed `wake_edge_sample_tiles = 0.024`, produced the accepted two trailing margins with a quieter wake center.
- Current river bakes are signature version `19`. Do not bump the signature, rebake, or regenerate WaterSystem data unless the chosen change really needs it.

## Review Loop

1. Pick one feature and one detection question.
   Examples: "Should this upstream rock face be a pillow?", "Should this downstream seam be an eddy line?", "Should this ordinary bank be ignored?"
2. Review the raw source debug view first.
   If raw detection is wrong, material tuning cannot fix it.
3. Review the final visual/debug mask second.
   If raw detection is good but the final mask is too sparse or too broad, tune shader gates or final-mask logic.
4. Review visible water last.
   If the mask is good but the feature is too subtle or too strong, tune material response rather than detection.
5. Let the user confirm in the editor 3D viewport or runtime view.
   Codex should not treat exported screenshots as acceptance by themselves.
6. Add or update a raw reading if the decision depends on coverage, false positives, or a user-identified area.
7. Only then make the smallest scoped change.

## Channel Phase Alignment

Some feature bugs are not caused by weak material response. They are caused by the chosen source channel being in the wrong spatial phase relative to the physical feature.

The Phase 7B eddy-line fix is the current example:

- The old `Eddy-Line Visual Mask` used raw `obstacle_features.b` multiplied by an exact-pixel wake gate.
- User review showed raw B and the exact wake gate were alive, but they did not line up with the desired close-behind-rock wake shoulders.
- Larger edge sampling alone made views busier but did not create the accepted two trailing rock-wake margins.
- Testing alternate channels showed that raw `obstacle_features.g` contained a better-distance wake-edge pattern: paired margins behind rocks with a quieter green middle.
- The accepted visual mask now derives eddy-line placement from that raw-G wake-edge candidate and uses context gates only to keep it tied to nearby wake/obstruction support.

Use this method when a feature consistently appears too far upstream, too far downstream, or detached from its source rock/protrusion:

- Compare candidate channels by physical placement and pattern anatomy first: distance from the source, side of the obstacle, paired margins versus filled blobs, and ordinary-bank behavior.
- Only tune visual strength after the raw/final mask is in the right place.
- Keep old plausible-but-misplaced channels as diagnostics instead of deleting them immediately.
- For pillows, this means the next pass should compare raw `Pillow / Impact Mask`, final `Pillow Visual Mask`, support/contact channels, obstacle confidence, any reach/forward sampling, and the default-off contact-pull experiment against the actual upstream impact face before increasing pillow strength.

## Feature Definitions

- Pillow: upstream compression or pressure on the impact face of a rock, boulder, wall, or hard protrusion.
- Wake: downstream disturbed region behind an obstruction where the main current has been split, slowed, or broken up.
- Eddy line: narrow boundary where main current shears against wake or slower/recirculating water.
- Ordinary bank: normal shoreline or bank friction that should not automatically become a pillow, wake, or eddy.
- Hard protrusion: obstacle, cliff, or terrain contact that intrudes into flow enough to justify stronger feature detection.
- False positive: a detected feature in a place the user says should not detect.
- False negative: a missing feature in a place the user says should detect.
- Raw mask: baked/source feature mask before shader gates.
- Final visual mask: shader-side mask after confidence, context, energy, flow, and suppression gates.

## Generalization Checks

Every detection change should be reviewed against more than one layout before it is treated as an add-on improvement.

Required current checks:

- Main demo river.
- Obstacle-test river.
- Overview overhead view.
- Rock garden overhead view.
- Main bend low-oblique view.
- Downstream rocks low-oblique view.

Useful future checks:

- Single isolated boulder in a straight channel.
- Hard wall protrusion with no detached rock.
- Ordinary smooth bank with no obstruction.
- Shallow low-energy stream segment.
- Steeper chute or high-energy obstacle segment.
- Wide river where the same obstacle occupies a smaller portion of the channel.
- Narrow channel where banks and rocks are close together.

If a detector only works in the main demo camera angles, it should stay experimental.

## Pillow Detection

Primary review views:

- `Pillow / Impact Mask`: raw upstream impact source from `obstacle_features.r`.
- `Pillow Visual Mask`: final shader-gated mask used by material accents.
- `Pillow Height Influence`: combined default-off height influence.
- `Terrain Pillow Height Influence`: terrain/hard-boundary height influence.
- `Obstruction Pillow Height Influence`: raw in-river obstruction height influence.
- `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, `Grade / Energy Channel`, and `Final Flow Strength`: supporting gates.

What good detection means:

- Upstream faces of rocks, boulders, and hard wall protrusions are detected.
- Ordinary banks do not become continuous pillow strips.
- Detection appears on the impact/compression face, not the downstream wake.
- Raw `Pillow / Impact Mask` and final `Pillow Visual Mask` explain each other.

Decision guide:

- Raw pillow mask correct, final visual mask too sparse: tune shader-only gates or material controls.
- Raw pillow mask correct, visible water too subtle: tune pressure/highlight/normal/band/foam response.
- Raw pillow mask wrong: plan a bake-level classifier pass with source-signature bump, rebakes, stats, probes, and fresh captures.
- Pillow height artifact: treat it as visual/material or mesh-topology work before changing detection.

Current pillow follow-up:

- The reported far-ahead pillow offset was reproduced by comparing no-reach and prior-default-reach visual masks.
- The first fix is shader-only: default forward reach is `0.0`, which keeps the final visual mask aligned to the raw/gated source unless the user deliberately raises the reach slider.
- Follow-up live review showed the raw `Pillow / Impact Mask` still sat too far ahead of rocks, so the current bakes now use a contact-anchored pillow classifier in `obstacle_features.r` with the contact-search distance halved from `0.14` to `0.07` source tiles for review.
- Post-6E inspection found the current visible shader is not the main source of the remaining forward start when `pillow_forward_reach_tiles`, `pillow_contact_pull_tiles`, and `pillow_contact_pull_strength` are all default-off. The visible mask mostly reveals the baked raw `obstacle_features.r` through gates.
- The raw pillow formula currently combines a dilated collision support field, flow-facing obstacle normals, and a hard-boundary contact gate. The contact gate uses `hard_boundary_at = max(bank_response.a, terrain_contact.b)`. `bank_response.a` is a semantic hard-boundary/protrusion response that looks forward for protrusion context, so it can produce a forward halo rather than literal object contact.
- Halving the pillow contact-search distance reduced only one downstream sampling term. It did not change the forward-looking `bank_response.a` contribution or the size/thresholds of the dilated support field. This is why another blind distance reduction may not address the actual start rule.
- The effective contact anchor is broader than the `0.07` source-tile constant suggests. `pillow_contact_gate_at()` samples up to `1.5 * pillow_contact_search_uv`; each sample can accept `bank_response.a`; and `bank_response.a` uses `forward_protrusion()` up to `1.5 * RIVER_BANK_RESPONSE_PROBE_TILES`, currently `0.20` source tiles. This can gate a pillow from a downstream semantic halo even where direct `terrain_contact.b` is tight.
- The source side has a second placement risk: `pillow_source_at()` uses the same dilated collision support generated from `baking_dilate = 0.6`, so support and obstacle normals can be present before the visible object contact that the user is judging in the viewport.
- The pillow audit's anchor split found over one third of raw pillow pixels are strongly bank-response anchored while direct terrain protrusion is weak or absent. Treat that as high-severity evidence that current views are missing the exact source split needed for the next review.
- The shader-side contact-pull controls remain default-off review tools, but the first placement check should now be against the refreshed raw R, not against material brightness or height.
- Keep reviewing `Pillow / Impact Mask`, `Pillow Visual Mask`, `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, terrain contact, and final flow at the same rock/protrusion targets.
- If the refreshed raw/final masks still look ahead of a source rock in live viewport review, treat that as a remaining classifier-placement issue before tuning pillow brightness, foam, or height.

Audit-guided next pass:

1. Add diagnostic split views or probe output before changing the classifier:
   - pillow support/facing source;
   - direct `terrain_contact.b` anchor;
   - `bank_response.a` anchor;
   - combined pillow contact gate;
   - bank-only anchor contribution.
2. Review those views live in the editor on the same rocks/protrusions where the user sees the forward offset.
3. If the split confirms bank-response anchoring is the cause, change raw pillow R so direct protrusion/contact is required or near-required.
4. Keep `bank_response.a` as context only for pillows.
5. Tighten pillow-specific support if needed, but do not globally reduce `baking_dilate = 0.6` without reviewing flow, foam, pressure, wakes, and obstacle avoidance.
6. Report effective chain reach in docs/diagnostics so future sessions stop treating `0.07` as the whole reach.

Formula review questions before the next classifier change:

- Should pillow anchoring require direct contact/protrusion (`terrain_contact.b`) instead of the broader semantic `bank_response.a`? The audit recommends yes unless live review disproves it.
- Should `bank_response.a` be allowed only as a weak context multiplier, not as a contact anchor? The audit recommends yes.
- Should pillow support use a tighter support texture or higher `pillow_support_start` so the dilated collision halo cannot define the start too early?
- What is the smallest diagnostic split that answers direct contact, bank-response contribution, support/facing contribution, final contact-gate contribution, and bank-only contribution before changing the formula?

## Wake And Eddy-Line Detection

Primary review views:

- `Wake / Eddy Seed Mask`: raw downstream wake source from `obstacle_features.g`.
- `Eddy-Line / Shear Mask`: raw eddy-line/shear source from `obstacle_features.b`.
- `Wake Visual Mask`: final shader-gated wake surface mask.
- `Wake Edge Thinness`: edge filter used to keep eddy-line accents narrow.
- `Eddy-Line Visual Mask`: final shader-gated eddy-line material mask.
- `Obstacle Confidence`, `Hard-Boundary / Protrusion Response`, `Grade / Energy Channel`, and `Final Flow Strength`: supporting gates.

Accepted Phase 7B fix:

- Earlier `Eddy-Line Visual Mask` reviews were uniform green away from the river start because the old visible path multiplied raw `obstacle_features.b` by an exact-pixel `wake_shared_gate`.
- User review showed the old raw-B path produced red/yellow activity too far downstream from rocks, while close-behind-rock shoulders stayed green.
- The edge-sample sweep was useful evidence but not the whole fix. `wake_edge_sample_tiles = 0.024` became useful only after the source changed to a raw-G wake-edge candidate.
- `Raw Wake-Edge Candidate (from G)` and `Experimental Wake-Edge Eddy Source` showed the accepted anatomy: two trailing wake-edge/eddy-line margins behind rocks, with quieter green patches inside the wake.
- Smooth banks stayed mostly green except where real rock or hard protrusions were nearby.
- The visible/debug `Eddy-Line Visual Mask` now uses the raw-G wake-edge candidate plus nearby wake/hard-protrusion context, current-pixel bank suppression, energy, and flow gates.
- The old B-based path remains diagnostic through `Eddy-Line / Shear Mask`, `Gated Eddy-Line Source (B * Wake Gate)`, `Eddy-Line Raw Low Range (B x4)`, `Eddy-Line Candidate Gate`, `Eddy-Line Hard Context Search`, and `Eddy-Line Wake Context Search`.
- This was shader/material/debug work only: no source-signature bump, river rebake, saved WaterSystem bake regeneration, or reverse/circulating flow change.

What good detection means:

- Wake appears downstream of hard obstruction context.
- Eddy-line appears as a narrow, intermittent boundary between main current and wake.
- Ordinary bank edges do not become long eddy-line strips.
- The mask does not imply reverse/circulating physics. Actual eddy flow remains a later milestone.

Wake-edge visual anatomy:

- When the camera is downstream looking upriver, water generally moves from the far/upstream side of the view toward the near/downstream side.
- `Wake Edge Thinness` should concentrate on the downstream shoulders of rocks, boulders, and hard protrusions, then continue as two thin trailing margins where faster current shears against the slower wake.
- The center of the wake behind an obstruction can remain mostly unlit by the thinness view; that area is wake body, not the wake edge.
- Upstream impact faces should be dominated by pillow/compression behavior, not wake-edge thinness.
- Hard convex banks or wall protrusions may produce wake-edge thinness downstream of the protrusion, but smooth ordinary banks should not become continuous highlighted outlines.
- User-circled Phase 7B viewport review found missing wake-edge thinness around the large lower rock cluster and the central rock downstream shoulder. Those are plausible false negatives to check during the sample-distance sweep.
- A useful tuning result must improve rock/protrusion shoulder and trailing-margin signal away from the river start. If the only visible eddy-line response remains the start-of-river hotspot, the final mask is still failing the review.

Reusable channel-alignment triage:

1. Lock the review targets before tuning.
   Use rock-garden and downstream-rock shoulder/trailing wake regions as "should detect" targets, smooth ordinary banks as "should not detect" controls, and the obstacle-test river as a second layout check. Exclude the known start-of-river hotspot from acceptance.
2. Prove the debug view is honest.
   Compare raw channels, final visual masks, and any CPU/readback values before judging visible water.
3. Compare channels by distance from the physical source.
   If the named channel is alive but too far from the rock/protrusion, inspect nearby channels or derived candidates before changing strength.
4. Split source-placement failures from gate failures.
   If the raw source is in the right place and the final mask is not, debug gates. If the raw source is in the wrong place, shader strength cannot fix it.
5. Tune visible material last.
   Once the debug mask is placed correctly, tune subtle normal/roughness/turbulence first. Avoid white foam until the mask is trusted, because bad eddy-line foam will read like shoreline artifacts.

## Raw Tools And Readings

Useful future tools:

- Named-region coverage reports for user-identified expected areas.
- Raw-versus-final overlap reports for pillows, wakes, and eddy lines.
- Ordinary-bank false-positive rates.
- Hard-boundary/protrusion support rates.
- Grade/energy and final-flow strength context summaries.
- Sample probes at user-marked "should detect" and "should not detect" locations.
- Optional editor-authored or script-authored review markers placed near specific rocks, walls, banks, or downstream seams.
- Low-range debug palettes or alternate debug modes when green-to-red masks are too easy to misread.
- Small synthetic bake scenes for isolated feature behavior.
- A review artifact manifest that records which scene, camera, debug mode, script, and parameter set produced a capture or reading.
- Parameter-sweep captures for shader-only review values, especially `wake_edge_sample_tiles`, so visual decisions can compare one setting at a time against the same camera.

Raw `obstacle_features.b/g/a` readability improvements:

- Add low-range heatmap views for raw `B`, `G`, and `A`, with useful ranges such as `0.00-0.10` or `0.00-0.25` stretched across the full palette so faint but meaningful signal is not hidden as uniform green.
- Add threshold-band views for raw channels, with fixed bands such as `0`, `0.01+`, `0.05+`, `0.10+`, `0.25+`, and `0.50+`.
- Add binary threshold preview modes for raw `B`, `G`, and `A`; make thresholds adjustable in shader uniforms or scripted exports when practical.
- Add a cursor, marker, or scripted sample readout for user-circled areas that reports raw `B`, raw `G`, raw `A`, hard-boundary/protrusion context, ordinary-bank suppression, grade/energy, and final-flow strength.
- Add named-region stats for user-marked "should detect" and "should not detect" regions, including average, max, percent above `0.05`, percent above `0.25`, and percent above `0.50`.
- Add a nearest/raw-texel mode or CPU readback path so filtered shader sampling can be separated from the actual baked pixel values.
- Add a raw composite view that shows how `G` wake seed, `B` eddy-line/shear, and `A` confidence overlap, so review can tell whether eddy-line candidates sit on wake edges, inside wake blobs, or outside confidence.
- Add raw-to-final retention views for eddy lines: raw `B`, `B * wake_shared_gate`, `wake_edge_thinness`, and `B * wake_shared_gate * wake_edge_thinness`.
- Treat these readability tools as diagnostic work. Do not tune shader gates, rebake classifier data, or change final-flow behavior until the raw/intermediate readings explain where expected pixels are present or lost.

Suggested output pattern:

- Feature name.
- Raw mask coverage in expected regions.
- Final mask coverage in expected regions.
- False-positive coverage in ordinary-bank or should-not-detect regions.
- Top gating reason for missing pixels when possible.
- Screenshots or captures as supporting evidence only.

Suggested acceptance metrics:

- Expected-region raw coverage.
- Expected-region final-mask coverage.
- Final-mask retention from raw mask.
- False-positive coverage in ordinary-bank regions.
- Hard-protrusion support percentage.
- Grade/energy support percentage.
- Final-flow support percentage.
- Top two gates suppressing expected pixels.

These metrics should guide review, not replace the user's viewport judgment.

## Debug View Backlog

- Low-range grayscale or heatmap modes for masks whose useful values are below the current green-to-red visible range.
- Raw `obstacle_features.b/g/a` readability modes: low-range heatmaps, threshold bands, binary previews, nearest/raw-texel views, composite overlap, and raw-to-final retention.
- Binary threshold preview modes with adjustable threshold uniforms or scripted exports.
- Raw-versus-final comparison overlays for pillows, wakes, and eddy lines.
- Gating-reason views that show which term suppressed a pixel: confidence, hard-boundary context, ordinary-bank suppression, grade/energy, final-flow strength, wake-edge thinness, or source-support rejection.
- Named-region overlay or marker labels for expected and rejected areas.

## Change Boundaries

Shader-only detection/gate tuning:

- Allowed for final visual masks when raw source masks are correct.
- Requires visible/debug shader parity and probe updates.
- Does not require source-signature bump, river rebake, or WaterSystem regeneration.

Material response tuning:

- Use when masks are placed correctly but visible read is too subtle, too strong, or too foam-like.
- Does not change raw detection.
- Does not require source-signature bump, river rebake, or WaterSystem regeneration.

Bake-level classifier refinement:

- Use only when raw source masks are wrong.
- Requires source-signature bump, main and obstacle-test rebakes, metadata/stat updates, validation probes, and fresh review captures.

New feature texture/channel:

- Requires `RiverBakeData` layout changes, material wiring, debug modes, validation/export script updates, source metadata, source-signature bump, and rebakes.

Final-flow or physics-facing changes:

- Not part of ordinary detection tuning.
- Requires visible shader, debug shader, system-flow shader, WaterSystem regeneration, validation, and user runtime review so visuals and buoyancy agree.

## Working Notes

- Go slowly. One feature, one question, one small edit at a time.
- Keep pillows upstream and wakes/eddy lines downstream.
- Do not promote scalar masks into reverse/circulating flow. They do not encode eddy center, spin side, or velocity offset.
- Prefer user-confirmed editor viewport semantics over Codex-only screenshot interpretation.
- Make debug views and raw readings explain why a pixel is present or missing before changing thresholds.
- Write down why a detection change should generalize beyond the demo scene before accepting it as part of the add-on.
