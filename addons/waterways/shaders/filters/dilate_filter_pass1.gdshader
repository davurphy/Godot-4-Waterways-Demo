shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture : repeat_disable, filter_nearest;
uniform float dilation = 0.1;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"

const float EPSILON = 0.0001;

float input_in(vec2 uv) {
	return (dot(texture(input_texture, uv).rgb, vec3(1.0))/3.0);
}

vec3 distance_h(vec2 uv) {
	float safe_size = max(size, 1.0);
	if (dilation <= EPSILON) {
		return vec3(input_in(uv), uv);
	}
	float safe_dilation = max(dilation, EPSILON);
	vec2 e = vec2( 1.0 / safe_size, 0.0);
	int steps = max(1, int(safe_size * safe_dilation));
	float rv = 0.0;
	vec2 source_uv = uv;
	for (int i = 0; i < steps; ++i) {
		source_uv = atlas_column_clamp(uv + float(i) * e, uv);
		if (input_in(source_uv) > 0.5) {
			rv = 1.0 - float(i) * e.x / safe_dilation;
			break;
		}
		source_uv = atlas_column_clamp(uv - float(i) * e, uv);
		if (input_in(source_uv) > 0.5) {
			rv = 1.0 - float(i) * e.x / safe_dilation;
			break;
		}
	}
	return vec3(rv, source_uv);
}

void fragment() {
	vec3 dilated_uv = distance_h((UV));
	COLOR = vec4(dilated_uv, 1.0);
}
