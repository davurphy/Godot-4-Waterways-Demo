// Shared helpers for the bake-time pressure projection solve
// (divergence -> Jacobi pressure -> gradient subtract -> boundary tangency).
//
// All solve passes run on the margin-padded UV2 atlas. X-offset reads must
// stay inside the fragment's column band (atlas columns are world-disjoint
// river stretches); a clamped X read is treated as a free-slip wall.
// Y-offset reads are world-continuous within a column and read continuation
// content in the whole-image margins, so they sample freely (clamped to the
// image edge, which acts as an open boundary).
//
// Encodings (solve passes render with use_hdr_2d, f16 targets):
//   velocity: packed RG, v = rg * 2 - 1 (matches the river flowmap encoding)
//   divergence: enc = div * FLOW_SOLVE_DIV_SCALE + 0.5
//   pressure:   enc = p * FLOW_SOLVE_PRESSURE_SCALE + 0.5
//
// The bake seeds the Jacobi pressure ping-pong CPU-side with
// river_manager's RIVER_FLOW_PRESSURE_SEED_COLOR (r = 0.5), which is enc(0)
// for all three encodings above. Changing any 0.5 bias here requires
// updating that seed; flow_solve_seed_assert_probe asserts the pairing.

const float FLOW_SOLVE_EPSILON = 0.0001;
const float FLOW_SOLVE_DIV_SCALE = 0.25;
const float FLOW_SOLVE_PRESSURE_SCALE = 0.03125; // 1/32 - potential-flow pressure scales with obstacle radius in texels

vec2 flow_solve_decode_velocity(vec4 color) {
	return color.rg * 2.0 - 1.0;
}

vec4 flow_solve_encode_velocity(vec2 velocity) {
	return vec4(clamp(velocity * 0.5 + 0.5, vec2(0.0), vec2(1.0)), 0.0, 1.0);
}

float flow_solve_decode_divergence(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_DIV_SCALE;
}

vec4 flow_solve_encode_divergence(float divergence) {
	return vec4(clamp(divergence * FLOW_SOLVE_DIV_SCALE + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0);
}

float flow_solve_decode_pressure(vec4 color) {
	return (color.r - 0.5) / FLOW_SOLVE_PRESSURE_SCALE;
}

vec4 flow_solve_encode_pressure(float pressure) {
	return vec4(clamp(pressure * FLOW_SOLVE_PRESSURE_SCALE + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0);
}

// Offset sample position with wall detection. X reads that would leave the
// fragment's column band are clamped and flagged as a wall; Y reads clamp to
// the image edge without flagging (open ends / continuation margins).
vec2 flow_solve_neighbor_uv(vec2 base_uv, vec2 offset_uv, out bool hit_wall) {
	vec2 requested = base_uv + offset_uv;
	vec2 clamped = atlas_column_clamp(requested, base_uv);
	clamped.y = clamp(clamped.y, 0.0, 1.0);
	hit_wall = abs(clamped.x - requested.x) > FLOW_SOLVE_EPSILON;
	return clamped;
}
