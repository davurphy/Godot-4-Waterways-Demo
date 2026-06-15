# River-refactor R7 compute backend selection and active cleanup/abort probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_selection_abort_probe.gd -- out=res://.codex-research/r7-baselines/compute-selection-abort
#
# Success marker: R7_COMPUTE_SELECTION_ABORT_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")

const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-selection-abort"
const REPORT_FILE_NAME := "r7_compute_selection_abort.txt"
const MAX_COMPUTE_FRAMES := 900
const MAX_ALLOWED_FRAME_GAP_MS := 1000.0
const SYNTHETIC_TEXTURE_SIZE := Vector2i(106, 106)
const INTERRUPT_AFTER_FRAMES := 4
const INTERRUPT_SYNC_WAIT_FRAMES := 45
const COMPLETE_SYNC_WAIT_FRAMES := 3

var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _report_lines := PackedStringArray()
var _written_report := ""
var _active_compute_progress_events: Array = []
var _compute_async_done := false
var _compute_async_result := {}
var _free_target: Node = null
var _scene_close_target: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))

	_report_lines.append("R7_COMPUTE_SELECTION_ABORT_DUMP v1")
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())

	var selections := _verify_backend_selection()
	for key in selections.keys():
		_append_selection_lines("selection." + String(key), selections[key])

	var complete_run := await _measure_compute_projection(
		"compute_selection_complete",
		_make_compute_projection_config(_make_synthetic_projection_images(SYNTHETIC_TEXTURE_SIZE), COMPLETE_SYNC_WAIT_FRAMES),
		Callable()
	)
	_verify_complete_run(complete_run, "compute_selection_complete")
	_append_compute_lines("compute_selection_complete", complete_run)

	var abort_run := await _measure_interrupt_projection(
		"compute_abort_in_flight",
		_make_compute_projection_config(_make_synthetic_projection_images(SYNTHETIC_TEXTURE_SIZE), INTERRUPT_SYNC_WAIT_FRAMES),
		"abort"
	)
	_verify_interrupt_run(abort_run, "compute_abort_in_flight")
	_append_compute_lines("compute_abort_in_flight", abort_run)

	var free_run := await _measure_interrupt_projection(
		"compute_free_owner_in_flight",
		_make_compute_projection_config(_make_synthetic_projection_images(SYNTHETIC_TEXTURE_SIZE), INTERRUPT_SYNC_WAIT_FRAMES),
		"free"
	)
	_verify_interrupt_run(free_run, "compute_free_owner_in_flight")
	_append_compute_lines("compute_free_owner_in_flight", free_run)

	var scene_close_run := await _measure_interrupt_projection(
		"compute_scene_close_in_flight",
		_make_compute_projection_config(_make_synthetic_projection_images(SYNTHETIC_TEXTURE_SIZE), INTERRUPT_SYNC_WAIT_FRAMES),
		"scene_close"
	)
	_verify_interrupt_run(scene_close_run, "compute_scene_close_in_flight")
	_append_compute_lines("compute_scene_close_in_flight", scene_close_run)

	_report_lines.append("warnings=" + str(_warnings))
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_SELECTION_ABORT_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _verify_backend_selection() -> Dictionary:
	var baker := RiverFlowmapBaker.new()
	var default_selection := baker.select_flowmap_backend({})
	var explicit_legacy_config := {}
	explicit_legacy_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM
	var explicit_legacy := baker.select_flowmap_backend(explicit_legacy_config)
	var explicit_compute_config := {}
	explicit_compute_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_NON_REPLACING
	var explicit_compute := baker.select_flowmap_backend(explicit_compute_config)
	var replacing_compute_config := {}
	replacing_compute_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	var replacing_compute := baker.select_flowmap_backend(replacing_compute_config)
	var unsupported_config := {}
	unsupported_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = "unexpected_backend"
	var unsupported := baker.select_flowmap_backend(unsupported_config)

	_expect(String(default_selection.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "Default backend selection should use canonical compute for R7 in-game review.")
	_expect(String(default_selection.get("default_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "Default backend mode should report canonical compute for R7 in-game review.")
	_expect(not bool(default_selection.get("explicit_selection", true)), "Default backend selection should not be explicit.")
	_expect(not bool(default_selection.get("fallback_applied", true)), "Default backend selection should not need fallback.")
	_expect(bool(default_selection.get("canonical_compute_replacement_gate_ready", false)), "Default canonical compute review selection should supply accepted gate evidence.")
	_expect(bool(default_selection.get("production_output_replaced_by_compute", false)), "Default canonical compute review selection should replace the scoped generated output.")
	_expect(String(explicit_legacy.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, "Explicit legacy selection should choose legacy CanvasItem.")
	_expect(bool(explicit_legacy.get("explicit_selection", false)), "Explicit legacy selection should be recorded.")
	_expect(String(explicit_legacy.get("fallback_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, "Legacy fallback mode should remain available.")
	_expect(String(explicit_compute.get("requested_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_NON_REPLACING, "Explicit compute selection should preserve requested mode.")
	_expect(String(explicit_compute.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, "Non-replacing compute selection should fall back to legacy output.")
	_expect(bool(explicit_compute.get("fallback_applied", false)), "Non-replacing compute selection should report fallback.")
	_expect(String(explicit_compute.get("fallback_reason", "")) == "canonical_compute_non_replacing_is_report_only", "Non-replacing compute fallback reason changed.")
	_expect(not bool(explicit_compute.get("canonical_compute_replacement_ready", true)), "Canonical compute replacement must not be ready.")
	_expect(String(explicit_compute.get("canonical_compute_replacement_gate_id", "")) == "R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1", "Canonical compute replacement gate id changed.")
	_expect(String(explicit_compute.get("canonical_compute_replacement_gate_stage", "")) == "report_only_non_replacing", "Canonical compute replacement gate stage changed.")
	_expect(not bool(explicit_compute.get("canonical_compute_replacement_gate_ready", true)), "Canonical compute replacement gate must not be ready.")
	_expect(int(explicit_compute.get("canonical_compute_min_replacing_signature_version", -1)) == 29, "Canonical compute replacement should require signature version 29 or backend-keyed source signatures.")
	_expect(_selection_has_blocker(explicit_compute, "generated_output_replacement_staging_not_accepted"), "Canonical compute gate should block on generated-output replacement staging.")
	_expect(not _selection_has_blocker(explicit_compute, "source_signature_version_29_or_backend_mode_signature_key_required"), "Canonical compute gate should not block on the accepted signature policy.")
	_expect(not _selection_has_blocker(explicit_compute, "canonical_compute_replacement_code_path_disabled"), "Canonical compute gate should not block on the enabled replacement code path.")
	_expect(not bool(explicit_compute.get("production_output_replaced_by_compute", true)), "Canonical compute selection must not replace production output.")
	_expect(int(explicit_compute.get("source_signature_version", -1)) == 29, "Signature version should be 29 before canonical compute can replace output.")
	_expect(not bool(explicit_compute.get("source_signature_requires_backend_or_version_bump_before_compute_replacement", true)), "Source signature policy should be accepted.")
	_expect(String(replacing_compute.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, "Unpromoted replacing compute selection should fall back to legacy output.")
	_expect(String(replacing_compute.get("fallback_reason", "")) == "canonical_compute_replacing_not_promoted", "Replacing compute fallback reason changed.")
	_expect(not bool(replacing_compute.get("canonical_compute_replacement_gate_ready", true)), "Replacing compute request should still fail the replacement gate.")
	_expect(_selection_has_blocker(replacing_compute, "generated_output_replacement_staging_not_accepted"), "Replacing compute gate should block on generated-output replacement staging.")
	_expect(not _selection_has_blocker(replacing_compute, "source_signature_version_29_or_backend_mode_signature_key_required"), "Replacing compute gate should not block on the accepted signature policy.")
	_expect(not _selection_has_blocker(replacing_compute, "canonical_compute_replacement_code_path_disabled"), "Replacing compute gate should not block on the enabled replacement code path.")
	_expect(not bool(unsupported.get("requested_mode_supported", true)), "Unsupported backend mode should be reported.")
	_expect(String(unsupported.get("raw_requested_mode", "")) == "unexpected_backend", "Unsupported backend mode should preserve raw request.")
	_expect(String(unsupported.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, "Unsupported backend mode should fall back to legacy output.")

	return {
		"default": default_selection,
		"explicit_legacy": explicit_legacy,
		"explicit_compute_non_replacing": explicit_compute,
		"explicit_compute_replacing_unpromoted": replacing_compute,
		"unsupported": unsupported,
	}


func _make_synthetic_projection_images(texture_size: Vector2i) -> Dictionary:
	var flow := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	var occupancy := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(texture_size.x) * 0.52, float(texture_size.y) * 0.48)
	for y in texture_size.y:
		for x in texture_size.x:
			var u := float(x) / maxf(1.0, float(texture_size.x - 1))
			var v := float(y) / maxf(1.0, float(texture_size.y - 1))
			var vx := 0.18 + sin(v * TAU * 1.5) * 0.08
			var vy := cos(u * TAU * 1.25) * 0.10
			flow.set_pixel(x, y, Color(clampf(0.5 + vx, 0.0, 1.0), clampf(0.5 + vy, 0.0, 1.0), 0.0, 1.0))

			var p := Vector2(float(x), float(y))
			var solid_box := absf(p.x - center.x) <= 8.0 and absf(p.y - center.y) <= 14.0
			var edge_distance := maxf(absf(p.x - center.x) - 8.0, absf(p.y - center.y) - 14.0)
			var proximity := clampf(1.0 - maxf(edge_distance, 0.0) / 18.0, 0.0, 1.0)
			occupancy.set_pixel(x, y, Color(1.0 if solid_box else 0.0, proximity, 0.0, 1.0))
	return {
		"flow_image": flow,
		"occupancy_image": occupancy,
	}


func _make_compute_projection_config(images: Dictionary, sync_wait_frames: int) -> Dictionary:
	var config := {
		"flow_image": images.get("flow_image"),
		"occupancy_image": images.get("occupancy_image"),
		"frame_wait_source": self,
		"warning_callback": Callable(self, "_record_warning"),
		"source_size": 64.0,
		"atlas_columns": 5,
		"solve_local_size": 8,
		"flow_projection_strides": [32, 16, 8, 4, 2, 1, 1, 1],
		"flow_projection_iterations_per_stride": 5,
		"flow_tangency_passes": 2,
		"sync_wait_frames": sync_wait_frames,
		"replacement_path_guarded": true,
	}
	config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_NON_REPLACING
	return config


func _measure_compute_projection(label: String, config: Dictionary, cancellation: Callable) -> Dictionary:
	var baker := RiverFlowmapBaker.new()
	_compute_async_done = false
	_compute_async_result = {}
	_active_compute_progress_events = []
	var start_usec := Time.get_ticks_usec()
	var previous_frame_usec := start_usec
	var frame_gaps: Array = []
	_start_compute_projection(baker, config, cancellation)
	var frame_count := 0
	while not _compute_async_done and frame_count < MAX_COMPUTE_FRAMES:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_gaps.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
		frame_count += 1
	if not _compute_async_done:
		_errors.append(label + ": Compute projection did not finish within " + str(MAX_COMPUTE_FRAMES) + " frames.")
		baker.abort()
		await process_frame
	var finish_usec := Time.get_ticks_usec()
	var running_after_result := baker.is_running()
	baker.cleanup()
	var running_after_cleanup := baker.is_running()
	baker.abort()
	baker.cleanup()
	return {
		"completed": _compute_async_done,
		"label": label,
		"elapsed_ms": float(finish_usec - start_usec) / 1000.0,
		"frame_gaps_ms": frame_gaps.duplicate(),
		"frame_count": frame_count,
		"max_frame_gap_ms": _max_float(frame_gaps),
		"p95_frame_gap_ms": _percentile(frame_gaps, 0.95),
		"progress_events": _active_compute_progress_events.duplicate(true),
		"compute_result": _sanitize_compute_result(_compute_async_result),
		"baker_running_after_result": running_after_result,
		"baker_running_after_cleanup": running_after_cleanup,
		"interrupt_applied": false,
	}


func _measure_interrupt_projection(label: String, config: Dictionary, interrupt_kind: String) -> Dictionary:
	var baker := RiverFlowmapBaker.new()
	_compute_async_done = false
	_compute_async_result = {}
	_active_compute_progress_events = []
	_free_target = null
	_scene_close_target = null
	var cancellation := Callable()
	if interrupt_kind == "free":
		_free_target = Node.new()
		_free_target.name = "R7ComputeFreeTarget"
		root.add_child(_free_target)
		cancellation = Callable(self, "_free_target_cancelled")
	elif interrupt_kind == "scene_close":
		_scene_close_target = Node3D.new()
		_scene_close_target.name = "R7ComputeSceneCloseTarget"
		root.add_child(_scene_close_target)
		current_scene = _scene_close_target
		config["frame_wait_source"] = _scene_close_target
		cancellation = Callable(self, "_scene_close_cancelled")

	var start_usec := Time.get_ticks_usec()
	var previous_frame_usec := start_usec
	var frame_gaps: Array = []
	_start_compute_projection(baker, config, cancellation)
	var frame_count := 0
	var interrupt_applied := false
	while not _compute_async_done and frame_count < MAX_COMPUTE_FRAMES:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_gaps.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
		frame_count += 1
		if not interrupt_applied and frame_count >= INTERRUPT_AFTER_FRAMES:
			_apply_interrupt(baker, interrupt_kind)
			interrupt_applied = true
	if not _compute_async_done:
		_errors.append(label + ": Compute projection did not finish within " + str(MAX_COMPUTE_FRAMES) + " frames.")
		baker.abort()
		await process_frame
	var finish_usec := Time.get_ticks_usec()
	var running_after_result := baker.is_running()
	baker.cleanup()
	var running_after_cleanup := baker.is_running()
	baker.abort()
	baker.cleanup()
	_free_target = null
	_scene_close_target = null
	current_scene = null
	return {
		"completed": _compute_async_done,
		"label": label,
		"interrupt_kind": interrupt_kind,
		"interrupt_applied": interrupt_applied,
		"elapsed_ms": float(finish_usec - start_usec) / 1000.0,
		"frame_gaps_ms": frame_gaps.duplicate(),
		"frame_count": frame_count,
		"max_frame_gap_ms": _max_float(frame_gaps),
		"p95_frame_gap_ms": _percentile(frame_gaps, 0.95),
		"progress_events": _active_compute_progress_events.duplicate(true),
		"compute_result": _sanitize_compute_result(_compute_async_result),
		"baker_running_after_result": running_after_result,
		"baker_running_after_cleanup": running_after_cleanup,
	}


func _apply_interrupt(baker: RefCounted, interrupt_kind: String) -> void:
	if interrupt_kind == "abort":
		baker.call("abort")
		baker.call("cleanup")
	elif interrupt_kind == "free":
		if _free_target != null and is_instance_valid(_free_target):
			_free_target.queue_free()
	elif interrupt_kind == "scene_close":
		if _scene_close_target != null and is_instance_valid(_scene_close_target):
			_scene_close_target.queue_free()
		current_scene = null


func _start_compute_projection(baker: RefCounted, config: Dictionary, cancellation: Callable) -> void:
	_compute_async_result = await baker.call(
		"run_non_replacing_compute_solve_filter_projection_probe",
		config,
		Callable(self, "_record_compute_progress"),
		cancellation
	)
	_compute_async_done = true


func _free_target_cancelled() -> bool:
	return _free_target == null or not is_instance_valid(_free_target) or _free_target.is_queued_for_deletion()


func _scene_close_cancelled() -> bool:
	return _scene_close_target == null or not is_instance_valid(_scene_close_target) or _scene_close_target.is_queued_for_deletion()


func _verify_complete_run(run: Dictionary, label: String) -> void:
	_expect(bool(run.get("completed", false)), label + ": async wrapper did not complete.")
	_expect(float(run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, label + ": max frame gap exceeded " + str(MAX_ALLOWED_FRAME_GAP_MS) + " ms.")
	_expect(not bool(run.get("baker_running_after_result", true)), label + ": baker should not remain running after completed compute.")
	_expect(not bool(run.get("baker_running_after_cleanup", true)), label + ": baker should not remain running after cleanup.")
	var result: Dictionary = run.get("compute_result", {})
	_expect(bool(result.get("ok", false)), label + ": compute projection did not return ok=true: " + str(result))
	_expect(not bool(result.get("production_output_replaced", true)), label + ": compute projection must not replace production output.")
	_expect(_output_texture_key_count(result) == 0, label + ": compute projection returned output texture keys before replacement is allowed.")
	_expect(not bool(result.get("async_readback_selected", true)), label + ": compute projection selected async readback.")
	_expect(String(result.get("selected_readback_path", "")).find("delayed_single_submit_wait_") >= 0, label + ": compute projection did not use the delayed sync/readback path.")
	_expect(int(result.get("submit_count", 0)) == 1, label + ": compute projection should submit once.")
	_expect(bool(result.get("cleanup_completed", false)), label + ": compute projection did not report cleanup completion.")
	_expect(int(result.get("cleanup_owned_rid_count_after_cleanup", -1)) == 0, label + ": compute projection leaked owned RIDs.")
	_expect(bool(result.get("cleanup_rendering_device_released", false)), label + ": compute projection did not release the local RenderingDevice.")
	_expect(not bool(result.get("cleanup_submitted_without_sync_after_cleanup", true)), label + ": compute projection left submitted work unsynced after cleanup.")
	_expect(bool(result.get("canonical_integer_texel_addressing", false)), label + ": compute projection did not report canonical integer texel-space addressing.")


func _verify_interrupt_run(run: Dictionary, label: String) -> void:
	_expect(bool(run.get("completed", false)), label + ": async wrapper did not complete.")
	_expect(bool(run.get("interrupt_applied", false)), label + ": interrupt was not applied.")
	_expect(float(run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, label + ": max frame gap exceeded " + str(MAX_ALLOWED_FRAME_GAP_MS) + " ms.")
	_expect(not bool(run.get("baker_running_after_result", true)), label + ": baker should not remain running after interrupted compute.")
	_expect(not bool(run.get("baker_running_after_cleanup", true)), label + ": baker should not remain running after interrupted cleanup.")
	var result: Dictionary = run.get("compute_result", {})
	_expect(not bool(result.get("ok", true)), label + ": interrupted compute projection should not return ok=true.")
	_expect(String(result.get("reason", "")) == "cancelled", label + ": interrupted compute projection reason was not 'cancelled'.")
	_expect(int(result.get("compiled_shader_count", 0)) > 0, label + ": interrupt did not reach compiled compute resources.")
	_expect(bool(result.get("projection_sampler_reads", false)), label + ": interrupt did not reach projection sampler resource setup.")
	_expect(not bool(result.get("production_output_replaced", true)), label + ": interrupted compute projection must not replace production output.")
	_expect(_output_texture_key_count(result) == 0, label + ": interrupted compute projection returned output texture keys.")
	_expect(bool(result.get("cleanup_completed", false)), label + ": interrupted compute projection did not report cleanup completion.")
	_expect(int(result.get("cleanup_owned_rid_count_after_cleanup", -1)) == 0, label + ": interrupted compute projection leaked owned RIDs.")
	_expect(bool(result.get("cleanup_rendering_device_released", false)), label + ": interrupted compute projection did not release the local RenderingDevice.")
	_expect(not bool(result.get("cleanup_submitted_without_sync_after_cleanup", true)), label + ": interrupted compute projection left submitted work unsynced after cleanup.")


func _record_compute_progress(progress: float, message: String) -> void:
	_active_compute_progress_events.append({
		"progress": progress,
		"label": message,
	})


func _record_warning(message: String) -> void:
	_warnings.append(message)


func _sanitize_compute_result(result: Dictionary) -> Dictionary:
	var sanitized := {}
	for key in result.keys():
		var key_string := String(key)
		if key_string.begins_with("_debug_"):
			continue
		sanitized[key] = result[key]
	return sanitized


func _output_texture_key_count(result: Dictionary) -> int:
	var output_keys = result.get("output_texture_keys", [])
	if typeof(output_keys) == TYPE_ARRAY or typeof(output_keys) == TYPE_PACKED_STRING_ARRAY:
		return output_keys.size()
	return 0


func _selection_has_blocker(selection: Dictionary, blocker: String) -> bool:
	var blockers = selection.get("canonical_compute_replacement_gate_blockers", [])
	if typeof(blockers) != TYPE_ARRAY and typeof(blockers) != TYPE_PACKED_STRING_ARRAY:
		return false
	for value in blockers:
		if String(value) == blocker:
			return true
	return false


func _append_selection_lines(prefix: String, selection: Dictionary) -> void:
	var keys := selection.keys()
	keys.sort()
	for key in keys:
		_report_lines.append(prefix + "." + String(key) + "=" + str(selection[key]))


func _append_compute_lines(prefix: String, run: Dictionary) -> void:
	_report_lines.append(prefix + ".completed=" + str(bool(run.get("completed", false))))
	_report_lines.append(prefix + ".interrupt_kind=" + String(run.get("interrupt_kind", "")))
	_report_lines.append(prefix + ".interrupt_applied=" + str(bool(run.get("interrupt_applied", false))))
	_report_lines.append(prefix + ".elapsed_ms=" + str(float(run.get("elapsed_ms", 0.0))))
	_report_lines.append(prefix + ".frame_count=" + str(int(run.get("frame_count", 0))))
	_report_lines.append(prefix + ".max_frame_gap_ms=" + str(float(run.get("max_frame_gap_ms", 0.0))))
	_report_lines.append(prefix + ".p95_frame_gap_ms=" + str(float(run.get("p95_frame_gap_ms", 0.0))))
	_report_lines.append(prefix + ".baker_running_after_result=" + str(bool(run.get("baker_running_after_result", true))))
	_report_lines.append(prefix + ".baker_running_after_cleanup=" + str(bool(run.get("baker_running_after_cleanup", true))))
	var result: Dictionary = run.get("compute_result", {})
	var keys := result.keys()
	keys.sort()
	for key in keys:
		_report_lines.append(prefix + ".result." + String(key) + "=" + str(result[key]))


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


func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * ratio)) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


func _max_float(values: Array) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value))
	return result


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
