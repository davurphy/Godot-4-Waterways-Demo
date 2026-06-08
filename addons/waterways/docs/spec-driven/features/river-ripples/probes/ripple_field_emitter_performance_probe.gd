extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")
const FIELD_SCRIPT_PATH := "res://addons/waterways/water_ripple_field.gd"
const RESOLUTIONS := [128, 256, 512]
const EMITTER_COUNTS := [0, 4, 16]
const STEP_COUNT := 8
const MAX_DISPATCH_MS_PER_CASE := 12.0

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var field_script := load(FIELD_SCRIPT_PATH) as Script
	_expect(field_script != null and field_script.can_instantiate(), "WaterRippleField script should be instantiable for performance probe.")
	if field_script == null:
		_finish()
		return

	_results["renderer"] = {
		"method": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"step_count": STEP_COUNT,
	}
	var cases := []
	for resolution in RESOLUTIONS:
		for emitter_count in EMITTER_COUNTS:
			cases.append(await _run_case(field_script, int(resolution), int(emitter_count)))
	_results["cases"] = cases

	print("RIPPLE_FIELD_EMITTER_PERFORMANCE_RESULTS=", _results)
	_finish()


func _run_case(field_script: Script, resolution: int, emitter_count: int) -> Dictionary:
	var probe_root := Node3D.new()
	root.add_child(probe_root)

	var river := RiverManager.new()
	river.name = "PerformanceProbeRiver"
	probe_root.add_child(river)
	await _settle_frames(4)
	var river_mesh := river.get("mesh_instance") as MeshInstance3D
	_expect(river_mesh != null and river_mesh.mesh != null, "Performance RiverManager should expose a generated mesh for boundary sourcing.")

	var field := field_script.new() as Node3D
	field.name = "PerformanceProbeRippleField"
	field.set("enabled", false)
	field.set("resolution", resolution)
	field.set("max_emitters", max(1, emitter_count))
	field.set("world_bounds", AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 2.0, 6.0)))
	probe_root.add_child(field)
	var target_paths: Array[NodePath] = []
	target_paths.append(field.get_path_to(river))
	field.set("target_river_paths", target_paths)
	if river_mesh != null:
		var boundary_paths: Array[NodePath] = []
		boundary_paths.append(field.get_path_to(river_mesh))
		field.set("boundary_source_paths", boundary_paths)
	field.set("enabled", true)
	_expect(bool(field.call("initialize_runtime")), "Performance field should initialize at " + str(resolution) + ".")
	await _settle_frames(8)

	var dispatch_usec := 0
	var dispatch_start := Time.get_ticks_usec()
	for index in range(emitter_count):
		var position := _emitter_position(index, emitter_count)
		field.call("queue_impulse_world", position, 0.55, 0.75, 2.0, index, null)
	if emitter_count > 0:
		field.call("render_queued_impulses_once")
	dispatch_usec += Time.get_ticks_usec() - dispatch_start
	if emitter_count > 0:
		await _settle_frames(3)
	for _step in range(STEP_COUNT):
		dispatch_start = Time.get_ticks_usec()
		field.call("step_once")
		field.call("clear_impulse_once")
		dispatch_usec += Time.get_ticks_usec() - dispatch_start
		await process_frame
	var dispatch_ms := float(dispatch_usec) / 1000.0

	var snapshot: Dictionary = field.call("get_field_snapshot")
	_expect(not bool(snapshot.get("normal_runtime_readback", true)), "Performance field should not use normal-runtime readback.")
	_expect(int(snapshot.get("steps_completed", 0)) >= STEP_COUNT, "Performance field should complete simulation steps.")
	_expect(dispatch_ms <= MAX_DISPATCH_MS_PER_CASE, "Field/emitter dispatch exceeded budget at resolution=" + str(resolution) + " emitters=" + str(emitter_count) + ": " + str(dispatch_ms) + " ms.")
	if emitter_count > 0:
		_expect(int(snapshot.get("last_rendered_impulse_count", 0)) == min(emitter_count, int(snapshot.get("max_emitters", 0))), "Rendered impulse count should match the emitter cap.")

	var result := {
		"resolution": resolution,
		"emitter_count": emitter_count,
		"dispatch_ms": dispatch_ms,
		"read_texture_size": snapshot.get("read_texture_size", Vector2i.ZERO),
		"boundary_texture_size": snapshot.get("boundary_texture_size", Vector2i.ZERO),
		"last_rendered_impulse_count": snapshot.get("last_rendered_impulse_count", 0),
		"last_capped_impulse_count": snapshot.get("last_capped_impulse_count", 0),
		"steps_completed": snapshot.get("steps_completed", 0),
		"target_count": snapshot.get("target_count", 0),
		"applied_target_count": snapshot.get("applied_target_count", 0),
	}

	field.queue_free()
	await _settle_frames(3)
	_expect(not bool(river.call("has_runtime_ripple_material_state")), "Performance field cleanup should restore the target river.")
	probe_root.queue_free()
	await _settle_frames(2)
	return result


func _emitter_position(index: int, count: int) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	var columns := int(ceil(sqrt(float(count))))
	var row := index / columns
	var column := index % columns
	var x := -2.2 + 4.4 * (float(column) / float(max(columns - 1, 1)))
	var z := -2.2 + 4.4 * (float(row) / float(max(columns - 1, 1)))
	return Vector3(x, 0.0, z)


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_FIELD_EMITTER_PERFORMANCE_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
