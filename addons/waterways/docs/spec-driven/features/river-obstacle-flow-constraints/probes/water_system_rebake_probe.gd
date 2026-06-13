# Regenerates a scene's WaterSystem combined map from the current river
# bakes (generate_system_maps saves the bake resource itself).
#
# Run (NOT headless - the system map render needs viewport readback):
#   & $godotConsole --path $root --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/water_system_rebake_probe.gd
# Optional arg: -- scene=res://Demo_obstacle_flow_test.tscn (default Demo.tscn)
extends SceneTree

const SCENE_PATH := "res://Demo.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_path := SCENE_PATH
	for arg_variant in OS.get_cmdline_user_args():
		var arg := String(arg_variant)
		if arg.begins_with("scene="):
			scene_path = arg.trim_prefix("scene=")
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: " + scene_path)
		quit(1)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var system := scene.get_node_or_null("WaterSystem")
	if system == null:
		push_error("Could not find WaterSystem in " + scene_path)
		quit(1)
		return
	print("WATER_SYSTEM_REBAKE start")
	await system.generate_system_maps()
	var bake := system.get("bake_data") as Resource
	if bake == null:
		push_error("WaterSystem bake_data missing after generate_system_maps.")
		quit(1)
		return
	# generate_system_maps' internal save is editor-only and silently skips
	# under --script runs, so persist the bake explicitly here.
	if bake.resource_path.is_empty():
		push_error("WaterSystem bake_data has no resource path to save to.")
		quit(1)
		return
	var save_flags := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	var save_error := ResourceSaver.save(bake, bake.resource_path, save_flags)
	print("WATER_SYSTEM_REBAKE save_error=", save_error, " path=", bake.resource_path)
	quit(0 if save_error == OK else 1)
