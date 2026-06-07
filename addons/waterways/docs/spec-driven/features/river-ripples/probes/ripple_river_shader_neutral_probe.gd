extends SceneTree

const RIVER_SHADER_PATH := "res://addons/waterways/shaders/river.gdshader"
const VIEWPORT_SIZE := Vector2i(96, 96)
const MAX_ALLOWED_DELTA := 0.006
const MEAN_ALLOWED_DELTA := 0.0015

const RIPPLE_UNIFORMS := [
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

var _errors := PackedStringArray()
var _results := {}
var _neutral_texture: Texture2D
var _ripple_texture: Texture2D
var _boundary_texture: Texture2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var shader := load(RIVER_SHADER_PATH) as Shader
	_expect(shader != null, "River shader should load")
	if shader == null:
		_finish()
		return

	_validate_shader_uniforms(shader)
	_build_test_textures()

	var baseline := await _render_case(shader, {})
	var disabled_with_textures := await _render_case(shader, {
		"i_ripple_enabled": false,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_impulse_texture": _ripple_texture,
		"i_ripple_boundary_mask": _boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / 32.0, 1.0 / 32.0),
		"i_ripple_normal_strength": 3.0,
		"i_ripple_refraction_strength": 1.0,
		"i_ripple_displacement_strength": 1.0,
		"i_ripple_height_fade_distance": 8.0,
		"i_ripple_boundary_fade": 0.08,
	})
	var enabled_missing_simulation := await _render_case(shader, {
		"i_ripple_enabled": true,
		"i_ripple_impulse_texture": _ripple_texture,
		"i_ripple_boundary_mask": _boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / 32.0, 1.0 / 32.0),
		"i_ripple_normal_strength": 3.0,
		"i_ripple_refraction_strength": 1.0,
		"i_ripple_displacement_strength": 1.0,
		"i_ripple_height_fade_distance": 8.0,
		"i_ripple_boundary_fade": 0.08,
	})
	var enabled_missing_boundary := await _render_case(shader, {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_impulse_texture": _ripple_texture,
		"i_ripple_texel_size": Vector2(1.0 / 32.0, 1.0 / 32.0),
		"i_ripple_normal_strength": 3.0,
		"i_ripple_refraction_strength": 1.0,
		"i_ripple_displacement_strength": 1.0,
		"i_ripple_height_fade_distance": 8.0,
		"i_ripple_boundary_fade": 0.08,
	})

	_expect(_image_has_visible_content(baseline), "Baseline river shader render should not be blank")
	_compare_images("disabled_with_textures", baseline, disabled_with_textures)
	_compare_images("enabled_missing_simulation_texture", baseline, enabled_missing_simulation)
	_compare_images("enabled_missing_boundary_texture", baseline, enabled_missing_boundary)

	_finish()


func _validate_shader_uniforms(shader: Shader) -> void:
	var shader_parameters := {}
	var parameter_list := RenderingServer.get_shader_parameter_list(shader.get_rid())
	for parameter in parameter_list:
		shader_parameters[String(parameter.name)] = true
	for uniform_name in RIPPLE_UNIFORMS:
		_expect(shader_parameters.has(uniform_name), "River shader should declare " + uniform_name)


func _build_test_textures() -> void:
	_neutral_texture = _make_solid_texture(Color(0.5, 0.5, 0.5, 1.0))
	_boundary_texture = _make_solid_texture(Color(1.0, 1.0, 1.0, 1.0))

	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var wave := sin(float(x) * 0.73) * cos(float(y) * 0.41)
			var encoded_height := clamp(0.5 + wave * 0.45, 0.0, 1.0)
			image.set_pixel(x, y, Color(encoded_height, 0.5, 0.0, 1.0))
	_ripple_texture = ImageTexture.create_from_image(image)


func _render_case(shader: Shader, ripple_parameters: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
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
	light.light_energy = 1.5
	light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	viewport.add_child(light)

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for _frame in range(4):
		await process_frame

	var texture := viewport.get_texture()
	var image := texture.get_image() if texture != null else null
	viewport.queue_free()
	await process_frame

	if image == null:
		_expect(false, "Render case should produce an image")
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	return image


func _make_river_material(shader: Shader, ripple_parameters: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("flow_speed", 0.0)
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
	material.set_shader_parameter("i_ripple_world_to_uv", Transform3D.IDENTITY)
	for parameter_name_variant in ripple_parameters.keys():
		var parameter_name := String(parameter_name_variant)
		material.set_shader_parameter(parameter_name, ripple_parameters[parameter_name_variant])
	return material


func _make_solid_texture(color: Color) -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _compare_images(case_name: String, baseline: Image, candidate: Image) -> void:
	_expect(baseline != null and candidate != null, case_name + " should have comparison images")
	if baseline == null or candidate == null:
		return
	_expect(baseline.get_size() == candidate.get_size(), case_name + " render size should match baseline")
	if baseline.get_size() != candidate.get_size():
		return

	var max_delta := 0.0
	var total_delta := 0.0
	var sample_count := 0
	for y in range(baseline.get_height()):
		for x in range(baseline.get_width()):
			var baseline_color := baseline.get_pixel(x, y)
			var candidate_color := candidate.get_pixel(x, y)
			var pixel_delta := max(
				max(abs(baseline_color.r - candidate_color.r), abs(baseline_color.g - candidate_color.g)),
				max(abs(baseline_color.b - candidate_color.b), abs(baseline_color.a - candidate_color.a))
			)
			max_delta = max(max_delta, pixel_delta)
			total_delta += pixel_delta
			sample_count += 1
	var mean_delta: float = total_delta / max(float(sample_count), 1.0)
	_results[case_name] = {
		"max_delta": max_delta,
		"mean_delta": mean_delta,
	}
	_expect(max_delta <= MAX_ALLOWED_DELTA, case_name + " should stay visually neutral; max_delta=" + str(max_delta))
	_expect(mean_delta <= MEAN_ALLOWED_DELTA, case_name + " should stay visually neutral; mean_delta=" + str(mean_delta))


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
		print("RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_RESULTS=", _results)
		print("RIPPLE_RIVER_SHADER_NEUTRAL_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
