# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends SubViewport

const HEIGHT_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_height.gdshader"
const FLOW_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_flow.gdshader"
const ALPHA_SHADER_PATH = "res://addons/waterways/shaders/system_renders/alpha.gdshader"

var _camera : Camera3D
var _container : Node3D
var _height_shader : Shader
var _flow_shader : Shader
var _alpha_shader : Shader
var last_readback_error := ""


func grab_height(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	return await _grab(water_objects, aabb, resolution, "height")


func grab_alpha(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	return await _grab(water_objects, aabb, resolution, "alpha")


func grab_flow(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	return await _grab(water_objects, aabb, resolution, "flow")


func _grab(water_objects, aabb: AABB, resolution: float, grab_name: String) -> ImageTexture:
	size = Vector2i(int(resolution), int(resolution))
	own_world_3d = true
	debug_draw = Viewport.DEBUG_DRAW_DISABLED
	_camera = $Camera3D
	_container = $Container

	for object in water_objects:
		var water_mesh_copy := _copy_water_mesh(object)
		if water_mesh_copy == null:
			continue
		var grab_material := _make_grab_material(grab_name, object, aabb)
		if grab_material == null:
			continue
		_container.add_child(water_mesh_copy)
		water_mesh_copy.global_transform = object.mesh_instance.global_transform
		water_mesh_copy.material_override = grab_material

	_frame_camera_for_bounds(aabb)

	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame

	var result := _create_output_texture("system_" + grab_name)
	_clear_container()

	return result


func _make_grab_material(grab_name: String, water_object, aabb: AABB) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	match grab_name:
		"height":
			material.shader = _get_height_shader()
			material.set_shader_parameter("lower_bounds", aabb.position.y)
			material.set_shader_parameter("upper_bounds", aabb.end.y)
		"alpha":
			material.shader = _get_alpha_shader()
		"flow":
			material.shader = _get_flow_shader()
			_configure_flow_material(material, water_object)
		_:
			last_readback_error = "unknown system-map grab '" + grab_name + "'"
			return null
	return material


func _configure_flow_material(flow_mat: ShaderMaterial, water_object) -> void:
	flow_mat.set_shader_parameter("flowmap", water_object.flow_foam_noise)
	flow_mat.set_shader_parameter("distmap", water_object.dist_pressure)
	flow_mat.set_shader_parameter("i_terrain_contact_features", water_object.terrain_contact_features)
	flow_mat.set_shader_parameter("i_bank_response_features", water_object.bank_response_features)
	# Defect 1 fix (R2.1): system_flow skips the boundary slide for
	# pressure-projected bakes, same as the river surface shader. The
	# material flag is bound from bake metadata in _apply_bake_data.
	var flow_projected = water_object.get_shader_param("i_flow_projected")
	flow_mat.set_shader_parameter("i_flow_projected", flow_projected != null and bool(flow_projected))
	# Pass the river's values straight through. A null (river material has
	# no such parameter / no override) clears the override on flow_mat, so
	# the uniform default from river_flow_common.gdshaderinc applies - the
	# same include the river shader consumes, so the values cannot diverge
	# (R3.5; this replaced ten hand-mirrored fallback literals).
	flow_mat.set_shader_parameter("flow_base", water_object.get_shader_param("flow_base"))
	flow_mat.set_shader_parameter("flow_steepness", water_object.get_shader_param("flow_steepness"))
	flow_mat.set_shader_parameter("flow_distance", water_object.get_shader_param("flow_distance"))
	flow_mat.set_shader_parameter("flow_pressure", water_object.get_shader_param("flow_pressure"))
	flow_mat.set_shader_parameter("flow_grade_energy", water_object.get_shader_param("flow_grade_energy"))
	flow_mat.set_shader_parameter("flow_bend_bias", water_object.get_shader_param("flow_bend_bias"))
	flow_mat.set_shader_parameter("flow_bank_drag", water_object.get_shader_param("flow_bank_drag"))
	flow_mat.set_shader_parameter("flow_shallow_drag", water_object.get_shader_param("flow_shallow_drag"))
	flow_mat.set_shader_parameter("flow_inside_bend_drag", water_object.get_shader_param("flow_inside_bend_drag"))
	flow_mat.set_shader_parameter("flow_pressure_bank_gate", water_object.get_shader_param("flow_pressure_bank_gate"))
	flow_mat.set_shader_parameter("flow_hard_boundary_pressure", water_object.get_shader_param("flow_hard_boundary_pressure"))
	flow_mat.set_shader_parameter("flow_hard_boundary_slide", water_object.get_shader_param("flow_hard_boundary_slide"))
	flow_mat.set_shader_parameter("flow_hard_boundary_min_downstream", water_object.get_shader_param("flow_hard_boundary_min_downstream"))
	flow_mat.set_shader_parameter("flow_boundary_probe", water_object.get_shader_param("flow_boundary_probe"))
	flow_mat.set_shader_parameter("flow_max", water_object.get_shader_param("flow_max"))
	flow_mat.set_shader_parameter("valid_flowmap", water_object.get_shader_param("i_valid_flowmap"))
	var uv2_sides: int = 1
	var shader_uv2_sides = water_object.get_shader_param("i_uv2_sides")
	if shader_uv2_sides != null:
		uv2_sides = maxi(1, int(shader_uv2_sides))
	flow_mat.set_shader_parameter("uv2_sides", uv2_sides)


func _get_height_shader() -> Shader:
	if _height_shader == null:
		_height_shader = load(HEIGHT_SHADER_PATH) as Shader
	return _height_shader


func _get_alpha_shader() -> Shader:
	if _alpha_shader == null:
		_alpha_shader = load(ALPHA_SHADER_PATH) as Shader
	return _alpha_shader


func _get_flow_shader() -> Shader:
	if _flow_shader == null:
		_flow_shader = load(FLOW_SHADER_PATH) as Shader
	return _flow_shader


func _create_output_texture(pass_label: String) -> ImageTexture:
	var image := _read_viewport_image(pass_label)
	if image == null:
		return null
	var result := ImageTexture.create_from_image(image)
	if result == null or result.get_width() <= 0 or result.get_height() <= 0:
		last_readback_error = pass_label + " output texture creation failed"
		return null
	return result


func _read_viewport_image(pass_label: String) -> Image:
	last_readback_error = ""
	var preflight_error := _get_viewport_readback_preflight_error(pass_label)
	if not preflight_error.is_empty():
		last_readback_error = preflight_error
		return null
	var viewport_texture := get_texture()
	if viewport_texture == null:
		last_readback_error = pass_label + " viewport texture is null"
		return null
	var texture_size := viewport_texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		last_readback_error = pass_label + " viewport texture has invalid size " + str(texture_size)
		return null
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		last_readback_error = pass_label + " viewport image is empty or unreadable"
		return null
	if image.get_width() <= 0 or image.get_height() <= 0:
		last_readback_error = pass_label + " viewport image has invalid size " + str(image.get_size())
		return null
	return image


func _get_viewport_readback_preflight_error(pass_label: String) -> String:
	if not is_inside_tree():
		return pass_label + " renderer is not inside the scene tree"
	if get_tree() == null:
		return pass_label + " renderer has no SceneTree"
	if size.x <= 0 or size.y <= 0:
		return pass_label + " viewport size is invalid " + str(size)
	if String(DisplayServer.get_name()).to_lower() == "headless":
		return pass_label + " viewport readback is unavailable with the headless display server"
	if String(RenderingServer.get_current_rendering_method()).to_lower() == "dummy":
		return pass_label + " viewport readback is unavailable with the dummy rendering method"
	var viewport_rid := get_viewport_rid()
	if not viewport_rid.is_valid():
		return pass_label + " viewport RID is invalid"
	var texture_rid := RenderingServer.viewport_get_texture(viewport_rid)
	if not texture_rid.is_valid():
		return pass_label + " viewport texture RID is invalid"
	return ""


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
