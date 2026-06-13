# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Resource
class_name RiverBakeData

const DEFAULT_CHANNEL_METADATA := {
	"flow_foam_noise": {
		"r": "signed_flow_x_packed_0_to_1_neutral_0_5",
		"g": "signed_flow_y_packed_0_to_1_neutral_0_5",
		"b": "foam_mask_0_to_1_neutral_0",
		"a": "phase_noise_0_to_1_for_flow_texture_offset"
	},
	"dist_pressure": {
		"r": "bank_distance_or_edge_influence_0_to_1_shader_inverts_for_force",
		"g": "flow_pressure_or_collision_support_0_to_1",
		"b": "curve_derived_grade_energy_feature_0_to_1_neutral_0",
		"a": "curve_derived_bend_bias_feature_packed_signed_0_to_1_neutral_0_5_positive_outside"
	},
	"obstacle_features": {
		"r": "contact_anchored_upstream_pillow_or_impact_mask_0_to_1_neutral_0",
		"g": "downstream_wake_or_eddy_seed_mask_0_to_1_neutral_0",
		"b": "terrain_energy_gated_eddy_line_or_shear_mask_0_to_1_neutral_0",
		"a": "side_deflection_or_obstacle_confidence_mask_0_to_1_neutral_0"
	},
	"terrain_contact_features": {
		"r": "near_surface_terrain_or_world_contact_mask_0_to_1_neutral_0",
		"g": "shallow_depth_mask_0_to_1_neutral_0",
		"b": "terrain_or_world_protrusion_intersection_mask_0_to_1_neutral_0",
		"a": "contact_source_provenance_0_none_0_5_physics_fallback_1_hterrain"
	},
	"bank_response_features": {
		"r": "bank_friction_or_drag_response_0_to_1_neutral_0",
		"g": "outside_bend_wet_pressure_or_bank_pillow_candidate_0_to_1_neutral_0",
		"b": "inside_bend_shallow_or_deposition_candidate_0_to_1_neutral_0",
		"a": "hard_boundary_or_protrusion_response_candidate_0_to_1_neutral_0"
	},
	"water_occupancy": {
		"r": "crisp_solid_mask_1_inside_obstacle_or_protrusion_0_water_neutral_0",
		"g": "solid_proximity_1_at_solid_surface_0_beyond_ramp_radius_neutral_0",
		"b": "unused_neutral_0",
		"a": "unused_neutral_1"
	}
}

const DEFAULT_IMPORT_PROFILE := {
	"color_space": "linear",
	"srgb": false,
	"compression": "uncompressed_or_lossless",
	"mipmaps": false,
	"neutral_flow": Vector2(0.5, 0.5),
	"neutral_grade_energy": 0.0,
	"neutral_bend_bias": 0.5,
	"neutral_obstacle_features": Color(0.0, 0.0, 0.0, 0.0),
	"neutral_terrain_contact_features": Color(0.0, 0.0, 0.0, 0.0),
	"neutral_bank_response_features": Color(0.0, 0.0, 0.0, 0.0),
	# Must match river_manager.gd RIVER_NEUTRAL_DISTMAP_COLOR (the code-side
	# neutral texture bound to i_distmap when dist_pressure is null). Not 0.5
	# across the board: R decodes as distance = (1 - R) * 2.
	"neutral_dist_pressure": Color(0.75, 0.25, 0.0, 0.5),
	"neutral_water_occupancy": Color(0.0, 0.0, 0.0, 1.0)
}

const TEXTURE_LAYOUT_PADDED_UV2_ATLAS := "padded_uv2_atlas_with_one_tile_margin"
const SOURCE_KIND_SPLINE_COLLISION_BAKE := "generated_spline_collision_bake"
const SOURCE_KIND_DOWNSTREAM_BASELINE_COLLISION_BAKE := "generated_downstream_baseline_collision_bake"
const SOURCE_KIND_CURVE_COLLISION_MODIFIERS_BAKE := "generated_curve_collision_modifiers_bake"
const SOURCE_KIND_CURVE_ONLY_BAKE := "generated_curve_only_bake"

@export var flow_foam_noise: Texture2D
@export var dist_pressure: Texture2D
@export var obstacle_features: Texture2D
@export var terrain_contact_features: Texture2D
@export var bank_response_features: Texture2D
# Optional - absent on bakes made before the occupancy/projection system.
@export var water_occupancy: Texture2D
@export var texture_size := Vector2i.ZERO
@export var source_texture_size := Vector2i.ZERO
@export var content_rect := Rect2i()
@export var texture_layout := TEXTURE_LAYOUT_PADDED_UV2_ATLAS
@export var uv2_sides := 0
@export var mesh_global_bounds := AABB()
@export var source_kind := SOURCE_KIND_SPLINE_COLLISION_BAKE
@export var source_metadata: Dictionary = {}
@export var channel_metadata: Dictionary = {}
@export var import_profile: Dictionary = {}
@export var bake_settings: Dictionary = {}
@export var source_signature_version := 0
@export var source_signature: Dictionary = {}


func _init() -> void:
	if channel_metadata.is_empty():
		channel_metadata = DEFAULT_CHANNEL_METADATA.duplicate(true)
	if import_profile.is_empty():
		import_profile = DEFAULT_IMPORT_PROFILE.duplicate(true)


func set_from_bake(
		new_flow_foam_noise: Texture2D,
		new_dist_pressure: Texture2D,
		new_obstacle_features: Texture2D,
		new_terrain_contact_features: Texture2D,
		new_bank_response_features: Texture2D,
		new_texture_size: Vector2i,
		new_uv2_sides: int,
		new_mesh_global_bounds: AABB,
		new_bake_settings: Dictionary,
		new_source_texture_size: Vector2i,
		new_content_rect: Rect2i,
		new_texture_layout: String,
		new_source_kind: String,
		new_source_metadata: Dictionary,
		new_source_signature: Dictionary = {},
		new_water_occupancy: Texture2D = null
) -> void:
	flow_foam_noise = new_flow_foam_noise
	dist_pressure = new_dist_pressure
	obstacle_features = new_obstacle_features
	terrain_contact_features = new_terrain_contact_features
	bank_response_features = new_bank_response_features
	water_occupancy = new_water_occupancy
	texture_size = new_texture_size
	source_texture_size = new_source_texture_size
	content_rect = new_content_rect
	texture_layout = new_texture_layout
	uv2_sides = new_uv2_sides
	mesh_global_bounds = new_mesh_global_bounds
	source_kind = new_source_kind
	source_metadata = new_source_metadata.duplicate(true)
	bake_settings = new_bake_settings.duplicate(true)
	source_signature = new_source_signature.duplicate(true)
	source_signature_version = int(source_signature.get("version", 0))
	channel_metadata = DEFAULT_CHANNEL_METADATA.duplicate(true)
	import_profile = DEFAULT_IMPORT_PROFILE.duplicate(true)


func has_required_textures() -> bool:
	return flow_foam_noise != null and dist_pressure != null and obstacle_features != null and terrain_contact_features != null and bank_response_features != null


func has_matching_source_signature(current_signature: Dictionary) -> bool:
	return not source_signature.is_empty() and source_signature == current_signature


func normalize_source_metadata() -> bool:
	var changed := false
	var terrain_contact_feature_stats = source_metadata.get("terrain_contact_feature_stats", {})
	if typeof(terrain_contact_feature_stats) == TYPE_DICTIONARY:
		var stats: Dictionary = terrain_contact_feature_stats
		if stats.has("source_confidence"):
			if not stats.has("source_provenance"):
				stats["source_provenance"] = stats["source_confidence"]
			stats.erase("source_confidence")
			source_metadata["terrain_contact_feature_stats"] = stats
			changed = true
	return changed
