shader_type canvas_item;
render_mode unshaded;

uniform mat4 world_to_ripple_uv = mat4(1.0);
uniform vec3 marker_world_0 = vec3(0.0);
uniform vec3 marker_world_1 = vec3(0.0);
uniform vec3 marker_world_2 = vec3(0.0);
uniform vec3 marker_world_3 = vec3(0.0);
uniform vec4 marker_color_0 : source_color = vec4(1.0, 0.05, 0.05, 1.0);
uniform vec4 marker_color_1 : source_color = vec4(0.05, 1.0, 0.20, 1.0);
uniform vec4 marker_color_2 : source_color = vec4(0.10, 0.35, 1.0, 1.0);
uniform vec4 marker_color_3 : source_color = vec4(1.0, 0.15, 0.85, 1.0);
uniform float marker_radius_uv : hint_range(0.001, 0.1) = 0.026;

vec3 map_world_to_ripple(vec3 world_position) {
	return (world_to_ripple_uv * vec4(world_position, 1.0)).xyz;
}

float in_field(vec2 marker_uv) {
	vec2 lower = step(vec2(0.0), marker_uv);
	vec2 upper = step(marker_uv, vec2(1.0));
	return lower.x * lower.y * upper.x * upper.y;
}

float marker_disk(vec2 uv, vec3 world_position) {
	vec3 mapped = map_world_to_ripple(world_position);
	vec2 marker_uv = mapped.xz;
	float distance_to_marker = distance(uv, marker_uv);
	return (1.0 - smoothstep(marker_radius_uv * 0.55, marker_radius_uv, distance_to_marker)) * in_field(marker_uv);
}

void apply_marker(inout vec3 color, vec2 uv, vec3 world_position, vec3 marker_color) {
	float disk = marker_disk(uv, world_position);
	color = mix(color, marker_color, disk);
}

void fragment() {
	vec2 uv = clamp(UV, vec2(0.0), vec2(1.0));
	vec2 grid = abs(fract(uv * 8.0) - vec2(0.5));
	float grid_line = 1.0 - smoothstep(0.0, 0.035, min(grid.x, grid.y));
	float edge_line = 1.0 - smoothstep(0.0, 0.012, min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y)));
	vec3 color = vec3(0.025, 0.035, 0.045) + vec3(0.05, 0.07, 0.08) * grid_line + vec3(0.10, 0.12, 0.13) * edge_line;

	apply_marker(color, uv, marker_world_0, marker_color_0.rgb);
	apply_marker(color, uv, marker_world_1, marker_color_1.rgb);
	apply_marker(color, uv, marker_world_2, marker_color_2.rgb);
	apply_marker(color, uv, marker_world_3, marker_color_3.rgb);

	COLOR = vec4(color, 1.0);
}
