# Research: River Refactor R7 - RenderingDevice Compute Path

## Current Truth

- Date: 2026-06-15
- Scope: official Godot documentation review plus installed Godot 4.6.3 API/runtime spot-check. The shipped R7 low-cost baseline fixture/probe slice, non-replacing production compute backend skeleton, first isolated non-replacing pressure-Jacobi solve/filter compute step, non-replacing production-shaped pressure-Jacobi stack, expanded projection diagnostic, opt-in sampler diagnostics, pass-limited pressure prefix diagnostic, probe-only `FRAGCOORD` diagnostic, canonical acceptance, selection/abort, representative visuals, report-only generated-output replacement staging, source signature v29, gated replacement branch, refreshed production replacement validation/runtime smoke, broader promotion fixture coverage, intentional saved-output promotion, accepted switched/default compute path, requested compute-default human-visible in-game review, explicit legacy-vs-compute backend performance comparison, and final pre-switch non-neutral/saved-load/system-map/selection-cleanup checks are complete; any legacy-path removal remains deferred until a separate explicit comparison/removal protocol is accepted.
- Implementation target remains Godot 4.6.3 for this project, so the cited 4.6 documentation is the primary source. Latest official docs were spot-checked for the same topic area, but this plan should be validated against the installed 4.6.3 binary before code patches.

## Official Sources Read

- [Using compute shaders - Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/compute_shaders.html)
- [CanvasItem shaders - Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html)
- [Shading language - Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shading_language.html)
- [RenderingDevice class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html)
- [RenderingServer class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html)
- [RenderingDevice class reference - latest](https://docs.godotengine.org/en/latest/classes/class_renderingdevice.html) spot-check for API drift after 4.6.
- [Image class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_image.html)
- [OS class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_os.html)
- [Time class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_time.html)
- [SceneTree class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_scenetree.html)
- [ResourceSaver class reference - Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_resourcesaver.html)

## Documentation Findings That Affect R7

1. Compute shaders are available only through RenderingDevice-based renderers, i.e. Forward+ or Mobile. The Compatibility/OpenGL path cannot be the R7 compute validation target, and the docs warn that mobile compute support can be poor due driver bugs. R7 should target the installed Forward+ desktop renderer first and keep a legacy fallback.

2. `RenderingServer.create_local_rendering_device()` creates a separate RenderingDevice that can run draw/compute work off the main rendering device, but it cannot draw to the screen or share data with the global RenderingDevice. It also returns `null` under OpenGL or headless mode. `RenderingServer.get_rendering_device()` likewise returns `null` under OpenGL/headless. Therefore R7 compute probes must be windowed console runs, not `--headless`, and local-RD textures cannot be bound directly to RiverManager materials or saved resources. The compute backend must read final data back, then RiverManager should continue creating/binding/saving Godot `Texture2D` resources.

3. The basic compute sequence is: compile/create shader, create storage buffers/images and uniform sets, create a compute pipeline, begin a compute list, bind pipeline and uniform set, dispatch workgroups, end the list, submit, and synchronize only when data is needed. Shaders must bounds-check `gl_GlobalInvocationID` because dispatch groups commonly round up to cover texture dimensions.

4. Immediate `rd.sync()` after `rd.submit()` is documented as CPU/GPU blocking. The tutorial recommends waiting at least 2 or 3 frames before synchronizing when possible. R7 should avoid per-pass readback and avoid immediate sync inside the Jacobi loop; use one final readback or a small number of staged readbacks at result boundaries.

5. Long compute dispatches can trip Windows TDR on slow drivers. R7 should keep dispatches bounded, split long work into multiple dispatches if needed, and keep the existing 40 Jacobi iterations as separate or otherwise bounded dispatch work rather than one huge monolithic kernel.

6. `buffer_get_data()` and `texture_get_data()` block GPU progress while data is retrieved. Their async variants return data after a frame-queue delay and report the resource contents at request time. Large buffer/texture downloads can still be expensive. R7 should use readback only for final generated textures and validation/debug reductions, not for every intermediate pass.

7. `texture_get_data()` requires textures created with `TEXTURE_USAGE_CAN_COPY_FROM_BIT`; texture copies require the corresponding copy-from/copy-to usage bits. Storage-image compute outputs also need storage usage, and sampled inputs need sampling usage. R7 should create texture formats with explicit usage flags and fail early if `texture_is_format_supported_for_usage()` says the selected format is unavailable.

8. RIDs owned by RenderingDevice are not automatically freed when using the low-level API directly. R7 needs a single cleanup owner for every texture, buffer, shader, pipeline, sampler, and uniform set RID, and abort paths must call it idempotently.

9. General `barrier()` and `full_barrier()` are documented/no-op because RenderingDevice inserts broad barriers automatically. This does not remove `compute_list_add_barrier(compute_list)`: the installed 4.6.3 API docs describe it as raising a Vulkan compute barrier in the specified compute list. R7 should still use explicit ping-pong resources and validation to prove dispatch ordering, because stale reads can come from wrong resource binding, missing intra-list barriers, readback timing, or backend state reuse.

10. Device limits are hardware/driver dependent. R7 should log `limit_get()` values that matter to compute, especially workgroup count/size/invocations and push-constant size. Keep push constants under the common 128-byte limit unless device probing and review justify more.

## Planning Consequences

- R7 correctness, synchronization, and performance probes should be windowed console commands under the Forward+ renderer. Headless remains valid only for pure dictionary/property/API checks.
- The first compute backend should be local-RD owned behind the extracted baker, with final readback into normal Godot images/textures at the RiverManager result boundary.
- The low-cost fixture must exercise the projection path, not just `curve_only`. A blank-support fallback skips collision-support filters and the Jacobi branch, so the fixture needs a deliberately sized, layer-checked collider at `baking_resolution = 0` that produces collision hits without covering the whole bake.
- Baseline timing must record both bake elapsed time and editor heartbeat/frame gaps. A fast total time alone is not enough if the main thread stalls during sync/readback.
- Texture tolerance should be reviewable and per-texture. Textures unaffected by a compute slice must stay byte-identical; only textures generated by the migrated compute slice may use tolerance.
- The low-cost baseline fixture must prove `collision_hit_pixel_count > 0`, no support fallback, water occupancy, obstacle features, projected flow, the current eight public projection stride labels, and a separate internal `jacobi_pass_count=40`. Current code emits public labels once per stride group (`0/40`, `5/40`, ..., `35/40`), not once per Jacobi pass.

## Baseline Probe Implementation Notes - 2026-06-14

Official Godot 4.6 class references were checked again before adding the shipped baseline fixture/probe:

- `OS.get_cmdline_user_args()` reads user arguments after `--`, so `r7_legacy_canvas_item_bake_trace_probe.gd` uses `key=value` arguments after the script path for scene, river, output directory, warmup count, run count, and save mode.
- `Time.get_ticks_usec()` is a monotonic microsecond clock, so the probe uses it for bake elapsed time, progress timestamps, pass-trace durations, and heartbeat frame gaps.
- `SceneTree.process_frame` is available as a frame signal, so the probe waits across frames while `RiverManager.is_bake_in_progress()` is true and records responsiveness data without relying on headless timing.
- `ResourceSaver.save()` is intentionally not part of the default baseline path. The probe rejects `save=true` for this slice and verifies `bake_data.resource_path == ""`, keeping generated RiverBakeData resources out of shipped paths while still proving RiverManager result handoff.

The recorded baseline fixture/probe produced `R7_LEGACY_BASELINE_OK` with one warmup and five measured windowed runs. It exercises the expensive legacy projection workload and records the pass trace, texture hashes, metadata, settings, heartbeat, and RiverManager handoff under `.codex-research/r7-baselines/legacy/`.

## Installed Godot 4.6.3 Verification

Verified with `C:\Users\pc\Desktop\Godot_v4.6.3-stable\Godot_v4.6.3-stable_win64_console.exe` on 2026-06-14. Scratch artifacts were written under `.codex-research/r7-api*` and `.codex-research/godot-user-r7-review*`; no addon code, shipped probes, scenes, shaders, or bake resources were edited.

- API dump exact names/signatures:
  - `RenderingServer.create_local_rendering_device() -> RenderingDevice`
  - `RenderingServer.get_rendering_device() -> RenderingDevice`
  - `RenderingDevice.texture_is_format_supported_for_usage(format, usage_flags) -> bool`
  - `RenderingDevice.texture_get_data(texture, layer) -> PackedByteArray`
  - `RenderingDevice.texture_get_data_async(texture, layer, callback) -> Error`
  - `RenderingDevice.buffer_get_data(buffer, offset_bytes, size_bytes) -> PackedByteArray`
  - `RenderingDevice.buffer_get_data_async(buffer, callback, offset_bytes, size_bytes) -> Error`
  - `RenderingDevice.compute_list_add_barrier(compute_list) -> void`
  - `RenderingDevice.barrier(from, to) -> void` and `RenderingDevice.full_barrier() -> void`, both documented as doing nothing.
- Relevant enum names exist in 4.6.3: `DATA_FORMAT_R16G16B16A16_SFLOAT`, `DATA_FORMAT_R32G32B32A32_SFLOAT`, `TEXTURE_USAGE_STORAGE_BIT`, `TEXTURE_USAGE_SAMPLING_BIT`, `TEXTURE_USAGE_CAN_COPY_FROM_BIT`, `TEXTURE_USAGE_CAN_COPY_TO_BIT`, `UNIFORM_TYPE_IMAGE`, `UNIFORM_TYPE_SAMPLER_WITH_TEXTURE`, and `UNIFORM_TYPE_STORAGE_BUFFER`.
- Windowed Forward+ runtime check on this machine: Godot 4.6.3, Vulkan, AMD Radeon RX 6800 XT, global RD available, local RD available. `R16G16B16A16_SFLOAT` and `R32G32B32A32_SFLOAT` both reported supported for storage + sampling + copy-from + copy-to on local and global RD.
- Headless runtime check on the same binary: global RD unavailable and local RD unavailable, matching the official docs. Headless remains valid for pure dictionary/property checks, not compute validation.
- Reported limits on the RX 6800 XT local RD: push constant size 256 bytes, compute shared memory 32768 bytes, max compute workgroup invocations 1024, max workgroup size 1024/1024/1024. R7 should still log these per run because they are hardware/driver dependent.
- Godot `Image` exposes `FORMAT_RGBAH` and `FORMAT_RGBAF`; R7 format probes must verify conversion/readback into the final `ImageTexture.create_from_image()` path, not only storage-image support.

## Adversarial Review Re-check - 2026-06-14

The R7 plan was rechecked against the official Godot 4.6 docs and the installed 4.6.3 binary during the pre-implementation review. Official documentation still supports the recorded constraints: local RD cannot share data with the global RD and is unavailable in headless/OpenGL; global RD is also unavailable in headless/OpenGL; immediate `sync()` blocks CPU/GPU parallelism; `texture_get_data()` requires copy-from usage and blocks; async texture readback returns contents after the frame queue delay; and `free_rid()` ownership remains manual for low-level RD resources.

The scratch `.codex-research/r7_rd_runtime_check.gd` was rerun windowed and headless. Windowed Forward+/Vulkan on the AMD Radeon RX 6800 XT again reported local/global RD available and `R16G16B16A16_SFLOAT` plus `R32G32B32A32_SFLOAT` supported for storage/sampling/copy usage. Headless again reported local/global RD unavailable. This confirms capability on this machine only; it does not prove storage-image shader correctness, byte layout, readback conversion, or final `ImageTexture` behavior.

Review changes recorded in the plan/validation docs:

- The baseline fixture now needs a low-distortion pass trace, not only metadata, to prove the expensive projection workload actually ran.
- The default neutral-flow fixture must explicitly record `flow_speed_scaled=false` and `flow_speed_scale` pass count `0`; a non-neutral variant is required before migrating that pass.
- Collision coverage now has a minimum as well as a non-full maximum, so a one-pixel collider cannot make the legacy baseline look meaningful.
- Texture-format validation must include shader write/readback, bytes-to-`Image` conversion, `ImageTexture.create_from_image()`, and decoded flow/pressure metrics; `texture_is_format_supported_for_usage()` remains only a preflight.

## Validation-Only Probe Implementation Notes - 2026-06-14

Before adding the shipped validation probes, the installed Godot 4.6.3 API was rechecked with scratch introspection under `.codex-research/r7_api_introspection.gd`, and the official Godot 4.6 `RenderingDevice` and `Image` class references were rechecked.

Implementation-relevant findings confirmed for the probes:

- Installed `RDShaderSource.source_compute`, `RenderingDevice.shader_compile_spirv_from_source()`, `shader_create_from_spirv()`, `storage_buffer_create()`, `texture_create()`, `texture_get_data()`, `texture_get_data_async()`, `buffer_get_data()`, `buffer_get_data_async()`, and `compute_list_add_barrier()` are available in 4.6.3.
- Installed `RDTextureFormat` exposes `format`, `width`, `height`, `depth`, `array_layers`, `mipmaps`, `texture_type`, `samples`, and `usage_bits`, matching the production-style storage texture setup needed by R7.
- Installed `Image.create_from_data()` supports the final byte-to-`Image` path used by the format probe, and `ImageTexture.create_from_image()` completes the end-to-end texture handoff proof.
- Official docs state `buffer_get_data_async()` calls back after a frame-queue delay with data from the time of request. The recorded local probe attempted this API, but the callback did not arrive within 180 process frames, so async readback is not selected for the first production path.
- Official docs state `compute_list_add_barrier(compute_list)` raises a Vulkan compute barrier. The recorded local probe matched expected values with the barrier and did not match in the no-barrier report-only variant, so production code must use `compute_list_add_barrier()` when batching same-list dependent dispatches.
- Installed local RD printed `device already submitted, call sync to wait until done` when a development version tried repeated `submit()` calls without `sync()`. The recorded passing probe therefore uses the proven pattern: record all dependent compute lists, call `submit()` once, wait three process frames, call `sync()`, then read back.

Recorded shipped validation markers:

- `R7_TOLERANCE_SELF_COMPARE_OK`
- `R7_TEXTURE_FORMAT_ROUNDTRIP_OK`
- `R7_RENDERING_DEVICE_SYNC_OK`

## Production Skeleton Implementation Notes - 2026-06-14

Official Godot 4.6 documentation was rechecked immediately before adding the non-replacing backend skeleton:

- [RenderingServer.create_local_rendering_device()](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#class-renderingserver-method-create-local-rendering-device) creates a separate RenderingDevice for draw/compute work and cannot draw to the screen or share data with the global RenderingDevice. It returns `null` under OpenGL/headless, so the skeleton probe remains a windowed Forward+/Vulkan check.
- [RenderingDevice.texture_get_data() and texture copy usage notes](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html) still require `TEXTURE_USAGE_CAN_COPY_FROM_BIT` for texture retrieval, so the skeleton keeps RGBA16F/RGBA32F storage/sampling/copy usage preflight even though this first proof reads a storage buffer only.
- [Using compute shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/compute_shaders.html) still shows the local-RD compute flow: create a local RenderingDevice, create shader/pipeline/resources/uniform sets, record dispatches, submit, and synchronize when data is needed. The skeleton follows the already-proven R7 pattern: record separate ping-pong compute lists, submit once, wait three process frames, call `sync()`, and read back with `buffer_get_data()`.

Implementation consequence: `river_flowmap_compute_backend.gd` owns only local RenderingDevice setup, GPU resource RIDs, dispatch, sync/readback, and cleanup. `RiverFlowmapBaker` owns the backend instance and exposes only a non-replacing proof entry point. The proof path reports `production_output_replaced=false`, returns no output texture keys, avoids same-list read-after-write dependencies, and does not use async readback.

Recorded shipped validation markers:

- `R7_COMPUTE_BACKEND_SKELETON_OK`
- `R7_R6_SURFACE_PROPERTY_DIFF_OK`

## Isolated Solve/Filter Step Implementation Notes - 2026-06-14

Official Godot 4.6 documentation was rechecked immediately before adding the first isolated non-replacing solve/filter compute step:

- [RenderingDevice texture usage bits](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html) state that `TEXTURE_USAGE_STORAGE_BIT` allows use as a storage image, `TEXTURE_USAGE_CAN_COPY_FROM_BIT` is required for texture retrieval, and `TEXTURE_USAGE_CAN_COPY_TO_BIT` is available for copy destinations. The pressure-Jacobi proof therefore uses RGBA32F storage textures with the same storage/sampling/copy usage preflight shape already proven by R7.
- [RenderingDevice.texture_get_data()](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html#class-renderingdevice-method-texture-get-data) requires `TEXTURE_USAGE_CAN_COPY_FROM_BIT` and blocks the GPU while data is retrieved. The isolated step keeps readback report-only and uses it once at the validation boundary, not per production bake output replacement.
- [Using compute shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/compute_shaders.html) still recommends avoiding immediate `sync()` where possible and waiting at least 2 or 3 frames before synchronizing so GPU work can overlap CPU work. The step follows the recorded R7 delayed path: one compute list, one `submit()`, wait three process frames, `sync()`, then `texture_get_data()`.

Implementation consequence: `river_flowmap_compute_backend.gd` now owns one production-shaped pressure-Jacobi compute kernel behind `RiverFlowmapBaker`. It creates deterministic RGBA32F pressure, divergence, occupancy, and output storage textures; runs one Jacobi dispatch with solid-cell and atlas-column-wall handling; reads back the output through the proven delayed sync path; compares against a CPU reference; and discards the compute output. `r7_compute_solve_filter_step_probe.gd` first bakes the low-cost fixture through the legacy path and verifies all RiverManager texture IDs and hashes stay unchanged after the compute proof.

Follow-up confirmation recorded on 2026-06-14: the pressure-Jacobi compute shader and CPU reference were aligned with `flow_pressure_jacobi_pass.gdshader` and its includes, not just with each other. The proof now uses legacy pressure/divergence encodings, source-size UV stride (`stride / size`) on a padded texture, `atlas_column_clamp`'s 2% padding-wall behavior, y clamping without wall flagging, solid-cell pressure preservation, and Neumann wall/solid neighbor pressure. The probe also runs the same synthetic intermediate through `FilterRenderer.apply_flow_pressure_jacobi`; legacy shader parity passed with f16-sized pressure deltas while compute-vs-reference stayed at RGBA32F precision. This keeps the next expansion toward divergence/gradient/tangency anchored to the old shader semantics.

Recorded shipped validation markers:

- `R7_COMPUTE_SOLVE_FILTER_STEP_OK`
- `R7_R6_SURFACE_PROPERTY_DIFF_OK`

## Multi-Pass Pressure-Jacobi Stack Implementation Notes - 2026-06-14

Official Godot 4.6 documentation was rechecked immediately before expanding the one-step proof into the production-shaped pressure stack:

- [RenderingServer.create_local_rendering_device()](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#class-renderingserver-method-create-local-rendering-device) still describes a separate local RenderingDevice that cannot share resources with the global RenderingDevice and is unavailable under OpenGL/headless. The stack remains a windowed Forward+/Vulkan proof and reads data back instead of exposing local-RD textures to RiverManager.
- [RenderingDevice texture usage and readback notes](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html) still require storage usage for image writes and copy-from usage for `texture_get_data()`. The stack keeps RGBA32F storage/sampling/copy usage preflight and performs one final texture readback at the proof boundary.
- [Using compute shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/compute_shaders.html) still recommends avoiding immediate `sync()` where possible and waiting 2 or 3 frames before synchronization. The stack follows the R7 selected path: record compute work, `submit()` once, wait three process frames, call `sync()`, then read back once.
- The installed API exposes `compute_list_add_barrier(compute_list)`, and the recorded R7 sync probe already proved the barrier variant for same-list dependent dispatches. Because the stack batches 40 dependent ping-pong pressure dispatches into one compute list, it inserts a `compute_list_add_barrier()` between each read-after-write dependency. A future implementation that batches divergence, gradient subtract, or boundary tangency dependencies in one compute list must make the same barrier decision explicitly.

Implementation consequence: `river_flowmap_compute_backend.gd` now owns a non-replacing pressure stack behind `RiverFlowmapBaker` using two RGBA32F pressure storage textures plus divergence and occupancy storage textures. The proof uses the real low-cost fixture stride schedule `[32, 16, 8, 4, 2, 1, 1, 1]`, 5 iterations per stride, 40 dispatches, 39 intra-list compute barriers, one submit, delayed wait/sync/readback, and idempotent cleanup. `r7_compute_solve_filter_stack_probe.gd` compares the final pressure intermediate against a legacy shader multi-pass stack over the same deterministic fixture and verifies legacy RiverManager texture IDs and hashes stay unchanged.

The accepted stack gate is `R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1`, a pressure-intermediate tolerance for accumulated RGBA32F compute feedback versus legacy f16 shader feedback. It does not relax final generated texture `R7_TOLERANCE_V1`; the expanded diagnostic now proves the outer passes with captured legacy pressure, but the primary compute-pressure generated candidate still needs the generated-output gate before replacement.

Recorded shipped validation markers:

- `R7_COMPUTE_SOLVE_FILTER_STACK_OK`
- `R7_R6_SURFACE_PROPERTY_DIFF_OK`

## Expanded Projection Diagnostic Implementation Notes - 2026-06-14

Official Godot 4.6 documentation was rechecked before adding the non-replacing divergence/gradient/tangency projection diagnostic:

- [RenderingDevice texture usage bits](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html) document `TEXTURE_USAGE_SAMPLING_BIT`, `TEXTURE_USAGE_STORAGE_BIT`, and `TEXTURE_USAGE_CAN_COPY_FROM_BIT`; the projection diagnostic keeps all candidate textures local to the baker-owned RenderingDevice and uses storage/sampling/copy usage for write, sampled-read, and report-only readback.
- [RenderingDevice.sampler_create()](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html#class-renderingdevice-method-sampler-create) creates sampler RIDs from `RDSamplerState`. [RDSamplerState](https://docs.godotengine.org/en/4.6/classes/class_rdsamplerstate.html) exposes nearest/linear filter and clamp repeat properties; the diagnostic uses nearest samplers for flow/pressure/divergence/solid-mask reads and a linear occupancy sampler for boundary tangency proximity, matching the legacy filter descriptors.
- [Using compute shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/compute_shaders.html) still supports the local-RD pattern already selected for R7. The expanded projection path records all dependent dispatches, inserts `compute_list_add_barrier()` between read-after-write dependencies, submits once, waits three frames, calls `sync()`, and reads back with `texture_get_data()`.

Implementation consequence: `river_flowmap_compute_backend.gd` now has a non-replacing projection path that dispatches flow divergence, the 40-pass pressure stack, flow gradient subtract, and two boundary tangency passes in one compute list. It still returns no production output texture keys and writes nothing into RiverManager textures/resources. `r7_compute_solve_filter_stack_probe.gd` records two generated candidates: the primary compute-pressure path and a diagnostic that feeds captured legacy pressure into compute gradient/tangency.

Recorded result: the legacy-pressure diagnostic proves the outer compute passes, final combine, and baker postprocess under `R7_TOLERANCE_V1` (`generated_override_candidate_parity.ok=true`, p95/max decoded angle `0`, occupied R/G p99 `0`). The primary compute-pressure generated candidate still fails (`generated_candidate_parity.ok=false`, p95 angle `3.60344260089818 deg`, max angle `16.9067074883773 deg`, occupied R/G p99 `0.00784313678741`). This keeps replacement blocked and narrows the next investigation to accumulated pressure-feedback parity.

Recorded shipped validation markers:

- `R7_COMPUTE_SOLVE_FILTER_STACK_OK`
- `R7_COMPUTE_BACKEND_SKELETON_OK`
- `R7_R6_SURFACE_PROPERTY_DIFF_OK`

## Pressure-Feedback Drift Retry Notes - 2026-06-14

This retry kept the expanded projection diagnostic non-replacing and focused only on accumulated compute pressure feedback in the primary generated candidate. The latest clean report is `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`: `R7_COMPUTE_SOLVE_FILTER_STACK_OK` still records 44 dispatches, 43 `compute_list_add_barrier()` calls, one compute list, one submit, delayed wait/sync/readback, empty output texture keys, `production_output_replaced=false`, and async readback blocked.

Retained findings:

- Preserving source `flow_image` and `occupancy_image` as sampled RGBA8 when the source images are RGBA8 made the divergence stage exact and is a better match for the legacy inputs.
- Replacing one pressure-Jacobi shader variant per stride with a dynamic stride storage buffer kept the production path simpler without changing the non-replacing contract.
- Adding explicit `textureLod(..., 0.0)` for pressure, divergence, and occupancy reads was the only retained change that materially improved final generated-output drift: primary generated p95/max angle moved from `3.60344260089818/16.9067074883773 deg` to `3.48932145236808/12.4395520353247 deg`. Occupied G p99 remains `0.00784313678741`, and occupied R p99 is now `0.00392159819603`.
- Probe instrumentation now records signed channel deltas, max-delta coordinates, and captured legacy pressure by Jacobi pass count. The latest report shows the failure remains small in channel space, often one or two 8-bit steps after final combine, but still large enough to fail decoded flow-angle tolerance.

Rejected or reverted investigations:

- TexelFetch, tie-down, edge UV, conditional edge, small forward/reverse sample biases, pre-occupancy variants, and a half-like base-UV patch either moved the pass-6 mismatch or worsened final generated-output parity.
- Splitting compute lists, creating a fresh pressure texture per pass, RGBA32F projection pressure, linear pressure sampler variants, divergence scale `0.9/1.1`, 4 or 6 iterations per stride, candidate RGBA8 output, and tiny output/channel biases were not useful.
- A CPU replay of legacy pass 6 from captured pass 5 with floor/tie/linear/old-texture/source-size variants did not reproduce the legacy shader closely enough. This makes the remaining mismatch look more nuanced than a simple floor/ceil/tie or stale-texture rule.

Current interpretation: divergence, gradient subtract, boundary tangency, final combine, and postprocess are not the blocker because the captured legacy-pressure override still passes intermediate and generated-output `R7_TOLERANCE_V1`. The first useful pressure drift clue is the transition from the first five stride-32 passes into the first stride-16 pass on the 106-wide padded texture, where the effective 26.5-pixel offset makes canvas-shader sampler precision/tie behavior suspicious. Simple tie rules are insufficient.

## Legacy Pass-6 Canvas Sampler Diagnostic Notes - 2026-06-15

Official docs were spot-checked before adding the controlled legacy sampler diagnostic. The relevant implementation details are stable for this slice: CanvasItem `UV` is a normalized texture coordinate, `sampler2D` uniforms bind `Texture2D` values from GDScript, sampler uniform hints include `filter_nearest` and `repeat_disable`, and Godot `Image.FORMAT_RGBAH` is RGBA16F. This matches the legacy `FilterRenderer` path used by `flow_pressure_jacobi_pass.gdshader`: `ImageTexture` inputs, `filter_nearest` pressure/divergence/occupancy samplers, HDR 2D SubViewport output, and f16 pressure feedback.

The new report is `.codex-research/r7-baselines/compute-solve-stack-final/r7_compute_solve_filter_stack.txt`. It adds `legacy_pass6_sampler.*` fields from a one-pass controlled `FilterRenderer.apply_flow_pressure_jacobi` diagnostic at the first stride-16 transition (`pass_index=6`, `stride=16`, `source_size=64`, `texture=106x106`, `atlas_columns=5`). The diagnostic uses uniquely encoded pressure texels for up-neighbor, down-neighbor, and horizontal-wall center cases, with zero divergence and empty solid occupancy.

Recorded findings:

- The stride-16 offset is exactly `26.5` texels on the 106-wide padded texture.
- Horizontal stride-16 pressure reads are atlas-wall reads for all five probe points; the shader returned center pressure contribution exactly (`horizontal_wall_match_count=5`, max delta `0`).
- Vertical half-texel reads do not use one global tie rule. Up-neighbor choices split lower/upper `3/2`; down-neighbor choices also split lower/upper `3/2`.
- The current compute sampler model, `floor(clamp(uv, 0, 1) * texture_size)`, matched only `1/5` up-neighbor choices and `2/5` down-neighbor choices in the controlled pass.
- All controlled choice deltas were `0`, so the diagnostic is seeing exact legacy neighbor choices, not noisy inference from final generated flow.

Follow-up legacy correctness audit on 2026-06-15 added a 25-point vertical sampler grid. It kept exact zero-delta choices and showed the mixed behavior is mostly, but not perfectly, shaped like the ColorRect triangle split: `upper when point.x < point.y, otherwise lower` matched `22/25` up samples and `22/25` down samples. The mismatches were the same for up and down, at `(10, 63)`, `(31, 63)`, and `(53, 63)`, all choosing lower where the simple diagonal model predicted upper. The floor model matched only `10/25` up and `9/25` down. The follow-up report `.codex-research/r7-baselines/compute-solve-stack-legacy-audit-grid3/r7_compute_solve_filter_stack.txt` records the full `grid_up_choices` and `grid_down_choices` arrays for future model checks.

Canvas-tie diagnostic follow-up on 2026-06-15 added an opt-in `pressure_jacobi_canvas_tie_mode=1` candidate in the non-replacing backend. The candidate applies the simple diagonal tie bias only around exact stride-16 vertical half-texel pressure/occupancy samples and leaves the default path unchanged. It confirmed that tie handling matters, but did not solve replacement parity: generated p95 angle improved from `3.48932145236808 deg` to `3.02500924801543 deg` and weighted mean improved from `0.76174545540638 deg` to `0.60170081393187 deg`, while p99/max angle worsened from `5.48129340327964/12.4395520353247 deg` to `5.96108559105589/18.2393832633789 deg`. Occupied R/G p99 failures remained unchanged. Treat this as evidence for a more renderer-grounded sampler model, not a production rule.

Source-edge follow-up on 2026-06-15 added dense scanline and y-band diagnostics to `.codex-research/r7-baselines/compute-solve-stack-source-edge-final/r7_compute_solve_filter_stack.txt`. The controlled pass-6 tables are exactly explained by `upper when point.x < point.y except source_size - 1 row, otherwise lower`: grid `25/25`, scanline `95/95`, y-band `209/209`, for both up and down. An opt-in `pressure_jacobi_canvas_tie_mode=2` candidate tested that source-edge exception beside the unchanged primary path. It improved broad drift again (`p95=2.81378265972502 deg`, weighted mean `0.51408882340789 deg`) but did not satisfy the tail-focused acceptance concern: p99 stayed worse than primary at `5.71058370749061 deg`, max stayed `18.2393832633789 deg`, angle-over-10 count rose to `7`, and occupied G/R p99 remained `0.00784313678741`/`0.00392159819603`. Keep mode `2` diagnostic-only; it proves a controlled sampler model, not replacement readiness.

Pass-prefix follow-up on 2026-06-15 added diagnostic-only pressure prefix comparisons to `.codex-research/r7-baselines/compute-solve-stack-prefix-diagnostic/r7_compute_solve_filter_stack.txt`. The backend now accepts an opt-in `pressure_jacobi_pass_limit` for probe runs, but full projection runs still report `pressure_jacobi_pass_limited=false`; the pass limit is not a production behavior. The diagnostic compares primary mode 0, diagonal mode 1, and source-edge mode 2 against legacy pressure after pass counts `[5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]`.

Pass-prefix interpretation: pass 5 is clean for all modes. Primary mode 0 first fails at pass 6, stride 16 iteration 1 (`occupied_r_p99_abs=0.18359375`) and peaks at pass 10 (`occupied_r_p99_abs=0.30126953125`), which explains the broad primary drift. Modes 1/2 suppress broad stride-16 p99 drift but retain local max errors from pass 6, fail p99 by pass 8, and peak p99 at pass 15. The primary generated max target `(82, 47)` corresponds to a mode-0 pressure delta `2.140625` at pass 15; modes 1/2 fix that point but leave the generated max at `(61, 67)`, where the pressure delta is `0.3671875` at pass 20. Mode 2 also shifts occupied G/R failure clusters into tile 5 `(42, 63)`. This supports an over-application/tile-edge hypothesis for source-edge mode rather than acceptance of the source-edge rule.

Current interpretation before the `FRAGCOORD` confirmation: the remaining pressure-feedback drift is not explained by a uniform floor, ceil, tie-up, tie-down, small global UV bias, one safe diagonal rule, or the source-edge row exception alone. The legacy pressure shader's intended stencil remains coherent; the mixed half-texel behavior is a canvas-renderer artifact with unproven visual consequence. Do not hard-code or promote the simple diagonal or source-edge rule, and keep legacy p99/max angle plus occupied channel gates as diagnostics rather than relaxing them.

## Probe-Only FRAGCOORD Diagnostic Notes - 2026-06-15

Official CanvasItem shader docs were rechecked for the architecture pivot. They describe `UV` as texture coordinates passed from vertex to fragment interpolation, and `FRAGCOORD.xy` as the current pixel center in viewport space. The docs do not define exact nearest half-texel tie behavior. Installed Godot 4.6.3 accepted the probe shader only after the `FRAGCOORD` reference was made directly from `fragment()` scope and passed into a helper; referencing it inside a global helper body failed shader compilation.

The accepted report is `.codex-research/r7-baselines/compute-solve-stack-fragcoord-diagnostic/r7_compute_solve_filter_stack.txt`. It adds `res://addons/waterways/probes/r7_flow_pressure_jacobi_fragcoord_probe.gdshader`, a probe-only variant of `flow_pressure_jacobi_pass.gdshader` that derives the base texel center from `FRAGCOORD` instead of interpolated CanvasItem `UV`.

Recorded result: `legacy_pass6_sampler.fragcoord_uv_artifact_hypothesis_supported=true`. The legacy UV y-band cases had 20 total X-dependent transitions, while the `FRAGCOORD` variant had 0. This is strong evidence that the controlled pass-6 mixed lower/upper pattern depends on interpolated CanvasItem UV behavior, not intended Jacobi math.

Caution: the `FRAGCOORD` variant did not become a uniform canonical compute-floor rule (`fragcoord_y_band_compute_model_match_delta=-36`). It collapses the X-transition artifact but still exposes renderer/tie details. Therefore the architecture decision is to stop chasing legacy sampler artifacts and move to a canonical texel-space compute solver, not to promote a new legacy-compatibility tie rule.

Updated interpretation: compute pressure feedback is the canonical solver target. Legacy CanvasItem parity remains diagnostic and fallback evidence. Replacement needs `R7_COMPUTE_CANONICAL_ACCEPTANCE_V1`: canonical texel-space rules, named visual evidence, physics/semantic validation, fallback selection, unchanged RiverManager ownership, and an explicit bake signature/version decision if generated textures change.

## Replacement Staging Documentation Re-check - 2026-06-15

Official stable Godot documentation was rechecked before adding the generated-output replacement staging report. The implementation-relevant constraints remain unchanged for this slice:

- `RenderingDevice.sync()` synchronizes CPU and GPU work and has a performance cost, and the class reference says it can only be called after `submit()`. The staging probe therefore keeps the established delayed single-submit/wait-3-frames/sync/readback sequence and does not add per-texture or per-pass sync calls.
- Local RenderingDevice frame queue count is one frame. The staging proof keeps all candidate data report-only, reads back after the already-proven wait/sync boundary, and does not assume longer queued local-RD overlap.
- The compute-shader tutorial still notes that RenderingDevice RIDs must be freed manually. Staging reuses the existing backend cleanup path and verifies zero owned RIDs plus a released local RenderingDevice after the non-replacing compute run.
- The staging report does not introduce new RenderingDevice APIs, async readback, or production texture replacement. It only documents what `canonical_compute_replacing` would replace: `flow_foam_noise.rg` from canonical compute, with `flow_foam_noise.ba` and all other generated textures legacy-sourced.

Recorded result: `.codex-research/r7-baselines/compute-generated-output-replacement-staging/r7_compute_generated_output_replacement_staging.txt` contains `R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK`. The staged low-cost `flow_foam_noise` hash would change from `3bfadac449d094f0bd603f8549f8de9e` to `a5ee9d4f0e7585ca1dc67d3c72c26a49`, but actual RiverManager state and generated texture hashes remain unchanged, `production_output_replaced=false`, and source signature version is now 29.

## Production Replacement Validation Documentation Re-check - 2026-06-15

Official stable Godot documentation was rechecked before adding the report-only production replacement validation probe. The implementation-relevant constraints remain the same as the staging slice:

- The compute-shader tutorial still supports the selected local-RD flow: record dispatches, `submit()`, wait a few frames when possible, then synchronize when data is needed.
- `RenderingDevice.texture_get_data()` still requires copy-from texture usage and blocks while data is retrieved, so production validation keeps one final delayed readback boundary and does not add per-pass or per-texture sync calls.
- `Image.create_from_data()` plus `ImageTexture.create_from_image()` remain the final CPU image/texture handoff path after readback. This supports keeping RiverManager as the owner of generated `Texture2D` resources instead of trying to share local-RD textures with material bindings.
- The existing manual-RID cleanup requirement still applies. Production validation reuses the non-replacing backend cleanup path and records unchanged live RiverManager texture state/hashes.

Recorded result: `.codex-research/r7-baselines/compute-production-replacement-validation/r7_compute_production_replacement_validation.txt` contains refreshed `R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK`. The report-only handoff would give RiverManager a canonical `flow_foam_noise_texture` candidate while keeping the other generated texture fields legacy-sourced; actual generated output remains unchanged and `production_output_replaced=false`. Source signature policy is accepted as version 29, the gated replacement branch is implemented, the supplied-evidence gate has no blockers, and the direct runtime smoke keeps delayed single-submit/wait-3-frames/sync/`texture_get_data()` readback while reporting only `flow_foam_noise`.

## Source Signature And Replacement Branch Notes - 2026-06-15

Official Godot constraints did not change for the source-signature/replacement-code slice. The implementation keeps the local RenderingDevice branch behind the baker, keeps the proven delayed single-submit/wait/sync/readback path, and does not introduce async readback. The source signature policy uses `RIVER_BAKE_SOURCE_SIGNATURE_VERSION=29` rather than backend-mode signature keying because `flowmap_backend_mode` remains an internal baker selection/gate input, not a RiverManager source-setting surface.

## Broader Promotion Fixture Coverage Notes - 2026-06-15

No new RenderingDevice or Godot API surface was introduced for broader coverage. The new probe reuses the production replacement validation path and only widens the fixture set: the low-cost fixture, `res://Demo.tscn`, and `res://Demo_obstacle_flow_test.tscn`. All runs keep the already-proven local RenderingDevice pattern: one compute submit, wait three frames, `sync()`, `texture_get_data()`, 44 dispatches, 43 compute barriers, and no async readback.

Recorded result: `.codex-research/r7-baselines/compute-promotion-fixture-coverage/r7_compute_promotion_fixture_coverage.txt` contains `R7_COMPUTE_PROMOTION_FIXTURE_COVERAGE_OK`. The report confirms each fixture exercises the projected obstacle path at source signature version 29 and that explicit supplied-evidence `canonical_compute_replacing` reports runtime `output_texture_keys=["flow_foam_noise"]` only. The texture-scope proof remains unchanged from staging/production validation: canonical compute migrates only `flow_foam_noise.r/g`, while `flow_foam_noise.b/a` and all other generated textures/channels remain legacy-sourced.

Policy consequence: broader coverage is accepted for the explicit gated branch. That report kept `legacy_canvas_item` as the code default at the time, but the later saved-output promotion and switched/default compute acceptance now make `canonical_compute_replacing` the non-explicit default solve path.

## Saved-Output Promotion Notes - 2026-06-15

No new RenderingDevice or Godot API surface was introduced for saved-output promotion. The probe reuses the accepted explicit gated replacement path, the established delayed single-submit/wait-3-frames/sync/`texture_get_data()` readback, and Godot `ResourceSaver.save()` with the existing external river bake resource path. It also adds a same-signature comparison step: each authored scene is first rebaked through legacy v29 without saving, then rebaked through explicit gated `canonical_compute_replacing` and saved only to the scoped river bake resource.

Recorded result: `.codex-research/r7-baselines/compute-saved-output-promotion/r7_compute_saved_output_promotion.txt` contains `R7_COMPUTE_SAVED_OUTPUT_PROMOTION_OK`. The report records the deliberate pre-promotion-to-promoted texture hash changes for `res://waterways_bakes/Demo/Water_River.river_bake.res` and `res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res`. Relative to the same-signature legacy v29 baseline, only `flow_foam_noise` changes; its `r/g` channels are compute-migrated and its `b/a` channels remain byte-identical. All other generated textures remain legacy-sourced and hash-identical to legacy v29, WaterSystem resources are unchanged, backend mode remains outside the source signature, and the current code default backend is the accepted `canonical_compute_replacing` solve path.

## Backend Performance Comparison Notes - 2026-06-15

No new RenderingDevice or Godot API surface was introduced for the backend performance comparison. The probe reuses the accepted explicit backend selection surface, the established delayed single-submit/wait-3-frames/sync/`texture_get_data()` readback for compute, and the existing `progress_notified`/process-frame heartbeat timing method from the R7 baseline work.

Recorded result: `.codex-research/r7-baselines/compute-backend-performance-compare/r7_compute_backend_performance_compare.txt` contains `R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK`. The same harness requests `legacy_canvas_item` and `canonical_compute_replacing` on the low-cost fixture, `res://Demo_obstacle_flow_test.tscn`, and `res://Demo.tscn`. No fallback occurred. Compute was faster in all recorded cases: low-cost `1044.678 ms` versus legacy `2510.612 ms`, obstacle Demo `70597.861 ms` versus legacy `71726.023 ms`, and Demo `127139.944 ms` versus legacy `128334.516 ms`. Full authored scenes still exceeded 1000 ms frame gaps in both backends, which keeps full-scene responsiveness as a shared bake-workload concern rather than a compute-only API issue.

## Open Implementation Research

- Confirm actual 4.6.3 device support for candidate storage-image formats on the user's GPU before full generated-output replacement. Recorded 2026-06-14: both `DATA_FORMAT_R16G16B16A16_SFLOAT` and `DATA_FORMAT_R32G32B32A32_SFLOAT` passed storage/sampling/copy usage plus shader write/imageLoad/readback/Image/ImageTexture semantic metrics on AMD Radeon RX 6800 XT; the first isolated pressure-Jacobi step uses RGBA32F for CPU-reference accuracy.
- Decide whether future replacement reads final textures via `texture_get_data_async()` or delayed `submit()`/`sync()` plus `texture_get_data()`. Recorded 2026-06-14: choose delayed single-submit/wait/sync/readback for the first production path; async buffer readback did not call back within 180 frames and remains unselected. The non-replacing skeleton uses the same delayed path with `buffer_get_data()`, and the isolated pressure-Jacobi step uses it with `texture_get_data()`.
- Verify whether any diagnostic currently parsed by probes must move to a GPU reduction or remain CPU-side until later. Do not remove diagnostic marker text without migrating consumers.
- Verify whether future final replacement can use the same single-list barrier strategy or should split dispatches for maintainability/performance. Recorded 2026-06-14: the pressure-Jacobi stack batches 40 dependent ping-pong dispatches in one compute list with 39 `compute_list_add_barrier()` calls; the expanded projection diagnostic batches divergence + 40 Jacobi + gradient + 2 tangency dispatches in one compute list with 43 `compute_list_add_barrier()` calls.
