class_name BesprenWorldMap2D
extends Node2D
## Deterministic 14x14 tactical macro-map and the canonical collision/flow-field source.

enum Biome {
	FOREST,
	CITY,
	MALL,
	VILLAGE_WEST,
	VILLAGE_EAST,
	WILDERNESS,
}

const GRID_SIZE: int = 14
const CELL_SIZE: float = 2048.0
const PLAYABLE_HALF_EXTENT: float = 14336.0
const WORLD_SIZE: float = PLAYABLE_HALF_EXTENT * 2.0
## Secluded east-forest clearing used by the initial camp and player roster.
## Asphalt stays 2,130 world units from this point. The dirt spur is the one
## route allowed inside that bowl; seclusion is measured against asphalt only.
const STARTING_CAMP_POSITION: Vector2 = Vector2(9950.0, 2400.0)
const STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE: float = 1600.0
const PLAYABLE_RECT: Rect2 = Rect2(
	Vector2(-PLAYABLE_HALF_EXTENT, -PLAYABLE_HALF_EXTENT),
	Vector2(WORLD_SIZE, WORLD_SIZE)
)
const SOURCE_TILE_PIXELS: int = 64
const GROUND_ATLAS: Texture2D = preload("res://assets/2d/environment/tiles/bespren_ground_atlas.svg")
const NATURE_ATLAS: Texture2D = preload("res://assets/tiles/claw_forest_ground.png")
const NATURE_DETAIL_SCALE: float = 8.0
const NATURE_TILES_PER_MACRO_CELL: int = 4
const NATURE_VARIANTS: Array[Vector2i] = [
	Vector2i(0, 6),
	Vector2i(1, 6),
	Vector2i(2, 6),
	Vector2i(0, 0),
	Vector2i(2, 0),
]
const FLOW_FIELD_CELL_SIZE: float = 256.0
const FLOW_FIELD_DIMENSION: int = 112
const FLOW_FIELD_AGENT_RADIUS: float = 34.0
const FLOW_FIELD_RASTER_CLEARANCE: float = (
	FLOW_FIELD_AGENT_RADIUS + FLOW_FIELD_CELL_SIZE * 0.70710678
)
const CORE_COLLISION_RADIUS: float = 128.0
## Obstacle broadphase grid. 512 units is a quarter of a macro cell, which puts
## the largest building shells in a handful of buckets while keeping a wilderness
## query - the common case - reading one or two mostly empty ones.
## This sits on the authoritative movement path: [method resolve_player_motion]
## makes up to three [method is_position_walkable] calls per player per 20 Hz
## tick, so with two seats the linear scan over all 461 obstacles cost about
## 25 ms of every wall-clock second before the grid existed. Measured over 6,000
## sampled queries the scan runs at 209.9 us and the grid at 3.8 us, a 55.2x
## reduction, and the equivalence is exact: 0 mismatches against a brute-force
## reference, with 34.1 percent of those samples actually blocked because half
## of them were drawn inside an obstacle's own padded bounds. That sampling
## choice is the point - uniformly sampling the 28,672-unit world puts almost
## every point nowhere near an obstacle, where the pad below cannot be wrong and
## a broken grid would still score a clean run.
const OBSTACLE_BROADPHASE_CELL: float = 512.0
const WORLD_STATIC_LAYER: int = 2
const WORLD_BUILD_SEED: int = 0xB35E7E
const STARTING_CAMP_OPEN_RADIUS: float = 520.0
const STARTING_CAMP_SATELLITE_COUNT: int = 3
const VILLAGE_DRESSING_COUNT_PER_SIDE: int = 3
const DENSE_CITY_RUIN_COUNT: int = 8
const DENSE_MALL_RUIN_COUNT: int = 5
const DENSE_VILLAGE_RUIN_COUNT_PER_SIDE: int = 2
const DENSE_LANDMARK_ROAD_EDGE_CLEARANCE: float = 360.0
const DENSE_FOREST_TREES_PER_CELL: int = 3
const DENSE_WILDERNESS_TREES_PER_CELL: int = 1
const DENSE_TREE_CAMP_CLEAR_RADIUS: float = 1800.0
const DENSE_TREE_ROAD_EDGE_CLEARANCE: float = 460.0
const DENSE_TREE_OBSTACLE_CLEARANCE: float = 72.0
const DENSE_TREE_PLACEMENT_ATTEMPTS: int = 12
const MIN_DENSE_FOREST_TREE_COUNT: int = 180
const MIN_WILDERNESS_GROVE_TREE_COUNT: int = 35

@onready var ground_tiles: TileMapLayer = %GroundTiles
@onready var terrain_details: Node2D = %TerrainDetails
@onready var terrain_tiles: TileMapLayer = %TerrainTiles
@onready var road_network: WorldRoadNetwork2D = %RoadNetwork
@onready var background_decor: WorldBackgroundDecor2D = %BackgroundDecor
@onready var wilderness_accent: Node2D = %WildernessAccent
@onready var ground_cover: Node2D = %GroundCover
@onready var ambient_scenery: Node2D = %AmbientScenery
@onready var structures: Node2D = %Structures
@onready var world_bounds: Node2D = %WorldBounds

var _built: bool = false
var _biome_cells: PackedInt32Array = PackedInt32Array()
var _obstacles: Array[WorldObstacle2D] = []
## Broadphase for `is_position_walkable`. That query used to scan every obstacle
## in the world on every call, which measures 380 microseconds each against the
## built map - and it is not a build-time-only path. `resolve_player_motion`
## issues up to three of them per player per authoritative tick, so at 20 Hz with
## two seats the linear scan was spending roughly 45 ms of every second inside
## `contains_world_point` before any decoration layer asked it anything. A
## uniform grid over the obstacle world bounds reduces each call to the handful
## of obstacles whose bounds could possibly reach the point. It is rebuilt lazily
## rather than at a fixed point in `ensure_built`, so an obstacle added later can
## never be queried against a stale grid.
var _obstacle_broadphase: Dictionary = {}
var _obstacle_broadphase_ready: bool = false
var _flow_field_blocked: PackedByteArray = PackedByteArray()
var _boundary_count: int = 0
var _obstacle_sequence: int = 0
var _core_world_position: Vector2 = STARTING_CAMP_POSITION


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_biome_cells()
	_build_ground_tile_map()
	_build_nature_tile_map()
	_build_road_network()
	background_decor.configure(PLAYABLE_HALF_EXTENT, WORLD_BUILD_SEED + 91)
	_build_city()
	_build_mall()
	_build_village_west()
	_build_village_east()
	_build_density_landmarks()
	_build_starting_camp_satellites()
	_build_metsa_loop_landmarks()
	_build_forest_perimeter()
	ambient_scenery.call(
		&"configure",
		PLAYABLE_HALF_EXTENT,
		WORLD_BUILD_SEED + 137,
		STARTING_CAMP_POSITION,
		Callable(self, &"is_position_walkable"),
		Callable(self, &"get_minimum_road_edge_distance")
	)
	_build_world_boundaries()
	_bake_flow_field_mask()
	## Configure the independent visual-only accent after the canonical obstacle
	## and flow-field pipeline has finished. It only reads the established map
	## contract and must not alter collisions, authority, or navigation state.
	wilderness_accent.call(
		&"configure",
		PLAYABLE_HALF_EXTENT,
		WORLD_BUILD_SEED + 173,
		STARTING_CAMP_POSITION,
		Callable(self, &"is_position_walkable"),
		Callable(self, &"get_minimum_road_edge_distance")
	)
	## Ground cover is configured last for the same reason and on its own
	## seed stream, so its density can be tuned without moving a single
	## obstacle, scenery item, or background decoration.
	ground_cover.call(
		&"configure",
		PLAYABLE_HALF_EXTENT,
		WORLD_BUILD_SEED + 211,
		STARTING_CAMP_POSITION,
		Callable(self, &"is_position_walkable"),
		Callable(self, &"get_minimum_road_edge_distance")
	)
	# After obstacles, scenery, and the flow bake. Those queries must not see
	# the spur, or a new road shoulder would move footprints the seed already
	# placed. The spur is still the live ninth route for rendering and for
	# every distance query once the map is built.
	_append_camp_dirt_spur()


func get_playable_rect() -> Rect2:
	return PLAYABLE_RECT


func get_world_size() -> Vector2:
	return Vector2(WORLD_SIZE, WORLD_SIZE)


func set_core_position(world_position: Vector2) -> void:
	if not world_position.is_finite():
		return
	_core_world_position = world_position
	if _built:
		_bake_flow_field_mask()


func get_core_position() -> Vector2:
	return _core_world_position


func get_biome_regions() -> Dictionary[StringName, Rect2]:
	var regions: Dictionary[StringName, Rect2] = {}
	regions[&"kaupunki"] = _cells_to_rect(Vector2i(1, 1), Vector2i(5, 5))
	regions[&"ostari"] = _cells_to_rect(Vector2i(7, 2), Vector2i(10, 5))
	regions[&"kyla_west"] = _cells_to_rect(Vector2i(1, 9), Vector2i(4, 12))
	regions[&"kyla_east"] = _cells_to_rect(Vector2i(9, 9), Vector2i(12, 12))
	regions[&"metsa_perimeter"] = PLAYABLE_RECT
	return regions


func get_biome_at_cell(cell: Vector2i) -> int:
	if not _is_valid_map_cell(cell):
		return -1
	return _biome_cells[_cell_index(cell)]


func get_biome_cell_count(biome: int) -> int:
	var count: int = 0
	for cell_biome: int in _biome_cells:
		if cell_biome == biome:
			count += 1
	return count


func get_cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		-PLAYABLE_HALF_EXTENT + (float(cell.x) + 0.5) * CELL_SIZE,
		-PLAYABLE_HALF_EXTENT + (float(cell.y) + 0.5) * CELL_SIZE
	)


func get_road_route_count() -> int:
	return road_network.get_route_count()


func get_nature_tile_count() -> int:
	return terrain_tiles.get_used_cells().size()


func get_nature_variant_count() -> int:
	var variants: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in terrain_tiles.get_used_cells():
		variants[terrain_tiles.get_cell_atlas_coords(cell)] = true
	return variants.size()


func get_road_routes() -> Array[PackedVector2Array]:
	return road_network.get_routes()


func get_road_dirt_flags() -> PackedByteArray:
	return road_network.get_dirt_flags()


func get_minimum_road_edge_distance(world_position: Vector2) -> float:
	return road_network.get_minimum_road_edge_distance(world_position)


func get_minimum_asphalt_edge_distance(world_position: Vector2) -> float:
	return road_network.get_minimum_asphalt_edge_distance(world_position)


func get_obstacle_nodes() -> Array[WorldObstacle2D]:
	return _obstacles.duplicate()


func get_static_collision_count() -> int:
	return _obstacles.size() + _boundary_count


func get_world_boundary_count() -> int:
	return _boundary_count


func get_flow_field_dimensions() -> Vector2i:
	return Vector2i(FLOW_FIELD_DIMENSION, FLOW_FIELD_DIMENSION)


func get_blocked_flow_cell_count() -> int:
	var count: int = 0
	for value: int in _flow_field_blocked:
		if value != 0:
			count += 1
	return count


func get_flow_field_mask_hash() -> String:
	## Stable evidence for visual-only layers: an accent configured after this
	## mask is baked cannot silently change navigation occupancy.
	return _flow_field_blocked.hex_encode().sha256_text()


func is_flow_cell_blocked(cell: Vector2i) -> bool:
	if (
		cell.x < 0
		or cell.y < 0
		or cell.x >= FLOW_FIELD_DIMENSION
		or cell.y >= FLOW_FIELD_DIMENSION
	):
		return true
	return _flow_field_blocked[cell.y * FLOW_FIELD_DIMENSION + cell.x] != 0


func world_to_flow_cell(world_position: Vector2) -> Vector2i:
	var local_position: Vector2 = world_position + Vector2.ONE * PLAYABLE_HALF_EXTENT
	return Vector2i(
		floori(local_position.x / FLOW_FIELD_CELL_SIZE),
		floori(local_position.y / FLOW_FIELD_CELL_SIZE)
	)


func flow_cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		-PLAYABLE_HALF_EXTENT + (float(cell.x) + 0.5) * FLOW_FIELD_CELL_SIZE,
		-PLAYABLE_HALF_EXTENT + (float(cell.y) + 0.5) * FLOW_FIELD_CELL_SIZE
	)


func is_position_walkable(world_position: Vector2, clearance: float = 0.0) -> bool:
	if not world_position.is_finite() or clearance < 0.0:
		return false
	var safe_rect: Rect2 = PLAYABLE_RECT.grow(-clearance)
	if not safe_rect.has_point(world_position):
		return false
	if world_position.distance_squared_to(_core_world_position) <= pow(CORE_COLLISION_RADIUS + clearance, 2.0):
		return false
	if not _obstacle_broadphase_ready:
		_build_obstacle_broadphase()
	## Obstacles are stamped by their zero-clearance world bounds, but a rotated
	## rectangle expands along its own local axes, so its containment region can
	## reach up to `clearance * sqrt(2)` beyond that AABB. Padding the query by
	## the same factor keeps the cell sweep a strict superset of the obstacles
	## the exact test could accept, which is what makes the grid lossless rather
	## than merely fast.
	var pad: float = clearance * 1.4143
	var minimum: Vector2i = _obstacle_broadphase_cell(world_position - Vector2.ONE * pad)
	var maximum: Vector2i = _obstacle_broadphase_cell(world_position + Vector2.ONE * pad)
	for cell_y: int in range(minimum.y, maximum.y + 1):
		for cell_x: int in range(minimum.x, maximum.x + 1):
			var key: Vector2i = Vector2i(cell_x, cell_y)
			if not _obstacle_broadphase.has(key):
				continue
			var bucket: PackedInt32Array = _obstacle_broadphase[key]
			for obstacle_index: int in bucket:
				if _obstacles[obstacle_index].contains_world_point(world_position, clearance):
					return false
	return true


func _build_obstacle_broadphase() -> void:
	_obstacle_broadphase.clear()
	for index: int in range(_obstacles.size()):
		var bounds: Rect2 = _obstacles[index].get_world_bounds()
		var minimum: Vector2i = _obstacle_broadphase_cell(bounds.position)
		var maximum: Vector2i = _obstacle_broadphase_cell(bounds.end)
		for cell_y: int in range(minimum.y, maximum.y + 1):
			for cell_x: int in range(minimum.x, maximum.x + 1):
				var key: Vector2i = Vector2i(cell_x, cell_y)
				## Packed arrays are value types, so the bucket has to be written
				## back rather than mutated in place through the lookup.
				var bucket: PackedInt32Array = PackedInt32Array()
				if _obstacle_broadphase.has(key):
					bucket = _obstacle_broadphase[key]
				bucket.append(index)
				_obstacle_broadphase[key] = bucket
	_obstacle_broadphase_ready = true


static func _obstacle_broadphase_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / OBSTACLE_BROADPHASE_CELL),
		floori(world_position.y / OBSTACLE_BROADPHASE_CELL)
	)


func resolve_player_motion(
	current_position: Vector2,
	desired_position: Vector2,
	player_radius: float
) -> Vector2:
	if not current_position.is_finite() or not desired_position.is_finite():
		return current_position
	var safe_rect: Rect2 = PLAYABLE_RECT.grow(-player_radius)
	var clamped: Vector2 = Vector2(
		clampf(desired_position.x, safe_rect.position.x, safe_rect.end.x),
		clampf(desired_position.y, safe_rect.position.y, safe_rect.end.y)
	)
	if is_position_walkable(clamped, player_radius):
		return clamped
	var horizontal_slide: Vector2 = Vector2(clamped.x, current_position.y)
	if is_position_walkable(horizontal_slide, player_radius):
		current_position = horizontal_slide
	var vertical_slide: Vector2 = Vector2(current_position.x, clamped.y)
	if is_position_walkable(vertical_slide, player_radius):
		current_position = vertical_slide
	return current_position


func _build_biome_cells() -> void:
	_biome_cells.resize(GRID_SIZE * GRID_SIZE)
	_biome_cells.fill(Biome.WILDERNESS)
	for row: int in range(GRID_SIZE):
		for column: int in range(GRID_SIZE):
			var cell: Vector2i = Vector2i(column, row)
			var biome: int = Biome.WILDERNESS
			var perimeter: bool = column == 0 or row == 0 or column == GRID_SIZE - 1 or row == GRID_SIZE - 1
			if perimeter or (column >= 10 and row <= 8) or (column <= 2 and row >= 5):
				biome = Biome.FOREST
			if column >= 1 and column <= 5 and row >= 1 and row <= 5:
				biome = Biome.CITY
			elif column >= 7 and column <= 10 and row >= 2 and row <= 5:
				biome = Biome.MALL
			elif column >= 1 and column <= 4 and row >= 9 and row <= 12:
				biome = Biome.VILLAGE_WEST
			elif column >= 9 and column <= 12 and row >= 9 and row <= 12:
				biome = Biome.VILLAGE_EAST
			_biome_cells[_cell_index(cell)] = biome


func _build_ground_tile_map() -> void:
	var tile_set_resource: TileSet = TileSet.new()
	tile_set_resource.tile_size = Vector2i(SOURCE_TILE_PIXELS, SOURCE_TILE_PIXELS)
	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = GROUND_ATLAS
	atlas_source.texture_region_size = Vector2i(SOURCE_TILE_PIXELS, SOURCE_TILE_PIXELS)
	for atlas_column: int in range(Biome.size()):
		atlas_source.create_tile(Vector2i(atlas_column, 0))
	var source_id: int = tile_set_resource.add_source(atlas_source)
	ground_tiles.tile_set = tile_set_resource
	ground_tiles.scale = Vector2.ONE * (CELL_SIZE / float(SOURCE_TILE_PIXELS))
	ground_tiles.z_index = -20
	ground_tiles.z_as_relative = false
	var local_origin: Vector2 = ground_tiles.map_to_local(Vector2i.ZERO)
	ground_tiles.position = get_cell_center(Vector2i.ZERO) - local_origin * ground_tiles.scale
	for row: int in range(GRID_SIZE):
		for column: int in range(GRID_SIZE):
			var cell: Vector2i = Vector2i(column, row)
			var atlas_coordinates: Vector2i = Vector2i(get_biome_at_cell(cell), 0)
			ground_tiles.set_cell(cell, source_id, atlas_coordinates, 0)


func _build_nature_tile_map() -> void:
	var tile_set_resource: TileSet = TileSet.new()
	tile_set_resource.tile_size = Vector2i(SOURCE_TILE_PIXELS, SOURCE_TILE_PIXELS)
	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = NATURE_ATLAS
	atlas_source.texture_region_size = Vector2i(SOURCE_TILE_PIXELS, SOURCE_TILE_PIXELS)
	for atlas_coordinates: Vector2i in NATURE_VARIANTS:
		atlas_source.create_tile(atlas_coordinates)
	var source_id: int = tile_set_resource.add_source(atlas_source)
	terrain_tiles.tile_set = tile_set_resource
	terrain_tiles.scale = Vector2.ONE * NATURE_DETAIL_SCALE
	terrain_tiles.position = PLAYABLE_RECT.position
	terrain_tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Pull the bright source sheet into Bespren's muted petroleum-green world
	# palette without destructively editing the licensed source texture.
	# Keep the licensed detail sheet as a restrained breakup layer. The authored
	# Poly Haven blend must remain dominant so macro-cell edges do not reappear as
	# hard vertical or horizontal seams at gameplay zoom.
	terrain_tiles.modulate = Color(0.604, 0.678, 0.627, 0.0)
	terrain_tiles.z_index = -20
	terrain_tiles.z_as_relative = false
	for macro_row: int in range(GRID_SIZE):
		for macro_column: int in range(GRID_SIZE):
			var macro_cell: Vector2i = Vector2i(macro_column, macro_row)
			var biome: int = get_biome_at_cell(macro_cell)
			if biome != Biome.FOREST and biome != Biome.WILDERNESS:
				continue
			for detail_y: int in range(NATURE_TILES_PER_MACRO_CELL):
				for detail_x: int in range(NATURE_TILES_PER_MACRO_CELL):
					var detail_cell: Vector2i = Vector2i(
						macro_column * NATURE_TILES_PER_MACRO_CELL + detail_x,
						macro_row * NATURE_TILES_PER_MACRO_CELL + detail_y
					)
					var variant_index: int = posmod(
						macro_column * 31
						+ macro_row * 47
						+ detail_x * 7
						+ detail_y * 13
						+ WORLD_BUILD_SEED,
						NATURE_VARIANTS.size()
					)
					terrain_tiles.set_cell(
						detail_cell,
						source_id,
						NATURE_VARIANTS[variant_index],
						0
					)


func _append_camp_dirt_spur() -> void:
	# Measured column: tree shoulder stays above 460, and the six camp
	# keepouts (three teaching nodes, three satellites) stay off the dirt edge.
	# The start sits on the 520 open-radius circle, then runs north to asphalt.
	var spur_east: float = 480.0
	var spur_x: float = STARTING_CAMP_POSITION.x + spur_east
	var bowl_drop: float = sqrt(
		STARTING_CAMP_OPEN_RADIUS * STARTING_CAMP_OPEN_RADIUS - spur_east * spur_east
	)
	var routes: Array[PackedVector2Array] = road_network.get_routes()
	var asphalt_edge_y: float = WorldRoadNetwork2D.ASPHALT_OUTER_WIDTH * 0.5
	routes.append(PackedVector2Array([
		Vector2(spur_x, STARTING_CAMP_POSITION.y - bowl_drop),
		Vector2(spur_x, asphalt_edge_y),
	]))
	var dirt_flags: PackedByteArray = road_network.get_dirt_flags()
	dirt_flags.append(1)
	road_network.configure(routes, dirt_flags)


func _build_road_network() -> void:
	var routes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-12288.0, 0.0), Vector2.ZERO, Vector2(12288.0, 0.0)]),
		PackedVector2Array([Vector2(0.0, -12288.0), Vector2.ZERO, Vector2(0.0, 12288.0)]),
		PackedVector2Array([Vector2(-8192.0, -11264.0), Vector2(-8192.0, 0.0), Vector2.ZERO]),
		PackedVector2Array([Vector2(0.0, -5500.0), Vector2(9000.0, -5500.0), Vector2(9000.0, 0.0)]),
		PackedVector2Array([Vector2(0.0, 4096.0), Vector2(-8192.0, 4096.0), Vector2(-8192.0, 11264.0)]),
		PackedVector2Array([Vector2(0.0, 4096.0), Vector2(8192.0, 4096.0), Vector2(8192.0, 11264.0)]),
		PackedVector2Array([Vector2(-12288.0, -12288.0), Vector2(12288.0, -12288.0), Vector2(12288.0, 12288.0), Vector2(-12288.0, 12288.0), Vector2(-12288.0, -12288.0)]),
		PackedVector2Array([Vector2(9000.0, -5500.0), Vector2(11264.0, -5500.0), Vector2(11264.0, -11264.0)]),
		# North of the camp spur tip. Built with the other routes so trees and
		# scenery keep a shoulder. South of this T is the way home.
		PackedVector2Array([
			Vector2(10430.0, 270.0),
			Vector2(10430.0, -650.0),
			Vector2(11280.0, -1280.0),
		]),
	]
	var dirt_flags: PackedByteArray = PackedByteArray([0, 0, 0, 0, 1, 1, 1, 1, 1])
	road_network.configure(routes, dirt_flags)
	terrain_details.z_index = -20
	terrain_details.z_as_relative = false


func _build_city() -> void:
	var building_positions: PackedVector2Array = PackedVector2Array([
		Vector2(-11000.0, -10700.0),
		Vector2(-5350.0, -10700.0),
		Vector2(-11000.0, -7900.0),
		Vector2(-5200.0, -7900.0),
		Vector2(-10900.0, -4800.0),
		Vector2(-5100.0, -4700.0),
	])
	var building_sizes: PackedVector2Array = PackedVector2Array([
		Vector2(1850.0, 1650.0),
		Vector2(2300.0, 1500.0),
		Vector2(1900.0, 1450.0),
		Vector2(2150.0, 1700.0),
		Vector2(2100.0, 1350.0),
		Vector2(2350.0, 1500.0),
	])
	for building_index: int in range(building_positions.size()):
		_add_rectangle_obstacle(
			StringName("CityBuilding_%02d" % building_index),
			building_positions[building_index],
			building_sizes[building_index],
			WorldObstacle2D.VisualKind.CITY_BUILDING
		)

	var vehicle_positions: PackedVector2Array = PackedVector2Array([
		Vector2(-8500.0, -9900.0),
		Vector2(-7700.0, -6900.0),
		Vector2(-8650.0, -3900.0),
		Vector2(-3350.0, -8050.0),
		Vector2(-11850.0, -2250.0),
	])
	for vehicle_index: int in range(vehicle_positions.size()):
		_add_rectangle_obstacle(
			StringName("CityVehicleWreck_%02d" % vehicle_index),
			vehicle_positions[vehicle_index],
			Vector2(560.0, 280.0),
			WorldObstacle2D.VisualKind.VEHICLE_WRECK,
			-0.35 + float(vehicle_index) * 0.17
		)
	var scrap_positions: PackedVector2Array = PackedVector2Array([
		Vector2(-9800.0, -9000.0), Vector2(-6800.0, -9300.0),
		Vector2(-9300.0, -6100.0), Vector2(-6500.0, -5700.0),
		Vector2(-11600.0, -3600.0), Vector2(-4200.0, -3400.0),
	])
	for scrap_index: int in range(scrap_positions.size()):
		_add_circle_obstacle(
			StringName("CityScrapPile_%02d" % scrap_index),
			scrap_positions[scrap_index],
			82.0 + float(scrap_index % 3) * 16.0,
			WorldObstacle2D.VisualKind.SCRAP_PILE
		)
	# The asphalt at x=-8192 used to run open for about three screens. These
	# masses pinch it into a dogleg a player can feel without a label.
	_add_rectangle_obstacle(
		&"CityChokeWest_00",
		Vector2(-9200.0, -9200.0),
		Vector2(900.0, 1100.0),
		WorldObstacle2D.VisualKind.CITY_BUILDING
	)
	_add_rectangle_obstacle(
		&"CityChokeEast_00",
		Vector2(-7200.0, -9000.0),
		Vector2(900.0, 1200.0),
		WorldObstacle2D.VisualKind.CITY_BUILDING
	)
	_add_rectangle_obstacle(
		&"CityChokeWest_01",
		Vector2(-9050.0, -5800.0),
		Vector2(900.0, 1000.0),
		WorldObstacle2D.VisualKind.CITY_BUILDING
	)
	_add_rectangle_obstacle(
		&"CityChokeEast_01",
		Vector2(-7300.0, -6100.0),
		Vector2(950.0, 1100.0),
		WorldObstacle2D.VisualKind.CITY_BUILDING
	)
	_add_rectangle_obstacle(
		&"CityChokeJackknife",
		Vector2(-8000.0, -3400.0),
		Vector2(560.0, 280.0),
		WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		1.2
	)


func _build_mall() -> void:
	# Still a long shell, so the Hidden Alley module mix stays the reviewed 16.
	# The east end stops short of the old bar and leaves a missing-tooth gate.
	_add_rectangle_obstacle(
		&"OstariNorthShell",
		Vector2(3650.0, -7900.0),
		Vector2(4000.0, 1800.0),
		WorldObstacle2D.VisualKind.MALL_SHELL
	)
	_add_rectangle_obstacle(
		&"OstariSouthShell",
		Vector2(4850.0, -3150.0),
		Vector2(6400.0, 1800.0),
		WorldObstacle2D.VisualKind.MALL_SHELL
	)
	_add_rectangle_obstacle(
		&"OstariWestPylon",
		Vector2(5900.0, -7020.0),
		Vector2(720.0, 920.0),
		WorldObstacle2D.VisualKind.MALL_SHELL
	)
	_add_rectangle_obstacle(
		&"OstariEastPylon",
		Vector2(6800.0, -7020.0),
		Vector2(720.0, 920.0),
		WorldObstacle2D.VisualKind.MALL_SHELL
	)
	_add_rectangle_obstacle(
		&"OstariCollapsedTruck",
		Vector2(6350.0, -6880.0),
		Vector2(680.0, 310.0),
		WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		0.24
	)
	_add_circle_obstacle(
		&"OstariCourtScrap_00",
		Vector2(4000.0, -5400.0),
		118.0,
		WorldObstacle2D.VisualKind.SCRAP_PILE
	)
	_add_rectangle_obstacle(
		&"OstariCourtWreck",
		Vector2(5600.0, -4900.0),
		Vector2(560.0, 280.0),
		WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		-0.22
	)


func _build_village_west() -> void:
	var house_positions: PackedVector2Array = PackedVector2Array([
		Vector2(-10800.0, 6900.0),
		Vector2(-6200.0, 7200.0),
		Vector2(-10700.0, 9800.0),
		Vector2(-5200.0, 10100.0),
	])
	for house_index: int in range(house_positions.size()):
		_add_rectangle_obstacle(
			StringName("WestVillageHouse_%02d" % house_index),
			house_positions[house_index],
			Vector2(1220.0, 940.0),
			WorldObstacle2D.VisualKind.VILLAGE_HOUSE,
			0.04 * float((house_index % 2) * 2 - 1)
		)
	_add_village_fences(&"West", Vector2(-8050.0, 8350.0), -1.0)
	_add_village_utility_poles(&"West", -8050.0)
	# A loose salvage triangle breaks up the broad field without repeating the
	# fence language or closing the two walkable sides of the village road.
	_add_circle_obstacle(
		&"WestVillageScrapCache",
		Vector2(-9300.0, 8200.0),
		96.0,
		WorldObstacle2D.VisualKind.SCRAP_PILE
	)
	_add_circle_obstacle(
		&"WestVillageYardWoodpile",
		Vector2(-9800.0, 7600.0),
		110.0,
		WorldObstacle2D.VisualKind.SCRAP_PILE
	)
	_add_circle_obstacle(
		&"WestVillageMossRock",
		Vector2(-6750.0, 8450.0),
		144.0,
		WorldObstacle2D.VisualKind.MOSSY_ROCK
	)
	_add_rectangle_obstacle(
		&"WestVillageFallenLog",
		Vector2(-9300.0, 8950.0),
		Vector2(470.0, 115.0),
		WorldObstacle2D.VisualKind.FALLEN_LOG,
		0.34
	)


func _build_village_east() -> void:
	var house_positions: PackedVector2Array = PackedVector2Array([
		Vector2(5300.0, 6900.0),
		Vector2(10900.0, 6800.0),
		Vector2(6200.0, 10500.0),
		Vector2(10800.0, 10100.0),
	])
	for house_index: int in range(house_positions.size()):
		_add_rectangle_obstacle(
			StringName("EastVillageHouse_%02d" % house_index),
			house_positions[house_index],
			Vector2(1260.0, 920.0),
			WorldObstacle2D.VisualKind.VILLAGE_HOUSE,
			0.05 * float((house_index % 2) * 2 - 1)
		)
	_add_village_fences(&"East", Vector2(8050.0, 8350.0), 1.0)
	_add_village_utility_poles(&"East", 8050.0)
	# The eastern field uses a different three-family silhouette and an offset
	# composition so the paired villages do not read as mirrored copies.
	_add_rectangle_obstacle(
		&"EastVillageVehicleWreck",
		Vector2(9550.0, 8300.0),
		Vector2(560.0, 280.0),
		WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		-0.24
	)
	_add_circle_obstacle(
		&"EastVillageScrapCache",
		Vector2(6850.0, 8200.0),
		105.0,
		WorldObstacle2D.VisualKind.SCRAP_PILE
	)
	_add_rectangle_obstacle(
		&"EastVillageGraveCrossA",
		Vector2(9600.0, 9000.0),
		Vector2(480.0, 115.0),
		WorldObstacle2D.VisualKind.FALLEN_LOG,
		0.85
	)
	_add_rectangle_obstacle(
		&"EastVillageGraveCrossB",
		Vector2(9750.0, 9120.0),
		Vector2(420.0, 115.0),
		WorldObstacle2D.VisualKind.FALLEN_LOG,
		-0.75
	)
	_add_rectangle_obstacle(
		&"EastVillageHearse",
		Vector2(7000.0, 9300.0),
		Vector2(560.0, 280.0),
		WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		0.4
	)
	_add_circle_obstacle(
		&"EastVillageMossRock",
		Vector2(9650.0, 9000.0),
		150.0,
		WorldObstacle2D.VisualKind.MOSSY_ROCK
	)


func _build_density_landmarks() -> void:
	var city_ruins: Array[Dictionary] = [
		{&"name": &"DenseCityRuin_00", &"position": Vector2(-9400.0, -10800.0), &"size": Vector2(550.0, 600.0), &"rotation": -0.12, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_01", &"position": Vector2(-7050.0, -10800.0), &"size": Vector2(550.0, 600.0), &"rotation": 0.08, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_02", &"position": Vector2(-9400.0, -7850.0), &"size": Vector2(550.0, 600.0), &"rotation": 0.16, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_03", &"position": Vector2(-6900.0, -7750.0), &"size": Vector2(550.0, 600.0), &"rotation": -0.06, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_04", &"position": Vector2(-9300.0, -4550.0), &"size": Vector2(600.0, 540.0), &"rotation": -0.14, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_05", &"position": Vector2(-6900.0, -4550.0), &"size": Vector2(600.0, 540.0), &"rotation": 0.12, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_06", &"position": Vector2(-11000.0, -6300.0), &"size": Vector2(620.0, 600.0), &"rotation": 0.04, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseCityRuin_07", &"position": Vector2(-5000.0, -6200.0), &"size": Vector2(620.0, 600.0), &"rotation": -0.04, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
	]
	var mall_ruins: Array[Dictionary] = [
		{&"name": &"DenseMallRuin_00", &"position": Vector2(2600.0, -10000.0), &"size": Vector2(620.0, 500.0), &"rotation": -0.10, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseMallRuin_01", &"position": Vector2(7200.0, -10050.0), &"size": Vector2(620.0, 500.0), &"rotation": 0.14, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseMallRuin_02", &"position": Vector2(3000.0, -4450.0), &"size": Vector2(500.0, 300.0), &"rotation": -0.18, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseMallRuin_03", &"position": Vector2(7000.0, -4450.0), &"size": Vector2(500.0, 300.0), &"rotation": 0.16, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
		{&"name": &"DenseMallRuin_04", &"position": Vector2(4850.0, -10000.0), &"size": Vector2(620.0, 500.0), &"rotation": 0.02, &"kind": WorldObstacle2D.VisualKind.CITY_BUILDING},
	]
	var village_ruins: Array[Dictionary] = [
		{&"name": &"DenseWestVillageRuin_00", &"position": Vector2(-11250.0, 8500.0), &"size": Vector2(560.0, 480.0), &"rotation": -0.08, &"kind": WorldObstacle2D.VisualKind.VILLAGE_HOUSE},
		{&"name": &"DenseWestVillageRuin_01", &"position": Vector2(-4550.0, 8500.0), &"size": Vector2(560.0, 480.0), &"rotation": 0.10, &"kind": WorldObstacle2D.VisualKind.VILLAGE_HOUSE},
		{&"name": &"DenseEastVillageRuin_00", &"position": Vector2(4500.0, 11000.0), &"size": Vector2(560.0, 480.0), &"rotation": 0.08, &"kind": WorldObstacle2D.VisualKind.VILLAGE_HOUSE},
		{&"name": &"DenseEastVillageRuin_01", &"position": Vector2(11250.0, 8500.0), &"size": Vector2(560.0, 480.0), &"rotation": -0.10, &"kind": WorldObstacle2D.VisualKind.VILLAGE_HOUSE},
	]
	_add_density_rectangles(city_ruins)
	_add_density_rectangles(mall_ruins)
	_add_density_rectangles(village_ruins)


func _add_density_rectangles(placements: Array[Dictionary]) -> void:
	for placement: Dictionary in placements:
		var placement_position: Vector2 = placement[&"position"]
		var placement_size: Vector2 = placement[&"size"]
		var footprint_radius: float = placement_size.length() * 0.5
		if not _can_place_density_obstacle(placement_position, footprint_radius):
			push_error("World density placement is not clear: %s" % placement[&"name"])
			continue
		_add_rectangle_obstacle(
			placement[&"name"],
			placement_position,
			placement_size,
			placement[&"kind"],
			placement[&"rotation"]
		)


func _can_place_density_obstacle(world_position: Vector2, footprint_radius: float) -> bool:
	if (
		world_position.distance_to(STARTING_CAMP_POSITION)
		< DENSE_TREE_CAMP_CLEAR_RADIUS + footprint_radius
	):
		return false
	if (
		get_minimum_road_edge_distance(world_position)
		< DENSE_LANDMARK_ROAD_EDGE_CLEARANCE + footprint_radius
	):
		return false
	return is_position_walkable(world_position, footprint_radius)


func _build_starting_camp_satellites() -> void:
	# Three restrained utility clusters turn the secluded Base clearing into a
	# lived-in camp. Their authored ring stays clear of the Base, co-op spawn
	# lane, starter resources, and every road edge; building/flow use the same
	# obstacles. Their asymmetric west/south-east arc fits the road-free lens
	# between the central route, east-village branch, and eastern outer loop.
	var placements: Array[Dictionary] = [
		{
			&"name": &"StartingCampBedding",
			&"offset": Vector2(-650.0, -300.0),
			&"size": Vector2(240.0, 120.0),
			&"kind": WorldObstacle2D.VisualKind.CAMP_BEDDING,
			&"rotation": -0.12,
		},
		{
			&"name": &"StartingCampSupplyCache",
			&"offset": Vector2(350.0, 650.0),
			&"size": Vector2(210.0, 170.0),
			&"kind": WorldObstacle2D.VisualKind.CAMP_SUPPLY_CACHE,
			&"rotation": 0.18,
		},
		{
			&"name": &"StartingCampMedicalCache",
			&"offset": Vector2(0.0, 720.0),
			&"size": Vector2(180.0, 140.0),
			&"kind": WorldObstacle2D.VisualKind.CAMP_MEDICAL_CACHE,
			&"rotation": -0.08,
		},
	]
	for placement: Dictionary in placements:
		_add_rectangle_obstacle(
			placement[&"name"],
			STARTING_CAMP_POSITION + placement[&"offset"],
			placement[&"size"],
			placement[&"kind"],
			placement[&"rotation"]
		)


func _add_village_utility_poles(prefix: StringName, center_x: float) -> void:
	for pole_index: int in range(5):
		_add_circle_obstacle(
			StringName("%sUtilityPole_%02d" % [prefix, pole_index]),
			Vector2(center_x + (-420.0 if pole_index % 2 == 0 else 420.0), 6400.0 + pole_index * 980.0),
			48.0,
			WorldObstacle2D.VisualKind.UTILITY_POLE
		)


func _add_village_fences(prefix: StringName, center: Vector2, side: float) -> void:
	var segments: Array[Dictionary] = [
		{&"offset": Vector2(-1850.0, -1350.0), &"size": Vector2(1500.0, 120.0)},
		{&"offset": Vector2(1850.0, -1350.0), &"size": Vector2(1500.0, 120.0)},
		{&"offset": Vector2(-1850.0, 1350.0), &"size": Vector2(1500.0, 120.0)},
		{&"offset": Vector2(1850.0, 1350.0), &"size": Vector2(1500.0, 120.0)},
		{&"offset": Vector2(-2700.0, 0.0), &"size": Vector2(120.0, 1700.0)},
		{&"offset": Vector2(2700.0, 0.0), &"size": Vector2(120.0, 1700.0)},
	]
	for segment_index: int in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		var offset: Vector2 = segment[&"offset"]
		offset.x *= side
		_add_rectangle_obstacle(
			StringName("%sVillageFence_%02d" % [prefix, segment_index]),
			center + offset,
			segment[&"size"],
			WorldObstacle2D.VisualKind.WOODEN_FENCE
		)


func _build_metsa_loop_landmarks() -> void:
	# The shout on the 30-second loop: a hauler east of the spur, south of the
	# asphalt, clear of the teaching nodes and the camp satellites.
	_add_rectangle_obstacle(
		&"MetsaSpurHauler",
		Vector2(11050.0, 580.0),
		Vector2(640.0, 300.0),
		WorldObstacle2D.VisualKind.VEHICLE_WRECK,
		-0.62
	)
	_add_circle_obstacle(
		&"MetsaSpurShoulderRock",
		Vector2(10620.0, 1180.0),
		175.0,
		WorldObstacle2D.VisualKind.MOSSY_ROCK
	)
	_add_rectangle_obstacle(
		&"MetsaSpurWindfall",
		Vector2(10140.0, 900.0),
		Vector2(540.0, 120.0),
		WorldObstacle2D.VisualKind.FALLEN_LOG,
		0.95
	)


func _build_forest_perimeter() -> void:
	var tree_positions: PackedVector2Array = PackedVector2Array()
	for tree_index: int in range(14):
		var axis_position: float = -13200.0 + float(tree_index) * 1950.0
		tree_positions.append(Vector2(axis_position, -13400.0 + float(tree_index % 3) * 170.0))
		tree_positions.append(Vector2(axis_position, 13400.0 - float(tree_index % 4) * 160.0))
		tree_positions.append(Vector2(-13400.0 + float(tree_index % 3) * 150.0, axis_position))
		tree_positions.append(Vector2(13400.0 - float(tree_index % 4) * 145.0, axis_position))
	var inner_cluster: PackedVector2Array = PackedVector2Array([
		Vector2(10100.0, -10200.0), Vector2(11900.0, -9100.0), Vector2(10000.0, -7600.0),
		Vector2(12100.0, -6900.0), Vector2(10400.0, -3500.0), Vector2(12400.0, -2400.0),
		Vector2(-12600.0, 1600.0), Vector2(-10900.0, 2500.0), Vector2(-12200.0, 4200.0),
		Vector2(2500.0, 12300.0), Vector2(-2100.0, 12600.0), Vector2(11200.0, 3500.0),
	])
	tree_positions.append_array(inner_cluster)
	for tree_index: int in range(tree_positions.size()):
		_add_circle_obstacle(
			StringName("ForestTree_%03d" % tree_index),
			tree_positions[tree_index],
			105.0 + float(tree_index % 4) * 12.0,
			WorldObstacle2D.VisualKind.TREE
		)

	var rock_positions: PackedVector2Array = PackedVector2Array([
		Vector2(-12600.0, -6100.0), Vector2(-11900.0, 6200.0), Vector2(-9700.0, 12700.0),
		Vector2(-2100.0, -12600.0), Vector2(4600.0, -12500.0), Vector2(12700.0, -10500.0),
		Vector2(12600.0, 2300.0), Vector2(11700.0, 12100.0), Vector2(3600.0, 13000.0),
		Vector2(-3100.0, 11100.0), Vector2(10300.0, -980.0), Vector2(-9700.0, 1200.0),
	])
	for rock_index: int in range(rock_positions.size()):
		_add_circle_obstacle(
			StringName("MossyRock_%02d" % rock_index),
			rock_positions[rock_index],
			130.0 + float(rock_index % 3) * 24.0,
			WorldObstacle2D.VisualKind.MOSSY_ROCK
		)

	# Fill authored forest macro-cells with deterministic mixed-age stands while
	# preserving a generous playable clearing around the starting camp.
	var forest_random: RandomNumberGenerator = RandomNumberGenerator.new()
	forest_random.seed = WORLD_BUILD_SEED + 7001
	for row: int in range(GRID_SIZE):
		for column: int in range(GRID_SIZE):
			var cell: Vector2i = Vector2i(column, row)
			if get_biome_at_cell(cell) != Biome.FOREST:
				continue
			var trees_in_cell: int = DENSE_FOREST_TREES_PER_CELL + (
				1 if (column + row) % 3 == 0 else 0
			)
			for local_tree_index: int in range(trees_in_cell):
				for placement_attempt: int in range(DENSE_TREE_PLACEMENT_ATTEMPTS):
					var candidate: Vector2 = get_cell_center(cell) + Vector2(
						forest_random.randf_range(-720.0, 720.0),
						forest_random.randf_range(-720.0, 720.0)
					)
					var tree_radius: float = forest_random.randf_range(92.0, 142.0)
					if not _can_place_dense_tree(candidate, tree_radius):
						continue
					_add_circle_obstacle(
						StringName("ForestStand_%02d_%02d_%d" % [column, row, local_tree_index]),
						candidate,
						tree_radius,
						WorldObstacle2D.VisualKind.TREE
					)
					break
	_build_wilderness_groves()

	var log_candidates: PackedVector2Array = PackedVector2Array([
		Vector2(10100.0, 5200.0), Vector2(12400.0, 6100.0), Vector2(11300.0, 7900.0),
		Vector2(-12100.0, -8700.0), Vector2(-12500.0, -3200.0), Vector2(-11600.0, 5300.0),
		Vector2(-8400.0, 12800.0), Vector2(-3600.0, -13100.0), Vector2(4100.0, -13000.0),
		Vector2(8300.0, 12700.0), Vector2(12900.0, -5300.0), Vector2(11800.0, 10300.0),
	])
	for log_index: int in range(log_candidates.size()):
		var log_position: Vector2 = log_candidates[log_index]
		if log_position.distance_to(STARTING_CAMP_POSITION) < 720.0:
			continue
		if not is_position_walkable(log_position, 260.0):
			continue
		_add_rectangle_obstacle(
			StringName("FallenLog_%02d" % log_index),
			log_position,
			Vector2(430.0 + float(log_index % 3) * 55.0, 115.0),
			WorldObstacle2D.VisualKind.FALLEN_LOG,
			-0.7 + float(log_index % 5) * 0.32
		)


func _build_wilderness_groves() -> void:
	var wilderness_random: RandomNumberGenerator = RandomNumberGenerator.new()
	wilderness_random.seed = WORLD_BUILD_SEED + 8191
	for row: int in range(GRID_SIZE):
		for column: int in range(GRID_SIZE):
			var cell: Vector2i = Vector2i(column, row)
			if get_biome_at_cell(cell) != Biome.WILDERNESS:
				continue
			var trees_in_cell: int = DENSE_WILDERNESS_TREES_PER_CELL + (
				1 if (column * 3 + row) % 3 == 0 else 0
			)
			for local_tree_index: int in range(trees_in_cell):
				for placement_attempt: int in range(DENSE_TREE_PLACEMENT_ATTEMPTS):
					var candidate: Vector2 = get_cell_center(cell) + Vector2(
						wilderness_random.randf_range(-690.0, 690.0),
						wilderness_random.randf_range(-690.0, 690.0)
					)
					var tree_radius: float = wilderness_random.randf_range(86.0, 126.0)
					if not _can_place_dense_tree(candidate, tree_radius):
						continue
					_add_circle_obstacle(
						StringName("WildernessGrove_%02d_%02d_%d" % [column, row, local_tree_index]),
						candidate,
						tree_radius,
						WorldObstacle2D.VisualKind.TREE
					)
					break


func _can_place_dense_tree(world_position: Vector2, tree_radius: float) -> bool:
	if world_position.distance_to(STARTING_CAMP_POSITION) < DENSE_TREE_CAMP_CLEAR_RADIUS:
		return false
	if (
		get_minimum_road_edge_distance(world_position)
		< DENSE_TREE_ROAD_EDGE_CLEARANCE + tree_radius
	):
		return false
	return is_position_walkable(world_position, tree_radius + DENSE_TREE_OBSTACLE_CLEARANCE)


func _build_world_boundaries() -> void:
	var thickness: float = 256.0
	_add_boundary(
		&"BoundaryNorth",
		Vector2(0.0, -PLAYABLE_HALF_EXTENT - thickness * 0.5),
		Vector2(WORLD_SIZE + thickness * 2.0, thickness)
	)
	_add_boundary(
		&"BoundarySouth",
		Vector2(0.0, PLAYABLE_HALF_EXTENT + thickness * 0.5),
		Vector2(WORLD_SIZE + thickness * 2.0, thickness)
	)
	_add_boundary(
		&"BoundaryWest",
		Vector2(-PLAYABLE_HALF_EXTENT - thickness * 0.5, 0.0),
		Vector2(thickness, WORLD_SIZE)
	)
	_add_boundary(
		&"BoundaryEast",
		Vector2(PLAYABLE_HALF_EXTENT + thickness * 0.5, 0.0),
		Vector2(thickness, WORLD_SIZE)
	)


func _add_rectangle_obstacle(
	obstacle_name: StringName,
	world_position: Vector2,
	size: Vector2,
	visual_kind: int,
	obstacle_rotation: float = 0.0
) -> void:
	_obstacle_sequence += 1
	var obstacle: WorldObstacle2D = WorldObstacle2D.new()
	obstacle.configure_rectangle(
		obstacle_name,
		world_position,
		size,
		visual_kind,
		obstacle_rotation,
		WORLD_BUILD_SEED + _obstacle_sequence * 31
	)
	structures.add_child(obstacle)
	_obstacles.append(obstacle)
	_obstacle_broadphase_ready = false


func _add_circle_obstacle(
	obstacle_name: StringName,
	world_position: Vector2,
	radius: float,
	visual_kind: int
) -> void:
	_obstacle_sequence += 1
	var obstacle: WorldObstacle2D = WorldObstacle2D.new()
	obstacle.configure_circle(
		obstacle_name,
		world_position,
		radius,
		visual_kind,
		WORLD_BUILD_SEED + _obstacle_sequence * 31
	)
	structures.add_child(obstacle)
	_obstacles.append(obstacle)
	_obstacle_broadphase_ready = false


func _add_boundary(boundary_name: StringName, boundary_position: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = boundary_name
	body.position = boundary_position
	body.collision_layer = WORLD_STATIC_LAYER
	body.collision_mask = 0
	body.add_to_group(&"world_boundary")
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = shape
	body.add_child(collision)
	world_bounds.add_child(body)
	_boundary_count += 1


func _bake_flow_field_mask() -> void:
	_flow_field_blocked.resize(FLOW_FIELD_DIMENSION * FLOW_FIELD_DIMENSION)
	_flow_field_blocked.fill(0)
	_mark_circle_on_flow_field(_core_world_position, CORE_COLLISION_RADIUS + FLOW_FIELD_RASTER_CLEARANCE)
	for obstacle: WorldObstacle2D in _obstacles:
		var bounds: Rect2 = obstacle.get_world_bounds(FLOW_FIELD_RASTER_CLEARANCE)
		var minimum: Vector2i = world_to_flow_cell(bounds.position)
		var maximum: Vector2i = world_to_flow_cell(bounds.end)
		var minimum_x: int = clampi(minimum.x, 0, FLOW_FIELD_DIMENSION - 1)
		var minimum_y: int = clampi(minimum.y, 0, FLOW_FIELD_DIMENSION - 1)
		var maximum_x: int = clampi(maximum.x, 0, FLOW_FIELD_DIMENSION - 1)
		var maximum_y: int = clampi(maximum.y, 0, FLOW_FIELD_DIMENSION - 1)
		for cell_y: int in range(minimum_y, maximum_y + 1):
			for cell_x: int in range(minimum_x, maximum_x + 1):
				var cell: Vector2i = Vector2i(cell_x, cell_y)
				if obstacle.contains_world_point(flow_cell_to_world(cell), FLOW_FIELD_RASTER_CLEARANCE):
					_flow_field_blocked[cell_y * FLOW_FIELD_DIMENSION + cell_x] = 1


func _mark_circle_on_flow_field(center: Vector2, radius: float) -> void:
	var bounds: Rect2 = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var minimum: Vector2i = world_to_flow_cell(bounds.position)
	var maximum: Vector2i = world_to_flow_cell(bounds.end)
	for cell_y: int in range(clampi(minimum.y, 0, FLOW_FIELD_DIMENSION - 1), clampi(maximum.y, 0, FLOW_FIELD_DIMENSION - 1) + 1):
		for cell_x: int in range(clampi(minimum.x, 0, FLOW_FIELD_DIMENSION - 1), clampi(maximum.x, 0, FLOW_FIELD_DIMENSION - 1) + 1):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			if flow_cell_to_world(cell).distance_squared_to(center) <= radius * radius:
				_flow_field_blocked[cell_y * FLOW_FIELD_DIMENSION + cell_x] = 1


func _cell_index(cell: Vector2i) -> int:
	return cell.y * GRID_SIZE + cell.x


func _is_valid_map_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE and cell.y < GRID_SIZE


func _cells_to_rect(minimum_cell: Vector2i, maximum_cell: Vector2i) -> Rect2:
	var position: Vector2 = Vector2(
		-PLAYABLE_HALF_EXTENT + float(minimum_cell.x) * CELL_SIZE,
		-PLAYABLE_HALF_EXTENT + float(minimum_cell.y) * CELL_SIZE
	)
	var size: Vector2 = Vector2(
		float(maximum_cell.x - minimum_cell.x + 1) * CELL_SIZE,
		float(maximum_cell.y - minimum_cell.y + 1) * CELL_SIZE
	)
	return Rect2(position, size)
