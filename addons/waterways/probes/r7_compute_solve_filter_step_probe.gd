# River-refactor R7 isolated non-replacing solve/filter compute step probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_solve_filter_step_probe.gd -- out=res://.codex-research/r7-baselines/compute-solve-filter
#
# Success marker: R7_COMPUTE_SOLVE_FILTER_STEP_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverFlowmapComputeBackend = preload("res://addons/waterways/river_flowmap_compute_backend.gd")

const DEFAULT_SCENE := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-solve-filter"
const REPORT_FILE_NAME := "r7_compute_solve_filter_step.txt"
const FILTER_RENDERER_SCENE := "res://addons/waterways/filter_renderer.tscn"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 2400
const FLOW_SOLVE_PRESSURE_SCALE := 0.03125
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

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
	var texture_width := maxi(4, int(args.get("texture_width", "16")))
	var texture_height := maxi(4, int(args.get("texture_height", "16")))
	var stride := maxi(1, int(args.get("stride", "2")))
	var source_size := maxf(1.0, float(args.get("source_size", "13.0")))
	var atlas_columns := maxi(1, int(args.get("atlas_columns", "4")))
	var fixture_seed := int(args.get("fixture_seed", "37"))

	_report_lines.append("R7_COMPUTE_SOLVE_FILTER_STEP_DUMP v2")
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
		_expect(legacy_ok, "Legacy fixture bake did not complete before compute comparison.")
	var legacy_before_state := _river_output_state(river)
	var legacy_before_hashes := _river_texture_hashes(river)
	_report_lines.append("legacy_before_state=" + str(legacy_before_state))
	_report_lines.append("legacy_before_hashes=" + str(legacy_before_hashes))

	var baker := RiverFlowmapBaker.new()
	var compute_config := {
		"frame_wait_source": self,
		"warning_callback": Callable(self, "_record_warning"),
		"texture_width": texture_width,
		"texture_height": texture_height,
		"stride": stride,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"fixture_seed": fixture_seed,
		"sync_wait_frames": 3
	}
	var compute_result: Dictionary = await baker.run_non_replacing_compute_solve_filter_step_probe(
		compute_config,
		Callable(self, "_record_progress")
	)
	baker.cleanup()
	baker.abort()
	baker.cleanup()
	var legacy_parity := await _run_legacy_pressure_jacobi_parity(compute_config)

	var legacy_after_state := _river_output_state(river)
	var legacy_after_hashes := _river_texture_hashes(river)
	_report_lines.append("legacy_after_state=" + str(legacy_after_state))
	_report_lines.append("legacy_after_hashes=" + str(legacy_after_hashes))
	_append_result("compute", compute_result)
	_append_result("legacy_jacobi", legacy_parity)
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("progress=" + str(_progress))

	_expect(bool(compute_result.get("ok", false)), "Compute solve/filter step did not return ok=true: " + str(compute_result))
	_expect(String(compute_result.get("isolated_step", "")) == "flow_pressure_jacobi", "Compute step did not report flow_pressure_jacobi.")
	_expect(String(compute_result.get("reference", "")) == "cpu_legacy_uv_flow_pressure_jacobi_v2", "Compute step did not report the legacy-UV CPU reference.")
	_expect(not bool(compute_result.get("production_output_replaced", true)), "Compute solve/filter step must not replace production bake output.")
	_expect(_output_texture_key_count(compute_result) == 0, "Compute solve/filter step returned output texture keys before replacement is allowed.")
	_expect(not bool(compute_result.get("async_readback_selected", true)), "Compute solve/filter step selected async readback.")
	_expect(String(compute_result.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, "Compute solve/filter step did not report delayed texture readback.")
	_expect(int(compute_result.get("submit_count", 0)) == 1, "Compute solve/filter step should use one submit for this proof path.")
	_expect(int(compute_result.get("compute_lists_recorded", 0)) == 1, "Compute solve/filter step should record one compute list.")
	_expect(bool(compute_result.get("solve_rgba32f_supported", false)), "Compute solve/filter step did not confirm RGBA32F storage texture support.")
	_expect(int(compute_result.get("fixture_active_pixels", 0)) > 0, "Compute fixture did not exercise active fluid pixels.")
	_expect(int(compute_result.get("fixture_solid_pixels", 0)) > 0, "Compute fixture did not exercise solid occupancy pixels.")
	_expect(int(compute_result.get("fixture_wall_neighbor_cases", 0)) > 0, "Compute fixture did not exercise atlas wall neighbors.")
	_expect(int(compute_result.get("fixture_cross_column_wall_neighbor_cases", 0)) > 0, "Compute fixture did not exercise cross-column atlas wall neighbors.")
	_expect(int(compute_result.get("fixture_padding_wall_neighbor_cases", 0)) > 0, "Compute fixture did not exercise legacy atlas padding wall neighbors.")
	_expect(int(compute_result.get("fixture_solid_neighbor_cases", 0)) > 0, "Compute fixture did not exercise solid neighbors.")
	_expect(float(compute_result.get("metric_encoded_max_abs", 1.0)) <= 0.00001, "Encoded pressure max delta exceeded the CPU-reference gate.")
	_expect(float(compute_result.get("metric_pressure_max_abs", 1.0)) <= 0.001, "Decoded pressure max delta exceeded the CPU-reference gate.")
	_expect(bool(compute_result.get("cleanup_completed", false)), "Compute solve/filter step did not report cleanup completion.")
	_expect(bool(legacy_parity.get("ok", false)), "Legacy shader Jacobi parity failed: " + str(legacy_parity))
	_expect(float(legacy_parity.get("metric_encoded_max_abs", 1.0)) <= 0.001, "Legacy shader encoded pressure max delta exceeded the parity gate.")
	_expect(float(legacy_parity.get("metric_pressure_max_abs", 1.0)) <= 0.04, "Legacy shader decoded pressure max delta exceeded the parity gate.")
	_expect(bool(legacy_before_state.get("valid_flowmap", false)), "Legacy fixture bake did not leave RiverManager valid_flowmap=true before compute.")
	_expect(legacy_before_state == legacy_after_state, "RiverManager texture/bake output state changed during non-replacing solve/filter proof.")
	_expect(legacy_before_hashes == legacy_after_hashes, "RiverManager generated texture hashes changed during non-replacing solve/filter proof.")

	if fixture != null:
		fixture.queue_free()
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_SOLVE_FILTER_STEP_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_legacy_pressure_jacobi_parity(config: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "legacy_filter_renderer_pressure_jacobi_parity",
		"shader": "flow_pressure_jacobi_pass.gdshader",
		"reference": "cpu_legacy_uv_flow_pressure_jacobi_v2",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"tolerance_gate": "R7_LEGACY_JACOBI_INTERMEDIATE_V1",
	}
	var backend := RiverFlowmapComputeBackend.new()
	var fixture := backend.make_pressure_jacobi_validation_fixture(config)
	var pressure_image := fixture.get("pressure_image") as Image
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
	var output_texture: Texture2D = await renderer.apply_flow_pressure_jacobi(
		pressure_texture,
		divergence_texture,
		occupancy_texture,
		float(fixture.get("stride", 1)),
		float(fixture.get("source_size", 1.0)),
		float(fixture.get("atlas_columns", 1))
	)
	var readback_error := ""
	if "last_readback_error" in renderer:
		readback_error = String(renderer.last_readback_error)
	if renderer.get_parent() != null:
		renderer.get_parent().remove_child(renderer)
	renderer.queue_free()
	if output_texture == null:
		result.reason = "legacy_shader_output_missing"
		result.readback_error = readback_error
		return result
	var output_image := output_texture.get_image()
	if output_image == null or output_image.is_empty():
		result.reason = "legacy_shader_image_unreadable"
		result.readback_error = readback_error
		return result
	var actual_encoded := _read_red_channel(output_image)
	var expected_encoded: Array = fixture.get("expected_encoded_pressure", [])
	var metrics := _pressure_compare_metrics(expected_encoded, actual_encoded)
	for key in metrics:
		result["metric_" + String(key)] = metrics[key]
	result.texture_width = output_image.get_width()
	result.texture_height = output_image.get_height()
	result.texture_format = output_image.get_format()
	result.source_size = float(fixture.get("source_size", 1.0))
	result.stride = int(fixture.get("stride", 1))
	result.atlas_columns = int(fixture.get("atlas_columns", 1))
	result.fixture_active_pixels = int(fixture.get("active_pixels", 0))
	result.fixture_solid_pixels = int(fixture.get("solid_pixels", 0))
	result.fixture_wall_neighbor_cases = int(fixture.get("wall_neighbor_cases", 0))
	result.fixture_cross_column_wall_neighbor_cases = int(fixture.get("cross_column_wall_neighbor_cases", 0))
	result.fixture_padding_wall_neighbor_cases = int(fixture.get("padding_wall_neighbor_cases", 0))
	result.fixture_solid_neighbor_cases = int(fixture.get("solid_neighbor_cases", 0))
	result.reason = "ok"
	result.ok = (
		float(metrics.get("encoded_max_abs", 1.0)) <= 0.001
		and float(metrics.get("encoded_p99_abs", 1.0)) <= 0.001
		and float(metrics.get("pressure_max_abs", 1.0)) <= 0.04
		and float(metrics.get("pressure_p99_abs", 1.0)) <= 0.04
	)
	if not bool(result.ok):
		result.reason = "legacy_shader_cpu_reference_mismatch"
	return result


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
	river.call("bake_texture")
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		frame_count += 1
	return not bool(river.call("is_bake_in_progress")) and river.get("bake_data") != null


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


func _pressure_compare_metrics(expected_encoded: Array, actual_encoded: Array) -> Dictionary:
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
		if first_mismatch.is_empty() and (encoded_delta > 0.001 or pressure_delta > 0.04):
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
