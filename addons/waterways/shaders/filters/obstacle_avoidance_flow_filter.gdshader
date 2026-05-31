shader_type canvas_item;

uniform sampler2D baseline_flow_texture : repeat_disable, filter_nearest;
uniform sampler2D normal_texture : repeat_disable, filter_nearest;
uniform sampler2D support_texture : repeat_disable, filter_linear;
uniform sampler2D bank_response_texture : hint_default_black, repeat_disable, filter_linear;
uniform float strength = 1.0;
uniform float influence_start = 0.02;
uniform float influence_full = 0.85;
uniform float upstream_lookahead_uv = 0.0;
uniform float upstream_strength = 0.0;
uniform float min_downstream_alignment = 0.0;
uniform float bank_friction_suppression = 0.85;
uniform float hard_boundary_steering_gate = 0.55;

const float EPSILON = 0.0001;
const float OBSTACLE_FACING_START = 0.08;
const float OBSTACLE_FACING_FULL = 0.85;

vec2 decode_flow(vec4 color) {
	return color.rg * 2.0 - 1.0;
}

vec4 encode_flow(vec2 flow) {
	vec2 packed_flow = clamp(flow * 0.5 + 0.5, vec2(0.0), vec2(1.0));
	return vec4(packed_flow, 0.0, 1.0);
}

float directional_weight(vec2 obstacle_normal, vec2 baseline_direction, float floor_value) {
	float facing = smoothstep(OBSTACLE_FACING_START, OBSTACLE_FACING_FULL, dot(obstacle_normal, baseline_direction));
	return mix(floor_value, 1.0, facing);
}

vec4 sample_bank_response(vec2 uv) {
	return texture(bank_response_texture, clamp(uv, vec2(0.0), vec2(1.0)));
}

float steering_context_at(vec2 uv) {
	vec4 bank_response = sample_bank_response(uv);
	float bank_friction = clamp(bank_response.r, 0.0, 1.0);
	float hard_boundary = clamp(bank_response.a, 0.0, 1.0);
	float ordinary_bank = bank_friction * (1.0 - hard_boundary);
	float bank_context = clamp(1.0 - ordinary_bank * bank_friction_suppression, 0.0, 1.0);
	float hard_gate = mix(clamp(hard_boundary_steering_gate, 0.0, 1.0), 1.0, hard_boundary);
	return bank_context * hard_gate;
}

vec2 keep_downstream_component(vec2 direction, vec2 baseline_direction) {
	float floor_value = clamp(min_downstream_alignment, 0.0, 0.95);
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

void add_steering_sample(
	vec2 uv,
	vec2 baseline_direction,
	float sample_strength,
	inout vec2 steering_normal,
	inout float steering_support
) {
	vec2 clamped_uv = clamp(uv, vec2(0.0), vec2(1.0));
	float support = texture(support_texture, clamped_uv).r;
	if (support <= EPSILON) {
		return;
	}
	vec2 normal = texture(normal_texture, clamped_uv).rg * 2.0 - 1.0;
	float normal_magnitude = length(normal);
	if (normal_magnitude <= EPSILON) {
		return;
	}
	vec2 obstacle_normal = normal / normal_magnitude;
	float context = steering_context_at(clamped_uv);
	float weight = support * context * directional_weight(obstacle_normal, baseline_direction, 0.0) * sample_strength;
	if (weight <= EPSILON) {
		return;
	}
	steering_normal += obstacle_normal * weight;
	steering_support = max(steering_support, weight);
}

void fragment() {
	vec2 baseline = decode_flow(texture(baseline_flow_texture, UV));
	float baseline_magnitude = length(baseline);
	vec2 normal = texture(normal_texture, UV).rg * 2.0 - 1.0;
	float normal_magnitude = length(normal);
	float support = texture(support_texture, UV).r;
	vec2 flow = baseline;

	if (baseline_magnitude > EPSILON) {
		vec2 baseline_direction = baseline / baseline_magnitude;
		vec2 steering_normal = vec2(0.0);
		float steering_support = 0.0;
		if (normal_magnitude > EPSILON && support > EPSILON) {
			vec2 obstacle_normal = normal / normal_magnitude;
			float local_context = steering_context_at(UV);
			float local_weight = support * local_context * directional_weight(obstacle_normal, baseline_direction, 0.0);
			steering_normal += obstacle_normal * local_weight;
			steering_support = max(steering_support, local_weight);
		}
		float safe_upstream_strength = clamp(upstream_strength, 0.0, 1.0);
		if (upstream_lookahead_uv > EPSILON && safe_upstream_strength > EPSILON) {
			vec2 lookahead = baseline_direction * upstream_lookahead_uv;
			add_steering_sample(UV + lookahead * 0.4, baseline_direction, safe_upstream_strength * 0.65, steering_normal, steering_support);
			add_steering_sample(UV + lookahead * 0.7, baseline_direction, safe_upstream_strength * 0.85, steering_normal, steering_support);
			add_steering_sample(UV + lookahead, baseline_direction, safe_upstream_strength, steering_normal, steering_support);
		}

		float steering_normal_magnitude = length(steering_normal);
		float influence = smoothstep(influence_start, influence_full, steering_support) * clamp(strength, 0.0, 1.0);
		if (steering_normal_magnitude > EPSILON && influence > EPSILON) {
			vec2 obstacle_normal = steering_normal / steering_normal_magnitude;
			vec2 tangent = normalize(vec2(-obstacle_normal.y, obstacle_normal.x));
			if (dot(tangent, baseline_direction) < 0.0) {
				tangent = -tangent;
			}

			vec2 avoided_direction = keep_downstream_component(normalize(mix(baseline_direction, tangent, influence)), baseline_direction);
			flow = avoided_direction * baseline_magnitude;
		}
	}

	COLOR = encode_flow(flow);
}
