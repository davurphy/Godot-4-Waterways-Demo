// Copyright (c) 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
//
// Canonical packed-flow codec (river-refactor R3.2, 2026-06-12): a flow
// vector v in [-1, 1]^2 is stored in a texture's RG as rg = v * 0.5 + 0.5
// (neutral 0.5). Single shader-side source of truth for river / river_debug /
// system_flow / lava and the bake filter passes.
//
// Cross-language mirrors that must stay in sync (cannot consume an include):
// - water_helper_methods.gd decode_packed_flow_vector / encode_packed_flow_vector
// - flow_solve_common.gdshaderinc flow_solve_decode/encode_velocity (the bake
//   solve keeps its own internally-consistent encoding family; its 0.5 bias
//   is additionally asserted against the CPU pressure seed by
//   flow_solve_seed_assert_probe)
//
// Float-form note: (x - 0.5) * 2.0 and x * 2.0 - 1.0 round identically in
// IEEE float (scaling by 2 is exact), so consolidating the two historical
// spellings here is bit-safe.

vec2 flow_pack_decode(vec2 packed_rg) {
	return (packed_rg - vec2(0.5)) * 2.0;
}

vec2 flow_pack_encode_unclamped(vec2 flow_vector) {
	return flow_vector * 0.5 + 0.5;
}

vec2 flow_pack_encode(vec2 flow_vector) {
	return clamp(flow_pack_encode_unclamped(flow_vector), vec2(0.0), vec2(1.0));
}
