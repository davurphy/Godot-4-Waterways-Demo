extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")
const RiverBakeData = preload("res://addons/waterways/resources/river_bake_data.gd")
const FilterRendererScript = preload("res://addons/waterways/filter_renderer.gd")

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_filter_pass_descriptors()
	await _check_property_list_and_channels()
	_check_river_bake_data_finalize()
	_finish()


func _check_filter_pass_descriptors() -> void:
	var renderer: Node = FilterRendererScript.new()
	var constants: Dictionary = renderer.get_script().get_script_constant_map()
	renderer.free()
	var descriptors: Dictionary = constants.get("PASS_DESCRIPTORS", {})
	_expect(not descriptors.is_empty(), "FilterRenderer should expose pass descriptors.")

	var unique_shader_paths := {}
	for pass_name in descriptors:
		var descriptor: Dictionary = descriptors[pass_name]
		var shader_path := String(descriptor.get("shader_path", ""))
		_expect(not shader_path.is_empty(), "Filter pass " + String(pass_name) + " should declare a shader path.")
		_expect(load(shader_path) != null, "Filter pass " + String(pass_name) + " shader should load: " + shader_path)
		unique_shader_paths[shader_path] = true
		var texture_policies: Dictionary = descriptor.get("textures", {})
		_expect(not texture_policies.is_empty(), "Filter pass " + String(pass_name) + " should declare texture policies.")
	_expect(unique_shader_paths.size() == 19, "Filter descriptors should cover the 19 pass shaders; got " + str(unique_shader_paths.size()) + ".")

	_expect(String(descriptors["combine"].textures["b_texture"].get("default", "")) == "black", "Combine B texture should use the descriptor default policy.")
	_expect(String(descriptors["combine"].textures["a_texture"].get("default", "")) == "white", "Combine A texture should use the descriptor default policy.")
	_expect(String(descriptors["obstacle_feature"].textures["bank_response_texture"].get("default", "")) == "black", "Obstacle feature bank-response fallback should be descriptor-owned.")
	_expect(String(descriptors["obstacle_feature"].textures["grade_energy_texture"].get("default", "")) == "white", "Obstacle feature grade-energy fallback should be descriptor-owned.")
	_expect(bool(descriptors["flow_divergence"].get("hdr", false)), "Flow divergence should own HDR selection through the descriptor.")
	_expect(bool(descriptors["flow_pressure_jacobi"].get("hdr", false)), "Jacobi pressure should own HDR selection through the descriptor.")


func _check_property_list_and_channels() -> void:
	var river := RiverManager.new()
	river.name = "R5PropertyAndChannelRiver"
	root.add_child(river)
	await _settle_frames(2)

	var property_names := PackedStringArray()
	for info in river.get_property_list():
		property_names.append(String(info.get("name", "")))
	_expect(property_names.has("widths"), "River property list should keep widths storage.")
	_expect(property_names.has("flow_speeds"), "River property list should keep flow_speeds.")

	var baking_group_index := _find_last_property_index(property_names, "Baking")
	var bake_data_index := _find_last_property_index(property_names, "bake_data")
	_expect(baking_group_index >= 0, "River property list should keep the Baking group.")
	_expect(bake_data_index > baking_group_index, "bake_data should stay after the Baking group.")

	var constants: Dictionary = river.get_script().get_script_constant_map()
	var baking_descriptors: Array = constants.get("BAKING_PROPERTY_DESCRIPTORS", [])
	var previous_index := baking_group_index
	for descriptor in baking_descriptors:
		var property_name := String(descriptor.get("name", ""))
		var property_index := _find_last_property_index(property_names, property_name)
		_expect(property_index > previous_index, property_name + " should appear in descriptor order.")
		_expect(property_index < bake_data_index, property_name + " should stay before bake_data.")
		previous_index = property_index

	_check_channel_padding_and_round_trip(river)
	river.queue_free()
	await _settle_frames(2)


func _check_channel_padding_and_round_trip(river: Node) -> void:
	var curve := river.get("curve") as Curve3D
	curve.clear_points()
	curve.add_point(Vector3(0.0, 0.0, 0.0))
	curve.add_point(Vector3(1.0, 0.0, 0.0))
	curve.add_point(Vector3(2.0, 0.0, 0.0))

	river.call("set_widths", [1.0, 1.5, 2.0])
	river.call("set_flow_speeds", [1.0, 0.5, 1.5])
	river.set("valid_flowmap", true)
	var original_curve_state: Dictionary = river.call("get_curve_state")
	var original_valid_state: Dictionary = river.call("get_generated_bake_valid_state")

	curve.set_point_position(1, Vector3(1.0, 0.0, 1.0))
	river.call("set_widths", [4.0, 5.0, 6.0])
	river.call("set_flow_speeds", [2.0, 2.0, 2.0])
	river.call("restore_curve_state_with_generated_bake_valid_state", original_curve_state, original_valid_state)

	_expect(_arrays_close(river.get("widths") as Array, [1.0, 1.5, 2.0]), "Curve-state restore should round-trip widths.")
	_expect(_arrays_close(river.get("flow_speeds") as Array, [1.0, 0.5, 1.5]), "Curve-state restore should round-trip flow_speeds.")
	_expect((river.get("curve") as Curve3D).get_point_position(1).is_equal_approx(Vector3(1.0, 0.0, 0.0)), "Curve-state restore should round-trip point positions.")
	_expect(bool(river.get("valid_flowmap")), "Generated-bake valid state should restore after a curve-state round trip.")

	river.call("set_widths", [2.0])
	river.call("set_flow_speeds", [0.75])
	_expect(_arrays_close(river.get("widths") as Array, [2.0, 2.0, 2.0]), "Width channel should pad from the last value.")
	_expect(_arrays_close(river.get("flow_speeds") as Array, [0.75, 0.75, 0.75]), "Flow-speed channel should pad from the last value.")


func _check_river_bake_data_finalize() -> void:
	var data := RiverBakeData.new()
	var source_metadata := {"nested": {"value": 1}}
	var bake_settings := {"resolution": 256}
	var source_signature := {"version": 28, "marker": "r5"}
	data.source_metadata = source_metadata
	data.bake_settings = bake_settings
	data.source_signature = source_signature
	data.finalize()

	(source_metadata["nested"] as Dictionary)["value"] = 9
	bake_settings["resolution"] = 512
	source_signature["version"] = 99

	_expect(int((data.source_metadata["nested"] as Dictionary).get("value", 0)) == 1, "RiverBakeData.finalize should deep-copy source metadata.")
	_expect(int(data.bake_settings.get("resolution", 0)) == 256, "RiverBakeData.finalize should copy bake settings.")
	_expect(int(data.source_signature.get("version", 0)) == 28, "RiverBakeData.finalize should copy source signature.")
	_expect(data.source_signature_version == 28, "RiverBakeData.finalize should refresh source_signature_version.")
	_expect(not data.channel_metadata.is_empty(), "RiverBakeData.finalize should restore default channel metadata.")
	_expect(not data.import_profile.is_empty(), "RiverBakeData.finalize should restore default import profile.")


func _arrays_close(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if absf(float(actual[index]) - float(expected[index])) > 0.0001:
			return false
	return true


func _find_last_property_index(property_names: PackedStringArray, property_name: String) -> int:
	for index in range(property_names.size() - 1, -1, -1):
		if property_names[index] == property_name:
			return index
	return -1


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("R5_BEHAVIOR_PRESERVATION_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
