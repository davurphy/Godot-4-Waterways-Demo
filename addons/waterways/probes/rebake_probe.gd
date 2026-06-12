# General-purpose bake regenerator: loads each scene, bakes its river, saves
# the bake resource, and optionally regenerates the WaterSystem combined map.
# This is the standard tool after a bake source signature bump; feature
# probes layer their own gates on top (e.g. river_obstacle_projection_rebake_probe).
#
# Run (NOT headless - bakes need viewport readback). User args after `--`:
#   & $godotConsole --path $root --script res://addons/waterways/probes/rebake_probe.gd
#
# Args (all optional, key=value):
#   scenes=<comma-separated res:// paths>   default res://Demo.tscn,res://Demo_obstacle_flow_test.tscn
#   river=<node path within each scene>     default WaterSystem/Water River
#   save=<true|false>                       save river bakes (default true)
#   system=<node path|none>                 WaterSystem to regenerate + save after
#                                           river bakes (default WaterSystem in the
#                                           FIRST scene only; `system=none` skips)
#
# generate_system_maps' internal save is editor-only and silently no-ops under
# --script runs, so this probe always saves the system bake explicitly and
# prints the save_error. Success marker: REBAKE_PROBE_OK
extends SceneTree

const DEFAULT_SCENES := "res://Demo.tscn,res://Demo_obstacle_flow_test.tscn"
const DEFAULT_RIVER := "WaterSystem/Water River"
const DEFAULT_SYSTEM := "WaterSystem"
const BAKE_TIMEOUT_FRAMES := 7200
const SAVE_FLAGS := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES

var _bake_done := false
var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var scene_paths := String(args.get("scenes", DEFAULT_SCENES)).split(",", false)
	var river_path := String(args.get("river", DEFAULT_RIVER))
	var save_bakes := String(args.get("save", "true")).to_lower() != "false"
	var system_path := String(args.get("system", DEFAULT_SYSTEM))

	for scene_index in scene_paths.size():
		var scene_path := String(scene_paths[scene_index]).strip_edges()
		var regenerate_system := system_path != "none" and scene_index == 0
		await _rebake_scene(scene_path, river_path, save_bakes, system_path if regenerate_system else "none")
		if not _errors.is_empty():
			break

	if _errors.is_empty():
		print("REBAKE_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _rebake_scene(scene_path: String, river_path: String, save_bakes: bool, system_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + scene_path)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		_errors.append("Could not find " + river_path + " in " + scene_path)
	else:
		print("REBAKE scene=", scene_path, " river=", river_path)
		if not river.progress_notified.is_connected(_on_river_progress_notified):
			river.progress_notified.connect(_on_river_progress_notified)
		_bake_done = false
		river.bake_texture()
		var frames := 0
		while not _bake_done and frames < BAKE_TIMEOUT_FRAMES:
			await process_frame
			frames += 1
		if not _bake_done:
			_errors.append("River bake did not finish within timeout for " + scene_path)
		else:
			var bake_data := river.get("bake_data") as Resource
			if bake_data == null:
				_errors.append(scene_path + ": bake_data missing after bake")
			else:
				var metadata: Dictionary = bake_data.get("source_metadata")
				print("REBAKE_RESULT scene=", scene_path,
					" signature_version=", bake_data.get("source_signature_version"),
					" flow_projected=", metadata.get("flow_projected", false),
					" flow_speed_scaled=", metadata.get("flow_speed_scaled", false))
				if save_bakes:
					if bake_data.resource_path.is_empty():
						_errors.append(scene_path + ": bake_data has no resource path to save to")
					else:
						var save_error := ResourceSaver.save(bake_data, bake_data.resource_path, SAVE_FLAGS)
						print("REBAKE_SAVE scene=", scene_path, " save_error=", save_error, " path=", bake_data.resource_path)
						if save_error != OK:
							_errors.append(scene_path + ": river bake save failed with error " + str(save_error))

	if _errors.is_empty() and system_path != "none":
		await _regenerate_system(scene, scene_path, system_path)

	scene.queue_free()
	await process_frame


func _regenerate_system(scene: Node, scene_path: String, system_path: String) -> void:
	var system := scene.get_node_or_null(system_path)
	if system == null:
		_errors.append("Could not find " + system_path + " in " + scene_path)
		return
	print("REBAKE_SYSTEM scene=", scene_path, " system=", system_path)
	await system.generate_system_maps()
	var bake := system.get("bake_data") as Resource
	if bake == null:
		_errors.append(scene_path + ": WaterSystem bake_data missing after generate_system_maps")
		return
	if bake.resource_path.is_empty():
		_errors.append(scene_path + ": WaterSystem bake_data has no resource path to save to")
		return
	var save_error := ResourceSaver.save(bake, bake.resource_path, SAVE_FLAGS)
	print("REBAKE_SYSTEM_SAVE save_error=", save_error, " path=", bake.resource_path)
	if save_error != OK:
		_errors.append(scene_path + ": WaterSystem bake save failed with error " + str(save_error))


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args


func _on_river_progress_notified(_progress: float, message: String) -> void:
	if message == "finished":
		_bake_done = true
