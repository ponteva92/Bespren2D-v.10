class_name StructureCatalog
extends RefCounted
## Canonical eight-card Tier-1 build catalog.

const KINETIC_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_kinetic.png")
const CHEMICAL_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_chemical.png")
const ELECTRIC_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_electric.png")
const SUPPORT_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_support.png")
const BARRICADE_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_barricade.png")
const LANDMINE_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_landmine.png")
const SLOWING_PIT_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_slowing_pit.png")
const RAZOR_SNARE_TEXTURE: Texture2D = preload(
	"res://assets/2d/structures/structure_t1_razor_snare.png"
)

const T1_KINETIC: StringName = &"t1_kinetic"
const T1_CHEMICAL: StringName = &"t1_chemical"
const T1_ELECTRIC: StringName = &"t1_electric"
const T1_SUPPORT: StringName = &"t1_support"
const T1_BARRICADE: StringName = &"t1_barricade"
const T1_LANDMINE: StringName = &"t1_landmine"
const T1_SLOWING_PIT: StringName = &"t1_slowing_pit"
const T1_RAZOR_SNARE: StringName = &"t1_razor_snare"

const CARD_IDS: Array[StringName] = [
	T1_KINETIC,
	T1_CHEMICAL,
	T1_ELECTRIC,
	T1_SUPPORT,
	T1_BARRICADE,
	T1_LANDMINE,
	T1_SLOWING_PIT,
	T1_RAZOR_SNARE,
]

static var _definitions: Array[StructureDefinition] = []


static func get_all() -> Array[StructureDefinition]:
	_ensure_catalog()
	return _definitions.duplicate()


static func get_definition(structure_id: StringName) -> StructureDefinition:
	_ensure_catalog()
	for definition: StructureDefinition in _definitions:
		if definition.structure_id == structure_id:
			return definition
	return null


static func has_structure(structure_id: StringName) -> bool:
	return get_definition(structure_id) != null


static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	_definitions = [
		StructureDefinition.new().configure(
			T1_KINETIC,
			"T1 Kinetic",
			"Direct-fire sentry",
			"Tracks the nearest zombie and fires armor-piercing scrap bolts. Reliable single-target pressure with no status effect.",
			"DMG 18  |  RATE 1.7/s  |  RANGE 360",
			PackedInt32Array([18, 22, 4]),
			Vector2i.ONE,
			Color("d89b4d"),
			180,
			TowerCombatProfile.new().configure(
				TowerCombatProfile.AttackKind.KINETIC,
				TowerCombatProfile.TargetingMode.NEAREST,
				360.0,
				18,
				1.0 / 1.7
			),
			StructureDefinition.Category.TOWER,
			KINETIC_TEXTURE.resource_path,
			true
		),
		StructureDefinition.new().configure(
			T1_CHEMICAL,
			"T1 Chemical",
			"Corrosive area denial",
			"Lobs corrosive canisters that burst across clustered zombies at the impact point.",
			"DMG 9  |  TARGET 300  |  BURST 84",
			PackedInt32Array([8, 14, 16]),
			Vector2i.ONE,
			Color("7fa56a"),
			150,
			TowerCombatProfile.new().configure(
				TowerCombatProfile.AttackKind.CHEMICAL,
				TowerCombatProfile.TargetingMode.NEAREST,
				300.0,
				9,
				1.0,
				84.0
			),
			StructureDefinition.Category.TOWER,
			CHEMICAL_TEXTURE.resource_path,
			true
		),
		StructureDefinition.new().configure(
			T1_ELECTRIC,
			"T1 Electric",
			"Chain-control coil",
			"Arcs through up to three nearby zombies, applying direct damage to each chained target.",
			"DMG 12  |  CHAINS 3  |  RANGE 280",
			PackedInt32Array([6, 20, 22]),
			Vector2i.ONE,
			Color("5ab4bc"),
			140,
			TowerCombatProfile.new().configure(
				TowerCombatProfile.AttackKind.ELECTRIC,
				TowerCombatProfile.TargetingMode.NEAREST,
				280.0,
				12,
				0.85,
				0.0,
				108.0,
				3
			),
			StructureDefinition.Category.TOWER,
			ELECTRIC_TEXTURE.resource_path,
			true
		),
		StructureDefinition.new().configure(
			T1_SUPPORT,
			"T1 Support",
			"Field maintenance rig",
			"Repairs nearby defenses and improves their target acquisition. It does not attack on its own.",
			"REPAIR 6/s  |  RANGE 224  |  SCAN +12%",
			PackedInt32Array([20, 10, 12]),
			Vector2i.ONE,
			Color("77a99a"),
			170,
			null,
			StructureDefinition.Category.UTILITY,
			SUPPORT_TEXTURE.resource_path,
			true
		),
		StructureDefinition.new().configure(
			T1_BARRICADE,
			"T1 Barricade",
			"Two-cell path blocker",
			"A reinforced timber wall that redirects ground zombies and buys time. It has no attack.",
			"HP 420  |  ARMOR 4  |  FOOTPRINT 2x1",
			PackedInt32Array([26, 4, 0]),
			Vector2i(2, 1),
			Color("9b6843"),
			420,
			null,
			StructureDefinition.Category.UTILITY,
			BARRICADE_TEXTURE.resource_path,
			true
		),
		StructureDefinition.new().configure(
			T1_LANDMINE,
			"T1 Landmine",
			"Single-use blast trap",
			"Detonates when the first zombie enters its trigger cell, dealing heavy radial damage before being consumed.",
			"DMG 95  |  TRIGGER 56  |  BLAST 112",
			PackedInt32Array([8, 12, 4]),
			Vector2i.ONE,
			Color("c65b44"),
			40,
			TowerCombatProfile.new().configure(
				TowerCombatProfile.AttackKind.LANDMINE,
				TowerCombatProfile.TargetingMode.NEAREST,
				56.0,
				95,
				0.0,
				112.0,
				0.0,
				1,
				true
			),
			StructureDefinition.Category.TRAP,
			LANDMINE_TEXTURE.resource_path,
			false
		),
		StructureDefinition.new().configure(
			T1_SLOWING_PIT,
			"T1 Slowing Pit",
			"Persistent movement trap",
			"A camouflaged scrap pit that slows every ground zombie crossing its cell without being consumed.",
			"SLOW 38%  |  RANGE 72  |  PERSISTENT",
			PackedInt32Array([18, 0, 5]),
			Vector2i.ONE,
			Color("8f8064"),
			90,
			TowerCombatProfile.new().configure(
				TowerCombatProfile.AttackKind.SLOWING_PIT,
				TowerCombatProfile.TargetingMode.NEAREST,
				72.0,
				0,
				0.20,
				0.0,
				0.0,
				8,
				false,
				0.62,
				0.32
			),
			StructureDefinition.Category.TRAP,
			SLOWING_PIT_TEXTURE.resource_path,
			false
		),
		StructureDefinition.new().configure(
			T1_RAZOR_SNARE,
			"T1 Razor Snare",
			"Reusable root trap",
			"Snaps razor jaws around one zombie, dealing damage and briefly rooting it before rearming.",
			"DMG 34  |  ROOT 0.45s  |  REARM 1.25s",
			PackedInt32Array([12, 18, 8]),
			Vector2i.ONE,
			Color("d86a9d"),
			75,
			TowerCombatProfile.new().configure(
				TowerCombatProfile.AttackKind.RAZOR_SNARE,
				TowerCombatProfile.TargetingMode.NEAREST,
				64.0,
				34,
				1.25,
				0.0,
				0.0,
				1,
				false,
				0.0,
				0.45
			),
			StructureDefinition.Category.TRAP,
			RAZOR_SNARE_TEXTURE.resource_path,
			false
		),
	]
