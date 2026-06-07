extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var probe_root := Node3D.new()
	root.add_child(probe_root)

	var owner_a := Node.new()
	owner_a.name = "RippleOwnerA"
	root.add_child(owner_a)
	var owner_b := Node.new()
	owner_b.name = "RippleOwnerB"
	root.add_child(owner_b)
	var stranger_owner := Node.new()
	stranger_owner.name = "UnrelatedRippleOwner"
	root.add_child(stranger_owner)

	var shared_material := _make_probe_material("SharedProbeRiverMaterial")
	var original_texture := _make_texture(Color(0.05, 0.10, 0.15, 1.0))
	var original_boundary := _make_texture(Color(0.15, 0.10, 0.05, 1.0))
	_set_original_ripple_state(shared_material, original_texture, original_boundary)

	var river_a := RiverManager.new()
	river_a.name = "ProbeRiverA"
	probe_root.add_child(river_a)
	var river_b := RiverManager.new()
	river_b.name = "ProbeRiverB"
	probe_root.add_child(river_b)
	await _settle_frames(4)

	_assign_river_material(river_a, shared_material)
	_assign_river_material(river_b, shared_material)
	await _settle_frames(2)

	_expect(_get_river_material(river_a) == shared_material, "River A should start on the shared material")
	_expect(_get_river_material(river_b) == shared_material, "River B should start on the shared material")

	var texture_a := _make_texture(Color(0.85, 0.05, 0.10, 1.0))
	var boundary_a := _make_texture(Color(0.05, 0.85, 0.10, 1.0))
	var texture_b := _make_texture(Color(0.05, 0.20, 0.90, 1.0))
	var boundary_b := _make_texture(Color(0.90, 0.80, 0.05, 1.0))

	var default_shader_river := RiverManager.new()
	default_shader_river.name = "ProbeDefaultShaderRiver"
	probe_root.add_child(default_shader_river)
	await _settle_frames(3)
	var default_shader_material := _get_river_material(default_shader_river)
	var default_shader_apply := bool(default_shader_river.call("apply_runtime_ripple_material_state", owner_a, _make_runtime_state(texture_a, boundary_a, 0.33)))
	_expect(default_shader_apply, "Default river material should accept declared neutral i_ripple_* runtime state")
	var default_shader_runtime_material := _get_river_material(default_shader_river)
	_expect(default_shader_runtime_material != null and default_shader_runtime_material != default_shader_material, "Default river material should be duplicated before runtime ripple state is applied")
	_expect(_get_shader_param(default_shader_runtime_material, "i_ripple_simulation_texture") == texture_a, "Default river runtime material should receive the ripple texture")
	_expect(_get_shader_param(default_shader_runtime_material, "i_ripple_impulse_texture") == texture_a, "Default river runtime material should receive the impulse/contact texture")
	default_shader_river.call("clear_runtime_ripple_material_state", owner_a)
	await _settle_frames(1)
	_expect(_get_river_material(default_shader_river) == default_shader_material, "Default river clear should restore the original material")
	default_shader_river.queue_free()
	await _settle_frames(1)

	var invalid_non_ripple := bool(river_a.call("apply_runtime_ripple_material_state", owner_a, {"i_flowmap": texture_a}))
	_expect(not invalid_non_ripple, "Runtime ripple API should reject non-ripple i_* uniforms")
	_expect(_get_river_material(river_a) == shared_material, "Rejected non-ripple apply should leave River A on the original shared material")

	var invalid_unknown_ripple := bool(river_a.call("apply_runtime_ripple_material_state", owner_a, {"i_ripple_unplanned": 1.0}))
	_expect(not invalid_unknown_ripple, "Runtime ripple API should reject unknown i_ripple_* uniforms")
	_expect(_get_river_material(river_a) == shared_material, "Rejected unknown ripple apply should leave River A on the original shared material")

	var apply_a := bool(river_a.call("apply_runtime_ripple_material_state", owner_a, _make_runtime_state(texture_a, boundary_a, 0.61)))
	_expect(apply_a, "River A should accept planned i_ripple_* runtime state")
	var river_a_runtime_material := _get_river_material(river_a)
	_expect(river_a_runtime_material != null and river_a_runtime_material != shared_material, "River A should receive a duplicated runtime material")
	_expect(_get_shader_param(river_a_runtime_material, "i_ripple_simulation_texture") == texture_a, "River A runtime material should receive texture A")
	_expect(_get_shader_param(river_a_runtime_material, "i_ripple_impulse_texture") == texture_a, "River A runtime material should receive impulse/contact texture A")
	_expect(_get_shader_param(river_a_runtime_material, "i_ripple_normal_strength") == 0.61, "River A runtime material should receive strength A")
	_expect(_get_river_material(river_b) == shared_material, "River B should remain on the shared material after River A apply")
	_expect(_get_shader_param(shared_material, "i_ripple_simulation_texture") == original_texture, "Shared material should keep its original ripple texture after River A apply")
	_expect(_get_shader_param(shared_material, "i_ripple_impulse_texture") == original_texture, "Shared material should keep its original impulse/contact texture after River A apply")
	_expect(_get_shader_param(shared_material, "i_ripple_normal_strength") == 0.25, "Shared material should keep its original ripple strength after River A apply")

	var wrong_owner_update := bool(river_a.call("apply_runtime_ripple_material_state", owner_b, _make_runtime_state(texture_b, boundary_b, 0.73)))
	_expect(not wrong_owner_update, "A second owner should not be able to replace River A runtime ripple state")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_simulation_texture") == texture_a, "Wrong-owner apply should leave River A texture unchanged")

	river_a.call("set_debug_view", 1)
	await _settle_frames(1)
	river_a.call("set_debug_view", 0)
	await _settle_frames(1)
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_simulation_texture") == texture_a, "Debug view toggle should not drop River A visible ripple state")

	var apply_b := bool(river_b.call("apply_runtime_ripple_material_state", owner_b, _make_runtime_state(texture_b, boundary_b, 0.73)))
	_expect(apply_b, "River B should accept its own planned i_ripple_* runtime state")
	var river_b_runtime_material := _get_river_material(river_b)
	_expect(river_b_runtime_material != null and river_b_runtime_material != shared_material, "River B should receive a duplicated runtime material")
	_expect(river_b_runtime_material != river_a_runtime_material, "River A and River B should not share runtime ripple material duplicates")
	_expect(_get_shader_param(river_b_runtime_material, "i_ripple_simulation_texture") == texture_b, "River B runtime material should receive texture B")
	_expect(_get_shader_param(river_b_runtime_material, "i_ripple_impulse_texture") == texture_b, "River B runtime material should receive impulse/contact texture B")

	river_b.call("clear_runtime_ripple_material_state", stranger_owner)
	var wrong_owner_clear_kept_b: bool = _get_shader_param(_get_river_material(river_b), "i_ripple_simulation_texture") == texture_b
	_expect(bool(river_b.call("has_runtime_ripple_material_state", owner_b)), "Wrong-owner clear should not remove River B runtime state")
	_expect(wrong_owner_clear_kept_b, "Wrong-owner clear should leave River B texture unchanged")

	river_a.call("clear_runtime_ripple_material_state", owner_a)
	await _settle_frames(1)
	_expect(not bool(river_a.call("has_runtime_ripple_material_state")), "River A should report no runtime ripple state after clear")
	_expect(_get_river_material(river_a) == shared_material, "River A clear should restore the original shared material")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_simulation_texture") == original_texture, "River A clear should restore the original ripple texture")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_impulse_texture") == original_texture, "River A clear should restore the original impulse/contact texture")
	_expect(_get_shader_param(_get_river_material(river_b), "i_ripple_simulation_texture") == texture_b, "River A clear should not affect River B runtime texture")

	var apply_a_again := bool(river_a.call("apply_runtime_ripple_material_state", owner_a, _make_runtime_state(texture_a, boundary_a, 0.62)))
	_expect(apply_a_again, "River A should accept runtime state again after clear")
	owner_a.queue_free()
	await _settle_frames(3)
	_expect(not bool(river_a.call("has_runtime_ripple_material_state")), "River A should restore when its ripple owner exits the tree")
	_expect(_get_river_material(river_a) == shared_material, "Owner exit should restore River A original shared material")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_simulation_texture") == original_texture, "Owner exit should clear River A stale runtime texture")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_impulse_texture") == original_texture, "Owner exit should clear River A stale impulse/contact texture")

	var reload_owner := Node.new()
	reload_owner.name = "ReloadLikeRippleOwner"
	root.add_child(reload_owner)
	var apply_before_reload := bool(river_a.call("apply_runtime_ripple_material_state", reload_owner, _make_runtime_state(texture_a, boundary_a, 0.63)))
	_expect(apply_before_reload, "River A should accept runtime state before reload-like exit")
	probe_root.remove_child(river_a)
	await _settle_frames(2)
	_expect(not bool(river_a.call("has_runtime_ripple_material_state")), "River A should restore during its own tree exit")
	_expect(_get_river_material(river_a) == shared_material, "River tree exit should restore the original shared material")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_simulation_texture") == original_texture, "River tree exit should clear stale runtime texture")
	_expect(_get_shader_param(_get_river_material(river_a), "i_ripple_impulse_texture") == original_texture, "River tree exit should clear stale impulse/contact texture")

	river_b.call("clear_runtime_ripple_material_state", owner_b)
	await _settle_frames(1)
	_expect(not bool(river_b.call("has_runtime_ripple_material_state")), "River B should report no runtime ripple state after clear")
	_expect(_get_river_material(river_b) == shared_material, "River B clear should restore the original shared material")
	_expect(_get_shader_param(shared_material, "i_ripple_simulation_texture") == original_texture, "Shared material should finish with its original ripple texture")
	_expect(_get_shader_param(shared_material, "i_ripple_impulse_texture") == original_texture, "Shared material should finish with its original impulse/contact texture")
	_expect(_get_shader_param(shared_material, "i_lod0_distance") == 11.0, "Non-ripple material state should remain untouched")

	_results = {
		"shared_material_restored": _get_shader_param(shared_material, "i_ripple_simulation_texture") == original_texture,
		"shared_impulse_material_restored": _get_shader_param(shared_material, "i_ripple_impulse_texture") == original_texture,
		"river_a_runtime_material_was_duplicate": river_a_runtime_material != null and river_a_runtime_material != shared_material,
		"river_b_runtime_material_was_duplicate": river_b_runtime_material != null and river_b_runtime_material != shared_material,
		"runtime_duplicates_distinct": river_a_runtime_material != null and river_b_runtime_material != null and river_a_runtime_material != river_b_runtime_material,
		"default_shader_apply_accepted": default_shader_apply,
		"wrong_owner_apply_rejected": not wrong_owner_update,
		"wrong_owner_clear_rejected": wrong_owner_clear_kept_b,
	}

	reload_owner.queue_free()
	river_a.queue_free()
	probe_root.queue_free()
	stranger_owner.queue_free()
	owner_b.queue_free()
	await _settle_frames(2)

	print("RIPPLE_MATERIAL_OWNERSHIP_PROBE_RESULTS=", _results)
	_finish()


func _make_probe_material(material_name: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;

uniform bool i_ripple_enabled = false;
uniform sampler2D i_ripple_simulation_texture;
uniform sampler2D i_ripple_impulse_texture;
uniform mat4 i_ripple_world_to_uv = mat4(1.0);
uniform sampler2D i_ripple_boundary_mask;
uniform vec2 i_ripple_texel_size = vec2(0.0);
uniform float i_ripple_normal_strength = 0.0;
uniform float i_ripple_refraction_strength = 0.0;
uniform float i_ripple_displacement_strength = 0.0;
uniform float i_ripple_height_fade_distance = 0.0;
uniform float i_ripple_boundary_fade = 0.0;
uniform float i_lod0_distance = 5.0;
uniform sampler2D i_flowmap;

void fragment() {
	ALBEDO = vec3(0.1, 0.2, 0.3);
}
"""
	var material := ShaderMaterial.new()
	material.resource_name = material_name
	material.shader = shader
	return material


func _set_original_ripple_state(material: ShaderMaterial, texture: Texture2D, boundary: Texture2D) -> void:
	material.set_shader_parameter("i_ripple_enabled", false)
	material.set_shader_parameter("i_ripple_simulation_texture", texture)
	material.set_shader_parameter("i_ripple_impulse_texture", texture)
	material.set_shader_parameter("i_ripple_world_to_uv", Transform3D.IDENTITY)
	material.set_shader_parameter("i_ripple_boundary_mask", boundary)
	material.set_shader_parameter("i_ripple_texel_size", Vector2(0.25, 0.25))
	material.set_shader_parameter("i_ripple_normal_strength", 0.25)
	material.set_shader_parameter("i_ripple_refraction_strength", 0.0)
	material.set_shader_parameter("i_ripple_displacement_strength", 0.0)
	material.set_shader_parameter("i_ripple_height_fade_distance", 3.0)
	material.set_shader_parameter("i_ripple_boundary_fade", 0.15)
	material.set_shader_parameter("i_lod0_distance", 11.0)


func _make_runtime_state(texture: Texture2D, boundary: Texture2D, normal_strength: float) -> Dictionary:
	return {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": texture,
		"i_ripple_impulse_texture": texture,
		"i_ripple_world_to_uv": Transform3D(Basis(Vector3(0.1, 0.0, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, 0.1)), Vector3(0.5, 0.0, 0.5)),
		"i_ripple_boundary_mask": boundary,
		"i_ripple_texel_size": Vector2(0.125, 0.125),
		"i_ripple_normal_strength": normal_strength,
		"i_ripple_refraction_strength": 0.12,
		"i_ripple_displacement_strength": 0.0,
		"i_ripple_height_fade_distance": 4.0,
		"i_ripple_boundary_fade": 0.20,
	}


func _make_texture(color: Color) -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _assign_river_material(river: Node, material: ShaderMaterial) -> void:
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		_expect(false, String(river.name) + " should have a generated mesh with one material surface")
		return
	mesh_instance.material_override = null
	mesh_instance.mesh.surface_set_material(0, material)
	mesh_instance.set_surface_override_material(0, null)
	river.call("_prepare_generated_mesh_instance", mesh_instance)
	river.call("set_debug_view", 0)


func _get_river_material(river: Node) -> ShaderMaterial:
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	return mesh_instance.mesh.surface_get_material(0) as ShaderMaterial


func _get_shader_param(material: ShaderMaterial, parameter_name: String) -> Variant:
	if material == null:
		return null
	return material.get_shader_parameter(parameter_name)


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_MATERIAL_OWNERSHIP_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
