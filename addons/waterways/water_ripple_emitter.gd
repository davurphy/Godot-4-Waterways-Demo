@tool
@icon("res://addons/waterways/icons/ripple_emitter.svg")
class_name WaterRippleEmitter
extends Node3D

const MODE_PULSE := 0
const MODE_CONTINUOUS := 1
const MODE_ONE_SHOT := 2
const MODE_MOVING := 3
const DEFAULT_FIELD_GROUP := "water_ripple_fields"
const ONE_SHOT_MAX_ROUTE_RETRIES := 8
const WaterRippleEmitterPresetResource := preload("res://addons/waterways/resources/water_ripple_emitter_preset.gd")

@export_group("Routing")
@export var enabled := true:
	set(value):
		enabled = value
		if is_inside_tree():
			_sync_processing()
			update_configuration_warnings()
@export var target_field_path: NodePath:
	set(value):
		target_field_path = value
		_cached_field = null
		_one_shot_route_retries = 0
		_sync_processing()
		if is_inside_tree():
			update_configuration_warnings()
@export var field_group_name := DEFAULT_FIELD_GROUP:
	set(value):
		field_group_name = String(value)
		_cached_field = null
		_one_shot_route_retries = 0
		_sync_processing()
		if is_inside_tree():
			update_configuration_warnings()

@export_group("Shape")
@export_range(0.001, 64.0, 0.001) var radius := 1.75
@export_range(0.01, 8.0, 0.01) var falloff := 2.0

@export_group("Emission")
@export_enum("Pulse", "Continuous", "One Shot", "Moving") var emitter_mode := MODE_PULSE:
	set(value):
		var sanitized: int = clamp(int(value), MODE_PULSE, MODE_MOVING)
		if emitter_mode == sanitized:
			return
		emitter_mode = sanitized
		_pulse_accumulator = 0.0
		_one_shot_emitted = false
		_one_shot_route_retries = 0
		if is_inside_tree():
			_sync_processing()
			update_configuration_warnings()
@export_range(0.0, 1.0, 0.001) var intensity := 0.8
@export_range(0.01, 60.0, 0.01) var pulse_rate := 2.0
@export var emit_on_ready := false
@export_range(0.001, 64.0, 0.001) var moving_emit_distance := 0.75

@export_group("Priority And Caps")
@export_range(-1024, 1024, 1) var priority := 0

var _cached_field: Node
var _pulse_accumulator := 0.0
var _one_shot_emitted := false
var _last_emit_position := Vector3.ZERO
var _has_last_emit_position := false
var _emit_count := 0
var _rejected_count := 0
var _one_shot_route_retries := 0


func _ready() -> void:
	_last_emit_position = global_position
	_has_last_emit_position = true
	_sync_processing()
	if _should_run_runtime() and (emit_on_ready or emitter_mode == MODE_ONE_SHOT):
		call_deferred("emit_once")


func _process(delta: float) -> void:
	if not enabled or not _should_run_runtime():
		return
	match emitter_mode:
		MODE_ONE_SHOT:
			if not _one_shot_emitted:
				emit_once()
		MODE_CONTINUOUS:
			emit_once()
		MODE_MOVING:
			_process_moving(delta)
		_:
			_process_pulse(delta)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if enabled and target_field_path == NodePath("") and field_group_name.is_empty() and _get_ancestor_field() == null:
		warnings.append("Set a target field path, use a field group, or parent this emitter under a WaterRippleField.")
	if target_field_path != NodePath("") and not _is_valid_field(get_node_or_null(target_field_path)):
		warnings.append("Target field path '" + String(target_field_path) + "' does not resolve to a compatible WaterRippleField.")
	if not field_group_name.is_empty() and is_inside_tree():
		var has_group_field := false
		for candidate in get_tree().get_nodes_in_group(field_group_name):
			if _is_valid_field(candidate):
				has_group_field = true
				break
		if not has_group_field and target_field_path == NodePath("") and _get_ancestor_field() == null:
			warnings.append("Field group '" + field_group_name + "' currently has no compatible WaterRippleField nodes.")
	if radius <= 0.0:
		warnings.append("Emitter radius must be greater than zero.")
	if pulse_rate <= 0.0 and emitter_mode != MODE_ONE_SHOT:
		warnings.append("Emitter pulse_rate must be greater than zero for repeated modes.")
	if Engine.is_editor_hint() and enabled:
		warnings.append("Runtime ripple emitters queue impulses only while the scene runs; editor-time emission is intentionally disabled for this prototype.")
	return warnings


static func get_builtin_preset_names() -> PackedStringArray:
	return WaterRippleEmitterPresetResource.get_builtin_preset_names()


static func create_builtin_preset(preset_name: String) -> WaterRippleEmitterPresetResource:
	return WaterRippleEmitterPresetResource.create_builtin_preset(preset_name)


func apply_builtin_preset(preset_name: String) -> bool:
	var preset := create_builtin_preset(preset_name)
	if preset == null:
		return false
	return apply_preset(preset)


func apply_preset(preset: Resource) -> bool:
	if preset == null or not (preset is WaterRippleEmitterPresetResource):
		return false

	emitter_mode = clamp(int(preset.emitter_mode), MODE_PULSE, MODE_MOVING)
	radius = max(0.001, float(preset.radius))
	intensity = clamp(float(preset.intensity), 0.0, 1.0)
	falloff = max(0.01, float(preset.falloff))
	pulse_rate = max(0.01, float(preset.pulse_rate))
	emit_on_ready = bool(preset.emit_on_ready)
	moving_emit_distance = max(0.001, float(preset.moving_emit_distance))
	priority = int(preset.priority)

	if is_inside_tree():
		_sync_processing()
		update_configuration_warnings()
	return true


func capture_preset() -> WaterRippleEmitterPresetResource:
	var preset := WaterRippleEmitterPresetResource.new()
	preset.resource_name = "Captured Water Ripple Emitter Preset"
	preset.emitter_mode = emitter_mode
	preset.radius = radius
	preset.intensity = intensity
	preset.falloff = falloff
	preset.pulse_rate = pulse_rate
	preset.emit_on_ready = emit_on_ready
	preset.moving_emit_distance = moving_emit_distance
	preset.priority = priority
	return preset


func emit_once() -> bool:
	if not enabled or not _should_run_runtime():
		return false
	var field := _resolve_field()
	if field == null:
		_rejected_count += 1
		if emitter_mode == MODE_ONE_SHOT:
			_one_shot_route_retries += 1
			if _one_shot_route_retries >= ONE_SHOT_MAX_ROUTE_RETRIES:
				_one_shot_emitted = true
				_sync_processing()
		return false
	var accepted := bool(field.call("queue_impulse_world", global_position, radius, intensity, falloff, priority, self))
	if accepted:
		_emit_count += 1
		_one_shot_emitted = true
		_one_shot_route_retries = 0
		_last_emit_position = global_position
		_has_last_emit_position = true
		if emitter_mode == MODE_ONE_SHOT:
			_sync_processing()
	else:
		_rejected_count += 1
	return accepted


func get_emitter_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"mode": emitter_mode,
		"emit_count": _emit_count,
		"rejected_count": _rejected_count,
		"one_shot_route_retries": _one_shot_route_retries,
		"has_cached_field": _cached_field != null and is_instance_valid(_cached_field),
		"target_field_path": target_field_path,
		"field_group_name": field_group_name,
		"radius": radius,
		"intensity": intensity,
		"falloff": falloff,
		"priority": priority,
	}


func _process_pulse(delta: float) -> void:
	var interval: float = 1.0 / max(pulse_rate, 0.01)
	_pulse_accumulator += delta
	while _pulse_accumulator >= interval:
		_pulse_accumulator -= interval
		emit_once()


func _process_moving(delta: float) -> void:
	var interval: float = 1.0 / max(pulse_rate, 0.01)
	_pulse_accumulator += delta
	if not _has_last_emit_position:
		_last_emit_position = global_position
		_has_last_emit_position = true
	var moved_far_enough := global_position.distance_to(_last_emit_position) >= moving_emit_distance
	if moved_far_enough and _pulse_accumulator >= interval:
		_pulse_accumulator = 0.0
		emit_once()


func _resolve_field() -> Node:
	if _cached_field != null and is_instance_valid(_cached_field):
		return _cached_field
	if target_field_path != NodePath(""):
		var by_path := get_node_or_null(target_field_path)
		if _is_valid_field(by_path):
			_cached_field = by_path
			return _cached_field

	var ancestor := _get_ancestor_field()
	if ancestor != null:
		_cached_field = ancestor
		return _cached_field

	if not field_group_name.is_empty() and is_inside_tree():
		for candidate in get_tree().get_nodes_in_group(field_group_name):
			if _is_valid_field(candidate):
				_cached_field = candidate
				return _cached_field
	return null


func _is_valid_field(candidate: Variant) -> bool:
	return candidate is Node and candidate.has_method("queue_impulse_world")


func _get_ancestor_field() -> Node:
	var ancestor := get_parent()
	while ancestor != null:
		if _is_valid_field(ancestor):
			return ancestor
		ancestor = ancestor.get_parent()
	return null


func _sync_processing() -> void:
	var should_process := enabled and _should_run_runtime()
	if emitter_mode == MODE_ONE_SHOT and _one_shot_emitted:
		should_process = false
	set_process(should_process)


func _should_run_runtime() -> bool:
	return not Engine.is_editor_hint()
