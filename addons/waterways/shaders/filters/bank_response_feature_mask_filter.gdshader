shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D baseline_flow_texture : repeat_disable, filter_nearest;
uniform sampler2D terrain_contact_texture : repeat_disable, filter_linear;
uniform sampler2D grade_energy_texture : repeat_disable, filter_linear;
uniform sampler2D bend_bias_texture : repeat_disable, filter_linear;
uniform float probe_uv = 0.012;
uniform float friction_contact_weight = 0.85;
uniform float friction_shallow_weight = 0.65;
uniform float hard_protrusion_weight = 0.90;
uniform float outside_bend_start = 0.12;
uniform float outside_bend_full = 0.70;
uniform float inside_bend_start = 0.12;
uniform float inside_bend_full = 0.70;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"

const float EPSILON = 0.0001;

vec2 decode_flow(vec4 color) {
	return color.rg * 2.0 - 1.0;
}

vec2 safe_direction(vec2 vector, vec2 fallback) {
	float magnitude = length(vector);
	if (magnitude <= EPSILON) {
		return fallback;
	}
	return vector / magnitude;
}

vec4 sample_terrain(vec2 uv) {
	return texture(terrain_contact_texture, clamp(uv, vec2(0.0), vec2(1.0)));
}

float boundary_source(vec2 uv) {
	vec4 terrain = sample_terrain(uv);
	return max(max(terrain.r, terrain.g * 0.75), terrain.b);
}

vec2 boundary_gradient(vec2 uv, float offset) {
	vec2 dx = vec2(offset, 0.0);
	vec2 dy = vec2(0.0, offset);
	return vec2(
		boundary_source(atlas_column_clamp(uv + dx, uv)) - boundary_source(atlas_column_clamp(uv - dx, uv)),
		boundary_source(uv + dy) - boundary_source(uv - dy)
	);
}

float forward_protrusion(vec2 uv, vec2 flow_direction, float offset) {
	float near_ahead = sample_terrain(atlas_column_clamp(uv + flow_direction * offset * 0.75, uv)).b;
	float farther_ahead = sample_terrain(atlas_column_clamp(uv + flow_direction * offset * 1.5, uv)).b;
	return max(near_ahead, farther_ahead * 0.75);
}

void fragment() {
	vec4 terrain = sample_terrain(UV);
	float contact = terrain.r;
	float shallow = terrain.g;
	float protrusion = terrain.b;
	float grade_energy = texture(grade_energy_texture, UV).r;
	float signed_bend = texture(bend_bias_texture, UV).r * 2.0 - 1.0;

	vec2 flow = decode_flow(texture(baseline_flow_texture, UV));
	vec2 flow_direction = safe_direction(flow, vec2(0.0, 1.0));
	float safe_probe_uv = max(probe_uv, EPSILON);
	vec2 gradient = boundary_gradient(UV, safe_probe_uv);
	vec2 boundary_normal = safe_direction(gradient, vec2(0.0));
	float flow_into_boundary = max(dot(flow_direction, boundary_normal), 0.0);

	float near_boundary = max(contact, shallow * 0.75);
	float hard_nearby = max(protrusion, forward_protrusion(UV, flow_direction, safe_probe_uv));
	float friction = clamp(max(contact * friction_contact_weight, shallow * friction_shallow_weight) + hard_nearby * 0.35, 0.0, 1.0);

	float outside_bend = smoothstep(outside_bend_start, outside_bend_full, signed_bend);
	float inside_bend = smoothstep(inside_bend_start, inside_bend_full, -signed_bend);
	float energy_gate = mix(0.45, 1.0, clamp(grade_energy, 0.0, 1.0));
	float outside_pressure = clamp(near_boundary * outside_bend * energy_gate * (1.0 - hard_nearby * 0.35), 0.0, 1.0);
	float inside_deposition = clamp(max(shallow, contact * 0.45) * inside_bend * (1.0 - grade_energy * 0.25) * (1.0 - hard_nearby * 0.45), 0.0, 1.0);

	float flow_facing_contact = smoothstep(0.25, 0.85, near_boundary) * flow_into_boundary;
	float hard_response = clamp(
		hard_nearby * hard_protrusion_weight +
		protrusion * 0.35 +
		flow_facing_contact * protrusion * 0.55,
		0.0,
		1.0
	);

	COLOR = vec4(friction, outside_pressure, inside_deposition, hard_response);
}
