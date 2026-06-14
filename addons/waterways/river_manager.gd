# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Node3D

const WaterHelperMethods = preload("./water_helper_methods.gd")
const RiverBakeDataResource = preload("res://addons/waterways/resources/river_bake_data.gd")
const RiverRippleMaterialOwner = preload("res://addons/waterways/river_ripple_material_owner.gd")
const RiverEditorValidation = preload("res://addons/waterways/river_editor_validation.gd")
const RiverFlowmapBaker = preload("res://addons/waterways/river_flowmap_baker.gd")
const RiverBakeConstants = preload("res://addons/waterways/river_bake_constants.gd")

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

const BAKE_CHANNEL_FLAT_EPSILON := 0.002
const BAKE_CHANNEL_LOW_CONTRAST_EPSILON := 0.03
const BAKE_CHANNEL_SATURATION_EPSILON := 0.02
# v28 (2026-06-12, refactor track R1): R1.1 SDF-steering metadata removal,
# R1.2 signature-gap keys, R1.3 occupancy serialization; retroactively covers
# the R0.5 first-tile UV2 margin fix, which changed multi-tile bake content
# without a bump. All pre-v28 bakes are stale and need a rebake.
const RIVER_BAKE_SOURCE_SIGNATURE_VERSION := 28
# Shader parameters that displace VERTEX.y upward; their sum is the headroom
# added to the mesh's custom AABB.
const DISPLACEMENT_AABB_SHADER_PARAMETERS: Array[String] = ["pillow_terrain_height", "pillow_obstruction_height"]
const RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS := 1
const RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE := "downstream_baseline_collision_support"
const RIVER_FLOW_GENERATION_BEHAVIOR_CURVE_ONLY := "curve_only"
const RIVER_FLOW_GENERATION_BEHAVIOR_LEGACY_COLLISION_ONLY := "legacy_collision_only"
const RIVER_DOWNSTREAM_BASELINE_STRENGTH := 0.25
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
const BAKING_PROPERTY_DESCRIPTORS := [
	{
		name = "baking_resolution",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "64, 128, 256, 512, 1024",
		sanitize = "int_range",
		min = RIVER_BAKE_RESOLUTION_MIN,
		max = RIVER_BAKE_RESOLUTION_MAX
	},
	{
		name = "baking_raycast_distance",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0, 100.0",
		sanitize = "float_range",
		min = BAKING_RAYCAST_DISTANCE_MIN,
		max = BAKING_RAYCAST_DISTANCE_MAX
	},
	{
		name = "baking_raycast_layers",
		type = TYPE_INT,
		hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
		sanitize = "int_range",
		min = BAKING_RAYCAST_LAYERS_MIN,
		max = BAKING_RAYCAST_LAYERS_MAX
	},
	{
		name = "baking_dilate",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0, 1.0",
		sanitize = "float_range",
		min = BAKING_NORMALIZED_MIN,
		max = BAKING_NORMALIZED_MAX
	},
	{
		name = "baking_flowmap_blur",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0, 1.0",
		sanitize = "float_range",
		min = BAKING_NORMALIZED_MIN,
		max = BAKING_NORMALIZED_MAX
	},
	{
		name = "baking_foam_cutoff",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0, 1.0",
		sanitize = "float_range",
		min = BAKING_NORMALIZED_MIN,
		max = BAKING_NORMALIZED_MAX
	},
	{
		name = "baking_foam_offset",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0, 1.0",
		sanitize = "float_range",
		min = BAKING_NORMALIZED_MIN,
		max = BAKING_NORMALIZED_MAX
	},
	{
		name = "baking_foam_blur",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0, 1.0",
		sanitize = "float_range",
		min = BAKING_NORMALIZED_MIN,
		max = BAKING_NORMALIZED_MAX
	}
]


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
		var sanitized_value := int(_sanitize_baking_property_value("baking_resolution", value))
		if sanitized_value == baking_resolution:
			return
		baking_resolution = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_raycast_distance := 10.0:
	set(value):
		var sanitized_value := float(_sanitize_baking_property_value("baking_raycast_distance", value))
		if is_equal_approx(sanitized_value, baking_raycast_distance):
			return
		baking_raycast_distance = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_raycast_layers := 1:
	set(value):
		var sanitized_value := int(_sanitize_baking_property_value("baking_raycast_layers", value))
		if sanitized_value == baking_raycast_layers:
			return
		baking_raycast_layers = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_dilate := 0.6:
	set(value):
		var sanitized_value := float(_sanitize_baking_property_value("baking_dilate", value))
		if is_equal_approx(sanitized_value, baking_dilate):
			return
		baking_dilate = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_flowmap_blur := 0.04:
	set(value):
		var sanitized_value := float(_sanitize_baking_property_value("baking_flowmap_blur", value))
		if is_equal_approx(sanitized_value, baking_flowmap_blur):
			return
		baking_flowmap_blur = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_foam_cutoff := 0.9:
	set(value):
		var sanitized_value := float(_sanitize_baking_property_value("baking_foam_cutoff", value))
		if is_equal_approx(sanitized_value, baking_foam_cutoff):
			return
		baking_foam_cutoff = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_foam_offset := 0.1:
	set(value):
		var sanitized_value := float(_sanitize_baking_property_value("baking_foam_offset", value))
		if is_equal_approx(sanitized_value, baking_foam_offset):
			return
		baking_foam_offset = sanitized_value
		if not _suppress_property_change_notifications:
			_on_bake_property_changed()
var baking_foam_blur := 0.02:
	set(value):
		var sanitized_value := float(_sanitize_baking_property_value("baking_foam_blur", value))
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
# Kept for serialized property-list compatibility. RiverFlowmapBaker owns the
# live bake renderer during R6 bakes.
var _flowmap_bake_renderer: Node = null
# Compatibility placeholders keep the full RiverManager property list stable;
# live runtime ripple ownership state lives in RiverRippleMaterialOwner.
var _runtime_ripple_owner_id := 0
var _runtime_ripple_owner_node: Node = null
var _runtime_ripple_original_material: ShaderMaterial = null
var _runtime_ripple_original_debug_material: ShaderMaterial = null
static var _runtime_ripple_material_owners := {}
static var _flowmap_bakers := {}

# river_changed used to update handles when values are changed on script side
# progress_notified used to up progress bar when baking maps
signal river_changed
signal progress_notified

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
		}
	] + _get_baking_property_list_entries() + [
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
			name = "water_occupancy",
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


func _get_baking_property_list_entries() -> Array:
	var entries := []
	for descriptor in BAKING_PROPERTY_DESCRIPTORS:
		var entry := {
			name = String(descriptor.get("name", "")),
			type = int(descriptor.get("type", TYPE_NIL)),
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		}
		if descriptor.has("hint"):
			entry.hint = int(descriptor.get("hint", PROPERTY_HINT_NONE))
		if descriptor.has("hint_string"):
			entry.hint_string = String(descriptor.get("hint_string", ""))
		entries.append(entry)
	return entries


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


# Only dynamic mat_<shader param> properties reach _set/_get: every other
# inspector property is a declared script var (with setter), and Godot resolves
# declared properties before calling these.
func _set(property: StringName, value: Variant) -> bool:
	var property_name := String(property)
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
		if _material == null or _material.shader == null:
			return false
		# Reverts come straight from the live shader's declared defaults
		# (R3.3) - the old hand-mirrored override table held no actual
		# overrides, and ShaderMaterial.property_can_revert never worked here
		# (its remap cache only fills when the material itself is inspected,
		# which this internal material never is).
		var param_name := property_name.trim_prefix("mat_")
		var current_value = _material.get_shader_parameter(param_name)
		if current_value == null:
			return false
		return current_value != RenderingServer.shader_get_parameter_default(_material.shader.get_rid(), param_name)

	return false


func _property_get_revert(property: StringName) -> Variant:
	var property_name := String(property)
	if DEFAULT_PARAMETERS.has(property_name):
		return DEFAULT_PARAMETERS.get(property_name, null)
	if property_name.begins_with("mat_"):
		if _material == null or _material.shader == null:
			return null
		var param_name := property_name.trim_prefix("mat_")
		return RenderingServer.shader_get_parameter_default(_material.shader.get_rid(), param_name)
	return null


func _init() -> void:
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	_filter_renderer = load(FILTER_RENDERER_PATH)
	_get_runtime_ripple_material_owner()

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


# Neutral texel for i_distmap, derived from the shader decode (distance =
# (1-R)*2, pressure = G*2, grade_energy = B, bend_bias = A*2-1) so a null
# dist_pressure yields the same values as the shader's invalid-flowmap
# fallback (0.5, 0.5, 0.0, 0.0). No built-in hint_default_* can express
# this texel, so this code-side binding is the real default.
const RIVER_NEUTRAL_DISTMAP_COLOR := Color(0.75, 0.25, 0.0, 0.5)
# Jacobi pressure seed. Must equal enc(0) of the solve encodings in
# flow_solve_common.gdshaderinc (all three use a 0.5 bias), or the first
# Jacobi pass reads a fictitious pressure field. flow_solve_seed_assert_probe
# asserts this cross-language pairing.
const RIVER_FLOW_PRESSURE_SEED_COLOR := Color(0.5, 0.0, 0.0, 1.0)
static var _neutral_distmap_texture: ImageTexture = null


static func _get_neutral_distmap_texture() -> ImageTexture:
	if _neutral_distmap_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(RIVER_NEUTRAL_DISTMAP_COLOR)
		_neutral_distmap_texture = ImageTexture.create_from_image(image)
	return _neutral_distmap_texture


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
	set_materials("i_distmap", dist_pressure if dist_pressure != null else _get_neutral_distmap_texture())
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_obstacle_features", obstacle_features)
	set_materials("i_terrain_contact_features", terrain_contact_features)
	set_materials("i_bank_response_features", bank_response_features)
	set_materials("i_water_occupancy", water_occupancy)
	set_materials("i_texture_foam_noise", load(FOAM_NOISE_PATH) as Texture2D)


func _exit_tree() -> void:
	_apply_runtime_ripple_material_owner_result(_get_runtime_ripple_material_owner().restore())
	_runtime_ripple_material_owners.erase(get_instance_id())
	_abort_flowmap_bake_on_tree_exit()
	_flowmap_bakers.erase(get_instance_id())


func _abort_flowmap_bake_on_tree_exit() -> void:
	# A scene close mid-bake parks the bake coroutine forever, so the in-progress
	# flag would otherwise stay set and swallow every later bake_texture() request.
	var flowmap_baker = _flowmap_bakers.get(get_instance_id())
	if not _flowmap_bake_in_progress and (flowmap_baker == null or not flowmap_baker.is_running()):
		return
	_flowmap_bake_in_progress = false
	if flowmap_baker != null:
		flowmap_baker.abort()


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
	if index < widths.size():
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
	var result: Dictionary = _get_runtime_ripple_material_owner().apply(owner, _material, _debug_material, parameters)
	if not String(result.get("warning", "")).is_empty():
		push_warning(String(result.get("warning", "")))
	if not bool(result.get("ok", false)):
		return false
	_apply_runtime_ripple_material_owner_result(result)
	return true


func clear_runtime_ripple_material_state(owner: Object) -> void:
	var result: Dictionary = _get_runtime_ripple_material_owner().clear(owner)
	if not String(result.get("warning", "")).is_empty():
		push_warning(String(result.get("warning", "")))
	_apply_runtime_ripple_material_owner_result(result)


func has_runtime_ripple_material_state(owner: Object = null) -> bool:
	return _get_runtime_ripple_material_owner().has_state(owner)


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
	var debug_parameter_names := RiverRippleMaterialOwner.get_shader_parameter_name_set(_debug_material.shader)
	var visible_parameters: Array = RenderingServer.get_shader_parameter_list(_material.shader.get_rid())
	for parameter in visible_parameters:
		var parameter_name := String(parameter.name)
		if debug_parameter_names.has(parameter_name):
			_debug_material.set_shader_parameter(parameter_name, _material.get_shader_parameter(parameter_name))


func _get_runtime_ripple_material_owner():
	var river_id := get_instance_id()
	var material_owner = _runtime_ripple_material_owners.get(river_id)
	if material_owner == null:
		material_owner = RiverRippleMaterialOwner.new()
		_runtime_ripple_material_owners[river_id] = material_owner
	var callback := Callable(self, "_on_runtime_ripple_material_owner_materials_changed")
	if not material_owner.is_connected("materials_changed", callback):
		material_owner.connect("materials_changed", callback)
	return material_owner


func _get_flowmap_baker():
	var river_id := get_instance_id()
	var flowmap_baker = _flowmap_bakers.get(river_id)
	if flowmap_baker == null:
		flowmap_baker = RiverFlowmapBaker.new()
		_flowmap_bakers[river_id] = flowmap_baker
	return flowmap_baker


func _get_flowmap_source_image_config() -> Dictionary:
	return {
		"curve": curve,
		"flow_speeds": flow_speeds.duplicate(),
		"blank_support_value": RIVER_BLANK_SUPPORT_VALUE,
		"neutral_grade_energy_value": RIVER_NEUTRAL_GRADE_ENERGY_VALUE,
		"grade_energy_lookahead_tiles": RIVER_GRADE_ENERGY_LOOKAHEAD_TILES,
		"grade_energy_smooth_radius_tiles": RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES,
		"grade_energy_reference_grade": RIVER_GRADE_ENERGY_REFERENCE_GRADE,
		"neutral_flow_speed_factor": RIVER_NEUTRAL_FLOW_SPEED_FACTOR,
		"flow_speed_factor_min": RIVER_FLOW_SPEED_FACTOR_MIN,
		"flow_speed_factor_max": RIVER_FLOW_SPEED_FACTOR_MAX,
		"neutral_bend_bias_value": RIVER_NEUTRAL_BEND_BIAS_VALUE,
		"bend_bias_lookahead_tiles": RIVER_BEND_BIAS_LOOKAHEAD_TILES,
		"bend_bias_smooth_radius_tiles": RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES,
		"bend_bias_reference_radians": RIVER_BEND_BIAS_REFERENCE_RADIANS
	}


func _apply_runtime_ripple_material_owner_result(result: Dictionary) -> void:
	if not bool(result.get("refresh", false)):
		return
	_material = result.get("visible_material") as ShaderMaterial
	_debug_material = result.get("debug_material") as ShaderMaterial
	_apply_debug_view_material()


func _on_runtime_ripple_material_owner_materials_changed(visible_material: ShaderMaterial, debug_material: ShaderMaterial) -> void:
	_apply_runtime_ripple_material_owner_result({
		"refresh": true,
		"visible_material": visible_material,
		"debug_material": debug_material,
	})


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


func _sanitize_baking_property_value(property_name: String, value: Variant) -> Variant:
	var descriptor := _get_baking_property_descriptor(property_name)
	if descriptor.is_empty():
		return value
	var fallback = DEFAULT_PARAMETERS.get(property_name, value)
	match String(descriptor.get("sanitize", "")):
		"int_range":
			return _sanitize_int_range(property_name, value, int(descriptor.get("min", 0)), int(descriptor.get("max", 0)), int(fallback))
		"float_range":
			return _sanitize_float_range(property_name, value, float(descriptor.get("min", 0.0)), float(descriptor.get("max", 0.0)), float(fallback))
	return value


func _get_baking_property_descriptor(property_name: String) -> Dictionary:
	for descriptor in BAKING_PROPERTY_DESCRIPTORS:
		if String(descriptor.get("name", "")) == property_name:
			return descriptor
	return {}


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
	_set_per_point_channel_without_property_notifications("widths", new_widths)


func _set_flow_speeds_without_property_notifications(new_flow_speeds: Array) -> void:
	_set_per_point_channel_without_property_notifications("flow_speeds", new_flow_speeds)


func _set_per_point_channel_without_property_notifications(channel_name: String, new_values: Array) -> void:
	var was_suppressed := _suppress_property_change_notifications
	_suppress_property_change_notifications = true
	match channel_name:
		"widths":
			widths = new_values
		"flow_speeds":
			flow_speeds = new_values
	_suppress_property_change_notifications = was_suppressed


func _sanitize_flow_speed_array(value: Variant) -> Array:
	return _sanitize_per_point_channel_array("flow_speeds", value)


func _sanitize_flow_speed_value(value: Variant, property_name: String) -> float:
	return _sanitize_per_point_channel_value("flow_speeds", value, property_name)


func _ensure_flow_speed_count_for_curve() -> void:
	_ensure_per_point_channel_count_for_curve("flow_speeds")


func _get_flow_speed_for_point(point_index: int) -> float:
	return _get_per_point_channel_value_for_point("flow_speeds", point_index)


func _any_flow_speed_non_neutral() -> bool:
	for flow_speed_index in flow_speeds.size():
		if not is_equal_approx(_get_flow_speed_for_point(flow_speed_index), RIVER_NEUTRAL_FLOW_SPEED_FACTOR):
			return true
	return false


func _sanitize_width_array(value: Variant) -> Array:
	return _sanitize_per_point_channel_array("widths", value)


func _sanitize_width_value(value: Variant, property_name: String) -> float:
	return _sanitize_per_point_channel_value("widths", value, property_name)


func _ensure_width_count_for_curve() -> void:
	_ensure_per_point_channel_count_for_curve("widths")


func _get_width_for_point(point_index: int) -> float:
	return _get_per_point_channel_value_for_point("widths", point_index)


func _sanitize_per_point_channel_array(channel_name: String, value: Variant) -> Array:
	var sanitized_values := []
	if typeof(value) != TYPE_ARRAY:
		_warn_sanitized_property(channel_name, value, "[]")
		return sanitized_values
	var source_values: Array = value
	for value_index in source_values.size():
		sanitized_values.append(_sanitize_per_point_channel_value(channel_name, source_values[value_index], channel_name + "[" + str(value_index) + "]"))
	return sanitized_values


func _sanitize_per_point_channel_value(channel_name: String, value: Variant, property_name: String) -> float:
	var numeric_value := float(value)
	match channel_name:
		"widths":
			if not _is_finite_number(numeric_value) or numeric_value < WaterHelperMethods.MIN_RIVER_WIDTH:
				_warn_sanitized_property(property_name, value, WaterHelperMethods.MIN_RIVER_WIDTH)
				return WaterHelperMethods.MIN_RIVER_WIDTH
			return numeric_value
		"flow_speeds":
			if not _is_finite_number(numeric_value) or numeric_value < RIVER_FLOW_SPEED_FACTOR_MIN or numeric_value > RIVER_FLOW_SPEED_FACTOR_MAX:
				_warn_sanitized_property(property_name, value, RIVER_NEUTRAL_FLOW_SPEED_FACTOR)
				return RIVER_NEUTRAL_FLOW_SPEED_FACTOR
			return numeric_value
		_:
			_warn_sanitized_property(property_name, value, _get_per_point_channel_seed_default(channel_name))
			return _get_per_point_channel_seed_default(channel_name)


func _ensure_per_point_channel_count_for_curve(channel_name: String) -> void:
	var required_count := 0
	if curve != null:
		required_count = curve.get_point_count()
	if required_count <= 0:
		return
	var values := _get_per_point_channel_values(channel_name)
	if values.is_empty():
		if _should_warn_on_empty_per_point_channel(channel_name):
			_warn_sanitized_property(channel_name, "empty", "default " + channel_name + " values")
		values.append(_get_per_point_channel_seed_default(channel_name))
	while values.size() < required_count:
		if _should_warn_on_padded_per_point_channel(channel_name):
			_warn_sanitized_property(channel_name, "too few entries", "padded to curve point count")
		values.append(values[values.size() - 1])


func _get_per_point_channel_value_for_point(channel_name: String, point_index: int) -> float:
	var values := _get_per_point_channel_values(channel_name)
	if values.is_empty():
		return _get_per_point_channel_empty_fallback(channel_name)
	var value_index: int = clamp(point_index, 0, values.size() - 1)
	return _sanitize_per_point_channel_value(channel_name, values[value_index], channel_name + "[" + str(value_index) + "]")


func _get_per_point_channel_values(channel_name: String) -> Array:
	match channel_name:
		"widths":
			return widths
		"flow_speeds":
			return flow_speeds
	return []


func _get_per_point_channel_seed_default(channel_name: String) -> float:
	match channel_name:
		"widths":
			return 1.0
		"flow_speeds":
			return RIVER_NEUTRAL_FLOW_SPEED_FACTOR
	return 0.0


func _get_per_point_channel_empty_fallback(channel_name: String) -> float:
	match channel_name:
		"widths":
			return WaterHelperMethods.MIN_RIVER_WIDTH
		"flow_speeds":
			return RIVER_NEUTRAL_FLOW_SPEED_FACTOR
	return _get_per_point_channel_seed_default(channel_name)


func _should_warn_on_empty_per_point_channel(channel_name: String) -> bool:
	return channel_name == "widths"


func _should_warn_on_padded_per_point_channel(channel_name: String) -> bool:
	return channel_name == "widths"


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
	var flowmap_baker = _get_flowmap_baker()
	var generation_behavior := _sanitize_bake_generation_behavior(bake_generation_behavior)
	var image := Image.create(int(flowmap_resolution), int(flowmap_resolution), true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	# The image is guaranteed blank here; don't pay a full-resolution pixel scan
	# for stats that are zero by construction.
	var collision_stats: Dictionary = flowmap_baker.make_blank_collision_map_stats(int(flowmap_resolution))
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
		if _is_flowmap_bake_cancelled():
			return
	else:
		WaterHelperMethods.reset_all_colliders(get_tree().root)
		emit_signal("progress_notified", 0.0, "Calculating Collisions (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
		await get_tree().process_frame
		if _is_flowmap_bake_cancelled():
			return
		image = await WaterHelperMethods.generate_collisionmap(image, mesh_instance, baking_raycast_distance, baking_raycast_layers, _steps, shape_step_length_divs, shape_step_width_divs, self)
		if _is_flowmap_bake_cancelled():
			return
		if image == null or image.is_empty():
			flowmap_baker.warn_if_collision_map_empty(image, _uses_downstream_baseline_generation(generation_behavior), support_fallback_reason, Callable(self, "_push_baker_warning"))
			_finish_flowmap_bake_after_failure()
			return
		collision_stats = flowmap_baker.get_collision_map_stats(image)
		if _uses_downstream_baseline_generation(generation_behavior) and int(collision_stats.get("hit_pixel_count", 0)) == 0:
			support_fallback_reason = "no_collision_hits"
		flowmap_baker.warn_if_collision_map_empty(image, _uses_downstream_baseline_generation(generation_behavior), support_fallback_reason, Callable(self, "_push_baker_warning"))
	
	emit_signal("progress_notified", 0.95, "Applying filters (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	await get_tree().process_frame
	if _is_flowmap_bake_cancelled():
		return
	
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
		downstream_baseline_with_margins_texture = flowmap_baker.create_margin_texture(downstream_baseline, flowmap_resolution, margin, _steps)
	var blank_support_with_margins_texture: Texture2D = flowmap_baker.create_margin_texture(flowmap_baker.create_blank_support_source_image(int(flowmap_resolution), _get_flowmap_source_image_config()), flowmap_resolution, margin, _steps)
	var blank_obstacle_features_with_margins_texture: Texture2D = flowmap_baker.create_margin_texture(flowmap_baker.create_blank_obstacle_feature_source_image(int(flowmap_resolution)), flowmap_resolution, margin, _steps)
	var blank_bank_response_features_with_margins_texture: Texture2D = flowmap_baker.create_margin_texture(flowmap_baker.create_blank_bank_response_feature_source_image(int(flowmap_resolution)), flowmap_resolution, margin, _steps)
	var terrain_contact_source := await WaterHelperMethods.generate_terrain_contact_feature_map(
		flowmap_baker.create_blank_terrain_contact_feature_source_image(int(flowmap_resolution)),
		mesh_instance,
		baking_raycast_layers,
		_steps,
		shape_step_length_divs,
		shape_step_width_divs,
		self,
		_get_terrain_contact_feature_settings()
	)
	if _is_flowmap_bake_cancelled():
		return
	if terrain_contact_source == null or terrain_contact_source.is_empty():
		_push_baker_warning("Waterways: River Flow & Foam bake failed while generating terrain contact source. The bake was aborted before temporary renderer setup.")
		_finish_flowmap_bake_after_failure()
		return
	WaterHelperMethods.smooth_uv2_tile_channels(terrain_contact_source, _uv2_sides, _steps, RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES)
	var terrain_contact_with_margins: Image = flowmap_baker.create_margin_image(terrain_contact_source, flowmap_resolution, margin, _steps)
	var terrain_contact_with_margins_texture := ImageTexture.create_from_image(terrain_contact_with_margins)
	var curve_source_config := _get_flowmap_source_image_config()
	var grade_energy_with_margins_texture: Texture2D = flowmap_baker.create_margin_texture(flowmap_baker.create_curve_grade_energy_source_image(int(flowmap_resolution), _uv2_sides, _steps, curve_source_config), flowmap_resolution, margin, _steps)
	var bend_bias_with_margins_texture: Texture2D = flowmap_baker.create_margin_texture(flowmap_baker.create_curve_bend_bias_source_image(int(flowmap_resolution), _uv2_sides, _steps, curve_source_config), flowmap_resolution, margin, _steps)
	# Authored per-point flow speed: only built when any point deviates from
	# neutral, so default rivers skip the extra scale pass entirely.
	var flow_speed_with_margins_texture: Texture2D = null
	if _any_flow_speed_non_neutral():
		flow_speed_with_margins_texture = flowmap_baker.create_margin_texture(flowmap_baker.create_curve_flow_speed_source_image(int(flowmap_resolution), _uv2_sides, _steps, _get_flowmap_source_image_config()), flowmap_resolution, margin, _steps)

	# Create correctly tiling noise for A channel
	var noise_texture := load(FLOW_OFFSET_NOISE_TEXTURE_PATH) as Texture2D
	var noise_with_tiling: Image = flowmap_baker.create_tiled_flow_offset_noise(noise_texture, _uv2_sides)
	var tiled_noise := ImageTexture.create_from_image(noise_with_tiling)

	var flow_pressure_blur_amount = 0.04 / float(_uv2_sides) * flowmap_resolution
	var dilate_amount = baking_dilate / float(_uv2_sides)
	var flowmap_blur_amount = baking_flowmap_blur / float(_uv2_sides) * flowmap_resolution
	var foam_offset_amount = baking_foam_offset / float(_uv2_sides)
	var foam_blur_amount = baking_foam_blur / float(_uv2_sides) * flowmap_resolution
	
	var support_fallback_applied := not support_fallback_reason.is_empty()
	var filter_pass_result: Dictionary = await flowmap_baker.run_filter_pass_sequence(
		{
			"filter_renderer_scene": _filter_renderer,
			"renderer_parent": mesh_instance,
			"warning_callback": Callable(self, "_push_baker_warning"),
			"flowmap_resolution": flowmap_resolution,
			"uv2_sides": _uv2_sides,
			"steps": _steps,
			"margin": margin,
			"bake_atlas_columns": bake_atlas_columns,
			"generation_behavior": generation_behavior,
			"support_fallback_reason": support_fallback_reason,
			"support_fallback_notice": Callable(self, "_print_curve_support_fallback_notice"),
			"uses_obstacle_avoidance_generation": _uses_obstacle_avoidance_generation(generation_behavior),
			"collision_source_image": image,
			"downstream_baseline_with_margins_texture": downstream_baseline_with_margins_texture,
			"blank_support_with_margins_texture": blank_support_with_margins_texture,
			"blank_obstacle_features_with_margins_texture": blank_obstacle_features_with_margins_texture,
			"blank_bank_response_features_with_margins_texture": blank_bank_response_features_with_margins_texture,
			"terrain_contact_source": terrain_contact_source,
			"terrain_contact_with_margins_texture": terrain_contact_with_margins_texture,
			"grade_energy_with_margins_texture": grade_energy_with_margins_texture,
			"bend_bias_with_margins_texture": bend_bias_with_margins_texture,
			"flow_speed_with_margins_texture": flow_speed_with_margins_texture,
			"tiled_noise": tiled_noise,
			"flow_pressure_blur_amount": flow_pressure_blur_amount,
			"dilate_amount": dilate_amount,
			"flowmap_blur_amount": flowmap_blur_amount,
			"foam_offset_amount": foam_offset_amount,
			"foam_cutoff": baking_foam_cutoff,
			"foam_blur_amount": foam_blur_amount,
			"occupancy_ramp_tiles": RIVER_OCCUPANCY_RAMP_TILES,
			"occupancy_protrusion_threshold": RIVER_OCCUPANCY_PROTRUSION_THRESHOLD,
			"occupancy_protrusion_confidence_min": RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN,
			"flow_projection_strides": RIVER_FLOW_PROJECTION_STRIDES.duplicate(),
			"flow_projection_iterations_per_stride": RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE,
			"flow_tangency_passes": RIVER_FLOW_TANGENCY_PASSES,
			"flow_pressure_seed_color": RIVER_FLOW_PRESSURE_SEED_COLOR,
			"flow_speed_factor_max": RIVER_FLOW_SPEED_FACTOR_MAX,
			"obstacle_feature_support_start": RIVER_OBSTACLE_FEATURE_SUPPORT_START,
			"obstacle_feature_support_full": RIVER_OBSTACLE_FEATURE_SUPPORT_FULL,
			"obstacle_feature_facing_start": RIVER_OBSTACLE_FEATURE_FACING_START,
			"obstacle_feature_facing_full": RIVER_OBSTACLE_FEATURE_FACING_FULL,
			"obstacle_feature_pillow_support_start": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START,
			"obstacle_feature_pillow_support_full": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL,
			"obstacle_feature_pillow_contact_search_tiles": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES,
			"obstacle_feature_pillow_contact_gate_start": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START,
			"obstacle_feature_pillow_contact_gate_full": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL,
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
			"bank_response_feature_settings": _get_bank_response_feature_settings(),
			"bank_response_probe_tiles": RIVER_BANK_RESPONSE_PROBE_TILES,
			"bank_response_friction_contact_weight": RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
			"bank_response_friction_shallow_weight": RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
			"bank_response_hard_protrusion_weight": RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
			"bank_response_outside_bend_start": RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
			"bank_response_outside_bend_full": RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
			"bank_response_inside_bend_start": RIVER_BANK_RESPONSE_INSIDE_BEND_START,
			"bank_response_inside_bend_full": RIVER_BANK_RESPONSE_INSIDE_BEND_FULL
		},
		Callable(self, "_emit_flowmap_bake_progress"),
		Callable(self, "_is_flowmap_bake_cancelled")
	)
	if not bool(filter_pass_result.get("ok", false)):
		_finish_flowmap_bake_after_failure()
		return

	support_fallback_applied = bool(filter_pass_result.get("support_fallback_applied", support_fallback_applied))
	var run_collision_support_filters := bool(filter_pass_result.get("collision_support_filters_ran", not support_fallback_applied))
	var obstacle_avoidance_applied := bool(filter_pass_result.get("obstacle_avoidance_applied", false))
	var flow_projected_applied := bool(filter_pass_result.get("flow_projected", false))
	var image_postprocess_result: Dictionary = flowmap_baker.process_filter_pass_images(
		{
			"warning_callback": Callable(self, "_push_baker_warning"),
			"diagnostic_callback": Callable(self, "_print_baker_diagnostic"),
			"flowmap_resolution": flowmap_resolution,
			"uv2_sides": _uv2_sides,
			"steps": _steps,
			"margin": margin,
			"flow_foam_noise_texture": filter_pass_result.get("flow_foam_noise_texture") as Texture2D,
			"dist_pressure_texture": filter_pass_result.get("dist_pressure_texture") as Texture2D,
			"obstacle_features_texture": filter_pass_result.get("obstacle_feature_mask") as Texture2D,
			"terrain_contact_with_margins_image": terrain_contact_with_margins,
			"terrain_contact_with_margins_texture": terrain_contact_with_margins_texture,
			"bank_response_features_texture": filter_pass_result.get("bank_response_feature_mask") as Texture2D,
			"water_occupancy_texture": filter_pass_result.get("water_occupancy_mask") as Texture2D,
			"generation_behavior": generation_behavior,
			"uses_downstream_baseline_generation": _uses_downstream_baseline_generation(generation_behavior),
			"support_fallback_applied": support_fallback_applied,
			"support_fallback_reason": support_fallback_reason,
			"collision_probe_skipped": collision_probe_skipped,
			"collision_support_filters_ran": run_collision_support_filters,
			"obstacle_avoidance_applied": obstacle_avoidance_applied,
			"flow_projected": flow_projected_applied,
			"collision_stats": collision_stats,
			"flat_foam_support_value": RIVER_FLAT_FOAM_SUPPORT_VALUE,
			"flat_pressure_support_value": RIVER_FLAT_PRESSURE_SUPPORT_VALUE,
			"near_neutral_threshold": WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
			"filtered_feature_edge_sync_depth_pixels": RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS,
			"bake_channel_flat_epsilon": BAKE_CHANNEL_FLAT_EPSILON,
			"bake_channel_low_contrast_epsilon": BAKE_CHANNEL_LOW_CONTRAST_EPSILON,
			"bake_channel_saturation_epsilon": BAKE_CHANNEL_SATURATION_EPSILON
		}
	)
	if not bool(image_postprocess_result.get("ok", false)):
		_finish_flowmap_bake_after_failure()
		return
	_apply_flowmap_bake_result(image_postprocess_result)


func _emit_flowmap_bake_progress(percentage: float, label: String) -> void:
	emit_signal("progress_notified", percentage, label)


func _is_flowmap_bake_cancelled() -> bool:
	if not _flowmap_bake_in_progress:
		return true
	if is_queued_for_deletion() or not is_inside_tree():
		return true
	if mesh_instance == null or not is_instance_valid(mesh_instance):
		return true
	if mesh_instance.is_queued_for_deletion() or not mesh_instance.is_inside_tree():
		return true
	return false


func _cleanup_bake_renderer(renderer_instance: Node) -> void:
	if renderer_instance == _flowmap_bake_renderer:
		_flowmap_bake_renderer = null
	if renderer_instance == null or not is_instance_valid(renderer_instance):
		return
	if renderer_instance.get_parent() != null:
		renderer_instance.get_parent().remove_child(renderer_instance)
	renderer_instance.queue_free()


func _finish_flowmap_bake_after_failure() -> void:
	_clear_flowmap_bake_request()
	emit_signal("progress_notified", 100.0, "finished")
	update_configuration_warnings()


func _apply_flowmap_bake_result(result: Dictionary) -> void:
	flow_foam_noise = result.get("flow_foam_noise_texture") as Texture2D
	dist_pressure = result.get("dist_pressure_texture") as Texture2D
	obstacle_features = result.get("obstacle_features_texture") as Texture2D
	terrain_contact_features = result.get("terrain_contact_features_texture") as Texture2D
	bank_response_features = result.get("bank_response_features_texture") as Texture2D
	water_occupancy = result.get("water_occupancy_texture") as Texture2D
	_write_bake_data(result)
	var storage_result := WaterHelperMethods.save_river_bake_data(self, bake_data)
	_apply_bake_data()

	var bake_diagnostics: Dictionary = result.get("bake_diagnostics", {})
	var flow_projected_applied := bool(bake_diagnostics.get("flow_projected", false))
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure if dist_pressure != null else _get_neutral_distmap_texture())
	set_materials("i_obstacle_features", obstacle_features)
	set_materials("i_terrain_contact_features", terrain_contact_features)
	set_materials("i_bank_response_features", bank_response_features)
	set_materials("i_water_occupancy", water_occupancy)
	set_materials("i_flow_projected", flow_projected_applied)
	set_materials("i_valid_flowmap", true)
	set_materials("i_uv2_sides", _uv2_sides)
	valid_flowmap = true
	_clear_flowmap_bake_request()
	emit_signal("progress_notified", 100.0, "finished")
	var texture_size: Vector2i = result.get("padded_texture_size", Vector2i.ZERO)
	_print_bake_save_notice(texture_size, storage_result)
	update_configuration_warnings()


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


func _push_baker_warning(message: String) -> void:
	push_warning(message)


func _print_baker_diagnostic(message: String) -> void:
	print(message)


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


func _has_unsaved_generated_textures() -> bool:
	if flow_foam_noise == null and dist_pressure == null and obstacle_features == null and terrain_contact_features == null and bank_response_features == null and water_occupancy == null:
		return false
	return not WaterHelperMethods.has_external_bake_path(bake_data)


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
	var validator := RiverEditorValidation.new()
	validator.validate_data_textures(_make_editor_validation_context())


func validate_filter_renderer() -> void:
	var validator := RiverEditorValidation.new()
	await validator.validate_filter_renderer(_make_editor_validation_context())


func _make_editor_validation_context() -> Dictionary:
	return {
		"flow_foam_noise": flow_foam_noise,
		"dist_pressure": dist_pressure,
		"obstacle_features": obstacle_features,
		"terrain_contact_features": terrain_contact_features,
		"bank_response_features": bank_response_features,
		"bake_data": bake_data,
		"uv2_sides": _uv2_sides,
		"step_count": _calculate_step_count(),
		"filter_renderer_scene": _filter_renderer,
		"renderer_parent": self,
		"cleanup_renderer": Callable(self, "_cleanup_bake_renderer"),
	}


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
	set_materials("i_distmap", dist_pressure if dist_pressure != null else _get_neutral_distmap_texture())
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


func _write_bake_data(result: Dictionary) -> void:
	var data := _ensure_bake_data()
	var texture_layout := RiverBakeDataResource.TEXTURE_LAYOUT_PADDED_UV2_ATLAS
	var texture_size: Vector2i = result.get("padded_texture_size", Vector2i.ZERO)
	var source_texture_size: Vector2i = result.get("source_texture_size", texture_size)
	var content_rect: Rect2i = result.get("content_rect", Rect2i())
	var flow_vector_diagnostics: Dictionary = result.get("flow_vector_diagnostics", {})
	var generation_behavior := String(result.get("generation_behavior", RIVER_FLOW_GENERATION_BEHAVIOR_DOWNSTREAM_BASELINE))
	var foam_support_reduced := bool(result.get("foam_support_reduced", false))
	var pressure_support_reduced := bool(result.get("pressure_support_reduced", false))
	var bake_diagnostics: Dictionary = result.get("bake_diagnostics", {})
	var sanitized_generation_behavior := _sanitize_bake_generation_behavior(generation_behavior)
	var source_kind := _get_bake_source_kind(sanitized_generation_behavior)
	var collision_stats: Dictionary = bake_diagnostics.get("collision_stats", {})
	var occupied_stats: Dictionary = flow_vector_diagnostics.get("occupied", {})
	var grade_energy_stats: Dictionary = bake_diagnostics.get("grade_energy_stats", {})
	var bend_bias_stats: Dictionary = bake_diagnostics.get("bend_bias_stats", {})
	var obstacle_feature_stats: Dictionary = bake_diagnostics.get("obstacle_feature_stats", {})
	var terrain_contact_feature_stats: Dictionary = bake_diagnostics.get("terrain_contact_feature_stats", {})
	var bank_response_feature_stats: Dictionary = bake_diagnostics.get("bank_response_feature_stats", {})
	var source_metadata := RiverBakeConstants.build_source_metadata({
		"bake_revision": _make_bake_revision(),
		"generation_behavior": sanitized_generation_behavior,
		"generation_mode": _get_generation_mode_label(sanitized_generation_behavior),
		"downstream_baseline_applied": _uses_downstream_baseline_generation(sanitized_generation_behavior),
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
		"obstacle_feature_stats": obstacle_feature_stats.duplicate(true),
		"terrain_contact_feature_stats": terrain_contact_feature_stats.duplicate(true),
		"bank_response_feature_stats": bank_response_feature_stats.duplicate(true),
		"support_fallback_applied": bool(bake_diagnostics.get("support_fallback_applied", false)),
		"support_fallback_reason": String(bake_diagnostics.get("support_fallback_reason", "")),
		"no_collider_curve_only_fallback": String(bake_diagnostics.get("support_fallback_reason", "")) == "no_collision_hits",
		"grade_energy_stats": grade_energy_stats.duplicate(true),
		"bend_bias_stats": bend_bias_stats.duplicate(true),
		"flow_speed_scaled": _any_flow_speed_non_neutral(),
		"flat_foam_support_reduced": foam_support_reduced,
		"flat_pressure_support_reduced": pressure_support_reduced,
		"flow_vector_diagnostics": flow_vector_diagnostics.duplicate(true),
	})
	data.flow_foam_noise = result.get("flow_foam_noise_texture") as Texture2D
	data.dist_pressure = result.get("dist_pressure_texture") as Texture2D
	data.obstacle_features = result.get("obstacle_features_texture") as Texture2D
	data.terrain_contact_features = result.get("terrain_contact_features_texture") as Texture2D
	data.bank_response_features = result.get("bank_response_features_texture") as Texture2D
	data.water_occupancy = result.get("water_occupancy_texture") as Texture2D
	data.texture_size = texture_size
	data.uv2_sides = _uv2_sides
	data.mesh_global_bounds = _get_mesh_global_aabb(mesh_instance)
	data.bake_settings = _get_bake_settings(source_texture_size, texture_size, content_rect, texture_layout)
	data.source_texture_size = source_texture_size
	data.content_rect = content_rect
	data.texture_layout = texture_layout
	data.source_kind = source_kind
	data.source_metadata = source_metadata
	data.source_signature = get_bake_source_signature()
	data.finalize()
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
	return RiverBakeConstants.build_source_signature({
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
		"step_count": step_count,
		"uv2_sides": WaterHelperMethods.calculate_side(step_count)
	})


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
	# Runtime set_widths()/set_flow_speeds() are data-only API calls; geometry
	# regeneration and bake invalidation remain editor-authoring behavior.
	if _first_enter_tree:
		return
	_invalidate_generated_bake(true, notify_river)


func _on_bake_property_changed() -> void:
	# Runtime set_widths()/set_flow_speeds() are data-only API calls; geometry
	# regeneration and bake invalidation remain editor-authoring behavior.
	if _first_enter_tree:
		return
	_invalidate_generated_bake(false, false)


func _invalidate_generated_bake(regenerate_geometry: bool, notify_river: bool) -> void:
	_set_valid_flowmap(false)
	if regenerate_geometry:
		_generate_river()
	if notify_river:
		emit_signal("river_changed")


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
	return RiverBakeConstants.build_bake_settings({
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
		"uv2_sides": _uv2_sides,
		"source_texture_size": source_texture_size,
		"texture_size": texture_size,
		"content_rect": content_rect,
		"texture_layout": texture_layout
	})


# Signal Methods
func properties_changed() -> void:
	emit_signal("river_changed")
