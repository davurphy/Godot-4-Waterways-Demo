extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const SCENE_PATH := "res://Demo.tscn"
const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"
const RIVER_NODE_PATH := "WaterSystem/Water River"
const REGION_NODE_PATH := "Cliffs/cliff2"
const REGION_RADIUS := 10.0
const WATERLINE_HALF_BAND := 0.08
const OCCUPANCY_SOLID_THRESHOLD := 0.5
const PROTRUSION_THRESHOLD := 0.9
const PROTRUSION_CONFIDENCE_MIN := 0.75
const OUT_DIR := "res://addons/waterways/docs/spec-driven/features/river-waterline-bank-flow-corrections/probes/out"

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_probe()
	if _errors.is_empty():
		print("WATERLINE_OCCUPANCY_PROBE_OK")
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
	var occupancy_image := _get_bake_image(bake, "water_occupancy")
	var terrain_image := _get_bake_image(bake, "terrain_contact_features")
	if occupancy_image == null:
		_expect(false, "Bake is missing water_occupancy image")
		return
	var content_rect := _get_content_rect(bake, occupancy_image)
	var uv2_sides := maxi(1, int(bake.get("uv2_sides")))
	var occupied_steps := _get_occupied_steps(bake, uv2_sides)

	var scene := await _load_scene()
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
	var sample_context: Dictionary = WaterHelperMethods._create_uv2_world_sample_context(
		mesh_instance,
		int(river.get("_steps")),
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
	print("WATERLINE_OCCUPANCY_REGION node=", REGION_NODE_PATH,
		" radius=", REGION_RADIUS,
		" steps=", region_steps.keys(),
		" waterline_half_band=", WATERLINE_HALF_BAND)

	_scan_region(river, mesh_instance, sample_context, content_rect, uv2_sides, occupied_steps, region_steps, occupancy_image, terrain_image)
	scene.queue_free()
	await process_frame


func _scan_region(
	river,
	mesh_instance: MeshInstance3D,
	sample_context: Dictionary,
	content_rect: Rect2i,
	uv2_sides: int,
	occupied_steps: int,
	region_steps: Dictionary,
	occupancy_image: Image,
	terrain_image: Image
) -> void:
	var raycast_distance := float(river.get("baking_raycast_distance"))
	var raycast_layers := int(river.get("baking_raycast_layers"))
	var collision_root: Node = WaterHelperMethods._get_bake_collision_root(mesh_instance, river)
	var collision_shapes: Array = WaterHelperMethods.collect_raycast_collision_shapes(collision_root, raycast_layers)
	var space_state := mesh_instance.get_world_3d().direct_space_state
	if space_state == null:
		_expect(false, "No physics space state available")
		return
	WaterHelperMethods.clear_polygon_shape_intersection_caches()

	var overlay := Image.create(content_rect.size.x, content_rect.size.y, false, Image.FORMAT_RGBA8)
	overlay.fill(Color(0.0, 0.0, 0.0, 1.0))

	var sampled := 0
	var saved_solid := 0
	var saved_upper_open := 0
	var current_solid := 0
	var current_upper_open := 0
	var current_down_top_upper_open := 0
	var current_direct_upper_open := 0
	var current_inside := 0
	var current_overhang_exempted := 0
	var waterline_hit := 0
	var terrain_hard_high_conf := 0
	var terrain_hard_low_conf := 0
	var overlap_saved_current_upper_open := 0
	var saved_only_upper_open := 0
	var current_only_upper_open := 0
	var examples := []

	for x in content_rect.size.x:
		for y in content_rect.size.y:
			var step_index := _step_index_for_source_pixel(x, y, content_rect.size.x, content_rect.size.y, uv2_sides)
			if step_index >= occupied_steps:
				continue
			if not region_steps.is_empty() and not region_steps.has(step_index):
				continue
			var sample := WaterHelperMethods._get_uv2_world_sample(sample_context, content_rect.size.x, content_rect.size.y, x, y)
			if bool(sample.get("outside_occupied_atlas", false)) or sample.is_empty():
				continue
			var world_position: Vector3 = sample.get("world_position", Vector3.ZERO)
			if not WaterHelperMethods._is_finite_vector3(world_position):
				continue
			sampled += 1
			var atlas_pixel := content_rect.position + Vector2i(x, y)
			var saved_is_solid := occupancy_image.get_pixelv(atlas_pixel).r > OCCUPANCY_SOLID_THRESHOLD
			var terrain := Color(0.0, 0.0, 0.0, 0.0)
			if terrain_image != null and terrain_image.get_size() == occupancy_image.get_size():
				terrain = terrain_image.get_pixelv(atlas_pixel)
			var hard_high_conf := terrain.b >= PROTRUSION_THRESHOLD and terrain.a >= PROTRUSION_CONFIDENCE_MIN
			var hard_low_conf := terrain.b >= PROTRUSION_THRESHOLD and terrain.a > 0.0 and terrain.a < PROTRUSION_CONFIDENCE_MIN
			if hard_high_conf:
				terrain_hard_high_conf += 1
			if hard_low_conf:
				terrain_hard_low_conf += 1

			var current := _classify_current_collision(space_state, collision_shapes, world_position, raycast_distance, raycast_layers)
			var waterline_is_hit := _has_waterline_contact(space_state, collision_shapes, world_position, raycast_layers)
			var waterline_open := not waterline_is_hit
			if waterline_is_hit:
				waterline_hit += 1
			if saved_is_solid:
				saved_solid += 1
			if bool(current.get("solid", false)):
				current_solid += 1
			if bool(current.get("inside", false)):
				current_inside += 1
			if bool(current.get("overhang_exempted", false)):
				current_overhang_exempted += 1

			var current_is_upper_open: bool = bool(current.get("solid", false)) and waterline_open
			var saved_is_upper_open := saved_is_solid and waterline_open
			if current_is_upper_open:
				current_upper_open += 1
				if bool(current.get("down_top", false)):
					current_down_top_upper_open += 1
				if bool(current.get("direct_fallback", false)):
					current_direct_upper_open += 1
			if saved_is_upper_open:
				saved_upper_open += 1
			if saved_is_upper_open and current_is_upper_open:
				overlap_saved_current_upper_open += 1
			elif saved_is_upper_open and not current_is_upper_open:
				saved_only_upper_open += 1
			elif current_is_upper_open and not saved_is_upper_open:
				current_only_upper_open += 1

			if current_is_upper_open and examples.size() < 8:
				examples.append({
					"pixel": atlas_pixel,
					"world": world_position,
					"source": current.get("source", "")
				})

			var overlay_color := Color(0.0, 0.0, 0.0, 1.0)
			if saved_is_upper_open and current_is_upper_open:
				overlay_color = Color(1.0, 0.0, 0.0, 1.0)
			elif saved_is_upper_open:
				overlay_color = Color(1.0, 0.75, 0.0, 1.0)
			elif current_is_upper_open:
				overlay_color = Color(0.7, 0.0, 1.0, 1.0)
			elif saved_is_solid or bool(current.get("solid", false)):
				overlay_color = Color(0.25, 0.25, 0.25, 1.0)
			elif waterline_is_hit:
				overlay_color = Color(0.0, 0.35, 1.0, 1.0)
			overlay.set_pixel(x, y, overlay_color)

	var out_path := OUT_DIR + "/waterline_occupancy_cliff2.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	overlay.save_png(out_path)

	print("WATERLINE_OCCUPANCY_SCAN sampled=", sampled,
		" saved_solid=", saved_solid,
		" current_solid=", current_solid,
		" waterline_hit=", waterline_hit,
		" saved_upper_open=", saved_upper_open,
		" current_upper_open=", current_upper_open,
		" current_down_top_upper_open=", current_down_top_upper_open,
		" current_direct_upper_open=", current_direct_upper_open,
		" overlap_saved_current_upper_open=", overlap_saved_current_upper_open,
		" saved_only_upper_open=", saved_only_upper_open,
		" current_only_upper_open=", current_only_upper_open,
		" current_inside=", current_inside,
		" current_overhang_exempted=", current_overhang_exempted,
		" terrain_hard_high_conf=", terrain_hard_high_conf,
		" terrain_hard_low_conf=", terrain_hard_low_conf,
		" overlay=", out_path)
	if not examples.is_empty():
		print("WATERLINE_OCCUPANCY_EXAMPLES ", examples)


func _classify_current_collision(space_state: PhysicsDirectSpaceState3D, collision_shapes: Array, world_position: Vector3, raycast_distance: float, raycast_layers: int) -> Dictionary:
	var real_pos_up := world_position + Vector3.UP * raycast_distance
	var query_up := PhysicsRayQueryParameters3D.create(world_position, real_pos_up)
	query_up.collision_mask = raycast_layers
	query_up.hit_from_inside = true
	var result_up: Dictionary = space_state.intersect_ray(query_up)
	var query_down := PhysicsRayQueryParameters3D.create(real_pos_up, world_position)
	query_down.collision_mask = raycast_layers
	var result_down: Dictionary = space_state.intersect_ray(query_down)

	var up_hit_frontface := false
	var up_hit_inside := false
	if result_up:
		if result_up.normal == Vector3.ZERO:
			up_hit_inside = true
		elif result_up.normal.y < 0:
			up_hit_frontface = true
	if up_hit_inside:
		return {"solid": true, "inside": true, "source": "inside"}
	if result_up or result_down:
		if not up_hit_frontface and result_down and WaterHelperMethods._has_collision_waterline_contact(space_state, collision_shapes, world_position, raycast_layers):
			return {"solid": true, "down_top": true, "source": "down_top"}
		return {"solid": false, "overhang_exempted": up_hit_frontface, "source": "physics_exempted"}
	if WaterHelperMethods._has_collision_waterline_contact(space_state, collision_shapes, world_position, raycast_layers):
		return {"solid": true, "direct_fallback": true, "source": "direct_fallback"}
	return {"solid": false, "source": "open"}


func _has_waterline_contact(space_state: PhysicsDirectSpaceState3D, collision_shapes: Array, world_position: Vector3, raycast_layers: int) -> bool:
	return WaterHelperMethods._has_collision_waterline_contact(space_state, collision_shapes, world_position, raycast_layers, WATERLINE_HALF_BAND)


func _load_scene() -> Node:
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


func _get_bake_image(bake: Resource, property_name: String) -> Image:
	var texture := bake.get(property_name) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
