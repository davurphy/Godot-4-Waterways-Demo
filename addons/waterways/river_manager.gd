# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Node3D

const WaterHelperMethods = preload("./water_helper_methods.gd")
const RiverBakeDataResource = preload("res://addons/waterways/resources/river_bake_data.gd")

const FILTER_RENDERER_PATH = "res://addons/waterways/filter_renderer.tscn"
const FLOW_OFFSET_NOISE_TEXTURE_PATH = "res://addons/waterways/textures/flow_offset_noise.png"
const FOAM_NOISE_PATH = "res://addons/waterways/textures/foam_noise.png"
const GENERATED_MESH_NAME := "RiverMeshInstance"
const GENERATED_MESH_META := "waterways_generated_river_mesh"

const MATERIAL_CATEGORIES = {
	albedo_ = "Albedo",
	emission_ = "Emission",
	transparency_ = "Transparency",
	flow_ = "Flow",
	foam_ = "Foam",
	pillow_ = "Pillow",
	wake_ = "Wake / Eddy",
	custom_ = "Custom"
}

const MATERIAL_PARAMETER_SUBGROUP_LAYOUTS = {
	pillow_ = [
		{
			name = "Pillow Shape",
			parameters = [
				"pillow_strength",
				"pillow_pressure_strength",
				"pillow_highlight_strength",
				"pillow_forward_reach_tiles",
				"pillow_contact_pull_tiles",
				"pillow_contact_pull_strength",
			]
		},
		{
			name = "Pillow Mask Gates",
			parameters = [
				"pillow_confidence_gate_start",
				"pillow_confidence_gate_full",
				"pillow_hard_gate_start",
				"pillow_hard_gate_full",
				"pillow_energy_gate_start",
				"pillow_energy_gate",
				"pillow_flow_gate_start",
				"pillow_flow_gate",
				"pillow_bank_suppression",
			]
		},
		{
			name = "Pillow Surface",
			parameters = [
				"pillow_pressure_color",
				"pillow_highlight_color",
				"pillow_specular_boost",
				"pillow_roughness_reduction",
				"pillow_normal_strength",
			]
		},
		{
			name = "Pillow Bands & Foam",
			parameters = [
				"pillow_band_strength",
				"pillow_band_scale",
				"pillow_foam_bias",
			]
		},
		{
			name = "Pillow Height",
			parameters = [
				"pillow_terrain_height",
				"pillow_terrain_height_curve",
				"pillow_obstruction_height",
				"pillow_obstruction_height_curve",
				"pillow_height_smoothing_tiles",
			]
		},
		{
			name = "Pillow Seam Fades",
			parameters = [
				"pillow_height_seam_stitch_tiles",
				"pillow_height_tile_seam_fade",
				"pillow_material_tile_seam_fade",
			]
		},
	]
}

enum SHADER_TYPES {WATER, LAVA, CUSTOM}
const BUILTIN_SHADERS = [
	{
		name = "Water",
		shader_path = "res://addons/waterways/shaders/river.gdshader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/water1_normal_bump.png"
			}
		]
	},
	{
		name = "Lava",
		shader_path = "res://addons/waterways/shaders/lava.gdshader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/lava_normal_bump.png"
			},
			{
				name = "emission_texture",
				path = "res://addons/waterways/textures/lava_emission.png"
			}
		]
	}
]

const DEBUG_SHADER = {
	name = "Debug",
	shader_path = "res://addons/waterways/shaders/river_debug.gdshader",
	texture_paths = [
		{
			name = "debug_pattern",
			path = "res://addons/waterways/textures/debug_pattern.png"
		},
		{
			name = "debug_arrow",
			path = "res://addons/waterways/textures/debug_arrow.svg"
		}
	]
}

const DEFAULT_PARAMETERS = {
	shape_step_length_divs = 1,
	shape_step_width_divs = 1,
	shape_smoothness = 0.5,
	mat_shader_type = 0,
	mat_custom_shader = null,
	baking_resolution = 2, 
	baking_raycast_distance = 10.0,
	baking_raycast_layers = 1,
	baking_dilate = 0.6,
	baking_flowmap_blur = 0.04,
	baking_foam_cutoff = 0.9,
	baking_foam_offset = 0.1,
	baking_foam_blur = 0.02,
	lod_lod0_distance = 50.0,
}

const MATERIAL_PARAMETER_REVERT_OVERRIDES = {
	pillow_strength = 1.15,
	pillow_confidence_gate_start = 0.07,
	pillow_confidence_gate_full = 0.45,
	pillow_hard_gate_start = 0.08,
	pillow_hard_gate_full = 0.45,
	pillow_energy_gate_start = 0.05,
	pillow_energy_gate = 0.35,
	pillow_flow_gate_start = 0.03,
	pillow_flow_gate = 0.28,
	pillow_bank_suppression = 0.85,
	pillow_pressure_strength = 0.50,
	pillow_highlight_strength = 0.60,
	pillow_pressure_color = Color(0.34, 0.68, 0.78, 1.0),
	pillow_highlight_color = Color(0.72, 0.92, 1.0, 1.0),
	pillow_specular_boost = 0.12,
	pillow_roughness_reduction = 0.18,
	pillow_normal_strength = 0.70,
	pillow_band_strength = 0.55,
	pillow_band_scale = 18.0,
	pillow_foam_bias = 0.14,
	pillow_forward_reach_tiles = 0.0,
	pillow_contact_pull_tiles = 0.0,
	pillow_contact_pull_strength = 0.0,
	pillow_terrain_height = 0.0,
	pillow_terrain_height_curve = 1.35,
	pillow_obstruction_height = 0.0,
	pillow_obstruction_height_curve = 1.35,
	pillow_height_smoothing_tiles = 0.10,
	pillow_height_seam_stitch_tiles = 0.015,
	pillow_height_tile_seam_fade = 0.0,
	pillow_material_tile_seam_fade = 0.0,
	foam_bank_friction_bias = 0.35,
	foam_pillow_anchor_bias = 0.35,
	foam_pillow_visual_bias = 0.35,
	wake_strength = 0.70,
	wake_confidence_gate_start = 0.08,
	wake_confidence_gate_full = 0.45,
	wake_hard_gate_start = 0.06,
	wake_hard_gate_full = 0.40,
	wake_energy_gate_start = 0.03,
	wake_energy_gate = 0.35,
	wake_flow_gate_start = 0.03,
	wake_flow_gate = 0.28,
	wake_bank_suppression = 0.85,
	wake_edge_sample_tiles = 0.024,
	wake_eddy_edge_gate_start = 0.025,
	wake_eddy_edge_gate_full = 0.18,
	wake_eddy_near_wake_gate_start = 0.04,
	wake_eddy_near_wake_gate_full = 0.25,
	wake_eddy_line_strength = 1.85,
	wake_normal_strength = 0.22,
	wake_eddy_line_normal_strength = 0.85,
	wake_roughness_boost = 0.22,
	wake_specular_reduction = 0.12,
	wake_albedo_breakup_strength = 0.18,
	wake_breakup_color = Color(0.42, 0.72, 0.78, 1.0),
	wake_foam_fleck_bias = 0.055,
	wake_eddy_line_foam_bias = 0.18,
	wake_fleck_noise_scale = 42.0,
}

const RUNTIME_RIPPLE_MATERIAL_PARAMETER_SET = {
	"i_ripple_enabled": true,
	"i_ripple_simulation_texture": true,
	"i_ripple_impulse_texture": true,
	"i_ripple_world_to_uv": true,
	"i_ripple_boundary_mask": true,
	"i_ripple_texel_size": true,
	"i_ripple_normal_strength": true,
	"i_ripple_refraction_strength": true,
	"i_ripple_displacement_strength": true,
	"i_ripple_height_fade_distance": true,
	"i_ripple_boundary_fade": true,
}

const BAKE_CHANNEL_FLAT_EPSILON := 0.002
const BAKE_CHANNEL_LOW_CONTRAST_EPSILON := 0.03
const BAKE_CHANNEL_SATURATION_EPSILON := 0.02
const RIVER_BAKE_SOURCE_SIGNATURE_VERSION := 27
# Shader parameters that displace VERTEX.y upward; their sum is the headroom
# added to the mesh's custom AABB.
const DISPLACEMENT_AABB_SHADER_PARAMETERS: Array[String] = ["pillow_terrain_height", "pillow_obstruction_height"]
const RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS := 1
const RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE := "downstream_baseline_collision_support"
const RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY := "curve_only"
const RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY := "legacy_collision_only"
const RIVER_DOWNSTREAM_BASELINE_STRENGTH := 0.25
const RIVER_OBSTACLE_AVOIDANCE_STRENGTH := 0.85
const RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_START := 0.08
const RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_FULL := 0.85
const RIVER_OBSTACLE_AVOIDANCE_SDF_RADIUS_TILES := 0.45
const RIVER_OBSTACLE_AVOIDANCE_SDF_BLUR_TILES := 0.02
const RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_LOOKAHEAD_TILES := 0.08
const RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_STRENGTH := 0.30
const RIVER_OBSTACLE_AVOIDANCE_MIN_DOWNSTREAM_ALIGNMENT := 0.65
const RIVER_OBSTACLE_AVOIDANCE_BANK_FRICTION_SUPPRESSION := 0.85
const RIVER_OBSTACLE_AVOIDANCE_HARD_BOUNDARY_STEERING_GATE := 0.55
# Water occupancy mask (crisp solid interiors + speed-ramp proximity field).
const RIVER_OCCUPANCY_RAMP_TILES := 0.12
# Only terrain that protrudes essentially its full reference height above the
# water surface counts as solid. Lower values mark shallow shelves and bank
# margins (where water still renders and ducks still float) as walls, which
# bakes dead flow zones far larger than the actual obstacles.
const RIVER_OCCUPANCY_PROTRUSION_THRESHOLD := 0.9
# Minimum terrain-contact source confidence (A channel) for protrusion to mark
# occupancy solids. Sits between the physics-collider confidence (0.5) and the
# heightfield confidence (1.0): collider-sourced protrusion is overhang-blind
# (a boulder wider above the waterline reads as protruding even where open
# water passes beneath it) and those colliders are already covered by the
# collision map's facing-aware overhang exemption.
const RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN := 0.75
# Bake-time pressure projection (divergence-free flow solve).
const RIVER_FLOW_PROJECTION_STRIDES: Array[int] = [32, 16, 8, 4, 2, 1, 1, 1]
const RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE := 5
const RIVER_FLOW_TANGENCY_PASSES := 2
const RIVER_OBSTACLE_FEATURE_SUPPORT_START := 0.22
const RIVER_OBSTACLE_FEATURE_SUPPORT_FULL := 0.82
const RIVER_OBSTACLE_FEATURE_FACING_START := 0.35
const RIVER_OBSTACLE_FEATURE_FACING_FULL := 0.92
const RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START := 0.40
const RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL := 0.88
const RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES := 0.07
const RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START := 0.08
const RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL := 0.38
const RIVER_OBSTACLE_FEATURE_WAKE_LENGTH_TILES := 0.70
const RIVER_OBSTACLE_FEATURE_WAKE_WIDTH_TILES := 0.11
const RIVER_OBSTACLE_FEATURE_SIDE_WIDTH_TILES := 0.14
const RIVER_OBSTACLE_FEATURE_WAKE_START := 0.045
const RIVER_OBSTACLE_FEATURE_WAKE_FULL := 0.20
const RIVER_OBSTACLE_FEATURE_BANK_FRICTION_SUPPRESSION := 0.70
const RIVER_OBSTACLE_FEATURE_HARD_BOUNDARY_WAKE_GATE := 0.45
const RIVER_OBSTACLE_FEATURE_CONFIDENCE_START := 0.14
const RIVER_OBSTACLE_FEATURE_CONFIDENCE_FULL := 0.44
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_START := 0.04
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_FULL := 0.22
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_START := 0.06
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_FULL := 0.28
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_START := 0.06
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_FULL := 0.40
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_START := 0.03
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_FULL := 0.35
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_START := 0.62
const RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_FULL := 0.92
const RIVER_TERRAIN_CONTACT_FULL_BAND := 0.08
const RIVER_TERRAIN_CONTACT_FADE_DISTANCE := 0.45
const RIVER_TERRAIN_SHALLOW_FULL_DEPTH := 0.25
const RIVER_TERRAIN_SHALLOW_FADE_DEPTH := 1.25
const RIVER_TERRAIN_PROTRUSION_FADE_HEIGHT := 0.03
const RIVER_TERRAIN_PROTRUSION_FULL_HEIGHT := 0.20
const RIVER_TERRAIN_CONTACT_RAYCAST_UP_OFFSET := 0.75
const RIVER_TERRAIN_CONTACT_RAYCAST_DOWN_DISTANCE := 1.50
const RIVER_TERRAIN_HTERRAIN_SOURCE_CONFIDENCE := 1.0
const RIVER_TERRAIN_PHYSICS_SOURCE_CONFIDENCE := 0.5
const RIVER_TERRAIN_CONTACT_SUPERSAMPLES := 2
const RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND := 0.15
const RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES := 1
const RIVER_BANK_RESPONSE_PROBE_TILES := 0.20
const RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT := 0.85
const RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT := 0.65
const RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT := 0.90
const RIVER_BANK_RESPONSE_OUTSIDE_BEND_START := 0.12
const RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL := 0.70
const RIVER_BANK_RESPONSE_INSIDE_BEND_START := 0.12
const RIVER_BANK_RESPONSE_INSIDE_BEND_FULL := 0.70
const RIVER_BLANK_SUPPORT_VALUE := 0.0
const RIVER_NEUTRAL_GRADE_ENERGY_VALUE := 0.0
const RIVER_GRADE_ENERGY_LOOKAHEAD_TILES := 1.0
const RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES := 1
const RIVER_GRADE_ENERGY_REFERENCE_GRADE := 0.25
const RIVER_NEUTRAL_BEND_BIAS_VALUE := 0.5
# Per-point flow speed factor: 1.0 = neutral, < 1 slows (pools), > 1 speeds up
# (rapids). Applied as a post-projection magnitude scale, so the solve's
# non-penetration guarantee is preserved (direction never changes).
const RIVER_NEUTRAL_FLOW_SPEED_FACTOR := 1.0
const RIVER_FLOW_SPEED_FACTOR_MIN := 0.0
const RIVER_FLOW_SPEED_FACTOR_MAX := 2.0
const RIVER_BEND_BIAS_LOOKAHEAD_TILES := 1.0
const RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES := 1
const RIVER_BEND_BIAS_REFERENCE_RADIANS := 0.45
const RIVER_FLAT_FOAM_SUPPORT_VALUE := 0.25
const RIVER_FLAT_PRESSURE_SUPPORT_VALUE := 0.25
const SOURCE_SIGNATURE_FLOAT_STEP := 0.0001
const SHAPE_STEP_DIVS_MIN := 1
const SHAPE_STEP_DIVS_MAX := 8
const SHAPE_SMOOTHNESS_MIN := 0.1
const SHAPE_SMOOTHNESS_MAX := 5.0
const LOD0_DISTANCE_MIN := 5.0
const LOD0_DISTANCE_MAX := 200.0
const RIVER_BAKE_RESOLUTION_MIN := 0
const RIVER_BAKE_RESOLUTION_MAX := 4
const RIVER_BAKE_TEXTURE_SIZE_MIN := 64
const RIVER_BAKE_TEXTURE_SIZE_MAX := 1024
const BAKING_RAYCAST_DISTANCE_MIN := 0.0
const BAKING_RAYCAST_DISTANCE_MAX := 100.0
const BAKING_RAYCAST_LAYERS_MIN := 0
const BAKING_RAYCAST_LAYERS_MAX := 0xFFFFFFFF
const BAKING_NORMALIZED_MIN := 0.0
const BAKING_NORMALIZED_MAX := 1.0


# Shape Properties
var shape_step_length_divs := 1:
	set(value):
		var sanitized_value := _sanitize_int_range("shape_step_length_divs", value, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX, DEFAULT_PARAMETERS.shape_step_length_divs)
		if sanitized_value == shape_step_length_divs:
			return
		shape_step_length_divs = sanitized_value
		if not _suppress_property_change_notifications:
			_on_geometry_property_changed(true)
var shape_step_width_divs := 1:
	set(value):
		var sanitized_value := _sanitize_int_range("shape_step_width_divs", value, SHAPE_STEP_DIVS_MIN, SHAPE_STEP_DIVS_MAX, DEFAULT_PARAMETERS.shape_step_width_divs)
		if sanitized_value == shape_step_width_divs:
			return
		shape_step_width_divs = sanitized_value
		if not _suppress_property_change_notifications:
			_on_geometry_property_changed(true)
var shape_smoothness := 0.5:
	set(value):
		var sanitized_value := _sanitize_float_range("shape_smoothness", value, SHAPE_SMOOTHNESS_MIN, SHAPE_SMOOTHNESS_MAX, DEFAULT_PARAMETERS.shape_smoothness)
		if is_equal_approx(sanitized_value, shape_smoothness):
			return
		shape_smoothness = sanitized_value
		if not _suppress_property_change_notifications:
			_on_geometry_property_changed(true)

# Material Properties that not handled in shader
var mat_shader_type : int:
	set(value):
		var shader_type := _sanitize_shader_type(value)
		if shader_type == mat_shader_type:
			return
		mat_shader_type = shader_type
		_apply_shader_type()
var mat_custom_shader : Shader:
	set(value):
		var shader := value as Shader
		if mat_custom_shader == shader:
			return
		mat_custom_shader = shader
		_apply_custom_shader()

# LOD Properties
var lod_lod0_distance := 50.0:
	set(value):
		lod_lod0_distance = _sanitize_float_range("lod_lod0_distance", value, LOD0_DISTANCE_MIN, LOD0_DISTANCE_MAX, DEFAULT_PARAMETERS.lod_lod0_distance)
		set_materials("i_lod0_distance", lod_lod0_distance)

# Bake Properties
var baking_resolution := 2:
	set(value):
		var sanitized_value := _sanitize_int_range("baking_resolution", value, RIVER_BAKE_RESOLUTION_MIN, RIVER_BAKE_RESOLUTION_MAX, DEFAULT_PARAMETERS.baking_resolution)
		if sanitized_value == baking_resolution:
			return
		baking_resolution = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_raycast_distance := 10.0:
	set(value):
		var sanitized_value := _sanitize_float_range("baking_raycast_distance", value, BAKING_RAYCAST_DISTANCE_MIN, BAKING_RAYCAST_DISTANCE_MAX, DEFAULT_PARAMETERS.baking_raycast_distance)
		if is_equal_approx(sanitized_value, baking_raycast_distance):
			return
		baking_raycast_distance = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_raycast_layers := 1:
	set(value):
		var sanitized_value := _sanitize_int_range("baking_raycast_layers", value, BAKING_RAYCAST_LAYERS_MIN, BAKING_RAYCAST_LAYERS_MAX, DEFAULT_PARAMETERS.baking_raycast_layers)
		if sanitized_value == baking_raycast_layers:
			return
		baking_raycast_layers = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_dilate := 0.6:
	set(value):
		var sanitized_value := _sanitize_float_range("baking_dilate", value, BAKING_NORMALIZED_MIN, BAKING_NORMALIZED_MAX, DEFAULT_PARAMETERS.baking_dilate)
		if is_equal_approx(sanitized_value, baking_dilate):
			return
		baking_dilate = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_flowmap_blur := 0.04:
	set(value):
		var sanitized_value := _sanitize_float_range("baking_flowmap_blur", value, BAKING_NORMALIZED_MIN, BAKING_NORMALIZED_MAX, DEFAULT_PARAMETERS.baking_flowmap_blur)
		if is_equal_approx(sanitized_value, baking_flowmap_blur):
			return
		baking_flowmap_blur = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_foam_cutoff := 0.9:
	set(value):
		var sanitized_value := _sanitize_float_range("baking_foam_cutoff", value, BAKING_NORMALIZED_MIN, BAKING_NORMALIZED_MAX, DEFAULT_PARAMETERS.baking_foam_cutoff)
		if is_equal_approx(sanitized_value, baking_foam_cutoff):
			return
		baking_foam_cutoff = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_foam_offset := 0.1:
	set(value):
		var sanitized_value := _sanitize_float_range("baking_foam_offset", value, BAKING_NORMALIZED_MIN, BAKING_NORMALIZED_MAX, DEFAULT_PARAMETERS.baking_foam_offset)
		if is_equal_approx(sanitized_value, baking_foam_offset):
			return
		baking_foam_offset = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_foam_blur := 0.02:
	set(value):
		var sanitized_value := _sanitize_float_range("baking_foam_blur", value, BAKING_NORMALIZED_MIN, BAKING_NORMALIZED_MAX, DEFAULT_PARAMETERS.baking_foam_blur)
		if is_equal_approx(sanitized_value, baking_foam_blur):
			return
		baking_foam_blur = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var bake_generation_behavior := RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE:
	set(value):
		var sanitized_value := _sanitize_bake_generation_behavior(value)
		if sanitized_value == bake_generation_behavior:
			return
		bake_generation_behavior = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()

# Public variables
var curve : Curve3D
var widths := []:
	set(value):
		widths = _sanitize_width_array(value)
		_ensure_width_count_for_curve()
		if not _suppress_property_change_notifications and not _first_enter_tree:
			_on_geometry_property_changed(true)
var flow_speeds := []:
	set(value):
		flow_speeds = _sanitize_flow_speed_array(value)
		_ensure_flow_speed_count_for_curve()
		if not _suppress_property_change_notifications and not _first_enter_tree:
			_on_bake_property_changed()
var valid_flowmap := false
var debug_view := 0
var mesh_instance : MeshInstance3D
var flow_foam_noise : Texture2D
var dist_pressure : Texture2D
var obstacle_features : Texture2D
var terrain_contact_features : Texture2D
var bank_response_features : Texture2D
var water_occupancy : Texture2D
var _bake_data_resource : Resource
var bake_data : Resource:
	get:
		return _bake_data_resource
	set(value):
		_bake_data_resource = value
		_apply_bake_data()

# Private variables
var _steps := 2
var _st : SurfaceTool
var _mdt : MeshDataTool
var _debug_material : ShaderMaterial
var _first_enter_tree := true
var _filter_renderer
# Serialised private variables
var _material : ShaderMaterial
var _selected_shader : int = SHADER_TYPES.WATER
var _uv2_sides : int
var _suppress_property_change_notifications := false
var _flowmap_bake_in_progress := false
var _runtime_ripple_owner_id := 0
var _runtime_ripple_owner_node: Node = null
var _runtime_ripple_original_material: ShaderMaterial = null
var _runtime_ripple_original_debug_material: ShaderMaterial = null

# river_changed used to update handles when values are changed on script side
# progress_notified used to up progress bar when baking maps
# albedo_set is needed since the gradient is a custom inspector that needs a signal to update from script side
signal river_changed
signal progress_notified
#signal albedo_set

# Internal Methods
func _get_property_list() -> Array:
	var props = [
		{
			name = "Shape",
			type = TYPE_NIL,
			hint_string = "shape_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_step_length_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_step_width_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_smoothness",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Flow",
			type = TYPE_NIL,
			hint_string = "flow_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			# One factor per curve point (like widths): 1.0 neutral, < 1 pools,
			# > 1 rapids. Scales baked flow magnitude after the projection.
			name = "flow_speeds",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Material",
			type = TYPE_NIL,
			hint_string = "mat_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_shader_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Water, Lava, Custom",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Shader"
		},
	]

	var props2 = []
	var mat_categories = MATERIAL_CATEGORIES.duplicate(true)
	
	if _material.shader != null:
		var shader_params: Array = RenderingServer.get_shader_parameter_list(_material.shader.get_rid())
		shader_params = WaterHelperMethods.reorder_params(shader_params)
		shader_params = _ordered_shader_parameters_for_inspector(shader_params)
		var appended_subgroups := {}
		for p in shader_params:
			if p.name.begins_with("i_"):
				continue
			var parameter_category := _get_material_parameter_category(String(p.name))
			var hit_category = null
			for category in mat_categories:
				if p.name.begins_with(category):
					props2.append({
						name = str("Material/", mat_categories[category]),
						type = TYPE_NIL,
						hint_string = str("mat_", category),
						usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
					})
					hit_category = category
					break
			if hit_category != null:
				mat_categories.erase(hit_category)
			var subgroup_name := _get_material_parameter_subgroup_name(String(p.name), parameter_category)
			if not subgroup_name.is_empty():
				var subgroup_key := str(parameter_category, "/", subgroup_name)
				if not appended_subgroups.has(subgroup_key):
					props2.append({
						name = subgroup_name,
						type = TYPE_NIL,
						hint_string = str("mat_", parameter_category),
						usage = PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
					})
					appended_subgroups[subgroup_key] = true
			var cp := {}
			for k in p:
				cp[k] = p[k]
			cp.name = str("mat_", p.name)
			if _should_use_easing_curve_hint(cp):
				cp.hint = PROPERTY_HINT_EXP_EASING
				cp.hint_string = "EASE"
			props2.append(cp)
	var props3 = [
		{
			name = "Lod",
			type = TYPE_NIL,
			hint_string = "lod_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "lod_lod0_distance",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "5.0, 200.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Baking",
			type = TYPE_NIL,
			hint_string = "baking_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "64, 128, 256, 512, 1024",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_raycast_distance",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 100.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},		
		{
			name = "baking_raycast_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_dilate",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_flowmap_blur",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_foam_cutoff",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_foam_offset",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_foam_blur",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "bake_data",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "RiverBakeData",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "bake_generation_behavior",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_STORAGE
		},
		# Serialize these values without exposing it in the inspector
		{
			name = "curve",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "widths",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "valid_flowmap",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "flow_foam_noise",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "dist_pressure",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "obstacle_features",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "terrain_contact_features",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "bank_response_features",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_material",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "ShaderMaterial",
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_selected_shader",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_uv2_sides",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE
		}
	]
	var combined_props = props + props2 + props3
	return combined_props


func _ordered_shader_parameters_for_inspector(shader_params: Array) -> Array:
	var ordered_params := []
	var consumed_params := {}
	var inserted_layouts := {}
	for param in shader_params:
		var parameter_name := String(param.get("name", ""))
		var category := _get_material_parameter_category(parameter_name)
		if category.is_empty() or not MATERIAL_PARAMETER_SUBGROUP_LAYOUTS.has(category):
			if not consumed_params.has(parameter_name):
				ordered_params.append(param)
			continue
		if bool(inserted_layouts.get(category, false)):
			continue
		for ordered_param in _get_ordered_category_parameters(shader_params, category):
			var ordered_name := String(ordered_param.get("name", ""))
			ordered_params.append(ordered_param)
			consumed_params[ordered_name] = true
		inserted_layouts[category] = true
	return ordered_params


func _get_ordered_category_parameters(shader_params: Array, category: String) -> Array:
	var remaining_params := {}
	for param in shader_params:
		var parameter_name := String(param.get("name", ""))
		if parameter_name.begins_with(category):
			remaining_params[parameter_name] = param
	var ordered_params := []
	for subgroup in MATERIAL_PARAMETER_SUBGROUP_LAYOUTS[category]:
		for parameter_name in subgroup.parameters:
			if remaining_params.has(parameter_name):
				ordered_params.append(remaining_params[parameter_name])
				remaining_params.erase(parameter_name)
	for param in shader_params:
		var parameter_name := String(param.get("name", ""))
		if remaining_params.has(parameter_name):
			ordered_params.append(param)
			remaining_params.erase(parameter_name)
	return ordered_params


func _get_material_parameter_category(parameter_name: String) -> String:
	for category in MATERIAL_CATEGORIES:
		if parameter_name.begins_with(category):
			return String(category)
	return ""


func _get_material_parameter_subgroup_name(parameter_name: String, category: String) -> String:
	if category.is_empty() or not MATERIAL_PARAMETER_SUBGROUP_LAYOUTS.has(category):
		return ""
	for subgroup in MATERIAL_PARAMETER_SUBGROUP_LAYOUTS[category]:
		if parameter_name in subgroup.parameters:
			return String(subgroup.name)
	return ""


func _should_use_easing_curve_hint(property_info: Dictionary) -> bool:
	var parameter_name := String(property_info.get("name", ""))
	if not parameter_name.contains("curve"):
		return false
	return int(property_info.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_NONE


func _set(property: StringName, value: Variant) -> bool:
	var property_name := String(property)
	if property_name == "bake_data":
		bake_data = value
		return true
	if property_name == "bake_generation_behavior":
		set_bake_generation_behavior(String(value))
		return true
	match property_name:
		"shape_step_length_divs":
			set_step_length_divs(int(value))
			return true
		"shape_step_width_divs":
			set_step_width_divs(int(value))
			return true
		"shape_smoothness":
			set_smoothness(float(value))
			return true
		"mat_shader_type":
			set_shader_type(int(value))
			return true
		"mat_custom_shader":
			set_custom_shader(value as Shader)
			return true
		"lod_lod0_distance":
			set_lod0_distance(float(value))
			return true
	if property_name.begins_with("baking_"):
		return _set_baking_property(property_name, value)
	if property_name.begins_with("mat_"):
		var param_name := property_name.trim_prefix("mat_")
		_material.set_shader_parameter(param_name, value)
		if _debug_material != null:
			_debug_material.set_shader_parameter(param_name, value)
		_apply_debug_view_material()
		if param_name in DISPLACEMENT_AABB_SHADER_PARAMETERS:
			_update_mesh_custom_aabb()
		return true
	return false


func _get(property: StringName) -> Variant:
	var property_name := String(property)
	if property_name == "bake_data":
		return bake_data
	if property_name == "bake_generation_behavior":
		return bake_generation_behavior
	match property_name:
		"shape_step_length_divs":
			return shape_step_length_divs
		"shape_step_width_divs":
			return shape_step_width_divs
		"shape_smoothness":
			return shape_smoothness
		"mat_shader_type":
			return mat_shader_type
		"mat_custom_shader":
			return mat_custom_shader
		"lod_lod0_distance":
			return lod_lod0_distance
	if property_name.begins_with("baking_"):
		return _get_baking_property(property_name)
	if property_name.begins_with("mat_"):
		var param_name := property_name.trim_prefix("mat_")
		return  _material.get_shader_parameter(param_name)
	return null


func _property_can_revert(property: StringName) -> bool:
	var property_name := String(property)
	if DEFAULT_PARAMETERS.has(property_name):
		if get(property_name) != DEFAULT_PARAMETERS[property_name]:
			return true
		return false
	if property_name.begins_with("mat_"):
		if _material == null:
			return false
		var param_name := property_name.trim_prefix("mat_")
		if MATERIAL_PARAMETER_REVERT_OVERRIDES.has(param_name):
			return _material.get_shader_parameter(param_name) != MATERIAL_PARAMETER_REVERT_OVERRIDES[param_name]
		return _material.property_can_revert(str("shader_parameter/", param_name)) or _material.property_can_revert(str("shader_param/", param_name))

	return false


func _property_get_revert(property: StringName) -> Variant:
	var property_name := String(property)
	if DEFAULT_PARAMETERS.has(property_name):
		return DEFAULT_PARAMETERS.get(property_name, null)
	if property_name.begins_with("mat_"):
		if _material == null:
			return null
		var param_name := property_name.trim_prefix("mat_")
		if MATERIAL_PARAMETER_REVERT_OVERRIDES.has(param_name):
			return MATERIAL_PARAMETER_REVERT_OVERRIDES[param_name]
		var revert_value := _material.property_get_revert(str("shader_parameter/", param_name))
		if revert_value == null:
			revert_value = _material.property_get_revert(str("shader_param/", param_name))
		return revert_value
	return null


func _init() -> void:
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	_filter_renderer = load(FILTER_RENDERER_PATH)

	_debug_material = ShaderMaterial.new()
	_debug_material.shader = load(DEBUG_SHADER.shader_path) as Shader
	for texture in DEBUG_SHADER.texture_paths:
		_debug_material.set_shader_parameter(texture.name, load(texture.path) as Texture2D)

	_material = ShaderMaterial.new()
	_material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
	for texture in BUILTIN_SHADERS[mat_shader_type].texture_paths:
		var texture_resource := load(texture.path) as Texture2D
		_material.set_shader_parameter(texture.name, texture_resource)
		if texture.name == "normal_bump_texture":
			_debug_material.set_shader_parameter(texture.name, texture_resource)
	# Have to manually set the color or it does not default right. Not sure how to work around this
	_material.set_shader_parameter("albedo_color", Transform3D(Vector3(0.0, 0.8, 1.0), Vector3(0.15, 0.2, 0.5), Vector3.ZERO, Vector3.ZERO))


func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false
	
	if not curve:
		curve = Curve3D.new()
		curve.bake_interval = 0.05
		curve.add_point(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		curve.add_point(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		_set_widths_without_property_notifications([1.0, 1.0])
		_set_flow_speeds_without_property_notifications([RIVER_NEUTRAL_FLOW_SPEED_FACTOR, RIVER_NEUTRAL_FLOW_SPEED_FACTOR])
	_sanitize_authoring_properties()
	
	_ensure_generated_mesh_instance()
	_sync_debug_material_from_visible_material()
	
	_generate_river()
	
	_apply_bake_data()
	set_materials("i_valid_flowmap", valid_flowmap)
	set_materials("i_uv2_sides", _uv2_sides)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_obstacle_features", obstacle_features)
	set_materials("i_terrain_contact_features", terrain_contact_features)
	set_materials("i_bank_response_features", bank_response_features)
	set_materials("i_texture_foam_noise", load(FOAM_NOISE_PATH) as Texture2D)


func _exit_tree() -> void:
	_restore_runtime_ripple_material_state()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not valid_flowmap:
		warnings.append("No flowmap is set. Select River -> Generate Flow & Foam Map to generate and assign one.")
	elif _has_unsaved_generated_textures():
		warnings.append("Generated River maps are not stored in an external .res bake resource. Save the scene, then rebake before running with F6 or exporting.")
	return warnings


# Public Methods - These should all be good to use as API from other scripts
func is_bake_in_progress() -> bool:
	return _flowmap_bake_in_progress


func add_point(position : Vector3, index : int, dir : Vector3 = Vector3.ZERO, width : float = 0.0) -> void:
	if index == -1:
		var last_index := curve.get_point_count() - 1
		var dist := position.distance_to(curve.get_point_position(last_index))
		var new_dir: Vector3 = dir if dir != Vector3.ZERO else (position - curve.get_point_position(last_index) - curve.get_point_out(last_index) ).normalized() * 0.25 * dist
		curve.add_point(position, -new_dir, new_dir, -1)
		widths.append(_get_width_for_point(widths.size() - 1)) # If this is a new point at the end, add a width that's the same as last
		flow_speeds.append(_get_flow_speed_for_point(flow_speeds.size() - 1))
	else:
		var dist := curve.get_point_position(index).distance_to(curve.get_point_position(index + 1))
		var new_dir: Vector3 = dir if dir != Vector3.ZERO else (curve.get_point_position(index + 1) - curve.get_point_position(index)).normalized() * 0.25 * dist
		curve.add_point(position, -new_dir, new_dir, index + 1)
		var new_width = _sanitize_width_value(width, "width") if width != 0.0 else (_get_width_for_point(index) + _get_width_for_point(index + 1)) / 2.0
		widths.insert(index + 1, new_width) # We set the width to the average of the two surrounding widths
		flow_speeds.insert(index + 1, (_get_flow_speed_for_point(index) + _get_flow_speed_for_point(index + 1)) / 2.0)
	_invalidate_generated_bake(true, true)


func insert_point_with_handles(position: Vector3, index: int, point_in: Vector3, point_out: Vector3, width: float) -> void:
	var insert_index := index
	if insert_index < 0:
		insert_index = 0
	if insert_index > curve.get_point_count():
		insert_index = curve.get_point_count()
	var curve_insert_index := insert_index
	if insert_index >= curve.get_point_count():
		curve_insert_index = -1
	curve.add_point(position, point_in, point_out, curve_insert_index)
	var safe_width := _sanitize_width_value(width, "width")
	if insert_index >= widths.size():
		widths.append(safe_width)
	else:
		widths.insert(insert_index, safe_width)
	var neighbor_flow_speed := (_get_flow_speed_for_point(maxi(insert_index - 1, 0)) + _get_flow_speed_for_point(insert_index)) / 2.0
	if insert_index >= flow_speeds.size():
		flow_speeds.append(neighbor_flow_speed)
	else:
		flow_speeds.insert(insert_index, neighbor_flow_speed)
	_invalidate_generated_bake(true, true)


func get_curve_state() -> Dictionary:
	var positions := PackedVector3Array()
	var point_ins := PackedVector3Array()
	var point_outs := PackedVector3Array()
	for point_index in curve.get_point_count():
		positions.append(curve.get_point_position(point_index))
		point_ins.append(curve.get_point_in(point_index))
		point_outs.append(curve.get_point_out(point_index))
	return {
		"positions": positions,
		"point_ins": point_ins,
		"point_outs": point_outs,
		"widths": widths.duplicate(true),
		"flow_speeds": flow_speeds.duplicate(true)
	}


func restore_curve_state(state: Dictionary) -> void:
	var positions: PackedVector3Array = state.get("positions", PackedVector3Array())
	var point_ins: PackedVector3Array = state.get("point_ins", PackedVector3Array())
	var point_outs: PackedVector3Array = state.get("point_outs", PackedVector3Array())
	_set_widths_without_property_notifications(state.get("widths", []).duplicate(true))
	_set_flow_speeds_without_property_notifications(state.get("flow_speeds", []).duplicate(true))
	curve.clear_points()
	for point_index in positions.size():
		var point_in := Vector3.ZERO
		var point_out := Vector3.ZERO
		if point_index < point_ins.size():
			point_in = point_ins[point_index]
		if point_index < point_outs.size():
			point_out = point_outs[point_index]
		curve.add_point(positions[point_index], point_in, point_out, -1)
	_ensure_width_count_for_curve()
	_ensure_flow_speed_count_for_curve()
	_invalidate_generated_bake(true, true)


func get_generated_bake_valid_state() -> Dictionary:
	return {
		"valid_flowmap": valid_flowmap,
		"shader_i_valid_flowmap": _get_valid_flowmap_shader_state(valid_flowmap)
	}


func restore_generated_bake_valid_state(state: Dictionary) -> void:
	var restored_valid := bool(state.get("valid_flowmap", false))
	var shader_value = state.get("shader_i_valid_flowmap", restored_valid)
	if shader_value == null:
		shader_value = restored_valid
	var restored_shader_valid := bool(shader_value)
	_set_valid_flowmap(restored_valid)
	if restored_shader_valid != restored_valid:
		set_materials("i_valid_flowmap", restored_shader_valid)


func restore_curve_state_with_generated_bake_valid_state(curve_state: Dictionary, bake_valid_state: Dictionary) -> void:
	restore_curve_state(curve_state)
	restore_generated_bake_valid_state(bake_valid_state)


func remove_point(index : int) -> void:
	# We don't allow rivers shorter than 2 points
	if curve.get_point_count() <= 2:
		return
	curve.remove_point(index)
	widths.remove_at(index)
	if index < flow_speeds.size():
		flow_speeds.remove_at(index)
	_invalidate_generated_bake(true, true)


func bake_texture() -> void:
	if not _begin_flowmap_bake_request():
		return
	var flowmap_resolution := _get_river_bake_texture_size()
	var setup_failures := _get_bake_preflight_failures(flowmap_resolution, false)
	if not setup_failures.is_empty():
		_warn_bake_preflight_failures(setup_failures)
		_clear_flowmap_bake_request()
		return
	_generate_river()
	var mesh_failures := _get_bake_preflight_failures(flowmap_resolution, true)
	if not mesh_failures.is_empty():
		_warn_bake_preflight_failures(mesh_failures)
		_clear_flowmap_bake_request()
		return
	_generate_flowmap(flowmap_resolution)


func set_bake_generation_behavior(value: String) -> void:
	bake_generation_behavior = value


func set_curve_point_position(index : int, position : Vector3) -> void:
	curve.set_point_position(index, position)
	_invalidate_generated_bake(true, false)


func set_curve_point_in(index : int, position : Vector3) -> void:
	curve.set_point_in(index, position)
	_invalidate_generated_bake(true, false)


func set_curve_point_out(index : int, position : Vector3) -> void:
	curve.set_point_out(index, position)
	_invalidate_generated_bake(true, false)


func set_widths(new_widths : Array) -> void:
	widths = new_widths


func set_flow_speeds(new_flow_speeds : Array) -> void:
	flow_speeds = new_flow_speeds


func set_materials(param : String, value) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)
	if _debug_material != null:
		_debug_material.set_shader_parameter(param, value)


func apply_runtime_ripple_material_state(owner: Object, parameters: Dictionary) -> bool:
	if owner == null:
		push_warning("Cannot apply runtime ripple material state without an owner.")
		return false
	if _material == null:
		push_warning("Cannot apply runtime ripple material state because the river has no ShaderMaterial.")
		return false

	var validation_error := _validate_runtime_ripple_material_parameters(parameters)
	if not validation_error.is_empty():
		push_warning(validation_error)
		return false
	if parameters.is_empty():
		return true

	var owner_id := owner.get_instance_id()
	if _runtime_ripple_owner_id != 0 and _runtime_ripple_owner_id != owner_id:
		push_warning("Cannot apply runtime ripple material state because another ripple owner already controls this river.")
		return false

	var parameter_names := _get_runtime_ripple_parameter_names(parameters)
	if not _shader_material_has_parameters(_material, parameter_names):
		push_warning("Cannot apply runtime ripple material state because the river material does not declare all requested i_ripple_* uniforms.")
		return false

	if _runtime_ripple_owner_id == 0:
		var visible_duplicate := _duplicate_runtime_ripple_material(_material)
		if visible_duplicate == null:
			push_warning("Cannot apply runtime ripple material state because the visible material could not be duplicated.")
			return false
		var debug_duplicate: ShaderMaterial = null
		if _debug_material != null:
			debug_duplicate = _duplicate_runtime_ripple_material(_debug_material)
			if debug_duplicate == null:
				push_warning("Cannot apply runtime ripple material state because the debug material could not be duplicated.")
				return false
		_runtime_ripple_owner_id = owner_id
		_connect_runtime_ripple_owner(owner)
		_runtime_ripple_original_material = _material
		_runtime_ripple_original_debug_material = _debug_material
		_material = visible_duplicate
		_debug_material = debug_duplicate

	_apply_runtime_ripple_parameters(_material, parameters)
	_apply_runtime_ripple_parameters(_debug_material, parameters)
	_apply_debug_view_material()
	return true


func clear_runtime_ripple_material_state(owner: Object) -> void:
	if _runtime_ripple_owner_id == 0:
		return
	if owner == null or owner.get_instance_id() != _runtime_ripple_owner_id:
		push_warning("Ignoring runtime ripple material clear from a non-owner.")
		return
	_restore_runtime_ripple_material_state()


func has_runtime_ripple_material_state(owner: Object = null) -> bool:
	if _runtime_ripple_owner_id == 0:
		return false
	if owner == null:
		return true
	return owner.get_instance_id() == _runtime_ripple_owner_id


func set_debug_view(index : int) -> void:
	debug_view = index
	_apply_debug_view_material()


func spawn_mesh() -> void:
	if get_parent() == null:
		push_warning("Cannot create MeshInstance3D sibling when River is root.")
		return
	_ensure_generated_mesh_instance()
	if mesh_instance == null:
		push_warning("Cannot create MeshInstance3D sibling because the generated RiverMeshInstance is unavailable.")
		return
	var source_global_transform := mesh_instance.global_transform
	var sibling_mesh := mesh_instance.duplicate(true) as MeshInstance3D
	if sibling_mesh.has_meta(GENERATED_MESH_META):
		sibling_mesh.remove_meta(GENERATED_MESH_META)
	get_parent().add_child(sibling_mesh)
	_assign_generated_mesh_owner(sibling_mesh)
	sibling_mesh.global_transform = source_global_transform
	sibling_mesh.material_override = null;


func get_curve_points() -> PackedVector3Array:
	var points : PackedVector3Array
	for p in curve.get_point_count():
		points.append(curve.get_point_position(p))
	
	return points


func get_closest_point_to(point : Vector3) -> int:
	var points = []
	var closest_distance := 4096.0
	var closest_index
	for p in curve.get_point_count():
		var dist := point.distance_to(curve.get_point_position(p))
		if dist < closest_distance:
			closest_distance = dist
			closest_index = p
	
	return closest_index


func get_shader_param(param : String):
	return _material.get_shader_parameter(param)


# Parameter Setters
func set_step_length_divs(value : int) -> void:
	shape_step_length_divs = value


func set_step_width_divs(value : int) -> void:
	shape_step_width_divs = value


func set_smoothness(value : float) -> void:
	shape_smoothness = value


func set_shader_type(type: int):
	mat_shader_type = type


func _apply_shader_type() -> void:
	if _material == null:
		return
	if mat_shader_type < SHADER_TYPES.WATER or mat_shader_type > SHADER_TYPES.CUSTOM:
		mat_shader_type = _sanitize_shader_type(mat_shader_type)
		return
	if mat_shader_type == SHADER_TYPES.CUSTOM:
		_material.shader = mat_custom_shader
	else:
		_selected_shader = mat_shader_type
		_material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path)
		for texture in BUILTIN_SHADERS[mat_shader_type].texture_paths:
			var texture_resource := load(texture.path) as Texture2D
			_material.set_shader_parameter(texture.name, texture_resource)
			if texture.name == "normal_bump_texture":
				_debug_material.set_shader_parameter(texture.name, texture_resource)
	_sync_debug_material_from_visible_material()
	
	notify_property_list_changed()


func set_custom_shader(shader : Shader) -> void:
	mat_custom_shader = shader


func _apply_custom_shader() -> void:
	if _material == null:
		return
	if mat_custom_shader != null:
		_material.shader = mat_custom_shader
		
		if Engine.is_editor_hint():
			# Ability to fork default shader
			if mat_custom_shader.code == "":
				var selected_shader_index := _selected_shader
				if selected_shader_index < SHADER_TYPES.WATER or selected_shader_index > SHADER_TYPES.LAVA:
					selected_shader_index = SHADER_TYPES.WATER
				var selected_shader = load(BUILTIN_SHADERS[selected_shader_index].shader_path) as Shader
				mat_custom_shader.code = selected_shader.code
	
	if mat_custom_shader != null:
		mat_shader_type = SHADER_TYPES.CUSTOM
	else:
		mat_shader_type = SHADER_TYPES.WATER


func set_lod0_distance(value : float) -> void:
	lod_lod0_distance = value


# Private Methods
func _generate_river() -> void:
	if curve == null:
		return
	_ensure_generated_mesh_instance()
	if mesh_instance == null:
		return
	mesh_instance.transform = Transform3D.IDENTITY
	_steps = _calculate_step_count()
	
	var river_width_values := WaterHelperMethods.generate_river_width_values(curve, _steps, shape_step_length_divs, shape_step_width_divs, widths)
	var uv2_source_resolution := _get_river_bake_texture_size()
	mesh_instance.mesh = WaterHelperMethods.generate_river_mesh(curve, _steps, shape_step_length_divs, shape_step_width_divs, shape_smoothness, river_width_values, uv2_source_resolution)
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		mesh_instance.mesh.surface_set_material(0, _material)
	_update_mesh_custom_aabb()
	_apply_debug_view_material()


# The surface shader displaces VERTEX.y upward by up to the sum of the pillow
# height amplitudes (river.gdshader vertex()). The render AABB must include
# that headroom or the river gets frustum-culled at the undisplaced bounds.
func _update_mesh_custom_aabb() -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var aabb: AABB = mesh_instance.mesh.get_aabb()
	var upward := _get_configured_max_vertical_displacement()
	if upward > 0.0:
		aabb.size.y += upward
	mesh_instance.set_custom_aabb(aabb)


func _get_configured_max_vertical_displacement() -> float:
	var total := 0.0
	for param_name in DISPLACEMENT_AABB_SHADER_PARAMETERS:
		total += _get_float_shader_parameter(param_name)
	return total


func _get_float_shader_parameter(param_name: String) -> float:
	if _material == null:
		return 0.0
	var value = _material.get_shader_parameter(param_name)
	if value == null and _material.shader != null:
		value = RenderingServer.shader_get_parameter_default(_material.shader.get_rid(), param_name)
	if value is float or value is int:
		return float(value)
	return 0.0


func _apply_debug_view_material() -> void:
	if mesh_instance == null:
		return
	if debug_view == 0:
		mesh_instance.material_override = null
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			mesh_instance.mesh.surface_set_material(0, _material)
			mesh_instance.set_surface_override_material(0, null)
		return
	
	_debug_material.set_shader_parameter("mode", debug_view)
	mesh_instance.material_override = _debug_material
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		mesh_instance.set_surface_override_material(0, _debug_material)


func _ensure_generated_mesh_instance() -> void:
	if _is_valid_generated_mesh_instance(mesh_instance):
		_prepare_generated_mesh_instance(mesh_instance)
		return
	var found_mesh := _find_generated_mesh_instance()
	if found_mesh == null:
		found_mesh = MeshInstance3D.new()
		found_mesh.name = GENERATED_MESH_NAME
		add_child(found_mesh)
	mesh_instance = found_mesh
	_prepare_generated_mesh_instance(mesh_instance)


func _find_generated_mesh_instance() -> MeshInstance3D:
	var named_candidate: MeshInstance3D = null
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var child_mesh := child as MeshInstance3D
		if _has_generated_mesh_metadata(child_mesh):
			return child_mesh
		if named_candidate == null and child_mesh.name == GENERATED_MESH_NAME:
			named_candidate = child_mesh
	return named_candidate


func _is_valid_generated_mesh_instance(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node is MeshInstance3D and node.get_parent() == self and (_has_generated_mesh_metadata(node) or node.name == GENERATED_MESH_NAME)


func _prepare_generated_mesh_instance(node: MeshInstance3D) -> void:
	node.set_meta(GENERATED_MESH_META, true)
	_assign_generated_mesh_owner(node)
	if node.mesh != null and node.mesh.get_surface_count() > 0:
		var existing_material := node.mesh.surface_get_material(0)
		if existing_material is ShaderMaterial:
			_material = existing_material as ShaderMaterial
			_sync_debug_material_from_visible_material()


func _has_generated_mesh_metadata(node: Node) -> bool:
	return node != null and node.has_meta(GENERATED_MESH_META) and bool(node.get_meta(GENERATED_MESH_META))


func _assign_generated_mesh_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var edited_scene_root = get_tree().get_edited_scene_root()
	if edited_scene_root != null and edited_scene_root.is_ancestor_of(node):
		node.owner = edited_scene_root


func _sync_debug_material_from_visible_material() -> void:
	if _material == null or _material.shader == null or _debug_material == null or _debug_material.shader == null:
		return
	var debug_parameter_names := _get_shader_parameter_name_set(_debug_material.shader)
	var visible_parameters: Array = RenderingServer.get_shader_parameter_list(_material.shader.get_rid())
	for parameter in visible_parameters:
		var parameter_name := String(parameter.name)
		if debug_parameter_names.has(parameter_name):
			_debug_material.set_shader_parameter(parameter_name, _material.get_shader_parameter(parameter_name))


func _get_shader_parameter_name_set(shader: Shader) -> Dictionary:
	var names := {}
	if shader == null:
		return names
	var parameters: Array = RenderingServer.get_shader_parameter_list(shader.get_rid())
	for parameter in parameters:
		names[String(parameter.name)] = true
	return names


func _validate_runtime_ripple_material_parameters(parameters: Dictionary) -> String:
	for parameter_name_variant in parameters.keys():
		var parameter_name := String(parameter_name_variant)
		if not parameter_name.begins_with("i_ripple_"):
			return "Runtime ripple material state may only set i_ripple_* uniforms; rejected " + parameter_name + "."
		if not RUNTIME_RIPPLE_MATERIAL_PARAMETER_SET.has(parameter_name):
			return "Runtime ripple material state rejected unknown ripple uniform " + parameter_name + "."
	return ""


func _get_runtime_ripple_parameter_names(parameters: Dictionary) -> PackedStringArray:
	var names := PackedStringArray()
	for parameter_name_variant in parameters.keys():
		names.append(String(parameter_name_variant))
	return names


func _shader_material_has_parameters(material: ShaderMaterial, parameter_names: PackedStringArray) -> bool:
	if material == null or material.shader == null:
		return false
	var shader_parameters := _get_shader_parameter_name_set(material.shader)
	for parameter_name in parameter_names:
		if not shader_parameters.has(parameter_name):
			return false
	return true


func _duplicate_runtime_ripple_material(source: ShaderMaterial) -> ShaderMaterial:
	if source == null:
		return null
	var duplicate := source.duplicate(true) as ShaderMaterial
	if duplicate == null:
		return null
	duplicate.resource_local_to_scene = true
	if source.resource_name.is_empty():
		duplicate.resource_name = "RuntimeRippleMaterial"
	else:
		duplicate.resource_name = source.resource_name + " RuntimeRipple"
	return duplicate


func _apply_runtime_ripple_parameters(material: ShaderMaterial, parameters: Dictionary) -> void:
	if material == null or material.shader == null:
		return
	var shader_parameters := _get_shader_parameter_name_set(material.shader)
	for parameter_name_variant in parameters.keys():
		var parameter_name := String(parameter_name_variant)
		if shader_parameters.has(parameter_name):
			material.set_shader_parameter(parameter_name, parameters[parameter_name_variant])


func _restore_runtime_ripple_material_state() -> void:
	if _runtime_ripple_owner_id == 0:
		return
	_disconnect_runtime_ripple_owner()
	_material = _runtime_ripple_original_material
	_debug_material = _runtime_ripple_original_debug_material
	_runtime_ripple_owner_id = 0
	_runtime_ripple_original_material = null
	_runtime_ripple_original_debug_material = null
	_apply_debug_view_material()


func _connect_runtime_ripple_owner(owner: Object) -> void:
	if not owner is Node:
		return
	_runtime_ripple_owner_node = owner as Node
	var callback := Callable(self, "_on_runtime_ripple_owner_tree_exiting")
	if not _runtime_ripple_owner_node.is_connected("tree_exiting", callback):
		_runtime_ripple_owner_node.connect("tree_exiting", callback)


func _disconnect_runtime_ripple_owner() -> void:
	if _runtime_ripple_owner_node == null or not is_instance_valid(_runtime_ripple_owner_node):
		_runtime_ripple_owner_node = null
		return
	var callback := Callable(self, "_on_runtime_ripple_owner_tree_exiting")
	if _runtime_ripple_owner_node.is_connected("tree_exiting", callback):
		_runtime_ripple_owner_node.disconnect("tree_exiting", callback)
	_runtime_ripple_owner_node = null


func _on_runtime_ripple_owner_tree_exiting() -> void:
	_restore_runtime_ripple_material_state()


func _get_bake_preflight_failures(flowmap_resolution: int, require_mesh: bool, generation_behavior: String = "") -> PackedStringArray:
	var checked_generation_behavior := _sanitize_bake_generation_behavior(bake_generation_behavior if generation_behavior.is_empty() else generation_behavior)
	var failures := PackedStringArray()
	if curve == null:
		failures.append("no Curve3D is assigned")
	elif curve.get_point_count() < 2:
		failures.append("the curve needs at least two points")
	elif widths.size() < curve.get_point_count():
		failures.append("width data has fewer entries than curve points")
	if shape_step_length_divs < SHAPE_STEP_DIVS_MIN or shape_step_length_divs > SHAPE_STEP_DIVS_MAX:
		failures.append("shape_step_length_divs must be between " + str(SHAPE_STEP_DIVS_MIN) + " and " + str(SHAPE_STEP_DIVS_MAX))
	if shape_step_width_divs < SHAPE_STEP_DIVS_MIN or shape_step_width_divs > SHAPE_STEP_DIVS_MAX:
		failures.append("shape_step_width_divs must be between " + str(SHAPE_STEP_DIVS_MIN) + " and " + str(SHAPE_STEP_DIVS_MAX))
	if not _is_finite_number(shape_smoothness) or shape_smoothness < SHAPE_SMOOTHNESS_MIN or shape_smoothness > SHAPE_SMOOTHNESS_MAX:
		failures.append("shape_smoothness must be between " + str(SHAPE_SMOOTHNESS_MIN) + " and " + str(SHAPE_SMOOTHNESS_MAX))
	if baking_resolution < RIVER_BAKE_RESOLUTION_MIN or baking_resolution > RIVER_BAKE_RESOLUTION_MAX:
		failures.append("baking_resolution must be between " + str(RIVER_BAKE_RESOLUTION_MIN) + " and " + str(RIVER_BAKE_RESOLUTION_MAX))
	if flowmap_resolution < RIVER_BAKE_TEXTURE_SIZE_MIN or flowmap_resolution > RIVER_BAKE_TEXTURE_SIZE_MAX:
		failures.append("baking_resolution produced an invalid texture size")
	if not _is_finite_number(baking_raycast_distance) or baking_raycast_distance <= 0.0:
		failures.append("baking_raycast_distance must be greater than 0")
	elif baking_raycast_distance > BAKING_RAYCAST_DISTANCE_MAX:
		failures.append("baking_raycast_distance must be no greater than " + str(BAKING_RAYCAST_DISTANCE_MAX))
	if _requires_collision_raycast_layers(checked_generation_behavior) and baking_raycast_layers == 0:
		failures.append("baking_raycast_layers has no collision layers selected")
	if not _is_finite_number(baking_dilate) or baking_dilate < BAKING_NORMALIZED_MIN or baking_dilate > BAKING_NORMALIZED_MAX:
		failures.append("baking_dilate must be between 0 and 1")
	if not _is_finite_number(baking_flowmap_blur) or baking_flowmap_blur < BAKING_NORMALIZED_MIN or baking_flowmap_blur > BAKING_NORMALIZED_MAX:
		failures.append("baking_flowmap_blur must be between 0 and 1")
	if not _is_finite_number(baking_foam_cutoff) or baking_foam_cutoff < BAKING_NORMALIZED_MIN or baking_foam_cutoff > BAKING_NORMALIZED_MAX:
		failures.append("baking_foam_cutoff must be between 0 and 1")
	if not _is_finite_number(baking_foam_offset) or baking_foam_offset < BAKING_NORMALIZED_MIN or baking_foam_offset > BAKING_NORMALIZED_MAX:
		failures.append("baking_foam_offset must be between 0 and 1")
	if not _is_finite_number(baking_foam_blur) or baking_foam_blur < BAKING_NORMALIZED_MIN or baking_foam_blur > BAKING_NORMALIZED_MAX:
		failures.append("baking_foam_blur must be between 0 and 1")
	for width in widths:
		var width_value := float(width)
		if not _is_finite_number(width_value) or width_value < WaterHelperMethods.MIN_RIVER_WIDTH:
			failures.append("all river widths must be finite positive values")
			break
	for flow_speed in flow_speeds:
		var flow_speed_value := float(flow_speed)
		if not _is_finite_number(flow_speed_value) or flow_speed_value < RIVER_FLOW_SPEED_FACTOR_MIN or flow_speed_value > RIVER_FLOW_SPEED_FACTOR_MAX:
			failures.append("all flow speeds must be between " + str(RIVER_FLOW_SPEED_FACTOR_MIN) + " and " + str(RIVER_FLOW_SPEED_FACTOR_MAX))
			break
	if not (_filter_renderer is PackedScene):
		failures.append("filter renderer scene could not be loaded")
	if require_mesh:
		if mesh_instance == null:
			failures.append("no generated RiverMeshInstance is available")
		elif mesh_instance.mesh == null:
			failures.append("RiverMeshInstance has no mesh")
		elif mesh_instance.mesh.get_surface_count() < 1:
			failures.append("RiverMeshInstance mesh has no surfaces")
	return failures


func _warn_bake_preflight_failures(failures: PackedStringArray) -> void:
	push_warning("Cannot generate River flow map: " + "; ".join(failures) + ".")


func _begin_flowmap_bake_request() -> bool:
	if _flowmap_bake_in_progress:
		push_warning("Waterways: River Flow & Foam bake is already in progress; ignoring duplicate request.")
		return false
	_flowmap_bake_in_progress = true
	return true


func _clear_flowmap_bake_request() -> void:
	_flowmap_bake_in_progress = false


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _sanitize_int_range(property_name: String, value: Variant, min_value: int, max_value: int, fallback_value: int) -> int:
	var numeric_value := fallback_value
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		if not _is_finite_number(float_value):
			_warn_sanitized_property(property_name, value, fallback_value)
			return fallback_value
		numeric_value = int(round(float_value))
	else:
		numeric_value = int(value)
	var sanitized_value: int = clamp(numeric_value, min_value, max_value)
	if numeric_value != sanitized_value:
		_warn_sanitized_property(property_name, value, sanitized_value)
	return sanitized_value


func _sanitize_float_range(property_name: String, value: Variant, min_value: float, max_value: float, fallback_value: float) -> float:
	var numeric_value := float(value)
	if not _is_finite_number(numeric_value):
		_warn_sanitized_property(property_name, value, fallback_value)
		return fallback_value
	var sanitized_value: float = clamp(numeric_value, min_value, max_value)
	if not is_equal_approx(numeric_value, sanitized_value):
		_warn_sanitized_property(property_name, value, sanitized_value)
	return sanitized_value


func _sanitize_shader_type(value: Variant) -> int:
	if typeof(value) == TYPE_FLOAT and not _is_finite_number(float(value)):
		_warn_sanitized_property("mat_shader_type", value, SHADER_TYPES.WATER)
		return SHADER_TYPES.WATER
	var shader_type := int(value)
	if shader_type < SHADER_TYPES.WATER or shader_type > SHADER_TYPES.CUSTOM:
		_warn_sanitized_property("mat_shader_type", value, SHADER_TYPES.WATER)
		return SHADER_TYPES.WATER
	return shader_type


func _sanitize_bake_generation_behavior(value: Variant) -> String:
	var behavior := String(value)
	if behavior == RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY:
		return behavior
	if behavior == RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY:
		return behavior
	if behavior == RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE:
		return behavior
	_warn_sanitized_property("bake_generation_behavior", value, RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE)
	return RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE


func _sanitize_authoring_properties() -> void:
	var was_suppressed := _suppress_property_change_notifications
	_suppress_property_change_notifications = true
	shape_step_length_divs = shape_step_length_divs
	shape_step_width_divs = shape_step_width_divs
	shape_smoothness = shape_smoothness
	mat_shader_type = mat_shader_type
	lod_lod0_distance = lod_lod0_distance
	baking_resolution = baking_resolution
	baking_raycast_distance = baking_raycast_distance
	baking_raycast_layers = baking_raycast_layers
	baking_dilate = baking_dilate
	baking_flowmap_blur = baking_flowmap_blur
	baking_foam_cutoff = baking_foam_cutoff
	baking_foam_offset = baking_foam_offset
	baking_foam_blur = baking_foam_blur
	bake_generation_behavior = bake_generation_behavior
	widths = widths
	flow_speeds = flow_speeds
	_suppress_property_change_notifications = was_suppressed


func _set_widths_without_property_notifications(new_widths: Array) -> void:
	var was_suppressed := _suppress_property_change_notifications
	_suppress_property_change_notifications = true
	widths = new_widths
	_suppress_property_change_notifications = was_suppressed


func _set_flow_speeds_without_property_notifications(new_flow_speeds: Array) -> void:
	var was_suppressed := _suppress_property_change_notifications
	_suppress_property_change_notifications = true
	flow_speeds = new_flow_speeds
	_suppress_property_change_notifications = was_suppressed


func _sanitize_flow_speed_array(value: Variant) -> Array:
	var sanitized_flow_speeds := []
	if typeof(value) != TYPE_ARRAY:
		_warn_sanitized_property("flow_speeds", value, "[]")
		return sanitized_flow_speeds
	var source_flow_speeds: Array = value
	for flow_speed_index in source_flow_speeds.size():
		sanitized_flow_speeds.append(_sanitize_flow_speed_value(source_flow_speeds[flow_speed_index], "flow_speeds[" + str(flow_speed_index) + "]"))
	return sanitized_flow_speeds


func _sanitize_flow_speed_value(value: Variant, property_name: String) -> float:
	var flow_speed_value := float(value)
	if not _is_finite_number(flow_speed_value) or flow_speed_value < RIVER_FLOW_SPEED_FACTOR_MIN or flow_speed_value > RIVER_FLOW_SPEED_FACTOR_MAX:
		_warn_sanitized_property(property_name, value, RIVER_NEUTRAL_FLOW_SPEED_FACTOR)
		return RIVER_NEUTRAL_FLOW_SPEED_FACTOR
	return flow_speed_value


func _ensure_flow_speed_count_for_curve() -> void:
	var required_count := 0
	if curve != null:
		required_count = curve.get_point_count()
	if required_count <= 0:
		return
	if flow_speeds.is_empty():
		flow_speeds.append(RIVER_NEUTRAL_FLOW_SPEED_FACTOR)
	while flow_speeds.size() < required_count:
		flow_speeds.append(flow_speeds[flow_speeds.size() - 1])


func _get_flow_speed_for_point(point_index: int) -> float:
	if flow_speeds.is_empty():
		return RIVER_NEUTRAL_FLOW_SPEED_FACTOR
	var flow_speed_index: int = clamp(point_index, 0, flow_speeds.size() - 1)
	return _sanitize_flow_speed_value(flow_speeds[flow_speed_index], "flow_speeds[" + str(flow_speed_index) + "]")


func _any_flow_speed_non_neutral() -> bool:
	for flow_speed_index in flow_speeds.size():
		if not is_equal_approx(_get_flow_speed_for_point(flow_speed_index), RIVER_NEUTRAL_FLOW_SPEED_FACTOR):
			return true
	return false


func _sanitize_width_array(value: Variant) -> Array:
	var sanitized_widths := []
	if typeof(value) != TYPE_ARRAY:
		_warn_sanitized_property("widths", value, "[]")
		return sanitized_widths
	var source_widths: Array = value
	for width_index in source_widths.size():
		sanitized_widths.append(_sanitize_width_value(source_widths[width_index], "widths[" + str(width_index) + "]"))
	return sanitized_widths


func _sanitize_width_value(value: Variant, property_name: String) -> float:
	var width_value := float(value)
	if not _is_finite_number(width_value) or width_value < WaterHelperMethods.MIN_RIVER_WIDTH:
		_warn_sanitized_property(property_name, value, WaterHelperMethods.MIN_RIVER_WIDTH)
		return WaterHelperMethods.MIN_RIVER_WIDTH
	return width_value


func _ensure_width_count_for_curve() -> void:
	var required_width_count := 0
	if curve != null:
		required_width_count = curve.get_point_count()
	if required_width_count <= 0:
		return
	if widths.is_empty():
		_warn_sanitized_property("widths", "empty", "default width values")
		widths.append(1.0)
	while widths.size() < required_width_count:
		_warn_sanitized_property("widths", "too few entries", "padded to curve point count")
		widths.append(widths[widths.size() - 1])


func _get_width_for_point(point_index: int) -> float:
	if widths.is_empty():
		return WaterHelperMethods.MIN_RIVER_WIDTH
	var width_index: int = clamp(point_index, 0, widths.size() - 1)
	return _sanitize_width_value(widths[width_index], "widths[" + str(width_index) + "]")


func _get_average_width() -> float:
	if widths.is_empty():
		return 1.0
	var total_width := 0.0
	for width_index in widths.size():
		total_width += _get_width_for_point(width_index)
	return max(WaterHelperMethods.MIN_RIVER_WIDTH, total_width / float(widths.size()))


func _get_river_bake_texture_size() -> int:
	var safe_resolution := _sanitize_int_range("baking_resolution", baking_resolution, RIVER_BAKE_RESOLUTION_MIN, RIVER_BAKE_RESOLUTION_MAX, DEFAULT_PARAMETERS.baking_resolution)
	if safe_resolution != baking_resolution:
		var was_suppressed := _suppress_property_change_notifications
		_suppress_property_change_notifications = true
		baking_resolution = safe_resolution
		_suppress_property_change_notifications = was_suppressed
	return int(pow(2, 6 + safe_resolution))


func _warn_sanitized_property(property_name: String, original_value: Variant, sanitized_value: Variant) -> void:
	push_warning("Waterways: " + property_name + " had unsafe value " + str(original_value) + "; using " + str(sanitized_value) + " instead.")


func _generate_flowmap(flowmap_resolution : float) -> void:
	var generation_behavior := _sanitize_bake_generation_behavior(bake_generation_behavior)
	var image := Image.create(int(flowmap_resolution), int(flowmap_resolution), true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	var collision_stats := _get_collision_map_stats(image)
	var support_fallback_reason := ""
	var collision_probe_skipped := false
	if _is_curve_only_generation(generation_behavior):
		support_fallback_reason = "curve_only"
		collision_probe_skipped = true
	elif generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE and baking_raycast_layers == 0:
		support_fallback_reason = "baking_raycast_layers_zero"
		collision_probe_skipped = true
	
	if collision_probe_skipped:
		emit_signal("progress_notified", 0.0, "Preparing curve flow (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
		await get_tree().process_frame
	else:
		WaterHelperMethods.reset_all_colliders(get_tree().root)
		emit_signal("progress_notified", 0.0, "Calculating Collisions (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
		await get_tree().process_frame
		image = await WaterHelperMethods.generate_collisionmap(image, mesh_instance, baking_raycast_distance, baking_raycast_layers, _steps, shape_step_length_divs, shape_step_width_divs, self)
		if image == null or image.is_empty():
			_warn_if_collision_map_empty(image, generation_behavior, support_fallback_reason)
			_finish_flowmap_bake_after_failure()
			return
		collision_stats = _get_collision_map_stats(image)
		if _uses_downstream_baseline_generation(generation_behavior) and int(collision_stats.get("hit_pixel_count", 0)) == 0:
			support_fallback_reason = "no_collision_hits"
		_warn_if_collision_map_empty(image, generation_behavior, support_fallback_reason)
	
	emit_signal("progress_notified", 0.95, "Applying filters (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	await get_tree().process_frame
	
	# Calculate how many colums are in UV2
	_uv2_sides = WaterHelperMethods.calculate_side(_steps)
	
	var margin := int(round(float(flowmap_resolution) / float(_uv2_sides)))
	# Content columns plus one margin band each side. Filter passes clamp
	# offset reads to the fragment's column band so atlas-adjacent (but
	# world-distant) tiles cannot bleed into each other.
	var bake_atlas_columns := float(_uv2_sides + 2)
	var downstream_baseline_with_margins_texture: Texture2D = null
	if _uses_downstream_baseline_generation(generation_behavior):
		# River flow RG is local UV flow. Flat collision interiors have no gradient,
		# so the default bake supplies downstream +V and keeps collision data as support.
		var downstream_baseline := WaterHelperMethods.create_downstream_baseline_flow_image(int(flowmap_resolution), _uv2_sides, _steps, RIVER_DOWNSTREAM_BASELINE_STRENGTH)
		var downstream_baseline_with_margins := WaterHelperMethods.add_margins(downstream_baseline, flowmap_resolution, margin, _steps)
		downstream_baseline_with_margins_texture = ImageTexture.create_from_image(downstream_baseline_with_margins)
	var blank_support_with_margins := WaterHelperMethods.add_margins(_create_blank_support_source_image(int(flowmap_resolution)), flowmap_resolution, margin, _steps)
	var blank_support_with_margins_texture := ImageTexture.create_from_image(blank_support_with_margins)
	var blank_obstacle_features_with_margins := WaterHelperMethods.add_margins(_create_blank_obstacle_feature_source_image(int(flowmap_resolution)), flowmap_resolution, margin, _steps)
	var blank_obstacle_features_with_margins_texture := ImageTexture.create_from_image(blank_obstacle_features_with_margins)
	var blank_bank_response_features_with_margins := WaterHelperMethods.add_margins(_create_blank_bank_response_feature_source_image(int(flowmap_resolution)), flowmap_resolution, margin, _steps)
	var blank_bank_response_features_with_margins_texture := ImageTexture.create_from_image(blank_bank_response_features_with_margins)
	var terrain_contact_source := await WaterHelperMethods.generate_terrain_contact_feature_map(
		_create_blank_terrain_contact_feature_source_image(int(flowmap_resolution)),
		mesh_instance,
		baking_raycast_layers,
		_steps,
		shape_step_length_divs,
		shape_step_width_divs,
		self,
		_get_terrain_contact_feature_settings()
	)
	WaterHelperMethods.smooth_uv2_tile_channels(terrain_contact_source, _uv2_sides, _steps, RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES)
	var terrain_contact_with_margins := WaterHelperMethods.add_margins(terrain_contact_source, flowmap_resolution, margin, _steps)
	var terrain_contact_with_margins_texture := ImageTexture.create_from_image(terrain_contact_with_margins)
	var grade_energy_with_margins := WaterHelperMethods.add_margins(_create_curve_grade_energy_source_image(int(flowmap_resolution), _uv2_sides, _steps), flowmap_resolution, margin, _steps)
	var grade_energy_with_margins_texture := ImageTexture.create_from_image(grade_energy_with_margins)
	var bend_bias_with_margins := WaterHelperMethods.add_margins(_create_curve_bend_bias_source_image(int(flowmap_resolution), _uv2_sides, _steps), flowmap_resolution, margin, _steps)
	var bend_bias_with_margins_texture := ImageTexture.create_from_image(bend_bias_with_margins)
	# Authored per-point flow speed: only built when any point deviates from
	# neutral, so default rivers skip the extra scale pass entirely.
	var flow_speed_with_margins_texture: Texture2D = null
	if _any_flow_speed_non_neutral():
		var flow_speed_with_margins := WaterHelperMethods.add_margins(_create_curve_flow_speed_source_image(int(flowmap_resolution), _uv2_sides, _steps), flowmap_resolution, margin, _steps)
		flow_speed_with_margins_texture = ImageTexture.create_from_image(flow_speed_with_margins)

	# Create correctly tiling noise for A channel
	var noise_texture := load(FLOW_OFFSET_NOISE_TEXTURE_PATH) as Texture2D
	var noise_with_margin_size := float(_uv2_sides + 2) * (float(noise_texture.get_width()) / float(_uv2_sides))
	var noise_with_tiling := Image.create(int(noise_with_margin_size), int(noise_with_margin_size), false, Image.FORMAT_RGB8)
	var noise_image := noise_texture.get_image()
	var slice_width := float(noise_texture.get_width()) / float(_uv2_sides)
	for x in _uv2_sides:
		noise_with_tiling.blend_rect(noise_image, Rect2i(0, 0, int(slice_width), noise_texture.get_height()), Vector2i(int(slice_width + float(x) * slice_width), int(slice_width - (noise_texture.get_width() / 2.0))))
		noise_with_tiling.blend_rect(noise_image, Rect2i(0, 0, int(slice_width), noise_texture.get_height()), Vector2i(int(slice_width + float(x) * slice_width), int(slice_width + (noise_texture.get_width() / 2.0))))
	var tiled_noise := ImageTexture.create_from_image(noise_with_tiling)

	# Create renderer
	var renderer_instance = _filter_renderer.instantiate()
	if renderer_instance == null:
		push_warning("Waterways: River Flow & Foam bake failed because the filter renderer could not be instantiated.")
		_finish_flowmap_bake_after_failure()
		return

	self.add_child(renderer_instance)

	var flow_pressure_blur_amount = 0.04 / float(_uv2_sides) * flowmap_resolution
	var dilate_amount = baking_dilate / float(_uv2_sides) 
	var flowmap_blur_amount = baking_flowmap_blur / float(_uv2_sides) * flowmap_resolution
	var foam_offset_amount = baking_foam_offset / float(_uv2_sides)
	var foam_blur_amount = baking_foam_blur / float(_uv2_sides) * flowmap_resolution
	
	var support_fallback_applied := not support_fallback_reason.is_empty()
	var run_collision_support_filters := not support_fallback_applied
	var obstacle_avoidance_applied := false
	var flow_projected_applied := false
	var primary_flow_map: Texture2D = null
	var blurred_foam_map: Texture2D = blank_support_with_margins_texture
	var blurred_flow_pressure_map: Texture2D = blank_support_with_margins_texture
	var dilated_texture: Texture2D = blank_support_with_margins_texture
	var obstacle_feature_mask: Texture2D = blank_obstacle_features_with_margins_texture
	var bank_response_feature_mask: Texture2D = blank_bank_response_features_with_margins_texture
	var water_occupancy_mask: Texture2D = null
	var bank_response_feature_mask_ready := false
	if downstream_baseline_with_margins_texture != null:
		var early_bank_response_feature_settings := _get_bank_response_feature_settings()
		var early_bank_response_uv_denominator := float(_uv2_sides) + 2.0
		var early_bank_response_feature_mask_result = await renderer_instance.apply_bank_response_feature_mask(
			downstream_baseline_with_margins_texture,
			terrain_contact_with_margins_texture,
			grade_energy_with_margins_texture,
			bend_bias_with_margins_texture,
			float(early_bank_response_feature_settings.get("probe_tiles", RIVER_BANK_RESPONSE_PROBE_TILES)) / early_bank_response_uv_denominator,
			RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
			RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
			RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
			RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
			RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
			RIVER_BANK_RESPONSE_INSIDE_BEND_START,
			RIVER_BANK_RESPONSE_INSIDE_BEND_FULL,
			bake_atlas_columns
		)
		if not _filter_output_is_valid(early_bank_response_feature_mask_result, "bank response feature mask", renderer_instance):
			return
		bank_response_feature_mask = early_bank_response_feature_mask_result
		bank_response_feature_mask_ready = true
	if run_collision_support_filters:
		var collision_with_margins_image := WaterHelperMethods.add_margins(image, flowmap_resolution, margin, _steps)
		var collision_with_margins := ImageTexture.create_from_image(collision_with_margins_image)
		var flow_pressure_map = await renderer_instance.apply_flow_pressure(collision_with_margins, flowmap_resolution, _uv2_sides + 2.0)
		if not _filter_output_is_valid(flow_pressure_map, "flow pressure", renderer_instance):
			return
		blurred_flow_pressure_map = await renderer_instance.apply_vertical_blur(flow_pressure_map, flow_pressure_blur_amount, flowmap_resolution)
		if not _filter_output_is_valid(blurred_flow_pressure_map, "blurred flow pressure", renderer_instance):
			return
		dilated_texture = await renderer_instance.apply_dilate(collision_with_margins, dilate_amount, 0.0, flowmap_resolution, null, bake_atlas_columns)
		if not _filter_output_is_valid(dilated_texture, "dilated collision map", renderer_instance):
			return
		var normal_map = await renderer_instance.apply_normal(dilated_texture, flowmap_resolution, bake_atlas_columns)
		if not _filter_output_is_valid(normal_map, "normal map", renderer_instance):
			return
		# Crisp water occupancy: collision interiors plus protruding terrain,
		# packed with a proximity ramp for runtime clipping and flow stilling.
		var solid_occupancy_source := WaterHelperMethods.create_solid_occupancy_source_image(image, terrain_contact_source, RIVER_OCCUPANCY_PROTRUSION_THRESHOLD, RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN)
		var solid_occupancy_with_margins := WaterHelperMethods.add_margins(solid_occupancy_source, flowmap_resolution, margin, _steps)
		var solid_occupancy_with_margins_texture := ImageTexture.create_from_image(solid_occupancy_with_margins)
		var occupancy_proximity = await renderer_instance.apply_proximity(solid_occupancy_with_margins_texture, RIVER_OCCUPANCY_RAMP_TILES / float(_uv2_sides), flowmap_resolution, bake_atlas_columns)
		if not _filter_output_is_valid(occupancy_proximity, "occupancy proximity field", renderer_instance):
			return
		var water_occupancy_result = await renderer_instance.apply_occupancy_pack(solid_occupancy_with_margins_texture, occupancy_proximity)
		if not _filter_output_is_valid(water_occupancy_result, "water occupancy mask", renderer_instance):
			return
		water_occupancy_mask = water_occupancy_result
		if _uses_obstacle_avoidance_generation(generation_behavior) and downstream_baseline_with_margins_texture != null:
			var feature_uv_denominator := float(_uv2_sides) + 2.0
			var obstacle_feature_mask_result = await renderer_instance.apply_obstacle_feature_mask(
				downstream_baseline_with_margins_texture,
				normal_map,
				dilated_texture,
				bank_response_feature_mask,
				RIVER_OBSTACLE_FEATURE_SUPPORT_START,
				RIVER_OBSTACLE_FEATURE_SUPPORT_FULL,
				RIVER_OBSTACLE_FEATURE_FACING_START,
				RIVER_OBSTACLE_FEATURE_FACING_FULL,
				RIVER_OBSTACLE_FEATURE_WAKE_LENGTH_TILES / feature_uv_denominator,
				RIVER_OBSTACLE_FEATURE_WAKE_WIDTH_TILES / feature_uv_denominator,
				RIVER_OBSTACLE_FEATURE_SIDE_WIDTH_TILES / feature_uv_denominator,
				RIVER_OBSTACLE_FEATURE_WAKE_START,
				RIVER_OBSTACLE_FEATURE_WAKE_FULL,
				RIVER_OBSTACLE_FEATURE_BANK_FRICTION_SUPPRESSION,
				RIVER_OBSTACLE_FEATURE_HARD_BOUNDARY_WAKE_GATE,
				RIVER_OBSTACLE_FEATURE_CONFIDENCE_START,
				RIVER_OBSTACLE_FEATURE_CONFIDENCE_FULL,
				terrain_contact_with_margins_texture,
				grade_energy_with_margins_texture,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_START,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_FULL,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_START,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_FULL,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_START,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_FULL,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_START,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_FULL,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_START,
				RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_FULL,
				RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START,
				RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL,
				RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES / feature_uv_denominator,
				RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START,
				RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL,
				bake_atlas_columns
			)
			if not _filter_output_is_valid(obstacle_feature_mask_result, "obstacle feature mask", renderer_instance):
				return
			obstacle_feature_mask = obstacle_feature_mask_result
			# Pressure projection (Helmholtz-Hodge): make the baseline field
			# divergence-free with free-slip solid boundaries. Guarantees flow
			# does not cross obstacle/bank boundaries, splits around solids,
			# stagnates in front, and speeds up through constrictions.
			# Replaces the legacy local SDF tangent steering.
			renderer_instance.set_hdr_2d(true)
			var divergence_map = await renderer_instance.apply_flow_divergence(downstream_baseline_with_margins_texture, water_occupancy_mask, flowmap_resolution, bake_atlas_columns)
			if not _filter_output_is_valid(divergence_map, "flow divergence map", renderer_instance):
				return
			var pressure_size := Vector2i(downstream_baseline_with_margins_texture.get_size())
			var neutral_pressure_image := Image.create(pressure_size.x, pressure_size.y, false, Image.FORMAT_RGBAF)
			neutral_pressure_image.fill(Color(0.5, 0.0, 0.0, 1.0))
			var pressure_map: Texture2D = ImageTexture.create_from_image(neutral_pressure_image)
			var total_jacobi_passes := RIVER_FLOW_PROJECTION_STRIDES.size() * RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE
			var jacobi_pass_index := 0
			for stride in RIVER_FLOW_PROJECTION_STRIDES:
				emit_signal("progress_notified", 0.95, "Projecting flow %d/%d (stride %d)" % [jacobi_pass_index, total_jacobi_passes, stride])
				for iteration in RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE:
					pressure_map = await renderer_instance.apply_flow_pressure_jacobi(pressure_map, divergence_map, water_occupancy_mask, float(stride), flowmap_resolution, bake_atlas_columns)
					if not _filter_output_is_valid(pressure_map, "flow pressure jacobi pass", renderer_instance):
						return
					jacobi_pass_index += 1
			var projected_flow_map = await renderer_instance.apply_flow_gradient_subtract(downstream_baseline_with_margins_texture, pressure_map, water_occupancy_mask, flowmap_resolution, bake_atlas_columns)
			if not _filter_output_is_valid(projected_flow_map, "projected flow map", renderer_instance):
				return
			var tangent_flow_map: Texture2D = projected_flow_map
			for tangency_pass in RIVER_FLOW_TANGENCY_PASSES:
				tangent_flow_map = await renderer_instance.apply_flow_boundary_tangency(tangent_flow_map, water_occupancy_mask, flowmap_resolution, bake_atlas_columns)
				if not _filter_output_is_valid(tangent_flow_map, "boundary tangency flow map", renderer_instance):
					return
			renderer_instance.set_hdr_2d(false)
			# No post-blur: the projected field is smooth by construction and
			# blurring would smear velocity back across solid boundaries.
			primary_flow_map = tangent_flow_map
			obstacle_avoidance_applied = true
			flow_projected_applied = true
		else:
			var flow_map = await renderer_instance.apply_normal_to_flow(normal_map, flowmap_resolution)
			if not _filter_output_is_valid(flow_map, "flow map", renderer_instance):
				return
			var blurred_flow_map = await renderer_instance.apply_blur(flow_map, flowmap_blur_amount, flowmap_resolution, bake_atlas_columns)
			if not _filter_output_is_valid(blurred_flow_map, "blurred flow map", renderer_instance):
				return
			primary_flow_map = blurred_flow_map
		var foam_map = await renderer_instance.apply_foam(dilated_texture, foam_offset_amount, baking_foam_cutoff, flowmap_resolution)
		if not _filter_output_is_valid(foam_map, "foam map", renderer_instance):
			return
		blurred_foam_map = await renderer_instance.apply_blur(foam_map, foam_blur_amount, flowmap_resolution, bake_atlas_columns)
		if not _filter_output_is_valid(blurred_foam_map, "blurred foam map", renderer_instance):
			return
	if downstream_baseline_with_margins_texture != null and primary_flow_map == null:
		primary_flow_map = downstream_baseline_with_margins_texture
	if primary_flow_map == null:
		push_warning("Waterways: River Flow & Foam bake failed because no primary flow map was available for behavior " + generation_behavior + ".")
		_cleanup_bake_renderer(renderer_instance)
		_finish_flowmap_bake_after_failure()
		return
	if support_fallback_applied:
		_print_curve_support_fallback_notice(generation_behavior, support_fallback_reason)
	if flow_speed_with_margins_texture != null:
		var speed_scaled_flow_map = await renderer_instance.apply_flow_speed_scale(primary_flow_map, flow_speed_with_margins_texture, RIVER_FLOW_SPEED_FACTOR_MAX)
		if not _filter_output_is_valid(speed_scaled_flow_map, "flow speed scale map", renderer_instance):
			return
		primary_flow_map = speed_scaled_flow_map
	var bank_response_source_flow := downstream_baseline_with_margins_texture
	if bank_response_source_flow == null:
		bank_response_source_flow = primary_flow_map
	if not bank_response_feature_mask_ready and bank_response_source_flow != null:
		var bank_response_feature_settings := _get_bank_response_feature_settings()
		var bank_response_uv_denominator := float(_uv2_sides) + 2.0
		var bank_response_feature_mask_result = await renderer_instance.apply_bank_response_feature_mask(
			bank_response_source_flow,
			terrain_contact_with_margins_texture,
			grade_energy_with_margins_texture,
			bend_bias_with_margins_texture,
			float(bank_response_feature_settings.get("probe_tiles", RIVER_BANK_RESPONSE_PROBE_TILES)) / bank_response_uv_denominator,
			RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
			RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
			RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
			RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
			RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
			RIVER_BANK_RESPONSE_INSIDE_BEND_START,
			RIVER_BANK_RESPONSE_INSIDE_BEND_FULL,
			bake_atlas_columns
		)
		if not _filter_output_is_valid(bank_response_feature_mask_result, "bank response feature mask", renderer_instance):
			return
		bank_response_feature_mask = bank_response_feature_mask_result
	var flow_foam_noise_img = await renderer_instance.apply_combine(primary_flow_map, primary_flow_map, blurred_foam_map, tiled_noise)
	if not _filter_output_is_valid(flow_foam_noise_img, "combined flow/foam/noise map", renderer_instance):
		return
	var dist_pressure_img = await renderer_instance.apply_combine(dilated_texture, blurred_flow_pressure_map, grade_energy_with_margins_texture, bend_bias_with_margins_texture)
	if not _filter_output_is_valid(dist_pressure_img, "combined distance/pressure map", renderer_instance):
		return
	
	_cleanup_bake_renderer(renderer_instance)
	
	var flow_foam_noise_result: Image = flow_foam_noise_img.get_image()
	var dist_pressure_result: Image = dist_pressure_img.get_image()
	var obstacle_features_result: Image = obstacle_feature_mask.get_image()
	var terrain_contact_features_result: Image = terrain_contact_with_margins
	var bank_response_features_result: Image = bank_response_feature_mask.get_image()
	var water_occupancy_result_image: Image = null
	if water_occupancy_mask != null:
		water_occupancy_result_image = water_occupancy_mask.get_image()
	var crop_rect := Rect2i(margin, margin, int(flowmap_resolution), int(flowmap_resolution))
	# Filters and combine passes can leave meaningful-looking RG in unused atlas cells.
	# Clear only the source-region unused tiles so occupied seam margins stay intact.
	WaterHelperMethods.neutralize_unused_uv2_atlas_flow_rg(flow_foam_noise_result, _uv2_sides, _steps, crop_rect)
	var foam_support_reduced := false
	var pressure_support_reduced := false
	if _uses_downstream_baseline_generation(generation_behavior) and not support_fallback_applied:
		foam_support_reduced = _reduce_flat_occupied_foam_support(flow_foam_noise_result, crop_rect)
		pressure_support_reduced = _reduce_flat_occupied_pressure_support(dist_pressure_result, crop_rect)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(flow_foam_noise_result, _uv2_sides, _steps, crop_rect, RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(dist_pressure_result, _uv2_sides, _steps, crop_rect, RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(obstacle_features_result, _uv2_sides, _steps, crop_rect, RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS)
	WaterHelperMethods.synchronize_uv2_logical_edge_bands(bank_response_features_result, _uv2_sides, _steps, crop_rect, RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS)
	if water_occupancy_result_image != null:
		WaterHelperMethods.synchronize_uv2_logical_edge_bands(water_occupancy_result_image, _uv2_sides, _steps, crop_rect, RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS)
	var grade_energy_stats := _get_occupied_channel_stats(dist_pressure_result, crop_rect, 2)
	var bend_bias_stats := _get_occupied_channel_stats(dist_pressure_result, crop_rect, 3)
	var obstacle_feature_stats := _get_obstacle_feature_stats(obstacle_features_result, crop_rect)
	var terrain_contact_feature_stats := _get_terrain_contact_feature_stats(terrain_contact_features_result, crop_rect)
	var bank_response_feature_stats := _get_bank_response_feature_stats(bank_response_features_result, crop_rect)
	var source_texture_size := Vector2i(int(flowmap_resolution), int(flowmap_resolution))
	var padded_texture_size := Vector2i(flow_foam_noise_result.get_width(), flow_foam_noise_result.get_height())
	var sampled_flow_foam_noise_result: Image = flow_foam_noise_result.get_region(crop_rect)
	var sampled_dist_pressure_result: Image = dist_pressure_result.get_region(crop_rect)
	if not support_fallback_applied:
		_warn_if_bake_channels_flat(sampled_flow_foam_noise_result, "foam map B", [2], PackedStringArray(["B"]))
		_warn_if_bake_channels_flat(sampled_dist_pressure_result, "distance/pressure RG", [0, 1], PackedStringArray(["R", "G"]))
	var flow_vector_diagnostics := WaterHelperMethods.get_uv2_atlas_decoded_flow_vector_stats(
		flow_foam_noise_result,
		_uv2_sides,
		_steps,
		crop_rect,
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD
	)
	_print_river_flow_vector_diagnostics(flow_vector_diagnostics)
	_warn_if_bake_flow_vectors_near_neutral(flow_vector_diagnostics)
	
	# River shaders remap UV2 into the center of the margin-padded bake atlas.
	# Keep the shader-facing textures padded to match the original Waterways layout.
	flow_foam_noise = ImageTexture.create_from_image(flow_foam_noise_result)
	dist_pressure = ImageTexture.create_from_image(dist_pressure_result)
	obstacle_features = ImageTexture.create_from_image(obstacle_features_result)
	terrain_contact_features = ImageTexture.create_from_image(terrain_contact_features_result)
	bank_response_features = ImageTexture.create_from_image(bank_response_features_result)
	water_occupancy = ImageTexture.create_from_image(water_occupancy_result_image) if water_occupancy_result_image != null else null
	var bake_diagnostics := {
		"collision_probe_skipped": collision_probe_skipped,
		"collision_support_filters_ran": run_collision_support_filters,
		"support_fallback_applied": support_fallback_applied,
		"support_fallback_reason": support_fallback_reason,
		"obstacle_avoidance_applied": obstacle_avoidance_applied,
		"flow_projected": flow_projected_applied,
		"water_occupancy_baked": water_occupancy != null,
		"collision_stats": collision_stats.duplicate(true),
		"grade_energy_stats": grade_energy_stats.duplicate(true),
		"bend_bias_stats": bend_bias_stats.duplicate(true),
		"obstacle_feature_stats": obstacle_feature_stats.duplicate(true),
		"terrain_contact_feature_stats": terrain_contact_feature_stats.duplicate(true),
		"bank_response_feature_stats": bank_response_feature_stats.duplicate(true)
	}
	_write_bake_data(padded_texture_size, source_texture_size, crop_rect, flow_vector_diagnostics, generation_behavior, foam_support_reduced, pressure_support_reduced, bake_diagnostics)
	var storage_result := WaterHelperMethods.save_river_bake_data(self, bake_data)
	_apply_bake_data()
	
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_obstacle_features", obstacle_features)
	set_materials("i_terrain_contact_features", terrain_contact_features)
	set_materials("i_bank_response_features", bank_response_features)
	set_materials("i_water_occupancy", water_occupancy)
	set_materials("i_flow_projected", flow_projected_applied)
	set_materials("i_valid_flowmap", true)
	set_materials("i_uv2_sides", _uv2_sides)
	valid_flowmap = true;
	_clear_flowmap_bake_request()
	emit_signal("progress_notified", 100.0, "finished")
	_print_bake_save_notice(padded_texture_size, storage_result)
	update_configuration_warnings()


func _filter_output_is_valid(texture: Texture2D, label: String, renderer_instance: Node) -> bool:
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		return true
	push_warning("Waterways: River Flow & Foam bake failed while generating " + label + ". The bake was aborted and temporary renderer nodes were cleaned up.")
	_cleanup_bake_renderer(renderer_instance)
	_finish_flowmap_bake_after_failure()
	return false


func _cleanup_bake_renderer(renderer_instance: Node) -> void:
	if renderer_instance == null:
		return
	if renderer_instance.get_parent() != null:
		renderer_instance.get_parent().remove_child(renderer_instance)
	renderer_instance.queue_free()


func _finish_flowmap_bake_after_failure() -> void:
	_clear_flowmap_bake_request()
	emit_signal("progress_notified", 100.0, "finished")
	update_configuration_warnings()


func _create_blank_support_source_image(resolution: int) -> Image:
	return _create_uniform_support_source_image(resolution, RIVER_BLANK_SUPPORT_VALUE)


func _create_blank_obstacle_feature_source_image(resolution: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _create_blank_terrain_contact_feature_source_image(resolution: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _create_blank_bank_response_feature_source_image(resolution: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _get_terrain_contact_feature_settings() -> Dictionary:
	return {
		"contact_full_band": RIVER_TERRAIN_CONTACT_FULL_BAND,
		"contact_fade_distance": RIVER_TERRAIN_CONTACT_FADE_DISTANCE,
		"shallow_full_depth": RIVER_TERRAIN_SHALLOW_FULL_DEPTH,
		"shallow_fade_depth": RIVER_TERRAIN_SHALLOW_FADE_DEPTH,
		"protrusion_fade_height": RIVER_TERRAIN_PROTRUSION_FADE_HEIGHT,
		"protrusion_full_height": RIVER_TERRAIN_PROTRUSION_FULL_HEIGHT,
		"raycast_up_offset": RIVER_TERRAIN_CONTACT_RAYCAST_UP_OFFSET,
		"raycast_down_distance": RIVER_TERRAIN_CONTACT_RAYCAST_DOWN_DISTANCE,
		"hterrain_source_confidence": RIVER_TERRAIN_HTERRAIN_SOURCE_CONFIDENCE,
		"physics_source_confidence": RIVER_TERRAIN_PHYSICS_SOURCE_CONFIDENCE,
		"contact_supersamples": RIVER_TERRAIN_CONTACT_SUPERSAMPLES,
		"source_blend_band": RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND
	}


func _get_bank_response_feature_settings() -> Dictionary:
	return {
		"probe_tiles": RIVER_BANK_RESPONSE_PROBE_TILES,
		"friction_contact_weight": RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
		"friction_shallow_weight": RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
		"hard_protrusion_weight": RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
		"outside_bend_start": RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
		"outside_bend_full": RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
		"inside_bend_start": RIVER_BANK_RESPONSE_INSIDE_BEND_START,
		"inside_bend_full": RIVER_BANK_RESPONSE_INSIDE_BEND_FULL
	}


func _create_uniform_support_source_image(resolution: int, value: float) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var clamped_value := clampf(value, 0.0, 1.0)
	image.fill(Color(clamped_value, clamped_value, clamped_value, 1.0))
	return image


func _create_curve_grade_energy_source_image(resolution: int, uv2_sides: int, occupied_steps: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	image.fill(Color(RIVER_NEUTRAL_GRADE_ENERGY_VALUE, RIVER_NEUTRAL_GRADE_ENERGY_VALUE, RIVER_NEUTRAL_GRADE_ENERGY_VALUE, 1.0))
	var side := maxi(1, uv2_sides)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	if safe_occupied_steps <= 0:
		return image
	var grade_energy_by_step := _calculate_curve_grade_energy_by_step(safe_occupied_steps)
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			var local_y := _tile_axis_vertex_aligned_ratio(y, tile_rect.size.y)
			var step_progress := float(step_index) + local_y
			var grade_energy := clampf(_sample_step_value_linear(grade_energy_by_step, step_progress, RIVER_NEUTRAL_GRADE_ENERGY_VALUE), 0.0, 1.0)
			var color := Color(grade_energy, grade_energy, grade_energy, 1.0)
			for x in tile_rect.size.x:
				image.set_pixel(tile_rect.position.x + x, tile_rect.position.y + y, color)
	return image


func _calculate_curve_grade_energy_by_step(step_count: int) -> Array:
	var safe_step_count := maxi(1, step_count)
	var raw_grades := []
	raw_grades.resize(safe_step_count)
	for step_index in safe_step_count:
		raw_grades[step_index] = 0.0
	if curve == null or curve.get_point_count() <= 0:
		return raw_grades
	var curve_length := curve.get_baked_length()
	if curve_length <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return raw_grades
	var lookahead_tiles := maxf(RIVER_GRADE_ENERGY_LOOKAHEAD_TILES, 0.1)
	for step_index in safe_step_count:
		var sample_step := float(step_index)
		var downstream_step := minf(float(safe_step_count), sample_step + lookahead_tiles)
		var sample_distance := (sample_step / float(safe_step_count)) * curve_length
		var downstream_distance := (downstream_step / float(safe_step_count)) * curve_length
		var sample_position := _sample_curve_baked_distance(sample_distance, curve_length)
		var downstream_position := _sample_curve_baked_distance(downstream_distance, curve_length)
		var run_distance := maxf(downstream_distance - sample_distance, WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
		var downhill_drop := sample_position.y - downstream_position.y
		raw_grades[step_index] = maxf(0.0, downhill_drop / run_distance)
	return _normalize_curve_grade_values(_smooth_curve_grade_values(raw_grades, RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES))


# Per-point flow speed factor sampled along the curve, packed into R as
# factor / RIVER_FLOW_SPEED_FACTOR_MAX (0.5 = neutral factor 1.0).
func _create_curve_flow_speed_source_image(resolution: int, uv2_sides: int, occupied_steps: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	var neutral_packed := RIVER_NEUTRAL_FLOW_SPEED_FACTOR / RIVER_FLOW_SPEED_FACTOR_MAX
	image.fill(Color(neutral_packed, neutral_packed, neutral_packed, 1.0))
	var side := maxi(1, uv2_sides)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	if safe_occupied_steps <= 0:
		return image
	var flow_speed_by_step := _calculate_curve_flow_speed_by_step(safe_occupied_steps)
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			var local_y := _tile_axis_vertex_aligned_ratio(y, tile_rect.size.y)
			var step_progress := float(step_index) + local_y
			var flow_speed := clampf(_sample_step_value_linear(flow_speed_by_step, step_progress, RIVER_NEUTRAL_FLOW_SPEED_FACTOR), RIVER_FLOW_SPEED_FACTOR_MIN, RIVER_FLOW_SPEED_FACTOR_MAX)
			var packed := flow_speed / RIVER_FLOW_SPEED_FACTOR_MAX
			var color := Color(packed, packed, packed, 1.0)
			for x in tile_rect.size.x:
				image.set_pixel(tile_rect.position.x + x, tile_rect.position.y + y, color)
	return image


func _calculate_curve_flow_speed_by_step(step_count: int) -> Array:
	var safe_step_count := maxi(1, step_count)
	var factors := []
	factors.resize(safe_step_count + 1)
	for step_index in safe_step_count + 1:
		factors[step_index] = RIVER_NEUTRAL_FLOW_SPEED_FACTOR
	if curve == null or curve.get_point_count() < 2 or flow_speeds.is_empty():
		return factors
	var curve_length := curve.get_baked_length()
	if curve_length <= 0.0:
		return factors
	var point_offsets := _get_curve_point_offsets()
	for step_index in safe_step_count + 1:
		var distance := (float(step_index) / float(safe_step_count)) * curve_length
		factors[step_index] = _sample_flow_speed_at_offset(distance, point_offsets)
	return factors


func _get_curve_point_offsets() -> PackedFloat32Array:
	var offsets := PackedFloat32Array()
	var running := 0.0
	for point_index in curve.get_point_count():
		var offset := curve.get_closest_offset(curve.get_point_position(point_index))
		# Offsets must be monotonic; a near-self-intersecting curve can fool
		# get_closest_offset, so never step backwards.
		running = maxf(running, offset)
		offsets.append(running)
	return offsets


func _sample_flow_speed_at_offset(distance: float, point_offsets: PackedFloat32Array) -> float:
	if point_offsets.size() < 2:
		return _get_flow_speed_for_point(0)
	for segment_index in point_offsets.size() - 1:
		var segment_start := point_offsets[segment_index]
		var segment_end := point_offsets[segment_index + 1]
		if distance <= segment_end or segment_index == point_offsets.size() - 2:
			var t := 0.0
			if segment_end > segment_start:
				t = clampf((distance - segment_start) / (segment_end - segment_start), 0.0, 1.0)
			# Smoothstep easing matches the width interpolation convention.
			return lerpf(_get_flow_speed_for_point(segment_index), _get_flow_speed_for_point(segment_index + 1), smoothstep(0.0, 1.0, t))
	return _get_flow_speed_for_point(point_offsets.size() - 1)


func _create_curve_bend_bias_source_image(resolution: int, uv2_sides: int, occupied_steps: int) -> Image:
	var safe_resolution := maxi(1, resolution)
	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RGBA8)
	image.fill(Color(RIVER_NEUTRAL_BEND_BIAS_VALUE, RIVER_NEUTRAL_BEND_BIAS_VALUE, RIVER_NEUTRAL_BEND_BIAS_VALUE, 1.0))
	var side := maxi(1, uv2_sides)
	var total_tiles := side * side
	var safe_occupied_steps := clampi(occupied_steps, 0, total_tiles)
	if safe_occupied_steps <= 0:
		return image
	var bend_bias_by_step := _calculate_curve_bend_bias_by_step(safe_occupied_steps)
	var source_rect := Rect2i(0, 0, safe_resolution, safe_resolution)
	for step_index in safe_occupied_steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, side, source_rect)
		for y in tile_rect.size.y:
			var local_y := _tile_axis_vertex_aligned_ratio(y, tile_rect.size.y)
			var step_progress := float(step_index) + local_y
			var signed_outside_side := clampf(_sample_step_value_linear(bend_bias_by_step, step_progress, 0.0), -1.0, 1.0)
			for x in tile_rect.size.x:
				var local_x := _tile_axis_vertex_aligned_ratio(x, tile_rect.size.x)
				var side_from_river_right := 1.0 - 2.0 * local_x
				var signed_bend_bias := clampf(signed_outside_side * side_from_river_right, -1.0, 1.0)
				var packed_bend_bias := signed_bend_bias * 0.5 + 0.5
				var color := Color(packed_bend_bias, packed_bend_bias, packed_bend_bias, 1.0)
				image.set_pixel(tile_rect.position.x + x, tile_rect.position.y + y, color)
	return image


func _tile_axis_vertex_aligned_ratio(pixel_index: int, axis_size: int) -> float:
	if axis_size <= 1:
		return 0.5
	return clampf(float(pixel_index) / float(axis_size - 1), 0.0, 1.0)


func _sample_step_value_linear(values: Array, step_progress: float, fallback: float) -> float:
	if values.is_empty():
		return fallback
	if values.size() == 1:
		return float(values[0])
	if step_progress <= 0.0:
		return float(values[0])
	var last_index := values.size() - 1
	if step_progress >= float(last_index):
		return float(values[last_index])
	var left_index := clampi(int(floor(step_progress)), 0, last_index - 1)
	var right_index := left_index + 1
	var t := clampf(step_progress - float(left_index), 0.0, 1.0)
	return lerpf(float(values[left_index]), float(values[right_index]), t)


func _calculate_curve_bend_bias_by_step(step_count: int) -> Array:
	var safe_step_count := maxi(1, step_count)
	var raw_bends := []
	raw_bends.resize(safe_step_count)
	for step_index in safe_step_count:
		raw_bends[step_index] = 0.0
	if curve == null or curve.get_point_count() <= 0:
		return raw_bends
	var curve_length := curve.get_baked_length()
	if curve_length <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return raw_bends
	var lookahead_tiles := maxf(RIVER_BEND_BIAS_LOOKAHEAD_TILES, 0.1)
	var reference_angle := maxf(RIVER_BEND_BIAS_REFERENCE_RADIANS, WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
	for step_index in safe_step_count:
		var sample_step := float(step_index) + 0.5
		var upstream_step := maxf(0.0, sample_step - lookahead_tiles)
		var downstream_step := minf(float(safe_step_count), sample_step + lookahead_tiles)
		if downstream_step - upstream_step <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
			continue
		var sample_distance := (sample_step / float(safe_step_count)) * curve_length
		var upstream_distance := (upstream_step / float(safe_step_count)) * curve_length
		var downstream_distance := (downstream_step / float(safe_step_count)) * curve_length
		var sample_position := _sample_curve_baked_distance(sample_distance, curve_length)
		var upstream_position := _sample_curve_baked_distance(upstream_distance, curve_length)
		var downstream_position := _sample_curve_baked_distance(downstream_distance, curve_length)
		var upstream_direction := _planar_direction_xz(sample_position - upstream_position)
		var downstream_direction := _planar_direction_xz(downstream_position - sample_position)
		if upstream_direction == Vector2.ZERO or downstream_direction == Vector2.ZERO:
			continue
		var center_direction := upstream_direction + downstream_direction
		if center_direction.length_squared() <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
			center_direction = downstream_direction
		else:
			center_direction = center_direction.normalized()
		var river_right := Vector2(-center_direction.y, center_direction.x)
		var curvature_direction := downstream_direction - upstream_direction
		var curvature_dot_right := curvature_direction.dot(river_right)
		if absf(curvature_dot_right) <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
			continue
		var turn_cross := upstream_direction.x * downstream_direction.y - upstream_direction.y * downstream_direction.x
		var turn_dot := clampf(upstream_direction.dot(downstream_direction), -1.0, 1.0)
		var turn_angle := atan2(absf(turn_cross), turn_dot)
		var bend_strength := clampf(turn_angle / reference_angle, 0.0, 1.0)
		var outside_side := -1.0 if curvature_dot_right > 0.0 else 1.0
		raw_bends[step_index] = outside_side * bend_strength
	return _smooth_curve_bend_bias_values(raw_bends, RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES)


func _planar_direction_xz(value: Vector3) -> Vector2:
	var planar := Vector2(value.x, value.z)
	if planar.length_squared() <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return Vector2.ZERO
	return planar.normalized()


func _sample_curve_baked_distance(distance: float, curve_length: float) -> Vector3:
	if curve == null or curve.get_point_count() <= 0:
		return Vector3.ZERO
	if curve_length <= WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED:
		return curve.get_point_position(0)
	return curve.sample_baked(clampf(distance, 0.0, curve_length), false)


func _smooth_curve_grade_values(values: Array, radius: int) -> Array:
	var smoothed := []
	smoothed.resize(values.size())
	if values.is_empty():
		return smoothed
	var safe_radius := maxi(0, radius)
	for value_index in values.size():
		var start_index := maxi(0, value_index - safe_radius)
		var end_index := mini(values.size() - 1, value_index + safe_radius)
		var sum := 0.0
		var count := 0
		for sample_index in range(start_index, end_index + 1):
			sum += float(values[sample_index])
			count += 1
		smoothed[value_index] = sum / float(maxi(1, count))
	return smoothed


func _smooth_curve_bend_bias_values(values: Array, radius: int) -> Array:
	var smoothed := []
	smoothed.resize(values.size())
	if values.is_empty():
		return smoothed
	var safe_radius := maxi(0, radius)
	for value_index in values.size():
		var start_index := maxi(0, value_index - safe_radius)
		var end_index := mini(values.size() - 1, value_index + safe_radius)
		var sum := 0.0
		var count := 0
		for sample_index in range(start_index, end_index + 1):
			sum += float(values[sample_index])
			count += 1
		smoothed[value_index] = clampf(sum / float(maxi(1, count)), -1.0, 1.0)
	return smoothed


func _normalize_curve_grade_values(grades: Array) -> Array:
	var energy_values := []
	energy_values.resize(grades.size())
	var reference_grade := maxf(RIVER_GRADE_ENERGY_REFERENCE_GRADE, WaterHelperMethods.MIN_DIRECTION_LENGTH_SQUARED)
	for grade_index in grades.size():
		energy_values[grade_index] = clampf(float(grades[grade_index]) / reference_grade, 0.0, 1.0)
	return energy_values


func _get_collision_map_stats(image: Image) -> Dictionary:
	var total_pixels := 0
	var hit_pixels := 0
	if image != null and not image.is_empty():
		total_pixels = image.get_width() * image.get_height()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).r > 0.5:
					hit_pixels += 1
	var hit_percent := 0.0
	if total_pixels > 0:
		hit_percent = 100.0 * float(hit_pixels) / float(total_pixels)
	return {
		"hit_pixel_count": hit_pixels,
		"total_pixel_count": total_pixels,
		"hit_pixel_percent": hit_percent
	}


func _warn_if_collision_map_empty(image: Image, generation_behavior: String, support_fallback_reason: String = "") -> void:
	if image == null or image.is_empty():
		push_warning("Waterways: River collision bake produced no readable collision image.")
		return
	var stats := _get_collision_map_stats(image)
	var hit_pixels := int(stats.get("hit_pixel_count", 0))
	var total_pixels := int(stats.get("total_pixel_count", 0))
	if hit_pixels == 0:
		if _uses_downstream_baseline_generation(generation_behavior) and not support_fallback_reason.is_empty():
			push_warning("Waterways: River collision bake found no collider pixels; generated curve downstream flow will use exact blank collision support maps for reduced foam, pressure, and bank detail.")
		else:
			push_warning("Waterways: River collision bake found no collider pixels. Check baking raycast layers, collider placement, and raycast distance.")
	elif hit_pixels == total_pixels:
		push_warning("Waterways: River collision bake hit every pixel, so generated flow/foam maps may be flat. Use non-uniform bake geometry for visual validation.")


func _print_curve_support_fallback_notice(generation_behavior: String, support_fallback_reason: String) -> void:
	var detail := "collision support was skipped"
	match support_fallback_reason:
		"curve_only":
			detail = "Curve Only behavior skips collision probing"
		"baking_raycast_layers_zero":
			detail = "baking_raycast_layers is 0"
		"no_collision_hits":
			detail = "no collider pixels were hit"
	print(
		"Waterways: River Flow & Foam bake used curve downstream flow with blank support maps (",
		detail,
		") for behavior ",
		generation_behavior,
		"."
	)


func _warn_if_bake_channels_flat(image: Image, label: String, channel_indices: Array, channel_names: PackedStringArray) -> void:
	if image == null or image.is_empty() or channel_indices.is_empty():
		push_warning("Waterways: River bake produced no readable " + label + " image.")
		return
	var min_values := []
	var max_values := []
	var avg_values := []
	for channel_index in channel_indices.size():
		min_values.append(INF)
		max_values.append(-INF)
		avg_values.append(0.0)
	var total_pixels := max(1, image.get_width() * image.get_height())
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			for channel_index in channel_indices.size():
				var value := _get_color_channel(pixel, int(channel_indices[channel_index]))
				min_values[channel_index] = min(float(min_values[channel_index]), value)
				max_values[channel_index] = max(float(max_values[channel_index]), value)
				avg_values[channel_index] = float(avg_values[channel_index]) + value
	var channel_notes := PackedStringArray()
	var summaries := PackedStringArray()
	for channel_index in channel_indices.size():
		var channel_name := str(channel_indices[channel_index])
		if channel_index < channel_names.size():
			channel_name = channel_names[channel_index]
		var min_value := float(min_values[channel_index])
		var max_value := float(max_values[channel_index])
		var avg_value := float(avg_values[channel_index]) / float(total_pixels)
		var channel_range := max_value - min_value
		summaries.append("%s %.3f..%.3f avg %.3f" % [channel_name, min_value, max_value, avg_value])
		if channel_range <= BAKE_CHANNEL_FLAT_EPSILON:
			channel_notes.append(channel_name + " flat")
		elif channel_range <= BAKE_CHANNEL_LOW_CONTRAST_EPSILON:
			channel_notes.append(channel_name + " low contrast")
		if min_value >= 1.0 - BAKE_CHANNEL_SATURATION_EPSILON:
			channel_notes.append(channel_name + " near white")
		elif max_value <= BAKE_CHANNEL_SATURATION_EPSILON:
			channel_notes.append(channel_name + " near black")
	if not channel_notes.is_empty():
		push_warning("Waterways: Generated " + label + " has limited debug contrast (" + ", ".join(summaries) + "; " + ", ".join(channel_notes) + "). Debug views may appear as a solid color until the bake input and filter settings produce varied data.")


func _get_color_channel(color: Color, channel_index: int) -> float:
	match channel_index:
		0:
			return color.r
		1:
			return color.g
		2:
			return color.b
		3:
			return color.a
		_:
			return 0.0


func _print_river_flow_vector_diagnostics(flow_vector_diagnostics: Dictionary) -> void:
	if flow_vector_diagnostics.is_empty():
		return
	var occupied_stats: Dictionary = flow_vector_diagnostics.get("occupied", {})
	var unused_stats: Dictionary = flow_vector_diagnostics.get("unused", {})
	print(
		"Waterways: River decoded flow-vector diagnostics: ",
		WaterHelperMethods.format_decoded_flow_vector_stats("occupied_source_tiles", occupied_stats),
		"; ",
		WaterHelperMethods.format_decoded_flow_vector_stats("unused_source_tiles", unused_stats),
		"."
	)


func _warn_if_bake_flow_vectors_near_neutral(flow_vector_diagnostics: Dictionary) -> void:
	if flow_vector_diagnostics.is_empty():
		return
	var occupied_stats: Dictionary = flow_vector_diagnostics.get("occupied", {})
	if typeof(occupied_stats) != TYPE_DICTIONARY or not bool(occupied_stats.get("valid", false)):
		return
	var near_neutral_percent := float(occupied_stats.get("near_neutral_percent", 0.0))
	var active_pixels := int(occupied_stats.get("active_pixel_count", 0))
	if active_pixels == 0 or near_neutral_percent >= 95.0:
		push_warning(
			"Waterways: Generated River occupied flow vectors are mostly near-neutral ("
			+ WaterHelperMethods.format_decoded_flow_vector_stats("occupied_source_tiles", occupied_stats)
			+ "). This usually means the collision-derived bake has no useful downstream interior direction."
		)


func _uses_downstream_baseline_generation(generation_behavior: String) -> bool:
	return generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE or generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY


func _uses_obstacle_avoidance_generation(generation_behavior: String) -> bool:
	return generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE


func _is_curve_only_generation(generation_behavior: String) -> bool:
	return generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY


func _requires_collision_raycast_layers(generation_behavior: String) -> bool:
	return generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY


func _get_generation_mode_label(generation_behavior: String) -> String:
	match generation_behavior:
		RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY:
			return "curve_only"
		RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY:
			return "collision_legacy"
		_:
			return "curve_collision_modifiers"


func _get_bake_source_kind(generation_behavior: String) -> String:
	match generation_behavior:
		RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY:
			return RiverBakeDataResource.SOURCE_KIND_CURVE_ONLY_BAKE
		RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY:
			return RiverBakeDataResource.SOURCE_KIND_SPLINE_COLLISION_BAKE
		_:
			return RiverBakeDataResource.SOURCE_KIND_CURVE_COLLISION_MODIFIERS_BAKE


func _reduce_flat_occupied_foam_support(image: Image, content_rect: Rect2i) -> bool:
	if not _soften_flat_occupied_support_channel(image, content_rect, 2, RIVER_FLAT_FOAM_SUPPORT_VALUE):
		return false
	push_warning(
		"Waterways: River collision-derived foam support is saturated across occupied tiles, so the default downstream bake softened foam support to avoid full-width foam bands. "
		+ "Inspect the collision support bake if you need the raw support texture."
	)
	return true


func _reduce_flat_occupied_pressure_support(image: Image, content_rect: Rect2i) -> bool:
	if not _soften_flat_occupied_support_channel(image, content_rect, 1, RIVER_FLAT_PRESSURE_SUPPORT_VALUE):
		return false
	push_warning(
		"Waterways: River collision-derived pressure support is saturated across occupied tiles, so the default downstream bake softened pressure support to keep generated flow-pattern strength usable. "
		+ "Inspect the collision support bake if you need the raw support texture."
	)
	return true


func _soften_flat_occupied_support_channel(image: Image, content_rect: Rect2i, channel_index: int, channel_value: float) -> bool:
	if image == null or image.is_empty():
		return false
	var stats := _get_occupied_channel_stats(image, content_rect, channel_index)
	if stats.is_empty():
		return false
	var average := float(stats.get("average", 0.0))
	var saturated_percent := float(stats.get("saturated_percent", 0.0))
	if average < 0.95 or saturated_percent < 90.0:
		return false
	_set_occupied_channel_value(image, content_rect, channel_index, channel_value)
	return true


func _get_occupied_channel_stats(image: Image, content_rect: Rect2i, channel_index: int) -> Dictionary:
	var source_rect := _clamp_rect_to_image(image, content_rect)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return {}
	var sum := 0.0
	var min_value := INF
	var max_value := -INF
	var saturated_pixels := 0
	var sampled_pixels := 0
	var above_005_pixels := 0
	var above_025_pixels := 0
	var above_050_pixels := 0
	for step_index in _steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, _uv2_sides, source_rect)
		for y in tile_rect.size.y:
			for x in tile_rect.size.x:
				var value := _get_color_channel(image.get_pixel(tile_rect.position.x + x, tile_rect.position.y + y), channel_index)
				sum += value
				min_value = min(min_value, value)
				max_value = max(max_value, value)
				if value >= 0.95:
					saturated_pixels += 1
				if value > 0.05:
					above_005_pixels += 1
				if value > 0.25:
					above_025_pixels += 1
				if value > 0.50:
					above_050_pixels += 1
				sampled_pixels += 1
	if sampled_pixels <= 0:
		return {}
	return {
		"sampled_pixel_count": sampled_pixels,
		"min": min_value,
		"max": max_value,
		"average": sum / float(sampled_pixels),
		"saturated_percent": 100.0 * float(saturated_pixels) / float(sampled_pixels),
		"above_0_05_percent": 100.0 * float(above_005_pixels) / float(sampled_pixels),
		"above_0_25_percent": 100.0 * float(above_025_pixels) / float(sampled_pixels),
		"above_0_50_percent": 100.0 * float(above_050_pixels) / float(sampled_pixels)
	}


func _get_obstacle_feature_stats(image: Image, content_rect: Rect2i) -> Dictionary:
	return {
		"pillow_impact": _get_occupied_channel_stats(image, content_rect, 0),
		"wake_eddy_seed": _get_occupied_channel_stats(image, content_rect, 1),
		"eddy_line_shear": _get_occupied_channel_stats(image, content_rect, 2),
		"side_deflection_confidence": _get_occupied_channel_stats(image, content_rect, 3)
	}


func _get_terrain_contact_feature_stats(image: Image, content_rect: Rect2i) -> Dictionary:
	return {
		"near_surface_contact": _get_occupied_channel_stats(image, content_rect, 0),
		"shallow_depth": _get_occupied_channel_stats(image, content_rect, 1),
		"protrusion_intersection": _get_occupied_channel_stats(image, content_rect, 2),
		"source_provenance": _get_occupied_channel_stats(image, content_rect, 3)
	}


func _get_bank_response_feature_stats(image: Image, content_rect: Rect2i) -> Dictionary:
	return {
		"bank_friction_drag": _get_occupied_channel_stats(image, content_rect, 0),
		"outside_bend_wet_pressure": _get_occupied_channel_stats(image, content_rect, 1),
		"inside_bend_deposition": _get_occupied_channel_stats(image, content_rect, 2),
		"hard_boundary_protrusion": _get_occupied_channel_stats(image, content_rect, 3)
	}


func _set_occupied_channel_value(image: Image, content_rect: Rect2i, channel_index: int, channel_value: float) -> void:
	var source_rect := _clamp_rect_to_image(image, content_rect)
	for step_index in _steps:
		var tile_rect := WaterHelperMethods.get_uv2_atlas_tile_rect(step_index, _uv2_sides, source_rect)
		for y in tile_rect.size.y:
			for x in tile_rect.size.x:
				var pixel_position := Vector2i(tile_rect.position.x + x, tile_rect.position.y + y)
				var color := image.get_pixelv(pixel_position)
				match channel_index:
					0:
						color.r = channel_value
					1:
						color.g = channel_value
					2:
						color.b = channel_value
					3:
						color.a = channel_value
				image.set_pixelv(pixel_position, color)


func _clamp_rect_to_image(image: Image, rect: Rect2i) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var image_size := image.get_size()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i(Vector2i.ZERO, image_size)
	var x0: int = clampi(rect.position.x, 0, image_size.x)
	var y0: int = clampi(rect.position.y, 0, image_size.y)
	var x1: int = clampi(rect.position.x + rect.size.x, x0, image_size.x)
	var y1: int = clampi(rect.position.y + rect.size.y, y0, image_size.y)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


func _has_unsaved_generated_textures() -> bool:
	if flow_foam_noise == null and dist_pressure == null and obstacle_features == null and terrain_contact_features == null and bank_response_features == null:
		return false
	return not WaterHelperMethods.has_external_bake_path(bake_data)


func _is_unsaved_texture_resource(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var path := texture.resource_path
	return path.is_empty() or path.find("::") != -1


func _print_bake_save_notice(texture_size: Vector2i, storage_result: Dictionary = {}) -> void:
	if not Engine.is_editor_hint():
		return
	if bool(storage_result.get("saved", false)):
		print(
			"Waterways: River Flow & Foam Map saved to external bake resource ",
			String(storage_result.get("path", "")),
			". Save the scene once so F6/export serializes this reference. flow_foam_noise=",
			_texture_size_label(flow_foam_noise, texture_size),
			" dist_pressure=",
			_texture_size_label(dist_pressure, texture_size),
			" obstacle_features=",
			_texture_size_label(obstacle_features, texture_size),
			" terrain_contact_features=",
			_texture_size_label(terrain_contact_features, texture_size),
			" bank_response_features=",
			_texture_size_label(bank_response_features, texture_size),
			" uv2_sides=",
			_uv2_sides,
			"."
		)
		return
	if bool(storage_result.get("requires_saved_scene", false)):
		print(
			"Waterways: River Flow & Foam Map regenerated in editor memory because this scene has no saved path. Save the scene, then rebake to create scene-owned external .res storage before F6/export. flow_foam_noise=",
			_texture_size_label(flow_foam_noise, texture_size),
			" dist_pressure=",
			_texture_size_label(dist_pressure, texture_size),
			" obstacle_features=",
			_texture_size_label(obstacle_features, texture_size),
			" terrain_contact_features=",
			_texture_size_label(terrain_contact_features, texture_size),
			" bank_response_features=",
			_texture_size_label(bank_response_features, texture_size),
			" uv2_sides=",
			_uv2_sides,
			"."
		)
		return
	var error_code := int(storage_result.get("error", OK))
	if error_code != OK:
		push_warning("Waterways: River Flow & Foam Map regenerated, but external .res storage failed. " + String(storage_result.get("message", "")) + " Error code: " + str(error_code) + ".")
		return
	print(
		"Waterways: River Flow & Foam Map regenerated in editor memory. Save the scene before F6/export so runtime uses this data. flow_foam_noise=",
		_texture_size_label(flow_foam_noise, texture_size),
		" dist_pressure=",
		_texture_size_label(dist_pressure, texture_size),
		" obstacle_features=",
		_texture_size_label(obstacle_features, texture_size),
		" terrain_contact_features=",
		_texture_size_label(terrain_contact_features, texture_size),
		" bank_response_features=",
		_texture_size_label(bank_response_features, texture_size),
		" uv2_sides=",
		_uv2_sides,
		"."
	)


func _texture_size_label(texture: Texture2D, fallback_size: Vector2i = Vector2i.ZERO) -> String:
	if texture != null:
		return str(texture.get_width()) + "x" + str(texture.get_height())
	if fallback_size != Vector2i.ZERO:
		return str(fallback_size.x) + "x" + str(fallback_size.y)
	return "<none>"


func validate_data_textures() -> void:
	var failures := []
	var notes := []
	_append_texture_data_validation("flow_foam_noise", flow_foam_noise, true, failures, notes)
	_append_texture_data_validation("dist_pressure", dist_pressure, false, failures, notes)
	_append_texture_data_validation("obstacle_features", obstacle_features, false, failures, notes)
	_append_texture_data_validation("terrain_contact_features", terrain_contact_features, false, failures, notes)
	_append_texture_data_validation("bank_response_features", bank_response_features, false, failures, notes)
	if failures.is_empty():
		print("RIVER_DATA_TEXTURE_TEST: " + "; ".join(notes))
	else:
		push_warning("RIVER_DATA_TEXTURE_TEST: " + "; ".join(failures) + " | " + "; ".join(notes))


func _append_texture_data_validation(label: String, texture: Texture2D, expect_neutral_flow: bool, failures: Array, notes: Array) -> void:
	if texture == null:
		failures.append(label + " is not assigned")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append(label + " has no readable image data")
		return
	var size := image.get_size()
	notes.append("%s size=%dx%d" % [label, size.x, size.y])
	_append_data_texture_import_validation(label, texture, failures, notes)
	if expect_neutral_flow:
		_append_neutral_flow_validation(label, image, texture.resource_path, failures, notes)
		_append_flow_vector_stats_validation(label, image, notes)
		_append_alpha_phase_noise_validation(label, image, notes)


func _append_data_texture_import_validation(label: String, texture: Texture2D, failures: Array, notes: Array) -> void:
	var path := texture.resource_path
	var generated_bake_source_kind := _get_generated_bake_source_kind_for_texture(label, texture)
	if path.is_empty() or not generated_bake_source_kind.is_empty():
		var source_note := label + " source=generated/resource-owned"
		if not generated_bake_source_kind.is_empty():
			source_note += " source_kind=" + generated_bake_source_kind
		notes.append(source_note)
		return
	notes.append(label + " source=" + path)
	if not path.begins_with("res://"):
		failures.append(label + " uses a non-project texture path")
		return
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		failures.append(label + " has no .import settings file")
		return
	var import_text := FileAccess.get_file_as_string(import_path)
	if import_text.find("compress/mode=0") == -1:
		failures.append(label + " import should use lossless/uncompressed texture data (compress/mode=0)")
	if import_text.find("compress/normal_map=0") == -1:
		failures.append(label + " import should not be treated as a normal map")
	if import_text.find("mipmaps/generate=true") != -1:
		failures.append(label + " import has mipmaps enabled before neutral-flow/mask stability is validated")
	if import_text.find("\"vram_texture\": true") != -1 or import_text.find("path.s3tc=") != -1:
		failures.append(label + " import uses VRAM/block-compressed data")


func _get_generated_bake_source_kind_for_texture(label: String, texture: Texture2D) -> String:
	if texture == null or bake_data == null:
		return ""
	var source_kind := String(bake_data.get("source_kind"))
	if not source_kind.begins_with("generated_"):
		return ""
	var stored_texture := bake_data.get(label) as Texture2D
	if stored_texture == texture:
		return source_kind
	var bake_path := bake_data.resource_path
	var texture_path := texture.resource_path
	if not bake_path.is_empty() and texture_path.begins_with(bake_path + "::"):
		return source_kind
	return ""


func _append_neutral_flow_validation(label: String, image: Image, texture_path: String, failures: Array, notes: Array) -> void:
	var size := image.get_size()
	var step := max(1, int(ceil(float(max(size.x, size.y)) / 128.0)))
	var best_error := INF
	var best_color := Color()
	var best_pixel := Vector2i.ZERO
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var color := image.get_pixel(x, y)
			var error: float = abs(color.r - 0.5) + abs(color.g - 0.5)
			if error < best_error:
				best_error = error
				best_color = color
				best_pixel = Vector2i(x, y)
	notes.append("%s closest_neutral_rg=(%.4f, %.4f) pixel=(%d,%d)" % [label, best_color.r, best_color.g, best_pixel.x, best_pixel.y])
	var neutral_tolerance := 0.01
	if best_error > neutral_tolerance and not texture_path.is_empty():
		failures.append(label + " imported flow map did not preserve or include a sampled neutral (0.5, 0.5) flow value")


func _append_flow_vector_stats_validation(label: String, image: Image, notes: Array) -> void:
	var content_rect := _get_bake_content_rect_for_image(image)
	var source_stats := WaterHelperMethods.get_decoded_flow_vector_stats(
		image,
		content_rect,
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD
	)
	notes.append(WaterHelperMethods.format_decoded_flow_vector_stats(label + " source_rect", source_stats))
	var atlas_stats := WaterHelperMethods.get_uv2_atlas_decoded_flow_vector_stats(
		image,
		_get_bake_uv2_sides(),
		_calculate_step_count(),
		content_rect,
		WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD
	)
	var occupied_stats: Dictionary = atlas_stats.get("occupied", {})
	var unused_stats: Dictionary = atlas_stats.get("unused", {})
	notes.append(WaterHelperMethods.format_decoded_flow_vector_stats(label + " occupied_tiles", occupied_stats))
	notes.append(WaterHelperMethods.format_decoded_flow_vector_stats(label + " unused_tiles", unused_stats))


func _get_bake_content_rect_for_image(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var content_rect := Rect2i(Vector2i.ZERO, image.get_size())
	if bake_data != null:
		var stored_rect = bake_data.get("content_rect")
		if typeof(stored_rect) == TYPE_RECT2I and stored_rect.size.x > 0 and stored_rect.size.y > 0:
			content_rect = stored_rect
	return content_rect


func _get_bake_uv2_sides() -> int:
	var uv2_sides := _uv2_sides
	if bake_data != null:
		var stored_uv2_sides = bake_data.get("uv2_sides")
		if stored_uv2_sides != null:
			uv2_sides = int(stored_uv2_sides)
	return max(1, uv2_sides)


func _append_alpha_phase_noise_validation(label: String, image: Image, notes: Array) -> void:
	var size := image.get_size()
	var step := max(1, int(ceil(float(max(size.x, size.y)) / 128.0)))
	var alpha_min := INF
	var alpha_max := -INF
	var samples := 0
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var alpha := image.get_pixel(x, y).a
			alpha_min = min(alpha_min, alpha)
			alpha_max = max(alpha_max, alpha)
			samples += 1
	var alpha_range: float = alpha_max - alpha_min
	var alpha_state := "varied" if alpha_range > 0.001 else "flat"
	notes.append("%s alpha_min=%.4f alpha_max=%.4f alpha_range=%.4f alpha_state=%s samples=%d" % [label, alpha_min, alpha_max, alpha_range, alpha_state, samples])


func validate_filter_renderer() -> void:
	var failures := []
	var notes := []
	if not is_inside_tree():
		push_warning("FILTER_RENDERER_TEST: River must be inside the edited scene tree")
		return
	var renderer_instance = _filter_renderer.instantiate()
	add_child(renderer_instance)
	await get_tree().process_frame
	var source_texture := _make_filter_validation_texture()
	var combine_result: Texture2D = await renderer_instance.apply_combine(source_texture, source_texture, source_texture, source_texture)
	_append_filter_texture_validation("combine", combine_result, failures, notes)
	var dot_result: Texture2D = await renderer_instance.apply_dotproduct(source_texture, 8.0)
	_append_filter_texture_validation("dotproduct", dot_result, failures, notes)
	var flow_pressure_result: Texture2D = await renderer_instance.apply_flow_pressure(source_texture, 8.0, 2.0)
	_append_filter_texture_validation("flow_pressure", flow_pressure_result, failures, notes)
	var foam_result: Texture2D = await renderer_instance.apply_foam(source_texture, 0.1, 0.9, 8.0)
	_append_filter_texture_validation("foam", foam_result, failures, notes)
	var blur_result: Texture2D = await renderer_instance.apply_blur(source_texture, 0.0, 8.0)
	_append_filter_texture_validation("blur_zero", blur_result, failures, notes)
	var vertical_blur_result: Texture2D = await renderer_instance.apply_vertical_blur(source_texture, 0.0, 8.0)
	_append_filter_texture_validation("vertical_blur_zero", vertical_blur_result, failures, notes)
	var normal_result: Texture2D = await renderer_instance.apply_normal(source_texture, 0.0)
	_append_filter_texture_validation("normal_zero_size", normal_result, failures, notes)
	var normal_to_flow_result: Texture2D = await renderer_instance.apply_normal_to_flow(normal_result, 0.0)
	_append_filter_texture_validation("normal_to_flow", normal_to_flow_result, failures, notes)
	var dilate_result: Texture2D = await renderer_instance.apply_dilate(source_texture, 0.0, 0.0, 0.0, source_texture)
	_append_filter_texture_validation("dilate_zero", dilate_result, failures, notes)
	var dilate_default_fill_result: Texture2D = await renderer_instance.apply_dilate(source_texture, 0.0, 1.0, 0.0)
	_append_filter_texture_validation("dilate_default_fill", dilate_default_fill_result, failures, notes)
	var active_dilate_fill_texture = renderer_instance.filter_mat.get_shader_parameter("color_texture")
	if active_dilate_fill_texture == null:
		failures.append("dilate default fill did not assign a fallback color texture")
	elif active_dilate_fill_texture == source_texture:
		failures.append("dilate default fill reused the previous color_texture")
	else:
		notes.append("dilate_default_fill_texture_reset=true")
	_cleanup_bake_renderer(renderer_instance)
	if failures.is_empty():
		print("FILTER_RENDERER_TEST: " + "; ".join(notes))
	else:
		push_warning("FILTER_RENDERER_TEST: " + "; ".join(failures) + " | " + "; ".join(notes))


func _make_filter_validation_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var xf := float(x) / float(max(1, image.get_width() - 1))
			var yf := float(y) / float(max(1, image.get_height() - 1))
			var checker := 1.0 if ((x + y) % 2 == 0) else 0.0
			image.set_pixel(x, y, Color(xf, yf, checker, 1.0))
	return ImageTexture.create_from_image(image)


func _append_filter_texture_validation(label: String, texture: Texture2D, failures: Array, notes: Array) -> void:
	if texture == null:
		failures.append(label + " returned null texture")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append(label + " returned no readable image data")
		return
	var size := image.get_size()
	if size.x <= 0 or size.y <= 0:
		failures.append(label + " returned invalid size")
		return
	var invalid_samples := 0
	for sample_point in [Vector2i(0, 0), Vector2i(size.x / 2, size.y / 2), Vector2i(size.x - 1, size.y - 1)]:
		var color := image.get_pixelv(sample_point)
		if is_nan(color.r) or is_nan(color.g) or is_nan(color.b) or is_nan(color.a) or is_inf(color.r) or is_inf(color.g) or is_inf(color.b) or is_inf(color.a):
			invalid_samples += 1
	if invalid_samples > 0:
		failures.append(label + " returned invalid numeric samples")
	notes.append("%s=%dx%d" % [label, size.x, size.y])


func _ensure_bake_data() -> Resource:
	if bake_data == null:
		_bake_data_resource = RiverBakeDataResource.new()
	return bake_data


func _apply_bake_data() -> void:
	if bake_data == null:
		return
	if bake_data.has_method("normalize_source_metadata"):
		bake_data.call("normalize_source_metadata")
	flow_foam_noise = bake_data.get("flow_foam_noise") as Texture2D
	dist_pressure = bake_data.get("dist_pressure") as Texture2D
	obstacle_features = bake_data.get("obstacle_features") as Texture2D
	terrain_contact_features = bake_data.get("terrain_contact_features") as Texture2D
	bank_response_features = bake_data.get("bank_response_features") as Texture2D
	water_occupancy = bake_data.get("water_occupancy") as Texture2D
	var resource_uv2_sides = bake_data.get("uv2_sides")
	if resource_uv2_sides != null:
		_uv2_sides = max(1, int(resource_uv2_sides))
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_obstacle_features", obstacle_features)
	set_materials("i_terrain_contact_features", terrain_contact_features)
	set_materials("i_bank_response_features", bank_response_features)
	set_materials("i_water_occupancy", water_occupancy)
	set_materials("i_uv2_sides", _uv2_sides)
	set_materials("i_flow_projected", _bake_metadata_flow_projected())
	var textures_are_present := flow_foam_noise != null and dist_pressure != null and obstacle_features != null and terrain_contact_features != null and bank_response_features != null
	_set_valid_flowmap(textures_are_present and _bake_data_matches_current_source())


func _bake_metadata_flow_projected() -> bool:
	if bake_data == null:
		return false
	var metadata = bake_data.get("source_metadata")
	if typeof(metadata) != TYPE_DICTIONARY:
		return false
	return bool((metadata as Dictionary).get("flow_projected", false))


func _write_bake_data(texture_size: Vector2i, source_texture_size: Vector2i, content_rect: Rect2i, flow_vector_diagnostics: Dictionary = {}, generation_behavior: String = RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE, foam_support_reduced: bool = false, pressure_support_reduced: bool = false, bake_diagnostics: Dictionary = {}) -> void:
	var data := _ensure_bake_data()
	var texture_layout := RiverBakeDataResource.TEXTURE_LAYOUT_PADDED_UV2_ATLAS
	var sanitized_generation_behavior := _sanitize_bake_generation_behavior(generation_behavior)
	var source_kind := _get_bake_source_kind(sanitized_generation_behavior)
	var collision_stats: Dictionary = bake_diagnostics.get("collision_stats", {})
	var occupied_stats: Dictionary = flow_vector_diagnostics.get("occupied", {})
	var grade_energy_stats: Dictionary = bake_diagnostics.get("grade_energy_stats", {})
	var bend_bias_stats: Dictionary = bake_diagnostics.get("bend_bias_stats", {})
	var obstacle_feature_stats: Dictionary = bake_diagnostics.get("obstacle_feature_stats", {})
	var terrain_contact_feature_stats: Dictionary = bake_diagnostics.get("terrain_contact_feature_stats", {})
	var bank_response_feature_stats: Dictionary = bake_diagnostics.get("bank_response_feature_stats", {})
	var source_metadata := {
		"bake_revision": _make_bake_revision(),
		"generation_behavior": sanitized_generation_behavior,
		"generation_mode": _get_generation_mode_label(sanitized_generation_behavior),
		"downstream_baseline_applied": _uses_downstream_baseline_generation(sanitized_generation_behavior),
		"downstream_baseline_strength": RIVER_DOWNSTREAM_BASELINE_STRENGTH,
		"legacy_collision_only": sanitized_generation_behavior == RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY,
		"collision_hit_pixel_count": int(collision_stats.get("hit_pixel_count", 0)),
		"collision_total_pixel_count": int(collision_stats.get("total_pixel_count", 0)),
		"collision_hit_pixel_percent": float(collision_stats.get("hit_pixel_percent", 0.0)),
		"curve_baseline_pixel_count": int(occupied_stats.get("sampled_pixel_count", 0)) if _uses_downstream_baseline_generation(sanitized_generation_behavior) else 0,
		"collision_probe_skipped": bool(bake_diagnostics.get("collision_probe_skipped", false)),
		"collision_support_filters_ran": bool(bake_diagnostics.get("collision_support_filters_ran", false)),
		"obstacle_avoidance_applied": bool(bake_diagnostics.get("obstacle_avoidance_applied", false)),
		"flow_projected": bool(bake_diagnostics.get("flow_projected", false)),
		"water_occupancy_baked": bool(bake_diagnostics.get("water_occupancy_baked", false)),
		"water_occupancy_ramp_tiles": RIVER_OCCUPANCY_RAMP_TILES,
		"water_occupancy_protrusion_threshold": RIVER_OCCUPANCY_PROTRUSION_THRESHOLD,
		"water_occupancy_protrusion_confidence_min": RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN,
		"flow_projection_strides": RIVER_FLOW_PROJECTION_STRIDES.duplicate(),
		"flow_projection_iterations_per_stride": RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE,
		"obstacle_avoidance_strength": RIVER_OBSTACLE_AVOIDANCE_STRENGTH,
		"obstacle_avoidance_algorithm": "pressure_projection_free_slip_jacobi_with_legacy_sdf_steering_fallback",
		"obstacle_avoidance_influence_start": RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_START,
		"obstacle_avoidance_influence_full": RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_FULL,
		"obstacle_avoidance_sdf_radius_tiles": RIVER_OBSTACLE_AVOIDANCE_SDF_RADIUS_TILES,
		"obstacle_avoidance_sdf_blur_tiles": RIVER_OBSTACLE_AVOIDANCE_SDF_BLUR_TILES,
		"obstacle_avoidance_upstream_lookahead_tiles": RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_LOOKAHEAD_TILES,
		"obstacle_avoidance_upstream_strength": RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_STRENGTH,
		"obstacle_avoidance_min_downstream_alignment": RIVER_OBSTACLE_AVOIDANCE_MIN_DOWNSTREAM_ALIGNMENT,
		"obstacle_avoidance_bank_friction_suppression": RIVER_OBSTACLE_AVOIDANCE_BANK_FRICTION_SUPPRESSION,
		"obstacle_avoidance_hard_boundary_steering_gate": RIVER_OBSTACLE_AVOIDANCE_HARD_BOUNDARY_STEERING_GATE,
		"obstacle_avoidance_uses_bank_response_context": true,
		"obstacle_features_baked": true,
		"obstacle_features_algorithm": "direct_terrain_contact_anchored_pillow_tight_support_bank_context_flow_feature_classification_debug_only",
		"obstacle_features_neutral_value": Color(0.0, 0.0, 0.0, 0.0),
		"obstacle_features_support_start": RIVER_OBSTACLE_FEATURE_SUPPORT_START,
		"obstacle_features_support_full": RIVER_OBSTACLE_FEATURE_SUPPORT_FULL,
		"obstacle_features_facing_start": RIVER_OBSTACLE_FEATURE_FACING_START,
		"obstacle_features_facing_full": RIVER_OBSTACLE_FEATURE_FACING_FULL,
		"obstacle_features_pillow_support_start": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START,
		"obstacle_features_pillow_support_full": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL,
		"obstacle_features_pillow_contact_search_tiles": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES,
		"obstacle_features_pillow_contact_gate_start": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START,
		"obstacle_features_pillow_contact_gate_full": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL,
		"obstacle_features_pillow_anchor_source": "terrain_contact_features.b_direct_search",
		"obstacle_features_pillow_bank_response_role": "weak_context_only_not_anchor",
		"obstacle_features_wake_length_tiles": RIVER_OBSTACLE_FEATURE_WAKE_LENGTH_TILES,
		"obstacle_features_wake_width_tiles": RIVER_OBSTACLE_FEATURE_WAKE_WIDTH_TILES,
		"obstacle_features_side_width_tiles": RIVER_OBSTACLE_FEATURE_SIDE_WIDTH_TILES,
		"obstacle_features_wake_start": RIVER_OBSTACLE_FEATURE_WAKE_START,
		"obstacle_features_wake_full": RIVER_OBSTACLE_FEATURE_WAKE_FULL,
		"obstacle_features_bank_friction_suppression": RIVER_OBSTACLE_FEATURE_BANK_FRICTION_SUPPRESSION,
		"obstacle_features_hard_boundary_wake_gate": RIVER_OBSTACLE_FEATURE_HARD_BOUNDARY_WAKE_GATE,
		"obstacle_features_confidence_start": RIVER_OBSTACLE_FEATURE_CONFIDENCE_START,
		"obstacle_features_confidence_full": RIVER_OBSTACLE_FEATURE_CONFIDENCE_FULL,
		"obstacle_features_eddy_line_edge_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_START,
		"obstacle_features_eddy_line_edge_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_FULL,
		"obstacle_features_eddy_line_wake_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_START,
		"obstacle_features_eddy_line_wake_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_FULL,
		"obstacle_features_eddy_line_hard_gate_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_START,
		"obstacle_features_eddy_line_hard_gate_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_FULL,
		"obstacle_features_eddy_line_energy_gate_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_START,
		"obstacle_features_eddy_line_energy_gate_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_FULL,
		"obstacle_features_eddy_line_support_reject_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_START,
		"obstacle_features_eddy_line_support_reject_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_FULL,
		"obstacle_features_uses_tight_support": true,
		"obstacle_features_uses_bank_response_context": true,
		"obstacle_features_uses_terrain_protrusion_context": true,
		"obstacle_features_uses_grade_energy_context": true,
		"obstacle_features_pillow_uses_contact_anchor": true,
		"filtered_feature_edge_sync_depth_pixels": RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS,
		"obstacle_feature_stats": obstacle_feature_stats.duplicate(true),
		"terrain_contact_features_baked": true,
		"terrain_contact_features_algorithm": "uv2_world_height_delta_supersampled_blended_sources_debug_only",
		"terrain_contact_features_neutral_value": Color(0.0, 0.0, 0.0, 0.0),
		"terrain_contact_full_band": RIVER_TERRAIN_CONTACT_FULL_BAND,
		"terrain_contact_fade_distance": RIVER_TERRAIN_CONTACT_FADE_DISTANCE,
		"terrain_contact_shallow_full_depth": RIVER_TERRAIN_SHALLOW_FULL_DEPTH,
		"terrain_contact_shallow_fade_depth": RIVER_TERRAIN_SHALLOW_FADE_DEPTH,
		"terrain_contact_protrusion_fade_height": RIVER_TERRAIN_PROTRUSION_FADE_HEIGHT,
		"terrain_contact_protrusion_full_height": RIVER_TERRAIN_PROTRUSION_FULL_HEIGHT,
		"terrain_contact_raycast_up_offset": RIVER_TERRAIN_CONTACT_RAYCAST_UP_OFFSET,
		"terrain_contact_raycast_down_distance": RIVER_TERRAIN_CONTACT_RAYCAST_DOWN_DISTANCE,
		"terrain_contact_hterrain_source_confidence": RIVER_TERRAIN_HTERRAIN_SOURCE_CONFIDENCE,
		"terrain_contact_physics_source_confidence": RIVER_TERRAIN_PHYSICS_SOURCE_CONFIDENCE,
		"terrain_contact_supersamples": RIVER_TERRAIN_CONTACT_SUPERSAMPLES,
		"terrain_contact_source_blend_band": RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND,
		"terrain_contact_edge_smooth_passes": RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES,
		"filter_passes_column_clamped": true,
		"terrain_contact_feature_stats": terrain_contact_feature_stats.duplicate(true),
		"bank_response_features_baked": true,
		"bank_response_features_algorithm": "terrain_contact_depth_bend_grade_flow_semantic_response_debug_only",
		"bank_response_features_neutral_value": Color(0.0, 0.0, 0.0, 0.0),
		"bank_response_probe_tiles": RIVER_BANK_RESPONSE_PROBE_TILES,
		"bank_response_friction_contact_weight": RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
		"bank_response_friction_shallow_weight": RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
		"bank_response_hard_protrusion_weight": RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
		"bank_response_outside_bend_start": RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
		"bank_response_outside_bend_full": RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
		"bank_response_inside_bend_start": RIVER_BANK_RESPONSE_INSIDE_BEND_START,
		"bank_response_inside_bend_full": RIVER_BANK_RESPONSE_INSIDE_BEND_FULL,
		"bank_response_uses_obstacle_features": false,
		"bank_response_feature_stats": bank_response_feature_stats.duplicate(true),
		"support_fallback_applied": bool(bake_diagnostics.get("support_fallback_applied", false)),
		"support_fallback_reason": String(bake_diagnostics.get("support_fallback_reason", "")),
		"no_collider_curve_only_fallback": String(bake_diagnostics.get("support_fallback_reason", "")) == "no_collision_hits",
		"blank_support_foam_value": RIVER_BLANK_SUPPORT_VALUE,
		"blank_support_dist_pressure": Vector2(RIVER_BLANK_SUPPORT_VALUE, RIVER_BLANK_SUPPORT_VALUE),
		"grade_energy_baked": true,
		"grade_energy_algorithm": "curve_height_drop_vertex_aligned_longitudinal_lerp",
		"grade_energy_lookahead_tiles": RIVER_GRADE_ENERGY_LOOKAHEAD_TILES,
		"grade_energy_smooth_radius_tiles": RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES,
		"grade_energy_reference_grade": RIVER_GRADE_ENERGY_REFERENCE_GRADE,
		"neutral_grade_energy_feature_value": RIVER_NEUTRAL_GRADE_ENERGY_VALUE,
		"grade_energy_stats": grade_energy_stats.duplicate(true),
		"neutral_bend_bias_feature_value": RIVER_NEUTRAL_BEND_BIAS_VALUE,
		"bend_bias_baked": true,
		"bend_bias_algorithm": "curve_planar_curvature_vertex_aligned_longitudinal_lerp_cross_river_bias",
		"bend_bias_sign_convention": "dist_pressure.a packed signed bias; values above 0.5 mean outside bend faster, below 0.5 mean inside bend slower",
		"bend_bias_lookahead_tiles": RIVER_BEND_BIAS_LOOKAHEAD_TILES,
		"bend_bias_smooth_radius_tiles": RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES,
		"bend_bias_reference_radians": RIVER_BEND_BIAS_REFERENCE_RADIANS,
		"bend_bias_stats": bend_bias_stats.duplicate(true),
		"flow_speed_scaled": _any_flow_speed_non_neutral(),
		"flow_speed_factor_max": RIVER_FLOW_SPEED_FACTOR_MAX,
		"flat_foam_support_reduced": foam_support_reduced,
		"flat_foam_support_value": RIVER_FLAT_FOAM_SUPPORT_VALUE,
		"flat_pressure_support_reduced": pressure_support_reduced,
		"flat_pressure_support_value": RIVER_FLAT_PRESSURE_SUPPORT_VALUE,
		"near_neutral_threshold": WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
		"flow_vector_diagnostics": flow_vector_diagnostics.duplicate(true),
		"supported_future_source_kinds": PackedStringArray([
			"generated_spline_collision_bake",
			"generated_downstream_baseline_collision_bake",
			"generated_curve_collision_modifiers_bake",
			"generated_curve_only_bake",
			"imported_linear_data_map",
			"hand_painted_flow_map",
			"dcc_or_simulation_flow_map",
			"shore_distance_field",
			"terrain_slope_field",
			"obstacle_influence_field"
		])
	}
	if data.has_method("set_from_bake"):
		data.call(
			"set_from_bake",
			flow_foam_noise,
			dist_pressure,
			obstacle_features,
			terrain_contact_features,
			bank_response_features,
			texture_size,
			_uv2_sides,
			_get_mesh_global_aabb(mesh_instance),
			_get_bake_settings(source_texture_size, texture_size, content_rect, texture_layout),
			source_texture_size,
			content_rect,
			texture_layout,
			source_kind,
			source_metadata,
			get_bake_source_signature(),
			water_occupancy
		)
	if Engine.is_editor_hint():
		notify_property_list_changed()


func get_bake_source_signature() -> Dictionary:
	var points := []
	if curve != null:
		for point_index in curve.get_point_count():
			points.append({
				"position": _vector3_signature(curve.get_point_position(point_index)),
				"in": _vector3_signature(curve.get_point_in(point_index)),
				"out": _vector3_signature(curve.get_point_out(point_index)),
				"width": _signature_float(_get_width_for_point(point_index)),
				"flow_speed": _signature_float(_get_flow_speed_for_point(point_index))
			})
	var step_count := _calculate_step_count()
	return {
		"version": RIVER_BAKE_SOURCE_SIGNATURE_VERSION,
		"curve_bake_interval": _signature_float(curve.bake_interval) if curve != null else 0.0,
		"points": points,
		"shape_step_length_divs": shape_step_length_divs,
		"shape_step_width_divs": shape_step_width_divs,
		"shape_smoothness": _signature_float(shape_smoothness),
		"baking_resolution": baking_resolution,
		"baking_raycast_distance": _signature_float(baking_raycast_distance),
		"baking_raycast_layers": baking_raycast_layers,
		"baking_dilate": _signature_float(baking_dilate),
		"baking_flowmap_blur": _signature_float(baking_flowmap_blur),
		"baking_foam_cutoff": _signature_float(baking_foam_cutoff),
		"baking_foam_offset": _signature_float(baking_foam_offset),
		"baking_foam_blur": _signature_float(baking_foam_blur),
		"bake_generation_behavior": _sanitize_bake_generation_behavior(bake_generation_behavior),
		"downstream_baseline_strength": _signature_float(RIVER_DOWNSTREAM_BASELINE_STRENGTH),
		"obstacle_avoidance_strength": _signature_float(RIVER_OBSTACLE_AVOIDANCE_STRENGTH),
		"obstacle_avoidance_influence_start": _signature_float(RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_START),
		"obstacle_avoidance_influence_full": _signature_float(RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_FULL),
		"obstacle_avoidance_sdf_radius_tiles": _signature_float(RIVER_OBSTACLE_AVOIDANCE_SDF_RADIUS_TILES),
		"obstacle_avoidance_sdf_blur_tiles": _signature_float(RIVER_OBSTACLE_AVOIDANCE_SDF_BLUR_TILES),
		"obstacle_avoidance_upstream_lookahead_tiles": _signature_float(RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_LOOKAHEAD_TILES),
		"obstacle_avoidance_upstream_strength": _signature_float(RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_STRENGTH),
		"obstacle_avoidance_min_downstream_alignment": _signature_float(RIVER_OBSTACLE_AVOIDANCE_MIN_DOWNSTREAM_ALIGNMENT),
		"obstacle_avoidance_bank_friction_suppression": _signature_float(RIVER_OBSTACLE_AVOIDANCE_BANK_FRICTION_SUPPRESSION),
		"obstacle_avoidance_hard_boundary_steering_gate": _signature_float(RIVER_OBSTACLE_AVOIDANCE_HARD_BOUNDARY_STEERING_GATE),
		"obstacle_feature_support_start": _signature_float(RIVER_OBSTACLE_FEATURE_SUPPORT_START),
		"obstacle_feature_support_full": _signature_float(RIVER_OBSTACLE_FEATURE_SUPPORT_FULL),
		"obstacle_feature_facing_start": _signature_float(RIVER_OBSTACLE_FEATURE_FACING_START),
		"obstacle_feature_facing_full": _signature_float(RIVER_OBSTACLE_FEATURE_FACING_FULL),
		"obstacle_feature_pillow_support_start": _signature_float(RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START),
		"obstacle_feature_pillow_support_full": _signature_float(RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL),
		"obstacle_feature_pillow_contact_search_tiles": _signature_float(RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES),
		"obstacle_feature_pillow_contact_gate_start": _signature_float(RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START),
		"obstacle_feature_pillow_contact_gate_full": _signature_float(RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL),
		"obstacle_feature_pillow_anchor_source": "terrain_contact_features.b_direct_search",
		"obstacle_feature_pillow_bank_response_role": "weak_context_only_not_anchor",
		"obstacle_feature_wake_length_tiles": _signature_float(RIVER_OBSTACLE_FEATURE_WAKE_LENGTH_TILES),
		"obstacle_feature_wake_width_tiles": _signature_float(RIVER_OBSTACLE_FEATURE_WAKE_WIDTH_TILES),
		"obstacle_feature_side_width_tiles": _signature_float(RIVER_OBSTACLE_FEATURE_SIDE_WIDTH_TILES),
		"obstacle_feature_wake_start": _signature_float(RIVER_OBSTACLE_FEATURE_WAKE_START),
		"obstacle_feature_wake_full": _signature_float(RIVER_OBSTACLE_FEATURE_WAKE_FULL),
		"obstacle_feature_bank_friction_suppression": _signature_float(RIVER_OBSTACLE_FEATURE_BANK_FRICTION_SUPPRESSION),
		"obstacle_feature_hard_boundary_wake_gate": _signature_float(RIVER_OBSTACLE_FEATURE_HARD_BOUNDARY_WAKE_GATE),
		"obstacle_feature_confidence_start": _signature_float(RIVER_OBSTACLE_FEATURE_CONFIDENCE_START),
		"obstacle_feature_confidence_full": _signature_float(RIVER_OBSTACLE_FEATURE_CONFIDENCE_FULL),
		"obstacle_feature_eddy_line_edge_start": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_START),
		"obstacle_feature_eddy_line_edge_full": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_FULL),
		"obstacle_feature_eddy_line_wake_start": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_START),
		"obstacle_feature_eddy_line_wake_full": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_FULL),
		"obstacle_feature_eddy_line_hard_gate_start": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_START),
		"obstacle_feature_eddy_line_hard_gate_full": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_FULL),
		"obstacle_feature_eddy_line_energy_gate_start": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_START),
		"obstacle_feature_eddy_line_energy_gate_full": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_FULL),
		"obstacle_feature_eddy_line_support_reject_start": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_START),
		"obstacle_feature_eddy_line_support_reject_full": _signature_float(RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_FULL),
		"water_occupancy_ramp_tiles": _signature_float(RIVER_OCCUPANCY_RAMP_TILES),
		"water_occupancy_protrusion_threshold": _signature_float(RIVER_OCCUPANCY_PROTRUSION_THRESHOLD),
		"water_occupancy_protrusion_confidence_min": _signature_float(RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN),
		"flow_projection_strides": ",".join(RIVER_FLOW_PROJECTION_STRIDES.map(func(stride: int) -> String: return str(stride))),
		"flow_projection_iterations_per_stride": RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE,
		"flow_tangency_passes": RIVER_FLOW_TANGENCY_PASSES,
		"terrain_contact_full_band": _signature_float(RIVER_TERRAIN_CONTACT_FULL_BAND),
		"terrain_contact_fade_distance": _signature_float(RIVER_TERRAIN_CONTACT_FADE_DISTANCE),
		"terrain_contact_shallow_full_depth": _signature_float(RIVER_TERRAIN_SHALLOW_FULL_DEPTH),
		"terrain_contact_shallow_fade_depth": _signature_float(RIVER_TERRAIN_SHALLOW_FADE_DEPTH),
		"terrain_contact_protrusion_fade_height": _signature_float(RIVER_TERRAIN_PROTRUSION_FADE_HEIGHT),
		"terrain_contact_protrusion_full_height": _signature_float(RIVER_TERRAIN_PROTRUSION_FULL_HEIGHT),
		"terrain_contact_raycast_up_offset": _signature_float(RIVER_TERRAIN_CONTACT_RAYCAST_UP_OFFSET),
		"terrain_contact_raycast_down_distance": _signature_float(RIVER_TERRAIN_CONTACT_RAYCAST_DOWN_DISTANCE),
		"terrain_contact_hterrain_source_confidence": _signature_float(RIVER_TERRAIN_HTERRAIN_SOURCE_CONFIDENCE),
		"terrain_contact_physics_source_confidence": _signature_float(RIVER_TERRAIN_PHYSICS_SOURCE_CONFIDENCE),
		"terrain_contact_supersamples": RIVER_TERRAIN_CONTACT_SUPERSAMPLES,
		"terrain_contact_source_blend_band": _signature_float(RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND),
		"terrain_contact_edge_smooth_passes": RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES,
		"uv2_world_sample_tile_classifier": "floor_partition_match_tile_rect",
		"filter_passes_column_clamped": true,
		"filtered_feature_edge_sync_depth_pixels": RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS,
		"bank_response_probe_tiles": _signature_float(RIVER_BANK_RESPONSE_PROBE_TILES),
		"bank_response_friction_contact_weight": _signature_float(RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT),
		"bank_response_friction_shallow_weight": _signature_float(RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT),
		"bank_response_hard_protrusion_weight": _signature_float(RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT),
		"bank_response_outside_bend_start": _signature_float(RIVER_BANK_RESPONSE_OUTSIDE_BEND_START),
		"bank_response_outside_bend_full": _signature_float(RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL),
		"bank_response_inside_bend_start": _signature_float(RIVER_BANK_RESPONSE_INSIDE_BEND_START),
		"bank_response_inside_bend_full": _signature_float(RIVER_BANK_RESPONSE_INSIDE_BEND_FULL),
		"blank_support_value": _signature_float(RIVER_BLANK_SUPPORT_VALUE),
		"neutral_grade_energy_value": _signature_float(RIVER_NEUTRAL_GRADE_ENERGY_VALUE),
		"grade_energy_source_sampling": "vertex_aligned_longitudinal_lerp",
		"grade_energy_lookahead_tiles": _signature_float(RIVER_GRADE_ENERGY_LOOKAHEAD_TILES),
		"grade_energy_smooth_radius_tiles": RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES,
		"grade_energy_reference_grade": _signature_float(RIVER_GRADE_ENERGY_REFERENCE_GRADE),
		"neutral_bend_bias_value": _signature_float(RIVER_NEUTRAL_BEND_BIAS_VALUE),
		"bend_bias_source_sampling": "vertex_aligned_longitudinal_lerp",
		"bend_bias_lateral_sampling": "vertex_aligned_cross_river_ratio",
		"bend_bias_lookahead_tiles": _signature_float(RIVER_BEND_BIAS_LOOKAHEAD_TILES),
		"bend_bias_smooth_radius_tiles": RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES,
		"bend_bias_reference_radians": _signature_float(RIVER_BEND_BIAS_REFERENCE_RADIANS),
		"flat_foam_support_value": _signature_float(RIVER_FLAT_FOAM_SUPPORT_VALUE),
		"flat_pressure_support_value": _signature_float(RIVER_FLAT_PRESSURE_SUPPORT_VALUE),
		"near_neutral_threshold": _signature_float(WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD),
		"step_count": step_count,
		"uv2_sides": WaterHelperMethods.calculate_side(step_count)
	}


func _bake_data_matches_current_source() -> bool:
	var current_signature := get_bake_source_signature()
	if current_signature.is_empty():
		return false
	if bake_data.has_method("has_matching_source_signature"):
		return bool(bake_data.call("has_matching_source_signature", current_signature))
	var stored_signature = bake_data.get("source_signature")
	return typeof(stored_signature) == TYPE_DICTIONARY and not stored_signature.is_empty() and stored_signature == current_signature


func _set_valid_flowmap(value: bool) -> void:
	valid_flowmap = value
	set_materials("i_valid_flowmap", valid_flowmap)
	if is_inside_tree():
		update_configuration_warnings()


func _get_valid_flowmap_shader_state(default_value: bool) -> bool:
	var shader_value = null
	if _material != null:
		shader_value = _material.get_shader_parameter("i_valid_flowmap")
	if shader_value == null and _debug_material != null:
		shader_value = _debug_material.get_shader_parameter("i_valid_flowmap")
	if shader_value == null:
		return default_value
	return bool(shader_value)


func _on_geometry_property_changed(notify_river: bool) -> void:
	if _first_enter_tree:
		return
	_invalidate_generated_bake(true, notify_river)


func _on_bake_property_changed() -> void:
	if _first_enter_tree:
		return
	_invalidate_generated_bake(false, false)


func _invalidate_generated_bake(regenerate_geometry: bool, notify_river: bool) -> void:
	_set_valid_flowmap(false)
	if regenerate_geometry:
		_generate_river()
	if notify_river:
		emit_signal("river_changed")


func _set_baking_property(property_name: String, value: Variant) -> bool:
	match property_name:
		"baking_resolution":
			baking_resolution = int(value)
		"baking_raycast_distance":
			baking_raycast_distance = float(value)
		"baking_raycast_layers":
			baking_raycast_layers = int(value)
		"baking_dilate":
			baking_dilate = float(value)
		"baking_flowmap_blur":
			baking_flowmap_blur = float(value)
		"baking_foam_cutoff":
			baking_foam_cutoff = float(value)
		"baking_foam_offset":
			baking_foam_offset = float(value)
		"baking_foam_blur":
			baking_foam_blur = float(value)
		_:
			return false
	return true


func _get_baking_property(property_name: String) -> Variant:
	match property_name:
		"baking_resolution":
			return baking_resolution
		"baking_raycast_distance":
			return baking_raycast_distance
		"baking_raycast_layers":
			return baking_raycast_layers
		"baking_dilate":
			return baking_dilate
		"baking_flowmap_blur":
			return baking_flowmap_blur
		"baking_foam_cutoff":
			return baking_foam_cutoff
		"baking_foam_offset":
			return baking_foam_offset
		"baking_foam_blur":
			return baking_foam_blur
	return null


func _calculate_step_count() -> int:
	if curve == null:
		return 1
	var average_width := _get_average_width()
	return int(max(1.0, round(curve.get_baked_length() / average_width)))


func _signature_float(value: float) -> float:
	return snappedf(value, SOURCE_SIGNATURE_FLOAT_STEP)


func _vector3_signature(value: Vector3) -> Array:
	return [
		_signature_float(value.x),
		_signature_float(value.y),
		_signature_float(value.z)
	]


func _make_bake_revision() -> String:
	return str(Time.get_unix_time_from_system()) + ":" + str(Time.get_ticks_usec())


func _get_mesh_global_aabb(instance: MeshInstance3D) -> AABB:
	if instance == null:
		return AABB()
	return instance.global_transform * instance.get_aabb()


func _get_bake_settings(source_texture_size: Vector2i, texture_size: Vector2i, content_rect: Rect2i, texture_layout: String) -> Dictionary:
	return {
		"shape_step_length_divs": shape_step_length_divs,
		"shape_step_width_divs": shape_step_width_divs,
		"shape_smoothness": shape_smoothness,
		"baking_resolution": baking_resolution,
		"baking_raycast_distance": baking_raycast_distance,
		"baking_raycast_layers": baking_raycast_layers,
		"baking_dilate": baking_dilate,
		"baking_flowmap_blur": baking_flowmap_blur,
		"baking_foam_cutoff": baking_foam_cutoff,
		"baking_foam_offset": baking_foam_offset,
		"baking_foam_blur": baking_foam_blur,
		"bake_generation_behavior": _sanitize_bake_generation_behavior(bake_generation_behavior),
		"downstream_baseline_strength": RIVER_DOWNSTREAM_BASELINE_STRENGTH,
		"obstacle_avoidance_strength": RIVER_OBSTACLE_AVOIDANCE_STRENGTH,
		"obstacle_avoidance_influence_start": RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_START,
		"obstacle_avoidance_influence_full": RIVER_OBSTACLE_AVOIDANCE_INFLUENCE_FULL,
		"obstacle_avoidance_sdf_radius_tiles": RIVER_OBSTACLE_AVOIDANCE_SDF_RADIUS_TILES,
		"obstacle_avoidance_sdf_blur_tiles": RIVER_OBSTACLE_AVOIDANCE_SDF_BLUR_TILES,
		"obstacle_avoidance_upstream_lookahead_tiles": RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_LOOKAHEAD_TILES,
		"obstacle_avoidance_upstream_strength": RIVER_OBSTACLE_AVOIDANCE_UPSTREAM_STRENGTH,
		"obstacle_avoidance_min_downstream_alignment": RIVER_OBSTACLE_AVOIDANCE_MIN_DOWNSTREAM_ALIGNMENT,
		"obstacle_avoidance_bank_friction_suppression": RIVER_OBSTACLE_AVOIDANCE_BANK_FRICTION_SUPPRESSION,
		"obstacle_avoidance_hard_boundary_steering_gate": RIVER_OBSTACLE_AVOIDANCE_HARD_BOUNDARY_STEERING_GATE,
		"obstacle_feature_support_start": RIVER_OBSTACLE_FEATURE_SUPPORT_START,
		"obstacle_feature_support_full": RIVER_OBSTACLE_FEATURE_SUPPORT_FULL,
		"obstacle_feature_facing_start": RIVER_OBSTACLE_FEATURE_FACING_START,
		"obstacle_feature_facing_full": RIVER_OBSTACLE_FEATURE_FACING_FULL,
		"obstacle_feature_pillow_support_start": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START,
		"obstacle_feature_pillow_support_full": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL,
		"obstacle_feature_pillow_contact_search_tiles": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES,
		"obstacle_feature_pillow_contact_gate_start": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START,
		"obstacle_feature_pillow_contact_gate_full": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL,
		"obstacle_feature_pillow_anchor_source": "terrain_contact_features.b_direct_search",
		"obstacle_feature_pillow_bank_response_role": "weak_context_only_not_anchor",
		"obstacle_feature_wake_length_tiles": RIVER_OBSTACLE_FEATURE_WAKE_LENGTH_TILES,
		"obstacle_feature_wake_width_tiles": RIVER_OBSTACLE_FEATURE_WAKE_WIDTH_TILES,
		"obstacle_feature_side_width_tiles": RIVER_OBSTACLE_FEATURE_SIDE_WIDTH_TILES,
		"obstacle_feature_wake_start": RIVER_OBSTACLE_FEATURE_WAKE_START,
		"obstacle_feature_wake_full": RIVER_OBSTACLE_FEATURE_WAKE_FULL,
		"obstacle_feature_bank_friction_suppression": RIVER_OBSTACLE_FEATURE_BANK_FRICTION_SUPPRESSION,
		"obstacle_feature_hard_boundary_wake_gate": RIVER_OBSTACLE_FEATURE_HARD_BOUNDARY_WAKE_GATE,
		"obstacle_feature_confidence_start": RIVER_OBSTACLE_FEATURE_CONFIDENCE_START,
		"obstacle_feature_confidence_full": RIVER_OBSTACLE_FEATURE_CONFIDENCE_FULL,
		"obstacle_feature_eddy_line_edge_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_START,
		"obstacle_feature_eddy_line_edge_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_FULL,
		"obstacle_feature_eddy_line_wake_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_START,
		"obstacle_feature_eddy_line_wake_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_FULL,
		"obstacle_feature_eddy_line_hard_gate_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_START,
		"obstacle_feature_eddy_line_hard_gate_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_FULL,
		"obstacle_feature_eddy_line_energy_gate_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_START,
		"obstacle_feature_eddy_line_energy_gate_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_FULL,
		"obstacle_feature_eddy_line_support_reject_start": RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_START,
		"obstacle_feature_eddy_line_support_reject_full": RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_FULL,
		"terrain_contact_full_band": RIVER_TERRAIN_CONTACT_FULL_BAND,
		"terrain_contact_fade_distance": RIVER_TERRAIN_CONTACT_FADE_DISTANCE,
		"terrain_contact_shallow_full_depth": RIVER_TERRAIN_SHALLOW_FULL_DEPTH,
		"terrain_contact_shallow_fade_depth": RIVER_TERRAIN_SHALLOW_FADE_DEPTH,
		"terrain_contact_protrusion_fade_height": RIVER_TERRAIN_PROTRUSION_FADE_HEIGHT,
		"terrain_contact_protrusion_full_height": RIVER_TERRAIN_PROTRUSION_FULL_HEIGHT,
		"terrain_contact_raycast_up_offset": RIVER_TERRAIN_CONTACT_RAYCAST_UP_OFFSET,
		"terrain_contact_raycast_down_distance": RIVER_TERRAIN_CONTACT_RAYCAST_DOWN_DISTANCE,
		"terrain_contact_hterrain_source_confidence": RIVER_TERRAIN_HTERRAIN_SOURCE_CONFIDENCE,
		"terrain_contact_physics_source_confidence": RIVER_TERRAIN_PHYSICS_SOURCE_CONFIDENCE,
		"terrain_contact_supersamples": RIVER_TERRAIN_CONTACT_SUPERSAMPLES,
		"terrain_contact_source_blend_band": RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND,
		"terrain_contact_edge_smooth_passes": RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES,
		"bank_response_probe_tiles": RIVER_BANK_RESPONSE_PROBE_TILES,
		"bank_response_friction_contact_weight": RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
		"bank_response_friction_shallow_weight": RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
		"bank_response_hard_protrusion_weight": RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
		"bank_response_outside_bend_start": RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
		"bank_response_outside_bend_full": RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
		"bank_response_inside_bend_start": RIVER_BANK_RESPONSE_INSIDE_BEND_START,
		"bank_response_inside_bend_full": RIVER_BANK_RESPONSE_INSIDE_BEND_FULL,
		"blank_support_value": RIVER_BLANK_SUPPORT_VALUE,
		"neutral_grade_energy_value": RIVER_NEUTRAL_GRADE_ENERGY_VALUE,
		"grade_energy_lookahead_tiles": RIVER_GRADE_ENERGY_LOOKAHEAD_TILES,
		"grade_energy_smooth_radius_tiles": RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES,
		"grade_energy_reference_grade": RIVER_GRADE_ENERGY_REFERENCE_GRADE,
		"neutral_bend_bias_value": RIVER_NEUTRAL_BEND_BIAS_VALUE,
		"bend_bias_lookahead_tiles": RIVER_BEND_BIAS_LOOKAHEAD_TILES,
		"bend_bias_smooth_radius_tiles": RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES,
		"bend_bias_reference_radians": RIVER_BEND_BIAS_REFERENCE_RADIANS,
		"flat_foam_support_value": RIVER_FLAT_FOAM_SUPPORT_VALUE,
		"flat_pressure_support_value": RIVER_FLAT_PRESSURE_SUPPORT_VALUE,
		"near_neutral_threshold": WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
		"filtered_feature_edge_sync_depth_pixels": RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS,
		"uv2_sides": _uv2_sides,
		"source_texture_size": source_texture_size,
		"texture_size": texture_size,
		"content_rect": content_rect,
		"texture_layout": texture_layout
	}


# Signal Methods
func properties_changed() -> void:
	emit_signal("river_changed")
