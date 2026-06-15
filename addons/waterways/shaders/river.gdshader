// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx, cull_disabled;
#include "res://addons/waterways/shaders/flow_pack.gdshaderinc"
#include "res://addons/waterways/shaders/river_flow_common.gdshaderinc"
#include "res://addons/waterways/shaders/river_surface_common.gdshaderinc"

// If you are making your own shader, you can customize or add your own
// parameters below and they will automatically get parsed and displayed in
// the River inspector. Most shared parameters (flow, foam, pillow, wake) are
// declared in the two includes above, shared with river_debug.gdshader (and
// river_flow_common.gdshaderinc additionally with the WaterSystem's
// system_flow.gdshader) - edit shared behavior there, once.

// Use prefixes: albedo_, emission_, transparency_, flow_, foam_, pillow_, wake_ and custom_
// to automatically put your parameters into categories in the inspector.

// If "curve" is in the name and no explicit shader hint is provided,
// the inspector will represent an easing curve.
// mat4´s with "color" in their name will get parsed as gradients.

// Main
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
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

// Foam
uniform vec4 foam_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);

// Wake / Eddy (visible-surface response only; the gate family lives in
// river_surface_common.gdshaderinc)
uniform float wake_normal_strength : hint_range(0.0, 2.0) = 0.22;
uniform float wake_eddy_line_normal_strength : hint_range(0.0, 2.0) = 0.85;
uniform float wake_roughness_boost : hint_range(0.0, 1.0) = 0.22;
uniform float wake_specular_reduction : hint_range(0.0, 1.0) = 0.12;
uniform float wake_albedo_breakup_strength : hint_range(0.0, 1.0) = 0.18;
uniform vec4 wake_breakup_color : source_color = vec4(0.42, 0.72, 0.78, 1.0);

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// View-space depth band over which a refracted screen sample fades back to
// the unrefracted one when it lands in front of the water plane.
const float REFRACTION_VALID_BAND = 0.15;
const float REFRACTION_MAX_LOD = 4.0;
// Water fades out across this band of the crisp solid mask (bilinear ramp).
const float OCCUPANCY_CLIP_START = 0.35;
const float OCCUPANCY_CLIP_FULL = 0.75;

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

// Reserved for river-height-displacement (2026-06-12): no callers yet by
// design — this chain is the declared sampling interface of the planned
// feature (see river-height displacement/initial_research.md). Do not delete
// without updating the river-ripples spec contract list and asserting probes.
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

vec2 ripple_normal_offset_at_world(vec3 world_position, vec3 camera_position_world) {
	return ripple_normal_offset_at_uv(ripple_world_to_uv(world_position)) * ripple_distance_fade(camera_position_world, world_position);
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
	
	flow = flow_pack_decode(flow); // unpack the flow vectors
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
