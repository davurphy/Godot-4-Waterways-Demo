extends SceneTree

const OUTPUT_DIR := "res://.codex-research/river-pillows-visual-review"

const SCENES := [
	{"path": "res://Demo.tscn", "river_path": "WaterSystem/Water River", "name": "main"},
	{"path": "res://Demo_obstacle_flow_test.tscn", "river_path": "WaterSystem/Water River", "name": "obstacle_test"},
]

const DEBUG_VIEWS := [
	{"mode": 0, "name": "visible_water"},
	{"mode": 14, "name": "pillow_impact_raw_r"},
	{"mode": 26, "name": "pillow_visual_mask"},
	{"mode": 58, "name": "pillow_visual_mask_black_zero"},
	{"mode": 48, "name": "pillow_no_reach_black_zero"},
	{"mode": 49, "name": "pillow_direct_terrain_anchor"},
	{"mode": 50, "name": "pillow_bank_response_anchor"},
	{"mode": 51, "name": "pillow_combined_contact_gate"},
	{"mode": 52, "name": "pillow_bank_only_anchor_contribution"},
	{"mode": 53, "name": "pillow_raw_to_final_retention"},
	{"mode": 54, "name": "pillow_material_response"},
	{"mode": 55, "name": "pillow_material_seam_guard"},
	{"mode": 56, "name": "pillow_height_seam_guard"},
	{"mode": 57, "name": "pillow_height_seam_stitch"},
	{"mode": 27, "name": "pillow_height_influence"},
	{"mode": 28, "name": "terrain_pillow_height_influence"},
	{"mode": 29, "name": "obstruction_pillow_height_influence"},
]

const REVIEW_CAMERAS := [
	{"path": "Camera", "name": "demo"},
	{"path": "Phase0B Review Cameras/Phase0B_Overview_Overhead", "name": "overview_overhead"},
	{"path": "Phase0B Review Cameras/Phase0B_RockGarden_Overhead", "name": "rock_garden_overhead"},
	{"path": "Phase0B Review Cameras/Phase0B_MainBend_Low_Oblique", "name": "main_bend_low_oblique"},
	{"path": "Phase0B Review Cameras/Phase0B_Downstream_Rocks_Low_Oblique", "name": "downstream_rocks_low_oblique"},
]

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var quick := OS.get_environment("PILLOW_VISUAL_EXPORT_QUICK") == "1"
	root.size = Vector2i(1280, 720) if quick else Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenes := [SCENES[0]] if quick else SCENES
	var debug_views := DEBUG_VIEWS.slice(0, 4) if quick else DEBUG_VIEWS
	var camera_specs := [REVIEW_CAMERAS[0]] if quick else REVIEW_CAMERAS
	for scene_info in scenes:
		var ok := await _export_scene(scene_info, debug_views, camera_specs)
		if not ok:
			break
	if _errors.is_empty():
		print("PILLOW_VISUAL_REVIEW_EXPORT_OUTPUT_DIR=", OUTPUT_DIR)
		print("PILLOW_VISUAL_REVIEW_EXPORT_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _export_scene(scene_info: Dictionary, debug_views: Array, camera_specs: Array) -> bool:
	var scene_path := String(scene_info.path)
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, scene_path + " should load")
	if packed == null:
		return false
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var river := scene.get_node_or_null(String(scene_info.river_path))
	_expect(river != null and river.has_method("set_debug_view"), scene_path + " should contain a debuggable river at " + String(scene_info.river_path))
	if river == null or not river.has_method("set_debug_view"):
		scene.queue_free()
		return false
	var cameras := _get_review_cameras(scene, camera_specs)
	_expect(not cameras.is_empty(), scene_path + " should have at least one review camera")
	if cameras.is_empty():
		scene.queue_free()
		return false
	var all_cameras := scene.find_children("*", "Camera3D", true, false)
	for view in debug_views:
		river.call("set_debug_view", int(view.mode))
		for camera_info in cameras:
			var active_camera := camera_info.get("camera") as Camera3D
			_make_only_camera_current(all_cameras, active_camera)
			await _settle_frames(12)
			var image := root.get_texture().get_image()
			if image == null or image.is_empty():
				_expect(false, "Could not capture " + String(scene_info.name) + " " + String(camera_info.name) + " " + String(view.name))
				scene.queue_free()
				return false
			var output_path := OUTPUT_DIR + "/" + String(scene_info.name) + "__" + String(camera_info.name) + "__" + String(view.name) + ".png"
			var error := image.save_png(output_path)
			print("PILLOW_VISUAL_REVIEW_EXPORT_PATH=", output_path, " error=", error)
			if error != OK:
				_expect(false, "Could not save " + output_path + " error=" + str(error))
				scene.queue_free()
				return false
	scene.queue_free()
	await process_frame
	return true


func _get_review_cameras(scene: Node, camera_specs: Array) -> Array:
	var cameras := []
	for camera_info in camera_specs:
		var camera := scene.get_node_or_null(String(camera_info.path)) as Camera3D
		if camera == null:
			push_warning("Missing pillow review camera: " + String(camera_info.path))
			continue
		cameras.append({
			"camera": camera,
			"name": String(camera_info.name),
		})
	return cameras


func _make_only_camera_current(cameras: Array, active_camera: Camera3D) -> void:
	for camera_info in cameras:
		var camera := camera_info as Camera3D
		if camera != null:
			camera.current = false
	if active_camera != null:
		active_camera.make_current()


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
