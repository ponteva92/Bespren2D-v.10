shader_type canvas_item;
// blend_mix, not unshaded, and this file is the reason the rule in CLAUDE.md 8
// needed a second application. Fixing `sleek_canvas_grade` closed the night
// exemption in the frames whose subject was scenery, decor or a wilderness
// accent - the forest camp fell from 5.28 percent of pixels holding full
// daylight value to 0.10 and its composition shot from 6.71 to 2.17 - but the
// city barrier came back byte-identical at 7.46 percent and the west village
// barely moved, 10.00 to 8.44. Byte-identical is the whole diagnosis: that
// frame contains no pixel of the other material, so its exempt population was
// always a different subject. Mapped, it is one centred blob of day rgb
// (110, 85, 63) - the concrete roadblock itself. This material dresses
// `WorldObstacle2D` and `PlacedStructure2D`, so under unshaded every rock,
// tree, shell, house, fence, wreck, district fitting and player-built tower in
// the game held full daylight value while the ground and the survivors fell to
// the blue hour. Switching it took the city barrier and the west village to
// exactly zero exempt pixels and the other three live pairs to 161, 67 and 8,
// all of which are the refuge's own additive amber - day rgb (85, 67, 2) and
// (118, 95, 21) - which is `blend_add` glow and is meant to hold. Daylight is
// untouched: mean frame luma matches the previous capture to two decimals in
// all five, because with no CanvasModulate the light pass composites the base
// draw unchanged. Nothing here needs unshaded either: the pass grades the
// source and draws a silhouette from neighbour alpha, performs no lighting of
// its own, and composites correctly under the light pass.
render_mode blend_mix;

// The outline taps used to step by `TEXTURE_PIXEL_SIZE * outline_width`, which
// is one source texel of UV, so what a player actually saw was outline_width
// multiplied by the sprite's own scale and by the camera zoom. One authored
// constant therefore drew a different contour on every subject: measured over
// the twenty-three shipped subjects at the 0.38 gameplay zoom, the 1.6 below
// delivered 0.13 screen pixels on a placed trap and 2.83 on a district urban
// block - a 21.6x range - and it was thinnest on the things the player builds.
// A contour weight is a screen quantity by definition; authoring it in texels
// authored it in a unit nobody sees.
//
// The alternative was a material per quantised scale band, and it was rejected
// for being N things to keep correct rather than one. It re-breaks the moment
// any scale moves, and it cannot express a scale chosen at runtime, which
// `PlacedStructure2D` does three different ways. `fwidth` costs one derivative
// instruction and no new materials, and `SCREEN_PIXEL_SIZE` is available to a
// canvas_item fragment shader without any screen texture being sampled, so
// CLAUDE.md 10's single-full-screen-pass budget is untouched.
//
// Verified on delivered pixels rather than on the algebra, since the defect is
// precisely that the authored number and the delivered one differ: horizontal
// dark-run short-means are 1.75 to 2.23 across the eight structures against
// 1.40 to 1.71 across the world props, where before the structures carried
// 0.14 to 0.19 screen pixels against the world's 0.9 to 2.83.
//
// One method note for anyone measuring this material, because it cost two
// broken estimators: the ring below is composited *outside* the source alpha
// and is never graded, so it holds one fixed luma of 6.16. A body mask taken
// from the composited alpha is therefore measuring the contour, and at
// delivered size the contour is a large share of the sprite. Downsample the
// source alpha through the same filter as the colour and threshold that.

uniform vec4 outline_color : source_color = vec4(0.018, 0.026, 0.024, 0.94);
uniform vec4 accent_color : source_color = vec4(0.48, 0.78, 0.68, 1.0);
uniform vec4 cool_shadow : source_color = vec4(0.055, 0.11, 0.105, 1.0);
// The logical viewport width CLAUDE.md 11 locks at 480x270. It is a constant
// here rather than a uniform because a shader that had to be told the project
// setting could be told the wrong one.
const float LOGICAL_VIEWPORT_WIDTH = 480.0;

// Screen pixels of contour, in the 480-wide logical canvas, not atlas texels.
uniform float outline_width : hint_range(0.0, 4.0) = 1.6;
uniform float saturation : hint_range(0.0, 1.5) = 0.82;
uniform float contrast : hint_range(0.7, 1.5) = 1.09;
uniform float shadow_tint : hint_range(0.0, 0.5) = 0.12;
uniform float shadow_lift : hint_range(0.0, 0.25) = 0.07;
uniform float accent_strength : hint_range(0.0, 0.5) = 0.10;
uniform float sheen_strength : hint_range(0.0, 0.35) = 0.055;
uniform float palette_cohesion : hint_range(0.0, 0.25) = 0.08;

void fragment() {
	// Entry COLOR already carries texture(TEXTURE, UV) times modulate; the old
	// `texture(TEXTURE, UV) * COLOR` squared every texel and its alpha, so every
	// prop wearing this finish shipped gamma-2 darkened before any grade ran.
	vec4 source = COLOR;
	// One logical pixel of contour is one logical pixel at every scale in the
	// cast, which is the whole point of the header note above. fwidth(UV) is how
	// far UV travels across one rendered fragment, so it converts a screen
	// quantity into the texel space the taps need; the stretch term converts
	// rendered fragments back into the 480-wide logical canvas CLAUDE.md 11
	// locks, so the ring holds its weight on a dense panel instead of thinning
	// to a quarter of it the way a raw fwidth would.
	float stretch = (1.0 / SCREEN_PIXEL_SIZE.x) / LOGICAL_VIEWPORT_WIDTH;
	vec2 offset = fwidth(UV) * outline_width * stretch;
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV + vec2(offset.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV - vec2(offset.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV + vec2(0.0, offset.y), vec2(0.0), vec2(1.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV - vec2(0.0, offset.y), vec2(0.0), vec2(1.0))).a);
	float outline_alpha = max(neighbor_alpha - source.a, 0.0) * outline_color.a;

	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luminance), source.rgb, saturation);
	graded = clamp((graded - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	float shadow_mask = (1.0 - smoothstep(0.12, 0.54, luminance)) * shadow_tint;
	graded = mix(graded, cool_shadow.rgb, shadow_mask);
	float lift_mask = (1.0 - smoothstep(0.04, 0.38, luminance)) * source.a;
	graded += vec3(0.80, 0.86, 0.82) * shadow_lift * lift_mask;
	float highlight_mask = smoothstep(0.52, 0.96, luminance) * accent_strength;
	graded += accent_color.rgb * highlight_mask;
	float diagonal_sheen = 1.0 - smoothstep(0.0, 0.19, abs(UV.x + UV.y - 0.74));
	graded += accent_color.rgb * diagonal_sheen * sheen_strength * source.a;
	// A restrained two-anchor grade makes photographic and illustrated sources
	// share one visual world without mobile-unfriendly extra texture sampling.
	vec3 palette_anchor = mix(
		cool_shadow.rgb,
		accent_color.rgb,
		smoothstep(0.16, 0.84, luminance)
	);
	graded = mix(graded, palette_anchor, palette_cohesion * source.a);

	vec4 fill = vec4(clamp(graded, vec3(0.0), vec3(1.0)), source.a);
	COLOR = mix(vec4(outline_color.rgb, outline_alpha), fill, source.a);
}
