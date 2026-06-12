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
#                                                     `views=list` prints all and exits;
#                                                     `views=parity` = the fixed RT.2/R3 set
#                                                     (surface + one view per shared-code family)
#   scene=<res:// path>              default res://Demo.tscn
#   river=<node path in scene>       default WaterSystem/Water River
#   cameras=<comma list of camera node paths>  capture from these scene cameras
#                                              instead of flying along the curve
#   stations=<int>                   fly-along camera stops (default 8; ignored with cameras=)
#   height=<float> back=<float>      fly-along camera offset in meters (default 7 / 6)
#   label=<name>                     output subfolder, e.g. before/after a change
#   out=<res:// dir>                 default res://addons/waterways/probes/out
#   freeze=0                         disable the default Engine.time_scale=0 freeze
#                                    (frozen runs are deterministic: shader TIME stays ~0
#                                    and physics never steps, so before/after captures of
#                                    unchanged code should be byte-identical)
#
# Output: <out>[/<label>]/<view>_<station or camera name>.png
# Success marker: DEBUG_VIEW_CAPTURE_OK
#
# RT.2 diff mode (headless OK - pure image comparison, no window):
#   ... --headless --script res://addons/waterways/probes/debug_view_capture_probe.gd -- a=res://.../before b=res://.../after
#   thresholds: max_delta=0.02 mean_delta=0.002 (per channel, 0..1 scale)
# Pairs PNGs by filename across the two directories; byte-identical files
# short-circuit; differing files get per-channel max/mean deltas. Any missing
# file, size mismatch, or threshold breach prints CAPTURE_DIFF_MISMATCH and
# exits 1. Success marker: CAPTURE_DIFF_OK. Consumer: R3's extraction
# pixel-parity gate (constitution rule 8: captures themselves are
# windowed/human-assisted; this diff runs headless on their output).
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
const DEFAULT_MAX_DELTA := 0.02
const DEFAULT_MEAN_DELTA := 0.002

# The fixed RT.2 pixel-parity set for R3's extraction gate: the visible
# surface plus one representative view per shared-code family the includes
# will move (flow decode/force, foam, dist/pressure, steepness, pillow stack,
# wake/eddy, pillow height displacement).
const PARITY_VIEW_IDS := [0, 1, 8, 9, 6, 7, 4, 5, 11, 26, 30, 31, 27]


func _initialize() -> void:
	# Freeze before the first frame iterates: shader TIME accumulates scaled
	# frame deltas, so freezing here pins it at ~0 in every run. Freezing
	# later (e.g. in _run) pins each run at a different accumulated TIME and
	# every animated element (water, foliage, sky) carries a run-to-run phase
	# offset that breaks capture determinism.
	var args := _parse_args()
	if not (args.has("a") or args.has("b")) and String(args.get("freeze", "1")) != "0":
		Engine.time_scale = 0.0
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	if args.has("a") or args.has("b"):
		_run_diff(args)
		return
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

	var freeze := Engine.time_scale == 0.0
	print("DEBUG_VIEW_CAPTURE scene=", scene_path, " views=", view_ids, " cameras=", camera_paths.size(), " stations=", station_count, " freeze=", freeze)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: " + scene_path)
		quit(1)
		return
	var scene := packed.instantiate()
	scene.scene_file_path = scene_path
	if freeze:
		_stabilize_detail_layers(scene)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	if freeze:
		# physics_frame never fires at time_scale 0 - settle on render frames.
		await process_frame
		await process_frame
	else:
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


# zylann.hterrain detail layers scatter their grass multimesh with a
# time-randomized RNG on every load (hterrain_detail_layer.gd:814-818), which
# breaks run-to-run capture determinism even with frozen time. They expose a
# fixed-seed mode - switch it on (runtime instance only; nothing is saved).
func _stabilize_detail_layers(scene_root: Node) -> void:
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var current := stack.pop_back() as Node
		for child in current.get_children():
			stack.push_back(child)
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("hterrain_detail_layer.gd"):
			current.set("fixed_seed", 12345)
			current.set("fixed_seed_enabled", true)
			print("  fixed detail-layer seed: ", current.name)


func _run_diff(args: Dictionary) -> void:
	var a_dir := String(args.get("a", ""))
	var b_dir := String(args.get("b", ""))
	if a_dir.is_empty() or b_dir.is_empty():
		push_error("Diff mode needs both a=<dir> and b=<dir> capture directories.")
		quit(1)
		return
	var max_delta_limit := float(args.get("max_delta", DEFAULT_MAX_DELTA))
	var mean_delta_limit := float(args.get("mean_delta", DEFAULT_MEAN_DELTA))
	var a_base := ProjectSettings.globalize_path(a_dir)
	var b_base := ProjectSettings.globalize_path(b_dir)
	var a_files := _list_pngs(a_base)
	var b_files := _list_pngs(b_base)
	if a_files.is_empty():
		push_error("No PNG files found in " + a_base)
		quit(1)
		return
	print("CAPTURE_DIFF a=", a_base, " (", a_files.size(), " files) b=", b_base, " (", b_files.size(), " files)",
			" max_delta_limit=", max_delta_limit, " mean_delta_limit=", mean_delta_limit)
	var names := {}
	for file_name in a_files:
		names[file_name] = true
	for file_name in b_files:
		names[file_name] = true
	var sorted_names := names.keys()
	sorted_names.sort()
	var mismatches := 0
	for name_variant in sorted_names:
		var file_name := String(name_variant)
		if not a_files.has(file_name) or not b_files.has(file_name):
			mismatches += 1
			print("CAPTURE_DIFF_MISMATCH file=", file_name, " present_a=", a_files.has(file_name), " present_b=", b_files.has(file_name))
			continue
		if not _diff_pair(file_name, a_base + "/" + file_name, b_base + "/" + file_name, max_delta_limit, mean_delta_limit):
			mismatches += 1
	if mismatches == 0:
		print("CAPTURE_DIFF_OK files=", sorted_names.size())
		quit(0)
		return
	push_error("Capture sets differ in " + str(mismatches) + " file(s); see CAPTURE_DIFF_MISMATCH lines.")
	quit(1)


func _diff_pair(file_name: String, a_path: String, b_path: String, max_delta_limit: float, mean_delta_limit: float) -> bool:
	var image_a := Image.load_from_file(a_path)
	var image_b := Image.load_from_file(b_path)
	if image_a == null or image_b == null:
		print("CAPTURE_DIFF_MISMATCH file=", file_name, " unreadable_a=", image_a == null, " unreadable_b=", image_b == null)
		return false
	if image_a.get_size() != image_b.get_size():
		print("CAPTURE_DIFF_MISMATCH file=", file_name, " size_a=", image_a.get_size(), " size_b=", image_b.get_size())
		return false
	image_a.convert(Image.FORMAT_RGBA8)
	image_b.convert(Image.FORMAT_RGBA8)
	var data_a := image_a.get_data()
	var data_b := image_b.get_data()
	if data_a == data_b:
		print("CAPTURE_DIFF_FILE file=", file_name, " identical=true")
		return true
	var max_delta := [0, 0, 0, 0]
	var sum_delta := [0, 0, 0, 0]
	var differing_pixels := 0
	var byte_count := mini(data_a.size(), data_b.size())
	var byte_index := 0
	while byte_index < byte_count:
		var pixel_differs := false
		for channel_index in 4:
			var delta: int = absi(int(data_a[byte_index + channel_index]) - int(data_b[byte_index + channel_index]))
			if delta > 0:
				pixel_differs = true
				sum_delta[channel_index] += delta
				if delta > int(max_delta[channel_index]):
					max_delta[channel_index] = delta
		if pixel_differs:
			differing_pixels += 1
		byte_index += 4
	var pixel_count := byte_count / 4
	var worst_max := 0.0
	var worst_mean := 0.0
	var channel_report := ""
	for channel_index in 4:
		var channel_max := float(max_delta[channel_index]) / 255.0
		var channel_mean := float(sum_delta[channel_index]) / (255.0 * float(maxi(pixel_count, 1)))
		worst_max = maxf(worst_max, channel_max)
		worst_mean = maxf(worst_mean, channel_mean)
		channel_report += " %s_max=%s %s_mean=%s" % ["rgba"[channel_index], snappedf(channel_max, 0.0001), "rgba"[channel_index], snappedf(channel_mean, 0.000001)]
	var over_limit := worst_max > max_delta_limit or worst_mean > mean_delta_limit
	print("CAPTURE_DIFF_MISMATCH file=" if over_limit else "CAPTURE_DIFF_FILE file=", file_name,
			" differing_pixels=", differing_pixels, "/", pixel_count, channel_report)
	return not over_limit


func _list_pngs(base_dir: String) -> Dictionary:
	var files := {}
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.to_lower().ends_with(".png"):
			files[entry] = true
		entry = dir.get_next()
	dir.list_dir_end()
	return files


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
	if raw.strip_edges().to_lower() == "parity":
		return PARITY_VIEW_IDS.duplicate()
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
