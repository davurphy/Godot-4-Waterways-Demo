# River-refactor R6 baseline dump probe (headless OK).
#
# Captures the pre/post-R6 canonical dictionary dumps for RiverBakeData
# source_metadata, source_signature, and bake_settings, plus the RiverManager
# public script surface, signal surface, and full inspector property lists.
#
# Run:
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/r6_baseline_dump_probe.gd
#
# Optional args after `--`:
#   out=res://.codex-research/r6-baselines/pre-r6
#
# Success marker: R6_BASELINE_DUMP_OK
extends SceneTree

const RIVER_MANAGER_SCRIPT_PATH := "res://addons/waterways/river_manager.gd"
const DEFAULT_OUT_DIR := "res://.codex-research/r6-baselines/pre-r6"
const DEFAULT_RIVER_PATH := "WaterSystem/Water River"
const DYNAMIC_METADATA_ALLOW_LIST := {
	"bake_revision": true,
}

const BAKE_TARGETS := [
	{
		"label": "demo",
		"path": "res://waterways_bakes/Demo/Water_River.river_bake.res",
	},
	{
		"label": "demo_obstacle_flow_test",
		"path": "res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
	},
]

const SCENE_TARGETS := [
	{
		"label": "demo",
		"path": "res://Demo.tscn",
		"river": DEFAULT_RIVER_PATH,
	},
	{
		"label": "demo_obstacle_flow_test",
		"path": "res://Demo_obstacle_flow_test.tscn",
		"river": DEFAULT_RIVER_PATH,
	},
]

const REQUIRED_PUBLIC_METHODS := [
	"is_bake_in_progress",
	"bake_texture",
	"add_point",
	"remove_point",
	"set_curve_point_position",
	"set_curve_point_in",
	"set_curve_point_out",
	"set_widths",
	"set_flow_speeds",
	"set_bake_generation_behavior",
	"set_materials",
	"set_debug_view",
	"apply_runtime_ripple_material_state",
	"clear_runtime_ripple_material_state",
	"has_runtime_ripple_material_state",
	"validate_data_textures",
	"validate_filter_renderer",
	"get_bake_source_signature",
]

const REQUIRED_SIGNALS := [
	"river_changed",
	"progress_notified",
]

var _errors := PackedStringArray()
var _written_files := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var out_abs := ProjectSettings.globalize_path(out_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(out_abs)
	if dir_error != OK:
		push_error("Could not create output directory " + out_abs + ": " + error_string(dir_error))
		quit(1)
		return

	_dump_bake_dictionaries(out_dir)
	_dump_river_manager_surface(out_dir)
	await _dump_property_lists(out_dir)

	if _errors.is_empty():
		for file_path in _written_files:
			print("R6_BASELINE_DUMP_FILE ", file_path)
		print("R6_BASELINE_DUMP_OK out=", out_dir, " files=", _written_files.size())
		quit(0)
		return

	for error in _errors:
		push_error(error)
	quit(1)


func _dump_bake_dictionaries(out_dir: String) -> void:
	for target_variant in BAKE_TARGETS:
		var target: Dictionary = target_variant
		var label := String(target.get("label", ""))
		var bake_path := String(target.get("path", ""))
		var bake := load(bake_path) as Resource
		if bake == null:
			_errors.append("Could not load bake resource: " + bake_path)
			continue
		_write_dictionary_dump(
			out_dir.path_join(label + "__source_metadata.txt"),
			"source_metadata",
			label + " " + bake_path,
			_get_bake_dictionary(bake, "source_metadata")
		)
		_write_dictionary_dump(
			out_dir.path_join(label + "__source_signature.txt"),
			"source_signature",
			label + " " + bake_path,
			_get_bake_dictionary(bake, "source_signature")
		)
		_write_dictionary_dump(
			out_dir.path_join(label + "__bake_settings.txt"),
			"bake_settings",
			label + " " + bake_path,
			_get_bake_dictionary(bake, "bake_settings")
		)


func _get_bake_dictionary(bake: Resource, property_name: String) -> Dictionary:
	var value = bake.get(property_name)
	if typeof(value) != TYPE_DICTIONARY:
		_errors.append("Bake " + str(bake.resource_path) + " property " + property_name + " is not a Dictionary.")
		return {}
	return (value as Dictionary).duplicate(true)


func _write_dictionary_dump(file_path: String, section: String, target: String, source: Dictionary) -> void:
	var filtered := source.duplicate(true)
	if section == "source_metadata":
		for key in DYNAMIC_METADATA_ALLOW_LIST.keys():
			filtered.erase(key)

	var keys := filtered.keys()
	keys.sort_custom(_sort_variant_keys)
	var lines := PackedStringArray()
	lines.append("R6_CANONICAL_DUMP v1")
	lines.append("section=" + section)
	lines.append("target=" + target)
	lines.append("key_count=" + str(keys.size()))
	for key in keys:
		lines.append(str(key) + " = " + _serialize_canonical_value(filtered[key]))
	_write_text_file(file_path, "\n".join(lines) + "\n")


func _dump_river_manager_surface(out_dir: String) -> void:
	var source := FileAccess.get_file_as_string(RIVER_MANAGER_SCRIPT_PATH)
	if source.is_empty():
		_errors.append("Could not read RiverManager source: " + RIVER_MANAGER_SCRIPT_PATH)
		return

	var public_methods := []
	var public_method_names := {}
	var signals := []
	var signal_names := {}
	var lines := source.split("\n", true)
	for index in lines.size():
		var stripped := String(lines[index]).strip_edges()
		var line_number := index + 1
		var method_name := _parse_public_method_name(stripped)
		if not method_name.is_empty():
			public_method_names[method_name] = true
			public_methods.append({
				"line": line_number,
				"name": method_name,
				"signature": stripped,
			})
			continue
		var signal_name := _parse_signal_name(stripped)
		if not signal_name.is_empty():
			signal_names[signal_name] = true
			signals.append({
				"line": line_number,
				"name": signal_name,
				"signature": stripped,
			})

	for required_method in REQUIRED_PUBLIC_METHODS:
		if not public_method_names.has(required_method):
			_errors.append("Missing required RiverManager public method: " + String(required_method))
	for required_signal in REQUIRED_SIGNALS:
		if not signal_names.has(required_signal):
			_errors.append("Missing required RiverManager signal: " + String(required_signal))

	_write_surface_file(
		out_dir.path_join("river_manager_public_methods.txt"),
		"R6_PUBLIC_METHOD_SURFACE_DUMP v1",
		"public_method_count",
		public_methods
	)
	_write_surface_file(
		out_dir.path_join("river_manager_signals.txt"),
		"R6_SIGNAL_SURFACE_DUMP v1",
		"signal_count",
		signals
	)


func _parse_public_method_name(stripped_line: String) -> String:
	var declaration := stripped_line
	if declaration.begins_with("static func "):
		declaration = declaration.trim_prefix("static ")
	if not declaration.begins_with("func "):
		return ""
	var after_func := declaration.trim_prefix("func ")
	var paren_index := after_func.find("(")
	if paren_index <= 0:
		return ""
	var method_name := after_func.substr(0, paren_index).strip_edges()
	if method_name.begins_with("_"):
		return ""
	return method_name


func _parse_signal_name(stripped_line: String) -> String:
	if not stripped_line.begins_with("signal "):
		return ""
	var after_signal := stripped_line.trim_prefix("signal ").strip_edges()
	var end_index := after_signal.length()
	var paren_index := after_signal.find("(")
	if paren_index >= 0:
		end_index = mini(end_index, paren_index)
	var space_index := after_signal.find(" ")
	if space_index >= 0:
		end_index = mini(end_index, space_index)
	return after_signal.substr(0, end_index).strip_edges()


func _write_surface_file(file_path: String, header: String, count_label: String, entries: Array) -> void:
	var lines := PackedStringArray()
	lines.append(header)
	lines.append("script=" + RIVER_MANAGER_SCRIPT_PATH)
	lines.append(count_label + "=" + str(entries.size()))
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		lines.append("line=" + str(entry.get("line", 0))
				+ " name=" + String(entry.get("name", ""))
				+ " signature=" + String(entry.get("signature", "")))
	_write_text_file(file_path, "\n".join(lines) + "\n")


func _dump_property_lists(out_dir: String) -> void:
	for target_variant in SCENE_TARGETS:
		var target: Dictionary = target_variant
		await _dump_scene_property_list(out_dir, target)


func _dump_scene_property_list(out_dir: String, target: Dictionary) -> void:
	var label := String(target.get("label", ""))
	var scene_path := String(target.get("path", ""))
	var river_path := String(target.get("river", DEFAULT_RIVER_PATH))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + scene_path)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		_errors.append("Could not find river " + river_path + " in " + scene_path)
	else:
		_write_property_list_file(
			out_dir.path_join(label + "__river_manager_property_list.txt"),
			label + " " + scene_path + " " + river_path,
			river.get_property_list()
		)

	scene.queue_free()
	await process_frame


func _write_property_list_file(file_path: String, target: String, property_list: Array) -> void:
	var lines := PackedStringArray()
	lines.append("R6_PROPERTY_LIST_DUMP v1")
	lines.append("target=" + target)
	lines.append("entry_count=" + str(property_list.size()))
	for index in property_list.size():
		lines.append(str(index) + " = " + _serialize_canonical_value(property_list[index]))
	_write_text_file(file_path, "\n".join(lines) + "\n")


func _canonicalize_value(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var sorted := {}
			var keys := source.keys()
			keys.sort_custom(_sort_variant_keys)
			for key in keys:
				sorted[key] = _canonicalize_value(source[key])
			return sorted
		TYPE_ARRAY:
			var sorted_array := []
			for item in value:
				sorted_array.append(_canonicalize_value(item))
			return sorted_array
		_:
			return value


func _serialize_canonical_value(value) -> String:
	var serialized := var_to_str(_canonicalize_value(value))
	return serialized.replace("\r\n", "\n").replace("\n", " ")


func _sort_variant_keys(a, b) -> bool:
	var a_string := str(a)
	var b_string := str(b)
	if a_string == b_string:
		return var_to_str(a) < var_to_str(b)
	return a_string < b_string


func _write_text_file(file_path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK:
		_errors.append("Could not create output parent " + parent + ": " + error_string(dir_error))
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write " + absolute_path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(text)
	file.close()
	_written_files.append(file_path)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args
