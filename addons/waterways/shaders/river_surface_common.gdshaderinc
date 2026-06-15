// Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
// See LICENSE.md included in the source distribution for details.
//
// Shared surface code for river.gdshader and river_debug.gdshader ONLY:
// shared uniforms, FlowUVW, the pillow stack, wake/eddy gate families,
// ripple helpers, and the shared vertex() displacement. Extracted 2026-06-12
// (river-refactor R3.1) to end the ~700-line hand-synced mirror between the
// two shaders (four recorded drift failures).
// Deliberately NOT consumed by system_renders/system_flow.gdshader - it would
// inject ~80 surface uniforms and a displacement vertex() into the system-map
// render (see river-refactor roadmap R3.1).
//
// Requires flow_pack.gdshaderinc and river_flow_common.gdshaderinc to be
// included first (the flow codec, EPSILON, and the boundary feature samplers
// are declared there).

// Flow
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float flow_wake_damping : hint_range(0.0, 1.0) = 0.6;
uniform float foam_amount : hint_range(0.0, 4.0) = 2.0;
uniform float foam_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float foam_energy_bias : hint_range(0.0, 8.0) = 0.5;
uniform float foam_bank_friction_bias : hint_range(0.0, 2.0) = 0.35;
uniform float foam_pillow_anchor_bias : hint_range(0.0, 2.0) = 0.35;
uniform float foam_pillow_visual_bias : hint_range(0.0, 2.0) = 0.35;
uniform float foam_smoothness : hint_range(0.0, 1.0) = 0.3;
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform sampler2D normal_bump_texture : hint_default_black, repeat_enable, filter_linear_mipmap;
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
// The surface-shading pillow uniforms below are only read by river.gdshader,
// but the full pillow set is part of the inspector contract on BOTH materials
// (river-pillows spec.md; pillow_inspector_wiring_probe asserts them on the
// debug material). Keep them declared here, shared (2026-06-12).
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
// R: crisp solid mask (1 = inside obstacle/protruding terrain), G: solid
// proximity (1 at the solid surface, 0 beyond the ramp radius). Absent on
// legacy bakes - the black default makes every occupancy behavior neutral.
uniform sampler2D i_water_occupancy : hint_default_black, repeat_disable, filter_linear;
uniform bool i_valid_flowmap = false;
uniform int i_uv2_sides = 2;
uniform bool i_ripple_enabled = false;
uniform sampler2D i_ripple_simulation_texture : hint_default_black, repeat_disable, filter_linear;
// Not sampled by river.gdshader's surface shading, but live:
// river_debug.gdshader's impulse/contact heat view samples it,
// water_ripple_field.gd sets it every frame, and the ripple parity/ownership
// probes assert the binding (2026-06-12; see river-height
// displacement/initial_research.md before touching).
uniform sampler2D i_ripple_impulse_texture : hint_default_black, repeat_disable, filter_linear;
uniform mat4 i_ripple_world_to_uv = mat4(1.0);
uniform sampler2D i_ripple_boundary_mask : hint_default_black, repeat_disable, filter_linear;
uniform vec2 i_ripple_texel_size = vec2(0.0);
uniform float i_ripple_normal_strength : hint_range(0.0, 4.0) = 0.0;
// Reserved for river-height-displacement (2026-06-12): declared interface of
// the planned feature (see river-height displacement/initial_research.md);
// synced from water_ripple_field.gd but not consumed here yet. Do not delete
// without updating the river-ripples spec contract list and asserting probes.
uniform float i_ripple_refraction_strength : hint_range(0.0, 1.0) = 0.0;
uniform float i_ripple_displacement_strength : hint_range(0.0, 1.0) = 0.0;
uniform float i_ripple_height_fade_distance : hint_range(0.0, 200.0) = 0.0;
uniform float i_ripple_boundary_fade : hint_range(0.0, 0.25) = 0.0;

const float EDDY_CONTEXT_UPSTREAM_NEAR_TILES = 0.16;
const float EDDY_CONTEXT_UPSTREAM_MID_TILES = 0.38;
const float EDDY_CONTEXT_UPSTREAM_FAR_TILES = 0.70;
const float EDDY_CONTEXT_LATERAL_TILES = 0.14;
const float PILLOW_BAKE_CONTACT_SEARCH_TILES = 0.07;
const float PILLOW_BAKE_CONTACT_GATE_START = 0.08;
const float PILLOW_BAKE_CONTACT_GATE_FULL = 0.38;
// Advection speed recovers from 0 at the solid surface over the proximity
// ramp; openness = 1 - proximity. Full speed returns by mid-ring so the
// stilled band hugs the solid instead of deadening the whole proximity ring.
// This is the single source of truth (R3.5): the flow-arrow and projection
// probes parse this declaration from this file instead of mirroring the
// value - keep it on one line. (river.gdshader's OCCUPANCY_CLIP_* alpha
// constants are deliberately not shared: the debug shader renders solids
// opaquely instead of clipping.)
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

vec2 water_occupancy_at(vec2 uv) {
	// R: solid mask, G: solid proximity.
	return textureLod(i_water_occupancy, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).rg;
}

float occupancy_speed_factor(vec2 occupancy_rg) {
	float openness = 1.0 - occupancy_rg.g;
	return smoothstep(0.0, OCCUPANCY_SPEED_RAMP_FULL, openness);
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
		vec2 flow = flow_pack_decode(flow_foam_noise.xy);
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
