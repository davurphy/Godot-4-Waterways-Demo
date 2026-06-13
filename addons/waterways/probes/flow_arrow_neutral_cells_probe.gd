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
# Shared copy of the river-obstacle-flow-constraints probe. Args:
#   bake=<res:// path>  river bake resource (defaults to the main demo bake)
#   out=<dir path>      overlay PNG output directory (defaults to probes/out)
# Success marker: ARROW_NEUTRAL_CELLS_PROBE_OK
extends SceneTree

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"
const OUT_DIR := "res://addons/waterways/probes/out"

# Mirror river_debug.gdshader arrow constants.
const ARROWS_PER_TILE := 8
const NEAR_NEUTRAL := 0.05
const PROBE_OFFSET_CELLS := 0.3
# Read from river_surface_common.gdshaderinc - the declaring source (R3.5);
# -1.0 means the include could not be parsed and the run must fail.
var SPEED_RAMP_FULL := WaterHelperMethods.get_occupancy_speed_ramp_full()
# Mirror occupancy bake constants.
const PROTRUSION_THRESHOLD := 0.9
const PROTRUSION_CONFIDENCE_MIN := 0.75


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if SPEED_RAMP_FULL <= 0.0:
		push_error("OCCUPANCY_SPEED_RAMP_FULL could not be read from river_surface_common.gdshaderinc.")
		quit(1)
		return
	var bake_path := BAKE_PATH
	var out_dir := OUT_DIR
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("bake="):
			bake_path = String(arg).trim_prefix("bake=")
		elif String(arg).begins_with("out="):
			out_dir = String(arg).trim_prefix("out=")
	var bake := load(bake_path) as Resource
	if bake == null:
		push_error("Could not load bake: " + bake_path)
		quit(1)
		return
	var flow_image := _get_bake_image(bake, "flow_foam_noise", bake_path)
	var occupancy_image := _get_bake_image(bake, "water_occupancy", bake_path)
	var terrain_image := _get_bake_image(bake, "terrain_contact_features", bake_path)
	if flow_image == null or occupancy_image == null or terrain_image == null:
		quit(1)
		return
	var content_rect := Rect2i(Vector2i.ZERO, flow_image.get_size())
	var content_rect_variant = bake.get("content_rect")
	if typeof(content_rect_variant) == TYPE_RECT2I and (content_rect_variant as Rect2i).size.x > 0 and (content_rect_variant as Rect2i).size.y > 0:
		content_rect = content_rect_variant
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
			var factor: float = smoothstep(0.0, SPEED_RAMP_FULL, openness)
			var displayed := flow * factor
			# Mirror river_debug's FLOW_ARROWS sub-cell fallback (4 probes, max
			# magnitude) so cells the shader displays via fallback are not
			# misreported as neutral.
			if displayed.length() <= NEAR_NEUTRAL:
				for probe_index in 4:
					var sign_x := -1.0 if probe_index % 2 == 0 else 1.0
					var sign_y := -1.0 if probe_index < 2 else 1.0
					var probe_x := clampi(px + int(sign_x * PROBE_OFFSET_CELLS * cell_w), 0, flow_image.get_width() - 1)
					var probe_y := clampi(py + int(sign_y * PROBE_OFFSET_CELLS * cell_h), 0, flow_image.get_height() - 1)
					var probe_flow := WaterHelperMethods.decode_packed_flow_vector(flow_image.get_pixel(probe_x, probe_y))
					var probe_factor: float = smoothstep(0.0, SPEED_RAMP_FULL, 1.0 - occupancy_image.get_pixel(probe_x, probe_y).g)
					var probe_displayed := probe_flow * probe_factor
					if probe_displayed.length() > displayed.length():
						displayed = probe_displayed
			if displayed.length() > NEAR_NEUTRAL:
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
	var out_base := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_base)
	var png_path := out_base + "/arrow_neutral_cells_" + bake_path.get_file().get_basename().validate_filename() + ".png"
	var save_error := overlay.save_png(png_path)
	if save_error != OK:
		push_error("Could not write overlay PNG (error " + str(save_error) + "): " + png_path)
		quit(1)
		return
	print("wrote ", png_path)
	print("ARROW_NEUTRAL_CELLS_PROBE_OK")
	quit(0)


func _get_bake_image(bake: Resource, property_name: String, bake_path: String) -> Image:
	var texture := bake.get(property_name) as Texture2D
	if texture == null:
		push_error(bake_path + " is missing texture " + property_name)
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error(bake_path + " texture is unreadable: " + property_name)
		return null
	return image


func _paint_cell(overlay: Image, content_rect: Rect2i, cx: int, cy: int, cell_w: float, cell_h: float, color: Color) -> void:
	var x0 := content_rect.position.x + int(float(cx) * cell_w)
	var y0 := content_rect.position.y + int(float(cy) * cell_h)
	for y in range(y0, mini(y0 + int(cell_h), overlay.get_height())):
		for x in range(x0, mini(x0 + int(cell_w), overlay.get_width())):
			overlay.set_pixel(x, y, overlay.get_pixel(x, y).lerp(color, 0.65))
