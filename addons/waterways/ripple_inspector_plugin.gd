@tool
extends EditorInspectorPlugin

const WaterRippleFieldScript = preload("res://addons/waterways/water_ripple_field.gd")
const WaterRippleEmitterScript = preload("res://addons/waterways/water_ripple_emitter.gd")
const RippleInspectorStatus = preload("res://addons/waterways/ripple_inspector_status.gd")
const RipplePresetApplyModel = preload("res://addons/waterways/ripple_inspector_preset_apply_model.gd")

const BUILTIN_SELECTOR_PLACEHOLDER := "Choose built-in preset..."
const CUSTOM_PRESET_LABEL := "Custom values"
const FIELD_CAPTURE_FILE_NAME := "water_ripple_field_preset.tres"
const EMITTER_CAPTURE_FILE_NAME := "water_ripple_emitter_preset.tres"

var _status: RefCounted = RippleInspectorStatus.new()
var _preset_apply_model: RefCounted = RipplePresetApplyModel.new()
var _undo_redo: EditorUndoRedoManager
var _last_applied_presets := {}
var _captured_presets := {}
var _open_save_dialogs := []


func _can_handle(object: Object) -> bool:
	return object is WaterRippleFieldScript or object is WaterRippleEmitterScript


func _parse_begin(object: Object) -> void:
	add_custom_control(_make_status_panel(_status.build_status_model(object)))
	add_custom_control(_make_preset_apply_panel(object))


func set_undo_redo_manager(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo


func clear_transient_state() -> void:
	_clear_save_dialogs()
	_status = RippleInspectorStatus.new()
	_preset_apply_model = RipplePresetApplyModel.new()
	_last_applied_presets = {}
	_captured_presets = {}
	_open_save_dialogs = []


func _make_status_panel(model: Dictionary) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "WaterRippleReadOnlyStatus"
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = String(model.get("title", "Water Ripple"))
	title.add_theme_font_size_override("font_size", 13)
	panel.add_child(title)

	for row in model.get("rows", []):
		var row_label := Label.new()
		row_label.text = "%s: %s" % [String(row.get("label", "")), String(row.get("value", ""))]
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(row_label)

	var warnings: PackedStringArray = model.get("warnings", PackedStringArray())
	var warning_label := Label.new()
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if warnings.is_empty():
		warning_label.text = "Warnings: None"
	else:
		warning_label.text = "Warnings:\n- " + "\n- ".join(warnings)
		warning_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	panel.add_child(warning_label)
	return panel


func _make_preset_apply_panel(object: Object) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "WaterRipplePresetApply"
	panel.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Preset Apply"
	title.add_theme_font_size_override("font_size", 13)
	panel.add_child(title)

	var active_preset_label := Label.new()
	active_preset_label.name = "WaterRippleActivePreset"
	active_preset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_active_preset_label(active_preset_label, object)
	panel.add_child(active_preset_label)

	var builtin_row := HBoxContainer.new()
	builtin_row.add_theme_constant_override("separation", 4)
	var builtin_selector := OptionButton.new()
	builtin_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builtin_selector.add_item(BUILTIN_SELECTOR_PLACEHOLDER)
	var active_builtin_name: String = _preset_apply_model.get_builtin_preset_name_matching_node(object)
	var active_builtin_index := 0
	for preset_name in _preset_apply_model.get_builtin_preset_names_for_node(object):
		builtin_selector.add_item(String(preset_name))
		if String(preset_name) == active_builtin_name:
			active_builtin_index = builtin_selector.get_item_count() - 1
	builtin_selector.select(active_builtin_index)
	builtin_row.add_child(builtin_selector)

	var apply_builtin_button := Button.new()
	apply_builtin_button.text = "Apply Built-In"
	apply_builtin_button.disabled = builtin_selector.selected <= 0
	builtin_row.add_child(apply_builtin_button)
	panel.add_child(builtin_row)

	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 4)
	var resource_picker := EditorResourcePicker.new()
	resource_picker.base_type = _preset_apply_model.get_resource_base_type_for_node(object)
	resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_row.add_child(resource_picker)

	var apply_resource_button := Button.new()
	apply_resource_button.text = "Apply Resource"
	apply_resource_button.disabled = true
	resource_row.add_child(apply_resource_button)
	panel.add_child(resource_row)

	var feedback_label := Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var capture_title := Label.new()
	capture_title.text = "Preset Capture"
	capture_title.add_theme_font_size_override("font_size", 13)
	panel.add_child(capture_title)

	var capture_row := HBoxContainer.new()
	capture_row.add_theme_constant_override("separation", 4)

	var capture_button := Button.new()
	capture_button.text = _get_capture_button_text(object)
	capture_row.add_child(capture_button)

	var save_captured_button := Button.new()
	save_captured_button.text = "Save Captured"
	save_captured_button.disabled = true
	capture_row.add_child(save_captured_button)
	panel.add_child(capture_row)

	var captured_label := Label.new()
	captured_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	captured_label.text = "Captured preset: None"
	panel.add_child(captured_label)
	panel.add_child(feedback_label)

	builtin_selector.item_selected.connect(func(index: int) -> void:
		apply_builtin_button.disabled = index <= 0
		_set_feedback(feedback_label, "", false)
	)
	apply_builtin_button.pressed.connect(func() -> void:
		var selected_index := builtin_selector.selected
		if selected_index <= 0:
			_set_feedback(feedback_label, "Choose a built-in preset first.", true)
			return
		var preset_name := builtin_selector.get_item_text(selected_index)
		var preset: Resource = _preset_apply_model.create_builtin_preset_for_node(object, preset_name)
		_apply_preset_with_undo(object, preset, feedback_label, active_preset_label, preset_name)
	)
	resource_picker.resource_changed.connect(func(resource: Resource) -> void:
		apply_resource_button.disabled = not _preset_apply_model.can_apply_preset(object, resource)
		_set_feedback(feedback_label, "", false)
	)
	apply_resource_button.pressed.connect(func() -> void:
		_apply_preset_with_undo(object, resource_picker.edited_resource, feedback_label, active_preset_label)
	)
	capture_button.pressed.connect(func() -> void:
		var captured_preset := _capture_preset_from_node(object)
		if captured_preset == null:
			_forget_captured_preset(object)
			save_captured_button.disabled = true
			captured_label.text = "Captured preset: None"
			_set_feedback(feedback_label, "Could not capture a preset from the selected ripple node.", true)
			return
		_remember_captured_preset(object, captured_preset)
		save_captured_button.disabled = false
		captured_label.text = "Captured preset: %s" % _get_preset_display_name(captured_preset)
		_set_feedback(feedback_label, "Captured preset in memory.", false)
	)
	save_captured_button.pressed.connect(func() -> void:
		var captured_preset := _get_captured_preset(object)
		if captured_preset == null:
			save_captured_button.disabled = true
			captured_label.text = "Captured preset: None"
			_set_feedback(feedback_label, "Capture a preset before saving.", true)
			return
		_open_preset_save_dialog(panel, object, captured_preset, feedback_label)
	)

	return panel


func _apply_preset_with_undo(
		object: Object,
		preset: Resource,
		feedback_label: Label,
		active_preset_label: Label = null,
		applied_preset_label: String = "") -> void:
	if not is_instance_valid(object):
		_set_feedback(feedback_label, "The selected ripple node is no longer available.", true)
		return
	if not _preset_apply_model.can_apply_preset(object, preset):
		_set_feedback(feedback_label, "Choose a matching ripple preset resource first.", true)
		return
	if _undo_redo == null:
		_set_feedback(feedback_label, "Editor undo is unavailable for this inspector action.", true)
		return

	var preset_display_name := _get_preset_display_name(preset, applied_preset_label)
	var changes: Array = _preset_apply_model.build_property_changes(object, preset)
	if changes.is_empty():
		_remember_applied_preset(object, preset, preset_display_name)
		if active_preset_label != null:
			_set_active_preset_label(active_preset_label, object)
		_set_feedback(feedback_label, "Preset already matches this node.", false)
		return

	_undo_redo.create_action(_preset_apply_model.get_apply_action_name(object), 0, object)
	for change in changes:
		var property_name := StringName(change.get("property", ""))
		_undo_redo.add_do_property(object, property_name, change.get("new_value"))
		_undo_redo.add_undo_property(object, property_name, change.get("old_value"))
	_add_refresh_methods(object)
	_undo_redo.commit_action()
	_remember_applied_preset(object, preset, preset_display_name)
	if active_preset_label != null:
		_set_active_preset_label(active_preset_label, object)
	_set_feedback(feedback_label, "Applied %d preset value%s." % [changes.size(), "" if changes.size() == 1 else "s"], false)


func _add_refresh_methods(object: Object) -> void:
	if object.has_method("update_configuration_warnings"):
		_undo_redo.add_do_method(object, "update_configuration_warnings")
		_undo_redo.add_undo_method(object, "update_configuration_warnings")
	if object.has_method("notify_property_list_changed"):
		_undo_redo.add_do_method(object, "notify_property_list_changed")
		_undo_redo.add_undo_method(object, "notify_property_list_changed")


func _set_feedback(label: Label, text: String, is_warning: bool) -> void:
	label.text = text
	if is_warning:
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	else:
		label.remove_theme_color_override("font_color")


func _set_active_preset_label(label: Label, object: Object) -> void:
	label.text = "Active preset: %s" % _get_active_preset_display_name(object)


func _get_active_preset_display_name(object: Object) -> String:
	var builtin_match: String = _preset_apply_model.get_builtin_preset_name_matching_node(object)
	if not builtin_match.is_empty():
		return builtin_match

	var remembered_preset: Dictionary = _last_applied_presets.get(_get_object_key(object), {})
	if remembered_preset.is_empty():
		return CUSTOM_PRESET_LABEL
	if _preset_apply_model.node_matches_property_values(object, remembered_preset.get("values", {})):
		return String(remembered_preset.get("label", CUSTOM_PRESET_LABEL))
	return CUSTOM_PRESET_LABEL


func _remember_applied_preset(object: Object, preset: Resource, preset_display_name: String) -> void:
	if not is_instance_valid(object) or not _preset_apply_model.can_apply_preset(object, preset):
		return
	_last_applied_presets[_get_object_key(object)] = {
		"label": preset_display_name,
		"values": _preset_apply_model.build_sanitized_property_values(object, preset),
	}


func _capture_preset_from_node(object: Object) -> Resource:
	if not is_instance_valid(object) or not object.has_method("capture_preset"):
		return null
	var captured = object.call("capture_preset")
	if not (captured is Resource):
		return null
	var captured_preset := captured as Resource
	if not _preset_apply_model.can_apply_preset(object, captured_preset):
		return null
	captured_preset.resource_path = ""
	if captured_preset.resource_name.strip_edges().is_empty():
		captured_preset.resource_name = _get_default_capture_resource_name(object)
	return captured_preset


func _remember_captured_preset(object: Object, preset: Resource) -> void:
	if not is_instance_valid(object) or not _preset_apply_model.can_apply_preset(object, preset):
		return
	_captured_presets[_get_object_key(object)] = preset


func _get_captured_preset(object: Object) -> Resource:
	var preset = _captured_presets.get(_get_object_key(object))
	if preset is Resource and _preset_apply_model.can_apply_preset(object, preset):
		return preset
	return null


func _forget_captured_preset(object: Object) -> void:
	_captured_presets.erase(_get_object_key(object))


func _open_preset_save_dialog(owner_control: Control, object: Object, preset: Resource, feedback_label: Label) -> void:
	if not is_instance_valid(owner_control):
		_set_feedback(feedback_label, "The preset save dialog cannot be opened from this inspector state.", true)
		return
	if not is_instance_valid(object) or not _preset_apply_model.can_apply_preset(object, preset):
		_set_feedback(feedback_label, "Capture a matching ripple preset before saving.", true)
		return

	var dialog := EditorFileDialog.new()
	dialog.name = "WaterRipplePresetSaveDialog"
	dialog.title = _get_save_dialog_title(object)
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.current_dir = "res://"
	dialog.current_file = _get_default_capture_file_name(object)
	dialog.clear_filters()
	dialog.add_filter("*.tres", "Godot text resource")
	_open_save_dialogs.append(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		_save_captured_preset(preset, path, feedback_label)
		_close_save_dialog(dialog)
	)
	dialog.canceled.connect(func() -> void:
		_close_save_dialog(dialog)
	)
	owner_control.add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(820, 520), 0.8)


func _clear_save_dialogs() -> void:
	for dialog in _open_save_dialogs:
		if is_instance_valid(dialog):
			dialog.queue_free()


func _close_save_dialog(dialog: EditorFileDialog) -> void:
	_open_save_dialogs.erase(dialog)
	if is_instance_valid(dialog):
		dialog.queue_free()


func _save_captured_preset(preset: Resource, path: String, feedback_label: Label) -> void:
	var save_path := _normalize_preset_save_path(path)
	if save_path.is_empty():
		_set_feedback(feedback_label, "Choose a res:// .tres path for the captured preset.", true)
		return
	var save_flags := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	var save_error := ResourceSaver.save(preset, save_path, save_flags)
	if save_error != OK:
		_set_feedback(feedback_label, "Could not save preset. Error code: %d" % save_error, true)
		return
	_set_feedback(feedback_label, "Saved preset to %s." % save_path, false)


func _normalize_preset_save_path(path: String) -> String:
	var save_path := path.strip_edges()
	if save_path.is_empty() or not save_path.begins_with("res://"):
		return ""
	var extension := save_path.get_extension().to_lower()
	if extension.is_empty():
		return save_path + ".tres"
	if extension != "tres":
		return ""
	return save_path


func _get_capture_button_text(object: Object) -> String:
	if object is WaterRippleFieldScript:
		return "Capture Field"
	if object is WaterRippleEmitterScript:
		return "Capture Emitter"
	return "Capture Preset"


func _get_default_capture_resource_name(object: Object) -> String:
	if object is WaterRippleFieldScript:
		return "Captured Water Ripple Field Preset"
	if object is WaterRippleEmitterScript:
		return "Captured Water Ripple Emitter Preset"
	return "Captured Water Ripple Preset"


func _get_default_capture_file_name(object: Object) -> String:
	if object is WaterRippleFieldScript:
		return FIELD_CAPTURE_FILE_NAME
	if object is WaterRippleEmitterScript:
		return EMITTER_CAPTURE_FILE_NAME
	return "water_ripple_preset.tres"


func _get_save_dialog_title(object: Object) -> String:
	if object is WaterRippleFieldScript:
		return "Save Water Ripple Field Preset"
	if object is WaterRippleEmitterScript:
		return "Save Water Ripple Emitter Preset"
	return "Save Water Ripple Preset"


func _get_preset_display_name(preset: Resource, fallback_name: String = "") -> String:
	if not fallback_name.strip_edges().is_empty():
		return fallback_name.strip_edges()
	if preset.resource_name.strip_edges().is_empty() == false:
		return preset.resource_name.strip_edges()
	if preset.resource_path.strip_edges().is_empty() == false:
		return preset.resource_path.get_file().get_basename()
	return "Resource preset"


func _get_object_key(object: Object) -> int:
	if not is_instance_valid(object):
		return 0
	return object.get_instance_id()
