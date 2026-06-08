@tool
extends RefCounted

const WaterRippleFieldScript = preload("res://addons/waterways/water_ripple_field.gd")
const WaterRippleEmitterScript = preload("res://addons/waterways/water_ripple_emitter.gd")
const RippleGizmoHandleModel = preload("res://addons/waterways/ripple_gizmo_handle_model.gd")

const CIRCLE_SEGMENTS := 64
const MODE_MOVING := 3
const MIN_RADIUS := 0.001


static func can_build_for_node(node: Object) -> bool:
	return node is WaterRippleFieldScript or node is WaterRippleEmitterScript


static func build_segments_for_node(node: Node3D) -> Dictionary:
	if node is WaterRippleFieldScript:
		return build_field_segments(node)
	if node is WaterRippleEmitterScript:
		return build_emitter_segments(node)
	return {}


static func build_handle_points_for_node(node: Node3D) -> Dictionary:
	if node is WaterRippleFieldScript:
		return build_field_handle_points(node)
	if node is WaterRippleEmitterScript:
		return build_emitter_handle_points(node)
	return {
		"positions": PackedVector3Array(),
		"ids": PackedInt32Array(),
	}


static func build_field_segments(field: Node3D) -> Dictionary:
	var bounds: AABB = field.get("world_bounds")
	bounds = _normalized_bounds(bounds)
	var result := {
		"field_bounds": PackedVector3Array(),
		"field_footprint": PackedVector3Array(),
		"field_routes": PackedVector3Array(),
	}
	if bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		return result

	result["field_bounds"] = _build_bounds_lines(field, bounds)
	result["field_footprint"] = _build_footprint_lines(field, bounds)
	result["field_routes"] = _build_field_route_lines(field, bounds)
	return result


static func build_emitter_segments(emitter: Node3D) -> Dictionary:
	var radius := max(MIN_RADIUS, float(emitter.get("radius")))
	var moving_distance := max(MIN_RADIUS, float(emitter.get("moving_emit_distance")))
	var origin_world := _node_world_position(emitter)
	var result := {
		"emitter_radius": _build_world_circle_lines(emitter, origin_world, radius, false),
		"emitter_moving": PackedVector3Array(),
		"emitter_handle_guides": PackedVector3Array(),
		"emitter_route": _build_emitter_route_lines(emitter, origin_world),
	}
	if int(emitter.get("emitter_mode")) == MODE_MOVING:
		result["emitter_moving"] = _build_world_circle_lines(emitter, origin_world, moving_distance, true)
		result["emitter_handle_guides"] = _build_moving_handle_guide(emitter, origin_world, moving_distance)
	return result


static func build_field_handle_points(field: Node3D) -> Dictionary:
	var result := {
		"positions": PackedVector3Array(),
		"ids": PackedInt32Array(),
	}
	var bounds: AABB = RippleGizmoHandleModel.sanitize_field_bounds(field.get("world_bounds"))
	for handle_id in RippleGizmoHandleModel.get_handle_ids_for_node(field):
		var world_position := RippleGizmoHandleModel.get_field_bounds_handle_world_position(bounds, handle_id)
		result["positions"].append(_world_to_node_local(field, world_position))
		result["ids"].append(handle_id)
	return result


static func build_emitter_handle_points(emitter: Node3D) -> Dictionary:
	var result := {
		"positions": PackedVector3Array(),
		"ids": PackedInt32Array(),
	}
	var origin_world := _node_world_position(emitter)
	for handle_id in RippleGizmoHandleModel.get_handle_ids_for_node(emitter):
		var direction := Vector3.RIGHT
		if handle_id == RippleGizmoHandleModel.HANDLE_EMITTER_MOVING_DISTANCE:
			direction = Vector3.BACK
		var actual_distance := float(RippleGizmoHandleModel.get_handle_value(emitter, handle_id))
		var distance := RippleGizmoHandleModel.get_visual_handle_value(handle_id, actual_distance)
		result["positions"].append(_world_to_node_local(emitter, origin_world + direction * distance))
		result["ids"].append(handle_id)
	return result


static func _build_bounds_lines(owner: Node3D, bounds: AABB) -> PackedVector3Array:
	var min_pos := bounds.position
	var max_pos := bounds.position + bounds.size
	var corners := [
		Vector3(min_pos.x, min_pos.y, min_pos.z),
		Vector3(max_pos.x, min_pos.y, min_pos.z),
		Vector3(min_pos.x, min_pos.y, max_pos.z),
		Vector3(max_pos.x, min_pos.y, max_pos.z),
		Vector3(min_pos.x, max_pos.y, min_pos.z),
		Vector3(max_pos.x, max_pos.y, min_pos.z),
		Vector3(min_pos.x, max_pos.y, max_pos.z),
		Vector3(max_pos.x, max_pos.y, max_pos.z),
	]
	var edge_indices := [
		0, 1, 1, 3, 3, 2, 2, 0,
		4, 5, 5, 7, 7, 6, 6, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	]
	var lines := PackedVector3Array()
	for index in edge_indices:
		lines.append(_world_to_node_local(owner, corners[index]))
	return lines


static func _build_footprint_lines(owner: Node3D, bounds: AABB) -> PackedVector3Array:
	var min_pos := bounds.position
	var max_pos := bounds.position + bounds.size
	var y := min_pos.y + bounds.size.y * 0.5
	var corners := [
		Vector3(min_pos.x, y, min_pos.z),
		Vector3(max_pos.x, y, min_pos.z),
		Vector3(max_pos.x, y, max_pos.z),
		Vector3(min_pos.x, y, max_pos.z),
	]
	var lines := PackedVector3Array()
	for index in range(corners.size()):
		lines.append(_world_to_node_local(owner, corners[index]))
		lines.append(_world_to_node_local(owner, corners[(index + 1) % corners.size()]))

	var center := bounds.position + bounds.size * 0.5
	lines.append(_world_to_node_local(owner, Vector3(min_pos.x, y, center.z)))
	lines.append(_world_to_node_local(owner, Vector3(max_pos.x, y, center.z)))
	lines.append(_world_to_node_local(owner, Vector3(center.x, y, min_pos.z)))
	lines.append(_world_to_node_local(owner, Vector3(center.x, y, max_pos.z)))
	return lines


static func _build_field_route_lines(field: Node3D, bounds: AABB) -> PackedVector3Array:
	var lines := PackedVector3Array()
	var paths: Array = field.get("target_river_paths")
	if paths.is_empty():
		return lines
	var origin_world := bounds.position + bounds.size * 0.5
	for path_value in paths:
		var path := NodePath(path_value)
		if path == NodePath(""):
			continue
		var target := field.get_node_or_null(path)
		if target is Node3D:
			lines.append(_world_to_node_local(field, origin_world))
			lines.append(_world_to_node_local(field, _node_world_position(target as Node3D)))
	return lines


static func _build_emitter_route_lines(emitter: Node3D, origin_world: Vector3) -> PackedVector3Array:
	var target := _find_emitter_route_target(emitter)
	var lines := PackedVector3Array()
	if target == null:
		return lines
	lines.append(_world_to_node_local(emitter, origin_world))
	lines.append(_world_to_node_local(emitter, _field_anchor_world(target)))
	return lines


static func _build_world_circle_lines(owner: Node3D, origin_world: Vector3, radius: float, dashed: bool) -> PackedVector3Array:
	var lines := PackedVector3Array()
	for index in range(CIRCLE_SEGMENTS):
		if dashed and index % 2 == 1:
			continue
		var angle_a := TAU * float(index) / float(CIRCLE_SEGMENTS)
		var angle_b := TAU * float(index + 1) / float(CIRCLE_SEGMENTS)
		var point_a := origin_world + Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius)
		var point_b := origin_world + Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius)
		lines.append(_world_to_node_local(owner, point_a))
		lines.append(_world_to_node_local(owner, point_b))
	return lines


static func _build_moving_handle_guide(owner: Node3D, origin_world: Vector3, moving_distance: float) -> PackedVector3Array:
	var visual_distance := RippleGizmoHandleModel.get_visual_handle_value(
		RippleGizmoHandleModel.HANDLE_EMITTER_MOVING_DISTANCE,
		moving_distance
	)
	var lines := PackedVector3Array()
	if is_equal_approx(visual_distance, moving_distance):
		return lines
	lines.append(_world_to_node_local(owner, origin_world + Vector3.BACK * moving_distance))
	lines.append(_world_to_node_local(owner, origin_world + Vector3.BACK * visual_distance))
	return lines


static func _find_emitter_route_target(emitter: Node3D) -> Node3D:
	var path := NodePath(emitter.get("target_field_path"))
	if path != NodePath(""):
		var by_path := emitter.get_node_or_null(path)
		if by_path is WaterRippleFieldScript:
			return by_path as Node3D

	var ancestor := emitter.get_parent()
	while ancestor != null:
		if ancestor is WaterRippleFieldScript:
			return ancestor as Node3D
		ancestor = ancestor.get_parent()

	var group_name := String(emitter.get("field_group_name"))
	if not group_name.is_empty() and emitter.is_inside_tree():
		var group_targets := []
		for candidate in emitter.get_tree().get_nodes_in_group(group_name):
			if candidate is WaterRippleFieldScript:
				group_targets.append(candidate)
		if group_targets.size() == 1:
			return group_targets[0] as Node3D
	return null


static func _field_anchor_world(field: Node3D) -> Vector3:
	var bounds: AABB = field.get("world_bounds")
	bounds = _normalized_bounds(bounds)
	if bounds.size.x > 0.0 and bounds.size.z > 0.0:
		return bounds.position + bounds.size * 0.5
	return _node_world_position(field)


static func _node_world_position(node: Node3D) -> Vector3:
	if node.is_inside_tree():
		return node.global_position
	return node.transform.origin


static func _world_to_node_local(node: Node3D, world_point: Vector3) -> Vector3:
	if node.is_inside_tree():
		return node.to_local(world_point)
	return node.transform.affine_inverse() * world_point


static func _normalized_bounds(bounds: AABB) -> AABB:
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
	return AABB(position, size)
