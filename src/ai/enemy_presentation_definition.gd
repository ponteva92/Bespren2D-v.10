class_name EnemyPresentationDefinition
extends RefCounted
## Immutable catalog entry that maps one stable simulation variant to local 2D presentation.

enum MarkerKind {
	WALKER_BARS,
	CRAWLER_PACK,
	STATIC_PRONGS,
	SHIELD_ARC,
	GOLIATH_RUNES,
	CARRIER_ORBITS,
	SPLITTER_TWINS,
	OVERLORD_CROWN,
}

var variant_id: int
var simulation_name: StringName
var presentation_id: StringName
var silhouette_tag: StringName
var visual_scene: PackedScene
var visual_scale: Vector2
var visual_offset: Vector2
var copy_offsets: PackedVector2Array
var body_tint: Color
var accent_color: Color
var secondary_color: Color
var marker_kind: MarkerKind
var marker_radius: float
## Distance from the projected world origin down to the point the actor's
## pixels actually touch the ground, in sprite-sheet pixels, which at
## EnemyPresentationCatalog.ACTOR_SCALE are also screen pixels. The baked
## scenes pin their sprite to the origin the bake camera projected, and in a
## three-quarter view a limb reaching toward the lens projects below that
## origin - so the contact ellipse belongs at the feet rather than at the
## pivot. Derived per actor by sweeping this offset against the sheet's own
## alpha over every heading and every idle frame; see CLAUDE.md 7.
var contact_offset: float
## Half-width of the contact ellipse, in sprite-sheet pixels, measured from
## the silhouette rather than borrowed from the marker ring. marker_radius is
## a readability affordance authored per marker language - bars, prongs, arcs,
## runes, orbits, a crown - and it has no reason to track a stance. Taking the
## footprint from it spread the ratio of contact diameter to lower-body width
## across the cast from 1.00 to 2.69: the goliath's ellipse was narrower than
## its own stance while the crawler's was 2.7x its whole lower body, drawn
## three times over. Derived per actor off the sheets; see CLAUDE.md 7.
var contact_radius: float
var idle_animation: StringName
var move_animation: StringName
var animation_speed_scale: float
var bob_amplitude: float
var bob_frequency: float
var boss_presentation: bool


func _init(
	p_variant_id: int,
	p_simulation_name: StringName,
	p_presentation_id: StringName,
	p_silhouette_tag: StringName,
	p_visual_scene: PackedScene,
	p_visual_scale: Vector2,
	p_visual_offset: Vector2,
	p_copy_offsets: PackedVector2Array,
	p_body_tint: Color,
	p_accent_color: Color,
	p_secondary_color: Color,
	p_marker_kind: MarkerKind,
	p_marker_radius: float,
	p_contact_offset: float,
	p_contact_radius: float,
	p_idle_animation: StringName,
	p_move_animation: StringName,
	p_animation_speed_scale: float,
	p_bob_amplitude: float,
	p_bob_frequency: float,
	p_boss_presentation: bool
) -> void:
	variant_id = p_variant_id
	simulation_name = p_simulation_name
	presentation_id = p_presentation_id
	silhouette_tag = p_silhouette_tag
	visual_scene = p_visual_scene
	visual_scale = p_visual_scale
	visual_offset = p_visual_offset
	copy_offsets = p_copy_offsets.duplicate()
	body_tint = p_body_tint
	accent_color = p_accent_color
	secondary_color = p_secondary_color
	marker_kind = p_marker_kind
	marker_radius = p_marker_radius
	contact_offset = p_contact_offset
	contact_radius = p_contact_radius
	idle_animation = p_idle_animation
	move_animation = p_move_animation
	animation_speed_scale = p_animation_speed_scale
	bob_amplitude = p_bob_amplitude
	bob_frequency = p_bob_frequency
	boss_presentation = p_boss_presentation


func get_validation_error(expected_variant_id: int) -> String:
	if variant_id != expected_variant_id:
		return "variant_id %d does not match catalog index %d" % [variant_id, expected_variant_id]
	if simulation_name.is_empty() or presentation_id.is_empty() or silhouette_tag.is_empty():
		return "identity fields must not be empty"
	if visual_scene == null:
		return "visual_scene is missing"
	if (
		not visual_scale.is_finite()
		or visual_scale.x <= 0.0
		or visual_scale.y <= 0.0
		or not visual_offset.is_finite()
	):
		return "visual transform must be finite and positive"
	if copy_offsets.is_empty():
		return "at least one visual copy offset is required"
	for copy_offset: Vector2 in copy_offsets:
		if not copy_offset.is_finite():
			return "copy offsets must be finite"
	if marker_radius <= 0.0 or not is_finite(marker_radius):
		return "marker radius must be finite and positive"
	if contact_offset < 0.0 or not is_finite(contact_offset):
		return "contact offset must be finite and non-negative"
	if contact_radius <= 0.0 or not is_finite(contact_radius):
		return "contact radius must be finite and positive"
	if animation_speed_scale < 0.0 or not is_finite(animation_speed_scale):
		return "animation speed must be finite and non-negative"
	if bob_amplitude < 0.0 or bob_frequency < 0.0:
		return "bob tuning must be non-negative"
	if not is_finite(bob_amplitude) or not is_finite(bob_frequency):
		return "bob tuning must be finite"
	return ""
