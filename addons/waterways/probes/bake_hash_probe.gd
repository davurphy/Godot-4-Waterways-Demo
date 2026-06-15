# RT.1 bake content hash + diff gate (headless OK): emits a per-texture MD5
# over the raw pixel data (plus format/size) of every texture in a
# RiverBakeData resource, and in diff mode compares two bake resources,
# exiting nonzero on any mismatch with a per-channel delta summary and the
# bounding rect of differing pixels (so a localized change - e.g. a margin
# fix - is visibly localized in the report).
#
# Gate consumer phases: R1 ("output must not change except explained
# regions"), R5/R6 ("byte-identical, hash-gated").
#
#   hash one bake:
#     & $godotConsole --headless --path $root --script res://addons/waterways/probes/bake_hash_probe.gd -- bake=res://waterways_bakes/Demo/Water_River.river_bake.res
#   diff two bakes:
#     & $godotConsole --headless --path $root --script res://addons/waterways/probes/bake_hash_probe.gd -- a=res://path_a.res b=res://path_b.res
#
# Success markers: BAKE_HASH_PROBE_OK (hash mode), BAKE_HASH_COMPARE_OK
# (diff mode, all textures identical). Mismatches print BAKE_HASH_MISMATCH
# lines and exit 1.
extends SceneTree

const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

const CHANNELS := ["r", "g", "b", "a"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bake_path := ""
	var a_path := ""
	var b_path := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("bake="):
			bake_path = String(arg).trim_prefix("bake=")
		elif String(arg).begins_with("a="):
			a_path = String(arg).trim_prefix("a=")
		elif String(arg).begins_with("b="):
			b_path = String(arg).trim_prefix("b=")

	if not a_path.is_empty() or not b_path.is_empty():
		if a_path.is_empty() or b_path.is_empty():
			push_error("Diff mode needs both a= and b= bake paths.")
			quit(1)
			return
		_run_diff(a_path, b_path)
		return
	if bake_path.is_empty():
		push_error("Pass bake=<res:// path> for hash mode or a=/b= for diff mode.")
		quit(1)
		return
	_run_hash(bake_path)


func _run_hash(bake_path: String) -> void:
	var bake := _load_bake(bake_path)
	if bake == null:
		quit(1)
		return
	print("BAKE_HASH_BAKE bake=", bake_path, " signature_version=", bake.get("source_signature_version"))
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var entry := _hash_texture(bake, property_name)
		print("BAKE_HASH texture=", property_name, " present=", entry.present,
				" size=", entry.size, " format=", entry.format, " md5=", entry.md5)
	print("BAKE_HASH_PROBE_OK")
	quit(0)


func _run_diff(a_path: String, b_path: String) -> void:
	var bake_a := _load_bake(a_path)
	var bake_b := _load_bake(b_path)
	if bake_a == null or bake_b == null:
		quit(1)
		return
	print("BAKE_HASH_DIFF a=", a_path, " b=", b_path)
	print("  signature_version a=", bake_a.get("source_signature_version"), " b=", bake_b.get("source_signature_version"))
	var mismatches := 0
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var entry_a := _hash_texture(bake_a, property_name)
		var entry_b := _hash_texture(bake_b, property_name)
		if entry_a.md5 == entry_b.md5 and entry_a.present == entry_b.present:
			print("BAKE_HASH_MATCH texture=", property_name, " md5=", entry_a.md5)
			continue
		mismatches += 1
		print("BAKE_HASH_MISMATCH texture=", property_name,
				" a_present=", entry_a.present, " b_present=", entry_b.present,
				" a_size=", entry_a.size, " b_size=", entry_b.size,
				" a_md5=", entry_a.md5, " b_md5=", entry_b.md5)
		if entry_a.present and entry_b.present and entry_a.size == entry_b.size:
			_print_channel_deltas(entry_a.image, entry_b.image, property_name)
		elif entry_a.present and entry_b.present:
			print("  (size mismatch - no per-channel delta computed)")
	if mismatches == 0:
		print("BAKE_HASH_COMPARE_OK")
		quit(0)
		return
	push_error("Bake content differs in " + str(mismatches) + " texture(s); see BAKE_HASH_MISMATCH lines.")
	quit(1)


func _load_bake(bake_path: String) -> Resource:
	var bake := load(bake_path) as Resource
	if bake == null:
		push_error("Could not load bake resource: " + bake_path)
	return bake


# Returns {present, size, format, md5, image}. Absent textures hash to "absent"
# so present-vs-null transitions register as mismatches, not crashes.
func _hash_texture(bake: Resource, property_name: String) -> Dictionary:
	var entry := {
		"present": false,
		"size": Vector2i.ZERO,
		"format": -1,
		"md5": "absent",
		"image": null,
	}
	var texture := bake.get(property_name) as Texture2D
	if texture == null:
		return entry
	var image := texture.get_image()
	if image == null or image.is_empty():
		entry.md5 = "unreadable"
		return entry
	entry.present = true
	entry.size = image.get_size()
	entry.format = image.get_format()
	entry.image = image
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	# Fold format and dimensions in so equal pixel bytes in different layouts
	# cannot collide.
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	entry.md5 = context.finish().hex_encode()
	return entry


func _print_channel_deltas(image_a: Image, image_b: Image, property_name: String) -> void:
	var width: int = image_a.get_width()
	var height: int = image_a.get_height()
	var max_delta := [0.0, 0.0, 0.0, 0.0]
	var sum_delta := [0.0, 0.0, 0.0, 0.0]
	var differing_pixels := 0
	var diff_min := Vector2i(width, height)
	var diff_max := Vector2i(-1, -1)
	var first_diff := Vector2i(-1, -1)
	for y in height:
		for x in width:
			var color_a := image_a.get_pixel(x, y)
			var color_b := image_b.get_pixel(x, y)
			var deltas := [
				absf(color_a.r - color_b.r),
				absf(color_a.g - color_b.g),
				absf(color_a.b - color_b.b),
				absf(color_a.a - color_b.a),
			]
			var pixel_differs := false
			for channel_index in 4:
				var delta: float = deltas[channel_index]
				if delta > 0.0:
					pixel_differs = true
					sum_delta[channel_index] += delta
					if delta > float(max_delta[channel_index]):
						max_delta[channel_index] = delta
			if pixel_differs:
				differing_pixels += 1
				if first_diff.x < 0:
					first_diff = Vector2i(x, y)
				diff_min = Vector2i(mini(diff_min.x, x), mini(diff_min.y, y))
				diff_max = Vector2i(maxi(diff_max.x, x), maxi(diff_max.y, y))
	var total_pixels := width * height
	var diff_rect := Rect2i()
	if diff_max.x >= 0:
		diff_rect = Rect2i(diff_min, diff_max - diff_min + Vector2i.ONE)
	print("  delta_summary texture=", property_name,
			" differing_pixels=", differing_pixels, "/", total_pixels,
			" diff_rect=", diff_rect, " first_diff=", first_diff)
	for channel_index in 4:
		var mean := 0.0
		if total_pixels > 0:
			mean = float(sum_delta[channel_index]) / float(total_pixels)
		print("    channel=", CHANNELS[channel_index],
				" max_delta=", snappedf(float(max_delta[channel_index]), 0.00001),
				" mean_delta=", snappedf(mean, 0.0000001))
