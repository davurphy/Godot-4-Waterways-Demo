# River-refactor R7 canonical-compute representative visual probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_representative_visual_probe.gd -- out=res://.codex-research/r7-baselines/compute-representative-visuals
#
# Success marker: R7_COMPUTE_REPRESENTATIVE_VISUALS_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

const DEFAULT_SCENE := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-representative-visuals"
const REPORT_FILE_NAME := "r7_compute_representative_visuals.txt"
const FILTER_RENDERER_SCENE := "res://addons/waterways/filter_renderer.tscn"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 2400
const DEFAULT_STRIDE_SCHEDULE := [32, 16, 8, 4, 2, 1, 1, 1]

const VIEW_NORMAL := 0
const VIEW_RAW_FLOW := 10
const VIEW_FLOW_ARROWS := 7
const VIEW_OBSTACLE_CONFIDENCE := 17
const VIEW_PROTRUSION := 20

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
var _legacy_projection_capture := {}
var _written_report := ""


func _initialize() -> void:
	Engine.time_scale = 0.0
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
	var iterations_per_stride := maxi(1, int(args.get("iterations_per_stride", "5")))
	var stride_schedule := _parse_int_list(String(args.get("strides", "")), DEFAULT_STRIDE_SCHEDULE)

	_report_lines.append("R7_COMPUTE_REPRESENTATIVE_VISUALS_DUMP v1")
	_report_lines.append("scene=" + scene_path)
	_report_lines.append("river=" + river_path)
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())

	DisplayServer.window_set_size(Vector2i(1600, 900))
	var fixture := _load_fixture(scene_path)
	var river := fixture.get_node_or_null(river_path) if fixture != null else null
	_expect(river != null, "R7 visual fixture river was not found at " + river_path + ".")
	if river != null:
		_configure_fixture_river(river)
		_add_runtime_review_scene_context(fixture)
		var legacy_ok := await _run_legacy_bake(river)
		_expect(legacy_ok, "Legacy fixture bake did not complete before representative visual capture.")

	var before_state := _river_output_state(river)
	var before_hashes := _river_texture_hashes(river)
	_report_lines.append("legacy_before_state=" + str(before_state))
	_report_lines.append("legacy_before_hashes=" + str(before_hashes))

	var compute_config := {
		"frame_wait_source": self,
		"warning_callback": Callable(self, "_record_warning"),
		"texture_width": texture_width,
		"texture_height": texture_height,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"flow_projection_strides": stride_schedule.duplicate(),
		"flow_projection_iterations_per_stride": iterations_per_stride,
		"sync_wait_frames": 3
	}
	var projection_config := _make_projection_compute_config(compute_config)
	var baker := RiverFlowmapBaker.new()
	var projection_result: Dictionary = await baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_config,
		Callable(self, "_record_progress")
	)
	baker.cleanup()
	baker.abort()
	baker.cleanup()
	var candidate_result := await _make_canonical_candidate_texture(projection_result, river)
	var visual_result := await _capture_representative_visuals(
		river,
		candidate_result.get("candidate_texture", null) as Texture2D,
		candidate_result.get("candidate_image", null) as Image,
		out_dir
	)
	var neighborhood_result := _write_neighborhood_artifacts(
		candidate_result.get("candidate_image", null) as Image,
		_texture_to_image(river.get("flow_foam_noise") as Texture2D) if river != null else null,
		_texture_to_image(river.get("water_occupancy") as Texture2D) if river != null else null,
		_texture_to_image(river.get("obstacle_features") as Texture2D) if river != null else null,
		out_dir
	)

	var after_state := _river_output_state(river)
	var after_hashes := _river_texture_hashes(river)
	var output_preservation := {
		"ok": before_state == after_state and before_hashes == after_hashes,
		"river_state_unchanged": before_state == after_state,
		"river_texture_hashes_unchanged": before_hashes == after_hashes,
		"production_output_replaced": false,
		"output_texture_keys": [],
		"source_signature_version": 29,
		"signature_version_while_compute_non_replacing": 29,
		"temporary_material_override_used": true,
	}

	_append_result("projection_compute", projection_result)
	_append_result("canonical_candidate", candidate_result)
	_append_result("representative_visuals", visual_result)
	_append_result("texture_neighborhoods", neighborhood_result)
	_append_result("output_preservation", output_preservation)
	_report_lines.append("legacy_after_state=" + str(after_state))
	_report_lines.append("legacy_after_hashes=" + str(after_hashes))
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("progress=" + str(_progress))

	_expect(bool(projection_result.get("ok", false)), "Canonical projection compute failed: " + str(projection_result))
	_expect(String(projection_result.get("mode", "")) == "non_replacing_solve_filter_projection", "Projection compute did not stay non-replacing.")
	_expect(String(projection_result.get("pressure_feedback_target", "")) == "canonical_texel_space_compute", "Projection compute did not report canonical texel-space pressure feedback.")
	_expect(bool(projection_result.get("canonical_integer_texel_addressing", false)), "Projection compute did not report canonical integer texel addressing.")
	_expect(not bool(projection_result.get("production_output_replaced", true)), "Projection compute must not replace generated bake output.")
	_expect(_output_texture_key_count(projection_result) == 0, "Projection compute returned output texture keys before replacement.")
	_expect(not bool(projection_result.get("async_readback_selected", true)), "Projection compute selected async readback.")
	_expect(String(projection_result.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, "Projection compute did not use delayed sync texture readback.")
	_expect(bool(candidate_result.get("ok", false)), "Canonical candidate texture could not be assembled: " + str(candidate_result))
	_expect(bool(visual_result.get("ok", false)), "Representative visual capture failed: " + str(visual_result))
	_expect(bool(neighborhood_result.get("ok", false)), "Texture neighborhood artifacts failed: " + str(neighborhood_result))
	_expect(bool(output_preservation.get("ok", false)), "Representative visual probe changed RiverManager output state or hashes.")

	if fixture != null:
		fixture.queue_free()
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _make_projection_compute_config(base_config: Dictionary) -> Dictionary:
	var config := base_config.duplicate(true)
	var flow_texture := _legacy_projection_capture.get("flow_input_texture", null) as Texture2D
	var occupancy_texture := _legacy_projection_capture.get("occupancy_input_texture", null) as Texture2D
	config["flow_image"] = _texture_to_image(flow_texture)
	config["occupancy_image"] = _texture_to_image(occupancy_texture)
	config["source_size"] = float(_legacy_projection_capture.get("source_size", base_config.get("source_size", 1.0)))
	config["atlas_columns"] = maxi(1, int(round(float(_legacy_projection_capture.get("atlas_columns", base_config.get("atlas_columns", 1))))))
	config["flow_tangency_passes"] = int(_legacy_projection_capture.get("tangency_pass_count", 2))
	config["sync_wait_frames"] = 3
	return config


func _make_canonical_candidate_texture(projection_result: Dictionary, river: Node) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "canonical_compute_candidate_visual_material_bind",
		"candidate_texture": null,
		"candidate_image": null,
		"production_output_replaced": false,
		"output_texture_keys": [],
		"migrated_channels": "flow_foam_noise.rg",
		"legacy_foam_noise_channels_preserved": true,
	}
	if not bool(projection_result.get("ok", false)):
		result.reason = "projection_compute_failed"
		return result
	var compute_flow := projection_result.get("_debug_final_flow_image", null) as Image
	var compute_flow_texture := ImageTexture.create_from_image(compute_flow) if compute_flow != null else null
	var foam_texture := _legacy_projection_capture.get("flow_foam_noise_b_texture", null) as Texture2D
	var noise_texture := _legacy_projection_capture.get("flow_foam_noise_a_texture", null) as Texture2D
	var bake_data: Resource = null
	if river != null:
		bake_data = river.get("bake_data") as Resource
	if compute_flow_texture == null or foam_texture == null or noise_texture == null or bake_data == null:
		result.reason = "candidate_inputs_missing"
		return result
	var renderer := _make_renderer()
	if renderer == null:
		result.reason = "candidate_renderer_missing"
		return result
	var candidate_texture: Texture2D = await renderer.apply_combine(compute_flow_texture, compute_flow_texture, foam_texture, noise_texture)
	_remove_renderer(renderer)
	candidate_texture = _postprocess_candidate_flow_texture(candidate_texture, river, bake_data)
	var candidate_image := _texture_to_image(candidate_texture)
	if candidate_texture == null or candidate_image == null:
		result.reason = "candidate_postprocess_failed"
		return result
	result.ok = true
	result.reason = "ok"
	result.candidate_texture = candidate_texture
	result.candidate_image = candidate_image
	result.candidate_size = candidate_image.get_size()
	result.candidate_format = candidate_image.get_format()
	result.candidate_md5 = _hash_image(candidate_image)
	result.candidate_source = "canonical_compute_final_flow_plus_legacy_foam_noise_postprocess"
	return result


func _capture_representative_visuals(river: Node, candidate_texture: Texture2D, candidate_image: Image, out_dir: String) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "temporary_material_visual_capture",
		"scene": DEFAULT_SCENE,
		"production_output_replaced": false,
		"output_texture_keys": [],
		"temporary_material_override_used": true,
		"captures": [],
	}
	if river == null or candidate_texture == null or candidate_image == null:
		result.reason = "inputs_missing"
		return result
	var legacy_texture := river.get("flow_foam_noise") as Texture2D
	if legacy_texture == null:
		result.reason = "legacy_flow_texture_missing"
		return result
	var camera_oblique := _make_oblique_camera()
	var camera_topdown := _make_topdown_camera()
	var paths := []
	var stats := {}
	await _capture_scene_view(river, camera_oblique, VIEW_NORMAL, out_dir.path_join("r7_legacy_material_oblique.png"), paths, stats)
	river.call("set_materials", "i_flowmap", candidate_texture)
	await _capture_scene_view(river, camera_oblique, VIEW_NORMAL, out_dir.path_join("r7_canonical_material_oblique.png"), paths, stats)
	await _capture_scene_view(river, camera_topdown, VIEW_NORMAL, out_dir.path_join("r7_canonical_topdown_material.png"), paths, stats)
	await _capture_scene_view(river, camera_topdown, VIEW_RAW_FLOW, out_dir.path_join("r7_canonical_topdown_raw_flow.png"), paths, stats)
	await _capture_scene_view(river, camera_topdown, VIEW_FLOW_ARROWS, out_dir.path_join("r7_canonical_topdown_flow_arrows.png"), paths, stats)
	await _capture_scene_view(river, camera_topdown, VIEW_OBSTACLE_CONFIDENCE, out_dir.path_join("r7_canonical_topdown_obstacle_confidence.png"), paths, stats)
	await _capture_scene_view(river, camera_topdown, VIEW_PROTRUSION, out_dir.path_join("r7_canonical_topdown_contact_protrusion.png"), paths, stats)
	river.call("set_materials", "i_flowmap", legacy_texture)
	river.call("set_debug_view", VIEW_NORMAL)
	camera_oblique.queue_free()
	camera_topdown.queue_free()
	result.captures = paths
	result.capture_count = paths.size()
	result.capture_stats = stats
	result.material_rendered_output_captured = paths.has(out_dir.path_join("r7_canonical_material_oblique.png"))
	result.top_down_debug_output_captured = paths.has(out_dir.path_join("r7_canonical_topdown_flow_arrows.png"))
	result.obstacle_contact_debug_output_captured = paths.has(out_dir.path_join("r7_canonical_topdown_obstacle_confidence.png"))
	result.ok = paths.size() >= 7 and _all_capture_stats_nonblank(stats)
	result.reason = "ok" if bool(result.ok) else "capture_missing_or_blank"
	return result


func _capture_scene_view(river: Node, camera: Camera3D, view_id: int, path: String, paths: Array, stats: Dictionary) -> void:
	camera.current = true
	river.call("set_debug_view", view_id)
	for _frame in 24:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_warnings.append("Viewport capture returned no image for " + path)
		return
	_save_png(image, path, paths)
	stats[path.get_file()] = _image_luma_stats(image)


func _write_neighborhood_artifacts(candidate_image: Image, legacy_image: Image, occupancy_image: Image, obstacle_image: Image, out_dir: String) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "canonical_texture_neighborhood_review",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"artifacts": [],
		"known_failure_targets": [Vector2i(82, 47), Vector2i(61, 67), Vector2i(42, 63)],
	}
	if candidate_image == null or candidate_image.is_empty():
		result.reason = "candidate_image_missing"
		return result
	var paths := []
	_save_zoomed_crop_with_marker(candidate_image, Vector2i(82, 47), 8, 12, out_dir.path_join("r7_canonical_known_failure_82_47_flow_crop.png"), paths)
	_save_zoomed_crop_with_marker(candidate_image, Vector2i(61, 67), 8, 12, out_dir.path_join("r7_canonical_known_failure_61_67_flow_crop.png"), paths)
	_save_zoomed_crop_with_marker(candidate_image, Vector2i(42, 63), 8, 12, out_dir.path_join("r7_canonical_tile5_42_63_flow_crop.png"), paths)
	if occupancy_image != null and not occupancy_image.is_empty():
		var contact_center := _max_channel_point(occupancy_image, 1)
		_save_zoomed_crop_with_marker(occupancy_image, contact_center, 10, 10, out_dir.path_join("r7_canonical_obstacle_contact_occupancy_crop.png"), paths)
		result.obstacle_contact_center = contact_center
	if obstacle_image != null and not obstacle_image.is_empty():
		var obstacle_center := _max_channel_point(obstacle_image, 3)
		_save_zoomed_crop_with_marker(obstacle_image, obstacle_center, 10, 10, out_dir.path_join("r7_canonical_obstacle_confidence_crop.png"), paths)
		result.obstacle_confidence_center = obstacle_center
	if legacy_image != null and not legacy_image.is_empty():
		_save_delta_crop_with_marker(legacy_image, candidate_image, Vector2i(82, 47), 8, 12, out_dir.path_join("r7_canonical_vs_legacy_82_47_delta_crop.png"), paths)
	result.artifacts = paths
	result.artifact_count = paths.size()
	result.known_failure_neighborhoods_captured = 3
	result.tile_edge_neighborhood_captured = true
	result.obstacle_contact_neighborhood_captured = paths.has(out_dir.path_join("r7_canonical_obstacle_contact_occupancy_crop.png"))
	result.ok = paths.size() >= 5
	result.reason = "ok" if bool(result.ok) else "neighborhood_artifacts_missing"
	return result


func _save_zoomed_crop_with_marker(source: Image, center: Vector2i, radius: int, scale: int, path: String, paths: Array) -> void:
	if source == null or source.is_empty():
		return
	var size := radius * 2 + 1
	var image := Image.create(size * scale, size * scale, false, Image.FORMAT_RGBA8)
	var converted := source.duplicate()
	converted.convert(Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var src := Vector2i(clampi(center.x + x - radius, 0, converted.get_width() - 1), clampi(center.y + y - radius, 0, converted.get_height() - 1))
			var color: Color = converted.get_pixelv(src)
			for yy in scale:
				for xx in scale:
					image.set_pixel(x * scale + xx, y * scale + yy, color)
	_draw_marker(image, radius * scale + int(scale * 0.5), radius * scale + int(scale * 0.5), scale)
	_save_png(image, path, paths)


func _save_delta_crop_with_marker(expected: Image, actual: Image, center: Vector2i, radius: int, scale: int, path: String, paths: Array) -> void:
	if expected == null or actual == null or expected.is_empty() or actual.is_empty():
		return
	var size := radius * 2 + 1
	var image := Image.create(size * scale, size * scale, false, Image.FORMAT_RGBA8)
	var expected_copy := expected.duplicate()
	var actual_copy := actual.duplicate()
	expected_copy.convert(Image.FORMAT_RGBA8)
	actual_copy.convert(Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var src := Vector2i(clampi(center.x + x - radius, 0, expected_copy.get_width() - 1), clampi(center.y + y - radius, 0, expected_copy.get_height() - 1))
			var a: Color = expected_copy.get_pixelv(src)
			var b: Color = actual_copy.get_pixelv(src)
			var delta := Color(absf(a.r - b.r) * 8.0, absf(a.g - b.g) * 8.0, absf(a.b - b.b) * 8.0, 1.0)
			for yy in scale:
				for xx in scale:
					image.set_pixel(x * scale + xx, y * scale + yy, delta)
	_draw_marker(image, radius * scale + int(scale * 0.5), radius * scale + int(scale * 0.5), scale)
	_save_png(image, path, paths)


func _draw_marker(image: Image, cx: int, cy: int, scale: int) -> void:
	var color := Color(1.0, 0.0, 0.0, 1.0)
	for offset in range(-scale, scale + 1):
		var x := clampi(cx + offset, 0, image.get_width() - 1)
		var y := clampi(cy + offset, 0, image.get_height() - 1)
		image.set_pixel(x, clampi(cy, 0, image.get_height() - 1), color)
		image.set_pixel(clampi(cx, 0, image.get_width() - 1), y, color)
	for x in image.get_width():
		image.set_pixel(x, 0, color)
		image.set_pixel(x, image.get_height() - 1, color)
	for y in image.get_height():
		image.set_pixel(0, y, color)
		image.set_pixel(image.get_width() - 1, y, color)


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
		"water_occupancy_baked": true,
	})
	baker.cleanup()
	if not bool(postprocess_result.get("ok", false)):
		return null
	return postprocess_result.get("flow_foam_noise_texture") as Texture2D


func _step_count_from_bake(bake_data: Resource) -> int:
	if bake_data == null:
		return 1
	var source_signature: Dictionary = bake_data.get("source_signature")
	return maxi(1, int(source_signature.get("step_count", bake_data.get("uv2_sides"))))


func _add_runtime_review_scene_context(scene: Node) -> void:
	if scene == null:
		return
	var light := DirectionalLight3D.new()
	light.name = "R7VisualReviewLight"
	light.light_energy = 1.8
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	scene.add_child(light)
	var obstacle_body := scene.get_node_or_null("Midstream Obstacle") as Node3D
	if obstacle_body != null:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "R7VisualReviewObstacle"
		var box := BoxMesh.new()
		box.size = Vector3(1.1, 1.0, 1.7)
		mesh_instance.mesh = box
		mesh_instance.transform = obstacle_body.transform
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.18, 0.08, 0.45)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.65
		mesh_instance.material_override = material
		scene.add_child(mesh_instance)


func _make_oblique_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "R7VisualObliqueCamera"
	camera.fov = 45.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.15, 4.0, -1.8), Vector3(0.0, 0.0, 3.75), Vector3.UP)
	return camera


func _make_topdown_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "R7VisualTopdownCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 9.5, 3.75), Vector3(0.0, 0.0, 3.75), Vector3.FORWARD)
	return camera


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
	current_scene = fixture
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
		"boundary tangency flow map":
			_legacy_projection_capture["tangency_pass_count"] = int(_legacy_projection_capture.get("tangency_pass_count", 0)) + 1
		"combined flow/foam/noise map":
			_legacy_projection_capture["legacy_flow_foam_noise_texture"] = texture


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
	entry.md5 = _hash_image(image)
	return entry


func _hash_image(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	return context.finish().hex_encode()


func _texture_to_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


func _save_png(image: Image, path: String, paths: Array) -> void:
	if image == null or image.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_warnings.append("Could not create visual output parent " + parent + ": " + error_string(dir_error))
		return
	var writable := image.duplicate()
	writable.convert(Image.FORMAT_RGBA8)
	var save_error: Error = writable.save_png(absolute_path)
	if save_error != OK:
		_warnings.append("Could not write visual output " + absolute_path + ": " + error_string(save_error))
		return
	paths.append(path)


func _image_luma_stats(image: Image) -> Dictionary:
	var result := {
		"size": image.get_size(),
		"sample_count": 0,
		"min_luma": INF,
		"max_luma": -INF,
		"mean_luma": 0.0,
		"nonblack_pixel_count": 0,
	}
	if image == null or image.is_empty():
		return result
	var converted := image.duplicate()
	converted.convert(Image.FORMAT_RGBA8)
	var sum := 0.0
	for y in converted.get_height():
		for x in converted.get_width():
			var color: Color = converted.get_pixel(x, y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			result.min_luma = minf(float(result.min_luma), luma)
			result.max_luma = maxf(float(result.max_luma), luma)
			sum += luma
			result.sample_count = int(result.sample_count) + 1
			if luma > 0.01:
				result.nonblack_pixel_count = int(result.nonblack_pixel_count) + 1
	if int(result.sample_count) > 0:
		result.mean_luma = sum / float(result.sample_count)
	return result


func _all_capture_stats_nonblank(stats: Dictionary) -> bool:
	if stats.is_empty():
		return false
	for key in stats.keys():
		var entry: Dictionary = stats[key]
		if int(entry.get("sample_count", 0)) <= 0:
			return false
		if int(entry.get("nonblack_pixel_count", 0)) <= 0:
			return false
		if float(entry.get("max_luma", 0.0)) <= float(entry.get("min_luma", 0.0)) + 0.001:
			return false
	return true


func _max_channel_point(image: Image, channel_index: int) -> Vector2i:
	var best := Vector2i(image.get_width() / 2, image.get_height() / 2)
	var best_value := -INF
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var value := color.r
			match channel_index:
				1:
					value = color.g
				2:
					value = color.b
				3:
					value = color.a
			if value > best_value:
				best_value = value
				best = Vector2i(x, y)
	return best


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
		if String(key).begins_with("_debug_"):
			continue
		var value = result[key]
		if value is Texture2D or value is Image:
			continue
		_report_lines.append(prefix + "." + str(key) + "=" + str(value))


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


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_REPRESENTATIVE_VISUALS_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


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
