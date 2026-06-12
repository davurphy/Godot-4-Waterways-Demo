@tool
@icon("res://addons/waterways/icons/ripple_field.svg")
class_name WaterRippleField
extends Node3D

const SIMULATION_SHADER_PATH := "res://addons/waterways/shaders/runtime/ripple_simulation.gdshader"
const IMPULSE_SHADER_PATH := "res://addons/waterways/shaders/runtime/ripple_impulse_additive.gdshader"
const BOUNDARY_SHADER_PATH := "res://addons/waterways/shaders/runtime/ripple_boundary_mask.gdshader"
const DEFAULT_FIELD_GROUP := "water_ripple_fields"
const NEUTRAL_HEIGHT_COLOR := Color(0.5, 0.5, 0.0, 1.0)
const WaterRippleFieldPresetResource := preload("res://addons/waterways/resources/water_ripple_field_preset.gd")

@export_group("Setup")
@export var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if is_inside_tree():
			if enabled:
				initialize_runtime()
				_apply_material_state_to_targets()
			else:
				_clear_target_material_state()
			_sync_processing()
			update_configuration_warnings()

@export_range(32, 1024, 1) var resolution := 256:
	set(value):
		var sanitized: int = max(2, int(value))
		if resolution == sanitized:
			return
		resolution = sanitized
		if _runtime_initialized and not _is_applying_preset:
			rebuild_runtime()
		if is_inside_tree():
			update_configuration_warnings()

@export var world_bounds := AABB(Vector3(-16.0, -2.0, -16.0), Vector3(32.0, 4.0, 32.0)):
	set(value):
		world_bounds = value
		_world_to_ripple_uv = build_world_to_ripple_uv(world_bounds)
		if _runtime_initialized:
			rebuild_boundary_mask()
			reset_feedback()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()

@export_range(1.0, 120.0, 1.0) var simulation_update_rate := 60.0:
	set(value):
		var sanitized: float = max(1.0, float(value))
		if is_equal_approx(simulation_update_rate, sanitized):
			return
		simulation_update_rate = sanitized
		if is_inside_tree():
			update_configuration_warnings()

@export_group("Targets")
@export var target_river_paths: Array[NodePath] = []:
	set(value):
		target_river_paths = value
		if _runtime_initialized:
			_refresh_target_rivers()
			rebuild_boundary_mask()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()

@export var target_group_name := "":
	set(value):
		target_group_name = value
		if _runtime_initialized:
			_refresh_target_rivers()
			rebuild_boundary_mask()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()

@export var field_group_name := DEFAULT_FIELD_GROUP:
	set(value):
		var next_group := String(value)
		if field_group_name == next_group:
			return
		var previous_group := field_group_name
		field_group_name = next_group
		if is_inside_tree():
			if not previous_group.is_empty() and is_in_group(previous_group):
				remove_from_group(previous_group)
			if not field_group_name.is_empty():
				add_to_group(field_group_name)
			update_configuration_warnings()

@export_group("Boundary Mask")
@export var auto_generate_boundary_mask := true:
	set(value):
		if auto_generate_boundary_mask == value:
			return
		auto_generate_boundary_mask = value
		if _runtime_initialized and not _is_applying_preset:
			rebuild_boundary_mask()
			reset_feedback()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()

@export var require_boundary_mask := true:
	set(value):
		if require_boundary_mask == value:
			return
		require_boundary_mask = value
		if _runtime_initialized and not _is_applying_preset:
			rebuild_boundary_mask()
			reset_feedback()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()

@export var boundary_source_paths: Array[NodePath] = []:
	set(value):
		boundary_source_paths = value
		if _runtime_initialized:
			rebuild_boundary_mask()
			reset_feedback()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()

@export var boundary_mask_texture: Texture2D:
	set(value):
		boundary_mask_texture = value
		if _runtime_initialized:
			rebuild_boundary_mask()
			reset_feedback()
			_apply_material_state_to_targets()
		if is_inside_tree():
			update_configuration_warnings()
@export_range(0.0, 0.25, 0.001) var boundary_fade := 0.025

@export_group("Simulation")
@export_range(0.0, 1.0, 0.001) var damping := 0.985
@export_range(0.0, 2.0, 0.001) var propagation := 0.45
@export_range(1, 128, 1) var max_emitters := 16:
	set(value):
		var sanitized: int = max(1, int(value))
		if max_emitters == sanitized:
			return
		max_emitters = sanitized
		if _runtime_initialized and not _is_applying_preset:
			rebuild_runtime()
		if is_inside_tree():
			update_configuration_warnings()

@export_group("Visual Response")
@export_range(0.0, 4.0, 0.001) var ripple_strength := 1.0
@export_range(0.0, 8.0, 0.001) var normal_strength := 1.25
@export_range(0.0, 200.0, 0.1) var height_fade_distance := 0.0

# Reserved for river-height-displacement (2026-06-12): hidden stored fields for
# the planned feature (see river-height displacement/initial_research.md and
# river-ripples spec contract). debug_visible additionally awaits its Phase 10
# re-exposure design. Do not delete without updating that contract list and the
# asserting probes.
@export_storage var refraction_strength := 0.0
@export_storage var displacement_strength := 0.0
@export_storage var debug_visible := false

var _simulation_viewports := []
var _simulation_materials := []
var _impulse_viewport: SubViewport
var _impulse_materials := []
var _impulse_rects := []
var _boundary_viewport: SubViewport
var _boundary_texture: Texture2D
var _neutral_texture: Texture2D
var _black_texture: Texture2D
var _white_texture: Texture2D
var _world_to_ripple_uv := Transform3D.IDENTITY
var _registered_targets := []
var _target_rivers := []
var _applied_targets := []
var _read_index := 0
var _write_index := 1
var _step_accumulator := 0.0
var _queued_impulses := []
var _runtime_initialized := false
var _boundary_valid := false
var _boundary_source := "none"
var _last_boundary_build_error := ""
var _last_read_texture: Texture2D
var _last_write_viewport: SubViewport
var _last_rendered_impulse_count := 0
var _last_capped_impulse_count := 0
var _last_rejected_impulse_count := 0
var _steps_completed := 0
var _is_applying_preset := false


func _enter_tree() -> void:
	_world_to_ripple_uv = build_world_to_ripple_uv(world_bounds)
	if not field_group_name.is_empty():
		add_to_group(field_group_name)
	if _should_run_runtime() and enabled:
		initialize_runtime()
	_sync_processing()


func _exit_tree() -> void:
	cleanup_runtime()


func _process(delta: float) -> void:
	if not _runtime_initialized or not enabled:
		return

	if not _queued_impulses.is_empty():
		render_queued_impulses_once()
		return

	var step_interval: float = 1.0 / max(simulation_update_rate, 1.0)
	_step_accumulator += delta
	while _step_accumulator >= step_interval:
		_step_accumulator -= step_interval
		step_once()
		clear_impulse_once()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if resolution < 2:
		warnings.append("Ripple resolution must be at least 2 pixels.")
	if world_bounds.size.x <= 0.0 or world_bounds.size.z <= 0.0:
		warnings.append("Ripple field world_bounds needs positive X and Z size.")
	if transform != Transform3D.IDENTITY:
		warnings.append("WaterRippleField currently uses axis-aligned world_bounds; the node transform is not part of ripple mapping yet.")
	if target_river_paths.is_empty() and target_group_name.is_empty():
		warnings.append("Add at least one target river path or target group before enabling river material output.")
	for path in target_river_paths:
		if path == NodePath(""):
			continue
		var target := get_node_or_null(path)
		if not _is_valid_ripple_target(target):
			warnings.append("Target river path '" + String(path) + "' does not resolve to a compatible Waterways river target.")
	if not target_group_name.is_empty() and is_inside_tree():
		var has_group_target := false
		for target in get_tree().get_nodes_in_group(target_group_name):
			if _is_valid_ripple_target(target):
				has_group_target = true
				break
		if not has_group_target:
			warnings.append("Target group '" + target_group_name + "' currently has no compatible Waterways river targets.")
	if field_group_name.is_empty():
		warnings.append("Field group name is empty; group-routed WaterRippleEmitter nodes cannot discover this field.")
	if boundary_mask_texture == null and not auto_generate_boundary_mask and require_boundary_mask:
		warnings.append("Boundary masking is required, but no boundary texture is assigned and auto generation is disabled.")
	if boundary_mask_texture == null and auto_generate_boundary_mask and boundary_source_paths.is_empty() and target_river_paths.is_empty() and target_group_name.is_empty():
		warnings.append("Boundary auto-generation needs target rivers or explicit boundary source mesh paths.")
	for path in boundary_source_paths:
		if path == NodePath(""):
			continue
		var source := get_node_or_null(path)
		var source_mesh := _get_target_mesh_instance(source)
		if source_mesh == null or source_mesh.mesh == null:
			warnings.append("Boundary source path '" + String(path) + "' does not resolve to a MeshInstance3D or Waterways river mesh.")
	if Engine.is_editor_hint() and enabled:
		warnings.append("Runtime ripple textures are created only while the scene runs; editor-time preview is intentionally disabled for this prototype.")
	return warnings


static func get_builtin_preset_names() -> PackedStringArray:
	return WaterRippleFieldPresetResource.get_builtin_preset_names()


static func create_builtin_preset(preset_name: String) -> WaterRippleFieldPresetResource:
	return WaterRippleFieldPresetResource.create_builtin_preset(preset_name)


func apply_builtin_preset(preset_name: String) -> bool:
	var preset := create_builtin_preset(preset_name)
	if preset == null:
		return false
	return apply_preset(preset)


func apply_preset(preset: Resource) -> bool:
	if preset == null or not (preset is WaterRippleFieldPresetResource):
		return false

	var next_resolution: int = max(2, int(preset.resolution))
	var next_max_emitters: int = max(1, int(preset.max_emitters))
	var next_normal_strength: float = max(0.0, float(preset.normal_strength))
	var next_height_fade_distance: float = max(0.0, float(preset.height_fade_distance))
	var next_boundary_fade: float = clamp(float(preset.boundary_fade), 0.0, 0.25)
	var runtime_rebuild_needed := _runtime_initialized and (resolution != next_resolution or max_emitters != next_max_emitters)
	var boundary_rebuild_needed := _runtime_initialized and (
			auto_generate_boundary_mask != bool(preset.auto_generate_boundary_mask)
			or require_boundary_mask != bool(preset.require_boundary_mask)
	)
	var material_reapply_needed := _runtime_initialized and (
			boundary_rebuild_needed
			or not is_equal_approx(normal_strength, next_normal_strength)
			or not is_equal_approx(height_fade_distance, next_height_fade_distance)
			or not is_equal_approx(boundary_fade, next_boundary_fade)
	)

	_is_applying_preset = true
	resolution = next_resolution
	simulation_update_rate = max(1.0, float(preset.simulation_update_rate))
	damping = clamp(float(preset.damping), 0.0, 1.0)
	propagation = clamp(float(preset.propagation), 0.0, 2.0)
	max_emitters = next_max_emitters
	ripple_strength = max(0.0, float(preset.ripple_strength))
	normal_strength = next_normal_strength
	height_fade_distance = next_height_fade_distance
	boundary_fade = next_boundary_fade
	auto_generate_boundary_mask = bool(preset.auto_generate_boundary_mask)
	require_boundary_mask = bool(preset.require_boundary_mask)
	_is_applying_preset = false

	if runtime_rebuild_needed:
		rebuild_runtime()
	elif _runtime_initialized:
		var material_reapplied := false
		if boundary_rebuild_needed:
			rebuild_boundary_mask()
			reset_feedback()
			material_reapplied = true
		if material_reapply_needed and not material_reapplied:
			_apply_material_state_to_targets()

	if is_inside_tree():
		update_configuration_warnings()
	return true


func capture_preset() -> WaterRippleFieldPresetResource:
	var preset := WaterRippleFieldPresetResource.new()
	preset.resource_name = "Captured Water Ripple Field Preset"
	preset.resolution = resolution
	preset.simulation_update_rate = simulation_update_rate
	preset.damping = damping
	preset.propagation = propagation
	preset.max_emitters = max_emitters
	preset.ripple_strength = ripple_strength
	preset.normal_strength = normal_strength
	preset.height_fade_distance = height_fade_distance
	preset.boundary_fade = boundary_fade
	preset.auto_generate_boundary_mask = auto_generate_boundary_mask
	preset.require_boundary_mask = require_boundary_mask
	return preset


func initialize_runtime() -> bool:
	if _runtime_initialized:
		return true
	if not _should_run_runtime():
		return false

	var simulation_shader := load(SIMULATION_SHADER_PATH) as Shader
	var impulse_shader := load(IMPULSE_SHADER_PATH) as Shader
	if simulation_shader == null:
		push_warning("WaterRippleField could not load " + SIMULATION_SHADER_PATH + ".")
		return false
	if impulse_shader == null:
		push_warning("WaterRippleField could not load " + IMPULSE_SHADER_PATH + ".")
		return false

	_neutral_texture = _create_solid_texture(NEUTRAL_HEIGHT_COLOR)
	_black_texture = _create_solid_texture(Color(0.0, 0.0, 0.0, 1.0))
	_white_texture = _create_solid_texture(Color(1.0, 1.0, 1.0, 1.0))

	for index in range(2):
		var viewport := _create_canvas_viewport("WaterRippleSimulation" + str(index))
		var material := ShaderMaterial.new()
		material.shader = simulation_shader
		_add_full_viewport_rect(viewport, material, true)
		add_child(viewport)
		_simulation_viewports.append(viewport)
		_simulation_materials.append(material)

	_impulse_viewport = _create_canvas_viewport("WaterRippleImpulse")
	for impulse_index in range(max_emitters):
		var material := ShaderMaterial.new()
		material.shader = impulse_shader
		var rect := _add_full_viewport_rect(_impulse_viewport, material, false)
		_impulse_materials.append(material)
		_impulse_rects.append(rect)
	add_child(_impulse_viewport)

	_runtime_initialized = true
	_refresh_target_rivers()
	rebuild_boundary_mask()
	if require_boundary_mask and not _boundary_valid:
		push_warning("WaterRippleField cannot start because no valid boundary mask is available.")
		cleanup_runtime()
		return false

	reset_feedback()
	clear_impulse_once()
	_apply_material_state_to_targets()
	_sync_processing()
	return true


func rebuild_runtime() -> void:
	var should_restart := _should_run_runtime() and enabled
	cleanup_runtime()
	if should_restart:
		initialize_runtime()


func cleanup_runtime() -> void:
	_clear_target_material_state()
	set_process(false)
	_runtime_initialized = false
	_boundary_valid = false
	_boundary_source = "none"
	_boundary_texture = null
	_queued_impulses.clear()
	_simulation_materials.clear()
	_impulse_materials.clear()
	_impulse_rects.clear()
	_simulation_viewports.clear()
	_registered_targets.clear()
	_target_rivers.clear()
	_applied_targets.clear()
	_last_read_texture = null
	_last_write_viewport = null
	_last_rendered_impulse_count = 0
	_last_capped_impulse_count = 0
	_read_index = 0
	_write_index = 1

	for child in get_children():
		if child is SubViewport and String(child.name).begins_with("WaterRipple"):
			child.queue_free()
	_impulse_viewport = null
	_boundary_viewport = null


func rebuild_boundary_mask() -> void:
	if not _runtime_initialized:
		return
	if _boundary_viewport != null and is_instance_valid(_boundary_viewport):
		_boundary_viewport.queue_free()
	_boundary_viewport = null
	_boundary_texture = null
	_boundary_valid = false
	_boundary_source = "none"
	_last_boundary_build_error = ""

	if boundary_mask_texture != null:
		_boundary_texture = boundary_mask_texture
		_boundary_valid = true
		_boundary_source = "assigned_texture"
		return
	if not auto_generate_boundary_mask:
		_last_boundary_build_error = "auto_generation_disabled"
		return

	var target_meshes := _get_target_mesh_instances()
	if target_meshes.is_empty():
		_last_boundary_build_error = "no_target_mesh_instances"
		return

	var boundary_shader := load(BOUNDARY_SHADER_PATH) as Shader
	if boundary_shader == null:
		_last_boundary_build_error = "boundary_shader_missing"
		push_warning("WaterRippleField could not load " + BOUNDARY_SHADER_PATH + ".")
		return

	_boundary_viewport = SubViewport.new()
	_boundary_viewport.name = "WaterRippleBoundaryMask"
	_boundary_viewport.size = Vector2i(resolution, resolution)
	_boundary_viewport.transparent_bg = true
	_boundary_viewport.own_world_3d = true
	_boundary_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_boundary_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_boundary_viewport.gui_disable_input = true

	var root_3d := Node3D.new()
	_boundary_viewport.add_child(root_3d)

	for source in target_meshes:
		var normalized := MeshInstance3D.new()
		normalized.name = "NormalizedRippleBoundaryFootprint"
		normalized.mesh = _build_normalized_footprint_mesh(source)
		if normalized.mesh == null or normalized.mesh.get_surface_count() == 0:
			continue
		var material := ShaderMaterial.new()
		material.shader = boundary_shader
		normalized.material_override = material
		root_3d.add_child(normalized)

	if root_3d.get_child_count() == 0:
		_last_boundary_build_error = "normalized_footprint_empty"
		_boundary_viewport.queue_free()
		_boundary_viewport = null
		return

	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(0.5, 1.0, 0.5), Vector3(0.5, 0.0, 0.5), Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	camera.near = 0.01
	camera.far = 4.0
	camera.current = true
	_boundary_viewport.add_child(camera)
	add_child(_boundary_viewport)
	_request_viewport_update_once(_boundary_viewport)
	_boundary_texture = _boundary_viewport.get_texture()
	_boundary_valid = _boundary_texture != null
	_boundary_source = "target_river_mesh_footprint" if _boundary_valid else "none"
	_last_boundary_build_error = "" if _boundary_valid else "viewport_texture_missing"


func register_target(river: Node) -> bool:
	if river == null or not is_instance_valid(river):
		return false
	if not _registered_targets.has(river):
		_registered_targets.append(river)
	if not _target_rivers.has(river):
		_target_rivers.append(river)
		rebuild_boundary_mask()
	if _runtime_initialized and enabled:
		return _apply_material_state_to_target(river, _make_material_state())
	return true


func unregister_target(river: Node) -> void:
	if river == null:
		return
	if _registered_targets.has(river):
		_registered_targets.erase(river)
	if _target_rivers.has(river):
		_target_rivers.erase(river)
	if _applied_targets.has(river):
		_clear_material_state_for_target(river)
	rebuild_boundary_mask()


func queue_impulse_world(world_position: Vector3, radius_world: float, intensity: float, falloff: float = 2.0, priority: int = 0, source: Object = null) -> bool:
	var uv := world_position_to_ripple_uv(world_position)
	var radius_uv := world_radius_to_ripple_uv_radius(radius_world)
	return queue_impulse(uv, radius_uv, intensity, falloff, priority, source)


func queue_impulse(uv: Vector2, radius_uv: float, intensity: float, falloff: float = 2.0, priority: int = 0, source: Object = null) -> bool:
	if not enabled:
		_last_rejected_impulse_count += 1
		return false
	if not _runtime_initialized and not initialize_runtime():
		_last_rejected_impulse_count += 1
		return false
	if not _uv_is_in_bounds(uv):
		_last_rejected_impulse_count += 1
		return false
	_queued_impulses.append({
		"uv": uv,
		"radius": clamp(radius_uv, 0.0001, 0.5),
		"intensity": clamp(intensity, 0.0, 1.0),
		"falloff": max(falloff, 0.01),
		"priority": priority,
		"source_id": source.get_instance_id() if source != null else 0,
	})
	return true


func render_queued_impulses_once() -> int:
	if not _runtime_initialized or _impulse_viewport == null:
		return 0
	var impulses := _queued_impulses.duplicate(true)
	impulses.sort_custom(Callable(self, "_sort_impulses_by_priority"))
	var render_count := min(impulses.size(), _impulse_materials.size())
	_last_rendered_impulse_count = render_count
	_last_capped_impulse_count = max(0, impulses.size() - render_count)

	for index in range(_impulse_materials.size()):
		var material := _impulse_materials[index] as ShaderMaterial
		var rect := _impulse_rects[index] as TextureRect
		if index < render_count:
			var impulse: Dictionary = impulses[index]
			material.set_shader_parameter("impulse_uv", impulse.uv)
			material.set_shader_parameter("impulse_radius", impulse.radius)
			material.set_shader_parameter("impulse_intensity", impulse.intensity)
			material.set_shader_parameter("impulse_falloff", impulse.falloff)
			rect.visible = true
		else:
			rect.visible = false

	_queued_impulses.clear()
	_request_viewport_update_once(_impulse_viewport)
	return render_count


func clear_impulse_once() -> void:
	if _impulse_viewport == null:
		return
	for rect in _impulse_rects:
		if rect != null:
			rect.visible = false
	_request_viewport_update_once(_impulse_viewport)


func step_once() -> bool:
	if not _runtime_initialized:
		return false
	if _simulation_viewports.size() != 2 or _simulation_materials.size() != 2:
		return false

	var read_viewport := _simulation_viewports[_read_index] as SubViewport
	var write_viewport := _simulation_viewports[_write_index] as SubViewport
	var write_material := _simulation_materials[_write_index] as ShaderMaterial
	var read_texture := read_viewport.get_texture() if read_viewport != null else null
	if read_texture == null:
		read_texture = _neutral_texture
	var impulse_texture := get_impulse_texture()
	if impulse_texture == null:
		impulse_texture = _black_texture

	write_material.set_shader_parameter("previous_texture", read_texture)
	write_material.set_shader_parameter("impulse_texture", impulse_texture)
	write_material.set_shader_parameter("boundary_texture", _get_active_boundary_texture())
	write_material.set_shader_parameter("texel_size", Vector2.ONE / float(max(resolution, 1)))
	write_material.set_shader_parameter("damping", damping)
	write_material.set_shader_parameter("propagation", propagation)
	write_material.set_shader_parameter("impulse_strength", ripple_strength)
	write_material.set_shader_parameter("boundary_fade", boundary_fade)
	write_material.set_shader_parameter("clear_state", false)
	_request_viewport_update_once(write_viewport)

	_last_read_texture = read_texture
	_last_write_viewport = write_viewport
	var old_read := _read_index
	_read_index = _write_index
	_write_index = old_read
	_steps_completed += 1
	_apply_material_state_to_targets()
	return true


func reset_feedback() -> void:
	if not _runtime_initialized:
		return
	for index in range(_simulation_viewports.size()):
		var material := _simulation_materials[index] as ShaderMaterial
		var viewport := _simulation_viewports[index] as SubViewport
		material.set_shader_parameter("previous_texture", _neutral_texture)
		material.set_shader_parameter("impulse_texture", _black_texture)
		material.set_shader_parameter("boundary_texture", _get_active_boundary_texture())
		material.set_shader_parameter("texel_size", Vector2.ONE / float(max(resolution, 1)))
		material.set_shader_parameter("damping", damping)
		material.set_shader_parameter("propagation", propagation)
		material.set_shader_parameter("impulse_strength", ripple_strength)
		material.set_shader_parameter("boundary_fade", boundary_fade)
		material.set_shader_parameter("clear_state", true)
		_request_viewport_update_once(viewport)
	_read_index = 0
	_write_index = 1
	_steps_completed = 0
	_apply_material_state_to_targets()


func get_current_ripple_texture() -> Texture2D:
	if _simulation_viewports.size() != 2:
		return null
	var read_viewport := _simulation_viewports[_read_index] as SubViewport
	if read_viewport == null:
		return null
	return read_viewport.get_texture()


func get_previous_ripple_texture() -> Texture2D:
	if _simulation_viewports.size() != 2:
		return null
	var write_viewport := _simulation_viewports[_write_index] as SubViewport
	if write_viewport == null:
		return null
	return write_viewport.get_texture()


func get_impulse_texture() -> Texture2D:
	if _impulse_viewport == null:
		return null
	return _impulse_viewport.get_texture()


func get_boundary_texture() -> Texture2D:
	return _get_active_boundary_texture()


func get_world_to_ripple_uv() -> Transform3D:
	return _world_to_ripple_uv


func world_position_to_ripple_uv(world_position: Vector3) -> Vector2:
	var mapped := _world_to_ripple_uv * world_position
	return Vector2(mapped.x, mapped.z)


func world_radius_to_ripple_uv_radius(radius_world: float) -> float:
	var xz_size: float = max(world_bounds.size.x, world_bounds.size.z)
	if xz_size <= 0.0:
		return radius_world
	return radius_world / xz_size


func get_field_snapshot() -> Dictionary:
	var read_viewport := _simulation_viewports[_read_index] as SubViewport if _simulation_viewports.size() == 2 else null
	var write_viewport := _simulation_viewports[_write_index] as SubViewport if _simulation_viewports.size() == 2 else null
	var read_texture := read_viewport.get_texture() if read_viewport != null else null
	var write_texture := write_viewport.get_texture() if write_viewport != null else null
	var boundary_texture := _get_active_boundary_texture()
	var same_target_hazard := _last_read_texture != null and _last_write_viewport != null and _last_read_texture == _last_write_viewport.get_texture()
	return {
		"enabled": enabled,
		"runtime_initialized": _runtime_initialized,
		"resolution": resolution,
		"world_bounds": world_bounds,
		"world_to_ripple_uv": _world_to_ripple_uv,
		"read_index": _read_index,
		"write_index": _write_index,
		"read_texture_size": read_texture.get_size() if read_texture != null else Vector2i.ZERO,
		"write_texture_size": write_texture.get_size() if write_texture != null else Vector2i.ZERO,
		"impulse_texture_size": get_impulse_texture().get_size() if get_impulse_texture() != null else Vector2i.ZERO,
		"boundary_texture_size": boundary_texture.get_size() if boundary_texture != null else Vector2i.ZERO,
		"boundary_valid": _boundary_valid,
		"boundary_source": _boundary_source,
		"last_boundary_build_error": _last_boundary_build_error,
		"target_river_path_count": target_river_paths.size(),
		"boundary_source_path_count": boundary_source_paths.size(),
		"has_distinct_viewports": _simulation_viewports.size() == 2 and _simulation_viewports[0] != _simulation_viewports[1],
		"has_distinct_textures": read_texture != null and write_texture != null and read_texture != write_texture,
		"same_target_hazard_last_step": same_target_hazard,
		"normal_runtime_readback": false,
		"target_count": _target_rivers.size(),
		"applied_target_count": _applied_targets.size(),
		"queued_impulse_count": _queued_impulses.size(),
		"last_rendered_impulse_count": _last_rendered_impulse_count,
		"last_capped_impulse_count": _last_capped_impulse_count,
		"last_rejected_impulse_count": _last_rejected_impulse_count,
		"steps_completed": _steps_completed,
		"max_emitters": max_emitters,
	}


func get_runtime_viewport_rids() -> Array:
	var rids := []
	for viewport in _simulation_viewports:
		if viewport != null:
			rids.append((viewport as SubViewport).get_viewport_rid())
	if _impulse_viewport != null:
		rids.append(_impulse_viewport.get_viewport_rid())
	if _boundary_viewport != null:
		rids.append(_boundary_viewport.get_viewport_rid())
	return rids


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


func _should_run_runtime() -> bool:
	return not Engine.is_editor_hint()


func _sync_processing() -> void:
	set_process(_runtime_initialized and enabled and _should_run_runtime())


func _create_canvas_viewport(viewport_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = Vector2i(resolution, resolution)
	# Empty impulse/simulation pixels must sample as zero, not the project clear color.
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	return viewport


func _add_full_viewport_rect(viewport: SubViewport, material: Material, visible: bool) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.position = Vector2.ZERO
	texture_rect.size = Vector2(resolution, resolution)
	texture_rect.texture = _white_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.material = material
	texture_rect.visible = visible
	viewport.add_child(texture_rect)
	return texture_rect


func _request_viewport_update_once(viewport: SubViewport) -> void:
	if viewport == null:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _get_active_boundary_texture() -> Texture2D:
	if _boundary_texture != null:
		return _boundary_texture
	if require_boundary_mask:
		return _black_texture
	return _white_texture


func _create_solid_texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _refresh_target_rivers() -> void:
	var next_targets := []
	for path in target_river_paths:
		if path == NodePath(""):
			continue
		var target := get_node_or_null(path)
		if _is_valid_ripple_target(target) and not next_targets.has(target):
			next_targets.append(target)

	if not target_group_name.is_empty() and is_inside_tree():
		for target in get_tree().get_nodes_in_group(target_group_name):
			if _is_valid_ripple_target(target) and not next_targets.has(target):
				next_targets.append(target)

	for target in _registered_targets:
		if _is_valid_ripple_target(target) and not next_targets.has(target):
			next_targets.append(target)

	for applied in _applied_targets.duplicate():
		if not next_targets.has(applied):
			_clear_material_state_for_target(applied)
	_target_rivers = next_targets


func _is_valid_ripple_target(target: Variant) -> bool:
	return target is Node and target.has_method("apply_runtime_ripple_material_state") and target.has_method("clear_runtime_ripple_material_state")


func _apply_material_state_to_targets() -> void:
	if not _runtime_initialized or not enabled:
		return
	if require_boundary_mask and not _boundary_valid:
		_clear_target_material_state()
		return
	_refresh_target_rivers()
	var parameters := _make_material_state()
	for target in _target_rivers:
		_apply_material_state_to_target(target, parameters)


func _apply_material_state_to_target(target: Node, parameters: Dictionary) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var accepted := bool(target.call("apply_runtime_ripple_material_state", self, parameters))
	if accepted and not _applied_targets.has(target):
		_applied_targets.append(target)
	return accepted


func _clear_target_material_state() -> void:
	for target in _applied_targets.duplicate():
		_clear_material_state_for_target(target)
	_applied_targets.clear()


func _clear_material_state_for_target(target: Node) -> void:
	if target != null and is_instance_valid(target) and target.has_method("clear_runtime_ripple_material_state"):
		target.call("clear_runtime_ripple_material_state", self)
	_applied_targets.erase(target)


func _make_material_state() -> Dictionary:
	var current_texture := get_current_ripple_texture()
	if current_texture == null:
		current_texture = _neutral_texture
	var impulse_texture := get_impulse_texture()
	if impulse_texture == null:
		impulse_texture = _black_texture
	return {
		"i_ripple_enabled": enabled and _runtime_initialized and (not require_boundary_mask or _boundary_valid),
		"i_ripple_simulation_texture": current_texture,
		"i_ripple_impulse_texture": impulse_texture,
		"i_ripple_world_to_uv": _world_to_ripple_uv,
		"i_ripple_boundary_mask": _get_active_boundary_texture(),
		"i_ripple_texel_size": Vector2.ONE / float(max(resolution, 1)),
		"i_ripple_normal_strength": normal_strength,
		"i_ripple_refraction_strength": refraction_strength,
		"i_ripple_displacement_strength": displacement_strength,
		"i_ripple_height_fade_distance": height_fade_distance,
		"i_ripple_boundary_fade": boundary_fade,
	}


func _get_target_mesh_instances() -> Array:
	var meshes := []
	for path in boundary_source_paths:
		if path == NodePath(""):
			continue
		var source := get_node_or_null(path)
		var source_mesh := _get_target_mesh_instance(source)
		if source_mesh != null and source_mesh.mesh != null and not meshes.has(source_mesh):
			meshes.append(source_mesh)
	for target in _target_rivers:
		var mesh_instance := _get_target_mesh_instance(target)
		if mesh_instance != null and mesh_instance.mesh != null and not meshes.has(mesh_instance):
			meshes.append(mesh_instance)
	return meshes


func _get_target_mesh_instance(target: Node) -> MeshInstance3D:
	if target is MeshInstance3D:
		return target as MeshInstance3D
	if target == null:
		return null
	var value = target.get("mesh_instance")
	return value as MeshInstance3D


func _build_normalized_footprint_mesh(source: MeshInstance3D) -> Mesh:
	var normalized_mesh := ArrayMesh.new()
	if source == null or source.mesh == null:
		return normalized_mesh

	var source_transform := source.global_transform if source.is_inside_tree() else source.transform
	for surface_index in range(source.mesh.get_surface_count()):
		var primitive: Mesh.PrimitiveType = source.mesh.surface_get_primitive_type(surface_index)
		var arrays := source.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue
		var mapped_vertices := PackedVector3Array()
		var mapped_normals := PackedVector3Array()
		for vertex in vertices:
			var world_vertex: Vector3 = source_transform * vertex
			var mapped: Vector3 = _world_to_ripple_uv * world_vertex
			mapped_vertices.append(Vector3(mapped.x, 0.0, mapped.z))
			mapped_normals.append(Vector3.UP)
		arrays[Mesh.ARRAY_VERTEX] = mapped_vertices
		arrays[Mesh.ARRAY_NORMAL] = mapped_normals
		normalized_mesh.add_surface_from_arrays(primitive, arrays)
	return normalized_mesh


func _sort_impulses_by_priority(a: Dictionary, b: Dictionary) -> bool:
	var a_priority := int(a.get("priority", 0))
	var b_priority := int(b.get("priority", 0))
	if a_priority == b_priority:
		return float(a.get("intensity", 0.0)) > float(b.get("intensity", 0.0))
	return a_priority > b_priority


func _uv_is_in_bounds(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 1.0 and uv.y <= 1.0
