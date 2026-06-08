extends SceneTree

const REVIEW_SCRIPT_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_review.gd"
const PROBE_RESOLUTION := 256

var _errors := PackedStringArray()
var _results := []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var review_script := load(REVIEW_SCRIPT_PATH) as Script
	_expect(review_script != null, "Could not load " + REVIEW_SCRIPT_PATH)
	if review_script == null or not review_script.can_instantiate():
		_expect(false, "Ripple mapping review script should be instantiable")
		_finish()
		return

	var review := review_script.new() as Control
	_expect(review != null, "Ripple mapping review script should instantiate as Control")
	if review == null:
		_finish()
		return

	review.set("resolution", PROBE_RESOLUTION)
	review.set("show_visual_views", false)
	root.add_child(review)
	await _settle_frames(4)
	review.call("render_mapping_markers_once")
	await _settle_frames(3)

	var snapshot: Dictionary = review.call("get_mapping_snapshot")
	var texture := review.call("get_mapping_texture") as Texture2D
	_expect(texture != null, "Mapping probe should expose a texture marker render")
	_expect(Vector2i(snapshot.get("mapping_texture_size", Vector2i.ZERO)) == Vector2i(PROBE_RESOLUTION, PROBE_RESOLUTION), "Mapping texture should initialize at the probe resolution")
	_expect(not bool(snapshot.get("visual_scene_markers", true)), "Console probe should run without the visible scene viewport")

	var image: Image = null
	if texture != null:
		# Validation-only readback. Runtime ripple mapping and river rendering must not use this pattern.
		image = texture.get_image()
	_expect(image != null and not image.is_empty(), "Mapping texture should be readable for validation")
	if image != null and not image.is_empty():
		_validate_mapping_snapshot(snapshot, image)
	await _run_visual_scene_smoke(review_script)

	print("RIPPLE_MAPPING_PROBE_RESULTS=", _results)
	_finish()


func _run_visual_scene_smoke(review_script: Script) -> void:
	var review := review_script.new() as Control
	_expect(review != null, "Ripple mapping visual review script should instantiate as Control")
	if review == null:
		return
	review.set("resolution", 128)
	review.set("show_visual_views", true)
	root.add_child(review)
	await _settle_frames(4)
	var snapshot: Dictionary = review.call("get_mapping_snapshot")
	_expect(bool(snapshot.get("visual_scene_markers", false)), "Mapping visual review should create scene markers")
	_expect(Vector2i(snapshot.get("mapping_texture_size", Vector2i.ZERO)) == Vector2i(128, 128), "Mapping visual review should create a 128x128 texture marker view")
	review.queue_free()
	await _settle_frames(2)


func _validate_mapping_snapshot(snapshot: Dictionary, image: Image) -> void:
	var transform: Transform3D = snapshot.get("world_to_ripple_uv", Transform3D.IDENTITY)
	var markers: Array = snapshot.get("markers", [])
	_expect(markers.size() == 4, "Mapping probe should have four fixed marker positions")
	var marker_radius_uv := float(snapshot.get("marker_radius_uv", 0.0))
	_expect(marker_radius_uv > 0.0, "Marker radius should be recorded")

	for marker in markers:
		var world_position: Vector3 = marker.get("world", Vector3.ZERO)
		var expected_uv: Vector2 = marker.get("expected_uv", Vector2(-1.0, -1.0))
		var mapped_position: Vector3 = transform * world_position
		var mapped_uv := Vector2(mapped_position.x, mapped_position.z)
		_expect(mapped_uv.distance_to(expected_uv) < 0.00001, "GDScript world_to_ripple_uv should reproduce expected UV for " + str(marker.get("name", "marker")))
		_expect(_uv_is_in_bounds(mapped_uv), "Marker " + str(marker.get("name", "marker")) + " should map inside the ripple field")

		var color: Color = marker.get("color", Color.WHITE)
		var sample := _sample_marker_at_expected_uv(image, mapped_uv, color, marker_radius_uv)
		_expect(float(sample.get("best_color_distance", 1.0)) < 0.25, "Texture marker should land at expected UV for " + str(marker.get("name", "marker")) + "; sample=" + str(sample))
		_results.append({
			"name": marker.get("name", "marker"),
			"world": world_position,
			"expected_uv": expected_uv,
			"mapped_uv": mapped_uv,
			"sample": sample,
		})


func _sample_marker_at_expected_uv(image: Image, uv: Vector2, target_color: Color, marker_radius_uv: float) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var expected_pixel := Vector2(
		uv.x * float(width - 1),
		uv.y * float(height - 1)
	)
	var search_radius := max(3, int(ceil(marker_radius_uv * float(min(width, height)) * 0.45)))
	var center := Vector2i(
		clampi(int(round(expected_pixel.x)), 0, width - 1),
		clampi(int(round(expected_pixel.y)), 0, height - 1)
	)
	var best_distance := INF
	var best_pixel := center
	var best_color := Color.BLACK
	for y in range(max(center.y - search_radius, 0), min(center.y + search_radius + 1, height)):
		for x in range(max(center.x - search_radius, 0), min(center.x + search_radius + 1, width)):
			var color := image.get_pixel(x, y)
			var distance := _rgb_distance(color, target_color)
			if distance < best_distance:
				best_distance = distance
				best_pixel = Vector2i(x, y)
				best_color = color
	return {
		"expected_pixel": expected_pixel,
		"best_pixel": best_pixel,
		"best_pixel_error": Vector2(best_pixel).distance_to(expected_pixel),
		"best_color": best_color,
		"best_color_distance": best_distance,
		"search_radius": search_radius,
	}


func _rgb_distance(first: Color, second: Color) -> float:
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()


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
		print("RIPPLE_MAPPING_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
