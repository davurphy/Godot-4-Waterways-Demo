shader_type canvas_item;
render_mode blend_disabled;

// Central-difference divergence of the baseline velocity field with
// free-slip solid boundaries: a solid or wall neighbor contributes the
// center velocity mirrored about the shared face (zero normal flux).

uniform sampler2D flow_texture : repeat_disable, filter_nearest;
uniform sampler2D occupancy_texture : hint_default_black, repeat_disable, filter_nearest;
uniform float size = 512.0;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"
#include "res://addons/waterways/shaders/filters/flow_solve_common.gdshaderinc"

bool is_solid(vec2 uv) {
	return texture(occupancy_texture, uv).r > 0.5;
}

vec2 velocity_at(vec2 uv) {
	vec2 velocity = flow_solve_decode_velocity(texture(flow_texture, uv));
	return is_solid(uv) ? vec2(0.0) : velocity;
}

// Neighbor velocity along one axis with free-slip ghosts at walls/solids.
// axis_normal is the unit vector from center toward the neighbor.
vec2 neighbor_velocity(vec2 base_uv, vec2 offset_uv, vec2 axis_normal, vec2 center_velocity) {
	bool hit_wall = false;
	vec2 sample_uv = flow_solve_neighbor_uv(base_uv, offset_uv, hit_wall);
	if (hit_wall || is_solid(sample_uv)) {
		return center_velocity - 2.0 * dot(center_velocity, axis_normal) * axis_normal;
	}
	return velocity_at(sample_uv);
}

void fragment() {
	if (is_solid(UV)) {
		COLOR = flow_solve_encode_divergence(0.0);
	} else {
		float safe_size = max(size, 1.0);
		vec2 texel = vec2(1.0 / safe_size);
		vec2 center = velocity_at(UV);
		vec2 left = neighbor_velocity(UV, vec2(-texel.x, 0.0), vec2(-1.0, 0.0), center);
		vec2 right = neighbor_velocity(UV, vec2(texel.x, 0.0), vec2(1.0, 0.0), center);
		vec2 up = neighbor_velocity(UV, vec2(0.0, -texel.y), vec2(0.0, -1.0), center);
		vec2 down = neighbor_velocity(UV, vec2(0.0, texel.y), vec2(0.0, 1.0), center);
		float divergence = 0.5 * ((right.x - left.x) + (down.y - up.y));
		COLOR = flow_solve_encode_divergence(divergence);
	}
}
