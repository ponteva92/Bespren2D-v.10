extends Node2D
## Artifact-only V3 ecology probe.  It builds four original/provenance-safe
## low-profile ground families in an isolated test scene, uses the actual
## WorldMap2D only as a visual substrate, and never writes a decor value,
## collision, flow field, authority state, export dependency, or map scene.
##
## V2's repeated dark pebble token is deliberately not reused.  The card set
## is: irregular lichen, needle/leaf litter, fallen twig, and one small bare
## approved-atlas pebble.  Every route card contains all four families.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const WILD_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
)

const OUTPUT_DIRECTORY: String = "res://artifacts/wilderness_ecology_route_validation"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/wilderness_ecology_route_validation.json"
const DAY_SHEET_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/day_route_sheet.png"
const NIGHT_SHEET_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/night_route_sheet.png"
const GRAYSCALE_SHEET_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/day_grayscale_route_sheet.png"

const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const CARD_OCCLUSION_MARGIN: float = 10.0
const ROUTE_OCCLUSION_MARGIN: float = 16.0
const REQUIRED_ROUTE_ROAD_CLEARANCE: float = 480.0
const REQUIRED_PLAYER_ROAD_CLEARANCE: float = 72.0
const PLAYER_ROAD_RADIUS: float = 24.0
const REQUIRED_PLAYER_CARD_CLEARANCE: float = 24.0
## AmbientScenery and WildernessAccent own tree/grove silhouettes.  This is
## intentionally much higher than V2's generic material floor so cards cannot
## be selected under a canopy merely because their bounds technically miss it.
const REQUIRED_CANOPY_CLEARANCE: float = 220.0
const REQUIRED_OTHER_ENVIRONMENT_CLEARANCE: float = 140.0
const REQUIRED_CARD_SEPARATION: float = 18.0
const MIN_VISIBLE_CHANGED_PIXELS: int = 5
const SCREEN_SAFE_INSET_PX: float = 20.0
const TEXTURE_RING_SAMPLE_COUNT: int = 16
const TEXTURE_RING_RADIUS_PX: float = 13.0
const MAX_TEXTURE_RING_LUMA_RANGE: float = 0.34
const MAX_TEXTURE_RING_EDGE_STEP: float = 0.18
const SAMPLE_RING_COUNT: int = 28
const SAMPLE_SPOKE_COUNT: int = 56
const CONTACT_SHEET_COLUMNS: int = 5
const CONTACT_TILE_SIZE: Vector2i = Vector2i(240, 135)

## This is the manifest-backed padded region for `rock_bare_0`, not a raw
## Addons/Poly Haven file.  V2 mossy-stone and every Recipe B source region are
## intentionally excluded.
const BARE_PEBBLE_REGION: Rect2 = Rect2(340.0, 1109.0, 89.0, 94.0)
const REJECTED_RECIPE_B_REGIONS: Array[Rect2] = [
	Rect2(34.0, 578.0, 188.0, 146.0),
	Rect2(295.0, 570.0, 164.0, 155.0),
	Rect2(796.0, 1086.0, 205.0, 153.0),
	Rect2(1038.0, 1117.0, 226.0, 100.0),
	Rect2(805.0, 578.0, 183.0, 119.0),
]
const EXPORTED_ROOT_SCENES: Array[String] = [
	"res://scenes/ui/StartMenu.tscn",
	"res://scenes/game/game_world.tscn",
	"res://scenes/build/runtime_export_dependencies.tscn",
]
const PLAYER_REFERENCE_OFFSETS: Array[Vector2] = [
	Vector2(-220.0, 76.0),
	Vector2(202.0, -82.0),
	Vector2(-184.0, -106.0),
	Vector2(196.0, 88.0),
]

@onready var lighting: CanvasModulate = %ValidationCanvasModulate
@onready var y_sort_world: Node2D = %YSortWorld
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var atmosphere: NightAtmosphere2D = %NightAtmosphere2D as NightAtmosphere2D
@onready var camera: Camera2D = %ValidationCamera

var _route_cluster: RouteEcologyCluster
var _player: PlayerAvatar
var _player_local_visual_bounds: Rect2 = Rect2()
var _ambient_positions: PackedVector2Array = PackedVector2Array()
var _ambient_radii: PackedFloat32Array = PackedFloat32Array()
var _accent_positions: PackedVector2Array = PackedVector2Array()
var _accent_radii: PackedFloat32Array = PackedFloat32Array()
var _rubble_positions: PackedVector2Array = PackedVector2Array()
var _rubble_radii: PackedFloat32Array = PackedFloat32Array()
var _moss_positions: PackedVector2Array = PackedVector2Array()
var _moss_radii: PackedFloat32Array = PackedFloat32Array()
var _prop_positions: PackedVector2Array = PackedVector2Array()
var _prop_radii: PackedFloat32Array = PackedFloat32Array()
var _crack_envelopes: Array[Rect2] = []
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0
var _visual_gate_results: Array[Dictionary] = []


class EcologyCard extends Node2D:
	enum Family {
		LICHEN,
		NEEDLE_LITTER,
		FALLEN_TWIG,
		BARE_PEBBLE,
	}

	const FAMILY_NAMES: Array[String] = [
		"lichen_patch",
		"needle_litter",
		"fallen_twig",
		"irregular_bare_pebble",
	]
	var _family: int = Family.LICHEN
	var _variant: int = 0
	var _visual_bounds: Rect2 = Rect2()
	var _visual_radius: float = 0.0
	var _has_bounds: bool = false
	var _source_records: Array[Dictionary] = []

	func configure(family: int, variant: int) -> bool:
		_family = family
		_variant = variant
		z_index = -5
		z_as_relative = false
		match family:
			Family.LICHEN:
				_add_lichen_patch()
			Family.NEEDLE_LITTER:
				_add_needle_litter()
			Family.FALLEN_TWIG:
				_add_fallen_twig()
			Family.BARE_PEBBLE:
				_add_bare_pebble()
			_:
				return false
		_finalize_bounds()
		return _has_bounds and _visual_radius > 0.0

	func get_family() -> int:
		return _family

	func get_family_name() -> String:
		if _family < 0 or _family >= FAMILY_NAMES.size():
			return "invalid"
		return FAMILY_NAMES[_family]

	func get_visual_bounds() -> Rect2:
		return _visual_bounds

	func get_card_radius() -> float:
		return _visual_radius + CARD_OCCLUSION_MARGIN

	func get_source_records() -> Array[Dictionary]:
		return _source_records.duplicate(true)

	func _add_lichen_patch() -> void:
		var drift: Vector2 = Vector2(float(posmod(_variant * 7, 5) - 2), float(posmod(_variant * 3, 5) - 2))
		var lobe_centers: Array[Vector2] = [
			Vector2(-11.0, -3.0) + drift * 0.25,
			Vector2(1.0, -7.0),
			Vector2(12.0, 1.0) - drift * 0.15,
			Vector2(-2.0, 8.0),
		]
		var lobe_radii: Array[Vector2] = [
			Vector2(11.0, 6.0), Vector2(9.0, 7.0), Vector2(10.0, 5.0), Vector2(8.0, 5.0),
		]
		var colors: Array[Color] = [
			Color("66724f9e"), Color("7b8461a8"), Color("586345a8"), Color("87906ba0"),
		]
		for lobe_index: int in range(lobe_centers.size()):
			var polygon: Polygon2D = Polygon2D.new()
			polygon.name = "LichenLobe_%d" % lobe_index
			polygon.polygon = _irregular_lobe(lobe_centers[lobe_index], lobe_radii[lobe_index], lobe_index)
			polygon.color = colors[lobe_index]
			add_child(polygon)
			for point: Vector2 in polygon.polygon:
				_expand_bounds(point)
		_source_records.append({
			"source": "original_procedural_lobes",
			"semantic": "flat_lichen_patch",
			"variant": _variant,
		})

	func _irregular_lobe(center: Vector2, radii: Vector2, lobe_index: int) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(7):
			var angle: float = TAU * float(point_index) / 7.0 + 0.17 * float(lobe_index)
			var wobble: float = 0.78 + 0.13 * float(posmod(point_index * 5 + _variant + lobe_index, 4))
			points.append(center + Vector2(cos(angle) * radii.x * wobble, sin(angle) * radii.y * wobble))
		return points

	func _add_needle_litter() -> void:
		var colors: Array[Color] = [Color("64533cbb"), Color("7a684ba8"), Color("4d4937a8")]
		for needle_index: int in range(7):
			var angle: float = -0.75 + float(needle_index) * 0.43 + float(posmod(_variant, 3)) * 0.12
			var anchor: Vector2 = Vector2(
				-17.0 + float(posmod(needle_index * 11 + _variant, 34)),
				-9.0 + float(posmod(needle_index * 7 + _variant * 3, 23))
			)
			var length: float = 9.0 + float(posmod(needle_index * 3 + _variant, 5))
			var end: Vector2 = anchor + Vector2(cos(angle), sin(angle)) * length
			var line: Line2D = Line2D.new()
			line.name = "Needle_%d" % needle_index
			line.points = PackedVector2Array([anchor, end])
			line.width = 1.15
			line.default_color = colors[needle_index % colors.size()]
			line.antialiased = true
			add_child(line)
			_expand_bounds(anchor)
			_expand_bounds(end)
		_source_records.append({
			"source": "original_procedural_lines",
			"semantic": "needle_leaf_litter",
			"variant": _variant,
		})

	func _add_fallen_twig() -> void:
		var rotation_offset: float = (float(posmod(_variant, 5)) - 2.0) * 0.09
		var main_start: Vector2 = Vector2(-19.0, 4.0).rotated(rotation_offset)
		var main_end: Vector2 = Vector2(20.0, -4.0).rotated(rotation_offset)
		_add_twig_line("TwigMain", main_start, main_end, 1.55, Color("5a4634d1"))
		var fork_a: Vector2 = Vector2(-2.0, -1.0).rotated(rotation_offset)
		_add_twig_line("TwigForkA", fork_a, (fork_a + Vector2(-4.0, -10.0).rotated(rotation_offset)), 1.0, Color("6c523bd1"))
		var fork_b: Vector2 = Vector2(8.0, -2.0).rotated(rotation_offset)
		_add_twig_line("TwigForkB", fork_b, (fork_b + Vector2(8.0, -8.0).rotated(rotation_offset)), 0.95, Color("4d3d30c7"))
		_source_records.append({
			"source": "original_procedural_lines",
			"semantic": "fallen_twig",
			"variant": _variant,
		})

	func _add_twig_line(line_name: String, start: Vector2, finish: Vector2, width: float, color: Color) -> void:
		var line: Line2D = Line2D.new()
		line.name = line_name
		line.points = PackedVector2Array([start, finish])
		line.width = width
		line.default_color = color
		line.antialiased = true
		add_child(line)
		_expand_bounds(start)
		_expand_bounds(finish)

	func _add_bare_pebble() -> void:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = WILD_ATLAS
		frame.region = BARE_PEBBLE_REGION
		frame.filter_clip = true
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "BarePebble"
		sprite.texture = frame
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.rotation = -0.26 + float(posmod(_variant, 5)) * 0.13
		sprite.position = Vector2(float(posmod(_variant * 5, 5) - 2), float(posmod(_variant * 3, 5) - 2))
		sprite.scale = Vector2.ONE * 24.0 / maxf(BARE_PEBBLE_REGION.size.x, BARE_PEBBLE_REGION.size.y)
		sprite.self_modulate = Color("7b8174c7")
		add_child(sprite)
		var rect: Rect2 = sprite.get_rect()
		for corner: Vector2 in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]:
			_expand_bounds(sprite.transform * corner)
		_source_records.append({
			"source": "approved_wild_atlas",
			"atlas_region": [BARE_PEBBLE_REGION.position.x, BARE_PEBBLE_REGION.position.y, BARE_PEBBLE_REGION.size.x, BARE_PEBBLE_REGION.size.y],
			"semantic": "irregular_bare_pebble",
			"variant": _variant,
		})

	func _expand_bounds(point: Vector2) -> void:
		if not _has_bounds:
			_visual_bounds = Rect2(point, Vector2.ZERO)
			_has_bounds = true
			return
		_visual_bounds = _visual_bounds.expand(point)

	func _finalize_bounds() -> void:
		if not _has_bounds:
			return
		_visual_bounds = _visual_bounds.grow(2.0)
		for corner: Vector2 in [
			_visual_bounds.position,
			Vector2(_visual_bounds.end.x, _visual_bounds.position.y),
			_visual_bounds.end,
			Vector2(_visual_bounds.position.x, _visual_bounds.end.y),
		]:
			_visual_radius = maxf(_visual_radius, corner.length())


class RouteEcologyCluster extends Node2D:
	const FAMILY_COUNT: int = 4
	const CARD_OFFSETS: Array[Vector2] = [
		Vector2(-58.0, -24.0),
		Vector2(43.0, -34.0),
		Vector2(-41.0, 35.0),
		Vector2(58.0, 27.0),
	]
	var _cards: Array[EcologyCard] = []
	var _visual_bounds: Rect2 = Rect2()
	var _route_radius: float = 0.0
	var _variant: int = 0

	func configure(variant: int) -> bool:
		for child: Node in get_children():
			child.queue_free()
		_cards.clear()
		_visual_bounds = Rect2()
		_route_radius = 0.0
		_variant = posmod(variant, FAMILY_COUNT)
		var has_bounds: bool = false
		for slot: int in range(CARD_OFFSETS.size()):
			var family: int = posmod(slot + _variant, FAMILY_COUNT)
			var card: EcologyCard = EcologyCard.new()
			card.name = "Ecology_%s" % EcologyCard.FAMILY_NAMES[family]
			if not card.configure(family, variant * 11 + slot):
				return false
			card.position = CARD_OFFSETS[slot]
			add_child(card)
			_cards.append(card)
			var card_bounds: Rect2 = card.get_visual_bounds()
			var shifted_bounds: Rect2 = Rect2(card_bounds.position + card.position, card_bounds.size)
			if not has_bounds:
				_visual_bounds = shifted_bounds
				has_bounds = true
			else:
				_visual_bounds = _visual_bounds.merge(shifted_bounds)
		if not has_bounds:
			return false
		_visual_bounds = _visual_bounds.grow(ROUTE_OCCLUSION_MARGIN)
		for corner: Vector2 in [
			_visual_bounds.position,
			Vector2(_visual_bounds.end.x, _visual_bounds.position.y),
			_visual_bounds.end,
			Vector2(_visual_bounds.position.x, _visual_bounds.end.y),
		]:
			_route_radius = maxf(_route_radius, corner.length())
		return _cards.size() == FAMILY_COUNT and _route_radius > 0.0

	func get_variant() -> int:
		return _variant

	func get_cards() -> Array[EcologyCard]:
		return _cards.duplicate()

	func get_visual_bounds() -> Rect2:
		return _visual_bounds

	func get_route_radius() -> float:
		return _route_radius

	func get_card_bounds_at(origin: Vector2, card: EcologyCard) -> Rect2:
		var local: Rect2 = card.get_visual_bounds()
		return Rect2(origin + card.position + local.position, local.size)

	func get_card_position_at(origin: Vector2, card: EcologyCard) -> Vector2:
		return origin + card.position

	func get_card_records_at(origin: Vector2) -> Array[Dictionary]:
		var records: Array[Dictionary] = []
		for card: EcologyCard in _cards:
			var bounds: Rect2 = get_card_bounds_at(origin, card)
			records.append({
				"family": card.get_family_name(),
				"family_index": card.get_family(),
				"position": [get_card_position_at(origin, card).x, get_card_position_at(origin, card).y],
				"card_radius": snappedf(card.get_card_radius(), 0.001),
				"visual_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
				"sources": card.get_source_records(),
			})
		return records

	func get_minimum_inter_card_clearance() -> float:
		var minimum_clearance: float = 1000000.0
		for first_index: int in range(_cards.size()):
			for second_index: int in range(first_index + 1, _cards.size()):
				var first: EcologyCard = _cards[first_index]
				var second: EcologyCard = _cards[second_index]
				minimum_clearance = minf(
					minimum_clearance,
					first.position.distance_to(second.position) - first.get_card_radius() - second.get_card_radius()
				)
		return minimum_clearance

	func get_primary_family() -> int:
		if _cards.is_empty():
			return -1
		return _cards[0].get_family()


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if world_map == null or atmosphere == null or camera == null or lighting == null:
		_fail("fixture is missing WorldMap2D, NightAtmosphere2D, camera, or CanvasModulate")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the live 0.38 gameplay zoom")
		return
	camera.make_current()
	_route_cluster = RouteEcologyCluster.new()
	_route_cluster.name = "ArtifactOnlyEcologyRouteCluster"
	world_map.add_child(_route_cluster)
	_route_cluster.visible = false
	if not _load_existing_world_envelopes() or not _spawn_player_reference() or not _cache_player_visual_bounds():
		return
	if not _verify_source_and_runtime_isolation() or not _verify_cluster_family_contract():
		return
	var patches: Array[Dictionary] = _find_all_route_patches()
	if patches.size() != WorldAmbientScenery2D.WILDERNESS_POCKETS.size():
		_fail("expected exactly one gated ecology route in every wilderness pocket")
		return
	if not _verify_patch_contracts(patches):
		return
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		print("WILDERNESS ECOLOGY ROUTE CONTRACT OK | routes=%d | families=4 | GPU visual gate intentionally skipped" % patches.size())
		get_tree().quit(0)
		return
	await get_tree().process_frame
	var captures: Array[Dictionary] = []
	var day_tiles: Array[Image] = []
	var night_tiles: Array[Image] = []
	var grayscale_tiles: Array[Image] = []
	for patch_index: int in range(patches.size()):
		var patch: Dictionary = patches[patch_index]
		if not await _capture_route(patch_index, patch, "day", captures, day_tiles, night_tiles, grayscale_tiles):
			return
		if not await _capture_route(patch_index, patch, "night", captures, day_tiles, night_tiles, grayscale_tiles):
			return
	if day_tiles.size() != patches.size() or night_tiles.size() != patches.size() or grayscale_tiles.size() != patches.size():
		_fail("every route must produce day, night, and grayscale gameplay evidence")
		return
	if not _save_contact_sheet(day_tiles, DAY_SHEET_OUTPUT_PATH) or not _save_contact_sheet(night_tiles, NIGHT_SHEET_OUTPUT_PATH) or not _save_contact_sheet(grayscale_tiles, GRAYSCALE_SHEET_OUTPUT_PATH):
		return
	_write_metadata(patches, captures)
	print("WILDERNESS ECOLOGY ROUTE CAPTURE OK | routes=%d | captures=%d | visual_gates=%d | promotion=forbidden" % [
		patches.size(), captures.size(), _visual_gate_results.size(),
	])
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var error_code: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if error_code != OK:
		return _fail_bool("could not create artifact directory: %s" % error_string(error_code))
	return true


func _load_existing_world_envelopes() -> bool:
	var ambient: Node2D = world_map.get_node_or_null(^"AmbientScenery") as Node2D
	var accent: Node2D = world_map.get_node_or_null(^"WildernessAccent") as Node2D
	var background: WorldBackgroundDecor2D = world_map.get_node_or_null(^"BackgroundDecor") as WorldBackgroundDecor2D
	var ground_cover: Node2D = world_map.get_node_or_null(^"GroundCover") as Node2D
	if ambient == null or accent == null or background == null or ground_cover == null:
		return _fail_bool("WorldMap2D is missing required existing scenery/decor nodes")
	var ambient_positions_value: Variant = ambient.call(&"get_scenery_positions")
	var ambient_radii_value: Variant = ambient.call(&"get_scenery_visual_radii")
	var accent_positions_value: Variant = accent.call(&"get_anchor_positions")
	var accent_radii_value: Variant = accent.call(&"get_anchor_visual_radii")
	if not ambient_positions_value is PackedVector2Array or not ambient_radii_value is PackedFloat32Array:
		return _fail_bool("ambient envelope API returned an unexpected type")
	if not accent_positions_value is PackedVector2Array or not accent_radii_value is PackedFloat32Array:
		return _fail_bool("wilderness-accent envelope API returned an unexpected type")
	_ambient_positions = ambient_positions_value
	_ambient_radii = ambient_radii_value
	_accent_positions = accent_positions_value
	_accent_radii = accent_radii_value
	_rubble_positions = background.get_rubble_positions()
	_rubble_radii = background.get_rubble_visual_radii()
	_moss_positions = background.get_moss_positions()
	_moss_radii = background.get_moss_visual_radii()
	_prop_positions = background.get_prop_positions()
	_prop_radii = background.get_prop_visual_radii()
	var crack_value: Variant = background.get_crack_visual_envelopes()
	if not crack_value is Array:
		return _fail_bool("background crack envelope API returned an unexpected type")
	_crack_envelopes.clear()
	for entry: Variant in crack_value:
		if not entry is Rect2:
			return _fail_bool("background crack envelope API returned a non-Rect2 entry")
		_crack_envelopes.append(entry)
	if _ambient_positions.is_empty() or _accent_positions.is_empty() or _crack_envelopes.is_empty():
		return _fail_bool("existing map evidence unexpectedly has no canopy/decor envelopes")
	if _ambient_positions.size() != _ambient_radii.size() or _accent_positions.size() != _accent_radii.size():
		return _fail_bool("canopy envelope position/radius pairs are mismatched")
	return true


func _spawn_player_reference() -> bool:
	_player = PLAYER_SCENE.instantiate() as PlayerAvatar
	if _player == null:
		return _fail_bool("could not instantiate baked player scale reference")
	_player.configure(1, &"heikki", world_map.get_playable_rect().get_center(), false)
	y_sort_world.add_child(_player)
	_player.set_aim_direction(Vector2.RIGHT, false)
	return true


func _cache_player_visual_bounds() -> bool:
	if _player == null or not _player.uses_baked_actor_presentation():
		return _fail_bool("player reference did not bind the baked actor presentation")
	var presentation: AnimatedSprite2D = _player.get_presentation_sprite()
	if presentation == null or presentation.sprite_frames == null:
		return _fail_bool("player reference has no baked AnimatedSprite2D frame")
	var frame_texture: Texture2D = presentation.sprite_frames.get_frame_texture(presentation.animation, presentation.frame)
	if frame_texture == null:
		return _fail_bool("player reference has no readable baked frame")
	var frame_size: Vector2 = frame_texture.get_size()
	var atlas_frame: AtlasTexture = frame_texture as AtlasTexture
	if atlas_frame != null and atlas_frame.region.size.x > 0.0 and atlas_frame.region.size.y > 0.0:
		frame_size = atlas_frame.region.size
	var frame_origin: Vector2 = presentation.offset
	if presentation.centered:
		frame_origin -= frame_size * 0.5
	var rect: Rect2 = Rect2(frame_origin, frame_size)
	var has_bounds: bool = false
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var player_corner: Vector2 = _player.to_local(presentation.to_global(corner))
		if not has_bounds:
			_player_local_visual_bounds = Rect2(player_corner, Vector2.ZERO)
			has_bounds = true
		else:
			_player_local_visual_bounds = _player_local_visual_bounds.expand(player_corner)
	_player_local_visual_bounds = _player_local_visual_bounds.grow(8.0)
	return _player_local_visual_bounds.size.x > 0.0 and _player_local_visual_bounds.size.y > 0.0


func _verify_source_and_runtime_isolation() -> bool:
	if WILD_ATLAS == null or WILD_ATLAS.get_width() != 1536 or WILD_ATLAS.get_height() != 1280:
		return _fail_bool("V3 expects the manifest-approved 1536x1280 wild atlas")
	var atlas_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(float(WILD_ATLAS.get_width()), float(WILD_ATLAS.get_height())))
	if not _rect_inside(atlas_bounds, BARE_PEBBLE_REGION):
		return _fail_bool("bare-pebble region leaves the approved atlas")
	for rejected_region: Rect2 in REJECTED_RECIPE_B_REGIONS:
		if BARE_PEBBLE_REGION == rejected_region:
			return _fail_bool("V3 unexpectedly reuses a rejected Recipe B region")
	for root_scene: String in EXPORTED_ROOT_SCENES:
		if not ResourceLoader.exists(root_scene):
			return _fail_bool("declared exported root does not exist: %s" % root_scene)
		for dependency: String in ResourceLoader.get_dependencies(root_scene):
			if dependency.contains("wilderness_ecology_route_validation"):
				return _fail_bool("artifact-only V3 fixture leaked into an exported root dependency")
	return true


func _verify_cluster_family_contract() -> bool:
	var previous_primary: int = -1
	for variant: int in range(RouteEcologyCluster.FAMILY_COUNT):
		if not _route_cluster.configure(variant):
			return _fail_bool("could not build route cluster variant %d" % variant)
		var seen_families: Dictionary[int, bool] = {}
		for card: EcologyCard in _route_cluster.get_cards():
			seen_families[card.get_family()] = true
			if card.get_card_radius() <= CARD_OCCLUSION_MARGIN or card.get_card_radius() >= 42.0:
				return _fail_bool("ecology card escaped its low-profile size budget")
		if seen_families.size() != RouteEcologyCluster.FAMILY_COUNT:
			return _fail_bool("route card lost one of the four distinct ecology families")
		if _route_cluster.get_minimum_inter_card_clearance() < REQUIRED_CARD_SEPARATION:
			return _fail_bool("route cards collapse into a single token silhouette")
		var primary: int = _route_cluster.get_primary_family()
		if primary == previous_primary:
			return _fail_bool("route layout repeats a primary token family")
		previous_primary = primary
	return true


func _find_all_route_patches() -> Array[Dictionary]:
	var patches: Array[Dictionary] = []
	for pocket_index: int in range(WorldAmbientScenery2D.WILDERNESS_POCKETS.size()):
		var cluster_variant: int = posmod(pocket_index, RouteEcologyCluster.FAMILY_COUNT)
		if not _route_cluster.configure(cluster_variant):
			_fail("could not configure ecology route variant %d" % cluster_variant)
			return []
		var pocket: Vector4 = WorldAmbientScenery2D.WILDERNESS_POCKETS[pocket_index]
		var player_offset: Vector2 = PLAYER_REFERENCE_OFFSETS[cluster_variant]
		var candidate: Vector2 = _find_clear_candidate_in_pocket(pocket, player_offset)
		if candidate == Vector2.INF:
			_fail("wilderness pocket %d has no V3 route position outside canopy/texture envelopes" % pocket_index)
			return []
		patches.append(_get_patch_metadata(pocket_index, pocket, candidate, cluster_variant, player_offset))
	return patches


func _find_clear_candidate_in_pocket(pocket: Vector4, player_offset: Vector2) -> Vector2:
	var best_candidate: Vector2 = Vector2.INF
	var best_score: float = -INF
	var rejection_counts: Dictionary[StringName, int] = {}
	for ring_index: int in range(SAMPLE_RING_COUNT):
		var radius_factor: float = 0.06 + float(ring_index) / float(SAMPLE_RING_COUNT - 1) * 0.84
		for spoke_index: int in range(SAMPLE_SPOKE_COUNT):
			var angle: float = fposmod(float(spoke_index) * 2.399963 + float(ring_index) * 0.31, TAU)
			var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(cos(angle) * pocket.z * radius_factor, sin(angle) * pocket.w * radius_factor)
			var rejection: StringName = _get_candidate_rejection(candidate, player_offset)
			if not rejection.is_empty():
				rejection_counts[rejection] = rejection_counts.get(rejection, 0) + 1
				continue
			var score: float = _get_candidate_clearance_score(candidate)
			if score > best_score:
				best_score = score
				best_candidate = candidate
	if best_candidate.is_finite():
		print("WILDERNESS ECOLOGY ROUTE SELECTED | center=(%.1f, %.1f) radius=%.3f score=%.3f" % [
			pocket.x, pocket.y, _route_cluster.get_route_radius(), best_score,
		])
		return best_candidate
	print("WILDERNESS ECOLOGY ROUTE REJECTION | center=(%.1f, %.1f) reasons=%s" % [pocket.x, pocket.y, JSON.stringify(rejection_counts)])
	return Vector2.INF


func _get_candidate_rejection(candidate: Vector2, player_offset: Vector2) -> StringName:
	if not candidate.is_finite() or _route_cluster.get_route_radius() <= 0.0:
		return &"invalid"
	var playable_rect: Rect2 = world_map.get_playable_rect()
	var route_radius: float = _route_cluster.get_route_radius()
	var player_position: Vector2 = candidate + player_offset
	var player_bounds: Rect2 = _get_player_visual_bounds_at(player_position)
	if not playable_rect.grow(-route_radius).has_point(candidate):
		return &"route_playable_bounds"
	if not _rect_inside(playable_rect, player_bounds):
		return &"player_playable_bounds"
	if not world_map.is_position_walkable(candidate, 0.0) or not world_map.is_position_walkable(player_position, 0.0):
		return &"route_or_player_walkability"
	if world_map.get_minimum_road_edge_distance(candidate) - route_radius < REQUIRED_ROUTE_ROAD_CLEARANCE:
		return &"route_road_clearance"
	if world_map.get_minimum_road_edge_distance(player_position) - PLAYER_ROAD_RADIUS < REQUIRED_PLAYER_ROAD_CLEARANCE:
		return &"player_road_clearance"
	for card: EcologyCard in _route_cluster.get_cards():
		var card_position: Vector2 = _route_cluster.get_card_position_at(candidate, card)
		var card_bounds: Rect2 = _route_cluster.get_card_bounds_at(candidate, card)
		if not _rect_inside(playable_rect, card_bounds):
			return &"card_playable_bounds"
		if not world_map.is_position_walkable(card_position, 0.0):
			return &"card_walkability"
		if _rect_clearance(player_bounds, card_bounds) < REQUIRED_PLAYER_CARD_CLEARANCE:
			return &"player_card_clearance"
		if _minimum_circular_clearance(card_position, card.get_card_radius(), _ambient_positions, _ambient_radii) < REQUIRED_CANOPY_CLEARANCE:
			return &"ambient_canopy_clearance"
		if _minimum_circular_clearance(card_position, card.get_card_radius(), _accent_positions, _accent_radii) < REQUIRED_CANOPY_CLEARANCE:
			return &"accent_canopy_clearance"
		if _minimum_circular_clearance(card_position, card.get_card_radius(), _rubble_positions, _rubble_radii) < REQUIRED_OTHER_ENVIRONMENT_CLEARANCE:
			return &"rubble_clearance"
		if _minimum_circular_clearance(card_position, card.get_card_radius(), _moss_positions, _moss_radii) < REQUIRED_OTHER_ENVIRONMENT_CLEARANCE:
			return &"moss_clearance"
		if _minimum_circular_clearance(card_position, card.get_card_radius(), _prop_positions, _prop_radii) < REQUIRED_OTHER_ENVIRONMENT_CLEARANCE:
			return &"prop_clearance"
		if _minimum_rect_clearance(card_position, card.get_card_radius(), _crack_envelopes) < REQUIRED_OTHER_ENVIRONMENT_CLEARANCE:
			return &"texture_boundary_clearance"
	return &""


func _get_candidate_clearance_score(candidate: Vector2) -> float:
	var score: float = 1000000.0
	for card: EcologyCard in _route_cluster.get_cards():
		var card_position: Vector2 = _route_cluster.get_card_position_at(candidate, card)
		var radius: float = card.get_card_radius()
		score = minf(score, _minimum_circular_clearance(card_position, radius, _ambient_positions, _ambient_radii))
		score = minf(score, _minimum_circular_clearance(card_position, radius, _accent_positions, _accent_radii))
		score = minf(score, _minimum_circular_clearance(card_position, radius, _rubble_positions, _rubble_radii))
		score = minf(score, _minimum_circular_clearance(card_position, radius, _moss_positions, _moss_radii))
		score = minf(score, _minimum_circular_clearance(card_position, radius, _prop_positions, _prop_radii))
		score = minf(score, _minimum_rect_clearance(card_position, radius, _crack_envelopes))
	return score


func _get_patch_metadata(pocket_index: int, pocket: Vector4, candidate: Vector2, cluster_variant: int, player_offset: Vector2) -> Dictionary:
	var player_position: Vector2 = candidate + player_offset
	var player_bounds: Rect2 = _get_player_visual_bounds_at(player_position)
	var canopy_minimum: float = 1000000.0
	var other_minimum: float = 1000000.0
	var all_cards_walkable: bool = true
	var cards: Array[Dictionary] = _route_cluster.get_card_records_at(candidate)
	for card: EcologyCard in _route_cluster.get_cards():
		var card_position: Vector2 = _route_cluster.get_card_position_at(candidate, card)
		var radius: float = card.get_card_radius()
		canopy_minimum = minf(canopy_minimum, _minimum_circular_clearance(card_position, radius, _ambient_positions, _ambient_radii))
		canopy_minimum = minf(canopy_minimum, _minimum_circular_clearance(card_position, radius, _accent_positions, _accent_radii))
		other_minimum = minf(other_minimum, _minimum_circular_clearance(card_position, radius, _rubble_positions, _rubble_radii))
		other_minimum = minf(other_minimum, _minimum_circular_clearance(card_position, radius, _moss_positions, _moss_radii))
		other_minimum = minf(other_minimum, _minimum_circular_clearance(card_position, radius, _prop_positions, _prop_radii))
		other_minimum = minf(other_minimum, _minimum_rect_clearance(card_position, radius, _crack_envelopes))
		all_cards_walkable = all_cards_walkable and world_map.is_position_walkable(card_position, 0.0)
	return {
		"pocket_index": pocket_index,
		"pocket": [pocket.x, pocket.y, pocket.z, pocket.w],
		"position": [candidate.x, candidate.y],
		"cluster_variant": cluster_variant,
		"player_reference_offset": [player_offset.x, player_offset.y],
		"route_radius": snappedf(_route_cluster.get_route_radius(), 0.001),
		"route_visual_bounds": _rect_to_array(Rect2(_route_cluster.get_visual_bounds().position + candidate, _route_cluster.get_visual_bounds().size)),
		"cards": cards,
		"all_cards_walkable": all_cards_walkable,
		"card_separation": snappedf(_route_cluster.get_minimum_inter_card_clearance(), 0.001),
		"selection_clearance_score": snappedf(_get_candidate_clearance_score(candidate), 0.001),
		"canopy_clearance": snappedf(canopy_minimum, 0.001),
		"other_environment_clearance": snappedf(other_minimum, 0.001),
		"route_road_clearance": snappedf(world_map.get_minimum_road_edge_distance(candidate) - _route_cluster.get_route_radius(), 0.001),
		"player_relative_contract": {
			"position": [player_position.x, player_position.y],
			"visual_bounds": _rect_to_array(player_bounds),
			"body_bounds_inside_playable_rect": _rect_inside(world_map.get_playable_rect(), player_bounds),
			"origin_walkable": world_map.is_position_walkable(player_position, 0.0),
			"road_clearance": snappedf(world_map.get_minimum_road_edge_distance(player_position) - PLAYER_ROAD_RADIUS, 0.001),
		},
	}


func _verify_patch_contracts(patches: Array[Dictionary]) -> bool:
	var previous_primary: int = -1
	for patch: Dictionary in patches:
		var cluster_variant: int = int(patch.get("cluster_variant", -1))
		if not _route_cluster.configure(cluster_variant):
			return _fail_bool("could not reconfigure a selected route cluster")
		var primary: int = _route_cluster.get_primary_family()
		if primary == previous_primary:
			return _fail_bool("route sequence repeats a primary family token")
		previous_primary = primary
		if not bool(patch.get("all_cards_walkable", false)):
			return _fail_bool("selected ecology card is not on a walkable substrate")
		if float(patch.get("canopy_clearance", -1.0)) < REQUIRED_CANOPY_CLEARANCE:
			return _fail_bool("route could disappear under a canopy")
		if float(patch.get("other_environment_clearance", -1.0)) < REQUIRED_OTHER_ENVIRONMENT_CLEARANCE:
			return _fail_bool("route reaches a texture/decor boundary")
		if float(patch.get("card_separation", -1.0)) < REQUIRED_CARD_SEPARATION:
			return _fail_bool("route families collapse into a repeated token")
		var cards_value: Variant = patch.get("cards", [])
		if not cards_value is Array or cards_value.size() != RouteEcologyCluster.FAMILY_COUNT:
			return _fail_bool("route does not expose all four ecology families")
	return true


func _capture_route(
	patch_index: int,
	patch: Dictionary,
	phase: String,
	captures: Array[Dictionary],
	day_tiles: Array[Image],
	night_tiles: Array[Image],
	grayscale_tiles: Array[Image]
) -> bool:
	var cluster_variant: int = int(patch.get("cluster_variant", -1))
	var route_position: Vector2 = _dictionary_position(patch, &"position")
	var player_offset: Vector2 = _dictionary_position(patch, &"player_reference_offset")
	if cluster_variant < 0 or not route_position.is_finite() or not player_offset.is_finite():
		return _fail_bool("route patch %d has malformed placement data" % patch_index)
	if not _route_cluster.configure(cluster_variant):
		return _fail_bool("could not configure route cluster for capture")
	_route_cluster.position = route_position
	camera.position = route_position
	camera.zoom = Vector2.ONE * GAMEPLAY_CAMERA_ZOOM
	var player_position: Vector2 = route_position + player_offset
	_player.apply_authoritative_state(player_position, Vector2.ZERO)
	_player.global_position = player_position
	if phase == "day":
		lighting.color = NightAtmosphere2D.DAY_COLOR
		atmosphere.set_night_active(false, true)
		_player.set_aim_direction(Vector2.RIGHT, false)
	else:
		atmosphere.register_player(_player)
		atmosphere.set_night_active(true, true)
		_player.set_aim_direction(Vector2.UP, true)
		if not _player.is_flashlight_enabled():
			return _fail_bool("night route capture did not enable the real player flashlight")
	_route_cluster.visible = false
	_player.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var backdrop: Image = get_viewport().get_texture().get_image()
	if not _normalize_to_logical_capture(backdrop):
		return false
	_route_cluster.visible = true
	_player.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var composed: Image = get_viewport().get_texture().get_image()
	if not _normalize_to_logical_capture(composed):
		return false
	if phase == "day":
		var visual_gate: Dictionary = _evaluate_day_visual_gate(backdrop, composed, route_position, patch_index)
		if not bool(visual_gate.get("passes", false)):
			return _fail_bool("route %d fails the canopy/texture/visibility screen gate: %s" % [patch_index, JSON.stringify(visual_gate)])
		_visual_gate_results.append(visual_gate)
	var output_path: String = "%s/route_%02d_%s.png" % [OUTPUT_DIRECTORY, patch_index, phase]
	if not _save_image(composed, output_path):
		return false
	var grayscale: Image = _to_grayscale(composed)
	var grayscale_path: String = "%s/route_%02d_%s_grayscale.png" % [OUTPUT_DIRECTORY, patch_index, phase]
	if not _save_image(grayscale, grayscale_path):
		return false
	if phase == "day":
		day_tiles.append(composed)
		grayscale_tiles.append(grayscale)
	else:
		night_tiles.append(composed)
	captures.append({
		"route_index": patch_index,
		"phase": phase,
		"output": output_path,
		"grayscale_output": grayscale_path,
		"cluster_variant": cluster_variant,
	})
	return true


func _evaluate_day_visual_gate(backdrop: Image, composed: Image, route_position: Vector2, route_index: int) -> Dictionary:
	var texture_records: Array[Dictionary] = []
	var visible_records: Array[Dictionary] = []
	var passes: bool = true
	for card: EcologyCard in _route_cluster.get_cards():
		var world_position: Vector2 = _route_cluster.get_card_position_at(route_position, card)
		var pixel: Vector2 = _world_to_capture_pixel(world_position)
		var radius_px: float = maxf(5.0, card.get_card_radius() * GAMEPLAY_CAMERA_ZOOM)
		var inside_safe_rect: bool = (
			pixel.x - radius_px >= SCREEN_SAFE_INSET_PX
			and pixel.y - radius_px >= SCREEN_SAFE_INSET_PX
			and pixel.x + radius_px < float(LOGICAL_CAPTURE_SIZE.x) - SCREEN_SAFE_INSET_PX
			and pixel.y + radius_px < float(LOGICAL_CAPTURE_SIZE.y) - SCREEN_SAFE_INSET_PX
		)
		var luma_values: Array[float] = []
		for sample_index: int in range(TEXTURE_RING_SAMPLE_COUNT):
			var angle: float = TAU * float(sample_index) / float(TEXTURE_RING_SAMPLE_COUNT)
			var sample_point: Vector2 = pixel + Vector2(cos(angle), sin(angle)) * TEXTURE_RING_RADIUS_PX
			luma_values.append(_sample_luma(backdrop, sample_point))
		var luma_minimum: float = 1.0
		var luma_maximum: float = 0.0
		var max_edge_step: float = 0.0
		for luma_index: int in range(luma_values.size()):
			luma_minimum = minf(luma_minimum, luma_values[luma_index])
			luma_maximum = maxf(luma_maximum, luma_values[luma_index])
			max_edge_step = maxf(max_edge_step, absf(luma_values[luma_index] - luma_values[(luma_index + 1) % luma_values.size()]))
		var luma_range: float = luma_maximum - luma_minimum
		var changed_pixels: int = _count_changed_pixels(backdrop, composed, pixel, int(ceil(radius_px)))
		var texture_pass: bool = inside_safe_rect and luma_range <= MAX_TEXTURE_RING_LUMA_RANGE and max_edge_step <= MAX_TEXTURE_RING_EDGE_STEP
		var visibility_pass: bool = changed_pixels >= MIN_VISIBLE_CHANGED_PIXELS
		passes = passes and texture_pass and visibility_pass
		texture_records.append({
			"family": card.get_family_name(),
			"screen_center": [snappedf(pixel.x, 0.01), snappedf(pixel.y, 0.01)],
			"inside_safe_rect": inside_safe_rect,
			"luma_range": snappedf(luma_range, 0.0001),
			"max_edge_step": snappedf(max_edge_step, 0.0001),
			"texture_pass": texture_pass,
		})
		visible_records.append({
			"family": card.get_family_name(),
			"changed_pixels": changed_pixels,
			"required_changed_pixels": MIN_VISIBLE_CHANGED_PIXELS,
			"visibility_pass": visibility_pass,
		})
	return {
		"route_index": route_index,
		"passes": passes,
		"canopy_policy": "static per-card >= %.1f units from AmbientScenery/WildernessAccent envelopes" % REQUIRED_CANOPY_CLEARANCE,
		"texture_records": texture_records,
		"visibility_records": visible_records,
	}


func _world_to_capture_pixel(world_position: Vector2) -> Vector2:
	return Vector2(float(LOGICAL_CAPTURE_SIZE.x) * 0.5, float(LOGICAL_CAPTURE_SIZE.y) * 0.5) + (world_position - camera.position) * GAMEPLAY_CAMERA_ZOOM


func _sample_luma(image: Image, point: Vector2) -> float:
	var pixel_x: int = clampi(int(round(point.x)), 0, image.get_width() - 1)
	var pixel_y: int = clampi(int(round(point.y)), 0, image.get_height() - 1)
	var color: Color = image.get_pixel(pixel_x, pixel_y)
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _count_changed_pixels(backdrop: Image, composed: Image, center: Vector2, radius: int) -> int:
	var changed_pixels: int = 0
	for pixel_y: int in range(maxi(0, int(floor(center.y)) - radius), mini(composed.get_height(), int(ceil(center.y)) + radius + 1)):
		for pixel_x: int in range(maxi(0, int(floor(center.x)) - radius), mini(composed.get_width(), int(ceil(center.x)) + radius + 1)):
			if Vector2(float(pixel_x), float(pixel_y)).distance_to(center) > float(radius):
				continue
			var before: Color = backdrop.get_pixel(pixel_x, pixel_y)
			var after: Color = composed.get_pixel(pixel_x, pixel_y)
			var difference: float = maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
			if difference >= 0.035:
				changed_pixels += 1
	return changed_pixels


func _normalize_to_logical_capture(image: Image) -> bool:
	if image == null or image.is_empty():
		return _fail_bool("empty viewport image")
	_native_capture_size = image.get_size()
	if _native_capture_size.x <= 0 or _native_capture_size.y <= 0 or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0 or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0:
		return _fail_bool("native viewport is %s; expected an integer scale of %s" % [_native_capture_size, LOGICAL_CAPTURE_SIZE])
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		return _fail_bool("native viewport scale is non-uniform")
	_native_capture_scale = horizontal_scale
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	return image.get_size() == LOGICAL_CAPTURE_SIZE


func _to_grayscale(source: Image) -> Image:
	var grayscale: Image = source.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	return grayscale


func _save_contact_sheet(images: Array[Image], output_path: String) -> bool:
	var rows: int = int(ceili(float(images.size()) / float(CONTACT_SHEET_COLUMNS)))
	var sheet: Image = Image.create(CONTACT_TILE_SIZE.x * CONTACT_SHEET_COLUMNS, CONTACT_TILE_SIZE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101513"))
	for image_index: int in range(images.size()):
		var tile: Image = images[image_index].duplicate()
		tile.resize(CONTACT_TILE_SIZE.x, CONTACT_TILE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var destination: Vector2i = Vector2i((image_index % CONTACT_SHEET_COLUMNS) * CONTACT_TILE_SIZE.x, (image_index / CONTACT_SHEET_COLUMNS) * CONTACT_TILE_SIZE.y)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), destination)
	return _save_image(sheet, output_path)


func _save_image(image: Image, output_path: String) -> bool:
	var error_code: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if error_code != OK:
		return _fail_bool("could not save %s: %s" % [output_path, error_string(error_code)])
	return true


func _write_metadata(patches: Array[Dictionary], captures: Array[Dictionary]) -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_independent_visual_veto",
		"candidate": "v3_four_family_low_profile_wilderness_ecology_route",
		"iteration_history": {
			"recipe_b": "REJECTED: oversized root/branch hierarchy and silhouette failure",
			"v1": "HOLD: fixed three-stone waypoint-like token and weak envelope slack",
			"v2": "HOLD: better hierarchy, but repeated dark pebble token and canopy disappearance",
			"v3": "artifact-only four-family route card with static canopy clearance plus GPU texture-boundary and visible-pixel gates",
		},
		"source_policy": "one manifest-approved baked wild atlas pebble region plus original procedural lichen/litter/twig silhouettes; no raw Addons, Poly Haven download, GLTF, Blender scene, mesh, PBR graph, Node3D, or source-vault dependency",
		"source_atlas": "res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png",
		"source_atlas_sha256": "20497d4d1d2e7560be0b35001f6c6256168c85fd0880d44b42ea9cf7d46d832e",
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"family_contract": "every route holds exactly lichen patch, needle litter, fallen twig, and irregular bare pebble; no two cards use the same semantic family and route primary family rotates deterministically",
		"canopy_contract": "each card must keep at least %.1f world units from AmbientScenery/WildernessAccent envelopes" % REQUIRED_CANOPY_CLEARANCE,
		"texture_boundary_contract": "GPU day backdrop samples ring luma; range <= %.2f and adjacent edge step <= %.2f, with every card inside a 20px screen-safe inset" % [MAX_TEXTURE_RING_LUMA_RANGE, MAX_TEXTURE_RING_EDGE_STEP],
		"visibility_contract": "GPU comparison against a no-card backdrop requires >= %d changed pixels for every family" % MIN_VISIBLE_CHANGED_PIXELS,
		"capture_scope": "isolated test sibling only; no WorldMap2D scene, decor settings, collision, flow field, authority, input, or export dependency changed",
		"pocket_count": patches.size(),
		"patches": patches,
		"capture_count": captures.size(),
		"captures": captures,
		"visual_gate_results": _visual_gate_results,
		"day_sheet": DAY_SHEET_OUTPUT_PATH,
		"night_sheet": NIGHT_SHEET_OUTPUT_PATH,
		"grayscale_sheet": GRAYSCALE_SHEET_OUTPUT_PATH,
		"review_requirement": "Independent visual review is mandatory. Passing static/GPU artifact gates does not certify Android performance, touch ergonomics, LAN, moving combat readability, or premium quality and does not authorize runtime promotion.",
	}
	var metadata_file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(METADATA_OUTPUT_PATH), FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write V3 ecology metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _get_player_visual_bounds_at(position: Vector2) -> Rect2:
	return Rect2(_player_local_visual_bounds.position + position, _player_local_visual_bounds.size)


func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end - Vector2(0.001, 0.001))


func _rect_clearance(first: Rect2, second: Rect2) -> float:
	if first.intersects(second):
		return -minf(minf(first.end.x - second.position.x, second.end.x - first.position.x), minf(first.end.y - second.position.y, second.end.y - first.position.y))
	var horizontal_gap: float = maxf(maxf(first.position.x - second.end.x, second.position.x - first.end.x), 0.0)
	var vertical_gap: float = maxf(maxf(first.position.y - second.end.y, second.position.y - first.end.y), 0.0)
	return Vector2(horizontal_gap, vertical_gap).length()


func _minimum_circular_clearance(candidate: Vector2, radius: float, positions: PackedVector2Array, radii: PackedFloat32Array) -> float:
	var minimum_clearance: float = 1000000.0
	for index: int in range(positions.size()):
		minimum_clearance = minf(minimum_clearance, candidate.distance_to(positions[index]) - radius - radii[index])
	return minimum_clearance


func _minimum_rect_clearance(candidate: Vector2, radius: float, envelopes: Array[Rect2]) -> float:
	var minimum_clearance: float = 1000000.0
	for envelope: Rect2 in envelopes:
		var nearest: Vector2 = Vector2(clampf(candidate.x, envelope.position.x, envelope.end.x), clampf(candidate.y, envelope.position.y, envelope.end.y))
		minimum_clearance = minf(minimum_clearance, candidate.distance_to(nearest) - radius)
	return minimum_clearance


func _dictionary_position(source: Dictionary, key: StringName) -> Vector2:
	var value: Variant = source.get(key, [])
	if not value is Array or value.size() != 2:
		return Vector2.INF
	var coordinates: Array = value
	if not (coordinates[0] is float or coordinates[0] is int) or not (coordinates[1] is float or coordinates[1] is int):
		return Vector2.INF
	return Vector2(float(coordinates[0]), float(coordinates[1]))


func _rect_to_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("WILDERNESS ECOLOGY ROUTE FAILED: %s" % message)
	get_tree().quit(1)
