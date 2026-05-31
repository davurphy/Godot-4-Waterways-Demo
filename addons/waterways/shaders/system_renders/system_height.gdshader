shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float lower_bounds = 0.0;
uniform float upper_bounds = 10.0;
varying vec3 vertex_trans;

vec3 srgb_to_linear(vec3 color) {
	return mix(
		color / 12.92,
		pow((color + vec3(0.055)) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color)
	);
}

vec3 data_to_albedo(vec3 color) {
	if (OUTPUT_IS_SRGB) {
		return color;
	}
	return srgb_to_linear(color);
}

void vertex() {
	vertex_trans = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float range = max(abs(upper_bounds - lower_bounds), 0.0001);
	ALBEDO = data_to_albedo(vec3(clamp((vertex_trans.y - lower_bounds) / range, 0.0, 1.0)));
}
