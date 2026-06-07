extends SceneTree

const RIVER_SHADER_PATH := "res://addons/waterways/shaders/river.gdshader"
const DEBUG_SHADER_PATH := "res://addons/waterways/shaders/river_debug.gdshader"
const VIEWPORT_SIZE := Vector2i(640, 360)
const RIPPLE_SIZE := 256
const WARMUP_FRAMES := 24
const MEASURE_FRAMES := 72
const MIN_RENDER_TIME_SAMPLES := 36
const MAX_DISABLED_GPU_DELTA_MS := 0.25
const MAX_DISABLED_GPU_RATIO := 1.35
const MAX_ENABLED_GPU_DELTA_MS := 0.60
const MAX_ENABLED_GPU_RATIO := 2.25

const DEBUG_MODES := {
	"raw_height": 62,
	"impulse_contact": 63,
	"boundary_mask": 64,
	"visible_influence": 65,
}

var _errors := PackedStringArray()
var _results := {}
var _neutral_texture: Texture2D
var _ripple_texture: Texture2D
var _boundary_texture: Texture2D
var _impulse_texture: Texture2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_test_textures()
	_validate_static_shader_cost()

	var river_shader := load(RIVER_SHADER_PATH) as Shader
	var debug_shader := load(DEBUG_SHADER_PATH) as Shader
	_expect(river_shader != null, "River shader should load for shader-cost probe.")
	_expect(debug_shader != null, "Debug shader should load for shader-cost probe.")

	_results["renderer"] = {
		"method": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"viewport_size": VIEWPORT_SIZE,
		"warmup_frames": WARMUP_FRAMES,
		"measure_frames": MEASURE_FRAMES,
	}

	if river_shader != null:
		var baseline := await _measure_case("baseline_no_ripples", river_shader, _make_river_parameters(false, 0.0), false)
		var disabled := await _measure_case("disabled_live_textures", river_shader, _make_river_parameters(false, 1.25), false)
		var enabled := await _measure_case("enabled_visible_normal", river_shader, _make_river_parameters(true, 1.25), false)
		_validate_disabled_runtime_cost(baseline, disabled)
		_validate_enabled_runtime_cost(disabled, enabled)

	if debug_shader != null:
		var debug_results := {}
		for mode_name in DEBUG_MODES.keys():
			var mode_id := int(DEBUG_MODES[mode_name])
			debug_results[mode_name] = await _measure_case("debug_" + mode_name, debug_shader, _make_debug_parameters(mode_id), true)
		_results["debug_modes"] = debug_results
		_validate_debug_runtime_cost(debug_results)

	_finish()


func _validate_static_shader_cost() -> void:
	var river_source := _read_text(RIVER_SHADER_PATH)
	var debug_source := _read_text(DEBUG_SHADER_PATH)
	_expect(not river_source.is_empty(), "River shader source should be readable for shader-cost probe.")
	_expect(not debug_source.is_empty(), "Debug shader source should be readable for shader-cost probe.")
	if river_source.is_empty() or debug_source.is_empty():
		return

	var ready_body := _extract_function_body(river_source, "bool ripple_sampling_ready()")
	var normal_body := _extract_function_body(river_source, "vec2 ripple_normal_offset_at_uv(")
	var fragment_body := _extract_function_body(river_source, "void fragment()")
	var debug_color_body := _extract_function_body(debug_source, "vec3 ripple_debug_color(")
	var debug_normal_body := _extract_function_body(debug_source, "vec2 ripple_normal_offset_at_uv(")

	var visible_simulation_samples := _count_occurrences(normal_body, "textureLod(i_ripple_simulation_texture")
	var visible_boundary_samples := _count_occurrences(normal_body, "ripple_boundary_mask_unchecked(")
	var visible_fragment_world_calls := _count_occurrences(fragment_body, "ripple_normal_offset_at_world(")
	var visible_fragment_ripple_samples := _count_occurrences(fragment_body, "textureLod(i_ripple_") + _count_occurrences(fragment_body, "texture(i_ripple_")
	var ready_ripple_samples := _count_occurrences(ready_body, "textureLod(i_ripple_") + _count_occurrences(ready_body, "texture(i_ripple_")
	var first_normal_sample_index := normal_body.find("textureLod(i_ripple_simulation_texture")
	var normal_guard_index := normal_body.find("if (!ripple_sampling_ready() || i_ripple_normal_strength <= EPSILON)")

	_expect(ready_body.find("i_ripple_enabled") >= 0, "Ripple sampling guard should include i_ripple_enabled.")
	_expect(ready_ripple_samples == 0, "Ripple sampling readiness guard should not perform ripple texture samples; found " + str(ready_ripple_samples) + ".")
	_expect(normal_guard_index >= 0 and first_normal_sample_index > normal_guard_index, "Visible normal helper should guard disabled/missing ripple paths before sampling.")
	_expect(visible_simulation_samples == 3, "Enabled visible normal helper should keep exactly three simulation samples; found " + str(visible_simulation_samples) + ".")
	_expect(visible_boundary_samples == 1, "Enabled visible normal helper should keep one boundary-mask helper call; found " + str(visible_boundary_samples) + ".")
	_expect(visible_fragment_world_calls == 1, "Visible fragment path should call the ripple normal world helper once; found " + str(visible_fragment_world_calls) + ".")
	_expect(visible_fragment_ripple_samples == 0, "Visible fragment path should not sample ripple textures directly; found " + str(visible_fragment_ripple_samples) + ".")

	var debug_direct_samples := {
		"simulation": _count_occurrences(debug_color_body, "textureLod(i_ripple_simulation_texture"),
		"impulse": _count_occurrences(debug_color_body, "textureLod(i_ripple_impulse_texture"),
		"boundary": _count_occurrences(debug_color_body, "textureLod(i_ripple_boundary_mask"),
		"visible_influence_simulation": _count_occurrences(debug_normal_body, "textureLod(i_ripple_simulation_texture"),
	}
	_results["static_cost"] = {
		"disabled_ready_ripple_samples": ready_ripple_samples,
		"visible_fragment_direct_ripple_samples": visible_fragment_ripple_samples,
		"visible_fragment_world_helper_calls": visible_fragment_world_calls,
		"visible_normal_simulation_samples": visible_simulation_samples,
		"visible_normal_boundary_helper_calls": visible_boundary_samples,
		"debug_direct_samples": debug_direct_samples,
	}


func _measure_case(case_name: String, shader: Shader, shader_parameters: Dictionary, is_debug_shader: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.look_at_from_position(Vector3(0.0, 4.0, 0.0), Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	viewport.add_child(camera)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(5.5, 5.5)
	water.mesh = water_mesh
	water.material_override = _make_material(shader, shader_parameters, is_debug_shader)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(water)

	var light := DirectionalLight3D.new()
	light.light_energy = 1.8
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	viewport.add_child(light)

	var viewport_rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _wait_render_frames(WARMUP_FRAMES)

	var cpu_samples := []
	var gpu_samples := []
	var wall_samples := []
	for _frame in range(MEASURE_FRAMES):
		var start_usec := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		wall_samples.append(float(Time.get_ticks_usec() - start_usec) / 1000.0)
		var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		if cpu_ms > 0.0:
			cpu_samples.append(cpu_ms)
		if gpu_ms > 0.0:
			gpu_samples.append(gpu_ms)

	var draw_calls := RenderingServer.viewport_get_render_info(
		viewport_rid,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	var primitives := RenderingServer.viewport_get_render_info(
		viewport_rid,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
	)
	var objects := RenderingServer.viewport_get_render_info(
		viewport_rid,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
	)

	var result := {
		"cpu_ms": _sample_summary(cpu_samples),
		"gpu_ms": _sample_summary(gpu_samples),
		"wall_ms": _sample_summary(wall_samples),
		"draw_calls": draw_calls,
		"primitives": primitives,
		"objects": objects,
	}
	_results[case_name] = result

	RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
	viewport.queue_free()
	await process_frame
	return result


func _validate_disabled_runtime_cost(baseline: Dictionary, disabled: Dictionary) -> void:
	_validate_measured_case("baseline_no_ripples", baseline)
	_validate_measured_case("disabled_live_textures", disabled)
	_expect(int(disabled.get("draw_calls", 0)) == int(baseline.get("draw_calls", -1)), "Disabled live-texture path should not add draw calls.")

	var baseline_gpu := _median_ms(baseline, "gpu_ms")
	var disabled_gpu := _median_ms(disabled, "gpu_ms")
	var delta := disabled_gpu - baseline_gpu
	var ratio := _safe_ratio(disabled_gpu, baseline_gpu)
	_results["disabled_cost_delta"] = {
		"gpu_median_delta_ms": delta,
		"gpu_median_ratio": ratio,
	}
	_expect(delta <= MAX_DISABLED_GPU_DELTA_MS or ratio <= MAX_DISABLED_GPU_RATIO, "Disabled live-texture path should stay close to baseline GPU cost; delta=" + str(delta) + "ms ratio=" + str(ratio) + ".")


func _validate_enabled_runtime_cost(disabled: Dictionary, enabled: Dictionary) -> void:
	_validate_measured_case("enabled_visible_normal", enabled)
	_expect(int(enabled.get("draw_calls", 0)) == int(disabled.get("draw_calls", -1)), "Enabled visible normal path should not add draw calls.")

	var disabled_gpu := _median_ms(disabled, "gpu_ms")
	var enabled_gpu := _median_ms(enabled, "gpu_ms")
	var delta := enabled_gpu - disabled_gpu
	var ratio := _safe_ratio(enabled_gpu, disabled_gpu)
	_results["enabled_cost_delta"] = {
		"gpu_median_delta_ms": delta,
		"gpu_median_ratio": ratio,
	}
	_expect(delta <= MAX_ENABLED_GPU_DELTA_MS or ratio <= MAX_ENABLED_GPU_RATIO, "Enabled visible normal path should stay within the first-pass GPU timing guard; delta=" + str(delta) + "ms ratio=" + str(ratio) + ".")


func _validate_debug_runtime_cost(debug_results: Dictionary) -> void:
	for mode_name in debug_results.keys():
		var result := debug_results[mode_name] as Dictionary
		_validate_measured_case("debug_" + String(mode_name), result)
		_expect(int(result.get("draw_calls", 0)) >= 1, "Debug mode " + String(mode_name) + " should render at least one visible draw call.")
	_results["debug_cost_scope"] = "Debug timings are recorded as inspection-tool costs; they are not visual tuning targets for this gate."


func _validate_measured_case(case_name: String, result: Dictionary) -> void:
	var gpu_summary := result.get("gpu_ms", {}) as Dictionary
	var cpu_summary := result.get("cpu_ms", {}) as Dictionary
	_expect(int(gpu_summary.get("count", 0)) >= MIN_RENDER_TIME_SAMPLES, case_name + " should report enough measured GPU render-time samples.")
	_expect(int(cpu_summary.get("count", 0)) >= MIN_RENDER_TIME_SAMPLES, case_name + " should report enough measured CPU render-time samples.")
	_expect(float(gpu_summary.get("median", 0.0)) >= 0.0, case_name + " should report a non-negative GPU median.")
	_expect(int(result.get("draw_calls", 0)) >= 1, case_name + " should report at least one draw call.")


func _make_material(shader: Shader, shader_parameters: Dictionary, is_debug_shader: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	var declared := _shader_parameter_names(shader)
	_set_if_declared(material, declared, "mode", int(shader_parameters.get("mode", 0)))
	_set_if_declared(material, declared, "flow_speed", 0.0)
	_set_if_declared(material, declared, "normal_scale", 2.5)
	_set_if_declared(material, declared, "roughness", 0.08)
	_set_if_declared(material, declared, "foam_amount", 0.0)
	_set_if_declared(material, declared, "transparency_refraction", 0.0)
	_set_if_declared(material, declared, "edge_fade", 0.0)
	_set_if_declared(material, declared, "normal_bump_texture", _neutral_texture)
	_set_if_declared(material, declared, "i_texture_foam_noise", _neutral_texture)
	_set_if_declared(material, declared, "i_flowmap", _neutral_texture)
	_set_if_declared(material, declared, "i_distmap", _neutral_texture)
	_set_if_declared(material, declared, "i_obstacle_features", _neutral_texture)
	_set_if_declared(material, declared, "i_terrain_contact_features", _neutral_texture)
	_set_if_declared(material, declared, "i_bank_response_features", _neutral_texture)
	_set_if_declared(material, declared, "i_valid_flowmap", false)
	if is_debug_shader:
		_set_if_declared(material, declared, "debug_pattern", _neutral_texture)
		_set_if_declared(material, declared, "debug_arrow", _neutral_texture)
	for parameter_name_variant in shader_parameters.keys():
		var parameter_name := String(parameter_name_variant)
		_set_if_declared(material, declared, parameter_name, shader_parameters[parameter_name_variant])
	return material


func _make_river_parameters(enabled: bool, normal_strength: float) -> Dictionary:
	return {
		"i_ripple_enabled": enabled,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_impulse_texture": _impulse_texture,
		"i_ripple_world_to_uv": _build_world_to_ripple_uv(),
		"i_ripple_boundary_mask": _boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / float(RIPPLE_SIZE), 1.0 / float(RIPPLE_SIZE)),
		"i_ripple_normal_strength": normal_strength,
		"i_ripple_refraction_strength": 0.0,
		"i_ripple_displacement_strength": 0.0,
		"i_ripple_height_fade_distance": 0.0,
		"i_ripple_boundary_fade": 0.02,
	}


func _make_debug_parameters(mode_id: int) -> Dictionary:
	var parameters := _make_river_parameters(true, 1.25)
	parameters["mode"] = mode_id
	return parameters


func _build_world_to_ripple_uv() -> Transform3D:
	var bounds := AABB(Vector3(-2.75, -1.0, -2.75), Vector3(5.5, 2.0, 5.5))
	var basis := Basis(
		Vector3(1.0 / bounds.size.x, 0.0, 0.0),
		Vector3(0.0, 1.0 / bounds.size.y, 0.0),
		Vector3(0.0, 0.0, 1.0 / bounds.size.z)
	)
	return Transform3D(basis, basis * -bounds.position)


func _build_test_textures() -> void:
	_neutral_texture = _make_solid_texture(Color(0.5, 0.5, 0.5, 1.0), RIPPLE_SIZE)
	_boundary_texture = _make_solid_texture(Color(1.0, 1.0, 1.0, 1.0), RIPPLE_SIZE)
	_ripple_texture = _make_wave_texture()
	_impulse_texture = _make_impulse_texture()


func _make_solid_texture(color: Color, size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _make_wave_texture() -> Texture2D:
	var image := Image.create(RIPPLE_SIZE, RIPPLE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(RIPPLE_SIZE):
		for x in range(RIPPLE_SIZE):
			var uv := Vector2((float(x) + 0.5) / float(RIPPLE_SIZE), (float(y) + 0.5) / float(RIPPLE_SIZE))
			var radial := uv.distance_to(Vector2(0.52, 0.48))
			var wave := sin(radial * 58.0) * exp(-radial * 4.0)
			var encoded := clamp(0.5 + wave * 0.42, 0.0, 1.0)
			image.set_pixel(x, y, Color(encoded, 0.5, 0.0, 1.0))
	return ImageTexture.create_from_image(image)


func _make_impulse_texture() -> Texture2D:
	var image := Image.create(RIPPLE_SIZE, RIPPLE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var centers := [Vector2(0.36, 0.42), Vector2(0.62, 0.58)]
	for y in range(RIPPLE_SIZE):
		for x in range(RIPPLE_SIZE):
			var uv := Vector2((float(x) + 0.5) / float(RIPPLE_SIZE), (float(y) + 0.5) / float(RIPPLE_SIZE))
			var value := 0.0
			for center in centers:
				value = max(value, 1.0 - smoothstep(0.025, 0.09, uv.distance_to(center)))
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)


func _wait_render_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await RenderingServer.frame_post_draw


func _sample_summary(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {
			"count": 0,
			"min": 0.0,
			"median": 0.0,
			"p95": 0.0,
			"max": 0.0,
			"mean": 0.0,
		}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted:
		total += float(sample)
	var count := sorted.size()
	return {
		"count": count,
		"min": float(sorted[0]),
		"median": _percentile(sorted, 0.5),
		"p95": _percentile(sorted, 0.95),
		"max": float(sorted[count - 1]),
		"mean": total / float(count),
	}


func _percentile(sorted_samples: Array, percentile: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(roundi(percentile * float(sorted_samples.size() - 1)), 0, sorted_samples.size() - 1)
	return float(sorted_samples[index])


func _median_ms(result: Dictionary, metric_name: String) -> float:
	var summary := result.get(metric_name, {}) as Dictionary
	return float(summary.get("median", 0.0))


func _safe_ratio(numerator: float, denominator: float) -> float:
	if denominator <= 0.0001:
		return 1.0 if numerator <= 0.0001 else INF
	return numerator / denominator


func _shader_parameter_names(shader: Shader) -> Dictionary:
	var names := {}
	if shader == null:
		return names
	for parameter in RenderingServer.get_shader_parameter_list(shader.get_rid()):
		names[String(parameter.name)] = true
	return names


func _set_if_declared(material: ShaderMaterial, declared: Dictionary, parameter_name: String, value: Variant) -> void:
	if declared.has(parameter_name):
		material.set_shader_parameter(parameter_name, value)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Could not open " + path + ": " + error_string(FileAccess.get_open_error()))
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _extract_function_body(source: String, signature: String) -> String:
	var signature_start := source.find(signature)
	if signature_start < 0:
		_errors.append("Could not find function signature " + signature)
		return ""
	var brace_start := source.find("{", signature_start)
	if brace_start < 0:
		_errors.append("Could not find opening brace for " + signature)
		return ""

	var depth := 0
	for index in range(brace_start, source.length()):
		var character := source.substr(index, 1)
		if character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return source.substr(brace_start + 1, index - brace_start - 1)

	_errors.append("Could not find closing brace for " + signature)
	return ""


func _count_occurrences(text: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	var count := 0
	var offset := 0
	while true:
		var match_index := text.find(needle, offset)
		if match_index < 0:
			break
		count += 1
		offset = match_index + needle.length()
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_SHADER_COST_PROBE_RESULTS=", _results)
		print("RIPPLE_SHADER_COST_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	print("RIPPLE_SHADER_COST_PROBE_RESULTS=", _results)
	quit(1)
