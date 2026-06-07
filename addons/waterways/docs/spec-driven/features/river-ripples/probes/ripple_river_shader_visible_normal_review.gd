extends Node3D

const DEMO_SCENE_PATH := "res://Demo.tscn"
const TARGET_RIVER_PATH := "WaterSystem/Water River"
const REVIEW_CAMERA_PATH := "Phase0B Review Cameras/Phase0B_UpperRiver_Overhead"
const REVIEW_CAMERA_NAME := "RippleReviewCamera"
const RIPPLE_SIZE := 256
const FALLBACK_RIPPLE_CENTERS := [
	Vector2(0.34, 0.42),
	Vector2(0.58, 0.54),
	Vector2(0.44, 0.70),
]
const REVIEW_CENTER_QUANTILES := [0.46, 0.50, 0.54]
const REVIEW_CENTER_MIN_UV_DISTANCE := 0.045
const RIPPLE_ANIMATION_FRAME_COUNT := 48
const RIPPLE_PULSE_PERIOD := 2.6
const RIPPLE_START_RADIUS := 0.018
const RIPPLE_END_RADIUS := 0.135
const RIPPLE_RING_WIDTH := 0.014
const RIPPLE_WAVE_AMPLITUDE := 0.20
const CAMERA_MODE_OBLIQUE := 0
const CAMERA_MODE_OVERHEAD := 1
const CAMERA_MODE_DEMO := 2
const CAMERA_MOVE_SPEED := 12.0
const CAMERA_FAST_MULTIPLIER := 3.0
const CAMERA_ZOOM_STEP := 1.25
const MOUSE_LOOK_SENSITIVITY := 0.0035
const MAX_CAMERA_PITCH := 1.35
const DEBUG_VIEW_NORMAL := 0
const DEBUG_VIEW_RIPPLE_RAW_HEIGHT := 62
const DEBUG_VIEW_RIPPLE_IMPULSE_CONTACT := 63
const DEBUG_VIEW_RIPPLE_BOUNDARY_MASK := 64
const DEBUG_VIEW_RIPPLE_VISIBLE_INFLUENCE := 65

var _demo_scene: Node
var _target_river: Node
var _ripple_texture: Texture2D
var _ripple_textures: Array[Texture2D] = []
var _impulse_texture: Texture2D
var _boundary_texture: Texture2D
var _world_to_ripple_uv := Transform3D.IDENTITY
var _ripple_centers := FALLBACK_RIPPLE_CENTERS.duplicate()
var _ripple_center_world_positions := []
var _ripple_focus := Vector3.ZERO
var _ripple_bounds := AABB()
var _review_camera: Camera3D
var _demo_review_camera: Camera3D
var _camera_mode := CAMERA_MODE_OVERHEAD
var _ripples_enabled := true
var _normal_strength := 1.25
var _debug_view := DEBUG_VIEW_NORMAL
var _ripple_animation_time := 0.0
var _ripple_texture_frame := 0
var _ripple_texture_frame_index := 0
var _ripple_image_generation_count := 0
var _mouse_look_pressed := false
var _camera_yaw := 0.0
var _camera_pitch := -0.45
var _status_label: Label
var _setup_complete := false
var _last_status := "Loading demo..."


func _ready() -> void:
	_build_overlay()
	call_deferred("_setup_review")


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _target_river != null and is_instance_valid(_target_river):
		_target_river.call("set_debug_view", DEBUG_VIEW_NORMAL)
		_target_river.call("clear_runtime_ripple_material_state", self)


func _process(delta: float) -> void:
	if _review_camera == null or not _review_camera.current:
		return
	if _setup_complete and _ripples_enabled:
		_advance_ripple_texture(delta)
	_move_review_camera(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_SPACE:
			set_ripples_enabled(not _ripples_enabled)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_1:
			set_normal_strength(1.25)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_2:
			set_normal_strength(2.0)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_3:
			set_normal_strength(4.0)
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
			_set_review_camera(_ripple_bounds)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_look_pressed = mouse_event.pressed
			if _mouse_look_pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_zoom_review_camera(-1.0)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_zoom_review_camera(1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _mouse_look_pressed:
			_rotate_review_camera((event as InputEventMouseMotion).relative)
			get_viewport().set_input_as_handled()


func set_ripples_enabled(enabled: bool) -> void:
	_ripples_enabled = enabled
	_apply_or_clear_runtime_state()


func set_normal_strength(strength: float) -> void:
	_normal_strength = max(strength, 0.0)
	_apply_or_clear_runtime_state()


func set_debug_view_mode(debug_view: int) -> void:
	_debug_view = debug_view
	if _target_river != null and is_instance_valid(_target_river):
		_target_river.call("set_debug_view", _debug_view)
	_set_status(_debug_view_status())


func get_review_status() -> Dictionary:
	return {
		"setup_complete": _setup_complete,
		"ripples_enabled": _ripples_enabled,
		"normal_strength": _normal_strength,
		"debug_view": _debug_view,
		"debug_view_label": _debug_view_label(),
		"last_status": _last_status,
		"target_river_found": _target_river != null and is_instance_valid(_target_river),
		"camera_mode": _get_camera_mode_name(),
		"review_camera_current": _review_camera != null and _review_camera.current,
		"ripple_center_count": _ripple_centers.size(),
		"ripple_texture_frame": _ripple_texture_frame,
		"ripple_texture_frame_index": _ripple_texture_frame_index,
		"ripple_precomputed_frame_count": _ripple_textures.size(),
		"ripple_image_generation_count": _ripple_image_generation_count,
		"ripple_animation_time": _ripple_animation_time,
		"impulse_texture_size": _impulse_texture.get_size() if _impulse_texture != null else Vector2i.ZERO,
		"boundary_texture_size": _boundary_texture.get_size() if _boundary_texture != null else Vector2i.ZERO,
		"runtime_flow_speed": _get_active_shader_parameter("flow_speed"),
	}


func get_target_river() -> Node:
	return _target_river


func _setup_review() -> void:
	_demo_scene = _get_or_instantiate_demo_scene()
	if _demo_scene == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_target_river = _demo_scene.get_node_or_null(TARGET_RIVER_PATH)
	if _target_river == null:
		_set_status("Could not find demo river at " + TARGET_RIVER_PATH)
		return

	var mesh_instance := _get_river_mesh_instance()
	if mesh_instance == null or mesh_instance.mesh == null:
		_set_status("Demo river mesh is not available for ripple review.")
		return

	_ripple_bounds = mesh_instance.global_transform * mesh_instance.get_aabb()
	_world_to_ripple_uv = _build_world_to_ripple_uv(_ripple_bounds)
	_choose_ripple_centers_from_mesh(mesh_instance)
	_ripple_focus = _build_ripple_focus(_ripple_bounds)
	_build_ripple_texture_frames()
	_build_impulse_texture()
	_boundary_texture = _create_solid_texture(Color.WHITE, RIPPLE_SIZE)
	_set_review_camera(_ripple_bounds)
	_setup_complete = true
	_apply_or_clear_runtime_state()


func _apply_or_clear_runtime_state() -> void:
	if _target_river == null or not is_instance_valid(_target_river):
		return
	if not _ripples_enabled:
		_target_river.call("clear_runtime_ripple_material_state", self)
		_set_status("Ripples off. Space toggles, 1/2/3 changes strength.")
		return

	var accepted := bool(_target_river.call("apply_runtime_ripple_material_state", self, {
		"i_ripple_enabled": true,
		"i_ripple_simulation_texture": _ripple_texture,
		"i_ripple_impulse_texture": _impulse_texture,
		"i_ripple_world_to_uv": _world_to_ripple_uv,
		"i_ripple_boundary_mask": _boundary_texture,
		"i_ripple_texel_size": Vector2(1.0 / float(RIPPLE_SIZE), 1.0 / float(RIPPLE_SIZE)),
		"i_ripple_normal_strength": _normal_strength,
		"i_ripple_refraction_strength": 0.0,
		"i_ripple_displacement_strength": 0.0,
		"i_ripple_height_fade_distance": 0.0,
		"i_ripple_boundary_fade": 0.02,
	}))
	if accepted:
		_target_river.call("set_debug_view", _debug_view)
		_set_status("Ripples on. Strength: " + str(_normal_strength))
	else:
		_set_status("Demo river rejected runtime ripple material state.")


func cycle_review_camera_mode() -> void:
	if _camera_mode == CAMERA_MODE_OBLIQUE:
		_camera_mode = CAMERA_MODE_OVERHEAD
	elif _camera_mode == CAMERA_MODE_OVERHEAD and _demo_review_camera != null:
		_camera_mode = CAMERA_MODE_DEMO
	else:
		_camera_mode = CAMERA_MODE_OBLIQUE
	_set_review_camera(_ripple_bounds)


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
	var material := mesh_instance.get_active_material(0) as ShaderMaterial
	if material == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		material = mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	return material


func _get_active_shader_parameter(parameter_name: String) -> Variant:
	var material := _get_active_shader_material()
	if material == null:
		return null
	return material.get_shader_parameter(parameter_name)


func _get_or_instantiate_demo_scene() -> Node:
	var existing_scene := get_node_or_null("World")
	if existing_scene != null:
		return existing_scene

	var packed_scene := load(DEMO_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_set_status("Could not load " + DEMO_SCENE_PATH)
		return null

	var scene := packed_scene.instantiate()
	add_child(scene)
	return scene


func _set_review_camera(bounds: AABB) -> void:
	if _demo_scene == null:
		return
	_demo_review_camera = _demo_scene.get_node_or_null(REVIEW_CAMERA_PATH) as Camera3D
	if _review_camera == null:
		_review_camera = get_node_or_null(REVIEW_CAMERA_NAME) as Camera3D
	if _review_camera == null:
		_review_camera = Camera3D.new()
		_review_camera.name = REVIEW_CAMERA_NAME
		add_child(_review_camera)

	if _camera_mode == CAMERA_MODE_DEMO and _demo_review_camera != null:
		_demo_review_camera.current = true
		return

	if bounds.size == Vector3.ZERO:
		return
	_review_camera.current = true
	_review_camera.near = 0.05
	_review_camera.far = 500.0

	var horizontal_span := max(bounds.size.x, bounds.size.z)
	if _camera_mode == CAMERA_MODE_OVERHEAD:
		_review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_review_camera.size = clamp(horizontal_span * 0.2, 8.0, 14.0)
		_review_camera.global_position = _ripple_focus + Vector3(0.0, clamp(horizontal_span * 0.35, 18.0, 32.0), 0.0)
		_review_camera.look_at(_ripple_focus, Vector3.FORWARD)
		_sync_camera_angles_from_current_transform()
		return

	_review_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_review_camera.fov = 42.0
	var distance := clamp(horizontal_span * 0.14, 7.0, 12.0)
	var height := clamp(horizontal_span * 0.10, 5.0, 9.0)
	_review_camera.global_position = _ripple_focus + Vector3(-distance * 0.55, height, -distance)
	_review_camera.look_at(_ripple_focus, Vector3.UP)
	_sync_camera_angles_from_current_transform()


func _build_ripple_focus(bounds: AABB) -> Vector3:
	if not _ripple_center_world_positions.is_empty():
		var world_focus := Vector3.ZERO
		for world_position in _ripple_center_world_positions:
			world_focus += world_position as Vector3
		return world_focus / float(_ripple_center_world_positions.size())

	var center_uv := _average_ripple_center()
	return Vector3(
		bounds.position.x + bounds.size.x * center_uv.x,
		bounds.position.y + bounds.size.y * 0.55,
		bounds.position.z + bounds.size.z * center_uv.y
	)


func _choose_ripple_centers_from_mesh(mesh_instance: MeshInstance3D) -> void:
	var candidates := []
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex in vertices:
			var world_position := mesh_instance.global_transform * vertex
			var uv := _world_position_to_ripple_uv(world_position)
			if uv.x <= 0.06 or uv.x >= 0.94 or uv.y <= 0.06 or uv.y >= 0.94:
				continue
			candidates.append({
				"world_z": world_position.z,
				"uv": uv,
				"world_position": world_position,
			})

	if candidates.is_empty():
		_ripple_centers = FALLBACK_RIPPLE_CENTERS.duplicate()
		_ripple_center_world_positions.clear()
		return

	candidates.sort_custom(func(a, b): return float(a["world_z"]) < float(b["world_z"]))
	var selected := []
	for quantile in REVIEW_CENTER_QUANTILES:
		var index := clampi(roundi(float(candidates.size() - 1) * quantile), 0, candidates.size() - 1)
		_add_unique_ripple_candidate(selected, candidates[index])

	var center_index := clampi(roundi(float(candidates.size() - 1) * 0.50), 0, candidates.size() - 1)
	var max_offset := maxi(center_index, candidates.size() - 1 - center_index)
	for offset in range(max_offset + 1):
		if selected.size() >= 3:
			break
		var lower_index := center_index - offset
		if lower_index >= 0:
			_add_unique_ripple_candidate(selected, candidates[lower_index])
		if selected.size() >= 3:
			break
		var upper_index := center_index + offset
		if offset > 0 and upper_index < candidates.size():
			_add_unique_ripple_candidate(selected, candidates[upper_index])

	if selected.size() >= 3:
		_ripple_centers.clear()
		_ripple_center_world_positions.clear()
		for selected_candidate in selected:
			_ripple_centers.append(selected_candidate["uv"])
			_ripple_center_world_positions.append(selected_candidate["world_position"])
	else:
		_ripple_centers = FALLBACK_RIPPLE_CENTERS.duplicate()
		_ripple_center_world_positions.clear()


func _add_unique_ripple_candidate(selected: Array, candidate: Dictionary) -> void:
	var uv := candidate["uv"] as Vector2
	for existing_candidate in selected:
		var existing_uv := existing_candidate["uv"] as Vector2
		if existing_uv.distance_to(uv) < REVIEW_CENTER_MIN_UV_DISTANCE:
			return
	selected.append(candidate)


func _average_ripple_center() -> Vector2:
	var center_uv := Vector2.ZERO
	for ripple_center in _ripple_centers:
		center_uv += ripple_center
	center_uv /= max(float(_ripple_centers.size()), 1.0)
	return center_uv


func _world_position_to_ripple_uv(world_position: Vector3) -> Vector2:
	var mapped := _world_to_ripple_uv * world_position
	return Vector2(mapped.x, mapped.z)


func _move_review_camera(delta: float) -> void:
	var move := Vector3.ZERO
	var forward := -_review_camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := _review_camera.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()

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
		if direction < 0.0:
			_review_camera.size = max(_review_camera.size / CAMERA_ZOOM_STEP, 2.0)
		else:
			_review_camera.size = min(_review_camera.size * CAMERA_ZOOM_STEP, 80.0)
		return

	var forward := -_review_camera.global_transform.basis.z.normalized()
	_review_camera.global_position += forward * (-direction) * CAMERA_ZOOM_STEP * 2.0


func _get_camera_mode_name() -> String:
	if _camera_mode == CAMERA_MODE_OVERHEAD:
		return "close overhead"
	if _camera_mode == CAMERA_MODE_DEMO:
		return "demo overhead"
	return "close oblique"


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


func _advance_ripple_texture(delta: float) -> void:
	_ripple_animation_time += max(delta, 0.0)
	if _ripple_textures.is_empty():
		return
	var normalized_phase := fmod(_ripple_animation_time / RIPPLE_PULSE_PERIOD, 1.0)
	var frame_index := clampi(floori(normalized_phase * float(_ripple_textures.size())), 0, _ripple_textures.size() - 1)
	if frame_index == _ripple_texture_frame_index:
		return
	_set_ripple_texture_frame(frame_index)
	_push_runtime_ripple_texture()


func _build_ripple_texture_frames() -> void:
	_ripple_textures.clear()
	_ripple_image_generation_count = 0
	for frame_index in range(RIPPLE_ANIMATION_FRAME_COUNT):
		var frame_time := (float(frame_index) / float(RIPPLE_ANIMATION_FRAME_COUNT)) * RIPPLE_PULSE_PERIOD
		_ripple_textures.append(ImageTexture.create_from_image(_create_ring_image(RIPPLE_SIZE, frame_time)))
	_set_ripple_texture_frame(0)


func _set_ripple_texture_frame(frame_index: int) -> void:
	if _ripple_textures.is_empty():
		return
	_ripple_texture_frame_index = wrapi(frame_index, 0, _ripple_textures.size())
	_ripple_texture = _ripple_textures[_ripple_texture_frame_index]
	_ripple_texture_frame += 1


func _push_runtime_ripple_texture() -> void:
	if _target_river == null or not is_instance_valid(_target_river) or not _ripples_enabled:
		return
	if not bool(_target_river.call("has_runtime_ripple_material_state", self)):
		return
	_target_river.call("set_materials", "i_ripple_simulation_texture", _ripple_texture)


func _build_impulse_texture() -> void:
	_impulse_texture = ImageTexture.create_from_image(_create_impulse_image(RIPPLE_SIZE))


func _create_impulse_image(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var radius := max(RIPPLE_START_RADIUS * 1.8, 0.02)
	for y in range(size):
		for x in range(size):
			var uv := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var contact := 0.0
			for center_index in range(_ripple_centers.size()):
				var center := _ripple_centers[center_index] as Vector2
				var distance_to_center := uv.distance_to(center)
				contact = max(contact, 1.0 - smoothstep(radius * 0.55, radius, distance_to_center))
			image.set_pixel(x, y, Color(contact, contact, contact, 1.0))
	return image


func _create_ring_image(size: int, animation_time: float) -> Image:
	_ripple_image_generation_count += 1
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var wave := 0.0
			for center_index in range(_ripple_centers.size()):
				var center := _ripple_centers[center_index] as Vector2
				var distance_to_center := uv.distance_to(center)
				var phase := fmod((animation_time / RIPPLE_PULSE_PERIOD) + float(center_index) * 0.23, 1.0)
				var radius := lerp(RIPPLE_START_RADIUS, RIPPLE_END_RADIUS, phase)
				var pulse_fade := smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.72, 1.0, phase))
				var crest := exp(-pow((distance_to_center - radius) / RIPPLE_RING_WIDTH, 2.0))
				var trough := exp(-pow((distance_to_center - radius - RIPPLE_RING_WIDTH * 1.55) / (RIPPLE_RING_WIDTH * 1.2), 2.0))
				var inner_softening := 1.0 - smoothstep(0.0, RIPPLE_START_RADIUS * 0.8, distance_to_center)
				wave += (crest - trough * 0.65) * pulse_fade * (1.0 - inner_softening)
			var encoded_height := clamp(0.5 + wave * RIPPLE_WAVE_AMPLITUDE, 0.0, 1.0)
			image.set_pixel(x, y, Color(encoded_height, 0.5, 0.0, 1.0))
	return image


func _create_solid_texture(color: Color, size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
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
		_status_label.text = status + "\nSpace toggles ripples. 1/2/3 strength. 0 normal. 4 raw. 5 contact. 6 boundary. 7 influence. C camera. R reset. WASD/QE move. Hold right mouse to look. Wheel zoom."


func _debug_view_status() -> String:
	if _debug_view == DEBUG_VIEW_NORMAL:
		return "Debug view off. Runtime ripple state remains active when ripples are on."
	return "Debug view: " + _debug_view_label() + ". Press 0 to return to visible river."


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
