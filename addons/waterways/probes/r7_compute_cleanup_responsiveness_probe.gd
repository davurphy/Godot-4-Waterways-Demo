# River-refactor R7 compute cleanup, responsiveness, and non-neutral flow-speed probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_cleanup_responsiveness_probe.gd -- out=res://.codex-research/r7-baselines/compute-cleanup-responsiveness
#
# Success marker: R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK
extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")
const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")

const DEFAULT_SCENE_PATH := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-cleanup-responsiveness"
const REPORT_FILE_NAME := "r7_compute_cleanup_responsiveness.txt"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 3000
const MAX_COMPUTE_FRAMES := 900
const MAX_ALLOWED_FRAME_GAP_MS := 1000.0
const SYNTHETIC_TEXTURE_SIZE := Vector2i(106, 106)
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]
const EXPECTED_NEUTRAL_FLOW_SPEED_PASS_COUNT := 0
const EXPECTED_NON_NEUTRAL_FLOW_SPEED_PASS_COUNT := 1

var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _report_lines := PackedStringArray()
var _written_report := ""
var _active_pass_trace: Array = []
var _active_run_start_usec := 0
var _active_progress_events: Array = []
var _active_finished_usec := 0
var _active_compute_progress_events: Array = []
var _compute_async_done := false
var _compute_async_result := {}
var _cancel_call_count := 0
var _cancel_after_call_count := 3


class R7TraceBaker:
	extends RiverFlowmapBaker

	var trace_owner: Object = null

	func _run_pass(label: String, pass_callable: Callable) -> Dictionary:
		var start_usec := Time.get_ticks_usec()
		var result: Dictionary = await super._run_pass(label, pass_callable)
		if trace_owner != null and trace_owner.has_method("_record_pass_trace"):
			trace_owner.call("_record_pass_trace", label, start_usec, Time.get_ticks_usec(), bool(result.get("ok", false)), String(result.get("reason", "")))
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var scene_path := String(args.get("scene", DEFAULT_SCENE_PATH))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))

	_report_lines.append("R7_COMPUTE_CLEANUP_RESPONSIVENESS_DUMP v1")
	_report_lines.append("scene=" + scene_path)
	_report_lines.append("river=" + river_path)
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())

	var neutral_run := await _run_single_legacy_bake(scene_path, river_path, "legacy_neutral", false)
	var non_neutral_run := await _run_single_legacy_bake(scene_path, river_path, "legacy_non_neutral", true)
	_verify_legacy_pair(neutral_run, non_neutral_run)

	var synthetic_images := _make_synthetic_projection_images(SYNTHETIC_TEXTURE_SIZE)
	var compute_config := _make_compute_projection_config(synthetic_images)
	var compute_run := await _measure_compute_projection("compute_full_projection", compute_config, Callable())
	_verify_compute_run(compute_run, "compute_full_projection")

	_cancel_call_count = 0
	var cancel_run := await _measure_compute_projection("compute_cancel_after_resources", compute_config, Callable(self, "_cancel_after_threshold"))
	_verify_cancel_run(cancel_run, "compute_cancel_after_resources")

	_append_run_lines("legacy_neutral", neutral_run)
	_append_run_lines("legacy_non_neutral", non_neutral_run)
	_append_compute_lines("compute_full_projection", compute_run)
	_append_compute_lines("compute_cancel_after_resources", cancel_run)
	_report_lines.append("warnings=" + str(_warnings))

	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_CLEANUP_RESPONSIVENESS_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_single_legacy_bake(scene_path: String, river_path: String, label: String, non_neutral_flow: bool) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append(label + ": Could not load scene " + scene_path)
		return {}
	var scene := packed.instantiate()
	if scene == null:
		_errors.append(label + ": Could not instantiate scene " + scene_path)
		return {}
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		_errors.append(label + ": Could not find river " + river_path)
		scene.queue_free()
		current_scene = null
		await process_frame
		return {}
	_configure_fixture_river(river, non_neutral_flow)

	var trace_baker := R7TraceBaker.new()
	trace_baker.trace_owner = self
	RiverManager._flowmap_bakers[river.get_instance_id()] = trace_baker
	_active_pass_trace = []
	_active_progress_events = []
	_active_finished_usec = 0
	_active_run_start_usec = Time.get_ticks_usec()
	river.progress_notified.connect(Callable(self, "_on_progress_notified"))
	river.call("bake_texture")

	var frame_gaps: Array = []
	var previous_frame_usec := _active_run_start_usec
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_gaps.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
		frame_count += 1
	if bool(river.call("is_bake_in_progress")):
		_errors.append(label + ": Bake did not finish within " + str(MAX_BAKE_FRAMES) + " frames.")
	if _active_finished_usec <= 0:
		_active_finished_usec = Time.get_ticks_usec()

	if river.progress_notified.is_connected(Callable(self, "_on_progress_notified")):
		river.progress_notified.disconnect(Callable(self, "_on_progress_notified"))

	var bake_data := river.get("bake_data") as Resource
	var result := {
		"ok": bake_data != null and not bool(river.call("is_bake_in_progress")),
		"label": label,
		"non_neutral_flow": non_neutral_flow,
		"elapsed_ms": float(_active_finished_usec - _active_run_start_usec) / 1000.0,
		"frame_gaps_ms": frame_gaps.duplicate(),
		"frame_count": frame_count,
		"max_frame_gap_ms": _max_float(frame_gaps),
		"p95_frame_gap_ms": _percentile(frame_gaps, 0.95),
		"progress_events": _active_progress_events.duplicate(true),
		"pass_trace": _active_pass_trace.duplicate(true),
		"pass_counts": _count_passes(_active_pass_trace),
		"metadata": _resource_dictionary(bake_data, "source_metadata"),
		"signature": _resource_dictionary(bake_data, "source_signature"),
		"settings": _resource_dictionary(bake_data, "bake_settings"),
		"source_signature_version": int(bake_data.get("source_signature_version")) if bake_data != null else -1,
		"texture_hashes": _hash_bake_textures(bake_data),
		"result_handoff": _result_handoff_state(river, bake_data),
		"resource_path": bake_data.resource_path if bake_data != null else "",
	}
	RiverManager._flowmap_bakers.erase(river.get_instance_id())
	scene.queue_free()
	current_scene = null
	await process_frame
	return result


func _configure_fixture_river(river: Node, non_neutral_flow: bool) -> void:
	river.set("baking_resolution", 0)
	river.set("baking_raycast_layers", 1)
	river.set("shape_step_length_divs", 1)
	river.set("shape_step_width_divs", 1)
	river.set("bake_generation_behavior", TARGET_GENERATION_BEHAVIOR)
	var curve = river.get("curve")
	var point_count := 0
	if curve != null and curve.has_method("get_point_count"):
		point_count = int(curve.call("get_point_count"))
	var speeds := []
	var non_neutral_values := [0.65, 1.35, 0.85, 1.75]
	for point_index in point_count:
		if non_neutral_flow:
			speeds.append(non_neutral_values[point_index % non_neutral_values.size()])
		else:
			speeds.append(1.0)
	if not speeds.is_empty():
		river.call("set_flow_speeds", speeds)


func _verify_legacy_pair(neutral_run: Dictionary, non_neutral_run: Dictionary) -> void:
	_expect(bool(neutral_run.get("ok", false)), "Neutral legacy bake failed.")
	_expect(bool(non_neutral_run.get("ok", false)), "Non-neutral legacy bake failed.")
	if not bool(neutral_run.get("ok", false)) or not bool(non_neutral_run.get("ok", false)):
		return

	var neutral_metadata: Dictionary = neutral_run.get("metadata", {})
	var non_neutral_metadata: Dictionary = non_neutral_run.get("metadata", {})
	var neutral_counts: Dictionary = neutral_run.get("pass_counts", {})
	var non_neutral_counts: Dictionary = non_neutral_run.get("pass_counts", {})
	_expect(int(neutral_run.get("source_signature_version", -1)) == 29, "Neutral run source_signature_version should be 29.")
	_expect(int(non_neutral_run.get("source_signature_version", -1)) == 29, "Non-neutral run source_signature_version should be 29.")
	_expect(String(neutral_run.get("resource_path", "")) == "", "Neutral run bake_data.resource_path should remain empty.")
	_expect(String(non_neutral_run.get("resource_path", "")) == "", "Non-neutral run bake_data.resource_path should remain empty.")
	_expect(not bool(neutral_metadata.get("flow_speed_scaled", true)), "Neutral fixture should not run flow-speed scaling.")
	_expect(bool(non_neutral_metadata.get("flow_speed_scaled", false)), "Non-neutral fixture should run flow-speed scaling.")
	_expect(int(neutral_counts.get("flow speed scale map", 0)) == EXPECTED_NEUTRAL_FLOW_SPEED_PASS_COUNT, "Neutral flow-speed pass count changed.")
	_expect(int(non_neutral_counts.get("flow speed scale map", 0)) == EXPECTED_NON_NEUTRAL_FLOW_SPEED_PASS_COUNT, "Non-neutral flow-speed pass count should be 1.")
	_expect(float(neutral_run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, "Neutral legacy max frame gap exceeded " + str(MAX_ALLOWED_FRAME_GAP_MS) + " ms.")
	_expect(float(non_neutral_run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, "Non-neutral legacy max frame gap exceeded " + str(MAX_ALLOWED_FRAME_GAP_MS) + " ms.")

	var neutral_hashes: Dictionary = neutral_run.get("texture_hashes", {})
	var non_neutral_hashes: Dictionary = non_neutral_run.get("texture_hashes", {})
	var neutral_flow: Dictionary = neutral_hashes.get("flow_foam_noise", {})
	var non_neutral_flow: Dictionary = non_neutral_hashes.get("flow_foam_noise", {})
	_expect(bool(neutral_flow.get("present", false)), "Neutral flow_foam_noise texture missing.")
	_expect(bool(non_neutral_flow.get("present", false)), "Non-neutral flow_foam_noise texture missing.")
	_expect(String(neutral_flow.get("md5", "")) != String(non_neutral_flow.get("md5", "")), "Non-neutral flow-speed run did not change flow_foam_noise hash.")

	var neutral_handoff: Dictionary = neutral_run.get("result_handoff", {})
	var non_neutral_handoff: Dictionary = non_neutral_run.get("result_handoff", {})
	_expect(bool(neutral_handoff.get("river_textures_match_bake", false)), "Neutral RiverManager texture fields do not match bake_data.")
	_expect(bool(non_neutral_handoff.get("river_textures_match_bake", false)), "Non-neutral RiverManager texture fields do not match bake_data.")


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


func _make_compute_projection_config(images: Dictionary) -> Dictionary:
	return {
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
		"sync_wait_frames": 3,
	}


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
	baker.cleanup()
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
	}


func _start_compute_projection(baker: RiverFlowmapBaker, config: Dictionary, cancellation: Callable) -> void:
	_compute_async_result = await baker.run_non_replacing_compute_solve_filter_projection_probe(
		config,
		Callable(self, "_record_compute_progress"),
		cancellation
	)
	_compute_async_done = true


func _verify_compute_run(run: Dictionary, label: String) -> void:
	_expect(bool(run.get("completed", false)), label + ": async wrapper did not complete.")
	_expect(float(run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, label + ": max frame gap exceeded " + str(MAX_ALLOWED_FRAME_GAP_MS) + " ms.")
	var result: Dictionary = run.get("compute_result", {})
	_expect(bool(result.get("ok", false)), label + ": compute projection did not return ok=true: " + str(result))
	_expect(not bool(result.get("production_output_replaced", true)), label + ": compute projection must not replace production output.")
	_expect(_output_texture_key_count(result) == 0, label + ": compute projection returned output texture keys before replacement is allowed.")
	_expect(not bool(result.get("async_readback_selected", true)), label + ": compute projection selected async readback.")
	_expect(String(result.get("selected_readback_path", "")).find("delayed_single_submit_wait_") >= 0, label + ": compute projection did not use the delayed sync/readback path.")
	_expect(int(result.get("submit_count", 0)) == 1, label + ": compute projection should submit once.")
	_expect(int(result.get("compute_lists_recorded", 0)) == 1, label + ": compute projection should record one compute list.")
	_expect(bool(result.get("same_list_read_after_write_dependencies", false)), label + ": projection should report same-list dependencies.")
	_expect(bool(result.get("intra_list_barriers_required", false)), label + ": projection should require intra-list barriers.")
	_expect(int(result.get("compute_barrier_count", 0)) == maxi(0, int(result.get("dispatch_count", 0)) - 1), label + ": barrier count did not match dispatch count.")
	_expect(bool(result.get("cleanup_completed", false)), label + ": compute projection did not report cleanup completion.")
	_expect(int(result.get("cleanup_owned_rid_count_after_cleanup", -1)) == 0, label + ": compute projection leaked owned RIDs.")
	_expect(bool(result.get("cleanup_rendering_device_released", false)), label + ": compute projection did not release the local RenderingDevice.")
	_expect(not bool(result.get("cleanup_submitted_without_sync_after_cleanup", true)), label + ": compute projection left submitted work unsynced after cleanup.")
	_expect(bool(result.get("pressure_feedback_rgba32f", false)), label + ": compute projection did not use RGBA32F pressure feedback.")
	_expect(bool(result.get("canonical_integer_texel_addressing", false)), label + ": compute projection did not report canonical integer texel-space addressing.")


func _verify_cancel_run(run: Dictionary, label: String) -> void:
	_expect(bool(run.get("completed", false)), label + ": async wrapper did not complete.")
	_expect(float(run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, label + ": max frame gap exceeded " + str(MAX_ALLOWED_FRAME_GAP_MS) + " ms.")
	var result: Dictionary = run.get("compute_result", {})
	_expect(not bool(result.get("ok", true)), label + ": cancelled compute projection should not return ok=true.")
	_expect(String(result.get("reason", "")) == "cancelled", label + ": cancelled compute projection reason was not 'cancelled'.")
	_expect(_cancel_call_count >= _cancel_after_call_count, label + ": cancellation callback was not exercised enough times.")
	_expect(int(result.get("compiled_shader_count", 0)) > 0, label + ": cancellation did not reach compiled compute resources.")
	_expect(bool(result.get("projection_sampler_reads", false)), label + ": cancellation did not reach projection sampler resource setup.")
	_expect(not bool(result.get("production_output_replaced", true)), label + ": cancelled compute projection must not replace production output.")
	_expect(_output_texture_key_count(result) == 0, label + ": cancelled compute projection returned output texture keys.")
	_expect(bool(result.get("cleanup_completed", false)), label + ": cancelled compute projection did not report cleanup completion.")
	_expect(int(result.get("cleanup_owned_rid_count_after_cleanup", -1)) == 0, label + ": cancelled compute projection leaked owned RIDs.")
	_expect(bool(result.get("cleanup_rendering_device_released", false)), label + ": cancelled compute projection did not release the local RenderingDevice.")
	_expect(not bool(result.get("cleanup_submitted_without_sync_after_cleanup", true)), label + ": cancelled compute projection left submitted work unsynced after cleanup.")


func _cancel_after_threshold() -> bool:
	_cancel_call_count += 1
	return _cancel_call_count >= _cancel_after_call_count


func _on_progress_notified(progress, message) -> void:
	var now_usec := Time.get_ticks_usec()
	var label := String(message)
	_active_progress_events.append({
		"elapsed_ms": float(now_usec - _active_run_start_usec) / 1000.0,
		"progress": float(progress),
		"label": label,
	})
	if label == "finished":
		_active_finished_usec = now_usec


func _record_compute_progress(progress: float, message: String) -> void:
	_active_compute_progress_events.append({
		"elapsed_ms": 0.0,
		"progress": progress,
		"label": message,
	})


func _record_pass_trace(label: String, start_usec: int, end_usec: int, ok: bool, reason: String) -> void:
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


func _count_passes(pass_trace: Array) -> Dictionary:
	var counts := {}
	for event in pass_trace:
		var entry: Dictionary = event
		var label := String(entry.get("label", ""))
		counts[label] = int(counts.get(label, 0)) + 1
	if not counts.has("flow speed scale map"):
		counts["flow speed scale map"] = 0
	return counts


func _resource_dictionary(resource: Resource, property_name: String) -> Dictionary:
	if resource == null:
		return {}
	var value = resource.get(property_name)
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _hash_bake_textures(bake_data: Resource) -> Dictionary:
	var hashes := {}
	if bake_data == null:
		return hashes
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		hashes[property_name] = _hash_texture(bake_data.get(property_name) as Texture2D)
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


func _result_handoff_state(river: Node, bake_data: Resource) -> Dictionary:
	var state := {
		"valid_flowmap": false,
		"river_textures_match_bake": false,
		"material_bindings_match": false,
	}
	if river == null or bake_data == null:
		return state
	state.valid_flowmap = bool(river.get("valid_flowmap"))
	var river_matches := true
	var material_matches := true
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var bake_texture := bake_data.get(texture_name)
		if river.get(texture_name) != bake_texture:
			river_matches = false
		var shader_param := _shader_param_name(texture_name)
		if not shader_param.is_empty() and river.call("get_shader_param", shader_param) != bake_texture:
			material_matches = false
	state.river_textures_match_bake = river_matches
	state.material_bindings_match = material_matches
	return state


func _shader_param_name(texture_name: String) -> String:
	match texture_name:
		"flow_foam_noise":
			return "i_flowmap"
		"dist_pressure":
			return "i_distmap"
		"obstacle_features":
			return "i_obstacle_features"
		"terrain_contact_features":
			return "i_terrain_contact_features"
		"bank_response_features":
			return "i_bank_response_features"
		"water_occupancy":
			return "i_water_occupancy"
	return ""


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


func _append_run_lines(prefix: String, run: Dictionary) -> void:
	_report_lines.append(prefix + ".ok=" + str(bool(run.get("ok", false))))
	_report_lines.append(prefix + ".elapsed_ms=" + str(float(run.get("elapsed_ms", 0.0))))
	_report_lines.append(prefix + ".frame_count=" + str(int(run.get("frame_count", 0))))
	_report_lines.append(prefix + ".max_frame_gap_ms=" + str(float(run.get("max_frame_gap_ms", 0.0))))
	_report_lines.append(prefix + ".p95_frame_gap_ms=" + str(float(run.get("p95_frame_gap_ms", 0.0))))
	_report_lines.append(prefix + ".resource_path=" + String(run.get("resource_path", "")))
	_report_lines.append(prefix + ".source_signature_version=" + str(int(run.get("source_signature_version", -1))))
	var metadata: Dictionary = run.get("metadata", {})
	_report_lines.append(prefix + ".metadata.flow_speed_scaled=" + str(metadata.get("flow_speed_scaled", null)))
	_report_lines.append(prefix + ".metadata.generation_behavior=" + str(metadata.get("generation_behavior", null)))
	var pass_counts: Dictionary = run.get("pass_counts", {})
	_report_lines.append(prefix + ".pass_count.flow speed scale map=" + str(int(pass_counts.get("flow speed scale map", 0))))
	var texture_hashes: Dictionary = run.get("texture_hashes", {})
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var entry: Dictionary = texture_hashes.get(texture_name, {})
		_report_lines.append(prefix + ".texture." + texture_name + ".present=" + str(bool(entry.get("present", false))) + " size=" + str(entry.get("size", Vector2i.ZERO)) + " format=" + str(entry.get("format", -1)) + " md5=" + String(entry.get("md5", "")))
	var handoff: Dictionary = run.get("result_handoff", {})
	for key in handoff.keys():
		_report_lines.append(prefix + ".handoff." + String(key) + "=" + str(handoff[key]))


func _append_compute_lines(prefix: String, run: Dictionary) -> void:
	_report_lines.append(prefix + ".completed=" + str(bool(run.get("completed", false))))
	_report_lines.append(prefix + ".elapsed_ms=" + str(float(run.get("elapsed_ms", 0.0))))
	_report_lines.append(prefix + ".frame_count=" + str(int(run.get("frame_count", 0))))
	_report_lines.append(prefix + ".max_frame_gap_ms=" + str(float(run.get("max_frame_gap_ms", 0.0))))
	_report_lines.append(prefix + ".p95_frame_gap_ms=" + str(float(run.get("p95_frame_gap_ms", 0.0))))
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
