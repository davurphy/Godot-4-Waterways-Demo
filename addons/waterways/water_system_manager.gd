# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Node3D

const SystemMapRenderer = preload("res://addons/waterways/system_map_renderer.tscn")
const FilterRenderer = preload("res://addons/waterways/filter_renderer.tscn")
const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")
const RiverManager = preload("res://addons/waterways/river_manager.gd")
const WaterSystemBakeDataResource = preload("res://addons/waterways/resources/water_system_bake_data.gd")

const SYSTEM_COVERAGE_THRESHOLD := 0.001
const SYSTEM_BAKE_RESOLUTION_MIN := 0
const SYSTEM_BAKE_RESOLUTION_MAX := 4
const SYSTEM_BAKE_TEXTURE_SIZE_MIN := 128
const SYSTEM_BAKE_TEXTURE_SIZE_MAX := 2048

var system_map : Texture2D = null
var bake_data : Resource = null
var system_bake_resolution := 2:
	set(value):
		system_bake_resolution = _sanitize_int_range("system_bake_resolution", value, SYSTEM_BAKE_RESOLUTION_MIN, SYSTEM_BAKE_RESOLUTION_MAX, 2)
var system_group_name: String = "waterways_system":
	set(value):
		system_group_name = String(value).strip_edges()
		_sync_system_group_membership()
var minimum_water_level := 0.0
# Auto assign
var wet_group_name: String = "waterways_wet":
	set(value):
		wet_group_name = String(value).strip_edges()
var surface_index : int = -1
var material_override : bool = false

var _system_aabb : AABB
var _system_img : Image
var _first_enter_tree := true
var _active_system_group_name := StringName()
var _system_bake_in_progress := false

func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false
	_sync_system_group_membership()


func _ready() -> void:
	if bake_data != null:
		_apply_bake_data()
		# R2.4: editor sessions surface this via configuration warnings; at
		# runtime nothing else would say the loaded map predates the current
		# system_flow shader output.
		if not Engine.is_editor_hint():
			var flow_version_warning := _get_system_flow_version_warning()
			if not flow_version_warning.is_empty():
				push_warning(flow_version_warning)
	elif system_map != null:
		_refresh_system_image()
	elif not Engine.is_editor_hint():
		push_warning("No WaterSystem map!")


func _exit_tree() -> void:
	_clear_system_group_membership()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if system_map == null:
		warnings.append("No System Map is set. Select WaterSystem -> Generate System Map to generate and assign one.")
	elif _has_unsaved_generated_system_map():
		warnings.append("Generated WaterSystem map is not stored in an external .res bake resource. Save the scene, then rebake before running with F6 or exporting.")
	else:
		var stale_source_warning := _get_stale_source_warning()
		if not stale_source_warning.is_empty():
			warnings.append(stale_source_warning)
	if system_group_name.is_empty():
		warnings.append("System group name is empty; Buoyant nodes cannot discover this WaterSystem by group.")
	return warnings


func _get_property_list() -> Array:
	return [
		{
			name = "system_map",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Texture2D"
		},
		{
			name = "bake_data",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "WaterSystemBakeData"
		},
		{
			name = "system_bake_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "128, 256, 512, 1024, 2048",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "system_group_name",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "minimum_water_level",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Auto assign texture & coordinates on generate",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "wet_group_name",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "surface_index",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "material_override",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		# values that need to be serialized, but should not be exposed
		{
			name = "_system_aabb",
			type = TYPE_AABB,
			usage = PROPERTY_USAGE_STORAGE
		}
	]


func _set(property: StringName, value: Variant) -> bool:
	if String(property) == "bake_data":
		bake_data = value
		_apply_bake_data()
		return true
	return false


func _get(property: StringName) -> Variant:
	if String(property) == "bake_data":
		return bake_data
	return null


func is_bake_in_progress() -> bool:
	return _system_bake_in_progress


func generate_system_maps() -> void:
	if not _begin_system_bake_request():
		return
	var rivers := []

	for child in get_children():
		if child is RiverManager and _river_can_contribute_to_system_map(child):
			rivers.append(child)
	var resolution := _get_system_bake_texture_size()
	var preflight_failures := _get_system_bake_preflight_failures(rivers, resolution)
	if not preflight_failures.is_empty():
		push_warning("Cannot generate WaterSystem map: " + "; ".join(preflight_failures) + ".")
		_clear_system_bake_request()
		return
	
	# We need to make the aabb out of the first river, so we don't include 0,0
	_system_aabb = _get_mesh_global_aabb(rivers[0].mesh_instance)
	
	for river in rivers:
		var river_aabb = _get_mesh_global_aabb(river.mesh_instance)
		_system_aabb = _system_aabb.merge(river_aabb)
	if _system_aabb.size.x <= 0.0 or _system_aabb.size.z <= 0.0:
		push_warning("Cannot generate WaterSystem map: generated river bounds have no X/Z area.")
		_clear_system_bake_request()
		return
	
	var renderer = SystemMapRenderer.instantiate()
	if renderer == null:
		push_warning("Cannot generate WaterSystem map: system map renderer could not be instantiated.")
		_clear_system_bake_request()
		return
	add_child(renderer)
	var flow_map = await renderer.grab_flow(rivers, _system_aabb, resolution)
	if not _system_bake_texture_is_valid(flow_map, "flow map", renderer):
		return
	var height_map = await renderer.grab_height(rivers, _system_aabb, resolution)
	if not _system_bake_texture_is_valid(height_map, "height map", renderer):
		return
	var alpha_map = await renderer.grab_alpha(rivers, _system_aabb, resolution)
	if not _system_bake_texture_is_valid(alpha_map, "alpha map", renderer):
		return
	
	_cleanup_bake_renderer(renderer)
	
	var filter_renderer = FilterRenderer.instantiate()
	if filter_renderer == null:
		push_warning("Cannot generate WaterSystem map: filter renderer could not be instantiated.")
		_clear_system_bake_request()
		return
	add_child(filter_renderer)
	
	#var dilated_height = await filter_renderer.apply_dilate(alpha_map, 0.1, 1.0, resolution, height_map)
	var combined_map = await filter_renderer.apply_combine(flow_map, flow_map, height_map, alpha_map)
	if not _system_bake_texture_is_valid(combined_map, "combined system map", filter_renderer):
		return
	var system_map_diagnostics := _get_system_map_diagnostics(combined_map)
	_warn_on_system_map_coverage(system_map_diagnostics)
	set_system_map(combined_map)
	_write_bake_data(
		Vector2i(combined_map.get_width(), combined_map.get_height()),
		_get_source_river_paths(rivers),
		_get_source_river_metadata(rivers),
		system_map_diagnostics
	)
	var storage_result := WaterHelperMethods.save_water_system_bake_data(self, bake_data)
	_apply_bake_data()
	
	_cleanup_bake_renderer(filter_renderer)
	
	# give the map and coordinates to all nodes in the wet_group
	assign_system_map_to_wet_nodes()
	_print_bake_save_notice(Vector2i(combined_map.get_width(), combined_map.get_height()), rivers.size(), storage_result)
	update_configuration_warnings()
	_clear_system_bake_request()


func _system_bake_texture_is_valid(texture: Texture2D, label: String, renderer_instance: Node) -> bool:
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		return true
	push_warning("Cannot generate WaterSystem map: " + label + " render returned no readable image. Temporary renderer nodes were cleaned up.")
	_cleanup_bake_renderer(renderer_instance)
	_finish_system_bake_after_failure()
	return false


func _cleanup_bake_renderer(renderer_instance: Node) -> void:
	if renderer_instance == null:
		return
	if renderer_instance.get_parent() != null:
		renderer_instance.get_parent().remove_child(renderer_instance)
	renderer_instance.queue_free()


func _begin_system_bake_request() -> bool:
	if _system_bake_in_progress:
		push_warning("Waterways: WaterSystem map bake is already in progress; ignoring duplicate request.")
		return false
	_system_bake_in_progress = true
	return true


func _clear_system_bake_request() -> void:
	_system_bake_in_progress = false


func _finish_system_bake_after_failure() -> void:
	_clear_system_bake_request()
	update_configuration_warnings()


# Returns the vetical distance to the water, positive values above water level,
# negative numbers below the water
func get_water_altitude(query_pos : Vector3) -> float:
	var sample := _sample_system_map(query_pos)
	if not sample.valid:
		return query_pos.y - minimum_water_level
	
	var col: Color = sample.color
	var bounds := _get_system_bounds()
	var height = col.b * bounds.size.y + bounds.position.y
	return query_pos.y - height


# Returns the flow vector from the system flowmap
func get_water_flow(query_pos : Vector3) -> Vector3:
	var sample := _sample_system_map(query_pos)
	if not sample.valid:
		return Vector3.ZERO
	
	var col: Color = sample.color
	var flow = Vector3(col.r, 0.5, col.g) * 2.0 - Vector3(1.0, 1.0, 1.0)
	return flow


func get_system_map() -> Texture2D:
	return system_map


func get_system_map_coordinates() -> Transform3D:
	# storing the AABB info in a transform, seems dodgy
	var offset = Transform3D(_system_aabb.position, _system_aabb.size, _system_aabb.end, Vector3())
	return offset


func set_system_map(texture : Texture2D) -> void:
	system_map = texture
	_refresh_system_image()
	if _first_enter_tree:
		return
	notify_property_list_changed()
	update_configuration_warnings()


func assign_system_map_to_wet_nodes() -> Dictionary:
	return _assign_system_map_to_wet_nodes()


func validate_generated_map_sampling() -> bool:
	if system_map != null:
		_refresh_system_image()
	elif bake_data != null:
		_apply_bake_data()
	if _system_img == null:
		push_warning("WATER_SYSTEM_GENERATED_MAP_TEST: no generated system map image is available.")
		return false
	var rivers := []
	for child in get_children():
		if child is RiverManager and _river_can_contribute_to_system_map(child):
			rivers.append(child)
	if rivers.is_empty():
		push_warning("WATER_SYSTEM_GENERATED_MAP_TEST: no generated child River mesh is available to sample against.")
		return false
	var river_samples := []
	var min_samples_per_river := _get_min_validation_samples_per_river()
	var total_coverage_samples := 0
	for river in rivers:
		var coverage_samples := _find_covered_samples_near_river(river, min_samples_per_river)
		if coverage_samples.is_empty():
			push_warning("WATER_SYSTEM_GENERATED_MAP_TEST: no covered system-map pixel was found near " + str(river.get_path()) + ".")
			return false
		if coverage_samples.size() < min_samples_per_river:
			push_warning(
				"WATER_SYSTEM_GENERATED_MAP_TEST: only "
				+ str(coverage_samples.size())
				+ " covered system-map mesh sample(s) were found for "
				+ str(river.get_path())
				+ "; expected at least "
				+ str(min_samples_per_river)
				+ ". samples="
				+ _get_map_sample_summary(coverage_samples)
			)
			return false
		total_coverage_samples += coverage_samples.size()
		var river_sample := _get_representative_coverage_sample(coverage_samples)
		var sample_pos: Vector3 = river_sample.position
		river_sample.river = river
		river_sample.coverage_sample_count = coverage_samples.size()
		river_sample.coverage_samples = coverage_samples
		river_sample.altitude = get_water_altitude(sample_pos)
		river_sample.flow = get_water_flow(sample_pos)
		river_samples.append(river_sample)
	
	var source_path_error := _get_source_path_validation_error(rivers)
	if source_path_error != "":
		push_warning(source_path_error)
		return false
	
	var distinct_flow_error := _get_distinct_flow_validation_error(river_samples)
	if distinct_flow_error != "":
		push_warning(distinct_flow_error)
		return false
	
	var expected_flow_error := _get_expected_flow_validation_error(river_samples)
	if expected_flow_error != "":
		push_warning(expected_flow_error)
		return false
	
	var wet_target_error := _get_wet_target_assignment_validation_error()
	if wet_target_error != "":
		push_warning(wet_target_error)
		return false
	
	var outside_pos := _get_outside_system_sample_position()
	var outside_altitude := get_water_altitude(outside_pos)
	var outside_flow := get_water_flow(outside_pos)
	var outside_altitude_ok := absf(outside_altitude - (outside_pos.y - minimum_water_level)) < 0.01
	var outside_flow_ok := outside_flow.distance_squared_to(Vector3.ZERO) < 0.0001
	var edge_pos := _get_max_edge_system_sample_position()
	var edge_altitude := get_water_altitude(edge_pos)
	var edge_flow := get_water_flow(edge_pos)
	if not outside_altitude_ok or not outside_flow_ok:
		push_warning("WATER_SYSTEM_GENERATED_MAP_TEST: outside fallback failed. altitude=" + str(outside_altitude) + " flow=" + str(outside_flow))
		return false
	var alpha_flow_stats := WaterHelperMethods.get_decoded_flow_vector_stats(
		_system_img,
		Rect2i(),
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
		SYSTEM_COVERAGE_THRESHOLD
	)
	print(
		"WATER_SYSTEM_GENERATED_MAP_TEST: ",
		river_samples.size(),
		" river sample(s) passed; ",
		_get_river_sample_summary(river_samples),
		_get_coverage_sample_pass_suffix(min_samples_per_river, total_coverage_samples),
		_get_wet_target_assignment_pass_suffix(),
		"; outside fallback passed at ",
		outside_pos,
		"; max-edge sampled without error altitude=",
		edge_altitude,
		" flow=",
		edge_flow,
		"; ",
		WaterHelperMethods.format_decoded_flow_vector_stats("alpha_covered_flow", alpha_flow_stats),
		"."
	)
	return true


func _river_can_contribute_to_system_map(river) -> bool:
	if river.mesh_instance == null:
		push_warning("Skipping WaterSystem bake source without a RiverMeshInstance: " + _get_node_warning_label(river))
		return false
	if river.mesh_instance.mesh == null:
		push_warning("Skipping WaterSystem bake source with an empty RiverMeshInstance mesh: " + _get_node_warning_label(river))
		return false
	if river.mesh_instance.mesh.get_surface_count() < 1:
		push_warning("Skipping WaterSystem bake source with no mesh surfaces: " + _get_node_warning_label(river))
		return false
	return true


func _get_system_bake_preflight_failures(rivers: Array, resolution: int) -> PackedStringArray:
	var failures := PackedStringArray()
	if rivers.is_empty():
		failures.append("no child River nodes have generated meshes")
	if system_bake_resolution < SYSTEM_BAKE_RESOLUTION_MIN or system_bake_resolution > SYSTEM_BAKE_RESOLUTION_MAX:
		failures.append("system_bake_resolution must be between " + str(SYSTEM_BAKE_RESOLUTION_MIN) + " and " + str(SYSTEM_BAKE_RESOLUTION_MAX))
	if resolution < SYSTEM_BAKE_TEXTURE_SIZE_MIN or resolution > SYSTEM_BAKE_TEXTURE_SIZE_MAX:
		failures.append("system_bake_resolution produced an invalid texture size")
	for river in rivers:
		var river_label := _get_node_warning_label(river)
		if river.flow_foam_noise == null:
			failures.append(river_label + " has no flow/foam/noise texture; run River -> Generate Flow & Foam Map first")
		if river.dist_pressure == null:
			failures.append(river_label + " has no distance/pressure texture; run River -> Generate Flow & Foam Map first")
		if not river.valid_flowmap:
			failures.append(river_label + " flow map is marked invalid; regenerate the River map")
	return failures


func _get_system_bake_texture_size() -> int:
	var safe_resolution := _sanitize_int_range("system_bake_resolution", system_bake_resolution, SYSTEM_BAKE_RESOLUTION_MIN, SYSTEM_BAKE_RESOLUTION_MAX, 2)
	if safe_resolution != system_bake_resolution:
		system_bake_resolution = safe_resolution
	return int(pow(2, safe_resolution + 7))


func _sanitize_int_range(property_name: String, value: Variant, min_value: int, max_value: int, fallback_value: int) -> int:
	var numeric_value := fallback_value
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		if is_nan(float_value) or is_inf(float_value):
			push_warning("Waterways: " + property_name + " had unsafe value " + str(value) + "; using " + str(fallback_value) + " instead.")
			return fallback_value
		numeric_value = int(round(float_value))
	else:
		numeric_value = int(value)
	var sanitized_value: int = clamp(numeric_value, min_value, max_value)
	if numeric_value != sanitized_value:
		push_warning("Waterways: " + property_name + " had unsafe value " + str(value) + "; using " + str(sanitized_value) + " instead.")
	return sanitized_value


func _get_node_warning_label(node: Node) -> String:
	if node == null:
		return "<null>"
	if node == self:
		return name
	if is_ancestor_of(node):
		return str(get_path_to(node))
	if node.owner != null and node.owner.is_ancestor_of(node):
		return str(node.owner.get_path_to(node))
	if is_inside_tree() and Engine.is_editor_hint():
		var edited_scene_root := get_tree().get_edited_scene_root()
		if edited_scene_root != null and edited_scene_root.is_ancestor_of(node):
			return str(edited_scene_root.get_path_to(node))
	return str(node.get_path())


func _assign_system_map_to_wet_nodes() -> Dictionary:
	var result := {
		"assigned_count": 0,
		"skipped_count": 0,
		"wet_group_name": wet_group_name
	}
	if not is_inside_tree() or wet_group_name.is_empty():
		return result
	var wet_nodes = get_tree().get_nodes_in_group(wet_group_name)
	for node in wet_nodes:
		var material := _get_wet_node_shader_material(node)
		if material == null:
			result["skipped_count"] += 1
			continue
		material.set_shader_parameter("water_systemmap", system_map)
		material.set_shader_parameter("water_systemmap_coords", get_system_map_coordinates())
		result["assigned_count"] += 1
	return result


func _get_wet_node_shader_material(node: Node, warn := true) -> ShaderMaterial:
	if not (node is MeshInstance3D):
		_push_wet_target_warning("Skipping WaterSystem wet target that is not a MeshInstance3D: " + str(node.get_path()), warn)
		return null
	var mesh_node := node as MeshInstance3D
	var material: Material = null
	if material_override:
		material = mesh_node.material_override
	elif surface_index >= 0:
		if mesh_node.mesh == null:
			_push_wet_target_warning("Skipping WaterSystem wet target with no mesh: " + str(node.get_path()), warn)
			return null
		if surface_index >= mesh_node.mesh.get_surface_count():
			_push_wet_target_warning("Skipping WaterSystem wet target surface " + str(surface_index) + " because the mesh has only " + str(mesh_node.mesh.get_surface_count()) + " surfaces: " + str(node.get_path()), warn)
			return null
		material = mesh_node.get_active_material(surface_index)
	else:
		return null
	if material == null:
		_push_wet_target_warning("Skipping WaterSystem wet target with no material to update: " + str(node.get_path()), warn)
		return null
	if not (material is ShaderMaterial):
		_push_wet_target_warning("Skipping WaterSystem wet target with a non-ShaderMaterial material: " + str(node.get_path()), warn)
		return null
	return material as ShaderMaterial


func _push_wet_target_warning(message: String, warn: bool) -> void:
	if warn:
		push_warning(message)


func _sync_system_group_membership() -> void:
	if not is_inside_tree():
		return
	var desired_group := StringName(system_group_name)
	if desired_group == _active_system_group_name:
		if not String(desired_group).is_empty() and not is_in_group(desired_group):
			add_to_group(desired_group)
		return
	_clear_system_group_membership()
	if not String(desired_group).is_empty():
		add_to_group(desired_group)
		_active_system_group_name = desired_group


func _clear_system_group_membership() -> void:
	if String(_active_system_group_name).is_empty():
		return
	remove_from_group(_active_system_group_name)
	_active_system_group_name = StringName()


func _get_mesh_global_aabb(instance: MeshInstance3D) -> AABB:
	if instance == null:
		return AABB()
	return instance.global_transform * instance.get_aabb()


func _ensure_bake_data() -> Resource:
	if bake_data == null:
		bake_data = WaterSystemBakeDataResource.new()
	return bake_data


func _apply_bake_data() -> void:
	if bake_data == null:
		return
	var resource_system_map = bake_data.get("system_map") as Texture2D
	if resource_system_map != null:
		system_map = resource_system_map
	var resource_bounds = bake_data.get("world_bounds")
	if typeof(resource_bounds) == TYPE_AABB:
		_system_aabb = resource_bounds
	if bake_data.has_method("refresh_sampling_image"):
		bake_data.call("refresh_sampling_image")
	if bake_data.has_method("get_sampling_image"):
		_system_img = bake_data.call("get_sampling_image")
	else:
		_refresh_system_image()
	if is_inside_tree():
		update_configuration_warnings()


func _write_bake_data(texture_size: Vector2i, source_river_paths: PackedStringArray, source_river_metadata: Array, system_map_diagnostics: Dictionary) -> void:
	var data := _ensure_bake_data()
	var source_metadata := {
		"system_map_diagnostics": system_map_diagnostics.duplicate(true),
		"supported_future_source_kinds": PackedStringArray([
			"generated_water_system_combine",
			"imported_linear_system_map",
			"hand_painted_flow_height_coverage_map",
			"dcc_or_simulation_system_map",
			"shore_distance_or_obstacle_influence_map"
		])
	}
	if data.has_method("set_from_bake"):
		data.call(
			"set_from_bake",
			system_map,
			texture_size,
			_system_aabb,
			source_river_paths,
			_get_bake_settings(system_map_diagnostics),
			WaterSystemBakeDataResource.SOURCE_KIND_WATER_SYSTEM_COMBINE,
			source_metadata,
			source_river_metadata
		)
	if data.has_method("get_sampling_image"):
		_system_img = data.call("get_sampling_image")
	if Engine.is_editor_hint():
		notify_property_list_changed()


func _has_unsaved_generated_system_map() -> bool:
	if system_map == null:
		return false
	return not WaterHelperMethods.has_external_bake_path(bake_data)


func _print_bake_save_notice(texture_size: Vector2i, river_count: int, storage_result: Dictionary = {}) -> void:
	if not Engine.is_editor_hint():
		return
	if bool(storage_result.get("saved", false)):
		print(
			"Waterways: WaterSystem maps saved to external bake resource ",
			String(storage_result.get("path", "")),
			". Save the scene once so F6/export serializes this reference. system_map=",
			_texture_size_label(system_map, texture_size),
			" source_rivers=",
			river_count,
			" bounds=",
			_system_aabb,
			"."
		)
		return
	if bool(storage_result.get("requires_saved_scene", false)):
		print(
			"Waterways: WaterSystem maps regenerated in editor memory because this scene has no saved path. Save the scene, then rebake to create scene-owned external .res storage before F6/export. system_map=",
			_texture_size_label(system_map, texture_size),
			" source_rivers=",
			river_count,
			" bounds=",
			_system_aabb,
			"."
		)
		return
	var error_code := int(storage_result.get("error", OK))
	if error_code != OK:
		push_warning("Waterways: WaterSystem maps regenerated, but external .res storage failed. " + String(storage_result.get("message", "")) + " Error code: " + str(error_code) + ".")
		return
	print(
		"Waterways: WaterSystem maps regenerated in editor memory. Save the scene before F6/export so runtime and Buoyant nodes use this data. system_map=",
		_texture_size_label(system_map, texture_size),
		" source_rivers=",
		river_count,
		" bounds=",
		_system_aabb,
		"."
	)


func _texture_size_label(texture: Texture2D, fallback_size: Vector2i = Vector2i.ZERO) -> String:
	if texture != null:
		return str(texture.get_width()) + "x" + str(texture.get_height())
	if fallback_size != Vector2i.ZERO:
		return str(fallback_size.x) + "x" + str(fallback_size.y)
	return "<none>"


func _refresh_system_image() -> void:
	if system_map == null:
		_system_img = null
		return
	_system_img = system_map.get_image()


func _get_source_river_paths(rivers: Array) -> PackedStringArray:
	var source_paths := PackedStringArray()
	for river in rivers:
		if river is Node:
			var river_node := river as Node
			source_paths.append(_get_source_river_path(river_node))
	return source_paths


func _get_source_river_path(river_node: Node) -> String:
	if river_node == null:
		return ""
	if is_inside_tree() and river_node.is_inside_tree():
		return str(get_path_to(river_node))
	return river_node.name


func _get_child_rivers() -> Array:
	var rivers := []
	for child in get_children():
		if child is RiverManager:
			rivers.append(child)
	return rivers


func _get_source_river_metadata(rivers: Array) -> Array:
	var metadata := []
	for river in rivers:
		if river is Node:
			metadata.append(_get_source_river_metadata_entry(river as Node))
	return metadata


func _get_source_river_metadata_entry(river_node: Node) -> Dictionary:
	var river_bake_data := river_node.get("bake_data") as Resource
	var source_signature := {}
	if river_node.has_method("get_bake_source_signature"):
		var signature = river_node.call("get_bake_source_signature")
		if typeof(signature) == TYPE_DICTIONARY:
			source_signature = signature.duplicate(true)
	return {
		"path": _get_source_river_path(river_node),
		"bake_resource_path": _get_resource_path(river_bake_data),
		"has_external_bake_path": WaterHelperMethods.has_external_bake_path(river_bake_data),
		"source_signature": source_signature,
		"bake_data_source_signature": _get_bake_data_dictionary(river_bake_data, "source_signature"),
		"flow_foam_noise_size": _get_texture_size(river_node.get("flow_foam_noise") as Texture2D),
		"dist_pressure_size": _get_texture_size(river_node.get("dist_pressure") as Texture2D),
		"flow_foam_noise_path": _get_texture_resource_path(river_node.get("flow_foam_noise") as Texture2D),
		"dist_pressure_path": _get_texture_resource_path(river_node.get("dist_pressure") as Texture2D),
		"texture_size": _get_bake_data_vector2i(river_bake_data, "texture_size"),
		"source_texture_size": _get_bake_data_vector2i(river_bake_data, "source_texture_size"),
		"uv2_sides": _get_bake_data_int(river_bake_data, "uv2_sides"),
		"valid_flowmap": bool(river_node.get("valid_flowmap")),
		"bake_settings": _get_bake_data_dictionary(river_bake_data, "bake_settings"),
		"source_metadata": _get_bake_data_dictionary(river_bake_data, "source_metadata")
	}


func _get_stale_source_warning() -> String:
	if bake_data == null or system_map == null:
		return ""
	var stored_source_kind = bake_data.get("source_kind")
	if typeof(stored_source_kind) == TYPE_STRING and String(stored_source_kind) != WaterSystemBakeDataResource.SOURCE_KIND_WATER_SYSTEM_COMBINE:
		return ""
	var stored_capture_rect = bake_data.get("capture_rect")
	if typeof(stored_capture_rect) != TYPE_RECT2 or not _has_valid_capture_rect(stored_capture_rect):
		return "WaterSystem map is stale because capture metadata is missing. Select WaterSystem -> Generate System Map to rebuild it."
	var stored_version = bake_data.get("source_river_metadata_version")
	if typeof(stored_version) != TYPE_INT or int(stored_version) != WaterSystemBakeDataResource.SOURCE_RIVER_METADATA_VERSION:
		return "WaterSystem map is stale because child River source metadata is missing. Select WaterSystem -> Generate System Map to rebuild it."
	var flow_version_warning := _get_system_flow_version_warning()
	if not flow_version_warning.is_empty():
		return flow_version_warning
	var stored_metadata = bake_data.get("source_river_metadata")
	if typeof(stored_metadata) != TYPE_ARRAY or stored_metadata.is_empty():
		return "WaterSystem map is stale because child River source metadata is missing. Select WaterSystem -> Generate System Map to rebuild it."
	var current_metadata := _get_source_river_metadata(_get_child_rivers())
	var mismatch := _get_source_river_metadata_mismatch(stored_metadata, current_metadata)
	if mismatch.is_empty():
		return ""
	return "WaterSystem map is stale because " + mismatch + ". Select WaterSystem -> Generate System Map to rebuild it."


# System maps have no bake-source signature; this version int (stored in
# bake_settings by _get_bake_settings) is their staleness signal for
# system_flow.gdshader output changes. R2.4 (2026-06-12). Missing key reads
# as 0, so every pre-versioning map warns.
func _get_system_flow_version_warning() -> String:
	if bake_data == null or system_map == null:
		return ""
	var stored_settings = bake_data.get("bake_settings")
	var stored_flow_version := 0
	if typeof(stored_settings) == TYPE_DICTIONARY:
		stored_flow_version = int((stored_settings as Dictionary).get("system_flow_map_version", 0))
	if stored_flow_version == WaterSystemBakeDataResource.SYSTEM_FLOW_MAP_VERSION:
		return ""
	return (
		"WaterSystem map was generated by an older system flow shader (map v"
		+ str(stored_flow_version) + " < current v"
		+ str(WaterSystemBakeDataResource.SYSTEM_FLOW_MAP_VERSION)
		+ "); buoyancy reads outdated flow near obstacles. Select WaterSystem -> Generate System Map to rebuild it."
	)


func _get_source_river_metadata_mismatch(stored_metadata: Array, current_metadata: Array) -> String:
	if stored_metadata.size() != current_metadata.size():
		return "the child River source count changed from " + str(stored_metadata.size()) + " to " + str(current_metadata.size())
	var stored_by_path := {}
	for stored_entry in stored_metadata:
		if typeof(stored_entry) != TYPE_DICTIONARY:
			return "stored child River source metadata is malformed"
		var stored_path := String(stored_entry.get("path", ""))
		if stored_path.is_empty():
			return "stored child River source metadata has no WaterSystem-relative path"
		stored_by_path[stored_path] = stored_entry
	for current_entry in current_metadata:
		if typeof(current_entry) != TYPE_DICTIONARY:
			return "current child River source metadata is malformed"
		var current_path := String(current_entry.get("path", ""))
		if current_path.is_empty():
			return "a current child River has no WaterSystem-relative path"
		if not stored_by_path.has(current_path):
			return "child River " + current_path + " was added, removed, or renamed"
		var changed_key := _get_source_river_metadata_changed_key(stored_by_path[current_path], current_entry)
		if not changed_key.is_empty():
			return "child River " + current_path + " " + changed_key + " changed"
	return ""


func _get_source_river_metadata_changed_key(stored_entry: Dictionary, current_entry: Dictionary) -> String:
	# flow_foam_noise_path / dist_pressure_path are collected for diagnostics
	# but deliberately NOT compared (2026-06-12): the textures' container
	# flips between contexts - an editor session saves scene-embedded copies
	# (res://<scene>::ImageTexture_x) while a fresh load binds the bake
	# resource's subresources (res://<bake>.res::ImageTexture_x) - and every
	# rebake regenerates subresource ids, so a raw path comparison reports
	# stale either falsely (context flip) or redundantly (rebakes already
	# change the compared signatures/sizes).
	var keys := PackedStringArray([
		"bake_resource_path",
		"has_external_bake_path",
		"source_signature",
		"bake_data_source_signature",
		"flow_foam_noise_size",
		"dist_pressure_size",
		"texture_size",
		"source_texture_size",
		"uv2_sides",
		"valid_flowmap",
		"bake_settings",
		"source_metadata"
	])
	for key in keys:
		if stored_entry.get(key) != current_entry.get(key):
			return _get_source_river_metadata_label(key)
	return ""


func _get_source_river_metadata_label(key: String) -> String:
	match key:
		"bake_resource_path":
			return "bake resource path"
		"has_external_bake_path":
			return "external bake storage state"
		"source_signature":
			return "geometry or bake-source signature"
		"bake_data_source_signature":
			return "stored River bake signature"
		"flow_foam_noise_size", "dist_pressure_size", "texture_size", "source_texture_size":
			return "bake texture size"
		"flow_foam_noise_path", "dist_pressure_path":
			return "bake texture resource path"
		"uv2_sides":
			return "UV2 side count"
		"valid_flowmap":
			return "valid bake state"
		"bake_settings":
			return "bake settings"
		"source_metadata":
			return "bake metadata"
	return key


func _get_bake_data_dictionary(bake_data_resource: Resource, property_name: String) -> Dictionary:
	if bake_data_resource == null:
		return {}
	var value = bake_data_resource.get(property_name)
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value.duplicate(true)


func _get_bake_data_vector2i(bake_data_resource: Resource, property_name: String) -> Vector2i:
	if bake_data_resource == null:
		return Vector2i.ZERO
	var value = bake_data_resource.get(property_name)
	if typeof(value) != TYPE_VECTOR2I:
		return Vector2i.ZERO
	return value


func _get_bake_data_int(bake_data_resource: Resource, property_name: String) -> int:
	if bake_data_resource == null:
		return 0
	var value = bake_data_resource.get(property_name)
	if typeof(value) != TYPE_INT:
		return 0
	return int(value)


func _get_resource_path(resource: Resource) -> String:
	if resource == null:
		return ""
	return resource.resource_path


func _get_texture_size(texture: Texture2D) -> Vector2i:
	if texture == null:
		return Vector2i.ZERO
	return Vector2i(texture.get_width(), texture.get_height())


func _get_texture_resource_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return texture.resource_path


func _get_bake_settings(system_map_diagnostics: Dictionary = {}) -> Dictionary:
	var settings := {
		"system_flow_map_version": WaterSystemBakeDataResource.SYSTEM_FLOW_MAP_VERSION,
		"system_bake_resolution": system_bake_resolution,
		"system_group_name": system_group_name,
		"minimum_water_level": minimum_water_level,
		"wet_group_name": wet_group_name,
		"surface_index": surface_index,
		"material_override": material_override
	}
	if not system_map_diagnostics.is_empty():
		settings["system_map_diagnostics"] = system_map_diagnostics
	return settings


func _get_system_map_diagnostics(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var image := texture.get_image()
	if image == null:
		return {}
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return {}
	var min_values := [INF, INF, INF, INF]
	var max_values := [-INF, -INF, -INF, -INF]
	var sums := [0.0, 0.0, 0.0, 0.0]
	for y in height:
		for x in width:
			var col := image.get_pixel(x, y)
			var values := [col.r, col.g, col.b, col.a]
			for channel in values.size():
				min_values[channel] = min(min_values[channel], values[channel])
				max_values[channel] = max(max_values[channel], values[channel])
				sums[channel] += values[channel]
	var count := float(width * height)
	var names := ["r", "g", "b", "a"]
	var diagnostics := {
		"texture_size": Vector2i(width, height)
	}
	for channel in names.size():
		diagnostics[names[channel]] = {
			"min": min_values[channel],
			"max": max_values[channel],
			"average": sums[channel] / count,
			"range": max_values[channel] - min_values[channel]
		}
	diagnostics["alpha_covered_flow"] = WaterHelperMethods.get_decoded_flow_vector_stats(
		image,
		Rect2i(),
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
		SYSTEM_COVERAGE_THRESHOLD
	)
	return diagnostics


func _warn_on_system_map_coverage(system_map_diagnostics: Dictionary) -> void:
	if system_map_diagnostics.is_empty() or not system_map_diagnostics.has("a"):
		return
	var coverage = system_map_diagnostics["a"]
	var coverage_min := float(coverage.get("min", 0.0))
	var coverage_max := float(coverage.get("max", 0.0))
	if coverage_max <= SYSTEM_COVERAGE_THRESHOLD:
		push_warning("WaterSystem system map coverage channel is empty; check alpha render/combine output or river mesh visibility.")
	elif coverage_min >= 1.0 - SYSTEM_COVERAGE_THRESHOLD:
		push_warning("WaterSystem system map coverage channel is full; check whether the alpha render/combine pass is covering the whole map.")


func _find_covered_samples_near_river(river, target_count: int) -> Array:
	target_count = max(target_count, 1)
	var mesh_samples := _find_covered_samples_on_river_mesh(river, target_count)
	if mesh_samples.size() >= target_count:
		return mesh_samples
	var mesh_sample := _find_covered_sample_on_river_mesh(river)
	if mesh_sample.valid:
		_append_unique_map_sample(mesh_samples, mesh_sample, target_count)
	var river_aabb := _get_mesh_global_aabb(river.mesh_instance)
	if not _has_valid_bounds(river_aabb):
		return mesh_samples
	var samples_per_axis := 7
	var sample_y := river_aabb.end.y + 1.0
	for z_index in samples_per_axis:
		var z_ratio := float(z_index) / float(samples_per_axis - 1)
		for x_index in samples_per_axis:
			var x_ratio := float(x_index) / float(samples_per_axis - 1)
			var sample_pos := Vector3(
				lerpf(river_aabb.position.x, river_aabb.end.x, x_ratio),
				sample_y,
				lerpf(river_aabb.position.z, river_aabb.end.z, z_ratio)
			)
			var sample := _sample_system_map(sample_pos)
			if sample.valid:
				var candidate := {
					valid = true,
					position = sample_pos,
					color = sample.color,
					uv = sample.get("uv", Vector2(-1.0, -1.0)),
					pixel = sample.get("pixel", Vector2i(-1, -1)),
					source = "aabb_grid"
				}
				if _append_unique_map_sample(mesh_samples, candidate, target_count):
					return mesh_samples
	return mesh_samples


func _find_covered_sample_on_river_mesh(river) -> Dictionary:
	var samples := _find_covered_samples_on_river_mesh(river, 1)
	if not samples.is_empty():
		return samples[0]
	return {
		valid = false
	}


func _find_covered_samples_on_river_mesh(river, target_count: int) -> Array:
	target_count = max(target_count, 1)
	var selected_samples := []
	if river == null or river.mesh_instance == null:
		return selected_samples
	var mesh: Mesh = river.mesh_instance.mesh
	if mesh == null or mesh.get_surface_count() <= 0:
		return selected_samples
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_VERTEX:
		return selected_samples
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() <= 0:
		return selected_samples
	var river_aabb := _get_mesh_global_aabb(river.mesh_instance)
	var sample_y := river_aabb.end.y + 1.0
	var transform: Transform3D = river.mesh_instance.global_transform
	var candidates := []
	for tri_start in range(0, vertices.size() - 2, 3):
		var sample_pos: Vector3 = (
			transform * vertices[tri_start]
			+ transform * vertices[tri_start + 1]
			+ transform * vertices[tri_start + 2]
		) / 3.0
		sample_pos.y = sample_y
		var sample := _sample_system_map(sample_pos)
		if sample.valid:
			candidates.append({
				valid = true,
				position = sample_pos,
				color = sample.color,
				uv = sample.get("uv", Vector2(-1.0, -1.0)),
				pixel = sample.get("pixel", Vector2i(-1, -1)),
				source = "mesh_triangle"
			})
	selected_samples = _select_spread_map_samples(candidates, target_count)
	if selected_samples.size() >= target_count:
		return selected_samples
	
	for vertex in vertices:
		var sample_pos: Vector3 = transform * vertex
		sample_pos.y = sample_y
		var sample := _sample_system_map(sample_pos)
		if sample.valid:
			var candidate := {
				valid = true,
				position = sample_pos,
				color = sample.color,
				uv = sample.get("uv", Vector2(-1.0, -1.0)),
				pixel = sample.get("pixel", Vector2i(-1, -1)),
				source = "mesh_vertex"
			}
			if _append_unique_map_sample(selected_samples, candidate, target_count):
				return selected_samples
	return selected_samples


func _select_spread_map_samples(candidates: Array, target_count: int) -> Array:
	var selected_samples := []
	if candidates.is_empty():
		return selected_samples
	target_count = max(target_count, 1)
	if target_count == 1:
		var middle_index := int(round(float(candidates.size() - 1) * 0.5))
		_append_unique_map_sample(selected_samples, candidates[middle_index], target_count)
		return selected_samples
	for sample_index in target_count:
		var ratio := float(sample_index) / float(target_count - 1)
		var candidate_index := clampi(int(round(ratio * float(candidates.size() - 1))), 0, candidates.size() - 1)
		if _append_unique_map_sample(selected_samples, candidates[candidate_index], target_count):
			return selected_samples
	for candidate in candidates:
		if _append_unique_map_sample(selected_samples, candidate, target_count):
			return selected_samples
	return selected_samples


func _append_unique_map_sample(samples: Array, candidate: Dictionary, target_count: int) -> bool:
	if not bool(candidate.get("valid", false)):
		return samples.size() >= target_count
	var candidate_pixel = candidate.get("pixel", Vector2i(-1, -1))
	for existing in samples:
		var existing_pixel = existing.get("pixel", Vector2i(-2, -2))
		if existing_pixel == candidate_pixel:
			return samples.size() >= target_count
	samples.append(candidate)
	return samples.size() >= target_count


func _get_representative_coverage_sample(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {
			valid = false
		}
	var representative_index := clampi(int(floor(float(samples.size()) * 0.5)), 0, samples.size() - 1)
	var sample = samples[representative_index]
	if typeof(sample) == TYPE_DICTIONARY:
		return sample.duplicate()
	return {
		valid = false
	}


func _get_outside_system_sample_position() -> Vector3:
	var bounds := _get_system_bounds()
	var margin := max(bounds.get_longest_axis_size() * 0.25, 1.0)
	return Vector3(
		bounds.end.x + margin,
		bounds.position.y + bounds.size.y + 1.0,
		bounds.position.z
	)


func _get_max_edge_system_sample_position() -> Vector3:
	var bounds := _get_system_bounds()
	return Vector3(
		bounds.end.x,
		bounds.position.y + bounds.size.y + 1.0,
		bounds.end.z
	)


func _sample_system_map(query_pos: Vector3) -> Dictionary:
	if _system_img == null:
		return {
			valid = false,
			color = Color(),
			uv = Vector2(-1.0, -1.0),
			pixel = Vector2i(-1, -1)
		}
	var uv := _world_position_to_map_uv(query_pos)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return {
			valid = false,
			color = Color(),
			uv = uv,
			pixel = Vector2i(-1, -1)
		}
	var width := _system_img.get_width()
	var height := _system_img.get_height()
	if width <= 0 or height <= 0:
		return {
			valid = false,
			color = Color(),
			uv = uv,
			pixel = Vector2i(-1, -1)
		}
	var pixel := Vector2i(
		clampi(int(floor(uv.x * float(width))), 0, width - 1),
		clampi(int(floor(uv.y * float(height))), 0, height - 1)
	)
	var col := _system_img.get_pixelv(pixel)
	if col.a <= SYSTEM_COVERAGE_THRESHOLD:
		return {
			valid = false,
			color = col,
			uv = uv,
			pixel = pixel
		}
	return {
		valid = true,
		color = col,
		uv = uv,
		pixel = pixel
	}


func _world_position_to_map_uv(query_pos: Vector3) -> Vector2:
	var bounds := _get_system_bounds()
	if _has_valid_bounds(bounds):
		var world_to_map = _get_world_to_map_transform(bounds)
		var map_pos: Vector3 = world_to_map * query_pos
		return Vector2(map_pos.x, map_pos.z)
	return Vector2(-1.0, -1.0)


func _get_system_bounds() -> AABB:
	if bake_data != null:
		var resource_bounds = bake_data.get("world_bounds")
		if typeof(resource_bounds) == TYPE_AABB and _has_valid_bounds(resource_bounds):
			return resource_bounds
	return _system_aabb


func _get_world_to_map_transform(bounds: AABB) -> Transform3D:
	if bake_data != null:
		var resource_bounds = bake_data.get("world_bounds")
		var resource_world_to_map = bake_data.get("world_to_map")
		var resource_capture_rect = bake_data.get("capture_rect")
		if typeof(resource_bounds) == TYPE_AABB and _has_valid_bounds(resource_bounds) and typeof(resource_world_to_map) == TYPE_TRANSFORM3D and typeof(resource_capture_rect) == TYPE_RECT2 and _has_valid_capture_rect(resource_capture_rect):
			return resource_world_to_map
	return _build_world_to_map(bounds)


func _build_world_to_map(bounds: AABB) -> Transform3D:
	return WaterSystemBakeDataResource.build_world_to_map(bounds)


func _has_valid_bounds(bounds: AABB) -> bool:
	return bounds.size.x > 0.0 and bounds.size.z > 0.0


func _has_valid_capture_rect(capture_rect: Rect2) -> bool:
	return capture_rect.size.x > 0.0 and capture_rect.size.y > 0.0


func _get_min_validation_samples_per_river() -> int:
	return max(int(get_meta("waterways_min_system_samples_per_river", 1)), 1)


func _get_source_path_validation_error(rivers: Array) -> String:
	if bake_data == null:
		return ""
	var stored_paths = bake_data.get("source_river_paths")
	if typeof(stored_paths) != TYPE_PACKED_STRING_ARRAY:
		return "WATER_SYSTEM_GENERATED_MAP_TEST: bake_data.source_river_paths is missing or not a PackedStringArray."
	var expected_paths := _get_source_river_paths(rivers)
	if stored_paths.size() != expected_paths.size():
		return "WATER_SYSTEM_GENERATED_MAP_TEST: source_river_paths count mismatch. expected=" + str(expected_paths) + " stored=" + str(stored_paths)
	for path in stored_paths:
		if String(path).begins_with("/root/") or String(path).contains("@EditorNode"):
			return "WATER_SYSTEM_GENERATED_MAP_TEST: source_river_paths contains a live editor path instead of a stable WaterSystem-relative path: " + str(stored_paths)
	for expected_path in expected_paths:
		if not stored_paths.has(expected_path):
			return "WATER_SYSTEM_GENERATED_MAP_TEST: source_river_paths is missing " + expected_path + ". stored=" + str(stored_paths)
	return ""


func _get_distinct_flow_validation_error(river_samples: Array) -> String:
	if not bool(get_meta("waterways_expect_distinct_system_flow", false)):
		return ""
	if river_samples.size() < 2:
		return ""
	for first_index in river_samples.size():
		var first_flow: Vector3 = river_samples[first_index].flow
		var first_color: Color = river_samples[first_index].color
		for second_index in range(first_index + 1, river_samples.size()):
			var second_flow: Vector3 = river_samples[second_index].flow
			var second_color: Color = river_samples[second_index].color
			var flow_delta := first_flow.distance_to(second_flow)
			var color_delta := Vector2(first_color.r - second_color.r, first_color.g - second_color.g).length()
			if flow_delta > 0.08 or color_delta > 0.04:
				return ""
	return "WATER_SYSTEM_GENERATED_MAP_TEST: all sampled river flows are nearly identical, but this WaterSystem expects distinct per-river flow data. This can indicate the system render/combine path reused one river's flow map or material state. samples=" + _get_river_sample_summary(river_samples)


func _get_expected_flow_validation_error(river_samples: Array) -> String:
	for sample in river_samples:
		var river = sample.river
		if river == null or not river.has_meta("waterways_expected_system_flow"):
			continue
		var expected_variant = river.get_meta("waterways_expected_system_flow")
		var expected := Vector2.ZERO
		if typeof(expected_variant) == TYPE_VECTOR2:
			expected = expected_variant
		elif typeof(expected_variant) == TYPE_VECTOR3:
			var expected_vector := expected_variant as Vector3
			expected = Vector2(expected_vector.x, expected_vector.z)
		else:
			return "WATER_SYSTEM_GENERATED_MAP_TEST: waterways_expected_system_flow metadata must be a Vector2 or Vector3 on " + str(river.get_path()) + "."
		var sampled_flow: Vector3 = sample.flow
		var sampled := Vector2(sampled_flow.x, sampled_flow.z)
		if expected.length_squared() <= 0.0001 or sampled.length_squared() <= 0.0001:
			continue
		var alignment := expected.normalized().dot(sampled.normalized())
		if alignment < 0.25:
			return "WATER_SYSTEM_GENERATED_MAP_TEST: sampled flow for " + str(river.get_path()) + " does not align with expected validation direction. expected=" + str(expected) + " sampled=" + str(sampled) + " alignment=" + str(alignment)
	return ""


func _get_wet_target_assignment_validation_error() -> String:
	if not bool(get_meta("waterways_expect_wet_target_assignment", false)):
		return ""
	if wet_group_name.is_empty():
		return "WATER_SYSTEM_GENERATED_MAP_TEST: expected a wet target assignment, but wet_group_name is empty."
	var wet_nodes = get_tree().get_nodes_in_group(wet_group_name)
	if wet_nodes.is_empty():
		return "WATER_SYSTEM_GENERATED_MAP_TEST: expected a wet target assignment, but group '" + wet_group_name + "' has no nodes."
	var allow_incompatible_targets := bool(get_meta("waterways_allow_incompatible_wet_targets", false))
	var compatible_count := 0
	for node in wet_nodes:
		var material := _get_wet_node_shader_material(node)
		if material == null:
			if allow_incompatible_targets:
				continue
			return "WATER_SYSTEM_GENERATED_MAP_TEST: expected wet target assignment, but " + str(node.get_path()) + " does not expose a compatible ShaderMaterial."
		compatible_count += 1
		var assigned_map = material.get_shader_parameter("water_systemmap")
		if assigned_map != system_map:
			return "WATER_SYSTEM_GENERATED_MAP_TEST: wet target " + str(node.get_path()) + " did not receive the current system_map."
		if material.get_shader_parameter("water_systemmap_coords") == null:
			return "WATER_SYSTEM_GENERATED_MAP_TEST: wet target " + str(node.get_path()) + " did not receive water_systemmap_coords."
	if compatible_count <= 0:
		return "WATER_SYSTEM_GENERATED_MAP_TEST: expected wet target assignment, but group '" + wet_group_name + "' has no compatible ShaderMaterial targets."
	return ""


func _get_coverage_sample_pass_suffix(min_samples_per_river: int, total_coverage_samples: int) -> String:
	if min_samples_per_river <= 1:
		return ""
	return "; " + str(total_coverage_samples) + " mesh coverage sample(s) passed"


func _get_wet_target_assignment_pass_suffix() -> String:
	if not bool(get_meta("waterways_expect_wet_target_assignment", false)):
		return ""
	return "; " + str(_get_compatible_wet_target_assignment_count()) + " wet target assignment(s) passed"


func _get_compatible_wet_target_assignment_count() -> int:
	if not is_inside_tree() or wet_group_name.is_empty():
		return 0
	var count := 0
	for node in get_tree().get_nodes_in_group(wet_group_name):
		if _get_wet_node_shader_material(node, false) != null:
			count += 1
	return count


func _get_map_sample_summary(samples: Array) -> String:
	if samples.is_empty():
		return "none"
	var entries := PackedStringArray()
	for sample in samples:
		entries.append(
			"pos="
			+ str(sample.get("position", Vector3.ZERO))
			+ " uv="
			+ str(sample.get("uv", Vector2(-1.0, -1.0)))
			+ " pixel="
			+ str(sample.get("pixel", Vector2i(-1, -1)))
			+ " source="
			+ str(sample.get("source", "unknown"))
			+ " color="
			+ str(sample.get("color", Color()))
		)
	return "; ".join(entries)


func _get_river_sample_summary(river_samples: Array) -> String:
	var entries := PackedStringArray()
	for sample in river_samples:
		var river = sample.river
		var river_name := "River"
		if river is Node:
			river_name = (river as Node).name
		entries.append(
			river_name
			+ " pos="
			+ str(sample.position)
			+ " uv="
			+ str(sample.get("uv", Vector2(-1.0, -1.0)))
			+ " pixel="
			+ str(sample.get("pixel", Vector2i(-1, -1)))
			+ " source="
			+ str(sample.get("source", "unknown"))
			+ " coverage_samples="
			+ str(sample.get("coverage_sample_count", 1))
			+ " color="
			+ str(sample.color)
			+ " altitude="
			+ str(sample.altitude)
			+ " flow="
			+ str(sample.flow)
		)
	return "; ".join(entries)
