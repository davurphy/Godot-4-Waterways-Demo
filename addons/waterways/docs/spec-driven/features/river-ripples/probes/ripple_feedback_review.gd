extends Control

const SIMULATION_SHADER_PATH := "res://addons/waterways/shaders/runtime/ripple_simulation.gdshader"
const IMPULSE_SHADER_PATH := "res://addons/waterways/shaders/runtime/ripple_impulse.gdshader"

@export_range(32, 1024, 1) var resolution := 256
@export_range(1.0, 120.0, 1.0) var simulation_update_rate := 60.0
@export var auto_step := true
@export var auto_emit := true
@export_range(0.05, 5.0, 0.01) var auto_emit_interval := 1.0
@export var impulse_uv := Vector2(0.5, 0.5)
@export_range(0.001, 0.5, 0.001) var impulse_radius := 0.055
@export_range(0.0, 1.0, 0.001) var impulse_intensity := 0.8
@export_range(0.0, 1.0, 0.001) var damping := 0.985
@export_range(0.0, 2.0, 0.001) var propagation := 0.45
@export_range(0.0, 0.25, 0.001) var boundary_fade := 0.025
@export var show_debug_views := true

var _simulation_viewports := []
var _simulation_materials := []
var _impulse_viewport: SubViewport
var _impulse_material: ShaderMaterial
var _neutral_texture: Texture2D
var _black_texture: Texture2D
var _white_texture: Texture2D
var _boundary_texture: Texture2D
var _read_index := 0
var _write_index := 1
var _step_accumulator := 0.0
var _emit_accumulator := 0.0
var _pending_impulse := false
var _pending_impulse_uv := Vector2(0.5, 0.5)
var _pending_impulse_radius := 0.055
var _pending_impulse_intensity := 0.8
var _current_texture_rect: TextureRect
var _write_texture_rect: TextureRect
var _impulse_texture_rect: TextureRect
var _last_read_texture: Texture2D
var _last_write_viewport: SubViewport
var _is_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_runtime_probe()


func _process(delta: float) -> void:
	if not _is_ready:
		return
	if auto_emit:
		_emit_accumulator += delta
		if _emit_accumulator >= auto_emit_interval:
			_emit_accumulator = 0.0
			queue_impulse(impulse_uv, impulse_radius, impulse_intensity)
	if _pending_impulse:
		render_queued_impulse_once()
	elif auto_step:
		clear_impulse_once()
	if auto_step:
		var step_interval: float = 1.0 / max(simulation_update_rate, 1.0)
		_step_accumulator += delta
		while _step_accumulator >= step_interval:
			_step_accumulator -= step_interval
			step_once()


func queue_impulse(uv: Vector2, radius: float, intensity: float) -> void:
	_pending_impulse = true
	_pending_impulse_uv = uv
	_pending_impulse_radius = radius
	_pending_impulse_intensity = intensity


func render_queued_impulse_once() -> void:
	_set_impulse_material(_pending_impulse, _pending_impulse_uv, _pending_impulse_radius, _pending_impulse_intensity)
	_pending_impulse = false


func clear_impulse_once() -> void:
	_set_impulse_material(false, Vector2(0.5, 0.5), impulse_radius, 0.0)


func step_once() -> void:
	if not _is_ready:
		return
	var read_viewport := _simulation_viewports[_read_index] as SubViewport
	var write_viewport := _simulation_viewports[_write_index] as SubViewport
	var write_material := _simulation_materials[_write_index] as ShaderMaterial
	var read_texture := read_viewport.get_texture()
	if read_texture == null:
		read_texture = _neutral_texture
	var impulse_texture := _impulse_viewport.get_texture()
	if impulse_texture == null:
		impulse_texture = _black_texture

	write_material.set_shader_parameter("previous_texture", read_texture)
	write_material.set_shader_parameter("impulse_texture", impulse_texture)
	write_material.set_shader_parameter("boundary_texture", _get_active_boundary_texture())
	write_material.set_shader_parameter("texel_size", Vector2.ONE / float(max(resolution, 1)))
	write_material.set_shader_parameter("damping", damping)
	write_material.set_shader_parameter("propagation", propagation)
	write_material.set_shader_parameter("boundary_fade", boundary_fade)
	write_material.set_shader_parameter("clear_state", false)
	_request_viewport_update_once(write_viewport)

	_last_read_texture = read_texture
	_last_write_viewport = write_viewport
	var old_read := _read_index
	_read_index = _write_index
	_write_index = old_read
	_update_debug_textures()


func reset_feedback() -> void:
	for index in _simulation_viewports.size():
		var material := _simulation_materials[index] as ShaderMaterial
		var viewport := _simulation_viewports[index] as SubViewport
		material.set_shader_parameter("previous_texture", _neutral_texture)
		material.set_shader_parameter("impulse_texture", _black_texture)
		material.set_shader_parameter("boundary_texture", _get_active_boundary_texture())
		material.set_shader_parameter("texel_size", Vector2.ONE / float(max(resolution, 1)))
		material.set_shader_parameter("damping", damping)
		material.set_shader_parameter("propagation", propagation)
		material.set_shader_parameter("boundary_fade", boundary_fade)
		material.set_shader_parameter("clear_state", true)
		_request_viewport_update_once(viewport)
	_read_index = 0
	_write_index = 1
	_update_debug_textures()


func get_current_ripple_texture() -> Texture2D:
	if _simulation_viewports.size() != 2:
		return null
	var read_viewport := _simulation_viewports[_read_index] as SubViewport
	if read_viewport == null:
		return null
	return read_viewport.get_texture()


func get_impulse_texture() -> Texture2D:
	if _impulse_viewport == null:
		return null
	return _impulse_viewport.get_texture()


func set_boundary_texture(texture: Texture2D) -> void:
	_boundary_texture = texture


func clear_boundary_texture() -> void:
	_boundary_texture = null


func get_active_boundary_texture() -> Texture2D:
	return _get_active_boundary_texture()


func get_feedback_snapshot() -> Dictionary:
	var read_viewport := _simulation_viewports[_read_index] as SubViewport
	var write_viewport := _simulation_viewports[_write_index] as SubViewport
	var read_texture := read_viewport.get_texture() if read_viewport != null else null
	var write_texture := write_viewport.get_texture() if write_viewport != null else null
	var boundary_texture := _get_active_boundary_texture()
	var same_target_hazard := _last_read_texture != null and _last_write_viewport != null and _last_read_texture == _last_write_viewport.get_texture()
	return {
		"resolution": resolution,
		"read_index": _read_index,
		"write_index": _write_index,
		"read_texture_size": read_texture.get_size() if read_texture != null else Vector2i.ZERO,
		"write_texture_size": write_texture.get_size() if write_texture != null else Vector2i.ZERO,
		"boundary_texture_size": boundary_texture.get_size() if boundary_texture != null else Vector2i.ZERO,
		"has_custom_boundary_texture": _boundary_texture != null,
		"has_distinct_viewports": _simulation_viewports.size() == 2 and _simulation_viewports[0] != _simulation_viewports[1],
		"has_distinct_textures": read_texture != null and write_texture != null and read_texture != write_texture,
		"same_target_hazard_last_step": same_target_hazard,
		"normal_runtime_readback": false,
	}


func _build_runtime_probe() -> void:
	var simulation_shader := load(SIMULATION_SHADER_PATH) as Shader
	var impulse_shader := load(IMPULSE_SHADER_PATH) as Shader
	if simulation_shader == null:
		push_error("Could not load " + SIMULATION_SHADER_PATH)
		return
	if impulse_shader == null:
		push_error("Could not load " + IMPULSE_SHADER_PATH)
		return

	_neutral_texture = _create_solid_texture(Color(0.5, 0.5, 0.0, 1.0))
	_black_texture = _create_solid_texture(Color(0.0, 0.0, 0.0, 1.0))
	_white_texture = _create_solid_texture(Color(1.0, 1.0, 1.0, 1.0))

	for index in range(2):
		var viewport := _create_viewport("RippleSimulation" + str(index))
		var material := ShaderMaterial.new()
		material.shader = simulation_shader
		_add_full_viewport_rect(viewport, material)
		add_child(viewport)
		_simulation_viewports.append(viewport)
		_simulation_materials.append(material)

	_impulse_viewport = _create_viewport("RippleImpulse")
	_impulse_material = ShaderMaterial.new()
	_impulse_material.shader = impulse_shader
	_add_full_viewport_rect(_impulse_viewport, _impulse_material)
	add_child(_impulse_viewport)

	if show_debug_views:
		_build_debug_ui()

	_is_ready = true
	reset_feedback()
	clear_impulse_once()


func _create_viewport(viewport_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = Vector2i(resolution, resolution)
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	return viewport


func _add_full_viewport_rect(viewport: SubViewport, material: Material) -> void:
	var texture_rect := TextureRect.new()
	texture_rect.position = Vector2.ZERO
	texture_rect.size = Vector2(resolution, resolution)
	texture_rect.texture = _white_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.material = material
	viewport.add_child(texture_rect)


func _build_debug_ui() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	_current_texture_rect = _add_texture_panel(row, "current")
	_write_texture_rect = _add_texture_panel(row, "previous")
	_impulse_texture_rect = _add_texture_panel(row, "impulse")
	_update_debug_textures()


func _add_texture_panel(parent: Control, label_text: String) -> TextureRect:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := Label.new()
	label.text = label_text
	column.add_child(label)
	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(texture_rect)
	return texture_rect


func _update_debug_textures() -> void:
	if _current_texture_rect != null:
		_current_texture_rect.texture = (_simulation_viewports[_read_index] as SubViewport).get_texture()
	if _write_texture_rect != null:
		_write_texture_rect.texture = (_simulation_viewports[_write_index] as SubViewport).get_texture()
	if _impulse_texture_rect != null and _impulse_viewport != null:
		_impulse_texture_rect.texture = _impulse_viewport.get_texture()


func _set_impulse_material(is_enabled: bool, uv: Vector2, radius: float, intensity: float) -> void:
	if _impulse_material == null or _impulse_viewport == null:
		return
	_impulse_material.set_shader_parameter("impulse_uv", uv)
	_impulse_material.set_shader_parameter("impulse_radius", radius)
	_impulse_material.set_shader_parameter("impulse_intensity", intensity if is_enabled else 0.0)
	_request_viewport_update_once(_impulse_viewport)


func _request_viewport_update_once(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _get_active_boundary_texture() -> Texture2D:
	if _boundary_texture != null:
		return _boundary_texture
	return _white_texture


func _create_solid_texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
