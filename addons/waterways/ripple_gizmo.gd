@tool
extends EditorNode3DGizmoPlugin

const RippleGizmoGeometry = preload("res://addons/waterways/ripple_gizmo_geometry.gd")
const RippleGizmoHandleModel = preload("res://addons/waterways/ripple_gizmo_handle_model.gd")
const FIELD_BOUNDS_MATERIAL := "ripple_field_bounds"
const FIELD_FOOTPRINT_MATERIAL := "ripple_field_footprint"
const FIELD_ROUTE_MATERIAL := "ripple_field_route"
const EMITTER_RADIUS_MATERIAL := "ripple_emitter_radius"
const EMITTER_MOVING_MATERIAL := "ripple_emitter_moving"
const EMITTER_ROUTE_MATERIAL := "ripple_emitter_route"
const HANDLE_MATERIAL := "handles"
const HANDLE_RAY_LENGTH := 4096.0

var _undo_redo: EditorUndoRedoManager
var _handle_drag_visual_offsets := {}


func _init() -> void:
	create_handle_material(HANDLE_MATERIAL)
	create_material(FIELD_BOUNDS_MATERIAL, Color(0.2, 0.72, 1.0, 0.85), false, true)
	create_material(FIELD_FOOTPRINT_MATERIAL, Color(0.34, 1.0, 0.74, 0.7), false, true)
	create_material(FIELD_ROUTE_MATERIAL, Color(0.48, 0.82, 1.0, 0.45), false, true)
	create_material(EMITTER_RADIUS_MATERIAL, Color(1.0, 0.58, 0.18, 0.95), false, true)
	create_material(EMITTER_MOVING_MATERIAL, Color(1.0, 0.9, 0.2, 0.75), false, true)
	create_material(EMITTER_ROUTE_MATERIAL, Color(0.56, 0.86, 1.0, 0.55), false, true)


func set_undo_redo_manager(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo


func _get_gizmo_name() -> String:
	return "WaterRipples"


func _has_gizmo(spatial: Node3D) -> bool:
	return RippleGizmoGeometry.can_build_for_node(spatial)


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	if node == null:
		return
	var segments := RippleGizmoGeometry.build_segments_for_node(node)
	_add_lines(gizmo, segments.get("field_bounds", PackedVector3Array()), FIELD_BOUNDS_MATERIAL, true)
	_add_lines(gizmo, segments.get("field_footprint", PackedVector3Array()), FIELD_FOOTPRINT_MATERIAL, false)
	_add_lines(gizmo, segments.get("field_routes", PackedVector3Array()), FIELD_ROUTE_MATERIAL, false)
	_add_lines(gizmo, segments.get("emitter_radius", PackedVector3Array()), EMITTER_RADIUS_MATERIAL, true)
	_add_lines(gizmo, segments.get("emitter_moving", PackedVector3Array()), EMITTER_MOVING_MATERIAL, false)
	_add_lines(gizmo, segments.get("emitter_handle_guides", PackedVector3Array()), EMITTER_MOVING_MATERIAL, false)
	_add_lines(gizmo, segments.get("emitter_route", PackedVector3Array()), EMITTER_ROUTE_MATERIAL, false)
	var handle_data := RippleGizmoGeometry.build_handle_points_for_node(node)
	_apply_active_handle_visual_offsets(gizmo, node, handle_data)
	_add_handles(gizmo, handle_data)


func _get_handle_name(_gizmo: EditorNode3DGizmo, index: int, _secondary: bool) -> String:
	return RippleGizmoHandleModel.get_handle_name(index)


func _get_handle_value(gizmo: EditorNode3DGizmo, index: int, _secondary: bool) -> Variant:
	var node := gizmo.get_node_3d()
	var value = RippleGizmoHandleModel.get_handle_value(node, index)
	var visual_offset := RippleGizmoHandleModel.get_visual_handle_offset(index, value)
	if is_zero_approx(visual_offset):
		_handle_drag_visual_offsets.erase(_handle_drag_key(gizmo, index))
	else:
		_handle_drag_visual_offsets[_handle_drag_key(gizmo, index)] = visual_offset
	return value


func _set_handle(gizmo: EditorNode3DGizmo, index: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node := gizmo.get_node_3d()
	if not RippleGizmoHandleModel.can_edit_handle(node, index):
		return
	var next_value = _project_handle_value(node, index, camera, point, _get_handle_drag_visual_offset(gizmo, node, index))
	if next_value == null:
		return
	RippleGizmoHandleModel.apply_handle_value(node, index, next_value)
	_refresh_after_handle_edit(node, gizmo, true)


func _commit_handle(gizmo: EditorNode3DGizmo, index: int, _secondary: bool, restore: Variant, cancel: bool = false) -> void:
	var node := gizmo.get_node_3d()
	if not RippleGizmoHandleModel.can_edit_handle(node, index):
		return
	var drag_key := _handle_drag_key(gizmo, index)
	var previous_value := RippleGizmoHandleModel.sanitize_handle_value(index, restore)
	if cancel:
		RippleGizmoHandleModel.apply_handle_value(node, index, previous_value)
		_handle_drag_visual_offsets.erase(drag_key)
		_refresh_after_handle_edit(node, gizmo, true)
		return

	var change := RippleGizmoHandleModel.build_property_change(node, index, previous_value)
	if change.is_empty():
		RippleGizmoHandleModel.apply_handle_value(node, index, previous_value)
		_handle_drag_visual_offsets.erase(drag_key)
		_refresh_after_handle_edit(node, gizmo, true)
		return
	if _undo_redo == null:
		RippleGizmoHandleModel.apply_handle_value(node, index, previous_value)
		_handle_drag_visual_offsets.erase(drag_key)
		_refresh_after_handle_edit(node, gizmo, true)
		return

	var property_name := StringName(change.get("property", StringName()))
	_undo_redo.create_action(String(change.get("action", "Change Ripple Handle")), 0, node)
	_undo_redo.add_do_property(node, property_name, change.get("new_value"))
	_undo_redo.add_undo_property(node, property_name, change.get("old_value"))
	_add_handle_refresh_methods(node)
	_undo_redo.commit_action()
	_handle_drag_visual_offsets.erase(drag_key)
	_refresh_after_handle_edit(node, gizmo, true)


func _add_lines(gizmo: EditorNode3DGizmo, lines: PackedVector3Array, material_name: String, add_collision: bool) -> void:
	if lines.is_empty():
		return
	gizmo.add_lines(lines, get_material(material_name, gizmo))
	if add_collision:
		gizmo.add_collision_segments(lines)


func _add_handles(gizmo: EditorNode3DGizmo, handle_data: Dictionary) -> void:
	var positions: PackedVector3Array = handle_data.get("positions", PackedVector3Array())
	var ids: PackedInt32Array = handle_data.get("ids", PackedInt32Array())
	if positions.is_empty():
		return
	gizmo.add_handles(positions, get_material(HANDLE_MATERIAL, gizmo), ids)


func _project_handle_value(node: Node3D, handle_id: int, camera: Camera3D, point: Vector2, visual_offset: float) -> Variant:
	var ray_from := camera.project_ray_origin(point)
	var ray_dir := camera.project_ray_normal(point)
	var ray_to := ray_from + ray_dir * HANDLE_RAY_LENGTH
	var axis := RippleGizmoHandleModel.get_handle_axis(handle_id)
	if RippleGizmoHandleModel.is_field_bounds_handle(handle_id):
		var bounds: AABB = RippleGizmoHandleModel.sanitize_field_bounds(node.get("world_bounds"))
		var face_center := RippleGizmoHandleModel.get_field_bounds_handle_world_position(bounds, handle_id)
		var axis_from := face_center - axis * HANDLE_RAY_LENGTH
		var axis_to := face_center + axis * HANDLE_RAY_LENGTH
		var field_closest_points := Geometry3D.get_closest_points_between_segments(axis_from, axis_to, ray_from, ray_to)
		return RippleGizmoHandleModel.build_field_bounds_from_face_drag(bounds, handle_id, field_closest_points[0])

	var origin_world := _node_world_position(node)
	var axis_to := origin_world + axis * RippleGizmoHandleModel.MAX_HANDLE_VALUE
	var closest_points := Geometry3D.get_closest_points_between_segments(origin_world, axis_to, ray_from, ray_to)
	return (closest_points[0] - origin_world).dot(axis) - visual_offset


func _get_handle_axis(handle_id: int) -> Vector3:
	return RippleGizmoHandleModel.get_handle_axis(handle_id)


func _node_world_position(node: Node3D) -> Vector3:
	if node.is_inside_tree():
		return node.global_position
	return node.transform.origin


func _apply_active_handle_visual_offsets(gizmo: EditorNode3DGizmo, node: Node3D, handle_data: Dictionary) -> void:
	var positions: PackedVector3Array = handle_data.get("positions", PackedVector3Array())
	var ids: PackedInt32Array = handle_data.get("ids", PackedInt32Array())
	for handle_index in range(min(positions.size(), ids.size())):
		var handle_id := int(ids[handle_index])
		var drag_key := _handle_drag_key(gizmo, handle_id)
		if not _handle_drag_visual_offsets.has(drag_key):
			continue
		if not RippleGizmoHandleModel.is_emitter_handle(handle_id):
			continue
		var actual_distance := float(RippleGizmoHandleModel.get_handle_value(node, handle_id))
		var visual_distance := actual_distance + float(_handle_drag_visual_offsets[drag_key])
		var world_point := _node_world_position(node) + _get_handle_axis(handle_id) * visual_distance
		positions[handle_index] = _world_to_node_local(node, world_point)
	handle_data["positions"] = positions


func _world_to_node_local(node: Node3D, world_point: Vector3) -> Vector3:
	if node.is_inside_tree():
		return node.to_local(world_point)
	return node.transform.affine_inverse() * world_point


func _get_handle_drag_visual_offset(gizmo: EditorNode3DGizmo, node: Node3D, handle_id: int) -> float:
	var drag_key := _handle_drag_key(gizmo, handle_id)
	if _handle_drag_visual_offsets.has(drag_key):
		return float(_handle_drag_visual_offsets[drag_key])
	return RippleGizmoHandleModel.get_visual_handle_offset(handle_id, RippleGizmoHandleModel.get_handle_value(node, handle_id))


func _handle_drag_key(gizmo: EditorNode3DGizmo, handle_id: int) -> String:
	return str(gizmo.get_instance_id()) + ":" + str(handle_id)


func _refresh_after_handle_edit(node: Node3D, gizmo: EditorNode3DGizmo, redraw_now: bool) -> void:
	if node.has_method("update_configuration_warnings"):
		node.call("update_configuration_warnings")
	if node.has_method("update_gizmos"):
		node.call("update_gizmos")
	if redraw_now:
		_redraw(gizmo)


func _add_handle_refresh_methods(node: Node3D) -> void:
	if node.has_method("update_configuration_warnings"):
		_undo_redo.add_do_method(node, "update_configuration_warnings")
		_undo_redo.add_undo_method(node, "update_configuration_warnings")
	if node.has_method("update_gizmos"):
		_undo_redo.add_do_method(node, "update_gizmos")
		_undo_redo.add_undo_method(node, "update_gizmos")
