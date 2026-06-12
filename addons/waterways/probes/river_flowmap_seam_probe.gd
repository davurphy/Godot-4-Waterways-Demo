# Seam continuity probe (headless OK): samples UV2 atlas logical-edge deltas
# across all baked channels of the listed river bakes. Re-run whenever flow
# bake content changes.
#
# By default this is DIAGNOSTIC: the exit code reflects only load/read
# errors, and the measured deltas land in the printed stats. Pass
# max_logical_delta=<float> to turn it into a gate - any depth-0 logical-edge
# max delta above the threshold then fails the run.
#
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/river_flowmap_seam_probe.gd
#   optional: -- bakes=res://path/a.res,res://path/b.res max_logical_delta=0.05
#
# Shared copy of the river-flowmap-seams probe. Success marker: RIVER_FLOWMAP_SEAM_PROBE_OK
extends SceneTree

const BAKE_PATHS := [
	"res://waterways_bakes/Demo/Water_River.river_bake.res",
	"res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
]

const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
]

const CHANNELS := ["r", "g", "b", "a"]
const EDGE_DEPTHS := [0, 1, 2]
const MAX_SAMPLES_PER_EDGE := 64
const TOP_SAMPLE_LIMIT := 12

const PRIORITY_CHANNELS := [
	"flow_foam_noise.r",
	"flow_foam_noise.g",
	"flow_foam_noise.b",
	"flow_foam_noise.a",
	"dist_pressure.b",
	"dist_pressure.a",
	"obstacle_features.r",
	"obstacle_features.g",
	"obstacle_features.b",
	"obstacle_features.a",
	"terrain_contact_features.r",
	"terrain_contact_features.g",
	"terrain_contact_features.b",
	"terrain_contact_features.a",
	"bank_response_features.r",
	"bank_response_features.g",
	"bank_response_features.b",
	"bank_response_features.a",
]

var _errors := PackedStringArray()
# Negative = diagnostic mode (no delta gating).
var _max_logical_delta := -1.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bake_paths := BAKE_PATHS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("bakes="):
			bake_paths = Array(String(arg).trim_prefix("bakes=").split(",", false))
		elif String(arg).begins_with("max_logical_delta="):
			_max_logical_delta = float(String(arg).trim_prefix("max_logical_delta="))
	for bake_path_variant in bake_paths:
		var bake_path := String(bake_path_variant)
		_inspect_bake(bake_path)
	if _errors.is_empty():
		print("RIVER_FLOWMAP_SEAM_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _inspect_bake(bake_path: String) -> void:
	var bake := load(bake_path) as Resource
	if bake == null:
		_expect(false, "Could not load bake resource: " + bake_path)
		return

	var images := _load_bake_images(bake, bake_path)
	if images.is_empty():
		return

	var first_image: Image = images[TEXTURE_PROPERTIES[0]]
	var content_rect := _get_content_rect(bake, first_image)
	var uv2_sides := maxi(1, int(bake.get("uv2_sides")))
	var occupied_steps := _get_occupied_steps(bake, uv2_sides)
	var stats := {}
	var global_logical_top := []
	var atlas_nonlogical_top := []

	for step_index in range(maxi(occupied_steps - 1, 0)):
		var current_tile := _tile_rect(step_index, uv2_sides, content_rect)
		var next_tile := _tile_rect(step_index + 1, uv2_sides, content_rect)
		var row := step_index % uv2_sides
		var kind := "logical_same_column"
		if row == uv2_sides - 1:
			kind = "logical_row_wrap"
		_sample_longitudinal_join(
			images,
			stats,
			global_logical_top,
			step_index,
			step_index + 1,
			current_tile,
			next_tile,
			kind
		)

	_sample_atlas_column_edges(images, stats, atlas_nonlogical_top, occupied_steps, uv2_sides, content_rect)
	_print_report(bake_path, bake, first_image, content_rect, uv2_sides, occupied_steps, stats, global_logical_top, atlas_nonlogical_top)
	_gate_logical_deltas(bake_path, stats)


func _gate_logical_deltas(bake_path: String, stats: Dictionary) -> void:
	if _max_logical_delta < 0.0:
		return
	for stat_key in stats:
		var stat: Dictionary = stats[stat_key]
		if int(stat["depth"]) != 0:
			continue
		var kind := String(stat["kind"])
		if kind != "logical_same_column" and kind != "logical_row_wrap":
			continue
		var max_delta := float(stat["max"])
		if max_delta > _max_logical_delta:
			_expect(false, bake_path + " seam gate: " + String(stat["channel"]) + " " + kind
					+ " depth=0 max_delta=" + str(_round5(max_delta))
					+ " exceeds max_logical_delta=" + str(_max_logical_delta)
					+ " at " + str(stat["max_sample"]))


func _load_bake_images(bake: Resource, bake_path: String) -> Dictionary:
	var images := {}
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var texture := bake.get(property_name) as Texture2D
		if texture == null:
			_expect(false, bake_path + " is missing texture " + property_name)
			return {}
		var image := texture.get_image()
		if image == null or image.is_empty():
			_expect(false, bake_path + " texture is unreadable: " + property_name)
			return {}
		images[property_name] = image
	return images


func _get_content_rect(bake: Resource, image: Image) -> Rect2i:
	var rect := bake.get("content_rect") as Rect2i
	var image_rect := Rect2i(Vector2i.ZERO, image.get_size())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return image_rect
	var position := Vector2i(
		clampi(rect.position.x, 0, image.get_width() - 1),
		clampi(rect.position.y, 0, image.get_height() - 1)
	)
	var end := Vector2i(
		clampi(rect.position.x + rect.size.x, position.x + 1, image.get_width()),
		clampi(rect.position.y + rect.size.y, position.y + 1, image.get_height())
	)
	return Rect2i(position, end - position)


func _get_occupied_steps(bake: Resource, uv2_sides: int) -> int:
	var total_tiles := uv2_sides * uv2_sides
	var signature = bake.get("source_signature")
	if typeof(signature) == TYPE_DICTIONARY:
		var signature_steps := int((signature as Dictionary).get("step_count", 0))
		if signature_steps > 0:
			return clampi(signature_steps, 1, total_tiles)
	return total_tiles


func _sample_longitudinal_join(
		images: Dictionary,
		stats: Dictionary,
		global_top: Array,
		from_step: int,
		to_step: int,
		from_tile: Rect2i,
		to_tile: Rect2i,
		kind: String
) -> void:
	if from_tile.size.x <= 0 or from_tile.size.y <= 0 or to_tile.size.x <= 0 or to_tile.size.y <= 0:
		return
	var sample_count := mini(MAX_SAMPLES_PER_EDGE, maxi(from_tile.size.x, to_tile.size.x))
	for depth_variant in EDGE_DEPTHS:
		var depth := int(depth_variant)
		if depth >= from_tile.size.y or depth >= to_tile.size.y:
			continue
		var from_y: int = from_tile.position.y + from_tile.size.y - 1 - depth
		var to_y: int = to_tile.position.y + depth
		for sample_index in range(sample_count):
			var t := _sample_t(sample_index, sample_count)
			var from_x := _lerp_pixel(from_tile.position.x, from_tile.size.x, t)
			var to_x := _lerp_pixel(to_tile.position.x, to_tile.size.x, t)
			_record_all_channels(
				images,
				stats,
				global_top,
				kind,
				depth,
				from_step,
				to_step,
				Vector2i(from_x, from_y),
				Vector2i(to_x, to_y),
				sample_index
			)


func _sample_atlas_column_edges(
		images: Dictionary,
		stats: Dictionary,
		global_top: Array,
		occupied_steps: int,
		uv2_sides: int,
		content_rect: Rect2i
) -> void:
	for column in range(maxi(uv2_sides - 1, 0)):
		for row in range(uv2_sides):
			var left_step := column * uv2_sides + row
			var right_step := (column + 1) * uv2_sides + row
			if left_step >= occupied_steps or right_step >= occupied_steps:
				continue
			var left_tile := _tile_rect(left_step, uv2_sides, content_rect)
			var right_tile := _tile_rect(right_step, uv2_sides, content_rect)
			var sample_count := mini(MAX_SAMPLES_PER_EDGE, maxi(left_tile.size.y, right_tile.size.y))
			for depth_variant in EDGE_DEPTHS:
				var depth := int(depth_variant)
				if depth >= left_tile.size.x or depth >= right_tile.size.x:
					continue
				var left_x: int = left_tile.position.x + left_tile.size.x - 1 - depth
				var right_x: int = right_tile.position.x + depth
				for sample_index in range(sample_count):
					var t := _sample_t(sample_index, sample_count)
					var left_y := _lerp_pixel(left_tile.position.y, left_tile.size.y, t)
					var right_y := _lerp_pixel(right_tile.position.y, right_tile.size.y, t)
					_record_all_channels(
						images,
						stats,
						global_top,
						"atlas_column_edge_nonlogical",
						depth,
						left_step,
						right_step,
						Vector2i(left_x, left_y),
						Vector2i(right_x, right_y),
						sample_index
					)


func _record_all_channels(
		images: Dictionary,
		stats: Dictionary,
		global_top: Array,
		kind: String,
		depth: int,
		from_step: int,
		to_step: int,
		from_pixel: Vector2i,
		to_pixel: Vector2i,
		sample_index: int
) -> void:
	for texture_name_variant in TEXTURE_PROPERTIES:
		var texture_name := String(texture_name_variant)
		var image: Image = images[texture_name]
		var from_color := image.get_pixelv(from_pixel)
		var to_color := image.get_pixelv(to_pixel)
		for channel_variant in CHANNELS:
			var channel := String(channel_variant)
			var from_value := _channel_value(from_color, channel)
			var to_value := _channel_value(to_color, channel)
			var delta := absf(from_value - to_value)
			var channel_key: String = texture_name + "." + channel
			var sample := {
				"channel": channel_key,
				"kind": kind,
				"depth": depth,
				"from_step": from_step,
				"to_step": to_step,
				"from_pixel": from_pixel,
				"to_pixel": to_pixel,
				"sample": sample_index,
				"from": _round5(from_value),
				"to": _round5(to_value),
				"delta": _round5(delta),
			}
			_record_stat(stats, channel_key, kind, depth, delta, sample)
			_track_top(global_top, sample)


func _record_stat(stats: Dictionary, channel_key: String, kind: String, depth: int, delta: float, sample: Dictionary) -> void:
	var stat_key := channel_key + "|" + kind + "|depth=" + str(depth)
	if not stats.has(stat_key):
		stats[stat_key] = {
			"channel": channel_key,
			"kind": kind,
			"depth": depth,
			"count": 0,
			"sum": 0.0,
			"max": 0.0,
			"max_sample": {},
		}
	var stat: Dictionary = stats[stat_key]
	stat["count"] = int(stat["count"]) + 1
	stat["sum"] = float(stat["sum"]) + delta
	if delta > float(stat["max"]):
		stat["max"] = delta
		stat["max_sample"] = sample


func _print_report(
		bake_path: String,
		bake: Resource,
		first_image: Image,
		content_rect: Rect2i,
		uv2_sides: int,
		occupied_steps: int,
		stats: Dictionary,
		global_logical_top: Array,
		atlas_nonlogical_top: Array
) -> void:
	var source_signature = bake.get("source_signature")
	var signature_version := -1
	if typeof(source_signature) == TYPE_DICTIONARY:
		signature_version = int((source_signature as Dictionary).get("version", -1))
	print("RIVER_FLOWMAP_SEAM_PROBE_BAKE bake=", bake_path)
	print("  texture_size=", first_image.get_size(), " content_rect=", content_rect, " uv2_sides=", uv2_sides, " occupied_steps=", occupied_steps, " signature_version=", signature_version)
	print("  priority_logical_edge_depth0=")
	for channel_key_variant in PRIORITY_CHANNELS:
		var channel_key := String(channel_key_variant)
		for kind_variant in ["logical_same_column", "logical_row_wrap"]:
			var kind := String(kind_variant)
			_print_stat_line(stats, channel_key, kind, 0)
	print("  global_logical_top=", _top_samples_for_kinds(global_logical_top, ["logical_same_column", "logical_row_wrap"]))
	print("  atlas_column_edge_nonlogical_top=", _top_samples_for_kinds(atlas_nonlogical_top, ["atlas_column_edge_nonlogical"]))


func _print_stat_line(stats: Dictionary, channel_key: String, kind: String, depth: int) -> void:
	var stat_key := channel_key + "|" + kind + "|depth=" + str(depth)
	if not stats.has(stat_key):
		print("    ", channel_key, " ", kind, " depth=", depth, " no_samples")
		return
	var stat: Dictionary = stats[stat_key]
	var count := maxi(1, int(stat["count"]))
	var average := float(stat["sum"]) / float(count)
	print(
		"    ",
		channel_key,
		" ",
		kind,
		" depth=",
		depth,
		" count=",
		int(stat["count"]),
		" avg_delta=",
		_round5(average),
		" max_delta=",
		_round5(float(stat["max"])),
		" max_sample=",
		stat["max_sample"]
	)


func _top_samples_for_kinds(samples: Array, kinds: Array) -> Array:
	var result := []
	for sample in samples:
		if kinds.has(String(sample.get("kind", ""))):
			result.append(sample)
		if result.size() >= TOP_SAMPLE_LIMIT:
			break
	return result


func _track_top(top: Array, sample: Dictionary) -> void:
	top.append(sample)
	top.sort_custom(Callable(self, "_sort_sample_desc"))
	if top.size() > TOP_SAMPLE_LIMIT:
		top.resize(TOP_SAMPLE_LIMIT)


func _sort_sample_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("delta", 0.0)) > float(b.get("delta", 0.0))


func _tile_rect(step_index: int, side: int, source_rect: Rect2i) -> Rect2i:
	var safe_side := maxi(1, side)
	var column := int(step_index / safe_side)
	var row := step_index % safe_side
	var x0 := source_rect.position.x + int(floor(float(column) * float(source_rect.size.x) / float(safe_side)))
	var x1 := source_rect.position.x + int(floor(float(column + 1) * float(source_rect.size.x) / float(safe_side)))
	var y0 := source_rect.position.y + int(floor(float(row) * float(source_rect.size.y) / float(safe_side)))
	var y1 := source_rect.position.y + int(floor(float(row + 1) * float(source_rect.size.y) / float(safe_side)))
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


func _sample_t(sample_index: int, sample_count: int) -> float:
	if sample_count <= 1:
		return 0.5
	return (float(sample_index) + 0.5) / float(sample_count)


func _lerp_pixel(position: int, size: int, t: float) -> int:
	return position + clampi(int(floor(t * float(size))), 0, maxi(size - 1, 0))


func _channel_value(color: Color, channel: String) -> float:
	match channel:
		"r":
			return color.r
		"g":
			return color.g
		"b":
			return color.b
		"a":
			return color.a
	return 0.0


func _round5(value: float) -> float:
	return snappedf(value, 0.00001)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
