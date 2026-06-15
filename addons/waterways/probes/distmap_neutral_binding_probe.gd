# R0.7 verification probe (headless OK): instantiates a RiverManager with no
# bake data (so dist_pressure is null), lets _enter_tree run, and asserts that
# BOTH the visible and debug materials bind the code-side neutral distmap
# texel (0.75, 0.25, 0.0, 0.5) to i_distmap instead of leaving the sampler
# unbound (which would fall back to the shader hint - black - and decode as
# max distance / bend bias -1).
#
# This covers the Defect-11 class that cannot be reproduced by hand from the
# demo scene: a legacy river with valid_flowmap saved true and a null
# distmap. The binding is unconditional in _enter_tree, so asserting it on a
# fresh river asserts it for that legacy state too.
#
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/distmap_neutral_binding_probe.gd
#
# Success marker: DISTMAP_NEUTRAL_BINDING_OK
extends SceneTree

const RIVER_MANAGER_PATH := "res://addons/waterways/river_manager.gd"
const EXPECTED_NEUTRAL := Color(0.75, 0.25, 0.0, 0.5)
# 8-bit quantization of the texel plus float rounding.
const CHANNEL_TOLERANCE := 0.01

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var river_script := load(RIVER_MANAGER_PATH) as GDScript
	if river_script == null:
		push_error("Could not load " + RIVER_MANAGER_PATH)
		quit(1)
		return
	var river := river_script.new() as Node3D
	root.add_child(river)
	await process_frame

	_check_material(river.get("_material") as ShaderMaterial, "visible material")
	_check_material(river.get("_debug_material") as ShaderMaterial, "debug material")

	river.queue_free()
	await process_frame

	if _errors.is_empty():
		print("DISTMAP_NEUTRAL_BINDING_OK texel=", EXPECTED_NEUTRAL)
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _check_material(material: ShaderMaterial, label: String) -> void:
	if material == null:
		_errors.append(label + " is null on a fresh RiverManager")
		return
	var bound = material.get_shader_parameter("i_distmap")
	var texture := bound as Texture2D
	if texture == null:
		_errors.append(label + " has no texture bound to i_distmap (hint default would apply: black, non-neutral)")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		_errors.append(label + " i_distmap texture is unreadable")
		return
	var texel := image.get_pixel(0, 0)
	for channel_index in 4:
		var actual: float = texel[channel_index]
		var expected: float = EXPECTED_NEUTRAL[channel_index]
		if absf(actual - expected) > CHANNEL_TOLERANCE:
			_errors.append(label + " i_distmap texel is " + str(texel)
					+ " but the neutral decode requires " + str(EXPECTED_NEUTRAL))
			return
