extends SceneTree

# Dash-hunt probe: captures close-up renders of the Demo river surface at
# several positions along the curve so the dashed shape-tracing artifact
# (artifacts/visual artifact*.png) can be reproduced and bisected without a
# human at the editor.
#
# Modes via OBJECT_ARTIFACT_DASH_MODE:
#   (empty/default) - capture default material at every curve fraction
#   bisect          - at the fractions in BISECT_FRACTIONS, capture once per
#                     suspect override in SUSPECT_OVERRIDES (uniform set to
#                     the given value, restored afterwards)
#
# Output: .codex-research/river-object-artifacts-visual-review/dash-hunt/
# Success marker: OBJECT_ARTIFACT_DASH_HUNT_OK

const SCENE_PATH := "res://Demo.tscn"
const RIVER_NODE_PATH := "WaterSystem/Water River"
const OUTPUT_ROOT := "res://.codex-research/river-object-artifacts-visual-review/dash-hunt"

const FRACTIONS := [0.08, 0.18, 0.30, 0.42, 0.55, 0.68, 0.80, 0.92]
const BISECT_FRACTIONS := [0.30, 0.55]
const SUSPECT_OVERRIDES := [
	{"name": "no_flow", "param": "flow_speed", "value": 0.0},
	{"name": "no_foam", "param": "foam_amount", "value": 0.0},
	{"name": "no_normal", "param": "normal_scale", "value": 0.0},
	{"name": "no_wake_normal", "param": "wake_normal_strength", "value": 0.0},
	{"name": "no_eddy_normal", "param": "wake_eddy_line_normal_strength", "value": 0.0},
	{"name": "no_pillow_normal", "param": "pillow_normal_strength", "value": 0.0},
	{"name": "no_refraction", "param": "transparency_refraction", "value": 0.0},
	{"name": "no_wake", "param": "wake_strength", "value": 0.0},
	{"name": "no_pillow", "param": "pillow_strength", "value": 0.0},
]

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_probe()
	if _errors.is_empty():
		print("OBJECT_ARTIFACT_DASH_HUNT_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_probe() -> void:
	var mode := OS.get_environment("OBJECT_ARTIFACT_DASH_MODE")
	root.size = Vector2i(1920, 1080)
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + SCENE_PATH)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = SCENE_PATH
	root.add_child(scene)
	current_scene = scene
	await _settle_frames(8)

	var river := scene.get_node_or_null(RIVER_NODE_PATH)
	if river == null:
		_errors.append("Could not find river node")
		return
	var curve := river.get("curve") as Curve3D
	if curve == null or curve.get_baked_length() <= 0.0:
		_errors.append("River has no baked curve")
		return
	var river_node := river as Node3D
	var camera := Camera3D.new()
	scene.add_child(camera)
	for other_camera in scene.find_children("*", "Camera3D", true, false):
		(other_camera as Camera3D).current = false
	camera.current = true

	var output_dir := OUTPUT_ROOT + "/" + (mode if not mode.is_empty() else "default")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	if mode == "bisect":
		for fraction in BISECT_FRACTIONS:
			await _capture(camera, river_node, curve, float(fraction), output_dir, "baseline", river, "", 0.0)
			for override in SUSPECT_OVERRIDES:
				await _capture(camera, river_node, curve, float(fraction), output_dir, String(override.name), river, String(override.param), float(override.value))
	else:
		for fraction in FRACTIONS:
			await _capture(camera, river_node, curve, float(fraction), output_dir, "default", river, "", 0.0)

	scene.queue_free()
	await process_frame


func _capture(camera: Camera3D, river_node: Node3D, curve: Curve3D, fraction: float, output_dir: String, label: String, river, override_param: String, override_value: float) -> void:
	var length := curve.get_baked_length()
	var at := river_node.global_transform * curve.sample_baked(fraction * length)
	var ahead := river_node.global_transform * curve.sample_baked(minf(fraction * length + 3.0, length))
	var forward := (ahead - at)
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	camera.global_position = at - forward * 2.0 + Vector3.UP * 2.2
	camera.look_at(at + forward * 4.0, Vector3.UP)

	var original_value = null
	if not override_param.is_empty():
		var material := _get_river_material(river)
		if material != null:
			original_value = material.get_shader_parameter(override_param)
		river.call("set_materials", override_param, override_value)
	await _settle_frames(10)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_errors.append("Could not capture " + label + " at fraction " + str(fraction))
	else:
		var path := output_dir + "/f" + ("%0.2f" % fraction).replace(".", "_") + "__" + label + ".png"
		var error := image.save_png(path)
		if error != OK:
			_errors.append("Could not save " + path)
	if not override_param.is_empty() and original_value != null:
		river.call("set_materials", override_param, original_value)
		await _settle_frames(2)


func _get_river_material(river) -> ShaderMaterial:
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return null
	return mesh_instance.mesh.surface_get_material(0) as ShaderMaterial


func _settle_frames(count: int) -> void:
	for _index in count:
		await process_frame
