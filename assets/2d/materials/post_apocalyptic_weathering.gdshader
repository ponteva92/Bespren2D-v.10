shader_type canvas_item;
render_mode unshaded;

uniform int treatment : hint_enum("Rust","Decayed Wood","Oxidized Copper","Toxic Mutation") = 0;
uniform float weathering : hint_range(0.0, 1.0) = 0.78;
uniform float structural_damage : hint_range(0.0, 1.0) = 0.0;
uniform float rust_streaks : hint_range(0.0, 1.0) = 0.45;
uniform float toxic_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.843, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.25;
uniform float pattern_scale : hint_range(4.0, 96.0) = 28.0;
uniform float damage_seed : hint_range(0.0, 64.0) = 7.0;

float hash21(vec2 point) {
	vec3 p3 = fract(vec3(point.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	if (source.a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 seeded_uv = UV + vec2(damage_seed * 0.071, damage_seed * 0.113);
		float coarse = value_noise(seeded_uv * pattern_scale);
		float fine = value_noise(seeded_uv * pattern_scale * 3.17);
		float erosion = smoothstep(0.43, 0.82, coarse * 0.72 + fine * 0.28) * weathering;
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		vec3 treated = source.rgb;

		if (treatment == 0) {
			vec3 rust_shadow = vec3(0.105, 0.025, 0.010);
			vec3 rust_bloom = vec3(0.79, 0.165, 0.018);
			treated = mix(source.rgb, mix(rust_shadow, rust_bloom, fine), erosion * 0.86);
		} else if (treatment == 1) {
			float grain = 0.5 + 0.5 * sin((UV.x + coarse * 0.08) * 112.0);
			vec3 rot = mix(vec3(0.055, 0.021, 0.009), vec3(0.34, 0.14, 0.028), grain);
			treated = mix(source.rgb, rot, clamp(erosion + (1.0 - grain) * 0.14, 0.0, 1.0));
		} else if (treatment == 2) {
			vec3 verdigris_dark = vec3(0.018, 0.145, 0.135);
			vec3 verdigris_light = vec3(0.08, 0.63, 0.49);
			treated = mix(source.rgb, mix(verdigris_dark, verdigris_light, fine), erosion * 0.82);
		} else {
			vec3 necrotic = mix(vec3(0.075, 0.058, 0.055), vec3(0.31, 0.46, 0.055), fine);
			treated = mix(source.rgb, necrotic, erosion * 0.64);
		}

		float vertical_run = smoothstep(0.48, 0.88, value_noise(vec2(UV.x * pattern_scale * 0.72, damage_seed)));
		float streak_falloff = smoothstep(0.0, 0.88, UV.y);
		float streak_mask = vertical_run * streak_falloff * rust_streaks * weathering;
		treated = mix(treated, treated * vec3(0.43, 0.27, 0.18), streak_mask);

		vec2 window_grid = abs(fract(UV * vec2(9.0, 7.0) + damage_seed * 0.013) - 0.5);
		float window_shape = step(window_grid.x, 0.31) * step(window_grid.y, 0.30);
		float dark_window = 1.0 - smoothstep(0.09, 0.31, luminance);
		float fracture = smoothstep(0.54, 0.91, coarse * 0.66 + fine * 0.34);
		float blown_window = window_shape * dark_window * fracture * structural_damage;
		float edge_chip = smoothstep(0.71, 0.96, fine) * structural_damage * 0.72;
		float surviving_alpha = source.a * (1.0 - clamp(blown_window + edge_chip, 0.0, 0.94));

		float highlight = smoothstep(0.56, 0.96, max(max(source.r, source.g), source.b));
		float spore_cluster = smoothstep(0.66, 0.93, value_noise(seeded_uv * pattern_scale * 1.93));
		float toxic_cluster = smoothstep(0.58, 0.91, fine) * toxic_intensity;
		float glow_mask = clamp(highlight * 0.56 + spore_cluster * 0.42 + toxic_cluster * 0.55, 0.0, 1.0);
		vec3 emitted = glow_color.rgb * glow_mask * emission_strength;

		float soot_edge = 1.0 - smoothstep(0.0, 0.075, min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y)));
		treated *= 1.0 - soot_edge * weathering * 0.24;
		COLOR = vec4(treated + emitted, surviving_alpha);
	}
}
