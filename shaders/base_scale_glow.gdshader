shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.52, 0.06, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 1.25;
uniform float scale_amount : hint_range(0.0, 0.15) = 0.045;
uniform float pulse_phase : hint_range(0.0, 6.28318) = 0.0;

void vertex() {
	float pulse = 0.5 + 0.5 * sin(pulse_phase);
	VERTEX *= 1.0 + scale_amount * pulse;
}

void fragment() {
	// Entry COLOR.a already carries the texture's alpha times modulate; the old
	// `texture(TEXTURE, UV).a * COLOR.a` squared it along the glow's soft edge.
	float source_alpha = COLOR.a;
	float pulse = 0.72 + 0.28 * sin(pulse_phase);
	COLOR = vec4(glow_color.rgb * glow_strength * pulse * source_alpha, source_alpha * 0.62);
}
