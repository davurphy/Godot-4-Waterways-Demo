shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D baseline_flow_texture : repeat_disable, filter_nearest;
uniform sampler2D normal_texture : repeat_disable, filter_nearest;
uniform sampler2D support_texture : repeat_disable, filter_linear;
uniform sampler2D bank_response_texture : repeat_disable, filter_linear;
uniform sampler2D terrain_contact_texture : repeat_disable, filter_linear;
uniform sampler2D grade_energy_texture : repeat_disable, filter_linear;
// Every uniform below is always overridden by apply_obstacle_feature_mask
// (filter_renderer.gd) from river_manager's RIVER_OBSTACLE_FEATURE_*
// constants - the canonical values. Defaults here match those constants
// where the units agree (R3.4, 2026-06-12); the *_uv ones are tile-unit
// constants converted to UV at the call site, so their defaults are dummies.
uniform float support_start = 0.22;
uniform float support_full = 0.82;
uniform float facing_start = 0.35;
uniform float facing_full = 0.92;
uniform float pillow_support_start = 0.40;
uniform float pillow_support_full = 0.88;
uniform float pillow_contact_search_uv = 0.01; // dummy: tiles -> UV at call site
uniform float pillow_contact_gate_start = 0.08;
uniform float pillow_contact_gate_full = 0.38;
uniform float wake_length_uv = 0.04; // dummy: tiles -> UV at call site
uniform float wake_width_uv = 0.012; // dummy: tiles -> UV at call site
uniform float side_width_uv = 0.012; // dummy: tiles -> UV at call site
uniform float wake_start = 0.045;
uniform float wake_full = 0.20;
uniform float bank_friction_suppression = 0.70;
uniform float hard_boundary_wake_gate = 0.45;
uniform float confidence_start = 0.14;
uniform float confidence_full = 0.44;
uniform float eddy_line_edge_start = 0.04;
uniform float eddy_line_edge_full = 0.22;
uniform float eddy_line_wake_start = 0.06;
uniform float eddy_line_wake_full = 0.28;
uniform float eddy_line_hard_gate_start = 0.06;
uniform float eddy_line_hard_gate_full = 0.40;
uniform float eddy_line_energy_gate_start = 0.03;
uniform float eddy_line_energy_gate_full = 0.35;
uniform float eddy_line_support_reject_start = 0.62;
uniform float eddy_line_support_reject_full = 0.92;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"
#include "res://addons/waterways/shaders/flow_pack.gdshaderinc"

const float EPSILON = 0.0001;

vec2 decode_flow(vec4 color) {
	return flow_pack_decode(color.rg);
}

vec2 safe_direction(vec2 vector, vec2 fallback) {
	float magnitude = length(vector);
	if (magnitude <= EPSILON) {
		return fallback;
	}
	return vector / magnitude;
}

vec2 sample_obstacle_normal(vec2 uv) {
	vec2 normal = texture(normal_texture, clamp(uv, vec2(0.0), vec2(1.0))).rg * 2.0 - 1.0;
	float magnitude = length(normal);
	if (magnitude <= EPSILON) {
		return vec2(0.0);
	}
	return normal / magnitude;
}

float sample_support_range(vec2 uv, float range_start, float range_full) {
	float support = texture(support_texture, clamp(uv, vec2(0.0), vec2(1.0))).r;
	float start = min(clamp(range_start, 0.0, 1.0), 1.0 - EPSILON);
	float full = min(1.0, max(start + EPSILON, clamp(range_full, 0.0, 1.0)));
	float mask = smoothstep(start, full, support);
	return mask * mask;
}

float sample_support(vec2 uv) {
	return sample_support_range(uv, support_start, support_full);
}

float sample_pillow_support(vec2 uv) {
	return sample_support_range(uv, pillow_support_start, pillow_support_full);
}

vec4 sample_bank_response(vec2 uv) {
	return texture(bank_response_texture, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec4 sample_terrain_contact(vec2 uv) {
	return texture(terrain_contact_texture, clamp(uv, vec2(0.0), vec2(1.0)));
}

float grade_energy_at(vec2 uv) {
	return texture(grade_energy_texture, clamp(uv, vec2(0.0), vec2(1.0))).r;
}

float facing_weight(vec2 obstacle_normal, vec2 flow_direction) {
	return smoothstep(facing_start, facing_full, dot(obstacle_normal, flow_direction));
}

float backface_weight(vec2 obstacle_normal, vec2 flow_direction) {
	return smoothstep(facing_start, facing_full, dot(-obstacle_normal, flow_direction));
}

float side_weight(vec2 obstacle_normal, vec2 flow_direction) {
	vec2 lateral = vec2(-flow_direction.y, flow_direction.x);
	return smoothstep(facing_start, facing_full, abs(dot(obstacle_normal, lateral)));
}

float hard_boundary_at(vec2 uv) {
	return clamp(max(sample_bank_response(uv).a, sample_terrain_contact(uv).b), 0.0, 1.0);
}

float direct_pillow_contact_at(vec2 uv) {
	return clamp(sample_terrain_contact(uv).b, 0.0, 1.0);
}

float pillow_bank_context_at(vec2 uv) {
	return clamp(sample_bank_response(uv).a, 0.0, 1.0);
}

float obstacle_context_at(vec2 uv) {
	vec4 bank_response = sample_bank_response(uv);
	float bank_friction = clamp(bank_response.r, 0.0, 1.0);
	float hard_boundary = hard_boundary_at(uv);
	float ordinary_bank = bank_friction * (1.0 - hard_boundary);
	return clamp(1.0 - ordinary_bank * bank_friction_suppression, 0.0, 1.0);
}

float smooth_gate(float gate_start, float gate_full, float value) {
	float start = min(clamp(gate_start, 0.0, 1.0), 1.0 - EPSILON);
	float full = min(1.0, max(start + EPSILON, clamp(gate_full, 0.0, 1.0)));
	return smoothstep(start, full, value);
}

float pillow_context_at(vec2 uv) {
	vec4 bank_response = sample_bank_response(uv);
	float bank_friction = clamp(bank_response.r, 0.0, 1.0);
	float hard_boundary = hard_boundary_at(uv);
	float ordinary_bank = bank_friction * (1.0 - hard_boundary);
	return clamp(1.0 - ordinary_bank * bank_friction_suppression * 0.45, 0.0, 1.0);
}

float pillow_source_at(vec2 uv, vec2 flow_direction) {
	vec2 obstacle_normal = sample_obstacle_normal(uv);
	float support = sample_pillow_support(uv);
	float facing = facing_weight(obstacle_normal, flow_direction);
	return support * facing * facing * pillow_context_at(uv);
}

float direct_pillow_contact_search_at(vec2 uv, vec2 flow_direction) {
	float search_uv = max(pillow_contact_search_uv, 0.0);
	float contact = direct_pillow_contact_at(uv);
	contact = max(contact, direct_pillow_contact_at(atlas_column_clamp(uv + flow_direction * search_uv * 0.50, uv)));
	contact = max(contact, direct_pillow_contact_at(atlas_column_clamp(uv + flow_direction * search_uv, uv)));
	contact = max(contact, direct_pillow_contact_at(atlas_column_clamp(uv + flow_direction * search_uv * 1.50, uv)) * 0.65);
	return clamp(contact, 0.0, 1.0);
}

float pillow_bank_context_search_at(vec2 uv, vec2 flow_direction) {
	float search_uv = max(pillow_contact_search_uv, 0.0);
	float bank_context = pillow_bank_context_at(uv);
	bank_context = max(bank_context, pillow_bank_context_at(atlas_column_clamp(uv + flow_direction * search_uv * 0.50, uv)));
	bank_context = max(bank_context, pillow_bank_context_at(atlas_column_clamp(uv + flow_direction * search_uv, uv)));
	bank_context = max(bank_context, pillow_bank_context_at(atlas_column_clamp(uv + flow_direction * search_uv * 1.50, uv)) * 0.65);
	return clamp(bank_context, 0.0, 1.0);
}

float pillow_contact_gate_at(vec2 uv, vec2 flow_direction) {
	float direct_contact = direct_pillow_contact_search_at(uv, flow_direction);
	float direct_gate = smooth_gate(pillow_contact_gate_start, pillow_contact_gate_full, direct_contact);
	float bank_context = pillow_bank_context_search_at(uv, flow_direction);
	float bank_context_boost = mix(0.85, 1.0, smooth_gate(pillow_contact_gate_start, pillow_contact_gate_full, bank_context));
	return clamp(direct_gate * bank_context_boost, 0.0, 1.0);
}

float wake_seed_at(vec2 uv, vec2 flow_direction) {
	float wake = 0.0;
	vec2 sample_uv = atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.25, uv);
	float support = sample_support(sample_uv);
	vec2 obstacle_normal = sample_obstacle_normal(sample_uv);
	float hard_boundary = hard_boundary_at(sample_uv);
	float context = obstacle_context_at(sample_uv);
	float lee = max(backface_weight(obstacle_normal, flow_direction), side_weight(obstacle_normal, flow_direction) * 0.06);
	float hard_gate = mix(hard_boundary_wake_gate, 1.0, hard_boundary);
	wake = max(wake, support * lee * context * hard_gate);

	sample_uv = atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.5, uv);
	support = sample_support(sample_uv);
	obstacle_normal = sample_obstacle_normal(sample_uv);
	hard_boundary = hard_boundary_at(sample_uv);
	context = obstacle_context_at(sample_uv);
	lee = max(backface_weight(obstacle_normal, flow_direction), side_weight(obstacle_normal, flow_direction) * 0.06);
	hard_gate = mix(hard_boundary_wake_gate, 1.0, hard_boundary);
	wake = max(wake, support * lee * context * hard_gate * 0.62);

	sample_uv = atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.85, uv);
	support = sample_support(sample_uv);
	obstacle_normal = sample_obstacle_normal(sample_uv);
	hard_boundary = hard_boundary_at(sample_uv);
	context = obstacle_context_at(sample_uv);
	lee = max(backface_weight(obstacle_normal, flow_direction), side_weight(obstacle_normal, flow_direction) * 0.06);
	hard_gate = mix(hard_boundary_wake_gate, 1.0, hard_boundary);
	wake = max(wake, support * lee * context * hard_gate * 0.32);

	sample_uv = atlas_column_clamp(uv - flow_direction * wake_length_uv * 1.15, uv);
	support = sample_support(sample_uv);
	obstacle_normal = sample_obstacle_normal(sample_uv);
	hard_boundary = hard_boundary_at(sample_uv);
	context = obstacle_context_at(sample_uv);
	lee = max(backface_weight(obstacle_normal, flow_direction), side_weight(obstacle_normal, flow_direction) * 0.06);
	hard_gate = mix(hard_boundary_wake_gate, 1.0, hard_boundary);
	wake = max(wake, support * lee * context * hard_gate * 0.12);
	return clamp(wake, 0.0, 1.0);
}

float wake_mask_at(vec2 uv, vec2 flow_direction) {
	float wake = wake_seed_at(uv, flow_direction);
	return wake * smooth_gate(wake_start, wake_full, wake);
}

float wake_source_hard_context(vec2 uv, vec2 flow_direction) {
	float hard_context = hard_boundary_at(uv);
	hard_context = max(hard_context, hard_boundary_at(atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.25, uv)));
	hard_context = max(hard_context, hard_boundary_at(atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.50, uv)));
	hard_context = max(hard_context, hard_boundary_at(atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.85, uv)));
	return clamp(hard_context, 0.0, 1.0);
}

float wake_source_energy_context(vec2 uv, vec2 flow_direction) {
	float energy = grade_energy_at(uv);
	energy = max(energy, grade_energy_at(atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.25, uv)));
	energy = max(energy, grade_energy_at(atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.50, uv)));
	energy = max(energy, grade_energy_at(atlas_column_clamp(uv - flow_direction * wake_length_uv * 0.85, uv)));
	return clamp(energy, 0.0, 1.0);
}

void fragment() {
	vec2 flow = decode_flow(texture(baseline_flow_texture, UV));
	vec2 flow_direction = safe_direction(flow, vec2(0.0, 1.0));
	vec2 obstacle_normal = sample_obstacle_normal(UV);
	float support = sample_support(UV);
	vec4 bank_response = sample_bank_response(UV);
	float bank_friction = clamp(bank_response.r, 0.0, 1.0);
	float bank_hard_boundary = clamp(bank_response.a, 0.0, 1.0);
	float hard_boundary = hard_boundary_at(UV);
	float ordinary_bank = bank_friction * (1.0 - bank_hard_boundary);
	float local_side_context = clamp(1.0 - ordinary_bank * bank_friction_suppression * 0.45, 0.0, 1.0);

	float facing = facing_weight(obstacle_normal, flow_direction);
	float side = side_weight(obstacle_normal, flow_direction);
	float pillow_source = pillow_source_at(UV, flow_direction);
	float pillow_contact_gate = pillow_contact_gate_at(UV, flow_direction);
	float current_contact_anchor = smooth_gate(pillow_contact_gate_start, pillow_contact_gate_full, direct_pillow_contact_at(UV));
	float pulled_contact_source = pillow_source_at(atlas_column_clamp(UV - flow_direction * max(pillow_contact_search_uv, 0.0) * 0.55, UV), flow_direction) * current_contact_anchor * 0.80;
	float pillow = max(pillow_source * pillow_contact_gate, pulled_contact_source);
	float side_deflection = support * side * side * (1.0 - pillow * 0.5) * local_side_context;

	float wake = wake_mask_at(UV, flow_direction);
	vec2 lateral = vec2(-flow_direction.y, flow_direction.x);
	float wake_left = wake_mask_at(atlas_column_clamp(UV + lateral * wake_width_uv, UV), flow_direction);
	float wake_right = wake_mask_at(atlas_column_clamp(UV - lateral * wake_width_uv, UV), flow_direction);
	float wake_far_left = wake_mask_at(atlas_column_clamp(UV + lateral * side_width_uv, UV), flow_direction);
	float wake_far_right = wake_mask_at(atlas_column_clamp(UV - lateral * side_width_uv, UV), flow_direction);
	float wake_edge = max(abs(wake_left - wake), abs(wake_right - wake));
	float wake_cross_edge = abs(wake_left - wake_right);
	float wake_far_cross_edge = abs(wake_far_left - wake_far_right);
	float neighboring_wake = max(max(wake_left, wake_right), max(wake_far_left, wake_far_right));
	float edge_strength = max(max(wake_edge, wake_cross_edge * 0.85), wake_far_cross_edge * 0.45);
	float edge_gate = smooth_gate(eddy_line_edge_start, eddy_line_edge_full, edge_strength);
	float wake_gate = smooth_gate(eddy_line_wake_start, eddy_line_wake_full, neighboring_wake);
	float hard_gate = smooth_gate(eddy_line_hard_gate_start, eddy_line_hard_gate_full, wake_source_hard_context(UV, flow_direction));
	float energy_gate = smooth_gate(eddy_line_energy_gate_start, eddy_line_energy_gate_full, wake_source_energy_context(UV, flow_direction));
	float support_reject = 1.0 - smooth_gate(eddy_line_support_reject_start, eddy_line_support_reject_full, support);
	float eddy_line = clamp((wake_edge * 1.15 + wake_cross_edge * 0.95 + wake_far_cross_edge * 0.35) * edge_gate * wake_gate * hard_gate * energy_gate * support_reject, 0.0, 1.0);
	eddy_line *= clamp(1.0 - ordinary_bank * bank_friction_suppression * 0.6, 0.0, 1.0);

	float obstacle_confidence_raw = clamp(max(max(pillow, wake * 0.82), max(eddy_line * 0.80, side_deflection * 0.18)), 0.0, 1.0);
	float obstacle_confidence = obstacle_confidence_raw * smoothstep(confidence_start, confidence_full, obstacle_confidence_raw);
	COLOR = vec4(clamp(pillow, 0.0, 1.0), wake, eddy_line, obstacle_confidence);
}
