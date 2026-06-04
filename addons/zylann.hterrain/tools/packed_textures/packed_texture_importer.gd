@tool
extends EditorImportPlugin

const HT_Logger = preload("../../util/logger.gd")

const IMPORTER_NAME = "hterrain_packed_texture_importer"
const RESOURCE_TYPE = "CompressedTexture2D"

var _logger = HT_Logger.get_for(self)


func _get_importer_name() -> String:
	return IMPORTER_NAME


func _get_visible_name() -> String:
	return "HTerrainPackedTexture"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["packed_tex"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return RESOURCE_TYPE


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return ""


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	return options


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return false


func _import(
	source_file: String,
	_save_path: String,
	_options: Dictionary,
	_platform_variants: Array[String],
	_gen_files: Array[String]
) -> Error:
	_logger.error("HTerrain .packed_tex import is unavailable in this Godot 4 project: {0}".format([source_file]))
	return ERR_UNAVAILABLE
