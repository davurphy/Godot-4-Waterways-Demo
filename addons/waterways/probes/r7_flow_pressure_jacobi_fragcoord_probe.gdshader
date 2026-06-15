shader_type canvas_item;
render_mode blend_disabled;

// Probe-only variant of flow_pressure_jacobi_pass.gdshader.
// It derives the base texel center from FRAGCOORD instead of CanvasItem UV so
// R7 can isolate interpolated-UV sampler artifacts without changing production.

uniform sampler2D pressure_texture : repeat_disable, filter_nearest;
uniform sampler2D divergence_texture : repeat_disable, filter_nearest;
uniform sampler2D occupancy_texture : hint_default_black, repeat_disable, filter_nearest;
uniform float size = 512.0;
uniform float stride = 1.0;
uniform vec2 texture_size_px = vec2(1.0, 1.0);

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"
#include "res://addons/waterways/shaders/filters/flow_solve_common.gdshaderinc"

vec2 fragcoord_texel_uv(vec2 fragcoord_xy) {
	vec2 safe_texture_size = max(texture_size_px, vec2(1.0));
	vec2 texel_center = floor(fragcoord_xy) + vec2(0.5);
	return clamp(texel_center / safe_texture_size, vec2(0.0), vec2(1.0));
}

bool is_solid(vec2 uv) {
	return texture(occupancy_texture, uv).r > 0.5;
}

float neighbor_pressure(vec2 base_uv, vec2 offset_uv, float center_pressure) {
	bool hit_wall = false;
	vec2 sample_uv = flow_solve_neighbor_uv(base_uv, offset_uv, hit_wall);
	if (hit_wall || is_solid(sample_uv)) {
		return center_pressure;
	}
	return flow_solve_decode_pressure(texture(pressure_texture, sample_uv));
}

void fragment() {
	vec2 base_uv = fragcoord_texel_uv(FRAGCOORD.xy);
	float center_pressure = flow_solve_decode_pressure(texture(pressure_texture, base_uv));
	if (is_solid(base_uv)) {
		COLOR = flow_solve_encode_pressure(center_pressure);
	} else {
		float safe_size = max(size, 1.0);
		float safe_stride = max(stride, 1.0);
		vec2 step_uv = vec2(safe_stride / safe_size);
		float left = neighbor_pressure(base_uv, vec2(-step_uv.x, 0.0), center_pressure);
		float right = neighbor_pressure(base_uv, vec2(step_uv.x, 0.0), center_pressure);
		float up = neighbor_pressure(base_uv, vec2(0.0, -step_uv.y), center_pressure);
		float down = neighbor_pressure(base_uv, vec2(0.0, step_uv.y), center_pressure);
		float divergence = flow_solve_decode_divergence(texture(divergence_texture, base_uv));
		float new_pressure = (left + right + up + down - divergence * safe_stride * safe_stride) * 0.25;
		COLOR = flow_solve_encode_pressure(new_pressure);
	}
}
