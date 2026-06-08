extends SceneTree

const INSPECTOR_SCRIPT_PATH := "res://addons/waterways/ripple_inspector_plugin.gd"
const STATUS_SCRIPT_PATH := "res://addons/waterways/ripple_inspector_status.gd"
const PRESET_APPLY_MODEL_SCRIPT_PATH := "res://addons/waterways/ripple_inspector_preset_apply_model.gd"
const PLUGIN_SCRIPT_PATH := "res://addons/waterways/plugin.gd"
const FIELD_SCRIPT_PATH := "res://addons/waterways/water_ripple_field.gd"
const EMITTER_SCRIPT_PATH := "res://addons/waterways/water_ripple_emitter.gd"
const FIELD_PRESET_SCRIPT_PATH := "res://addons/waterways/resources/water_ripple_field_preset.gd"
const EMITTER_PRESET_SCRIPT_PATH := "res://addons/waterways/resources/water_ripple_emitter_preset.gd"
const FieldPresetResource := preload("res://addons/waterways/resources/water_ripple_field_preset.gd")
const EmitterPresetResource := preload("res://addons/waterways/resources/water_ripple_emitter_preset.gd")
const SCRATCH_DIR := "res://.codex-research/ripple-phase10-inspector"
const SCRATCH_FIELD_CAPTURE_SAVE_PATH := SCRATCH_DIR + "/phase10_captured_field_preset.tres"
const SCRATCH_EMITTER_CAPTURE_SAVE_PATH := SCRATCH_DIR + "/phase10_captured_emitter_preset.tres"

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var inspector_script := load(INSPECTOR_SCRIPT_PATH) as Script
	var status_script := load(STATUS_SCRIPT_PATH) as Script
	var preset_apply_model_script := load(PRESET_APPLY_MODEL_SCRIPT_PATH) as Script
	var plugin_script := load(PLUGIN_SCRIPT_PATH) as Script
	var field_script := load(FIELD_SCRIPT_PATH) as Script
	var emitter_script := load(EMITTER_SCRIPT_PATH) as Script
	_expect(inspector_script != null, "Ripple inspector plugin script should load.")
	_expect(status_script != null and status_script.can_instantiate(), "Ripple inspector status helper should instantiate.")
	_expect(preset_apply_model_script != null and preset_apply_model_script.can_instantiate(), "Ripple preset apply model should instantiate.")
	_expect(plugin_script != null, "Waterways plugin script should still load.")
	_expect(field_script != null and field_script.can_instantiate(), "WaterRippleField script should still instantiate.")
	_expect(emitter_script != null and emitter_script.can_instantiate(), "WaterRippleEmitter script should still instantiate.")
	if status_script == null or preset_apply_model_script == null or field_script == null or emitter_script == null:
		_finish()
		return

	_validate_static_boundaries()
	_validate_status_models(status_script, field_script, emitter_script)
	_validate_preset_apply_model(preset_apply_model_script, field_script, emitter_script)
	_validate_preset_capture_save_contract(field_script, emitter_script)

	print("RIPPLE_PHASE10_INSPECTOR_RESULTS=", _results)
	_finish()


func _validate_static_boundaries() -> void:
	var inspector_source := FileAccess.get_file_as_string(INSPECTOR_SCRIPT_PATH)
	var status_source := FileAccess.get_file_as_string(STATUS_SCRIPT_PATH)
	var preset_apply_model_source := FileAccess.get_file_as_string(PRESET_APPLY_MODEL_SCRIPT_PATH)
	var plugin_source := FileAccess.get_file_as_string(PLUGIN_SCRIPT_PATH)
	var runtime_source := FileAccess.get_file_as_string(FIELD_SCRIPT_PATH) + "\n" + FileAccess.get_file_as_string(EMITTER_SCRIPT_PATH) + "\n" + FileAccess.get_file_as_string(FIELD_PRESET_SCRIPT_PATH) + "\n" + FileAccess.get_file_as_string(EMITTER_PRESET_SCRIPT_PATH)
	var editor_status_source := inspector_source + "\n" + status_source + "\n" + preset_apply_model_source

	_expect(plugin_source.contains("RippleInspector"), "Waterways plugin should register the ripple inspector plugin.")
	_expect(plugin_source.contains("set_undo_redo_manager(get_undo_redo())"), "Waterways plugin should pass editor undo to the ripple inspector.")
	_expect(plugin_source.contains("add_inspector_plugin(ripple_inspector)"), "Waterways plugin should add the ripple inspector.")
	_expect(plugin_source.contains("remove_inspector_plugin(ripple_inspector)"), "Waterways plugin should remove the ripple inspector.")
	_expect(inspector_source.contains("extends EditorInspectorPlugin"), "Ripple inspector should be an EditorInspectorPlugin.")
	_expect(inspector_source.contains("func clear_transient_state()"), "Ripple inspector should expose lifecycle cleanup.")
	_expect(inspector_source.contains("EditorResourcePicker"), "Ripple inspector should expose transient preset resource selectors.")
	_expect(inspector_source.contains("EditorUndoRedoManager"), "Ripple inspector should use editor undo for Apply actions.")
	_expect(inspector_source.contains("add_do_property"), "Ripple inspector should use per-property do operations for Apply.")
	_expect(inspector_source.contains("add_undo_property"), "Ripple inspector should use per-property undo operations for Apply.")
	_expect(inspector_source.contains("create_action"), "Ripple inspector should group Apply property changes in one undo action.")
	_expect(inspector_source.contains("Active preset:"), "Ripple inspector should show the active preset state.")
	_expect(inspector_source.contains("BUILTIN_SELECTOR_PLACEHOLDER"), "Ripple inspector should avoid implying the first built-in preset is active.")
	_expect(inspector_source.contains("EditorFileDialog"), "Ripple inspector should own the editor save dialog for captured presets.")
	_expect(inspector_source.contains("FileDialog.FILE_MODE_SAVE_FILE"), "Ripple inspector save dialog should use save-file mode.")
	_expect(inspector_source.contains("FileDialog.ACCESS_RESOURCES"), "Ripple inspector save dialog should stay inside res:// resource paths.")
	_expect(inspector_source.contains("ResourceSaver.save"), "Ripple inspector should save captured presets only from editor UI.")
	_expect(inspector_source.contains("_normalize_preset_save_path"), "Ripple inspector should sanitize explicit save paths.")
	_expect(inspector_source.contains("capture_preset"), "Ripple inspector should capture fresh in-memory presets before saving.")
	_expect(inspector_source.contains("_captured_presets"), "Ripple inspector should keep captured presets as transient plugin state.")
	_expect(inspector_source.contains("_open_save_dialogs"), "Ripple inspector should track save dialogs for lifecycle cleanup.")
	_expect(status_source.contains("can_build_status_model"), "Read-only status helper should expose a probeable status contract.")
	_expect(not editor_status_source.contains("initialize_runtime("), "Read-only inspector should not initialize runtime.")
	_expect(not editor_status_source.contains("rebuild_runtime("), "Read-only inspector should not rebuild runtime.")
	_expect(not editor_status_source.contains("rebuild_boundary_mask("), "Read-only inspector should not rebuild boundary masks.")
	_expect(not editor_status_source.contains("reset_feedback("), "Read-only inspector should not reset feedback.")
	_expect(not editor_status_source.contains("queue_impulse"), "Read-only inspector should not queue impulses.")
	_expect(not editor_status_source.contains("emit_once("), "Read-only inspector should not emit once.")
	_expect(not editor_status_source.contains("register_target("), "Read-only inspector should not register targets.")
	_expect(not editor_status_source.contains("unregister_target("), "Read-only inspector should not unregister targets.")
	_expect(not editor_status_source.contains("apply_runtime_ripple_material_state"), "Read-only inspector should not apply runtime material state.")
	_expect(not editor_status_source.contains("clear_runtime_ripple_material_state"), "Read-only inspector should not clear runtime material state.")
	_expect(not editor_status_source.contains("_resolve_field("), "Read-only inspector should not call emitter private routing resolver.")
	_expect(not editor_status_source.contains("_refresh_target_rivers("), "Read-only inspector should not refresh runtime targets.")
	_expect(not editor_status_source.contains("_get_target_mesh_instances("), "Read-only inspector should not inspect private target mesh caches.")
	_expect(not editor_status_source.contains("get_runtime_viewport_rids("), "Read-only inspector should not inspect runtime viewport RIDs.")
	_expect(not editor_status_source.contains("get_field_snapshot("), "Read-only inspector should not use runtime field snapshots.")
	_expect(not editor_status_source.contains("get_emitter_snapshot("), "Read-only inspector should not use runtime emitter snapshots.")
	_expect(not editor_status_source.contains("mark_scene_as_unsaved"), "Read-only inspector should not mark scenes unsaved.")
	_expect(not status_source.contains("EditorFileDialog"), "Read-only status helper should not own save dialogs.")
	_expect(not status_source.contains("ResourceSaver"), "Read-only status helper should not save resources.")
	_expect(not inspector_source.contains(".apply_preset("), "Editor Apply should not call runtime apply_preset as its undo do-method.")
	_expect(not inspector_source.contains("apply_builtin_preset("), "Editor Apply should not call runtime built-in apply helpers.")

	_expect(not runtime_source.contains("EditorPlugin"), "Runtime ripple scripts should not reference EditorPlugin.")
	_expect(not runtime_source.contains("EditorInspectorPlugin"), "Runtime ripple scripts should not reference EditorInspectorPlugin.")
	_expect(not runtime_source.contains("EditorUndoRedoManager"), "Runtime ripple scripts should not reference EditorUndoRedoManager.")
	_expect(not runtime_source.contains("EditorFileDialog"), "Runtime ripple scripts should not reference EditorFileDialog.")
	_expect(not runtime_source.contains("EditorResourcePicker"), "Runtime ripple scripts should not reference EditorResourcePicker.")
	_expect(not runtime_source.contains("ResourceSaver"), "Runtime ripple scripts should not save resources.")
	_expect(not runtime_source.contains(".tres"), "Runtime ripple scripts should not create preset resource save paths.")
	_expect(not preset_apply_model_source.contains("EditorPlugin"), "Preset apply model should stay probeable without EditorPlugin.")
	_expect(not preset_apply_model_source.contains("EditorInspectorPlugin"), "Preset apply model should stay probeable without EditorInspectorPlugin.")
	_expect(not preset_apply_model_source.contains("EditorUndoRedoManager"), "Preset apply model should not own editor undo.")
	_expect(not preset_apply_model_source.contains("EditorResourcePicker"), "Preset apply model should not own selector UI.")
	_expect(not preset_apply_model_source.contains("EditorFileDialog"), "Preset apply model should not own save dialogs.")
	_expect(not preset_apply_model_source.contains("ResourceSaver"), "Preset apply model should not save resources.")
	_expect(preset_apply_model_source.contains("get_builtin_preset_name_matching_node"), "Preset apply model should identify current built-in matches.")


func _validate_status_models(status_script: Script, field_script: Script, emitter_script: Script) -> void:
	var status: Object = status_script.new()
	var root_node := Node3D.new()
	root_node.name = "Phase10InspectorProbeRoot"
	root.add_child(root_node)

	var field := field_script.new() as Node3D
	field.name = "ProbeField"
	field.set("enabled", false)
	field.set("resolution", 256)
	field.set("target_group_name", "phase10_targets")
	root_node.add_child(field)

	var emitter := emitter_script.new() as Node3D
	emitter.name = "ProbeEmitter"
	emitter.set("enabled", false)
	root_node.add_child(emitter)
	emitter.set("target_field_path", emitter.get_path_to(field))

	var field_before := _read_field_values(field)
	var emitter_before := _read_emitter_values(emitter)
	_expect(bool(status.call("can_build_status_model", field)), "Ripple status helper should handle WaterRippleField.")
	_expect(bool(status.call("can_build_status_model", emitter)), "Ripple status helper should handle WaterRippleEmitter.")
	_expect(not bool(status.call("can_build_status_model", root_node)), "Ripple status helper should ignore unrelated nodes.")

	var field_model: Dictionary = status.call("build_status_model", field)
	var emitter_model: Dictionary = status.call("build_status_model", emitter)
	_expect(String(field_model.get("title", "")) == "Water Ripple Field", "Field status model should have a field title.")
	_expect(String(emitter_model.get("title", "")) == "Water Ripple Emitter", "Emitter status model should have an emitter title.")
	_expect(_row_value_contains(field_model, "Resolution", "256"), "Field status should show exported resolution.")
	_expect(_row_value_contains(field_model, "Targets", "phase10_targets"), "Field status should summarize target group.")
	_expect(_row_value_contains(field_model, "Editor Preview", "Runtime textures"), "Field status should state runtime texture boundary.")
	_expect(_row_value_contains(emitter_model, "Routing", "ProbeField"), "Emitter status should summarize exported path routing.")
	_expect(_row_value_contains(emitter_model, "Editor Commands", "deferred"), "Emitter status should keep live commands deferred.")
	_expect(_read_field_values(field) == field_before, "Building field status should not mutate exported values.")
	_expect(_read_emitter_values(emitter) == emitter_before, "Building emitter status should not mutate exported values.")
	_expect(field.get_child_count() == 0, "Building field status should not add runtime or preview children.")
	_expect(emitter.get_child_count() == 0, "Building emitter status should not add runtime or preview children.")

	_results["field_model_rows"] = (field_model.get("rows", []) as Array).size()
	_results["emitter_model_rows"] = (emitter_model.get("rows", []) as Array).size()
	root_node.free()


func _validate_preset_apply_model(preset_apply_model_script: Script, field_script: Script, emitter_script: Script) -> void:
	var model: Object = preset_apply_model_script.new()
	var root_node := Node3D.new()
	root_node.name = "Phase10PresetApplyProbeRoot"
	root.add_child(root_node)

	var field := field_script.new() as Node3D
	field.name = "ProbeField"
	field.set("enabled", false)
	field.set("resolution", 128)
	field.set("simulation_update_rate", 30.0)
	field.set("damping", 0.5)
	field.set("target_group_name", "phase10_targets_should_not_copy")
	root_node.add_child(field)

	var emitter := emitter_script.new() as Node3D
	emitter.name = "ProbeEmitter"
	emitter.set("enabled", false)
	emitter.set("emitter_mode", 0)
	emitter.set("radius", 0.25)
	emitter.set("intensity", 0.1)
	emitter.set("target_field_path", NodePath("../ProbeField"))
	root_node.add_child(emitter)

	var field_preset := field_script.call("create_builtin_preset", "Heavy Impact Field") as Resource
	var emitter_preset := emitter_script.call("create_builtin_preset", "Heavy Impact") as Resource
	_expect(field_preset != null, "Field built-in preset should be creatable.")
	_expect(emitter_preset != null, "Emitter built-in preset should be creatable.")
	if field_preset == null or emitter_preset == null:
		root_node.free()
		return

	var field_before := _read_field_values(field)
	var emitter_before := _read_emitter_values(emitter)
	var field_changes: Array = model.call("build_property_changes", field, field_preset)
	var emitter_changes: Array = model.call("build_property_changes", emitter, emitter_preset)
	_expect(not field_changes.is_empty(), "Field preset apply should report changed values.")
	_expect(not emitter_changes.is_empty(), "Emitter preset apply should report changed values.")
	_expect(_changes_include(field_changes, "resolution"), "Field preset apply should include whitelisted field values.")
	_expect(_changes_include(field_changes, "ripple_strength"), "Field preset apply should include visual strength values.")
	_expect(not _changes_include(field_changes, "target_group_name"), "Field preset apply should not copy target routing.")
	_expect(not _changes_include(field_changes, "target_river_paths"), "Field preset apply should not copy target paths.")
	_expect(not _changes_include(field_changes, "refraction_strength"), "Field preset apply should not copy reserved refraction.")
	_expect(not _changes_include(field_changes, "displacement_strength"), "Field preset apply should not copy reserved displacement.")
	_expect(not _changes_include(field_changes, "debug_visible"), "Field preset apply should not copy hidden debug reservations.")
	_expect(_changes_include(emitter_changes, "emitter_mode"), "Emitter preset apply should include mode.")
	_expect(_changes_include(emitter_changes, "radius"), "Emitter preset apply should include shape values.")
	_expect(not _changes_include(emitter_changes, "target_field_path"), "Emitter preset apply should not copy field paths.")
	_expect(not _changes_include(emitter_changes, "field_group_name"), "Emitter preset apply should not copy field groups.")
	_expect(_read_field_values(field) == field_before, "Building field preset changes should not mutate the node.")
	_expect(_read_emitter_values(emitter) == emitter_before, "Building emitter preset changes should not mutate the node.")

	_apply_changes_directly(field, field_changes)
	_apply_changes_directly(emitter, emitter_changes)
	_expect((model.call("build_property_changes", field, field_preset) as Array).is_empty(), "No-op field Apply should produce no property changes.")
	_expect((model.call("build_property_changes", emitter, emitter_preset) as Array).is_empty(), "No-op emitter Apply should produce no property changes.")
	_expect(String(model.call("get_builtin_preset_name_matching_node", field)) == "Heavy Impact Field", "Field Apply should make the active built-in preset identifiable.")
	_expect(String(model.call("get_builtin_preset_name_matching_node", emitter)) == "Heavy Impact", "Emitter Apply should make the active built-in preset identifiable.")

	field_preset.set("resolution", 1024)
	emitter_preset.set("radius", 8.0)
	_expect(int(field.get("resolution")) != 1024, "Editing a source field preset after apply should not mutate the field.")
	_expect(not is_equal_approx(float(emitter.get("radius")), 8.0), "Editing a source emitter preset after apply should not mutate the emitter.")

	_results["field_apply_changes"] = field_changes.size()
	_results["emitter_apply_changes"] = emitter_changes.size()
	root_node.free()


func _validate_preset_capture_save_contract(field_script: Script, emitter_script: Script) -> void:
	var scratch_abs := ProjectSettings.globalize_path(SCRATCH_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(scratch_abs)
	_expect(dir_error == OK or dir_error == ERR_ALREADY_EXISTS, "Scratch directory should be available for Phase 10 capture/save probes.")

	var root_node := Node3D.new()
	root_node.name = "Phase10CaptureSaveProbeRoot"
	root.add_child(root_node)

	var field := field_script.new() as Node3D
	field.name = "CaptureField"
	field.set("enabled", false)
	field.set("resolution", 384)
	field.set("simulation_update_rate", 42.0)
	field.set("normal_strength", 2.75)
	field.set("target_group_name", "phase10_capture_targets_should_not_save")
	root_node.add_child(field)

	var emitter := emitter_script.new() as Node3D
	emitter.name = "CaptureEmitter"
	emitter.set("enabled", false)
	emitter.set("emitter_mode", 3)
	emitter.set("radius", 2.5)
	emitter.set("intensity", 0.7)
	emitter.set("target_field_path", NodePath("../CaptureField"))
	root_node.add_child(emitter)

	var field_before := _read_field_values(field)
	var emitter_before := _read_emitter_values(emitter)
	var captured_field := field.call("capture_preset") as Resource
	var captured_emitter := emitter.call("capture_preset") as Resource
	_expect(captured_field != null, "Field capture should create a preset resource.")
	_expect(captured_emitter != null, "Emitter capture should create a preset resource.")
	_expect(_read_field_values(field) == field_before, "Capturing a field preset should not mutate the field.")
	_expect(_read_emitter_values(emitter) == emitter_before, "Capturing an emitter preset should not mutate the emitter.")

	if captured_field != null:
		_expect(captured_field.get_script() == FieldPresetResource, "Captured field preset should keep the field preset script.")
		_expect(captured_field.resource_path.is_empty(), "Captured field preset should start as an unsaved scratch resource.")
		_expect(int(captured_field.get("resolution")) == 384, "Captured field preset should copy approved field values.")
		_expect(_approximately(float(captured_field.get("normal_strength")), 2.75), "Captured field preset should copy visual response values.")
		_expect(not _resource_has_property(captured_field, "target_group_name"), "Captured field preset should not store target routing.")
		_expect(not _resource_has_property(captured_field, "refraction_strength"), "Captured field preset should not store reserved refraction.")
		_expect(not _resource_has_property(captured_field, "displacement_strength"), "Captured field preset should not store reserved displacement.")
		_expect(ResourceSaver.save(captured_field, SCRATCH_FIELD_CAPTURE_SAVE_PATH, ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES) == OK, "Captured field preset should save to an explicit scratch path.")
		var loaded_field := ResourceLoader.load(SCRATCH_FIELD_CAPTURE_SAVE_PATH) as Resource
		_expect(loaded_field != null, "Saved captured field preset should load from scratch.")
		if loaded_field != null:
			_expect(loaded_field.get_script() == FieldPresetResource, "Loaded captured field preset should keep its resource script.")
			_expect(int(loaded_field.get("resolution")) == 384, "Loaded captured field preset should preserve resolution.")
			_expect(_approximately(float(loaded_field.get("normal_strength")), 2.75), "Loaded captured field preset should preserve visual response values.")

	if captured_emitter != null:
		_expect(captured_emitter.get_script() == EmitterPresetResource, "Captured emitter preset should keep the emitter preset script.")
		_expect(captured_emitter.resource_path.is_empty(), "Captured emitter preset should start as an unsaved scratch resource.")
		_expect(int(captured_emitter.get("emitter_mode")) == 3, "Captured emitter preset should copy approved mode.")
		_expect(_approximately(float(captured_emitter.get("radius")), 2.5), "Captured emitter preset should copy shape values.")
		_expect(not _resource_has_property(captured_emitter, "target_field_path"), "Captured emitter preset should not store target field paths.")
		_expect(not _resource_has_property(captured_emitter, "field_group_name"), "Captured emitter preset should not store target field groups.")
		_expect(ResourceSaver.save(captured_emitter, SCRATCH_EMITTER_CAPTURE_SAVE_PATH, ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES) == OK, "Captured emitter preset should save to an explicit scratch path.")
		var loaded_emitter := ResourceLoader.load(SCRATCH_EMITTER_CAPTURE_SAVE_PATH) as Resource
		_expect(loaded_emitter != null, "Saved captured emitter preset should load from scratch.")
		if loaded_emitter != null:
			_expect(loaded_emitter.get_script() == EmitterPresetResource, "Loaded captured emitter preset should keep its resource script.")
			_expect(int(loaded_emitter.get("emitter_mode")) == 3, "Loaded captured emitter preset should preserve mode.")
			_expect(_approximately(float(loaded_emitter.get("radius")), 2.5), "Loaded captured emitter preset should preserve shape values.")

	_results["phase10_capture_save_paths"] = [SCRATCH_FIELD_CAPTURE_SAVE_PATH, SCRATCH_EMITTER_CAPTURE_SAVE_PATH]
	root_node.free()


func _read_field_values(field: Node) -> Dictionary:
	return {
		"enabled": field.get("enabled"),
		"resolution": field.get("resolution"),
		"target_group_name": field.get("target_group_name"),
		"world_bounds": field.get("world_bounds"),
		"auto_generate_boundary_mask": field.get("auto_generate_boundary_mask"),
		"require_boundary_mask": field.get("require_boundary_mask"),
	}


func _read_emitter_values(emitter: Node) -> Dictionary:
	return {
		"enabled": emitter.get("enabled"),
		"target_field_path": emitter.get("target_field_path"),
		"field_group_name": emitter.get("field_group_name"),
		"emitter_mode": emitter.get("emitter_mode"),
		"radius": emitter.get("radius"),
		"intensity": emitter.get("intensity"),
	}


func _row_value_contains(model: Dictionary, row_label: String, expected_text: String) -> bool:
	for row in model.get("rows", []):
		if String(row.get("label", "")) == row_label:
			return String(row.get("value", "")).contains(expected_text)
	return false


func _changes_include(changes: Array, property_name: String) -> bool:
	for change in changes:
		if String((change as Dictionary).get("property", "")) == property_name:
			return true
	return false


func _apply_changes_directly(object: Object, changes: Array) -> void:
	for change in changes:
		var change_dict := change as Dictionary
		object.set(String(change_dict.get("property", "")), change_dict.get("new_value"))


func _resource_has_property(resource: Resource, property_name: String) -> bool:
	for property in resource.get_property_list():
		if String((property as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _approximately(left: float, right: float) -> bool:
	return is_equal_approx(left, right)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_PHASE10_INSPECTOR_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
