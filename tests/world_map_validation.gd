extends SceneTree
## Headless contract gate for the deterministic 14x14 tactical world.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const GAME_WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
const NETWORK_PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const EXPECTED_GRID_SIZE: int = 14
const EXPECTED_CELL_SIZE: float = 2048.0
const EXPECTED_HALF_EXTENT: float = 14336.0
const EXPECTED_WORLD_SIZE: float = 28672.0
const EXPECTED_GROUND_Z: int = -20
const EXPECTED_DECOR_Z: int = -5
const EXPECTED_AMBIENT_SCENERY_Z: int = -4
const EXPECTED_WILDERNESS_ACCENT_Z: int = -5
const EXPECTED_ENTITY_Z: int = 5
const EXPECTED_BOUNDARY_COUNT: int = 4
const EXPECTED_FLOW_DIMENSION: int = 112
const EXPECTED_NATURE_TILES_PER_MACRO_CELL: int = 4
const EXPECTED_NATURE_VARIANT_MINIMUM: int = 5
const EXPECTED_NATURE_ATLAS_PATH: String = "res://assets/tiles/claw_forest_ground.png"
const EXPECTED_TREE_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
)
const EXPECTED_DENSE_DECOR_ZONE_TOTALS: Array[int] = [265, 193, 116, 116, 286, 124]
const EXPECTED_AMBIENT_SCENERY_ZONE_TOTALS: Array[int] = [96, 72, 48, 48, 236, 92, 48]
const EXPECTED_AMBIENT_SCENERY_TOTAL: int = 640
const EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL: int = 24
const WILDERNESS_ACCENT_MINIMUM_SPAN: float = 112.0
const WILDERNESS_ACCENT_MAXIMUM_SPAN: float = 160.0
const WILDERNESS_ACCENT_CAMP_CLEAR_RADIUS: float = 1760.0
const WILDERNESS_ACCENT_ROAD_CLEARANCE: float = 480.0
const EXPECTED_WILDERNESS_ACCENT_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
const EXPECTED_FLOW_FIELD_MASK_HASH: String = (
	"1260828a95ccfe1278d512533f61482d57fccc719de54c6d55c40d1ab70747ed"
)
const AMBIENT_SCENERY_CAMP_CLEAR_RADIUS: float = 1760.0
const AMBIENT_SCENERY_ROAD_CLEARANCE: float = 480.0
const AMBIENT_SCENERY_CONNECTOR_ROAD_CLEARANCE: float = 360.0
## Forest and wilderness dress their own tracks closer than the districts do;
## see `WorldAmbientScenery2D.FOREST_ROAD_EDGE_CLEARANCE` for why a layer that
## cannot occlude a gameplay participant does not owe a road the urban verge.
const AMBIENT_SCENERY_FOREST_ROAD_CLEARANCE: float = 300.0
const AMBIENT_SCENERY_STRUCTURAL_SEPARATION: float = 340.0
const AMBIENT_SCENERY_SCRIPT: Script = preload("res://src/world/world_ambient_scenery_2d.gd")
const WILDERNESS_ACCENT_SCRIPT: Script = preload("res://src/world/world_wilderness_accent_2d.gd")
const PLAYER_RADIUS: float = 34.0
const MAX_ROAD_CHUNK_SPAN: float = 4640.0
const MAX_DECOR_CHUNK_SPAN: float = 4896.0
const MAX_AMBIENT_SCENERY_CHUNK_SPAN: float = 5500.0
const MAX_WILDERNESS_ACCENT_CHUNK_SPAN: float = 4800.0
const CAMP_ROUTE_MARGIN: float = 96.0
const EXPECTED_STARTING_CAMP_POSITION: Vector2 = Vector2(9950.0, 2400.0)
const EXPECTED_STARTING_CAMP_ROAD_EDGE_DISTANCE: float = 2130.0
const COOP_SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(-220.0, 285.0),
	Vector2(-75.0, 380.0),
	Vector2(70.0, 285.0),
	Vector2(215.0, 380.0),
]
const STARTER_RESOURCE_OFFSETS: Array[Vector2] = [
	Vector2(390.0, 120.0),
	Vector2(-410.0, 150.0),
	Vector2(130.0, -430.0),
]
const EXPECTED_CAMP_SATELLITE_OFFSETS: Dictionary = {
	&"StartingCampBedding": Vector2(-650.0, -300.0),
	&"StartingCampSupplyCache": Vector2(350.0, 650.0),
	&"StartingCampMedicalCache": Vector2(0.0, 720.0),
}
const VILLAGE_DRESSING_MINIMUM_ROAD_EDGE_CLEARANCE: float = 520.0
const EXPECTED_VILLAGE_DRESSING: Dictionary = {
	&"WestVillageScrapCache": {
		&"position": Vector2(-9300.0, 8200.0),
		&"kind": WorldObstacle2D.VisualKind.SCRAP_PILE,
		&"biome": BesprenWorldMap2D.Biome.VILLAGE_WEST,
	},
	&"WestVillageMossRock": {
		&"position": Vector2(-6750.0, 8450.0),
		&"kind": WorldObstacle2D.VisualKind.MOSSY_ROCK,
		&"biome": BesprenWorldMap2D.Biome.VILLAGE_WEST,
	},
	&"WestVillageFallenLog": {
		&"position": Vector2(-9300.0, 8950.0),
		&"kind": WorldObstacle2D.VisualKind.FALLEN_LOG,
		&"biome": BesprenWorldMap2D.Biome.VILLAGE_WEST,
	},
	&"EastVillageVehicleWreck": {
		&"position": Vector2(9550.0, 8300.0),
		&"kind": WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		&"biome": BesprenWorldMap2D.Biome.VILLAGE_EAST,
	},
	&"EastVillageScrapCache": {
		&"position": Vector2(6850.0, 8200.0),
		&"kind": WorldObstacle2D.VisualKind.SCRAP_PILE,
		&"biome": BesprenWorldMap2D.Biome.VILLAGE_EAST,
	},
	&"EastVillageMossRock": {
		&"position": Vector2(9650.0, 9000.0),
		&"kind": WorldObstacle2D.VisualKind.MOSSY_ROCK,
		&"biome": BesprenWorldMap2D.Biome.VILLAGE_EAST,
	},
}
const EXPECTED_BIOME_COUNTS: Array[int] = [
	78,
	25,
	16,
	16,
	16,
	45,
]

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world_map: BesprenWorldMap2D = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	_check(world_map != null, "World map scene instantiates as BesprenWorldMap2D")
	if world_map == null:
		_finish()
		return
	root.add_child(world_map)
	await process_frame
	world_map.ensure_built()

	_validate_dimensions(world_map)
	_validate_biomes(world_map)
	_validate_render_layers(world_map)
	_validate_gameplay_entity_layers()
	_validate_collision_contract(world_map)
	_validate_flow_field(world_map)
	_validate_motion_resolver(world_map)

	world_map.queue_free()
	await process_frame
	_finish()


func _validate_dimensions(world_map: BesprenWorldMap2D) -> void:
	_check(BesprenWorldMap2D.GRID_SIZE == EXPECTED_GRID_SIZE, "Macro grid is exactly 14x14")
	_check(is_equal_approx(BesprenWorldMap2D.CELL_SIZE, EXPECTED_CELL_SIZE), "Macro cell size is exactly 2048")
	_check(
		is_equal_approx(BesprenWorldMap2D.PLAYABLE_HALF_EXTENT, EXPECTED_HALF_EXTENT),
		"Playable half extent is exactly 14336"
	)
	_check(is_equal_approx(BesprenWorldMap2D.WORLD_SIZE, EXPECTED_WORLD_SIZE), "World canvas size is exactly 28672")
	_check(
		BesprenWorldMap2D.GRID_SIZE * BesprenWorldMap2D.CELL_SIZE == BesprenWorldMap2D.WORLD_SIZE,
		"Fourteen macro cells span the complete world canvas"
	)
	_check(
		world_map.get_world_size().is_equal_approx(Vector2(EXPECTED_WORLD_SIZE, EXPECTED_WORLD_SIZE)),
		"World API reports a 28672x28672 canvas"
	)
	_check(
		BesprenWorldMap2D.STARTING_CAMP_POSITION.is_equal_approx(
			EXPECTED_STARTING_CAMP_POSITION
		),
		"Starting camp owns the exact secluded east-forest position (9950, 2400)"
	)
	_check(
		is_equal_approx(
			world_map.get_minimum_asphalt_edge_distance(
				BesprenWorldMap2D.STARTING_CAMP_POSITION
			),
			EXPECTED_STARTING_CAMP_ROAD_EDGE_DISTANCE
		),
		"Starting camp center is exactly 2130 world units from the nearest asphalt edge"
	)
	_check(
		world_map.get_minimum_asphalt_edge_distance(
			BesprenWorldMap2D.STARTING_CAMP_POSITION
		) - BesprenWorldMap2D.CORE_COLLISION_RADIUS
		>= BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE,
		"Complete Base footprint preserves at least 1600 units from every asphalt edge"
	)
	_check(
		world_map.get_minimum_road_edge_distance(
			BesprenWorldMap2D.STARTING_CAMP_POSITION
		) < BesprenWorldMap2D.STARTING_CAMP_OPEN_RADIUS,
		"The dirt spur reaches the camp bowl"
	)
	var expected_rect: Rect2 = Rect2(
		Vector2(-EXPECTED_HALF_EXTENT, -EXPECTED_HALF_EXTENT),
		Vector2(EXPECTED_WORLD_SIZE, EXPECTED_WORLD_SIZE)
	)
	_check(_rect_is_equal_approx(world_map.get_playable_rect(), expected_rect), "Playable rectangle is centered on the 2D origin")


func _validate_biomes(world_map: BesprenWorldMap2D) -> void:
	var regions: Dictionary[StringName, Rect2] = world_map.get_biome_regions()
	var expected_regions: Dictionary[StringName, Rect2] = {
		&"kaupunki": Rect2(Vector2(-12288.0, -12288.0), Vector2(10240.0, 10240.0)),
		&"ostari": Rect2(Vector2(0.0, -10240.0), Vector2(8192.0, 8192.0)),
		&"kyla_west": Rect2(Vector2(-12288.0, 4096.0), Vector2(8192.0, 8192.0)),
		&"kyla_east": Rect2(Vector2(4096.0, 4096.0), Vector2(8192.0, 8192.0)),
		&"metsa_perimeter": world_map.get_playable_rect(),
	}
	_check(regions.size() == expected_regions.size(), "Biome API exposes the five tactical blueprint regions")
	var all_regions_match: bool = true
	for region_name: StringName in expected_regions:
		if not regions.has(region_name):
			all_regions_match = false
			continue
		if not _rect_is_equal_approx(regions[region_name], expected_regions[region_name]):
			all_regions_match = false
	_check(all_regions_match, "Kaupunki, Ostari, both Kylat, and Metsa regions match the blueprint")

	var counted_cells: int = 0
	var every_cell_has_valid_biome: bool = true
	for biome: int in range(BesprenWorldMap2D.Biome.size()):
		var biome_count: int = world_map.get_biome_cell_count(biome)
		counted_cells += biome_count
		_check(
			biome_count == EXPECTED_BIOME_COUNTS[biome],
			"Biome %s owns exactly %d cells" % [
				String(BesprenWorldMap2D.Biome.keys()[biome]),
				EXPECTED_BIOME_COUNTS[biome],
			]
		)
	for row: int in range(EXPECTED_GRID_SIZE):
		for column: int in range(EXPECTED_GRID_SIZE):
			var biome_at_cell: int = world_map.get_biome_at_cell(Vector2i(column, row))
			if biome_at_cell < 0 or biome_at_cell >= BesprenWorldMap2D.Biome.size():
				every_cell_has_valid_biome = false
	_check(counted_cells == EXPECTED_GRID_SIZE * EXPECTED_GRID_SIZE, "Biome counts cover all 196 macro cells")
	_check(every_cell_has_valid_biome, "Every in-bounds macro cell resolves to one valid biome")
	_check(world_map.get_biome_at_cell(Vector2i(-1, 0)) == -1, "Out-of-bounds macro cells are rejected")
	_check(world_map.get_biome_at_cell(Vector2i(1, 1)) == BesprenWorldMap2D.Biome.CITY, "Kaupunki cell resolves to City")
	_check(world_map.get_biome_at_cell(Vector2i(7, 2)) == BesprenWorldMap2D.Biome.MALL, "Ostari cell resolves to Mall")
	_check(world_map.get_biome_at_cell(Vector2i(1, 9)) == BesprenWorldMap2D.Biome.VILLAGE_WEST, "Western Kyla cell resolves correctly")
	_check(world_map.get_biome_at_cell(Vector2i(9, 9)) == BesprenWorldMap2D.Biome.VILLAGE_EAST, "Eastern Kyla cell resolves correctly")
	_check(world_map.get_biome_at_cell(Vector2i(0, 0)) == BesprenWorldMap2D.Biome.FOREST, "Perimeter cell resolves to Metsa")
	_check(world_map.get_biome_at_cell(Vector2i(6, 6)) == BesprenWorldMap2D.Biome.WILDERNESS, "Open connector cell resolves to Wilderness")


func _validate_render_layers(world_map: BesprenWorldMap2D) -> void:
	var ground_tiles: TileMapLayer = world_map.get_node_or_null("GroundTiles") as TileMapLayer
	var terrain_details: Node2D = world_map.get_node_or_null("TerrainDetails") as Node2D
	var terrain_tiles: TileMapLayer = world_map.get_node_or_null("TerrainDetails/TerrainTiles") as TileMapLayer
	var road_network: WorldRoadNetwork2D = world_map.get_node_or_null("TerrainDetails/RoadNetwork") as WorldRoadNetwork2D
	var background_decor: WorldBackgroundDecor2D = world_map.get_node_or_null("BackgroundDecor") as WorldBackgroundDecor2D
	var wilderness_accent: Node2D = world_map.get_node_or_null("WildernessAccent") as Node2D
	var ambient_scenery: Node2D = world_map.get_node_or_null("AmbientScenery") as Node2D
	var structures: Node2D = world_map.get_node_or_null("Structures") as Node2D
	_check(ground_tiles != null, "GroundTiles layer exists")
	_check(terrain_details != null, "TerrainDetails layer exists")
	_check(terrain_tiles != null, "TerrainTiles layer exists")
	_check(road_network != null, "RoadNetwork layer exists")
	_check(background_decor != null, "BackgroundDecor layer exists")
	_check(wilderness_accent != null, "WildernessAccent visual-only layer exists")
	_check(ambient_scenery != null, "AmbientScenery visual-only layer exists")
	_check(structures != null, "Structures entity container exists")
	if ground_tiles != null:
		_check_absolute_z(ground_tiles, EXPECTED_GROUND_Z, "GroundTiles")
		_check(ground_tiles.get_used_cells().size() == EXPECTED_GRID_SIZE * EXPECTED_GRID_SIZE, "GroundTiles covers all 196 macro cells")
	if terrain_details != null:
		_check_absolute_z(terrain_details, EXPECTED_GROUND_Z, "TerrainDetails")
	if terrain_tiles != null:
		_check_absolute_z(terrain_tiles, EXPECTED_GROUND_Z, "TerrainTiles")
		_validate_nature_tiles(world_map, terrain_tiles)
	if road_network != null:
		_check_absolute_z(road_network, EXPECTED_GROUND_Z, "RoadNetwork")
		_check(road_network.get_route_count() == 10, "Road network exposes eight routes, the camp spur, and the north threat arm")
		_check(
			road_network.get_dirt_flags().size() == 10
			and road_network.get_dirt_flags()[8] == 1
			and road_network.get_dirt_flags()[9] == 1,
			"The camp spur and the north threat arm are dirt"
		)
		var routes_are_valid: bool = true
		for route: PackedVector2Array in road_network.get_routes():
			if route.size() < 2:
				routes_are_valid = false
		_check(routes_are_valid, "Every road route contains at least one traversable segment")
		_validate_road_render_chunks(road_network)
	if background_decor != null:
		_check_absolute_z(background_decor, EXPECTED_DECOR_Z, "BackgroundDecor")
		_check(
			background_decor.get_decoration_count() == WorldBackgroundDecor2D.TOTAL_DECORATION_COUNT,
			"Background decor batches rubble, cracks, moss, and nine prop families"
		)
		_validate_decor_render_chunks(background_decor)
	if wilderness_accent != null:
		_check_absolute_z(wilderness_accent, EXPECTED_WILDERNESS_ACCENT_Z, "WildernessAccent")
		_validate_wilderness_accent(world_map, wilderness_accent)
	if ambient_scenery != null:
		_check_absolute_z(ambient_scenery, EXPECTED_AMBIENT_SCENERY_Z, "AmbientScenery")
		_validate_ambient_scenery(world_map, ambient_scenery)
	_check(world_map.y_sort_enabled, "World map root explicitly enables Y-sort")
	if structures != null:
		_check_absolute_z(structures, EXPECTED_ENTITY_Z, "Structures")
		_check(structures.y_sort_enabled, "Structures container explicitly enables Y-sort")


func _validate_road_render_chunks(road_network: WorldRoadNetwork2D) -> void:
	var chunks: Array[WorldRoadSegmentChunk2D] = road_network.get_render_chunks()
	var bounds: Array[Rect2] = road_network.get_render_chunk_bounds()
	_check(chunks.size() > road_network.get_route_count(), "Road rendering is split across multiple bounded CanvasItems")
	_check(bounds.size() == chunks.size(), "Every road render chunk exposes one culling bound")
	var every_chunk_is_bounded: bool = not chunks.is_empty()
	var every_chunk_uses_ground_z: bool = not chunks.is_empty()
	for chunk_index: int in range(chunks.size()):
		var chunk_bounds: Rect2 = bounds[chunk_index]
		if (
			chunk_bounds.size.x > MAX_ROAD_CHUNK_SPAN
			or chunk_bounds.size.y > MAX_ROAD_CHUNK_SPAN
			or chunk_bounds.size.x >= EXPECTED_WORLD_SIZE
			or chunk_bounds.size.y >= EXPECTED_WORLD_SIZE
		):
			every_chunk_is_bounded = false
		if chunks[chunk_index].z_index != EXPECTED_GROUND_Z or chunks[chunk_index].z_as_relative:
			every_chunk_uses_ground_z = false
	_check(every_chunk_is_bounded, "No road CanvasItem spans the 28672-unit world")
	_check(every_chunk_uses_ground_z, "Every road chunk stays on absolute terrain z=-20")


func _validate_decor_render_chunks(background_decor: WorldBackgroundDecor2D) -> void:
	var chunks: Array[WorldBackgroundDecorChunk2D] = background_decor.get_render_chunks()
	var bounds: Array[Rect2] = background_decor.get_render_chunk_bounds()
	var zone_counts: PackedInt32Array = background_decor.get_zone_decoration_counts()
	_check(
		background_decor.get_decoration_count() == WorldBackgroundDecor2D.TOTAL_DECORATION_COUNT
		and WorldBackgroundDecor2D.TOTAL_DECORATION_COUNT == 1100
		and Array(zone_counts) == EXPECTED_DENSE_DECOR_ZONE_TOTALS,
		"Every world zone receives its dense 1100-mark rubble, foliage, and prop allocation"
	)
	_check(chunks.size() > 1, "Background decorations are split across multiple regional CanvasItems")
	_check(bounds.size() == chunks.size(), "Every background render chunk exposes one culling bound")
	_check(
		background_decor.get_chunked_decoration_count() == background_decor.get_decoration_count(),
		"Regional decor chunks retain all 1100 deterministic decorations"
	)
	var every_chunk_is_bounded: bool = not chunks.is_empty()
	var every_chunk_uses_decor_z: bool = not chunks.is_empty()
	var every_chunk_uses_sleek_grade: bool = not chunks.is_empty()
	for chunk_index: int in range(chunks.size()):
		var chunk_bounds: Rect2 = bounds[chunk_index]
		if (
			chunk_bounds.size.x > MAX_DECOR_CHUNK_SPAN
			or chunk_bounds.size.y > MAX_DECOR_CHUNK_SPAN
			or chunk_bounds.size.x >= EXPECTED_WORLD_SIZE
			or chunk_bounds.size.y >= EXPECTED_WORLD_SIZE
		):
			every_chunk_is_bounded = false
		if chunks[chunk_index].z_index != EXPECTED_DECOR_Z or chunks[chunk_index].z_as_relative:
			every_chunk_uses_decor_z = false
		var grade_material: ShaderMaterial = chunks[chunk_index].material as ShaderMaterial
		if (
			grade_material == null
			or grade_material.shader == null
			or grade_material.shader.resource_path != "res://shaders/sleek_canvas_grade.gdshader"
		):
			every_chunk_uses_sleek_grade = false
	_check(every_chunk_is_bounded, "No background-decor CanvasItem spans the 28672-unit world")
	_check(every_chunk_uses_decor_z, "Every background chunk stays on absolute decor z=-5")
	_check(every_chunk_uses_sleek_grade, "Every prop batch uses the sleek mobile color-grade shader")
	var rubble_sizes: PackedFloat32Array = background_decor.get_rubble_sizes()
	var moss_sizes: PackedFloat32Array = background_decor.get_moss_sizes()
	var prop_sizes: PackedFloat32Array = background_decor.get_prop_sizes()
	var decor_size_metadata_is_sound: bool = (
		rubble_sizes.size() == background_decor.get_rubble_positions().size()
		and moss_sizes.size() == background_decor.get_moss_positions().size()
		and prop_sizes.size() == background_decor.get_prop_positions().size()
	)
	for size: float in rubble_sizes:
		if not is_finite(size) or size <= 0.0:
			decor_size_metadata_is_sound = false
	for size: float in moss_sizes:
		if not is_finite(size) or size <= 0.0:
			decor_size_metadata_is_sound = false
	for size: float in prop_sizes:
		if not is_finite(size) or size <= 0.0:
			decor_size_metadata_is_sound = false
	_check(
		decor_size_metadata_is_sound,
		"Background decor exposes finite read-only size metadata for visual-envelope review"
	)
	_check(
		WorldBackgroundDecor2D.CAMP_POSITION.is_equal_approx(
			BesprenWorldMap2D.STARTING_CAMP_POSITION
		),
		"Background-decor clearing follows the exact relocated camp position"
	)
	var camp_clear_radius_squared: float = WorldBackgroundDecor2D.CAMP_CLEAR_RADIUS * WorldBackgroundDecor2D.CAMP_CLEAR_RADIUS
	var all_forest_details_clear_camp: bool = true
	for moss_position: Vector2 in background_decor.get_moss_positions():
		if moss_position.distance_squared_to(BesprenWorldMap2D.STARTING_CAMP_POSITION) < camp_clear_radius_squared:
			all_forest_details_clear_camp = false
	for prop_position: Vector2 in background_decor.get_prop_positions():
		if prop_position.distance_squared_to(BesprenWorldMap2D.STARTING_CAMP_POSITION) < camp_clear_radius_squared:
			all_forest_details_clear_camp = false
	_check(
		all_forest_details_clear_camp,
		"Moss and prop scatter preserve the relocated camp's 1360-unit visual clearing"
	)

	var deterministic_copy: WorldBackgroundDecor2D = WorldBackgroundDecor2D.new()
	deterministic_copy.configure(
		BesprenWorldMap2D.PLAYABLE_HALF_EXTENT,
		BesprenWorldMap2D.WORLD_BUILD_SEED + 91
	)
	_check(
		deterministic_copy.get_rubble_positions() == background_decor.get_rubble_positions()
		and deterministic_copy.get_crack_starts() == background_decor.get_crack_starts()
		and deterministic_copy.get_crack_ends() == background_decor.get_crack_ends()
		and deterministic_copy.get_moss_positions() == background_decor.get_moss_positions()
		and deterministic_copy.get_rubble_sizes() == rubble_sizes
		and deterministic_copy.get_moss_sizes() == moss_sizes
		and deterministic_copy.get_prop_positions() == background_decor.get_prop_positions()
		and deterministic_copy.get_prop_sizes() == prop_sizes
		and deterministic_copy.get_prop_kinds() == background_decor.get_prop_kinds(),
		"Background chunking preserves the exact seeded layout and prop-family stream"
	)
	deterministic_copy.free()


func _validate_wilderness_accent(world_map: BesprenWorldMap2D, wilderness_accent: Node2D) -> void:
	var anchor_count_variant: Variant = wilderness_accent.call(&"get_anchor_count")
	var positions_variant: Variant = wilderness_accent.call(&"get_anchor_positions")
	var spans_variant: Variant = wilderness_accent.call(&"get_anchor_spans")
	var rotations_variant: Variant = wilderness_accent.call(&"get_anchor_rotations")
	var recipes_variant: Variant = wilderness_accent.call(&"get_anchor_recipes")
	var variants_variant: Variant = wilderness_accent.call(&"get_anchor_variants")
	var radii_variant: Variant = wilderness_accent.call(&"get_anchor_visual_radii")
	var frame_counts_variant: Variant = wilderness_accent.call(&"get_anchor_frame_counts")
	var chunks_variant: Variant = wilderness_accent.call(&"get_render_chunks")
	var bounds_variant: Variant = wilderness_accent.call(&"get_render_chunk_bounds")
	var chunked_anchor_count_variant: Variant = wilderness_accent.call(&"get_chunked_anchor_count")
	var frame_count_variant: Variant = wilderness_accent.call(&"get_frame_count")
	var positions: PackedVector2Array = PackedVector2Array()
	var spans: PackedFloat32Array = PackedFloat32Array()
	var rotations: PackedFloat32Array = PackedFloat32Array()
	var recipes: PackedInt32Array = PackedInt32Array()
	var variants: PackedInt32Array = PackedInt32Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var frame_counts: PackedInt32Array = PackedInt32Array()
	var chunks: Array = []
	var bounds: Array = []
	if positions_variant is PackedVector2Array:
		positions = positions_variant
	if spans_variant is PackedFloat32Array:
		spans = spans_variant
	if rotations_variant is PackedFloat32Array:
		rotations = rotations_variant
	if recipes_variant is PackedInt32Array:
		recipes = recipes_variant
	if variants_variant is PackedInt32Array:
		variants = variants_variant
	if radii_variant is PackedFloat32Array:
		radii = radii_variant
	if frame_counts_variant is PackedInt32Array:
		frame_counts = frame_counts_variant
	if chunks_variant is Array:
		chunks = chunks_variant
	if bounds_variant is Array:
		bounds = bounds_variant
	_check(
		anchor_count_variant is int
		and anchor_count_variant == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and positions.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and spans.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and rotations.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and recipes.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and variants.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and radii.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
		and frame_counts.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL,
		"WildernessAccent owns exactly 24 independent low-profile ecology anchors"
	)
	_check(
		chunks.size() > 1
		and bounds.size() == chunks.size()
		and chunked_anchor_count_variant is int
		and chunked_anchor_count_variant == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL,
		"WildernessAccent batches every anchor into bounded regional CanvasItems"
	)
	_check(
		frame_count_variant is int
		and frame_count_variant >= EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL * 2
		and frame_count_variant <= EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL * 4,
		"WildernessAccent keeps its Poly Haven moss-rock recipes inside the 2-4 frame mobile budget"
	)
	var every_anchor_is_safe: bool = positions.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
	var recipes_are_supported: bool = recipes.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
	var every_anchor_stays_inside_mobile_frame_budget: bool = (
		frame_counts.size() == EXPECTED_WILDERNESS_ACCENT_ANCHOR_TOTAL
	)
	for anchor_index: int in range(positions.size()):
		var position: Vector2 = positions[anchor_index]
		var in_pocket_variant: Variant = wilderness_accent.call(
			&"is_position_in_wilderness_pocket",
			position
		)
		if (
			not position.is_finite()
			or not in_pocket_variant is bool
			or not in_pocket_variant
			or position.distance_to(BesprenWorldMap2D.STARTING_CAMP_POSITION)
				< WILDERNESS_ACCENT_CAMP_CLEAR_RADIUS
			or world_map.get_minimum_road_edge_distance(position) < WILDERNESS_ACCENT_ROAD_CLEARANCE
			or not world_map.is_position_walkable(position, radii[anchor_index])
		):
			every_anchor_is_safe = false
		if (
			spans[anchor_index] < WILDERNESS_ACCENT_MINIMUM_SPAN
			or spans[anchor_index] > WILDERNESS_ACCENT_MAXIMUM_SPAN
			or not is_equal_approx(radii[anchor_index], spans[anchor_index] * 0.90 + 38.0)
			or recipes[anchor_index] < 0
			or recipes[anchor_index] >= 4
		):
			recipes_are_supported = false
		if frame_counts[anchor_index] < 2 or frame_counts[anchor_index] > 4:
			every_anchor_stays_inside_mobile_frame_budget = false
		for previous_index: int in range(anchor_index):
			if position.distance_to(positions[previous_index]) < 300.0:
				every_anchor_is_safe = false
	_check(
		every_anchor_is_safe,
		"Every wilderness anchor stays finite, pocket-bounded, obstacle-clear, camp-clear, and road-clear"
	)
	_check(
		recipes_are_supported,
		"WildernessAccent uses only bounded low-profile moss-rock recipe IDs and spans"
	)
	_check(
		every_anchor_stays_inside_mobile_frame_budget,
		"Every WildernessAccent anchor individually stays inside the 2-4 frame mobile budget"
	)
	var every_chunk_is_bounded: bool = not chunks.is_empty()
	var every_chunk_is_decor_z: bool = not chunks.is_empty()
	var every_chunk_uses_sleek_grade: bool = not chunks.is_empty()
	var every_chunk_uses_mipped_polyhaven_atlas: bool = not chunks.is_empty()
	for chunk_index: int in range(chunks.size()):
		var chunk: Node2D = chunks[chunk_index] as Node2D
		if chunk == null or not bounds[chunk_index] is Rect2:
			every_chunk_is_bounded = false
			every_chunk_is_decor_z = false
			every_chunk_uses_sleek_grade = false
			every_chunk_uses_mipped_polyhaven_atlas = false
			continue
		var chunk_bounds: Rect2 = bounds[chunk_index]
		if (
			chunk_bounds.size.x > MAX_WILDERNESS_ACCENT_CHUNK_SPAN
			or chunk_bounds.size.y > MAX_WILDERNESS_ACCENT_CHUNK_SPAN
			or chunk_bounds.size.x >= EXPECTED_WORLD_SIZE
			or chunk_bounds.size.y >= EXPECTED_WORLD_SIZE
		):
			every_chunk_is_bounded = false
		if chunk.z_index != EXPECTED_WILDERNESS_ACCENT_Z or chunk.z_as_relative:
			every_chunk_is_decor_z = false
		var grade_material: ShaderMaterial = chunk.material as ShaderMaterial
		if (
			grade_material == null
			or grade_material.shader == null
			or grade_material.shader.resource_path != "res://shaders/sleek_canvas_grade.gdshader"
		):
			every_chunk_uses_sleek_grade = false
		var source_texture_variant: Variant = chunk.call(&"get_source_texture")
		if (
			not source_texture_variant is Texture2D
			or (source_texture_variant as Texture2D).resource_path != EXPECTED_WILDERNESS_ACCENT_ATLAS_PATH
			or chunk.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		):
			every_chunk_uses_mipped_polyhaven_atlas = false
	_check(every_chunk_is_bounded, "No WildernessAccent CanvasItem spans the 28672-unit world")
	_check(every_chunk_is_decor_z, "Every WildernessAccent chunk stays behind ambient silhouettes at absolute z=-5")
	_check(every_chunk_uses_sleek_grade, "Every WildernessAccent batch reuses the shared mobile color grade")
	_check(
		every_chunk_uses_mipped_polyhaven_atlas,
		"Every WildernessAccent chunk reuses the shipped mipped CC0 Poly Haven atlas"
	)
	_check(
		not _subtree_has_physics(wilderness_accent),
		"WildernessAccent recursively owns no physics body, shape, obstacle, or navigation footprint"
	)
	_check(
		world_map.get_node_or_null("BackgroundDecor").get_index() < wilderness_accent.get_index()
		and wilderness_accent.get_index() < world_map.get_node_or_null("AmbientScenery").get_index(),
		"WildernessAccent draws after ground decor and before ambient tree/ruin silhouettes"
	)
	var deterministic_copy: Node2D = WILDERNESS_ACCENT_SCRIPT.new() as Node2D
	var deterministic_layout_matches: bool = deterministic_copy != null
	if deterministic_copy != null:
		deterministic_copy.call(
			&"configure",
			BesprenWorldMap2D.PLAYABLE_HALF_EXTENT,
			BesprenWorldMap2D.WORLD_BUILD_SEED + 173,
			BesprenWorldMap2D.STARTING_CAMP_POSITION,
			Callable(world_map, &"is_position_walkable"),
			Callable(world_map, &"get_minimum_road_edge_distance")
		)
		var copy_positions: Variant = deterministic_copy.call(&"get_anchor_positions")
		var copy_spans: Variant = deterministic_copy.call(&"get_anchor_spans")
		var copy_rotations: Variant = deterministic_copy.call(&"get_anchor_rotations")
		var copy_recipes: Variant = deterministic_copy.call(&"get_anchor_recipes")
		var copy_variants: Variant = deterministic_copy.call(&"get_anchor_variants")
		deterministic_layout_matches = (
			copy_positions is PackedVector2Array
			and copy_spans is PackedFloat32Array
			and copy_rotations is PackedFloat32Array
			and copy_recipes is PackedInt32Array
			and copy_variants is PackedInt32Array
			and copy_positions == positions
			and copy_spans == spans
			and copy_rotations == rotations
			and copy_recipes == recipes
			and copy_variants == variants
		)
		deterministic_copy.free()
	_check(
		deterministic_layout_matches,
		"WildernessAccent preserves its own exact seed stream without shifting legacy decor streams"
	)


func _validate_ambient_scenery(world_map: BesprenWorldMap2D, ambient_scenery: Node2D) -> void:
	var count_variant: Variant = ambient_scenery.call(&"get_scenery_count")
	var zone_counts_variant: Variant = ambient_scenery.call(&"get_zone_scenery_counts")
	var positions_variant: Variant = ambient_scenery.call(&"get_scenery_positions")
	var kinds_variant: Variant = ambient_scenery.call(&"get_scenery_kinds")
	var sizes_variant: Variant = ambient_scenery.call(&"get_scenery_sizes")
	var visual_radii_variant: Variant = ambient_scenery.call(&"get_scenery_visual_radii")
	var zones_variant: Variant = ambient_scenery.call(&"get_scenery_zones")
	var chunks_variant: Variant = ambient_scenery.call(&"get_render_chunks")
	var bounds_variant: Variant = ambient_scenery.call(&"get_render_chunk_bounds")
	var chunked_count_variant: Variant = ambient_scenery.call(&"get_chunked_scenery_count")
	var zone_counts: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector2Array = PackedVector2Array()
	var kinds: PackedInt32Array = PackedInt32Array()
	var sizes: PackedFloat32Array = PackedFloat32Array()
	var visual_radii: PackedFloat32Array = PackedFloat32Array()
	var zones: PackedInt32Array = PackedInt32Array()
	var chunks: Array = []
	var bounds: Array = []
	if zone_counts_variant is PackedInt32Array:
		zone_counts = zone_counts_variant
	if positions_variant is PackedVector2Array:
		positions = positions_variant
	if kinds_variant is PackedInt32Array:
		kinds = kinds_variant
	if sizes_variant is PackedFloat32Array:
		sizes = sizes_variant
	if visual_radii_variant is PackedFloat32Array:
		visual_radii = visual_radii_variant
	if zones_variant is PackedInt32Array:
		zones = zones_variant
	if chunks_variant is Array:
		chunks = chunks_variant
	if bounds_variant is Array:
		bounds = bounds_variant
	_check(
		count_variant is int
		and count_variant == EXPECTED_AMBIENT_SCENERY_TOTAL
		and positions.size() == EXPECTED_AMBIENT_SCENERY_TOTAL
		and kinds.size() == EXPECTED_AMBIENT_SCENERY_TOTAL
		and sizes.size() == EXPECTED_AMBIENT_SCENERY_TOTAL
		and visual_radii.size() == EXPECTED_AMBIENT_SCENERY_TOTAL
		and zones.size() == EXPECTED_AMBIENT_SCENERY_TOTAL
		and Array(zone_counts) == EXPECTED_AMBIENT_SCENERY_ZONE_TOTALS,
		"Ambient scenery owns its exact 576 region-weighted ruin, tree, and prop groups"
	)
	var visual_radius_metadata_is_sound: bool = visual_radii.size() == positions.size()
	for scenery_index: int in range(visual_radii.size()):
		if (
			not is_finite(visual_radii[scenery_index])
			or visual_radii[scenery_index] <= 0.0
			or visual_radii[scenery_index] > sizes[scenery_index]
		):
			visual_radius_metadata_is_sound = false
	_check(
		visual_radius_metadata_is_sound,
		"Ambient visual-radius metadata is finite, positive, and bounded by its source group size"
	)
	_check(
		chunks.size() > 1
		and bounds.size() == chunks.size()
		and chunked_count_variant is int
		and chunked_count_variant == EXPECTED_AMBIENT_SCENERY_TOTAL,
		"Ambient scenery batches every visual group into bounded regional CanvasItems"
	)
	var every_chunk_is_bounded: bool = not chunks.is_empty()
	var every_chunk_is_ambient: bool = not chunks.is_empty()
	var every_chunk_uses_sleek_grade: bool = not chunks.is_empty()
	var every_child_is_visual_only: bool = true
	for child: Node in ambient_scenery.get_children():
		if child is CollisionObject2D or child is CollisionShape2D:
			every_child_is_visual_only = false
	for chunk_index: int in range(chunks.size()):
		var chunk: Node2D = chunks[chunk_index] as Node2D
		if chunk == null or not bounds[chunk_index] is Rect2:
			every_chunk_is_bounded = false
			every_chunk_is_ambient = false
			every_chunk_uses_sleek_grade = false
			continue
		var chunk_bounds: Rect2 = bounds[chunk_index]
		if (
			chunk_bounds.size.x > MAX_AMBIENT_SCENERY_CHUNK_SPAN
			or chunk_bounds.size.y > MAX_AMBIENT_SCENERY_CHUNK_SPAN
			or chunk_bounds.size.x >= EXPECTED_WORLD_SIZE
			or chunk_bounds.size.y >= EXPECTED_WORLD_SIZE
		):
			every_chunk_is_bounded = false
		if chunk.z_index != EXPECTED_AMBIENT_SCENERY_Z or chunk.z_as_relative:
			every_chunk_is_ambient = false
		var grade_material: ShaderMaterial = chunk.material as ShaderMaterial
		if (
			grade_material == null
			or grade_material.shader == null
			or grade_material.shader.resource_path != "res://shaders/sleek_canvas_grade.gdshader"
		):
			every_chunk_uses_sleek_grade = false
	_check(every_chunk_is_bounded, "No ambient-scenery CanvasItem spans the 28672-unit world")
	_check(every_chunk_is_ambient, "Every ambient-scenery chunk stays on absolute visual z=-4")
	_check(every_chunk_uses_sleek_grade, "Every ambient-scenery batch uses the shared mobile color grade")
	_check(every_child_is_visual_only, "Ambient scenery adds no physics body, collision shape, or flow-field footprint")
	var every_position_preserves_clearings: bool = positions.size() == zones.size()
	for position_index: int in range(positions.size()):
		var zone_id: int = zones[position_index]
		var road_clearance: float = AMBIENT_SCENERY_ROAD_CLEARANCE
		if zone_id == 4 or zone_id == 5:
			road_clearance = AMBIENT_SCENERY_FOREST_ROAD_CLEARANCE
		elif zone_id == 6:
			road_clearance = AMBIENT_SCENERY_CONNECTOR_ROAD_CLEARANCE
		if (
			positions[position_index].distance_to(BesprenWorldMap2D.STARTING_CAMP_POSITION)
			< AMBIENT_SCENERY_CAMP_CLEAR_RADIUS
			or world_map.get_minimum_road_edge_distance(positions[position_index]) < road_clearance
		):
			every_position_preserves_clearings = false
	_check(
		every_position_preserves_clearings,
		"Every ambient group preserves the 1760-unit camp clearing and road centerline margins"
	)
	var has_ruins: bool = kinds.count(0) > 0 and kinds.count(1) > 0
	var has_tree_canopies: bool = kinds.count(2) > 0
	var has_props: bool = (
		kinds.count(4) > 0
		and kinds.count(5) > 0
		and kinds.count(6) > 0
		and kinds.count(7) > 0
		and kinds.count(8) > 0
		and kinds.count(9) > 0
	)
	_check(
		has_ruins and has_tree_canopies and has_props,
		"Ambient allocation visibly covers ruin facades, tree canopies, and mixed-world props"
	)
	var structural_positions: PackedVector2Array = PackedVector2Array()
	var structural_silhouettes_are_readable: bool = true
	for scenery_index: int in range(positions.size()):
		if kinds[scenery_index] != 0 and kinds[scenery_index] != 1:
			continue
		for existing_position: Vector2 in structural_positions:
			if (
				positions[scenery_index].distance_to(existing_position)
				< AMBIENT_SCENERY_STRUCTURAL_SEPARATION
			):
				structural_silhouettes_are_readable = false
		structural_positions.append(positions[scenery_index])
	_check(
		structural_silhouettes_are_readable,
		"Large non-colliding ruins keep a 340-unit composition gap from one another"
	)
	var deterministic_copy: Node2D = AMBIENT_SCENERY_SCRIPT.new() as Node2D
	var deterministic_layout_matches: bool = deterministic_copy != null
	if deterministic_copy != null:
		deterministic_copy.call(
			&"configure",
			BesprenWorldMap2D.PLAYABLE_HALF_EXTENT,
			BesprenWorldMap2D.WORLD_BUILD_SEED + 137,
			BesprenWorldMap2D.STARTING_CAMP_POSITION,
			Callable(world_map, &"is_position_walkable"),
			Callable(world_map, &"get_minimum_road_edge_distance")
		)
		var copy_positions: Variant = deterministic_copy.call(&"get_scenery_positions")
		var copy_kinds: Variant = deterministic_copy.call(&"get_scenery_kinds")
		var copy_sizes: Variant = deterministic_copy.call(&"get_scenery_sizes")
		var copy_visual_radii: Variant = deterministic_copy.call(&"get_scenery_visual_radii")
		var copy_zones: Variant = deterministic_copy.call(&"get_scenery_zones")
		deterministic_layout_matches = (
			copy_positions is PackedVector2Array
			and copy_kinds is PackedInt32Array
			and copy_zones is PackedInt32Array
			and copy_positions == positions
			and copy_kinds == kinds
			and copy_sizes is PackedFloat32Array
			and copy_visual_radii is PackedFloat32Array
			and copy_sizes == sizes
			and copy_visual_radii == visual_radii
			and copy_zones == zones
		)
		deterministic_copy.free()
	_check(
		deterministic_layout_matches,
		"Ambient scenery preserves its exact seeded layout without mutable gameplay state"
	)


func _validate_nature_tiles(
	world_map: BesprenWorldMap2D,
	terrain_tiles: TileMapLayer
) -> void:
	var tile_set_resource: TileSet = terrain_tiles.tile_set
	_check(tile_set_resource != null, "TerrainTiles owns a runtime TileSet")
	if tile_set_resource == null:
		return

	var used_cells: Array[Vector2i] = terrain_tiles.get_used_cells()
	_check(not used_cells.is_empty(), "TerrainTiles contains imported environment cells")
	_check(
		BesprenWorldMap2D.NATURE_TILES_PER_MACRO_CELL == EXPECTED_NATURE_TILES_PER_MACRO_CELL,
		"Nature coverage uses a deterministic 4x4 detail grid per macro cell"
	)
	var expected_tile_count: int = 0
	var every_expected_cell_is_filled: bool = true
	for macro_row: int in range(EXPECTED_GRID_SIZE):
		for macro_column: int in range(EXPECTED_GRID_SIZE):
			var macro_cell: Vector2i = Vector2i(macro_column, macro_row)
			var biome: int = world_map.get_biome_at_cell(macro_cell)
			var expects_nature: bool = (
				biome == BesprenWorldMap2D.Biome.FOREST
				or biome == BesprenWorldMap2D.Biome.WILDERNESS
			)
			for detail_y: int in range(EXPECTED_NATURE_TILES_PER_MACRO_CELL):
				for detail_x: int in range(EXPECTED_NATURE_TILES_PER_MACRO_CELL):
					var detail_cell: Vector2i = Vector2i(
						macro_column * EXPECTED_NATURE_TILES_PER_MACRO_CELL + detail_x,
						macro_row * EXPECTED_NATURE_TILES_PER_MACRO_CELL + detail_y
					)
					var cell_is_filled: bool = terrain_tiles.get_cell_source_id(detail_cell) >= 0
					if expects_nature:
						expected_tile_count += 1
					if cell_is_filled != expects_nature:
						every_expected_cell_is_filled = false
	_check(
		used_cells.size() == expected_tile_count,
		"TerrainTiles covers every Forest/Wilderness macro cell with exactly 4x4 detail cells"
	)
	_check(
		every_expected_cell_is_filled,
		"Nature detail cells have no holes or spillover outside Forest/Wilderness biomes"
	)

	var atlas_variants: Dictionary[Vector2i, bool] = {}
	var every_used_cell_uses_imported_atlas: bool = not used_cells.is_empty()
	for used_cell: Vector2i in used_cells:
		atlas_variants[terrain_tiles.get_cell_atlas_coords(used_cell)] = true
		var source_id: int = terrain_tiles.get_cell_source_id(used_cell)
		var atlas_source: TileSetAtlasSource = (
			tile_set_resource.get_source(source_id) as TileSetAtlasSource
		)
		if (
			atlas_source == null
			or atlas_source.texture == null
			or atlas_source.texture.resource_path != EXPECTED_NATURE_ATLAS_PATH
		):
			every_used_cell_uses_imported_atlas = false
	_check(
		atlas_variants.size() >= EXPECTED_NATURE_VARIANT_MINIMUM,
		"TerrainTiles uses at least five imported atlas-coordinate variants"
	)
	_check(
		every_used_cell_uses_imported_atlas,
		"Every nature detail cell uses res://assets/tiles/claw_forest_ground.png"
	)


func _validate_collision_contract(world_map: BesprenWorldMap2D) -> void:
	var obstacles: Array[WorldObstacle2D] = world_map.get_obstacle_nodes()
	var category_counts: PackedInt32Array = PackedInt32Array()
	category_counts.resize(WorldObstacle2D.VisualKind.size())
	category_counts.fill(0)
	var every_obstacle_has_collision: bool = not obstacles.is_empty()
	var every_shape_matches_kind: bool = not obstacles.is_empty()
	var every_obstacle_uses_static_layer: bool = not obstacles.is_empty()
	var every_obstacle_uses_entity_z: bool = not obstacles.is_empty()
	var every_obstacle_blocks_its_center: bool = not obstacles.is_empty()
	var tree_count: int = 0
	var camp_satellite_count: int = 0
	var camp_names: Dictionary[StringName, bool] = {}
	var every_camp_satellite_is_rectangular: bool = true
	var every_camp_satellite_clears_core: bool = true
	var every_camp_satellite_clears_routes: bool = true
	var every_camp_satellite_is_in_forest: bool = true
	var every_camp_satellite_matches_authored_offset: bool = true
	var every_camp_satellite_preserves_deep_road_clearance: bool = true
	var every_tree_has_active_collision: bool = true
	var every_tree_has_imported_visual: bool = true
	var every_tree_uses_imported_atlas: bool = true
	for obstacle: WorldObstacle2D in obstacles:
		var visual_kind: int = obstacle.get_visual_kind()
		if visual_kind >= 0 and visual_kind < category_counts.size():
			category_counts[visual_kind] += 1
		else:
			every_obstacle_has_collision = false
		var collision: CollisionShape2D = obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null:
			every_obstacle_has_collision = false
		else:
			var shape_matches: bool = (
				obstacle.get_shape_kind() == WorldObstacle2D.ShapeKind.RECTANGLE
				and collision.shape is RectangleShape2D
			) or (
				obstacle.get_shape_kind() == WorldObstacle2D.ShapeKind.CIRCLE
				and collision.shape is CircleShape2D
			)
			if not shape_matches:
				every_shape_matches_kind = false
		if obstacle.collision_layer != BesprenWorldMap2D.WORLD_STATIC_LAYER or obstacle.collision_mask != 0:
			every_obstacle_uses_static_layer = false
		if obstacle.z_index != EXPECTED_ENTITY_Z or obstacle.z_as_relative:
			every_obstacle_uses_entity_z = false
		if world_map.is_position_walkable(obstacle.position):
			every_obstacle_blocks_its_center = false
		if visual_kind == WorldObstacle2D.VisualKind.TREE:
			tree_count += 1
			var tree_body: StaticBody2D = obstacle as StaticBody2D
			if (
				tree_body == null
				or collision == null
				or collision.shape == null
				or collision.disabled
			):
				every_tree_has_active_collision = false
			var imported_visual: Sprite2D = obstacle.get_node_or_null("ImportedTreeVisual") as Sprite2D
			if imported_visual == null or imported_visual.texture == null:
				every_tree_has_imported_visual = false
				every_tree_uses_imported_atlas = false
			elif _get_texture_source_path(imported_visual.texture) != EXPECTED_TREE_ATLAS_PATH:
				every_tree_uses_imported_atlas = false
		if visual_kind in [
			WorldObstacle2D.VisualKind.CAMP_BEDDING,
			WorldObstacle2D.VisualKind.CAMP_SUPPLY_CACHE,
			WorldObstacle2D.VisualKind.CAMP_MEDICAL_CACHE,
		]:
			camp_satellite_count += 1
			camp_names[obstacle.name] = true
			if (
				not EXPECTED_CAMP_SATELLITE_OFFSETS.has(obstacle.name)
				or not obstacle.position.is_equal_approx(
					BesprenWorldMap2D.STARTING_CAMP_POSITION
					+ EXPECTED_CAMP_SATELLITE_OFFSETS[obstacle.name]
				)
			):
				every_camp_satellite_matches_authored_offset = false
			if obstacle.get_shape_kind() != WorldObstacle2D.ShapeKind.RECTANGLE:
				every_camp_satellite_is_rectangular = false
			var footprint_radius: float = obstacle.half_size.length() + PLAYER_RADIUS
			if (
				obstacle.position.distance_to(BesprenWorldMap2D.STARTING_CAMP_POSITION)
				< BesprenWorldMap2D.STARTING_CAMP_OPEN_RADIUS + footprint_radius
			):
				every_camp_satellite_clears_core = false
			if _distance_to_routes(obstacle.position, world_map.get_road_routes()) < footprint_radius + CAMP_ROUTE_MARGIN:
				every_camp_satellite_clears_routes = false
			if (
				world_map.get_minimum_asphalt_edge_distance(obstacle.position)
				- obstacle.half_size.length()
				< BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE
			):
				every_camp_satellite_preserves_deep_road_clearance = false
			var macro_cell: Vector2i = Vector2i(
				floori((obstacle.position.x + EXPECTED_HALF_EXTENT) / EXPECTED_CELL_SIZE),
				floori((obstacle.position.y + EXPECTED_HALF_EXTENT) / EXPECTED_CELL_SIZE)
			)
			if world_map.get_biome_at_cell(macro_cell) != BesprenWorldMap2D.Biome.FOREST:
				every_camp_satellite_is_in_forest = false
	_check(every_obstacle_has_collision, "Every authored structure owns a CollisionShape2D")
	_check(every_shape_matches_kind, "Rectangle and circle obstacle records use matching 2D physics shapes")
	_check(every_obstacle_uses_static_layer, "Every authored obstacle uses only the WorldStatic physics layer")
	_check(every_obstacle_uses_entity_z, "Every authored obstacle resides on absolute entity z=5")
	_check(every_obstacle_blocks_its_center, "Every authored obstacle blocks its physical center")
	_check(tree_count > 0, "Collision coverage includes authored boundary trees")
	_check(every_tree_has_active_collision, "Every tree remains an active colliding StaticBody2D")
	_check(every_tree_has_imported_visual, "Every tree owns an ImportedTreeVisual Sprite2D")
	_check(
		every_tree_uses_imported_atlas,
		"Every ImportedTreeVisual uses the baked polyhaven_wild atlas"
	)
	_check(
		camp_satellite_count == BesprenWorldMap2D.STARTING_CAMP_SATELLITE_COUNT
		and camp_names.has_all([
			&"StartingCampBedding",
			&"StartingCampSupplyCache",
			&"StartingCampMedicalCache",
		]),
		"Forest camp owns exactly the three named satellite obstacles"
	)
	_check(every_camp_satellite_is_rectangular, "Every camp satellite uses an authored rectangle footprint")
	_check(every_camp_satellite_matches_authored_offset, "Camp satellites match the exact asymmetric deep-forest composition")
	_check(every_camp_satellite_clears_core, "Camp satellites preserve the central Base and build-clearance ring")
	_check(every_camp_satellite_clears_routes, "Camp satellites preserve a physical margin from every authored road segment")
	_check(
		every_camp_satellite_preserves_deep_road_clearance,
		"Every complete camp-satellite footprint stays at least 1600 units from every asphalt edge"
	)
	_check(every_camp_satellite_is_in_forest, "Every camp satellite remains inside the secluded Forest biome")
	var spawn_and_resource_lanes_clear: bool = true
	var spawn_and_resource_lanes_are_deep: bool = true
	var clearance_offsets: Array[Vector2] = COOP_SPAWN_OFFSETS.duplicate()
	clearance_offsets.append_array(STARTER_RESOURCE_OFFSETS)
	for offset: Vector2 in clearance_offsets:
		if not world_map.is_position_walkable(
			BesprenWorldMap2D.STARTING_CAMP_POSITION + offset,
			PLAYER_RADIUS
		):
			spawn_and_resource_lanes_clear = false
		if (
			world_map.get_minimum_asphalt_edge_distance(
				BesprenWorldMap2D.STARTING_CAMP_POSITION + offset
			) - PLAYER_RADIUS
			< BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE
		):
			spawn_and_resource_lanes_are_deep = false
	_check(spawn_and_resource_lanes_clear, "Co-op spawn and starter-resource approach lanes remain walkable")
	_check(
		spawn_and_resource_lanes_are_deep,
		"All four co-op spawns and three starter-resource approaches stay at least 1600 units from every road edge"
	)
	_validate_village_dressing(world_map, obstacles)
	_validate_density_landmarks(world_map, obstacles)
	var every_category_present: bool = true
	for category_count: int in category_counts:
		if category_count <= 0:
			every_category_present = false
	_check(every_category_present, "Collision coverage includes every world and camp visual category")

	var world_bounds: Node2D = world_map.get_node_or_null("WorldBounds") as Node2D
	_check(world_map.get_world_boundary_count() == EXPECTED_BOUNDARY_COUNT, "World API reports exactly four collision bounds")
	_check(
		world_map.get_static_collision_count() == obstacles.size() + EXPECTED_BOUNDARY_COUNT,
		"Static collision total includes every obstacle and four bounds"
	)
	_check(world_bounds != null and world_bounds.get_child_count() == EXPECTED_BOUNDARY_COUNT, "WorldBounds owns four physical boundary bodies")
	if world_bounds == null:
		return
	var every_boundary_is_physical: bool = true
	for boundary_node: Node in world_bounds.get_children():
		var boundary: StaticBody2D = boundary_node as StaticBody2D
		if boundary == null:
			every_boundary_is_physical = false
			continue
		var boundary_collision: CollisionShape2D = boundary.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if (
			boundary_collision == null
			or not (boundary_collision.shape is RectangleShape2D)
			or boundary.collision_layer != BesprenWorldMap2D.WORLD_STATIC_LAYER
			or boundary.collision_mask != 0
			or not boundary.is_in_group(&"world_boundary")
		):
			every_boundary_is_physical = false
	_check(every_boundary_is_physical, "All four bounds are rectangular StaticBody2D collision barriers")


func _validate_village_dressing(
	world_map: BesprenWorldMap2D,
	obstacles: Array[WorldObstacle2D]
) -> void:
	var obstacles_by_name: Dictionary[StringName, WorldObstacle2D] = {}
	for obstacle: WorldObstacle2D in obstacles:
		obstacles_by_name[obstacle.name] = obstacle

	var west_count: int = 0
	var east_count: int = 0
	var west_families: Dictionary[int, bool] = {}
	var east_families: Dictionary[int, bool] = {}
	var every_record_matches: bool = true
	var every_record_uses_imported_visuals: bool = true
	var every_record_owns_its_village_biome: bool = true
	var every_record_clears_roads: bool = true
	var every_record_clears_village_shells: bool = true
	for dressing_name: StringName in EXPECTED_VILLAGE_DRESSING:
		if not obstacles_by_name.has(dressing_name):
			every_record_matches = false
			continue
		var dressing: WorldObstacle2D = obstacles_by_name[dressing_name]
		var expected: Dictionary = EXPECTED_VILLAGE_DRESSING[dressing_name]
		var expected_biome: int = expected[&"biome"]
		if (
			not dressing.position.is_equal_approx(expected[&"position"])
			or dressing.get_visual_kind() != expected[&"kind"]
		):
			every_record_matches = false
		if dressing.get_imported_visual_count() <= 0:
			every_record_uses_imported_visuals = false
		var macro_cell: Vector2i = Vector2i(
			floori((dressing.position.x + EXPECTED_HALF_EXTENT) / EXPECTED_CELL_SIZE),
			floori((dressing.position.y + EXPECTED_HALF_EXTENT) / EXPECTED_CELL_SIZE)
		)
		if world_map.get_biome_at_cell(macro_cell) != expected_biome:
			every_record_owns_its_village_biome = false
		var footprint_radius: float = (
			dressing.collision_radius
			if dressing.get_shape_kind() == WorldObstacle2D.ShapeKind.CIRCLE
			else dressing.half_size.length()
		)
		if (
			world_map.get_minimum_road_edge_distance(dressing.position)
			- footprint_radius
			< VILLAGE_DRESSING_MINIMUM_ROAD_EDGE_CLEARANCE
		):
			every_record_clears_roads = false
		for shell: WorldObstacle2D in obstacles:
			if shell == dressing or shell.name in EXPECTED_VILLAGE_DRESSING:
				continue
			if shell.get_visual_kind() not in [
				WorldObstacle2D.VisualKind.VILLAGE_HOUSE,
				WorldObstacle2D.VisualKind.WOODEN_FENCE,
				WorldObstacle2D.VisualKind.UTILITY_POLE,
			]:
				continue
			if dressing.get_world_bounds(PLAYER_RADIUS).intersects(
				shell.get_world_bounds(PLAYER_RADIUS)
			):
				every_record_clears_village_shells = false
		if expected_biome == BesprenWorldMap2D.Biome.VILLAGE_WEST:
			west_count += 1
			west_families[dressing.get_visual_kind()] = true
		else:
			east_count += 1
			east_families[dressing.get_visual_kind()] = true

	_check(
		west_count == BesprenWorldMap2D.VILLAGE_DRESSING_COUNT_PER_SIDE
		and east_count == BesprenWorldMap2D.VILLAGE_DRESSING_COUNT_PER_SIDE,
		"West and east villages each own exactly three authored dressing props"
	)
	_check(every_record_matches, "All six village dressing props match exact names, positions, and visual families")
	_check(
		west_families.size() == 3 and east_families.size() == 3,
		"Each village mixes exactly three non-fence prop families"
	)
	_check(every_record_uses_imported_visuals, "Every village dressing prop resolves an imported atlas visual")
	_check(every_record_owns_its_village_biome, "Village dressing remains inside its authored west/east biome")
	_check(
		every_record_clears_roads,
		"Every complete village dressing footprint stays at least 520 units from road edges"
	)
	_check(
		every_record_clears_village_shells,
		"Village dressing preserves player clearance from houses, fences, and utility poles"
	)


func _validate_density_landmarks(
	world_map: BesprenWorldMap2D,
	obstacles: Array[WorldObstacle2D]
) -> void:
	var city_ruin_count: int = 0
	var mall_ruin_count: int = 0
	var west_village_ruin_count: int = 0
	var east_village_ruin_count: int = 0
	var forest_stand_count: int = 0
	var wilderness_grove_count: int = 0
	var every_density_anchor_is_imported_and_clear: bool = true
	var every_dense_tree_preserves_camp_and_road_clearance: bool = true
	for obstacle: WorldObstacle2D in obstacles:
		var obstacle_name: String = String(obstacle.name)
		var expected_biome: int = -1
		if obstacle_name.begins_with("DenseCityRuin_"):
			city_ruin_count += 1
			expected_biome = BesprenWorldMap2D.Biome.CITY
		elif obstacle_name.begins_with("DenseMallRuin_"):
			mall_ruin_count += 1
			expected_biome = BesprenWorldMap2D.Biome.MALL
		elif obstacle_name.begins_with("DenseWestVillageRuin_"):
			west_village_ruin_count += 1
			expected_biome = BesprenWorldMap2D.Biome.VILLAGE_WEST
		elif obstacle_name.begins_with("DenseEastVillageRuin_"):
			east_village_ruin_count += 1
			expected_biome = BesprenWorldMap2D.Biome.VILLAGE_EAST

		if expected_biome >= 0:
			var anchor_radius: float = obstacle.half_size.length()
			var macro_cell: Vector2i = Vector2i(
				floori((obstacle.position.x + EXPECTED_HALF_EXTENT) / EXPECTED_CELL_SIZE),
				floori((obstacle.position.y + EXPECTED_HALF_EXTENT) / EXPECTED_CELL_SIZE)
			)
			if (
				obstacle.get_imported_visual_count() <= 0
				or obstacle.get_shape_kind() != WorldObstacle2D.ShapeKind.RECTANGLE
				or world_map.get_biome_at_cell(macro_cell) != expected_biome
				or world_map.get_minimum_road_edge_distance(obstacle.position) - anchor_radius
				< BesprenWorldMap2D.DENSE_LANDMARK_ROAD_EDGE_CLEARANCE
			):
				every_density_anchor_is_imported_and_clear = false

		if obstacle_name.begins_with("ForestStand_"):
			forest_stand_count += 1
		elif obstacle_name.begins_with("WildernessGrove_"):
			wilderness_grove_count += 1
		else:
			continue
		if (
			obstacle.position.distance_to(BesprenWorldMap2D.STARTING_CAMP_POSITION)
			< BesprenWorldMap2D.DENSE_TREE_CAMP_CLEAR_RADIUS
			or world_map.get_minimum_road_edge_distance(obstacle.position) - obstacle.collision_radius
			< BesprenWorldMap2D.DENSE_TREE_ROAD_EDGE_CLEARANCE
		):
			every_dense_tree_preserves_camp_and_road_clearance = false

	_check(
		city_ruin_count == BesprenWorldMap2D.DENSE_CITY_RUIN_COUNT
		and mall_ruin_count == BesprenWorldMap2D.DENSE_MALL_RUIN_COUNT
		and west_village_ruin_count == BesprenWorldMap2D.DENSE_VILLAGE_RUIN_COUNT_PER_SIDE
		and east_village_ruin_count == BesprenWorldMap2D.DENSE_VILLAGE_RUIN_COUNT_PER_SIDE,
		"Kaupunki, Ostari, and both villages gain their planned dense ruin anchors"
	)
	_check(
		every_density_anchor_is_imported_and_clear,
		"Every new ruin uses an imported silhouette inside its biome and outside road clearance"
	)
	_check(
		forest_stand_count >= BesprenWorldMap2D.MIN_DENSE_FOREST_TREE_COUNT
		and wilderness_grove_count >= BesprenWorldMap2D.MIN_WILDERNESS_GROVE_TREE_COUNT,
		"Forest and wilderness receive materially denser tree coverage (%d forest stands, %d wilderness groves)" % [
			forest_stand_count,
			wilderness_grove_count,
		]
	)
	_check(
		every_dense_tree_preserves_camp_and_road_clearance,
		"Dense trees preserve the camp clearing and every authored road shoulder"
	)


func _validate_gameplay_entity_layers() -> void:
	var game_world: Node2D = GAME_WORLD_SCENE.instantiate() as Node2D
	_check(game_world != null, "Gameplay composition instantiates for entity-layer validation")
	if game_world == null:
		return
	var entity_root: Node2D = game_world.get_node_or_null("YSortWorld") as Node2D
	var players: Node2D = game_world.get_node_or_null("YSortWorld/Players") as Node2D
	var base_core: Node2D = game_world.get_node_or_null("YSortWorld/BaseCore") as Node2D
	_check(entity_root != null, "Gameplay composition owns a YSortWorld entity root")
	_check(players != null, "Gameplay composition owns a Players entity container")
	_check(base_core != null, "Gameplay composition owns the Base Core entity")
	if entity_root != null:
		_check_absolute_z(entity_root, EXPECTED_ENTITY_Z, "YSortWorld")
		_check(entity_root.y_sort_enabled, "Gameplay entity root explicitly enables Y-sort")
	if players != null:
		_check_absolute_z(players, EXPECTED_ENTITY_Z, "Players")
		_check(players.y_sort_enabled, "Players container explicitly enables Y-sort")
	if base_core != null:
		_check_absolute_z(base_core, EXPECTED_ENTITY_Z, "BaseCore")
	game_world.free()

	var network_player: Node2D = NETWORK_PLAYER_SCENE.instantiate() as Node2D
	_check(network_player != null, "Network player entity instantiates for layer validation")
	if network_player != null:
		_check_absolute_z(network_player, EXPECTED_ENTITY_Z, "NetworkPlayer")
		network_player.free()


func _validate_flow_field(world_map: BesprenWorldMap2D) -> void:
	var expected_dimensions: Vector2i = Vector2i(EXPECTED_FLOW_DIMENSION, EXPECTED_FLOW_DIMENSION)
	_check(world_map.get_flow_field_dimensions() == expected_dimensions, "Flow-field mask is exactly 112x112")
	_check(
		world_map.get_flow_field_mask_hash() == EXPECTED_FLOW_FIELD_MASK_HASH,
		"Visual-only WildernessAccent leaves the complete 112x112 flow-field mask byte-identical"
	)
	var blocked_count: int = world_map.get_blocked_flow_cell_count()
	_check(blocked_count > 0, "Flow-field mask contains blocked cells")
	_check(blocked_count < EXPECTED_FLOW_DIMENSION * EXPECTED_FLOW_DIMENSION, "Flow-field mask preserves traversable cells")
	var core_cell: Vector2i = world_map.world_to_flow_cell(BesprenWorldMap2D.STARTING_CAMP_POSITION)
	_check(world_map.is_flow_cell_blocked(core_cell), "Base Core footprint is baked into the flow-field mask")
	_check(world_map.is_flow_cell_blocked(Vector2i(-1, 0)), "Flow-field cells west of the world are blocked")
	_check(world_map.is_flow_cell_blocked(Vector2i(EXPECTED_FLOW_DIMENSION, 0)), "Flow-field cells east of the world are blocked")
	var obstacles: Array[WorldObstacle2D] = world_map.get_obstacle_nodes()
	var every_obstacle_is_flow_blocked: bool = not obstacles.is_empty()
	for obstacle: WorldObstacle2D in obstacles:
		if not world_map.is_flow_cell_blocked(world_map.world_to_flow_cell(obstacle.position)):
			every_obstacle_is_flow_blocked = false
	_check(every_obstacle_is_flow_blocked, "Every static obstacle footprint is represented in the flow-field mask")
	var building: WorldObstacle2D = null
	for obstacle: WorldObstacle2D in obstacles:
		if obstacle.get_visual_kind() == WorldObstacle2D.VisualKind.CITY_BUILDING:
			building = obstacle
			break
	_check(building != null, "Flow-field validation resolves an authored city building")
	if building != null:
		_check(
			world_map.is_flow_cell_blocked(world_map.world_to_flow_cell(building.position)),
			"A city building footprint is baked into the flow-field mask"
		)
	var sample_cell: Vector2i = Vector2i(23, 71)
	_check(
		world_map.world_to_flow_cell(world_map.flow_cell_to_world(sample_cell)) == sample_cell,
		"Flow-field world/cell conversion round-trips"
	)


func _validate_motion_resolver(world_map: BesprenWorldMap2D) -> void:
	var obstacles: Array[WorldObstacle2D] = world_map.get_obstacle_nodes()
	_check(not obstacles.is_empty(), "Motion resolver has authored obstacle input")
	if obstacles.is_empty():
		return
	var current_position: Vector2 = _find_walkable_position(world_map, PLAYER_RADIUS)
	_check(current_position.is_finite(), "Validation locates a walkable player start")
	if not current_position.is_finite():
		return
	var blocked_destination: Vector2 = obstacles[0].position
	_check(not world_map.is_position_walkable(blocked_destination, PLAYER_RADIUS), "Obstacle destination is non-walkable at player clearance")
	var resolved_position: Vector2 = world_map.resolve_player_motion(
		current_position,
		blocked_destination,
		PLAYER_RADIUS
	)
	_check(not resolved_position.is_equal_approx(blocked_destination), "Motion resolver refuses movement into a static structure")
	_check(world_map.is_position_walkable(resolved_position, PLAYER_RADIUS), "Motion resolver returns a walkable slide or prior position")


func _find_walkable_position(world_map: BesprenWorldMap2D, clearance: float) -> Vector2:
	for row: int in range(EXPECTED_GRID_SIZE):
		for column: int in range(EXPECTED_GRID_SIZE):
			var candidate: Vector2 = world_map.get_cell_center(Vector2i(column, row))
			if world_map.is_position_walkable(candidate, clearance):
				return candidate
	return Vector2.INF


func _distance_to_routes(point: Vector2, routes: Array[PackedVector2Array]) -> float:
	var shortest: float = INF
	for route: PackedVector2Array in routes:
		for point_index: int in range(route.size() - 1):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				point,
				route[point_index],
				route[point_index + 1]
			)
			shortest = minf(shortest, point.distance_to(closest))
	return shortest


func _subtree_has_physics(node: Node) -> bool:
	if node is CollisionObject2D or node is CollisionShape2D or node is WorldObstacle2D:
		return true
	for child: Node in node.get_children():
		if _subtree_has_physics(child):
			return true
	return false


func _check_absolute_z(canvas_item: CanvasItem, expected_z: int, label: String) -> void:
	_check(canvas_item.z_index == expected_z, "%s uses z=%d" % [label, expected_z])
	_check(not canvas_item.z_as_relative, "%s z-index is absolute" % label)


func _rect_is_equal_approx(left: Rect2, right: Rect2) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)


func _get_texture_source_path(texture: Texture2D) -> String:
	var atlas_texture: AtlasTexture = texture as AtlasTexture
	if atlas_texture != null:
		if atlas_texture.atlas == null:
			return ""
		return atlas_texture.atlas.resource_path
	return texture.resource_path


func _finish() -> void:
	if _failures == 0:
		print("WORLD MAP VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("WORLD MAP VALIDATION FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
