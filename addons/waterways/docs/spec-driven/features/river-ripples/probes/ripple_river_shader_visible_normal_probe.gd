extends SceneTree

const RIVER_SHADER_PATH := "res://addons/waterways/shaders/river.gdshader"
const VIEWPORT_SIZE := Vector2i(128, 128)
const RIPPLE_SIZE := 64
const NEUTRAL_MAX_ALLOWED_DELTA := 0.008
const NEUTRAL_MEAN_ALLOWED_DELTA := 0.002
const VISIBLE_MIN_MAX_DELTA := 0.012
const VISIBLE_MIN_MEAN_DELTA := 0.00005

var _errors := PackedStringArray()
var _results := {}
var _neutral_texture: Texture2D
var _ripple_texture: Texture2D
var _white_boundary_texture: Texture2D
var _black_boundary_texture: Texture2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var shader := load(RIVER_SHADER_PATH) as Shader
	_expect(shader != null, "River shader should load for visible normal probe.")
	if shader == null:
		_finish()
		return

	_build_test_textures()

	var baseline := await _render_case(shader, {})
	var disabled_with_wave := await _render_case(shader, {
		"i_ripple_enabled": false,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_boundary_mask": _white_boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / float(RIPPLE_SIZE), 1.0 / float(RIPPLE_SIZE)),
		"i_ripple_normal_strength": 4.0,
	})
	var enabled_flat := await _render_case(shader, {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": _neutral_texture,
		"i_ripple_boundary_mask": _white_boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / float(RIPPLE_SIZE), 1.0 / float(RIPPLE_SIZE)),
		"i_ripple_normal_strength": 4.0,
	})
	var enabled_masked := await _render_case(shader, {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_boundary_mask": _black_boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / float(RIPPLE_SIZE), 1.0 / float(RIPPLE_SIZE)),
		"i_ripple_normal_strength": 4.0,
	})
	var enabled_wave := await _render_case(shader, {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_boundary_mask": _white_boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / float(RIPPLE_SIZE), 1.0 / float(RIPPLE_SIZE)),
		"i_ripple_normal_strength": 4.0,
	})

	_expect(_image_has_visible_content(baseline), "Baseline river shader render should not be blank.")
	_compare_neutral("disabled_with_wave_texture", baseline, disabled_with_wave)
	_compare_neutral("enabled_flat_texture", baseline, enabled_flat)
	_compare_neutral("enabled_black_boundary", baseline, enabled_masked)
	_compare_visible("enabled_wave_texture", baseline, enabled_wave)

	_finish()


func _build_test_textures() -> void:
	_neutral_texture = _make_solid_texture(Color(0.5, 0.5, 0.5, 1.0), RIPPLE_SIZE)
	_white_boundary_texture = _make_solid_texture(Color(1.0, 1.0, 1.0, 1.0), RIPPLE_SIZE)
	_black_boundary_texture = _make_solid_texture(Color(0.0, 0.0, 0.0, 1.0), RIPPLE_SIZE)

	var image := Image.create(RIPPLE_SIZE, RIPPLE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var u := (float(x) + 0.5) / float(image.get_width())
			var v := (float(y) + 0.5) / float(image.get_height())
			var wave := sin(u * TAU * 6.0) * cos(v * TAU * 5.0)
			var encoded_height := clamp(0.5 + wave * 0.45, 0.0, 1.0)
			image.set_pixel(x, y, Color(encoded_height, 0.5, 0.0, 1.0))
	_ripple_texture = ImageTexture.create_from_image(image)


func _render_case(shader: Shader, ripple_parameters: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(0.0, 3.0, 4.0), Vector3.ZERO, Vector3.UP)
	camera.current = true
	viewport.add_child(camera)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8.0, 8.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -1.0, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.18, 0.20, 0.23, 1.0)
	floor.material_override = floor_material
	viewport.add_child(floor)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(5.5, 5.5)
	water.mesh = water_mesh
	water.material_override = _make_river_material(shader, ripple_parameters)
	viewport.add_child(water)

	var light := DirectionalLight3D.new()
	light.light_energy = 2.0
	light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	viewport.add_child(light)

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for _frame in range(4):
		await process_frame

	var texture := viewport.get_texture()
	# Validation-only readback. Runtime ripple simulation and river rendering must not use this pattern.
	var image := texture.get_image() if texture != null else null
	viewport.queue_free()
	await process_frame

	if image == null:
		_expect(false, "Render case should produce an image.")
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	return image


func _make_river_material(shader: Shader, ripple_parameters: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("flow_speed", 0.0)
	material.set_shader_parameter("normal_scale", 2.5)
	material.set_shader_parameter("roughness", 0.08)
	material.set_shader_parameter("foam_amount", 0.0)
	material.set_shader_parameter("transparency_refraction", 0.0)
	material.set_shader_parameter("edge_fade", 0.0)
	material.set_shader_parameter("normal_bump_texture", _neutral_texture)
	material.set_shader_parameter("i_texture_foam_noise", _neutral_texture)
	material.set_shader_parameter("i_flowmap", _neutral_texture)
	material.set_shader_parameter("i_distmap", _neutral_texture)
	material.set_shader_parameter("i_obstacle_features", _neutral_texture)
	material.set_shader_parameter("i_terrain_contact_features", _neutral_texture)
	material.set_shader_parameter("i_bank_response_features", _neutral_texture)
	material.set_shader_parameter("i_valid_flowmap", false)
	material.set_shader_parameter("i_ripple_world_to_uv", _build_world_to_ripple_uv())
	material.set_shader_parameter("i_ripple_height_fade_distance", 0.0)
	material.set_shader_parameter("i_ripple_boundary_fade", 0.0)
	material.set_shader_parameter("i_ripple_refraction_strength", 0.0)
	material.set_shader_parameter("i_ripple_displacement_strength", 0.0)
	for parameter_name_variant in ripple_parameters.keys():
		var parameter_name := String(parameter_name_variant)
		material.set_shader_parameter(parameter_name, ripple_parameters[parameter_name_variant])
	return material


func _build_world_to_ripple_uv() -> Transform3D:
	var bounds := AABB(Vector3(-2.75, -1.0, -2.75), Vector3(5.5, 2.0, 5.5))
	var basis := Basis(
		Vector3(1.0 / bounds.size.x, 0.0, 0.0),
		Vector3(0.0, 1.0 / bounds.size.y, 0.0),
		Vector3(0.0, 0.0, 1.0 / bounds.size.z)
	)
	return Transform3D(basis, basis * -bounds.position)


func _make_solid_texture(color: Color, size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _compare_neutral(case_name: String, baseline: Image, candidate: Image) -> void:
	var metrics := _image_delta(case_name, baseline, candidate)
	_expect(float(metrics.max_delta) <= NEUTRAL_MAX_ALLOWED_DELTA, case_name + " should stay visually neutral; max_delta=" + str(metrics.max_delta))
	_expect(float(metrics.mean_delta) <= NEUTRAL_MEAN_ALLOWED_DELTA, case_name + " should stay visually neutral; mean_delta=" + str(metrics.mean_delta))


func _compare_visible(case_name: String, baseline: Image, candidate: Image) -> void:
	var metrics := _image_delta(case_name, baseline, candidate)
	_expect(float(metrics.max_delta) >= VISIBLE_MIN_MAX_DELTA, case_name + " should visibly differ from baseline; max_delta=" + str(metrics.max_delta))
	_expect(float(metrics.mean_delta) >= VISIBLE_MIN_MEAN_DELTA, case_name + " should visibly differ from baseline; mean_delta=" + str(metrics.mean_delta))


func _image_delta(case_name: String, baseline: Image, candidate: Image) -> Dictionary:
	_expect(baseline != null and candidate != null, case_name + " should have comparison images.")
	if baseline == null or candidate == null:
		return {"max_delta": 0.0, "mean_delta": 0.0}
	_expect(baseline.get_size() == candidate.get_size(), case_name + " render size should match baseline.")
	if baseline.get_size() != candidate.get_size():
		return {"max_delta": 0.0, "mean_delta": 0.0}

	var max_delta := 0.0
	var total_delta := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for y in range(baseline.get_height()):
		for x in range(baseline.get_width()):
			var baseline_color := baseline.get_pixel(x, y)
			var candidate_color := candidate.get_pixel(x, y)
			var pixel_delta := max(
				max(abs(baseline_color.r - candidate_color.r), abs(baseline_color.g - candidate_color.g)),
				max(abs(baseline_color.b - candidate_color.b), abs(baseline_color.a - candidate_color.a))
			)
			if pixel_delta > 0.004:
				changed_pixels += 1
			max_delta = max(max_delta, pixel_delta)
			total_delta += pixel_delta
			sample_count += 1
	var mean_delta: float = total_delta / max(float(sample_count), 1.0)
	_results[case_name] = {
		"max_delta": max_delta,
		"mean_delta": mean_delta,
		"changed_pixels": changed_pixels,
	}
	return _results[case_name]


func _image_has_visible_content(image: Image) -> bool:
	if image == null:
		return false
	var min_value := 1.0
	var max_value := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var luminance := (color.r + color.g + color.b) / 3.0
			min_value = min(min_value, luminance)
			max_value = max(max_value, luminance)
	return max_value - min_value > 0.02


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_RESULTS=", _results)
		print("RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
