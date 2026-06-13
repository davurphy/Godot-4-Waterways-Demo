// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://addons/waterways/shaders/river_flow_common.gdshaderinc"
#include "res://addons/waterways/shaders/river_surface_common.gdshaderinc"

const int EFFECTIVE_FLOWMAP = 1;
const int FOAMMAP = 2;
const int NOISEMAP = 3;

const int DISTANCEMAP = 4;
const int PRESSUREMAP = 5;

const int FLOW_PATTERN = 6;
const int FLOW_ARROWS = 7;
const int FLOW_FORCE = 8;

const int FOAM_MIX = 9;
const int RAW_FLOWMAP = 10;
const int SURFACE_STEEPNESS = 11;
const int GRADE_ENERGY = 12;
const int BEND_BIAS = 13;
const int PILLOW_MASK = 14;
const int EDDY_MASK = 15;
const int EDDY_LINE_MASK = 16;
const int OBSTACLE_CONFIDENCE = 17;
const int TERRAIN_CONTACT = 18;
const int TERRAIN_SHALLOW = 19;
const int TERRAIN_PROTRUSION = 20;
const int TERRAIN_SOURCE_PROVENANCE = 21;
const int BANK_FRICTION_DRAG = 22;
const int OUTSIDE_BEND_WET_PRESSURE = 23;
const int INSIDE_BEND_DEPOSITION = 24;
const int HARD_BOUNDARY_PROTRUSION = 25;
const int PILLOW_VISUAL_MASK = 26;
const int PILLOW_HEIGHT_MASK = 27;
const int TERRAIN_PILLOW_HEIGHT_MASK = 28;
const int OBSTRUCTION_PILLOW_HEIGHT_MASK = 29;
const int WAKE_VISUAL_MASK = 30;
const int EDDY_LINE_VISUAL_MASK = 31;
const int WAKE_EDGE_THINNESS_MASK = 32;
const int WAKE_SHARED_GATE_MASK = 33;
const int GATED_EDDY_LINE_SOURCE_MASK = 34;
const int WAKE_CONFIDENCE_GATE_MASK = 35;
const int WAKE_HARD_GATE_MASK = 36;
const int WAKE_BANK_KEEP_GATE_MASK = 37;
const int WAKE_ENERGY_GATE_MASK = 38;
const int WAKE_FLOW_GATE_MASK = 39;
const int EDDY_LINE_CONTEXT_GATE_MASK = 40;
const int EXPERIMENTAL_GATED_EDDY_LINE_SOURCE_MASK = 41;
const int EDDY_LINE_LOW_RANGE_MASK = 42;
const int EDDY_LINE_CANDIDATE_GATE_MASK = 43;
const int EDDY_LINE_HARD_CONTEXT_SEARCH_MASK = 44;
const int EDDY_LINE_WAKE_CONTEXT_SEARCH_MASK = 45;
const int RAW_WAKE_EDGE_CANDIDATE_MASK = 46;
const int EXPERIMENTAL_WAKE_EDGE_EDDY_SOURCE_MASK = 47;
const int PILLOW_VISUAL_MASK_NO_REACH_BLACK_ZERO = 48;
const int PILLOW_DIRECT_TERRAIN_ANCHOR_SEARCH = 49;
const int PILLOW_BANK_RESPONSE_ANCHOR_SEARCH = 50;
const int PILLOW_COMBINED_CONTACT_GATE = 51;
const int PILLOW_BANK_ONLY_ANCHOR_CONTRIBUTION = 52;
const int PILLOW_RAW_TO_FINAL_RETENTION = 53;
const int PILLOW_MATERIAL_RESPONSE_MASK = 54;
const int PILLOW_MATERIAL_SEAM_GUARD = 55;
const int PILLOW_HEIGHT_SEAM_GUARD = 56;
const int PILLOW_HEIGHT_SEAM_STITCH = 57;
const int PILLOW_VISUAL_MASK_BLACK_ZERO = 58;
const int BANK_FOAM_CONTRIBUTION = 59;
const int PILLOW_ANCHOR_FOAM_CONTRIBUTION = 60;
const int PILLOW_VISUAL_FOAM_CONTRIBUTION = 61;
const int RIPPLE_RAW_HEIGHT = 62;
const int RIPPLE_IMPULSE_CONTACT = 63;
const int RIPPLE_BOUNDARY_MASK = 64;
const int RIPPLE_VISIBLE_INFLUENCE = 65;

uniform int mode = 1;

uniform sampler2D debug_pattern : source_color, hint_default_black, repeat_enable, filter_linear_mipmap;
uniform sampler2D debug_arrow : source_color, hint_default_black, repeat_enable, filter_linear_mipmap;

const float EDDY_CONTEXT_CANDIDATE_GATE_START = 0.015;
const float EDDY_CONTEXT_CANDIDATE_GATE_FULL = 0.18;
// Below this speed the residual direction left by the solve near walls is
// numerically meaningless - render neutral instead of a confident arrow.
const float FLOW_ARROW_NEAR_NEUTRAL_THRESHOLD = 0.05;
const float FLOW_ARROW_DENSITY_PER_UV2_TILE = 8.0;
const float FLOW_ARROW_GLYPH_SCALE = 0.55;
// Glyphs scale with flow speed (full size at the downstream baseline speed),
// so slow wall-adjacent water reads as a small arrow rather than a
// full-confidence glyph with a noisy direction.
const float FLOW_ARROW_FULL_SPEED_REFERENCE = 0.25;
const float FLOW_ARROW_MIN_GLYPH_FRACTION = 0.45;

float mip_map_level(in vec2 texture_coordinate) {
    vec2  dx_vtc = dFdx(texture_coordinate);
    vec2  dy_vtc = dFdy(texture_coordinate);
    float delta_max_sqr = max(dot(dx_vtc, dx_vtc), dot(dy_vtc, dy_vtc));
    float mml = 0.5 * log2(delta_max_sqr);
    return max(0, mml);
}

vec3 grayscale_to_gradient(float gradient) {
	float red = clamp(mix(0.0, 2.0, gradient), 0.0, 1.0);
	float green = clamp(mix(2.0, 0.0, gradient),0.0, 1.0);
	return vec3(red, green, 0.0);
}

vec3 black_zero_to_heat(float value) {
	float v = clamp(value, 0.0, 1.0);
	if (v <= 0.0025) {
		return vec3(0.0);
	}
	vec3 weak = vec3(0.03, 0.18, 0.55);
	vec3 mid = vec3(0.04, 0.78, 0.92);
	vec3 strong = vec3(1.0, 0.88, 0.18);
	if (v < 0.5) {
		return mix(weak, mid, smoothstep(0.0, 0.5, v));
	}
	return mix(mid, strong, smoothstep(0.5, 1.0, v));
}

vec3 signed_channel_to_gradient(float packed_value) {
	float signed_value = packed_value * 2.0 - 1.0;
	vec3 negative = vec3(0.0, 0.32, 1.0);
	vec3 neutral = vec3(0.06);
	vec3 positive = vec3(1.0, 0.46, 0.0);
	if (signed_value < 0.0) {
		return mix(neutral, negative, clamp(-signed_value, 0.0, 1.0));
	}
	return mix(neutral, positive, clamp(signed_value, 0.0, 1.0));
}

vec3 source_provenance_to_color(float provenance) {
	if (provenance >= 0.75) {
		return vec3(0.05, 0.90, 0.32);
	}
	if (provenance >= 0.25) {
		return vec3(0.10, 0.42, 1.0);
	}
	return vec3(0.035);
}

float pillow_bank_response_anchor_sample(vec2 uv) {
	return textureLod(i_bank_response_features, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).a;
}

float pillow_combined_anchor_sample(vec2 uv) {
	return max(pillow_direct_terrain_anchor_sample(uv), pillow_bank_response_anchor_sample(uv));
}

float pillow_contact_search_bank_response(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction) {
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 search_offset = downstream_direction * source_tile_uv_size * PILLOW_BAKE_CONTACT_SEARCH_TILES;
	float contact = pillow_bank_response_anchor_sample(uv);
	contact = max(contact, pillow_bank_response_anchor_sample(uv + search_offset * 0.50));
	contact = max(contact, pillow_bank_response_anchor_sample(uv + search_offset));
	contact = max(contact, pillow_bank_response_anchor_sample(uv + search_offset * 1.50) * 0.65);
	return clamp(contact, 0.0, 1.0);
}

float pillow_contact_search_combined(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction) {
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 search_offset = downstream_direction * source_tile_uv_size * PILLOW_BAKE_CONTACT_SEARCH_TILES;
	float contact = pillow_combined_anchor_sample(uv);
	contact = max(contact, pillow_combined_anchor_sample(uv + search_offset * 0.50));
	contact = max(contact, pillow_combined_anchor_sample(uv + search_offset));
	contact = max(contact, pillow_combined_anchor_sample(uv + search_offset * 1.50) * 0.65);
	return clamp(contact, 0.0, 1.0);
}

float wake_edge_thinness_at(vec2 uv, vec2 source_tile_uv_size, float local_grade_energy, float normalized_flow_force, float center_wake_seed) {
	float sample_tiles = max(wake_edge_sample_tiles, 0.0);
	if (sample_tiles <= EPSILON) {
		return 1.0;
	}
	vec2 sample_offset = source_tile_uv_size * sample_tiles;
	vec2 dx = vec2(sample_offset.x, 0.0);
	vec2 dy = vec2(0.0, sample_offset.y);
	float left = wake_gated_seed_at(uv - dx, local_grade_energy, normalized_flow_force);
	float right = wake_gated_seed_at(uv + dx, local_grade_energy, normalized_flow_force);
	float up = wake_gated_seed_at(uv - dy, local_grade_energy, normalized_flow_force);
	float down = wake_gated_seed_at(uv + dy, local_grade_energy, normalized_flow_force);
	float edge_gradient = max(max(abs(left - right), abs(up - down)), max(max(abs(left - center_wake_seed), abs(right - center_wake_seed)), max(abs(up - center_wake_seed), abs(down - center_wake_seed))));
	float nearby_wake = max(max(max(left, right), max(up, down)), center_wake_seed);
	return smooth_gate(wake_eddy_edge_gate_start, wake_eddy_edge_gate_full, edge_gradient) * smooth_gate(wake_eddy_near_wake_gate_start, wake_eddy_near_wake_gate_full, nearby_wake);
}

float eddy_line_visual_mask(float wake_edge_candidate, float context_gate) {
	return clamp(wake_edge_candidate * context_gate * wake_eddy_line_strength, 0.0, 1.0);
}

float eddy_line_candidate_gate_component(vec4 obstacle_features) {
	return smooth_gate(EDDY_CONTEXT_CANDIDATE_GATE_START, EDDY_CONTEXT_CANDIDATE_GATE_FULL, obstacle_features.b);
}

float eddy_line_context_search(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, float grade_energy_map, float normalized_flow_force, int support_mode) {
	vec2 downstream = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 lateral = vec2(-downstream.y, downstream.x);
	vec2 downstream_tile = downstream * source_tile_uv_size;
	vec2 lateral_tile = lateral * source_tile_uv_size;
	float context = 0.0;
	if (support_mode == 1) {
		context = eddy_line_hard_context_support_at(uv, grade_energy_map, normalized_flow_force);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_NEAR_TILES, grade_energy_map, normalized_flow_force) * 0.95);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES, grade_energy_map, normalized_flow_force) * 0.85);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES, grade_energy_map, normalized_flow_force) * 0.70);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
		context = max(context, eddy_line_hard_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
		context = max(context, eddy_line_hard_context_support_at(uv + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
		context = max(context, eddy_line_hard_context_support_at(uv - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
	} else if (support_mode == 2) {
		context = eddy_line_wake_context_support_at(uv, grade_energy_map, normalized_flow_force);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_NEAR_TILES, grade_energy_map, normalized_flow_force) * 0.95);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES, grade_energy_map, normalized_flow_force) * 0.85);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES, grade_energy_map, normalized_flow_force) * 0.70);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
		context = max(context, eddy_line_wake_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
		context = max(context, eddy_line_wake_context_support_at(uv + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
		context = max(context, eddy_line_wake_context_support_at(uv - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
	} else {
		context = eddy_line_context_support_at(uv, grade_energy_map, normalized_flow_force);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_NEAR_TILES, grade_energy_map, normalized_flow_force) * 0.95);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES, grade_energy_map, normalized_flow_force) * 0.85);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES, grade_energy_map, normalized_flow_force) * 0.70);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
		context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
		context = max(context, eddy_line_context_support_at(uv + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
		context = max(context, eddy_line_context_support_at(uv - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
	}
	return clamp(context, 0.0, 1.0);
}

float eddy_line_context_gate(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float context = eddy_line_context_search(uv, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force, 0);

	float candidate_gate = eddy_line_candidate_gate_component(obstacle_features);
	float confidence_gate = wake_confidence_gate_component(obstacle_features);
	float bank_gate = wake_bank_keep_gate_component(terrain_contact_features, bank_response_features);
	float energy_gate = wake_energy_gate_component(grade_energy_map);
	float flow_gate = wake_flow_gate_component(normalized_flow_force);
	return clamp(candidate_gate * confidence_gate * bank_gate * energy_gate * flow_gate * context, 0.0, 1.0);
}

bool ripple_debug_mode_selected() {
	return mode == RIPPLE_RAW_HEIGHT
		|| mode == RIPPLE_IMPULSE_CONTACT
		|| mode == RIPPLE_BOUNDARY_MASK
		|| mode == RIPPLE_VISIBLE_INFLUENCE;
}

bool ripple_simulation_texture_ready() {
	ivec2 simulation_size = textureSize(i_ripple_simulation_texture, 0);
	return simulation_size.x > 1 && simulation_size.y > 1;
}

bool ripple_impulse_texture_ready() {
	ivec2 impulse_size = textureSize(i_ripple_impulse_texture, 0);
	return impulse_size.x > 1 && impulse_size.y > 1;
}

bool ripple_boundary_texture_ready() {
	ivec2 boundary_size = textureSize(i_ripple_boundary_mask, 0);
	return boundary_size.x > 1 && boundary_size.y > 1;
}

vec3 ripple_debug_color(vec3 world_position, vec3 camera_position_world) {
	vec2 ripple_uv = ripple_world_to_uv(world_position);
	if (mode == RIPPLE_RAW_HEIGHT) {
		if (!ripple_simulation_texture_ready() || ripple_uv_bounds_mask(ripple_uv) <= EPSILON) {
			return vec3(0.02);
		}
		float encoded_height = textureLod(i_ripple_simulation_texture, clamp(ripple_uv, vec2(0.0), vec2(1.0)), 0.0).r;
		return signed_channel_to_gradient(encoded_height);
	}
	if (mode == RIPPLE_IMPULSE_CONTACT) {
		if (!ripple_impulse_texture_ready() || ripple_uv_bounds_mask(ripple_uv) <= EPSILON) {
			return vec3(0.0);
		}
		return black_zero_to_heat(textureLod(i_ripple_impulse_texture, clamp(ripple_uv, vec2(0.0), vec2(1.0)), 0.0).r);
	}
	if (mode == RIPPLE_BOUNDARY_MASK) {
		return black_zero_to_heat(ripple_boundary_mask_unchecked(ripple_uv));
	}
	vec2 normal_offset = ripple_normal_offset_at_uv(ripple_uv) * ripple_distance_fade(camera_position_world, world_position);
	return black_zero_to_heat(clamp(length(normal_offset) * 2.0, 0.0, 1.0));
}

void fragment() {
	if (ripple_debug_mode_selected()) {
		ALBEDO = ripple_debug_color(ripple_fragment_world_position(INV_VIEW_MATRIX, VERTEX), CAMERA_POSITION_WORLD);
	} else {

	float safe_uv2_sides = max(float(i_uv2_sides), 1.0);
	vec2 atlas_size = max(vec2(textureSize(i_flowmap, 0)), vec2(1.0));
	vec2 source_size = max(round(atlas_size * safe_uv2_sides / (safe_uv2_sides + 2.0)), vec2(1.0));
	vec2 margin = round((atlas_size - source_size) * 0.5);
	vec2 custom_UV = (UV2 * source_size + margin) / atlas_size;
	vec2 terrain_atlas_size = max(vec2(textureSize(i_terrain_contact_features, 0)), vec2(1.0));
	vec2 terrain_texel_center_uv = (floor(clamp(custom_UV, vec2(0.0), vec2(1.0) - vec2(0.5) / terrain_atlas_size) * terrain_atlas_size) + vec2(0.5)) / terrain_atlas_size;
	vec4 flow_foam_noise = textureLod(i_flowmap, custom_UV, 0.0);
	vec4 dist_pressure_features = textureLod(i_distmap, custom_UV, 0.0);
	vec4 obstacle_features = textureLod(i_obstacle_features, custom_UV, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, custom_UV, 0.0);
	vec4 terrain_contact_features_texel = textureLod(i_terrain_contact_features, terrain_texel_center_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, custom_UV, 0.0);
	vec2 dist_pressure = dist_pressure_features.xy;
	
	vec2 encoded_flow;
	vec2 flow;
	float foam_mask;
	float noise_mask;
	float distance_map;
	float pressure_map;
	float grade_energy_channel;
	float bend_bias_channel;
	float pillow_mask;
	float eddy_mask;
	float eddy_line_mask;
	float obstacle_confidence;
	float terrain_contact;
	float terrain_shallow;
	float terrain_protrusion;
	float terrain_source_provenance;
	float bank_friction_drag;
	float outside_bend_wet_pressure;
	float inside_bend_deposition;
	float hard_boundary_protrusion;
	if (i_valid_flowmap) {
		encoded_flow = flow_foam_noise.xy;
		flow = encoded_flow;
		foam_mask = flow_foam_noise.b;
		noise_mask = flow_foam_noise.a;
		distance_map = (1.0 - dist_pressure.r) * 2.0;
		pressure_map = dist_pressure.g * 2.0;
		grade_energy_channel = dist_pressure_features.b;
		bend_bias_channel = dist_pressure_features.a;
		pillow_mask = obstacle_features.r;
		eddy_mask = obstacle_features.g;
		eddy_line_mask = obstacle_features.b;
		obstacle_confidence = obstacle_features.a;
		terrain_contact = terrain_contact_features.r;
		terrain_shallow = terrain_contact_features.g;
		terrain_protrusion = terrain_contact_features.b;
		terrain_source_provenance = terrain_contact_features_texel.a;
		bank_friction_drag = bank_response_features.r;
		outside_bend_wet_pressure = bank_response_features.g;
		inside_bend_deposition = bank_response_features.b;
		hard_boundary_protrusion = bank_response_features.a;
	} else {
		float invalid_checker = step(0.5, fract((UV.x + UV.y) * 12.0));
		ALBEDO = mix(vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), invalid_checker);
	}
if (i_valid_flowmap) {
	flow = (flow - 0.5) * 2.0; // unpack flowmap
	vec2 raw_flow = flow;
	float hard_boundary_context = clamp(max(hard_boundary_protrusion, terrain_protrusion), 0.0, 1.0);
	if (!i_flow_projected) {
		flow = apply_contextual_flow_slide(flow, custom_UV, 1.0 / atlas_size, hard_boundary_context);
	}
	vec2 occupancy_rg = water_occupancy_at(custom_UV);
	
	// calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
	
	float signed_bend_bias = bend_bias_channel * 2.0 - 1.0;
	float ordinary_bank = clamp(bank_friction_drag * (1.0 - hard_boundary_context), 0.0, 1.0);
	float pressure_gate_base = 1.0 - clamp((ordinary_bank + terrain_shallow * 0.35) * flow_pressure_bank_gate, 0.0, 0.95);
	float pressure_gate = clamp(mix(pressure_gate_base, clamp(flow_hard_boundary_pressure, 0.0, 1.0), hard_boundary_context), 0.0, 1.0);
	pressure_gate = max(pressure_gate, outside_bend_wet_pressure * 0.35);
	float grade_resistance = 1.0 - clamp(max(ordinary_bank, terrain_shallow) * 0.35, 0.0, 0.65);
	float context_drag = ordinary_bank * flow_bank_drag + terrain_shallow * flow_shallow_drag + inside_bend_deposition * flow_inside_bend_drag + hard_boundary_context * max(flow_bank_drag, flow_shallow_drag) * 0.20;
	context_drag *= 1.0 - outside_bend_wet_pressure * 0.25;
	context_drag = clamp(context_drag, 0.0, 0.85);
	float flow_force = clamp(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure * pressure_gate + grade_energy_channel * flow_grade_energy * grade_resistance + signed_bend_bias * flow_bend_bias, 0.0, flow_max);
	flow_force *= 1.0 - context_drag;
	float normalized_flow_force = clamp(flow_force / max(flow_max, EPSILON), 0.0, 1.0);
	vec2 pillow_reach_direction = safe_direction(flow, vec2(0.0, 1.0));
	vec2 source_tile_uv_size = (source_size / safe_uv2_sides) / atlas_size;
	float pillow_visual_no_reach = pillow_visual_mask(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_channel, normalized_flow_force);
	float pillow_visual = pillow_visual_mask_with_reach(custom_UV, source_tile_uv_size, pillow_reach_direction, obstacle_features, terrain_contact_features, bank_response_features, grade_energy_channel, normalized_flow_force);
	float pillow_obstruction_height_visual = pillow_obstruction_height_mask_with_reach(custom_UV, source_tile_uv_size, pillow_reach_direction, obstacle_features, terrain_contact_features, bank_response_features, grade_energy_channel, normalized_flow_force);
	float pillow_smoothed_height_visual = pillow_smoothed_visual_height_mask(pillow_visual, custom_UV, source_tile_uv_size, pillow_reach_direction, grade_energy_channel, normalized_flow_force);
	float pillow_smoothed_obstruction_height_visual = pillow_smoothed_obstruction_height_mask(pillow_obstruction_height_visual, custom_UV, source_tile_uv_size, pillow_reach_direction, grade_energy_channel, normalized_flow_force);
	float pillow_height_stitch = pillow_height_seam_stitch_weight(UV2, UV, safe_uv2_sides);
	pillow_smoothed_height_visual = pillow_seam_stitched_visual_height_mask(pillow_smoothed_height_visual, custom_UV, 1.0 / atlas_size, source_tile_uv_size, pillow_reach_direction, grade_energy_channel, normalized_flow_force, pillow_height_stitch);
	pillow_smoothed_obstruction_height_visual = pillow_seam_stitched_obstruction_height_mask(pillow_smoothed_obstruction_height_visual, custom_UV, 1.0 / atlas_size, source_tile_uv_size, pillow_reach_direction, grade_energy_channel, normalized_flow_force, pillow_height_stitch);
	float pillow_height_seam_fade = pillow_height_tile_seam_fade_mask(UV2, UV, safe_uv2_sides);
	float pillow_height_seam_guard = 1.0 - pillow_height_seam_fade;
	float pillow_material_seam_fade = pillow_material_tile_seam_fade_mask(UV2, UV, safe_uv2_sides);
	float pillow_material_visual = pillow_visual * pillow_material_seam_fade;
	float pillow_material_seam_guard = 1.0 - pillow_material_seam_fade;
	float pillow_direct_terrain_anchor_search = pillow_contact_search_direct_terrain(custom_UV, source_tile_uv_size, pillow_reach_direction);
	float pillow_bank_response_anchor_search = pillow_contact_search_bank_response(custom_UV, source_tile_uv_size, pillow_reach_direction);
	float pillow_direct_contact_gate = pillow_bake_contact_gate(pillow_direct_terrain_anchor_search);
	float pillow_bank_context_gate = pillow_bake_contact_gate(pillow_bank_response_anchor_search);
	float pillow_combined_contact_gate = clamp(pillow_direct_contact_gate * mix(0.85, 1.0, pillow_bank_context_gate), 0.0, 1.0);
	float pillow_bank_only_anchor_contribution = clamp(pillow_bank_context_gate - pillow_direct_contact_gate, 0.0, 1.0);
	float pillow_raw_to_final_retention = pillow_mask > EPSILON ? clamp(pillow_visual_no_reach / pillow_mask, 0.0, 1.0) : 0.0;
	float wake_shared_gate_visual = wake_shared_gate(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_channel, normalized_flow_force);
	float wake_confidence_gate_visual = wake_confidence_gate_component(obstacle_features);
	float wake_hard_gate_visual = wake_hard_gate_component(terrain_contact_features, bank_response_features);
	float wake_bank_keep_gate_visual = wake_bank_keep_gate_component(terrain_contact_features, bank_response_features);
	float wake_energy_gate_visual = wake_energy_gate_component(grade_energy_channel);
	float wake_flow_gate_visual = wake_flow_gate_component(normalized_flow_force);
	float wake_seed_visual = clamp(obstacle_features.g * wake_shared_gate_visual, 0.0, 1.0);
	float wake_visual = clamp(wake_seed_visual * wake_strength, 0.0, 1.0);
	float wake_edge_thinness = wake_edge_thinness_at(custom_UV, source_tile_uv_size, grade_energy_channel, normalized_flow_force, wake_seed_visual);
	float raw_wake_edge_candidate = raw_wake_edge_candidate_at(custom_UV, source_tile_uv_size);
	float gated_eddy_line_source = clamp(obstacle_features.b * wake_shared_gate_visual, 0.0, 1.0);
	float eddy_line_low_range = clamp(obstacle_features.b * 4.0, 0.0, 1.0);
	float eddy_line_candidate_gate_visual = eddy_line_candidate_gate_component(obstacle_features);
	float eddy_line_hard_context_search_visual = eddy_line_context_search(custom_UV, source_tile_uv_size, pillow_reach_direction, grade_energy_channel, normalized_flow_force, 1);
	float eddy_line_wake_context_search_visual = eddy_line_context_search(custom_UV, source_tile_uv_size, pillow_reach_direction, grade_energy_channel, normalized_flow_force, 2);
	float eddy_line_context_gate_visual = eddy_line_context_gate(custom_UV, source_tile_uv_size, pillow_reach_direction, obstacle_features, terrain_contact_features, bank_response_features, grade_energy_channel, normalized_flow_force);
	float experimental_gated_eddy_line_source = clamp(obstacle_features.b * eddy_line_context_gate_visual, 0.0, 1.0);
	float wake_edge_context_gate = clamp(max(eddy_line_hard_context_search_visual, eddy_line_wake_context_search_visual) * wake_bank_keep_gate_visual * wake_energy_gate_visual * wake_flow_gate_visual, 0.0, 1.0);
	float experimental_wake_edge_eddy_source = clamp(raw_wake_edge_candidate * wake_edge_context_gate, 0.0, 1.0);
	float eddy_line_visual = eddy_line_visual_mask(raw_wake_edge_candidate, wake_edge_context_gate);
	// Mirror river.gdshader: lee-side wake damping + occupancy stilling ramp.
	flow_force *= 1.0 - clamp(flow_wake_damping, 0.0, 1.0) * wake_seed_visual;
	flow_force *= occupancy_speed_factor(occupancy_rg);
	flow *= flow_force;
	float foam_randomness = texture(i_texture_foam_noise, UV * uv_scale.xy).r;
	float bank_friction_edge = bank_friction_edge_mask(custom_UV, 1.0 / atlas_size);
	float bank_foam_contribution = bank_friction_edge * clamp(foam_bank_friction_bias, 0.0, 2.0) * max(grade_energy_channel, normalized_flow_force) * foam_randomness;
	float pillow_anchor_foam_contribution = pillow_direct_contact_gate * clamp(foam_pillow_anchor_bias, 0.0, 2.0) * max(grade_energy_channel, normalized_flow_force) * foam_randomness;
	float pillow_visual_foam_contribution = pillow_visual * clamp(foam_pillow_visual_bias, 0.0, 2.0) * max(grade_energy_channel, normalized_flow_force) * foam_randomness;
	
	if(mode == EFFECTIVE_FLOWMAP) {
		ALBEDO = vec3(clamp(flow * 0.5 + 0.5, vec2(0.0), vec2(1.0)), 0.0);
		
	} else if(mode == FOAMMAP) {
		ALBEDO = vec3(foam_mask);
		
	} else if(mode == NOISEMAP) {
		ALBEDO = vec3(noise_mask);
		
	} else if(mode == FLOW_PATTERN) {
		vec2 jump = vec2(0.24, 0.2083333);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump, uv_scale, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump, uv_scale, time, true);

		vec2 pattern_uv_grad_x = dFdx(UV) * uv_scale.xy;
		vec2 pattern_uv_grad_y = dFdy(UV) * uv_scale.xy;
		vec3 pattern_a = textureGrad(debug_pattern, flow_uvA.xy, pattern_uv_grad_x, pattern_uv_grad_y).rgb;
		vec3 pattern_b = textureGrad(debug_pattern, flow_uvB.xy, pattern_uv_grad_x, pattern_uv_grad_y).rgb;
		
		vec3 pattern = pattern_a * flow_uvA.z + pattern_b * flow_uvB.z;
		
		ALBEDO = pattern;
		
	} else if(mode == FLOW_ARROWS) {
		vec2 source_UV = clamp(UV2, vec2(0.0), vec2(1.0));
		vec2 tiled_UV_raw = source_UV * safe_uv2_sides * FLOW_ARROW_DENSITY_PER_UV2_TILE;
		vec2 tiled_UV = fract(tiled_UV_raw) - 0.5;
		vec2 arrow_source_UV = (floor(tiled_UV_raw) + vec2(0.5)) / (safe_uv2_sides * FLOW_ARROW_DENSITY_PER_UV2_TILE);
		vec2 arrow_custom_UV = (arrow_source_UV * source_size + margin) / atlas_size;
		vec2 arrow_flow = textureLod(i_flowmap, arrow_custom_UV, 0.0).rg * 2.0 - 1.0;
		vec4 arrow_terrain_contact_features = textureLod(i_terrain_contact_features, arrow_custom_UV, 0.0);
		vec4 arrow_bank_response_features = textureLod(i_bank_response_features, arrow_custom_UV, 0.0);
		float arrow_hard_boundary_context = clamp(max(arrow_bank_response_features.a, arrow_terrain_contact_features.b), 0.0, 1.0);
		if (!i_flow_projected) {
			arrow_flow = apply_contextual_flow_slide(arrow_flow, arrow_custom_UV, 1.0 / atlas_size, arrow_hard_boundary_context);
		}
		// Stilled/solid texels read as neutral arrows instead of full-speed glyphs.
		arrow_flow *= occupancy_speed_factor(water_occupancy_at(arrow_custom_UV));
		// An arrow cell spans ~1/8 of the river width but samples one texel at
		// its center. A cell straddling a solid rim (rock waterline footprint)
		// would paint fully dark even though most of it is flowing water, so
		// when the center is neutral, probe sub-cell offsets and represent the
		// cell with the strongest open-water flow found. Cells entirely inside
		// solids stay dark.
		if (length(arrow_flow) <= FLOW_ARROW_NEAR_NEUTRAL_THRESHOLD) {
			vec2 cell_size_source_uv = vec2(1.0) / (safe_uv2_sides * FLOW_ARROW_DENSITY_PER_UV2_TILE);
			for (int probe_index = 0; probe_index < 4; probe_index++) {
				vec2 probe_sign = vec2(
					probe_index % 2 == 0 ? -1.0 : 1.0,
					probe_index < 2 ? -1.0 : 1.0
				);
				vec2 probe_source_UV = clamp(arrow_source_UV + probe_sign * cell_size_source_uv * 0.3, vec2(0.0), vec2(1.0));
				vec2 probe_custom_UV = (probe_source_UV * source_size + margin) / atlas_size;
				vec2 probe_flow = textureLod(i_flowmap, probe_custom_UV, 0.0).rg * 2.0 - 1.0;
				probe_flow *= occupancy_speed_factor(water_occupancy_at(probe_custom_UV));
				if (length(probe_flow) > length(arrow_flow)) {
					arrow_flow = probe_flow;
				}
			}
		}
		// Near-neutral packed RG has an unstable numeric angle; show it as neutral.
		float arrow_speed = length(arrow_flow);
		if (arrow_speed <= FLOW_ARROW_NEAR_NEUTRAL_THRESHOLD) {
			ALBEDO = vec3(0.04);
		} else {
			float speed_fraction = clamp(arrow_speed / FLOW_ARROW_FULL_SPEED_REFERENCE, 0.0, 1.0);
			float glyph_scale = FLOW_ARROW_GLYPH_SCALE * mix(FLOW_ARROW_MIN_GLYPH_FRACTION, 1.0, speed_fraction);
			float rotation = atan(arrow_flow.y, arrow_flow.x) - 3.14 / 2.0;
			float cosine = cos(rotation);
			float sine = sin(rotation);
			mat2 rotation_mat = mat2(vec2(cosine, -sine), vec2(sine, cosine));
			vec2 arrow_local_uv = rotation_mat * tiled_UV;
			vec2 new_uv = arrow_local_uv / glyph_scale + 0.5;
			float lod = mip_map_level(tiled_UV_raw * vec2(textureSize(debug_arrow, 0)));
			if (abs(arrow_local_uv.x) > 0.5 * glyph_scale || abs(arrow_local_uv.y) > 0.5 * glyph_scale) {
				ALBEDO = vec3(0.0, 0.5, 1.0);
			} else {
				ALBEDO = textureLod(debug_arrow, new_uv, lod).rgb;
			}
		}
		
	} else if(mode == FLOW_FORCE) {
		float gradient = clamp(mix(0.0, 1.0, flow_force / max(flow_max, EPSILON)), 0.0, 1.0);
		ALBEDO = grayscale_to_gradient(gradient);

	} else if(mode == RAW_FLOWMAP) {
		ALBEDO = vec3(encoded_flow, 0.0);

	} else if(mode == SURFACE_STEEPNESS) {
		ALBEDO = grayscale_to_gradient(clamp(steepness_map / 4.0, 0.0, 1.0));

	} else if(mode == GRADE_ENERGY) {
		ALBEDO = grayscale_to_gradient(grade_energy_channel);

	} else if(mode == BEND_BIAS) {
		ALBEDO = signed_channel_to_gradient(bend_bias_channel);

	} else if(mode == PILLOW_MASK) {
		ALBEDO = grayscale_to_gradient(pillow_mask);

	} else if(mode == PILLOW_VISUAL_MASK) {
		ALBEDO = grayscale_to_gradient(pillow_visual);

	} else if(mode == PILLOW_VISUAL_MASK_BLACK_ZERO) {
		ALBEDO = black_zero_to_heat(pillow_visual);

	} else if(mode == PILLOW_VISUAL_MASK_NO_REACH_BLACK_ZERO) {
		ALBEDO = black_zero_to_heat(pillow_visual_no_reach);

	} else if(mode == PILLOW_DIRECT_TERRAIN_ANCHOR_SEARCH) {
		ALBEDO = black_zero_to_heat(pillow_direct_terrain_anchor_search);

	} else if(mode == PILLOW_BANK_RESPONSE_ANCHOR_SEARCH) {
		ALBEDO = black_zero_to_heat(pillow_bank_response_anchor_search);

	} else if(mode == PILLOW_COMBINED_CONTACT_GATE) {
		ALBEDO = black_zero_to_heat(pillow_combined_contact_gate);

	} else if(mode == PILLOW_BANK_ONLY_ANCHOR_CONTRIBUTION) {
		ALBEDO = black_zero_to_heat(pillow_bank_only_anchor_contribution);

	} else if(mode == PILLOW_RAW_TO_FINAL_RETENTION) {
		ALBEDO = black_zero_to_heat(pillow_raw_to_final_retention);

	} else if(mode == PILLOW_MATERIAL_RESPONSE_MASK) {
		ALBEDO = black_zero_to_heat(pillow_material_visual);

	} else if(mode == PILLOW_MATERIAL_SEAM_GUARD) {
		ALBEDO = black_zero_to_heat(pillow_material_seam_guard);

	} else if(mode == PILLOW_HEIGHT_SEAM_GUARD) {
		ALBEDO = black_zero_to_heat(pillow_height_seam_guard);

	} else if(mode == PILLOW_HEIGHT_SEAM_STITCH) {
		ALBEDO = black_zero_to_heat(pillow_height_stitch);

	} else if(mode == PILLOW_HEIGHT_MASK) {
		float terrain_height_mask = pillow_height_influence(pillow_smoothed_height_visual, pillow_terrain_height_curve) * pillow_height_seam_fade;
		float obstruction_height_mask = pillow_height_influence(pillow_smoothed_obstruction_height_visual, pillow_obstruction_height_curve) * pillow_height_seam_fade;
		float height_mask = max(terrain_height_mask, obstruction_height_mask);
		ALBEDO = black_zero_to_heat(height_mask);

	} else if(mode == TERRAIN_PILLOW_HEIGHT_MASK) {
		float height_mask = pillow_height_influence(pillow_smoothed_height_visual, pillow_terrain_height_curve) * pillow_height_seam_fade;
		ALBEDO = black_zero_to_heat(height_mask);

	} else if(mode == OBSTRUCTION_PILLOW_HEIGHT_MASK) {
		float height_mask = pillow_height_influence(pillow_smoothed_obstruction_height_visual, pillow_obstruction_height_curve) * pillow_height_seam_fade;
		ALBEDO = black_zero_to_heat(height_mask);

	} else if(mode == EDDY_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_mask);

	} else if(mode == EDDY_LINE_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_mask);

	} else if(mode == WAKE_VISUAL_MASK) {
		ALBEDO = grayscale_to_gradient(wake_visual);

	} else if(mode == EDDY_LINE_VISUAL_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_visual);

	} else if(mode == WAKE_EDGE_THINNESS_MASK) {
		ALBEDO = grayscale_to_gradient(wake_edge_thinness);

	} else if(mode == WAKE_SHARED_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(wake_shared_gate_visual);

	} else if(mode == GATED_EDDY_LINE_SOURCE_MASK) {
		ALBEDO = grayscale_to_gradient(gated_eddy_line_source);

	} else if(mode == WAKE_CONFIDENCE_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(wake_confidence_gate_visual);

	} else if(mode == WAKE_HARD_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(wake_hard_gate_visual);

	} else if(mode == WAKE_BANK_KEEP_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(wake_bank_keep_gate_visual);

	} else if(mode == WAKE_ENERGY_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(wake_energy_gate_visual);

	} else if(mode == WAKE_FLOW_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(wake_flow_gate_visual);

	} else if(mode == EDDY_LINE_CONTEXT_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_context_gate_visual);

	} else if(mode == EXPERIMENTAL_GATED_EDDY_LINE_SOURCE_MASK) {
		ALBEDO = grayscale_to_gradient(experimental_gated_eddy_line_source);

	} else if(mode == EDDY_LINE_LOW_RANGE_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_low_range);

	} else if(mode == EDDY_LINE_CANDIDATE_GATE_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_candidate_gate_visual);

	} else if(mode == EDDY_LINE_HARD_CONTEXT_SEARCH_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_hard_context_search_visual);

	} else if(mode == EDDY_LINE_WAKE_CONTEXT_SEARCH_MASK) {
		ALBEDO = grayscale_to_gradient(eddy_line_wake_context_search_visual);

	} else if(mode == RAW_WAKE_EDGE_CANDIDATE_MASK) {
		ALBEDO = grayscale_to_gradient(raw_wake_edge_candidate);

	} else if(mode == EXPERIMENTAL_WAKE_EDGE_EDDY_SOURCE_MASK) {
		ALBEDO = grayscale_to_gradient(experimental_wake_edge_eddy_source);

	} else if(mode == OBSTACLE_CONFIDENCE) {
		ALBEDO = grayscale_to_gradient(obstacle_confidence);

	} else if(mode == TERRAIN_CONTACT) {
		ALBEDO = grayscale_to_gradient(terrain_contact);

	} else if(mode == TERRAIN_SHALLOW) {
		ALBEDO = grayscale_to_gradient(terrain_shallow);

	} else if(mode == TERRAIN_PROTRUSION) {
		ALBEDO = grayscale_to_gradient(terrain_protrusion);

	} else if(mode == TERRAIN_SOURCE_PROVENANCE) {
		ALBEDO = source_provenance_to_color(terrain_source_provenance);

	} else if(mode == BANK_FRICTION_DRAG) {
		ALBEDO = grayscale_to_gradient(bank_friction_drag);

	} else if(mode == OUTSIDE_BEND_WET_PRESSURE) {
		ALBEDO = grayscale_to_gradient(outside_bend_wet_pressure);

	} else if(mode == INSIDE_BEND_DEPOSITION) {
		ALBEDO = grayscale_to_gradient(inside_bend_deposition);

	} else if(mode == HARD_BOUNDARY_PROTRUSION) {
		ALBEDO = grayscale_to_gradient(hard_boundary_protrusion);

	} else if(mode == BANK_FOAM_CONTRIBUTION) {
		ALBEDO = grayscale_to_gradient(bank_foam_contribution);

	} else if(mode == PILLOW_ANCHOR_FOAM_CONTRIBUTION) {
		ALBEDO = grayscale_to_gradient(pillow_anchor_foam_contribution);

	} else if(mode == PILLOW_VISUAL_FOAM_CONTRIBUTION) {
		ALBEDO = grayscale_to_gradient(pillow_visual_foam_contribution);
		
	} else if(mode == FOAM_MIX) {
		
		vec2 jump1 = vec2(0.24, 0.2083333);
		vec2 jump2 = vec2(0.20, 0.25);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump1, uv_scale, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump1, uv_scale, time, true);
		vec3 flowx2_uvA = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, false);
		vec3 flowx2_uvB = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, true);
		
		// Match river.gdshader: continuous base-UV gradients avoid the
		// phase-wrap mip seams that draw dashed contour artifacts.
		vec2 water_uv_grad_x = dFdx(UV) * uv_scale.xy;
		vec2 water_uv_grad_y = dFdy(UV) * uv_scale.xy;
		vec3 water_a = textureGrad(normal_bump_texture, flow_uvA.xy, water_uv_grad_x, water_uv_grad_y).rgb;
		vec3 water_b = textureGrad(normal_bump_texture, flow_uvB.xy, water_uv_grad_x, water_uv_grad_y).rgb;
		vec3 waterx2_a = textureGrad(normal_bump_texture, flowx2_uvA.xy, water_uv_grad_x * 2.0, water_uv_grad_y * 2.0).rgb;
		vec3 waterx2_b = textureGrad(normal_bump_texture, flowx2_uvB.xy, water_uv_grad_x * 2.0, water_uv_grad_y * 2.0).rgb;
		vec3 water = water_a * flow_uvA.z + water_b * flow_uvB.z;
		vec3 waterx2 = waterx2_a * flowx2_uvA.z + waterx2_b * flowx2_uvB.z;
		
		float water_foamFBM = water.b; // LOD1
		water_foamFBM *= waterx2.b * 2.0; // LOD0 - add second level of detail
		float wake_noise_scale = max(wake_fleck_noise_scale, 1.0);
		float wake_noise = texture(i_texture_foam_noise, UV * uv_scale.xy * wake_noise_scale + vec2(flow_foam_noise.a * 3.17, time * 0.017)).r;
		float wake_fleck_noise = smoothstep(0.62, 0.98, wake_noise);
		float eddy_noise = texture(i_texture_foam_noise, UV * uv_scale.xy * wake_noise_scale * 1.65 - vec2(time * 0.021, flow_foam_noise.a * 2.41)).r;
		float eddy_fleck_noise = smoothstep(0.58, 0.96, eddy_noise);
		foam_mask += (steepness_map * foam_steepness + grade_energy_channel * foam_energy_bias) * foam_randomness;
		foam_mask += bank_foam_contribution;
		foam_mask += pillow_anchor_foam_contribution;
		foam_mask += pillow_visual_foam_contribution;
		foam_mask += pillow_material_visual * pillow_foam_bias * grade_energy_channel * normalized_flow_force * foam_randomness * smoothstep(0.35, 0.8, water_foamFBM);
		foam_mask += wake_visual * wake_foam_fleck_bias * grade_energy_channel * normalized_flow_force * wake_fleck_noise * smoothstep(0.45, 0.85, water_foamFBM);
		foam_mask += eddy_line_visual * wake_eddy_line_foam_bias * max(grade_energy_channel, normalized_flow_force) * (0.25 + eddy_fleck_noise * 0.75) * smoothstep(0.25, 0.78, water_foamFBM);
		foam_mask = clamp(foam_mask, 0.0, 1.0);
		
		float safe_foam_amount = max(foam_amount, EPSILON);
		water_foamFBM = clamp((water_foamFBM * foam_amount) - (0.5 / safe_foam_amount), 0.0, 1.0);
		
		float foam_smooth = clamp(water_foamFBM * foam_mask, 0.0, 1.0);
		float foam_sharp = clamp(water_foamFBM - (1.0 - foam_mask), 0.0, 1.0);
		float combined_foam = mix(foam_sharp, foam_smooth, foam_smoothness);
		
		ALBEDO = vec3(combined_foam);
		
	} else if(mode == DISTANCEMAP) {
		ALBEDO = vec3(dist_pressure.r);
		
	} else if(mode == PRESSUREMAP) {
		ALBEDO = vec3(dist_pressure.g);
		
	} else {
		ALBEDO = vec3(1.0, 0.0, 1.0);
	}
	}
	}
	ALPHA = 1.0;
}
