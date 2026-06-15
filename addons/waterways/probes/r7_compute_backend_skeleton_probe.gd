# River-refactor R7 non-replacing production compute backend skeleton probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_backend_skeleton_probe.gd -- out=res://.codex-research/r7-baselines/compute-skeleton
#
# Success marker: R7_COMPUTE_BACKEND_SKELETON_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")

const DEFAULT_SCENE := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-skeleton"
const REPORT_FILE_NAME := "r7_compute_backend_skeleton.txt"
const DEFAULT_ITERATIONS := 9
const DEFAULT_ELEMENT_COUNT := 257

var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _progress := PackedStringArray()
var _report_lines := PackedStringArray()
var _written_report := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var iterations := maxi(1, int(args.get("iterations", str(DEFAULT_ITERATIONS))))
	var element_count := maxi(1, int(args.get("element_count", str(DEFAULT_ELEMENT_COUNT))))

	_report_lines.append("R7_COMPUTE_BACKEND_SKELETON_DUMP v1")
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
	var before_state := _river_output_state(river)
	_report_lines.append("before_river_output_state=" + str(before_state))

	var baker := RiverFlowmapBaker.new()
	var compute_result: Dictionary = await baker.run_non_replacing_compute_backend_probe(
		{
			"frame_wait_source": self,
			"warning_callback": Callable(self, "_record_warning"),
			"iterations": iterations,
			"element_count": element_count,
			"sync_wait_frames": 3
		},
		Callable(self, "_record_progress")
	)
	baker.cleanup()
	baker.abort()
	baker.cleanup()

	var after_state := _river_output_state(river)
	_report_lines.append("after_river_output_state=" + str(after_state))
	_append_result("compute", compute_result)
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("progress=" + str(_progress))

	_expect(bool(compute_result.get("ok", false)), "Compute backend skeleton did not return ok=true: " + str(compute_result))
	_expect(not bool(compute_result.get("production_output_replaced", true)), "Compute skeleton must not replace production bake output.")
	_expect(_output_texture_key_count(compute_result) == 0, "Compute skeleton returned output texture keys before replacement is allowed.")
	_expect(not bool(compute_result.get("async_readback_selected", true)), "Compute skeleton selected async readback.")
	_expect(String(compute_result.get("selected_readback_path", "")).find("sync_buffer_get_data") >= 0, "Compute skeleton did not report the delayed sync/readback path.")
	_expect(int(compute_result.get("submit_count", 0)) == 1, "Compute skeleton should use one submit for this proof path.")
	_expect(int(compute_result.get("compute_lists_recorded", 0)) == iterations, "Compute list count did not match requested iterations.")
	_expect(not bool(compute_result.get("same_list_read_after_write_dependencies", true)), "Compute skeleton should avoid same-list read-after-write dependencies.")
	_expect(bool(compute_result.get("cleanup_completed", false)), "Compute skeleton did not report cleanup completion.")
	_expect(before_state == after_state, "RiverManager texture/bake output state changed during non-replacing compute proof.")

	if fixture != null:
		fixture.queue_free()
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_BACKEND_SKELETON_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


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


func _river_output_state(river: Node) -> Dictionary:
	if river == null:
		return {}
	var bake_data = river.get("bake_data")
	var bake_path := ""
	if bake_data != null and bake_data is Resource:
		bake_path = (bake_data as Resource).resource_path
	return {
		"valid_flowmap": bool(river.get("valid_flowmap")),
		"bake_data_path": bake_path,
		"flow_foam_noise_id": _object_id(river.get("flow_foam_noise")),
		"dist_pressure_id": _object_id(river.get("dist_pressure")),
		"obstacle_features_id": _object_id(river.get("obstacle_features")),
		"terrain_contact_features_id": _object_id(river.get("terrain_contact_features")),
		"bank_response_features_id": _object_id(river.get("bank_response_features")),
		"water_occupancy_id": _object_id(river.get("water_occupancy"))
	}


func _object_id(value: Variant) -> int:
	var object := value as Object
	return object.get_instance_id() if object != null else 0


func _output_texture_key_count(result: Dictionary) -> int:
	var output_keys = result.get("output_texture_keys", [])
	if typeof(output_keys) == TYPE_ARRAY or typeof(output_keys) == TYPE_PACKED_STRING_ARRAY:
		return output_keys.size()
	return 0


func _append_result(prefix: String, result: Dictionary) -> void:
	var keys := result.keys()
	keys.sort()
	for key in keys:
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
