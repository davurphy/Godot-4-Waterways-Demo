# River-refactor R7 explicit legacy_canvas_item bake trace probe (window required).
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_legacy_canvas_item_bake_trace_probe.gd -- scene=res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn river="Water River" out=res://.codex-research/r7-baselines/legacy warmup=1 runs=5 save=false
#
# Success marker: R7_LEGACY_BASELINE_OK
extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")
const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")

const DEFAULT_SCENE_PATH := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/legacy"
const BASELINE_FILE_NAME := "r7_legacy_baseline.txt"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 3000
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]
const EXPECTED_PASS_COUNTS := {
	"bank response feature mask": 1,
	"flow pressure": 1,
	"blurred flow pressure": 1,
	"dilated collision map": 1,
	"normal map": 1,
	"occupancy proximity field": 1,
	"water occupancy mask": 1,
	"obstacle feature mask": 1,
	"flow divergence map": 1,
	"flow pressure jacobi pass": 40,
	"projected flow map": 1,
	"boundary tangency flow map": 2,
	"foam map": 1,
	"blurred foam map": 1,
	"combined flow/foam/noise map": 1,
	"combined distance/pressure map": 1,
	"flow speed scale map": 0,
}
const REQUIRED_PROJECTION_LABELS := [
	"Projecting flow 0/40",
	"Projecting flow 5/40",
	"Projecting flow 10/40",
	"Projecting flow 15/40",
	"Projecting flow 20/40",
	"Projecting flow 25/40",
	"Projecting flow 30/40",
	"Projecting flow 35/40",
]

var _errors := PackedStringArray()
var _written_files := PackedStringArray()
var _active_pass_trace: Array = []
var _active_run_start_usec := 0
var _active_progress_events: Array = []
var _active_finished_usec := 0


class R7TraceBaker:
	extends RiverFlowmapBaker

	var trace_owner: Object = null
	var forced_backend_mode := RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM
	var last_filter_result := {}

	func run_filter_pass_sequence(config: Dictionary, progress: Callable = Callable(), cancellation: Callable = Callable()) -> Dictionary:
		var injected_config := config.duplicate(true)
		injected_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = forced_backend_mode
		var result: Dictionary = await super.run_filter_pass_sequence(injected_config, progress, cancellation)
		last_filter_result = result.duplicate(true)
		return result

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
	var warmup_count := max(0, int(args.get("warmup", "1")))
	var run_count := max(1, int(args.get("runs", "5")))
	var save_requested := _parse_bool(String(args.get("save", "false")))
	if save_requested:
		_errors.append("save=true is not supported for the R7 baseline fixture; generated resources must stay out of shipped paths.")

	var out_abs := ProjectSettings.globalize_path(out_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(out_abs)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_errors.append("Could not create output directory " + out_abs + ": " + error_string(dir_error))

	var measured_runs: Array = []
	var warmup_runs: Array = []
	if _errors.is_empty():
		for warmup_index in warmup_count:
			var warmup := await _run_single_bake(scene_path, river_path, "warmup_" + str(warmup_index))
			if not bool(warmup.get("ok", false)):
				_errors.append("Warmup " + str(warmup_index) + " failed.")
				break
			warmup_runs.append(warmup)
		for run_index in run_count:
			if not _errors.is_empty():
				break
			var measured := await _run_single_bake(scene_path, river_path, "run_" + str(run_index))
			if not bool(measured.get("ok", false)):
				_errors.append("Measured run " + str(run_index) + " failed.")
				break
			measured_runs.append(measured)
			_verify_run(measured, "run_" + str(run_index))

	if not measured_runs.is_empty():
		_write_baseline_file(out_dir.path_join(BASELINE_FILE_NAME), scene_path, river_path, warmup_runs, measured_runs)

	if _errors.is_empty():
		for file_path in _written_files:
			print("R7_LEGACY_BASELINE_FILE ", file_path)
		var elapsed_values := _elapsed_values(measured_runs)
		print("R7_LEGACY_BASELINE_OK runs=", measured_runs.size(), " median_ms=", _median(elapsed_values), " out=", out_dir)
		quit(0)
		return

	for error in _errors:
		push_error(error)
	quit(1)


func _run_single_bake(scene_path: String, river_path: String, label: String) -> Dictionary:
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
	var filter_result := trace_baker.last_filter_result.duplicate(true)
	var backend_selection := (filter_result.get("flowmap_backend_selection", {}) as Dictionary).duplicate(true)
	var result := {
		"ok": bake_data != null and not bool(river.call("is_bake_in_progress")),
		"label": label,
		"elapsed_ms": float(_active_finished_usec - _active_run_start_usec) / 1000.0,
		"frame_gaps_ms": frame_gaps.duplicate(),
		"frame_count": frame_count,
		"max_frame_gap_ms": _max_float(frame_gaps),
		"p95_frame_gap_ms": _percentile(frame_gaps, 0.95),
		"progress_events": _active_progress_events.duplicate(true),
		"pass_trace": _active_pass_trace.duplicate(true),
		"pass_counts": _count_passes(_active_pass_trace),
		"bake_data": bake_data,
		"metadata": _resource_dictionary(bake_data, "source_metadata"),
		"signature": _resource_dictionary(bake_data, "source_signature"),
		"settings": _resource_dictionary(bake_data, "bake_settings"),
		"source_signature_version": int(bake_data.get("source_signature_version")) if bake_data != null else -1,
		"flowmap_backend_mode": String(filter_result.get("flowmap_backend_mode", "")),
		"flowmap_backend_selection": backend_selection,
		"production_output_replaced": bool(filter_result.get("production_output_replaced", false)),
		"texture_hashes": _hash_bake_textures(bake_data),
		"water_occupancy_stats": _water_occupancy_stats(bake_data),
		"result_handoff": _result_handoff_state(river, bake_data),
		"resource_path": bake_data.resource_path if bake_data != null else "",
	}
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


func _record_pass_trace(label: String, start_usec: int, end_usec: int, ok: bool, reason: String) -> void:
	_active_pass_trace.append({
		"label": label,
		"start_ms": float(start_usec - _active_run_start_usec) / 1000.0,
		"end_ms": float(end_usec - _active_run_start_usec) / 1000.0,
		"duration_ms": float(end_usec - start_usec) / 1000.0,
		"ok": ok,
		"reason": reason,
	})


func _verify_run(run: Dictionary, label: String) -> void:
	if not bool(run.get("ok", false)):
		_errors.append(label + ": bake_data was missing or bake was still in progress.")
		return
	var metadata: Dictionary = run.get("metadata", {})
	var signature: Dictionary = run.get("signature", {})
	var settings: Dictionary = run.get("settings", {})
	var pass_counts: Dictionary = run.get("pass_counts", {})
	var texture_hashes: Dictionary = run.get("texture_hashes", {})
	var occupancy_stats: Dictionary = run.get("water_occupancy_stats", {})
	var handoff: Dictionary = run.get("result_handoff", {})
	var backend_selection: Dictionary = run.get("flowmap_backend_selection", {})

	_expect(int(run.get("source_signature_version", -1)) == 29, label + ": source_signature_version should be 29.")
	_expect(String(run.get("flowmap_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, label + ": flowmap backend should be explicit legacy_canvas_item.")
	_expect(bool(backend_selection.get("explicit_selection", false)), label + ": legacy backend selection should be explicit.")
	_expect(String(backend_selection.get("requested_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, label + ": requested backend should be legacy_canvas_item.")
	_expect(String(backend_selection.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, label + ": selected backend should be legacy_canvas_item.")
	_expect(not bool(run.get("production_output_replaced", true)), label + ": legacy trace should not replace output with compute.")
	_expect(String(metadata.get("generation_behavior", "")) == TARGET_GENERATION_BEHAVIOR, label + ": generation_behavior metadata did not match target.")
	_expect(String(signature.get("bake_generation_behavior", "")) == TARGET_GENERATION_BEHAVIOR, label + ": source signature generation behavior did not match target.")
	_expect(String(settings.get("bake_generation_behavior", "")) == TARGET_GENERATION_BEHAVIOR, label + ": bake settings generation behavior did not match target.")
	_expect(int(signature.get("baking_resolution", -1)) == 0, label + ": baking_resolution signature should be 0.")
	_expect(int(signature.get("baking_raycast_layers", -1)) == 1, label + ": baking_raycast_layers signature should be 1.")
	_expect(int(signature.get("shape_step_length_divs", -1)) == 1, label + ": shape_step_length_divs signature should be 1.")
	_expect(int(signature.get("shape_step_width_divs", -1)) == 1, label + ": shape_step_width_divs signature should be 1.")

	var hit_count := int(metadata.get("collision_hit_pixel_count", 0))
	var total_count := int(metadata.get("collision_total_pixel_count", 0))
	var hit_percent := float(metadata.get("collision_hit_pixel_percent", 0.0))
	_expect(not bool(metadata.get("collision_probe_skipped", true)), label + ": collision probe was skipped.")
	_expect(hit_count > 0, label + ": collision_hit_pixel_count must be > 0.")
	_expect(total_count > 0, label + ": collision_total_pixel_count must be > 0.")
	_expect(hit_count < total_count, label + ": collision map cannot be full coverage.")
	_expect(hit_count >= 32, label + ": collision hit pixels below R7 minimum of 32.")
	_expect(hit_percent < 70.0, label + ": collision coverage must stay below 70%.")
	_expect(not bool(metadata.get("support_fallback_applied", true)), label + ": support fallback was applied.")
	_expect(String(metadata.get("support_fallback_reason", "")) == "", label + ": support fallback reason should be empty.")
	_expect(bool(metadata.get("collision_support_filters_ran", false)), label + ": collision support filters did not run.")
	_expect(bool(metadata.get("water_occupancy_baked", false)), label + ": water occupancy was not baked.")
	_expect(bool(metadata.get("obstacle_avoidance_applied", false)), label + ": obstacle avoidance was not applied.")
	_expect(bool(metadata.get("flow_projected", false)), label + ": flow was not projected.")
	_expect(not bool(metadata.get("flow_speed_scaled", true)), label + ": neutral fixture should not run flow-speed scaling.")

	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var entry: Dictionary = texture_hashes.get(texture_name, {})
		_expect(bool(entry.get("present", false)), label + ": texture missing or unreadable: " + texture_name)

	_expect(int(occupancy_stats.get("solid_pixels", 0)) > 0, label + ": water_occupancy solid coverage is zero.")
	_expect(int(occupancy_stats.get("solid_pixels", 0)) < int(occupancy_stats.get("sampled_pixels", 0)), label + ": water_occupancy solid coverage is full.")
	_expect(int(occupancy_stats.get("proximity_ring_pixels", 0)) > 0, label + ": water_occupancy proximity ring coverage is zero.")

	var obstacle_stats: Dictionary = metadata.get("obstacle_feature_stats", {})
	var side_stats: Dictionary = obstacle_stats.get("side_deflection_confidence", {})
	_expect(float(side_stats.get("max", 0.0)) > 0.05, label + ": obstacle side-deflection confidence stayed neutral.")
	var rich_feature_present := false
	for feature_name in ["pillow_impact", "wake_eddy_seed", "eddy_line_shear"]:
		var feature_stats: Dictionary = obstacle_stats.get(feature_name, {})
		if float(feature_stats.get("max", 0.0)) > 0.05:
			rich_feature_present = true
	_expect(rich_feature_present, label + ": obstacle feature mask lacked pillow, wake/eddy, or eddy-line coverage.")

	var flow_diagnostics: Dictionary = metadata.get("flow_vector_diagnostics", {})
	var occupied_flow: Dictionary = flow_diagnostics.get("occupied", {})
	_expect(int(occupied_flow.get("sampled_pixel_count", 0)) > 0, label + ": occupied flow diagnostics sampled no texels.")

	for pass_label in EXPECTED_PASS_COUNTS.keys():
		_expect(int(pass_counts.get(pass_label, 0)) == int(EXPECTED_PASS_COUNTS[pass_label]), label + ": pass count for '" + pass_label + "' expected " + str(EXPECTED_PASS_COUNTS[pass_label]) + " got " + str(pass_counts.get(pass_label, 0)))
	_expect(int(pass_counts.get("flow pressure jacobi pass", 0)) == 40, label + ": jacobi_pass_count must be 40.")
	for required_label in REQUIRED_PROJECTION_LABELS:
		_expect(_progress_contains_prefix(run.get("progress_events", []), required_label), label + ": missing public progress label prefix " + required_label)

	_expect(bool(handoff.get("valid_flowmap", false)), label + ": RiverManager valid_flowmap was not true.")
	_expect(bool(handoff.get("shader_i_valid_flowmap", false)), label + ": material i_valid_flowmap did not reach true.")
	_expect(bool(handoff.get("river_textures_match_bake", false)), label + ": RiverManager texture fields do not match bake_data.")
	_expect(bool(handoff.get("material_bindings_match", false)), label + ": material bindings do not match final textures.")
	_expect(String(run.get("resource_path", "")) == "", label + ": bake_data.resource_path should remain empty for save=false.")
	_expect(float(run.get("max_frame_gap_ms", 0.0)) <= 1000.0, label + ": max frame gap exceeded 1000 ms.")


func _progress_contains_prefix(progress_events: Array, prefix: String) -> bool:
	for event in progress_events:
		if String((event as Dictionary).get("label", "")).begins_with(prefix):
			return true
	return false


func _count_passes(pass_trace: Array) -> Dictionary:
	var counts := {}
	for event in pass_trace:
		var entry: Dictionary = event
		var label := String(entry.get("label", ""))
		counts[label] = int(counts.get(label, 0)) + 1
	for expected_label in EXPECTED_PASS_COUNTS.keys():
		if not counts.has(expected_label):
			counts[expected_label] = 0
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


func _water_occupancy_stats(bake_data: Resource) -> Dictionary:
	var stats := {
		"sampled_pixels": 0,
		"solid_pixels": 0,
		"proximity_pixels": 0,
		"proximity_ring_pixels": 0,
	}
	if bake_data == null:
		return stats
	var texture := bake_data.get("water_occupancy") as Texture2D
	if texture == null:
		return stats
	var image := texture.get_image()
	if image == null or image.is_empty():
		return stats
	var content_rect: Rect2i = bake_data.get("content_rect")
	var uv2_sides := maxi(1, int(bake_data.get("uv2_sides")))
	var steps := clampi(int(_resource_dictionary(bake_data, "source_signature").get("step_count", 0)), 0, uv2_sides * uv2_sides)
	var source_rect := Rect2i(
		clampi(content_rect.position.x, 0, image.get_width()),
		clampi(content_rect.position.y, 0, image.get_height()),
		maxi(0, mini(content_rect.size.x, image.get_width() - clampi(content_rect.position.x, 0, image.get_width()))),
		maxi(0, mini(content_rect.size.y, image.get_height() - clampi(content_rect.position.y, 0, image.get_height())))
	)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return stats
	for step_index in steps:
		var tile_rect := _uv2_tile_rect(step_index, uv2_sides, source_rect)
		for y in tile_rect.size.y:
			for x in tile_rect.size.x:
				var color := image.get_pixel(tile_rect.position.x + x, tile_rect.position.y + y)
				var solid := color.r > 0.5
				var proximity := color.g > 0.05
				stats.sampled_pixels = int(stats.sampled_pixels) + 1
				if solid:
					stats.solid_pixels = int(stats.solid_pixels) + 1
				if proximity:
					stats.proximity_pixels = int(stats.proximity_pixels) + 1
				if proximity and not solid:
					stats.proximity_ring_pixels = int(stats.proximity_ring_pixels) + 1
	return stats


func _uv2_tile_rect(step_index: int, side: int, source_rect: Rect2i) -> Rect2i:
	var x_index := step_index % side
	var y_index := step_index / side
	var x0 := int(floor(float(x_index) * float(source_rect.size.x) / float(side)))
	var y0 := int(floor(float(y_index) * float(source_rect.size.y) / float(side)))
	var x1 := int(floor(float(x_index + 1) * float(source_rect.size.x) / float(side)))
	var y1 := int(floor(float(y_index + 1) * float(source_rect.size.y) / float(side)))
	return Rect2i(source_rect.position + Vector2i(x0, y0), Vector2i(maxi(1, x1 - x0), maxi(1, y1 - y0)))


func _result_handoff_state(river: Node, bake_data: Resource) -> Dictionary:
	var state := {
		"valid_flowmap": false,
		"shader_i_valid_flowmap": false,
		"river_textures_match_bake": false,
		"material_bindings_match": false,
	}
	if river == null or bake_data == null:
		return state
	state.valid_flowmap = bool(river.get("valid_flowmap"))
	state.shader_i_valid_flowmap = bool(river.call("get_shader_param", "i_valid_flowmap"))
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


func _write_baseline_file(file_path: String, scene_path: String, river_path: String, warmup_runs: Array, measured_runs: Array) -> void:
	var lines := PackedStringArray()
	lines.append("R7_LEGACY_BASELINE_DUMP v1")
	lines.append("scene=" + scene_path)
	lines.append("river=" + river_path)
	lines.append("godot_version=" + str(Engine.get_version_info()))
	lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())
	lines.append("warmup_count=" + str(warmup_runs.size()))
	lines.append("measured_count=" + str(measured_runs.size()))
	var elapsed_values := _elapsed_values(measured_runs)
	lines.append("elapsed_ms_median=" + str(_median(elapsed_values)))
	lines.append("elapsed_ms_min=" + str(_min_float(elapsed_values)))
	lines.append("elapsed_ms_max=" + str(_max_float(elapsed_values)))
	for run_index in measured_runs.size():
		_append_run_lines(lines, measured_runs[run_index], run_index)
	_write_text_file(file_path, "\n".join(lines) + "\n")


func _append_run_lines(lines: PackedStringArray, run: Dictionary, run_index: int) -> void:
	var prefix := "run[" + str(run_index) + "]."
	lines.append(prefix + "elapsed_ms=" + str(float(run.get("elapsed_ms", 0.0))))
	lines.append(prefix + "frame_count=" + str(int(run.get("frame_count", 0))))
	lines.append(prefix + "max_frame_gap_ms=" + str(float(run.get("max_frame_gap_ms", 0.0))))
	lines.append(prefix + "p95_frame_gap_ms=" + str(float(run.get("p95_frame_gap_ms", 0.0))))
	lines.append(prefix + "resource_path=" + String(run.get("resource_path", "")))
	lines.append(prefix + "source_signature_version=" + str(int(run.get("source_signature_version", -1))))
	lines.append(prefix + "flowmap_backend_mode=" + String(run.get("flowmap_backend_mode", "")))
	var backend_selection: Dictionary = run.get("flowmap_backend_selection", {})
	lines.append(prefix + "flowmap_backend_requested_mode=" + String(backend_selection.get("requested_mode", "")))
	lines.append(prefix + "flowmap_backend_selected_mode=" + String(backend_selection.get("selected_mode", "")))
	var metadata: Dictionary = run.get("metadata", {})
	for key in [
		"generation_behavior",
		"collision_probe_skipped",
		"collision_hit_pixel_count",
		"collision_total_pixel_count",
		"collision_hit_pixel_percent",
		"support_fallback_applied",
		"support_fallback_reason",
		"collision_support_filters_ran",
		"water_occupancy_baked",
		"obstacle_avoidance_applied",
		"flow_projected",
		"flow_speed_scaled",
	]:
		lines.append(prefix + "metadata." + key + "=" + str(metadata.get(key, null)))
	var flow_diagnostics: Dictionary = metadata.get("flow_vector_diagnostics", {})
	var occupied_flow: Dictionary = flow_diagnostics.get("occupied", {})
	lines.append(prefix + "occupied_flow_sampled_pixel_count=" + str(occupied_flow.get("sampled_pixel_count", 0)))
	var settings: Dictionary = run.get("settings", {})
	_append_dictionary_lines(lines, prefix + "bake_settings.", settings)
	var occupancy_stats: Dictionary = run.get("water_occupancy_stats", {})
	for key in occupancy_stats.keys():
		lines.append(prefix + "water_occupancy." + String(key) + "=" + str(occupancy_stats[key]))
	var obstacle_stats: Dictionary = metadata.get("obstacle_feature_stats", {})
	for feature_name in ["pillow_impact", "wake_eddy_seed", "eddy_line_shear", "side_deflection_confidence"]:
		var feature_stats: Dictionary = obstacle_stats.get(feature_name, {})
		lines.append(prefix + "obstacle_features." + feature_name + ".max=" + str(float(feature_stats.get("max", 0.0))))
		lines.append(prefix + "obstacle_features." + feature_name + ".above_0_05_percent=" + str(float(feature_stats.get("above_0_05_percent", 0.0))))
	var pass_counts: Dictionary = run.get("pass_counts", {})
	for pass_label in EXPECTED_PASS_COUNTS.keys():
		lines.append(prefix + "pass_count." + pass_label + "=" + str(int(pass_counts.get(pass_label, 0))))
	var texture_hashes: Dictionary = run.get("texture_hashes", {})
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var entry: Dictionary = texture_hashes.get(texture_name, {})
		lines.append(prefix + "texture." + texture_name
				+ ".present=" + str(bool(entry.get("present", false)))
				+ " size=" + str(entry.get("size", Vector2i.ZERO))
				+ " format=" + str(entry.get("format", -1))
				+ " md5=" + String(entry.get("md5", "")))
	var handoff: Dictionary = run.get("result_handoff", {})
	for key in handoff.keys():
		lines.append(prefix + "handoff." + String(key) + "=" + str(handoff[key]))
	var progress_events: Array = run.get("progress_events", [])
	lines.append(prefix + "progress_event_count=" + str(progress_events.size()))
	for progress_index in progress_events.size():
		var event: Dictionary = progress_events[progress_index]
		lines.append(prefix + "progress[" + str(progress_index) + "] elapsed_ms=" + str(float(event.get("elapsed_ms", 0.0))) + " value=" + str(float(event.get("progress", 0.0))) + " label=" + String(event.get("label", "")))
	var pass_trace: Array = run.get("pass_trace", [])
	lines.append(prefix + "pass_trace_count=" + str(pass_trace.size()))
	for trace_index in pass_trace.size():
		var event: Dictionary = pass_trace[trace_index]
		lines.append(prefix + "pass_trace[" + str(trace_index) + "] label=" + String(event.get("label", "")) + " ok=" + str(bool(event.get("ok", false))) + " duration_ms=" + str(float(event.get("duration_ms", 0.0))))


func _append_dictionary_lines(lines: PackedStringArray, prefix: String, values: Dictionary) -> void:
	var keys := values.keys()
	keys.sort()
	for key in keys:
		lines.append(prefix + String(key) + "=" + str(values[key]))


func _write_text_file(file_path: String, text: String) -> void:
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
	file.store_string(text)
	file.close()
	_written_files.append(file_path)


func _elapsed_values(runs: Array) -> Array:
	var values := []
	for run in runs:
		values.append(float((run as Dictionary).get("elapsed_ms", 0.0)))
	return values


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[middle])
	return (float(sorted[middle - 1]) + float(sorted[middle])) * 0.5


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


func _parse_bool(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args
