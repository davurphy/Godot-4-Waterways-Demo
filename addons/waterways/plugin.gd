# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends EditorPlugin

const WaterHelperMethods = preload("./water_helper_methods.gd")
const WaterSystem = preload("./water_system_manager.gd")
const RiverManager = preload("./river_manager.gd")
const RiverGizmo = preload("./river_gizmo.gd")
const RippleGizmo = preload("./ripple_gizmo.gd")
const GradientInspector = preload("./inspector_plugin.gd")
const RippleInspector = preload("./ripple_inspector_plugin.gd")
const ProgressWindow = preload("./progress_window.tscn")
const RiverControls = preload("./gui/river_controls.gd")

var river_gizmo = RiverGizmo.new()
var ripple_gizmo = RippleGizmo.new()
var gradient_inspector = GradientInspector.new()
var ripple_inspector = RippleInspector.new()

var _river_controls = null
var _water_system_controls = null
var _edited_node = null
var _progress_window = null
var _progress_source: RiverManager = null
var _editor_selection : EditorSelection = null
var _heightmap_renderer = null
var _mode := "select"
var constraint: int = RiverControls.CONSTRAINTS.NONE
var local_editing := false


func _enter_tree() -> void:
	_ensure_control_instances()
	add_custom_type("River", "Node3D", preload("./river_manager.gd"), preload("./icons/river.svg"))
	add_custom_type("WaterSystem", "Node3D", preload("./water_system_manager.gd"), preload("./icons/system.svg"))
	add_custom_type("Buoyant", "Node3D", preload("./buoyant_manager.gd"), preload("./icons/buoyant.svg"))
	add_node_3d_gizmo_plugin(river_gizmo)
	add_node_3d_gizmo_plugin(ripple_gizmo)
	add_inspector_plugin(gradient_inspector)
	ripple_gizmo.set_undo_redo_manager(get_undo_redo())
	ripple_inspector.set_undo_redo_manager(get_undo_redo())
	add_inspector_plugin(ripple_inspector)
	river_gizmo.editor_plugin = self
	_connect_once(_river_controls, "mode", Callable(self, "_on_mode_change"))
	_connect_once(_river_controls, "options", Callable(self, "_on_option_change"))
	_editor_selection = get_editor_interface().get_selection()
	_connect_once(_editor_selection, "selection_changed", Callable(self, "_on_selection_change"))
	_connect_once(self, "scene_changed", Callable(self, "_on_scene_changed"))
	_connect_once(self, "scene_closed", Callable(self, "_on_scene_closed"))


func _on_generate_flowmap_pressed() -> void:
	if _edited_node is RiverManager:
		if _edited_node.is_bake_in_progress():
			_edited_node.bake_texture()
			return
		_edited_node.bake_texture()
		_mark_current_scene_unsaved()


func _on_generate_mesh_pressed() -> void:
	if _edited_node is RiverManager:
		_edited_node.spawn_mesh()


func _on_validate_river_data_textures_pressed() -> void:
	if _edited_node is RiverManager:
		_edited_node.validate_data_textures()


func _on_validate_filter_renderer_pressed() -> void:
	if _edited_node is RiverManager:
		_edited_node.validate_filter_renderer()


func _on_debug_view_changed(index : int) -> void:
	if _edited_node is RiverManager:
		_edited_node.set_debug_view(index)


func _sync_debug_view_menu_selection() -> void:
	if not (_edited_node is RiverManager):
		return
	var debug_menu = _get_debug_view_menu()
	if debug_menu != null:
		debug_menu.set_debug_view_menu_selected(_edited_node.debug_view)


func _on_generate_system_maps_pressed() -> void:
	if _edited_node is WaterSystem:
		if _edited_node.is_bake_in_progress():
			_edited_node.generate_system_maps()
			return
		_edited_node.generate_system_maps()
		_mark_current_scene_unsaved()


func _on_validate_system_map_sampling_pressed() -> void:
	if _edited_node is WaterSystem:
		_edited_node.validate_generated_map_sampling()


func _exit_tree() -> void:
	_clear_editing_state()
	_disconnect_if_connected(_river_controls, "mode", Callable(self, "_on_mode_change"))
	_disconnect_if_connected(_river_controls, "options", Callable(self, "_on_option_change"))
	_disconnect_if_connected(_editor_selection, "selection_changed", Callable(self, "_on_selection_change"))
	_disconnect_if_connected(self, "scene_changed", Callable(self, "_on_scene_changed"))
	_disconnect_if_connected(self, "scene_closed", Callable(self, "_on_scene_closed"))
	remove_custom_type("River")
	remove_custom_type("WaterSystem")
	remove_custom_type("Buoyant")
	remove_node_3d_gizmo_plugin(river_gizmo)
	remove_node_3d_gizmo_plugin(ripple_gizmo)
	remove_inspector_plugin(gradient_inspector)
	remove_inspector_plugin(ripple_inspector)
	ripple_gizmo.set_undo_redo_manager(null)
	ripple_inspector.clear_transient_state()
	ripple_inspector.set_undo_redo_manager(null)
	_free_control_instances()
	_editor_selection = null


func _clear() -> void:
	_clear_editing_state()


func _make_visible(visible: bool) -> void:
	if visible:
		_on_selection_change()
	else:
		_clear_editing_state()


func _handles(node: Object) -> bool:
	return node is RiverManager or node is WaterSystem


func _edit(node: Object) -> void:
	if node == null:
		_clear_editing_state()
		return
	if node is RiverManager:
		_edited_node = node as RiverManager
		_show_river_control_panel()
		_sync_debug_view_menu_selection()
		_set_progress_source(_edited_node)
		_hide_water_system_control_panel()
	elif node is WaterSystem:
		_edited_node = node as WaterSystem
		_show_water_system_control_panel()
		_set_progress_source(null)
		_hide_river_control_panel()
	else:
		_clear_editing_state()


func _on_selection_change() -> void:
	_editor_selection = get_editor_interface().get_selection()
	var selected = _editor_selection.get_selected_nodes()
	if len(selected) == 0:
		_edited_node = null
		_set_progress_source(null)
		_hide_river_control_panel()
		_hide_water_system_control_panel()
		return
	if selected[0] is RiverManager:
		_edited_node = selected[0] as RiverManager
		_show_river_control_panel()
		_sync_debug_view_menu_selection()
		_set_progress_source(_edited_node)
		_hide_water_system_control_panel()
	elif selected[0] is WaterSystem:
		_edited_node = selected[0] as WaterSystem
		_show_water_system_control_panel()
		_set_progress_source(null)
		_hide_river_control_panel()
	else:
		_edited_node = null
		_set_progress_source(null)
		_hide_river_control_panel()
		_hide_water_system_control_panel()


func _on_scene_changed(scene_root : Node) -> void:
	_clear_editing_state()


func _on_scene_closed(_value) -> void:
	_clear_editing_state()


func _on_mode_change(mode) -> void:
	_mode = mode


func _on_option_change(option, value) -> void:
	if option == "constraint":
		constraint = value
		if constraint == RiverControls.CONSTRAINTS.COLLIDERS and _edited_node != null:
			WaterHelperMethods.reset_all_colliders(_edited_node.get_tree().root)
	elif option == "local_mode":
		local_editing = value


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _edited_node:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not (_edited_node is RiverManager):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	var global_transform: Transform3D = _edited_node.transform
	if _edited_node.is_inside_tree():
		global_transform = _edited_node.get_global_transform()
	var global_inverse: Transform3D = global_transform.affine_inverse()
	
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		
		var ray_from = camera.project_ray_origin(event.position)
		var ray_dir = camera.project_ray_normal(event.position)
		var g1: Vector3 = global_inverse * ray_from
		var g2: Vector3 = global_inverse * (ray_from + ray_dir * 4096)
		
		# Iterate through points to find closest segment
		var curve_points = _edited_node.get_curve_points()
		var closest_distance = 4096.0
		var closest_segment = -1
		
		for point in curve_points.size() -1:
			var p1 = curve_points[point]
			var p2 = curve_points[point + 1]
			var result  = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
			var dist = result[0].distance_to(result[1])
			if dist < closest_distance:
				closest_distance = dist
				closest_segment = point
		
		# Iterate through baked points to find the closest position on the
		# curved path
		var baked_curve_points = _edited_node.curve.get_baked_points()
		var baked_closest_distance = 4096.0
		var baked_closest_point = Vector3()
		var baked_point_found = false
		
		for baked_point in baked_curve_points.size() - 1:
			var p1 = baked_curve_points[baked_point]
			var p2 = baked_curve_points[baked_point + 1]
			var result  = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
			var dist = result[0].distance_to(result[1])
			if dist < 0.1 and dist < baked_closest_distance:
				baked_closest_distance = dist
				baked_closest_point = result[0]
				baked_point_found = true
		
		# In case we were close enough to a line segment to find a segment,
		# but not close enough to the curved line
		if not baked_point_found:
			closest_segment = -1
		
		# We'll use this closest point to add a point in between if on the line
		# and to remove if close to a point
		if _mode == "select":
			if not event.pressed:
				river_gizmo.reset()
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if _mode == "add" and not event.pressed:
			# if we don't have a point on the line, we'll calculate a point
			# based of a plane of the last point of the curve
			if closest_segment == -1:
				var last_index: int = _edited_node.curve.get_point_count() - 1
				var end_pos = _edited_node.curve.get_point_position(last_index)
				var end_pos_global : Vector3 = _edited_node.to_global(end_pos)
					
				var tangent := RiverGizmo.get_point_tangent(_edited_node.curve, last_index)
				var _handle_base_transform = RiverGizmo.make_handle_base_transform(tangent, global_transform.basis, end_pos_global)
			
				var plane := Plane(end_pos_global, end_pos_global + camera.global_transform.basis.x, end_pos_global + camera.global_transform.basis.y)
				var new_pos: Variant = null
				if constraint == RiverControls.CONSTRAINTS.COLLIDERS:
					var fallback_pos = plane.intersects_ray(ray_from, ray_dir)
					new_pos = RiverGizmo.get_collider_snap_position(_edited_node.get_tree().get_edited_scene_root(), _edited_node.get_world_3d(), ray_from, ray_dir, fallback_pos)
					if new_pos == null:
						new_pos = fallback_pos
				elif constraint == RiverControls.CONSTRAINTS.NONE:
					new_pos = plane.intersects_ray(ray_from, ray_dir)
				
				elif constraint in RiverGizmo.AXIS_MAPPING:
					var axis: Vector3 = RiverGizmo.get_constraint_direction(RiverGizmo.AXIS_MAPPING[constraint], local_editing, _handle_base_transform)
					var axis_from = end_pos_global + (axis * RiverGizmo.AXIS_CONSTRAINT_LENGTH)
					var axis_to = end_pos_global - (axis * RiverGizmo.AXIS_CONSTRAINT_LENGTH)
					var ray_to = ray_from + (ray_dir * RiverGizmo.AXIS_CONSTRAINT_LENGTH)
					var result = Geometry3D.get_closest_points_between_segments(axis_from, axis_to, ray_from, ray_to)
					new_pos = result[0]
				
				elif constraint in RiverGizmo.PLANE_MAPPING:
					var normal: Vector3 = RiverGizmo.get_constraint_direction(RiverGizmo.PLANE_MAPPING[constraint], local_editing, _handle_base_transform)
					plane = Plane(normal, end_pos_global)
					new_pos = plane.intersects_ray(ray_from, ray_dir)
						
				if new_pos == null:
					return EditorPlugin.AFTER_GUI_INPUT_PASS
				baked_closest_point = _edited_node.to_local(new_pos)
			
			var previous_curve_state: Dictionary = _edited_node.get_curve_state()
			var ur := get_undo_redo()
			ur.create_action("Add River point", 0, _edited_node)
			ur.add_do_method(_edited_node, "add_point", baked_closest_point, closest_segment)
			ur.add_do_method(_edited_node, "properties_changed")
			ur.add_do_method(_edited_node, "set_materials", "i_valid_flowmap", false)
			ur.add_do_property(_edited_node, "valid_flowmap", false)
			ur.add_do_method(_edited_node, "update_configuration_warnings")
			ur.add_undo_method(_edited_node, "restore_curve_state", previous_curve_state)
			ur.add_undo_method(_edited_node, "properties_changed")
			ur.add_undo_method(_edited_node, "set_materials", "i_valid_flowmap", _edited_node.valid_flowmap)
			ur.add_undo_property(_edited_node, "valid_flowmap", _edited_node.valid_flowmap)
			ur.add_undo_method(_edited_node, "update_configuration_warnings")
			ur.commit_action()
		if _mode == "remove" and not event.pressed:
			# A closest_segment of -1 means we didn't press close enough to a
			# point for it to be removed
			if not closest_segment == -1: 
				var closest_index = _edited_node.get_closest_point_to(baked_closest_point)
				#_edited_node.remove_point(closest_index)
				var previous_curve_state: Dictionary = _edited_node.get_curve_state()
				var ur = get_undo_redo()
				ur.create_action("Remove River point", 0, _edited_node)
				ur.add_do_method(_edited_node, "remove_point", closest_index)
				ur.add_do_method(_edited_node, "properties_changed")
				ur.add_do_method(_edited_node, "set_materials", "i_valid_flowmap", false)
				ur.add_do_property(_edited_node, "valid_flowmap", false)
				ur.add_do_method(_edited_node, "update_configuration_warnings")
				ur.add_undo_method(_edited_node, "restore_curve_state", previous_curve_state)
				ur.add_undo_method(_edited_node, "properties_changed")
				ur.add_undo_method(_edited_node, "set_materials", "i_valid_flowmap", _edited_node.valid_flowmap)
				ur.add_undo_property(_edited_node, "valid_flowmap", _edited_node.valid_flowmap)
				ur.add_undo_method(_edited_node, "update_configuration_warnings")
				ur.commit_action()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	elif _edited_node is RiverManager:
		# Forward input to river controls. This is cleaner than handling
		# the keybindings here as the keybindings need to interact with
		# the buttons. Handling it here would expose more private details
		# of the controls than needed, instead only the spatial_gui_input()
		# method needs to be exposed.
		return EditorPlugin.AFTER_GUI_INPUT_STOP if _river_controls.spatial_gui_input(event) else EditorPlugin.AFTER_GUI_INPUT_PASS
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _river_progress_notified(progress : float, message : String) -> void:
	if message == "finished":
		_progress_window.hide()
	
	else:
		if not _progress_window.visible:
			_progress_window.popup_centered()
		
		_progress_window.show_progress(message, progress)


func _set_progress_source(river: RiverManager) -> void:
	var callback := Callable(self, "_river_progress_notified")
	if is_instance_valid(_progress_source) and _progress_source.is_connected("progress_notified", callback):
		_progress_source.disconnect("progress_notified", callback)
	_progress_source = river
	if is_instance_valid(_progress_source) and not _progress_source.is_connected("progress_notified", callback):
		_progress_source.connect("progress_notified", callback)


func _mark_current_scene_unsaved() -> void:
	if not Engine.is_editor_hint():
		return
	var editor_interface: EditorInterface = get_editor_interface()
	if editor_interface != null and editor_interface.has_method("mark_scene_as_unsaved"):
		editor_interface.call("mark_scene_as_unsaved")


func _show_river_control_panel() -> void:
	_ensure_control_instances()
	if not _river_controls.get_parent():
		add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)
	var menu = _get_river_menu()
	var debug_menu = _get_debug_view_menu()
	_connect_once(menu, "generate_flowmap", Callable(self, "_on_generate_flowmap_pressed"))
	_connect_once(menu, "generate_mesh", Callable(self, "_on_generate_mesh_pressed"))
	_connect_once(menu, "validate_data_textures", Callable(self, "_on_validate_river_data_textures_pressed"))
	_connect_once(menu, "validate_filter_renderer", Callable(self, "_on_validate_filter_renderer_pressed"))
	_connect_once(debug_menu, "debug_view_changed", Callable(self, "_on_debug_view_changed"))


func _hide_river_control_panel() -> void:
	if _progress_window != null:
		_progress_window.hide()
	if _river_controls == null:
		return
	var menu = _get_river_menu()
	var debug_menu = _get_debug_view_menu()
	_disconnect_if_connected(menu, "generate_flowmap", Callable(self, "_on_generate_flowmap_pressed"))
	_disconnect_if_connected(menu, "generate_mesh", Callable(self, "_on_generate_mesh_pressed"))
	_disconnect_if_connected(menu, "validate_data_textures", Callable(self, "_on_validate_river_data_textures_pressed"))
	_disconnect_if_connected(menu, "validate_filter_renderer", Callable(self, "_on_validate_filter_renderer_pressed"))
	_disconnect_if_connected(debug_menu, "debug_view_changed", Callable(self, "_on_debug_view_changed"))
	if _river_controls.get_parent():
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)


func _show_water_system_control_panel() -> void:
	_ensure_control_instances()
	if not _water_system_controls.get_parent():
		add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)
	var menu = _get_water_system_menu()
	_connect_once(menu, "generate_system_maps", Callable(self, "_on_generate_system_maps_pressed"))
	_connect_once(menu, "validate_map_sampling", Callable(self, "_on_validate_system_map_sampling_pressed"))


func _hide_water_system_control_panel() -> void:
	if _water_system_controls == null:
		return
	var menu = _get_water_system_menu()
	_disconnect_if_connected(menu, "generate_system_maps", Callable(self, "_on_generate_system_maps_pressed"))
	_disconnect_if_connected(menu, "validate_map_sampling", Callable(self, "_on_validate_system_map_sampling_pressed"))
	if _water_system_controls.get_parent():
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)


func _ensure_control_instances() -> void:
	if _river_controls == null:
		_river_controls = preload("./gui/river_controls.tscn").instantiate()
	if _water_system_controls == null:
		_water_system_controls = preload("./gui/water_system_controls.tscn").instantiate()
	if _progress_window == null:
		_progress_window = ProgressWindow.instantiate()
		_river_controls.add_child(_progress_window)
		_progress_window.hide()


func _free_control_instances() -> void:
	if _river_controls != null:
		if _river_controls.get_parent():
			remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)
		_river_controls.queue_free()
		_river_controls = null
	if _water_system_controls != null:
		if _water_system_controls.get_parent():
			remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)
		_water_system_controls.queue_free()
		_water_system_controls = null
	_progress_window = null


func _clear_editing_state() -> void:
	_edited_node = null
	_set_progress_source(null)
	river_gizmo.reset()
	ripple_inspector.clear_transient_state()
	_hide_river_control_panel()
	_hide_water_system_control_panel()


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source != null and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _disconnect_if_connected(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source != null and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)


func _get_river_menu() -> Object:
	if _river_controls == null:
		return null
	if _river_controls.menu != null:
		return _river_controls.menu
	if _river_controls.has_node("RiverMenu"):
		return _river_controls.get_node("RiverMenu")
	return null


func _get_debug_view_menu() -> Object:
	if _river_controls == null:
		return null
	if _river_controls.debug_view_menu != null:
		return _river_controls.debug_view_menu
	if _river_controls.has_node("DebugViewMenu"):
		return _river_controls.get_node("DebugViewMenu")
	return null


func _get_water_system_menu() -> Object:
	if _water_system_controls == null:
		return null
	if _water_system_controls.menu != null:
		return _water_system_controls.menu
	if _water_system_controls.has_node("WaterSystemMenu"):
		return _water_system_controls.get_node("WaterSystemMenu")
	return null
