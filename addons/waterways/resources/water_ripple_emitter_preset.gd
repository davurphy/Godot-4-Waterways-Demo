@tool
extends Resource
class_name WaterRippleEmitterPreset

const MODE_PULSE := 0
const MODE_CONTINUOUS := 1
const MODE_ONE_SHOT := 2
const MODE_MOVING := 3

const PRESET_FOOTSTEP := "Footstep"
const PRESET_WADING_CHARACTER := "Wading Character"
const PRESET_NPC_AMBIENT := "NPC Ambient"
const PRESET_SMALL_IMPACT := "Small Impact"
const PRESET_HEAVY_IMPACT := "Heavy Impact"
const PRESET_LIGHT_RAIN_DROP := "Light Rain Drop"
const PRESET_STATIC_RIVER_DISTURBANCE := "Static River Disturbance"

@export_group("Emission")
@export_enum("Pulse", "Continuous", "One Shot", "Moving") var emitter_mode := MODE_PULSE
@export_range(0.0, 1.0, 0.001) var intensity := 0.8
@export_range(0.01, 60.0, 0.01) var pulse_rate := 2.0
@export var emit_on_ready := false
@export_range(0.001, 64.0, 0.001) var moving_emit_distance := 0.75

@export_group("Shape")
@export_range(0.001, 64.0, 0.001) var radius := 1.75
@export_range(0.01, 8.0, 0.01) var falloff := 2.0

@export_group("Priority And Caps")
@export_range(-1024, 1024, 1) var priority := 0


static func get_builtin_preset_names() -> PackedStringArray:
	return PackedStringArray([
		PRESET_FOOTSTEP,
		PRESET_WADING_CHARACTER,
		PRESET_NPC_AMBIENT,
		PRESET_SMALL_IMPACT,
		PRESET_HEAVY_IMPACT,
		PRESET_LIGHT_RAIN_DROP,
		PRESET_STATIC_RIVER_DISTURBANCE,
	])


static func create_builtin_preset(preset_name: String) -> WaterRippleEmitterPreset:
	match preset_name:
		PRESET_FOOTSTEP:
			return _make_preset(preset_name, MODE_ONE_SHOT, 0.55, 0.75, 2.5, 1.0, false, 0.5, 10)
		PRESET_WADING_CHARACTER:
			return _make_preset(preset_name, MODE_MOVING, 1.3, 0.65, 2.0, 10.0, false, 0.18, 8)
		PRESET_NPC_AMBIENT:
			return _make_preset(preset_name, MODE_PULSE, 1.1, 0.25, 2.5, 0.8, false, 0.75, -2)
		PRESET_SMALL_IMPACT:
			return _make_preset(preset_name, MODE_ONE_SHOT, 1.25, 0.75, 2.0, 1.0, false, 0.75, 15)
		PRESET_HEAVY_IMPACT:
			return _make_preset(preset_name, MODE_ONE_SHOT, 3.0, 1.0, 1.6, 1.0, false, 1.25, 30)
		PRESET_LIGHT_RAIN_DROP:
			return _make_preset(preset_name, MODE_PULSE, 0.25, 0.18, 3.0, 4.0, false, 0.75, -10)
		PRESET_STATIC_RIVER_DISTURBANCE:
			return _make_preset(preset_name, MODE_CONTINUOUS, 0.9, 0.22, 2.0, 3.0, false, 0.75, -4)
	return null


static func has_builtin_preset(preset_name: String) -> bool:
	return get_builtin_preset_names().has(preset_name)


static func _make_preset(
		preset_name: String,
		preset_emitter_mode: int,
		preset_radius: float,
		preset_intensity: float,
		preset_falloff: float,
		preset_pulse_rate: float,
		preset_emit_on_ready: bool,
		preset_moving_emit_distance: float,
		preset_priority: int) -> WaterRippleEmitterPreset:
	var preset := WaterRippleEmitterPreset.new()
	preset.resource_name = preset_name
	preset.emitter_mode = preset_emitter_mode
	preset.radius = preset_radius
	preset.intensity = preset_intensity
	preset.falloff = preset_falloff
	preset.pulse_rate = preset_pulse_rate
	preset.emit_on_ready = preset_emit_on_ready
	preset.moving_emit_distance = preset_moving_emit_distance
	preset.priority = preset_priority
	return preset
