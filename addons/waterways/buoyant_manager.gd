# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Node3D

const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")

const DAMPING_OWNERSHIP_EPSILON := 0.0001


@export var water_system_group_name: String = "waterways_system":
	set(value):
		water_system_group_name = String(value).strip_edges()
		_system = null
@export_range(0.0, 200.0) var buoyancy_force := 50.0
@export_range(0.0, 20.0) var up_correcting_force := 5.0
@export_range(0.0, 200.0) var flow_force := 50.0
@export_range(0.0, 30.0) var water_resistance := 5.0

var _rb : RigidBody3D
var _system : WaterSystem
var _restore_linear_damp := 0.0
var _restore_angular_damp := 0.0
var _last_linear_damp_written := 0.0
var _last_angular_damp_written := 0.0
var _owns_linear_damp := false
var _owns_angular_damp := false
var _is_submerged := false


func _enter_tree() -> void:
	_refresh_body_reference()


func _exit_tree() -> void:
	_restore_default_damping()
	_clear_damping_ownership()
	_rb = null
	_system = null


func _ready() -> void:
	_refresh_body_reference()
	_refresh_system_reference()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _rb == null:
		warnings.append("Buoyant node must be a direct child of a RigidBody3D to function.")
	if water_system_group_name.is_empty():
		warnings.append("Water system group name is empty; this Buoyant cannot find a WaterSystem.")
	return warnings


func _get_rotation_correction() -> Vector3:
	var up_vector := global_transform.basis.y
	if up_vector.length_squared() <= 0.000001:
		return Vector3.ZERO
	up_vector = up_vector.normalized()
	var angle := up_vector.angle_to(Vector3.UP)
	if angle < 0.1:
		# Very small angles make the correction axis noisy and are not worth nudging.
		return Vector3.ZERO
	var correction_axis := up_vector.cross(Vector3.UP)
	if correction_axis.length_squared() <= 0.000001:
		correction_axis = global_transform.basis.x
		if correction_axis.length_squared() <= 0.000001:
			correction_axis = Vector3.FORWARD
	return correction_axis.normalized() * angle


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() || _rb == null:
		return
	if not _has_valid_system_reference():
		_refresh_system_reference()
	if _system == null:
		_restore_default_damping()
		return
	var altitude = _system.get_water_altitude(global_transform.origin)
	if altitude < 0.0:
		var flow = _system.get_water_flow(global_transform.origin)
		var woke_body := _wake_body_for_water_force()
		_rb.apply_central_force(Vector3.UP * buoyancy_force * -altitude)
		var rot = _get_rotation_correction()
		_rb.apply_torque(rot * up_correcting_force)
		_rb.apply_central_force(flow * flow_force)
		if not woke_body:
			_apply_water_damping()
	else:
		_restore_default_damping()


func _refresh_body_reference() -> void:
	var parent = get_parent()
	var body: RigidBody3D = null
	if parent is RigidBody3D:
		body = parent as RigidBody3D
	if body == _rb:
		return
	_restore_default_damping()
	_clear_damping_ownership()
	_rb = body
	update_configuration_warnings()


func _refresh_system_reference() -> void:
	_system = null
	if not is_inside_tree() or water_system_group_name.is_empty():
		return
	var closest_system: WaterSystem = null
	var closest_distance := INF
	for node in get_tree().get_nodes_in_group(water_system_group_name):
		if not (node is WaterSystem):
			continue
		var candidate := node as WaterSystem
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_system = candidate
	_system = closest_system


func _has_valid_system_reference() -> bool:
	return (
		_system != null
		and is_instance_valid(_system)
		and _system.is_inside_tree()
		and _system.is_in_group(water_system_group_name)
	)


func _restore_default_damping() -> void:
	if _rb == null:
		_clear_damping_ownership()
		return
	if _owns_linear_damp:
		if _damping_matches(_rb.linear_damp, _last_linear_damp_written):
			_rb.linear_damp = _restore_linear_damp
		_owns_linear_damp = false
	if _owns_angular_damp:
		if _damping_matches(_rb.angular_damp, _last_angular_damp_written):
			_rb.angular_damp = _restore_angular_damp
		_owns_angular_damp = false
	_is_submerged = false


func _apply_water_damping() -> void:
	if _rb == null:
		_clear_damping_ownership()
		return
	if not _is_submerged:
		_is_submerged = true
		_claim_damping_ownership()
	_apply_linear_water_damping()
	_apply_angular_water_damping()


func _claim_damping_ownership() -> void:
	# Capture damping at water entry, then restore only while these values remain ours.
	_restore_linear_damp = _rb.linear_damp
	_restore_angular_damp = _rb.angular_damp
	_last_linear_damp_written = _rb.linear_damp
	_last_angular_damp_written = _rb.angular_damp
	_owns_linear_damp = true
	_owns_angular_damp = true


func _apply_linear_water_damping() -> void:
	if not _owns_linear_damp:
		return
	if not _damping_matches(_rb.linear_damp, _last_linear_damp_written):
		_owns_linear_damp = false
		return
	if not _damping_matches(_rb.linear_damp, water_resistance):
		_rb.linear_damp = water_resistance
		_last_linear_damp_written = water_resistance


func _apply_angular_water_damping() -> void:
	if not _owns_angular_damp:
		return
	if not _damping_matches(_rb.angular_damp, _last_angular_damp_written):
		_owns_angular_damp = false
		return
	if not _damping_matches(_rb.angular_damp, water_resistance):
		_rb.angular_damp = water_resistance
		_last_angular_damp_written = water_resistance


func _wake_body_for_water_force() -> bool:
	var was_sleeping := _rb.sleeping
	_rb.sleeping = false
	return was_sleeping


func _clear_damping_ownership() -> void:
	_owns_linear_damp = false
	_owns_angular_damp = false
	_is_submerged = false


func _damping_matches(a: float, b: float) -> bool:
	return absf(a - b) <= DAMPING_OWNERSHIP_EPSILON
