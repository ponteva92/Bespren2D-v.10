shader_type canvas_item;

uniform int surface_mode : hint_enum("Rust","Decayed Wood","Oxidized Copper") = 0;
uniform float weathering : hint_range(0.0, 1.0) = 0.44;
uniform float texture_scale : hint_range(2.0, 64.0) = 22.0;
uniform vec4 cool_shadow : source_color = vec4(0.025, 0.075, 0.068, 1.0);
uniform vec4 warm_highlight : source_color = vec4(0.62, 0.43, 0.24, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.74;
uniform float contrast : hint_range(0.7, 1.5) = 1.06;
uniform float material_sheen : hint_range(0.0, 0.25) = 0.038;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
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
	// Entry COLOR already carries texture(TEXTURE, UV) times modulate; the old
	// `texture(TEXTURE, UV) * COLOR` squared every texel and its alpha.
	vec4 source = COLOR;
	float coarse = value_noise(UV * texture_scale);
	float fine = value_noise(UV * texture_scale * 3.7);
	// Keep damage in restrained islands. Large high-chroma noise reads as cheap
	// at 480x270, while this tighter mask leaves the authored material dominant.
	float mask = smoothstep(0.54, 0.84, coarse * 0.72 + fine * 0.28) * weathering;
	vec3 treated = source.rgb;
	if (surface_mode == 0) {
		vec3 rust_dark = vec3(0.14, 0.060, 0.028);
		vec3 rust_bloom = vec3(0.46, 0.18, 0.065);
		treated = mix(source.rgb, mix(rust_dark, rust_bloom, fine), mask);
	} else if (surface_mode == 1) {
		float grain = abs(sin((UV.x + coarse * 0.14) * 76.0));
		vec3 rot = mix(vec3(0.075, 0.041, 0.024), vec3(0.31, 0.17, 0.075), grain);
		treated = mix(source.rgb, rot, clamp(mask + (1.0 - grain) * 0.10, 0.0, 1.0));
	} else {
		vec3 patina = mix(vec3(0.025, 0.19, 0.17), vec3(0.11, 0.51, 0.42), fine);
		treated = mix(source.rgb, patina, mask);
	}
	float edge_distance = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
	float edge_soot = 1.0 - smoothstep(0.0, 0.52, edge_distance);
	treated = mix(treated, treated * 0.48, edge_soot * 0.18);
	float luminance = dot(treated, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luminance), treated, saturation);
	graded = clamp((graded - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	graded = mix(graded, cool_shadow.rgb, (1.0 - smoothstep(0.1, 0.52, luminance)) * 0.065);
	float sheen = smoothstep(0.58, 0.94, luminance) * material_sheen;
	graded += warm_highlight.rgb * sheen;
	COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), source.a);
}
