shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture : repeat_disable, filter_nearest;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"

float input_in(vec2 uv) {
	vec4 lodded_texture = textureLod(input_texture, uv, 0.0);
return (dot((lodded_texture).rgb, vec3(1.0))/3.0);
}

vec3 fct(vec2 uv) {
	float safe_size = max(size, 1.0);
	vec3 e = vec3(1.0 / safe_size, -1.0 / safe_size, 0);
	vec2 rv = vec2(1.0, -1.0) * input_in(atlas_column_clamp(uv + e.xy, uv));
	rv += vec2(-1.0, 1.0) * input_in(atlas_column_clamp(uv - e.xy, uv));
	rv += vec2(1.0, 1.0) * input_in(atlas_column_clamp(uv + e.xx, uv));
	rv += vec2(-1.0, -1.0) * input_in(atlas_column_clamp(uv - e.xx, uv));
	rv += vec2(2.0, 0.0) * input_in(atlas_column_clamp(uv + e.xz, uv));
	rv += vec2(-2.0, 0.0) * input_in(atlas_column_clamp(uv - e.xz, uv));
	rv += vec2(0.0, 2.0) * input_in(atlas_column_clamp(uv + e.zx, uv));
	rv += vec2(0.0, -2.0) * input_in(atlas_column_clamp(uv - e.zx, uv));
	return vec3(rv, 0.0);
}

vec3 process_normal(vec3 v, float multiplier) {
	return 0.5 * normalize(v.xyz * multiplier + vec3(0.0, 0.0, -1.0)) + vec3(0.5);
}

void fragment() {
	float safe_size = max(size, 1.0);
	vec3 normal_map = process_normal(fct((UV)), safe_size / 128.0);
	COLOR = vec4(normal_map, 1.0);
}
