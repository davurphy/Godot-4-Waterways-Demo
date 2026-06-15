# River-refactor R7 production replacement validation probe.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r7_compute_production_replacement_validation_probe.gd -- out=res://.codex-research/r7-baselines/compute-production-replacement-validation
#
# Success marker: R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK
extends "res://addons/waterways/probes/r7_compute_generated_output_replacement_staging_probe.gd"

const PRODUCTION_DEFAULT_OUT_DIR := "res://.codex-research/r7-baselines/compute-production-replacement-validation"
const PRODUCTION_REPORT_FILE_NAME := "r7_compute_production_replacement_validation.txt"
const PRODUCTION_EXPECTED_MARKER := "R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK"
const MAX_VALIDATION_FRAMES := 1200
const MAX_ALLOWED_FRAME_GAP_MS := 1000.0

var _validation_async_done := false
var _validation_async_result := {}
var _validation_progress_events: Array = []
var _validation_start_usec := 0


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", PRODUCTION_DEFAULT_OUT_DIR))
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var texture_width := maxi(4, int(args.get("texture_width", "106")))
	var texture_height := maxi(4, int(args.get("texture_height", "106")))
	var source_size := maxf(1.0, float(args.get("source_size", "64.0")))
	var atlas_columns := maxi(1, int(args.get("atlas_columns", "5")))
	var iterations_per_stride := maxi(1, int(args.get("iterations_per_stride", "5")))
	var stride_schedule := _parse_int_list(String(args.get("strides", "")), DEFAULT_STRIDE_SCHEDULE)

	_report_lines.append("R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_DUMP v1")
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
	_expect(river != null, "R7 production replacement validation fixture river was not found at " + river_path + ".")
	var legacy_elapsed_ms := 0.0
	if river != null:
		_configure_fixture_river(river)
		var legacy_start_usec := Time.get_ticks_usec()
		var legacy_ok := await _run_legacy_bake(river)
		legacy_elapsed_ms = float(Time.get_ticks_usec() - legacy_start_usec) / 1000.0
		_expect(legacy_ok, "Legacy fixture bake did not complete before production replacement validation.")

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
	var pipeline_run := await _measure_production_candidate_pipeline(projection_config, river)
	var projection_result: Dictionary = pipeline_run.get("projection_result", {})
	var candidate_result: Dictionary = pipeline_run.get("candidate_result", {})
	var timing_report := _make_timing_report(pipeline_run, projection_result, legacy_elapsed_ms)

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
	var assumed_validation_gate_config := _make_production_gate_config(bool(staging_report.get("ok", false)), true)
	var replacing_assumed_config := assumed_validation_gate_config.duplicate(true)
	replacing_assumed_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	var replacing_selection_after_validation := RiverFlowmapBaker.new().select_flowmap_backend(replacing_assumed_config)
	var production_validation_report := RiverFlowmapBaker.build_canonical_compute_production_replacement_validation_report({
		"legacy_before_state": before_state,
		"legacy_after_state": after_state,
		"legacy_before_hashes": before_hashes,
		"legacy_after_hashes": after_hashes,
		"candidate_hashes": candidate_hashes,
		"canonical_candidate_source": String(candidate_result.get("candidate_source", "")),
		"river_manager_ownership_preserved": before_state == after_state and before_hashes == after_hashes,
		"river_manager_public_surface_preserved": true,
		"timing": timing_report,
		"fallback_selection": replacing_selection_after_validation,
		"max_allowed_frame_gap_ms": MAX_ALLOWED_FRAME_GAP_MS
	})
	var production_gate_config := _make_production_gate_config(
		bool(staging_report.get("ok", false)),
		bool(production_validation_report.get("ok", false))
	)
	var production_gate := RiverFlowmapBaker.evaluate_canonical_compute_replacement_gate(production_gate_config)
	var replacing_config := production_gate_config.duplicate(true)
	replacing_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	var replacing_selection := RiverFlowmapBaker.new().select_flowmap_backend(replacing_config)
	var runtime_replacement_path := await _run_runtime_replacement_path_smoke(river, production_gate_config)
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
	_append_result("production_pipeline_timing", timing_report)
	_append_result("replacement_staging", staging_report)
	_append_result("production_replacement_validation", production_validation_report)
	_append_result("production_replacement_validation_gate", production_gate)
	_append_result("canonical_compute_replacing_after_production_validation", replacing_selection)
	_append_result("runtime_replacement_path", runtime_replacement_path)
	_append_result("output_preservation", output_preservation)
	_report_lines.append("legacy_after_state=" + str(after_state))
	_report_lines.append("legacy_after_hashes=" + str(after_hashes))
	_report_lines.append("warnings=" + str(_warnings))
	_report_lines.append("progress=" + str(_progress))

	_verify_projection_result(projection_result)
	_verify_candidate_result(candidate_result)
	_verify_staging_report(staging_report)
	_verify_production_validation_report(production_validation_report)
	_verify_production_gate(production_gate, replacing_selection)
	_verify_runtime_replacement_path(runtime_replacement_path)
	_expect(bool(output_preservation.get("ok", false)), "Production replacement validation changed RiverManager output state or hashes.")

	if fixture != null:
		fixture.queue_free()
		current_scene = null
	_written_report = out_dir.path_join(PRODUCTION_REPORT_FILE_NAME)
	_write_report(_written_report)
	_finish()


func _measure_production_candidate_pipeline(projection_config: Dictionary, river: Node) -> Dictionary:
	var baker := RiverFlowmapBaker.new()
	_validation_async_done = false
	_validation_async_result = {}
	_validation_progress_events = []
	_validation_start_usec = Time.get_ticks_usec()
	var previous_frame_usec := _validation_start_usec
	var frame_gaps: Array = []
	_start_production_candidate_pipeline(baker, projection_config, river)
	var frame_count := 0
	while not _validation_async_done and frame_count < MAX_VALIDATION_FRAMES:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_gaps.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
		frame_count += 1
	if not _validation_async_done:
		_errors.append("Production replacement validation pipeline did not finish within " + str(MAX_VALIDATION_FRAMES) + " frames.")
		baker.abort()
		await process_frame
	var finish_usec := Time.get_ticks_usec()
	baker.cleanup()
	baker.abort()
	baker.cleanup()
	var result := _validation_async_result.duplicate(true)
	result["completed"] = _validation_async_done
	result["elapsed_ms"] = float(finish_usec - _validation_start_usec) / 1000.0
	result["frame_count"] = frame_count
	result["frame_gaps_ms"] = frame_gaps.duplicate()
	result["max_frame_gap_ms"] = _max_float(frame_gaps)
	result["p95_frame_gap_ms"] = _percentile(frame_gaps, 0.95)
	result["progress_events"] = _validation_progress_events.duplicate(true)
	return result


func _start_production_candidate_pipeline(baker: RiverFlowmapBaker, projection_config: Dictionary, river: Node) -> void:
	var projection_start_usec := Time.get_ticks_usec()
	var projection_result: Dictionary = await baker.run_non_replacing_compute_solve_filter_projection_probe(
		projection_config,
		Callable(self, "_record_validation_progress")
	)
	var projection_elapsed_ms := float(Time.get_ticks_usec() - projection_start_usec) / 1000.0
	baker.cleanup()
	baker.abort()
	baker.cleanup()
	var candidate_start_usec := Time.get_ticks_usec()
	var candidate_result := await _make_canonical_candidate_texture(projection_result, river)
	var candidate_elapsed_ms := float(Time.get_ticks_usec() - candidate_start_usec) / 1000.0
	_validation_async_result = {
		"projection_result": projection_result,
		"candidate_result": candidate_result,
		"compute_projection_elapsed_ms": projection_elapsed_ms,
		"candidate_assembly_elapsed_ms": candidate_elapsed_ms,
	}
	_validation_async_done = true


func _make_timing_report(pipeline_run: Dictionary, projection_result: Dictionary, legacy_elapsed_ms: float) -> Dictionary:
	return {
		"completed": bool(pipeline_run.get("completed", false)),
		"elapsed_ms": float(pipeline_run.get("elapsed_ms", 0.0)),
		"frame_count": int(pipeline_run.get("frame_count", 0)),
		"max_frame_gap_ms": float(pipeline_run.get("max_frame_gap_ms", 0.0)),
		"p95_frame_gap_ms": float(pipeline_run.get("p95_frame_gap_ms", 0.0)),
		"legacy_fixture_bake_elapsed_ms": legacy_elapsed_ms,
		"compute_projection_elapsed_ms": float(pipeline_run.get("compute_projection_elapsed_ms", 0.0)),
		"candidate_assembly_elapsed_ms": float(pipeline_run.get("candidate_assembly_elapsed_ms", 0.0)),
		"selected_readback_path": String(projection_result.get("selected_readback_path", "")),
		"async_readback_selected": bool(projection_result.get("async_readback_selected", false)),
		"submit_count": int(projection_result.get("submit_count", 0)),
		"sync_count": int(projection_result.get("sync_count", 0)),
		"sync_wait_frames": int(projection_result.get("sync_wait_frames", 0)),
		"dispatch_count": int(projection_result.get("dispatch_count", 0)),
		"compute_barrier_count": int(projection_result.get("compute_barrier_count", 0)),
		"readback_byte_count": int(projection_result.get("readback_byte_count", 0)),
		"max_allowed_frame_gap_ms": MAX_ALLOWED_FRAME_GAP_MS,
	}


func _make_production_gate_config(staging_ok: bool, production_validation_ok: bool) -> Dictionary:
	return {
		"automated_canonical_acceptance_ok": true,
		"representative_visuals_ok": true,
		"selection_abort_ok": true,
		"cleanup_responsiveness_ok": true,
		"river_manager_surface_ok": true,
		"generated_output_replacement_staging_ok": staging_ok,
		"production_replacement_validation_ok": production_validation_ok,
		"source_signature_version": 29,
		"source_signature_includes_backend_mode": false,
	}


func _run_runtime_replacement_path_smoke(river: Node, gate_config: Dictionary) -> Dictionary:
	var before_state := _river_output_state(river)
	var before_hashes := _river_texture_hashes(river)
	var captured_config := {}
	var captured_value = _legacy_projection_capture.get("filter_pass_config", {})
	if typeof(captured_value) == TYPE_DICTIONARY:
		captured_config = (captured_value as Dictionary).duplicate(true)
	if captured_config.is_empty():
		return {
			"ok": false,
			"reason": "filter_pass_config_not_captured",
			"production_output_replaced": false,
			"output_texture_keys": [],
			"river_state_unchanged": before_state == _river_output_state(river),
			"river_texture_hashes_unchanged": before_hashes == _river_texture_hashes(river),
		}
	var replacement_config := captured_config.duplicate(true)
	for key in gate_config.keys():
		replacement_config[key] = gate_config[key]
	replacement_config[RiverFlowmapBaker.FLOWMAP_BACKEND_CONFIG_KEY] = RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
	replacement_config["frame_wait_source"] = self
	replacement_config["warning_callback"] = Callable(self, "_record_warning")
	var baker := RiverFlowmapBaker.new()
	var filter_result: Dictionary = await baker.run_filter_pass_sequence(
		replacement_config,
		Callable(self, "_record_validation_progress")
	)
	baker.cleanup()
	var after_state := _river_output_state(river)
	var after_hashes := _river_texture_hashes(river)
	var selection := {}
	var selection_value = filter_result.get("flowmap_backend_selection", {})
	if typeof(selection_value) == TYPE_DICTIONARY:
		selection = (selection_value as Dictionary).duplicate(true)
	var replacement_result := {}
	var replacement_value = filter_result.get("canonical_compute_replacement_result", {})
	if typeof(replacement_value) == TYPE_DICTIONARY:
		replacement_result = (replacement_value as Dictionary).duplicate(true)
	var replacement_summary := {
		"ok": bool(replacement_result.get("ok", false)),
		"reason": String(replacement_result.get("reason", "")),
		"mode": String(replacement_result.get("mode", "")),
		"production_output_replaced": bool(replacement_result.get("production_output_replaced", false)),
		"output_texture_keys": replacement_result.get("output_texture_keys", []),
		"selected_readback_path": String(replacement_result.get("selected_readback_path", "")),
		"async_readback_selected": bool(replacement_result.get("async_readback_selected", false)),
		"sync_wait_frames": int(replacement_result.get("sync_wait_frames", -1)),
		"submit_count": int(replacement_result.get("submit_count", -1)),
		"sync_count": int(replacement_result.get("sync_count", -1)),
		"dispatch_count": int(replacement_result.get("dispatch_count", -1)),
		"compute_barrier_count": int(replacement_result.get("compute_barrier_count", -1)),
	}
	var flow_hash := _hash_texture(filter_result.get("flow_foam_noise_texture") as Texture2D)
	var dist_hash := _hash_texture(filter_result.get("dist_pressure_texture") as Texture2D)
	var ok := (
		bool(filter_result.get("ok", false))
		and String(filter_result.get("flowmap_backend_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
		and String(selection.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING
		and not bool(selection.get("fallback_applied", true))
		and bool(filter_result.get("production_output_replaced", false))
		and _array_has_string(filter_result.get("output_texture_keys", []), "flow_foam_noise")
		and _output_texture_key_count(filter_result) == 1
		and bool(replacement_summary.get("ok", false))
		and bool(replacement_summary.get("production_output_replaced", false))
		and not bool(replacement_summary.get("async_readback_selected", true))
		and String(replacement_summary.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0
		and before_state == after_state
		and before_hashes == after_hashes
	)
	return {
		"ok": ok,
		"reason": "ok" if ok else "runtime_replacement_path_failed_invariants",
		"mode": String(filter_result.get("flowmap_backend_mode", "")),
		"selected_mode": String(selection.get("selected_mode", "")),
		"fallback_applied": bool(selection.get("fallback_applied", true)),
		"fallback_reason": String(selection.get("fallback_reason", "")),
		"production_output_replaced": bool(filter_result.get("production_output_replaced", false)),
		"output_texture_keys": filter_result.get("output_texture_keys", []),
		"flow_foam_noise_hash": flow_hash,
		"dist_pressure_hash": dist_hash,
		"replacement_summary": replacement_summary,
		"river_state_unchanged": before_state == after_state,
		"river_texture_hashes_unchanged": before_hashes == after_hashes,
	}


func _verify_production_validation_report(result: Dictionary) -> void:
	_expect(bool(result.get("ok", false)), "Production replacement validation report failed: " + str(result))
	_expect(String(result.get("marker", "")) == PRODUCTION_EXPECTED_MARKER, "Production replacement validation marker changed.")
	_expect(String(result.get("gate_id", "")) == "R7_CANONICAL_COMPUTE_REPLACEMENT_GATE_V1", "Production replacement validation gate id changed.")
	_expect(String(result.get("stage", "")) == "production_replacement_validation_report_only", "Production replacement validation stage changed.")
	_expect(bool(result.get("production_replacement_validation_ok", false)), "Production replacement validation did not record production_replacement_validation_ok.")
	_expect(bool(result.get("generated_output_replacement_staging_ok", false)), "Production validation lost generated-output staging evidence.")
	_expect(not bool(result.get("replacement_ready", true)), "Production validation must not make replacement ready.")
	_expect(not bool(result.get("production_output_replaced", true)), "Production validation must not replace production output.")
	_expect(_output_texture_key_count(result) == 0, "Production validation returned actual production output keys.")
	_expect(_array_has_string(result.get("would_replace_texture_keys", []), "flow_foam_noise"), "Production validation did not name flow_foam_noise as the would-replace texture.")
	_expect(_array_has_string(result.get("river_manager_handoff_texture_fields", []), "flow_foam_noise_texture"), "Production validation did not record RiverManager flow_foam_noise_texture handoff.")
	_expect(_array_has_string(result.get("legacy_sourced_channels", []), "flow_foam_noise.b"), "Production validation did not keep foam legacy-sourced.")
	_expect(_array_has_string(result.get("legacy_sourced_channels", []), "flow_foam_noise.a"), "Production validation did not keep noise legacy-sourced.")
	_expect(_array_has_string(result.get("legacy_sourced_texture_keys", []), "dist_pressure"), "Production validation did not keep dist_pressure legacy-sourced.")
	_expect(bool(result.get("timing_responsiveness_ok", false)), "Production validation timing/responsiveness failed.")
	_expect(bool(result.get("fallback_behavior_ok", false)), "Production validation fallback behavior failed.")
	_expect(bool(result.get("actual_river_state_unchanged", false)), "Production validation changed RiverManager object state.")
	_expect(bool(result.get("actual_river_texture_hashes_unchanged", false)), "Production validation changed RiverManager texture hashes.")
	_expect(bool(result.get("river_manager_ownership_preserved", false)), "Production validation did not preserve RiverManager ownership.")
	_expect(bool(result.get("river_manager_public_surface_preserved", false)), "Production validation did not preserve the public surface guard.")
	_expect(int(result.get("source_signature_version", -1)) == 29, "Production validation must use source signature version 29.")
	_expect(bool(result.get("source_signature_policy_ready", false)), "Production validation must keep source signature policy ready.")


func _verify_production_gate(gate: Dictionary, replacing_selection: Dictionary) -> void:
	_expect(bool(gate.get("ready", false)), "Replacement gate should be ready after accepted source policy, code path, and production validation evidence.")
	_expect(not _gate_has_blocker(gate, "generated_output_replacement_staging_not_accepted"), "Production gate should not still block on generated-output replacement staging.")
	_expect(not _gate_has_blocker(gate, "production_replacement_validation_not_accepted"), "Production gate should not still block on production replacement validation after this report.")
	_expect(not _gate_has_blocker(gate, "source_signature_version_29_or_backend_mode_signature_key_required"), "Production gate should not block on accepted source signature policy.")
	_expect(not _gate_has_blocker(gate, "canonical_compute_replacement_code_path_disabled"), "Production gate should not block on enabled replacement code path.")
	_expect(String(replacing_selection.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "canonical_compute_replacing should select compute after production validation evidence.")
	_expect(not bool(replacing_selection.get("fallback_applied", true)), "canonical_compute_replacing should not fall back after the gate is ready.")
	_expect(bool(replacing_selection.get("production_output_replaced_by_compute", false)), "canonical_compute_replacing selection should report replacement after the gate is ready.")


func _verify_runtime_replacement_path(result: Dictionary) -> void:
	_expect(bool(result.get("ok", false)), "Runtime replacement path smoke failed: " + str(result))
	_expect(String(result.get("mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "Runtime replacement path did not select canonical compute.")
	_expect(String(result.get("selected_mode", "")) == RiverFlowmapBaker.FLOWMAP_BACKEND_CANONICAL_COMPUTE_REPLACING, "Runtime replacement path selection did not stay canonical compute.")
	_expect(not bool(result.get("fallback_applied", true)), "Runtime replacement path fell back to legacy.")
	_expect(bool(result.get("production_output_replaced", false)), "Runtime replacement path did not report production output replacement.")
	_expect(_output_texture_key_count(result) == 1, "Runtime replacement path should report exactly one output texture key.")
	_expect(_array_has_string(result.get("output_texture_keys", []), "flow_foam_noise"), "Runtime replacement path should report flow_foam_noise as the only replacement output.")
	var replacement_summary := {}
	var summary_value = result.get("replacement_summary", {})
	if typeof(summary_value) == TYPE_DICTIONARY:
		replacement_summary = summary_value as Dictionary
	_expect(bool(replacement_summary.get("ok", false)), "Runtime replacement compute summary did not report ok.")
	_expect(String(replacement_summary.get("selected_readback_path", "")).find("sync_texture_get_data") >= 0, "Runtime replacement path did not keep sync texture readback.")
	_expect(not bool(replacement_summary.get("async_readback_selected", true)), "Runtime replacement path selected async readback.")
	_expect(bool(result.get("river_state_unchanged", false)), "Runtime replacement path changed RiverManager state.")
	_expect(bool(result.get("river_texture_hashes_unchanged", false)), "Runtime replacement path changed RiverManager texture hashes.")


func _record_validation_progress(percentage: float, label: String) -> void:
	var now_usec := Time.get_ticks_usec()
	_progress.append(str(percentage) + ":" + label)
	_validation_progress_events.append({
		"elapsed_ms": float(now_usec - _validation_start_usec) / 1000.0,
		"progress": percentage,
		"label": label,
	})


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


func _finish() -> void:
	if _errors.is_empty():
		print("R7_COMPUTE_PRODUCTION_REPLACEMENT_VALIDATION_OK report=", _written_report)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
