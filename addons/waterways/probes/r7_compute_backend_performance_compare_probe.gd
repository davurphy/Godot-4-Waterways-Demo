# River-refactor R7 backend performance comparison probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_backend_performance_compare_probe.gd -- out=res://.codex-research/r7-baselines/compute-backend-performance-compare
#
# Success marker: R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-backend-performance-compare"
const REPORT_FILE_NAME := "r7_compute_backend_performance_compare.txt"
const EXPECTED_MARKER := "R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 12000
const LOW_COST_DEFAULT_RUNS := 3
const AUTHORED_DEFAULT_RUNS := 1

const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

const REQUIRED_CASE_LABELS := [
	"r7_low_cost_fixture",
	"obstacle_flow_authored_river",
	"demo_authored_river",
]

const PERFORMANCE_CASES := [
	{
		"label": "r7_low_cost_fixture",
		"scene": "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn",
		"river": "Water River",
		"profile": "low_cost_controlled",
		"configured_settings": true,
		"run_group": "low_cost",
	},
	{
		"label": "obstacle_flow_authored_river",
		"scene": "res://Demo_obstacle_flow_test.tscn",
		"river": "WaterSystem/Water River",
		"profile": "authored_scene_settings",
		"configured_settings": false,
		"run_group": "authored",
	},
	{
		"label": "demo_authored_river",
		"scene": "res://Demo.tscn",
		"river": "WaterSystem/Water River",
		"profile": "authored_scene_settings",
		"configured_settings": false,
		"run_group": "authored",
	},
]


class R7PerformanceBaker:
	extends RiverFlowmapBaker

	var trace_owner: Object = null
	var backend_mode := RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM
	var gate_config := {}
	var injected_filter_config := {}
	var last_filter_result := {}
	var pass_counts := {}
	var pass_trace := []

	func run_filter_pass_sequence(config: Dictionary, progress: Callable = Callable(), cancellation: Callable = Callable()) -> Dictionary:
		var injected_config := config.duplicate(true)
		for key in gate_config.keys():
			injected_config[key] = gate_config[key]
		injected_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = backend_mode
		if trace_owner != null:
			injected_config["frame_wait_source"] = trace_owner
			if trace_owner.has_method("_record_warning"):
				injected_config["warning_callback"] = Callable(trace_owner, "_record_warning")
		if not injected_config.has("sync_wait_frames"):
			injected_config["sync_wait_frames"] = 3
		injected_filter_config = injected_config.duplicate(true)
		if trace_owner != null and trace_owner.has_method("_record_filter_config"):
			trace_owner.call("_record_filter_config", injected_filter_config)
		var result: Dictionary = await super.run_filter_pass_sequence(injected_config, progress, cancellation)
		last_filter_result = result.duplicate(true)
		if trace_owner != null and trace_owner.has_method("_record_filter_result"):
			trace_owner.call("_record_filter_result", last_filter_result)
		return result

	func _run_pass(label: String, pass_callable: Callable) -> Dictionary:
		var start_usec := Time.get_ticks_usec()
		var result: Dictionary = await super._run_pass(label, pass_callable)
		var end_usec := Time.get_ticks_usec()
		pass_counts[label] = int(pass_counts.get(label, 0)) + 1
		pass_trace.append({
			"label": label,
			"duration_ms": float(end_usec - start_usec) / 1000.0,
			"ok": bool(result.get("ok", false)),
			"reason": String(result.get("reason", "")),
		})
		if trace_owner != null and trace_owner.has_method("_record_backend_pass"):
			trace_owner.call("_record_backend_pass", label, start_usec, end_usec, bool(result.get("ok", false)), String(result.get("reason", "")))
		return result


var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _report_lines := PackedStringArray()
var _progress_events: Array = []
var _active_run_start_usec := 0
var _active_finished_usec := 0
var _active_filter_config := {}
var _active_filter_result := {}
var _active_pass_trace: Array = []
var _written_report := ""


func _initialize() -> void:
	Engine.time_scale = 1.0
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var low_cost_runs := maxi(1, int(args.get("low_cost_runs", str(LOW_COST_DEFAULT_RUNS))))
	var authored_runs := maxi(1, int(args.get("authored_runs", str(AUTHORED_DEFAULT_RUNS))))

	_report_lines.append("R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_DUMP v1")
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())
	_report_lines.append("default_backend_mode=" + RiverFlowmapBaker.get_default_flowmap_backend_mode())
	_report_lines.append("legacy_backend_mode=" + RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM)
	_report_lines.append("compute_backend_mode=" + RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING)
	_report_lines.append("low_cost_runs_per_backend=" + str(low_cost_runs))
	_report_lines.append("authored_runs_per_backend=" + str(authored_runs))
	_report_lines.append("save_output=false")
	_report_lines.append("comparison_scope=end_to_end_bake_texture_timing")
	_report_lines.append("performance_note=timings include source/collision/postprocess; canonical compute replaces the projection solve/filter branch only")

	var case_reports := []
	var passed_labels := PackedStringArray()
	var failed_labels := PackedStringArray()
	for case_value in PERFORMANCE_CASES:
		var spec := _dictionary_from_variant(case_value)
		var run_count := low_cost_runs if String(spec.get("run_group", "")) == "low_cost" else authored_runs
		var case_report := await _run_performance_case(spec, run_count)
		case_reports.append(case_report)
		var label := String(case_report.get("label", ""))
		if bool(case_report.get("ok", false)):
			passed_labels.append(label)
		else:
			failed_labels.append(label)
		_append_result("performance_case_" + label, case_report)

	var summary := _make_summary(case_reports, passed_labels, failed_labels)
	_append_result("performance_compare", summary)
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("errors=" + str(_errors))

	_verify_summary(summary)
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _run_performance_case(spec: Dictionary, run_count: int) -> Dictionary:
	var label := String(spec.get("label", "unnamed_case"))
	var legacy_runs := []
	var compute_runs := []
	for run_index in run_count:
		legacy_runs.append(await _run_single_backend_bake(spec, RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, {}, run_index))
	for run_index in run_count:
		compute_runs.append(await _run_single_backend_bake(spec, RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, _make_production_gate_config(), run_index))

	var legacy_summary := _summarize_backend_runs(legacy_runs, RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM)
	var compute_summary := _summarize_backend_runs(compute_runs, RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING)
	var comparison := _compare_backend_summaries(legacy_summary, compute_summary)
	var runtime_concerns := _runtime_concerns(legacy_summary, compute_summary)
	var ok := (
		bool(legacy_summary.get("ok", false))
		and bool(compute_summary.get("ok", false))
		and bool(comparison.get("ok", false))
	)
	return {
		"ok": ok,
		"reason": "ok" if ok else "backend_performance_case_failed",
		"label": label,
		"scene": String(spec.get("scene", "")),
		"river": String(spec.get("river", "")),
		"profile": String(spec.get("profile", "")),
		"runs_per_backend": run_count,
		"configured_settings": bool(spec.get("configured_settings", false)),
		"legacy": legacy_summary,
		"compute": compute_summary,
		"comparison": comparison,
		"visible_runtime_concerns": runtime_concerns,
	}


func _run_single_backend_bake(spec: Dictionary, backend_mode: String, gate_config: Dictionary, run_index: int) -> Dictionary:
	var scene_path := String(spec.get("scene", ""))
	var river_path := String(spec.get("river", ""))
	var label := String(spec.get("label", "unnamed_case"))
	var fixture := await _load_fixture(scene_path)
	var river := fixture.get_node_or_null(river_path) if fixture != null else null
	var result := {
		"ok": false,
		"reason": "not_run",
		"label": label,
		"scene": scene_path,
		"river": river_path,
		"run_index": run_index,
		"requested_backend_mode": backend_mode,
	}
	if river == null:
		result.reason = "river_not_found"
		_errors.append(label + " " + backend_mode + ": river not found at " + river_path + ".")
		_free_fixture(fixture)
		return result

	var original_config := _river_config_snapshot(river)
	if bool(spec.get("configured_settings", false)):
		_configure_low_cost_river(river)
	var configured_config := _river_config_snapshot(river)

	_active_filter_config = {}
	_active_filter_result = {}
	_active_pass_trace = []
	_progress_events = []
	_active_finished_usec = 0
	_active_run_start_usec = Time.get_ticks_usec()
	var frame_gaps := []
	var previous_frame_usec := _active_run_start_usec
	var progress_callable := Callable(self, "_on_progress_notified")
	if not river.progress_notified.is_connected(progress_callable):
		river.progress_notified.connect(progress_callable)

	var performance_baker := R7PerformanceBaker.new()
	performance_baker.trace_owner = self
	performance_baker.backend_mode = backend_mode
	performance_baker.gate_config = gate_config.duplicate(true)
	RiverManager._flowmap_bakers[river.get_instance_id()] = performance_baker
	river.call("bake_texture")
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_gaps.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
		frame_count += 1
	if bool(river.call("is_bake_in_progress")):
		_errors.append(label + " " + backend_mode + ": bake did not finish within " + str(MAX_BAKE_FRAMES) + " frames.")
		performance_baker.abort()
		await process_frame
	if _active_finished_usec <= 0:
		_active_finished_usec = Time.get_ticks_usec()
	if river.progress_notified.is_connected(progress_callable):
		river.progress_notified.disconnect(progress_callable)
	RiverManager._flowmap_bakers.erase(river.get_instance_id())

	var bake_data := river.get("bake_data") as Resource
	var metadata := _resource_dictionary(bake_data, "source_metadata")
	var selection := _dictionary_from_variant(_active_filter_result.get("flowmap_backend_selection", metadata.get("flowmap_backend_selection", {})))
	var replacement_result := _dictionary_from_variant(_active_filter_result.get("canonical_compute_replacement_result", metadata.get("canonical_compute_replacement_result", {})))
	var completed := bake_data != null and not bool(river.call("is_bake_in_progress"))
	var pass_counts := performance_baker.pass_counts.duplicate(true)
	var output_keys = _active_filter_result.get("output_texture_keys", metadata.get("output_texture_keys", PackedStringArray()))
	var selected_mode := String(_active_filter_result.get("flowmap_backend_mode", metadata.get("flowmap_backend_mode", "")))
	if selected_mode.is_empty():
		selected_mode = String(selection.get("selected_mode", ""))
	var fallback_applied := bool(selection.get("fallback_applied", selected_mode != backend_mode))
	var workload := _make_workload_report(metadata, _river_texture_hashes(river), pass_counts)
	var texture_hashes := _river_texture_hashes(river)
	result.ok = (
		completed
		and bool(workload.get("ok", false))
		and String(selection.get("requested_mode", backend_mode)) == backend_mode
		and selected_mode == backend_mode
		and not fallback_applied
	)
	result.reason = "ok" if bool(result.ok) else "backend_bake_failed_invariants"
	result.original_river_config = original_config
	result.configured_river_config = configured_config
	result.elapsed_ms = float(_active_finished_usec - _active_run_start_usec) / 1000.0
	result.frame_count = frame_count
	result.max_frame_gap_ms = _max_float(frame_gaps)
	result.p95_frame_gap_ms = _percentile(frame_gaps, 0.95)
	result.progress_event_count = _progress_events.size()
	result.progress_events = _progress_events.duplicate(true)
	result.pass_counts = pass_counts
	result.pass_trace = _trim_pass_trace(performance_baker.pass_trace)
	result.requested_backend_mode = backend_mode
	result.selected_backend_mode = selected_mode
	result.default_backend_mode = RiverFlowmapBaker.get_default_flowmap_backend_mode()
	result.backend_selection = selection
	result.fallback_applied = fallback_applied
	result.fallback_reason = String(selection.get("fallback_reason", ""))
	result.production_output_replaced = bool(_active_filter_result.get("production_output_replaced", metadata.get("production_output_replaced", false)))
	result.output_texture_keys = output_keys
	result.output_texture_key_count = _output_key_count(output_keys)
	result.replacement_summary = _replacement_summary(replacement_result)
	result.source_signature_version = int(bake_data.get("source_signature_version")) if bake_data != null else -1
	result.metadata_flowmap_backend_mode = String(metadata.get("flowmap_backend_mode", ""))
	result.metadata_output_texture_keys = metadata.get("output_texture_keys", PackedStringArray())
	result.support_fallback_applied = bool(metadata.get("support_fallback_applied", true))
	result.support_fallback_reason = String(metadata.get("support_fallback_reason", ""))
	result.flow_projected = bool(metadata.get("flow_projected", false))
	result.obstacle_avoidance_applied = bool(metadata.get("obstacle_avoidance_applied", false))
	result.collision_hit_pixel_count = int(metadata.get("collision_hit_pixel_count", 0))
	result.texture_hashes = texture_hashes
	result.workload = workload
	result.callback_warnings_seen = _warnings.size()
	result.filter_result_ok = bool(_active_filter_result.get("ok", false))

	_free_fixture(fixture)
	return result


func _load_fixture(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load fixture scene " + scene_path + ".")
		return null
	var fixture := packed.instantiate()
	if fixture == null:
		_errors.append("Could not instantiate fixture scene " + scene_path + ".")
		return null
	fixture.scene_file_path = scene_path
	root.add_child(fixture)
	current_scene = fixture
	await process_frame
	await physics_frame
	await physics_frame
	return fixture


func _free_fixture(fixture: Node) -> void:
	if fixture == null:
		return
	fixture.queue_free()
	current_scene = null
	await process_frame


func _configure_low_cost_river(river: Node) -> void:
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
	if river.has_method("set_flow_speeds"):
		river.call("set_flow_speeds", neutral_speeds)
	else:
		river.set("flow_speeds", neutral_speeds)


func _river_config_snapshot(river: Node) -> Dictionary:
	if river == null:
		return {}
	var flow_speeds = river.get("flow_speeds")
	var flow_speed_count := 0
	if typeof(flow_speeds) == TYPE_ARRAY:
		flow_speed_count = (flow_speeds as Array).size()
	var bake_data := river.get("bake_data") as Resource
	return {
		"baking_resolution": int(river.get("baking_resolution")),
		"baking_raycast_layers": int(river.get("baking_raycast_layers")),
		"shape_step_length_divs": int(river.get("shape_step_length_divs")),
		"shape_step_width_divs": int(river.get("shape_step_width_divs")),
		"bake_generation_behavior": String(river.get("bake_generation_behavior")),
		"flow_speed_count": flow_speed_count,
		"bake_data_path": bake_data.resource_path if bake_data != null else "",
	}


func _make_workload_report(metadata: Dictionary, texture_hashes: Dictionary, pass_counts: Dictionary) -> Dictionary:
	var all_textures_present := true
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var entry := _dictionary_from_variant(texture_hashes.get(texture_name, {}))
		if not bool(entry.get("present", false)):
			all_textures_present = false
	var ok := (
		bool(metadata.get("flow_projected", false))
		and bool(metadata.get("obstacle_avoidance_applied", false))
		and bool(metadata.get("collision_support_filters_ran", false))
		and bool(metadata.get("water_occupancy_baked", false))
		and not bool(metadata.get("support_fallback_applied", true))
		and not bool(metadata.get("collision_probe_skipped", true))
		and int(metadata.get("collision_hit_pixel_count", 0)) > 0
		and all_textures_present
	)
	return {
		"ok": ok,
		"flow_projected": bool(metadata.get("flow_projected", false)),
		"obstacle_avoidance_applied": bool(metadata.get("obstacle_avoidance_applied", false)),
		"collision_support_filters_ran": bool(metadata.get("collision_support_filters_ran", false)),
		"water_occupancy_baked": bool(metadata.get("water_occupancy_baked", false)),
		"support_fallback_applied": bool(metadata.get("support_fallback_applied", true)),
		"support_fallback_reason": String(metadata.get("support_fallback_reason", "")),
		"collision_probe_skipped": bool(metadata.get("collision_probe_skipped", true)),
		"collision_hit_pixel_count": int(metadata.get("collision_hit_pixel_count", 0)),
		"all_generated_textures_present": all_textures_present,
		"legacy_jacobi_pass_count": int(pass_counts.get("flow pressure jacobi pass", 0)),
		"legacy_boundary_tangency_pass_count": int(pass_counts.get("boundary tangency flow map", 0)),
	}


func _summarize_backend_runs(runs: Array, requested_backend_mode: String) -> Dictionary:
	var elapsed_values := []
	var frame_counts := []
	var max_gaps := []
	var p95_gaps := []
	var selected_modes := PackedStringArray()
	var output_keys := PackedStringArray()
	var texture_md5s := {}
	var fallback_any := false
	var fallback_reasons := PackedStringArray()
	var ok := not runs.is_empty()
	var production_output_replaced_any := false
	var replacement_summary := {}
	for run_value in runs:
		var run := _dictionary_from_variant(run_value)
		ok = ok and bool(run.get("ok", false))
		elapsed_values.append(float(run.get("elapsed_ms", 0.0)))
		frame_counts.append(int(run.get("frame_count", 0)))
		max_gaps.append(float(run.get("max_frame_gap_ms", 0.0)))
		p95_gaps.append(float(run.get("p95_frame_gap_ms", 0.0)))
		var selected_mode := String(run.get("selected_backend_mode", ""))
		if not selected_mode in selected_modes:
			selected_modes.append(selected_mode)
		if bool(run.get("fallback_applied", false)):
			fallback_any = true
			var fallback_reason := String(run.get("fallback_reason", ""))
			if not fallback_reason in fallback_reasons:
				fallback_reasons.append(fallback_reason)
		production_output_replaced_any = production_output_replaced_any or bool(run.get("production_output_replaced", false))
		for key in _variant_to_string_array(run.get("output_texture_keys", [])):
			if not key in output_keys:
				output_keys.append(key)
		if texture_md5s.is_empty():
			texture_md5s = _texture_md5s(_dictionary_from_variant(run.get("texture_hashes", {})))
		if replacement_summary.is_empty():
			replacement_summary = _dictionary_from_variant(run.get("replacement_summary", {}))
	var selected_mode_consistent := selected_modes.size() == 1 and (selected_modes[0] if selected_modes.size() > 0 else "") == requested_backend_mode
	ok = ok and selected_mode_consistent and not fallback_any
	return {
		"ok": ok,
		"requested_backend_mode": requested_backend_mode,
		"selected_modes": selected_modes,
		"selected_mode_consistent": selected_mode_consistent,
		"fallback_any": fallback_any,
		"fallback_reasons": fallback_reasons,
		"run_count": runs.size(),
		"elapsed_ms_median": _median(elapsed_values),
		"elapsed_ms_min": _min_float(elapsed_values),
		"elapsed_ms_max": _max_float(elapsed_values),
		"frame_count_median": _median_int(frame_counts),
		"max_frame_gap_ms_max": _max_float(max_gaps),
		"p95_frame_gap_ms_max": _max_float(p95_gaps),
		"production_output_replaced_any": production_output_replaced_any,
		"output_texture_keys": output_keys,
		"output_texture_key_count": output_keys.size(),
		"texture_md5s_first_run": texture_md5s,
		"replacement_summary_first_run": replacement_summary,
		"runs": runs,
	}


func _compare_backend_summaries(legacy_summary: Dictionary, compute_summary: Dictionary) -> Dictionary:
	var legacy_elapsed := float(legacy_summary.get("elapsed_ms_median", 0.0))
	var compute_elapsed := float(compute_summary.get("elapsed_ms_median", 0.0))
	var speedup := legacy_elapsed / compute_elapsed if compute_elapsed > 0.0 else 0.0
	var delta := compute_elapsed - legacy_elapsed
	var ok := bool(legacy_summary.get("ok", false)) and bool(compute_summary.get("ok", false)) and compute_elapsed > 0.0 and legacy_elapsed > 0.0
	return {
		"ok": ok,
		"legacy_elapsed_ms_median": legacy_elapsed,
		"compute_elapsed_ms_median": compute_elapsed,
		"compute_minus_legacy_ms": delta,
		"legacy_divided_by_compute": speedup,
		"compute_faster_than_legacy": compute_elapsed < legacy_elapsed,
		"legacy_output_texture_keys": legacy_summary.get("output_texture_keys", []),
		"compute_output_texture_keys": compute_summary.get("output_texture_keys", []),
	}


func _runtime_concerns(legacy_summary: Dictionary, compute_summary: Dictionary) -> PackedStringArray:
	var concerns := PackedStringArray()
	if bool(legacy_summary.get("fallback_any", false)):
		concerns.append("legacy_backend_fallback_reported")
	if bool(compute_summary.get("fallback_any", false)):
		concerns.append("compute_backend_fallback_reported")
	if float(legacy_summary.get("max_frame_gap_ms_max", 0.0)) > 1000.0:
		concerns.append("legacy_full_bake_frame_gap_exceeded_1000_ms")
	if float(compute_summary.get("max_frame_gap_ms_max", 0.0)) > 1000.0:
		concerns.append("compute_full_bake_frame_gap_exceeded_1000_ms")
	if concerns.is_empty():
		concerns.append("no_probe_runtime_concerns_observed; not_a_human_visible_review")
	return concerns


func _make_summary(case_reports: Array, passed_labels: PackedStringArray, failed_labels: PackedStringArray) -> Dictionary:
	var required_ok := true
	for label in REQUIRED_CASE_LABELS:
		if not _array_has_string(passed_labels, String(label)):
			required_ok = false
	var ok := required_ok and failed_labels.is_empty()
	return {
		"ok": ok,
		"marker": EXPECTED_MARKER,
		"case_count": case_reports.size(),
		"required_labels": PackedStringArray(REQUIRED_CASE_LABELS),
		"passed_labels": passed_labels,
		"failed_labels": failed_labels,
		"default_backend_mode": RiverFlowmapBaker.get_default_flowmap_backend_mode(),
		"legacy_canvas_item_available": true,
		"legacy_removal_decision": "not_approved",
		"tolerance_policy": "R7_TOLERANCE_V1_unchanged_no_R7_TOLERANCE_V2",
		"comparison_scope": "end_to_end_bake_texture_timing_for_identical_case_settings",
		"save_output": false,
		"console_warning_error_note": "external Godot console output captured beside this report",
	}


func _verify_summary(summary: Dictionary) -> void:
	_expect(bool(summary.get("ok", false)), "Performance comparison failed: " + str(summary))
	_expect(String(summary.get("marker", "")) == EXPECTED_MARKER, "Performance comparison marker changed.")
	_expect(String(summary.get("default_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "Default backend should remain canonical compute.")
	_expect(bool(summary.get("legacy_canvas_item_available", false)), "Performance comparison lost explicit legacy availability.")
	_expect(String(summary.get("legacy_removal_decision", "")) == "not_approved", "Performance comparison must not approve legacy removal.")


func _make_production_gate_config() -> Dictionary:
	return {
		"automated_canonical_acceptance_ok": true,
		"representative_visuals_ok": true,
		"selection_abort_ok": true,
		"cleanup_responsiveness_ok": true,
		"river_manager_surface_ok": true,
		"generated_output_replacement_staging_ok": true,
		"production_replacement_validation_ok": true,
		"source_signature_version": 29,
		"source_signature_includes_backend_mode": false,
	}


func _on_progress_notified(percentage: float, label: String) -> void:
	var now_usec := Time.get_ticks_usec()
	_progress_events.append({
		"elapsed_ms": float(now_usec - _active_run_start_usec) / 1000.0,
		"progress": percentage,
		"label": label,
	})
	if String(label) == "finished":
		_active_finished_usec = now_usec


func _record_filter_config(config: Dictionary) -> void:
	_active_filter_config = config.duplicate(true)


func _record_filter_result(result: Dictionary) -> void:
	_active_filter_result = result.duplicate(true)


func _record_backend_pass(label: String, start_usec: int, end_usec: int, ok: bool, reason: String) -> void:
	_active_pass_trace.append({
		"label": label,
		"start_ms": float(start_usec - _active_run_start_usec) / 1000.0,
		"end_ms": float(end_usec - _active_run_start_usec) / 1000.0,
		"duration_ms": float(end_usec - start_usec) / 1000.0,
		"ok": ok,
		"reason": reason,
	})


func _record_warning(message: String) -> void:
	_warnings.append(message)


func _replacement_summary(replacement_result: Dictionary) -> Dictionary:
	return {
		"ok": bool(replacement_result.get("ok", false)),
		"reason": String(replacement_result.get("reason", "")),
		"mode": String(replacement_result.get("mode", "")),
		"selected_readback_path": String(replacement_result.get("selected_readback_path", "")),
		"sync_wait_frames": int(replacement_result.get("sync_wait_frames", -1)),
		"submit_count": int(replacement_result.get("submit_count", -1)),
		"sync_count": int(replacement_result.get("sync_count", -1)),
		"dispatch_count": int(replacement_result.get("dispatch_count", -1)),
		"compute_barrier_count": int(replacement_result.get("compute_barrier_count", -1)),
		"readback_byte_count": int(replacement_result.get("readback_byte_count", -1)),
		"async_readback_selected": bool(replacement_result.get("async_readback_selected", false)),
		"production_output_replaced": bool(replacement_result.get("production_output_replaced", false)),
		"output_texture_keys": replacement_result.get("output_texture_keys", []),
	}


func _trim_pass_trace(pass_trace: Array) -> Array:
	var trimmed := []
	for index in mini(pass_trace.size(), 80):
		trimmed.append((pass_trace[index] as Dictionary).duplicate(true))
	if pass_trace.size() > trimmed.size():
		trimmed.append({
			"label": "truncated",
			"remaining_count": pass_trace.size() - trimmed.size(),
		})
	return trimmed


func _resource_dictionary(resource: Resource, property_name: String) -> Dictionary:
	if resource == null:
		return {}
	var value = resource.get(property_name)
	return _dictionary_from_variant(value)


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
	entry.md5 = _hash_image(image)
	return entry


func _hash_image(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	return context.finish().hex_encode()


func _texture_md5s(hashes: Dictionary) -> Dictionary:
	var md5s := {}
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		md5s[texture_name] = String(_dictionary_from_variant(hashes.get(texture_name, {})).get("md5", ""))
	return md5s


func _variant_to_string_array(values: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if typeof(values) != TYPE_ARRAY and typeof(values) != TYPE_PACKED_STRING_ARRAY:
		return result
	for value in values:
		result.append(String(value))
	return result


func _output_key_count(values: Variant) -> int:
	if typeof(values) == TYPE_ARRAY or typeof(values) == TYPE_PACKED_STRING_ARRAY:
		return values.size()
	return 0


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _array_has_string(values: Variant, target: String) -> bool:
	if typeof(values) != TYPE_ARRAY and typeof(values) != TYPE_PACKED_STRING_ARRAY:
		return false
	for value in values:
		if String(value) == target:
			return true
	return false


func _append_result(prefix: String, result: Dictionary) -> void:
	var keys := result.keys()
	keys.sort()
	for key in keys:
		var value = result[key]
		if value is Texture2D or value is Image:
			continue
		_report_lines.append(prefix + "." + str(key) + "=" + str(value))


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


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.find("=") < 0:
			continue
		var parts := text.split("=", false, 1)
		if parts.size() == 2:
			result[String(parts[0]).trim_prefix("--")] = parts[1]
	return result


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[middle])
	return (float(sorted[middle - 1]) + float(sorted[middle])) * 0.5


func _median_int(values: Array) -> int:
	return int(round(_median(values)))


func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * ratio)) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


func _min_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := INF
	for value in values:
		result = minf(result, float(value))
	return result


func _max_float(values: Array) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_BACKEND_PERFORMANCE_COMPARE_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
