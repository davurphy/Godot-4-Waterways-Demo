@tool
extends Node3D

const MODE_PULSE := 0
const MODE_CONTINUOUS := 1
const MODE_ONE_SHOT := 2
const MODE_MOVING := 3
const DEFAULT_FIELD_GROUP := "water_ripple_fields"

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
		if is_inside_tree():
			update_configuration_warnings()
@export var field_group_name := DEFAULT_FIELD_GROUP
@export_enum("Pulse", "Continuous", "One Shot", "Moving") var emitter_mode := MODE_PULSE
@export_range(0.001, 64.0, 0.001) var radius := 1.75
@export_range(0.0, 1.0, 0.001) var intensity := 0.8
@export_range(0.01, 8.0, 0.01) var falloff := 2.0
@export_range(0.01, 60.0, 0.01) var pulse_rate := 2.0
@export var emit_on_ready := false
@export_range(0.001, 64.0, 0.001) var moving_emit_distance := 0.75
@export_range(-1024, 1024, 1) var priority := 0

var _cached_field: Node
var _pulse_accumulator := 0.0
var _one_shot_emitted := false
var _last_emit_position := Vector3.ZERO
var _has_last_emit_position := false
var _emit_count := 0
var _rejected_count := 0


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
		MODE_MOVING:
			_process_moving(delta)
		_:
			_process_pulse(delta)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if enabled and target_field_path == NodePath("") and field_group_name.is_empty():
		warnings.append("Emitter has no target field path or field group; it will only find a WaterRippleField ancestor.")
	if radius <= 0.0:
		warnings.append("Emitter radius must be greater than zero.")
	if pulse_rate <= 0.0 and emitter_mode != MODE_ONE_SHOT:
		warnings.append("Emitter pulse_rate must be greater than zero for repeated modes.")
	if Engine.is_editor_hint() and enabled:
		warnings.append("Runtime ripple emitters queue impulses only while the scene runs; editor-time emission is intentionally disabled for this prototype.")
	return warnings


func emit_once() -> bool:
	if not enabled or not _should_run_runtime():
		return false
	var field := _resolve_field()
	if field == null:
		_rejected_count += 1
		return false
	var accepted := bool(field.call("queue_impulse_world", global_position, radius, intensity, falloff, priority, self))
	if accepted:
		_emit_count += 1
		_one_shot_emitted = true
		_last_emit_position = global_position
		_has_last_emit_position = true
	else:
		_rejected_count += 1
	return accepted


func get_emitter_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"mode": emitter_mode,
		"emit_count": _emit_count,
		"rejected_count": _rejected_count,
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

	var ancestor := get_parent()
	while ancestor != null:
		if _is_valid_field(ancestor):
			_cached_field = ancestor
			return _cached_field
		ancestor = ancestor.get_parent()

	if not field_group_name.is_empty() and is_inside_tree():
		for candidate in get_tree().get_nodes_in_group(field_group_name):
			if _is_valid_field(candidate):
				_cached_field = candidate
				return _cached_field
	return null


func _is_valid_field(candidate: Variant) -> bool:
	return candidate is Node and candidate.has_method("queue_impulse_world")


func _sync_processing() -> void:
	set_process(enabled and _should_run_runtime())


func _should_run_runtime() -> bool:
	return not Engine.is_editor_hint()
