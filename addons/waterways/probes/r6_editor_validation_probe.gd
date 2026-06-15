# River-refactor R6.4 editor validation wrapper and marker probe.
#
# Exercises the public RiverManager validation wrappers and the River menu
# validation signals. Use without --headless because filter renderer readback
# needs a real viewport.
#
# Run:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r6_editor_validation_probe.gd
#
# Success marker: R6_EDITOR_VALIDATION_PROBE_OK
extends SceneTree

const DEFAULT_SCENE := "res://Demo.tscn"
const DEFAULT_RIVER_PATH := "WaterSystem/Water River"
const RIVER_CONTROLS_SCENE := "res://addons/waterways/gui/river_controls.tscn"

var _errors := PackedStringArray()
var _menu_data_signal_count := 0
var _menu_filter_signal_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_menu_validation_signals()
	await _run_direct_wrapper_checks()
	if _errors.is_empty():
		print("R6_EDITOR_VALIDATION_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _check_menu_validation_signals() -> void:
	var controls_scene := load(RIVER_CONTROLS_SCENE) as PackedScene
	if controls_scene == null:
		_errors.append("Could not load river controls scene")
		return
	var controls := controls_scene.instantiate()
	if controls == null:
		_errors.append("Could not instantiate river controls")
		return
	root.add_child(controls)
	var menu := controls.get_node_or_null("RiverMenu")
	if menu == null:
		_errors.append("RiverMenu was not found in river controls")
		controls.queue_free()
		return
	menu.connect("validate_data_textures", Callable(self, "_on_menu_data_validation_signal"))
	menu.connect("validate_filter_renderer", Callable(self, "_on_menu_filter_validation_signal"))
	menu.call("_menu_item_selected", 2)
	menu.call("_menu_item_selected", 3)
	if _menu_data_signal_count != 1:
		_errors.append("RiverMenu did not emit validate_data_textures exactly once")
	if _menu_filter_signal_count != 1:
		_errors.append("RiverMenu did not emit validate_filter_renderer exactly once")
	controls.queue_free()
	if _errors.is_empty():
		print("R6_EDITOR_VALIDATION_MENU_SIGNALS_OK data=1 filter=1")


func _run_direct_wrapper_checks() -> void:
	var scene_resource := load(DEFAULT_SCENE) as PackedScene
	if scene_resource == null:
		_errors.append("Could not load scene " + DEFAULT_SCENE)
		return
	var scene := scene_resource.instantiate()
	if scene == null:
		_errors.append("Could not instantiate scene " + DEFAULT_SCENE)
		return
	root.add_child(scene)
	await process_frame
	var river := scene.get_node_or_null(DEFAULT_RIVER_PATH)
	if river == null:
		_errors.append("Could not find river " + DEFAULT_RIVER_PATH)
		scene.queue_free()
		return
	if not river.has_method("validate_data_textures"):
		_errors.append("River missing validate_data_textures wrapper")
	if not river.has_method("validate_filter_renderer"):
		_errors.append("River missing validate_filter_renderer wrapper")
	if not _errors.is_empty():
		scene.queue_free()
		return
	print("R6_EDITOR_VALIDATION_DIRECT_DATA_BEGIN")
	river.validate_data_textures()
	print("R6_EDITOR_VALIDATION_DIRECT_FILTER_BEGIN")
	await river.validate_filter_renderer()
	scene.queue_free()


func _on_menu_data_validation_signal() -> void:
	_menu_data_signal_count += 1


func _on_menu_filter_validation_signal() -> void:
	_menu_filter_signal_count += 1
