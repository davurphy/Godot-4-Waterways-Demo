# River-refactor R6.2 constants table shadow probe (headless OK).
#
# Compares old source_metadata, source_signature, and bake_settings dictionaries
# against table-generated dictionaries without switching the live bake path.
#
# Run:
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/r6_constants_shadow_probe.gd
#
# Success marker: R6_R62_CONSTANTS_SHADOW_OK
extends SceneTree

const RiverBakeConstants = preload("res://addons/waterways/river_bake_constants.gd")

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

var _errors := PackedStringArray()
var _comparison_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_table()
	_compare_saved_bake_dictionaries()
	await _compare_live_scene_signatures()

	if _errors.is_empty():
		print("R6_R62_CONSTANTS_SHADOW_OK comparisons=", _comparison_count, " rows=", RiverBakeConstants.get_constant_rows().size(), " signature_version=", RiverBakeConstants.RIVER_BAKE_SOURCE_SIGNATURE_VERSION)
		quit(0)
		return

	for error in _errors:
		push_error(error)
	quit(1)


func _validate_table() -> void:
	for error in RiverBakeConstants.validate_rows():
		_errors.append(error)


func _compare_saved_bake_dictionaries() -> void:
	for target_variant in BAKE_TARGETS:
		var target: Dictionary = target_variant
		var label := String(target.get("label", ""))
		var bake_path := String(target.get("path", ""))
		var bake := load(bake_path) as Resource
		if bake == null:
			_errors.append("Could not load bake resource: " + bake_path)
			continue
		_compare_dictionary(
			label + " saved " + bake_path,
			RiverBakeConstants.SECTION_SOURCE_METADATA,
			_get_bake_dictionary(bake, "source_metadata"),
			RiverBakeConstants.build_source_metadata(_extract_dynamic_values(RiverBakeConstants.SECTION_SOURCE_METADATA, _get_bake_dictionary(bake, "source_metadata")))
		)
		_compare_dictionary(
			label + " saved " + bake_path,
			RiverBakeConstants.SECTION_SOURCE_SIGNATURE,
			_get_bake_dictionary(bake, "source_signature"),
			RiverBakeConstants.build_source_signature(_extract_dynamic_values(RiverBakeConstants.SECTION_SOURCE_SIGNATURE, _get_bake_dictionary(bake, "source_signature")))
		)
		_compare_dictionary(
			label + " saved " + bake_path,
			RiverBakeConstants.SECTION_BAKE_SETTINGS,
			_get_bake_dictionary(bake, "bake_settings"),
			RiverBakeConstants.build_bake_settings(_extract_dynamic_values(RiverBakeConstants.SECTION_BAKE_SETTINGS, _get_bake_dictionary(bake, "bake_settings")))
		)


func _get_bake_dictionary(bake: Resource, property_name: String) -> Dictionary:
	var value = bake.get(property_name)
	if typeof(value) != TYPE_DICTIONARY:
		_errors.append("Bake " + str(bake.resource_path) + " property " + property_name + " is not a Dictionary.")
		return {}
	return (value as Dictionary).duplicate(true)


func _compare_live_scene_signatures() -> void:
	for target_variant in SCENE_TARGETS:
		var target: Dictionary = target_variant
		await _compare_live_scene_signature(target)


func _compare_live_scene_signature(target: Dictionary) -> void:
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
		var old_signature: Dictionary = river.call("get_bake_source_signature")
		_compare_dictionary(
			label + " live " + scene_path + " " + river_path,
			RiverBakeConstants.SECTION_SOURCE_SIGNATURE,
			old_signature,
			RiverBakeConstants.build_source_signature(_extract_dynamic_values(RiverBakeConstants.SECTION_SOURCE_SIGNATURE, old_signature))
		)

	scene.queue_free()
	await process_frame


func _extract_dynamic_values(section: String, source: Dictionary) -> Dictionary:
	var dynamic_values := {}
	var dynamic_keys := _array_to_lookup(RiverBakeConstants.get_dynamic_keys(section))
	var table_keys := RiverBakeConstants.get_section_keys(section)

	for key in source.keys():
		var key_string := String(key)
		if dynamic_keys.has(key_string):
			dynamic_values[key] = _duplicate_value(source[key])
		elif not table_keys.has(key_string):
			_errors.append("Dictionary key is neither dynamic nor constants-table covered: " + section + "." + key_string)

	return dynamic_values


func _compare_dictionary(target: String, section: String, old_dictionary: Dictionary, table_dictionary: Dictionary) -> void:
	var old_filtered := _filter_for_section(section, old_dictionary)
	var table_filtered := _filter_for_section(section, table_dictionary)
	var old_lines := _canonical_lines(section, target, old_filtered)
	var table_lines := _canonical_lines(section, target, table_filtered)
	_comparison_count += 1
	if old_lines == table_lines:
		return

	var max_lines := maxi(old_lines.size(), table_lines.size())
	for index in max_lines:
		var old_line := old_lines[index] if index < old_lines.size() else "<missing>"
		var table_line := table_lines[index] if index < table_lines.size() else "<missing>"
		if old_line != table_line:
			_errors.append("Constants shadow mismatch in " + section + " for " + target + " at canonical line " + str(index + 1) + ": old=" + old_line + " table=" + table_line)
			return
	_errors.append("Constants shadow mismatch in " + section + " for " + target + ".")


func _filter_for_section(section: String, source: Dictionary) -> Dictionary:
	var filtered := source.duplicate(true)
	if section == RiverBakeConstants.SECTION_SOURCE_METADATA:
		for key in DYNAMIC_METADATA_ALLOW_LIST.keys():
			filtered.erase(key)
	return filtered


func _canonical_lines(section: String, target: String, source: Dictionary) -> PackedStringArray:
	var keys := source.keys()
	keys.sort_custom(_sort_variant_keys)
	var lines := PackedStringArray()
	lines.append("R6_CANONICAL_DUMP v1")
	lines.append("section=" + section)
	lines.append("target=" + target)
	lines.append("key_count=" + str(keys.size()))
	for key in keys:
		lines.append(str(key) + " = " + _serialize_canonical_value(source[key]))
	return lines


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


func _array_to_lookup(values: Array) -> Dictionary:
	var lookup := {}
	for value in values:
		lookup[String(value)] = true
	return lookup


func _duplicate_value(value):
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(value)
		_:
			return value
