extends SceneTree

const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn"
const MIN_WATER_TERRAIN_CLEARANCE := 0.08
const MIN_DISPLAY_TERRAIN_CLEARANCE := 0.75
const MIN_MARKER_TERRAIN_CLEARANCE := 1.2
const MIN_MOVING_WATER_TERRAIN_CLEARANCE := 1.0
const MIN_REVIEW_RIPPLE_STRENGTH := 2.0
const MIN_REVIEW_NORMAL_STRENGTH := 2.5
const MIN_FIXED_EMITTER_INTENSITY := 0.95
const MIN_MOVING_EMITTER_INTENSITY := 0.85
const MIN_MOVING_EMITTER_PULSE_RATE := 10.0
const MAX_MOVING_EMITTER_DISTANCE := 0.12

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Field/emitter demo review scene should load.")
	if packed_scene == null:
		_finish()
		return

	var review := packed_scene.instantiate()
	root.add_child(review)
	await _settle_frames(24)

	var status: Dictionary = review.call("get_review_status")
	var target_river := review.call("get_target_river") as Node
	var field := review.call("get_field") as Node
	_expect(bool(status.get("setup_complete", false)), "Review scene should finish setup. Status: " + str(status))
	_expect(target_river != null, "Review scene should find the demo river.")
	_expect(bool(status.get("terrain_found", false)), "Review scene should find the demo terrain for placement validation. Status: " + str(status))
	_expect(field != null, "Review scene should expose the WaterRippleField node.")
	_expect(bool(status.get("review_camera_current", false)), "Review scene should activate an inspection camera. Status: " + str(status))
	_expect(str(status.get("camera_mode", "")) == "close overhead", "Review scene should start in close overhead mode. Status: " + str(status))
	_expect(bool(status.get("target_has_field_runtime_state", false)), "Enabled field should own runtime ripple state on the demo river. Status: " + str(status))
	_expect(bool(status.get("current_material_is_runtime_duplicate", false)), "Enabled field should use a duplicated runtime material, not the baseline material. Status: " + str(status))
	_expect(float(status.get("runtime_flow_speed", 0.0)) > 0.001, "Demo base flow speed should remain active. Status: " + str(status))

	var field_snapshot: Dictionary = status.get("field_snapshot", {})
	_expect(bool(field_snapshot.get("runtime_initialized", false)), "Field runtime should initialize. Snapshot: " + str(field_snapshot))
	_expect(Vector2i(field_snapshot.get("read_texture_size", Vector2i.ZERO)) == Vector2i(256, 256), "Field should use a 256x256 read texture. Snapshot: " + str(field_snapshot))
	_expect(String(field_snapshot.get("boundary_source", "")) == "target_river_mesh_footprint", "Field should auto-generate the demo mesh-footprint boundary mask. Snapshot: " + str(field_snapshot))
	_expect(int(field_snapshot.get("target_count", 0)) == 1, "Field should target exactly one demo river. Snapshot: " + str(field_snapshot))
	_expect(int(field_snapshot.get("applied_target_count", 0)) == 1, "Field should apply to exactly one demo river. Snapshot: " + str(field_snapshot))
	_expect(float(field.get("ripple_strength")) >= MIN_REVIEW_RIPPLE_STRENGTH, "Review scene should use stronger field impulse response for visible authoring review.")
	_expect(float(field.get("normal_strength")) >= MIN_REVIEW_NORMAL_STRENGTH, "Review scene should use stronger normal response for visible authoring review.")
	_expect(is_equal_approx(float(field.get("refraction_strength")), 0.0), "Review scene should keep refraction tuning disabled.")
	_expect(is_equal_approx(float(field.get("displacement_strength")), 0.0), "Review scene should keep displacement tuning disabled.")

	_validate_emitter_reports(status.get("emitter_reports", []))
	_validate_moving_path_reports(status.get("moving_path_reports", []))

	if field != null:
		field.set_process(false)
	var emitted_count := int(review.call("fire_emitters_once"))
	var emission_reports := review.call("get_emitter_reports")
	_expect(emitted_count >= 3, "Manual review pulse should accept all configured emitters.")
	var rendered_count := int(field.call("render_queued_impulses_once")) if field != null else 0
	_expect(rendered_count >= 3, "Field should render all configured demo emitters in one impulse pass.")
	await _settle_frames(4)
	_validate_impulse_texture(field, emission_reports)
	if field != null:
		_expect(bool(field.call("step_once")), "Field should step after rendered demo impulses.")
		await _settle_frames(3)
		var stepped_snapshot: Dictionary = field.call("get_field_snapshot")
		_expect(int(stepped_snapshot.get("steps_completed", 0)) >= 1, "Field should report simulation steps after demo emitter impulses. Snapshot: " + str(stepped_snapshot))
		_expect(not bool(stepped_snapshot.get("same_target_hazard_last_step", true)), "Demo field should avoid same-target feedback hazards. Snapshot: " + str(stepped_snapshot))

	review.call("set_field_enabled", false)
	await _settle_frames(4)
	var disabled_status: Dictionary = review.call("get_review_status")
	_expect(not bool(disabled_status.get("target_has_runtime_state", true)), "Disabling field should clear runtime ripple state. Status: " + str(disabled_status))
	_expect(bool(disabled_status.get("baseline_material_restored", false)), "Disabling field should restore the baseline demo river material. Status: " + str(disabled_status))

	review.call("set_field_enabled", true)
	await _settle_frames(8)
	var reenabled_status: Dictionary = review.call("get_review_status")
	_expect(bool(reenabled_status.get("target_has_field_runtime_state", false)), "Re-enabled field should reapply owned runtime ripple state. Status: " + str(reenabled_status))

	review.queue_free()
	await _settle_frames(6)

	var reloaded := packed_scene.instantiate()
	root.add_child(reloaded)
	await _settle_frames(24)
	var reload_status: Dictionary = reloaded.call("get_review_status")
	_expect(bool(reload_status.get("setup_complete", false)), "Reloaded review scene should finish setup. Status: " + str(reload_status))
	_expect(bool(reload_status.get("target_has_field_runtime_state", false)), "Reloaded scene should create fresh field-owned runtime state. Status: " + str(reload_status))
	reloaded.call("set_field_enabled", false)
	await _settle_frames(4)
	var reload_disabled_status: Dictionary = reloaded.call("get_review_status")
	_expect(bool(reload_disabled_status.get("baseline_material_restored", false)), "Reloaded scene should restore baseline material after disabling. Status: " + str(reload_disabled_status))

	_results = {
		"initial": status,
		"disabled": disabled_status,
		"reenabled": reenabled_status,
		"reload_disabled": reload_disabled_status,
		"rendered_impulse_count": rendered_count,
	}

	reloaded.queue_free()
	await _settle_frames(3)
	_finish()


func _validate_emitter_reports(reports: Array) -> void:
	_expect(reports.size() >= 3, "Review scene should expose at least three configured emitters. Reports: " + str(reports))
	for report in reports:
		var name := String(report.get("name", ""))
		var uv_error := float(report.get("uv_error", 1.0))
		var mode := int(report.get("mode", -1))
		var allowed_error := 0.075 if mode == 3 else 0.06
		_expect(bool(report.get("enabled", false)), "Emitter should be enabled after review setup: " + str(report))
		_expect(bool(report.get("in_bounds", false)), "Emitter should map inside field bounds: " + str(report))
		_expect(uv_error >= 0.0 and uv_error < allowed_error, "Emitter " + name + " should stay near its authored water UV. Report: " + str(report))
		_expect(bool(report.get("terrain_sample_available", false)), "Emitter " + name + " should have terrain clearance data. Report: " + str(report))
		_expect(float(report.get("water_terrain_clearance", -INF)) >= MIN_WATER_TERRAIN_CLEARANCE, "Emitter " + name + " water anchor should be above terrain, not embedded. Report: " + str(report))
		if mode == 3:
			_expect(float(report.get("water_terrain_clearance", -INF)) >= MIN_MOVING_WATER_TERRAIN_CLEARANCE, "Moving emitter " + name + " should sit well inside exposed river water, not skim the bank. Report: " + str(report))
			_expect(float(report.get("intensity", 0.0)) >= MIN_MOVING_EMITTER_INTENSITY, "Moving emitter should be strong enough for visible authoring review. Report: " + str(report))
			_expect(float(report.get("pulse_rate", 0.0)) >= MIN_MOVING_EMITTER_PULSE_RATE, "Moving emitter should emit densely enough to read as a trail. Report: " + str(report))
			_expect(float(report.get("moving_emit_distance", INF)) <= MAX_MOVING_EMITTER_DISTANCE, "Moving emitter should not require too much travel between trail stamps. Report: " + str(report))
		else:
			_expect(float(report.get("intensity", 0.0)) >= MIN_FIXED_EMITTER_INTENSITY, "Fixed emitter should be strong enough for visible authoring review. Report: " + str(report))
		_expect(float(report.get("display_terrain_clearance", -INF)) >= MIN_DISPLAY_TERRAIN_CLEARANCE, "Emitter " + name + " authoring handle should be visibly above terrain. Report: " + str(report))
		_expect(float(report.get("marker_terrain_clearance", -INF)) >= MIN_MARKER_TERRAIN_CLEARANCE, "Emitter " + name + " marker should be visibly above terrain. Report: " + str(report))


func _validate_moving_path_reports(reports: Array) -> void:
	_expect(reports.size() >= 8, "Moving emitter path should have multiple terrain-aware samples. Reports: " + str(reports))
	for report in reports:
		_expect(bool(report.get("in_bounds", false)), "Moving emitter path sample should map inside field bounds: " + str(report))
		_expect(bool(report.get("terrain_sample_available", false)), "Moving emitter path sample should have terrain clearance data. Report: " + str(report))
		_expect(float(report.get("water_terrain_clearance", -INF)) >= MIN_WATER_TERRAIN_CLEARANCE, "Moving emitter path water anchor should stay above terrain. Report: " + str(report))
		_expect(float(report.get("water_terrain_clearance", -INF)) >= MIN_MOVING_WATER_TERRAIN_CLEARANCE, "Moving emitter path should stay well inside exposed river water, not skim the bank. Report: " + str(report))
		_expect(float(report.get("display_terrain_clearance", -INF)) >= MIN_DISPLAY_TERRAIN_CLEARANCE, "Moving emitter path handle should stay visibly above terrain. Report: " + str(report))


func _validate_impulse_texture(field: Node, reports: Array) -> void:
	_expect(field != null, "Field should be available for impulse texture validation.")
	if field == null:
		return
	var texture := field.call("get_impulse_texture") as Texture2D
	_expect(texture != null, "Field should expose an impulse texture after demo emitters render.")
	if texture == null:
		return
	var image := texture.get_image()
	# Validation-only readback. Normal field simulation and visible rendering do not use this path.
	_expect(image != null and not image.is_empty(), "Impulse texture should be readable in the validation probe.")
	if image == null or image.is_empty():
		return
	var nonzero_count := 0
	var red_sum := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var red := image.get_pixel(x, y).r
			red_sum += red
			if red > 0.01:
				nonzero_count += 1
	var mean_red := red_sum / float(max(image.get_width() * image.get_height(), 1))
	_expect(mean_red < 0.02, "Impulse texture background should remain black except localized emitter stamps. Mean red=" + str(mean_red) + " nonzero_count=" + str(nonzero_count))
	_expect(nonzero_count < 2048, "Impulse texture should not read as a full-field contact sheet. Nonzero_count=" + str(nonzero_count))
	for report in reports:
		var sample_uv := report.get("actual_uv", Vector2.INF) as Vector2
		if sample_uv == Vector2.INF:
			continue
		var pixel := Vector2i(
			clampi(roundi(sample_uv.x * float(image.get_width() - 1)), 0, image.get_width() - 1),
			clampi(roundi(sample_uv.y * float(image.get_height() - 1)), 0, image.get_height() - 1)
		)
		var color := image.get_pixelv(pixel)
		_expect(color.r > 0.05, "Impulse texture should contain a visible stamp at " + String(report.get("name", "")) + " expected UV. Pixel=" + str(pixel) + " color=" + str(color))


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_RESULTS=", _results)
		print("RIPPLE_FIELD_EMITTER_DEMO_REVIEW_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
