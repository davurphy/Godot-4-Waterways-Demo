extends SceneTree

const CASES := [
	{
		"name": "main_demo",
		"scene": "res://Demo.tscn",
	},
	{
		"name": "obstacle_test",
		"scene": "res://Demo_obstacle_flow_test.tscn",
	},
]

var _bake_done := false
var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for case_variant in CASES:
		var probe_case := case_variant as Dictionary
		var ok := await _rebake_scene(probe_case)
		if not ok:
			break
	if _errors.is_empty():
		print("RIVER_FLOWMAP_SEAM_REBAKE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _rebake_scene(probe_case: Dictionary) -> bool:
	var scene_path := String(probe_case.get("scene", ""))
	var case_name := String(probe_case.get("name", scene_path))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_expect(false, "Could not load scene: " + scene_path)
		return false
	var scene := packed.instantiate()
	if scene == null:
		_expect(false, "Could not instantiate scene: " + scene_path)
		return false
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var river := scene.get_node_or_null("WaterSystem/Water River")
	if river == null:
		_expect(false, "Could not find WaterSystem/Water River in " + scene_path)
		scene.queue_free()
		await process_frame
		return false

	print("RIVER_FLOWMAP_SEAM_REBAKE_SCENE case=", case_name, " scene=", scene_path)
	_bake_done = false
	if not river.progress_notified.is_connected(_on_river_progress_notified):
		river.progress_notified.connect(_on_river_progress_notified)
	river.bake_texture()
	var frames := 0
	while not _bake_done and frames < 3600:
		await process_frame
		frames += 1
	if not _bake_done:
		_expect(false, "River bake did not finish within timeout for " + scene_path)
		scene.queue_free()
		await process_frame
		return false

	var bake_data := river.get("bake_data") as Resource
	if not _save_resource(bake_data, "RIVER_" + case_name):
		scene.queue_free()
		await process_frame
		return false
	_print_bake_summary(case_name, bake_data)
	scene.queue_free()
	await process_frame
	return true


func _on_river_progress_notified(_progress: float, message: String) -> void:
	if message == "finished":
		_bake_done = true


func _save_resource(resource: Resource, label: String) -> bool:
	if resource == null:
		_expect(false, label + " bake resource is missing.")
		return false
	if resource.resource_path.is_empty():
		_expect(false, label + " bake resource has no save path.")
		return false
	var save_flags := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	var save_error := ResourceSaver.save(resource, resource.resource_path, save_flags)
	print(label + "_SAVE_PATH=", resource.resource_path)
	print(label + "_SAVE_ERROR=", save_error)
	if save_error != OK:
		_expect(false, label + " save failed with error " + str(save_error))
		return false
	return true


func _print_bake_summary(case_name: String, bake_data: Resource) -> void:
	if bake_data == null:
		return
	var source_signature: Dictionary = bake_data.get("source_signature")
	var source_metadata: Dictionary = bake_data.get("source_metadata")
	print("RIVER_FLOWMAP_SEAM_REBAKE_SUMMARY case=", case_name)
	print("  signature_version=", source_signature.get("version", "<none>"))
	print("  uv2_world_sample_tile_classifier=", source_signature.get("uv2_world_sample_tile_classifier", "<none>"))
	print("  terrain_contact_stats=", source_metadata.get("terrain_contact_feature_stats", {}))
	print("  bank_response_stats=", source_metadata.get("bank_response_feature_stats", {}))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
