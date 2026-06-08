extends SceneTree

const REVIEW_SCRIPT_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_review.gd"
const RESOLUTIONS := [128, 256, 512]
const SAMPLE_STEPS := [1, 8, 20, 40, 64]
const CAPTURE_DIR := "res://.codex-research/ripple-feedback-analysis"
const SAVE_VALIDATION_IMAGES := true

var _errors := PackedStringArray()
var _results := []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var review_script := load(REVIEW_SCRIPT_PATH) as Script
	_expect(review_script != null, "Could not load " + REVIEW_SCRIPT_PATH)
	if review_script == null or not review_script.can_instantiate():
		_expect(false, "Ripple feedback review script should be instantiable")
		_finish()
		return

	for resolution in RESOLUTIONS:
		await _run_resolution(review_script, resolution)

	print("RIPPLE_FEEDBACK_ANALYSIS_RESULTS=", _results)
	_finish()


func _run_resolution(review_script: Script, resolution: int) -> void:
	var review := review_script.new() as Control
	_expect(review != null, "Ripple feedback review script should instantiate as Control")
	if review == null:
		return

	review.set("resolution", resolution)
	review.set("auto_step", false)
	review.set("auto_emit", false)
	review.set("show_debug_views", false)
	root.add_child(review)

	await _settle_frames(4)
	review.call("reset_feedback")
	review.call("clear_impulse_once")
	await _settle_frames(3)

	review.call("queue_impulse", Vector2(0.5, 0.5), 0.06, 0.9)
	review.call("render_queued_impulse_once")
	await _settle_frames(2)
	_save_validation_image(review.call("get_impulse_texture") as Texture2D, resolution, -1)

	var samples := []
	for step in range(1, SAMPLE_STEPS[-1] + 1):
		review.call("step_once")
		await _settle_frames(2)
		if step == 1:
			review.call("clear_impulse_once")
			await _settle_frames(1)
		if step in SAMPLE_STEPS:
			var texture := review.call("get_current_ripple_texture") as Texture2D
			var metrics := _sample_texture(texture, resolution, step)
			samples.append(metrics)
			_save_validation_image(texture, resolution, step)

	review.queue_free()
	await _settle_frames(2)

	var first: Dictionary = samples[0]
	var middle: Dictionary = samples[2]
	var final: Dictionary = samples[-1]
	var max_peak := 0.0
	for sample in samples:
		max_peak = max(max_peak, float(sample.get("max_abs_height", 0.0)))
	var spread_radius := max(float(middle.get("weighted_radius", 0.0)), float(final.get("weighted_radius", 0.0)))
	var spread_ring_energy := max(float(middle.get("ring_energy", 0.0)), float(final.get("ring_energy", 0.0)))

	_expect(float(first.get("max_abs_height", 0.0)) > 0.005, "Resolution " + str(resolution) + " should react to the first impulse")
	_expect(spread_radius > float(first.get("weighted_radius", 0.0)) + 0.01, "Resolution " + str(resolution) + " should spread outward after the first impulse")
	_expect(spread_ring_energy > float(first.get("ring_energy", 0.0)) + 0.0001, "Resolution " + str(resolution) + " should move visible energy into the ring band")
	_expect(float(final.get("max_abs_height", 0.0)) < max_peak * 0.75, "Resolution " + str(resolution) + " should decay from peak amplitude")
	_expect(float(final.get("saturated_ratio", 1.0)) < 0.01, "Resolution " + str(resolution) + " should avoid widespread height saturation")

	_results.append({
		"resolution": resolution,
		"first": first,
		"middle": middle,
		"final": final,
	})


func _sample_texture(texture: Texture2D, resolution: int, step: int) -> Dictionary:
	_expect(texture != null, "Resolution " + str(resolution) + " step " + str(step) + " should expose a current ripple texture")
	if texture == null:
		return {
			"step": step,
			"max_abs_height": 0.0,
			"weighted_radius": 0.0,
			"outer_energy": 0.0,
			"saturated_ratio": 1.0,
		}

	# Validation-only readback. Runtime ripple simulation and river rendering must not use this pattern.
	var image := texture.get_image()
	_expect(image != null and not image.is_empty(), "Resolution " + str(resolution) + " step " + str(step) + " should read a validation image")
	if image == null or image.is_empty():
		return {
			"step": step,
			"max_abs_height": 0.0,
			"weighted_radius": 0.0,
			"outer_energy": 0.0,
			"saturated_ratio": 1.0,
		}

	var stride := int(max(1.0, floor(float(resolution) / 96.0)))
	var center := Vector2(float(resolution - 1) * 0.5, float(resolution - 1) * 0.5)
	var encoded_values := []

	for y in range(0, resolution, stride):
		for x in range(0, resolution, stride):
			encoded_values.append(image.get_pixel(x, y).r)
	encoded_values.sort()
	var neutral_r := float(encoded_values[encoded_values.size() / 2])

	var energy := 0.0
	var radius_energy := 0.0
	var center_energy := 0.0
	var ring_energy := 0.0
	var max_abs_height := 0.0
	var saturated_count := 0
	var sample_count := 0
	var focused_sample_count := 0

	for y in range(0, resolution, stride):
		for x in range(0, resolution, stride):
			var color := image.get_pixel(x, y)
			var encoded_height := color.r
			var height := (encoded_height - neutral_r) * 2.0
			var abs_height := abs(height)
			var normalized_radius := Vector2(float(x), float(y)).distance_to(center) / float(resolution)
			if normalized_radius <= 0.30:
				energy += abs_height
				radius_energy += abs_height * normalized_radius
				focused_sample_count += 1
			if normalized_radius <= 0.045:
				center_energy += abs_height
			if normalized_radius >= 0.055 and normalized_radius <= 0.18:
				ring_energy += abs_height
			max_abs_height = max(max_abs_height, abs_height)
			if encoded_height <= 0.001 or encoded_height >= 0.999:
				saturated_count += 1
			sample_count += 1

	return {
		"step": step,
		"neutral_r": neutral_r,
		"max_abs_height": max_abs_height,
		"weighted_radius": radius_energy / max(energy, 0.000001),
		"center_energy": center_energy / max(float(focused_sample_count), 1.0),
		"ring_energy": ring_energy / max(float(focused_sample_count), 1.0),
		"total_energy": energy / max(float(focused_sample_count), 1.0),
		"saturated_ratio": float(saturated_count) / max(float(sample_count), 1.0),
	}


func _save_validation_image(texture: Texture2D, resolution: int, step: int) -> void:
	if not SAVE_VALIDATION_IMAGES or texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file_path := CAPTURE_DIR + ("/impulse_%d.png" % resolution if step < 0 else "/ripple_%d_step_%02d.png" % [resolution, step])
	image.save_png(file_path)


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_FEEDBACK_ANALYSIS_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
