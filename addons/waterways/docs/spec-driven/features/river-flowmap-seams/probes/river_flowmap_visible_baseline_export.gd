extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const OUTPUT_DIR := "res://.codex-research/river-flowmap-seams-visible-baseline"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const RIVER_PATH := "WaterSystem/Water River"
const RIVER_SCRIPT_PATH := "res://addons/waterways/river_manager.gd"

const SCENES := [
	{
		"name": "demo",
		"path": "res://Demo.tscn",
		"bake": "res://waterways_bakes/Demo/Water_River.river_bake.res",
	},
	{
		"name": "obstacle",
		"path": "res://Demo_obstacle_flow_test.tscn",
		"bake": "res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
	},
]

const DEBUG_VIEWS := [
	{"mode": 0, "name": "lit_water", "kind": "lit_material"},
	{"mode": 8, "name": "final_flow_strength", "kind": "derived_debug"},
	{"mode": 9, "name": "foam_mix", "kind": "derived_debug"},
	{"mode": 6, "name": "flow_pattern", "kind": "derived_debug"},
	{"mode": 10, "name": "raw_flow_rg", "kind": "raw_debug"},
	{"mode": 18, "name": "terrain_contact_r", "kind": "raw_debug"},
	{"mode": 19, "name": "terrain_shallow_g", "kind": "raw_debug"},
	{"mode": 21, "name": "terrain_provenance_a", "kind": "raw_debug"},
	{"mode": 22, "name": "bank_friction_r", "kind": "raw_debug"},
	{"mode": 23, "name": "outside_bend_g", "kind": "raw_debug"},
	{"mode": 24, "name": "inside_bend_b", "kind": "raw_debug"},
	{"mode": 37, "name": "wake_bank_keep_gate", "kind": "derived_debug"},
	{"mode": 30, "name": "wake_visual", "kind": "derived_debug"},
	{"mode": 31, "name": "eddy_line_visual", "kind": "derived_debug"},
]

const CAMERA_SPECS := [
	{"name": "scene_camera", "path": "Camera"},
	{"name": "overview_overhead", "path": "Phase0B Review Cameras/Phase0B_Overview_Overhead"},
	{"name": "upper_overhead", "path": "Phase0B Review Cameras/Phase0B_UpperRiver_Overhead"},
	{"name": "mid_bend_overhead", "path": "Phase0B Review Cameras/Phase0B_MidBend_Overhead"},
	{"name": "rock_garden_overhead", "path": "Phase0B Review Cameras/Phase0B_RockGarden_Overhead"},
	{"name": "lower_exit_overhead", "path": "Phase0B Review Cameras/Phase0B_LowerExit_Overhead"},
	{"name": "main_bend_oblique", "path": "Phase0B Review Cameras/Phase0B_MainBend_Low_Oblique"},
	{"name": "upper_obstructions_oblique", "path": "Phase0B Review Cameras/Phase0B_UpperObstructions_Low_Oblique"},
	{"name": "downstream_rocks_oblique", "path": "Phase0B Review Cameras/Phase0B_Downstream_Rocks_Low_Oblique"},
]

const PILLOW_UNIFORMS := [
	"pillow_forward_reach_tiles",
	"pillow_contact_pull_tiles",
	"pillow_contact_pull_strength",
	"pillow_height_smoothing_tiles",
	"pillow_height_tile_seam_fade",
	"pillow_material_tile_seam_fade",
]

const HELPER_UNIFORMS := [
	"flow_hard_boundary_slide",
	"wake_edge_sample_tiles",
	"wake_strength",
	"wake_bank_suppression",
]

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_absolute)
	for scene_info in SCENES:
		await _export_scene(scene_info)
		if not _errors.is_empty():
			break
	var report_path := OUTPUT_DIR + "/visible_baseline_report.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "\t"))
		file.close()
	print("RIVER_FLOWMAP_VISIBLE_BASELINE_OUTPUT_DIR=", output_absolute)
	print("RIVER_FLOWMAP_VISIBLE_BASELINE_REPORT=", ProjectSettings.globalize_path(report_path))
	if _errors.is_empty():
		print("RIVER_FLOWMAP_VISIBLE_BASELINE_EXPORT_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _export_scene(scene_info: Dictionary) -> void:
	var scene_path := String(scene_info.path)
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "Could not load scene " + scene_path)
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _settle_frames(8)

	var river := scene.get_node_or_null(RIVER_PATH)
	_expect(river != null and river.has_method("set_debug_view"), scene_path + " should contain a debuggable river at " + RIVER_PATH)
	if river == null or not river.has_method("set_debug_view"):
		scene.queue_free()
		await _settle_frames(2)
		return
	var mesh_instance := _get_river_mesh_instance(river)
	_expect(mesh_instance != null and mesh_instance.mesh != null, scene_path + " should have a generated river mesh")
	if mesh_instance == null or mesh_instance.mesh == null:
		scene.queue_free()
		await _settle_frames(2)
		return

	var cameras := _collect_cameras(scene, mesh_instance)
	_expect(not cameras.is_empty(), scene_path + " should have at least one review camera")
	if cameras.is_empty():
		scene.queue_free()
		await _settle_frames(2)
		return

	var marker_parent := _create_join_markers(river, mesh_instance)
	marker_parent.visible = false
	scene.add_child(marker_parent)

	var scene_name := String(scene_info.name)
	var all_cameras := scene.find_children("*", "Camera3D", true, false)
	_results[scene_name] = {
		"scene_path": scene_path,
		"bake_path": String(scene_info.bake),
		"material": _capture_material_report(river),
		"bake": _capture_bake_report(river, String(scene_info.bake)),
		"join_classes": _capture_join_classes(river),
		"captures": [],
	}

	for camera_info in cameras:
		var camera := camera_info.camera as Camera3D
		_make_only_camera_current(all_cameras, camera)
		for view_info in DEBUG_VIEWS:
			river.call("set_debug_view", int(view_info.mode))
			marker_parent.visible = false
			await _settle_frames(12)
			_save_capture(scene_name, String(camera_info.name), view_info, false)

			if int(view_info.mode) == 0:
				marker_parent.visible = true
				await _settle_frames(4)
				_save_capture(scene_name, String(camera_info.name), view_info, true)
				marker_parent.visible = false

	scene.queue_free()
	await _settle_frames(3)


func _collect_cameras(scene: Node, mesh_instance: MeshInstance3D) -> Array:
	var cameras := []
	for camera_spec in CAMERA_SPECS:
		var camera := scene.get_node_or_null(String(camera_spec.path)) as Camera3D
		if camera != null:
			cameras.append({"name": String(camera_spec.name), "camera": camera})
	if cameras.is_empty():
		var generated_camera := _make_generated_overhead_camera(mesh_instance)
		scene.add_child(generated_camera)
		cameras.append({"name": "generated_overhead", "camera": generated_camera})
	elif not _has_overhead_camera(cameras):
		var generated := _make_generated_overhead_camera(mesh_instance)
		scene.add_child(generated)
		cameras.append({"name": "generated_overhead", "camera": generated})
	return cameras


func _has_overhead_camera(cameras: Array) -> bool:
	for camera_info in cameras:
		if String(camera_info.name).contains("overhead"):
			return true
	return false


func _make_generated_overhead_camera(mesh_instance: MeshInstance3D) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "Generated_River_Seam_Overhead"
	var bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
	var center := bounds.get_center()
	var camera_position := center + Vector3(0.0, maxf(bounds.size.length(), 40.0), 0.0)
	camera.look_at_from_position(camera_position, center, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(maxf(bounds.size.x, bounds.size.z) * 1.25, 25.0)
	camera.near = 0.05
	camera.far = maxf(bounds.size.length() * 4.0, 200.0)
	return camera


func _save_capture(scene_name: String, camera_name: String, view_info: Dictionary, markers: bool) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_expect(false, "Could not capture " + scene_name + " " + camera_name + " " + String(view_info.name))
		return
	var marker_suffix := "__join_markers" if markers else ""
	var output_path := OUTPUT_DIR + "/" + scene_name + "__" + camera_name + "__" + String(view_info.name) + marker_suffix + ".png"
	var error := image.save_png(output_path)
	_expect(error == OK, "Could not save " + output_path + " error=" + str(error))
	if error == OK:
		var scene_result := _results[scene_name] as Dictionary
		var captures := scene_result.get("captures", []) as Array
		captures.append({
			"camera": camera_name,
			"view": String(view_info.name),
			"mode": int(view_info.mode),
			"kind": String(view_info.kind),
			"join_markers": markers,
			"path": ProjectSettings.globalize_path(output_path),
		})


func _capture_material_report(river: Node) -> Dictionary:
	var material := _get_visible_shader_material(river)
	var report := {
		"has_shader_material": material != null,
		"pillow_uniforms": {},
		"helper_uniforms": {},
	}
	if material == null:
		return report
	for uniform_name in PILLOW_UNIFORMS:
		report.pillow_uniforms[uniform_name] = material.get_shader_parameter(uniform_name)
	for uniform_name in HELPER_UNIFORMS:
		report.helper_uniforms[uniform_name] = material.get_shader_parameter(uniform_name)
	return report


func _capture_bake_report(river: Node, bake_path: String) -> Dictionary:
	var bake := river.get("bake_data") as Resource
	if bake == null:
		bake = load(bake_path) as Resource
	if bake == null:
		return {"has_bake": false}
	var signature = bake.get("source_signature")
	var signature_version := -1
	var step_count := 0
	if typeof(signature) == TYPE_DICTIONARY:
		signature_version = int((signature as Dictionary).get("version", -1))
		step_count = int((signature as Dictionary).get("step_count", 0))
	return {
		"has_bake": true,
		"resource_path": bake.resource_path,
		"uv2_sides": int(bake.get("uv2_sides")),
		"signature_version": signature_version,
		"step_count": step_count,
		"content_rect": str(bake.get("content_rect")),
		"texture_size": str((bake.get("flow_foam_noise") as Texture2D).get_size()) if bake.get("flow_foam_noise") is Texture2D else "",
	}


func _capture_join_classes(river: Node) -> Array:
	var bake := river.get("bake_data") as Resource
	var uv2_sides := maxi(1, int(river.get("_uv2_sides")))
	var occupied_steps := _get_occupied_steps(river, bake, uv2_sides)
	var joins := []
	for join_index in range(maxi(occupied_steps - 1, 0)):
		var atlas_class := "row-wrap" if join_index % uv2_sides == uv2_sides - 1 else "same-column"
		joins.append({
			"join_index": join_index,
			"from_step": join_index,
			"to_step": join_index + 1,
			"atlas_class": atlas_class,
		})
	var column_edges := []
	for column in range(maxi(uv2_sides - 1, 0)):
		for row in range(uv2_sides):
			var left_step := column * uv2_sides + row
			var right_step := (column + 1) * uv2_sides + row
			if left_step < occupied_steps and right_step < occupied_steps:
				column_edges.append({
					"left_step": left_step,
					"right_step": right_step,
					"atlas_class": "column X-edge band",
				})
	return [{
		"uv2_sides": uv2_sides,
		"occupied_steps": occupied_steps,
		"logical_joins": joins,
		"column_x_edge_bands": column_edges,
	}]


func _create_join_markers(river: Node, mesh_instance: MeshInstance3D) -> Node3D:
	var marker_parent := Node3D.new()
	marker_parent.name = "RiverSeamJoinMarkers"
	var marker_mesh := ImmediateMesh.new()
	marker_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var bake := river.get("bake_data") as Resource
	var uv2_sides := maxi(1, int(river.get("_uv2_sides")))
	var occupied_steps := _get_occupied_steps(river, bake, uv2_sides)
	var rows := _build_river_rows(river, mesh_instance, occupied_steps)
	for join_index in range(maxi(occupied_steps - 1, 0)):
		var row_index := (join_index + 1) * int(river.get("shape_step_length_divs"))
		if row_index < 0 or row_index >= rows.size():
			continue
		var row: Array = rows[row_index]
		if row.size() < 2:
			continue
		var color := Color(1.0, 0.16, 0.08, 1.0)
		if join_index % uv2_sides == uv2_sides - 1:
			color = Color(1.0, 0.85, 0.06, 1.0)
		var start := (mesh_instance.global_transform * (row.front() as Vector3)) + Vector3.UP * 0.08
		var end := (mesh_instance.global_transform * (row.back() as Vector3)) + Vector3.UP * 0.08
		marker_mesh.surface_set_color(color)
		marker_mesh.surface_add_vertex(start)
		marker_mesh.surface_set_color(color)
		marker_mesh.surface_add_vertex(end)
	marker_mesh.surface_end()
	var marker_instance := MeshInstance3D.new()
	marker_instance.name = "LogicalJoinLines"
	marker_instance.mesh = marker_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color.WHITE
	marker_instance.material_override = material
	marker_parent.add_child(marker_instance)
	return marker_parent


func _build_river_rows(river: Node, mesh_instance: MeshInstance3D, occupied_steps: int) -> Array:
	var curve := river.get("curve") as Curve3D
	var widths := river.get("widths") as Array
	var length_divs := clampi(int(river.get("shape_step_length_divs")), 1, 8)
	var width_divs := clampi(int(river.get("shape_step_width_divs")), 1, 8)
	var smoothness := clampf(float(river.get("shape_smoothness")), 0.1, 5.0)
	var river_width_values := WaterHelperMethods.generate_river_width_values(curve, occupied_steps, length_divs, width_divs, widths)
	var step_count := occupied_steps * length_divs
	var curve_length := curve.get_baked_length()
	var rows := []
	for step in range(step_count + 1):
		var row := []
		var position: Vector3 = WaterHelperMethods._sample_river_position(curve, step, step_count, curve_length)
		var backward_pos: Vector3 = WaterHelperMethods._sample_river_position(curve, float(step) - smoothness, step_count, curve_length)
		var forward_pos: Vector3 = WaterHelperMethods._sample_river_position(curve, float(step) + smoothness, step_count, curve_length)
		var right_vector: Vector3 = WaterHelperMethods._safe_right_vector(forward_pos - backward_pos)
		var width_lerp := WaterHelperMethods.MIN_RIVER_WIDTH
		if step < river_width_values.size():
			width_lerp = maxf(WaterHelperMethods.MIN_RIVER_WIDTH, float(river_width_values[step]))
		for w_sub in range(width_divs + 1):
			var width_ratio := float(w_sub) / float(width_divs)
			row.append(position + right_vector * width_lerp - 2.0 * right_vector * width_lerp * width_ratio)
		rows.append(row)
	return rows


func _get_occupied_steps(river: Node, bake: Resource, uv2_sides: int) -> int:
	var total_tiles := uv2_sides * uv2_sides
	if bake != null:
		var signature = bake.get("source_signature")
		if typeof(signature) == TYPE_DICTIONARY:
			var signature_steps := int((signature as Dictionary).get("step_count", 0))
			if signature_steps > 0:
				return clampi(signature_steps, 1, total_tiles)
	if river.has_method("_calculate_step_count"):
		return clampi(int(river.call("_calculate_step_count")), 1, total_tiles)
	return total_tiles


func _get_river_mesh_instance(river: Node) -> MeshInstance3D:
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance != null:
		return mesh_instance
	return river.get_node_or_null("RiverMeshInstance") as MeshInstance3D


func _get_visible_shader_material(river: Node) -> ShaderMaterial:
	var material := river.get("_material") as ShaderMaterial
	if material != null:
		return material
	var mesh_instance := _get_river_mesh_instance(river)
	if mesh_instance != null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	return null


func _make_only_camera_current(cameras: Array, active_camera: Camera3D) -> void:
	for camera in cameras:
		if camera is Camera3D:
			(camera as Camera3D).current = false
	if active_camera != null:
		active_camera.make_current()


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
