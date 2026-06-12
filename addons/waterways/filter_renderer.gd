# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends SubViewport

const DILATE_PASS1_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass1.gdshader"
const DILATE_PASS2_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass2.gdshader"
const DILATE_PASS3_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass3.gdshader"
const NORMAL_MAP_PASS_PATH = "res://addons/waterways/shaders/filters/normal_map_pass.gdshader"
const NORMAL_TO_FLOW_PASS_PATH = "res://addons/waterways/shaders/filters/normal_to_flow_filter.gdshader"
const OBSTACLE_AVOIDANCE_FLOW_PASS_PATH = "res://addons/waterways/shaders/filters/obstacle_avoidance_flow_filter.gdshader"
const OBSTACLE_FEATURE_MASK_PASS_PATH = "res://addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader"
const BANK_RESPONSE_FEATURE_MASK_PASS_PATH = "res://addons/waterways/shaders/filters/bank_response_feature_mask_filter.gdshader"
const BLUR_PASS1_PATH = "res://addons/waterways/shaders/filters/blur_pass1.gdshader"
const BLUR_PASS2_PATH = "res://addons/waterways/shaders/filters/blur_pass2.gdshader"
const FOAM_PASS_PATH = "res://addons/waterways/shaders/filters/foam_pass.gdshader"
const COMBINE_PASS_PATH = "res://addons/waterways/shaders/filters/combine_pass.gdshader"
const DOTPRODUCT_PASS_PATH = "res://addons/waterways/shaders/filters/dotproduct.gdshader"
const FLOW_PRESSURE_PASS_PATH = "res://addons/waterways/shaders/filters/flow_pressure_pass.gdshader"
const OCCUPANCY_PACK_PASS_PATH = "res://addons/waterways/shaders/filters/occupancy_pack_pass.gdshader"
const FLOW_DIVERGENCE_PASS_PATH = "res://addons/waterways/shaders/filters/flow_divergence_pass.gdshader"
const FLOW_PRESSURE_JACOBI_PASS_PATH = "res://addons/waterways/shaders/filters/flow_pressure_jacobi_pass.gdshader"
const FLOW_GRADIENT_SUBTRACT_PASS_PATH = "res://addons/waterways/shaders/filters/flow_gradient_subtract_pass.gdshader"
const FLOW_BOUNDARY_TANGENCY_PASS_PATH = "res://addons/waterways/shaders/filters/flow_boundary_tangency_pass.gdshader"
const FLOW_SPEED_SCALE_PASS_PATH = "res://addons/waterways/shaders/filters/flow_speed_scale_pass.gdshader"


var dilate_pass_1_shader : Shader
var dilate_pass_2_shader : Shader
var dilate_pass_3_shader : Shader
var normal_map_pass_shader : Shader
var normal_to_flow_pass_shader : Shader
var obstacle_avoidance_flow_pass_shader : Shader
var obstacle_feature_mask_pass_shader : Shader
var bank_response_feature_mask_pass_shader : Shader
var blur_pass1_shader : Shader
var blur_pass2_shader : Shader
var foam_pass_shader : Shader
var combine_pass_shader : Shader
var dotproduct_pass_shader : Shader
var flow_pressure_pass_shader : Shader
var occupancy_pack_pass_shader : Shader
var flow_divergence_pass_shader : Shader
var flow_pressure_jacobi_pass_shader : Shader
var flow_gradient_subtract_pass_shader : Shader
var flow_boundary_tangency_pass_shader : Shader
var flow_speed_scale_pass_shader : Shader

var filter_mat : Material
var _default_fill_texture : Texture2D
var _default_black_texture : Texture2D
var last_readback_error := ""


func _enter_tree() -> void:
	dilate_pass_1_shader = load(DILATE_PASS1_PATH) as Shader
	dilate_pass_2_shader = load(DILATE_PASS2_PATH) as Shader
	dilate_pass_3_shader = load(DILATE_PASS3_PATH) as Shader
	normal_map_pass_shader = load(NORMAL_MAP_PASS_PATH) as Shader
	normal_to_flow_pass_shader = load(NORMAL_TO_FLOW_PASS_PATH) as Shader
	obstacle_avoidance_flow_pass_shader = load(OBSTACLE_AVOIDANCE_FLOW_PASS_PATH) as Shader
	obstacle_feature_mask_pass_shader = load(OBSTACLE_FEATURE_MASK_PASS_PATH) as Shader
	bank_response_feature_mask_pass_shader = load(BANK_RESPONSE_FEATURE_MASK_PASS_PATH) as Shader
	blur_pass1_shader = load(BLUR_PASS1_PATH) as Shader
	blur_pass2_shader = load(BLUR_PASS2_PATH) as Shader
	foam_pass_shader = load(FOAM_PASS_PATH) as Shader
	combine_pass_shader = load(COMBINE_PASS_PATH) as Shader
	dotproduct_pass_shader = load(DOTPRODUCT_PASS_PATH) as Shader
	flow_pressure_pass_shader = load(FLOW_PRESSURE_PASS_PATH) as Shader
	occupancy_pack_pass_shader = load(OCCUPANCY_PACK_PASS_PATH) as Shader
	flow_divergence_pass_shader = load(FLOW_DIVERGENCE_PASS_PATH) as Shader
	flow_pressure_jacobi_pass_shader = load(FLOW_PRESSURE_JACOBI_PASS_PATH) as Shader
	flow_gradient_subtract_pass_shader = load(FLOW_GRADIENT_SUBTRACT_PASS_PATH) as Shader
	flow_boundary_tangency_pass_shader = load(FLOW_BOUNDARY_TANGENCY_PASS_PATH) as Shader
	flow_speed_scale_pass_shader = load(FLOW_SPEED_SCALE_PASS_PATH) as Shader

	filter_mat = ShaderMaterial.new()
	
	$ColorRect.material = filter_mat


func apply_combine(r_texture : Texture2D, g_texture : Texture2D, b_texture : Texture2D = null, a_texture : Texture2D = null) -> ImageTexture:
	if not _has_valid_reference_texture(r_texture, "combine r_texture"):
		return null
	if g_texture == null:
		last_readback_error = "combine g_texture is null"
		return null
	filter_mat.shader = combine_pass_shader
	size = r_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("r_texture", r_texture)
	$ColorRect.material.set_shader_parameter("g_texture", g_texture)
	$ColorRect.material.set_shader_parameter("b_texture", b_texture)
	$ColorRect.material.set_shader_parameter("a_texture", a_texture)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("combine")


func apply_dotproduct(input_texture : Texture2D, resolution : float) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "dotproduct input_texture"):
		return null
	filter_mat.shader = dotproduct_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("dotproduct")


func apply_flow_pressure(input_texture : Texture2D, resolution : float, rows : float) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "flow_pressure input_texture"):
		return null
	filter_mat.shader = flow_pressure_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("rows", rows)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("flow_pressure")


func apply_foam(input_texture : Texture2D, distance : float, cutoff : float, resolution : float) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "foam input_texture"):
		return null
	filter_mat.shader = foam_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("offset", distance)
	$ColorRect.material.set_shader_parameter("cutoff", cutoff)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("foam")


func apply_blur(input_texture : Texture2D, blur : float, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "blur input_texture"):
		return null
	filter_mat.shader = blur_pass1_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("blur", blur)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var pass1_result := _create_output_texture("blur pass 1")
	if pass1_result == null:
		return null
	# Pass 2
	filter_mat.shader = blur_pass2_shader
	$ColorRect.material.set_shader_parameter("input_texture", pass1_result)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("blur", blur)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("blur pass 2")


func apply_vertical_blur(input_texture : Texture2D, blur : float, resolution : float) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "vertical_blur input_texture"):
		return null
	filter_mat.shader = blur_pass2_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("blur", blur)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("vertical_blur")


func apply_normal_to_flow(input_texture : Texture2D, resolution : float) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "normal_to_flow input_texture"):
		return null
	filter_mat.shader = normal_to_flow_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("normal_to_flow")


func apply_obstacle_avoidance_flow(baseline_flow_texture : Texture2D, normal_texture : Texture2D, support_texture : Texture2D, bank_response_texture : Texture2D, strength : float, influence_start : float, influence_full : float, upstream_lookahead_uv : float = 0.0, upstream_strength : float = 0.0, min_downstream_alignment : float = 0.0, bank_friction_suppression : float = 0.85, hard_boundary_steering_gate : float = 0.55, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(baseline_flow_texture, "obstacle_avoidance baseline_flow_texture"):
		return null
	if normal_texture == null:
		last_readback_error = "obstacle_avoidance normal_texture is null"
		return null
	if support_texture == null:
		last_readback_error = "obstacle_avoidance support_texture is null"
		return null
	if bank_response_texture == null:
		bank_response_texture = _get_default_black_texture()
	filter_mat.shader = obstacle_avoidance_flow_pass_shader
	size = baseline_flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("baseline_flow_texture", baseline_flow_texture)
	$ColorRect.material.set_shader_parameter("normal_texture", normal_texture)
	$ColorRect.material.set_shader_parameter("support_texture", support_texture)
	$ColorRect.material.set_shader_parameter("bank_response_texture", bank_response_texture)
	$ColorRect.material.set_shader_parameter("strength", strength)
	$ColorRect.material.set_shader_parameter("influence_start", influence_start)
	$ColorRect.material.set_shader_parameter("influence_full", influence_full)
	$ColorRect.material.set_shader_parameter("upstream_lookahead_uv", upstream_lookahead_uv)
	$ColorRect.material.set_shader_parameter("upstream_strength", upstream_strength)
	$ColorRect.material.set_shader_parameter("min_downstream_alignment", min_downstream_alignment)
	$ColorRect.material.set_shader_parameter("bank_friction_suppression", bank_friction_suppression)
	$ColorRect.material.set_shader_parameter("hard_boundary_steering_gate", hard_boundary_steering_gate)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("obstacle_avoidance")


func apply_obstacle_feature_mask(baseline_flow_texture: Texture2D, normal_texture: Texture2D, support_texture: Texture2D, bank_response_texture: Texture2D, support_start: float, support_full: float, facing_start: float, facing_full: float, wake_length_uv: float, wake_width_uv: float, side_width_uv: float, wake_start: float, wake_full: float, bank_friction_suppression: float, hard_boundary_wake_gate: float, confidence_start: float, confidence_full: float, terrain_contact_texture: Texture2D = null, grade_energy_texture: Texture2D = null, eddy_line_edge_start: float = 0.04, eddy_line_edge_full: float = 0.22, eddy_line_wake_start: float = 0.06, eddy_line_wake_full: float = 0.28, eddy_line_hard_gate_start: float = 0.06, eddy_line_hard_gate_full: float = 0.40, eddy_line_energy_gate_start: float = 0.03, eddy_line_energy_gate_full: float = 0.35, eddy_line_support_reject_start: float = 0.62, eddy_line_support_reject_full: float = 0.92, pillow_support_start: float = 0.40, pillow_support_full: float = 0.88, pillow_contact_search_uv: float = 0.01, pillow_contact_gate_start: float = 0.08, pillow_contact_gate_full: float = 0.38, atlas_columns: float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(baseline_flow_texture, "obstacle_feature baseline_flow_texture"):
		return null
	if normal_texture == null:
		last_readback_error = "obstacle_feature normal_texture is null"
		return null
	if support_texture == null:
		last_readback_error = "obstacle_feature support_texture is null"
		return null
	if bank_response_texture == null:
		bank_response_texture = _get_default_black_texture()
	if terrain_contact_texture == null:
		terrain_contact_texture = _get_default_black_texture()
	if grade_energy_texture == null:
		grade_energy_texture = _get_default_white_texture()
	filter_mat.shader = obstacle_feature_mask_pass_shader
	size = baseline_flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("baseline_flow_texture", baseline_flow_texture)
	$ColorRect.material.set_shader_parameter("normal_texture", normal_texture)
	$ColorRect.material.set_shader_parameter("support_texture", support_texture)
	$ColorRect.material.set_shader_parameter("bank_response_texture", bank_response_texture)
	$ColorRect.material.set_shader_parameter("terrain_contact_texture", terrain_contact_texture)
	$ColorRect.material.set_shader_parameter("grade_energy_texture", grade_energy_texture)
	$ColorRect.material.set_shader_parameter("support_start", support_start)
	$ColorRect.material.set_shader_parameter("support_full", support_full)
	$ColorRect.material.set_shader_parameter("facing_start", facing_start)
	$ColorRect.material.set_shader_parameter("facing_full", facing_full)
	$ColorRect.material.set_shader_parameter("pillow_support_start", pillow_support_start)
	$ColorRect.material.set_shader_parameter("pillow_support_full", pillow_support_full)
	$ColorRect.material.set_shader_parameter("pillow_contact_search_uv", pillow_contact_search_uv)
	$ColorRect.material.set_shader_parameter("pillow_contact_gate_start", pillow_contact_gate_start)
	$ColorRect.material.set_shader_parameter("pillow_contact_gate_full", pillow_contact_gate_full)
	$ColorRect.material.set_shader_parameter("wake_length_uv", wake_length_uv)
	$ColorRect.material.set_shader_parameter("wake_width_uv", wake_width_uv)
	$ColorRect.material.set_shader_parameter("side_width_uv", side_width_uv)
	$ColorRect.material.set_shader_parameter("wake_start", wake_start)
	$ColorRect.material.set_shader_parameter("wake_full", wake_full)
	$ColorRect.material.set_shader_parameter("bank_friction_suppression", bank_friction_suppression)
	$ColorRect.material.set_shader_parameter("hard_boundary_wake_gate", hard_boundary_wake_gate)
	$ColorRect.material.set_shader_parameter("confidence_start", confidence_start)
	$ColorRect.material.set_shader_parameter("confidence_full", confidence_full)
	$ColorRect.material.set_shader_parameter("eddy_line_edge_start", eddy_line_edge_start)
	$ColorRect.material.set_shader_parameter("eddy_line_edge_full", eddy_line_edge_full)
	$ColorRect.material.set_shader_parameter("eddy_line_wake_start", eddy_line_wake_start)
	$ColorRect.material.set_shader_parameter("eddy_line_wake_full", eddy_line_wake_full)
	$ColorRect.material.set_shader_parameter("eddy_line_hard_gate_start", eddy_line_hard_gate_start)
	$ColorRect.material.set_shader_parameter("eddy_line_hard_gate_full", eddy_line_hard_gate_full)
	$ColorRect.material.set_shader_parameter("eddy_line_energy_gate_start", eddy_line_energy_gate_start)
	$ColorRect.material.set_shader_parameter("eddy_line_energy_gate_full", eddy_line_energy_gate_full)
	$ColorRect.material.set_shader_parameter("eddy_line_support_reject_start", eddy_line_support_reject_start)
	$ColorRect.material.set_shader_parameter("eddy_line_support_reject_full", eddy_line_support_reject_full)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("obstacle_feature")


func apply_bank_response_feature_mask(baseline_flow_texture: Texture2D, terrain_contact_texture: Texture2D, grade_energy_texture: Texture2D, bend_bias_texture: Texture2D, probe_uv: float, friction_contact_weight: float, friction_shallow_weight: float, hard_protrusion_weight: float, outside_bend_start: float, outside_bend_full: float, inside_bend_start: float, inside_bend_full: float, atlas_columns: float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(baseline_flow_texture, "bank_response baseline_flow_texture"):
		return null
	if terrain_contact_texture == null:
		last_readback_error = "bank_response terrain_contact_texture is null"
		return null
	if grade_energy_texture == null:
		last_readback_error = "bank_response grade_energy_texture is null"
		return null
	if bend_bias_texture == null:
		last_readback_error = "bank_response bend_bias_texture is null"
		return null
	filter_mat.shader = bank_response_feature_mask_pass_shader
	size = baseline_flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("baseline_flow_texture", baseline_flow_texture)
	$ColorRect.material.set_shader_parameter("terrain_contact_texture", terrain_contact_texture)
	$ColorRect.material.set_shader_parameter("grade_energy_texture", grade_energy_texture)
	$ColorRect.material.set_shader_parameter("bend_bias_texture", bend_bias_texture)
	$ColorRect.material.set_shader_parameter("probe_uv", probe_uv)
	$ColorRect.material.set_shader_parameter("friction_contact_weight", friction_contact_weight)
	$ColorRect.material.set_shader_parameter("friction_shallow_weight", friction_shallow_weight)
	$ColorRect.material.set_shader_parameter("hard_protrusion_weight", hard_protrusion_weight)
	$ColorRect.material.set_shader_parameter("outside_bend_start", outside_bend_start)
	$ColorRect.material.set_shader_parameter("outside_bend_full", outside_bend_full)
	$ColorRect.material.set_shader_parameter("inside_bend_start", inside_bend_start)
	$ColorRect.material.set_shader_parameter("inside_bend_full", inside_bend_full)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("bank_response_feature")


func apply_normal(input_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "normal input_texture"):
		return null
	filter_mat.shader = normal_map_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("normal")


func apply_dilate(input_texture : Texture2D, dilation : float, fill : float, resolution : float, fill_texture : Texture2D = null, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(input_texture, "dilate input_texture"):
		return null
	filter_mat.shader = dilate_pass_1_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("dilation", dilation)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var pass1_result := _create_output_texture("dilate pass 1")
	if pass1_result == null:
		return null
	# Pass 2
	filter_mat.shader = dilate_pass_2_shader
	$ColorRect.material.set_shader_parameter("input_texture", pass1_result)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("dilation", dilation)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var pass2_result := _create_output_texture("dilate pass 2")
	if pass2_result == null:
		return null
	# Pass 3
	filter_mat.shader = dilate_pass_3_shader
	$ColorRect.material.set_shader_parameter("distance_texture", pass2_result)
	$ColorRect.material.set_shader_parameter("color_texture", _get_dilate_fill_texture(fill_texture))
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("fill", fill)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("dilate pass 3")


func apply_proximity(input_texture : Texture2D, dilation : float, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	# Dilate passes 1+2 only: returns the raw proximity field (R = 1 at solid
	# texels, falling linearly to 0 at the dilation radius) without the pass 3
	# threshold/fill step.
	if not _has_valid_reference_texture(input_texture, "proximity input_texture"):
		return null
	filter_mat.shader = dilate_pass_1_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("dilation", dilation)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var pass1_result := _create_output_texture("proximity pass 1")
	if pass1_result == null:
		return null
	filter_mat.shader = dilate_pass_2_shader
	$ColorRect.material.set_shader_parameter("input_texture", pass1_result)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("dilation", dilation)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("proximity pass 2")


func apply_occupancy_pack(solid_texture : Texture2D, proximity_texture : Texture2D) -> ImageTexture:
	if not _has_valid_reference_texture(solid_texture, "occupancy solid_texture"):
		return null
	if proximity_texture == null:
		last_readback_error = "occupancy proximity_texture is null"
		return null
	filter_mat.shader = occupancy_pack_pass_shader
	size = solid_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("solid_texture", solid_texture)
	$ColorRect.material.set_shader_parameter("proximity_texture", proximity_texture)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("occupancy_pack")


func set_hdr_2d(enabled : bool) -> void:
	# The pressure projection solve needs float targets - 8-bit render targets
	# quantize the pressure gradients into visible velocity noise.
	use_hdr_2d = enabled


func apply_flow_divergence(flow_texture : Texture2D, occupancy_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(flow_texture, "flow_divergence flow_texture"):
		return null
	if occupancy_texture == null:
		last_readback_error = "flow_divergence occupancy_texture is null"
		return null
	filter_mat.shader = flow_divergence_pass_shader
	size = flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("flow_texture", flow_texture)
	$ColorRect.material.set_shader_parameter("occupancy_texture", occupancy_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("flow_divergence")


func apply_flow_pressure_jacobi(pressure_texture : Texture2D, divergence_texture : Texture2D, occupancy_texture : Texture2D, stride : float, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(pressure_texture, "flow_pressure_jacobi pressure_texture"):
		return null
	if divergence_texture == null:
		last_readback_error = "flow_pressure_jacobi divergence_texture is null"
		return null
	if occupancy_texture == null:
		last_readback_error = "flow_pressure_jacobi occupancy_texture is null"
		return null
	filter_mat.shader = flow_pressure_jacobi_pass_shader
	size = pressure_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("pressure_texture", pressure_texture)
	$ColorRect.material.set_shader_parameter("divergence_texture", divergence_texture)
	$ColorRect.material.set_shader_parameter("occupancy_texture", occupancy_texture)
	$ColorRect.material.set_shader_parameter("stride", stride)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("flow_pressure_jacobi")


func apply_flow_gradient_subtract(flow_texture : Texture2D, pressure_texture : Texture2D, occupancy_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(flow_texture, "flow_gradient_subtract flow_texture"):
		return null
	if pressure_texture == null:
		last_readback_error = "flow_gradient_subtract pressure_texture is null"
		return null
	if occupancy_texture == null:
		last_readback_error = "flow_gradient_subtract occupancy_texture is null"
		return null
	filter_mat.shader = flow_gradient_subtract_pass_shader
	size = flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("flow_texture", flow_texture)
	$ColorRect.material.set_shader_parameter("pressure_texture", pressure_texture)
	$ColorRect.material.set_shader_parameter("occupancy_texture", occupancy_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("flow_gradient_subtract")


func apply_flow_boundary_tangency(flow_texture : Texture2D, occupancy_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	if not _has_valid_reference_texture(flow_texture, "flow_boundary_tangency flow_texture"):
		return null
	if occupancy_texture == null:
		last_readback_error = "flow_boundary_tangency occupancy_texture is null"
		return null
	filter_mat.shader = flow_boundary_tangency_pass_shader
	size = flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("flow_texture", flow_texture)
	$ColorRect.material.set_shader_parameter("occupancy_texture", occupancy_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("atlas_columns", atlas_columns)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("flow_boundary_tangency")


func apply_flow_speed_scale(flow_texture : Texture2D, speed_texture : Texture2D, speed_factor_max : float) -> ImageTexture:
	if not _has_valid_reference_texture(flow_texture, "flow_speed_scale flow_texture"):
		return null
	if speed_texture == null:
		last_readback_error = "flow_speed_scale speed_texture is null"
		return null
	filter_mat.shader = flow_speed_scale_pass_shader
	size = flow_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("flow_texture", flow_texture)
	$ColorRect.material.set_shader_parameter("speed_texture", speed_texture)
	$ColorRect.material.set_shader_parameter("speed_factor_max", speed_factor_max)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture("flow_speed_scale")


func _create_output_texture(pass_label : String) -> ImageTexture:
	var image := _read_viewport_image(pass_label)
	if image == null:
		return null
	var result := ImageTexture.create_from_image(image)
	if result == null or result.get_width() <= 0 or result.get_height() <= 0:
		last_readback_error = pass_label + " output texture creation failed"
		return null
	return result


func _read_viewport_image(pass_label : String) -> Image:
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


func _get_viewport_readback_preflight_error(pass_label : String) -> String:
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


func _has_valid_reference_texture(texture : Texture2D, label : String) -> bool:
	last_readback_error = ""
	if texture == null:
		last_readback_error = label + " is null"
		return false
	if texture.get_width() <= 0 or texture.get_height() <= 0:
		last_readback_error = label + " has invalid size"
		return false
	return true


func _get_dilate_fill_texture(fill_texture : Texture2D) -> Texture2D:
	if fill_texture != null:
		return fill_texture
	if _default_fill_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.WHITE)
		_default_fill_texture = ImageTexture.create_from_image(image)
	return _default_fill_texture


func _get_default_black_texture() -> Texture2D:
	if _default_black_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.BLACK)
		_default_black_texture = ImageTexture.create_from_image(image)
	return _default_black_texture


func _get_default_white_texture() -> Texture2D:
	return _get_dilate_fill_texture(null)
