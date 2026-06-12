extends SceneTree

# Exports the object-artifact-relevant debug views from the Demo scene's
# review cameras so before/after bake changes can be compared as PNGs.
# Set OBJECT_ARTIFACT_EXPORT_LABEL to name the output subfolder
# (default "current").
# Success marker: OBJECT_ARTIFACT_VISUAL_EXPORT_OK

const OUTPUT_ROOT := "res://.codex-research/river-object-artifacts-visual-review"
const SCENE_PATH := "res://Demo.tscn"
const RIVER_NODE_PATH := "WaterSystem/Water River"

const DEBUG_VIEWS := [
	{"mode": 0, "name": "visible_water"},
	{"mode": 9, "name": "foam_mix"},
	{"mode": 8, "name": "final_flow_strength"},
	{"mode": 15, "name": "wake_eddy_seed_g"},
	{"mode": 20, "name": "protrusion_b"},
	{"mode": 21, "name": "provenance_a"},
]

const REVIEW_CAMERAS := [
	{"path": "Phase0B Review Cameras/Phase0B_RockGarden_Overhead", "name": "rock_garden_overhead"},
	{"path": "Phase0B Review Cameras/Phase0B_Downstream_Rocks_Low_Oblique", "name": "downstream_rocks_low_oblique"},
	{"path": "Phase0B Review Cameras/Phase0B_UpperObstructions_Low_Oblique", "name": "upper_obstructions_low_oblique"},
]

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var label := OS.get_environment("OBJECT_ARTIFACT_EXPORT_LABEL")
	if label.is_empty():
		label = "current"
	var output_dir := OUTPUT_ROOT + "/" + label
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var ok := await _export_scene(output_dir)
	if ok and _errors.is_empty():
		print("OBJECT_ARTIFACT_VISUAL_EXPORT_OUTPUT_DIR=", output_dir)
		print("OBJECT_ARTIFACT_VISUAL_EXPORT_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _export_scene(output_dir: String) -> bool:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + SCENE_PATH)
		return false
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var river := scene.get_node_or_null(RIVER_NODE_PATH)
	if river == null or not river.has_method("set_debug_view"):
		_errors.append("No debuggable river at " + RIVER_NODE_PATH)
		scene.queue_free()
		return false
	var cameras := []
	for camera_info in REVIEW_CAMERAS:
		var camera := scene.get_node_or_null(String(camera_info.path)) as Camera3D
		if camera == null:
			push_warning("Missing review camera: " + String(camera_info.path))
			continue
		cameras.append({"camera": camera, "name": String(camera_info.name)})
	if cameras.is_empty():
		_errors.append("No review cameras found")
		scene.queue_free()
		return false
	var all_cameras := scene.find_children("*", "Camera3D", true, false)
	for view in DEBUG_VIEWS:
		river.call("set_debug_view", int(view.mode))
		for camera_info in cameras:
			var active_camera := camera_info.get("camera") as Camera3D
			for candidate in all_cameras:
				(candidate as Camera3D).current = candidate == active_camera
			await _settle_frames(12)
			var image := root.get_texture().get_image()
			if image == null or image.is_empty():
				_errors.append("Could not capture " + String(camera_info.name) + " " + String(view.name))
				scene.queue_free()
				return false
			var output_path := output_dir + "/" + String(camera_info.name) + "__" + String(view.name) + ".png"
			var error := image.save_png(output_path)
			if error != OK:
				_errors.append("Could not save " + output_path + " error=" + str(error))
				scene.queue_free()
				return false
	scene.queue_free()
	await process_frame
	return true


func _settle_frames(count: int) -> void:
	for _index in count:
		await process_frame
