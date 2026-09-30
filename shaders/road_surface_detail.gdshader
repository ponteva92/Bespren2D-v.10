shader_type canvas_item;
// Deviation-only surface grain for the authored road graph.
//
// The road bed used to be a single flat `draw_polyline`, and it was the largest
// dead area in the game: row y=105 of `world_mall_validation.png` was 480
// identical pixels, and one colour covered a fifth to a quarter of five city
// captures. Authored marks alone could not fix that - eight aggregate strokes on
// a 52-unit row cover 6.6 percent of a 420-unit bed, so the flat fill survived
// underneath them and simply changed which colour was modal.
//
// This samples the grain the ground is already made of. It reads the same
// `polyhaven_terrain_atlas` cell that `terrain_material_blend.gdshader` uses for
// that biome, subtracts the cell's measured mean, and adds only what is left to
// whatever colour the CanvasItem drew. The road therefore keeps its authored
// value - which matters, because the bed at luma 59.4 and the city ground at a
// predicted 61.8 are nearly the same, so a road that sampled the asphalt scan
// outright would vanish into the terrain and lose the dark shoulder and dashes
// it is actually read from - while gaining a photoscan's edge structure at one
// draw call instead of two thousand line segments.
//
// The period matches the terrain's own: that shader repeats 28 times across
// 28,672 world units, so one tile is 1,024 units, and using the same figure here
// keeps grain the same physical size whether the player is standing on road or
// on ground. Deliberately not `unshaded` - CLAUDE.md 8 records what happens to a
// surface that opts out of `CanvasModulate`, and the road must fall to the blue
// hour with the world around it.

uniform sampler2D detail_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_cell = vec2(0.0, 0.0);
uniform vec3 cell_mean = vec3(0.1797, 0.1813, 0.1839);
uniform float world_period : hint_range(256.0, 4096.0) = 1024.0;
uniform float detail_strength : hint_range(0.0, 2.5) = 1.25;

const float ATLAS_SIZE = 1024.0;
const float CELL_SIZE = 512.0;
const float GUTTER = 8.0;
const float CONTENT_SIZE = 496.0;

varying vec2 world_position;

vec2 cell_uv(vec2 local_uv) {
	vec2 pixel = atlas_cell * CELL_SIZE + vec2(GUTTER) + local_uv * CONTENT_SIZE;
	return pixel / ATLAS_SIZE;
}

vec3 sample_seamless(vec2 repeated_uv) {
	// Same cross-fade the terrain uses. It is worth its second sample here for a
	// reason the terrain does not have: `fract` makes the UV derivative explode
	// on the wrap line, which picks the coarsest mip for a single pixel column
	// and draws a blurred seam every 1,024 units straight down the carriageway.
	// The half-period copy puts its own wrap somewhere else, so the blend has a
	// clean sample available wherever the other one is breaking down.
	vec2 local_uv = fract(repeated_uv);
	vec2 shifted_uv = fract(local_uv + vec2(0.5));
	vec2 edge_distance = min(local_uv, vec2(1.0) - local_uv);
	vec2 interior = smoothstep(vec2(0.08), vec2(0.20), edge_distance);
	float base_weight = interior.x * interior.y;
	vec3 shifted_sample = texture(detail_atlas, cell_uv(shifted_uv)).rgb;
	vec3 base_sample = texture(detail_atlas, cell_uv(local_uv)).rgb;
	return mix(shifted_sample, base_sample, base_weight);
}

void vertex() {
	// The road is drawn as polylines and polygons, which carry no useful UV of
	// their own, so the grain is anchored to world space instead. That also makes
	// it continuous across a chunk seam for free: two chunks meeting at 4,096
	// units sample the same world coordinate and therefore the same texel.
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 grain = sample_seamless(world_position / world_period) - cell_mean;
	COLOR.rgb = clamp(COLOR.rgb + grain * detail_strength, vec3(0.0), vec3(1.0));
}
