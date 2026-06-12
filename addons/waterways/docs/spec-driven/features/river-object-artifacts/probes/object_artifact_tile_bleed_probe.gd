extends SceneTree

# Cross-tile bake-bleed probe.
#
# The UV2 atlas packs world-disjoint river stretches into horizontally
# adjacent tiles (steps stack down each column; the tile to the RIGHT of
# step N belongs to step N + side). The GPU filter passes (dilate, blur,
# foam, feature searches) sample atlas-wide. This probe quantifies whether
# an obstacle near a tile edge contaminates the atlas-neighbor tile:
#
#   1. Bake the unmodified Demo river (in memory) and capture the filtered
#      outputs (flow_foam_noise, dist_pressure, obstacle_features).
#   2. Add a synthetic box obstacle intersecting the water surface near the
#      RIGHT edge of the tile of OBSTACLE_STEP (i.e. near one bank).
#   3. Rebake and capture again.
#   4. Report per-tile |delta| stats for: the obstacle tile, its
#      world-adjacent tiles (step +/- 1, legitimate response), the
#      atlas-horizontal neighbor (step + side, WORLD-DISTANT - any delta
#      here is bleed), and a two-columns-away control tile.
#
# In-probe bakes do not persist to disk (verified: saved bakes unchanged).
# Success marker: OBJECT_ARTIFACT_TILE_BLEED_PROBE_OK

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const SCENE_PATH := "res://Demo.tscn"
const RIVER_NODE_PATH := "WaterSystem/Water River"
const OBSTACLE_STEP := 1
const EDGE_INSET_PIXELS := 2
const EDGE_BAND_PIXELS := 8
const OBSTACLE_SIZE := Vector3(2.5, 3.0, 2.5)

var _errors := PackedStringArray()
var _bake_done := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_probe()
	if _errors.is_empty():
		print("OBJECT_ARTIFACT_TILE_BLEED_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_probe() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_expect(false, "Could not load scene: " + SCENE_PATH)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = SCENE_PATH
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var river := scene.get_node_or_null(RIVER_NODE_PATH)
	if river == null:
		_expect(false, "Could not find river node")
		scene.queue_free()
		return
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	var steps := int(river.get("_steps"))
	var side: int = WaterHelperMethods.calculate_side(steps)
	if steps <= OBSTACLE_STEP + side:
		_expect(false, "River too short for the bleed layout (steps=" + str(steps) + ", side=" + str(side) + ")")
		scene.queue_free()
		return
	var sample_context: Dictionary = WaterHelperMethods._create_uv2_world_sample_context(
		mesh_instance, steps,
		int(river.get("shape_step_length_divs")),
		int(river.get("shape_step_width_divs"))
	)
	if sample_context.is_empty():
		_expect(false, "Could not create UV2 sample context")
		scene.queue_free()
		return

	print("OBJECT_ARTIFACT_TILE_BLEED_LAYOUT steps=", steps, " side=", side,
		" obstacle_step=", OBSTACLE_STEP, " atlas_neighbor_step=", OBSTACLE_STEP + side)

	var baseline := await _bake_and_capture(river, "baseline")
	if baseline.is_empty():
		scene.queue_free()
		return

	var content_rect: Rect2i = baseline.get("content_rect")
	var obstacle_tile: Rect2i = WaterHelperMethods.get_uv2_atlas_tile_rect(OBSTACLE_STEP, side, content_rect)
	var edge_pixel := Vector2i(
		obstacle_tile.position.x + obstacle_tile.size.x - 1 - EDGE_INSET_PIXELS,
		obstacle_tile.position.y + obstacle_tile.size.y / 2
	)
	var source_pixel := edge_pixel - content_rect.position
	var sample := WaterHelperMethods._get_uv2_world_sample(sample_context, content_rect.size.x, content_rect.size.y, source_pixel.x, source_pixel.y)
	if sample.is_empty() or bool(sample.get("outside_occupied_atlas", false)):
		_expect(false, "Could not map obstacle placement pixel to world")
		scene.queue_free()
		return
	var obstacle_position: Vector3 = sample.get("world_position", Vector3.ZERO)
	print("OBJECT_ARTIFACT_TILE_BLEED_OBSTACLE world_position=", obstacle_position, " atlas_pixel=", edge_pixel)

	var obstacle := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = OBSTACLE_SIZE
	collision_shape.shape = box
	obstacle.add_child(collision_shape)
	scene.add_child(obstacle)
	obstacle.global_position = obstacle_position
	WaterHelperMethods.reset_all_colliders(root)
	await physics_frame
	await physics_frame

	var with_obstacle := await _bake_and_capture(river, "with_obstacle")
	if with_obstacle.is_empty():
		scene.queue_free()
		return

	var report_tiles := [
		{"label": "obstacle_tile", "step": OBSTACLE_STEP},
		{"label": "world_prev", "step": OBSTACLE_STEP - 1},
		{"label": "world_next", "step": OBSTACLE_STEP + 1},
		{"label": "ATLAS_NEIGHBOR_world_distant", "step": OBSTACLE_STEP + side},
		{"label": "control_two_columns", "step": OBSTACLE_STEP + side * 2},
	]
	for tile_info in report_tiles:
		var step_index := int(tile_info.step)
		if step_index < 0 or step_index >= steps:
			continue
		var tile: Rect2i = WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, content_rect)
		var stats := _tile_delta_stats(baseline, with_obstacle, tile)
		print("OBJECT_ARTIFACT_TILE_BLEED_TILE label=", tile_info.label, " step=", step_index, " ", stats)
		if String(tile_info.label).begins_with("ATLAS_NEIGHBOR"):
			var left_band := Rect2i(tile.position, Vector2i(mini(EDGE_BAND_PIXELS, tile.size.x), tile.size.y))
			var band_stats := _tile_delta_stats(baseline, with_obstacle, left_band)
			print("OBJECT_ARTIFACT_TILE_BLEED_TILE label=ATLAS_NEIGHBOR_left_edge_band step=", step_index, " ", band_stats)

	scene.queue_free()
	await process_frame


func _bake_and_capture(river, label: String) -> Dictionary:
	_bake_done = false
	if not river.progress_notified.is_connected(_on_river_progress_notified):
		river.progress_notified.connect(_on_river_progress_notified)
	river.call("bake_texture")
	var frames := 0
	while not _bake_done and frames < 14400:
		await process_frame
		frames += 1
	if river.progress_notified.is_connected(_on_river_progress_notified):
		river.progress_notified.disconnect(_on_river_progress_notified)
	if not _bake_done:
		_expect(false, label + " bake did not finish within timeout")
		return {}
	var bake_data := river.get("bake_data") as Resource
	if bake_data == null:
		_expect(false, label + " produced no bake data")
		return {}
	var captured := {}
	for texture_name in ["flow_foam_noise", "dist_pressure", "obstacle_features"]:
		var texture := bake_data.get(texture_name) as Texture2D
		if texture == null:
			_expect(false, label + " bake missing " + texture_name)
			return {}
		captured[texture_name] = texture.get_image()
	var content_rect := bake_data.get("content_rect") as Rect2i
	if content_rect.size.x <= 0:
		content_rect = Rect2i(Vector2i.ZERO, (captured["flow_foam_noise"] as Image).get_size())
	captured["content_rect"] = content_rect
	print("OBJECT_ARTIFACT_TILE_BLEED_BAKED label=", label, " content_rect=", content_rect)
	return captured


func _on_river_progress_notified(_progress: float, message: String) -> void:
	if message == "finished":
		_bake_done = true


# Mean/max |delta| per relevant channel inside the rect:
# foam (flow_foam_noise B), flow vector (RG magnitude), distance field
# (dist_pressure R), pressure (G), pillow (obstacle_features R), wake (G).
func _tile_delta_stats(baseline: Dictionary, with_obstacle: Dictionary, rect: Rect2i) -> String:
	var flow_a: Image = baseline["flow_foam_noise"]
	var flow_b: Image = with_obstacle["flow_foam_noise"]
	var dist_a: Image = baseline["dist_pressure"]
	var dist_b: Image = with_obstacle["dist_pressure"]
	var features_a: Image = baseline["obstacle_features"]
	var features_b: Image = with_obstacle["obstacle_features"]
	var sums := {"foam": 0.0, "flow": 0.0, "dist": 0.0, "pressure": 0.0, "pillow": 0.0, "wake": 0.0}
	var maxes := {"foam": 0.0, "flow": 0.0, "dist": 0.0, "pressure": 0.0, "pillow": 0.0, "wake": 0.0}
	var count := 0
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var flow_delta_a := flow_a.get_pixel(x, y)
			var flow_delta_b := flow_b.get_pixel(x, y)
			var dist_delta_a := dist_a.get_pixel(x, y)
			var dist_delta_b := dist_b.get_pixel(x, y)
			var features_delta_a := features_a.get_pixel(x, y)
			var features_delta_b := features_b.get_pixel(x, y)
			var deltas := {
				"foam": absf(flow_delta_b.b - flow_delta_a.b),
				"flow": Vector2(flow_delta_b.r - flow_delta_a.r, flow_delta_b.g - flow_delta_a.g).length(),
				"dist": absf(dist_delta_b.r - dist_delta_a.r),
				"pressure": absf(dist_delta_b.g - dist_delta_a.g),
				"pillow": absf(features_delta_b.r - features_delta_a.r),
				"wake": absf(features_delta_b.g - features_delta_a.g),
			}
			for key in deltas:
				sums[key] += deltas[key]
				maxes[key] = maxf(maxes[key], deltas[key])
			count += 1
	var parts := PackedStringArray()
	for key in ["foam", "flow", "dist", "pressure", "pillow", "wake"]:
		parts.append(key + "_mean=" + str(snappedf(sums[key] / maxf(1.0, float(count)), 0.0001)) + " " + key + "_max=" + str(snappedf(maxes[key], 0.0001)))
	return " ".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
