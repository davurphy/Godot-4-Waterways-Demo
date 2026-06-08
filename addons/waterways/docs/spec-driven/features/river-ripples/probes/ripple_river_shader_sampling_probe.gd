extends SceneTree

const RIVER_SHADER_PATH := "res://addons/waterways/shaders/river.gdshader"
const REQUIRED_HELPER_SIGNATURES := [
	"vec3 ripple_fragment_world_position(",
	"vec2 ripple_world_to_uv(",
	"bool ripple_sampling_ready()",
	"float ripple_uv_bounds_mask(",
	"float ripple_boundary_mask_unchecked(",
	"float ripple_height_at_uv(",
	"float ripple_height_at_world(",
	"float ripple_distance_fade(",
	"vec2 ripple_normal_offset_at_uv(",
	"vec2 ripple_normal_offset_at_world(",
]

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var shader := load(RIVER_SHADER_PATH) as Shader
	_expect(shader != null, "River shader should load after adding ripple sampling helpers.")

	var source := _read_text(RIVER_SHADER_PATH)
	_expect(not source.is_empty(), "River shader source should be readable for sampling-budget review.")
	if source.is_empty():
		_finish()
		return

	for signature in REQUIRED_HELPER_SIGNATURES:
		_expect(source.find(signature) >= 0, "River shader should declare helper " + signature)

	_validate_world_to_uv_mapping(source)
	_validate_sampling_ready_guard(source)
	_validate_height_helper(source)
	_validate_normal_budget(source)
	_validate_visible_normal_blend(source)

	_finish()


func _validate_world_to_uv_mapping(source: String) -> void:
	var body := _extract_function_body(source, "vec2 ripple_world_to_uv(")
	_expect(body.find("mapped.xz") >= 0, "River shader ripple mapping should use world X/Z as ripple U/V.")
	_expect(body.find("mapped.xy") < 0, "River shader ripple mapping should not use world X/Y for flat river surfaces.")
	_results["world_to_uv_uses_xz"] = body.find("mapped.xz") >= 0


func _validate_sampling_ready_guard(source: String) -> void:
	var body := _extract_function_body(source, "bool ripple_sampling_ready()")
	for required in [
		"i_ripple_enabled",
		"textureSize(i_ripple_simulation_texture, 0)",
		"textureSize(i_ripple_boundary_mask, 0)",
		"i_ripple_texel_size.x > EPSILON",
		"i_ripple_texel_size.y > EPSILON",
		"simulation_size.x > 1",
		"simulation_size.y > 1",
		"boundary_size.x > 1",
		"boundary_size.y > 1",
	]:
		_expect(body.find(required) >= 0, "Ripple sampling guard should include " + required)
	_results["sampling_guard_checked"] = true


func _validate_height_helper(source: String) -> void:
	var body := _extract_function_body(source, "float ripple_height_at_uv(")
	var simulation_samples := _count_occurrences(body, "textureLod(i_ripple_simulation_texture")
	var boundary_calls := _count_occurrences(body, "ripple_boundary_mask_unchecked(")
	_expect(simulation_samples == 1, "Height helper should use exactly one simulation texture sample; found " + str(simulation_samples))
	_expect(boundary_calls == 1, "Height helper should call the boundary mask helper once; found " + str(boundary_calls))
	_results["height_helper_simulation_samples"] = simulation_samples
	_results["height_helper_boundary_calls"] = boundary_calls


func _validate_normal_budget(source: String) -> void:
	var body := _extract_function_body(source, "vec2 ripple_normal_offset_at_uv(")
	var simulation_samples := _count_occurrences(body, "textureLod(i_ripple_simulation_texture")
	var boundary_calls := _count_occurrences(body, "ripple_boundary_mask_unchecked(")
	var height_helper_calls := _count_occurrences(body, "ripple_height_at_uv(")
	_expect(simulation_samples == 3, "Normal helper should stay at three simulation samples; found " + str(simulation_samples))
	_expect(boundary_calls == 1, "Normal helper should call the boundary mask helper once; found " + str(boundary_calls))
	_expect(height_helper_calls == 0, "Normal helper should not call the height helper because that would hide extra samples.")
	_results["normal_helper_simulation_samples"] = simulation_samples
	_results["normal_helper_boundary_calls"] = boundary_calls
	_results["normal_helper_height_helper_calls"] = height_helper_calls


func _validate_visible_normal_blend(source: String) -> void:
	var body := _extract_function_body(source, "void fragment()")
	var normal_world_calls := _count_occurrences(body, "ripple_normal_offset_at_world(")
	var normal_uv_calls := _count_occurrences(body, "ripple_normal_offset_at_uv(")
	var height_sample_calls := _count_occurrences(body, "ripple_height_at_")
	_expect(normal_world_calls == 1, "Visible normal slice should call ripple_normal_offset_at_world() exactly once; found " + str(normal_world_calls))
	_expect(normal_uv_calls == 0, "Visible normal slice should not call ripple_normal_offset_at_uv() directly from fragment.")
	_expect(height_sample_calls == 0, "Visible normal slice should not use ripple height directly in fragment.")
	_expect(body.find("ripple_fragment_world_position(INV_VIEW_MATRIX, VERTEX)") >= 0, "Visible normal slice should pass fragment view position through the world-position helper.")
	_expect(body.find("CAMERA_POSITION_WORLD") >= 0, "Visible normal slice should pass CAMERA_POSITION_WORLD into the distance fade path.")
	_results["fragment_ripple_normal_world_calls"] = normal_world_calls
	_results["fragment_ripple_normal_uv_calls"] = normal_uv_calls
	_results["fragment_ripple_height_calls"] = height_sample_calls


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
		print("RIPPLE_RIVER_SHADER_SAMPLING_PROBE_RESULTS=", _results)
		print("RIPPLE_RIVER_SHADER_SAMPLING_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
