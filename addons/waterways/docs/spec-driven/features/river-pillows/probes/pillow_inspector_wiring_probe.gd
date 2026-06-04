extends SceneTree

const EXPECTED_SIGNATURE_VERSION := 20
const RIVER_MANAGER_SCRIPT := "res://addons/waterways/river_manager.gd"
const VISIBLE_SHADER := "res://addons/waterways/shaders/river.gdshader"
const DEBUG_SHADER := "res://addons/waterways/shaders/river_debug.gdshader"

const SCENES := [
	{"path": "res://Demo.tscn", "river_path": "WaterSystem/Water River", "name": "main demo"},
	{"path": "res://Demo_obstacle_flow_test.tscn", "river_path": "WaterSystem/Water River", "name": "obstacle test"},
]

const PILLOW_BASELINE_FLOATS := {
	"pillow_strength": 1.15,
	"pillow_forward_reach_tiles": 0.0,
	"pillow_contact_pull_tiles": 0.0,
	"pillow_contact_pull_strength": 0.0,
	"pillow_terrain_height": 0.0,
	"pillow_terrain_height_curve": 1.35,
	"pillow_obstruction_height": 0.0,
	"pillow_obstruction_height_curve": 1.35,
	"pillow_height_tile_seam_fade": 0.0,
}

const PILLOW_UNIFORMS := [
	"pillow_strength",
	"pillow_confidence_gate_start",
	"pillow_confidence_gate_full",
	"pillow_hard_gate_start",
	"pillow_hard_gate_full",
	"pillow_energy_gate_start",
	"pillow_energy_gate",
	"pillow_flow_gate_start",
	"pillow_flow_gate",
	"pillow_bank_suppression",
	"pillow_pressure_strength",
	"pillow_highlight_strength",
	"pillow_pressure_color",
	"pillow_highlight_color",
	"pillow_specular_boost",
	"pillow_roughness_reduction",
	"pillow_normal_strength",
	"pillow_band_strength",
	"pillow_band_scale",
	"pillow_foam_bias",
	"pillow_forward_reach_tiles",
	"pillow_contact_pull_tiles",
	"pillow_contact_pull_strength",
	"pillow_terrain_height",
	"pillow_terrain_height_curve",
	"pillow_obstruction_height",
	"pillow_obstruction_height_curve",
	"pillow_height_smoothing_tiles",
	"pillow_height_seam_stitch_tiles",
	"pillow_height_tile_seam_fade",
	"pillow_material_tile_seam_fade",
]

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_static_wiring()
	_check_shader_uniforms()
	_check_scene_baselines()
	_check_fresh_river_wiring()
	if _errors.is_empty():
		print("PILLOW_INSPECTOR_WIRING_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _check_static_wiring() -> void:
	var manager := _read_text(RIVER_MANAGER_SCRIPT)
	_expect(manager.contains("RIVER_BAKE_SOURCE_SIGNATURE_VERSION := " + str(EXPECTED_SIGNATURE_VERSION)), "river bake signature should be version " + str(EXPECTED_SIGNATURE_VERSION))
	_expect(manager.contains("pillow_ = \"Pillow\""), "river inspector should group pillow_ controls")
	for subgroup_name in ["Pillow Shape", "Pillow Mask Gates", "Pillow Surface", "Pillow Bands & Foam", "Pillow Height", "Pillow Seam Fades"]:
		_expect(manager.contains("name = \"" + subgroup_name + "\""), "river inspector should expose subgroup " + subgroup_name)
	_expect(manager.contains("_should_use_easing_curve_hint(cp)"), "inspector should preserve explicit shader hints before applying easing curve hints")
	_expect(manager.contains("shader_parameter/"), "material revert wiring should use Godot 4 shader_parameter property names")
	_expect(manager.contains("_sync_debug_material_from_visible_material()"), "debug material should sync from the visible material")
	_expect(manager.contains("pillow_forward_reach_tiles = 0.0"), "pillow reach should have an explicit editor revert default")
	_expect(manager.contains("pillow_contact_pull_tiles = 0.0"), "pillow contact pull should have an explicit editor revert default")
	_expect(manager.contains("pillow_contact_pull_strength = 0.0"), "pillow contact pull strength should have an explicit editor revert default")


func _check_shader_uniforms() -> void:
	var visible_uniforms := _shader_uniform_names(VISIBLE_SHADER)
	var debug_uniforms := _shader_uniform_names(DEBUG_SHADER)
	for uniform_name in PILLOW_UNIFORMS:
		_expect(visible_uniforms.has(uniform_name), VISIBLE_SHADER + " missing " + uniform_name)
		_expect(debug_uniforms.has(uniform_name), DEBUG_SHADER + " missing " + uniform_name)
	var debug_shader := _read_text(DEBUG_SHADER)
	for constant_name in [
		"PILLOW_VISUAL_MASK_NO_REACH_BLACK_ZERO",
		"PILLOW_DIRECT_TERRAIN_ANCHOR_SEARCH",
		"PILLOW_BANK_RESPONSE_ANCHOR_SEARCH",
		"PILLOW_COMBINED_CONTACT_GATE",
		"PILLOW_BANK_ONLY_ANCHOR_CONTRIBUTION",
		"PILLOW_RAW_TO_FINAL_RETENTION",
		"PILLOW_MATERIAL_RESPONSE_MASK",
		"PILLOW_MATERIAL_SEAM_GUARD",
		"PILLOW_HEIGHT_SEAM_GUARD",
		"PILLOW_HEIGHT_SEAM_STITCH",
		"PILLOW_VISUAL_MASK_BLACK_ZERO",
	]:
		_expect(debug_shader.contains("const int " + constant_name), "debug shader should define " + constant_name)


func _check_scene_baselines() -> void:
	for scene_info in SCENES:
		var scene_path := String(scene_info.path)
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, scene_path + " should load")
		if packed == null:
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		var river := scene.get_node_or_null(String(scene_info.river_path))
		_expect(river != null, scene_path + " should contain " + String(scene_info.river_path))
		if river != null:
			_check_pillow_baseline(String(scene_info.name), river)
		scene.queue_free()


func _check_fresh_river_wiring() -> void:
	var river_script := load(RIVER_MANAGER_SCRIPT) as Script
	_expect(river_script != null, "river manager script should load")
	if river_script == null:
		return
	var river := river_script.new() as Node
	_expect(river != null, "river manager script should instantiate a node")
	if river == null:
		return
	root.add_child(river)
	river.call("_generate_river")
	_check_property_hints("fresh river", river)
	_check_material_mirror("fresh river", river)
	river.queue_free()


func _check_pillow_baseline(label: String, river: Node) -> void:
	var material := river.get("_material") as ShaderMaterial
	var debug_material := river.get("_debug_material") as ShaderMaterial
	_expect(material != null, label + " should have a visible ShaderMaterial")
	_expect(debug_material != null, label + " should have a debug ShaderMaterial")
	for param_name in PILLOW_BASELINE_FLOATS.keys():
		var expected := float(PILLOW_BASELINE_FLOATS[param_name])
		var inspector_name := "mat_" + String(param_name)
		_expect(_variant_is_close(river.get(inspector_name), expected), label + " inspector " + inspector_name + " should be " + str(expected))
		if material != null:
			_expect(_is_close(_float_shader_param(material, String(param_name)), expected), label + " visible shader " + String(param_name) + " should be " + str(expected))
		if debug_material != null:
			_expect(_is_close(_float_shader_param(debug_material, String(param_name)), expected), label + " debug shader " + String(param_name) + " should be " + str(expected))


func _check_property_hints(label: String, river: Node) -> void:
	var terrain_curve := _property_info(river, "mat_pillow_terrain_height_curve")
	var obstruction_curve := _property_info(river, "mat_pillow_obstruction_height_curve")
	var albedo_curve := _property_info(river, "mat_albedo_depth_curve")
	_expect(not terrain_curve.is_empty(), label + " should expose mat_pillow_terrain_height_curve")
	_expect(not obstruction_curve.is_empty(), label + " should expose mat_pillow_obstruction_height_curve")
	_expect(not albedo_curve.is_empty(), label + " should expose mat_albedo_depth_curve")
	if not terrain_curve.is_empty():
		_expect(int(terrain_curve.get("hint", -1)) == PROPERTY_HINT_RANGE, label + " terrain pillow height curve should keep the shader range hint")
		_expect(String(terrain_curve.get("hint_string", "")).contains("0.25") and String(terrain_curve.get("hint_string", "")).contains("4"), label + " terrain pillow height curve should expose the 0.25..4.0 range")
	if not obstruction_curve.is_empty():
		_expect(int(obstruction_curve.get("hint", -1)) == PROPERTY_HINT_RANGE, label + " obstruction pillow height curve should keep the shader range hint")
		_expect(String(obstruction_curve.get("hint_string", "")).contains("0.25") and String(obstruction_curve.get("hint_string", "")).contains("4"), label + " obstruction pillow height curve should expose the 0.25..4.0 range")
	if not albedo_curve.is_empty():
		_expect(int(albedo_curve.get("hint", -1)) == PROPERTY_HINT_EXP_EASING, label + " unhinted depth curve should still use the easing editor")


func _check_material_mirror(label: String, river: Node) -> void:
	var material := river.get("_material") as ShaderMaterial
	var debug_material := river.get("_debug_material") as ShaderMaterial
	_expect(material != null, label + " should have a visible ShaderMaterial")
	_expect(debug_material != null, label + " should have a debug ShaderMaterial")
	if material == null or debug_material == null:
		return
	for raw_param_name in ["pillow_forward_reach_tiles", "pillow_contact_pull_tiles", "pillow_contact_pull_strength"]:
		var param_name := String(raw_param_name)
		var inspector_name := "mat_" + param_name
		river.set(inspector_name, 0.123)
		_expect(_is_close(_float_shader_param(material, param_name), 0.123), label + " setter should update visible " + param_name)
		_expect(_is_close(_float_shader_param(debug_material, param_name), 0.123), label + " setter should update debug " + param_name)
		_expect(river.property_can_revert(inspector_name), label + " should expose revert for " + inspector_name)
		_expect(_variant_is_close(river.property_get_revert(inspector_name), 0.0), label + " revert should use 0.0 for " + inspector_name)
		river.set(inspector_name, 0.0)
		_expect(_is_close(_float_shader_param(material, param_name), 0.0), label + " reset should update visible " + param_name)
		_expect(_is_close(_float_shader_param(debug_material, param_name), 0.0), label + " reset should update debug " + param_name)
	river.set("mat_pillow_terrain_height_curve", 1.75)
	river.set("mat_pillow_obstruction_height_curve", 1.95)
	_expect(_is_close(_float_shader_param(material, "pillow_terrain_height_curve"), 1.75), label + " terrain height curve setter should update visible material")
	_expect(_is_close(_float_shader_param(debug_material, "pillow_terrain_height_curve"), 1.75), label + " terrain height curve setter should update debug material")
	_expect(_is_close(_float_shader_param(material, "pillow_obstruction_height_curve"), 1.95), label + " obstruction height curve setter should update visible material")
	_expect(_is_close(_float_shader_param(debug_material, "pillow_obstruction_height_curve"), 1.95), label + " obstruction height curve setter should update debug material")
	_expect(river.property_can_revert("mat_pillow_terrain_height_curve"), label + " terrain height curve should expose revert")
	_expect(_variant_is_close(river.property_get_revert("mat_pillow_terrain_height_curve"), 1.35), label + " terrain height curve revert should use shader default")


func _property_info(node: Object, property_name: String) -> Dictionary:
	for info in node.get_property_list():
		if String(info.name) == property_name:
			return info
	return {}


func _shader_uniform_names(shader_path: String) -> PackedStringArray:
	var names := PackedStringArray()
	var shader := load(shader_path) as Shader
	_expect(shader != null, shader_path + " did not load as a Shader")
	if shader == null:
		return names
	var shader_params: Array = RenderingServer.get_shader_parameter_list(shader.get_rid())
	for param in shader_params:
		names.append(String(param.name))
	return names


func _float_shader_param(material: ShaderMaterial, param_name: String) -> float:
	var value = material.get_shader_parameter(param_name)
	if value == null:
		return INF
	return float(value)


func _is_close(a: float, b: float) -> bool:
	return absf(a - b) <= 0.0001


func _variant_is_close(value: Variant, expected: float) -> bool:
	if value == null:
		return false
	return _is_close(float(value), expected)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null, "Could not open " + path)
	if file == null:
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
