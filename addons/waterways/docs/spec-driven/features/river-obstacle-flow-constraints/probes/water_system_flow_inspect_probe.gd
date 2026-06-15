# Diagnostic-only: dumps the WaterSystem combined map's flow channels (what
# buoyant ducks actually sample via get_water_flow) as a magnitude PNG with
# stats, to locate dead zones beside obstacles.
#
#   & $godotConsole --headless --path $root --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/water_system_flow_inspect_probe.gd
extends SceneTree

# The obstacle scene's own system bake (scenes stopped sharing one bake
# resource 2026-06-12; Demo.tscn's lives in waterways_bakes/Demo_28018/).
const BAKE_PATH := "res://waterways_bakes/Demo_obstacle_flow_test/WaterSystem.water_system_bake.res"
const OUT_DIR := "res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/out"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bake := load(BAKE_PATH) as Resource
	if bake == null:
		print("Could not load ", BAKE_PATH)
		quit(1)
		return
	var map := bake.get("system_map") as Texture2D
	if map == null:
		print("system_map texture missing")
		quit(1)
		return
	var image := map.get_image()
	var width := image.get_width()
	var height := image.get_height()
	print("system_map size=", width, "x", height)

	var magnitude_img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var covered := 0
	var dead := 0
	var magnitude_sum := 0.0
	for y in height:
		for x in width:
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				magnitude_img.set_pixel(x, y, Color(0.0, 0.0, 0.3, 1.0))
				continue
			covered += 1
			var flow := Vector2(color.r, color.g) * 2.0 - Vector2.ONE
			var magnitude := flow.length()
			magnitude_sum += magnitude
			if magnitude < 0.05:
				dead += 1
			magnitude_img.set_pixel(x, y, Color(clampf(magnitude, 0.0, 1.0), clampf(magnitude - 1.0, 0.0, 1.0), 0.0, 1.0))
	print("covered=", covered, " mean|flow|=", String.num(magnitude_sum / float(maxi(covered, 1)), 4), " dead_fraction(|flow|<0.05)=", String.num(float(dead) / float(maxi(covered, 1)) * 100.0, 2), "%")
	var out_base := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_base)
	magnitude_img.save_png(out_base + "/water_system_flow_magnitude.png")
	print("wrote ", out_base, "/water_system_flow_magnitude.png")
	quit(0)
