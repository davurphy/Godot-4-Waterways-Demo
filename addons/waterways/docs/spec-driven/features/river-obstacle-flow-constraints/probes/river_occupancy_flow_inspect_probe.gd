# Diagnostic-only: loads the existing baked river resources (no rebake) and
# dumps occupancy/flow diagnostics as PNGs plus speckle/coverage statistics,
# to investigate over-aggressive flow stilling beside obstacles.
#
# Run (resource reads only, headless is fine):
#   & $godotConsole --headless --path $root --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_occupancy_flow_inspect_probe.gd
extends SceneTree

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const BAKES := [
	{
		"name": "main_demo",
		"path": "res://waterways_bakes/Demo/Water_River.river_bake.res",
	},
	{
		"name": "obstacle_test",
		"path": "res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
	},
]

const OUT_DIR := "res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/out"
const SOLID_THRESHOLD := 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for bake_variant in BAKES:
		var case := bake_variant as Dictionary
		_inspect(String(case["name"]), String(case["path"]))
	print("RIVER_OCCUPANCY_FLOW_INSPECT_DONE")
	quit(0)


func _inspect(case_name: String, path: String) -> void:
	var bake_data := load(path) as Resource
	if bake_data == null:
		print("CASE ", case_name, ": could not load ", path)
		return
	var flow_texture := bake_data.get("flow_foam_noise") as Texture2D
	var occupancy_texture := bake_data.get("water_occupancy") as Texture2D
	var content_rect: Rect2i = bake_data.get("content_rect")
	var metadata: Dictionary = bake_data.get("source_metadata")
	print("CASE ", case_name)
	print("  flow_projected=", metadata.get("flow_projected", "<missing>"))
	if flow_texture == null:
		print("  flow texture missing")
		return
	var flow_image := flow_texture.get_image()
	var occupancy_image: Image = occupancy_texture.get_image() if occupancy_texture != null else null
	var terrain_contact_texture := bake_data.get("terrain_contact_features") as Texture2D
	var terrain_contact_image: Image = terrain_contact_texture.get_image() if terrain_contact_texture != null else null
	var width := flow_image.get_width()
	var height := flow_image.get_height()
	print("  size=", width, "x", height, " content_rect=", content_rect)

	var solid_count := 0
	var protrusion_solid_count := 0
	var speckle_count := 0
	var proximity_nonzero := 0
	var flow_mag_sum_open := 0.0
	var open_count := 0
	var dead_open_count := 0
	# Mean |flow| binned by proximity (0..1 in 10 bins) for open-water texels.
	var bin_mag_sum := PackedFloat64Array()
	var bin_count := PackedInt64Array()
	bin_mag_sum.resize(10)
	bin_count.resize(10)

	var solid_img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var proximity_img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var flow_mag_img := Image.create(width, height, false, Image.FORMAT_RGBA8)

	for y in height:
		for x in width:
			var flow := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(x, y))
			var magnitude := flow.length()
			flow_mag_img.set_pixel(x, y, Color(clampf(magnitude * 2.0, 0.0, 1.0), clampf((magnitude - 0.5) * 2.0, 0.0, 1.0), 0.0, 1.0))
			if occupancy_image == null:
				continue
			var occupancy := occupancy_image.get_pixel(x, y)
			solid_img.set_pixel(x, y, Color(occupancy.r, occupancy.r, occupancy.r, 1.0))
			proximity_img.set_pixel(x, y, Color(occupancy.g, occupancy.g, occupancy.g, 1.0))
			if not content_rect.has_point(Vector2i(x, y)):
				continue
			if occupancy.g > 0.01:
				proximity_nonzero += 1
			if occupancy.r > SOLID_THRESHOLD:
				solid_count += 1
				if terrain_contact_image != null and terrain_contact_image.get_size() == flow_image.get_size():
					if terrain_contact_image.get_pixel(x, y).b >= 0.5:
						protrusion_solid_count += 1
				var solid_neighbors := 0
				for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var neighbor := Vector2i(x, y) + offset
					if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
						continue
					if occupancy_image.get_pixel(neighbor.x, neighbor.y).r > SOLID_THRESHOLD:
						solid_neighbors += 1
				if solid_neighbors <= 1:
					speckle_count += 1
			else:
				open_count += 1
				flow_mag_sum_open += magnitude
				if magnitude < 0.02:
					dead_open_count += 1
				var bin := clampi(int(occupancy.g * 10.0), 0, 9)
				bin_mag_sum[bin] += magnitude
				bin_count[bin] += 1

	var total_content := maxi(content_rect.size.x * content_rect.size.y, 1)
	print("  solid_pixels=", solid_count, " (", String.num(float(solid_count) / float(total_content) * 100.0, 2), "% of content)")
	print("  solid_from_terrain_protrusion=", protrusion_solid_count, " (", String.num(float(protrusion_solid_count) / float(maxi(solid_count, 1)) * 100.0, 1), "% of solids)")
	print("  solid_speckles(<=1 solid neighbor)=", speckle_count, " (", String.num(float(speckle_count) / float(maxi(solid_count, 1)) * 100.0, 1), "% of solids)")
	print("  proximity_nonzero=", proximity_nonzero, " (", String.num(float(proximity_nonzero) / float(total_content) * 100.0, 2), "% of content)")
	print("  open_water_mean_flow_magnitude=", String.num(flow_mag_sum_open / float(maxi(open_count, 1)), 4))
	print("  open_water_dead_fraction(|flow|<0.02)=", String.num(float(dead_open_count) / float(maxi(open_count, 1)) * 100.0, 2), "%")
	for bin in 10:
		if bin_count[bin] == 0:
			continue
		print("  proximity_bin ", String.num(bin * 0.1, 1), "-", String.num(bin * 0.1 + 0.1, 1), ": mean|flow|=", String.num(bin_mag_sum[bin] / float(bin_count[bin]), 4), " n=", bin_count[bin])

	var out_base := ProjectSettings.globalize_path(OUT_DIR)
	solid_img.save_png(out_base + "/" + case_name + "_occupancy_solid.png")
	proximity_img.save_png(out_base + "/" + case_name + "_occupancy_proximity.png")
	flow_mag_img.save_png(out_base + "/" + case_name + "_flow_magnitude.png")
	print("  wrote PNGs to ", out_base)
