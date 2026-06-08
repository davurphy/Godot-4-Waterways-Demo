extends SceneTree

const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn"
const MOVING_TARGET_UVS := [
	Vector2(0.662573, 0.336428),
	Vector2(0.701191, 0.373611),
	Vector2(0.755304, 0.355428),
]
const TERRAIN_HEIGHT_UNAVAILABLE := -1000000000.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(REVIEW_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load review scene.")
		quit(1)
		return
	var review := packed_scene.instantiate()
	root.add_child(review)
	await _settle_frames(24)

	var field := review.call("get_field") as Node
	var target_river := review.call("get_target_river") as Node
	var mesh_instance := target_river.get("mesh_instance") as MeshInstance3D if target_river != null else null
	var terrain := review.get_node_or_null("World/HTerrain")
	if field == null or mesh_instance == null or mesh_instance.mesh == null:
		push_error("Missing field or river mesh for anchor diagnostic.")
		quit(1)
		return

	var world_to_uv: Transform3D = field.call("get_world_to_ripple_uv")
	var results := {
		"current_moving_path": review.call("get_moving_path_reports"),
		"targets": [],
	}
	for target_uv in MOVING_TARGET_UVS:
		results.targets.append(_candidate_report(mesh_instance, terrain, world_to_uv, target_uv))
	print("RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_RESULTS=", results)
	print("RIPPLE_FIELD_EMITTER_ANCHOR_DIAGNOSTIC_OK")
	quit(0)


func _candidate_report(mesh_instance: MeshInstance3D, terrain: Node, world_to_uv: Transform3D, target_uv: Vector2) -> Dictionary:
	var candidates := []
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex in vertices:
			var world_position := mesh_instance.global_transform * vertex
			var mapped := world_to_uv * world_position
			var uv := Vector2(mapped.x, mapped.z)
			if uv.distance_to(target_uv) > 0.09:
				continue
			var terrain_height := _sample_terrain_height(terrain, world_position)
			var clearance := INF if terrain_height == TERRAIN_HEIGHT_UNAVAILABLE else world_position.y - terrain_height
			candidates.append({
				"world": world_position,
				"uv": uv,
				"uv_distance": uv.distance_to(target_uv),
				"terrain_height": terrain_height,
				"clearance": clearance,
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var clearance_a := float(a.get("clearance", -INF))
		var clearance_b := float(b.get("clearance", -INF))
		if abs(clearance_a - clearance_b) > 0.001:
			return clearance_a > clearance_b
		return float(a.get("uv_distance", INF)) < float(b.get("uv_distance", INF))
	)
	var close_candidates := candidates.filter(func(candidate: Dictionary) -> bool:
		return float(candidate.get("uv_distance", INF)) <= 0.075
	)
	return {
		"target_uv": target_uv,
		"candidate_count": candidates.size(),
		"top_by_clearance": candidates.slice(0, min(12, candidates.size())),
		"top_by_clearance_within_0_075": close_candidates.slice(0, min(12, close_candidates.size())),
	}


func _sample_terrain_height(terrain: Node, world_position: Vector3) -> float:
	if terrain == null or not is_instance_valid(terrain):
		return TERRAIN_HEIGHT_UNAVAILABLE
	if not terrain.has_method("get_data") or not terrain.has_method("world_to_map") or not terrain.has_method("get_internal_transform"):
		return TERRAIN_HEIGHT_UNAVAILABLE
	var terrain_data: Object = terrain.call("get_data")
	if terrain_data == null or not terrain_data.has_method("get_interpolated_height_at"):
		return TERRAIN_HEIGHT_UNAVAILABLE
	var map_position: Vector3 = terrain.call("world_to_map", world_position)
	var raw_height := float(terrain_data.call("get_interpolated_height_at", map_position))
	var terrain_transform: Transform3D = terrain.call("get_internal_transform")
	var terrain_world_position := terrain_transform * Vector3(map_position.x, raw_height, map_position.z)
	return terrain_world_position.y


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
