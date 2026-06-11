extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const RIVER_SCRIPT_PATH := "res://addons/waterways/river_manager.gd"

const CASES := [
	{
		"name": "main_demo",
		"scene": "res://Demo.tscn",
		"bake": "res://waterways_bakes/Demo/Water_River.river_bake.res",
	},
	{
		"name": "obstacle_test",
		"scene": "res://Demo_obstacle_flow_test.tscn",
		"bake": "res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
	},
]

const TOP_JOIN_LIMIT := 8
const MAX_SAMPLES_PER_EDGE := 64
const EDGE_DEPTH := 0
const PRIORITY_CHANNELS := ["terrain_r", "terrain_g", "terrain_a", "bank_r", "bank_g", "bank_b"]

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for case_variant in CASES:
		var probe_case := case_variant as Dictionary
		await _run_case(probe_case)
	if _errors.is_empty():
		print("RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _run_case(probe_case: Dictionary) -> void:
	var scene_path := String(probe_case.get("scene", ""))
	var bake_path := String(probe_case.get("bake", ""))
	var case_name := String(probe_case.get("name", scene_path))
	var bake := load(bake_path) as Resource
	if bake == null:
		_expect(false, "Could not load bake resource: " + bake_path)
		return
	var terrain_image := _texture_image(bake, "terrain_contact_features", bake_path)
	var bank_image := _texture_image(bake, "bank_response_features", bake_path)
	if terrain_image == null or bank_image == null:
		return
	var content_rect := _get_content_rect(bake, terrain_image)
	var uv2_sides := maxi(1, int(bake.get("uv2_sides")))
	var occupied_steps := _get_occupied_steps(bake, uv2_sides)
	var top_joins := _collect_top_saved_bake_joins(terrain_image, bank_image, content_rect, uv2_sides, occupied_steps)

	var packed := load(scene_path) as PackedScene
	if packed == null:
		_expect(false, "Could not load scene: " + scene_path)
		return
	var scene := packed.instantiate()
	if scene == null:
		_expect(false, "Could not instantiate scene: " + scene_path)
		return
	root.add_child(scene)
	await _settle_frames(3)

	var river := _find_river_for_bake(scene, bake_path)
	if river == null:
		_expect(false, "Could not find river for bake " + bake_path + " in " + scene_path)
		scene.queue_free()
		await _settle_frames(1)
		return
	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		_expect(false, "River has no generated mesh for " + scene_path)
		scene.queue_free()
		await _settle_frames(1)
		return

	var shape_step_length_divs := int(river.get("shape_step_length_divs"))
	var shape_step_width_divs := int(river.get("shape_step_width_divs"))
	var sample_context: Dictionary = WaterHelperMethods._create_uv2_world_sample_context(
		mesh_instance,
		occupied_steps,
		shape_step_length_divs,
		shape_step_width_divs
	)
	if sample_context.is_empty():
		_expect(false, "Could not create UV2 world sample context for " + scene_path)
		scene.queue_free()
		await _settle_frames(1)
		return

	var terrain_context := _make_terrain_context(river, mesh_instance)
	var world_reports := []
	for join in top_joins:
		world_reports.append(_inspect_join_world_sample(join, bake, terrain_image, content_rect, sample_context, terrain_context))

	print("RIVER_FLOWMAP_WORLD_SAMPLE_PROBE_CASE case=", case_name)
	print("  scene=", scene_path, " bake=", bake_path, " uv2_sides=", uv2_sides, " occupied_steps=", occupied_steps, " content_rect=", content_rect)
	print("  worst_saved_bake_world_samples=", world_reports)

	scene.queue_free()
	await _settle_frames(2)


func _texture_image(bake: Resource, property_name: String, bake_path: String) -> Image:
	var texture := bake.get(property_name) as Texture2D
	if texture == null:
		_expect(false, bake_path + " is missing texture " + property_name)
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		_expect(false, bake_path + " texture is unreadable: " + property_name)
		return null
	return image


func _collect_top_saved_bake_joins(terrain_image: Image, bank_image: Image, content_rect: Rect2i, uv2_sides: int, occupied_steps: int) -> Array:
	var top := []
	for step_index in range(maxi(occupied_steps - 1, 0)):
		var from_tile := _tile_rect(step_index, uv2_sides, content_rect)
		var to_tile := _tile_rect(step_index + 1, uv2_sides, content_rect)
		var sample_count := mini(MAX_SAMPLES_PER_EDGE, maxi(from_tile.size.x, to_tile.size.x))
		var from_y := from_tile.position.y + from_tile.size.y - 1 - EDGE_DEPTH
		var to_y := to_tile.position.y + EDGE_DEPTH
		for sample_index in range(sample_count):
			var t := _sample_t(sample_index, sample_count)
			var from_pixel := Vector2i(_lerp_pixel(from_tile.position.x, from_tile.size.x, t), from_y)
			var to_pixel := Vector2i(_lerp_pixel(to_tile.position.x, to_tile.size.x, t), to_y)
			var terrain_from := terrain_image.get_pixelv(from_pixel)
			var terrain_to := terrain_image.get_pixelv(to_pixel)
			var bank_from := bank_image.get_pixelv(from_pixel)
			var bank_to := bank_image.get_pixelv(to_pixel)
			var deltas := {
				"terrain_r": absf(terrain_from.r - terrain_to.r),
				"terrain_g": absf(terrain_from.g - terrain_to.g),
				"terrain_b": absf(terrain_from.b - terrain_to.b),
				"terrain_a": absf(terrain_from.a - terrain_to.a),
				"bank_r": absf(bank_from.r - bank_to.r),
				"bank_g": absf(bank_from.g - bank_to.g),
				"bank_b": absf(bank_from.b - bank_to.b),
				"bank_a": absf(bank_from.a - bank_to.a),
			}
			var score := 0.0
			for channel_variant in PRIORITY_CHANNELS:
				var channel := String(channel_variant)
				score = maxf(score, float(deltas.get(channel, 0.0)))
			_track_top_join(top, {
				"score": _round5(score),
				"from_step": step_index,
				"to_step": step_index + 1,
				"kind": "logical_row_wrap" if step_index % uv2_sides == uv2_sides - 1 else "logical_same_column",
				"sample": sample_index,
				"from_pixel": from_pixel,
				"to_pixel": to_pixel,
				"terrain_from": _color_dict(terrain_from),
				"terrain_to": _color_dict(terrain_to),
				"bank_from": _color_dict(bank_from),
				"bank_to": _color_dict(bank_to),
				"deltas": _rounded_dict(deltas),
			})
	return top


func _inspect_join_world_sample(join: Dictionary, bake: Resource, terrain_image: Image, content_rect: Rect2i, sample_context: Dictionary, terrain_context: Dictionary) -> Dictionary:
	var source_size: Vector2i = bake.get("source_texture_size")
	if source_size.x <= 0 or source_size.y <= 0:
		source_size = content_rect.size
	var from_pixel: Vector2i = join.get("from_pixel", Vector2i.ZERO)
	var to_pixel: Vector2i = join.get("to_pixel", Vector2i.ZERO)
	var from_source_pixel := from_pixel - content_rect.position
	var to_source_pixel := to_pixel - content_rect.position
	var from_sample: Dictionary = WaterHelperMethods._get_uv2_world_sample(sample_context, source_size.x, source_size.y, from_source_pixel.x, from_source_pixel.y)
	var to_sample: Dictionary = WaterHelperMethods._get_uv2_world_sample(sample_context, source_size.x, source_size.y, to_source_pixel.x, to_source_pixel.y)
	var report := join.duplicate(true)
	report["from_source_pixel"] = from_source_pixel
	report["to_source_pixel"] = to_source_pixel
	if from_sample.is_empty() or to_sample.is_empty():
		report["world_sample_error"] = {
			"from_empty": from_sample.is_empty(),
			"to_empty": to_sample.is_empty(),
		}
		return report
	var from_world: Vector3 = from_sample.get("world_position", Vector3.ZERO)
	var to_world: Vector3 = to_sample.get("world_position", Vector3.ZERO)
	var from_contact := _sample_contact_features(from_world, terrain_context)
	var to_contact := _sample_contact_features(to_world, terrain_context)
	var saved_from := terrain_image.get_pixelv(from_pixel)
	var saved_to := terrain_image.get_pixelv(to_pixel)
	report["world"] = {
		"from": _vector3_dict(from_world),
		"to": _vector3_dict(to_world),
		"distance": _round5(from_world.distance_to(to_world)),
		"height_delta": _round5(from_world.y - to_world.y),
	}
	report["computed_contact"] = {
		"from": from_contact,
		"to": to_contact,
		"delta": _color_delta_dict(_contact_color(from_contact), _contact_color(to_contact)),
	}
	report["saved_terrain_delta"] = _color_delta_dict(saved_from, saved_to)
	return report


func _make_terrain_context(river: Node, mesh_instance: MeshInstance3D) -> Dictionary:
	var settings := {}
	if river.has_method("_get_terrain_contact_feature_settings"):
		settings = river.call("_get_terrain_contact_feature_settings")
	var raycast_layers := int(river.get("baking_raycast_layers"))
	var collision_root := _get_bake_collision_root(mesh_instance, river)
	return {
		"settings": settings,
		"raycast_layers": raycast_layers,
		"hterrain_samplers": WaterHelperMethods.collect_hterrain_samplers(collision_root, raycast_layers),
		"direct_collision_shapes": WaterHelperMethods.collect_raycast_collision_shapes(collision_root, raycast_layers),
		"space_state": mesh_instance.get_world_3d().direct_space_state,
	}


func _sample_contact_features(water_position: Vector3, terrain_context: Dictionary) -> Dictionary:
	var settings: Dictionary = terrain_context.get("settings", {})
	var raycast_layers := int(terrain_context.get("raycast_layers", 0))
	var hterrain_samplers: Array = terrain_context.get("hterrain_samplers", [])
	var direct_collision_shapes: Array = terrain_context.get("direct_collision_shapes", [])
	var space_state := terrain_context.get("space_state") as PhysicsDirectSpaceState3D
	var contact_full_band := maxf(0.0, float(settings.get("contact_full_band", 0.08)))
	var contact_fade_distance := maxf(contact_full_band, float(settings.get("contact_fade_distance", 0.45)))
	var shallow_full_depth := maxf(0.0, float(settings.get("shallow_full_depth", 0.25)))
	var shallow_fade_depth := maxf(shallow_full_depth, float(settings.get("shallow_fade_depth", 1.25)))
	var protrusion_fade_height := maxf(0.0, float(settings.get("protrusion_fade_height", 0.03)))
	var protrusion_full_height := maxf(protrusion_fade_height, float(settings.get("protrusion_full_height", 0.20)))
	var raycast_up_offset := maxf(0.0, float(settings.get("raycast_up_offset", 0.75)))
	var raycast_down_distance := maxf(shallow_fade_depth, float(settings.get("raycast_down_distance", 1.50)))
	var hterrain_confidence := clampf(float(settings.get("hterrain_source_confidence", 1.0)), 0.0, 1.0)
	var physics_confidence := clampf(float(settings.get("physics_source_confidence", 0.5)), 0.0, 1.0)
	var source_selection_epsilon := maxf(0.0, float(settings.get("source_selection_epsilon", 0.02)))
	var selected: Dictionary = WaterHelperMethods._sample_hterrain_contact(hterrain_samplers, water_position, hterrain_confidence)
	var physics_sample: Dictionary = WaterHelperMethods._sample_physics_contact(space_state, direct_collision_shapes, water_position, raycast_up_offset, raycast_down_distance, raycast_layers, physics_confidence)
	if not physics_sample.is_empty():
		if selected.is_empty() or float(physics_sample.get("height", -INF)) > float(selected.get("height", -INF)) + source_selection_epsilon:
			selected = physics_sample
	if selected.is_empty():
		return {
			"color": _color_dict(Color(0.0, 0.0, 0.0, 0.0)),
			"has_contact": false,
			"source": "none",
		}
	var hit_height := float(selected.get("height", water_position.y))
	var delta := water_position.y - hit_height
	var abs_delta := absf(delta)
	var contact := WaterHelperMethods._falloff_mask(abs_delta, contact_full_band, contact_fade_distance)
	var shallow := 0.0
	if delta >= 0.0:
		shallow = WaterHelperMethods._falloff_mask(delta, shallow_full_depth, shallow_fade_depth)
	var protrusion := WaterHelperMethods._rise_mask(maxf(0.0, -delta), protrusion_fade_height, protrusion_full_height)
	var confidence := clampf(float(selected.get("confidence", 0.0)), 0.0, 1.0)
	return {
		"color": _color_dict(Color(contact, shallow, protrusion, confidence)),
		"has_contact": true,
		"source": String(selected.get("source", "unknown")),
		"hit_height": _round5(hit_height),
		"water_height": _round5(water_position.y),
		"delta": _round5(delta),
	}


func _contact_color(contact: Dictionary) -> Color:
	var color_dict: Dictionary = contact.get("color", {})
	return Color(
		float(color_dict.get("r", 0.0)),
		float(color_dict.get("g", 0.0)),
		float(color_dict.get("b", 0.0)),
		float(color_dict.get("a", 0.0))
	)


func _find_river_for_bake(node: Node, bake_path: String) -> Node:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current := stack.pop_back()
		for child in current.get_children():
			stack.push_back(child)
		var script = current.get_script()
		if script == null or script.resource_path != RIVER_SCRIPT_PATH:
			continue
		var bake_data := current.get("bake_data") as Resource
		if bake_data != null and bake_data.resource_path == bake_path:
			return current
	return null


func _get_bake_collision_root(mesh_instance: MeshInstance3D, river: Node) -> Node:
	if river != null and river.owner != null:
		return river.owner
	if mesh_instance != null and mesh_instance.owner != null:
		return mesh_instance.owner
	if mesh_instance != null and mesh_instance.get_tree().current_scene != null:
		return mesh_instance.get_tree().current_scene
	return root


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


func _tile_rect(step_index: int, side: int, source_rect: Rect2i) -> Rect2i:
	var safe_side := maxi(1, side)
	var column := int(step_index / safe_side)
	var row := step_index % safe_side
	var x0 := source_rect.position.x + int(floor(float(column) * float(source_rect.size.x) / float(safe_side)))
	var x1 := source_rect.position.x + int(floor(float(column + 1) * float(source_rect.size.x) / float(safe_side)))
	var y0 := source_rect.position.y + int(floor(float(row) * float(source_rect.size.y) / float(safe_side)))
	var y1 := source_rect.position.y + int(floor(float(row + 1) * float(source_rect.size.y) / float(safe_side)))
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


func _track_top_join(top: Array, join: Dictionary) -> void:
	top.append(join)
	top.sort_custom(Callable(self, "_sort_join_desc"))
	if top.size() > TOP_JOIN_LIMIT:
		top.resize(TOP_JOIN_LIMIT)


func _sort_join_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", 0.0)) > float(b.get("score", 0.0))


func _sample_t(sample_index: int, sample_count: int) -> float:
	if sample_count <= 1:
		return 0.5
	return (float(sample_index) + 0.5) / float(sample_count)


func _lerp_pixel(position: int, size: int, t: float) -> int:
	return position + clampi(int(floor(t * float(size))), 0, maxi(size - 1, 0))


func _color_delta_dict(first: Color, second: Color) -> Dictionary:
	return {
		"r": _round5(absf(first.r - second.r)),
		"g": _round5(absf(first.g - second.g)),
		"b": _round5(absf(first.b - second.b)),
		"a": _round5(absf(first.a - second.a)),
	}


func _color_dict(color: Color) -> Dictionary:
	return {
		"r": _round5(color.r),
		"g": _round5(color.g),
		"b": _round5(color.b),
		"a": _round5(color.a),
	}


func _vector3_dict(vector: Vector3) -> Dictionary:
	return {
		"x": _round5(vector.x),
		"y": _round5(vector.y),
		"z": _round5(vector.z),
	}


func _rounded_dict(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values.keys():
		result[key] = _round5(float(values[key]))
	return result


func _round5(value: float) -> float:
	return snappedf(value, 0.00001)


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
