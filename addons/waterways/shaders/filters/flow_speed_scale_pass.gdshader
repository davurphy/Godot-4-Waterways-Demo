shader_type canvas_item;

// Scales the finished flow vectors by the authored per-point flow speed
// factor. Runs after the pressure projection (or legacy steering): scaling by
// a positive scalar preserves direction, so the v.n = 0 non-penetration
// guarantee survives.
// speed_texture R packs factor / speed_factor_max (0.5 = factor 1.0, neutral).
uniform sampler2D flow_texture : repeat_disable, filter_nearest;
uniform sampler2D speed_texture : repeat_disable, filter_nearest;
uniform float speed_factor_max = 2.0;

void fragment() {
    vec4 flow_sample = textureLod(flow_texture, UV, 0.0);
    float factor = textureLod(speed_texture, UV, 0.0).r * speed_factor_max;
    vec2 flow_vector = (flow_sample.rg - vec2(0.5)) * 2.0 * factor;
    COLOR = vec4(clamp(flow_vector * 0.5 + vec2(0.5), vec2(0.0), vec2(1.0)), flow_sample.ba);
}
