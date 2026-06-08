extends SceneTree

const RiverManager = preload("res://addons/waterways/river_manager.gd")
const FIELD_SCRIPT_PATH := "res://addons/waterways/water_ripple_field.gd"
const EMITTER_SCRIPT_PATH := "res://addons/waterways/water_ripple_emitter.gd"
const FIELD_PRESET_SCRIPT_PATH := "res://addons/waterways/resources/water_ripple_field_preset.gd"
const EMITTER_PRESET_SCRIPT_PATH := "res://addons/waterways/resources/water_ripple_emitter_preset.gd"
const FieldPresetResource := preload("res://addons/waterways/resources/water_ripple_field_preset.gd")
const EmitterPresetResource := preload("res://addons/waterways/resources/water_ripple_emitter_preset.gd")
const SCRATCH_DIR := "res://.codex-research/ripple-phase9-authoring"
const SCRATCH_SCENE_PATH := SCRATCH_DIR + "/phase9_scene_reload_probe.tscn"
const SCRATCH_FIELD_PRESET_PATH := SCRATCH_DIR + "/phase9_field_preset_reload_probe.tres"
const SCRATCH_EMITTER_PRESET_PATH := SCRATCH_DIR + "/phase9_emitter_preset_reload_probe.tres"

var _errors := PackedStringArray()
var _results := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var field_script := load(FIELD_SCRIPT_PATH) as Script
	var emitter_script := load(EMITTER_SCRIPT_PATH) as Script
	var field_preset_script := load(FIELD_PRESET_SCRIPT_PATH) as Script
	var emitter_preset_script := load(EMITTER_PRESET_SCRIPT_PATH) as Script
	_expect(field_script != null and field_script.can_instantiate(), "WaterRippleField script should instantiate.")
	_expect(emitter_script != null and emitter_script.can_instantiate(), "WaterRippleEmitter script should instantiate.")
	_expect(field_preset_script != null and field_preset_script.can_instantiate(), "WaterRippleFieldPreset script should instantiate.")
	_expect(emitter_preset_script != null and emitter_preset_script.can_instantiate(), "WaterRippleEmitterPreset script should instantiate.")
	if field_script == null or emitter_script == null or field_preset_script == null or emitter_preset_script == null:
		_finish()
		return

	_validate_static_contract(field_script, emitter_script, field_preset_script, emitter_preset_script)
	_validate_builtin_presets(field_script, emitter_script)
	_validate_field_copy_contract(field_script, field_preset_script, emitter_preset_script)
	_validate_emitter_copy_contract(emitter_script, emitter_preset_script, field_preset_script)
	await _validate_runtime_field_apply(field_script)
	await _validate_scene_save_reload(field_script, emitter_script)

	print("RIPPLE_PHASE9_PRESET_API_RESULTS=", _results)
	_finish()


func _validate_static_contract(field_script: Script, emitter_script: Script, field_preset_script: Script, emitter_preset_script: Script) -> void:
	var field := field_script.new() as Node3D
	var emitter := emitter_script.new() as Node3D
	var field_preset := field_preset_script.new() as Resource
	var emitter_preset := emitter_preset_script.new() as Resource
	_expect(not _has_property(field, "field_preset"), "WaterRippleField should not expose a field_preset slot.")
	_expect(not _has_property(field, "preset"), "WaterRippleField should not expose a generic preset slot.")
	_expect(not _has_property(emitter, "emitter_preset"), "WaterRippleEmitter should not expose an emitter_preset slot.")
	_expect(not _has_property(emitter, "preset"), "WaterRippleEmitter should not expose a generic preset slot.")
	_expect(_property_is_storage_only(field, "debug_visible"), "debug_visible should be stored without normal inspector visibility in Phase 9.")
	_expect(_property_is_storage_only(field, "refraction_strength"), "refraction_strength should stay stored without normal inspector visibility in Phase 9.")
	_expect(_property_is_storage_only(field, "displacement_strength"), "displacement_strength should stay stored without normal inspector visibility in Phase 9.")
	_expect(_export_groups_include(field, ["Setup", "Targets", "Boundary Mask", "Simulation", "Visual Response"]), "WaterRippleField should expose the planned ordinary export groups.")
	_expect(_export_groups_include(emitter, ["Routing", "Shape", "Emission", "Priority And Caps"]), "WaterRippleEmitter should expose the planned ordinary export groups.")
	_expect(_export_groups_include(field_preset, ["Simulation", "Visual Response", "Boundary Mask"]), "WaterRippleFieldPreset should expose grouped authoring values.")
	_expect(_export_groups_include(emitter_preset, ["Emission", "Shape", "Priority And Caps"]), "WaterRippleEmitterPreset should expose grouped authoring values.")

	var field_source := FileAccess.get_file_as_string(FIELD_SCRIPT_PATH)
	var emitter_source := FileAccess.get_file_as_string(EMITTER_SCRIPT_PATH)
	var field_preset_source := FileAccess.get_file_as_string(FIELD_PRESET_SCRIPT_PATH)
	var emitter_preset_source := FileAccess.get_file_as_string(EMITTER_PRESET_SCRIPT_PATH)
	var combined_source := field_source + "\n" + emitter_source + "\n" + field_preset_source + "\n" + emitter_preset_source
	_expect(not combined_source.contains("ResourceSaver"), "Phase 9 runtime preset API should not call ResourceSaver.")
	_expect(not combined_source.contains(".tres"), "Phase 9 runtime preset API should not create .tres paths.")
	field.free()
	emitter.free()


func _validate_builtin_presets(field_script: Script, emitter_script: Script) -> void:
	var field_names := FieldPresetResource.get_builtin_preset_names()
	var emitter_names := EmitterPresetResource.get_builtin_preset_names()
	_expect(field_names.size() == 6, "Field built-in preset list should contain the approved six starters.")
	_expect(emitter_names.size() == 7, "Emitter built-in preset list should contain the approved seven starters.")
	_expect(field_names.has("Calm Local Field"), "Field presets should include Calm Local Field.")
	_expect(field_names.has("Character Interaction Field"), "Field presets should include Character Interaction Field.")
	_expect(field_names.has("Rain-Sized Local Field"), "Field presets should include Rain-Sized Local Field.")
	_expect(field_names.has("Heavy Impact Field"), "Field presets should include Heavy Impact Field.")
	_expect(field_names.has("Performance Field"), "Field presets should include Performance Field.")
	_expect(field_names.has("Debug Strong Field"), "Field presets should include Debug Strong Field.")
	_expect(emitter_names.has("Footstep"), "Emitter presets should include Footstep.")
	_expect(emitter_names.has("Wading Character"), "Emitter presets should include Wading Character.")
	_expect(emitter_names.has("NPC Ambient"), "Emitter presets should include NPC Ambient.")
	_expect(emitter_names.has("Small Impact"), "Emitter presets should include Small Impact.")
	_expect(emitter_names.has("Heavy Impact"), "Emitter presets should include Heavy Impact.")
	_expect(emitter_names.has("Light Rain Drop"), "Emitter presets should include Light Rain Drop.")
	_expect(emitter_names.has("Static River Disturbance"), "Emitter presets should include Static River Disturbance.")
	_expect(not field_names.has("Heavy Rain"), "Field built-ins should not promise a dense rain system.")
	_expect(not emitter_names.has("Boat/Oar Wake"), "Emitter built-ins should not promise unsupported wake shapes.")

	var first_field_builtin := FieldPresetResource.create_builtin_preset("Character Interaction Field") as Resource
	var second_field_builtin := FieldPresetResource.create_builtin_preset("Character Interaction Field") as Resource
	_expect(first_field_builtin != null and second_field_builtin != null, "Field built-in factory should return resources for known names.")
	_expect(first_field_builtin != second_field_builtin, "Field built-in factory should return fresh resources.")
	_expect(first_field_builtin.resource_path.is_empty(), "Field built-in resources should be in-memory starters.")
	_expect(first_field_builtin.resource_name == "Character Interaction Field", "Field built-in resource should carry its starter name.")
	_expect(FieldPresetResource.create_builtin_preset("Unsupported Field Starter") == null, "Unknown field built-in preset should return null.")

	var field := field_script.new() as Node3D
	field.set("target_group_name", "unchanged_targets")
	field.set("field_group_name", "unchanged_fields")
	field.set("refraction_strength", 0.42)
	field.set("displacement_strength", 0.24)
	_expect(bool(field.call("apply_builtin_preset", "Debug Strong Field")), "Field should apply a known built-in starter by name.")
	_expect(_approximately(float(field.get("ripple_strength")), 2.25), "Debug Strong Field should copy ripple_strength.")
	_expect(_approximately(float(field.get("normal_strength")), 3.0), "Debug Strong Field should copy normal_strength.")
	_expect(String(field.get("target_group_name")) == "unchanged_targets", "Field built-in preset should not change target_group_name.")
	_expect(String(field.get("field_group_name")) == "unchanged_fields", "Field built-in preset should not change field_group_name.")
	_expect(_approximately(float(field.get("refraction_strength")), 0.42), "Field built-in preset should not change reserved refraction_strength.")
	_expect(_approximately(float(field.get("displacement_strength")), 0.24), "Field built-in preset should not change reserved displacement_strength.")
	_expect(not bool(field.call("apply_builtin_preset", "Boat Wake")), "Field should reject unknown built-in starters.")
	field.free()

	var first_emitter_builtin := EmitterPresetResource.create_builtin_preset("Wading Character") as Resource
	var second_emitter_builtin := EmitterPresetResource.create_builtin_preset("Wading Character") as Resource
	_expect(first_emitter_builtin != null and second_emitter_builtin != null, "Emitter built-in factory should return resources for known names.")
	_expect(first_emitter_builtin != second_emitter_builtin, "Emitter built-in factory should return fresh resources.")
	_expect(first_emitter_builtin.resource_path.is_empty(), "Emitter built-in resources should be in-memory starters.")
	_expect(first_emitter_builtin.resource_name == "Wading Character", "Emitter built-in resource should carry its starter name.")
	_expect(EmitterPresetResource.create_builtin_preset("Capsule Wake") == null, "Unknown emitter built-in preset should return null.")

	var emitter := emitter_script.new() as Node3D
	emitter.set("enabled", false)
	emitter.set("target_field_path", NodePath("../OriginalField"))
	emitter.set("field_group_name", "unchanged_field_group")
	_expect(bool(emitter.call("apply_builtin_preset", "Heavy Impact")), "Emitter should apply a known built-in starter by name.")
	_expect(int(emitter.get("emitter_mode")) == EmitterPresetResource.MODE_ONE_SHOT, "Heavy Impact should use the current one-shot emitter behavior.")
	_expect(_approximately(float(emitter.get("radius")), 3.0), "Heavy Impact should copy radius.")
	_expect(_approximately(float(emitter.get("intensity")), 1.0), "Heavy Impact should copy intensity.")
	_expect(NodePath(emitter.get("target_field_path")) == NodePath("../OriginalField"), "Emitter built-in preset should not change target_field_path.")
	_expect(String(emitter.get("field_group_name")) == "unchanged_field_group", "Emitter built-in preset should not change field_group_name.")
	_expect(not bool(emitter.call("apply_builtin_preset", "Heavy Rain")), "Emitter should reject unknown built-in starters.")
	emitter.free()

	_results["builtins"] = {
		"field_names": field_names,
		"emitter_names": emitter_names,
	}


func _validate_field_copy_contract(field_script: Script, field_preset_script: Script, wrong_preset_script: Script) -> void:
	var field := field_script.new() as Node3D
	field.set("enabled", false)
	field.set("target_group_name", "unchanged_targets")
	field.set("field_group_name", "unchanged_fields")
	field.set("resolution", 128)
	field.set("max_emitters", 2)
	field.set("refraction_strength", 0.37)
	field.set("displacement_strength", 0.49)

	var preset := field_preset_script.new() as Resource
	preset.set("resolution", 96)
	preset.set("simulation_update_rate", 30.0)
	preset.set("damping", 0.91)
	preset.set("propagation", 0.7)
	preset.set("max_emitters", 5)
	preset.set("ripple_strength", 1.8)
	preset.set("normal_strength", 2.4)
	preset.set("height_fade_distance", 18.0)
	preset.set("boundary_fade", 0.04)
	preset.set("auto_generate_boundary_mask", false)
	preset.set("require_boundary_mask", false)

	var wrong_preset := wrong_preset_script.new() as Resource
	_expect(not bool(field.call("apply_preset", wrong_preset)), "Field should reject an emitter preset.")
	_expect(bool(field.call("apply_preset", preset)), "Field should accept a WaterRippleFieldPreset.")
	_expect(int(field.get("resolution")) == 96, "Field preset should copy resolution.")
	_expect(_approximately(float(field.get("simulation_update_rate")), 30.0), "Field preset should copy simulation_update_rate.")
	_expect(_approximately(float(field.get("damping")), 0.91), "Field preset should copy damping.")
	_expect(_approximately(float(field.get("propagation")), 0.7), "Field preset should copy propagation.")
	_expect(int(field.get("max_emitters")) == 5, "Field preset should copy max_emitters.")
	_expect(_approximately(float(field.get("ripple_strength")), 1.8), "Field preset should copy ripple_strength.")
	_expect(_approximately(float(field.get("normal_strength")), 2.4), "Field preset should copy normal_strength.")
	_expect(_approximately(float(field.get("height_fade_distance")), 18.0), "Field preset should copy height_fade_distance.")
	_expect(_approximately(float(field.get("boundary_fade")), 0.04), "Field preset should copy boundary_fade.")
	_expect(not bool(field.get("auto_generate_boundary_mask")), "Field preset should copy auto_generate_boundary_mask.")
	_expect(not bool(field.get("require_boundary_mask")), "Field preset should copy require_boundary_mask.")
	_expect(String(field.get("target_group_name")) == "unchanged_targets", "Field preset should not change target_group_name.")
	_expect(String(field.get("field_group_name")) == "unchanged_fields", "Field preset should not change field_group_name.")
	_expect(_approximately(float(field.get("refraction_strength")), 0.37), "Field preset should not change reserved refraction_strength.")
	_expect(_approximately(float(field.get("displacement_strength")), 0.49), "Field preset should not change reserved displacement_strength.")

	preset.set("normal_strength", 7.5)
	preset.set("resolution", 512)
	_expect(_approximately(float(field.get("normal_strength")), 2.4), "Editing a source field preset after apply should not mutate the field.")
	_expect(int(field.get("resolution")) == 96, "Editing source field preset resolution after apply should not mutate the field.")

	var captured := field.call("capture_preset") as Resource
	_expect(captured != null, "Field capture should return a resource.")
	_expect(captured != preset, "Field capture should return a new resource.")
	_expect(captured.get_script() == field_preset_script, "Field capture should return WaterRippleFieldPreset.")
	_expect(captured.resource_path.is_empty(), "Field capture should stay in memory without a resource path.")
	_expect(int(captured.get("resolution")) == int(field.get("resolution")), "Captured field preset should copy current resolution.")
	_expect(_approximately(float(captured.get("normal_strength")), float(field.get("normal_strength"))), "Captured field preset should copy current normal strength.")
	captured.set("normal_strength", 0.25)
	_expect(_approximately(float(field.get("normal_strength")), 2.4), "Editing a captured field preset should not mutate the field.")

	_results["field_copy"] = {
		"resolution": field.get("resolution"),
		"normal_strength": field.get("normal_strength"),
		"captured_path": captured.resource_path,
	}
	field.free()


func _validate_emitter_copy_contract(emitter_script: Script, emitter_preset_script: Script, wrong_preset_script: Script) -> void:
	var emitter := emitter_script.new() as Node3D
	emitter.set("enabled", false)
	emitter.set("target_field_path", NodePath("../OriginalField"))
	emitter.set("field_group_name", "unchanged_field_group")

	var preset := emitter_preset_script.new() as Resource
	preset.set("emitter_mode", 3)
	preset.set("radius", 2.75)
	preset.set("intensity", 0.62)
	preset.set("falloff", 3.5)
	preset.set("pulse_rate", 8.0)
	preset.set("emit_on_ready", true)
	preset.set("moving_emit_distance", 0.3)
	preset.set("priority", 9)

	var wrong_preset := wrong_preset_script.new() as Resource
	_expect(not bool(emitter.call("apply_preset", wrong_preset)), "Emitter should reject a field preset.")
	_expect(bool(emitter.call("apply_preset", preset)), "Emitter should accept a WaterRippleEmitterPreset.")
	_expect(not bool(emitter.get("enabled")), "Emitter preset should not change enabled.")
	_expect(NodePath(emitter.get("target_field_path")) == NodePath("../OriginalField"), "Emitter preset should not change target_field_path.")
	_expect(String(emitter.get("field_group_name")) == "unchanged_field_group", "Emitter preset should not change field_group_name.")
	_expect(int(emitter.get("emitter_mode")) == 3, "Emitter preset should copy emitter_mode.")
	_expect(_approximately(float(emitter.get("radius")), 2.75), "Emitter preset should copy radius.")
	_expect(_approximately(float(emitter.get("intensity")), 0.62), "Emitter preset should copy intensity.")
	_expect(_approximately(float(emitter.get("falloff")), 3.5), "Emitter preset should copy falloff.")
	_expect(_approximately(float(emitter.get("pulse_rate")), 8.0), "Emitter preset should copy pulse_rate.")
	_expect(bool(emitter.get("emit_on_ready")), "Emitter preset should copy emit_on_ready.")
	_expect(_approximately(float(emitter.get("moving_emit_distance")), 0.3), "Emitter preset should copy moving_emit_distance.")
	_expect(int(emitter.get("priority")) == 9, "Emitter preset should copy priority.")

	preset.set("radius", 10.0)
	preset.set("priority", -5)
	_expect(_approximately(float(emitter.get("radius")), 2.75), "Editing a source emitter preset after apply should not mutate the emitter.")
	_expect(int(emitter.get("priority")) == 9, "Editing source emitter preset priority after apply should not mutate the emitter.")

	var captured := emitter.call("capture_preset") as Resource
	_expect(captured != null, "Emitter capture should return a resource.")
	_expect(captured != preset, "Emitter capture should return a new resource.")
	_expect(captured.get_script() == emitter_preset_script, "Emitter capture should return WaterRippleEmitterPreset.")
	_expect(captured.resource_path.is_empty(), "Emitter capture should stay in memory without a resource path.")
	_expect(int(captured.get("emitter_mode")) == int(emitter.get("emitter_mode")), "Captured emitter preset should copy current mode.")
	_expect(_approximately(float(captured.get("radius")), float(emitter.get("radius"))), "Captured emitter preset should copy current radius.")
	captured.set("radius", 0.5)
	_expect(_approximately(float(emitter.get("radius")), 2.75), "Editing a captured emitter preset should not mutate the emitter.")

	_results["emitter_copy"] = {
		"mode": emitter.get("emitter_mode"),
		"radius": emitter.get("radius"),
		"captured_path": captured.resource_path,
	}
	emitter.free()


func _validate_runtime_field_apply(field_script: Script) -> void:
	var probe_root := Node3D.new()
	root.add_child(probe_root)

	var river := RiverManager.new()
	river.name = "Phase9PresetProbeRiver"
	probe_root.add_child(river)
	await _settle_frames(4)
	var river_mesh := river.get("mesh_instance") as MeshInstance3D
	_expect(river_mesh != null and river_mesh.mesh != null, "Runtime preset probe river should expose a mesh for boundary generation.")

	var field := field_script.new() as Node3D
	field.name = "Phase9PresetProbeField"
	field.set("enabled", false)
	field.set("resolution", 128)
	field.set("max_emitters", 2)
	field.set("world_bounds", AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 2.0, 4.0)))
	probe_root.add_child(field)

	var target_paths: Array[NodePath] = []
	target_paths.append(field.get_path_to(river))
	field.set("target_river_paths", target_paths)
	if river_mesh != null:
		var boundary_paths: Array[NodePath] = []
		boundary_paths.append(field.get_path_to(river_mesh))
		field.set("boundary_source_paths", boundary_paths)
	field.set("enabled", true)
	_expect(bool(field.call("initialize_runtime")), "Runtime field should initialize before preset application.")
	await _settle_frames(8)

	var before_snapshot: Dictionary = field.call("get_field_snapshot")
	var before_rids: Array = field.call("get_runtime_viewport_rids")
	_expect(bool(river.call("has_runtime_ripple_material_state", field)), "Runtime field should own target material state before preset apply.")

	var visual_preset := field.call("capture_preset") as Resource
	visual_preset.set("normal_strength", float(field.get("normal_strength")) + 0.5)
	visual_preset.set("damping", 0.93)
	_expect(bool(field.call("apply_preset", visual_preset)), "Runtime field should accept a visual-only preset.")
	await _settle_frames(3)
	var visual_snapshot: Dictionary = field.call("get_field_snapshot")
	var visual_rids: Array = field.call("get_runtime_viewport_rids")
	_expect(_rid_arrays_match(before_rids, visual_rids), "Visual-only field preset should not rebuild runtime viewports.")
	_expect(Vector2i(visual_snapshot.get("read_texture_size", Vector2i.ZERO)) == Vector2i(128, 128), "Visual-only field preset should keep texture resolution.")
	_expect(int(visual_snapshot.get("applied_target_count", 0)) == 1, "Visual-only field preset should keep target material state applied.")
	_expect(bool(river.call("has_runtime_ripple_material_state", field)), "Visual-only field preset should keep runtime material ownership.")

	var rebuild_preset := field.call("capture_preset") as Resource
	rebuild_preset.set("resolution", 64)
	rebuild_preset.set("max_emitters", 4)
	_expect(bool(field.call("apply_preset", rebuild_preset)), "Runtime field should accept a rebuild-sensitive preset.")
	await _settle_frames(10)
	var rebuild_snapshot: Dictionary = field.call("get_field_snapshot")
	var rebuild_rids: Array = field.call("get_runtime_viewport_rids")
	_expect(not _rid_arrays_match(visual_rids, rebuild_rids), "Rebuild-sensitive field preset should replace runtime viewports.")
	_expect(bool(rebuild_snapshot.get("runtime_initialized", false)), "Field should remain initialized after preset-driven rebuild.")
	_expect(Vector2i(rebuild_snapshot.get("read_texture_size", Vector2i.ZERO)) == Vector2i(64, 64), "Preset-driven rebuild should update read texture size.")
	_expect(Vector2i(rebuild_snapshot.get("impulse_texture_size", Vector2i.ZERO)) == Vector2i(64, 64), "Preset-driven rebuild should update impulse texture size.")
	_expect(int(rebuild_snapshot.get("max_emitters", 0)) == 4, "Preset-driven rebuild should update max_emitters.")
	_expect(int(rebuild_snapshot.get("applied_target_count", 0)) == 1, "Preset-driven rebuild should reapply target material state.")
	_expect(bool(river.call("has_runtime_ripple_material_state", field)), "Preset-driven rebuild should keep runtime material ownership valid.")

	field.queue_free()
	await _settle_frames(4)
	_expect(not bool(river.call("has_runtime_ripple_material_state")), "Freeing runtime field should restore target material state after preset tests.")
	probe_root.queue_free()
	await _settle_frames(2)

	_results["runtime_field"] = {
		"before": before_snapshot,
		"visual": visual_snapshot,
		"rebuild": rebuild_snapshot,
	}


func _validate_scene_save_reload(field_script: Script, emitter_script: Script) -> void:
	var scratch_abs := ProjectSettings.globalize_path(SCRATCH_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(scratch_abs)
	_expect(dir_error == OK or dir_error == ERR_ALREADY_EXISTS, "Scratch directory should be available for Phase 9 save/reload probes.")

	var saved_field_preset := FieldPresetResource.create_builtin_preset("Performance Field") as Resource
	var saved_emitter_preset := EmitterPresetResource.create_builtin_preset("Footstep") as Resource
	_expect(ResourceSaver.save(saved_field_preset, SCRATCH_FIELD_PRESET_PATH) == OK, "Field preset resource should save to scratch for reload validation.")
	_expect(ResourceSaver.save(saved_emitter_preset, SCRATCH_EMITTER_PRESET_PATH) == OK, "Emitter preset resource should save to scratch for reload validation.")

	var loaded_field_preset := ResourceLoader.load(SCRATCH_FIELD_PRESET_PATH) as Resource
	var loaded_emitter_preset := ResourceLoader.load(SCRATCH_EMITTER_PRESET_PATH) as Resource
	_expect(loaded_field_preset != null, "Saved field preset should load from scratch.")
	_expect(loaded_emitter_preset != null, "Saved emitter preset should load from scratch.")
	if loaded_field_preset != null:
		_expect(loaded_field_preset.get_script() == FieldPresetResource, "Loaded field preset should keep its resource script.")
		_expect(int(loaded_field_preset.get("resolution")) == 128, "Loaded Performance Field preset should preserve resolution.")
		_expect(int(loaded_field_preset.get("max_emitters")) == 8, "Loaded Performance Field preset should preserve max_emitters.")
	if loaded_emitter_preset != null:
		_expect(loaded_emitter_preset.get_script() == EmitterPresetResource, "Loaded emitter preset should keep its resource script.")
		_expect(int(loaded_emitter_preset.get("emitter_mode")) == EmitterPresetResource.MODE_ONE_SHOT, "Loaded Footstep preset should preserve one-shot mode.")
		_expect(_approximately(float(loaded_emitter_preset.get("radius")), 0.55), "Loaded Footstep preset should preserve radius.")

	var scene_root := Node3D.new()
	scene_root.name = "Phase9SceneReloadProbe"

	var river := RiverManager.new()
	river.name = "ReloadProbeRiver"
	scene_root.add_child(river)
	river.owner = scene_root

	var field := field_script.new() as Node3D
	field.name = "ReloadProbeField"
	field.set("enabled", false)
	field.call("apply_builtin_preset", "Character Interaction Field")
	field.set("field_group_name", "phase9_reload_fields")
	field.set("target_group_name", "")
	field.set("world_bounds", AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 2.0, 4.0)))
	scene_root.add_child(field)
	field.owner = scene_root

	var target_paths: Array[NodePath] = []
	target_paths.append(field.get_path_to(river))
	field.set("target_river_paths", target_paths)

	var emitter := emitter_script.new() as Node3D
	emitter.name = "ReloadProbeEmitter"
	emitter.set("enabled", false)
	emitter.call("apply_builtin_preset", "Footstep")
	emitter.set("field_group_name", "phase9_reload_fields")
	scene_root.add_child(emitter)
	emitter.owner = scene_root
	emitter.set("target_field_path", emitter.get_path_to(field))

	var packed_scene := PackedScene.new()
	_expect(packed_scene.pack(scene_root) == OK, "Phase 9 authoring scene should pack for scratch save/reload.")
	_expect(ResourceSaver.save(packed_scene, SCRATCH_SCENE_PATH) == OK, "Phase 9 authoring scene should save to scratch.")
	scene_root.free()

	var loaded_scene := ResourceLoader.load(SCRATCH_SCENE_PATH) as PackedScene
	_expect(loaded_scene != null, "Saved Phase 9 authoring scene should load from scratch.")
	if loaded_scene == null:
		return

	var loaded_root := loaded_scene.instantiate() as Node3D
	_expect(loaded_root != null, "Saved Phase 9 authoring scene should instantiate.")
	if loaded_root == null:
		return

	var loaded_field := loaded_root.get_node_or_null("ReloadProbeField") as Node3D
	var loaded_emitter := loaded_root.get_node_or_null("ReloadProbeEmitter") as Node3D
	var loaded_river := loaded_root.get_node_or_null("ReloadProbeRiver") as Node
	_expect(loaded_field != null, "Reloaded scene should contain the WaterRippleField.")
	_expect(loaded_emitter != null, "Reloaded scene should contain the WaterRippleEmitter.")
	_expect(loaded_river != null, "Reloaded scene should contain the target river.")
	if loaded_field == null or loaded_emitter == null or loaded_river == null:
		loaded_root.queue_free()
		return

	_expect(not bool(loaded_field.get("enabled")), "Reloaded field should preserve enabled=false until runtime is deliberately started.")
	_expect(int(loaded_field.get("resolution")) == 256, "Reloaded field should preserve Character Interaction resolution.")
	_expect(_approximately(float(loaded_field.get("normal_strength")), 1.25), "Reloaded field should preserve Character Interaction normal strength.")
	_expect(String(loaded_field.get("field_group_name")) == "phase9_reload_fields", "Reloaded field should preserve field_group_name.")
	_expect(not _has_property(loaded_field, "field_preset"), "Reloaded field should not gain a live field_preset slot.")
	_expect(not bool(loaded_emitter.get("enabled")), "Reloaded emitter should preserve enabled=false until runtime is deliberately started.")
	_expect(int(loaded_emitter.get("emitter_mode")) == EmitterPresetResource.MODE_ONE_SHOT, "Reloaded emitter should preserve Footstep one-shot mode.")
	_expect(_approximately(float(loaded_emitter.get("radius")), 0.55), "Reloaded emitter should preserve Footstep radius.")
	_expect(NodePath(loaded_emitter.get("target_field_path")) == loaded_emitter.get_path_to(loaded_field), "Reloaded emitter should preserve target field path.")
	_expect(not _has_property(loaded_emitter, "emitter_preset"), "Reloaded emitter should not gain a live emitter_preset slot.")

	root.add_child(loaded_root)
	await _settle_frames(8)
	loaded_field.set("enabled", true)
	_expect(bool(loaded_field.call("initialize_runtime")), "Reloaded field should initialize runtime after scene reload.")
	await _settle_frames(10)
	var reload_snapshot: Dictionary = loaded_field.call("get_field_snapshot")
	_expect(bool(reload_snapshot.get("runtime_initialized", false)), "Reloaded field should rebuild transient runtime textures.")
	_expect(Vector2i(reload_snapshot.get("read_texture_size", Vector2i.ZERO)) == Vector2i(256, 256), "Reloaded runtime texture should match the saved field resolution.")
	_expect(int(reload_snapshot.get("target_count", 0)) == 1, "Reloaded field should resolve the saved target river path.")
	_expect(int(reload_snapshot.get("applied_target_count", 0)) == 1, "Reloaded field should apply target material state after runtime start.")
	_expect(bool(loaded_river.call("has_runtime_ripple_material_state", loaded_field)), "Reloaded target river should be owned by the reloaded field runtime state.")
	_expect((loaded_field.call("get_runtime_viewport_rids") as Array).size() >= 3, "Reloaded field should create fresh runtime viewport RIDs.")

	loaded_field.set("enabled", false)
	await _settle_frames(4)
	_expect(not bool(loaded_river.call("has_runtime_ripple_material_state")), "Disabling the reloaded field should restore target material state.")
	loaded_root.queue_free()
	await _settle_frames(2)

	_results["scene_save_reload"] = {
		"scene_path": SCRATCH_SCENE_PATH,
		"field_preset_path": SCRATCH_FIELD_PRESET_PATH,
		"emitter_preset_path": SCRATCH_EMITTER_PRESET_PATH,
		"snapshot": reload_snapshot,
	}


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.name) == property_name:
			return true
	return false


func _property_is_storage_only(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.name) != property_name:
			continue
		var usage := int(property.usage)
		return (usage & PROPERTY_USAGE_STORAGE) != 0 and (usage & PROPERTY_USAGE_EDITOR) == 0
	return false


func _export_groups_include(object: Object, expected_groups: Array[String]) -> bool:
	var actual_groups := PackedStringArray()
	for property in object.get_property_list():
		var usage := int(property.usage)
		if (usage & PROPERTY_USAGE_GROUP) != 0:
			actual_groups.append(String(property.name))
	for group_name in expected_groups:
		if not actual_groups.has(group_name):
			return false
	return true


func _rid_arrays_match(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if str(first[index]) != str(second[index]):
			return false
	return true


func _approximately(first: float, second: float) -> bool:
	return abs(first - second) <= 0.0001


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("RIPPLE_PHASE9_PRESET_API_PROBE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
