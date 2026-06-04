extends SceneTree

const EXPECTED_SIGNATURE_VERSION := 20
const RAW_THRESHOLD := 0.05
const STRONG_GATE_THRESHOLD := 0.25
const MANAGER_PATH := "res://addons/waterways/river_manager.gd"

const BAKE_PATHS := [
	"res://waterways_bakes/Demo/Water_River.river_bake.res",
	"res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
]

var _errors: PackedStringArray = []
var _contact_search_tiles := 0.07
var _contact_gate_start := 0.08
var _contact_gate_full := 0.38


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_load_manager_constants()
	for bake_path in BAKE_PATHS:
		var context := _load_context(bake_path)
		if not bool(context.get("ok", false)):
			_expect(false, String(context.get("error", "Could not load bake context")))
			continue
		_print_anchor_report(context)
	if _errors.is_empty():
		print("PILLOW_ANCHOR_SOURCE_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _load_manager_constants() -> void:
	var manager_code := _read_text(MANAGER_PATH)
	var signature_version := _gd_const_int(manager_code, "RIVER_BAKE_SOURCE_SIGNATURE_VERSION")
	_expect(signature_version == EXPECTED_SIGNATURE_VERSION, "river bake source signature should be " + str(EXPECTED_SIGNATURE_VERSION))
	_contact_search_tiles = _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES")
	_contact_gate_start = _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START")
	_contact_gate_full = _gd_const_float(manager_code, "RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL")


func _load_context(bake_path: String) -> Dictionary:
	var bake := load(bake_path) as RiverBakeData
	if bake == null:
		return {"ok": false, "error": "Could not load " + bake_path}
	if not bake.has_required_textures():
		return {"ok": false, "error": "Bake is missing required textures " + bake_path}
	_expect(bake.source_signature_version == EXPECTED_SIGNATURE_VERSION, bake_path + " should be source signature " + str(EXPECTED_SIGNATURE_VERSION))
	_expect(String(bake.source_metadata.get("obstacle_features_pillow_anchor_source", "")) == "terrain_contact_features.b_direct_search", bake_path + " should record direct terrain pillow anchor metadata")
	_expect(String(bake.source_metadata.get("obstacle_features_pillow_bank_response_role", "")) == "weak_context_only_not_anchor", bake_path + " should record weak bank-response pillow role metadata")
	var flow_image := bake.flow_foam_noise.get_image()
	var obstacle_image := bake.obstacle_features.get_image()
	var terrain_image := bake.terrain_contact_features.get_image()
	var bank_image := bake.bank_response_features.get_image()
	var rect := bake.content_rect
	if rect.size == Vector2i.ZERO:
		rect = Rect2i(Vector2i.ZERO, obstacle_image.get_size())
	var uv2_sides := max(1, bake.uv2_sides)
	var texture_size := obstacle_image.get_size()
	return {
		"ok": true,
		"bake_path": bake_path,
		"flow": flow_image,
		"obstacle": obstacle_image,
		"terrain": terrain_image,
		"bank": bank_image,
		"rect": rect,
		"texture_size": texture_size,
		"uv2_sides": uv2_sides,
		"search_pixels": _contact_search_tiles / float(uv2_sides + 2) * float(texture_size.x),
	}


func _print_anchor_report(context: Dictionary) -> void:
	var rect: Rect2i = context.get("rect", Rect2i())
	var raw_pixels := 0
	var raw_with_strong_combined := 0
	var raw_with_strong_direct := 0
	var raw_with_strong_bank := 0
	var raw_bank_only_anchor := 0
	var raw_direct_weak_bank_strong := 0
	var raw_current_terrain_low_bank_high := 0
	var raw_current_bank_higher := 0
	var combined_sum := 0.0
	var direct_sum := 0.0
	var bank_sum := 0.0
	var current_terrain_sum := 0.0
	var current_bank_sum := 0.0
	var top_bank_only := []

	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var raw := _sample_color(context.get("obstacle"), x, y).r
			if raw <= RAW_THRESHOLD:
				continue
			var flow_direction := _flow_direction(context.get("flow"), x, y)
			var combined_gate := _contact_gate(context, Vector2(x, y), flow_direction, true, true)
			var direct_gate := _contact_gate(context, Vector2(x, y), flow_direction, true, false)
			var bank_gate := _contact_gate(context, Vector2(x, y), flow_direction, false, true)
			var terrain_b := _sample_color(context.get("terrain"), x, y).b
			var bank_a := _sample_color(context.get("bank"), x, y).a

			raw_pixels += 1
			combined_sum += combined_gate
			direct_sum += direct_gate
			bank_sum += bank_gate
			current_terrain_sum += terrain_b
			current_bank_sum += bank_a

			if combined_gate > STRONG_GATE_THRESHOLD:
				raw_with_strong_combined += 1
			if direct_gate > STRONG_GATE_THRESHOLD:
				raw_with_strong_direct += 1
			if bank_gate > STRONG_GATE_THRESHOLD:
				raw_with_strong_bank += 1
			if combined_gate > STRONG_GATE_THRESHOLD and direct_gate <= RAW_THRESHOLD and bank_gate > STRONG_GATE_THRESHOLD:
				raw_bank_only_anchor += 1
				_track_top_candidate(top_bank_only, {
					"x": x,
					"y": y,
					"raw": _round4(raw),
					"combined_gate": _round4(combined_gate),
					"direct_gate": _round4(direct_gate),
					"bank_gate": _round4(bank_gate),
					"terrain_b": _round4(terrain_b),
					"bank_a": _round4(bank_a),
				})
			if direct_gate <= RAW_THRESHOLD and bank_gate > STRONG_GATE_THRESHOLD:
				raw_direct_weak_bank_strong += 1
			if terrain_b <= RAW_THRESHOLD and bank_a > STRONG_GATE_THRESHOLD:
				raw_current_terrain_low_bank_high += 1
			if bank_a > terrain_b + 0.10:
				raw_current_bank_higher += 1

	var denominator := maxi(raw_pixels, 1)
	var report := {
		"raw_threshold": RAW_THRESHOLD,
		"raw_pixel_count": raw_pixels,
		"raw_pct_of_content": _pct(raw_pixels, rect.size.x * rect.size.y),
		"avg_combined_contact_gate": _round4(combined_sum / denominator),
		"avg_direct_terrain_gate": _round4(direct_sum / denominator),
		"avg_bank_response_gate": _round4(bank_sum / denominator),
		"avg_current_terrain_b": _round4(current_terrain_sum / denominator),
		"avg_current_bank_a": _round4(current_bank_sum / denominator),
		"strong_combined_gate_pct_of_raw": _pct(raw_with_strong_combined, denominator),
		"strong_direct_terrain_gate_pct_of_raw": _pct(raw_with_strong_direct, denominator),
		"strong_bank_response_gate_pct_of_raw": _pct(raw_with_strong_bank, denominator),
		"bank_only_anchor_pct_of_raw": _pct(raw_bank_only_anchor, denominator),
		"direct_weak_bank_strong_pct_of_raw": _pct(raw_direct_weak_bank_strong, denominator),
		"current_terrain_low_bank_high_pct_of_raw": _pct(raw_current_terrain_low_bank_high, denominator),
		"current_bank_a_gt_terrain_b_plus_0_10_pct_of_raw": _pct(raw_current_bank_higher, denominator),
		"search_pixels": _round4(float(context.get("search_pixels", 0.0))),
		"top_bank_only_candidates": top_bank_only,
	}
	print("PILLOW_ANCHOR_SOURCE_PROBE bake=", context.get("bake_path", ""))
	print("  ", report)


func _contact_gate(context: Dictionary, pixel: Vector2, flow_direction: Vector2, use_terrain: bool, use_bank: bool) -> float:
	var search_pixels := float(context.get("search_pixels", 0.0))
	var contact := _hard_boundary_sample(context, pixel, use_terrain, use_bank)
	contact = maxf(contact, _hard_boundary_sample(context, pixel + flow_direction * search_pixels * 0.50, use_terrain, use_bank))
	contact = maxf(contact, _hard_boundary_sample(context, pixel + flow_direction * search_pixels, use_terrain, use_bank))
	contact = maxf(contact, _hard_boundary_sample(context, pixel + flow_direction * search_pixels * 1.50, use_terrain, use_bank) * 0.65)
	return _smooth_gate(_contact_gate_start, _contact_gate_full, contact)


func _hard_boundary_sample(context: Dictionary, pixel: Vector2, use_terrain: bool, use_bank: bool) -> float:
	var x := int(round(pixel.x))
	var y := int(round(pixel.y))
	var terrain_b := _sample_color(context.get("terrain"), x, y).b if use_terrain else 0.0
	var bank_a := _sample_color(context.get("bank"), x, y).a if use_bank else 0.0
	return clampf(maxf(terrain_b, bank_a), 0.0, 1.0)


func _flow_direction(flow_image: Image, x: int, y: int) -> Vector2:
	var flow := _sample_color(flow_image, x, y)
	var vector := Vector2(flow.r, flow.g) * 2.0 - Vector2.ONE
	if vector.length_squared() <= 0.0001:
		return Vector2(0.0, 1.0)
	return vector.normalized()


func _sample_color(image: Image, x: int, y: int) -> Color:
	if image == null:
		return Color.BLACK
	var size := image.get_size()
	return image.get_pixel(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1))


func _smooth_gate(gate_start: float, gate_full: float, value: float) -> float:
	var start := minf(clampf(gate_start, 0.0, 1.0), 1.0 - 0.0001)
	var full := minf(1.0, maxf(start + 0.0001, clampf(gate_full, 0.0, 1.0)))
	return smoothstep(start, full, value)


func _track_top_candidate(candidates: Array, candidate: Dictionary) -> void:
	candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("raw", 0.0)) * float(a.get("bank_gate", 0.0)) * (1.0 - float(a.get("direct_gate", 0.0)))
		var score_b := float(b.get("raw", 0.0)) * float(b.get("bank_gate", 0.0)) * (1.0 - float(b.get("direct_gate", 0.0)))
		return score_a > score_b
	)
	if candidates.size() > 8:
		candidates.pop_back()


func _gd_const_int(source_code: String, name: String) -> int:
	return int(_regex_number(source_code, "const " + name + " := ([0-9]+)", "GDScript constant " + name))


func _gd_const_float(source_code: String, name: String) -> float:
	return _regex_number(source_code, "const " + name + " := ([-+]?[0-9]+(?:\\.[0-9]+)?)", "GDScript constant " + name)


func _regex_number(source_code: String, pattern: String, context: String) -> float:
	var regex := RegEx.new()
	regex.compile(pattern)
	var result := regex.search(source_code)
	_expect(result != null, context + " should exist")
	if result == null:
		return 0.0
	return float(result.get_string(1))


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null, "Could not open " + path)
	if file == null:
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _pct(value: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return _round4(float(value) * 100.0 / float(total))


func _round4(value: float) -> float:
	return roundf(value * 10000.0) / 10000.0
