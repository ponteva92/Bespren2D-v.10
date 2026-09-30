shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 energy_tint : source_color = vec4(1.0, 0.71, 0.18, 1.0);
uniform float pulse_speed : hint_range(0.0, 20.0) = 11.0;
uniform float emission : hint_range(0.0, 3.0) = 1.35;

void fragment() {
	// Entry COLOR already carries texture(TEXTURE, UV) times modulate; the old
	// `texture(TEXTURE, UV) * COLOR` squared every texel and its alpha.
	vec4 source = COLOR;
	float pulse = 0.84 + 0.16 * sin(TIME * pulse_speed);
	vec3 energy = source.rgb + energy_tint.rgb * source.a * emission * pulse;
	COLOR = vec4(energy, source.a);
}
