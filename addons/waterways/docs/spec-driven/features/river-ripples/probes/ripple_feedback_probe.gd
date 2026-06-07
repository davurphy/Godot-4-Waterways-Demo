extends SceneTree

const REVIEW_SCRIPT_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_feedback_review.gd"

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var review_script := load(REVIEW_SCRIPT_PATH) as Script
	_expect(review_script != null, "Could not load " + REVIEW_SCRIPT_PATH)
	if review_script == null or not review_script.can_instantiate():
		_expect(false, "Ripple feedback review script should be instantiable")
		_finish()
		return

	var review := review_script.new() as Control
	_expect(review != null, "Ripple feedback review script should instantiate as Control")
	if review == null:
		_finish()
		return

	review.set("resolution", 128)
	review.set("auto_step", false)
	review.set("auto_emit", false)
	review.set("show_debug_views", false)
	root.add_child(review)

	await _settle_frames(4)
	_expect(review.has_method("get_feedback_snapshot"), "Review probe should expose feedback snapshot")
	var initial_snapshot: Dictionary = review.call("get_feedback_snapshot")
	_expect(Vector2i(initial_snapshot.get("read_texture_size", Vector2i.ZERO)) == Vector2i(128, 128), "Read texture should initialize at 128x128")
	_expect(bool(initial_snapshot.get("has_distinct_viewports", false)), "Ping-pong simulation should own two distinct viewports")
	_expect(bool(initial_snapshot.get("has_distinct_textures", false)), "Ping-pong simulation should expose two distinct textures")

	review.call("queue_impulse", Vector2(0.5, 0.5), 0.08, 0.9)
	review.call("render_queued_impulse_once")
	await _settle_frames(2)
	review.call("step_once")
	await _settle_frames(2)
	review.call("clear_impulse_once")
	await _settle_frames(1)
	for _index in range(24):
		review.call("step_once")
		await process_frame

	var final_snapshot: Dictionary = review.call("get_feedback_snapshot")
	_expect(bool(final_snapshot.get("has_distinct_viewports", false)), "Final ping-pong state should still have distinct viewports")
	_expect(bool(final_snapshot.get("has_distinct_textures", false)), "Final ping-pong state should still have distinct textures")
	_expect(not bool(final_snapshot.get("same_target_hazard_last_step", true)), "Last step should not sample from the write target")
	_expect(not bool(final_snapshot.get("normal_runtime_readback", true)), "Probe model should not use normal-runtime readback")

	print("RIPPLE_FEEDBACK_PROBE_INITIAL=", initial_snapshot)
	print("RIPPLE_FEEDBACK_PROBE_FINAL=", final_snapshot)
	_finish()


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_FEEDBACK_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
