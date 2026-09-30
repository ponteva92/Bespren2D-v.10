shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 storm_tint : source_color = vec4(0.06, 0.15, 0.15, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.62;
uniform float wind : hint_range(-2.0, 2.0) = 0.46;

// Damage feedback rides in this same pass rather than in a second one. The
// mobile budget in CLAUDE.md 10 allows exactly one full-screen custom pass and
// says to combine atmosphere into this shader instead of stacking another, so
// the red edge wash a survivor sees when he is hit is a pair of uniforms here
// rather than an overlay of its own. It is edge-weighted on purpose: a wash
// over the middle of a 480x270 canvas would cover the survivor at the moment
// the player most needs to see where he is standing.
uniform vec4 damage_tint : source_color = vec4(0.78, 0.09, 0.07, 1.0);
uniform float damage : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(41.31, 289.17))) * 951.1357);
}

void fragment() {
	vec2 streak_uv = UV * vec2(92.0, 38.0);
	streak_uv.x += TIME * wind * 2.4 + streak_uv.y * 0.24;
	streak_uv.y += TIME * 9.0;
	vec2 cell = floor(streak_uv);
	vec2 local = fract(streak_uv);
	float seed = hash21(cell);
	float rain = step(0.91, seed) * smoothstep(0.11, 0.0, abs(local.x - seed)) * smoothstep(1.0, 0.18, local.y);
	vec2 ash_uv = UV * 29.0 + vec2(TIME * wind * 0.31, TIME * 0.38);
	float ash = step(0.965, hash21(floor(ash_uv))) * smoothstep(0.55, 0.0, length(fract(ash_uv) - 0.5));
	float vignette = smoothstep(0.38, 0.93, length(UV - 0.5));
	float alpha = clamp((rain * 0.42 + ash * 0.28 + vignette * 0.20) * intensity, 0.0, 0.72);
	vec3 color = mix(storm_tint.rgb, vec3(0.65, 0.76, 0.72), rain + ash * 0.5);
	// Tighter than the storm vignette above, so the two never read as the same
	// darkening: weather closes in slowly from the corners, a hit snaps a band
	// around the whole frame.
	float hurt = smoothstep(0.26, 0.72, length(UV - 0.5)) * damage;
	color = mix(color, damage_tint.rgb, clamp(hurt * 1.7, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha + hurt * 0.80, 0.0, 0.86));
}

