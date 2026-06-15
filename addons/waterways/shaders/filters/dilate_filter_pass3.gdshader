shader_type canvas_item;

uniform sampler2D distance_texture : repeat_disable, filter_nearest;
uniform sampler2D color_texture : hint_default_white, repeat_disable, filter_nearest;
uniform float fill = 1.0;

void fragment() {
	vec3 dist = texture(distance_texture, UV).rgb;
	COLOR = vec4(texture(color_texture, dist.yz).rgb * mix(dist.x, 1.0, fill), 1.0);
	//COLOR = vec4(dist.xxx, 1.0);
	//$source($distance($uv).yz) * mix($distance($uv).x, 1.0, $amount)
}
