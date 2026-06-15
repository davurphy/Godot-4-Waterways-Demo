# RT.3 system-vs-river flow comparison probe (headless OK): for every
# WaterSystem with a saved system map, compares the saved map's world-space
# flow direction (what get_water_flow / buoyant ducks read) against the owning
# rivers' own baked flow - flow_foam_noise RG decoded and transformed to world
# XZ through the same UV->world basis system_flow.gdshader builds in
# get_world_xz_from_uv_axes (normalized per-triangle UV1 tangents).
#
# Samples are classified into three zones per river:
#   influence - obstacle influence (water_occupancy.g solid-proximity ramp, or
#               obstacle_features.a confidence when occupancy is absent)
#   control   - no hard-boundary context and no boundary gradient, so
#               apply_contextual_flow_slide is provably inactive; directions
#               must match here even before R2 (machinery sanity gate)
#   boundary  - bank-adjacent samples (report-only; slide is by-design there
#               for non-projected rivers)
#
# Gates: the control zone p90 angular delta is always enforced. The influence
# zone p90 is enforced only with enforce=all and only for rivers whose bake
# metadata says flow_projected=true.
#
#   report mode (control gate only):
#     & $godotConsole --headless --path $root --script res://addons/waterways/probes/system_flow_compare_probe.gd
#   influence gate mode:
#     ... --script res://addons/waterways/probes/system_flow_compare_probe.gd -- enforce=all
#   args: scene=res://X.tscn  stride=4  min_flow=0.05  influence_min=0.05
#         max_control_deg=15  max_influence_deg=35  sharp_deg=20
#         height_tol=1.0  allow_stale=1
#
# Noise floor (measured on fresh demo-scene maps): expected-vs-saved
# directions carry ~4 deg median / 9-12.5 deg p90 even where the slide is
# provably inactive. Sources: 8-bit flow quantization at low magnitudes, and
# - dominant in the tail - sharp flow structure (eddy edges, wakes) blended
# by the shader's linear texture filtering where the probe reads one texel;
# the obstacle scene sits at the high end because it has more such structure.
# The control gate exists to catch gross machinery breakage (a wrong basis
# reads as 45-90 deg p90), not stale maps - metadata staleness handles those.
# Samples whose system-map height channel disagrees with the sampled world
# height (top-down XZ overlap / edge bleed) are excluded as height_mismatch;
# the system map is paired bilinearly to remove half-pixel sampling offset;
# samples whose direction a single-neighbor blend would already rotate past
# sharp_deg are excluded as sharp_structure.
#
# ATTRIBUTION CORRECTION (2026-06-12, R2 execution): the pre-R2 influence
# p90 of 25.5/28.9 deg was recorded as "the Defect-1 signature", but direct
# A/B rendering (gated vs slide forced on) showed the slide contributes 0
# differing texels on Demo and 4.6k texels at mean 3.3 deg on the obstacle
# scene - the 23-27 deg influence floor is sampling/quantization noise of
# the stilled low-magnitude ring, NOT the slide, and survives the R2 fix.
# Consequences: max_influence_deg default recalibrated from 20 to 35
# (floor 23.3/26.9 measured post-R2 with sharp_deg=20; same floor-plus-margin
# philosophy as the control gate), and the influence gate now guards against
# GROSS systematic divergence only. The R2 slide-gate mechanism itself is
# gated directly by system_flow_projected_gate_probe.gd (windowed).
#
# Success marker: SYSTEM_FLOW_COMPARE_OK. Threshold breaches print
# SYSTEM_FLOW_COMPARE_EXCEEDED lines and exit 1. A stale saved system map
# (river bakes changed since it was generated) prints
# SYSTEM_FLOW_COMPARE_STALE and exits 1 unless allow_stale=1 - a stale map
# makes the comparison meaningless, not merely noisy.
extends SceneTree

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const RIVER_SCRIPT_PATH := "res://addons/waterways/river_manager.gd"
const WATER_SYSTEM_SCRIPT_PATH := "res://addons/waterways/water_system_manager.gd"

const DEFAULT_CASES := [
	{"name": "main_demo", "scene": "res://Demo.tscn"},
	{"name": "obstacle_test", "scene": "res://Demo_obstacle_flow_test.tscn"},
]

const ZONES := ["control", "influence", "boundary"]
const WORST_SAMPLE_LIMIT := 3
const CONTROL_HARD_CONTEXT_MAX := 0.01
const CONTROL_GRADIENT_MAX := 0.02
const SYSTEM_ZERO_MAGNITUDE := 0.01
const MIN_CONTROL_SAMPLES := 50

var _scene_override := ""
var _stride := 4
var _min_flow := 0.05
var _influence_min := 0.05
var _max_control_deg := 15.0
var _max_influence_deg := 35.0
var _height_tolerance := 1.0
var _sharp_deg := 20.0
var _enforce_influence := false
var _allow_stale := false

var _errors := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_args()
	var cases := []
	if _scene_override.is_empty():
		cases = DEFAULT_CASES
	else:
		cases = [{"name": "override", "scene": _scene_override}]
	for case_variant in cases:
		var probe_case := case_variant as Dictionary
		await _run_case(String(probe_case.get("name", "")), String(probe_case.get("scene", "")))
	if _errors.is_empty():
		print("SYSTEM_FLOW_COMPARE_OK")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _parse_args() -> void:
	for arg_variant in OS.get_cmdline_user_args():
		var arg := String(arg_variant)
		if arg.begins_with("scene="):
			_scene_override = arg.trim_prefix("scene=")
		elif arg.begins_with("stride="):
			_stride = maxi(1, int(arg.trim_prefix("stride=")))
		elif arg.begins_with("min_flow="):
			_min_flow = maxf(0.001, float(arg.trim_prefix("min_flow=")))
		elif arg.begins_with("influence_min="):
			_influence_min = clampf(float(arg.trim_prefix("influence_min=")), 0.0, 1.0)
		elif arg.begins_with("max_control_deg="):
			_max_control_deg = maxf(0.1, float(arg.trim_prefix("max_control_deg=")))
		elif arg.begins_with("max_influence_deg="):
			_max_influence_deg = maxf(0.1, float(arg.trim_prefix("max_influence_deg=")))
		elif arg.begins_with("height_tol="):
			_height_tolerance = maxf(0.01, float(arg.trim_prefix("height_tol=")))
		elif arg.begins_with("sharp_deg="):
			_sharp_deg = maxf(0.1, float(arg.trim_prefix("sharp_deg=")))
		elif arg == "enforce=all":
			_enforce_influence = true
		elif arg == "allow_stale=1":
			_allow_stale = true


func _run_case(case_name: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("Could not load scene: " + scene_path)
		return
	var scene := packed.instantiate()
	if scene == null:
		_fail("Could not instantiate scene: " + scene_path)
		return
	root.add_child(scene)
	await _settle_frames(3)
	print("SYSTEM_FLOW_COMPARE_CASE case=", case_name, " scene=", scene_path)

	var water_systems := _find_nodes_by_script(scene, WATER_SYSTEM_SCRIPT_PATH)
	if water_systems.is_empty():
		_fail(case_name + ": no WaterSystem node found in " + scene_path)
	for water_system in water_systems:
		_inspect_water_system(case_name, water_system)

	scene.queue_free()
	await _settle_frames(2)


func _inspect_water_system(case_name: String, water_system: Node) -> void:
	var label := case_name + "/" + String(water_system.name)
	if water_system.get("bake_data") != null:
		water_system.call("_apply_bake_data")
	elif water_system.get("system_map") != null:
		water_system.call("_refresh_system_image")
	else:
		_fail(label + ": WaterSystem has neither bake_data nor system_map - nothing to compare.")
		return
	var sample_probe: Dictionary = water_system.call("_sample_system_map", Vector3.ZERO)
	if sample_probe.is_empty():
		_fail(label + ": WaterSystem sampling image unavailable after applying bake data.")
		return

	var stale_warning := String(water_system.call("_get_stale_source_warning"))
	var gates_enabled := true
	if not stale_warning.is_empty():
		print("SYSTEM_FLOW_COMPARE_STALE system=", label, " warning=", stale_warning)
		if _allow_stale:
			# Comparing against a known-stale map proves nothing either way -
			# report the numbers but do not gate on them.
			gates_enabled = false
			print("  note: allow_stale=1 - thresholds for this system are report-only.")
		else:
			_fail(label + ": saved system map is stale relative to its source rivers (pass allow_stale=1 to compare anyway): " + stale_warning)

	var river_count := 0
	for child in water_system.get_children():
		var script = child.get_script()
		if script == null or script.resource_path != RIVER_SCRIPT_PATH:
			continue
		river_count += 1
		_compare_river(label, water_system, child, gates_enabled)
	if river_count == 0:
		_fail(label + ": WaterSystem has no child rivers to compare.")


func _compare_river(system_label: String, water_system: Node, river: Node, gates_enabled: bool) -> void:
	var label := system_label + "/" + String(river.name)
	if not bool(river.get("valid_flowmap")):
		print("SYSTEM_FLOW_COMPARE_RIVER river=", label, " skipped=invalid_flowmap")
		return
	var bake := river.get("bake_data") as Resource
	if bake == null:
		_fail(label + ": river has valid_flowmap but no bake_data resource.")
		return

	var flow_image := _river_texture_image(river, bake, "flow_foam_noise", label)
	var terrain_image := _river_texture_image(river, bake, "terrain_contact_features", label)
	var bank_image := _river_texture_image(river, bake, "bank_response_features", label)
	if flow_image == null or terrain_image == null or bank_image == null:
		return
	var occupancy_image := _optional_texture_image(river, bake, "water_occupancy")
	var obstacle_image := _optional_texture_image(river, bake, "obstacle_features")
	var atlas_size := flow_image.get_size()
	if terrain_image.get_size() != atlas_size or bank_image.get_size() != atlas_size:
		_fail(label + ": bake texture sizes disagree - cannot pair samples.")
		return

	var content_rect := _get_content_rect(bake, flow_image)
	var source_size: Vector2i = bake.get("source_texture_size")
	if source_size.x <= 0 or source_size.y <= 0:
		source_size = content_rect.size
	var uv2_sides := maxi(1, int(bake.get("uv2_sides")))
	var occupied_steps := _get_occupied_steps(bake, uv2_sides)
	var side: int = maxi(1, WaterHelperMethods.calculate_side(occupied_steps))
	if side != uv2_sides:
		print("  note: calculate_side(", occupied_steps, ")=", side, " != bake uv2_sides=", uv2_sides)

	var mesh_instance := river.get("mesh_instance") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		_fail(label + ": river has no generated mesh.")
		return
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uv1 := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var uv2 := arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	if verts.is_empty() or uv1.is_empty() or uv2.is_empty():
		_fail(label + ": river mesh is missing vertex/UV/UV2 arrays.")
		return
	var world_verts := PackedVector3Array()
	world_verts.resize(verts.size())
	for vertex_index in verts.size():
		world_verts[vertex_index] = mesh_instance.global_transform * verts[vertex_index]
	var step_length_divs := clampi(int(river.get("shape_step_length_divs")), 1, 8)
	var step_width_divs := clampi(int(river.get("shape_step_width_divs")), 1, 8)
	var tris_in_step_quad := step_length_divs * step_width_divs * 2

	var flow_projected := false
	var source_metadata = bake.get("source_metadata")
	if typeof(source_metadata) == TYPE_DICTIONARY:
		flow_projected = bool((source_metadata as Dictionary).get("flow_projected", false))
	var probe_scale := 1.0
	var probe_param = river.call("get_shader_param", "flow_boundary_probe")
	if probe_param != null:
		probe_scale = maxf(0.25, float(probe_param))
	var probe_offset := Vector2(probe_scale / float(atlas_size.x), probe_scale / float(atlas_size.y))

	var zone_angles := {}
	var zone_ratios := {}
	var zone_worst := {}
	for zone in ZONES:
		zone_angles[zone] = []
		zone_ratios[zone] = []
		zone_worst[zone] = []
	var counts := {
		"visited": 0,
		"solid": 0,
		"low_flow": 0,
		"sharp_structure": 0,
		"no_triangle": 0,
		"degenerate": 0,
		"no_coverage": 0,
		"height_mismatch": 0,
		"system_zero": 0,
	}
	var system_bounds: AABB = water_system.call("_get_system_bounds")

	var sample_y := 0
	while sample_y < source_size.y:
		var sample_x := 0
		while sample_x < source_size.x:
			_compare_sample(
				water_system, system_bounds, sample_x, sample_y, content_rect, atlas_size,
				flow_image, terrain_image, bank_image, occupancy_image, obstacle_image,
				uv1, uv2, world_verts, source_size, side, occupied_steps, tris_in_step_quad,
				probe_offset, counts, zone_angles, zone_ratios, zone_worst
			)
			sample_x += _stride
		sample_y += _stride

	print("SYSTEM_FLOW_COMPARE_RIVER river=", label,
			" flow_projected=", flow_projected,
			" occupancy=", occupancy_image != null,
			" stride=", _stride, " counts=", counts)
	for zone_variant in ZONES:
		var zone := String(zone_variant)
		var angles: Array = zone_angles[zone]
		var stats := _stats(angles)
		var ratio_stats := _stats(zone_ratios[zone])
		print("  zone=", zone, " count=", angles.size(),
				" angle_deg mean=", stats.mean, " p50=", stats.p50, " p90=", stats.p90, " max=", stats.max,
				" mag_ratio p50=", ratio_stats.p50, " min=", ratio_stats.min, " max=", ratio_stats.max)
		for worst_variant in zone_worst[zone]:
			var worst := worst_variant as Dictionary
			print("    worst angle_deg=", worst.angle, " source_pixel=", worst.pixel, " world=", worst.world)

	_evaluate_gates(label, flow_projected, zone_angles, gates_enabled)


func _compare_sample(
		water_system: Node, system_bounds: AABB, x: int, y: int, content_rect: Rect2i, atlas_size: Vector2i,
		flow_image: Image, terrain_image: Image, bank_image: Image, occupancy_image: Image, obstacle_image: Image,
		uv1: PackedVector2Array, uv2: PackedVector2Array, world_verts: PackedVector3Array,
		source_size: Vector2i, side: int, occupied_steps: int, tris_in_step_quad: int,
		probe_offset: Vector2, counts: Dictionary, zone_angles: Dictionary, zone_ratios: Dictionary, zone_worst: Dictionary
) -> void:
	counts.visited += 1
	var atlas_pixel := content_rect.position + Vector2i(x, y)
	var occupancy := Color(0.0, 0.0, 0.0, 1.0)
	if occupancy_image != null:
		occupancy = occupancy_image.get_pixelv(atlas_pixel)
		if occupancy.r > 0.5:
			counts.solid += 1
			return
	var flow_color := flow_image.get_pixelv(atlas_pixel)
	var flow_uv := Vector2(flow_color.r, flow_color.g) * 2.0 - Vector2.ONE
	var flow_magnitude := flow_uv.length()
	if flow_magnitude < _min_flow:
		counts.low_flow += 1
		return

	# Sharp-structure exclusion (2026-06-12, post-R2 finding): the system
	# render samples the flow atlas bilinearly at fragment positions, so where
	# the baked field changes sharply texel-to-texel (the occupancy stilling
	# ring, solid rims, eddy edges) the saved map holds a neighbor blend that
	# no single-texel expectation can match - measured at up to 25-29 deg p90
	# in influence zones with the slide provably inactive. If a 50/50 blend
	# with any 8-neighbor would already rotate this texel's direction by more
	# than sharp_deg, the comparison is meaningless here; exclude the sample.
	# A slide-class systematic re-bend varies smoothly across neighbors and is
	# NOT excluded by this filter.
	if _is_sharp_structure(flow_image, atlas_pixel, flow_uv):
		counts.sharp_structure += 1
		return

	var terrain := terrain_image.get_pixelv(atlas_pixel)
	var bank := bank_image.get_pixelv(atlas_pixel)
	var hard_context := maxf(bank.a, terrain.b)
	var is_influence := false
	if occupancy_image != null:
		is_influence = occupancy.g > _influence_min
	elif obstacle_image != null:
		is_influence = obstacle_image.get_pixelv(atlas_pixel).a > _influence_min
	var atlas_uv := Vector2(
		(float(atlas_pixel.x) + 0.5) / float(atlas_size.x),
		(float(atlas_pixel.y) + 0.5) / float(atlas_size.y)
	)
	var gradient := _boundary_gradient(terrain_image, bank_image, atlas_uv, probe_offset)
	var zone := "boundary"
	if is_influence:
		zone = "influence"
	elif hard_context < CONTROL_HARD_CONTEXT_MAX and gradient.length() < CONTROL_GRADIENT_MAX:
		zone = "control"

	var triangle := _find_uv2_triangle(uv2, source_size, side, occupied_steps, tris_in_step_quad, x, y)
	if triangle.is_empty():
		counts.no_triangle += 1
		return
	var i0 := int(triangle.i0)
	var i1 := int(triangle.i1)
	var i2 := int(triangle.i2)
	var bary: Vector3 = triangle.bary
	var world_position: Vector3 = WaterHelperMethods.bary2cart(world_verts[i0], world_verts[i1], world_verts[i2], bary)

	var uv_a := uv1[i1] - uv1[i0]
	var uv_b := uv1[i2] - uv1[i0]
	var det := uv_a.x * uv_b.y - uv_a.y * uv_b.x
	if absf(det) <= 0.0000001:
		counts.degenerate += 1
		return
	var world_a := Vector2(world_verts[i1].x - world_verts[i0].x, world_verts[i1].z - world_verts[i0].z)
	var world_b := Vector2(world_verts[i2].x - world_verts[i0].x, world_verts[i2].z - world_verts[i0].z)
	var world_du := (world_a * uv_b.y - world_b * uv_a.y) / det
	var world_dv := (world_b * uv_a.x - world_a * uv_b.x) / det
	if world_du.length() <= 0.0000001 or world_dv.length() <= 0.0000001:
		counts.degenerate += 1
		return
	# system_flow.gdshader's get_world_xz_from_uv_axes normalizes both axis
	# columns before applying them to the flow vector - mirror that exactly.
	var expected := world_du.normalized() * flow_uv.x + world_dv.normalized() * flow_uv.y
	if expected.length() <= 0.0000001:
		counts.degenerate += 1
		return
	var expected_direction := expected.normalized()

	# Bilinear pairing over the same image get_water_flow reads: the runtime
	# samples nearest-texel, but for this gate the half-pixel offset between
	# our river-texel world position and the system pixel center is pure
	# sampling noise - interpolating removes it without changing what data is
	# being compared.
	var sample := _sample_system_bilinear(water_system, world_position)
	if not bool(sample.get("valid", false)):
		counts.no_coverage += 1
		return
	var system_color: Color = sample.get("color", Color())
	# The system map is a top-down render: where two water surfaces overlap in
	# XZ (or at edge bleed), the sampled pixel may belong to a different
	# surface than our river point. The map's own height channel disambiguates.
	var system_height := system_color.b * system_bounds.size.y + system_bounds.position.y
	if absf(system_height - world_position.y) > _height_tolerance:
		counts.height_mismatch += 1
		return
	var system_flow := Vector2(system_color.r, system_color.g) * 2.0 - Vector2.ONE
	var system_magnitude := system_flow.length()
	if system_magnitude < SYSTEM_ZERO_MAGNITUDE:
		counts.system_zero += 1
		return
	var system_direction := system_flow / system_magnitude
	var angle_deg := rad_to_deg(acos(clampf(expected_direction.dot(system_direction), -1.0, 1.0)))
	var magnitude_ratio := system_magnitude / flow_magnitude

	(zone_angles[zone] as Array).append(angle_deg)
	(zone_ratios[zone] as Array).append(magnitude_ratio)
	_track_worst(zone_worst[zone] as Array, angle_deg, Vector2i(x, y), world_position)


func _evaluate_gates(label: String, flow_projected: bool, zone_angles: Dictionary, gates_enabled: bool) -> void:
	var control: Array = zone_angles["control"]
	if control.is_empty():
		_fail(label + ": no control-zone samples - machinery cannot be sanity-checked (river too small or stride too coarse).")
	else:
		if control.size() < MIN_CONTROL_SAMPLES:
			print("  note: only ", control.size(), " control samples - control gate is weakly powered.")
		var control_p90: float = _stats(control).p90
		if gates_enabled and control_p90 > _max_control_deg:
			print("SYSTEM_FLOW_COMPARE_EXCEEDED river=", label, " zone=control p90_deg=", control_p90, " limit=", _max_control_deg)
			_fail(label + ": control-zone angular delta p90 " + str(control_p90) + " deg exceeds " + str(_max_control_deg) + " deg - sampling machinery or saved map is suspect (stale map?).")

	var influence: Array = zone_angles["influence"]
	if influence.is_empty():
		print("  note: no influence-zone samples - no obstacle influence on this river; R2 gate not applicable.")
		return
	var influence_p90: float = _stats(influence).p90
	var enforced := _enforce_influence and flow_projected and gates_enabled
	print("SYSTEM_FLOW_COMPARE_INFLUENCE river=", label, " p90_deg=", influence_p90,
			" limit=", _max_influence_deg, " flow_projected=", flow_projected, " enforced=", enforced)
	if enforced and influence_p90 > _max_influence_deg:
		print("SYSTEM_FLOW_COMPARE_EXCEEDED river=", label, " zone=influence p90_deg=", influence_p90, " limit=", _max_influence_deg)
		_fail(label + ": influence-zone angular delta p90 " + str(influence_p90) + " deg exceeds " + str(_max_influence_deg) + " deg - gross systematic divergence between the system map and the river's projected flow (the slide-gate mechanism itself is covered by system_flow_projected_gate_probe).")


# Bilinearly interpolates the WaterSystem's sampling image at a world
# position (same uv mapping and coverage threshold as _sample_system_map).
# Texels under the coverage threshold are excluded from the blend; if none of
# the four neighbors has coverage, the sample is invalid.
func _sample_system_bilinear(water_system: Node, world_position: Vector3) -> Dictionary:
	var image := water_system.get("_system_img") as Image
	if image == null:
		return {"valid": false}
	var uv: Vector2 = water_system.call("_world_position_to_map_uv", world_position)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return {"valid": false}
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return {"valid": false}
	var px := uv.x * float(width) - 0.5
	var py := uv.y * float(height) - 0.5
	var x0 := clampi(int(floor(px)), 0, width - 1)
	var y0 := clampi(int(floor(py)), 0, height - 1)
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var fx := clampf(px - float(x0), 0.0, 1.0)
	var fy := clampf(py - float(y0), 0.0, 1.0)
	var texels := [image.get_pixel(x0, y0), image.get_pixel(x1, y0), image.get_pixel(x0, y1), image.get_pixel(x1, y1)]
	var weights := [(1.0 - fx) * (1.0 - fy), fx * (1.0 - fy), (1.0 - fx) * fy, fx * fy]
	var blended := Color(0.0, 0.0, 0.0, 0.0)
	var total_weight := 0.0
	for texel_index in 4:
		var texel: Color = texels[texel_index]
		if texel.a <= 0.001:
			continue
		var weight: float = weights[texel_index]
		blended += texel * weight
		total_weight += weight
	if total_weight <= 0.0001:
		return {"valid": false}
	return {"valid": true, "color": blended / total_weight}


# Mirrors WaterHelperMethods._get_uv2_world_sample's triangle search but also
# returns the triangle's vertex indices so UV1 world tangents can be derived.
func _find_uv2_triangle(uv2: PackedVector2Array, source_size: Vector2i, side: int, occupied_steps: int, tris_in_step_quad: int, x: int, y: int) -> Dictionary:
	var column: int = WaterHelperMethods._uv2_atlas_axis_index(x, source_size.x, side)
	var row: int = WaterHelperMethods._uv2_atlas_axis_index(y, source_size.y, side)
	var step_quad := column * side + row
	if step_quad >= occupied_steps:
		return {}
	var uv_coordinate := Vector2((0.5 + float(x)) / float(source_size.x), (0.5 + float(y)) / float(source_size.y))
	var p := Vector3(uv_coordinate.x, uv_coordinate.y, 0.0)
	for tris in tris_in_step_quad:
		var triangle_index := ((tris_in_step_quad * step_quad) + tris) * 3
		if triangle_index + 2 >= uv2.size():
			continue
		if WaterHelperMethods._is_degenerate_uv_triangle(uv2[triangle_index], uv2[triangle_index + 1], uv2[triangle_index + 2]):
			continue
		var a := Vector3(uv2[triangle_index].x, uv2[triangle_index].y, 0.0)
		var b := Vector3(uv2[triangle_index + 1].x, uv2[triangle_index + 1].y, 0.0)
		var c := Vector3(uv2[triangle_index + 2].x, uv2[triangle_index + 2].y, 0.0)
		var bary: Vector3 = WaterHelperMethods.cart2bary(p, a, b, c)
		if WaterHelperMethods.point_in_bariatric(bary):
			return {
				"i0": triangle_index,
				"i1": triangle_index + 1,
				"i2": triangle_index + 2,
				"bary": bary,
			}
	return {}


func _is_sharp_structure(flow_image: Image, atlas_pixel: Vector2i, flow_uv: Vector2) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var neighbor_pixel := atlas_pixel + Vector2i(offset_x, offset_y)
			if neighbor_pixel.x < 0 or neighbor_pixel.y < 0 \
					or neighbor_pixel.x >= flow_image.get_width() or neighbor_pixel.y >= flow_image.get_height():
				continue
			var neighbor_color := flow_image.get_pixelv(neighbor_pixel)
			var neighbor_uv := Vector2(neighbor_color.r, neighbor_color.g) * 2.0 - Vector2.ONE
			var blend := (flow_uv + neighbor_uv) * 0.5
			if blend.length() <= 0.000001:
				return true
			if absf(rad_to_deg(flow_uv.angle_to(blend))) > _sharp_deg:
				return true
	return false


# CPU mirror of system_flow.gdshader's boundary_context_at/boundary_gradient_at
# (nearest-texel reads; classification only, never fed into the comparison).
func _boundary_gradient(terrain_image: Image, bank_image: Image, uv: Vector2, offset: Vector2) -> Vector2:
	var dx := Vector2(offset.x, 0.0)
	var dy := Vector2(0.0, offset.y)
	return Vector2(
		_boundary_context(terrain_image, bank_image, uv + dx) - _boundary_context(terrain_image, bank_image, uv - dx),
		_boundary_context(terrain_image, bank_image, uv + dy) - _boundary_context(terrain_image, bank_image, uv - dy)
	)


func _boundary_context(terrain_image: Image, bank_image: Image, uv: Vector2) -> float:
	var safe_uv := uv.clamp(Vector2.ZERO, Vector2.ONE)
	var pixel := Vector2i(
		clampi(int(safe_uv.x * float(terrain_image.get_width())), 0, terrain_image.get_width() - 1),
		clampi(int(safe_uv.y * float(terrain_image.get_height())), 0, terrain_image.get_height() - 1)
	)
	var terrain := terrain_image.get_pixelv(pixel)
	var bank := bank_image.get_pixelv(pixel)
	var hard_context := maxf(bank.a, terrain.b)
	var soft_contact := maxf(bank.r * 0.35, terrain.r * 0.25)
	return clampf(maxf(hard_context, soft_contact), 0.0, 1.0)


func _river_texture_image(river: Node, bake: Resource, property_name: String, label: String) -> Image:
	var image := _optional_texture_image(river, bake, property_name)
	if image == null:
		_fail(label + ": missing or unreadable bake texture " + property_name)
	return image


func _optional_texture_image(river: Node, bake: Resource, property_name: String) -> Image:
	var texture := river.get(property_name) as Texture2D
	if texture == null:
		texture = bake.get(property_name) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


func _get_content_rect(bake: Resource, image: Image) -> Rect2i:
	var rect := bake.get("content_rect") as Rect2i
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i(Vector2i.ZERO, image.get_size())
	var position := Vector2i(
		clampi(rect.position.x, 0, image.get_width() - 1),
		clampi(rect.position.y, 0, image.get_height() - 1)
	)
	var end := Vector2i(
		clampi(rect.position.x + rect.size.x, position.x + 1, image.get_width()),
		clampi(rect.position.y + rect.size.y, position.y + 1, image.get_height())
	)
	return Rect2i(position, end - position)


func _get_occupied_steps(bake: Resource, uv2_sides: int) -> int:
	var total_tiles := uv2_sides * uv2_sides
	var signature = bake.get("source_signature")
	if typeof(signature) == TYPE_DICTIONARY:
		var signature_steps := int((signature as Dictionary).get("step_count", 0))
		if signature_steps > 0:
			return clampi(signature_steps, 1, total_tiles)
	return total_tiles


func _find_nodes_by_script(node: Node, script_path: String) -> Array:
	var found := []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current := stack.pop_back() as Node
		for child in current.get_children():
			stack.push_back(child)
		var script = current.get_script()
		if script != null and script.resource_path == script_path:
			found.append(current)
	return found


func _track_worst(worst: Array, angle_deg: float, pixel: Vector2i, world_position: Vector3) -> void:
	if worst.size() >= WORST_SAMPLE_LIMIT and angle_deg <= float((worst[worst.size() - 1] as Dictionary).angle):
		return
	worst.append({
		"angle": snappedf(angle_deg, 0.001),
		"pixel": pixel,
		"world": Vector3(snappedf(world_position.x, 0.001), snappedf(world_position.y, 0.001), snappedf(world_position.z, 0.001)),
	})
	worst.sort_custom(func(a, b): return float((a as Dictionary).angle) > float((b as Dictionary).angle))
	if worst.size() > WORST_SAMPLE_LIMIT:
		worst.resize(WORST_SAMPLE_LIMIT)


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p90": 0.0, "min": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return {
		"mean": snappedf(total / float(sorted.size()), 0.001),
		"p50": snappedf(float(sorted[int(0.5 * float(sorted.size() - 1))]), 0.001),
		"p90": snappedf(float(sorted[int(0.9 * float(sorted.size() - 1))]), 0.001),
		"min": snappedf(float(sorted[0]), 0.001),
		"max": snappedf(float(sorted[sorted.size() - 1]), 0.001),
	}


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _fail(message: String) -> void:
	_errors.append(message)
