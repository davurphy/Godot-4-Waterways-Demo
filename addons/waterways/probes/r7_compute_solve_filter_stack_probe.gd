# River-refactor R7 non-replacing production-shaped pressure-Jacobi stack probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_solve_filter_stack_probe.gd -- out=res://.codex-research/r7-baselines/compute-solve-stack
#
# Success marker: R7_COMPUTE_SOLVE_FILTER_STACK_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverFlowmapComputeBackend = preload("res://addons/waterways/river_flowmap_compute_backend.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")
const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const DEFAULT_SCENE := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-solve-stack"
const REPORT_FILE_NAME := "r7_compute_solve_filter_stack.txt"
const FILTER_RENDERER_SCENE := "res://addons/waterways/filter_renderer.tscn"
const FRAGCOORD_PRESSURE_JACOBI_PROBE_SHADER_PATH := "res://addons/waterways/probes/r7_flow_pressure_jacobi_fragcoord_probe.gdshader"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 2400
const FLOW_SOLVE_PRESSURE_SCALE := 0.03125
const FLOW_SOLVE_DIV_SCALE := 0.25
const FLOW_MAGNITUDE_MIN := 0.05
const FLOW_AUDIT_LOW_MAGNITUDE_MAX := 0.10
const FLOW_AUDIT_STRONG_MAGNITUDE_MIN := 0.20
const FLOW_AUDIT_EDGE_BAND_PIXELS := 1
const FLOW_AUDIT_CONFIDENCE_EDGE_BAND_PIXELS := 2
const CANONICAL_DIVERGENCE_MAX_RATIO_GATE := 1.50
const CANONICAL_SOLID_FLOW_MAX_GATE := 0.001
const CANONICAL_BOUNDARY_INTO_SOLID_MAX_GATE := 0.10
const CANONICAL_FLOW_MAGNITUDE_MAX_GATE := 1.5
const DEFAULT_STRIDE_SCHEDULE := [32, 16, 8, 4, 2, 1, 1, 1]
const PASS6_SAMPLER_DIAGNOSTIC_STRIDE := 16
const PASS6_SAMPLER_DIAGNOSTIC_PASS_INDEX := 6
const PASS6_SAMPLER_SCANLINE_X_COUNT := 21
const PASS6_PRESSURE_POINT_OFFSET_STEP := 0.1875
const PASS6_SAMPLER_Y_BAND_MIN := 55
const PASS6_SAMPLER_Y_BAND_MAX := 75
const PASS6_SAMPLER_Y_BAND_STEP := 2
const PRESSURE_PREFIX_DIAGNOSTIC_PASS_COUNTS := [5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40]
const CHANNEL_FAILURE_GATE := 0.006
const CHANNEL_FAILURE_HIGH_GATE := 0.010
const FAILURE_RECORD_LIMIT := 8
const CHANNEL_NAMES := ["r", "g", "b", "a"]
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

class R7CaptureBaker:
	extends RiverFlowmapBaker

	var trace_owner: Object = null
	var captured := {}

	func _run_renderer_pass(label: String, renderer_instance: Object, method_name: String, args: Array) -> Dictionary:
		if trace_owner != null and trace_owner.has_method("_record_legacy_pass_inputs"):
			trace_owner.call("_record_legacy_pass_inputs", label, args)
		var result: Dictionary = await super._run_renderer_pass(label, renderer_instance, method_name, args)
		if trace_owner != null and trace_owner.has_method("_record_legacy_pass_output"):
			trace_owner.call("_record_legacy_pass_output", label, result)
		return result

var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _progress := PackedStringArray()
var _report_lines := PackedStringArray()
var _written_report := ""
var _legacy_projection_capture := {}
var _canonical_acceptance_automated_ok := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var texture_width := maxi(4, int(args.get("texture_width", "106")))
	var texture_height := maxi(4, int(args.get("texture_height", "106")))
	var source_size := maxf(1.0, float(args.get("source_size", "64.0")))
	var atlas_columns := maxi(1, int(args.get("atlas_columns", "5")))
	var fixture_seed := int(args.get("fixture_seed", "97"))
	var iterations_per_stride := maxi(1, int(args.get("iterations_per_stride", "5")))
	var stride_schedule := _parse_int_list(String(args.get("strides", "")), DEFAULT_STRIDE_SCHEDULE)

	_report_lines.append("R7_COMPUTE_SOLVE_FILTER_STACK_DUMP v1")
	_report_lines.append("scene=" + scene_path)
	_report_lines.append("river=" + river_path)
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())

	var fixture := _load_fixture(scene_path)
	var river := fixture.get_node_or_null(river_path) if fixture != null else null
	_expect(river != null, "R7 low-cost fixture river was not found at " + river_path + ".")
	if river != null:
		_configure_fixture_river(river)
		var legacy_ok := await _run_legacy_bake(river)
		_expect(legacy_ok, "Legacy fixture bake did not complete before compute stack comparison.")
	var legacy_before_state := _river_output_state(river)
	var legacy_before_hashes := _river_texture_hashes(river)
	_report_lines.append("legacy_before_state=" + str(legacy_before_state))
	_report_lines.append("legacy_before_hashes=" + str(legacy_before_hashes))

	var compute_config := {
		"frame_wait_source": self,
		"warning_callback": Callable(self, "_record_warning"),
		"texture_width": texture_width,
		"texture_height": texture_height,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"fixture_seed": fixture_seed,
		"flow_projection_strides": stride_schedule.duplicate(),
		"flow_projection_iterations_per_stride": iterations_per_stride,
		"sync_wait_frames": 3
	}
	var baker := RiverFlowmapBaker.new()
	var compute_result: Dictionary = await baker.run_non_replacing_compute_solve_filter_stack_probe(
		compute_config,
		Callable(self, "_record_progress")
	)
	baker.cleanup()
	baker.abort()
	baker.cleanup()
	var legacy_stack := await _run_legacy_pressure_jacobi_stack_parity(compute_config)
	var legacy_pass6_sampler := await _run_legacy_pressure_jacobi_pass6_sampler_diagnostic(compute_config)
	var stack_parity := _compare_compute_to_legacy_stack(compute_result, legacy_stack)
	var projection_config := _make_projection_compute_config(compute_config)
	var projection_baker := RiverFlowmapBaker.new()
	var projection_result: Dictionary = await projection_baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_config,
		Callable(self, "_record_progress")
	)
	projection_baker.cleanup()
	projection_baker.abort()
	projection_baker.cleanup()
	var projection_parity := _compare_projection_candidate(projection_result)
	var generated_candidate_parity := await _compare_generated_flow_candidate(projection_result, river)
	var projection_canvas_tie_config := _make_projection_compute_config(compute_config)
	projection_canvas_tie_config["pressure_jacobi_canvas_tie_mode"] = 1
	var projection_canvas_tie_baker := RiverFlowmapBaker.new()
	var projection_canvas_tie_result: Dictionary = await projection_canvas_tie_baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_canvas_tie_config,
		Callable(self, "_record_progress")
	)
	projection_canvas_tie_baker.cleanup()
	projection_canvas_tie_baker.abort()
	projection_canvas_tie_baker.cleanup()
	var projection_canvas_tie_parity := _compare_projection_candidate(projection_canvas_tie_result)
	var generated_canvas_tie_candidate_parity := await _compare_generated_flow_candidate(projection_canvas_tie_result, river)
	var projection_canvas_tie_source_edge_config := _make_projection_compute_config(compute_config)
	projection_canvas_tie_source_edge_config["pressure_jacobi_canvas_tie_mode"] = 2
	var projection_canvas_tie_source_edge_baker := RiverFlowmapBaker.new()
	var projection_canvas_tie_source_edge_result: Dictionary = await projection_canvas_tie_source_edge_baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_canvas_tie_source_edge_config,
		Callable(self, "_record_progress")
	)
	projection_canvas_tie_source_edge_baker.cleanup()
	projection_canvas_tie_source_edge_baker.abort()
	projection_canvas_tie_source_edge_baker.cleanup()
	var projection_canvas_tie_source_edge_parity := _compare_projection_candidate(projection_canvas_tie_source_edge_result)
	var generated_canvas_tie_source_edge_candidate_parity := await _compare_generated_flow_candidate(projection_canvas_tie_source_edge_result, river)
	var pressure_prefix_diagnostic := await _run_pressure_prefix_diagnostic(compute_config)
	var projection_override_config := _make_projection_compute_config(compute_config, true)
	var projection_override_baker := RiverFlowmapBaker.new()
	var projection_override_result: Dictionary = await projection_override_baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_override_config,
		Callable(self, "_record_progress")
	)
	projection_override_baker.cleanup()
	projection_override_baker.abort()
	projection_override_baker.cleanup()
	var projection_override_parity := _compare_projection_candidate(projection_override_result)
	var generated_override_candidate_parity := await _compare_generated_flow_candidate(projection_override_result, river)
	var canonical_acceptance := _run_canonical_compute_acceptance_v1(projection_result, generated_candidate_parity, river, out_dir)

	var legacy_after_state := _river_output_state(river)
	var legacy_after_hashes := _river_texture_hashes(river)
	_report_lines.append("legacy_after_state=" + str(legacy_after_state))
	_report_lines.append("legacy_after_hashes=" + str(legacy_after_hashes))
	_append_result("compute", compute_result)
	_append_result("legacy_stack", legacy_stack)
	_append_result("legacy_pass6_sampler", legacy_pass6_sampler)
	_append_result("stack_parity", stack_parity)
	_append_result("projection_compute", projection_result)
	_append_result("projection_parity", projection_parity)
	_append_result("generated_candidate_parity", generated_candidate_parity)
	_append_result("projection_canvas_tie_compute", projection_canvas_tie_result)
	_append_result("projection_canvas_tie_parity", projection_canvas_tie_parity)
	_append_result("generated_canvas_tie_candidate_parity", generated_canvas_tie_candidate_parity)
	_append_result("projection_canvas_tie_source_edge_compute", projection_canvas_tie_source_edge_result)
	_append_result("projection_canvas_tie_source_edge_parity", projection_canvas_tie_source_edge_parity)
	_append_result("generated_canvas_tie_source_edge_candidate_parity", generated_canvas_tie_source_edge_candidate_parity)
	_append_result("pressure_prefix_diagnostic", pressure_prefix_diagnostic)
	_append_result("projection_override_compute", projection_override_result)
	_append_result("projection_override_parity", projection_override_parity)
	_append_result("generated_override_candidate_parity", generated_override_candidate_parity)
	_append_result("canonical_acceptance", canonical_acceptance)
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("progress=" + str(_progress))

	var expected_pass_count := stride_schedule.size() * iterations_per_stride
	_expect(bool(compute_result.get("ok", false)), "Compute solve/filter stack did not return ok=true: " + str(compute_result))
	_expect(String(compute_result.get("mode", "")) == "non_replacing_solve_filter_stack", "Compute stack did not report non_replacing_solve_filter_stack.")
	_expect(String(compute_result.get("stack_stage", "")) == "flow_pressure_jacobi_stack", "Compute stack did not report flow_pressure_jacobi_stack.")
	_expect(String(compute_result.get("reference", "")) == "cpu_legacy_uv_pressure_jacobi_stack_v1", "Compute stack did not report the stack CPU reference.")
	_expect(not bool(compute_result.get("production_output_replaced", true)), "Compute stack must not replace production bake output.")
	_expect(_output_texture_key_count(compute_result) == 0, "Compute stack returned output texture keys before replacement is allowed.")
	_expect(not bool(compute_result.get("async_readback_selected", true)), "Compute stack selected async readback.")
	_expect(String(compute_result.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, "Compute stack did not report delayed texture readback.")
	_expect(int(compute_result.get("submit_count", 0)) == 1, "Compute stack should use one submit for this proof path.")
	_expect(int(compute_result.get("compute_lists_recorded", 0)) == 1, "Compute stack should batch dependent dispatches into one compute list for the barrier proof.")
	_expect(int(compute_result.get("dispatch_count", 0)) == expected_pass_count, "Compute stack did not record the expected Jacobi dispatch count.")
	_expect(int(compute_result.get("jacobi_pass_count", 0)) == expected_pass_count, "Compute stack did not report the expected Jacobi pass count.")
	_expect(int(compute_result.get("pressure_ping_pong_texture_count", 0)) == 2, "Compute stack did not report two pressure ping-pong textures.")
	_expect(bool(compute_result.get("same_list_read_after_write_dependencies", false)), "Compute stack should report same-list dependencies for this barrier proof.")
	_expect(bool(compute_result.get("intra_list_barriers_required", false)), "Compute stack should report required intra-list barriers.")
	_expect(int(compute_result.get("compute_barrier_count", 0)) == expected_pass_count - 1, "Compute stack did not report one barrier between each dependent dispatch.")
	_expect(bool(compute_result.get("solve_rgba32f_supported", false)), "Compute stack did not confirm RGBA32F storage texture support.")
	_expect(int(compute_result.get("fixture_active_pixels", 0)) > 0, "Compute stack fixture did not exercise active fluid pixels.")
	_expect(int(compute_result.get("fixture_solid_pixels", 0)) > 0, "Compute stack fixture did not exercise solid occupancy pixels.")
	_expect(int(compute_result.get("fixture_wall_neighbor_cases", 0)) > 0, "Compute stack fixture did not exercise atlas wall neighbors.")
	_expect(int(compute_result.get("fixture_cross_column_wall_neighbor_cases", 0)) > 0, "Compute stack fixture did not exercise cross-column atlas wall neighbors.")
	_expect(int(compute_result.get("fixture_padding_wall_neighbor_cases", 0)) > 0, "Compute stack fixture did not exercise legacy atlas padding wall neighbors.")
	_expect(int(compute_result.get("fixture_solid_neighbor_cases", 0)) > 0, "Compute stack fixture did not exercise solid neighbors.")
	_expect(int(compute_result.get("metric_sample_count", 0)) == texture_width * texture_height, "Compute stack CPU diagnostic did not cover the full pressure texture.")
	_expect(bool(compute_result.get("cleanup_completed", false)), "Compute stack did not report cleanup completion.")
	_expect(bool(legacy_stack.get("ok", false)), "Legacy shader Jacobi stack parity failed: " + str(legacy_stack))
	_expect(int(legacy_stack.get("jacobi_pass_count", 0)) == expected_pass_count, "Legacy shader stack did not run the expected Jacobi pass count.")
	_expect(bool(legacy_pass6_sampler.get("ok", false)), "Legacy pass-6 sampler diagnostic failed to run: " + str(legacy_pass6_sampler))
	_expect(int(legacy_pass6_sampler.get("pass_index", 0)) == PASS6_SAMPLER_DIAGNOSTIC_PASS_INDEX, "Legacy pass-6 sampler diagnostic used the wrong pass index.")
	_expect(int(legacy_pass6_sampler.get("stride", 0)) == PASS6_SAMPLER_DIAGNOSTIC_STRIDE, "Legacy pass-6 sampler diagnostic used the wrong stride.")
	_expect(bool(stack_parity.get("ok", false)), "Compute-vs-legacy shader stack parity failed: " + str(stack_parity))
	_expect(float(stack_parity.get("metric_encoded_max_abs", 1.0)) <= 0.04, "Compute-vs-legacy encoded stack max delta exceeded the parity gate.")
	_expect(float(stack_parity.get("metric_pressure_max_abs", 1.0)) <= 1.3, "Compute-vs-legacy decoded stack max delta exceeded the parity gate.")
	_expect(bool(projection_result.get("ok", false)), "Compute solve/filter projection did not return ok=true: " + str(projection_result))
	_expect(String(projection_result.get("mode", "")) == "non_replacing_solve_filter_projection", "Projection compute did not report non_replacing_solve_filter_projection.")
	_expect(String(projection_result.get("stack_stage", "")) == "flow_divergence_pressure_gradient_tangency", "Projection compute did not report the expanded solve/filter stack.")
	_expect(not bool(projection_result.get("production_output_replaced", true)), "Projection compute must not replace production bake output.")
	_expect(_output_texture_key_count(projection_result) == 0, "Projection compute returned output texture keys before replacement is allowed.")
	_expect(not bool(projection_result.get("async_readback_selected", true)), "Projection compute selected async readback.")
	_expect(String(projection_result.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, "Projection compute did not report delayed texture readback.")
	_expect(int(projection_result.get("submit_count", 0)) == 1, "Projection compute should use one submit for this proof path.")
	_expect(int(projection_result.get("compute_lists_recorded", 0)) == 1, "Projection compute should batch dependent dispatches into one compute list for this barrier proof.")
	_expect(int(projection_result.get("jacobi_pass_count", 0)) == expected_pass_count, "Projection compute did not report the expected Jacobi pass count.")
	_expect(int(projection_result.get("dispatch_count", 0)) == expected_pass_count + 4, "Projection compute did not dispatch divergence + Jacobi stack + gradient + two tangency passes.")
	_expect(int(projection_result.get("compute_barrier_count", 0)) == int(projection_result.get("dispatch_count", 0)) - 1, "Projection compute did not report one barrier between each dependent dispatch.")
	_expect(int(projection_result.get("divergence_dispatch_count", 0)) == 1, "Projection compute did not dispatch divergence once.")
	_expect(int(projection_result.get("gradient_subtract_dispatch_count", 0)) == 1, "Projection compute did not dispatch gradient subtract once.")
	_expect(int(projection_result.get("tangency_pass_count", 0)) == 2, "Projection compute did not dispatch two boundary tangency passes.")
	_expect(bool(projection_result.get("cleanup_completed", false)), "Projection compute did not report cleanup completion.")
	_expect(not bool(projection_result.get("pressure_override_used", false)), "Primary projection compute unexpectedly used the legacy pressure override.")
	_expect(bool(projection_result.get("pressure_stack_candidate_computed", false)), "Projection compute did not report a computed pressure stack candidate.")
	_expect(bool(projection_canvas_tie_result.get("ok", false)), "Canvas-tie pressure diagnostic did not return ok=true: " + str(projection_canvas_tie_result))
	_expect(int(projection_canvas_tie_result.get("pressure_jacobi_canvas_tie_mode", 0)) == 1, "Canvas-tie pressure diagnostic did not report pressure_jacobi_canvas_tie_mode=1.")
	_expect(not bool(projection_canvas_tie_result.get("production_output_replaced", true)), "Canvas-tie pressure diagnostic must not replace production bake output.")
	_expect(_output_texture_key_count(projection_canvas_tie_result) == 0, "Canvas-tie pressure diagnostic returned output texture keys before replacement is allowed.")
	_expect(not bool(projection_canvas_tie_result.get("async_readback_selected", true)), "Canvas-tie pressure diagnostic selected async readback.")
	_expect(int(projection_canvas_tie_result.get("dispatch_count", 0)) == expected_pass_count + 4, "Canvas-tie pressure diagnostic did not dispatch the expanded stack.")
	_expect(bool(projection_canvas_tie_source_edge_result.get("ok", false)), "Canvas-tie source-edge pressure diagnostic did not return ok=true: " + str(projection_canvas_tie_source_edge_result))
	_expect(int(projection_canvas_tie_source_edge_result.get("pressure_jacobi_canvas_tie_mode", 0)) == 2, "Canvas-tie source-edge pressure diagnostic did not report pressure_jacobi_canvas_tie_mode=2.")
	_expect(not bool(projection_canvas_tie_source_edge_result.get("production_output_replaced", true)), "Canvas-tie source-edge pressure diagnostic must not replace production bake output.")
	_expect(_output_texture_key_count(projection_canvas_tie_source_edge_result) == 0, "Canvas-tie source-edge pressure diagnostic returned output texture keys before replacement is allowed.")
	_expect(not bool(projection_canvas_tie_source_edge_result.get("async_readback_selected", true)), "Canvas-tie source-edge pressure diagnostic selected async readback.")
	_expect(int(projection_canvas_tie_source_edge_result.get("dispatch_count", 0)) == expected_pass_count + 4, "Canvas-tie source-edge pressure diagnostic did not dispatch the expanded stack.")
	_expect(bool(pressure_prefix_diagnostic.get("ok", false)), "Pressure prefix diagnostic failed: " + str(pressure_prefix_diagnostic))
	_expect(bool(projection_override_result.get("ok", false)), "Legacy-pressure projection diagnostic did not return ok=true: " + str(projection_override_result))
	_expect(bool(projection_override_result.get("pressure_override_used", false)), "Legacy-pressure projection diagnostic did not report pressure_override_used=true.")
	_expect(not bool(projection_override_result.get("production_output_replaced", true)), "Legacy-pressure projection diagnostic must not replace production bake output.")
	_expect(_output_texture_key_count(projection_override_result) == 0, "Legacy-pressure projection diagnostic returned output texture keys before replacement is allowed.")
	_expect(int(projection_override_result.get("dispatch_count", 0)) == expected_pass_count + 4, "Legacy-pressure projection diagnostic did not dispatch the expanded stack.")
	_expect(int(projection_override_result.get("compute_barrier_count", 0)) == int(projection_override_result.get("dispatch_count", 0)) - 1, "Legacy-pressure projection diagnostic did not preserve dependent-dispatch barriers.")
	_expect(bool(projection_override_parity.get("ok", false)), "Legacy-pressure compute projection did not match legacy solve/filter intermediates under R7_TOLERANCE_V1: " + str(projection_override_parity))
	_expect(bool(generated_override_candidate_parity.get("ok", false)), "Legacy-pressure generated flow_foam_noise candidate did not match legacy bake output under R7_TOLERANCE_V1: " + str(generated_override_candidate_parity))
	_expect(bool(canonical_acceptance.get("automated_ok", false)), "Canonical compute automated acceptance failed: " + str(canonical_acceptance))
	_expect(not bool(canonical_acceptance.get("acceptance_complete", true)), "Canonical acceptance should stay incomplete until visual review is explicitly recorded.")
	_canonical_acceptance_automated_ok = bool(canonical_acceptance.get("automated_ok", false))
	_expect(bool(legacy_before_state.get("valid_flowmap", false)), "Legacy fixture bake did not leave RiverManager valid_flowmap=true before compute.")
	_expect(legacy_before_state == legacy_after_state, "RiverManager texture/bake output state changed during non-replacing stack proof.")
	_expect(legacy_before_hashes == legacy_after_hashes, "RiverManager generated texture hashes changed during non-replacing stack proof.")

	if fixture != null:
		fixture.queue_free()
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		if _canonical_acceptance_automated_ok:
			print("R7_COMPUTE_CANONICAL_ACCEPTANCE_V1_AUTOMATED_OK report=", _written_report)
		print("R7_COMPUTE_SOLVE_FILTER_STACK_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_legacy_pressure_jacobi_pass6_sampler_diagnostic(config: Dictionary) -> Dictionary:
	var texture_size := Vector2i(
		maxi(4, int(config.get("texture_width", 106))),
		maxi(4, int(config.get("texture_height", 106)))
	)
	var source_size := maxf(1.0, float(config.get("source_size", 64.0)))
	var atlas_columns := maxi(1, int(config.get("atlas_columns", 5)))
	var stride := PASS6_SAMPLER_DIAGNOSTIC_STRIDE
	var step_uv := float(stride) / source_size
	var result := {
		"ok": false,
		"mode": "legacy_filter_renderer_pressure_jacobi_pass6_sampler_diagnostic",
		"shader": "flow_pressure_jacobi_pass.gdshader",
		"reference": "controlled_legacy_canvas_sampler_pass6_stride16",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"pass_index": PASS6_SAMPLER_DIAGNOSTIC_PASS_INDEX,
		"stride": stride,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"texture_width": texture_size.x,
		"texture_height": texture_size.y,
		"vertical_texel_offset": step_uv * float(texture_size.y),
		"horizontal_texel_offset": step_uv * float(texture_size.x),
		"compute_sampler_model": "floor(clamp(uv,0,1)*texture_size)",
		"center_sampler_models": "uv*texture_size-0.5 lower/upper tie candidates",
	}
	var probe_points := _make_pass6_sampler_probe_points(texture_size, source_size, stride, atlas_columns)
	result.probe_points = probe_points.duplicate()
	if probe_points.is_empty():
		result.reason = "probe_points_missing"
		return result
	var renderer := _make_renderer()
	if renderer == null:
		result.reason = "filter_renderer_missing"
		return result
	await process_frame
	if renderer.has_method("set_hdr_2d"):
		renderer.call("set_hdr_2d", true)

	var divergence_image := _make_fill_image(texture_size, Image.FORMAT_RGBAH, Color(0.5, 0.0, 0.0, 1.0))
	var occupancy_image := _make_fill_image(texture_size, Image.FORMAT_RGBA8, Color(0.0, 0.0, 0.0, 1.0))
	var up_case := await _run_pass6_sampler_case(
		renderer,
		"up",
		_make_pass6_direction_pressure_image(texture_size, probe_points, source_size, stride, "up"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var down_case := await _run_pass6_sampler_case(
		renderer,
		"down",
		_make_pass6_direction_pressure_image(texture_size, probe_points, source_size, stride, "down"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var grid_probe_points := _make_pass6_sampler_grid_probe_points(texture_size, source_size, stride, atlas_columns)
	var scanline_probe_points := _make_pass6_sampler_scanline_probe_points(texture_size, source_size, stride, atlas_columns)
	var y_band_probe_points := _make_pass6_sampler_y_band_probe_points(texture_size, atlas_columns)
	var up_grid_case := await _run_pass6_sampler_case(
		renderer,
		"up_grid",
		_make_pass6_direction_pressure_image(texture_size, grid_probe_points, source_size, stride, "up"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var down_grid_case := await _run_pass6_sampler_case(
		renderer,
		"down_grid",
		_make_pass6_direction_pressure_image(texture_size, grid_probe_points, source_size, stride, "down"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var up_scanline_case := await _run_pass6_sampler_case(
		renderer,
		"up_scanline",
		_make_pass6_direction_pressure_image(texture_size, scanline_probe_points, source_size, stride, "up"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var down_scanline_case := await _run_pass6_sampler_case(
		renderer,
		"down_scanline",
		_make_pass6_direction_pressure_image(texture_size, scanline_probe_points, source_size, stride, "down"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var up_y_band_case := await _run_pass6_sampler_case(
		renderer,
		"up_y_band",
		_make_pass6_direction_pressure_image(texture_size, y_band_probe_points, source_size, stride, "up"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var down_y_band_case := await _run_pass6_sampler_case(
		renderer,
		"down_y_band",
		_make_pass6_direction_pressure_image(texture_size, y_band_probe_points, source_size, stride, "down"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var center_case := await _run_pass6_sampler_case(
		renderer,
		"horizontal_wall_center",
		_make_pass6_center_pressure_image(texture_size, probe_points),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns
	)
	var fragcoord_up_grid_case := await _run_pass6_sampler_case(
		renderer,
		"fragcoord_up_grid",
		_make_pass6_direction_pressure_image(texture_size, grid_probe_points, source_size, stride, "up"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns,
		true
	)
	var fragcoord_down_grid_case := await _run_pass6_sampler_case(
		renderer,
		"fragcoord_down_grid",
		_make_pass6_direction_pressure_image(texture_size, grid_probe_points, source_size, stride, "down"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns,
		true
	)
	var fragcoord_up_y_band_case := await _run_pass6_sampler_case(
		renderer,
		"fragcoord_up_y_band",
		_make_pass6_direction_pressure_image(texture_size, y_band_probe_points, source_size, stride, "up"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns,
		true
	)
	var fragcoord_down_y_band_case := await _run_pass6_sampler_case(
		renderer,
		"fragcoord_down_y_band",
		_make_pass6_direction_pressure_image(texture_size, y_band_probe_points, source_size, stride, "down"),
		divergence_image,
		occupancy_image,
		source_size,
		atlas_columns,
		true
	)
	var readback_error := ""
	if "last_readback_error" in renderer:
		readback_error = String(renderer.last_readback_error)
	_remove_renderer(renderer)

	var required_sampler_cases := [
		up_case,
		down_case,
		up_grid_case,
		down_grid_case,
		up_scanline_case,
		down_scanline_case,
		up_y_band_case,
		down_y_band_case,
		center_case,
		fragcoord_up_grid_case,
		fragcoord_down_grid_case,
		fragcoord_up_y_band_case,
		fragcoord_down_y_band_case,
	]
	var sampler_case_failed := false
	for sampler_case_variant in required_sampler_cases:
		var sampler_case: Dictionary = sampler_case_variant
		if not bool(sampler_case.get("ok", false)):
			sampler_case_failed = true
	if sampler_case_failed:
		result.reason = "sampler_case_failed"
		result.readback_error = readback_error
		result.up_case = up_case
		result.down_case = down_case
		result.up_grid_case = up_grid_case
		result.down_grid_case = down_grid_case
		result.up_scanline_case = up_scanline_case
		result.down_scanline_case = down_scanline_case
		result.up_y_band_case = up_y_band_case
		result.down_y_band_case = down_y_band_case
		result.center_case = center_case
		result.fragcoord_up_grid_case = fragcoord_up_grid_case
		result.fragcoord_down_grid_case = fragcoord_down_grid_case
		result.fragcoord_up_y_band_case = fragcoord_up_y_band_case
		result.fragcoord_down_y_band_case = fragcoord_down_y_band_case
		return result

	var up_summary := _summarize_pass6_direction_case(up_case.get("image", null) as Image, probe_points, source_size, stride, "up")
	var down_summary := _summarize_pass6_direction_case(down_case.get("image", null) as Image, probe_points, source_size, stride, "down")
	var up_grid_summary := _summarize_pass6_direction_case(up_grid_case.get("image", null) as Image, grid_probe_points, source_size, stride, "up")
	var down_grid_summary := _summarize_pass6_direction_case(down_grid_case.get("image", null) as Image, grid_probe_points, source_size, stride, "down")
	var up_grid_model_summary := _summarize_pass6_triangle_model(up_grid_summary.get("choices", []), texture_size, source_size)
	var down_grid_model_summary := _summarize_pass6_triangle_model(down_grid_summary.get("choices", []), texture_size, source_size)
	var up_scanline_summary := _summarize_pass6_direction_case(up_scanline_case.get("image", null) as Image, scanline_probe_points, source_size, stride, "up")
	var down_scanline_summary := _summarize_pass6_direction_case(down_scanline_case.get("image", null) as Image, scanline_probe_points, source_size, stride, "down")
	var up_scanline_model_summary := _summarize_pass6_scanline_model(up_scanline_summary.get("choices", []), texture_size, source_size)
	var down_scanline_model_summary := _summarize_pass6_scanline_model(down_scanline_summary.get("choices", []), texture_size, source_size)
	var up_y_band_summary := _summarize_pass6_direction_case(up_y_band_case.get("image", null) as Image, y_band_probe_points, source_size, stride, "up")
	var down_y_band_summary := _summarize_pass6_direction_case(down_y_band_case.get("image", null) as Image, y_band_probe_points, source_size, stride, "down")
	var up_y_band_model_summary := _summarize_pass6_scanline_model(up_y_band_summary.get("choices", []), texture_size, source_size)
	var down_y_band_model_summary := _summarize_pass6_scanline_model(down_y_band_summary.get("choices", []), texture_size, source_size)
	var center_summary := _summarize_pass6_center_case(center_case.get("image", null) as Image, probe_points, source_size, stride, atlas_columns)
	var fragcoord_up_grid_summary := _summarize_pass6_direction_case(fragcoord_up_grid_case.get("image", null) as Image, grid_probe_points, source_size, stride, "up")
	var fragcoord_down_grid_summary := _summarize_pass6_direction_case(fragcoord_down_grid_case.get("image", null) as Image, grid_probe_points, source_size, stride, "down")
	var fragcoord_up_grid_model_summary := _summarize_pass6_triangle_model(fragcoord_up_grid_summary.get("choices", []), texture_size, source_size)
	var fragcoord_down_grid_model_summary := _summarize_pass6_triangle_model(fragcoord_down_grid_summary.get("choices", []), texture_size, source_size)
	var fragcoord_up_y_band_summary := _summarize_pass6_direction_case(fragcoord_up_y_band_case.get("image", null) as Image, y_band_probe_points, source_size, stride, "up")
	var fragcoord_down_y_band_summary := _summarize_pass6_direction_case(fragcoord_down_y_band_case.get("image", null) as Image, y_band_probe_points, source_size, stride, "down")
	var fragcoord_up_y_band_model_summary := _summarize_pass6_scanline_model(fragcoord_up_y_band_summary.get("choices", []), texture_size, source_size)
	var fragcoord_down_y_band_model_summary := _summarize_pass6_scanline_model(fragcoord_down_y_band_summary.get("choices", []), texture_size, source_size)
	var legacy_grid_compute_model_matches := int(up_grid_summary.get("compute_model_match_count", 0)) + int(down_grid_summary.get("compute_model_match_count", 0))
	var fragcoord_grid_compute_model_matches := int(fragcoord_up_grid_summary.get("compute_model_match_count", 0)) + int(fragcoord_down_grid_summary.get("compute_model_match_count", 0))
	var legacy_y_band_compute_model_matches := int(up_y_band_summary.get("compute_model_match_count", 0)) + int(down_y_band_summary.get("compute_model_match_count", 0))
	var fragcoord_y_band_compute_model_matches := int(fragcoord_up_y_band_summary.get("compute_model_match_count", 0)) + int(fragcoord_down_y_band_summary.get("compute_model_match_count", 0))
	var legacy_y_band_transition_count := int(up_y_band_model_summary.get("transition_count", 0)) + int(down_y_band_model_summary.get("transition_count", 0))
	var fragcoord_y_band_transition_count := int(fragcoord_up_y_band_model_summary.get("transition_count", 0)) + int(fragcoord_down_y_band_model_summary.get("transition_count", 0))
	result.up_choices = up_summary.get("choices", [])
	result.up_lower_choice_count = int(up_summary.get("lower_choice_count", 0))
	result.up_upper_choice_count = int(up_summary.get("upper_choice_count", 0))
	result.up_compute_model_match_count = int(up_summary.get("compute_model_match_count", 0))
	result.up_max_choice_delta = float(up_summary.get("max_choice_delta", 0.0))
	result.down_choices = down_summary.get("choices", [])
	result.down_lower_choice_count = int(down_summary.get("lower_choice_count", 0))
	result.down_upper_choice_count = int(down_summary.get("upper_choice_count", 0))
	result.down_compute_model_match_count = int(down_summary.get("compute_model_match_count", 0))
	result.down_max_choice_delta = float(down_summary.get("max_choice_delta", 0.0))
	result.grid_probe_points = grid_probe_points.duplicate()
	result.grid_probe_point_count = grid_probe_points.size()
	result.grid_triangle_model = "upper when point.x < point.y, otherwise lower"
	result.grid_source_edge_model = "upper when point.x < point.y except source_size - 1 row, otherwise lower"
	result.grid_source_edge_model_y = int(up_grid_model_summary.get("source_edge_y", -1))
	result.grid_up_choices = up_grid_summary.get("choices", [])
	result.grid_up_lower_choice_count = int(up_grid_summary.get("lower_choice_count", 0))
	result.grid_up_upper_choice_count = int(up_grid_summary.get("upper_choice_count", 0))
	result.grid_up_compute_model_match_count = int(up_grid_summary.get("compute_model_match_count", 0))
	result.grid_up_max_choice_delta = float(up_grid_summary.get("max_choice_delta", 0.0))
	result.grid_up_triangle_model_match_count = int(up_grid_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.grid_up_triangle_model_mismatch_count = int(up_grid_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.grid_up_triangle_model_match_ratio = float(up_grid_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.grid_up_triangle_model_mismatches = up_grid_model_summary.get("diagonal_x_lt_y_mismatches", [])
	result.grid_up_antidiagonal_model_match_count = int(up_grid_model_summary.get("antidiagonal_x_plus_y_lt_size_match_count", 0))
	result.grid_up_source_edge_model_match_count = int(up_grid_model_summary.get("source_edge_match_count", 0))
	result.grid_up_source_edge_model_mismatch_count = int(up_grid_model_summary.get("source_edge_mismatch_count", 0))
	result.grid_up_source_edge_model_match_ratio = float(up_grid_model_summary.get("source_edge_match_ratio", 0.0))
	result.grid_up_source_edge_model_mismatches = up_grid_model_summary.get("source_edge_mismatches", [])
	result.grid_down_choices = down_grid_summary.get("choices", [])
	result.grid_down_lower_choice_count = int(down_grid_summary.get("lower_choice_count", 0))
	result.grid_down_upper_choice_count = int(down_grid_summary.get("upper_choice_count", 0))
	result.grid_down_compute_model_match_count = int(down_grid_summary.get("compute_model_match_count", 0))
	result.grid_down_max_choice_delta = float(down_grid_summary.get("max_choice_delta", 0.0))
	result.grid_down_triangle_model_match_count = int(down_grid_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.grid_down_triangle_model_mismatch_count = int(down_grid_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.grid_down_triangle_model_match_ratio = float(down_grid_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.grid_down_triangle_model_mismatches = down_grid_model_summary.get("diagonal_x_lt_y_mismatches", [])
	result.grid_down_antidiagonal_model_match_count = int(down_grid_model_summary.get("antidiagonal_x_plus_y_lt_size_match_count", 0))
	result.grid_down_source_edge_model_match_count = int(down_grid_model_summary.get("source_edge_match_count", 0))
	result.grid_down_source_edge_model_mismatch_count = int(down_grid_model_summary.get("source_edge_mismatch_count", 0))
	result.grid_down_source_edge_model_match_ratio = float(down_grid_model_summary.get("source_edge_match_ratio", 0.0))
	result.grid_down_source_edge_model_mismatches = down_grid_model_summary.get("source_edge_mismatches", [])
	result.scanline_probe_points = scanline_probe_points.duplicate()
	result.scanline_probe_point_count = scanline_probe_points.size()
	result.scanline_x_count = PASS6_SAMPLER_SCANLINE_X_COUNT
	result.scanline_point_offset_step = PASS6_PRESSURE_POINT_OFFSET_STEP
	result.scanline_up_choices = up_scanline_summary.get("choices", [])
	result.scanline_up_lower_choice_count = int(up_scanline_summary.get("lower_choice_count", 0))
	result.scanline_up_upper_choice_count = int(up_scanline_summary.get("upper_choice_count", 0))
	result.scanline_up_compute_model_match_count = int(up_scanline_summary.get("compute_model_match_count", 0))
	result.scanline_up_max_choice_delta = float(up_scanline_summary.get("max_choice_delta", 0.0))
	result.scanline_up_rows = up_scanline_model_summary.get("rows", [])
	result.scanline_up_transition_count = int(up_scanline_model_summary.get("transition_count", 0))
	result.scanline_up_diagonal_model_match_count = int(up_scanline_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.scanline_up_diagonal_model_mismatch_count = int(up_scanline_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.scanline_up_diagonal_model_match_ratio = float(up_scanline_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.scanline_up_source_edge_model_match_count = int(up_scanline_model_summary.get("source_edge_match_count", 0))
	result.scanline_up_source_edge_model_mismatch_count = int(up_scanline_model_summary.get("source_edge_mismatch_count", 0))
	result.scanline_up_source_edge_model_match_ratio = float(up_scanline_model_summary.get("source_edge_match_ratio", 0.0))
	result.scanline_down_choices = down_scanline_summary.get("choices", [])
	result.scanline_down_lower_choice_count = int(down_scanline_summary.get("lower_choice_count", 0))
	result.scanline_down_upper_choice_count = int(down_scanline_summary.get("upper_choice_count", 0))
	result.scanline_down_compute_model_match_count = int(down_scanline_summary.get("compute_model_match_count", 0))
	result.scanline_down_max_choice_delta = float(down_scanline_summary.get("max_choice_delta", 0.0))
	result.scanline_down_rows = down_scanline_model_summary.get("rows", [])
	result.scanline_down_transition_count = int(down_scanline_model_summary.get("transition_count", 0))
	result.scanline_down_diagonal_model_match_count = int(down_scanline_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.scanline_down_diagonal_model_mismatch_count = int(down_scanline_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.scanline_down_diagonal_model_match_ratio = float(down_scanline_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.scanline_down_source_edge_model_match_count = int(down_scanline_model_summary.get("source_edge_match_count", 0))
	result.scanline_down_source_edge_model_mismatch_count = int(down_scanline_model_summary.get("source_edge_mismatch_count", 0))
	result.scanline_down_source_edge_model_match_ratio = float(down_scanline_model_summary.get("source_edge_match_ratio", 0.0))
	result.y_band_probe_point_count = y_band_probe_points.size()
	result.y_band_y_min = PASS6_SAMPLER_Y_BAND_MIN
	result.y_band_y_max = PASS6_SAMPLER_Y_BAND_MAX
	result.y_band_y_step = PASS6_SAMPLER_Y_BAND_STEP
	result.y_band_up_rows = up_y_band_model_summary.get("rows", [])
	result.y_band_up_lower_choice_count = int(up_y_band_summary.get("lower_choice_count", 0))
	result.y_band_up_upper_choice_count = int(up_y_band_summary.get("upper_choice_count", 0))
	result.y_band_up_compute_model_match_count = int(up_y_band_summary.get("compute_model_match_count", 0))
	result.y_band_up_max_choice_delta = float(up_y_band_summary.get("max_choice_delta", 0.0))
	result.y_band_up_transition_count = int(up_y_band_model_summary.get("transition_count", 0))
	result.y_band_up_diagonal_model_match_count = int(up_y_band_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.y_band_up_diagonal_model_mismatch_count = int(up_y_band_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.y_band_up_diagonal_model_match_ratio = float(up_y_band_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.y_band_up_source_edge_model_match_count = int(up_y_band_model_summary.get("source_edge_match_count", 0))
	result.y_band_up_source_edge_model_mismatch_count = int(up_y_band_model_summary.get("source_edge_mismatch_count", 0))
	result.y_band_up_source_edge_model_match_ratio = float(up_y_band_model_summary.get("source_edge_match_ratio", 0.0))
	result.y_band_down_rows = down_y_band_model_summary.get("rows", [])
	result.y_band_down_lower_choice_count = int(down_y_band_summary.get("lower_choice_count", 0))
	result.y_band_down_upper_choice_count = int(down_y_band_summary.get("upper_choice_count", 0))
	result.y_band_down_compute_model_match_count = int(down_y_band_summary.get("compute_model_match_count", 0))
	result.y_band_down_max_choice_delta = float(down_y_band_summary.get("max_choice_delta", 0.0))
	result.y_band_down_transition_count = int(down_y_band_model_summary.get("transition_count", 0))
	result.y_band_down_diagonal_model_match_count = int(down_y_band_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.y_band_down_diagonal_model_mismatch_count = int(down_y_band_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.y_band_down_diagonal_model_match_ratio = float(down_y_band_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.y_band_down_source_edge_model_match_count = int(down_y_band_model_summary.get("source_edge_match_count", 0))
	result.y_band_down_source_edge_model_mismatch_count = int(down_y_band_model_summary.get("source_edge_mismatch_count", 0))
	result.y_band_down_source_edge_model_match_ratio = float(down_y_band_model_summary.get("source_edge_match_ratio", 0.0))
	result.fragcoord_variant_shader = FRAGCOORD_PRESSURE_JACOBI_PROBE_SHADER_PATH
	result.fragcoord_variant_reference = "probe_only_FRAGCOORD_derived_base_texel_center"
	result.fragcoord_variant_production_output_replaced = false
	result.fragcoord_grid_up_choices = fragcoord_up_grid_summary.get("choices", [])
	result.fragcoord_grid_up_lower_choice_count = int(fragcoord_up_grid_summary.get("lower_choice_count", 0))
	result.fragcoord_grid_up_upper_choice_count = int(fragcoord_up_grid_summary.get("upper_choice_count", 0))
	result.fragcoord_grid_up_compute_model_match_count = int(fragcoord_up_grid_summary.get("compute_model_match_count", 0))
	result.fragcoord_grid_up_max_choice_delta = float(fragcoord_up_grid_summary.get("max_choice_delta", 0.0))
	result.fragcoord_grid_up_triangle_model_match_count = int(fragcoord_up_grid_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.fragcoord_grid_up_triangle_model_mismatch_count = int(fragcoord_up_grid_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.fragcoord_grid_up_triangle_model_match_ratio = float(fragcoord_up_grid_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.fragcoord_grid_up_source_edge_model_match_count = int(fragcoord_up_grid_model_summary.get("source_edge_match_count", 0))
	result.fragcoord_grid_up_source_edge_model_mismatch_count = int(fragcoord_up_grid_model_summary.get("source_edge_mismatch_count", 0))
	result.fragcoord_grid_up_source_edge_model_match_ratio = float(fragcoord_up_grid_model_summary.get("source_edge_match_ratio", 0.0))
	result.fragcoord_grid_down_choices = fragcoord_down_grid_summary.get("choices", [])
	result.fragcoord_grid_down_lower_choice_count = int(fragcoord_down_grid_summary.get("lower_choice_count", 0))
	result.fragcoord_grid_down_upper_choice_count = int(fragcoord_down_grid_summary.get("upper_choice_count", 0))
	result.fragcoord_grid_down_compute_model_match_count = int(fragcoord_down_grid_summary.get("compute_model_match_count", 0))
	result.fragcoord_grid_down_max_choice_delta = float(fragcoord_down_grid_summary.get("max_choice_delta", 0.0))
	result.fragcoord_grid_down_triangle_model_match_count = int(fragcoord_down_grid_model_summary.get("diagonal_x_lt_y_match_count", 0))
	result.fragcoord_grid_down_triangle_model_mismatch_count = int(fragcoord_down_grid_model_summary.get("diagonal_x_lt_y_mismatch_count", 0))
	result.fragcoord_grid_down_triangle_model_match_ratio = float(fragcoord_down_grid_model_summary.get("diagonal_x_lt_y_match_ratio", 0.0))
	result.fragcoord_grid_down_source_edge_model_match_count = int(fragcoord_down_grid_model_summary.get("source_edge_match_count", 0))
	result.fragcoord_grid_down_source_edge_model_mismatch_count = int(fragcoord_down_grid_model_summary.get("source_edge_mismatch_count", 0))
	result.fragcoord_grid_down_source_edge_model_match_ratio = float(fragcoord_down_grid_model_summary.get("source_edge_match_ratio", 0.0))
	result.fragcoord_y_band_up_rows = fragcoord_up_y_band_model_summary.get("rows", [])
	result.fragcoord_y_band_up_lower_choice_count = int(fragcoord_up_y_band_summary.get("lower_choice_count", 0))
	result.fragcoord_y_band_up_upper_choice_count = int(fragcoord_up_y_band_summary.get("upper_choice_count", 0))
	result.fragcoord_y_band_up_compute_model_match_count = int(fragcoord_up_y_band_summary.get("compute_model_match_count", 0))
	result.fragcoord_y_band_up_transition_count = int(fragcoord_up_y_band_model_summary.get("transition_count", 0))
	result.fragcoord_y_band_up_source_edge_model_match_count = int(fragcoord_up_y_band_model_summary.get("source_edge_match_count", 0))
	result.fragcoord_y_band_up_source_edge_model_mismatch_count = int(fragcoord_up_y_band_model_summary.get("source_edge_mismatch_count", 0))
	result.fragcoord_y_band_up_source_edge_model_match_ratio = float(fragcoord_up_y_band_model_summary.get("source_edge_match_ratio", 0.0))
	result.fragcoord_y_band_down_rows = fragcoord_down_y_band_model_summary.get("rows", [])
	result.fragcoord_y_band_down_lower_choice_count = int(fragcoord_down_y_band_summary.get("lower_choice_count", 0))
	result.fragcoord_y_band_down_upper_choice_count = int(fragcoord_down_y_band_summary.get("upper_choice_count", 0))
	result.fragcoord_y_band_down_compute_model_match_count = int(fragcoord_down_y_band_summary.get("compute_model_match_count", 0))
	result.fragcoord_y_band_down_transition_count = int(fragcoord_down_y_band_model_summary.get("transition_count", 0))
	result.fragcoord_y_band_down_source_edge_model_match_count = int(fragcoord_down_y_band_model_summary.get("source_edge_match_count", 0))
	result.fragcoord_y_band_down_source_edge_model_mismatch_count = int(fragcoord_down_y_band_model_summary.get("source_edge_mismatch_count", 0))
	result.fragcoord_y_band_down_source_edge_model_match_ratio = float(fragcoord_down_y_band_model_summary.get("source_edge_match_ratio", 0.0))
	result.fragcoord_grid_compute_model_match_delta = fragcoord_grid_compute_model_matches - legacy_grid_compute_model_matches
	result.fragcoord_y_band_compute_model_match_delta = fragcoord_y_band_compute_model_matches - legacy_y_band_compute_model_matches
	result.fragcoord_y_band_transition_count = fragcoord_y_band_transition_count
	result.fragcoord_y_band_legacy_transition_count = legacy_y_band_transition_count
	result.fragcoord_y_band_transition_reduction = legacy_y_band_transition_count - fragcoord_y_band_transition_count
	result.fragcoord_uv_artifact_hypothesis_supported = fragcoord_y_band_transition_count < legacy_y_band_transition_count
	result.fragcoord_variant_interpretation = "FRAGCOORD collapses x-dependent y-band transitions but does not select the canonical compute model uniformly"
	result.horizontal_wall_choices = center_summary.get("choices", [])
	result.horizontal_wall_match_count = int(center_summary.get("wall_match_count", 0))
	result.horizontal_wall_max_delta = float(center_summary.get("max_wall_delta", 0.0))
	result.case_output_formats = {
		"up": int(up_case.get("format", -1)),
		"down": int(down_case.get("format", -1)),
		"up_grid": int(up_grid_case.get("format", -1)),
		"down_grid": int(down_grid_case.get("format", -1)),
		"up_scanline": int(up_scanline_case.get("format", -1)),
		"down_scanline": int(down_scanline_case.get("format", -1)),
		"up_y_band": int(up_y_band_case.get("format", -1)),
		"down_y_band": int(down_y_band_case.get("format", -1)),
		"horizontal_wall_center": int(center_case.get("format", -1)),
		"fragcoord_up_grid": int(fragcoord_up_grid_case.get("format", -1)),
		"fragcoord_down_grid": int(fragcoord_down_grid_case.get("format", -1)),
		"fragcoord_up_y_band": int(fragcoord_up_y_band_case.get("format", -1)),
		"fragcoord_down_y_band": int(fragcoord_down_y_band_case.get("format", -1)),
	}
	result.readback_error = readback_error
	result.reason = "ok"
	result.ok = true
	return result


func _run_flow_pressure_jacobi_fragcoord_probe(renderer: Node, pressure_texture: Texture2D, divergence_texture: Texture2D, occupancy_texture: Texture2D, stride: float, resolution: float, atlas_columns: float) -> ImageTexture:
	if pressure_texture == null or divergence_texture == null or occupancy_texture == null:
		_set_renderer_readback_error(renderer, "fragcoord pressure jacobi input texture is null")
		return null
	var shader := load(FRAGCOORD_PRESSURE_JACOBI_PROBE_SHADER_PATH) as Shader
	if shader == null:
		_set_renderer_readback_error(renderer, "fragcoord pressure jacobi probe shader failed to load")
		return null
	var color_rect := renderer.get_node_or_null("ColorRect") as ColorRect
	if color_rect == null:
		_set_renderer_readback_error(renderer, "fragcoord pressure jacobi renderer ColorRect is missing")
		return null
	var texture_size := pressure_texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		_set_renderer_readback_error(renderer, "fragcoord pressure jacobi pressure texture has invalid size")
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"pressure_texture", pressure_texture)
	material.set_shader_parameter(&"divergence_texture", divergence_texture)
	material.set_shader_parameter(&"occupancy_texture", occupancy_texture)
	material.set_shader_parameter(&"stride", stride)
	material.set_shader_parameter(&"size", resolution)
	material.set_shader_parameter(&"atlas_columns", atlas_columns)
	material.set_shader_parameter(&"texture_size_px", Vector2(float(texture_size.x), float(texture_size.y)))
	color_rect.material = material
	color_rect.position = Vector2.ZERO
	color_rect.size = texture_size
	renderer.set("filter_mat", material)
	renderer.set("size", texture_size)
	renderer.set("use_hdr_2d", true)
	renderer.set("render_target_update_mode", SubViewport.UPDATE_ONCE)
	await process_frame
	await process_frame
	return _read_renderer_output_texture(renderer, "flow_pressure_jacobi_fragcoord_probe")


func _read_renderer_output_texture(renderer: Node, pass_label: String) -> ImageTexture:
	_set_renderer_readback_error(renderer, "")
	var preflight_error := _renderer_readback_preflight_error(renderer, pass_label)
	if not preflight_error.is_empty():
		_set_renderer_readback_error(renderer, preflight_error)
		return null
	var viewport_texture := renderer.call("get_texture") as Texture2D
	if viewport_texture == null:
		_set_renderer_readback_error(renderer, pass_label + " viewport texture is null")
		return null
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		_set_renderer_readback_error(renderer, pass_label + " viewport image is empty or unreadable")
		return null
	var result := ImageTexture.create_from_image(image)
	if result == null or result.get_width() <= 0 or result.get_height() <= 0:
		_set_renderer_readback_error(renderer, pass_label + " output texture creation failed")
		return null
	return result


func _renderer_readback_preflight_error(renderer: Node, pass_label: String) -> String:
	if renderer == null:
		return pass_label + " renderer is null"
	if not renderer.is_inside_tree():
		return pass_label + " renderer is not inside the scene tree"
	if renderer.get_tree() == null:
		return pass_label + " renderer has no SceneTree"
	var renderer_size: Vector2 = renderer.get("size")
	if renderer_size.x <= 0 or renderer_size.y <= 0:
		return pass_label + " viewport size is invalid " + str(renderer_size)
	if String(DisplayServer.get_name()).to_lower() == "headless":
		return pass_label + " viewport readback is unavailable with the headless display server"
	if String(RenderingServer.get_current_rendering_method()).to_lower() == "dummy":
		return pass_label + " viewport readback is unavailable with the dummy rendering method"
	return ""


func _set_renderer_readback_error(renderer: Node, message: String) -> void:
	if renderer != null and "last_readback_error" in renderer:
		renderer.set("last_readback_error", message)


func _run_pass6_sampler_case(renderer: Node, case_name: String, pressure_image: Image, divergence_image: Image, occupancy_image: Image, source_size: float, atlas_columns: int, use_fragcoord_variant: bool = false) -> Dictionary:
	var result := {
		"ok": false,
		"case": case_name,
		"shader_variant": "fragcoord_probe" if use_fragcoord_variant else "legacy_uv",
	}
	if pressure_image == null or divergence_image == null or occupancy_image == null:
		result.reason = "case_image_missing"
		return result
	var pressure_texture := ImageTexture.create_from_image(pressure_image)
	var divergence_texture := ImageTexture.create_from_image(divergence_image)
	var occupancy_texture := ImageTexture.create_from_image(occupancy_image)
	if pressure_texture == null or divergence_texture == null or occupancy_texture == null:
		result.reason = "case_texture_create_failed"
		return result
	var output_texture: Texture2D = null
	if use_fragcoord_variant:
		output_texture = await _run_flow_pressure_jacobi_fragcoord_probe(
			renderer,
			pressure_texture,
			divergence_texture,
			occupancy_texture,
			float(PASS6_SAMPLER_DIAGNOSTIC_STRIDE),
			source_size,
			float(atlas_columns)
		)
	else:
		output_texture = await renderer.apply_flow_pressure_jacobi(
			pressure_texture,
			divergence_texture,
			occupancy_texture,
			float(PASS6_SAMPLER_DIAGNOSTIC_STRIDE),
			source_size,
			float(atlas_columns)
		)
	if output_texture == null:
		result.reason = "legacy_shader_output_missing"
		if "last_readback_error" in renderer:
			result.readback_error = String(renderer.last_readback_error)
		return result
	var output_image := output_texture.get_image()
	if output_image == null or output_image.is_empty():
		result.reason = "legacy_shader_image_unreadable"
		if "last_readback_error" in renderer:
			result.readback_error = String(renderer.last_readback_error)
		return result
	result.ok = true
	result.reason = "ok"
	result.format = output_image.get_format()
	result.image = output_image
	return result


func _run_legacy_pressure_jacobi_stack_parity(config: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "legacy_filter_renderer_pressure_jacobi_stack_parity",
		"shader": "flow_pressure_jacobi_pass.gdshader",
		"reference": "cpu_legacy_uv_pressure_jacobi_stack_v1",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"tolerance_gate": "R7_LEGACY_JACOBI_STACK_INTERMEDIATE_V1",
	}
	var backend := RiverFlowmapComputeBackend.new()
	var fixture := backend.make_pressure_jacobi_stack_validation_fixture(config)
	var pressure_image := fixture.get("initial_pressure_image") as Image
	var divergence_image := fixture.get("divergence_image") as Image
	var occupancy_image := fixture.get("occupancy_image") as Image
	if pressure_image == null or divergence_image == null or occupancy_image == null:
		result.reason = "fixture_image_create_failed"
		return result
	var pressure_texture := ImageTexture.create_from_image(pressure_image)
	var divergence_texture := ImageTexture.create_from_image(divergence_image)
	var occupancy_texture := ImageTexture.create_from_image(occupancy_image)
	if pressure_texture == null or divergence_texture == null or occupancy_texture == null:
		result.reason = "fixture_texture_create_failed"
		return result
	var renderer_scene := load(FILTER_RENDERER_SCENE) as PackedScene
	if renderer_scene == null:
		result.reason = "filter_renderer_scene_missing"
		return result
	var renderer := renderer_scene.instantiate()
	if renderer == null:
		result.reason = "filter_renderer_instantiate_failed"
		return result
	root.add_child(renderer)
	await process_frame
	if renderer.has_method("set_hdr_2d"):
		renderer.call("set_hdr_2d", true)
	var strides: Array = fixture.get("flow_projection_strides", [])
	var iterations_per_stride := int(fixture.get("flow_projection_iterations_per_stride", 1))
	var pass_count := 0
	for stride_variant in strides:
		var stride := int(stride_variant)
		for _iteration in iterations_per_stride:
			var output_texture: Texture2D = await renderer.apply_flow_pressure_jacobi(
				pressure_texture,
				divergence_texture,
				occupancy_texture,
				float(stride),
				float(fixture.get("source_size", 1.0)),
				float(fixture.get("atlas_columns", 1))
			)
			if output_texture == null:
				result.reason = "legacy_shader_output_missing"
				if "last_readback_error" in renderer:
					result.readback_error = String(renderer.last_readback_error)
				_remove_renderer(renderer)
				return result
			pressure_texture = output_texture
			pass_count += 1
	var readback_error := ""
	if "last_readback_error" in renderer:
		readback_error = String(renderer.last_readback_error)
	_remove_renderer(renderer)
	var output_image := pressure_texture.get_image()
	if output_image == null or output_image.is_empty():
		result.reason = "legacy_shader_image_unreadable"
		result.readback_error = readback_error
		return result
	var actual_encoded := _read_red_channel(output_image)
	var expected_encoded: Array = fixture.get("expected_encoded_pressure", [])
	var metrics := _pressure_compare_metrics(expected_encoded, actual_encoded, 0.02, 0.64)
	for key in metrics:
		result["metric_" + String(key)] = metrics[key]
	result.texture_width = output_image.get_width()
	result.texture_height = output_image.get_height()
	result.texture_format = output_image.get_format()
	result.source_size = float(fixture.get("source_size", 1.0))
	result.atlas_columns = int(fixture.get("atlas_columns", 1))
	result.flow_projection_strides = strides.duplicate()
	result.flow_projection_iterations_per_stride = iterations_per_stride
	result.jacobi_pass_count = pass_count
	result.fixture_active_pixels = int(fixture.get("active_pixels", 0))
	result.fixture_solid_pixels = int(fixture.get("solid_pixels", 0))
	result.fixture_wall_neighbor_cases = int(fixture.get("wall_neighbor_cases", 0))
	result.fixture_cross_column_wall_neighbor_cases = int(fixture.get("cross_column_wall_neighbor_cases", 0))
	result.fixture_padding_wall_neighbor_cases = int(fixture.get("padding_wall_neighbor_cases", 0))
	result.fixture_solid_neighbor_cases = int(fixture.get("solid_neighbor_cases", 0))
	result.reason = "ok"
	var cpu_reference_ok := (
		float(metrics.get("encoded_max_abs", 1.0)) <= 0.02
		and float(metrics.get("encoded_p99_abs", 1.0)) <= 0.01
		and float(metrics.get("pressure_max_abs", 1.0)) <= 0.64
		and float(metrics.get("pressure_p99_abs", 1.0)) <= 0.32
	)
	result.cpu_reference_ok = cpu_reference_ok
	result.ok = true
	result["_debug_actual_encoded_pressure"] = actual_encoded
	if not cpu_reference_ok:
		result.reason = "ok_cpu_reference_diagnostic_mismatch"
	return result


func _compare_compute_to_legacy_stack(compute_result: Dictionary, legacy_result: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "compute_vs_legacy_filter_renderer_pressure_jacobi_stack",
		"reference": "legacy_filter_renderer_pressure_jacobi_stack",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"tolerance_gate": "R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1",
	}
	var compute_encoded: Array = compute_result.get("_debug_actual_encoded_pressure", [])
	var legacy_encoded: Array = legacy_result.get("_debug_actual_encoded_pressure", [])
	if compute_encoded.is_empty() or legacy_encoded.is_empty():
		result.reason = "debug_encoded_pressure_missing"
		return result
	var metrics := _pressure_compare_metrics(legacy_encoded, compute_encoded, 0.02, 0.64)
	for key in metrics:
		result["metric_" + String(key)] = metrics[key]
	result.reason = "ok"
	result.ok = (
		float(metrics.get("encoded_max_abs", 1.0)) <= 0.04
		and float(metrics.get("encoded_p99_abs", 1.0)) <= 0.03
		and float(metrics.get("encoded_mean_abs", 1.0)) <= 0.008
		and float(metrics.get("pressure_max_abs", 1.0)) <= 1.3
		and float(metrics.get("pressure_p99_abs", 1.0)) <= 1.0
	)
	if not bool(result.ok):
		result.reason = "compute_legacy_stack_mismatch"
	return result


func _run_pressure_prefix_diagnostic(base_config: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "compute_pressure_prefix_vs_legacy_pressure",
		"reference": "legacy_filter_renderer_pressure_by_pass",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"candidate_modes": [0, 1, 2],
		"pass_counts": _pressure_prefix_pass_counts(base_config),
		"target_points": _pressure_failure_target_points(),
		"reason": "not_run",
	}
	var errors := []
	var pass_counts: Array = result.get("pass_counts", [])
	var target_points: Array = result.get("target_points", [])
	for mode in [0, 1, 2]:
		var records := []
		for pass_count_variant in pass_counts:
			var pass_count := int(pass_count_variant)
			var limited_config := _make_projection_compute_config(base_config)
			limited_config["pressure_jacobi_canvas_tie_mode"] = mode
			limited_config["pressure_jacobi_pass_limit"] = pass_count
			limited_config["flow_tangency_passes"] = 0
			var prefix_baker := RiverFlowmapBaker.new()
			var prefix_result: Dictionary = await prefix_baker.run_non_replacing_compute_solve_filter_projection_probe(
				limited_config,
				Callable(self, "_record_progress")
			)
			prefix_baker.cleanup()
			prefix_baker.abort()
			prefix_baker.cleanup()
			if not bool(prefix_result.get("ok", false)):
				errors.append("mode " + str(mode) + " pass " + str(pass_count) + " compute failed: " + String(prefix_result.get("reason", "")))
				continue
			var compute_pressure := prefix_result.get("_debug_pressure_image", null) as Image
			var legacy_pressure := _legacy_pressure_image_for_pass(pass_count)
			if compute_pressure == null or legacy_pressure == null:
				errors.append("mode " + str(mode) + " pass " + str(pass_count) + " pressure image missing")
				continue
			var rects := _legacy_occupied_rects()
			if rects.is_empty():
				rects = [Rect2i(Vector2i.ZERO, compute_pressure.get_size())]
			var pressure_compare := _compare_image_pair("pressure_prefix", legacy_pressure, compute_pressure, rects, false)
			records.append(_compact_pressure_prefix_record(
				pass_count,
				mode,
				_pressure_stride_info(pass_count, base_config),
				pressure_compare,
				legacy_pressure,
				compute_pressure,
				target_points
			))
		result["mode_" + str(mode) + "_records"] = records
		result["mode_" + str(mode) + "_summary"] = _summarize_pressure_prefix_records(records)
	result["ok"] = errors.is_empty()
	result["reason"] = "ok" if errors.is_empty() else "pressure_prefix_diagnostic_failed"
	result["errors"] = errors
	return result


func _pressure_prefix_pass_counts(base_config: Dictionary) -> Array:
	var total_passes := _pressure_total_pass_count(base_config)
	var result := []
	for pass_count_variant in PRESSURE_PREFIX_DIAGNOSTIC_PASS_COUNTS:
		var pass_count := clampi(int(pass_count_variant), 1, total_passes)
		if not result.has(pass_count):
			result.append(pass_count)
	result.sort()
	return result


func _pressure_total_pass_count(base_config: Dictionary) -> int:
	var strides = base_config.get("flow_projection_strides", DEFAULT_STRIDE_SCHEDULE)
	var stride_count := DEFAULT_STRIDE_SCHEDULE.size()
	if typeof(strides) == TYPE_ARRAY or typeof(strides) == TYPE_PACKED_INT32_ARRAY:
		stride_count = maxi(1, strides.size())
	var iterations_per_stride := maxi(1, int(base_config.get("flow_projection_iterations_per_stride", 5)))
	return maxi(1, stride_count * iterations_per_stride)


func _pressure_stride_info(pass_count: int, base_config: Dictionary) -> Dictionary:
	var strides = base_config.get("flow_projection_strides", DEFAULT_STRIDE_SCHEDULE)
	var stride_values := []
	if typeof(strides) == TYPE_ARRAY or typeof(strides) == TYPE_PACKED_INT32_ARRAY:
		for stride_variant in strides:
			stride_values.append(maxi(1, int(stride_variant)))
	if stride_values.is_empty():
		for stride_variant in DEFAULT_STRIDE_SCHEDULE:
			stride_values.append(maxi(1, int(stride_variant)))
	var iterations_per_stride := maxi(1, int(base_config.get("flow_projection_iterations_per_stride", 5)))
	var remaining := maxi(1, pass_count)
	for stride_index in stride_values.size():
		if remaining <= iterations_per_stride:
			return {
				"stride": int(stride_values[stride_index]),
				"stride_index": stride_index,
				"iteration_in_stride": remaining,
			}
		remaining -= iterations_per_stride
	return {
		"stride": int(stride_values[stride_values.size() - 1]),
		"stride_index": stride_values.size() - 1,
		"iteration_in_stride": iterations_per_stride,
	}


func _compact_pressure_prefix_record(pass_count: int, mode: int, stride_info: Dictionary, compare: Dictionary, expected: Image, actual: Image, target_points: Array) -> Dictionary:
	return {
		"mode": mode,
		"pass_count": pass_count,
		"stride": int(stride_info.get("stride", 0)),
		"stride_index": int(stride_info.get("stride_index", 0)),
		"iteration_in_stride": int(stride_info.get("iteration_in_stride", 0)),
		"pressure_ok": bool(compare.get("ok", false)),
		"pressure_reason": String(compare.get("reason", "")),
		"whole_r_p99_abs": float(compare.get("whole_r_p99_abs", 0.0)),
		"whole_r_max_abs": float(compare.get("whole_r_max_abs", 0.0)),
		"occupied_r_p99_abs": float(compare.get("occupied_r_p99_abs", 0.0)),
		"occupied_r_max_abs": float(compare.get("occupied_r_max_abs", 0.0)),
		"occupied_r_signed_mean": float(compare.get("occupied_r_signed_mean", 0.0)),
		"occupied_r_signed_p01": float(compare.get("occupied_r_signed_p01", 0.0)),
		"occupied_r_signed_p99": float(compare.get("occupied_r_signed_p99", 0.0)),
		"occupied_r_over_gate_count": int(compare.get("occupied_r_over_0_006_count", 0)),
		"occupied_r_over_high_gate_count": int(compare.get("occupied_r_over_0_010_count", 0)),
		"target_records": _pressure_target_records(expected, actual, target_points),
	}


func _summarize_pressure_prefix_records(records: Array) -> Dictionary:
	var summary := {
		"record_count": records.size(),
		"first_occupied_r_p99_over_gate": {},
		"first_occupied_r_max_over_0_02": {},
		"max_occupied_r_p99_abs": 0.0,
		"max_occupied_r_p99_record": {},
		"max_target_pressure_delta": 0.0,
		"max_target_pressure_record": {},
	}
	for record_variant in records:
		var record: Dictionary = record_variant
		var p99 := float(record.get("occupied_r_p99_abs", 0.0))
		var max_abs := float(record.get("occupied_r_max_abs", 0.0))
		var first_p99_over_gate: Dictionary = summary.get("first_occupied_r_p99_over_gate", {})
		var first_max_over_gate: Dictionary = summary.get("first_occupied_r_max_over_0_02", {})
		if first_p99_over_gate.is_empty() and p99 > CHANNEL_FAILURE_GATE:
			summary.first_occupied_r_p99_over_gate = record
		if first_max_over_gate.is_empty() and max_abs > 0.02:
			summary.first_occupied_r_max_over_0_02 = record
		if p99 > float(summary.max_occupied_r_p99_abs):
			summary.max_occupied_r_p99_abs = p99
			summary.max_occupied_r_p99_record = record
		for target_variant in record.get("target_records", []):
			var target: Dictionary = target_variant
			var pressure_delta := float(target.get("pressure_delta_abs", 0.0))
			if pressure_delta > float(summary.max_target_pressure_delta):
				summary.max_target_pressure_delta = pressure_delta
				summary.max_target_pressure_record = {
					"pass_count": int(record.get("pass_count", 0)),
					"mode": int(record.get("mode", 0)),
					"stride": int(record.get("stride", 0)),
					"iteration_in_stride": int(record.get("iteration_in_stride", 0)),
					"target": target,
				}
	return summary


func _make_projection_compute_config(base_config: Dictionary, use_legacy_pressure: bool = false) -> Dictionary:
	var config := base_config.duplicate(true)
	var flow_texture := _legacy_projection_capture.get("flow_input_texture", null) as Texture2D
	var occupancy_texture := _legacy_projection_capture.get("occupancy_input_texture", null) as Texture2D
	config["flow_image"] = _texture_to_image(flow_texture)
	config["occupancy_image"] = _texture_to_image(occupancy_texture)
	if use_legacy_pressure:
		config["pressure_override_image"] = _texture_to_image(_legacy_projection_capture.get("legacy_pressure_texture", null) as Texture2D)
	config["source_size"] = float(_legacy_projection_capture.get("source_size", base_config.get("source_size", 1.0)))
	config["atlas_columns"] = maxi(1, int(round(float(_legacy_projection_capture.get("atlas_columns", base_config.get("atlas_columns", 1))))))
	config["flow_tangency_passes"] = int(_legacy_projection_capture.get("tangency_pass_count", 2))
	config["sync_wait_frames"] = 3
	return config


func _compare_projection_candidate(projection_result: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "compute_vs_legacy_filter_renderer_projection_stack",
		"reference": "legacy_filter_renderer_projection_intermediates",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"tolerance_gate": "R7_TOLERANCE_V1",
	}
	if not bool(projection_result.get("ok", false)):
		result.reason = "projection_compute_failed"
		return result
	var compute_divergence := projection_result.get("_debug_divergence_image", null) as Image
	var compute_pressure := projection_result.get("_debug_pressure_image", null) as Image
	var compute_projected_flow := projection_result.get("_debug_projected_flow_image", null) as Image
	var compute_flow := projection_result.get("_debug_final_flow_image", null) as Image
	var legacy_divergence := _texture_to_image(_legacy_projection_capture.get("legacy_divergence_texture", null) as Texture2D)
	var legacy_pressure := _legacy_pressure_image_for_pass(maxi(1, int(projection_result.get("jacobi_pass_count", 0))))
	var legacy_projected_flow := _texture_to_image(_legacy_projection_capture.get("legacy_projected_flow_texture", null) as Texture2D)
	var legacy_flow := _texture_to_image(_legacy_projection_capture.get("legacy_tangent_flow_texture", null) as Texture2D)
	if compute_divergence == null or compute_pressure == null or compute_projected_flow == null or compute_flow == null or legacy_divergence == null or legacy_pressure == null or legacy_projected_flow == null or legacy_flow == null:
		result.reason = "projection_debug_or_legacy_images_missing"
		return result
	var rects := _legacy_occupied_rects()
	if rects.is_empty():
		rects = [Rect2i(Vector2i.ZERO, compute_flow.get_size())]
	var divergence_compare := _compare_image_pair("divergence", legacy_divergence, compute_divergence, rects, false)
	var pressure_compare := _compare_image_pair("pressure", legacy_pressure, compute_pressure, rects, false)
	var projected_compare := _compare_image_pair("projected_flow", legacy_projected_flow, compute_projected_flow, rects, true)
	var flow_compare := _compare_image_pair("final_flow", legacy_flow, compute_flow, rects, true)
	_merge_prefixed_result(result, "divergence_", divergence_compare)
	_merge_prefixed_result(result, "pressure_", pressure_compare)
	_merge_prefixed_result(result, "projected_flow_", projected_compare)
	_merge_prefixed_result(result, "final_flow_", flow_compare)
	result.ok = bool(divergence_compare.get("ok", false)) and bool(projected_compare.get("ok", false)) and bool(flow_compare.get("ok", false))
	result.reason = "ok" if bool(result.ok) else "projection_candidate_r7_tolerance_mismatch"
	return result


func _legacy_pressure_image_for_pass(pass_count: int) -> Image:
	var pressure_textures: Array = _legacy_projection_capture.get("legacy_pressure_textures", [])
	if pressure_textures.is_empty():
		return _texture_to_image(_legacy_projection_capture.get("legacy_pressure_texture", null) as Texture2D)
	var index := clampi(pass_count - 1, 0, pressure_textures.size() - 1)
	return _texture_to_image(pressure_textures[index] as Texture2D)


func _compare_generated_flow_candidate(projection_result: Dictionary, river: Node) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "compute_candidate_vs_legacy_generated_flow_foam_noise",
		"reference": "legacy_bake_output_flow_foam_noise",
		"candidate_texture": "flow_foam_noise",
		"migrated_channels": "rg",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"tolerance_gate": "R7_TOLERANCE_V1",
	}
	if not bool(projection_result.get("ok", false)):
		result.reason = "projection_compute_failed"
		return result
	var compute_flow := projection_result.get("_debug_final_flow_image", null) as Image
	var compute_flow_texture := ImageTexture.create_from_image(compute_flow) if compute_flow != null else null
	var foam_texture := _legacy_projection_capture.get("flow_foam_noise_b_texture", null) as Texture2D
	var noise_texture := _legacy_projection_capture.get("flow_foam_noise_a_texture", null) as Texture2D
	var legacy_texture: Texture2D = null
	if river != null:
		legacy_texture = river.get("flow_foam_noise") as Texture2D
	var legacy_image := _texture_to_image(legacy_texture)
	var bake_data: Resource = null
	if river != null:
		bake_data = river.get("bake_data") as Resource
	if compute_flow_texture == null or foam_texture == null or noise_texture == null or legacy_image == null or bake_data == null:
		result.reason = "candidate_inputs_missing"
		return result
	var renderer := _make_renderer()
	if renderer == null:
		result.reason = "candidate_renderer_missing"
		return result
	var candidate_texture: Texture2D = await renderer.apply_combine(compute_flow_texture, compute_flow_texture, foam_texture, noise_texture)
	_remove_renderer(renderer)
	candidate_texture = _postprocess_candidate_flow_texture(candidate_texture, river, bake_data)
	var candidate := _texture_to_image(candidate_texture)
	if candidate == null:
		result.reason = "candidate_postprocess_failed"
		return result
	var rects := _occupied_rects_from_bake(bake_data)
	if rects.is_empty():
		rects = [Rect2i(Vector2i.ZERO, legacy_image.get_size())]
	var compare := _compare_image_pair("flow_foam_noise", legacy_image, candidate, rects, true)
	compare["known_failure_target_records"] = _flow_target_records(legacy_image, candidate, _pressure_failure_target_points(), rects)
	_merge_prefixed_result(result, "", compare)
	result.ok = bool(compare.get("ok", false))
	result.reason = "ok" if bool(result.ok) else "generated_candidate_r7_tolerance_mismatch"
	return result


func _run_canonical_compute_acceptance_v1(projection_result: Dictionary, generated_candidate_parity: Dictionary, river: Node, out_dir: String) -> Dictionary:
	var result := {
		"ok": false,
		"automated_ok": false,
		"acceptance_complete": false,
		"visual_review_complete": false,
		"visual_review_status": "artifacts_generated_not_human_reviewed",
		"replacement_ready": false,
		"production_output_replaced": false,
		"output_texture_keys": [],
		"mode": "canonical_compute_acceptance_v1",
		"acceptance_gate": "R7_COMPUTE_CANONICAL_ACCEPTANCE_V1",
		"legacy_parity_gate": "R7_TOLERANCE_V1_DIAGNOSTIC_ONLY",
		"legacy_parity_ok": bool(generated_candidate_parity.get("ok", false)),
		"legacy_parity_blocks_replacement": false,
		"explicit_output_change_accepted_for_review": true,
		"bake_signature_version_decision": "no_signature_bump_until_replacement_ships",
		"fallback_selection_required": true,
		"fallback_selection_present": true,
		"fallback_selection_basis": "legacy_canvas_path_remains_default; compute remains non_replacing",
	}
	if not bool(projection_result.get("ok", false)):
		result.reason = "projection_compute_failed"
		return result
	var final_flow := projection_result.get("_debug_final_flow_image", null) as Image
	var projected_flow := projection_result.get("_debug_projected_flow_image", null) as Image
	var pressure := projection_result.get("_debug_pressure_image", null) as Image
	var divergence := projection_result.get("_debug_divergence_image", null) as Image
	var occupancy := _texture_to_image(_legacy_projection_capture.get("occupancy_input_texture", null) as Texture2D)
	if final_flow == null or projected_flow == null or pressure == null or divergence == null or occupancy == null:
		result.reason = "canonical_debug_images_missing"
		return result

	var source_size := maxf(1.0, float(projection_result.get("source_size", _legacy_projection_capture.get("source_size", 1.0))))
	var atlas_columns := maxi(1, int(projection_result.get("atlas_columns", _legacy_projection_capture.get("atlas_columns", 1))))
	var rects := _legacy_occupied_rects()
	if rects.is_empty():
		rects = [Rect2i(Vector2i.ZERO, final_flow.get_size())]

	var final_divergence := _make_flow_divergence_encoded_image(final_flow, occupancy, source_size, atlas_columns)
	if final_divergence == null:
		result.reason = "final_divergence_metric_image_failed"
		return result

	var final_flow_integrity := _image_numeric_integrity(final_flow, "final_flow")
	var projected_flow_integrity := _image_numeric_integrity(projected_flow, "projected_flow")
	var pressure_integrity := _image_numeric_integrity(pressure, "pressure")
	var divergence_integrity := _image_numeric_integrity(divergence, "divergence")
	var initial_divergence_metrics := _divergence_metrics_from_encoded_image(divergence, occupancy, rects)
	var final_divergence_metrics := _divergence_metrics_from_encoded_image(final_divergence, occupancy, rects)
	var flow_semantics := _canonical_flow_semantic_metrics(final_flow, occupancy, rects, source_size, atlas_columns)
	var projected_flow_semantics := _canonical_flow_semantic_metrics(projected_flow, occupancy, rects, source_size, atlas_columns)
	_merge_prefixed_result(result, "final_flow_integrity_", final_flow_integrity)
	_merge_prefixed_result(result, "projected_flow_integrity_", projected_flow_integrity)
	_merge_prefixed_result(result, "pressure_integrity_", pressure_integrity)
	_merge_prefixed_result(result, "divergence_integrity_", divergence_integrity)
	_merge_prefixed_result(result, "initial_divergence_", initial_divergence_metrics)
	_merge_prefixed_result(result, "final_divergence_", final_divergence_metrics)
	_merge_prefixed_result(result, "flow_semantics_", flow_semantics)
	_merge_prefixed_result(result, "projected_flow_semantics_", projected_flow_semantics)

	var canonical_rules_ok := (
		String(projection_result.get("pressure_feedback_target", "")) == "canonical_texel_space_compute"
		and bool(projection_result.get("canonical_integer_texel_addressing", false))
		and not bool(projection_result.get("canonical_canvasitem_uv_artifact_emulation", true))
		and not bool(projection_result.get("canonical_legacy_tie_rule_emulation", true))
		and bool(projection_result.get("pressure_feedback_rgba32f", false))
		and String(projection_result.get("pressure_texture_format", "")) == "R32G32B32A32_SFLOAT"
		and int(projection_result.get("pressure_jacobi_canvas_tie_mode", -1)) == 0
		and not bool(projection_result.get("pressure_override_used", true))
		and not bool(projection_result.get("pressure_jacobi_pass_limited", true))
		and bool(projection_result.get("rgba8_sampled_inputs_preserved", false))
	)
	var ownership_ok := (
		not bool(projection_result.get("production_output_replaced", true))
		and _output_texture_key_count(projection_result) == 0
		and river != null
		and bool(river.get("valid_flowmap"))
	)
	var integrity_ok := (
		int(final_flow_integrity.get("invalid_count", 1)) == 0
		and int(projected_flow_integrity.get("invalid_count", 1)) == 0
		and int(pressure_integrity.get("invalid_count", 1)) == 0
		and int(divergence_integrity.get("invalid_count", 1)) == 0
	)
	var initial_p99 := float(initial_divergence_metrics.get("p99_abs", 0.0))
	var final_p99 := float(final_divergence_metrics.get("p99_abs", 0.0))
	var initial_max := float(initial_divergence_metrics.get("max_abs", 0.0))
	var final_max := float(final_divergence_metrics.get("max_abs", 0.0))
	var divergence_ok := (
		final_p99 <= initial_p99
		and final_max <= maxf(initial_max * CANONICAL_DIVERGENCE_MAX_RATIO_GATE, initial_p99)
	)
	var projected_boundary_max := float(projected_flow_semantics.get("boundary_into_solid_max", 0.0))
	var projected_boundary_p99 := float(projected_flow_semantics.get("boundary_into_solid_p99", 0.0))
	var final_boundary_max := float(flow_semantics.get("boundary_into_solid_max", 1.0))
	var final_boundary_p99 := float(flow_semantics.get("boundary_into_solid_p99", 1.0))
	var flow_semantics_ok := (
		float(flow_semantics.get("solid_flow_max_magnitude", 1.0)) <= CANONICAL_SOLID_FLOW_MAX_GATE
		and float(flow_semantics.get("fluid_flow_max_magnitude", 99.0)) <= CANONICAL_FLOW_MAGNITUDE_MAX_GATE
		and final_boundary_max <= minf(CANONICAL_BOUNDARY_INTO_SOLID_MAX_GATE, projected_boundary_max + 0.0001)
		and final_boundary_p99 <= projected_boundary_p99 + 0.0001
	)
	var artifact_paths := _write_canonical_visual_artifacts(out_dir, projection_result, final_divergence)
	result.visual_artifact_paths = artifact_paths
	result.visual_artifact_count = artifact_paths.size()
	result.visual_artifacts_required_for_final_acceptance = true
	result.canonical_rules_ok = canonical_rules_ok
	result.ownership_ok = ownership_ok
	result.integrity_ok = integrity_ok
	result.divergence_ok = divergence_ok
	result.flow_semantics_ok = flow_semantics_ok
	result.automated_ok = canonical_rules_ok and ownership_ok and integrity_ok and divergence_ok and flow_semantics_ok and artifact_paths.size() >= 4
	result.ok = bool(result.automated_ok)
	result.reason = "automated_semantic_acceptance_ok_visual_review_pending" if bool(result.ok) else "automated_semantic_acceptance_failed"
	return result


func _image_numeric_integrity(image: Image, label: String) -> Dictionary:
	var result := {
		"label": label,
		"sample_count": 0,
		"invalid_count": 0,
		"out_of_range_count": 0,
		"min_value": INF,
		"max_value": -INF,
		"first_invalid": {},
	}
	if image == null or image.is_empty():
		result.invalid_count = 1
		result.reason = "image_missing"
		return result
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var values := [color.r, color.g, color.b, color.a]
			for channel_index in values.size():
				var value := float(values[channel_index])
				result.sample_count = int(result.sample_count) + 1
				if not _finite_float(value):
					result.invalid_count = int(result.invalid_count) + 1
					if (result.first_invalid as Dictionary).is_empty():
						result.first_invalid = {"x": x, "y": y, "channel": CHANNEL_NAMES[channel_index], "value": value}
					continue
				result.min_value = minf(float(result.min_value), value)
				result.max_value = maxf(float(result.max_value), value)
				if value < -0.0001 or value > 1.0001:
					result.out_of_range_count = int(result.out_of_range_count) + 1
					if (result.first_invalid as Dictionary).is_empty():
						result.first_invalid = {"x": x, "y": y, "channel": CHANNEL_NAMES[channel_index], "value": value}
	if int(result.out_of_range_count) > 0:
		result.invalid_count = int(result.invalid_count) + int(result.out_of_range_count)
	return result


func _finite_float(value: float) -> bool:
	return value == value and absf(value) < 1.0e20


func _divergence_metrics_from_encoded_image(divergence_image: Image, occupancy_image: Image, rects: Array) -> Dictionary:
	var abs_values := []
	var max_record := {}
	var sample_count := 0
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				if px < 0 or py < 0 or px >= divergence_image.get_width() or py >= divergence_image.get_height():
					continue
				if _is_solid_pixel(occupancy_image, px, py):
					continue
				var divergence := _decode_divergence(divergence_image.get_pixel(px, py).r)
				var abs_divergence := absf(divergence)
				abs_values.append(abs_divergence)
				sample_count += 1
				if max_record.is_empty() or abs_divergence > float(max_record.get("abs", -1.0)):
					max_record = {"x": px, "y": py, "divergence": divergence, "abs": abs_divergence}
	return {
		"sample_count": sample_count,
		"mean_abs": _mean_float(abs_values),
		"p95_abs": _percentile(abs_values, 0.95),
		"p99_abs": _percentile(abs_values, 0.99),
		"max_abs": _max_float(abs_values),
		"max_record": max_record,
	}


func _canonical_flow_semantic_metrics(flow_image: Image, occupancy_image: Image, rects: Array, source_size: float, atlas_columns: int) -> Dictionary:
	var solid_magnitudes := []
	var fluid_magnitudes := []
	var boundary_into_solid := []
	var max_solid_record := {}
	var max_boundary_record := {}
	var solid_count := 0
	var fluid_count := 0
	var boundary_sample_count := 0
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				if px < 0 or py < 0 or px >= flow_image.get_width() or py >= flow_image.get_height():
					continue
				var velocity := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(px, py))
				var magnitude := velocity.length()
				if _is_solid_pixel(occupancy_image, px, py):
					solid_count += 1
					solid_magnitudes.append(magnitude)
					if max_solid_record.is_empty() or magnitude > float(max_solid_record.get("magnitude", -1.0)):
						max_solid_record = {"x": px, "y": py, "magnitude": magnitude, "flow": velocity}
					continue
				fluid_count += 1
				fluid_magnitudes.append(magnitude)
				var boundary := _boundary_into_solid(flow_image, occupancy_image, Vector2i(px, py), source_size, atlas_columns)
				if bool(boundary.get("sampled", false)):
					boundary_sample_count += 1
					var into_solid := maxf(0.0, float(boundary.get("into_solid", 0.0)))
					boundary_into_solid.append(into_solid)
					if max_boundary_record.is_empty() or into_solid > float(max_boundary_record.get("into_solid", -1.0)):
						max_boundary_record = boundary
	return {
		"solid_sample_count": solid_count,
		"fluid_sample_count": fluid_count,
		"solid_flow_max_magnitude": _max_float(solid_magnitudes),
		"solid_flow_p99_magnitude": _percentile(solid_magnitudes, 0.99),
		"solid_flow_max_record": max_solid_record,
		"fluid_flow_p95_magnitude": _percentile(fluid_magnitudes, 0.95),
		"fluid_flow_p99_magnitude": _percentile(fluid_magnitudes, 0.99),
		"fluid_flow_max_magnitude": _max_float(fluid_magnitudes),
		"boundary_sample_count": boundary_sample_count,
		"boundary_into_solid_max": _max_float(boundary_into_solid),
		"boundary_into_solid_p99": _percentile(boundary_into_solid, 0.99),
		"boundary_into_solid_max_record": max_boundary_record,
	}


func _boundary_into_solid(flow_image: Image, occupancy_image: Image, point: Vector2i, source_size: float, atlas_columns: int) -> Dictionary:
	var base_uv := _pixel_center_uv_for_point(point, flow_image.get_size())
	var proximity := occupancy_image.get_pixel(point.x, point.y).g
	if proximity <= 0.10:
		return {"sampled": false}
	var step := 2.0 / maxf(source_size, 1.0)
	var toward_solid := Vector2(
		_proximity_at_uv(occupancy_image, _canonical_neighbor_uv(base_uv, Vector2(step, 0.0), atlas_columns).uv) - _proximity_at_uv(occupancy_image, _canonical_neighbor_uv(base_uv, Vector2(-step, 0.0), atlas_columns).uv),
		_proximity_at_uv(occupancy_image, _canonical_neighbor_uv(base_uv, Vector2(0.0, step), atlas_columns).uv) - _proximity_at_uv(occupancy_image, _canonical_neighbor_uv(base_uv, Vector2(0.0, -step), atlas_columns).uv)
	)
	var gradient_magnitude := toward_solid.length()
	if gradient_magnitude <= 0.0001:
		return {"sampled": false}
	var normal := toward_solid / gradient_magnitude
	var velocity := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(point.x, point.y))
	var into_solid := velocity.dot(normal)
	return {
		"sampled": true,
		"x": point.x,
		"y": point.y,
		"proximity": proximity,
		"normal": normal,
		"flow": velocity,
		"into_solid": into_solid,
	}


func _make_flow_divergence_encoded_image(flow_image: Image, occupancy_image: Image, source_size: float, atlas_columns: int) -> Image:
	if flow_image == null or occupancy_image == null or flow_image.is_empty() or occupancy_image.is_empty():
		return null
	var texture_size := flow_image.get_size()
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAF)
	var step := 1.0 / maxf(source_size, 1.0)
	for y in texture_size.y:
		for x in texture_size.x:
			if _is_solid_pixel(occupancy_image, x, y):
				image.set_pixel(x, y, Color(_encode_divergence(0.0), 0.0, 0.0, 1.0))
				continue
			var point := Vector2i(x, y)
			var center := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(x, y))
			var base_uv := _pixel_center_uv_for_point(point, texture_size)
			var left := _canonical_neighbor_velocity(flow_image, occupancy_image, base_uv, Vector2(-step, 0.0), Vector2(-1.0, 0.0), center, atlas_columns)
			var right := _canonical_neighbor_velocity(flow_image, occupancy_image, base_uv, Vector2(step, 0.0), Vector2(1.0, 0.0), center, atlas_columns)
			var up := _canonical_neighbor_velocity(flow_image, occupancy_image, base_uv, Vector2(0.0, -step), Vector2(0.0, -1.0), center, atlas_columns)
			var down := _canonical_neighbor_velocity(flow_image, occupancy_image, base_uv, Vector2(0.0, step), Vector2(0.0, 1.0), center, atlas_columns)
			var divergence := 0.5 * ((right.x - left.x) + (down.y - up.y))
			image.set_pixel(x, y, Color(_encode_divergence(divergence), 0.0, 0.0, 1.0))
	return image


func _canonical_neighbor_velocity(flow_image: Image, occupancy_image: Image, base_uv: Vector2, offset_uv: Vector2, axis_normal: Vector2, center_velocity: Vector2, atlas_columns: int) -> Vector2:
	var neighbor := _canonical_neighbor_uv(base_uv, offset_uv, atlas_columns)
	var sample_uv: Vector2 = neighbor.get("uv", base_uv)
	if bool(neighbor.get("hit_wall", false)) or _is_solid_uv(occupancy_image, sample_uv):
		return center_velocity - 2.0 * center_velocity.dot(axis_normal) * axis_normal
	return WaterHelperMethods.decode_packed_flow_vector(_sample_image_uv(flow_image, sample_uv))


func _canonical_neighbor_uv(base_uv: Vector2, offset_uv: Vector2, atlas_columns: int) -> Dictionary:
	var requested := base_uv + offset_uv
	var clamped := _canonical_atlas_column_clamp(requested, base_uv, atlas_columns)
	clamped.y = clampf(clamped.y, 0.0, 1.0)
	return {
		"uv": clamped,
		"hit_wall": absf(clamped.x - requested.x) > 0.0001,
	}


func _canonical_atlas_column_clamp(sample_uv: Vector2, base_uv: Vector2, atlas_columns: int) -> Vector2:
	var columns := maxf(float(atlas_columns), 1.0)
	if columns <= 1.0:
		return sample_uv
	var column_width := 1.0 / columns
	var column_min: float = floor(base_uv.x * columns) * column_width
	var padding := column_width * 0.02
	return Vector2(clampf(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y)


func _pixel_center_uv_for_point(point: Vector2i, texture_size: Vector2i) -> Vector2:
	return Vector2((float(point.x) + 0.5) / float(maxi(texture_size.x, 1)), (float(point.y) + 0.5) / float(maxi(texture_size.y, 1)))


func _is_solid_pixel(occupancy_image: Image, x: int, y: int) -> bool:
	if occupancy_image == null or occupancy_image.is_empty() or x < 0 or y < 0 or x >= occupancy_image.get_width() or y >= occupancy_image.get_height():
		return false
	return occupancy_image.get_pixel(x, y).r > 0.5


func _is_solid_uv(occupancy_image: Image, uv: Vector2) -> bool:
	return _sample_image_uv(occupancy_image, uv).r > 0.5


func _proximity_at_uv(occupancy_image: Image, uv: Vector2) -> float:
	return _sample_image_uv(occupancy_image, uv).g


func _sample_image_uv(image: Image, uv: Vector2) -> Color:
	if image == null or image.is_empty():
		return Color()
	var x := clampi(int(floor(clampf(uv.x, 0.0, 1.0) * float(image.get_width()))), 0, image.get_width() - 1)
	var y := clampi(int(floor(clampf(uv.y, 0.0, 1.0) * float(image.get_height()))), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _write_canonical_visual_artifacts(out_dir: String, projection_result: Dictionary, final_divergence: Image) -> Array:
	var paths := []
	var final_flow := projection_result.get("_debug_final_flow_image", null) as Image
	var projected_flow := projection_result.get("_debug_projected_flow_image", null) as Image
	var pressure := projection_result.get("_debug_pressure_image", null) as Image
	var divergence := projection_result.get("_debug_divergence_image", null) as Image
	_save_visual_artifact(final_flow, out_dir.path_join("r7_canonical_final_flow_rg.png"), paths)
	_save_visual_artifact(projected_flow, out_dir.path_join("r7_canonical_projected_flow_rg.png"), paths)
	_save_visual_artifact(pressure, out_dir.path_join("r7_canonical_pressure_r.png"), paths)
	_save_visual_artifact(_divergence_heat_image(divergence), out_dir.path_join("r7_canonical_divergence_before_abs.png"), paths)
	_save_visual_artifact(_divergence_heat_image(final_divergence), out_dir.path_join("r7_canonical_divergence_after_abs.png"), paths)
	return paths


func _save_visual_artifact(image: Image, path: String, paths: Array) -> void:
	if image == null or image.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_warnings.append("Could not create visual artifact parent " + parent + ": " + error_string(dir_error))
		return
	var writable := image.duplicate()
	writable.convert(Image.FORMAT_RGBA8)
	var save_error: Error = writable.save_png(absolute_path)
	if save_error != OK:
		_warnings.append("Could not write visual artifact " + absolute_path + ": " + error_string(save_error))
		return
	paths.append(path)


func _divergence_heat_image(divergence_image: Image) -> Image:
	if divergence_image == null or divergence_image.is_empty():
		return null
	var texture_size := divergence_image.get_size()
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	for y in texture_size.y:
		for x in texture_size.x:
			var divergence := absf(_decode_divergence(divergence_image.get_pixel(x, y).r))
			var value := clampf(divergence / 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return image


func _pressure_failure_target_points() -> Array:
	return [Vector2i(82, 47), Vector2i(61, 67)]


func _pressure_target_records(expected: Image, actual: Image, target_points: Array) -> Array:
	var records := []
	if expected == null or actual == null or expected.is_empty() or actual.is_empty():
		return records
	for point_variant in target_points:
		var point: Vector2i = point_variant
		if point.x < 0 or point.y < 0 or point.x >= expected.get_width() or point.y >= expected.get_height():
			continue
		var expected_encoded := expected.get_pixelv(point).r
		var actual_encoded := actual.get_pixelv(point).r
		var expected_pressure := _decode_pressure(expected_encoded)
		var actual_pressure := _decode_pressure(actual_encoded)
		records.append({
			"x": point.x,
			"y": point.y,
			"expected_encoded": expected_encoded,
			"actual_encoded": actual_encoded,
			"encoded_delta_signed": actual_encoded - expected_encoded,
			"encoded_delta_abs": absf(actual_encoded - expected_encoded),
			"expected_pressure": expected_pressure,
			"actual_pressure": actual_pressure,
			"pressure_delta_signed": actual_pressure - expected_pressure,
			"pressure_delta_abs": absf(actual_pressure - expected_pressure),
		})
	return records


func _flow_target_records(expected: Image, actual: Image, target_points: Array, rects: Array) -> Array:
	var records := []
	if expected == null or actual == null or expected.is_empty() or actual.is_empty():
		return records
	for point_variant in target_points:
		var point: Vector2i = point_variant
		if point.x < 0 or point.y < 0 or point.x >= expected.get_width() or point.y >= expected.get_height():
			continue
		var expected_color := expected.get_pixelv(point)
		var actual_color := actual.get_pixelv(point)
		var expected_flow := WaterHelperMethods.decode_packed_flow_vector(expected_color)
		var actual_flow := WaterHelperMethods.decode_packed_flow_vector(actual_color)
		var expected_magnitude := expected_flow.length()
		var actual_magnitude := actual_flow.length()
		var angle_delta := 180.0
		if actual_magnitude > 0.00001:
			angle_delta = absf(rad_to_deg(expected_flow.angle_to(actual_flow)))
		records.append({
			"x": point.x,
			"y": point.y,
			"expected_color": expected_color,
			"actual_color": actual_color,
			"signed_rg": Vector2(actual_color.r - expected_color.r, actual_color.g - expected_color.g),
			"expected_flow": expected_flow,
			"actual_flow": actual_flow,
			"expected_magnitude": expected_magnitude,
			"actual_magnitude": actual_magnitude,
			"magnitude_delta": absf(actual_magnitude - expected_magnitude),
			"endpoint_delta": expected_flow.distance_to(actual_flow),
			"angle_deg": angle_delta,
			"tile_edge_distance": _point_edge_distance_to_rects(point, rects),
		})
	return records


func _point_edge_distance_to_rects(point: Vector2i, rects: Array) -> int:
	var best := 1000000
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		if rect.has_point(point):
			best = mini(best, _rect_edge_distance(point, rect))
	return best if best < 1000000 else -1


func _postprocess_candidate_flow_texture(flow_foam_noise_texture: Texture2D, river: Node, bake_data: Resource) -> Texture2D:
	if flow_foam_noise_texture == null or river == null or bake_data == null:
		return null
	var content_rect: Rect2i = bake_data.get("content_rect")
	var source_size: Vector2i = bake_data.get("source_texture_size")
	var flowmap_resolution := source_size.x if source_size.x > 0 else content_rect.size.x
	var source_metadata: Dictionary = bake_data.get("source_metadata")
	var terrain_contact_texture := river.get("terrain_contact_features") as Texture2D
	var terrain_contact_image := _texture_to_image(terrain_contact_texture)
	var baker := RiverFlowmapBaker.new()
	var postprocess_result: Dictionary = baker.process_filter_pass_images({
		"warning_callback": Callable(self, "_record_warning"),
		"flowmap_resolution": flowmap_resolution,
		"uv2_sides": maxi(1, int(bake_data.get("uv2_sides"))),
		"steps": _step_count_from_bake(bake_data),
		"margin": content_rect.position.x,
		"flow_foam_noise_texture": flow_foam_noise_texture,
		"dist_pressure_texture": river.get("dist_pressure") as Texture2D,
		"obstacle_features_texture": river.get("obstacle_features") as Texture2D,
		"terrain_contact_with_margins_image": terrain_contact_image,
		"bank_response_features_texture": river.get("bank_response_features") as Texture2D,
		"water_occupancy_texture": river.get("water_occupancy") as Texture2D,
		"generation_behavior": String(source_metadata.get("generation_behavior", TARGET_GENERATION_BEHAVIOR)),
		"uses_downstream_baseline_generation": bool(source_metadata.get("downstream_baseline_applied", true)),
		"support_fallback_applied": bool(source_metadata.get("support_fallback_applied", false)),
		"support_fallback_reason": String(source_metadata.get("support_fallback_reason", "")),
		"collision_probe_skipped": bool(source_metadata.get("collision_probe_skipped", false)),
		"collision_support_filters_ran": bool(source_metadata.get("collision_support_filters_ran", true)),
		"obstacle_avoidance_applied": true,
		"flow_projected": true,
		"flat_foam_support_value": RiverManager.RIVER_FLAT_FOAM_SUPPORT_VALUE,
		"flat_pressure_support_value": RiverManager.RIVER_FLAT_PRESSURE_SUPPORT_VALUE,
		"near_neutral_threshold": WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
		"filtered_feature_edge_sync_depth_pixels": RiverManager.RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS,
		"bake_channel_flat_epsilon": RiverManager.BAKE_CHANNEL_FLAT_EPSILON,
		"bake_channel_low_contrast_epsilon": RiverManager.BAKE_CHANNEL_LOW_CONTRAST_EPSILON,
		"bake_channel_saturation_epsilon": RiverManager.BAKE_CHANNEL_SATURATION_EPSILON
	})
	baker.cleanup()
	if not bool(postprocess_result.get("ok", false)):
		return null
	return postprocess_result.get("flow_foam_noise_texture") as Texture2D


func _compare_image_pair(label: String, expected: Image, actual: Image, occupied_rects: Array, compare_flow: bool) -> Dictionary:
	var result := {
		"ok": false,
		"label": label,
	}
	if expected == null or actual == null or expected.is_empty() or actual.is_empty():
		result.reason = "image_missing"
		return result
	if expected.get_size() != actual.get_size():
		result.reason = "image_size_mismatch"
		result.expected_size = expected.get_size()
		result.actual_size = actual.get_size()
		return result
	var whole_metrics := _channel_delta_metrics(expected, actual, [Rect2i(Vector2i.ZERO, expected.get_size())])
	var occupied_metrics := _channel_delta_metrics(expected, actual, occupied_rects)
	_append_channel_metrics_to_result(result, "whole_", whole_metrics)
	_append_channel_metrics_to_result(result, "occupied_", occupied_metrics)
	_append_dictionary_to_result(result, "occupied_", _channel_failure_diagnostics(expected, actual, occupied_rects))
	var ok := _channel_metrics_pass(whole_metrics) and _channel_metrics_pass(occupied_metrics)
	if compare_flow:
		var flow_metrics := _flow_delta_metrics(expected, actual, occupied_rects)
		_append_dictionary_to_result(result, "decoded_flow_", flow_metrics)
		ok = ok and float(flow_metrics.get("p95_angle_deg", 999.0)) <= 2.0
		ok = ok and float(flow_metrics.get("max_angle_deg", 999.0)) <= 10.0
		ok = ok and float(flow_metrics.get("p95_magnitude_delta", 999.0)) <= 0.03
	result.ok = ok
	result.reason = "ok" if ok else "r7_tolerance_mismatch"
	return result


func _record_legacy_pass_inputs(label: String, args: Array) -> void:
	if label == "flow divergence map" and args.size() >= 4:
		_legacy_projection_capture["flow_input_texture"] = args[0]
		_legacy_projection_capture["occupancy_input_texture"] = args[1]
		_legacy_projection_capture["source_size"] = float(args[2])
		_legacy_projection_capture["atlas_columns"] = float(args[3])
	if label == "combined flow/foam/noise map" and args.size() >= 4:
		_legacy_projection_capture["flow_foam_noise_b_texture"] = args[2]
		_legacy_projection_capture["flow_foam_noise_a_texture"] = args[3]


func _record_legacy_pass_output(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	var texture := result.get("texture", null) as Texture2D
	if texture == null:
		return
	match label:
		"flow divergence map":
			_legacy_projection_capture["legacy_divergence_texture"] = texture
		"flow pressure jacobi pass":
			if not _legacy_projection_capture.has("legacy_pressure_textures"):
				_legacy_projection_capture["legacy_pressure_textures"] = []
			(_legacy_projection_capture["legacy_pressure_textures"] as Array).append(texture)
			_legacy_projection_capture["legacy_pressure_texture"] = texture
		"projected flow map":
			_legacy_projection_capture["legacy_projected_flow_texture"] = texture
		"boundary tangency flow map":
			_legacy_projection_capture["legacy_tangent_flow_texture"] = texture
			_legacy_projection_capture["tangency_pass_count"] = int(_legacy_projection_capture.get("tangency_pass_count", 0)) + 1
		"combined flow/foam/noise map":
			_legacy_projection_capture["legacy_flow_foam_noise_texture"] = texture


func _make_pass6_sampler_probe_points(texture_size: Vector2i, source_size: float, stride: int, atlas_columns: int) -> Array:
	var points := []
	var step_pixels := int(ceil(float(stride) / maxf(source_size, 1.0) * float(texture_size.y)))
	var y_top := clampi(step_pixels + 5, 1, texture_size.y - step_pixels - 2)
	var y_bottom := clampi(texture_size.y - step_pixels - 6, step_pixels + 1, texture_size.y - 2)
	var point_count := clampi(atlas_columns, 1, 5)
	for column_index in point_count:
		var column_width := float(texture_size.x) / float(maxi(atlas_columns, 1))
		var x := clampi(int(floor((float(column_index) + 0.5) * column_width)), 1, texture_size.x - 2)
		var y := y_top if column_index < int(ceil(float(point_count) * 0.5)) else y_bottom
		points.append(Vector2i(x, y))
	return points


func _make_pass6_sampler_grid_probe_points(texture_size: Vector2i, source_size: float, stride: int, atlas_columns: int) -> Array:
	var points := []
	var step_pixels := int(ceil(float(stride) / maxf(source_size, 1.0) * float(texture_size.y)))
	var y_min := clampi(step_pixels + 5, 1, texture_size.y - step_pixels - 2)
	var y_max := clampi(texture_size.y - step_pixels - 6, y_min, texture_size.y - 2)
	var point_count := clampi(atlas_columns, 1, 5)
	var y_rows := []
	for row_index in point_count:
		var t := 0.0 if point_count <= 1 else float(row_index) / float(point_count - 1)
		y_rows.append(clampi(int(round(lerpf(float(y_min), float(y_max), t))), 1, texture_size.y - 2))
	for row_y_variant in y_rows:
		var y := int(row_y_variant)
		for column_index in point_count:
			var column_width := float(texture_size.x) / float(maxi(atlas_columns, 1))
			var x := clampi(int(floor((float(column_index) + 0.5) * column_width)), 1, texture_size.x - 2)
			points.append(Vector2i(x, y))
	return points


func _make_pass6_sampler_scanline_probe_points(texture_size: Vector2i, source_size: float, stride: int, atlas_columns: int) -> Array:
	var points := []
	var grid_points := _make_pass6_sampler_grid_probe_points(texture_size, source_size, stride, atlas_columns)
	var y_rows := []
	for point_variant in grid_points:
		var point: Vector2i = point_variant
		if not y_rows.has(point.y):
			y_rows.append(point.y)
	if y_rows.is_empty():
		return points
	var x_positions := _make_pass6_sampler_scanline_x_positions(texture_size, atlas_columns)
	for y_variant in y_rows:
		var y := int(y_variant)
		for x_variant in x_positions:
			points.append(Vector2i(int(x_variant), y))
	return points


func _make_pass6_sampler_y_band_probe_points(texture_size: Vector2i, atlas_columns: int) -> Array:
	var points := []
	var x_positions := _make_pass6_sampler_scanline_x_positions(texture_size, atlas_columns)
	var y_min := clampi(PASS6_SAMPLER_Y_BAND_MIN, 1, texture_size.y - 2)
	var y_max := clampi(PASS6_SAMPLER_Y_BAND_MAX, y_min, texture_size.y - 2)
	for y in range(y_min, y_max + 1, maxi(1, PASS6_SAMPLER_Y_BAND_STEP)):
		for x_variant in x_positions:
			points.append(Vector2i(int(x_variant), y))
	return points


func _make_pass6_sampler_scanline_x_positions(texture_size: Vector2i, atlas_columns: int) -> Array:
	var x_count := clampi(PASS6_SAMPLER_SCANLINE_X_COUNT, 1, texture_size.x - 2)
	var x_positions := []
	for x_index in x_count:
		var t := 0.0 if x_count <= 1 else float(x_index) / float(x_count - 1)
		var x := clampi(int(round(lerpf(1.0, float(texture_size.x - 2), t))), 1, texture_size.x - 2)
		var base_uv_x := (float(x) + 0.5) / float(texture_size.x)
		if not _pass6_x_offset_hits_atlas_wall(base_uv_x, 0.0, atlas_columns) and not x_positions.has(x):
			x_positions.append(x)
	return x_positions


func _make_fill_image(texture_size: Vector2i, format: int, color: Color) -> Image:
	var image := Image.create(texture_size.x, texture_size.y, false, format)
	image.fill(color)
	return image


func _make_pass6_direction_pressure_image(texture_size: Vector2i, probe_points: Array, source_size: float, stride: int, direction: String) -> Image:
	var image := _make_fill_image(texture_size, Image.FORMAT_RGBAH, Color(_encode_pressure(0.0), 0.0, 0.0, 1.0))
	for point_index in probe_points.size():
		var point: Vector2i = probe_points[point_index]
		var candidates := _pass6_direction_candidates(point, texture_size, source_size, stride, direction)
		_set_pressure_pixel_band_x(image, point.x, int(candidates.get("lower_y", point.y)), _pass6_candidate_value(direction, point_index, "lower"))
		_set_pressure_pixel_band_x(image, point.x, int(candidates.get("upper_y", point.y)), _pass6_candidate_value(direction, point_index, "upper"))
	return image


func _make_pass6_center_pressure_image(texture_size: Vector2i, probe_points: Array) -> Image:
	var image := _make_fill_image(texture_size, Image.FORMAT_RGBAH, Color(_encode_pressure(0.0), 0.0, 0.0, 1.0))
	for point_index in probe_points.size():
		var point: Vector2i = probe_points[point_index]
		_set_pressure_pixel(image, point.x, point.y, _pass6_candidate_value("center", point_index, "center"))
	return image


func _summarize_pass6_direction_case(output_image: Image, probe_points: Array, source_size: float, stride: int, direction: String) -> Dictionary:
	var choices := []
	var lower_choice_count := 0
	var upper_choice_count := 0
	var compute_model_match_count := 0
	var max_choice_delta := 0.0
	if output_image == null or output_image.is_empty():
		return {
			"choices": choices,
			"lower_choice_count": 0,
			"upper_choice_count": 0,
			"compute_model_match_count": 0,
			"max_choice_delta": 0.0,
		}
	var texture_size := output_image.get_size()
	for point_index in probe_points.size():
		var point: Vector2i = probe_points[point_index]
		var candidates := _pass6_direction_candidates(point, texture_size, source_size, stride, direction)
		var lower_value := _pass6_candidate_value(direction, point_index, "lower")
		var upper_value := _pass6_candidate_value(direction, point_index, "upper")
		var actual_pressure := _decode_pressure(output_image.get_pixel(point.x, point.y).r)
		var inferred_neighbor := actual_pressure * 4.0
		var lower_delta := absf(inferred_neighbor - lower_value)
		var upper_delta := absf(inferred_neighbor - upper_value)
		var choice_label := "lower"
		var choice_y := int(candidates.get("lower_y", point.y))
		var choice_delta := lower_delta
		if upper_delta < lower_delta:
			choice_label = "upper"
			choice_y = int(candidates.get("upper_y", point.y))
			choice_delta = upper_delta
		if choice_label == "lower":
			lower_choice_count += 1
		else:
			upper_choice_count += 1
		if choice_y == int(candidates.get("compute_floor_uv_n_y", choice_y + 1)):
			compute_model_match_count += 1
		max_choice_delta = maxf(max_choice_delta, choice_delta)
		choices.append({
			"point": point,
			"actual_output_pressure": actual_pressure,
			"inferred_neighbor_pressure": inferred_neighbor,
			"choice": choice_label,
			"choice_y": choice_y,
			"choice_delta": choice_delta,
			"lower_y": int(candidates.get("lower_y", point.y)),
			"lower_pressure": lower_value,
			"upper_y": int(candidates.get("upper_y", point.y)),
			"upper_pressure": upper_value,
			"continuous_center_texel_y": float(candidates.get("continuous_center_texel_y", 0.0)),
			"compute_floor_uv_n_y": int(candidates.get("compute_floor_uv_n_y", point.y)),
		})
	return {
		"choices": choices,
		"lower_choice_count": lower_choice_count,
		"upper_choice_count": upper_choice_count,
		"compute_model_match_count": compute_model_match_count,
		"max_choice_delta": max_choice_delta,
	}


func _summarize_pass6_center_case(output_image: Image, probe_points: Array, source_size: float, stride: int, atlas_columns: int) -> Dictionary:
	var choices := []
	var wall_match_count := 0
	var max_wall_delta := 0.0
	if output_image == null or output_image.is_empty():
		return {
			"choices": choices,
			"wall_match_count": 0,
			"max_wall_delta": 0.0,
		}
	var texture_size := output_image.get_size()
	var step_uv := float(stride) / maxf(source_size, 1.0)
	for point_index in probe_points.size():
		var point: Vector2i = probe_points[point_index]
		var center_pressure := _pass6_candidate_value("center", point_index, "center")
		var actual_pressure := _decode_pressure(output_image.get_pixel(point.x, point.y).r)
		var expected_wall_pressure := center_pressure * 0.5
		var wall_delta := absf(actual_pressure - expected_wall_pressure)
		max_wall_delta = maxf(max_wall_delta, wall_delta)
		if wall_delta <= 0.03:
			wall_match_count += 1
		var base_uv_x := (float(point.x) + 0.5) / float(texture_size.x)
		choices.append({
			"point": point,
			"center_pressure": center_pressure,
			"actual_output_pressure": actual_pressure,
			"expected_wall_pressure": expected_wall_pressure,
			"wall_delta": wall_delta,
			"left_hit_wall": _pass6_x_offset_hits_atlas_wall(base_uv_x, -step_uv, atlas_columns),
			"right_hit_wall": _pass6_x_offset_hits_atlas_wall(base_uv_x, step_uv, atlas_columns),
		})
	return {
		"choices": choices,
		"wall_match_count": wall_match_count,
		"max_wall_delta": max_wall_delta,
	}


func _summarize_pass6_triangle_model(choices: Array, texture_size: Vector2i, source_size: float) -> Dictionary:
	var diagonal_match_count := 0
	var diagonal_mismatch_count := 0
	var antidiagonal_match_count := 0
	var source_edge_match_count := 0
	var source_edge_mismatch_count := 0
	var diagonal_mismatches := []
	var source_edge_mismatches := []
	var total_count := 0
	var source_edge_y := int(floor(maxf(source_size, 1.0))) - 1
	for choice_variant in choices:
		var choice: Dictionary = choice_variant
		var point: Vector2i = choice.get("point", Vector2i.ZERO)
		var actual_choice := String(choice.get("choice", ""))
		var diagonal_prediction := "upper" if point.x < point.y else "lower"
		var source_edge_prediction := "lower" if point.y == source_edge_y else diagonal_prediction
		var antidiagonal_prediction := "upper" if point.x + point.y < texture_size.x else "lower"
		total_count += 1
		if actual_choice == diagonal_prediction:
			diagonal_match_count += 1
		else:
			diagonal_mismatch_count += 1
			diagonal_mismatches.append({
				"point": point,
				"actual": actual_choice,
				"predicted": diagonal_prediction,
				"choice_y": int(choice.get("choice_y", 0)),
				"continuous_center_texel_y": float(choice.get("continuous_center_texel_y", 0.0)),
			})
		if actual_choice == antidiagonal_prediction:
			antidiagonal_match_count += 1
		if actual_choice == source_edge_prediction:
			source_edge_match_count += 1
		else:
			source_edge_mismatch_count += 1
			source_edge_mismatches.append({
				"point": point,
				"actual": actual_choice,
				"predicted": source_edge_prediction,
				"choice_y": int(choice.get("choice_y", 0)),
				"continuous_center_texel_y": float(choice.get("continuous_center_texel_y", 0.0)),
			})
	return {
		"sample_count": total_count,
		"diagonal_x_lt_y_match_count": diagonal_match_count,
		"diagonal_x_lt_y_mismatch_count": diagonal_mismatch_count,
		"diagonal_x_lt_y_match_ratio": float(diagonal_match_count) / float(total_count) if total_count > 0 else 0.0,
		"diagonal_x_lt_y_mismatches": diagonal_mismatches,
		"antidiagonal_x_plus_y_lt_size_match_count": antidiagonal_match_count,
		"source_edge_y": source_edge_y,
		"source_edge_match_count": source_edge_match_count,
		"source_edge_mismatch_count": source_edge_mismatch_count,
		"source_edge_match_ratio": float(source_edge_match_count) / float(total_count) if total_count > 0 else 0.0,
		"source_edge_mismatches": source_edge_mismatches,
	}


func _summarize_pass6_scanline_model(choices: Array, texture_size: Vector2i, source_size: float) -> Dictionary:
	var choices_by_y := {}
	var diagonal_match_count := 0
	var diagonal_mismatch_count := 0
	var source_edge_match_count := 0
	var source_edge_mismatch_count := 0
	var total_count := 0
	var source_edge_y := int(floor(maxf(source_size, 1.0))) - 1
	for choice_variant in choices:
		var choice: Dictionary = choice_variant
		var point: Vector2i = choice.get("point", Vector2i.ZERO)
		var key := str(point.y)
		if not choices_by_y.has(key):
			choices_by_y[key] = []
		(choices_by_y[key] as Array).append(choice)
		var actual_choice := String(choice.get("choice", ""))
		var diagonal_prediction := "upper" if point.x < point.y else "lower"
		var source_edge_prediction := "lower" if point.y == source_edge_y else diagonal_prediction
		total_count += 1
		if actual_choice == diagonal_prediction:
			diagonal_match_count += 1
		else:
			diagonal_mismatch_count += 1
		if actual_choice == source_edge_prediction:
			source_edge_match_count += 1
		else:
			source_edge_mismatch_count += 1
	var rows := []
	var transition_count := 0
	var row_keys := choices_by_y.keys()
	row_keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in row_keys:
		var row_choices: Array = choices_by_y[key]
		row_choices.sort_custom(func(a, b): return (a as Dictionary).get("point", Vector2i.ZERO).x < (b as Dictionary).get("point", Vector2i.ZERO).x)
		var upper_xs := []
		var lower_xs := []
		var pattern := ""
		var previous_choice := ""
		var row_transition_count := 0
		for row_choice_variant in row_choices:
			var row_choice: Dictionary = row_choice_variant
			var point: Vector2i = row_choice.get("point", Vector2i.ZERO)
			var actual_choice := String(row_choice.get("choice", ""))
			if actual_choice == "upper":
				upper_xs.append(point.x)
				pattern += "U"
			else:
				lower_xs.append(point.x)
				pattern += "L"
			if not previous_choice.is_empty() and previous_choice != actual_choice:
				row_transition_count += 1
			previous_choice = actual_choice
		transition_count += row_transition_count
		rows.append({
			"y": int(key),
			"sample_count": row_choices.size(),
			"upper_count": upper_xs.size(),
			"lower_count": lower_xs.size(),
			"first_upper_x": int(upper_xs.front()) if not upper_xs.is_empty() else -1,
			"last_upper_x": int(upper_xs.back()) if not upper_xs.is_empty() else -1,
			"first_lower_x": int(lower_xs.front()) if not lower_xs.is_empty() else -1,
			"last_lower_x": int(lower_xs.back()) if not lower_xs.is_empty() else -1,
			"transition_count": row_transition_count,
			"pattern": pattern,
		})
	return {
		"rows": rows,
		"transition_count": transition_count,
		"sample_count": total_count,
		"diagonal_x_lt_y_match_count": diagonal_match_count,
		"diagonal_x_lt_y_mismatch_count": diagonal_mismatch_count,
		"diagonal_x_lt_y_match_ratio": float(diagonal_match_count) / float(total_count) if total_count > 0 else 0.0,
		"source_edge_y": source_edge_y,
		"source_edge_match_count": source_edge_match_count,
		"source_edge_mismatch_count": source_edge_mismatch_count,
		"source_edge_match_ratio": float(source_edge_match_count) / float(total_count) if total_count > 0 else 0.0,
	}


func _pass6_direction_candidates(point: Vector2i, texture_size: Vector2i, source_size: float, stride: int, direction: String) -> Dictionary:
	var sign := -1.0 if direction == "up" else 1.0
	var offset_uv := sign * float(stride) / maxf(source_size, 1.0)
	var continuous_y := _sample_axis_center_texel(point.y, offset_uv, texture_size.y)
	return {
		"continuous_center_texel_y": continuous_y,
		"lower_y": clampi(int(floor(continuous_y)), 0, texture_size.y - 1),
		"upper_y": clampi(int(ceil(continuous_y)), 0, texture_size.y - 1),
		"compute_floor_uv_n_y": _sample_axis_floor_uv_n(point.y, offset_uv, texture_size.y),
	}


func _sample_axis_center_texel(pixel_index: int, offset_uv: float, axis_size: int) -> float:
	var base_uv := (float(pixel_index) + 0.5) / float(maxi(axis_size, 1))
	return (base_uv + offset_uv) * float(axis_size) - 0.5


func _sample_axis_floor_uv_n(pixel_index: int, offset_uv: float, axis_size: int) -> int:
	var base_uv := (float(pixel_index) + 0.5) / float(maxi(axis_size, 1))
	var sample_uv := clampf(base_uv + offset_uv, 0.0, 1.0)
	return clampi(int(floor(sample_uv * float(axis_size))), 0, axis_size - 1)


func _pass6_x_offset_hits_atlas_wall(base_uv_x: float, offset_uv_x: float, atlas_columns: int) -> bool:
	var columns := maxf(float(atlas_columns), 1.0)
	if columns <= 1.0:
		return false
	var requested := base_uv_x + offset_uv_x
	var column_width := 1.0 / columns
	var column_min: float = floor(base_uv_x * columns) * column_width
	var padding := column_width * 0.02
	var clamped := clampf(requested, column_min + padding, column_min + column_width - padding)
	return absf(clamped - requested) > 0.0001


func _pass6_candidate_value(direction: String, point_index: int, label: String) -> float:
	var point_offset := float(point_index % PASS6_SAMPLER_SCANLINE_X_COUNT) * PASS6_PRESSURE_POINT_OFFSET_STEP
	match direction:
		"up":
			return (2.0 if label == "lower" else 10.0) + point_offset
		"down":
			return (3.0 if label == "lower" else 11.0) + point_offset
		"center":
			return 8.0 + point_offset
	return 0.0


func _set_pressure_pixel(image: Image, x: int, y: int, pressure: float) -> void:
	if image == null or image.is_empty():
		return
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, Color(_encode_pressure(pressure), 0.0, 0.0, 1.0))


func _set_pressure_pixel_band_x(image: Image, x: int, y: int, pressure: float) -> void:
	for dx in range(-1, 2):
		_set_pressure_pixel(image, x + dx, y, pressure)


func _texture_to_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image := texture.get_image()
	return image.duplicate() if image != null and not image.is_empty() else null


func _legacy_occupied_rects() -> Array:
	var bake_data := _legacy_projection_capture.get("bake_data", null) as Resource
	return _occupied_rects_from_bake(bake_data)


func _occupied_rects_from_bake(bake_data: Resource) -> Array:
	if bake_data == null:
		return []
	var content_rect: Rect2i = bake_data.get("content_rect")
	var uv2_sides := maxi(1, int(bake_data.get("uv2_sides")))
	var steps := _step_count_from_bake(bake_data)
	var rects := []
	for step_index in steps:
		rects.append(WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, uv2_sides, content_rect))
	return rects


func _step_count_from_bake(bake_data: Resource) -> int:
	if bake_data == null:
		return 0
	var uv2_sides := maxi(1, int(bake_data.get("uv2_sides")))
	var signature = bake_data.get("source_signature")
	var steps := uv2_sides * uv2_sides
	if typeof(signature) == TYPE_DICTIONARY:
		steps = int((signature as Dictionary).get("step_count", steps))
	return clampi(steps, 0, uv2_sides * uv2_sides)


func _copy_flow_rg(candidate: Image, flow_image: Image, rects: Array) -> void:
	if candidate == null or flow_image == null:
		return
	var max_size := Vector2i(mini(candidate.get_width(), flow_image.get_width()), mini(candidate.get_height(), flow_image.get_height()))
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				if px < 0 or py < 0 or px >= max_size.x or py >= max_size.y:
					continue
				var target := candidate.get_pixel(px, py)
				var flow := flow_image.get_pixel(px, py)
				target.r = flow.r
				target.g = flow.g
				candidate.set_pixel(px, py, target)


func _channel_delta_metrics(expected: Image, actual: Image, rects: Array) -> Dictionary:
	var channel_deltas := [[], [], [], []]
	var signed_deltas := [[], [], [], []]
	var max_delta_records := [{}, {}, {}, {}]
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				if px < 0 or py < 0 or px >= expected.get_width() or py >= expected.get_height():
					continue
				var expected_color := expected.get_pixel(px, py)
				var actual_color := actual.get_pixel(px, py)
				var expected_values := [expected_color.r, expected_color.g, expected_color.b, expected_color.a]
				var actual_values := [actual_color.r, actual_color.g, actual_color.b, actual_color.a]
				for channel_index in 4:
					var signed_delta := float(actual_values[channel_index]) - float(expected_values[channel_index])
					var abs_delta := absf(signed_delta)
					channel_deltas[channel_index].append(abs_delta)
					signed_deltas[channel_index].append(signed_delta)
					if max_delta_records[channel_index].is_empty() or abs_delta > float(max_delta_records[channel_index].get("max_abs", -1.0)):
						max_delta_records[channel_index] = {
							"x": px,
							"y": py,
							"expected": float(expected_values[channel_index]),
							"actual": float(actual_values[channel_index]),
							"signed": signed_delta,
							"max_abs": abs_delta,
						}
	var metrics := {}
	for channel_index in 4:
		metrics[CHANNEL_NAMES[channel_index]] = {
			"sample_count": channel_deltas[channel_index].size(),
			"max_abs": _max_float(channel_deltas[channel_index]),
			"p99_abs": _percentile(channel_deltas[channel_index], 0.99),
			"mean_abs": _mean_float(channel_deltas[channel_index]),
			"signed_mean": _mean_float(signed_deltas[channel_index]),
			"signed_p01": _percentile(signed_deltas[channel_index], 0.01),
			"signed_p99": _percentile(signed_deltas[channel_index], 0.99),
			"max_delta_record": max_delta_records[channel_index],
		}
	return metrics


func _channel_failure_diagnostics(expected: Image, actual: Image, rects: Array) -> Dictionary:
	var result := {}
	if expected == null or actual == null or expected.is_empty() or actual.is_empty():
		return result
	for channel_index in [0, 1]:
		var channel_name := String(CHANNEL_NAMES[channel_index])
		var over_gate_count := 0
		var over_high_gate_count := 0
		var top_records := []
		var tile_buckets := {}
		for rect_index in rects.size():
			var rect: Rect2i = rects[rect_index]
			for y in rect.size.y:
				for x in rect.size.x:
					var px := rect.position.x + x
					var py := rect.position.y + y
					if px < 0 or py < 0 or px >= expected.get_width() or py >= expected.get_height():
						continue
					var expected_color := expected.get_pixel(px, py)
					var actual_color := actual.get_pixel(px, py)
					var expected_values := [expected_color.r, expected_color.g, expected_color.b, expected_color.a]
					var actual_values := [actual_color.r, actual_color.g, actual_color.b, actual_color.a]
					var signed_delta := float(actual_values[channel_index]) - float(expected_values[channel_index])
					var abs_delta := absf(signed_delta)
					if abs_delta <= CHANNEL_FAILURE_GATE:
						continue
					over_gate_count += 1
					if abs_delta > CHANNEL_FAILURE_HIGH_GATE:
						over_high_gate_count += 1
					var record := {
						"x": px,
						"y": py,
						"expected": float(expected_values[channel_index]),
						"actual": float(actual_values[channel_index]),
						"signed": signed_delta,
						"abs": abs_delta,
						"tile_index": rect_index,
						"tile_edge_distance": _rect_edge_distance(Vector2i(px, py), rect),
					}
					_insert_top_delta_record(top_records, record)
					var bucket_key := str(rect_index)
					if not tile_buckets.has(bucket_key):
						tile_buckets[bucket_key] = {
							"tile_index": rect_index,
							"rect_position": rect.position,
							"rect_size": rect.size,
							"count": 0,
							"high_count": 0,
							"signed_sum": 0.0,
							"max_abs": 0.0,
							"max_record": {},
						}
					var bucket: Dictionary = tile_buckets[bucket_key]
					bucket.count = int(bucket.get("count", 0)) + 1
					bucket.signed_sum = float(bucket.get("signed_sum", 0.0)) + signed_delta
					if abs_delta > CHANNEL_FAILURE_HIGH_GATE:
						bucket.high_count = int(bucket.get("high_count", 0)) + 1
					if abs_delta > float(bucket.get("max_abs", 0.0)):
						bucket.max_abs = abs_delta
						bucket.max_record = record
					tile_buckets[bucket_key] = bucket
		result[channel_name + "_over_0_006_count"] = over_gate_count
		result[channel_name + "_over_0_010_count"] = over_high_gate_count
		result[channel_name + "_top_delta_records"] = top_records
		result[channel_name + "_top_tile_buckets"] = _top_channel_failure_buckets(tile_buckets)
	return result


func _insert_top_delta_record(records: Array, record: Dictionary) -> void:
	var inserted := false
	for index in records.size():
		if float(record.get("abs", 0.0)) > float((records[index] as Dictionary).get("abs", 0.0)):
			records.insert(index, record)
			inserted = true
			break
	if not inserted:
		records.append(record)
	while records.size() > FAILURE_RECORD_LIMIT:
		records.pop_back()


func _top_channel_failure_buckets(tile_buckets: Dictionary) -> Array:
	var top_buckets := []
	for bucket in tile_buckets.values():
		var compact_bucket: Dictionary = bucket
		var count := int(compact_bucket.get("count", 0))
		compact_bucket["signed_mean"] = float(compact_bucket.get("signed_sum", 0.0)) / float(maxi(1, count))
		compact_bucket.erase("signed_sum")
		_insert_top_tile_bucket(top_buckets, compact_bucket)
	return top_buckets


func _insert_top_tile_bucket(records: Array, bucket: Dictionary) -> void:
	var inserted := false
	for index in records.size():
		var other: Dictionary = records[index]
		var bucket_count := int(bucket.get("count", 0))
		var other_count := int(other.get("count", 0))
		var bucket_max := float(bucket.get("max_abs", 0.0))
		var other_max := float(other.get("max_abs", 0.0))
		if bucket_count > other_count or (bucket_count == other_count and bucket_max > other_max):
			records.insert(index, bucket)
			inserted = true
			break
	if not inserted:
		records.append(bucket)
	while records.size() > FAILURE_RECORD_LIMIT:
		records.pop_back()


func _flow_delta_metrics(expected: Image, actual: Image, rects: Array) -> Dictionary:
	var angle_deltas := []
	var magnitude_deltas := []
	var endpoint_deltas := []
	var expected_magnitudes := []
	var actual_magnitudes := []
	var sample_count := 0
	var occupied_rect_sample_count := 0
	var skipped_expected_magnitude_count := 0
	var weighted_angle_sum := 0.0
	var weight_sum := 0.0
	var angle_over_2_count := 0
	var angle_over_5_count := 0
	var angle_over_10_count := 0
	var max_angle_record := {}
	var top_angle_records := []
	var low_magnitude_bucket := _empty_flow_audit_bucket()
	var mid_magnitude_bucket := _empty_flow_audit_bucket()
	var strong_magnitude_bucket := _empty_flow_audit_bucket()
	var edge_1px_bucket := _empty_flow_audit_bucket()
	var inner_1px_bucket := _empty_flow_audit_bucket()
	var edge_2px_bucket := _empty_flow_audit_bucket()
	var inner_2px_bucket := _empty_flow_audit_bucket()
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				if px < 0 or py < 0 or px >= expected.get_width() or py >= expected.get_height():
					continue
				occupied_rect_sample_count += 1
				var expected_flow := WaterHelperMethods.decode_packed_flow_vector(expected.get_pixel(px, py))
				var actual_flow := WaterHelperMethods.decode_packed_flow_vector(actual.get_pixel(px, py))
				var expected_magnitude := expected_flow.length()
				var actual_magnitude := actual_flow.length()
				if expected_magnitude < FLOW_MAGNITUDE_MIN:
					skipped_expected_magnitude_count += 1
					continue
				sample_count += 1
				expected_magnitudes.append(expected_magnitude)
				actual_magnitudes.append(actual_magnitude)
				var angle_delta := 180.0
				if actual_magnitude > 0.00001:
					angle_delta = absf(rad_to_deg(expected_flow.angle_to(actual_flow)))
				var magnitude_delta := absf(expected_magnitude - actual_magnitude)
				var endpoint_delta := expected_flow.distance_to(actual_flow)
				var edge_distance := _rect_edge_distance(Vector2i(px, py), rect)
				angle_deltas.append(angle_delta)
				magnitude_deltas.append(magnitude_delta)
				endpoint_deltas.append(endpoint_delta)
				weighted_angle_sum += angle_delta * expected_magnitude
				weight_sum += expected_magnitude
				if angle_delta > 2.0:
					angle_over_2_count += 1
				if angle_delta > 5.0:
					angle_over_5_count += 1
				if angle_delta > 10.0:
					angle_over_10_count += 1
				if max_angle_record.is_empty() or angle_delta > float(max_angle_record.get("angle_deg", -1.0)):
					max_angle_record = {
						"x": px,
						"y": py,
						"angle_deg": angle_delta,
						"expected_flow": expected_flow,
						"actual_flow": actual_flow,
						"expected_magnitude": expected_magnitude,
						"actual_magnitude": actual_magnitude,
						"magnitude_delta": magnitude_delta,
						"endpoint_delta": endpoint_delta,
						"tile_edge_distance": edge_distance,
						"within_tile_edge_1px": edge_distance <= FLOW_AUDIT_EDGE_BAND_PIXELS,
						"within_tile_edge_2px": edge_distance <= FLOW_AUDIT_CONFIDENCE_EDGE_BAND_PIXELS,
					}
				_insert_top_angle_record(top_angle_records, {
					"x": px,
					"y": py,
					"angle_deg": angle_delta,
					"expected_flow": expected_flow,
					"actual_flow": actual_flow,
					"expected_magnitude": expected_magnitude,
					"actual_magnitude": actual_magnitude,
					"magnitude_delta": magnitude_delta,
					"endpoint_delta": endpoint_delta,
					"tile_edge_distance": edge_distance,
				})
				if expected_magnitude < FLOW_AUDIT_LOW_MAGNITUDE_MAX:
					_add_flow_audit_sample(low_magnitude_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
				elif expected_magnitude < FLOW_AUDIT_STRONG_MAGNITUDE_MIN:
					_add_flow_audit_sample(mid_magnitude_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
				else:
					_add_flow_audit_sample(strong_magnitude_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
				if edge_distance <= FLOW_AUDIT_EDGE_BAND_PIXELS:
					_add_flow_audit_sample(edge_1px_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
				else:
					_add_flow_audit_sample(inner_1px_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
				if edge_distance <= FLOW_AUDIT_CONFIDENCE_EDGE_BAND_PIXELS:
					_add_flow_audit_sample(edge_2px_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
				else:
					_add_flow_audit_sample(inner_2px_bucket, angle_delta, magnitude_delta, endpoint_delta, expected_magnitude)
	var metrics := {
		"occupied_rect_sample_count": occupied_rect_sample_count,
		"skipped_expected_magnitude_lt_0_05": skipped_expected_magnitude_count,
		"sample_count": sample_count,
		"magnitude_mask": "expected_magnitude >= " + str(FLOW_MAGNITUDE_MIN),
		"p95_angle_deg": _percentile(angle_deltas, 0.95),
		"p99_angle_deg": _percentile(angle_deltas, 0.99),
		"max_angle_deg": _max_float(angle_deltas),
		"weighted_mean_angle_deg": weighted_angle_sum / weight_sum if weight_sum > 0.0 else 0.0,
		"angle_over_2_count": angle_over_2_count,
		"angle_over_5_count": angle_over_5_count,
		"angle_over_10_count": angle_over_10_count,
		"p95_magnitude_delta": _percentile(magnitude_deltas, 0.95),
		"p99_magnitude_delta": _percentile(magnitude_deltas, 0.99),
		"max_magnitude_delta": _max_float(magnitude_deltas),
		"p95_endpoint_delta": _percentile(endpoint_deltas, 0.95),
		"p99_endpoint_delta": _percentile(endpoint_deltas, 0.99),
		"max_endpoint_delta": _max_float(endpoint_deltas),
		"expected_magnitude_p05": _percentile(expected_magnitudes, 0.05),
		"expected_magnitude_p50": _percentile(expected_magnitudes, 0.50),
		"expected_magnitude_p95": _percentile(expected_magnitudes, 0.95),
		"actual_magnitude_p05": _percentile(actual_magnitudes, 0.05),
		"actual_magnitude_p50": _percentile(actual_magnitudes, 0.50),
		"actual_magnitude_p95": _percentile(actual_magnitudes, 0.95),
		"max_angle_record": max_angle_record,
		"top_angle_records": top_angle_records,
	}
	_append_flow_audit_bucket(metrics, "magnitude_0_05_to_0_10_", low_magnitude_bucket)
	_append_flow_audit_bucket(metrics, "magnitude_0_10_to_0_20_", mid_magnitude_bucket)
	_append_flow_audit_bucket(metrics, "magnitude_ge_0_20_", strong_magnitude_bucket)
	_append_flow_audit_bucket(metrics, "tile_edge_1px_", edge_1px_bucket)
	_append_flow_audit_bucket(metrics, "tile_inner_1px_", inner_1px_bucket)
	_append_flow_audit_bucket(metrics, "tile_edge_2px_", edge_2px_bucket)
	_append_flow_audit_bucket(metrics, "tile_inner_2px_", inner_2px_bucket)
	return metrics


func _insert_top_angle_record(records: Array, record: Dictionary) -> void:
	var inserted := false
	for index in records.size():
		if float(record.get("angle_deg", 0.0)) > float((records[index] as Dictionary).get("angle_deg", 0.0)):
			records.insert(index, record)
			inserted = true
			break
	if not inserted:
		records.append(record)
	while records.size() > FAILURE_RECORD_LIMIT:
		records.pop_back()


func _empty_flow_audit_bucket() -> Dictionary:
	return {
		"angles": [],
		"magnitude_deltas": [],
		"endpoint_deltas": [],
		"sample_count": 0,
		"weighted_angle_sum": 0.0,
		"weight_sum": 0.0,
		"angle_over_2_count": 0,
		"angle_over_5_count": 0,
		"angle_over_10_count": 0,
	}


func _add_flow_audit_sample(bucket: Dictionary, angle_delta: float, magnitude_delta: float, endpoint_delta: float, weight: float) -> void:
	(bucket["angles"] as Array).append(angle_delta)
	(bucket["magnitude_deltas"] as Array).append(magnitude_delta)
	(bucket["endpoint_deltas"] as Array).append(endpoint_delta)
	bucket["sample_count"] = int(bucket.get("sample_count", 0)) + 1
	bucket["weighted_angle_sum"] = float(bucket.get("weighted_angle_sum", 0.0)) + angle_delta * weight
	bucket["weight_sum"] = float(bucket.get("weight_sum", 0.0)) + weight
	if angle_delta > 2.0:
		bucket["angle_over_2_count"] = int(bucket.get("angle_over_2_count", 0)) + 1
	if angle_delta > 5.0:
		bucket["angle_over_5_count"] = int(bucket.get("angle_over_5_count", 0)) + 1
	if angle_delta > 10.0:
		bucket["angle_over_10_count"] = int(bucket.get("angle_over_10_count", 0)) + 1


func _append_flow_audit_bucket(metrics: Dictionary, prefix: String, bucket: Dictionary) -> void:
	var angles: Array = bucket.get("angles", [])
	var magnitude_deltas: Array = bucket.get("magnitude_deltas", [])
	var endpoint_deltas: Array = bucket.get("endpoint_deltas", [])
	var weight_sum := float(bucket.get("weight_sum", 0.0))
	metrics[prefix + "sample_count"] = int(bucket.get("sample_count", 0))
	metrics[prefix + "p95_angle_deg"] = _percentile(angles, 0.95)
	metrics[prefix + "p99_angle_deg"] = _percentile(angles, 0.99)
	metrics[prefix + "max_angle_deg"] = _max_float(angles)
	metrics[prefix + "weighted_mean_angle_deg"] = float(bucket.get("weighted_angle_sum", 0.0)) / weight_sum if weight_sum > 0.0 else 0.0
	metrics[prefix + "angle_over_2_count"] = int(bucket.get("angle_over_2_count", 0))
	metrics[prefix + "angle_over_5_count"] = int(bucket.get("angle_over_5_count", 0))
	metrics[prefix + "angle_over_10_count"] = int(bucket.get("angle_over_10_count", 0))
	metrics[prefix + "p95_magnitude_delta"] = _percentile(magnitude_deltas, 0.95)
	metrics[prefix + "p99_magnitude_delta"] = _percentile(magnitude_deltas, 0.99)
	metrics[prefix + "p95_endpoint_delta"] = _percentile(endpoint_deltas, 0.95)
	metrics[prefix + "p99_endpoint_delta"] = _percentile(endpoint_deltas, 0.99)
	metrics[prefix + "max_endpoint_delta"] = _max_float(endpoint_deltas)


func _rect_edge_distance(point: Vector2i, rect: Rect2i) -> int:
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1
	return mini(
		mini(point.x - rect.position.x, max_x - point.x),
		mini(point.y - rect.position.y, max_y - point.y)
	)


func _channel_metrics_pass(metrics: Dictionary) -> bool:
	for channel in CHANNEL_NAMES:
		var channel_metrics: Dictionary = metrics.get(channel, {})
		if float(channel_metrics.get("max_abs", 1.0)) > 0.02:
			return false
		if float(channel_metrics.get("p99_abs", 1.0)) > 0.006:
			return false
		if float(channel_metrics.get("mean_abs", 1.0)) > 0.0015:
			return false
	return true


func _append_channel_metrics_to_result(result: Dictionary, prefix: String, metrics: Dictionary) -> void:
	for channel in CHANNEL_NAMES:
		var channel_metrics: Dictionary = metrics.get(channel, {})
		result[prefix + channel + "_sample_count"] = int(channel_metrics.get("sample_count", 0))
		result[prefix + channel + "_max_abs"] = float(channel_metrics.get("max_abs", 0.0))
		result[prefix + channel + "_p99_abs"] = float(channel_metrics.get("p99_abs", 0.0))
		result[prefix + channel + "_mean_abs"] = float(channel_metrics.get("mean_abs", 0.0))
		result[prefix + channel + "_signed_mean"] = float(channel_metrics.get("signed_mean", 0.0))
		result[prefix + channel + "_signed_p01"] = float(channel_metrics.get("signed_p01", 0.0))
		result[prefix + channel + "_signed_p99"] = float(channel_metrics.get("signed_p99", 0.0))
		result[prefix + channel + "_max_delta_record"] = channel_metrics.get("max_delta_record", {})


func _append_dictionary_to_result(result: Dictionary, prefix: String, values: Dictionary) -> void:
	for key in values.keys():
		result[prefix + String(key)] = values[key]


func _merge_prefixed_result(target: Dictionary, prefix: String, source: Dictionary) -> void:
	for key in source.keys():
		target[prefix + String(key)] = source[key]


func _make_renderer() -> Node:
	var renderer_scene := load(FILTER_RENDERER_SCENE) as PackedScene
	if renderer_scene == null:
		return null
	var renderer := renderer_scene.instantiate()
	if renderer == null:
		return null
	root.add_child(renderer)
	return renderer


func _remove_renderer(renderer: Node) -> void:
	if renderer == null:
		return
	if renderer.get_parent() != null:
		renderer.get_parent().remove_child(renderer)
	renderer.queue_free()


func _load_fixture(scene_path: String) -> Node:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_errors.append("Could not load fixture scene " + scene_path + ".")
		return null
	var fixture := scene.instantiate()
	if fixture == null:
		_errors.append("Could not instantiate fixture scene " + scene_path + ".")
		return null
	root.add_child(fixture)
	return fixture


func _configure_fixture_river(river: Node) -> void:
	river.set("baking_resolution", 0)
	river.set("baking_raycast_layers", 1)
	river.set("shape_step_length_divs", 1)
	river.set("shape_step_width_divs", 1)
	river.set("bake_generation_behavior", TARGET_GENERATION_BEHAVIOR)
	var curve = river.get("curve")
	var point_count := 0
	if curve != null and curve.has_method("get_point_count"):
		point_count = int(curve.call("get_point_count"))
	var neutral_speeds := []
	for _index in maxi(1, point_count):
		neutral_speeds.append(1.0)
	river.set("flow_speeds", neutral_speeds)


func _run_legacy_bake(river: Node) -> bool:
	if river == null:
		return false
	await process_frame
	await process_frame
	_legacy_projection_capture = {}
	var capture_baker := R7CaptureBaker.new()
	capture_baker.trace_owner = self
	RiverManager._flowmap_bakers[river.get_instance_id()] = capture_baker
	river.call("bake_texture")
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		frame_count += 1
	var bake_data := river.get("bake_data") as Resource
	_legacy_projection_capture["bake_data"] = bake_data
	RiverManager._flowmap_bakers.erase(river.get_instance_id())
	return not bool(river.call("is_bake_in_progress")) and bake_data != null


func _river_output_state(river: Node) -> Dictionary:
	if river == null:
		return {}
	var bake_data = river.get("bake_data")
	var bake_path := ""
	var bake_data_id := 0
	if bake_data != null and bake_data is Resource:
		bake_path = (bake_data as Resource).resource_path
		bake_data_id = (bake_data as Resource).get_instance_id()
	return {
		"valid_flowmap": bool(river.get("valid_flowmap")),
		"bake_data_id": bake_data_id,
		"bake_data_path": bake_path,
		"flow_foam_noise_id": _object_id(river.get("flow_foam_noise")),
		"dist_pressure_id": _object_id(river.get("dist_pressure")),
		"obstacle_features_id": _object_id(river.get("obstacle_features")),
		"terrain_contact_features_id": _object_id(river.get("terrain_contact_features")),
		"bank_response_features_id": _object_id(river.get("bank_response_features")),
		"water_occupancy_id": _object_id(river.get("water_occupancy"))
	}


func _river_texture_hashes(river: Node) -> Dictionary:
	var hashes := {}
	if river == null:
		return hashes
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		hashes[texture_name] = _hash_texture(river.get(texture_name) as Texture2D)
	return hashes


func _hash_texture(texture: Texture2D) -> Dictionary:
	var entry := {
		"present": false,
		"size": Vector2i.ZERO,
		"format": -1,
		"md5": "absent",
	}
	if texture == null:
		return entry
	var image := texture.get_image()
	if image == null or image.is_empty():
		entry.md5 = "unreadable"
		return entry
	entry.present = true
	entry.size = image.get_size()
	entry.format = image.get_format()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	entry.md5 = context.finish().hex_encode()
	return entry


func _object_id(value: Variant) -> int:
	var object := value as Object
	return object.get_instance_id() if object != null else 0


func _output_texture_key_count(result: Dictionary) -> int:
	var output_keys = result.get("output_texture_keys", [])
	if typeof(output_keys) == TYPE_ARRAY or typeof(output_keys) == TYPE_PACKED_STRING_ARRAY:
		return output_keys.size()
	return 0


func _read_red_channel(image: Image) -> Array:
	var values := []
	if image == null or image.is_empty():
		return values
	values.resize(image.get_width() * image.get_height())
	var index := 0
	for y in image.get_height():
		for x in image.get_width():
			values[index] = image.get_pixel(x, y).r
			index += 1
	return values


func _pressure_compare_metrics(expected_encoded: Array, actual_encoded: Array, encoded_mismatch_threshold: float, pressure_mismatch_threshold: float) -> Dictionary:
	var encoded_deltas := []
	var pressure_deltas := []
	var first_mismatch := {}
	var sample_count := mini(expected_encoded.size(), actual_encoded.size())
	for index in sample_count:
		var expected := float(expected_encoded[index])
		var actual := float(actual_encoded[index])
		var encoded_delta := absf(expected - actual)
		var pressure_delta := absf(_decode_pressure(expected) - _decode_pressure(actual))
		encoded_deltas.append(encoded_delta)
		pressure_deltas.append(pressure_delta)
		if first_mismatch.is_empty() and (encoded_delta > encoded_mismatch_threshold or pressure_delta > pressure_mismatch_threshold):
			first_mismatch = {
				"index": index,
				"expected_encoded": expected,
				"actual_encoded": actual,
				"encoded_delta": encoded_delta,
				"pressure_delta": pressure_delta,
			}
	return {
		"sample_count": sample_count,
		"encoded_max_abs": _max_float(encoded_deltas),
		"encoded_p99_abs": _percentile(encoded_deltas, 0.99),
		"encoded_mean_abs": _mean_float(encoded_deltas),
		"pressure_max_abs": _max_float(pressure_deltas),
		"pressure_p99_abs": _percentile(pressure_deltas, 0.99),
		"pressure_mean_abs": _mean_float(pressure_deltas),
		"first_mismatch": first_mismatch,
	}


func _decode_pressure(encoded: float) -> float:
	return (encoded - 0.5) / FLOW_SOLVE_PRESSURE_SCALE


func _encode_pressure(value: float) -> float:
	return clampf(value * FLOW_SOLVE_PRESSURE_SCALE + 0.5, 0.0, 1.0)


func _decode_divergence(encoded: float) -> float:
	return (encoded - 0.5) / FLOW_SOLVE_DIV_SCALE


func _encode_divergence(value: float) -> float:
	return clampf(value * FLOW_SOLVE_DIV_SCALE + 0.5, 0.0, 1.0)


func _max_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := -INF
	for value in values:
		result = maxf(result, float(value))
	return result


func _mean_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += float(value)
	return sum / float(values.size())


func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


func _append_result(prefix: String, result: Dictionary) -> void:
	var keys := result.keys()
	keys.sort()
	for key in keys:
		if String(key).begins_with("_debug_"):
			continue
		_report_lines.append(prefix + "." + str(key) + "=" + str(result[key]))


func _record_warning(message: String) -> void:
	_warnings.append(message)


func _record_progress(percentage: float, label: String) -> void:
	_progress.append(str(percentage) + ":" + label)


func _write_report(file_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_errors.append("Could not create output parent " + parent + ": " + error_string(dir_error))
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write " + absolute_path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string("\n".join(_report_lines) + "\n")
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args


func _parse_int_list(value: String, fallback: Array) -> Array:
	var result := []
	if not value.strip_edges().is_empty():
		for part in value.split(",", false):
			result.append(maxi(1, int(part.strip_edges())))
	if result.is_empty():
		for fallback_value in fallback:
			result.append(maxi(1, int(fallback_value)))
	return result
