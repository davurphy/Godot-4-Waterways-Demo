# Visual review export: loads a scene, switches the river through one or more
# debug views, and captures screenshots either from a camera flown along the
# river curve (stations) or from named review cameras already in the scene.
# The view list is read from gui/debug_view_menu.gd so it never drifts from
# the editor menu. Supersedes the per-feature visual export probes
# (pillow_visual_review_export, object_artifact_visual_export) and the
# single-view fly-along capture probe.
#
# Run (NOT headless - needs a rendered window). User args after `--`:
#   & $godotConsole --path $root --script res://addons/waterways/probes/debug_view_capture_probe.gd -- views="Flow Arrows"
#
# Args (all optional, key=value):
#   views=<id | label substring | comma list | list>  default "Flow Arrows";
#                                                     `views=list` prints all and exits
#   scene=<res:// path>              default res://Demo.tscn
#   river=<node path in scene>       default WaterSystem/Water River
#   cameras=<comma list of camera node paths>  capture from these scene cameras
#                                              instead of flying along the curve
#   stations=<int>                   fly-along camera stops (default 8; ignored with cameras=)
#   height=<float> back=<float>      fly-along camera offset in meters (default 7 / 6)
#   label=<name>                     output subfolder, e.g. before/after a change
#   out=<res:// dir>                 default res://addons/waterways/probes/out
#
# Output: <out>[/<label>]/<view>_<station or camera name>.png
# Success marker: DEBUG_VIEW_CAPTURE_OK
extends SceneTree

const DebugViewMenu := preload("res://addons/waterways/gui/debug_view_menu.gd")

const DEFAULT_SCENE := "res://Demo.tscn"
const DEFAULT_RIVER := "WaterSystem/Water River"
const DEFAULT_VIEWS := "Flow Arrows"
const DEFAULT_STATIONS := 8
const DEFAULT_CAMERA_HEIGHT := 7.0
const DEFAULT_CAMERA_BACK := 6.0
const DEFAULT_OUT_DIR := "res://addons/waterways/probes/out"
const SETTLE_FRAMES := 12
const FIRST_SHOT_EXTRA_FRAMES := 30


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var views_raw := String(args.get("views", args.get("view", DEFAULT_VIEWS)))
	if views_raw.strip_edges().to_lower() == "list":
		_print_view_list()
		quit(0)
		return
	var view_ids := _resolve_view_ids(views_raw)
	if view_ids.is_empty():
		quit(1)
		return
	var scene_path := String(args.get("scene", DEFAULT_SCENE))
	var river_path := String(args.get("river", DEFAULT_RIVER))
	var camera_paths := String(args.get("cameras", "")).split(",", false)
	var station_count := maxi(1, int(args.get("stations", DEFAULT_STATIONS)))
	var camera_height := float(args.get("height", DEFAULT_CAMERA_HEIGHT))
	var camera_back := float(args.get("back", DEFAULT_CAMERA_BACK))
	var out_dir := String(args.get("out", DEFAULT_OUT_DIR))
	var label := String(args.get("label", ""))
	if not label.is_empty():
		out_dir = out_dir.path_join(label)

	print("DEBUG_VIEW_CAPTURE scene=", scene_path, " views=", view_ids, " cameras=", camera_paths.size(), " stations=", station_count)
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

	var out_base := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_base)

	var ok: bool
	if camera_paths.is_empty():
		ok = await _capture_fly_along(scene, river, view_ids, station_count, camera_height, camera_back, out_base)
	else:
		ok = await _capture_scene_cameras(scene, river, view_ids, camera_paths, out_base)
	if ok:
		print("DEBUG_VIEW_CAPTURE_OK")
	quit(0 if ok else 1)


func _capture_fly_along(scene: Node, river, view_ids: Array, station_count: int, camera_height: float, camera_back: float, out_base: String) -> bool:
	var curve: Curve3D = river.get("curve")
	if curve == null or curve.get_baked_length() <= 0.0:
		push_error("River has no usable curve.")
		return false
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var baked_length := curve.get_baked_length()
	var river_transform: Transform3D = river.global_transform
	var first_shot := true
	for station in station_count:
		var offset := baked_length * (float(station) + 0.5) / float(station_count)
		var look_target := river_transform * curve.sample_baked(offset)
		var ahead := river_transform * curve.sample_baked(minf(offset + 2.0, baked_length))
		var flow_direction := (ahead - look_target).normalized()
		if not flow_direction.is_finite() or flow_direction.length_squared() < 0.5:
			flow_direction = Vector3.FORWARD
		camera.global_position = look_target - flow_direction * camera_back + Vector3.UP * camera_height
		camera.look_at(look_target, Vector3.UP)
		for view_id_variant in view_ids:
			var view_id := int(view_id_variant)
			if not await _capture_one(river, view_id, "%s_station_%d" % [_sanitize_label(_view_label(view_id)), station], out_base, first_shot):
				return false
			first_shot = false
	return true


func _capture_scene_cameras(scene: Node, river, view_ids: Array, camera_paths: PackedStringArray, out_base: String) -> bool:
	var first_shot := true
	for camera_path_variant in camera_paths:
		var camera_path := String(camera_path_variant).strip_edges()
		var camera := scene.get_node_or_null(camera_path) as Camera3D
		if camera == null:
			push_error("Could not find Camera3D at " + camera_path)
			return false
		camera.current = true
		var camera_name := _sanitize_label(String(camera.name))
		for view_id_variant in view_ids:
			var view_id := int(view_id_variant)
			if not await _capture_one(river, view_id, "%s_%s" % [_sanitize_label(_view_label(view_id)), camera_name], out_base, first_shot):
				return false
			first_shot = false
	return true


func _capture_one(river, view_id: int, file_stem: String, out_base: String, first_shot: bool) -> bool:
	river.set_debug_view(view_id)
	var settle := SETTLE_FRAMES + (FIRST_SHOT_EXTRA_FRAMES if first_shot else 0)
	for frame in settle:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Viewport capture returned no image for " + file_stem)
		return false
	var file_path := out_base + "/" + file_stem + ".png"
	image.save_png(file_path)
	print("CAPTURED ", file_path)
	return true


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var separator := String(arg).find("=")
		if separator <= 0:
			continue
		args[String(arg).substr(0, separator).to_lower()] = String(arg).substr(separator + 1)
	return args


# Each entry: numeric view id or case-insensitive label substring.
# Returns [] (after printing guidance) when any entry cannot be resolved.
func _resolve_view_ids(raw: String) -> Array:
	var view_ids := []
	for entry in raw.split(",", false):
		var view_id := _resolve_view_id(String(entry).strip_edges())
		if view_id < 0:
			return []
		view_ids.append(view_id)
	if view_ids.is_empty():
		push_error("No views requested. Run with `-- views=list` to see all views.")
	return view_ids


func _resolve_view_id(text: String) -> int:
	if text.is_empty():
		return -1
	if text.is_valid_int():
		var view_id := int(text)
		if _view_label(view_id).begins_with("Unknown"):
			push_error("No debug view with id " + str(view_id) + ". Run with `-- views=list` to see all views.")
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
		push_error("No debug view label matches \"" + text + "\". Run with `-- views=list` to see all views.")
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
