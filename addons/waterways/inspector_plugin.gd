# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends EditorInspectorPlugin

const RiverManager = preload("res://addons/waterways/river_manager.gd")
var _editor = load("res://addons/waterways/editor_property.gd")


func _can_handle(object: Object) -> bool:
	return object is RiverManager


func _parse_property(object: Object, type, path: String, hint, hint_text: String, usage, wide: bool) -> bool:
	if type == TYPE_TRANSFORM3D and "color" in path:
		var editor_property = _editor.new()
		add_property_editor(path, editor_property)
		return true
	return false
