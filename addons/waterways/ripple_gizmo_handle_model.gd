@tool
extends RefCounted

const WaterRippleEmitterScript = preload("res://addons/waterways/water_ripple_emitter.gd")
const WaterRippleFieldScript = preload("res://addons/waterways/water_ripple_field.gd")

const HANDLE_EMITTER_RADIUS := 1001
const HANDLE_EMITTER_MOVING_DISTANCE := 1002
const HANDLE_FIELD_MIN_X := 2001
const HANDLE_FIELD_MAX_X := 2002
const HANDLE_FIELD_MIN_Y := 2003
const HANDLE_FIELD_MAX_Y := 2004
const HANDLE_FIELD_MIN_Z := 2005
const HANDLE_FIELD_MAX_Z := 2006
const MODE_MOVING := 3
const MIN_HANDLE_VALUE := 0.001
const MAX_HANDLE_VALUE := 64.0
const MIN_FIELD_BOUNDS_SIZE := 0.001
const MIN_PICKABLE_MOVING_HANDLE_DISTANCE := 0.75


static func can_edit_handle(node: Object, handle_id: int) -> bool:
	if node is WaterRippleFieldScript:
		return is_field_bounds_handle(handle_id)
	if node is WaterRippleEmitterScript:
		return is_emitter_handle(handle_id)
	return false


static func should_show_handle(node: Object, handle_id: int) -> bool:
	if not can_edit_handle(node, handle_id):
		return false
	if handle_id == HANDLE_EMITTER_MOVING_DISTANCE:
		return int(node.get("emitter_mode")) == MODE_MOVING
	return true


static func get_handle_ids_for_node(node: Object) -> PackedInt32Array:
	var ids := PackedInt32Array()
	if node is WaterRippleFieldScript:
		ids.append(HANDLE_FIELD_MIN_X)
		ids.append(HANDLE_FIELD_MAX_X)
		ids.append(HANDLE_FIELD_MIN_Y)
		ids.append(HANDLE_FIELD_MAX_Y)
		ids.append(HANDLE_FIELD_MIN_Z)
		ids.append(HANDLE_FIELD_MAX_Z)
	elif node is WaterRippleEmitterScript:
		ids.append(HANDLE_EMITTER_RADIUS)
		if int(node.get("emitter_mode")) == MODE_MOVING:
			ids.append(HANDLE_EMITTER_MOVING_DISTANCE)
	return ids


static func get_property_name(handle_id: int) -> StringName:
	match handle_id:
		HANDLE_EMITTER_RADIUS:
			return &"radius"
		HANDLE_EMITTER_MOVING_DISTANCE:
			return &"moving_emit_distance"
		HANDLE_FIELD_MIN_X, HANDLE_FIELD_MAX_X, HANDLE_FIELD_MIN_Y, HANDLE_FIELD_MAX_Y, HANDLE_FIELD_MIN_Z, HANDLE_FIELD_MAX_Z:
			return &"world_bounds"
		_:
			return StringName()


static func get_handle_name(handle_id: int) -> String:
	match handle_id:
		HANDLE_EMITTER_RADIUS:
			return "Emitter Radius"
		HANDLE_EMITTER_MOVING_DISTANCE:
			return "Moving Emit Distance"
		HANDLE_FIELD_MIN_X:
			return "Field Bounds Min X"
		HANDLE_FIELD_MAX_X:
			return "Field Bounds Max X"
		HANDLE_FIELD_MIN_Y:
			return "Field Bounds Min Y"
		HANDLE_FIELD_MAX_Y:
			return "Field Bounds Max Y"
		HANDLE_FIELD_MIN_Z:
			return "Field Bounds Min Z"
		HANDLE_FIELD_MAX_Z:
			return "Field Bounds Max Z"
		_:
			return "Ripple Handle"


static func get_action_name(handle_id: int) -> String:
	match handle_id:
		HANDLE_EMITTER_RADIUS:
			return "Change Ripple Emitter Radius"
		HANDLE_EMITTER_MOVING_DISTANCE:
			return "Change Ripple Moving Threshold"
		HANDLE_FIELD_MIN_X, HANDLE_FIELD_MAX_X, HANDLE_FIELD_MIN_Y, HANDLE_FIELD_MAX_Y, HANDLE_FIELD_MIN_Z, HANDLE_FIELD_MAX_Z:
			return "Change Ripple Field Bounds"
		_:
			return "Change Ripple Handle"


static func get_handle_value(node: Object, handle_id: int) -> Variant:
	if not can_edit_handle(node, handle_id):
		return null
	if is_field_bounds_handle(handle_id):
		return sanitize_field_bounds(node.get(get_property_name(handle_id)))
	return sanitize_handle_value(handle_id, node.get(get_property_name(handle_id)))


static func apply_handle_value(node: Object, handle_id: int, value: Variant) -> bool:
	if not can_edit_handle(node, handle_id):
		return false
	node.set(get_property_name(handle_id), sanitize_handle_value(handle_id, value))
	return true


static func build_property_change(node: Object, handle_id: int, restore_value: Variant) -> Dictionary:
	if not can_edit_handle(node, handle_id):
		return {}
	var property_name := get_property_name(handle_id)
	var old_value = sanitize_handle_value(handle_id, restore_value)
	var new_value = sanitize_handle_value(handle_id, node.get(property_name))
	if values_equal(handle_id, old_value, new_value):
		return {}
	return {
		"property": property_name,
		"old_value": old_value,
		"new_value": new_value,
		"action": get_action_name(handle_id),
	}


static func sanitize_handle_value(handle_id: int, value: Variant) -> Variant:
	if is_field_bounds_handle(handle_id):
		return sanitize_field_bounds(value)
	return clamp(float(value), MIN_HANDLE_VALUE, MAX_HANDLE_VALUE)


static func get_visual_handle_value(handle_id: int, value: Variant) -> float:
	var actual_value := float(sanitize_handle_value(handle_id, value))
	if handle_id == HANDLE_EMITTER_MOVING_DISTANCE:
		return max(actual_value, MIN_PICKABLE_MOVING_HANDLE_DISTANCE)
	return actual_value


static func get_visual_handle_offset(handle_id: int, value: Variant) -> float:
	if not is_emitter_handle(handle_id):
		return 0.0
	return get_visual_handle_value(handle_id, value) - float(sanitize_handle_value(handle_id, value))


static func is_emitter_handle(handle_id: int) -> bool:
	return handle_id == HANDLE_EMITTER_RADIUS or handle_id == HANDLE_EMITTER_MOVING_DISTANCE


static func is_field_bounds_handle(handle_id: int) -> bool:
	return handle_id >= HANDLE_FIELD_MIN_X and handle_id <= HANDLE_FIELD_MAX_Z


static func get_handle_axis(handle_id: int) -> Vector3:
	match handle_id:
		HANDLE_EMITTER_MOVING_DISTANCE, HANDLE_FIELD_MIN_Z, HANDLE_FIELD_MAX_Z:
			return Vector3.BACK
		HANDLE_FIELD_MIN_Y, HANDLE_FIELD_MAX_Y:
			return Vector3.UP
		_:
			return Vector3.RIGHT


static func get_field_bounds_handle_world_position(bounds_value: Variant, handle_id: int) -> Vector3:
	var bounds := sanitize_field_bounds(bounds_value)
	var min_pos := bounds.position
	var max_pos := bounds.position + bounds.size
	var center := bounds.position + bounds.size * 0.5
	match handle_id:
		HANDLE_FIELD_MIN_X:
			return Vector3(min_pos.x, center.y, center.z)
		HANDLE_FIELD_MAX_X:
			return Vector3(max_pos.x, center.y, center.z)
		HANDLE_FIELD_MIN_Y:
			return Vector3(center.x, min_pos.y, center.z)
		HANDLE_FIELD_MAX_Y:
			return Vector3(center.x, max_pos.y, center.z)
		HANDLE_FIELD_MIN_Z:
			return Vector3(center.x, center.y, min_pos.z)
		HANDLE_FIELD_MAX_Z:
			return Vector3(center.x, center.y, max_pos.z)
		_:
			return center


static func build_field_bounds_from_face_drag(bounds_value: Variant, handle_id: int, world_point: Vector3) -> AABB:
	var bounds := sanitize_field_bounds(bounds_value)
	var min_pos := bounds.position
	var max_pos := bounds.position + bounds.size
	match handle_id:
		HANDLE_FIELD_MIN_X:
			min_pos.x = min(world_point.x, max_pos.x - MIN_FIELD_BOUNDS_SIZE)
		HANDLE_FIELD_MAX_X:
			max_pos.x = max(world_point.x, min_pos.x + MIN_FIELD_BOUNDS_SIZE)
		HANDLE_FIELD_MIN_Y:
			min_pos.y = min(world_point.y, max_pos.y - MIN_FIELD_BOUNDS_SIZE)
		HANDLE_FIELD_MAX_Y:
			max_pos.y = max(world_point.y, min_pos.y + MIN_FIELD_BOUNDS_SIZE)
		HANDLE_FIELD_MIN_Z:
			min_pos.z = min(world_point.z, max_pos.z - MIN_FIELD_BOUNDS_SIZE)
		HANDLE_FIELD_MAX_Z:
			max_pos.z = max(world_point.z, min_pos.z + MIN_FIELD_BOUNDS_SIZE)
		_:
			return bounds
	return AABB(min_pos, max_pos - min_pos)


static func sanitize_field_bounds(value: Variant) -> AABB:
	var bounds: AABB = value
	var position := bounds.position
	var size := bounds.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	if size.z < 0.0:
		position.z += size.z
		size.z = -size.z
	size.x = max(size.x, MIN_FIELD_BOUNDS_SIZE)
	size.y = max(size.y, MIN_FIELD_BOUNDS_SIZE)
	size.z = max(size.z, MIN_FIELD_BOUNDS_SIZE)
	return AABB(position, size)


static func values_equal(handle_id: int, left: Variant, right: Variant) -> bool:
	if is_field_bounds_handle(handle_id):
		var left_bounds: AABB = left
		var right_bounds: AABB = right
		return aabb_equal_approx(left_bounds, right_bounds)
	return is_equal_approx(float(left), float(right))


static func aabb_equal_approx(left: AABB, right: AABB) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)
