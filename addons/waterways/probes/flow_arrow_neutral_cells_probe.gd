# Diagnostic-only (headless OK): reproduces the river_debug FLOW_ARROWS
# neutral-cell decision per arrow cell from the saved bake, classifies every
# neutral cell by root cause, and writes an overlay PNG:
#   gray   = flow magnitude (open water)
#   red    = neutral cell, center texel solid via collision map
#   orange = neutral cell, center texel solid via terrain protrusion
#   yellow = neutral cell, open water but stilling ramp kills decent flow
#   magenta= neutral cell, open water but baked flow itself is near zero
#
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/flow_arrow_neutral_cells_probe.gd -- bake=res://waterways_bakes/Demo/Water_River.river_bake.res
#
# Shared copy of the river-obstacle-flow-constraints probe; `bake=` selects
# the river bake resource (defaults to the main demo bake).
extends SceneTree

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"
const OUT_DIR := "res://addons/waterways/probes/out"

# Mirror river_debug.gdshader arrow constants.
const ARROWS_PER_TILE := 8
const NEAR_NEUTRAL := 0.05
const SPEED_RAMP_FULL := 0.45
# Mirror occupancy bake constants.
const PROTRUSION_THRESHOLD := 0.9
const PROTRUSION_CONFIDENCE_MIN := 0.75


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bake_path := BAKE_PATH
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("bake="):
			bake_path = String(arg).trim_prefix("bake=")
	var bake := load(bake_path) as Resource
	if bake == null:
		push_error("Could not load bake: " + bake_path)
		quit(1)
		return
	var flow_image: Image = (bake.get("flow_foam_noise") as Texture2D).get_image()
	var occupancy_image: Image = (bake.get("water_occupancy") as Texture2D).get_image()
	var terrain_image: Image = (bake.get("terrain_contact_features") as Texture2D).get_image()
	var content_rect: Rect2i = bake.get("content_rect")
	var side := maxi(1, int(bake.get("uv2_sides")))
	var cells := side * ARROWS_PER_TILE
	var cell_w := float(content_rect.size.x) / float(cells)
	var cell_h := float(content_rect.size.y) / float(cells)

	var overlay := Image.create(flow_image.get_width(), flow_image.get_height(), false, Image.FORMAT_RGBA8)
	for y in flow_image.get_height():
		for x in flow_image.get_width():
			var magnitude := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(x, y)).length()
			var v := clampf(magnitude * 2.0, 0.0, 1.0)
			overlay.set_pixel(x, y, Color(v, v, v, 1.0))

	var counts := {"solid_collision": 0, "solid_protrusion": 0, "stilled_ring": 0, "dead_flow": 0, "flowing": 0}
	for cy in cells:
		for cx in cells:
			var px := content_rect.position.x + int((float(cx) + 0.5) * cell_w)
			var py := content_rect.position.y + int((float(cy) + 0.5) * cell_h)
			var flow := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(px, py))
			var occupancy := occupancy_image.get_pixel(px, py)
			var openness := 1.0 - occupancy.g
			var factor := smoothstep(0.0, SPEED_RAMP_FULL, openness)
			if flow.length() * factor > NEAR_NEUTRAL:
				counts.flowing += 1
				continue
			var color: Color
			if occupancy.r > 0.5:
				var terrain := terrain_image.get_pixel(px, py)
				if terrain.b >= PROTRUSION_THRESHOLD and terrain.a >= PROTRUSION_CONFIDENCE_MIN:
					counts.solid_protrusion += 1
					color = Color(1.0, 0.55, 0.0, 1.0)
				else:
					counts.solid_collision += 1
					color = Color(1.0, 0.0, 0.0, 1.0)
			elif flow.length() <= 0.05:
				counts.dead_flow += 1
				color = Color(1.0, 0.0, 1.0, 1.0)
			else:
				counts.stilled_ring += 1
				color = Color(1.0, 1.0, 0.0, 1.0)
			_paint_cell(overlay, content_rect, cx, cy, cell_w, cell_h, color)

	print("ARROW_NEUTRAL_CELLS counts=", counts)
	var out_base := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_base)
	var png_path := out_base + "/arrow_neutral_cells_" + bake_path.get_file().get_basename().validate_filename() + ".png"
	overlay.save_png(png_path)
	print("wrote ", png_path)
	quit(0)


func _paint_cell(overlay: Image, content_rect: Rect2i, cx: int, cy: int, cell_w: float, cell_h: float, color: Color) -> void:
	var x0 := content_rect.position.x + int(float(cx) * cell_w)
	var y0 := content_rect.position.y + int(float(cy) * cell_h)
	for y in range(y0, mini(y0 + int(cell_h), overlay.get_height())):
		for x in range(x0, mini(x0 + int(cell_w), overlay.get_width())):
			overlay.set_pixel(x, y, overlay.get_pixel(x, y).lerp(color, 0.65))
