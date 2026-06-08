shader_type canvas_item;
render_mode unshaded;

uniform sampler2D previous_texture : hint_default_black, repeat_disable, filter_nearest;
uniform sampler2D impulse_texture : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D boundary_texture : hint_default_white, repeat_disable, filter_linear;
uniform vec2 texel_size = vec2(0.00390625, 0.00390625);
uniform float damping : hint_range(0.0, 1.0) = 0.985;
uniform float propagation : hint_range(0.0, 2.0) = 0.45;
uniform float impulse_strength : hint_range(0.0, 4.0) = 1.0;
uniform float boundary_fade : hint_range(0.0, 0.25) = 0.025;
uniform bool clear_state = false;

const float NEUTRAL_HEIGHT = 0.5;

float decode_height(float encoded_height) {
	return encoded_height * 2.0 - 1.0;
}

float encode_height(float height) {
	return clamp(height * 0.5 + 0.5, 0.0, 1.0);
}

float edge_mask(vec2 uv) {
	if (boundary_fade <= 0.0) {
		return 1.0;
	}
	vec2 distance_to_edge = min(uv, vec2(1.0) - uv);
	float nearest_edge = min(distance_to_edge.x, distance_to_edge.y);
	return smoothstep(0.0, boundary_fade, nearest_edge);
}

void fragment() {
	if (clear_state) {
		COLOR = vec4(NEUTRAL_HEIGHT, NEUTRAL_HEIGHT, 0.0, 1.0);
	} else {
		vec2 uv = clamp(UV, vec2(0.0), vec2(1.0));
		vec4 previous_state = texture(previous_texture, uv);
		float current_height = decode_height(previous_state.r);
		float previous_height = decode_height(previous_state.g);

		float left_height = decode_height(texture(previous_texture, clamp(uv - vec2(texel_size.x, 0.0), vec2(0.0), vec2(1.0))).r);
		float right_height = decode_height(texture(previous_texture, clamp(uv + vec2(texel_size.x, 0.0), vec2(0.0), vec2(1.0))).r);
		float up_height = decode_height(texture(previous_texture, clamp(uv - vec2(0.0, texel_size.y), vec2(0.0), vec2(1.0))).r);
		float down_height = decode_height(texture(previous_texture, clamp(uv + vec2(0.0, texel_size.y), vec2(0.0), vec2(1.0))).r);

		float laplacian = (left_height + right_height + up_height + down_height) * 0.25 - current_height;
		float impulse = texture(impulse_texture, uv).r * impulse_strength;
		float boundary = texture(boundary_texture, uv).r * edge_mask(uv);
		float next_height = (2.0 * current_height - previous_height + laplacian * propagation + impulse) * damping;
		next_height *= boundary;
		current_height *= boundary;

		COLOR = vec4(encode_height(next_height), encode_height(current_height), clamp(impulse, 0.0, 1.0), boundary);
	}
}
