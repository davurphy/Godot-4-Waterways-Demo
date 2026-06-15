// Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
// See LICENSE.md included in the source distribution for details.
//
// Shared flow-field code: decode-side boundary context, the contextual force
// shaping, and the runtime boundary slide. Single source of truth for
// river.gdshader, river_debug.gdshader AND system_renders/system_flow.gdshader
// (the baked WaterSystem flow map ducks read) - extracted 2026-06-12
// (river-refactor R3.1/R2.3) so the flow logic cannot drift between the
// three copies again (Defect 1 was exactly such a drift).
//
// Include this BEFORE river_surface_common.gdshaderinc: it declares EPSILON
// and the boundary feature samplers that the surface include's functions use.

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
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;
uniform sampler2D i_terrain_contact_features : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D i_bank_response_features : hint_default_black, repeat_disable, filter_linear;
// True when the baked flow field came from the pressure projection solve.
// Projected fields are divergence-free; re-bending them with the runtime
// boundary slide would corrupt them, so the slide only runs on legacy bakes.
uniform bool i_flow_projected = false;

const float EPSILON = 0.0001;

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
