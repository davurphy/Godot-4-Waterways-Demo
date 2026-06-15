shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://addons/waterways/shaders/flow_pack.gdshaderinc"
#include "res://addons/waterways/shaders/river_flow_common.gdshaderinc"

uniform sampler2D flowmap : repeat_disable, filter_linear;
uniform sampler2D distmap : hint_default_white, repeat_disable, filter_linear;
uniform bool valid_flowmap = false;
uniform int uv2_sides = 2;

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

	vec2 flow;
	vec4 dist_pressure_features;
	vec4 terrain_contact;
	vec4 bank_response;
	if (valid_flowmap) {
		flow = textureLod(flowmap, custom_UV, 0.0).rg;
		dist_pressure_features = textureLod(distmap, custom_UV, 0.0);
		terrain_contact = textureLod(i_terrain_contact_features, custom_UV, 0.0);
		bank_response = textureLod(i_bank_response_features, custom_UV, 0.0);
	} else {
		// Neutral inputs for contextual_flow_force matching the pre-include
		// neutral scalars (distance 0.5, pressure 0.5, grade 0, bend 0, no
		// boundary context) - the same neutral texel river_manager binds for
		// a null distmap.
		flow = vec2(0.5, 0.572);
		dist_pressure_features = vec4(0.75, 0.25, 0.0, 0.5);
		terrain_contact = vec4(0.0);
		bank_response = vec4(0.0);
	}

	flow = flow_pack_decode(flow);
	float hard_boundary_context = clamp(max(bank_response.a, terrain_contact.b), 0.0, 1.0);
	// Defect 1 fix (2026-06-12, river-refactor R2): pressure-projected flow is
	// divergence-free; re-bending it with the boundary slide corrupted what
	// buoyant ducks read. The slide (with its stagnation-centerline fade) and
	// the force shaping below now come from river_flow_common.gdshaderinc -
	// the same code the river surface runs, so the three copies cannot drift.
	if (!i_flow_projected) {
		flow = apply_contextual_flow_slide(flow, custom_UV, 1.0 / atlas_size, hard_boundary_context);
	}

	// calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;

	float flow_force = contextual_flow_force(dist_pressure_features, terrain_contact, bank_response, steepness_map);
	flow *= flow_force;

	mat2 world_from_uv = get_world_xz_from_uv_axes();
	vec2 new_flow = world_from_uv * flow;
	ALBEDO = data_to_albedo(vec3(flow_pack_encode_unclamped(new_flow), 0.5)); // repack flowmap
}
