# R2 mechanism gate (windowed - the system flow render needs viewport
# readback): proves that i_flow_projected actually reaches system_flow.gdshader
# and gates a live code path, by rendering each scene's system flow map twice
# in one session - once with the rivers' real material state (projected bakes
# -> slide skipped) and once with i_flow_projected forced false (slide on) -
# and comparing the two images.
#
# Assertions per scene:
#   1. gated render vs gated render re-run -> byte-identical (same-session GPU
#      determinism sanity; without it assertion 2 means nothing).
#   2. Where the scene's content is known to exercise the slide
#      (expect_slide_effect below, measured 2026-06-12): gated vs forced-slide
#      must DIFFER - a zero diff means the gate plumbing is broken (uniform
#      renamed, gate dropped, metadata flag lost) or the slide died entirely.
#      Note the symmetric failure mode this catches: if the flag never reached
#      the material, the "gated" render would also slide and the two renders
#      would be identical.
#   3. Scenes whose content never moves the slide above 8-bit quantization
#      (the main Demo: hard-boundary texels exist but only where flow is
#      stilled/absent - measured 0 differing texels) are report-only.
#
# Why this exists (2026-06-12, R2 execution finding): RT.3's influence-zone
# angular gate cannot see the slide - the slide's contribution to the demo
# maps measures 0 texels (Demo) / 4.6k texels at mean 3.3 deg (obstacle),
# far below the 23-27 deg sampling floor of the stilled low-magnitude ring.
# This probe gates the mechanism directly instead.
#
# Run:
#   & $godotConsole --path $root --script res://addons/waterways/probes/system_flow_projected_gate_probe.gd
# Optional: -- scene=res://X.tscn (report-only) or scene=res://X.tscn:expect
#           (assert slide_diff > 0)
# Success marker: SYSTEM_FLOW_PROJECTED_GATE_OK
extends SceneTree

const SystemMapRenderer = preload("res://addons/waterways/system_map_renderer.tscn")

const RIVER_SCRIPT_PATH := "res://addons/waterways/river_manager.gd"
const WATER_SYSTEM_SCRIPT_PATH := "res://addons/waterways/water_system_manager.gd"

const DEFAULT_SCENES := [
	{"path": "res://Demo.tscn", "expect_slide_effect": false},
	{"path": "res://Demo_obstacle_flow_test.tscn", "expect_slide_effect": true},
]

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenes := []
	for arg_variant in OS.get_cmdline_user_args():
		var arg := String(arg_variant)
		if arg.begins_with("scene="):
			var spec := arg.trim_prefix("scene=")
			var expect := spec.ends_with(":expect")
			scenes.append({"path": spec.trim_suffix(":expect"), "expect_slide_effect": expect})
	if scenes.is_empty():
		scenes = DEFAULT_SCENES
	for scene_spec_variant in scenes:
		var scene_spec := scene_spec_variant as Dictionary
		await _run_scene(String(scene_spec.get("path", "")), bool(scene_spec.get("expect_slide_effect", false)))
	if _errors.is_empty():
		print("SYSTEM_FLOW_PROJECTED_GATE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_scene(scene_path: String, expect_slide_effect: bool) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + scene_path)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var system: Node = null
	for child in scene.get_children():
		var script = child.get_script()
		if script != null and script.resource_path == WATER_SYSTEM_SCRIPT_PATH:
			system = child
			break
	if system == null:
		_errors.append(scene_path + ": no WaterSystem node")
		scene.queue_free()
		await process_frame
		return

	var rivers := []
	var any_projected := false
	for child in system.get_children():
		var script = child.get_script()
		if script == null or script.resource_path != RIVER_SCRIPT_PATH:
			continue
		if not bool(child.get("valid_flowmap")):
			continue
		rivers.append(child)
		var bake := child.get("bake_data") as Resource
		if bake != null:
			var metadata = bake.get("source_metadata")
			if typeof(metadata) == TYPE_DICTIONARY and bool((metadata as Dictionary).get("flow_projected", false)):
				any_projected = true
	if rivers.is_empty():
		_errors.append(scene_path + ": no valid rivers")
		scene.queue_free()
		await process_frame
		return

	var aabb: AABB = system.call("_get_mesh_global_aabb", rivers[0].mesh_instance)
	for river in rivers:
		aabb = aabb.merge(system.call("_get_mesh_global_aabb", river.mesh_instance))
	var resolution: float = float(system.call("_get_system_bake_texture_size"))

	var renderer = SystemMapRenderer.instantiate()
	system.add_child(renderer)

	var gated_a: ImageTexture = await renderer.grab_flow(rivers, aabb, resolution)
	var gated_b: ImageTexture = await renderer.grab_flow(rivers, aabb, resolution)
	for river in rivers:
		river.call("set_materials", "i_flow_projected", false)
	var forced: ImageTexture = await renderer.grab_flow(rivers, aabb, resolution)

	var repeat_diff := _diff_images(gated_a.get_image(), gated_b.get_image())
	var slide_diff := _diff_images(gated_a.get_image(), forced.get_image())
	print("SYSTEM_FLOW_PROJECTED_GATE scene=", scene_path,
		" projected=", any_projected, " expect_slide_effect=", expect_slide_effect,
		" repeat_diff_texels=", repeat_diff.count,
		" slide_diff_texels=", slide_diff.count,
		" slide_mean_angle=", slide_diff.mean_angle,
		" slide_max_angle=", slide_diff.max_angle)

	if repeat_diff.count != 0:
		_errors.append(scene_path + ": two identical gated renders differ in " + str(repeat_diff.count) + " texels - render not deterministic this session; gate results unreliable.")
	elif expect_slide_effect and not any_projected:
		_errors.append(scene_path + ": expect_slide_effect is set but no river is flow_projected - expectation stale?")
	elif expect_slide_effect and slide_diff.count == 0:
		_errors.append(scene_path + ": forcing the slide on changed zero texels - i_flow_projected gate plumbing is broken or the slide is dead.")
	elif not expect_slide_effect:
		print("  note: report-only scene (content does not exercise the slide above quantization).")

	scene.queue_free()
	await process_frame


func _diff_images(img_a: Image, img_b: Image) -> Dictionary:
	var count := 0
	var angle_sum := 0.0
	var angle_count := 0
	var max_angle := 0.0
	for y in img_a.get_height():
		for x in img_a.get_width():
			var ca := img_a.get_pixel(x, y)
			var cb := img_b.get_pixel(x, y)
			if ca.r == cb.r and ca.g == cb.g:
				continue
			count += 1
			var va := Vector2(ca.r - 0.5, ca.g - 0.5)
			var vb := Vector2(cb.r - 0.5, cb.g - 0.5)
			if va.length() > 0.005 and vb.length() > 0.005:
				var angle := absf(rad_to_deg(va.angle_to(vb)))
				angle_sum += angle
				angle_count += 1
				max_angle = maxf(max_angle, angle)
	return {
		"count": count,
		"mean_angle": angle_sum / maxf(1.0, float(angle_count)),
		"max_angle": max_angle,
	}
