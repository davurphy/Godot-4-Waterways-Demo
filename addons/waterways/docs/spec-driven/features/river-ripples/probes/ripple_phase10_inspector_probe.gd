extends SceneTree

const INSPECTOR_SCRIPT_PATH := "res://addons/waterways/ripple_inspector_plugin.gd"
const STATUS_SCRIPT_PATH := "res://addons/waterways/ripple_inspector_status.gd"
const PRESET_APPLY_MODEL_SCRIPT_PATH := "res://addons/waterways/ripple_inspector_preset_apply_model.gd"
const GIZMO_SCRIPT_PATH := "res://addons/waterways/ripple_gizmo.gd"
const GIZMO_GEOMETRY_SCRIPT_PATH := "res://addons/waterways/ripple_gizmo_geometry.gd"
const GIZMO_HANDLE_MODEL_SCRIPT_PATH := "res://addons/waterways/ripple_gizmo_handle_model.gd"
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
	var gizmo_script := load(GIZMO_SCRIPT_PATH) as Script
	var gizmo_geometry_script := load(GIZMO_GEOMETRY_SCRIPT_PATH) as Script
	var gizmo_handle_model_script := load(GIZMO_HANDLE_MODEL_SCRIPT_PATH) as Script
	var plugin_script := load(PLUGIN_SCRIPT_PATH) as Script
	var field_script := load(FIELD_SCRIPT_PATH) as Script
	var emitter_script := load(EMITTER_SCRIPT_PATH) as Script
	_expect(inspector_script != null, "Ripple inspector plugin script should load.")
	_expect(status_script != null and status_script.can_instantiate(), "Ripple inspector status helper should instantiate.")
	_expect(preset_apply_model_script != null and preset_apply_model_script.can_instantiate(), "Ripple preset apply model should instantiate.")
	_expect(gizmo_script != null, "Ripple gizmo plugin script should load.")
	_expect(gizmo_geometry_script != null and gizmo_geometry_script.can_instantiate(), "Ripple gizmo geometry helper should instantiate.")
	_expect(gizmo_handle_model_script != null and gizmo_handle_model_script.can_instantiate(), "Ripple gizmo handle model should instantiate.")
	_expect(plugin_script != null, "Waterways plugin script should still load.")
	_expect(field_script != null and field_script.can_instantiate(), "WaterRippleField script should still instantiate.")
	_expect(emitter_script != null and emitter_script.can_instantiate(), "WaterRippleEmitter script should still instantiate.")
	if status_script == null or preset_apply_model_script == null or gizmo_geometry_script == null or gizmo_handle_model_script == null or field_script == null or emitter_script == null:
		_finish()
		return

	_validate_static_boundaries()
	_validate_status_models(status_script, field_script, emitter_script)
	_validate_preset_apply_model(preset_apply_model_script, field_script, emitter_script)
	_validate_preset_capture_save_contract(field_script, emitter_script)
	_validate_gizmo_geometry(gizmo_geometry_script, field_script, emitter_script)
	_validate_gizmo_handle_model(gizmo_handle_model_script, field_script, emitter_script)

	print("RIPPLE_PHASE10_INSPECTOR_RESULTS=", _results)
	_finish()


func _validate_static_boundaries() -> void:
	var inspector_source := FileAccess.get_file_as_string(INSPECTOR_SCRIPT_PATH)
	var status_source := FileAccess.get_file_as_string(STATUS_SCRIPT_PATH)
	var preset_apply_model_source := FileAccess.get_file_as_string(PRESET_APPLY_MODEL_SCRIPT_PATH)
	var gizmo_source := FileAccess.get_file_as_string(GIZMO_SCRIPT_PATH)
	var gizmo_geometry_source := FileAccess.get_file_as_string(GIZMO_GEOMETRY_SCRIPT_PATH)
	var gizmo_handle_model_source := FileAccess.get_file_as_string(GIZMO_HANDLE_MODEL_SCRIPT_PATH)
	var plugin_source := FileAccess.get_file_as_string(PLUGIN_SCRIPT_PATH)
	var runtime_source := FileAccess.get_file_as_string(FIELD_SCRIPT_PATH) + "\n" + FileAccess.get_file_as_string(EMITTER_SCRIPT_PATH) + "\n" + FileAccess.get_file_as_string(FIELD_PRESET_SCRIPT_PATH) + "\n" + FileAccess.get_file_as_string(EMITTER_PRESET_SCRIPT_PATH)
	var editor_status_source := inspector_source + "\n" + status_source + "\n" + preset_apply_model_source + "\n" + gizmo_source + "\n" + gizmo_geometry_source + "\n" + gizmo_handle_model_source

	_expect(plugin_source.contains("RippleInspector"), "Waterways plugin should register the ripple inspector plugin.")
	_expect(plugin_source.contains("set_undo_redo_manager(get_undo_redo())"), "Waterways plugin should pass editor undo to the ripple inspector.")
	_expect(plugin_source.contains("add_inspector_plugin(ripple_inspector)"), "Waterways plugin should add the ripple inspector.")
	_expect(plugin_source.contains("remove_inspector_plugin(ripple_inspector)"), "Waterways plugin should remove the ripple inspector.")
	_expect(plugin_source.contains("RippleGizmo"), "Waterways plugin should register the ripple gizmo plugin.")
	_expect(plugin_source.contains("add_node_3d_gizmo_plugin(ripple_gizmo)"), "Waterways plugin should add the ripple gizmo.")
	_expect(plugin_source.contains("remove_node_3d_gizmo_plugin(ripple_gizmo)"), "Waterways plugin should remove the ripple gizmo.")
	_expect(plugin_source.contains("ripple_gizmo.set_undo_redo_manager(get_undo_redo())"), "Waterways plugin should pass editor undo to the ripple gizmo.")
	_expect(plugin_source.contains("ripple_gizmo.set_undo_redo_manager(null)"), "Waterways plugin should clear ripple gizmo editor undo on exit.")
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
	_expect(gizmo_source.contains("extends EditorNode3DGizmoPlugin"), "Ripple gizmo should use the Godot 3D gizmo plugin API.")
	_expect(gizmo_source.contains("func _has_gizmo"), "Ripple gizmo should declare handled nodes.")
	_expect(gizmo_source.contains("func _redraw"), "Ripple gizmo should draw helper overlays through _redraw.")
	_expect(gizmo_source.contains("add_collision_segments"), "Ripple gizmo should add simple picking collision for visual helper segments.")
	_expect(gizmo_source.contains("create_handle_material"), "Ripple gizmo should create a visible editor handle material.")
	_expect(gizmo_source.contains("const HANDLE_MATERIAL := \"handles\""), "Ripple gizmo should use Godot's registered handle material name.")
	_expect(gizmo_source.contains("add_handles"), "Ripple gizmo should add undo-backed emitter handles.")
	_expect(gizmo_source.contains("func _get_handle_value"), "Ripple gizmo should expose restore values for handle edits.")
	_expect(gizmo_source.contains("func _set_handle"), "Ripple gizmo should live-update whitelisted handle values while dragging.")
	_expect(gizmo_source.contains("func _commit_handle"), "Ripple gizmo should commit or cancel handle edits explicitly.")
	_expect(gizmo_source.contains("EditorUndoRedoManager"), "Ripple gizmo should use editor undo for handle commits.")
	_expect(gizmo_source.contains("add_do_property"), "Ripple gizmo should use per-property do operations for handles.")
	_expect(gizmo_source.contains("add_undo_property"), "Ripple gizmo should use per-property undo operations for handles.")
	_expect(gizmo_geometry_source.contains("build_field_segments"), "Ripple gizmo geometry helper should expose probeable field segments.")
	_expect(gizmo_geometry_source.contains("build_emitter_segments"), "Ripple gizmo geometry helper should expose probeable emitter segments.")
	_expect(gizmo_geometry_source.contains("build_handle_points_for_node"), "Ripple gizmo geometry helper should expose probeable handle positions.")
	_expect(gizmo_geometry_source.contains("emitter_handle_guides"), "Ripple gizmo geometry should expose a pickability guide for tiny moving-threshold handles.")
	_expect(not gizmo_geometry_source.contains("EditorNode3DGizmoPlugin"), "Ripple gizmo geometry helper should stay probeable without editor-only gizmo classes.")
	_expect(gizmo_handle_model_source.contains("HANDLE_EMITTER_RADIUS"), "Ripple handle model should name the emitter radius handle.")
	_expect(gizmo_handle_model_source.contains("HANDLE_EMITTER_MOVING_DISTANCE"), "Ripple handle model should name the moving-threshold handle.")
	_expect(gizmo_handle_model_source.contains("HANDLE_FIELD_MIN_X"), "Ripple handle model should name field bounds face handles.")
	_expect(gizmo_handle_model_source.contains("build_field_bounds_from_face_drag"), "Ripple handle model should expose field bounds drag math.")
	_expect(gizmo_handle_model_source.contains("MIN_PICKABLE_MOVING_HANDLE_DISTANCE"), "Ripple handle model should define a minimum visible moving-threshold handle distance.")
	_expect(gizmo_handle_model_source.contains("get_visual_handle_offset"), "Ripple handle model should expose visual offset math for tiny moving-threshold handles.")
	_expect(gizmo_handle_model_source.contains("build_property_change"), "Ripple handle model should expose no-op/change diff logic.")
	_expect(not gizmo_handle_model_source.contains("EditorNode3DGizmoPlugin"), "Ripple handle model should stay probeable without editor-only gizmo classes.")
	_expect(not gizmo_handle_model_source.contains("EditorUndoRedoManager"), "Ripple handle model should not own editor undo.")
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
	_expect(not runtime_source.contains("EditorNode3DGizmoPlugin"), "Runtime ripple scripts should not reference EditorNode3DGizmoPlugin.")
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


func _validate_gizmo_geometry(gizmo_geometry_script: Script, field_script: Script, emitter_script: Script) -> void:
	var geometry: Object = gizmo_geometry_script.new()
	var root_node := Node3D.new()
	root_node.name = "Phase10GizmoProbeRoot"
	root.add_child(root_node)

	var target := Node3D.new()
	target.name = "ProbeTargetRiverLikeNode"
	target.position = Vector3(18.0, 0.0, 32.0)
	root_node.add_child(target)

	var field := field_script.new() as Node3D
	field.name = "GizmoField"
	field.set("enabled", false)
	field.set("world_bounds", AABB(Vector3(10.0, -1.0, 20.0), Vector3(12.0, 2.0, 18.0)))
	root_node.add_child(field)
	var target_paths: Array[NodePath] = [field.get_path_to(target)]
	field.set("target_river_paths", target_paths)

	var emitter := emitter_script.new() as Node3D
	emitter.name = "GizmoEmitter"
	emitter.position = Vector3(13.0, 0.0, 24.0)
	emitter.set("enabled", false)
	emitter.set("radius", 2.5)
	emitter.set("emitter_mode", 3)
	emitter.set("moving_emit_distance", 0.75)
	root_node.add_child(emitter)
	emitter.set("target_field_path", emitter.get_path_to(field))

	var field_before := _read_field_values(field)
	var emitter_before := _read_emitter_values(emitter)
	_expect(bool(geometry.call("can_build_for_node", field)), "Ripple gizmo geometry should recognize WaterRippleField.")
	_expect(bool(geometry.call("can_build_for_node", emitter)), "Ripple gizmo geometry should recognize WaterRippleEmitter.")
	_expect(not bool(geometry.call("can_build_for_node", target)), "Ripple gizmo geometry should ignore unrelated Node3D nodes.")

	var field_segments: Dictionary = geometry.call("build_segments_for_node", field)
	var emitter_segments: Dictionary = geometry.call("build_segments_for_node", emitter)
	var field_bounds: PackedVector3Array = field_segments.get("field_bounds", PackedVector3Array())
	var field_footprint: PackedVector3Array = field_segments.get("field_footprint", PackedVector3Array())
	var field_routes: PackedVector3Array = field_segments.get("field_routes", PackedVector3Array())
	var emitter_radius: PackedVector3Array = emitter_segments.get("emitter_radius", PackedVector3Array())
	var emitter_moving: PackedVector3Array = emitter_segments.get("emitter_moving", PackedVector3Array())
	var emitter_handle_guides: PackedVector3Array = emitter_segments.get("emitter_handle_guides", PackedVector3Array())
	var emitter_route: PackedVector3Array = emitter_segments.get("emitter_route", PackedVector3Array())
	var field_handles: Dictionary = geometry.call("build_handle_points_for_node", field)
	var emitter_handles: Dictionary = geometry.call("build_handle_points_for_node", emitter)
	var field_handle_positions: PackedVector3Array = field_handles.get("positions", PackedVector3Array())
	var field_handle_ids: PackedInt32Array = field_handles.get("ids", PackedInt32Array())
	var emitter_handle_positions: PackedVector3Array = emitter_handles.get("positions", PackedVector3Array())
	var emitter_handle_ids: PackedInt32Array = emitter_handles.get("ids", PackedInt32Array())

	var pulse_emitter := emitter_script.new() as Node3D
	pulse_emitter.name = "GizmoPulseEmitter"
	pulse_emitter.position = Vector3(12.0, 0.0, 22.0)
	pulse_emitter.set("enabled", false)
	pulse_emitter.set("radius", 1.25)
	pulse_emitter.set("emitter_mode", 0)
	root_node.add_child(pulse_emitter)
	var pulse_handles: Dictionary = geometry.call("build_handle_points_for_node", pulse_emitter)
	var pulse_handle_positions: PackedVector3Array = pulse_handles.get("positions", PackedVector3Array())
	var pulse_handle_ids: PackedInt32Array = pulse_handles.get("ids", PackedInt32Array())

	var tiny_moving_emitter := emitter_script.new() as Node3D
	tiny_moving_emitter.name = "GizmoTinyMovingEmitter"
	tiny_moving_emitter.position = Vector3(11.0, 0.0, 21.0)
	tiny_moving_emitter.set("enabled", false)
	tiny_moving_emitter.set("radius", 1.35)
	tiny_moving_emitter.set("emitter_mode", 3)
	tiny_moving_emitter.set("moving_emit_distance", 0.08)
	root_node.add_child(tiny_moving_emitter)
	var tiny_segments: Dictionary = geometry.call("build_segments_for_node", tiny_moving_emitter)
	var tiny_handle_guides: PackedVector3Array = tiny_segments.get("emitter_handle_guides", PackedVector3Array())
	var tiny_handles: Dictionary = geometry.call("build_handle_points_for_node", tiny_moving_emitter)
	var tiny_handle_positions: PackedVector3Array = tiny_handles.get("positions", PackedVector3Array())
	var tiny_handle_ids: PackedInt32Array = tiny_handles.get("ids", PackedInt32Array())

	_expect(field_bounds.size() == 24, "Field bounds gizmo should draw twelve AABB edges.")
	_expect(field_footprint.size() == 12, "Field footprint gizmo should draw the X/Z rectangle plus center cross.")
	_expect(field_routes.size() == 2, "Field gizmo should draw explicit target path route lines without resolving private caches.")
	_expect(emitter_radius.size() == 128, "Emitter radius gizmo should draw a 64-segment radius ring.")
	_expect(emitter_moving.size() == 64, "Moving emitter gizmo should draw a dashed movement-threshold ring.")
	_expect(emitter_handle_guides.is_empty(), "Moving emitter should not draw a pickability guide when the threshold handle is already reachable.")
	_expect(emitter_route.size() == 2, "Emitter gizmo should draw one resolved field route line.")
	_expect(field_handle_positions.size() == 6, "Field gizmo should expose six world_bounds face handles.")
	_expect(field_handle_ids.size() == 6, "Field gizmo handle IDs should match field handle positions.")
	_expect(field_handle_ids.size() >= 6 and field_handle_ids[0] == 2001 and field_handle_ids[5] == 2006, "Field bounds handles should use stable face IDs.")
	_expect(emitter_handle_positions.size() == 2, "Moving emitter gizmo should expose radius and moving-threshold handles.")
	_expect(emitter_handle_ids.size() == 2, "Moving emitter gizmo handle IDs should match handle positions.")
	_expect(emitter_handle_ids.size() >= 2 and emitter_handle_ids[0] == 1001 and emitter_handle_ids[1] == 1002, "Moving emitter handles should use stable radius and moving-threshold IDs.")
	_expect(pulse_handle_positions.size() == 1, "Non-moving emitter gizmo should expose only a radius handle.")
	_expect(pulse_handle_ids.size() == 1 and pulse_handle_ids[0] == 1001, "Non-moving emitter handle should use the radius ID.")
	_expect(_approximately(field_bounds[0].x, 10.0) and _approximately(field_bounds[0].z, 20.0), "Field bounds should use world_bounds as the helper source.")
	_expect(field_handle_positions.size() >= 6 and _approximately(field_handle_positions[0].x, 10.0) and _approximately(field_handle_positions[0].z, 29.0), "Field min-X handle should sit at the min-X face center.")
	_expect(field_handle_positions.size() >= 6 and _approximately(field_handle_positions[1].x, 22.0) and _approximately(field_handle_positions[1].z, 29.0), "Field max-X handle should sit at the max-X face center.")
	_expect(field_handle_positions.size() >= 6 and _approximately(field_handle_positions[2].y, -1.0) and _approximately(field_handle_positions[3].y, 1.0), "Field Y handles should sit at the min/max Y face centers.")
	_expect(field_handle_positions.size() >= 6 and _approximately(field_handle_positions[4].z, 20.0) and _approximately(field_handle_positions[5].z, 38.0), "Field Z handles should sit at the min/max Z face centers.")
	_expect(_approximately(emitter_radius[0].x, 2.5) and _approximately(emitter_radius[0].z, 0.0), "Emitter radius helper should draw in local gizmo space with the configured world radius.")
	_expect(emitter_handle_positions.size() >= 2 and _approximately(emitter_handle_positions[0].x, 2.5) and _approximately(emitter_handle_positions[0].z, 0.0), "Emitter radius handle should sit on the radius ring.")
	_expect(emitter_handle_positions.size() >= 2 and _approximately(emitter_handle_positions[1].x, 0.0) and _approximately(emitter_handle_positions[1].z, 0.75), "Moving-threshold handle should sit on the dashed moving ring.")
	_expect(tiny_handle_positions.size() >= 2 and tiny_handle_ids.size() >= 2 and tiny_handle_ids[1] == 1002, "Tiny moving-threshold emitters should still expose the moving handle ID.")
	_expect(tiny_handle_positions.size() >= 2 and _approximately(tiny_handle_positions[1].x, 0.0) and _approximately(tiny_handle_positions[1].z, 0.75), "Tiny moving-threshold handle should use the minimum pickable grip distance.")
	_expect(tiny_handle_guides.size() == 2 and _approximately(tiny_handle_guides[0].z, 0.08) and _approximately(tiny_handle_guides[1].z, 0.75), "Tiny moving-threshold handle should draw a guide from the real dashed ring to the pickable grip.")
	_expect(_read_field_values(field) == field_before, "Building field gizmo geometry should not mutate exported values.")
	_expect(_read_emitter_values(emitter) == emitter_before, "Building emitter gizmo geometry should not mutate exported values.")
	_expect(field.get_child_count() == 0, "Building field gizmo geometry should not add preview children.")
	_expect(emitter.get_child_count() == 0, "Building emitter gizmo geometry should not add preview children.")

	_results["field_gizmo_segments"] = {
		"bounds": field_bounds.size(),
		"footprint": field_footprint.size(),
		"routes": field_routes.size(),
	}
	_results["emitter_gizmo_segments"] = {
		"radius": emitter_radius.size(),
		"moving": emitter_moving.size(),
		"tiny_handle_guides": tiny_handle_guides.size(),
		"route": emitter_route.size(),
	}
	_results["emitter_gizmo_handles"] = {
		"moving_handles": emitter_handle_positions.size(),
		"pulse_handles": pulse_handle_positions.size(),
		"tiny_moving_handles": tiny_handle_positions.size(),
	}
	_results["field_gizmo_handles"] = {
		"field_handles": field_handle_positions.size(),
		"first_id": field_handle_ids[0] if field_handle_ids.size() > 0 else -1,
		"last_id": field_handle_ids[field_handle_ids.size() - 1] if field_handle_ids.size() > 0 else -1,
	}
	root_node.free()


func _validate_gizmo_handle_model(handle_model_script: Script, field_script: Script, emitter_script: Script) -> void:
	var model: Object = handle_model_script.new()
	var radius_id := 1001
	var moving_id := 1002
	var field_min_x_id := 2001
	var field_max_x_id := 2002
	var field_min_y_id := 2003
	var field_max_y_id := 2004
	var field_min_z_id := 2005
	var field_max_z_id := 2006
	var root_node := Node3D.new()
	root_node.name = "Phase10GizmoHandleProbeRoot"
	root.add_child(root_node)

	var field := field_script.new() as Node3D
	field.name = "HandleProbeField"
	field.set("enabled", false)
	field.set("world_bounds", AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 2.0, 8.0)))
	root_node.add_child(field)

	var emitter := emitter_script.new() as Node3D
	emitter.name = "HandleProbeEmitter"
	emitter.set("enabled", false)
	emitter.set("emitter_mode", 3)
	emitter.set("radius", 2.5)
	emitter.set("moving_emit_distance", 0.75)
	emitter.set("target_field_path", NodePath("../HandleProbeField"))
	root_node.add_child(emitter)

	var field_before := _read_field_values(field)
	var emitter_before := _read_emitter_values(emitter)
	_expect(bool(model.call("can_edit_handle", field, field_min_x_id)), "Handle model should edit field min-X bounds handles.")
	_expect(bool(model.call("can_edit_handle", field, field_max_x_id)), "Handle model should edit field max-X bounds handles.")
	_expect(bool(model.call("can_edit_handle", field, field_min_y_id)), "Handle model should edit field min-Y bounds handles.")
	_expect(bool(model.call("can_edit_handle", field, field_max_y_id)), "Handle model should edit field max-Y bounds handles.")
	_expect(bool(model.call("can_edit_handle", field, field_min_z_id)), "Handle model should edit field min-Z bounds handles.")
	_expect(bool(model.call("can_edit_handle", field, field_max_z_id)), "Handle model should edit field max-Z bounds handles.")
	_expect(bool(model.call("can_edit_handle", emitter, radius_id)), "Handle model should edit emitter radius handles.")
	_expect(bool(model.call("can_edit_handle", emitter, moving_id)), "Handle model should edit moving-threshold handles.")
	_expect(not bool(model.call("can_edit_handle", field, radius_id)), "Field nodes should not accept emitter radius handles.")
	_expect(not bool(model.call("can_edit_handle", emitter, field_min_x_id)), "Emitter nodes should not accept field bounds handles.")
	_expect(String(model.call("get_property_name", field_min_x_id)) == "world_bounds", "Field face handles should map to world_bounds.")
	_expect(String(model.call("get_property_name", radius_id)) == "radius", "Radius handle should map to the radius property.")
	_expect(String(model.call("get_property_name", moving_id)) == "moving_emit_distance", "Moving handle should map to moving_emit_distance.")
	_expect(String(model.call("get_handle_name", field_max_z_id)).contains("Max Z"), "Field face handles should have readable labels.")
	_expect(String(model.call("get_action_name", field_min_y_id)).contains("Field Bounds"), "Field bounds handles should have a readable undo action label.")
	_expect(String(model.call("get_handle_name", radius_id)).contains("Radius"), "Radius handle should have a readable label.")
	_expect(String(model.call("get_action_name", moving_id)).contains("Moving"), "Moving handle should have a readable undo action label.")
	_expect(_approximately(float(model.call("get_visual_handle_value", moving_id, 0.08)), 0.75), "Tiny moving-threshold values should get a pickable visual handle distance.")
	_expect(_approximately(float(model.call("get_visual_handle_offset", moving_id, 0.08)), 0.67), "Tiny moving-threshold visual offsets should preserve no-jump drag math.")
	_expect(_approximately(float(model.call("get_visual_handle_offset", moving_id, 0.75)), 0.0), "Normal moving-threshold handles should not use a visual offset.")

	var field_ids: PackedInt32Array = model.call("get_handle_ids_for_node", field)
	_expect(field_ids.size() == 6 and field_ids[0] == field_min_x_id and field_ids[5] == field_max_z_id, "Fields should expose stable six-face world_bounds handle IDs.")
	var moving_ids: PackedInt32Array = model.call("get_handle_ids_for_node", emitter)
	_expect(moving_ids.size() == 2 and moving_ids[0] == radius_id and moving_ids[1] == moving_id, "Moving emitters should expose radius and moving-threshold handle IDs.")
	emitter.set("emitter_mode", 0)
	var pulse_ids: PackedInt32Array = model.call("get_handle_ids_for_node", emitter)
	_expect(pulse_ids.size() == 1 and pulse_ids[0] == radius_id, "Non-moving emitters should expose only radius handle IDs.")
	emitter.set("emitter_mode", 3)

	var field_restore: AABB = model.call("get_handle_value", field, field_min_x_id)
	_expect(field_restore == AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 2.0, 8.0)), "Field handle restore value should read the current world_bounds.")
	var field_min_x_drag: AABB = model.call("build_field_bounds_from_face_drag", field_restore, field_min_x_id, Vector3(-5.5, 99.0, 99.0))
	_expect(_approximately(field_min_x_drag.position.x, -5.5), "Dragging min-X should move only the min-X face.")
	_expect(_approximately(field_min_x_drag.size.x, 9.5), "Dragging min-X should keep the max-X face fixed.")
	_expect(_approximately(field_min_x_drag.position.y, -1.0) and _approximately(field_min_x_drag.position.z, -4.0), "Dragging min-X should not alter Y/Z origins.")
	_expect(bool(model.call("apply_handle_value", field, field_min_x_id, field_min_x_drag)), "Handle model should apply a world_bounds drag value.")
	var field_change: Dictionary = model.call("build_property_change", field, field_min_x_id, field_restore)
	_expect(String(field_change.get("property", "")) == "world_bounds", "Field handle change should report world_bounds.")
	var changed_bounds: AABB = field_change.get("new_value", AABB())
	_expect(_approximately(changed_bounds.position.x, -5.5), "Field handle change should report the final bounds value.")
	_expect(bool(model.call("apply_handle_value", field, field_min_x_id, field_restore)), "Handle model should restore field bounds for no-op/cancel behavior.")
	_expect((model.call("build_property_change", field, field_min_x_id, field_restore) as Dictionary).is_empty(), "No-op field handle commits should produce no property change.")
	var clamped_bounds: AABB = model.call("build_field_bounds_from_face_drag", field_restore, field_max_x_id, Vector3(-100.0, 0.0, 0.0))
	_expect(_approximately(clamped_bounds.size.x, 0.001), "Field max-X handle should clamp before flipping past min-X.")
	var dragged_min_y: AABB = model.call("build_field_bounds_from_face_drag", field_restore, field_min_y_id, Vector3(0.0, -3.0, 0.0))
	var dragged_max_z: AABB = model.call("build_field_bounds_from_face_drag", field_restore, field_max_z_id, Vector3(0.0, 0.0, 7.0))
	_expect(_approximately(dragged_min_y.position.y, -3.0) and _approximately(dragged_min_y.size.y, 4.0), "Field min-Y handle should keep max-Y fixed.")
	_expect(_approximately(dragged_max_z.position.z, -4.0) and _approximately(dragged_max_z.size.z, 11.0), "Field max-Z handle should keep min-Z fixed.")

	var radius_restore: float = model.call("get_handle_value", emitter, radius_id)
	_expect(_approximately(radius_restore, 2.5), "Handle restore value should read the current emitter radius.")
	_expect(bool(model.call("apply_handle_value", emitter, radius_id, 3.75)), "Handle model should apply a radius drag value.")
	var radius_change: Dictionary = model.call("build_property_change", emitter, radius_id, radius_restore)
	_expect(String(radius_change.get("property", "")) == "radius", "Radius handle change should report the radius property.")
	_expect(_approximately(float(radius_change.get("old_value", 0.0)), 2.5), "Radius handle change should keep the restore value.")
	_expect(_approximately(float(radius_change.get("new_value", 0.0)), 3.75), "Radius handle change should report the final radius value.")
	_expect(bool(model.call("apply_handle_value", emitter, radius_id, radius_restore)), "Handle model should restore radius values for no-op/cancel behavior.")
	_expect((model.call("build_property_change", emitter, radius_id, radius_restore) as Dictionary).is_empty(), "No-op radius handle commits should produce no property change.")

	var moving_restore: float = model.call("get_handle_value", emitter, moving_id)
	_expect(bool(model.call("apply_handle_value", emitter, moving_id, 1.5)), "Handle model should apply a moving-threshold drag value.")
	var moving_change: Dictionary = model.call("build_property_change", emitter, moving_id, moving_restore)
	_expect(String(moving_change.get("property", "")) == "moving_emit_distance", "Moving handle change should report moving_emit_distance.")
	_expect(_approximately(float(moving_change.get("old_value", 0.0)), 0.75), "Moving handle change should keep the restore value.")
	_expect(_approximately(float(moving_change.get("new_value", 0.0)), 1.5), "Moving handle change should report the final value.")

	model.call("apply_handle_value", emitter, radius_id, 128.0)
	_expect(_approximately(float(emitter.get("radius")), 64.0), "Radius handle should clamp to the exported maximum.")
	model.call("apply_handle_value", emitter, moving_id, -10.0)
	_expect(_approximately(float(emitter.get("moving_emit_distance")), 0.001), "Moving handle should clamp to the exported minimum.")

	_expect(String(field.get("target_group_name")) == String(field_before.get("target_group_name")), "Field bounds handle edits should not change field target groups.")
	_expect(field.get("auto_generate_boundary_mask") == field_before.get("auto_generate_boundary_mask"), "Field bounds handle edits should not change boundary settings.")
	_expect(String(emitter.get("target_field_path")) == String(emitter_before.get("target_field_path")), "Handle edits should not change emitter routing.")
	_expect(String(emitter.get("field_group_name")) == String(emitter_before.get("field_group_name")), "Handle edits should not change emitter groups.")
	_expect(field.get("world_bounds") == AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 2.0, 8.0)), "Emitter handle edits should not change field bounds.")

	_results["field_handle_model"] = {
		"field_property": String(model.call("get_property_name", field_min_x_id)),
		"field_ids": field_ids.size(),
		"clamped_min_size": clamped_bounds.size.x,
	}
	_results["emitter_handle_model"] = {
		"radius_property": String(model.call("get_property_name", radius_id)),
		"moving_property": String(model.call("get_property_name", moving_id)),
		"moving_ids": moving_ids.size(),
		"pulse_ids": pulse_ids.size(),
	}
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
		"moving_emit_distance": emitter.get("moving_emit_distance"),
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
