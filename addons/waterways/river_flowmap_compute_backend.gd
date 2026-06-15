# Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends RefCounted

const DEFAULT_ELEMENT_COUNT := 257
const DEFAULT_ITERATIONS := 9
const DEFAULT_LOCAL_SIZE := 64
const DEFAULT_SYNC_WAIT_FRAMES := 3
const UINT32_MOD := 4294967296
const DEFAULT_SOLVE_TEXTURE_SIZE := Vector2i(16, 16)
const DEFAULT_SOLVE_LOCAL_SIZE := 8
const DEFAULT_SOLVE_STRIDE := 2
const DEFAULT_SOLVE_SOURCE_SIZE := 13.0
const DEFAULT_SOLVE_ATLAS_COLUMNS := 4
const DEFAULT_STACK_TEXTURE_SIZE := Vector2i(106, 106)
const DEFAULT_STACK_SOURCE_SIZE := 64.0
const DEFAULT_STACK_ATLAS_COLUMNS := 5
const DEFAULT_STACK_STRIDES := [32, 16, 8, 4, 2, 1, 1, 1]
const DEFAULT_STACK_ITERATIONS_PER_STRIDE := 5
const DEFAULT_PROJECTION_TANGENCY_PASSES := 2
const FLOW_SOLVE_EPSILON := 0.0001
const FLOW_SOLVE_DIV_SCALE := 0.25
const FLOW_SOLVE_PRESSURE_SCALE := 0.03125

const PING_PONG_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) readonly restrict buffer SourceBuffer {
	uint values[];
}
source_buffer;
layout(set = 0, binding = 1, std430) writeonly restrict buffer DestinationBuffer {
	uint values[];
}
destination_buffer;

const uint ELEMENT_COUNT = $ELEMENT_COUNTu;

void main() {
	uint index = gl_GlobalInvocationID.x;
	if (index >= ELEMENT_COUNT) {
		return;
	}
	uint value = source_buffer.values[index];
	destination_buffer.values[index] = value * 1664525u + 1013904223u + index * 747796405u;
}
"""

const PRESSURE_JACOBI_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = $LOCAL_SIZE, local_size_z = 1) in;
layout(rgba32f, set = 0, binding = 0) uniform readonly restrict image2D pressure_image;
layout(rgba32f, set = 0, binding = 1) uniform readonly restrict image2D divergence_image;
layout(rgba32f, set = 0, binding = 2) uniform readonly restrict image2D occupancy_image;
layout(rgba32f, set = 0, binding = 3) uniform writeonly restrict image2D output_image;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;
const int STRIDE = $STRIDE;
const int ATLAS_COLUMNS = $ATLAS_COLUMNS;
const float SOURCE_SIZE = $SOURCE_SIZE;
const float FLOW_SOLVE_EPSILON = 0.0001;
const float FLOW_SOLVE_DIV_SCALE = 0.25;
const float FLOW_SOLVE_PRESSURE_SCALE = 0.03125;
const float PRESSURE_DIVERGENCE_SCALE = $PRESSURE_DIVERGENCE_SCALE;

float decode_divergence(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_DIV_SCALE;
}

float decode_pressure(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_PRESSURE_SCALE;
}

vec4 encode_pressure(float pressure) {
	return vec4(clamp(pressure * FLOW_SOLVE_PRESSURE_SCALE + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0);
}

bool is_solid(ivec2 pos) {
	return imageLoad(occupancy_image, pos).r > 0.5;
}

vec2 pixel_center_uv(ivec2 pos) {
	return (vec2(pos) + vec2(0.5)) / vec2(float(WIDTH), float(HEIGHT));
}

vec2 atlas_column_clamp_compute(vec2 sample_uv, vec2 base_uv) {
	float columns = max(float(ATLAS_COLUMNS), 1.0);
	if (columns <= 1.0) {
		return sample_uv;
	}
	float column_width = 1.0 / columns;
	float column_min = floor(base_uv.x * columns) * column_width;
	float padding = column_width * 0.02;
	return vec2(clamp(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y);
}

ivec2 sample_pos_from_uv(vec2 uv) {
	vec2 clamped_uv = clamp(uv, vec2(0.0), vec2(1.0));
	ivec2 sample_pos = ivec2(floor(clamped_uv * vec2(float(WIDTH), float(HEIGHT))));
	return ivec2(clamp(sample_pos.x, 0, WIDTH - 1), clamp(sample_pos.y, 0, HEIGHT - 1));
}

ivec2 neighbor_pos(ivec2 base, vec2 offset_uv, out bool hit_wall) {
	vec2 base_uv = pixel_center_uv(base);
	vec2 requested = base_uv + offset_uv;
	vec2 clamped = atlas_column_clamp_compute(requested, base_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	hit_wall = abs(clamped.x - requested.x) > FLOW_SOLVE_EPSILON;
	return sample_pos_from_uv(clamped);
}

float neighbor_pressure(ivec2 base, vec2 offset_uv, float center_pressure) {
	bool hit_wall = false;
	ivec2 sample_pos = neighbor_pos(base, offset_uv, hit_wall);
	if (hit_wall || is_solid(sample_pos)) {
		return center_pressure;
	}
	return decode_pressure(imageLoad(pressure_image, sample_pos));
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	float center_pressure = decode_pressure(imageLoad(pressure_image, pos));
	if (is_solid(pos)) {
		imageStore(output_image, pos, encode_pressure(center_pressure));
		return;
	}
	float safe_size = max(SOURCE_SIZE, 1.0);
	float safe_stride = float(max(STRIDE, 1));
	vec2 step_uv = vec2(safe_stride / safe_size);
	float left = neighbor_pressure(pos, vec2(-step_uv.x, 0.0), center_pressure);
	float right = neighbor_pressure(pos, vec2(step_uv.x, 0.0), center_pressure);
	float up = neighbor_pressure(pos, vec2(0.0, -step_uv.y), center_pressure);
	float down = neighbor_pressure(pos, vec2(0.0, step_uv.y), center_pressure);
	float divergence = decode_divergence(imageLoad(divergence_image, pos));
	float new_pressure = (left + right + up + down - divergence * safe_stride * safe_stride * PRESSURE_DIVERGENCE_SCALE) * 0.25;
	imageStore(output_image, pos, encode_pressure(new_pressure));
}
"""

const PRESSURE_JACOBI_SAMPLER_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = $LOCAL_SIZE, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D pressure_image;
layout(set = 0, binding = 1) uniform sampler2D divergence_image;
layout(set = 0, binding = 2) uniform sampler2D occupancy_image;
layout(rgba32f, set = 0, binding = 3) uniform writeonly restrict image2D output_image;
layout(set = 0, binding = 4, std430) readonly restrict buffer JacobiParams {
	float stride;
}
jacobi_params;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;
const int ATLAS_COLUMNS = $ATLAS_COLUMNS;
const float SOURCE_SIZE = $SOURCE_SIZE;
const int CANVAS_TIE_MODE = $CANVAS_TIE_MODE;
const float FLOW_SOLVE_EPSILON = 0.0001;
const float FLOW_SOLVE_DIV_SCALE = 0.25;
const float FLOW_SOLVE_PRESSURE_SCALE = 0.03125;

float decode_divergence(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_DIV_SCALE;
}

float decode_pressure(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_PRESSURE_SCALE;
}

vec4 encode_pressure(float pressure) {
	return vec4(clamp(pressure * FLOW_SOLVE_PRESSURE_SCALE + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0);
}

vec2 pixel_center_uv(ivec2 pos) {
	return (vec2(pos) + vec2(0.5)) / vec2(float(WIDTH), float(HEIGHT));
}

bool is_solid(vec2 uv) {
	return textureLod(occupancy_image, uv, 0.0).r > 0.5;
}

vec2 atlas_column_clamp_compute(vec2 sample_uv, vec2 base_uv) {
	float columns = max(float(ATLAS_COLUMNS), 1.0);
	if (columns <= 1.0) {
		return sample_uv;
	}
	float column_width = 1.0 / columns;
	float column_min = floor(base_uv.x * columns) * column_width;
	float padding = column_width * 0.02;
	return vec2(clamp(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y);
}

vec2 apply_canvas_tie_bias(vec2 sample_uv, vec2 base_uv, vec2 offset_uv) {
	if ((CANVAS_TIE_MODE != 1 && CANVAS_TIE_MODE != 2) || abs(offset_uv.x) > FLOW_SOLVE_EPSILON) {
		return sample_uv;
	}
	float safe_size = max(SOURCE_SIZE, 1.0);
	float stride_uv = 16.0 / safe_size;
	if (abs(abs(offset_uv.y) - stride_uv) > 0.0001) {
		return sample_uv;
	}
	float sample_texel_boundary = sample_uv.y * float(HEIGHT);
	if (abs(sample_texel_boundary - round(sample_texel_boundary)) > 0.0002) {
		return sample_uv;
	}
	vec2 base_texel = base_uv * vec2(float(WIDTH), float(HEIGHT)) - vec2(0.5);
	float bias = 0.25 / float(HEIGHT);
	bool source_edge_row_lower = CANVAS_TIE_MODE == 2 && abs(base_texel.y - (floor(safe_size) - 1.0)) < 0.5;
	sample_uv.y += (!source_edge_row_lower && base_texel.x < base_texel.y) ? bias : -bias;
	return sample_uv;
}

vec2 neighbor_uv(vec2 base_uv, vec2 offset_uv, out bool hit_wall) {
	vec2 requested = base_uv + offset_uv;
	vec2 clamped = atlas_column_clamp_compute(requested, base_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	clamped = apply_canvas_tie_bias(clamped, base_uv, offset_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	hit_wall = abs(clamped.x - requested.x) > FLOW_SOLVE_EPSILON;
	return clamped;
}

float neighbor_pressure(vec2 base_uv, vec2 offset_uv, float center_pressure) {
	bool hit_wall = false;
	vec2 sample_uv = neighbor_uv(base_uv, offset_uv, hit_wall);
	if (hit_wall || is_solid(sample_uv)) {
		return center_pressure;
	}
	return decode_pressure(textureLod(pressure_image, sample_uv, 0.0));
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	vec2 base_uv = pixel_center_uv(pos);
	float center_pressure = decode_pressure(textureLod(pressure_image, base_uv, 0.0));
	if (is_solid(base_uv)) {
		imageStore(output_image, pos, encode_pressure(center_pressure));
		return;
	}
	float safe_size = max(SOURCE_SIZE, 1.0);
	float safe_stride = max(jacobi_params.stride, 1.0);
	vec2 step_uv = vec2(safe_stride / safe_size);
	float left = neighbor_pressure(base_uv, vec2(-step_uv.x, 0.0), center_pressure);
	float right = neighbor_pressure(base_uv, vec2(step_uv.x, 0.0), center_pressure);
	float up = neighbor_pressure(base_uv, vec2(0.0, -step_uv.y), center_pressure);
	float down = neighbor_pressure(base_uv, vec2(0.0, step_uv.y), center_pressure);
	float divergence = decode_divergence(textureLod(divergence_image, base_uv, 0.0));
	float new_pressure = (left + right + up + down - divergence * safe_stride * safe_stride) * 0.25;
	imageStore(output_image, pos, encode_pressure(new_pressure));
}
"""

const FLOW_DIVERGENCE_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = $LOCAL_SIZE, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D flow_image;
layout(set = 0, binding = 1) uniform sampler2D occupancy_image;
layout(rgba32f, set = 0, binding = 2) uniform writeonly restrict image2D output_image;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;
const int ATLAS_COLUMNS = $ATLAS_COLUMNS;
const float SOURCE_SIZE = $SOURCE_SIZE;
const float FLOW_SOLVE_EPSILON = 0.0001;
const float FLOW_SOLVE_DIV_SCALE = 0.25;

vec2 decode_velocity(vec4 color) {
	return color.rg * 2.0 - 1.0;
}

vec4 encode_divergence(float divergence) {
	return vec4(clamp(divergence * FLOW_SOLVE_DIV_SCALE + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0);
}

bool is_solid(vec2 uv) {
	return texture(occupancy_image, uv).r > 0.5;
}

vec2 velocity_at(vec2 uv) {
	return is_solid(uv) ? vec2(0.0) : decode_velocity(texture(flow_image, uv));
}

vec2 pixel_center_uv(ivec2 pos) {
	return (vec2(pos) + vec2(0.5)) / vec2(float(WIDTH), float(HEIGHT));
}

vec2 atlas_column_clamp_compute(vec2 sample_uv, vec2 base_uv) {
	float columns = max(float(ATLAS_COLUMNS), 1.0);
	if (columns <= 1.0) {
		return sample_uv;
	}
	float column_width = 1.0 / columns;
	float column_min = floor(base_uv.x * columns) * column_width;
	float padding = column_width * 0.02;
	return vec2(clamp(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y);
}

vec2 neighbor_uv(vec2 base_uv, vec2 offset_uv, out bool hit_wall) {
	vec2 requested = base_uv + offset_uv;
	vec2 clamped = atlas_column_clamp_compute(requested, base_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	hit_wall = abs(clamped.x - requested.x) > FLOW_SOLVE_EPSILON;
	return clamped;
}

vec2 neighbor_velocity(vec2 base_uv, vec2 offset_uv, vec2 axis_normal, vec2 center_velocity) {
	bool hit_wall = false;
	vec2 sample_uv = neighbor_uv(base_uv, offset_uv, hit_wall);
	if (hit_wall || is_solid(sample_uv)) {
		return center_velocity - 2.0 * dot(center_velocity, axis_normal) * axis_normal;
	}
	return velocity_at(sample_uv);
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	vec2 base_uv = pixel_center_uv(pos);
	if (is_solid(base_uv)) {
		imageStore(output_image, pos, encode_divergence(0.0));
		return;
	}
	float safe_size = max(SOURCE_SIZE, 1.0);
	vec2 texel = vec2(1.0 / safe_size);
	vec2 center = velocity_at(base_uv);
	vec2 left = neighbor_velocity(base_uv, vec2(-texel.x, 0.0), vec2(-1.0, 0.0), center);
	vec2 right = neighbor_velocity(base_uv, vec2(texel.x, 0.0), vec2(1.0, 0.0), center);
	vec2 up = neighbor_velocity(base_uv, vec2(0.0, -texel.y), vec2(0.0, -1.0), center);
	vec2 down = neighbor_velocity(base_uv, vec2(0.0, texel.y), vec2(0.0, 1.0), center);
	float divergence = 0.5 * ((right.x - left.x) + (down.y - up.y));
	imageStore(output_image, pos, encode_divergence(divergence));
}
"""

const FLOW_GRADIENT_SUBTRACT_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = $LOCAL_SIZE, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D flow_image;
layout(set = 0, binding = 1) uniform sampler2D pressure_image;
layout(set = 0, binding = 2) uniform sampler2D occupancy_image;
layout(rgba32f, set = 0, binding = 3) uniform writeonly restrict image2D output_image;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;
const int ATLAS_COLUMNS = $ATLAS_COLUMNS;
const float SOURCE_SIZE = $SOURCE_SIZE;
const float FLOW_SOLVE_EPSILON = 0.0001;
const float FLOW_SOLVE_PRESSURE_SCALE = 0.03125;

vec2 decode_velocity(vec4 color) {
	return color.rg * 2.0 - 1.0;
}

vec4 encode_velocity(vec2 velocity) {
	return vec4(clamp(velocity * 0.5 + 0.5, vec2(0.0), vec2(1.0)), 0.0, 1.0);
}

float decode_pressure(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_PRESSURE_SCALE;
}

bool is_solid(vec2 uv) {
	return texture(occupancy_image, uv).r > 0.5;
}

vec2 pixel_center_uv(ivec2 pos) {
	return (vec2(pos) + vec2(0.5)) / vec2(float(WIDTH), float(HEIGHT));
}

vec2 atlas_column_clamp_compute(vec2 sample_uv, vec2 base_uv) {
	float columns = max(float(ATLAS_COLUMNS), 1.0);
	if (columns <= 1.0) {
		return sample_uv;
	}
	float column_width = 1.0 / columns;
	float column_min = floor(base_uv.x * columns) * column_width;
	float padding = column_width * 0.02;
	return vec2(clamp(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y);
}

vec2 neighbor_uv(vec2 base_uv, vec2 offset_uv, out bool hit_wall) {
	vec2 requested = base_uv + offset_uv;
	vec2 clamped = atlas_column_clamp_compute(requested, base_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	hit_wall = abs(clamped.x - requested.x) > FLOW_SOLVE_EPSILON;
	return clamped;
}

float neighbor_pressure(vec2 base_uv, vec2 offset_uv, float center_pressure) {
	bool hit_wall = false;
	vec2 sample_uv = neighbor_uv(base_uv, offset_uv, hit_wall);
	if (hit_wall || is_solid(sample_uv)) {
		return center_pressure;
	}
	return decode_pressure(texture(pressure_image, sample_uv));
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	vec2 base_uv = pixel_center_uv(pos);
	if (is_solid(base_uv)) {
		imageStore(output_image, pos, encode_velocity(vec2(0.0)));
		return;
	}
	float safe_size = max(SOURCE_SIZE, 1.0);
	vec2 texel = vec2(1.0 / safe_size);
	float center_pressure = decode_pressure(texture(pressure_image, base_uv));
	float left = neighbor_pressure(base_uv, vec2(-texel.x, 0.0), center_pressure);
	float right = neighbor_pressure(base_uv, vec2(texel.x, 0.0), center_pressure);
	float up = neighbor_pressure(base_uv, vec2(0.0, -texel.y), center_pressure);
	float down = neighbor_pressure(base_uv, vec2(0.0, texel.y), center_pressure);
	vec2 gradient = 0.5 * vec2(right - left, down - up);
	vec2 velocity = decode_velocity(texture(flow_image, base_uv)) - gradient;
	imageStore(output_image, pos, encode_velocity(velocity));
}
"""

const FLOW_BOUNDARY_TANGENCY_SHADER_TEMPLATE := """
#version 450

layout(local_size_x = $LOCAL_SIZE, local_size_y = $LOCAL_SIZE, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D flow_image;
layout(set = 0, binding = 1) uniform sampler2D occupancy_image;
layout(rgba32f, set = 0, binding = 2) uniform writeonly restrict image2D output_image;

const int WIDTH = $WIDTH;
const int HEIGHT = $HEIGHT;
const int ATLAS_COLUMNS = $ATLAS_COLUMNS;
const float SOURCE_SIZE = $SOURCE_SIZE;
const float RING_START = $RING_START;
const float RING_FULL = $RING_FULL;
const float FLOW_SOLVE_EPSILON = 0.0001;

vec2 decode_velocity(vec4 color) {
	return color.rg * 2.0 - 1.0;
}

vec4 encode_velocity(vec2 velocity) {
	return vec4(clamp(velocity * 0.5 + 0.5, vec2(0.0), vec2(1.0)), 0.0, 1.0);
}

bool is_solid(vec2 uv) {
	return texture(occupancy_image, uv).r > 0.5;
}

vec2 pixel_center_uv(ivec2 pos) {
	return (vec2(pos) + vec2(0.5)) / vec2(float(WIDTH), float(HEIGHT));
}

vec2 atlas_column_clamp_compute(vec2 sample_uv, vec2 base_uv) {
	float columns = max(float(ATLAS_COLUMNS), 1.0);
	if (columns <= 1.0) {
		return sample_uv;
	}
	float column_width = 1.0 / columns;
	float column_min = floor(base_uv.x * columns) * column_width;
	float padding = column_width * 0.02;
	return vec2(clamp(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y);
}

vec2 neighbor_uv(vec2 base_uv, vec2 offset_uv) {
	vec2 requested = base_uv + offset_uv;
	vec2 clamped = atlas_column_clamp_compute(requested, base_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	return clamped;
}

float proximity_at(vec2 base_uv, vec2 offset_uv) {
	return texture(occupancy_image, neighbor_uv(base_uv, offset_uv)).g;
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= WIDTH || pos.y >= HEIGHT) {
		return;
	}
	vec2 base_uv = pixel_center_uv(pos);
	if (is_solid(base_uv)) {
		imageStore(output_image, pos, encode_velocity(vec2(0.0)));
		return;
	}
	vec2 velocity = decode_velocity(texture(flow_image, base_uv));
	float proximity = texture(occupancy_image, base_uv).g;
	float ring_weight = smoothstep(RING_START, max(RING_FULL, RING_START + FLOW_SOLVE_EPSILON), proximity);
	if (ring_weight > FLOW_SOLVE_EPSILON) {
		float safe_size = max(SOURCE_SIZE, 1.0);
		vec2 texel = vec2(2.0 / safe_size);
		vec2 toward_solid = vec2(
			proximity_at(base_uv, vec2(texel.x, 0.0)) - proximity_at(base_uv, vec2(-texel.x, 0.0)),
			proximity_at(base_uv, vec2(0.0, texel.y)) - proximity_at(base_uv, vec2(0.0, -texel.y))
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
	imageStore(output_image, pos, encode_velocity(velocity));
}
"""

var _rd: RenderingDevice = null
var _owned_rids: Array[RID] = []
var _submitted_without_sync := false
var _aborted := false
var _warning_callback := Callable()
var _last_report := {}


func run_non_replacing_smoke(config: Dictionary = {}, cancellation: Callable = Callable()) -> Dictionary:
	_aborted = false
	_warning_callback = config.get("warning_callback", Callable())
	var result := await _run_non_replacing_smoke_internal(config, cancellation)
	return _finalize_run_result(result)


func run_non_replacing_solve_filter_step(config: Dictionary = {}, cancellation: Callable = Callable()) -> Dictionary:
	_aborted = false
	_warning_callback = config.get("warning_callback", Callable())
	var result := await _run_non_replacing_solve_filter_step_internal(config, cancellation)
	return _finalize_run_result(result)


func run_non_replacing_solve_filter_stack(config: Dictionary = {}, cancellation: Callable = Callable()) -> Dictionary:
	_aborted = false
	_warning_callback = config.get("warning_callback", Callable())
	var result := await _run_non_replacing_solve_filter_stack_internal(config, cancellation)
	return _finalize_run_result(result)


func run_non_replacing_solve_filter_projection(config: Dictionary = {}, cancellation: Callable = Callable()) -> Dictionary:
	_aborted = false
	_warning_callback = config.get("warning_callback", Callable())
	var result := await _run_non_replacing_solve_filter_projection_internal(config, cancellation)
	return _finalize_run_result(result)


func _finalize_run_result(result: Dictionary) -> Dictionary:
	cleanup()
	result["cleanup_completed"] = true
	result["cleanup_owned_rid_count_after_cleanup"] = _owned_rids.size()
	result["cleanup_rendering_device_released"] = _rd == null
	result["cleanup_submitted_without_sync_after_cleanup"] = _submitted_without_sync
	_last_report = result.duplicate(true)
	_warning_callback = Callable()
	return result


func make_pressure_jacobi_validation_fixture(config: Dictionary = {}) -> Dictionary:
	var texture_size := Vector2i(
		maxi(4, int(config.get("texture_width", DEFAULT_SOLVE_TEXTURE_SIZE.x))),
		maxi(4, int(config.get("texture_height", DEFAULT_SOLVE_TEXTURE_SIZE.y)))
	)
	var source_size := maxf(1.0, float(config.get("source_size", DEFAULT_SOLVE_SOURCE_SIZE)))
	var stride := maxi(1, int(config.get("stride", DEFAULT_SOLVE_STRIDE)))
	var atlas_columns := maxi(1, int(config.get("atlas_columns", DEFAULT_SOLVE_ATLAS_COLUMNS)))
	var fixture_seed := int(config.get("fixture_seed", 37))
	var fixture := _make_pressure_jacobi_fixture(texture_size, source_size, stride, atlas_columns, fixture_seed)
	fixture["pressure_image"] = _image_from_rgba32f_bytes(texture_size, fixture.get("pressure_bytes", PackedByteArray()))
	fixture["divergence_image"] = _image_from_rgba32f_bytes(texture_size, fixture.get("divergence_bytes", PackedByteArray()))
	fixture["occupancy_image"] = _image_from_rgba32f_bytes(texture_size, fixture.get("occupancy_bytes", PackedByteArray()))
	fixture["texture_size"] = texture_size
	fixture["source_size"] = source_size
	fixture["stride"] = stride
	fixture["atlas_columns"] = atlas_columns
	fixture["fixture_seed"] = fixture_seed
	return fixture


func make_pressure_jacobi_stack_validation_fixture(config: Dictionary = {}) -> Dictionary:
	var texture_size := Vector2i(
		maxi(4, int(config.get("texture_width", DEFAULT_STACK_TEXTURE_SIZE.x))),
		maxi(4, int(config.get("texture_height", DEFAULT_STACK_TEXTURE_SIZE.y)))
	)
	var source_size := maxf(1.0, float(config.get("source_size", DEFAULT_STACK_SOURCE_SIZE)))
	var atlas_columns := maxi(1, int(config.get("atlas_columns", DEFAULT_STACK_ATLAS_COLUMNS)))
	var fixture_seed := int(config.get("fixture_seed", 97))
	var strides := _config_int_array(config, "flow_projection_strides", DEFAULT_STACK_STRIDES)
	var iterations_per_stride := maxi(1, int(config.get("flow_projection_iterations_per_stride", DEFAULT_STACK_ITERATIONS_PER_STRIDE)))
	var fixture := _make_pressure_jacobi_stack_fixture(texture_size, source_size, strides, iterations_per_stride, atlas_columns, fixture_seed)
	fixture["initial_pressure_image"] = _image_from_rgba32f_bytes(texture_size, fixture.get("initial_pressure_bytes", PackedByteArray()))
	fixture["divergence_image"] = _image_from_rgba32f_bytes(texture_size, fixture.get("divergence_bytes", PackedByteArray()))
	fixture["occupancy_image"] = _image_from_rgba32f_bytes(texture_size, fixture.get("occupancy_bytes", PackedByteArray()))
	fixture["texture_size"] = texture_size
	fixture["source_size"] = source_size
	fixture["atlas_columns"] = atlas_columns
	fixture["fixture_seed"] = fixture_seed
	fixture["flow_projection_strides"] = strides
	fixture["flow_projection_iterations_per_stride"] = iterations_per_stride
	return fixture


func abort() -> void:
	_aborted = true
	cleanup()


func cleanup() -> void:
	if _rd != null:
		if _submitted_without_sync:
			_rd.sync()
			_submitted_without_sync = false
		_free_owned_rids()
		_rd.free()
	_rd = null
	_owned_rids.clear()


func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


func _run_non_replacing_smoke_internal(config: Dictionary, cancellation: Callable) -> Dictionary:
	var element_count := maxi(1, int(config.get("element_count", DEFAULT_ELEMENT_COUNT)))
	var iterations := maxi(1, int(config.get("iterations", DEFAULT_ITERATIONS)))
	var local_size := maxi(1, int(config.get("local_size", DEFAULT_LOCAL_SIZE)))
	var wait_frames := maxi(0, int(config.get("sync_wait_frames", DEFAULT_SYNC_WAIT_FRAMES)))
	var result := _make_base_report(element_count, iterations, local_size, wait_frames)
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		result["ok"] = false
		result["skipped"] = true
		result["reason"] = "local_rendering_device_unavailable"
		result["message"] = "Local RenderingDevice is unavailable; run windowed under a RenderingDevice renderer."
		_emit_warning("Waterways: R7 compute backend skeleton skipped because local RenderingDevice is unavailable.")
		return result

	_fill_device_report(result)
	if not bool(result.get("storage_texture_format_supported", false)):
		result["ok"] = false
		result["reason"] = "storage_texture_format_unavailable"
		return result

	var shader := _compile_compute_shader(_shader_source(element_count, local_size), "waterways_r7_non_replacing_smoke")
	if not shader.is_valid():
		result["ok"] = false
		result["reason"] = "compute_shader_compile_failed"
		return result
	_owned_rids.append(shader)
	var pipeline := _rd.compute_pipeline_create(shader)
	if not pipeline.is_valid():
		result["ok"] = false
		result["reason"] = "compute_pipeline_create_failed"
		return result
	_owned_rids.append(pipeline)

	var byte_size := element_count * 4
	var initial_values := _make_initial_values(1729, element_count)
	var zero_bytes := PackedByteArray()
	zero_bytes.resize(byte_size)
	var buffer_a := _rd.storage_buffer_create(byte_size, _u32_array_to_bytes(initial_values))
	var buffer_b := _rd.storage_buffer_create(byte_size, zero_bytes)
	if not buffer_a.is_valid() or not buffer_b.is_valid():
		result["ok"] = false
		result["reason"] = "storage_buffer_create_failed"
		return result
	_owned_rids.append(buffer_a)
	_owned_rids.append(buffer_b)
	var set_ab := _make_ping_pong_uniform_set(shader, buffer_a, buffer_b)
	var set_ba := _make_ping_pong_uniform_set(shader, buffer_b, buffer_a)
	if not set_ab.is_valid() or not set_ba.is_valid():
		result["ok"] = false
		result["reason"] = "uniform_set_create_failed"
		return result
	_owned_rids.append(set_ab)
	_owned_rids.append(set_ba)

	var expected_values := initial_values.duplicate()
	for iteration in iterations:
		if _is_cancellation_requested(cancellation):
			result["ok"] = false
			result["reason"] = "cancelled"
			return result
		var use_ab := iteration % 2 == 0
		_record_dispatch(pipeline, set_ab if use_ab else set_ba, element_count, local_size)
		expected_values = _advance_values(expected_values)
	_rd.submit()
	_submitted_without_sync = true
	await _wait_process_frames(config.get("frame_wait_source", null), wait_frames, cancellation)
	if _rd == null:
		result["ok"] = false
		result["reason"] = "cancelled"
		return result
	_rd.sync()
	_submitted_without_sync = false
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	var final_buffer := buffer_a if iterations % 2 == 0 else buffer_b
	var actual_bytes := _rd.buffer_get_data(final_buffer, 0, byte_size)
	var actual_values := _bytes_to_u32_array(actual_bytes, element_count)
	var mismatch := _first_mismatch(expected_values, actual_values)
	if not mismatch.is_empty():
		result["ok"] = false
		result["reason"] = "readback_mismatch"
		result["mismatch"] = mismatch
		return result

	result["ok"] = true
	result["checksum"] = _checksum_u32(actual_values)
	result["readback_byte_count"] = actual_bytes.size()
	return result


func _run_non_replacing_solve_filter_step_internal(config: Dictionary, cancellation: Callable) -> Dictionary:
	var texture_size := Vector2i(
		maxi(4, int(config.get("texture_width", DEFAULT_SOLVE_TEXTURE_SIZE.x))),
		maxi(4, int(config.get("texture_height", DEFAULT_SOLVE_TEXTURE_SIZE.y)))
	)
	var local_size := maxi(1, int(config.get("solve_local_size", DEFAULT_SOLVE_LOCAL_SIZE)))
	var wait_frames := maxi(0, int(config.get("sync_wait_frames", DEFAULT_SYNC_WAIT_FRAMES)))
	var stride := maxi(1, int(config.get("stride", DEFAULT_SOLVE_STRIDE)))
	var source_size := maxf(1.0, float(config.get("source_size", DEFAULT_SOLVE_SOURCE_SIZE)))
	var atlas_columns := maxi(1, int(config.get("atlas_columns", DEFAULT_SOLVE_ATLAS_COLUMNS)))
	var fixture_seed := int(config.get("fixture_seed", 37))
	var result := _make_solve_filter_report(texture_size, local_size, wait_frames, stride, source_size, atlas_columns, fixture_seed)
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		result["ok"] = false
		result["skipped"] = true
		result["reason"] = "local_rendering_device_unavailable"
		result["message"] = "Local RenderingDevice is unavailable; run windowed under a RenderingDevice renderer."
		_emit_warning("Waterways: R7 compute solve/filter step skipped because local RenderingDevice is unavailable.")
		return result

	_fill_device_report(result)
	var usage_bits := int(result.get("solve_storage_texture_usage_bits", _solve_texture_usage_bits()))
	if not bool(result.get("solve_rgba32f_supported", false)):
		result["ok"] = false
		result["reason"] = "rgba32f_storage_texture_unavailable"
		return result

	var fixture := _make_pressure_jacobi_fixture(texture_size, source_size, stride, atlas_columns, fixture_seed)
	result["fixture_active_pixels"] = int(fixture.get("active_pixels", 0))
	result["fixture_solid_pixels"] = int(fixture.get("solid_pixels", 0))
	result["fixture_wall_neighbor_cases"] = int(fixture.get("wall_neighbor_cases", 0))
	result["fixture_cross_column_wall_neighbor_cases"] = int(fixture.get("cross_column_wall_neighbor_cases", 0))
	result["fixture_padding_wall_neighbor_cases"] = int(fixture.get("padding_wall_neighbor_cases", 0))
	result["fixture_solid_neighbor_cases"] = int(fixture.get("solid_neighbor_cases", 0))
	result["cpu_reference_checksum"] = int(fixture.get("reference_checksum", 0))
	if int(fixture.get("active_pixels", 0)) <= 0 or int(fixture.get("solid_pixels", 0)) <= 0:
		result["ok"] = false
		result["reason"] = "fixture_did_not_exercise_active_and_solid_cells"
		return result
	if int(fixture.get("wall_neighbor_cases", 0)) <= 0 or int(fixture.get("solid_neighbor_cases", 0)) <= 0:
		result["ok"] = false
		result["reason"] = "fixture_did_not_exercise_boundaries"
		return result

	var shader := _compile_compute_shader(_pressure_jacobi_shader_source(texture_size, local_size, stride, source_size, atlas_columns), "waterways_r7_pressure_jacobi_step")
	if not shader.is_valid():
		result["ok"] = false
		result["reason"] = "compute_shader_compile_failed"
		return result
	_owned_rids.append(shader)
	var pipeline := _rd.compute_pipeline_create(shader)
	if not pipeline.is_valid():
		result["ok"] = false
		result["reason"] = "compute_pipeline_create_failed"
		return result
	_owned_rids.append(pipeline)

	var pressure_bytes: PackedByteArray = fixture.get("pressure_bytes", PackedByteArray())
	var divergence_bytes: PackedByteArray = fixture.get("divergence_bytes", PackedByteArray())
	var occupancy_bytes: PackedByteArray = fixture.get("occupancy_bytes", PackedByteArray())
	var output_seed_bytes: PackedByteArray = fixture.get("output_seed_bytes", PackedByteArray())
	var pressure_texture := _create_rgba32f_texture(texture_size, usage_bits, pressure_bytes)
	var divergence_texture := _create_rgba32f_texture(texture_size, usage_bits, divergence_bytes)
	var occupancy_texture := _create_rgba32f_texture(texture_size, usage_bits, occupancy_bytes)
	var output_texture := _create_rgba32f_texture(texture_size, usage_bits, output_seed_bytes)
	if not pressure_texture.is_valid() or not divergence_texture.is_valid() or not occupancy_texture.is_valid() or not output_texture.is_valid():
		result["ok"] = false
		result["reason"] = "storage_texture_create_failed"
		return result
	_owned_rids.append(pressure_texture)
	_owned_rids.append(divergence_texture)
	_owned_rids.append(occupancy_texture)
	_owned_rids.append(output_texture)
	var uniform_set := _make_jacobi_uniform_set(shader, pressure_texture, divergence_texture, occupancy_texture, output_texture)
	if not uniform_set.is_valid():
		result["ok"] = false
		result["reason"] = "uniform_set_create_failed"
		return result
	_owned_rids.append(uniform_set)

	_record_jacobi_dispatch(pipeline, uniform_set, texture_size, local_size)
	_rd.submit()
	_submitted_without_sync = true
	await _wait_process_frames(config.get("frame_wait_source", null), wait_frames, cancellation)
	if _rd == null:
		result["ok"] = false
		result["reason"] = "cancelled"
		return result
	_rd.sync()
	_submitted_without_sync = false
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	var readback_bytes := _rd.texture_get_data(output_texture, 0)
	if readback_bytes.is_empty():
		result["ok"] = false
		result["reason"] = "texture_get_data_empty"
		return result
	var actual_encoded := _read_rgba32f_red_channel(readback_bytes, texture_size.x * texture_size.y)
	var expected_encoded: Array = fixture.get("expected_encoded_pressure", [])
	var metrics := _pressure_compare_metrics(expected_encoded, actual_encoded)
	_append_metrics_to_result(result, metrics)
	var passed := (
		float(metrics.get("encoded_max_abs", 1.0)) <= 0.00001
		and float(metrics.get("encoded_p99_abs", 1.0)) <= 0.00001
		and float(metrics.get("encoded_mean_abs", 1.0)) <= 0.000001
		and float(metrics.get("pressure_max_abs", 1.0)) <= 0.001
		and float(metrics.get("pressure_p99_abs", 1.0)) <= 0.0005
	)
	result["ok"] = passed
	result["reason"] = "ok" if passed else "pressure_jacobi_cpu_reference_mismatch"
	result["readback_byte_count"] = readback_bytes.size()
	result["gpu_result_checksum"] = _checksum_encoded_pressure(actual_encoded)
	return result


func _run_non_replacing_solve_filter_stack_internal(config: Dictionary, cancellation: Callable) -> Dictionary:
	var texture_size := Vector2i(
		maxi(4, int(config.get("texture_width", DEFAULT_STACK_TEXTURE_SIZE.x))),
		maxi(4, int(config.get("texture_height", DEFAULT_STACK_TEXTURE_SIZE.y)))
	)
	var local_size := maxi(1, int(config.get("solve_local_size", DEFAULT_SOLVE_LOCAL_SIZE)))
	var wait_frames := maxi(0, int(config.get("sync_wait_frames", DEFAULT_SYNC_WAIT_FRAMES)))
	var source_size := maxf(1.0, float(config.get("source_size", DEFAULT_STACK_SOURCE_SIZE)))
	var atlas_columns := maxi(1, int(config.get("atlas_columns", DEFAULT_STACK_ATLAS_COLUMNS)))
	var fixture_seed := int(config.get("fixture_seed", 97))
	var strides := _config_int_array(config, "flow_projection_strides", DEFAULT_STACK_STRIDES)
	var iterations_per_stride := maxi(1, int(config.get("flow_projection_iterations_per_stride", DEFAULT_STACK_ITERATIONS_PER_STRIDE)))
	var result := _make_solve_filter_stack_report(texture_size, local_size, wait_frames, source_size, atlas_columns, fixture_seed, strides, iterations_per_stride)
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		result["ok"] = false
		result["skipped"] = true
		result["reason"] = "local_rendering_device_unavailable"
		result["message"] = "Local RenderingDevice is unavailable; run windowed under a RenderingDevice renderer."
		_emit_warning("Waterways: R7 compute solve/filter stack skipped because local RenderingDevice is unavailable.")
		return result

	_fill_device_report(result)
	var usage_bits := int(result.get("solve_storage_texture_usage_bits", _solve_texture_usage_bits()))
	if not bool(result.get("solve_rgba32f_supported", false)):
		result["ok"] = false
		result["reason"] = "rgba32f_storage_texture_unavailable"
		return result

	var fixture := _make_pressure_jacobi_stack_fixture(texture_size, source_size, strides, iterations_per_stride, atlas_columns, fixture_seed)
	result["fixture_active_pixels"] = int(fixture.get("active_pixels", 0))
	result["fixture_solid_pixels"] = int(fixture.get("solid_pixels", 0))
	result["fixture_wall_neighbor_cases"] = int(fixture.get("wall_neighbor_cases", 0))
	result["fixture_cross_column_wall_neighbor_cases"] = int(fixture.get("cross_column_wall_neighbor_cases", 0))
	result["fixture_padding_wall_neighbor_cases"] = int(fixture.get("padding_wall_neighbor_cases", 0))
	result["fixture_solid_neighbor_cases"] = int(fixture.get("solid_neighbor_cases", 0))
	result["cpu_reference_checksum"] = int(fixture.get("reference_checksum", 0))
	if int(fixture.get("active_pixels", 0)) <= 0 or int(fixture.get("solid_pixels", 0)) <= 0:
		result["ok"] = false
		result["reason"] = "fixture_did_not_exercise_active_and_solid_cells"
		return result
	if int(fixture.get("wall_neighbor_cases", 0)) <= 0 or int(fixture.get("solid_neighbor_cases", 0)) <= 0:
		result["ok"] = false
		result["reason"] = "fixture_did_not_exercise_boundaries"
		return result

	var pressure_a := _create_rgba32f_texture(texture_size, usage_bits, fixture.get("initial_pressure_bytes", PackedByteArray()))
	var pressure_b := _create_rgba32f_texture(texture_size, usage_bits, fixture.get("initial_pressure_bytes", PackedByteArray()))
	var divergence_texture := _create_rgba32f_texture(texture_size, usage_bits, fixture.get("divergence_bytes", PackedByteArray()))
	var occupancy_texture := _create_rgba32f_texture(texture_size, usage_bits, fixture.get("occupancy_bytes", PackedByteArray()))
	if not pressure_a.is_valid() or not pressure_b.is_valid() or not divergence_texture.is_valid() or not occupancy_texture.is_valid():
		result["ok"] = false
		result["reason"] = "storage_texture_create_failed"
		return result
	_owned_rids.append(pressure_a)
	_owned_rids.append(pressure_b)
	_owned_rids.append(divergence_texture)
	_owned_rids.append(occupancy_texture)

	var pipelines := {}
	var pass_infos := []
	var pass_index := 0
	for stride_variant in strides:
		var stride := maxi(1, int(stride_variant))
		var stride_key := str(stride)
		if not pipelines.has(stride_key):
			var shader := _compile_compute_shader(_pressure_jacobi_shader_source(texture_size, local_size, stride, source_size, atlas_columns), "waterways_r7_pressure_jacobi_stack_stride_" + stride_key)
			if not shader.is_valid():
				result["ok"] = false
				result["reason"] = "compute_shader_compile_failed"
				return result
			_owned_rids.append(shader)
			var pipeline := _rd.compute_pipeline_create(shader)
			if not pipeline.is_valid():
				result["ok"] = false
				result["reason"] = "compute_pipeline_create_failed"
				return result
			_owned_rids.append(pipeline)
			pipelines[stride_key] = {
				"shader": shader,
				"pipeline": pipeline
			}
		for _iteration in iterations_per_stride:
			if _is_cancellation_requested(cancellation):
				result["ok"] = false
				result["reason"] = "cancelled"
				return result
			var pipeline_info: Dictionary = pipelines[stride_key]
			var source_texture := pressure_a if pass_index % 2 == 0 else pressure_b
			var destination_texture := pressure_b if pass_index % 2 == 0 else pressure_a
			var shader_rid: RID = pipeline_info.get("shader", RID())
			var pipeline_rid: RID = pipeline_info.get("pipeline", RID())
			var uniform_set := _make_jacobi_uniform_set(shader_rid, source_texture, divergence_texture, occupancy_texture, destination_texture)
			if not uniform_set.is_valid():
				result["ok"] = false
				result["reason"] = "uniform_set_create_failed"
				return result
			_owned_rids.append(uniform_set)
			pass_infos.append({
				"pipeline": pipeline_rid,
				"uniform_set": uniform_set
			})
			pass_index += 1
	result["compiled_shader_count"] = pipelines.size()
	result["unique_stride_count"] = pipelines.size()
	result["compute_lists_recorded"] = 1
	result["compute_barrier_count"] = maxi(0, pass_index - 1)
	if pass_index != int(result.get("jacobi_pass_count", 0)):
		result["ok"] = false
		result["reason"] = "jacobi_pass_count_mismatch"
		return result

	var compute_list := _rd.compute_list_begin()
	for info_index in pass_infos.size():
		var pass_info: Dictionary = pass_infos[info_index]
		_rd.compute_list_bind_compute_pipeline(compute_list, pass_info.get("pipeline", RID()))
		_rd.compute_list_bind_uniform_set(compute_list, pass_info.get("uniform_set", RID()), 0)
		_rd.compute_list_dispatch(
			compute_list,
			int(ceil(float(texture_size.x) / float(local_size))),
			int(ceil(float(texture_size.y) / float(local_size))),
			1
		)
		if info_index < pass_infos.size() - 1:
			_rd.compute_list_add_barrier(compute_list)
	_rd.compute_list_end()

	_rd.submit()
	_submitted_without_sync = true
	await _wait_process_frames(config.get("frame_wait_source", null), wait_frames, cancellation)
	if _rd == null:
		result["ok"] = false
		result["reason"] = "cancelled"
		return result
	_rd.sync()
	_submitted_without_sync = false
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	var final_texture := pressure_a if pass_index % 2 == 0 else pressure_b
	var readback_bytes := _rd.texture_get_data(final_texture, 0)
	if readback_bytes.is_empty():
		result["ok"] = false
		result["reason"] = "texture_get_data_empty"
		return result
	var actual_encoded := _read_rgba32f_red_channel(readback_bytes, texture_size.x * texture_size.y)
	var expected_encoded: Array = fixture.get("expected_encoded_pressure", [])
	var metrics := _pressure_compare_metrics(expected_encoded, actual_encoded)
	_append_metrics_to_result(result, metrics)
	var passed := (
		float(metrics.get("encoded_max_abs", 1.0)) <= 0.04
		and float(metrics.get("encoded_p99_abs", 1.0)) <= 0.03
		and float(metrics.get("encoded_mean_abs", 1.0)) <= 0.008
		and float(metrics.get("pressure_max_abs", 1.0)) <= 1.3
		and float(metrics.get("pressure_p99_abs", 1.0)) <= 1.0
	)
	result["cpu_reference_ok"] = passed
	result["ok"] = true
	result["reason"] = "ok" if passed else "ok_cpu_reference_diagnostic_mismatch"
	result["readback_byte_count"] = readback_bytes.size()
	result["gpu_result_checksum"] = _checksum_encoded_pressure(actual_encoded)
	result["_debug_actual_encoded_pressure"] = actual_encoded
	return result


func _run_non_replacing_solve_filter_projection_internal(config: Dictionary, cancellation: Callable) -> Dictionary:
	var flow_image := config.get("flow_image", null) as Image
	var occupancy_image := config.get("occupancy_image", null) as Image
	var pressure_override_image := config.get("pressure_override_image", null) as Image
	if flow_image == null or flow_image.is_empty() or occupancy_image == null or occupancy_image.is_empty():
		return {
			"ok": false,
			"mode": "non_replacing_solve_filter_projection",
			"production_output_replaced": false,
			"output_texture_keys": [],
			"reason": "input_images_missing_or_empty"
		}
	var texture_size := flow_image.get_size()
	if occupancy_image.get_size() != texture_size:
		return {
			"ok": false,
			"mode": "non_replacing_solve_filter_projection",
			"production_output_replaced": false,
			"output_texture_keys": [],
			"reason": "input_image_size_mismatch",
			"flow_size": texture_size,
			"occupancy_size": occupancy_image.get_size()
		}
	if pressure_override_image != null and (pressure_override_image.is_empty() or pressure_override_image.get_size() != texture_size):
		return {
			"ok": false,
			"mode": "non_replacing_solve_filter_projection",
			"production_output_replaced": false,
			"output_texture_keys": [],
			"reason": "pressure_override_image_size_mismatch",
			"flow_size": texture_size,
			"pressure_override_size": pressure_override_image.get_size() if pressure_override_image != null else Vector2i.ZERO
		}
	var local_size := maxi(1, int(config.get("solve_local_size", DEFAULT_SOLVE_LOCAL_SIZE)))
	var wait_frames := maxi(0, int(config.get("sync_wait_frames", DEFAULT_SYNC_WAIT_FRAMES)))
	var source_size := maxf(1.0, float(config.get("source_size", DEFAULT_STACK_SOURCE_SIZE)))
	var atlas_columns := maxi(1, int(config.get("atlas_columns", DEFAULT_STACK_ATLAS_COLUMNS)))
	var strides := _config_int_array(config, "flow_projection_strides", DEFAULT_STACK_STRIDES)
	var iterations_per_stride := maxi(1, int(config.get("flow_projection_iterations_per_stride", DEFAULT_STACK_ITERATIONS_PER_STRIDE)))
	var tangency_passes := maxi(0, int(config.get("flow_tangency_passes", DEFAULT_PROJECTION_TANGENCY_PASSES)))
	var result := _make_solve_filter_projection_report(texture_size, local_size, wait_frames, source_size, atlas_columns, strides, iterations_per_stride, tangency_passes)
	var full_jacobi_pass_count := int(result.get("jacobi_pass_count", strides.size() * iterations_per_stride))
	var pressure_jacobi_pass_limit := clampi(int(config.get("pressure_jacobi_pass_limit", full_jacobi_pass_count)), 1, full_jacobi_pass_count)
	var pressure_jacobi_pass_limited := pressure_jacobi_pass_limit != full_jacobi_pass_count
	if pressure_jacobi_pass_limited:
		var limited_dispatch_count := 1 + pressure_jacobi_pass_limit + 1 + tangency_passes
		result["pressure_jacobi_pass_limited"] = true
		result["pressure_jacobi_pass_limit"] = pressure_jacobi_pass_limit
		result["full_jacobi_pass_count"] = full_jacobi_pass_count
		result["jacobi_pass_count"] = pressure_jacobi_pass_limit
		result["dispatch_count"] = limited_dispatch_count
		result["compute_barrier_count"] = maxi(0, limited_dispatch_count - 1)
	else:
		result["pressure_jacobi_pass_limited"] = false
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		result["ok"] = false
		result["skipped"] = true
		result["reason"] = "local_rendering_device_unavailable"
		result["message"] = "Local RenderingDevice is unavailable; run windowed under a RenderingDevice renderer."
		_emit_warning("Waterways: R7 compute solve/filter projection skipped because local RenderingDevice is unavailable.")
		return result

	_fill_device_report(result)
	var usage_bits := int(result.get("solve_storage_texture_usage_bits", _solve_texture_usage_bits()))
	var sampled_usage_bits := int(result.get("sampled_texture_usage_bits", _sampled_texture_usage_bits()))
	var format_support: Dictionary = result.get("storage_texture_format_support", {})
	if not bool(format_support.get("R16G16B16A16_SFLOAT", false)):
		result["ok"] = false
		result["reason"] = "rgba16f_storage_texture_unavailable"
		return result
	var sampled_format_support: Dictionary = result.get("sampled_texture_format_support", {})
	if flow_image.get_format() == Image.FORMAT_RGBA8 and not bool(sampled_format_support.get("R8G8B8A8_UNORM", false)):
		result["ok"] = false
		result["reason"] = "rgba8_sampled_flow_texture_unavailable"
		return result
	if occupancy_image.get_format() == Image.FORMAT_RGBA8 and not bool(sampled_format_support.get("R8G8B8A8_UNORM", false)):
		result["ok"] = false
		result["reason"] = "rgba8_sampled_occupancy_texture_unavailable"
		return result
	result["projection_rgba16f_supported"] = true
	result["pressure_feedback_rgba32f"] = true
	result["pressure_feedback_target"] = "canonical_texel_space_compute"
	result["canonical_integer_texel_addressing"] = true
	result["canonical_canvasitem_uv_artifact_emulation"] = false
	result["canonical_legacy_tie_rule_emulation"] = false
	result["flow_input_image_format"] = flow_image.get_format()
	result["occupancy_input_image_format"] = occupancy_image.get_format()
	result["rgba8_sampled_inputs_preserved"] = flow_image.get_format() == Image.FORMAT_RGBA8 and occupancy_image.get_format() == Image.FORMAT_RGBA8

	var shader_sources := {
		"divergence": _projection_shader_source(FLOW_DIVERGENCE_SHADER_TEMPLATE, texture_size, local_size, source_size, atlas_columns, 0.10, 0.55, "rgba16f"),
		"gradient": _projection_shader_source(FLOW_GRADIENT_SUBTRACT_SHADER_TEMPLATE, texture_size, local_size, source_size, atlas_columns, 0.10, 0.55, "rgba16f"),
		"tangency": _projection_shader_source(FLOW_BOUNDARY_TANGENCY_SHADER_TEMPLATE, texture_size, local_size, source_size, atlas_columns, float(config.get("tangency_ring_start", 0.10)), float(config.get("tangency_ring_full", 0.55)), "rgba16f"),
	}
	var shader_rids := {}
	var pipeline_rids := {}
	for shader_name in shader_sources.keys():
		var shader := _compile_compute_shader(String(shader_sources[shader_name]), "waterways_r7_projection_" + String(shader_name))
		if not shader.is_valid():
			result["ok"] = false
			result["reason"] = "compute_shader_compile_failed_" + String(shader_name)
			return result
		_owned_rids.append(shader)
		var pipeline := _rd.compute_pipeline_create(shader)
		if not pipeline.is_valid():
			result["ok"] = false
			result["reason"] = "compute_pipeline_create_failed_" + String(shader_name)
			return result
		_owned_rids.append(pipeline)
		shader_rids[shader_name] = shader
		pipeline_rids[shader_name] = pipeline

	var pressure_jacobi_canvas_tie_mode := int(config.get("pressure_jacobi_canvas_tie_mode", 0))
	result["pressure_jacobi_canvas_tie_mode"] = pressure_jacobi_canvas_tie_mode
	var jacobi_shader := _compile_compute_shader(_pressure_jacobi_projection_shader_source(texture_size, local_size, source_size, atlas_columns, "rgba32f", pressure_jacobi_canvas_tie_mode), "waterways_r7_projection_jacobi_dynamic_stride")
	if not jacobi_shader.is_valid():
		result["ok"] = false
		result["reason"] = "compute_shader_compile_failed_jacobi"
		return result
	_owned_rids.append(jacobi_shader)
	var jacobi_pipeline := _rd.compute_pipeline_create(jacobi_shader)
	if not jacobi_pipeline.is_valid():
		result["ok"] = false
		result["reason"] = "compute_pipeline_create_failed_jacobi"
		return result
	_owned_rids.append(jacobi_pipeline)

	var unique_strides := {}
	for stride_variant in strides:
		var stride := maxi(1, int(stride_variant))
		unique_strides[str(stride)] = true
	result["compiled_shader_count"] = shader_rids.size() + 1
	result["unique_stride_count"] = unique_strides.size()
	result["pressure_jacobi_stride_source"] = "storage_buffer_per_pass"

	var flow_texture := _create_sampled_texture_from_image(flow_image, sampled_usage_bits)
	var occupancy_texture := _create_sampled_texture_from_image(occupancy_image, sampled_usage_bits)
	var divergence_texture := _create_rgba16f_texture(texture_size, usage_bits, _rgba16f_bytes_from_fill(texture_size, Color(0.5, 0.0, 0.0, 1.0)))
	var pressure_seed_color := Color(_encode_pressure(0.0), 0.0, 0.0, 1.0)
	var pressure_a := _create_rgba32f_texture(texture_size, usage_bits, _rgba32f_bytes_from_fill(texture_size.x * texture_size.y, pressure_seed_color))
	var pressure_b := _create_rgba32f_texture(texture_size, usage_bits, _rgba32f_bytes_from_fill(texture_size.x * texture_size.y, pressure_seed_color))
	var projected_flow_texture := _create_rgba16f_texture(texture_size, usage_bits, _rgba16f_bytes_from_fill(texture_size, Color(0.5, 0.5, 0.0, 1.0)))
	var tangent_a := _create_rgba16f_texture(texture_size, usage_bits, _rgba16f_bytes_from_fill(texture_size, Color(0.5, 0.5, 0.0, 1.0)))
	var tangent_b := _create_rgba16f_texture(texture_size, usage_bits, _rgba16f_bytes_from_fill(texture_size, Color(0.5, 0.5, 0.0, 1.0)))
	var textures := [flow_texture, occupancy_texture, divergence_texture, pressure_a, pressure_b, projected_flow_texture, tangent_a, tangent_b]
	var pressure_override_texture := RID()
	if pressure_override_image != null:
		pressure_override_texture = _create_rgba32f_texture(texture_size, usage_bits, _rgba32f_bytes_from_image(pressure_override_image))
		textures.append(pressure_override_texture)
	for texture in textures:
		if not (texture as RID).is_valid():
			result["ok"] = false
			result["reason"] = "storage_texture_create_failed"
			return result
		_owned_rids.append(texture)
	var nearest_sampler := _create_texture_sampler(RenderingDevice.SAMPLER_FILTER_NEAREST)
	var linear_sampler := _create_texture_sampler(RenderingDevice.SAMPLER_FILTER_LINEAR)
	if not nearest_sampler.is_valid() or not linear_sampler.is_valid():
		result["ok"] = false
		result["reason"] = "sampler_create_failed"
		return result
	_owned_rids.append(nearest_sampler)
	_owned_rids.append(linear_sampler)
	result["projection_sampler_reads"] = true
	result["projection_nearest_sampler"] = true
	result["projection_linear_tangency_occupancy_sampler"] = true
	result["pressure_override_used"] = pressure_override_texture.is_valid()
	result["pressure_stack_candidate_computed"] = true

	var dispatches := []
	var divergence_set := _make_uniform_set(shader_rids.divergence, [
		_sampler_texture_uniform(nearest_sampler, flow_texture, 0),
		_sampler_texture_uniform(nearest_sampler, occupancy_texture, 1),
		_image_uniform(divergence_texture, 2),
	])
	if not divergence_set.is_valid():
		result["ok"] = false
		result["reason"] = "uniform_set_create_failed_divergence"
		return result
	_owned_rids.append(divergence_set)
	dispatches.append({
		"stage": "flow_divergence",
		"pipeline": pipeline_rids.divergence,
		"uniform_set": divergence_set
	})

	var pass_index := 0
	for stride_variant in strides:
		var stride := maxi(1, int(stride_variant))
		for _iteration in iterations_per_stride:
			if pass_index >= pressure_jacobi_pass_limit:
				break
			if _is_cancellation_requested(cancellation):
				result["ok"] = false
				result["reason"] = "cancelled"
				return result
			var stride_buffer := _float_storage_buffer([float(stride)])
			if not stride_buffer.is_valid():
				result["ok"] = false
				result["reason"] = "jacobi_stride_buffer_create_failed"
				return result
			_owned_rids.append(stride_buffer)
			var source_texture := pressure_a if pass_index % 2 == 0 else pressure_b
			var destination_texture := pressure_b if pass_index % 2 == 0 else pressure_a
			var uniform_set := _make_uniform_set(jacobi_shader, [
				_sampler_texture_uniform(nearest_sampler, source_texture, 0),
				_sampler_texture_uniform(nearest_sampler, divergence_texture, 1),
				_sampler_texture_uniform(nearest_sampler, occupancy_texture, 2),
				_image_uniform(destination_texture, 3),
				_storage_buffer_uniform(stride_buffer, 4),
			])
			if not uniform_set.is_valid():
				result["ok"] = false
				result["reason"] = "uniform_set_create_failed_jacobi"
				return result
			_owned_rids.append(uniform_set)
			dispatches.append({
				"stage": "flow_pressure_jacobi",
				"pipeline": jacobi_pipeline,
				"uniform_set": uniform_set
			})
			pass_index += 1
		if pass_index >= pressure_jacobi_pass_limit:
			break
	var computed_pressure_texture := pressure_a if pass_index % 2 == 0 else pressure_b
	result["pressure_ping_pong_texture_count"] = 2
	var final_pressure_texture := pressure_override_texture if pressure_override_texture.is_valid() else computed_pressure_texture
	var gradient_set := _make_uniform_set(shader_rids.gradient, [
		_sampler_texture_uniform(nearest_sampler, flow_texture, 0),
		_sampler_texture_uniform(nearest_sampler, final_pressure_texture, 1),
		_sampler_texture_uniform(nearest_sampler, occupancy_texture, 2),
		_image_uniform(projected_flow_texture, 3),
	])
	if not gradient_set.is_valid():
		result["ok"] = false
		result["reason"] = "uniform_set_create_failed_gradient"
		return result
	_owned_rids.append(gradient_set)
	dispatches.append({
		"stage": "flow_gradient_subtract",
		"pipeline": pipeline_rids.gradient,
		"uniform_set": gradient_set
	})

	var final_flow_texture := projected_flow_texture
	for tangency_index in tangency_passes:
		var source_texture := projected_flow_texture
		if tangency_index > 0:
			source_texture = tangent_a if (tangency_index - 1) % 2 == 0 else tangent_b
		var destination_texture := tangent_a if tangency_index % 2 == 0 else tangent_b
		var tangency_set := _make_uniform_set(shader_rids.tangency, [
			_sampler_texture_uniform(nearest_sampler, source_texture, 0),
			_sampler_texture_uniform(linear_sampler, occupancy_texture, 1),
			_image_uniform(destination_texture, 2),
		])
		if not tangency_set.is_valid():
			result["ok"] = false
			result["reason"] = "uniform_set_create_failed_tangency"
			return result
		_owned_rids.append(tangency_set)
		dispatches.append({
			"stage": "flow_boundary_tangency",
			"pipeline": pipeline_rids.tangency,
			"uniform_set": tangency_set
		})
		final_flow_texture = destination_texture
	result["dispatch_count"] = dispatches.size()
	result["compute_lists_recorded"] = 1
	result["same_list_read_after_write_dependencies"] = true
	result["intra_list_barriers_required"] = true
	result["compute_barrier_count"] = maxi(0, dispatches.size() - 1)
	if pass_index != int(result.get("jacobi_pass_count", 0)):
		result["ok"] = false
		result["reason"] = "jacobi_pass_count_mismatch"
		return result

	var compute_list := _rd.compute_list_begin()
	for dispatch_index in dispatches.size():
		var dispatch: Dictionary = dispatches[dispatch_index]
		_rd.compute_list_bind_compute_pipeline(compute_list, dispatch.get("pipeline", RID()))
		_rd.compute_list_bind_uniform_set(compute_list, dispatch.get("uniform_set", RID()), 0)
		_rd.compute_list_dispatch(
			compute_list,
			int(ceil(float(texture_size.x) / float(local_size))),
			int(ceil(float(texture_size.y) / float(local_size))),
			1
		)
		if dispatch_index < dispatches.size() - 1:
			_rd.compute_list_add_barrier(compute_list)
	_rd.compute_list_end()

	_rd.submit()
	_submitted_without_sync = true
	await _wait_process_frames(config.get("frame_wait_source", null), wait_frames, cancellation)
	if _rd == null:
		result["ok"] = false
		result["reason"] = "cancelled"
		return result
	_rd.sync()
	_submitted_without_sync = false
	if _is_cancellation_requested(cancellation):
		result["ok"] = false
		result["reason"] = "cancelled"
		return result

	var final_flow_bytes := _rd.texture_get_data(final_flow_texture, 0)
	var projected_flow_bytes := _rd.texture_get_data(projected_flow_texture, 0)
	var pressure_bytes := _rd.texture_get_data(final_pressure_texture, 0)
	var divergence_bytes := _rd.texture_get_data(divergence_texture, 0)
	if final_flow_bytes.is_empty() or projected_flow_bytes.is_empty() or pressure_bytes.is_empty() or divergence_bytes.is_empty():
		result["ok"] = false
		result["reason"] = "texture_get_data_empty"
		result["flow_readback_byte_count"] = final_flow_bytes.size()
		result["projected_flow_readback_byte_count"] = projected_flow_bytes.size()
		result["pressure_readback_byte_count"] = pressure_bytes.size()
		result["divergence_readback_byte_count"] = divergence_bytes.size()
		return result

	var final_flow_image := _image_from_rgba16f_bytes(texture_size, final_flow_bytes)
	var projected_flow_image := _image_from_rgba16f_bytes(texture_size, projected_flow_bytes)
	var pressure_image := _image_from_rgba32f_bytes(texture_size, pressure_bytes)
	var divergence_image := _image_from_rgba16f_bytes(texture_size, divergence_bytes)
	if final_flow_image == null or projected_flow_image == null or pressure_image == null or divergence_image == null:
		result["ok"] = false
		result["reason"] = "readback_image_create_failed"
		return result

	result["ok"] = true
	result["reason"] = "ok"
	result["flow_readback_byte_count"] = final_flow_bytes.size()
	result["projected_flow_readback_byte_count"] = projected_flow_bytes.size()
	result["pressure_readback_byte_count"] = pressure_bytes.size()
	result["divergence_readback_byte_count"] = divergence_bytes.size()
	result["readback_byte_count"] = final_flow_bytes.size() + projected_flow_bytes.size() + pressure_bytes.size() + divergence_bytes.size()
	result["gpu_result_checksum"] = _checksum_image(final_flow_image)
	result["projected_flow_result_checksum"] = _checksum_image(projected_flow_image)
	result["pressure_result_checksum"] = _checksum_image(pressure_image)
	result["divergence_result_checksum"] = _checksum_image(divergence_image)
	result["_debug_final_flow_image"] = final_flow_image
	result["_debug_projected_flow_image"] = projected_flow_image
	result["_debug_pressure_image"] = pressure_image
	result["_debug_divergence_image"] = divergence_image
	return result


func _make_solve_filter_report(texture_size: Vector2i, local_size: int, wait_frames: int, stride: int, source_size: float, atlas_columns: int, fixture_seed: int) -> Dictionary:
	return {
		"ok": false,
		"backend": "local_rendering_device",
		"mode": "non_replacing_solve_filter_step",
		"isolated_step": "flow_pressure_jacobi",
		"reference": "cpu_legacy_uv_flow_pressure_jacobi_v2",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"selected_readback_path": "delayed_single_submit_wait_" + str(wait_frames) + "_frames_sync_texture_get_data",
		"async_readback_selected": false,
		"same_list_read_after_write_dependencies": false,
		"intra_list_barriers_required": false,
		"submit_count": 1,
		"sync_count": 1,
		"compute_lists_recorded": 1,
		"texture_width": texture_size.x,
		"texture_height": texture_size.y,
		"local_size": local_size,
		"stride": stride,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"fixture_seed": fixture_seed,
		"sync_wait_frames": wait_frames,
		"texture_format": "R32G32B32A32_SFLOAT",
		"image_format": "FORMAT_RGBAF",
		"tolerance_gate": "R7_TOLERANCE_V1_cpu_legacy_uv_pressure_jacobi",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter_name": RenderingServer.get_video_adapter_name(),
		"adapter_type": str(RenderingServer.get_video_adapter_type()),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor()
	}


func _make_solve_filter_stack_report(texture_size: Vector2i, local_size: int, wait_frames: int, source_size: float, atlas_columns: int, fixture_seed: int, strides: Array, iterations_per_stride: int) -> Dictionary:
	var safe_iterations_per_stride := maxi(1, iterations_per_stride)
	var jacobi_pass_count := strides.size() * safe_iterations_per_stride
	return {
		"ok": false,
		"backend": "local_rendering_device",
		"mode": "non_replacing_solve_filter_stack",
		"stack_stage": "flow_pressure_jacobi_stack",
		"reference": "cpu_legacy_uv_pressure_jacobi_stack_v1",
		"production_shape": "low_cost_fixture_64_source_106_padded_texture",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"selected_readback_path": "delayed_single_submit_wait_" + str(wait_frames) + "_frames_sync_texture_get_data",
		"async_readback_selected": false,
		"same_list_read_after_write_dependencies": true,
		"intra_list_barriers_required": true,
		"compute_barrier_count": maxi(0, jacobi_pass_count - 1),
		"submit_count": 1,
		"sync_count": 1,
		"compute_lists_recorded": 1,
		"dispatch_count": jacobi_pass_count,
		"jacobi_pass_count": jacobi_pass_count,
		"pressure_ping_pong_texture_count": 2,
		"texture_width": texture_size.x,
		"texture_height": texture_size.y,
		"local_size": local_size,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"fixture_seed": fixture_seed,
		"flow_projection_strides": strides.duplicate(),
		"flow_projection_iterations_per_stride": safe_iterations_per_stride,
		"sync_wait_frames": wait_frames,
		"texture_format": "R32G32B32A32_SFLOAT",
		"image_format": "FORMAT_RGBAF",
		"tolerance_gate": "R7_PRESSURE_JACOBI_STACK_INTERMEDIATE_V1",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter_name": RenderingServer.get_video_adapter_name(),
		"adapter_type": str(RenderingServer.get_video_adapter_type()),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor()
	}


func _make_solve_filter_projection_report(texture_size: Vector2i, local_size: int, wait_frames: int, source_size: float, atlas_columns: int, strides: Array, iterations_per_stride: int, tangency_passes: int) -> Dictionary:
	var safe_iterations_per_stride := maxi(1, iterations_per_stride)
	var safe_tangency_passes := maxi(0, tangency_passes)
	var jacobi_pass_count := strides.size() * safe_iterations_per_stride
	var dispatch_count := 1 + jacobi_pass_count + 1 + safe_tangency_passes
	return {
		"ok": false,
		"backend": "local_rendering_device",
		"mode": "non_replacing_solve_filter_projection",
		"stack_stage": "flow_divergence_pressure_gradient_tangency",
		"reference": "legacy_filter_renderer_projection_stack",
		"production_shape": "low_cost_fixture_64_source_106_padded_texture",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"selected_readback_path": "delayed_single_submit_wait_" + str(wait_frames) + "_frames_sync_texture_get_data",
		"async_readback_selected": false,
		"same_list_read_after_write_dependencies": true,
		"intra_list_barriers_required": true,
		"compute_barrier_count": maxi(0, dispatch_count - 1),
		"submit_count": 1,
		"sync_count": 1,
		"compute_lists_recorded": 1,
		"dispatch_count": dispatch_count,
		"divergence_dispatch_count": 1,
		"gradient_subtract_dispatch_count": 1,
		"tangency_pass_count": safe_tangency_passes,
		"jacobi_pass_count": jacobi_pass_count,
		"pressure_ping_pong_texture_count": 2,
		"texture_width": texture_size.x,
		"texture_height": texture_size.y,
		"local_size": local_size,
		"source_size": source_size,
		"atlas_columns": atlas_columns,
		"flow_projection_strides": strides.duplicate(),
		"flow_projection_iterations_per_stride": safe_iterations_per_stride,
		"sync_wait_frames": wait_frames,
		"texture_format": "R16G16B16A16_SFLOAT",
		"image_format": "FORMAT_RGBAH",
		"pressure_texture_format": "R32G32B32A32_SFLOAT",
		"pressure_image_format": "FORMAT_RGBAF",
		"legacy_f16_feedback_quantized": false,
		"pressure_feedback_target": "canonical_texel_space_compute",
		"acceptance_target": "R7_COMPUTE_CANONICAL_ACCEPTANCE_V1",
		"tolerance_gate": "R7_TOLERANCE_V1",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter_name": RenderingServer.get_video_adapter_name(),
		"adapter_type": str(RenderingServer.get_video_adapter_type()),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor()
	}


func _make_base_report(element_count: int, iterations: int, local_size: int, wait_frames: int) -> Dictionary:
	return {
		"ok": false,
		"backend": "local_rendering_device",
		"mode": "non_replacing_smoke",
		"production_output_replaced": false,
		"output_texture_keys": [],
		"selected_readback_path": "delayed_single_submit_wait_" + str(wait_frames) + "_frames_sync_buffer_get_data",
		"async_readback_selected": false,
		"same_list_read_after_write_dependencies": false,
		"intra_list_barriers_required": false,
		"submit_count": 1,
		"sync_count": 1,
		"compute_lists_recorded": iterations,
		"element_count": element_count,
		"iterations": iterations,
		"local_size": local_size,
		"sync_wait_frames": wait_frames,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter_name": RenderingServer.get_video_adapter_name(),
		"adapter_type": str(RenderingServer.get_video_adapter_type()),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor()
	}


func _fill_device_report(result: Dictionary) -> void:
	result["local_rd_device_name"] = _rd.get_device_name()
	result["local_rd_device_vendor"] = _rd.get_device_vendor_name()
	result["local_rd_device_total_memory"] = _rd.get_device_total_memory()
	result["limit_push_constant_size"] = _rd.limit_get(RenderingDevice.LIMIT_MAX_PUSH_CONSTANT_SIZE)
	result["limit_compute_shared_memory"] = _rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_SHARED_MEMORY_SIZE)
	result["limit_max_compute_workgroup_invocations"] = _rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_INVOCATIONS)
	result["limit_max_compute_workgroup_size_x"] = _rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_SIZE_X)
	var usage_bits := (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	var rgba16_supported := _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage_bits)
	var rgba32_supported := _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, usage_bits)
	result["storage_texture_format_support"] = {
		"R16G16B16A16_SFLOAT": rgba16_supported,
		"R32G32B32A32_SFLOAT": rgba32_supported,
		"usage_bits": usage_bits
	}
	result["storage_texture_format_supported"] = rgba16_supported or rgba32_supported
	var sampled_usage_bits := _sampled_texture_usage_bits()
	result["sampled_texture_usage_bits"] = sampled_usage_bits
	result["sampled_texture_format_support"] = {
		"R8G8B8A8_UNORM": _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, sampled_usage_bits),
		"R16G16B16A16_SFLOAT": _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, sampled_usage_bits),
		"R32G32B32A32_SFLOAT": _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, sampled_usage_bits),
		"usage_bits": sampled_usage_bits
	}
	var solve_usage_bits := _solve_texture_usage_bits()
	result["solve_storage_texture_usage_bits"] = solve_usage_bits
	result["solve_rgba32f_supported"] = _rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, solve_usage_bits)


func _solve_texture_usage_bits() -> int:
	return (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)


func _sampled_texture_usage_bits() -> int:
	return RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT


func _compile_compute_shader(code: String, shader_name: String) -> RID:
	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = code
	var spirv: RDShaderSPIRV = _rd.shader_compile_spirv_from_source(shader_source, false)
	var compile_error := spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not compile_error.is_empty():
		_emit_warning("Waterways: R7 compute backend shader compile failed: " + compile_error)
		return RID()
	var shader := _rd.shader_create_from_spirv(spirv, shader_name)
	if not shader.is_valid():
		_emit_warning("Waterways: R7 compute backend shader_create_from_spirv returned an invalid RID.")
	return shader


func _shader_source(element_count: int, local_size: int) -> String:
	return PING_PONG_SHADER_TEMPLATE.replace("$LOCAL_SIZE", str(local_size)).replace("$ELEMENT_COUNT", str(element_count))


func _pressure_jacobi_shader_source(texture_size: Vector2i, local_size: int, stride: int, source_size: float, atlas_columns: int) -> String:
	return PRESSURE_JACOBI_SHADER_TEMPLATE \
		.replace("$LOCAL_SIZE", str(local_size)) \
		.replace("$WIDTH", str(texture_size.x)) \
		.replace("$HEIGHT", str(texture_size.y)) \
		.replace("$STRIDE", str(stride)) \
		.replace("$SOURCE_SIZE", str(source_size)) \
		.replace("$ATLAS_COLUMNS", str(atlas_columns)) \
		.replace("$PRESSURE_DIVERGENCE_SCALE", "1.0")


func _pressure_jacobi_projection_shader_source(texture_size: Vector2i, local_size: int, source_size: float, atlas_columns: int, image_layout: String, canvas_tie_mode: int = 0) -> String:
	return PRESSURE_JACOBI_SAMPLER_SHADER_TEMPLATE \
		.replace("$LOCAL_SIZE", str(local_size)) \
		.replace("$WIDTH", str(texture_size.x)) \
		.replace("$HEIGHT", str(texture_size.y)) \
		.replace("$SOURCE_SIZE", str(source_size)) \
		.replace("$ATLAS_COLUMNS", str(atlas_columns)) \
		.replace("$CANVAS_TIE_MODE", str(canvas_tie_mode)) \
		.replace("layout(rgba32f", "layout(" + image_layout)


func _projection_shader_source(template: String, texture_size: Vector2i, local_size: int, source_size: float, atlas_columns: int, ring_start: float, ring_full: float, image_layout: String) -> String:
	return template \
		.replace("$LOCAL_SIZE", str(local_size)) \
		.replace("$WIDTH", str(texture_size.x)) \
		.replace("$HEIGHT", str(texture_size.y)) \
		.replace("$SOURCE_SIZE", str(source_size)) \
		.replace("$ATLAS_COLUMNS", str(atlas_columns)) \
		.replace("$RING_START", str(ring_start)) \
		.replace("$RING_FULL", str(ring_full)) \
		.replace("layout(rgba32f", "layout(" + image_layout)


func _make_ping_pong_uniform_set(shader: RID, source_buffer: RID, destination_buffer: RID) -> RID:
	var source_uniform := RDUniform.new()
	source_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	source_uniform.binding = 0
	source_uniform.add_id(source_buffer)
	var destination_uniform := RDUniform.new()
	destination_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	destination_uniform.binding = 1
	destination_uniform.add_id(destination_buffer)
	return _rd.uniform_set_create([source_uniform, destination_uniform], shader, 0)


func _make_jacobi_uniform_set(shader: RID, pressure_texture: RID, divergence_texture: RID, occupancy_texture: RID, output_texture: RID) -> RID:
	return _rd.uniform_set_create([
		_image_uniform(pressure_texture, 0),
		_image_uniform(divergence_texture, 1),
		_image_uniform(occupancy_texture, 2),
		_image_uniform(output_texture, 3),
	], shader, 0)


func _make_image_uniform_set(shader: RID, textures: Array) -> RID:
	var uniforms := []
	for texture_index in textures.size():
		uniforms.append(_image_uniform(textures[texture_index], texture_index))
	return _rd.uniform_set_create(uniforms, shader, 0)


func _make_uniform_set(shader: RID, uniforms: Array) -> RID:
	return _rd.uniform_set_create(uniforms, shader, 0)


func _create_texture_sampler(filter: int) -> RID:
	var sampler_state := RDSamplerState.new()
	sampler_state.mag_filter = filter
	sampler_state.min_filter = filter
	sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	return _rd.sampler_create(sampler_state)


func _sampler_texture_uniform(sampler: RID, texture: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform


func _image_uniform(texture: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform


func _storage_buffer_uniform(buffer: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform


func _float_storage_buffer(values: Array) -> RID:
	var bytes := PackedByteArray()
	bytes.resize(maxi(1, values.size()) * 4)
	for index in values.size():
		bytes.encode_float(index * 4, float(values[index]))
	return _rd.storage_buffer_create(bytes.size(), bytes)


func _record_dispatch(pipeline: RID, uniform_set: RID, element_count: int, local_size: int) -> void:
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	_rd.compute_list_dispatch(compute_list, int(ceil(float(element_count) / float(local_size))), 1, 1)
	_rd.compute_list_end()


func _record_jacobi_dispatch(pipeline: RID, uniform_set: RID, texture_size: Vector2i, local_size: int) -> void:
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	_rd.compute_list_dispatch(
		compute_list,
		int(ceil(float(texture_size.x) / float(local_size))),
		int(ceil(float(texture_size.y) / float(local_size))),
		1
	)
	_rd.compute_list_end()


func _create_sampled_texture_from_image(image: Image, usage_bits: int) -> RID:
	if image == null or image.is_empty():
		return RID()
	var texture_size := image.get_size()
	match image.get_format():
		Image.FORMAT_RGBA8:
			var rgba8 := image.duplicate()
			rgba8.convert(Image.FORMAT_RGBA8)
			return _create_rgba8_texture(texture_size, usage_bits, rgba8.get_data())
		Image.FORMAT_RGBAF:
			return _create_rgba32f_texture(texture_size, usage_bits, _rgba32f_bytes_from_image(image))
		_:
			return _create_rgba16f_texture(texture_size, usage_bits, _rgba16f_bytes_from_image(image))


func _create_rgba8_texture(texture_size: Vector2i, usage_bits: int, data: PackedByteArray) -> RID:
	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	texture_format.width = texture_size.x
	texture_format.height = texture_size.y
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	texture_format.usage_bits = usage_bits
	var initial_data := []
	if not data.is_empty():
		initial_data.append(data)
	return _rd.texture_create(texture_format, RDTextureView.new(), initial_data)


func _create_rgba32f_texture(texture_size: Vector2i, usage_bits: int, data: PackedByteArray) -> RID:
	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.width = texture_size.x
	texture_format.height = texture_size.y
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	texture_format.usage_bits = usage_bits
	var initial_data := []
	if not data.is_empty():
		initial_data.append(data)
	return _rd.texture_create(texture_format, RDTextureView.new(), initial_data)


func _create_rgba16f_texture(texture_size: Vector2i, usage_bits: int, data: PackedByteArray) -> RID:
	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	texture_format.width = texture_size.x
	texture_format.height = texture_size.y
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	texture_format.usage_bits = usage_bits
	var initial_data := []
	if not data.is_empty():
		initial_data.append(data)
	return _rd.texture_create(texture_format, RDTextureView.new(), initial_data)


func _wait_process_frames(frame_wait_source: Variant, frame_count: int, cancellation: Callable) -> void:
	for _frame_index in frame_count:
		if _is_cancellation_requested(cancellation):
			return
		var tree := _get_scene_tree(frame_wait_source)
		if tree == null:
			return
		await tree.process_frame


func _get_scene_tree(frame_wait_source: Variant) -> SceneTree:
	if frame_wait_source is SceneTree:
		return frame_wait_source as SceneTree
	if frame_wait_source is Node:
		var node := frame_wait_source as Node
		if is_instance_valid(node) and node.get_tree() != null:
			return node.get_tree()
	return null


func _make_pressure_jacobi_fixture(texture_size: Vector2i, source_size: float, stride: int, atlas_columns: int, seed: int) -> Dictionary:
	var pixel_count := texture_size.x * texture_size.y
	var pressure_values := []
	var divergence_values := []
	var solid_values := []
	pressure_values.resize(pixel_count)
	divergence_values.resize(pixel_count)
	solid_values.resize(pixel_count)
	var solid_pixels := 0
	for y in texture_size.y:
		for x in texture_size.x:
			var index := _pixel_index(x, y, texture_size)
			var solid := _fixture_solid(x, y, texture_size, seed)
			var pressure := _fixture_pressure(x, y, seed)
			var divergence := _fixture_divergence(x, y, seed)
			pressure_values[index] = pressure
			divergence_values[index] = divergence
			solid_values[index] = solid
			if solid:
				solid_pixels += 1
	var expected := []
	expected.resize(pixel_count)
	var expected_encoded := []
	expected_encoded.resize(pixel_count)
	var stats := {
		"active_pixels": 0,
		"solid_pixels": solid_pixels,
		"wall_neighbor_cases": 0,
		"cross_column_wall_neighbor_cases": 0,
		"padding_wall_neighbor_cases": 0,
		"solid_neighbor_cases": 0,
	}
	for y in texture_size.y:
		for x in texture_size.x:
			var index := _pixel_index(x, y, texture_size)
			var center_pressure := float(pressure_values[index])
			if bool(solid_values[index]):
				expected[index] = center_pressure
				expected_encoded[index] = _encode_pressure(center_pressure)
				continue
			stats.active_pixels += 1
			var left := _reference_neighbor_pressure(x, y, -stride, 0, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
			var right := _reference_neighbor_pressure(x, y, stride, 0, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
			var up := _reference_neighbor_pressure(x, y, 0, -stride, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
			var down := _reference_neighbor_pressure(x, y, 0, stride, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
			var divergence := float(divergence_values[index])
			var safe_stride := float(maxi(1, stride))
			var new_pressure := (left + right + up + down - divergence * safe_stride * safe_stride) * 0.25
			expected[index] = new_pressure
			expected_encoded[index] = _encode_pressure(new_pressure)
	var pressure_bytes := _rgba32f_bytes_from_scalar_values(pressure_values, "pressure")
	var divergence_bytes := _rgba32f_bytes_from_scalar_values(divergence_values, "divergence")
	var occupancy_bytes := _rgba32f_bytes_from_solid_values(solid_values)
	var output_seed_bytes := _rgba32f_bytes_from_fill(pixel_count, Color(0.0, 0.0, 0.0, 1.0))
	return {
		"pressure_bytes": pressure_bytes,
		"divergence_bytes": divergence_bytes,
		"occupancy_bytes": occupancy_bytes,
		"output_seed_bytes": output_seed_bytes,
		"expected_pressure": expected,
		"expected_encoded_pressure": expected_encoded,
		"active_pixels": int(stats.active_pixels),
		"solid_pixels": int(stats.solid_pixels),
		"wall_neighbor_cases": int(stats.wall_neighbor_cases),
		"cross_column_wall_neighbor_cases": int(stats.cross_column_wall_neighbor_cases),
		"padding_wall_neighbor_cases": int(stats.padding_wall_neighbor_cases),
		"solid_neighbor_cases": int(stats.solid_neighbor_cases),
		"reference_checksum": _checksum_encoded_pressure(expected_encoded),
	}


func _make_pressure_jacobi_stack_fixture(texture_size: Vector2i, source_size: float, strides: Array, iterations_per_stride: int, atlas_columns: int, seed: int) -> Dictionary:
	var pixel_count := texture_size.x * texture_size.y
	var pressure_values := []
	var encoded_values := []
	var divergence_values := []
	var solid_values := []
	pressure_values.resize(pixel_count)
	encoded_values.resize(pixel_count)
	divergence_values.resize(pixel_count)
	solid_values.resize(pixel_count)
	var solid_pixels := 0
	for y in texture_size.y:
		for x in texture_size.x:
			var index := _pixel_index(x, y, texture_size)
			var solid := _fixture_solid(x, y, texture_size, seed)
			var encoded_pressure := _encode_pressure(0.0)
			pressure_values[index] = _decode_pressure(encoded_pressure)
			encoded_values[index] = encoded_pressure
			divergence_values[index] = _fixture_stack_divergence(x, y, seed)
			solid_values[index] = solid
			if solid:
				solid_pixels += 1
	var stats := {
		"active_pixels": 0,
		"solid_pixels": solid_pixels,
		"wall_neighbor_cases": 0,
		"cross_column_wall_neighbor_cases": 0,
		"padding_wall_neighbor_cases": 0,
		"solid_neighbor_cases": 0,
	}
	var safe_iterations_per_stride := maxi(1, iterations_per_stride)
	var pass_count := 0
	for stride_variant in strides:
		var stride := maxi(1, int(stride_variant))
		for _iteration in safe_iterations_per_stride:
			var next_pressure_values := []
			var next_encoded_values := []
			next_pressure_values.resize(pixel_count)
			next_encoded_values.resize(pixel_count)
			for y in texture_size.y:
				for x in texture_size.x:
					var index := _pixel_index(x, y, texture_size)
					var center_pressure := float(pressure_values[index])
					if bool(solid_values[index]):
						var solid_encoded := _encode_pressure(center_pressure)
						next_encoded_values[index] = solid_encoded
						next_pressure_values[index] = _decode_pressure(solid_encoded)
						continue
					stats.active_pixels += 1
					var left := _reference_neighbor_pressure(x, y, -stride, 0, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
					var right := _reference_neighbor_pressure(x, y, stride, 0, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
					var up := _reference_neighbor_pressure(x, y, 0, -stride, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
					var down := _reference_neighbor_pressure(x, y, 0, stride, source_size, center_pressure, pressure_values, solid_values, texture_size, atlas_columns, stats)
					var divergence := float(divergence_values[index])
					var safe_stride := float(maxi(1, stride))
					var new_pressure := (left + right + up + down - divergence * safe_stride * safe_stride) * 0.25
					var encoded := _encode_pressure(new_pressure)
					next_encoded_values[index] = encoded
					next_pressure_values[index] = _decode_pressure(encoded)
			pressure_values = next_pressure_values
			encoded_values = next_encoded_values
			pass_count += 1
	var initial_pressure_values := []
	initial_pressure_values.resize(pixel_count)
	for index in pixel_count:
		initial_pressure_values[index] = 0.0
	var initial_pressure_bytes := _rgba32f_bytes_from_scalar_values(initial_pressure_values, "pressure")
	var divergence_bytes := _rgba32f_bytes_from_scalar_values(divergence_values, "divergence")
	var occupancy_bytes := _rgba32f_bytes_from_solid_values(solid_values)
	return {
		"initial_pressure_bytes": initial_pressure_bytes,
		"divergence_bytes": divergence_bytes,
		"occupancy_bytes": occupancy_bytes,
		"expected_pressure": pressure_values,
		"expected_encoded_pressure": encoded_values,
		"active_pixels": int(stats.active_pixels),
		"solid_pixels": int(stats.solid_pixels),
		"wall_neighbor_cases": int(stats.wall_neighbor_cases),
		"cross_column_wall_neighbor_cases": int(stats.cross_column_wall_neighbor_cases),
		"padding_wall_neighbor_cases": int(stats.padding_wall_neighbor_cases),
		"solid_neighbor_cases": int(stats.solid_neighbor_cases),
		"jacobi_pass_count": pass_count,
		"reference_checksum": _checksum_encoded_pressure(encoded_values),
	}


func _fixture_pressure(x: int, y: int, seed: int) -> float:
	return -2.5 + 5.0 * fposmod(float(x * 31 + y * 17 + seed * 13) * 0.017, 1.0)


func _fixture_divergence(x: int, y: int, seed: int) -> float:
	return -0.16 + 0.32 * fposmod(float(x * 11 - y * 5 + seed * 7) * 0.071, 1.0)


func _fixture_stack_divergence(x: int, y: int, seed: int) -> float:
	return -0.018 + 0.036 * fposmod(float(x * 11 - y * 5 + seed * 7) * 0.071, 1.0)


func _fixture_solid(x: int, y: int, texture_size: Vector2i, seed: int) -> bool:
	var vertical_barrier := x == int(texture_size.x / 2) and y >= 3 and y <= texture_size.y - 4
	var scattered_pixel := (x * 5 + y * 9 + seed) % 19 == 0
	return vertical_barrier or scattered_pixel


func _reference_neighbor_pressure(x: int, y: int, offset_x: int, offset_y: int, source_size: float, center_pressure: float, pressure_values: Array, solid_values: Array, texture_size: Vector2i, atlas_columns: int, stats: Dictionary) -> float:
	var safe_source_size: float = maxf(source_size, 1.0)
	var base_uv := _pixel_center_uv(x, y, texture_size)
	var requested_uv := base_uv + Vector2(float(offset_x) / safe_source_size, float(offset_y) / safe_source_size)
	var safe_columns: float = maxf(float(atlas_columns), 1.0)
	var column_width: float = 1.0 / safe_columns
	var column_min: float = floor(base_uv.x * safe_columns) * column_width
	var column_max: float = column_min + column_width
	var cross_column_wall: bool = safe_columns > 1.0 and (requested_uv.x < column_min or requested_uv.x > column_max)
	var clamped_uv := _atlas_column_clamp_uv(requested_uv, base_uv, atlas_columns)
	clamped_uv.y = clampf(clamped_uv.y, 0.0, 1.0)
	var hit_wall := absf(clamped_uv.x - requested_uv.x) > FLOW_SOLVE_EPSILON
	if hit_wall:
		stats.wall_neighbor_cases += 1
		if cross_column_wall:
			stats.cross_column_wall_neighbor_cases += 1
		else:
			stats.padding_wall_neighbor_cases += 1
		return center_pressure
	var sample_x := _uv_to_texel(clamped_uv.x, texture_size.x)
	var sample_y := _uv_to_texel(clamped_uv.y, texture_size.y)
	var sample_index := _pixel_index(sample_x, sample_y, texture_size)
	if bool(solid_values[sample_index]):
		stats.solid_neighbor_cases += 1
		return center_pressure
	return float(pressure_values[sample_index])


func _pixel_index(x: int, y: int, texture_size: Vector2i) -> int:
	return y * texture_size.x + x


func _pixel_center_uv(x: int, y: int, texture_size: Vector2i) -> Vector2:
	return Vector2((float(x) + 0.5) / float(texture_size.x), (float(y) + 0.5) / float(texture_size.y))


func _atlas_column_clamp_uv(sample_uv: Vector2, base_uv: Vector2, atlas_columns: int) -> Vector2:
	var columns: float = maxf(float(atlas_columns), 1.0)
	if columns <= 1.0:
		return sample_uv
	var column_width: float = 1.0 / columns
	var column_min: float = floor(base_uv.x * columns) * column_width
	var padding: float = column_width * 0.02
	return Vector2(clampf(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y)


func _uv_to_texel(uv: float, size: int) -> int:
	return clampi(int(floor(clampf(uv, 0.0, 1.0) * float(size))), 0, maxi(0, size - 1))


func _image_from_rgba32f_bytes(texture_size: Vector2i, bytes: PackedByteArray) -> Image:
	if bytes.size() < texture_size.x * texture_size.y * 16:
		return null
	return Image.create_from_data(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAF, bytes)


func _image_from_rgba16f_bytes(texture_size: Vector2i, bytes: PackedByteArray) -> Image:
	if bytes.size() < texture_size.x * texture_size.y * 8:
		return null
	return Image.create_from_data(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAH, bytes)


func _rgba32f_bytes_from_image(image: Image) -> PackedByteArray:
	if image == null or image.is_empty():
		return PackedByteArray()
	var bytes := PackedByteArray()
	bytes.resize(image.get_width() * image.get_height() * 16)
	var index := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var offset := index * 16
			bytes.encode_float(offset, color.r)
			bytes.encode_float(offset + 4, color.g)
			bytes.encode_float(offset + 8, color.b)
			bytes.encode_float(offset + 12, color.a)
			index += 1
	return bytes


func _rgba16f_bytes_from_image(image: Image) -> PackedByteArray:
	if image == null or image.is_empty():
		return PackedByteArray()
	var converted := image.duplicate()
	converted.convert(Image.FORMAT_RGBAH)
	return converted.get_data()


func _rgba32f_bytes_from_scalar_values(values: Array, encoded_kind: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 16)
	for index in values.size():
		var value := float(values[index])
		var encoded := _encode_pressure(value) if encoded_kind == "pressure" else _encode_divergence(value)
		var offset := index * 16
		bytes.encode_float(offset, encoded)
		bytes.encode_float(offset + 4, 0.0)
		bytes.encode_float(offset + 8, 0.0)
		bytes.encode_float(offset + 12, 1.0)
	return bytes


func _rgba32f_bytes_from_solid_values(values: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 16)
	for index in values.size():
		var solid := 1.0 if bool(values[index]) else 0.0
		var offset := index * 16
		bytes.encode_float(offset, solid)
		bytes.encode_float(offset + 4, 0.0)
		bytes.encode_float(offset + 8, 0.0)
		bytes.encode_float(offset + 12, 1.0)
	return bytes


func _rgba32f_bytes_from_fill(count: int, color: Color) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(count * 16)
	for index in count:
		var offset := index * 16
		bytes.encode_float(offset, color.r)
		bytes.encode_float(offset + 4, color.g)
		bytes.encode_float(offset + 8, color.b)
		bytes.encode_float(offset + 12, color.a)
	return bytes


func _rgba16f_bytes_from_fill(texture_size: Vector2i, color: Color) -> PackedByteArray:
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAH)
	image.fill(color)
	return image.get_data()


func _read_rgba32f_red_channel(bytes: PackedByteArray, count: int) -> Array:
	var values := []
	values.resize(count)
	if bytes.size() < count * 16:
		return values
	for index in count:
		values[index] = bytes.decode_float(index * 16)
	return values


func _pressure_compare_metrics(expected_encoded: Array, actual_encoded: Array) -> Dictionary:
	var encoded_deltas := []
	var pressure_deltas := []
	var first_mismatch := {}
	var sample_count := mini(expected_encoded.size(), actual_encoded.size())
	for index in sample_count:
		var expected := float(expected_encoded[index])
		var actual := float(actual_encoded[index])
		var encoded_delta := absf(expected - actual)
		var pressure_delta := absf(_decode_pressure(expected) - _decode_pressure(actual))
		encoded_deltas.append(encoded_delta)
		pressure_deltas.append(pressure_delta)
		if first_mismatch.is_empty() and (encoded_delta > 0.00001 or pressure_delta > 0.001):
			first_mismatch = {
				"index": index,
				"expected_encoded": expected,
				"actual_encoded": actual,
				"encoded_delta": encoded_delta,
				"pressure_delta": pressure_delta,
			}
	return {
		"sample_count": sample_count,
		"encoded_max_abs": _max_float(encoded_deltas),
		"encoded_p99_abs": _percentile(encoded_deltas, 0.99),
		"encoded_mean_abs": _mean_float(encoded_deltas),
		"pressure_max_abs": _max_float(pressure_deltas),
		"pressure_p99_abs": _percentile(pressure_deltas, 0.99),
		"pressure_mean_abs": _mean_float(pressure_deltas),
		"first_mismatch": first_mismatch,
	}


func _append_metrics_to_result(result: Dictionary, metrics: Dictionary) -> void:
	for key in metrics.keys():
		result["metric_" + String(key)] = metrics[key]


func _encode_pressure(value: float) -> float:
	return clampf(value * FLOW_SOLVE_PRESSURE_SCALE + 0.5, 0.0, 1.0)


func _encode_divergence(value: float) -> float:
	return clampf(value * FLOW_SOLVE_DIV_SCALE + 0.5, 0.0, 1.0)


func _decode_pressure(encoded: float) -> float:
	return (encoded - 0.5) / FLOW_SOLVE_PRESSURE_SCALE


func _make_initial_values(seed: int, count: int) -> Array:
	var values := []
	values.resize(count)
	var value := _u32(seed * 1664525 + 1013904223)
	for index in count:
		value = _u32(value * 1103515245 + 12345 + index * 97)
		values[index] = value
	return values


func _advance_values(values: Array) -> Array:
	var next_values := []
	next_values.resize(values.size())
	for index in values.size():
		next_values[index] = _u32(int(values[index]) * 1664525 + 1013904223 + index * 747796405)
	return next_values


func _u32_array_to_bytes(values: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 4)
	for index in values.size():
		bytes.encode_u32(index * 4, int(values[index]))
	return bytes


func _bytes_to_u32_array(bytes: PackedByteArray, count: int) -> Array:
	var values := []
	values.resize(count)
	if bytes.size() < count * 4:
		return values
	for index in count:
		values[index] = int(bytes.decode_u32(index * 4))
	return values


func _first_mismatch(expected: Array, actual: Array) -> Dictionary:
	if expected.size() != actual.size():
		return {
			"index": -1,
			"expected_size": expected.size(),
			"actual_size": actual.size()
		}
	for index in expected.size():
		if int(expected[index]) != int(actual[index]):
			return {
				"index": index,
				"expected": int(expected[index]),
				"actual": int(actual[index])
			}
	return {}


func _checksum_u32(values: Array) -> int:
	var checksum := 0
	for value in values:
		checksum = _u32(checksum + int(value))
	return checksum


func _checksum_encoded_pressure(values: Array) -> int:
	var checksum := 0
	for value in values:
		checksum = _u32(checksum + int(round(float(value) * 1000000.0)))
	return checksum


func _checksum_rgba32f_bytes(bytes: PackedByteArray) -> int:
	var checksum := 0
	var value_count := int(bytes.size() / 4)
	for value_index in value_count:
		checksum = _u32(checksum + int(round(bytes.decode_float(value_index * 4) * 1000000.0)))
	return checksum


func _checksum_image(image: Image) -> int:
	if image == null or image.is_empty():
		return 0
	var checksum := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			checksum = _u32(checksum + int(round(color.r * 1000000.0)))
			checksum = _u32(checksum + int(round(color.g * 1000000.0)))
			checksum = _u32(checksum + int(round(color.b * 1000000.0)))
			checksum = _u32(checksum + int(round(color.a * 1000000.0)))
	return checksum


func _u32(value: int) -> int:
	return int(value % UINT32_MOD)


func _max_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := -INF
	for value in values:
		result = maxf(result, float(value))
	return result


func _mean_float(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += float(value)
	return sum / float(values.size())


func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


func _config_int_array(config: Dictionary, key: String, fallback: Array) -> Array:
	var source = config.get(key, fallback)
	var result := []
	if typeof(source) == TYPE_ARRAY:
		for value in source:
			result.append(maxi(1, int(value)))
	elif typeof(source) == TYPE_PACKED_INT32_ARRAY:
		for value in source:
			result.append(maxi(1, int(value)))
	if result.is_empty():
		for value in fallback:
			result.append(maxi(1, int(value)))
	return result


func _free_owned_rids() -> void:
	for reverse_index in _owned_rids.size():
		var rid := _owned_rids[_owned_rids.size() - 1 - reverse_index]
		if rid.is_valid():
			_rd.free_rid(rid)
	_owned_rids.clear()


func _is_cancellation_requested(cancellation: Callable = Callable()) -> bool:
	if _aborted:
		return true
	if cancellation.is_valid():
		return bool(cancellation.call())
	return false


func _emit_warning(message: String) -> void:
	if _warning_callback.is_valid():
		_warning_callback.call(message)
		return
	push_warning(message)
