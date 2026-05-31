shader_type spatial;
render_mode unshaded, cull_disabled;

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

void fragment() {
	ALBEDO = data_to_albedo(vec3(1.0));
}
