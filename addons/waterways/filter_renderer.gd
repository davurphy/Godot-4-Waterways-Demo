# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends SubViewport

const DILATE_PASS1_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass1.gdshader"
const DILATE_PASS2_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass2.gdshader"
const DILATE_PASS3_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass3.gdshader"
const NORMAL_MAP_PASS_PATH = "res://addons/waterways/shaders/filters/normal_map_pass.gdshader"
const NORMAL_TO_FLOW_PASS_PATH = "res://addons/waterways/shaders/filters/normal_to_flow_filter.gdshader"
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

const PASS_DESCRIPTORS := {
	"combine": {
		shader_path = COMBINE_PASS_PATH,
		textures = {
			"r_texture": {required = true},
			"g_texture": {required = true},
			"b_texture": {default = "black"},
			"a_texture": {default = "white"}
		}
	},
	"dotproduct": {
		shader_path = DOTPRODUCT_PASS_PATH,
		textures = {"input_texture": {required = true}}
	},
	"flow_pressure": {
		shader_path = FLOW_PRESSURE_PASS_PATH,
		textures = {"input_texture": {required = true}}
	},
	"foam": {
		shader_path = FOAM_PASS_PATH,
		textures = {"input_texture": {required = true}}
	},
	"blur_h": {
		shader_path = BLUR_PASS1_PATH,
		textures = {"input_texture": {required = true}}
	},
	"blur_v": {
		shader_path = BLUR_PASS2_PATH,
		textures = {"input_texture": {required = true}}
	},
	"normal_to_flow": {
		shader_path = NORMAL_TO_FLOW_PASS_PATH,
		textures = {"input_texture": {required = true}}
	},
	"obstacle_feature": {
		shader_path = OBSTACLE_FEATURE_MASK_PASS_PATH,
		textures = {
			"baseline_flow_texture": {required = true},
			"normal_texture": {required = true},
			"support_texture": {required = true},
			"bank_response_texture": {default = "black"},
			"terrain_contact_texture": {default = "black"},
			"grade_energy_texture": {default = "white"}
		}
	},
	"bank_response": {
		shader_path = BANK_RESPONSE_FEATURE_MASK_PASS_PATH,
		textures = {
			"baseline_flow_texture": {required = true},
			"terrain_contact_texture": {required = true},
			"grade_energy_texture": {required = true},
			"bend_bias_texture": {required = true}
		}
	},
	"normal": {
		shader_path = NORMAL_MAP_PASS_PATH,
		textures = {"input_texture": {required = true}}
	},
	"dilate_h": {
		shader_path = DILATE_PASS1_PATH,
		textures = {"input_texture": {required = true}}
	},
	"dilate_v": {
		shader_path = DILATE_PASS2_PATH,
		textures = {"input_texture": {required = true}}
	},
	"dilate_fill": {
		shader_path = DILATE_PASS3_PATH,
		textures = {
			"distance_texture": {required = true},
			"color_texture": {default = "white"}
		}
	},
	"occupancy_pack": {
		shader_path = OCCUPANCY_PACK_PASS_PATH,
		textures = {
			"solid_texture": {required = true},
			"proximity_texture": {required = true}
		}
	},
	"flow_divergence": {
		shader_path = FLOW_DIVERGENCE_PASS_PATH,
		hdr = true,
		textures = {
			"flow_texture": {required = true},
			"occupancy_texture": {required = true}
		}
	},
	"flow_pressure_jacobi": {
		shader_path = FLOW_PRESSURE_JACOBI_PASS_PATH,
		hdr = true,
		textures = {
			"pressure_texture": {required = true},
			"divergence_texture": {required = true},
			"occupancy_texture": {required = true}
		}
	},
	"flow_gradient_subtract": {
		shader_path = FLOW_GRADIENT_SUBTRACT_PASS_PATH,
		hdr = true,
		textures = {
			"flow_texture": {required = true},
			"pressure_texture": {required = true},
			"occupancy_texture": {required = true}
		}
	},
	"flow_boundary_tangency": {
		shader_path = FLOW_BOUNDARY_TANGENCY_PASS_PATH,
		hdr = true,
		textures = {
			"flow_texture": {required = true},
			"occupancy_texture": {required = true}
		}
	},
	"flow_speed_scale": {
		shader_path = FLOW_SPEED_SCALE_PASS_PATH,
		textures = {
			"flow_texture": {required = true},
			"speed_texture": {required = true}
		}
	}
}

var filter_mat : ShaderMaterial
var _pass_shaders := {}
var _default_fill_texture : Texture2D
var _default_black_texture : Texture2D
var last_readback_error := ""


func _enter_tree() -> void:
	filter_mat = ShaderMaterial.new()
	$ColorRect.material = filter_mat


func apply_combine(r_texture : Texture2D, g_texture : Texture2D, b_texture : Texture2D = null, a_texture : Texture2D = null) -> ImageTexture:
	return await _run_pass("combine", r_texture, {
		"r_texture": r_texture,
		"g_texture": g_texture,
		"b_texture": b_texture,
		"a_texture": a_texture
	})


func apply_dotproduct(input_texture : Texture2D) -> ImageTexture:
	return await _run_pass("dotproduct", input_texture, {"input_texture": input_texture})


func apply_flow_pressure(input_texture : Texture2D, resolution : float, rows : float) -> ImageTexture:
	return await _run_pass("flow_pressure", input_texture, {"input_texture": input_texture}, {
		"size": resolution,
		"rows": rows
	})


func apply_foam(input_texture : Texture2D, distance : float, cutoff : float) -> ImageTexture:
	return await _run_pass("foam", input_texture, {"input_texture": input_texture}, {
		"offset": distance,
		"cutoff": cutoff
	})


func apply_blur(input_texture : Texture2D, blur : float, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	var pass1_result := await _run_pass("blur_h", input_texture, {"input_texture": input_texture}, {
		"size": resolution,
		"blur": blur,
		"atlas_columns": atlas_columns
	})
	if pass1_result == null:
		return null
	return await _run_pass("blur_v", pass1_result, {"input_texture": pass1_result}, {
		"size": resolution,
		"blur": blur
	})


func apply_vertical_blur(input_texture : Texture2D, blur : float, resolution : float) -> ImageTexture:
	return await _run_pass("blur_v", input_texture, {"input_texture": input_texture}, {
		"size": resolution,
		"blur": blur
	})


func apply_normal_to_flow(input_texture : Texture2D) -> ImageTexture:
	return await _run_pass("normal_to_flow", input_texture, {"input_texture": input_texture})


func apply_obstacle_feature_mask(baseline_flow_texture: Texture2D, normal_texture: Texture2D, support_texture: Texture2D, bank_response_texture: Texture2D, support_start: float, support_full: float, facing_start: float, facing_full: float, wake_length_uv: float, wake_width_uv: float, side_width_uv: float, wake_start: float, wake_full: float, bank_friction_suppression: float, hard_boundary_wake_gate: float, confidence_start: float, confidence_full: float, terrain_contact_texture: Texture2D = null, grade_energy_texture: Texture2D = null, eddy_line_edge_start: float = 0.04, eddy_line_edge_full: float = 0.22, eddy_line_wake_start: float = 0.06, eddy_line_wake_full: float = 0.28, eddy_line_hard_gate_start: float = 0.06, eddy_line_hard_gate_full: float = 0.40, eddy_line_energy_gate_start: float = 0.03, eddy_line_energy_gate_full: float = 0.35, eddy_line_support_reject_start: float = 0.62, eddy_line_support_reject_full: float = 0.92, pillow_support_start: float = 0.40, pillow_support_full: float = 0.88, pillow_contact_search_uv: float = 0.01, pillow_contact_gate_start: float = 0.08, pillow_contact_gate_full: float = 0.38, atlas_columns: float = 1.0) -> ImageTexture:
	return await _run_pass("obstacle_feature", baseline_flow_texture, {
		"baseline_flow_texture": baseline_flow_texture,
		"normal_texture": normal_texture,
		"support_texture": support_texture,
		"bank_response_texture": bank_response_texture,
		"terrain_contact_texture": terrain_contact_texture,
		"grade_energy_texture": grade_energy_texture
	}, {
		"support_start": support_start,
		"support_full": support_full,
		"facing_start": facing_start,
		"facing_full": facing_full,
		"pillow_support_start": pillow_support_start,
		"pillow_support_full": pillow_support_full,
		"pillow_contact_search_uv": pillow_contact_search_uv,
		"pillow_contact_gate_start": pillow_contact_gate_start,
		"pillow_contact_gate_full": pillow_contact_gate_full,
		"wake_length_uv": wake_length_uv,
		"wake_width_uv": wake_width_uv,
		"side_width_uv": side_width_uv,
		"wake_start": wake_start,
		"wake_full": wake_full,
		"bank_friction_suppression": bank_friction_suppression,
		"hard_boundary_wake_gate": hard_boundary_wake_gate,
		"confidence_start": confidence_start,
		"confidence_full": confidence_full,
		"eddy_line_edge_start": eddy_line_edge_start,
		"eddy_line_edge_full": eddy_line_edge_full,
		"eddy_line_wake_start": eddy_line_wake_start,
		"eddy_line_wake_full": eddy_line_wake_full,
		"eddy_line_hard_gate_start": eddy_line_hard_gate_start,
		"eddy_line_hard_gate_full": eddy_line_hard_gate_full,
		"eddy_line_energy_gate_start": eddy_line_energy_gate_start,
		"eddy_line_energy_gate_full": eddy_line_energy_gate_full,
		"eddy_line_support_reject_start": eddy_line_support_reject_start,
		"eddy_line_support_reject_full": eddy_line_support_reject_full,
		"atlas_columns": atlas_columns
	})


func apply_bank_response_feature_mask(baseline_flow_texture: Texture2D, terrain_contact_texture: Texture2D, grade_energy_texture: Texture2D, bend_bias_texture: Texture2D, probe_uv: float, friction_contact_weight: float, friction_shallow_weight: float, hard_protrusion_weight: float, outside_bend_start: float, outside_bend_full: float, inside_bend_start: float, inside_bend_full: float, atlas_columns: float = 1.0) -> ImageTexture:
	return await _run_pass("bank_response", baseline_flow_texture, {
		"baseline_flow_texture": baseline_flow_texture,
		"terrain_contact_texture": terrain_contact_texture,
		"grade_energy_texture": grade_energy_texture,
		"bend_bias_texture": bend_bias_texture
	}, {
		"probe_uv": probe_uv,
		"friction_contact_weight": friction_contact_weight,
		"friction_shallow_weight": friction_shallow_weight,
		"hard_protrusion_weight": hard_protrusion_weight,
		"outside_bend_start": outside_bend_start,
		"outside_bend_full": outside_bend_full,
		"inside_bend_start": inside_bend_start,
		"inside_bend_full": inside_bend_full,
		"atlas_columns": atlas_columns
	})


func apply_normal(input_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	return await _run_pass("normal", input_texture, {"input_texture": input_texture}, {
		"size": resolution,
		"atlas_columns": atlas_columns
	})


func apply_dilate(input_texture : Texture2D, dilation : float, fill : float, resolution : float, fill_texture : Texture2D = null, atlas_columns : float = 1.0) -> ImageTexture:
	var pass1_result := await _run_pass("dilate_h", input_texture, {"input_texture": input_texture}, {
		"size": resolution,
		"dilation": dilation,
		"atlas_columns": atlas_columns
	})
	if pass1_result == null:
		return null
	var pass2_result := await _run_pass("dilate_v", pass1_result, {"input_texture": pass1_result}, {
		"size": resolution,
		"dilation": dilation
	})
	if pass2_result == null:
		return null
	return await _run_pass("dilate_fill", pass2_result, {
		"distance_texture": pass2_result,
		"color_texture": fill_texture
	}, {
		"fill": fill
	})


func apply_proximity(input_texture : Texture2D, dilation : float, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	# Dilate passes 1+2 only: returns the raw proximity field (R = 1 at solid
	# texels, falling linearly to 0 at the dilation radius) without the pass 3
	# threshold/fill step.
	var pass1_result := await _run_pass("dilate_h", input_texture, {"input_texture": input_texture}, {
		"size": resolution,
		"dilation": dilation,
		"atlas_columns": atlas_columns
	})
	if pass1_result == null:
		return null
	return await _run_pass("dilate_v", pass1_result, {"input_texture": pass1_result}, {
		"size": resolution,
		"dilation": dilation
	})


func apply_occupancy_pack(solid_texture : Texture2D, proximity_texture : Texture2D) -> ImageTexture:
	return await _run_pass("occupancy_pack", solid_texture, {
		"solid_texture": solid_texture,
		"proximity_texture": proximity_texture
	})


func set_hdr_2d(enabled : bool) -> void:
	# Retained for older call sites; descriptor entries now own HDR selection.
	use_hdr_2d = enabled


func apply_flow_divergence(flow_texture : Texture2D, occupancy_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	return await _run_pass("flow_divergence", flow_texture, {
		"flow_texture": flow_texture,
		"occupancy_texture": occupancy_texture
	}, {
		"size": resolution,
		"atlas_columns": atlas_columns
	})


func apply_flow_pressure_jacobi(pressure_texture : Texture2D, divergence_texture : Texture2D, occupancy_texture : Texture2D, stride : float, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	return await _run_pass("flow_pressure_jacobi", pressure_texture, {
		"pressure_texture": pressure_texture,
		"divergence_texture": divergence_texture,
		"occupancy_texture": occupancy_texture
	}, {
		"stride": stride,
		"size": resolution,
		"atlas_columns": atlas_columns
	})


func apply_flow_gradient_subtract(flow_texture : Texture2D, pressure_texture : Texture2D, occupancy_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	return await _run_pass("flow_gradient_subtract", flow_texture, {
		"flow_texture": flow_texture,
		"pressure_texture": pressure_texture,
		"occupancy_texture": occupancy_texture
	}, {
		"size": resolution,
		"atlas_columns": atlas_columns
	})


func apply_flow_boundary_tangency(flow_texture : Texture2D, occupancy_texture : Texture2D, resolution : float, atlas_columns : float = 1.0) -> ImageTexture:
	return await _run_pass("flow_boundary_tangency", flow_texture, {
		"flow_texture": flow_texture,
		"occupancy_texture": occupancy_texture
	}, {
		"size": resolution,
		"atlas_columns": atlas_columns
	})


func apply_flow_speed_scale(flow_texture : Texture2D, speed_texture : Texture2D, speed_factor_max : float) -> ImageTexture:
	return await _run_pass("flow_speed_scale", flow_texture, {
		"flow_texture": flow_texture,
		"speed_texture": speed_texture
	}, {
		"speed_factor_max": speed_factor_max
	})


func _run_pass(pass_name: String, reference_texture: Texture2D, textures: Dictionary, params: Dictionary = {}) -> ImageTexture:
	var descriptor: Dictionary = PASS_DESCRIPTORS.get(pass_name, {})
	if descriptor.is_empty():
		last_readback_error = pass_name + " pass descriptor is missing"
		return null
	if not _has_valid_reference_texture(reference_texture, pass_name + " reference_texture"):
		return null
	var shader := _get_pass_shader(pass_name, descriptor)
	if shader == null:
		last_readback_error = pass_name + " shader failed to load"
		return null

	filter_mat = ShaderMaterial.new()
	filter_mat.shader = shader
	$ColorRect.material = filter_mat
	size = reference_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size

	if not _bind_pass_textures(pass_name, descriptor, textures):
		return null
	for param_name in params:
		filter_mat.set_shader_parameter(StringName(param_name), params[param_name])

	use_hdr_2d = bool(descriptor.get("hdr", false))
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	return _create_output_texture(pass_name)


func _get_pass_shader(pass_name: String, descriptor: Dictionary) -> Shader:
	if _pass_shaders.has(pass_name):
		return _pass_shaders[pass_name] as Shader
	var shader_path := String(descriptor.get("shader_path", ""))
	var shader := load(shader_path) as Shader
	_pass_shaders[pass_name] = shader
	return shader


func _bind_pass_textures(pass_name: String, descriptor: Dictionary, textures: Dictionary) -> bool:
	var texture_policies: Dictionary = descriptor.get("textures", {})
	for texture_name in texture_policies:
		var texture = textures.get(texture_name, null)
		var resolved := _resolve_pass_texture(pass_name, String(texture_name), texture, texture_policies[texture_name])
		if resolved == null and bool((texture_policies[texture_name] as Dictionary).get("required", false)):
			return false
		if resolved != null and not _has_valid_reference_texture(resolved, pass_name + " " + String(texture_name)):
			return false
		filter_mat.set_shader_parameter(StringName(texture_name), resolved)
	return true


func _resolve_pass_texture(pass_name: String, texture_name: String, texture, policy: Dictionary) -> Texture2D:
	if texture != null:
		return texture as Texture2D
	if bool(policy.get("required", false)):
		last_readback_error = pass_name + " " + texture_name + " is null"
		return null
	var default_name := String(policy.get("default", ""))
	match default_name:
		"black":
			return _get_default_black_texture()
		"white":
			return _get_default_white_texture()
		"":
			return null
	last_readback_error = pass_name + " " + texture_name + " has unknown default policy '" + default_name + "'"
	return null


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
	if texture == null:
		last_readback_error = label + " is null"
		return false
	if texture.get_width() <= 0 or texture.get_height() <= 0:
		last_readback_error = label + " has invalid size"
		return false
	return true


func _get_default_black_texture() -> Texture2D:
	if _default_black_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.BLACK)
		_default_black_texture = ImageTexture.create_from_image(image)
	return _default_black_texture


func _get_default_white_texture() -> Texture2D:
	if _default_fill_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.WHITE)
		_default_fill_texture = ImageTexture.create_from_image(image)
	return _default_fill_texture
