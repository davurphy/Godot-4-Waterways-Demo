shader_type canvas_item;
render_mode unshaded;

uniform vec2 impulse_uv = vec2(0.5, 0.5);
uniform float impulse_radius : hint_range(0.001, 0.5) = 0.055;
uniform float impulse_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float impulse_falloff : hint_range(0.01, 8.0) = 2.0;

void fragment() {
	float normalized_distance = distance(clamp(UV, vec2(0.0), vec2(1.0)), impulse_uv) / max(impulse_radius, 0.0001);
	float circle = clamp(1.0 - normalized_distance, 0.0, 1.0);
	float impulse = pow(circle, max(impulse_falloff, 0.01)) * impulse_intensity;
	COLOR = vec4(impulse, 0.0, 0.0, 1.0);
}
