extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")
const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")
const FIELD_SCRIPT_PATH := "res://addons/waterways/water_ripple_field.gd"
const EMITTER_SCRIPT_PATH := "res://addons/waterways/water_ripple_emitter.gd"

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var field_script := load(FIELD_SCRIPT_PATH) as Script
	var emitter_script := load(EMITTER_SCRIPT_PATH) as Script
	_expect(field_script != null and field_script.can_instantiate(), "WaterRippleField script should instantiate.")
	_expect(emitter_script != null and emitter_script.can_instantiate(), "WaterRippleEmitter script should instantiate.")
	if field_script == null or emitter_script == null:
		_finish()
		return

	await _check_ripple_step_clamp(field_script)
	await _check_dynamic_targets_and_cleanup(field_script)
	await _check_emitter_one_shot_cap(emitter_script)
	_check_width_generation_parity()
	await _check_buoyancy_coverage_binding()

	_finish()


func _make_runtime_field(field_script: Script, name: String) -> Node3D:
	var field := field_script.new() as Node3D
	field.name = name
	field.set("enabled", false)
	field.set("resolution", 64)
	field.set("max_emitters", 4)
	field.set("require_boundary_mask", false)
	field.set("auto_generate_boundary_mask", false)
	field.set("world_bounds", AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 2.0, 8.0)))
	root.add_child(field)
	field.set("enabled", true)
	_expect(bool(field.call("initialize_runtime")), name + " should initialize.")
	return field


func _check_ripple_step_clamp(field_script: Script) -> void:
	var field := _make_runtime_field(field_script, "R4StepClampField")
	await _settle_frames(3)

	var before: Dictionary = field.call("get_field_snapshot")
	field.call("_process", 2.0)
	var after_hitch: Dictionary = field.call("get_field_snapshot")
	_expect(int(after_hitch.get("steps_completed", 0)) == int(before.get("steps_completed", 0)) + 1, "A 2 s hitch should produce exactly one ripple step.")

	for _index in range(6):
		_expect(bool(field.call("queue_impulse_world", Vector3.ZERO, 0.5, 0.9)), "Impulse should queue during starvation check.")
		field.call("_process", 1.0 / 60.0)
	var after_impulses: Dictionary = field.call("get_field_snapshot")
	_expect(int(after_impulses.get("steps_completed", 0)) >= int(after_hitch.get("steps_completed", 0)) + 2, "60 Hz impulses should not starve ripple propagation.")
	_expect(int(after_impulses.get("last_rendered_impulse_count", 0)) > 0, "Impulse render pass should still run.")
	field.queue_free()
	await _settle_frames(2)


func _check_dynamic_targets_and_cleanup(field_script: Script) -> void:
	var field := _make_runtime_field(field_script, "R4TargetRefreshField")
	field.set("target_group_name", "r4_late_targets")
	await _settle_frames(3)

	var river := RiverManager.new()
	river.name = "R4LateTargetRiver"
	root.add_child(river)
	river.add_to_group("r4_late_targets")
	await _settle_frames(4)
	field.call("_process", 1.0 / 60.0)
	var late_snapshot: Dictionary = field.call("get_field_snapshot")
	_expect(int(late_snapshot.get("target_count", 0)) == 1, "Late group target should refresh into the field target list.")
	_expect(int(late_snapshot.get("applied_target_count", 0)) == 1, "Late group target should receive runtime ripple material state.")

	field.call("register_target", river)
	field.call("cleanup_runtime")
	_expect(bool(field.call("initialize_runtime")), "Field should reinitialize after cleanup_runtime().")
	await _settle_frames(4)
	var rebuild_snapshot: Dictionary = field.call("get_field_snapshot")
	_expect(int(rebuild_snapshot.get("target_count", 0)) == 1, "API-registered target should survive cleanup_runtime().")
	_expect(int(rebuild_snapshot.get("applied_target_count", 0)) == 1, "API-registered target should be reapplied after rebuild.")

	var off_tree_field := field_script.new() as Node3D
	off_tree_field.set("field_group_name", "r4_old_group")
	off_tree_field.set("field_group_name", "r4_new_group")
	_expect(not off_tree_field.is_in_group("r4_old_group"), "Off-tree field_group_name changes should remove the old group.")
	_expect(off_tree_field.is_in_group("r4_new_group"), "Off-tree field_group_name changes should keep the new group.")
	off_tree_field.free()

	field.queue_free()
	river.queue_free()
	await _settle_frames(2)


func _check_emitter_one_shot_cap(emitter_script: Script) -> void:
	var emitter := emitter_script.new() as Node3D
	emitter.name = "R4OneShotCapEmitter"
	emitter.set("enabled", true)
	emitter.set("target_field_path", NodePath(""))
	emitter.set("field_group_name", "")
	emitter.set("emitter_mode", 2)
	root.add_child(emitter)
	await _settle_frames(1)
	for _index in range(20):
		emitter.call("_process", 1.0 / 60.0)
	var snapshot: Dictionary = emitter.call("get_emitter_snapshot")
	_expect(int(snapshot.get("one_shot_route_retries", 0)) == 8, "One-shot emitter should stop after the route retry cap.")
	_expect(int(snapshot.get("rejected_count", 0)) == 8, "One-shot emitter should not retry forever without a field.")
	emitter.queue_free()
	await _settle_frames(2)


func _check_width_generation_parity() -> void:
	var curve := Curve3D.new()
	curve.add_point(Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(2.0, 0.0, 0.0))
	curve.add_point(Vector3(4.0, 0.0, 1.0), Vector3(-1.0, 0.0, -0.5), Vector3(1.5, 0.0, 0.8))
	curve.add_point(Vector3(8.0, 0.0, -1.0), Vector3(-1.5, 0.0, 0.5), Vector3(2.0, 0.0, -0.2))
	curve.add_point(Vector3(12.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0), Vector3.ZERO)
	var widths := [1.0, 1.75, 0.85, 1.35]
	var next_values := WaterHelperMethods.generate_river_width_values(curve, 8, 4, 4, widths)
	var legacy_values := _legacy_generate_river_width_values(curve, 8, 4, widths)
	_expect(next_values.size() == legacy_values.size(), "Width generation should preserve sample count.")
	var max_delta := 0.0
	for index in range(min(next_values.size(), legacy_values.size())):
		max_delta = maxf(max_delta, absf(float(next_values[index]) - float(legacy_values[index])))
	_expect(max_delta <= 0.03, "Width generation should stay within the legacy 1/100-segment search tolerance. max_delta=" + str(max_delta))


func _legacy_generate_river_width_values(curve: Curve3D, steps: int, step_length_divs: int, widths: Array) -> Array:
	var values := []
	var safe_steps := max(1, steps)
	var safe_step_length_divs: int = clamp(step_length_divs, WaterHelperMethods.SHAPE_STEP_DIVS_MIN, WaterHelperMethods.SHAPE_STEP_DIVS_MAX)
	var sample_count: int = safe_steps * safe_step_length_divs
	var length := curve.get_baked_length()
	var last_width_index: int = min(curve.get_point_count(), widths.size()) - 1
	for step in sample_count + 1:
		if step == 0:
			values.append(float(widths[0]))
			continue
		if step == sample_count:
			values.append(float(widths[last_width_index]))
			continue
		var target_pos := curve.sample_baked((float(step) / float(sample_count)) * length)
		var closest_dist := INF
		var closest_interpolate := 0.0
		var closest_point := 0
		for point_index in last_width_index:
			for sub_index in 101:
				var interpolate := float(sub_index) / 100.0
				var pos := curve.sample(point_index, interpolate)
				var dist := pos.distance_to(target_pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_interpolate = interpolate
					closest_point = point_index
		values.append(max(WaterHelperMethods.MIN_RIVER_WIDTH, lerpf(float(widths[closest_point]), float(widths[closest_point + 1]), smoothstep(0.0, 1.0, closest_interpolate))))
	return values


func _check_buoyancy_coverage_binding() -> void:
	var body := RigidBody3D.new()
	body.name = "R4CoverageBody"
	body.position = Vector3(10.0, -0.5, 0.0)
	root.add_child(body)

	var near_system := _make_test_water_system("R4NearButOutside", Vector3.ZERO, AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0)))
	var covering_system := _make_test_water_system("R4FarButCovering", Vector3(50.0, 0.0, 0.0), AABB(Vector3(8.0, -2.0, -2.0), Vector3(6.0, 4.0, 4.0)))
	root.add_child(near_system)
	root.add_child(covering_system)
	await _settle_frames(2)

	var buoyant := preload("res://addons/waterways/buoyant_manager.gd").new()
	body.add_child(buoyant)
	await _settle_frames(2)
	buoyant.call("_refresh_system_reference")
	_expect(buoyant.get("_system") == covering_system, "Buoyant should bind to the WaterSystem whose coverage contains the body, not the nearest origin.")

	body.sleeping = true
	var was_sleeping := bool(buoyant.call("_wake_body_for_water_force"))
	_expect(was_sleeping, "_wake_body_for_water_force should report a sleeping body.")
	_expect(body.sleeping, "Buoyant should not force settled bodies awake every tick.")

	body.queue_free()
	near_system.queue_free()
	covering_system.queue_free()
	await _settle_frames(2)


func _make_test_water_system(name: String, position: Vector3, bounds: AABB) -> WaterSystem:
	var system := WaterSystem.new()
	system.name = name
	system.position = position
	system.set("_system_aabb", bounds)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 0.5, 1.0))
	system.call("set_system_map", ImageTexture.create_from_image(image))
	return system


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("R4_RUNTIME_ROBUSTNESS_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
