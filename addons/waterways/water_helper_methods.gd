# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.

const MIN_DIRECTION_LENGTH_SQUARED := 0.000001
const MIN_RIVER_WIDTH := 0.001
const MIN_UV_TRIANGLE_AREA := 0.000000000001
const MIN_BARYCENTRIC_DENOMINATOR := 0.000000000000000001
const BARYCENTRIC_EDGE_EPSILON := 0.00001
const EXTERNAL_BAKE_STORAGE_VERSION := 1
const EXTERNAL_BAKE_ROOT := "res://waterways_bakes"
const RIVER_SCRIPT_PATH := "res://addons/waterways/river_manager.gd"
const WATER_SYSTEM_SCRIPT_PATH := "res://addons/waterways/water_system_manager.gd"
const RIVER_BAKE_SUFFIX := ".river_bake.res"
const WATER_SYSTEM_BAKE_SUFFIX := ".water_system_bake.res"
const SAFE_FILENAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
const SHAPE_STEP_DIVS_MIN := 1
const SHAPE_STEP_DIVS_MAX := 8
const SHAPE_SMOOTHNESS_MIN := 0.1
const SHAPE_SMOOTHNESS_MAX := 5.0
const FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD := 0.02
const POLYGON_SHAPE_AABB_EPSILON := 0.0001
const POLYGON_HULL_PLANE_EPSILON := 0.0001

static var _polygon_shape_local_aabb_cache: Dictionary = {}
static var _convex_shape_planes_cache: Dictionary = {}


static func clear_polygon_shape_intersection_caches() -> void:
	_polygon_shape_local_aabb_cache.clear()
	_convex_shape_planes_cache.clear()


static func save_river_bake_data(owner: Node, bake_data: Resource) -> Dictionary:
	return _save_external_bake_data(owner, bake_data, RIVER_SCRIPT_PATH, RIVER_BAKE_SUFFIX)


static func save_water_system_bake_data(owner: Node, bake_data: Resource) -> Dictionary:
	return _save_external_bake_data(owner, bake_data, WATER_SYSTEM_SCRIPT_PATH, WATER_SYSTEM_BAKE_SUFFIX)


static func has_external_bake_path(bake_data: Resource) -> bool:
	return not _get_existing_external_bake_path(bake_data).is_empty()


static func _save_external_bake_data(owner: Node, bake_data: Resource, owner_script_path: String, file_suffix: String) -> Dictionary:
	var result := {
		"saved": false,
		"path": "",
		"requires_saved_scene": false,
		"error": OK,
		"message": ""
	}
	if not Engine.is_editor_hint():
		result.message = "External bake storage is editor-only."
		return result
	if owner == null or bake_data == null:
		result.error = ERR_INVALID_PARAMETER
		result.message = "Cannot save Waterways bake data without a node and bake resource."
		return result
	var existing_path := _get_existing_external_bake_path(bake_data)
	var scene_root := _get_scene_root_for_bake(owner)
	var scene_path := _get_scene_path(scene_root, owner)
	var target_path := existing_path
	if target_path.is_empty():
		if scene_path.is_empty():
			result.requires_saved_scene = true
			result.message = "Save the scene, then rebake to create a scene-owned external Waterways bake resource."
			return result
		target_path = _get_default_bake_path(owner, scene_root, scene_path, owner_script_path, file_suffix)
	var target_folder := target_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_folder))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		result.error = dir_error
		result.message = "Could not create Waterways bake folder: " + target_folder
		return result
	_write_bake_storage_metadata(bake_data, scene_root, owner, scene_path, target_path)
	var save_flags := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	var save_error := ResourceSaver.save(bake_data, target_path, save_flags)
	result.error = save_error
	if save_error != OK:
		result.message = "Could not save Waterways bake resource: " + target_path
		return result
	bake_data.take_over_path(target_path)
	result.saved = true
	result.path = target_path
	result.message = "Saved Waterways bake resource: " + target_path
	_rescan_editor_filesystem()
	return result


static func _get_existing_external_bake_path(bake_data: Resource) -> String:
	if bake_data == null:
		return ""
	var path := bake_data.resource_path
	if path.begins_with("res://") and path.find("::") == -1 and path.get_extension().to_lower() == "res":
		return path
	return ""


static func _get_scene_root_for_bake(owner: Node) -> Node:
	if owner != null and owner.is_inside_tree():
		var tree := owner.get_tree()
		if Engine.is_editor_hint() and tree.has_method("get_edited_scene_root"):
			var edited_scene = tree.call("get_edited_scene_root")
			if edited_scene is Node:
				var edited_node := edited_scene as Node
				if edited_node == owner or edited_node.is_ancestor_of(owner):
					return edited_node
		if tree.current_scene != null and (tree.current_scene == owner or tree.current_scene.is_ancestor_of(owner)):
			return tree.current_scene
	if owner != null and owner.owner != null:
		return owner.owner
	return owner


static func _get_scene_path(scene_root: Node, owner: Node) -> String:
	if scene_root != null and not scene_root.scene_file_path.is_empty():
		return scene_root.scene_file_path
	if owner != null and owner.owner != null and not owner.owner.scene_file_path.is_empty():
		return owner.owner.scene_file_path
	return ""


static func _get_default_bake_path(owner: Node, scene_root: Node, scene_path: String, owner_script_path: String, file_suffix: String) -> String:
	var folder := _get_scene_bake_folder(scene_path)
	var base_filename := _get_default_bake_filename(owner, file_suffix)
	var filename := base_filename
	var filename_counts := _get_default_bake_filename_counts(scene_root, owner_script_path, file_suffix)
	if int(filename_counts.get(base_filename, 0)) > 1:
		filename = _get_default_bake_filename(owner, file_suffix, _get_scene_relative_node_path(scene_root, owner))
	return _join_res_path(folder, filename)


static func _get_scene_bake_folder(scene_path: String) -> String:
	var scene_key := _sanitize_file_stem(scene_path.trim_prefix("res://").get_basename().replace("/", "_").replace("\\", "_"))
	var folder := _join_res_path(EXTERNAL_BAKE_ROOT, scene_key)
	if _folder_has_foreign_scene_bakes(folder, scene_path):
		folder = _join_res_path(EXTERNAL_BAKE_ROOT, scene_key + "_" + _stable_short_suffix(scene_path))
	return folder


static func _get_default_bake_filename(owner: Node, file_suffix: String, relative_node_path := "") -> String:
	var stem := "BakeData"
	if owner != null:
		stem = _sanitize_file_stem(owner.name)
	if not relative_node_path.is_empty():
		stem += "_" + _stable_short_suffix(relative_node_path)
	return stem + file_suffix


static func _get_default_bake_filename_counts(scene_root: Node, owner_script_path: String, file_suffix: String) -> Dictionary:
	var counts := {}
	for node in _collect_scene_bake_targets(scene_root, owner_script_path):
		var filename := _get_default_bake_filename(node, file_suffix)
		counts[filename] = int(counts.get(filename, 0)) + 1
	return counts


static func _collect_scene_bake_targets(scene_root: Node, owner_script_path: String) -> Array:
	var targets := []
	if scene_root == null:
		return targets
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		var script = node.get_script()
		if script != null and script.resource_path == owner_script_path:
			targets.append(node)
	return targets


static func _folder_has_foreign_scene_bakes(folder_path: String, scene_path: String) -> bool:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var filename := dir.get_next()
	while not filename.is_empty():
		if not dir.current_is_dir() and filename.get_extension().to_lower() == "res":
			var resource := ResourceLoader.load(_join_res_path(folder_path, filename))
			if resource != null:
				var metadata = resource.get("source_metadata")
				if typeof(metadata) == TYPE_DICTIONARY:
					var stored_scene_path := String(metadata.get("scene_path", ""))
					if not stored_scene_path.is_empty() and stored_scene_path != scene_path:
						dir.list_dir_end()
						return true
		filename = dir.get_next()
	dir.list_dir_end()
	return false


static func _write_bake_storage_metadata(bake_data: Resource, scene_root: Node, owner: Node, scene_path: String, target_path: String) -> void:
	var source_metadata = bake_data.get("source_metadata")
	var metadata := {}
	if typeof(source_metadata) == TYPE_DICTIONARY:
		metadata = source_metadata.duplicate(true)
	metadata["scene_path"] = scene_path
	metadata["node_path"] = _get_scene_relative_node_path(scene_root, owner)
	metadata["node_name"] = owner.name if owner != null else ""
	metadata["bake_resource_path"] = target_path
	metadata["storage_version"] = EXTERNAL_BAKE_STORAGE_VERSION
	bake_data.set("source_metadata", metadata)


static func _get_scene_relative_node_path(scene_root: Node, node: Node) -> String:
	if node == null:
		return ""
	if scene_root == node:
		return "."
	if scene_root != null and scene_root.is_ancestor_of(node):
		return str(scene_root.get_path_to(node))
	if node.owner != null and node.owner.is_ancestor_of(node):
		return str(node.owner.get_path_to(node))
	return str(node.get_path())


static func _join_res_path(folder: String, filename: String) -> String:
	if folder.ends_with("/"):
		return folder + filename
	return folder + "/" + filename


static func _sanitize_file_stem(value: String) -> String:
	var text := value.strip_edges()
	if text.is_empty():
		text = "BakeData"
	var result := ""
	for index in text.length():
		var character := text.substr(index, 1)
		if SAFE_FILENAME_CHARS.find(character) != -1:
			result += character
		else:
			result += "_"
	while result.find("__") != -1:
		result = result.replace("__", "_")
	while result.begins_with("_") and result.length() > 1:
		result = result.substr(1)
	while result.ends_with("_") and result.length() > 1:
		result = result.substr(0, result.length() - 1)
	if result == "_":
		result = "BakeData"
	return result


static func _stable_short_suffix(value: String) -> String:
	var hash_value := value.hash()
	if hash_value < 0:
		hash_value = -hash_value
	var suffix := str(hash_value % 100000)
	while suffix.length() < 5:
		suffix = "0" + suffix
	return suffix


static func _rescan_editor_filesystem() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_resource_filesystem"):
		return
	var resource_filesystem = editor_interface.call("get_resource_filesystem")
	if resource_filesystem != null and resource_filesystem.has_method("scan"):
		resource_filesystem.call_deferred("scan")


static func cart2bary(p : Vector3, a : Vector3, b : Vector3, c: Vector3) -> Vector3:
	if not _is_finite_vector3(p) or not _is_finite_vector3(a) or not _is_finite_vector3(b) or not _is_finite_vector3(c):
		return Vector3(-1.0, -1.0, -1.0)
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if not _is_finite_number(denom) or abs(denom) <= MIN_BARYCENTRIC_DENOMINATOR:
		return Vector3(-1.0, -1.0, -1.0)
	var v = (d11 * d20 - d01 * d21) / denom
	var w = (d00 * d21 - d01 * d20) / denom
	var u = 1.0 - v - w
	if not _is_finite_number(u) or not _is_finite_number(v) or not _is_finite_number(w):
		return Vector3(-1.0, -1.0, -1.0)
	return Vector3(u, v, w)


static func bary2cart(a : Vector3, b : Vector3, c: Vector3, barycentric: Vector3) -> Vector3:
	return barycentric.x * a + barycentric.y * b + barycentric.z * c


static func point_in_bariatric(v : Vector3) -> bool:
	if not _is_finite_vector3(v):
		return false
	return -BARYCENTRIC_EDGE_EPSILON <= v.x and v.x <= 1.0 + BARYCENTRIC_EDGE_EPSILON and -BARYCENTRIC_EDGE_EPSILON <= v.y and v.y <= 1.0 + BARYCENTRIC_EDGE_EPSILON and -BARYCENTRIC_EDGE_EPSILON <= v.z and v.z <= 1.0 + BARYCENTRIC_EDGE_EPSILON;


static func reset_all_colliders(node):
	for n in node.get_children():
		if n.get_child_count() > 0:
			reset_all_colliders(n)
		if n is CollisionShape3D:
			if n.disabled == false:
				n.disabled = true
				n.disabled = false


static func collect_raycast_collision_shapes(scene_root: Node, raycast_layers: int) -> Array:
	var collision_shapes := []
	if scene_root == null:
		return collision_shapes
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if not node is CollisionShape3D:
			continue
		var collision_shape := node as CollisionShape3D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		var collision_parent := collision_shape.get_parent()
		if not collision_parent is CollisionObject3D:
			continue
		if not collision_parent is PhysicsBody3D:
			continue
		if ((collision_parent as CollisionObject3D).collision_layer & raycast_layers) == 0:
			continue
		collision_shapes.append(collision_shape)
	return collision_shapes


static func collect_hterrain_samplers(scene_root: Node, raycast_layers: int) -> Array:
	var terrains := []
	if scene_root == null or raycast_layers == 0:
		return terrains
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if not _looks_like_hterrain(node):
			continue
		var collision_enabled = node.get("collision_enabled")
		if typeof(collision_enabled) == TYPE_BOOL and not bool(collision_enabled):
			continue
		var collision_layer = node.get("collision_layer")
		if typeof(collision_layer) != TYPE_INT and typeof(collision_layer) != TYPE_FLOAT:
			continue
		if (int(collision_layer) & raycast_layers) == 0:
			continue
		var terrain_data = node.call("get_data")
		if terrain_data == null or not terrain_data.has_method("get_interpolated_height_at"):
			continue
		terrains.append(node)
	return terrains


static func _looks_like_hterrain(node: Node) -> bool:
	return node != null \
		and node.has_method("world_to_map") \
		and node.has_method("get_internal_transform") \
		and node.has_method("get_data")


static func calculate_side(steps : int) -> int:
	var safe_steps := max(1, steps)
	var side_float : float = sqrt(float(safe_steps))
	if fmod(side_float, 1.0) != 0.0:
		side_float += 1.0
	return int(side_float)


# R3.5 (2026-06-12): probes read OCCUPANCY_SPEED_RAMP_FULL from the shader
# include that declares it instead of mirroring the value (it had drifted into
# 7 hand-synced copies). Parses the single-line const declaration; returns
# -1.0 (after push_error) when the include or declaration is missing so
# callers fail loudly instead of comparing against a stale mirror.
static func get_occupancy_speed_ramp_full() -> float:
	const INCLUDE_PATH := "res://addons/waterways/shaders/river_surface_common.gdshaderinc"
	var source := FileAccess.get_file_as_string(INCLUDE_PATH)
	if source.is_empty():
		push_error("Cannot read " + INCLUDE_PATH + " to resolve OCCUPANCY_SPEED_RAMP_FULL.")
		return -1.0
	var regex := RegEx.new()
	regex.compile("const\\s+float\\s+OCCUPANCY_SPEED_RAMP_FULL\\s*=\\s*([0-9.]+)\\s*;")
	var regex_match := regex.search(source)
	if regex_match == null:
		push_error("OCCUPANCY_SPEED_RAMP_FULL declaration not found in " + INCLUDE_PATH + ".")
		return -1.0
	return float(regex_match.get_string(1))


# GDScript mirror of the canonical shader-side flow codec in
# shaders/flow_pack.gdshaderinc (rg = v * 0.5 + 0.5, neutral 0.5) - GDScript
# cannot consume a shader include, so keep the two in sync.
static func decode_packed_flow_vector(color: Color) -> Vector2:
	return Vector2((color.r - 0.5) * 2.0, (color.g - 0.5) * 2.0)


static func encode_packed_flow_vector(vector: Vector2) -> Color:
	return Color(clampf(vector.x * 0.5 + 0.5, 0.0, 1.0), clampf(vector.y * 0.5 + 0.5, 0.0, 1.0), 0.0, 1.0)


static func create_downstream_baseline_flow_image(resolution: int, uv2_sides: int, occupied_steps: int, strength: float = 1.0) -> Image:
	var safe_resolution: int = maxi(1, resolution)
	var safe_side: int = maxi(1, uv2_sides)
	var total_tiles := safe_side * safe_side
	var safe_occupied_steps: int = clampi(occupied_steps, 0, total_tiles)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var neutral_color := encode_packed_flow_vector(Vector2.ZERO)
	image.fill(neutral_color)
	var downstream_color := encode_packed_flow_vector(Vector2(0.0, clampf(strength, 0.0, 1.0)))
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := get_uv2_atlas_tile_rect(step_index, safe_side, source_rect)
		image.fill_rect(tile_rect, downstream_color)
	return image


static func create_solid_occupancy_source_image(collision_image: Image, terrain_contact_image: Image, protrusion_threshold: float = 0.5, protrusion_confidence_min: float = 0.0) -> Image:
	if collision_image == null or collision_image.is_empty():
		return collision_image
	var width := collision_image.get_width()
	var height := collision_image.get_height()
	var occupancy := Image.create(width, height, false, Image.FORMAT_RGBA8)
	occupancy.fill(Color(0.0, 0.0, 0.0, 1.0))
	var has_terrain_contact := terrain_contact_image != null and not terrain_contact_image.is_empty() \
			and terrain_contact_image.get_width() == width and terrain_contact_image.get_height() == height
	var safe_threshold := clampf(protrusion_threshold, 0.0, 1.0)
	var safe_confidence_min := clampf(protrusion_confidence_min, 0.0, 1.0)
	for y in height:
		for x in width:
			var solid := collision_image.get_pixel(x, y).r > 0.5
			if not solid and has_terrain_contact:
				# Only high-confidence (heightfield-sourced) protrusion may add
				# solids: heightfields cannot overhang, so terrain above the
				# water there really displaces the water column. Physics-collider
				# protrusion is overhang-blind (the down-ray hits a boulder's
				# top even when open water passes beneath) and is redundant
				# anyway - the same colliders are baked into collision_image
				# with a facing-aware overhang exemption.
				var contact := terrain_contact_image.get_pixel(x, y)
				solid = contact.b >= safe_threshold and contact.a >= safe_confidence_min
			if solid:
				occupancy.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	return occupancy


static func neutralize_unused_uv2_atlas_flow_rg(image: Image, uv2_sides: int, occupied_steps: int, content_rect: Rect2i = Rect2i()) -> void:
	if image == null or image.is_empty():
		return
	var source_rect := _clamp_image_rect(image, content_rect)
	var side: int = maxi(1, uv2_sides)
	if side <= 1 and occupied_steps > 1:
		side = calculate_side(occupied_steps)
	var total_tiles := side * side
	var safe_occupied_steps: int = clampi(occupied_steps, 0, total_tiles)
	for step_index in range(safe_occupied_steps, total_tiles):
		var tile_rect := get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			for x in tile_rect.size.x:
				var pixel_position := Vector2i(tile_rect.position.x + x, tile_rect.position.y + y)
				var color := image.get_pixelv(pixel_position)
				color.r = 0.5
				color.g = 0.5
				image.set_pixelv(pixel_position, color)


static func synchronize_uv2_logical_edge_bands(image: Image, uv2_sides: int, occupied_steps: int, content_rect: Rect2i = Rect2i(), band_depth: int = 1) -> void:
	if image == null or image.is_empty():
		return
	var source_rect := _clamp_image_rect(image, content_rect)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return
	var side: int = maxi(1, uv2_sides)
	if side <= 1 and occupied_steps > 1:
		side = calculate_side(occupied_steps)
	var total_tiles := side * side
	var safe_occupied_steps: int = clampi(occupied_steps, 0, total_tiles)
	var safe_band_depth := maxi(0, band_depth)
	if safe_occupied_steps <= 1 or safe_band_depth <= 0:
		return
	for step_index in range(safe_occupied_steps - 1):
		var from_tile := get_uv2_atlas_tile_rect(step_index, side, source_rect)
		var to_tile := get_uv2_atlas_tile_rect(step_index + 1, side, source_rect)
		_synchronize_uv2_longitudinal_edge_band(image, from_tile, to_tile, safe_band_depth)


static func _synchronize_uv2_longitudinal_edge_band(image: Image, from_tile: Rect2i, to_tile: Rect2i, band_depth: int) -> void:
	if from_tile.size.x <= 0 or from_tile.size.y <= 0 or to_tile.size.x <= 0 or to_tile.size.y <= 0:
		return
	var max_depth := mini(band_depth, mini(from_tile.size.y, to_tile.size.y))
	var sample_count := maxi(from_tile.size.x, to_tile.size.x)
	for depth in max_depth:
		var from_y := from_tile.position.y + from_tile.size.y - 1 - depth
		var to_y := to_tile.position.y + depth
		for sample_index in sample_count:
			var t := _edge_sample_t(sample_index, sample_count)
			var from_x := _edge_lerp_pixel(from_tile.position.x, from_tile.size.x, t)
			var to_x := _edge_lerp_pixel(to_tile.position.x, to_tile.size.x, t)
			var from_pixel := Vector2i(from_x, from_y)
			var to_pixel := Vector2i(to_x, to_y)
			var average := _average_color(image.get_pixelv(from_pixel), image.get_pixelv(to_pixel))
			image.set_pixelv(from_pixel, average)
			image.set_pixelv(to_pixel, average)


# Applies a small separable binomial blur to each occupied UV2 tile of a
# source-resolution feature image. Smooths residual single-texel
# classification steps (steep banks cross a whole mask ramp inside one
# texel) into multi-texel ramps that bilinear sampling renders smoothly.
# Blur is clamped at tile edges: atlas-adjacent tiles are not always
# world-adjacent, so cross-tile bleed would mix unrelated river segments.
static func smooth_uv2_tile_channels(image: Image, uv2_sides: int, occupied_steps: int, passes: int = 1) -> void:
	if image == null or image.is_empty() or passes <= 0:
		return
	var side := maxi(1, uv2_sides)
	if side <= 1 and occupied_steps > 1:
		side = calculate_side(occupied_steps)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	var source_rect := Rect2i(Vector2i.ZERO, image.get_size())
	for step_index in safe_occupied_steps:
		var tile := get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for pass_index in passes:
			_blur_tile_separable(image, tile)


static func _blur_tile_separable(image: Image, tile: Rect2i) -> void:
	if tile.size.x <= 0 or tile.size.y <= 0:
		return
	var weights: Array[float] = [1.0 / 16.0, 4.0 / 16.0, 6.0 / 16.0, 4.0 / 16.0, 1.0 / 16.0]
	var source := image.get_region(tile)
	# Float intermediate avoids quantizing twice through an 8-bit buffer.
	var horizontal := Image.create(tile.size.x, tile.size.y, false, Image.FORMAT_RGBAF)
	for y in tile.size.y:
		for x in tile.size.x:
			var accumulated := Color(0.0, 0.0, 0.0, 0.0)
			for tap in 5:
				var sample_x := clampi(x + tap - 2, 0, tile.size.x - 1)
				accumulated += source.get_pixel(sample_x, y) * weights[tap]
			horizontal.set_pixel(x, y, accumulated)
	for y in tile.size.y:
		for x in tile.size.x:
			var accumulated := Color(0.0, 0.0, 0.0, 0.0)
			for tap in 5:
				var sample_y := clampi(y + tap - 2, 0, tile.size.y - 1)
				accumulated += horizontal.get_pixel(x, sample_y) * weights[tap]
			image.set_pixel(tile.position.x + x, tile.position.y + y, accumulated)


static func _edge_sample_t(sample_index: int, sample_count: int) -> float:
	if sample_count <= 1:
		return 0.5
	return (float(sample_index) + 0.5) / float(sample_count)


static func _edge_lerp_pixel(position: int, size: int, t: float) -> int:
	return position + clampi(int(floor(t * float(size))), 0, maxi(size - 1, 0))


static func _average_color(a: Color, b: Color) -> Color:
	return Color((a.r + b.r) * 0.5, (a.g + b.g) * 0.5, (a.b + b.b) * 0.5, (a.a + b.a) * 0.5)


static func get_decoded_flow_vector_stats(image: Image, rect: Rect2i = Rect2i(), near_neutral_threshold: float = FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD, alpha_threshold: float = -1.0) -> Dictionary:
	var sample_rect := _clamp_image_rect(image, rect)
	if sample_rect.size.x <= 0 or sample_rect.size.y <= 0:
		return _empty_flow_vector_stats(near_neutral_threshold, alpha_threshold, 1)
	return _get_decoded_flow_vector_stats_for_rects(image, [sample_rect], near_neutral_threshold, alpha_threshold)


static func get_uv2_atlas_decoded_flow_vector_stats(image: Image, uv2_sides: int, occupied_steps: int, content_rect: Rect2i = Rect2i(), near_neutral_threshold: float = FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD, alpha_threshold: float = -1.0) -> Dictionary:
	var source_rect := _clamp_image_rect(image, content_rect)
	var side: int = maxi(1, uv2_sides)
	if side <= 1 and occupied_steps > 1:
		side = calculate_side(occupied_steps)
	var total_tiles := side * side
	var safe_occupied_steps: int = clampi(occupied_steps, 0, total_tiles)
	var occupied_rects := []
	var unused_rects := []
	for step_index in total_tiles:
		var tile_rect := get_uv2_atlas_tile_rect(step_index, side, source_rect)
		if tile_rect.size.x <= 0 or tile_rect.size.y <= 0:
			continue
		if step_index < safe_occupied_steps:
			occupied_rects.append(tile_rect)
		else:
			unused_rects.append(tile_rect)
	return {
		"source_rect": source_rect,
		"uv2_sides": side,
		"occupied_tile_count": occupied_rects.size(),
		"unused_tile_count": unused_rects.size(),
		"occupied": _get_decoded_flow_vector_stats_for_rects(image, occupied_rects, near_neutral_threshold, alpha_threshold),
		"unused": _get_decoded_flow_vector_stats_for_rects(image, unused_rects, near_neutral_threshold, alpha_threshold)
	}


static func get_uv2_atlas_tile_rect(step_index: int, side: int, source_rect: Rect2i) -> Rect2i:
	var safe_side: int = maxi(1, side)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return Rect2i()
	var column := int(step_index / safe_side)
	var row := step_index % safe_side
	var x0 := source_rect.position.x + int(floor(float(column) * float(source_rect.size.x) / float(safe_side)))
	var x1 := source_rect.position.x + int(floor(float(column + 1) * float(source_rect.size.x) / float(safe_side)))
	var y0 := source_rect.position.y + int(floor(float(row) * float(source_rect.size.y) / float(safe_side)))
	var y1 := source_rect.position.y + int(floor(float(row + 1) * float(source_rect.size.y) / float(safe_side)))
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


static func format_decoded_flow_vector_stats(label: String, stats: Dictionary) -> String:
	if stats.is_empty() or not bool(stats.get("valid", false)):
		return label + " flow_stats=no_pixels"
	var threshold := float(stats.get("near_neutral_threshold", FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD))
	var average_vector: Vector2 = stats.get("average_vector", Vector2.ZERO)
	var min_rg: Vector2 = stats.get("min_rg", Vector2.ZERO)
	var max_rg: Vector2 = stats.get("max_rg", Vector2.ZERO)
	var alpha_suffix := ""
	if float(stats.get("alpha_threshold", -1.0)) >= 0.0:
		alpha_suffix = " alpha_gt_%.4f_skipped=%d" % [float(stats.get("alpha_threshold", -1.0)), int(stats.get("alpha_skipped_pixel_count", 0))]
	return "%s pixels=%d active_mag_gt_%.3f=%d near_neutral=%.2f%% mag_min=%.6f mag_median=%.6f mag_avg=%.6f mag_max=%.6f avg_vec=(%.4f, %.4f) range_rg=(%.4f..%.4f, %.4f..%.4f)%s" % [
		label,
		int(stats.get("sampled_pixel_count", 0)),
		threshold,
		int(stats.get("active_pixel_count", 0)),
		float(stats.get("near_neutral_percent", 0.0)),
		float(stats.get("min_magnitude", 0.0)),
		float(stats.get("median_magnitude", 0.0)),
		float(stats.get("average_magnitude", 0.0)),
		float(stats.get("max_magnitude", 0.0)),
		average_vector.x,
		average_vector.y,
		min_rg.x,
		max_rg.x,
		min_rg.y,
		max_rg.y,
		alpha_suffix
	]


static func _clamp_image_rect(image: Image, rect: Rect2i) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var image_size := image.get_size()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i(Vector2i.ZERO, image_size)
	var x0: int = clampi(rect.position.x, 0, image_size.x)
	var y0: int = clampi(rect.position.y, 0, image_size.y)
	var x1: int = clampi(rect.position.x + rect.size.x, x0, image_size.x)
	var y1: int = clampi(rect.position.y + rect.size.y, y0, image_size.y)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


static func _get_decoded_flow_vector_stats_for_rects(image: Image, rects: Array, near_neutral_threshold: float, alpha_threshold: float) -> Dictionary:
	var stats := _empty_flow_vector_stats(near_neutral_threshold, alpha_threshold, rects.size())
	if image == null or image.is_empty() or rects.is_empty():
		return stats
	var safe_threshold := max(0.0, near_neutral_threshold)
	var magnitudes := []
	var sum_magnitude := 0.0
	var sum_vector := Vector2.ZERO
	var sum_rg := Vector2.ZERO
	var min_vector := Vector2(INF, INF)
	var max_vector := Vector2(-INF, -INF)
	var min_rg := Vector2(INF, INF)
	var max_rg := Vector2(-INF, -INF)
	var min_magnitude := INF
	var max_magnitude := -INF
	var sampled_pixels := 0
	var total_pixels := 0
	var alpha_skipped_pixels := 0
	var near_neutral_pixels := 0
	for raw_rect in rects:
		if typeof(raw_rect) != TYPE_RECT2I:
			continue
		var raw_rect2i: Rect2i = raw_rect
		var rect := _clamp_image_rect(image, raw_rect2i)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		total_pixels += rect.size.x * rect.size.y
		for y in rect.size.y:
			for x in rect.size.x:
				var pixel := image.get_pixel(rect.position.x + x, rect.position.y + y)
				if alpha_threshold >= 0.0 and pixel.a <= alpha_threshold:
					alpha_skipped_pixels += 1
					continue
				var vector := decode_packed_flow_vector(pixel)
				var magnitude := vector.length()
				magnitudes.append(magnitude)
				sampled_pixels += 1
				sum_magnitude += magnitude
				sum_vector += vector
				sum_rg += Vector2(pixel.r, pixel.g)
				min_magnitude = min(min_magnitude, magnitude)
				max_magnitude = max(max_magnitude, magnitude)
				min_vector.x = min(min_vector.x, vector.x)
				min_vector.y = min(min_vector.y, vector.y)
				max_vector.x = max(max_vector.x, vector.x)
				max_vector.y = max(max_vector.y, vector.y)
				min_rg.x = min(min_rg.x, pixel.r)
				min_rg.y = min(min_rg.y, pixel.g)
				max_rg.x = max(max_rg.x, pixel.r)
				max_rg.y = max(max_rg.y, pixel.g)
				if magnitude <= safe_threshold:
					near_neutral_pixels += 1
	if sampled_pixels <= 0:
		stats["total_pixel_count"] = total_pixels
		stats["alpha_skipped_pixel_count"] = alpha_skipped_pixels
		return stats
	magnitudes.sort()
	var median_magnitude := 0.0
	var middle_index := int(floor(float(magnitudes.size()) * 0.5))
	if magnitudes.size() % 2 == 0:
		median_magnitude = (float(magnitudes[middle_index - 1]) + float(magnitudes[middle_index])) * 0.5
	else:
		median_magnitude = float(magnitudes[middle_index])
	stats["valid"] = true
	stats["total_pixel_count"] = total_pixels
	stats["sampled_pixel_count"] = sampled_pixels
	stats["alpha_skipped_pixel_count"] = alpha_skipped_pixels
	stats["near_neutral_pixel_count"] = near_neutral_pixels
	stats["active_pixel_count"] = sampled_pixels - near_neutral_pixels
	stats["near_neutral_percent"] = 100.0 * float(near_neutral_pixels) / float(sampled_pixels)
	stats["active_percent"] = 100.0 * float(sampled_pixels - near_neutral_pixels) / float(sampled_pixels)
	stats["min_magnitude"] = min_magnitude
	stats["max_magnitude"] = max_magnitude
	stats["average_magnitude"] = sum_magnitude / float(sampled_pixels)
	stats["median_magnitude"] = median_magnitude
	stats["min_vector"] = min_vector
	stats["max_vector"] = max_vector
	stats["average_vector"] = sum_vector / float(sampled_pixels)
	stats["min_rg"] = min_rg
	stats["max_rg"] = max_rg
	stats["average_rg"] = sum_rg / float(sampled_pixels)
	return stats


static func _empty_flow_vector_stats(near_neutral_threshold: float, alpha_threshold: float, rect_count: int) -> Dictionary:
	return {
		"valid": false,
		"rect_count": rect_count,
		"near_neutral_threshold": max(0.0, near_neutral_threshold),
		"alpha_threshold": alpha_threshold,
		"total_pixel_count": 0,
		"sampled_pixel_count": 0,
		"alpha_skipped_pixel_count": 0,
		"near_neutral_pixel_count": 0,
		"active_pixel_count": 0,
		"near_neutral_percent": 0.0,
		"active_percent": 0.0,
		"min_magnitude": 0.0,
		"max_magnitude": 0.0,
		"average_magnitude": 0.0,
		"median_magnitude": 0.0,
		"min_vector": Vector2.ZERO,
		"max_vector": Vector2.ZERO,
		"average_vector": Vector2.ZERO,
		"min_rg": Vector2.ZERO,
		"max_rg": Vector2.ZERO,
		"average_rg": Vector2.ZERO
	}


static func generate_river_width_values(curve : Curve3D, steps : int, step_length_divs : int, step_width_divs : int, widths : Array) -> Array:
	var river_width_values := []
	if curve.get_point_count() < 2 or widths.size() < 2:
		river_width_values.append(1.0)
		return river_width_values
	var safe_steps := max(1, steps)
	var safe_step_length_divs: int = clamp(step_length_divs, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX)
	var sample_count: int = safe_steps * safe_step_length_divs
	var length = curve.get_baked_length()
	var last_width_index: int = min(curve.get_point_count(), widths.size()) - 1
	for step in sample_count + 1:
		if step == 0:
			river_width_values.append(_safe_width_value(widths, 0))
			continue
		if step == sample_count:
			river_width_values.append(_safe_width_value(widths, last_width_index))
			continue
		var target_pos = curve.sample_baked((float(step) / float(sample_count)) * length)
		var closest_dist := 4096.0
		var closest_interpolate := 0.0
		var closest_point := 0
		for c_point in last_width_index:
			for i in 101:
				var interpolate := float(i) / 100.0
				var pos = curve.sample(c_point, interpolate)
				var dist = pos.distance_to(target_pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_interpolate = interpolate
					closest_point = c_point
		# Smoothstep-eased interpolation keeps the width derivative continuous
		# across curve points (no visible kinks in the bank lines).
		var eased_interpolate := smoothstep(0.0, 1.0, closest_interpolate)
		river_width_values.append(max(MIN_RIVER_WIDTH, lerp(_safe_width_value(widths, closest_point), _safe_width_value(widths, closest_point + 1), eased_interpolate)))
	
	return river_width_values


static func generate_river_mesh(curve : Curve3D, steps : int, step_length_divs : int, step_width_divs : int, smoothness : float, river_width_values : Array, uv2_source_resolution : int = 0) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var safe_steps := max(1, steps)
	var safe_step_length_divs: int = clamp(step_length_divs, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX)
	var safe_step_width_divs: int = clamp(step_width_divs, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX)
	var step_count: int = safe_steps * safe_step_length_divs
	var curve_length := curve.get_baked_length()
	var safe_smoothness := smoothness
	if not _is_finite_number(safe_smoothness):
		safe_smoothness = 0.5
	safe_smoothness = clamp(safe_smoothness, SHAPE_SMOOTHNESS_MIN, SHAPE_SMOOTHNESS_MAX)

	var rows := []
	var center_positions := []
	for step in step_count + 1:
		var row := []
		var position := _sample_river_position(curve, step, step_count, curve_length)
		var backward_pos := _sample_river_position(curve, float(step) - safe_smoothness, step_count, curve_length)
		var forward_pos := _sample_river_position(curve, float(step) + safe_smoothness, step_count, curve_length)
		var right_vector := _safe_right_vector(forward_pos - backward_pos)
		var width_lerp := MIN_RIVER_WIDTH
		if step < river_width_values.size():
			width_lerp = max(MIN_RIVER_WIDTH, float(river_width_values[step]))
		for w_sub in safe_step_width_divs + 1:
			var width_ratio := float(w_sub) / float(safe_step_width_divs)
			row.append(position + right_vector * width_lerp - 2.0 * right_vector * width_lerp * width_ratio)
		center_positions.append(position)
		rows.append(row)

	_resolve_river_row_overlaps(rows, center_positions, safe_step_width_divs)

	var grid_side := calculate_side(safe_steps)
	var grid_side_length := 1.0 / float(grid_side)
	var x_grid_sub_length := grid_side_length / float(safe_step_width_divs)
	var y_grid_sub_length := grid_side_length / float(safe_step_length_divs)
	var safe_uv2_source_resolution := max(1, uv2_source_resolution)
	for step in step_count:
		var step_quad := int(step / safe_step_length_divs)
		var tile_x := int(step_quad / grid_side)
		var tile_y := int(step_quad % grid_side)
		var sub_y := int(step % safe_step_length_divs)
		for w_sub in safe_step_width_divs:
			var uv2_origin := Vector2.ZERO
			var uv2_right := Vector2.ZERO
			var uv2_down := Vector2.ZERO
			var uv2_diag := Vector2.ZERO
			if uv2_source_resolution > 0:
				var tile_uv_rect := _uv2_tile_pixel_center_rect(tile_x, tile_y, grid_side, safe_uv2_source_resolution)
				var local_x0 := float(w_sub) / float(safe_step_width_divs)
				var local_x1 := float(w_sub + 1) / float(safe_step_width_divs)
				var local_y0 := float(sub_y) / float(safe_step_length_divs)
				var local_y1 := float(sub_y + 1) / float(safe_step_length_divs)
				uv2_origin = Vector2(lerpf(tile_uv_rect.position.x, tile_uv_rect.end.x, local_x0), lerpf(tile_uv_rect.position.y, tile_uv_rect.end.y, local_y0))
				uv2_right = Vector2(lerpf(tile_uv_rect.position.x, tile_uv_rect.end.x, local_x1), uv2_origin.y)
				uv2_down = Vector2(uv2_origin.x, lerpf(tile_uv_rect.position.y, tile_uv_rect.end.y, local_y1))
				uv2_diag = Vector2(uv2_right.x, uv2_down.y)
			else:
				uv2_origin = Vector2(
					float(tile_x) * grid_side_length + float(w_sub) * x_grid_sub_length,
					float(tile_y) * grid_side_length + float(sub_y) * y_grid_sub_length
				)
				uv2_right = uv2_origin + Vector2(x_grid_sub_length, 0.0)
				uv2_down = uv2_origin + Vector2(0.0, y_grid_sub_length)
				uv2_diag = uv2_origin + Vector2(x_grid_sub_length, y_grid_sub_length)
			var uv00 := Vector2(float(w_sub) / float(safe_step_width_divs), float(step) / float(safe_step_length_divs))
			var uv01 := Vector2(float(w_sub + 1) / float(safe_step_width_divs), float(step) / float(safe_step_length_divs))
			var uv10 := Vector2(float(w_sub) / float(safe_step_width_divs), float(step + 1) / float(safe_step_length_divs))
			var uv11 := Vector2(float(w_sub + 1) / float(safe_step_width_divs), float(step + 1) / float(safe_step_length_divs))
			_add_river_vertex(st, rows[step][w_sub], uv00, uv2_origin)
			_add_river_vertex(st, rows[step + 1][w_sub], uv10, uv2_down)
			_add_river_vertex(st, rows[step][w_sub + 1], uv01, uv2_right)
			_add_river_vertex(st, rows[step][w_sub + 1], uv01, uv2_right)
			_add_river_vertex(st, rows[step + 1][w_sub], uv10, uv2_down)
			_add_river_vertex(st, rows[step + 1][w_sub + 1], uv11, uv2_diag)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# On the inside of tight bends the bank edges fold back over themselves and
# produce flipped triangles. Clamp edge points that move backwards relative to
# the spline tangent, relax the clamped neighborhoods, and rebuild the interior
# row points between the corrected edges. No-op when there are no overlaps.
const RIVER_EDGE_SMOOTH_RADIUS := 2
const RIVER_EDGE_SMOOTH_ITERATIONS := 5


static func _resolve_river_row_overlaps(rows: Array, center_positions: Array, step_width_divs: int) -> void:
	if rows.size() < 3 or step_width_divs < 1 or center_positions.size() != rows.size():
		return
	var affected_rows := {}
	for edge_index in [0, step_width_divs]:
		var clamped := _clamp_backpedaling_edge_points(rows, center_positions, edge_index)
		_smooth_clamped_edge_neighborhoods(rows, edge_index, clamped)
		for clamped_index in clamped:
			for offset in range(-RIVER_EDGE_SMOOTH_RADIUS, RIVER_EDGE_SMOOTH_RADIUS + 1):
				var row_index: int = clamped_index + offset
				if row_index >= 0 and row_index < rows.size():
					affected_rows[row_index] = true
	if step_width_divs < 2:
		return
	for row_index in affected_rows:
		var edge_start: Vector3 = rows[row_index][0]
		var edge_end: Vector3 = rows[row_index][step_width_divs]
		for w_sub in range(1, step_width_divs):
			rows[row_index][w_sub] = edge_start.lerp(edge_end, float(w_sub) / float(step_width_divs))


static func _clamp_backpedaling_edge_points(rows: Array, center_positions: Array, edge_index: int) -> PackedInt32Array:
	var clamped := PackedInt32Array()
	var last_good: Vector3 = rows[0][edge_index]
	for row_index in range(1, rows.size()):
		var point: Vector3 = rows[row_index][edge_index]
		# Flatland test: vertical movement must not mask a horizontal backpedal.
		var spline_tangent: Vector3 = center_positions[row_index] - center_positions[row_index - 1]
		var edge_tangent: Vector3 = point - last_good
		spline_tangent.y = 0.0
		edge_tangent.y = 0.0
		if edge_tangent.dot(spline_tangent) > 0.0:
			last_good = point
		else:
			# Keep the point's own height so collapsed points do not stack.
			rows[row_index][edge_index] = Vector3(last_good.x, point.y, last_good.z)
			clamped.append(row_index)
	return clamped


static func _smooth_clamped_edge_neighborhoods(rows: Array, edge_index: int, clamped: PackedInt32Array) -> void:
	if clamped.is_empty():
		return
	var affected := {}
	for clamped_index in clamped:
		for offset in range(-RIVER_EDGE_SMOOTH_RADIUS, RIVER_EDGE_SMOOTH_RADIUS + 1):
			var row_index: int = clamped_index + offset
			if row_index > 0 and row_index < rows.size() - 1:
				affected[row_index] = true
	for _iteration in RIVER_EDGE_SMOOTH_ITERATIONS:
		var smoothed := {}
		for row_index in affected:
			smoothed[row_index] = 0.5 * (rows[row_index - 1][edge_index] + rows[row_index + 1][edge_index])
		for row_index in smoothed:
			rows[row_index][edge_index] = smoothed[row_index]


static func _uv2_tile_pixel_center_rect(tile_x: int, tile_y: int, grid_side: int, source_resolution: int) -> Rect2:
	var safe_grid_side := maxi(1, grid_side)
	var safe_source_resolution := maxi(1, source_resolution)
	var x0 := int(floor(float(tile_x) * float(safe_source_resolution) / float(safe_grid_side)))
	var x1 := int(floor(float(tile_x + 1) * float(safe_source_resolution) / float(safe_grid_side)))
	var y0 := int(floor(float(tile_y) * float(safe_source_resolution) / float(safe_grid_side)))
	var y1 := int(floor(float(tile_y + 1) * float(safe_source_resolution) / float(safe_grid_side)))
	if x1 <= x0:
		x1 = x0 + 1
	if y1 <= y0:
		y1 = y0 + 1
	var inv_resolution := 1.0 / float(safe_source_resolution)
	var start := Vector2((float(x0) + 0.5) * inv_resolution, (float(y0) + 0.5) * inv_resolution)
	var end := Vector2((float(x1) - 0.5) * inv_resolution, (float(y1) - 0.5) * inv_resolution)
	return Rect2(start, end - start)


static func _add_river_vertex(st: SurfaceTool, position: Vector3, uv: Vector2, uv2: Vector2) -> void:
	st.set_uv(uv)
	st.set_uv2(uv2)
	st.add_vertex(position)


static func _sample_river_position(curve: Curve3D, step, step_count: int, curve_length: float) -> Vector3:
	var base := Vector3.ZERO
	if curve.get_point_count() > 0:
		base = curve.get_point_position(0)
	if curve_length <= MIN_DIRECTION_LENGTH_SQUARED:
		return base + Vector3.BACK * MIN_RIVER_WIDTH * (float(step) / float(max(1, step_count)))
	var clamped_step: float = clamp(float(step), 0.0, float(step_count))
	return curve.sample_baked((clamped_step / float(step_count)) * curve_length, false)


static func _safe_right_vector(forward_vector: Vector3) -> Vector3:
	var forward := _safe_direction(forward_vector, Vector3.BACK)
	var reference := Vector3.UP
	if abs(forward.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	return _safe_direction(forward.cross(reference), Vector3.RIGHT)


static func _safe_direction(direction: Vector3, fallback: Vector3) -> Vector3:
	if direction.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		return direction.normalized()
	if fallback.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		return fallback.normalized()
	return Vector3.BACK


static func _safe_width_value(widths: Array, index: int) -> float:
	if widths.is_empty():
		return MIN_RIVER_WIDTH
	var clamped_index: int = clamp(index, 0, widths.size() - 1)
	var width_value := float(widths[clamped_index])
	if not _is_finite_number(width_value):
		return MIN_RIVER_WIDTH
	return max(MIN_RIVER_WIDTH, width_value)


static func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_number(value.x) and _is_finite_number(value.y)


static func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_number(value.x) and _is_finite_number(value.y) and _is_finite_number(value.z)


static func _is_degenerate_uv_triangle(a: Vector2, b: Vector2, c: Vector2) -> bool:
	if not _is_finite_vector2(a) or not _is_finite_vector2(b) or not _is_finite_vector2(c):
		return true
	return abs((b - a).cross(c - a)) <= MIN_UV_TRIANGLE_AREA


static func _get_bake_collision_root(mesh_instance: MeshInstance3D, river) -> Node:
	var root: Node = null
	if river != null and river.owner != null:
		root = river.owner
	elif mesh_instance.owner != null:
		root = mesh_instance.owner
	if root == null:
		root = mesh_instance.get_tree().current_scene
	if root == null:
		root = mesh_instance.get_tree().root
	return root


static func _intersects_collision_shapes_segment(collision_shapes: Array, from: Vector3, to: Vector3) -> bool:
	for item in collision_shapes:
		var collision_shape := item as CollisionShape3D
		if collision_shape == null:
			continue
		if intersect_collision_shape_segment(collision_shape, from, to) != null:
			return true
	return false


static func intersect_collision_shape_segment(collision_shape: CollisionShape3D, from: Vector3, to: Vector3) -> Variant:
	return _intersect_collision_shape_segment(collision_shape, from, to)


static func _intersect_collision_shape_segment(collision_shape: CollisionShape3D, from: Vector3, to: Vector3) -> Variant:
	if collision_shape == null or collision_shape.shape == null:
		return null
	var shape := collision_shape.shape
	var local_from: Vector3 = collision_shape.global_transform.affine_inverse() * from
	var local_to: Vector3 = collision_shape.global_transform.affine_inverse() * to
	var local_hit: Variant = null
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		var half_size := size * 0.5
		local_hit = AABB(-half_size, size).intersects_segment(local_from, local_to)
	elif shape is SphereShape3D:
		local_hit = _intersect_local_segment_sphere(local_from, local_to, Vector3.ZERO, max(0.0, (shape as SphereShape3D).radius))
	elif shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		local_hit = _intersect_local_segment_cylinder(local_from, local_to, max(0.0, cylinder.radius), max(0.0, cylinder.height))
	elif shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		local_hit = _intersect_local_segment_capsule(local_from, local_to, max(0.0, capsule.radius), max(0.0, capsule.height))
	elif shape is ConcavePolygonShape3D:
		var concave := shape as ConcavePolygonShape3D
		var concave_data: PackedVector3Array = concave.data
		if _local_segment_intersects_polygon_shape_aabb(shape, local_from, local_to, concave_data):
			local_hit = _intersect_local_segment_triangle_soup(local_from, local_to, concave_data)
	elif shape is ConvexPolygonShape3D:
		var convex := shape as ConvexPolygonShape3D
		var convex_points: PackedVector3Array = convex.points
		if _local_segment_intersects_polygon_shape_aabb(shape, local_from, local_to, convex_points):
			local_hit = _intersect_local_segment_convex_hull(shape, local_from, local_to, convex_points)
	if local_hit == null:
		return null
	return collision_shape.global_transform * local_hit


static func _local_segment_intersects_polygon_shape_aabb(shape: Shape3D, local_from: Vector3, local_to: Vector3, points: PackedVector3Array) -> bool:
	if points.is_empty():
		return false
	var bounds := _get_polygon_shape_local_aabb(shape, points)
	if bounds.has_point(local_from) or bounds.has_point(local_to):
		return true
	return bounds.intersects_segment(local_from, local_to) != null


static func _get_polygon_shape_local_aabb(shape: Shape3D, points: PackedVector3Array) -> AABB:
	var cache_key := "%d:%d" % [shape.get_instance_id(), points.size()]
	if _polygon_shape_local_aabb_cache.has(cache_key):
		var cached_bounds: AABB = _polygon_shape_local_aabb_cache[cache_key]
		return cached_bounds
	var first_point: Vector3 = points[0]
	var bounds := AABB(first_point, Vector3.ZERO)
	for point_index in range(1, points.size()):
		bounds = bounds.expand(points[point_index])
	var grow := Vector3(POLYGON_SHAPE_AABB_EPSILON, POLYGON_SHAPE_AABB_EPSILON, POLYGON_SHAPE_AABB_EPSILON)
	bounds = bounds.expand(bounds.position - grow)
	bounds = bounds.expand(bounds.position + bounds.size + grow)
	_polygon_shape_local_aabb_cache[cache_key] = bounds
	return bounds


static func _intersect_local_segment_sphere(local_from: Vector3, local_to: Vector3, center: Vector3, radius: float) -> Variant:
	var direction := local_to - local_from
	var segment_length_squared := direction.length_squared()
	if segment_length_squared <= MIN_DIRECTION_LENGTH_SQUARED:
		if local_from.distance_squared_to(center) <= radius * radius:
			return local_from
		return null
	var relative_from := local_from - center
	var radius_squared := radius * radius
	if relative_from.length_squared() <= radius_squared:
		return local_from
	var a := segment_length_squared
	var b := 2.0 * relative_from.dot(direction)
	var c := relative_from.length_squared() - radius_squared
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null
	var sqrt_discriminant := sqrt(discriminant)
	var t := (-b - sqrt_discriminant) / (2.0 * a)
	if t < 0.0 or t > 1.0:
		t = (-b + sqrt_discriminant) / (2.0 * a)
	if t < 0.0 or t > 1.0:
		return null
	return local_from + direction * t


static func _intersect_local_segment_cylinder(local_from: Vector3, local_to: Vector3, radius: float, height: float) -> Variant:
	var half_height := height * 0.5
	var radius_squared := radius * radius
	var from_xz_squared := local_from.x * local_from.x + local_from.z * local_from.z
	if abs(local_from.y) <= half_height and from_xz_squared <= radius_squared:
		return local_from
	var direction := local_to - local_from
	var local_hit: Variant = _intersect_local_segment_cylinder_side(local_from, local_to, radius, half_height)
	if abs(direction.y) > MIN_DIRECTION_LENGTH_SQUARED:
		for cap_y in [-half_height, half_height]:
			var t: float = (cap_y - local_from.y) / direction.y
			if t < 0.0 or t > 1.0:
				continue
			var point: Vector3 = local_from + direction * t
			var point_xz_squared: float = point.x * point.x + point.z * point.z
			if point_xz_squared <= radius_squared:
				local_hit = _nearest_local_segment_hit(local_hit, point, local_from)
	return local_hit


static func _intersect_local_segment_cylinder_side(local_from: Vector3, local_to: Vector3, radius: float, half_height: float) -> Variant:
	var direction := local_to - local_from
	var a := direction.x * direction.x + direction.z * direction.z
	if a <= MIN_DIRECTION_LENGTH_SQUARED:
		return null
	var b := 2.0 * (local_from.x * direction.x + local_from.z * direction.z)
	var c := local_from.x * local_from.x + local_from.z * local_from.z - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null
	var sqrt_discriminant := sqrt(discriminant)
	var local_hit: Variant = null
	for t: float in [(-b - sqrt_discriminant) / (2.0 * a), (-b + sqrt_discriminant) / (2.0 * a)]:
		if t < 0.0 or t > 1.0:
			continue
		var point: Vector3 = local_from + direction * t
		if abs(point.y) <= half_height:
			local_hit = _nearest_local_segment_hit(local_hit, point, local_from)
	return local_hit


static func _intersect_local_segment_capsule(local_from: Vector3, local_to: Vector3, radius: float, height: float) -> Variant:
	var half_segment := max(0.0, height * 0.5 - radius)
	var closest_axis_y := clamp(local_from.y, -half_segment, half_segment)
	var closest_axis_point := Vector3(0.0, closest_axis_y, 0.0)
	if local_from.distance_squared_to(closest_axis_point) <= radius * radius:
		return local_from
	var local_hit: Variant = null
	if half_segment > MIN_DIRECTION_LENGTH_SQUARED:
		local_hit = _intersect_local_segment_cylinder_side(local_from, local_to, radius, half_segment)
	local_hit = _nearest_local_segment_hit(local_hit, _intersect_local_segment_sphere(local_from, local_to, Vector3(0.0, half_segment, 0.0), radius), local_from)
	local_hit = _nearest_local_segment_hit(local_hit, _intersect_local_segment_sphere(local_from, local_to, Vector3(0.0, -half_segment, 0.0), radius), local_from)
	return local_hit


static func _intersect_local_segment_triangle_soup(local_from: Vector3, local_to: Vector3, data: PackedVector3Array) -> Variant:
	var triangle_count := int(data.size() / 3)
	var local_hit: Variant = null
	for triangle_index in triangle_count:
		var vertex_index := triangle_index * 3
		var candidate_hit := _intersect_local_segment_triangle(local_from, local_to, data[vertex_index], data[vertex_index + 1], data[vertex_index + 2])
		local_hit = _nearest_local_segment_hit(local_hit, candidate_hit, local_from)
	return local_hit


static func _intersect_local_segment_triangle(local_from: Vector3, local_to: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Variant:
	var edge_1 := b - a
	var edge_2 := c - a
	var direction := local_to - local_from
	if edge_1.cross(edge_2).length_squared() <= MIN_DIRECTION_LENGTH_SQUARED or direction.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return null
	var p_vector := direction.cross(edge_2)
	var determinant := edge_1.dot(p_vector)
	if abs(determinant) <= MIN_DIRECTION_LENGTH_SQUARED:
		return null
	var inverse_determinant := 1.0 / determinant
	var t_vector := local_from - a
	var u := t_vector.dot(p_vector) * inverse_determinant
	if u < -BARYCENTRIC_EDGE_EPSILON or u > 1.0 + BARYCENTRIC_EDGE_EPSILON:
		return null
	var q_vector := t_vector.cross(edge_1)
	var v := direction.dot(q_vector) * inverse_determinant
	if v < -BARYCENTRIC_EDGE_EPSILON or u + v > 1.0 + BARYCENTRIC_EDGE_EPSILON:
		return null
	var t := edge_2.dot(q_vector) * inverse_determinant
	if t < -BARYCENTRIC_EDGE_EPSILON or t > 1.0 + BARYCENTRIC_EDGE_EPSILON:
		return null
	return local_from + direction * clampf(t, 0.0, 1.0)


static func _intersect_local_segment_convex_hull(shape: Shape3D, local_from: Vector3, local_to: Vector3, points: PackedVector3Array) -> Variant:
	var point_count := points.size()
	if point_count < 4:
		return null
	var direction := local_to - local_from
	if direction.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return null
	var planes := _get_convex_hull_planes(shape, points)
	if planes.is_empty():
		return null
	var t_enter := 0.0
	var t_exit := 1.0
	for plane_index in range(0, planes.size(), 2):
		var a: Vector3 = planes[plane_index]
		var normal: Vector3 = planes[plane_index + 1]
		var from_distance := normal.dot(local_from - a)
		var direction_distance := normal.dot(direction)
		if abs(direction_distance) <= POLYGON_HULL_PLANE_EPSILON:
			if from_distance > POLYGON_HULL_PLANE_EPSILON:
				return null
			continue
		var t := -from_distance / direction_distance
		if direction_distance > 0.0:
			t_exit = minf(t_exit, t)
		else:
			t_enter = maxf(t_enter, t)
		if t_enter - t_exit > POLYGON_HULL_PLANE_EPSILON:
			return null
	return local_from + direction * clampf(t_enter, 0.0, 1.0)


static func _get_convex_hull_planes(shape: Shape3D, points: PackedVector3Array) -> PackedVector3Array:
	var cache_key := "%d:%d" % [shape.get_instance_id(), points.size()]
	if _convex_shape_planes_cache.has(cache_key):
		var cached_planes: PackedVector3Array = _convex_shape_planes_cache[cache_key]
		return cached_planes
	var point_count := points.size()
	var planes := PackedVector3Array()
	for i in range(0, point_count - 2):
		var a: Vector3 = points[i]
		for j in range(i + 1, point_count - 1):
			var b: Vector3 = points[j]
			for k in range(j + 1, point_count):
				var c: Vector3 = points[k]
				var normal := (b - a).cross(c - a)
				if normal.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
					continue
				normal = normal.normalized()
				var has_positive := false
				var has_negative := false
				for point_index in point_count:
					var plane_distance := normal.dot(points[point_index] - a)
					if plane_distance > POLYGON_HULL_PLANE_EPSILON:
						has_positive = true
					elif plane_distance < -POLYGON_HULL_PLANE_EPSILON:
						has_negative = true
					if has_positive and has_negative:
						break
				if has_positive and has_negative:
					continue
				if not has_positive and not has_negative:
					continue
				if has_positive:
					normal = -normal
				_append_unique_convex_hull_plane(planes, a, normal)
	_convex_shape_planes_cache[cache_key] = planes
	return planes


static func _append_unique_convex_hull_plane(planes: PackedVector3Array, point: Vector3, normal: Vector3) -> void:
	var plane_distance := normal.dot(point)
	for plane_index in range(0, planes.size(), 2):
		var existing_point: Vector3 = planes[plane_index]
		var existing_normal: Vector3 = planes[plane_index + 1]
		var existing_distance := existing_normal.dot(existing_point)
		if normal.dot(existing_normal) > 1.0 - POLYGON_HULL_PLANE_EPSILON and abs(plane_distance - existing_distance) <= POLYGON_HULL_PLANE_EPSILON:
			return
	planes.append(point)
	planes.append(normal)


static func _nearest_local_segment_hit(current_hit: Variant, candidate_hit: Variant, local_from: Vector3) -> Variant:
	if candidate_hit == null:
		return current_hit
	if current_hit == null:
		return candidate_hit
	if local_from.distance_squared_to(candidate_hit) < local_from.distance_squared_to(current_hit):
		return candidate_hit
	return current_hit


static func _create_uv2_world_sample_context(mesh_instance: MeshInstance3D, steps: int, step_length_divs: int, step_width_divs: int) -> Dictionary:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return {}
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	if arrays.size() <= 5:
		return {}
	var uv2 := arrays[5] as PackedVector2Array
	var verts := arrays[0] as PackedVector3Array
	if uv2.is_empty() or verts.is_empty():
		return {}
	var world_verts := PackedVector3Array()
	for v in verts.size():
		world_verts.append(mesh_instance.global_transform * verts[v])
	var safe_step_length_divs: int = clamp(step_length_divs, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX)
	var safe_step_width_divs: int = clamp(step_width_divs, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX)
	return {
		"uv2": uv2,
		"world_verts": world_verts,
		"steps": maxi(0, steps),
		"side": max(1, calculate_side(steps)),
		"tris_in_step_quad": safe_step_length_divs * safe_step_width_divs * 2
	}


# subtexel_offset jitters the sample inside the texel (each axis in -0.5..0.5);
# tile membership stays keyed to the integer texel so jittered samples that
# fall outside the tile's triangles return empty instead of leaking into a
# neighboring step.
static func _get_uv2_world_sample(context: Dictionary, image_width: int, image_height: int, x: int, y: int, subtexel_offset := Vector2.ZERO) -> Dictionary:
	if context.is_empty() or image_width <= 0 or image_height <= 0:
		return {}
	var steps := int(context.get("steps", 0))
	var side := int(context.get("side", max(1, calculate_side(steps))))
	var tris_in_step_quad := int(context.get("tris_in_step_quad", 0))
	if steps <= 0 or side <= 0 or tris_in_step_quad <= 0:
		return {}
	var uv2: PackedVector2Array = context.get("uv2", PackedVector2Array())
	var world_verts: PackedVector3Array = context.get("world_verts", PackedVector3Array())
	if uv2.is_empty() or world_verts.is_empty():
		return {}
	var column := _uv2_atlas_axis_index(x, image_width, side)
	var row := _uv2_atlas_axis_index(y, image_height, side)
	var step_quad: int = column * side + row
	if step_quad >= steps:
		return {"outside_occupied_atlas": true}
	var uv_coordinate := Vector2((0.5 + float(x) + subtexel_offset.x) / float(image_width), (0.5 + float(y) + subtexel_offset.y) / float(image_height))
	var p := Vector3(uv_coordinate.x, uv_coordinate.y, 0.0)
	var barycentric_coords := Vector3.ZERO
	var correct_triangle := []
	for tris in tris_in_step_quad:
		var offset_tris: int = (tris_in_step_quad * step_quad) + tris
		var triangle_index := offset_tris * 3
		if triangle_index + 2 >= uv2.size() or triangle_index + 2 >= world_verts.size():
			continue
		if _is_degenerate_uv_triangle(uv2[triangle_index], uv2[triangle_index + 1], uv2[triangle_index + 2]):
			continue
		var a := Vector3(uv2[triangle_index].x, uv2[triangle_index].y, 0.0)
		var b := Vector3(uv2[triangle_index + 1].x, uv2[triangle_index + 1].y, 0.0)
		var c := Vector3(uv2[triangle_index + 2].x, uv2[triangle_index + 2].y, 0.0)
		barycentric_coords = cart2bary(p, a, b, c)
		if point_in_bariatric(barycentric_coords):
			correct_triangle = [triangle_index, triangle_index + 1, triangle_index + 2]
			break
	if correct_triangle.is_empty():
		return {}
	var real_pos := bary2cart(
		world_verts[correct_triangle[0]],
		world_verts[correct_triangle[1]],
		world_verts[correct_triangle[2]],
		barycentric_coords
	)
	if not _is_finite_vector3(real_pos):
		return {}
	return {
		"world_position": real_pos,
		"uv": uv_coordinate,
		"step": step_quad
	}


static func _uv2_atlas_axis_index(pixel: int, axis_size: int, side: int) -> int:
	var safe_axis_size := maxi(1, axis_size)
	var safe_side := maxi(1, side)
	var clamped_pixel := clampi(pixel, 0, safe_axis_size - 1)
	for index in safe_side:
		var start := int(floor(float(index) * float(safe_axis_size) / float(safe_side)))
		var end := int(floor(float(index + 1) * float(safe_axis_size) / float(safe_side)))
		end = mini(safe_axis_size, maxi(start + 1, end))
		if clamped_pixel >= start and clamped_pixel < end:
			return index
	return safe_side - 1


static func generate_collisionmap(image : Image, mesh_instance : MeshInstance3D, raycast_dist : float, raycast_layers : int, steps : int, step_length_divs : int, step_width_divs : int, river) -> Image:
	clear_polygon_shape_intersection_caches()
	var space_state := mesh_instance.get_world_3d().direct_space_state
	var bake_collision_root := _get_bake_collision_root(mesh_instance, river)
	var direct_collision_shapes := collect_raycast_collision_shapes(bake_collision_root, raycast_layers)
	if direct_collision_shapes.is_empty():
		push_warning("Waterways: River collision bake found no direct CollisionShape3D nodes matching raycast layer mask %d under %s. Falling back to physics raycasts." % [raycast_layers, bake_collision_root.get_path()])
	var sample_context := _create_uv2_world_sample_context(mesh_instance, steps, step_length_divs, step_width_divs)
	
	var image_width := image.get_width()
	var image_height := image.get_height()
	if image_width <= 0 or image_height <= 0 or steps <= 0 or sample_context.is_empty():
		return image
	var percentage = 0.0
	river.emit_signal("progress_notified", percentage, "Calculating Collisions (" + str(image_width) + "x" + str(image_height) + ")")
	await river.get_tree().process_frame
	for x in image_width:
		var cur_percentage = float(x) / float(image_width)
		if cur_percentage > percentage + 0.1:
			percentage += 0.1
			river.emit_signal("progress_notified", percentage, "Calculating Collisions (" + str(image_width) + "x" + str(image_height) + ")")
			await river.get_tree().process_frame
		for y in image_height:
			var sample := _get_uv2_world_sample(sample_context, image_width, image_height, x, y)
			if bool(sample.get("outside_occupied_atlas", false)):
				break # we are in the empty part of UV2 so we break to the next column
			if sample.is_empty():
				continue
			var real_pos: Vector3 = sample.get("world_position", Vector3.ZERO)
			if not _is_finite_vector3(real_pos):
				continue
			var real_pos_up := real_pos + Vector3.UP * raycast_dist
			
			var query_up := PhysicsRayQueryParameters3D.create(real_pos, real_pos_up)
			query_up.collision_mask = raycast_layers
			query_up.hit_from_inside = true
			var result_up: Dictionary = space_state.intersect_ray(query_up)
			var query_down := PhysicsRayQueryParameters3D.create(real_pos_up, real_pos)
			query_down.collision_mask = raycast_layers
			var result_down: Dictionary = space_state.intersect_ray(query_down)

			var up_hit_frontface := false
			var up_hit_inside := false
			if result_up:
				if result_up.normal == Vector3.ZERO:
					# hit_from_inside reports a zero normal when the ray origin
					# is already embedded in a collider - deep interiors of tall
					# boulders/cliffs that both rays would otherwise miss.
					up_hit_inside = true
				elif result_up.normal.y < 0:
					up_hit_frontface = true

			if up_hit_inside:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
			elif result_up or result_down:
				# Physics rays carry facing info: an up-ray whose first hit is an
				# underside means the geometry hangs above the water here, so it
				# must not bake as a flow obstacle.
				if not up_hit_frontface and result_down:
					image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
			elif _intersects_collision_shapes_segment(direct_collision_shapes, real_pos_up, real_pos):
				# Direct shape-segment fallback for contexts where the physics
				# space reports nothing; it has no facing info, so it cannot
				# exempt overhangs.
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	return image


static func generate_terrain_contact_feature_map(image: Image, mesh_instance: MeshInstance3D, raycast_layers: int, steps: int, step_length_divs: int, step_width_divs: int, river, settings: Dictionary) -> Image:
	clear_polygon_shape_intersection_caches()
	if image == null or image.is_empty() or mesh_instance == null or mesh_instance.get_world_3d() == null:
		return image
	var image_width := image.get_width()
	var image_height := image.get_height()
	var sample_context := _create_uv2_world_sample_context(mesh_instance, steps, step_length_divs, step_width_divs)
	if image_width <= 0 or image_height <= 0 or steps <= 0 or sample_context.is_empty():
		return image
	var bake_collision_root := _get_bake_collision_root(mesh_instance, river)
	var hterrain_samplers := collect_hterrain_samplers(bake_collision_root, raycast_layers)
	var direct_collision_shapes := collect_raycast_collision_shapes(bake_collision_root, raycast_layers)
	var space_state := mesh_instance.get_world_3d().direct_space_state
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
	var supersamples := clampi(int(settings.get("contact_supersamples", 1)), 1, 4)
	var source_blend_band := maxf(0.0, float(settings.get("source_blend_band", 0.0)))
	var percentage := 0.0
	_emit_terrain_contact_progress(river, percentage, image_width, image_height)
	await _await_bake_frame(mesh_instance, river)
	for x in image_width:
		var cur_percentage := float(x) / float(image_width)
		if cur_percentage > percentage + 0.1:
			percentage += 0.1
			_emit_terrain_contact_progress(river, percentage, image_width, image_height)
			await _await_bake_frame(mesh_instance, river)
		for y in image_height:
			var center_sample := _get_uv2_world_sample(sample_context, image_width, image_height, x, y)
			if bool(center_sample.get("outside_occupied_atlas", false)):
				break
			if center_sample.is_empty():
				continue
			# Supersampled texels average the classified masks of N x N
			# jittered rays so classification edges resolve as coverage ramps
			# instead of per-texel binary flips. Sub-rays that miss everything
			# contribute zero (area coverage), matching the untouched-pixel
			# semantics of a fully missing texel.
			var contact_sum := 0.0
			var shallow_sum := 0.0
			var protrusion_sum := 0.0
			var confidence_sum := 0.0
			var sampled := 0
			var hit := false
			for sub_x in supersamples:
				for sub_y in supersamples:
					var sample := center_sample
					if supersamples > 1:
						var jitter := Vector2(
							(float(sub_x) + 0.5) / float(supersamples) - 0.5,
							(float(sub_y) + 0.5) / float(supersamples) - 0.5
						)
						sample = _get_uv2_world_sample(sample_context, image_width, image_height, x, y, jitter)
						if sample.is_empty() or bool(sample.get("outside_occupied_atlas", false)):
							continue
					var water_position: Vector3 = sample.get("world_position", Vector3.ZERO)
					if not _is_finite_vector3(water_position):
						continue
					sampled += 1
					var hterrain_sample := _sample_hterrain_contact(hterrain_samplers, water_position, hterrain_confidence)
					var physics_sample := _sample_physics_contact(space_state, direct_collision_shapes, water_position, raycast_up_offset, raycast_down_distance, raycast_layers, physics_confidence)
					var selected := _blend_contact_samples(hterrain_sample, physics_sample, source_blend_band)
					if selected.is_empty():
						continue
					hit = true
					var hit_height := float(selected.get("height", water_position.y))
					var delta := water_position.y - hit_height
					contact_sum += _falloff_mask(absf(delta), contact_full_band, contact_fade_distance)
					if delta >= 0.0:
						shallow_sum += _falloff_mask(delta, shallow_full_depth, shallow_fade_depth)
					protrusion_sum += _rise_mask(maxf(0.0, -delta), protrusion_fade_height, protrusion_full_height)
					confidence_sum += clampf(float(selected.get("confidence", 0.0)), 0.0, 1.0)
			if sampled == 0 or not hit:
				continue
			var inverse_sampled := 1.0 / float(sampled)
			image.set_pixel(x, y, Color(
				contact_sum * inverse_sampled,
				shallow_sum * inverse_sampled,
				protrusion_sum * inverse_sampled,
				confidence_sum * inverse_sampled
			))
	return image


static func _emit_terrain_contact_progress(river, percentage: float, image_width: int, image_height: int) -> void:
	if river != null and river.has_signal("progress_notified"):
		river.emit_signal("progress_notified", percentage, "Calculating Terrain Contact (" + str(image_width) + "x" + str(image_height) + ")")


static func _await_bake_frame(mesh_instance: MeshInstance3D, river) -> void:
	if river != null and river is Node and (river as Node).is_inside_tree():
		await (river as Node).get_tree().process_frame
	elif mesh_instance != null and mesh_instance.is_inside_tree():
		await mesh_instance.get_tree().process_frame


static func _sample_hterrain_contact(hterrain_samplers: Array, water_position: Vector3, source_confidence: float) -> Dictionary:
	var selected := {}
	for terrain in hterrain_samplers:
		if terrain == null:
			continue
		var terrain_data = terrain.call("get_data")
		if terrain_data == null or not terrain_data.has_method("get_interpolated_height_at"):
			continue
		var map_position: Vector3 = terrain.call("world_to_map", water_position)
		if not _is_finite_vector3(map_position):
			continue
		if terrain_data.has_method("get_resolution"):
			var resolution := int(terrain_data.call("get_resolution"))
			if resolution > 1 and (map_position.x < 0.0 or map_position.z < 0.0 or map_position.x > float(resolution - 1) or map_position.z > float(resolution - 1)):
				continue
		var raw_height := float(terrain_data.call("get_interpolated_height_at", map_position))
		if not _is_finite_number(raw_height):
			continue
		var internal_transform: Transform3D = terrain.call("get_internal_transform")
		var terrain_world_position := internal_transform * Vector3(map_position.x, raw_height, map_position.z)
		if not _is_finite_vector3(terrain_world_position):
			continue
		if selected.is_empty() or terrain_world_position.y > float(selected.get("height", -INF)):
			selected = {
				"height": terrain_world_position.y,
				"position": terrain_world_position,
				"confidence": source_confidence,
				"source": "hterrain"
			}
	return selected


# Blends the HTerrain and physics contact candidates by relative height
# instead of a hard winner-takes-all switch, so the selected source cannot
# flip per texel along near-tie boundaries (visible as provenance
# checkerboarding in the baked A channel). blend_band <= 0 preserves the
# legacy higher-wins selection.
static func _blend_contact_samples(hterrain_sample: Dictionary, physics_sample: Dictionary, blend_band: float) -> Dictionary:
	if physics_sample.is_empty():
		return hterrain_sample
	if hterrain_sample.is_empty():
		return physics_sample
	var height_difference := float(physics_sample.get("height", -INF)) - float(hterrain_sample.get("height", -INF))
	if blend_band <= 0.0:
		return physics_sample if height_difference > 0.0 else hterrain_sample
	var physics_weight := smoothstep(-blend_band, blend_band, height_difference)
	if physics_weight <= 0.0:
		return hterrain_sample
	if physics_weight >= 1.0:
		return physics_sample
	var hterrain_position: Vector3 = hterrain_sample.get("position", Vector3.ZERO)
	var physics_position: Vector3 = physics_sample.get("position", Vector3.ZERO)
	return {
		"height": lerpf(float(hterrain_sample.get("height", 0.0)), float(physics_sample.get("height", 0.0)), physics_weight),
		"position": hterrain_position.lerp(physics_position, physics_weight),
		"confidence": lerpf(float(hterrain_sample.get("confidence", 0.0)), float(physics_sample.get("confidence", 0.0)), physics_weight),
		"source": "blended"
	}


static func _sample_physics_contact(space_state: PhysicsDirectSpaceState3D, direct_collision_shapes: Array, water_position: Vector3, up_offset: float, down_distance: float, raycast_layers: int, source_confidence: float) -> Dictionary:
	if raycast_layers == 0:
		return {}
	var ray_from := water_position + Vector3.UP * up_offset
	var ray_to := water_position - Vector3.UP * down_distance
	var selected_hit := Vector3.ZERO
	var has_hit := false
	for item in direct_collision_shapes:
		var collision_shape := item as CollisionShape3D
		if collision_shape == null:
			continue
		var hit = intersect_collision_shape_segment(collision_shape, ray_from, ray_to)
		if hit == null:
			continue
		var shape_hit: Vector3 = hit
		if not has_hit or ray_from.distance_squared_to(shape_hit) < ray_from.distance_squared_to(selected_hit):
			selected_hit = shape_hit
			has_hit = true
	if space_state != null:
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collision_mask = raycast_layers
		var result: Dictionary = space_state.intersect_ray(query)
		if result and result.has("position"):
			var physics_hit: Vector3 = result.position
			if not has_hit or ray_from.distance_squared_to(physics_hit) < ray_from.distance_squared_to(selected_hit):
				selected_hit = physics_hit
				has_hit = true
	if not has_hit or not _is_finite_vector3(selected_hit):
		return {}
	return {
		"height": selected_hit.y,
		"position": selected_hit,
		"confidence": source_confidence,
		"source": "physics"
	}


static func _falloff_mask(value: float, full_value: float, zero_value: float) -> float:
	if value <= full_value:
		return 1.0
	if value >= zero_value:
		return 0.0
	if zero_value <= full_value:
		return 0.0
	return 1.0 - smoothstep(full_value, zero_value, value)


static func _rise_mask(value: float, zero_value: float, full_value: float) -> float:
	if value <= zero_value:
		return 0.0
	if value >= full_value:
		return 1.0
	if full_value <= zero_value:
		return 1.0
	return smoothstep(zero_value, full_value, value)


# Adds offset margins so filters will correctly extend across UV edges
static func add_margins(image : Image, resolution : float, margin : float, occupied_steps: int = -1) -> Image:
	if image == null or image.is_empty():
		return image
	var resolution_int: int = max(1, int(round(resolution)))
	resolution_int = min(resolution_int, image.get_width())
	resolution_int = min(resolution_int, image.get_height())
	var margin_int: int = max(0, int(round(margin)))
	if margin_int <= 0:
		return image
	margin_int = min(margin_int, resolution_int)
	var with_margins_size: int = resolution_int + 2 * margin_int
	var image_with_margins := Image.create(with_margins_size, with_margins_size, false, image.get_format())
	image_with_margins.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	image_with_margins.blend_rect(image, Rect2i(0, 0, resolution_int, resolution_int), Vector2i(margin_int, margin_int))
	image_with_margins.blend_rect(image, Rect2i(0, 0, resolution_int, margin_int), Vector2i(margin_int, 0))
	image_with_margins.blend_rect(image, Rect2i(0, resolution_int - margin_int, resolution_int, margin_int), Vector2i(margin_int, resolution_int + margin_int))
	image_with_margins.blend_rect(image, Rect2i(0, 0, margin_int, resolution_int), Vector2i(0, margin_int))
	image_with_margins.blend_rect(image, Rect2i(resolution_int - margin_int, 0, margin_int, resolution_int), Vector2i(resolution_int + margin_int, margin_int))
	image_with_margins.blend_rect(image, Rect2i(0, 0, margin_int, margin_int), Vector2i(0, 0))
	image_with_margins.blend_rect(image, Rect2i(resolution_int - margin_int, 0, margin_int, margin_int), Vector2i(resolution_int + margin_int, 0))
	image_with_margins.blend_rect(image, Rect2i(0, resolution_int - margin_int, margin_int, margin_int), Vector2i(0, resolution_int + margin_int))
	image_with_margins.blend_rect(image, Rect2i(resolution_int - margin_int, resolution_int - margin_int, margin_int, margin_int), Vector2i(resolution_int + margin_int, resolution_int + margin_int))
	
	# The UV2 atlas advances down a column before continuing at the top of the next column.
	# Extend row-wrapping seams from occupied tiles, but clamp the first and last real
	# tiles to themselves so empty atlas cells cannot bleed into River ends.
	if occupied_steps > 0:
		_add_uv2_column_continuation_margins(image_with_margins, image, resolution_int, margin_int, occupied_steps)
	else:
		image_with_margins.blend_rect(image, Rect2i(0, resolution_int - margin_int, resolution_int, margin_int), Vector2i(margin_int + margin_int, 0))
		image_with_margins.blend_rect(image, Rect2i(0, 0, resolution_int, margin_int), Vector2i(0, resolution_int + margin_int))
	
	return image_with_margins


static func _add_uv2_column_continuation_margins(padded: Image, source: Image, resolution: int, margin: int, occupied_steps: int) -> void:
	var side: int = max(1, calculate_side(occupied_steps))
	var max_steps: int = min(occupied_steps, side * side)
	if max_steps <= 0:
		return
	for step_index in max_steps:
		var tile := _uv2_tile_rect(step_index, side, resolution)
		var row := step_index % side
		if row == 0:
			var previous_step: int = max(0, step_index - 1)
			var previous_tile := _uv2_tile_rect(previous_step, side, resolution)
			# The first tile clamps to itself: copy its own *top* strip (mirror of
			# the last-tile case below), not its bottom strip, so the upstream
			# river end cannot bleed wrapped content into its top margin.
			var previous_strip_y: int = previous_tile.position.y + max(0, previous_tile.size.y - margin)
			if previous_step == step_index:
				previous_strip_y = previous_tile.position.y
			var previous_strip := Rect2i(
				previous_tile.position.x,
				previous_strip_y,
				previous_tile.size.x,
				min(margin, previous_tile.size.y)
			)
			var top_margin := Rect2i(tile.position.x + margin, 0, tile.size.x, margin)
			_copy_scaled_region(padded, top_margin, source, previous_strip)
		if row == side - 1:
			var next_step: int = min(max_steps - 1, step_index + 1)
			var next_tile := _uv2_tile_rect(next_step, side, resolution)
			var next_strip_y := next_tile.position.y
			if next_step == step_index:
				next_strip_y = next_tile.position.y + max(0, next_tile.size.y - margin)
			var next_strip := Rect2i(next_tile.position.x, next_strip_y, next_tile.size.x, min(margin, next_tile.size.y))
			var bottom_margin := Rect2i(tile.position.x + margin, resolution + margin, tile.size.x, margin)
			_copy_scaled_region(padded, bottom_margin, source, next_strip)


static func _uv2_tile_rect(step_index: int, side: int, resolution: int) -> Rect2i:
	var column := int(step_index / side)
	var row := step_index % side
	var x0 := int(floor(float(column) * float(resolution) / float(side)))
	var x1 := int(floor(float(column + 1) * float(resolution) / float(side)))
	var y0 := int(floor(float(row) * float(resolution) / float(side)))
	var y1 := int(floor(float(row + 1) * float(resolution) / float(side)))
	return Rect2i(x0, y0, max(1, x1 - x0), max(1, y1 - y0))


static func _copy_scaled_region(destination: Image, destination_rect: Rect2i, source: Image, source_rect: Rect2i) -> void:
	if destination_rect.size.x <= 0 or destination_rect.size.y <= 0 or source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return
	for y in destination_rect.size.y:
		var source_y := source_rect.position.y + int(floor((float(y) + 0.5) * float(source_rect.size.y) / float(destination_rect.size.y)))
		source_y = clamp(source_y, source_rect.position.y, source_rect.position.y + source_rect.size.y - 1)
		for x in destination_rect.size.x:
			var source_x := source_rect.position.x + int(floor((float(x) + 0.5) * float(source_rect.size.x) / float(destination_rect.size.x)))
			source_x = clamp(source_x, source_rect.position.x, source_rect.position.x + source_rect.size.x - 1)
			destination.set_pixel(destination_rect.position.x + x, destination_rect.position.y + y, source.get_pixel(source_x, source_y))


