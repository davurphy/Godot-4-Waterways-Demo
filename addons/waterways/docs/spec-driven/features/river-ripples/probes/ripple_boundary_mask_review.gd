extends Control

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const BOUNDARY_SHADER_PATH := "res://addons/waterways/docs/spec-driven/features/river-ripples/probes/ripple_boundary_mask.gdshader"
const TARGET_POINTS := [
	Vector3(-13.0, 0.0, -3.0),
	Vector3(5.0, 0.0, -3.0),
	Vector3(10.0, 0.0, 0.0),
	Vector3(5.0, 0.0, 3.0),
	Vector3(-13.0, 0.0, 3.0),
]
const TARGET_WIDTHS := [1.05, 1.20, 1.15, 1.20, 1.05]
const SAMPLE_DEFINITIONS := [
	{
		name = "lower-channel-source",
		world = Vector3(-2.0, 0.0, -3.0),
		expected_inside = true,
		color = Color(0.08, 0.95, 0.35, 1.0),
	},
	{
		name = "upper-channel-across-bank",
		world = Vector3(-2.0, 0.0, 3.0),
		expected_inside = true,
		color = Color(0.15, 0.45, 1.0, 1.0),
	},
	{
		name = "dry-gap-between-branches",
		world = Vector3(-2.0, 0.0, 0.0),
		expected_inside = false,
		color = Color(1.0, 0.18, 0.12, 1.0),
	},
	{
		name = "dry-northwest-field",
		world = Vector3(-14.0, 0.0, -14.0),
		expected_inside = false,
		color = Color(1.0, 0.70, 0.10, 1.0),
	},
	{
		name = "outer-dry-corner",
		world = Vector3(14.0, 0.0, 14.0),
		expected_inside = false,
		color = Color(1.0, 0.10, 0.80, 1.0),
	},
]

@export_range(64, 1024, 1) var resolution := 256
@export var show_visual_views := true
@export var field_origin := Vector3(-16.0, -2.0, -16.0)
@export var field_size := Vector3(32.0, 4.0, 32.0)
@export_range(1, 8, 1) var shape_step_length_divs := 2
@export_range(1, 8, 1) var shape_step_width_divs := 2
@export_range(0.1, 5.0, 0.1) var shape_smoothness := 0.5

var _field_bounds := AABB()
var _world_to_ripple_uv := Transform3D.IDENTITY
var _target_curve: Curve3D
var _target_mesh_instance: MeshInstance3D
var _boundary_viewport: SubViewport
var _boundary_texture_rect: TextureRect
var _scene_viewport: SubViewport
var _samples := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_boundary_probe()


func _exit_tree() -> void:
	if _target_mesh_instance != null and is_instance_valid(_target_mesh_instance):
		_target_mesh_instance.free()
	_target_mesh_instance = null


func render_boundary_mask_once() -> void:
	if _boundary_viewport == null:
		return
	_boundary_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_boundary_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _boundary_texture_rect != null:
		_boundary_texture_rect.texture = _boundary_viewport.get_texture()


func get_boundary_texture() -> Texture2D:
	if _boundary_viewport == null:
		return null
	return _boundary_viewport.get_texture()


func get_boundary_snapshot() -> Dictionary:
	var texture := get_boundary_texture()
	return {
		"resolution": resolution,
		"field_bounds": _field_bounds,
		"world_to_ripple_uv": _world_to_ripple_uv,
		"boundary_texture_size": texture.get_size() if texture != null else Vector2i.ZERO,
		"target_mesh_aabb": _get_mesh_global_aabb(_target_mesh_instance),
		"mask_source": "target_river_mesh_footprint",
		"uses_uv2_atlas": false,
		"normal_runtime_readback": false,
		"samples": _samples.duplicate(true),
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


func _build_boundary_probe() -> void:
	_field_bounds = AABB(field_origin, field_size)
	_world_to_ripple_uv = build_world_to_ripple_uv(_field_bounds)
	_target_curve = _build_target_curve()
	_target_mesh_instance = _build_target_mesh_instance(_target_curve)
	_samples = _build_samples()
	_build_boundary_viewport()
	if show_visual_views:
		_build_review_ui()
	render_boundary_mask_once()


func _build_target_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.05
	for point in TARGET_POINTS:
		curve.add_point(point)
	return curve


func _build_target_mesh_instance(curve: Curve3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TargetRiverMeshFootprintSource"
	var steps := _calculate_target_steps(curve)
	var widths := TARGET_WIDTHS.duplicate()
	var river_width_values := WaterHelperMethods.generate_river_width_values(curve, steps, shape_step_length_divs, shape_step_width_divs, widths)
	mesh_instance.mesh = WaterHelperMethods.generate_river_mesh(curve, steps, shape_step_length_divs, shape_step_width_divs, shape_smoothness, river_width_values, resolution)
	return mesh_instance


func _calculate_target_steps(curve: Curve3D) -> int:
	var average_width := 0.0
	for width in TARGET_WIDTHS:
		average_width += float(width)
	average_width /= float(max(TARGET_WIDTHS.size(), 1))
	return int(max(4.0, round(curve.get_baked_length() / max(average_width, 0.001))))


func _build_samples() -> Array:
	var samples := []
	for definition in SAMPLE_DEFINITIONS:
		var world_position: Vector3 = definition.world
		samples.append({
			"name": definition.name,
			"world": world_position,
			"expected_uv": world_position_to_ripple_uv(world_position),
			"expected_inside": bool(definition.expected_inside),
			"color": definition.color,
		})
	return samples


func _build_boundary_viewport() -> void:
	var shader := load(BOUNDARY_SHADER_PATH) as Shader
	if shader == null:
		push_error("Could not load " + BOUNDARY_SHADER_PATH)
		return

	_boundary_viewport = SubViewport.new()
	_boundary_viewport.name = "RippleBoundaryMask"
	_boundary_viewport.size = Vector2i(resolution, resolution)
	_boundary_viewport.transparent_bg = true
	_boundary_viewport.own_world_3d = true
	_boundary_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_boundary_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_boundary_viewport.gui_disable_input = true

	var root_3d := Node3D.new()
	_boundary_viewport.add_child(root_3d)

	var normalized_mesh := MeshInstance3D.new()
	normalized_mesh.name = "NormalizedTargetRiverFootprint"
	normalized_mesh.mesh = _build_normalized_footprint_mesh(_target_mesh_instance)
	var material := ShaderMaterial.new()
	material.shader = shader
	normalized_mesh.material_override = material
	root_3d.add_child(normalized_mesh)

	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(0.5, 1.0, 0.5), Vector3(0.5, 0.0, 0.5), Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	camera.near = 0.01
	camera.far = 4.0
	camera.current = true
	_boundary_viewport.add_child(camera)

	add_child(_boundary_viewport)


func _build_normalized_footprint_mesh(source: MeshInstance3D) -> Mesh:
	var normalized_mesh := ArrayMesh.new()
	if source == null or source.mesh == null:
		return normalized_mesh

	for surface_index in source.mesh.get_surface_count():
		var primitive: Mesh.PrimitiveType = source.mesh.surface_get_primitive_type(surface_index)
		var arrays := source.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue

		var mapped_vertices := PackedVector3Array()
		var mapped_normals := PackedVector3Array()
		for vertex in vertices:
			var world_vertex: Vector3 = source.transform * vertex
			var mapped: Vector3 = _world_to_ripple_uv * world_vertex
			mapped_vertices.append(Vector3(mapped.x, 0.0, mapped.z))
			mapped_normals.append(Vector3.UP)
		arrays[Mesh.ARRAY_VERTEX] = mapped_vertices
		arrays[Mesh.ARRAY_NORMAL] = mapped_normals
		normalized_mesh.add_surface_from_arrays(primitive, arrays)

	return normalized_mesh


func _build_review_ui() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)

	var scene_column := _add_column(row, "target river mesh")
	_add_scene_view(scene_column)
	_add_sample_table(scene_column)

	var mask_column := _add_column(row, "boundary mask")
	_boundary_texture_rect = TextureRect.new()
	_boundary_texture_rect.texture = _boundary_viewport.get_texture() if _boundary_viewport != null else null
	_boundary_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_boundary_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boundary_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boundary_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_boundary_texture_rect.custom_minimum_size = Vector2(360, 360)
	mask_column.add_child(_boundary_texture_rect)


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
	_scene_viewport.name = "RippleBoundaryTargetScene"
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
	plane_material.albedo_color = Color(0.035, 0.045, 0.050, 1.0)
	plane_material.roughness = 0.9
	plane.material_override = plane_material
	root_3d.add_child(plane)

	var target_scene_mesh := MeshInstance3D.new()
	target_scene_mesh.mesh = _target_mesh_instance.mesh if _target_mesh_instance != null else null
	var target_material := StandardMaterial3D.new()
	target_material.albedo_color = Color(0.02, 0.45, 0.78, 1.0)
	target_material.emission_enabled = true
	target_material.emission = Color(0.01, 0.28, 0.42, 1.0)
	target_material.emission_energy_multiplier = 0.55
	target_scene_mesh.material_override = target_material
	root_3d.add_child(target_scene_mesh)

	for sample in _samples:
		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.23
		sphere.height = sphere.radius * 2.0
		mesh_instance.mesh = sphere
		mesh_instance.position = sample.world + Vector3(0.0, 0.35, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = sample.color
		material.emission_enabled = true
		material.emission = sample.color
		material.emission_energy_multiplier = 0.85
		mesh_instance.material_override = material
		root_3d.add_child(mesh_instance)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	root_3d.add_child(light)

	var camera := Camera3D.new()
	var center := _field_bounds.position + _field_bounds.size * 0.5
	var camera_position := center + Vector3(0.0, max(_field_bounds.size.x, _field_bounds.size.z) * 1.20, 0.001)
	camera.look_at_from_position(camera_position, center, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = max(_field_bounds.size.x, _field_bounds.size.z) * 1.12
	camera.current = true
	viewport.add_child(camera)


func _add_sample_table(parent: Control) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = _get_sample_table_text()
	parent.add_child(label)


func _get_sample_table_text() -> String:
	var lines := PackedStringArray()
	lines.append("green/blue = water, red/orange/pink = dry")
	for sample in _samples:
		lines.append(
			"%s uv=%s expected=%s"
			% [
				String(sample.name),
				_format_vector2(sample.expected_uv),
				"water" if bool(sample.expected_inside) else "dry",
			]
		)
	return "\n".join(lines)


func _get_mesh_global_aabb(instance: MeshInstance3D) -> AABB:
	if instance == null:
		return AABB()
	return instance.transform * instance.get_aabb()


func _format_vector2(value: Vector2) -> String:
	return "(%.4f, %.4f)" % [value.x, value.y]
