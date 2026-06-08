@tool
extends RefCounted

const WaterRippleFieldScript = preload("res://addons/waterways/water_ripple_field.gd")
const WaterRippleEmitterScript = preload("res://addons/waterways/water_ripple_emitter.gd")
const RiverManagerScript = preload("res://addons/waterways/river_manager.gd")

const EMITTER_MODE_NAMES := {
	0: "Pulse",
	1: "Continuous",
	2: "One Shot",
	3: "Moving",
}


func can_build_status_model(object: Object) -> bool:
	return object is WaterRippleFieldScript or object is WaterRippleEmitterScript


func build_status_model(object: Object) -> Dictionary:
	if object is WaterRippleFieldScript:
		return _build_field_status(object as Node)
	if object is WaterRippleEmitterScript:
		return _build_emitter_status(object as Node)
	return {}


func _build_field_status(field: Node) -> Dictionary:
	var target_summary := _summarize_field_targets(field)
	var boundary_summary := _summarize_field_boundary(field, target_summary)
	var bounds: AABB = field.get("world_bounds")
	return {
		"title": "Water Ripple Field",
		"rows": [
			{"label": "Runtime", "value": "Enabled for scene playback" if bool(field.get("enabled")) else "Disabled"},
			{"label": "Resolution", "value": str(int(field.get("resolution"))) + " px"},
			{"label": "World Bounds", "value": _format_bounds(bounds)},
			{"label": "Targets", "value": target_summary.get("text", "No targets configured")},
			{"label": "Boundary", "value": boundary_summary},
			{"label": "Editor Preview", "value": "Runtime textures are created only when the scene runs"},
		],
		"warnings": _get_configuration_warning_text(field),
	}


func _build_emitter_status(emitter: Node) -> Dictionary:
	var mode := int(emitter.get("emitter_mode"))
	return {
		"title": "Water Ripple Emitter",
		"rows": [
			{"label": "Runtime", "value": "Queues impulses during scene playback" if bool(emitter.get("enabled")) else "Disabled"},
			{"label": "Mode", "value": String(EMITTER_MODE_NAMES.get(mode, "Unknown"))},
			{"label": "Routing", "value": _summarize_emitter_route(emitter)},
			{"label": "Shape", "value": "radius %s m, falloff %s" % [_format_float(float(emitter.get("radius"))), _format_float(float(emitter.get("falloff")))]},
			{"label": "Emission", "value": "intensity %s, rate %s/s" % [_format_float(float(emitter.get("intensity"))), _format_float(float(emitter.get("pulse_rate")))]},
			{"label": "Editor Commands", "value": "Live emit/rebuild controls are deferred"},
		],
		"warnings": _get_configuration_warning_text(emitter),
	}


func _summarize_field_targets(field: Node) -> Dictionary:
	var path_count := 0
	var resolved_path_count := 0
	var paths: Array = field.get("target_river_paths")
	for path in paths:
		var node_path := NodePath(path)
		if node_path == NodePath(""):
			continue
		path_count += 1
		var target := field.get_node_or_null(node_path)
		if target is RiverManagerScript:
			resolved_path_count += 1

	var group_name := String(field.get("target_group_name"))
	var group_count := -1
	if not group_name.is_empty() and field.is_inside_tree():
		group_count = _count_river_group_targets(field, group_name)

	var parts := PackedStringArray()
	if path_count > 0:
		parts.append("%d path%s (%d resolved)" % [path_count, "" if path_count == 1 else "s", resolved_path_count])
	if not group_name.is_empty():
		if group_count >= 0:
			parts.append("group '%s' (%d resolved)" % [group_name, group_count])
		else:
			parts.append("group '%s' (unresolved until in tree)" % group_name)
	if parts.is_empty():
		parts.append("No targets configured")

	return {
		"text": ", ".join(parts),
		"has_configured_sources": path_count > 0 or not group_name.is_empty(),
	}


func _summarize_field_boundary(field: Node, target_summary: Dictionary) -> String:
	if field.get("boundary_mask_texture") != null:
		return "Manual texture assigned"

	var source_count := 0
	var paths: Array = field.get("boundary_source_paths")
	for path in paths:
		if NodePath(path) != NodePath(""):
			source_count += 1

	var auto_generate := bool(field.get("auto_generate_boundary_mask"))
	var require_mask := bool(field.get("require_boundary_mask"))
	var required_text := "required" if require_mask else "optional"
	if auto_generate:
		if source_count > 0:
			return "Auto from %d source path%s, %s" % [source_count, "" if source_count == 1 else "s", required_text]
		if bool(target_summary.get("has_configured_sources", false)):
			return "Auto from target rivers, " + required_text
		return "Auto enabled, no source configured, " + required_text
	return "Auto disabled, " + required_text


func _summarize_emitter_route(emitter: Node) -> String:
	var path := NodePath(emitter.get("target_field_path"))
	if path != NodePath(""):
		var target := emitter.get_node_or_null(path)
		if target is WaterRippleFieldScript:
			return "Path '%s' resolves to %s" % [String(path), target.name]
		return "Path '%s' is unresolved" % String(path)

	var ancestor := _find_ancestor_field(emitter)
	if ancestor != null:
		return "Ancestor field '%s'" % ancestor.name

	var group_name := String(emitter.get("field_group_name"))
	if not group_name.is_empty():
		if emitter.is_inside_tree():
			var field_count := _count_field_group_targets(emitter, group_name)
			return "Group '%s' has %d field%s" % [group_name, field_count, "" if field_count == 1 else "s"]
		return "Group '%s' unresolved until in tree" % group_name
	return "No route configured"


func _find_ancestor_field(node: Node) -> Node:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is WaterRippleFieldScript:
			return ancestor
		ancestor = ancestor.get_parent()
	return null


func _count_field_group_targets(node: Node, group_name: String) -> int:
	var count := 0
	for candidate in node.get_tree().get_nodes_in_group(group_name):
		if candidate is WaterRippleFieldScript:
			count += 1
	return count


func _count_river_group_targets(node: Node, group_name: String) -> int:
	var count := 0
	for candidate in node.get_tree().get_nodes_in_group(group_name):
		if candidate is RiverManagerScript:
			count += 1
	return count


func _get_configuration_warning_text(node: Node) -> PackedStringArray:
	if not node.has_method("_get_configuration_warnings"):
		return PackedStringArray()
	var result = node.call("_get_configuration_warnings")
	if result is PackedStringArray:
		return result
	if result is Array:
		return PackedStringArray(result)
	return PackedStringArray()


func _format_bounds(bounds: AABB) -> String:
	return "origin %s, size %s" % [_format_vector3(bounds.position), _format_vector3(bounds.size)]


func _format_vector3(value: Vector3) -> String:
	return "(%s, %s, %s)" % [_format_float(value.x), _format_float(value.y), _format_float(value.z)]


func _format_float(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%0.3f" % value
