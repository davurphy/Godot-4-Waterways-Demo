shader_type canvas_item;
#include "res://addons/waterways/shaders/flow_pack.gdshaderinc"

uniform sampler2D input_texture : repeat_disable, filter_nearest;

vec3 nm2flow(vec2 x) {
    x -= vec2(0.5);
    vec3 rv = vec3(sign(x.x)*vec2(-x.y, x.x), -1.0);
    return normalize(rv);
}

void fragment() {
    vec4 texture_sample = textureLod(input_texture, UV, 0.0);
    vec3 flow_direction = nm2flow(texture_sample.xy);
    COLOR = vec4(flow_pack_encode_unclamped(flow_direction.xy), flow_direction.z * 0.5 + 0.5, 1.0);
}
