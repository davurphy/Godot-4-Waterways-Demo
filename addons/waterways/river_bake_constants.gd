# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends RefCounted

const WaterHelperMethods = preload("res://addons/waterways/water_helper_methods.gd")

const SECTION_SOURCE_METADATA := "source_metadata"
const SECTION_SOURCE_SIGNATURE := "source_signature"
const SECTION_BAKE_SETTINGS := "bake_settings"

const ROW_TYPE_RAW := "raw"
const ROW_TYPE_SIGNATURE_SNAPPED_FLOAT := "signature_snapped_float"
const ROW_TYPE_STABLE_JOINED_ARRAY := "stable_joined_array"
const ROW_TYPE_STRING_LITERAL := "string_literal"
const ROW_TYPE_BOOLEAN := "boolean"
const ROW_TYPE_WATER_HELPER := "water_helper"

const SOURCE_SIGNATURE_FLOAT_STEP := 0.0001

# v28 is intentionally preserved for R6.2 shadow extraction.
const RIVER_BAKE_SOURCE_SIGNATURE_VERSION := 28
const FLOW_OFFSET_NOISE_TEXTURE_PATH := "res://addons/waterways/textures/flow_offset_noise.png"

const RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS := 1
const RIVER_DOWNSTREAM_BASELINE_STRENGTH := 0.25
const RIVER_OCCUPANCY_RAMP_TILES := 0.12
const RIVER_OCCUPANCY_PROTRUSION_THRESHOLD := 0.9
const RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN := 0.75
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
const RIVER_FLOW_SPEED_FACTOR_MAX := 2.0
const RIVER_BEND_BIAS_LOOKAHEAD_TILES := 1.0
const RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES := 1
const RIVER_BEND_BIAS_REFERENCE_RADIANS := 0.45
const RIVER_FLAT_FOAM_SUPPORT_VALUE := 0.25
const RIVER_FLAT_PRESSURE_SUPPORT_VALUE := 0.25

const SOURCE_METADATA_DYNAMIC_KEYS := [
	"bake_revision",
	"generation_behavior",
	"generation_mode",
	"downstream_baseline_applied",
	"legacy_collision_only",
	"collision_hit_pixel_count",
	"collision_total_pixel_count",
	"collision_hit_pixel_percent",
	"curve_baseline_pixel_count",
	"collision_probe_skipped",
	"collision_support_filters_ran",
	"obstacle_avoidance_applied",
	"flow_projected",
	"water_occupancy_baked",
	"obstacle_feature_stats",
	"terrain_contact_feature_stats",
	"bank_response_feature_stats",
	"support_fallback_applied",
	"support_fallback_reason",
	"no_collider_curve_only_fallback",
	"grade_energy_stats",
	"bend_bias_stats",
	"flow_speed_scaled",
	"flat_foam_support_reduced",
	"flat_pressure_support_reduced",
	"flow_vector_diagnostics",
	"scene_path",
	"node_path",
	"node_name",
	"bake_resource_path",
]

const SOURCE_SIGNATURE_DYNAMIC_KEYS := [
	"curve_bake_interval",
	"points",
	"shape_step_length_divs",
	"shape_step_width_divs",
	"shape_smoothness",
	"baking_resolution",
	"baking_raycast_distance",
	"baking_raycast_layers",
	"baking_dilate",
	"baking_flowmap_blur",
	"baking_foam_cutoff",
	"baking_foam_offset",
	"baking_foam_blur",
	"bake_generation_behavior",
	"step_count",
	"uv2_sides",
]

const BAKE_SETTINGS_DYNAMIC_KEYS := [
	"shape_step_length_divs",
	"shape_step_width_divs",
	"shape_smoothness",
	"baking_resolution",
	"baking_raycast_distance",
	"baking_raycast_layers",
	"baking_dilate",
	"baking_flowmap_blur",
	"baking_foam_cutoff",
	"baking_foam_offset",
	"baking_foam_blur",
	"bake_generation_behavior",
	"uv2_sides",
	"source_texture_size",
	"texture_size",
	"content_rect",
	"texture_layout",
]


static func get_constant_rows() -> Array:
	return [
		{
			"name": "source_signature_version",
			"value": RIVER_BAKE_SOURCE_SIGNATURE_VERSION,
			"type": ROW_TYPE_RAW,
			"signature_key": "version",
			"reason": "Bumps when bake compatibility changes.",
			"review_decision": "Signature row; R6.2 preserves version 28.",
		},
		{
			"name": "water_helper_storage_version",
			"value": WaterHelperMethods.EXTERNAL_BAKE_STORAGE_VERSION,
			"type": ROW_TYPE_WATER_HELPER,
			"metadata_key": "storage_version",
			"reason": "External bake storage metadata is added by WaterHelperMethods when saved.",
			"review_decision": "Metadata-only storage format marker; it does not alter generated texture content.",
		},
		{
			"name": "river_edge_smooth_radius",
			"value": WaterHelperMethods.RIVER_EDGE_SMOOTH_RADIUS,
			"type": ROW_TYPE_WATER_HELPER,
			"signature_key": "river_edge_smooth_radius",
			"reason": "Edge-overlap smoothing shapes the generated river mesh used by the bake.",
			"review_decision": "Signature row sourced from WaterHelperMethods.",
		},
		{
			"name": "river_edge_smooth_iterations",
			"value": WaterHelperMethods.RIVER_EDGE_SMOOTH_ITERATIONS,
			"type": ROW_TYPE_WATER_HELPER,
			"signature_key": "river_edge_smooth_iterations",
			"reason": "Edge-overlap smoothing shapes the generated river mesh used by the bake.",
			"review_decision": "Signature row sourced from WaterHelperMethods.",
		},
		{
			"name": "downstream_baseline_strength",
			"value": RIVER_DOWNSTREAM_BASELINE_STRENGTH,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "downstream_baseline_strength",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "downstream_baseline_strength",
			"settings_key": "downstream_baseline_strength",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes generated downstream baseline flow.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "flow_speed_factor_max",
			"value": RIVER_FLOW_SPEED_FACTOR_MAX,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "flow_speed_factor_max",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "flow_speed_factor_max",
			"reason": "Packs per-point flow-speed factors into source images.",
			"review_decision": "Signature and metadata row.",
		},
		{
			"name": "flow_offset_noise_texture_path",
			"value": FLOW_OFFSET_NOISE_TEXTURE_PATH,
			"type": ROW_TYPE_STRING_LITERAL,
			"signature_key": "flow_offset_noise_texture_path",
			"reason": "Changing the noise texture resource path can change generated flow detail.",
			"review_decision": "Signature-only stable path literal.",
		},
		{
			"name": "water_occupancy_ramp_tiles",
			"value": RIVER_OCCUPANCY_RAMP_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "water_occupancy_ramp_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "water_occupancy_ramp_tiles",
			"reason": "Shapes the water-occupancy proximity ramp.",
			"review_decision": "Signature and metadata row.",
		},
		{
			"name": "water_occupancy_protrusion_threshold",
			"value": RIVER_OCCUPANCY_PROTRUSION_THRESHOLD,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "water_occupancy_protrusion_threshold",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "water_occupancy_protrusion_threshold",
			"reason": "Classifies solid terrain protrusions for occupancy.",
			"review_decision": "Signature and metadata row.",
		},
		{
			"name": "water_occupancy_protrusion_confidence_min",
			"value": RIVER_OCCUPANCY_PROTRUSION_CONFIDENCE_MIN,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "water_occupancy_protrusion_confidence_min",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "water_occupancy_protrusion_confidence_min",
			"reason": "Gates terrain-contact confidence before marking occupancy solids.",
			"review_decision": "Signature and metadata row.",
		},
		{
			"name": "flow_projection_strides",
			"value": RIVER_FLOW_PROJECTION_STRIDES,
			"type": ROW_TYPE_STABLE_JOINED_ARRAY,
			"metadata_key": "flow_projection_strides",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "flow_projection_strides",
			"reason": "Controls pressure-projection solve order.",
			"review_decision": "Signature stores a stable joined string; metadata stores the raw stride list.",
		},
		{
			"name": "flow_projection_iterations_per_stride",
			"value": RIVER_FLOW_PROJECTION_ITERATIONS_PER_STRIDE,
			"type": ROW_TYPE_RAW,
			"metadata_key": "flow_projection_iterations_per_stride",
			"signature_key": "flow_projection_iterations_per_stride",
			"reason": "Controls pressure-projection solve iterations.",
			"review_decision": "Signature and metadata row.",
		},
		{
			"name": "flow_tangency_passes",
			"value": RIVER_FLOW_TANGENCY_PASSES,
			"type": ROW_TYPE_RAW,
			"signature_key": "flow_tangency_passes",
			"reason": "Controls final tangency enforcement passes.",
			"review_decision": "Signature-only row because saved metadata/settings did not historically include this value.",
		},
		{
			"name": "obstacle_avoidance_algorithm",
			"value": "pressure_projection_free_slip_jacobi_with_normal_to_flow_blur_fallback",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "obstacle_avoidance_algorithm",
			"reason": "Documents the active obstacle-avoidance algorithm in saved metadata.",
			"review_decision": "Metadata-only descriptor; behavior-affecting constants are separate signature rows.",
		},
		{
			"name": "obstacle_avoidance_uses_bank_response_context",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_avoidance_uses_bank_response_context",
			"reason": "Documents that obstacle avoidance consumes bank-response context.",
			"review_decision": "Metadata-only descriptor; bank-response constants are signed separately.",
		},
		{
			"name": "obstacle_features_baked",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_features_baked",
			"reason": "Documents that obstacle feature textures are generated.",
			"review_decision": "Metadata-only descriptor; feature constants are signed separately.",
		},
		{
			"name": "obstacle_features_algorithm",
			"value": "direct_terrain_contact_anchored_pillow_tight_support_bank_context_flow_feature_classification_debug_only",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "obstacle_features_algorithm",
			"reason": "Documents the obstacle feature generation algorithm.",
			"review_decision": "Metadata-only descriptor; behavior-affecting thresholds are signed separately.",
		},
		{
			"name": "obstacle_features_neutral_value",
			"value": Color(0.0, 0.0, 0.0, 0.0),
			"type": ROW_TYPE_RAW,
			"metadata_key": "obstacle_features_neutral_value",
			"reason": "Documents the neutral obstacle feature channel value.",
			"review_decision": "Metadata-only descriptor; blank feature source output is already covered by generated-output validation.",
		},
		{
			"name": "obstacle_feature_support_start",
			"value": RIVER_OBSTACLE_FEATURE_SUPPORT_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_support_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_support_start",
			"settings_key": "obstacle_feature_support_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle support classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_support_full",
			"value": RIVER_OBSTACLE_FEATURE_SUPPORT_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_support_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_support_full",
			"settings_key": "obstacle_feature_support_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle support classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_facing_start",
			"value": RIVER_OBSTACLE_FEATURE_FACING_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_facing_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_facing_start",
			"settings_key": "obstacle_feature_facing_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle facing classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_facing_full",
			"value": RIVER_OBSTACLE_FEATURE_FACING_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_facing_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_facing_full",
			"settings_key": "obstacle_feature_facing_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle facing classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_support_start",
			"value": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_pillow_support_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_pillow_support_start",
			"settings_key": "obstacle_feature_pillow_support_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes pillow support classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_support_full",
			"value": RIVER_OBSTACLE_FEATURE_PILLOW_SUPPORT_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_pillow_support_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_pillow_support_full",
			"settings_key": "obstacle_feature_pillow_support_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes pillow support classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_contact_search_tiles",
			"value": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_SEARCH_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_pillow_contact_search_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_pillow_contact_search_tiles",
			"settings_key": "obstacle_feature_pillow_contact_search_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls pillow contact search radius.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_contact_gate_start",
			"value": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_pillow_contact_gate_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_pillow_contact_gate_start",
			"settings_key": "obstacle_feature_pillow_contact_gate_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls pillow contact gating.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_contact_gate_full",
			"value": RIVER_OBSTACLE_FEATURE_PILLOW_CONTACT_GATE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_pillow_contact_gate_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_pillow_contact_gate_full",
			"settings_key": "obstacle_feature_pillow_contact_gate_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls pillow contact gating.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_anchor_source",
			"value": "terrain_contact_features.b_direct_search",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "obstacle_features_pillow_anchor_source",
			"signature_key": "obstacle_feature_pillow_anchor_source",
			"settings_key": "obstacle_feature_pillow_anchor_source",
			"reason": "Identifies the source channel used for pillow anchoring.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_pillow_bank_response_role",
			"value": "weak_context_only_not_anchor",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "obstacle_features_pillow_bank_response_role",
			"signature_key": "obstacle_feature_pillow_bank_response_role",
			"settings_key": "obstacle_feature_pillow_bank_response_role",
			"reason": "Documents the role of bank response in pillow classification.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_wake_length_tiles",
			"value": RIVER_OBSTACLE_FEATURE_WAKE_LENGTH_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_wake_length_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_wake_length_tiles",
			"settings_key": "obstacle_feature_wake_length_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle wake extent.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_wake_width_tiles",
			"value": RIVER_OBSTACLE_FEATURE_WAKE_WIDTH_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_wake_width_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_wake_width_tiles",
			"settings_key": "obstacle_feature_wake_width_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle wake width.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_side_width_tiles",
			"value": RIVER_OBSTACLE_FEATURE_SIDE_WIDTH_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_side_width_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_side_width_tiles",
			"settings_key": "obstacle_feature_side_width_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes side-deflection width.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_wake_start",
			"value": RIVER_OBSTACLE_FEATURE_WAKE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_wake_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_wake_start",
			"settings_key": "obstacle_feature_wake_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes wake response ramp.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_wake_full",
			"value": RIVER_OBSTACLE_FEATURE_WAKE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_wake_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_wake_full",
			"settings_key": "obstacle_feature_wake_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes wake response ramp.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_bank_friction_suppression",
			"value": RIVER_OBSTACLE_FEATURE_BANK_FRICTION_SUPPRESSION,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_bank_friction_suppression",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_bank_friction_suppression",
			"settings_key": "obstacle_feature_bank_friction_suppression",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle feature interaction with bank friction.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_hard_boundary_wake_gate",
			"value": RIVER_OBSTACLE_FEATURE_HARD_BOUNDARY_WAKE_GATE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_hard_boundary_wake_gate",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_hard_boundary_wake_gate",
			"settings_key": "obstacle_feature_hard_boundary_wake_gate",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Gates wake response near hard boundaries.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_confidence_start",
			"value": RIVER_OBSTACLE_FEATURE_CONFIDENCE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_confidence_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_confidence_start",
			"settings_key": "obstacle_feature_confidence_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle confidence response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_confidence_full",
			"value": RIVER_OBSTACLE_FEATURE_CONFIDENCE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_confidence_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_confidence_full",
			"settings_key": "obstacle_feature_confidence_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes obstacle confidence response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_edge_start",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_edge_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_edge_start",
			"settings_key": "obstacle_feature_eddy_line_edge_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes eddy-line edge response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_edge_full",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_EDGE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_edge_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_edge_full",
			"settings_key": "obstacle_feature_eddy_line_edge_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes eddy-line edge response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_wake_start",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_wake_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_wake_start",
			"settings_key": "obstacle_feature_eddy_line_wake_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes eddy-line wake response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_wake_full",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_WAKE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_wake_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_wake_full",
			"settings_key": "obstacle_feature_eddy_line_wake_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes eddy-line wake response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_hard_gate_start",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_hard_gate_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_hard_gate_start",
			"settings_key": "obstacle_feature_eddy_line_hard_gate_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Gates eddy-line response near hard boundaries.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_hard_gate_full",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_HARD_GATE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_hard_gate_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_hard_gate_full",
			"settings_key": "obstacle_feature_eddy_line_hard_gate_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Gates eddy-line response near hard boundaries.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_energy_gate_start",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_energy_gate_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_energy_gate_start",
			"settings_key": "obstacle_feature_eddy_line_energy_gate_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Gates eddy-line response by grade energy.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_energy_gate_full",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_ENERGY_GATE_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_energy_gate_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_energy_gate_full",
			"settings_key": "obstacle_feature_eddy_line_energy_gate_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Gates eddy-line response by grade energy.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_support_reject_start",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_support_reject_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_support_reject_start",
			"settings_key": "obstacle_feature_eddy_line_support_reject_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Rejects eddy-line response in strongly supported regions.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_feature_eddy_line_support_reject_full",
			"value": RIVER_OBSTACLE_FEATURE_EDDY_LINE_SUPPORT_REJECT_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "obstacle_features_eddy_line_support_reject_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "obstacle_feature_eddy_line_support_reject_full",
			"settings_key": "obstacle_feature_eddy_line_support_reject_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Rejects eddy-line response in strongly supported regions.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "obstacle_features_uses_tight_support",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_features_uses_tight_support",
			"reason": "Documents tight-support filtering in obstacle features.",
			"review_decision": "Metadata-only descriptor; thresholds and generated-output gates cover behavior.",
		},
		{
			"name": "obstacle_features_uses_bank_response_context",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_features_uses_bank_response_context",
			"reason": "Documents bank-response context usage in obstacle features.",
			"review_decision": "Metadata-only descriptor; bank-response constants are signed separately.",
		},
		{
			"name": "obstacle_features_uses_terrain_protrusion_context",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_features_uses_terrain_protrusion_context",
			"reason": "Documents terrain-protrusion context usage in obstacle features.",
			"review_decision": "Metadata-only descriptor; terrain-contact constants are signed separately.",
		},
		{
			"name": "obstacle_features_uses_grade_energy_context",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_features_uses_grade_energy_context",
			"reason": "Documents grade-energy context usage in obstacle features.",
			"review_decision": "Metadata-only descriptor; grade-energy constants are signed separately.",
		},
		{
			"name": "obstacle_features_pillow_uses_contact_anchor",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "obstacle_features_pillow_uses_contact_anchor",
			"reason": "Documents pillow contact-anchor usage.",
			"review_decision": "Metadata-only descriptor; anchor source is signed separately.",
		},
		{
			"name": "filtered_feature_edge_sync_depth_pixels",
			"value": RIVER_FILTERED_FEATURE_EDGE_SYNC_DEPTH_PIXELS,
			"type": ROW_TYPE_RAW,
			"metadata_key": "filtered_feature_edge_sync_depth_pixels",
			"signature_key": "filtered_feature_edge_sync_depth_pixels",
			"settings_key": "filtered_feature_edge_sync_depth_pixels",
			"reason": "Controls edge-band synchronization for filtered feature maps.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_features_baked",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "terrain_contact_features_baked",
			"reason": "Documents that terrain-contact feature textures are generated.",
			"review_decision": "Metadata-only descriptor; terrain-contact constants are signed separately.",
		},
		{
			"name": "terrain_contact_features_algorithm",
			"value": "uv2_world_height_delta_supersampled_blended_sources_debug_only",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "terrain_contact_features_algorithm",
			"reason": "Documents the terrain-contact feature generation algorithm.",
			"review_decision": "Metadata-only descriptor; behavior-affecting thresholds are signed separately.",
		},
		{
			"name": "terrain_contact_features_neutral_value",
			"value": Color(0.0, 0.0, 0.0, 0.0),
			"type": ROW_TYPE_RAW,
			"metadata_key": "terrain_contact_features_neutral_value",
			"reason": "Documents the neutral terrain-contact feature channel value.",
			"review_decision": "Metadata-only descriptor; blank feature source output is covered by generated-output validation.",
		},
		{
			"name": "terrain_contact_full_band",
			"value": RIVER_TERRAIN_CONTACT_FULL_BAND,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_full_band",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_full_band",
			"settings_key": "terrain_contact_full_band",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes terrain-contact near-surface banding.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_fade_distance",
			"value": RIVER_TERRAIN_CONTACT_FADE_DISTANCE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_fade_distance",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_fade_distance",
			"settings_key": "terrain_contact_fade_distance",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes terrain-contact near-surface fading.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_shallow_full_depth",
			"value": RIVER_TERRAIN_SHALLOW_FULL_DEPTH,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_shallow_full_depth",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_shallow_full_depth",
			"settings_key": "terrain_contact_shallow_full_depth",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes shallow-water terrain contact.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_shallow_fade_depth",
			"value": RIVER_TERRAIN_SHALLOW_FADE_DEPTH,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_shallow_fade_depth",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_shallow_fade_depth",
			"settings_key": "terrain_contact_shallow_fade_depth",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes shallow-water terrain-contact fading.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_protrusion_fade_height",
			"value": RIVER_TERRAIN_PROTRUSION_FADE_HEIGHT,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_protrusion_fade_height",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_protrusion_fade_height",
			"settings_key": "terrain_contact_protrusion_fade_height",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes protrusion-height terrain contact.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_protrusion_full_height",
			"value": RIVER_TERRAIN_PROTRUSION_FULL_HEIGHT,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_protrusion_full_height",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_protrusion_full_height",
			"settings_key": "terrain_contact_protrusion_full_height",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes protrusion-height terrain contact.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_raycast_up_offset",
			"value": RIVER_TERRAIN_CONTACT_RAYCAST_UP_OFFSET,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_raycast_up_offset",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_raycast_up_offset",
			"settings_key": "terrain_contact_raycast_up_offset",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls terrain-contact raycast origin.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_raycast_down_distance",
			"value": RIVER_TERRAIN_CONTACT_RAYCAST_DOWN_DISTANCE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_raycast_down_distance",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_raycast_down_distance",
			"settings_key": "terrain_contact_raycast_down_distance",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls terrain-contact raycast distance.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_hterrain_source_confidence",
			"value": RIVER_TERRAIN_HTERRAIN_SOURCE_CONFIDENCE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_hterrain_source_confidence",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_hterrain_source_confidence",
			"settings_key": "terrain_contact_hterrain_source_confidence",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls heightfield-source confidence packing.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_physics_source_confidence",
			"value": RIVER_TERRAIN_PHYSICS_SOURCE_CONFIDENCE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_physics_source_confidence",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_physics_source_confidence",
			"settings_key": "terrain_contact_physics_source_confidence",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls physics-source confidence packing.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_supersamples",
			"value": RIVER_TERRAIN_CONTACT_SUPERSAMPLES,
			"type": ROW_TYPE_RAW,
			"metadata_key": "terrain_contact_supersamples",
			"signature_key": "terrain_contact_supersamples",
			"settings_key": "terrain_contact_supersamples",
			"reason": "Controls terrain-contact source supersampling.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_source_blend_band",
			"value": RIVER_TERRAIN_CONTACT_SOURCE_BLEND_BAND,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "terrain_contact_source_blend_band",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "terrain_contact_source_blend_band",
			"settings_key": "terrain_contact_source_blend_band",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls blending between terrain-contact sources.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "terrain_contact_edge_smooth_passes",
			"value": RIVER_TERRAIN_CONTACT_EDGE_SMOOTH_PASSES,
			"type": ROW_TYPE_RAW,
			"metadata_key": "terrain_contact_edge_smooth_passes",
			"signature_key": "terrain_contact_edge_smooth_passes",
			"settings_key": "terrain_contact_edge_smooth_passes",
			"reason": "Controls terrain-contact source edge smoothing.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "uv2_world_sample_tile_classifier",
			"value": "floor_partition_match_tile_rect",
			"type": ROW_TYPE_STRING_LITERAL,
			"signature_key": "uv2_world_sample_tile_classifier",
			"reason": "Identifies the UV2 world-sampling tile classifier.",
			"review_decision": "Signature-only stable algorithm literal.",
		},
		{
			"name": "filter_passes_column_clamped",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "filter_passes_column_clamped",
			"signature_key": "filter_passes_column_clamped",
			"reason": "Records column clamping in the filter pass layout.",
			"review_decision": "Signature and metadata row.",
		},
		{
			"name": "bank_response_features_baked",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "bank_response_features_baked",
			"reason": "Documents that bank-response feature textures are generated.",
			"review_decision": "Metadata-only descriptor; bank-response constants are signed separately.",
		},
		{
			"name": "bank_response_features_algorithm",
			"value": "terrain_contact_depth_bend_grade_flow_semantic_response_debug_only",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "bank_response_features_algorithm",
			"reason": "Documents the bank-response feature generation algorithm.",
			"review_decision": "Metadata-only descriptor; behavior-affecting thresholds are signed separately.",
		},
		{
			"name": "bank_response_features_neutral_value",
			"value": Color(0.0, 0.0, 0.0, 0.0),
			"type": ROW_TYPE_RAW,
			"metadata_key": "bank_response_features_neutral_value",
			"reason": "Documents the neutral bank-response feature channel value.",
			"review_decision": "Metadata-only descriptor; blank feature source output is covered by generated-output validation.",
		},
		{
			"name": "bank_response_probe_tiles",
			"value": RIVER_BANK_RESPONSE_PROBE_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_probe_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_probe_tiles",
			"settings_key": "bank_response_probe_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls bank-response neighborhood probing.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_friction_contact_weight",
			"value": RIVER_BANK_RESPONSE_FRICTION_CONTACT_WEIGHT,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_friction_contact_weight",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_friction_contact_weight",
			"settings_key": "bank_response_friction_contact_weight",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Weights contact contribution to bank friction.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_friction_shallow_weight",
			"value": RIVER_BANK_RESPONSE_FRICTION_SHALLOW_WEIGHT,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_friction_shallow_weight",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_friction_shallow_weight",
			"settings_key": "bank_response_friction_shallow_weight",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Weights shallow-depth contribution to bank friction.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_hard_protrusion_weight",
			"value": RIVER_BANK_RESPONSE_HARD_PROTRUSION_WEIGHT,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_hard_protrusion_weight",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_hard_protrusion_weight",
			"settings_key": "bank_response_hard_protrusion_weight",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Weights hard protrusion contribution to bank response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_outside_bend_start",
			"value": RIVER_BANK_RESPONSE_OUTSIDE_BEND_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_outside_bend_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_outside_bend_start",
			"settings_key": "bank_response_outside_bend_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes outside-bend wet-pressure response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_outside_bend_full",
			"value": RIVER_BANK_RESPONSE_OUTSIDE_BEND_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_outside_bend_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_outside_bend_full",
			"settings_key": "bank_response_outside_bend_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes outside-bend wet-pressure response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_inside_bend_start",
			"value": RIVER_BANK_RESPONSE_INSIDE_BEND_START,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_inside_bend_start",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_inside_bend_start",
			"settings_key": "bank_response_inside_bend_start",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes inside-bend deposition response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_inside_bend_full",
			"value": RIVER_BANK_RESPONSE_INSIDE_BEND_FULL,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bank_response_inside_bend_full",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bank_response_inside_bend_full",
			"settings_key": "bank_response_inside_bend_full",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Shapes inside-bend deposition response.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bank_response_uses_obstacle_features",
			"value": false,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "bank_response_uses_obstacle_features",
			"reason": "Documents that bank response currently avoids obstacle-feature feedback.",
			"review_decision": "Metadata-only descriptor; it does not change generated content unless implementation changes.",
		},
		{
			"name": "blank_support_value",
			"value": RIVER_BLANK_SUPPORT_VALUE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"signature_key": "blank_support_value",
			"settings_key": "blank_support_value",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Defines neutral support map value.",
			"review_decision": "Signature and settings row.",
		},
		{
			"name": "blank_support_foam_value",
			"value": RIVER_BLANK_SUPPORT_VALUE,
			"type": ROW_TYPE_RAW,
			"metadata_key": "blank_support_foam_value",
			"reason": "Documents neutral foam support value.",
			"review_decision": "Metadata-only mirror of signed blank_support_value.",
		},
		{
			"name": "blank_support_dist_pressure",
			"value": Vector2(RIVER_BLANK_SUPPORT_VALUE, RIVER_BLANK_SUPPORT_VALUE),
			"type": ROW_TYPE_RAW,
			"metadata_key": "blank_support_dist_pressure",
			"reason": "Documents neutral distance/pressure support vector.",
			"review_decision": "Metadata-only mirror of signed blank_support_value.",
		},
		{
			"name": "grade_energy_baked",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "grade_energy_baked",
			"reason": "Documents that grade-energy features are generated.",
			"review_decision": "Metadata-only descriptor; grade-energy constants are signed separately.",
		},
		{
			"name": "grade_energy_algorithm",
			"value": "curve_height_drop_vertex_aligned_longitudinal_lerp",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "grade_energy_algorithm",
			"reason": "Documents the grade-energy feature algorithm.",
			"review_decision": "Metadata-only descriptor; source sampling literal and thresholds are signed separately.",
		},
		{
			"name": "grade_energy_source_sampling",
			"value": "vertex_aligned_longitudinal_lerp",
			"type": ROW_TYPE_STRING_LITERAL,
			"signature_key": "grade_energy_source_sampling",
			"reason": "Identifies grade-energy source sampling.",
			"review_decision": "Signature-only stable algorithm literal.",
		},
		{
			"name": "grade_energy_lookahead_tiles",
			"value": RIVER_GRADE_ENERGY_LOOKAHEAD_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "grade_energy_lookahead_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "grade_energy_lookahead_tiles",
			"settings_key": "grade_energy_lookahead_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls grade-energy lookahead distance.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "grade_energy_smooth_radius_tiles",
			"value": RIVER_GRADE_ENERGY_SMOOTH_RADIUS_TILES,
			"type": ROW_TYPE_RAW,
			"metadata_key": "grade_energy_smooth_radius_tiles",
			"signature_key": "grade_energy_smooth_radius_tiles",
			"settings_key": "grade_energy_smooth_radius_tiles",
			"reason": "Controls grade-energy smoothing radius.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "grade_energy_reference_grade",
			"value": RIVER_GRADE_ENERGY_REFERENCE_GRADE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "grade_energy_reference_grade",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "grade_energy_reference_grade",
			"settings_key": "grade_energy_reference_grade",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls grade-energy normalization.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "neutral_grade_energy_value",
			"value": RIVER_NEUTRAL_GRADE_ENERGY_VALUE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"signature_key": "neutral_grade_energy_value",
			"settings_key": "neutral_grade_energy_value",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Defines neutral grade-energy value.",
			"review_decision": "Signature and settings row.",
		},
		{
			"name": "neutral_grade_energy_feature_value",
			"value": RIVER_NEUTRAL_GRADE_ENERGY_VALUE,
			"type": ROW_TYPE_RAW,
			"metadata_key": "neutral_grade_energy_feature_value",
			"reason": "Documents neutral grade-energy feature value.",
			"review_decision": "Metadata-only mirror of signed neutral_grade_energy_value.",
		},
		{
			"name": "bend_bias_baked",
			"value": true,
			"type": ROW_TYPE_BOOLEAN,
			"metadata_key": "bend_bias_baked",
			"reason": "Documents that bend-bias features are generated.",
			"review_decision": "Metadata-only descriptor; bend-bias constants are signed separately.",
		},
		{
			"name": "bend_bias_algorithm",
			"value": "curve_planar_curvature_vertex_aligned_longitudinal_lerp_cross_river_bias",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "bend_bias_algorithm",
			"reason": "Documents the bend-bias feature algorithm.",
			"review_decision": "Metadata-only descriptor; sampling literals and thresholds are signed separately.",
		},
		{
			"name": "bend_bias_sign_convention",
			"value": "dist_pressure.a packed signed bias; values above 0.5 mean outside bend faster, below 0.5 mean inside bend slower",
			"type": ROW_TYPE_STRING_LITERAL,
			"metadata_key": "bend_bias_sign_convention",
			"reason": "Documents bend-bias packing semantics.",
			"review_decision": "Metadata-only descriptor; it does not alter generated content.",
		},
		{
			"name": "bend_bias_source_sampling",
			"value": "vertex_aligned_longitudinal_lerp",
			"type": ROW_TYPE_STRING_LITERAL,
			"signature_key": "bend_bias_source_sampling",
			"reason": "Identifies bend-bias longitudinal sampling.",
			"review_decision": "Signature-only stable algorithm literal.",
		},
		{
			"name": "bend_bias_lateral_sampling",
			"value": "vertex_aligned_cross_river_ratio",
			"type": ROW_TYPE_STRING_LITERAL,
			"signature_key": "bend_bias_lateral_sampling",
			"reason": "Identifies bend-bias lateral sampling.",
			"review_decision": "Signature-only stable algorithm literal.",
		},
		{
			"name": "neutral_bend_bias_value",
			"value": RIVER_NEUTRAL_BEND_BIAS_VALUE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"signature_key": "neutral_bend_bias_value",
			"settings_key": "neutral_bend_bias_value",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Defines neutral bend-bias value.",
			"review_decision": "Signature and settings row.",
		},
		{
			"name": "neutral_bend_bias_feature_value",
			"value": RIVER_NEUTRAL_BEND_BIAS_VALUE,
			"type": ROW_TYPE_RAW,
			"metadata_key": "neutral_bend_bias_feature_value",
			"reason": "Documents neutral bend-bias feature value.",
			"review_decision": "Metadata-only mirror of signed neutral_bend_bias_value.",
		},
		{
			"name": "bend_bias_lookahead_tiles",
			"value": RIVER_BEND_BIAS_LOOKAHEAD_TILES,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bend_bias_lookahead_tiles",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bend_bias_lookahead_tiles",
			"settings_key": "bend_bias_lookahead_tiles",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls bend-bias lookahead distance.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bend_bias_smooth_radius_tiles",
			"value": RIVER_BEND_BIAS_SMOOTH_RADIUS_TILES,
			"type": ROW_TYPE_RAW,
			"metadata_key": "bend_bias_smooth_radius_tiles",
			"signature_key": "bend_bias_smooth_radius_tiles",
			"settings_key": "bend_bias_smooth_radius_tiles",
			"reason": "Controls bend-bias smoothing radius.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "bend_bias_reference_radians",
			"value": RIVER_BEND_BIAS_REFERENCE_RADIANS,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "bend_bias_reference_radians",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "bend_bias_reference_radians",
			"settings_key": "bend_bias_reference_radians",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Controls bend-bias curvature normalization.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "flat_foam_support_value",
			"value": RIVER_FLAT_FOAM_SUPPORT_VALUE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "flat_foam_support_value",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "flat_foam_support_value",
			"settings_key": "flat_foam_support_value",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Defines reduced flat foam support value.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "flat_pressure_support_value",
			"value": RIVER_FLAT_PRESSURE_SUPPORT_VALUE,
			"type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"metadata_key": "flat_pressure_support_value",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "flat_pressure_support_value",
			"settings_key": "flat_pressure_support_value",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Defines reduced flat pressure support value.",
			"review_decision": "Signature, settings, and metadata row.",
		},
		{
			"name": "near_neutral_threshold",
			"value": WaterHelperMethods.FLOW_VECTOR_NEAR_NEUTRAL_THRESHOLD,
			"type": ROW_TYPE_WATER_HELPER,
			"metadata_key": "near_neutral_threshold",
			"metadata_type": ROW_TYPE_RAW,
			"signature_key": "near_neutral_threshold",
			"signature_type": ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
			"settings_key": "near_neutral_threshold",
			"settings_type": ROW_TYPE_RAW,
			"reason": "Classifies near-neutral flow vectors in diagnostics and metadata.",
			"review_decision": "Signature, settings, and metadata row sourced from WaterHelperMethods.",
		},
		{
			"name": "supported_future_source_kinds",
			"value": PackedStringArray([
				"generated_spline_collision_bake",
				"generated_downstream_baseline_collision_bake",
				"generated_curve_collision_modifiers_bake",
				"generated_curve_only_bake",
				"imported_linear_data_map",
				"hand_painted_flow_map",
				"dcc_or_simulation_flow_map",
				"shore_distance_field",
				"terrain_slope_field",
				"obstacle_influence_field",
			]),
			"type": ROW_TYPE_RAW,
			"metadata_key": "supported_future_source_kinds",
			"reason": "Documents supported source-kind vocabulary for saved metadata consumers.",
			"review_decision": "Metadata-only vocabulary; not a generated-texture input.",
		},
	]


static func build_source_metadata(dynamic_values: Dictionary = {}) -> Dictionary:
	return build_dictionary(SECTION_SOURCE_METADATA, dynamic_values)


static func build_source_signature(dynamic_values: Dictionary = {}) -> Dictionary:
	return build_dictionary(SECTION_SOURCE_SIGNATURE, dynamic_values)


static func build_bake_settings(dynamic_values: Dictionary = {}) -> Dictionary:
	return build_dictionary(SECTION_BAKE_SETTINGS, dynamic_values)


static func build_dictionary(section: String, dynamic_values: Dictionary = {}) -> Dictionary:
	var result := dynamic_values.duplicate(true)
	for row_variant in get_constant_rows():
		var row: Dictionary = row_variant
		var section_key := _row_section_key(row, section)
		if section_key.is_empty():
			continue
		result[section_key] = _row_section_value(row, section)
	return result


static func get_section_keys(section: String) -> Dictionary:
	var keys := {}
	for row_variant in get_constant_rows():
		var row: Dictionary = row_variant
		var section_key := _row_section_key(row, section)
		if not section_key.is_empty():
			keys[section_key] = true
	return keys


static func get_dynamic_keys(section: String) -> Array:
	match section:
		SECTION_SOURCE_METADATA:
			return SOURCE_METADATA_DYNAMIC_KEYS.duplicate()
		SECTION_SOURCE_SIGNATURE:
			return SOURCE_SIGNATURE_DYNAMIC_KEYS.duplicate()
		SECTION_BAKE_SETTINGS:
			return BAKE_SETTINGS_DYNAMIC_KEYS.duplicate()
	return []


static func get_required_row_types() -> Array:
	return [
		ROW_TYPE_RAW,
		ROW_TYPE_SIGNATURE_SNAPPED_FLOAT,
		ROW_TYPE_STABLE_JOINED_ARRAY,
		ROW_TYPE_STRING_LITERAL,
		ROW_TYPE_BOOLEAN,
		ROW_TYPE_WATER_HELPER,
	]


static func validate_rows() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_names := {}
	var seen_types := {}
	var seen_section_keys := {
		SECTION_SOURCE_METADATA: {},
		SECTION_SOURCE_SIGNATURE: {},
		SECTION_BAKE_SETTINGS: {},
	}
	var dynamic_section_keys := {
		SECTION_SOURCE_METADATA: _array_to_lookup(SOURCE_METADATA_DYNAMIC_KEYS),
		SECTION_SOURCE_SIGNATURE: _array_to_lookup(SOURCE_SIGNATURE_DYNAMIC_KEYS),
		SECTION_BAKE_SETTINGS: _array_to_lookup(BAKE_SETTINGS_DYNAMIC_KEYS),
	}

	for row_variant in get_constant_rows():
		var row: Dictionary = row_variant
		var name := String(row.get("name", ""))
		if name.is_empty():
			errors.append("Constant row is missing name.")
		elif seen_names.has(name):
			errors.append("Duplicate constant row name: " + name)
		else:
			seen_names[name] = true

		var type_name := String(row.get("type", ROW_TYPE_RAW))
		seen_types[type_name] = true
		for type_key in ["metadata_type", "signature_type", "settings_type"]:
			if row.has(type_key):
				seen_types[String(row[type_key])] = true

		var has_signature := row.has("signature_key") and not String(row.get("signature_key", "")).is_empty()
		var feeds_any_section := false
		for section in [SECTION_SOURCE_METADATA, SECTION_SOURCE_SIGNATURE, SECTION_BAKE_SETTINGS]:
			var section_key := _row_section_key(row, section)
			if section_key.is_empty():
				continue
			feeds_any_section = true
			if dynamic_section_keys[section].has(section_key):
				errors.append("Constant row " + name + " overlaps dynamic " + section + " key: " + section_key)
			var section_seen: Dictionary = seen_section_keys[section]
			if section_seen.has(section_key):
				errors.append("Duplicate " + section + " constant key: " + section_key)
			else:
				section_seen[section_key] = name

		if not feeds_any_section:
			errors.append("Constant row " + name + " does not feed metadata, signature, or settings.")
		if not has_signature:
			if String(row.get("reason", "")).is_empty():
				errors.append("Non-signature row " + name + " is missing reason.")
			if String(row.get("review_decision", "")).is_empty():
				errors.append("Non-signature row " + name + " is missing review_decision.")

	for required_type in get_required_row_types():
		if not seen_types.has(required_type):
			errors.append("Constants table is missing required row type: " + String(required_type))

	if int(build_source_signature().get("version", -1)) != RIVER_BAKE_SOURCE_SIGNATURE_VERSION:
		errors.append("Source signature version row does not resolve to " + str(RIVER_BAKE_SOURCE_SIGNATURE_VERSION) + ".")

	return errors


static func _row_section_key(row: Dictionary, section: String) -> String:
	match section:
		SECTION_SOURCE_METADATA:
			return String(row.get("metadata_key", ""))
		SECTION_SOURCE_SIGNATURE:
			return String(row.get("signature_key", ""))
		SECTION_BAKE_SETTINGS:
			return String(row.get("settings_key", ""))
	return ""


static func _row_section_value(row: Dictionary, section: String):
	var type_key := ""
	match section:
		SECTION_SOURCE_METADATA:
			type_key = "metadata_type"
		SECTION_SOURCE_SIGNATURE:
			type_key = "signature_type"
		SECTION_BAKE_SETTINGS:
			type_key = "settings_type"
	var row_type := String(row.get(type_key, row.get("type", ROW_TYPE_RAW)))
	var value = row.get("value")
	match row_type:
		ROW_TYPE_SIGNATURE_SNAPPED_FLOAT:
			return snappedf(float(value), SOURCE_SIGNATURE_FLOAT_STEP)
		ROW_TYPE_STABLE_JOINED_ARRAY:
			return _stable_joined_array(value)
		_:
			return _duplicate_value(value)


static func _stable_joined_array(value) -> String:
	var parts := PackedStringArray()
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			parts.append(str(item))
	else:
		parts.append(str(value))
	return ",".join(parts)


static func _duplicate_value(value):
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(value)
		_:
			return value


static func _array_to_lookup(values: Array) -> Dictionary:
	var lookup := {}
	for value in values:
		lookup[String(value)] = true
	return lookup
