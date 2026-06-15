extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")

const RIVER_SHADER_PATH := "res://addons/waterways/shaders/river.gdshader"
const DEBUG_SHADER_PATH := "res://addons/waterways/shaders/river_debug.gdshader"
const SURFACE_COMMON_PATH := "res://addons/waterways/shaders/river_surface_common.gdshaderinc"
const DEBUG_MENU_PATH := "res://addons/waterways/gui/debug_view_menu.gd"
const RIVER_MANAGER_PATH := "res://addons/waterways/river_manager.gd"
const RIVER_RIPPLE_MATERIAL_OWNER_PATH := "res://addons/waterways/river_ripple_material_owner.gd"
const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn"
const VIEWPORT_SIZE := Vector2i(96, 96)

const REQUIRED_RIPPLE_UNIFORMS := [
	"i_ripple_enabled",
	"i_ripple_simulation_texture",
	"i_ripple_impulse_texture",
	"i_ripple_world_to_uv",
	"i_ripple_boundary_mask",
	"i_ripple_texel_size",
	"i_ripple_normal_strength",
	"i_ripple_refraction_strength",
	"i_ripple_displacement_strength",
	"i_ripple_height_fade_distance",
	"i_ripple_boundary_fade",
]

const DEBUG_MODES := {
	"raw_height": 62,
	"impulse_contact": 63,
	"boundary_mask": 64,
	"visible_influence": 65,
}

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_shader_and_menu_contract()
	await _validate_river_manager_runtime_contract()
	await _validate_review_scene_debug_state()
	await _validate_debug_render_modes()
	_finish()


func _validate_shader_and_menu_contract() -> void:
	var river_shader := load(RIVER_SHADER_PATH) as Shader
	var debug_shader := load(DEBUG_SHADER_PATH) as Shader
	_expect(river_shader != null, "River shader should load.")
	_expect(debug_shader != null, "Debug shader should load.")
	if river_shader != null:
		_validate_uniforms(river_shader, "river shader")
	if debug_shader != null:
		_validate_uniforms(debug_shader, "debug shader")

	var debug_source := _read_text(DEBUG_SHADER_PATH)
	var surface_common_source := _read_text(SURFACE_COMMON_PATH)
	var menu_source := _read_text(DEBUG_MENU_PATH)
	var manager_source := _read_text(RIVER_MANAGER_PATH)
	var ripple_owner_source := _read_text(RIVER_RIPPLE_MATERIAL_OWNER_PATH)
	var runtime_material_source := manager_source + "\n" + ripple_owner_source
	var debug_shader_source := debug_source + "\n" + surface_common_source
	_expect(runtime_material_source.find("\"i_ripple_impulse_texture\"") >= 0, "Runtime ripple material owner should allow the impulse/contact texture.")
	for mode_name in DEBUG_MODES.keys():
		var mode_id := int(DEBUG_MODES[mode_name])
		_expect(debug_source.find("= " + str(mode_id) + ";") >= 0, "Debug shader should define ripple debug mode " + mode_name + ".")
		_expect(debug_source.find("mode == " + _debug_constant_name(mode_name)) >= 0, "Debug shader should handle mode " + mode_name + ".")
		_expect(menu_source.find(str(mode_id)) >= 0, "Debug view menu should expose mode id " + str(mode_id) + ".")
	_expect(debug_source.find("textureLod(i_ripple_simulation_texture") >= 0, "Debug shader should sample the raw ripple simulation texture.")
	_expect(debug_source.find("textureLod(i_ripple_impulse_texture") >= 0, "Debug shader should sample the impulse/contact texture.")
	_expect(debug_shader_source.find("textureLod(i_ripple_boundary_mask") >= 0, "Debug shader should sample the boundary mask.")
	_expect(debug_source.find("ripple_normal_offset_at_uv") >= 0, "Debug shader should expose visible influence through the normal-offset helper.")
	_results["shader_menu_contract"] = true


func _validate_uniforms(shader: Shader, label: String) -> void:
	var shader_parameters := {}
	for parameter in RenderingServer.get_shader_parameter_list(shader.get_rid()):
		shader_parameters[String(parameter.name)] = true
	for uniform_name in REQUIRED_RIPPLE_UNIFORMS:
		_expect(shader_parameters.has(uniform_name), label + " should declare " + uniform_name + ".")


func _validate_river_manager_runtime_contract() -> void:
	var owner := Node.new()
	owner.name = "RippleDebugOwner"
	root.add_child(owner)
	var river := RiverManager.new()
	river.name = "RippleDebugProbeRiver"
	root.add_child(river)
	await _settle_frames(4)

	var simulation_texture := _make_wave_texture()
	var next_simulation_texture := _make_wave_texture(0.37)
	var impulse_texture := _make_contact_texture()
	var next_impulse_texture := _make_contact_texture(0.18)
	var boundary_texture := _make_boundary_texture()
	var accepted := bool(river.call("apply_runtime_ripple_material_state", owner, _make_runtime_state(simulation_texture, impulse_texture, boundary_texture)))
	_expect(accepted, "River should accept runtime ripple state including impulse/contact texture.")

	var visible_material := _get_river_material(river)
	var debug_material := _get_debug_material(river)
	_expect(visible_material != null, "River should have a visible runtime material.")
	_expect(debug_material != null, "River should have a debug material.")
	_expect(_get_shader_param(visible_material, "i_ripple_simulation_texture") == simulation_texture, "Visible material should receive raw ripple texture.")
	_expect(_get_shader_param(visible_material, "i_ripple_impulse_texture") == impulse_texture, "Visible material should receive impulse/contact texture.")
	_expect(_get_shader_param(debug_material, "i_ripple_simulation_texture") == simulation_texture, "Debug material should receive raw ripple texture.")
	_expect(_get_shader_param(debug_material, "i_ripple_impulse_texture") == impulse_texture, "Debug material should receive impulse/contact texture.")
	_expect(_get_shader_param(debug_material, "i_ripple_boundary_mask") == boundary_texture, "Debug material should receive boundary mask.")

	for mode_id in DEBUG_MODES.values():
		river.call("set_debug_view", int(mode_id))
		await _settle_frames(1)
		_expect(bool(river.call("has_runtime_ripple_material_state", owner)), "Runtime ripple ownership should survive switching to debug mode " + str(mode_id) + ".")
		_expect(_get_shader_param(_get_debug_material(river), "mode") == int(mode_id), "Debug material should receive mode " + str(mode_id) + ".")
		_expect(_get_shader_param(_get_debug_material(river), "i_ripple_simulation_texture") == simulation_texture, "Debug mode " + str(mode_id) + " should keep the live raw ripple texture.")

	river.call("set_materials", "i_ripple_simulation_texture", next_simulation_texture)
	river.call("set_materials", "i_ripple_impulse_texture", next_impulse_texture)
	await _settle_frames(1)
	_expect(_get_shader_param(_get_debug_material(river), "i_ripple_simulation_texture") == next_simulation_texture, "Debug material should keep receiving animated ripple texture updates while a debug view is active.")
	_expect(_get_shader_param(_get_debug_material(river), "i_ripple_impulse_texture") == next_impulse_texture, "Debug material should keep receiving contact texture updates while a debug view is active.")

	river.call("set_debug_view", 0)
	await _settle_frames(1)
	_expect(bool(river.call("has_runtime_ripple_material_state", owner)), "Runtime ripple ownership should survive returning to the visible river.")
	_expect(_get_shader_param(_get_river_material(river), "i_ripple_simulation_texture") == next_simulation_texture, "Visible material should retain the latest raw ripple texture after debug views close.")
	_expect(_get_shader_param(_get_river_material(river), "i_ripple_impulse_texture") == next_impulse_texture, "Visible material should retain the latest contact texture after debug views close.")

	_results["runtime_debug_state_preserved"] = true
	river.call("clear_runtime_ripple_material_state", owner)
	river.queue_free()
	owner.queue_free()
	await _settle_frames(2)


func _validate_review_scene_debug_state() -> void:
	var packed_scene := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Visible normal review scene should load for debug parity.")
	if packed_scene == null:
		return

	var review := packed_scene.instantiate()
	root.add_child(review)
	await _settle_frames(16)
	var status: Dictionary = review.call("get_review_status")
	var target_river := review.call("get_target_river") as Node
	_expect(bool(status.get("setup_complete", false)), "Review scene should finish setup before debug parity checks. Status: " + str(status))
	_expect(target_river != null, "Review scene should find the target river for debug parity.")
	var impulse_texture_size = status.get("impulse_texture_size", Vector2.ZERO)
	_expect(int(impulse_texture_size.x) == 256 and int(impulse_texture_size.y) == 256, "Review scene should create an inspectable impulse/contact texture. Status: " + str(status))
	if target_river != null:
		_expect(bool(target_river.call("has_runtime_ripple_material_state", review)), "Review scene should start with active runtime ripple state.")

	review.call("set_debug_view_mode", DEBUG_MODES["raw_height"])
	await _settle_frames(2)
	var raw_status: Dictionary = review.call("get_review_status")
	_expect(int(raw_status.get("debug_view", 0)) == DEBUG_MODES["raw_height"], "Review scene should switch to raw ripple debug view. Status: " + str(raw_status))
	if target_river != null:
		_expect(bool(target_river.call("has_runtime_ripple_material_state", review)), "Raw debug view should not clear runtime ripple state.")

	var initial_frame := int(raw_status.get("ripple_texture_frame", 0))
	await _settle_frames(18)
	var animated_status: Dictionary = review.call("get_review_status")
	_expect(int(animated_status.get("ripple_texture_frame", 0)) > initial_frame, "Runtime ripple texture should keep animating while a debug view is active. Status: " + str(animated_status))
	if target_river != null:
		_expect(bool(target_river.call("has_runtime_ripple_material_state", review)), "Animated debug view should keep runtime ripple state.")

	review.call("set_debug_view_mode", DEBUG_MODES["visible_influence"])
	await _settle_frames(2)
	var influence_status: Dictionary = review.call("get_review_status")
	_expect(int(influence_status.get("debug_view", 0)) == DEBUG_MODES["visible_influence"], "Review scene should switch to visible influence debug view. Status: " + str(influence_status))
	review.call("set_debug_view_mode", 0)
	await _settle_frames(2)
	var visible_status: Dictionary = review.call("get_review_status")
	_expect(int(visible_status.get("debug_view", -1)) == 0, "Review scene should return to visible river mode. Status: " + str(visible_status))
	if target_river != null:
		_expect(bool(target_river.call("has_runtime_ripple_material_state", review)), "Returning to visible river should not clear runtime ripple state.")

	_results["review_scene_debug_state_preserved"] = true
	review.queue_free()
	await _settle_frames(3)
	if target_river != null and is_instance_valid(target_river):
		_expect(not bool(target_river.call("has_runtime_ripple_material_state", review)), "Review scene should restore runtime ripple state when freed.")


func _validate_debug_render_modes() -> void:
	var debug_shader := load(DEBUG_SHADER_PATH) as Shader
	if debug_shader == null:
		return
	var contrasts := {}
	for mode_name in DEBUG_MODES.keys():
		var image := await _render_debug_mode(debug_shader, int(DEBUG_MODES[mode_name]))
		var contrast := _image_luminance_contrast(image)
		contrasts[mode_name] = contrast
		_expect(contrast > 0.025, "Debug render mode " + mode_name + " should produce readable contrast; got " + str(contrast) + ".")
	_results["debug_render_contrast"] = contrasts


func _render_debug_mode(shader: Shader, mode_id: int) -> Image:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.look_at_from_position(Vector3(0.0, 2.0, 0.0), Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	viewport.add_child(camera)

	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	plane.mesh = mesh
	plane.material_override = _make_debug_material(shader, mode_id)
	viewport.add_child(plane)

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for _frame in range(4):
		await process_frame
	var texture := viewport.get_texture()
	# Validation-only readback. Runtime ripple simulation and visible rendering must not use this path.
	var image := texture.get_image() if texture != null else Image.create(1, 1, false, Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return image


func _make_debug_material(shader: Shader, mode_id: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mode", mode_id)
	material.set_shader_parameter("i_ripple_enabled", true)
	material.set_shader_parameter("i_ripple_simulation_texture", _make_wave_texture())
	material.set_shader_parameter("i_ripple_impulse_texture", _make_contact_texture())
	material.set_shader_parameter("i_ripple_boundary_mask", _make_boundary_texture())
	material.set_shader_parameter("i_ripple_world_to_uv", _build_world_to_uv_transform())
	material.set_shader_parameter("i_ripple_texel_size", Vector2(1.0 / 64.0, 1.0 / 64.0))
	material.set_shader_parameter("i_ripple_normal_strength", 4.0)
	material.set_shader_parameter("i_ripple_refraction_strength", 0.0)
	material.set_shader_parameter("i_ripple_displacement_strength", 0.0)
	material.set_shader_parameter("i_ripple_height_fade_distance", 0.0)
	material.set_shader_parameter("i_ripple_boundary_fade", 0.0)
	return material


func _make_runtime_state(simulation: Texture2D, impulse: Texture2D, boundary: Texture2D) -> Dictionary:
	return {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": simulation,
		"i_ripple_impulse_texture": impulse,
		"i_ripple_world_to_uv": _build_world_to_uv_transform(),
		"i_ripple_boundary_mask": boundary,
		"i_ripple_texel_size": Vector2(1.0 / 64.0, 1.0 / 64.0),
		"i_ripple_normal_strength": 1.25,
		"i_ripple_refraction_strength": 0.0,
		"i_ripple_displacement_strength": 0.0,
		"i_ripple_height_fade_distance": 0.0,
		"i_ripple_boundary_fade": 0.02,
	}


func _build_world_to_uv_transform() -> Transform3D:
	return Transform3D(
		Basis(Vector3(0.5, 0.0, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, 0.5)),
		Vector3(0.5, 0.0, 0.5)
	)


func _make_wave_texture(phase: float = 0.0) -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var radial := uv.distance_to(Vector2(0.52, 0.48))
			var wave := sin((radial + phase) * 42.0) * exp(-radial * 4.5)
			var encoded := clamp(0.5 + wave * 0.42, 0.0, 1.0)
			image.set_pixel(x, y, Color(encoded, 0.5, 0.0, 1.0))
	return ImageTexture.create_from_image(image)


func _make_contact_texture(offset: float = 0.0) -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var centers := [Vector2(0.34 + offset, 0.40), Vector2(0.66 - offset, 0.62)]
	for y in range(size):
		for x in range(size):
			var uv := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var value := 0.0
			for center in centers:
				value = max(value, 1.0 - smoothstep(0.06, 0.16, uv.distance_to(center)))
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)


func _make_boundary_texture() -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var ribbon := 1.0 - smoothstep(0.10, 0.20, abs(uv.y - (0.42 + sin(uv.x * 6.2831853) * 0.08)))
			image.set_pixel(x, y, Color(ribbon, ribbon, ribbon, 1.0))
	return ImageTexture.create_from_image(image)


func _get_river_material(river: Node) -> ShaderMaterial:
	var mesh_instance := _get_mesh_instance(river)
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	return mesh_instance.mesh.surface_get_material(0) as ShaderMaterial


func _get_debug_material(river: Node) -> ShaderMaterial:
	return river.get("_debug_material") as ShaderMaterial


func _get_mesh_instance(river: Node) -> MeshInstance3D:
	return river.get("mesh_instance") as MeshInstance3D


func _get_shader_param(material: ShaderMaterial, parameter_name: String) -> Variant:
	if material == null:
		return null
	return material.get_shader_parameter(parameter_name)


func _image_luminance_contrast(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var min_luminance := 1.0
	var max_luminance := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var luminance := (color.r + color.g + color.b) / 3.0
			min_luminance = min(min_luminance, luminance)
			max_luminance = max(max_luminance, luminance)
	return max_luminance - min_luminance


func _debug_constant_name(mode_name: String) -> String:
	match mode_name:
		"raw_height":
			return "RIPPLE_RAW_HEIGHT"
		"impulse_contact":
			return "RIPPLE_IMPULSE_CONTACT"
		"boundary_mask":
			return "RIPPLE_BOUNDARY_MASK"
		"visible_influence":
			return "RIPPLE_VISIBLE_INFLUENCE"
		_:
			return ""


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Could not open " + path + ": " + error_string(FileAccess.get_open_error()))
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_DEBUG_PARITY_PROBE_RESULTS=", _results)
		print("RIPPLE_DEBUG_PARITY_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
