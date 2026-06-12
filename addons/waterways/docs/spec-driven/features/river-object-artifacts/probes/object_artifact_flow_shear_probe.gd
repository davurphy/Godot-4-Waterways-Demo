extends SceneTree

# Measures lateral shear in the baked flow field (flow_foam_noise RG):
# the worst and mean |delta| of the decoded flow vector between laterally
# adjacent texels (x axis = across the river) inside occupied UV2 tiles,
# plus the count of texel pairs above SHEAR_THRESHOLD. The
# obstacle-avoidance tangent flip wrote hard lateral flow reversals along
# obstacle stagnation centerlines - visible as static crack-like seams in
# the advected water pattern.
# Success marker: OBJECT_ARTIFACT_FLOW_SHEAR_PROBE_OK

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"
const SHEAR_THRESHOLD := 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bake := load(BAKE_PATH) as Resource
	if bake == null:
		push_error("Could not load bake resource: " + BAKE_PATH)
		quit(1)
		return
	var flow_texture := bake.get("flow_foam_noise") as Texture2D
	if flow_texture == null:
		push_error("Bake missing flow_foam_noise")
		quit(1)
		return
	var image := flow_texture.get_image()
	var content_rect := bake.get("content_rect") as Rect2i
	if content_rect.size.x <= 0:
		content_rect = Rect2i(Vector2i.ZERO, image.get_size())
	var uv2_sides := maxi(1, int(bake.get("uv2_sides")))
	var occupied_steps := uv2_sides * uv2_sides
	var signature = bake.get("source_signature")
	if typeof(signature) == TYPE_DICTIONARY:
		var signature_steps := int((signature as Dictionary).get("step_count", 0))
		if signature_steps > 0:
			occupied_steps = clampi(signature_steps, 1, occupied_steps)

	var pair_count := 0
	var shear_pairs := 0
	var delta_sum := 0.0
	var delta_max := 0.0
	var width := content_rect.size.x
	var height := content_rect.size.y
	for x in range(width - 1):
		for y in height:
			var step_a := _step_index(x, y, width, height, uv2_sides)
			var step_b := _step_index(x + 1, y, width, height, uv2_sides)
			if step_a >= occupied_steps or step_b != step_a:
				continue
			var color_a := image.get_pixel(content_rect.position.x + x, content_rect.position.y + y)
			var color_b := image.get_pixel(content_rect.position.x + x + 1, content_rect.position.y + y)
			var flow_a := Vector2(color_a.r, color_a.g) * 2.0 - Vector2.ONE
			var flow_b := Vector2(color_b.r, color_b.g) * 2.0 - Vector2.ONE
			var delta := flow_a.distance_to(flow_b)
			pair_count += 1
			delta_sum += delta
			delta_max = maxf(delta_max, delta)
			if delta >= SHEAR_THRESHOLD:
				shear_pairs += 1
	print("OBJECT_ARTIFACT_FLOW_SHEAR pairs=", pair_count,
		" shear_pairs(>=", SHEAR_THRESHOLD, ")=", shear_pairs,
		" mean_delta=", snappedf(delta_sum / maxf(1.0, float(pair_count)), 0.0001),
		" max_delta=", snappedf(delta_max, 0.0001))
	print("OBJECT_ARTIFACT_FLOW_SHEAR_PROBE_OK")
	quit(0)


func _step_index(x: int, y: int, width: int, height: int, side: int) -> int:
	var column: int = WaterHelperMethods._uv2_atlas_axis_index(x, width, side)
	var row: int = WaterHelperMethods._uv2_atlas_axis_index(y, height, side)
	return column * side + row
