# Visual diagnostic: loads a scene, switches the river to a chosen debug view,
# flies a camera along the river curve and saves rendered screenshots for
# inspection. General-purpose: the view (and scene/river/camera settings) are
# passed as user args; the view list is read from gui/debug_view_menu.gd so it
# never drifts from the editor menu.
#
# Run (NOT headless - needs a rendered window). User args go after a `--`:
#   & $godotConsole --path $root --script res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/river_debug_view_capture_probe.gd -- view="Flow Arrows"
#
# Args (all optional, key=value):
#   view=<id | label substring | list>   debug view (default: Flow Arrows = 7)
#                                        `view=list` prints all views and exits
#   scene=<res:// path>                  default res://Demo.tscn
#   river=<node path in scene>           default WaterSystem/Water River
#   stations=<int>                       camera stops along the curve (default 8)
#   height=<float> back=<float>          camera offset in meters (default 7 / 6)
#   out=<res:// dir>                     default <this folder>/out
#   prefix=<file prefix>                 default derived from the view label
#
# Examples:
#   -- view=list
#   -- view=58 stations=12
#   -- view="pillow visual mask" scene=res://Demo_obstacle_flow_test.tscn
extends SceneTree

const DebugViewMenu := preload("res://addons/waterways/gui/debug_view_menu.gd")

const DEFAULT_SCENE := "res://Demo.tscn"
const DEFAULT_RIVER := "WaterSystem/Water River"
const DEFAULT_VIEW_ID := 7 # Flow Arrows
const DEFAULT_STATIONS := 8
const DEFAULT_CAMERA_HEIGHT := 7.0
const DEFAULT_CAMERA_BACK := 6.0
const DEFAULT_OUT_DIR := "res://addons/waterways/docs/spec-driven/features/river-obstacle-flow-constraints/probes/out"
const SETTLE_FRAMES := 12
const FIRST_SHOT_EXTRA_FRAMES := 30


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	if String(args.get("view", "")).to_lower() == "list":
		_print_view_list()
		quit(0)
		return
	var view_id := _resolve_view_id(args.get("view", ""))
	if view_id < 0:
		quit(1)
		return
	var view_label := _view_label(view_id)
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER))
	var station_count := maxi(1, int(args.get("stations", DEFAULT_STATIONS)))
	var camera_height := float(args.get("height", DEFAULT_CAMERA_HEIGHT))
	var camera_back := float(args.get("back", DEFAULT_CAMERA_BACK))
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var prefix := String(args.get("prefix", _sanitize_label(view_label)))
	print("RIVER_DEBUG_VIEW_CAPTURE view=", view_id, " (", view_label, ") scene=", scene_path, " river=", river_path, " stations=", station_count)

	DisplayServer.window_set_size(Vector2i(1600, 900))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: " + scene_path)
		quit(1)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	await physics_frame

	var river := scene.get_node_or_null(river_path)
	if river == null:
		push_error("Could not find " + river_path + " in " + scene_path)
		quit(1)
		return
	river.set_debug_view(view_id)

	var curve: Curve3D = river.get("curve")
	if curve == null or curve.get_baked_length() <= 0.0:
		push_error("River has no usable curve.")
		quit(1)
		return

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true

	var out_base := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_base)
	var baked_length := curve.get_baked_length()
	var river_transform: Transform3D = river.global_transform

	for station in station_count:
		var offset := baked_length * (float(station) + 0.5) / float(station_count)
		var look_target := river_transform * curve.sample_baked(offset)
		var ahead := river_transform * curve.sample_baked(minf(offset + 2.0, baked_length))
		var flow_direction := (ahead - look_target).normalized()
		if not flow_direction.is_finite() or flow_direction.length_squared() < 0.5:
			flow_direction = Vector3.FORWARD
		camera.global_position = look_target - flow_direction * camera_back + Vector3.UP * camera_height
		camera.look_at(look_target, Vector3.UP)
		var settle := SETTLE_FRAMES + (FIRST_SHOT_EXTRA_FRAMES if station == 0 else 0)
		for frame in settle:
			await process_frame
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Viewport capture returned no image at station " + str(station))
			quit(1)
			return
		var file_path := out_base + "/%s_station_%d.png" % [prefix, station]
		image.save_png(file_path)
		print("CAPTURED station=", station, " offset=", String.num(offset, 1), "m -> ", file_path)

	print("RIVER_DEBUG_VIEW_CAPTURE_DONE")
	quit(0)


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args


# Accepts a numeric view id or a case-insensitive substring of the menu label.
# Returns -1 (after printing guidance) when the view cannot be resolved.
func _resolve_view_id(raw: Variant) -> int:
	var text := String(raw).strip_edges()
	if text.is_empty():
		return DEFAULT_VIEW_ID
	if text.is_valid_int():
		var view_id := int(text)
		if _view_label(view_id).begins_with("Unknown"):
			push_error("No debug view with id " + str(view_id) + ". Run with `-- view=list` to see all views.")
			return -1
		return view_id
	var needle := text.to_lower()
	var matches := []
	for item in DebugViewMenu.DEBUG_VIEW_ITEMS:
		var label := String(item[0])
		if label.to_lower() == needle:
			return int(item[1])
		if label.to_lower().contains(needle):
			matches.append(item)
	if matches.size() == 1:
		return int(matches[0][1])
	if matches.is_empty():
		push_error("No debug view label matches \"" + text + "\". Run with `-- view=list` to see all views.")
	else:
		var lines := PackedStringArray()
		for item in matches:
			lines.append("  %d = %s" % [int(item[1]), String(item[0])])
		push_error("Ambiguous view \"" + text + "\" - matches:\n" + "\n".join(lines))
	return -1


func _view_label(view_id: int) -> String:
	for item in DebugViewMenu.DEBUG_VIEW_ITEMS:
		if int(item[1]) == view_id:
			return String(item[0])
	return "Unknown " + str(view_id)


func _print_view_list() -> void:
	print("Available debug views (from gui/debug_view_menu.gd, grouped as in the editor menu):")
	for group_variant in DebugViewMenu.DEBUG_VIEW_GROUPS:
		var group := group_variant as Dictionary
		print("  [", group.get("name", ""), "]")
		for item in group.get("items", []):
			print("    %2d = %s" % [int(item[1]), String(item[0])])


func _sanitize_label(label: String) -> String:
	var out := ""
	for character in label.to_lower():
		out += character if character.is_valid_identifier() or character.is_valid_int() else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_suffix("_").trim_prefix("_")
