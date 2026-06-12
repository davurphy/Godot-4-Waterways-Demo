# Diagnostic-only (headless OK): mirrors the FLOW_ARROWS displayed-arrow
# logic (center sample + 4 sub-cell probes, max magnitude) per cell, then
# flags cells whose displayed direction deviates strongly from the average of
# their flowing neighbor cells. Reports whether each outlier came from the
# center sample (bake data) or the sub-cell fallback (probe pick), plus
# magnitudes, so misleading-arrow causes can be separated from bake issues.
#
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/flow_arrow_direction_outlier_probe.gd -- bake=res://waterways_bakes/Demo/Water_River.river_bake.res
#
# Shared copy of the river-obstacle-flow-constraints probe. Args:
#   bake=<res:// path>  river bake resource (defaults to the main demo bake)
#   out=<dir path>      overlay PNG output directory (defaults to probes/out)
# Success marker: ARROW_DIRECTION_OUTLIER_PROBE_OK
extends SceneTree

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const BAKE_PATH := "res://waterways_bakes/Demo/Water_River.river_bake.res"
const OUT_DIR := "res://addons/waterways/probes/out"

const ARROWS_PER_TILE := 8
const NEAR_NEUTRAL := 0.05
const SPEED_RAMP_FULL := 0.45
const PROBE_OFFSET_CELLS := 0.3
const OUTLIER_ANGLE_DEGREES := 60.0
const REPORT_LIMIT := 14

var _flow_image: Image
var _occupancy_image: Image
var _content_rect: Rect2i
var _cell_w: float
var _cell_h: float


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	_flow_image = _get_bake_image(bake, "flow_foam_noise", bake_path)
	_occupancy_image = _get_bake_image(bake, "water_occupancy", bake_path)
	if _flow_image == null or _occupancy_image == null:
		quit(1)
		return
	_content_rect = Rect2i(Vector2i.ZERO, _flow_image.get_size())
	var content_rect_variant = bake.get("content_rect")
	if typeof(content_rect_variant) == TYPE_RECT2I and (content_rect_variant as Rect2i).size.x > 0 and (content_rect_variant as Rect2i).size.y > 0:
		_content_rect = content_rect_variant
	var side := maxi(1, int(bake.get("uv2_sides")))
	var cells := side * ARROWS_PER_TILE
	_cell_w = float(_content_rect.size.x) / float(cells)
	_cell_h = float(_content_rect.size.y) / float(cells)

	# displayed[cy][cx] = {flow, from_fallback, center_solid}
	var displayed := []
	for cy in cells:
		var row := []
		for cx in cells:
			row.append(_displayed_arrow(cx, cy))
		displayed.append(row)

	var overlay := Image.create(_flow_image.get_width(), _flow_image.get_height(), false, Image.FORMAT_RGBA8)
	for y in _flow_image.get_height():
		for x in _flow_image.get_width():
			var magnitude := WaterHelperMethods.decode_packed_flow_vector(_flow_image.get_pixel(x, y)).length()
			var v := clampf(magnitude * 2.0, 0.0, 1.0)
			overlay.set_pixel(x, y, Color(v, v, v, 1.0))

	var outliers := []
	var cos_limit := cos(deg_to_rad(OUTLIER_ANGLE_DEGREES))
	for cy in cells:
		for cx in cells:
			var cell: Dictionary = displayed[cy][cx]
			var flow: Vector2 = cell.flow
			if flow.length() <= NEAR_NEUTRAL:
				continue
			# Average direction of flowing neighbor cells (column-local: skip
			# neighbors across the tile's lateral edge - world-disjoint).
			var neighbor_sum := Vector2.ZERO
			var neighbor_count := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := cx + dx
					var ny := cy + dy
					if nx < 0 or ny < 0 or nx >= cells or ny >= cells:
						continue
					if nx / ARROWS_PER_TILE != cx / ARROWS_PER_TILE:
						continue
					var neighbor_flow: Vector2 = displayed[ny][nx].flow
					if neighbor_flow.length() <= NEAR_NEUTRAL:
						continue
					neighbor_sum += neighbor_flow.normalized()
					neighbor_count += 1
			if neighbor_count < 3:
				continue
			var mean_direction := neighbor_sum / float(neighbor_count)
			if mean_direction.length() < 0.5:
				continue # neighbors disagree among themselves; skip
			var alignment := flow.normalized().dot(mean_direction.normalized())
			if alignment < cos_limit:
				outliers.append({
					"cell": Vector2i(cx, cy),
					"alignment": alignment,
					"magnitude": flow.length(),
					"from_fallback": cell.from_fallback,
					"center_solid": cell.center_solid,
					"flow": flow,
					"mean_neighbor": mean_direction.normalized(),
				})
				_paint_cell(overlay, cx, cy, Color(1.0, 0.0, 0.0, 1.0))

	outliers.sort_custom(func(a, b): return a.alignment < b.alignment)
	var fallback_count := 0
	for outlier in outliers:
		if outlier.from_fallback:
			fallback_count += 1
	print("ARROW_DIRECTION_OUTLIERS total=", outliers.size(), " from_fallback=", fallback_count, " from_center_sample=", outliers.size() - fallback_count)
	for index in mini(outliers.size(), REPORT_LIMIT):
		var o: Dictionary = outliers[index]
		print("  cell=", o.cell, " align=", String.num(o.alignment, 2), " |flow|=", String.num(o.magnitude, 3),
				" fallback=", o.from_fallback, " center_solid=", o.center_solid,
				" flow=", o.flow, " neighbors=", o.mean_neighbor)
	var out_base := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_base)
	var png_path := out_base + "/arrow_direction_outliers_" + bake_path.get_file().get_basename().validate_filename() + ".png"
	var save_error := overlay.save_png(png_path)
	if save_error != OK:
		push_error("Could not write overlay PNG (error " + str(save_error) + "): " + png_path)
		quit(1)
		return
	print("wrote ", png_path)
	print("ARROW_DIRECTION_OUTLIER_PROBE_OK")
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


func _sample(px: int, py: int) -> Vector2:
	px = clampi(px, 0, _flow_image.get_width() - 1)
	py = clampi(py, 0, _flow_image.get_height() - 1)
	var flow := WaterHelperMethods.decode_packed_flow_vector(_flow_image.get_pixel(px, py))
	var occupancy := _occupancy_image.get_pixel(px, py)
	var factor: float = smoothstep(0.0, SPEED_RAMP_FULL, 1.0 - occupancy.g)
	return flow * factor


func _displayed_arrow(cx: int, cy: int) -> Dictionary:
	var center_x := _content_rect.position.x + int((float(cx) + 0.5) * _cell_w)
	var center_y := _content_rect.position.y + int((float(cy) + 0.5) * _cell_h)
	var flow := _sample(center_x, center_y)
	var center_solid := _occupancy_image.get_pixel(center_x, center_y).r > 0.5
	var from_fallback := false
	if flow.length() <= NEAR_NEUTRAL:
		for probe_index in 4:
			var sign_x := -1.0 if probe_index % 2 == 0 else 1.0
			var sign_y := -1.0 if probe_index < 2 else 1.0
			var probe_x := center_x + int(sign_x * PROBE_OFFSET_CELLS * _cell_w)
			var probe_y := center_y + int(sign_y * PROBE_OFFSET_CELLS * _cell_h)
			var probe_flow := _sample(probe_x, probe_y)
			if probe_flow.length() > flow.length():
				flow = probe_flow
				from_fallback = true
	return {"flow": flow, "from_fallback": from_fallback, "center_solid": center_solid}


func _paint_cell(overlay: Image, cx: int, cy: int, color: Color) -> void:
	var x0 := _content_rect.position.x + int(float(cx) * _cell_w)
	var y0 := _content_rect.position.y + int(float(cy) * _cell_h)
	for y in range(y0, mini(y0 + int(_cell_h), overlay.get_height())):
		for x in range(x0, mini(x0 + int(_cell_w), overlay.get_width())):
			overlay.set_pixel(x, y, overlay.get_pixel(x, y).lerp(color, 0.65))
