extends Node3D

const TARGET_RIVER_PATH := "World/WaterSystem/Water River"
const TERRAIN_PATH := "World/HTerrain"
const FIELD_PATH := "WaterRippleField"
const REVIEW_CAMERA_NAME := "RippleFieldEmitterReviewCamera"
const DEMO_CAMERA_PATH := "World/Phase0B Review Cameras/Phase0B_UpperRiver_Overhead"
const DEBUG_VIEW_NORMAL := 0
const DEBUG_VIEW_RIPPLE_RAW_HEIGHT := 62
const DEBUG_VIEW_RIPPLE_IMPULSE_CONTACT := 63
const DEBUG_VIEW_RIPPLE_BOUNDARY_MASK := 64
const DEBUG_VIEW_RIPPLE_VISIBLE_INFLUENCE := 65
const CAMERA_MODE_OVERHEAD := 0
const CAMERA_MODE_OBLIQUE := 1
const CAMERA_MODE_DEMO := 2
const CAMERA_MOVE_SPEED := 12.0
const CAMERA_FAST_MULTIPLIER := 3.0
const CAMERA_ZOOM_STEP := 1.25
const MOUSE_LOOK_SENSITIVITY := 0.0035
const MAX_CAMERA_PITCH := 1.35
const MOVING_PATH_SECONDS := 5.0
const MOVING_PATH_SEGMENT_STEPS := 4
const FIELD_RESOLUTION := 256
const REVIEW_RIPPLE_STRENGTH := 2.25
const REVIEW_NORMAL_STRENGTH := 3.0
const TERRAIN_HEIGHT_UNAVAILABLE := -1000000000.0
const MIN_VISIBLE_WATER_TERRAIN_CLEARANCE := 0.08
const EMITTER_DISPLAY_HEIGHT_ABOVE_WATER := 0.18
const EMITTER_DISPLAY_TERRAIN_CLEARANCE := 0.8
const MARKER_VERTICAL_OFFSET := 0.55
const EMITTER_EXPECTED_UVS := {
	"PulseEmitter_UpperWater": Vector2(0.662573, 0.336428),
	"OneShotEmitter_MidBend": Vector2(0.755304, 0.355428),
	"MovingEmitter_TestTrail": Vector2(0.744296, 0.313726),
}
const MOVING_PATH_UVS := [
	Vector2(0.658509, 0.318055),
	Vector2(0.744296, 0.313726),
	Vector2(0.731226, 0.293750),
	Vector2(0.744296, 0.313726),
]

var _target_river: Node
var _terrain: Node
var _field: Node3D
var _river_mesh: MeshInstance3D
var _baseline_visible_material: ShaderMaterial
var _review_camera: Camera3D
var _demo_review_camera: Camera3D
var _camera_mode := CAMERA_MODE_OVERHEAD
var _camera_yaw := 0.0
var _camera_pitch := -0.45
var _mouse_look_pressed := false
var _status_label: Label
var _last_status := "Loading field/emitter demo..."
var _setup_complete := false
var _debug_view := DEBUG_VIEW_NORMAL
var _moving_emitters_enabled := true
var _moving_path_world := []
var _moving_time := 0.0
var _marker_root: Node3D
var _ripple_bounds := AABB()
var _ripple_focus := Vector3.ZERO
var _emitter_anchor_positions := {}


func _ready() -> void:
	_build_overlay()
	call_deferred("_setup_review")


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _target_river != null and is_instance_valid(_target_river):
		_target_river.call("set_debug_view", DEBUG_VIEW_NORMAL)
	if _field != null and is_instance_valid(_field):
		_field.set("enabled", false)
		_field.call("cleanup_runtime")


func _process(delta: float) -> void:
	if not _setup_complete:
		return
	_update_moving_emitter(delta)
	_sync_authoring_markers()
	_move_review_camera(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_SPACE:
			set_field_enabled(not is_field_enabled())
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F:
			fire_emitters_once()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_M:
			set_moving_emitters_enabled(not _moving_emitters_enabled)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_0:
			set_debug_view_mode(DEBUG_VIEW_NORMAL)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_4:
			set_debug_view_mode(DEBUG_VIEW_RIPPLE_RAW_HEIGHT)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_5:
			set_debug_view_mode(DEBUG_VIEW_RIPPLE_IMPULSE_CONTACT)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_6:
			set_debug_view_mode(DEBUG_VIEW_RIPPLE_BOUNDARY_MASK)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_7:
			set_debug_view_mode(DEBUG_VIEW_RIPPLE_VISIBLE_INFLUENCE)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_C:
			cycle_review_camera_mode()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_R:
			reset_review()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_look_pressed = mouse_event.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _mouse_look_pressed else Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_zoom_review_camera(-1.0)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_zoom_review_camera(1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_look_pressed:
		_rotate_review_camera((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()


func get_review_status() -> Dictionary:
	var field_snapshot := _field.call("get_field_snapshot") if _field != null and is_instance_valid(_field) else {}
	return {
		"setup_complete": _setup_complete,
		"last_status": _last_status,
		"target_river_found": _target_river != null and is_instance_valid(_target_river),
		"terrain_found": _terrain != null and is_instance_valid(_terrain),
		"field_found": _field != null and is_instance_valid(_field),
		"field_enabled": is_field_enabled(),
		"field_snapshot": field_snapshot,
		"target_has_runtime_state": _target_river != null and bool(_target_river.call("has_runtime_ripple_material_state")),
		"target_has_field_runtime_state": _target_river != null and _field != null and bool(_target_river.call("has_runtime_ripple_material_state", _field)),
		"baseline_material_restored": is_baseline_material_restored(),
		"current_material_is_runtime_duplicate": _current_material_is_runtime_duplicate(),
		"debug_view": _debug_view,
		"debug_view_label": _debug_view_label(),
		"camera_mode": _get_camera_mode_name(),
		"review_camera_current": _review_camera != null and _review_camera.current,
		"moving_emitters_enabled": _moving_emitters_enabled,
		"emitter_reports": get_emitter_reports(),
		"moving_path_reports": get_moving_path_reports(),
		"runtime_flow_speed": _get_active_shader_parameter("flow_speed"),
		"bounds": _ripple_bounds,
		"focus": _ripple_focus,
	}


func get_target_river() -> Node:
	return _target_river


func get_field() -> Node3D:
	return _field


func get_configured_emitters() -> Array[Node]:
	var emitters: Array[Node] = []
	if _field == null:
		return emitters
	for child in _field.get_children():
		if child is Node3D and child.has_method("emit_once"):
			emitters.append(child)
	return emitters


func get_emitter_reports() -> Array:
	var reports := []
	if _field == null:
		return reports
	for emitter in get_configured_emitters():
		var emitter_node := emitter as Node3D
		var expected_uv := EMITTER_EXPECTED_UVS.get(String(emitter_node.name), Vector2.INF) as Vector2
		var actual_uv := _field.call("world_position_to_ripple_uv", emitter_node.global_position) as Vector2
		var water_anchor := _find_nearest_mesh_world_position_for_uv(actual_uv)
		if water_anchor == Vector3.INF:
			water_anchor = _emitter_anchor_positions.get(String(emitter_node.name), emitter_node.global_position) as Vector3
		var display_terrain_height := _sample_terrain_height(emitter_node.global_position)
		var water_terrain_height := _sample_terrain_height(water_anchor)
		var marker_position := _get_marker_position_for_emitter(String(emitter_node.name))
		var marker_terrain_height := _sample_terrain_height(marker_position)
		var snapshot: Dictionary = emitter.call("get_emitter_snapshot")
		reports.append({
			"name": String(emitter_node.name),
			"world_position": emitter_node.global_position,
			"water_anchor_position": water_anchor,
			"marker_position": marker_position,
			"expected_uv": expected_uv,
			"actual_uv": actual_uv,
			"uv_error": actual_uv.distance_to(expected_uv) if expected_uv != Vector2.INF else -1.0,
			"in_bounds": actual_uv.x >= 0.0 and actual_uv.y >= 0.0 and actual_uv.x <= 1.0 and actual_uv.y <= 1.0,
			"terrain_sample_available": _terrain_height_available(display_terrain_height) and _terrain_height_available(water_terrain_height),
			"display_terrain_height": display_terrain_height,
			"water_terrain_height": water_terrain_height,
			"marker_terrain_height": marker_terrain_height,
			"display_terrain_clearance": emitter_node.global_position.y - display_terrain_height if _terrain_height_available(display_terrain_height) else INF,
			"water_terrain_clearance": water_anchor.y - water_terrain_height if _terrain_height_available(water_terrain_height) else INF,
			"marker_terrain_clearance": marker_position.y - marker_terrain_height if _terrain_height_available(marker_terrain_height) else INF,
			"enabled": bool(snapshot.get("enabled", false)),
			"mode": int(snapshot.get("mode", -1)),
			"emit_count": int(snapshot.get("emit_count", 0)),
			"rejected_count": int(snapshot.get("rejected_count", 0)),
			"radius": float(snapshot.get("radius", 0.0)),
			"intensity": float(snapshot.get("intensity", 0.0)),
			"pulse_rate": float(emitter.get("pulse_rate")),
			"moving_emit_distance": float(emitter.get("moving_emit_distance")),
			"priority": int(snapshot.get("priority", 0)),
		})
	return reports


func get_moving_path_reports() -> Array:
	var reports := []
	for display_position in _moving_path_world:
		var actual_uv := _field.call("world_position_to_ripple_uv", display_position) as Vector2
		var water_anchor := _find_nearest_mesh_world_position_for_uv(actual_uv)
		if water_anchor == Vector3.INF:
			water_anchor = display_position
		var display_terrain_height := _sample_terrain_height(display_position)
		var water_terrain_height := _sample_terrain_height(water_anchor)
		reports.append({
			"display_position": display_position,
			"water_anchor_position": water_anchor,
			"actual_uv": actual_uv,
			"in_bounds": actual_uv.x >= 0.0 and actual_uv.y >= 0.0 and actual_uv.x <= 1.0 and actual_uv.y <= 1.0,
			"terrain_sample_available": _terrain_height_available(display_terrain_height) and _terrain_height_available(water_terrain_height),
			"display_terrain_clearance": display_position.y - display_terrain_height if _terrain_height_available(display_terrain_height) else INF,
			"water_terrain_clearance": water_anchor.y - water_terrain_height if _terrain_height_available(water_terrain_height) else INF,
		})
	return reports


func is_field_enabled() -> bool:
	return _field != null and bool(_field.get("enabled"))


func set_field_enabled(value: bool) -> void:
	if _field == null:
		return
	_field.set("enabled", value)
	for emitter in get_configured_emitters():
		emitter.set("enabled", value)
	if value:
		_field.call("initialize_runtime")
		_set_status("Field on. Press F for a manual pulse, Space to disable.")
	else:
		_set_status("Field off. River should match its baseline material state.")


func set_moving_emitters_enabled(value: bool) -> void:
	_moving_emitters_enabled = value
	var moving := _get_moving_emitter()
	if moving != null:
		moving.set("enabled", value and is_field_enabled())
	_set_status("Moving emitter " + ("on." if value else "off."))


func fire_emitters_once() -> int:
	if not _setup_complete or _field == null or not is_field_enabled():
		_set_status("Enable the field before firing emitters.")
		return 0
	var accepted_count := 0
	for emitter in get_configured_emitters():
		if bool(emitter.call("emit_once")):
			accepted_count += 1
	_set_status("Queued " + str(accepted_count) + " emitter impulses.")
	return accepted_count


func set_debug_view_mode(debug_view: int) -> void:
	_debug_view = debug_view
	if _target_river != null and is_instance_valid(_target_river):
		_target_river.call("set_debug_view", _debug_view)
	_set_status("Debug view: " + _debug_view_label())


func cycle_review_camera_mode() -> void:
	if _camera_mode == CAMERA_MODE_OVERHEAD:
		_camera_mode = CAMERA_MODE_OBLIQUE
	elif _camera_mode == CAMERA_MODE_OBLIQUE and _demo_review_camera != null:
		_camera_mode = CAMERA_MODE_DEMO
	else:
		_camera_mode = CAMERA_MODE_OVERHEAD
	_set_review_camera()


func reset_review() -> void:
	if _field != null:
		_field.call("reset_feedback")
	_set_review_camera()
	fire_emitters_once()


func is_baseline_material_restored() -> bool:
	if _target_river == null or _baseline_visible_material == null:
		return false
	return _get_active_shader_material() == _baseline_visible_material and not bool(_target_river.call("has_runtime_ripple_material_state"))


func _setup_review() -> void:
	await _settle_frames(4)
	_target_river = get_node_or_null(TARGET_RIVER_PATH)
	_terrain = get_node_or_null(TERRAIN_PATH)
	_field = get_node_or_null(FIELD_PATH) as Node3D
	if _target_river == null:
		_set_status("Could not find " + TARGET_RIVER_PATH)
		return
	if _field == null:
		_set_status("Could not find " + FIELD_PATH)
		return

	_river_mesh = _get_river_mesh_instance()
	if _river_mesh == null or _river_mesh.mesh == null:
		_set_status("Demo river mesh is not available for field authoring.")
		return

	_baseline_visible_material = _get_active_shader_material()
	_ripple_bounds = _river_mesh.global_transform * _river_mesh.get_aabb()
	_ripple_focus = _build_ripple_focus()
	_configure_field_from_demo_river()
	_configure_emitters_from_demo_river()
	_build_authoring_markers()
	_set_review_camera()

	_setup_complete = true
	set_field_enabled(true)
	await _settle_frames(3)
	fire_emitters_once()


func _configure_field_from_demo_river() -> void:
	_field.set("enabled", false)
	_field.set("resolution", FIELD_RESOLUTION)
	_field.set("world_bounds", _ripple_bounds)
	var target_paths: Array[NodePath] = []
	target_paths.append(_field.get_path_to(_target_river))
	_field.set("target_river_paths", target_paths)
	var boundary_paths: Array[NodePath] = []
	boundary_paths.append(_field.get_path_to(_river_mesh))
	_field.set("boundary_source_paths", boundary_paths)
	_field.set("require_boundary_mask", true)
	_field.set("auto_generate_boundary_mask", true)
	_field.set("ripple_strength", REVIEW_RIPPLE_STRENGTH)
	_field.set("normal_strength", REVIEW_NORMAL_STRENGTH)
	_field.set("refraction_strength", 0.0)
	_field.set("displacement_strength", 0.0)


func _configure_emitters_from_demo_river() -> void:
	_emitter_anchor_positions.clear()
	for emitter in get_configured_emitters():
		var emitter_node := emitter as Node3D
		emitter.set("enabled", false)
		emitter.set("target_field_path", emitter_node.get_path_to(_field))
		var expected_uv := EMITTER_EXPECTED_UVS.get(String(emitter_node.name), Vector2.INF) as Vector2
		if expected_uv != Vector2.INF:
			var water_anchor := _find_visible_mesh_world_position_for_uv(expected_uv)
			if water_anchor != Vector3.INF:
				_emitter_anchor_positions[String(emitter_node.name)] = water_anchor
				emitter_node.global_position = _build_emitter_display_position(water_anchor)
	_moving_path_world.clear()
	for path_index in range(MOVING_PATH_UVS.size()):
		var from_uv := MOVING_PATH_UVS[path_index] as Vector2
		var to_uv := MOVING_PATH_UVS[(path_index + 1) % MOVING_PATH_UVS.size()] as Vector2
		for step in range(MOVING_PATH_SEGMENT_STEPS):
			var local_t := float(step) / float(MOVING_PATH_SEGMENT_STEPS)
			var sampled_uv := from_uv.lerp(to_uv, local_t)
			var water_anchor := _find_visible_mesh_world_position_for_uv(sampled_uv)
			if water_anchor != Vector3.INF:
				_moving_path_world.append(_build_emitter_display_position(water_anchor))


func _build_authoring_markers() -> void:
	if _marker_root != null:
		_marker_root.queue_free()
	_marker_root = Node3D.new()
	_marker_root.name = "RuntimeEmitterPositionMarkers"
	add_child(_marker_root)

	var colors := [
		Color(0.15, 0.7, 1.0, 1.0),
		Color(0.3, 1.0, 0.45, 1.0),
		Color(1.0, 0.55, 0.12, 1.0),
	]
	var index := 0
	for emitter in get_configured_emitters():
		var emitter_node := emitter as Node3D
		var marker := MeshInstance3D.new()
		marker.name = String(emitter_node.name) + "_Marker"
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		marker.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[index % colors.size()]
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 1.2
		marker.material_override = material
		marker.set_meta("emitter_name", String(emitter_node.name))
		_marker_root.add_child(marker)
		index += 1
	_sync_authoring_markers()


func _sync_authoring_markers() -> void:
	if _marker_root == null or _field == null:
		return
	for child in _marker_root.get_children():
		var marker := child as Node3D
		if marker == null or not marker.has_meta("emitter_name"):
			continue
		var emitter := _field.get_node_or_null(String(marker.get_meta("emitter_name"))) as Node3D
		if emitter == null:
			continue
		marker.global_position = emitter.global_position + Vector3(0.0, MARKER_VERTICAL_OFFSET, 0.0)


func _update_moving_emitter(delta: float) -> void:
	if not _moving_emitters_enabled or _moving_path_world.size() < 2:
		return
	var moving := _get_moving_emitter()
	if moving == null:
		return
	_moving_time += max(delta, 0.0)
	var phase := fposmod(_moving_time / MOVING_PATH_SECONDS, 1.0)
	var scaled := phase * float(_moving_path_world.size())
	var index := int(floor(scaled)) % _moving_path_world.size()
	var next_index := (index + 1) % _moving_path_world.size()
	var local_t: float = scaled - floor(scaled)
	moving.global_position = (_moving_path_world[index] as Vector3).lerp(_moving_path_world[next_index] as Vector3, local_t)


func _get_moving_emitter() -> Node3D:
	if _field == null:
		return null
	return _field.get_node_or_null("MovingEmitter_TestTrail") as Node3D


func _set_review_camera() -> void:
	_demo_review_camera = get_node_or_null(DEMO_CAMERA_PATH) as Camera3D
	if _review_camera == null:
		_review_camera = get_node_or_null(REVIEW_CAMERA_NAME) as Camera3D
	if _review_camera == null:
		_review_camera = Camera3D.new()
		_review_camera.name = REVIEW_CAMERA_NAME
		add_child(_review_camera)

	if _camera_mode == CAMERA_MODE_DEMO and _demo_review_camera != null:
		_demo_review_camera.current = true
		_set_status("Demo camera active.")
		return

	_review_camera.current = true
	_review_camera.near = 0.05
	_review_camera.far = 500.0
	var horizontal_span := max(_ripple_bounds.size.x, _ripple_bounds.size.z)
	if _camera_mode == CAMERA_MODE_OVERHEAD:
		_review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_review_camera.size = clamp(horizontal_span * 0.22, 9.0, 16.0)
		_review_camera.global_position = _ripple_focus + Vector3(0.0, clamp(horizontal_span * 0.35, 18.0, 32.0), 0.0)
		_review_camera.look_at(_ripple_focus, Vector3.FORWARD)
		_sync_camera_angles_from_current_transform()
		_set_status("Close overhead camera active.")
		return

	_review_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_review_camera.fov = 42.0
	var distance := clamp(horizontal_span * 0.14, 7.0, 12.0)
	var height := clamp(horizontal_span * 0.10, 5.0, 9.0)
	_review_camera.global_position = _ripple_focus + Vector3(-distance * 0.55, height, -distance)
	_review_camera.look_at(_ripple_focus, Vector3.UP)
	_sync_camera_angles_from_current_transform()
	_set_status("Close oblique camera active.")


func _build_ripple_focus() -> Vector3:
	var focus := Vector3.ZERO
	var count := 0
	for uv in EMITTER_EXPECTED_UVS.values():
		var world_position := _find_visible_mesh_world_position_for_uv(uv as Vector2)
		if world_position != Vector3.INF:
			focus += world_position
			count += 1
	if count > 0:
		return focus / float(count)
	return _ripple_bounds.get_center()


func _find_visible_mesh_world_position_for_uv(target_uv: Vector2) -> Vector3:
	if _river_mesh == null or _river_mesh.mesh == null:
		return Vector3.INF
	var world_to_uv: Transform3D = _field.call("get_world_to_ripple_uv") if _field != null else _build_world_to_ripple_uv(_ripple_bounds)
	var best_visible_world_position := Vector3.INF
	var best_visible_distance := INF
	var best_fallback_world_position := Vector3.INF
	var best_fallback_distance := INF
	for surface_index in range(_river_mesh.mesh.get_surface_count()):
		var arrays := _river_mesh.mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex in vertices:
			var world_position := _river_mesh.global_transform * vertex
			var mapped := world_to_uv * world_position
			var uv := Vector2(mapped.x, mapped.z)
			var distance := uv.distance_squared_to(target_uv)
			if distance < best_fallback_distance:
				best_fallback_distance = distance
				best_fallback_world_position = world_position
			if not _water_point_is_exposed(world_position):
				continue
			if distance < best_visible_distance:
				best_visible_distance = distance
				best_visible_world_position = world_position
	if best_visible_world_position != Vector3.INF:
		return best_visible_world_position
	return best_fallback_world_position


func _find_nearest_mesh_world_position_for_uv(target_uv: Vector2) -> Vector3:
	if _river_mesh == null or _river_mesh.mesh == null:
		return Vector3.INF
	var world_to_uv: Transform3D = _field.call("get_world_to_ripple_uv") if _field != null else _build_world_to_ripple_uv(_ripple_bounds)
	var best_world_position := Vector3.INF
	var best_distance := INF
	for surface_index in range(_river_mesh.mesh.get_surface_count()):
		var arrays := _river_mesh.mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex in vertices:
			var world_position := _river_mesh.global_transform * vertex
			var mapped := world_to_uv * world_position
			var uv := Vector2(mapped.x, mapped.z)
			var distance := uv.distance_squared_to(target_uv)
			if distance < best_distance:
				best_distance = distance
				best_world_position = world_position
	return best_world_position


func _water_point_is_exposed(world_position: Vector3) -> bool:
	var terrain_height := _sample_terrain_height(world_position)
	if not _terrain_height_available(terrain_height):
		return true
	return world_position.y >= terrain_height + MIN_VISIBLE_WATER_TERRAIN_CLEARANCE


func _build_emitter_display_position(water_anchor: Vector3) -> Vector3:
	var display_y := water_anchor.y + EMITTER_DISPLAY_HEIGHT_ABOVE_WATER
	var terrain_height := _sample_terrain_height(water_anchor)
	if _terrain_height_available(terrain_height):
		display_y = max(display_y, terrain_height + EMITTER_DISPLAY_TERRAIN_CLEARANCE)
	return Vector3(water_anchor.x, display_y, water_anchor.z)


func _sample_terrain_height(world_position: Vector3) -> float:
	if _terrain == null or not is_instance_valid(_terrain):
		return TERRAIN_HEIGHT_UNAVAILABLE
	if not _terrain.has_method("get_data") or not _terrain.has_method("world_to_map") or not _terrain.has_method("get_internal_transform"):
		return TERRAIN_HEIGHT_UNAVAILABLE
	var terrain_data: Object = _terrain.call("get_data")
	if terrain_data == null or not terrain_data.has_method("get_interpolated_height_at"):
		return TERRAIN_HEIGHT_UNAVAILABLE
	var map_position: Vector3 = _terrain.call("world_to_map", world_position)
	var raw_height := float(terrain_data.call("get_interpolated_height_at", map_position))
	var terrain_transform: Transform3D = _terrain.call("get_internal_transform")
	var terrain_world_position := terrain_transform * Vector3(map_position.x, raw_height, map_position.z)
	return terrain_world_position.y


func _terrain_height_available(terrain_height: float) -> bool:
	return terrain_height != TERRAIN_HEIGHT_UNAVAILABLE


func _get_marker_position_for_emitter(emitter_name: String) -> Vector3:
	if _marker_root == null:
		return Vector3.INF
	for child in _marker_root.get_children():
		var marker := child as Node3D
		if marker != null and marker.has_meta("emitter_name") and String(marker.get_meta("emitter_name")) == emitter_name:
			return marker.global_position
	return Vector3.INF


func _get_river_mesh_instance() -> MeshInstance3D:
	if _target_river == null:
		return null
	var direct_mesh := _target_river.get("mesh_instance") as MeshInstance3D
	if direct_mesh != null:
		return direct_mesh
	return _target_river.get_node_or_null("RiverMeshInstance") as MeshInstance3D


func _get_active_shader_material() -> ShaderMaterial:
	var mesh_instance := _get_river_mesh_instance()
	if mesh_instance == null:
		return null
	var active_material := mesh_instance.get_active_material(0) as ShaderMaterial
	if active_material != null:
		return active_material
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	return null


func _get_active_shader_parameter(parameter_name: String) -> Variant:
	var material := _get_active_shader_material()
	if material == null:
		return null
	return material.get_shader_parameter(parameter_name)


func _current_material_is_runtime_duplicate() -> bool:
	if _target_river == null or _baseline_visible_material == null:
		return false
	if not bool(_target_river.call("has_runtime_ripple_material_state")):
		return false
	return _get_active_shader_material() != _baseline_visible_material


func _build_world_to_ripple_uv(bounds: AABB) -> Transform3D:
	var safe_size := bounds.size
	safe_size.x = max(safe_size.x, 1.0)
	safe_size.y = max(safe_size.y, 1.0)
	safe_size.z = max(safe_size.z, 1.0)
	var basis := Basis(
		Vector3(1.0 / safe_size.x, 0.0, 0.0),
		Vector3(0.0, 1.0 / safe_size.y, 0.0),
		Vector3(0.0, 0.0, 1.0 / safe_size.z)
	)
	return Transform3D(basis, basis * -bounds.position)


func _move_review_camera(delta: float) -> void:
	if _review_camera == null or not _review_camera.current:
		return
	var move := Vector3.ZERO
	var forward := -_review_camera.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length() < 0.001 else forward.normalized()
	var right := _review_camera.global_transform.basis.x
	right.y = 0.0
	right = Vector3.RIGHT if right.length() < 0.001 else right.normalized()

	if Input.is_key_pressed(KEY_W):
		move += forward
	if Input.is_key_pressed(KEY_S):
		move -= forward
	if Input.is_key_pressed(KEY_A):
		move -= right
	if Input.is_key_pressed(KEY_D):
		move += right
	if Input.is_key_pressed(KEY_E):
		move += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		move -= Vector3.UP
	if move == Vector3.ZERO:
		return

	var speed := CAMERA_MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= CAMERA_FAST_MULTIPLIER
	_review_camera.global_position += move.normalized() * speed * delta


func _rotate_review_camera(relative: Vector2) -> void:
	if _review_camera == null or not _review_camera.current:
		return
	_camera_yaw -= relative.x * MOUSE_LOOK_SENSITIVITY
	_camera_pitch = clamp(_camera_pitch - relative.y * MOUSE_LOOK_SENSITIVITY, -MAX_CAMERA_PITCH, MAX_CAMERA_PITCH)
	_review_camera.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)


func _sync_camera_angles_from_current_transform() -> void:
	if _review_camera == null:
		return
	_camera_yaw = _review_camera.rotation.y
	_camera_pitch = _review_camera.rotation.x
	_review_camera.rotation.z = 0.0


func _zoom_review_camera(direction: float) -> void:
	if _review_camera == null or not _review_camera.current:
		return
	if _review_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_review_camera.size = max(_review_camera.size / CAMERA_ZOOM_STEP, 2.0) if direction < 0.0 else min(_review_camera.size * CAMERA_ZOOM_STEP, 80.0)
		return
	var forward := -_review_camera.global_transform.basis.z.normalized()
	_review_camera.global_position += forward * (-direction) * CAMERA_ZOOM_STEP * 2.0


func _get_camera_mode_name() -> String:
	if _camera_mode == CAMERA_MODE_OVERHEAD:
		return "close overhead"
	if _camera_mode == CAMERA_MODE_DEMO:
		return "demo overhead"
	return "close oblique"


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "RippleReviewOverlay"
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 16.0)
	_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_status_label)
	_set_status(_last_status)


func _set_status(status: String) -> void:
	_last_status = status
	if _status_label != null:
		_status_label.text = status + "\nSelect WaterRippleField or its emitter children to inspect the authoring setup.\nSpace field on/off. F pulse. M moving emitter. 0 normal. 4 raw. 5 contact. 6 boundary. 7 influence. C camera. R reset. WASD/QE move. Right mouse look. Wheel zoom."


func _debug_view_label() -> String:
	match _debug_view:
		DEBUG_VIEW_RIPPLE_RAW_HEIGHT:
			return "raw ripple height"
		DEBUG_VIEW_RIPPLE_IMPULSE_CONTACT:
			return "impulse/contact"
		DEBUG_VIEW_RIPPLE_BOUNDARY_MASK:
			return "boundary mask"
		DEBUG_VIEW_RIPPLE_VISIBLE_INFLUENCE:
			return "visible influence"
		_:
			return "visible river"


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
