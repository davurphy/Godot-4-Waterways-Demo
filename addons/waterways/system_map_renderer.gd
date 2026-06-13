# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends SubViewport

const HEIGHT_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_height.gdshader"
const FLOW_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_flow.gdshader"
const ALPHA_SHADER_PATH = "res://addons/waterways/shaders/system_renders/alpha.gdshader"

var _camera : Camera3D
var _container : Node3D


func _get_water_shader_float(water_object, param_name: String, fallback: float) -> float:
	if water_object == null or not water_object.has_method("get_shader_param"):
		return fallback
	var value = water_object.get_shader_param(param_name)
	if value == null:
		return fallback
	return float(value)

func grab_height(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2i(int(resolution), int(resolution))
	own_world_3d = true
	debug_draw = Viewport.DEBUG_DRAW_DISABLED
	_camera = $Camera3D
	_container = $Container
	
	var height_mat = ShaderMaterial.new()
	var height_shader := load(HEIGHT_SHADER_PATH) as Shader
	height_mat.shader = height_shader
	height_mat.set_shader_parameter("lower_bounds", aabb.position.y)
	height_mat.set_shader_parameter("upper_bounds", aabb.end.y)
	
	for object in water_objects:
		var water_mesh_copy := _copy_water_mesh(object)
		if water_mesh_copy == null:
			continue
		_container.add_child(water_mesh_copy)
		water_mesh_copy.global_transform = object.mesh_instance.global_transform
		water_mesh_copy.material_override = height_mat
	
	_frame_camera_for_bounds(aabb)
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var height: Image = get_texture().get_image()
	var height_result := ImageTexture.create_from_image(height)
	
	_clear_container()
	
	return height_result


func grab_alpha(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2i(int(resolution), int(resolution))
	own_world_3d = true
	debug_draw = Viewport.DEBUG_DRAW_DISABLED
	_camera = $Camera3D
	_container = $Container
	
	var alpha_mat = ShaderMaterial.new()
	var alpha_shader := load(ALPHA_SHADER_PATH) as Shader
	alpha_mat.shader = alpha_shader
	
	for object in water_objects:
		var water_mesh_copy := _copy_water_mesh(object)
		if water_mesh_copy == null:
			continue
		_container.add_child(water_mesh_copy)
		water_mesh_copy.global_transform = object.mesh_instance.global_transform
		water_mesh_copy.material_override = alpha_mat
	
	_frame_camera_for_bounds(aabb)
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var alpha: Image = get_texture().get_image()
	var alpha_result := ImageTexture.create_from_image(alpha)
	
	_clear_container()
	
	return alpha_result


func grab_flow(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2i(int(resolution), int(resolution))
	own_world_3d = true
	debug_draw = Viewport.DEBUG_DRAW_DISABLED
	_camera = $Camera3D
	_container = $Container
	
	var flow_shader := load(FLOW_SHADER_PATH) as Shader

	for i in water_objects.size():
		var water_mesh_copy := _copy_water_mesh(water_objects[i])
		if water_mesh_copy == null:
			continue
		var flow_mat := ShaderMaterial.new()
		flow_mat.shader = flow_shader
		_container.add_child(water_mesh_copy)
		water_mesh_copy.global_transform = water_objects[i].mesh_instance.global_transform
		water_mesh_copy.material_override = flow_mat
		flow_mat.set_shader_parameter("flowmap", water_objects[i].flow_foam_noise)
		flow_mat.set_shader_parameter("distmap", water_objects[i].dist_pressure)
		flow_mat.set_shader_parameter("i_terrain_contact_features", water_objects[i].terrain_contact_features)
		flow_mat.set_shader_parameter("i_bank_response_features", water_objects[i].bank_response_features)
		# Defect 1 fix (R2.1): system_flow skips the boundary slide for
		# pressure-projected bakes, same as the river surface shader. The
		# material flag is bound from bake metadata in _apply_bake_data.
		var flow_projected = water_objects[i].get_shader_param("i_flow_projected")
		flow_mat.set_shader_parameter("i_flow_projected", flow_projected != null and bool(flow_projected))
		flow_mat.set_shader_parameter("flow_base", water_objects[i].get_shader_param("flow_base"))
		flow_mat.set_shader_parameter("flow_steepness", water_objects[i].get_shader_param("flow_steepness"))
		flow_mat.set_shader_parameter("flow_distance", water_objects[i].get_shader_param("flow_distance"))
		flow_mat.set_shader_parameter("flow_pressure", water_objects[i].get_shader_param("flow_pressure"))
		flow_mat.set_shader_parameter("flow_grade_energy", _get_water_shader_float(water_objects[i], "flow_grade_energy", 1.0))
		flow_mat.set_shader_parameter("flow_bend_bias", _get_water_shader_float(water_objects[i], "flow_bend_bias", 0.5))
		flow_mat.set_shader_parameter("flow_bank_drag", _get_water_shader_float(water_objects[i], "flow_bank_drag", 0.55))
		flow_mat.set_shader_parameter("flow_shallow_drag", _get_water_shader_float(water_objects[i], "flow_shallow_drag", 0.35))
		flow_mat.set_shader_parameter("flow_inside_bend_drag", _get_water_shader_float(water_objects[i], "flow_inside_bend_drag", 0.25))
		flow_mat.set_shader_parameter("flow_pressure_bank_gate", _get_water_shader_float(water_objects[i], "flow_pressure_bank_gate", 0.75))
		flow_mat.set_shader_parameter("flow_hard_boundary_pressure", _get_water_shader_float(water_objects[i], "flow_hard_boundary_pressure", 0.45))
		flow_mat.set_shader_parameter("flow_hard_boundary_slide", _get_water_shader_float(water_objects[i], "flow_hard_boundary_slide", 0.45))
		flow_mat.set_shader_parameter("flow_hard_boundary_min_downstream", _get_water_shader_float(water_objects[i], "flow_hard_boundary_min_downstream", 0.55))
		flow_mat.set_shader_parameter("flow_boundary_probe", _get_water_shader_float(water_objects[i], "flow_boundary_probe", 1.0))
		flow_mat.set_shader_parameter("flow_max", water_objects[i].get_shader_param("flow_max"))
		flow_mat.set_shader_parameter("valid_flowmap", water_objects[i].get_shader_param("i_valid_flowmap"))
		var uv2_sides: int = 1
		var shader_uv2_sides = water_objects[i].get_shader_param("i_uv2_sides")
		if shader_uv2_sides != null:
			uv2_sides = int(shader_uv2_sides)
			if uv2_sides < 1:
				uv2_sides = 1
		flow_mat.set_shader_parameter("uv2_sides", uv2_sides)
	
	_frame_camera_for_bounds(aabb)
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var flow: Image = get_texture().get_image()
	var flow_result := ImageTexture.create_from_image(flow)
	
	_clear_container()
	
	return flow_result


func _copy_water_mesh(water_object) -> MeshInstance3D:
	if water_object == null or water_object.mesh_instance == null:
		push_warning("Skipping WaterSystem bake source without a generated river mesh.")
		return null
	if water_object.mesh_instance.mesh == null:
		push_warning("Skipping WaterSystem bake source with an empty generated river mesh.")
		return null
	return water_object.mesh_instance.duplicate(true) as MeshInstance3D


func _frame_camera_for_bounds(aabb: AABB) -> void:
	var horizontal_size := max(aabb.size.x, aabb.size.z)
	if is_zero_approx(horizontal_size):
		horizontal_size = 1.0
	_camera.position = aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y + 1.0, aabb.size.z * 0.5)
	_camera.size = horizontal_size
	_camera.far = max(aabb.size.y + 2.0, 2.0)


func _clear_container() -> void:
	for child in _container.get_children():
		_container.remove_child(child)
		child.queue_free()
