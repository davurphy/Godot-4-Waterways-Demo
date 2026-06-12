extends SceneTree

# Object-artifact baseline probe (Phase 0 of river-object-artifacts).
#
# Quantifies, from the saved Demo bake and the live Demo scene:
#   1. Provenance two-tone metric: terrain_contact_features A histogram
#      (physics 0.5 vs hterrain 1.0) and per-texel neighbor flips.
#   2. Protrusion blockiness: hard texel count, isolated hard texels,
#      hard-edge neighbor flips (terrain_contact_features B).
#   3. Contact edge sharpness: mean neighbor delta of partial contact (R).
#   4. Live collision-path divergence: texels where the direct-shape
#      segment test marks an obstacle but the physics up/down-ray path
#      would exempt it (the dead overhang exemption).
#
# Optional: set OBJECT_ARTIFACT_RES_AB=1 to rebake at baking_resolution 3
# (512 atlas) and re-measure blockiness. NOTE: the bake auto-saves to
# res://waterways_bakes/ — restore that folder from git after an A/B run.
#
# Success marker: OBJECT_ARTIFACT_BASELINE_PROBE_OK

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const SCENE_PATH := "res://Demo.tscn"
const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"
const RIVER_NODE_PATH := "WaterSystem/Water River"
const REGION_NODE_PATH := "Cliffs/cliff2"
const REGION_RADIUS := 10.0
const DIVERGENCE_STRIDE := 2
const PROVENANCE_FLIP_DELTA := 0.3
const HARD_PROTRUSION_THRESHOLD := 0.5

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_probe()
	if _errors.is_empty():
		print("OBJECT_ARTIFACT_BASELINE_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_probe() -> void:
	var bake := load(BAKE_PATH) as Resource
	if bake == null:
		_expect(false, "Could not load bake resource: " + BAKE_PATH)
		return
	var terrain_texture := bake.get("terrain_contact_features") as Texture2D
	if terrain_texture == null:
		_expect(false, "Bake is missing terrain_contact_features")
		return
	var terrain_image := terrain_texture.get_image()
	if terrain_image == null or terrain_image.is_empty():
		_expect(false, "terrain_contact_features image is unreadable")
		return
	var content_rect := _get_content_rect(bake, terrain_image)
	var uv2_sides := maxi(1, int(bake.get("uv2_sides")))
	var occupied_steps := _get_occupied_steps(bake, uv2_sides)

	var scene := await _load_demo_scene()
	if scene == null:
		return
	var river := scene.get_node_or_null(RIVER_NODE_PATH)
	if river == null:
		_expect(false, "Could not find river node: " + RIVER_NODE_PATH)
		return
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		_expect(false, "River has no generated mesh")
		return
	var live_steps := int(river.get("_steps"))
	if live_steps != occupied_steps:
		print("OBJECT_ARTIFACT_BASELINE_NOTE live_steps=", live_steps, " bake_step_count=", occupied_steps, " (using live)")
	var sample_context: Dictionary = WaterHelperMethods._create_uv2_world_sample_context(
		mesh_instance,
		live_steps,
		int(river.get("shape_step_length_divs")),
		int(river.get("shape_step_width_divs"))
	)
	if sample_context.is_empty():
		_expect(false, "Could not create UV2 world sample context")
		return

	var region_node := scene.get_node_or_null(REGION_NODE_PATH) as Node3D
	var region_steps := {}
	if region_node != null:
		region_steps = _find_region_steps(sample_context, content_rect.size, region_node.global_position, REGION_RADIUS)
		print("OBJECT_ARTIFACT_BASELINE_REGION node=", REGION_NODE_PATH, " radius=", REGION_RADIUS, " steps=", region_steps.keys())
	else:
		print("OBJECT_ARTIFACT_BASELINE_NOTE region node missing: ", REGION_NODE_PATH)

	_print_saved_metrics("global", terrain_image, content_rect, uv2_sides, live_steps, {})
	if not region_steps.is_empty():
		_print_saved_metrics("region", terrain_image, content_rect, uv2_sides, live_steps, region_steps)

	await _run_divergence_scan(river, mesh_instance, sample_context, content_rect.size, region_steps)

	if OS.get_environment("OBJECT_ARTIFACT_RES_AB") == "1":
		await _run_resolution_ab(river, uv2_sides)

	scene.queue_free()
	await process_frame


func _load_demo_scene() -> Node:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_expect(false, "Could not load scene: " + SCENE_PATH)
		return null
	var scene := packed.instantiate()
	if scene == null:
		_expect(false, "Could not instantiate scene: " + SCENE_PATH)
		return null
	scene.scene_file_path = SCENE_PATH
	root.add_child(scene)
	current_scene = scene
	await process_frame
	WaterHelperMethods.reset_all_colliders(root)
	await physics_frame
	await physics_frame
	await physics_frame
	return scene


# Map each occupied UV2 tile's center texel to world space; return the set of
# step indices whose center lies within radius of the region center.
func _find_region_steps(sample_context: Dictionary, source_size: Vector2i, region_center: Vector3, radius: float) -> Dictionary:
	var steps := int(sample_context.get("steps", 0))
	var side := int(sample_context.get("side", 1))
	var found := {}
	for step_index in steps:
		var tile := _source_tile_rect(step_index, side, source_size)
		var center_x := tile.position.x + tile.size.x / 2
		var center_y := tile.position.y + tile.size.y / 2
		var sample := WaterHelperMethods._get_uv2_world_sample(sample_context, source_size.x, source_size.y, center_x, center_y)
		if sample.is_empty() or bool(sample.get("outside_occupied_atlas", false)):
			continue
		var world_position: Vector3 = sample.get("world_position", Vector3.ZERO)
		if world_position.distance_to(region_center) <= radius:
			found[step_index] = true
	return found


func _print_saved_metrics(label: String, terrain_image: Image, content_rect: Rect2i, uv2_sides: int, occupied_steps: int, region_steps: Dictionary) -> void:
	var metrics := _measure_terrain_image(terrain_image, content_rect, uv2_sides, occupied_steps, region_steps)
	print("OBJECT_ARTIFACT_BASELINE_TERRAIN scope=", label,
		" texels=", metrics.texels,
		" prov_zero=", metrics.prov_zero,
		" prov_physics=", metrics.prov_physics,
		" prov_blend=", metrics.prov_blend,
		" prov_hterrain=", metrics.prov_hterrain,
		" prov_flips=", metrics.prov_flips,
		" prov_flip_density=", _density(metrics.prov_flips, metrics.texels - metrics.prov_zero))
	print("OBJECT_ARTIFACT_BASELINE_PROTRUSION scope=", label,
		" hard=", metrics.hard,
		" partial=", metrics.partial,
		" isolated_hard=", metrics.isolated_hard,
		" hard_edge_flips=", metrics.hard_edge_flips,
		" flip_per_hard=", _density(metrics.hard_edge_flips, metrics.hard))
	print("OBJECT_ARTIFACT_BASELINE_CONTACT scope=", label,
		" partial_contact=", metrics.contact_partial,
		" mean_neighbor_delta=", snappedf(metrics.contact_mean_delta, 0.0001))


func _measure_terrain_image(image: Image, content_rect: Rect2i, uv2_sides: int, occupied_steps: int, region_steps: Dictionary) -> Dictionary:
	var width := content_rect.size.x
	var height := content_rect.size.y
	var texels := 0
	var prov_zero := 0
	var prov_physics := 0
	var prov_blend := 0
	var prov_hterrain := 0
	var prov_flips := 0
	var hard := 0
	var partial := 0
	var isolated_hard := 0
	var hard_edge_flips := 0
	var contact_partial := 0
	var contact_delta_sum := 0.0
	var contact_delta_count := 0
	for x in width:
		for y in height:
			var step_index := _step_index_for_source_pixel(x, y, width, height, uv2_sides)
			if step_index >= occupied_steps:
				continue
			if not region_steps.is_empty() and not region_steps.has(step_index):
				continue
			texels += 1
			var color := image.get_pixel(content_rect.position.x + x, content_rect.position.y + y)
			if color.a < 0.05:
				prov_zero += 1
			elif color.a < 0.55:
				prov_physics += 1
			elif color.a < 0.95:
				prov_blend += 1
			else:
				prov_hterrain += 1
			var is_hard := color.b >= HARD_PROTRUSION_THRESHOLD
			if is_hard:
				hard += 1
			elif color.b > 0.05:
				partial += 1
			if color.r > 0.01 and color.r < 0.99:
				contact_partial += 1
			var hard_neighbors := 0
			for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var neighbor_step := _step_index_for_source_pixel(nx, ny, width, height, uv2_sides)
				if neighbor_step >= occupied_steps:
					continue
				var neighbor := image.get_pixel(content_rect.position.x + nx, content_rect.position.y + ny)
				if neighbor.b >= HARD_PROTRUSION_THRESHOLD:
					hard_neighbors += 1
				# Count each adjacent pair once (positive offsets only).
				if offset.x > 0 or offset.y > 0:
					if color.a >= 0.05 and neighbor.a >= 0.05 and absf(color.a - neighbor.a) >= PROVENANCE_FLIP_DELTA:
						prov_flips += 1
					if absf(color.b - neighbor.b) >= HARD_PROTRUSION_THRESHOLD:
						hard_edge_flips += 1
					if (color.r > 0.01 and color.r < 0.99) or (neighbor.r > 0.01 and neighbor.r < 0.99):
						contact_delta_sum += absf(color.r - neighbor.r)
						contact_delta_count += 1
			if is_hard and hard_neighbors == 0:
				isolated_hard += 1
	return {
		"texels": texels,
		"prov_zero": prov_zero,
		"prov_physics": prov_physics,
		"prov_blend": prov_blend,
		"prov_hterrain": prov_hterrain,
		"prov_flips": prov_flips,
		"hard": hard,
		"partial": partial,
		"isolated_hard": isolated_hard,
		"hard_edge_flips": hard_edge_flips,
		"contact_partial": contact_partial,
		"contact_mean_delta": contact_delta_sum / maxf(1.0, float(contact_delta_count))
	}


# Replicates the two generate_collisionmap paths per sampled texel and counts
# where they disagree. direct_only_overhang is the dead-exemption signature:
# the direct-shape segment test marks an obstacle while the physics path's
# up-ray frontface logic would exempt it.
func _run_divergence_scan(river, mesh_instance: MeshInstance3D, sample_context: Dictionary, source_size: Vector2i, region_steps: Dictionary) -> void:
	var raycast_distance := float(river.get("baking_raycast_distance"))
	var raycast_layers := int(river.get("baking_raycast_layers"))
	var collision_root: Node = WaterHelperMethods._get_bake_collision_root(mesh_instance, river)
	var collision_shapes: Array = WaterHelperMethods.collect_raycast_collision_shapes(collision_root, raycast_layers)
	var space_state := mesh_instance.get_world_3d().direct_space_state
	if space_state == null:
		_expect(false, "No physics space state available")
		return
	WaterHelperMethods.clear_polygon_shape_intersection_caches()
	var samples := 0
	var both_mark := 0
	var physics_only := 0
	var direct_only := 0
	var direct_only_overhang := 0
	var region_direct_only_overhang := 0
	var example_positions := []
	for x in range(0, source_size.x, DIVERGENCE_STRIDE):
		for y in range(0, source_size.y, DIVERGENCE_STRIDE):
			var sample := WaterHelperMethods._get_uv2_world_sample(sample_context, source_size.x, source_size.y, x, y)
			if bool(sample.get("outside_occupied_atlas", false)):
				break
			if sample.is_empty():
				continue
			var real_pos: Vector3 = sample.get("world_position", Vector3.ZERO)
			var real_pos_up := real_pos + Vector3.UP * raycast_distance
			samples += 1

			var direct_hit: bool = WaterHelperMethods._intersects_collision_shapes_segment(collision_shapes, real_pos_up, real_pos)

			var query_up := PhysicsRayQueryParameters3D.create(real_pos, real_pos_up)
			query_up.collision_mask = raycast_layers
			var result_up: Dictionary = space_state.intersect_ray(query_up)
			var query_down := PhysicsRayQueryParameters3D.create(real_pos_up, real_pos)
			query_down.collision_mask = raycast_layers
			var result_down: Dictionary = space_state.intersect_ray(query_down)
			var up_hit_frontface := false
			if result_up:
				if result_up.normal.y < 0:
					up_hit_frontface = true
			var physics_mark: bool = (result_up or result_down) and (not up_hit_frontface and not result_down.is_empty())

			if direct_hit and physics_mark:
				both_mark += 1
			elif direct_hit and not physics_mark:
				direct_only += 1
				if up_hit_frontface:
					direct_only_overhang += 1
					if region_steps.has(int(sample.get("step", -1))):
						region_direct_only_overhang += 1
					if example_positions.size() < 5:
						example_positions.append(real_pos)
			elif physics_mark and not direct_hit:
				physics_only += 1
	print("OBJECT_ARTIFACT_BASELINE_DIVERGENCE samples=", samples,
		" both_mark=", both_mark,
		" direct_only=", direct_only,
		" direct_only_overhang=", direct_only_overhang,
		" region_direct_only_overhang=", region_direct_only_overhang,
		" physics_only=", physics_only)
	if not example_positions.is_empty():
		print("OBJECT_ARTIFACT_BASELINE_DIVERGENCE_EXAMPLES ", example_positions)


# Premise falsification A/B: rebake at baking_resolution 3 (512 atlas) and
# re-measure. If flip densities stay ~constant per texel (block size shrinks
# in world terms), texel aliasing is confirmed dominant.
func _run_resolution_ab(river, uv2_sides: int) -> void:
	print("OBJECT_ARTIFACT_RES_AB starting rebake at baking_resolution=3 (512)")
	river.set("baking_resolution", 3)
	var bake_done := [false]
	var on_progress := func(_progress: float, message: String) -> void:
		if message == "finished":
			bake_done[0] = true
	river.progress_notified.connect(on_progress)
	river.call("bake_texture")
	var frames := 0
	while not bake_done[0] and frames < 14400:
		await process_frame
		frames += 1
	river.progress_notified.disconnect(on_progress)
	if not bake_done[0]:
		_expect(false, "Resolution A/B bake did not finish within timeout")
		return
	var bake_data := river.get("bake_data") as Resource
	if bake_data == null:
		_expect(false, "Resolution A/B produced no bake data")
		return
	var terrain_texture := bake_data.get("terrain_contact_features") as Texture2D
	if terrain_texture == null:
		_expect(false, "Resolution A/B bake missing terrain_contact_features")
		return
	var terrain_image := terrain_texture.get_image()
	var content_rect := _get_content_rect(bake_data, terrain_image)
	var occupied_steps := _get_occupied_steps(bake_data, uv2_sides)
	_print_saved_metrics("res_ab_512", terrain_image, content_rect, uv2_sides, occupied_steps, {})
	print("OBJECT_ARTIFACT_RES_AB done; restore res://waterways_bakes/ from git before committing")


func _step_index_for_source_pixel(x: int, y: int, width: int, height: int, side: int) -> int:
	var column: int = WaterHelperMethods._uv2_atlas_axis_index(x, width, side)
	var row: int = WaterHelperMethods._uv2_atlas_axis_index(y, height, side)
	return column * side + row


func _source_tile_rect(step_index: int, side: int, source_size: Vector2i) -> Rect2i:
	var safe_side := maxi(1, side)
	var column := int(step_index / safe_side)
	var row := step_index % safe_side
	var x0 := int(floor(float(column) * float(source_size.x) / float(safe_side)))
	var x1 := int(floor(float(column + 1) * float(source_size.x) / float(safe_side)))
	var y0 := int(floor(float(row) * float(source_size.y) / float(safe_side)))
	var y1 := int(floor(float(row + 1) * float(source_size.y) / float(safe_side)))
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


func _get_content_rect(bake: Resource, image: Image) -> Rect2i:
	var rect := bake.get("content_rect") as Rect2i
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i(Vector2i.ZERO, image.get_size())
	var position := Vector2i(
		clampi(rect.position.x, 0, image.get_width() - 1),
		clampi(rect.position.y, 0, image.get_height() - 1)
	)
	var end := Vector2i(
		clampi(rect.position.x + rect.size.x, position.x + 1, image.get_width()),
		clampi(rect.position.y + rect.size.y, position.y + 1, image.get_height())
	)
	return Rect2i(position, end - position)


func _get_occupied_steps(bake: Resource, uv2_sides: int) -> int:
	var total_tiles := uv2_sides * uv2_sides
	var signature = bake.get("source_signature")
	if typeof(signature) == TYPE_DICTIONARY:
		var signature_steps := int((signature as Dictionary).get("step_count", 0))
		if signature_steps > 0:
			return clampi(signature_steps, 1, total_tiles)
	return total_tiles


func _density(count: int, total: int) -> float:
	return snappedf(float(count) / maxf(1.0, float(total)), 0.0001)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
