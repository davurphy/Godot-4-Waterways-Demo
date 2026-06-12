// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx, cull_disabled;

// If you are making your own shader, you can customize or add your own
// parameters below and they will automatically get parsed and displayed in
// the River inspector.

// Use prefixes: albedo_, emission_, transparency_, flow_, foam_, pillow_, wake_ and custom_
// to automatically put your parameters into categories in the inspector.

// If "curve" is in the name and no explicit shader hint is provided,
// the inspector will represent an easing curve.
// mat4´s with "color" in their name will get parsed as gradients.

// Main
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform sampler2D normal_bump_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.25;

// Albedo
uniform mat4 albedo_color = mat4(vec4(0.0, 0.15, 0.0, 0.0), vec4(0.8, 0.2, 0.0, 0.0), vec4(1.0, 0.5, 0.0, 0.0), vec4(0.0));
uniform float albedo_depth : hint_range(0.0, 200.0) = 10.0;
uniform float albedo_depth_curve = 0.25;

// Transparency
uniform float transparency_clarity : hint_range(0.0, 200.0) = 10.0;
uniform float transparency_depth_curve = 0.25;
uniform float transparency_refraction : hint_range(-1.0, 1.0) = 0.05;

// Flow
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_grade_energy : hint_range(0.0, 8.0) = 1.0;
uniform float flow_bend_bias : hint_range(0.0, 8.0) = 0.5;
uniform float flow_bank_drag : hint_range(0.0, 1.0) = 0.55;
uniform float flow_shallow_drag : hint_range(0.0, 1.0) = 0.35;
uniform float flow_inside_bend_drag : hint_range(0.0, 1.0) = 0.25;
uniform float flow_pressure_bank_gate : hint_range(0.0, 1.0) = 0.75;
uniform float flow_hard_boundary_pressure : hint_range(0.0, 1.0) = 0.45;
uniform float flow_hard_boundary_slide : hint_range(0.0, 1.0) = 0.45;
uniform float flow_hard_boundary_min_downstream : hint_range(0.0, 1.0) = 0.55;
uniform float flow_boundary_probe : hint_range(0.25, 4.0) = 1.0;
uniform float flow_wake_damping : hint_range(0.0, 1.0) = 0.6;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;

// Foam
uniform vec4 foam_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float foam_amount : hint_range(0.0, 4.0) = 2.0;
uniform float foam_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float foam_energy_bias : hint_range(0.0, 8.0) = 0.5;
uniform float foam_bank_friction_bias : hint_range(0.0, 2.0) = 0.35;
uniform float foam_pillow_anchor_bias : hint_range(0.0, 2.0) = 0.35;
uniform float foam_pillow_visual_bias : hint_range(0.0, 2.0) = 0.35;
uniform float foam_smoothness : hint_range(0.0, 1.0) = 0.3;

// Pillow
uniform float pillow_strength : hint_range(0.0, 4.0) = 1.15;
uniform float pillow_confidence_gate_start : hint_range(0.0, 1.0) = 0.07;
uniform float pillow_confidence_gate_full : hint_range(0.0, 1.0) = 0.45;
uniform float pillow_hard_gate_start : hint_range(0.0, 1.0) = 0.08;
uniform float pillow_hard_gate_full : hint_range(0.0, 1.0) = 0.45;
uniform float pillow_energy_gate_start : hint_range(0.0, 1.0) = 0.05;
uniform float pillow_energy_gate : hint_range(0.01, 1.0) = 0.35;
uniform float pillow_flow_gate_start : hint_range(0.0, 1.0) = 0.03;
uniform float pillow_flow_gate : hint_range(0.01, 1.0) = 0.28;
uniform float pillow_bank_suppression : hint_range(0.0, 1.0) = 0.85;
uniform float pillow_pressure_strength : hint_range(0.0, 2.0) = 0.50;
uniform float pillow_highlight_strength : hint_range(0.0, 2.0) = 0.60;
uniform vec4 pillow_pressure_color : source_color = vec4(0.34, 0.68, 0.78, 1.0);
uniform vec4 pillow_highlight_color : source_color = vec4(0.72, 0.92, 1.0, 1.0);
uniform float pillow_specular_boost : hint_range(0.0, 1.0) = 0.12;
uniform float pillow_roughness_reduction : hint_range(0.0, 1.0) = 0.18;
uniform float pillow_normal_strength : hint_range(0.0, 2.0) = 0.70;
uniform float pillow_band_strength : hint_range(0.0, 2.0) = 0.55;
uniform float pillow_band_scale : hint_range(1.0, 64.0) = 18.0;
uniform float pillow_foam_bias : hint_range(0.0, 2.0) = 0.14;
uniform float pillow_forward_reach_tiles : hint_range(0.0, 0.25) = 0.0;
uniform float pillow_contact_pull_tiles : hint_range(0.0, 0.25) = 0.0;
uniform float pillow_contact_pull_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pillow_terrain_height : hint_range(0.0, 0.5) = 0.0;
uniform float pillow_terrain_height_curve : hint_range(0.25, 4.0) = 1.35;
uniform float pillow_obstruction_height : hint_range(0.0, 0.5) = 0.0;
uniform float pillow_obstruction_height_curve : hint_range(0.25, 4.0) = 1.35;
uniform float pillow_height_smoothing_tiles : hint_range(0.0, 0.35) = 0.10;
uniform float pillow_height_seam_stitch_tiles : hint_range(0.0, 0.05) = 0.015;
uniform float pillow_height_tile_seam_fade : hint_range(0.0, 0.25) = 0.0;
uniform float pillow_material_tile_seam_fade : hint_range(0.0, 0.25) = 0.0;

// Wake / Eddy
uniform float wake_strength : hint_range(0.0, 2.0) = 0.70;
uniform float wake_confidence_gate_start : hint_range(0.0, 1.0) = 0.08;
uniform float wake_confidence_gate_full : hint_range(0.0, 1.0) = 0.45;
uniform float wake_hard_gate_start : hint_range(0.0, 1.0) = 0.06;
uniform float wake_hard_gate_full : hint_range(0.0, 1.0) = 0.40;
uniform float wake_energy_gate_start : hint_range(0.0, 1.0) = 0.03;
uniform float wake_energy_gate : hint_range(0.01, 1.0) = 0.35;
uniform float wake_flow_gate_start : hint_range(0.0, 1.0) = 0.03;
uniform float wake_flow_gate : hint_range(0.01, 1.0) = 0.28;
uniform float wake_bank_suppression : hint_range(0.0, 1.0) = 0.85;
uniform float wake_edge_sample_tiles : hint_range(0.0, 0.05) = 0.024;
uniform float wake_eddy_edge_gate_start : hint_range(0.0, 1.0) = 0.025;
uniform float wake_eddy_edge_gate_full : hint_range(0.0, 1.0) = 0.18;
uniform float wake_eddy_near_wake_gate_start : hint_range(0.0, 1.0) = 0.04;
uniform float wake_eddy_near_wake_gate_full : hint_range(0.0, 1.0) = 0.25;
uniform float wake_eddy_line_strength : hint_range(0.0, 2.0) = 1.85;
uniform float wake_normal_strength : hint_range(0.0, 2.0) = 0.22;
uniform float wake_eddy_line_normal_strength : hint_range(0.0, 2.0) = 0.85;
uniform float wake_roughness_boost : hint_range(0.0, 1.0) = 0.22;
uniform float wake_specular_reduction : hint_range(0.0, 1.0) = 0.12;
uniform float wake_albedo_breakup_strength : hint_range(0.0, 1.0) = 0.18;
uniform vec4 wake_breakup_color : source_color = vec4(0.42, 0.72, 0.78, 1.0);
uniform float wake_foam_fleck_bias : hint_range(0.0, 1.0) = 0.055;
uniform float wake_eddy_line_foam_bias : hint_range(0.0, 1.0) = 0.18;
uniform float wake_fleck_noise_scale : hint_range(1.0, 96.0) = 42.0;

// Internal uniforms - DO NOT CUSTOMIZE THESE
uniform float i_lod0_distance : hint_range(5.0, 200.0) = 50.0;
uniform sampler2D i_texture_foam_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D i_flowmap : repeat_disable, filter_linear;
// The real default is a neutral texel (0.75, 0.25, 0.0, 0.5) bound code-side
// by river_manager whenever dist_pressure is null - no hint_default_* can
// express it (white maxes pressure/bend, black maxes distance, bend_bias -1).
uniform sampler2D i_distmap : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D i_obstacle_features : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D i_terrain_contact_features : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D i_bank_response_features : hint_default_black, repeat_disable, filter_linear;
// R: crisp solid mask (1 = inside obstacle/protruding terrain), G: solid
// proximity (1 at the solid surface, 0 beyond the ramp radius). Absent on
// legacy bakes - the black default makes every occupancy behavior neutral.
uniform sampler2D i_water_occupancy : hint_default_black, repeat_disable, filter_linear;
// True when the baked flow field came from the pressure projection solve.
// Projected fields are divergence-free; re-bending them with the runtime
// boundary slide would corrupt them, so the slide only runs on legacy bakes.
uniform bool i_flow_projected = false;
uniform bool i_valid_flowmap = false;
uniform int i_uv2_sides = 2;
uniform bool i_ripple_enabled = false;
uniform sampler2D i_ripple_simulation_texture : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D i_ripple_impulse_texture : hint_default_black, repeat_disable, filter_linear;
uniform mat4 i_ripple_world_to_uv = mat4(1.0);
uniform sampler2D i_ripple_boundary_mask : hint_default_black, repeat_disable, filter_linear;
uniform vec2 i_ripple_texel_size = vec2(0.0);
uniform float i_ripple_normal_strength : hint_range(0.0, 4.0) = 0.0;
uniform float i_ripple_refraction_strength : hint_range(0.0, 1.0) = 0.0;
uniform float i_ripple_displacement_strength : hint_range(0.0, 1.0) = 0.0;
uniform float i_ripple_height_fade_distance : hint_range(0.0, 200.0) = 0.0;
uniform float i_ripple_boundary_fade : hint_range(0.0, 0.25) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

const float EPSILON = 0.0001;
// View-space depth band over which a refracted screen sample fades back to
// the unrefracted one when it lands in front of the water plane.
const float REFRACTION_VALID_BAND = 0.15;
const float REFRACTION_MAX_LOD = 4.0;
const float EDDY_CONTEXT_UPSTREAM_NEAR_TILES = 0.16;
const float EDDY_CONTEXT_UPSTREAM_MID_TILES = 0.38;
const float EDDY_CONTEXT_UPSTREAM_FAR_TILES = 0.70;
const float EDDY_CONTEXT_LATERAL_TILES = 0.14;
const float PILLOW_BAKE_CONTACT_SEARCH_TILES = 0.07;
const float PILLOW_BAKE_CONTACT_GATE_START = 0.08;
const float PILLOW_BAKE_CONTACT_GATE_FULL = 0.38;
// Water fades out across this band of the crisp solid mask (bilinear ramp).
const float OCCUPANCY_CLIP_START = 0.35;
const float OCCUPANCY_CLIP_FULL = 0.75;
// Advection speed recovers from 0 at the solid surface over the proximity
// ramp; openness = 1 - proximity. Full speed returns by mid-ring so the
// stilled band hugs the solid instead of deadening the whole proximity ring.
const float OCCUPANCY_SPEED_RAMP_FULL = 0.45;

vec3 FlowUVW(vec2 uv_in, vec2 flowVector, vec2 jump, vec3 tiling, float time, bool flowB) {
	float phaseOffset = flowB ? 0.5 : 0.0;
	float progress = fract(time + phaseOffset);
	vec3 uvw;
	uvw.xy = uv_in - flowVector * (progress - 0.5);
	uvw.xy *= tiling.xy;
	uvw.xy += phaseOffset;
	uvw.xy += (time - progress) * jump;
	uvw.z = 1.0 - abs(1.0 - 2.0 * progress);
	return uvw;
}

// ease implementation copied from math_funcs.cpp in source
float ease(float p_x, float p_c) {
	if (p_x < 0.0) {
		p_x = 0.0;
	} else if (p_x > 1.0) {
		p_x = 1.0;
	}
	if (p_c > 0.0) {
		if (p_c < 1.0) {
			return 1.0 - pow(1.0 - p_x, 1.0 / p_c);
		} else {
			return pow(p_x, p_c);
		}
	} else if (p_c < 0.0) {
		//inout ease
		
		if (p_x < 0.5) {
			return pow(p_x * 2.0, -p_c) * 0.5;
		} else {
			return (1.0 - pow(1.0 - (p_x - 0.5) * 2.0, -p_c)) * 0.5 + 0.5;
		}
	} else {
		return 0.0; // no ease (raw)
	}
}

float srgb_to_linear_channel(float srgb) {
	srgb = max(srgb, 0.0);
	if (srgb <= 0.04045) {
		return srgb / 12.92;
	}
	return pow((srgb + 0.055) / 1.055, 2.4);
}

mat4 gradient_srgb_to_linear(mat4 srgb_mat) {
	return mat4(
		vec4(srgb_to_linear_channel(srgb_mat[0].x), srgb_to_linear_channel(srgb_mat[0].y), srgb_to_linear_channel(srgb_mat[0].z), srgb_mat[0].w),
		vec4(srgb_to_linear_channel(srgb_mat[1].x), srgb_to_linear_channel(srgb_mat[1].y), srgb_to_linear_channel(srgb_mat[1].z), srgb_mat[1].w),
		srgb_mat[2],
		srgb_mat[3]
	);
}

float scene_view_z(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = textureLod(depth_texture, screen_uv, 0.0).r;
	vec4 view_pos = inv_projection_matrix * vec4(screen_uv * 2.0 - 1.0, depth, 1.0);
	view_pos.xyz /= view_pos.w;
	return view_pos.z;
}

vec2 safe_direction(vec2 vector, vec2 fallback) {
	float vector_length = length(vector);
	if (vector_length <= EPSILON) {
		return fallback;
	}
	return vector / vector_length;
}

vec2 keep_minimum_alignment(vec2 direction, vec2 baseline_direction, float min_alignment) {
	float floor_value = clamp(min_alignment, 0.0, 0.95);
	if (floor_value <= EPSILON) {
		return direction;
	}
	float downstream = dot(direction, baseline_direction);
	if (downstream >= floor_value) {
		return direction;
	}
	vec2 lateral = direction - baseline_direction * downstream;
	float lateral_magnitude = length(lateral);
	if (lateral_magnitude <= EPSILON) {
		return baseline_direction;
	}
	float lateral_limit = sqrt(max(0.0, 1.0 - floor_value * floor_value));
	return normalize(baseline_direction * floor_value + (lateral / lateral_magnitude) * lateral_limit);
}

vec2 water_occupancy_at(vec2 uv) {
	// R: solid mask, G: solid proximity.
	return textureLod(i_water_occupancy, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).rg;
}

float occupancy_speed_factor(vec2 occupancy_rg) {
	float openness = 1.0 - occupancy_rg.g;
	return smoothstep(0.0, OCCUPANCY_SPEED_RAMP_FULL, openness);
}

float boundary_context_at(vec2 uv) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 terrain_contact = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response = textureLod(i_bank_response_features, safe_uv, 0.0);
	float hard_context = max(bank_response.a, terrain_contact.b);
	float soft_contact = max(bank_response.r * 0.35, terrain_contact.r * 0.25);
	return clamp(max(hard_context, soft_contact), 0.0, 1.0);
}

vec2 boundary_gradient_at(vec2 uv, vec2 offset) {
	vec2 dx = vec2(offset.x, 0.0);
	vec2 dy = vec2(0.0, offset.y);
	return vec2(
		boundary_context_at(uv + dx) - boundary_context_at(uv - dx),
		boundary_context_at(uv + dy) - boundary_context_at(uv - dy)
	);
}

float bank_friction_at(vec2 uv) {
	return textureLod(i_bank_response_features, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r;
}

float bank_friction_edge_mask(vec2 uv, vec2 texel_size) {
	vec2 sample_offset = vec2(max(texel_size.x * 2.0, EPSILON), max(texel_size.y * 2.0, EPSILON));
	vec2 dx = vec2(sample_offset.x, 0.0);
	vec2 dy = vec2(0.0, sample_offset.y);
	float center = bank_friction_at(uv);
	float left = bank_friction_at(uv - dx);
	float right = bank_friction_at(uv + dx);
	float up = bank_friction_at(uv - dy);
	float down = bank_friction_at(uv + dy);
	float local_min = min(min(left, right), min(up, down));
	float local_max = max(max(left, right), max(up, down));
	float edge = local_max - local_min;
	return smoothstep(0.04, 0.24, center) * smoothstep(0.015, 0.18, edge);
}

float smooth_gate(float gate_start, float gate_full, float value) {
	float start = min(clamp(gate_start, 0.0, 1.0), 1.0 - EPSILON);
	float full = min(1.0, max(start + EPSILON, clamp(gate_full, 0.0, 1.0)));
	return smoothstep(start, full, value);
}

float pillow_direct_terrain_anchor_sample(vec2 uv) {
	return textureLod(i_terrain_contact_features, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).b;
}

float pillow_contact_search_direct_terrain(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction) {
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 search_offset = downstream_direction * source_tile_uv_size * PILLOW_BAKE_CONTACT_SEARCH_TILES;
	float contact = pillow_direct_terrain_anchor_sample(uv);
	contact = max(contact, pillow_direct_terrain_anchor_sample(uv + search_offset * 0.50));
	contact = max(contact, pillow_direct_terrain_anchor_sample(uv + search_offset));
	contact = max(contact, pillow_direct_terrain_anchor_sample(uv + search_offset * 1.50) * 0.65);
	return clamp(contact, 0.0, 1.0);
}

float pillow_bake_contact_gate(float anchor_value) {
	return smooth_gate(PILLOW_BAKE_CONTACT_GATE_START, PILLOW_BAKE_CONTACT_GATE_FULL, anchor_value);
}

float pillow_visual_mask(vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float raw_pillow = obstacle_features.r;
	float confidence_gate = smooth_gate(pillow_confidence_gate_start, pillow_confidence_gate_full, obstacle_features.a);
	float hard_boundary_context = clamp(max(bank_response_features.a, terrain_contact_features.b), 0.0, 1.0);
	float hard_gate = smooth_gate(pillow_hard_gate_start, pillow_hard_gate_full, hard_boundary_context);
	float ordinary_bank = clamp(bank_response_features.r * (1.0 - hard_boundary_context), 0.0, 1.0);
	float bank_gate = 1.0 - clamp(ordinary_bank * pillow_bank_suppression, 0.0, 0.95);
	float energy_gate = smooth_gate(pillow_energy_gate_start, pillow_energy_gate, grade_energy_map);
	float flow_gate = smooth_gate(pillow_flow_gate_start, pillow_flow_gate, normalized_flow_force);
	return clamp(raw_pillow * confidence_gate * hard_gate * bank_gate * energy_gate * flow_gate * pillow_strength, 0.0, 1.0);
}

float pillow_obstruction_height_mask(vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float raw_pillow = obstacle_features.r;
	float confidence_gate = smooth_gate(pillow_confidence_gate_start, pillow_confidence_gate_full, max(obstacle_features.a, raw_pillow));
	float hard_boundary_context = clamp(max(bank_response_features.a, terrain_contact_features.b), 0.0, 1.0);
	float ordinary_bank = clamp(bank_response_features.r * (1.0 - hard_boundary_context), 0.0, 1.0);
	float bank_gate = 1.0 - clamp(ordinary_bank * max(pillow_bank_suppression, 0.65), 0.0, 0.98);
	float energy_gate = smooth_gate(pillow_energy_gate_start, pillow_energy_gate, grade_energy_map);
	float flow_gate = smooth_gate(pillow_flow_gate_start, pillow_flow_gate, normalized_flow_force);
	return clamp(raw_pillow * confidence_gate * bank_gate * energy_gate * flow_gate * pillow_strength, 0.0, 1.0);
}

float pillow_visual_mask_at(vec2 uv, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	return pillow_visual_mask(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
}

float pillow_obstruction_height_mask_at(vec2 uv, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	return pillow_obstruction_height_mask(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
}

float pillow_visual_mask_with_reach(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float base_mask = pillow_visual_mask(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	float mask = base_mask;
	float reach = max(pillow_forward_reach_tiles, 0.0);
	if (reach > EPSILON) {
		vec2 downstream_offset = downstream_direction * source_tile_uv_size * reach;
		float forward_mask = max(
			pillow_visual_mask_at(uv + downstream_offset * 0.5, grade_energy_map, normalized_flow_force) * 0.85,
			pillow_visual_mask_at(uv + downstream_offset, grade_energy_map, normalized_flow_force) * 0.65
		);
		forward_mask = max(forward_mask, pillow_visual_mask_at(uv + downstream_offset * 1.5, grade_energy_map, normalized_flow_force) * 0.45);
		mask = max(mask, forward_mask);
	}
	float contact_pull = clamp(pillow_contact_pull_strength, 0.0, 1.0);
	float contact_pull_tiles = max(pillow_contact_pull_tiles, 0.0);
	if (contact_pull > EPSILON && contact_pull_tiles > EPSILON) {
		vec2 contact_offset = downstream_direction * source_tile_uv_size * contact_pull_tiles;
		float contact_pulled_mask = max(
			pillow_visual_mask_at(uv - contact_offset, grade_energy_map, normalized_flow_force),
			pillow_visual_mask_at(uv - contact_offset * 0.5, grade_energy_map, normalized_flow_force) * 0.75
		);
		contact_pulled_mask = max(contact_pulled_mask, pillow_visual_mask_at(uv - contact_offset * 1.5, grade_energy_map, normalized_flow_force) * 0.50);
		mask = mix(mask, contact_pulled_mask, contact_pull);
	}
	return clamp(mask, 0.0, 1.0);
}

float pillow_obstruction_height_mask_with_reach(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float base_mask = pillow_obstruction_height_mask(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	float mask = base_mask;
	float reach = max(pillow_forward_reach_tiles, 0.0);
	if (reach > EPSILON) {
		vec2 downstream_offset = downstream_direction * source_tile_uv_size * reach;
		float forward_mask = max(
			pillow_obstruction_height_mask_at(uv + downstream_offset * 0.5, grade_energy_map, normalized_flow_force) * 0.85,
			pillow_obstruction_height_mask_at(uv + downstream_offset, grade_energy_map, normalized_flow_force) * 0.65
		);
		forward_mask = max(forward_mask, pillow_obstruction_height_mask_at(uv + downstream_offset * 1.5, grade_energy_map, normalized_flow_force) * 0.45);
		mask = max(mask, forward_mask);
	}
	float contact_pull = clamp(pillow_contact_pull_strength, 0.0, 1.0);
	float contact_pull_tiles = max(pillow_contact_pull_tiles, 0.0);
	if (contact_pull > EPSILON && contact_pull_tiles > EPSILON) {
		vec2 contact_offset = downstream_direction * source_tile_uv_size * contact_pull_tiles;
		float contact_pulled_mask = max(
			pillow_obstruction_height_mask_at(uv - contact_offset, grade_energy_map, normalized_flow_force),
			pillow_obstruction_height_mask_at(uv - contact_offset * 0.5, grade_energy_map, normalized_flow_force) * 0.75
		);
		contact_pulled_mask = max(contact_pulled_mask, pillow_obstruction_height_mask_at(uv - contact_offset * 1.5, grade_energy_map, normalized_flow_force) * 0.50);
		mask = mix(mask, contact_pulled_mask, contact_pull);
	}
	return clamp(mask, 0.0, 1.0);
}

float pillow_visual_mask_with_reach_at(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	return pillow_visual_mask_with_reach(safe_uv, source_tile_uv_size, flow_direction, obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
}

float pillow_obstruction_height_mask_with_reach_at(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	return pillow_obstruction_height_mask_with_reach(safe_uv, source_tile_uv_size, flow_direction, obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
}

float pillow_smoothed_visual_height_mask(float center_mask, vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, float grade_energy_map, float normalized_flow_force) {
	float smoothing_tiles = max(pillow_height_smoothing_tiles, 0.0);
	if (smoothing_tiles <= EPSILON) {
		return clamp(center_mask, 0.0, 1.0);
	}
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 lateral_direction = vec2(-downstream_direction.y, downstream_direction.x);
	vec2 downstream_offset = downstream_direction * source_tile_uv_size * smoothing_tiles;
	vec2 lateral_offset = lateral_direction * source_tile_uv_size * smoothing_tiles;
	float axial_mask = (
		pillow_visual_mask_with_reach_at(uv + downstream_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_visual_mask_with_reach_at(uv - downstream_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_visual_mask_with_reach_at(uv + lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_visual_mask_with_reach_at(uv - lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force)
	) * 0.25;
	float diagonal_mask = (
		pillow_visual_mask_with_reach_at(uv + downstream_offset + lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_visual_mask_with_reach_at(uv + downstream_offset - lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_visual_mask_with_reach_at(uv - downstream_offset + lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_visual_mask_with_reach_at(uv - downstream_offset - lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force)
	) * 0.25;
	float smoothed_mask = center_mask * 0.50 + axial_mask * 0.35 + diagonal_mask * 0.15;
	return clamp(max(center_mask * 0.85, smoothed_mask), 0.0, 1.0);
}

float pillow_smoothed_obstruction_height_mask(float center_mask, vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, float grade_energy_map, float normalized_flow_force) {
	float smoothing_tiles = max(pillow_height_smoothing_tiles, 0.0);
	if (smoothing_tiles <= EPSILON) {
		return clamp(center_mask, 0.0, 1.0);
	}
	vec2 downstream_direction = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 lateral_direction = vec2(-downstream_direction.y, downstream_direction.x);
	vec2 downstream_offset = downstream_direction * source_tile_uv_size * smoothing_tiles;
	vec2 lateral_offset = lateral_direction * source_tile_uv_size * smoothing_tiles;
	float axial_mask = (
		pillow_obstruction_height_mask_with_reach_at(uv + downstream_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_obstruction_height_mask_with_reach_at(uv - downstream_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_obstruction_height_mask_with_reach_at(uv + lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_obstruction_height_mask_with_reach_at(uv - lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force)
	) * 0.25;
	float diagonal_mask = (
		pillow_obstruction_height_mask_with_reach_at(uv + downstream_offset + lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_obstruction_height_mask_with_reach_at(uv + downstream_offset - lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_obstruction_height_mask_with_reach_at(uv - downstream_offset + lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force) +
		pillow_obstruction_height_mask_with_reach_at(uv - downstream_offset - lateral_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force)
	) * 0.25;
	float smoothed_mask = center_mask * 0.50 + axial_mask * 0.35 + diagonal_mask * 0.15;
	return clamp(max(center_mask * 0.85, smoothed_mask), 0.0, 1.0);
}

float pillow_height_seam_stitch_weight(vec2 source_uv, vec2 mesh_uv, float safe_uv2_sides) {
	float stitch_width = max(pillow_height_seam_stitch_tiles, 0.0);
	if (stitch_width <= EPSILON) {
		return 0.0;
	}
	float atlas_local_y = fract(clamp(source_uv.y, 0.0, 1.0) * safe_uv2_sides);
	float atlas_distance_to_tile_edge = min(atlas_local_y, 1.0 - atlas_local_y);
	float step_local_y = fract(max(mesh_uv.y, 0.0));
	float step_distance_to_tile_edge = min(step_local_y, 1.0 - step_local_y);
	float seam_distance = min(atlas_distance_to_tile_edge, step_distance_to_tile_edge);
	return 1.0 - smoothstep(0.0, stitch_width, seam_distance);
}

float pillow_seam_stitched_visual_height_mask(float center_mask, vec2 uv, vec2 atlas_texel_size, vec2 source_tile_uv_size, vec2 flow_direction, float grade_energy_map, float normalized_flow_force, float stitch_weight) {
	if (stitch_weight <= EPSILON) {
		return clamp(center_mask, 0.0, 1.0);
	}
	vec2 seam_offset = vec2(0.0, atlas_texel_size.y);
	float stitched_mask = max(center_mask, max(
		pillow_visual_mask_with_reach_at(uv + seam_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force),
		pillow_visual_mask_with_reach_at(uv - seam_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force)
	));
	return clamp(mix(center_mask, stitched_mask, stitch_weight), 0.0, 1.0);
}

float pillow_seam_stitched_obstruction_height_mask(float center_mask, vec2 uv, vec2 atlas_texel_size, vec2 source_tile_uv_size, vec2 flow_direction, float grade_energy_map, float normalized_flow_force, float stitch_weight) {
	if (stitch_weight <= EPSILON) {
		return clamp(center_mask, 0.0, 1.0);
	}
	vec2 seam_offset = vec2(0.0, atlas_texel_size.y);
	float stitched_mask = max(center_mask, max(
		pillow_obstruction_height_mask_with_reach_at(uv + seam_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force),
		pillow_obstruction_height_mask_with_reach_at(uv - seam_offset, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force)
	));
	return clamp(mix(center_mask, stitched_mask, stitch_weight), 0.0, 1.0);
}

float wake_confidence_gate_component(vec4 obstacle_features) {
	return smooth_gate(wake_confidence_gate_start, wake_confidence_gate_full, obstacle_features.a);
}

float wake_hard_boundary_context_component(vec4 terrain_contact_features, vec4 bank_response_features) {
	return clamp(max(bank_response_features.a, terrain_contact_features.b), 0.0, 1.0);
}

float wake_hard_gate_component(vec4 terrain_contact_features, vec4 bank_response_features) {
	float hard_boundary_context = wake_hard_boundary_context_component(terrain_contact_features, bank_response_features);
	return smooth_gate(wake_hard_gate_start, wake_hard_gate_full, hard_boundary_context);
}

float wake_ordinary_bank_component(vec4 terrain_contact_features, vec4 bank_response_features) {
	float hard_boundary_context = wake_hard_boundary_context_component(terrain_contact_features, bank_response_features);
	return clamp(bank_response_features.r * (1.0 - hard_boundary_context), 0.0, 1.0);
}

float wake_bank_keep_gate_component(vec4 terrain_contact_features, vec4 bank_response_features) {
	float ordinary_bank = wake_ordinary_bank_component(terrain_contact_features, bank_response_features);
	return 1.0 - clamp(ordinary_bank * wake_bank_suppression, 0.0, 0.95);
}

float wake_energy_gate_component(float grade_energy_map) {
	return smooth_gate(wake_energy_gate_start, wake_energy_gate, grade_energy_map);
}

float wake_flow_gate_component(float normalized_flow_force) {
	return smooth_gate(wake_flow_gate_start, wake_flow_gate, normalized_flow_force);
}

float wake_shared_gate(vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float confidence_gate = wake_confidence_gate_component(obstacle_features);
	float hard_gate = wake_hard_gate_component(terrain_contact_features, bank_response_features);
	float bank_gate = wake_bank_keep_gate_component(terrain_contact_features, bank_response_features);
	float energy_gate = wake_energy_gate_component(grade_energy_map);
	float flow_gate = wake_flow_gate_component(normalized_flow_force);
	return clamp(confidence_gate * hard_gate * bank_gate * energy_gate * flow_gate, 0.0, 1.0);
}

float wake_gated_seed(vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	return clamp(obstacle_features.g * wake_shared_gate(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force), 0.0, 1.0);
}

float wake_gated_seed_at(vec2 uv, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	return wake_gated_seed(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
}

float wake_visual_mask(vec4 obstacle_features, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	return clamp(wake_gated_seed(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force) * wake_strength, 0.0, 1.0);
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

float raw_wake_seed_at(vec2 uv) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	return textureLod(i_obstacle_features, safe_uv, 0.0).g;
}

float raw_wake_edge_candidate_at(vec2 uv, vec2 source_tile_uv_size) {
	float sample_tiles = max(wake_edge_sample_tiles, 0.0);
	if (sample_tiles <= EPSILON) {
		return 0.0;
	}
	vec2 sample_offset = source_tile_uv_size * sample_tiles;
	vec2 dx = vec2(sample_offset.x, 0.0);
	vec2 dy = vec2(0.0, sample_offset.y);
	float center = raw_wake_seed_at(uv);
	float left = raw_wake_seed_at(uv - dx);
	float right = raw_wake_seed_at(uv + dx);
	float up = raw_wake_seed_at(uv - dy);
	float down = raw_wake_seed_at(uv + dy);
	float edge_gradient = max(max(abs(left - right), abs(up - down)), max(max(abs(left - center), abs(right - center)), max(abs(up - center), abs(down - center))));
	float nearby_wake = max(max(max(left, right), max(up, down)), center);
	return smooth_gate(wake_eddy_edge_gate_start, wake_eddy_edge_gate_full, edge_gradient) * smooth_gate(wake_eddy_near_wake_gate_start, wake_eddy_near_wake_gate_full, nearby_wake);
}

float eddy_line_hard_context_support_at(vec2 uv, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	float confidence_gate = wake_confidence_gate_component(obstacle_features);
	float hard_gate = wake_hard_gate_component(terrain_contact_features, bank_response_features);
	float bank_gate = wake_bank_keep_gate_component(terrain_contact_features, bank_response_features);
	float energy_gate = wake_energy_gate_component(grade_energy_map);
	float hard_context = hard_gate * max(confidence_gate, 0.50);
	return clamp(hard_context * bank_gate * max(energy_gate, 0.35) * max(wake_flow_gate_component(normalized_flow_force), 0.35), 0.0, 1.0);
}

float eddy_line_wake_context_support_at(vec2 uv, float local_grade_energy, float normalized_flow_force) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 obstacle_features = textureLod(i_obstacle_features, safe_uv, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, safe_uv, 0.0);
	float grade_energy_map = max(local_grade_energy, textureLod(i_distmap, safe_uv, 0.0).b);
	float confidence_gate = wake_confidence_gate_component(obstacle_features);
	float bank_gate = wake_bank_keep_gate_component(terrain_contact_features, bank_response_features);
	float energy_gate = wake_energy_gate_component(grade_energy_map);
	float wake_source_gate = smooth_gate(wake_eddy_near_wake_gate_start, wake_eddy_near_wake_gate_full, obstacle_features.g);
	float wake_context = wake_source_gate * max(confidence_gate, 0.55);
	return clamp(wake_context * bank_gate * max(energy_gate, 0.35) * max(wake_flow_gate_component(normalized_flow_force), 0.35), 0.0, 1.0);
}

float eddy_line_context_support_at(vec2 uv, float local_grade_energy, float normalized_flow_force) {
	return max(eddy_line_hard_context_support_at(uv, local_grade_energy, normalized_flow_force), eddy_line_wake_context_support_at(uv, local_grade_energy, normalized_flow_force));
}

float eddy_line_context_search(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, float grade_energy_map, float normalized_flow_force) {
	vec2 downstream = safe_direction(flow_direction, vec2(0.0, 1.0));
	vec2 lateral = vec2(-downstream.y, downstream.x);
	vec2 downstream_tile = downstream * source_tile_uv_size;
	vec2 lateral_tile = lateral * source_tile_uv_size;
	float context = eddy_line_context_support_at(uv, grade_energy_map, normalized_flow_force);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_NEAR_TILES, grade_energy_map, normalized_flow_force) * 0.95);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES, grade_energy_map, normalized_flow_force) * 0.85);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES, grade_energy_map, normalized_flow_force) * 0.70);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_MID_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.80);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
	context = max(context, eddy_line_context_support_at(uv - downstream_tile * EDDY_CONTEXT_UPSTREAM_FAR_TILES - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.62);
	context = max(context, eddy_line_context_support_at(uv + lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
	context = max(context, eddy_line_context_support_at(uv - lateral_tile * EDDY_CONTEXT_LATERAL_TILES, grade_energy_map, normalized_flow_force) * 0.65);
	return clamp(context, 0.0, 1.0);
}

float wake_edge_eddy_context_gate(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float context = eddy_line_context_search(uv, source_tile_uv_size, flow_direction, grade_energy_map, normalized_flow_force);
	float bank_gate = wake_bank_keep_gate_component(terrain_contact_features, bank_response_features);
	float energy_gate = wake_energy_gate_component(grade_energy_map);
	float flow_gate = wake_flow_gate_component(normalized_flow_force);
	return clamp(context * bank_gate * energy_gate * flow_gate, 0.0, 1.0);
}

float eddy_line_visual_mask(vec2 uv, vec2 source_tile_uv_size, vec2 flow_direction, vec4 terrain_contact_features, vec4 bank_response_features, float grade_energy_map, float normalized_flow_force) {
	float raw_wake_edge_candidate = raw_wake_edge_candidate_at(uv, source_tile_uv_size);
	float context_gate = wake_edge_eddy_context_gate(uv, source_tile_uv_size, flow_direction, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
	return clamp(raw_wake_edge_candidate * context_gate * wake_eddy_line_strength, 0.0, 1.0);
}

float contextual_flow_force(vec4 dist_pressure_features, vec4 terrain_contact_features, vec4 bank_response_features, float steepness_map) {
	vec2 dist_pressure = dist_pressure_features.xy;
	float distance_map = (1.0 - dist_pressure.r) * 2.0;
	float pressure_map = dist_pressure.g * 2.0;
	float grade_energy_map = dist_pressure_features.b;
	float bend_bias_map = dist_pressure_features.a * 2.0 - 1.0;
	float terrain_shallow = terrain_contact_features.g;
	float terrain_protrusion = terrain_contact_features.b;
	float bank_friction_drag = bank_response_features.r;
	float outside_bend_wet_pressure = bank_response_features.g;
	float inside_bend_deposition = bank_response_features.b;
	float hard_boundary_context = clamp(max(bank_response_features.a, terrain_protrusion), 0.0, 1.0);
	float ordinary_bank = clamp(bank_friction_drag * (1.0 - hard_boundary_context), 0.0, 1.0);
	float pressure_gate_base = 1.0 - clamp((ordinary_bank + terrain_shallow * 0.35) * flow_pressure_bank_gate, 0.0, 0.95);
	float pressure_gate = clamp(mix(pressure_gate_base, clamp(flow_hard_boundary_pressure, 0.0, 1.0), hard_boundary_context), 0.0, 1.0);
	pressure_gate = max(pressure_gate, outside_bend_wet_pressure * 0.35);
	float grade_resistance = 1.0 - clamp(max(ordinary_bank, terrain_shallow) * 0.35, 0.0, 0.65);
	float context_drag = ordinary_bank * flow_bank_drag + terrain_shallow * flow_shallow_drag + inside_bend_deposition * flow_inside_bend_drag + hard_boundary_context * max(flow_bank_drag, flow_shallow_drag) * 0.20;
	context_drag *= 1.0 - outside_bend_wet_pressure * 0.25;
	context_drag = clamp(context_drag, 0.0, 0.85);
	float flow_force = clamp(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure * pressure_gate + grade_energy_map * flow_grade_energy * grade_resistance + bend_bias_map * flow_bend_bias, 0.0, flow_max);
	return flow_force * (1.0 - context_drag);
}

vec2 apply_contextual_flow_slide(vec2 flow, vec2 uv, vec2 texel_size, float hard_boundary) {
	float flow_magnitude = length(flow);
	if (flow_magnitude <= EPSILON) {
		return flow;
	}
	vec2 baseline_direction = flow / flow_magnitude;
	vec2 probe_offset = texel_size * max(flow_boundary_probe, 0.25);
	vec2 boundary_gradient = boundary_gradient_at(uv, probe_offset);
	float gradient_magnitude = length(boundary_gradient);
	if (gradient_magnitude <= EPSILON) {
		return flow;
	}
	vec2 boundary_normal = boundary_gradient / gradient_magnitude;
	vec2 boundary_tangent = normalize(vec2(-boundary_normal.y, boundary_normal.x));
	float tangent_alignment = dot(boundary_tangent, baseline_direction);
	if (tangent_alignment < 0.0) {
		boundary_tangent = -boundary_tangent;
	}
	float flow_into_boundary = max(dot(baseline_direction, boundary_normal), 0.0);
	float slide_gate = clamp(hard_boundary * smoothstep(0.03, 0.35, gradient_magnitude) * mix(0.35, 1.0, flow_into_boundary), 0.0, 1.0);
	// The tangent sign flips across the obstacle's stagnation centerline
	// (flow heading straight into the boundary). Sliding at full strength
	// there shears the advected pattern in opposite lateral directions on
	// each side of a texel-quantized line - a static jagged crack through
	// every hard-boundary obstacle. Fade the slide out as the tangent
	// choice becomes ambiguous; water splits smoothly at a stagnation line.
	float slide_amount = clamp(flow_hard_boundary_slide, 0.0, 1.0) * slide_gate * smoothstep(0.0, 0.35, abs(tangent_alignment));
	if (slide_amount <= EPSILON) {
		return flow;
	}
	vec2 slide_direction = safe_direction(mix(baseline_direction, boundary_tangent, slide_amount), baseline_direction);
	slide_direction = keep_minimum_alignment(slide_direction, baseline_direction, flow_hard_boundary_min_downstream);
	return slide_direction * flow_magnitude;
}

float pillow_height_influence(float pillow_mask, float height_curve) {
	return pow(clamp(pillow_mask, 0.0, 1.0), max(height_curve, EPSILON));
}

float pillow_tile_seam_fade_mask(float seam_fade_width, vec2 source_uv, vec2 mesh_uv, float safe_uv2_sides) {
	float seam_fade = max(seam_fade_width, 0.0);
	if (seam_fade <= EPSILON) {
		return 1.0;
	}
	float atlas_local_y = fract(clamp(source_uv.y, 0.0, 1.0) * safe_uv2_sides);
	float atlas_distance_to_tile_edge = min(atlas_local_y, 1.0 - atlas_local_y);
	float atlas_fade = smoothstep(0.0, seam_fade, atlas_distance_to_tile_edge);
	float step_local_y = fract(max(mesh_uv.y, 0.0));
	float step_distance_to_tile_edge = min(step_local_y, 1.0 - step_local_y);
	float step_fade = smoothstep(0.0, seam_fade, step_distance_to_tile_edge);
	return min(atlas_fade, step_fade);
}

float pillow_height_tile_seam_fade_mask(vec2 source_uv, vec2 mesh_uv, float safe_uv2_sides) {
	return pillow_tile_seam_fade_mask(pillow_height_tile_seam_fade, source_uv, mesh_uv, safe_uv2_sides);
}

float pillow_material_tile_seam_fade_mask(vec2 source_uv, vec2 mesh_uv, float safe_uv2_sides) {
	return pillow_tile_seam_fade_mask(pillow_material_tile_seam_fade, source_uv, mesh_uv, safe_uv2_sides);
}

vec3 ripple_fragment_world_position(mat4 inv_view_matrix, vec3 view_position) {
	return (inv_view_matrix * vec4(view_position, 1.0)).xyz;
}

vec2 ripple_world_to_uv(vec3 world_position) {
	vec4 mapped = i_ripple_world_to_uv * vec4(world_position, 1.0);
	float safe_w = abs(mapped.w) > EPSILON ? mapped.w : 1.0;
	return mapped.xz / safe_w;
}

bool ripple_sampling_ready() {
	ivec2 simulation_size = textureSize(i_ripple_simulation_texture, 0);
	ivec2 boundary_size = textureSize(i_ripple_boundary_mask, 0);
	return i_ripple_enabled
		&& i_ripple_texel_size.x > EPSILON
		&& i_ripple_texel_size.y > EPSILON
		&& simulation_size.x > 1
		&& simulation_size.y > 1
		&& boundary_size.x > 1
		&& boundary_size.y > 1;
}

float ripple_uv_bounds_mask(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	float fade_width = max(i_ripple_boundary_fade, 0.0);
	if (fade_width <= EPSILON) {
		return 1.0;
	}
	float edge_distance = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	return smoothstep(0.0, fade_width, edge_distance);
}

float ripple_boundary_mask_unchecked(vec2 uv) {
	float bounds_mask = ripple_uv_bounds_mask(uv);
	if (bounds_mask <= EPSILON) {
		return 0.0;
	}
	float boundary = textureLod(i_ripple_boundary_mask, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r;
	return clamp(boundary * bounds_mask, 0.0, 1.0);
}

float ripple_decode_height(float encoded_height) {
	return encoded_height * 2.0 - 1.0;
}

float ripple_height_at_uv(vec2 uv) {
	if (!ripple_sampling_ready()) {
		return 0.0;
	}
	float mask = ripple_boundary_mask_unchecked(uv);
	if (mask <= EPSILON) {
		return 0.0;
	}
	return ripple_decode_height(textureLod(i_ripple_simulation_texture, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r) * mask;
}

float ripple_height_at_world(vec3 world_position) {
	return ripple_height_at_uv(ripple_world_to_uv(world_position));
}

float ripple_distance_fade(vec3 camera_position_world, vec3 world_position) {
	float fade_distance = max(i_ripple_height_fade_distance, 0.0);
	if (fade_distance <= EPSILON) {
		return 1.0;
	}
	float camera_distance = distance(camera_position_world, world_position);
	return 1.0 - smoothstep(fade_distance * 0.75, fade_distance, camera_distance);
}

vec2 ripple_normal_offset_at_uv(vec2 uv) {
	if (!ripple_sampling_ready() || i_ripple_normal_strength <= EPSILON) {
		return vec2(0.0);
	}
	// Sample budget for the first visible-normal path: one boundary sample and
	// three simulation height samples.
	float center_mask = ripple_boundary_mask_unchecked(uv);
	if (center_mask <= EPSILON) {
		return vec2(0.0);
	}
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec2 right_uv = clamp(uv + vec2(i_ripple_texel_size.x, 0.0), vec2(0.0), vec2(1.0));
	vec2 up_uv = clamp(uv + vec2(0.0, i_ripple_texel_size.y), vec2(0.0), vec2(1.0));
	float center_height = ripple_decode_height(textureLod(i_ripple_simulation_texture, safe_uv, 0.0).r) * center_mask;
	float right_height = ripple_decode_height(textureLod(i_ripple_simulation_texture, right_uv, 0.0).r) * center_mask;
	float up_height = ripple_decode_height(textureLod(i_ripple_simulation_texture, up_uv, 0.0).r) * center_mask;
	vec2 slope = vec2(right_height - center_height, up_height - center_height);
	return clamp(-slope * i_ripple_normal_strength, vec2(-1.0), vec2(1.0));
}

vec2 ripple_normal_offset_at_world(vec3 world_position, vec3 camera_position_world) {
	return ripple_normal_offset_at_uv(ripple_world_to_uv(world_position)) * ripple_distance_fade(camera_position_world, world_position);
}

void vertex() {
	if (i_valid_flowmap && (pillow_terrain_height > EPSILON || pillow_obstruction_height > EPSILON)) {
		float safe_uv2_sides = max(float(i_uv2_sides), 1.0);
		vec2 atlas_size = max(vec2(textureSize(i_flowmap, 0)), vec2(1.0));
		vec2 source_size = max(round(atlas_size * safe_uv2_sides / (safe_uv2_sides + 2.0)), vec2(1.0));
		vec2 margin = round((atlas_size - source_size) * 0.5);
		vec2 custom_UV = (UV2 * source_size + margin) / atlas_size;
		vec4 flow_foam_noise = textureLod(i_flowmap, custom_UV, 0.0);
		vec4 dist_pressure_features = textureLod(i_distmap, custom_UV, 0.0);
		vec4 obstacle_features = textureLod(i_obstacle_features, custom_UV, 0.0);
		vec4 terrain_contact_features = textureLod(i_terrain_contact_features, custom_UV, 0.0);
		vec4 bank_response_features = textureLod(i_bank_response_features, custom_UV, 0.0);
		vec2 flow = (flow_foam_noise.xy - vec2(0.5)) * 2.0;
		float hard_boundary_context = clamp(max(bank_response_features.a, terrain_contact_features.b), 0.0, 1.0);
		if (!i_flow_projected) {
			flow = apply_contextual_flow_slide(flow, custom_UV, 1.0 / atlas_size, hard_boundary_context);
		}
		vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
		vec3 up_viewspace = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
		float flow_force = contextual_flow_force(dist_pressure_features, terrain_contact_features, bank_response_features, steepness_map);
		float normalized_flow_force = clamp(flow_force / max(flow_max, EPSILON), 0.0, 1.0);
		vec2 source_tile_uv_size = (source_size / safe_uv2_sides) / atlas_size;
		vec2 pillow_reach_direction = safe_direction(flow, vec2(0.0, 1.0));
		float terrain_pillow_mask = pillow_visual_mask_with_reach(custom_UV, source_tile_uv_size, pillow_reach_direction, obstacle_features, terrain_contact_features, bank_response_features, dist_pressure_features.b, normalized_flow_force);
		float obstruction_pillow_mask = pillow_obstruction_height_mask_with_reach(custom_UV, source_tile_uv_size, pillow_reach_direction, obstacle_features, terrain_contact_features, bank_response_features, dist_pressure_features.b, normalized_flow_force);
		terrain_pillow_mask = pillow_smoothed_visual_height_mask(terrain_pillow_mask, custom_UV, source_tile_uv_size, pillow_reach_direction, dist_pressure_features.b, normalized_flow_force);
		obstruction_pillow_mask = pillow_smoothed_obstruction_height_mask(obstruction_pillow_mask, custom_UV, source_tile_uv_size, pillow_reach_direction, dist_pressure_features.b, normalized_flow_force);
		float pillow_height_stitch = pillow_height_seam_stitch_weight(UV2, UV, safe_uv2_sides);
		terrain_pillow_mask = pillow_seam_stitched_visual_height_mask(terrain_pillow_mask, custom_UV, 1.0 / atlas_size, source_tile_uv_size, pillow_reach_direction, dist_pressure_features.b, normalized_flow_force, pillow_height_stitch);
		obstruction_pillow_mask = pillow_seam_stitched_obstruction_height_mask(obstruction_pillow_mask, custom_UV, 1.0 / atlas_size, source_tile_uv_size, pillow_reach_direction, dist_pressure_features.b, normalized_flow_force, pillow_height_stitch);
		vec3 view_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float pillow_height_fade = 1.0 - smoothstep(i_lod0_distance * 0.75, i_lod0_distance * 1.50, -view_vertex.z);
		pillow_height_fade *= pillow_height_tile_seam_fade_mask(UV2, UV, safe_uv2_sides);
		// No pillow displacement inside solid occupancy - the surface there is
		// being clipped by the fragment stage.
		pillow_height_fade *= 1.0 - water_occupancy_at(custom_UV).r;
		float terrain_height = pillow_terrain_height * pillow_height_influence(terrain_pillow_mask, pillow_terrain_height_curve);
		float obstruction_height = pillow_obstruction_height * pillow_height_influence(obstruction_pillow_mask, pillow_obstruction_height_curve);
		VERTEX.y += (terrain_height + obstruction_height) * pillow_height_fade;
	}
}

void fragment() {
	// Sample the UV2 textures. To avoid issues with the UV2 seams, margins
	// are left on the textures, so the UV2 needs to be rescaled to cut off
	// the margins.
	float safe_uv2_sides = max(float(i_uv2_sides), 1.0);
	vec2 atlas_size = max(vec2(textureSize(i_flowmap, 0)), vec2(1.0));
	vec2 source_size = max(round(atlas_size * safe_uv2_sides / (safe_uv2_sides + 2.0)), vec2(1.0));
	vec2 margin = round((atlas_size - source_size) * 0.5);
	vec2 custom_UV = (UV2 * source_size + margin) / atlas_size;
	vec4 flow_foam_noise = textureLod(i_flowmap, custom_UV, 0.0);
	vec4 dist_pressure_features = textureLod(i_distmap, custom_UV, 0.0);
	vec4 obstacle_features = textureLod(i_obstacle_features, custom_UV, 0.0);
	vec4 terrain_contact_features = textureLod(i_terrain_contact_features, custom_UV, 0.0);
	vec4 bank_response_features = textureLod(i_bank_response_features, custom_UV, 0.0);
	vec2 dist_pressure = dist_pressure_features.xy;
	
	vec2 flow;
	float distance_map;
	float pressure_map;
	float grade_energy_map;
	float bend_bias_map;
	float terrain_shallow;
	float terrain_protrusion;
	float bank_friction_drag;
	float outside_bend_wet_pressure;
	float inside_bend_deposition;
	float hard_boundary_protrusion;
	float foam_mask;
	if (i_valid_flowmap) {
		flow = flow_foam_noise.xy;
		distance_map = (1.0 - dist_pressure.r) * 2.0;
		pressure_map = dist_pressure.g * 2.0;
		grade_energy_map = dist_pressure_features.b;
		bend_bias_map = dist_pressure_features.a * 2.0 - 1.0;
		terrain_shallow = terrain_contact_features.g;
		terrain_protrusion = terrain_contact_features.b;
		bank_friction_drag = bank_response_features.r;
		outside_bend_wet_pressure = bank_response_features.g;
		inside_bend_deposition = bank_response_features.b;
		hard_boundary_protrusion = bank_response_features.a;
		foam_mask = flow_foam_noise.b;
	} else {
		flow = vec2(0.5, 0.572);
		distance_map = 0.5;
		pressure_map = 0.5;
		grade_energy_map = 0.0;
		bend_bias_map = 0.0;
		terrain_shallow = 0.0;
		terrain_protrusion = 0.0;
		bank_friction_drag = 0.0;
		outside_bend_wet_pressure = 0.0;
		inside_bend_deposition = 0.0;
		hard_boundary_protrusion = 0.0;
		foam_mask = 0.0;
	}
	
	flow = (flow - 0.5) * 2.0; // unpack the flow vectors
	float hard_boundary_context = clamp(max(hard_boundary_protrusion, terrain_protrusion), 0.0, 1.0);
	if (!i_flow_projected) {
		flow = apply_contextual_flow_slide(flow, custom_UV, 1.0 / atlas_size, hard_boundary_context);
	}
	vec2 occupancy_rg = water_occupancy_at(custom_UV);
	
	// Calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
	
	float ordinary_bank = clamp(bank_friction_drag * (1.0 - hard_boundary_context), 0.0, 1.0);
	float pressure_gate_base = 1.0 - clamp((ordinary_bank + terrain_shallow * 0.35) * flow_pressure_bank_gate, 0.0, 0.95);
	float pressure_gate = clamp(mix(pressure_gate_base, clamp(flow_hard_boundary_pressure, 0.0, 1.0), hard_boundary_context), 0.0, 1.0);
	pressure_gate = max(pressure_gate, outside_bend_wet_pressure * 0.35);
	float grade_resistance = 1.0 - clamp(max(ordinary_bank, terrain_shallow) * 0.35, 0.0, 0.65);
	float context_drag = ordinary_bank * flow_bank_drag + terrain_shallow * flow_shallow_drag + inside_bend_deposition * flow_inside_bend_drag + hard_boundary_context * max(flow_bank_drag, flow_shallow_drag) * 0.20;
	context_drag *= 1.0 - outside_bend_wet_pressure * 0.25;
	context_drag = clamp(context_drag, 0.0, 0.85);
	float flow_force = clamp(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure * pressure_gate + grade_energy_map * flow_grade_energy * grade_resistance + bend_bias_map * flow_bend_bias, 0.0, flow_max);
	flow_force *= 1.0 - context_drag;
	float normalized_flow_force = clamp(flow_force / max(flow_max, EPSILON), 0.0, 1.0);
	vec2 pillow_reach_direction = safe_direction(flow, vec2(0.0, 1.0));
	vec2 source_tile_uv_size = (source_size / safe_uv2_sides) / atlas_size;
	float pillow_mask = pillow_visual_mask_with_reach(custom_UV, source_tile_uv_size, pillow_reach_direction, obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
	float pillow_material_mask = pillow_mask * pillow_material_tile_seam_fade_mask(UV2, UV, safe_uv2_sides);
	float wake_seed_mask = wake_gated_seed(obstacle_features, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
	float wake_mask = clamp(wake_seed_mask * wake_strength, 0.0, 1.0);
	float eddy_line_mask = eddy_line_visual_mask(custom_UV, source_tile_uv_size, pillow_reach_direction, terrain_contact_features, bank_response_features, grade_energy_map, normalized_flow_force);
	float pillow_direct_terrain_anchor_search = pillow_contact_search_direct_terrain(custom_UV, source_tile_uv_size, pillow_reach_direction);
	float pillow_direct_contact_gate = pillow_bake_contact_gate(pillow_direct_terrain_anchor_search);
	// Lee-side damping: the wake region advects slowly instead of resuming
	// full baseline speed immediately behind obstacles.
	flow_force *= 1.0 - clamp(flow_wake_damping, 0.0, 1.0) * wake_seed_mask;
	// Stilling ramp: advection speed is zero at solid boundaries/interiors
	// and recovers across the occupancy proximity ring.
	flow_force *= occupancy_speed_factor(occupancy_rg);
	flow *= flow_force;
	
	vec2 jump1 = vec2(0.24, 0.2083333);
	vec2 jump2 = vec2(0.20, 0.25);
	vec2 jump3 = vec2(0.22, 0.27);
	float time = TIME * flow_speed + flow_foam_noise.a;
	float pillow_detail_fade = 1.0 - smoothstep(i_lod0_distance * 0.75, i_lod0_distance * 1.50, -VERTEX.z);
	vec2 pillow_flow_direction = safe_direction(flow, pillow_reach_direction);
	float pillow_band_coord = dot(UV * uv_scale.xy * pillow_band_scale, pillow_flow_direction) + time * 0.35 + flow_foam_noise.a * 6.2831853;
	float pillow_band = smoothstep(0.72, 1.0, sin(pillow_band_coord * 6.2831853) * 0.5 + 0.5);
	float pillow_band_mask = pillow_material_mask * pillow_band * clamp(pillow_band_strength, 0.0, 2.0) * pillow_detail_fade;
	vec3 flow_uvA = FlowUVW(UV, flow, jump1, uv_scale, time, false);
	vec3 flow_uvB = FlowUVW(UV, flow, jump1, uv_scale, time, true);
	vec3 flowx2_uvA = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, false);
	vec3 flowx2_uvB = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, true);
	
	// The flow phase wraps along iso-lines of the per-pixel phase noise;
	// there the flow UVs jump by a whole flow vector between neighboring
	// pixels, so derivative-based mip selection picks a tiny mip along
	// those curves and draws dashed contour-shaped artifacts. Sample with
	// the continuous base-UV gradients instead.
	vec2 water_uv_grad_x = dFdx(UV) * uv_scale.xy;
	vec2 water_uv_grad_y = dFdy(UV) * uv_scale.xy;

	// Level 1 Water
	vec3 water_a = textureGrad(normal_bump_texture, flow_uvA.xy, water_uv_grad_x, water_uv_grad_y).rgb;
	vec3 water_b = textureGrad(normal_bump_texture, flow_uvB.xy, water_uv_grad_x, water_uv_grad_y).rgb;
	vec3 water = water_a * flow_uvA.z + water_b * flow_uvB.z;

	vec2 water_norFBM = water.rg;
	float water_foamFBM = water.b;

	// Level 2 Water, only add in if closer than lod 0 distance
	if (-VERTEX.z < i_lod0_distance) {
		vec3 waterx2_a = textureGrad(normal_bump_texture, flowx2_uvA.xy, water_uv_grad_x * 2.0, water_uv_grad_y * 2.0).rgb;
		vec3 waterx2_b = textureGrad(normal_bump_texture, flowx2_uvB.xy, water_uv_grad_x * 2.0, water_uv_grad_y * 2.0).rgb;
		vec3 waterx2 = waterx2_a * flowx2_uvA.z + waterx2_b * flowx2_uvB.z;

		water_norFBM *= 0.65;
		water_norFBM += waterx2.rg * 0.35;
		water_foamFBM *= waterx2.b * 2.0;
	}
	
	float foam_randomness = texture(i_texture_foam_noise, UV * uv_scale.xy).r;
	float wake_noise_scale = max(wake_fleck_noise_scale, 1.0);
	float wake_noise = texture(i_texture_foam_noise, UV * uv_scale.xy * wake_noise_scale + vec2(flow_foam_noise.a * 3.17, time * 0.017)).r;
	float wake_fleck_noise = smoothstep(0.62, 0.98, wake_noise);
	float eddy_noise = texture(i_texture_foam_noise, UV * uv_scale.xy * wake_noise_scale * 1.65 - vec2(time * 0.021, flow_foam_noise.a * 2.41)).r;
	float eddy_fleck_noise = smoothstep(0.58, 0.96, eddy_noise);
	float bank_friction_edge = bank_friction_edge_mask(custom_UV, 1.0 / atlas_size);
	float bank_foam_contribution = bank_friction_edge * clamp(foam_bank_friction_bias, 0.0, 2.0) * max(grade_energy_map, normalized_flow_force) * foam_randomness;
	float pillow_anchor_foam_contribution = pillow_direct_contact_gate * clamp(foam_pillow_anchor_bias, 0.0, 2.0) * max(grade_energy_map, normalized_flow_force) * foam_randomness;
	float pillow_visual_foam_contribution = pillow_mask * clamp(foam_pillow_visual_bias, 0.0, 2.0) * max(grade_energy_map, normalized_flow_force) * foam_randomness;
	
	foam_mask += (steepness_map * foam_steepness + grade_energy_map * foam_energy_bias) * foam_randomness;
	foam_mask += bank_foam_contribution;
	foam_mask += pillow_anchor_foam_contribution;
	foam_mask += pillow_visual_foam_contribution;
	foam_mask += pillow_material_mask * pillow_foam_bias * grade_energy_map * normalized_flow_force * foam_randomness * smoothstep(0.35, 0.8, water_foamFBM);
	foam_mask += wake_mask * wake_foam_fleck_bias * grade_energy_map * normalized_flow_force * wake_fleck_noise * smoothstep(0.45, 0.85, water_foamFBM);
	foam_mask += eddy_line_mask * wake_eddy_line_foam_bias * max(grade_energy_map, normalized_flow_force) * (0.25 + eddy_fleck_noise * 0.75) * smoothstep(0.25, 0.78, water_foamFBM);
	foam_mask = clamp(foam_mask, 0.0, 1.0);
	float safe_foam_amount = max(foam_amount, EPSILON);
	water_foamFBM = clamp((water_foamFBM * foam_amount) - (0.5 / safe_foam_amount), 0.0, 1.0);
	float foam_smooth = clamp(water_foamFBM * foam_mask, 0.0, 1.0);
	float foam_sharp = clamp(water_foamFBM - (1.0 - foam_mask), 0.0, 1.0);
	float combined_foam = mix(foam_sharp, foam_smooth, foam_smoothness);

	// Depthtest
	float scene_z = scene_view_z(SCREEN_UV, INV_PROJECTION_MATRIX);
	float water_depth = max(VERTEX.z - scene_z, 0.0);
	
	
	float alb_t = clamp(water_depth / max(albedo_depth, EPSILON), 0.0, 1.0);
	alb_t = ease(alb_t, albedo_depth_curve);
	SPECULAR = 0.25; // Supposedly clear water has approximately a 0.25 specular value
	ROUGHNESS = roughness;
	float pillow_lighting_mask = clamp((pillow_material_mask + pillow_band_mask * 0.50) * pillow_detail_fade, 0.0, 1.0);
	float wake_detail_fade = pillow_detail_fade;
	float wake_lighting_mask = clamp((wake_mask * (0.55 + wake_fleck_noise * 0.45) + eddy_line_mask * (0.65 + eddy_fleck_noise * 0.35)) * wake_detail_fade, 0.0, 1.0);
	SPECULAR = min(SPECULAR + pillow_lighting_mask * pillow_specular_boost, 1.0);
	SPECULAR = max(SPECULAR - wake_lighting_mask * wake_specular_reduction, 0.0);
	ROUGHNESS = clamp(ROUGHNESS * (1.0 - pillow_lighting_mask * pillow_roughness_reduction), 0.0, 1.0);
	ROUGHNESS = clamp(ROUGHNESS + wake_lighting_mask * wake_roughness_boost, 0.0, 1.0);
	float pillow_normal_boost = clamp((pillow_material_mask * pillow_normal_strength + pillow_band_mask * 0.50) * pillow_detail_fade, 0.0, 1.0);
	float wake_normal_boost = clamp((wake_mask * wake_normal_strength * (0.45 + wake_fleck_noise * 0.55) + eddy_line_mask * wake_eddy_line_normal_strength * (0.55 + eddy_fleck_noise * 0.45)) * wake_detail_fade, 0.0, 1.0);
	water_norFBM = clamp((water_norFBM - 0.5) * (1.0 + pillow_normal_boost + wake_normal_boost) + 0.5, vec2(0.0), vec2(1.0));
	vec3 refraction_normal_map = vec3(water_norFBM, 0.0);
	vec3 ripple_world_position = ripple_fragment_world_position(INV_VIEW_MATRIX, VERTEX);
	vec2 ripple_normal_offset = ripple_normal_offset_at_world(ripple_world_position, CAMERA_POSITION_WORLD);
	vec2 visible_normal_offset = water_norFBM * 2.0 - 1.0 + ripple_normal_offset;
	NORMAL_MAP = vec3(clamp(visible_normal_offset * 0.5 + 0.5, vec2(0.0), vec2(1.0)), 0.0);
	NORMAL_MAP_DEPTH = normal_scale * (1.0 + clamp(pillow_material_mask * pillow_normal_strength * pillow_detail_fade + wake_normal_boost, 0.0, 0.85));

	
	// Refraction - has to be done after normal is set
	vec3 unpacted_normals = refraction_normal_map * 2.0 - 1.0;
	//vec3 ref_normal = normalize( mix(NORMAL, TANGENT * unpacted_normals.x + BINORMAL * unpacted_normals.y + NORMAL, NORMAL_MAP_DEPTH) );
	vec3 ref_vector = TANGENT * unpacted_normals.x + BINORMAL * unpacted_normals.y;
	vec3 ref_normal = (length(ref_vector) > EPSILON ? normalize(ref_vector) : vec3(0.0)) * NORMAL_MAP_DEPTH * .1;
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * transparency_refraction;

	// Depthtest 2
	// A refracted sample can land on geometry in front of the water plane.
	// A hard per-pixel fallback to SCREEN_UV flickers along the screen-space
	// silhouettes of rocks and banks (the offset wiggles with the water
	// normal), drawing dashed contour shapes on the surface. Fade the offset
	// out smoothly across a validity band instead.
	float scene_z2 = scene_view_z(ref_ofs, INV_PROJECTION_MATRIX);
	float refraction_valid = smoothstep(0.0, REFRACTION_VALID_BAND, VERTEX.z - scene_z2);
	ref_ofs = mix(SCREEN_UV, ref_ofs, refraction_valid);
	scene_z2 = scene_view_z(ref_ofs, INV_PROJECTION_MATRIX);
	float water_depth2 = mix(water_depth, max(VERTEX.z - scene_z2, 0.0), refraction_valid);
	float clar_t = clamp(water_depth2 / max(transparency_clarity, EPSILON), 0.0, 1.0);
	clar_t = ease(clar_t, transparency_depth_curve);
	float ref_amount = 1.0 - clamp(clar_t + combined_foam, 0.0, 1.0);
	alb_t = clamp(water_depth2 / max(albedo_depth, EPSILON), 0.0, 1.0);
	alb_t = ease(alb_t, albedo_depth_curve);
	// Gradient colors are packed into a mat4, so Godot cannot apply source_color automatically.
	mat4 albedo_color_linear = gradient_srgb_to_linear(albedo_color);
	vec3 albedo_color_near = vec3(albedo_color_linear[0].x, albedo_color_linear[0].y, albedo_color_linear[0].z);
	vec3 albedo_color_far = vec3(albedo_color_linear[1].x, albedo_color_linear[1].y, albedo_color_linear[1].z);
	vec3 alb_mix = mix(albedo_color_near.rgb, albedo_color_far.rgb, alb_t);
	float pillow_pressure = clamp(pillow_material_mask * pillow_pressure_strength, 0.0, 0.65);
	float pillow_highlight = clamp((pillow_material_mask + pillow_band_mask) * pillow_highlight_strength, 0.0, 0.65);
	float wake_albedo_breakup = clamp((wake_mask * wake_fleck_noise + eddy_line_mask * (0.30 + eddy_fleck_noise * 0.70)) * wake_albedo_breakup_strength * wake_detail_fade, 0.0, 0.35);
	alb_mix = min(alb_mix * (1.0 + pillow_pressure * 0.25), vec3(1.0));
	alb_mix = mix(alb_mix, pillow_pressure_color.rgb, pillow_pressure * 0.18);
	alb_mix = mix(alb_mix, pillow_highlight_color.rgb, pillow_highlight * 0.42);
	alb_mix = min(alb_mix * (1.0 + wake_albedo_breakup * 0.08), vec3(1.0));
	alb_mix = mix(alb_mix, wake_breakup_color.rgb, wake_albedo_breakup * 0.28);
	ALBEDO = mix(alb_mix, foam_color.rgb, combined_foam);
	// Filtered screen sampling can bleed near edges; a later quality pass can
	// evaluate texelFetch-style refraction sampling if needed.
	EMISSION += textureLod(screen_texture, ref_ofs, min(ROUGHNESS * water_depth2, REFRACTION_MAX_LOD)).rgb * ref_amount;

	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
	ALPHA *= smoothstep(0.0, max(edge_fade, EPSILON), water_depth);
	// Clip water inside solid occupancy (obstacle interiors, crevices,
	// protruding terrain) - the Crest clip-surface analogue.
	ALPHA *= 1.0 - smoothstep(OCCUPANCY_CLIP_START, OCCUPANCY_CLIP_FULL, occupancy_rg.r);
}
