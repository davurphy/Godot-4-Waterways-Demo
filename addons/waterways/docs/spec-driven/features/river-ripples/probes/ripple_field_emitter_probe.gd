extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")
const FIELD_SCRIPT_PATH := "res://addons/waterways/water_ripple_field.gd"
const EMITTER_SCRIPT_PATH := "res://addons/waterways/water_ripple_emitter.gd"
const FIELD_SCENE_PATH := "res://addons/waterways/water_ripple_field.tscn"
const EMITTER_SCENE_PATH := "res://addons/waterways/water_ripple_emitter.tscn"

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var field_script := load(FIELD_SCRIPT_PATH) as Script
	var emitter_script := load(EMITTER_SCRIPT_PATH) as Script
	_expect(field_script != null and field_script.can_instantiate(), "WaterRippleField script should be instantiable.")
	_expect(emitter_script != null and emitter_script.can_instantiate(), "WaterRippleEmitter script should be instantiable.")
	_expect(_packed_scene_instantiates(FIELD_SCENE_PATH), "WaterRippleField prototype scene should instantiate.")
	_expect(_packed_scene_instantiates(EMITTER_SCENE_PATH), "WaterRippleEmitter prototype scene should instantiate.")
	if field_script == null or emitter_script == null:
		_finish()
		return

	var probe_root := Node3D.new()
	root.add_child(probe_root)

	var river := RiverManager.new()
	river.name = "FieldEmitterProbeRiver"
	probe_root.add_child(river)
	await _settle_frames(4)
	var river_mesh := river.get("mesh_instance") as MeshInstance3D
	_expect(river_mesh != null and river_mesh.mesh != null, "Probe RiverManager should expose a generated mesh for boundary sourcing.")

	var field := field_script.new() as Node3D
	_expect(field != null, "WaterRippleField should instantiate as Node3D.")
	if field == null:
		_finish()
		return
	field.name = "ProbeWaterRippleField"
	field.set("enabled", false)
	field.set("resolution", 128)
	field.set("max_emitters", 2)
	field.set("world_bounds", AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 2.0, 4.0)))
	probe_root.add_child(field)
	var target_paths: Array[NodePath] = []
	target_paths.append(field.get_path_to(river))
	field.set("target_river_paths", target_paths)
	if river_mesh != null:
		var boundary_paths: Array[NodePath] = []
		boundary_paths.append(field.get_path_to(river_mesh))
		field.set("boundary_source_paths", boundary_paths)
	field.set("enabled", true)
	_expect(bool(field.call("initialize_runtime")), "WaterRippleField should initialize with a target river.")
	await _settle_frames(8)

	var initial_snapshot: Dictionary = field.call("get_field_snapshot")
	_expect(bool(initial_snapshot.get("runtime_initialized", false)), "Field should report runtime initialization.")
	_expect(Vector2i(initial_snapshot.get("read_texture_size", Vector2i.ZERO)) == Vector2i(128, 128), "Field read texture should be 128x128.")
	_expect(Vector2i(initial_snapshot.get("impulse_texture_size", Vector2i.ZERO)) == Vector2i(128, 128), "Field impulse texture should be 128x128.")
	_expect(String(initial_snapshot.get("boundary_source", "")) == "target_river_mesh_footprint", "Field should generate boundary from target river mesh footprint.")
	_expect(bool(initial_snapshot.get("boundary_valid", false)), "Field boundary should be valid.")
	_expect(bool(initial_snapshot.get("has_distinct_viewports", false)), "Field should own distinct ping-pong viewports.")
	_expect(bool(initial_snapshot.get("has_distinct_textures", false)), "Field should expose distinct ping-pong textures.")
	_expect(int(initial_snapshot.get("target_count", 0)) == 1, "Field should resolve one target river.")
	_expect(int(initial_snapshot.get("applied_target_count", 0)) == 1, "Field should apply runtime material state to one target.")
	_expect(bool(river.call("has_runtime_ripple_material_state", field)), "River should report field-owned runtime ripple material state.")

	var mapped_uv: Vector2 = field.call("world_position_to_ripple_uv", Vector3.ZERO)
	_expect(mapped_uv.distance_to(Vector2(0.5, 0.5)) < 0.00001, "Field world-to-ripple mapping should center Vector3.ZERO in the probe bounds.")

	var emitter := emitter_script.new() as Node3D
	_expect(emitter != null, "WaterRippleEmitter should instantiate as Node3D.")
	if emitter != null:
		emitter.name = "ProbeRippleEmitter"
		emitter.set("target_field_path", emitter.get_path_to(field) if emitter.is_inside_tree() else NodePath("../ProbeWaterRippleField"))
		emitter.set("radius", 0.55)
		emitter.set("intensity", 0.9)
		emitter.set("priority", 4)
		emitter.position = Vector3(0.0, 0.0, 0.0)
		probe_root.add_child(emitter)
		emitter.set("target_field_path", emitter.get_path_to(field))
		await _settle_frames(2)
		_expect(bool(emitter.call("emit_once")), "Emitter should queue an in-bounds impulse on the target field.")
		var emitter_snapshot: Dictionary = emitter.call("get_emitter_snapshot")
		_expect(int(emitter_snapshot.get("emit_count", 0)) == 1, "Emitter should count the accepted manual impulse.")

	var accepted_a := bool(field.call("queue_impulse_world", Vector3(-0.75, 0.0, 0.0), 0.45, 0.6, 2.0, 1, null))
	var accepted_b := bool(field.call("queue_impulse_world", Vector3(0.75, 0.0, 0.0), 0.45, 0.7, 2.0, 5, null))
	var accepted_c := bool(field.call("queue_impulse_world", Vector3(0.0, 0.0, 0.75), 0.45, 0.8, 2.0, 0, null))
	_expect(accepted_a and accepted_b and accepted_c, "Manual in-bounds impulses should be queued.")
	var rendered_count := int(field.call("render_queued_impulses_once"))
	_expect(rendered_count == 2, "Field should render only max_emitters impulses in one pass.")
	await _settle_frames(3)
	_expect(bool(field.call("step_once")), "Field should step the simulation after rendered impulses.")
	await _settle_frames(3)
	field.call("clear_impulse_once")
	await _settle_frames(2)

	var post_step_snapshot: Dictionary = field.call("get_field_snapshot")
	_expect(int(post_step_snapshot.get("last_rendered_impulse_count", 0)) == 2, "Field snapshot should record the rendered cap.")
	_expect(int(post_step_snapshot.get("last_capped_impulse_count", 0)) >= 2, "Field snapshot should record capped impulses from emitter plus manual burst.")
	_expect(int(post_step_snapshot.get("steps_completed", 0)) >= 1, "Field should record completed simulation steps.")
	_expect(not bool(post_step_snapshot.get("same_target_hazard_last_step", true)), "Field should not sample from the write target on the last step.")
	_expect(not bool(post_step_snapshot.get("normal_runtime_readback", true)), "Field runtime path should not use readback.")

	var out_of_bounds := bool(field.call("queue_impulse_world", Vector3(10.0, 0.0, 10.0), 0.5, 1.0, 2.0, 10, null))
	_expect(not out_of_bounds, "Field should reject out-of-bounds world impulses.")

	field.set("enabled", false)
	await _settle_frames(2)
	_expect(not bool(river.call("has_runtime_ripple_material_state", field)), "Disabling the field should clear field-owned river material state.")

	field.set("enabled", true)
	_expect(bool(field.call("initialize_runtime")), "Field should reinitialize after being re-enabled.")
	await _settle_frames(6)
	_expect(bool(river.call("has_runtime_ripple_material_state", field)), "Re-enabled field should reapply river material state.")

	field.queue_free()
	await _settle_frames(4)
	_expect(not bool(river.call("has_runtime_ripple_material_state")), "Freeing the field should restore the target river material.")

	_results = {
		"initial": initial_snapshot,
		"post_step": post_step_snapshot,
		"out_of_bounds_rejected": not out_of_bounds,
	}

	probe_root.queue_free()
	await _settle_frames(2)
	print("RIPPLE_FIELD_EMITTER_PROBE_RESULTS=", _results)
	_finish()


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _packed_scene_instantiates(scene_path: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	var is_valid_scene := instance != null
	if instance != null:
		instance.queue_free()
	return is_valid_scene


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_FIELD_EMITTER_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
