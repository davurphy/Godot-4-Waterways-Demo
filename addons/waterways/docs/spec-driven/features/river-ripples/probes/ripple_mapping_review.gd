extends Control

const MAPPING_SHADER_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_mapping_markers.gdshader"
const MARKER_NAMES := ["entry", "center", "right-bank", "downstream"]
const MARKER_UVS := [
	Vector2(0.15625, 0.21875),
	Vector2(0.50000, 0.50000),
	Vector2(0.78125, 0.34375),
	Vector2(0.87500, 0.81250),
]
const MARKER_HEIGHT_RATIOS := [0.20, 0.45, 0.70, 0.35]
const MARKER_COLORS := [
	Color(1.0, 0.05, 0.05, 1.0),
	Color(0.05, 1.0, 0.20, 1.0),
	Color(0.10, 0.35, 1.0, 1.0),
	Color(1.0, 0.15, 0.85, 1.0),
]

@export_range(64, 1024, 1) var resolution := 256
@export var show_visual_views := true
@export_range(0.001, 0.1, 0.001) var marker_radius_uv := 0.026
@export var field_origin := Vector3(-24.0, 8.0, 12.0)
@export var field_size := Vector3(64.0, 10.0, 48.0)

var _field_bounds := AABB()
var _world_to_ripple_uv := Transform3D.IDENTITY
var _markers := []
var _mapping_viewport: SubViewport
var _mapping_material: ShaderMaterial
var _mapping_texture_rect: TextureRect
var _scene_viewport: SubViewport
var _white_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_mapping_probe()


func render_mapping_markers_once() -> void:
	if _mapping_material == null or _mapping_viewport == null:
		return
	_mapping_material.set_shader_parameter("world_to_ripple_uv", _world_to_ripple_uv)
	_mapping_material.set_shader_parameter("marker_radius_uv", marker_radius_uv)
	for index in _markers.size():
		var marker: Dictionary = _markers[index]
		_mapping_material.set_shader_parameter("marker_world_" + str(index), marker.world)
		_mapping_material.set_shader_parameter("marker_color_" + str(index), marker.color)
	_mapping_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mapping_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _mapping_texture_rect != null:
		_mapping_texture_rect.texture = _mapping_viewport.get_texture()


func get_mapping_texture() -> Texture2D:
	if _mapping_viewport == null:
		return null
	return _mapping_viewport.get_texture()


func get_mapping_snapshot() -> Dictionary:
	var texture := get_mapping_texture()
	return {
		"resolution": resolution,
		"field_bounds": _field_bounds,
		"world_to_ripple_uv": _world_to_ripple_uv,
		"mapping_texture_size": texture.get_size() if texture != null else Vector2i.ZERO,
		"marker_radius_uv": marker_radius_uv,
		"markers": _markers.duplicate(true),
		"visual_scene_markers": _scene_viewport != null,
	}


func world_position_to_ripple_uv(world_position: Vector3) -> Vector2:
	var mapped: Vector3 = _world_to_ripple_uv * world_position
	return Vector2(mapped.x, mapped.z)


static func build_world_to_ripple_uv(bounds: AABB) -> Transform3D:
	var x_size := bounds.size.x
	if is_zero_approx(x_size):
		x_size = 1.0
	var y_size := bounds.size.y
	if is_zero_approx(y_size):
		y_size = 1.0
	var z_size := bounds.size.z
	if is_zero_approx(z_size):
		z_size = 1.0
	var basis := Basis(
		Vector3(1.0 / x_size, 0.0, 0.0),
		Vector3(0.0, 1.0 / y_size, 0.0),
		Vector3(0.0, 0.0, 1.0 / z_size)
	)
	return Transform3D(basis, basis * -bounds.position)


func _build_mapping_probe() -> void:
	_field_bounds = AABB(field_origin, field_size)
	_world_to_ripple_uv = build_world_to_ripple_uv(_field_bounds)
	_markers = _build_fixed_markers(_field_bounds)
	_white_texture = _create_solid_texture(Color.WHITE)
	_build_mapping_viewport()
	if show_visual_views:
		_build_review_ui()
	render_mapping_markers_once()


func _build_fixed_markers(bounds: AABB) -> Array:
	var markers := []
	for index in MARKER_UVS.size():
		var uv: Vector2 = MARKER_UVS[index]
		var height_ratio := float(MARKER_HEIGHT_RATIOS[index])
		var world_position := Vector3(
			bounds.position.x + uv.x * bounds.size.x,
			bounds.position.y + height_ratio * bounds.size.y,
			bounds.position.z + uv.y * bounds.size.z
		)
		var mapped_uv := world_position_to_ripple_uv(world_position)
		markers.append({
			"name": MARKER_NAMES[index],
			"world": world_position,
			"expected_uv": mapped_uv,
			"color": MARKER_COLORS[index],
		})
	return markers


func _build_mapping_viewport() -> void:
	var shader := load(MAPPING_SHADER_PATH) as Shader
	if shader == null:
		push_error("Could not load " + MAPPING_SHADER_PATH)
		return
	_mapping_material = ShaderMaterial.new()
	_mapping_material.shader = shader

	_mapping_viewport = SubViewport.new()
	_mapping_viewport.name = "RippleMappingTextureMarkers"
	_mapping_viewport.size = Vector2i(resolution, resolution)
	_mapping_viewport.transparent_bg = false
	_mapping_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_mapping_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mapping_viewport.gui_disable_input = true

	var texture_rect := TextureRect.new()
	texture_rect.position = Vector2.ZERO
	texture_rect.size = Vector2(resolution, resolution)
	texture_rect.texture = _white_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.material = _mapping_material
	_mapping_viewport.add_child(texture_rect)
	add_child(_mapping_viewport)


func _build_review_ui() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)

	var scene_column := _add_column(row, "scene markers")
	_add_scene_view(scene_column)
	_add_marker_table(scene_column)

	var texture_column := _add_column(row, "texture impulses")
	_mapping_texture_rect = TextureRect.new()
	_mapping_texture_rect.texture = _mapping_viewport.get_texture()
	_mapping_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_mapping_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mapping_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapping_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapping_texture_rect.custom_minimum_size = Vector2(360, 360)
	texture_column.add_child(_mapping_texture_rect)


func _add_column(parent: Control, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := Label.new()
	label.text = title
	column.add_child(label)
	return column


func _add_scene_view(parent: Control) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(360, 360)
	parent.add_child(container)

	_scene_viewport = SubViewport.new()
	_scene_viewport.name = "RippleMappingSceneMarkers"
	_scene_viewport.size = Vector2i(resolution, resolution)
	_scene_viewport.own_world_3d = true
	_scene_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_scene_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_scene_viewport)
	_populate_scene_viewport(_scene_viewport)


func _populate_scene_viewport(viewport: SubViewport) -> void:
	var root_3d := Node3D.new()
	viewport.add_child(root_3d)

	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(_field_bounds.size.x, _field_bounds.size.z)
	plane.mesh = plane_mesh
	plane.position = Vector3(
		_field_bounds.position.x + _field_bounds.size.x * 0.5,
		_field_bounds.position.y,
		_field_bounds.position.z + _field_bounds.size.z * 0.5
	)
	var plane_material := StandardMaterial3D.new()
	plane_material.albedo_color = Color(0.05, 0.16, 0.20, 1.0)
	plane_material.roughness = 0.8
	plane.material_override = plane_material
	root_3d.add_child(plane)

	for marker in _markers:
		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = max(min(_field_bounds.size.x, _field_bounds.size.z) * 0.018, 0.35)
		sphere.height = sphere.radius * 2.0
		mesh_instance.mesh = sphere
		mesh_instance.position = marker.world
		var material := StandardMaterial3D.new()
		material.albedo_color = marker.color
		material.emission_enabled = true
		material.emission = marker.color
		material.emission_energy_multiplier = 0.8
		mesh_instance.material_override = material
		root_3d.add_child(mesh_instance)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	root_3d.add_child(light)

	var camera := Camera3D.new()
	var center := _field_bounds.position + _field_bounds.size * 0.5
	var camera_position := center + Vector3(0.0, max(_field_bounds.size.x, _field_bounds.size.z) * 1.2, 0.001)
	camera.look_at_from_position(camera_position, center, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = max(_field_bounds.size.x, _field_bounds.size.z) * 1.15
	camera.current = true
	viewport.add_child(camera)


func _add_marker_table(parent: Control) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = _get_marker_table_text()
	parent.add_child(label)


func _get_marker_table_text() -> String:
	var lines := PackedStringArray()
	lines.append("world_to_ripple_uv maps world X/Z into texture U/V")
	for marker in _markers:
		lines.append(
			"%s world=%s uv=%s"
			% [
				String(marker.name),
				_format_vector3(marker.world),
				_format_vector2(marker.expected_uv),
			]
		)
	return "\n".join(lines)


func _format_vector2(value: Vector2) -> String:
	return "(%.4f, %.4f)" % [value.x, value.y]


func _format_vector3(value: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]


func _create_solid_texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
