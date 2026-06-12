shader_type canvas_item;
render_mode blend_disabled;

// Local free-slip enforcement, independent of solve convergence: inside the
// solid proximity ring, remove any remaining velocity component pointing
// INTO the solid (projection onto the boundary tangent). A hard local
// guarantee that baked flow never crosses obstacle boundaries.

uniform sampler2D flow_texture : repeat_disable, filter_nearest;
uniform sampler2D occupancy_texture : hint_default_black, repeat_disable, filter_linear;
uniform float size = 512.0;
uniform float ring_start = 0.10;
uniform float ring_full = 0.55;

#include "res://addons/waterways/shaders/filters/atlas_column_clamp.gdshaderinc"
#include "res://addons/waterways/shaders/filters/flow_solve_common.gdshaderinc"

float proximity_at(vec2 base_uv, vec2 offset_uv) {
	bool hit_wall = false;
	vec2 sample_uv = flow_solve_neighbor_uv(base_uv, offset_uv, hit_wall);
	return texture(occupancy_texture, sample_uv).g;
}

void fragment() {
	if (texture(occupancy_texture, UV).r > 0.5) {
		COLOR = flow_solve_encode_velocity(vec2(0.0));
	} else {
		vec2 velocity = flow_solve_decode_velocity(texture(flow_texture, UV));
		float proximity = texture(occupancy_texture, UV).g;
		float ring_weight = smoothstep(ring_start, max(ring_full, ring_start + FLOW_SOLVE_EPSILON), proximity);
		if (ring_weight > FLOW_SOLVE_EPSILON) {
			float safe_size = max(size, 1.0);
			vec2 texel = vec2(2.0 / safe_size);
			vec2 toward_solid = vec2(
				proximity_at(UV, vec2(texel.x, 0.0)) - proximity_at(UV, vec2(-texel.x, 0.0)),
				proximity_at(UV, vec2(0.0, texel.y)) - proximity_at(UV, vec2(0.0, -texel.y))
			);
			float gradient_magnitude = length(toward_solid);
			if (gradient_magnitude > FLOW_SOLVE_EPSILON) {
				vec2 boundary_normal = toward_solid / gradient_magnitude;
				float into_solid = dot(velocity, boundary_normal);
				if (into_solid > 0.0) {
					velocity -= boundary_normal * into_solid * ring_weight;
				}
			}
		}
		COLOR = flow_solve_encode_velocity(velocity);
	}
}
