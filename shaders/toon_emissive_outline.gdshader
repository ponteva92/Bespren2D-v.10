shader_type canvas_item;
// Deliberately NOT unshaded. Every item drawn with this shader - the refuge,
// the three resource nodes, both survivors - is a physical thing standing in
// the world, and an unshaded canvas item receives neither CanvasModulate nor a
// PointLight2D. That exempted all six from the night transition in
// night_atmosphere_2d.gd, so the world fell to the blue hour around them while
// they stayed at full daylight value: the camp became a lit decal pasted on a
// dark map, and the resource nodes stayed fully saturated after dusk. It also
// meant the Base Core's own AmberLight lit the ground it stood on but never the
// camp itself, which is why the refuge could only ever be brightened by piling
// on flat additive terms. terrain_material_validation.gd already asserts this
// same property for the ground - "Terrain remains responsive to CanvasModulate
// and local camp lights" - and there is no reason the things standing on that
// ground should obey a different rule.
render_mode blend_mix;

// This file was the fifth and last instance of the defect CLAUDE.md 8 records
// for `sleek_sprite_finish`: the taps stepped by `TEXTURE_PIXEL_SIZE`, so the
// authored width was a source texel and what reached a player was that width
// times the sprite's scale times the camera zoom. The ratio here was mild next
// to the sprite shader's 21.6x - 4.4x across the three wearers - but the
// absolute values are the finding, because every one of them was under a pixel
// at the 0.38 gameplay zoom: the refuge 0.77, a resource node 0.38, and the
// legacy survivor scenes 0.17. A four-tap outline below one pixel is not a
// thin contour, it is nearly no contour at all, because the taps land inside
// the sprite's own alpha and `neighbor_alpha - source.a` goes to zero along
// most of the boundary. CLAUDE.md 1 calls the refuge the emotional centre of
// the game and it was the object drawing three quarters of a pixel of edge.
//
// The pulse was the reason this was held back from the same fix, and measuring
// it retired the objection: `0.9 + pulse * 0.1` over a pulse of 0.52 to 1.00
// is a width multiplier of 0.952 to 1.000, a five percent wobble that no one
// can see. What actually pulses on this material is the emission and the
// outline's alpha, both of which are untouched here.
const float LOGICAL_VIEWPORT_WIDTH = 480.0;

uniform vec4 outline_color : source_color = vec4(0.008, 0.012, 0.012, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
// Screen pixels of contour in the 480-wide logical canvas, not atlas texels.
uniform float outline_width : hint_range(0.0, 5.0) = 1.6;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.55;
// The emission is gated on the source's own luminance and composited as a
// screen rather than added flat, and both halves of that are load bearing.
// See the fragment for why.
uniform float emission_gate_low : hint_range(0.0, 1.0) = 0.25;
uniform float emission_gate_high : hint_range(0.0, 1.0) = 0.75;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	float pulse = 0.76 + 0.24 * sin(TIME * pulse_speed);
	float animated_outline_width = outline_width * (0.9 + pulse * 0.1);
	// fwidth(UV) is how far UV moves across one rendered fragment, so the tap
	// lands one screen pixel out whatever the sprite's scale; the stretch term
	// converts rendered fragments back into the logical canvas, without which
	// the ring would thin to a quarter of its weight on a 1080p panel.
	float stretch = (1.0 / SCREEN_PIXEL_SIZE.x) / LOGICAL_VIEWPORT_WIDTH;
	vec2 offset = fwidth(UV) * animated_outline_width * stretch;
	// Entry COLOR already carries texture(TEXTURE, UV) times modulate, so
	// multiplying the fetch back in squared every texel and its alpha. Measured
	// on the GPU rather than assumed: `COLOR = texture(TEXTURE, UV)` is byte-
	// identical to no material, and the product is the per-channel square.
	vec4 source = COLOR;
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV + vec2(offset.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV - vec2(offset.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV + vec2(0.0, offset.y), vec2(0.0), vec2(1.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, clamp(UV - vec2(0.0, offset.y), vec2(0.0), vec2(1.0))).a);
	float outline_alpha = max(neighbor_alpha - source.a, 0.0);
	// This term used to be a flat add: `source.rgb + glow * strength * pulse *
	// source.a`. On an opaque body source.a is 1.0, so it added a constant to
	// every pixel rather than lighting a core, and the 8-bit target then clipped
	// whatever went past the ceiling. Converted to what each wearer actually
	// added at peak pulse that is +122/+103/+0 on Wood, +94 flat on Metal and
	// +0/+163/+163 on Tech - 64 percent of the whole range, so any Tech source
	// pixel above 92 in G or B clipped. Measured on the masters at delivered
	// size the damage was at the dark end rather than the bright one: 21.7, 26.0
	// and 24.6 percent of the three node bodies sit below the Void charcoal luma
	// of 8.4 as authored - those are the cavities and the outer shell - and the
	// flat add left 0.0 percent below it on all three, with the darkest surviving
	// pixel at 60.8, 54.3 and 71.5. It also inverted CLAUDE.md 8 outright: the
	// share of a body above luma 200 went 19.4 to 45.1 on Metal and 5.8 to 44.0
	// on Tech while the refuge went 1.1 to 2.4, so the nodes carried high-value
	// islands 7x to 19x the refuge's share of its own body.
	//
	// The gate makes it an emissive core: smoothstep on the source luminance so
	// cavities receive nothing and lit features receive it in full. The screen
	// makes it bounded: it cannot exceed 1.0, so it rolls off instead of
	// clipping, and because it never lifts a channel the glow colour leaves at
	// zero it pushes lit pixels toward the wearer's own locked anchor rather
	// than toward white. Both are branch-free and loop-free per CLAUDE.md 10.
	vec3 base = clamp(source.rgb, vec3(0.0), vec3(1.0));
	float source_luminance = dot(base, vec3(0.299, 0.587, 0.114));
	float emissive_core = smoothstep(
		emission_gate_low,
		max(emission_gate_low + 0.001, emission_gate_high),
		source_luminance
	);
	vec3 emissive = clamp(
		glow_color.rgb * emission_strength * pulse * emissive_core * source.a,
		vec3(0.0),
		vec3(1.0)
	);
	vec3 luminous = 1.0 - (1.0 - base) * (1.0 - emissive);
	vec4 fill = vec4(luminous, source.a);
	float animated_outline_alpha = outline_alpha * outline_color.a * (0.78 + pulse * 0.22);
	COLOR = mix(vec4(outline_color.rgb, animated_outline_alpha), fill, source.a);
}
