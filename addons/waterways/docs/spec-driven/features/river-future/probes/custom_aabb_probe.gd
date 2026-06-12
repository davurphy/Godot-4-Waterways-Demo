# Verifies the custom-AABB wiring (Roadmap Phase 1): after mesh generation the
# river MeshInstance3D must carry a custom AABB that encloses the mesh AABB and
# adds exactly the configured vertical displacement headroom
# (DISPLACEMENT_AABB_SHADER_PARAMETERS sum).
#
# Run (mesh generation is CPU-side, headless is fine):
#   & $godotConsole --headless --path $root --script res://addons/waterways/docs/spec-driven/features/river-future/probes/custom_aabb_probe.gd
extends SceneTree

const SCENES := [
	{"name": "main_demo", "path": "res://Demo.tscn"},
	{"name": "obstacle_test", "path": "res://Demo_obstacle_flow_test.tscn"},
]

const HEADROOM_TOLERANCE := 0.0001


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	var rivers_checked := 0
	for scene_variant in SCENES:
		var case := scene_variant as Dictionary
		var packed := load(String(case["path"])) as PackedScene
		if packed == null:
			print("CASE ", case["name"], ": could not load ", case["path"])
			failures += 1
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		for river in _find_rivers(instance):
			rivers_checked += 1
			river._generate_river()
			var mesh_instance: MeshInstance3D = river.mesh_instance
			if mesh_instance == null or mesh_instance.mesh == null:
				print("CASE ", case["name"], " river=", river.name, ": no generated mesh")
				failures += 1
				continue
			var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
			var custom_aabb: AABB = mesh_instance.custom_aabb
			var expected_headroom: float = river._get_configured_max_vertical_displacement()
			var actual_headroom: float = custom_aabb.size.y - mesh_aabb.size.y
			var encloses: bool = custom_aabb.encloses(mesh_aabb) or custom_aabb.is_equal_approx(mesh_aabb)
			var headroom_ok: bool = absf(actual_headroom - expected_headroom) <= HEADROOM_TOLERANCE
			print("CASE ", case["name"], " river=", river.name,
				" expected_headroom=", expected_headroom,
				" actual_headroom=", actual_headroom,
				" encloses_mesh_aabb=", encloses)
			if not encloses or not headroom_ok:
				failures += 1
			# Exercise the parameter-change hook with a nonzero amplitude
			# (demo materials leave the pillow heights at the 0.0 default).
			var probe_amplitude := 0.25
			river._set("mat_pillow_terrain_height", probe_amplitude)
			var raised_aabb: AABB = mesh_instance.custom_aabb
			var raised_headroom: float = raised_aabb.size.y - mesh_aabb.size.y
			var raised_expected: float = river._get_configured_max_vertical_displacement()
			var raised_ok: bool = absf(raised_headroom - raised_expected) <= HEADROOM_TOLERANCE \
				and raised_expected >= probe_amplitude - HEADROOM_TOLERANCE
			print("CASE ", case["name"], " river=", river.name,
				" raised_expected=", raised_expected,
				" raised_headroom=", raised_headroom)
			if not raised_ok:
				failures += 1
		instance.queue_free()
	print("CUSTOM_AABB_PROBE rivers_checked=", rivers_checked, " failures=", failures)
	print("CUSTOM_AABB_PROBE_", "PASS" if failures == 0 and rivers_checked > 0 else "FAIL")
	quit(0 if failures == 0 and rivers_checked > 0 else 1)


func _find_rivers(node: Node) -> Array:
	var rivers := []
	var script := node.get_script() as Script
	if script != null and script.resource_path.ends_with("river_manager.gd"):
		rivers.append(node)
	for child in node.get_children():
		rivers.append_array(_find_rivers(child))
	return rivers
