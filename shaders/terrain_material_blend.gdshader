shader_type canvas_item;

uniform sampler2D biome_mask : filter_linear, repeat_disable;
uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float texture_repeats : hint_range(8.0, 48.0) = 28.0;
uniform float overlay_opacity : hint_range(0.0, 1.0) = 0.66;
uniform float saturation : hint_range(0.0, 1.4) = 1.06;
// Macro breakup. The blend above runs at a single spatial frequency, so a
// screen of ground is one flat value however good the source scans are. These
// two octaves of value noise vary tone across distances larger than the camera
// sees, which is what stops 28,672 units of world from reading as one surface.
// They are pure ALU - no extra sampler, no extra bandwidth on a full-screen
// pass - and use the same bounded hash the weathering shader already relies on
// rather than a dynamic loop.
uniform float macro_scale : hint_range(2.0, 32.0) = 9.0;
uniform float macro_strength : hint_range(0.0, 0.4) = 0.15;
uniform float macro_warmth : hint_range(0.0, 0.2) = 0.05;
// Forest floor. The macro octaves above work at roughly 3,200 and 1,200 world
// units; the ground a player actually sees between two trees is three hundred.
// At that scale the forest cell of the atlas is one scan of leaf litter and a
// screen of it reads as one flat brown - and this is the biome where that costs
// the most, because CLAUDE.md 8 names deep charcoal and petroleum green as the
// world's value base and the green half was nowhere in the ground. `mottle`
// carries the value half at a readable patch size, `patina` the hue half, and
// both are multiplied by the forest weight so asphalt, concrete and mud are
// untouched. Two more value-noise evaluations: no extra sampler, no loop.
uniform float forest_mottle_scale : hint_range(8.0, 160.0) = 62.0;
uniform float forest_mottle_strength : hint_range(0.0, 0.5) = 0.26;
// Detail band. Measured off the shipped gameplay capture at the 0.38 camera
// zoom, block-mean luma standard deviation runs 8.05 at a 2-pixel block, 4.91 at
// 16 and 2.93 at 64 - so two thirds of the frame's variance sits below the scale
// at which anything can be recognised, and the picture is busy up close and flat
// as a composition, which is the inverse of what a 480x270 target wants. One
// atlas repeat covers 1,024 world units, which is 389 screen pixels at that zoom
// carrying 496 texels of leaf litter, so the scan is displayed near one texel per
// pixel and its grain lands on the sampling limit. A mip bias moves that band
// down with no second fetch and, because a mip level is an average of the level
// below it, without moving the ground's mean off the 53.0 forest-floor luma.
uniform float detail_softness : hint_range(0.0, 2.0) = 1.0;
// The amplitude taken out of the pixel band is put back where the eye reads
// shape. `mottle` works at 462 world units, about 176 screen pixels, which is
// under three cycles across the frame; `relief` is a second, tighter field at
// roughly 69 pixels, so the ground carries both the broad patch and the break-up
// inside it. Non-harmonic against the mottle scale, and kept as its own field
// rather than folded in as an octave of it because `bloom` below reads `mottle`
// directly and its window is solved against that field's own distribution -
// summing two uniforms there would narrow the distribution the window was cut
// for and quietly retune the patina pass along with the value one.
uniform float forest_relief_scale : hint_range(40.0, 400.0) = 158.0;
uniform float forest_relief_strength : hint_range(0.0, 0.4) = 0.13;
// Copper patina `#1C8270` carried as a direction rather than as a colour. The
// bloom below rescales it to whatever luminance the litter already has, so only
// the ratios between the channels survive and the sRGB-versus-linear question
// cannot move the ground's value in either reading. Taken as sRGB ratios it is
// the less saturated of the two, which is the safer default under something
// players navigate across.
//
// The reach was 0.34 and the pass was invisible, and the arithmetic says why
// rather than the eye. Rescaling the patina to the litter's own luminance means
// the two colours differ only in hue, so a pixel does not read green until the
// mix carries it past the litter's own red-over-green bias: measured off the
// graded litter that crossover sits at a mix fraction of about 0.27. The old
// chain - an upper-tail `smoothstep`, times `1.0 - mottle`, times 0.34, times a
// forest weight of 0.84 - peaked at 0.29 and averaged nearer 0.014, so almost
// every pixel it touched was moved by less than the amount needed to see it at
// all. Measured on the forest-density capture: 3.71 percent of the frame read
// green and 0.26 percent read strongly green, against CLAUDE.md 8 naming
// petroleum green as half the world's value base. The reach now clears that
// crossover, and the gate below decides where.
//
// It was then overshot in the other direction and the overshoot is the more
// useful measurement of the two. At a reach of 0.55 with a floor under the
// mottle term, 43.9 percent of the frame read green, the forest side averaged
// rgb (45.4, 52.6, 41.4), and the block-level green index never fell below 2.7
// anywhere - there was no dry litter left in the shot at all. The picture was a
// green field with a brown road cut through it, which is not a forest floor;
// leaf litter is the ground and moss is the patch on it, not the reverse. The
// numbers below are solved for that reading rather than tried: a crossover at
// t = 0.266, a median mix near 0.10, and roughly a fifth of the area past the
// crossover.
//
// The hue moved with it. `#1C8270` is the locked anchor for weathered
// technology, and read at the strength a ground plane needs it goes to pond
// teal - the blue channel is nearly as high as it is on a colour that is
// supposed to be growing. This is that anchor with the blue pulled down and the
// red lifted a touch, roughly `#22805C`: still cool, still in the petroleum
// family CLAUDE.md 8 asks the world's base to sit in, but unmistakably a plant
// rather than an oxidised plate. The anchor itself is untouched where it is
// actually used.
uniform vec3 forest_patina = vec3(0.135, 0.500, 0.360);
uniform float forest_patina_reach : hint_range(0.0, 0.7) = 0.60;
uniform float forest_damp_depth : hint_range(0.7, 1.0) = 0.88;
uniform float contrast : hint_range(0.8, 1.3) = 1.04;
uniform float exposure : hint_range(0.8, 1.6) = 1.24;
uniform float black_lift : hint_range(0.0, 0.12) = 0.035;

const float ATLAS_SIZE = 1024.0;
const float CELL_SIZE = 512.0;
const float GUTTER = 8.0;
const float CONTENT_SIZE = 496.0;

float terrain_hash(vec2 p) {
	vec2 wrapped = fract(p * vec2(233.34, 851.73));
	wrapped += dot(wrapped, wrapped + 23.45);
	return fract(wrapped.x * wrapped.y);
}

float terrain_value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 smooth_f = f * f * (3.0 - 2.0 * f);
	float a = terrain_hash(cell);
	float b = terrain_hash(cell + vec2(1.0, 0.0));
	float c = terrain_hash(cell + vec2(0.0, 1.0));
	float d = terrain_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_f.x), mix(c, d, smooth_f.x), smooth_f.y);
}

vec2 terrain_uv(vec2 local_uv, vec2 atlas_cell) {
	vec2 pixel = atlas_cell * CELL_SIZE + vec2(GUTTER) + local_uv * CONTENT_SIZE;
	return pixel / ATLAS_SIZE;
}

vec3 sample_seamless_cell(vec2 repeated_uv, vec2 atlas_cell) {
	// Cross-fade the authored tile against a half-period copy only near its
	// borders. This hides source-edge discontinuities without blurring the
	// texture interior or adding another world-sized CanvasItem.
	vec2 local_uv = fract(repeated_uv);
	vec2 shifted_uv = fract(local_uv + vec2(0.5));
	vec2 edge_distance = min(local_uv, vec2(1.0) - local_uv);
	vec2 interior = smoothstep(vec2(0.08), vec2(0.20), edge_distance);
	float base_weight = interior.x * interior.y;
	vec3 shifted_sample = texture(terrain_atlas, terrain_uv(shifted_uv, atlas_cell), detail_softness).rgb;
	vec3 base_sample = texture(terrain_atlas, terrain_uv(local_uv, atlas_cell), detail_softness).rgb;
	return mix(shifted_sample, base_sample, base_weight);
}

void fragment() {
	vec3 encoded = clamp(texture(biome_mask, UV).rgb, vec3(0.0), vec3(1.0));
	float mud_weight = max(1.0 - encoded.r - encoded.g - encoded.b, 0.0);
	vec4 weights = vec4(encoded.r, encoded.g, encoded.b, mud_weight);
	weights /= max(dot(weights, vec4(1.0)), 0.0001);

	vec2 repeated = UV * texture_repeats;
	vec3 asphalt = sample_seamless_cell(repeated, vec2(0.0, 0.0));
	vec3 mud = sample_seamless_cell(repeated, vec2(1.0, 0.0));
	vec3 forest = sample_seamless_cell(repeated, vec2(0.0, 1.0));
	vec3 concrete = sample_seamless_cell(repeated, vec2(1.0, 1.0));
	vec3 graded = (
		forest * weights.r
		+ asphalt * weights.g
		+ concrete * weights.b
		+ mud * weights.a
	);
	// Two octaves, roughly 3,200 and 1,200 world units across, so one carries
	// tone past the edge of the screen and the other breaks up what is on it.
	float macro = terrain_value_noise(UV * macro_scale) * 0.62
		+ terrain_value_noise(UV * macro_scale * 2.7 + vec2(17.0, 5.0)) * 0.38;
	float macro_signal = macro * 2.0 - 1.0;
	graded *= 1.0 + macro_signal * macro_strength;
	// A patch that lifts also warms, which is how sun-bleached ground differs
	// from damp ground. Tiny, but it stops the variation reading as a grey
	// brightness dial laid over the biome colours.
	graded.r *= 1.0 + macro_signal * macro_warmth;
	graded.b *= 1.0 - macro_signal * macro_warmth;
	// Value first: litter breaks into patches, so the field that lifts a dry patch
	// is the same one that sinks the hollow beside it.
	float mottle = terrain_value_noise(UV * forest_mottle_scale + vec2(41.0, 63.0));
	// The damp field was authored at 0.37 of the mottle scale, which is a period of
	// roughly 1,250 world units - wider than the 480x270 viewport at the shipped
	// 0.38 gameplay zoom. A patch larger than the screen is not a patch; it is a
	// tint that drifts as the player walks. 0.83 puts it near 580 units, so a moss
	// bed is about a third of the screen in play and still resolves as blobs in the
	// wider density captures. Non-harmonic against the mottle scale on purpose.
	float damp = terrain_value_noise(UV * forest_mottle_scale * 0.83 + vec2(7.0, 29.0));
	float forest_weight = weights.r;
	graded *= 1.0 + (mottle * 2.0 - 1.0) * forest_mottle_strength * forest_weight;
	float relief = terrain_value_noise(UV * forest_relief_scale + vec2(19.0, 88.0));
	graded *= 1.0 + (relief * 2.0 - 1.0) * forest_relief_strength * forest_weight;
	// Hue second, and only where the litter is dark and the damp field is high, so
	// the patina collects in hollows rather than dusting the whole biome. The
	// target is luminance-matched to the litter it replaces and then dropped by
	// `forest_damp_depth`, because wet ground is darker than dry ground and a
	// green that also lifted would compete with the silhouettes standing on it.
	vec3 luma_weights = vec3(0.2126, 0.7152, 0.0722);
	float litter_luma = dot(graded, luma_weights);
	float patina_luma = max(dot(forest_patina, luma_weights), 0.0001);
	vec3 damp_ground = forest_patina * (litter_luma / patina_luma) * forest_damp_depth;
	// `1.0 - mottle` was a multiply, so half the field was zeroed for no reason
	// beyond that the litter there was dry; a floor of 0.58 under it then removed
	// the dry ground entirely. 0.30 is the setting that keeps both halves of that:
	// moss still prefers the hollows strongly, and the driest litter still gets a
	// trace rather than a hard mask edge. The window's low end sits just under the
	// noise's own median so about a sixth of the biome stays untouched brown, and
	// its high end is inside the field's range so the wettest cores reach full
	// strength instead of asymptoting toward it.
	float bloom = smoothstep(0.36, 0.75, damp) * mix(0.30, 1.0, 1.0 - mottle);
	graded = mix(graded, damp_ground, bloom * forest_patina_reach * forest_weight);
	graded = max(graded, vec3(0.0));

	float luminance = dot(graded, vec3(0.2126, 0.7152, 0.0722));
	graded = mix(vec3(luminance), graded, saturation);
	graded = clamp((graded - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	graded = clamp(graded * exposure + vec3(black_lift), vec3(0.0), vec3(1.0));
	COLOR = vec4(graded, overlay_opacity);
}
