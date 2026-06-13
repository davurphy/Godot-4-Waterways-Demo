# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Resource
class_name WaterSystemBakeData

const DEFAULT_CHANNEL_METADATA := {
	"system_map": {
		"r": "world_flow_x_packed_0_to_1_neutral_0_5",
		"g": "world_flow_z_packed_0_to_1_neutral_0_5",
		"b": "normalized_height_within_world_bounds",
		"a": "coverage_mask_0_outside_1_valid_water"
	}
}

const DEFAULT_IMPORT_PROFILE := {
	"color_space": "linear",
	"srgb": false,
	"compression": "uncompressed_or_lossless",
	"mipmaps": false,
	"neutral_flow": Vector2(0.5, 0.5)
}

const SOURCE_KIND_WATER_SYSTEM_COMBINE := "generated_water_system_combine"
const SOURCE_RIVER_METADATA_VERSION := 1
# Version of the system_flow.gdshader output baked into system_map, stored in
# bake_settings as "system_flow_map_version". System maps have no bake-source
# signature like river bakes do, so this int is their only staleness signal
# for shader-output changes. Bump it whenever system_flow.gdshader's output
# changes for identical inputs. Comparator rule (2026-06-12): compare stable
# values like this int, never resource path strings.
# v1 (2026-06-12, river-refactor R2): projected-flow fix - the boundary slide
# is skipped for pressure-projected rivers and gained the stagnation fade;
# maps saved before v1 carry re-bent flow and must be regenerated.
const SYSTEM_FLOW_MAP_VERSION := 1

@export var system_map: Texture2D:
	set(value):
		system_map = value
		refresh_sampling_image()
@export var texture_size := Vector2i.ZERO
@export var world_bounds := AABB()
@export var world_to_map := Transform3D.IDENTITY
@export var capture_rect := Rect2()
@export var source_river_paths := PackedStringArray()
@export var source_river_metadata_version := 0
@export var source_river_metadata: Array = []
@export var source_kind := SOURCE_KIND_WATER_SYSTEM_COMBINE
@export var source_metadata: Dictionary = {}
@export var channel_metadata: Dictionary = {}
@export var import_profile: Dictionary = {}
@export var bake_settings: Dictionary = {}

var _sampling_image: Image


func _init() -> void:
	if channel_metadata.is_empty():
		channel_metadata = DEFAULT_CHANNEL_METADATA.duplicate(true)
	if import_profile.is_empty():
		import_profile = DEFAULT_IMPORT_PROFILE.duplicate(true)


func set_from_bake(
		new_system_map: Texture2D,
		new_texture_size: Vector2i,
		new_world_bounds: AABB,
		new_source_river_paths: PackedStringArray,
		new_bake_settings: Dictionary,
		new_source_kind: String,
		new_source_metadata: Dictionary,
		new_source_river_metadata: Array = []
) -> void:
	system_map = new_system_map
	texture_size = new_texture_size
	world_bounds = new_world_bounds
	capture_rect = build_capture_rect(new_world_bounds)
	world_to_map = build_world_to_map(new_world_bounds)
	source_river_paths = new_source_river_paths
	source_river_metadata_version = SOURCE_RIVER_METADATA_VERSION
	source_river_metadata = new_source_river_metadata.duplicate(true)
	source_kind = new_source_kind
	source_metadata = new_source_metadata.duplicate(true)
	bake_settings = new_bake_settings.duplicate(true)
	channel_metadata = DEFAULT_CHANNEL_METADATA.duplicate(true)
	import_profile = DEFAULT_IMPORT_PROFILE.duplicate(true)
	refresh_sampling_image()


func has_required_texture() -> bool:
	return system_map != null


func refresh_sampling_image() -> void:
	if system_map == null:
		_sampling_image = null
		return
	_sampling_image = system_map.get_image()


func get_sampling_image() -> Image:
	if _sampling_image == null and system_map != null:
		refresh_sampling_image()
	return _sampling_image


func world_position_to_map_position(world_position: Vector3) -> Vector3:
	return world_to_map * world_position


static func build_world_to_map(bounds: AABB) -> Transform3D:
	var capture := build_capture_rect(bounds)
	var x_size := capture.size.x
	if is_zero_approx(x_size):
		x_size = 1.0
	var z_size := capture.size.y
	if is_zero_approx(z_size):
		z_size = 1.0
	var height_size := bounds.size.y
	if is_zero_approx(height_size):
		height_size = 1.0
	var basis := Basis(
		Vector3(1.0 / x_size, 0.0, 0.0),
		Vector3(0.0, 1.0 / height_size, 0.0),
		Vector3(0.0, 0.0, 1.0 / z_size)
	)
	var capture_origin := Vector3(capture.position.x, bounds.position.y, capture.position.y)
	return Transform3D(basis, basis * -capture_origin)


static func build_capture_rect(bounds: AABB) -> Rect2:
	return Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
