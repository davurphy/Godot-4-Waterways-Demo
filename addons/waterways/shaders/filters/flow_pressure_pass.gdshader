shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture : repeat_disable, filter_nearest;
uniform float rows = 1.0;

void fragment() {
	float safe_size = max(size, 1.0);
	float safe_rows = max(rows, 1.0);
	float value = 0.0;
	float pixel_size = 1.0 / safe_size;
	int row_size = max(1, int(safe_size) / int(safe_rows));
	for (int i = 0; i < row_size; i++) {
		float base_x = floor(UV.x * safe_rows) / safe_rows;
		vec2 new_uv = vec2(base_x + float(i) / safe_size, UV.y) + pixel_size / 2.0;
		value += textureLod(input_texture, new_uv, 0.0).r;
	}
	value /= float(row_size);
	COLOR = vec4(vec3(value), 1.0);
}
