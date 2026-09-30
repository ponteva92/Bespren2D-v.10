shader_type canvas_item;
render_mode unshaded;

uniform float mix_weight : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Entry COLOR already carries texture(TEXTURE, UV) times modulate; the old
	// `texture(TEXTURE, UV) * COLOR` squared every texel and its alpha.
	vec4 source = COLOR;
	vec3 flashed_rgb = mix(source.rgb, vec3(1.0), mix_weight);
	COLOR = vec4(flashed_rgb, source.a);
}

