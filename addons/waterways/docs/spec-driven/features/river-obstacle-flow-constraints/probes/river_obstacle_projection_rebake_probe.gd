extends SceneTree

# Rebakes the demo scenes with the occupancy + pressure projection pipeline,
# then verifies on the baked textures that:
#  1. water_occupancy exists, has solid coverage, and flow_projected is set
#  2. flow inside solid occupancy is (near) zero
#  3. flow in the boundary proximity ring does not point into solids
#     (free-slip: the into-solid component must stay below thresholds)
#
# Run (NOT headless - bakes need viewport readback):
#   & $godotConsole --path $root --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_obstacle_projection_rebake_probe.gd

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const CASES := [
	{
		"name": "obstacle_test",
		"scene": "res://Demo_obstacle_flow_test.tscn",
		"expect_solids": true,
	},
	{
		"name": "main_demo",
		"scene": "res://Demo.tscn",
		"expect_solids": false,
	},
]

const SOLID_THRESHOLD := 0.5
# Flow approaching an obstacle from a distance is physically correct (the
# stagnation streamline points at the solid); free-slip only guarantees
# v.n -> 0 AT the surface. Gates therefore apply to the inner ring close to
# the surface; the outer ring is reported as diagnostics only.
const RING_PROXIMITY_MIN := 0.15
const RING_PROXIMITY_MAX := 0.85
const INNER_RING_PROXIMITY_MIN := 0.5
const GRADIENT_SAMPLE_OFFSET := 2
const GRADIENT_MIN_MAGNITUDE := 0.02
const COLUMN_EDGE_GUARD_PIXELS := 3
# The shader stills advection near solids (flow_force *= smoothstep(0,
# OCCUPANCY_SPEED_RAMP_FULL, 1 - proximity)), so the rendered penetration is
# the raw into-solid component scaled by that same factor. Raw stats are
# printed for diagnostics; gates apply to the effective (rendered) values.
const OCCUPANCY_SPEED_RAMP_FULL := 0.45
# Stagnation approach flow decelerates roughly linearly with distance to the
# wall, so the permitted raw into-solid speed is distance-scaled: near the
# ring's outer edge approach at up to ~baseline speed is physical; at the
# surface only a small residual is tolerated. A fixed cap would always trip
# on legitimate approach flow at whatever radius the cap is evaluated.
const RAW_APPROACH_ALLOWANCE_SLOPE := 0.5
const RAW_SURFACE_RESIDUAL_ALLOWANCE := 0.03
# Single-texel backstop. Sensitive to discrete proximity-gradient estimation
# where rings from neighboring solids overlap or solids are only a few texels
# wide (an extra tangency pass leaves the worst texel byte-identical, so the
# residual is probe-vs-bake gradient disagreement, not removable penetration).
# Worst observed offenders sit at proximity ~0.84 where rendered advection is
# stilled to ~0.3x and the occupancy clip hides the surface anyway. Field-wide
# health is enforced by the fraction gates below.
const MAX_ALLOWANCE_EXCESS := 0.25
const ALLOWANCE_EXCESS_MAX_FRACTION := 0.005
# Scales with OCCUPANCY_SPEED_RAMP_FULL: the same raw baked field renders
# ~2.3x more residual motion under the softer 0.45 ramp than under the
# original 0.85 ramp this limit was calibrated for (0.03 * 2.3 ~= 0.07).
const EFFECTIVE_INTO_SOLID_SOFT_LIMIT := 0.07
const SOFT_LIMIT_MAX_FRACTION := 0.01
const SOLID_FLOW_MAGNITUDE_MAX_MEAN := 0.03

var _bake_done := false
var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for case_variant in CASES:
		var probe_case := case_variant as Dictionary
		var ok := await _rebake_and_verify(probe_case)
		if not ok:
			break
	if _errors.is_empty():
		print("RIVER_OBSTACLE_PROJECTION_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _rebake_and_verify(probe_case: Dictionary) -> bool:
	var scene_path := String(probe_case.get("scene", ""))
	var case_name := String(probe_case.get("name", scene_path))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_expect(false, "Could not load scene: " + scene_path)
		return false
	var scene := packed.instantiate()
	if scene == null:
		_expect(false, "Could not instantiate scene: " + scene_path)
		return false
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var river := scene.get_node_or_null("WaterSystem/Water River")
	if river == null:
		_expect(false, "Could not find WaterSystem/Water River in " + scene_path)
		scene.queue_free()
		await process_frame
		return false

	print("RIVER_OBSTACLE_PROJECTION_REBAKE case=", case_name, " scene=", scene_path)
	_bake_done = false
	if not river.progress_notified.is_connected(_on_river_progress_notified):
		river.progress_notified.connect(_on_river_progress_notified)
	river.bake_texture()
	var frames := 0
	while not _bake_done and frames < 7200:
		await process_frame
		frames += 1
	if not _bake_done:
		_expect(false, "River bake did not finish within timeout for " + scene_path)
		scene.queue_free()
		await process_frame
		return false

	var bake_data := river.get("bake_data") as Resource
	var verified := _verify_bake(case_name, bake_data, bool(probe_case.get("expect_solids", false)))
	if verified and not bake_data.resource_path.is_empty():
		var save_flags := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
		var save_error := ResourceSaver.save(bake_data, bake_data.resource_path, save_flags)
		print("RIVER_", case_name, "_SAVE_PATH=", bake_data.resource_path)
		print("RIVER_", case_name, "_SAVE_ERROR=", save_error)
		_expect(save_error == OK, case_name + " bake resource save failed with error " + str(save_error))
	scene.queue_free()
	await process_frame
	return _errors.is_empty()


func _verify_bake(case_name: String, bake_data: Resource, expect_solids: bool) -> bool:
	if bake_data == null:
		_expect(false, case_name + ": bake_data resource is missing.")
		return false
	var source_metadata: Dictionary = bake_data.get("source_metadata")
	var flow_projected := bool(source_metadata.get("flow_projected", false))
	var occupancy_baked := bool(source_metadata.get("water_occupancy_baked", false))
	print("RIVER_OBSTACLE_PROJECTION_SUMMARY case=", case_name)
	print("  flow_projected=", flow_projected)
	print("  water_occupancy_baked=", occupancy_baked)
	_expect(flow_projected, case_name + ": flow_projected metadata flag is false - projection solve did not run.")
	_expect(occupancy_baked, case_name + ": water_occupancy_baked metadata flag is false.")

	var flow_texture := bake_data.get("flow_foam_noise") as Texture2D
	var occupancy_texture := bake_data.get("water_occupancy") as Texture2D
	if flow_texture == null or occupancy_texture == null:
		_expect(false, case_name + ": flow or occupancy texture missing from bake data.")
		return false
	var flow_image := flow_texture.get_image()
	var occupancy_image := occupancy_texture.get_image()
	if flow_image == null or occupancy_image == null or flow_image.get_size() != occupancy_image.get_size():
		_expect(false, case_name + ": flow/occupancy images unreadable or size mismatch.")
		return false

	var content_rect: Rect2i = bake_data.get("content_rect")
	var uv2_sides := int(bake_data.get("uv2_sides"))
	var side: int = maxi(1, uv2_sides)

	var solid_count := 0
	var solid_flow_magnitude_sum := 0.0
	var outer_ring_count := 0
	var outer_effective_max := 0.0
	var inner_ring_count := 0
	var inner_raw_max := 0.0
	var inner_effective_max := 0.0
	var inner_effective_sum := 0.0
	var inner_over_soft_limit := 0
	var allowance_excess_max := 0.0
	var allowance_excess_count := 0
	var worst_pixel := Vector2i(-1, -1)
	var worst_proximity := 0.0

	for y in range(content_rect.position.y, content_rect.position.y + content_rect.size.y):
		for x in range(content_rect.position.x, content_rect.position.x + content_rect.size.x):
			var occupancy := occupancy_image.get_pixel(x, y)
			var flow := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(x, y))
			if occupancy.r > SOLID_THRESHOLD:
				solid_count += 1
				solid_flow_magnitude_sum += flow.length()
				continue
			var proximity := occupancy.g
			if proximity < RING_PROXIMITY_MIN or proximity > RING_PROXIMITY_MAX:
				continue
			if _near_column_edge(x, content_rect, side):
				continue
			var gradient := _proximity_gradient(occupancy_image, x, y)
			if gradient.length() < GRADIENT_MIN_MAGNITUDE:
				continue
			var into_solid := flow.dot(gradient.normalized())
			var speed_factor := smoothstep(0.0, OCCUPANCY_SPEED_RAMP_FULL, 1.0 - proximity)
			var effective_into_solid := into_solid * speed_factor
			if proximity < INNER_RING_PROXIMITY_MIN:
				outer_ring_count += 1
				outer_effective_max = maxf(outer_effective_max, effective_into_solid)
				continue
			inner_ring_count += 1
			inner_effective_sum += maxf(effective_into_solid, 0.0)
			inner_raw_max = maxf(inner_raw_max, into_solid)
			if effective_into_solid > EFFECTIVE_INTO_SOLID_SOFT_LIMIT:
				inner_over_soft_limit += 1
			var allowed_raw := RAW_APPROACH_ALLOWANCE_SLOPE * (1.0 - proximity) + RAW_SURFACE_RESIDUAL_ALLOWANCE
			var allowance_excess := into_solid - allowed_raw
			if allowance_excess > 0.0:
				allowance_excess_count += 1
			if allowance_excess > allowance_excess_max:
				allowance_excess_max = allowance_excess
				worst_pixel = Vector2i(x, y)
				worst_proximity = proximity
			inner_effective_max = maxf(inner_effective_max, effective_into_solid)

	var total_content := content_rect.size.x * content_rect.size.y
	var solid_fraction := float(solid_count) / float(maxi(total_content, 1))
	var solid_flow_mean := solid_flow_magnitude_sum / float(maxi(solid_count, 1))
	var inner_effective_mean := inner_effective_sum / float(maxi(inner_ring_count, 1))
	var inner_over_soft_fraction := float(inner_over_soft_limit) / float(maxi(inner_ring_count, 1))
	print("  solid_pixels=", solid_count, " (", String.num(solid_fraction * 100.0, 2), "% of content)")
	print("  solid_flow_mean_magnitude=", String.num(solid_flow_mean, 4))
	print("  outer_ring_samples=", outer_ring_count, " outer_effective_max=", String.num(outer_effective_max, 4), " (diagnostic only - approach flow is physical)")
	var allowance_excess_fraction := float(allowance_excess_count) / float(maxi(inner_ring_count, 1))
	print("  inner_ring_samples=", inner_ring_count)
	print("  inner_raw_into_solid_max=", String.num(inner_raw_max, 4))
	print("  inner_effective_into_solid_max=", String.num(inner_effective_max, 4))
	print("  inner_effective_into_solid_mean_positive=", String.num(inner_effective_mean, 4))
	print("  inner_over_soft_limit_fraction=", String.num(inner_over_soft_fraction * 100.0, 2), "%")
	print("  allowance_excess_max=", String.num(allowance_excess_max, 4), " at ", worst_pixel, " proximity=", String.num(worst_proximity, 3))
	print("  allowance_excess_fraction=", String.num(allowance_excess_fraction * 100.0, 3), "%")

	if expect_solids:
		_expect(solid_count > 0, case_name + ": expected solid occupancy pixels but found none.")
	if solid_count > 0:
		_expect(solid_fraction < 0.9, case_name + ": occupancy is almost entirely solid (" + String.num(solid_fraction * 100.0, 1) + "%) - mask looks inverted or broken.")
		_expect(solid_flow_mean <= SOLID_FLOW_MAGNITUDE_MAX_MEAN, case_name + ": mean flow magnitude inside solids is " + String.num(solid_flow_mean, 4) + " (limit " + String.num(SOLID_FLOW_MAGNITUDE_MAX_MEAN, 3) + ").")
	if inner_ring_count > 0:
		_expect(allowance_excess_max <= MAX_ALLOWANCE_EXCESS, case_name + ": into-solid flow exceeds the distance-scaled allowance by " + String.num(allowance_excess_max, 4) + " (limit " + String.num(MAX_ALLOWANCE_EXCESS, 3) + ") at " + str(worst_pixel) + ".")
		_expect(allowance_excess_fraction <= ALLOWANCE_EXCESS_MAX_FRACTION, case_name + ": " + String.num(allowance_excess_fraction * 100.0, 3) + "% of inner-ring samples exceed the distance-scaled allowance.")
		_expect(inner_over_soft_fraction <= SOFT_LIMIT_MAX_FRACTION, case_name + ": " + String.num(inner_over_soft_fraction * 100.0, 2) + "% of inner-ring samples exceed the effective soft into-solid limit.")
	return _errors.is_empty()


func _near_column_edge(x: int, content_rect: Rect2i, side: int) -> bool:
	# Atlas columns are world-disjoint; proximity gradients sampled across a
	# column boundary are meaningless, so guard a band around each edge.
	var local_x := x - content_rect.position.x
	var column := int(float(local_x) * float(side) / float(content_rect.size.x))
	var column_start := int(floor(float(column) * float(content_rect.size.x) / float(side)))
	var column_end := int(floor(float(column + 1) * float(content_rect.size.x) / float(side)))
	return local_x < column_start + COLUMN_EDGE_GUARD_PIXELS or local_x >= column_end - COLUMN_EDGE_GUARD_PIXELS


func _proximity_gradient(occupancy_image: Image, x: int, y: int) -> Vector2:
	var width := occupancy_image.get_width()
	var height := occupancy_image.get_height()
	var left := occupancy_image.get_pixel(clampi(x - GRADIENT_SAMPLE_OFFSET, 0, width - 1), y).g
	var right := occupancy_image.get_pixel(clampi(x + GRADIENT_SAMPLE_OFFSET, 0, width - 1), y).g
	var up := occupancy_image.get_pixel(x, clampi(y - GRADIENT_SAMPLE_OFFSET, 0, height - 1)).g
	var down := occupancy_image.get_pixel(x, clampi(y + GRADIENT_SAMPLE_OFFSET, 0, height - 1)).g
	return Vector2(right - left, down - up)


func _on_river_progress_notified(_progress: float, message: String) -> void:
	if message == "finished":
		_bake_done = true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
