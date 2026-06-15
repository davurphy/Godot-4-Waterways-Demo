extends SceneTree

const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_field_emitter_demo_review.tscn"
const DEBUG_NORMAL := 0
const DEBUG_RIPPLE_RAW_HEIGHT := 62
const DEBUG_RIPPLE_IMPULSE_CONTACT := 63
const DEBUG_RIPPLE_VISIBLE_INFLUENCE := 65

var _review: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(REVIEW_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Could not load " + REVIEW_SCENE_PATH)
		quit(1)
		return
	_review = packed.instantiate()
	root.add_child(_review)
	if not await _wait_for_setup():
		push_error("Review scene did not finish setup.")
		quit(1)
		return

	await _show_step("NORMAL VIEW - field enabled, baseline river plus visible ripple normals", DEBUG_NORMAL, 4.0, true)
	await _show_step("VISIBLE INFLUENCE - should show localized ripple influence rings near markers", DEBUG_RIPPLE_VISIBLE_INFLUENCE, 6.0, true)
	await _show_step("IMPULSE / CONTACT - should show localized impulse marks, not a blank/full screen", DEBUG_RIPPLE_IMPULSE_CONTACT, 4.0, true)
	await _show_step("RAW HEIGHT - should show a moving local height pattern, slower at low FPS", DEBUG_RIPPLE_RAW_HEIGHT, 6.0, true)

	print("R4_AUTO_REVIEW: disabling field; river should return to baseline.")
	_review.call("set_debug_view_mode", DEBUG_NORMAL)
	_review.call("set_field_enabled", false)
	await create_timer(4.0).timeout

	print("R4_AUTO_REVIEW: re-enabling field and firing emitters; state should return cleanly.")
	_review.call("set_field_enabled", true)
	_review.call("set_debug_view_mode", DEBUG_RIPPLE_VISIBLE_INFLUENCE)
	_review.call("fire_emitters_once")
	await create_timer(6.0).timeout

	print("R4_VISIBLE_AUTO_REVIEW_DONE")
	quit(0)


func _wait_for_setup() -> bool:
	for _index in range(240):
		await process_frame
		if _review != null and _review.has_method("get_review_status"):
			var status: Dictionary = _review.call("get_review_status")
			if bool(status.get("setup_complete", false)):
				return true
	return false


func _show_step(label: String, debug_view: int, seconds: float, fire_emitters: bool) -> void:
	print("R4_AUTO_REVIEW: " + label)
	_review.call("set_debug_view_mode", debug_view)
	if fire_emitters:
		_review.call("fire_emitters_once")
	await create_timer(seconds).timeout
