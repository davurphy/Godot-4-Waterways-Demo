extends SceneTree

const EXPECTED_SIGNATURE_VERSION := 20
const SHADER_PATH := "res://addons/waterways/shaders/river.gdshader"
const PRIOR_REACH_TILES := 0.075
const PULL_REVIEW_TILES := 0.035
const PULL_REVIEW_STRENGTH := 0.65
const EPSILON := 0.0001
const THRESHOLDS := [0.05, 0.25, 0.50]

const BAKE_PATHS := [
	"res://waterways_bakes/Demo/Water_River.river_bake.res",
	"res://waterways_bakes/Demo/Water_River_obstacle_test.river_bake.res",
]

var _errors: PackedStringArray = []
var _defaults := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_load_shader_defaults()
	for bake_path in BAKE_PATHS:
		var context := _load_context(bake_path)
		if not bool(context.get("ok", false)):
			_expect(false, String(context.get("error", "Could not load bake context")))
			continue
		_print_placement_report(context)
	if _errors.is_empty():
		print("PILLOW_PLACEMENT_DIAGNOSTIC_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _load_shader_defaults() -> void:
	var shader_code := _read_text(SHADER_PATH)
	for name in [
		"flow_base",
		"flow_steepness",
		"flow_distance",
		"flow_pressure",
		"flow_grade_energy",
		"flow_bend_bias",
		"flow_bank_drag",
		"flow_shallow_drag",
		"flow_inside_bend_drag",
		"flow_pressure_bank_gate",
		"flow_hard_boundary_pressure",
		"flow_max",
		"pillow_strength",
		"pillow_confidence_gate_start",
		"pillow_confidence_gate_full",
		"pillow_hard_gate_start",
		"pillow_hard_gate_full",
		"pillow_energy_gate_start",
		"pillow_energy_gate",
		"pillow_flow_gate_start",
		"pillow_flow_gate",
		"pillow_bank_suppression",
		"pillow_forward_reach_tiles",
		"pillow_contact_pull_tiles",
		"pillow_contact_pull_strength",
	]:
		_defaults[name] = _shader_uniform_float(shader_code, name)


func _load_context(bake_path: String) -> Dictionary:
	var bake := load(bake_path) as RiverBakeData
	if bake == null:
		return {"ok": false, "error": "Could not load " + bake_path}
	if not bake.has_required_textures():
		return {"ok": false, "error": "Bake is missing required textures " + bake_path}
	_expect(bake.source_signature_version == EXPECTED_SIGNATURE_VERSION, bake_path + " should be source signature " + str(EXPECTED_SIGNATURE_VERSION))
	var obstacle_image := bake.obstacle_features.get_image()
	var rect := bake.content_rect
	if rect.size == Vector2i.ZERO:
		rect = Rect2i(Vector2i.ZERO, obstacle_image.get_size())
	var uv2_sides := max(1, bake.uv2_sides)
	return {
		"ok": true,
		"bake_path": bake_path,
		"flow": bake.flow_foam_noise.get_image(),
		"dist": bake.dist_pressure.get_image(),
		"obstacle": obstacle_image,
		"terrain": bake.terrain_contact_features.get_image(),
		"bank": bake.bank_response_features.get_image(),
		"rect": rect,
		"uv2_sides": uv2_sides,
		"source_tile_pixels": Vector2(rect.size) / float(uv2_sides),
	}


func _print_placement_report(context: Dictionary) -> void:
	var rect: Rect2i = context.get("rect", Rect2i())
	var metrics := {}
	var current_reach := _default("pillow_forward_reach_tiles")
	var current_pull_tiles := _default("pillow_contact_pull_tiles")
	var current_pull_strength := _default("pillow_contact_pull_strength")
	var top_prior_reach_extra := []
	var top_raw_high_visual_low := []

	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var state := _sample_state(context, x, y, current_reach, current_pull_tiles, current_pull_strength)
			var prior_state := _sample_state(context, x, y, PRIOR_REACH_TILES, 0.0, 0.0)
			var pull_state := _sample_state(context, x, y, 0.0, PULL_REVIEW_TILES, PULL_REVIEW_STRENGTH)
			_add_metric(metrics, "raw_r", float(state.get("raw_r", 0.0)))
			_add_metric(metrics, "visual_no_reach", float(state.get("visual_no_reach", 0.0)))
			_add_metric(metrics, "visual_current_default", float(state.get("visual_reached", 0.0)))
			_add_metric(metrics, "visual_prior_reach_0_075", float(prior_state.get("visual_reached", 0.0)))
			_add_metric(metrics, "visual_pull_example", float(pull_state.get("visual_reached", 0.0)))
			_add_metric(metrics, "direct_terrain_b", float(state.get("direct_terrain_b", 0.0)))
			_add_metric(metrics, "bank_response_a", float(state.get("bank_response_a", 0.0)))
			_add_metric(metrics, "obstacle_confidence_a", float(state.get("confidence", 0.0)))
			_track_top_candidate(top_prior_reach_extra, {
				"x": x,
				"y": y,
				"score": maxf(float(prior_state.get("visual_reached", 0.0)) - float(state.get("visual_no_reach", 0.0)), 0.0),
				"raw_r": _round4(float(state.get("raw_r", 0.0))),
				"visual_no_reach": _round4(float(state.get("visual_no_reach", 0.0))),
				"prior_reach": _round4(float(prior_state.get("visual_reached", 0.0))),
			})
			_track_top_candidate(top_raw_high_visual_low, {
				"x": x,
				"y": y,
				"score": float(state.get("raw_r", 0.0)) * (1.0 - minf(float(state.get("visual_no_reach", 0.0)), 1.0)),
				"raw_r": _round4(float(state.get("raw_r", 0.0))),
				"visual_no_reach": _round4(float(state.get("visual_no_reach", 0.0))),
				"direct_terrain_b": _round4(float(state.get("direct_terrain_b", 0.0))),
				"bank_response_a": _round4(float(state.get("bank_response_a", 0.0))),
			})

	print("PILLOW_PLACEMENT_DIAGNOSTIC bake=", context.get("bake_path", ""))
	print("  current_defaults=", {
		"pillow_forward_reach_tiles": current_reach,
		"pillow_contact_pull_tiles": current_pull_tiles,
		"pillow_contact_pull_strength": current_pull_strength,
	})
	print("  global=", _finish_metrics(metrics))
	print("  top_prior_reach_extra=", top_prior_reach_extra)
	print("  top_raw_high_visual_low=", top_raw_high_visual_low)


func _sample_state(context: Dictionary, x: int, y: int, reach_tiles: float, pull_tiles: float, pull_strength: float) -> Dictionary:
	var flow_color := _sample_color(context.get("flow"), x, y)
	var dist_color := _sample_color(context.get("dist"), x, y)
	var obstacle := _sample_color(context.get("obstacle"), x, y)
	var terrain := _sample_color(context.get("terrain"), x, y)
	var bank := _sample_color(context.get("bank"), x, y)
	var flow_force := _estimate_flow_force(flow_color, dist_color, terrain, bank)
	var normalized_flow_force := clampf(flow_force / maxf(_default("flow_max"), EPSILON), 0.0, 1.0)
	var flow_direction := _decode_flow_direction(flow_color)
	var no_reach := _pillow_visual_mask(obstacle, terrain, bank, dist_color.b, normalized_flow_force)
	var reached := _pillow_visual_mask_with_reach(context, x, y, no_reach, dist_color.b, normalized_flow_force, flow_direction, reach_tiles, pull_tiles, pull_strength)
	return {
		"raw_r": obstacle.r,
		"visual_no_reach": no_reach,
		"visual_reached": reached,
		"direct_terrain_b": terrain.b,
		"bank_response_a": bank.a,
		"confidence": obstacle.a,
		"normalized_flow_force": normalized_flow_force,
	}


func _estimate_flow_force(flow_color: Color, dist_color: Color, terrain: Color, bank: Color) -> float:
	var distance_map := (1.0 - dist_color.r) * 2.0
	var pressure_map := dist_color.g * 2.0
	var grade_energy_map := dist_color.b
	var bend_bias_map := dist_color.a * 2.0 - 1.0
	var terrain_shallow := terrain.g
	var terrain_protrusion := terrain.b
	var bank_friction_drag := bank.r
	var outside_bend_wet_pressure := bank.g
	var inside_bend_deposition := bank.b
	var hard_boundary_context := clampf(maxf(bank.a, terrain_protrusion), 0.0, 1.0)
	var ordinary_bank := clampf(bank_friction_drag * (1.0 - hard_boundary_context), 0.0, 1.0)
	var pressure_gate_base := 1.0 - clampf((ordinary_bank + terrain_shallow * 0.35) * _default("flow_pressure_bank_gate"), 0.0, 0.95)
	var pressure_gate := clampf(lerpf(pressure_gate_base, clampf(_default("flow_hard_boundary_pressure"), 0.0, 1.0), hard_boundary_context), 0.0, 1.0)
	pressure_gate = maxf(pressure_gate, outside_bend_wet_pressure * 0.35)
	var grade_resistance := 1.0 - clampf(maxf(ordinary_bank, terrain_shallow) * 0.35, 0.0, 0.65)
	var context_drag := ordinary_bank * _default("flow_bank_drag") + terrain_shallow * _default("flow_shallow_drag") + inside_bend_deposition * _default("flow_inside_bend_drag") + hard_boundary_context * maxf(_default("flow_bank_drag"), _default("flow_shallow_drag")) * 0.20
	context_drag *= 1.0 - outside_bend_wet_pressure * 0.25
	context_drag = clampf(context_drag, 0.0, 0.85)
	var flow_force := clampf(
		_default("flow_base") +
		distance_map * _default("flow_distance") +
		pressure_map * _default("flow_pressure") * pressure_gate +
		grade_energy_map * _default("flow_grade_energy") * grade_resistance +
		bend_bias_map * _default("flow_bend_bias"),
		0.0,
		_default("flow_max")
	)
	return flow_force * (1.0 - context_drag)


func _pillow_visual_mask(obstacle: Color, terrain: Color, bank: Color, grade_energy_map: float, normalized_flow_force: float) -> float:
	var raw_pillow := obstacle.r
	var confidence_gate := _smooth_gate(_default("pillow_confidence_gate_start"), _default("pillow_confidence_gate_full"), obstacle.a)
	var hard_boundary_context := clampf(maxf(bank.a, terrain.b), 0.0, 1.0)
	var hard_gate := _smooth_gate(_default("pillow_hard_gate_start"), _default("pillow_hard_gate_full"), hard_boundary_context)
	var ordinary_bank := clampf(bank.r * (1.0 - hard_boundary_context), 0.0, 1.0)
	var bank_gate := 1.0 - clampf(ordinary_bank * _default("pillow_bank_suppression"), 0.0, 0.95)
	var energy_gate := _smooth_gate(_default("pillow_energy_gate_start"), _default("pillow_energy_gate"), grade_energy_map)
	var flow_gate := _smooth_gate(_default("pillow_flow_gate_start"), _default("pillow_flow_gate"), normalized_flow_force)
	return clampf(raw_pillow * confidence_gate * hard_gate * bank_gate * energy_gate * flow_gate * _default("pillow_strength"), 0.0, 1.0)


func _pillow_visual_mask_with_reach(context: Dictionary, x: int, y: int, base_mask: float, local_grade_energy: float, normalized_flow_force: float, flow_direction: Vector2, reach_tiles: float, pull_tiles: float, pull_strength: float) -> float:
	var source_tile_pixels: Vector2 = context.get("source_tile_pixels", Vector2.ONE)
	var downstream_direction := flow_direction.normalized() if flow_direction.length_squared() > EPSILON else Vector2(0.0, 1.0)
	var mask := base_mask
	if reach_tiles > EPSILON:
		var downstream_offset := downstream_direction * source_tile_pixels * reach_tiles
		var forward_mask := maxf(
			_pillow_visual_mask_at(context, x, y, downstream_offset * 0.5, local_grade_energy, normalized_flow_force) * 0.85,
			_pillow_visual_mask_at(context, x, y, downstream_offset, local_grade_energy, normalized_flow_force) * 0.65
		)
		forward_mask = maxf(forward_mask, _pillow_visual_mask_at(context, x, y, downstream_offset * 1.5, local_grade_energy, normalized_flow_force) * 0.45)
		mask = maxf(mask, forward_mask)
	if pull_strength > EPSILON and pull_tiles > EPSILON:
		var contact_offset := downstream_direction * source_tile_pixels * pull_tiles
		var contact_pulled_mask := maxf(
			_pillow_visual_mask_at(context, x, y, -contact_offset, local_grade_energy, normalized_flow_force),
			_pillow_visual_mask_at(context, x, y, -contact_offset * 0.5, local_grade_energy, normalized_flow_force) * 0.75
		)
		contact_pulled_mask = maxf(contact_pulled_mask, _pillow_visual_mask_at(context, x, y, -contact_offset * 1.5, local_grade_energy, normalized_flow_force) * 0.50)
		mask = lerpf(mask, contact_pulled_mask, clampf(pull_strength, 0.0, 1.0))
	return clampf(mask, 0.0, 1.0)


func _pillow_visual_mask_at(context: Dictionary, x: int, y: int, offset: Vector2, local_grade_energy: float, normalized_flow_force: float) -> float:
	var rect: Rect2i = context.get("rect", Rect2i())
	var sample_x := clampi(int(round(float(x) + offset.x)), rect.position.x, rect.position.x + rect.size.x - 1)
	var sample_y := clampi(int(round(float(y) + offset.y)), rect.position.y, rect.position.y + rect.size.y - 1)
	var grade_energy_map := maxf(local_grade_energy, _sample_color(context.get("dist"), sample_x, sample_y).b)
	return _pillow_visual_mask(
		_sample_color(context.get("obstacle"), sample_x, sample_y),
		_sample_color(context.get("terrain"), sample_x, sample_y),
		_sample_color(context.get("bank"), sample_x, sample_y),
		grade_energy_map,
		normalized_flow_force
	)


func _decode_flow_direction(flow_color: Color) -> Vector2:
	var flow := Vector2(flow_color.r, flow_color.g) * 2.0 - Vector2.ONE
	if flow.length_squared() <= EPSILON:
		return Vector2(0.0, 1.0)
	return flow.normalized()


func _sample_color(image: Image, x: int, y: int) -> Color:
	if image == null:
		return Color.BLACK
	var size := image.get_size()
	return image.get_pixel(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1))


func _add_metric(metrics: Dictionary, name: String, value: float) -> void:
	if not metrics.has(name):
		metrics[name] = {
			"min": INF,
			"max": -INF,
			"sum": 0.0,
			"count": 0,
			"nonzero": 0,
			"above": {},
		}
	var metric: Dictionary = metrics[name]
	metric["min"] = minf(float(metric.get("min", INF)), value)
	metric["max"] = maxf(float(metric.get("max", -INF)), value)
	metric["sum"] = float(metric.get("sum", 0.0)) + value
	metric["count"] = int(metric.get("count", 0)) + 1
	if value > 0.001:
		metric["nonzero"] = int(metric.get("nonzero", 0)) + 1
	var above: Dictionary = metric.get("above", {})
	for threshold in THRESHOLDS:
		var key := str(threshold)
		if not above.has(key):
			above[key] = 0
		if value > threshold:
			above[key] = int(above[key]) + 1
	metric["above"] = above
	metrics[name] = metric


func _finish_metrics(metrics: Dictionary) -> Dictionary:
	var result := {}
	for name in metrics.keys():
		var metric: Dictionary = metrics[name]
		var count := int(metric.get("count", 0))
		var summary := {
			"min": _round4(float(metric.get("min", 0.0))),
			"max": _round4(float(metric.get("max", 0.0))),
			"avg": _round4(float(metric.get("sum", 0.0)) / maxf(float(count), 1.0)),
			"nonzero_pct": _pct(int(metric.get("nonzero", 0)), count),
		}
		var above: Dictionary = metric.get("above", {})
		for threshold in THRESHOLDS:
			var key := str(threshold)
			summary["above_" + key + "_pct"] = _pct(int(above.get(key, 0)), count)
		result[name] = summary
	return result


func _track_top_candidate(candidates: Array, candidate: Dictionary) -> void:
	if float(candidate.get("score", 0.0)) <= 0.01:
		return
	candidate["score"] = _round4(float(candidate.get("score", 0.0)))
	candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	if candidates.size() > 8:
		candidates.pop_back()


func _smooth_gate(gate_start: float, gate_full: float, value: float) -> float:
	var start := minf(clampf(gate_start, 0.0, 1.0), 1.0 - EPSILON)
	var full := minf(1.0, maxf(start + EPSILON, clampf(gate_full, 0.0, 1.0)))
	return smoothstep(start, full, value)


func _default(name: String) -> float:
	return float(_defaults.get(name, 0.0))


func _shader_uniform_float(source_code: String, name: String) -> float:
	var regex := RegEx.new()
	regex.compile("uniform float " + name + "(?:\\s*:\\s*[^=;]+)?\\s*=\\s*([-+]?[0-9]+(?:\\.[0-9]+)?);")
	var result := regex.search(source_code)
	_expect(result != null, "Shader uniform " + name + " should exist")
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
