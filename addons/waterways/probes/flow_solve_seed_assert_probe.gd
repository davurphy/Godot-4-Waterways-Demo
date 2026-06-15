# RT.4 cross-language seed assertion (headless OK): the bake seeds the Jacobi
# pressure ping-pong CPU-side with RIVER_FLOW_PRESSURE_SEED_COLOR, and the
# solve shaders decode pressure as (r - 0.5) / scale - so the seed's red
# channel must equal the encodings' zero point (enc(0) = 0.5 for velocity,
# divergence, and pressure in flow_solve_common.gdshaderinc). This probe
# fails if either side drifts away from the 0.5 bias.
#
#   & $godotConsole --headless --path $root --script res://addons/waterways/probes/flow_solve_seed_assert_probe.gd
#
# Success marker: FLOW_SOLVE_SEED_ASSERT_OK
extends SceneTree

const RIVER_MANAGER_PATH := "res://addons/waterways/river_manager.gd"
const SOLVE_INCLUDE_PATH := "res://addons/waterways/shaders/filters/flow_solve_common.gdshaderinc"

# Each encoding's neutral bias as written in the include; their presence
# asserts enc(0) = 0.5 textually for all three encodings.
const REQUIRED_ENCODING_FRAGMENTS := [
	"velocity * 0.5 + 0.5",
	"FLOW_SOLVE_DIV_SCALE + 0.5",
	"FLOW_SOLVE_PRESSURE_SCALE + 0.5",
]

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var river_manager_script := load(RIVER_MANAGER_PATH) as GDScript
	if river_manager_script == null:
		_errors.append("Could not load " + RIVER_MANAGER_PATH)
	else:
		var constants := river_manager_script.get_script_constant_map()
		if not constants.has("RIVER_FLOW_PRESSURE_SEED_COLOR"):
			_errors.append("river_manager.gd no longer declares RIVER_FLOW_PRESSURE_SEED_COLOR")
		else:
			var seed_value = constants["RIVER_FLOW_PRESSURE_SEED_COLOR"]
			if typeof(seed_value) != TYPE_COLOR:
				_errors.append("RIVER_FLOW_PRESSURE_SEED_COLOR is not a Color: " + str(seed_value))
			elif not is_equal_approx((seed_value as Color).r, 0.5):
				_errors.append("RIVER_FLOW_PRESSURE_SEED_COLOR.r = " + str((seed_value as Color).r)
						+ " but the solve encodings' enc(0) is 0.5")

	var include_text := FileAccess.get_file_as_string(SOLVE_INCLUDE_PATH)
	if include_text.is_empty():
		_errors.append("Could not read " + SOLVE_INCLUDE_PATH)
	else:
		for fragment_variant in REQUIRED_ENCODING_FRAGMENTS:
			var fragment := String(fragment_variant)
			if not include_text.contains(fragment):
				_errors.append(SOLVE_INCLUDE_PATH + " no longer contains the 0.5-bias encoding fragment '"
						+ fragment + "' - the CPU pressure seed pairing must be re-verified")

	if _errors.is_empty():
		print("FLOW_SOLVE_SEED_ASSERT_OK seed_r=0.5 encodings=3/3")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
