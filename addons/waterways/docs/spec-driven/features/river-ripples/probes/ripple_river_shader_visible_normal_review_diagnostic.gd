extends SceneTree

const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn"
const VIEWPORT_SIZE := Vector2i(384, 216)
const OUTPUT_DIR := "res://.codex-research/ripple-review-diagnostic"

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Visible normal review scene should load.")
	if packed_scene == null:
		_finish(false)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var review := packed_scene.instantiate()
	viewport.add_child(review)
	await _settle_frames(16)

	var status: Dictionary = review.call("get_review_status")
	var target_river := review.call("get_target_river") as Node
	_expect(bool(status.get("setup_complete", false)), "Review scene should finish setup. Status: " + str(status))
	_expect(target_river != null, "Review scene should find the target river.")
	if target_river == null:
		viewport.queue_free()
		await _settle_frames(2)
		_finish(false)
		return

	_hide_status_overlay(review)
	_apply_inspection_material_settings(target_river)
	var enabled_material_report := _capture_material_report(target_river)
	var camera_report := _capture_camera_report(review, target_river)
	var ripple_texture_report := _capture_ripple_texture_report(review)
	var mesh_report := _capture_mesh_report(target_river)

	var enabled_image := await _capture_viewport(viewport)
	review.call("set_normal_strength", 0.0)
	_apply_inspection_material_settings(target_river)
	await _settle_frames(2)
	var zero_strength_image := await _capture_viewport(viewport)
	var image_delta := _image_delta(zero_strength_image, enabled_image)
	var output_paths := _save_capture_images(zero_strength_image, enabled_image, image_delta)

	_results = {
		"status": status,
		"image_delta": image_delta,
		"capture_paths": output_paths,
		"material": enabled_material_report,
		"camera": camera_report,
		"ripple_texture": ripple_texture_report,
		"mesh": mesh_report,
	}

	viewport.queue_free()
	await _settle_frames(2)
	_finish(true)


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _capture_viewport(viewport: SubViewport) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for _frame in range(4):
		await process_frame
	var texture := viewport.get_texture()
	# Validation-only readback. Runtime ripple simulation and river rendering must not use this pattern.
	return texture.get_image() if texture != null else Image.create(1, 1, false, Image.FORMAT_RGBA8)


func _hide_status_overlay(review: Node) -> void:
	var label := review.get("_status_label") as Label
	if label != null:
		label.visible = false


func _set_active_shader_parameter(target_river: Node, parameter_name: String, value: Variant) -> void:
	var material := _get_active_shader_material(target_river)
	if material != null and material.shader != null:
		material.set_shader_parameter(parameter_name, value)


func _apply_inspection_material_settings(target_river: Node) -> void:
	# Keep the demo material moving during diagnostics. The human review caught
	# frozen flow when this probe fixture changed flow_speed and normal_scale.
	pass


func _capture_material_report(target_river: Node) -> Dictionary:
	var shader_material := _get_active_shader_material(target_river)
	var mesh_instance := _get_river_mesh_instance(target_river)
	var report := {
		"has_runtime_state": bool(target_river.call("has_runtime_ripple_material_state")),
		"active_material_is_shader": shader_material != null,
		"material_override_is_null": mesh_instance == null or mesh_instance.material_override == null,
	}
	if shader_material == null:
		return report
	var simulation_texture := shader_material.get_shader_parameter("i_ripple_simulation_texture") as Texture2D
	var impulse_texture := shader_material.get_shader_parameter("i_ripple_impulse_texture") as Texture2D
	var boundary_texture := shader_material.get_shader_parameter("i_ripple_boundary_mask") as Texture2D
	report["i_ripple_enabled"] = shader_material.get_shader_parameter("i_ripple_enabled")
	report["i_ripple_normal_strength"] = shader_material.get_shader_parameter("i_ripple_normal_strength")
	report["i_ripple_texel_size"] = shader_material.get_shader_parameter("i_ripple_texel_size")
	report["i_ripple_boundary_fade"] = shader_material.get_shader_parameter("i_ripple_boundary_fade")
	report["flow_speed"] = shader_material.get_shader_parameter("flow_speed")
	report["normal_scale"] = shader_material.get_shader_parameter("normal_scale")
	report["simulation_texture_size"] = simulation_texture.get_size() if simulation_texture != null else Vector2.ZERO
	report["impulse_texture_size"] = impulse_texture.get_size() if impulse_texture != null else Vector2.ZERO
	report["boundary_texture_size"] = boundary_texture.get_size() if boundary_texture != null else Vector2.ZERO
	return report


func _capture_camera_report(review: Node, target_river: Node) -> Dictionary:
	var camera := _find_current_camera(review)
	var bounds: AABB = review.get("_ripple_bounds")
	var centers: Array = review.get("_ripple_centers")
	var focus: Vector3 = review.get("_ripple_focus")
	var mesh_instance := _get_river_mesh_instance(target_river)
	var world_to_uv: Transform3D = review.get("_world_to_ripple_uv")
	var projected := []
	if camera != null:
		for center_variant in centers:
			var center := center_variant as Vector2
			var world_position := _find_nearest_mesh_world_position_for_uv(mesh_instance, world_to_uv, center)
			if world_position == Vector3.INF:
				world_position = Vector3(
					bounds.position.x + bounds.size.x * center.x,
					focus.y,
					bounds.position.z + bounds.size.z * center.y
				)
			var screen_position := camera.unproject_position(world_position)
			projected.append({
				"uv": center,
				"world": world_position,
				"screen": screen_position,
				"behind_camera": camera.is_position_behind(world_position),
				"inside_viewport": Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).has_point(screen_position),
				"camera_distance": camera.global_position.distance_to(world_position),
			})
	return {
		"camera_found": camera != null,
		"camera_name": camera.name if camera != null else "",
		"camera_position": camera.global_position if camera != null else Vector3.ZERO,
		"camera_projection": camera.projection if camera != null else -1,
		"bounds": bounds,
		"focus": focus,
		"projected_centers": projected,
	}


func _capture_ripple_texture_report(review: Node) -> Dictionary:
	var texture := review.get("_ripple_texture") as Texture2D
	if texture == null:
		return {"has_texture": false}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"has_texture": true, "has_image": false}
	var centers: Array = review.get("_ripple_centers")
	var max_slope := 0.0
	var mean_slope := 0.0
	var sample_count := 0
	for center_variant in centers:
		var center := center_variant as Vector2
		var center_px := Vector2i(
			clampi(roundi(center.x * float(image.get_width() - 1)), 0, image.get_width() - 1),
			clampi(roundi(center.y * float(image.get_height() - 1)), 0, image.get_height() - 1)
		)
		for y_offset in range(-16, 17):
			for x_offset in range(-16, 17):
				var x := clampi(center_px.x + x_offset, 0, image.get_width() - 2)
				var y := clampi(center_px.y + y_offset, 0, image.get_height() - 2)
				var center_height := image.get_pixel(x, y).r * 2.0 - 1.0
				var right_height := image.get_pixel(x + 1, y).r * 2.0 - 1.0
				var up_height := image.get_pixel(x, y + 1).r * 2.0 - 1.0
				var slope := Vector2(right_height - center_height, up_height - center_height).length()
				max_slope = max(max_slope, slope)
				mean_slope += slope
				sample_count += 1
	mean_slope /= max(float(sample_count), 1.0)
	return {
		"has_texture": true,
		"has_image": true,
		"size": image.get_size(),
		"center_count": centers.size(),
		"animation_time": review.get("_ripple_animation_time"),
		"texture_frame": review.get("_ripple_texture_frame"),
		"texture_frame_index": review.get("_ripple_texture_frame_index"),
		"precomputed_frame_count": review.get("_ripple_textures").size(),
		"image_generation_count": review.get("_ripple_image_generation_count"),
		"local_max_one_texel_slope": max_slope,
		"local_mean_one_texel_slope": mean_slope,
	}


func _capture_mesh_report(target_river: Node) -> Dictionary:
	var mesh_instance := _get_river_mesh_instance(target_river)
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return {"mesh_found": false}
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var tangents := PackedFloat32Array()
	var normals := PackedVector3Array()
	if arrays.size() > Mesh.ARRAY_TANGENT and arrays[Mesh.ARRAY_TANGENT] != null:
		tangents = arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
	if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null:
		normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	return {
		"mesh_found": true,
		"surface_count": mesh_instance.mesh.get_surface_count(),
		"vertex_count": mesh_instance.mesh.get_faces().size(),
		"tangent_float_count": tangents.size(),
		"normal_count": normals.size(),
		"global_aabb": mesh_instance.global_transform * mesh_instance.get_aabb(),
	}


func _get_river_mesh_instance(target_river: Node) -> MeshInstance3D:
	var direct_mesh := target_river.get("mesh_instance") as MeshInstance3D
	if direct_mesh != null:
		return direct_mesh
	return target_river.get_node_or_null("RiverMeshInstance") as MeshInstance3D


func _get_active_shader_material(target_river: Node) -> ShaderMaterial:
	var mesh_instance := _get_river_mesh_instance(target_river)
	if mesh_instance == null:
		return null
	var active_material := mesh_instance.get_active_material(0) as ShaderMaterial
	if active_material != null:
		return active_material
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	return null


func _find_nearest_mesh_world_position_for_uv(mesh_instance: MeshInstance3D, world_to_uv: Transform3D, target_uv: Vector2) -> Vector3:
	if mesh_instance == null or mesh_instance.mesh == null:
		return Vector3.INF
	var best_world_position := Vector3.INF
	var best_distance := INF
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex in vertices:
			var world_position := mesh_instance.global_transform * vertex
			var mapped := world_to_uv * world_position
			var uv := Vector2(mapped.x, mapped.z)
			var distance := uv.distance_squared_to(target_uv)
			if distance < best_distance:
				best_distance = distance
				best_world_position = world_position
	return best_world_position


func _find_current_camera(root_node: Node) -> Camera3D:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node is Camera3D and (node as Camera3D).current:
			return node as Camera3D
		for child in node.get_children():
			stack.push_back(child)
	return null


func _image_delta(baseline: Image, candidate: Image) -> Dictionary:
	_expect(baseline != null and candidate != null, "Image comparison should have both images.")
	if baseline == null or candidate == null:
		return {"max_delta": 0.0, "mean_delta": 0.0, "changed_pixels": 0}
	_expect(baseline.get_size() == candidate.get_size(), "Image comparison size should match.")
	if baseline.get_size() != candidate.get_size():
		return {"max_delta": 0.0, "mean_delta": 0.0, "changed_pixels": 0}

	var max_delta := 0.0
	var total_delta := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for y in range(baseline.get_height()):
		for x in range(baseline.get_width()):
			var baseline_color := baseline.get_pixel(x, y)
			var candidate_color := candidate.get_pixel(x, y)
			var pixel_delta := max(
				max(abs(baseline_color.r - candidate_color.r), abs(baseline_color.g - candidate_color.g)),
				max(abs(baseline_color.b - candidate_color.b), abs(baseline_color.a - candidate_color.a))
			)
			if pixel_delta > 0.004:
				changed_pixels += 1
			max_delta = max(max_delta, pixel_delta)
			total_delta += pixel_delta
			sample_count += 1
	return {
		"max_delta": max_delta,
		"mean_delta": total_delta / max(float(sample_count), 1.0),
		"changed_pixels": changed_pixels,
	}


func _save_capture_images(baseline: Image, candidate: Image, delta: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var baseline_path := OUTPUT_DIR + "/zero_strength.png"
	var candidate_path := OUTPUT_DIR + "/enabled_ripples.png"
	var diff_path := OUTPUT_DIR + "/diff.png"
	if baseline != null:
		baseline.save_png(baseline_path)
	if candidate != null:
		candidate.save_png(candidate_path)
	if baseline != null and candidate != null and baseline.get_size() == candidate.get_size():
		var diff := Image.create(baseline.get_width(), baseline.get_height(), false, Image.FORMAT_RGBA8)
		var max_delta: float = max(float(delta.get("max_delta", 0.0)), 0.0001)
		for y in range(baseline.get_height()):
			for x in range(baseline.get_width()):
				var baseline_color := baseline.get_pixel(x, y)
				var candidate_color := candidate.get_pixel(x, y)
				var pixel_delta := max(
					max(abs(baseline_color.r - candidate_color.r), abs(baseline_color.g - candidate_color.g)),
					max(abs(baseline_color.b - candidate_color.b), abs(baseline_color.a - candidate_color.a))
				)
				var normalized_delta := clamp(pixel_delta / max_delta, 0.0, 1.0)
				diff.set_pixel(x, y, Color(normalized_delta, normalized_delta, normalized_delta, 1.0))
		diff.save_png(diff_path)
	return {
		"zero_strength": ProjectSettings.globalize_path(baseline_path),
		"enabled_ripples": ProjectSettings.globalize_path(candidate_path),
		"diff": ProjectSettings.globalize_path(diff_path),
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish(success_allowed: bool) -> void:
	print("RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_RESULTS=", _results)
	if _errors.is_empty() and success_allowed:
		print("RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_DIAGNOSTIC_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
