@tool
extends RefCounted

const WaterRippleFieldScript = preload("res://addons/waterways/water_ripple_field.gd")
const WaterRippleEmitterScript = preload("res://addons/waterways/water_ripple_emitter.gd")
const WaterRippleFieldPresetResource = preload("res://addons/waterways/resources/water_ripple_field_preset.gd")
const WaterRippleEmitterPresetResource = preload("res://addons/waterways/resources/water_ripple_emitter_preset.gd")

const FIELD_PRESET_PROPERTIES := [
	"resolution",
	"simulation_update_rate",
	"damping",
	"propagation",
	"max_emitters",
	"ripple_strength",
	"normal_strength",
	"height_fade_distance",
	"boundary_fade",
	"auto_generate_boundary_mask",
	"require_boundary_mask",
]

const EMITTER_PRESET_PROPERTIES := [
	"emitter_mode",
	"radius",
	"intensity",
	"falloff",
	"pulse_rate",
	"emit_on_ready",
	"moving_emit_distance",
	"priority",
]


func can_apply_preset(object: Object, preset: Resource) -> bool:
	return (
			(object is WaterRippleFieldScript and preset is WaterRippleFieldPresetResource)
			or (object is WaterRippleEmitterScript and preset is WaterRippleEmitterPresetResource)
	)


func get_resource_base_type_for_node(object: Object) -> String:
	if object is WaterRippleFieldScript:
		return "WaterRippleFieldPreset"
	if object is WaterRippleEmitterScript:
		return "WaterRippleEmitterPreset"
	return "Resource"


func get_builtin_preset_names_for_node(object: Object) -> PackedStringArray:
	if object is WaterRippleFieldScript:
		return WaterRippleFieldPresetResource.get_builtin_preset_names()
	if object is WaterRippleEmitterScript:
		return WaterRippleEmitterPresetResource.get_builtin_preset_names()
	return PackedStringArray()


func get_builtin_preset_name_matching_node(object: Object) -> String:
	for preset_name in get_builtin_preset_names_for_node(object):
		var preset := create_builtin_preset_for_node(object, String(preset_name))
		if preset == null:
			continue
		if node_matches_property_values(object, build_sanitized_property_values(object, preset)):
			return String(preset_name)
	return ""


func create_builtin_preset_for_node(object: Object, preset_name: String) -> Resource:
	if object is WaterRippleFieldScript:
		return WaterRippleFieldPresetResource.create_builtin_preset(preset_name)
	if object is WaterRippleEmitterScript:
		return WaterRippleEmitterPresetResource.create_builtin_preset(preset_name)
	return null


func get_apply_action_name(object: Object) -> String:
	if object is WaterRippleFieldScript:
		return "Apply Water Ripple Field Preset"
	if object is WaterRippleEmitterScript:
		return "Apply Water Ripple Emitter Preset"
	return "Apply Water Ripple Preset"


func build_property_changes(object: Object, preset: Resource) -> Array:
	var next_values := build_sanitized_property_values(object, preset)
	var property_names := get_property_names_for_node(object)
	var changes := []
	for property_name in property_names:
		if not next_values.has(property_name):
			continue
		var old_value = object.get(property_name)
		var new_value = next_values[property_name]
		if _values_equal(old_value, new_value):
			continue
		changes.append({
			"property": property_name,
			"old_value": old_value,
			"new_value": new_value,
		})
	return changes


func node_matches_property_values(object: Object, property_values: Dictionary) -> bool:
	for property_name in get_property_names_for_node(object):
		if not property_values.has(property_name):
			return false
		if _values_equal(object.get(property_name), property_values[property_name]):
			continue
		return false
	return true


func build_sanitized_property_values(object: Object, preset: Resource) -> Dictionary:
	if object is WaterRippleFieldScript and preset is WaterRippleFieldPresetResource:
		return {
			"resolution": max(2, int(preset.resolution)),
			"simulation_update_rate": max(1.0, float(preset.simulation_update_rate)),
			"damping": clamp(float(preset.damping), 0.0, 1.0),
			"propagation": clamp(float(preset.propagation), 0.0, 2.0),
			"max_emitters": max(1, int(preset.max_emitters)),
			"ripple_strength": max(0.0, float(preset.ripple_strength)),
			"normal_strength": max(0.0, float(preset.normal_strength)),
			"height_fade_distance": max(0.0, float(preset.height_fade_distance)),
			"boundary_fade": clamp(float(preset.boundary_fade), 0.0, 0.25),
			"auto_generate_boundary_mask": bool(preset.auto_generate_boundary_mask),
			"require_boundary_mask": bool(preset.require_boundary_mask),
		}
	if object is WaterRippleEmitterScript and preset is WaterRippleEmitterPresetResource:
		return {
			"emitter_mode": clamp(int(preset.emitter_mode), WaterRippleEmitterPresetResource.MODE_PULSE, WaterRippleEmitterPresetResource.MODE_MOVING),
			"radius": max(0.001, float(preset.radius)),
			"intensity": clamp(float(preset.intensity), 0.0, 1.0),
			"falloff": max(0.01, float(preset.falloff)),
			"pulse_rate": max(0.01, float(preset.pulse_rate)),
			"emit_on_ready": bool(preset.emit_on_ready),
			"moving_emit_distance": max(0.001, float(preset.moving_emit_distance)),
			"priority": int(preset.priority),
		}
	return {}


func get_property_names_for_node(object: Object) -> Array:
	if object is WaterRippleFieldScript:
		return FIELD_PRESET_PROPERTIES.duplicate()
	if object is WaterRippleEmitterScript:
		return EMITTER_PRESET_PROPERTIES.duplicate()
	return []


func _values_equal(left, right) -> bool:
	if typeof(left) == TYPE_FLOAT or typeof(right) == TYPE_FLOAT:
		return is_equal_approx(float(left), float(right))
	return left == right
