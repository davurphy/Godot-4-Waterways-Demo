shader_type canvas_item;
render_mode blend_disabled;

// Packs the water occupancy texture consumed by the river shaders:
// R: crisp solid mask (1 = inside obstacle / protruding terrain, 0 = water)
// G: solid proximity (1 at the solid surface, falling to 0 at the ramp radius)
// The proximity input is the raw dilate pass 1+2 distance field.

uniform sampler2D solid_texture : hint_default_black, repeat_disable, filter_nearest;
uniform sampler2D proximity_texture : hint_default_black, repeat_disable, filter_nearest;

void fragment() {
	float solid = step(0.5, texture(solid_texture, UV).r);
	float proximity = clamp(texture(proximity_texture, UV).r, 0.0, 1.0);
	COLOR = vec4(solid, max(proximity, solid), 0.0, 1.0);
}
