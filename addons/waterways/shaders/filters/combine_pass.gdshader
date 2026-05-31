shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D r_texture : hint_default_black, repeat_disable, filter_nearest;
uniform sampler2D g_texture : hint_default_black, repeat_disable, filter_nearest;
uniform sampler2D b_texture : hint_default_black, repeat_disable, filter_nearest;
uniform sampler2D a_texture : hint_default_white, repeat_disable, filter_nearest;

void fragment() {
	COLOR = vec4(texture(r_texture, UV).r, texture(g_texture, UV).g, texture(b_texture, UV).b, texture(a_texture, UV).r);
}
