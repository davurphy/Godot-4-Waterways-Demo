extends SceneTree

const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

const DEMO_SCENE_PATH := "res://Demo.tscn"
const DEMO_RIVER_PATH := "WaterSystem/Water River"
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

var _errors := PackedStringArray()
var _active_abort_case := ""
var _active_river: Node = null
var _active_scene: Node = null
var _abort_triggered := false
var _delayed_pass_cancelled := false


class FakeFilterRenderer:
	extends Node
	var last_readback_error := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer_scene := _make_fake_renderer_scene()
	_expect(renderer_scene != null, "fake renderer scene should pack")
	if renderer_scene == null:
		_finish()
		return

	_check_result_application_strategy()
	await _check_river_duplicate_request_guard()
	await _check_baker_lifecycle_cases(renderer_scene)
	await _check_filter_renderer_setup_failure()
	await _check_invalid_filter_output(renderer_scene)
	await _check_awaited_renderer_cancellation(renderer_scene)
	_check_postprocess_strategy()
	await _check_pre_renderer_abort_keeps_existing_state()
	await _check_scene_close_before_renderer()
	await _check_terrain_helper_node_free()
	_finish()


func _check_result_application_strategy() -> void:
	var manager_source := _read_source("res://addons/waterways/river_manager.gd")
	var body := _function_body(manager_source, "func _apply_flowmap_bake_result")
	_expect(not body.is_empty(), "RiverManager result application method should exist")
	_expect(body.find("await ") == -1, "RiverManager result application should remain synchronous")
	_expect(body.find("_clear_flowmap_bake_request()") < body.find("emit_signal(\"progress_notified\", 100.0, \"finished\")"), "result application should clear bake flag before completion progress")


func _check_river_duplicate_request_guard() -> void:
	var river := RiverManager.new()
	river.name = "R6AbortMatrixDuplicateRiver"
	root.add_child(river)
	await _settle_frames(2)
	var first := bool(river.call("_begin_flowmap_bake_request"))
	var duplicate := bool(river.call("_begin_flowmap_bake_request"))
	_expect(first, "first RiverManager bake request should be accepted")
	_expect(not duplicate, "duplicate RiverManager bake request should be rejected")
	_expect(bool(river.call("is_bake_in_progress")), "duplicate request should leave original bake flag set")
	river.call("_clear_flowmap_bake_request")
	var after_clear := bool(river.call("_begin_flowmap_bake_request"))
	_expect(after_clear, "RiverManager should accept a bake after duplicate guard is cleared")
	river.call("_clear_flowmap_bake_request")
	river.queue_free()
	await _settle_frames(2)


func _check_baker_lifecycle_cases(renderer_scene: PackedScene) -> void:
	var parent := Node.new()
	parent.name = "R6AbortMatrixBakerParent"
	root.add_child(parent)
	await _check_baker_success_cleanup(parent, renderer_scene)
	await _check_baker_duplicate_start(parent, renderer_scene)
	await _check_baker_repeated_abort(parent, renderer_scene)
	parent.queue_free()
	await _settle_frames(2)


func _check_baker_success_cleanup(parent: Node, renderer_scene: PackedScene) -> void:
	var baker = RiverFlowmapBaker.new()
	var setup: Dictionary = await baker.bake(_make_renderer_config(parent, renderer_scene), Callable(), Callable())
	_expect(bool(setup.get("ok", false)), "baker setup should succeed before success cleanup")
	var renderer := setup.get("renderer") as Node
	_expect(baker.is_running(), "baker should be running after setup")
	baker.cleanup()
	_expect(not baker.is_running(), "baker cleanup should clear running")
	await _settle_frames(2)
	_expect(renderer == null or not is_instance_valid(renderer), "baker success cleanup should free renderer")


func _check_baker_duplicate_start(parent: Node, renderer_scene: PackedScene) -> void:
	var baker = RiverFlowmapBaker.new()
	var first: Dictionary = await baker.bake(_make_renderer_config(parent, renderer_scene), Callable(), Callable())
	_expect(bool(first.get("ok", false)), "first baker setup should succeed")
	var duplicate: Dictionary = await baker.bake(_make_renderer_config(parent, renderer_scene), Callable(), Callable())
	_expect(not bool(duplicate.get("ok", true)), "duplicate baker setup should fail")
	_expect(String(duplicate.get("reason", "")) == "already_running", "duplicate baker setup should report already_running")
	_expect(baker.is_running(), "duplicate baker setup should leave original run active")
	baker.cleanup()
	await _settle_frames(2)


func _check_baker_repeated_abort(parent: Node, renderer_scene: PackedScene) -> void:
	var baker = RiverFlowmapBaker.new()
	var setup: Dictionary = await baker.bake(_make_renderer_config(parent, renderer_scene), Callable(), Callable())
	_expect(bool(setup.get("ok", false)), "baker setup should succeed before repeated abort")
	var renderer := setup.get("renderer") as Node
	baker.abort()
	baker.abort()
	_expect(not baker.is_running(), "repeated baker abort should clear running")
	await _settle_frames(2)
	_expect(renderer == null or not is_instance_valid(renderer), "repeated baker abort should free renderer")


func _check_filter_renderer_setup_failure() -> void:
	var parent := Node.new()
	parent.name = "R6AbortMatrixRendererSetupParent"
	root.add_child(parent)
	var baker = RiverFlowmapBaker.new()
	var result: Dictionary = await baker.bake({"renderer_parent": parent}, Callable(), Callable())
	_expect(not bool(result.get("ok", true)), "missing renderer scene should abort")
	_expect(String(result.get("reason", "")) == "renderer_scene_missing", "missing renderer scene should report renderer_scene_missing")
	_expect(not baker.is_running(), "renderer setup failure should clear running")
	_expect(_count_filter_renderers(parent) == 0, "renderer setup failure should not leave filter renderers")
	parent.queue_free()
	await _settle_frames(2)


func _check_invalid_filter_output(renderer_scene: PackedScene) -> void:
	var parent := Node.new()
	parent.name = "R6AbortMatrixInvalidFilterParent"
	root.add_child(parent)
	var baker = RiverFlowmapBaker.new()
	var setup: Dictionary = await baker.bake(_make_renderer_config(parent, renderer_scene), Callable(), Callable())
	_expect(bool(setup.get("ok", false)), "invalid-filter setup should succeed")
	var renderer := setup.get("renderer") as Node
	if renderer != null and is_instance_valid(renderer):
		renderer.last_readback_error = "abort matrix forced unreadable viewport"
	var result: Dictionary = await baker._run_pass("combined flow/foam/noise map", Callable(self, "_return_null_texture"))
	_expect(not bool(result.get("ok", true)), "forced invalid filter output should abort")
	_expect(String(result.get("reason", "")) == "filter_pass_failed", "invalid filter output should report filter_pass_failed")
	_expect(String(result.get("stage", "")) == "filter_pass", "invalid filter output should report filter_pass stage")
	_expect(String(result.get("label", "")) == "combined flow/foam/noise map", "invalid filter output should keep label")
	_expect(not baker.is_running(), "invalid filter output should clear running")
	await _settle_frames(2)
	_expect(renderer == null or not is_instance_valid(renderer), "invalid filter output should free renderer")
	_expect(_count_filter_renderers(parent) == 0, "invalid filter output should not leave filter renderers")
	parent.queue_free()
	await _settle_frames(2)


func _check_awaited_renderer_cancellation(renderer_scene: PackedScene) -> void:
	var parent := Node.new()
	parent.name = "R6AbortMatrixAwaitedRendererParent"
	root.add_child(parent)
	var baker = RiverFlowmapBaker.new()
	_delayed_pass_cancelled = false
	var setup: Dictionary = await baker.bake(
		_make_renderer_config(parent, renderer_scene),
		Callable(),
		Callable(self, "_is_delayed_pass_cancelled")
	)
	_expect(bool(setup.get("ok", false)), "awaited renderer setup should succeed")
	var renderer := setup.get("renderer") as Node
	var result: Dictionary = await baker._run_pass("flow pressure jacobi pass", Callable(self, "_return_texture_after_delayed_cancellation"))
	_expect(not bool(result.get("ok", true)), "awaited renderer cancellation should abort")
	_expect(String(result.get("reason", "")) == "cancelled", "awaited renderer cancellation should report cancelled")
	_expect(not baker.is_running(), "awaited renderer cancellation should clear running")
	await _settle_frames(2)
	_expect(renderer == null or not is_instance_valid(renderer), "awaited renderer cancellation should free renderer")
	_expect(_count_filter_renderers(parent) == 0, "awaited renderer cancellation should not leave filter renderers")
	parent.queue_free()
	await _settle_frames(2)


func _check_postprocess_strategy() -> void:
	var baker_source := _read_source("res://addons/waterways/river_flowmap_baker.gd")
	var sequence_body := _function_body(baker_source, "func run_filter_pass_sequence")
	_expect(sequence_body.find("cleanup()\n\treturn {") != -1, "filter pass sequence should clean renderer before image postprocess handoff")
	var body := _function_body(baker_source, "func process_filter_pass_images")
	_expect(body.find("await ") == -1, "image postprocess should remain synchronous")


func _check_pre_renderer_abort_keeps_existing_state() -> void:
	var loaded := await _load_demo_scene()
	var scene := loaded.get("scene") as Node
	var river := loaded.get("river") as Node
	if river == null:
		return
	river.set("baking_resolution", 0)
	river.call("set_bake_generation_behavior", "curve_only")
	var before := _snapshot_generated_state(river)
	_active_abort_case = "pre_renderer_abort"
	_active_river = river
	_active_scene = scene
	_abort_triggered = false
	river.progress_notified.connect(Callable(self, "_on_abort_progress"))
	river.call("bake_texture")
	await _wait_until_not_baking(river, 180)
	await _settle_frames(2)
	_expect(_abort_triggered, "pre-renderer abort should trigger from progress")
	_expect(not bool(river.call("is_bake_in_progress")), "pre-renderer abort should clear bake flag")
	_expect(_count_filter_renderers(scene) == 0, "pre-renderer abort should not leave filter renderers")
	_expect(_snapshot_matches(river, before), "pre-renderer abort should keep generated bake state unchanged")
	_clear_abort_context()
	scene.queue_free()
	await _settle_frames(2)


func _check_scene_close_before_renderer() -> void:
	var loaded := await _load_demo_scene()
	var scene := loaded.get("scene") as Node
	var river := loaded.get("river") as Node
	if river == null:
		return
	river.set("baking_resolution", 0)
	river.call("set_bake_generation_behavior", "curve_only")
	var baker = river.call("_get_flowmap_baker")
	_active_abort_case = "scene_close_pre_renderer"
	_active_river = river
	_active_scene = scene
	_abort_triggered = false
	river.progress_notified.connect(Callable(self, "_on_abort_progress"))
	river.call("bake_texture")
	await _settle_frames(12)
	_expect(_abort_triggered, "scene close should trigger before renderer setup")
	_expect(not baker.is_running(), "scene close before renderer should leave baker stopped")
	_expect(scene == null or not is_instance_valid(scene), "scene close before renderer should free scene")
	_clear_abort_context()


func _check_terrain_helper_node_free() -> void:
	var loaded := await _load_demo_scene()
	var scene := loaded.get("scene") as Node
	var river := loaded.get("river") as Node
	if river == null:
		return
	river.set("baking_resolution", 0)
	var baker = river.call("_get_flowmap_baker")
	_active_abort_case = "terrain_helper_node_free"
	_active_river = river
	_active_scene = scene
	_abort_triggered = false
	river.progress_notified.connect(Callable(self, "_on_abort_progress"))
	river.call("bake_texture")
	await _settle_frames(180)
	_expect(_abort_triggered, "terrain-contact helper node-free case should trigger")
	_expect(not baker.is_running(), "terrain-contact node-free should leave baker stopped")
	_expect(river == null or not is_instance_valid(river), "terrain-contact node-free should free river")
	if scene != null and is_instance_valid(scene):
		_expect(_count_filter_renderers(scene) == 0, "terrain-contact node-free should not leave filter renderers")
		scene.queue_free()
	await _settle_frames(2)
	_clear_abort_context()


func _on_abort_progress(_progress: float, label: String) -> void:
	var label_text := String(label)
	match _active_abort_case:
		"pre_renderer_abort":
			if not _abort_triggered and label_text.begins_with("Preparing curve flow"):
				_abort_triggered = true
				_active_river.call("_abort_flowmap_bake_on_tree_exit")
		"scene_close_pre_renderer":
			if not _abort_triggered and label_text.begins_with("Preparing curve flow"):
				_abort_triggered = true
				_active_scene.queue_free()
		"terrain_helper_node_free":
			if not _abort_triggered and label_text.begins_with("Calculating Terrain Contact"):
				_abort_triggered = true
				_active_river.queue_free()


func _load_demo_scene() -> Dictionary:
	var packed := load(DEMO_SCENE_PATH) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + DEMO_SCENE_PATH)
		return {}
	var scene := packed.instantiate()
	scene.scene_file_path = DEMO_SCENE_PATH
	root.add_child(scene)
	current_scene = scene
	await _settle_frames(2)
	var river := scene.get_node_or_null(DEMO_RIVER_PATH)
	if river == null:
		_errors.append("Could not find river: " + DEMO_RIVER_PATH)
		scene.queue_free()
		await _settle_frames(2)
		return {}
	return {
		"scene": scene,
		"river": river
	}


func _snapshot_generated_state(river: Node) -> Dictionary:
	var state := {
		"valid_flowmap": bool(river.get("valid_flowmap")),
		"bake_data": river.get("bake_data")
	}
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		state[property_name] = river.get(property_name)
	return state


func _snapshot_matches(river: Node, before: Dictionary) -> bool:
	if bool(river.get("valid_flowmap")) != bool(before.get("valid_flowmap", false)):
		return false
	if river.get("bake_data") != before.get("bake_data"):
		return false
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		if river.get(property_name) != before.get(property_name):
			return false
	return true


func _wait_until_not_baking(river: Node, max_frames: int) -> void:
	var frame := 0
	while is_instance_valid(river) and bool(river.call("is_bake_in_progress")) and frame < max_frames:
		frame += 1
		await process_frame
	if is_instance_valid(river) and bool(river.call("is_bake_in_progress")):
		_errors.append("River bake did not abort within " + str(max_frames) + " frames")


func _clear_abort_context() -> void:
	_active_abort_case = ""
	_active_river = null
	_active_scene = null
	_abort_triggered = false


func _make_renderer_config(parent: Node, renderer_scene: PackedScene) -> Dictionary:
	return {
		"filter_renderer_scene": renderer_scene,
		"renderer_parent": parent
	}


func _return_null_texture():
	return null


func _return_texture_after_delayed_cancellation():
	await process_frame
	_delayed_pass_cancelled = true
	await process_frame
	return _make_texture(Color(1.0, 0.0, 0.0, 1.0))


func _is_delayed_pass_cancelled() -> bool:
	return _delayed_pass_cancelled


func _make_texture(color: Color) -> ImageTexture:
	return ImageTexture.create_from_image(_make_image(color))


func _make_image(color: Color) -> Image:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func _count_filter_renderers(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var count := 0
	if node is FakeFilterRenderer:
		count += 1
	for child in node.get_children():
		count += _count_filter_renderers(child)
	return count


func _make_fake_renderer_scene() -> PackedScene:
	var fake_renderer := FakeFilterRenderer.new()
	fake_renderer.name = "R6AbortMatrixFakeRenderer"
	var scene := PackedScene.new()
	var pack_error := scene.pack(fake_renderer)
	fake_renderer.free()
	if pack_error != OK:
		_errors.append("Could not pack fake renderer scene: " + error_string(pack_error))
		return null
	return scene


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _function_body(source: String, marker: String) -> String:
	var start := source.find(marker)
	if start == -1:
		return ""
	var next := source.find("\nfunc ", start + marker.length())
	if next == -1:
		return source.substr(start)
	return source.substr(start, next - start)


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("R6_R61H_ABORT_MATRIX_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
