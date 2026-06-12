# General-purpose bake channel inspector (headless OK): loads a saved bake
# resource, decodes a channel, prints distribution stats, and dumps a
# grayscale PNG for visual review. Works on river bakes (RiverBakeData) and
# the WaterSystem map (WaterSystemBakeData). Channel semantics are documented
# in docs/spec-driven/features/river-future/Data Contract.md.
#
# Run:
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/bake_inspect_probe.gd -- bake=res://waterways_bakes/Demo/Water_River.river_bake.res texture=flow_foam_noise channel=rg
#
# Args (key=value):
#   bake=<res:// path>     REQUIRED - .res bake resource
#   texture=<property>     river: flow_foam_noise | dist_pressure | obstacle_features |
#                          terrain_contact_features | bank_response_features | water_occupancy
#                          system: system_map. Default: flow_foam_noise (river) / system_map (system)
#   channel=<r|g|b|a|rg>   rg = decoded packed flow vector stats (default rg for
#                          flow textures, r otherwise)
#   png=<true|false>       dump grayscale PNG (default true)
#   out=<res:// dir>       default res://addons/waterways/probes/out
#
# Success marker: BAKE_INSPECT_OK
extends SceneTree

const WaterHelperMethods := preload("res://addons/waterways/water_helper_methods.gd")

const DEFAULT_OUT_DIR := "res://addons/waterways/probes/out"
const NEAR_NEUTRAL := 0.02
const CHANNEL_INDEX := {"r": 0, "g": 1, "b": 2, "a": 3}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var bake_path := String(args.get("bake", ""))
	if bake_path.is_empty():
		push_error("bake= is required, e.g. -- bake=res://waterways_bakes/Demo/Water_River.river_bake.res")
		quit(1)
		return
	var bake := load(bake_path) as Resource
	if bake == null:
		push_error("Could not load bake: " + bake_path)
		quit(1)
		return

	var is_system := bake.get("system_map") != null or _resource_is_system(bake)
	var texture_property := String(args.get("texture", "system_map" if is_system else "flow_foam_noise"))
	var texture := bake.get(texture_property) as Texture2D
	if texture == null:
		push_error("Bake has no texture property \"" + texture_property + "\" (or it is unset).")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Texture \"" + texture_property + "\" has no readable image.")
		quit(1)
		return

	var default_channel := "rg" if texture_property in ["flow_foam_noise", "system_map"] else "r"
	var channel := String(args.get("channel", default_channel)).to_lower()
	var rect := _content_rect(bake, image)
	print("BAKE_INSPECT bake=", bake_path, " texture=", texture_property, " channel=", channel,
		" image=", image.get_width(), "x", image.get_height(), " rect=", rect)
	_print_channel_metadata(bake, texture_property, channel)

	var dump_png := String(args.get("png", "true")).to_lower() != "false"
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var png_stem := "%s_%s_%s" % [bake_path.get_file().get_basename().validate_filename(), texture_property, channel]

	if channel == "rg":
		# The system map's outside-coverage pixels are black (decode to (-1,-1)),
		# so flow stats there are meaningless - gate on the A coverage mask.
		var use_coverage_mask := texture_property == "system_map"
		_inspect_flow(image, rect, use_coverage_mask, dump_png, out_dir, png_stem)
	elif CHANNEL_INDEX.has(channel):
		_inspect_scalar(image, rect, CHANNEL_INDEX[channel], dump_png, out_dir, png_stem)
	else:
		push_error("Unknown channel \"" + channel + "\" - use r, g, b, a, or rg.")
		quit(1)
		return
	print("BAKE_INSPECT_OK")
	quit(0)


func _inspect_scalar(image: Image, rect: Rect2i, channel_index: int, dump_png: bool, out_dir: String, png_stem: String) -> void:
	var values := PackedFloat32Array()
	var sum := 0.0
	for y in rect.size.y:
		for x in rect.size.x:
			var color := image.get_pixel(rect.position.x + x, rect.position.y + y)
			var value: float = color[channel_index]
			values.append(value)
			sum += value
	values.sort()
	var count := values.size()
	var zero_count := 0
	var one_count := 0
	for value in values:
		if value <= NEAR_NEUTRAL:
			zero_count += 1
		elif value >= 1.0 - NEAR_NEUTRAL:
			one_count += 1
	print("  count=", count,
		" min=", _f(values[0]), " p25=", _f(_percentile(values, 0.25)),
		" median=", _f(_percentile(values, 0.5)), " p75=", _f(_percentile(values, 0.75)),
		" max=", _f(values[count - 1]), " mean=", _f(sum / float(count)))
	print("  near_zero(<=", NEAR_NEUTRAL, ")=", _pct(zero_count, count),
		" near_one(>=", 1.0 - NEAR_NEUTRAL, ")=", _pct(one_count, count))
	if dump_png:
		var dump := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		for y in rect.size.y:
			for x in rect.size.x:
				var value: float = image.get_pixel(rect.position.x + x, rect.position.y + y)[channel_index]
				dump.set_pixel(x, y, Color(value, value, value, 1.0))
		_save_png(dump, out_dir, png_stem)


func _inspect_flow(image: Image, rect: Rect2i, use_coverage_mask: bool, dump_png: bool, out_dir: String, png_stem: String) -> void:
	var magnitudes := PackedFloat32Array()
	var magnitude_sum := 0.0
	var vector_sum := Vector2.ZERO
	var neutral_count := 0
	var uncovered_count := 0
	for y in rect.size.y:
		for x in rect.size.x:
			var color := image.get_pixel(rect.position.x + x, rect.position.y + y)
			if use_coverage_mask and color.a < 0.5:
				uncovered_count += 1
				continue
			var flow: Vector2 = WaterHelperMethods.decode_packed_flow_vector(color)
			var magnitude := flow.length()
			magnitudes.append(magnitude)
			magnitude_sum += magnitude
			vector_sum += flow
			if magnitude < NEAR_NEUTRAL:
				neutral_count += 1
	var count := magnitudes.size()
	if count == 0:
		print("  no covered pixels to inspect (uncovered=", uncovered_count, ")")
		return
	magnitudes.sort()
	print("  count=", count,
		" mag_min=", _f(magnitudes[0]), " mag_median=", _f(_percentile(magnitudes, 0.5)),
		" mag_mean=", _f(magnitude_sum / float(count)), " mag_max=", _f(magnitudes[count - 1]))
	print("  near_neutral(<", NEAR_NEUTRAL, ")=", _pct(neutral_count, count),
		" avg_vec=", vector_sum / float(count),
		(" uncovered=" + _pct(uncovered_count, count + uncovered_count)) if use_coverage_mask else "")
	if dump_png:
		var dump := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		for y in rect.size.y:
			for x in rect.size.x:
				var color := image.get_pixel(rect.position.x + x, rect.position.y + y)
				var value := 0.0
				if not (use_coverage_mask and color.a < 0.5):
					value = clampf(WaterHelperMethods.decode_packed_flow_vector(color).length() * 2.0, 0.0, 1.0)
				dump.set_pixel(x, y, Color(value, value, value, 1.0))
		_save_png(dump, out_dir, png_stem)


func _content_rect(bake: Resource, image: Image) -> Rect2i:
	var rect_variant = bake.get("content_rect")
	if rect_variant is Rect2i and (rect_variant as Rect2i).has_area():
		return rect_variant
	return Rect2i(0, 0, image.get_width(), image.get_height())


func _print_channel_metadata(bake: Resource, texture_property: String, channel: String) -> void:
	var metadata_variant = bake.get("channel_metadata")
	if not (metadata_variant is Dictionary):
		return
	var texture_metadata: Dictionary = (metadata_variant as Dictionary).get(texture_property, {})
	if texture_metadata.is_empty():
		return
	if channel == "rg":
		print("  semantics: r=", texture_metadata.get("r", "?"), " g=", texture_metadata.get("g", "?"))
	else:
		print("  semantics: ", channel, "=", texture_metadata.get(channel, "?"))


func _resource_is_system(bake: Resource) -> bool:
	var script := bake.get_script() as Script
	return script != null and script.resource_path.ends_with("water_system_bake_data.gd")


func _save_png(dump: Image, out_dir: String, png_stem: String) -> void:
	var out_base := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_base)
	var file_path := out_base + "/" + png_stem + ".png"
	dump.save_png(file_path)
	print("  png=", file_path)


func _percentile(sorted_values: PackedFloat32Array, fraction: float) -> float:
	var index := clampi(int(round(fraction * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1)
	return sorted_values[index]


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args


func _f(value: float) -> String:
	return String.num(value, 4)


func _pct(numerator: int, denominator: int) -> String:
	if denominator <= 0:
		return "0%"
	return String.num(100.0 * float(numerator) / float(denominator), 2) + "%"
