class_name WorldAmbientScenery2D
extends Node2D
## Deterministic visual-only ruin, tree, and prop clusters for traversal-safe world density.

const AMBIENT_SCENERY_Z: int = -4
const RENDER_CHUNK_SIZE: float = 4096.0
const CAMP_CLEAR_RADIUS: float = 1760.0
const ROAD_EDGE_CLEARANCE: float = 480.0
## What a decorative layer owes a road is not what a navigable one owes it. 480
## units is measured from the road *edge*, and a dirt track is 480 wide, so the
## original figure kept every tree, rock and log 720 units from any centreline -
## 1,440 units of bare ground straddling every route, against a forest-density
## frame that is 2,667 units across. In the districts that is right: an asphalt
## carriageway wants a clean verge. Under the forest and wilderness belts it
## emptied the shot, and it is bought with nothing, because this layer draws at
## `AMBIENT_SCENERY_Z = -4` and cannot occlude a gameplay participant at 5. A
## canopy leaning over a forest track is the picture; the urban clearance stays.
const FOREST_ROAD_EDGE_CLEARANCE: float = 300.0
const WORLD_MARGIN: float = 320.0
const STRUCTURE_VISUAL_CLEARANCE: float = 0.0
const STRUCTURAL_SILHOUETTE_SEPARATION: float = 340.0
const PLACEMENT_ATTEMPTS: int = 192
const TOTAL_SCENERY_COUNT: int = 640
const AMBIENT_SCENERY_CHUNK_SCRIPT: Script = preload(
	"res://src/world/world_ambient_scenery_chunk_2d.gd"
)

enum SceneryZone {
	CITY,
	MALL,
	VILLAGE_WEST,
	VILLAGE_EAST,
	FOREST,
	WILDERNESS,
	CONNECTORS,
}

enum SceneryKind {
	RUIN_FACADE,
	VILLAGE_SHACK,
	TREE_CLUSTER,
	FOLIAGE_CLUSTER,
	ROCK_CLUSTER,
	FALLEN_LOG,
	SCRAP_CLUSTER,
	ROAD_BARRIER,
	WRECK,
	FENCE,
}

## The forest carries the largest zone budget and still read as bare ground,
## because three of its eighteen pockets were geometrically impossible and the
## road clearance ate most of a fourth. Fixing both frees the budget rather than
## enlarging it, so the count rises only enough to cover the two pockets added
## east of the perimeter route: 172 items over fifteen usable pockets was eleven
## each, and 236 over twenty is the same eleven with the gaps closed.
const ZONE_SCENERY_COUNTS: Array[int] = [96, 72, 48, 48, 236, 92, 48]
const CITY_POCKETS: Array[Vector4] = [
	Vector4(-11800.0, -9700.0, 580.0, 620.0),
	Vector4(-9200.0, -10200.0, 620.0, 520.0),
	Vector4(-6300.0, -9700.0, 660.0, 620.0),
	Vector4(-11700.0, -6700.0, 600.0, 580.0),
	Vector4(-9200.0, -6000.0, 580.0, 680.0),
	Vector4(-6400.0, -6200.0, 650.0, 660.0),
	Vector4(-11200.0, -3600.0, 650.0, 500.0),
	Vector4(-5000.0, -3450.0, 700.0, 520.0),
]
const MALL_POCKETS: Array[Vector4] = [
	Vector4(2350.0, -6650.0, 620.0, 360.0),
	Vector4(4750.0, -6650.0, 780.0, 360.0),
	Vector4(7350.0, -6650.0, 660.0, 360.0),
	Vector4(2350.0, -4400.0, 600.0, 480.0),
	Vector4(4750.0, -4100.0, 820.0, 420.0),
	Vector4(7350.0, -4400.0, 600.0, 480.0),
	Vector4(10500.0, -8700.0, 560.0, 800.0),
	Vector4(10500.0, -2600.0, 560.0, 720.0),
]
const WEST_VILLAGE_POCKETS: Array[Vector4] = [
	Vector4(-11200.0, 7300.0, 600.0, 520.0),
	Vector4(-9400.0, 7000.0, 560.0, 460.0),
	Vector4(-6100.0, 7300.0, 620.0, 520.0),
	Vector4(-11000.0, 10500.0, 650.0, 620.0),
	Vector4(-8300.0, 11200.0, 560.0, 600.0),
	Vector4(-5000.0, 10800.0, 620.0, 600.0),
]
const EAST_VILLAGE_POCKETS: Array[Vector4] = [
	Vector4(5200.0, 7300.0, 620.0, 520.0),
	Vector4(7000.0, 7000.0, 560.0, 460.0),
	Vector4(10800.0, 7300.0, 620.0, 520.0),
	Vector4(5200.0, 10800.0, 620.0, 600.0),
	Vector4(8000.0, 11200.0, 560.0, 620.0),
	Vector4(11200.0, 10600.0, 620.0, 600.0),
]
const FOREST_POCKETS: Array[Vector4] = [
	Vector4(-10400.0, -13300.0, 1060.0, 360.0),
	Vector4(-5400.0, -13300.0, 1060.0, 360.0),
	Vector4(3200.0, -13300.0, 1080.0, 360.0),
	Vector4(9300.0, -12950.0, 1020.0, 620.0),
	Vector4(11700.0, -9200.0, 700.0, 1100.0),
	Vector4(11800.0, -4200.0, 700.0, 1050.0),
	Vector4(11800.0, 4200.0, 740.0, 1020.0),
	Vector4(11600.0, 9200.0, 760.0, 980.0),
	Vector4(9300.0, 12400.0, 1100.0, 440.0),
	Vector4(3400.0, 13300.0, 1100.0, 360.0),
	Vector4(-3000.0, 13300.0, 1050.0, 360.0),
	Vector4(-9200.0, 13100.0, 1050.0, 420.0),
	## The three western belt pockets used to sit at x -12600 with a half-width
	## of 380, which put every one of their candidates inside the perimeter
	## route's clearance band: sampling road-edge distance along y = -5200, 2600
	## and 8500 returns nothing at or above the old 480 anywhere in x -12980 to
	## -12220. All three were completely impossible, and `_sample_position`
	## cycles pockets on failure, so the belt silently donated its whole share to
	## the pockets that could be filled. They are centred on the legal band the
	## probe found instead, and widened to reach both it and the near-road strip
	## the reduced forest clearance opens up.
	Vector4(-13300.0, 8500.0, 780.0, 1120.0),
	Vector4(-13300.0, 2600.0, 780.0, 1150.0),
	Vector4(-13300.0, -5200.0, 780.0, 1080.0),
	Vector4(-8600.0, 2700.0, 720.0, 640.0),
	## East of the perimeter route the nearest forest pocket was 3,400 units
	## away, which is why the right half of the forest-density frame contained no
	## scenery at all. These two close that gap, sited where the biome mask still
	## reads 0.84 forest - the belt at x -10800 is only forest between y -1000 and
	## y 4000, and a tree pocket outside that band would stand a canopy on ground
	## the terrain shader is painting as asphalt.
	Vector4(-10800.0, 2600.0, 900.0, 780.0),
	Vector4(-10900.0, 500.0, 860.0, 820.0),
	Vector4(7800.0, 800.0, 560.0, 620.0),
	Vector4(11800.0, 1800.0, 620.0, 760.0),
]
const WILDERNESS_POCKETS: Array[Vector4] = [
	Vector4(-5700.0, -2200.0, 760.0, 620.0),
	Vector4(-3300.0, -2600.0, 700.0, 620.0),
	Vector4(2600.0, -2200.0, 700.0, 620.0),
	Vector4(5200.0, -1800.0, 620.0, 620.0),
	Vector4(-5200.0, 1800.0, 760.0, 620.0),
	Vector4(-2800.0, 2700.0, 680.0, 620.0),
	Vector4(2500.0, 2400.0, 720.0, 620.0),
	Vector4(5100.0, 2600.0, 620.0, 620.0),
	Vector4(-4200.0, 6200.0, 720.0, 680.0),
	Vector4(2600.0, 6800.0, 720.0, 680.0),
]
const CONNECTOR_POCKETS: Array[Vector4] = [
	Vector4(-5700.0, -920.0, 740.0, 360.0),
	Vector4(-3100.0, 920.0, 680.0, 360.0),
	Vector4(3200.0, -920.0, 700.0, 360.0),
	Vector4(6500.0, 920.0, 680.0, 360.0),
	Vector4(-4200.0, 3350.0, 720.0, 360.0),
	Vector4(2900.0, 4820.0, 720.0, 360.0),
	Vector4(9600.0, -920.0, 620.0, 360.0),
]

const CITY_KIND_POOL: Array[int] = [
	SceneryKind.RUIN_FACADE,
	SceneryKind.SCRAP_CLUSTER,
	SceneryKind.ROAD_BARRIER,
	SceneryKind.WRECK,
	SceneryKind.RUIN_FACADE,
	SceneryKind.FOLIAGE_CLUSTER,
	SceneryKind.SCRAP_CLUSTER,
	SceneryKind.FENCE,
]
const MALL_KIND_POOL: Array[int] = [
	SceneryKind.RUIN_FACADE,
	SceneryKind.ROAD_BARRIER,
	SceneryKind.FENCE,
	SceneryKind.SCRAP_CLUSTER,
	SceneryKind.WRECK,
	SceneryKind.ROAD_BARRIER,
	SceneryKind.RUIN_FACADE,
	SceneryKind.FOLIAGE_CLUSTER,
]
const VILLAGE_KIND_POOL: Array[int] = [
	SceneryKind.VILLAGE_SHACK,
	SceneryKind.FENCE,
	SceneryKind.FOLIAGE_CLUSTER,
	SceneryKind.ROCK_CLUSTER,
	SceneryKind.FALLEN_LOG,
	SceneryKind.SCRAP_CLUSTER,
	SceneryKind.VILLAGE_SHACK,
	SceneryKind.FOLIAGE_CLUSTER,
]
const FOREST_KIND_POOL: Array[int] = [
	SceneryKind.TREE_CLUSTER,
	SceneryKind.TREE_CLUSTER,
	SceneryKind.FOLIAGE_CLUSTER,
	SceneryKind.TREE_CLUSTER,
	SceneryKind.ROCK_CLUSTER,
	SceneryKind.TREE_CLUSTER,
	SceneryKind.FALLEN_LOG,
	SceneryKind.TREE_CLUSTER,
]
const WILDERNESS_KIND_POOL: Array[int] = [
	SceneryKind.TREE_CLUSTER,
	SceneryKind.FOLIAGE_CLUSTER,
	SceneryKind.ROCK_CLUSTER,
	SceneryKind.FALLEN_LOG,
	SceneryKind.TREE_CLUSTER,
	SceneryKind.SCRAP_CLUSTER,
	SceneryKind.FOLIAGE_CLUSTER,
	SceneryKind.ROCK_CLUSTER,
]
const CONNECTOR_KIND_POOL: Array[int] = [
	SceneryKind.ROAD_BARRIER,
	SceneryKind.SCRAP_CLUSTER,
	SceneryKind.FOLIAGE_CLUSTER,
	SceneryKind.ROCK_CLUSTER,
	SceneryKind.FENCE,
	SceneryKind.WRECK,
]

var _half_extent: float = 14336.0
var _camp_position: Vector2 = Vector2.ZERO
var _is_position_walkable: Callable = Callable()
var _road_edge_distance: Callable = Callable()
var _positions: PackedVector2Array = PackedVector2Array()
var _sizes: PackedFloat32Array = PackedFloat32Array()
var _rotations: PackedFloat32Array = PackedFloat32Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _variants: PackedInt32Array = PackedInt32Array()
var _zones: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	z_index = AMBIENT_SCENERY_Z
	z_as_relative = false


func configure(
	playable_half_extent: float,
	seed_value: int,
	camp_position: Vector2,
	position_walkable: Callable,
	road_edge_distance: Callable
) -> void:
	_clear_render_chunks()
	_half_extent = playable_half_extent
	_camp_position = camp_position
	_is_position_walkable = position_walkable
	_road_edge_distance = road_edge_distance
	_positions.clear()
	_sizes.clear()
	_rotations.clear()
	_kinds.clear()
	_variants.clear()
	_zones.clear()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	for zone: int in range(SceneryZone.size()):
		_scatter_zone(random, zone)
	assert(_positions.size() == TOTAL_SCENERY_COUNT)
	z_index = AMBIENT_SCENERY_Z
	z_as_relative = false
	_build_render_chunks()


func get_scenery_count() -> int:
	return _positions.size()


func get_zone_scenery_counts() -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	for zone: int in range(SceneryZone.size()):
		counts.append(ZONE_SCENERY_COUNTS[zone])
	return counts


func get_scenery_positions() -> PackedVector2Array:
	return _positions.duplicate()


func get_scenery_kinds() -> PackedInt32Array:
	return _kinds.duplicate()


func get_scenery_sizes() -> PackedFloat32Array:
	## Read-only placement evidence for visual-only sibling layers.  Exposing a
	## duplicate avoids coupling an accent's placement to ambient internals while
	## letting an art gate reject a ground card hidden by an oversized tree.
	return _sizes.duplicate()


func get_scenery_visual_radii() -> PackedFloat32Array:
	## Conservative render radii at the same scale used during deterministic
	## placement.  This is presentation metadata only; collision, flow, and seed
	## ownership remain solely with WorldMap2D.
	var radii: PackedFloat32Array = PackedFloat32Array()
	for scenery_index: int in range(_kinds.size()):
		radii.append(_get_visual_radius(_kinds[scenery_index], _sizes[scenery_index]))
	return radii


func get_scenery_zones() -> PackedInt32Array:
	return _zones.duplicate()


func get_render_chunks() -> Array[Node2D]:
	var chunks: Array[Node2D] = []
	for child: Node in get_children():
		var chunk: Node2D = child as Node2D
		if chunk != null:
			chunks.append(chunk)
	return chunks


func get_render_chunk_count() -> int:
	return get_render_chunks().size()


func get_render_chunk_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for chunk: Node2D in get_render_chunks():
		var bounds_variant: Variant = chunk.call(&"get_world_render_bounds")
		if bounds_variant is Rect2:
			bounds.append(bounds_variant)
	return bounds


func get_chunked_scenery_count() -> int:
	var count: int = 0
	for chunk: Node2D in get_render_chunks():
		var count_variant: Variant = chunk.call(&"get_scenery_count")
		if count_variant is int:
			count += count_variant
	return count


func _scatter_zone(random: RandomNumberGenerator, zone: int) -> void:
	for zone_index: int in range(ZONE_SCENERY_COUNTS[zone]):
		var kind: int = _get_scenery_kind(zone, zone_index)
		var size: float = _get_scenery_size(random, kind)
		var candidate: Vector2 = _sample_position(random, zone, zone_index, kind, size)
		_positions.append(candidate)
		_sizes.append(size)
		_rotations.append(_get_scenery_rotation(random, kind))
		_kinds.append(kind)
		_variants.append(zone_index + zone * 17)
		_zones.append(zone)


func _sample_position(
	random: RandomNumberGenerator,
	zone: int,
	zone_index: int,
	kind: int,
	size: float
) -> Vector2:
	var pockets: Array[Vector4] = _get_zone_pockets(zone)
	for attempt: int in range(PLACEMENT_ATTEMPTS):
		var pocket: Vector4 = pockets[(zone_index + attempt * 3) % pockets.size()]
		var angle: float = random.randf_range(0.0, TAU)
		var radius_factor: float = lerpf(0.12, 1.0, pow(random.randf(), 1.32))
		var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
			cos(angle) * pocket.z * radius_factor,
			sin(angle) * pocket.w * radius_factor
		)
		if _is_candidate_valid(candidate, zone, kind, size):
			return candidate

	for pocket_index: int in range(pockets.size() * 32):
		var fallback_pocket: Vector4 = pockets[pocket_index % pockets.size()]
		var fallback_angle: float = float(pocket_index) * 2.399963
		var fallback_radius: float = 0.14 + float(pocket_index % 11) * 0.07
		var fallback: Vector2 = Vector2(fallback_pocket.x, fallback_pocket.y) + Vector2(
			cos(fallback_angle) * fallback_pocket.z * minf(fallback_radius, 0.90),
			sin(fallback_angle) * fallback_pocket.w * minf(fallback_radius, 0.90)
		)
		if _is_candidate_valid(fallback, zone, kind, size):
			return fallback

	push_error("Ambient scenery could not find a legal position for zone %d" % zone)
	return Vector2(pockets[0].x, pockets[0].y)


func _is_candidate_valid(position: Vector2, zone: int, kind: int, size: float) -> bool:
	if not position.is_finite():
		return false
	if absf(position.x) > _half_extent - WORLD_MARGIN or absf(position.y) > _half_extent - WORLD_MARGIN:
		return false
	var visual_radius: float = _get_visual_radius(kind, size)
	if position.distance_squared_to(_camp_position) < CAMP_CLEAR_RADIUS * CAMP_CLEAR_RADIUS:
		return false
	if not _road_edge_distance.is_valid() or not _is_position_walkable.is_valid():
		return false
	var distance_to_road: Variant = _road_edge_distance.call(position)
	if not distance_to_road is float and not distance_to_road is int:
		return false
	var required_road_clearance: float = ROAD_EDGE_CLEARANCE
	if zone == SceneryZone.FOREST or zone == SceneryZone.WILDERNESS:
		required_road_clearance = FOREST_ROAD_EDGE_CLEARANCE
	if zone == SceneryZone.CONNECTORS:
		required_road_clearance = 360.0
		if float(distance_to_road) > 1450.0:
			return false
	if float(distance_to_road) < required_road_clearance:
		return false
	var position_is_walkable: Variant = _is_position_walkable.call(
		position,
		minf(visual_radius, STRUCTURE_VISUAL_CLEARANCE)
	)
	if not position_is_walkable is bool or not position_is_walkable:
		return false
	return _is_separated(position, kind)


func _is_separated(position: Vector2, kind: int) -> bool:
	for position_index: int in range(_positions.size()):
		var other_kind: int = _kinds[position_index]
		var minimum_separation: float = 128.0
		if _is_structural_scenery(kind) and _is_structural_scenery(other_kind):
			minimum_separation = STRUCTURAL_SILHOUETTE_SEPARATION
		elif kind == SceneryKind.TREE_CLUSTER and other_kind == SceneryKind.TREE_CLUSTER:
			minimum_separation = 190.0
		if position.distance_squared_to(_positions[position_index]) < minimum_separation * minimum_separation:
			return false
	return true


func _is_structural_scenery(kind: int) -> bool:
	return kind == SceneryKind.RUIN_FACADE or kind == SceneryKind.VILLAGE_SHACK


func _get_zone_pockets(zone: int) -> Array[Vector4]:
	match zone:
		SceneryZone.CITY:
			return CITY_POCKETS
		SceneryZone.MALL:
			return MALL_POCKETS
		SceneryZone.VILLAGE_WEST:
			return WEST_VILLAGE_POCKETS
		SceneryZone.VILLAGE_EAST:
			return EAST_VILLAGE_POCKETS
		SceneryZone.FOREST:
			return FOREST_POCKETS
		SceneryZone.WILDERNESS:
			return WILDERNESS_POCKETS
		_:
			return CONNECTOR_POCKETS


func _get_scenery_kind(zone: int, zone_index: int) -> int:
	var pool: Array[int] = CITY_KIND_POOL
	match zone:
		SceneryZone.MALL:
			pool = MALL_KIND_POOL
		SceneryZone.VILLAGE_WEST, SceneryZone.VILLAGE_EAST:
			pool = VILLAGE_KIND_POOL
		SceneryZone.FOREST:
			pool = FOREST_KIND_POOL
		SceneryZone.WILDERNESS:
			pool = WILDERNESS_KIND_POOL
		SceneryZone.CONNECTORS:
			pool = CONNECTOR_KIND_POOL
	return pool[zone_index % pool.size()]


func _get_scenery_size(random: RandomNumberGenerator, kind: int) -> float:
	match kind:
		SceneryKind.RUIN_FACADE:
			return random.randf_range(500.0, 760.0)
		SceneryKind.VILLAGE_SHACK:
			return random.randf_range(380.0, 560.0)
		SceneryKind.TREE_CLUSTER:
			return random.randf_range(360.0, 610.0)
		SceneryKind.FOLIAGE_CLUSTER:
			return random.randf_range(220.0, 360.0)
		SceneryKind.ROCK_CLUSTER:
			return random.randf_range(250.0, 410.0)
		SceneryKind.FALLEN_LOG:
			return random.randf_range(300.0, 500.0)
		SceneryKind.SCRAP_CLUSTER, SceneryKind.ROAD_BARRIER, SceneryKind.WRECK, SceneryKind.FENCE:
			return random.randf_range(250.0, 440.0)
		_:
			return 320.0


func _get_visual_radius(kind: int, size: float) -> float:
	match kind:
		SceneryKind.RUIN_FACADE:
			return size * 0.44
		SceneryKind.VILLAGE_SHACK:
			return size * 0.42
		SceneryKind.TREE_CLUSTER:
			return size * 0.38
		SceneryKind.FALLEN_LOG:
			return size * 0.44
		_:
			return size * 0.34


func _get_scenery_rotation(random: RandomNumberGenerator, kind: int) -> float:
	match kind:
		SceneryKind.RUIN_FACADE, SceneryKind.VILLAGE_SHACK:
			return random.randf_range(-0.10, 0.10)
		SceneryKind.TREE_CLUSTER, SceneryKind.FOLIAGE_CLUSTER, SceneryKind.ROCK_CLUSTER:
			return random.randf_range(-0.22, 0.22)
		_:
			return random.randf_range(-0.72, 0.72)


func _build_render_chunks() -> void:
	var chunks_by_coordinate: Dictionary = {}
	for scenery_index: int in range(_positions.size()):
		var scenery_position: Vector2 = _positions[scenery_index]
		var chunk: Node2D = _get_or_create_chunk(
			scenery_position,
			chunks_by_coordinate
		)
		chunk.call(
			&"add_scenery",
			scenery_position,
			_sizes[scenery_index],
			_rotations[scenery_index],
			_kinds[scenery_index],
			_variants[scenery_index]
		)
	for chunk: Node2D in get_render_chunks():
		chunk.call(&"seal")


func _get_or_create_chunk(
	world_position: Vector2,
	chunks_by_coordinate: Dictionary
) -> Node2D:
	var coordinate: Vector2i = _get_chunk_coordinate(world_position)
	if chunks_by_coordinate.has(coordinate):
		return chunks_by_coordinate[coordinate] as Node2D
	var chunk: Node2D = AMBIENT_SCENERY_CHUNK_SCRIPT.new() as Node2D
	chunk.name = "AmbientSceneryChunk_%02d_%02d" % [coordinate.x, coordinate.y]
	add_child(chunk)
	chunk.configure_origin(
		Vector2(-_half_extent, -_half_extent) + Vector2(coordinate) * RENDER_CHUNK_SIZE
	)
	chunks_by_coordinate[coordinate] = chunk
	return chunk


func _get_chunk_coordinate(world_position: Vector2) -> Vector2i:
	var chunk_dimension: int = maxi(1, ceili((_half_extent * 2.0) / RENDER_CHUNK_SIZE))
	return Vector2i(
		clampi(floori((world_position.x + _half_extent) / RENDER_CHUNK_SIZE), 0, chunk_dimension - 1),
		clampi(floori((world_position.y + _half_extent) / RENDER_CHUNK_SIZE), 0, chunk_dimension - 1)
	)


func _clear_render_chunks() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
