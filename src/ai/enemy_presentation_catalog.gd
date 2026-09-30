class_name EnemyPresentationCatalog
extends RefCounted
## Cached one-to-one presentation catalog for the eight stable EnemyAgent2D IDs.

const VARIANT_COUNT: int = 8

## The eight variants now read from one baked actor family: eight world-space
## headings per clip, rendered through a single camera, lighting rig and palette.
## That shared bake is what makes a goliath read as twice a walker without any
## per-variant scale saying so - the size difference is in the pixels, so the
## runtime applies one uniform scale and does not get a vote.
##
## For the same reason every visual_offset here is zero. Each baked scene pins
## its sprite to the projected world origin the bake recorded, so a nudge in this
## table would push a variant away from the marker ring and status arc drawn at
## that origin. copy_offsets stay, because a crawler pack fanning out around its
## anchor is composition.
##
## That origin is not the same point as the feet, and contact_offset is the gap.
## The bake camera looks down a three-quarter axis, so a limb reaching toward the
## lens projects below the pivot: measured against the sheets' own alpha over all
## eight headings and every idle frame, the contact ellipse drawn at the origin
## covered 2.4 percent of the crawler pack's foot pixels and 4.4 percent of the
## splitter's. The offsets below are the per-actor correction, and they have to
## be per-actor - scrap_bulwark measures 0.979 already and takes exactly zero.
##
## contact_radius is the other half of that ellipse and was wrong for a related
## reason: it used to come from marker_radius, which is the ring a variant's
## threat is announced through rather than a measurement of anything it stands
## on. Measured off the sheets over idle and walk, eight headings, every frame,
## the ratio of contact diameter to lower-body width ran from 1.00 on the
## goliath to 2.69 on the crawler pack - the goliath standing wider than its own
## shadow while a crawler wore one 2.7x its body, instanced once per copy. The
## values below are derived against the survivors, whose radius was itself
## settled on two independent denominators and a rendered sweep.
## Exactly 1.0, and that is the point rather than a coincidence. The bake used
## to frame every clip on the union of all of them, so a death pose lying flat
## set the cell and a walker's idle resolved from about twenty real pixels which
## this constant then doubled. Doubling the bake density instead and dividing
## here leaves every actor the same size on screen while the pixels behind it
## are real, and at 1.0 a texel lands on a logical pixel, so the nearest
## filtering these sprites ask for finally means what it says.
const ACTOR_SCALE: Vector2 = Vector2(1.0, 1.0)

const WALKER_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_walker.tscn"
)
const CRAWLER_PACK_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_rat_swarm.tscn"
)
const STATIC_WALKER_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_static_walker.tscn"
)
const SCRAP_SHIELD_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_scrap_shield.tscn"
)
const GOLIATH_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_goliath.tscn"
)
const CARRIER_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_carrier.tscn"
)
const SPLITTER_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_splitter.tscn"
)
const OVERLORD_SCENE: PackedScene = preload(
	"res://assets/2d/actors/scenes/enemy_overlord.tscn"
)

static var _definitions: Array[EnemyPresentationDefinition] = []


static func get_definition(variant_id: int) -> EnemyPresentationDefinition:
	_ensure_definitions()
	if variant_id < 0 or variant_id >= _definitions.size():
		return null
	return _definitions[variant_id]


static func get_all() -> Array[EnemyPresentationDefinition]:
	_ensure_definitions()
	return _definitions.duplicate()


static func get_variant_name(variant_id: int) -> StringName:
	var definition: EnemyPresentationDefinition = get_definition(variant_id)
	return definition.simulation_name if definition != null else &"unknown"


static func get_catalog_errors() -> PackedStringArray:
	_ensure_definitions()
	var errors: PackedStringArray = PackedStringArray()
	if _definitions.size() != VARIANT_COUNT:
		errors.append(
			"catalog contains %d entries instead of %d" % [_definitions.size(), VARIANT_COUNT]
		)
	for variant_id: int in range(_definitions.size()):
		var definition: EnemyPresentationDefinition = _definitions[variant_id]
		if definition == null:
			errors.append("catalog entry %d is null" % variant_id)
			continue
		var validation_error: String = definition.get_validation_error(variant_id)
		if not validation_error.is_empty():
			errors.append("%s: %s" % [definition.presentation_id, validation_error])
	return errors


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return
	_definitions = [
		EnemyPresentationDefinition.new(
			0,
			&"walker",
			&"toxic_brute",
			&"broad_shoulders",
			WALKER_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("e4ffbd"),
			Color("a7ff4f"),
			Color("304e32"),
			EnemyPresentationDefinition.MarkerKind.WALKER_BARS,
			21.0,
			3.0,
			11.5,
			&"idle",
			&"walk",
			1.0,
			0.9,
			6.2,
			false
		),
		EnemyPresentationDefinition.new(
			1,
			&"rat_swarm",
			&"infected_crawler_pack",
			&"three_low_crawlers",
			CRAWLER_PACK_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([
				Vector2(-10.0, 2.0),
				Vector2(10.0, 3.0),
				Vector2(0.0, -7.0),
			]),
			Color("ffd6a1"),
			Color("ff9d45"),
			Color("6f351d"),
			EnemyPresentationDefinition.MarkerKind.CRAWLER_PACK,
			20.0,
			8.0,
			5.0,
			&"idle",
			&"walk",
			1.35,
			1.2,
			9.4,
			false
		),
		EnemyPresentationDefinition.new(
			2,
			&"static_walker",
			&"static_conduit",
			&"forked_emp_prongs",
			STATIC_WALKER_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("b9f8ff"),
			Color("42e8ff"),
			Color("185d72"),
			EnemyPresentationDefinition.MarkerKind.STATIC_PRONGS,
			20.0,
			2.5,
			10.5,
			&"idle",
			&"walk",
			1.0,
			0.7,
			7.4,
			false
		),
		EnemyPresentationDefinition.new(
			3,
			&"scrap_shield",
			&"scrap_bulwark",
			&"armored_front_plate",
			SCRAP_SHIELD_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("e1edf2"),
			Color("a7c4d8"),
			Color("40576a"),
			EnemyPresentationDefinition.MarkerKind.SHIELD_ARC,
			27.0,
			0.0,
			11.0,
			&"idle",
			&"walk",
			1.0,
			0.45,
			4.8,
			false
		),
		EnemyPresentationDefinition.new(
			4,
			&"goliath",
			&"runic_goliath",
			&"towering_rune_horns",
			GOLIATH_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("ffd0ad"),
			Color("ff7b42"),
			Color("702c28"),
			EnemyPresentationDefinition.MarkerKind.GOLIATH_RUNES,
			36.0,
			4.5,
			24.0,
			&"idle",
			&"walk",
			0.8,
			0.65,
			3.4,
			true
		),
		EnemyPresentationDefinition.new(
			5,
			&"carrier",
			&"plague_carrier",
			&"wide_orbiting_carapace",
			CARRIER_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("e0d5ff"),
			Color("b892ff"),
			Color("4a327a"),
			EnemyPresentationDefinition.MarkerKind.CARRIER_ORBITS,
			37.0,
			11.5,
			13.0,
			&"idle",
			&"walk",
			0.9,
			1.1,
			4.2,
			true
		),
		EnemyPresentationDefinition.new(
			6,
			&"splitter",
			&"blood_splitter",
			&"paired_feral_echoes",
			SPLITTER_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("ffc0cc"),
			Color("ff4f75"),
			Color("741f3a"),
			EnemyPresentationDefinition.MarkerKind.SPLITTER_TWINS,
			34.0,
			11.5,
			11.5,
			&"idle",
			&"walk",
			1.05,
			1.0,
			5.6,
			true
		),
		EnemyPresentationDefinition.new(
			7,
			&"overlord",
			&"undead_overlord",
			&"crowned_royal_mass",
			OVERLORD_SCENE,
			ACTOR_SCALE,
			Vector2.ZERO,
			PackedVector2Array([Vector2.ZERO]),
			Color("fff0bd"),
			Color("ffd45a"),
			Color("713d9b"),
			EnemyPresentationDefinition.MarkerKind.OVERLORD_CROWN,
			38.0,
			8.0,
			22.5,
			&"idle",
			&"walk",
			0.85,
			0.7,
			3.0,
			true
		),
	]
