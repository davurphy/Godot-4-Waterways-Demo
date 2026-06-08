@tool
extends RefCounted

const WaterRippleFieldScript = preload("res://addons/waterways/water_ripple_field.gd")
const WaterRippleEmitterScript = preload("res://addons/waterways/water_ripple_emitter.gd")
const RippleGizmoHandleModel = preload("res://addons/waterways/ripple_gizmo_handle_model.gd")

const CIRCLE_SEGMENTS := 64
const MODE_MOVING := 3
const MIN_RADIUS := 0.001
const MAX_BOUNDARY_PREVIEW_LINE_PAIRS := 512
const BOUNDARY_PREVIEW_Y_OFFSET := 0.03


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
		"field_boundary_preview": PackedVector3Array(),
		"field_routes": PackedVector3Array(),
	}
	if bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		return result

	result["field_bounds"] = _build_bounds_lines(field, bounds)
	result["field_footprint"] = _build_footprint_lines(field, bounds)
	result["field_boundary_preview"] = _build_boundary_preview_lines(field, bounds)
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


static func _build_boundary_preview_lines(field: Node3D, bounds: AABB) -> PackedVector3Array:
	if field.get("boundary_mask_texture") != null or not bool(field.get("auto_generate_boundary_mask")):
		return PackedVector3Array()

	var meshes := _get_boundary_preview_meshes(field)
	if meshes.is_empty():
		return PackedVector3Array()

	var edge_counts := {}
	var edge_points := {}
	for mesh_instance in meshes:
		_collect_boundary_edges(mesh_instance, bounds, edge_counts, edge_points)

	var lines := PackedVector3Array()
	for edge_key in edge_points.keys():
		if int(edge_counts.get(edge_key, 0)) != 1:
			continue
		var points: PackedVector3Array = edge_points[edge_key]
		if points.size() < 2:
			continue
		lines.append(_world_to_node_local(field, points[0]))
		lines.append(_world_to_node_local(field, points[1]))
		if lines.size() / 2 >= MAX_BOUNDARY_PREVIEW_LINE_PAIRS:
			break
	return lines


static func _build_emitter_route_lines(emitter: Node3D, origin_world: Vector3) -> PackedVector3Array:
	var target := _find_emitter_route_target(emitter)
	var lines := PackedVector3Array()
	if target == null:
		return lines
	lines.append(_world_to_node_local(emitter, origin_world))
	lines.append(_world_to_node_local(emitter, _field_anchor_world(target)))
	return lines


static func _get_boundary_preview_meshes(field: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_append_boundary_preview_meshes_from_paths(field, field.get("boundary_source_paths"), meshes)
	_append_boundary_preview_meshes_from_paths(field, field.get("target_river_paths"), meshes)

	var group_name := String(field.get("target_group_name"))
	if not group_name.is_empty() and field.is_inside_tree():
		for candidate in field.get_tree().get_nodes_in_group(group_name):
			var mesh := _get_boundary_preview_mesh(candidate)
			if mesh != null and not meshes.has(mesh):
				meshes.append(mesh)
	return meshes


static func _append_boundary_preview_meshes_from_paths(field: Node3D, paths: Array, meshes: Array[MeshInstance3D]) -> void:
	for path_value in paths:
		var path := NodePath(path_value)
		if path == NodePath(""):
			continue
		var source := field.get_node_or_null(path)
		var mesh := _get_boundary_preview_mesh(source)
		if mesh != null and not meshes.has(mesh):
			meshes.append(mesh)


static func _get_boundary_preview_mesh(source: Object) -> MeshInstance3D:
	if source is MeshInstance3D:
		var direct_mesh := source as MeshInstance3D
		return direct_mesh if direct_mesh.mesh != null and direct_mesh.mesh.get_surface_count() > 0 else null
	if source == null:
		return null

	var mesh_value = source.get("mesh_instance")
	if mesh_value is MeshInstance3D:
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			return mesh_instance
	return null


static func _collect_boundary_edges(
		mesh_instance: MeshInstance3D,
		bounds: AABB,
		edge_counts: Dictionary,
		edge_points: Dictionary) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var source_transform := mesh_instance.global_transform if mesh_instance.is_inside_tree() else mesh_instance.transform
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var primitive: Mesh.PrimitiveType = mesh_instance.mesh.surface_get_primitive_type(surface_index)
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		match primitive:
			Mesh.PRIMITIVE_TRIANGLES:
				_collect_triangle_edges(vertices, indices, source_transform, bounds, edge_counts, edge_points)
			Mesh.PRIMITIVE_TRIANGLE_STRIP:
				_collect_triangle_strip_edges(vertices, indices, source_transform, bounds, edge_counts, edge_points)
			Mesh.PRIMITIVE_LINES:
				_append_line_edges(vertices, indices, source_transform, bounds, edge_counts, edge_points, false)
			Mesh.PRIMITIVE_LINE_STRIP:
				_append_line_edges(vertices, indices, source_transform, bounds, edge_counts, edge_points, true)


static func _collect_triangle_edges(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		source_transform: Transform3D,
		bounds: AABB,
		edge_counts: Dictionary,
		edge_points: Dictionary) -> void:
	var vertex_count := indices.size() if not indices.is_empty() else vertices.size()
	for start in range(0, vertex_count - 2, 3):
		var a := _project_boundary_vertex(vertices, indices, start, source_transform, bounds)
		var b := _project_boundary_vertex(vertices, indices, start + 1, source_transform, bounds)
		var c := _project_boundary_vertex(vertices, indices, start + 2, source_transform, bounds)
		_count_boundary_edge(edge_counts, edge_points, a, b)
		_count_boundary_edge(edge_counts, edge_points, b, c)
		_count_boundary_edge(edge_counts, edge_points, c, a)


static func _collect_triangle_strip_edges(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		source_transform: Transform3D,
		bounds: AABB,
		edge_counts: Dictionary,
		edge_points: Dictionary) -> void:
	var vertex_count := indices.size() if not indices.is_empty() else vertices.size()
	for start in range(max(0, vertex_count - 2)):
		var a := _project_boundary_vertex(vertices, indices, start, source_transform, bounds)
		var b := _project_boundary_vertex(vertices, indices, start + 1, source_transform, bounds)
		var c := _project_boundary_vertex(vertices, indices, start + 2, source_transform, bounds)
		_count_boundary_edge(edge_counts, edge_points, a, b)
		_count_boundary_edge(edge_counts, edge_points, b, c)
		_count_boundary_edge(edge_counts, edge_points, c, a)


static func _append_line_edges(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		source_transform: Transform3D,
		bounds: AABB,
		edge_counts: Dictionary,
		edge_points: Dictionary,
		is_strip: bool) -> void:
	var vertex_count := indices.size() if not indices.is_empty() else vertices.size()
	var step := 1 if is_strip else 2
	for start in range(0, max(0, vertex_count - 1), step):
		var a := _project_boundary_vertex(vertices, indices, start, source_transform, bounds)
		var b := _project_boundary_vertex(vertices, indices, start + 1, source_transform, bounds)
		_count_boundary_edge(edge_counts, edge_points, a, b)


static func _project_boundary_vertex(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		vertex_index: int,
		source_transform: Transform3D,
		bounds: AABB) -> Vector3:
	var source_index := int(indices[vertex_index]) if not indices.is_empty() else vertex_index
	source_index = clampi(source_index, 0, vertices.size() - 1)
	var world_vertex := source_transform * vertices[source_index]
	return Vector3(world_vertex.x, bounds.position.y + bounds.size.y * 0.5 + BOUNDARY_PREVIEW_Y_OFFSET, world_vertex.z)


static func _count_boundary_edge(edge_counts: Dictionary, edge_points: Dictionary, point_a: Vector3, point_b: Vector3) -> void:
	if point_a.is_equal_approx(point_b):
		return
	var key_a := _boundary_point_key(point_a)
	var key_b := _boundary_point_key(point_b)
	var edge_key := key_a + "|" + key_b if key_a < key_b else key_b + "|" + key_a
	edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1
	if not edge_points.has(edge_key):
		var points := PackedVector3Array()
		points.append(point_a)
		points.append(point_b)
		edge_points[edge_key] = points


static func _boundary_point_key(point: Vector3) -> String:
	return "%d,%d" % [int(round(point.x * 1000.0)), int(round(point.z * 1000.0))]


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
