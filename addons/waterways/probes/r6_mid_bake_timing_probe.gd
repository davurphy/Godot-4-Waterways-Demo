# River-refactor R6 source-timing/progress trap probe (window required).
#
# Starts a Demo river bake with neutral flow_speeds, waits until the first
# "Projecting flow ..." progress label, then mutates flow_speeds. In the old
# mixed-timing path, the flow-speed source decision has already happened, but
# final metadata/signature re-read the new flow_speeds.
#
# Run without --headless:
#   & $godotConsole --path $root --script res://addons/waterways/probes/r6_mid_bake_timing_probe.gd
#
# Optional args after `--`:
#   out=res://.codex-research/r6-baselines/pre-r6
#
# Success marker: R6_MID_BAKE_TIMING_OK
extends SceneTree

const DEFAULT_OUT_DIR := "res://.codex-research/r6-baselines/pre-r6"
const DEFAULT_SCENE_PATH := "res://Demo.tscn"
const DEFAULT_RIVER_PATH := "WaterSystem/Water River"
const DEFAULT_LABEL := "demo_flow_speeds_projecting_flow_trap"
const DEFAULT_BASELINE_HASH_FILE := "res://.codex-research/r6-baselines/pre-r6/demo__bake_hash.txt"
const TARGET_PROGRESS_PREFIX := "Projecting flow "
const MUTATED_POINT0_FLOW_SPEED := 1.5
const MUTATED_LAST_POINT_FLOW_SPEED := 0.75
const TEXTURE_PROPERTIES := [
	"flow_foam_noise",
	"dist_pressure",
	"obstacle_features",
	"terrain_contact_features",
	"bank_response_features",
	"water_occupancy",
]

var _errors := PackedStringArray()
var _written_files := PackedStringArray()
var _progress_events := []
var _frame_index := 0
var _mutation_done := false
var _mutation_frame := -1
var _mutation_label := ""
var _mutation_progress := 0.0
var _target_river: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var label := String(args.get("label", DEFAULT_LABEL))
	var scene_path := String(args.get("scene", DEFAULT_SCENE_PATH))
	var river_path := String(args.get("river", DEFAULT_RIVER_PATH))
	var baseline_hash_file := String(args.get("baseline_hash", DEFAULT_BASELINE_HASH_FILE))
	var out_abs := ProjectSettings.globalize_path(out_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(out_abs)
	if dir_error != OK:
		push_error("Could not create output directory " + out_abs + ": " + error_string(dir_error))
		quit(1)
		return

	var result := await _run_flow_speed_trap(scene_path, river_path, baseline_hash_file)
	if result.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return

	_write_timing_file(out_dir.path_join(label + "__mid_bake_timing.txt"), label, scene_path, river_path, result)
	if _errors.is_empty():
		for file_path in _written_files:
			print("R6_MID_BAKE_TIMING_FILE ", file_path)
		print("R6_MID_BAKE_TIMING_OK out=", out_dir, " files=", _written_files.size())
		quit(0)
		return

	for error in _errors:
		push_error(error)
	quit(1)


func _run_flow_speed_trap(scene_path: String, river_path: String, baseline_hash_file: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load scene: " + scene_path)
		return {}
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		_errors.append("Could not find river " + river_path + " in " + scene_path)
		scene.queue_free()
		await process_frame
		return {}
	_target_river = river
	_progress_events.clear()
	_frame_index = 0
	_mutation_done = false
	_mutation_frame = -1
	_mutation_label = ""
	_mutation_progress = 0.0

	river.connect("progress_notified", Callable(self, "_on_progress_notified"))
	_set_neutral_flow_speeds(river)
	var initial_signature: Dictionary = river.call("get_bake_source_signature")
	var initial_point0 := _get_signature_point_flow_speed(initial_signature, 0)
	var baseline_hashes := _read_baseline_hashes(baseline_hash_file)

	river.call("bake_texture")
	var max_frames := 2400
	while bool(river.call("is_bake_in_progress")) and _frame_index < max_frames:
		_frame_index += 1
		await process_frame

	if bool(river.call("is_bake_in_progress")):
		_errors.append("Bake did not finish within " + str(max_frames) + " frames.")
	if not _mutation_done:
		_errors.append("Did not see target progress label prefix: " + TARGET_PROGRESS_PREFIX)

	var bake_data := river.get("bake_data") as Resource
	if bake_data == null:
		_errors.append("River has no bake_data after timing probe.")
		scene.queue_free()
		await process_frame
		return {}
	var metadata: Dictionary = bake_data.get("source_metadata")
	var signature: Dictionary = bake_data.get("source_signature")
	var texture_hashes := _hash_bake_textures(bake_data)
	var comparisons := _compare_hashes(texture_hashes, baseline_hashes)
	var final_point0 := _get_signature_point_flow_speed(signature, 0)
	var final_last := _get_signature_point_flow_speed(signature, _get_signature_point_count(signature) - 1)

	var result := {
		"mutation_done": _mutation_done,
		"mutation_frame": _mutation_frame,
		"mutation_progress": _mutation_progress,
		"mutation_label": _mutation_label,
		"progress_events": _progress_events.duplicate(true),
		"initial_point0_flow_speed": initial_point0,
		"final_point0_flow_speed": final_point0,
		"final_last_point_flow_speed": final_last,
		"metadata_flow_speed_scaled": bool(metadata.get("flow_speed_scaled", false)),
		"signature_point_count": _get_signature_point_count(signature),
		"texture_hashes": texture_hashes,
		"baseline_hashes": baseline_hashes,
		"hash_comparisons": comparisons,
		"source_metadata": metadata.duplicate(true),
		"source_signature": signature.duplicate(true),
	}
	if _mutation_done and not bool(result.metadata_flow_speed_scaled):
		_errors.append("Final metadata did not re-read mutated flow_speeds.")
	if _mutation_done and absf(final_point0 - MUTATED_POINT0_FLOW_SPEED) > 0.0001:
		_errors.append("Final signature point 0 flow_speed did not re-read mutated value.")

	scene.queue_free()
	await process_frame
	var control_result := await _run_neutral_control_bake(scene_path, river_path)
	var control_hashes: Dictionary = control_result.get("texture_hashes", {})
	result["control_metadata_flow_speed_scaled"] = bool(control_result.get("metadata_flow_speed_scaled", false))
	result["control_point0_flow_speed"] = float(control_result.get("point0_flow_speed", -1.0))
	result["control_texture_hashes"] = control_hashes
	result["control_hash_comparisons"] = _compare_hash_entries(texture_hashes, control_hashes)
	return result


func _on_progress_notified(progress, label) -> void:
	var progress_value := float(progress)
	var label_text := String(label)
	_progress_events.append({
		"frame": _frame_index,
		"progress": progress_value,
		"label": label_text,
	})
	if _mutation_done or _target_river == null:
		return
	if not label_text.begins_with(TARGET_PROGRESS_PREFIX):
		return
	_mutation_done = true
	_mutation_frame = _frame_index
	_mutation_label = label_text
	_mutation_progress = progress_value
	_set_mutated_flow_speeds(_target_river)


func _set_neutral_flow_speeds(river: Node) -> void:
	var count := _get_curve_point_count(river)
	var speeds := []
	for _index in count:
		speeds.append(1.0)
	river.call("set_flow_speeds", speeds)


func _set_mutated_flow_speeds(river: Node) -> void:
	var count := _get_curve_point_count(river)
	var speeds := []
	for index in count:
		var speed := 1.0
		if index == 0:
			speed = MUTATED_POINT0_FLOW_SPEED
		elif index == count - 1:
			speed = MUTATED_LAST_POINT_FLOW_SPEED
		speeds.append(speed)
	river.call("set_flow_speeds", speeds)


func _run_neutral_control_bake(scene_path: String, river_path: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("Could not load control scene: " + scene_path)
		return {}
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		_errors.append("Could not find control river " + river_path + " in " + scene_path)
		scene.queue_free()
		await process_frame
		return {}

	_set_neutral_flow_speeds(river)
	river.call("bake_texture")
	var max_frames := 2400
	var frame := 0
	while bool(river.call("is_bake_in_progress")) and frame < max_frames:
		frame += 1
		await process_frame

	if bool(river.call("is_bake_in_progress")):
		_errors.append("Control bake did not finish within " + str(max_frames) + " frames.")

	var bake_data := river.get("bake_data") as Resource
	if bake_data == null:
		_errors.append("Control river has no bake_data after timing probe.")
		scene.queue_free()
		await process_frame
		return {}
	var metadata: Dictionary = bake_data.get("source_metadata")
	var signature: Dictionary = bake_data.get("source_signature")
	var result := {
		"metadata_flow_speed_scaled": bool(metadata.get("flow_speed_scaled", false)),
		"point0_flow_speed": _get_signature_point_flow_speed(signature, 0),
		"texture_hashes": _hash_bake_textures(bake_data),
	}
	scene.queue_free()
	await process_frame
	return result


func _get_curve_point_count(river: Node) -> int:
	var curve = river.get("curve")
	if curve != null and curve.has_method("get_point_count"):
		return int(curve.call("get_point_count"))
	return 0


func _get_signature_point_count(signature: Dictionary) -> int:
	var points = signature.get("points", [])
	if typeof(points) != TYPE_ARRAY:
		return 0
	return (points as Array).size()


func _get_signature_point_flow_speed(signature: Dictionary, index: int) -> float:
	var points = signature.get("points", [])
	if typeof(points) != TYPE_ARRAY:
		return -1.0
	var point_array: Array = points
	if index < 0 or index >= point_array.size():
		return -1.0
	var point = point_array[index]
	if typeof(point) != TYPE_DICTIONARY:
		return -1.0
	return float((point as Dictionary).get("flow_speed", -1.0))


func _hash_bake_textures(bake_data: Resource) -> Dictionary:
	var hashes := {}
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		hashes[property_name] = _hash_texture(bake_data.get(property_name) as Texture2D)
	return hashes


func _hash_texture(texture: Texture2D) -> Dictionary:
	var entry := {
		"present": false,
		"size": Vector2i.ZERO,
		"format": -1,
		"md5": "absent",
	}
	if texture == null:
		return entry
	var image := texture.get_image()
	if image == null or image.is_empty():
		entry.md5 = "unreadable"
		return entry
	entry.present = true
	entry.size = image.get_size()
	entry.format = image.get_format()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	context.update(PackedInt32Array([image.get_format(), image.get_width(), image.get_height()]).to_byte_array())
	context.update(image.get_data())
	entry.md5 = context.finish().hex_encode()
	return entry


func _read_baseline_hashes(file_path: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var text := FileAccess.get_file_as_string(absolute_path)
	var hashes := {}
	if text.is_empty():
		_errors.append("Could not read baseline hash file: " + file_path)
		return hashes
	for line in text.split("\n", false):
		var trimmed := String(line).strip_edges()
		if not trimmed.begins_with("BAKE_HASH texture="):
			continue
		var texture_name := _extract_token_value(trimmed, "texture")
		var md5 := _extract_token_value(trimmed, "md5")
		if not texture_name.is_empty() and not md5.is_empty():
			hashes[texture_name] = md5
	return hashes


func _extract_token_value(line: String, key: String) -> String:
	var prefix := key + "="
	var parts := line.split(" ", false)
	for part in parts:
		var text := String(part)
		if text.begins_with(prefix):
			return text.trim_prefix(prefix)
	return ""


func _compare_hashes(texture_hashes: Dictionary, baseline_hashes: Dictionary) -> Dictionary:
	var comparisons := {}
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var entry: Dictionary = texture_hashes.get(property_name, {})
		var md5 := String(entry.get("md5", ""))
		var baseline_md5 := String(baseline_hashes.get(property_name, ""))
		comparisons[property_name] = {
			"md5": md5,
			"baseline_md5": baseline_md5,
			"matches_baseline": not baseline_md5.is_empty() and md5 == baseline_md5,
		}
	return comparisons


func _compare_hash_entries(texture_hashes: Dictionary, reference_hash_entries: Dictionary) -> Dictionary:
	var reference_hashes := {}
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var reference_entry: Dictionary = reference_hash_entries.get(property_name, {})
		reference_hashes[property_name] = String(reference_entry.get("md5", ""))
	return _compare_hashes(texture_hashes, reference_hashes)


func _write_timing_file(file_path: String, label: String, scene_path: String, river_path: String, result: Dictionary) -> void:
	var lines := PackedStringArray()
	lines.append("R6_MID_BAKE_TIMING_DUMP v1")
	lines.append("target=" + label + " " + scene_path + " " + river_path)
	lines.append("trap=flow_speeds_mutated_at_first_projecting_flow_progress")
	lines.append("interpretation=old_path_had_already_made_flow_speed_source_decision_before_this_progress_label_but_final_metadata_and_signature_reread_live_flow_speeds")
	lines.append("mutation_done=" + str(bool(result.get("mutation_done", false))))
	lines.append("mutation_frame=" + str(int(result.get("mutation_frame", -1))))
	lines.append("mutation_progress=" + str(float(result.get("mutation_progress", 0.0))))
	lines.append("mutation_label=" + String(result.get("mutation_label", "")))
	lines.append("initial_point0_flow_speed=" + str(float(result.get("initial_point0_flow_speed", -1.0))))
	lines.append("final_point0_flow_speed=" + str(float(result.get("final_point0_flow_speed", -1.0))))
	lines.append("final_last_point_flow_speed=" + str(float(result.get("final_last_point_flow_speed", -1.0))))
	lines.append("metadata_flow_speed_scaled=" + str(bool(result.get("metadata_flow_speed_scaled", false))))
	lines.append("control_point0_flow_speed=" + str(float(result.get("control_point0_flow_speed", -1.0))))
	lines.append("control_metadata_flow_speed_scaled=" + str(bool(result.get("control_metadata_flow_speed_scaled", false))))
	lines.append("signature_point_count=" + str(int(result.get("signature_point_count", 0))))
	var control_comparisons: Dictionary = result.get("control_hash_comparisons", {})
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var control_comparison: Dictionary = control_comparisons.get(property_name, {})
		lines.append("control_texture=" + property_name
				+ " trap_md5=" + String(control_comparison.get("md5", ""))
				+ " control_md5=" + String(control_comparison.get("baseline_md5", ""))
				+ " matches_control=" + str(bool(control_comparison.get("matches_baseline", false))))
	var comparisons: Dictionary = result.get("hash_comparisons", {})
	for property_name_variant in TEXTURE_PROPERTIES:
		var property_name := String(property_name_variant)
		var comparison: Dictionary = comparisons.get(property_name, {})
		lines.append("texture=" + property_name
				+ " md5=" + String(comparison.get("md5", ""))
				+ " baseline_md5=" + String(comparison.get("baseline_md5", ""))
				+ " matches_baseline=" + str(bool(comparison.get("matches_baseline", false))))
	var progress_events: Array = result.get("progress_events", [])
	lines.append("progress_event_count=" + str(progress_events.size()))
	for index in progress_events.size():
		var event: Dictionary = progress_events[index]
		lines.append("progress[" + str(index) + "] frame=" + str(int(event.get("frame", -1)))
				+ " value=" + str(float(event.get("progress", 0.0)))
				+ " label=" + String(event.get("label", "")))
	_write_text_file(file_path, "\n".join(lines) + "\n")


func _write_text_file(file_path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var parent := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error != OK:
		_errors.append("Could not create output parent " + parent + ": " + error_string(dir_error))
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_errors.append("Could not write " + absolute_path + ": " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(text)
	file.close()
	_written_files.append(file_path)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args
