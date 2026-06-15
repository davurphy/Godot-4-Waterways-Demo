# River-refactor R7 texture-format and explicit-legacy tolerance proof.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_texture_format_and_tolerance_probe.gd -- out=res://.codex-research/r7-baselines/format
#
# Success markers:
#   R7_TOLERANCE_SELF_COMPARE_OK
#   R7_TEXTURE_FORMAT_ROUNDTRIP_OK
extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")
const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

const DEFAULT_SCENE_PATH := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/format"
const DEFAULT_BASELINE_PATH := "res://.codex-research/r7-baselines/legacy/r7_legacy_baseline.txt"
const REPORT_FILE_NAME := "r7_texture_format_and_tolerance.txt"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 3000
const FORMAT_TEXTURE_SIZE := Vector2i(16, 16)
const FLOW_MAGNITUDE_MIN := 0.05
const PRESSURE_SCALE := 0.03125
const CHANNEL_NAMES := ["r", "g", "b", "a"]
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]
const FORMAT_CASES := [
	{
		"name": "rgba16f",
		"rd_format": RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
		"image_format": Image.FORMAT_RGBAH,
		"layout": "rgba16f",
		"channel_max_gate": 0.02,
		"channel_p99_gate": 0.006,
		"channel_mean_gate": 0.0015,
		"pressure_p95_gate": 0.03,
		"pressure_max_gate": 0.08,
	},
	{
		"name": "rgba32f",
		"rd_format": RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT,
		"image_format": Image.FORMAT_RGBAF,
		"layout": "rgba32f",
		"channel_max_gate": 0.00001,
		"channel_p99_gate": 0.00001,
		"channel_mean_gate": 0.000001,
		"pressure_p95_gate": 0.0005,
		"pressure_max_gate": 0.001,
	},
]

const FORMAT_WRITE_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout($LAYOUT, set = 0, binding = 0) uniform restrict image2D output_image;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;
const float PRESSURE_SCALE = 0.03125;

vec4 representative_value(ivec2 pos) {
	int idx = pos.y * WIDTH + pos.x;
	vec2 centered = vec2(float(pos.x) / float(WIDTH - 1), float(pos.y) / float(HEIGHT - 1)) * 2.0 - 1.0;
	vec2 direction = centered;
	if (length(direction) < 0.001) {
		direction = vec2(1.0, 0.0);
	}
	direction = normalize(direction);
	float magnitude = 0.05 + 0.85 * fract(float(idx) * 0.037 + 0.19);
	vec2 flow = direction * magnitude;
	float pressure = -3.75 + 7.5 * fract(float(idx) * 0.173 + 0.11);
	float class_mask = ((idx % 7) == 0) ? 1.0 : (((idx % 5) == 0) ? 0.5 : 0.0);
	return vec4(clamp(flow * 0.5 + 0.5, vec2(0.0), vec2(1.0)), clamp(pressure * PRESSURE_SCALE + 0.5, 0.0, 1.0), class_mask);
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	imageStore(output_image, pos, representative_value(pos));
}
"""

const FORMAT_READ_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout($LAYOUT, set = 0, binding = 0) uniform readonly restrict image2D input_image;
layout(set = 0, binding = 1, std430) restrict buffer Readback {
	vec4 values[];
}
readback;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	int idx = pos.y * WIDTH + pos.x;
	readback.values[idx] = imageLoad(input_image, pos);
}
"""

var _errors := PackedStringArray()
var _report_lines := PackedStringArray()
var _progress_finished_usec := 0
var _written_report := ""


class R7ExplicitLegacyBaker:
	extends RiverFlowmapBaker

	var last_filter_result := {}

	func run_filter_pass_sequence(config: Dictionary, progress: Callable = Callable(), cancellation: Callable = Callable()) -> Dictionary:
		var injected_config := config.duplicate(true)
		injected_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM
		var result: Dictionary = await super.run_filter_pass_sequence(injected_config, progress, cancellation)
		last_filter_result = result.duplicate(true)
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var scene_path := String(args.get("scene", DEFAULT_SCENE_PATH))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var baseline_path := String(args.get("baseline", DEFAULT_BASELINE_PATH))
	var baseline_abs := ProjectSettings.globalize_path(baseline_path)
	_report_lines.append("R7_TEXTURE_FORMAT_ROUNDTRIP_DUMP v1")
	_report_lines.append("baseline_path=" + baseline_path)
	_report_lines.append("baseline_exists=" + str(FileAccess.file_exists(baseline_abs)))
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())
	if not FileAccess.file_exists(baseline_abs):
		_errors.append("Recorded R7 legacy baseline is missing: " + baseline_path)

	var legacy_a := await _run_legacy_fixture_bake(scene_path, river_path, "legacy_a")
	var legacy_b := await _run_legacy_fixture_bake(scene_path, river_path, "legacy_b")
	if bool(legacy_a.get("ok", false)) and bool(legacy_b.get("ok", false)):
		_run_tolerance_evidence(legacy_a, legacy_b)
	else:
		_errors.append("Could not collect two legacy fixture bakes for tolerance evidence.")

	_run_format_roundtrip_evidence()
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)

	if _errors.is_empty():
		print("R7_TOLERANCE_SELF_COMPARE_OK textures=", TEXTURE_PROPERTIES.size(), " out=", out_dir)
		print("R7_TEXTURE_FORMAT_ROUNDTRIP_OK formats=", FORMAT_CASES.size(), " out=", out_dir)
		print("R7_TEXTURE_FORMAT_ROUNDTRIP_FILE ", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_legacy_fixture_bake(scene_path: String, river_path: String, label: String) -> Dictionary:
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
		await process_frame
		return {}
	_configure_fixture_river(river)

	var legacy_baker := R7ExplicitLegacyBaker.new()
	RiverManager._flowmap_bakers[river.get_instance_id()] = legacy_baker
	_progress_finished_usec = 0
	var started_usec := Time.get_ticks_usec()
	river.progress_notified.connect(Callable(self, "_on_progress_notified"))
	river.call("bake_texture")
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		frame_count += 1
	if river.progress_notified.is_connected(Callable(self, "_on_progress_notified")):
		river.progress_notified.disconnect(Callable(self, "_on_progress_notified"))
	if bool(river.call("is_bake_in_progress")):
		_errors.append(label + ": Bake did not finish within " + str(MAX_BAKE_FRAMES) + " frames.")
	if _progress_finished_usec <= 0:
		_progress_finished_usec = Time.get_ticks_usec()

	var bake_data := river.get("bake_data") as Resource
	var filter_result := legacy_baker.last_filter_result.duplicate(true)
	var backend_selection := (filter_result.get("flowmap_backend_selection", {}) as Dictionary).duplicate(true)
	var result := {
		"ok": bake_data != null and not bool(river.call("is_bake_in_progress")),
		"label": label,
		"elapsed_ms": float(_progress_finished_usec - started_usec) / 1000.0,
		"bake_data": bake_data,
		"images": _extract_images(bake_data),
		"metadata": _resource_dictionary(bake_data, "source_metadata"),
		"signature": _resource_dictionary(bake_data, "source_signature"),
		"settings": _resource_dictionary(bake_data, "bake_settings"),
		"source_signature_version": int(bake_data.get("source_signature_version")) if bake_data != null else -1,
		"flowmap_backend_mode": String(filter_result.get("flowmap_backend_mode", "")),
		"flowmap_backend_selection": backend_selection,
		"production_output_replaced": bool(filter_result.get("production_output_replaced", false)),
		"resource_path": bake_data.resource_path if bake_data != null else "",
		"content_rect": bake_data.get("content_rect") if bake_data != null else Rect2i(),
		"uv2_sides": int(bake_data.get("uv2_sides")) if bake_data != null else 1,
	}
	_report_lines.append(label + ".elapsed_ms=" + str(float(result.elapsed_ms)))
	_report_lines.append(label + ".source_signature_version=" + str(int(result.source_signature_version)))
	_report_lines.append(label + ".flowmap_backend_mode=" + String(result.flowmap_backend_mode))
	_report_lines.append(label + ".flowmap_backend_requested_mode=" + String(backend_selection.get("requested_mode", "")))
	_report_lines.append(label + ".flowmap_backend_selected_mode=" + String(backend_selection.get("selected_mode", "")))
	_report_lines.append(label + ".resource_path=" + String(result.resource_path))
	RiverManager._flowmap_bakers.erase(river.get_instance_id())
	scene.queue_free()
	current_scene = null
	await process_frame
	return result


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
	for _index in point_count:
		neutral_speeds.append(1.0)
	if not neutral_speeds.is_empty():
		river.call("set_flow_speeds", neutral_speeds)


func _on_progress_notified(_progress, message) -> void:
	if String(message) == "finished":
		_progress_finished_usec = Time.get_ticks_usec()


func _extract_images(bake_data: Resource) -> Dictionary:
	var images := {}
	if bake_data == null:
		return images
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var texture := bake_data.get(texture_name) as Texture2D
		if texture == null:
			images[texture_name] = null
			continue
		var image := texture.get_image()
		images[texture_name] = image.duplicate() if image != null else null
	return images


func _run_tolerance_evidence(run_a: Dictionary, run_b: Dictionary) -> void:
	_report_lines.append("tolerance_gate=R7_TOLERANCE_V1")
	_expect(int(run_a.get("source_signature_version", -1)) == 29, "legacy_a source signature version drifted from 29.")
	_expect(int(run_b.get("source_signature_version", -1)) == 29, "legacy_b source signature version drifted from 29.")
	_verify_explicit_legacy_backend(run_a, "legacy_a")
	_verify_explicit_legacy_backend(run_b, "legacy_b")
	_expect(String(run_a.get("resource_path", "")) == "", "legacy_a saved a bake resource unexpectedly.")
	_expect(String(run_b.get("resource_path", "")) == "", "legacy_b saved a bake resource unexpectedly.")
	_compare_texture_sets(run_a, run_a, "legacy_self")
	_compare_texture_sets(run_a, run_b, "legacy_rerun")


func _verify_explicit_legacy_backend(run: Dictionary, label: String) -> void:
	var backend_selection: Dictionary = run.get("flowmap_backend_selection", {})
	_expect(String(run.get("flowmap_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, label + ": flowmap backend should be explicit legacy_canvas_item.")
	_expect(bool(backend_selection.get("explicit_selection", false)), label + ": legacy backend selection should be explicit.")
	_expect(String(backend_selection.get("requested_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, label + ": requested backend should be legacy_canvas_item.")
	_expect(String(backend_selection.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, label + ": selected backend should be legacy_canvas_item.")
	_expect(not bool(run.get("production_output_replaced", true)), label + ": tolerance bake should not replace output with compute.")


func _compare_texture_sets(run_a: Dictionary, run_b: Dictionary, label: String) -> void:
	var images_a: Dictionary = run_a.get("images", {})
	var images_b: Dictionary = run_b.get("images", {})
	var occupied_rects := _occupied_atlas_rects(run_a)
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var image_a := images_a.get(texture_name, null) as Image
		var image_b := images_b.get(texture_name, null) as Image
		if image_a == null or image_b == null:
			_errors.append(label + ": Missing texture image for " + texture_name)
			continue
		var whole_metrics := _channel_delta_metrics(image_a, image_b, [Rect2i(Vector2i.ZERO, image_a.get_size())])
		var occupied_metrics := _channel_delta_metrics(image_a, image_b, occupied_rects)
		_append_channel_metric_lines(label + "." + texture_name + ".whole", whole_metrics)
		_append_channel_metric_lines(label + "." + texture_name + ".occupied_atlas", occupied_metrics)
		_verify_channel_metrics(label + "." + texture_name + ".whole", whole_metrics, label == "legacy_self")
		_verify_channel_metrics(label + "." + texture_name + ".occupied_atlas", occupied_metrics, label == "legacy_self")
		if texture_name == "flow_foam_noise":
			var flow_metrics := _flow_delta_metrics(image_a, image_b, occupied_rects)
			_append_dictionary_lines(label + "." + texture_name + ".decoded_flow.", flow_metrics)
			_expect(float(flow_metrics.get("p95_angle_deg", 0.0)) <= 2.0, label + ": decoded flow p95 angle exceeded R7_TOLERANCE_V1.")
			_expect(float(flow_metrics.get("max_angle_deg", 0.0)) <= 10.0, label + ": decoded flow max angle exceeded R7_TOLERANCE_V1.")
			_expect(float(flow_metrics.get("p95_magnitude_delta", 0.0)) <= 0.03, label + ": decoded flow p95 magnitude delta exceeded R7_TOLERANCE_V1.")
		if texture_name == "water_occupancy":
			var class_metrics := _water_occupancy_class_delta(image_a, image_b, occupied_rects)
			_append_dictionary_lines(label + "." + texture_name + ".class_delta.", class_metrics)
			_expect(int(class_metrics.get("solid_delta", 0)) == 0, label + ": water_occupancy solid class count drifted.")
			_expect(int(class_metrics.get("proximity_delta", 0)) == 0, label + ": water_occupancy proximity class count drifted.")
			_expect(int(class_metrics.get("ring_delta", 0)) == 0, label + ": water_occupancy proximity-ring class count drifted.")
		if texture_name == "obstacle_features":
			var obstacle_metrics := _obstacle_feature_class_delta(image_a, image_b, occupied_rects)
			_append_dictionary_lines(label + "." + texture_name + ".class_delta.", obstacle_metrics)
			_expect(int(obstacle_metrics.get("nonneutral_delta", 0)) == 0, label + ": obstacle feature non-neutral coverage drifted.")


func _verify_channel_metrics(label: String, metrics: Dictionary, exact: bool) -> void:
	for channel in CHANNEL_NAMES:
		var channel_metrics: Dictionary = metrics.get(channel, {})
		var max_abs := float(channel_metrics.get("max_abs", 0.0))
		var p99_abs := float(channel_metrics.get("p99_abs", 0.0))
		var mean_abs := float(channel_metrics.get("mean_abs", 0.0))
		if exact:
			_expect(max_abs == 0.0 and p99_abs == 0.0 and mean_abs == 0.0, label + ": self-compare was not exact for channel " + channel)
		else:
			_expect(max_abs <= 0.02, label + ": max_abs exceeded R7_TOLERANCE_V1 for channel " + channel)
			_expect(p99_abs <= 0.006, label + ": p99_abs exceeded R7_TOLERANCE_V1 for channel " + channel)
			_expect(mean_abs <= 0.0015, label + ": mean_abs exceeded R7_TOLERANCE_V1 for channel " + channel)


func _run_format_roundtrip_evidence() -> void:
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		_errors.append("R7 texture format round-trip requires local RenderingDevice; it is unavailable in this run.")
		return
	_report_lines.append("local_rd_device_name=" + rd.get_device_name())
	_report_lines.append("local_rd_device_vendor=" + rd.get_device_vendor_name())
	_report_lines.append("local_rd_device_total_memory=" + str(rd.get_device_total_memory()))
	_report_lines.append("limit_push_constant_size=" + str(rd.limit_get(RenderingDevice.LIMIT_MAX_PUSH_CONSTANT_SIZE)))
	_report_lines.append("limit_max_compute_workgroup_invocations=" + str(rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_INVOCATIONS)))
	var usage := (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	for format_case_variant in FORMAT_CASES:
		var format_case: Dictionary = format_case_variant
		var format_name := String(format_case.get("name", ""))
		var rd_format := int(format_case.get("rd_format", -1))
		var supported := rd.texture_is_format_supported_for_usage(rd_format, usage)
		_report_lines.append("format." + format_name + ".supported_storage_sampling_copy=" + str(supported))
		if not supported:
			_errors.append("RenderingDevice format not supported for production-style usage: " + format_name)
			continue
		_run_single_format_case(rd, format_case, usage)
	rd.free()


func _run_single_format_case(rd: RenderingDevice, format_case: Dictionary, usage: int) -> void:
	var format_name := String(format_case.get("name", ""))
	var owned_rids: Array[RID] = []
	var texture := _create_texture(rd, int(format_case.get("rd_format", -1)), usage)
	if not texture.is_valid():
		_errors.append("Could not create RD texture for " + format_name)
		return
	owned_rids.append(texture)

	var write_shader := _compile_compute_shader(rd, _format_shader(FORMAT_WRITE_SHADER_TEMPLATE, format_case), format_name + "_write")
	if not write_shader.is_valid():
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(write_shader)
	var write_pipeline := rd.compute_pipeline_create(write_shader)
	if not write_pipeline.is_valid():
		_errors.append("Could not create write pipeline for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(write_pipeline)
	var write_set := rd.uniform_set_create([_image_uniform(texture, 0)], write_shader, 0)
	if not write_set.is_valid():
		_errors.append("Could not create write uniform set for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(write_set)

	var read_shader := _compile_compute_shader(rd, _format_shader(FORMAT_READ_SHADER_TEMPLATE, format_case), format_name + "_read")
	if not read_shader.is_valid():
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(read_shader)
	var read_pipeline := rd.compute_pipeline_create(read_shader)
	if not read_pipeline.is_valid():
		_errors.append("Could not create read pipeline for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(read_pipeline)
	var readback_size := FORMAT_TEXTURE_SIZE.x * FORMAT_TEXTURE_SIZE.y * 4 * 4
	var zero_bytes := PackedByteArray()
	zero_bytes.resize(readback_size)
	var readback_buffer := rd.storage_buffer_create(readback_size, zero_bytes)
	if not readback_buffer.is_valid():
		_errors.append("Could not create readback storage buffer for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(readback_buffer)
	var read_set := rd.uniform_set_create([_image_uniform(texture, 0), _storage_buffer_uniform(readback_buffer, 1)], read_shader, 0)
	if not read_set.is_valid():
		_errors.append("Could not create read uniform set for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	owned_rids.append(read_set)

	_dispatch(rd, write_pipeline, write_set, _groups_2d(FORMAT_TEXTURE_SIZE, 8))
	rd.submit()
	rd.sync()
	_dispatch(rd, read_pipeline, read_set, _groups_2d(FORMAT_TEXTURE_SIZE, 8))
	rd.submit()
	rd.sync()

	var texture_bytes := rd.texture_get_data(texture, 0)
	if texture_bytes.is_empty():
		_errors.append("texture_get_data returned empty bytes for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	var image := Image.create_from_data(FORMAT_TEXTURE_SIZE.x, FORMAT_TEXTURE_SIZE.y, false, int(format_case.get("image_format", -1)), texture_bytes)
	if image == null or image.is_empty():
		_errors.append("Image.create_from_data failed for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	var image_texture := ImageTexture.create_from_image(image)
	if image_texture == null or image_texture.get_image() == null:
		_errors.append("ImageTexture.create_from_image failed for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	var shader_readback := rd.buffer_get_data(readback_buffer, 0, readback_size)
	if shader_readback.is_empty():
		_errors.append("buffer_get_data returned empty shader readback for " + format_name)
		_free_owned_rids(rd, owned_rids)
		return
	var metrics := _format_metrics(image, shader_readback)
	_append_dictionary_lines("format." + format_name + ".", metrics)
	_verify_format_metrics(format_case, metrics)
	_report_lines.append("format." + format_name + ".image_format=" + str(image.get_format()))
	_report_lines.append("format." + format_name + ".image_texture_format=" + str(image_texture.get_format()))
	_report_lines.append("format." + format_name + ".texture_byte_size=" + str(texture_bytes.size()))
	_report_lines.append("format." + format_name + ".shader_readback_byte_size=" + str(shader_readback.size()))
	_free_owned_rids(rd, owned_rids)
	_free_owned_rids(rd, owned_rids)


func _create_texture(rd: RenderingDevice, rd_format: int, usage: int) -> RID:
	var texture_format := RDTextureFormat.new()
	texture_format.format = rd_format
	texture_format.width = FORMAT_TEXTURE_SIZE.x
	texture_format.height = FORMAT_TEXTURE_SIZE.y
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	texture_format.usage_bits = usage
	return rd.texture_create(texture_format, RDTextureView.new(), [])


func _compile_compute_shader(rd: RenderingDevice, code: String, shader_name: String) -> RID:
	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = code
	var spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_source, false)
	var compile_error := spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not compile_error.is_empty():
		_errors.append("Compute shader compile failed for " + shader_name + ": " + compile_error)
		return RID()
	var shader := rd.shader_create_from_spirv(spirv, shader_name)
	if not shader.is_valid():
		_errors.append("shader_create_from_spirv returned invalid RID for " + shader_name)
	return shader


func _format_shader(template: String, format_case: Dictionary) -> String:
	return template.replace("$LAYOUT", String(format_case.get("layout", "rgba16f"))).replace("$WIDTH", str(FORMAT_TEXTURE_SIZE.x)).replace("$HEIGHT", str(FORMAT_TEXTURE_SIZE.y))


func _dispatch(rd: RenderingDevice, pipeline: RID, uniform_set: RID, groups: Vector3i) -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
	rd.compute_list_end()


func _groups_2d(size: Vector2i, local_size: int) -> Vector3i:
	return Vector3i(int(ceil(float(size.x) / float(local_size))), int(ceil(float(size.y) / float(local_size))), 1)


func _image_uniform(texture: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform


func _storage_buffer_uniform(buffer: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform


func _format_metrics(image: Image, shader_readback: PackedByteArray) -> Dictionary:
	var channel_deltas := [[], [], [], []]
	var shader_channel_deltas := [[], [], [], []]
	var flow_angles := []
	var flow_magnitude_deltas := []
	var pressure_deltas := []
	var class_count_expected := 0
	var class_count_image := 0
	var class_count_shader := 0
	for y in FORMAT_TEXTURE_SIZE.y:
		for x in FORMAT_TEXTURE_SIZE.x:
			var expected := _representative_value(Vector2i(x, y))
			var pixel := image.get_pixel(x, y)
			var idx := y * FORMAT_TEXTURE_SIZE.x + x
			var shader_pixel := _decode_vec4(shader_readback, idx * 16)
			var pixel_channels := [pixel.r, pixel.g, pixel.b, pixel.a]
			var expected_channels := [expected.r, expected.g, expected.b, expected.a]
			var shader_channels := [shader_pixel.r, shader_pixel.g, shader_pixel.b, shader_pixel.a]
			for channel_index in 4:
				channel_deltas[channel_index].append(absf(float(pixel_channels[channel_index]) - float(expected_channels[channel_index])))
				shader_channel_deltas[channel_index].append(absf(float(shader_channels[channel_index]) - float(expected_channels[channel_index])))
			var expected_flow := _decode_flow(expected)
			var pixel_flow := _decode_flow(pixel)
			if expected_flow.length() >= FLOW_MAGNITUDE_MIN and pixel_flow.length() > 0.00001:
				flow_angles.append(absf(rad_to_deg(expected_flow.angle_to(pixel_flow))))
				flow_magnitude_deltas.append(absf(expected_flow.length() - pixel_flow.length()))
			var expected_pressure := _decode_pressure(expected)
			var pixel_pressure := _decode_pressure(pixel)
			pressure_deltas.append(absf(expected_pressure - pixel_pressure))
			if expected.a > 0.25:
				class_count_expected += 1
			if pixel.a > 0.25:
				class_count_image += 1
			if shader_pixel.a > 0.25:
				class_count_shader += 1
	var metrics := {}
	for channel_index in 4:
		metrics["image_channel_" + CHANNEL_NAMES[channel_index] + "_max_abs"] = _max_float(channel_deltas[channel_index])
		metrics["image_channel_" + CHANNEL_NAMES[channel_index] + "_p99_abs"] = _percentile(channel_deltas[channel_index], 0.99)
		metrics["image_channel_" + CHANNEL_NAMES[channel_index] + "_mean_abs"] = _mean_float(channel_deltas[channel_index])
		metrics["shader_read_channel_" + CHANNEL_NAMES[channel_index] + "_max_abs"] = _max_float(shader_channel_deltas[channel_index])
	metrics["decoded_flow_p95_angle_deg"] = _percentile(flow_angles, 0.95)
	metrics["decoded_flow_max_angle_deg"] = _max_float(flow_angles)
	metrics["decoded_flow_p95_magnitude_delta"] = _percentile(flow_magnitude_deltas, 0.95)
	metrics["pressure_p95_delta"] = _percentile(pressure_deltas, 0.95)
	metrics["pressure_max_delta"] = _max_float(pressure_deltas)
	metrics["class_count_expected"] = class_count_expected
	metrics["class_count_image"] = class_count_image
	metrics["class_count_shader_read"] = class_count_shader
	return metrics


func _verify_format_metrics(format_case: Dictionary, metrics: Dictionary) -> void:
	var format_name := String(format_case.get("name", ""))
	for channel in CHANNEL_NAMES:
		_expect(float(metrics.get("image_channel_" + channel + "_max_abs", 0.0)) <= float(format_case.get("channel_max_gate", 0.02)), format_name + ": image channel " + channel + " max_abs exceeded gate.")
		_expect(float(metrics.get("image_channel_" + channel + "_p99_abs", 0.0)) <= float(format_case.get("channel_p99_gate", 0.006)), format_name + ": image channel " + channel + " p99_abs exceeded gate.")
		_expect(float(metrics.get("image_channel_" + channel + "_mean_abs", 0.0)) <= float(format_case.get("channel_mean_gate", 0.0015)), format_name + ": image channel " + channel + " mean_abs exceeded gate.")
		_expect(float(metrics.get("shader_read_channel_" + channel + "_max_abs", 0.0)) <= float(format_case.get("channel_max_gate", 0.02)), format_name + ": shader imageLoad channel " + channel + " max_abs exceeded gate.")
	_expect(float(metrics.get("decoded_flow_p95_angle_deg", 0.0)) <= 2.0, format_name + ": decoded flow p95 angle exceeded R7_TOLERANCE_V1.")
	_expect(float(metrics.get("decoded_flow_max_angle_deg", 0.0)) <= 10.0, format_name + ": decoded flow max angle exceeded R7_TOLERANCE_V1.")
	_expect(float(metrics.get("decoded_flow_p95_magnitude_delta", 0.0)) <= 0.03, format_name + ": decoded flow p95 magnitude delta exceeded R7_TOLERANCE_V1.")
	_expect(float(metrics.get("pressure_p95_delta", 0.0)) <= float(format_case.get("pressure_p95_gate", 0.03)), format_name + ": pressure p95 delta exceeded gate.")
	_expect(float(metrics.get("pressure_max_delta", 0.0)) <= float(format_case.get("pressure_max_gate", 0.08)), format_name + ": pressure max delta exceeded gate.")
	_expect(int(metrics.get("class_count_expected", -1)) == int(metrics.get("class_count_image", -2)), format_name + ": Image class-mask count drifted.")
	_expect(int(metrics.get("class_count_expected", -1)) == int(metrics.get("class_count_shader_read", -2)), format_name + ": shader imageLoad class-mask count drifted.")


func _representative_value(pos: Vector2i) -> Color:
	var idx := pos.y * FORMAT_TEXTURE_SIZE.x + pos.x
	var centered := Vector2(float(pos.x) / float(FORMAT_TEXTURE_SIZE.x - 1), float(pos.y) / float(FORMAT_TEXTURE_SIZE.y - 1)) * 2.0 - Vector2.ONE
	var direction := centered
	if direction.length() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var magnitude := 0.05 + 0.85 * fposmod(float(idx) * 0.037 + 0.19, 1.0)
	var flow := direction * magnitude
	var pressure := -3.75 + 7.5 * fposmod(float(idx) * 0.173 + 0.11, 1.0)
	var class_mask := 1.0 if idx % 7 == 0 else (0.5 if idx % 5 == 0 else 0.0)
	return Color(clampf(flow.x * 0.5 + 0.5, 0.0, 1.0), clampf(flow.y * 0.5 + 0.5, 0.0, 1.0), clampf(pressure * PRESSURE_SCALE + 0.5, 0.0, 1.0), class_mask)


func _decode_vec4(bytes: PackedByteArray, offset: int) -> Color:
	return Color(bytes.decode_float(offset), bytes.decode_float(offset + 4), bytes.decode_float(offset + 8), bytes.decode_float(offset + 12))


func _decode_flow(color: Color) -> Vector2:
	return Vector2(color.r * 2.0 - 1.0, color.g * 2.0 - 1.0)


func _decode_pressure(color: Color) -> float:
	return (color.b - 0.5) / PRESSURE_SCALE


func _channel_delta_metrics(image_a: Image, image_b: Image, rects: Array) -> Dictionary:
	var channel_deltas := [[], [], [], []]
	if image_a.get_size() != image_b.get_size():
		_errors.append("Cannot compare images with different sizes: " + str(image_a.get_size()) + " vs " + str(image_b.get_size()))
		return {}
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				var color_a := image_a.get_pixel(px, py)
				var color_b := image_b.get_pixel(px, py)
				channel_deltas[0].append(absf(color_a.r - color_b.r))
				channel_deltas[1].append(absf(color_a.g - color_b.g))
				channel_deltas[2].append(absf(color_a.b - color_b.b))
				channel_deltas[3].append(absf(color_a.a - color_b.a))
	var metrics := {}
	for channel_index in 4:
		metrics[CHANNEL_NAMES[channel_index]] = {
			"sample_count": channel_deltas[channel_index].size(),
			"max_abs": _max_float(channel_deltas[channel_index]),
			"p99_abs": _percentile(channel_deltas[channel_index], 0.99),
			"mean_abs": _mean_float(channel_deltas[channel_index]),
		}
	return metrics


func _flow_delta_metrics(image_a: Image, image_b: Image, rects: Array) -> Dictionary:
	var angle_deltas := []
	var magnitude_deltas := []
	var sample_count := 0
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var px := rect.position.x + x
				var py := rect.position.y + y
				var flow_a := WaterHelperMethods.decode_packed_flow_vector(image_a.get_pixel(px, py))
				var flow_b := WaterHelperMethods.decode_packed_flow_vector(image_b.get_pixel(px, py))
				if flow_a.length() < FLOW_MAGNITUDE_MIN:
					continue
				sample_count += 1
				if flow_b.length() > 0.00001:
					angle_deltas.append(absf(rad_to_deg(flow_a.angle_to(flow_b))))
				else:
					angle_deltas.append(180.0)
				magnitude_deltas.append(absf(flow_a.length() - flow_b.length()))
	return {
		"sample_count": sample_count,
		"p95_angle_deg": _percentile(angle_deltas, 0.95),
		"max_angle_deg": _max_float(angle_deltas),
		"p95_magnitude_delta": _percentile(magnitude_deltas, 0.95),
		"max_magnitude_delta": _max_float(magnitude_deltas),
	}


func _water_occupancy_class_delta(image_a: Image, image_b: Image, rects: Array) -> Dictionary:
	var counts_a := _water_occupancy_counts(image_a, rects)
	var counts_b := _water_occupancy_counts(image_b, rects)
	return {
		"solid_a": counts_a.solid,
		"solid_b": counts_b.solid,
		"solid_delta": int(counts_b.solid) - int(counts_a.solid),
		"proximity_a": counts_a.proximity,
		"proximity_b": counts_b.proximity,
		"proximity_delta": int(counts_b.proximity) - int(counts_a.proximity),
		"ring_a": counts_a.ring,
		"ring_b": counts_b.ring,
		"ring_delta": int(counts_b.ring) - int(counts_a.ring),
	}


func _water_occupancy_counts(image: Image, rects: Array) -> Dictionary:
	var counts := {
		"solid": 0,
		"proximity": 0,
		"ring": 0,
	}
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var color := image.get_pixel(rect.position.x + x, rect.position.y + y)
				var solid := color.r > 0.5
				var proximity := color.g > 0.05
				if solid:
					counts.solid += 1
				if proximity:
					counts.proximity += 1
				if proximity and not solid:
					counts.ring += 1
	return counts


func _obstacle_feature_class_delta(image_a: Image, image_b: Image, rects: Array) -> Dictionary:
	var count_a := _obstacle_nonneutral_count(image_a, rects)
	var count_b := _obstacle_nonneutral_count(image_b, rects)
	return {
		"nonneutral_a": count_a,
		"nonneutral_b": count_b,
		"nonneutral_delta": count_b - count_a,
	}


func _obstacle_nonneutral_count(image: Image, rects: Array) -> int:
	var count := 0
	for rect_variant in rects:
		var rect: Rect2i = rect_variant
		for y in rect.size.y:
			for x in rect.size.x:
				var color := image.get_pixel(rect.position.x + x, rect.position.y + y)
				if color.r > 0.05 or color.g > 0.05 or color.b > 0.05 or color.a > 0.05:
					count += 1
	return count


func _occupied_atlas_rects(run: Dictionary) -> Array:
	var bake_data := run.get("bake_data", null) as Resource
	if bake_data == null:
		return []
	var signature: Dictionary = run.get("signature", {})
	var steps := clampi(int(signature.get("step_count", 0)), 0, int(bake_data.get("uv2_sides")) * int(bake_data.get("uv2_sides")))
	var uv2_sides := maxi(1, int(run.get("uv2_sides", 1)))
	var content_rect: Rect2i = run.get("content_rect", Rect2i())
	var rects := []
	for step_index in steps:
		rects.append(WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, uv2_sides, content_rect))
	return rects


func _append_channel_metric_lines(prefix: String, metrics: Dictionary) -> void:
	for channel in CHANNEL_NAMES:
		var channel_metrics: Dictionary = metrics.get(channel, {})
		_report_lines.append(prefix + "." + channel + ".sample_count=" + str(int(channel_metrics.get("sample_count", 0))))
		_report_lines.append(prefix + "." + channel + ".max_abs=" + str(float(channel_metrics.get("max_abs", 0.0))))
		_report_lines.append(prefix + "." + channel + ".p99_abs=" + str(float(channel_metrics.get("p99_abs", 0.0))))
		_report_lines.append(prefix + "." + channel + ".mean_abs=" + str(float(channel_metrics.get("mean_abs", 0.0))))


func _append_dictionary_lines(prefix: String, values: Dictionary) -> void:
	var keys := values.keys()
	keys.sort()
	for key in keys:
		_report_lines.append(prefix + String(key) + "=" + str(values[key]))


func _resource_dictionary(resource: Resource, property_name: String) -> Dictionary:
	if resource == null:
		return {}
	var value = resource.get(property_name)
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _free_owned_rids(rd: RenderingDevice, rids: Array[RID]) -> void:
	for reverse_index in rids.size():
		var rid := rids[rids.size() - 1 - reverse_index]
		if rid.is_valid():
			rd.free_rid(rid)
	rids.clear()


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


func _mean_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args
