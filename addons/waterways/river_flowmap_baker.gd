# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends RefCounted

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

var _running := false
var _aborted := false
var _renderer_parent: Node = null
var _renderer_instance: Node = null
var _last_abort_reason := ""
var _warning_callback := Callable()
var _cancellation_callback := Callable()


func bake(config: Dictionary, progress: Callable, cancellation: Callable = Callable()) -> Dictionary:
	if _running:
		return _make_abort_result("already_running")
	_running = true
	_aborted = false
	_last_abort_reason = ""
	_warning_callback = config.get("warning_callback", Callable())
	_cancellation_callback = cancellation
	if _is_cancellation_requested(cancellation):
		return _abort_with_cleanup("cancelled")
	var renderer_scene := config.get("filter_renderer_scene") as PackedScene
	if renderer_scene == null:
		_emit_warning("Waterways: River Flow & Foam bake failed because the filter renderer scene could not be loaded.")
		return _abort_with_cleanup("renderer_scene_missing")
	_renderer_parent = config.get("renderer_parent") as Node
	if _renderer_parent == null or not is_instance_valid(_renderer_parent) or not _renderer_parent.is_inside_tree():
		_emit_warning("Waterways: River Flow & Foam bake failed because the filter renderer parent was not available.")
		return _abort_with_cleanup("renderer_parent_missing")
	var renderer_instance := renderer_scene.instantiate()
	if renderer_instance == null:
		_emit_warning("Waterways: River Flow & Foam bake failed because the filter renderer could not be instantiated.")
		return _abort_with_cleanup("renderer_instantiate_failed")
	_renderer_instance = renderer_instance
	_renderer_parent.add_child(_renderer_instance)
	if _is_cancellation_requested(cancellation):
		return _abort_with_cleanup("cancelled")
	if bool(config.get("await_renderer_ready_frame", false)) and _renderer_parent != null and is_instance_valid(_renderer_parent):
		await _renderer_parent.get_tree().process_frame
		if _is_cancellation_requested(cancellation):
			return _abort_with_cleanup("cancelled")
	return {
		"ok": true,
		"renderer": _renderer_instance
	}


func abort() -> void:
	_aborted = true
	if _last_abort_reason.is_empty():
		_last_abort_reason = "aborted"
	cleanup()


func is_running() -> bool:
	return _running


func cleanup() -> void:
	var renderer := _renderer_instance
	_renderer_instance = null
	_renderer_parent = null
	_running = false
	_warning_callback = Callable()
	_cancellation_callback = Callable()
	if renderer == null or not is_instance_valid(renderer):
		return
	if renderer.get_parent() != null:
		renderer.get_parent().remove_child(renderer)
	renderer.queue_free()


func validate_pass_result(label: String, texture: Texture2D) -> Dictionary:
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		return {
			"ok": true,
			"texture": texture
		}
	return _abort_pass_with_cleanup(label, _get_renderer_readback_error())


func create_margin_texture(source_image: Image, source_resolution: float, margin: int, steps: int) -> ImageTexture:
	return ImageTexture.create_from_image(create_margin_image(source_image, source_resolution, margin, steps))


func create_margin_image(source_image: Image, source_resolution: float, margin: int, steps: int) -> Image:
	return WaterHelperMethods.add_margins(source_image, source_resolution, margin, steps)


func create_blank_support_source_image(resolution: int, source_config: Dictionary) -> Image:
	return _create_uniform_support_source_image(resolution, _config_float(source_config, "blank_support_value", 0.0))


func create_blank_obstacle_feature_source_image(resolution: int) -> Image:
	return _create_blank_feature_source_image(resolution)


func create_blank_terrain_contact_feature_source_image(resolution: int) -> Image:
	return _create_blank_feature_source_image(resolution)


func create_blank_bank_response_feature_source_image(resolution: int) -> Image:
	return _create_blank_feature_source_image(resolution)


func create_curve_grade_energy_source_image(resolution: int, uv2_sides: int, occupied_steps: int, source_config: Dictionary) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var neutral_value := _config_float(source_config, "neutral_grade_energy_value", 0.0)
	image.fill(Color(neutral_value, neutral_value, neutral_value, 1.0))
	var side := maxi(1, uv2_sides)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	if safe_occupied_steps <= 0:
		return image
	var grade_energy_by_step := _calculate_curve_grade_energy_by_step(safe_occupied_steps, source_config)
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			var local_y := _tile_axis_vertex_aligned_ratio(y, tile_rect.size.y)
			var step_progress := float(step_index) + local_y
			var grade_energy := clampf(_sample_step_value_linear(grade_energy_by_step, step_progress, neutral_value), 0.0, 1.0)
			var color := Color(grade_energy, grade_energy, grade_energy, 1.0)
			for x in tile_rect.size.x:
				image.set_pixel(tile_rect.position.x + x, tile_rect.position.y + y, color)
	return image


func create_curve_flow_speed_source_image(resolution: int, uv2_sides: int, occupied_steps: int, source_config: Dictionary) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var neutral_factor := _config_float(source_config, "neutral_flow_speed_factor", 1.0)
	var max_factor := _config_float(source_config, "flow_speed_factor_max", 2.0)
	var neutral_packed := neutral_factor / maxf(max_factor, WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
	image.fill(Color(neutral_packed, neutral_packed, neutral_packed, 1.0))
	var side := maxi(1, uv2_sides)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	if safe_occupied_steps <= 0:
		return image
	var flow_speed_by_step := _calculate_curve_flow_speed_by_step(safe_occupied_steps, source_config)
	var min_factor := _config_float(source_config, "flow_speed_factor_min", 0.0)
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			var local_y := _tile_axis_vertex_aligned_ratio(y, tile_rect.size.y)
			var step_progress := float(step_index) + local_y
			var flow_speed := clampf(_sample_step_value_linear(flow_speed_by_step, step_progress, neutral_factor), min_factor, max_factor)
			var packed := flow_speed / maxf(max_factor, WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
			var color := Color(packed, packed, packed, 1.0)
			for x in tile_rect.size.x:
				image.set_pixel(tile_rect.position.x + x, tile_rect.position.y + y, color)
	return image


func create_curve_bend_bias_source_image(resolution: int, uv2_sides: int, occupied_steps: int, source_config: Dictionary) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var neutral_value := _config_float(source_config, "neutral_bend_bias_value", 0.5)
	image.fill(Color(neutral_value, neutral_value, neutral_value, 1.0))
	var side := maxi(1, uv2_sides)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	if safe_occupied_steps <= 0:
		return image
	var bend_bias_by_step := _calculate_curve_bend_bias_by_step(safe_occupied_steps, source_config)
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			var local_y := _tile_axis_vertex_aligned_ratio(y, tile_rect.size.y)
			var step_progress := float(step_index) + local_y
			var signed_outside_side := clampf(_sample_step_value_linear(bend_bias_by_step, step_progress, 0.0), -1.0, 1.0)
			for x in tile_rect.size.x:
				var local_x := _tile_axis_vertex_aligned_ratio(x, tile_rect.size.x)
				var side_from_river_right := 1.0 - 2.0 * local_x
				var signed_bend_bias := clampf(signed_outside_side * side_from_river_right, -1.0, 1.0)
				var packed_bend_bias := signed_bend_bias * 0.5 + 0.5
				var color := Color(packed_bend_bias, packed_bend_bias, packed_bend_bias, 1.0)
				image.set_pixel(tile_rect.position.x + x, tile_rect.position.y + y, color)
	return image


func create_tiled_flow_offset_noise(noise_texture: Texture2D, uv2_sides: int) -> Image:
	if noise_texture == null:
		return null
	var noise_image := noise_texture.get_image()
	if noise_image == null or noise_image.is_empty():
		return null
	var safe_uv2_sides := maxi(1, uv2_sides)
	var noise_with_margin_size := float(safe_uv2_sides + 2) * (float(noise_texture.get_width()) / float(safe_uv2_sides))
	var noise_with_tiling := Image.create(int(noise_with_margin_size), int(noise_with_margin_size), false, Image.FORMAT_RGB8)
	var slice_width := float(noise_texture.get_width()) / float(safe_uv2_sides)
	for x in safe_uv2_sides:
		noise_with_tiling.blend_rect(
			noise_image,
			Rect2i(0, 0, int(slice_width), noise_texture.get_height()),
			Vector2i(int(slice_width + float(x) * slice_width), int(slice_width - (noise_texture.get_width() / 2.0)))
		)
		noise_with_tiling.blend_rect(
			noise_image,
			Rect2i(0, 0, int(slice_width), noise_texture.get_height()),
			Vector2i(int(slice_width + float(x) * slice_width), int(slice_width + (noise_texture.get_width() / 2.0)))
		)
	return noise_with_tiling


func make_blank_collision_map_stats(resolution: int) -> Dictionary:
	var safe_resolution := maxi(0, resolution)
	return {
		"hit_pixel_count": 0,
		"total_pixel_count": safe_resolution * safe_resolution,
		"hit_pixel_percent": 0.0
	}


func get_collision_map_stats(image: Image) -> Dictionary:
	var total_pixels := 0
	var hit_pixels := 0
	if image != null and not image.is_empty():
		total_pixels = image.get_width() * image.get_height()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).r > 0.5:
					hit_pixels += 1
	var hit_percent := 0.0
	if total_pixels > 0:
		hit_percent = 100.0 * float(hit_pixels) / float(total_pixels)
	return {
		"hit_pixel_count": hit_pixels,
		"total_pixel_count": total_pixels,
		"hit_pixel_percent": hit_percent
	}


func warn_if_collision_map_empty(image: Image, uses_downstream_baseline_generation: bool, support_fallback_reason: String = "", warning_callback: Callable = Callable()) -> void:
	if image == null or image.is_empty():
		_emit_warning("Waterways: River collision bake produced no readable collision image.", warning_callback)
		return
	var stats := get_collision_map_stats(image)
	var hit_pixels := int(stats.get("hit_pixel_count", 0))
	var total_pixels := int(stats.get("total_pixel_count", 0))
	if hit_pixels == 0:
		if uses_downstream_baseline_generation and not support_fallback_reason.is_empty():
			_emit_warning("Waterways: River collision bake found no collider pixels; generated curve downstream flow will use exact blank collision support maps for reduced foam, pressure, and bank detail.", warning_callback)
		else:
			_emit_warning("Waterways: River collision bake found no collider pixels. Check baking raycast layers, collider placement, and raycast distance.", warning_callback)
	elif hit_pixels == total_pixels:
		_emit_warning("Waterways: River collision bake hit every pixel, so generated flow/foam maps may be flat. Use non-uniform bake geometry for visual validation.", warning_callback)


func process_filter_pass_images(config: Dictionary) -> Dictionary:
	var warning_callback: Callable = config.get("warning_callback", Callable())
	var diagnostic_callback: Callable = config.get("diagnostic_callback", Callable())
	var flowmap_resolution := float(config.get("flowmap_resolution", 0.0))
	var uv2_sides := maxi(1, int(config.get("uv2_sides", 1)))
	var steps := maxi(1, int(config.get("steps", 1)))
	var margin := int(config.get("margin", 0))
	var crop_rect := Rect2i(margin, margin, int(flowmap_resolution), int(flowmap_resolution))

	var flow_foam_noise_texture := config.get("flow_foam_noise_texture") as Texture2D
	var dist_pressure_texture := config.get("dist_pressure_texture") as Texture2D
	var obstacle_features_texture := config.get("obstacle_features_texture") as Texture2D
	var bank_response_features_texture := config.get("bank_response_features_texture") as Texture2D
	var water_occupancy_texture := config.get("water_occupancy_texture") as Texture2D
	var terrain_contact_features_result := config.get("terrain_contact_with_margins_image") as Image
	if terrain_contact_features_result == null:
		var terrain_contact_texture := config.get("terrain_contact_with_margins_texture") as Texture2D
		if terrain_contact_texture != null:
			terrain_contact_features_result = terrain_contact_texture.get_image()

	var flow_foam_noise_result: Image = flow_foam_noise_texture.get_image()
	var dist_pressure_result: Image = dist_pressure_texture.get_image()
	var obstacle_features_result: Image = obstacle_features_texture.get_image()
	var bank_response_features_result: Image = bank_response_features_texture.get_image()
	var water_occupancy_result_image: Image = null
	if water_occupancy_texture != null:
		water_occupancy_result_image = water_occupancy_texture.get_image()

	# Filters and combine passes can leave meaningful-looking RG in unused atlas cells.
	# Clear only the source-region unused tiles so occupied seam margins stay intact.
	WaterHelperMethods.neutralize_unused_uv2_atlas_flow_rg(flow_foam_noise_result, uv2_sides, steps, crop_rect)
	var support_fallback_applied := bool(config.get("support_fallback_applied", false))
	var foam_support_reduced := false
	var pressure_support_reduced := false
	if bool(config.get("uses_downstream_baseline_generation", false)) and not support_fallback_applied:
		foam_support_reduced = _reduce_flat_occupied_foam_support(flow_foam_noise_result, crop_rect, uv2_sides, steps, config, warning_callback)
		pressure_support_reduced = _reduce_flat_occupied_pressure_support(dist_pressure_result, crop_rect, uv2_sides, steps, config, warning_callback)

	var edge_sync_depth := int(config.get("filtered_feature_edge_sync_depth_pixels", 1))
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(flow_foam_noise_result, uv2_sides, steps, crop_rect, edge_sync_depth)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(dist_pressure_result, uv2_sides, steps, crop_rect, edge_sync_depth)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(obstacle_features_result, uv2_sides, steps, crop_rect, edge_sync_depth)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(bank_response_features_result, uv2_sides, steps, crop_rect, edge_sync_depth)
	if water_occupancy_result_image != null:
		WaterHelperMethods.synchronize_uv2_logical_edge_bands(water_occupancy_result_image, uv2_sides, steps, crop_rect, edge_sync_depth)

	var grade_energy_stats := get_occupied_channel_stats(dist_pressure_result, crop_rect, 2, uv2_sides, steps)
	var bend_bias_stats := get_occupied_channel_stats(dist_pressure_result, crop_rect, 3, uv2_sides, steps)
	var obstacle_feature_stats := get_obstacle_feature_stats(obstacle_features_result, crop_rect, uv2_sides, steps)
	var terrain_contact_feature_stats := get_terrain_contact_feature_stats(terrain_contact_features_result, crop_rect, uv2_sides, steps)
	var bank_response_feature_stats := get_bank_response_feature_stats(bank_response_features_result, crop_rect, uv2_sides, steps)
	var source_texture_size := Vector2i(int(flowmap_resolution), int(flowmap_resolution))
	var padded_texture_size := Vector2i(flow_foam_noise_result.get_width(), flow_foam_noise_result.get_height())
	var sampled_flow_foam_noise_result: Image = flow_foam_noise_result.get_region(crop_rect)
	var sampled_dist_pressure_result: Image = dist_pressure_result.get_region(crop_rect)
	if not support_fallback_applied:
		_warn_if_bake_channels_flat(sampled_flow_foam_noise_result, "foam map B", [2], PackedStringArray(["B"]), config, warning_callback)
		_warn_if_bake_channels_flat(sampled_dist_pressure_result, "distance/pressure RG", [0, 1], PackedStringArray(["R", "G"]), config, warning_callback)

	var flow_vector_diagnostics := WaterHelperMethods.get_uv2_atlas_decoded_flow_vector_stats(
		flow_foam_noise_result,
		uv2_sides,
		steps,
		crop_rect,
		float(config.get("near_neutral_threshold", WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD))
	)
	_print_river_flow_vector_diagnostics(flow_vector_diagnostics, diagnostic_callback)
	_warn_if_bake_flow_vectors_near_neutral(flow_vector_diagnostics, warning_callback)

	# River shaders remap UV2 into the center of the margin-padded bake atlas.
	# Keep the shader-facing textures padded to match the original Waterways layout.
	var final_flow_foam_noise := ImageTexture.create_from_image(flow_foam_noise_result)
	var final_dist_pressure := ImageTexture.create_from_image(dist_pressure_result)
	var final_obstacle_features := ImageTexture.create_from_image(obstacle_features_result)
	var final_terrain_contact_features := ImageTexture.create_from_image(terrain_contact_features_result)
	var final_bank_response_features := ImageTexture.create_from_image(bank_response_features_result)
	var final_water_occupancy := ImageTexture.create_from_image(water_occupancy_result_image) if water_occupancy_result_image != null else null
	var bake_diagnostics := {
		"collision_probe_skipped": bool(config.get("collision_probe_skipped", false)),
		"collision_support_filters_ran": bool(config.get("collision_support_filters_ran", not support_fallback_applied)),
		"support_fallback_applied": support_fallback_applied,
		"support_fallback_reason": String(config.get("support_fallback_reason", "")),
		"obstacle_avoidance_applied": bool(config.get("obstacle_avoidance_applied", false)),
		"flow_projected": bool(config.get("flow_projected", false)),
		"water_occupancy_baked": final_water_occupancy != null,
		"collision_stats": (config.get("collision_stats", {}) as Dictionary).duplicate(true),
		"grade_energy_stats": grade_energy_stats.duplicate(true),
		"bend_bias_stats": bend_bias_stats.duplicate(true),
		"obstacle_feature_stats": obstacle_feature_stats.duplicate(true),
		"terrain_contact_feature_stats": terrain_contact_feature_stats.duplicate(true),
		"bank_response_feature_stats": bank_response_feature_stats.duplicate(true)
	}
	return {
		"ok": true,
		"flow_foam_noise_texture": final_flow_foam_noise,
		"dist_pressure_texture": final_dist_pressure,
		"obstacle_features_texture": final_obstacle_features,
		"terrain_contact_features_texture": final_terrain_contact_features,
		"bank_response_features_texture": final_bank_response_features,
		"water_occupancy_texture": final_water_occupancy,
		"source_texture_size": source_texture_size,
		"padded_texture_size": padded_texture_size,
		"content_rect": crop_rect,
		"generation_behavior": String(config.get("generation_behavior", "")),
		"flow_vector_diagnostics": flow_vector_diagnostics,
		"foam_support_reduced": foam_support_reduced,
		"pressure_support_reduced": pressure_support_reduced,
		"bake_diagnostics": bake_diagnostics
	}


func run_filter_pass_sequence(config: Dictionary, progress: Callable = Callable(), cancellation: Callable = Callable()) -> Dictionary:
	var renderer_setup: Dictionary = await bake(config, progress, cancellation)
	if not bool(renderer_setup.get("ok", false)):
		return renderer_setup
	var renderer_instance := renderer_setup.get("renderer") as Node
	if renderer_instance == null or not is_instance_valid(renderer_instance):
		_emit_warning("Waterways: River Flow & Foam bake failed because the filter renderer could not be instantiated.")
		return _abort_with_cleanup("renderer_instantiate_failed")

	var flowmap_resolution := float(config.get("flowmap_resolution", 0.0))
	var uv2_sides := maxi(1, int(config.get("uv2_sides", 1)))
	var steps := maxi(1, int(config.get("steps", 1)))
	var margin := int(config.get("margin", 0))
	var bake_atlas_columns := float(config.get("bake_atlas_columns", float(uv2_sides + 2)))
	var generation_behavior := String(config.get("generation_behavior", ""))
	var support_fallback_reason := String(config.get("support_fallback_reason", ""))
	var support_fallback_applied := not support_fallback_reason.is_empty()
	var run_collision_support_filters := not support_fallback_applied
	var uses_obstacle_avoidance := bool(config.get("uses_obstacle_avoidance_generation", false))

	var downstream_baseline_with_margins_texture := config.get("downstream_baseline_with_margins_texture") as Texture2D
	var blank_support_with_margins_texture := config.get("blank_support_with_margins_texture") as Texture2D
	var blank_obstacle_features_with_margins_texture := config.get("blank_obstacle_features_with_margins_texture") as Texture2D
	var blank_bank_response_features_with_margins_texture := config.get("blank_bank_response_features_with_margins_texture") as Texture2D
	var terrain_contact_source := config.get("terrain_contact_source") as Image
	var terrain_contact_with_margins_texture := config.get("terrain_contact_with_margins_texture") as Texture2D
	var grade_energy_with_margins_texture := config.get("grade_energy_with_margins_texture") as Texture2D
	var bend_bias_with_margins_texture := config.get("bend_bias_with_margins_texture") as Texture2D
	var flow_speed_with_margins_texture := config.get("flow_speed_with_margins_texture") as Texture2D
	var tiled_noise := config.get("tiled_noise") as Texture2D

	var flow_pressure_blur_amount := float(config.get("flow_pressure_blur_amount", 0.0))
	var dilate_amount := float(config.get("dilate_amount", 0.0))
	var flowmap_blur_amount := float(config.get("flowmap_blur_amount", 0.0))
	var foam_offset_amount := float(config.get("foam_offset_amount", 0.0))
	var foam_blur_amount := float(config.get("foam_blur_amount", 0.0))
	var foam_cutoff := float(config.get("foam_cutoff", 0.0))

	var obstacle_avoidance_applied := false
	var flow_projected_applied := false
	var primary_flow_map: Texture2D = null
	var blurred_foam_map: Texture2D = blank_support_with_margins_texture
	var blurred_flow_pressure_map: Texture2D = blank_support_with_margins_texture
	var dilated_texture: Texture2D = blank_support_with_margins_texture
	var obstacle_feature_mask: Texture2D = blank_obstacle_features_with_margins_texture
	var bank_response_feature_mask: Texture2D = blank_bank_response_features_with_margins_texture
	var water_occupancy_mask: Texture2D = null
	var bank_response_feature_mask_ready := false
	if downstream_baseline_with_margins_texture != null:
		var early_bank_response_uv_denominator := float(uv2_sides) + 2.0
		var early_bank_response_result: Dictionary = await _run_bank_response_feature_mask(
			renderer_instance,
			downstream_baseline_with_margins_texture,
			terrain_contact_with_margins_texture,
			grade_energy_with_margins_texture,
			bend_bias_with_margins_texture,
			early_bank_response_uv_denominator,
			bake_atlas_columns,
			config
		)
		if not bool(early_bank_response_result.get("ok", false)):
			return early_bank_response_result
		bank_response_feature_mask = early_bank_response_result.get("texture") as Texture2D
		bank_response_feature_mask_ready = true
	if run_collision_support_filters:
		var collision_with_margins: Texture2D = create_margin_texture(config.get("collision_source_image") as Image, flowmap_resolution, margin, steps)
		var flow_pressure_result: Dictionary = await _run_renderer_pass("flow pressure", renderer_instance, "apply_flow_pressure", [collision_with_margins, flowmap_resolution, float(uv2_sides) + 2.0])
		if not bool(flow_pressure_result.get("ok", false)):
			return flow_pressure_result
		var flow_pressure_map: Texture2D = flow_pressure_result.get("texture") as Texture2D
		var blurred_flow_pressure_result: Dictionary = await _run_renderer_pass("blurred flow pressure", renderer_instance, "apply_vertical_blur", [flow_pressure_map, flow_pressure_blur_amount, flowmap_resolution])
		if not bool(blurred_flow_pressure_result.get("ok", false)):
			return blurred_flow_pressure_result
		blurred_flow_pressure_map = blurred_flow_pressure_result.get("texture") as Texture2D
		var dilated_result: Dictionary = await _run_renderer_pass("dilated collision map", renderer_instance, "apply_dilate", [collision_with_margins, dilate_amount, 0.0, flowmap_resolution, null, bake_atlas_columns])
		if not bool(dilated_result.get("ok", false)):
			return dilated_result
		dilated_texture = dilated_result.get("texture") as Texture2D
		var normal_result: Dictionary = await _run_renderer_pass("normal map", renderer_instance, "apply_normal", [dilated_texture, flowmap_resolution, bake_atlas_columns])
		if not bool(normal_result.get("ok", false)):
			return normal_result
		var normal_map: Texture2D = normal_result.get("texture") as Texture2D
		var solid_occupancy_source := WaterHelperMethods.create_solid_occupancy_source_image(
			config.get("collision_source_image") as Image,
			terrain_contact_source,
			float(config.get("occupancy_protrusion_threshold", 0.9)),
			float(config.get("occupancy_protrusion_confidence_min", 0.75))
		)
		var solid_occupancy_with_margins_texture: Texture2D = create_margin_texture(solid_occupancy_source, flowmap_resolution, margin, steps)
		var occupancy_proximity_result: Dictionary = await _run_renderer_pass("occupancy proximity field", renderer_instance, "apply_proximity", [solid_occupancy_with_margins_texture, float(config.get("occupancy_ramp_tiles", 0.12)) / float(uv2_sides), flowmap_resolution, bake_atlas_columns])
		if not bool(occupancy_proximity_result.get("ok", false)):
			return occupancy_proximity_result
		var occupancy_proximity: Texture2D = occupancy_proximity_result.get("texture") as Texture2D
		var water_occupancy_result: Dictionary = await _run_renderer_pass("water occupancy mask", renderer_instance, "apply_occupancy_pack", [solid_occupancy_with_margins_texture, occupancy_proximity])
		if not bool(water_occupancy_result.get("ok", false)):
			return water_occupancy_result
		water_occupancy_mask = water_occupancy_result.get("texture") as Texture2D
		if uses_obstacle_avoidance and downstream_baseline_with_margins_texture != null:
			var feature_uv_denominator := float(uv2_sides) + 2.0
			var obstacle_feature_result: Dictionary = await _run_renderer_pass(
				"obstacle feature mask",
				renderer_instance,
				"apply_obstacle_feature_mask",
				[
					downstream_baseline_with_margins_texture,
					normal_map,
					dilated_texture,
					bank_response_feature_mask,
					float(config.get("obstacle_feature_support_start", 0.22)),
					float(config.get("obstacle_feature_support_full", 0.82)),
					float(config.get("obstacle_feature_facing_start", 0.35)),
					float(config.get("obstacle_feature_facing_full", 0.92)),
					float(config.get("obstacle_feature_wake_length_tiles", 0.70)) / feature_uv_denominator,
					float(config.get("obstacle_feature_wake_width_tiles", 0.11)) / feature_uv_denominator,
					float(config.get("obstacle_feature_side_width_tiles", 0.14)) / feature_uv_denominator,
					float(config.get("obstacle_feature_wake_start", 0.045)),
					float(config.get("obstacle_feature_wake_full", 0.20)),
					float(config.get("obstacle_feature_bank_friction_suppression", 0.70)),
					float(config.get("obstacle_feature_hard_boundary_wake_gate", 0.45)),
					float(config.get("obstacle_feature_confidence_start", 0.14)),
					float(config.get("obstacle_feature_confidence_full", 0.44)),
					terrain_contact_with_margins_texture,
					grade_energy_with_margins_texture,
					float(config.get("obstacle_feature_eddy_line_edge_start", 0.04)),
					float(config.get("obstacle_feature_eddy_line_edge_full", 0.22)),
					float(config.get("obstacle_feature_eddy_line_wake_start", 0.06)),
					float(config.get("obstacle_feature_eddy_line_wake_full", 0.28)),
					float(config.get("obstacle_feature_eddy_line_hard_gate_start", 0.06)),
					float(config.get("obstacle_feature_eddy_line_hard_gate_full", 0.40)),
					float(config.get("obstacle_feature_eddy_line_energy_gate_start", 0.03)),
					float(config.get("obstacle_feature_eddy_line_energy_gate_full", 0.35)),
					float(config.get("obstacle_feature_eddy_line_support_reject_start", 0.62)),
					float(config.get("obstacle_feature_eddy_line_support_reject_full", 0.92)),
					float(config.get("obstacle_feature_pillow_support_start", 0.40)),
					float(config.get("obstacle_feature_pillow_support_full", 0.88)),
					float(config.get("obstacle_feature_pillow_contact_search_tiles", 0.07)) / feature_uv_denominator,
					float(config.get("obstacle_feature_pillow_contact_gate_start", 0.08)),
					float(config.get("obstacle_feature_pillow_contact_gate_full", 0.38)),
					bake_atlas_columns
				]
			)
			if not bool(obstacle_feature_result.get("ok", false)):
				return obstacle_feature_result
			obstacle_feature_mask = obstacle_feature_result.get("texture") as Texture2D
			renderer_instance.set_hdr_2d(true)
			var divergence_result: Dictionary = await _run_renderer_pass("flow divergence map", renderer_instance, "apply_flow_divergence", [downstream_baseline_with_margins_texture, water_occupancy_mask, flowmap_resolution, bake_atlas_columns])
			if not bool(divergence_result.get("ok", false)):
				return divergence_result
			var divergence_map: Texture2D = divergence_result.get("texture") as Texture2D
			var pressure_size := Vector2i(downstream_baseline_with_margins_texture.get_size())
			var neutral_pressure_image := Image.create(pressure_size.x, pressure_size.y, false, Image.FORMAT_RGBAF)
			neutral_pressure_image.fill(config.get("flow_pressure_seed_color", Color(0.5, 0.0, 0.0, 1.0)) as Color)
			var pressure_map: Texture2D = ImageTexture.create_from_image(neutral_pressure_image)
			var flow_projection_strides := _config_array(config, "flow_projection_strides")
			var flow_projection_iterations_per_stride := int(config.get("flow_projection_iterations_per_stride", 5))
			var total_jacobi_passes := flow_projection_strides.size() * flow_projection_iterations_per_stride
			var jacobi_pass_index := 0
			for stride in flow_projection_strides:
				_emit_progress(progress, 0.95, "Projecting flow %d/%d (stride %d)" % [jacobi_pass_index, total_jacobi_passes, int(stride)])
				for iteration in flow_projection_iterations_per_stride:
					var jacobi_result: Dictionary = await _run_renderer_pass("flow pressure jacobi pass", renderer_instance, "apply_flow_pressure_jacobi", [pressure_map, divergence_map, water_occupancy_mask, float(stride), flowmap_resolution, bake_atlas_columns])
					if not bool(jacobi_result.get("ok", false)):
						return jacobi_result
					pressure_map = jacobi_result.get("texture") as Texture2D
					jacobi_pass_index += 1
			var projected_flow_result: Dictionary = await _run_renderer_pass("projected flow map", renderer_instance, "apply_flow_gradient_subtract", [downstream_baseline_with_margins_texture, pressure_map, water_occupancy_mask, flowmap_resolution, bake_atlas_columns])
			if not bool(projected_flow_result.get("ok", false)):
				return projected_flow_result
			var tangent_flow_map: Texture2D = projected_flow_result.get("texture") as Texture2D
			for tangency_pass in int(config.get("flow_tangency_passes", 2)):
				var tangent_result: Dictionary = await _run_renderer_pass("boundary tangency flow map", renderer_instance, "apply_flow_boundary_tangency", [tangent_flow_map, water_occupancy_mask, flowmap_resolution, bake_atlas_columns])
				if not bool(tangent_result.get("ok", false)):
					return tangent_result
				tangent_flow_map = tangent_result.get("texture") as Texture2D
			renderer_instance.set_hdr_2d(false)
			primary_flow_map = tangent_flow_map
			obstacle_avoidance_applied = true
			flow_projected_applied = true
		else:
			var flow_result: Dictionary = await _run_renderer_pass("flow map", renderer_instance, "apply_normal_to_flow", [normal_map])
			if not bool(flow_result.get("ok", false)):
				return flow_result
			var flow_map: Texture2D = flow_result.get("texture") as Texture2D
			var blurred_flow_result: Dictionary = await _run_renderer_pass("blurred flow map", renderer_instance, "apply_blur", [flow_map, flowmap_blur_amount, flowmap_resolution, bake_atlas_columns])
			if not bool(blurred_flow_result.get("ok", false)):
				return blurred_flow_result
			primary_flow_map = blurred_flow_result.get("texture") as Texture2D
		var foam_result: Dictionary = await _run_renderer_pass("foam map", renderer_instance, "apply_foam", [dilated_texture, foam_offset_amount, foam_cutoff])
		if not bool(foam_result.get("ok", false)):
			return foam_result
		var foam_map: Texture2D = foam_result.get("texture") as Texture2D
		var blurred_foam_result: Dictionary = await _run_renderer_pass("blurred foam map", renderer_instance, "apply_blur", [foam_map, foam_blur_amount, flowmap_resolution, bake_atlas_columns])
		if not bool(blurred_foam_result.get("ok", false)):
			return blurred_foam_result
		blurred_foam_map = blurred_foam_result.get("texture") as Texture2D
	if downstream_baseline_with_margins_texture != null and primary_flow_map == null:
		primary_flow_map = downstream_baseline_with_margins_texture
	if primary_flow_map == null:
		_emit_warning("Waterways: River Flow & Foam bake failed because no primary flow map was available for behavior " + generation_behavior + ".")
		return _abort_with_cleanup("primary_flow_map_missing")
	if support_fallback_applied:
		var support_fallback_notice: Callable = config.get("support_fallback_notice", Callable())
		if support_fallback_notice.is_valid():
			support_fallback_notice.call(generation_behavior, support_fallback_reason)
	if flow_speed_with_margins_texture != null:
		var speed_scaled_result: Dictionary = await _run_renderer_pass("flow speed scale map", renderer_instance, "apply_flow_speed_scale", [primary_flow_map, flow_speed_with_margins_texture, float(config.get("flow_speed_factor_max", 2.0))])
		if not bool(speed_scaled_result.get("ok", false)):
			return speed_scaled_result
		primary_flow_map = speed_scaled_result.get("texture") as Texture2D
	var bank_response_source_flow := downstream_baseline_with_margins_texture
	if bank_response_source_flow == null:
		bank_response_source_flow = primary_flow_map
	if not bank_response_feature_mask_ready and bank_response_source_flow != null:
		var bank_response_uv_denominator := float(uv2_sides) + 2.0
		var bank_response_result: Dictionary = await _run_bank_response_feature_mask(
			renderer_instance,
			bank_response_source_flow,
			terrain_contact_with_margins_texture,
			grade_energy_with_margins_texture,
			bend_bias_with_margins_texture,
			bank_response_uv_denominator,
			bake_atlas_columns,
			config
		)
		if not bool(bank_response_result.get("ok", false)):
			return bank_response_result
		bank_response_feature_mask = bank_response_result.get("texture") as Texture2D
	var flow_foam_noise_result: Dictionary = await _run_renderer_pass("combined flow/foam/noise map", renderer_instance, "apply_combine", [primary_flow_map, primary_flow_map, blurred_foam_map, tiled_noise])
	if not bool(flow_foam_noise_result.get("ok", false)):
		return flow_foam_noise_result
	var dist_pressure_result: Dictionary = await _run_renderer_pass("combined distance/pressure map", renderer_instance, "apply_combine", [dilated_texture, blurred_flow_pressure_map, grade_energy_with_margins_texture, bend_bias_with_margins_texture])
	if not bool(dist_pressure_result.get("ok", false)):
		return dist_pressure_result

	cleanup()
	return {
		"ok": true,
		"flow_foam_noise_texture": flow_foam_noise_result.get("texture") as Texture2D,
		"dist_pressure_texture": dist_pressure_result.get("texture") as Texture2D,
		"obstacle_feature_mask": obstacle_feature_mask,
		"bank_response_feature_mask": bank_response_feature_mask,
		"water_occupancy_mask": water_occupancy_mask,
		"support_fallback_applied": support_fallback_applied,
		"collision_support_filters_ran": run_collision_support_filters,
		"obstacle_avoidance_applied": obstacle_avoidance_applied,
		"flow_projected": flow_projected_applied
	}


func _abort_with_cleanup(reason: String) -> Dictionary:
	_aborted = true
	_last_abort_reason = reason
	cleanup()
	return _make_abort_result(reason)


func _make_abort_result(reason: String) -> Dictionary:
	return {
		"ok": false,
		"aborted": true,
		"reason": reason
	}


func _is_cancellation_requested(cancellation: Callable = Callable()) -> bool:
	if _aborted:
		return true
	var active_cancellation := cancellation
	if not active_cancellation.is_valid():
		active_cancellation = _cancellation_callback
	if active_cancellation.is_valid():
		return bool(active_cancellation.call())
	return false


func _run_pass(label: String, pass_callable: Callable) -> Dictionary:
	if not pass_callable.is_valid():
		return _abort_pass_with_cleanup(label, "pass callable is invalid")
	if _is_cancellation_requested():
		return _abort_with_cleanup("cancelled")
	var texture = await pass_callable.call()
	if _is_cancellation_requested():
		return _abort_with_cleanup("cancelled")
	return validate_pass_result(label, texture as Texture2D)


func _run_renderer_pass(label: String, renderer_instance: Object, method_name: String, args: Array) -> Dictionary:
	var pass_callable := Callable(renderer_instance, method_name)
	if not pass_callable.is_valid():
		return _abort_pass_with_cleanup(label, "pass callable is invalid")
	return await _run_pass(label, pass_callable.bindv(args))


func _run_bank_response_feature_mask(renderer_instance: Node, source_flow: Texture2D, terrain_contact_texture: Texture2D, grade_energy_texture: Texture2D, bend_bias_texture: Texture2D, uv_denominator: float, atlas_columns: float, config: Dictionary) -> Dictionary:
	var bank_response_feature_settings: Dictionary = config.get("bank_response_feature_settings", {})
	return await _run_renderer_pass(
		"bank response feature mask",
		renderer_instance,
		"apply_bank_response_feature_mask",
		[
			source_flow,
			terrain_contact_texture,
			grade_energy_texture,
			bend_bias_texture,
			float(bank_response_feature_settings.get("probe_tiles", config.get("bank_response_probe_tiles", 0.20))) / uv_denominator,
			float(bank_response_feature_settings.get("friction_contact_weight", config.get("bank_response_friction_contact_weight", 0.85))),
			float(bank_response_feature_settings.get("friction_shallow_weight", config.get("bank_response_friction_shallow_weight", 0.65))),
			float(bank_response_feature_settings.get("hard_protrusion_weight", config.get("bank_response_hard_protrusion_weight", 0.90))),
			float(bank_response_feature_settings.get("outside_bend_start", config.get("bank_response_outside_bend_start", 0.12))),
			float(bank_response_feature_settings.get("outside_bend_full", config.get("bank_response_outside_bend_full", 0.70))),
			float(bank_response_feature_settings.get("inside_bend_start", config.get("bank_response_inside_bend_start", 0.12))),
			float(bank_response_feature_settings.get("inside_bend_full", config.get("bank_response_inside_bend_full", 0.70))),
			atlas_columns
		]
	)


func _emit_progress(progress: Callable, percentage: float, label: String) -> void:
	if progress.is_valid():
		progress.call(percentage, label)


func _emit_warning(message: String, warning_callback: Callable = Callable()) -> void:
	if warning_callback.is_valid():
		warning_callback.call(message)
		return
	if _warning_callback.is_valid():
		_warning_callback.call(message)
		return
	push_warning(message)


func _emit_diagnostic(message: String, diagnostic_callback: Callable = Callable()) -> void:
	if diagnostic_callback.is_valid():
		diagnostic_callback.call(message)
		return
	print(message)


func _warn_if_bake_channels_flat(image: Image, label: String, channel_indices: Array, channel_names: PackedStringArray, config: Dictionary, warning_callback: Callable = Callable()) -> void:
	if image == null or image.is_empty() or channel_indices.is_empty():
		_emit_warning("Waterways: River bake produced no readable " + label + " image.", warning_callback)
		return
	var min_values := []
	var max_values := []
	var avg_values := []
	for channel_index in channel_indices.size():
		min_values.append(INF)
		max_values.append(-INF)
		avg_values.append(0.0)
	var total_pixels := max(1, image.get_width() * image.get_height())
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			for channel_index in channel_indices.size():
				var value := _get_color_channel(pixel, int(channel_indices[channel_index]))
				min_values[channel_index] = min(float(min_values[channel_index]), value)
				max_values[channel_index] = max(float(max_values[channel_index]), value)
				avg_values[channel_index] = float(avg_values[channel_index]) + value
	var channel_notes := PackedStringArray()
	var summaries := PackedStringArray()
	var flat_epsilon := float(config.get("bake_channel_flat_epsilon", 0.002))
	var low_contrast_epsilon := float(config.get("bake_channel_low_contrast_epsilon", 0.03))
	var saturation_epsilon := float(config.get("bake_channel_saturation_epsilon", 0.02))
	for channel_index in channel_indices.size():
		var channel_name := str(channel_indices[channel_index])
		if channel_index < channel_names.size():
			channel_name = channel_names[channel_index]
		var min_value := float(min_values[channel_index])
		var max_value := float(max_values[channel_index])
		var avg_value := float(avg_values[channel_index]) / float(total_pixels)
		var channel_range := max_value - min_value
		summaries.append("%s %.3f..%.3f avg %.3f" % [channel_name, min_value, max_value, avg_value])
		if channel_range <= flat_epsilon:
			channel_notes.append(channel_name + " flat")
		elif channel_range <= low_contrast_epsilon:
			channel_notes.append(channel_name + " low contrast")
		if min_value >= 1.0 - saturation_epsilon:
			channel_notes.append(channel_name + " near white")
		elif max_value <= saturation_epsilon:
			channel_notes.append(channel_name + " near black")
	if not channel_notes.is_empty():
		_emit_warning("Waterways: Generated " + label + " has limited debug contrast (" + ", ".join(summaries) + "; " + ", ".join(channel_notes) + "). Debug views may appear as a solid color until the bake input and filter settings produce varied data.", warning_callback)


func _get_color_channel(color: Color, channel_index: int) -> float:
	match channel_index:
		0:
			return color.r
		1:
			return color.g
		2:
			return color.b
		3:
			return color.a
		_:
			return 0.0


func _print_river_flow_vector_diagnostics(flow_vector_diagnostics: Dictionary, diagnostic_callback: Callable = Callable()) -> void:
	if flow_vector_diagnostics.is_empty():
		return
	var occupied_stats: Dictionary = flow_vector_diagnostics.get("occupied", {})
	var unused_stats: Dictionary = flow_vector_diagnostics.get("unused", {})
	_emit_diagnostic(
		"Waterways: River decoded flow-vector diagnostics: "
		+ WaterHelperMethods.format_decoded_flow_vector_stats("occupied_source_tiles", occupied_stats)
		+ "; "
		+ WaterHelperMethods.format_decoded_flow_vector_stats("unused_source_tiles", unused_stats)
		+ ".",
		diagnostic_callback
	)


func _warn_if_bake_flow_vectors_near_neutral(flow_vector_diagnostics: Dictionary, warning_callback: Callable = Callable()) -> void:
	if flow_vector_diagnostics.is_empty():
		return
	var occupied_stats: Dictionary = flow_vector_diagnostics.get("occupied", {})
	if typeof(occupied_stats) != TYPE_DICTIONARY or not bool(occupied_stats.get("valid", false)):
		return
	var near_neutral_percent := float(occupied_stats.get("near_neutral_percent", 0.0))
	var active_pixels := int(occupied_stats.get("active_pixel_count", 0))
	if active_pixels == 0 or near_neutral_percent >= 95.0:
		_emit_warning(
			"Waterways: Generated River occupied flow vectors are mostly near-neutral ("
			+ WaterHelperMethods.format_decoded_flow_vector_stats("occupied_source_tiles", occupied_stats)
			+ "). This usually means the collision-derived bake has no useful downstream interior direction.",
			warning_callback
		)


func _reduce_flat_occupied_foam_support(image: Image, content_rect: Rect2i, uv2_sides: int, steps: int, config: Dictionary, warning_callback: Callable = Callable()) -> bool:
	if not _soften_flat_occupied_support_channel(image, content_rect, 2, float(config.get("flat_foam_support_value", 0.25)), uv2_sides, steps):
		return false
	_emit_warning(
		"Waterways: River collision-derived foam support is saturated across occupied tiles, so the default downstream bake softened foam support to avoid full-width foam bands. "
		+ "Inspect the collision support bake if you need the raw support texture.",
		warning_callback
	)
	return true


func _reduce_flat_occupied_pressure_support(image: Image, content_rect: Rect2i, uv2_sides: int, steps: int, config: Dictionary, warning_callback: Callable = Callable()) -> bool:
	if not _soften_flat_occupied_support_channel(image, content_rect, 1, float(config.get("flat_pressure_support_value", 0.25)), uv2_sides, steps):
		return false
	_emit_warning(
		"Waterways: River collision-derived pressure support is saturated across occupied tiles, so the default downstream bake softened pressure support to keep generated flow-pattern strength usable. "
		+ "Inspect the collision support bake if you need the raw support texture.",
		warning_callback
	)
	return true


func _soften_flat_occupied_support_channel(image: Image, content_rect: Rect2i, channel_index: int, channel_value: float, uv2_sides: int, steps: int) -> bool:
	if image == null or image.is_empty():
		return false
	var stats := get_occupied_channel_stats(image, content_rect, channel_index, uv2_sides, steps)
	if stats.is_empty():
		return false
	var average := float(stats.get("average", 0.0))
	var saturated_percent := float(stats.get("saturated_percent", 0.0))
	if average < 0.95 or saturated_percent < 90.0:
		return false
	_set_occupied_channel_value(image, content_rect, channel_index, channel_value, uv2_sides, steps)
	return true


func get_occupied_channel_stats(image: Image, content_rect: Rect2i, channel_index: int, uv2_sides: int, steps: int) -> Dictionary:
	var source_rect := _clamp_rect_to_image(image, content_rect)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return {}
	var sum := 0.0
	var min_value := INF
	var max_value := -INF
	var saturated_pixels := 0
	var sampled_pixels := 0
	var above_005_pixels := 0
	var above_025_pixels := 0
	var above_050_pixels := 0
	var safe_uv2_sides := maxi(1, uv2_sides)
	var total_tiles := safe_uv2_sides * safe_uv2_sides
	var safe_steps := clampi(steps, 0, total_tiles)
	for step_index in safe_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, safe_uv2_sides, source_rect)
		for y in tile_rect.size.y:
			for x in tile_rect.size.x:
				var value := _get_color_channel(image.get_pixel(tile_rect.position.x + x, tile_rect.position.y + y), channel_index)
				sum += value
				min_value = min(min_value, value)
				max_value = max(max_value, value)
				if value >= 0.95:
					saturated_pixels += 1
				if value > 0.05:
					above_005_pixels += 1
				if value > 0.25:
					above_025_pixels += 1
				if value > 0.50:
					above_050_pixels += 1
				sampled_pixels += 1
	if sampled_pixels <= 0:
		return {}
	return {
		"sampled_pixel_count": sampled_pixels,
		"min": min_value,
		"max": max_value,
		"average": sum / float(sampled_pixels),
		"saturated_percent": 100.0 * float(saturated_pixels) / float(sampled_pixels),
		"above_0_05_percent": 100.0 * float(above_005_pixels) / float(sampled_pixels),
		"above_0_25_percent": 100.0 * float(above_025_pixels) / float(sampled_pixels),
		"above_0_50_percent": 100.0 * float(above_050_pixels) / float(sampled_pixels)
	}


func get_obstacle_feature_stats(image: Image, content_rect: Rect2i, uv2_sides: int, steps: int) -> Dictionary:
	return {
		"pillow_impact": get_occupied_channel_stats(image, content_rect, 0, uv2_sides, steps),
		"wake_eddy_seed": get_occupied_channel_stats(image, content_rect, 1, uv2_sides, steps),
		"eddy_line_shear": get_occupied_channel_stats(image, content_rect, 2, uv2_sides, steps),
		"side_deflection_confidence": get_occupied_channel_stats(image, content_rect, 3, uv2_sides, steps)
	}


func get_terrain_contact_feature_stats(image: Image, content_rect: Rect2i, uv2_sides: int, steps: int) -> Dictionary:
	return {
		"near_surface_contact": get_occupied_channel_stats(image, content_rect, 0, uv2_sides, steps),
		"shallow_depth": get_occupied_channel_stats(image, content_rect, 1, uv2_sides, steps),
		"protrusion_intersection": get_occupied_channel_stats(image, content_rect, 2, uv2_sides, steps),
		"source_provenance": get_occupied_channel_stats(image, content_rect, 3, uv2_sides, steps)
	}


func get_bank_response_feature_stats(image: Image, content_rect: Rect2i, uv2_sides: int, steps: int) -> Dictionary:
	return {
		"bank_friction_drag": get_occupied_channel_stats(image, content_rect, 0, uv2_sides, steps),
		"outside_bend_wet_pressure": get_occupied_channel_stats(image, content_rect, 1, uv2_sides, steps),
		"inside_bend_deposition": get_occupied_channel_stats(image, content_rect, 2, uv2_sides, steps),
		"hard_boundary_protrusion": get_occupied_channel_stats(image, content_rect, 3, uv2_sides, steps)
	}


func _set_occupied_channel_value(image: Image, content_rect: Rect2i, channel_index: int, channel_value: float, uv2_sides: int, steps: int) -> void:
	var source_rect := _clamp_rect_to_image(image, content_rect)
	var safe_uv2_sides := maxi(1, uv2_sides)
	var total_tiles := safe_uv2_sides * safe_uv2_sides
	var safe_steps := clampi(steps, 0, total_tiles)
	for step_index in safe_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, safe_uv2_sides, source_rect)
		for y in tile_rect.size.y:
			for x in tile_rect.size.x:
				var pixel_position := Vector2i(tile_rect.position.x + x, tile_rect.position.y + y)
				var color := image.get_pixelv(pixel_position)
				match channel_index:
					0:
						color.r = channel_value
					1:
						color.g = channel_value
					2:
						color.b = channel_value
					3:
						color.a = channel_value
				image.set_pixelv(pixel_position, color)


func _clamp_rect_to_image(image: Image, rect: Rect2i) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var image_size := image.get_size()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i(Vector2i.ZERO, image_size)
	var x0: int = clampi(rect.position.x, 0, image_size.x)
	var y0: int = clampi(rect.position.y, 0, image_size.y)
	var x1: int = clampi(rect.position.x + rect.size.x, x0, image_size.x)
	var y1: int = clampi(rect.position.y + rect.size.y, y0, image_size.y)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


func _abort_pass_with_cleanup(label: String, readback_error: String) -> Dictionary:
	var renderer_valid := _renderer_instance != null and is_instance_valid(_renderer_instance)
	var message := _make_pass_failure_message(label, readback_error)
	_emit_warning(message)
	_aborted = true
	_last_abort_reason = "filter_pass_failed"
	cleanup()
	var result := _make_abort_result("filter_pass_failed")
	result["label"] = label
	result["message"] = message
	result["readback_error"] = readback_error
	result["stage"] = "filter_pass"
	result["renderer_valid"] = renderer_valid
	return result


func _make_pass_failure_message(label: String, readback_error: String) -> String:
	var readback_detail := ""
	if not readback_error.is_empty():
		readback_detail = " Cause: " + readback_error + "."
	return "Waterways: River Flow & Foam bake failed while generating " + label + "." + readback_detail + " The bake was aborted and temporary renderer nodes were cleaned up."


func _get_renderer_readback_error() -> String:
	if _renderer_instance != null and is_instance_valid(_renderer_instance) and "last_readback_error" in _renderer_instance:
		return String(_renderer_instance.last_readback_error)
	return ""


func _create_blank_feature_source_image(resolution: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _create_uniform_support_source_image(resolution: int, value: float) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var clamped_value := clampf(value, 0.0, 1.0)
	image.fill(Color(clamped_value, clamped_value, clamped_value, 1.0))
	return image


func _calculate_curve_grade_energy_by_step(step_count: int, source_config: Dictionary) -> Array:
	var safe_step_count := maxi(1, step_count)
	var raw_grades := []
	raw_grades.resize(safe_step_count)
	for step_index in safe_step_count:
		raw_grades[step_index] = 0.0
	var curve := source_config.get("curve") as Curve3D
	if curve == null or curve.get_point_count() <= 0:
		return raw_grades
	var curve_length := curve.get_baked_length()
	if curve_length <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return raw_grades
	var lookahead_tiles := maxf(_config_float(source_config, "grade_energy_lookahead_tiles", 1.0), 0.1)
	for step_index in safe_step_count:
		var sample_step := float(step_index)
		var downstream_step := minf(float(safe_step_count), sample_step + lookahead_tiles)
		var sample_distance := (sample_step / float(safe_step_count)) * curve_length
		var downstream_distance := (downstream_step / float(safe_step_count)) * curve_length
		var sample_position := _sample_curve_baked_distance(curve, sample_distance, curve_length)
		var downstream_position := _sample_curve_baked_distance(curve, downstream_distance, curve_length)
		var run_distance := maxf(downstream_distance - sample_distance, WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
		var downhill_drop := sample_position.y - downstream_position.y
		raw_grades[step_index] = maxf(0.0, downhill_drop / run_distance)
	var smooth_radius := _config_int(source_config, "grade_energy_smooth_radius_tiles", 1)
	return _normalize_curve_grade_values(_smooth_curve_grade_values(raw_grades, smooth_radius), source_config)


func _calculate_curve_flow_speed_by_step(step_count: int, source_config: Dictionary) -> Array:
	var safe_step_count := maxi(1, step_count)
	var neutral_factor := _config_float(source_config, "neutral_flow_speed_factor", 1.0)
	var factors := []
	factors.resize(safe_step_count + 1)
	for step_index in safe_step_count + 1:
		factors[step_index] = neutral_factor
	var curve := source_config.get("curve") as Curve3D
	var flow_speeds := _config_array(source_config, "flow_speeds")
	if curve == null or curve.get_point_count() < 2 or flow_speeds.is_empty():
		return factors
	var curve_length := curve.get_baked_length()
	if curve_length <= 0.0:
		return factors
	var point_offsets := _get_curve_point_offsets(curve)
	for step_index in safe_step_count + 1:
		var distance := (float(step_index) / float(safe_step_count)) * curve_length
		factors[step_index] = _sample_flow_speed_at_offset(distance, point_offsets, flow_speeds, source_config)
	return factors


func _get_curve_point_offsets(curve: Curve3D) -> PackedFloat32Array:
	var offsets := PackedFloat32Array()
	var running := 0.0
	for point_index in curve.get_point_count():
		var offset := curve.get_closest_offset(curve.get_point_position(point_index))
		# Offsets must be monotonic; a near-self-intersecting curve can fool
		# get_closest_offset, so never step backwards.
		running = maxf(running, offset)
		offsets.append(running)
	return offsets


func _sample_flow_speed_at_offset(distance: float, point_offsets: PackedFloat32Array, flow_speeds: Array, source_config: Dictionary) -> float:
	if point_offsets.size() < 2:
		return _get_flow_speed_for_point(0, flow_speeds, source_config)
	for segment_index in point_offsets.size() - 1:
		var segment_start := point_offsets[segment_index]
		var segment_end := point_offsets[segment_index + 1]
		if distance <= segment_end or segment_index == point_offsets.size() - 2:
			var t := 0.0
			if segment_end > segment_start:
				t = clampf((distance - segment_start) / (segment_end - segment_start), 0.0, 1.0)
			# Smoothstep easing matches the width interpolation convention.
			return lerpf(_get_flow_speed_for_point(segment_index, flow_speeds, source_config), _get_flow_speed_for_point(segment_index + 1, flow_speeds, source_config), smoothstep(0.0, 1.0, t))
	return _get_flow_speed_for_point(point_offsets.size() - 1, flow_speeds, source_config)


func _calculate_curve_bend_bias_by_step(step_count: int, source_config: Dictionary) -> Array:
	var safe_step_count := maxi(1, step_count)
	var raw_bends := []
	raw_bends.resize(safe_step_count)
	for step_index in safe_step_count:
		raw_bends[step_index] = 0.0
	var curve := source_config.get("curve") as Curve3D
	if curve == null or curve.get_point_count() <= 0:
		return raw_bends
	var curve_length := curve.get_baked_length()
	if curve_length <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return raw_bends
	var lookahead_tiles := maxf(_config_float(source_config, "bend_bias_lookahead_tiles", 1.0), 0.1)
	var reference_angle := maxf(_config_float(source_config, "bend_bias_reference_radians", 0.45), WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
	for step_index in safe_step_count:
		var sample_step := float(step_index) + 0.5
		var upstream_step := maxf(0.0, sample_step - lookahead_tiles)
		var downstream_step := minf(float(safe_step_count), sample_step + lookahead_tiles)
		if downstream_step - upstream_step <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
			continue
		var sample_distance := (sample_step / float(safe_step_count)) * curve_length
		var upstream_distance := (upstream_step / float(safe_step_count)) * curve_length
		var downstream_distance := (downstream_step / float(safe_step_count)) * curve_length
		var sample_position := _sample_curve_baked_distance(curve, sample_distance, curve_length)
		var upstream_position := _sample_curve_baked_distance(curve, upstream_distance, curve_length)
		var downstream_position := _sample_curve_baked_distance(curve, downstream_distance, curve_length)
		var upstream_direction := _planar_direction_xz(sample_position - upstream_position)
		var downstream_direction := _planar_direction_xz(downstream_position - sample_position)
		if upstream_direction == Vector2.ZERO or downstream_direction == Vector2.ZERO:
			continue
		var center_direction := upstream_direction + downstream_direction
		if center_direction.length_squared() <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
			center_direction = downstream_direction
		else:
			center_direction = center_direction.normalized()
		var river_right := Vector2(-center_direction.y, center_direction.x)
		var curvature_direction := downstream_direction - upstream_direction
		var curvature_dot_right := curvature_direction.dot(river_right)
		if absf(curvature_dot_right) <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
			continue
		var turn_cross := upstream_direction.x * downstream_direction.y - upstream_direction.y * downstream_direction.x
		var turn_dot := clampf(upstream_direction.dot(downstream_direction), -1.0, 1.0)
		var turn_angle := atan2(absf(turn_cross), turn_dot)
		var bend_strength := clampf(turn_angle / reference_angle, 0.0, 1.0)
		var outside_side := -1.0 if curvature_dot_right > 0.0 else 1.0
		raw_bends[step_index] = outside_side * bend_strength
	var smooth_radius := _config_int(source_config, "bend_bias_smooth_radius_tiles", 1)
	return _smooth_curve_bend_bias_values(raw_bends, smooth_radius)


func _tile_axis_vertex_aligned_ratio(pixel_index: int, axis_size: int) -> float:
	if axis_size <= 1:
		return 0.5
	return clampf(float(pixel_index) / float(axis_size - 1), 0.0, 1.0)


func _sample_step_value_linear(values: Array, step_progress: float, fallback: float) -> float:
	if values.is_empty():
		return fallback
	if values.size() == 1:
		return float(values[0])
	if step_progress <= 0.0:
		return float(values[0])
	var last_index := values.size() - 1
	if step_progress >= float(last_index):
		return float(values[last_index])
	var left_index := clampi(int(floor(step_progress)), 0, last_index - 1)
	var right_index := left_index + 1
	var t := clampf(step_progress - float(left_index), 0.0, 1.0)
	return lerpf(float(values[left_index]), float(values[right_index]), t)


func _planar_direction_xz(value: Vector3) -> Vector2:
	var planar := Vector2(value.x, value.z)
	if planar.length_squared() <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return Vector2.ZERO
	return planar.normalized()


func _sample_curve_baked_distance(curve: Curve3D, distance: float, curve_length: float) -> Vector3:
	if curve == null or curve.get_point_count() <= 0:
		return Vector3.ZERO
	if curve_length <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return curve.get_point_position(0)
	return curve.sample_baked(clampf(distance, 0.0, curve_length), false)


func _smooth_curve_grade_values(values: Array, radius: int) -> Array:
	return _smooth_curve_scalar_values(values, radius, false, 0.0, 0.0)


func _smooth_curve_bend_bias_values(values: Array, radius: int) -> Array:
	return _smooth_curve_scalar_values(values, radius, true, -1.0, 1.0)


func _smooth_curve_scalar_values(values: Array, radius: int, clamp_result: bool, min_value: float, max_value: float) -> Array:
	var smoothed := []
	smoothed.resize(values.size())
	if values.is_empty():
		return smoothed
	var safe_radius := maxi(0, radius)
	for value_index in values.size():
		var start_index := maxi(0, value_index - safe_radius)
		var end_index := mini(values.size() - 1, value_index + safe_radius)
		var sum := 0.0
		var count := 0
		for sample_index in range(start_index, end_index + 1):
			sum += float(values[sample_index])
			count += 1
		var average := sum / float(maxi(1, count))
		smoothed[value_index] = clampf(average, min_value, max_value) if clamp_result else average
	return smoothed


func _normalize_curve_grade_values(grades: Array, source_config: Dictionary) -> Array:
	var energy_values := []
	energy_values.resize(grades.size())
	var reference_grade := maxf(_config_float(source_config, "grade_energy_reference_grade", 0.25), WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
	for grade_index in grades.size():
		energy_values[grade_index] = clampf(float(grades[grade_index]) / reference_grade, 0.0, 1.0)
	return energy_values


func _get_flow_speed_for_point(point_index: int, flow_speeds: Array, source_config: Dictionary) -> float:
	if flow_speeds.is_empty():
		return _config_float(source_config, "neutral_flow_speed_factor", 1.0)
	var value_index: int = clamp(point_index, 0, flow_speeds.size() - 1)
	return _sanitize_flow_speed_value(flow_speeds[value_index], source_config)


func _sanitize_flow_speed_value(value: Variant, source_config: Dictionary) -> float:
	var numeric_value := float(value)
	var neutral_factor := _config_float(source_config, "neutral_flow_speed_factor", 1.0)
	if not _is_finite_number(numeric_value):
		return neutral_factor
	var min_factor := _config_float(source_config, "flow_speed_factor_min", 0.0)
	var max_factor := _config_float(source_config, "flow_speed_factor_max", 2.0)
	if numeric_value < min_factor or numeric_value > max_factor:
		return neutral_factor
	return numeric_value


func _config_float(source_config: Dictionary, key: String, fallback: float) -> float:
	return float(source_config.get(key, fallback))


func _config_int(source_config: Dictionary, key: String, fallback: int) -> int:
	return int(source_config.get(key, fallback))


func _config_array(source_config: Dictionary, key: String) -> Array:
	var value = source_config.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
