# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends RefCounted

const WaterHelperMethods = preload("./water_helper_methods.gd")

const DATA_TEXTURE_MARKER := "RIVER_DATA_TEXTURE_TEST"
const FILTER_RENDERER_MARKER := "FILTER_RENDERER_TEST"
const DATA_TEXTURES := [
	{
		"label": "flow_foam_noise",
		"expect_neutral_flow": true,
	},
	{
		"label": "dist_pressure",
		"expect_neutral_flow": false,
	},
	{
		"label": "obstacle_features",
		"expect_neutral_flow": false,
	},
	{
		"label": "terrain_contact_features",
		"expect_neutral_flow": false,
	},
	{
		"label": "bank_response_features",
		"expect_neutral_flow": false,
	},
]


func validate_data_textures(context: Dictionary) -> void:
	var failures := []
	var notes := []
	for entry in DATA_TEXTURES:
		var label := String(entry.get("label", ""))
		var texture := context.get(label) as Texture2D
		var expect_neutral_flow := bool(entry.get("expect_neutral_flow", false))
		_append_texture_data_validation(label, texture, expect_neutral_flow, context, failures, notes)
	if failures.is_empty():
		print(DATA_TEXTURE_MARKER + ": " + "; ".join(notes))
	else:
		push_warning(DATA_TEXTURE_MARKER + ": " + "; ".join(failures) + " | " + "; ".join(notes))


func validate_filter_renderer(context: Dictionary) -> void:
	var failures := []
	var notes := []
	var renderer_parent := context.get("renderer_parent") as Node
	if renderer_parent == null or not renderer_parent.is_inside_tree():
		push_warning(FILTER_RENDERER_MARKER + ": River must be inside the edited scene tree")
		return
	var filter_renderer_scene = context.get("filter_renderer_scene")
	if not (filter_renderer_scene is PackedScene):
		push_warning(FILTER_RENDERER_MARKER + ": filter renderer scene could not be loaded")
		return
	var renderer_scene := filter_renderer_scene as PackedScene
	var renderer_instance = renderer_scene.instantiate()
	if renderer_instance == null:
		push_warning(FILTER_RENDERER_MARKER + ": filter renderer scene could not be instantiated")
		return
	renderer_parent.add_child(renderer_instance)
	await renderer_parent.get_tree().process_frame
	var source_texture := _make_filter_validation_texture()
	var combine_result: Texture2D = await renderer_instance.apply_combine(source_texture, source_texture, source_texture, source_texture)
	_append_filter_texture_validation("combine", combine_result, failures, notes)
	var dot_result: Texture2D = await renderer_instance.apply_dotproduct(source_texture)
	_append_filter_texture_validation("dotproduct", dot_result, failures, notes)
	var flow_pressure_result: Texture2D = await renderer_instance.apply_flow_pressure(source_texture, 8.0, 2.0)
	_append_filter_texture_validation("flow_pressure", flow_pressure_result, failures, notes)
	var foam_result: Texture2D = await renderer_instance.apply_foam(source_texture, 0.1, 0.9)
	_append_filter_texture_validation("foam", foam_result, failures, notes)
	var blur_result: Texture2D = await renderer_instance.apply_blur(source_texture, 0.0, 8.0)
	_append_filter_texture_validation("blur_zero", blur_result, failures, notes)
	var vertical_blur_result: Texture2D = await renderer_instance.apply_vertical_blur(source_texture, 0.0, 8.0)
	_append_filter_texture_validation("vertical_blur_zero", vertical_blur_result, failures, notes)
	var normal_result: Texture2D = await renderer_instance.apply_normal(source_texture, 0.0)
	_append_filter_texture_validation("normal_zero_size", normal_result, failures, notes)
	var normal_to_flow_result: Texture2D = await renderer_instance.apply_normal_to_flow(normal_result)
	_append_filter_texture_validation("normal_to_flow", normal_to_flow_result, failures, notes)
	var dilate_result: Texture2D = await renderer_instance.apply_dilate(source_texture, 0.0, 0.0, 0.0, source_texture)
	_append_filter_texture_validation("dilate_zero", dilate_result, failures, notes)
	var dilate_default_fill_result: Texture2D = await renderer_instance.apply_dilate(source_texture, 0.0, 1.0, 0.0)
	_append_filter_texture_validation("dilate_default_fill", dilate_default_fill_result, failures, notes)
	var active_dilate_fill_texture = renderer_instance.get("filter_mat").get_shader_parameter("color_texture")
	if active_dilate_fill_texture == null:
		failures.append("dilate default fill did not assign a fallback color texture")
	elif active_dilate_fill_texture == source_texture:
		failures.append("dilate default fill reused the previous color_texture")
	else:
		notes.append("dilate_default_fill_texture_reset=true")
	_cleanup_renderer(renderer_instance, context)
	if failures.is_empty():
		print(FILTER_RENDERER_MARKER + ": " + "; ".join(notes))
	else:
		push_warning(FILTER_RENDERER_MARKER + ": " + "; ".join(failures) + " | " + "; ".join(notes))


func _append_texture_data_validation(label: String, texture: Texture2D, expect_neutral_flow: bool, context: Dictionary, failures: Array, notes: Array) -> void:
	if texture == null:
		failures.append(label + " is not assigned")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append(label + " has no readable image data")
		return
	var size := image.get_size()
	notes.append("%s size=%dx%d" % [label, size.x, size.y])
	_append_data_texture_import_validation(label, texture, context, failures, notes)
	if expect_neutral_flow:
		_append_neutral_flow_validation(label, image, texture.resource_path, failures, notes)
		_append_flow_vector_stats_validation(label, image, context, notes)
		_append_alpha_phase_noise_validation(label, image, notes)


func _append_data_texture_import_validation(label: String, texture: Texture2D, context: Dictionary, failures: Array, notes: Array) -> void:
	var path := texture.resource_path
	var generated_bake_source_kind := _get_generated_bake_source_kind_for_texture(label, texture, context)
	if path.is_empty() or not generated_bake_source_kind.is_empty():
		var source_note := label + " source=generated/resource-owned"
		if not generated_bake_source_kind.is_empty():
			source_note += " source_kind=" + generated_bake_source_kind
		notes.append(source_note)
		return
	notes.append(label + " source=" + path)
	if not path.begins_with("res://"):
		failures.append(label + " uses a non-project texture path")
		return
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		failures.append(label + " has no .import settings file")
		return
	var import_text := FileAccess.get_file_as_string(import_path)
	if import_text.find("compress/mode=0") == -1:
		failures.append(label + " import should use lossless/uncompressed texture data (compress/mode=0)")
	if import_text.find("compress/normal_map=0") == -1:
		failures.append(label + " import should not be treated as a normal map")
	if import_text.find("mipmaps/generate=true") != -1:
		failures.append(label + " import has mipmaps enabled before neutral-flow/mask stability is validated")
	if import_text.find("\"vram_texture\": true") != -1 or import_text.find("path.s3tc=") != -1:
		failures.append(label + " import uses VRAM/block-compressed data")


func _get_generated_bake_source_kind_for_texture(label: String, texture: Texture2D, context: Dictionary) -> String:
	var bake_data := context.get("bake_data") as Resource
	if texture == null or bake_data == null:
		return ""
	var source_kind := String(bake_data.get("source_kind"))
	if not source_kind.begins_with("generated_"):
		return ""
	var stored_texture := bake_data.get(label) as Texture2D
	if stored_texture == texture:
		return source_kind
	var bake_path := bake_data.resource_path
	var texture_path := texture.resource_path
	if not bake_path.is_empty() and texture_path.begins_with(bake_path + "::"):
		return source_kind
	return ""


func _append_neutral_flow_validation(label: String, image: Image, texture_path: String, failures: Array, notes: Array) -> void:
	var size := image.get_size()
	var step := max(1, int(ceil(float(max(size.x, size.y)) / 128.0)))
	var best_error := INF
	var best_color := Color()
	var best_pixel := Vector2i.ZERO
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var color := image.get_pixel(x, y)
			var error: float = abs(color.r - 0.5) + abs(color.g - 0.5)
			if error < best_error:
				best_error = error
				best_color = color
				best_pixel = Vector2i(x, y)
	notes.append("%s closest_neutral_rg=(%.4f, %.4f) pixel=(%d,%d)" % [label, best_color.r, best_color.g, best_pixel.x, best_pixel.y])
	var neutral_tolerance := 0.01
	if best_error > neutral_tolerance and not texture_path.is_empty():
		failures.append(label + " imported flow map did not preserve or include a sampled neutral (0.5, 0.5) flow value")


func _append_flow_vector_stats_validation(label: String, image: Image, context: Dictionary, notes: Array) -> void:
	var content_rect := _get_bake_content_rect_for_image(image, context)
	var source_stats := WaterHelperMethods.get_decoded_flow_vector_stats(
		image,
		content_rect,
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD
	)
	notes.append(WaterHelperMethods.format_decoded_flow_vector_stats(label + " source_rect", source_stats))
	var atlas_stats := WaterHelperMethods.get_uv2_atlas_decoded_flow_vector_stats(
		image,
		_get_bake_uv2_sides(context),
		max(1, int(context.get("step_count", 1))),
		content_rect,
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD
	)
	var occupied_stats: Dictionary = atlas_stats.get("occupied", {})
	var unused_stats: Dictionary = atlas_stats.get("unused", {})
	notes.append(WaterHelperMethods.format_decoded_flow_vector_stats(label + " occupied_tiles", occupied_stats))
	notes.append(WaterHelperMethods.format_decoded_flow_vector_stats(label + " unused_tiles", unused_stats))


func _get_bake_content_rect_for_image(image: Image, context: Dictionary) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var content_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var bake_data := context.get("bake_data") as Resource
	if bake_data != null:
		var stored_rect = bake_data.get("content_rect")
		if typeof(stored_rect) == TYPE_RECT2I and stored_rect.size.x > 0 and stored_rect.size.y > 0:
			content_rect = stored_rect
	return content_rect


func _get_bake_uv2_sides(context: Dictionary) -> int:
	var uv2_sides := int(context.get("uv2_sides", 1))
	var bake_data := context.get("bake_data") as Resource
	if bake_data != null:
		var stored_uv2_sides = bake_data.get("uv2_sides")
		if stored_uv2_sides != null:
			uv2_sides = int(stored_uv2_sides)
	return max(1, uv2_sides)


func _append_alpha_phase_noise_validation(label: String, image: Image, notes: Array) -> void:
	var size := image.get_size()
	var step := max(1, int(ceil(float(max(size.x, size.y)) / 128.0)))
	var alpha_min := INF
	var alpha_max := -INF
	var samples := 0
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var alpha := image.get_pixel(x, y).a
			alpha_min = min(alpha_min, alpha)
			alpha_max = max(alpha_max, alpha)
			samples += 1
	var alpha_range: float = alpha_max - alpha_min
	var alpha_state := "varied" if alpha_range > 0.001 else "flat"
	notes.append("%s alpha_min=%.4f alpha_max=%.4f alpha_range=%.4f alpha_state=%s samples=%d" % [label, alpha_min, alpha_max, alpha_range, alpha_state, samples])


func _make_filter_validation_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var xf := float(x) / float(max(1, image.get_width() - 1))
			var yf := float(y) / float(max(1, image.get_height() - 1))
			var checker := 1.0 if ((x + y) % 2 == 0) else 0.0
			image.set_pixel(x, y, Color(xf, yf, checker, 1.0))
	return ImageTexture.create_from_image(image)


func _append_filter_texture_validation(label: String, texture: Texture2D, failures: Array, notes: Array) -> void:
	if texture == null:
		failures.append(label + " returned null texture")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append(label + " returned no readable image data")
		return
	var size := image.get_size()
	if size.x <= 0 or size.y <= 0:
		failures.append(label + " returned invalid size")
		return
	var invalid_samples := 0
	for sample_point in [Vector2i(0, 0), Vector2i(size.x / 2, size.y / 2), Vector2i(size.x - 1, size.y - 1)]:
		var color := image.get_pixelv(sample_point)
		if is_nan(color.r) or is_nan(color.g) or is_nan(color.b) or is_nan(color.a) or is_inf(color.r) or is_inf(color.g) or is_inf(color.b) or is_inf(color.a):
			invalid_samples += 1
	if invalid_samples > 0:
		failures.append(label + " returned invalid numeric samples")
	notes.append("%s=%dx%d" % [label, size.x, size.y])


func _cleanup_renderer(renderer_instance: Node, context: Dictionary) -> void:
	var cleanup_renderer: Callable = context.get("cleanup_renderer", Callable())
	if cleanup_renderer.is_valid():
		cleanup_renderer.call(renderer_instance)
		return
	if renderer_instance == null or not is_instance_valid(renderer_instance):
		return
	if renderer_instance.get_parent() != null:
		renderer_instance.get_parent().remove_child(renderer_instance)
	renderer_instance.queue_free()
