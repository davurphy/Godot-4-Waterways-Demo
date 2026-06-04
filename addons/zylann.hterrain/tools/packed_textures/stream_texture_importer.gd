@tool

const Result = preload("../util/result.gd")

const COMPRESS_LOSSLESS = 0
const COMPRESS_LOSSY = 1
const COMPRESS_VIDEO_RAM = 2
const COMPRESS_UNCOMPRESSED = 3

const COMPRESS_HINT_STRING = "Lossless,Lossy,VRAM,Uncompressed"

const REPEAT_NONE = 0
const REPEAT_ENABLED = 1
const REPEAT_MIRRORED = 2

const REPEAT_HINT_STRING = "None,Enabled,Mirrored"


static func import(
	p_source_path: String,
	_image: Image,
	_p_save_path: String,
	_r_platform_variants: Array[String],
	_r_gen_files: Array[String],
	_p_contains_albedo: bool,
	_importer_name: String,
	_p_compress_mode: int,
	_p_repeat: int,
	_p_filter: bool,
	_p_mipmaps: bool
) -> Result:
	return Result.new(
		false,
		"HTerrain legacy packed texture import is unavailable in this Godot 4 project: {0}".format([p_source_path])
	).with_value(ERR_UNAVAILABLE)
