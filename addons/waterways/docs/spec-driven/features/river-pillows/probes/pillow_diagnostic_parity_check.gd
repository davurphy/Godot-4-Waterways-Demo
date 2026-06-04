extends SceneTree

var _errors: PackedStringArray = []


func _init() -> void:
	_check_bake_constant_parity()
	_check_black_zero_debug_modes()
	if _errors.is_empty():
		print("PILLOW_DIAGNOSTIC_PARITY_CHECK_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _check_bake_constant_parity() -> void:
	var manager_code := _read_text("res://addons/waterways/river_manager.gd")
	var filter_code := _read_text("res://addons/waterways/shaders/filters/obstacle_feature_mask_filter.gdshader")
	var debug_shader_code := _read_text("res://addons/waterways/shaders/river_debug.gdshader")

	var manager_constants := {
		"support_start": _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START"),
		"support_full": _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL"),
		"contact_search_tiles": _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES"),
		"contact_gate_start": _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START"),
		"contact_gate_full": _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL"),
	}

	_expect_close(manager_constants["support_start"], _shader_uniform_float(filter_code, "pillow_support_start"), "filter pillow_support_start should match river manager")
	_expect_close(manager_constants["support_full"], _shader_uniform_float(filter_code, "pillow_support_full"), "filter pillow_support_full should match river manager")
	_expect_close(manager_constants["contact_gate_start"], _shader_uniform_float(filter_code, "pillow_contact_gate_start"), "filter pillow_contact_gate_start should match river manager")
	_expect_close(manager_constants["contact_gate_full"], _shader_uniform_float(filter_code, "pillow_contact_gate_full"), "filter pillow_contact_gate_full should match river manager")

	_expect_close(manager_constants["contact_search_tiles"], _shader_const_float(debug_shader_code, "PILLOW_BAKE_CONTACT_SEARCH_TILES"), "debug pillow contact-search tiles should match river manager")
	_expect_close(manager_constants["contact_gate_start"], _shader_const_float(debug_shader_code, "PILLOW_BAKE_CONTACT_GATE_START"), "debug pillow contact-gate start should match river manager")
	_expect_close(manager_constants["contact_gate_full"], _shader_const_float(debug_shader_code, "PILLOW_BAKE_CONTACT_GATE_FULL"), "debug pillow contact-gate full should match river manager")

	_expect(manager_code.contains("RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES / feature_uv_denominator"), "river manager should derive filter pillow_contact_search_uv from contact-search tiles")
	_expect(manager_code.contains("\"obstacle_features_pillow_contact_search_tiles\": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES"), "bake metadata should record pillow contact-search tiles")


func _check_black_zero_debug_modes() -> void:
	var menu_code := _read_text("res://addons/waterways/gui/debug_view_menu.gd")
	var debug_shader_code := _read_text("res://addons/waterways/shaders/river_debug.gdshader")
	var constants := _debug_shader_constants(debug_shader_code)
	var handled_mode_ids := _debug_shader_handled_mode_ids(debug_shader_code, constants)
	var menu_items := _array_items(menu_code, "DEBUG_VIEW_ITEMS", "SUBMENU_NAME_PREFIX")
	var labels_by_id := {}
	for item in menu_items:
		labels_by_id[int(item[1])] = String(item[0])

	_expect(labels_by_id.get(48, "") == "Pillow No-Reach Mask (Black Zero)", "mode 48 should be labeled as the no-reach Black Zero mask")
	_expect(labels_by_id.get(58, "") == "Pillow Visual Mask (Black Zero)", "mode 58 should be the true Black Zero pillow visual mask")
	_expect(constants.get("PILLOW_VISUAL_MASK_NO_REACH_BLACK_ZERO", -1) == 48, "debug shader should define mode 48 as no-reach Black Zero")
	_expect(constants.get("PILLOW_VISUAL_MASK_BLACK_ZERO", -1) == 58, "debug shader should define mode 58 as true visual Black Zero")
	_expect(handled_mode_ids.has(48), "debug shader should handle mode 48")
	_expect(handled_mode_ids.has(58), "debug shader should handle mode 58")
	_expect(debug_shader_code.contains("black_zero_to_heat(pillow_visual_no_reach)"), "mode 48 should render no-reach pillow visual")
	_expect(debug_shader_code.contains("black_zero_to_heat(pillow_visual)"), "mode 58 should render the normal pillow visual")


func _array_items(source_code: String, const_name: String, next_token: String) -> Array:
	var items := []
	var block_regex := RegEx.new()
	block_regex.compile("const " + const_name + " := \\[([\\s\\S]*?)\\]\\s*const " + next_token)
	var block_result := block_regex.search(source_code)
	_expect(block_result != null, "debug menu should define " + const_name)
	if block_result == null:
		return items
	var item_regex := RegEx.new()
	item_regex.compile("\\[\"([^\"]+)\",\\s*([0-9]+)\\]")
	for result in item_regex.search_all(block_result.get_string(1)):
		items.append([String(result.get_string(1)), int(result.get_string(2))])
	return items


func _debug_shader_constants(shader_code: String) -> Dictionary:
	var constants := {}
	var regex := RegEx.new()
	regex.compile("const int ([A-Z0-9_]+) = ([0-9]+);")
	for result in regex.search_all(shader_code):
		constants[String(result.get_string(1))] = int(result.get_string(2))
	return constants


func _debug_shader_handled_mode_ids(shader_code: String, constants: Dictionary) -> Dictionary:
	var handled_mode_ids := {}
	var regex := RegEx.new()
	regex.compile("mode == ([A-Z0-9_]+)")
	for result in regex.search_all(shader_code):
		var constant_name := String(result.get_string(1))
		if constants.has(constant_name):
			handled_mode_ids[int(constants[constant_name])] = true
	return handled_mode_ids


func _gd_const_float(source_code: String, name: String) -> float:
	return _regex_float(source_code, "const " + name + " := ([0-9]+(?:\\.[0-9]+)?)", "GDScript constant " + name)


func _shader_const_float(source_code: String, name: String) -> float:
	return _regex_float(source_code, "const float " + name + " = ([0-9]+(?:\\.[0-9]+)?);", "shader constant " + name)


func _shader_uniform_float(source_code: String, name: String) -> float:
	return _regex_float(source_code, "uniform float " + name + " = ([0-9]+(?:\\.[0-9]+)?);", "shader uniform " + name)


func _regex_float(source_code: String, pattern: String, context: String) -> float:
	var regex := RegEx.new()
	regex.compile(pattern)
	var result := regex.search(source_code)
	_expect(result != null, context + " should exist")
	if result == null:
		return INF
	return float(result.get_string(1))


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null, "Could not open " + path)
	if file == null:
		return ""
	return file.get_as_text()


func _expect_close(actual: float, expected: float, message: String) -> void:
	if is_inf(actual) or is_inf(expected):
		return
	if abs(actual - expected) <= 0.0001:
		return
	_errors.append(message + ": got " + str(actual) + " expected " + str(expected))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
