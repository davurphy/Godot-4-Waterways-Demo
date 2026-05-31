shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D flowmap : repeat_disable, filter_linear;
uniform sampler2D distmap : hint_default_white, repeat_disable, filter_linear;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_grade_energy : hint_range(0.0, 8.0) = 1.0;
uniform float flow_bend_bias : hint_range(0.0, 8.0) = 0.5;
uniform float flow_bank_drag : hint_range(0.0, 1.0) = 0.55;
uniform float flow_shallow_drag : hint_range(0.0, 1.0) = 0.35;
uniform float flow_inside_bend_drag : hint_range(0.0, 1.0) = 0.25;
uniform float flow_pressure_bank_gate : hint_range(0.0, 1.0) = 0.75;
uniform float flow_hard_boundary_pressure : hint_range(0.0, 1.0) = 0.45;
uniform float flow_hard_boundary_slide : hint_range(0.0, 1.0) = 0.45;
uniform float flow_hard_boundary_min_downstream : hint_range(0.0, 1.0) = 0.55;
uniform float flow_boundary_probe : hint_range(0.25, 4.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;
uniform bool valid_flowmap = false;
uniform int uv2_sides = 2;
uniform sampler2D terrain_contact_features : hint_default_black, repeat_disable, filter_linear;
uniform sampler2D bank_response_features : hint_default_black, repeat_disable, filter_linear;

const float EPSILON = 0.0001;

varying vec3 world_position;
varying vec2 mesh_uv;


vec3 srgb_to_linear(vec3 color) {
	return mix(
		color / 12.92,
		pow((color + vec3(0.055)) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color)
	);
}

vec3 data_to_albedo(vec3 color) {
	if (OUTPUT_IS_SRGB) {
		return color;
	}
	return srgb_to_linear(color);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mesh_uv = UV;
}

vec2 safe_direction(vec2 vector, vec2 fallback) {
	float vector_length = length(vector);
	if (vector_length <= EPSILON) {
		return fallback;
	}
	return vector / vector_length;
}

vec2 keep_minimum_alignment(vec2 direction, vec2 baseline_direction, float min_alignment) {
	float floor_value = clamp(min_alignment, 0.0, 0.95);
	if (floor_value <= EPSILON) {
		return direction;
	}
	float downstream = dot(direction, baseline_direction);
	if (downstream >= floor_value) {
		return direction;
	}
	vec2 lateral = direction - baseline_direction * downstream;
	float lateral_magnitude = length(lateral);
	if (lateral_magnitude <= EPSILON) {
		return baseline_direction;
	}
	float lateral_limit = sqrt(max(0.0, 1.0 - floor_value * floor_value));
	return normalize(baseline_direction * floor_value + (lateral / lateral_magnitude) * lateral_limit);
}

float boundary_context_at(vec2 uv) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 terrain_contact = textureLod(terrain_contact_features, safe_uv, 0.0);
	vec4 bank_response = textureLod(bank_response_features, safe_uv, 0.0);
	float hard_context = max(bank_response.a, terrain_contact.b);
	float soft_contact = max(bank_response.r * 0.35, terrain_contact.r * 0.25);
	return clamp(max(hard_context, soft_contact), 0.0, 1.0);
}

vec2 boundary_gradient_at(vec2 uv, vec2 offset) {
	vec2 dx = vec2(offset.x, 0.0);
	vec2 dy = vec2(0.0, offset.y);
	return vec2(
		boundary_context_at(uv + dx) - boundary_context_at(uv - dx),
		boundary_context_at(uv + dy) - boundary_context_at(uv - dy)
	);
}

vec2 apply_contextual_flow_slide(vec2 flow, vec2 uv, vec2 texel_size, float hard_boundary) {
	float flow_magnitude = length(flow);
	if (flow_magnitude <= EPSILON) {
		return flow;
	}
	vec2 baseline_direction = flow / flow_magnitude;
	vec2 probe_offset = texel_size * max(flow_boundary_probe, 0.25);
	vec2 boundary_gradient = boundary_gradient_at(uv, probe_offset);
	float gradient_magnitude = length(boundary_gradient);
	if (gradient_magnitude <= EPSILON) {
		return flow;
	}
	vec2 boundary_normal = boundary_gradient / gradient_magnitude;
	vec2 boundary_tangent = normalize(vec2(-boundary_normal.y, boundary_normal.x));
	if (dot(boundary_tangent, baseline_direction) < 0.0) {
		boundary_tangent = -boundary_tangent;
	}
	float flow_into_boundary = max(dot(baseline_direction, boundary_normal), 0.0);
	float slide_gate = clamp(hard_boundary * smoothstep(0.03, 0.35, gradient_magnitude) * mix(0.35, 1.0, flow_into_boundary), 0.0, 1.0);
	float slide_amount = clamp(flow_hard_boundary_slide, 0.0, 1.0) * slide_gate;
	if (slide_amount <= EPSILON) {
		return flow;
	}
	vec2 slide_direction = safe_direction(mix(baseline_direction, boundary_tangent, slide_amount), baseline_direction);
	slide_direction = keep_minimum_alignment(slide_direction, baseline_direction, flow_hard_boundary_min_downstream);
	return slide_direction * flow_magnitude;
}

mat2 get_world_xz_from_uv_axes() {
	vec2 dpdx = dFdx(world_position.xz);
	vec2 dpdy = dFdy(world_position.xz);
	vec2 duvdx = dFdx(mesh_uv);
	vec2 duvdy = dFdy(mesh_uv);
	float det = duvdx.x * duvdy.y - duvdx.y * duvdy.x;
	if (abs(det) <= EPSILON) {
		return mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));
	}
	vec2 world_u = (dpdx * duvdy.y - dpdy * duvdx.y) / det;
	vec2 world_v = (-dpdx * duvdy.x + dpdy * duvdx.x) / det;
	return mat2(
		safe_direction(world_u, vec2(1.0, 0.0)),
		safe_direction(world_v, vec2(0.0, 1.0))
	);
}

void fragment() {
	float safe_uv2_sides = max(float(uv2_sides), 1.0);
	vec2 atlas_size = max(vec2(textureSize(flowmap, 0)), vec2(1.0));
	vec2 source_size = max(round(atlas_size * safe_uv2_sides / (safe_uv2_sides + 2.0)), vec2(1.0));
	vec2 margin = round((atlas_size - source_size) * 0.5);
	vec2 custom_UV = (UV2 * source_size + margin) / atlas_size;
	vec2 flow_foam_noise = textureLod(flowmap, custom_UV, 0.0).rg;
	vec4 dist_pressure_features = textureLod(distmap, custom_UV, 0.0);
	vec4 terrain_contact = textureLod(terrain_contact_features, custom_UV, 0.0);
	vec4 bank_response = textureLod(bank_response_features, custom_UV, 0.0);
	vec2 dist_pressure = dist_pressure_features.xy;
	
	vec2 flow;
	float distance_map;
	float pressure_map;
	float grade_energy_map;
	float bend_bias_map;
	float terrain_shallow;
	float terrain_protrusion;
	float bank_friction_drag;
	float outside_bend_wet_pressure;
	float inside_bend_deposition;
	float hard_boundary_protrusion;
	if (valid_flowmap) {
		flow = flow_foam_noise.xy;
		distance_map = (1.0 - dist_pressure.r) * 2.0;
		pressure_map = dist_pressure.g * 2.0;
		grade_energy_map = dist_pressure_features.b;
		bend_bias_map = dist_pressure_features.a * 2.0 - 1.0;
		terrain_shallow = terrain_contact.g;
		terrain_protrusion = terrain_contact.b;
		bank_friction_drag = bank_response.r;
		outside_bend_wet_pressure = bank_response.g;
		inside_bend_deposition = bank_response.b;
		hard_boundary_protrusion = bank_response.a;
	} else {
		flow = vec2(0.5, 0.572);
		distance_map = 0.5;
		pressure_map = 0.5;
		grade_energy_map = 0.0;
		bend_bias_map = 0.0;
		terrain_shallow = 0.0;
		terrain_protrusion = 0.0;
		bank_friction_drag = 0.0;
		outside_bend_wet_pressure = 0.0;
		inside_bend_deposition = 0.0;
		hard_boundary_protrusion = 0.0;
	}
	
	flow = (flow - 0.5) * 2.0; // remap
	float hard_boundary_context = clamp(max(hard_boundary_protrusion, terrain_protrusion), 0.0, 1.0);
	flow = apply_contextual_flow_slide(flow, custom_UV, 1.0 / atlas_size, hard_boundary_context);
	
	// calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
	
	float ordinary_bank = clamp(bank_friction_drag * (1.0 - hard_boundary_context), 0.0, 1.0);
	float pressure_gate_base = 1.0 - clamp((ordinary_bank + terrain_shallow * 0.35) * flow_pressure_bank_gate, 0.0, 0.95);
	float pressure_gate = clamp(mix(pressure_gate_base, clamp(flow_hard_boundary_pressure, 0.0, 1.0), hard_boundary_context), 0.0, 1.0);
	pressure_gate = max(pressure_gate, outside_bend_wet_pressure * 0.35);
	float grade_resistance = 1.0 - clamp(max(ordinary_bank, terrain_shallow) * 0.35, 0.0, 0.65);
	float context_drag = ordinary_bank * flow_bank_drag + terrain_shallow * flow_shallow_drag + inside_bend_deposition * flow_inside_bend_drag + hard_boundary_context * max(flow_bank_drag, flow_shallow_drag) * 0.20;
	context_drag *= 1.0 - outside_bend_wet_pressure * 0.25;
	context_drag = clamp(context_drag, 0.0, 0.85);
	float flow_force = clamp(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure * pressure_gate + grade_energy_map * flow_grade_energy * grade_resistance + bend_bias_map * flow_bend_bias, 0.0, flow_max);
	flow_force *= 1.0 - context_drag;
	flow *= flow_force;
	
	mat2 world_from_uv = get_world_xz_from_uv_axes();
	vec2 new_flow = world_from_uv * flow;
	ALBEDO = data_to_albedo(vec3((new_flow), 0.0) * 0.5 + 0.5); // repack flowmap
}
