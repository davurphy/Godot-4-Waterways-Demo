@tool
extends Resource
class_name WaterRippleFieldPreset

const PRESET_CALM_LOCAL_FIELD := "Calm Local Field"
const PRESET_CHARACTER_INTERACTION_FIELD := "Character Interaction Field"
const PRESET_RAIN_SIZED_LOCAL_FIELD := "Rain-Sized Local Field"
const PRESET_HEAVY_IMPACT_FIELD := "Heavy Impact Field"
const PRESET_PERFORMANCE_FIELD := "Performance Field"
const PRESET_DEBUG_STRONG_FIELD := "Debug Strong Field"

@export_group("Simulation")
@export_range(32, 1024, 1) var resolution := 256
@export_range(1.0, 120.0, 1.0) var simulation_update_rate := 60.0
@export_range(0.0, 1.0, 0.001) var damping := 0.985
@export_range(0.0, 2.0, 0.001) var propagation := 0.45
@export_range(1, 128, 1) var max_emitters := 16

@export_group("Visual Response")
@export_range(0.0, 4.0, 0.001) var ripple_strength := 1.0
@export_range(0.0, 8.0, 0.001) var normal_strength := 1.25
@export_range(0.0, 200.0, 0.1) var height_fade_distance := 0.0
@export_range(0.0, 0.25, 0.001) var boundary_fade := 0.025

@export_group("Boundary Mask")
@export var auto_generate_boundary_mask := true
@export var require_boundary_mask := true


static func get_builtin_preset_names() -> PackedStringArray:
	return PackedStringArray([
		PRESET_CALM_LOCAL_FIELD,
		PRESET_CHARACTER_INTERACTION_FIELD,
		PRESET_RAIN_SIZED_LOCAL_FIELD,
		PRESET_HEAVY_IMPACT_FIELD,
		PRESET_PERFORMANCE_FIELD,
		PRESET_DEBUG_STRONG_FIELD,
	])


static func create_builtin_preset(preset_name: String) -> WaterRippleFieldPreset:
	match preset_name:
		PRESET_CALM_LOCAL_FIELD:
			return _make_preset(preset_name, 256, 45.0, 0.992, 0.34, 8, 0.55, 0.75, 28.0, 0.035, true, true)
		PRESET_CHARACTER_INTERACTION_FIELD:
			return _make_preset(preset_name, 256, 60.0, 0.985, 0.45, 16, 1.0, 1.25, 24.0, 0.025, true, true)
		PRESET_RAIN_SIZED_LOCAL_FIELD:
			return _make_preset(preset_name, 256, 60.0, 0.975, 0.38, 48, 0.35, 0.85, 16.0, 0.02, true, true)
		PRESET_HEAVY_IMPACT_FIELD:
			return _make_preset(preset_name, 512, 60.0, 0.992, 0.6, 24, 1.8, 2.4, 35.0, 0.03, true, true)
		PRESET_PERFORMANCE_FIELD:
			return _make_preset(preset_name, 128, 30.0, 0.96, 0.38, 8, 0.65, 0.8, 18.0, 0.035, true, true)
		PRESET_DEBUG_STRONG_FIELD:
			return _make_preset(preset_name, 256, 60.0, 0.99, 0.55, 16, 2.25, 3.0, 40.0, 0.025, true, true)
	return null


static func has_builtin_preset(preset_name: String) -> bool:
	return get_builtin_preset_names().has(preset_name)


static func _make_preset(
		preset_name: String,
		preset_resolution: int,
		preset_update_rate: float,
		preset_damping: float,
		preset_propagation: float,
		preset_max_emitters: int,
		preset_ripple_strength: float,
		preset_normal_strength: float,
		preset_height_fade_distance: float,
		preset_boundary_fade: float,
		preset_auto_generate_boundary_mask: bool,
		preset_require_boundary_mask: bool) -> WaterRippleFieldPreset:
	var preset := WaterRippleFieldPreset.new()
	preset.resource_name = preset_name
	preset.resolution = preset_resolution
	preset.simulation_update_rate = preset_update_rate
	preset.damping = preset_damping
	preset.propagation = preset_propagation
	preset.max_emitters = preset_max_emitters
	preset.ripple_strength = preset_ripple_strength
	preset.normal_strength = preset_normal_strength
	preset.height_fade_distance = preset_height_fade_distance
	preset.boundary_fade = preset_boundary_fade
	preset.auto_generate_boundary_mask = preset_auto_generate_boundary_mask
	preset.require_boundary_mask = preset_require_boundary_mask
	return preset
