extends SceneTree

const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn"
const DEBUG_VIEW_NORMAL := 0
const DEBUG_VIEW_RIPPLE_RAW_HEIGHT := 62
const DEBUG_VIEW_RIPPLE_IMPULSE_CONTACT := 63
const DEBUG_VIEW_RIPPLE_BOUNDARY_MASK := 64
const DEBUG_VIEW_RIPPLE_VISIBLE_INFLUENCE := 65

var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(REVIEW_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load field/emitter demo review scene.")
		quit(1)
		return

	var review := packed_scene.instantiate()
	root.add_child(review)
	await _settle_frames(24)

	var field := review.call("get_field") as Node
	if field == null:
		push_error("Review scene did not expose a WaterRippleField.")
		quit(1)
		return

	field.set_process(false)
	for emitter in review.call("get_configured_emitters"):
		if emitter is Node:
			(emitter as Node).set_process(false)

	var initial_status: Dictionary = review.call("get_review_status")
	var emitted_count := int(review.call("fire_emitters_once"))
	var rendered_count := int(field.call("render_queued_impulses_once"))
	await _settle_frames(6)
	var impulse_report := _texture_report(field.call("get_impulse_texture") as Texture2D, initial_status.get("emitter_reports", []), false)

	var stepped := bool(field.call("step_once"))
	await _settle_frames(6)
	var simulation_report_after_one_step := _texture_report(field.call("get_current_ripple_texture") as Texture2D, initial_status.get("emitter_reports", []), true)

	for _index in range(24):
		field.call("clear_impulse_once")
		field.call("step_once")
		await _settle_frames(2)
	var simulation_report_after_decay := _texture_report(field.call("get_current_ripple_texture") as Texture2D, initial_status.get("emitter_reports", []), true)

	_results = {
		"initial_status": initial_status,
		"manual_emit_count": emitted_count,
		"rendered_impulse_count": rendered_count,
		"step_after_manual_impulses": stepped,
		"impulse_texture": impulse_report,
		"simulation_after_one_step": simulation_report_after_one_step,
		"simulation_after_decay": simulation_report_after_decay,
		"render_debug_views": {
			"boundary": await _render_view_report(review, DEBUG_VIEW_RIPPLE_BOUNDARY_MASK),
			"raw_height": await _render_view_report(review, DEBUG_VIEW_RIPPLE_RAW_HEIGHT),
			"impulse_contact": await _render_view_report(review, DEBUG_VIEW_RIPPLE_IMPULSE_CONTACT),
			"visible_influence": await _render_view_report(review, DEBUG_VIEW_RIPPLE_VISIBLE_INFLUENCE),
			"normal": await _render_view_report(review, DEBUG_VIEW_NORMAL),
		},
	}

	print("RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_RESULTS=", _results)
	print("RIPPLE_FIELD_EMITTER_DEMO_REVIEW_DIAGNOSTIC_OK")
	quit(0)


func _texture_report(texture: Texture2D, emitter_reports: Array, decode_signed: bool) -> Dictionary:
	if texture == null:
		return {"available": false}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"available": false, "size": texture.get_size()}

	var min_value := INF
	var max_value := -INF
	var sum := 0.0
	var changed_count := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			var raw_value := image.get_pixel(x, y).r
			var value := raw_value * 2.0 - 1.0 if decode_signed else raw_value
			min_value = min(min_value, value)
			max_value = max(max_value, value)
			sum += value
			if abs(value) > 0.01:
				changed_count += 1

	var samples := []
	for report in emitter_reports:
		var uv := report.get("actual_uv", Vector2.INF) as Vector2
		if uv == Vector2.INF:
			continue
		var pixel := Vector2i(
			clampi(roundi(uv.x * float(width - 1)), 0, width - 1),
			clampi(roundi(uv.y * float(height - 1)), 0, height - 1)
		)
		var raw_sample := image.get_pixelv(pixel).r
		samples.append({
			"name": String(report.get("name", "")),
			"uv": uv,
			"pixel": pixel,
			"raw": raw_sample,
			"value": raw_sample * 2.0 - 1.0 if decode_signed else raw_sample,
		})

	return {
		"available": true,
		"size": Vector2i(width, height),
		"min": min_value,
		"max": max_value,
		"mean": sum / float(max(width * height, 1)),
		"changed_count_abs_gt_0_01": changed_count,
		"emitter_samples": samples,
	}


func _render_view_report(review: Node, debug_view: int) -> Dictionary:
	review.call("set_debug_view_mode", debug_view)
	await _settle_frames(8)
	var texture := root.get_texture()
	if texture == null:
		return {"available": false}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"available": false, "size": texture.get_size()}
	return _image_report(image)


func _image_report(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var min_luma := INF
	var max_luma := -INF
	var sum := 0.0
	var nonblack_count := 0
	for y in range(height):
		for x in range(width):
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			min_luma = min(min_luma, luma)
			max_luma = max(max_luma, luma)
			sum += luma
			if color.r > 0.01 or color.g > 0.01 or color.b > 0.01:
				nonblack_count += 1
	return {
		"available": true,
		"size": Vector2i(width, height),
		"min_luma": min_luma,
		"max_luma": max_luma,
		"mean_luma": sum / float(max(width * height, 1)),
		"contrast": max_luma - min_luma,
		"nonblack_count": nonblack_count,
	}


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame
