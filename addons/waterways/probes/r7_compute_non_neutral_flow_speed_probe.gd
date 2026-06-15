# River-refactor R7 compute non-neutral flow-speed bake probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_non_neutral_flow_speed_probe.gd -- out=res://.codex-research/r7-baselines/compute-non-neutral-flow-speed
#
# Success marker: R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

const DEFAULT_SCENE := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-non-neutral-flow-speed"
const REPORT_FILE_NAME := "r7_compute_non_neutral_flow_speed.txt"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 3000
const MAX_ALLOWED_FRAME_GAP_MS := 1000.0

const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]


class R7ComputeFlowSpeedBaker:
	extends RiverFlowmapBaker

	var trace_owner: Object = null
	var backend_mode := RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	var gate_config := {}
	var last_filter_result := {}
	var injected_filter_config := {}
	var pass_counts := {}
	var pass_trace := []

	func run_filter_pass_sequence(config: Dictionary, progress: Callable = Callable(), cancellation: Callable = Callable()) -> Dictionary:
		var injected_config := config.duplicate(true)
		for key in gate_config.keys():
			injected_config[key] = gate_config[key]
		injected_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = backend_mode
		injected_config["sync_wait_frames"] = int(injected_config.get("sync_wait_frames", 3))
		if trace_owner != null:
			injected_config["frame_wait_source"] = trace_owner
			if trace_owner.has_method("_record_warning"):
				injected_config["warning_callback"] = Callable(trace_owner, "_record_warning")
		injected_filter_config = injected_config.duplicate(true)
		var result: Dictionary = await super.run_filter_pass_sequence(injected_config, progress, cancellation)
		last_filter_result = result.duplicate(true)
		return result

	func _run_pass(label: String, pass_callable: Callable) -> Dictionary:
		var start_usec := Time.get_ticks_usec()
		var result: Dictionary = await super._run_pass(label, pass_callable)
		var end_usec := Time.get_ticks_usec()
		pass_counts[label] = int(pass_counts.get(label, 0)) + 1
		pass_trace.append({
			"label": label,
			"duration_ms": float(end_usec - start_usec) / 1000.0,
			"ok": bool(result.get("ok", false)),
			"reason": String(result.get("reason", "")),
		})
		return result


var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _report_lines := PackedStringArray()
var _written_report := ""
var _active_progress_events: Array = []
var _active_run_start_usec := 0
var _active_finished_usec := 0


func _initialize() -> void:
	Engine.time_scale = 1.0
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))

	_report_lines.append("R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_DUMP v1")
	_report_lines.append("scene=" + scene_path)
	_report_lines.append("river=" + river_path)
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())
	_report_lines.append("default_backend_mode=" + RiverFlowmapBaker.get_default_flowmap_backend_mode())
	_report_lines.append("requested_backend_mode=" + RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING)
	_report_lines.append("save_output=false")

	var neutral_run := await _run_compute_bake(scene_path, river_path, "compute_neutral", false)
	var non_neutral_run := await _run_compute_bake(scene_path, river_path, "compute_non_neutral", true)
	var comparison := _compare_runs(neutral_run, non_neutral_run)

	_append_result("compute_neutral", neutral_run)
	_append_result("compute_non_neutral", non_neutral_run)
	_append_result("non_neutral_comparison", comparison)
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("errors=" + str(_errors))

	_verify_run(neutral_run, false)
	_verify_run(non_neutral_run, true)
	_verify_comparison(comparison)

	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _run_compute_bake(scene_path: String, river_path: String, label: String, non_neutral_flow: bool) -> Dictionary:
	var fixture := await _load_fixture(scene_path)
	var river := fixture.get_node_or_null(river_path) if fixture != null else null
	var result := {
		"ok": false,
		"reason": "not_run",
		"label": label,
		"non_neutral_flow": non_neutral_flow,
	}
	if river == null:
		result.reason = "river_not_found"
		_errors.append(label + ": river not found at " + river_path + ".")
		_free_fixture(fixture)
		return result

	_configure_low_cost_river(river, non_neutral_flow)
	_active_progress_events = []
	_active_finished_usec = 0
	_active_run_start_usec = Time.get_ticks_usec()
	var frame_gaps := []
	var previous_frame_usec := _active_run_start_usec
	var progress_callable := Callable(self, "_on_progress_notified")
	if not river.progress_notified.is_connected(progress_callable):
		river.progress_notified.connect(progress_callable)

	var baker := R7ComputeFlowSpeedBaker.new()
	baker.trace_owner = self
	baker.gate_config = _make_production_gate_config()
	RiverManager._flowmap_bakers[river.get_instance_id()] = baker
	river.call("bake_texture")
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_gaps.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
		frame_count += 1
	if bool(river.call("is_bake_in_progress")):
		_errors.append(label + ": bake did not finish within " + str(MAX_BAKE_FRAMES) + " frames.")
		baker.abort()
		await process_frame
	if _active_finished_usec <= 0:
		_active_finished_usec = Time.get_ticks_usec()
	if river.progress_notified.is_connected(progress_callable):
		river.progress_notified.disconnect(progress_callable)
	RiverManager._flowmap_bakers.erase(river.get_instance_id())

	var bake_data := river.get("bake_data") as Resource
	var metadata := _resource_dictionary(bake_data, "source_metadata")
	var selection := _dictionary_from_variant(baker.last_filter_result.get("flowmap_backend_selection", metadata.get("flowmap_backend_selection", {})))
	var replacement_result := _dictionary_from_variant(baker.last_filter_result.get("canonical_compute_replacement_result", metadata.get("canonical_compute_replacement_result", {})))
	var output_keys = baker.last_filter_result.get("output_texture_keys", metadata.get("output_texture_keys", PackedStringArray()))
	var selected_mode := String(baker.last_filter_result.get("flowmap_backend_mode", metadata.get("flowmap_backend_mode", selection.get("selected_mode", ""))))
	var fallback_applied := bool(selection.get("fallback_applied", selected_mode != RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING))
	var texture_hashes := _river_texture_hashes(river)
	var texture_images := texture_hashes.get("_images", {})
	texture_hashes.erase("_images")
	var completed := bake_data != null and not bool(river.call("is_bake_in_progress"))
	var pass_counts := baker.pass_counts.duplicate(true)
	var expected_speed_passes := 1 if non_neutral_flow else 0
	result.ok = (
		completed
		and selected_mode == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
		and not fallback_applied
		and bool(baker.last_filter_result.get("production_output_replaced", metadata.get("production_output_replaced", false)))
		and _array_has_string(output_keys, "flow_foam_noise")
		and _output_key_count(output_keys) == 1
		and int(pass_counts.get("flow speed scale map", 0)) == expected_speed_passes
		and bool(metadata.get("flow_speed_scaled", false)) == non_neutral_flow
	)
	result.reason = "ok" if bool(result.ok) else "compute_non_neutral_invariants_failed"
	result.elapsed_ms = float(_active_finished_usec - _active_run_start_usec) / 1000.0
	result.frame_count = frame_count
	result.max_frame_gap_ms = _max_float(frame_gaps)
	result.p95_frame_gap_ms = _percentile(frame_gaps, 0.95)
	result.progress_events = _active_progress_events.duplicate(true)
	result.pass_counts = pass_counts
	result.pass_trace = baker.pass_trace.duplicate(true)
	result.requested_backend_mode = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	result.selected_backend_mode = selected_mode
	result.fallback_applied = fallback_applied
	result.fallback_reason = String(selection.get("fallback_reason", ""))
	result.flowmap_backend_selection = selection
	result.production_output_replaced = bool(baker.last_filter_result.get("production_output_replaced", metadata.get("production_output_replaced", false)))
	result.output_texture_keys = output_keys
	result.output_texture_key_count = _output_key_count(output_keys)
	result.replacement_summary = _replacement_summary(replacement_result)
	result.source_signature_version = int(bake_data.get("source_signature_version")) if bake_data != null else -1
	result.metadata = metadata
	result.source_signature = _resource_dictionary(bake_data, "source_signature")
	result.texture_hashes = texture_hashes
	result["_images"] = texture_images
	result.resource_path = bake_data.resource_path if bake_data != null else ""
	result.material_binding = _material_binding_report(river, bake_data)
	result.warnings_seen = _warnings.size()
	result.console_error_count = _errors.size()

	_free_fixture(fixture)
	return result


func _configure_low_cost_river(river: Node, non_neutral_flow: bool) -> void:
	river.set("baking_resolution", 0)
	river.set("baking_raycast_layers", 1)
	river.set("shape_step_length_divs", 1)
	river.set("shape_step_width_divs", 1)
	river.set("bake_generation_behavior", TARGET_GENERATION_BEHAVIOR)
	var curve = river.get("curve")
	var point_count := 0
	if curve != null and curve.has_method("get_point_count"):
		point_count = int(curve.call("get_point_count"))
	var speeds := []
	var non_neutral_values := [0.65, 1.35, 0.85, 1.75]
	for point_index in maxi(1, point_count):
		speeds.append(non_neutral_values[point_index % non_neutral_values.size()] if non_neutral_flow else 1.0)
	if river.has_method("set_flow_speeds"):
		river.call("set_flow_speeds", speeds)
	else:
		river.set("flow_speeds", speeds)


func _compare_runs(neutral_run: Dictionary, non_neutral_run: Dictionary) -> Dictionary:
	var neutral_hashes := _dictionary_from_variant(neutral_run.get("texture_hashes", {}))
	var non_neutral_hashes := _dictionary_from_variant(non_neutral_run.get("texture_hashes", {}))
	var changed_keys := PackedStringArray()
	var unchanged_keys := PackedStringArray()
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var neutral_md5 := _hash_entry_md5(_dictionary_from_variant(neutral_hashes.get(texture_name, {})))
		var non_neutral_md5 := _hash_entry_md5(_dictionary_from_variant(non_neutral_hashes.get(texture_name, {})))
		if neutral_md5 == non_neutral_md5:
			unchanged_keys.append(texture_name)
		else:
			changed_keys.append(texture_name)
	var channel_scope := _flow_foam_noise_channel_scope(neutral_run, non_neutral_run)
	var ok := (
		bool(neutral_run.get("ok", false))
		and bool(non_neutral_run.get("ok", false))
		and _array_has_string(changed_keys, "flow_foam_noise")
		and changed_keys.size() == 1
		and bool(channel_scope.get("ok", false))
	)
	return {
		"ok": ok,
		"reason": "ok" if ok else "non_neutral_compute_flow_speed_did_not_have_expected_texture_impact",
		"changed_texture_keys": changed_keys,
		"unchanged_texture_keys": unchanged_keys,
		"flow_foam_noise_channel_scope": channel_scope,
		"neutral_flow_foam_noise_md5": _hash_entry_md5(_dictionary_from_variant(neutral_hashes.get("flow_foam_noise", {}))),
		"non_neutral_flow_foam_noise_md5": _hash_entry_md5(_dictionary_from_variant(non_neutral_hashes.get("flow_foam_noise", {}))),
	}


func _flow_foam_noise_channel_scope(neutral_run: Dictionary, non_neutral_run: Dictionary) -> Dictionary:
	var neutral_image := _texture_image_from_run(neutral_run, "flow_foam_noise")
	var non_neutral_image := _texture_image_from_run(non_neutral_run, "flow_foam_noise")
	if neutral_image == null or non_neutral_image == null:
		return {"ok": false, "reason": "flow_foam_noise_image_missing"}
	if neutral_image.get_size() != non_neutral_image.get_size() or neutral_image.get_format() != non_neutral_image.get_format():
		return {
			"ok": false,
			"reason": "flow_foam_noise_layout_changed",
			"neutral_size": neutral_image.get_size(),
			"non_neutral_size": non_neutral_image.get_size(),
			"neutral_format": neutral_image.get_format(),
			"non_neutral_format": non_neutral_image.get_format(),
		}
	var deltas := _channel_delta_report(neutral_image, non_neutral_image)
	var r_changed := int(deltas.get("r_differing_pixels", 0)) > 0
	var g_changed := int(deltas.get("g_differing_pixels", 0)) > 0
	var b_same := is_zero_approx(float(deltas.get("b_max_delta", 1.0)))
	var a_same := is_zero_approx(float(deltas.get("a_max_delta", 1.0)))
	return {
		"ok": r_changed and g_changed and b_same and a_same,
		"reason": "ok" if r_changed and g_changed and b_same and a_same else "unexpected_channel_scope",
		"r_changed": r_changed,
		"g_changed": g_changed,
		"b_legacy_identical": b_same,
		"a_legacy_identical": a_same,
		"channel_deltas": deltas,
		"expected_impact": "flow_foam_noise.rg changed by flow_speed_scale; foam/noise channels unchanged",
	}


func _texture_image_from_run(run: Dictionary, texture_name: String) -> Image:
	var value = run.get("_images", {})
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var images: Dictionary = value
	return images.get(texture_name, null) as Image


func _channel_delta_report(before_image: Image, after_image: Image) -> Dictionary:
	var names := ["r", "g", "b", "a"]
	var max_delta := [0.0, 0.0, 0.0, 0.0]
	var differing_pixels := [0, 0, 0, 0]
	for y in before_image.get_height():
		for x in before_image.get_width():
			var before_color := before_image.get_pixel(x, y)
			var after_color := after_image.get_pixel(x, y)
			var deltas := [
				absf(before_color.r - after_color.r),
				absf(before_color.g - after_color.g),
				absf(before_color.b - after_color.b),
				absf(before_color.a - after_color.a),
			]
			for channel_index in 4:
				var delta := float(deltas[channel_index])
				if delta > 0.0:
					differing_pixels[channel_index] = int(differing_pixels[channel_index]) + 1
					max_delta[channel_index] = maxf(float(max_delta[channel_index]), delta)
	var report := {}
	for channel_index in names.size():
		report[names[channel_index] + "_max_delta"] = float(max_delta[channel_index])
		report[names[channel_index] + "_differing_pixels"] = int(differing_pixels[channel_index])
	return report


func _load_fixture(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene " + scene_path + ".")
		return null
	var fixture := packed.instantiate()
	if fixture == null:
		_errors.append("Could not instantiate scene " + scene_path + ".")
		return null
	fixture.scene_file_path = scene_path
	root.add_child(fixture)
	current_scene = fixture
	await process_frame
	await physics_frame
	await physics_frame
	return fixture


func _free_fixture(fixture: Node) -> void:
	if fixture == null:
		return
	fixture.queue_free()
	current_scene = null
	await process_frame


func _on_progress_notified(percentage: float, label: String) -> void:
	var now_usec := Time.get_ticks_usec()
	_active_progress_events.append({
		"elapsed_ms": float(now_usec - _active_run_start_usec) / 1000.0,
		"progress": percentage,
		"label": label,
	})
	if String(label) == "finished":
		_active_finished_usec = now_usec


func _record_warning(message: String) -> void:
	_warnings.append(message)


func _make_production_gate_config() -> Dictionary:
	return {
		"automated_canonical_acceptance_ok": true,
		"representative_visuals_ok": true,
		"selection_abort_ok": true,
		"cleanup_responsiveness_ok": true,
		"river_manager_surface_ok": true,
		"generated_output_replacement_staging_ok": true,
		"production_replacement_validation_ok": true,
		"source_signature_version": 29,
		"source_signature_includes_backend_mode": false,
	}


func _verify_run(run: Dictionary, non_neutral_flow: bool) -> void:
	var label := String(run.get("label", "run"))
	_expect(bool(run.get("ok", false)), label + " failed invariants: " + str(run))
	_expect(String(run.get("selected_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, label + " did not select compute.")
	_expect(not bool(run.get("fallback_applied", true)), label + " unexpectedly fell back.")
	_expect(bool(run.get("production_output_replaced", false)), label + " did not report production replacement.")
	_expect(_array_has_string(run.get("output_texture_keys", []), "flow_foam_noise"), label + " did not report flow_foam_noise output.")
	_expect(_output_key_count(run.get("output_texture_keys", [])) == 1, label + " should report exactly one output texture key.")
	_expect(int(run.get("source_signature_version", -1)) == 29, label + " should use source signature v29.")
	_expect(String(run.get("resource_path", "")) == "", label + " should not save or reuse an external resource path.")
	_expect(float(run.get("max_frame_gap_ms", 0.0)) <= MAX_ALLOWED_FRAME_GAP_MS, label + " exceeded the low-cost frame-gap hard stop.")
	var pass_counts := _dictionary_from_variant(run.get("pass_counts", {}))
	_expect(int(pass_counts.get("flow speed scale map", 0)) == (1 if non_neutral_flow else 0), label + " flow-speed pass count changed.")
	var metadata := _dictionary_from_variant(run.get("metadata", {}))
	_expect(bool(metadata.get("flow_speed_scaled", false)) == non_neutral_flow, label + " metadata.flow_speed_scaled mismatch.")
	var replacement := _dictionary_from_variant(run.get("replacement_summary", {}))
	_expect(bool(replacement.get("ok", false)), label + " replacement summary was not ok.")
	_expect(not bool(replacement.get("async_readback_selected", true)), label + " selected async readback.")
	_expect(String(replacement.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, label + " did not keep the delayed sync texture readback path.")
	var material := _dictionary_from_variant(run.get("material_binding", {}))
	_expect(bool(material.get("ok", false)), label + " material binding did not match generated bake textures.")


func _verify_comparison(comparison: Dictionary) -> void:
	_expect(bool(comparison.get("ok", false)), "Non-neutral flow-speed comparison failed: " + str(comparison))
	_expect(_array_has_string(comparison.get("changed_texture_keys", []), "flow_foam_noise"), "Non-neutral flow-speed run did not change flow_foam_noise.")
	_expect(_output_key_count(comparison.get("changed_texture_keys", [])) == 1, "Non-neutral flow-speed changed unexpected generated textures.")


func _replacement_summary(replacement_result: Dictionary) -> Dictionary:
	return {
		"ok": bool(replacement_result.get("ok", false)),
		"reason": String(replacement_result.get("reason", "")),
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


func _material_binding_report(river: Node, bake_data: Resource) -> Dictionary:
	var result := {
		"ok": false,
		"valid_flowmap": false,
		"all_river_textures_match_bake": false,
		"all_visible_material_textures_match_bake": false,
	}
	if river == null or bake_data == null:
		result.reason = "missing_river_or_bake"
		return result
	result.valid_flowmap = bool(river.get("valid_flowmap"))
	var river_match := true
	var visible_match := true
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var bake_texture := bake_data.get(texture_name)
		if river.get(texture_name) != bake_texture:
			river_match = false
		var shader_param := _shader_param_name(texture_name)
		if not shader_param.is_empty() and river.call("get_shader_param", shader_param) != bake_texture:
			visible_match = false
	result.all_river_textures_match_bake = river_match
	result.all_visible_material_textures_match_bake = visible_match
	result.ok = bool(result.valid_flowmap) and river_match and visible_match
	return result


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


func _river_texture_hashes(river: Node) -> Dictionary:
	var hashes := {}
	var images := {}
	if river == null:
		return hashes
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var texture := river.get(texture_name) as Texture2D
		hashes[texture_name] = _hash_texture(texture)
		images[texture_name] = texture.get_image() if texture != null else null
	hashes["_images"] = images
	return hashes


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
	entry.md5 = _hash_image(image)
	return entry


func _hash_image(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	return context.finish().hex_encode()


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _hash_entry_md5(entry: Dictionary) -> String:
	return String(entry.get("md5", ""))


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
		if String(key) == "_images":
			continue
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


func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * ratio)) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


func _max_float(values: Array) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_NON_NEUTRAL_FLOW_SPEED_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
