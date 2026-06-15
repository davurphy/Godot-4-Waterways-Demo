# River-refactor R7 promoted saved-resource load smoke.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_saved_resource_load_smoke_probe.gd -- out=res://.codex-research/r7-baselines/compute-saved-resource-load-smoke
#
# Success marker: R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")

const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-saved-resource-load-smoke"
const REPORT_FILE_NAME := "r7_compute_saved_resource_load_smoke.txt"

const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

const SMOKE_CASES := [
	{
		"label": "obstacle_flow_authored_river_saved_load",
		"scene": "res://Demo_obstacle_flow_test.tscn",
		"river": "WaterSystem/Water River",
		"river_bake_resource": "res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
		"water_system_bake_resource": "res://waterways_bakes/Demo_obstacle_flow_test/WaterSystem.water_system_bake.res",
	},
	{
		"label": "demo_authored_river_saved_load",
		"scene": "res://Demo.tscn",
		"river": "WaterSystem/Water River",
		"river_bake_resource": "res://waterways_bakes/Demo/Water_River.river_bake.res",
		"water_system_bake_resource": "res://waterways_bakes/Demo_28018/WaterSystem.water_system_bake.res",
	},
]

const DEBUG_VIEW_IDS := [0, 10, 7, 8]

var _errors := PackedStringArray()
var _report_lines := PackedStringArray()
var _written_report := ""


func _initialize() -> void:
	Engine.time_scale = 1.0
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	_report_lines.append("R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_DUMP v1")
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + str(RenderingServer.get_video_adapter_vendor()))
	_report_lines.append("default_backend_mode=" + RiverFlowmapBaker.get_default_flowmap_backend_mode())
	_report_lines.append("load_only=true")
	_report_lines.append("rebake_invoked=false")
	_report_lines.append("resource_saver_invoked=false")

	var reports := []
	var passed := PackedStringArray()
	var failed := PackedStringArray()
	for case_value in SMOKE_CASES:
		var spec := _dictionary_from_variant(case_value)
		var report := await _run_case(spec)
		reports.append(report)
		var label := String(report.get("label", ""))
		if bool(report.get("ok", false)):
			passed.append(label)
		else:
			failed.append(label)
		_append_result("saved_load_case_" + label, report)

	var summary := _make_summary(reports, passed, failed)
	_append_result("saved_resource_load_smoke", summary)
	_report_lines.append("errors=" + str(_errors))
	_verify_summary(summary)

	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _run_case(spec: Dictionary) -> Dictionary:
	var label := String(spec.get("label", "unnamed_saved_load"))
	var scene_path := String(spec.get("scene", ""))
	var river_path := String(spec.get("river", ""))
	var expected_river_resource := String(spec.get("river_bake_resource", ""))
	var water_system_resource := String(spec.get("water_system_bake_resource", ""))
	var before_river_file_md5 := _file_md5(expected_river_resource)
	var before_water_system_file_md5 := _file_md5(water_system_resource)
	var scene := await _load_scene(scene_path)
	var river := scene.get_node_or_null(river_path) if scene != null else null
	var result := {
		"ok": false,
		"reason": "not_run",
		"label": label,
		"scene": scene_path,
		"river": river_path,
		"expected_river_bake_resource": expected_river_resource,
		"water_system_bake_resource": water_system_resource,
		"before_river_file_md5": before_river_file_md5,
		"before_water_system_file_md5": before_water_system_file_md5,
	}
	if river == null:
		result.reason = "river_not_found"
		_errors.append(label + ": river not found at " + river_path + ".")
		_free_scene(scene)
		return result

	var bake_data := river.get("bake_data") as Resource
	var metadata := _resource_dictionary(bake_data, "source_metadata")
	var signature := _resource_dictionary(bake_data, "source_signature")
	var texture_report := _texture_report(river, bake_data)
	var binding_report := _binding_report(river, bake_data)
	var debug_report := await _debug_view_report(river)
	var source_matches := false
	if river.has_method("_bake_data_matches_current_source"):
		source_matches = bool(river.call("_bake_data_matches_current_source"))
	var after_river_file_md5 := _file_md5(expected_river_resource)
	var after_water_system_file_md5 := _file_md5(water_system_resource)
	var runtime_concerns := _runtime_concerns(river, bake_data, texture_report, binding_report, debug_report)
	var output_keys = metadata.get("output_texture_keys", PackedStringArray())
	var replacement_result := _dictionary_from_variant(metadata.get("canonical_compute_replacement_result", {}))
	var selection := _dictionary_from_variant(metadata.get("flowmap_backend_selection", {}))
	var resource_path := bake_data.resource_path if bake_data != null else ""
	var ok := (
		bake_data != null
		and resource_path == expected_river_resource
		and bool(river.get("valid_flowmap"))
		and source_matches
		and int(bake_data.get("source_signature_version")) == 29
		and int(signature.get("version", -1)) == 29
		and String(metadata.get("flowmap_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
		and bool(metadata.get("production_output_replaced", false))
		and _array_has_string(output_keys, "flow_foam_noise")
		and _output_key_count(output_keys) == 1
		and bool(texture_report.get("ok", false))
		and bool(binding_report.get("ok", false))
		and bool(debug_report.get("ok", false))
		and runtime_concerns.is_empty()
		and before_river_file_md5 == after_river_file_md5
		and before_water_system_file_md5 == after_water_system_file_md5
	)

	result.ok = ok
	result.reason = "ok" if ok else "saved_resource_load_smoke_failed_invariants"
	result.bake_data_present = bake_data != null
	result.bake_data_resource_path = resource_path
	result.river_file_md5_unchanged = before_river_file_md5 == after_river_file_md5
	result.after_river_file_md5 = after_river_file_md5
	result.water_system_file_md5_unchanged = before_water_system_file_md5 == after_water_system_file_md5
	result.after_water_system_file_md5 = after_water_system_file_md5
	result.valid_flowmap = bool(river.get("valid_flowmap"))
	result.source_signature_matches_current_scene = source_matches
	result.source_signature_version = int(bake_data.get("source_signature_version")) if bake_data != null else -1
	result.source_signature_version_field = int(signature.get("version", -1))
	result.metadata_flowmap_backend_mode = String(metadata.get("flowmap_backend_mode", ""))
	result.metadata_production_output_replaced = bool(metadata.get("production_output_replaced", false))
	result.metadata_output_texture_keys = output_keys
	result.metadata_selected_mode = String(selection.get("selected_mode", ""))
	result.metadata_fallback_applied = bool(selection.get("fallback_applied", false))
	result.replacement_summary = _replacement_summary(replacement_result)
	result.texture_report = texture_report
	result.binding_report = binding_report
	result.debug_view_report = debug_report
	result.runtime_concerns = runtime_concerns
	result.visible_runtime_note = "load_only_smoke; no bake, no screenshot capture, debug views switched without missing texture/material state" if runtime_concerns.is_empty() else "runtime_concerns_recorded"

	_free_scene(scene)
	return result


func _load_scene(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene " + scene_path + ".")
		return null
	var scene := packed.instantiate()
	if scene == null:
		_errors.append("Could not instantiate scene " + scene_path + ".")
		return null
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame
	return scene


func _free_scene(scene: Node) -> void:
	if scene == null:
		return
	scene.queue_free()
	current_scene = null
	await process_frame


func _texture_report(river: Node, bake_data: Resource) -> Dictionary:
	var hashes := {}
	var missing := PackedStringArray()
	var unreadable := PackedStringArray()
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var river_texture := river.get(texture_name) as Texture2D
		var bake_texture := bake_data.get(texture_name) as Texture2D if bake_data != null else null
		var hash := _hash_texture(river_texture)
		hashes[texture_name] = hash
		if river_texture == null or bake_texture == null:
			missing.append(texture_name)
		elif String(hash.get("md5", "")) == "unreadable":
			unreadable.append(texture_name)
	var ok := missing.is_empty() and unreadable.is_empty()
	return {
		"ok": ok,
		"missing_textures": missing,
		"unreadable_textures": unreadable,
		"hashes": hashes,
	}


func _binding_report(river: Node, bake_data: Resource) -> Dictionary:
	var river_mismatches := PackedStringArray()
	var visible_mismatches := PackedStringArray()
	var debug_mismatches := PackedStringArray()
	var debug_material := river.get("_debug_material") as ShaderMaterial
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var bake_texture := bake_data.get(texture_name) if bake_data != null else null
		if river.get(texture_name) != bake_texture:
			river_mismatches.append(texture_name)
		var shader_param := _shader_param_name(texture_name)
		if not shader_param.is_empty():
			if river.call("get_shader_param", shader_param) != bake_texture:
				visible_mismatches.append(shader_param)
			if debug_material == null or debug_material.get_shader_parameter(shader_param) != bake_texture:
				debug_mismatches.append(shader_param)
	var visible_valid = river.call("get_shader_param", "i_valid_flowmap")
	var debug_valid = debug_material.get_shader_parameter("i_valid_flowmap") if debug_material != null else null
	var visible_projected = river.call("get_shader_param", "i_flow_projected")
	var debug_projected = debug_material.get_shader_parameter("i_flow_projected") if debug_material != null else null
	var ok := (
		river_mismatches.is_empty()
		and visible_mismatches.is_empty()
		and debug_mismatches.is_empty()
		and bool(visible_valid)
		and bool(debug_valid)
		and bool(visible_projected)
		and bool(debug_projected)
	)
	return {
		"ok": ok,
		"river_texture_mismatches": river_mismatches,
		"visible_material_mismatches": visible_mismatches,
		"debug_material_mismatches": debug_mismatches,
		"debug_material_present": debug_material != null,
		"visible_i_valid_flowmap": visible_valid,
		"debug_i_valid_flowmap": debug_valid,
		"visible_i_flow_projected": visible_projected,
		"debug_i_flow_projected": debug_projected,
	}


func _debug_view_report(river: Node) -> Dictionary:
	var failures := PackedStringArray()
	var applied := PackedInt32Array()
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	for view_id in DEBUG_VIEW_IDS:
		river.call("set_debug_view", view_id)
		await process_frame
		await process_frame
		applied.append(view_id)
		if view_id == 0:
			if mesh_instance != null and mesh_instance.material_override != null:
				failures.append("normal_view_material_override_not_cleared")
		else:
			if mesh_instance == null or mesh_instance.material_override == null:
				failures.append("debug_view_" + str(view_id) + "_material_missing")
	river.call("set_debug_view", 0)
	await process_frame
	return {
		"ok": failures.is_empty(),
		"applied_debug_view_ids": applied,
		"failures": failures,
	}


func _runtime_concerns(river: Node, bake_data: Resource, texture_report: Dictionary, binding_report: Dictionary, debug_report: Dictionary) -> PackedStringArray:
	var concerns := PackedStringArray()
	if bake_data == null:
		concerns.append("bake_data_missing")
	if not bool(river.get("valid_flowmap")):
		concerns.append("valid_flowmap_false")
	if not bool(texture_report.get("ok", false)):
		concerns.append("texture_availability_failed")
	if not bool(binding_report.get("ok", false)):
		concerns.append("material_binding_failed")
	if not bool(debug_report.get("ok", false)):
		concerns.append("debug_view_switch_failed")
	return concerns


func _make_summary(reports: Array, passed: PackedStringArray, failed: PackedStringArray) -> Dictionary:
	var ok := failed.is_empty() and passed.size() == SMOKE_CASES.size()
	return {
		"ok": ok,
		"case_count": reports.size(),
		"passed_labels": passed,
		"failed_labels": failed,
		"default_backend_mode": RiverFlowmapBaker.get_default_flowmap_backend_mode(),
		"rebake_invoked": false,
		"resource_saver_invoked": false,
		"saved_resources_loaded_cleanly": ok,
		"legacy_canvas_item_available": true,
		"switch_to_compute_solve_decision": "may_be_considered_after_recording; not_performed_by_this_probe",
		"legacy_removal_decision": "not_approved",
	}


func _verify_summary(summary: Dictionary) -> void:
	_expect(bool(summary.get("ok", false)), "Saved-resource load smoke failed: " + str(summary))
	_expect(String(summary.get("default_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "Default backend should remain canonical compute.")
	_expect(not bool(summary.get("rebake_invoked", true)), "Load smoke must not rebake.")
	_expect(not bool(summary.get("resource_saver_invoked", true)), "Load smoke must not save resources.")
	_expect(bool(summary.get("legacy_canvas_item_available", false)), "Load smoke lost explicit legacy availability.")
	_expect(String(summary.get("legacy_removal_decision", "")) == "not_approved", "Load smoke must not approve legacy removal.")


func _replacement_summary(replacement_result: Dictionary) -> Dictionary:
	return {
		"ok": bool(replacement_result.get("ok", false)),
		"mode": String(replacement_result.get("mode", "")),
		"selected_readback_path": String(replacement_result.get("selected_readback_path", "")),
		"sync_wait_frames": int(replacement_result.get("sync_wait_frames", -1)),
		"submit_count": int(replacement_result.get("submit_count", -1)),
		"sync_count": int(replacement_result.get("sync_count", -1)),
		"dispatch_count": int(replacement_result.get("dispatch_count", -1)),
		"compute_barrier_count": int(replacement_result.get("compute_barrier_count", -1)),
		"async_readback_selected": bool(replacement_result.get("async_readback_selected", true)),
		"production_output_replaced": bool(replacement_result.get("production_output_replaced", false)),
		"output_texture_keys": replacement_result.get("output_texture_keys", []),
	}


func _shader_param_name(texture_name: String) -> String:
	match texture_name:
		"flow_foam_noise":
			return "i_flowmap"
		"dist_pressure":
			return "i_distmap"
		"obstacle_features":
			return "i_obstacle_features"
		"terrain_contact_features":
			return "i_terrain_contact_features"
		"bank_response_features":
			return "i_bank_response_features"
		"water_occupancy":
			return "i_water_occupancy"
	return ""


func _resource_dictionary(resource: Resource, property_name: String) -> Dictionary:
	if resource == null:
		return {}
	return _dictionary_from_variant(resource.get(property_name))


func _hash_texture(texture: Texture2D) -> Dictionary:
	var entry := {
		"present": false,
		"size": Vector2i.ZERO,
		"format": -1,
		"md5": "absent",
	}
	if texture == null:
		return entry
	var image := texture.get_image()
	if image == null or image.is_empty():
		entry.md5 = "unreadable"
		return entry
	entry.present = true
	entry.size = image.get_size()
	entry.format = image.get_format()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	entry.md5 = context.finish().hex_encode()
	return entry


func _file_md5(resource_path: String) -> String:
	if resource_path.is_empty():
		return "missing_path"
	var bytes := FileAccess.get_file_as_bytes(resource_path)
	if bytes.is_empty() and not FileAccess.file_exists(resource_path):
		return "missing"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(bytes)
	return context.finish().hex_encode()


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _array_has_string(values: Variant, target: String) -> bool:
	if typeof(values) != TYPE_ARRAY and typeof(values) != TYPE_PACKED_STRING_ARRAY:
		return false
	for value in values:
		if String(value) == target:
			return true
	return false


func _output_key_count(values: Variant) -> int:
	if typeof(values) == TYPE_ARRAY or typeof(values) == TYPE_PACKED_STRING_ARRAY:
		return values.size()
	return 0


func _append_result(prefix: String, result: Dictionary) -> void:
	var keys := result.keys()
	keys.sort()
	for key in keys:
		var value = result[key]
		if value is Texture2D or value is Image:
			continue
		_report_lines.append(prefix + "." + str(key) + "=" + str(value))


func _write_report(file_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_errors.append("Could not create output parent " + parent + ": " + error_string(dir_error))
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write " + absolute_path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string("\n".join(_report_lines) + "\n")
	file.close()


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_SAVED_RESOURCE_LOAD_SMOKE_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
