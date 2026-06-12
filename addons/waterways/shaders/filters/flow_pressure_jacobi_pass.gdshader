shader_type canvas_item;
render_mode blend_disabled;

// One Jacobi iteration of the pressure Poisson equation laplacian(p) = div.
// Neumann boundaries (dp/dn = 0) at solids and column walls: the ghost
// neighbor takes the center pressure. A `stride` > 1 relaxes the equation
// on a coarser virtual grid (laplacian step = stride texels), which lets a
// coarse-to-fine stride schedule converge long wavelengths in far fewer
// passes than plain stride-1 Jacobi.

uniform sampler2D pressure_texture : repeat_disable, filter_nearest;
uniform sampler2D divergence_texture : repeat_disable, filter_nearest;
uniform sampler2D occupancy_texture : hint_default_black, repeat_disable, filter_nearest;
uniform float size = 512.0;
uniform float stride = 1.0;

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
	float center_pressure = flow_solve_decode_pressure(texture(pressure_texture, UV));
	if (is_solid(UV)) {
		COLOR = flow_solve_encode_pressure(center_pressure);
	} else {
		float safe_size = max(size, 1.0);
		float safe_stride = max(stride, 1.0);
		vec2 step_uv = vec2(safe_stride / safe_size);
		float left = neighbor_pressure(UV, vec2(-step_uv.x, 0.0), center_pressure);
		float right = neighbor_pressure(UV, vec2(step_uv.x, 0.0), center_pressure);
		float up = neighbor_pressure(UV, vec2(0.0, -step_uv.y), center_pressure);
		float down = neighbor_pressure(UV, vec2(0.0, step_uv.y), center_pressure);
		float divergence = flow_solve_decode_divergence(texture(divergence_texture, UV));
		float new_pressure = (left + right + up + down - divergence * safe_stride * safe_stride) * 0.25;
		COLOR = flow_solve_encode_pressure(new_pressure);
	}
}
