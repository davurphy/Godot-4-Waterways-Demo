# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends EditorNode3DGizmoPlugin


const RiverManager = preload("./river_manager.gd")
const RiverControls = preload("./gui/river_controls.gd")
const WaterHelperMethods = preload("./water_helper_methods.gd")
const HANDLES_PER_POINT = 5
const AXIS_CONSTRAINT_LENGTH = 4096
const COLLIDER_SNAP_MASK = 0xFFFFFFFF
const COLLIDER_SNAP_RAY_LENGTH = 4096.0
const AXIS_MAPPING := {
	RiverControls.CONSTRAINTS.AXIS_X: Vector3.RIGHT,
	RiverControls.CONSTRAINTS.AXIS_Y: Vector3.UP,
	RiverControls.CONSTRAINTS.AXIS_Z: Vector3.BACK
}
const PLANE_MAPPING := {
	RiverControls.CONSTRAINTS.PLANE_YZ: Vector3.RIGHT,
	RiverControls.CONSTRAINTS.PLANE_XZ: Vector3.UP,
	RiverControls.CONSTRAINTS.PLANE_XY: Vector3.BACK
}
const MIN_DIRECTION_LENGTH_SQUARED := 0.000001

var editor_plugin : EditorPlugin

var _path_mat
var _handle_lines_mat
var _handle_base_transform
var _handle_restore_state := {}
var _handle_restore_bake_valid_state := {}


static func get_point_tangent(curve: Curve3D, point_index: int) -> Vector3:
	var point_count := curve.get_point_count()
	if point_count == 0:
		return Vector3.BACK
	var safe_index := max(0, min(point_index, point_count - 1))
	var tangent := curve.get_point_out(safe_index)
	if tangent.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		tangent = -curve.get_point_in(safe_index)
	if tangent.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED and safe_index < point_count - 1:
		tangent = curve.get_point_position(safe_index + 1) - curve.get_point_position(safe_index)
	if tangent.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED and safe_index > 0:
		tangent = curve.get_point_position(safe_index) - curve.get_point_position(safe_index - 1)
	return _safe_direction(tangent, Vector3.BACK)


static func make_handle_base_transform(tangent: Vector3, global_basis: Basis, origin: Vector3) -> Transform3D:
	var z := _safe_direction(tangent, Vector3.BACK)
	var reference := Vector3.DOWN
	if abs(z.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	var x := _safe_direction(z.cross(reference), Vector3.RIGHT)
	var y := _safe_direction(z.cross(x), Vector3.UP)
	return Transform3D(Basis(x, y, z) * global_basis, origin)


static func get_constraint_direction(direction: Vector3, local_mode: bool, base_transform: Transform3D) -> Vector3:
	var result := direction
	if local_mode:
		result = base_transform.basis * result
	return _safe_direction(result, direction)


static func get_width_direction(tangent: Vector3, side: int) -> Vector3:
	var z := _safe_direction(tangent, Vector3.BACK)
	var reference := Vector3.UP
	if abs(z.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	var right := _safe_direction(z.cross(reference), Vector3.RIGHT)
	return right if side >= 0 else -right


static func make_collider_snap_query(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = COLLIDER_SNAP_MASK
	query.exclude = exclude
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.hit_back_faces = true
	query.hit_from_inside = true
	return query


static func get_collider_snap_position(scene_root: Node, world: World3D, ray_from: Vector3, ray_dir: Vector3, fallback_pos: Variant) -> Variant:
	if fallback_pos != null:
		var candidate: Vector3 = fallback_pos
		var scene_vertical_hit = _intersect_scene_collision_shapes(
			scene_root,
			candidate + Vector3.UP * COLLIDER_SNAP_RAY_LENGTH,
			candidate + Vector3.DOWN * COLLIDER_SNAP_RAY_LENGTH
		)
		if scene_vertical_hit != null:
			return scene_vertical_hit
	
	var camera_to := ray_from + ray_dir * COLLIDER_SNAP_RAY_LENGTH
	var scene_camera_hit = _intersect_scene_collision_shapes(scene_root, ray_from, camera_to)
	if scene_camera_hit != null:
		return scene_camera_hit
	
	var space_state := world.direct_space_state
	var snap_exclude_rids := _collect_snap_ignore_rids(scene_root)
	if fallback_pos != null:
		var candidate: Vector3 = fallback_pos
		var vertical_query := make_collider_snap_query(
			candidate + Vector3.UP * COLLIDER_SNAP_RAY_LENGTH,
			candidate + Vector3.DOWN * COLLIDER_SNAP_RAY_LENGTH,
			snap_exclude_rids
		)
		var vertical_result: Dictionary = space_state.intersect_ray(vertical_query)
		if vertical_result:
			return vertical_result.position
	
	var camera_query := make_collider_snap_query(ray_from, camera_to, snap_exclude_rids)
	var camera_result: Dictionary = space_state.intersect_ray(camera_query)
	if camera_result:
		return camera_result.position
	
	return null


static func _intersect_scene_collision_shapes(scene_root: Node, from: Vector3, to: Vector3) -> Variant:
	if scene_root == null:
		return null
	var best_distance := INF
	var best_hit: Variant = null
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if not node is CollisionShape3D:
			continue
		var collision_shape := node as CollisionShape3D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		if _should_skip_snap_collision_shape(collision_shape):
			continue
		var hit = _intersect_collision_shape_segment(collision_shape, from, to)
		if hit == null:
			continue
		var distance := from.distance_squared_to(hit)
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


static func _collect_snap_ignore_rids(scene_root: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if scene_root == null:
		return rids
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if node is CollisionObject3D and _node_or_ancestor_has_snap_ignore(node):
			rids.append((node as CollisionObject3D).get_rid())
	return rids


static func _should_skip_snap_collision_shape(collision_shape: CollisionShape3D) -> bool:
	if _node_or_ancestor_has_snap_ignore(collision_shape):
		return true
	
	var collision_parent := collision_shape.get_parent()
	if collision_parent is CollisionObject3D:
		return ((collision_parent as CollisionObject3D).collision_layer & COLLIDER_SNAP_MASK) == 0
	return false


static func _node_or_ancestor_has_snap_ignore(node: Node) -> bool:
	while node != null:
		if node.has_meta("waterways_snap_ignore") and bool(node.get_meta("waterways_snap_ignore")):
			return true
		node = node.get_parent()
	return false


static func _intersect_collision_shape_segment(collision_shape: CollisionShape3D, from: Vector3, to: Vector3) -> Variant:
	return WaterHelperMethods.intersect_collision_shape_segment(collision_shape, from, to)


static func _safe_direction(direction: Vector3, fallback: Vector3) -> Vector3:
	if direction.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		return direction.normalized()
	if fallback.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		return fallback.normalized()
	return Vector3.BACK

func _init() -> void:
	create_handle_material("handles")
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 1.0, 0.0)
	mat.render_priority = 10
	add_material("path", mat)
	add_material("handle_lines", mat)


func reset() -> void:
	_handle_base_transform = null


func _get_gizmo_name() -> String:
	return "RiverInput"


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is RiverManager


func _get_handle_name(gizmo: EditorNode3DGizmo, index: int, _secondary: bool) -> String:
	return "Handle " + str(index)


func _get_handle_value(gizmo: EditorNode3DGizmo, index: int, _secondary: bool) -> Variant:
	var p_index := int(index / HANDLES_PER_POINT)
	var river := gizmo.get_node_3d() as RiverManager
	if index % HANDLES_PER_POINT == 0:
		return river.curve.get_point_position(p_index)
	if index % HANDLES_PER_POINT == 1:
		return river.curve.get_point_in(p_index)
	if index % HANDLES_PER_POINT == 2:
		return river.curve.get_point_out(p_index)
	if index % HANDLES_PER_POINT == 3 or  index % HANDLES_PER_POINT == 4:
		return river.widths[p_index] 
	return null


# Called when handle is moved
func _set_handle(gizmo: EditorNode3DGizmo, index: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var river := gizmo.get_node_3d() as RiverManager

	var global_transform : Transform3D = river.transform
	if river.is_inside_tree():
		global_transform = river.get_global_transform()
	var global_inverse: Transform3D = global_transform.affine_inverse()

	var ray_from = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)

	var old_pos : Vector3
	var p_index = int(index / HANDLES_PER_POINT)
	var base = river.curve.get_point_position(p_index)
	var tangent := get_point_tangent(river.curve, p_index)
	
	# Logic to move handles
	if index % HANDLES_PER_POINT == 0:
		old_pos = base
	if index % HANDLES_PER_POINT == 1:
		old_pos = river.curve.get_point_in(p_index) + base
	if index % HANDLES_PER_POINT == 2:
		old_pos = river.curve.get_point_out(p_index) + base
	if index % HANDLES_PER_POINT == 3:
		old_pos = base + get_width_direction(tangent, 1) * river.widths[p_index]
	if index % HANDLES_PER_POINT == 4:
		old_pos = base + get_width_direction(tangent, -1) * river.widths[p_index]
	
	var old_pos_global := river.to_global(old_pos)
	
	if not _handle_base_transform:
		# This is the first set_handle() call since the last reset so we
		# use the current handle position as our _handle_base_transform
		_handle_base_transform = make_handle_base_transform(tangent, global_transform.basis, old_pos_global)
	
	# Point, in and out handles
	if index % HANDLES_PER_POINT <= 2:
		var new_pos: Variant = null
		
		if editor_plugin.constraint == RiverControls.CONSTRAINTS.COLLIDERS:
			# In/out handles still use the camera-facing drag plane before collider
			# snapping; hit-normal planes need a dedicated UX pass.
			var plane = Plane(old_pos_global, old_pos_global + camera.global_transform.basis.x, old_pos_global + camera.global_transform.basis.y)
			var fallback_pos = plane.intersects_ray(ray_from, ray_dir)
			new_pos = get_collider_snap_position(river.get_tree().get_edited_scene_root(), river.get_world_3d(), ray_from, ray_dir, fallback_pos)
			if new_pos == null:
				new_pos = fallback_pos
		
		elif editor_plugin.constraint == RiverControls.CONSTRAINTS.NONE:
			var plane = Plane(old_pos_global, old_pos_global + camera.global_transform.basis.x, old_pos_global + camera.global_transform.basis.y)
			new_pos = plane.intersects_ray(ray_from, ray_dir)
		
		elif editor_plugin.constraint in AXIS_MAPPING:
			var axis: Vector3 = get_constraint_direction(AXIS_MAPPING[editor_plugin.constraint], editor_plugin.local_editing, _handle_base_transform)
			var axis_from = old_pos_global + (axis * AXIS_CONSTRAINT_LENGTH)
			var axis_to = old_pos_global - (axis * AXIS_CONSTRAINT_LENGTH)
			var ray_to = ray_from + (ray_dir * AXIS_CONSTRAINT_LENGTH)
			var result = Geometry3D.get_closest_points_between_segments(axis_from, axis_to, ray_from, ray_to)
			new_pos = result[0]
		
		elif editor_plugin.constraint in PLANE_MAPPING:
			var normal: Vector3 = get_constraint_direction(PLANE_MAPPING[editor_plugin.constraint], editor_plugin.local_editing, _handle_base_transform)
			var plane := Plane(normal, old_pos_global)
			new_pos = plane.intersects_ray(ray_from, ray_dir)
		
		# Discard if no valid position was found
		if new_pos == null:
			return
		
		# Ctrl-based rounding is deferred until local axis/plane rounding has a
		# clear editor behavior.
		
		var new_pos_local := river.to_local(new_pos)

		if index % HANDLES_PER_POINT == 0:
			river.set_curve_point_position(p_index, new_pos_local)
		if index % HANDLES_PER_POINT == 1:
			river.set_curve_point_in(p_index, new_pos_local - base)
			river.set_curve_point_out(p_index, -(new_pos_local - base))
		if index % HANDLES_PER_POINT == 2:
			river.set_curve_point_out(p_index, new_pos_local - base)
			river.set_curve_point_in(p_index, -(new_pos_local - base))
	
	# Widths handles
	if index % HANDLES_PER_POINT >= 3:
		var p1 = base
		var p2
		if index % HANDLES_PER_POINT == 3:
			p2 = get_width_direction(tangent, 1) * 4096
		if index % HANDLES_PER_POINT == 4:
			p2 = get_width_direction(tangent, -1) * 4096
		var g1: Vector3 = global_inverse * ray_from
		var g2: Vector3 = global_inverse * (ray_from + ray_dir * 4096)
		
		var geo_points = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
		var dir = geo_points[0].distance_to(base) - old_pos.distance_to(base)
		
		var next_widths := river.widths.duplicate(true)
		next_widths[p_index] = max(0.0, river.widths[p_index] + dir)
		river.set_widths(next_widths)
	
	_redraw(gizmo)


func _begin_handle_action(gizmo: EditorNode3DGizmo, _index: int, _secondary: bool) -> void:
	var river := gizmo.get_node_3d() as RiverManager
	_handle_restore_state = river.get_curve_state()
	_handle_restore_bake_valid_state = river.get_generated_bake_valid_state()


# Handle Undo / Redo of handle movements
func _commit_handle(gizmo: EditorNode3DGizmo, index: int, _secondary: bool, restore: Variant, cancel: bool = false) -> void:
	var river := gizmo.get_node_3d() as RiverManager
	var previous_curve_state: Dictionary = _handle_restore_state.duplicate(true)
	if previous_curve_state.is_empty():
		previous_curve_state = _get_restore_state_from_handle_value(river, index, restore)
	var previous_bake_valid_state: Dictionary = _handle_restore_bake_valid_state.duplicate(true)
	if previous_bake_valid_state.is_empty():
		previous_bake_valid_state = river.get_generated_bake_valid_state()
	
	if cancel:
		river.restore_curve_state_with_generated_bake_valid_state(previous_curve_state, previous_bake_valid_state)
		river.properties_changed()
		_handle_restore_state.clear()
		_handle_restore_bake_valid_state.clear()
		reset()
		_redraw(gizmo)
		return
	
	var current_curve_state := river.get_curve_state()
	if current_curve_state == previous_curve_state:
		# Click without drag: state is bitwise-identical, so don't push a
		# "Change River Shape" undo entry or invalidate the bake.
		_handle_restore_state.clear()
		_handle_restore_bake_valid_state.clear()
		reset()
		_redraw(gizmo)
		return

	var ur = editor_plugin.get_undo_redo()
	ur.create_action("Change River Shape", 0, river)

	var current_bake_valid_state := {
		"valid_flowmap": false,
		"shader_i_valid_flowmap": false
	}
	ur.add_do_method(river, "restore_curve_state_with_generated_bake_valid_state", current_curve_state, current_bake_valid_state)
	ur.add_undo_method(river, "restore_curve_state_with_generated_bake_valid_state", previous_curve_state, previous_bake_valid_state)
	
	ur.add_do_method(river, "properties_changed")
	ur.add_do_method(river, "update_configuration_warnings")
	ur.add_undo_method(river, "properties_changed")
	ur.add_undo_method(river, "update_configuration_warnings")
	ur.commit_action()
	
	_handle_restore_state.clear()
	_handle_restore_bake_valid_state.clear()
	reset()
	_redraw(gizmo)


func _get_restore_state_from_handle_value(river: RiverManager, index: int, restore: Variant) -> Dictionary:
	var state := river.get_curve_state()
	var p_index := int(index / HANDLES_PER_POINT)
	if index % HANDLES_PER_POINT == 0:
		var restore_position: Vector3 = restore
		var positions: PackedVector3Array = state["positions"]
		positions[p_index] = restore_position
		state["positions"] = positions
	elif index % HANDLES_PER_POINT == 1:
		var restore_in: Vector3 = restore
		var point_ins: PackedVector3Array = state["point_ins"]
		var point_outs: PackedVector3Array = state["point_outs"]
		point_ins[p_index] = restore_in
		point_outs[p_index] = -restore_in
		state["point_ins"] = point_ins
		state["point_outs"] = point_outs
	elif index % HANDLES_PER_POINT == 2:
		var restore_out: Vector3 = restore
		var point_ins_for_out: PackedVector3Array = state["point_ins"]
		var point_outs_for_out: PackedVector3Array = state["point_outs"]
		point_outs_for_out[p_index] = restore_out
		point_ins_for_out[p_index] = -restore_out
		state["point_ins"] = point_ins_for_out
		state["point_outs"] = point_outs_for_out
	elif index % HANDLES_PER_POINT == 3 or index % HANDLES_PER_POINT == 4:
		var restore_width := float(restore)
		var restored_widths: Array = state["widths"]
		restored_widths[p_index] = restore_width
		state["widths"] = restored_widths
	return state

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	# Work around for issue where using "get_material" doesn't return a
	# material when redraw is being called manually from _set_handle()
	# so I'm caching the materials instead
	if not _path_mat:
		_path_mat = get_material("path", gizmo)
	if not _handle_lines_mat:
		_handle_lines_mat = get_material("handle_lines", gizmo)
	gizmo.clear()
	
	var river := gizmo.get_node_3d() as RiverManager
	
	var redraw_callable := Callable(self, "_redraw").bind(gizmo)
	# Gizmos are freed without a plugin-side callback, so connections bound to
	# dead gizmos accumulate on the river; sweep them before adding ours.
	for connection in river.get_signal_connection_list("river_changed"):
		var connected: Callable = connection["callable"]
		if connected.get_object() != self or connected.get_method() != &"_redraw":
			continue
		var bound_arguments: Array = connected.get_bound_arguments()
		if bound_arguments.size() == 1 and not is_instance_valid(bound_arguments[0]):
			river.disconnect("river_changed", connected)
	if not river.is_connected("river_changed", redraw_callable):
		river.connect("river_changed", redraw_callable)
	
	_draw_path(gizmo, river.curve)
	_draw_handles(gizmo, river)

func _draw_path(gizmo: EditorNode3DGizmo, curve : Curve3D) -> void:
	var path = PackedVector3Array()
	var baked_points = curve.get_baked_points()
	
	for i in baked_points.size() - 1:
		path.append(baked_points[i])
		path.append(baked_points[i + 1])
	
	gizmo.add_lines(path, _path_mat)

func _draw_handles(gizmo: EditorNode3DGizmo, river : RiverManager) -> void:
	var handles = PackedVector3Array()
	var lines = PackedVector3Array()
	for i in river.curve.get_point_count():
		var point_pos = river.curve.get_point_position(i)
		var point_pos_in = river.curve.get_point_in(i) + point_pos
		var point_pos_out = river.curve.get_point_out(i) + point_pos
		var tangent := get_point_tangent(river.curve, i)
		var point_width_pos_right = point_pos + get_width_direction(tangent, 1) * river.widths[i]
		var point_width_pos_left = point_pos + get_width_direction(tangent, -1) * river.widths[i]
		
		handles.push_back(point_pos)
		handles.push_back(point_pos_in)
		handles.push_back(point_pos_out)
		handles.push_back(point_width_pos_right)
		handles.push_back(point_width_pos_left)
		
		lines.push_back(point_pos)
		lines.push_back(point_pos_in)
		lines.push_back(point_pos)
		lines.push_back(point_pos_out)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_right)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_left)
		
	gizmo.add_lines(lines, _handle_lines_mat)
	gizmo.add_handles(handles, get_material("handles", gizmo), PackedInt32Array())
