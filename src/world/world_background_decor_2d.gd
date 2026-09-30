class_name WorldBackgroundDecor2D
extends Node2D
## Deterministic non-colliding decor partitioned into bounded regional batches.

const RUBBLE_COUNT: int = 300
const CRACK_COUNT: int = 160
const MOSS_COUNT: int = 220
const PROP_COUNT: int = 420
const TOTAL_DECORATION_COUNT: int = RUBBLE_COUNT + CRACK_COUNT + MOSS_COUNT + PROP_COUNT
const RENDER_CHUNK_SIZE: float = 4096.0
const CAMP_POSITION: Vector2 = Vector2(9950.0, 2400.0)
const CAMP_CLEAR_RADIUS: float = 1360.0
const PLACEMENT_ATTEMPTS: int = 96

## These conservative render envelopes mirror the actual custom-draw bounds in
## WorldBackgroundDecorChunk2D.  They are deliberately public read-only evidence
## for sibling presentation gates: neither placement, collision, flow-field
## ownership, nor the seeded decoration stream is exposed or mutable here.
const RUBBLE_VISUAL_RADIUS_MULTIPLIER: float = 1.2
const RUBBLE_VISUAL_RADIUS_PADDING: float = 2.0
const CRACK_VISUAL_RADIUS: float = 12.0
const CRACK_BRANCH_RATIO: float = 0.56
const CRACK_BRANCH_LENGTH: float = 85.0
const MOSS_VISUAL_RADIUS_PADDING: float = 6.0
const PROP_VISUAL_RADIUS_MULTIPLIER: float = 1.8
const PROP_VISUAL_RADIUS_PADDING: float = 8.0

enum DecorZone {
	CITY,
	MALL,
	VILLAGE_WEST,
	VILLAGE_EAST,
	FOREST,
	CONNECTORS,
}

enum DecorCategory {
	RUBBLE,
	CRACK,
	MOSS,
	PROP,
}

enum PropKind {
	SHRUB,
	ROOT,
	TYRE,
	BARREL,
	BONES,
	GROWTH,
	STREET_SEATING,
	FIRE_HYDRANT,
	BARREL_STOVE,
}

const RUBBLE_ZONE_COUNTS: Array[int] = [115, 65, 24, 24, 32, 40]
const CRACK_ZONE_COUNTS: Array[int] = [52, 40, 15, 15, 18, 20]
const MOSS_ZONE_COUNTS: Array[int] = [16, 18, 25, 25, 110, 26]
const PROP_ZONE_COUNTS: Array[int] = [82, 70, 52, 52, 126, 38]

# These are deliberate composition pockets rather than biome-wide scatter
# rectangles. Reusing a small number of ellipses creates readable clusters and
# leaves broad negative-space corridors between landmarks.
const CITY_POCKETS: Array[Vector4] = [
	Vector4(-12600.0, -10200.0, 630.0, 980.0),
	Vector4(-9300.0, -12200.0, 1050.0, 500.0),
	Vector4(-7800.0, -8950.0, 760.0, 900.0),
	Vector4(-3100.0, -10300.0, 720.0, 1050.0),
	Vector4(-8500.0, -6100.0, 820.0, 880.0),
	Vector4(-12300.0, -5850.0, 660.0, 880.0),
	Vector4(-3000.0, -5350.0, 720.0, 920.0),
]
const MALL_POCKETS: Array[Vector4] = [
	Vector4(1200.0, -10250.0, 780.0, 950.0),
	Vector4(9050.0, -9300.0, 800.0, 1050.0),
	Vector4(2400.0, -5750.0, 920.0, 720.0),
	Vector4(4750.0, -6150.0, 1100.0, 570.0),
	Vector4(7350.0, -5750.0, 900.0, 720.0),
	Vector4(2450.0, -1250.0, 1050.0, 680.0),
	Vector4(7200.0, -1250.0, 1120.0, 680.0),
]
const WEST_VILLAGE_POCKETS: Array[Vector4] = [
	Vector4(-12500.0, 6500.0, 630.0, 840.0),
	Vector4(-8650.0, 5850.0, 1150.0, 620.0),
	Vector4(-3900.0, 7600.0, 760.0, 1050.0),
	Vector4(-11600.0, 11150.0, 980.0, 720.0),
	Vector4(-7600.0, 11100.0, 1120.0, 760.0),
	Vector4(-3900.0, 11800.0, 720.0, 650.0),
]
const EAST_VILLAGE_POCKETS: Array[Vector4] = [
	Vector4(3900.0, 7600.0, 760.0, 1050.0),
	Vector4(7600.0, 5900.0, 1100.0, 650.0),
	Vector4(12350.0, 6500.0, 680.0, 880.0),
	Vector4(3900.0, 11700.0, 760.0, 680.0),
	Vector4(7600.0, 11100.0, 1050.0, 760.0),
	Vector4(12100.0, 11500.0, 850.0, 720.0),
]
const FOREST_POCKETS: Array[Vector4] = [
	Vector4(-10200.0, -13400.0, 1450.0, 520.0),
	Vector4(-4600.0, -13400.0, 1300.0, 520.0),
	Vector4(4200.0, -13400.0, 1400.0, 520.0),
	Vector4(10600.0, -13400.0, 1250.0, 520.0),
	Vector4(-13500.0, -7000.0, 500.0, 1450.0),
	Vector4(-13500.0, 1700.0, 500.0, 1500.0),
	Vector4(13500.0, -8200.0, 500.0, 1350.0),
	Vector4(13500.0, -2800.0, 500.0, 1250.0),
	Vector4(13500.0, 7600.0, 500.0, 1250.0),
	Vector4(-10200.0, 13400.0, 1350.0, 500.0),
	Vector4(-2600.0, 13400.0, 1400.0, 500.0),
	Vector4(4400.0, 13400.0, 1300.0, 500.0),
	Vector4(10500.0, 13400.0, 1250.0, 500.0),
]
const CONNECTOR_POCKETS: Array[Vector4] = [
	Vector4(-5600.0, -760.0, 1300.0, 330.0),
	Vector4(-3150.0, 760.0, 1100.0, 330.0),
	Vector4(3350.0, -760.0, 1200.0, 330.0),
	Vector4(6500.0, 760.0, 1050.0, 330.0),
	Vector4(-4200.0, 3350.0, 1150.0, 330.0),
	Vector4(2900.0, 4820.0, 1150.0, 330.0),
	Vector4(9600.0, -760.0, 850.0, 330.0),
]

# Landmarks remain visually dominant. Decoration may gather near their outer
# edges, but never directly beneath the principal authored footprints.
const LANDMARK_CLEAR_RECTS: Array[Rect2] = [
	Rect2(-12105.0, -11705.0, 2210.0, 2010.0),
	Rect2(-6680.0, -11630.0, 2660.0, 1860.0),
	Rect2(-12130.0, -8805.0, 2260.0, 1810.0),
	Rect2(-6455.0, -8930.0, 2510.0, 2060.0),
	Rect2(-12130.0, -5655.0, 2460.0, 1710.0),
	Rect2(-6455.0, -5630.0, 2710.0, 1860.0),
	Rect2(1470.0, -8980.0, 6760.0, 2160.0),
	Rect2(1470.0, -4230.0, 6760.0, 2160.0),
	Rect2(1210.0, -6140.0, 1080.0, 1280.0),
	Rect2(7410.0, -6140.0, 1080.0, 1280.0),
	Rect2(-11590.0, 6250.0, 1580.0, 1300.0),
	Rect2(-6090.0, 6150.0, 1580.0, 1300.0),
	Rect2(-11490.0, 9150.0, 1580.0, 1300.0),
	Rect2(-5990.0, 9450.0, 1580.0, 1300.0),
	Rect2(4490.0, 6250.0, 1620.0, 1280.0),
	Rect2(10090.0, 6140.0, 1620.0, 1280.0),
	Rect2(4540.0, 9210.0, 1620.0, 1280.0),
	Rect2(9990.0, 9460.0, 1620.0, 1280.0),
]

const FOREST_PROP_KINDS: Array[int] = [
	PropKind.SHRUB,
	PropKind.ROOT,
	PropKind.SHRUB,
	PropKind.GROWTH,
	PropKind.ROOT,
	PropKind.BONES,
	PropKind.SHRUB,
	PropKind.GROWTH,
]
const VILLAGE_PROP_KINDS: Array[int] = [
	PropKind.SHRUB,
	PropKind.ROOT,
	PropKind.STREET_SEATING,
	PropKind.BONES,
	PropKind.SHRUB,
	PropKind.BARREL_STOVE,
	PropKind.ROOT,
	PropKind.STREET_SEATING,
]
const URBAN_PROP_KINDS: Array[int] = [
	PropKind.TYRE,
	PropKind.STREET_SEATING,
	PropKind.FIRE_HYDRANT,
	PropKind.BARREL,
	PropKind.TYRE,
	PropKind.STREET_SEATING,
	PropKind.FIRE_HYDRANT,
	PropKind.BARREL_STOVE,
]

var _half_extent: float = 14336.0
var _rubble_positions: PackedVector2Array = PackedVector2Array()
var _rubble_sizes: PackedFloat32Array = PackedFloat32Array()
var _rubble_rotations: PackedFloat32Array = PackedFloat32Array()
var _crack_starts: PackedVector2Array = PackedVector2Array()
var _crack_ends: PackedVector2Array = PackedVector2Array()
var _moss_positions: PackedVector2Array = PackedVector2Array()
var _moss_sizes: PackedFloat32Array = PackedFloat32Array()
var _prop_positions: PackedVector2Array = PackedVector2Array()
var _prop_sizes: PackedFloat32Array = PackedFloat32Array()
var _prop_rotations: PackedFloat32Array = PackedFloat32Array()
var _prop_kinds: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	z_index = -5
	z_as_relative = false


func configure(playable_half_extent: float, seed_value: int) -> void:
	_clear_render_chunks()
	_half_extent = playable_half_extent
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	_rubble_positions.clear()
	_rubble_sizes.clear()
	_rubble_rotations.clear()
	_crack_starts.clear()
	_crack_ends.clear()
	_moss_positions.clear()
	_moss_sizes.clear()
	_prop_positions.clear()
	_prop_sizes.clear()
	_prop_rotations.clear()
	_prop_kinds.clear()

	_scatter_rubble(random)
	_scatter_cracks(random)
	_scatter_moss(random)
	_scatter_props(random)

	z_index = -5
	z_as_relative = false
	_build_render_chunks()


func get_decoration_count() -> int:
	return (
		_rubble_positions.size()
		+ _crack_starts.size()
		+ _moss_positions.size()
		+ _prop_positions.size()
	)


func get_zone_decoration_counts() -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	for zone: int in range(DecorZone.size()):
		counts.append(
			RUBBLE_ZONE_COUNTS[zone]
			+ CRACK_ZONE_COUNTS[zone]
			+ MOSS_ZONE_COUNTS[zone]
			+ PROP_ZONE_COUNTS[zone]
		)
	return counts


func get_render_chunk_count() -> int:
	return get_render_chunks().size()


func get_render_chunks() -> Array[WorldBackgroundDecorChunk2D]:
	var chunks: Array[WorldBackgroundDecorChunk2D] = []
	for child: Node in get_children():
		var chunk: WorldBackgroundDecorChunk2D = child as WorldBackgroundDecorChunk2D
		if chunk != null:
			chunks.append(chunk)
	return chunks


func get_render_chunk_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for chunk: WorldBackgroundDecorChunk2D in get_render_chunks():
		bounds.append(chunk.get_world_render_bounds())
	return bounds


func get_chunked_decoration_count() -> int:
	var count: int = 0
	for chunk: WorldBackgroundDecorChunk2D in get_render_chunks():
		count += chunk.get_decoration_count()
	return count


func get_rubble_positions() -> PackedVector2Array:
	return _rubble_positions.duplicate()


func get_rubble_sizes() -> PackedFloat32Array:
	## Read-only visual-envelope evidence for future decor siblings.  The data is
	## duplicated so a presentation gate cannot alter the legacy seeded stream.
	return _rubble_sizes.duplicate()


func get_rubble_visual_radii() -> PackedFloat32Array:
	var radii: PackedFloat32Array = PackedFloat32Array()
	for rubble_size: float in _rubble_sizes:
		radii.append(
			rubble_size * RUBBLE_VISUAL_RADIUS_MULTIPLIER + RUBBLE_VISUAL_RADIUS_PADDING
		)
	return radii


func get_crack_starts() -> PackedVector2Array:
	return _crack_starts.duplicate()


func get_crack_ends() -> PackedVector2Array:
	return _crack_ends.duplicate()


func get_crack_visual_envelopes() -> Array[Rect2]:
	## Each envelope includes the main stroke, its deterministic branch, and the
	## 12px stroke half-width.  Returning copies keeps visual review code from
	## reaching into this seeded decoration stream.
	var envelopes: Array[Rect2] = []
	for crack_index: int in range(_crack_starts.size()):
		var crack_start: Vector2 = _crack_starts[crack_index]
		var crack_end: Vector2 = _crack_ends[crack_index]
		var envelope: Rect2 = Rect2(crack_start, Vector2.ZERO).expand(crack_end)
		var displacement: Vector2 = crack_end - crack_start
		if not displacement.is_zero_approx():
			var branch_end: Vector2 = (
				crack_start.lerp(crack_end, CRACK_BRANCH_RATIO)
				+ displacement.normalized().orthogonal() * CRACK_BRANCH_LENGTH
			)
			envelope = envelope.expand(branch_end)
		envelopes.append(envelope.grow(CRACK_VISUAL_RADIUS))
	return envelopes


func get_moss_positions() -> PackedVector2Array:
	return _moss_positions.duplicate()


func get_moss_sizes() -> PackedFloat32Array:
	return _moss_sizes.duplicate()


func get_moss_visual_radii() -> PackedFloat32Array:
	var radii: PackedFloat32Array = PackedFloat32Array()
	for moss_size: float in _moss_sizes:
		radii.append(moss_size + MOSS_VISUAL_RADIUS_PADDING)
	return radii


func get_prop_positions() -> PackedVector2Array:
	return _prop_positions.duplicate()


func get_prop_sizes() -> PackedFloat32Array:
	return _prop_sizes.duplicate()


func get_prop_visual_radii() -> PackedFloat32Array:
	var radii: PackedFloat32Array = PackedFloat32Array()
	for prop_size: float in _prop_sizes:
		radii.append(
			prop_size * PROP_VISUAL_RADIUS_MULTIPLIER + PROP_VISUAL_RADIUS_PADDING
		)
	return radii


func get_prop_kinds() -> PackedInt32Array:
	return _prop_kinds.duplicate()


func _scatter_rubble(random: RandomNumberGenerator) -> void:
	var global_index: int = 0
	for zone: int in range(RUBBLE_ZONE_COUNTS.size()):
		for zone_index: int in range(RUBBLE_ZONE_COUNTS[zone]):
			var position: Vector2 = _sample_unique_position(
				random,
				zone,
				DecorCategory.RUBBLE,
				zone_index,
				_rubble_positions,
				72.0
			)
			_rubble_positions.append(position)
			_rubble_sizes.append(random.randf_range(28.0, 104.0))
			_rubble_rotations.append(random.randf_range(0.0, TAU))
			global_index += 1
	assert(global_index == RUBBLE_COUNT)


func _scatter_cracks(random: RandomNumberGenerator) -> void:
	var global_index: int = 0
	for zone: int in range(CRACK_ZONE_COUNTS.size()):
		for zone_index: int in range(CRACK_ZONE_COUNTS[zone]):
			var crack_start: Vector2 = Vector2.ZERO
			var crack_end: Vector2 = Vector2.ZERO
			for attempt: int in range(PLACEMENT_ATTEMPTS):
				crack_start = _sample_unique_position(
					random,
					zone,
					DecorCategory.CRACK,
					zone_index + attempt * 7,
					_crack_starts,
					118.0
				)
				var crack_length: float = random.randf_range(90.0, 330.0)
				var crack_angle: float = random.randf_range(0.0, TAU)
				if zone == DecorZone.CITY or zone == DecorZone.MALL or zone == DecorZone.CONNECTORS:
					var axis_angle: float = 0.0 if (zone_index + attempt) % 2 == 0 else PI * 0.5
					crack_angle = axis_angle + random.randf_range(-0.34, 0.34)
				crack_end = crack_start + Vector2.from_angle(crack_angle) * crack_length
				if (
					_is_candidate_valid(crack_end, zone, DecorCategory.CRACK)
					and _is_candidate_valid(
						crack_start.lerp(crack_end, 0.5),
						zone,
						DecorCategory.CRACK
					)
				):
					break
			_crack_starts.append(crack_start)
			_crack_ends.append(crack_end)
			global_index += 1
	assert(global_index == CRACK_COUNT)


func _scatter_moss(random: RandomNumberGenerator) -> void:
	var global_index: int = 0
	for zone: int in range(MOSS_ZONE_COUNTS.size()):
		for zone_index: int in range(MOSS_ZONE_COUNTS[zone]):
			var position: Vector2 = _sample_unique_position(
				random,
				zone,
				DecorCategory.MOSS,
				zone_index,
				_moss_positions,
				105.0
			)
			_moss_positions.append(position)
			_moss_sizes.append(random.randf_range(35.0, 118.0))
			global_index += 1
	assert(global_index == MOSS_COUNT)


func _scatter_props(random: RandomNumberGenerator) -> void:
	var global_index: int = 0
	for zone: int in range(PROP_ZONE_COUNTS.size()):
		for zone_index: int in range(PROP_ZONE_COUNTS[zone]):
			var position: Vector2 = _sample_unique_position(
				random,
				zone,
				DecorCategory.PROP,
				zone_index,
				_prop_positions,
				132.0
			)
			_prop_positions.append(position)
			_prop_sizes.append(random.randf_range(22.0, 64.0))
			_prop_rotations.append(random.randf_range(0.0, TAU))
			_prop_kinds.append(_get_prop_kind(zone, zone_index))
			global_index += 1
	assert(global_index == PROP_COUNT)


func _sample_unique_position(
	random: RandomNumberGenerator,
	zone: int,
	category: int,
	sample_index: int,
	existing_positions: PackedVector2Array,
	minimum_separation: float
) -> Vector2:
	var candidate: Vector2 = Vector2.ZERO
	for attempt: int in range(PLACEMENT_ATTEMPTS):
		candidate = _sample_authored_position(
			random,
			zone,
			category,
			sample_index + attempt * 11
		)
		if _is_separated(candidate, existing_positions, minimum_separation):
			return candidate
	# Exact category totals are more important than a rare spacing relaxation.
	# The candidate still obeys all road, landmark, camp, and world-bound rules.
	return candidate


func _sample_authored_position(
	random: RandomNumberGenerator,
	zone: int,
	category: int,
	sample_index: int
) -> Vector2:
	var pockets: Array[Vector4] = _get_zone_pockets(zone)
	for attempt: int in range(PLACEMENT_ATTEMPTS):
		var pocket: Vector4 = pockets[(sample_index + attempt) % pockets.size()]
		var angle: float = random.randf_range(0.0, TAU)
		# Bias marks toward a pocket's focal mass while retaining a soft outer
		# shoulder. Separate pockets create intentional negative space.
		var radius_factor: float = lerpf(0.16, 1.0, pow(random.randf(), 1.42))
		var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
			cos(angle) * pocket.z * radius_factor,
			sin(angle) * pocket.w * radius_factor
		)
		if _is_candidate_valid(candidate, zone, category):
			return candidate

	# Pocket geometry is intentionally generous, so this is only a defensive
	# deterministic fallback for future footprint changes.
	for fallback_index: int in range(pockets.size() * 12):
		var fallback_pocket: Vector4 = pockets[fallback_index % pockets.size()]
		var fallback_angle: float = float(fallback_index) * 2.399963
		var fallback: Vector2 = Vector2(fallback_pocket.x, fallback_pocket.y) + Vector2(
			cos(fallback_angle) * fallback_pocket.z * 0.82,
			sin(fallback_angle) * fallback_pocket.w * 0.82
		)
		if _is_candidate_valid(fallback, zone, category):
			return fallback
	return Vector2(pockets[0].x, pockets[0].y)


func _get_zone_pockets(zone: int) -> Array[Vector4]:
	match zone:
		DecorZone.CITY:
			return CITY_POCKETS
		DecorZone.MALL:
			return MALL_POCKETS
		DecorZone.VILLAGE_WEST:
			return WEST_VILLAGE_POCKETS
		DecorZone.VILLAGE_EAST:
			return EAST_VILLAGE_POCKETS
		DecorZone.FOREST:
			return FOREST_POCKETS
		_:
			return CONNECTOR_POCKETS


func _get_prop_kind(zone: int, zone_index: int) -> int:
	var pool: Array[int] = URBAN_PROP_KINDS
	if zone == DecorZone.FOREST:
		pool = FOREST_PROP_KINDS
	elif zone == DecorZone.VILLAGE_WEST or zone == DecorZone.VILLAGE_EAST:
		pool = VILLAGE_PROP_KINDS
	return pool[zone_index % pool.size()]


func _is_candidate_valid(position: Vector2, zone: int, category: int) -> bool:
	if not position.is_finite():
		return false
	var world_margin: float = 320.0
	if (
		absf(position.x) > _half_extent - world_margin
		or absf(position.y) > _half_extent - world_margin
	):
		return false
	if position.distance_squared_to(CAMP_POSITION) < CAMP_CLEAR_RADIUS * CAMP_CLEAR_RADIUS:
		return false
	for landmark_rect: Rect2 in LANDMARK_CLEAR_RECTS:
		if landmark_rect.has_point(position):
			return false

	var road_clearance: float = 350.0
	match category:
		DecorCategory.RUBBLE:
			road_clearance = 390.0
		DecorCategory.CRACK:
			road_clearance = 410.0
		DecorCategory.PROP:
			road_clearance = 380.0
	var road_distance: float = _distance_to_authored_roads(position)
	if road_distance < road_clearance:
		return false
	# Connector decoration is composed specifically on road shoulders. This
	# keeps navigation centers clean while visually binding the macro regions.
	if zone == DecorZone.CONNECTORS and road_distance > 1450.0:
		return false
	return true


func _is_separated(
	position: Vector2,
	existing_positions: PackedVector2Array,
	minimum_separation: float
) -> bool:
	var minimum_squared: float = minimum_separation * minimum_separation
	for existing: Vector2 in existing_positions:
		if position.distance_squared_to(existing) < minimum_squared:
			return false
	return true


func _distance_to_authored_roads(position: Vector2) -> float:
	var distance: float = INF
	distance = minf(distance, _distance_to_segment(position, Vector2(-12288.0, 0.0), Vector2(12288.0, 0.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(0.0, -12288.0), Vector2(0.0, 12288.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(-8192.0, -11264.0), Vector2(-8192.0, 0.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(0.0, -5500.0), Vector2(11264.0, -5500.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(9000.0, -5500.0), Vector2(9000.0, 0.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(-8192.0, 4096.0), Vector2(8192.0, 4096.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(-8192.0, 4096.0), Vector2(-8192.0, 11264.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(8192.0, 4096.0), Vector2(8192.0, 11264.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(-12288.0, -12288.0), Vector2(12288.0, -12288.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(12288.0, -12288.0), Vector2(12288.0, 12288.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(12288.0, 12288.0), Vector2(-12288.0, 12288.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(-12288.0, 12288.0), Vector2(-12288.0, -12288.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(9000.0, -5500.0), Vector2(11264.0, -5500.0)))
	distance = minf(distance, _distance_to_segment(position, Vector2(11264.0, -5500.0), Vector2(11264.0, -11264.0)))
	return distance


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var displacement: Vector2 = finish - start
	var length_squared: float = displacement.length_squared()
	if length_squared <= 0.0:
		return point.distance_to(start)
	var ratio: float = clampf((point - start).dot(displacement) / length_squared, 0.0, 1.0)
	return point.distance_to(start + displacement * ratio)


func _build_render_chunks() -> void:
	var chunks_by_coordinate: Dictionary = {}
	for rubble_index: int in range(_rubble_positions.size()):
		var rubble_position: Vector2 = _rubble_positions[rubble_index]
		var rubble_chunk: WorldBackgroundDecorChunk2D = _get_or_create_chunk(
			rubble_position,
			chunks_by_coordinate
		)
		rubble_chunk.add_rubble(
			rubble_position,
			_rubble_sizes[rubble_index],
			_rubble_rotations[rubble_index],
			rubble_index
		)

	for crack_index: int in range(_crack_starts.size()):
		var crack_start: Vector2 = _crack_starts[crack_index]
		var crack_chunk: WorldBackgroundDecorChunk2D = _get_or_create_chunk(
			crack_start,
			chunks_by_coordinate
		)
		crack_chunk.add_crack(crack_start, _crack_ends[crack_index])

	for moss_index: int in range(_moss_positions.size()):
		var moss_position: Vector2 = _moss_positions[moss_index]
		var moss_chunk: WorldBackgroundDecorChunk2D = _get_or_create_chunk(
			moss_position,
			chunks_by_coordinate
		)
		moss_chunk.add_moss(moss_position, _moss_sizes[moss_index])

	for prop_index: int in range(_prop_positions.size()):
		var prop_position: Vector2 = _prop_positions[prop_index]
		var prop_chunk: WorldBackgroundDecorChunk2D = _get_or_create_chunk(
			prop_position,
			chunks_by_coordinate
		)
		prop_chunk.add_prop(
			prop_position,
			_prop_sizes[prop_index],
			_prop_rotations[prop_index],
			_prop_kinds[prop_index]
		)

	for chunk: WorldBackgroundDecorChunk2D in get_render_chunks():
		chunk.seal()


func _get_or_create_chunk(
	world_position: Vector2,
	chunks_by_coordinate: Dictionary
) -> WorldBackgroundDecorChunk2D:
	var coordinate: Vector2i = _get_chunk_coordinate(world_position)
	if chunks_by_coordinate.has(coordinate):
		return chunks_by_coordinate[coordinate] as WorldBackgroundDecorChunk2D
	var chunk: WorldBackgroundDecorChunk2D = WorldBackgroundDecorChunk2D.new()
	chunk.name = "DecorChunk_%02d_%02d" % [coordinate.x, coordinate.y]
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
