# River-refactor R7 generated-output replacement staging probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_generated_output_replacement_staging_probe.gd -- out=res://.codex-research/r7-baselines/compute-generated-output-replacement-staging
#
# Success marker: R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK
extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

const DEFAULT_SCENE := "res://addons/waterways/probes/r7_low_cost_bake_fixture.tscn"
const DEFAULT_RIVER_PATH := "Water River"
const DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-generated-output-replacement-staging"
const REPORT_FILE_NAME := "r7_compute_generated_output_replacement_staging.txt"
const FILTER_RENDERER_SCENE := "res://addons/waterways/filter_renderer.tscn"
const TARGET_GENERATION_BEHAVIOR := "downstream_baseline_collision_support"
const MAX_BAKE_FRAMES := 2400
const DEFAULT_STRIDE_SCHEDULE := [32, 16, 8, 4, 2, 1, 1, 1]
const EXPECTED_STAGING_MARKER := "R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK"

const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]


class R7CaptureBaker:
	extends RiverFlowmapBaker

	var trace_owner: Object = null

	func run_filter_pass_sequence(config: Dictionary, progress: Callable = Callable(), cancellation: Callable = Callable()) -> Dictionary:
		if trace_owner != null and trace_owner.has_method("_record_filter_pass_config"):
			trace_owner.call("_record_filter_pass_config", config)
		return await super.run_filter_pass_sequence(config, progress, cancellation)

	func _run_renderer_pass(label: String, renderer_instance: Object, method_name: String, args: Array) -> Dictionary:
		if trace_owner != null and trace_owner.has_method("_record_legacy_pass_inputs"):
			trace_owner.call("_record_legacy_pass_inputs", label, args)
		var result: Dictionary = await super._run_renderer_pass(label, renderer_instance, method_name, args)
		if trace_owner != null and trace_owner.has_method("_record_legacy_pass_output"):
			trace_owner.call("_record_legacy_pass_output", label, result)
		return result


var _errors := PackedStringArray()
var _warnings := PackedStringArray()
var _progress := PackedStringArray()
var _report_lines := PackedStringArray()
var _legacy_projection_capture := {}
var _written_report := ""


func _initialize() -> void:
	Engine.time_scale = 0.0
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var texture_width := maxi(4, int(args.get("texture_width", "106")))
	var texture_height := maxi(4, int(args.get("texture_height", "106")))
	var source_size := maxf(1.0, float(args.get("source_size", "64.0")))
	var atlas_columns := maxi(1, int(args.get("atlas_columns", "5")))
	var iterations_per_stride := maxi(1, int(args.get("iterations_per_stride", "5")))
	var stride_schedule := _parse_int_list(String(args.get("strides", "")), DEFAULT_STRIDE_SCHEDULE)

	_report_lines.append("R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_DUMP v1")
	_report_lines.append("scene=" + scene_path)
	_report_lines.append("river=" + river_path)
	_report_lines.append("godot_version=" + str(Engine.get_version_info()))
	_report_lines.append("rendering_method=" + RenderingServer.get_current_rendering_method())
	_report_lines.append("rendering_driver=" + RenderingServer.get_current_rendering_driver_name())
	_report_lines.append("adapter_name=" + RenderingServer.get_video_adapter_name())
	_report_lines.append("adapter_type=" + str(RenderingServer.get_video_adapter_type()))
	_report_lines.append("adapter_vendor=" + RenderingServer.get_video_adapter_vendor())

	var fixture := _load_fixture(scene_path)
	var river := fixture.get_node_or_null(river_path) if fixture != null else null
	_expect(river != null, "R7 staging fixture river was not found at " + river_path + ".")
	if river != null:
		_configure_fixture_river(river)
		var legacy_ok := await _run_legacy_bake(river)
		_expect(legacy_ok, "Legacy fixture bake did not complete before replacement staging.")

	var before_state := _river_output_state(river)
	var before_hashes := _river_texture_hashes(river)
	_report_lines.append("legacy_before_state=" + str(before_state))
	_report_lines.append("legacy_before_hashes=" + str(before_hashes))

	var compute_config := {
		"frame_wait_source": self,
		"warning_callback": Callable(self, "_record_warning"),
		"texture_width": texture_width,
		"texture_height": texture_height,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"flow_projection_strides": stride_schedule.duplicate(),
		"flow_projection_iterations_per_stride": iterations_per_stride,
		"sync_wait_frames": 3
	}
	var projection_config := _make_projection_compute_config(compute_config)
	var baker := RiverFlowmapBaker.new()
	var projection_result: Dictionary = await baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_config,
		Callable(self, "_record_progress")
	)
	baker.cleanup()
	baker.abort()
	baker.cleanup()

	var candidate_result := await _make_canonical_candidate_texture(projection_result, river)
	var after_state := _river_output_state(river)
	var after_hashes := _river_texture_hashes(river)
	var candidate_hashes := before_hashes.duplicate(true)
	if bool(candidate_result.get("ok", false)):
		candidate_hashes["flow_foam_noise"] = {
			"present": true,
			"size": candidate_result.get("candidate_size", Vector2i.ZERO),
			"format": int(candidate_result.get("candidate_format", -1)),
			"md5": String(candidate_result.get("candidate_md5", ""))
		}
	var staging_report := RiverFlowmapBaker.build_canonical_compute_generated_output_replacement_staging_report({
		"legacy_before_state": before_state,
		"legacy_after_state": after_state,
		"legacy_before_hashes": before_hashes,
		"legacy_after_hashes": after_hashes,
		"candidate_hashes": candidate_hashes,
		"canonical_candidate_source": String(candidate_result.get("candidate_source", "")),
		"river_manager_ownership_preserved": before_state == after_state and before_hashes == after_hashes,
		"river_manager_public_surface_preserved": true
	})
	var staged_gate_config := _make_staged_gate_config(bool(staging_report.get("ok", false)))
	var staged_gate := RiverFlowmapBaker.evaluate_canonical_compute_replacement_gate(staged_gate_config)
	var replacing_config := staged_gate_config.duplicate(true)
	replacing_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	var replacing_selection := RiverFlowmapBaker.new().select_flowmap_backend(replacing_config)

	var output_preservation := {
		"ok": before_state == after_state and before_hashes == after_hashes,
		"river_state_unchanged": before_state == after_state,
		"river_texture_hashes_unchanged": before_hashes == after_hashes,
		"production_output_replaced": false,
		"output_texture_keys": [],
		"source_signature_version": 29,
		"signature_version_while_compute_non_replacing": 29,
	}

	_append_result("projection_compute", projection_result)
	_append_result("canonical_candidate", candidate_result)
	_append_result("replacement_staging", staging_report)
	_append_result("replacement_staging_gate", staged_gate)
	_append_result("canonical_compute_replacing_after_staging", replacing_selection)
	_append_result("output_preservation", output_preservation)
	_report_lines.append("legacy_after_state=" + str(after_state))
	_report_lines.append("legacy_after_hashes=" + str(after_hashes))
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("progress=" + str(_progress))

	_verify_projection_result(projection_result)
	_verify_candidate_result(candidate_result)
	_verify_staging_report(staging_report)
	_verify_staged_gate(staged_gate, replacing_selection)
	_expect(bool(output_preservation.get("ok", false)), "Replacement staging changed RiverManager output state or hashes.")

	if fixture != null:
		fixture.queue_free()
		current_scene = null
	_written_report = out_dir.path_join(REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _make_staged_gate_config(staging_ok: bool) -> Dictionary:
	return {
		"automated_canonical_acceptance_ok": true,
		"representative_visuals_ok": true,
		"selection_abort_ok": true,
		"cleanup_responsiveness_ok": true,
		"river_manager_surface_ok": true,
		"generated_output_replacement_staging_ok": staging_ok,
		"production_replacement_validation_ok": false,
		"source_signature_version": 29,
		"source_signature_includes_backend_mode": false,
	}


func _make_projection_compute_config(base_config: Dictionary) -> Dictionary:
	var config := base_config.duplicate(true)
	var flow_texture := _legacy_projection_capture.get("flow_input_texture", null) as Texture2D
	var occupancy_texture := _legacy_projection_capture.get("occupancy_input_texture", null) as Texture2D
	config["flow_image"] = _texture_to_image(flow_texture)
	config["occupancy_image"] = _texture_to_image(occupancy_texture)
	config["source_size"] = float(_legacy_projection_capture.get("source_size", base_config.get("source_size", 1.0)))
	config["atlas_columns"] = maxi(1, int(round(float(_legacy_projection_capture.get("atlas_columns", base_config.get("atlas_columns", 1))))))
	config["flow_tangency_passes"] = int(_legacy_projection_capture.get("tangency_pass_count", 2))
	config["sync_wait_frames"] = 3
	return config


func _make_canonical_candidate_texture(projection_result: Dictionary, river: Node) -> Dictionary:
	var result := {
		"ok": false,
		"mode": "canonical_compute_candidate_generated_output_staging",
		"candidate_texture": null,
		"candidate_image": null,
		"production_output_replaced": false,
		"output_texture_keys": [],
		"migrated_channels": "flow_foam_noise.rg",
		"legacy_foam_noise_channels_preserved": true,
	}
	if not bool(projection_result.get("ok", false)):
		result.reason = "projection_compute_failed"
		return result
	var compute_flow := projection_result.get("_debug_final_flow_image", null) as Image
	var compute_flow_texture := ImageTexture.create_from_image(compute_flow) if compute_flow != null else null
	var foam_texture := _legacy_projection_capture.get("flow_foam_noise_b_texture", null) as Texture2D
	var noise_texture := _legacy_projection_capture.get("flow_foam_noise_a_texture", null) as Texture2D
	var bake_data: Resource = null
	if river != null:
		bake_data = river.get("bake_data") as Resource
	if compute_flow_texture == null or foam_texture == null or noise_texture == null or bake_data == null:
		result.reason = "candidate_inputs_missing"
		return result
	var renderer := _make_renderer()
	if renderer == null:
		result.reason = "candidate_renderer_missing"
		return result
	var candidate_texture: Texture2D = await renderer.apply_combine(compute_flow_texture, compute_flow_texture, foam_texture, noise_texture)
	_remove_renderer(renderer)
	candidate_texture = _postprocess_candidate_flow_texture(candidate_texture, river, bake_data)
	var candidate_image := _texture_to_image(candidate_texture)
	if candidate_texture == null or candidate_image == null:
		result.reason = "candidate_postprocess_failed"
		return result
	result.ok = true
	result.reason = "ok"
	result.candidate_texture = candidate_texture
	result.candidate_image = candidate_image
	result.candidate_size = candidate_image.get_size()
	result.candidate_format = candidate_image.get_format()
	result.candidate_md5 = _hash_image(candidate_image)
	result.candidate_source = "canonical_compute_final_flow_plus_legacy_foam_noise_postprocess"
	return result


func _postprocess_candidate_flow_texture(flow_foam_noise_texture: Texture2D, river: Node, bake_data: Resource) -> Texture2D:
	if flow_foam_noise_texture == null or river == null or bake_data == null:
		return null
	var content_rect: Rect2i = bake_data.get("content_rect")
	var source_size: Vector2i = bake_data.get("source_texture_size")
	var flowmap_resolution := source_size.x if source_size.x > 0 else content_rect.size.x
	var source_metadata: Dictionary = bake_data.get("source_metadata")
	var terrain_contact_texture := river.get("terrain_contact_features") as Texture2D
	var terrain_contact_image := _texture_to_image(terrain_contact_texture)
	var baker := RiverFlowmapBaker.new()
	var postprocess_result: Dictionary = baker.process_filter_pass_images({
		"warning_callback": Callable(self, "_record_warning"),
		"flowmap_resolution": flowmap_resolution,
		"uv2_sides": maxi(1, int(bake_data.get("uv2_sides"))),
		"steps": _step_count_from_bake(bake_data),
		"margin": content_rect.position.x,
		"flow_foam_noise_texture": flow_foam_noise_texture,
		"dist_pressure_texture": river.get("dist_pressure") as Texture2D,
		"obstacle_features_texture": river.get("obstacle_features") as Texture2D,
		"terrain_contact_with_margins_image": terrain_contact_image,
		"bank_response_features_texture": river.get("bank_response_features") as Texture2D,
		"water_occupancy_texture": river.get("water_occupancy") as Texture2D,
		"generation_behavior": String(source_metadata.get("generation_behavior", TARGET_GENERATION_BEHAVIOR)),
		"uses_downstream_baseline_generation": bool(source_metadata.get("downstream_baseline_applied", true)),
		"support_fallback_applied": bool(source_metadata.get("support_fallback_applied", false)),
		"support_fallback_reason": String(source_metadata.get("support_fallback_reason", "")),
		"collision_probe_skipped": bool(source_metadata.get("collision_probe_skipped", false)),
		"collision_support_filters_ran": bool(source_metadata.get("collision_support_filters_ran", true)),
		"obstacle_avoidance_applied": true,
		"flow_projected": true,
		"water_occupancy_baked": true,
	})
	baker.cleanup()
	if not bool(postprocess_result.get("ok", false)):
		return null
	return postprocess_result.get("flow_foam_noise_texture") as Texture2D


func _step_count_from_bake(bake_data: Resource) -> int:
	if bake_data == null:
		return 1
	var source_signature: Dictionary = bake_data.get("source_signature")
	return maxi(1, int(source_signature.get("step_count", bake_data.get("uv2_sides"))))


func _make_renderer() -> Node:
	var renderer_scene := load(FILTER_RENDERER_SCENE) as PackedScene
	if renderer_scene == null:
		return null
	var renderer := renderer_scene.instantiate()
	if renderer == null:
		return null
	root.add_child(renderer)
	return renderer


func _remove_renderer(renderer: Node) -> void:
	if renderer == null:
		return
	if renderer.get_parent() != null:
		renderer.get_parent().remove_child(renderer)
	renderer.queue_free()


func _load_fixture(scene_path: String) -> Node:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_errors.append("Could not load fixture scene " + scene_path + ".")
		return null
	var fixture := scene.instantiate()
	if fixture == null:
		_errors.append("Could not instantiate fixture scene " + scene_path + ".")
		return null
	root.add_child(fixture)
	current_scene = fixture
	return fixture


func _configure_fixture_river(river: Node) -> void:
	river.set("baking_resolution", 0)
	river.set("baking_raycast_layers", 1)
	river.set("shape_step_length_divs", 1)
	river.set("shape_step_width_divs", 1)
	river.set("bake_generation_behavior", TARGET_GENERATION_BEHAVIOR)
	var curve = river.get("curve")
	var point_count := 0
	if curve != null and curve.has_method("get_point_count"):
		point_count = int(curve.call("get_point_count"))
	var neutral_speeds := []
	for _index in maxi(1, point_count):
		neutral_speeds.append(1.0)
	river.set("flow_speeds", neutral_speeds)


func _run_legacy_bake(river: Node) -> bool:
	if river == null:
		return false
	await process_frame
	await process_frame
	_legacy_projection_capture = {}
	var capture_baker := R7CaptureBaker.new()
	capture_baker.trace_owner = self
	RiverManager._flowmap_bakers[river.get_instance_id()] = capture_baker
	river.call("bake_texture")
	var frame_count := 0
	while bool(river.call("is_bake_in_progress")) and frame_count < MAX_BAKE_FRAMES:
		await process_frame
		frame_count += 1
	var bake_data := river.get("bake_data") as Resource
	_legacy_projection_capture["bake_data"] = bake_data
	RiverManager._flowmap_bakers.erase(river.get_instance_id())
	return not bool(river.call("is_bake_in_progress")) and bake_data != null


func _record_legacy_pass_inputs(label: String, args: Array) -> void:
	if label == "flow divergence map" and args.size() >= 4:
		_legacy_projection_capture["flow_input_texture"] = args[0]
		_legacy_projection_capture["occupancy_input_texture"] = args[1]
		_legacy_projection_capture["source_size"] = float(args[2])
		_legacy_projection_capture["atlas_columns"] = float(args[3])
	if label == "combined flow/foam/noise map" and args.size() >= 4:
		_legacy_projection_capture["flow_foam_noise_b_texture"] = args[2]
		_legacy_projection_capture["flow_foam_noise_a_texture"] = args[3]


func _record_legacy_pass_output(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	var texture := result.get("texture", null) as Texture2D
	if texture == null:
		return
	match label:
		"boundary tangency flow map":
			_legacy_projection_capture["tangency_pass_count"] = int(_legacy_projection_capture.get("tangency_pass_count", 0)) + 1
		"combined flow/foam/noise map":
			_legacy_projection_capture["legacy_flow_foam_noise_texture"] = texture


func _record_filter_pass_config(config: Dictionary) -> void:
	_legacy_projection_capture["filter_pass_config"] = config.duplicate(true)


func _river_output_state(river: Node) -> Dictionary:
	if river == null:
		return {}
	var bake_data = river.get("bake_data")
	var bake_path := ""
	var bake_data_id := 0
	if bake_data != null and bake_data is Resource:
		bake_path = (bake_data as Resource).resource_path
		bake_data_id = (bake_data as Resource).get_instance_id()
	return {
		"valid_flowmap": bool(river.get("valid_flowmap")),
		"bake_data_id": bake_data_id,
		"bake_data_path": bake_path,
		"flow_foam_noise_id": _object_id(river.get("flow_foam_noise")),
		"dist_pressure_id": _object_id(river.get("dist_pressure")),
		"obstacle_features_id": _object_id(river.get("obstacle_features")),
		"terrain_contact_features_id": _object_id(river.get("terrain_contact_features")),
		"bank_response_features_id": _object_id(river.get("bank_response_features")),
		"water_occupancy_id": _object_id(river.get("water_occupancy"))
	}


func _river_texture_hashes(river: Node) -> Dictionary:
	var hashes := {}
	if river == null:
		return hashes
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		hashes[texture_name] = _hash_texture(river.get(texture_name) as Texture2D)
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


func _texture_to_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


func _verify_projection_result(result: Dictionary) -> void:
	_expect(bool(result.get("ok", false)), "Canonical projection compute failed: " + str(result))
	_expect(String(result.get("mode", "")) == "non_replacing_solve_filter_projection", "Projection compute did not stay non-replacing.")
	_expect(String(result.get("pressure_feedback_target", "")) == "canonical_texel_space_compute", "Projection compute did not report canonical texel-space pressure feedback.")
	_expect(bool(result.get("canonical_integer_texel_addressing", false)), "Projection compute did not report canonical integer texel addressing.")
	_expect(not bool(result.get("production_output_replaced", true)), "Projection compute must not replace generated bake output.")
	_expect(_output_texture_key_count(result) == 0, "Projection compute returned output texture keys before replacement.")
	_expect(not bool(result.get("async_readback_selected", true)), "Projection compute selected async readback.")
	_expect(String(result.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, "Projection compute did not use delayed sync texture readback.")


func _verify_candidate_result(result: Dictionary) -> void:
	_expect(bool(result.get("ok", false)), "Canonical candidate texture could not be assembled: " + str(result))
	_expect(String(result.get("candidate_md5", "")).length() > 0, "Canonical candidate hash was not recorded.")
	_expect(not bool(result.get("production_output_replaced", true)), "Canonical candidate assembly must not replace generated output.")
	_expect(_output_texture_key_count(result) == 0, "Canonical candidate assembly returned production output keys.")


func _verify_staging_report(result: Dictionary) -> void:
	_expect(bool(result.get("ok", false)), "Generated-output replacement staging report failed: " + str(result))
	_expect(String(result.get("marker", "")) == EXPECTED_STAGING_MARKER, "Generated-output replacement staging marker changed.")
	_expect(String(result.get("gate_id", "")) == "R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1", "Replacement staging gate id changed.")
	_expect(String(result.get("stage", "")) == "generated_output_replacement_staging_report_only", "Replacement staging stage changed.")
	_expect(bool(result.get("generated_output_replacement_staging_ok", false)), "Replacement staging did not record generated_output_replacement_staging_ok.")
	_expect(not bool(result.get("replacement_ready", true)), "Replacement staging must not make replacement ready.")
	_expect(not bool(result.get("production_output_replaced", true)), "Replacement staging must not replace production output.")
	_expect(_output_texture_key_count(result) == 0, "Replacement staging returned actual production output keys.")
	_expect(_array_has_string(result.get("staged_output_texture_keys", []), "flow_foam_noise"), "Replacement staging did not name flow_foam_noise as the staged output.")
	_expect(_array_has_string(result.get("changed_texture_keys", []), "flow_foam_noise"), "Replacement staging did not report the staged flow_foam_noise hash change.")
	_expect(_array_has_string(result.get("legacy_sourced_texture_keys", []), "dist_pressure"), "Replacement staging did not keep dist_pressure legacy-sourced.")
	_expect(_array_has_string(result.get("legacy_sourced_channels", []), "flow_foam_noise.b"), "Replacement staging did not keep foam channel legacy-sourced.")
	_expect(_array_has_string(result.get("legacy_sourced_channels", []), "flow_foam_noise.a"), "Replacement staging did not keep noise channel legacy-sourced.")
	_expect(bool(result.get("actual_river_state_unchanged", false)), "Replacement staging changed RiverManager object state.")
	_expect(bool(result.get("actual_river_texture_hashes_unchanged", false)), "Replacement staging changed RiverManager texture hashes.")
	_expect(bool(result.get("river_manager_ownership_preserved", false)), "Replacement staging did not preserve RiverManager ownership.")
	_expect(bool(result.get("river_manager_public_surface_preserved", false)), "Replacement staging did not preserve the public surface guard.")
	_expect(int(result.get("source_signature_version", -1)) == 29, "Replacement staging must use source signature version 29.")


func _verify_staged_gate(gate: Dictionary, replacing_selection: Dictionary) -> void:
	_expect(not bool(gate.get("ready", true)), "Replacement gate became ready during staging.")
	_expect(not _gate_has_blocker(gate, "generated_output_replacement_staging_not_accepted"), "Staged gate should not still block on generated-output replacement staging.")
	_expect(_gate_has_blocker(gate, "production_replacement_validation_not_accepted"), "Staged gate should still block on production replacement validation.")
	_expect(not _gate_has_blocker(gate, "source_signature_version_29_or_backend_mode_signature_key_required"), "Staged gate should not block on the accepted source signature policy.")
	_expect(not _gate_has_blocker(gate, "canonical_compute_replacement_code_path_disabled"), "Staged gate should not block on the enabled replacement code path.")
	_expect(String(replacing_selection.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_LEGACY_CANVAS_ITEM, "canonical_compute_replacing should still fall back to legacy after staging.")
	_expect(String(replacing_selection.get("fallback_reason", "")) == "canonical_compute_replacing_not_promoted", "canonical_compute_replacing fallback reason changed after staging.")
	_expect(not bool(replacing_selection.get("production_output_replaced_by_compute", true)), "canonical_compute_replacing selection replaced output during staging.")


func _object_id(value: Variant) -> int:
	var object := value as Object
	return object.get_instance_id() if object != null else 0


func _output_texture_key_count(result: Dictionary) -> int:
	var output_keys = result.get("output_texture_keys", [])
	if typeof(output_keys) == TYPE_ARRAY or typeof(output_keys) == TYPE_PACKED_STRING_ARRAY:
		return output_keys.size()
	return 0


func _array_has_string(values: Variant, target: String) -> bool:
	if typeof(values) != TYPE_ARRAY and typeof(values) != TYPE_PACKED_STRING_ARRAY:
		return false
	for value in values:
		if String(value) == target:
			return true
	return false


func _gate_has_blocker(gate: Dictionary, blocker: String) -> bool:
	return _array_has_string(gate.get("blockers", []), blocker)


func _append_result(prefix: String, result: Dictionary) -> void:
	var keys := result.keys()
	keys.sort()
	for key in keys:
		if String(key).begins_with("_debug_"):
			continue
		var value = result[key]
		if value is Texture2D or value is Image:
			continue
		_report_lines.append(prefix + "." + str(key) + "=" + str(value))


func _record_warning(message: String) -> void:
	_warnings.append(message)


func _record_progress(percentage: float, label: String) -> void:
	_progress.append(str(percentage) + ":" + label)


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


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_GENERATED_OUTPUT_REPLACEMENT_STAGING_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _parse_args() -> Dictionary:
	var result := {}
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := String(arg)
		if text.find("=") < 0:
			continue
		var parts := text.split("=", false, 1)
		if parts.size() == 2:
			result[String(parts[0]).trim_prefix("--")] = parts[1]
	return result


func _parse_int_list(text: String, fallback: Array) -> Array:
	if text.strip_edges().is_empty():
		return fallback.duplicate()
	var result := []
	for part in text.split(",", false):
		var value := int(String(part).strip_edges())
		if value > 0:
			result.append(value)
	return result if not result.is_empty() else fallback.duplicate()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
