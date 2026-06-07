extends SceneTree

const BOUNDARY_REVIEW_SCRIPT_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask_review.gd"
const FEEDBACK_REVIEW_SCRIPT_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_review.gd"
const PROBE_RESOLUTION := 256

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var review_script := load(BOUNDARY_REVIEW_SCRIPT_PATH) as Script
	_expect(review_script != null, "Could not load " + BOUNDARY_REVIEW_SCRIPT_PATH)
	if review_script == null or not review_script.can_instantiate():
		_expect(false, "Ripple boundary mask review script should be instantiable")
		_finish()
		return

	var review := review_script.new() as Control
	_expect(review != null, "Ripple boundary mask review script should instantiate as Control")
	if review == null:
		_finish()
		return

	review.set("resolution", PROBE_RESOLUTION)
	review.set("show_visual_views", false)
	root.add_child(review)
	await _settle_frames(6)
	review.call("render_boundary_mask_once")
	await _settle_frames(4)

	var snapshot: Dictionary = review.call("get_boundary_snapshot")
	var texture := review.call("get_boundary_texture") as Texture2D
	_expect(texture != null, "Boundary probe should expose a mesh-footprint mask texture")
	_expect(Vector2i(snapshot.get("boundary_texture_size", Vector2i.ZERO)) == Vector2i(PROBE_RESOLUTION, PROBE_RESOLUTION), "Boundary texture should initialize at the probe resolution")
	_expect(String(snapshot.get("mask_source", "")) == "target_river_mesh_footprint", "Boundary source should be the target river mesh footprint")
	_expect(not bool(snapshot.get("uses_uv2_atlas", true)), "Boundary source should not be a direct UV2 atlas bake texture")
	_expect(not bool(snapshot.get("visual_scene_markers", true)), "Console probe should run without the visible scene viewport")

	var image: Image = null
	if texture != null:
		# Validation-only readback. Runtime boundary sampling and river rendering must not use this pattern.
		image = texture.get_image()
	_expect(image != null and not image.is_empty(), "Boundary mask texture should be readable for validation")
	if image != null and not image.is_empty():
		_validate_boundary_snapshot(snapshot, image)

	await _run_boundary_feedback_check(texture, snapshot)
	await _run_visual_scene_smoke(review_script)

	review.queue_free()
	await _settle_frames(3)

	print("RIPPLE_BOUNDARY_MASK_PROBE_RESULTS=", _results)
	_finish()


func _validate_boundary_snapshot(snapshot: Dictionary, image: Image) -> void:
	var transform: Transform3D = snapshot.get("world_to_ripple_uv", Transform3D.IDENTITY)
	var samples: Array = snapshot.get("samples", [])
	_expect(samples.size() >= 5, "Boundary probe should expose fixed water and dry sample points")

	for sample in samples:
		var world_position: Vector3 = sample.get("world", Vector3.ZERO)
		var expected_uv: Vector2 = sample.get("expected_uv", Vector2(-1.0, -1.0))
		var mapped_position: Vector3 = transform * world_position
		var mapped_uv := Vector2(mapped_position.x, mapped_position.z)
		_expect(mapped_uv.distance_to(expected_uv) < 0.00001, "Boundary sample world_to_ripple_uv should reproduce expected UV for " + str(sample.get("name", "sample")))
		_expect(_uv_is_in_bounds(mapped_uv), "Boundary sample " + str(sample.get("name", "sample")) + " should map inside the ripple field")

		var mask_sample := _sample_mask_at_uv(image, mapped_uv, 2)
		if bool(sample.get("expected_inside", false)):
			_expect(float(mask_sample.get("max_value", 0.0)) > 0.50, "Water sample should be inside the boundary mask: " + str(sample.get("name", "sample")) + "; sample=" + str(mask_sample))
		else:
			_expect(float(mask_sample.get("max_value", 1.0)) < 0.15, "Dry sample should be outside the boundary mask: " + str(sample.get("name", "sample")) + "; sample=" + str(mask_sample))

	var coverage := _measure_mask_coverage(image)
	_expect(float(coverage.get("white_ratio", 0.0)) > 0.035, "Boundary mask should contain visible target-river coverage; coverage=" + str(coverage))
	_expect(float(coverage.get("white_ratio", 1.0)) < 0.22, "Boundary mask should not be a rectangular/full-field mask; coverage=" + str(coverage))
	_expect(int(coverage.get("white_edge_pixels", 1)) == 0, "Boundary mask should not touch the field border in this probe; coverage=" + str(coverage))
	_results["mask"] = {
		"coverage": coverage,
		"samples": samples,
	}


func _run_boundary_feedback_check(boundary_texture: Texture2D, boundary_snapshot: Dictionary) -> void:
	if boundary_texture == null:
		_expect(false, "Boundary feedback check needs the boundary texture")
		return

	var feedback_script := load(FEEDBACK_REVIEW_SCRIPT_PATH) as Script
	_expect(feedback_script != null, "Could not load " + FEEDBACK_REVIEW_SCRIPT_PATH)
	if feedback_script == null or not feedback_script.can_instantiate():
		_expect(false, "Ripple feedback review script should be instantiable for boundary check")
		return

	var feedback := feedback_script.new() as Control
	_expect(feedback != null, "Ripple feedback review script should instantiate as Control for boundary check")
	if feedback == null:
		return

	feedback.set("resolution", PROBE_RESOLUTION)
	feedback.set("auto_step", false)
	feedback.set("auto_emit", false)
	feedback.set("show_debug_views", false)
	root.add_child(feedback)
	await _settle_frames(5)
	feedback.call("set_boundary_texture", boundary_texture)
	await _settle_frames(2)

	var feedback_snapshot: Dictionary = feedback.call("get_feedback_snapshot")
	_expect(bool(feedback_snapshot.get("has_custom_boundary_texture", false)), "Feedback probe should accept the mesh-footprint boundary texture")
	_expect(Vector2i(feedback_snapshot.get("boundary_texture_size", Vector2i.ZERO)) == Vector2i(PROBE_RESOLUTION, PROBE_RESOLUTION), "Feedback boundary texture should match the probe resolution")

	var samples: Array = boundary_snapshot.get("samples", [])
	var source_uv := _find_sample_uv(samples, "lower-channel-source")
	var across_bank_uv := _find_sample_uv(samples, "upper-channel-across-bank")
	var dry_gap_uv := _find_sample_uv(samples, "dry-gap-between-branches")
	var dry_corner_uv := _find_sample_uv(samples, "outer-dry-corner")

	var dry_rejection := await _run_single_impulse_check(feedback, dry_corner_uv, 0.035, 0.90, 1)
	_expect(float(dry_rejection.get("max_delta", 1.0)) < 0.01, "Boundary mask should reject impulses in fully dry areas; metrics=" + str(dry_rejection))

	var source_baseline: Image = await _prime_boundary_neutral(feedback)
	feedback.call("queue_impulse", source_uv, 0.026, 0.90)
	feedback.call("render_queued_impulse_once")
	await _settle_frames(2)
	feedback.call("step_once")
	await _settle_frames(2)

	var first_image := _read_ripple_image(feedback)
	var source_first := _sample_abs_delta_at_uv(first_image, source_baseline, source_uv, 2)
	_expect(float(source_first.get("max_delta", 0.0)) > 0.20, "Water impulse should affect the lower channel inside the boundary; metrics=" + str(source_first))

	feedback.call("clear_impulse_once")
	await _settle_frames(1)
	for _step in range(40):
		feedback.call("step_once")
		await process_frame

	var final_image := _read_ripple_image(feedback)
	var dry_gap := _sample_abs_delta_at_uv(final_image, source_baseline, dry_gap_uv, 2)
	var across_bank := _sample_abs_delta_at_uv(final_image, source_baseline, across_bank_uv, 2)
	_expect(float(dry_gap.get("max_delta", 1.0)) < 0.03, "Boundary mask should keep the dry gap neutral; metrics=" + str(dry_gap))
	_expect(float(across_bank.get("max_delta", 1.0)) < 0.08, "Boundary mask should prevent short-path cross-bank propagation; metrics=" + str(across_bank))

	_results["feedback_boundary"] = {
		"dry_rejection": dry_rejection,
		"source_first": source_first,
		"dry_gap_after_steps": dry_gap,
		"across_bank_after_steps": across_bank,
	}

	feedback.queue_free()
	await _settle_frames(2)


func _run_single_impulse_check(feedback: Control, uv: Vector2, radius: float, intensity: float, steps: int) -> Dictionary:
	await _prime_boundary_neutral(feedback)
	for control_step in steps:
		feedback.call("step_once")
		await _settle_frames(2)
		if control_step == 0:
			feedback.call("clear_impulse_once")
			await _settle_frames(1)
	var control_image := _read_ripple_image(feedback)

	await _prime_boundary_neutral(feedback)
	feedback.call("queue_impulse", uv, radius, intensity)
	feedback.call("render_queued_impulse_once")
	await _settle_frames(2)
	for step in steps:
		feedback.call("step_once")
		await _settle_frames(2)
		if step == 0:
			feedback.call("clear_impulse_once")
			await _settle_frames(1)
	var image := _read_ripple_image(feedback)
	return _measure_abs_delta(image, control_image)


func _prime_boundary_neutral(feedback: Control) -> Image:
	feedback.call("reset_feedback")
	feedback.call("clear_impulse_once")
	await _settle_frames(3)
	for _step in range(4):
		feedback.call("step_once")
		await _settle_frames(2)
		feedback.call("clear_impulse_once")
		await _settle_frames(1)
	return _read_ripple_image(feedback)


func _run_visual_scene_smoke(review_script: Script) -> void:
	var review := review_script.new() as Control
	_expect(review != null, "Ripple boundary visual review script should instantiate as Control")
	if review == null:
		return
	review.set("resolution", 128)
	review.set("show_visual_views", true)
	root.add_child(review)
	await _settle_frames(5)
	var snapshot: Dictionary = review.call("get_boundary_snapshot")
	_expect(bool(snapshot.get("visual_scene_markers", false)), "Boundary visual review should create scene markers")
	_expect(Vector2i(snapshot.get("boundary_texture_size", Vector2i.ZERO)) == Vector2i(128, 128), "Boundary visual review should create a 128x128 mask view")
	review.queue_free()
	await _settle_frames(2)


func _sample_mask_at_uv(image: Image, uv: Vector2, radius_px: int) -> Dictionary:
	if image == null or image.is_empty():
		return {"max_value": 0.0, "average_value": 0.0}
	var width := image.get_width()
	var height := image.get_height()
	var center := Vector2i(
		clampi(int(round(uv.x * float(width - 1))), 0, width - 1),
		clampi(int(round(uv.y * float(height - 1))), 0, height - 1)
	)
	var max_value := 0.0
	var sum := 0.0
	var count := 0
	for y in range(max(center.y - radius_px, 0), min(center.y + radius_px + 1, height)):
		for x in range(max(center.x - radius_px, 0), min(center.x + radius_px + 1, width)):
			var value := image.get_pixel(x, y).r
			max_value = max(max_value, value)
			sum += value
			count += 1
	return {
		"uv": uv,
		"center": center,
		"max_value": max_value,
		"average_value": sum / max(float(count), 1.0),
	}


func _measure_mask_coverage(image: Image) -> Dictionary:
	var white_pixels := 0
	var white_edge_pixels := 0
	var width := image.get_width()
	var height := image.get_height()
	var edge_margin := 2
	for y in height:
		for x in width:
			if image.get_pixel(x, y).r <= 0.35:
				continue
			white_pixels += 1
			if x < edge_margin or y < edge_margin or x >= width - edge_margin or y >= height - edge_margin:
				white_edge_pixels += 1
	return {
		"white_pixels": white_pixels,
		"total_pixels": width * height,
		"white_ratio": float(white_pixels) / max(float(width * height), 1.0),
		"white_edge_pixels": white_edge_pixels,
	}


func _read_ripple_image(feedback: Control) -> Image:
	var texture := feedback.call("get_current_ripple_texture") as Texture2D
	_expect(texture != null, "Boundary feedback check should expose a current ripple texture")
	if texture == null:
		return null
	# Validation-only readback. Runtime ripple simulation and river rendering must not use this pattern.
	var image := texture.get_image()
	_expect(image != null and not image.is_empty(), "Boundary feedback check should read a validation image")
	return image


func _measure_abs_delta(image: Image, baseline: Image) -> Dictionary:
	if image == null or image.is_empty() or baseline == null or baseline.is_empty():
		return {"max_delta": 1.0}
	var width: int = min(image.get_width(), baseline.get_width())
	var height: int = min(image.get_height(), baseline.get_height())
	var max_delta := 0.0
	var active_pixels := 0
	for y in height:
		for x in width:
			var delta: float = abs(image.get_pixel(x, y).r - baseline.get_pixel(x, y).r) * 2.0
			if delta > 0.01:
				active_pixels += 1
			max_delta = max(max_delta, delta)
	return {
		"max_delta": max_delta,
		"active_pixels": active_pixels,
	}


func _sample_abs_delta_at_uv(image: Image, baseline: Image, uv: Vector2, radius_px: int) -> Dictionary:
	if image == null or image.is_empty() or baseline == null or baseline.is_empty():
		return {"max_delta": 1.0}
	var width: int = min(image.get_width(), baseline.get_width())
	var height: int = min(image.get_height(), baseline.get_height())
	var center := Vector2i(
		clampi(int(round(uv.x * float(width - 1))), 0, width - 1),
		clampi(int(round(uv.y * float(height - 1))), 0, height - 1)
	)
	var max_delta := 0.0
	for y in range(max(center.y - radius_px, 0), min(center.y + radius_px + 1, height)):
		for x in range(max(center.x - radius_px, 0), min(center.x + radius_px + 1, width)):
			var delta: float = abs(image.get_pixel(x, y).r - baseline.get_pixel(x, y).r) * 2.0
			max_delta = max(max_delta, delta)
	return {
		"uv": uv,
		"center": center,
		"max_delta": max_delta,
	}


func _find_sample_uv(samples: Array, sample_name: String) -> Vector2:
	for sample in samples:
		if String(sample.get("name", "")) == sample_name:
			return sample.get("expected_uv", Vector2(-1.0, -1.0))
	_expect(false, "Missing boundary sample " + sample_name)
	return Vector2(-1.0, -1.0)


func _uv_is_in_bounds(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_BOUNDARY_MASK_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
