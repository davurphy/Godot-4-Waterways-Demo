# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends RefCounted

signal materials_changed(visible_material, debug_material)

const RUNTIME_RIPPLE_MATERIAL_PARAMETER_SET = {
	"i_ripple_enabled": true,
	"i_ripple_simulation_texture": true,
	"i_ripple_impulse_texture": true,
	"i_ripple_world_to_uv": true,
	"i_ripple_boundary_mask": true,
	"i_ripple_texel_size": true,
	"i_ripple_normal_strength": true,
	"i_ripple_refraction_strength": true,
	"i_ripple_displacement_strength": true,
	"i_ripple_height_fade_distance": true,
	"i_ripple_boundary_fade": true,
}

var _owner_id := 0
var _owner_node: Node = null
var _original_material: ShaderMaterial = null
var _original_debug_material: ShaderMaterial = null


func apply(owner: Object, visible_material: ShaderMaterial, debug_material: ShaderMaterial, parameters: Dictionary) -> Dictionary:
	if owner == null:
		return _make_result(false, "Cannot apply runtime ripple material state without an owner.")
	if visible_material == null:
		return _make_result(false, "Cannot apply runtime ripple material state because the river has no ShaderMaterial.")

	var validation_error := _validate_runtime_ripple_material_parameters(parameters)
	if not validation_error.is_empty():
		return _make_result(false, validation_error)
	if parameters.is_empty():
		return _make_result(true)

	var owner_instance_id := owner.get_instance_id()
	if _owner_id != 0 and _owner_id != owner_instance_id:
		return _make_result(false, "Cannot apply runtime ripple material state because another ripple owner already controls this river.")

	var parameter_names := _get_runtime_ripple_parameter_names(parameters)
	if not _shader_material_has_parameters(visible_material, parameter_names):
		return _make_result(false, "Cannot apply runtime ripple material state because the river material does not declare all requested i_ripple_* uniforms.")

	var applied_visible_material := visible_material
	var applied_debug_material := debug_material
	if _owner_id == 0:
		applied_visible_material = _duplicate_runtime_ripple_material(visible_material)
		if applied_visible_material == null:
			return _make_result(false, "Cannot apply runtime ripple material state because the visible material could not be duplicated.")
		if debug_material != null:
			applied_debug_material = _duplicate_runtime_ripple_material(debug_material)
			if applied_debug_material == null:
				return _make_result(false, "Cannot apply runtime ripple material state because the debug material could not be duplicated.")
		_owner_id = owner_instance_id
		_connect_runtime_ripple_owner(owner)
		_original_material = visible_material
		_original_debug_material = debug_material

	_apply_runtime_ripple_parameters(applied_visible_material, parameters)
	_apply_runtime_ripple_parameters(applied_debug_material, parameters)
	return _make_result(true, "", true, applied_visible_material, applied_debug_material)


func clear(owner: Object) -> Dictionary:
	if _owner_id == 0:
		return _make_result(true)
	if owner == null or owner.get_instance_id() != _owner_id:
		return _make_result(false, "Ignoring runtime ripple material clear from a non-owner.")
	return restore()


func restore() -> Dictionary:
	if _owner_id == 0:
		return _make_result(true)
	_disconnect_runtime_ripple_owner()
	var restored_material := _original_material
	var restored_debug_material := _original_debug_material
	_owner_id = 0
	_original_material = null
	_original_debug_material = null
	return _make_result(true, "", true, restored_material, restored_debug_material)


func has_state(owner: Object = null) -> bool:
	if _owner_id == 0:
		return false
	if owner == null:
		return true
	return owner.get_instance_id() == _owner_id


static func get_shader_parameter_name_set(shader: Shader) -> Dictionary:
	var names := {}
	if shader == null:
		return names
	var parameters: Array = RenderingServer.get_shader_parameter_list(shader.get_rid())
	for parameter in parameters:
		names[String(parameter.name)] = true
	return names


func _make_result(ok: bool, warning: String = "", refresh: bool = false, visible_material: ShaderMaterial = null, debug_material: ShaderMaterial = null) -> Dictionary:
	return {
		"ok": ok,
		"warning": warning,
		"refresh": refresh,
		"visible_material": visible_material,
		"debug_material": debug_material,
	}


func _validate_runtime_ripple_material_parameters(parameters: Dictionary) -> String:
	for parameter_name_variant in parameters.keys():
		var parameter_name := String(parameter_name_variant)
		if not parameter_name.begins_with("i_ripple_"):
			return "Runtime ripple material state may only set i_ripple_* uniforms; rejected " + parameter_name + "."
		if not RUNTIME_RIPPLE_MATERIAL_PARAMETER_SET.has(parameter_name):
			return "Runtime ripple material state rejected unknown ripple uniform " + parameter_name + "."
	return ""


func _get_runtime_ripple_parameter_names(parameters: Dictionary) -> PackedStringArray:
	var names := PackedStringArray()
	for parameter_name_variant in parameters.keys():
		names.append(String(parameter_name_variant))
	return names


func _shader_material_has_parameters(material: ShaderMaterial, parameter_names: PackedStringArray) -> bool:
	if material == null or material.shader == null:
		return false
	var shader_parameters := get_shader_parameter_name_set(material.shader)
	for parameter_name in parameter_names:
		if not shader_parameters.has(parameter_name):
			return false
	return true


func _duplicate_runtime_ripple_material(source: ShaderMaterial) -> ShaderMaterial:
	if source == null:
		return null
	var duplicate := source.duplicate(true) as ShaderMaterial
	if duplicate == null:
		return null
	duplicate.resource_local_to_scene = true
	if source.resource_name.is_empty():
		duplicate.resource_name = "RuntimeRippleMaterial"
	else:
		duplicate.resource_name = source.resource_name + " RuntimeRipple"
	return duplicate


func _apply_runtime_ripple_parameters(material: ShaderMaterial, parameters: Dictionary) -> void:
	if material == null or material.shader == null:
		return
	var shader_parameters := get_shader_parameter_name_set(material.shader)
	for parameter_name_variant in parameters.keys():
		var parameter_name := String(parameter_name_variant)
		if shader_parameters.has(parameter_name):
			material.set_shader_parameter(parameter_name, parameters[parameter_name_variant])


func _connect_runtime_ripple_owner(owner: Object) -> void:
	if not owner is Node:
		return
	_owner_node = owner as Node
	var callback := Callable(self, "_on_runtime_ripple_owner_tree_exiting")
	if not _owner_node.is_connected("tree_exiting", callback):
		_owner_node.connect("tree_exiting", callback)


func _disconnect_runtime_ripple_owner() -> void:
	if _owner_node == null or not is_instance_valid(_owner_node):
		_owner_node = null
		return
	var callback := Callable(self, "_on_runtime_ripple_owner_tree_exiting")
	if _owner_node.is_connected("tree_exiting", callback):
		_owner_node.disconnect("tree_exiting", callback)
	_owner_node = null


func _on_runtime_ripple_owner_tree_exiting() -> void:
	var result := restore()
	if bool(result.get("refresh", false)):
		emit_signal("materials_changed", result.get("visible_material"), result.get("debug_material"))
