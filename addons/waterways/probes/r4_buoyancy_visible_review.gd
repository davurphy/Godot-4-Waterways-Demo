extends Node3D

const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")
const Buoyant = preload("res://addons/waterways/buoyant_manager.gd")

const WATER_GROUP := "r4_visible_buoyancy_systems"
const OBSERVATION_SECONDS := 6.0
const SLEEP_ARM_SECONDS := 0.25
const MAX_SLEEP_DRIFT := 0.03
const MAX_AWAKE_STREAK := 0.5
const BINDING_BODY_POSITION := Vector3(10.0, -0.5, 0.0)
const SLEEP_BODY_POSITION := Vector3(10.0, -0.25, 2.2)
const LIVE_BODY_POSITION := Vector3(10.0, 1.0, -2.2)
const NEAR_BOUNDS := AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 2.0, 6.0))
const COVERING_BOUNDS := AABB(Vector3(8.0, -1.0, -4.0), Vector3(6.0, 2.0, 8.0))

var _near_system: WaterSystem
var _covering_system: WaterSystem
var _binding_body: RigidBody3D
var _sleep_body: RigidBody3D
var _live_body: RigidBody3D
var _binding_buoyant: Node
var _sleep_buoyant: Node
var _status_label: Label
var _setup_complete := false
var _coverage_pass := false
var _sleep_timer := 0.0
var _sleep_start_position := Vector3.ZERO
var _sleep_awake_time := 0.0
var _sleep_current_awake_streak := 0.0
var _sleep_longest_awake_streak := 0.0
var _sleep_max_drift := 0.0
var _sleep_observation_complete := false
var _sleep_watch_active := false
var _sleep_watch_arming := false
var _sleep_arm_timer := 0.0


func _ready() -> void:
	_build_scene()


func _process(delta: float) -> void:
	if not _setup_complete:
		return
	_update_coverage_result()
	_update_sleep_watch(delta)
	_update_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_reset_sleep_watch()


func get_review_status() -> Dictionary:
	return {
		"setup_complete": _setup_complete,
		"coverage_pass": _coverage_pass,
		"near_covers_body": _near_system != null and _near_system.covers_world_position(BINDING_BODY_POSITION),
		"covering_covers_body": _covering_system != null and _covering_system.covers_world_position(BINDING_BODY_POSITION),
		"bound_system": _get_bound_system_name(_binding_buoyant),
		"sleep_observation_complete": _sleep_observation_complete,
		"sleep_pass": _sleep_observation_complete and _sleep_body != null and _sleep_body.sleeping and _sleep_max_drift <= MAX_SLEEP_DRIFT and _sleep_longest_awake_streak <= MAX_AWAKE_STREAK,
		"sleep_awake_time": _sleep_awake_time,
		"sleep_longest_awake_streak": _sleep_longest_awake_streak,
		"sleep_max_drift": _sleep_max_drift,
		"sleep_body_sleeping": _sleep_body != null and _sleep_body.sleeping,
		"sleep_watch_active": _sleep_watch_active,
		"sleep_watch_arming": _sleep_watch_arming,
		"live_body_sleeping": _live_body != null and _live_body.sleeping
	}


func _build_scene() -> void:
	_near_system = _make_water_system("NearOrigin_OutsideCoverage", Vector3.ZERO, NEAR_BOUNDS)
	_covering_system = _make_water_system("FarOrigin_CoveringWater", Vector3(22.0, 0.0, 0.0), COVERING_BOUNDS)
	add_child(_near_system)
	add_child(_covering_system)

	_add_coverage_volume("RedCoverage_NearOriginOutside", NEAR_BOUNDS, Color(1.0, 0.18, 0.12, 0.16))
	_add_coverage_volume("GreenCoverage_FarOriginCoversBodies", COVERING_BOUNDS, Color(0.0, 0.82, 0.38, 0.18))
	_add_water_plane("GreenWaterSurface", COVERING_BOUNDS, Color(0.12, 0.52, 1.0, 0.35))
	_add_origin_marker("Red origin\nnearer to bodies\noutside coverage", _near_system.global_position, Color(1.0, 0.18, 0.12, 1.0))
	_add_origin_marker("Green origin\nfarther away\ncoverage contains bodies", _covering_system.global_position, Color(0.0, 0.85, 0.38, 1.0))

	_binding_body = _make_body("CoverageBindingBody", BINDING_BODY_POSITION, Color(0.1, 1.0, 0.42, 1.0), true)
	_binding_buoyant = _add_buoyant(_binding_body)
	_add_label("closer to red origin\nbound to green coverage", BINDING_BODY_POSITION + Vector3(0.0, 1.0, 0.0), Color(0.8, 1.0, 0.8, 1.0))

	_sleep_body = _make_body("SettledSleepBody", SLEEP_BODY_POSITION, Color(0.26, 0.9, 1.0, 1.0), false)
	_sleep_buoyant = _add_buoyant(_sleep_body)
	_add_label("sleep watch body", SLEEP_BODY_POSITION + Vector3(0.0, 1.0, 0.0), Color(0.75, 0.95, 1.0, 1.0))

	_live_body = _make_body("LiveSettlingBody", LIVE_BODY_POSITION, Color(1.0, 0.76, 0.18, 1.0), false)
	_add_buoyant(_live_body)
	_add_label("live settling body", LIVE_BODY_POSITION + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.9, 0.6, 1.0))

	_add_floor()
	_add_lighting()
	_add_camera()
	_build_overlay()
	_setup_complete = true
	_reset_sleep_watch()


func _make_water_system(node_name: String, origin: Vector3, bounds: AABB) -> WaterSystem:
	var system := WaterSystem.new()
	system.name = node_name
	system.position = origin
	system.system_group_name = WATER_GROUP
	system.minimum_water_level = 0.0
	system.set("_system_aabb", bounds)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 0.5, 1.0))
	system.call("set_system_map", ImageTexture.create_from_image(image))
	return system


func _make_body(node_name: String, position: Vector3, color: Color, frozen: bool) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position
	body.mass = 1.0
	body.can_sleep = true
	body.linear_damp = 0.2
	body.angular_damp = 0.2
	body.freeze = frozen
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _make_material(color, 1.0, false)
	body.add_child(mesh_instance)

	add_child(body)
	return body


func _add_buoyant(body: RigidBody3D) -> Node:
	var buoyant := Buoyant.new()
	buoyant.name = "Buoyant"
	buoyant.water_system_group_name = WATER_GROUP
	buoyant.buoyancy_force = 49.0
	buoyant.up_correcting_force = 0.0
	buoyant.flow_force = 0.0
	buoyant.water_resistance = 8.0
	body.add_child(buoyant)
	return buoyant


func _add_coverage_volume(node_name: String, bounds: AABB, color: Color) -> void:
	var volume := MeshInstance3D.new()
	volume.name = node_name
	var box := BoxMesh.new()
	box.size = bounds.size
	volume.mesh = box
	volume.position = bounds.position + bounds.size * 0.5
	volume.material_override = _make_material(color, color.a, true)
	add_child(volume)


func _add_water_plane(node_name: String, bounds: AABB, color: Color) -> void:
	var plane := MeshInstance3D.new()
	plane.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(bounds.size.x, bounds.size.z)
	plane.mesh = mesh
	plane.position = Vector3(bounds.position.x + bounds.size.x * 0.5, 0.0, bounds.position.z + bounds.size.z * 0.5)
	plane.material_override = _make_material(color, color.a, true)
	add_child(plane)


func _add_origin_marker(label: String, position: Vector3, color: Color) -> void:
	var marker := MeshInstance3D.new()
	marker.name = label.get_slice("\n", 0).replace(" ", "_")
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	marker.mesh = sphere
	marker.position = position + Vector3(0.0, 0.35, 0.0)
	marker.material_override = _make_material(color, 1.0, false)
	add_child(marker)
	_add_label(label, position + Vector3(0.0, 1.2, 0.0), color)


func _add_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = 30
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	add_child(label)


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "LowSafetyFloor"
	floor_body.position = Vector3(7.0, -1.25, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(18.0, 0.2, 10.0)
	collision.shape = shape
	floor_body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(Color(0.2, 0.22, 0.24, 0.55), 0.55, true)
	floor_body.add_child(mesh_instance)
	add_child(floor_body)


func _add_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.name = "ReviewKeyLight"
	light.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	light.light_energy = 2.0
	add_child(light)

	var environment := WorldEnvironment.new()
	environment.name = "ReviewEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.032, 0.04, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.7, 0.78, 1.0)
	env.ambient_light_energy = 0.55
	environment.environment = env
	add_child(environment)


func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.position = Vector3(10.0, 8.0, 13.0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(9.0, -0.1, 0.0), Vector3.UP)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BuoyancyReviewOverlay"
	add_child(canvas)

	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 16.0)
	_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_status_label)
	_update_overlay()


func _make_material(color: Color, alpha: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.8
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _reset_sleep_watch() -> void:
	if _sleep_body == null:
		return
	_sleep_watch_active = false
	_sleep_watch_arming = true
	_sleep_body.global_position = SLEEP_BODY_POSITION
	_sleep_body.rotation = Vector3.ZERO
	_sleep_body.linear_velocity = Vector3.ZERO
	_sleep_body.angular_velocity = Vector3.ZERO
	_sleep_body.sleeping = true
	_sleep_start_position = _sleep_body.global_position
	_sleep_timer = 0.0
	_sleep_awake_time = 0.0
	_sleep_current_awake_streak = 0.0
	_sleep_longest_awake_streak = 0.0
	_sleep_max_drift = 0.0
	_sleep_observation_complete = false
	_sleep_arm_timer = SLEEP_ARM_SECONDS


func _update_coverage_result() -> void:
	if _near_system == null or _covering_system == null or _binding_buoyant == null:
		_coverage_pass = false
		return
	var near_covers := _near_system.covers_world_position(_binding_body.global_position)
	var covering_covers := _covering_system.covers_world_position(_binding_body.global_position)
	_coverage_pass = not near_covers and covering_covers and _binding_buoyant.get("_system") == _covering_system


func _update_sleep_watch(delta: float) -> void:
	if _sleep_watch_arming:
		_sleep_arm_timer -= delta
		if _sleep_arm_timer > 0.0:
			return
		_sleep_body.linear_velocity = Vector3.ZERO
		_sleep_body.angular_velocity = Vector3.ZERO
		_sleep_body.sleeping = true
		_sleep_start_position = _sleep_body.global_position
		_sleep_timer = 0.0
		_sleep_awake_time = 0.0
		_sleep_current_awake_streak = 0.0
		_sleep_longest_awake_streak = 0.0
		_sleep_max_drift = 0.0
		_sleep_observation_complete = false
		_sleep_watch_arming = false
		_sleep_watch_active = true
		return
	if not _sleep_watch_active or _sleep_body == null or _sleep_observation_complete:
		return
	_sleep_timer += delta
	if not _sleep_body.sleeping:
		_sleep_awake_time += delta
		_sleep_current_awake_streak += delta
		_sleep_longest_awake_streak = maxf(_sleep_longest_awake_streak, _sleep_current_awake_streak)
	else:
		_sleep_current_awake_streak = 0.0
	_sleep_max_drift = maxf(_sleep_max_drift, _sleep_body.global_position.distance_to(_sleep_start_position))
	if _sleep_timer >= OBSERVATION_SECONDS:
		_sleep_observation_complete = true


func _update_overlay() -> void:
	if _status_label == null:
		return
	var status := get_review_status()
	var coverage_text := "PASS" if _coverage_pass else "WAIT"
	var sleep_pass := bool(status.get("sleep_pass", false))
	var sleep_text := "PASS" if sleep_pass else ("FAIL" if _sleep_observation_complete else "WATCHING")
	var near_distance := BINDING_BODY_POSITION.distance_to(_near_system.global_position) if _near_system != null else 0.0
	var covering_distance := BINDING_BODY_POSITION.distance_to(_covering_system.global_position) if _covering_system != null else 0.0
	_status_label.text = (
		"R4 buoyancy visible review\n"
		+ "Coverage binding: " + coverage_text + " | bound system: " + str(status.get("bound_system", "none")) + "\n"
		+ "Body is closer to red origin (" + _format_float(near_distance) + " m) than green origin (" + _format_float(covering_distance) + " m).\n"
		+ "Red covers body: " + str(status.get("near_covers_body", false)) + " | Green covers body: " + str(status.get("covering_covers_body", false)) + "\n"
		+ "Settled sleep: " + sleep_text + " | sleeping: " + str(status.get("sleep_body_sleeping", false))
		+ " | drift: " + _format_float(_sleep_max_drift) + " m | awake streak: " + _format_float(_sleep_longest_awake_streak) + " s"
		+ " | time: " + _format_float(minf(_sleep_timer, OBSERVATION_SECONDS)) + "/" + _format_float(OBSERVATION_SECONDS) + " s\n"
		+ "Live settling body sleeping: " + str(status.get("live_body_sleeping", false)) + "\n"
		+ "R resets the sleep watch."
	)


func _get_bound_system_name(buoyant: Node) -> String:
	if buoyant == null:
		return "none"
	var system := buoyant.get("_system") as Node
	return system.name if system != null else "none"


func _format_float(value: float) -> String:
	return "%0.2f" % value
