shader_type canvas_item;
render_mode blend_disabled;

// Helmholtz-Hodge projection step: v' = v - gradient(p). With Neumann
// pressure ghosts at solids/walls the resulting field has (approximately)
// zero normal velocity at solid boundaries. Velocity inside solids is
// forced to zero.

uniform sampler2D flow_texture : repeat_disable, filter_nearest;
uniform sampler2D pressure_texture : repeat_disable, filter_nearest;
uniform sampler2D occupancy_texture : hint_default_black, repeat_disable, filter_nearest;
uniform float size = 512.0;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"
#include "res://addons/waterways/shaders/filters/flow_solve_common.gdshaderinc"

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
	if (is_solid(UV)) {
		COLOR = flow_solve_encode_velocity(vec2(0.0));
	} else {
		float safe_size = max(size, 1.0);
		vec2 texel = vec2(1.0 / safe_size);
		float center_pressure = flow_solve_decode_pressure(texture(pressure_texture, UV));
		float left = neighbor_pressure(UV, vec2(-texel.x, 0.0), center_pressure);
		float right = neighbor_pressure(UV, vec2(texel.x, 0.0), center_pressure);
		float up = neighbor_pressure(UV, vec2(0.0, -texel.y), center_pressure);
		float down = neighbor_pressure(UV, vec2(0.0, texel.y), center_pressure);
		vec2 gradient = 0.5 * vec2(right - left, down - up);
		vec2 velocity = flow_solve_decode_velocity(texture(flow_texture, UV)) - gradient;
		COLOR = flow_solve_encode_velocity(velocity);
	}
}
