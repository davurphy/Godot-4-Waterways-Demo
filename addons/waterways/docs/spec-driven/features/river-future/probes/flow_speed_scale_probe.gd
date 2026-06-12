# Validates per-point flow speed (Roadmap Phase 2): loads the saved (neutral)
# obstacle demo bake as the baseline, bakes once with an authored
# slow -> neutral -> fast profile, and verifies on the baked flow textures:
#  1. flow_speed_scaled metadata is false on the baseline, true on authored
#  2. baked |flow| scales down in the slow zone and up in the fast zone
#  3. flow direction is unchanged by the scale (projection guarantee survives)
#  4. flow inside solids stays near zero
# Does NOT save bake resources - the shipped demo bakes stay neutral.
#
# Run (NOT headless - bakes need viewport readback):
#   & $godotConsole --path $root --script res://addons/waterways/docs/spec-driven/features/river-future/probes/flow_speed_scale_probe.gd
extends SceneTree

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const SCENE_PATH := "res://Demo_obstacle_flow_test.tscn"
const RIVER_NODE_PATH := "WaterSystem/Water River"
const BASELINE_BAKE_PATH := "res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res"
const SLOW_FACTOR := 0.5
const FAST_FACTOR := 1.5
const NEAR_NEUTRAL := 0.02
const SOLID_THRESHOLD := 0.5
const SOLID_FLOW_MAGNITUDE_MAX_MEAN := 0.03
const DIRECTION_MIN_MAGNITUDE := 0.05
const DIRECTION_MAX_MEAN_ANGLE_RAD := 0.12
const SLOW_BAND_MAX_RATIO := 0.75
const FAST_BAND_MIN_RATIO := 1.2
const NEUTRAL_BAND_RATIO_TOLERANCE := 0.15

var _bake_done := false
var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load scene: " + SCENE_PATH)
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
		_fail("Could not find " + RIVER_NODE_PATH)
		return
	if not river.progress_notified.is_connected(_on_river_progress_notified):
		river.progress_notified.connect(_on_river_progress_notified)
	var steps := int(river.get("_steps"))

	# Baseline: the saved demo bake is neutral (flow_speeds all 1.0), so its
	# flow content equals a fresh neutral bake without paying for one.
	var baseline_bake := load(BASELINE_BAKE_PATH) as Resource
	if baseline_bake == null:
		_fail("Could not load baseline bake: " + BASELINE_BAKE_PATH)
		return
	var baseline_metadata: Dictionary = baseline_bake.get("source_metadata")
	_expect(not bool(baseline_metadata.get("flow_speed_scaled", false)), "baseline bake should have flow_speed_scaled absent/false")
	var baseline := _measure(baseline_bake, steps)

	var point_count: int = river.curve.get_point_count()
	var authored_speeds := []
	var first_third := int(ceil(float(point_count) / 3.0))
	for i in point_count:
		if i < first_third:
			authored_speeds.append(SLOW_FACTOR)
		elif i >= point_count - first_third:
			authored_speeds.append(FAST_FACTOR)
		else:
			authored_speeds.append(1.0)
	river.set_flow_speeds(authored_speeds)
	print("FLOW_SPEED_PROBE baking authored profile slow=", SLOW_FACTOR, " fast=", FAST_FACTOR, " points=", point_count)
	if not await _bake(river):
		return
	var authored_bake := river.get("bake_data") as Resource
	var authored_metadata: Dictionary = authored_bake.get("source_metadata")
	_expect(bool(authored_metadata.get("flow_speed_scaled", false)), "authored bake should have flow_speed_scaled=true")
	var scaled := _measure(authored_bake, steps)

	_compare(baseline, scaled)

	if _errors.is_empty():
		print("FLOW_SPEED_SCALE_PROBE_OK")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _bake(river) -> bool:
	_bake_done = false
	river.bake_texture()
	var frames := 0
	while not _bake_done and frames < 7200:
		await process_frame
		frames += 1
	if not _bake_done:
		_fail("River bake did not finish within timeout")
		return false
	return true


# Returns per-step mean open-water |flow|, sampled decoded vectors, and solid
# stats, for band comparison between bakes.
func _measure(bake_data: Resource, steps: int) -> Dictionary:
	var flow_image: Image = (bake_data.get("flow_foam_noise") as Texture2D).get_image()
	var occupancy_texture := bake_data.get("water_occupancy") as Texture2D
	var occupancy_image: Image = occupancy_texture.get_image() if occupancy_texture != null else null
	var content_rect: Rect2i = bake_data.get("content_rect")
	var side := int(bake_data.get("uv2_sides"))
	var step_means := []
	var solid_sum := 0.0
	var solid_count := 0
	var vectors := {}
	for step_index in steps:
		var tile_rect: Rect2i = WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, content_rect)
		var magnitude_sum := 0.0
		var magnitude_count := 0
		for y in range(0, tile_rect.size.y, 2):
			for x in range(0, tile_rect.size.x, 2):
				var px := tile_rect.position.x + x
				var py := tile_rect.position.y + y
				var solid := false
				if occupancy_image != null:
					solid = occupancy_image.get_pixel(px, py).r > SOLID_THRESHOLD
				var color := flow_image.get_pixel(px, py)
				var flow := Vector2(color.r - 0.5, color.g - 0.5) * 2.0
				if solid:
					solid_sum += flow.length()
					solid_count += 1
					continue
				if flow.length() < NEAR_NEUTRAL:
					continue
				magnitude_sum += flow.length()
				magnitude_count += 1
				vectors[Vector2i(px, py)] = flow
		step_means.append(magnitude_sum / float(magnitude_count) if magnitude_count > 0 else 0.0)
	return {
		"step_means": step_means,
		"solid_mean": solid_sum / float(solid_count) if solid_count > 0 else 0.0,
		"vectors": vectors,
	}


func _compare(baseline: Dictionary, scaled: Dictionary) -> void:
	var steps: int = baseline.step_means.size()
	var slow_ratio := _band_ratio(baseline.step_means, scaled.step_means, 0.0, 0.1)
	var neutral_ratio := _band_ratio(baseline.step_means, scaled.step_means, 0.45, 0.55)
	var fast_ratio := _band_ratio(baseline.step_means, scaled.step_means, 0.9, 1.0)
	print("FLOW_SPEED_PROBE steps=", steps,
		" slow_band_ratio=", slow_ratio,
		" neutral_band_ratio=", neutral_ratio,
		" fast_band_ratio=", fast_ratio,
		" solid_mean_neutral=", baseline.solid_mean,
		" solid_mean_scaled=", scaled.solid_mean)
	_expect(slow_ratio < SLOW_BAND_MAX_RATIO, "slow band ratio %f should be < %f" % [slow_ratio, SLOW_BAND_MAX_RATIO])
	_expect(fast_ratio > FAST_BAND_MIN_RATIO, "fast band ratio %f should be > %f" % [fast_ratio, FAST_BAND_MIN_RATIO])
	_expect(absf(neutral_ratio - 1.0) < NEUTRAL_BAND_RATIO_TOLERANCE, "neutral band ratio %f should be ~1.0" % neutral_ratio)
	_expect(scaled.solid_mean < SOLID_FLOW_MAGNITUDE_MAX_MEAN, "solid mean |flow| %f should stay < %f" % [scaled.solid_mean, SOLID_FLOW_MAGNITUDE_MAX_MEAN])

	# Direction preservation: the scale must not rotate the field.
	var angle_sum := 0.0
	var angle_count := 0
	for key in baseline.vectors:
		if not scaled.vectors.has(key):
			continue
		var before: Vector2 = baseline.vectors[key]
		var after: Vector2 = scaled.vectors[key]
		if before.length() < DIRECTION_MIN_MAGNITUDE or after.length() < DIRECTION_MIN_MAGNITUDE:
			continue
		angle_sum += absf(before.angle_to(after))
		angle_count += 1
	var mean_angle := angle_sum / float(angle_count) if angle_count > 0 else 0.0
	print("FLOW_SPEED_PROBE direction_samples=", angle_count, " mean_angle_delta_rad=", mean_angle)
	_expect(angle_count > 0, "no comparable direction samples found")
	_expect(mean_angle < DIRECTION_MAX_MEAN_ANGLE_RAD, "mean direction delta %f rad should be < %f" % [mean_angle, DIRECTION_MAX_MEAN_ANGLE_RAD])


func _band_ratio(before: Array, after: Array, from_fraction: float, to_fraction: float) -> float:
	var steps := before.size()
	var from_index := int(floor(from_fraction * float(steps)))
	var to_index := int(ceil(to_fraction * float(steps)))
	var before_sum := 0.0
	var after_sum := 0.0
	var count := 0
	for step_index in range(from_index, mini(to_index, steps)):
		if float(before[step_index]) <= 0.0:
			continue
		before_sum += float(before[step_index])
		after_sum += float(after[step_index])
		count += 1
	if count == 0 or before_sum <= 0.0:
		return 0.0
	return after_sum / before_sum


func _on_river_progress_notified(_progress: float, message: String) -> void:
	if message == "finished":
		_bake_done = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
