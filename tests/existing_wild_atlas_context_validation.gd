extends Node2D
## Artifact-only context gate for prospective wild-root / fallen-branch cards.
##
## The live world already owns dense GroundCover, BackgroundDecor, wilderness
## rock accents, and ambient silhouettes.  This fixture does not add to any of
## them.  It uses the *current runtime* Poly Haven wild atlas as a transient
## sibling of WorldMap2D, finds one deterministically clear location in every
## one of the ten wilderness pockets, and records day/night A/B evidence at the
## shipped 480x270 / 0.38 camera contract.  A green result is placement and
## capture evidence only; it never authorizes a runtime-art promotion.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const WILD_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
)
const SLEEK_SPRITE_SHADER: Shader = preload("res://shaders/sleek_sprite_finish.gdshader")

const OUTPUT_DIRECTORY: String = "res://artifacts/existing_wild_atlas_context_validation"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/existing_wild_atlas_context_validation.json"
const DAY_GRAYSCALE_SHEET_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/recipe_b_day_grayscale_sheet.png"

const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const CARD_OCCLUSION_MARGIN: float = 32.0
## This is the edge-to-edge clearance of the entire card, not only the card
## origin.  The prior grass probe checked its centre against 480 and could still
## let a broad card run into the road shoulder.
const REQUIRED_ROAD_CARD_CLEARANCE: float = 480.0
## 37 x 80 samples put one candidate every ~21 units across a 700 x 620 pocket.
## The previous 19 x 40 grid found nothing in pocket 2 once the card was also
## tested against colliding footprints: that pocket is 40 percent obstacle by
## sample count, so the clear pockets left in it are narrower than the old
## 42-unit spacing could resolve.
const SAMPLE_RING_COUNT: int = 37
const SAMPLE_SPOKE_COUNT: int = 80
## At most one authored pocket may fail to host the whole card, and that failure
## is recorded as a world-authoring finding rather than hidden or worked around.
## Pocket 2 (2600, -2200, 700x620) lies under the Ostari MALL_SHELL at (4850, -3150),
## whose colliding full-footprint foundation spans x 1650..8050, y -4050..-2250 at
## zero clearance: 45 percent of the pocket's samples are unwalkable at the origin
## and the ambient scenery authored into the pocket fills the walkable remainder.
## A 10-unit grid of 12,031 samples under every test below found no clear centre.
## The pocket is recorded under unhostable_pockets with its rejection census and
## the colliding obstacles reaching into it; a second unhostable pocket is a new
## finding and fails the gate.
const MAXIMUM_UNHOSTABLE_POCKETS: int = 1
const DAY_GRAYSCALE_SHEET_COLUMNS: int = 5
const DAY_GRAYSCALE_TILE_SIZE: Vector2i = Vector2i(240, 135)

const ROOT_REGIONS: Array[Rect2] = [
	Rect2(34.0, 578.0, 188.0, 146.0),
	Rect2(295.0, 570.0, 164.0, 155.0),
]
const BRANCH_REGIONS: Array[Rect2] = [
	Rect2(796.0, 1086.0, 205.0, 153.0),
	Rect2(1038.0, 1117.0, 226.0, 100.0),
]
const SHRUB_REGION: Rect2 = Rect2(805.0, 578.0, 183.0, 119.0)

enum ReviewRecipe {
	ROOTS_AND_BRANCHES,
	ROOTS_BRANCHES_AND_SHRUB,
}

@onready var lighting: CanvasModulate = %ValidationCanvasModulate
@onready var y_sort_world: Node2D = %YSortWorld
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var atmosphere: NightAtmosphere2D = %NightAtmosphere2D as NightAtmosphere2D
@onready var camera: Camera2D = %ValidationCamera

var _card_a: WildAtlasReviewCard
var _card_b: WildAtlasReviewCard
var _player: PlayerAvatar
var _tower: PlacedStructure2D
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0

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
var _obstacles: Array[WorldObstacle2D] = []
var _unhostable_pockets: Array[Dictionary] = []
var _last_rejection_counts: Dictionary[StringName, int] = {}


class WildAtlasReviewCard extends Node2D:
	## A real child hierarchy is intentional: the clearance radius is derived from
	## its transformed Sprite2D rects, not copied from a guessed source size.
	const ROOT_REGIONS: Array[Rect2] = [
		Rect2(34.0, 578.0, 188.0, 146.0),
		Rect2(295.0, 570.0, 164.0, 155.0),
	]
	const BRANCH_REGIONS: Array[Rect2] = [
		Rect2(796.0, 1086.0, 205.0, 153.0),
		Rect2(1038.0, 1117.0, 226.0, 100.0),
	]
	const SHRUB_REGION: Rect2 = Rect2(805.0, 578.0, 183.0, 119.0)

	var _visual_bounds: Rect2 = Rect2()
	var _base_radius: float = 0.0
	var _card_radius: float = 0.0
	var _frame_records: Array[Dictionary] = []

	func configure(recipe: int, occlusion_margin: float) -> bool:
		if WILD_ATLAS == null or occlusion_margin < 0.0:
			return false
		z_index = -5
		z_as_relative = false
		if not _add_frame(
			&"RootClusterA", ROOT_REGIONS[0], 126.0, Vector2(-42.0, 8.0), -0.18
		):
			return false
		if not _add_frame(
			&"RootClusterB", ROOT_REGIONS[1], 104.0, Vector2(26.0, -14.0), 0.15
		):
			return false
		if not _add_frame(
			&"FallenBranchA", BRANCH_REGIONS[0], 112.0, Vector2(24.0, 50.0), 0.18
		):
			return false
		if not _add_frame(
			&"FallenBranchB", BRANCH_REGIONS[1], 92.0, Vector2(-38.0, 58.0), -0.33
		):
			return false
		if recipe == ReviewRecipe.ROOTS_BRANCHES_AND_SHRUB:
			if not _add_frame(
				&"ShrubB", SHRUB_REGION, 82.0, Vector2(70.0, -28.0), 0.12
			):
				return false
		_measure_transformed_child_bounds(occlusion_margin)
		return _card_radius > 0.0 and _visual_bounds.size.x > 0.0 and _visual_bounds.size.y > 0.0

	func get_card_radius() -> float:
		return _card_radius

	func get_base_radius() -> float:
		return _base_radius

	func get_visual_bounds() -> Rect2:
		return _visual_bounds

	func get_frame_records() -> Array[Dictionary]:
		return _frame_records.duplicate(true)

	func _add_frame(
		frame_name: StringName,
		region: Rect2,
		target_span: float,
		local_position: Vector2,
		local_rotation: float
	) -> bool:
		if region.size.x <= 0.0 or region.size.y <= 0.0 or target_span <= 0.0:
			return false
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = WILD_ATLAS
		frame.region = region
		frame.filter_clip = true
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = frame_name
		sprite.texture = frame
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position = local_position
		sprite.rotation = local_rotation
		sprite.scale = Vector2.ONE * target_span / maxf(region.size.x, region.size.y)
		sprite.material = _make_forest_finish()
		add_child(sprite)
		_frame_records.append({
			"name": String(frame_name),
			"region": [region.position.x, region.position.y, region.size.x, region.size.y],
			"target_span": target_span,
			"position": [local_position.x, local_position.y],
			"rotation": local_rotation,
		})
		return true

	func _measure_transformed_child_bounds(occlusion_margin: float) -> void:
		var has_bounds: bool = false
		var maximum_radius: float = 0.0
		for child: Node in get_children():
			var sprite: Sprite2D = child as Sprite2D
			if sprite == null or sprite.texture == null:
				continue
			var rect: Rect2 = sprite.get_rect()
			var corners: Array[Vector2] = [
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y),
			]
			for corner: Vector2 in corners:
				var transformed: Vector2 = sprite.transform * corner
				if not has_bounds:
					_visual_bounds = Rect2(transformed, Vector2.ZERO)
					has_bounds = true
				else:
					_visual_bounds = _visual_bounds.expand(transformed)
				maximum_radius = maxf(maximum_radius, transformed.length())
		_base_radius = maximum_radius
		_card_radius = maximum_radius + occlusion_margin

	func _make_forest_finish() -> ShaderMaterial:
		var finish: ShaderMaterial = ShaderMaterial.new()
		finish.shader = SLEEK_SPRITE_SHADER
		## Same family correction used by the installed wild-tree sprites.  This is
		## presentation fidelity for review, not an approval of these new cards.
		finish.set_shader_parameter(&"accent_color", Color("6b8f78"))
		finish.set_shader_parameter(&"saturation", 0.78)
		finish.set_shader_parameter(&"contrast", 1.30)
		finish.set_shader_parameter(&"shadow_lift", 0.025)
		finish.set_shader_parameter(&"shadow_tint", 0.24)
		finish.set_shader_parameter(&"accent_strength", 0.065)
		finish.set_shader_parameter(&"sheen_strength", 0.032)
		finish.set_shader_parameter(&"outline_width", 1.6)
		finish.set_shader_parameter(&"palette_cohesion", 0.10)
		return finish


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if world_map == null or atmosphere == null or camera == null or lighting == null:
		_fail("fixture is missing WorldMap2D, NightAtmosphere2D, camera, or CanvasModulate")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the 0.38 gameplay zoom")
		return
	camera.make_current()
	## Headless Godot does not reliably advance a presentation scene through
	## process_frame on this workspace, so keep its useful static contract free of
	## deferred frames. Child WorldMap2D setup has already completed before this
	## root's _ready callback.
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		_run_headless_contract_validation()
		return
	await get_tree().process_frame
	if not _load_existing_world_envelopes():
		return
	if not _build_review_cards():
		return
	var required_card_radius: float = maxf(_card_a.get_card_radius(), _card_b.get_card_radius())
	var patches: Array[Dictionary] = _find_all_clear_pockets(required_card_radius)
	if not _verify_pocket_coverage(patches):
		return
	if not _spawn_scale_references(_dictionary_position(patches[0], &"position")):
		return
	await get_tree().process_frame
	if not _verify_contracts(required_card_radius):
		return
	var captures: Array[Dictionary] = []
	var day_grayscale_tiles: Array[Image] = []
	for patch_index: int in range(patches.size()):
		var patch: Dictionary = patches[patch_index]
		for recipe: int in [ReviewRecipe.ROOTS_AND_BRANCHES, ReviewRecipe.ROOTS_BRANCHES_AND_SHRUB]:
			if not await _capture_recipe(
				patch_index,
				patch,
				recipe,
				"day",
				captures,
				day_grayscale_tiles
			):
				return
			if not await _capture_recipe(
				patch_index,
				patch,
				recipe,
				"night",
				captures,
				day_grayscale_tiles
			):
				return
	if day_grayscale_tiles.size() != patches.size():
		_fail("recipe B day grayscale sheet is missing one or more hosted wilderness pockets")
		return
	if not _save_grayscale_sheet(day_grayscale_tiles, DAY_GRAYSCALE_SHEET_OUTPUT_PATH):
		return
	_write_metadata(patches, captures, required_card_radius)
	print(
		"EXISTING WILD ATLAS CONTEXT CAPTURE OK | pockets=%d | unhostable=%d | captures=%d | card_radius=%.3f | review_required=true"
		% [patches.size(), _unhostable_pockets.size(), captures.size(), required_card_radius]
	)
	get_tree().quit(0)


func _run_headless_contract_validation() -> void:
	if not _load_existing_world_envelopes():
		return
	if not _build_review_cards():
		return
	var required_card_radius: float = maxf(_card_a.get_card_radius(), _card_b.get_card_radius())
	var patches: Array[Dictionary] = _find_all_clear_pockets(required_card_radius)
	if not _verify_pocket_coverage(patches):
		return
	if _card_a.get_base_radius() <= 0.0 or _card_b.get_base_radius() <= 0.0:
		_fail("headless contract could not derive transformed child-rect radius")
		return
	if WILD_ATLAS.get_width() <= 0 or WILD_ATLAS.get_height() <= 0:
		_fail("headless contract could not read current runtime wild atlas dimensions")
		return
	print("EXISTING WILD ATLAS CONTEXT CONTRACT OK | pockets=%d | unhostable=%d | card_radius=%.3f | GPU capture intentionally skipped" % [
		patches.size(), _unhostable_pockets.size(), required_card_radius,
	])
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if make_directory_error != OK:
		_fail("could not create wild-atlas artifact directory: %s" % error_string(make_directory_error))
		return false
	return true


func _load_existing_world_envelopes() -> bool:
	var ambient: Node2D = world_map.get_node_or_null(^"AmbientScenery") as Node2D
	var accent: Node2D = world_map.get_node_or_null(^"WildernessAccent") as Node2D
	var background: WorldBackgroundDecor2D = (
		world_map.get_node_or_null(^"BackgroundDecor") as WorldBackgroundDecor2D
	)
	var ground_cover: Node2D = world_map.get_node_or_null(^"GroundCover") as Node2D
	if ambient == null or accent == null or background == null or ground_cover == null:
		_fail("WorldMap2D is missing AmbientScenery, WildernessAccent, BackgroundDecor, or GroundCover")
		return false
	var ambient_positions_variant: Variant = ambient.call(&"get_scenery_positions")
	var ambient_radii_variant: Variant = ambient.call(&"get_scenery_visual_radii")
	var accent_positions_variant: Variant = accent.call(&"get_anchor_positions")
	var accent_radii_variant: Variant = accent.call(&"get_anchor_visual_radii")
	if (
		not ambient_positions_variant is PackedVector2Array
		or not ambient_radii_variant is PackedFloat32Array
		or not accent_positions_variant is PackedVector2Array
		or not accent_radii_variant is PackedFloat32Array
	):
		_fail("ambient or wilderness-accent envelope API returned an unexpected type")
		return false
	_ambient_positions = ambient_positions_variant
	_ambient_radii = ambient_radii_variant
	_accent_positions = accent_positions_variant
	_accent_radii = accent_radii_variant
	_rubble_positions = background.get_rubble_positions()
	_rubble_radii = background.get_rubble_visual_radii()
	_moss_positions = background.get_moss_positions()
	_moss_radii = background.get_moss_visual_radii()
	_prop_positions = background.get_prop_positions()
	_prop_radii = background.get_prop_visual_radii()
	var crack_envelopes_variant: Variant = background.get_crack_visual_envelopes()
	if not crack_envelopes_variant is Array:
		_fail("background crack envelope API returned an unexpected type")
		return false
	_crack_envelopes.clear()
	for crack_envelope_variant: Variant in crack_envelopes_variant:
		if not crack_envelope_variant is Rect2:
			_fail("background crack envelope API returned a non-Rect2 entry")
			return false
		_crack_envelopes.append(crack_envelope_variant)
	if (
		_ambient_positions.size() != _ambient_radii.size()
		or _accent_positions.size() != _accent_radii.size()
		or _rubble_positions.size() != _rubble_radii.size()
		or _moss_positions.size() != _moss_radii.size()
		or _prop_positions.size() != _prop_radii.size()
	):
		_fail("one or more existing visual-envelope position/radius pairs are mismatched")
		return false
	if _ambient_positions.is_empty() or _accent_positions.is_empty() or _crack_envelopes.is_empty():
		_fail("existing world visual-envelope evidence was unexpectedly empty")
		return false
	_obstacles = world_map.get_obstacle_nodes()
	if _obstacles.is_empty():
		_fail("WorldMap2D reported no colliding obstacles to test the card against")
		return false
	return true


func _build_review_cards() -> bool:
	_card_a = WildAtlasReviewCard.new()
	_card_a.name = &"WildAtlasRecipeA"
	if not _card_a.configure(ReviewRecipe.ROOTS_AND_BRANCHES, CARD_OCCLUSION_MARGIN):
		_fail("could not construct recipe A wild-atlas card")
		return false
	world_map.add_child(_card_a)
	_card_b = WildAtlasReviewCard.new()
	_card_b.name = &"WildAtlasRecipeB"
	if not _card_b.configure(ReviewRecipe.ROOTS_BRANCHES_AND_SHRUB, CARD_OCCLUSION_MARGIN):
		_fail("could not construct recipe B wild-atlas card")
		return false
	world_map.add_child(_card_b)
	_card_a.visible = false
	_card_b.visible = false
	return true


func _find_all_clear_pockets(card_radius: float) -> Array[Dictionary]:
	var patches: Array[Dictionary] = []
	for pocket_index: int in range(WorldAmbientScenery2D.WILDERNESS_POCKETS.size()):
		var pocket: Vector4 = WorldAmbientScenery2D.WILDERNESS_POCKETS[pocket_index]
		var candidate: Vector2 = _find_clear_candidate_in_pocket(pocket, card_radius)
		if candidate == Vector2.INF:
			_unhostable_pockets.append(_get_unhostable_pocket_record(pocket_index, pocket, card_radius))
			continue
		var patch: Dictionary = _get_patch_metadata(pocket_index, pocket, candidate, card_radius)
		patches.append(patch)
	return patches


func _verify_pocket_coverage(patches: Array[Dictionary]) -> bool:
	var pocket_total: int = WorldAmbientScenery2D.WILDERNESS_POCKETS.size()
	if patches.size() + _unhostable_pockets.size() != pocket_total:
		_fail("pocket assessment lost pockets: %d hosted + %d unhostable != %d authored" % [
			patches.size(), _unhostable_pockets.size(), pocket_total,
		])
		return false
	if _unhostable_pockets.size() > MAXIMUM_UNHOSTABLE_POCKETS:
		_fail("%d wilderness pockets cannot host the whole card; at most %d is a recorded finding" % [
			_unhostable_pockets.size(), MAXIMUM_UNHOSTABLE_POCKETS,
		])
		return false
	if patches.is_empty():
		_fail("no wilderness pocket can host the whole card")
		return false
	for record: Dictionary in _unhostable_pockets:
		var reaching: Array = record.get("obstacles_reaching_into_pocket", [])
		print("WILD ATLAS UNHOSTABLE POCKET | index=%d obstacles_reaching_in=%d census=%s" % [
			int(record.get("pocket_index", -1)), reaching.size(), JSON.stringify(record.get("rejection_census", {})),
		])
	return true


func _get_unhostable_pocket_record(pocket_index: int, pocket: Vector4, card_radius: float) -> Dictionary:
	var pocket_rect: Rect2 = Rect2(Vector2(pocket.x - pocket.z, pocket.y - pocket.w), Vector2(pocket.z, pocket.w) * 2.0)
	var kind_names: PackedStringArray = WorldObstacle2D.VisualKind.keys()
	var reaching: Array[Dictionary] = []
	for obstacle: WorldObstacle2D in _obstacles:
		var bounds: Rect2 = obstacle.get_world_bounds(0.0)
		if bounds.intersects(pocket_rect):
			reaching.append({
				"visual_kind": kind_names[obstacle.get_visual_kind()],
				"position": [snappedf(obstacle.position.x, 0.1), snappedf(obstacle.position.y, 0.1)],
				"world_bounds": _rect_to_array(bounds),
			})
	var census: Dictionary = {}
	for reason: StringName in _last_rejection_counts:
		census[String(reason)] = _last_rejection_counts[reason]
	return {
		"pocket_index": pocket_index,
		"pocket": [pocket.x, pocket.y, pocket.z, pocket.w],
		"card_radius": snappedf(card_radius, 0.001),
		"sample_count": SAMPLE_RING_COUNT * SAMPLE_SPOKE_COUNT,
		"rejection_census": census,
		"obstacles_reaching_into_pocket": reaching,
	}


func _find_clear_candidate_in_pocket(pocket: Vector4, card_radius: float) -> Vector2:
	var rejection_counts: Dictionary[StringName, int] = {}
	for ring_index: int in range(SAMPLE_RING_COUNT):
		## Inspect almost the complete authored ellipse.  The periphery is still
		## inside the declared pocket and is where a broad card can legitimately
		## preserve the existing scenery's focal center and keep a clear shoulder.
		var radius_factor: float = 0.04 + float(ring_index) / float(SAMPLE_RING_COUNT - 1) * 0.90
		for spoke_index: int in range(SAMPLE_SPOKE_COUNT):
			var angle: float = fposmod(
				float(spoke_index) * 2.399963 + float(ring_index) * 0.37,
				TAU
			)
			var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
				cos(angle) * pocket.z * radius_factor,
				sin(angle) * pocket.w * radius_factor
			)
			var rejection: StringName = _get_candidate_rejection(candidate, card_radius)
			if rejection.is_empty():
				return candidate
			rejection_counts[rejection] = rejection_counts.get(rejection, 0) + 1
	_last_rejection_counts = rejection_counts
	print("WILD ATLAS POCKET REJECTION | center=(%.1f, %.1f) radius=%.3f reasons=%s" % [
		pocket.x, pocket.y, card_radius, JSON.stringify(rejection_counts),
	])
	return Vector2.INF


func _is_render_clear_candidate(candidate: Vector2, card_radius: float) -> bool:
	return _get_candidate_rejection(candidate, card_radius).is_empty()


func _get_candidate_rejection(candidate: Vector2, card_radius: float) -> StringName:
	if not candidate.is_finite() or card_radius <= 0.0:
		return &"invalid"
	## The trial card is deliberately a nonblocking ground-layer visual.  Its
	## complete radius must stay inside the playable rectangle, while its origin
	## must remain walkable.  The card is also tested, over its whole radius,
	## against every colliding `WorldObstacle2D` footprint: the card draws at
	## z_index -5 and every obstacle sprite at 5, so a card that overlaps a
	## fence, wreck or trunk footprint is drawn under it and the capture holds
	## no evidence about the card at all - the first run of this gate placed
	## pocket 0 under a chain-link fence and a covered car for exactly that
	## reason.  The footprint is the collision shape rather than the sprite, so
	## a root card may still sit under a canopy edge, which is where a root
	## card naturally belongs.  The explicit visual envelopes below remain
	## full-card tests.
	if not world_map.get_playable_rect().grow(-card_radius).has_point(candidate):
		return &"playable_bounds"
	if not world_map.is_position_walkable(candidate, 0.0):
		return &"origin_walkability"
	if _minimum_obstacle_clearance(candidate, card_radius) < 0.0:
		return &"obstacle_footprint"
	var road_card_clearance: float = world_map.get_minimum_road_edge_distance(candidate) - card_radius
	if road_card_clearance < REQUIRED_ROAD_CARD_CLEARANCE:
		return &"road_card_clearance"
	if _minimum_circular_clearance(candidate, card_radius, _ambient_positions, _ambient_radii) < 0.0:
		return &"ambient_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _accent_positions, _accent_radii) < 0.0:
		return &"accent_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _rubble_positions, _rubble_radii) < 0.0:
		return &"rubble_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _moss_positions, _moss_radii) < 0.0:
		return &"moss_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _prop_positions, _prop_radii) < 0.0:
		return &"prop_envelope"
	if _minimum_rect_clearance(candidate, card_radius, _crack_envelopes) < 0.0:
		return &"crack_envelope"
	## GroundCover is intentionally not tested as an exclusion: it is the visual
	## substrate on which this hypothetical card must sit, rather than a competing
	## macro silhouette to erase.
	return &""


func _get_patch_metadata(
	pocket_index: int,
	pocket: Vector4,
	candidate: Vector2,
	card_radius: float
) -> Dictionary:
	var road_edge_distance: float = world_map.get_minimum_road_edge_distance(candidate)
	return {
		"pocket_index": pocket_index,
		"pocket": [pocket.x, pocket.y, pocket.z, pocket.w],
		"position": [candidate.x, candidate.y],
		"card_radius": snappedf(card_radius, 0.001),
		"origin_walkable": world_map.is_position_walkable(candidate, 0.0),
		"obstacle_footprint_clearance": snappedf(_minimum_obstacle_clearance(candidate, card_radius), 0.001),
		"full_card_inside_playable_rect": world_map.get_playable_rect().grow(-card_radius).has_point(candidate),
		"road_edge_distance": snappedf(road_edge_distance, 0.001),
		"road_card_clearance": snappedf(road_edge_distance - card_radius, 0.001),
		"ambient_clearance": snappedf(
			_minimum_circular_clearance(candidate, card_radius, _ambient_positions, _ambient_radii), 0.001
		),
		"wilderness_accent_clearance": snappedf(
			_minimum_circular_clearance(candidate, card_radius, _accent_positions, _accent_radii), 0.001
		),
		"background_decor_clearance": {
			"rubble": snappedf(
				_minimum_circular_clearance(candidate, card_radius, _rubble_positions, _rubble_radii), 0.001
			),
			"cracks": snappedf(_minimum_rect_clearance(candidate, card_radius, _crack_envelopes), 0.001),
			"moss": snappedf(
				_minimum_circular_clearance(candidate, card_radius, _moss_positions, _moss_radii), 0.001
			),
			"props": snappedf(
				_minimum_circular_clearance(candidate, card_radius, _prop_positions, _prop_radii), 0.001
			),
		},
		"ground_cover_policy": "retained_as_substrate_not_used_as_an_exclusion_envelope",
	}


func _minimum_circular_clearance(
	candidate: Vector2,
	card_radius: float,
	positions: PackedVector2Array,
	radii: PackedFloat32Array
) -> float:
	var minimum_clearance: float = 1000000.0
	for index: int in range(positions.size()):
		minimum_clearance = minf(
			minimum_clearance,
			candidate.distance_to(positions[index]) - card_radius - radii[index]
		)
	return minimum_clearance


func _minimum_rect_clearance(
	candidate: Vector2,
	card_radius: float,
	envelopes: Array[Rect2]
) -> float:
	var minimum_clearance: float = 1000000.0
	for envelope: Rect2 in envelopes:
		var nearest_point: Vector2 = Vector2(
			clampf(candidate.x, envelope.position.x, envelope.end.x),
			clampf(candidate.y, envelope.position.y, envelope.end.y)
		)
		minimum_clearance = minf(
			minimum_clearance,
			candidate.distance_to(nearest_point) - card_radius
		)
	return minimum_clearance


func _minimum_obstacle_clearance(candidate: Vector2, card_radius: float) -> float:
	## Exact distance from the card disc to each obstacle's own collision
	## footprint - a rotated rectangle or a circle - rather than to its
	## axis-aligned world bounds, so a rotated fence run is not padded into a
	## square that would reject candidates the sprite never reaches.
	var minimum_clearance: float = 1000000.0
	for obstacle: WorldObstacle2D in _obstacles:
		var local_point: Vector2 = (candidate - obstacle.position).rotated(-obstacle.rotation)
		var distance: float
		if obstacle.get_shape_kind() == WorldObstacle2D.ShapeKind.CIRCLE:
			distance = local_point.length() - obstacle.collision_radius
		else:
			var outside: Vector2 = Vector2(
				maxf(absf(local_point.x) - obstacle.half_size.x, 0.0),
				maxf(absf(local_point.y) - obstacle.half_size.y, 0.0)
			)
			distance = outside.length()
		minimum_clearance = minf(minimum_clearance, distance - card_radius)
	return minimum_clearance


func _spawn_scale_references(initial_position: Vector2) -> bool:
	_player = PLAYER_SCENE.instantiate() as PlayerAvatar
	if _player == null:
		_fail("could not instantiate baked player scale reference")
		return false
	_player.configure(1, &"heikki", initial_position + Vector2(-124.0, 50.0), false)
	y_sort_world.add_child(_player)
	_player.set_aim_direction(Vector2.RIGHT, false)
	var kinetic_definition: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_KINETIC)
	if kinetic_definition == null:
		_fail("could not resolve the live T1 Kinetic scale reference")
		return false
	_tower = PlacedStructure2D.new()
	_tower.configure(9201, kinetic_definition, 1, initial_position + Vector2(124.0, 54.0), false)
	y_sort_world.add_child(_tower)
	return true


func _verify_contracts(required_card_radius: float) -> bool:
	if _card_a == null or _card_b == null or _player == null or _tower == null:
		_fail("review cards or live scale references were not constructed")
		return false
	if _card_a.get_base_radius() <= 0.0 or _card_b.get_base_radius() <= 0.0:
		_fail("transformed child-rect card radius was not calculated")
		return false
	if not is_equal_approx(required_card_radius, _card_b.get_card_radius()):
		_fail("candidate clearance must use the larger recipe B card")
		return false
	if not _player.uses_baked_actor_presentation():
		_fail("scale reference did not bind the live baked player presentation")
		return false
	if _tower.get_structure_visual() == null:
		_fail("scale reference did not construct the live T1 Kinetic visual")
		return false
	if WILD_ATLAS.get_width() <= 0 or WILD_ATLAS.get_height() <= 0:
		_fail("current runtime wild atlas has no renderable dimensions")
		return false
	return true


func _capture_recipe(
	patch_index: int,
	patch: Dictionary,
	recipe: int,
	phase: String,
	captures: Array[Dictionary],
	day_grayscale_tiles: Array[Image]
) -> bool:
	var patch_position: Vector2 = _dictionary_position(patch, &"position")
	if not patch_position.is_finite():
		return _fail_bool("patch %d has no finite world position" % patch_index)
	# Output names carry the authored pocket index so a skipped pocket leaves a gap
	# rather than renumbering every later capture; the grayscale sheet tile stays ordinal.
	var pocket_index: int = int(patch.get("pocket_index", patch_index))
	var active_card: WildAtlasReviewCard = (
		_card_a if recipe == ReviewRecipe.ROOTS_AND_BRANCHES else _card_b
	)
	_card_a.visible = active_card == _card_a
	_card_b.visible = active_card == _card_b
	_card_a.position = patch_position
	_card_b.position = patch_position
	_place_scale_references(patch_position)
	camera.position = patch_position
	camera.zoom = Vector2.ONE * GAMEPLAY_CAMERA_ZOOM
	if phase == "day":
		lighting.color = NightAtmosphere2D.DAY_COLOR
		atmosphere.set_night_active(false, true)
		_player.set_aim_direction(Vector2.RIGHT, false)
	else:
		atmosphere.register_player(_player)
		atmosphere.register_structure(_tower)
		atmosphere.set_night_active(true, true)
		_player.set_aim_direction(Vector2.UP, true)
		if not _player.is_flashlight_enabled() or not _tower.has_security_light():
			return _fail_bool("night capture did not enable the real flashlight/security-light path")
		var security_light: PointLight2D = _tower.get_node_or_null(^"SecurityLight") as PointLight2D
		if security_light == null or not security_light.enabled:
			return _fail_bool("night capture did not enable the live T1 Kinetic security light")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail_bool("empty viewport for pocket %d recipe %s %s" % [
			patch_index, _recipe_name(recipe), phase,
		])
	if not _normalize_to_logical_capture(image):
		return false
	var output_stem: String = "pocket_%02d_%s_%s" % [pocket_index, _recipe_name(recipe), phase]
	var output_path: String = "%s/%s.png" % [OUTPUT_DIRECTORY, output_stem]
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail_bool("could not save %s: %s" % [output_path, error_string(save_error)])
	var capture: Dictionary = {
		"pocket_index": pocket_index,
		"position": [patch_position.x, patch_position.y],
		"recipe": _recipe_name(recipe),
		"phase": phase,
		"output": output_path,
		"card_radius": snappedf(active_card.get_card_radius(), 0.001),
	}
	## Every recipe-B night receives its own grayscale proof; recipe B's ten day
	## images are collected into one compact contact sheet after the loop.
	if recipe == ReviewRecipe.ROOTS_BRANCHES_AND_SHRUB:
		var grayscale: Image = _to_grayscale(image)
		if phase == "night":
			var grayscale_path: String = "%s/%s_grayscale.png" % [OUTPUT_DIRECTORY, output_stem]
			if not _save_image(grayscale, grayscale_path):
				return false
			capture["grayscale_output"] = grayscale_path
		else:
			day_grayscale_tiles.append(grayscale)
			capture["grayscale_sheet"] = DAY_GRAYSCALE_SHEET_OUTPUT_PATH
			capture["grayscale_sheet_tile_index"] = patch_index
	captures.append(capture)
	return true


func _place_scale_references(patch_position: Vector2) -> void:
	var player_position: Vector2 = patch_position + Vector2(-124.0, 50.0)
	_player.apply_authoritative_state(player_position, Vector2.ZERO)
	_player.global_position = player_position
	_tower.global_position = patch_position + Vector2(124.0, 54.0)


func _normalize_to_logical_capture(image: Image) -> bool:
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		return _fail_bool("native viewport is %s; expected an integer scale of %s" % [
			_native_capture_size, LOGICAL_CAPTURE_SIZE,
		])
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		return _fail_bool("native viewport scale is non-uniform")
	_native_capture_scale = horizontal_scale
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		return _fail_bool("logical capture did not resolve to 480x270")
	image.convert(Image.FORMAT_RGBA8)
	return true


func _to_grayscale(source: Image) -> Image:
	var grayscale: Image = source.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	return grayscale


func _save_grayscale_sheet(images: Array[Image], output_path: String) -> bool:
	var rows: int = ceili(float(images.size()) / float(DAY_GRAYSCALE_SHEET_COLUMNS))
	var sheet_size: Vector2i = Vector2i(
		DAY_GRAYSCALE_TILE_SIZE.x * DAY_GRAYSCALE_SHEET_COLUMNS,
		DAY_GRAYSCALE_TILE_SIZE.y * rows
	)
	var sheet: Image = Image.create(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101513"))
	for image_index: int in range(images.size()):
		var tile: Image = images[image_index].duplicate()
		tile.resize(
			DAY_GRAYSCALE_TILE_SIZE.x,
			DAY_GRAYSCALE_TILE_SIZE.y,
			Image.INTERPOLATE_LANCZOS
		)
		var destination: Vector2i = Vector2i(
			(image_index % DAY_GRAYSCALE_SHEET_COLUMNS) * DAY_GRAYSCALE_TILE_SIZE.x,
			(image_index / DAY_GRAYSCALE_SHEET_COLUMNS) * DAY_GRAYSCALE_TILE_SIZE.y
		)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), destination)
	return _save_image(sheet, output_path)


func _save_image(image: Image, output_path: String) -> bool:
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail_bool("could not save %s: %s" % [output_path, error_string(save_error)])
	return true


func _write_metadata(
	patches: Array[Dictionary],
	captures: Array[Dictionary],
	required_card_radius: float
) -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_human_visual_veto",
		"source_atlas": "res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png",
		"source_policy": "current installed runtime atlas was sampled directly; no Addons or external raw asset was copied into runtime closure",
		"capture_scope": "presentation-only test sibling; no collision, flow field, authority, scene export dependency, or runtime placement changed",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"pocket_contract": "all ten WorldAmbientScenery2D.WILDERNESS_POCKETS were assessed in order with no early exit after a convenient subset; every pocket that can host the whole card is captured, and a pocket that cannot is recorded under unhostable_pockets with its rejection census and the colliding obstacles reaching into it, up to maximum_unhostable_pockets",
		"pocket_count": patches.size(),
		"unhostable_pocket_count": _unhostable_pockets.size(),
		"maximum_unhostable_pockets": MAXIMUM_UNHOSTABLE_POCKETS,
		"unhostable_pockets": _unhostable_pockets,
		"patches": patches,
		"recipes": {
			"a_roots_and_branches": {
				"card_base_radius_from_transformed_child_rects": snappedf(_card_a.get_base_radius(), 0.001),
				"card_radius_with_32px_margin": snappedf(_card_a.get_card_radius(), 0.001),
				"transformed_bounds": _rect_to_array(_card_a.get_visual_bounds()),
				"frames": _card_a.get_frame_records(),
			},
			"b_roots_branches_and_shrub": {
				"card_base_radius_from_transformed_child_rects": snappedf(_card_b.get_base_radius(), 0.001),
				"card_radius_with_32px_margin": snappedf(_card_b.get_card_radius(), 0.001),
				"transformed_bounds": _rect_to_array(_card_b.get_visual_bounds()),
				"frames": _card_b.get_frame_records(),
			},
		},
		"candidate_clearance_radius": snappedf(required_card_radius, 0.001),
		"required_road_card_clearance": REQUIRED_ROAD_CARD_CLEARANCE,
		"clearance_contract": "candidate origin remains walkable because the trial is a nonblocking ground-layer card; the full transformed-card radius remains inside the playable rectangle, is subtracted from road-edge distance, is clear of every colliding WorldObstacle2D collision footprint so no z_index 5 obstacle sprite is drawn over the z_index -5 card, and is tested against explicit ambient, wilderness-accent, rubble, crack, moss, and prop render envelopes",
		"ground_cover_policy": "GroundCover is intentionally retained as substrate and not cleared. This gate prevents macro-card occlusion, not natural floor density.",
		"capture_count": captures.size(),
		"captures": captures,
		"grayscale_contract": "every hosted pocket's recipe-B night capture has an individual grayscale output; one recipe-B day contact sheet covers every hosted pocket in pocket order",
		"day_grayscale_sheet": DAY_GRAYSCALE_SHEET_OUTPUT_PATH,
		"night_lighting": "NightAtmosphere2D registered the real baked-player flashlight and live T1 Kinetic security light before every night capture",
		"review_requirement": "Human art-direction veto is mandatory. Green contracts and pixels do not certify Android performance, touch ergonomics, LAN behavior, motion readability, or premium quality, and do not authorize runtime promotion.",
	}
	var metadata_file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(METADATA_OUTPUT_PATH), FileAccess.WRITE
	)
	if metadata_file == null:
		_fail("could not write existing wild-atlas metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


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


func _recipe_name(recipe: int) -> String:
	return "recipe_a" if recipe == ReviewRecipe.ROOTS_AND_BRANCHES else "recipe_b"


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("EXISTING WILD ATLAS CONTEXT FAILED: %s" % message)
	get_tree().quit(1)
