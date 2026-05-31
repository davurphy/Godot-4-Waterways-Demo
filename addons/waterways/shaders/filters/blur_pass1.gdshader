shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture : repeat_disable, filter_nearest;
uniform float blur = 0.1;

const float EPSILON = 0.0001;

vec4 fct(vec2 uv) {
	float safe_size = max(size, 1.0);
	float safe_blur = max(abs(blur), EPSILON);
	float e = 1.0 / safe_size;
	vec4 rv = vec4(0.0);
	float sum = 0.0;
	for (float i = -50.0; i <= 50.0; i += 1.0) {
		float coef = exp(-0.5 * (pow(i / safe_blur, 2.0)))/(6.28318530718 * safe_blur * safe_blur);
		rv += texture(input_texture, uv + vec2(i * e, 0.0)) * coef;
		sum += coef;
	}
	return rv / max(sum, EPSILON);
}

void fragment() {
	COLOR = fct(UV);
}
