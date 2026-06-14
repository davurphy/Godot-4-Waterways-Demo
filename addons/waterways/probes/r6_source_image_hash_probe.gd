# River-refactor R6.1D source-image hash probe (headless OK).
#
# Captures the full raw-plus-margin intermediate source-image list. The probe
# mirrors the source-generation portion of RiverManager._generate_flowmap(),
# exercises the baker-owned source helpers, and stops before filter renderer
# creation.
#
# Run:
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/r6_source_image_hash_probe.gd
#
# Optional args after `--`:
#   out=res://.codex-research/r6-baselines/pre-r6
#
# Success marker: R6_SOURCE_IMAGE_HASH_OK
extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")
const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")

const DEFAULT_OUT_DIR := "res://.codex-research/r6-baselines/pre-r6"
const DEFAULT_RIVER_PATH := "WaterSystem/Water River"

const SCENE_TARGETS := [
	{
		"label": "demo",
		"path": "res://Demo.tscn",
		"river": DEFAULT_RIVER_PATH,
	},
	{
		"label": "demo_obstacle_flow_test",
		"path": "res://Demo_obstacle_flow_test.tscn",
		"river": DEFAULT_RIVER_PATH,
	},
]

var _errors := PackedStringArray()
var _written_files := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var out_abs := ProjectSettings.globalize_path(out_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(out_abs)
	if dir_error != OK:
		push_error("Could not create output directory " + out_abs + ": " + error_string(dir_error))
		quit(1)
		return

	for target_variant in SCENE_TARGETS:
		var target: Dictionary = target_variant
		await _dump_scene_source_images(out_dir, target)

	if _errors.is_empty():
		for file_path in _written_files:
			print("R6_SOURCE_IMAGE_HASH_FILE ", file_path)
		print("R6_SOURCE_IMAGE_HASH_OK out=", out_dir, " files=", _written_files.size())
		quit(0)
		return

	for error in _errors:
		push_error(error)
	quit(1)


func _dump_scene_source_images(out_dir: String, target: Dictionary) -> void:
	var label := String(target.get("label", ""))
	var scene_path := String(target.get("path", ""))
	var river_path := String(target.get("river", DEFAULT_RIVER_PATH))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + scene_path)
		return

	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		_errors.append("Could not find river " + river_path + " in " + scene_path)
		scene.queue_free()
		await process_frame
		return

	var entries := await _collect_source_entries(river, label)
	if entries.is_empty():
		_errors.append("No source-image entries captured for " + label)
	else:
		_write_source_hash_file(
			out_dir.path_join(label + "__source_image_hashes.txt"),
			label,
			scene_path,
			river_path,
			entries
		)

	scene.queue_free()
	await process_frame


func _collect_source_entries(river: Node, label: String) -> Array:
	var entries := []
	var source_baker := RiverFlowmapBaker.new()
	river.call("_generate_river")
	await process_frame

	var flowmap_resolution := int(river.call("_get_river_bake_texture_size"))
	var generation_behavior := String(river.call("_sanitize_bake_generation_behavior", river.get("bake_generation_behavior")))
	var signature: Dictionary = river.call("get_bake_source_signature")
	var steps := int(signature.get("step_count", maxi(1, int(river.get("_steps")))))
	var uv2_sides := WaterHelperMethods.calculate_side(steps)
	var margin := int(round(float(flowmap_resolution) / float(maxi(1, uv2_sides))))
	var source_size := Vector2i(flowmap_resolution, flowmap_resolution)
	var padded_size := Vector2i(flowmap_resolution + 2 * margin, flowmap_resolution + 2 * margin)
	var uses_downstream := bool(river.call("_uses_downstream_baseline_generation", generation_behavior))
	var collision_probe_skipped := bool(river.call("_is_curve_only_generation", generation_behavior))
	var support_fallback_reason := "curve_only" if collision_probe_skipped else ""
	if not collision_probe_skipped and generation_behavior == "downstream_baseline_collision_support" and int(river.get("baking_raycast_layers")) == 0:
		collision_probe_skipped = true
		support_fallback_reason = "baking_raycast_layers_zero"

	var collision_source := Image.create(flowmap_resolution, flowmap_resolution, true, Image.FORMAT_RGB8)
	collision_source.fill(Color(0.0, 0.0, 0.0))
	if not collision_probe_skipped:
		WaterHelperMethods.reset_all_colliders(river.get_tree().root)
		await process_frame
		collision_source = await WaterHelperMethods.generate_collisionmap(
			collision_source,
			river.get("mesh_instance"),
			float(river.get("baking_raycast_distance")),
			int(river.get("baking_raycast_layers")),
			steps,
			int(river.get("shape_step_length_divs")),
			int(river.get("shape_step_width_divs")),
			river
		)
		if collision_source == null or collision_source.is_empty():
			_errors.append("Collision source generation failed for " + label)
			return entries
		var collision_stats: Dictionary = source_baker.get_collision_map_stats(collision_source)
		if uses_downstream and int(collision_stats.get("hit_pixel_count", 0)) == 0:
			support_fallback_reason = "no_collision_hits"

	var support_fallback_applied := not support_fallback_reason.is_empty()
	var run_collision_support_filters := not support_fallback_applied
	_append_image_entry(entries, "collision_source", collision_source, not collision_probe_skipped, "post_collision_generation")
	_append_image_entry(entries, "collision_with_margins", source_baker.create_margin_image(collision_source, float(flowmap_resolution), margin, steps), run_collision_support_filters, "filter_support_source")

	var downstream_baseline: Image = null
	if uses_downstream:
		var downstream_strength := float(signature.get("downstream_baseline_strength", 0.25))
		downstream_baseline = WaterHelperMethods.create_downstream_baseline_flow_image(flowmap_resolution, uv2_sides, steps, downstream_strength)
	_append_image_entry(entries, "downstream_baseline_source", downstream_baseline, uses_downstream, "raw")
	_append_image_entry(entries, "downstream_baseline_with_margins", source_baker.create_margin_image(downstream_baseline, float(flowmap_resolution), margin, steps) if downstream_baseline != null else null, uses_downstream, "filter_source")

	var source_config: Dictionary = river.call("_get_flowmap_source_image_config")
	var blank_support: Image = source_baker.create_blank_support_source_image(flowmap_resolution, source_config)
	var blank_obstacle_features: Image = source_baker.create_blank_obstacle_feature_source_image(flowmap_resolution)
	var blank_terrain_contact_features: Image = source_baker.create_blank_terrain_contact_feature_source_image(flowmap_resolution)
	var blank_bank_response_features: Image = source_baker.create_blank_bank_response_feature_source_image(flowmap_resolution)
	_append_raw_and_margin(entries, source_baker, "blank_support", blank_support, true, flowmap_resolution, margin, steps)
	_append_raw_and_margin(entries, source_baker, "blank_obstacle_features", blank_obstacle_features, true, flowmap_resolution, margin, steps)
	_append_raw_and_margin(entries, source_baker, "blank_terrain_contact_features", blank_terrain_contact_features, true, flowmap_resolution, margin, steps)
	_append_raw_and_margin(entries, source_baker, "blank_bank_response_features", blank_bank_response_features, true, flowmap_resolution, margin, steps)

	var terrain_contact_seed := blank_terrain_contact_features.duplicate(true) as Image
	var terrain_contact_source := await WaterHelperMethods.generate_terrain_contact_feature_map(
		terrain_contact_seed,
		river.get("mesh_instance"),
		int(river.get("baking_raycast_layers")),
		steps,
		int(river.get("shape_step_length_divs")),
		int(river.get("shape_step_width_divs")),
		river,
		river.call("_get_terrain_contact_feature_settings")
	)
	if terrain_contact_source == null or terrain_contact_source.is_empty():
		_errors.append("Terrain-contact source generation failed for " + label)
		return entries
	_append_image_entry(entries, "terrain_contact_source", terrain_contact_source, true, "pre_smooth")
	var terrain_contact_smoothed := terrain_contact_source.duplicate(true) as Image
	WaterHelperMethods.smooth_uv2_tile_channels(
		terrain_contact_smoothed,
		uv2_sides,
		steps,
		int(signature.get("terrain_contact_edge_smooth_passes", 1))
	)
	_append_image_entry(entries, "terrain_contact_smoothed_source", terrain_contact_smoothed, true, "post_smooth")
	_append_image_entry(entries, "terrain_contact_with_margins", source_baker.create_margin_image(terrain_contact_smoothed, float(flowmap_resolution), margin, steps), true, "filter_source")

	var occupancy_threshold := float(signature.get("water_occupancy_protrusion_threshold", 0.9))
	var occupancy_confidence_min := float(signature.get("water_occupancy_protrusion_confidence_min", 0.75))
	var solid_occupancy := WaterHelperMethods.create_solid_occupancy_source_image(collision_source, terrain_contact_smoothed, occupancy_threshold, occupancy_confidence_min)
	_append_raw_and_margin(entries, source_baker, "solid_occupancy", solid_occupancy, run_collision_support_filters, flowmap_resolution, margin, steps)

	source_config = river.call("_get_flowmap_source_image_config")
	var grade_energy: Image = source_baker.create_curve_grade_energy_source_image(flowmap_resolution, uv2_sides, steps, source_config)
	var bend_bias: Image = source_baker.create_curve_bend_bias_source_image(flowmap_resolution, uv2_sides, steps, source_config)
	var flow_speed: Image = source_baker.create_curve_flow_speed_source_image(flowmap_resolution, uv2_sides, steps, source_config)
	_append_raw_and_margin(entries, source_baker, "grade_energy", grade_energy, true, flowmap_resolution, margin, steps)
	_append_raw_and_margin(entries, source_baker, "bend_bias", bend_bias, true, flowmap_resolution, margin, steps)
	_append_raw_and_margin(entries, source_baker, "flow_speed", flow_speed, bool(river.call("_any_flow_speed_non_neutral")), flowmap_resolution, margin, steps)

	_append_image_entry(entries, "tiled_flow_offset_noise", _create_tiled_flow_offset_noise(source_baker, signature, uv2_sides), true, "filter_source")
	entries.push_front({
		"label": "__run_context__",
		"present": true,
		"used": true,
		"size": source_size,
		"padded_size": padded_size,
		"format": -1,
		"sha256": "",
		"note": "flowmap_resolution=" + str(flowmap_resolution)
				+ " uv2_sides=" + str(uv2_sides)
				+ " steps=" + str(steps)
				+ " margin=" + str(margin)
				+ " generation_behavior=" + generation_behavior
				+ " support_fallback_reason=" + support_fallback_reason
				+ " flow_speed_scale_would_run=" + str(bool(river.call("_any_flow_speed_non_neutral"))),
	})
	return entries


func _append_raw_and_margin(entries: Array, source_baker, base_label: String, image: Image, used: bool, flowmap_resolution: int, margin: int, steps: int) -> void:
	_append_image_entry(entries, base_label + "_source", image, used, "raw")
	_append_image_entry(entries, base_label + "_with_margins", source_baker.create_margin_image(image, float(flowmap_resolution), margin, steps) if image != null else null, used, "margin_padded")


func _append_image_entry(entries: Array, label: String, image: Image, used: bool, note: String) -> void:
	var hash := _hash_image(image)
	hash["label"] = label
	hash["used"] = used
	hash["note"] = note
	entries.append(hash)


func _create_tiled_flow_offset_noise(source_baker, signature: Dictionary, uv2_sides: int) -> Image:
	var noise_path := String(signature.get("flow_offset_noise_texture_path", ""))
	var noise_texture := load(noise_path) as Texture2D
	if noise_texture == null:
		_errors.append("Could not load flow offset noise texture: " + noise_path)
		return null
	var noise_with_tiling: Image = source_baker.create_tiled_flow_offset_noise(noise_texture, uv2_sides)
	if noise_with_tiling == null or noise_with_tiling.is_empty():
		_errors.append("Could not read flow offset noise image: " + noise_path)
		return null
	return noise_with_tiling


func _hash_image(image: Image) -> Dictionary:
	var entry := {
		"present": false,
		"size": Vector2i.ZERO,
		"format": -1,
		"sha256": "absent",
	}
	if image == null or image.is_empty():
		return entry
	entry.present = true
	entry.size = image.get_size()
	entry.format = image.get_format()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	entry.sha256 = context.finish().hex_encode()
	return entry


func _write_source_hash_file(file_path: String, label: String, scene_path: String, river_path: String, entries: Array) -> void:
	var lines := PackedStringArray()
	lines.append("R6_SOURCE_IMAGE_HASH_DUMP v1")
	lines.append("target=" + label + " " + scene_path + " " + river_path)
	lines.append("entry_count=" + str(entries.size()))
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		if String(entry.get("label", "")) == "__run_context__":
			lines.append("context " + String(entry.get("note", "")))
			continue
		lines.append("source=" + String(entry.get("label", ""))
				+ " present=" + str(bool(entry.get("present", false)))
				+ " used_in_current_bake=" + str(bool(entry.get("used", false)))
				+ " size=" + str(entry.get("size", Vector2i.ZERO))
				+ " format=" + str(int(entry.get("format", -1)))
				+ " sha256=" + String(entry.get("sha256", ""))
				+ " note=" + String(entry.get("note", "")))
	_write_text_file(file_path, "\n".join(lines) + "\n")


func _write_text_file(file_path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK:
		_errors.append("Could not create output parent " + parent + ": " + error_string(dir_error))
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write " + absolute_path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(text)
	file.close()
	_written_files.append(file_path)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args
