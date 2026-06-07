extends SceneTree

const REVIEW_SCENE_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_river_shader_visible_normal_review.tscn"

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(REVIEW_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Visible normal review scene should load.")
	if packed_scene == null:
		_finish()
		return

	var review := packed_scene.instantiate()
	root.add_child(review)
	await _settle_frames(12)

	var status: Dictionary = review.call("get_review_status")
	var target_river := review.call("get_target_river") as Node
	_expect(bool(status.get("setup_complete", false)), "Visible normal review scene should finish setup. Status: " + str(status))
	_expect(target_river != null, "Visible normal review scene should find the demo river.")
	_expect(bool(status.get("review_camera_current", false)), "Visible normal review scene should activate the close review camera. Status: " + str(status))
	_expect(str(status.get("camera_mode", "")) == "close overhead", "Visible normal review scene should start in close overhead inspection camera mode. Status: " + str(status))
	_expect(int(status.get("ripple_center_count", 0)) >= 3, "Visible normal review scene should derive at least three review ripple centers from the demo river mesh. Status: " + str(status))
	_expect(abs(float(status.get("normal_strength", 0.0)) - 1.25) < 0.001, "Visible normal review scene should start at readable strength 1.25. Status: " + str(status))
	_expect(float(status.get("runtime_flow_speed", 0.0)) > 0.001, "Visible normal review scene should preserve demo river flow speed instead of freezing the base material. Status: " + str(status))
	_expect(int(status.get("ripple_precomputed_frame_count", 0)) >= 24, "Visible normal review scene should precompute animation frames. Status: " + str(status))
	if target_river != null:
		_expect(bool(target_river.call("has_runtime_ripple_material_state", review)), "Review scene should apply runtime ripple state when enabled.")

	var initial_texture_frame := int(status.get("ripple_texture_frame", 0))
	var initial_image_generation_count := int(status.get("ripple_image_generation_count", 0))
	await _settle_frames(18)
	var animated_status: Dictionary = review.call("get_review_status")
	_expect(int(animated_status.get("ripple_texture_frame", 0)) > initial_texture_frame, "Visible normal review texture should animate instead of remaining frozen. Status: " + str(animated_status))
	_expect(int(animated_status.get("ripple_image_generation_count", 0)) == initial_image_generation_count, "Visible normal review texture animation should reuse precomputed frames instead of generating images during playback. Status: " + str(animated_status))

	review.call("set_ripples_enabled", false)
	await _settle_frames(2)
	if target_river != null:
		_expect(not bool(target_river.call("has_runtime_ripple_material_state", review)), "Review scene should clear runtime ripple state when toggled off.")

	review.call("set_ripples_enabled", true)
	await _settle_frames(2)
	if target_river != null:
		_expect(bool(target_river.call("has_runtime_ripple_material_state", review)), "Review scene should reapply runtime ripple state when toggled on.")

	_results = review.call("get_review_status")
	review.queue_free()
	await _settle_frames(3)
	if target_river != null and is_instance_valid(target_river):
		_expect(not bool(target_river.call("has_runtime_ripple_material_state", review)), "Review scene should restore runtime ripple state when freed.")

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
		print("RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_RESULTS=", _results)
		print("RIPPLE_RIVER_SHADER_VISIBLE_NORMAL_REVIEW_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
