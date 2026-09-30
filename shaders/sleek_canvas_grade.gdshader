shader_type canvas_item;
// Deliberately blend_mix and not unshaded, for the reason CLAUDE.md 8 already
// records against toon_emissive_outline: an unshaded CanvasItem receives
// neither CanvasModulate nor any PointLight2D. Three families wear this
// material - ambient scenery, background decor, and wilderness accents - and
// under unshaded every one of them was exempt from the night transition. The
// measurement is unambiguous once the capture actually contains them: against a
// world darkening to a median ratio of 0.63, the share of pixels holding their
// full daylight value ran 5.28 percent in the forest camp, 6.71 in its
// composition shot and 10.00 in the west village, versus 0.27 percent in the
// open-wilderness frame where these families are sparse. Switching this file
// alone took those to 0.10, 2.17 and 8.44 - real, and visibly not the whole
// story, which is what sent the same audit to `sleek_sprite_finish`.
// Nothing here needs unshaded: this is a grading pass that writes COLOR and
// performs no lighting of its own, so the light pass composites over it.
render_mode blend_mix;

uniform vec4 cool_shadow : source_color = vec4(0.035, 0.085, 0.075, 1.0);
uniform vec4 warm_highlight : source_color = vec4(0.72, 0.48, 0.25, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.78;
uniform float contrast : hint_range(0.7, 1.5) = 1.08;
uniform float shadow_mix : hint_range(0.0, 0.4) = 0.08;
uniform float highlight_mix : hint_range(0.0, 0.3) = 0.045;

void fragment() {
	// Entry COLOR already carries texture(TEXTURE, UV) times modulate; the old
	// `texture(TEXTURE, UV) * COLOR` squared every texel and its alpha.
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luminance), source.rgb, saturation);
	graded = clamp((graded - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	graded = mix(graded, cool_shadow.rgb, (1.0 - smoothstep(0.08, 0.48, luminance)) * shadow_mix);
	graded += warm_highlight.rgb * smoothstep(0.58, 0.94, luminance) * highlight_mix;
	COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), source.a);
}
