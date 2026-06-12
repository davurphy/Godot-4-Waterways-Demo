// Shared helper for UV2-atlas-aware filter passes.
//
// The river bake atlas packs world-disjoint stretches of river into
// horizontally adjacent column bands (steps stack down each column, plus
// one margin band on each side). Offset sample reads must therefore never
// cross the column band of the fragment they serve, or obstacles bleed
// into river stretches that are far away in the world.
// atlas_columns <= 1.0 disables clamping for single-image consumers.
uniform float atlas_columns = 1.0;

vec2 atlas_column_clamp(vec2 sample_uv, vec2 base_uv) {
	float columns = max(atlas_columns, 1.0);
	if (columns <= 1.0) {
		return sample_uv;
	}
	float column_width = 1.0 / columns;
	float column_min = floor(base_uv.x * columns) * column_width;
	// Padding keeps bilinear taps off the shared boundary and absorbs the
	// +/-1px floor-partition misalignment of real tile rects.
	float padding = column_width * 0.02;
	return vec2(clamp(sample_uv.x, column_min + padding, column_min + column_width - padding), sample_uv.y);
}
